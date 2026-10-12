"""Reuse a successful simulator check only when the app source is unchanged."""
import json
import os
from pathlib import Path
from urllib.request import Request, urlopen

ALLOWED = {
    ".github/workflows/food_recognition_loop.yml",
    "Prototypes/AIFoodRecognition/Integration/request.json",
    "Prototypes/AIFoodRecognition/Integration/fastlane/Fastfile",
    "Prototypes/AIFoodRecognition/Integration/reuse_validation.py",
    "Prototypes/AIFoodRecognition/Integration/reuse_validation_test.py",
}


def reusable(run, jobs, comparison, expected_source):
    if run.get("head_sha") != expected_source:
        return False
    if not any(step.get("name") == "Compile integrated Loop without signing" and step.get("conclusion") == "success"
               for job in jobs.get("jobs", []) for step in job.get("steps", [])):
        return False
    files = comparison.get("files", [])
    if len(files) >= 300 or comparison.get("total_commits", 0) > 10:
        return False
    return all(item.get("filename") in ALLOWED or item.get("filename", "").endswith(".md") for item in files)


def api(path):
    url = f"https://api.github.com/repos/{os.environ['GITHUB_REPOSITORY']}/{path}"
    request = Request(url, headers={
        "Authorization": f"Bearer {os.environ['ACTIONS_READ_TOKEN']}",
        "Accept": "application/vnd.github+json",
    })
    with urlopen(request, timeout=20) as response:
        return json.load(response)


if __name__ == "__main__":
    request = json.loads(Path(__file__).with_name("request.json").read_text())
    source, run_id = request.get("validatedSource"), request.get("validationRun")
    reuse = False
    if isinstance(source, str) and len(source) == 40 and all(c in "0123456789abcdef" for c in source) and type(run_id) is int:
        try:
            reuse = reusable(api(f"actions/runs/{run_id}"), api(f"actions/runs/{run_id}/jobs"),
                             api(f"compare/{source}...{os.environ['GITHUB_SHA']}"), source)
        except Exception:
            print("Previous validation could not be verified; a full simulator check is required.")
    with open(os.environ["GITHUB_OUTPUT"], "a") as output:
        output.write(f"reuse={'true' if reuse else 'false'}\n")
    print("Reusing the verified simulator build for unchanged app source." if reuse else "Running a full simulator build.")
