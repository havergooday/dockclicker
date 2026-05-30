class_name DispatchManager
extends Node

signal auto_slot_changed(index: int)
signal auto_dispatch_returned(slot_index: int)

const BASE_RETURN_TIME: float = 30.0

# ── HangarGroup ───────────────────────────────────────────────
# 격납고 단위 잠금. 각 격납고는 4개의 베이 슬롯을 포함.

class HangarGroup:
	var id: int = 0
	var locked: bool = false
	var unlock_cost: int = 0

# ── AutoSlot ──────────────────────────────────────────────────
# 슬롯 상태: locked | empty | offline | on_mission | returning | returned

class AutoSlot:
	var state: String = "empty"
	var unlock_cost: int = 0
	var hangar_group_id: int = 0
	var machine: Dictionary = {}   # {body: int, weapon: int, legs: int}
	var custom_name: String = ""   # 사용자 지정 베이 이름
	var assigned_pilot_id: String = ""  # 베이 사전 배정 파일럿 (임무와 무관하게 유지)
	var pilot_id: String = ""
	var planet: String = ""
	var mission_start_time: float = 0.0
	var mission_end_time: float = INF
	var return_start_time: float = 0.0
	var return_end_time: float = INF
	var credits_earned: int = 0
	# 자동 재파견 설정 (수령 후 즉시 동일 조건으로 재파견)
	var auto_redispatch: bool = false
	var auto_pilot_id: String = ""
	var auto_planet: String = ""
	# 미완성 조립 드래프트 (empty 상태에서 팝업 닫을 때 기록)
	var pending_machine: Dictionary = {}
	var pending_pilot_id: String = ""

	static func make_empty(group_id: int = 0) -> AutoSlot:
		var s := AutoSlot.new()
		s.hangar_group_id = group_id
		return s

	static func make_locked(cost: int, group_id: int = 0) -> AutoSlot:
		var s := AutoSlot.new()
		s.state = "locked"
		s.unlock_cost = cost
		s.hangar_group_id = group_id
		return s

	func reset_mission_data() -> void:
		pilot_id = ""
		planet = ""
		mission_end_time = INF
		return_end_time = INF
		credits_earned = 0
		# auto_redispatch 설정은 유지

# ── 초기화 ────────────────────────────────────────────────────

var hangar_groups: Array = []  # Array[HangarGroup]
var auto_slots: Array = []

# 격납고별 해금 비용 / 베이별 개별 해금 비용
const HANGAR_COSTS: Array  = [0, 5000, 50000, 500000]
const BAY_COSTS: Array     = [300, 700, 1500, 3500]  # 격납고 내 베이 2~4번 비용

func _ready() -> void:
	_init_default_layout()


func _init_default_layout() -> void:
	hangar_groups.clear()
	auto_slots.clear()
	for g in 4:
		var hg := HangarGroup.new()
		hg.id = g
		hg.locked = g > 0  # 격납고 0만 기본 해금
		hg.unlock_cost = HANGAR_COSTS[g]
		hangar_groups.append(hg)
		# 격납고 0의 첫 베이(g*4+0)는 기본 오픈, 나머지는 잠금
		for b in 4:
			var slot: AutoSlot
			if g == 0 and b == 0:
				slot = AutoSlot.make_empty(g)
			else:
				slot = AutoSlot.make_locked(BAY_COSTS[b] if b > 0 else BAY_COSTS[0], g)
			auto_slots.append(slot)

# ── 타이머 ────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	var now := Time.get_unix_time_from_system()
	for i in auto_slots.size():
		var slot: AutoSlot = auto_slots[i]
		if slot.state == "on_mission":
			if now >= slot.mission_end_time:
				_start_returning(i, now)
		elif slot.state == "returning":
			if now >= slot.return_end_time:
				_complete_return(i)

# ── 격납고 잠금 해제 ──────────────────────────────────────────

