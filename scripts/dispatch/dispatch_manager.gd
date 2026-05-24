class_name DispatchManager
extends Node

signal auto_slot_changed(index: int)
signal auto_dispatch_returned(slot_index: int)

const BASE_RETURN_TIME: float = 30.0

# ── AutoSlot ──────────────────────────────────────────────
# 슬롯 상태: locked | empty | offline | on_mission | returning | returned

class AutoSlot:
	var state: String = "empty"
	var unlock_cost: int = 0
	var machine: Dictionary = {}   # {body: int, weapon: int, legs: int}
	var pilot_tier: int = 0
	var planet: String = ""
	var mission_end_time: float = INF
	var return_end_time: float = INF
	var credits_earned: int = 0

	static func make_empty() -> AutoSlot:
		return AutoSlot.new()

	static func make_locked(cost: int) -> AutoSlot:
		var s := AutoSlot.new()
		s.state = "locked"
		s.unlock_cost = cost
		return s

	func reset_mission_data() -> void:
		pilot_tier = 0
		planet = ""
		mission_end_time = INF
		return_end_time = INF
		credits_earned = 0

# ── 슬롯 초기화 ───────────────────────────────────────────

var auto_slots: Array = []

func _ready() -> void:
	auto_slots = [
		AutoSlot.make_empty(),
		AutoSlot.make_locked(300),
		AutoSlot.make_locked(700),
	]

# ── 타이머 ────────────────────────────────────────────────

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

# ── 슬롯 잠금 해제 ───────────────────────────────────────

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

# ── 머신 조립 ─────────────────────────────────────────────

func get_assembly_cost(body_tier: int, weapon_tier: int, legs_tier: int) -> int:
	return (body_tier + weapon_tier + legs_tier) * 50

func assemble_machine(slot_index: int, body_tier: int, weapon_tier: int, legs_tier: int) -> bool:
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
	GameState.total_credits -= cost
	GameState.owned_parts["body"][body_tier - 1] -= 1
	GameState.owned_parts["weapon"][weapon_tier - 1] -= 1
	GameState.owned_parts["legs"][legs_tier - 1] -= 1
	slot.state = "offline"
	slot.machine = {"body": body_tier, "weapon": weapon_tier, "legs": legs_tier}
	GameState.credits_changed.emit(GameState.total_credits)
	auto_slot_changed.emit(slot_index)
	return true

# ── 파견 ──────────────────────────────────────────────────

func get_pilot_accessible_planets(pilot_tier: int) -> Array:
	var result: Array = []
	for i in GameState.PLANETS.size():
		if i < pilot_tier and GameState.is_planet_unlocked(GameState.PLANETS[i]["id"]):
			result.append(GameState.PLANETS[i])
	return result

func start_auto_dispatch(slot_index: int, pilot_tier: int, planet_id: String) -> bool:
	if slot_index < 0 or slot_index >= auto_slots.size():
		return false
	var slot: AutoSlot = auto_slots[slot_index]
	if slot.state != "offline":
		return false
	if GameState.get_owned_qty("pilot", pilot_tier) <= 0:
		return false
	if not GameState.is_planet_unlocked(planet_id):
		return false
	var ok := false
	for p in get_pilot_accessible_planets(pilot_tier):
		if p["id"] == planet_id:
			ok = true
			break
	if not ok:
		return false
	GameState.owned_parts["pilot"][pilot_tier - 1] -= 1
	var body_tier: int = slot.machine.get("body", 1)
	var now := Time.get_unix_time_from_system()
	slot.state = "on_mission"
	slot.pilot_tier = pilot_tier
	slot.planet = planet_id
	slot.mission_end_time = now + _get_mission_duration(body_tier)
	auto_slot_changed.emit(slot_index)
	return true

# ── 수령 ──────────────────────────────────────────────────

func collect_auto_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= auto_slots.size():
		return false
	var slot: AutoSlot = auto_slots[slot_index]
	if slot.state != "returned":
		return false
	if slot.pilot_tier >= 1 and slot.pilot_tier <= GameState.owned_parts["pilot"].size():
		GameState.owned_parts["pilot"][slot.pilot_tier - 1] += 1
	GameState.total_credits += slot.credits_earned
	GameState.credits_changed.emit(GameState.total_credits)
	slot.reset_mission_data()
	slot.state = "offline"
	auto_slot_changed.emit(slot_index)
	return true

# ── 내부 상태 전환 ────────────────────────────────────────

func _start_returning(slot_index: int, now: float) -> void:
	var slot: AutoSlot = auto_slots[slot_index]
	var body_tier: int = slot.machine.get("body", 1)
	var weapon_tier: int = slot.machine.get("weapon", 1)
	var legs_tier: int = slot.machine.get("legs", 1)
	slot.credits_earned = _get_mission_credits(weapon_tier, _get_mission_duration(body_tier))
	slot.state = "returning"
	slot.return_end_time = now + _get_return_duration(legs_tier)
	auto_slot_changed.emit(slot_index)

func _complete_return(slot_index: int) -> void:
	var slot: AutoSlot = auto_slots[slot_index]
	slot.state = "returned"
	auto_slot_changed.emit(slot_index)
	auto_dispatch_returned.emit(slot_index)

# ── 머신 스펙 미리보기 ───────────────────────────────────

func get_machine_preview(body_tier: int, weapon_tier: int, legs_tier: int) -> Dictionary:
	var mission_time := _get_mission_duration(body_tier) if body_tier > 0 else 0.0
	var return_time  := _get_return_duration(legs_tier)  if legs_tier  > 0 else 0.0
	var rate: int = 0
	if weapon_tier >= 1 and weapon_tier <= PartsData.DICT["weapon"]["tiers"].size():
		rate = PartsData.DICT["weapon"]["tiers"][weapon_tier - 1]["value"]
	var credits: int = int(float(rate) * mission_time) if (body_tier > 0 and weapon_tier > 0) else 0
	return {
		"mission_time": mission_time,
		"return_time":  return_time,
		"credits":      credits,
		"rate":         rate,
	}

# ── 수치 계산 헬퍼 ────────────────────────────────────────

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
