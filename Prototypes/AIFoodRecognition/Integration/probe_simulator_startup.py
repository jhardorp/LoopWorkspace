#!/usr/bin/env python3
"""Launch the normal app in a disposable Simulator; never touches a physical device."""
import argparse
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import time


def run(*args, timeout=120):
    try:
        return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT, timeout=timeout)
    except subprocess.CalledProcessError as error:
        print(error.output[-16000:], file=sys.stderr)
        raise
    except subprocess.TimeoutExpired as error:
        partial = error.output or b""
        if isinstance(partial, bytes):
            partial = partial.decode(errors="replace")
        print(partial[-16000:], file=sys.stderr)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if sys.platform != "darwin" or os.environ.get("CI") != "true" or os.environ.get("GITHUB_REF") != "refs/heads/migration/loop4-ai-photo":
        raise SystemExit("Startup probe is restricted to macOS migration CI.")

    root = Path(__file__).resolve().parents[3]
    loop = root / "Loop"
    if run("git", "-C", str(loop), "rev-parse", "HEAD").strip() != "b55744981c2e589799754d19f73b8912c8809e12":
        raise SystemExit("Unexpected Loop source pin.")
    if "NSStringFromClass(AppDelegate.self)" not in (loop / "Loop/main.swift").read_text():
        raise SystemExit("Probe must run before replacing the real application entry point.")

    app = args.app.resolve(strict=True)
    info = plistlib.loads((app / "Info.plist").read_bytes())
    if info.get("CFBundleSupportedPlatforms") != ["iPhoneSimulator"] or "UIApplicationSceneManifest" not in info:
        raise SystemExit("Expected the normal Simulator app with its original scene configuration.")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="LoopStartup-", dir=os.environ["RUNNER_TEMP"]) as staging:
        copy = Path(staging) / app.name
        shutil.copytree(app, copy, symlinks=True)
        probe(copy, info, output, loop)


def probe(app, info, output, loop):
    bundle = info["CFBundleIdentifier"]
    executable = info["CFBundleExecutable"]

    # Ad-hoc Simulator signing has no Apple identity, provisioning profile or upload.
    # The unsigned build remains a separate check. Siri checks require this entitlement
    # even on Simulator; retain the app's original entitlements and expanded app group.
    entitlements = plistlib.loads((loop / "Loop/Loop.entitlements").read_bytes())
    entitlements["com.apple.security.application-groups"] = [info["AppGroupIdentifier"]]
    entitlements_path = output / "simulator-entitlements.plist"
    entitlements_path.write_bytes(plistlib.dumps(entitlements))
    # Only this disposable copy is ad-hoc signed, including its embedded bundles.
    # No signed app product is retained or distributed, and the build/test host is untouched.
    run("codesign", "--force", "--deep", "--sign", "-", str(app))
    run("codesign", "--force", "--sign", "-", "--entitlements", str(entitlements_path), str(app))

    catalog = json.loads(run("xcrun", "simctl", "list", "--json"))
    runtimes = [r for r in catalog["runtimes"] if r.get("isAvailable") and r["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS-")]
    runtime = max(runtimes, key=lambda r: tuple(int(v) for v in r["version"].split(".")))
    supported = {d["identifier"] if isinstance(d, dict) else d for d in runtime.get("supportedDeviceTypes", [])}
    device_type = next(d for d in catalog["devicetypes"] if d["name"].startswith("iPhone") and (not supported or d["identifier"] in supported))
    device = run("xcrun", "simctl", "create", "Loop AI migration startup", device_type["identifier"], runtime["identifier"]).strip()
    report = {"bundle": bundle, "runtime": runtime["version"], "device": device, "status": "failed", "phase": "boot", "scope": "Normal app launch only; onboarding, live photos, provider requests and therapy behavior are not validated."}
    try:
        run("xcrun", "simctl", "boot", device)
        run("xcrun", "simctl", "bootstatus", device, "-b", timeout=180)
        # A full Loop bundle includes all pinned plugins and companion bundles.
        # Installation on a freshly booted CI Simulator can exceed two minutes.
        report["phase"] = "install"
        run("xcrun", "simctl", "install", device, str(app), timeout=600)
        report["phase"] = "launch"
        launched = run("xcrun", "simctl", "launch", "--terminate-running-process", device, bundle)
        (output / "launch.txt").write_text(launched)
        match = re.search(r":\s*(\d+)\s*$", launched)
        if not match:
            raise RuntimeError("simctl did not return the launched app PID.")
        pid = match.group(1)
        report["phase"] = "process-survival"
        for _ in range(3):
            time.sleep(5)
            command = run("ps", "-p", pid, "-o", "command=").strip()
            if f"/{app.name}/{executable}" not in command:
                raise RuntimeError("The normal app did not remain running.")
        run("xcrun", "simctl", "io", device, "screenshot", str(output / "startup.png"))
        report["status"] = "passed"
        report["phase"] = "complete"
        print(f"Normal Loop startup stayed running for 15 seconds on iOS {runtime['version']}. Screenshot retained. This is not end-to-end validation.")
    except Exception as error:
        report["error"] = str(error)
        raise
    finally:
        # Diagnostics and cleanup must not hide the original measurement failure.
        try:
            logs = subprocess.run(["xcrun", "simctl", "spawn", device, "log", "show", "--last", "5m", "--style", "compact", "--predicate", 'process == "Loop" OR process == "installd" OR process == "containermanagerd"'], capture_output=True, text=True, timeout=30)
            (output / "application.log").write_text((logs.stdout + logs.stderr)[-200000:])
        except subprocess.TimeoutExpired:
            report["diagnostics_timeout"] = True
        for command in [("terminate", device, bundle), ("shutdown", device), ("delete", device)]:
            try:
                subprocess.run(["xcrun", "simctl", *command], capture_output=True, timeout=30)
            except subprocess.TimeoutExpired:
                report.setdefault("cleanup_timeouts", []).append(command[0])
        (output / "result.json").write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
