class_name QuartersZone
extends Control

signal pilot_detail_requested(pilot_id: String, bed_idx: int, slot_idx: int)

const SLOTS_PER_BED   := 3
const BED_BTN_H       := 46
const BED_BTN_W       := 100
const SLOT_CARD_MAX_W := 280
const BED_SEP         := 8

var _selected_bed: int = -1   # 현재 선택된 침대 인덱스

var _bed_row:      HBoxContainer = null
var _slot_area:    Control       = null
var _needs_rebuild: bool         = false


func _ready() -> void:
	GameState.quarters_changed.connect(func(): _needs_rebuild = true)
	GameState.pilot_hired.connect(func(_id): _needs_rebuild = true)
	GameState.pilot_status_changed.connect(func(_id): _needs_rebuild = true)
	_build()


func _process(_dt: float) -> void:
	if not visible or not _needs_rebuild: return
	_needs_rebuild = false
	_build()


# ── 전체 빌드 ─────────────────────────────────────────────────

func _build() -> void:
	for c in get_children(): c.queue_free()
	_bed_row   = null
	_slot_area = null

	# 자동 선택: 없으면 첫 번째 해금 침대
	if _selected_bed < 0 or _is_bed_locked(_selected_bed):
		for b in GameState.quarters_beds.size():
			if not GameState.quarters_beds[b].get("locked", true):
				_selected_bed = b
				break

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

	# 상단 바 (침대 탭 + 정원 표시)
	_build_top_bar()

	# 하단 슬롯 뷰
	_slot_area = Control.new()
	_slot_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slot_area.offset_top = float(BED_BTN_H + 2)
	_slot_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_slot_area)
	_build_slot_view()


func _build_top_bar() -> void:
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.06, 0.09, 0.15, 0.85)
	bar_bg.anchor_left = 0.0; bar_bg.anchor_right  = 1.0
	bar_bg.anchor_top  = 0.0; bar_bg.anchor_bottom = 0.0
	bar_bg.offset_bottom = float(BED_BTN_H)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_bg)

	var bar := HBoxContainer.new()
	bar.anchor_left = 0.0; bar.anchor_right  = 1.0
	bar.anchor_top  = 0.0; bar.anchor_bottom = 0.0
	bar.offset_left = 10.0; bar.offset_right = -10.0
	bar.offset_top  = 4.0;  bar.offset_bottom = float(BED_BTN_H) - 4.0
	bar.add_theme_constant_override("separation", BED_SEP)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	_bed_row = bar

	# 정원 레이블
	var cap := GameState.get_quarters_capacity()
	var cur := GameState.hired_pilots.size()
	var cap_lbl := Label.new()
	cap_lbl.text = "숙소  %d / %d" % [cur, cap]
	cap_lbl.add_theme_font_size_override("font_size", 11)
	cap_lbl.modulate = Color(0.55, 0.68, 0.88)
	cap_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap_lbl.custom_minimum_size = Vector2(90, 0)
	cap_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(cap_lbl)

	# 구분선
	var sep := ColorRect.new()
	sep.color = Color(0.25, 0.35, 0.55, 0.45)
	sep.custom_minimum_size = Vector2(1, 0)
	sep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(sep)

	# 침대 탭 버튼들
	var beds: Array = GameState.quarters_beds
	for b in beds.size():
		var bed: Dictionary = beds[b]
		var locked: bool = bed.get("locked", true)
		var is_sel: bool = (b == _selected_bed)
		bar.add_child(_make_bed_tab(b, bed, locked, is_sel))


func _make_bed_tab(b_idx: int, bed: Dictionary, locked: bool, is_sel: bool) -> Button:
	var cost: int = int(bed.get("unlock_cost", 0))
	var can_afford: bool = GameState.total_credits >= cost

	var btn := Button.new()
	btn.text = ""
	btn.custom_minimum_size = Vector2(BED_BTN_W, 0)
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var norm := _tab_sty(is_sel, locked)
	var hov  := _tab_sty(true, locked)
	btn.add_theme_stylebox_override("normal",  norm)
	btn.add_theme_stylebox_override("hover",   hov)
	btn.add_theme_stylebox_override("pressed", norm)
	btn.add_theme_stylebox_override("focus",   norm)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vb)

	if locked:
		_add_lbl(vb, "🔒", 11, Color(0.50, 0.54, 0.62))
		_add_lbl(vb, _fmt(cost) + " CR", 8,
			Color(0.85, 0.75, 0.50) if can_afford else Color(0.80, 0.35, 0.35))
		btn.pressed.connect(func(): _try_unlock_bed(b_idx))
	else:
		# 점유 수 표시
		var slots: Array = bed.get("slots", [])
		var occupied := 0
		for s in slots:
			if str(s) != "": occupied += 1
		_add_lbl(vb, "침대 %d" % (b_idx + 1), 10,
			Color(0.85, 0.92, 1.0) if is_sel else Color(0.55, 0.62, 0.78))
		_add_lbl(vb, "%d / %d" % [occupied, SLOTS_PER_BED], 9,
			Color(0.42, 0.85, 0.55) if occupied > 0 else Color(0.38, 0.44, 0.56))
		btn.pressed.connect(func():
			_selected_bed = b_idx
			_build()
		)

	return btn


# ── 슬롯 뷰 ──────────────────────────────────────────────────

