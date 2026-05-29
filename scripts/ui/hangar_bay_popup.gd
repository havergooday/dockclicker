class_name HangarBayPopup
extends Control

const POPUP_HEIGHT := 300.0
const PANEL_W_RATIO := 0.60
const PANEL_PAD_X := 32.0
const PANEL_PAD_Y := 12.0
var _selector_w: float = 220.0  # computed in _build_ui from viewport

signal navigate_to_control_requested

var _panel: PanelContainer
var _content_root: Control
var _selector_panel: PanelContainer
var _selector_body: VBoxContainer
var _selector_scroll: ScrollContainer = null
var _slot_index: int = -1
var _closing: bool = false
var _selector_visible: bool = false
var _selector_kind: String = ""
var _selector_part_key: String = ""
var _draft_pilot_id: String = ""
var _draft_machine: Dictionary = {}
var _sel_dragging: bool = false
var _sel_drag_start_y: float = 0.0
var _sel_drag_start_scroll: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	hide()


func _input(event: InputEvent) -> void:
	if not visible or not _selector_visible or _selector_scroll == null or _selector_panel == null:
		return
	var sel_rect := Rect2(_selector_panel.global_position, _selector_panel.size)
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
				if event.pressed and sel_rect.has_point(event.global_position):
					_sel_dragging = true
					_sel_drag_start_y = event.global_position.y
					_sel_drag_start_scroll = _selector_scroll.scroll_vertical
					get_viewport().set_input_as_handled()
				elif not event.pressed and _sel_dragging:
					_sel_dragging = false
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if sel_rect.has_point(event.global_position):
					get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _sel_dragging:
		var delta: float = _sel_drag_start_y - (event as InputEventMouseMotion).global_position.y
		_selector_scroll.scroll_vertical = _sel_drag_start_scroll + int(delta)
		get_viewport().set_input_as_handled()


func open_for_slot(slot_index: int) -> void:
	_slot_index = slot_index
	_closing = false
	visible = true
	_init_draft_state()
	_rebuild_content()

	var off := -POPUP_HEIGHT
	_panel.offset_top = off
	_panel.offset_bottom = off
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(_panel, "offset_top", 0.0, 0.22)
	tween.parallel().tween_property(_panel, "offset_bottom", 0.0, 0.22)


func close_popup() -> void:
	if not visible or _closing:
		return
	_closing = true
	_flush_draft_to_slot()
	_hide_selector(false)
	var off := -POPUP_HEIGHT
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(_panel, "offset_top", off, 0.18)
	tween.parallel().tween_property(_panel, "offset_bottom", off, 0.18)
	tween.tween_callback(func():
		hide()
		_slot_index = -1
		_closing = false
	)


func _build_ui() -> void:
	_selector_w = get_viewport_rect().size.x * 0.5
	for child in get_children():
		child.queue_free()

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.52)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close_popup()
	)
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.anchor_left = (1.0 - PANEL_W_RATIO) * 0.5
	_panel.anchor_right = 1.0 - (1.0 - PANEL_W_RATIO) * 0.5
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 0.0
	_panel.offset_right = 0.0
	_panel.offset_top = -POPUP_HEIGHT
	_panel.offset_bottom = -POPUP_HEIGHT
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.12, 0.98)
	style.border_color = Color(0.28, 0.40, 0.62, 0.92)
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	style.content_margin_left = PANEL_PAD_X
	style.content_margin_right = PANEL_PAD_X
	style.content_margin_top = PANEL_PAD_Y
	style.content_margin_bottom = PANEL_PAD_Y
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	_panel.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(header)

	var left_spacer := Control.new()
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(left_spacer)

	var close_btn := Button.new()
	close_btn.text = "닫기"
	close_btn.flat = true
	close_btn.custom_minimum_size = Vector2(92, 24)
	close_btn.pressed.connect(close_popup)
	header.add_child(close_btn)

	var right_spacer := Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(right_spacer)

	_content_root = Control.new()
	_content_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_content_root)

	_build_selector_panel()


func _rebuild_content() -> void:
	for child in _content_root.get_children():
		child.queue_free()

	if _slot_index < 0 or _slot_index >= GameState.auto_slots.size():
		return

	var slot: DispatchManager.AutoSlot = GameState.auto_slots[_slot_index]
	var accent := _border_color(slot.state)

	var content := HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("separation", 14)
	_content_root.add_child(content)

	content.add_child(_build_pilot_panel(slot, accent))
	content.add_child(_build_machine_panel(slot, accent))
	content.add_child(_build_spec_panel(slot, accent))
	content.add_child(_build_action_panel(slot, accent))
	_update_selector_state()