func unlock_hangar(group_id: int) -> bool:
	if group_id < 0 or group_id >= hangar_groups.size():
		return false
	var group: HangarGroup = hangar_groups[group_id]
	if not group.locked:
		return false
	if GameState.total_credits < group.unlock_cost:
		return false
	GameState.total_credits -= group.unlock_cost
	group.locked = false
	GameState.credits_changed.emit(GameState.total_credits)
	for i in auto_slots.size():
		if (auto_slots[i] as AutoSlot).hangar_group_id == group_id:
			auto_slot_changed.emit(i)
	return true


func get_hangar_group(group_id: int) -> HangarGroup:
	if group_id < 0 or group_id >= hangar_groups.size():
		return null
	return hangar_groups[group_id]


# ── 슬롯 잠금 해제 ───────────────────────────────────────────

func unlock_auto_slot(index: int) -> bool:
	if index < 0 or index >= auto_slots.size():
		return false
	var slot: AutoSlot = auto_slots[index]
	if slot.state != "locked":
		return false
	if GameState.total_credits < slot.unlock_cost:
		return false
	GameState.total_credits -= slot.unlock_cost
	slot.state = "empty"
	GameState.credits_changed.emit(GameState.total_credits)
	auto_slot_changed.emit(index)
	return true

# ── 머신 조립 ─────────────────────────────────────────────────

func get_assembly_cost(body_tier: int, weapon_tier: int, legs_tier: int) -> int:
	return (body_tier + weapon_tier + legs_tier) * 50

func assemble_machine(slot_index: int, body_tier: int, weapon_tier: int, legs_tier: int, iids: Dictionary = {}, machine_name: String = "") -> bool:
	if slot_index < 0 or slot_index >= auto_slots.size():
		return false
	var slot: AutoSlot = auto_slots[slot_index]
	if slot.state != "empty":
		return false
	if GameState.get_owned_qty("body", body_tier) <= 0:
		return false
	if GameState.get_owned_qty("weapon", weapon_tier) <= 0:
		return false
	if GameState.get_owned_qty("legs", legs_tier) <= 0:
		return false
	var cost := get_assembly_cost(body_tier, weapon_tier, legs_tier)
	if GameState.total_credits < cost:
		return false
	var body_opts   := _lookup_opts(iids.get("body",   ""), "body",   body_tier)
	var weapon_opts := _lookup_opts(iids.get("weapon", ""), "weapon", weapon_tier)
	var legs_opts   := _lookup_opts(iids.get("legs",   ""), "legs",   legs_tier)
	GameState.total_credits -= cost
	GameState.consume_part_by_iid(str(iids.get("body",   "")), "body",   body_tier)
	GameState.consume_part_by_iid(str(iids.get("weapon", "")), "weapon", weapon_tier)
	GameState.consume_part_by_iid(str(iids.get("legs",   "")), "legs",   legs_tier)
	slot.state = "offline"
	slot.machine = {
		"body": body_tier, "weapon": weapon_tier, "legs": legs_tier,
		"body_opts": body_opts, "weapon_opts": weapon_opts, "legs_opts": legs_opts,
		"name": machine_name,
	}
	slot.pending_machine = {}
	slot.pending_pilot_id = ""
	GameState.credits_changed.emit(GameState.total_credits)
	auto_slot_changed.emit(slot_index)
	return true

func rename_bay(slot_index: int, new_name: String) -> bool:
	if slot_index < 0 or slot_index >= auto_slots.size():
		return false
	auto_slots[slot_index].custom_name = new_name.strip_edges()
	auto_slot_changed.emit(slot_index)
	return true


func rename_machine(slot_index: int, new_name: String) -> bool:
	if slot_index < 0 or slot_index >= auto_slots.size():
		return false
	var slot: AutoSlot = auto_slots[slot_index]
	if slot.machine.is_empty():
		return false
	slot.machine["name"] = new_name.strip_edges()
	auto_slot_changed.emit(slot_index)
	return true


# ── 파견 ──────────────────────────────────────────────────────

