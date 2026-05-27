extends Control

const POPUP_HEIGHT := 264.0

var _main_panel: PanelContainer
var _planet_pane: PanelContainer
var _detail_pane: PanelContainer
var _slot_pane: PanelContainer
var _planet_scroll: ScrollContainer
var _planet_row: HBoxContainer
var _detail_body: VBoxContainer
var _slot_grid: GridContainer
var _ship_popup: PanelContainer
var _ship_popup_body: VBoxContainer
var _confirm_popup: PanelContainer
var _confirm_label: Label
var _toast_label: Label
var _confirm_bay_index: int = -1
var _selected_planet_id: String = ""
var _planet_detail_mode: bool = false
var _selected_slot_index: int = -1
var _selected_bay_index: int = -1
var _last_ship_anchor: Control = null
var _planet_buttons: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	hide()
	GameState.planet_unlocked.connect(_on_state_changed)
	GameState.auto_slot_changed.connect(_on_auto_slot_changed)
	GameState.auto_dispatch_returned.connect(_on_auto_slot_changed)
	GameState.pilot_hired.connect(_on_auto_slot_changed)
	GameState.pilot_status_changed.connect(_on_auto_slot_changed)


func open_for_control_room() -> void:
	visible = true
	_select_default_planet()
	_rebuild()
	_apply_layout_mode()
	_main_panel.offset_top = -POPUP_HEIGHT
	var tween := create_tween()
	tween.tween_property(_main_panel, "offset_top", 0.0, 0.20).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


func close_popup() -> void:
	if not visible:
		return
	var tween := create_tween()
	tween.tween_property(_main_panel, "offset_top", -POPUP_HEIGHT, 0.18).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func():
		hide()
		_hide_ship_popup()
		_hide_confirm_popup()
		_hide_toast()
		_selected_slot_index = -1
		_selected_bay_index = -1
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
	main_style.bg_color = Color(0.04, 0.06, 0.11, 0.96)
	main_style.border_color = Color(0.28, 0.40, 0.62, 0.96)
	main_style.set_border_width_all(1)
	main_style.set_corner_radius_all(8)
	main_style.content_margin_left = 12
	main_style.content_margin_right = 12
	main_style.content_margin_top = 10
	main_style.content_margin_bottom = 10
	_main_panel.add_theme_stylebox_override("panel", main_style)
	add_child(_main_panel)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	_main_panel.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)

	var title := Label.new()
	title.text = "항성지도"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var hint := Label.new()
	hint.text = "마지막 선택 행성 복원"
	hint.modulate = Color(0.68, 0.74, 0.90)
	header.add_child(hint)

	var close_btn := Button.new()
	close_btn.text = "닫기"
	close_btn.pressed.connect(close_popup)
	header.add_child(close_btn)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	_planet_pane = _make_pane("우주지도")
	_planet_pane.custom_minimum_size = Vector2(720, 0)
	_planet_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_planet_pane)

	_detail_pane = _make_pane("행성 상세")
	_detail_pane.custom_minimum_size = Vector2(430, 0)
	_detail_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_detail_pane)

	_slot_pane = _make_pane("BAY / 슬롯")
	_slot_pane.custom_minimum_size = Vector2(520, 0)
	_slot_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_slot_pane)

	_build_planet_pane()
	_build_detail_pane()
	_build_slot_pane()
	_build_float_popups()
	_build_toast()


func _make_pane(title_text: String) -> PanelContainer:
	var pane := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.10, 0.16, 0.92)
	style.border_color = Color(0.24, 0.36, 0.54, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	pane.add_theme_stylebox_override("panel", style)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	pane.add_child(root)

	var lbl := Label.new()
	lbl.text = title_text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.modulate = Color(0.76, 0.88, 1.0)
	root.add_child(lbl)

	var body := VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 6)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	return pane


func _build_planet_pane() -> void:
	var body := _planet_pane.get_node("Body") as VBoxContainer
	_planet_scroll = ScrollContainer.new()
	_planet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_planet_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_planet_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_planet_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_planet_scroll)

	_planet_row = HBoxContainer.new()
	_planet_row.add_theme_constant_override("separation", 8)
	_planet_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_planet_scroll.add_child(_planet_row)


