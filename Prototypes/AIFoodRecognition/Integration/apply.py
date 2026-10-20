#!/usr/bin/env python3
"""Apply the reviewed overlay only to this workspace's pinned Loop source."""
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
LOOP = ROOT / "Loop"
PIN = "b55744981c2e589799754d19f73b8912c8809e12"

if subprocess.check_output(["git", "-C", str(LOOP), "rev-parse", "HEAD"], text=True).strip() != PIN:
    raise SystemExit("Loop source pin changed. Rebase and validate the meal-review overlay before building.")
patch = Path(__file__).with_name("LoopMealReview.patch")
subprocess.run(["git", "-C", str(LOOP), "apply", "--check", str(patch)], check=True)
subprocess.run(["git", "-C", str(LOOP), "apply", str(patch)], check=True)
print("Applied meal review to the pinned Loop carbohydrate-entry screen.")
