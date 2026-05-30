extends Control

# 파일럿 상세 팝업 — shop_popup과 동일한 슬라이드다운 구조

const POPUP_W_RATIO := 0.42
const ANIM_DURATION := 0.20

var _panel:      Control       = null
var _content_vb: VBoxContainer = null
var _move_panel: Control       = null

var _pilot_id: String = ""
var _bed_idx:  int    = -1
var _slot_idx: int    = -1
var _popup_w:  float  = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)  # .new()로 생성되므로 직접 설정
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	_build_ui()


# ── UI 빌드 (최초 1회) ────────────────────────────────────────

func _build_ui() -> void:
	_popup_w = get_viewport_rect().size.x * POPUP_W_RATIO

	# 딤
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			close()
	)
	add_child(dim)

	# 슬라이드 패널 (shop_popup과 동일 구조)
	_panel = Control.new()
	_panel.anchor_left   = 0.5
	_panel.anchor_right  = 0.5
	_panel.anchor_top    = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left   = -_popup_w * 0.5
	_panel.offset_right  =  _popup_w * 0.5
	_panel.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var bg_sty := StyleBoxFlat.new()
	bg_sty.bg_color     = Color(0.07, 0.10, 0.15, 0.97)
	bg_sty.border_color = Color(0.26, 0.40, 0.62, 0.80)
	bg_sty.set_border_width_all(1)
	var panel_bg := PanelContainer.new()
	panel_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_bg.add_theme_stylebox_override("panel", bg_sty)
	panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(panel_bg)

	_content_vb = VBoxContainer.new()
	_content_vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content_vb.offset_left   = 24
	_content_vb.offset_right  = -24
	_content_vb.offset_top    = 14
	_content_vb.offset_bottom = -14
	_content_vb.add_theme_constant_override("separation", 10)
	_content_vb.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_content_vb)


# ── 공개 API ──────────────────────────────────────────────────

func open(pilot_id: String, bed_idx: int, slot_idx: int) -> void:
	_pilot_id = pilot_id
	_bed_idx  = bed_idx
	_slot_idx = slot_idx
	_rebuild()
	visible = true
	_panel.position.y = -_panel.size.y - 10.0
	var tween := create_tween()
	tween.tween_property(_panel, "position:y", 0.0, ANIM_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func close() -> void:
	var tween := create_tween()
	tween.tween_property(_panel, "position:y", -_panel.size.y - 10.0, ANIM_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): visible = false)


# ── 콘텐츠 재구성 ────────────────────────────────────────────

