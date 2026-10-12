"""Compile Loop, retrying once only for incomplete embedded plugin manifests."""
import os
import re
import subprocess
from pathlib import Path


def compile_loop(command, log_path, run_command=subprocess.run):
    for attempt in range(2):
        with log_path.open("w") as output:
            result = run_command(command, stdout=output, stderr=subprocess.STDOUT).returncode
        lines = log_path.read_text(errors="replace").splitlines()
        print("\n".join(lines[-150:]))
        errors = [line for line in lines if re.search(r"\berror:", line)]
        missing_plugin_manifests = errors and all(
            re.fullmatch(r"error: Framework .* did not contain an Info\.plist \(.*\)", line.strip())
            for line in errors
        )
        if result == 0 or attempt == 1 or not missing_plugin_manifests:
            return result
        print("Retrying the same build incrementally after incomplete plugin manifest copies.")
    raise AssertionError("Unreachable")


if __name__ == "__main__":
    temporary = Path(os.environ["RUNNER_TEMP"])
    command = [
        "xcodebuild", "-workspace", "LoopWorkspace.xcworkspace", "-scheme", "LoopWorkspace",
        "-destination", "generic/platform=iOS Simulator",
        "-derivedDataPath", str(temporary / "LoopMealReviewUnsigned"),
        "CODE_SIGNING_ALLOWED=NO", "build",
    ]
    raise SystemExit(compile_loop(command, temporary / "LoopMealReviewCompile.log"))
