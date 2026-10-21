"""Reject packages that could replace working Loop or conceal missing native code."""
from pathlib import Path
import plistlib
import tempfile
import unittest
from verify_product import GROUP, IDENTITY, verify


class FullProductTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.app = Path(self.temp.name) / 'Loop.app'
        self.app.mkdir()
        self.info = {
            'CFBundleIdentifier': IDENTITY, 'CFBundleDisplayName': 'Loop Next AI',
            'AppGroupIdentifier': GROUP, 'MealPhotoFullAppExperimental': True,
            'MealPhotoFullAppSource': 'reviewed-source', 'MealPhotoFullAppCompanions': False,
            'UIApplicationSceneManifest': {'UISceneConfigurations': {}},
            'CFBundleURLTypes': [{'CFBundleURLName': IDENTITY, 'CFBundleURLSchemes': ['loop-next-ai']}],
            'ITSAppUsesNonExemptEncryption': False, 'CFBundleExecutable': 'Loop',
        }
        for key in ('NSHealthShareUsageDescription', 'NSHealthUpdateUsageDescription',
                    'NSSiriUsageDescription', 'NSBluetoothAlwaysUsageDescription', 'NSCameraUsageDescription'):
            self.info[key] = 'Native purpose description'
        self.entitlements = {'com.apple.security.application-groups': [GROUP],
                             'com.apple.developer.healthkit': True,
                             'application-identifier': 'TESTTEAMID.' + IDENTITY}
        (self.app / 'Loop').write_bytes(b'executable')
        for name in ('LoopOnboardingPlugin', 'LoopSupportPlugin'):
            plugin = self.app / 'Frameworks' / (name + '.framework')
            plugin.mkdir(parents=True)
            (plugin / 'Info.plist').write_bytes(plistlib.dumps({'NSPrincipalClass': name + '.Plugin'}))

    def check(self, info=None, entitlements=None):
        (self.app / 'Info.plist').write_bytes(plistlib.dumps(info or self.info))
        return verify(self.app, entitlements or self.entitlements, 'reviewed-source')

    def test_full_native_package_accepts_own_group(self):
        self.check()

    def test_production_identity_or_group_is_rejected(self):
        for key in ('CFBundleIdentifier', 'AppGroupIdentifier'):
            with self.subTest(key=key), self.assertRaises(AssertionError):
                self.check({**self.info, key: 'production.identity'})
        wrong = {**self.entitlements, 'com.apple.security.application-groups': ['group.production']}
        with self.assertRaises(AssertionError):
            self.check(entitlements=wrong)

    def test_shared_or_wildcard_keychain_is_rejected(self):
        for value in ('TESTTEAMID.*', 'TESTTEAMID.production'):
            with self.subTest(value=value), self.assertRaises(AssertionError):
                self.check(entitlements={**self.entitlements, 'keychain-access-groups': [value]})

    def test_sandbox_and_wrong_source_are_rejected(self):
        for change in ({'MealPhotoSandbox': True}, {'MealPhotoFullAppSource': 'other-source'}):
            with self.subTest(change=change), self.assertRaises(AssertionError):
                self.check({**self.info, **change})

    def test_missing_native_onboarding_is_rejected(self):
        (self.app / 'Frameworks/LoopOnboardingPlugin.framework/Info.plist').unlink()
        with self.assertRaises(AssertionError):
            self.check()

    def test_companion_install_is_rejected(self):
        (self.app / 'Watch').mkdir()
        with self.assertRaises(AssertionError):
            self.check()


if __name__ == '__main__':
    unittest.main()
