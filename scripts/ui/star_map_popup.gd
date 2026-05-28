extends Control

const POPUP_HEIGHT := 264.0

# planet icon placeholder colors (index-based)
const PLANET_COLORS: Array = [
	Color(0.32, 0.56, 0.92), Color(0.82, 0.48, 0.28), Color(0.44, 0.76, 0.52),
	Color(0.72, 0.32, 0.72), Color(0.88, 0.82, 0.28), Color(0.32, 0.72, 0.88),
	Color(0.88, 0.32, 0.44), Color(0.56, 0.44, 0.88), Color(0.56, 0.88, 0.44),
	Color(0.88, 0.68, 0.32),
]

var _main_panel: PanelContainer
var _body_wrapper: Control
var _planet_area: Control
var _planet_scroll: ScrollContainer
var _planet_row: HBoxContainer
var _slide_panel: PanelContainer
var _detail_info_label: Label
var _slot_grid: GridContainer
var _toast_label: Label
var _selected_planet_id: String = ""
var _planet_detail_mode: bool = false
var _planet_buttons: Dictionary = {}
var _saved_planet_scroll_x: int = 0
var _planet_dragging: bool = false
var _planet_drag_anchor_x: float = 0.0
var _planet_drag_scroll_start: int = 0
var _detail_overlay: ColorRect
var _slot_scroll_container: ScrollContainer
var _slot_dragging: bool = false
var _slot_drag_anchor_x: float = 0.0
var _slot_drag_scroll_start: int = 0
var _bay_panel: PanelContainer
var _bay_grid: GridContainer
var _bay_scroll: ScrollContainer
var _bay_panel_dragging: bool = false
var _bay_drag_anchor_x: float = 0.0
var _bay_drag_scroll_start: int = 0
var _bay_select_mode: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	hide()
	GameState.planet_unlocked.connect(_on_state_changed)
	GameState.auto_slot_changed.connect(_on_auto_slot_changed)
	GameState.auto_dispatch_returned.connect(_on_auto_slot_changed)
	GameState.pilot_hired.connect(func(_pid: String): _on_auto_slot_changed(-1))
	GameState.pilot_status_changed.connect(func(_pid: String): _on_auto_slot_changed(-1))


func open_for_control_room() -> void:
	visible = true
	_planet_detail_mode = false
	_slide_panel.visible = false
	_slide_panel.offset_left = 2000.0
	_slide_panel.offset_right = 2000.0
	_detail_overlay.visible = false
	_select_default_planet()
	_rebuild_planets()
	call_deferred("_restore_saved_scroll")
	_main_panel.offset_top = -POPUP_HEIGHT
	var tween := create_tween()
	tween.tween_property(_main_panel, "offset_top", 0.0, 0.20).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


func _restore_saved_scroll() -> void:
	_planet_scroll.scroll_horizontal = _saved_planet_scroll_x


func close_popup() -> void:
	if not visible:
		return
	_saved_planet_scroll_x = _planet_scroll.scroll_horizontal
	var tween := create_tween()
	tween.tween_property(_main_panel, "offset_top", -POPUP_HEIGHT, 0.18).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func():
		hide()
		_hide_toast()
		if _bay_select_mode:
			_bay_select_mode = false
			_bay_panel_dragging = false
			_bay_panel.visible = false
		_slide_panel.visible = false
		_detail_overlay.visible = false
		_planet_dragging = false
		_planet_detail_mode = false
	)


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.46)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			close_popup()
	)
	add_child(overlay)

	_main_panel = PanelContainer.new()
	_main_panel.anchor_left = 0.0
	_main_panel.anchor_top = 0.0
	_main_panel.anchor_right = 1.0
	_main_panel.anchor_bottom = 0.0
	_main_panel.offset_left = 0.0
	_main_panel.offset_right = 0.0
	_main_panel.offset_bottom = POPUP_HEIGHT
	_main_panel.offset_top = -POPUP_HEIGHT
	var main_style := StyleBoxFlat.new()
	main_style.bg_color = Color(0.04, 0.06, 0.11, 0.98)
	main_style.border_color = Color(0.28, 0.40, 0.62, 0.96)
	main_style.set_border_width_all(1)
	main_style.set_corner_radius_all(0)
	main_style.content_margin_left = 12
	main_style.content_margin_right = 12
	main_style.content_margin_top = 8
	main_style.content_margin_bottom = 8
	_main_panel.add_theme_stylebox_override("panel", main_style)
	add_child(_main_panel)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	_main_panel.add_child(root)

	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(header)

	var close_btn := Button.new()
	close_btn.text = "× 닫기"
	close_btn.flat = true
	close_btn.add_theme_color_override("font_color", Color(0.70, 0.80, 1.0))
	close_btn.pressed.connect(close_popup)
	header.add_child(close_btn)

	# Body wrapper — planet area + slide panel as overlapping children
	_body_wrapper = Control.new()
	_body_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_wrapper.clip_contents = true
	root.add_child(_body_wrapper)

	_planet_area = Control.new()
	_planet_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body_wrapper.add_child(_planet_area)

	_build_planet_area()
	_build_detail_overlay()
	_build_slide_panel()
	_build_bay_panel()
	_build_float_popups()
	_build_toast()


