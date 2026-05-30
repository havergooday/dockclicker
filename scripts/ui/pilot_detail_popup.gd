extends Control

# 파일럿 상세 팝업 — 침대 슬롯 클릭 시 표시
# 상세 조회 + 침대 이동 선택

const POPUP_W := 340.0
const POPUP_H := 460.0

var _pilot_id:  String = ""
var _bed_idx:   int    = -1
var _slot_idx:  int    = -1

var _panel:      PanelContainer = null
var _content_vb: VBoxContainer  = null
var _move_panel: Control        = null   # 침대 이동 선택 패널


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 딤 배경
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.40)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			close()
	)
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.anchor_left   = 0.5; _panel.anchor_right  = 0.5
	_panel.anchor_top    = 0.5; _panel.anchor_bottom = 0.5
	_panel.offset_left   = -POPUP_W * 0.5
	_panel.offset_right  =  POPUP_W * 0.5
	_panel.offset_top    = -POPUP_H * 0.5
	_panel.offset_bottom =  POPUP_H * 0.5
	_panel.mouse_filter  = Control.MOUSE_FILTER_STOP
	var sty := StyleBoxFlat.new()
	sty.bg_color     = Color(0.05, 0.07, 0.12, 0.98)
	sty.border_color = Color(0.30, 0.44, 0.68, 0.90)
	sty.set_border_width_all(1); sty.set_corner_radius_all(6)
	sty.content_margin_left = 20; sty.content_margin_right  = 20
	sty.content_margin_top  = 16; sty.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel", sty)
	add_child(_panel)

	_content_vb = VBoxContainer.new()
	_content_vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content_vb.add_theme_constant_override("separation", 10)
	_panel.add_child(_content_vb)


func open(pilot_id: String, bed_idx: int, slot_idx: int) -> void:
	_pilot_id = pilot_id
	_bed_idx  = bed_idx
	_slot_idx = slot_idx
	_rebuild()
	visible = true


func close() -> void:
	visible = false


