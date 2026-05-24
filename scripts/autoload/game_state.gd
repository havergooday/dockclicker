extends Node

var layout_mode := "horizontal"
var dispatch_preselect_slot: int = -1
var total_credits: int = 1000000
var pending_credits: int = 0
var player_status: String = "idle"  # idle / on_mission / returned
var click_damage: int = 1
var damage_upgrade_level: int = 0
var unlocked_planets: Array = ["sector_a"]
var selected_planet: String = "sector_a"
# 파츠 보유 수량: owned_parts[part_type][tier_index] = 보유 수량 (tier_index: 0=Lv.1, 1=Lv.2, 2=Lv.3)
var owned_parts: Dictionary = {
	"pilot": [0, 0, 0],
	"body":  [0, 0, 0],
	"weapon":[0, 0, 0],
	"legs":  [0, 0, 0],
}

# 자동 파견 슬롯
# state: locked | empty | offline | on_mission | returning | returned
var auto_slots: Array = [
	{"state": "empty"},
	{"state": "locked", "unlock_cost": 300},
	{"state": "locked", "unlock_cost": 700},
]

const PLANETS: Array = [
	{
		"id": "sector_a",
		"name": "섹터 A",
		"unlock_cost": 0,
		"max_on_screen": 2,
		"wave_size": 5,
		"credit_per_kill": 10,
		"enemy_hp": 2,
	},
	{
		"id": "sector_b",
		"name": "섹터 B",
		"unlock_cost": 50,
		"max_on_screen": 3,
		"wave_size": 8,
		"credit_per_kill": 15,
		"enemy_hp": 3,
	},
	{
		"id": "sector_c",
		"name": "섹터 C",
		"unlock_cost": 200,
		"max_on_screen": 4,
		"wave_size": 12,
		"credit_per_kill": 25,
		"enemy_hp": 5,
	},
]

const DAMAGE_UPGRADE_COSTS: Array = [20, 50, 100, 200]

