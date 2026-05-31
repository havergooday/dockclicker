import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parent.parent
CREDIT_HUD = ROOT / "scripts" / "ui" / "credit_hud.gd"
STAR_MAP = ROOT / "scripts" / "ui" / "star_map_popup.gd"
BED_DETAIL = ROOT / "scripts" / "ui" / "bed_detail_popup.gd"
BRIDGE_PILOT = ROOT / "scripts" / "ui" / "bridge_pilot.gd"
SHIP_CANVAS = ROOT / "scripts" / "ui" / "ship_canvas.gd"
GAME_STATE = ROOT / "scripts" / "autoload" / "game_state.gd"
DISPATCH = ROOT / "scripts" / "dispatch" / "dispatch_manager.gd"


class LivingShipUITextTest(unittest.TestCase):
    def test_credit_hud_declares_resource_display_hooks(self):
        text = CREDIT_HUD.read_text(encoding="utf8")
        for token in [
            "var _resource_labels: Dictionary",
            "GameState.resources_changed.connect",
            "GameState.resource_changed.connect",
            'for id in ["alloy", "supplies", "circuit"]',
            'text = _resource_abbr(id)',
            "func _refresh_resources()",
            "func _resource_abbr(",
        ]:
            self.assertIn(token, text)

    def test_hud_position_option(self):
        gs = GAME_STATE.read_text(encoding="utf8")
        for token in [
            'var hud_position: String = "right"',
            "signal hud_position_changed(pos: String)",
            "func set_hud_position(pos: String) -> void:",
            '["top", "bottom", "left", "right"]',
        ]:
            self.assertIn(token, gs)
        hud = CREDIT_HUD.read_text(encoding="utf8")
        for token in [
            "func _apply_pill_anchors(",
            "func _rebuild_hud()",
            "GameState.hud_position_changed.connect",
            'GameState.hud_position in ["left", "right"]',
        ]:
            self.assertIn(token, hud)
        save = (ROOT / "scripts" / "autoload" / "save_manager.gd").read_text(encoding="utf8")
        self.assertIn('"hud_position":', save)
        self.assertIn('d.get("hud_position", "right")', save)
        canvas = SHIP_CANVAS.read_text(encoding="utf8")
        for token in [
            "상태표시줄",
            "GameState.set_hud_position(pos_id)",
        ]:
            self.assertIn(token, canvas)

    def test_star_map_detail_shows_living_ship_reward_fields(self):
        text = STAR_MAP.read_text(encoding="utf8")
        for token in [
            'planet.get("primary_rewards"',
            'planet.get("risk_level"',
            'planet.get("fatigue_delta"',
            'planet.get("stress_delta"',
            "주요 보상",
            "위험도",
            "피로",
            "스트레스",
            "func _format_primary_rewards(",
        ]:
            self.assertIn(token, text)

    def test_bed_detail_cards_show_full_pilot_living_state(self):
        text = BED_DETAIL.read_text(encoding="utf8")
        for token in [
            'pilot.get("fatigue", 0)',
            'pilot.get("stress", 0)',
            'pilot.get("mood", 70)',
            '"피로"',
            '"스트레스"',
            '"기분"',
            "func _living_state_label(",
            "func _living_state_color(",
        ]:
            self.assertIn(token, text)

    def test_roaming_pilot_shows_three_status_values(self):
        pilot_text = BRIDGE_PILOT.read_text(encoding="utf8")
        for token in [
            "var _mood_label: Label = null",
            "var _fatigue_label: Label = null",
            "var _stress_label: Label = null",
            "var _activity_label: Label = null",
            "func _build_mood_label()",
            "func _refresh_mood_label()",
            "func _make_status_label(",
            "func _status_color_hi_bad(",
            '_fatigue_label.text = "피로 %d" % fatigue',
            '_stress_label.text = "스트 %d" % stress',
            '_mood_label.text = "기분 %d" % mood',
            '_activity_label.text = "활동 %s" % _activity_text(current_activity)',
            'pilot_data.get("fatigue", 0)',
            'pilot_data.get("stress", 0)',
            'pilot_data.get("mood", 70)',
            "func _activity_text(activity: String) -> String:",
            "func _activity_color(activity: String) -> Color:",
        ]:
            self.assertIn(token, pilot_text)

        canvas_text = SHIP_CANVAS.read_text(encoding="utf8")
        for token in [
            "GameState.pilot_status_changed.connect",
            "func _refresh_bridge_pilot_data(",
            'node.call("update_pilot_data", p)',
        ]:
            self.assertIn(token, canvas_text)

    def test_resources_collected_signal_and_flytext(self):
        gs_text = GAME_STATE.read_text(encoding="utf8")
        self.assertIn("signal resources_collected(rewards: Dictionary)", gs_text)

        dm_text = DISPATCH.read_text(encoding="utf8")
        self.assertIn("GameState.resources_collected.emit(rewards_to_grant)", dm_text)

        hud_text = CREDIT_HUD.read_text(encoding="utf8")
        for token in [
            "GameState.resources_collected.connect(_on_resources_collected)",
            "func _on_resources_collected(rewards: Dictionary)",
            "_resource_abbr(",
            'parts.append("+%d CR"',
            "tween.tween_callback(fly.queue_free)",
        ]:
            self.assertIn(token, hud_text)


if __name__ == "__main__":
    unittest.main()
