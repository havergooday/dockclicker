extends Control

const POPUP_HEIGHT := 300.0
const ANIM_DURATION := 0.20

var _main_panel:  PanelContainer = null
var _content_vb:  VBoxContainer  = null
var _move_vb:     VBoxContainer  = null

var _pilot_id: String = ""
var _bed_idx:  int    = -1
var _slot_idx: int    = -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	hide()


func _build_ui() -> void:
	# 딤 오버레이 (항성지도와 동일)
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.46)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			close_popup()
	)
	add_child(overlay)

	# 메인 패널 (항성지도와 동일한 anchor 구조)
	_main_panel = PanelContainer.new()
	_main_panel.anchor_left   = 0.0
	_main_panel.anchor_top    = 0.0
	_main_panel.anchor_right  = 1.0
	_main_panel.anchor_bottom = 0.0
	_main_panel.offset_left   = 0.0
	_main_panel.offset_right  = 0.0
	_main_panel.offset_top    = -POPUP_HEIGHT  # 숨김 상태
	_main_panel.offset_bottom = 0.0
	var sty := StyleBoxFlat.new()
	sty.bg_color     = Color(0.04, 0.06, 0.11, 0.98)
	sty.border_color = Color(0.28, 0.40, 0.62, 0.96)
	sty.set_border_width_all(1)
	sty.content_margin_left = 16; sty.content_margin_right  = 16
	sty.content_margin_top  = 10; sty.content_margin_bottom = 10
	_main_panel.add_theme_stylebox_override("panel", sty)
	add_child(_main_panel)

	_content_vb = VBoxContainer.new()
	_content_vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content_vb.add_theme_constant_override("separation", 8)
	_content_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_panel.add_child(_content_vb)


# ── 공개 API ──────────────────────────────────────────────────

func open(pilot_id: String, bed_idx: int, slot_idx: int) -> void:
	_pilot_id = pilot_id
	_bed_idx  = bed_idx
	_slot_idx = slot_idx
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
	_move_vb = null

	var pilot: Dictionary = GameState.get_hired_pilot(_pilot_id)
	if pilot.is_empty(): close_popup(); return

	# 헤더 행
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 12)
	hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_vb.add_child(hdr)

	var pcol := Color.html(str(pilot.get("portrait_color", "#4499DD")))
	var portrait := Panel.new()
	portrait.custom_minimum_size = Vector2(56, 56)
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
	hdr.add_child(portrait)

	var hdr_vb := VBoxContainer.new()
	hdr_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_vb.add_theme_constant_override("separation", 3)
	hdr_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr.add_child(hdr_vb)

	var name_lbl := Label.new()
	name_lbl.text = str(pilot.get("name", ""))
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.modulate = Color(0.90, 0.94, 1.0)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr_vb.add_child(name_lbl)

	var tier_lbl := Label.new()
	tier_lbl.text = "T%d 파일럿" % int(pilot.get("tier", 1))
	tier_lbl.add_theme_font_size_override("font_size", 11)
	tier_lbl.modulate = Color(0.55, 0.68, 0.88)
	tier_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr_vb.add_child(tier_lbl)

	var close_btn := Button.new()
	close_btn.text = "× 닫기"
	close_btn.flat = true
	close_btn.add_theme_color_override("font_color", Color(0.70, 0.80, 1.0))
	close_btn.pressed.connect(close_popup)
	hdr.add_child(close_btn)

	_content_vb.add_child(_hsep())

	# 정보 그리드
	var info_hb := HBoxContainer.new()
	info_hb.add_theme_constant_override("separation", 24)
	info_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_vb.add_child(info_hb)

	var left_vb := VBoxContainer.new()
	left_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vb.add_theme_constant_override("separation", 6)
	left_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_hb.add_child(left_vb)

	var status: String = str(pilot.get("status", "idle"))
	left_vb.add_child(_info_row("상태",
		"파견 중" if status == "on_mission" else "대기 중",
		Color(0.55, 0.78, 1.0) if status == "on_mission" else Color(0.38, 1.0, 0.55)))

	var bay_idx := _find_assigned_bay()
	left_vb.add_child(_info_row("배정 베이",
		"BAY %02d" % (bay_idx + 1) if bay_idx >= 0 else "없음",
		Color(0.75, 0.82, 1.0) if bay_idx >= 0 else Color(0.40, 0.46, 0.58)))

	left_vb.add_child(_info_row("숙소 위치",
		"침대 %d  %s" % [_bed_idx + 1, "상단" if _slot_idx == 0 else "하단"],
		Color(0.68, 0.75, 0.90)))

	var bonus_type: String = str(pilot.get("bonus_type", "none"))
	if bonus_type != "none":
		left_vb.add_child(_info_row("특성",
			_bonus_label(bonus_type, int(pilot.get("bonus_value", 0))),
			Color(0.50, 0.95, 0.68)))

	# 침대 이동 버튼 + 목록
	_content_vb.add_child(_hsep())

	var move_btn := Button.new()
	move_btn.text = "침대 이동"
	move_btn.custom_minimum_size = Vector2(120, 28)
	move_btn.add_theme_font_size_override("font_size", 11)
	move_btn.pressed.connect(func():
		if is_instance_valid(_move_vb) and _move_vb.visible:
			_move_vb.visible = false
		else:
			_build_move_list()
	)
	_content_vb.add_child(move_btn)

	_move_vb = VBoxContainer.new()
	_move_vb.add_theme_constant_override("separation", 4)
	_move_vb.visible = false
	_move_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_vb.add_child(_move_vb)


