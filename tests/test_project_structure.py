import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parent.parent


class ProjectStructureTest(unittest.TestCase):
    def test_godot_bootstrap_files_exist(self):
        required_paths = [
            "project.godot",
            "icon.svg",
            "docs/godot-project-structure.md",
            "docs/plans/2026-05-21-godot-bootstrap.md",
            "scenes/main/main.tscn",
            "scripts/autoload/game_state.gd",
            "scripts/core/app_root.gd",
            "scripts/ui/main_panel.gd",
            "data/README.md",
            "assets/README.md",
        ]

        for relative_path in required_paths:
            with self.subTest(path=relative_path):
                self.assertTrue((ROOT / relative_path).exists())


if __name__ == "__main__":
    unittest.main()
