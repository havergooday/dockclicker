import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parent.parent
HANGAR_ZONE = ROOT / "scripts" / "ui" / "hangar_zone.gd"
DISPATCH_MANAGER = ROOT / "scripts" / "dispatch" / "dispatch_manager.gd"
CURRENT_PRIORITIES = ROOT / "docs" / "current-priorities.md"
IMPLEMENTED_FEATURES = ROOT / "docs" / "implemented-features.md"
MISSING_FEATURES = ROOT / "docs" / "missing-features.md"


class HangarLeftExpansionRulesTest(unittest.TestCase):
    def test_dispatch_manager_keeps_four_stable_hangar_groups(self):
        text = DISPATCH_MANAGER.read_text(encoding="utf8")
        self.assertIn("const HANGAR_COSTS: Array  = [0, 5000, 50000, 500000]", text)
        self.assertIn("for g in 4:", text)
        self.assertIn("hg.locked = g > 0", text)
        self.assertIn("AutoSlot.make_locked(BAY_COSTS[b] if b > 0 else 0, g)", text)

    def test_hangar_zone_declares_named_expansion_order(self):
        text = HANGAR_ZONE.read_text(encoding="utf8")
        for token in [
            "const LEFT_EXPANSION_GROUPS: Array = [3, 2]",
            "const CENTER_GROUP := 0",
            "const RIGHT_EXPANSION_GROUPS: Array = [1]",
            "func _visual_group_order() -> Array:",
            "return LEFT_EXPANSION_GROUPS + [CENTER_GROUP] + RIGHT_EXPANSION_GROUPS",
        ]:
            self.assertIn(token, text)

    def test_hangar_zone_centers_group_zero_once_and_preserves_scroll_afterwards(self):
        text = HANGAR_ZONE.read_text(encoding="utf8")
        for token in [
            "var _did_initial_center := false",
            "func _restore_or_center_scroll() -> void:",
            "if not _did_initial_center:",
            "_center_on_group(CENTER_GROUP)",
            "_scroll_ref.scroll_horizontal = _bay_scroll_pos",
            "call_deferred(\"_restore_or_center_scroll\")",
        ]:
            self.assertIn(token, text)

    def test_hangar_zone_uses_left_expansion_labels(self):
        text = HANGAR_ZONE.read_text(encoding="utf8")
        for token in [
            "func _hangar_group_title(g_idx: int) -> String:",
            '"중앙 격납고"',
            '"좌측 확장"',
            '"우측 확장"',
            "_hangar_group_title(g_idx)",
        ]:
            self.assertIn(token, text)

    def test_docs_describe_left_expansion_rules_as_complete(self):
        priorities = CURRENT_PRIORITIES.read_text(encoding="utf8")
        implemented = IMPLEMENTED_FEATURES.read_text(encoding="utf8")
        missing = MISSING_FEATURES.read_text(encoding="utf8")

        self.assertIn("격납고 좌측 확장 규칙 구성~~ ✓", priorities)
        self.assertIn("격납고 확장 규칙 구현 완료", implemented)
        self.assertIn("시각 순서 `[3, 2, 0, 1]`", implemented)
        self.assertNotIn("격납고 좌측 확장", missing)


if __name__ == "__main__":
    unittest.main()
