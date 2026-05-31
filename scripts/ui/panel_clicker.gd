extends Control

const CreatureVisualData = preload("res://data/creature_visual_data.gd")

# ── 생물 정의 ──────────────────────────────────────────────────
# 난이도 티어 0(쉬움) ~ 5(어려움)
# wave/circle/figure8 → speed = rad/s,  amp 사용
# bounce/erratic      → speed = px/s,   amp 미사용
const CREATURE_DEFS: Array = [
	# 0: 슬라임 — 좌우 파동, 느리고 큼
	{"glyph": "●",  "color": Color(0.40, 0.82, 0.36),
	 "size": Vector2(72, 58), "pattern": "h_wave",  "speed": 1.6,  "amp": Vector2(68, 0)},
	# 1: 날벌레 — 상하 파동
	{"glyph": "▸",  "color": Color(0.46, 0.66, 1.00),
	 "size": Vector2(64, 52), "pattern": "v_wave",  "speed": 2.0,  "amp": Vector2(0, 40)},
	# 2: 유영체 — 원운동
	{"glyph": "◎",  "color": Color(0.92, 0.58, 0.26),
	 "size": Vector2(60, 50), "pattern": "circle",  "speed": 2.4,  "amp": Vector2(56, 36)},
	# 3: 거미 — 직선 반사
	{"glyph": "✕",  "color": Color(0.88, 0.28, 0.38),
	 "size": Vector2(54, 46), "pattern": "bounce",  "speed": 130.0, "amp": Vector2.ZERO},
	# 4: 환영체 — 8자 궤적
	{"glyph": "◇",  "color": Color(0.70, 0.34, 1.00),
	 "size": Vector2(50, 42), "pattern": "figure8", "speed": 2.8,  "amp": Vector2(80, 32)},
	# 5: 변이체 — 무작위 방향 전환, 작고 빠름
	{"glyph": "⟡",  "color": Color(1.00, 0.82, 0.14),
	 "size": Vector2(46, 38), "pattern": "erratic", "speed": 175.0, "amp": Vector2.ZERO},
]

var _enemies: Dictionary = {}
var _wave_kills: int = 0
var _planet_data: Dictionary = {}
var _planet_tier: int = 0
var _auto_attack_timer: float = 0.0
var _returning := false
var _float_label: Label
var _combo_count: int = 0
var _last_click_time: float = 0.0
var _combo_label: Label = null
var _drop_label: Label = null

const AUTO_ATTACK_INTERVAL := 1.5
const DROP_RATE := 0.40

@onready var battle_area: Control = $BattleArea
@onready var session_label: Label = $Header/SessionLabel
@onready var return_button: Button = $Header/ReturnButton


func _ready() -> void:
	PanelManager.register_panel("clicker", self)
	return_button.pressed.connect(_on_return_pressed)
	PanelManager.panel_changed.connect(_on_panel_changed)
	_build_float_label()
	_build_combo_label()
	_build_drop_label()


func _build_float_label() -> void:
	_float_label = Label.new()
	_float_label.anchor_left   = 0.5
	_float_label.anchor_right  = 0.5
	_float_label.anchor_top    = 0.5
	_float_label.anchor_bottom = 0.5
	_float_label.offset_left   = -200.0
	_float_label.offset_right  =  200.0
	_float_label.offset_top    =  -50.0
	_float_label.offset_bottom =   50.0
	_float_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_float_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_float_label.add_theme_font_size_override("font_size", 42)
	_float_label.add_theme_color_override("font_color", Color(0.88, 0.96, 1.0))
	_float_label.modulate.a = 0.0
	_float_label.z_index = 20
	_float_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_float_label)


func _build_combo_label() -> void:
	_combo_label = Label.new()
	_combo_label.anchor_right  = 1.0
	_combo_label.offset_top    = 4.0
	_combo_label.offset_bottom = 24.0
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo_label.add_theme_font_size_override("font_size", 12)
	_combo_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.30))
	_combo_label.modulate.a = 0.0
	_combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_combo_label)


func _build_drop_label() -> void:
	_drop_label = Label.new()
	_drop_label.anchor_left   = 0.0
	_drop_label.anchor_right  = 1.0
	_drop_label.anchor_top    = 1.0
	_drop_label.anchor_bottom = 1.0
	_drop_label.offset_top    = -22.0
	_drop_label.offset_bottom =  -2.0
	_drop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_drop_label.add_theme_font_size_override("font_size", 11)
	_drop_label.add_theme_color_override("font_color", Color(0.55, 1.00, 0.72))
	_drop_label.modulate.a = 0.0
	_drop_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drop_label)