func get_pilot_accessible_planets(pilot_tier: int) -> Array:
	var result: Array = []
	for i in GameState.PLANETS.size():
		if i < pilot_tier and GameState.is_planet_unlocked(GameState.PLANETS[i]["id"]):
			result.append(GameState.PLANETS[i])
	return result

func start_auto_dispatch(slot_index: int, pilot_id: String, planet_id: String) -> bool:
	if slot_index < 0 or slot_index >= auto_slots.size():
		return false
	var slot: AutoSlot = auto_slots[slot_index]
	if slot.state != "offline":
		return false
	var pilot := GameState.get_hired_pilot(pilot_id)
	if pilot.is_empty() or pilot.get("status", "") != "idle":
		return false
	if not GameState.is_planet_unlocked(planet_id):
		return false
	var pilot_tier: int = int(pilot.get("tier", 1))
	var ok := false
	for p in get_pilot_accessible_planets(pilot_tier):
		if p["id"] == planet_id:
			ok = true
			break
	if not ok:
		return false
	pilot["status"] = "on_mission"
	GameState.pilot_status_changed.emit(pilot_id)
	var body_tier: int = slot.machine.get("body", 1)
	var now := Time.get_unix_time_from_system()
	slot.state = "on_mission"
	slot.pilot_id = pilot_id
	slot.planet = planet_id
	var duration := _get_mission_duration(body_tier)
	duration *= _opts_time_mult(slot.machine, "dispatch_time_pct")
	if pilot.get("bonus_type", "") == "speed":
		duration *= (1.0 - float(pilot.get("bonus_value", 0)) / 100.0)
	slot.mission_start_time = now
	slot.mission_end_time = now + maxf(5.0, duration)
	auto_slot_changed.emit(slot_index)
	return true

# ── 수령 ──────────────────────────────────────────────────────

func collect_auto_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= auto_slots.size():
		return false
	var slot: AutoSlot = auto_slots[slot_index]
	if slot.state != "returned":
		return false
	if slot.pilot_id != "":
		var pilot := GameState.get_hired_pilot(slot.pilot_id)
		if not pilot.is_empty():
			pilot["status"] = "idle"
			GameState.pilot_status_changed.emit(slot.pilot_id)
	GameState.total_credits += slot.credits_earned
	GameState.credits_changed.emit(GameState.total_credits)
	slot.reset_mission_data()
	slot.state = "offline"
	auto_slot_changed.emit(slot_index)
	return true

# ── 내부 상태 전환 ────────────────────────────────────────────

func _start_returning(slot_index: int, now: float) -> void:
	var slot: AutoSlot = auto_slots[slot_index]
	var body_tier: int   = slot.machine.get("body",   1)
	var weapon_tier: int = slot.machine.get("weapon", 1)
	var legs_tier: int   = slot.machine.get("legs",   1)
	var actual_duration := slot.mission_end_time - slot.mission_start_time
	var base_credits := _get_mission_credits(weapon_tier, actual_duration)
	base_credits = int(float(base_credits) * _opts_credits_mult(slot.machine))
	var pilot := GameState.get_hired_pilot(slot.pilot_id)
	if not pilot.is_empty() and pilot.get("bonus_type", "") == "credits":
		base_credits = int(float(base_credits) * (1.0 + float(pilot.get("bonus_value", 0)) / 100.0))
	slot.credits_earned = base_credits
	slot.state = "returning"
	slot.return_start_time = now
	var ret_dur := _get_return_duration(legs_tier) * _opts_time_mult(slot.machine, "return_time_pct")
	slot.return_end_time = now + maxf(5.0, ret_dur)
	auto_slot_changed.emit(slot_index)

func _complete_return(slot_index: int) -> void:
	var slot: AutoSlot = auto_slots[slot_index]
	slot.state = "returned"
	auto_slot_changed.emit(slot_index)
	auto_dispatch_returned.emit(slot_index)
	if slot.auto_redispatch and slot.auto_pilot_id != "" and slot.auto_planet != "":
		_do_auto_redispatch(slot_index)

