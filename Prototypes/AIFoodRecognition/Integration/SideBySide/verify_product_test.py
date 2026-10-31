import plistlib
import tempfile
import unittest
from pathlib import Path
from verify_product import IDENTITY, REQUIRED_PURPOSE_STRINGS, verify


class IsolationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.app = Path(self.temp.name) / 'Loop.app'
        self.app.mkdir()
        (self.app / 'Loop').touch()
        self.info = {
            'CFBundleIdentifier': IDENTITY, 'CFBundleDisplayName': 'Loop AI Test',
            'CFBundleExecutable': 'Loop', 'MealPhotoSandbox': True,
            'MealPhotoSandboxSchema': 1, 'MealPhotoSandboxStorage': 'MemoryOnly',
            'MealPhotoSandboxSource': 'source', 'AppGroupIdentifier': 'group.' + IDENTITY,
            'CFBundleURLTypes': [{'CFBundleURLName': IDENTITY, 'CFBundleURLSchemes': ['loop-ai-test']}],
            **REQUIRED_PURPOSE_STRINGS
        }

    def check(self, entitlements=None):
        (self.app / 'Info.plist').write_bytes(plistlib.dumps(self.info))
        return verify(self.app, entitlements or {}, 'source')

    def testDistinctMinimalAppIsAccepted(self):
        self.check({'application-identifier': 'TEAM.' + IDENTITY,
                    'keychain-access-groups': ['TEAM.' + IDENTITY]})

    def testHealthKitSharedGroupAndWildcardKeychainAreRejected(self):
        for entitlement in ({'com.apple.developer.healthkit': True},
                            {'com.apple.developer.siri': True},
                            {'com.apple.security.application-groups': ['group.workingLoop']},
                            {'keychain-access-groups': ['TEAM.*']},
                            {'application-identifier': 'TEAM.com.working.Loop'}):
            with self.assertRaises(AssertionError):
                self.check(entitlement)

    def testProductionIdentityAndBackgroundCapabilitiesAreRejected(self):
        self.info['CFBundleIdentifier'] = 'com.working.Loop'
        with self.assertRaises(AssertionError): self.check()
        self.info['CFBundleIdentifier'] = IDENTITY
        for key in ('NSBluetoothPeripheralUsageDescription', 'UIBackgroundModes', 'UIApplicationSceneManifest'):
            self.info[key] = []
            with self.assertRaises(AssertionError): self.check()
            del self.info[key]

    def testApplePrivacyMetadataIsRequiredWithoutEnablingAccess(self):
        self.check()
        for key, value in REQUIRED_PURPOSE_STRINGS.items():
            with self.subTest(key=key):
                del self.info[key]
                with self.assertRaises(AssertionError): self.check()
                self.info[key] = 'Production app requests access to your data.'
                with self.assertRaises(AssertionError): self.check()
                self.info[key] = value
        self.check()

    def testExtensionOrDevicePluginIsRejected(self):
        extension = self.app / 'Widget.appex'
        extension.mkdir()
        with self.assertRaises(AssertionError): self.check()
        extension.rmdir()
        framework = self.app / 'Frameworks' / 'Pump.framework'
        framework.mkdir(parents=True)
        (framework / 'Info.plist').write_bytes(plistlib.dumps({'NSPrincipalClass': 'PumpPlugin'}))
        with self.assertRaises(AssertionError): self.check()

    def testSourceOrStorageMismatchIsRejected(self):
        self.info['MealPhotoSandboxSource'] = 'other'
        with self.assertRaises(AssertionError): self.check()
        self.info['MealPhotoSandboxSource'] = 'source'
        self.info['MealPhotoSandboxStorage'] = 'SharedStore'
        with self.assertRaises(AssertionError): self.check()


if __name__ == '__main__': unittest.main()
