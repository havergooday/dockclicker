extends Node

const SAVE_PATH    := "user://save.json"
const SAVE_VERSION := 5
const _INF_SUB     := 1e30  # INF를 JSON에 저장할 때 대체값

func _ready() -> void:
	load_save()
	GameState.credits_changed.connect(func(_v): save())
	GameState.resources_changed.connect(func(_resources: Dictionary): save())
	GameState.auto_slot_changed.connect(func(_i): save())
	GameState.pilot_hired.connect(func(_id): save())
	GameState.pilot_status_changed.connect(func(_id): save())
	GameState.board_refreshed.connect(func(): save())
	GameState.quarters_changed.connect(func(): save())
	GameState.feature_unlocked.connect(func(_id: String): save())
	GameState.base_area_unlocks_changed.connect(func(): save())
	GameState.facilities_changed.connect(func(): save())
	GameState.placeable_positions_changed.connect(func(): save())
	GameState.hud_position_changed.connect(func(_p): save())

# ── 저장 ─────────────────────────────────────────────────────────

func save() -> void:
	var data := {
		"version":              SAVE_VERSION,
		"save_time":            Time.get_unix_time_from_system(),
		"total_credits":        GameState.total_credits,
		"resources":            GameState.resources.duplicate(),
		"pending_credits":      GameState.pending_credits,
		"player_status":        GameState.player_status,
		"click_damage":         GameState.click_damage,
		"damage_upgrade_level": GameState.damage_upgrade_level,
		"auto_attack_unlocked": GameState.auto_attack_unlocked,
		"click_range_level":    GameState.click_range_level,
		"combo_level":          GameState.combo_level,
		"selected_planet":      GameState.selected_planet,
		"unlocked_planets":     GameState.unlocked_planets.duplicate(),
		"part_inventory": GameState.part_inventory.duplicate(true),
		"hired_pilots":    _serialize_pilots(),
		"auto_slots":      _serialize_slots(),
		"hangar_groups":   _serialize_hangar_groups(),
		"ui_positions":    GameState.ui_positions.duplicate(),
		"board_pilot_ids":     GameState.board_pilot_ids.duplicate(),
		"board_last_day":      GameState.board_last_day,
		"board_refresh_count": GameState.board_refresh_count,
		"quarters_beds":       _serialize_quarters(),
		"unlocked_features":   GameState.unlocked_features.duplicate(),
		"base_area_unlocks":   GameState.base_area_unlocks.duplicate(true),
		"lounge_slots":        GameState.lounge_slots.duplicate(),
		"placeable_positions": GameState.placeable_positions.duplicate(true),
		"hud_position":        GameState.hud_position,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot write " + SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

# ── 불러오기 ──────────────────────────────────────────────────────

func load_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("SaveManager: corrupt save file — ignored")
		return false
	var d: Dictionary = parsed as Dictionary

	GameState.total_credits        = int(d.get("total_credits",        0))
	var resources_raw = d.get("resources", {})
	if resources_raw is Dictionary:
		GameState.resources = (resources_raw as Dictionary).duplicate()
	else:
		GameState.resources = {"alloy": 0, "supplies": 0, "circuit": 0}
	for resource_id in ["alloy", "supplies", "circuit"]:
		if not GameState.resources.has(resource_id):
			GameState.resources[resource_id] = 0
	GameState.pending_credits      = int(d.get("pending_credits",      0))
	GameState.player_status        = str(d.get("player_status",        "idle"))
	GameState.click_damage         = int(d.get("click_damage",         1))
	GameState.damage_upgrade_level = int(d.get("damage_upgrade_level", 0))
	GameState.auto_attack_unlocked = bool(d.get("auto_attack_unlocked", false))
	GameState.click_range_level    = int(d.get("click_range_level",    0))
	GameState.combo_level          = int(d.get("combo_level",          0))
	GameState.selected_planet      = str(d.get("selected_planet",      "sector_a"))
	GameState.unlocked_planets     = (d.get("unlocked_planets", ["sector_a"]) as Array).duplicate()
	var feat_raw = d.get("unlocked_features", [])
	GameState.unlocked_features = (feat_raw as Array).duplicate() if feat_raw is Array else []
	var base_area_defaults: Dictionary = {
		"quarters": true,
		"lounge": false,
		"canteen": false,
		"medbay": false,
	}
	var base_area_raw = d.get("base_area_unlocks", {})
	if base_area_raw is Dictionary:
		GameState.base_area_unlocks = (base_area_raw as Dictionary).duplicate(true)
	else:
		GameState.base_area_unlocks = {}
	for area_id in base_area_defaults.keys():
		if not GameState.base_area_unlocks.has(area_id):
			GameState.base_area_unlocks[area_id] = base_area_defaults[area_id]
	for feature_id in GameState.unlocked_features:
		if GameState.base_area_unlocks.has(feature_id):
			GameState.base_area_unlocks[feature_id] = true
	for feature_id in ["quarters", "canteen"]:
		if bool(GameState.base_area_unlocks.get(feature_id, false)) and not GameState.unlocked_features.has(feature_id):
			GameState.unlocked_features.append(feature_id)
	var lounge_raw = d.get("lounge_slots", {})
	if lounge_raw is Dictionary:
		var loaded_slots := (lounge_raw as Dictionary).duplicate()
		for slot_id in GameState.lounge_slots.keys():
			GameState.lounge_slots[slot_id] = str(loaded_slots.get(slot_id, ""))
	var placeable_raw = d.get("placeable_positions", {})
	if placeable_raw is Dictionary:
		GameState.placeable_positions = (placeable_raw as Dictionary).duplicate(true)

	GameState.part_inventory.clear()
	if d.has("part_inventory"):
		for raw in (d["part_inventory"] as Array):
			var item: Dictionary = raw as Dictionary
			var opts_raw = item.get("options", [])
			GameState.part_inventory.append({
				"iid":     str(item.get("iid",  "p_%d" % Time.get_ticks_usec())),
				"type":    str(item.get("type", "")),
				"tier":    int(item.get("tier", 1)),
				"options": (opts_raw as Array).duplicate() if opts_raw is Array else [],
			})
	elif d.has("owned_parts"):
		# v2 → v3 마이그레이션: 수량 배열을 인스턴스 배열로 변환
		var parts_old: Dictionary = d["owned_parts"] as Dictionary
		for pt: String in ["body", "weapon", "legs"]:
			if not parts_old.has(pt):
				continue
			var counts: Array = parts_old[pt] as Array
			for i in counts.size():
				for _j in int(counts[i]):
					GameState.part_inventory.append({
						"iid":  "migrated_%d" % Time.get_ticks_usec(),
						"type": pt,
						"tier": i + 1,
					})

	var pilots_raw: Array = d.get("hired_pilots", [])
	GameState.hired_pilots.clear()
	for pr in pilots_raw:
		var pd: Dictionary = pr as Dictionary
		var preferred_regions: Array = pd.get("preferred_regions", [])
		var favorite_facilities: Array = pd.get("favorite_facilities", [])
		GameState.hired_pilots.append({
			"id":             str(pd.get("id",             "")),
			"name":           str(pd.get("name",           "")),
			"tier":           int(pd.get("tier",           1)),
			"bonus_type":     str(pd.get("bonus_type",     "none")),
			"bonus_value":    int(pd.get("bonus_value",    0)),
			"portrait_color": str(pd.get("portrait_color", "#4499DD")),
			"status":         str(pd.get("status",         "idle")),
			"fatigue":        int(pd.get("fatigue",        0)),
			"stress":         int(pd.get("stress",         0)),
			"mood":           int(pd.get("mood",           70)),
			"preferred_regions": preferred_regions.duplicate(),
			"favorite_facilities": favorite_facilities.duplicate(),
			"personality":    str(pd.get("personality",    "")),
			"exp":            int(pd.get("exp",            0)),
			"is_custom":      bool(pd.get("is_custom",     false)),
		})

	var slots_raw: Array  = d.get("auto_slots",    [])
	var groups_raw: Array = d.get("hangar_groups", [])
	var save_time: float  = float(d.get("save_time", Time.get_unix_time_from_system()))
	GameState.apply_dispatch_save(slots_raw, save_time, groups_raw)

	var ui_pos = d.get("ui_positions", {})
	if ui_pos is Dictionary:
		GameState.ui_positions = (ui_pos as Dictionary).duplicate()

	GameState.hud_position = str(d.get("hud_position", "right"))

	var board_ids = d.get("board_pilot_ids", [])
	if board_ids is Array:
		GameState.board_pilot_ids = (board_ids as Array).duplicate()
	GameState.board_last_day      = int(d.get("board_last_day",      -1))
	GameState.board_refresh_count = int(d.get("board_refresh_count",  0))

	var beds_raw = d.get("quarters_beds", [])
	if beds_raw is Array and (beds_raw as Array).size() > 0:
		for i in GameState.quarters_beds.size():
			if i >= (beds_raw as Array).size(): break
			var br: Dictionary = (beds_raw as Array)[i] as Dictionary
			GameState.quarters_beds[i]["locked"]      = bool(br.get("locked", i > 0))
			GameState.quarters_beds[i]["unlock_cost"] = int(br.get("unlock_cost",
				GameState.quarters_beds[i]["unlock_cost"]))
			var sl: Array = (br.get("slots", ["", "", ""]) as Array)
			GameState.quarters_beds[i]["slots"] = [
				str(sl[0] if sl.size() > 0 else ""),
				str(sl[1] if sl.size() > 1 else ""),
				str(sl[2] if sl.size() > 2 else ""),
			]
	if GameState.quarters_beds.size() > 0:
		GameState.quarters_beds[0]["locked"] = not bool(GameState.base_area_unlocks.get("quarters", true))

	return true

# ── 직렬화 헬퍼 ───────────────────────────────────────────────────

func _serialize_pilots() -> Array:
	var out: Array = []
	for p in GameState.hired_pilots:
		out.append({
			"id":             p.get("id",             ""),
			"name":           p.get("name",           ""),
			"tier":           p.get("tier",           1),
			"bonus_type":     p.get("bonus_type",     "none"),
			"bonus_value":    p.get("bonus_value",    0),
			"portrait_color": p.get("portrait_color", "#4499DD"),
			"status":         p.get("status",         "idle"),
			"fatigue":        p.get("fatigue",        0),
			"stress":         p.get("stress",         0),
			"mood":           p.get("mood",           70),
			"preferred_regions": (p.get("preferred_regions", []) as Array).duplicate(),
			"favorite_facilities": (p.get("favorite_facilities", []) as Array).duplicate(),
			"personality":    p.get("personality",    ""),
			"exp":            p.get("exp",            0),
			"is_custom":      p.get("is_custom",      false),
		})
	return out

func _serialize_slots() -> Array:
	var out: Array = []
	for raw in GameState.auto_slots:
		var s: DispatchManager.AutoSlot = raw as DispatchManager.AutoSlot
		out.append({
			"state":             s.state,
				"custom_name":       s.custom_name,
			"unlock_cost":       s.unlock_cost,
			"hangar_group_id":   s.hangar_group_id,
			"machine":           s.machine.duplicate(),
			"pilot_id":          s.pilot_id,
			"assigned_pilot_id": s.assigned_pilot_id,
			"planet":            s.planet,
			"mission_start_time":  s.mission_start_time,
			"mission_end_time":    _enc(s.mission_end_time),
			"return_start_time":   s.return_start_time,
			"return_end_time":     _enc(s.return_end_time),
			"credits_earned":    s.credits_earned,
			"rewards":           s.rewards.duplicate(),
			"reward_breakdown":  s.reward_breakdown.duplicate(),
			"auto_redispatch":   s.auto_redispatch,
			"auto_pilot_id":     s.auto_pilot_id,
			"auto_planet":       s.auto_planet,
			"pending_machine":   s.pending_machine.duplicate(),
			"pending_pilot_id":  s.pending_pilot_id,
		})
	return out


func _serialize_hangar_groups() -> Array:
	var out: Array = []
	for raw in GameState.hangar_groups:
		var hg: DispatchManager.HangarGroup = raw as DispatchManager.HangarGroup
		out.append({"id": hg.id, "locked": hg.locked, "unlock_cost": hg.unlock_cost})
	return out

func _serialize_quarters() -> Array:
	var out: Array = []
	for bed in GameState.quarters_beds:
		out.append({
			"locked":      bed.get("locked", true),
			"unlock_cost": bed.get("unlock_cost", 0),
			"slots":       (bed.get("slots", ["", "", ""]) as Array).duplicate(),
		})
	return out

func _enc(v: float) -> float:
	return _INF_SUB if not is_finite(v) else v
