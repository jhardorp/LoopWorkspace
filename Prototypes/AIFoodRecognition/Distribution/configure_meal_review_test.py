import plistlib
import tempfile
import unittest
from pathlib import Path
from configure_meal_review import configure


class ConfigurationTests(unittest.TestCase):
    def test_preconfiguration_preserves_existing_app_settings(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "Info.plist"
            existing = {"CFBundleDisplayName": "Loop", "NSCameraUsageDescription": "Existing camera features"}
            path.write_bytes(plistlib.dumps(existing))
            code = "test-only-owner-access-code-for-a-local-fixture"
            configure(path, code)
            settings = plistlib.loads(path.read_bytes())
            self.assertEqual(settings["LoopMealReviewTesterAccessCode"], code)
            for key, value in existing.items():
                self.assertEqual(settings[key], value)

    def test_invalid_or_provider_keys_do_not_modify_the_plist(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "Info.plist"
            original = plistlib.dumps({"CFBundleDisplayName": "Loop"})
            for code in ["", "short", "x" * 257, "contains spaces" + "x" * 32,
                         "sk-test-only-not-a-real-provider-key", "x" * 32 + "\n"]:
                path.write_bytes(original)
                with self.assertRaises(ValueError):
                    configure(path, code)
                self.assertEqual(path.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