func _build_slot_view() -> void:
	if _slot_area == null: return

	if _selected_bed < 0:
		var hint := Label.new()
		hint.text = "침대를 선택하세요"
		hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", 12)
		hint.modulate = Color(0.30, 0.36, 0.50)
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_slot_area.add_child(hint)
		return

	var bed: Dictionary = GameState.quarters_beds[_selected_bed]
	var slots: Array    = bed.get("slots", ["", "", ""])

	# 3슬롯 가로 배치
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left  = 16.0; hbox.offset_right  = -16.0
	hbox.offset_top   = 10.0; hbox.offset_bottom = -10.0
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_area.add_child(hbox)

	for s in SLOTS_PER_BED:
		var pid: String = str(slots[s]) if s < slots.size() else ""
		hbox.add_child(_make_pilot_card(_selected_bed, s, pid))


func _make_pilot_card(bed_idx: int, slot_idx: int, pilot_id: String) -> Control:
	var occupied := pilot_id != ""
	var pilot: Dictionary = GameState.get_hired_pilot(pilot_id) if occupied else {}
	var is_mission := occupied and str(pilot.get("status", "")) == "on_mission"

	var card := Button.new()
	card.text = ""
	card.custom_minimum_size = Vector2(0, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical   = Control.SIZE_EXPAND_FILL

	var border_col: Color
	if occupied and is_mission:
		border_col = Color(0.40, 0.60, 1.00)
	elif occupied:
		border_col = Color(0.30, 0.75, 0.48)
	else:
		border_col = Color(0.22, 0.28, 0.42)

	var sty := _card_sty(border_col, false)
	var hov := _card_sty(border_col, true)
	card.add_theme_stylebox_override("normal",  sty)
	card.add_theme_stylebox_override("hover",   hov)
	card.add_theme_stylebox_override("pressed", sty)
	card.add_theme_stylebox_override("focus",   sty)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if occupied \
		else Control.CURSOR_ARROW

	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 10.0; inner.offset_right  = -10.0
	inner.offset_top  =  8.0; inner.offset_bottom =  -8.0
	inner.add_theme_constant_override("separation", 6)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)

	if occupied:
		var pcol := Color.html(str(pilot.get("portrait_color", "#4499DD")))

		# 초상화
		var portrait := Panel.new()
		portrait.custom_minimum_size = Vector2(64, 64)
		portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ps := StyleBoxFlat.new()
		ps.bg_color = pcol.darkened(0.55); ps.border_color = pcol.darkened(0.20)
		ps.set_border_width_all(2); ps.set_corner_radius_all(8)
		portrait.add_theme_stylebox_override("panel", ps)
		var init_lbl := Label.new()
		init_lbl.text = str(pilot.get("name", "?")).substr(0, 1)
		init_lbl.add_theme_font_size_override("font_size", 26)
		init_lbl.modulate = pcol.lightened(0.25)
		init_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		init_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		init_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		init_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.add_child(init_lbl)
		inner.add_child(portrait)

		# 이름
		var name_lbl := Label.new()
		name_lbl.text = str(pilot.get("name", ""))
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.clip_contents = true
		name_lbl.modulate = Color(0.88, 0.93, 1.0)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(name_lbl)

		# 상태
		var status_lbl := Label.new()
		status_lbl.text = "파견 중" if is_mission else "대기"
		status_lbl.add_theme_font_size_override("font_size", 9)
		status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_lbl.modulate = Color(0.55, 0.78, 1.0) if is_mission else Color(0.38, 1.0, 0.55)
		status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(status_lbl)

		var cap_pid := pilot_id; var cap_b := bed_idx; var cap_s := slot_idx
		card.pressed.connect(func():
			pilot_detail_requested.emit(cap_pid, cap_b, cap_s)
		)
	else:
		# 빈 슬롯
		var slot_lbl := Label.new()
		slot_lbl.text = "비어있음"
		slot_lbl.add_theme_font_size_override("font_size", 10)
		slot_lbl.modulate = Color(0.28, 0.34, 0.46)
		slot_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		slot_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(slot_lbl)

	return card


# ── 침대 해금 ─────────────────────────────────────────────────

func _try_unlock_bed(bed_idx: int) -> void:
	if GameState.unlock_bed(bed_idx):
		_selected_bed = bed_idx
		# _build는 quarters_changed 시그널로 자동 트리거


func _is_bed_locked(b: int) -> bool:
	if b < 0 or b >= GameState.quarters_beds.size(): return true
	return GameState.quarters_beds[b].get("locked", true)


# ── 스타일 헬퍼 ───────────────────────────────────────────────

func _tab_sty(active: bool, locked: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	if locked:
		s.bg_color     = Color(0.04, 0.05, 0.09, 0.80)
		s.border_color = Color(0.22, 0.28, 0.40, 0.60)
	elif active:
		s.bg_color     = Color(0.10, 0.18, 0.34, 0.95)
		s.border_color = Color(0.38, 0.58, 1.00, 0.90)
	else:
		s.bg_color     = Color(0.06, 0.09, 0.16, 0.80)
		s.border_color = Color(0.25, 0.34, 0.52, 0.60)
	s.set_border_width_all(1); s.set_corner_radius_all(4)
	s.content_margin_left = 4; s.content_margin_right = 4
	return s

func _card_sty(col: Color, hover: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color     = col.darkened(0.75).lightened(0.06 if hover else 0.0)
	s.border_color = col.darkened(0.30 if hover else 0.50)
	s.set_border_width_all(1); s.set_corner_radius_all(6)
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
