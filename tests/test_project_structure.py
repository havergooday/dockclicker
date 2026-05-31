import pathlib
import unittest
import re


ROOT = pathlib.Path(__file__).resolve().parent.parent


class ProjectStructureTest(unittest.TestCase):
    def test_godot_bootstrap_files_exist(self):
        required_paths = [
            "project.godot",
            "icon.svg",
            "docs/document-index.md",
            "docs/godot-project-structure.md",
            "docs/project-information.md",
            "docs/implemented-features.md",
            "docs/missing-features.md",
            "docs/ai-workflow.md",
            "docs/current-priorities.md",
            "docs/start-here.md",
            "docs/technical-decisions.md",
            "docs/commit-workflow.md",
            "docs/systems/README.md",
            "docs/systems/dispatch-loop.md",
            ".githooks/pre-commit",
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

    def test_project_targets_godot_4_6(self):
        project_text = (ROOT / "project.godot").read_text(encoding="utf8")
        self.assertRegex(project_text, re.compile(r'config/features=PackedStringArray\("4\.6"\)'))

    def test_legacy_panel_script_uids_are_removed(self):
        for relative_path in [
            "scripts/ui/panel_dispatch.gd.uid",
            "scripts/ui/panel_hangar.gd.uid",
            "scripts/ui/panel_shop.gd.uid",
            "scripts/ui/panel_workshop.gd.uid",
        ]:
            with self.subTest(path=relative_path):
                self.assertFalse((ROOT / relative_path).exists())


if __name__ == "__main__":
    unittest.main()