func _build_pilot_panel(slot: DispatchManager.AutoSlot, accent: Color) -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(245, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 8)

	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = Vector2(0, 142)
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.10, 0.16, 0.96)
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	portrait.add_theme_stylebox_override("panel", style)
	panel.add_child(portrait)

	var pbox := VBoxContainer.new()
	pbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pbox.add_theme_constant_override("separation", 8)
	portrait.add_child(pbox)

	var portrait_card := PanelContainer.new()
	portrait_card.custom_minimum_size = Vector2(0, 92)
	portrait_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = _pilot_color(slot)
	card_style.border_color = _pilot_color(slot).lightened(0.12)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(8)
	portrait_card.add_theme_stylebox_override("panel", card_style)
	pbox.add_child(portrait_card)

	if slot.state in ["empty", "offline"]:
		var portrait_btn := Button.new()
		portrait_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		portrait_btn.flat = true
		portrait_btn.text = ""
		portrait_btn.focus_mode = Control.FOCUS_NONE
		portrait_btn.modulate = Color(1, 1, 1, 0.01)
		portrait_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		portrait_btn.pressed.connect(func(): _open_selector("pilot", ""))
		portrait_card.add_child(portrait_btn)

	var portrait_lbl := Label.new()
	portrait_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait_lbl.add_theme_font_size_override("font_size", 18)
	portrait_lbl.modulate = Color(1, 1, 1)
	portrait_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_lbl.text = _pilot_caption(slot)
	portrait_card.add_child(portrait_lbl)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	pbox.add_child(info)

	_add_info_line(info, _display_pilot_name(slot), 13, Color(0.85, 0.92, 1.0))
	_add_info_line(info, "티어 %d" % _pilot_tier(slot), 10, Color(0.68, 0.72, 0.82))
	_add_info_line(info, _pilot_bonus_text(slot), 10, Color(0.70, 0.84, 1.0))
	_add_info_line(info, _state_label(slot.state), 10, accent)

	return panel


func _build_machine_panel(slot: DispatchManager.AutoSlot, accent: Color) -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(170, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 4)

	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.13, 0.96)
	style.border_color = accent.darkened(0.08)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	frame.add_theme_stylebox_override("panel", style)
	panel.add_child(frame)

	var schematic := Control.new()
	schematic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	schematic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(schematic)

	var core_glow := PanelContainer.new()
	core_glow.custom_minimum_size = Vector2(48, 84)
	core_glow.position = Vector2(60, 30)
	var core_style := StyleBoxFlat.new()
	core_style.bg_color = Color(0.10, 0.16, 0.24, 0.55)
	core_style.border_color = accent.lightened(0.08)
	core_style.set_border_width_all(1)
	core_style.set_corner_radius_all(4)
	core_glow.add_theme_stylebox_override("panel", core_style)
	schematic.add_child(core_glow)

	var core_line := ColorRect.new()
	core_line.color = Color(1, 1, 1, 0.06)
	core_line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	core_line.offset_left = 22
	core_line.offset_right = 22
	core_glow.add_child(core_line)

	schematic.add_child(_build_equipment_slot("body", slot, accent, Vector2(48, 8), "몸통"))
	schematic.add_child(_build_equipment_slot("weapon", slot, accent, Vector2(4, 58), "무기"))
	schematic.add_child(_build_equipment_slot("legs", slot, accent, Vector2(94, 106), "다리"))

	return panel


