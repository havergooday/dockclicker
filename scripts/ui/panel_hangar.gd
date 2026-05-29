extends Control

@onready var back_button: Button = $BackButton

var _needs_rebuild: bool = false
var _scroll_ref: ScrollContainer = null
var _drag_start_x: float = -1.0
var _drag_start_h: int = 0
var _was_dragging: bool = false
var _selected_slot: int = -1
var _detail_open: bool = false
var _grid_zone:   Control = null
var _detail_zone: Control = null

const DETAIL_SPLIT   := 0.30
const CARD_W         := 108
const CARD_H         := 108
const SPRITE_SZ      := 62
const COL_GAP        := 66
const ROW_GAP        := 12
const ROWS           := 2
const DRAG_THRESHOLD := 6.0
const TWEEN_DUR      := 0.28


func _ready() -> void:
	PanelManager.register_panel("hangar", self)
	back_button.pressed.connect(func(): PanelManager.go_back())
	_update_back_label()
	PanelManager.panel_changed.connect(func(id: String):
		if id == "hangar": _update_back_label()
	)
	GameState.auto_slot_changed.connect(func(_i): _needs_rebuild = true)
	GameState.auto_dispatch_returned.connect(func(_i): _needs_rebuild = true)
	GameState.slot_pilot_assigned.connect(func(_i): _needs_rebuild = true)
	visibility_changed.connect(func():
		if visible:
			_build_hangar()
		else:
			_selected_slot = -1
			_detail_open = false
	)
	_build_hangar()


func _update_back_label() -> void:
	back_button.text = "← %s" % PanelManager.get_back_label()


func _process(_dt: float) -> void:
	if not visible or not _needs_rebuild:
		return
	_needs_rebuild = false
	_build_hangar()


func _input(event: InputEvent) -> void:
	if _scroll_ref == null or not visible:
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


# ── 레이아웃 ──────────────────────────────────────────────────────

func _build_hangar() -> void:
	var old := get_node_or_null("BayLayout")
	if old:
		remove_child(old)
		old.queue_free()
	_scroll_ref = null
	_drag_start_x = -1.0
	_was_dragging = false
	_grid_zone = null
	_detail_zone = null

	var root := Control.new()
	root.name = "BayLayout"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# BackButton을 BayLayout 위(최상단)에 유지
	move_child(back_button, get_child_count() - 1)

	var detail_right := DETAIL_SPLIT if _detail_open else 0.0
	var grid_left    := DETAIL_SPLIT if _detail_open else 0.0

	# Detail zone - 좌측, 기본 zero-width (숨김)
	_detail_zone = Control.new()
	_detail_zone.anchor_left   = 0.0
	_detail_zone.anchor_top    = 0.0
	_detail_zone.anchor_right  = detail_right
	_detail_zone.anchor_bottom = 1.0
	_detail_zone.visible       = _detail_open
	_detail_zone.mouse_filter  = Control.MOUSE_FILTER_PASS
	root.add_child(_detail_zone)

	# Grid zone - 기본 전체 너비, 상세 패널 열리면 우측으로 밀림
	_grid_zone = Control.new()
	_grid_zone.anchor_left   = grid_left
	_grid_zone.anchor_top    = 0.0
	_grid_zone.anchor_right  = 1.0
	_grid_zone.anchor_bottom = 1.0
	_grid_zone.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	root.add_child(_grid_zone)
	_build_grid(_grid_zone)

	if _detail_open:
		_rebuild_detail_content()