# ── 머신 스펙 미리보기 ───────────────────────────────────────

func get_machine_preview(body_tier: int, weapon_tier: int, legs_tier: int, opts: Dictionary = {}) -> Dictionary:
	var mission_time := _get_mission_duration(body_tier) if body_tier > 0 else 0.0
	var return_time  := _get_return_duration(legs_tier)  if legs_tier  > 0 else 0.0
	if not opts.is_empty():
		mission_time *= _opts_time_mult(opts, "dispatch_time_pct")
		return_time  *= _opts_time_mult(opts, "return_time_pct")
	var rate: int = 0
	if weapon_tier >= 1 and weapon_tier <= PartsData.DICT["weapon"]["tiers"].size():
		rate = PartsData.DICT["weapon"]["tiers"][weapon_tier - 1]["value"]
	var credits: int = int(float(rate) * mission_time) if (body_tier > 0 and weapon_tier > 0) else 0
	if credits > 0 and not opts.is_empty():
		credits = int(float(credits) * _opts_credits_mult(opts))
	return {
		"mission_time": mission_time,
		"return_time":  return_time,
		"credits":      credits,
		"rate":         rate,
	}

# ── 수치 계산 헬퍼 ────────────────────────────────────────────

func _get_mission_duration(body_tier: int) -> float:
	var tiers: Array = PartsData.DICT["body"]["tiers"]
	if body_tier < 1 or body_tier > tiers.size():
		return 30.0
	return float(tiers[body_tier - 1]["value"])

func _get_return_duration(legs_tier: int) -> float:
	var tiers: Array = PartsData.DICT["legs"]["tiers"]
	if legs_tier < 1 or legs_tier > tiers.size():
		return BASE_RETURN_TIME
	var reduction: int = tiers[legs_tier - 1]["value"]
	return maxf(5.0, BASE_RETURN_TIME - float(reduction))

func _get_mission_credits(weapon_tier: int, mission_duration: float) -> int:
	var tiers: Array = PartsData.DICT["weapon"]["tiers"]
	if weapon_tier < 1 or weapon_tier > tiers.size():
		return int(mission_duration)
	var rate: int = tiers[weapon_tier - 1]["value"]
	return int(float(rate) * mission_duration)

# ── 저장/불러오기 ─────────────────────────────────────────────────

func apply_save_data(slot_data: Array, save_time: float, groups_data: Array = []) -> void:
	# 격납고 그룹 복원 (없으면 슬롯 상태로 자동 추론)
	hangar_groups.clear()
	if groups_data.size() >= 4:
		for gd in groups_data:
			var d: Dictionary = gd as Dictionary
			var hg := HangarGroup.new()
			hg.id          = int(d.get("id",           0))
			hg.locked      = bool(d.get("locked",       false))
			hg.unlock_cost = int(d.get("unlock_cost",   0))
			hangar_groups.append(hg)
	else:
		# v3→v4 마이그레이션: 슬롯 상태로 격납고 잠금 추론
		for g in 4:
			var hg := HangarGroup.new()
			hg.id          = g
			hg.unlock_cost = HANGAR_COSTS[g]
			var any_open := g == 0  # 격납고 0은 항상 해금
			if not any_open:
				for i in range(g * 4, min(g * 4 + 4, slot_data.size())):
					if slot_data[i].get("state", "locked") != "locked":
						any_open = true
						break
			hg.locked = not any_open
			hangar_groups.append(hg)

	auto_slots.clear()
	for i in slot_data.size():
		var d: Dictionary = slot_data[i] as Dictionary
		var slot := AutoSlot.new()
		slot.state             = str(d.get("state",             "empty"))
		slot.unlock_cost       = int(d.get("unlock_cost",       0))
		slot.hangar_group_id   = int(d.get("hangar_group_id",   i / 4))
		var mraw               = d.get("machine", {})
		slot.machine           = (mraw as Dictionary).duplicate() if mraw is Dictionary else {}
		slot.custom_name       = str(d.get("custom_name",        ""))
		slot.pilot_id          = str(d.get("pilot_id",          ""))
		slot.assigned_pilot_id = str(d.get("assigned_pilot_id", ""))
		slot.planet            = str(d.get("planet",            ""))
		slot.mission_start_time  = float(d.get("mission_start_time",  0.0))
		slot.mission_end_time    = _dec(d.get("mission_end_time",    INF))
		slot.return_start_time   = float(d.get("return_start_time",  0.0))
		slot.return_end_time     = _dec(d.get("return_end_time",     INF))
		slot.credits_earned    = int(d.get("credits_earned",    0))
		slot.auto_redispatch   = bool(d.get("auto_redispatch",  false))
		slot.auto_pilot_id     = str(d.get("auto_pilot_id",     ""))
		slot.auto_planet       = str(d.get("auto_planet",       ""))
		var pmraw              = d.get("pending_machine", {})
		slot.pending_machine   = (pmraw as Dictionary).duplicate() if pmraw is Dictionary else {}
		slot.pending_pilot_id  = str(d.get("pending_pilot_id",  ""))
		auto_slots.append(slot)
	_fast_forward(Time.get_unix_time_from_system())