# 파츠 종류별 데이터
# pilot: 자동 파견 슬롯 수 (자동 파견 구현 시 적용)
# body: 파견 지속 시간 +N초 (자동 파견 구현 시 적용)
# weapon: 자동 파견 CR/s 배율 (자동 파견 구현 시 적용)
# legs: 복귀 소요 시간 -N초 (자동 파견 구현 시 적용)
const PARTS: Dictionary = {
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

signal credits_changed(new_total: int)
signal credits_collected(amount: int, from_global_pos: Vector2)
signal player_status_changed(status: String)
signal planet_unlocked(planet_id: String)
signal part_purchased(part_type: String, tier: int)
signal auto_slot_changed(index: int)
signal auto_dispatch_returned(slot_index: int)

const BASE_RETURN_TIME: float = 30.0


func get_planet(planet_id: String) -> Dictionary:
	for p in PLANETS:
		if p["id"] == planet_id:
			return p
	return {}


func get_selected_planet_data() -> Dictionary:
	return get_planet(selected_planet)


func is_planet_unlocked(planet_id: String) -> bool:
	return planet_id in unlocked_planets


func unlock_planet(planet_id: String) -> bool:
	if is_planet_unlocked(planet_id):
		return false
	var data := get_planet(planet_id)
	if data.is_empty() or total_credits < int(data["unlock_cost"]):
		return false
	total_credits -= int(data["unlock_cost"])
	unlocked_planets.append(planet_id)
	credits_changed.emit(total_credits)
	planet_unlocked.emit(planet_id)
	return true


func get_damage_upgrade_cost() -> int:
	if damage_upgrade_level >= DAMAGE_UPGRADE_COSTS.size():
		return -1
	return DAMAGE_UPGRADE_COSTS[damage_upgrade_level]


func upgrade_click_damage() -> bool:
	var cost := get_damage_upgrade_cost()
	if cost < 0 or total_credits < cost:
		return false
	total_credits -= cost
	damage_upgrade_level += 1
	click_damage += 1
	credits_changed.emit(total_credits)
	return true


func start_direct_dispatch() -> void:
	player_status = "on_mission"
	pending_credits = 0
	player_status_changed.emit(player_status)


func return_from_dispatch() -> void:
	player_status = "returned"
	player_status_changed.emit(player_status)


func add_pending_credit(amount: int) -> void:
	pending_credits += amount


func collect_player_credits(from_global_pos: Vector2) -> void:
	if player_status != "returned" or pending_credits <= 0:
		return
	var amount := pending_credits
	total_credits += amount
	pending_credits = 0
	player_status = "idle"
	player_status_changed.emit(player_status)
	credits_changed.emit(total_credits)
	credits_collected.emit(amount, from_global_pos)


# 개별 아이템 구매 — 수량 1 증가, 파일럿은 required_planet 확인
func buy_part(part_type: String, tier: int) -> bool:
	if part_type not in PARTS:
		return false
	var tiers: Array = PARTS[part_type]["tiers"]
	if tier < 1 or tier > tiers.size():
		return false
	var tier_data: Dictionary = tiers[tier - 1]
	if "required_planet" in tier_data and not is_planet_unlocked(tier_data["required_planet"]):
		return false
	var cost: int = tier_data["cost"]
	if total_credits < cost:
		return false
	total_credits -= cost
	owned_parts[part_type][tier - 1] += 1
	credits_changed.emit(total_credits)
	part_purchased.emit(part_type, tier)
	return true


func get_owned_qty(part_type: String, tier: int) -> int:
	return owned_parts.get(part_type, [0, 0, 0])[tier - 1]


func get_assembly_cost(body_tier: int, weapon_tier: int, legs_tier: int) -> int:
	return (body_tier + weapon_tier + legs_tier) * 50


func unlock_auto_slot(index: int) -> bool:
	if index < 0 or index >= auto_slots.size():
		return false
	var slot: Dictionary = auto_slots[index]
	if slot["state"] != "locked":
		return false
	var cost: int = slot.get("unlock_cost", 0)
	if total_credits < cost:
		return false
	total_credits -= cost
	slot["state"] = "empty"
	credits_changed.emit(total_credits)
	auto_slot_changed.emit(index)
	return true


# 파츠 소비 후 머신 조립
func assemble_machine(slot_index: int, body_tier: int, weapon_tier: int, legs_tier: int) -> bool:
	if slot_index < 0 or slot_index >= auto_slots.size():
		return false
	if auto_slots[slot_index]["state"] != "empty":
		return false
	if get_owned_qty("body", body_tier) <= 0:
		return false
	if get_owned_qty("weapon", weapon_tier) <= 0:
		return false
	if get_owned_qty("legs", legs_tier) <= 0:
		return false
	var cost := get_assembly_cost(body_tier, weapon_tier, legs_tier)
	if total_credits < cost:
		return false
	total_credits -= cost
	owned_parts["body"][body_tier - 1] -= 1
	owned_parts["weapon"][weapon_tier - 1] -= 1
	owned_parts["legs"][legs_tier - 1] -= 1
	var slot: Dictionary = auto_slots[slot_index]
	slot["state"] = "offline"
	slot["machine"] = {"body": body_tier, "weapon": weapon_tier, "legs": legs_tier}
	credits_changed.emit(total_credits)
	auto_slot_changed.emit(slot_index)
	return true


# 파일럿 등급 기준 접근 가능 행성 목록 (해금된 것만)
# Lv.1 → sector_a, Lv.2 → +sector_b, Lv.3 → +sector_c
func get_pilot_accessible_planets(pilot_tier: int) -> Array:
	var result: Array = []
	for i in PLANETS.size():
		if i < pilot_tier and is_planet_unlocked(PLANETS[i]["id"]):
			result.append(PLANETS[i])
	return result


# 파일럿 수량 소비 후 자동 파견 시작
func start_auto_dispatch(slot_index: int, pilot_tier: int, planet_id: String) -> bool:
	if slot_index < 0 or slot_index >= auto_slots.size():
		return false
	var slot: Dictionary = auto_slots[slot_index]
	if slot["state"] != "offline":
		return false
	if get_owned_qty("pilot", pilot_tier) <= 0:
		return false
	if not is_planet_unlocked(planet_id):
		return false
	var ok := false
	for p in get_pilot_accessible_planets(pilot_tier):
		if p["id"] == planet_id:
			ok = true
			break
	if not ok:
		return false
	owned_parts["pilot"][pilot_tier - 1] -= 1
	var machine: Dictionary = slot.get("machine", {})
	var body_tier: int = machine.get("body", 1)
	var now := Time.get_unix_time_from_system()
	slot["state"] = "on_mission"
	slot["pilot_tier"] = pilot_tier
	slot["planet"] = planet_id
	slot["mission_start_time"] = now
	slot["mission_end_time"] = now + _get_mission_duration(body_tier)
	auto_slot_changed.emit(slot_index)
	return true


func _process(_delta: float) -> void:
	var now := Time.get_unix_time_from_system()
	for i in auto_slots.size():
		var slot: Dictionary = auto_slots[i]
		var state: String = slot.get("state", "")
		if state == "on_mission":
			if now >= float(slot.get("mission_end_time", INF)):
				_start_returning(i, now)
		elif state == "returning":
			if now >= float(slot.get("return_end_time", INF)):
				_complete_return(i)


func _get_mission_duration(body_tier: int) -> float:
	var tiers: Array = PARTS["body"]["tiers"]
	if body_tier < 1 or body_tier > tiers.size():
		return 30.0
	return float(tiers[body_tier - 1]["value"])


func _get_return_duration(legs_tier: int) -> float:
	var tiers: Array = PARTS["legs"]["tiers"]
	if legs_tier < 1 or legs_tier > tiers.size():
		return BASE_RETURN_TIME
	var reduction: int = tiers[legs_tier - 1]["value"]
	return maxf(5.0, BASE_RETURN_TIME - float(reduction))


func _get_mission_credits(weapon_tier: int, mission_duration: float) -> int:
	var tiers: Array = PARTS["weapon"]["tiers"]
	if weapon_tier < 1 or weapon_tier > tiers.size():
		return int(mission_duration)
	var rate: int = tiers[weapon_tier - 1]["value"]
	return int(float(rate) * mission_duration)


func _start_returning(slot_index: int, now: float) -> void:
	var slot: Dictionary = auto_slots[slot_index]
	var machine: Dictionary = slot.get("machine", {})
	var legs_tier: int = machine.get("legs", 1)
	var weapon_tier: int = machine.get("weapon", 1)
	var body_tier: int = machine.get("body", 1)
	var credits_earned := _get_mission_credits(weapon_tier, _get_mission_duration(body_tier))
	slot["state"] = "returning"
	slot["return_end_time"] = now + _get_return_duration(legs_tier)
	slot["credits_earned"] = credits_earned
	auto_slot_changed.emit(slot_index)


func _complete_return(slot_index: int) -> void:
	var slot: Dictionary = auto_slots[slot_index]
	slot["state"] = "returned"
	auto_slot_changed.emit(slot_index)
	auto_dispatch_returned.emit(slot_index)


func collect_auto_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= auto_slots.size():
		return false
	var slot: Dictionary = auto_slots[slot_index]
	if slot.get("state", "") != "returned":
		return false

	var pilot_tier: int = slot.get("pilot_tier", 1)
	var credits_earned: int = slot.get("credits_earned", 0)

	if pilot_tier >= 1 and pilot_tier <= owned_parts["pilot"].size():
		owned_parts["pilot"][pilot_tier - 1] += 1

	total_credits += credits_earned
	credits_changed.emit(total_credits)

	for key in ["pilot_tier", "planet", "mission_start_time", "mission_end_time",
			"return_end_time", "credits_earned"]:
		slot.erase(key)

	slot["state"] = "offline"
	auto_slot_changed.emit(slot_index)
	return true
