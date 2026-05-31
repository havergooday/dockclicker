import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parent.parent
HANGAR_BAY_POPUP = ROOT / "scripts" / "ui" / "hangar_bay_popup.gd"
IMPLEMENTED_FEATURES = ROOT / "docs" / "implemented-features.md"
MISSING_FEATURES = ROOT / "docs" / "missing-features.md"


class MechSpriteCompositionTest(unittest.TestCase):
    def test_popup_declares_layered_mech_sprite_helpers(self):
        text = HANGAR_BAY_POPUP.read_text(encoding="utf8")
        for token in [
            'const MECH_PART_DRAW_ORDER: Array = ["legs", "body", "weapon"]',
            "var _part_sprite_cache: Dictionary = {}",
            "func _build_mech_preview(slot: DispatchManager.AutoSlot, accent: Color) -> Control:",
            "func _add_mech_part_layer(root: Control, part_key: String, tier: int, rect: Rect2) -> void:",
            "func _mech_part_texture(part_key: String, tier: int) -> Texture2D:",
        ]:
            self.assertIn(token, text)

    def test_machine_panel_renders_preview_before_equipment_slots(self):
        text = HANGAR_BAY_POPUP.read_text(encoding="utf8")
        preview_idx = text.index("_build_mech_preview(slot, accent)")
        body_idx = text.index('_build_equipment_slot("body", slot, accent')
        self.assertLess(preview_idx, body_idx)
        self.assertIn("for part_key: String in MECH_PART_DRAW_ORDER:", text)
        self.assertIn("_add_mech_part_layer(preview, part_key, tier, rect)", text)

    def test_part_slot_textures_use_generated_mech_textures(self):
        text = HANGAR_BAY_POPUP.read_text(encoding="utf8")
        self.assertIn("return _mech_part_texture(part_key, tier)", text)
        self.assertIn('var cache_key := "%s:%d" % [part_key, tier]', text)
        self.assertIn("_part_sprite_cache[cache_key] = texture", text)

    def test_docs_move_mech_sprite_mvp_to_implemented(self):
        implemented = IMPLEMENTED_FEATURES.read_text(encoding="utf8")
        missing = MISSING_FEATURES.read_text(encoding="utf8")
        self.assertIn("메크 스프라이트 조합 시스템 MVP", implemented)
        self.assertNotIn("**메크 스프라이트 조합 시스템**", missing)


if __name__ == "__main__":
    unittest.main()
