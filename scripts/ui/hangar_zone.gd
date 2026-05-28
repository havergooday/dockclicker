class_name HangarZone
extends Control

signal navigate_to_control_requested

const CARD_W         := 108
const CARD_H         := 108
const CARD_SEP       := 8    # 격납고 내 카드 간격
const GROUP_SEP      := 24   # 격납고 간 구분선 너비
const DRAG_THRESHOLD := 6.0

var _layout_root:    Control         = null
var _scroll_ref:     ScrollContainer = null
var _popup_root:     Control         = null
var _drag_start_x:   float           = -1.0
var _drag_start_h:   int             = 0
var _was_dragging:   bool            = false
var _bay_scroll_pos: int             = 999999
var _needs_rebuild:  bool            = false

# 인라인 확인 상태 ("" | "hangar" | "bay")
var _confirming_type: String = ""
var _confirming_id:   int    = -1

# 오버레이 팝업 표시 중인 슬롯 (-1 = 없음)
var _popup_slot: int = -1


func _ready() -> void:
	GameState.auto_slot_changed.connect(func(_i): _needs_rebuild = true)
	GameState.auto_dispatch_returned.connect(func(_i): _needs_rebuild = true)
	GameState.slot_pilot_assigned.connect(func(_i): _needs_rebuild = true)
	_build()


func _process(_dt: float) -> void:
	if not visible or not _needs_rebuild:
		return
	_needs_rebuild = false
	var prev_popup := _popup_slot
	_build()
	if prev_popup >= 0:
		_show_popup(prev_popup)


func _input(event: InputEvent) -> void:
	if _scroll_ref == null or not visible or _popup_slot >= 0:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var rect := Rect2(_scroll_ref.global_position, _scroll_ref.size)
			if rect.has_point(event.global_position):
				_drag_start_x = event.global_position.x
				_drag_start_h = _scroll_ref.scroll_horizontal
				_was_dragging = false
		else:
			if _was_dragging:
				get_viewport().set_input_as_handled()
			_drag_start_x = -1.0
			_was_dragging = false
	elif event is InputEventMouseMotion and _drag_start_x >= 0.0:
		var delta: float = _drag_start_x - event.global_position.x
		if abs(delta) > DRAG_THRESHOLD:
			_was_dragging = true
			_scroll_ref.scroll_horizontal = _drag_start_h + int(delta)


# ── 레이아웃 빌드 ─────────────────────────────────────────────

func _build() -> void:
	if is_instance_valid(_layout_root):
		remove_child(_layout_root)
		_layout_root.queue_free()
	_scroll_ref   = null
	_drag_start_x = -1.0
	_was_dragging = false
	_popup_root   = null

	var root := Control.new()
	root.name = "HangarLayout"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_layout_root = root

	# 배경
	var bg_sty := StyleBoxFlat.new()
	bg_sty.bg_color     = Color(0.04, 0.06, 0.10, 0.88)
	bg_sty.border_color = Color(0.24, 0.36, 0.54, 0.75)
	bg_sty.set_border_width_all(1)
	bg_sty.border_width_right = 2
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", bg_sty)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	# 그리드 영역 (nav bar 아래)
	var grid_area := Control.new()
	grid_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid_area.offset_top = 50.0
	grid_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(grid_area)
	_build_grid(grid_area)

	# 팝업 오버레이 (그리드 위)
	var popup := Control.new()
	popup.name = "BayPopup"
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.offset_top = 50.0
	popup.visible = false
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(popup)
	_popup_root = popup


