import pathlib
import re
import unittest


ROOT = pathlib.Path(__file__).resolve().parent.parent
PLANET_DATA = ROOT / "data" / "planet_data.gd"
PARTS_DATA = ROOT / "data" / "parts_data.gd"

LATE_SECTOR_IDS = [
	"sector_i",
	"sector_j",
	"sector_k",
	"sector_l",
	"sector_m",
	"sector_n",
	"sector_o",
	"sector_p",
	"sector_q",
	"sector_r",
	"sector_s",
	"sector_t",
]


def _extract_tier_values(text: str, part_id: str) -> list[int]:
	pattern = rf'"{re.escape(part_id)}"\s*:\s*\{{.*?"tiers":\s*\[(?P<tiers>.*?)\]\s*\}}'
	match = re.search(pattern, text, re.S)
	if match is None:
		raise AssertionError(f"missing part block for {part_id}")
	return [int(v) for v in re.findall(r'"value":\s*(\d+)', match.group("tiers"))]


def _extract_array_values(text: str, token: str) -> list[int]:
	match = re.search(rf'{re.escape(token)}\s*=\s*\[(?P<body>.*?)\]', text, re.S)
	if match is None:
		raise AssertionError(f"missing array for {token}")
	return [int(v) for v in re.findall(r'\d+', match.group("body"))]


def _extract_sector_cp(text: str, sector_id: str) -> tuple[int, int, int]:
	start_token = f'"id": "{sector_id}"'
	start = text.find(start_token)
	if start < 0:
		raise AssertionError(f"missing planet block for {sector_id}")
	end_match = re.search(r'^\t\},\s*$', text[start:], re.M)
	if end_match is None:
		raise AssertionError(f"missing planet block terminator for {sector_id}")
	block = text[start:start + end_match.start()]
	credit_match = re.search(r'"credit_per_kill":\s*(\d+)', block)
	cp_match = re.search(r'"cp":\s*\[(\d+),\s*(\d+)\]', block)
	if credit_match is None or cp_match is None:
		raise AssertionError(f"missing economy values for {sector_id}")
	return int(credit_match.group(1)), int(cp_match.group(1)), int(cp_match.group(2))


class EconomySimulationTest(unittest.TestCase):
	def test_late_game_auto_dispatch_cp_curve_stays_in_hundreds(self):
		planet_text = PLANET_DATA.read_text(encoding="utf8")
		rows = []
		for sector_id in LATE_SECTOR_IDS:
			credit_per_kill, cp_min, cp_max = _extract_sector_cp(planet_text, sector_id)
			cp_mid = (cp_min + cp_max) / 2.0
			next_unlock = int(re.search(rf'"id": "{re.escape(sector_id)}".*?"unlock_cost":\s*(\d+)', planet_text, re.S).group(1))
			if sector_id != "sector_t":
				idx = LATE_SECTOR_IDS.index(sector_id)
				next_unlock = int(re.search(rf'"id": "{re.escape(LATE_SECTOR_IDS[idx + 1])}".*?"unlock_cost":\s*(\d+)', planet_text, re.S).group(1))
				cycles = next_unlock / (1800.0 + cp_mid)
				rows.append((sector_id, cp_mid, cycles))

		for sector_id, _cp_mid, cycles in rows:
			self.assertGreaterEqual(cycles, 300.0, sector_id)
			self.assertLessEqual(cycles, 800.0, sector_id)

	def test_late_game_t3_cycle_reward_is_front_loaded_for_cp_but_still_material_focused(self):
		planet_text = PLANET_DATA.read_text(encoding="utf8")
		parts_text = PARTS_DATA.read_text(encoding="utf8")

		body_values = _extract_tier_values(parts_text, "body")
		weapon_values = _extract_tier_values(parts_text, "weapon")
		self.assertGreaterEqual(len(body_values), 3)
		self.assertGreaterEqual(len(weapon_values), 3)

		body_duration = body_values[2]
		weapon_rate = weapon_values[2]
		raw_cycle_cp = body_duration * weapon_rate
		self.assertEqual(raw_cycle_cp, 1800)

		sector_rows = []
		for sector_id in LATE_SECTOR_IDS:
			credit_per_kill, cp_min, cp_max = _extract_sector_cp(planet_text, sector_id)
			cp_mid = (cp_min + cp_max) / 2.0
			cycle_cp = raw_cycle_cp + cp_mid
			sector_rows.append((sector_id, credit_per_kill, cycle_cp))

		self.assertGreater(sector_rows[-1][2], sector_rows[0][2])
		self.assertGreater(sector_rows[-1][2], 1_000_000)

	def test_average_late_game_direct_cp_outpaces_auto_dispatch_on_representative_sectors(self):
		planet_text = PLANET_DATA.read_text(encoding="utf8")
		parts_text = PARTS_DATA.read_text(encoding="utf8")

		damage_costs = _extract_array_values(parts_text, "const DAMAGE_UPGRADE_COSTS: Array")
		click_range_values = _extract_array_values(parts_text, "const CLICK_RANGE_PX: Array")
		combo_multipliers = _extract_array_values(parts_text, "const COMBO_MULTIPLIERS: Array")

		click_damage = 1 + (len(damage_costs) // 2)
		click_rate = 4.0
		click_range_px = float(click_range_values[1])
		target_count = max(1, int(round(click_range_px / 40.0)))
		combo_multiplier = float(combo_multipliers[1])
		auto_attack_bonus_dps = (float(click_damage) / 2.0) / 1.5

		def direct_cp_per_hour(sector_id: str) -> float:
			credit_per_kill, cp_min, cp_max = _extract_sector_cp(planet_text, sector_id)
			enemy_hp = int(re.search(
				rf'"id": "{re.escape(sector_id)}".*?"enemy_hp":\s*(\d+)',
				planet_text,
				re.S,
			).group(1))
			effective_dps = float(click_damage) * click_rate * combo_multiplier * target_count + auto_attack_bonus_dps
			kills_per_hour = (effective_dps / float(enemy_hp)) * 3600.0
			return kills_per_hour * float(credit_per_kill)

		def auto_cp_per_hour(sector_id: str) -> float:
			credit_per_kill, cp_min, cp_max = _extract_sector_cp(planet_text, sector_id)
			cp_mid = (cp_min + cp_max) / 2.0
			cycle_cp = 1800.0 + cp_mid
			cycle_seconds = 150.0 + 5.0
			return cycle_cp * (3600.0 / cycle_seconds)

		for sector_id in ["sector_j", "sector_k"]:
			direct = direct_cp_per_hour(sector_id)
			auto = auto_cp_per_hour(sector_id)
			self.assertGreater(direct, auto * 1.1, sector_id)


if __name__ == "__main__":
	unittest.main()
