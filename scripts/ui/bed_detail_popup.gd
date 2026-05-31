extends Control

const POPUP_W       := 660.0   # 파일럿 3명 카드 나란히
const POPUP_HEIGHT  := 280.0
const ANIM_DURATION := 0.20
const SLOTS_PER_BED := 3

var _main_panel: PanelContainer = null
var _content_vb: VBoxContainer  = null
var _bed_idx:    int            = -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	hide()


func _build_ui() -> void:
	# 딤 — pilot_detail_popup과 동일
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.46)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			close_popup()
	)
	add_child(overlay)

	# 패널 — pilot_detail_popup과 동일한 viewport 기준 중앙 정렬
	var vp_w := get_viewport_rect().size.x
	_main_panel = PanelContainer.new()
	_main_panel.anchor_left   = 0.0
	_main_panel.anchor_top    = 0.0
	_main_panel.anchor_right  = 0.0
	_main_panel.anchor_bottom = 0.0
	_main_panel.offset_left   = (vp_w - POPUP_W) * 0.5
	_main_panel.offset_right  = (vp_w + POPUP_W) * 0.5
	_main_panel.offset_top    = -POPUP_HEIGHT
	_main_panel.offset_bottom = 0.0
	var sty := StyleBoxFlat.new()
	sty.bg_color     = Color(0.04, 0.06, 0.11, 0.98)
	sty.border_color = Color(0.28, 0.40, 0.62, 0.96)
	sty.set_border_width_all(1)
	sty.content_margin_left = 16; sty.content_margin_right  = 16
	sty.content_margin_top  = 12; sty.content_margin_bottom = 14
	_main_panel.add_theme_stylebox_override("panel", sty)
	add_child(_main_panel)

	_content_vb = VBoxContainer.new()
	_content_vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content_vb.add_theme_constant_override("separation", 10)
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

	# 헤더 (pilot_detail_popup과 동일 스타일)
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_vb.add_child(hdr)

	var title := Label.new()
	title.text = "침대 %d" % (_bed_idx + 1)
	title.add_theme_font_size_override("font_size", 16)
	title.modulate = Color(0.90, 0.94, 1.0)
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
	cards_hb.add_theme_constant_override("separation", 10)
	cards_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_vb.add_child(cards_hb)

	for s in SLOTS_PER_BED:
		var pid: String = str(slots[s]) if s < slots.size() else ""
		cards_hb.add_child(_make_pilot_card(s, pid))


