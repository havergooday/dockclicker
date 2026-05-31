extends Node

var hangar_preselect_slot: int = -1
var total_credits: int = 500
const RESOURCE_IDS: Array = ["cp", "alloy", "supplies", "circuit"]
var resources: Dictionary = {
	"alloy": 0,
	"supplies": 0,
	"circuit": 0,
}
var pending_credits: int = 0
var player_status: String = "idle"  # idle / on_mission / returned
var click_damage: int = 1
var damage_upgrade_level: int = 0
var auto_attack_unlocked: bool = false
var click_range_level: int = 0
var combo_level: int = 0

signal upgrade_changed

const AUTO_ATTACK_COST := 800
var unlocked_planets: Array = ["sector_a"]
var selected_planet: String = "sector_a"

# ── 기능 해금 ─────────────────────────────────────────────────
const FEATURE_DEFS: Array = [
	{"id": "pc_terminal",    "name": "PC 터미널",       "desc": "파츠 구매 · 업그레이드",     "cost": 100},
	{"id": "quarters",       "name": "숙소",             "desc": "침대 1개 · 파일럿 거주 공간", "cost": 300},
	{"id": "pilot_workshop", "name": "공작실 · 파일럿", "desc": "머신 조립 · 파일럿 고용 · 격납고", "cost": 800},
	{"id": "canteen",        "name": "간이 식당",        "desc": "식사 회복 강화 · 기분 회복 +1 추가",  "cost": 3000},
]

const BASE_AREA_DEFS: Array = [
	{"id": "quarters", "name": "숙소", "desc": "침대와 파일럿 거주 공간", "cost": {"cp": 300}},
	{"id": "lounge", "name": "라운지", "desc": "휴식과 생활 시설이 보이는 공간", "cost": {"cp": 1200, "supplies": 4}},
	{"id": "canteen", "name": "간이 식당", "desc": "기분 회복을 강화하는 생활 구역", "cost": {"cp": 3000, "supplies": 10}},
	{"id": "medbay", "name": "의무실", "desc": "회복 행동을 강화하는 의료 구역", "cost": {"cp": 2500, "alloy": 3, "circuit": 2}},
]

var unlocked_features: Array = []

signal feature_unlocked(feature_id: String)
var base_area_unlocks: Dictionary = {
	"quarters": true,
	"lounge": false,
	"canteen": false,
	"medbay": false,
}

signal base_area_unlocks_changed
var part_inventory: Array = []  # Array of {iid, type, tier}

# ── 라운지 시설 ───────────────────────────────────────────────
var lounge_slots: Dictionary = {
	"wall": "",
	"rest": "",
	"table": "",
	"service": "",
	"medical": "",
	"decor": "",
}
signal facilities_changed

# ── 파일럿 ────────────────────────────────────────────────────
var hired_pilots: Array = []  # Array of pilot instance dicts

# ── 숙소 침대 ────────────────────────────────────────────────
# 각 침대: {locked: bool, unlock_cost: int, slots: [pilot_id|"", pilot_id|""]}
# slots[0] = 상단, slots[1] = 하단
var quarters_beds: Array = []
const BED_COSTS: Array   = [0, 300, 700, 1500, 3500, 8000, 18000, 40000]
const MAX_BEDS:  int     = 8
signal quarters_changed

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
var placeable_positions: Dictionary = {}
const PLACEABLE_GRID_SIZE := 16.0
signal ui_edit_mode_changed(enabled: bool)
signal ui_positions_reset
signal placeable_positions_changed

# 상태표시줄(크레딧 HUD) 위치: "top" | "bottom" | "left" | "right"
var hud_position: String = "right"
signal hud_position_changed(pos: String)

var _quarters_rest_accumulator: float = 0.0
const QUARTERS_REST_TICK_SEC := 4.0

