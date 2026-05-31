import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parent.parent
FACILITY_DATA = ROOT / "data" / "facility_data.gd"
GAME_STATE = ROOT / "scripts" / "autoload" / "game_state.gd"
SAVE_MANAGER = ROOT / "scripts" / "autoload" / "save_manager.gd"
SHIP_CANVAS = ROOT / "scripts" / "ui" / "ship_canvas.gd"


class LivingShipFacilitiesTest(unittest.TestCase):
    def test_facility_data_declares_sofa(self):
        self.assertTrue(FACILITY_DATA.exists())
        text = FACILITY_DATA.read_text(encoding="utf8")
        for token in [
            "class_name FacilityData",
            '"id": "sofa_1"',
            '"slot_type": "rest"',
            '"cost": {"cp": 120, "supplies": 3}',
            '"activity": "rest"',
            '"fatigue_recover": 2',
            '"use_point": Vector2',
        ]:
            self.assertIn(token, text)

    def test_facility_data_declares_game_console(self):
        text = FACILITY_DATA.read_text(encoding="utf8")
        for token in [
            '"id": "game_console_1"',
            '"slot_type": "table"',
            '"cost": {"cp": 150, "supplies": 1, "circuit": 2}',
            '"activity": "play"',
            '"stress_recover": 2',
            '"use_point": Vector2(1792, 192)',
        ]:
            self.assertIn(token, text)

    def test_facility_data_declares_coffee_machine(self):
        text = FACILITY_DATA.read_text(encoding="utf8")
        for token in [
            '"id": "coffee_machine_1"',
            '"slot_type": "service"',
            '"cost": {"cp": 180, "supplies": 4, "circuit": 1}',
            '"activity": "eat"',
            '"mood_recover": 2',
            '"use_point": Vector2(2048, 192)',
        ]:
            self.assertIn(token, text)

    def test_facility_data_declares_dine_table(self):
        text = FACILITY_DATA.read_text(encoding="utf8")
        for token in [
            '"id": "dine_table_1"',
            '"slot_type": "table"',
            '"cost": {"cp": 160, "supplies": 5}',
            '"activity": "eat"',
            '"mood_recover": 3',
        ]:
            self.assertIn(token, text)

    def test_game_state_declares_canteen_feature(self):
        text = GAME_STATE.read_text(encoding="utf8")
        self.assertIn('"id": "canteen"', text)
        self.assertIn('"cost": 3000', text)

    def test_facility_data_declares_medical_kit(self):
        text = FACILITY_DATA.read_text(encoding="utf8")
        for token in [
            '"id": "medical_kit_1"',
            '"slot_type": "medical"',
            '"activity": "recover"',
            '"stress_recover": 2',
            '"fatigue_recover": 1',
        ]:
            self.assertIn(token, text)

    def test_game_state_declares_lounge_facility_api(self):
        text = GAME_STATE.read_text(encoding="utf8")
        for token in [
            'preload("res://data/facility_data.gd")',
            "const FACILITIES:",
            "var lounge_slots: Dictionary",
            '"medical": ""',
            "signal facilities_changed",
            "func get_facility_data(",
            "func install_facility(",
            "func remove_facility(",
            "func get_installed_facility(",
            "pay_cost(facility.get",
        ]:
            self.assertIn(token, text)

    def test_facilities_are_saved_and_rendered(self):
        save_text = SAVE_MANAGER.read_text(encoding="utf8")
        for token in [
            '"lounge_slots":',
            "GameState.lounge_slots.duplicate()",
            "GameState.facilities_changed.connect",
            'd.get("lounge_slots", {})',
        ]:
            self.assertIn(token, save_text)
        canvas_text = SHIP_CANVAS.read_text(encoding="utf8")
        for token in [
            "var _lounge_facility_layer",
            "func _refresh_lounge_facilities(",
            "GameState.facilities_changed.connect",
            "GameState.get_installed_facility",
            '"시설관리"',
            "func _open_facility_management()",
            'card.add_child(_make_placeable_drag_handle(placeable_id, "lounge"))',
            "card.custom_minimum_size = Vector2(144, 56)",
            "_facility_slot_caption(",
            "_facility_activity_caption(",
            '"%s · %s" % [',
        ]:
            self.assertIn(token, canvas_text)


if __name__ == "__main__":
    unittest.main()