func _build_planet_area() -> void:
	# Planet scroll centered vertically — cards are ~96px tall
	_planet_scroll = ScrollContainer.new()
	_planet_scroll.anchor_left = 0.0
	_planet_scroll.anchor_right = 1.0
	_planet_scroll.anchor_top = 0.5
	_planet_scroll.anchor_bottom = 0.5
	_planet_scroll.offset_left = 24.0
	_planet_scroll.offset_right = -24.0
	_planet_scroll.offset_top = -50.0
	_planet_scroll.offset_bottom = 50.0
	_planet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_planet_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_planet_area.add_child(_planet_scroll)

	_planet_row = HBoxContainer.new()
	_planet_row.add_theme_constant_override("separation", 20)
	_planet_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_planet_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_planet_scroll.add_child(_planet_row)


func _build_detail_overlay() -> void:
	_detail_overlay = ColorRect.new()
	_detail_overlay.anchor_left = 0.0
	_detail_overlay.anchor_top = 0.0
	_detail_overlay.anchor_right = 1.0
	_detail_overlay.anchor_bottom = 0.0
	_detail_overlay.offset_top = 0.0
	_detail_overlay.offset_bottom = POPUP_HEIGHT
	_detail_overlay.color = Color(0, 0, 0, 0.60)
	_detail_overlay.visible = false
	_detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_detail_overlay)


func _build_slide_panel() -> void:
	_slide_panel = PanelContainer.new()
	_slide_panel.anchor_left = 0.25
	_slide_panel.anchor_top = 0.0
	_slide_panel.anchor_right = 1.0
	_slide_panel.anchor_bottom = 0.0
	_slide_panel.offset_top = 0.0
	_slide_panel.offset_bottom = POPUP_HEIGHT
	_slide_panel.offset_left = 0.0
	_slide_panel.offset_right = 0.0
	_slide_panel.visible = false
	var slide_style := StyleBoxFlat.new()
	slide_style.bg_color = Color(0.05, 0.08, 0.14, 0.98)
	slide_style.border_color = Color(0.30, 0.44, 0.68, 0.95)
	slide_style.border_width_left = 1
	slide_style.border_width_top = 0
	slide_style.border_width_right = 0
	slide_style.border_width_bottom = 0
	slide_style.content_margin_left = 12
	slide_style.content_margin_right = 16
	slide_style.content_margin_top = 8
	slide_style.content_margin_bottom = 8
	_slide_panel.add_theme_stylebox_override("panel", slide_style)
	add_child(_slide_panel)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 14)
	_slide_panel.add_child(row)

	# Left: X close button
	var x_btn := Button.new()
	x_btn.text = "×"
	x_btn.custom_minimum_size = Vector2(40, 0)
	x_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	x_btn.pressed.connect(_deselect_planet)
	row.add_child(x_btn)

	# Middle: planet detail info
	var info_section := VBoxContainer.new()
	info_section.custom_minimum_size = Vector2(220, 0)
	info_section.add_theme_constant_override("separation", 8)
	row.add_child(info_section)

	_detail_info_label = Label.new()
	_detail_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_info_label.add_theme_font_size_override("font_size", 13)
	info_section.add_child(_detail_info_label)

	var direct_btn := Button.new()
	direct_btn.text = "▶ 직접 파견"
	direct_btn.custom_minimum_size = Vector2(0, 32)
	direct_btn.pressed.connect(func():
		GameState.selected_planet = _selected_planet_id
		GameState.start_direct_dispatch()
		PanelManager.show_panel("clicker")
		hide()
	)
	info_section.add_child(direct_btn)

	# Right: planet slot section
	var slot_wrap := VBoxContainer.new()
	slot_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(slot_wrap)

	_slot_scroll_container = ScrollContainer.new()
	_slot_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_slot_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_slot_scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot_wrap.add_child(_slot_scroll_container)

	_slot_grid = GridContainer.new()
	_slot_grid.columns = 4
	_slot_grid.add_theme_constant_override("h_separation", 20)
	_slot_grid.add_theme_constant_override("v_separation", 12)
	_slot_scroll_container.add_child(_slot_grid)


