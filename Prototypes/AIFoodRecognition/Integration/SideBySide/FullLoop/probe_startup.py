#!/usr/bin/env python3
"""Use the established normal-startup probe on the separate full-app identity."""
import argparse
import importlib.util
import os
from pathlib import Path
import plistlib
import shutil
import sys
import tempfile
from verify_product import IDENTITY

spec = importlib.util.spec_from_file_location('normal_probe', Path(__file__).resolve().parents[2] / 'probe_simulator_startup.py')
normal = importlib.util.module_from_spec(spec)
spec.loader.exec_module(normal)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--app', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--cleanup-only', action='store_true')
    args = parser.parse_args()
    if sys.platform != 'darwin' or os.environ.get('CI') != 'true' or os.environ.get('GITHUB_REF') != 'refs/heads/migration/loop4-ai-photo':
        raise SystemExit('Only macOS migration CI is allowed.')
    if args.cleanup_only:
        normal.main()
        raise SystemExit(0)
    if args.app is None:
        parser.error('--app is required')
    root = Path(__file__).resolve().parents[5]
    if 'NSStringFromClass(AppDelegate.self)' not in (root / 'Loop/Loop/main.swift').read_text():
        raise SystemExit('Normal app entry point is required.')
    app = args.app.resolve(strict=True)
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    if info.get('CFBundleSupportedPlatforms') != ['iPhoneSimulator'] or info.get('CFBundleIdentifier') != IDENTITY or 'UIApplicationSceneManifest' not in info:
        raise SystemExit('Expected the separate full Simulator app.')
    args.output.mkdir(parents=True, exist_ok=True)
    normal.prepare_device(args.output)
    with tempfile.TemporaryDirectory(prefix='FullLoopStartup-', dir=os.environ['RUNNER_TEMP']) as staging:
        copy = Path(staging) / app.name
        shutil.copytree(app, copy, symlinks=True)
        normal.probe(copy, info, args.output)