func _build_detail_pane() -> void:
	var body := _detail_pane.get_node("Body") as VBoxContainer
	_detail_body = VBoxContainer.new()
	_detail_body.add_theme_constant_override("separation", 6)
	_detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_detail_body)


func _build_slot_pane() -> void:
	var body := _slot_pane.get_node("Body") as VBoxContainer
	_slot_grid = GridContainer.new()
	_slot_grid.columns = max(1, ceili(float(GameState.auto_slots.size()) / 2.0))
	_slot_grid.add_theme_constant_override("h_separation", 8)
	_slot_grid.add_theme_constant_override("v_separation", 8)
	_slot_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_slot_grid)


func _build_float_popups() -> void:
	_ship_popup = PanelContainer.new()
	_ship_popup.visible = false
	_ship_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_ship_popup.size = Vector2(260, 260)
	var ship_style := StyleBoxFlat.new()
	ship_style.bg_color = Color(0.05, 0.08, 0.14, 0.98)
	ship_style.border_color = Color(0.40, 0.60, 0.82, 0.9)
	ship_style.set_border_width_all(1)
	ship_style.set_corner_radius_all(6)
	ship_style.content_margin_left = 10
	ship_style.content_margin_right = 10
	ship_style.content_margin_top = 8
	ship_style.content_margin_bottom = 8
	_ship_popup.add_theme_stylebox_override("panel", ship_style)
	add_child(_ship_popup)

	var ship_root := VBoxContainer.new()
	ship_root.name = "ShipPopupRoot"
	ship_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ship_root.add_theme_constant_override("separation", 6)
	_ship_popup.add_child(ship_root)

	var ship_title := Label.new()
	ship_title.text = "기체 선택"
	ship_title.add_theme_font_size_override("font_size", 13)
	ship_root.add_child(ship_title)

	_ship_popup_body = VBoxContainer.new()
	_ship_popup_body.add_theme_constant_override("separation", 4)
	_ship_popup_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ship_popup_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ship_root.add_child(_ship_popup_body)

	_confirm_popup = PanelContainer.new()
	_confirm_popup.visible = false
	_confirm_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_popup.size = Vector2(190, 102)
	var confirm_style := StyleBoxFlat.new()
	confirm_style.bg_color = Color(0.05, 0.08, 0.14, 0.98)
	confirm_style.border_color = Color(0.54, 0.74, 1.0, 0.9)
	confirm_style.set_border_width_all(1)
	confirm_style.set_corner_radius_all(6)
	confirm_style.content_margin_left = 10
	confirm_style.content_margin_right = 10
	confirm_style.content_margin_top = 8
	confirm_style.content_margin_bottom = 8
	_confirm_popup.add_theme_stylebox_override("panel", confirm_style)
	add_child(_confirm_popup)

	var confirm_root := VBoxContainer.new()
	confirm_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm_root.add_theme_constant_override("separation", 6)
	_confirm_popup.add_child(confirm_root)

	_confirm_label = Label.new()
	_confirm_label.text = "파견 시작?"
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_root.add_child(_confirm_label)

	var confirm_buttons := HBoxContainer.new()
	confirm_buttons.add_theme_constant_override("separation", 6)
	confirm_root.add_child(confirm_buttons)

	var ok_btn := Button.new()
	ok_btn.text = "확인"
	ok_btn.pressed.connect(func(): _confirm_dispatch(_confirm_bay_index))
	confirm_buttons.add_child(ok_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "취소"
	cancel_btn.pressed.connect(_hide_confirm_popup)
	confirm_buttons.add_child(cancel_btn)


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


func _rebuild() -> void:
	_rebuild_planets()
	_rebuild_detail()
	_rebuild_slots()


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

	for planet in GameState.PLANETS:
		var pid := str(planet["id"])
		var unlocked := GameState.is_planet_unlocked(pid)
		var button := Button.new()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(148, 62)
		button.text = "%s\n%s" % [str(planet["name"]), "UNLOCKED" if unlocked else "LOCKED"]
		button.button_pressed = pid == _selected_planet_id
		button.disabled = not unlocked
		button.add_theme_font_size_override("font_size", 11)
		button.pressed.connect(func():
			_select_planet(pid)
		)
		_apply_planet_style(button, unlocked, pid == _selected_planet_id)
		_planet_row.add_child(button)
		_planet_buttons[pid] = button

	call_deferred("_restore_planet_scroll")


func _restore_planet_scroll() -> void:
	var btn: Button = _planet_buttons.get(_selected_planet_id, null)
	if btn and is_instance_valid(btn):
		_planet_scroll.ensure_control_visible(btn)


func _apply_planet_style(btn: Button, unlocked: bool, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.16, 0.24, 0.96) if selected else Color(0.07, 0.10, 0.16, 0.92)
	style.border_color = Color(0.70, 0.88, 1.0, 0.9) if selected else (Color(0.34, 0.48, 0.68, 0.75) if unlocked else Color(0.24, 0.24, 0.34, 0.8))
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("pressed", style)


func _rebuild_detail() -> void:
	for child in _detail_body.get_children():
		child.queue_free()

	var planet := GameState.get_planet(_selected_planet_id)
	if planet.is_empty():
		return

	var title := Label.new()
	title.text = str(planet.get("name", ""))
	title.add_theme_font_size_override("font_size", 18)
	_detail_body.add_child(title)

	var info := Label.new()
	info.text = "적 HP %d  ·  %d CR/킬  ·  %d 웨이브" % [
		int(planet.get("enemy_hp", 0)),
		int(planet.get("credits_per_kill", 0)),
		int(planet.get("wave_count", 0)),
	]
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_body.add_child(info)

	var desc := Label.new()
	desc.text = "선택하면 좌측 지도는 15%% 폭까지 축소되고, 우측 슬롯/기체 선택이 열립니다."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_body.add_child(desc)

	var selected_lbl := Label.new()
	selected_lbl.text = "선택된 행성: %s" % str(planet.get("name", ""))
	_detail_body.add_child(selected_lbl)


func _rebuild_slots() -> void:
	for child in _slot_grid.get_children():
		child.queue_free()
	_slot_grid.columns = max(1, ceili(float(GameState.auto_slots.size()) / 2.0))

	for i in GameState.auto_slots.size():
		_slot_grid.add_child(_make_slot_card(i))


func _make_slot_card(index: int) -> Button:
	var slot: DispatchManager.AutoSlot = GameState.auto_slots[index]
	var btn := Button.new()
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(150, 52)
	btn.add_theme_font_size_override("font_size", 10)
	btn.text = "BAY %02d\n%s" % [index + 1, _slot_state_text(slot.state)]
	btn.pressed.connect(func():
		_open_ship_popup(index, btn)
	)
	_apply_slot_style(btn, slot.state)
	return btn


func _slot_state_text(state: String) -> String:
	match state:
		"locked":
			return "정보 슬롯"
		"empty":
			return "빈 슬롯"
		"offline":
			return "대기"
		"on_mission":
			return "파견 중"
		"returning":
			return "복귀 중"
		"returned":
			return "수령 대기"
		_:
			return state


func _apply_slot_style(btn: Button, state: String) -> void:
	var style := StyleBoxFlat.new()
	var accent := Color(0.30, 0.46, 0.66, 0.95)
	match state:
		"locked":
			accent = Color(0.28, 0.30, 0.36, 0.95)
		"offline":
			accent = Color(0.38, 0.56, 0.78, 0.95)
		"on_mission":
			accent = Color(0.34, 0.82, 0.84, 0.95)
		"returning":
			accent = Color(0.92, 0.72, 0.32, 0.95)
		"returned":
			accent = Color(0.78, 0.92, 0.44, 0.95)
	style.bg_color = Color(accent.r * 0.26, accent.g * 0.26, accent.b * 0.26, 0.92)
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("pressed", style)


func _select_planet(planet_id: String) -> void:
	if not GameState.is_planet_unlocked(planet_id):
		_show_toast("미해금 행성입니다.")
		return
	_selected_planet_id = planet_id
	_planet_detail_mode = true
	GameState.selected_planet = planet_id
	_rebuild()
	_apply_layout_mode()


func _apply_layout_mode() -> void:
	if _planet_detail_mode:
		_planet_pane.custom_minimum_size.x = 280
		_detail_pane.custom_minimum_size.x = 520
		_slot_pane.custom_minimum_size.x = 640
	else:
		_planet_pane.custom_minimum_size.x = 720
		_detail_pane.custom_minimum_size.x = 430
		_slot_pane.custom_minimum_size.x = 520


func _open_ship_popup(slot_index: int, anchor: Control) -> void:
	_selected_slot_index = slot_index
	_last_ship_anchor = anchor
	_selected_bay_index = -1
	_hide_confirm_popup()

	for child in _ship_popup_body.get_children():
		child.queue_free()

	var intro := Label.new()
	intro.text = "BAY 선택"
	_ship_popup_body.add_child(intro)

	for i in GameState.auto_slots.size():
		var bay_index := i
		var bay_btn := Button.new()
		bay_btn.text = "0 BAY - 직접 파견" if bay_index == 0 else "BAY %02d" % (bay_index + 1)
		bay_btn.disabled = bay_index > 0 and not _bay_ready_for_dispatch(bay_index)
		bay_btn.pressed.connect(func():
			_select_ship_bay(bay_index)
		)
		_ship_popup_body.add_child(bay_btn)

	var local_pos := anchor.global_position - global_position + Vector2(anchor.size.x + 10, 0)
	_ship_popup.position = local_pos
	_ship_popup.visible = true


func _select_ship_bay(bay_index: int) -> void:
	_selected_bay_index = bay_index
	_show_confirm_popup(bay_index)


func _show_confirm_popup(bay_index: int) -> void:
	_confirm_bay_index = bay_index
	_confirm_label.text = "파견 시작?"
	if bay_index == 0:
		_confirm_label.text = "직접 파견 시작?"
	else:
		_confirm_label.text = "BAY %02d 파견 시작?" % (bay_index + 1)
	_confirm_popup.position = _ship_popup.position + Vector2(_ship_popup.size.x + 8, 32)
	_confirm_popup.visible = true


func _confirm_dispatch(bay_index: int) -> void:
	_hide_ship_popup()
	_hide_confirm_popup()
	if bay_index <= 0:
		GameState.selected_planet = _selected_planet_id
		GameState.start_direct_dispatch()
		PanelManager.show_panel("clicker")
		hide()
		return

	var pilot_id := _get_first_idle_pilot_id()
	if pilot_id == "":
		_show_toast("대기 파일럿이 없습니다.")
		return
	if not GameState._dispatch.start_auto_dispatch(bay_index, pilot_id, _selected_planet_id):
		_show_toast("BAY %02d 파견 실패" % (bay_index + 1))
		return
	_show_toast("BAY %02d 파견 시작" % (bay_index + 1))


func _bay_ready_for_dispatch(bay_index: int) -> bool:
	if bay_index < 0 or bay_index >= GameState.auto_slots.size():
		return false
	var slot: DispatchManager.AutoSlot = GameState.auto_slots[bay_index]
	return slot.state == "offline"


func _get_first_idle_pilot_id() -> String:
	for pilot in GameState.get_idle_pilots():
		return str(pilot.get("id", ""))
	return ""


func _hide_ship_popup() -> void:
	_ship_popup.visible = false


func _hide_confirm_popup() -> void:
	_confirm_popup.visible = false


func _show_toast(text: String) -> void:
	_toast_label.text = text
	_toast_label.visible = true
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(_hide_toast)


func _hide_toast() -> void:
	_toast_label.visible = false


func _on_state_changed(_planet_id: String) -> void:
	if visible:
		_rebuild()


func _on_auto_slot_changed(_index: int) -> void:
	if visible:
		_rebuild_slots()