func _build_spec_panel(slot: DispatchManager.AutoSlot, accent: Color) -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 8)

	var stats := PanelContainer.new()
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.custom_minimum_size = Vector2(0, 120)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.13, 0.96)
	style.border_color = Color(0.26, 0.34, 0.50, 0.88)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	stats.add_theme_stylebox_override("panel", style)
	panel.add_child(stats)

	var stat_box := VBoxContainer.new()
	stat_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stat_box.add_theme_constant_override("separation", 4)
	stats.add_child(stat_box)

	var preview := _slot_preview(slot)
	_add_kv(stat_box, "전투력", str(int(_part_tier(slot, "body")) + int(_part_tier(slot, "weapon")) + int(_part_tier(slot, "legs"))))
	_add_kv(stat_box, "파견 시간", _format_time(float(preview["mission_time"])))
	_add_kv(stat_box, "복귀 시간", _format_time(float(preview["return_time"])))
	_add_kv(stat_box, "예상 보상", "%s CR" % _fmt(int(preview["credits"])))
	_add_kv(stat_box, "CR/s", str(int(preview["rate"])))
	_add_kv(stat_box, "파일럿 상태", _pilot_status_text(slot))

	var opts := PanelContainer.new()
	opts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opts.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var ostyle := StyleBoxFlat.new()
	ostyle.bg_color = Color(0.04, 0.06, 0.11, 0.96)
	ostyle.border_color = accent.darkened(0.18)
	ostyle.set_border_width_all(1)
	ostyle.set_corner_radius_all(6)
	ostyle.content_margin_left = 12
	ostyle.content_margin_right = 12
	ostyle.content_margin_top = 10
	ostyle.content_margin_bottom = 10
	opts.add_theme_stylebox_override("panel", ostyle)
	panel.add_child(opts)

	var opt_box := VBoxContainer.new()
	opt_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	opt_box.add_theme_constant_override("separation", 4)
	opts.add_child(opt_box)

	var body_t := _part_tier(slot, "body")
	var weapon_t := _part_tier(slot, "weapon")
	var legs_t := _part_tier(slot, "legs")
	_add_option_line(opt_box, "몸통", _part_option_text("body", body_t), Color(0.72, 0.82, 1.0))
	_add_option_line(opt_box, "무기", _part_option_text("weapon", weapon_t), Color(0.72, 0.82, 1.0))
	_add_option_line(opt_box, "다리", _part_option_text("legs", legs_t), Color(0.72, 0.82, 1.0))
	if slot.state in ["on_mission", "returning"]:
		_add_option_line(opt_box, "행성", str(GameState.get_planet(slot.planet).get("name", slot.planet)), Color(0.78, 0.70, 1.0))
		_add_option_line(opt_box, "남은 시간", _mission_countdown(slot), Color(0.70, 1.0, 0.80))
	elif slot.state == "returned":
		_add_option_line(opt_box, "보상", "+%s CR" % _fmt(slot.credits_earned), Color(0.70, 1.0, 0.80))
	elif slot.state == "locked":
		_add_option_line(opt_box, "해금", "%s CR 필요" % _fmt(slot.unlock_cost), Color(0.90, 0.72, 0.48))

	return panel


func _build_action_panel(slot: DispatchManager.AutoSlot, accent: Color) -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(132, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 8)

	var spacer_top := Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(spacer_top)

	match slot.state:
		"empty":
			var build_btn := _make_action_button("조립 완료", _on_commit_assembly_pressed, accent)
			build_btn.disabled = not _can_commit_assembly()
			panel.add_child(build_btn)
		"offline":
			var repair_btn := _make_action_button("수리", _on_repair_pressed, accent.lightened(0.06))
			repair_btn.disabled = true
			panel.add_child(repair_btn)
			panel.add_child(_make_action_button("관제실 이동", _on_control_room_pressed, accent))
		"returned":
			panel.add_child(_make_action_button("수령", _on_collect_pressed, Color(0.26, 0.95, 0.46)))
		"locked":
			panel.add_child(_make_action_button("해금", _on_unlock_pressed, Color(0.90, 0.72, 0.48)))
		_:
			var note := Label.new()
			note.text = "조회 전용"
			note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			note.modulate = Color(0.52, 0.58, 0.72)
			panel.add_child(note)

	var spacer_bottom := Control.new()
	spacer_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(spacer_bottom)

	return panel


func _make_action_button(text: String, callback: Callable, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 30)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(callback)
	var sty := StyleBoxFlat.new()
	sty.bg_color = accent.darkened(0.30)
	sty.border_color = accent.lightened(0.10)
	sty.set_border_width_all(1)
	sty.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", sty)
	btn.add_theme_stylebox_override("hover", sty)
	btn.add_theme_stylebox_override("pressed", sty)
	btn.add_theme_stylebox_override("focus", sty)
	btn.modulate = Color(0.96, 0.98, 1.0)
	return btn


func _on_repair_pressed() -> void:
	pass


func _on_control_room_pressed() -> void:
	_request_control_room()


