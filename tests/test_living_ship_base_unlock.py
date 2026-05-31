import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parent.parent
GAME_STATE = ROOT / "scripts" / "autoload" / "game_state.gd"
SAVE_MANAGER = ROOT / "scripts" / "autoload" / "save_manager.gd"
SHIP_CANVAS = ROOT / "scripts" / "ui" / "ship_canvas.gd"
FACILITY_MANAGEMENT = ROOT / "scripts" / "ui" / "facility_management_popup.gd"


class LivingShipBaseUnlockTest(unittest.TestCase):
    def test_game_state_declares_base_area_unlock_api(self):
        text = GAME_STATE.read_text(encoding="utf8")
        for token in [
            "var base_area_unlocks: Dictionary",
            "signal base_area_unlocks_changed",
            "func is_base_area_unlocked(",
            "func unlock_base_area(",
            "func get_base_area_data(",
            "BASE_AREA_DEFS",
            '"quarters"',
            '"lounge"',
            '"canteen"',
            '"medbay"',
        ]:
            self.assertIn(token, text)

    def test_save_manager_persists_base_area_unlocks(self):
        text = SAVE_MANAGER.read_text(encoding="utf8")
        for token in [
            '"base_area_unlocks"',
            "GameState.base_area_unlocks.duplicate(true)",
            'd.get("base_area_unlocks", {})',
            "GameState.base_area_unlocks =",
        ]:
            self.assertIn(token, text)

    def test_ship_canvas_mentions_locked_rooms_and_expansion_flow(self):
        text = SHIP_CANVAS.read_text(encoding="utf8")
        for token in [
            "base_area_unlocks_changed",
            "기지 해금",
            "구역 해금",
            "복구 필요",
            "unlock_base_area",
            "is_base_area_unlocked",
        ]:
            self.assertIn(token, text)

    def test_facility_management_separates_area_unlocks_from_installation(self):
        text = FACILITY_MANAGEMENT.read_text(encoding="utf8")
        for token in [
            'func _tab_caption(tab: String) -> String:',
            'TAB_FACILITIES: return "생활시설"',
            'TAB_ZONES: return "구역해금"',
            'if _selected_kind == "facility":',
            'GameState.install_facility(str(facility.get("slot_type", "")), _selected_id)',
            'elif _selected_kind == "feature":',
            'if feature_id == "quarters":',
            'unlock_confirm_requested.emit(',
            'elif GameState.unlock_feature(feature_id):',
        ]:
            self.assertIn(token, text)


if __name__ == "__main__":
    unittest.main()
