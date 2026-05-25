extends Node

const SAVE_PATH    := "user://save.json"
const SAVE_VERSION := 1
const _INF_SUB     := 1e30  # INF를 JSON에 저장할 때 대체값

func _ready() -> void:
	load_save()
	GameState.credits_changed.connect(func(_v): save())
	GameState.auto_slot_changed.connect(func(_i): save())

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
		"selected_planet":      GameState.selected_planet,
		"unlocked_planets":     GameState.unlocked_planets.duplicate(),
		"owned_parts": {
			"pilot":  GameState.owned_parts["pilot"].duplicate(),
			"body":   GameState.owned_parts["body"].duplicate(),
			"weapon": GameState.owned_parts["weapon"].duplicate(),
			"legs":   GameState.owned_parts["legs"].duplicate(),
		},
		"auto_slots": _serialize_slots(),
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

	var parsed := JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("SaveManager: corrupt save file — ignored")
		return false
	var d: Dictionary = parsed

	GameState.total_credits        = int(d.get("total_credits",        0))
	GameState.pending_credits      = int(d.get("pending_credits",      0))
	GameState.player_status        = str(d.get("player_status",        "idle"))
	GameState.click_damage         = int(d.get("click_damage",         1))
	GameState.damage_upgrade_level = int(d.get("damage_upgrade_level", 0))
	GameState.selected_planet      = str(d.get("selected_planet",      "sector_a"))
	GameState.unlocked_planets     = (d.get("unlocked_planets", ["sector_a"]) as Array).duplicate()

	var parts: Dictionary = d.get("owned_parts", {})
	for pt: String in ["pilot", "body", "weapon", "legs"]:
		if parts.has(pt):
			GameState.owned_parts[pt] = (parts[pt] as Array).duplicate()

	var slots_raw: Array = d.get("auto_slots", [])
	var save_time: float  = float(d.get("save_time", Time.get_unix_time_from_system()))
	GameState.apply_dispatch_save(slots_raw, save_time)
	return true

# ── 직렬화 헬퍼 ───────────────────────────────────────────────────

func _serialize_slots() -> Array:
	var out: Array = []
	for raw in GameState.auto_slots:
		var s: DispatchManager.AutoSlot = raw as DispatchManager.AutoSlot
		out.append({
			"state":            s.state,
			"unlock_cost":      s.unlock_cost,
			"machine":          s.machine.duplicate(),
			"pilot_tier":       s.pilot_tier,
			"planet":           s.planet,
			"mission_end_time": _enc(s.mission_end_time),
			"return_end_time":  _enc(s.return_end_time),
			"credits_earned":   s.credits_earned,
			"auto_redispatch":  s.auto_redispatch,
			"auto_pilot_tier":  s.auto_pilot_tier,
			"auto_planet":      s.auto_planet,
		})
	return out

func _enc(v: float) -> float:
	return _INF_SUB if not is_finite(v) else v
