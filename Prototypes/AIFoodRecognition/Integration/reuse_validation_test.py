import copy
import unittest
from reuse_validation import reusable


class ValidationReuseTests(unittest.TestCase):
    source = "a" * 40

    def setUp(self):
        self.run = {"head_sha": self.source, "conclusion": "failure"}
        self.jobs = {"jobs": [{"steps": [{"name": "Compile integrated Loop without signing", "conclusion": "success"}]}]}
        self.comparison = {"total_commits": 1, "files": [{"filename": "Prototypes/AIFoodRecognition/Integration/fastlane/Fastfile"}]}

    def test_signing_only_change_reuses_the_completed_compile_even_if_upload_failed(self):
        self.assertTrue(reusable(self.run, self.jobs, self.comparison, self.source))

    def test_application_source_or_submodule_changes_require_another_compile(self):
        for name in ["Loop", "LoopKit", "Prototypes/AIFoodRecognition/PrototypeApp/FoodRecognitionView.swift",
                     "Prototypes/AIFoodRecognition/Integration/LoopMealReview.patch", "Prototypes/AIFoodRecognition/Package.swift"]:
            changed = copy.deepcopy(self.comparison)
            changed["files"] = [{"filename": name}]
            self.assertFalse(reusable(self.run, self.jobs, changed, self.source), name)

    def test_wrong_source_failed_compile_or_truncated_comparison_cannot_skip(self):
        self.assertFalse(reusable({"head_sha": "b" * 40}, self.jobs, self.comparison, self.source))
        self.jobs["jobs"][0]["steps"][0]["conclusion"] = "failure"
        self.assertFalse(reusable(self.run, self.jobs, self.comparison, self.source))
        self.jobs["jobs"][0]["steps"][0]["conclusion"] = "success"
        self.comparison["files"] *= 300
        self.assertFalse(reusable(self.run, self.jobs, self.comparison, self.source))


if __name__ == "__main__":
    unittest.main()