# ── 데이터 상수 ───────────────────────────────────────────────
const _PlanetDataScript = preload("res://data/planet_data.gd")
const _PartsDataScript  = preload("res://data/parts_data.gd")
const _PilotsDataScript = preload("res://data/pilots_data.gd")
const _FacilityDataScript = preload("res://data/facility_data.gd")
const PLANETS:               Array      = _PlanetDataScript.LIST
const PARTS:                 Dictionary = _PartsDataScript.DICT
const DAMAGE_UPGRADE_COSTS:  Array      = _PartsDataScript.DAMAGE_UPGRADE_COSTS
const PILOTS:                Array      = _PilotsDataScript.LIST
const FACILITIES:            Array      = _FacilityDataScript.LIST

signal credits_changed(new_total: int)
signal resources_changed(resources: Dictionary)
signal resource_changed(resource_id: String, new_amount: int)
signal resources_collected(rewards: Dictionary)
signal pilot_tier_up(pilot_id: String)

const EXP_PER_TIER: Array = [80, 160]
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
	feature_unlocked.connect(_on_feature_unlocked)
	_init_quarters()


func _process(delta: float) -> void:
	apply_quarters_rest_tick(delta)

func _on_feature_unlocked(feature_id: String) -> void:
	if feature_id == "pilot_workshop" and _dispatch != null:
		var slots: Array = _dispatch.auto_slots
		if slots.size() > 0:
			var s: DispatchManager.AutoSlot = slots[0]
			if s.state == "locked":
				s.state = "empty"
				_dispatch.auto_slot_changed.emit(0)

func get_base_area_data(area_id: String) -> Dictionary:
	for area in BASE_AREA_DEFS:
		if str(area.get("id", "")) == area_id:
			return area
	return {}

func is_base_area_unlocked(area_id: String) -> bool:
	return bool(base_area_unlocks.get(area_id, false))

func unlock_base_area(area_id: String) -> bool:
	if not base_area_unlocks.has(area_id):
		return false
	if is_base_area_unlocked(area_id):
		return false
	var area := get_base_area_data(area_id)
	if area.is_empty():
		return false
	if not pay_cost(area.get("cost", {})):
		return false
	base_area_unlocks[area_id] = true
	if area_id == "quarters" and quarters_beds.size() > 0 and bool(quarters_beds[0].get("locked", true)):
		quarters_beds[0]["locked"] = false
		quarters_changed.emit()
	base_area_unlocks_changed.emit()
	return true

func _init_quarters() -> void:
	quarters_beds.clear()
	for i in MAX_BEDS:
		quarters_beds.append({
			"locked":       true,
			"unlock_cost":  BED_COSTS[i] if i < BED_COSTS.size() else 99999,
			"slots":        ["", "", ""],   # 침대당 3 슬롯
		})
	if quarters_beds.size() > 0:
		quarters_beds[0]["locked"] = not is_base_area_unlocked("quarters")

# ── 숙소 함수 ────────────────────────────────────────────────

func get_quarters_capacity() -> int:
	var cap := 0
	for bed in quarters_beds:
		if not bed.get("locked", true): cap += 3
	return cap

func can_hire_more_pilots() -> bool:
	return hired_pilots.size() < get_quarters_capacity()

func get_pilot_bed_pos(pilot_id: String) -> Dictionary:
	for b in quarters_beds.size():
		var bed: Dictionary = quarters_beds[b]
		var slots: Array = bed.get("slots", [])
		for s in slots.size():
			if str(slots[s]) == pilot_id:
				return {"bed": b, "slot": s}
	return {}

func assign_pilot_to_bed(pilot_id: String, bed_idx: int, slot_idx: int) -> bool:
	if bed_idx < 0 or bed_idx >= quarters_beds.size(): return false
	var bed: Dictionary = quarters_beds[bed_idx]
	if bed.get("locked", true): return false
	if slot_idx < 0 or slot_idx > 2: return false
	var current_occupant: String = str(bed["slots"][slot_idx])
	if current_occupant != "" and current_occupant != pilot_id: return false
	# 기존 위치 비우기
	var old := get_pilot_bed_pos(pilot_id)
	if not old.is_empty():
		quarters_beds[old["bed"]]["slots"][old["slot"]] = ""
	quarters_beds[bed_idx]["slots"][slot_idx] = pilot_id
	quarters_changed.emit()
	return true