func _on_collect_pressed() -> void:
	GameState.collect_auto_slot(_slot_index)
	close_popup()


func _on_unlock_pressed() -> void:
	GameState.unlock_auto_slot(_slot_index)
	close_popup()


func _on_commit_assembly_pressed() -> void:
	if not _can_commit_assembly():
		return
	if not GameState.assemble_machine(_slot_index, _draft_machine.get("body", 0), _draft_machine.get("weapon", 0), _draft_machine.get("legs", 0)):
		return
	if _draft_pilot_id != "":
		GameState.assign_pilot_to_slot(_slot_index, _draft_pilot_id)
	_init_draft_state()
	_close_selector_and_refresh()


func _open_assembly(slot_index: int) -> void:
	GameState.hangar_preselect_slot = slot_index
	close_popup()
	PanelManager.show_panel("hangar_assembly")


func _request_control_room() -> void:
	close_popup()
	navigate_to_control_requested.emit()


func _build_equipment_slot(part_key: String, slot: DispatchManager.AutoSlot, accent: Color, pos: Vector2, caption: String) -> Control:
	var holder := Control.new()
	holder.position = pos
	holder.custom_minimum_size = Vector2(62, 54)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	holder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var sprite_frame := PanelContainer.new()
	sprite_frame.custom_minimum_size = Vector2(42, 34)
	sprite_frame.position = Vector2(10, 0)
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.08, 0.11, 0.16, 0.96)
	frame_style.border_color = _part_color(part_key, int(slot.machine.get(part_key, 0))).lightened(0.12)
	frame_style.set_border_width_all(1)
	frame_style.set_corner_radius_all(4)
	sprite_frame.add_theme_stylebox_override("panel", frame_style)
	holder.add_child(sprite_frame)

	var sprite := TextureRect.new()
	sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.texture = _part_sprite_texture(part_key, int(slot.machine.get(part_key, 0)))
	sprite.modulate = _part_color(part_key, int(slot.machine.get(part_key, 0))).lightened(0.35)
	sprite_frame.add_child(sprite)

	var fallback := Label.new()
	fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fallback.add_theme_font_size_override("font_size", 11)
	fallback.modulate = Color(1, 1, 1, 0.82)
	fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fallback.text = _part_short_text(part_key, int(slot.machine.get(part_key, 0)))
	sprite_frame.add_child(fallback)

	var name_lbl := Label.new()
	name_lbl.text = _part_display_name(slot, part_key, caption)
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.modulate = Color(0.82, 0.88, 1.0)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.position = Vector2(0, 38)
	name_lbl.custom_minimum_size = Vector2(62, 12)
	holder.add_child(name_lbl)

	if slot.state in ["empty", "offline"]:
		var btn := Button.new()
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.flat = true
		btn.text = ""
		btn.focus_mode = Control.FOCUS_NONE
		btn.modulate = Color(1, 1, 1, 0.01)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(func():
			_open_selector("part", part_key)
		)
		holder.add_child(btn)

	return holder


func _build_selector_panel() -> void:
	_selector_panel = PanelContainer.new()
	_selector_panel.anchor_left = 1.0
	_selector_panel.anchor_right = 1.0
	_selector_panel.anchor_top = 0.0
	_selector_panel.anchor_bottom = 1.0
	_selector_panel.offset_left = _selector_w
	_selector_panel.offset_right = _selector_w * 2.0
	_selector_panel.offset_top = 0.0
	_selector_panel.offset_bottom = 0.0
	_selector_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_selector_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.10, 0.98)
	style.border_color = Color(0.30, 0.42, 0.62, 0.90)
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_selector_panel.add_theme_stylebox_override("panel", style)
	add_child(_selector_panel)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	_selector_panel.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	root.add_child(header)

	var close_btn := Button.new()
	close_btn.text = "◀"
	close_btn.custom_minimum_size = Vector2(24, 24)
	close_btn.pressed.connect(func(): _hide_selector(true))
	header.add_child(close_btn)

	var title_lbl := Label.new()
	title_lbl.text = "선택"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.modulate = Color(0.80, 0.90, 1.0)
	header.add_child(title_lbl)

	var pad := Control.new()
	pad.custom_minimum_size = Vector2(24, 24)
	header.add_child(pad)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_selector_scroll = scroll
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root.add_child(scroll)

	_selector_body = VBoxContainer.new()
	_selector_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selector_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_selector_body.add_theme_constant_override("separation", 4)
	scroll.add_child(_selector_body)


