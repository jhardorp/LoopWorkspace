"""Record the existing Worker and a tested local bundle; only performs HTTP GETs."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
from urllib.request import Request, urlopen

ACCOUNT = 'a1af98f116246104f077ba72071d4dad'
WORKER = 'loop-plus-meal-review'
ADDRESS = 'https://loop-plus-meal-review.jan-1af.workers.dev'


def cloudflare(path):
    request = Request('https://api.cloudflare.com/client/v4/accounts/' + ACCOUNT + path,
                      headers={'Authorization': 'Bearer ' + os.environ['CLOUDFLARE_API_TOKEN']})
    with urlopen(request, timeout=25) as response:
        value = json.load(response)
    assert value.get('success') is True, 'Cloudflare read-only inspection failed'
    return value['result']


def inspect():
    assert os.environ.get('GITHUB_ACTIONS') == 'true'
    assert os.environ.get('GITHUB_REPOSITORY') == 'jhardorp/LoopWorkspace'
    assert os.environ.get('GITHUB_REF') == 'refs/heads/migration/loop4-ai-photo'
    assert os.environ.get('CLOUDFLARE_ACCOUNT_ID') == ACCOUNT, 'Existing Cloudflare account required'
    assert os.environ.get('CLOUDFLARE_API_TOKEN'), 'Cloudflare token permission is required'
    temporary = Path(os.environ['RUNNER_TEMP'])
    proof = json.loads((temporary / 'NextValidation.json').read_text())
    assert proof['candidate_source'] == os.environ['GITHUB_SHA'] and proof['application_source_unchanged']
    settings = cloudflare('/workers/scripts/' + WORKER + '/settings')
    deployments = cloudflare('/workers/scripts/' + WORKER + '/deployments')['deployments']
    assert deployments, 'Existing Worker deployment is required'
    assert cloudflare('/workers/subdomain')['subdomain'] == 'jan-1af'
    bindings = settings['bindings']
    secrets = {item['name'] for item in bindings if item['type'] == 'secret_text'}
    assert {'OPENAI_API_KEY', 'TESTER_ACCESS_CODE'} <= secrets, 'Existing server secrets are required'
    quota = next(item for item in bindings if item['name'] == 'QUOTA')
    assert quota['type'] == 'durable_object_namespace' and quota['class_name'] == 'PrototypeQuota'
    assert quota.get('namespace_id'), 'Existing shared quota namespace is required'
    variables = {item['name']: item['text'] for item in bindings
                 if item['type'] == 'plain_text' and item['name'] in
                 {'OPENAI_MODEL', 'DAILY_PHOTO_LIMIT', 'MINUTE_PHOTO_LIMIT'}}
    assert variables == {'OPENAI_MODEL': 'gpt-4.1-2025-04-14',
                         'DAILY_PHOTO_LIMIT': '1000', 'MINUTE_PHOTO_LIMIT': '60'}
    health = json.loads(subprocess.check_output([
        'curl', '--fail', '--silent', '--show-error', '--max-time', '25',
        '--header', 'Accept: application/json', '--user-agent', 'LoopMealReviewReleaseCheck/1.0',
        ADDRESS + '/health'], text=True))
    assert health.get('status') == 'ready' and health.get('features', {}).get('mealRefinement') is True
    assert health.get('photoLimits') == {'perDay': 1000, 'perMinute': 60}
    bundle = temporary / 'LoopDescriptionWorker/worker.js'
    record = {**proof, 'account': ACCOUNT, 'worker': WORKER, 'address': ADDRESS,
              'previous_deployment': deployments[0], 'quota_namespace': quota['namespace_id'],
              'secret_names': sorted(secrets), 'variables': variables, 'health_before': health,
              'bundle_sha256': hashlib.file_digest(bundle.open('rb'), 'sha256').hexdigest(),
              'deployed': False, 'secrets_changed': False, 'paid_provider_requests': 0}
    (temporary / 'DescriptionBackendCandidate.json').write_text(json.dumps(record, indent=2) + '\n')
    print('Existing Worker, quota, model, server secret names and service health verified. No deployment or paid AI request.')
    return record


if __name__ == '__main__':
    inspect()
