#!/usr/bin/env python3
"""Reverify the one explicitly approved, already signed TestFlight candidate."""
import hashlib
import json
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

SOURCE = '8af1328f54fa72807c3fe314d82f67cf488603a1'
IPA_SHA256 = '888f37757cd83537228018437d1bfa2a78e6da5660cddd8d17f99959cd8d3a55'
EXPECTED = {'source': SOURCE, 'bundle': 'com.jhardorp.loopaiphototest',
            'version': '0.1.0', 'build': '4', 'storage': 'MemoryOnly',
            'display_name': 'Loop AI Test'}


def main(directory):
    ipa = directory / 'LoopAIPhotoTest.ipa'
    with ipa.open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    if digest != IPA_SHA256:
        raise SystemExit('IPA differs from the approved signed candidate')
    original = json.loads((directory / 'SandboxCandidate.json').read_text())
    if original.get('ipa_sha256') != digest or any(original.get(k) != v for k, v in EXPECTED.items()):
        raise SystemExit('Original candidate record mismatch')
    with tempfile.TemporaryDirectory() as temp:
        root = Path(temp).resolve()
        with zipfile.ZipFile(ipa) as archive:
            for member in archive.namelist():
                if not (root / member).resolve().is_relative_to(root):
                    raise SystemExit('Unsafe IPA archive path')
            archive.extractall(root)
        record = root / 'VerifiedUpload.json'
        subprocess.run([sys.executable, str(Path(__file__).with_name('verify_product.py')),
                        '--app', str(root / 'Payload/Loop.app'), '--source', SOURCE,
                        '--record', str(record)], check=True)
        verified = json.loads(record.read_text())
    if any(verified.get(k) != v for k, v in EXPECTED.items()):
        raise SystemExit('Effective signed product differs from the approved candidate')
    verified['ipa_sha256'] = digest
    (directory / 'VerifiedUpload.json').write_text(json.dumps(verified, indent=2) + '\n')
    print('Approved Loop AI Test 0.1.0 (4): hash, signature, identity and isolation verified.')


if __name__ == '__main__':
    main(Path(sys.argv[1]))
