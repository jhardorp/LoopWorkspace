import tempfile
import unittest
from pathlib import Path
import xml.etree.ElementTree as ET
from configure_scheme import configure


class WorkspaceOrderTests(unittest.TestCase):
    def test_plugins_finish_before_loop_without_changing_target_definitions(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "Scheme.xcscheme"
            path.write_text('<Scheme><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>'
                            '<BuildActionEntry buildForArchiving="YES"><BuildableReference BlueprintName="Loop" BlueprintIdentifier="app"/></BuildActionEntry>'
                            '<BuildActionEntry buildForArchiving="YES"><BuildableReference BlueprintName="Plugin" BlueprintIdentifier="plugin"/></BuildActionEntry>'
                            '</BuildActionEntries></BuildAction><ArchiveAction buildConfiguration="Release"/></Scheme>')
            configure(path)
            root = ET.parse(path).getroot()
            action = root.find("BuildAction")
            self.assertEqual(action.get("parallelizeBuildables"), "NO")
            self.assertEqual(action.get("buildImplicitDependencies"), "YES")
            references = root.findall("./BuildAction/BuildActionEntries/BuildActionEntry/BuildableReference")
            self.assertEqual([(r.get("BlueprintName"), r.get("BlueprintIdentifier")) for r in references],
                             [("Plugin", "plugin"), ("Loop", "app")])
            self.assertEqual(root.find("ArchiveAction").get("buildConfiguration"), "Release")
            before = path.read_bytes()
            configure(path)
            self.assertEqual(path.read_bytes(), before)

    def test_missing_or_duplicate_app_entries_do_not_modify_the_file(self):
        for names in [[], ["Plugin"], ["Loop", "Loop"]]:
            with tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "Scheme.xcscheme"
                entries = ''.join(f'<BuildActionEntry><BuildableReference BlueprintName="{name}"/></BuildActionEntry>' for name in names)
                original = f'<Scheme><BuildAction><BuildActionEntries>{entries}</BuildActionEntries></BuildAction></Scheme>'
                path.write_text(original)
                with self.assertRaises(ValueError):
                    configure(path)
                self.assertEqual(path.read_text(), original)


if __name__ == "__main__":
    unittest.main()