func move_pilot_bed(pilot_id: String, target_bed: int, target_slot: int) -> bool:
	if not assign_pilot_to_bed(pilot_id, target_bed, target_slot): return false
	quarters_changed.emit()
	return true

func _auto_assign_bed(pilot_id: String) -> void:
	for b in quarters_beds.size():
		var bed: Dictionary = quarters_beds[b]
		if bed.get("locked", true): continue
		for s in 3:
			if str(bed["slots"][s]) == "":
				quarters_beds[b]["slots"][s] = pilot_id
				quarters_changed.emit()
				return

func unlock_bed(bed_idx: int) -> bool:
	if bed_idx < 0 or bed_idx >= quarters_beds.size(): return false
	var bed: Dictionary = quarters_beds[bed_idx]
	if not bed.get("locked", true): return false
	var cost: int = int(bed.get("unlock_cost", 99999))
	if total_credits < cost: return false
	total_credits -= cost
	quarters_beds[bed_idx]["locked"] = false
	credits_changed.emit(total_credits)
	quarters_changed.emit()
	return true

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
	if data.is_empty():
		return false
	if total_credits < int(data.get("unlock_cost", 0)):
		return false
	var extra: Dictionary = data.get("unlock_resources", {})
	if not can_pay(extra):
		return false
	total_credits -= int(data.get("unlock_cost", 0))
	if not extra.is_empty():
		pay_cost(extra)
	unlocked_planets.append(planet_id)
	credits_changed.emit(total_credits)
	planet_unlocked.emit(planet_id)
	return true

func is_feature_unlocked(feature_id: String) -> bool:
	return feature_id in unlocked_features

func unlock_feature(feature_id: String) -> bool:
	if feature_id == "quarters":
		var was_feature_unlocked := is_feature_unlocked(feature_id)
		if not is_base_area_unlocked(feature_id):
			if not unlock_base_area(feature_id):
				return false
		elif quarters_beds.size() > 0 and bool(quarters_beds[0].get("locked", true)):
			quarters_beds[0]["locked"] = false
			quarters_changed.emit()
		if was_feature_unlocked:
			return false
		unlocked_features.append(feature_id)
		feature_unlocked.emit(feature_id)
		return true
	if is_feature_unlocked(feature_id):
		return false
	var def := _get_feature_def(feature_id)
	if def.is_empty():
		return false
	var cost: int = int(def["cost"])
	if total_credits < cost:
		return false
	total_credits -= cost
	unlocked_features.append(feature_id)
	if feature_id == "quarters":
		quarters_beds[0]["locked"] = false
		quarters_changed.emit()
	credits_changed.emit(total_credits)
	feature_unlocked.emit(feature_id)
	return true

func _get_feature_def(feature_id: String) -> Dictionary:
	for f in FEATURE_DEFS:
		if str(f["id"]) == feature_id:
			return f
	return {}

func get_feature_cost(feature_id: String) -> int:
	var def := _get_feature_def(feature_id)
	if def.is_empty():
		return 0
	return int(def.get("cost", 0))

func format_feature_cost(feature_id: String) -> String:
	return format_cost({"cp": get_feature_cost(feature_id)})

# ── 배치 편집 ─────────────────────────────────────────────────

func set_ui_edit_mode(enabled: bool) -> void:
	if ui_edit_mode == enabled:
		return
	ui_edit_mode = enabled
	ui_edit_mode_changed.emit(enabled)


func set_hud_position(pos: String) -> void:
	if pos not in ["top", "bottom", "left", "right"]:
		return
	if hud_position == pos:
		return
	hud_position = pos
	hud_position_changed.emit(pos)