func _build_grid(area: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	area.add_child(scroll)
	_scroll_ref = scroll

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top",    10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.add_theme_constant_override("margin_left",   0)
	margin.add_theme_constant_override("margin_right",  0)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(hbox)

	var groups: Array = GameState.hangar_groups
	var num := groups.size()

	# 높은 인덱스(좌측)부터 0(우측) 순서로 추가
	for rev in num:
		var g_idx: int = num - 1 - rev
		if rev > 0:
			hbox.add_child(_make_sep())
		var group: DispatchManager.HangarGroup = groups[g_idx]
		if group.locked:
			hbox.add_child(_make_hangar_block(g_idx, group))
		else:
			hbox.add_child(_make_hangar_grid(g_idx))

	var rpad := Control.new()
	rpad.custom_minimum_size = Vector2(12, 0)
	rpad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(rpad)

	call_deferred("_restore_scroll")


func _restore_scroll() -> void:
	if is_instance_valid(_scroll_ref):
		_scroll_ref.scroll_horizontal = _bay_scroll_pos


# ── 격납고 구성 요소 ─────────────────────────────────────────

func _make_sep() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(GROUP_SEP, 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := ColorRect.new()
	line.color = Color(0.25, 0.35, 0.55, 0.35)
	line.anchor_left   = 0.5; line.anchor_right  = 0.5
	line.anchor_top    = 0.0; line.anchor_bottom = 1.0
	line.offset_left   = -1;  line.offset_right  = 1
	line.offset_top    = 12;  line.offset_bottom = -12
	line.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	c.add_child(line)
	return c


func _make_hangar_grid(g_idx: int) -> HBoxContainer:
	# 좌열: g*4+2, g*4+3 / 우열: g*4+0, g*4+1 (slot 0이 우측 상단)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", CARD_SEP)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(_make_bay_col(g_idx * 4 + 2, g_idx * 4 + 3))
	hb.add_child(_make_bay_col(g_idx * 4 + 0, g_idx * 4 + 1))
	return hb


func _make_bay_col(top_idx: int, bot_idx: int) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", CARD_SEP)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slots := GameState.auto_slots
	vb.add_child(_make_bay_card(top_idx) if top_idx < slots.size() else _make_placeholder())
	vb.add_child(_make_bay_card(bot_idx) if bot_idx < slots.size() else _make_placeholder())
	return vb


func _make_placeholder() -> Control:
	var ph := Control.new()
	ph.custom_minimum_size = Vector2(CARD_W, CARD_H)
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ph


# ── 잠긴 격납고 블록 ──────────────────────────────────────────

func _make_hangar_block(g_idx: int, group: DispatchManager.HangarGroup) -> Button:
	var W: float = CARD_W * 2 + CARD_SEP
	var H: float = CARD_H * 2 + CARD_SEP
	var is_conf: bool  = _confirming_type == "hangar" and _confirming_id == g_idx
	var can_afford: bool = GameState.total_credits >= group.unlock_cost

	var btn := Button.new()
	btn.text = ""
	btn.custom_minimum_size = Vector2(W, H)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var sty := StyleBoxFlat.new()
	sty.bg_color     = Color(0.04, 0.06, 0.10, 0.96)
	sty.border_color = Color(0.40, 0.52, 0.70, 0.90) if is_conf else Color(0.22, 0.28, 0.42, 0.70)
	sty.set_border_width_all(2 if is_conf else 1)
	sty.set_corner_radius_all(6)
	for key in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(key, sty)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 12; vb.offset_right = -12
	vb.offset_top  = 10; vb.offset_bottom = -10
	vb.add_theme_constant_override("separation", 6)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vb)

	if not is_conf:
		_add_lbl(vb, "🔒", 22, HORIZONTAL_ALIGNMENT_CENTER, Color.WHITE)
		_add_lbl(vb, "격납고 %d" % (g_idx + 1), 11, HORIZONTAL_ALIGNMENT_CENTER, Color(0.50, 0.54, 0.68))
		_add_lbl(vb, "%s CR" % _fmt(group.unlock_cost), 10, HORIZONTAL_ALIGNMENT_CENTER,
				Color(0.85, 0.75, 0.50) if can_afford else Color(0.90, 0.35, 0.35))
		btn.pressed.connect(func(): _set_confirming("hangar", g_idx))
	else:
		_add_lbl(vb, "격납고 %d 해금" % (g_idx + 1), 12, HORIZONTAL_ALIGNMENT_CENTER, Color(0.75, 0.80, 0.95))
		_add_lbl(vb, "%s CR" % _fmt(group.unlock_cost), 14, HORIZONTAL_ALIGNMENT_CENTER,
				Color(0.85, 0.75, 0.50) if can_afford else Color(0.90, 0.35, 0.35))
		vb.add_child(_vspacer())
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(row)
		var cancel_btn := Button.new()
		cancel_btn.text = "✗ 취소"
		cancel_btn.add_theme_font_size_override("font_size", 11)
		cancel_btn.pressed.connect(func(): _clear_confirming())
		row.add_child(cancel_btn)
		var confirm_btn := Button.new()
		confirm_btn.text = "✓ 해금"
		confirm_btn.add_theme_font_size_override("font_size", 11)
		confirm_btn.disabled = not can_afford
		confirm_btn.pressed.connect(func():
			GameState.unlock_hangar(g_idx)
			_clear_confirming()
		)
		row.add_child(confirm_btn)
		btn.pressed.connect(func(): pass)

	return btn


# ── 베이 카드 ─────────────────────────────────────────────────

func _make_bay_card(index: int) -> Button:
	var slots := GameState.auto_slots
	var slot: DispatchManager.AutoSlot = slots[index]
	var state: String  = slot.state
	var border_col     := _border_color(state)
	var glowing        := state == "returned"
	var is_conf        := _confirming_type == "bay" and _confirming_id == index

	var btn := Button.new()
	btn.text = ""
	btn.custom_minimum_size = Vector2(CARD_W, CARD_H)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var norm := _card_sty(border_col, false, glowing, is_conf)
	var hov  := _card_sty(border_col, true,  glowing, is_conf)
	btn.add_theme_stylebox_override("normal",   norm)
	btn.add_theme_stylebox_override("hover",    hov)
	btn.add_theme_stylebox_override("pressed",  norm)
	btn.add_theme_stylebox_override("disabled", norm)
	btn.add_theme_stylebox_override("focus",    norm)

	if glowing:
		var glow := ColorRect.new()
		glow.color = Color(border_col.r, border_col.g, border_col.b, 0.0)
		glow.set_anchors_preset(Control.PRESET_FULL_RECT)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(glow)
		var tw := glow.create_tween().set_loops()
		tw.tween_property(glow, "color:a", 0.08, 0.9)
		tw.tween_property(glow, "color:a", 0.0,  0.9)

	if state == "locked" and is_conf:
		_build_card_confirm(btn, slot, index)
	else:
		_build_card_content(btn, slot, state, border_col, index)

	return btn


func _build_card_content(btn: Button, slot: DispatchManager.AutoSlot,
		state: String, border_col: Color, index: int) -> void:
	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left   =  7.0; inner.offset_top    =  5.0
	inner.offset_right  = -7.0; inner.offset_bottom = -6.0
	inner.add_theme_constant_override("separation", 3)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(inner)

	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(top_row)

	var bay_lbl := Label.new()
	bay_lbl.text = "BAY %02d" % (index + 1)
	bay_lbl.add_theme_font_size_override("font_size", 7)
	bay_lbl.modulate = Color(0.40, 0.43, 0.52)
	bay_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bay_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(bay_lbl)

	var status_lbl := Label.new()
	status_lbl.text = _state_label(state)
	status_lbl.add_theme_font_size_override("font_size", 9)
	status_lbl.modulate = _status_color(state)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(status_lbl)

	var sprite_ph := Panel.new()
	sprite_ph.custom_minimum_size = Vector2(62, 62)
	sprite_ph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sprite_ph.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	sprite_ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ph_sty := StyleBoxFlat.new()
	ph_sty.bg_color     = _sprite_bg(slot.machine, state)
	ph_sty.border_color = border_col.darkened(0.38)
	ph_sty.set_border_width_all(1)
	ph_sty.set_corner_radius_all(3)
	sprite_ph.add_theme_stylebox_override("panel", ph_sty)
	inner.add_child(sprite_ph)

	if state == "locked":
		var lock_lbl := Label.new()
		lock_lbl.text = "🔒"
		lock_lbl.add_theme_font_size_override("font_size", 18)
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lock_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite_ph.add_child(lock_lbl)

	if state == "returned":
		var cr_lbl := Label.new()
		cr_lbl.text = "+ %s CR" % _fmt(slot.credits_earned)
		cr_lbl.add_theme_font_size_override("font_size", 10)
		cr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cr_lbl.modulate = Color(0.28, 1.00, 0.48)
		cr_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(cr_lbl)
	elif state == "locked":
		var cost_lbl := Label.new()
		cost_lbl.text = "%s CR" % _fmt(slot.unlock_cost)
		cost_lbl.add_theme_font_size_override("font_size", 10)
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cost_lbl.modulate = Color(0.50, 0.52, 0.62)
		cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(cost_lbl)
	elif state == "offline":
		var pilot_row := HBoxContainer.new()
		pilot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(pilot_row)
		var icon := Label.new()
		icon.text = "👤"
		icon.add_theme_font_size_override("font_size", 9)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pilot_row.add_child(icon)
		var name_lbl := Label.new()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 9)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if slot.assigned_pilot_id != "":
			var pilot := GameState.get_hired_pilot(slot.assigned_pilot_id)
			var pname: String = str(pilot.get("name", slot.assigned_pilot_id)) if not pilot.is_empty() else slot.assigned_pilot_id
			name_lbl.text = pname.substr(0, 5) if pname.length() > 5 else pname
			name_lbl.modulate = Color(0.65, 0.88, 1.0)
		else:
			name_lbl.text = "—"
			name_lbl.modulate = Color(0.55, 0.38, 0.38)
		pilot_row.add_child(name_lbl)

	if state == "locked":
		btn.pressed.connect(func(): _set_confirming("bay", index))
	else:
		btn.pressed.connect(func():
			if not _was_dragging:
				_show_popup(index)
		)


