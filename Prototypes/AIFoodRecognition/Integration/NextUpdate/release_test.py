import unittest
from release import ARTIFACTS, ARCHIVE_SOURCE, BACKEND_SOURCE, BUNDLE, GROUP, IPA_HASH, SOURCE, VALIDATION, artifact_matches, candidate_matches


class ReleaseArtifactTests(unittest.TestCase):
    def test_exact_artifacts_pass_and_changed_digest_size_source_or_expiry_reject(self):
        for expected in ARTIFACTS.values():
            run, source, size, digest = expected
            value = {'expired': False, 'size_in_bytes': size, 'digest': digest,
                     'workflow_run': {'id': run, 'head_sha': source}}
            self.assertTrue(artifact_matches(value, expected))
            for key, replacement in [('expired', True), ('size_in_bytes', size + 1), ('digest', 'other'),
                                     ('workflow_run', {'id': run, 'head_sha': 'other'}),
                                     ('workflow_run', {'id': run + 1, 'head_sha': source})]:
                self.assertFalse(artifact_matches({**value, key: replacement}, expected), key)

    def test_backend_artifact_cannot_replace_signed_app_artifact(self):
        expected = ARTIFACTS[12928092541]
        other = ARTIFACTS[12936348558]
        value = {'expired': False, 'size_in_bytes': other[2], 'digest': other[3],
                 'workflow_run': {'id': other[0], 'head_sha': other[1]}}
        self.assertFalse(artifact_matches(value, expected))

    def test_changed_app_identity_hash_confirmation_or_source_rejects(self):
        value = {'candidate_source': ARCHIVE_SOURCE, 'validation_source': SOURCE,
                 'validation_run': VALIDATION, 'ipa_sha256': IPA_HASH, 'application_source_unchanged': True,
                 'signature_verified': True, 'bundle': BUNDLE, 'app_group': GROUP,
                 'version': '3.15.2', 'build': '28', 'uploaded': False, 'device_installed': False}
        self.assertTrue(candidate_matches(value))
        for key, replacement in [('candidate_source', BACKEND_SOURCE), ('validation_source', 'other'),
                                 ('validation_run', 0), ('ipa_sha256', 'other'), ('bundle', 'other'),
                                 ('app_group', 'other'), ('version', '0.1.0'), ('build', '27'),
                                 ('signature_verified', False), ('application_source_unchanged', False),
                                 ('uploaded', True), ('device_installed', True)]:
            self.assertFalse(candidate_matches({**value, key: replacement}), key)

    def test_missing_proof_never_passes(self):
        self.assertFalse(candidate_matches({}))
        for expected in ARTIFACTS.values():
            self.assertFalse(artifact_matches({}, expected))


if __name__ == '__main__':
    unittest.main()