# ── 메인 루프 ─────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not visible:
		return
	_update_enemy_positions(delta)
	if GameState.auto_attack_unlocked and not _enemies.is_empty():
		_auto_attack_timer -= delta
		if _auto_attack_timer <= 0.0:
			_auto_attack_timer = AUTO_ATTACK_INTERVAL
			_do_auto_attack()


# ── 생물 이동 ─────────────────────────────────────────────────

func _update_enemy_positions(delta: float) -> void:
	if _enemies.is_empty():
		return
	var area := battle_area.size
	for enemy in _enemies.keys():
		if is_instance_valid(enemy):
			_move_enemy(enemy as Button, delta, area)


func _move_enemy(enemy: Button, delta: float, area: Vector2) -> void:
	var d: Dictionary = _enemies[enemy]
	var sz: Vector2 = enemy.custom_minimum_size
	var max_x := area.x - sz.x
	var max_y := area.y - sz.y

	match d["pattern"]:
		"h_wave":
			d["phase"] += delta * d["speed"]
			enemy.position.x = clampf(d["ax"] + sin(d["phase"]) * d["amp"].x, 0.0, max_x)
			enemy.position.y = d["ay"]
		"v_wave":
			d["phase"] += delta * d["speed"]
			enemy.position.x = d["ax"]
			enemy.position.y = clampf(d["ay"] + sin(d["phase"]) * d["amp"].y, 0.0, max_y)
		"circle":
			d["phase"] += delta * d["speed"]
			enemy.position.x = clampf(d["ax"] + cos(d["phase"]) * d["amp"].x, 0.0, max_x)
			enemy.position.y = clampf(d["ay"] + sin(d["phase"]) * d["amp"].y, 0.0, max_y)
		"bounce":
			var vx: float = d["vx"]
			var vy: float = d["vy"]
			var nx: float = enemy.position.x + vx * delta
			var ny: float = enemy.position.y + vy * delta
			if nx < 0.0 or nx > max_x:
				d["vx"] = -vx
				nx = clampf(nx, 0.0, max_x)
			if ny < 0.0 or ny > max_y:
				d["vy"] = -vy
				ny = clampf(ny, 0.0, max_y)
			enemy.position = Vector2(nx, ny)
		"figure8":
			d["phase"] += delta * d["speed"]
			enemy.position.x = clampf(d["ax"] + sin(d["phase"] * 2.0) * d["amp"].x, 0.0, max_x)
			enemy.position.y = clampf(d["ay"] + sin(d["phase"]) * d["amp"].y, 0.0, max_y)
		"erratic":
			d["timer"] -= delta
			if d["timer"] <= 0.0:
				d["timer"] = randf_range(0.25, 0.65)
				var angle := randf() * TAU
				d["vx"] = cos(angle) * d["speed"]
				d["vy"] = sin(angle) * d["speed"]
			var evx: float = d["vx"]
			var evy: float = d["vy"]
			var nx: float = enemy.position.x + evx * delta
			var ny: float = enemy.position.y + evy * delta
			if nx < 0.0 or nx > max_x:
				d["vx"] = -evx
				nx = clampf(nx, 0.0, max_x)
			if ny < 0.0 or ny > max_y:
				d["vy"] = -evy
				ny = clampf(ny, 0.0, max_y)
			enemy.position = Vector2(nx, ny)


# ── 자동 공격 ─────────────────────────────────────────────────

func _do_auto_attack() -> void:
	var keys := _enemies.keys()
	if keys.is_empty():
		return
	var enemy: Button = keys[randi() % keys.size()]
	if not is_instance_valid(enemy) or not _enemies.has(enemy):
		return
	var dmg := maxi(1, GameState.click_damage / 2)
	_enemies[enemy]["hp"] -= dmg
	if _enemies[enemy]["hp"] <= 0:
		_kill_enemy(enemy)
	else:
		_update_enemy_display(enemy)
		var tw := enemy.create_tween()
		tw.tween_property(enemy, "modulate", Color(0.45, 0.85, 1.0), 0.05)
		tw.tween_property(enemy, "modulate", Color.WHITE, 0.12)


