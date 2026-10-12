import contextlib
import io
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from compile_simulator import compile_loop


class SimulatorBuildTests(unittest.TestCase):
    manifest_error = "error: Framework /tmp/Loop.app/Frameworks/G7SensorPlugin.framework did not contain an Info.plist (in target 'Loop' from project 'Loop')\n"

    def build(self, outcomes):
        commands = []
        def runner(command, stdout, stderr):
            commands.append(list(command))
            code, text = outcomes[len(commands) - 1]
            stdout.write(text)
            return SimpleNamespace(returncode=code)
        with tempfile.TemporaryDirectory() as directory, contextlib.redirect_stdout(io.StringIO()):
            result = compile_loop(["fixture-build", "same-derived-data"], Path(directory) / "build.log", runner)
        return result, commands

    def test_missing_manifests_retry_the_same_incremental_build(self):
        result, commands = self.build([(65, self.manifest_error), (0, "BUILD SUCCEEDED\n")])
        self.assertEqual(result, 0)
        self.assertEqual(commands, [["fixture-build", "same-derived-data"]] * 2)

    def test_source_error_mixed_with_manifest_error_does_not_retry(self):
        result, commands = self.build([(65, self.manifest_error + "View.swift:12: error: cannot find type\n")])
        self.assertEqual(result, 65)
        self.assertEqual(len(commands), 1)

    def test_a_second_manifest_failure_is_reported(self):
        result, commands = self.build([(65, self.manifest_error)] * 2)
        self.assertEqual(result, 65)
        self.assertEqual(len(commands), 2)

    def test_unclassified_failure_is_reported_without_retry(self):
        result, commands = self.build([(137, "Process killed\n")])
        self.assertEqual(result, 137)
        self.assertEqual(len(commands), 1)

    def test_success_is_not_repeated(self):
        result, commands = self.build([(0, "BUILD SUCCEEDED\n")])
        self.assertEqual(result, 0)
        self.assertEqual(len(commands), 1)


if __name__ == "__main__":
    unittest.main()
