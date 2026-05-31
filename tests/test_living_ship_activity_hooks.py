import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parent.parent
BRIDGE_PILOT = ROOT / "scripts" / "ui" / "bridge_pilot.gd"
SHIP_CANVAS = ROOT / "scripts" / "ui" / "ship_canvas.gd"


class LivingShipActivityHooksTest(unittest.TestCase):
    def test_bridge_pilot_eat_trigger_uses_dine_table_threshold(self):
        text = BRIDGE_PILOT.read_text(encoding="utf8")
        for token in [
            'GameState.get_installed_facility("table") == "dine_table_1"',
            "eat_threshold",
        ]:
            self.assertIn(token, text)

    def test_bridge_pilot_eat_tick_boosted_by_canteen(self):
        text = BRIDGE_PILOT.read_text(encoding="utf8")
        for token in [
            'GameState.is_feature_unlocked("canteen")',
            "mood_gain",
        ]:
            self.assertIn(token, text)

    def test_bridge_pilot_declares_activity_state_and_provider(self):
        text = BRIDGE_PILOT.read_text(encoding="utf8")
        for token in [
            'var current_activity: String = "wander"',
            "var target_point: Vector2",
            "var activity_until: float",
            "var _activity_tick_accum: float",
            "var activity_point_provider: Callable",
            "func set_activity_point_provider(",
            'activity_point_provider.call("rest")',
            'activity_point_provider.call("play")',
            'activity_point_provider.call("eat")',
            'activity_point_provider.call("recover")',
            'pilot_data.get("fatigue", 0)',
            'pilot_data.get("stress", 0)',
            'pilot_data.get("mood", 70)',
            "func _process_activity_tick(",
            'current_activity == "rest"',
            'current_activity == "play"',
            'current_activity == "eat"',
            'current_activity == "recover"',
            'current_activity != "recover"',
            'GameState.apply_pilot_state_delta(pid, {"fatigue": -2, "mood": 1 + fav_bonus})',
            'GameState.apply_pilot_state_delta(pid, {"stress": -2, "mood": 1 + fav_bonus})',
            'GameState.apply_pilot_state_delta(pid, {"mood": mood_gain + fav_bonus})',
            'GameState.apply_pilot_state_delta(pid, {"stress": -2, "fatigue": -1 - fav_bonus})',
            'REST_LINES',
            '_show_bubble(REST_LINES',
            'PLAY_LINES',
            '_show_bubble(PLAY_LINES',
            'EAT_LINES',
            '_show_bubble(EAT_LINES',
            'RECOVER_LINES',
            '_show_bubble(RECOVER_LINES',
        ]:
            self.assertIn(token, text)

    def test_ship_canvas_exposes_activity_points_to_bridge_pilots(self):
        text = SHIP_CANVAS.read_text(encoding="utf8")
        for token in [
            "func get_activity_points(",
            'facility.get("activity", "") == activity',
            'facility.get("use_point", Vector2.ZERO)',
            'Callable(self, "get_activity_points")',
            "set_activity_point_provider",
        ]:
            self.assertIn(token, text)


if __name__ == "__main__":
    unittest.main()
