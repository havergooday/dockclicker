import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parent.parent
DISPATCH_MANAGER = ROOT / "scripts" / "dispatch" / "dispatch_manager.gd"
SAVE_MANAGER     = ROOT / "scripts" / "autoload" / "save_manager.gd"
BAY_DETAIL       = ROOT / "scripts" / "ui" / "hangar_bay_detail.gd"
BAY_POPUP        = ROOT / "scripts" / "ui" / "hangar_bay_popup.gd"
GAME_STATE       = ROOT / "scripts" / "autoload" / "game_state.gd"
STAR_MAP         = ROOT / "scripts" / "ui" / "star_map_popup.gd"
PARTS_DATA       = ROOT / "data" / "parts_data.gd"


class LivingShipAutoRewardsTest(unittest.TestCase):
    def test_auto_slot_tracks_multi_resource_rewards(self):
        text = DISPATCH_MANAGER.read_text(encoding="utf8")
        for token in [
            "var rewards: Dictionary = {}",
            "rewards = {}",
            "func _roll_planet_rewards(",
            "func _grant_slot_rewards(",
            "slot.rewards = _roll_planet_rewards(slot.planet)",
            'slot.rewards["cp"]',
            "GameState.add_resource",
        ]:
            self.assertIn(token, text)

    def test_auto_slot_rewards_are_saved_and_loaded(self):
        save_text = SAVE_MANAGER.read_text(encoding="utf8")
        dispatch_text = DISPATCH_MANAGER.read_text(encoding="utf8")
        for token in [
            '"rewards":',
            "s.rewards.duplicate()",
        ]:
            self.assertIn(token, save_text)
        for token in [
            'd.get("rewards", {})',
            "slot.rewards =",
        ]:
            self.assertIn(token, dispatch_text)

    def test_reward_breakdown_recorded_saved_and_displayed(self):
        dm = DISPATCH_MANAGER.read_text(encoding="utf8")
        for token in [
            "var reward_breakdown: Dictionary = {}",
            "slot.reward_breakdown = {",
            '"raw_credits":',
            '"credits_mult":',
            '"pilot_credits_pct":',
            '"fatigue_penalty_pct":',
            '"yield_mult":',
            'd.get("reward_breakdown", {})',
        ]:
            self.assertIn(token, dm)
        save = SAVE_MANAGER.read_text(encoding="utf8")
        self.assertIn('"reward_breakdown":', save)
        self.assertIn("s.reward_breakdown.duplicate()", save)
        popup = BAY_POPUP.read_text(encoding="utf8")
        for token in [
            "func _add_reward_breakdown(",
            "기본 수익",
            "파츠 보너스",
            "파일럿 보너스",
            "피로 패널티",
            "정산 CR",
            "재료 보너스",
        ]:
            self.assertIn(token, popup)
        detail = BAY_DETAIL.read_text(encoding="utf8")
        self.assertIn("func _add_breakdown_lines(", detail)
        self.assertIn("_add_breakdown_lines(vb, slot)", detail)

    def test_offline_multi_cycle_simulated_for_auto_redispatch(self):
        text = DISPATCH_MANAGER.read_text(encoding="utf8")
        for token in [
            "func _ff_simulate_auto_cycles(",
            "_ff_simulate_auto_cycles(slot, now)",
            "slot.auto_redispatch and slot.auto_planet",
            "extra_cycles",
            "_roll_planet_rewards(slot.auto_planet)",
            "slot.state = \"offline\"",
        ]:
            self.assertIn(token, text)

    def test_reward_preview_shown_in_bay_ui(self):
        detail_text = BAY_DETAIL.read_text(encoding="utf8")
        for token in [
            "func _fmt_rewards(",
            "slot.rewards",
            '"합금"',
            '"물자"',
            '"칩"',
        ]:
            self.assertIn(token, detail_text)
        popup_text = BAY_POPUP.read_text(encoding="utf8")
        for token in [
            "func _fmt_rewards_text(",
            "_fmt_rewards_text(slot)",
        ]:
            self.assertIn(token, popup_text)

    def test_game_initial_values_are_playtestable(self):
        text = GAME_STATE.read_text(encoding="utf8")
        self.assertNotIn("var total_credits: int = 1000000000", text)
        self.assertNotIn('"alloy": 999999', text)

    def test_parts_dynamic_tier_from_options(self):
        gs_text = GAME_STATE.read_text(encoding="utf8")
        for token in [
            "func compute_part_tier(options: Array) -> int:",
            "options.is_empty()",
            "options.size() == 1",
        ]:
            self.assertIn(token, gs_text)

    def test_pilot_detail_popup_shows_living_state_and_personality(self):
        popup_text = (ROOT / "scripts" / "ui" / "pilot_detail_popup.gd").read_text(encoding="utf8")
        for token in [
            'pilot.get("personality", "")',
            'pilot.get("preferred_regions", [])',
            'pilot.get("fatigue", 0)',
            'pilot.get("stress", 0)',
            'pilot.get("mood", 70)',
            'pilot.get("exp", 0)',
            "EXP_PER_TIER",
            "func _region_label(",
        ]:
            self.assertIn(token, popup_text)

    def test_pilot_detail_status_bars_and_quote(self):
        text = (ROOT / "scripts" / "ui" / "pilot_detail_popup.gd").read_text(encoding="utf8")
        for token in [
            "func _stat_bar_row(",
            "func _build_status_quote(",
            "func _status_quote_text(",
            "ProgressBar.new()",
            '"fill"',
            '"background"',
            "상태 한마디",
        ]:
            self.assertIn(token, text)

    def test_ship_canvas_pilot_status_panel_removed(self):
        # 브릿지 파일럿 현황 패널(F/M 요약)은 제거됨 — 재추가 방지 가드
        text = STAR_MAP.parent / "ship_canvas.gd"
        canvas_text = text.read_text(encoding="utf8")
        for token in [
            "_pilot_status_panel",
            "_build_pilot_status_panel",
            "_refresh_pilot_status_panel",
        ]:
            self.assertNotIn(token, canvas_text)

    def test_direct_dispatch_applies_pilot_state_on_collect(self):
        gs_text = GAME_STATE.read_text(encoding="utf8")
        for token in [
            "func _apply_direct_dispatch_pilot_state(",
            "_apply_direct_dispatch_pilot_state()",
            'planet.get("fatigue_delta", 0)',
            'planet.get("stress_delta", 0)',
            "get_idle_pilots()",
            "apply_pilot_state_delta(",
        ]:
            self.assertIn(token, gs_text)

    def test_new_option_labels_shown_in_bay_popup(self):
        text = BAY_POPUP.read_text(encoding="utf8")
        for token in [
            '"fatigue_pct"',
            '"stress_pct"',
            '"material_yield_pct"',
        ]:
            self.assertIn(token, text)

    def test_star_map_detail_shows_preferred_region_fatigue_note(self):
        text = STAR_MAP.read_text(encoding="utf8")
        for token in [
            "fat_note",
            "str_note",
            "선호 -2",
        ]:
            self.assertIn(token, text)

    def test_auto_redispatch_ui_and_api(self):
        dm_text = DISPATCH_MANAGER.read_text(encoding="utf8")
        for token in [
            "func set_slot_auto_redispatch(",
            "slot.auto_redispatch = enabled",
            "slot.auto_pilot_id",
            "slot.auto_planet",
        ]:
            self.assertIn(token, dm_text)
        gs_text = GAME_STATE.read_text(encoding="utf8")
        self.assertIn("func set_slot_auto_redispatch(", gs_text)
        star_text = STAR_MAP.read_text(encoding="utf8")
        for token in [
            "slot.auto_redispatch",
            "GameState.set_slot_auto_redispatch(",
            "_refresh_bay_grid()",
        ]:
            self.assertIn(token, star_text)

    def test_parts_living_options_declared_and_applied(self):
        pd_text = PARTS_DATA.read_text(encoding="utf8")
        for token in [
            '"fatigue_pct"',
            '"stress_pct"',
            '"material_yield_pct"',
        ]:
            self.assertIn(token, pd_text)
        dm_text = DISPATCH_MANAGER.read_text(encoding="utf8")
        for token in [
            "func _opts_value_sum(",
            "_opts_value_sum(slot.machine, \"fatigue_pct\")",
            "_opts_value_sum(slot.machine, \"stress_pct\")",
            "_opts_value_sum(slot.machine, \"material_yield_pct\")",
            "yield_mult",
        ]:
            self.assertIn(token, dm_text)

    def test_return_completion_applies_planet_living_state_delta(self):
        text = DISPATCH_MANAGER.read_text(encoding="utf8")
        for token in [
            "func _apply_planet_pilot_state(slot: AutoSlot) -> void:",
            'planet.get("fatigue_delta", 0)',
            'planet.get("stress_delta", 0)',
            "fat_delta",
            "str_delta",
            "GameState.apply_pilot_state_delta(slot.pilot_id,",
            "_apply_planet_pilot_state(slot)",
        ]:
            self.assertIn(token, text)


if __name__ == "__main__":
    unittest.main()
