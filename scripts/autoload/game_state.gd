extends Node

var layout_mode := "horizontal"
var dispatch_preselect_slot: int = -1
var workshop_preselect_slot: int = -1
var total_credits: int = 1000000
var pending_credits: int = 0
var player_status: String = "idle"  # idle / on_mission / returned
var click_damage: int = 1
var damage_upgrade_level: int = 0
var unlocked_planets: Array = ["sector_a"]
var selected_planet: String = "sector_a"
var owned_parts: Dictionary = {
	"pilot": [0, 0, 0],
	"body":  [0, 0, 0],
	"weapon":[0, 0, 0],
	"legs":  [0, 0, 0],
}

# 데이터 상수 — 실제 정의는 data/ 파일에 있음
const _PlanetDataScript = preload("res://data/planet_data.gd")
const _PartsDataScript  = preload("res://data/parts_data.gd")
const PLANETS:               Array      = _PlanetDataScript.LIST
const PARTS:                 Dictionary = _PartsDataScript.DICT
const DAMAGE_UPGRADE_COSTS:  Array      = _PartsDataScript.DAMAGE_UPGRADE_COSTS

signal credits_changed(new_total: int)
signal credits_collected(amount: int, from_global_pos: Vector2)
signal player_status_changed(status: String)
signal planet_unlocked(planet_id: String)
signal part_purchased(part_type: String, tier: int)
signal auto_slot_changed(index: int)
signal auto_dispatch_returned(slot_index: int)

var _dispatch: DispatchManager

var auto_slots: Array:
	get: return _dispatch.auto_slots if _dispatch != null else []

func _ready() -> void:
	_dispatch = DispatchManager.new()
	add_child(_dispatch)
	_dispatch.auto_slot_changed.connect(func(i: int): auto_slot_changed.emit(i))
	_dispatch.auto_dispatch_returned.connect(func(i: int): auto_dispatch_returned.emit(i))

# ── 행성 ──────────────────────────────────────────────────

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

# ── 클릭 데미지 강화 ──────────────────────────────────────

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

# ── 직접 파견 ─────────────────────────────────────────────

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

# ── 파츠 / 인벤토리 ──────────────────────────────────────

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

# ── 자동 파견 — DispatchManager 위임 ─────────────────────

func unlock_auto_slot(index: int) -> bool:
	return _dispatch.unlock_auto_slot(index)

func get_assembly_cost(body_tier: int, weapon_tier: int, legs_tier: int) -> int:
	return _dispatch.get_assembly_cost(body_tier, weapon_tier, legs_tier)

func assemble_machine(slot_index: int, body_tier: int, weapon_tier: int, legs_tier: int) -> bool:
	return _dispatch.assemble_machine(slot_index, body_tier, weapon_tier, legs_tier)

func get_pilot_accessible_planets(pilot_tier: int) -> Array:
	return _dispatch.get_pilot_accessible_planets(pilot_tier)

func start_auto_dispatch(slot_index: int, pilot_tier: int, planet_id: String) -> bool:
	return _dispatch.start_auto_dispatch(slot_index, pilot_tier, planet_id)

func collect_auto_slot(slot_index: int) -> bool:
	return _dispatch.collect_auto_slot(slot_index)

func get_machine_preview(body_tier: int, weapon_tier: int, legs_tier: int) -> Dictionary:
	return _dispatch.get_machine_preview(body_tier, weapon_tier, legs_tier)

func apply_dispatch_save(slot_data: Array, save_time: float) -> void:
	_dispatch.apply_save_data(slot_data, save_time)
