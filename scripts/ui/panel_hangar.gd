extends Control

@onready var back_button: Button = $BackButton

var _needs_rebuild: bool = false
var _scroll_ref: ScrollContainer = null
var _drag_start_x: float = -1.0
var _drag_start_h: int = 0
var _was_dragging: bool = false

const LEFT_ZONE_RATIO  := 0.20
const CARD_W           := 108
const CARD_H           := 108
const SPRITE_SZ        := 62
const COL_GAP          := 66
const ROW_GAP          := 12
const ROWS             := 2
const DRAG_THRESHOLD   := 6.0

func _ready() -> void:
	PanelManager.register_panel("hangar", self)
	back_button.pressed.connect(func(): PanelManager.go_back())
	_update_back_label()
	PanelManager.panel_changed.connect(func(id: String):
		if id == "hangar": _update_back_label()
	)
	GameState.auto_slot_changed.connect(func(_i): _needs_rebuild = true)
	GameState.auto_dispatch_returned.connect(func(_i): _needs_rebuild = true)
	visibility_changed.connect(func():
		if visible: _build_hangar()
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

	# 우측 2/3 영역
	var zone := Control.new()
	zone.name = "BayLayout"
	zone.anchor_left   = LEFT_ZONE_RATIO
	zone.anchor_top    = 0.0
	zone.anchor_right  = 1.0
	zone.anchor_bottom = 1.0
	zone.offset_left   = 0.0
	zone.offset_right  = 0.0
	zone.offset_top    = 0.0
	zone.offset_bottom = 0.0
	zone.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(zone)

	# 스크롤 컨테이너 — 스크롤바 숨김, 드래그로 이동
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	zone.add_child(scroll)
	_scroll_ref = scroll

	# 상하 여백을 명시적으로 고정 (SIZE_SHRINK_CENTER는 ScrollContainer 내부에서 불안정)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top",    32)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.add_theme_constant_override("margin_left",   0)
	margin.add_theme_constant_override("margin_right",  0)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(margin)

	# 열 컨테이너
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", COL_GAP)
	cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(cols)

	# 좌측 여백
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

	# 우측 여백
	var rpad := Control.new()
	rpad.custom_minimum_size = Vector2(28, 0)
	rpad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cols.add_child(rpad)

# ── 베이 카드 ─────────────────────────────────────────────────────

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
	var interactive: bool = state not in ["on_mission", "returning"]

	var btn := Button.new()
	btn.text = ""
	btn.custom_minimum_size = Vector2(CARD_W, CARD_H)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	btn.mouse_default_cursor_shape = \
		Control.CURSOR_POINTING_HAND if interactive else Control.CURSOR_ARROW

	var norm := _sty(border_col, false, glowing)
	var hov  := _sty(border_col, true,  glowing)
	btn.add_theme_stylebox_override("normal",   norm)
	btn.add_theme_stylebox_override("hover",    hov if interactive else norm)
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

	# 상단: 베이 번호 + 상태 텍스트
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

	# 하단 금액
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

	if interactive:
		match state:
			"locked":
				btn.pressed.connect(func(): GameState.unlock_auto_slot(index))
			"empty":
				btn.pressed.connect(func():
					GameState.workshop_preselect_slot = index
					PanelManager.show_panel("workshop")
				)
			"offline":
				btn.pressed.connect(func():
					GameState.dispatch_preselect_slot = index
					PanelManager.show_panel("dispatch")
				)
			"returned":
				btn.pressed.connect(func(): GameState.collect_auto_slot(index))

	return btn

# ── 헬퍼 ─────────────────────────────────────────────────────────

func _sty(col: Color, hover: bool, glowing: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color     = Color(0.06, 0.09, 0.17, 0.96) if hover else Color(0.04, 0.06, 0.13, 0.96)
	s.border_color = col if glowing else (col.lightened(0.18) if hover else col.darkened(0.38))
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