func _init_draft_state() -> void:
	# 이전 베이 오염 방지: 반드시 먼저 초기화
	_draft_pilot_id = ""
	_draft_machine = {"body": 0, "weapon": 0, "legs": 0}
	if _slot_index < 0 or _slot_index >= GameState.auto_slots.size():
		return
	var slot: DispatchManager.AutoSlot = GameState.auto_slots[_slot_index]
	if slot.state != "empty":
		_draft_machine = slot.machine.duplicate()
		_draft_pilot_id = slot.pilot_id if slot.pilot_id != "" else slot.assigned_pilot_id
	else:
		if not slot.pending_machine.is_empty():
			_draft_machine = slot.pending_machine.duplicate()
		if slot.pending_pilot_id != "":
			_draft_pilot_id = slot.pending_pilot_id
		elif slot.assigned_pilot_id != "":
			_draft_pilot_id = slot.assigned_pilot_id


func _flush_draft_to_slot() -> void:
	if _slot_index < 0 or _slot_index >= GameState.auto_slots.size():
		return
	var slot: DispatchManager.AutoSlot = GameState.auto_slots[_slot_index]
	if slot.state != "empty":
		return
	var has_any := _draft_machine.values().any(func(v): return int(v) > 0)
	slot.pending_machine = _draft_machine.duplicate() if has_any else {}
	slot.pending_pilot_id = _draft_pilot_id
	GameState.auto_slot_changed.emit(_slot_index)


func _open_selector(kind: String, part_key: String) -> void:
	_selector_kind = kind
	_selector_part_key = part_key
	_update_selector_state()
	_show_selector()


func _update_selector_state() -> void:
	if _selector_panel == null or _selector_body == null:
		return
	for child in _selector_body.get_children():
		child.queue_free()
	if not _selector_visible and _selector_kind == "":
		return
	var title := _selector_title_text()
	var header := _selector_panel.get_child(0) as VBoxContainer
	if header != null:
		var hbox := header.get_child(0) as HBoxContainer
		if hbox != null and hbox.get_child_count() > 1:
			var lbl := hbox.get_child(1) as Label
			if lbl != null:
				lbl.text = title
	if _selector_kind == "pilot":
		_build_pilot_selector()
	elif _selector_kind == "part":
		_build_part_selector(_selector_part_key)
	else:
		var note := Label.new()
		note.text = "선택 항목 없음"
		_selector_body.add_child(note)


func _selector_title_text() -> String:
	if _selector_kind == "pilot":
		return "파일럿 선택"
	if _selector_kind == "part":
		return "%s 선택" % _part_caption(_selector_part_key)
	return "선택"


func _show_selector() -> void:
	if _selector_panel == null:
		return
	_selector_visible = true
	_selector_panel.visible = true
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(_selector_panel, "offset_left", -_selector_w, 0.18)
	tween.parallel().tween_property(_selector_panel, "offset_right", 0.0, 0.18)


func _hide_selector(refresh: bool) -> void:
	if _selector_panel == null:
		return
	if _selector_visible:
		var tween := create_tween()
		tween.set_ease(Tween.EASE_IN)
		tween.set_trans(Tween.TRANS_SINE)
		tween.tween_property(_selector_panel, "offset_left", _selector_w, 0.16)
		tween.parallel().tween_property(_selector_panel, "offset_right", _selector_w * 2.0, 0.16)
		tween.tween_callback(func():
			_selector_panel.visible = false
		)
	_selector_visible = false
	_selector_kind = ""
	_selector_part_key = ""
	if refresh:
		_rebuild_content()


func _close_selector_and_refresh() -> void:
	_hide_selector(true)


func _build_pilot_selector() -> void:
	var header := Label.new()
	header.text = "대기 파일럿"
	header.modulate = Color(0.72, 0.78, 0.90)
	_selector_body.add_child(header)
	if _draft_pilot_id != "":
		_selector_body.add_child(_make_unequip_button(func(): _select_pilot("")))
	var pilots := GameState.get_idle_pilots()
	if pilots.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "대기 파일럿 없음"
		empty_lbl.modulate = Color(0.55, 0.60, 0.70)
		_selector_body.add_child(empty_lbl)
		return
	for p in pilots:
		var pid := str(p.get("id", ""))
		var cap_pid := pid
		var btn := Button.new()
		btn.text = "%s  ·  T%d" % [str(p.get("name", pid)), int(p.get("tier", 1))]
		btn.custom_minimum_size = Vector2(0, 30)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var is_current := cap_pid == _draft_pilot_id
		btn.pressed.connect(func():
			_select_pilot(cap_pid)
		)
		btn.modulate = Color(0.78, 0.88, 1.0) if is_current else Color(0.95, 0.98, 1.0)
		_selector_body.add_child(btn)