func _rebuild() -> void:
	for c in _content_vb.get_children(): c.queue_free()
	_move_panel = null

	var pilot: Dictionary = GameState.get_hired_pilot(_pilot_id)
	if pilot.is_empty():
		close(); return

	# ── 헤더 ──────────────────────────────────────────────────
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 10)
	_content_vb.add_child(hdr)

	# 초상화
	var portrait := Panel.new()
	portrait.custom_minimum_size = Vector2(64, 64)
	var pcol := Color.html(str(pilot.get("portrait_color", "#4499DD")))
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

	var hdr_info := VBoxContainer.new()
	hdr_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_info.add_theme_constant_override("separation", 4)
	hdr.add_child(hdr_info)

	var name_lbl := Label.new()
	name_lbl.text = str(pilot.get("name", ""))
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.modulate = Color(0.90, 0.94, 1.0)
	hdr_info.add_child(name_lbl)

	var tier_lbl := Label.new()
	tier_lbl.text = "T%d 파일럿" % int(pilot.get("tier", 1))
	tier_lbl.add_theme_font_size_override("font_size", 11)
	tier_lbl.modulate = Color(0.55, 0.68, 0.88)
	hdr_info.add_child(tier_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.pressed.connect(close)
	hdr.add_child(close_btn)

	_content_vb.add_child(_make_sep())

	# ── 상태 ──────────────────────────────────────────────────
	var status: String = str(pilot.get("status", "idle"))
	var status_row := _make_info_row("상태",
		"파견 중" if status == "on_mission" else "대기 중",
		Color(0.55, 0.78, 1.0) if status == "on_mission" else Color(0.38, 1.0, 0.55))
	_content_vb.add_child(status_row)

	# 배정 베이
	var assigned_bay := _find_assigned_bay()
	_content_vb.add_child(_make_info_row("배정 베이",
		"BAY %02d" % (assigned_bay + 1) if assigned_bay >= 0 else "없음",
		Color(0.75, 0.82, 1.0) if assigned_bay >= 0 else Color(0.45, 0.50, 0.60)))

	# 숙소 위치
	_content_vb.add_child(_make_info_row("숙소",
		"침대 %d  %s" % [_bed_idx + 1, "상단" if _slot_idx == 0 else "하단"],
		Color(0.68, 0.75, 0.90)))

	# ── 특성 ──────────────────────────────────────────────────
	var bonus_type: String  = str(pilot.get("bonus_type", "none"))
	var bonus_value: int    = int(pilot.get("bonus_value", 0))
	if bonus_type != "none":
		_content_vb.add_child(_make_sep())
		var bonus_text := _bonus_label(bonus_type, bonus_value)
		_content_vb.add_child(_make_info_row("특성", bonus_text, Color(0.55, 0.95, 0.70)))

	_content_vb.add_child(_make_sep())

	# ── 침대 이동 버튼 ─────────────────────────────────────────
	var move_btn := Button.new()
	move_btn.text = "침대 이동"
	move_btn.custom_minimum_size = Vector2(0, 32)
	move_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	move_btn.pressed.connect(func():
		if is_instance_valid(_move_panel) and _move_panel.visible:
			_move_panel.visible = false
		else:
			_show_move_panel()
	)
	_content_vb.add_child(move_btn)

	# 이동 패널 컨테이너 (초기엔 숨김)
	_move_panel = Control.new()
	_move_panel.visible = false
	_move_panel.custom_minimum_size = Vector2(0, 0)
	_move_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_vb.add_child(_move_panel)


func _show_move_panel() -> void:
	if _move_panel == null: return
	for c in _move_panel.get_children(): c.queue_free()

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_move_panel.add_child(vb)
	vb.set_anchors_preset(Control.PRESET_TOP_WIDE)

	var hint := Label.new()
	hint.text = "이동할 슬롯을 선택하세요"
	hint.add_theme_font_size_override("font_size", 10)
	hint.modulate = Color(0.55, 0.62, 0.78)
	vb.add_child(hint)

	var beds: Array = GameState.quarters_beds
	for b in beds.size():
		var bed: Dictionary = beds[b]
		if bed.get("locked", true): continue
		var slots: Array = bed.get("slots", ["", ""])
		for s in 2:
			var occupant: String = str(slots[s])
			if occupant == _pilot_id: continue  # 현재 위치 건너뜀
			if occupant != "": continue          # 이미 사용 중
			var cap_b := b; var cap_s := s
			var row_btn := Button.new()
			row_btn.text = "침대 %d  %s" % [b + 1, "상단" if s == 0 else "하단"]
			row_btn.custom_minimum_size = Vector2(0, 28)
			row_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row_btn.add_theme_font_size_override("font_size", 11)
			row_btn.pressed.connect(func():
				GameState.move_pilot_bed(_pilot_id, cap_b, cap_s)
				_bed_idx  = cap_b
				_slot_idx = cap_s
				_rebuild()
			)
			vb.add_child(row_btn)

	_move_panel.visible = true


# ── 헬퍼 ──────────────────────────────────────────────────────

func _find_assigned_bay() -> int:
	var slots: Array = GameState.auto_slots
	for i in slots.size():
		var s: DispatchManager.AutoSlot = slots[i]
		if s.assigned_pilot_id == _pilot_id or s.pilot_id == _pilot_id:
			return i
	return -1


func _bonus_label(btype: String, bval: int) -> String:
	match btype:
		"credits_pct":       return "수익 +%d%%" % bval
		"dispatch_time_pct": return "파견 시간 -%d%%" % bval
		"return_time_pct":   return "복귀 시간 -%d%%" % bval
	return btype


func _make_info_row(label: String, value: String, val_col: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.modulate = Color(0.50, 0.56, 0.70)
	lbl.custom_minimum_size = Vector2(70, 0)
	row.add_child(lbl)
	var val := Label.new()
	val.text = value
	val.add_theme_font_size_override("font_size", 11)
	val.modulate = val_col
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(val)
	return row


func _make_sep() -> HSeparator:
	var sep := HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.08)
	return sep