func _build_card_confirm(btn: Button, slot: DispatchManager.AutoSlot, index: int) -> void:
	var can_afford := GameState.total_credits >= slot.unlock_cost
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 8;  vb.offset_right  = -8
	vb.offset_top  = 6;  vb.offset_bottom = -6
	vb.add_theme_constant_override("separation", 4)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vb)

	_add_lbl(vb, "BAY %02d" % (index + 1), 9, HORIZONTAL_ALIGNMENT_CENTER, Color(0.60, 0.65, 0.80))
	_add_lbl(vb, "%s CR" % _fmt(slot.unlock_cost), 13, HORIZONTAL_ALIGNMENT_CENTER,
			Color(0.85, 0.75, 0.50) if can_afford else Color(0.90, 0.35, 0.35))
	vb.add_child(_vspacer())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(row)
	var cancel_btn := Button.new()
	cancel_btn.text = "✗"
	cancel_btn.add_theme_font_size_override("font_size", 11)
	cancel_btn.pressed.connect(func(): _clear_confirming())
	row.add_child(cancel_btn)
	var confirm_btn := Button.new()
	confirm_btn.text = "✓"
	confirm_btn.add_theme_font_size_override("font_size", 11)
	confirm_btn.disabled = not can_afford
	confirm_btn.pressed.connect(func():
		GameState.unlock_auto_slot(index)
		_clear_confirming()
	)
	row.add_child(confirm_btn)
	btn.pressed.connect(func(): pass)


