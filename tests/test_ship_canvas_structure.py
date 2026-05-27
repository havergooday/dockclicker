import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parent.parent
MAIN_SCENE = ROOT / "scenes" / "main" / "main.tscn"
SHIP_CANVAS_SCENE = ROOT / "scenes" / "ui" / "ship_canvas.tscn"
STAR_MAP_SCENE = ROOT / "scenes" / "ui" / "star_map_popup.tscn"
STAR_MAP_SCRIPT = ROOT / "scripts" / "ui" / "star_map_popup.gd"
GAME_STATE_SCRIPT = ROOT / "scripts" / "autoload" / "game_state.gd"


class ShipCanvasStructureTest(unittest.TestCase):
    def test_main_scene_uses_ship_canvas_root(self):
        text = MAIN_SCENE.read_text(encoding="utf8")
        self.assertIn("ship_canvas.tscn", text)
        self.assertNotIn("panel_dispatch.tscn", text)
        self.assertNotIn("panel_hangar.tscn", text)
        self.assertNotIn("panel_shop.tscn", text)
        self.assertNotIn("panel_workshop.tscn", text)

    def test_new_ship_canvas_and_star_map_assets_exist(self):
        self.assertTrue(SHIP_CANVAS_SCENE.exists())
        self.assertTrue(STAR_MAP_SCENE.exists())
        self.assertTrue(STAR_MAP_SCRIPT.exists())

    def test_star_map_script_declares_core_flow_methods(self):
        text = STAR_MAP_SCRIPT.read_text(encoding="utf8")
        self.assertIn("func open_for_control_room()", text)
        self.assertIn("func _select_planet(", text)
        self.assertIn("func _open_ship_popup(", text)
        self.assertIn("func _confirm_dispatch(", text)

    def test_game_state_exposes_auto_dispatch_wrapper(self):
        text = GAME_STATE_SCRIPT.read_text(encoding="utf8")
        self.assertIn("func start_auto_dispatch(", text)


if __name__ == "__main__":
    unittest.main()
