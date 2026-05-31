import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parent.parent
GAME_STATE  = ROOT / "scripts" / "autoload" / "game_state.gd"
SAVE_MANAGER = ROOT / "scripts" / "autoload" / "save_manager.gd"
STAR_MAP    = ROOT / "scripts" / "ui" / "star_map_popup.gd"
BED_DETAIL  = ROOT / "scripts" / "ui" / "bed_detail_popup.gd"


class LivingShipResourcesTest(unittest.TestCase):
    def test_game_state_declares_resource_api(self):
        text = GAME_STATE.read_text(encoding="utf8")
        for token in [
            'const RESOURCE_IDS: Array = ["cp", "alloy", "supplies", "circuit"]',
            "var total_credits: int =",
            "var resources: Dictionary",
            '"alloy":',
            '"supplies":',
            '"circuit":',
            "signal resources_changed",
            "signal resource_changed",
            "func get_resource(",
            "func set_resource(",
            "func add_resource(",
            "func can_pay(",
            "func pay_cost(",
            "func format_cost(",
        ]:
            self.assertIn(token, text)

    def test_save_version_and_resources_are_persisted(self):
        text = SAVE_MANAGER.read_text(encoding="utf8")
        self.assertIn("const SAVE_VERSION := 5", text)
        self.assertIn('"resources":', text)
        self.assertIn("GameState.resources.duplicate()", text)
        self.assertIn("GameState.resources_changed.connect", text)
        self.assertIn('d.get("resources", {})', text)


    def test_direct_dispatch_grants_material_rewards(self):
        text = GAME_STATE.read_text(encoding="utf8")
        for token in [
            "func _roll_direct_dispatch_materials(",
            "_roll_direct_dispatch_materials()",
            "resources_collected.emit(mat_rewards)",
            'planet.get("guaranteed_rewards"',
            'planet.get("chance_rewards"',
        ]:
            self.assertIn(token, text)

    def test_bay_card_shows_preferred_region_hint(self):
        text = STAR_MAP.read_text(encoding="utf8")
        for token in [
            '_pp.get("preferred_regions", [])',
            'get("region_type", "")',
            "★ 선호",
        ]:
            self.assertIn(token, text)

    def test_bed_detail_shows_personality_and_preferred_region(self):
        text = BED_DETAIL.read_text(encoding="utf8")
        for token in [
            'pilot.get("personality", "")',
            'pilot.get("preferred_regions", [])',
            "func _region_label(",
        ]:
            self.assertIn(token, text)


if __name__ == "__main__":
    unittest.main()
