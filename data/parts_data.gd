class_name PartsData

const DAMAGE_UPGRADE_COSTS: Array = [20, 50, 100, 200]

const CLICK_RANGE_COSTS: Array  = [400, 1200, 3000]
const CLICK_RANGE_PX: Array     = [40.0, 80.0, 130.0]

const COMBO_COSTS: Array        = [600, 1800, 4500]
const COMBO_THRESHOLDS: Array   = [3, 5, 8]
const COMBO_MULTIPLIERS: Array  = [1.5, 2.0, 3.0]
const COMBO_WINDOW_SEC: float   = 0.8

const DICT: Dictionary = {
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