func _make_pilot_card(_slot_idx: int, pilot_id: String) -> Control:
	var occupied := pilot_id != ""
	var pilot: Dictionary = GameState.get_hired_pilot(pilot_id) if occupied else {}
	var is_mission := occupied and str(pilot.get("status", "")) == "on_mission"

	var border_col: Color
	if occupied and is_mission: border_col = Color(0.40, 0.60, 1.00)
	elif occupied:              border_col = Color(0.30, 0.75, 0.48)
	else:                       border_col = Color(0.20, 0.26, 0.40)

	# 클릭 없이 바로 상세 표시 — Control (not Button)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sty := _card_sty(border_col)
	card.add_theme_stylebox_override("panel", sty)

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
		ps.bg_color = pcol.darkened(0.55); ps.border_color = pcol.darkened(0.15)
		ps.set_border_width_all(2); ps.set_corner_radius_all(5)
		portrait.add_theme_stylebox_override("panel", ps)
		var init_lbl := Label.new()
		init_lbl.text = str(pilot.get("name", "?")).substr(0, 1)
		init_lbl.add_theme_font_size_override("font_size", 24)
		init_lbl.modulate = pcol.lightened(0.30)
		init_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		init_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		init_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		init_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.add_child(init_lbl)
		inner.add_child(portrait)

		_add_lbl(inner, str(pilot.get("name", "")),              11, Color(0.88, 0.93, 1.0))
		_add_lbl(inner, "T%d 파일럿" % int(pilot.get("tier", 1)), 9,  Color(0.55, 0.68, 0.88))

		var sep := HSeparator.new()
		sep.modulate = Color(1, 1, 1, 0.08)
		inner.add_child(sep)

		var status_col := Color(0.55, 0.78, 1.0) if is_mission else Color(0.38, 1.0, 0.55)
		_add_lbl(inner, "파견 중" if is_mission else "대기 중", 9, status_col)

		var bay_idx := _find_assigned_bay(pilot_id)
		_add_lbl(inner, "BAY %02d" % (bay_idx + 1) if bay_idx >= 0 else "베이 미배정",
			9, Color(0.68, 0.75, 0.90) if bay_idx >= 0 else Color(0.40, 0.46, 0.58))

		var bonus_type: String = str(pilot.get("bonus_type", "none"))
		if bonus_type != "none":
			_add_lbl(inner, _bonus_label(bonus_type, int(pilot.get("bonus_value", 0))),
				9, Color(0.50, 0.95, 0.68))

		var exp := int(pilot.get("exp", 0))
		var tier := int(pilot.get("tier", 1))
		if tier < 3:
			var threshold: int = GameState.EXP_PER_TIER[tier - 1]
			_add_lbl(inner, "EXP %d / %d" % [exp, threshold], 9, Color(0.70, 0.88, 1.0))
		else:
			_add_lbl(inner, "EXP %d  MAX" % exp, 9, Color(0.88, 0.68, 1.0))
		_add_lbl(inner, _living_state_label("피로", int(pilot.get("fatigue", 0))),
			9, _living_state_color("fatigue", int(pilot.get("fatigue", 0))))
		_add_lbl(inner, _living_state_label("스트레스", int(pilot.get("stress", 0))),
			9, _living_state_color("stress", int(pilot.get("stress", 0))))
		_add_lbl(inner, _living_state_label("기분", int(pilot.get("mood", 70))),
			9, _living_state_color("mood", int(pilot.get("mood", 70))))
		var personality := str(pilot.get("personality", ""))
		if personality != "":
			_add_lbl(inner, "성격  " + personality, 9, Color(0.62, 0.90, 0.68))
		var pref_regions: Array = pilot.get("preferred_regions", [])
		if not pref_regions.is_empty():
			var region_names := pref_regions.map(func(r: String) -> String: return _region_label(r))
			_add_lbl(inner, "선호  " + ", ".join(region_names), 9, Color(0.72, 0.82, 0.96))
	else:
		_add_lbl(inner, "비어있음", 10, Color(0.28, 0.34, 0.46))

	return card


# ── 헬퍼 ──────────────────────────────────────────────────────

func _find_assigned_bay(pilot_id: String) -> int:
	for i in GameState.auto_slots.size():
		var s: DispatchManager.AutoSlot = GameState.auto_slots[i]
		if s.assigned_pilot_id == pilot_id or s.pilot_id == pilot_id:
			return i
	return -1

func _bonus_label(btype: String, bval: int) -> String:
	match btype:
		"credits_pct":       return "수익 +%d%%" % bval
		"dispatch_time_pct": return "파견 -%d%%" % bval
		"return_time_pct":   return "복귀 -%d%%" % bval
	return btype


func _living_state_label(label: String, value: int) -> String:
	return "%s %d/100" % [label, clampi(value, 0, 100)]


func _living_state_color(state_id: String, value: int) -> Color:
	var v := clampi(value, 0, 100)
	match state_id:
		"fatigue", "stress":
			if v >= 70:
				return Color(1.0, 0.48, 0.38)
			if v >= 40:
				return Color(0.95, 0.78, 0.38)
			return Color(0.52, 0.88, 0.62)
		"mood":
			if v >= 70:
				return Color(0.52, 0.88, 1.0)
			if v >= 40:
				return Color(0.72, 0.76, 0.90)
			return Color(0.95, 0.58, 0.58)
	return Color(0.72, 0.76, 0.90)

func _region_label(region_id: String) -> String:
	match region_id:
		"scrap":      return "폐기 위성"
		"trade":      return "교역 항로"
		"city_ruins": return "버려진 도시"
		"bio":        return "생태 행성"
	return region_id


func _add_lbl(parent: Control, text: String, size: int, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.modulate = col
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)

func _card_sty(col: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color     = col.darkened(0.75)
	s.border_color = col.darkened(0.45)
	s.set_border_width_all(1); s.set_corner_radius_all(6)
	return s
