#!/usr/bin/env python3
"""Inspect the exported full test IPA before any later upload can be considered."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import zipfile

if __name__ == '__main__':
    if os.environ.get('GITHUB_REF') != 'refs/heads/migration/loop4-ai-photo':
        raise SystemExit('Migration branch required')
    assert os.environ['FULL_VALIDATION_RESULT'] == 'success'
    assert os.environ['FULL_VALIDATED_SOURCE'] == os.environ['GITHUB_SHA']
    assert os.environ['FULL_VALIDATED_RUN'] == os.environ['GITHUB_RUN_ID']
    directory = Path(os.environ['RUNNER_TEMP']) / 'LoopNextAICandidate'
    ipa = directory / 'LoopNextAI.ipa'
    record = directory / 'FullCandidate.json'
    with tempfile.TemporaryDirectory() as temp:
        with zipfile.ZipFile(ipa) as archive:
            archive.extractall(temp)
        subprocess.run(['python3', str(Path(__file__).with_name('verify_product.py')),
                        '--app', str(Path(temp) / 'Payload/Loop.app'),
                        '--source', os.environ['GITHUB_SHA'], '--record', str(record)], check=True)
        data = json.loads(record.read_text())
        data['ipa_sha256'] = hashlib.file_digest(ipa.open('rb'), 'sha256').hexdigest()
        data['xcode'] = subprocess.check_output(['xcodebuild', '-version'], text=True).strip()
        data['validation_source'] = os.environ['FULL_VALIDATED_SOURCE']
        data['validation_run'] = int(os.environ['FULL_VALIDATED_RUN'])
        data['runtime_source'] = os.environ['FULL_RUNTIME_SOURCE']
        data['uploaded'] = False
        data['installed'] = False
        record.write_text(json.dumps(data, indent=2) + '\n')
        print(json.dumps(data))
