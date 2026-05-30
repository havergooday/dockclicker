class_name QuartersZone
extends Control

signal bed_clicked(bed_idx: int)

# 침대 아이콘 배치 (4×2 그리드, 구역 내 가구처럼)
const ICON_W   := 120
const ICON_H   := 100
const COLS     := 4
const PAD_X    := 20   # 좌우 여백
const PAD_TOP  := 36   # 제목 아래
const ROW_GAP  := 12   # 행 간격

var _needs_rebuild: bool = false


func _ready() -> void:
	GameState.quarters_changed.connect(func(): _needs_rebuild = true)
	GameState.pilot_hired.connect(func(_id): _needs_rebuild = true)
	GameState.pilot_status_changed.connect(func(_id): _needs_rebuild = true)
	_build()


func _process(_dt: float) -> void:
	if not visible or not _needs_rebuild: return
	_needs_rebuild = false
	_build()


func _build() -> void:
	for c in get_children(): c.queue_free()

	# 배경
	var bg_sty := StyleBoxFlat.new()
	bg_sty.bg_color     = Color(0.04, 0.06, 0.10, 0.88)
	bg_sty.border_color = Color(0.22, 0.30, 0.48, 0.70)
	bg_sty.set_border_width_all(1)
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", bg_sty)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 제목
	var cap  := GameState.get_quarters_capacity()
	var cur  := GameState.hired_pilots.size()
	var title := Label.new()
	title.text = "파일럿 숙소  %d / %d" % [cur, cap]
	title.add_theme_font_size_override("font_size", 11)
	title.modulate = Color(0.52, 0.64, 0.82, 0.70)
	title.anchor_left = 0.0; title.anchor_top = 0.0
	title.offset_left = 14.0; title.offset_top = 8.0
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	# 침대 아이콘 배치
	var beds: Array = GameState.quarters_beds
	var total_row_w := COLS * ICON_W + (COLS - 1) * int(PAD_X * 0.6)
	var start_x := (1200 - total_row_w) / 2   # 구역 너비 1200 기준 중앙 정렬

	for i in beds.size():
		var col: int = i % COLS
		var row: int = i / COLS
		var bx: float = float(start_x + col * (ICON_W + int(PAD_X * 0.6)))
		var by: float = float(PAD_TOP + row * (ICON_H + ROW_GAP))
		add_child(_make_bed_icon(i, beds[i], bx, by))


func _make_bed_icon(bed_idx: int, bed: Dictionary, bx: float, by: float) -> Button:
	var locked: bool      = bed.get("locked", true)
	var slots: Array      = bed.get("slots", ["","",""])
	var cost: int         = int(bed.get("unlock_cost", 0))
	var can_afford: bool  = GameState.total_credits >= cost

	var occupied := 0
	for s in slots:
		if str(s) != "": occupied += 1

	var btn := Button.new()
	btn.text = ""
	btn.anchor_left = 0.0; btn.anchor_top    = 0.0
	btn.anchor_right = 0.0; btn.anchor_bottom = 0.0
	btn.offset_left  = bx;        btn.offset_top    = by
	btn.offset_right = bx + ICON_W; btn.offset_bottom = by + ICON_H
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var sty := StyleBoxFlat.new()
	if locked:
		sty.bg_color     = Color(0.04, 0.05, 0.09, 0.80)
		sty.border_color = Color(0.20, 0.26, 0.38, 0.55)
	else:
		sty.bg_color     = Color(0.06, 0.10, 0.18, 0.85)
		sty.border_color = Color(0.30, 0.44, 0.68, 0.75) if occupied > 0 \
			else Color(0.22, 0.30, 0.48, 0.55)
	sty.set_border_width_all(1); sty.set_corner_radius_all(6)
	var hov := sty.duplicate() as StyleBoxFlat
	hov.bg_color = sty.bg_color.lightened(0.08)
	hov.border_color = sty.border_color.lightened(0.15)
	for state in ["normal", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state, sty)
	btn.add_theme_stylebox_override("hover", hov)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 6.0; vb.offset_right  = -6.0
	vb.offset_top  = 6.0; vb.offset_bottom = -6.0
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vb)

	if locked:
		_add_lbl(vb, "🔒", 16, Color(0.40, 0.44, 0.54))
		_add_lbl(vb, _fmt(cost) + " CR", 9,
			Color(0.85, 0.75, 0.50) if can_afford else Color(0.80, 0.35, 0.35))
		btn.pressed.connect(func():
			if GameState.unlock_bed(bed_idx):
				pass  # quarters_changed 시그널로 자동 리빌드
		)
	else:
		_add_lbl(vb, "🛏", 18, Color(0.60, 0.75, 1.00))
		_add_lbl(vb, "침대 %d" % (bed_idx + 1), 10, Color(0.70, 0.80, 0.95))
		_add_lbl(vb, "%d / 3" % occupied, 9,
			Color(0.42, 0.85, 0.55) if occupied > 0 else Color(0.35, 0.42, 0.55))
		var cap_idx := bed_idx
		btn.pressed.connect(func(): bed_clicked.emit(cap_idx))

	return btn


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