func _build_move_list() -> void:
	if _move_vb == null: return
	for c in _move_vb.get_children(): c.queue_free()

	var slots_row := HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", 6)
	slots_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_move_vb.add_child(slots_row)

	var any := false
	for b in GameState.quarters_beds.size():
		var bed: Dictionary = GameState.quarters_beds[b]
		if bed.get("locked", true): continue
		var slots: Array = bed.get("slots", ["", ""])
		for s in 2:
			if str(slots[s]) == _pilot_id: continue
			if str(slots[s]) != "": continue
			any = true
			var cap_b := b; var cap_s := s
			var btn := Button.new()
			btn.text = "침대%d %s" % [b + 1, "상" if s == 0 else "하"]
			btn.add_theme_font_size_override("font_size", 10)
			btn.custom_minimum_size = Vector2(72, 26)
			btn.pressed.connect(func():
				GameState.move_pilot_bed(_pilot_id, cap_b, cap_s)
				_bed_idx = cap_b; _slot_idx = cap_s
				_rebuild()
			)
			slots_row.add_child(btn)

	if not any:
		var lbl := Label.new()
		lbl.text = "이동 가능한 빈 슬롯 없음"
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.modulate = Color(0.65, 0.35, 0.35)
		_move_vb.add_child(lbl)

	_move_vb.visible = true


# ── 헬퍼 ──────────────────────────────────────────────────────

func _find_assigned_bay() -> int:
	for i in GameState.auto_slots.size():
		var s: DispatchManager.AutoSlot = GameState.auto_slots[i]
		if s.assigned_pilot_id == _pilot_id or s.pilot_id == _pilot_id:
			return i
	return -1

func _bonus_label(btype: String, bval: int) -> String:
	match btype:
		"credits_pct":       return "수익 +%d%%" % bval
		"dispatch_time_pct": return "파견 -%d%%" % bval
		"return_time_pct":   return "복귀 -%d%%" % bval
	return btype

func _info_row(label: String, value: String, val_col: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.modulate = Color(0.46, 0.52, 0.66)
	lbl.custom_minimum_size = Vector2(72, 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)
	var val := Label.new()
	val.text = value
	val.add_theme_font_size_override("font_size", 11)
	val.modulate = val_col
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(val)
	return row

func _hsep() -> HSeparator:
	var sep := HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.10)
	return sep