func _build_bay_panel() -> void:
	_bay_panel = PanelContainer.new()
	_bay_panel.anchor_left = 0.25
	_bay_panel.anchor_top = 0.0
	_bay_panel.anchor_right = 1.0
	_bay_panel.anchor_bottom = 0.0
	_bay_panel.offset_top = 0.0
	_bay_panel.offset_bottom = POPUP_HEIGHT
	_bay_panel.offset_left = 2000.0
	_bay_panel.offset_right = 2000.0
	_bay_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.09, 0.16, 0.99)
	style.border_color = Color(0.32, 0.48, 0.72, 0.95)
	style.border_width_left = 2
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	style.content_margin_left = 8
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_bay_panel.add_theme_stylebox_override("panel", style)
	add_child(_bay_panel)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 6)
	_bay_panel.add_child(row)

	var cancel_btn := Button.new()
	cancel_btn.text = "×"
	cancel_btn.custom_minimum_size = Vector2(40, 0)
	cancel_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cancel_btn.pressed.connect(_hide_bay_panel)
	row.add_child(cancel_btn)

	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 6)
	row.add_child(right_vbox)

	_bay_scroll = ScrollContainer.new()
	_bay_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bay_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bay_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_bay_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_vbox.add_child(_bay_scroll)

	_bay_grid = GridContainer.new()
	_bay_grid.columns = 2
	_bay_grid.add_theme_constant_override("h_separation", 16)
	_bay_grid.add_theme_constant_override("v_separation", 12)
	_bay_scroll.add_child(_bay_grid)



func _build_float_popups() -> void:
	pass


func _build_toast() -> void:
	_toast_label = Label.new()
	_toast_label.visible = false
	_toast_label.anchor_left = 0.0
	_toast_label.anchor_top = 1.0
	_toast_label.anchor_right = 0.0
	_toast_label.anchor_bottom = 1.0
	_toast_label.offset_left = 16.0
	_toast_label.offset_top = -38.0
	_toast_label.offset_right = 460.0
	_toast_label.offset_bottom = -12.0
	_toast_label.modulate = Color(0.85, 0.92, 1.0)
	add_child(_toast_label)


func _select_default_planet() -> void:
	if _selected_planet_id != "":
		return
	if GameState.selected_planet != "":
		_selected_planet_id = GameState.selected_planet
		return
	for planet in GameState.PLANETS:
		var pid := str(planet["id"])
		if GameState.is_planet_unlocked(pid):
			_selected_planet_id = pid
			return
	_selected_planet_id = str(GameState.PLANETS[0]["id"])


func _rebuild_planets() -> void:
	for child in _planet_row.get_children():
		child.queue_free()
	_planet_buttons.clear()

	for i in GameState.PLANETS.size():
		var planet: Dictionary = GameState.PLANETS[i]
		var pid := str(planet["id"])
		var unlocked := GameState.is_planet_unlocked(pid)
		var selected := pid == _selected_planet_id and _planet_detail_mode
		var card := _make_planet_card(planet, pid, i, unlocked, selected)
		_planet_row.add_child(card)
		_planet_buttons[pid] = card

	call_deferred("_restore_planet_scroll_to_selected")


func _make_planet_card(planet: Dictionary, pid: String, index: int, unlocked: bool, selected: bool) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(76, 90)
	card.toggle_mode = true
	card.button_pressed = selected
	card.flat = true
	card.disabled = not unlocked

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	var icon_wrap := PanelContainer.new()
	icon_wrap.custom_minimum_size = Vector2(58, 58)
	icon_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_style := StyleBoxFlat.new()
	var base_color: Color = PLANET_COLORS[index % PLANET_COLORS.size()]
	icon_style.bg_color = base_color.darkened(0.3) if selected else (base_color.darkened(0.55) if not unlocked else base_color.darkened(0.15))
	icon_style.border_color = base_color if selected else (base_color.darkened(0.3) if unlocked else Color(0.3, 0.3, 0.4))
	icon_style.set_border_width_all(2 if selected else 1)
	icon_style.set_corner_radius_all(29)
	icon_wrap.add_theme_stylebox_override("panel", icon_style)
	vbox.add_child(icon_wrap)

	var name_lbl := Label.new()
	name_lbl.text = str(planet.get("name", ""))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.modulate = Color(0.90, 0.95, 1.0) if unlocked else Color(0.45, 0.45, 0.55)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	card.pressed.connect(func(): _select_planet(pid))
	return card