func _rebuild() -> void:
	for c in _content_vb.get_children(): c.queue_free()
	_move_panel = null

	var pilot: Dictionary = GameState.get_hired_pilot(_pilot_id)
	if pilot.is_empty(): close(); return

	# 헤더 (초상화 + 이름 + 닫기)
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 12)
	_content_vb.add_child(hdr)

	var pcol := Color.html(str(pilot.get("portrait_color", "#4499DD")))
	var portrait := Panel.new()
	portrait.custom_minimum_size = Vector2(64, 64)
	var ps := StyleBoxFlat.new()
	ps.bg_color = pcol.darkened(0.55); ps.border_color = pcol.darkened(0.15)
	ps.set_border_width_all(2); ps.set_corner_radius_all(6)
	portrait.add_theme_stylebox_override("panel", ps)
	var init_lbl := Label.new()
	init_lbl.text = str(pilot.get("name", "?")).substr(0, 1)
	init_lbl.add_theme_font_size_override("font_size", 28)
	init_lbl.modulate = pcol.lightened(0.30)
	init_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	init_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	init_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	portrait.add_child(init_lbl)
	hdr.add_child(portrait)

	var hdr_vb := VBoxContainer.new()
	hdr_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_vb.add_theme_constant_override("separation", 4)
	hdr.add_child(hdr_vb)

	var name_lbl := Label.new()
	name_lbl.text = str(pilot.get("name", ""))
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.modulate = Color(0.90, 0.94, 1.0)
	hdr_vb.add_child(name_lbl)

	var tier_lbl := Label.new()
	tier_lbl.text = "T%d 파일럿" % int(pilot.get("tier", 1))
	tier_lbl.add_theme_font_size_override("font_size", 11)
	tier_lbl.modulate = Color(0.55, 0.68, 0.88)
	hdr_vb.add_child(tier_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.pressed.connect(close)
	hdr.add_child(close_btn)

	_content_vb.add_child(_hsep())

	# 정보 행들
	var status: String = str(pilot.get("status", "idle"))
	_content_vb.add_child(_info_row("상태",
		"파견 중" if status == "on_mission" else "대기 중",
		Color(0.55, 0.78, 1.0) if status == "on_mission" else Color(0.38, 1.0, 0.55)))

	var bay_idx := _find_assigned_bay()
	_content_vb.add_child(_info_row("배정 베이",
		"BAY %02d" % (bay_idx + 1) if bay_idx >= 0 else "없음",
		Color(0.75, 0.82, 1.0) if bay_idx >= 0 else Color(0.40, 0.46, 0.58)))

	_content_vb.add_child(_info_row("숙소",
		"침대 %d  %s" % [_bed_idx + 1, "상단" if _slot_idx == 0 else "하단"],
		Color(0.68, 0.75, 0.90)))

	var bonus_type: String = str(pilot.get("bonus_type", "none"))
	if bonus_type != "none":
		_content_vb.add_child(_hsep())
		_content_vb.add_child(_info_row("특성",
			_bonus_label(bonus_type, int(pilot.get("bonus_value", 0))),
			Color(0.50, 0.95, 0.68)))

	_content_vb.add_child(_hsep())

	# 침대 이동 버튼
	var move_btn := Button.new()
	move_btn.text = "침대 이동"
	move_btn.custom_minimum_size = Vector2(0, 34)
	move_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	move_btn.pressed.connect(func():
		if is_instance_valid(_move_panel) and _move_panel.visible:
			_move_panel.visible = false
		else:
			_show_move_panel()
	)
	_content_vb.add_child(move_btn)

	# 이동 슬롯 목록 컨테이너
	_move_panel = VBoxContainer.new()
	_move_panel.add_theme_constant_override("separation", 4)
	_move_panel.visible = false
	_move_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_vb.add_child(_move_panel)


func _show_move_panel() -> void:
	if _move_panel == null: return
	for c in _move_panel.get_children(): c.queue_free()

	var hint := Label.new()
	hint.text = "이동할 슬롯을 선택하세요"
	hint.add_theme_font_size_override("font_size", 10)
	hint.modulate = Color(0.50, 0.56, 0.72)
	_move_panel.add_child(hint)

	var any_avail := false
	for b in GameState.quarters_beds.size():
		var bed: Dictionary = GameState.quarters_beds[b]
		if bed.get("locked", true): continue
		var slots: Array = bed.get("slots", ["", ""])
		for s in 2:
			if str(slots[s]) == _pilot_id: continue
			if str(slots[s]) != "": continue
			any_avail = true
			var cap_b := b; var cap_s := s
			var row_btn := Button.new()
			row_btn.text = "침대 %d  %s" % [b + 1, "상단" if s == 0 else "하단"]
			row_btn.custom_minimum_size = Vector2(0, 30)
			row_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row_btn.add_theme_font_size_override("font_size", 11)
			row_btn.pressed.connect(func():
				GameState.move_pilot_bed(_pilot_id, cap_b, cap_s)
				_bed_idx  = cap_b
				_slot_idx = cap_s
				_rebuild()
			)
			_move_panel.add_child(row_btn)

	if not any_avail:
		var no_lbl := Label.new()
		no_lbl.text = "이동 가능한 빈 슬롯 없음"
		no_lbl.add_theme_font_size_override("font_size", 10)
		no_lbl.modulate = Color(0.65, 0.35, 0.35)
		_move_panel.add_child(no_lbl)

	_move_panel.visible = true


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
		"dispatch_time_pct": return "파견 시간 -%d%%" % bval
		"return_time_pct":   return "복귀 시간 -%d%%" % bval
	return btype


func _info_row(label: String, value: String, val_col: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.modulate = Color(0.46, 0.52, 0.66)
	lbl.custom_minimum_size = Vector2(72, 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	var val := Label.new()
	val.text = value
	val.add_theme_font_size_override("font_size", 11)
	val.modulate = val_col
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(val)
	return row


func _hsep() -> HSeparator:
	var sep := HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.08)
	return sep
