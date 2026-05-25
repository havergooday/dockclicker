extends Control

var _missions_vbox: VBoxContainer
var _countdown_data: Array = []
var _pilot_strip: HBoxContainer

# ── Util side panel ───────────────────────────────────────────────
var _active_tab: String = ""
var _side_panel: PanelContainer
var _side_content: VBoxContainer
var _tab_btns: Dictionary = {}

func _ready() -> void:
	PanelManager.register_panel("bridge", self)
	GameState.auto_slot_changed.connect(func(_i): _refresh_missions())
	GameState.auto_dispatch_returned.connect(func(_i): _refresh_missions())
	GameState.pilot_hired.connect(func(_id): _refresh_pilots())
	GameState.pilot_status_changed.connect(func(_id): _refresh_pilots())
	_build_pilot_strip()
	_build_mission_panel()
	_refresh_missions()
	_refresh_pilots()
	_build_util_panel()

func _process(_delta: float) -> void:
	if not visible:
		return
	var now := Time.get_unix_time_from_system()
	for entry in _countdown_data:
		var lbl: Label = entry["label"]
		if not is_instance_valid(lbl):
			continue
		var remaining: float = maxf(0.0, float(entry["end_time"]) - now)
		lbl.text = "%02d:%02d" % [int(remaining) / 60, int(remaining) % 60]

# ── Pilot roster strip (top-left) ────────────────────────────────

func _build_pilot_strip() -> void:
	var container := PanelContainer.new()
	container.anchor_left   = 0.0
	container.anchor_top    = 0.0
	container.anchor_right  = 0.0
	container.anchor_bottom = 0.0
	container.offset_left   = 4.0
	container.offset_top    = 4.0
	container.offset_right  = 380.0
	container.offset_bottom = 58.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.07, 0.13, 0.82)
	style.border_color = Color(0.18, 0.28, 0.44)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left   = 10
	style.content_margin_right  = 10
	style.content_margin_top    = 5
	style.content_margin_bottom = 5
	container.add_theme_stylebox_override("panel", style)
	add_child(container)

	_pilot_strip = HBoxContainer.new()
	_pilot_strip.add_theme_constant_override("separation", 10)
	_pilot_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pilot_strip.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	container.add_child(_pilot_strip)

func _refresh_pilots() -> void:
	if _pilot_strip == null:
		return
	for c in _pilot_strip.get_children():
		c.queue_free()

	if GameState.hired_pilots.is_empty():
		var lbl := Label.new()
		lbl.text = "파일럿 없음  —  PC 터미널에서 고용"
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.modulate = Color(1, 1, 1, 0.30)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_pilot_strip.add_child(lbl)
		return

	for pilot in GameState.hired_pilots:
		var col_str: String = pilot.get("portrait_color", "#4499DD")
		var col := Color(col_str) if col_str.begins_with("#") else Color.CORNFLOWER_BLUE
		var status: String = pilot.get("status", "idle")

		var card := HBoxContainer.new()
		card.add_theme_constant_override("separation", 5)
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_pilot_strip.add_child(card)

		# Portrait dot
		var dot_panel := PanelContainer.new()
		dot_panel.custom_minimum_size = Vector2(28, 28)
		dot_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var dot_style := StyleBoxFlat.new()
		dot_style.bg_color = col.darkened(0.35)
		dot_style.border_color = col if status == "idle" else col.darkened(0.4)
		dot_style.set_border_width_all(2)
		dot_style.set_corner_radius_all(14)
		dot_panel.add_theme_stylebox_override("panel", dot_style)
		var init_lbl := Label.new()
		var pname: String = pilot.get("name", "?")
		init_lbl.text = pname.substr(0, 1)
		init_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		init_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		init_lbl.add_theme_font_size_override("font_size", 11)
		init_lbl.modulate = col.lightened(0.3) if status == "idle" else col.darkened(0.2)
		dot_panel.add_child(init_lbl)
		card.add_child(dot_panel)

		# Name + status
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 0)
		info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		card.add_child(info)

		var name_lbl := Label.new()
		name_lbl.text = pname
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.modulate = Color(1, 1, 1, 0.9) if status == "idle" else Color(0.6, 0.6, 0.6, 0.8)
		info.add_child(name_lbl)

		var st_lbl := Label.new()
		st_lbl.text = "대기중" if status == "idle" else "파견중"
		st_lbl.add_theme_font_size_override("font_size", 10)
		st_lbl.modulate = Color(0.45, 0.90, 0.55) if status == "idle" else Color(0.95, 0.70, 0.25)
		info.add_child(st_lbl)

		# Separator between pilots (not after last)
		if pilot != GameState.hired_pilots.back():
			var sep := VSeparator.new()
			sep.modulate = Color(1, 1, 1, 0.15)
			_pilot_strip.add_child(sep)

# ── Mission status panel (bottom) ─────────────────────────────────

