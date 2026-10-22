"""Verify the retained normal-identity IPA without rebuilding or re-signing it."""
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import zipfile

SOURCE = 'e768ff50dc335671f479543ccd5f3a525c733c20'
IPA_HASH = 'd078c42e33663dbefa601d33275b8b99162b82f9b35ba12fe53defe03ad48b34'
BUNDLE = 'com.279LYMG57A.loopkit.Loop'
TEAM = '279LYMG57A'
GROUP = 'group.' + BUNDLE + 'Group'


def verify(directory):
    ipa = directory / 'Loop.ipa'
    original = json.loads((directory / 'MigrationCandidate.json').read_text())
    assert original['source'] == SOURCE and original['ipa_sha256'] == IPA_HASH
    assert hashlib.file_digest(ipa.open('rb'), 'sha256').hexdigest() == IPA_HASH
    allowed = [
        '.github/workflows/loop_ai_migration_validate.yml', '.github/workflows/loop_ai_sandbox.yml',
        '.github/workflows/loop_ai_live_update.yml', 'MIGRATION_LOOP4.md',
        'Prototypes/AIFoodRecognition/Integration/CONTROLLED_VALIDATION.md',
        'Prototypes/AIFoodRecognition/Integration/FULL_APP_CANDIDATE.md',
    ]
    changed = subprocess.check_output(['git', 'diff', '--name-only', '--no-renames', SOURCE, 'HEAD'], text=True).splitlines()
    assert all(path in allowed or path.startswith(('Prototypes/AIFoodRecognition/Integration/SideBySide/',
                                                   'Prototypes/AIFoodRecognition/Integration/LiveUpdate/'))
               for path in changed), 'Application source differs from the validated signed candidate'
    with tempfile.TemporaryDirectory() as temp:
        root = Path(temp).resolve()
        with zipfile.ZipFile(ipa) as archive:
            assert all((root / name).resolve().is_relative_to(root) for name in archive.namelist())
            archive.extractall(root)
        app = root / 'Payload/Loop.app'
        subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
        info = plistlib.loads((app / 'Info.plist').read_bytes())
        assert info['CFBundleIdentifier'] == BUNDLE and info['AppGroupIdentifier'] == GROUP
        assert info['CFBundleShortVersionString'] == '3.15.2' and info['CFBundleVersion'] == '27'
        assert info['MinimumOSVersion'] == '17.6' and 'UIApplicationSceneManifest' in info
        assert not any(key.startswith(('MealPhotoSandbox', 'MealPhotoFullApp')) for key in info)
        assert len(info.get('LoopMealReviewTesterAccessCode', '')) >= 32, 'Personal AI login missing'
        signed = plistlib.loads(subprocess.check_output(['codesign', '-d', '--entitlements', ':-', str(app)]))
        profile = plistlib.loads(subprocess.check_output(['security', 'cms', '-D', '-i', str(app / 'embedded.mobileprovision')]))
        assert signed['application-identifier'] == TEAM + '.' + BUNDLE
        assert signed['com.apple.developer.team-identifier'] == TEAM
        assert signed['com.apple.security.application-groups'] == [GROUP]
        assert signed.get('get-task-allow', False) is False
        assert signed['com.apple.developer.healthkit'] is True
        assert profile['Entitlements']['application-identifier'] == TEAM + '.' + BUNDLE
        assert profile['Entitlements']['com.apple.security.application-groups'] == [GROUP]
        companions = []
        for path in [*app.glob('PlugIns/*.appex/Info.plist'), *app.glob('Watch/*.app/Info.plist')]:
            item = plistlib.loads(path.read_bytes())
            assert item['CFBundleShortVersionString'] == '3.15.2' and item['CFBundleVersion'] == '27'
            companions.append(item['CFBundleIdentifier'])
        assert sorted(companions) == sorted(BUNDLE + '.' + name for name in ['Loop-Intent-Extension', 'LoopWidgetExtension', 'LoopWatch'])
    record = {**original, 'signature_verified': True, 'companions_verified': companions,
              'migration_checks': 'four Simulator cases required by workflow',
              'independently_validated_for_therapy': False, 'device_installed': False}
    (directory / 'VerifiedLiveCandidate.json').write_text(json.dumps(record, indent=2) + '\n')
    print('Verified the unchanged, originally signed normal Loop 3.15.2 (27); credentials were not printed.')


if __name__ == '__main__':
    verify(Path(sys.argv[1]))
