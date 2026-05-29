extends Node

const SAVE_PATH    := "user://save.json"
const SAVE_VERSION := 4
const _INF_SUB     := 1e30  # INF를 JSON에 저장할 때 대체값

func _ready() -> void:
	load_save()
	GameState.credits_changed.connect(func(_v): save())
	GameState.auto_slot_changed.connect(func(_i): save())
	GameState.pilot_hired.connect(func(_id): save())
	GameState.pilot_status_changed.connect(func(_id): save())
	GameState.board_refreshed.connect(func(): save())

# ── 저장 ─────────────────────────────────────────────────────────

func save() -> void:
	var data := {
		"version":              SAVE_VERSION,
		"save_time":            Time.get_unix_time_from_system(),
		"total_credits":        GameState.total_credits,
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
	GameState.pending_credits      = int(d.get("pending_credits",      0))
	GameState.player_status        = str(d.get("player_status",        "idle"))
	GameState.click_damage         = int(d.get("click_damage",         1))
	GameState.damage_upgrade_level = int(d.get("damage_upgrade_level", 0))
	GameState.auto_attack_unlocked = bool(d.get("auto_attack_unlocked", false))
	GameState.click_range_level    = int(d.get("click_range_level",    0))
	GameState.combo_level          = int(d.get("combo_level",          0))
	GameState.selected_planet      = str(d.get("selected_planet",      "sector_a"))
	GameState.unlocked_planets     = (d.get("unlocked_planets", ["sector_a"]) as Array).duplicate()

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
		GameState.hired_pilots.append({
			"id":             str(pd.get("id",             "")),
			"name":           str(pd.get("name",           "")),
			"tier":           int(pd.get("tier",           1)),
			"bonus_type":     str(pd.get("bonus_type",     "none")),
			"bonus_value":    int(pd.get("bonus_value",    0)),
			"portrait_color": str(pd.get("portrait_color", "#4499DD")),
			"status":         str(pd.get("status",         "idle")),
			"is_custom":      bool(pd.get("is_custom",     false)),
		})

	var slots_raw: Array  = d.get("auto_slots",    [])
	var groups_raw: Array = d.get("hangar_groups", [])
	var save_time: float  = float(d.get("save_time", Time.get_unix_time_from_system()))
	GameState.apply_dispatch_save(slots_raw, save_time, groups_raw)

	var ui_pos = d.get("ui_positions", {})
	if ui_pos is Dictionary:
		GameState.ui_positions = (ui_pos as Dictionary).duplicate()

	var board_ids = d.get("board_pilot_ids", [])
	if board_ids is Array:
		GameState.board_pilot_ids = (board_ids as Array).duplicate()
	GameState.board_last_day      = int(d.get("board_last_day",      -1))
	GameState.board_refresh_count = int(d.get("board_refresh_count",  0))

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
			"is_custom":      p.get("is_custom",      false),
		})
	return out

func _serialize_slots() -> Array:
	var out: Array = []
	for raw in GameState.auto_slots:
		var s: DispatchManager.AutoSlot = raw as DispatchManager.AutoSlot
		out.append({
			"state":             s.state,
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

func _enc(v: float) -> float:
	return _INF_SUB if not is_finite(v) else v
