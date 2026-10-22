#!/usr/bin/env python3
"""Fail closed on source drift or accidental production/signing/backend changes."""
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
LOCK = json.loads(Path(__file__).with_name('upstream-lock.json').read_text())
def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], text=True).strip()

assert git('branch', '--show-current') in ('migration/loop4-ai-photo', ''), 'Wrong branch'
for name, pin in LOCK['submodules'].items():
    row = git('ls-tree', 'HEAD', '--', name)
    assert row.split()[2] == pin, f'Gitlink drift: {name}'
    if (ROOT/name/'.git').exists():
        actual = subprocess.check_output(['git', '-C', str(ROOT/name), 'rev-parse', 'HEAD'], text=True).strip()
        assert actual == pin, f'Checkout drift: {name}'
protected = ['LoopConfigOverride.xcconfig', 'fastlane', '.github/workflows/food_recognition_loop.yml',
             '.github/workflows/build_loop.yml', '.github/workflows/build_loop_auto.yml',
             '.github/workflows/food_recognition_backend.yml', 'Prototypes/AIFoodRecognition/Backend',
             'Prototypes/AIFoodRecognition/Distribution', 'Prototypes/AIFoodRecognition/Integration/fastlane',
             'Prototypes/AIFoodRecognition/Integration/request.json']
assert not git('diff', '--name-only', LOCK['production'], '--', *protected), 'Protected configuration changed'
patch = Path(__file__).with_name('LoopMealReview.patch').read_text()
allowed = {'Loop/Views/CarbEntryView.swift', 'Loop/View Models/CarbEntryViewModel.swift',
           'Loop/Views/BolusEntryView.swift', 'LoopTests/ViewModels/BolusEntryViewModelTests.swift'}
changed = {line[4:].strip() for line in patch.splitlines() if line.startswith('+++ ')}
assert changed == {'b/'+p for p in allowed}, f'Unexpected native overlay scope: {changed}'
print('Pinned workspace/dependencies and protected production configuration verified.')
