import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parent.parent
FACILITY_POPUP = ROOT / "scripts" / "ui" / "facility_management_popup.gd"
FACILITY_POPUP_SCENE = ROOT / "scenes" / "ui" / "facility_management_popup.tscn"
SHIP_CANVAS = ROOT / "scripts" / "ui" / "ship_canvas.gd"
HANGAR_ZONE = ROOT / "scripts" / "ui" / "hangar_zone.gd"


class LivingShipFacilityManagementTest(unittest.TestCase):
    def test_facility_management_popup_declares_purchase_and_unlock_flow(self):
        self.assertTrue(FACILITY_POPUP.exists())
        text = FACILITY_POPUP.read_text(encoding="utf8")
        for token in [
            "extends Control",
            "func open_popup()",
            "func close_popup()",
            "set_anchors_preset(Control.PRESET_FULL_RECT)",
            "const POPUP_W_RATIO := 0.74",
            "const PANEL_V_PAD := 6",
            "const DETAIL_W := 320",
            "func _build_tabs_row()",
            "func _build_catalog_pane()",
            "func _build_detail_pane()",
            "func _refresh_catalog()",
            "func _refresh_detail()",
            '"시설관리"',
            '"생활시설"',
            '"구역해금"',
            "GameState.FACILITIES",
            "GameState.install_facility",
            "GameState.unlock_feature",
            "signal unlock_confirm_requested",
        ]:
            self.assertIn(token, text)

    def test_facility_management_popup_has_same_scene_root_contract_as_control_room_popups(self):
        self.assertTrue(FACILITY_POPUP_SCENE.exists())
        text = FACILITY_POPUP_SCENE.read_text(encoding="utf8")
        for token in [
            'path="res://scripts/ui/facility_management_popup.gd"',
            '[node name="FacilityManagementPopup" type="Control"]',
            "layout_mode = 3",
            "anchors_preset = 15",
            "anchor_right = 1.0",
            "anchor_bottom = 1.0",
        ]:
            self.assertIn(token, text)

    def test_ship_canvas_opens_facility_management_and_confirms_quarters_unlock(self):
        text = SHIP_CANVAS.read_text(encoding="utf8")
        for token in [
            'preload("res://scenes/ui/facility_management_popup.tscn")',
            "FACILITY_POPUP_SCENE.instantiate()",
            '_register_popup("facilities"',
            '"facilities"',
            '"시설관리"',
            "func _open_facility_management()",
            "func _open_unlock_confirm(",
            '"숙소 해금"',
            'GameState.unlock_feature("quarters")',
        ]:
            self.assertIn(token, text)

    def test_hangar_zone_uses_popup_confirmation_for_bay_and_hangar_unlocks(self):
        text = HANGAR_ZONE.read_text(encoding="utf8")
        for token in [
            "func _show_unlock_confirm_popup(",
            "func _hide_unlock_confirm_popup()",
            '"해금 진행"',
            "GameState.unlock_auto_slot(index)",
            "GameState.unlock_hangar(g_idx)",
        ]:
            self.assertIn(token, text)


if __name__ == "__main__":
    unittest.main()
