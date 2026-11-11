"""Verify a new normal-identity IPA without publishing or printing its personal login."""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import zipfile

BUNDLE = 'com.279LYMG57A.loopkit.Loop'
GROUP = 'group.' + BUNDLE + 'Group'
TEAM = '279LYMG57A'


def record():
    assert os.environ.get('GITHUB_REF') == 'refs/heads/migration/loop4-ai-photo'
    root = Path(os.environ['GITHUB_WORKSPACE'])
    proof = json.loads((Path(os.environ['RUNNER_TEMP']) / 'NextValidation.json').read_text())
    assert proof['candidate_source'] == os.environ['GITHUB_SHA'] and proof['application_source_unchanged']
    ipa = root / 'Loop.ipa'
    with tempfile.TemporaryDirectory() as temp:
        directory = Path(temp).resolve()
        with zipfile.ZipFile(ipa) as archive:
            assert all((directory / name).resolve().is_relative_to(directory) for name in archive.namelist())
            archive.extractall(directory)
        app = directory / 'Payload/Loop.app'
        subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
        info = plistlib.loads((app / 'Info.plist').read_bytes())
        assert info['CFBundleIdentifier'] == BUNDLE and info['AppGroupIdentifier'] == GROUP
        assert info['CFBundleShortVersionString'] == '3.15.2' and info['CFBundleVersion'] == '28'
        assert info['MinimumOSVersion'] == '17.6' and 'UIApplicationSceneManifest' in info
        assert not any(key.startswith(('MealPhotoSandbox', 'MealPhotoFullApp')) for key in info)
        assert len(info.get('LoopMealReviewTesterAccessCode', '')) >= 32
        signed = plistlib.loads(subprocess.check_output(['codesign', '-d', '--entitlements', ':-', str(app)]))
        profile = plistlib.loads(subprocess.check_output(['security', 'cms', '-D', '-i', str(app / 'embedded.mobileprovision')]))
        assert signed['application-identifier'] == TEAM + '.' + BUNDLE
        assert signed['com.apple.developer.team-identifier'] == TEAM
        assert signed['com.apple.security.application-groups'] == [GROUP]
        assert signed.get('get-task-allow', False) is False and signed['com.apple.developer.healthkit'] is True
        assert profile['Entitlements']['application-identifier'] == TEAM + '.' + BUNDLE
        assert profile['Entitlements']['com.apple.security.application-groups'] == [GROUP]
        companions = []
        for path in [*app.glob('PlugIns/*.appex/Info.plist'), *app.glob('Watch/*.app/Info.plist')]:
            child = plistlib.loads(path.read_bytes())
            assert child['CFBundleShortVersionString'] == '3.15.2' and child['CFBundleVersion'] == '28'
            companions.append(child['CFBundleIdentifier'])
        assert sorted(companions) == sorted(BUNDLE + '.' + name for name in ['Loop-Intent-Extension', 'LoopWidgetExtension', 'LoopWatch'])
    result = {**proof, 'bundle': BUNDLE, 'app_group': GROUP, 'version': '3.15.2', 'build': '28',
              'ipa_sha256': hashlib.file_digest(ipa.open('rb'), 'sha256').hexdigest(),
              'signature_verified': True, 'companions': companions,
              'xcode': subprocess.check_output(['xcodebuild', '-version'], text=True).strip(),
              'uploaded': False, 'device_installed': False, 'independently_validated_for_therapy': False}
    (root / 'NextCandidate.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))


if __name__ == '__main__':
    record()
