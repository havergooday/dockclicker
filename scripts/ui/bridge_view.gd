extends Control

var _pilot_nodes: Dictionary = {}  # pilot_id -> Control

# ── Util side panel ───────────────────────────────────────────────
var _util_open: bool = false
var _util_panel: PanelContainer
var _side_content: VBoxContainer

func _ready() -> void:
	PanelManager.register_panel("bridge", self)
	GameState.pilot_hired.connect(func(id): _spawn_pilot(id))
	GameState.pilot_status_changed.connect(func(id): _update_pilot_status(id))
	_build_roaming_pilots()
	_build_util_panel()
	_build_grid_overlay()

func _build_grid_overlay() -> void:
	var overlay := Control.new()
	overlay.set_script(load("res://scripts/ui/grid_overlay.gd"))
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false
	add_child(overlay)
	GameState.ui_edit_mode_changed.connect(func(v: bool):
		overlay.visible = v
		overlay.queue_redraw()
	)

# ── Roaming pilots ────────────────────────────────────────────────

const _WANDER_X_MIN := 180.0
const _WANDER_X_MAX := 1720.0
const _WANDER_Y_MIN := 210.0
const _WANDER_Y_MAX := 265.0
const _WALK_SPEED   := 30.0   # px/sec

func _build_roaming_pilots() -> void:
	for pilot in GameState.hired_pilots:
		_spawn_pilot(pilot["id"])

func _spawn_pilot(pilot_id: String) -> void:
	var pilot := GameState.get_hired_pilot(pilot_id)
	if pilot.is_empty() or _pilot_nodes.has(pilot_id):
		return

	var col_str: String = pilot.get("portrait_color", "#4499DD")
	var col := Color(col_str) if col_str.begins_with("#") else Color.CORNFLOWER_BLUE
	var pname: String = pilot.get("name", "?")
	var status: String = pilot.get("status", "idle")

	# 루트 — 발 위치 기준으로 자유 배치
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = Vector2(
		randf_range(_WANDER_X_MIN, _WANDER_X_MAX),
		randf_range(_WANDER_Y_MIN, _WANDER_Y_MAX)
	)
	add_child(root)
	_apply_depth(root)

	# 몸통 (컬러 직사각형 플레이스홀더, 56×96)
	var body := Panel.new()
	body.custom_minimum_size = Vector2(56, 96)
	body.size = Vector2(56, 96)
	body.position = Vector2(-28, -96)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bstyle := StyleBoxFlat.new()
	bstyle.bg_color = col.darkened(0.20)
	bstyle.border_color = col.lightened(0.15)
	bstyle.set_border_width_all(1)
	bstyle.set_corner_radius_all(4)
	body.add_theme_stylebox_override("panel", bstyle)
	root.add_child(body)

	var init_lbl := Label.new()
	init_lbl.text = pname.substr(0, 1)
	init_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	init_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	init_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	init_lbl.add_theme_font_size_override("font_size", 20)
	init_lbl.modulate = col.lightened(0.5)
	init_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(init_lbl)

	# 이름 라벨 (발 아래)
	var name_lbl := Label.new()
	name_lbl.text = pname
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.custom_minimum_size = Vector2(80, 0)
	name_lbl.position = Vector2(-40, 1)
	name_lbl.modulate = Color(1, 1, 1, 0.55)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(name_lbl)

	# 말풍선 (클릭 시 표시)
	var bubble := _make_bubble(pname, status)
	bubble.visible = false
	bubble.position = Vector2(-28, -118)
	root.add_child(bubble)

	# 클릭 버튼 (투명, 몸통 영역)
	var btn := Button.new()
	btn.flat = true
	btn.size = Vector2(56, 96)
	btn.position = Vector2(-28, -96)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for sname in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(sname, StyleBoxEmpty.new())
	btn.pressed.connect(func():
		var cur_status: String = GameState.get_hired_pilot(pilot_id).get("status", "idle")
		_show_bubble(bubble, pname, cur_status)
	)
	root.add_child(btn)

	_pilot_nodes[pilot_id] = root

	if status != "dispatched":
		_start_wander(root)
	else:
		root.modulate.a = 0.35