func set_placeable_position(placeable_id: String, region_tag: String, pos: Vector2) -> bool:
	var bounds := _placement_bounds(region_tag)
	if bounds.size == Vector2.ZERO:
		return false
	var clamped := clamp_placeable_position(placeable_id, region_tag, pos)
	if not can_place_at(placeable_id, region_tag, clamped):
		return false
	placeable_positions[placeable_id] = {
		"region": region_tag,
		"x": clamped.x,
		"y": clamped.y,
	}
	placeable_positions_changed.emit()
	return true


func ensure_placeable_position(placeable_id: String, region_tag: String, pos: Vector2) -> void:
	if placeable_positions.has(placeable_id):
		return
	var clamped := clamp_placeable_position(placeable_id, region_tag, pos)
	placeable_positions[placeable_id] = {
		"region": region_tag,
		"x": clamped.x,
		"y": clamped.y,
	}


func clamp_placeable_position(placeable_id: String, region_tag: String, pos: Vector2) -> Vector2:
	var bounds := _placement_bounds(region_tag)
	if bounds.size == Vector2.ZERO:
		return pos
	var size := _placeable_size(placeable_id, region_tag)
	var snapped := pos.snapped(Vector2(PLACEABLE_GRID_SIZE, PLACEABLE_GRID_SIZE))
	return Vector2(
		clampf(snapped.x, bounds.position.x, bounds.position.x + bounds.size.x - size.x),
		clampf(snapped.y, bounds.position.y, bounds.position.y + bounds.size.y - size.y)
	)


func can_place_at(placeable_id: String, region_tag: String, pos: Vector2) -> bool:
	var bounds := _placement_bounds(region_tag)
	if bounds.size == Vector2.ZERO:
		return false
	var clamped := clamp_placeable_position(placeable_id, region_tag, pos)
	if clamped != pos:
		return false
	return _is_placeable_cell_free(placeable_id, region_tag, clamped)


func get_placeable_position(placeable_id: String, fallback: Vector2) -> Vector2:
	var raw = placeable_positions.get(placeable_id, {})
	if raw is Dictionary:
		var d := raw as Dictionary
		var region_tag := str(d.get("region", ""))
		return clamp_placeable_position(placeable_id, region_tag, Vector2(float(d.get("x", fallback.x)), float(d.get("y", fallback.y))))
	return clamp_placeable_position(placeable_id, "", fallback)


func get_placement_bounds(region_tag: String) -> Rect2:
	return _placement_bounds(region_tag)


func _placeable_size(placeable_id: String, region_tag: String) -> Vector2:
	if placeable_id.begins_with("bed_") or region_tag == "quarters":
		return Vector2(128.0, 64.0)
	if placeable_id.begins_with("facility_") or region_tag == "lounge":
		# 충돌 판정 크기를 실제 카드 시각 크기(144×56)에 맞춤 — 작게 두면 시각적으로 겹쳐 놓을 수 있음
		return Vector2(144.0, 56.0)
	return Vector2(PLACEABLE_GRID_SIZE, PLACEABLE_GRID_SIZE)


func _is_placeable_cell_free(placeable_id: String, region_tag: String, candidate: Vector2) -> bool:
	var candidate_rect := Rect2(candidate, _placeable_size(placeable_id, region_tag))
	for other_key in placeable_positions.keys():
		var other_id := str(other_key)
		if other_id == placeable_id:
			continue
		var raw = placeable_positions.get(other_key, {})
		if not (raw is Dictionary):
			continue
		var d := raw as Dictionary
		if str(d.get("region", "")) != region_tag:
			continue
		var other_pos := Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
		var other_size := _placeable_size(other_id, region_tag)
		if candidate_rect.intersects(Rect2(other_pos, other_size)):
			return false
	return true


func _placement_bounds(region_tag: String) -> Rect2:
	match region_tag:
		"quarters": return Rect2(Vector2(0.0, 0.0), Vector2(1200.0, 288.0))
		"lounge": return Rect2(Vector2(1200.0, 80.0), Vector2(1216.0, 208.0))
	return Rect2()

