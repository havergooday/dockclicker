class_name QuartersZone
extends Control

signal pilot_detail_requested(pilot_id: String, bed_idx: int, slot_idx: int)

const CARD_W     := 108
const CARD_H     := 108
const CARD_SEP   := 8
const BED_SEP    := 24   # 침대 간 구분선
const DRAG_THRESHOLD := 6.0

var _scroll_ref:   ScrollContainer = null
var _drag_start_x: float           = -1.0
var _drag_start_h: int             = 0
var _was_dragging: bool            = false
var _needs_rebuild: bool           = false

# 확인 상태
var _confirming_bed: int = -1


func _ready() -> void:
	GameState.quarters_changed.connect(func(): _needs_rebuild = true)
	GameState.pilot_hired.connect(func(_id): _needs_rebuild = true)
	_build()


func _process(_dt: float) -> void:
	if not visible or not _needs_rebuild: return
	_needs_rebuild = false
	_build()


func _input(event: InputEvent) -> void:
	if _scroll_ref == null or not visible: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var rect := Rect2(_scroll_ref.global_position, _scroll_ref.size)
			if rect.has_point(event.global_position):
				_drag_start_x = event.global_position.x
				_drag_start_h = _scroll_ref.scroll_horizontal
				_was_dragging = false
		else:
			if _was_dragging: get_viewport().set_input_as_handled()
			_drag_start_x = -1.0; _was_dragging = false
	elif event is InputEventMouseMotion and _drag_start_x >= 0.0:
		var delta: float = _drag_start_x - event.global_position.x
		if abs(delta) > DRAG_THRESHOLD:
			_was_dragging = true
			_scroll_ref.scroll_horizontal = _drag_start_h + int(delta)


# ── 빌드 ──────────────────────────────────────────────────────

func _build() -> void:
	for c in get_children(): c.queue_free()
	_scroll_ref = null

	# 배경
	var bg_sty := StyleBoxFlat.new()
	bg_sty.bg_color     = Color(0.04, 0.06, 0.10, 0.90)
	bg_sty.border_color = Color(0.22, 0.30, 0.48, 0.75)
	bg_sty.set_border_width_all(1)
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", bg_sty)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 헤더 영역 (50px)
	_build_header()

	# 그리드 영역
	var grid_area := Control.new()
	grid_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid_area.offset_top = 50.0
	grid_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grid_area)
	_build_grid(grid_area)


func _build_header() -> void:
	var cap := GameState.get_quarters_capacity()
	var cur := GameState.hired_pilots.size()

	var lbl := Label.new()
	lbl.text = "파일럿 숙소  %d / %d" % [cur, cap]
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.modulate = Color(0.62, 0.76, 0.92)
	lbl.anchor_left = 0.0; lbl.anchor_top = 0.0
	lbl.offset_left = 16.0; lbl.offset_top = 14.0
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)


