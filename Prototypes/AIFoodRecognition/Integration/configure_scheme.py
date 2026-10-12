"""Finish workspace plugin products before Loop's dynamic plugin-copy phase."""
from pathlib import Path
import xml.etree.ElementTree as ET


def configure(path):
    tree = ET.parse(path)
    action = tree.getroot().find("BuildAction")
    if action is None:
        raise ValueError("The workspace build action is missing")
    entries = action.find("BuildActionEntries")
    if entries is None:
        raise ValueError("The workspace build entries are missing")
    loop = [entry for entry in entries if entry.find("BuildableReference") is not None
            and entry.find("BuildableReference").get("BlueprintName") == "Loop"]
    if len(loop) != 1:
        raise ValueError("Expected one Loop app build entry")
    # Scheme order is honored when target parallelization is disabled. Swift compilation
    # inside each target can still use multiple compiler jobs.
    action.set("parallelizeBuildables", "NO")
    entries.remove(loop[0])
    entries.append(loop[0])
    tree.write(path, encoding="UTF-8", xml_declaration=True)


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[3]
    configure(root / "LoopWorkspace.xcworkspace/xcshareddata/xcschemes/LoopWorkspace.xcscheme")
    print("Configured the workspace to finish plugins before building the Loop app.")