func _start_wander(root: Control) -> void:
	if not is_instance_valid(root) or root.get_meta("paused", false):
		return
	var tx := randf_range(_WANDER_X_MIN, _WANDER_X_MAX)
	var ty := randf_range(_WANDER_Y_MIN, _WANDER_Y_MAX)
	var dist := root.position.distance_to(Vector2(tx, ty))
	var dur  := maxf(dist / _WALK_SPEED, 0.1)

	var tw := root.create_tween()
	tw.tween_property(root, "position", Vector2(tx, ty), dur) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): _apply_depth(root))
	tw.tween_interval(randf_range(1.5, 4.0))
	tw.tween_callback(func(): _start_wander(root))
	root.set_meta("wander_tween", tw)

func _apply_depth(root: Control) -> void:
	var t := clampf((root.position.y - _WANDER_Y_MIN) / (_WANDER_Y_MAX - _WANDER_Y_MIN), 0.0, 1.0)
	root.scale   = Vector2.ONE * lerpf(0.75, 1.0, t)
	root.z_index = int(root.position.y)

func _update_pilot_status(pilot_id: String) -> void:
	if not _pilot_nodes.has(pilot_id):
		return
	var root: Control = _pilot_nodes[pilot_id]
	var status: String = GameState.get_hired_pilot(pilot_id).get("status", "idle")
	if status == "dispatched":
		root.set_meta("paused", true)
		if root.has_meta("wander_tween"):
			var old: Tween = root.get_meta("wander_tween")
			if is_instance_valid(old):
				old.kill()
		root.create_tween().tween_property(root, "modulate:a", 0.35, 0.4)
	else:
		root.set_meta("paused", false)
		var tw := root.create_tween()
		tw.tween_property(root, "modulate:a", 1.0, 0.4)
		tw.tween_callback(func(): _start_wander(root))

func _make_bubble(pname: String, status: String) -> PanelContainer:
	var bubble := PanelContainer.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bstyle := StyleBoxFlat.new()
	bstyle.bg_color = Color(0.05, 0.08, 0.16, 0.93)
	bstyle.border_color = Color(0.35, 0.55, 0.85, 0.65)
	bstyle.set_border_width_all(1)
	bstyle.set_corner_radius_all(4)
	bstyle.content_margin_left   = 6
	bstyle.content_margin_right  = 6
	bstyle.content_margin_top    = 4
	bstyle.content_margin_bottom = 4
	bubble.add_theme_stylebox_override("panel", bstyle)

	var lbl := Label.new()
	lbl.text = _bubble_text(pname, status)
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(lbl)
	bubble.set_meta("lbl", lbl)
	return bubble

func _bubble_text(pname: String, status: String) -> String:
	match status:
		"dispatched": return "%s\n▶ 임무 중..." % pname
		_:            return "%s\n● 대기 중" % pname

func _show_bubble(bubble: PanelContainer, pname: String, status: String) -> void:
	var lbl: Label = bubble.get_meta("lbl")
	lbl.text = _bubble_text(pname, status)
	bubble.visible = true
	if bubble.has_meta("tw"):
		var old: Tween = bubble.get_meta("tw")
		if is_instance_valid(old):
			old.kill()
	var tw := bubble.create_tween()
	tw.tween_interval(3.5)
	tw.tween_callback(func(): bubble.visible = false)
	bubble.set_meta("tw", tw)

# ── Util panel ────────────────────────────────────────────────────