func _build_part_selector(part_key: String) -> void:
	var header := Label.new()
	header.text = "%s 인벤토리" % _part_caption(part_key)
	header.modulate = Color(0.72, 0.78, 0.90)
	_selector_body.add_child(header)
	if _slot_index >= 0 and _slot_index < GameState.auto_slots.size():
		var cap_key := part_key
		if _part_tier(GameState.auto_slots[_slot_index], part_key) > 0:
			_selector_body.add_child(_make_unequip_button(func(): _unequip_part(cap_key)))
	var items := []
	for item: Dictionary in GameState.part_inventory:
		if str(item.get("type", "")) == part_key:
			items.append(item)
	if items.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "보유 파츠 없음"
		empty_lbl.modulate = Color(0.55, 0.60, 0.70)
		_selector_body.add_child(empty_lbl)
		return
	for item: Dictionary in items:
		var tier := int(item.get("tier", 0))
		var iid := str(item.get("iid", ""))
		var cap_tier := tier
		var cap_iid := iid
		var btn := Button.new()
		btn.text = "%s  ·  T%d" % [_part_name(part_key, tier), tier]
		btn.custom_minimum_size = Vector2(0, 30)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func():
			_select_part(part_key, cap_tier, cap_iid)
		)
		if cap_tier == _part_tier(GameState.auto_slots[_slot_index], part_key):
			btn.modulate = Color(0.78, 0.88, 1.0)
		_selector_body.add_child(btn)


func _select_pilot(pilot_id: String) -> void:
	if _slot_index < 0 or _slot_index >= GameState.auto_slots.size():
		return
	var slot: DispatchManager.AutoSlot = GameState.auto_slots[_slot_index]
	if slot.state == "empty":
		_draft_pilot_id = pilot_id
		_hide_selector(true)
		return
	if GameState.assign_pilot_to_slot(_slot_index, pilot_id):
		_hide_selector(true)


func _select_part(part_key: String, tier: int, iid: String) -> void:
	if _slot_index < 0 or _slot_index >= GameState.auto_slots.size():
		return
	var slot: DispatchManager.AutoSlot = GameState.auto_slots[_slot_index]
	if slot.state == "empty":
		_draft_machine[part_key] = tier
		_rebuild_content()
		return
	if GameState.replace_machine_part(_slot_index, part_key, tier):
		_hide_selector(true)