func _build_grid(area: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	area.add_child(scroll)
	_scroll_ref = scroll

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(hbox)

	# 숙소는 격납고와 달리 우측→좌측 확장: 침대0이 우측, 잠긴 침대들이 좌측
	# 해금된 침대들을 오름차순, 잠긴 침대들을 그 앞(좌측)에 배치
	var beds: Array = GameState.quarters_beds
	var unlocked_beds: Array = []
	var locked_beds:   Array = []
	for i in beds.size():
		if not beds[i].get("locked", true): unlocked_beds.append(i)
		else:                               locked_beds.append(i)

	# 좌측 패딩 (침대0이 우측 끝에서 시작하도록)
	var lpad := Control.new()
	lpad.custom_minimum_size = Vector2(8, 0)
	lpad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(lpad)

	# 잠긴 침대 (좌측에 배치, 가장 높은 인덱스부터)
	var first := true
	for i in range(locked_beds.size() - 1, -1, -1):
		var b_idx: int = locked_beds[i]
		if not first: hbox.add_child(_make_sep())
		first = false
		hbox.add_child(_make_locked_bed(b_idx))

	# 해금된 침대 (낮은 인덱스 = 우측)
	for b_idx: int in unlocked_beds:
		if not first: hbox.add_child(_make_sep())
		first = false
		hbox.add_child(_make_bed_card(b_idx))

	var rpad := Control.new()
	rpad.custom_minimum_size = Vector2(8, 0)
	rpad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(rpad)


# ── 침대 카드 ─────────────────────────────────────────────────

func _make_bed_card(bed_idx: int) -> Control:
	var bed: Dictionary = GameState.quarters_beds[bed_idx]
	var slots: Array    = bed.get("slots", ["", ""])

	var con := Control.new()
	con.custom_minimum_size = Vector2(CARD_W, 0)
	con.size_flags_vertical = Control.SIZE_EXPAND_FILL
	con.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", CARD_SEP)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	con.add_child(vb)

	for s in 2:
		var pid: String = str(slots[s])
		vb.add_child(_make_slot_card(bed_idx, s, pid))

	return con


func _make_slot_card(bed_idx: int, slot_idx: int, pilot_id: String) -> Button:
	var is_top   := slot_idx == 0
	var occupied := pilot_id != ""
	var pilot: Dictionary = GameState.get_hired_pilot(pilot_id) if occupied else {}
	var is_mission := occupied and str(pilot.get("status", "")) == "on_mission"

	var col: Color = Color(0.38, 0.72, 0.48) if (occupied and not is_mission) \
		else Color(0.55, 0.65, 0.85) if is_mission \
		else Color(0.28, 0.36, 0.54)

	var btn := Button.new()
	btn.text = ""
	btn.custom_minimum_size = Vector2(CARD_W, CARD_H)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var sty := _slot_sty(col, false)
	var hov := _slot_sty(col, true)
	btn.add_theme_stylebox_override("normal",  sty)
	btn.add_theme_stylebox_override("hover",   hov)
	btn.add_theme_stylebox_override("pressed", sty)
	btn.add_theme_stylebox_override("focus",   sty)

	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 6.0; inner.offset_right = -6.0
	inner.offset_top  = 5.0; inner.offset_bottom = -5.0
	inner.add_theme_constant_override("separation", 3)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(inner)

	# 상단/하단 구분 태그
	var tier_lbl := Label.new()
	tier_lbl.text = "상단" if is_top else "하단"
	tier_lbl.add_theme_font_size_override("font_size", 7)
	tier_lbl.modulate = Color(0.40, 0.45, 0.58)
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tier_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(tier_lbl)

	if occupied:
		# 파일럿 초상화 영역
		var portrait := Panel.new()
		portrait.custom_minimum_size = Vector2(52, 52)
		portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		portrait.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var p_sty := StyleBoxFlat.new()
		var pcol := Color.html(str(pilot.get("portrait_color", "#4499DD")))
		p_sty.bg_color     = pcol.darkened(0.60)
		p_sty.border_color = pcol.darkened(0.20)
		p_sty.set_border_width_all(1); p_sty.set_corner_radius_all(3)
		portrait.add_theme_stylebox_override("panel", p_sty)

		var initial := Label.new()
		initial.text = str(pilot.get("name", "?")).substr(0, 1)
		initial.add_theme_font_size_override("font_size", 20)
		initial.modulate = pcol.lightened(0.30)
		initial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initial.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		initial.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.add_child(initial)
		inner.add_child(portrait)

		var name_lbl := Label.new()
		name_lbl.text = str(pilot.get("name", ""))
		name_lbl.add_theme_font_size_override("font_size", 8)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.clip_contents = true
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(name_lbl)

		var status_lbl := Label.new()
		status_lbl.text = "파견중" if is_mission else "대기"
		status_lbl.add_theme_font_size_override("font_size", 8)
		status_lbl.modulate = Color(0.55, 0.78, 1.0) if is_mission else Color(0.38, 1.00, 0.55)
		status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(status_lbl)

		var cap_pid := pilot_id; var cap_b := bed_idx; var cap_s := slot_idx
		btn.pressed.connect(func():
			if not _was_dragging:
				pilot_detail_requested.emit(cap_pid, cap_b, cap_s)
		)
	else:
		# 빈 슬롯
		var empty_lbl := Label.new()
		empty_lbl.text = "비어있음"
		empty_lbl.add_theme_font_size_override("font_size", 9)
		empty_lbl.modulate = Color(0.30, 0.36, 0.48)
		empty_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		empty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(empty_lbl)
		btn.mouse_default_cursor_shape = Control.CURSOR_ARROW

	return btn


func _make_locked_bed(bed_idx: int) -> Button:
	var bed: Dictionary  = GameState.quarters_beds[bed_idx]
	var cost: int        = int(bed.get("unlock_cost", 0))
	var can_afford: bool = GameState.total_credits >= cost
	var is_conf: bool    = _confirming_bed == bed_idx

	var btn := Button.new()
	btn.text = ""
	btn.custom_minimum_size = Vector2(CARD_W, CARD_H * 2 + CARD_SEP)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var sty := StyleBoxFlat.new()
	sty.bg_color     = Color(0.04, 0.06, 0.10, 0.96)
	sty.border_color = Color(0.40, 0.52, 0.70, 0.90) if is_conf else Color(0.22, 0.28, 0.42, 0.70)
	sty.set_border_width_all(2 if is_conf else 1); sty.set_corner_radius_all(6)
	for key in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(key, sty)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 8.0; vb.offset_right = -8.0
	vb.offset_top = 10.0; vb.offset_bottom = -10.0
	vb.add_theme_constant_override("separation", 6)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vb)

	if not is_conf:
		_add_lbl(vb, "🛏", 22, Color.WHITE)
		_add_lbl(vb, "침대 해금", 10, Color(0.50, 0.54, 0.68))
		_add_lbl(vb, "%s CR" % _fmt(cost), 10,
			Color(0.85, 0.75, 0.50) if can_afford else Color(0.90, 0.35, 0.35))
		btn.pressed.connect(func(): _confirming_bed = bed_idx; _build())
	else:
		_add_lbl(vb, "침대 해금?", 11, Color(0.75, 0.80, 0.95))
		_add_lbl(vb, "%s CR" % _fmt(cost), 13,
			Color(0.85, 0.75, 0.50) if can_afford else Color(0.90, 0.35, 0.35))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(row)
		var cancel := Button.new(); cancel.text = "✗"
		cancel.add_theme_font_size_override("font_size", 10)
		cancel.pressed.connect(func(): _confirming_bed = -1; _build())
		row.add_child(cancel)
		var confirm := Button.new(); confirm.text = "✓ 해금"
		confirm.add_theme_font_size_override("font_size", 10)
		confirm.disabled = not can_afford
		confirm.pressed.connect(func():
			GameState.unlock_bed(bed_idx)
			_confirming_bed = -1
		)
		row.add_child(confirm)
		btn.pressed.connect(func(): pass)

	return btn


func _make_sep() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(BED_SEP, 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := ColorRect.new()
	line.color = Color(0.25, 0.35, 0.55, 0.35)
	line.anchor_left  = 0.5; line.anchor_right  = 0.5
	line.anchor_top   = 0.0; line.anchor_bottom = 1.0
	line.offset_left  = -1;  line.offset_right  = 1
	line.offset_top   = 12;  line.offset_bottom = -12
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(line)
	return c


# ── 스타일 헬퍼 ───────────────────────────────────────────────

func _slot_sty(col: Color, hover: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color     = col.darkened(0.70).lightened(0.05 if hover else 0.0)
	s.border_color = col.darkened(0.25 if hover else 0.45)
	s.set_border_width_all(1); s.set_corner_radius_all(4)
	return s

func _add_lbl(parent: Control, text: String, size: int, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.modulate = col
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)

func _fmt(n: int) -> String:
	if n >= 1000000: return "%.1fM" % (float(n) / 1000000.0)
	if n >= 1000:    return "%.1fK" % (float(n) / 1000.0)
	return str(n)
