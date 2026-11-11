"""Reuse complete Simulator validation only for the same application/test source."""
import json
import os
from pathlib import Path
import re
import subprocess
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[4]
REQUIRED_STEPS = {
    'Verify pinned sources and protected production configuration',
    'Run Swift review regression tests',
    'Test photo and description backend contracts without deploying',
    'Run settings and history migration regressions on the new dependency pins',
    'Build integrated app for iOS Simulator unsigned',
    'Package normal Simulator startup with Xcode ad-hoc signing',
    'Probe normal application startup in a disposable Simulator',
    'Run native adapter regression tests on Simulator',
    'Require normal startup as well as adapter tests',
}


def complete_validation(run, jobs, source):
    if not (run.get('head_sha') == source and run.get('conclusion') == 'success'
            and run.get('head_branch') == 'migration/loop4-ai-photo'
            and run.get('workflow_id') == 390255385
            and run.get('path') == '.github/workflows/loop_ai_migration_validate.yml'):
        return False
    validate = [job for job in jobs.get('jobs', []) if job.get('name') == 'validate']
    if len(validate) != 1 or validate[0].get('conclusion') != 'success':
        return False
    passed = {step.get('name') for step in validate[0].get('steps', []) if step.get('conclusion') == 'success'}
    return REQUIRED_STEPS <= passed


def api(path):
    request = Request('https://api.github.com/repos/jhardorp/LoopWorkspace/' + path,
                      headers={'Authorization': 'Bearer ' + os.environ['ACTIONS_READ_TOKEN'],
                               'Accept': 'application/vnd.github+json'})
    with urlopen(request, timeout=25) as response:
        return json.load(response)


def verify():
    assert os.environ.get('GITHUB_ACTIONS') == 'true'
    assert os.environ.get('GITHUB_REPOSITORY') == 'jhardorp/LoopWorkspace'
    assert os.environ.get('GITHUB_REF') == 'refs/heads/migration/loop4-ai-photo'
    source, run_id = os.environ['VALIDATED_SOURCE'], os.environ['VALIDATION_RUN']
    assert re.fullmatch('[0-9a-f]{40}', source) and re.fullmatch('[0-9]+', run_id)
    run = api('actions/runs/' + run_id)
    jobs = api('actions/runs/' + run_id + '/jobs?filter=latest&per_page=100')
    assert complete_validation(run, jobs, source), 'All Simulator, startup, native and migration checks must pass'
    # Only this release automation and Markdown may differ from validated source.
    changed = subprocess.check_output(['git', 'diff', '--name-only', '--no-renames', source, 'HEAD'],
                                      cwd=ROOT, text=True).splitlines()
    assert all(path.endswith('.md') or path == '.github/workflows/loop_ai_live_update.yml'
               or path.startswith('Prototypes/AIFoodRecognition/Integration/NextUpdate/')
               for path in changed), 'Application or validation source changed after the successful run'
    for branch, expected in [('main', '548b33245198eaae165c094c9c68fe333cb69c05'),
                             ('feature/ai-food-recognition', 'cb4f6b1821489a27b06a36e378b0a7e5267bcbf1')]:
        assert api('git/ref/heads/' + branch)['object']['sha'] == expected, 'Protected branch changed'
    record = {'validation_source': source, 'validation_run': int(run_id),
              'candidate_source': os.environ['GITHUB_SHA'], 'application_source_unchanged': True,
              'validation_job': next(job['id'] for job in jobs['jobs'] if job['name'] == 'validate'),
              'independently_validated_for_therapy': False}
    (Path(os.environ['RUNNER_TEMP']) / 'NextValidation.json').write_text(json.dumps(record, indent=2) + '\n')
    print('Verified complete validation and unchanged application/test sources: ' + source)


if __name__ == '__main__':
    verify()