func _build_grid(zone: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	zone.add_child(scroll)
	_scroll_ref = scroll

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top",    32)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.add_theme_constant_override("margin_left",   0)
	margin.add_theme_constant_override("margin_right",  0)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(margin)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", COL_GAP)
	cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(cols)

	var lpad := Control.new()
	lpad.custom_minimum_size = Vector2(40, 0)
	lpad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cols.add_child(lpad)

	var slots := GameState.auto_slots
	var num_cols: int = ceili(float(slots.size()) / float(ROWS))
	for c in range(num_cols):
		var col_box := VBoxContainer.new()
		col_box.add_theme_constant_override("separation", ROW_GAP)
		col_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cols.add_child(col_box)
		for r in range(ROWS):
			var idx: int = c * ROWS + r
			if idx < slots.size():
				col_box.add_child(_make_bay_card(idx))
			else:
				col_box.add_child(_make_slot_placeholder())

	var rpad := Control.new()
	rpad.custom_minimum_size = Vector2(28, 0)
	rpad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cols.add_child(rpad)


func _rebuild_detail_content() -> void:
	if not is_instance_valid(_detail_zone):
		return
	for child in _detail_zone.get_children():
		child.queue_free()
	_build_detail_panel(_detail_zone)


func _rebuild_grid_content() -> void:
	if not is_instance_valid(_grid_zone):
		return
	for child in _grid_zone.get_children():
		child.queue_free()
	_scroll_ref = null
	_drag_start_x = -1.0
	_was_dragging = false
	_build_grid(_grid_zone)


# ── 상세 패널 ─────────────────────────────────────────────────────

func _build_detail_panel(zone: Control) -> void:
	var valid := _selected_slot >= 0 and _selected_slot < GameState.auto_slots.size()
	if not valid:
		return

	var slot: DispatchManager.AutoSlot = GameState.auto_slots[_selected_slot]
	var accent := _border_color(slot.state)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left   =  8
	panel.offset_right  = -8
	panel.offset_top    =  8
	panel.offset_bottom = -8

	var sty := StyleBoxFlat.new()
	sty.bg_color = Color(0.04, 0.06, 0.12, 0.92)
	sty.border_color = accent
	sty.set_border_width_all(1)
	sty.border_width_left = 3
	sty.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", sty)
	zone.add_child(panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left   = 10
	vb.offset_right  = -10
	vb.offset_top    = 10
	vb.offset_bottom = -10
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 6)
	vb.add_child(hdr)

	var bay_lbl := Label.new()
	bay_lbl.text = "BAY %02d" % (_selected_slot + 1)
	bay_lbl.add_theme_font_size_override("font_size", 13)
	bay_lbl.modulate = Color(0.70, 0.72, 0.85)
	bay_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(bay_lbl)

	var state_lbl := Label.new()
	state_lbl.text = _state_label(slot.state)
	state_lbl.add_theme_font_size_override("font_size", 9)
	state_lbl.modulate = accent
	state_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hdr.add_child(state_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.add_theme_font_size_override("font_size", 10)
	close_btn.custom_minimum_size = Vector2(22, 22)
	close_btn.flat = true
	close_btn.pressed.connect(_close_detail)
	hdr.add_child(close_btn)

	var div := ColorRect.new()
	div.color = Color(accent.r, accent.g, accent.b, 0.35)
	div.custom_minimum_size = Vector2(0, 1)
	div.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(div)

	match slot.state:
		"locked":                  _detail_locked(vb, slot)
		"empty":                   _detail_empty(vb)
		"offline":                 _detail_offline(vb, slot)
		"on_mission", "returning": _detail_active(vb, slot)
		"returned":                _detail_returned(vb, slot)


func _open_detail() -> void:
	_detail_open = true
	_detail_zone.visible = true
	_rebuild_detail_content()
	_rebuild_grid_content()
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(_detail_zone, "anchor_right", DETAIL_SPLIT, TWEEN_DUR)
	tw.parallel().tween_property(_grid_zone,   "anchor_left",  DETAIL_SPLIT, TWEEN_DUR)


func _close_detail() -> void:
	_detail_open = false
	var tw := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(_detail_zone, "anchor_right", 0.0, TWEEN_DUR * 0.85)
	tw.parallel().tween_property(_grid_zone,   "anchor_left",  0.0, TWEEN_DUR * 0.85)
	tw.tween_callback(func():
		_detail_zone.visible = false
		_selected_slot = -1
		_rebuild_grid_content()
	)


func _select_slot(index: int) -> void:
	if _selected_slot == index and _detail_open:
		_close_detail()
		return
	_selected_slot = index
	if not _detail_open:
		_open_detail()
	else:
		_rebuild_detail_content()
		_rebuild_grid_content()


# ── 상세 패널 내용 ─────────────────────────────────────────────────

func _detail_locked(vb: VBoxContainer, slot: DispatchManager.AutoSlot) -> void:
	var hint_lbl := Label.new()
	hint_lbl.text = "해금 비용"
	hint_lbl.add_theme_font_size_override("font_size", 10)
	hint_lbl.modulate = Color(0.50, 0.52, 0.62)
	vb.add_child(hint_lbl)

	var cr_lbl := Label.new()
	cr_lbl.text = "%s CR" % _fmt(slot.unlock_cost)
	cr_lbl.add_theme_font_size_override("font_size", 16)
	cr_lbl.modulate = Color(0.85, 0.75, 0.50)
	vb.add_child(cr_lbl)

	vb.add_child(_vspacer())

	var btn := Button.new()
	btn.text = "잠금 해제"
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.disabled = GameState.total_credits < slot.unlock_cost
	var idx := _selected_slot
	btn.pressed.connect(func(): GameState.unlock_auto_slot(idx))
	vb.add_child(btn)


func _detail_empty(vb: VBoxContainer) -> void:
	var lbl := Label.new()
	lbl.text = "머신 없음"
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.modulate = Color(0.45, 0.45, 0.60)
	vb.add_child(lbl)

	vb.add_child(_vspacer())

	var btn := Button.new()
	btn.text = "격납고 조립  ▶"
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var idx := _selected_slot
	btn.pressed.connect(func():
		GameState.hangar_preselect_slot = idx
		PanelManager.show_panel("hangar_assembly")
	)
	vb.add_child(btn)


func _detail_offline(vb: VBoxContainer, slot: DispatchManager.AutoSlot) -> void:
	var b: int = slot.machine.get("body", 0)
	var w: int = slot.machine.get("weapon", 0)
	var l: int = slot.machine.get("legs", 0)

	var spec_lbl := Label.new()
	spec_lbl.text = "몸체T%d · 무기T%d · 다리T%d" % [b, w, l]
	spec_lbl.add_theme_font_size_override("font_size", 10)
	spec_lbl.modulate = Color(0.65, 0.70, 0.82)
	vb.add_child(spec_lbl)

	var pilot_hdr := Label.new()
	pilot_hdr.text = "파일럿 배정"
	pilot_hdr.add_theme_font_size_override("font_size", 9)
	pilot_hdr.modulate = Color(0.40, 0.42, 0.55)
	vb.add_child(pilot_hdr)

	var assigned_id := slot.assigned_pilot_id
	if assigned_id != "":
		var pilot := GameState.get_hired_pilot(assigned_id)
		var pname := str(pilot.get("name", assigned_id)) if not pilot.is_empty() else assigned_id
		var lbl := Label.new()
		lbl.text = "👤 " + pname
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.modulate = Color(0.65, 0.88, 1.0)
		vb.add_child(lbl)
	else:
		var lbl := Label.new()
		lbl.text = "미배정"
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.modulate = Color(0.72, 0.40, 0.40)
		vb.add_child(lbl)

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
			var cap_idx := _selected_slot
			var cap_pid := pid
			var cap_aid := assigned_id
			pbtn.pressed.connect(func():
				var new_id := "" if cap_aid == cap_pid else cap_pid
				GameState.assign_pilot_to_slot(cap_idx, new_id)
			)
			row.add_child(pbtn)
	elif assigned_id == "":
		var no_lbl := Label.new()
		no_lbl.text = "대기 파일럿 없음"
		no_lbl.add_theme_font_size_override("font_size", 10)
		no_lbl.modulate = Color(0.55, 0.35, 0.35)
		vb.add_child(no_lbl)

	vb.add_child(_vspacer())

	var dispatch_btn := Button.new()
	dispatch_btn.text = "파견 관제로  ▶"
	dispatch_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cap_idx := _selected_slot
	dispatch_btn.pressed.connect(func():
		GameState.dispatch_preselect_slot = cap_idx
		PanelManager.show_panel("dispatch")
	)
	vb.add_child(dispatch_btn)

	var dis_btn := Button.new()
	dis_btn.text = "머신 분해"
	dis_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dis_btn.modulate = Color(1.0, 0.62, 0.62)
	var cap_idx2 := _selected_slot
	dis_btn.pressed.connect(func(): GameState.disassemble_machine(cap_idx2))
	vb.add_child(dis_btn)


func _detail_active(vb: VBoxContainer, slot: DispatchManager.AutoSlot) -> void:
	var b: int = slot.machine.get("body", 0)
	var w: int = slot.machine.get("weapon", 0)
	var l: int = slot.machine.get("legs", 0)

	var spec_lbl := Label.new()
	spec_lbl.text = "몸체T%d · 무기T%d · 다리T%d" % [b, w, l]
	spec_lbl.add_theme_font_size_override("font_size", 10)
	spec_lbl.modulate = Color(0.65, 0.70, 0.82)
	vb.add_child(spec_lbl)

	if slot.pilot_id != "":
		var pilot := GameState.get_hired_pilot(slot.pilot_id)
		var pname := str(pilot.get("name", slot.pilot_id)) if not pilot.is_empty() else slot.pilot_id
		var lbl := Label.new()
		lbl.text = "👤 " + pname
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.modulate = Color(0.65, 0.88, 1.0)
		vb.add_child(lbl)

	if slot.planet != "":
		var planet := GameState.get_planet(slot.planet)
		var lbl := Label.new()
		lbl.text = "→ " + str(planet.get("name", slot.planet))
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.modulate = Color(0.75, 0.65, 1.0)
		vb.add_child(lbl)

	var preview := GameState.get_machine_preview(b, w, l)
	var cr_lbl := Label.new()
	cr_lbl.text = "예상 수익 %d CR" % preview["credits"]
	cr_lbl.add_theme_font_size_override("font_size", 10)
	cr_lbl.modulate = Color(0.50, 0.90, 0.55)
	vb.add_child(cr_lbl)


func _detail_returned(vb: VBoxContainer, slot: DispatchManager.AutoSlot) -> void:
	var cr_lbl := Label.new()
	cr_lbl.text = "+ %s CR" % _fmt(slot.credits_earned)
	cr_lbl.add_theme_font_size_override("font_size", 18)
	cr_lbl.modulate = Color(0.28, 1.00, 0.48)
	vb.add_child(cr_lbl)

	vb.add_child(_vspacer())

	var btn := Button.new()
	btn.text = "수령  ▶"
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var idx := _selected_slot
	btn.pressed.connect(func(): GameState.collect_auto_slot(idx))
	vb.add_child(btn)


# ── 베이 카드 ──────────────────────────────────────────────────────

func _make_slot_placeholder() -> Control:
	var ph := Control.new()
	ph.custom_minimum_size = Vector2(CARD_W, CARD_H)
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ph


func _make_bay_card(index: int) -> Button:
	var slot: DispatchManager.AutoSlot = GameState.auto_slots[index]
	var state      := slot.state
	var border_col := _border_color(state)
	var glowing    := state == "returned"
	var is_sel     := index == _selected_slot

	var btn := Button.new()
	btn.text = ""
	btn.custom_minimum_size = Vector2(CARD_W, CARD_H)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var norm := _sty(border_col, false, glowing, is_sel)
	var hov  := _sty(border_col, true,  glowing, is_sel)
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

	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left   =  7.0
	inner.offset_top    =  5.0
	inner.offset_right  = -7.0
	inner.offset_bottom = -6.0
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

	# 스프라이트 영역
	# TODO: 파츠 조합 완성 스프라이트로 교체 예정 (missing-features.md 참고)
	var sprite_ph := Panel.new()
	sprite_ph.custom_minimum_size = Vector2(SPRITE_SZ, SPRITE_SZ)
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

		var icon_lbl := Label.new()
		icon_lbl.text = "👤"
		icon_lbl.add_theme_font_size_override("font_size", 9)
		icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pilot_row.add_child(icon_lbl)

		var name_lbl := Label.new()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 9)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if slot.assigned_pilot_id != "":
			var pilot := GameState.get_hired_pilot(slot.assigned_pilot_id)
			var pname := str(pilot.get("name", slot.assigned_pilot_id)) if not pilot.is_empty() else slot.assigned_pilot_id
			name_lbl.text = pname.substr(0, 5) if pname.length() > 5 else pname
			name_lbl.modulate = Color(0.65, 0.88, 1.0)
		else:
			name_lbl.text = "—"
			name_lbl.modulate = Color(0.55, 0.38, 0.38)
		pilot_row.add_child(name_lbl)

	btn.pressed.connect(func(): _select_slot(index))
	return btn


# ── 헬퍼 ──────────────────────────────────────────────────────────

func _vspacer() -> Control:
	var s := Control.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s


func _sty(col: Color, hover: bool, glowing: bool, selected: bool = false) -> StyleBoxFlat:
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
