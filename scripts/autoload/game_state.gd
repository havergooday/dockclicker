extends Node

var layout_mode := "horizontal"
var dispatch_preselect_slot: int = -1
var workshop_preselect_slot: int = -1
var total_credits: int = 100000
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
var hired_pilots: Array = []  # Array of pilot instance dicts

# ── 모집 공고판 ───────────────────────────────────────────────
const BOARD_SLOT_COUNT    := 3
const BOARD_REFRESH_COST  := 300

var board_pilot_ids: Array  = []   # 현재 공고판에 표시 중인 파일럿 ID 3개
var board_last_day:   int   = -1   # 마지막 자동 갱신 일수 (Unix days)
var board_refresh_count: int = 0   # 오늘 유료 갱신 횟수 (시드 변경용)

signal board_refreshed

# ── UI 편집 ───────────────────────────────────────────────────
var ui_edit_mode: bool = false
var ui_positions: Dictionary = {}
signal ui_edit_mode_changed(enabled: bool)
signal ui_positions_reset

# ── 데이터 상수 ───────────────────────────────────────────────
const _PlanetDataScript = preload("res://data/planet_data.gd")
const _PartsDataScript  = preload("res://data/parts_data.gd")
const _PilotsDataScript = preload("res://data/pilots_data.gd")
const PLANETS:               Array      = _PlanetDataScript.LIST
const PARTS:                 Dictionary = _PartsDataScript.DICT
const DAMAGE_UPGRADE_COSTS:  Array      = _PartsDataScript.DAMAGE_UPGRADE_COSTS
const PILOTS:                Array      = _PilotsDataScript.LIST

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

var hangar_groups: Array:
	get: return _dispatch.hangar_groups if _dispatch != null else []

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
	board_pilot_ids = _select_board_from_pool(_build_board_pool(), _board_seed())
	board_refreshed.emit()
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

# ── 모집 공고판 ───────────────────────────────────────────────

func _today_unix_day() -> int:
	return int(Time.get_unix_time_from_system()) / 86400

func _board_seed() -> int:
	return _today_unix_day() * 1000 + board_refresh_count

func _build_board_pool() -> Array:
	var pool: Array = []
	var c_unlocked := is_planet_unlocked("sector_c")
	var f_unlocked := is_planet_unlocked("sector_f")
	for p in PILOTS:
		if is_pilot_hired(str(p["id"])):
			continue
		var tier: int = int(p.get("tier", 1))
		if tier == 1:
			pool.append(p)
		elif tier == 2 and c_unlocked:
			pool.append(p)
		elif tier == 3 and f_unlocked:
			pool.append(p)
	return pool

func _select_board_from_pool(pool: Array, seed_val: int) -> Array:
	if pool.is_empty():
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var shuffled := pool.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp
	var result: Array = []
	for i in mini(BOARD_SLOT_COUNT, shuffled.size()):
		result.append(str(shuffled[i]["id"]))
	return result

func ensure_board_fresh() -> void:
	var today := _today_unix_day()
	if today > board_last_day:
		board_last_day = today
		board_refresh_count = 0
		board_pilot_ids = _select_board_from_pool(_build_board_pool(), _board_seed())
		board_refreshed.emit()

func refresh_board_paid() -> bool:
	if total_credits < BOARD_REFRESH_COST:
		return false
	total_credits -= BOARD_REFRESH_COST
	board_refresh_count += 1
	board_pilot_ids = _select_board_from_pool(_build_board_pool(), _board_seed())
	credits_changed.emit(total_credits)
	board_refreshed.emit()
	return true

func get_board_pilot_data() -> Array:
	ensure_board_fresh()
	var result: Array = []
	for pid in board_pilot_ids:
		var found := false
		for p in PILOTS:
			if str(p["id"]) == str(pid):
				result.append(p)
				found = true
				break
		if not found:
			result.append({})
	return result

func get_board_next_refresh_secs() -> int:
	var now := int(Time.get_unix_time_from_system())
	var next_midnight := (_today_unix_day() + 1) * 86400
	return next_midnight - now

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


func remove_machine_part(slot_index: int, part_type: String) -> bool:
	return _dispatch.remove_machine_part(slot_index, part_type)

func replace_machine_part(slot_index: int, part_type: String, tier: int) -> bool:
	return _dispatch.replace_machine_part(slot_index, part_type, tier)


func disassemble_machine(slot_index: int) -> bool:
	return _dispatch.disassemble_machine(slot_index)

func unlock_hangar(group_id: int) -> bool:
	return _dispatch.unlock_hangar(group_id)

func get_hangar_group(group_id: int) -> DispatchManager.HangarGroup:
	return _dispatch.get_hangar_group(group_id)

func apply_dispatch_save(slot_data: Array, save_time: float, groups_data: Array = []) -> void:
	_dispatch.apply_save_data(slot_data, save_time, groups_data)
