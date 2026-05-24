class_name PartsData

const DAMAGE_UPGRADE_COSTS: Array = [20, 50, 100, 200]

const DICT: Dictionary = {
	"pilot": {
		"name": "파일럿",
		"effect": "파견 슬롯 +%d",
		"tiers": [
			{"name": "신인 파일럿", "cost": 150, "value": 1, "required_planet": "sector_a"},
			{"name": "숙련 파일럿", "cost": 350, "value": 2, "required_planet": "sector_b"},
			{"name": "에이스 파일럿", "cost": 800, "value": 3, "required_planet": "sector_c"},
		]
	},
	"body": {
		"name": "몸체",
		"effect": "파견 시간 +%ds",
		"tiers": [
			{"name": "경량 프레임", "cost": 100, "value": 30},
			{"name": "표준 프레임", "cost": 280, "value": 75},
			{"name": "중장갑 프레임", "cost": 600, "value": 150},
		]
	},
	"weapon": {
		"name": "무기",
		"effect": "CR/s ×%d",
		"tiers": [
			{"name": "레이저 포", "cost": 80, "value": 2},
			{"name": "플라즈마 캐논", "cost": 220, "value": 5},
			{"name": "레일건", "cost": 500, "value": 12},
		]
	},
	"legs": {
		"name": "다리",
		"effect": "복귀 -%ds",
		"tiers": [
			{"name": "부스터 다리", "cost": 60, "value": 5},
			{"name": "제트 다리", "cost": 160, "value": 12},
			{"name": "워프 다리", "cost": 380, "value": 25},
		]
	},
}
