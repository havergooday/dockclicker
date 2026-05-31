import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parent.parent
PLANET_DATA = ROOT / "data" / "planet_data.gd"


class LivingShipPlanetRewardsTest(unittest.TestCase):
    def test_mvp_planets_have_living_ship_reward_fields(self):
        text = PLANET_DATA.read_text(encoding="utf8")
        for token in [
            '"region_type"',
            '"primary_rewards"',
            '"guaranteed_rewards"',
            '"chance_rewards"',
            '"risk_level"',
            '"stress_delta"',
            '"fatigue_delta"',
            "폐기 위성",
            "교역 항로",
            "버려진 도시",
            "생태 행성",
        ]:
            self.assertIn(token, text)


if __name__ == "__main__":
    unittest.main()