func _restore_planet_scroll_to_selected() -> void:
	var btn = _planet_buttons.get(_selected_planet_id, null)
	if btn and is_instance_valid(btn):
		_planet_scroll.ensure_control_visible(btn)


func _rebuild_detail() -> void:
	if not is_instance_valid(_detail_info_label):
		return
	var planet := GameState.get_planet(_selected_planet_id)
	if planet.is_empty():
		_detail_info_label.text = ""
		return
	_detail_info_label.text = "%s\n\n적 HP  %d\nCR/킬  %d\n웨이브  %d" % [
		str(planet.get("name", "")),
		int(planet.get("enemy_hp", 0)),
		int(planet.get("credit_per_kill", 0)),
		int(planet.get("wave_size", 0)),
	]


func _rebuild_slots() -> void:
	for child in _slot_grid.get_children():
		child.queue_free()
	var planet := GameState.get_planet(_selected_planet_id)
	if planet.is_empty():
		return
	var max_slots := int(planet.get("max_slots", 1))
	var active_bays: Array = []
	for i in GameState.auto_slots.size():
		var s := GameState.auto_slots[i] as DispatchManager.AutoSlot
		if s.planet == _selected_planet_id and s.state in ["on_mission", "returning", "returned"]:
			active_bays.append(i)
	_slot_grid.columns = ceili(max_slots / 4.0)
	for i in max_slots:
		var bay_index: int = active_bays[i] if i < active_bays.size() else -1
		_slot_grid.add_child(_make_planet_slot_card(i, bay_index))


func _make_planet_slot_card(slot_idx: int, bay_index: int) -> Button:
	var btn := Button.new()
	btn.toggle_mode = false
	btn.custom_minimum_size = Vector2(58, 58)
	btn.add_theme_font_size_override("font_size", 12)
	if bay_index < 0:
		btn.text = "%d\n+" % (slot_idx + 1)
		btn.pressed.connect(func(): _show_bay_panel(slot_idx))
		_apply_slot_style(btn, "offline", false)
	else:
		var slot := GameState.auto_slots[bay_index] as DispatchManager.AutoSlot
		var abbr: String
		match slot.state:
			"on_mission": abbr = "▶"
			"returning":  abbr = "◀"
			"returned":   abbr = "복귀"
			_:            abbr = "?"
		btn.text = "%d\n%s" % [slot_idx + 1, abbr]
		btn.disabled = true
		_apply_slot_style(btn, slot.state, true)
	return btn


func _collect_bay(bay_index: int) -> void:
	if not GameState.collect_auto_slot(bay_index):
		_show_toast("수령 실패")
		return
	_show_toast("수령 완료")
	_rebuild_slots()


func _slot_state_text(state: String, is_this_planet: bool, planet_id: String) -> String:
	match state:
		"empty":      return "머신 없음"
		"offline":    return "대기 중"
		"on_mission":
			if is_this_planet: return "파견 중"
			var p := GameState.get_planet(planet_id)
			return "타 행성" if p.is_empty() else str(p.get("name", "타 행성"))
		"returning":  return "복귀 중" if is_this_planet else "타 행성 복귀"
		"returned":   return "수령 대기" if is_this_planet else "타 행성 수령"
		_: return state


func _apply_slot_style(btn: Button, state: String, is_this_planet: bool) -> void:
	var accent: Color
	if is_this_planet:
		match state:
			"on_mission": accent = Color(0.34, 0.82, 0.84, 0.95)
			"returning":  accent = Color(0.92, 0.72, 0.32, 0.95)
			"returned":   accent = Color(0.78, 0.92, 0.44, 0.95)
			_: accent = Color(0.38, 0.56, 0.78, 0.95)
	else:
		match state:
			"empty":   accent = Color(0.30, 0.30, 0.38, 0.85)
			"offline": accent = Color(0.38, 0.56, 0.78, 0.95)
			_:         accent = Color(0.42, 0.42, 0.52, 0.80)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.22, accent.g * 0.22, accent.b * 0.22, 0.92)
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("pressed", style)