func _fast_forward(now: float) -> void:
	for i: int in auto_slots.size():
		var slot: AutoSlot = auto_slots[i]
		if slot.state == "on_mission" and now >= slot.mission_end_time:
			var b: int = slot.machine.get("body",   1)
			var w: int = slot.machine.get("weapon", 1)
			var l: int = slot.machine.get("legs",   1)
			var actual_duration := slot.mission_end_time - slot.mission_start_time
			var base_credits := _get_mission_credits(w, actual_duration)
			base_credits = int(float(base_credits) * _opts_credits_mult(slot.machine))
			var pilot := GameState.get_hired_pilot(slot.pilot_id)
			if not pilot.is_empty() and pilot.get("bonus_type", "") == "credits":
				base_credits = int(float(base_credits) * (1.0 + float(pilot.get("bonus_value", 0)) / 100.0))
			slot.credits_earned  = base_credits
			slot.state           = "returning"
			var ret_dur := _get_return_duration(l) * _opts_time_mult(slot.machine, "return_time_pct")
			slot.return_end_time = slot.mission_end_time + maxf(5.0, ret_dur)
		if slot.state == "returning" and now >= slot.return_end_time:
			slot.state = "returned"

func _dec(v) -> float:
	var f := float(v)
	return INF if f >= 1e29 else f


# ── 파츠 옵션 헬퍼 ───────────────────────────────────────────────

func _lookup_opts(iid: String, part_type: String, _tier: int) -> Array:
	if iid == "":
		return []
	for item: Dictionary in GameState.part_inventory:
		if str(item.get("iid", "")) == iid and str(item.get("type", "")) == part_type:
			return (item.get("options", []) as Array).duplicate()
	return []


func _opts_credits_mult(machine: Dictionary) -> float:
	var mult := 1.0
	for key in ["body_opts", "weapon_opts", "legs_opts"]:
		for opt: Dictionary in machine.get(key, []):
			if opt.get("type", "") == "credits_pct":
				mult += float(opt.get("value", 0)) / 100.0
	return mult


func _opts_time_mult(machine: Dictionary, opt_type: String) -> float:
	var mult := 1.0
	for key in ["body_opts", "weapon_opts", "legs_opts"]:
		for opt: Dictionary in machine.get(key, []):
			if opt.get("type", "") == opt_type:
				mult -= float(opt.get("value", 0)) / 100.0
	return maxf(0.1, mult)

# ── 자동 재파견 ───────────────────────────────────────────────────────

func _do_auto_redispatch(slot_index: int) -> void:
	var slot: AutoSlot = auto_slots[slot_index]
	if slot.pilot_id != "":
		var pilot := GameState.get_hired_pilot(slot.pilot_id)
		if not pilot.is_empty():
			pilot["status"] = "idle"
			GameState.pilot_status_changed.emit(slot.pilot_id)
	GameState.total_credits += slot.credits_earned
	GameState.credits_changed.emit(GameState.total_credits)
	slot.reset_mission_data()
	slot.state = "offline"
	start_auto_dispatch(slot_index, slot.auto_pilot_id, slot.auto_planet)


