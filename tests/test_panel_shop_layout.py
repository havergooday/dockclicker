import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parent.parent
PANEL_SHOP = ROOT / "scripts" / "ui" / "panel_shop.gd"


class PanelShopLayoutTest(unittest.TestCase):
    def test_pc_terminal_uses_left_menu_categories(self):
        text = PANEL_SHOP.read_text(encoding="utf8")
        self.assertIn('"id": "parts"', text)
        self.assertIn('"id": "upgrade"', text)
        self.assertIn('"id": "pilot"', text)

    def test_pc_terminal_declares_approved_width_constants(self):
        text = PANEL_SHOP.read_text(encoding="utf8")
        self.assertIn("const MENU_W", text)
        self.assertIn("const PILOT_LIST_W", text)
        self.assertIn("const CUSTOM_PREVIEW_W", text)

    def test_pc_terminal_has_custom_pilot_workspace_builders(self):
        text = PANEL_SHOP.read_text(encoding="utf8")
        self.assertIn("func _build_custom_pilot_content()", text)
        self.assertIn("func _build_custom_preview_pane()", text)
        self.assertIn("func _build_custom_form_pane()", text)

    def test_pc_terminal_declares_scroll_hooks(self):
        text = PANEL_SHOP.read_text(encoding="utf8")
        self.assertIn("ScrollContainer.new()", text)
        self.assertIn("func _wrap_with_scroll(", text)
        self.assertIn("var _scroll_positions", text)
        self.assertIn("func _capture_scroll_positions()", text)
        self.assertIn("func _restore_scroll_positions()", text)

    def test_pc_terminal_uses_compact_headers(self):
        text = PANEL_SHOP.read_text(encoding="utf8")
        self.assertNotIn('title.text = "카테고리"', text)
        self.assertIn("func _make_content_root() -> VBoxContainer:", text)


if __name__ == "__main__":
    unittest.main()