# ── 재화 ─────────────────────────────────────────────────────

func get_resource(resource_id: String) -> int:
	if resource_id == "cp":
		return total_credits
	return int(resources.get(resource_id, 0))


func set_resource(resource_id: String, amount: int) -> void:
	var new_amount := maxi(0, amount)
	if resource_id == "cp":
		total_credits = new_amount
		credits_changed.emit(total_credits)
	else:
		resources[resource_id] = new_amount
	resources_changed.emit(resources.duplicate())
	resource_changed.emit(resource_id, new_amount)


func add_resource(resource_id: String, amount: int) -> void:
	set_resource(resource_id, get_resource(resource_id) + amount)


func can_pay(cost: Dictionary) -> bool:
	for id in cost.keys():
		if get_resource(str(id)) < int(cost[id]):
			return false
	return true


func pay_cost(cost: Dictionary) -> bool:
	if not can_pay(cost):
		return false
	for id in cost.keys():
		add_resource(str(id), -int(cost[id]))
	return true


func format_cost(cost: Dictionary) -> String:
	var parts: Array = []
	for id in cost.keys():
		var resource_id := str(id)
		var label := "CR" if resource_id == "cp" else resource_id.to_upper()
		parts.append("%d %s" % [int(cost[id]), label])
	return " · ".join(parts)

# ── 라운지 시설 함수 ─────────────────────────────────────────

func get_facility_data(facility_id: String) -> Dictionary:
	for facility in FACILITIES:
		if str(facility.get("id", "")) == facility_id:
			return facility
	return {}


func install_facility(slot_id: String, facility_id: String) -> bool:
	if not lounge_slots.has(slot_id):
		return false
	var facility := get_facility_data(facility_id)
	if facility.is_empty():
		return false
	if str(facility.get("slot_type", "")) != slot_id:
		return false
	if get_installed_facility(slot_id) == facility_id:
		return false
	if not pay_cost(facility.get("cost", {})):
		return false
	lounge_slots[slot_id] = facility_id
	facilities_changed.emit()
	return true


func remove_facility(slot_id: String) -> bool:
	if not lounge_slots.has(slot_id):
		return false
	if str(lounge_slots.get(slot_id, "")) == "":
		return false
	lounge_slots[slot_id] = ""
	facilities_changed.emit()
	return true


func get_installed_facility(slot_id: String) -> String:
	return str(lounge_slots.get(slot_id, ""))

# ── 파츠 옵션 동적 티어 ─────────────────────────────────────────

func compute_part_tier(options: Array) -> int:
	if options.is_empty():
		return 1
	elif options.size() == 1:
		return 2
	return 3

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
	upgrade_changed.emit()
	return true

func get_click_range_cost() -> int:
	if click_range_level >= PartsData.CLICK_RANGE_COSTS.size():
		return -1
	return PartsData.CLICK_RANGE_COSTS[click_range_level]

func get_click_range_px() -> float:
	if click_range_level <= 0:
		return 0.0
	return PartsData.CLICK_RANGE_PX[click_range_level - 1]

func upgrade_click_range() -> bool:
	var cost := get_click_range_cost()
	if cost < 0 or total_credits < cost:
		return false
	total_credits -= cost
	click_range_level += 1
	credits_changed.emit(total_credits)
	upgrade_changed.emit()
	return true

func get_combo_cost() -> int:
	if combo_level >= PartsData.COMBO_COSTS.size():
		return -1
	return PartsData.COMBO_COSTS[combo_level]

func get_combo_threshold() -> int:
	if combo_level <= 0:
		return 0
	return PartsData.COMBO_THRESHOLDS[combo_level - 1]

func get_combo_multiplier() -> float:
	if combo_level <= 0:
		return 1.0
	return PartsData.COMBO_MULTIPLIERS[combo_level - 1]