func _select_planet(planet_id: String) -> void:
	if not GameState.is_planet_unlocked(planet_id):
		_show_toast("미해금 행성입니다.")
		return
	_selected_planet_id = planet_id
	GameState.selected_planet = planet_id
	_rebuild_detail()
	_rebuild_slots()
	_rebuild_planets()
	if not _planet_detail_mode:
		_planet_detail_mode = true
		_enter_detail_mode()


func _deselect_planet() -> void:
	_planet_detail_mode = false
	if _bay_select_mode:
		_bay_select_mode = false
		_bay_panel_dragging = false
		_bay_panel.visible = false
	_rebuild_planets()
	_exit_detail_mode()


func _enter_detail_mode() -> void:
	var off := maxf(size.x, 800.0)
	_detail_overlay.visible = true
	_slide_panel.offset_left = off
	_slide_panel.offset_right = off
	_slide_panel.visible = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_slide_panel, "offset_left", 0.0, 0.24).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_slide_panel, "offset_right", 0.0, 0.24).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


func _exit_detail_mode() -> void:
	var off := maxf(size.x, 800.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_slide_panel, "offset_left", off, 0.20).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_slide_panel, "offset_right", off, 0.20).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_callback(func():
		_slide_panel.visible = false
		_detail_overlay.visible = false
	)


func _show_bay_panel(slot_idx: int) -> void:
	_bay_select_mode = true
	_refresh_bay_grid()

	var off := maxf(size.x, 800.0)
	_bay_panel.offset_left = off
	_bay_panel.offset_right = off
	_bay_panel.visible = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_bay_panel, "offset_left", 300.0, 0.20).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_bay_panel, "offset_right", 0.0, 0.20).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


func _refresh_bay_grid() -> void:
	for child in _bay_grid.get_children():
		child.queue_free()
	var available: Array = []
	for i in GameState.auto_slots.size():
		var s := GameState.auto_slots[i] as DispatchManager.AutoSlot
		if s.state != "locked":
			available.append(i)
	if available.is_empty():
		var lbl := Label.new()
		lbl.text = "사용 가능한 베이 없음"
		lbl.modulate = Color(0.55, 0.55, 0.65)
		_bay_grid.add_child(lbl)
	else:
		_bay_grid.columns = ceili(available.size() / 2.0)
		for bay_index in available:
			var bay_i: int = bay_index
			var slot := GameState.auto_slots[bay_i] as DispatchManager.AutoSlot
			_bay_grid.add_child(_make_bay_card(bay_i, slot))


func _hide_bay_panel() -> void:
	_bay_select_mode = false
	_bay_panel_dragging = false
	var off := maxf(size.x, 800.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_bay_panel, "offset_left", off, 0.18).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_bay_panel, "offset_right", off, 0.18).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_callback(func(): _bay_panel.visible = false)


func _make_bay_card(bay_index: int, slot: DispatchManager.AutoSlot) -> PanelContainer:
	var accent: Color
	match slot.state:
		"offline":    accent = Color(0.38, 0.56, 0.78, 0.95)
		"on_mission": accent = Color(0.34, 0.82, 0.84, 0.95)
		"returning":  accent = Color(0.92, 0.72, 0.32, 0.95)
		"returned":   accent = Color(0.78, 0.92, 0.44, 0.95)
		_:            accent = Color(0.30, 0.30, 0.38, 0.85)
	var _pid := slot.pilot_id if slot.pilot_id != "" else slot.assigned_pilot_id
	var pilot_name := "—"
	if _pid != "":
		var p := GameState.get_hired_pilot(_pid)
		if not p.is_empty():
			pilot_name = str(p.get("name", _pid))

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(96, 100)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.20, accent.g * 0.20, accent.b * 0.20, 0.92)
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)
	var num_lbl := Label.new()
	num_lbl.text = "BAY %02d" % (bay_index + 1)
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(num_lbl)
	var pilot_lbl := Label.new()
	pilot_lbl.text = pilot_name
	pilot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pilot_lbl.add_theme_font_size_override("font_size", 10)
	pilot_lbl.modulate = Color(0.72, 0.84, 1.0)
	pilot_lbl.clip_text = true
	vbox.add_child(pilot_lbl)
	match slot.state:
		"offline":
			var btn := Button.new()
			btn.text = "출격"
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size = Vector2(0, 28)
			btn.pressed.connect(func(): _dispatch_from_bay(bay_index))
			btn.disabled = not _can_dispatch_bay(bay_index)
			vbox.add_child(btn)
		"returned":
			var state_lbl := Label.new()
			state_lbl.text = "복귀 완료"
			state_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			state_lbl.add_theme_font_size_override("font_size", 10)
			state_lbl.modulate = accent
			vbox.add_child(state_lbl)
		_:
			var state_lbl := Label.new()
			state_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			state_lbl.add_theme_font_size_override("font_size", 10)
			state_lbl.modulate = accent
			match slot.state:
				"on_mission": state_lbl.text = "파견 중"
				"returning":  state_lbl.text = "복귀 중"
				_:            state_lbl.text = slot.state
			vbox.add_child(state_lbl)
	return card


