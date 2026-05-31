import pathlib
import re
import unittest


ROOT = pathlib.Path(__file__).resolve().parent.parent
CREATURE_VISUAL_DATA = ROOT / "data" / "creature_visual_data.gd"
PLANET_DATA = ROOT / "data" / "planet_data.gd"
PANEL_CLICKER = ROOT / "scripts" / "ui" / "panel_clicker.gd"
IMPLEMENTED_FEATURES = ROOT / "docs" / "implemented-features.md"
MISSING_FEATURES = ROOT / "docs" / "missing-features.md"


class PlanetCreatureVisualsTest(unittest.TestCase):
    def test_creature_visual_data_covers_planet_regions(self):
        planet_text = PLANET_DATA.read_text(encoding="utf8")
        visual_text = CREATURE_VISUAL_DATA.read_text(encoding="utf8")
        regions = sorted(set(re.findall(r'"region_type": "([^"]+)"', planet_text)))
        self.assertGreaterEqual(len(regions), 4)
        for region in regions:
            self.assertIn(f'"{region}": [', visual_text)
        self.assertIn("class_name CreatureVisualData", visual_text)
        self.assertIn("static func get_variant(region_type: String, tier: int) -> Dictionary:", visual_text)

    def test_panel_clicker_uses_region_visuals_without_changing_spawn_state(self):
        text = PANEL_CLICKER.read_text(encoding="utf8")
        for token in [
            'const CreatureVisualData = preload("res://data/creature_visual_data.gd")',
            'var region_type := str(_planet_data.get("region_type", "scrap"))',
            "var visual := CreatureVisualData.get_variant(region_type, _planet_tier)",
            '"visual": visual,',
            "func _build_enemy_visual(enemy: Button, visual: Dictionary, hp: int, max_hp: int) -> void:",
            "func _clear_enemy_visual(enemy: Button) -> void:",
        ]:
            self.assertIn(token, text)

    def test_enemy_display_uses_child_nodes_instead_of_glyph_text(self):
        text = PANEL_CLICKER.read_text(encoding="utf8")
        self.assertIn("_clear_enemy_visual(enemy)", text)
        self.assertIn("_build_enemy_visual(enemy, d[\"visual\"], d[\"hp\"], d[\"max_hp\"])", text)
        self.assertNotIn('enemy.text = "%s\\n%d/%d"', text)

    def test_docs_track_creature_visual_mvp(self):
        implemented = IMPLEMENTED_FEATURES.read_text(encoding="utf8")
        missing = MISSING_FEATURES.read_text(encoding="utf8")
        self.assertIn("행성별 생물 비주얼 MVP", implemented)
        self.assertIn("실제 픽셀 아트 에셋 교체", missing)
        self.assertNotIn("현재 6종 글리프/이동 패턴 + 색상 구분까지 구현", missing)


if __name__ == "__main__":
    unittest.main()