func upgrade_combo() -> bool:
	var cost := get_combo_cost()
	if cost < 0 or total_credits < cost:
		return false
	total_credits -= cost
	combo_level += 1
	credits_changed.emit(total_credits)
	upgrade_changed.emit()
	return true

func upgrade_click_damage() -> bool:
	var cost := get_damage_upgrade_cost()
	if cost < 0 or total_credits < cost:
		return false
	total_credits -= cost
	damage_upgrade_level += 1
	click_damage += 1
	credits_changed.emit(total_credits)
	upgrade_changed.emit()
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
	var mat_rewards := _roll_direct_dispatch_materials()
	for id in mat_rewards.keys():
		add_resource(str(id), int(mat_rewards[id]))
	_apply_direct_dispatch_pilot_state()
	player_status = "idle"
	player_status_changed.emit(player_status)
	if amount > 0:
		credits_changed.emit(total_credits)
		credits_collected.emit(amount, from_global_pos)
	if not mat_rewards.is_empty():
		resources_collected.emit(mat_rewards)


func _apply_direct_dispatch_pilot_state() -> void:
	var planet := get_planet(selected_planet)
	if planet.is_empty():
		return
	var fat := int(planet.get("fatigue_delta", 0))
	var str_ := int(planet.get("stress_delta", 0))
	if fat <= 0 and str_ <= 0:
		return
	var idle := get_idle_pilots()
	if idle.is_empty():
		return
	apply_pilot_state_delta(str(idle[0].get("id", "")), {"fatigue": fat, "stress": str_})


func _roll_direct_dispatch_materials() -> Dictionary:
	var planet := get_planet(selected_planet)
	if planet.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var out: Dictionary = {}
	for id_raw in planet.get("guaranteed_rewards", {}).keys():
		var id := str(id_raw)
		if id == "cp":
			continue
		var range_raw: Array = planet["guaranteed_rewards"][id_raw]
		var min_v := int(range_raw[0]) if range_raw.size() > 0 else 0
		var max_v := int(range_raw[1]) if range_raw.size() > 1 else min_v
		out[id] = int(out.get(id, 0)) + rng.randi_range(min_v, max_v)
	for reward_raw in planet.get("chance_rewards", []):
		var reward: Dictionary = reward_raw
		if rng.randf() > float(reward.get("chance", 0.0)):
			continue
		var rid := str(reward.get("id", ""))
		if rid == "" or rid == "cp":
			continue
		var amt: Array = reward.get("amount", [1, 1])
		out[rid] = int(out.get(rid, 0)) + rng.randi_range(
			int(amt[0]) if amt.size() > 0 else 1,
			int(amt[1]) if amt.size() > 1 else (int(amt[0]) if amt.size() > 0 else 1)
		)
	return out

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

# 특정 인스턴스(iid)를 정확히 소모. iid가 비었거나 없으면 티어 기준으로 fallback.
func consume_part_by_iid(iid: String, part_type: String, tier: int) -> bool:
	if iid != "":
		for i in part_inventory.size():
			var item: Dictionary = part_inventory[i]
			if str(item.get("iid", "")) == iid:
				part_inventory.remove_at(i)
				return true
	return consume_part(part_type, tier)

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


func _with_pilot_living_state(source: Dictionary) -> Dictionary:
	return {
		"id":             source.get("id", ""),
		"name":           source.get("name", ""),
		"tier":           int(source.get("tier", 1)),
		"bonus_type":     source.get("bonus_type", "none"),
		"bonus_value":    int(source.get("bonus_value", 0)),
		"portrait_color": source.get("portrait_color", "#4499DD"),
		"status":         source.get("status", "idle"),
		"fatigue":        int(source.get("fatigue", 0)),
		"stress":         int(source.get("stress", 0)),
		"mood":           int(source.get("mood", 70)),
		"preferred_regions": source.get("preferred_regions", []).duplicate(),
		"favorite_facilities": source.get("favorite_facilities", []).duplicate(),
		"personality": str(source.get("personality", "")),
		"exp":            int(source.get("exp", 0)),
		"is_custom":      bool(source.get("is_custom", false)),
	}