# ── 입력 ──────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_return_pressed()
		get_viewport().set_input_as_handled()


# ── 세션 관리 ─────────────────────────────────────────────────

func _on_panel_changed(panel_id: String) -> void:
	if panel_id == "clicker":
		_start_session()


func _start_session() -> void:
	_planet_data = GameState.get_selected_planet_data()
	_planet_tier = _get_planet_tier()
	_wave_kills = 0
	_auto_attack_timer = AUTO_ATTACK_INTERVAL
	_combo_count = 0
	_last_click_time = 0.0
	_returning = false
	return_button.disabled = false
	if is_instance_valid(_float_label):
		_float_label.modulate.a = 0.0
	_clear_enemies()
	_refresh_session_label()
	_fill_to_max.call_deferred()


func _clear_enemies() -> void:
	for enemy in _enemies.keys():
		if is_instance_valid(enemy):
			enemy.queue_free()
	_enemies.clear()


func _fill_to_max() -> void:
	if _planet_data.is_empty():
		return
	var max_on_screen: int = _planet_data.get("max_on_screen", 2)
	var wave_size: int = _planet_data.get("wave_size", 5)
	var total := _wave_kills + _enemies.size()
	while _enemies.size() < max_on_screen and total < wave_size:
		_spawn_enemy()
		total += 1


# ── 생물 스폰 ─────────────────────────────────────────────────

func _get_planet_tier() -> int:
	var pid := str(_planet_data.get("id", ""))
	for i in GameState.PLANETS.size():
		if str(GameState.PLANETS[i].get("id", "")) == pid:
			return clampi(i * CREATURE_DEFS.size() / GameState.PLANETS.size(), 0, CREATURE_DEFS.size() - 1)
	return 0


func _pick_creature_def() -> Dictionary:
	var tier := _planet_tier
	# 고난이도 행성에서 이전 티어 혼합 스폰 (30%)
	if tier > 0 and randf() < 0.30:
		tier = randi_range(maxi(0, tier - 2), tier - 1)
	return CREATURE_DEFS[tier]


func _spawn_enemy() -> void:
	var hp: int = _planet_data.get("enemy_hp", 2)
	var def := _pick_creature_def()
	var region_type := str(_planet_data.get("region_type", "scrap"))
	var visual := CreatureVisualData.get_variant(region_type, _planet_tier)
	var sz: Vector2  = def["size"]
	var col: Color   = def["color"]
	var pattern: String = def["pattern"]
	var speed: float = def["speed"]
	var amp: Vector2 = def["amp"]
	var area := battle_area.size

	# 버튼 생성 + 스타일
	var btn := Button.new()
	btn.custom_minimum_size = sz
	var sty := _make_enemy_style(col, false)
	var hov := _make_enemy_style(col, true)
	btn.add_theme_stylebox_override("normal",   sty)
	btn.add_theme_stylebox_override("hover",    hov)
	btn.add_theme_stylebox_override("pressed",  sty)
	btn.add_theme_stylebox_override("focus",    sty)
	btn.add_theme_stylebox_override("disabled", sty)
	btn.add_theme_color_override("font_color",       col.lightened(0.45))
	btn.add_theme_color_override("font_hover_color", col.lightened(0.60))
	btn.add_theme_font_size_override("font_size", 13)
	battle_area.add_child(btn)

	# 앵커 위치 — 파동 패턴은 진폭 여백 확보
	var mx: float = amp.x if pattern in ["h_wave", "circle", "figure8"] else 0.0
	var my: float = amp.y if pattern in ["v_wave", "circle", "figure8"] else 0.0
	var ax := randf_range(
		maxf(mx, 4.0),
		maxf(mx + 1.0, area.x - sz.x - mx - 4.0)
	)
	var ay := randf_range(
		maxf(my, 4.0),
		maxf(my + 1.0, area.y - sz.y - my - 4.0)
	)
	btn.position = Vector2(ax, ay)

	# 이동 데이터
	var d: Dictionary = {
		"hp": hp, "max_hp": hp,
		"glyph": def["glyph"],
		"visual": visual,
		"pattern": pattern,
		"amp": amp,
		"ax": ax, "ay": ay,
		"phase": randf() * TAU,
		"speed": speed,
	}
	match pattern:
		"bounce":
			var angle := randf() * TAU
			d["vx"] = cos(angle) * speed
			d["vy"] = sin(angle) * speed
		"erratic":
			var angle := randf() * TAU
			d["vx"] = cos(angle) * speed
			d["vy"] = sin(angle) * speed
			d["timer"] = randf_range(0.1, 0.5)

	_enemies[btn] = d
	_update_enemy_display(btn)
	btn.pressed.connect(func(): _on_enemy_clicked(btn))