# ── 인라인 확인 상태 ──────────────────────────────────────────

func _set_confirming(type: String, id: int) -> void:
	if _was_dragging:
		return
	_confirming_type = type
	_confirming_id   = id
	_rebuild_grid()


func _clear_confirming() -> void:
	_confirming_type = ""
	_confirming_id   = -1
	_rebuild_grid()


func _rebuild_grid() -> void:
	if is_instance_valid(_scroll_ref):
		_bay_scroll_pos = _scroll_ref.scroll_horizontal
	_needs_rebuild = true


# ── 오버레이 팝업 ────────────────────────────────────────────

func _show_popup(slot_idx: int) -> void:
	if not is_instance_valid(_popup_root):
		return
	_popup_slot = slot_idx
	for child in _popup_root.get_children():
		child.queue_free()

	# 딤 배경 (클릭 시 닫기)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.48)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_hide_popup()
	)
	_popup_root.add_child(dim)

	# 팝업 패널 (중앙)
	var panel := PanelContainer.new()
	panel.anchor_left   = 0.5; panel.anchor_right  = 0.5
	panel.anchor_top    = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left   = -190; panel.offset_right  = 190
	panel.offset_top    = -105; panel.offset_bottom = 105
	panel.mouse_filter  = Control.MOUSE_FILTER_STOP
	var psty := StyleBoxFlat.new()
	psty.bg_color     = Color(0.05, 0.07, 0.13, 0.97)
	psty.border_color = _border_color(GameState.auto_slots[slot_idx].state)
	psty.set_border_width_all(1)
	psty.border_width_top = 2
	psty.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", psty)
	_popup_root.add_child(panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 14; vb.offset_right  = -14
	vb.offset_top  = 10; vb.offset_bottom = -10
	vb.add_theme_constant_override("separation", 7)
	panel.add_child(vb)

	_build_popup_content(vb, slot_idx)
	_popup_root.visible = true


func _hide_popup() -> void:
	_popup_slot = -1
	if is_instance_valid(_popup_root):
		_popup_root.visible = false
		for child in _popup_root.get_children():
			child.queue_free()


func _build_popup_content(vb: VBoxContainer, slot_idx: int) -> void:
	var slot: DispatchManager.AutoSlot = GameState.auto_slots[slot_idx]
	var accent := _border_color(slot.state)

	# 헤더
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 6)
	vb.add_child(hdr)

	var title := Label.new()
	title.text = "BAY %02d" % (slot_idx + 1)
	title.add_theme_font_size_override("font_size", 13)
	title.modulate = Color(0.75, 0.80, 0.95)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(title)

	var state_lbl := Label.new()
	state_lbl.text = _state_label(slot.state)
	state_lbl.add_theme_font_size_override("font_size", 9)
	state_lbl.modulate = accent
	state_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hdr.add_child(state_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.custom_minimum_size = Vector2(22, 22)
	close_btn.pressed.connect(_hide_popup)
	hdr.add_child(close_btn)

	var div := ColorRect.new()
	div.color = Color(accent.r, accent.g, accent.b, 0.30)
	div.custom_minimum_size = Vector2(0, 1)
	div.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(div)

	match slot.state:
		"empty":                   _popup_empty(vb, slot_idx)
		"offline":                 _popup_offline(vb, slot, slot_idx)
		"on_mission", "returning": _popup_active(vb, slot)
		"returned":                _popup_returned(vb, slot, slot_idx)


func _popup_empty(vb: VBoxContainer, slot_idx: int) -> void:
	_add_lbl(vb, "머신 없음", 12, HORIZONTAL_ALIGNMENT_LEFT, Color(0.45, 0.45, 0.60))
	_add_lbl(vb, "이 베이에 배치된 머신이 없습니다.", 10, HORIZONTAL_ALIGNMENT_LEFT, Color(0.42, 0.44, 0.55))
	vb.add_child(_vspacer())
	var btn := Button.new()
	btn.text = "⚙ 공작실에서 조립하기"
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(func():
		GameState.workshop_preselect_slot = slot_idx
		_hide_popup()
		PanelManager.show_panel("workshop")
	)
	vb.add_child(btn)


func _popup_offline(vb: VBoxContainer, slot: DispatchManager.AutoSlot, slot_idx: int) -> void:
	var b: int = slot.machine.get("body",   0)
	var w: int = slot.machine.get("weapon", 0)
	var l: int = slot.machine.get("legs",   0)
	_add_lbl(vb, "몸체 T%d  ·  무기 T%d  ·  다리 T%d" % [b, w, l], 11,
			HORIZONTAL_ALIGNMENT_LEFT, Color(0.65, 0.70, 0.82))

	# 파일럿 배정
	var pilot_hdr := Label.new()
	pilot_hdr.text = "파일럿"
	pilot_hdr.add_theme_font_size_override("font_size", 9)
	pilot_hdr.modulate = Color(0.40, 0.42, 0.55)
	vb.add_child(pilot_hdr)

	var assigned_id := slot.assigned_pilot_id
	if assigned_id != "":
		var pilot := GameState.get_hired_pilot(assigned_id)
		var pname: String = str(pilot.get("name", assigned_id)) if not pilot.is_empty() else assigned_id
		_add_lbl(vb, "👤 " + pname, 11, HORIZONTAL_ALIGNMENT_LEFT, Color(0.65, 0.88, 1.0))
	else:
		_add_lbl(vb, "미배정", 11, HORIZONTAL_ALIGNMENT_LEFT, Color(0.72, 0.40, 0.40))

	var idle := GameState.get_idle_pilots()
	if not idle.is_empty():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		vb.add_child(row)
		for p in idle:
			var pid: String = str(p.get("id", ""))
			var pbtn := Button.new()
			pbtn.text = str(p.get("name", pid))
			pbtn.toggle_mode = true
			pbtn.button_pressed = (assigned_id == pid)
			pbtn.custom_minimum_size = Vector2(0, 22)
			pbtn.add_theme_font_size_override("font_size", 10)
			var cap_idx := slot_idx
			var cap_pid := pid
			var cap_aid := assigned_id
			pbtn.pressed.connect(func():
				var new_id := "" if cap_aid == cap_pid else cap_pid
				GameState.assign_pilot_to_slot(cap_idx, new_id)
				_hide_popup()
			)
			row.add_child(pbtn)
	elif assigned_id == "":
		_add_lbl(vb, "대기 파일럿 없음", 10, HORIZONTAL_ALIGNMENT_LEFT, Color(0.55, 0.35, 0.35))

	vb.add_child(_vspacer())

	var dispatch_btn := Button.new()
	dispatch_btn.text = "관제실에서 파견  ▶"
	dispatch_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dispatch_btn.pressed.connect(func():
		_hide_popup()
		navigate_to_control_requested.emit()
	)
	vb.add_child(dispatch_btn)

	var dis_btn := Button.new()
	dis_btn.text = "머신 분해"
	dis_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dis_btn.modulate = Color(1.0, 0.62, 0.62)
	var cap2 := slot_idx
	dis_btn.pressed.connect(func():
		GameState.disassemble_machine(cap2)
		_hide_popup()
	)
	vb.add_child(dis_btn)


func _popup_active(vb: VBoxContainer, slot: DispatchManager.AutoSlot) -> void:
	var b: int = slot.machine.get("body",   0)
	var w: int = slot.machine.get("weapon", 0)
	var l: int = slot.machine.get("legs",   0)
	_add_lbl(vb, "몸체 T%d  ·  무기 T%d  ·  다리 T%d" % [b, w, l], 11,
			HORIZONTAL_ALIGNMENT_LEFT, Color(0.65, 0.70, 0.82))

	if slot.pilot_id != "":
		var pilot := GameState.get_hired_pilot(slot.pilot_id)
		var pname: String = str(pilot.get("name", slot.pilot_id)) if not pilot.is_empty() else slot.pilot_id
		_add_lbl(vb, "👤 " + pname, 11, HORIZONTAL_ALIGNMENT_LEFT, Color(0.65, 0.88, 1.0))

	if slot.planet != "":
		var planet := GameState.get_planet(slot.planet)
		_add_lbl(vb, "→ " + str(planet.get("name", slot.planet)), 10,
				HORIZONTAL_ALIGNMENT_LEFT, Color(0.75, 0.65, 1.0))

	var preview := GameState.get_machine_preview(b, w, l)
	_add_lbl(vb, "예상 수익 %d CR" % preview["credits"], 10,
			HORIZONTAL_ALIGNMENT_LEFT, Color(0.50, 0.90, 0.55))

	vb.add_child(_vspacer())
	_add_lbl(vb, "임무 종료 후 자동 귀환합니다.", 9, HORIZONTAL_ALIGNMENT_LEFT, Color(0.42, 0.44, 0.55))


func _popup_returned(vb: VBoxContainer, slot: DispatchManager.AutoSlot, slot_idx: int) -> void:
	var cr_lbl := Label.new()
	cr_lbl.text = "+ %s CR" % _fmt(slot.credits_earned)
	cr_lbl.add_theme_font_size_override("font_size", 20)
	cr_lbl.modulate = Color(0.28, 1.00, 0.48)
	cr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cr_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(cr_lbl)

	vb.add_child(_vspacer())

	var btn := Button.new()
	btn.text = "수령  ▶"
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cap := slot_idx
	btn.pressed.connect(func():
		GameState.collect_auto_slot(cap)
		_hide_popup()
	)
	vb.add_child(btn)


# ── 헬퍼 ──────────────────────────────────────────────────────

func _vspacer() -> Control:
	var s := Control.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s


func _add_lbl(parent: Control, text: String, font_sz: int,
		align: HorizontalAlignment, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.horizontal_alignment = align
	lbl.modulate = col
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if align == HORIZONTAL_ALIGNMENT_LEFT:
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(lbl)


func _card_sty(col: Color, hover: bool, glowing: bool, selected: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	if selected:
		s.bg_color     = Color(0.08, 0.12, 0.22, 0.96)
		s.border_color = col.lightened(0.25)
		s.set_border_width_all(2)
	elif hover:
		s.bg_color     = Color(0.06, 0.09, 0.17, 0.96)
		s.border_color = col.lightened(0.18) if not glowing else col
		s.set_border_width_all(2 if glowing else 1)
	else:
		s.bg_color     = Color(0.04, 0.06, 0.13, 0.96)
		s.border_color = col if glowing else col.darkened(0.38)
		s.set_border_width_all(2 if glowing else 1)
	s.set_corner_radius_all(5)
	return s


func _status_color(state: String) -> Color:
	match state:
		"empty":      return Color(0.70, 0.72, 0.78)
		"offline":    return Color(0.72, 0.22, 0.22)
		"returned":   return Color(0.28, 1.00, 0.48)
		"on_mission": return Color(0.30, 0.62, 1.00)
		"returning":  return Color(1.00, 0.78, 0.22)
		"locked":     return Color(0.42, 0.44, 0.54)
		_:            return Color(0.60, 0.60, 0.65)


func _border_color(state: String) -> Color:
	match state:
		"locked":     return Color(0.33, 0.35, 0.48)
		"empty":      return Color(0.34, 0.48, 0.62)
		"offline":    return Color(0.55, 0.18, 0.18)
		"on_mission": return Color(0.28, 0.58, 0.95)
		"returning":  return Color(0.95, 0.74, 0.20)
		"returned":   return Color(0.26, 0.95, 0.46)
		_:            return Color(0.45, 0.45, 0.55)


func _state_label(state: String) -> String:
	match state:
		"locked":     return "LOCKED"
		"empty":      return "EMPTY"
		"offline":    return "OFFLINE"
		"on_mission": return "ON MISSION"
		"returning":  return "RETURNING"
		"returned":   return "RETURNED"
		_:            return state.to_upper()


func _sprite_bg(machine: Dictionary, state: String) -> Color:
	if machine.is_empty() or machine.get("body", 0) == 0:
		return Color(0.08, 0.10, 0.16)
	var avg: float = (int(machine.get("body", 1)) + int(machine.get("weapon", 1)) + int(machine.get("legs", 1))) / 3.0
	var base := Color(0.12, 0.24, 0.40).lerp(Color(0.10, 0.42, 0.62), (avg - 1.0) / 2.0)
	return base.darkened(0.45) if state in ["on_mission", "returning"] else base


func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	for i: int in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return out
