#!/usr/bin/env python3
"""Verify the full experimental main app; HealthKit remains globally shared."""
import argparse
import json
import plistlib
import subprocess
from pathlib import Path

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
    plugins = [path.parent.name for path in (app / 'Frameworks').glob('*.framework/Info.plist')
               if plistlib.loads(path.read_bytes()).get('NSPrincipalClass')]
    assert 'LoopOnboardingPlugin.framework' in plugins, 'Native onboarding plugin missing'
    assert 'LoopSupportPlugin.framework' in plugins, 'Native support plugin missing'
    assert (app / info['CFBundleExecutable']).is_file(), 'Executable missing'
    return info


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--app', type=Path, required=True)
    parser.add_argument('--source', required=True)
    parser.add_argument('--record', type=Path)
    args = parser.parse_args()
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(args.app)], check=True)
    signed = subprocess.check_output(['codesign', '-d', '--entitlements', ':-', str(args.app)])
    entitlements = plistlib.loads(signed) if signed.strip() else {}
    info = verify(args.app, entitlements, args.source)
    record = {
        'source': args.source, 'bundle': IDENTITY, 'display_name': info['CFBundleDisplayName'],
        'version': info['CFBundleShortVersionString'], 'build': info['CFBundleVersion'],
        'app_group': GROUP, 'entitlements': sorted(entitlements), 'full_native_startup': True,
        'companions': False, 'healthkit_isolation': False,
        'restriction': 'Experimental full app. Keep Health access and real pump/CGM connections off for initial current-phone tests. Not independently validated for therapy.',
    }
    if args.record:
        args.record.write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps(record))