func _make_enemy_style(col: Color, hover: bool) -> StyleBoxFlat:
	var sty := StyleBoxFlat.new()
	sty.bg_color     = col.darkened(0.55) if not hover else col.darkened(0.36)
	sty.border_color = col if not hover else col.lightened(0.22)
	sty.set_border_width_all(2)
	sty.set_corner_radius_all(5)
	return sty


func _update_enemy_display(enemy: Button) -> void:
	var d: Dictionary = _enemies[enemy]
	_clear_enemy_visual(enemy)
	_build_enemy_visual(enemy, d["visual"], d["hp"], d["max_hp"])


func _clear_enemy_visual(enemy: Button) -> void:
	enemy.text = ""
	for child in enemy.get_children():
		child.queue_free()


func _build_enemy_visual(enemy: Button, visual: Dictionary, hp: int, max_hp: int) -> void:
	var body_col: Color = visual.get("body", Color(0.40, 0.82, 0.36))
	var core_col: Color = visual.get("core", body_col.lightened(0.35))
	var mark := str(visual.get("mark", "●"))

	var body := PanelContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 7.0
	body.offset_right = -7.0
	body.offset_top = 7.0
	body.offset_bottom = -18.0
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var body_style := StyleBoxFlat.new()
	body_style.bg_color = body_col.darkened(0.20)
	body_style.border_color = body_col.lightened(0.20)
	body_style.set_border_width_all(1)
	body_style.set_corner_radius_all(8)
	body.add_theme_stylebox_override("panel", body_style)
	enemy.add_child(body)

	var core := ColorRect.new()
	core.color = core_col
	core.anchor_left = 0.35
	core.anchor_right = 0.65
	core.anchor_top = 0.30
	core.anchor_bottom = 0.62
	core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(core)

	var mark_lbl := Label.new()
	mark_lbl.text = mark
	mark_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mark_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark_lbl.add_theme_font_size_override("font_size", 16)
	mark_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.90))
	mark_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(mark_lbl)

	var hp_lbl := Label.new()
	hp_lbl.text = "%d/%d" % [hp, max_hp]
	hp_lbl.anchor_left = 0.0
	hp_lbl.anchor_right = 1.0
	hp_lbl.anchor_top = 1.0
	hp_lbl.anchor_bottom = 1.0
	hp_lbl.offset_top = -17.0
	hp_lbl.offset_bottom = -1.0
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.add_theme_font_size_override("font_size", 10)
	hp_lbl.add_theme_color_override("font_color", Color(0.88, 0.96, 1.0))
	hp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy.add_child(hp_lbl)


# ── 전투 ──────────────────────────────────────────────────────

func _on_enemy_clicked(enemy: Button) -> void:
	if not _enemies.has(enemy):
		return
	var dmg := _calc_click_damage()
	var click_center := enemy.position + enemy.custom_minimum_size * 0.5

	var targets: Array = [enemy]
	var range_px := GameState.get_click_range_px()
	if range_px > 0.0:
		for other in _enemies.keys():
			if other == enemy:
				continue
			var oc := (other as Button).position + (other as Button).custom_minimum_size * 0.5
			if click_center.distance_to(oc) <= range_px:
				targets.append(other)

	for target in targets:
		if not _enemies.has(target):
			continue
		_enemies[target]["hp"] -= dmg
		if _enemies[target]["hp"] <= 0:
			_kill_enemy(target)
		else:
			_update_enemy_display(target)


func _calc_click_damage() -> int:
	var now := Time.get_unix_time_from_system()
	if GameState.combo_level > 0 and now - _last_click_time <= PartsData.COMBO_WINDOW_SEC:
		_combo_count += 1
	else:
		_combo_count = 1
	_last_click_time = now

	var base := GameState.click_damage
	var threshold := GameState.get_combo_threshold()
	if GameState.combo_level > 0 and _combo_count >= threshold:
		var mult := GameState.get_combo_multiplier()
		_show_combo_active(mult)
		return int(ceil(float(base) * mult))
	return base


