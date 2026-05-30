extends Control

# 침대 클릭 → 3파일럿 동시 표시 팝업 (항성지도 패턴)

signal pilot_detail_requested(pilot_id: String, bed_idx: int, slot_idx: int)

const POPUP_HEIGHT  := 220.0
const SLOTS_PER_BED := 3
const ANIM_DURATION := 0.20

var _main_panel: PanelContainer = null
var _content_vb: VBoxContainer  = null
var _bed_idx:    int            = -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	hide()


func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.40)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			close_popup()
	)
	add_child(overlay)

	_main_panel = PanelContainer.new()
	_main_panel.anchor_left   = 0.0
	_main_panel.anchor_top    = 0.0
	_main_panel.anchor_right  = 1.0
	_main_panel.anchor_bottom = 0.0
	_main_panel.offset_left   = 0.0
	_main_panel.offset_right  = 0.0
	_main_panel.offset_top    = -POPUP_HEIGHT
	_main_panel.offset_bottom = 0.0
	var sty := StyleBoxFlat.new()
	sty.bg_color     = Color(0.04, 0.06, 0.11, 0.98)
	sty.border_color = Color(0.28, 0.40, 0.62, 0.96)
	sty.set_border_width_all(1)
	sty.content_margin_left = 16; sty.content_margin_right  = 16
	sty.content_margin_top  = 10; sty.content_margin_bottom = 12
	_main_panel.add_theme_stylebox_override("panel", sty)
	add_child(_main_panel)

	_content_vb = VBoxContainer.new()
	_content_vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content_vb.add_theme_constant_override("separation", 8)
	_content_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_panel.add_child(_content_vb)


# ── 공개 API ──────────────────────────────────────────────────

func open(bed_idx: int) -> void:
	_bed_idx = bed_idx
	_rebuild()
	show()
	_main_panel.offset_top    = -POPUP_HEIGHT
	_main_panel.offset_bottom = 0.0
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_main_panel, "offset_top",    0.0,          ANIM_DURATION)
	tween.parallel().tween_property(_main_panel, "offset_bottom", POPUP_HEIGHT, ANIM_DURATION)


func close_popup() -> void:
	if not visible: return
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_main_panel, "offset_top",    -POPUP_HEIGHT, ANIM_DURATION)
	tween.parallel().tween_property(_main_panel, "offset_bottom", 0.0, ANIM_DURATION)
	tween.tween_callback(func(): hide())


# ── 콘텐츠 ────────────────────────────────────────────────────

func _rebuild() -> void:
	for c in _content_vb.get_children(): c.queue_free()

	if _bed_idx < 0 or _bed_idx >= GameState.quarters_beds.size():
		close_popup(); return

	var bed: Dictionary = GameState.quarters_beds[_bed_idx]
	var slots: Array    = bed.get("slots", ["", "", ""])

	# 헤더
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_vb.add_child(hdr)

	var title := Label.new()
	title.text = "침대 %d" % (_bed_idx + 1)
	title.add_theme_font_size_override("font_size", 14)
	title.modulate = Color(0.80, 0.90, 1.0)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "× 닫기"
	close_btn.flat = true
	close_btn.add_theme_color_override("font_color", Color(0.70, 0.80, 1.0))
	close_btn.pressed.connect(close_popup)
	hdr.add_child(close_btn)

	var sep := HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.10)
	_content_vb.add_child(sep)

	# 3 파일럿 카드 가로 배치
	var cards_hb := HBoxContainer.new()
	cards_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_hb.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	cards_hb.add_theme_constant_override("separation", 12)
	cards_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_vb.add_child(cards_hb)

	for s in SLOTS_PER_BED:
		var pid: String = str(slots[s]) if s < slots.size() else ""
		cards_hb.add_child(_make_pilot_card(s, pid))


func _make_pilot_card(slot_idx: int, pilot_id: String) -> Control:
	var occupied := pilot_id != ""
	var pilot: Dictionary = GameState.get_hired_pilot(pilot_id) if occupied else {}
	var is_mission := occupied and str(pilot.get("status", "")) == "on_mission"

	var border_col: Color
	if occupied and is_mission: border_col = Color(0.40, 0.60, 1.00)
	elif occupied:              border_col = Color(0.30, 0.75, 0.48)
	else:                       border_col = Color(0.20, 0.26, 0.40)

	var card := Button.new()
	card.text = ""
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if occupied \
		else Control.CURSOR_ARROW

	var sty := _card_sty(border_col, false)
	var hov := _card_sty(border_col, true)
	card.add_theme_stylebox_override("normal",  sty)
	card.add_theme_stylebox_override("hover",   hov if occupied else sty)
	card.add_theme_stylebox_override("pressed", sty)
	card.add_theme_stylebox_override("focus",   sty)

	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 10.0; inner.offset_right  = -10.0
	inner.offset_top  =  8.0; inner.offset_bottom =  -8.0
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 6)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)

	if occupied:
		var pcol := Color.html(str(pilot.get("portrait_color", "#4499DD")))

		var portrait := Panel.new()
		portrait.custom_minimum_size = Vector2(56, 56)
		portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ps := StyleBoxFlat.new()
		ps.bg_color = pcol.darkened(0.55); ps.border_color = pcol.darkened(0.20)
		ps.set_border_width_all(2); ps.set_corner_radius_all(8)
		portrait.add_theme_stylebox_override("panel", ps)
		var init_lbl := Label.new()
		init_lbl.text = str(pilot.get("name", "?")).substr(0, 1)
		init_lbl.add_theme_font_size_override("font_size", 22)
		init_lbl.modulate = pcol.lightened(0.25)
		init_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		init_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		init_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		init_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.add_child(init_lbl)
		inner.add_child(portrait)

		var name_lbl := Label.new()
		name_lbl.text = str(pilot.get("name", ""))
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.modulate = Color(0.88, 0.93, 1.0)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(name_lbl)

		var tier_lbl := Label.new()
		tier_lbl.text = "T%d" % int(pilot.get("tier", 1))
		tier_lbl.add_theme_font_size_override("font_size", 9)
		tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tier_lbl.modulate = Color(0.55, 0.68, 0.88)
		tier_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(tier_lbl)

		var status_lbl := Label.new()
		status_lbl.text = "파견 중" if is_mission else "대기"
		status_lbl.add_theme_font_size_override("font_size", 9)
		status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_lbl.modulate = Color(0.55, 0.78, 1.0) if is_mission else Color(0.38, 1.0, 0.55)
		status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(status_lbl)

		var cap_pid := pilot_id; var cap_s := slot_idx; var cap_b := _bed_idx
		card.pressed.connect(func():
			pilot_detail_requested.emit(cap_pid, cap_b, cap_s)
		)
	else:
		var empty_lbl := Label.new()
		empty_lbl.text = "비어있음"
		empty_lbl.add_theme_font_size_override("font_size", 10)
		empty_lbl.modulate = Color(0.28, 0.34, 0.46)
		empty_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		empty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(empty_lbl)

	return card


func _card_sty(col: Color, hover: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color     = col.darkened(0.75).lightened(0.06 if hover else 0.0)
	s.border_color = col.darkened(0.30 if hover else 0.50)
	s.set_border_width_all(1); s.set_corner_radius_all(6)
	return s