func apply_pilot_state_delta(pilot_id: String, deltas: Dictionary) -> bool:
	for i in hired_pilots.size():
		var pilot: Dictionary = hired_pilots[i]
		if str(pilot.get("id", "")) != pilot_id:
			continue
		for id in ["fatigue", "stress", "mood"]:
			if deltas.has(id):
				pilot[id] = clampi(int(pilot.get(id, 0)) + int(deltas[id]), 0, 100)
		hired_pilots[i] = pilot
		pilot_status_changed.emit(pilot_id)
		return true
	return false


func add_pilot_exp(pilot_id: String, amount: int) -> void:
	for i in hired_pilots.size():
		var pilot: Dictionary = hired_pilots[i]
		if str(pilot.get("id", "")) != pilot_id:
			continue
		hired_pilots[i]["exp"] = int(pilot.get("exp", 0)) + amount
		_check_tier_up(i)
		pilot_status_changed.emit(pilot_id)
		return


func _check_tier_up(idx: int) -> void:
	var pilot: Dictionary = hired_pilots[idx]
	var tier := int(pilot.get("tier", 1))
	if tier >= 3:
		return
	var threshold: int = EXP_PER_TIER[tier - 1]
	if int(pilot.get("exp", 0)) < threshold:
		return
	hired_pilots[idx]["tier"] = tier + 1
	hired_pilots[idx]["bonus_value"] = int(pilot.get("bonus_value", 0)) + 5
	hired_pilots[idx]["exp"] = 0
	pilot_tier_up.emit(str(pilot.get("id", "")))


func apply_quarters_rest_tick(delta: float) -> void:
	if delta <= 0.0:
		return
	_quarters_rest_accumulator += delta
	while _quarters_rest_accumulator >= QUARTERS_REST_TICK_SEC:
		_quarters_rest_accumulator -= QUARTERS_REST_TICK_SEC
		_apply_quarters_rest_step()


func _apply_quarters_rest_step() -> void:
	for bed in quarters_beds:
		if bool(bed.get("locked", true)):
			continue
		for pilot_id_raw in bed.get("slots", []):
			var pilot_id := str(pilot_id_raw)
			if pilot_id == "":
				continue
			var pilot := get_hired_pilot(pilot_id)
			if pilot.is_empty() or str(pilot.get("status", "")) != "idle":
				continue
			apply_pilot_state_delta(pilot_id, {"fatigue": -1, "mood": 1})

func hire_pilot(pilot_id: String) -> bool:
	var data := get_pilot_data(pilot_id)
	if data.is_empty() or is_pilot_hired(pilot_id):
		return false
	if not can_hire_more_pilots():
		return false
	if total_credits < int(data["cost"]):
		return false
	total_credits -= int(data["cost"])
	hired_pilots.append(_with_pilot_living_state({
		"id":                  data["id"],
		"name":                data["name"],
		"tier":                data["tier"],
		"bonus_type":          data["bonus_type"],
		"bonus_value":         data["bonus_value"],
		"portrait_color":      data["portrait_color"],
		"status":              "idle",
		"preferred_regions":    data.get("preferred_regions", []),
		"favorite_facilities": data.get("favorite_facilities", []),
		"personality":         data.get("personality", ""),
	}))
	_auto_assign_bed(pilot_id)
	credits_changed.emit(total_credits)
	pilot_hired.emit(pilot_id)
	board_pilot_ids = _select_board_from_pool(_build_board_pool(), _board_seed())
	board_refreshed.emit()
	return true