func _kill_enemy(enemy: Button) -> void:
	var credit_per_kill: int = _planet_data.get("credit_per_kill", 10)
	GameState.add_pending_credit(credit_per_kill)
	_enemies.erase(enemy)
	enemy.queue_free()
	_wave_kills += 1
	_try_drop_part()
	_refresh_session_label()
	var wave_size: int = _planet_data.get("wave_size", 5)
	if _wave_kills >= wave_size:
		_on_wave_complete()
	else:
		_fill_to_max()


# ── 드랍 ──────────────────────────────────────────────────────

func _try_drop_part() -> void:
	if randf() > DROP_RATE:
		return
	var types := ["body", "weapon", "legs"]
	var ptype: String = types[randi() % types.size()]
	var options := _gen_drop_options()
	var tier := GameState.compute_part_tier(options)
	GameState.part_inventory.append({
		"iid":     "drop_%d" % Time.get_ticks_usec(),
		"type":    ptype,
		"tier":    tier,
		"options": options,
	})
	GameState.part_purchased.emit(ptype, tier)
	_show_drop_toast(ptype, tier, options)


func _gen_drop_options() -> Array:
	var planet_idx := 0
	for i in GameState.PLANETS.size():
		if str(GameState.PLANETS[i].get("id", "")) == str(_planet_data.get("id", "")):
			planet_idx = i
			break
	var max_opts: int
	if planet_idx < 6:
		max_opts = 1 if randf() > 0.5 else 0
	elif planet_idx < 12:
		max_opts = 1
	else:
		max_opts = 2 if randf() > 0.4 else 1
	var pool: Array = PartsData.OPTION_POOL.duplicate()
	var opts: Array = []
	for _i in max_opts:
		if pool.is_empty():
			break
		var idx := randi() % pool.size()
		var opt_def: Dictionary = pool[idx]
		pool.remove_at(idx)
		var vals: Array = opt_def["values"] as Array
		opts.append({"type": opt_def["type"], "value": vals[randi() % vals.size()]})
	return opts


# ── 연출 ──────────────────────────────────────────────────────

func _show_combo_active(mult: float) -> void:
	if _combo_label == null:
		return
	_combo_label.text = "COMBO ×%.1f" % mult
	_combo_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(_combo_label, "modulate:a", 0.0, 0.3)


func _show_drop_toast(ptype: String, tier: int, options: Array) -> void:
	if _drop_label == null:
		return
	var type_names := {"body": "몸체", "weapon": "무기", "legs": "다리"}
	var tier_str: String = ["T1", "T2", "T3"][clampi(tier - 1, 0, 2)]
	var opt_parts  := []
	for opt in options:
		match opt.get("type", ""):
			"credits_pct":       opt_parts.append("수익+%d%%" % opt["value"])
			"dispatch_time_pct": opt_parts.append("파견-%d%%" % opt["value"])
			"return_time_pct":   opt_parts.append("복귀-%d%%" % opt["value"])
	_drop_label.text = "▼ DROP  %s %s  [%s]" % [tier_str, type_names.get(ptype, "?"), "  ".join(opt_parts)]
	_drop_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(_drop_label, "modulate:a", 0.0, 0.5)


func _on_wave_complete() -> void:
	if _returning:
		return
	_returning = true
	return_button.disabled = true
	_show_float_then("미션완료", 0.8, _do_return)


func _on_return_pressed() -> void:
	if _returning:
		return
	_returning = true
	return_button.disabled = true
	_show_float_then("함선복귀", 0.5, _do_return)


func _show_float_then(text: String, hold: float, callback: Callable) -> void:
	_float_label.text = text
	_float_label.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_float_label, "modulate:a", 1.0, 0.18)
	tween.tween_interval(hold)
	tween.tween_callback(callback)


func _do_return() -> void:
	_clear_enemies()
	GameState.return_from_dispatch()
	GameState.collect_player_credits(return_button.global_position)
	PanelManager.go_back()


func _refresh_session_label() -> void:
	var wave_size: int = _planet_data.get("wave_size", 5)
	session_label.text = "%s  처치: %d/%d  보류: %d CR" % [
		_planet_data.get("name", ""),
		_wave_kills, wave_size,
		GameState.pending_credits,
	]