func _build_util_panel() -> void:
	# ── 설정 패널 (⚙ 버튼 클릭 시 표시) ─────────────────────
	_util_panel = PanelContainer.new()
	_util_panel.anchor_left   = 1.0
	_util_panel.anchor_top    = 0.0
	_util_panel.anchor_right  = 1.0
	_util_panel.anchor_bottom = 1.0
	_util_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_util_panel.offset_left   = -210.0
	_util_panel.offset_right  = 0.0
	_util_panel.offset_top    = 0.0
	_util_panel.offset_bottom = 0.0
	_util_panel.visible = false
	_util_panel.modulate.a = 0.0
	_util_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.04, 0.07, 0.13, 0.96)
	ps.border_color = Color(0.22, 0.34, 0.56)
	ps.set_border_width_all(1)
	ps.set_corner_radius_all(5)
	ps.content_margin_left   = 10
	ps.content_margin_right  = 10
	ps.content_margin_top    = 8
	ps.content_margin_bottom = 8
	_util_panel.add_theme_stylebox_override("panel", ps)
	add_child(_util_panel)

	_side_content = VBoxContainer.new()
	_side_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side_content.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_side_content.add_theme_constant_override("separation", 7)
	_util_panel.add_child(_side_content)

	_build_settings_tab()
	_util_separator()
	_build_sound_tab()
	_util_separator()

	var min_btn := Button.new()
	min_btn.text = "─  최소화"
	min_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	min_btn.pressed.connect(func(): get_window().mode = Window.MODE_MINIMIZED)
	_side_content.add_child(min_btn)

	# ── ⚙ 버튼 (우측 상단, 작은 정사각형) ────────────────────
	var gear := Button.new()
	gear.anchor_left   = 1.0
	gear.anchor_top    = 0.0
	gear.anchor_right  = 1.0
	gear.anchor_bottom = 0.0
	gear.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	gear.offset_left   = -34.0   # 28px 너비
	gear.offset_right  = -6.0    # 우측 6px 틈
	gear.offset_top    =  6.0    # 상단 6px 틈
	gear.offset_bottom =  34.0   # 28px 높이
	gear.text = "⚙"
	gear.tooltip_text = "설정"
	gear.mouse_filter = Control.MOUSE_FILTER_STOP

	var g_norm := StyleBoxFlat.new()
	g_norm.bg_color = Color(0.12, 0.18, 0.30, 0.72)
	g_norm.border_color = Color(0.28, 0.42, 0.68, 0.55)
	g_norm.set_border_width_all(1)
	g_norm.set_corner_radius_all(5)
	gear.add_theme_stylebox_override("normal", g_norm)

	var g_hov := StyleBoxFlat.new()
	g_hov.bg_color = Color(0.22, 0.36, 0.58, 0.90)
	g_hov.border_color = Color(0.50, 0.72, 1.00, 0.88)
	g_hov.set_border_width_all(1)
	g_hov.set_corner_radius_all(5)
	gear.add_theme_stylebox_override("hover", g_hov)

	var g_prs := StyleBoxFlat.new()
	g_prs.bg_color = Color(0.18, 0.30, 0.50, 0.95)
	g_prs.border_color = Color(0.55, 0.80, 1.00)
	g_prs.set_border_width_all(1)
	g_prs.set_corner_radius_all(5)
	gear.add_theme_stylebox_override("pressed", g_prs)

	gear.add_theme_font_size_override("font_size", 14)
	gear.pressed.connect(_toggle_util_open)
	add_child(gear)

func _toggle_util_open() -> void:
	_util_open = not _util_open
	var tw := create_tween()
	if _util_open:
		_util_panel.visible = true
		tw.tween_property(_util_panel, "modulate:a", 1.0, 0.15)
	else:
		tw.tween_property(_util_panel, "modulate:a", 0.0, 0.12)
		tw.tween_callback(func(): _util_panel.visible = false)

# ── Settings tab ──────────────────────────────────────────────────