func create_custom_pilot(custom_name: String, color_hex: String) -> bool:
	if custom_name.strip_edges().is_empty():
		return false
	if not can_hire_more_pilots():
		return false
	var cost := 300
	if total_credits < cost:
		return false
	total_credits -= cost
	var uid := "custom_%d" % Time.get_ticks_msec()
	hired_pilots.append(_with_pilot_living_state({
		"id":             uid,
		"name":           custom_name.strip_edges(),
		"tier":           1,
		"bonus_type":     "none",
		"bonus_value":    0,
		"portrait_color": color_hex,
		"status":         "idle",
		"is_custom":      true,
	}))
	_auto_assign_bed(uid)
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

func assemble_machine(slot_index: int, body_tier: int, weapon_tier: int, legs_tier: int, iids: Dictionary = {}, machine_name: String = "") -> bool:
	return _dispatch.assemble_machine(slot_index, body_tier, weapon_tier, legs_tier, iids, machine_name)

func rename_bay(slot_index: int, new_name: String) -> bool:
	return _dispatch.rename_bay(slot_index, new_name)

func rename_machine(slot_index: int, new_name: String) -> bool:
	return _dispatch.rename_machine(slot_index, new_name)

func calc_part_refund(item: Dictionary) -> int:
	var type: String = str(item.get("type", ""))
	var tier: int    = int(item.get("tier", 1))
	var cost := 0
	if PARTS.has(type):
		var tiers: Array = PARTS[type]["tiers"]
		if tier >= 1 and tier <= tiers.size():
			cost = int(tiers[tier - 1].get("cost", 0))
	var has_opts := not (item.get("options", []) as Array).is_empty()
	var rate := 0.45 if has_opts else 0.35
	return maxi(1, int(float(cost) * rate))

func disassemble_part(iid: String) -> int:
	for i in part_inventory.size():
		var item: Dictionary = part_inventory[i]
		if str(item.get("iid", "")) == iid:
			var refund := calc_part_refund(item)
			part_inventory.remove_at(i)
			total_credits += refund
			credits_changed.emit(total_credits)
			return refund
	return -1

func get_pilot_accessible_planets(pilot_id: String) -> Array:
	var p := get_hired_pilot(pilot_id)
	if p.is_empty():
		return []
	return _dispatch.get_pilot_accessible_planets(int(p.get("tier", 1)))

func start_auto_dispatch(slot_index: int, pilot_id: String, planet_id: String) -> bool:
	return _dispatch.start_auto_dispatch(slot_index, pilot_id, planet_id)

func collect_auto_slot(slot_index: int) -> bool:
	return _dispatch.collect_auto_slot(slot_index)

func set_slot_auto_redispatch(slot_index: int, enabled: bool, pilot_id: String = "", planet_id: String = "") -> void:
	_dispatch.set_slot_auto_redispatch(slot_index, enabled, pilot_id, planet_id)

func get_machine_preview(body_tier: int, weapon_tier: int, legs_tier: int, opts: Dictionary = {}) -> Dictionary:
	return _dispatch.get_machine_preview(body_tier, weapon_tier, legs_tier, opts)


func assign_pilot_to_slot(slot_index: int, pilot_id: String) -> bool:
	var ok := _dispatch.assign_pilot_to_slot(slot_index, pilot_id)
	if ok:
		slot_pilot_assigned.emit(slot_index)
	return ok


func remove_machine_part(slot_index: int, part_type: String) -> bool:
	return _dispatch.remove_machine_part(slot_index, part_type)

func replace_machine_part(slot_index: int, part_type: String, tier: int, iid: String = "") -> bool:
	return _dispatch.replace_machine_part(slot_index, part_type, tier, iid)


func disassemble_machine(slot_index: int) -> bool:
	return _dispatch.disassemble_machine(slot_index)

func unlock_hangar(group_id: int) -> bool:
	return _dispatch.unlock_hangar(group_id)

func get_hangar_group(group_id: int) -> DispatchManager.HangarGroup:
	return _dispatch.get_hangar_group(group_id)

func apply_dispatch_save(slot_data: Array, save_time: float, groups_data: Array = []) -> void:
	_dispatch.apply_save_data(slot_data, save_time, groups_data)