func _make_unequip_button(callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = "장착 해제"
	btn.custom_minimum_size = Vector2(0, 30)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(callback)
	var sty := StyleBoxFlat.new()
	sty.bg_color = Color(0.28, 0.10, 0.08, 0.92)
	sty.border_color = Color(0.82, 0.38, 0.28, 0.88)
	sty.set_border_width_all(1)
	sty.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", sty)
	btn.add_theme_stylebox_override("hover", sty)
	btn.add_theme_stylebox_override("pressed", sty)
	btn.add_theme_stylebox_override("focus", sty)
	btn.modulate = Color(1.0, 0.68, 0.58)
	return btn


func _unequip_part(part_key: String) -> void:
	if _slot_index < 0 or _slot_index >= GameState.auto_slots.size():
		return
	var slot: DispatchManager.AutoSlot = GameState.auto_slots[_slot_index]
	if slot.state == "empty":
		_draft_machine[part_key] = 0
		_hide_selector(true)
		return
	if GameState.remove_machine_part(_slot_index, part_key):
		_hide_selector(true)


func _can_commit_assembly() -> bool:
	return _draft_pilot_id != "" and int(_draft_machine.get("body", 0)) > 0 and int(_draft_machine.get("weapon", 0)) > 0 and int(_draft_machine.get("legs", 0)) > 0


func _display_pilot_name(slot: DispatchManager.AutoSlot) -> String:
	if slot.state == "empty" and _draft_pilot_id != "":
		var pilot := GameState.get_hired_pilot(_draft_pilot_id)
		if not pilot.is_empty():
			return str(pilot.get("name", _draft_pilot_id))
	return _pilot_name(slot)


func _part_tier(slot: DispatchManager.AutoSlot, part_key: String) -> int:
	if slot.state == "empty":
		return int(_draft_machine.get(part_key, 0))
	return int(slot.machine.get(part_key, 0))


func _part_display_name(slot: DispatchManager.AutoSlot, part_key: String, fallback: String) -> String:
	var tier := _part_tier(slot, part_key)
	if tier <= 0:
		return fallback
	return _part_name(part_key, tier)


func _part_caption(part_key: String) -> String:
	match part_key:
		"body":
			return "몸통"
		"weapon":
			return "무기"
		"legs":
			return "다리"
		_:
			return part_key


func _add_info_line(parent: Control, text: String, font_size: int, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.modulate = color
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(lbl)


func _add_kv(parent: Control, key: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var key_lbl := Label.new()
	key_lbl.text = key
	key_lbl.add_theme_font_size_override("font_size", 10)
	key_lbl.modulate = Color(0.55, 0.60, 0.70)
	key_lbl.custom_minimum_size = Vector2(82, 0)
	row.add_child(key_lbl)

	var value_lbl := Label.new()
	value_lbl.text = value
	value_lbl.add_theme_font_size_override("font_size", 11)
	value_lbl.modulate = Color(0.88, 0.94, 1.0)
	value_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_lbl)


func _add_option_line(parent: Control, title: String, text: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 10)
	title_lbl.modulate = Color(0.60, 0.65, 0.76)
	title_lbl.custom_minimum_size = Vector2(52, 0)
	row.add_child(title_lbl)

	var text_lbl := Label.new()
	text_lbl.text = text
	text_lbl.add_theme_font_size_override("font_size", 10)
	text_lbl.modulate = color
	text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(text_lbl)


func _pilot_id(slot: DispatchManager.AutoSlot) -> String:
	if slot.state == "empty" and _draft_pilot_id != "":
		return _draft_pilot_id
	return slot.pilot_id if slot.pilot_id != "" else slot.assigned_pilot_id


func _pilot_data(slot: DispatchManager.AutoSlot) -> Dictionary:
	var pid := _pilot_id(slot)
	return GameState.get_hired_pilot(pid) if pid != "" else {}


func _pilot_name(slot: DispatchManager.AutoSlot) -> String:
	var pilot := _pilot_data(slot)
	var pid := _pilot_id(slot)
	if pilot.is_empty():
		return "미배정"
	return str(pilot.get("name", pid))


func _pilot_tier(slot: DispatchManager.AutoSlot) -> int:
	var pilot := _pilot_data(slot)
	return int(pilot.get("tier", 0))


func _pilot_bonus_text(slot: DispatchManager.AutoSlot) -> String:
	var pilot := _pilot_data(slot)
	if pilot.is_empty():
		return "파일럿 없음"
	var bonus_type := str(pilot.get("bonus_type", "none"))
	var bonus_value := int(pilot.get("bonus_value", 0))
	match bonus_type:
		"speed":
			return "보너스 파견 시간 -%d%%" % bonus_value
		"credits":
			return "보너스 수익 +%d%%" % bonus_value
		_:
			return "보너스 없음"


func _pilot_caption(slot: DispatchManager.AutoSlot) -> String:
	var pilot := _pilot_data(slot)
	if pilot.is_empty():
		return "NO\nPILOT"
	return str(pilot.get("name", "PILOT")).to_upper()


func _pilot_color(slot: DispatchManager.AutoSlot) -> Color:
	var pilot := _pilot_data(slot)
	if pilot.is_empty():
		return Color(0.18, 0.24, 0.32)
	var hex := str(pilot.get("portrait_color", "#5D87B2"))
	return Color.from_string(hex, Color(0.36, 0.52, 0.70))


func _pilot_status_text(slot: DispatchManager.AutoSlot) -> String:
	if slot.state == "locked":
		return "잠금"
	if slot.state == "empty":
		var has_parts := _draft_machine.values().any(func(v): return int(v) > 0)
		if not has_parts:
			return "기체 없음"
		return "조립 대기" if _can_commit_assembly() else "조립중"
	var pilot := _pilot_data(slot)
	if pilot.is_empty():
		return "파일럿 없음"
	var status := str(pilot.get("status", "idle"))
	match status:
		"idle":
			return "대기 중"
		"on_mission":
			return "파견 중"
		"returned":
			return "귀환 완료"
		_:
			return status


func _slot_preview(slot: DispatchManager.AutoSlot) -> Dictionary:
	var b: int = int(slot.machine.get("body", 0))
	var w: int = int(slot.machine.get("weapon", 0))
	var l: int = int(slot.machine.get("legs", 0))
	if b <= 0 or w <= 0 or l <= 0:
		return {
			"mission_time": 0.0,
			"return_time": 0.0,
			"credits": 0,
			"rate": 0,
		}
	return GameState.get_machine_preview(b, w, l)


func _format_time(seconds: float) -> String:
	var total := maxi(0, int(round(seconds)))
	var m := total / 60
	var s := total % 60
	return "%02d:%02d" % [m, s]


func _mission_countdown(slot: DispatchManager.AutoSlot) -> String:
	var now := Time.get_unix_time_from_system()
	if slot.state == "on_mission":
		return _format_time(maxf(0.0, slot.mission_end_time - now))
	if slot.state == "returning":
		return _format_time(maxf(0.0, slot.return_end_time - now))
	return "00:00"


func _part_name(part_key: String, tier: int) -> String:
	if tier <= 0:
		return "미장착"
	var part: Dictionary = PartsData.DICT.get(part_key, {}) as Dictionary
	if part.is_empty():
		return "알 수 없음"
	var tiers: Array = part.get("tiers", []) as Array
	if tier < 1 or tier > tiers.size():
		return "알 수 없음"
	var tier_data: Dictionary = tiers[tier - 1] as Dictionary
	return str(tier_data.get("name", "알 수 없음"))


func _part_effect_text(part_key: String, tier: int) -> String:
	if tier <= 0:
		return "슬롯 비어 있음"
	var part: Dictionary = PartsData.DICT.get(part_key, {}) as Dictionary
	if part.is_empty():
		return "효과 정보 없음"
	var tiers: Array = part.get("tiers", []) as Array
	if tier < 1 or tier > tiers.size():
		return "효과 정보 없음"
	var data: Dictionary = tiers[tier - 1] as Dictionary
	var effect: String = str(part.get("effect", ""))
	var value: int = int(data.get("value", 0))
	return effect % value


func _part_short_text(part_key: String, tier: int) -> String:
	if tier <= 0:
		return "EMPTY"
	var abbr: String = "?"
	match part_key:
		"body":
			abbr = "B"
		"weapon":
			abbr = "W"
		"legs":
			abbr = "L"
	return "%s%d" % [abbr, tier]


func _part_option_text(part_key: String, tier: int) -> String:
	if tier <= 0:
		return "장착된 파츠가 없습니다."
	return "%s / %s" % [_part_name(part_key, tier), _part_effect_text(part_key, tier)]


func _part_color(part_key: String, tier: int) -> Color:
	if tier <= 0:
		return Color(0.12, 0.14, 0.20)
	var base := Color(0.20, 0.36, 0.58)
	match part_key:
		"body":
			base = Color(0.30, 0.42, 0.62)
		"weapon":
			base = Color(0.42, 0.30, 0.58)
		"legs":
			base = Color(0.28, 0.54, 0.38)
	return base.lightened(0.06 * minf(float(tier), 3.0))


func _part_sprite_texture(part_key: String, tier: int) -> Texture2D:
	# 아직 실제 파츠 아트가 연결되지 않았으므로 슬롯 전용 자리만 유지한다.
	# 나중에 파츠 타입/tier별 아이콘을 여기에 매핑하면 된다.
	return null


func _state_label(state: String) -> String:
	match state:
		"locked": return "잠금"
		"empty": return "머신 없음"
		"offline": return "도킹 중"
		"on_mission": return "파견 중"
		"returning": return "복귀 중"
		"returned": return "수령 대기"
		_: return state


func _border_color(state: String) -> Color:
	match state:
		"locked": return Color(0.33, 0.35, 0.48)
		"empty": return Color(0.34, 0.48, 0.62)
		"offline": return Color(0.55, 0.18, 0.18)
		"on_mission": return Color(0.28, 0.58, 0.95)
		"returning": return Color(0.95, 0.74, 0.20)
		"returned": return Color(0.26, 0.95, 0.46)
		_: return Color(0.45, 0.45, 0.55)


func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	for i: int in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return out