func _build_settings_tab() -> void:
	_util_header("⚙  설정")

	_util_toggle(
		"UI 위치 변형",
		false,
		func(v: bool):
			GameState.ui_edit_mode = v
			GameState.ui_edit_mode_changed.emit(v)
	)

	var reset_btn := Button.new()
	reset_btn.text = "↺  UI 위치 초기화"
	reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_btn.pressed.connect(func():
		GameState.ui_positions.clear()
		SaveManager.save()
		GameState.ui_positions_reset.emit()
	)
	_side_content.add_child(reset_btn)

	_util_separator()

	_util_toggle(
		"항상 위에",
		DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP),
		func(v: bool): DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, v)
	)

	_util_toggle(
		"드래그 이동",
		true,
		func(v: bool):
			var root: Control = get_parent() as Control
			if root:
				root.mouse_filter = Control.MOUSE_FILTER_IGNORE if v else Control.MOUSE_FILTER_STOP
	)

	_util_separator()
	_util_label("창 불투명도", Color(0.55, 0.65, 0.85))

	var parent_control := get_parent() as CanvasItem
	var init_opacity: float = parent_control.modulate.a * 100.0 if parent_control else 100.0

	var op_row := HBoxContainer.new()
	op_row.add_theme_constant_override("separation", 6)
	_side_content.add_child(op_row)

	var op_slider := HSlider.new()
	op_slider.min_value = 20.0
	op_slider.max_value = 100.0
	op_slider.step = 1.0
	op_slider.value = init_opacity
	op_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	op_row.add_child(op_slider)

	var op_val := Label.new()
	op_val.text = "%d%%" % int(init_opacity)
	op_val.custom_minimum_size = Vector2(34, 0)
	op_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	op_val.add_theme_font_size_override("font_size", 11)
	op_row.add_child(op_val)

	op_slider.value_changed.connect(func(v: float) -> void:
		op_val.text = "%d%%" % int(v)
		if parent_control:
			parent_control.modulate.a = v / 100.0
	)

# ── Sound tab ─────────────────────────────────────────────────────

func _build_sound_tab() -> void:
	_util_header("♪  사운드")

	_util_toggle(
		"전체 음소거",
		AudioServer.is_bus_mute(0),
		func(v: bool): AudioServer.set_bus_mute(0, v)
	)

	_util_separator()
	_util_label("마스터 볼륨", Color(0.55, 0.65, 0.85))
	_util_volume_slider(0)

	var bgm_idx := AudioServer.get_bus_index("BGM")
	if bgm_idx >= 0:
		_util_label("BGM", Color(0.55, 0.65, 0.85))
		_util_volume_slider(bgm_idx)

	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		_util_label("SFX", Color(0.55, 0.65, 0.85))
		_util_volume_slider(sfx_idx)

# ── Util helpers ──────────────────────────────────────────────────

func _util_header(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.modulate = Color(0.72, 0.88, 1.0)
	_side_content.add_child(lbl)
	_util_separator()

func _util_separator() -> void:
	_side_content.add_child(HSeparator.new())

func _util_label(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.modulate = color
	_side_content.add_child(lbl)

func _util_toggle(label_text: String, initial: bool, callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_side_content.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(lbl)

	var btn := Button.new()
	btn.toggle_mode = true
	btn.button_pressed = initial
	btn.text = "ON" if initial else "OFF"
	btn.custom_minimum_size = Vector2(44, 24)
	btn.modulate = Color(0.5, 1.0, 0.6) if initial else Color(1.0, 0.5, 0.5)
	btn.toggled.connect(func(v: bool) -> void:
		btn.text = "ON" if v else "OFF"
		btn.modulate = Color(0.5, 1.0, 0.6) if v else Color(1.0, 0.5, 0.5)
		callback.call(v)
	)
	row.add_child(btn)

func _util_volume_slider(bus_idx: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_side_content.add_child(row)

	var cur_vol: float = db_to_linear(AudioServer.get_bus_volume_db(bus_idx))

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = cur_vol
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%d%%" % int(cur_vol * 100.0)
	val_lbl.custom_minimum_size = Vector2(34, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(val_lbl)

	slider.value_changed.connect(func(v: float) -> void:
		val_lbl.text = "%d%%" % int(v * 100.0)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(maxf(v, 0.001)))
	)
