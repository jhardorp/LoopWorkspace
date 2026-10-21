#!/usr/bin/env python3
"""Check the built artifact, including the effective code-signing entitlements."""
import argparse
import json
import plistlib
import subprocess
from pathlib import Path

IDENTITY = 'com.jhardorp.loopaiphototest'
ALLOWED_ENTITLEMENTS = {'application-identifier', 'com.apple.developer.team-identifier',
                        'get-task-allow', 'beta-reports-active', 'keychain-access-groups'}
FORBIDDEN_INFO = {'UIApplicationSceneManifest', 'UIMainStoryboardFile', 'UIBackgroundModes',
                  'BGTaskSchedulerPermittedIdentifiers', 'NSHealthShareUsageDescription',
                  'NSHealthUpdateUsageDescription', 'NSBluetoothAlwaysUsageDescription',
                  'NSBluetoothPeripheralUsageDescription', 'NFCReaderUsageDescription',
                  'NSSiriUsageDescription', 'NSUserActivityTypes'}


def verify(app, entitlements, source):
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    assert info['CFBundleIdentifier'] == IDENTITY, 'Wrong app identity'
    assert info['CFBundleDisplayName'] == 'Loop AI Test', 'Ambiguous display name'
    assert info['MealPhotoSandbox'] is True and info['MealPhotoSandboxSchema'] == 1
    assert info['MealPhotoSandboxStorage'] == 'MemoryOnly'
    assert info['MealPhotoSandboxSource'] == source, 'Source mismatch'
    assert info['AppGroupIdentifier'] == 'group.' + IDENTITY
    assert not FORBIDDEN_INFO.intersection(info), 'Device/health/background capability remains'
    assert info['CFBundleURLTypes'] == [{'CFBundleURLName': IDENTITY, 'CFBundleURLSchemes': ['loop-ai-test']}]
    assert not set(entitlements).difference(ALLOWED_ENTITLEMENTS), 'Unexpected signed entitlement'
    for key in ('application-identifier',):
        if key in entitlements:
            assert entitlements[key].endswith('.' + IDENTITY), 'Production or wildcard signing identity'
    for group in entitlements.get('keychain-access-groups', []):
        assert group.endswith('.' + IDENTITY), 'Shared or wildcard keychain group'
    assert not list(app.rglob('*.appex')), 'Extension bundled'
    assert not (app / 'Watch').exists(), 'Watch app bundled'
    assert not (app / 'PlugIns').exists(), 'Device plugins bundled'
    assert not list(app.rglob('*.loopplugin')), 'Device plugin bundled'
    for framework_info in (app / 'Frameworks').glob('*.framework/Info.plist'):
        framework = plistlib.loads(framework_info.read_bytes())
        assert not framework.get('NSPrincipalClass'), 'Dynamic device/service plugin bundled'
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
    record = {'source': args.source, 'bundle': IDENTITY, 'display_name': info['CFBundleDisplayName'],
              'version': info['CFBundleShortVersionString'], 'build': info['CFBundleVersion'],
              'storage': info['MealPhotoSandboxStorage'], 'entitlements': sorted(entitlements),
              'restriction': 'AI UI test app only. No therapy, device connections or HealthKit access.'}
    if args.record:
        args.record.write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps(record))