func _can_dispatch_bay(_bay_index: int) -> bool:
	if _selected_planet_id == "":
		return false
	var pilot_id := _get_first_idle_pilot_id()
	if pilot_id == "":
		return false
	var pilot := GameState.get_hired_pilot(pilot_id)
	if pilot.is_empty():
		return false
	var pilot_tier := int(pilot.get("tier", 1))
	for p in GameState._dispatch.get_pilot_accessible_planets(pilot_tier):
		if str(p.get("id", "")) == _selected_planet_id:
			return true
	return false


func _dispatch_from_bay(bay_index: int) -> void:
	_hide_bay_panel()
	var pilot_id := _get_first_idle_pilot_id()
	if pilot_id == "":
		_show_toast("대기 파일럿이 없습니다.")
		return
	if not GameState._dispatch.start_auto_dispatch(bay_index, pilot_id, _selected_planet_id):
		_show_toast("BAY %02d 파견 실패" % (bay_index + 1))
		return
	_show_toast("BAY %02d 파견 시작" % (bay_index + 1))
	_rebuild_slots()


func _get_first_idle_pilot_id() -> String:
	for pilot in GameState.get_idle_pilots():
		return str(pilot.get("id", ""))
	return ""


func _show_toast(text: String) -> void:
	_toast_label.text = text
	_toast_label.visible = true
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(_hide_toast)


func _hide_toast() -> void:
	_toast_label.visible = false


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _bay_select_mode:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_bay_panel_dragging = true
				_bay_drag_anchor_x = event.position.x
				_bay_drag_scroll_start = _bay_scroll.scroll_horizontal
				get_viewport().set_input_as_handled()
			else:
				_bay_panel_dragging = false
				get_viewport().set_input_as_handled()
		elif event is InputEventMouseMotion and _bay_panel_dragging:
			var delta := int(_bay_drag_anchor_x - event.position.x)
			var max_scroll := maxi(0, int(_bay_grid.size.x - _bay_scroll.size.x))
			_bay_scroll.scroll_horizontal = clampi(_bay_drag_scroll_start + delta, 0, max_scroll)
			get_viewport().set_input_as_handled()
		return
	if _planet_detail_mode:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_slot_dragging = true
				_slot_drag_anchor_x = event.position.x
				_slot_drag_scroll_start = _slot_scroll_container.scroll_horizontal
				get_viewport().set_input_as_handled()
			else:
				_slot_dragging = false
				get_viewport().set_input_as_handled()
		elif event is InputEventMouseMotion and _slot_dragging:
			var delta := int(_slot_drag_anchor_x - event.position.x)
			var max_scroll := maxi(0, int(_slot_grid.size.x - _slot_scroll_container.size.x))
			_slot_scroll_container.scroll_horizontal = clampi(_slot_drag_scroll_start + delta, 0, max_scroll)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_planet_dragging = true
			_planet_drag_anchor_x = event.position.x
			_planet_drag_scroll_start = _planet_scroll.scroll_horizontal
			get_viewport().set_input_as_handled()
		else:
			_planet_dragging = false
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _planet_dragging:
		var delta := int(_planet_drag_anchor_x - event.position.x)
		var max_scroll := maxi(0, int(_planet_row.size.x - _planet_scroll.size.x))
		_planet_scroll.scroll_horizontal = clampi(_planet_drag_scroll_start + delta, 0, max_scroll)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if _bay_select_mode:
			_hide_bay_panel()
		elif _planet_detail_mode:
			_deselect_planet()
		else:
			close_popup()
		get_viewport().set_input_as_handled()


func _on_state_changed(_planet_id: String) -> void:
	if visible:
		_rebuild_planets()


func _on_auto_slot_changed(_index: int) -> void:
	if visible and _planet_detail_mode:
		_rebuild_slots()
