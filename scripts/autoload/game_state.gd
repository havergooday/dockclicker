extends Node

var layout_mode := "horizontal"
var dispatch_preselect_slot: int = -1
var workshop_preselect_slot: int = -1
var total_credits: int = 0
var pending_credits: int = 0
var player_status: String = "idle"  # idle / on_mission / returned
var click_damage: int = 1
var damage_upgrade_level: int = 0
var auto_attack_unlocked: bool = false

const AUTO_ATTACK_COST := 800
var unlocked_planets: Array = ["sector_a"]
var selected_planet: String = "sector_a"
var part_inventory: Array = []  # Array of {iid, type, tier}

# ── 파일럿 ────────────────────────────────────────────────────
# bonus_type: "none" | "speed" (임무 시간 단축 %) | "credits" (수익 증가 %)
const PILOTS: Array = [
	{
		"id": "kyla_vex",
		"name": "카이라 벡스",
		"tier": 1,
		"cost": 500,
		"bonus_type": "none",
		"bonus_value": 0,
		"portrait_color": "#4499DD",
		"desc": "신뢰할 수 있는 초보 파일럿",
	},
	{
		"id": "rio_son",
		"name": "리오 손",
		"tier": 2,
		"cost": 1500,
		"bonus_type": "speed",
		"bonus_value": 20,
		"portrait_color": "#DD7733",
		"desc": "임무 시간 -20%",
	},
	{
		"id": "dona_mar",
		"name": "도나 마르",
		"tier": 3,
		"cost": 3500,
		"bonus_type": "credits",
		"bonus_value": 30,
		"portrait_color": "#44CC66",
		"desc": "수익 +30%",
	},
]

var hired_pilots: Array = []  # Array of pilot instance dicts

# ── UI 편집 ───────────────────────────────────────────────────
var ui_edit_mode: bool = false
var ui_positions: Dictionary = {}
signal ui_edit_mode_changed(enabled: bool)
signal ui_positions_reset

# ── 데이터 상수 ───────────────────────────────────────────────
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
signal pilot_hired(pilot_id: String)
signal pilot_status_changed(pilot_id: String)
signal slot_pilot_assigned(index: int)

var _dispatch: DispatchManager

var auto_slots: Array:
	get: return _dispatch.auto_slots if _dispatch != null else []

func _ready() -> void:
	_dispatch = DispatchManager.new()
	add_child(_dispatch)
	_dispatch.auto_slot_changed.connect(func(i: int): auto_slot_changed.emit(i))
	_dispatch.auto_dispatch_returned.connect(func(i: int): auto_dispatch_returned.emit(i))

# ── 행성 ──────────────────────────────────────────────────────

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

# ── 클릭 데미지 강화 ──────────────────────────────────────────

func get_damage_upgrade_cost() -> int:
	if damage_upgrade_level >= DAMAGE_UPGRADE_COSTS.size():
		return -1
	return DAMAGE_UPGRADE_COSTS[damage_upgrade_level]

func unlock_auto_attack() -> bool:
	if auto_attack_unlocked or total_credits < AUTO_ATTACK_COST:
		return false
	total_credits -= AUTO_ATTACK_COST
	auto_attack_unlocked = true
	credits_changed.emit(total_credits)
	return true

func upgrade_click_damage() -> bool:
	var cost := get_damage_upgrade_cost()
	if cost < 0 or total_credits < cost:
		return false
	total_credits -= cost
	damage_upgrade_level += 1
	click_damage += 1
	credits_changed.emit(total_credits)
	return true

# ── 직접 파견 ─────────────────────────────────────────────────

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
	if player_status != "returned":
		return
	var amount := pending_credits
	total_credits += amount
	pending_credits = 0
	player_status = "idle"
	player_status_changed.emit(player_status)
	if amount > 0:
		credits_changed.emit(total_credits)
		credits_collected.emit(amount, from_global_pos)

# ── 파츠 / 인벤토리 ──────────────────────────────────────────

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
	part_inventory.append({"iid": "p_%d" % Time.get_ticks_usec(), "type": part_type, "tier": tier})
	credits_changed.emit(total_credits)
	part_purchased.emit(part_type, tier)
	return true

