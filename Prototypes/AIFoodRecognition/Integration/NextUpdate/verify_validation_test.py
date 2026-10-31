import copy
import unittest
from verify_validation import REQUIRED_STEPS, complete_validation


class ValidationReuseTests(unittest.TestCase):
    def setUp(self):
        self.source = 'a' * 40
        self.run = {'head_sha': self.source, 'conclusion': 'success',
                    'head_branch': 'migration/loop4-ai-photo', 'workflow_id': 390255385,
                    'path': '.github/workflows/loop_ai_migration_validate.yml'}
        self.jobs = {'jobs': [{'name': 'validate', 'conclusion': 'success',
                              'steps': [{'name': name, 'conclusion': 'success'} for name in REQUIRED_STEPS]}]}

    def test_all_checks_allow_reuse(self):
        self.assertTrue(complete_validation(self.run, self.jobs, self.source))

    def test_wrong_source_branch_workflow_or_failed_run_cannot_reuse(self):
        for field, value in [('head_sha', 'b' * 40), ('conclusion', 'failure'),
                             ('head_branch', 'main'), ('workflow_id', 0), ('path', 'other.yml')]:
            self.assertFalse(complete_validation({**self.run, field: value}, self.jobs, self.source), field)

    def test_each_missing_or_skipped_required_check_rejects_reuse(self):
        for name in REQUIRED_STEPS:
            jobs = copy.deepcopy(self.jobs)
            next(step for step in jobs['jobs'][0]['steps'] if step['name'] == name)['conclusion'] = 'skipped'
            self.assertFalse(complete_validation(self.run, jobs, self.source), name)

    def test_empty_failed_or_ambiguous_job_rejects_reuse(self):
        for jobs in [{'jobs': []}, {'jobs': [{'name': 'validate', 'conclusion': 'failure', 'steps': []}]},
                     {'jobs': self.jobs['jobs'] * 2}]:
            self.assertFalse(complete_validation(self.run, jobs, self.source))


if __name__ == '__main__':
    unittest.main()