func _build_mission_panel() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -120
	add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "── 파견 현황 ──"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_missions_vbox = VBoxContainer.new()
	_missions_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(_missions_vbox)

func _refresh_missions() -> void:
	_countdown_data.clear()
	for child in _missions_vbox.get_children():
		child.queue_free()

	var has_active := false
	for i: int in GameState.auto_slots.size():
		var slot: DispatchManager.AutoSlot = GameState.auto_slots[i] as DispatchManager.AutoSlot
		if slot.state != "on_mission" and slot.state != "returning":
			continue
		has_active = true

		var row := HBoxContainer.new()
		_missions_vbox.add_child(row)

		var info_lbl := Label.new()
		info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var end_time: float = 0.0

		if slot.state == "on_mission":
			var planet_name: String = slot.planet
			if slot.planet != "":
				planet_name = str(GameState.get_planet(slot.planet).get("name", slot.planet))
			info_lbl.text = "슬롯 %d  →  %s" % [i + 1, planet_name]
			end_time = slot.mission_end_time
		else:
			info_lbl.text = "슬롯 %d  ←  귀환중" % (i + 1)
			info_lbl.modulate = Color(1.0, 0.8, 0.4, 1.0)
			end_time = slot.return_end_time

		row.add_child(info_lbl)

		var countdown_lbl := Label.new()
		countdown_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		countdown_lbl.custom_minimum_size = Vector2(52, 0)
		row.add_child(countdown_lbl)

		_countdown_data.append({"label": countdown_lbl, "end_time": end_time})

	if not has_active:
		var lbl := Label.new()
		lbl.text = "파견 중인 머신 없음"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.modulate = Color(1, 1, 1, 0.35)
		_missions_vbox.add_child(lbl)

# ── Util panel ────────────────────────────────────────────────────

func _build_util_panel() -> void:
	# Side content panel: anchored right, full height, hidden initially
	_side_panel = PanelContainer.new()
	_side_panel.anchor_left   = 1.0
	_side_panel.anchor_top    = 0.0
	_side_panel.anchor_right  = 1.0
	_side_panel.anchor_bottom = 1.0
	_side_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_side_panel.offset_left   = -244.0  # 200px content + 4px gap + 40px strip
	_side_panel.offset_top    = 4.0
	_side_panel.offset_right  = -44.0   # 4px gap + 40px strip
	_side_panel.offset_bottom = -4.0
	_side_panel.visible = false
	_side_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.04, 0.07, 0.13, 0.96)
	ps.border_color = Color(0.22, 0.34, 0.56)
	ps.set_border_width_all(1)
	ps.set_corner_radius_all(5)
	ps.content_margin_left   = 10
	ps.content_margin_right  = 10
	ps.content_margin_top    = 8
	ps.content_margin_bottom = 8
	_side_panel.add_theme_stylebox_override("panel", ps)
	add_child(_side_panel)

	_side_content = VBoxContainer.new()
	_side_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side_content.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_side_content.add_theme_constant_override("separation", 7)
	_side_panel.add_child(_side_content)

	# Button strip: right edge
	var strip := VBoxContainer.new()
	strip.anchor_left   = 1.0
	strip.anchor_top    = 0.0
	strip.anchor_right  = 1.0
	strip.anchor_bottom = 0.0
	strip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	strip.offset_left   = -40.0
	strip.offset_top    = 4.0
	strip.offset_right  = -4.0
	strip.offset_bottom = 120.0
	strip.add_theme_constant_override("separation", 2)
	add_child(strip)

	for pair: Array in [["⚙", "settings"], ["♪", "sound"]]:
		var btn := Button.new()
		btn.text = pair[0]
		btn.custom_minimum_size = Vector2(32, 32)
		btn.toggle_mode = true
		var cap: String = pair[1]
		_tab_btns[cap] = btn
		btn.pressed.connect(func(): _toggle_tab(cap))
		strip.add_child(btn)

	var min_btn := Button.new()
	min_btn.text = "─"
	min_btn.custom_minimum_size = Vector2(32, 32)
	min_btn.tooltip_text = "최소화"
	min_btn.pressed.connect(func(): get_window().mode = Window.MODE_MINIMIZED)
	strip.add_child(min_btn)

func _toggle_tab(tab_id: String) -> void:
	if _active_tab == tab_id:
		_active_tab = ""
		_side_panel.visible = false
		for id: String in _tab_btns:
			(_tab_btns[id] as Button).set_pressed_no_signal(false)
	else:
		_active_tab = tab_id
		_side_panel.visible = true
		for id: String in _tab_btns:
			(_tab_btns[id] as Button).set_pressed_no_signal(id == tab_id)
		_rebuild_tab_content()

func _rebuild_tab_content() -> void:
	for c in _side_content.get_children():
		c.queue_free()
	match _active_tab:
		"settings": _build_settings_tab()
		"sound":    _build_sound_tab()

# ── Settings tab ──────────────────────────────────────────────────

func _build_settings_tab() -> void:
	_util_header("⚙  설정")

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
