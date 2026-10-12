#!/usr/bin/env python3
"""Preconfigure only the owner's tester login in a signed app's build-time plist."""
import argparse
import os
import plistlib
from pathlib import Path


def configure(path: Path, tester_code: str) -> None:
    if not 32 <= len(tester_code) <= 256 or tester_code.startswith("sk-") or any(
        not 33 <= ord(character) <= 126 for character in tester_code
    ):
        raise ValueError("FOOD_TESTER_ACCESS_CODE must contain the separate tester login.")
    with path.open("rb") as source:
        settings = plistlib.load(source)
    settings["LoopMealReviewTesterAccessCode"] = tester_code
    settings.setdefault("NSCameraUsageDescription", "Photograph a meal for AI carbohydrate review.")
    with path.open("wb") as destination:
        plistlib.dump(settings, destination, fmt=plistlib.FMT_XML, sort_keys=False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--plist", type=Path, required=True)
    options = parser.parse_args()
    configure(options.plist, os.environ.get("FOOD_TESTER_ACCESS_CODE", ""))
    print("Meal review login preconfigured for this personal build.")