func get_owned_qty(part_type: String, tier: int) -> int:
	var count := 0
	for item: Dictionary in part_inventory:
		if item.get("type") == part_type and int(item.get("tier", 0)) == tier:
			count += 1
	return count

func consume_part(part_type: String, tier: int) -> bool:
	for i in part_inventory.size():
		var item: Dictionary = part_inventory[i]
		if item.get("type") == part_type and int(item.get("tier", 0)) == tier:
			part_inventory.remove_at(i)
			return true
	return false

# ── 파일럿 시스템 ─────────────────────────────────────────────

func get_pilot_data(pilot_id: String) -> Dictionary:
	for p in PILOTS:
		if p["id"] == pilot_id:
			return p
	return {}

func is_pilot_hired(pilot_id: String) -> bool:
	for p in hired_pilots:
		if p["id"] == pilot_id:
			return true
	return false

func get_hired_pilot(pilot_id: String) -> Dictionary:
	for p in hired_pilots:
		if p["id"] == pilot_id:
			return p
	return {}

func get_idle_pilots() -> Array:
	var result: Array = []
	for p in hired_pilots:
		if p.get("status", "") == "idle":
			result.append(p)
	return result

func hire_pilot(pilot_id: String) -> bool:
	var data := get_pilot_data(pilot_id)
	if data.is_empty() or is_pilot_hired(pilot_id):
		return false
	if total_credits < int(data["cost"]):
		return false
	total_credits -= int(data["cost"])
	hired_pilots.append({
		"id":             data["id"],
		"name":           data["name"],
		"tier":           data["tier"],
		"bonus_type":     data["bonus_type"],
		"bonus_value":    data["bonus_value"],
		"portrait_color": data["portrait_color"],
		"status":         "idle",
	})
	credits_changed.emit(total_credits)
	pilot_hired.emit(pilot_id)
	return true

func create_custom_pilot(custom_name: String, color_hex: String) -> bool:
	if custom_name.strip_edges().is_empty():
		return false
	var cost := 300
	if total_credits < cost:
		return false
	total_credits -= cost
	var uid := "custom_%d" % Time.get_ticks_msec()
	hired_pilots.append({
		"id":             uid,
		"name":           custom_name.strip_edges(),
		"tier":           1,
		"bonus_type":     "none",
		"bonus_value":    0,
		"portrait_color": color_hex,
		"status":         "idle",
		"is_custom":      true,
	})
	credits_changed.emit(total_credits)
	pilot_hired.emit(uid)
	return true

# ── 자동 파견 — DispatchManager 위임 ─────────────────────────

func unlock_auto_slot(index: int) -> bool:
	return _dispatch.unlock_auto_slot(index)

func get_assembly_cost(body_tier: int, weapon_tier: int, legs_tier: int) -> int:
	return _dispatch.get_assembly_cost(body_tier, weapon_tier, legs_tier)

func assemble_machine(slot_index: int, body_tier: int, weapon_tier: int, legs_tier: int) -> bool:
	return _dispatch.assemble_machine(slot_index, body_tier, weapon_tier, legs_tier)

func get_pilot_accessible_planets(pilot_id: String) -> Array:
	var p := get_hired_pilot(pilot_id)
	if p.is_empty():
		return []
	return _dispatch.get_pilot_accessible_planets(int(p.get("tier", 1)))

func start_auto_dispatch(slot_index: int, pilot_id: String, planet_id: String) -> bool:
	return _dispatch.start_auto_dispatch(slot_index, pilot_id, planet_id)

func collect_auto_slot(slot_index: int) -> bool:
	return _dispatch.collect_auto_slot(slot_index)

func get_machine_preview(body_tier: int, weapon_tier: int, legs_tier: int) -> Dictionary:
	return _dispatch.get_machine_preview(body_tier, weapon_tier, legs_tier)


func assign_pilot_to_slot(slot_index: int, pilot_id: String) -> bool:
	var ok := _dispatch.assign_pilot_to_slot(slot_index, pilot_id)
	if ok:
		slot_pilot_assigned.emit(slot_index)
	return ok


func disassemble_machine(slot_index: int) -> bool:
	return _dispatch.disassemble_machine(slot_index)

func apply_dispatch_save(slot_data: Array, save_time: float) -> void:
	_dispatch.apply_save_data(slot_data, save_time)