func assign_pilot_to_slot(slot_index: int, pilot_id: String) -> bool:
	if slot_index < 0 or slot_index >= auto_slots.size():
		return false
	var slot: AutoSlot = auto_slots[slot_index]
	if slot.state != "offline":
		return false
	if pilot_id != "":
		var pilot := GameState.get_hired_pilot(pilot_id)
		if pilot.is_empty():
			return false
		for i in auto_slots.size():
			if i != slot_index:
				var s: AutoSlot = auto_slots[i]
				if s.assigned_pilot_id == pilot_id:
					s.assigned_pilot_id = ""
					auto_slot_changed.emit(i)
	slot.assigned_pilot_id = pilot_id
	auto_slot_changed.emit(slot_index)
	return true


func remove_machine_part(slot_index: int, part_type: String) -> bool:
	if slot_index < 0 or slot_index >= auto_slots.size():
		return false
	if part_type not in ["body", "weapon", "legs"]:
		return false
	var slot: AutoSlot = auto_slots[slot_index]
	if slot.state != "offline":
		return false
	var old_tier: int = int(slot.machine.get(part_type, 0))
	if old_tier <= 0:
		return false
	GameState.part_inventory.append({
		"iid":     "rem_%d" % Time.get_ticks_usec(),
		"type":    part_type,
		"tier":    old_tier,
		"options": slot.machine.get(part_type + "_opts", []),
	})
	slot.machine.erase(part_type)
	slot.machine.erase(part_type + "_opts")
	auto_slot_changed.emit(slot_index)
	return true


func replace_machine_part(slot_index: int, part_type: String, tier: int, iid: String = "") -> bool:
	if slot_index < 0 or slot_index >= auto_slots.size():
		return false
	if part_type not in ["body", "weapon", "legs"]:
		return false
	if tier <= 0:
		return false
	if GameState.get_owned_qty(part_type, tier) <= 0:
		return false
	var slot: AutoSlot = auto_slots[slot_index]
	if slot.state != "offline":
		return false
	var old_tier: int = int(slot.machine.get(part_type, 0))
	if not GameState.consume_part_by_iid(iid, part_type, tier):
		return false
	if old_tier > 0:
		GameState.part_inventory.append({
			"iid":     "swap_%d" % Time.get_ticks_usec(),
			"type":    part_type,
			"tier":    old_tier,
			"options": slot.machine.get(part_type + "_opts", []),
		})
	slot.machine[part_type] = tier
	slot.machine[part_type + "_opts"] = _lookup_opts(iid, part_type, tier)
	auto_slot_changed.emit(slot_index)
	return true


func disassemble_machine(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= auto_slots.size():
		return false
	var slot: AutoSlot = auto_slots[slot_index]
	if slot.state != "offline":
		return false
	var b: int = slot.machine.get("body", 0)
	var w: int = slot.machine.get("weapon", 0)
	var l: int = slot.machine.get("legs", 0)
	if b > 0:
		GameState.part_inventory.append({"iid": "dis_%d" % Time.get_ticks_usec(), "type": "body",   "tier": b, "options": slot.machine.get("body_opts",   [])})
	if w > 0:
		GameState.part_inventory.append({"iid": "dis_%d" % Time.get_ticks_usec(), "type": "weapon", "tier": w, "options": slot.machine.get("weapon_opts", [])})
	if l > 0:
		GameState.part_inventory.append({"iid": "dis_%d" % Time.get_ticks_usec(), "type": "legs",   "tier": l, "options": slot.machine.get("legs_opts",   [])})
	slot.machine = {}
	slot.assigned_pilot_id = ""
	slot.state = "empty"
	auto_slot_changed.emit(slot_index)
	return true
