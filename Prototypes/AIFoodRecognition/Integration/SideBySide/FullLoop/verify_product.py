#!/usr/bin/env python3
"""Verify the full experimental main app; HealthKit remains globally shared."""
import argparse
import json
import plistlib
import subprocess
from pathlib import Path
from simulator_entitlements import effective_entitlements

IDENTITY = 'com.jhardorp.loopaiphototest'
GROUP = 'group.' + IDENTITY
ALLOWED_ENTITLEMENTS = {
    'application-identifier', 'com.apple.developer.team-identifier',
    'get-task-allow', 'beta-reports-active', 'keychain-access-groups',
    'aps-environment', 'com.apple.developer.healthkit',
    'com.apple.developer.healthkit.access', 'com.apple.developer.healthkit.background-delivery',
    'com.apple.developer.nfc.readersession.formats', 'com.apple.developer.siri',
    'com.apple.developer.usernotifications.time-sensitive', 'com.apple.security.application-groups',
}


def verify(app, entitlements, source):
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    assert info['CFBundleIdentifier'] == IDENTITY, 'Wrong app identity'
    assert info['CFBundleDisplayName'] == 'Loop Next AI', 'Ambiguous display name'
    assert info['AppGroupIdentifier'] == GROUP, 'Shared production preferences/database group'
    assert info['MealPhotoFullAppExperimental'] is True
    assert info['MealPhotoFullAppSource'] == source, 'Source mismatch'
    assert info['MealPhotoFullAppCompanions'] is False
    assert not any(key.startswith('MealPhotoSandbox') for key in info), 'Sandbox substituted for full app'
    assert 'UIApplicationSceneManifest' in info, 'Normal startup missing'
    assert info['CFBundleURLTypes'] == [{'CFBundleURLName': IDENTITY, 'CFBundleURLSchemes': ['loop-next-ai']}]
    for key in ('NSHealthShareUsageDescription', 'NSHealthUpdateUsageDescription',
                'NSSiriUsageDescription', 'NSBluetoothAlwaysUsageDescription', 'NSCameraUsageDescription'):
        assert isinstance(info.get(key), str) and info[key].strip(), f'Missing privacy description: {key}'
    assert info['ITSAppUsesNonExemptEncryption'] is False
    assert entitlements.get('com.apple.security.application-groups') == [GROUP], 'Missing/private group mismatch'
    assert entitlements.get('com.apple.developer.healthkit') is True, 'Full native capabilities missing'
    assert not set(entitlements).difference(ALLOWED_ENTITLEMENTS), 'Unreviewed entitlement'
    if 'application-identifier' in entitlements:
        assert entitlements['application-identifier'].endswith('.' + IDENTITY), 'Production or wildcard signing identity'
    for group in entitlements.get('keychain-access-groups', []):
        assert group.endswith('.' + IDENTITY), 'Shared or wildcard keychain group'
    assert not list(app.rglob('*.appex')), 'Companion extension bundled'
    assert not (app / 'Watch').exists(), 'Watch app bundled'
    # Upstream copy-plugins.sh renames .loopplugin products to frameworks.
    # These pinned upstream modules declare their semantic identifiers and use
    # Bundle's default principal class; NSPrincipalClass is intentionally absent.
    modules = {
        'LoopOnboardingPlugin': ('com.loopkit.Loop.OnboardingIdentifier', 'LoopOnboarding'),
        'LoopSupportPlugin': ('com.loopkit.Loop.SupportIdentifier', 'LoopSupport'),
    }
    for name, (key, identifier) in modules.items():
        framework = app / 'Frameworks' / (name + '.framework')
        metadata = framework / 'Info.plist'
        assert metadata.is_file(), f'Native module missing: {name}'
        values = plistlib.loads(metadata.read_bytes())
        assert values.get(key) == identifier, f'Native module identifier mismatch: {name}'
        executable = values.get('CFBundleExecutable', '')
        assert executable and Path(executable).name == executable and (framework / executable).is_file(), f'Native module executable missing: {name}'
    assert (app / info['CFBundleExecutable']).is_file(), 'Executable missing'
    return info


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--app', type=Path, required=True)
    parser.add_argument('--source', required=True)
    parser.add_argument('--record', type=Path)
    parser.add_argument('--simulator', action='store_true', help='Read Xcode Simulator entitlements from the executable; never use for an IPA')
    args = parser.parse_args()
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(args.app)], check=True)
    signed = subprocess.check_output(['codesign', '-d', '--entitlements', ':-', str(args.app)])
    signed_entitlements = plistlib.loads(signed) if signed.strip() else {}
    info = plistlib.loads((args.app / 'Info.plist').read_bytes())
    entitlements = effective_entitlements(args.app, info, signed_entitlements, args.simulator)
    info = verify(args.app, entitlements, args.source)
    record = {
        'source': args.source, 'bundle': IDENTITY, 'display_name': info['CFBundleDisplayName'],
        'version': info['CFBundleShortVersionString'], 'build': info['CFBundleVersion'],
        'app_group': GROUP, 'entitlements': sorted(entitlements), 'full_native_startup': True,
        'entitlement_source': 'Simulator executable section' if args.simulator else 'Apple code signature',
        'companions': False, 'healthkit_isolation': False,
        'restriction': 'Experimental full app. Keep Health access and real pump/CGM connections off for initial current-phone tests. Not independently validated for therapy.',
    }
    if args.record:
        args.record.write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps(record))
