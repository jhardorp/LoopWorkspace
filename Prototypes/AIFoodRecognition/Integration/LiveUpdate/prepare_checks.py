"""Add migration-only fixtures to a disposable CI checkout; never patch the app."""
import base64
from datetime import datetime
import json
import os
from pathlib import Path
import plistlib
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent

if os.environ.get("GITHUB_ACTIONS") != "true" or os.environ.get("GITHUB_REF") != "refs/heads/migration/loop4-ai-photo":
    raise SystemExit("Migration CI checkout required")
pin = subprocess.check_output(["git", "-C", str(ROOT / "LoopKit"), "rev-parse", "HEAD"], text=True).strip()
assert pin == "031c16f574efaf73255b398d48479b19cd8d45b0"

def dates(value):
    if isinstance(value, dict):
        return {key: dates(item) for key, item in value.items()}
    if isinstance(value, list):
        return [dates(item) for item in value]
    if isinstance(value, str) and len(value) == 20 and value.endswith("Z"):
        try:
            return datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ")
        except ValueError:
            pass
    return value

legacy = dates(json.loads((HERE / "LegacyStoredSettings.json").read_text()))
blob = base64.b64encode(plistlib.dumps(legacy, fmt=plistlib.FMT_BINARY)).decode()
path = ROOT / "LoopKit/LoopKitTests/Persistence/PersistenceControllerMigrationTests.swift"
text = path.read_text()
assert "testProductionV4SettingsAndHistorySurviveUpgrade" not in text
path.write_text(text + "\n" + (HERE / "MigrationTests.swift").read_text().replace("LEGACY_SETTINGS_BASE64", blob))
# Several workspace dependencies call their scheme Shared. Give LoopKit's
# real test bundle a unique workspace scheme, with the correct container path.
scheme = ET.parse(ROOT / "LoopKit/LoopKit.xcodeproj/xcshareddata/xcschemes/Shared.xcscheme")
for ref in scheme.getroot().iter("BuildableReference"):
    ref.set("ReferencedContainer", "container:LoopKit/LoopKit.xcodeproj")
testables = scheme.getroot().find("TestAction/Testables")
for test in list(testables):
    if test.find("BuildableReference").get("BlueprintName") != "LoopKitTests":
        testables.remove(test)
scheme.write(ROOT / "LoopWorkspace.xcworkspace/xcshareddata/xcschemes/LoopKitMigration.xcscheme", encoding="UTF-8", xml_declaration=True)
print("Added two disposable v4 settings/history migration regressions, including repeat launch and a non-default insulin model.")
