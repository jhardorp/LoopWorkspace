"""Release only the exact reviewed artifacts; publication requires owner authorization."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import zipfile

from inspect_service import inspect
from verify_validation import ROOT, api, verify

SOURCE = '23c4cc427d09bc1f489b81b533e1bdf9c93634e0'
VALIDATION = 40886501697
ARCHIVE_RUN = 40937665799
ARCHIVE_SOURCE = '562919d74ff3b2ab1222e8c8ebc9e61c720ff01a'
BACKEND_RUN = 40962608601
BACKEND_SOURCE = '9a671a3b9352c2687cb6707cfe6df541a4c03d7e'
IPA_HASH = '43465f88c4758bc36fc37982fa5ed79520ccb9071fd71fae98d24a3f19009986'
BUNDLE = 'com.279LYMG57A.loopkit.Loop'
GROUP = 'group.' + BUNDLE + 'Group'
CONFIRMATION = 'PUBLISH_LOOP_28_AND_TEXT_INPUT'
ARTIFACTS = {
    12928092541: (ARCHIVE_RUN, ARCHIVE_SOURCE, 73533367,
                  'sha256:29cb4a535182ba36ba8fd6ee18c96e2038b88ff9bcf4bfc89b46c132c69ff37d'),
    12936348558: (BACKEND_RUN, BACKEND_SOURCE, 22105,
                  'sha256:8cc94da56e2c8eb2e5472d17459aac6cb808ea238629f03f72b3d414b837c6a0'),
}


def artifact_matches(value, expected):
    run, source, size, digest = expected
    return (value.get('expired') is False and value.get('size_in_bytes') == size
            and value.get('digest') == digest
            and value.get('workflow_run', {}).get('id') == run
            and value.get('workflow_run', {}).get('head_sha') == source)


def candidate_matches(value):
    return all(value.get(key) == expected for key, expected in {
        'candidate_source': ARCHIVE_SOURCE, 'validation_source': SOURCE,
        'validation_run': VALIDATION, 'ipa_sha256': IPA_HASH,
        'application_source_unchanged': True, 'signature_verified': True,
        'bundle': BUNDLE, 'app_group': GROUP, 'version': '3.15.2', 'build': '28',
        'uploaded': False, 'device_installed': False,
    }.items())


def evidence():
    assert os.environ['VALIDATED_SOURCE'] == SOURCE and os.environ['VALIDATION_RUN'] == str(VALIDATION)
    verify()
    for run_id, source, required in [
        (ARCHIVE_RUN, ARCHIVE_SOURCE, {'Archive using existing read-only signing',
                                     'Verify package signature and unchanged normal app identity'}),
        (BACKEND_RUN, BACKEND_SOURCE, {'Test and bundle the description Worker without publishing',
                                     'Inspect current Worker identity, quota and server secret names'}),
    ]:
        run = api('actions/runs/' + str(run_id))
        assert (run['head_sha'] == source and run['conclusion'] == 'success'
                and run['head_branch'] == 'migration/loop4-ai-photo'
                and run['workflow_id'] == 392623441), 'Successful original candidate run required'
        jobs = api('actions/runs/' + str(run_id) + '/jobs?filter=latest&per_page=100')['jobs']
        assert any(job['conclusion'] == 'success' and required <= {
            step['name'] for step in job.get('steps', []) if step['conclusion'] == 'success'
        } for job in jobs), 'Missing original archive or backend checks'
    for artifact_id, expected in ARTIFACTS.items():
        assert artifact_matches(api('actions/artifacts/' + str(artifact_id)), expected), 'Candidate artifact changed or expired'


def exactly_one(directory, name):
    matches = list(directory.rglob(name))
    assert len(matches) == 1, 'Expected exactly one retained ' + name
    return matches[0]


def backend_preflight(directory):
    evidence()
    baseline = json.loads(exactly_one(directory, 'DescriptionBackendCandidate.json').read_text())
    assert baseline['candidate_source'] == BACKEND_SOURCE and baseline['validation_source'] == SOURCE
    current = inspect()
    for key in ['account', 'worker', 'address', 'quota_namespace', 'secret_names', 'variables', 'bundle_sha256']:
        assert current[key] == baseline[key], 'Existing Worker configuration or candidate differs: ' + key
    assert current['previous_deployment'] == baseline['previous_deployment'], 'Worker was updated after preflight; inspect before deployment'
    return baseline


def publish_backend(directory):
    assert os.environ.get('OWNER_AUTHORIZED_UPDATE') == CONFIRMATION, 'Explicit owner publication authorization required'
    baseline = backend_preflight(directory)
    output = Path(os.environ['RUNNER_TEMP']) / 'DescriptionDeployStatus.json'
    status = {'candidate_source': os.environ['GITHUB_SHA'], 'validation_source': SOURCE,
              'bundle_sha256': baseline['bundle_sha256'], 'previous_deployment': baseline['previous_deployment'],
              'deployed': False, 'health_verified': False, 'paid_provider_requests': 0}
    output.write_text(json.dumps(status, indent=2) + '\n')
    try:
        backend = ROOT / 'Prototypes/AIFoodRecognition/Backend'
        subprocess.run(['node', 'node_modules/wrangler/bin/wrangler.js', 'deploy', '--keep-vars'],
                       cwd=backend, check=True)
        status['deployed'] = True
        after = inspect()
        assert after['health_before']['features'].get('mealDescription') is True, 'Description feature health check failed'
        for key in ['account', 'worker', 'quota_namespace', 'secret_names', 'variables']:
            assert after[key] == baseline[key], 'Existing backend configuration changed'
        status.update(health_verified=True, deployment=after['previous_deployment'])
    finally:
        output.write_text(json.dumps(status, indent=2) + '\n')


def verify_app(directory):
    evidence()
    candidate = json.loads(exactly_one(directory, 'NextCandidate.json').read_text())
    ipa = exactly_one(directory, 'Loop.ipa')
    assert candidate_matches(candidate), 'Wrong or unverified application candidate'
    assert hashlib.file_digest(ipa.open('rb'), 'sha256').hexdigest() == IPA_HASH, 'IPA differs from the signed candidate'
    health = json.loads(subprocess.check_output([
        'curl', '--fail', '--silent', '--show-error', '--max-time', '25',
        'https://loop-plus-meal-review.jan-1af.workers.dev/health'], text=True))
    assert health['status'] == 'ready' and health['features'].get('mealDescription') is True, 'Publish the verified description backend first'
    with tempfile.TemporaryDirectory() as temp:
        target = Path(temp).resolve()
        with zipfile.ZipFile(ipa) as archive:
            assert all((target / name).resolve().is_relative_to(target) for name in archive.namelist())
            archive.extractall(target)
        app = target / 'Payload/Loop.app'
        info = plistlib.loads((app / 'Info.plist').read_bytes())
        assert info['CFBundleIdentifier'] == BUNDLE and info['AppGroupIdentifier'] == GROUP
        assert info['CFBundleShortVersionString'] == '3.15.2' and info['CFBundleVersion'] == '28'
        subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
    proof = {**candidate, 'source': ARCHIVE_SOURCE, 'release_source': os.environ['GITHUB_SHA']}
    (directory / 'VerifiedNextRelease.json').write_text(json.dumps(proof, indent=2) + '\n')
    with open(os.environ['GITHUB_ENV'], 'a') as environment:
        environment.write('LOOP_VERIFIED_RELEASE_IPA=' + str(ipa.resolve()) + '\n')
    print('Verified exact signed Loop 3.15.2 (28), original identity and IPA hash; no upload performed.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=['preflight_backend', 'publish_backend', 'verify_app'])
    parser.add_argument('directory', type=Path)
    arguments = parser.parse_args()
    {'preflight_backend': backend_preflight, 'publish_backend': publish_backend,
     'verify_app': verify_app}[arguments.operation](arguments.directory)
