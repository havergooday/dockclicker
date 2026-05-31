import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parent.parent
GAME_STATE   = ROOT / "scripts" / "autoload" / "game_state.gd"
SAVE_MANAGER = ROOT / "scripts" / "autoload" / "save_manager.gd"
PILOTS_DATA  = ROOT / "data" / "pilots_data.gd"
SHOP_POPUP   = ROOT / "scripts" / "ui" / "shop_popup.gd"
BRIDGE_PILOT = ROOT / "scripts" / "ui" / "bridge_pilot.gd"
BAY_POPUP    = ROOT / "scripts" / "ui" / "hangar_bay_popup.gd"
FACILITY_DATA = ROOT / "data" / "facility_data.gd"
FACILITY_MGMT = ROOT / "scripts" / "ui" / "facility_management_popup.gd"
PARTS_SHOP   = ROOT / "scripts" / "ui" / "parts_shop_popup.gd"
SHIP_CANVAS  = ROOT / "scripts" / "ui" / "ship_canvas.gd"
DISPATCH     = ROOT / "scripts" / "dispatch" / "dispatch_manager.gd"
BED_DETAIL   = ROOT / "scripts" / "ui" / "bed_detail_popup.gd"


class LivingShipPilotStateTest(unittest.TestCase):
    def test_game_state_adds_living_state_to_new_pilots(self):
        text = GAME_STATE.read_text(encoding="utf8")
        for token in [
            "func _with_pilot_living_state(",
            '"fatigue":        int(source.get("fatigue", 0))',
            '"stress":         int(source.get("stress", 0))',
            '"mood":           int(source.get("mood", 70))',
            '"preferred_regions": source.get("preferred_regions", []).duplicate()',
            '"favorite_facilities": source.get("favorite_facilities", []).duplicate()',
            "_with_pilot_living_state({",
            "func apply_pilot_state_delta(",
            "clampi(int(pilot.get(id, 0)) + int(deltas[id]), 0, 100)",
        ]:
            self.assertIn(token, text)

    def test_save_manager_persists_and_migrates_living_state(self):
        text = SAVE_MANAGER.read_text(encoding="utf8")
        for token in [
            '"fatigue":        int(pd.get("fatigue",        0))',
            '"stress":         int(pd.get("stress",         0))',
            '"mood":           int(pd.get("mood",           70))',
            '"preferred_regions": preferred_regions.duplicate()',
            '"favorite_facilities": favorite_facilities.duplicate()',
            '"fatigue":        p.get("fatigue",        0)',
            '"stress":         p.get("stress",         0)',
            '"mood":           p.get("mood",           70)',
        ]:
            self.assertIn(token, text)

    def test_pilots_data_has_personality_and_favorite_facilities(self):
        text = PILOTS_DATA.read_text(encoding="utf8")
        for token in [
            '"personality"',
            '"favorite_facilities"',
            '"활발함"',
            '"차분함"',
            '"사교적"',
            '"독립적"',
            '"rest"',
            '"play"',
            '"eat"',
            '"recover"',
        ]:
            self.assertIn(token, text)

    def test_shop_popup_shows_personality_tag(self):
        text = SHOP_POPUP.read_text(encoding="utf8")
        for token in [
            'p.get("personality", "")',
            'p.get("favorite_facilities", [])',
            "func _activity_label(",
            "join(fav_names)",
        ]:
            self.assertIn(token, text)

    def test_bridge_pilot_applies_favorite_facility_bonus(self):
        text = BRIDGE_PILOT.read_text(encoding="utf8")
        for token in [
            'pilot_data.get("favorite_facilities", [])',
            "fav_bonus",
            "current_activity in fav",
        ]:
            self.assertIn(token, text)

    def test_facility_data_has_upgrade_tiers(self):
        text = FACILITY_DATA.read_text(encoding="utf8")
        for token in [
            '"id": "sofa_2"',
            '"id": "game_console_2"',
            '"upgrades_from": "sofa_1"',
            '"upgrades_from": "game_console_1"',
        ]:
            self.assertIn(token, text)

    def test_facility_management_shows_upgrade_option(self):
        text = FACILITY_MGMT.read_text(encoding="utf8")
        for token in [
            '"upgrades_from"',
            "is_upgrade",
            '"업그레이드"',
        ]:
            self.assertIn(token, text)

    def test_bay_popup_shows_assigned_pilot(self):
        text = BAY_POPUP.read_text(encoding="utf8")
        for token in [
            'slot.assigned_pilot_id',
            'slot.state in ["offline", "empty"]',
            '_add_option_line(opt_box,',
            'ap_color',
        ]:
            self.assertIn(token, text)

    def test_facility_data_has_all_upgrade_tiers(self):
        text = FACILITY_DATA.read_text(encoding="utf8")
        for token in [
            '"id": "dine_table_2"',
            '"id": "coffee_machine_2"',
            '"id": "medical_kit_2"',
            '"upgrades_from": "dine_table_1"',
            '"upgrades_from": "coffee_machine_1"',
            '"upgrades_from": "medical_kit_1"',
        ]:
            self.assertIn(token, text)

    def test_bridge_pilot_uses_personality_greetings(self):
        text = BRIDGE_PILOT.read_text(encoding="utf8")
        for token in [
            "PERSONALITY_GREETINGS",
            'pilot_data.get("personality", "")',
            "PERSONALITY_GREETINGS.get(personality, GREETINGS)",
        ]:
            self.assertIn(token, text)

    def test_parts_shop_has_facility_tab(self):
        text = PARTS_SHOP.read_text(encoding="utf8")
        for token in [
            '"facility"',
            "signal open_facility_management_requested",
            "func _build_facility_body(",
            "func _refresh_facility_body(",
            "open_facility_management_requested.emit()",
        ]:
            self.assertIn(token, text)
        canvas_text = SHIP_CANVAS.read_text(encoding="utf8")
        self.assertIn("open_facility_management_requested.connect", canvas_text)

    def test_fatigue_applies_dispatch_penalty(self):
        text = DISPATCH.read_text(encoding="utf8")
        for token in [
            'pilot.get("fatigue", 0)',
            "fatigue >= 90",
            "fatigue >= 70",
            "fatigue_penalty_pct = 20",
            "fatigue_penalty_pct = 10",
            "(1.0 - float(fatigue_penalty_pct) / 100.0)",
        ]:
            self.assertIn(token, text)

    def test_preferred_regions_reduce_pilot_state_delta(self):
        dispatch_text = DISPATCH.read_text(encoding="utf8")
        for token in [
            'pilot.get("preferred_regions", [])',
            'planet.get("region_type", "")',
            "fat_delta = maxi(0, fat_delta - 2)",
            "str_delta = maxi(0, str_delta - 2)",
        ]:
            self.assertIn(token, dispatch_text)
        pilot_text = PILOTS_DATA.read_text(encoding="utf8")
        for token in [
            '"preferred_regions": ["scrap"]',
            '"preferred_regions": ["trade"]',
            '"preferred_regions": ["city_ruins"]',
        ]:
            self.assertIn(token, pilot_text)

    def test_shop_popup_shows_exp_for_hired_pilots(self):
        text = SHOP_POPUP.read_text(encoding="utf8")
        for token in [
            'GameState.get_hired_pilot(',
            "EXP_PER_TIER",
            "EXP %d / %d",
        ]:
            self.assertIn(token, text)

    def test_pilot_growth_system(self):
        gs_text = GAME_STATE.read_text(encoding="utf8")
        for token in [
            "signal pilot_tier_up(pilot_id: String)",
            "const EXP_PER_TIER: Array",
            "func add_pilot_exp(",
            "func _check_tier_up(",
            '"exp":            int(source.get("exp", 0))',
            'hired_pilots[idx]["tier"] = tier + 1',
            'hired_pilots[idx]["exp"] = 0',
            "pilot_tier_up.emit(",
        ]:
            self.assertIn(token, gs_text)

    def test_dispatch_grants_exp_on_mission_complete(self):
        text = DISPATCH.read_text(encoding="utf8")
        for token in [
            "func _grant_mission_exp(",
            "_grant_mission_exp(slot)",
            "GameState.add_pilot_exp(",
            "risk_level",
            "exp_gain",
        ]:
            self.assertIn(token, text)

    def test_save_manager_persists_exp_and_personality(self):
        text = SAVE_MANAGER.read_text(encoding="utf8")
        for token in [
            '"exp":            p.get("exp",            0)',
            '"personality":    p.get("personality",    "")',
            '"exp":            int(pd.get("exp",            0))',
            '"personality":    str(pd.get("personality",    ""))',
        ]:
            self.assertIn(token, text)

    def test_bed_detail_shows_exp_progress(self):
        text = BED_DETAIL.read_text(encoding="utf8")
        for token in [
            'pilot.get("exp", 0)',
            "EXP_PER_TIER",
            "EXP %d / %d",
        ]:
            self.assertIn(token, text)

    def test_game_state_declares_quarters_rest_tick(self):
        text = GAME_STATE.read_text(encoding="utf8")
        for token in [
            "var _quarters_rest_accumulator",
            "func apply_quarters_rest_tick(",
            "func _process(",
            "get_pilot_bed_pos(",
            '"fatigue": -1',
            '"mood": 1',
        ]:
            self.assertIn(token, text)


if __name__ == "__main__":
    unittest.main()
