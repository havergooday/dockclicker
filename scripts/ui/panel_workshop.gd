extends Control

@onready var back_button: Button  = $Header/BackButton
@onready var _body:       Control = $Body

const TIER_COLORS: Array[Color] = [
	Color(0.55, 0.55, 0.58, 1.0),
	Color(1.00, 1.00, 1.00, 1.0),
	Color(0.35, 0.65, 1.00, 1.0),
]
const BUBBLE_LINES: Array[String] = [
	"파츠 상태 양호합니다.", "조립 준비 완료!", "이 구성... 마음에 드는군.",
	"슬롯을 선택하세요.", "좋은 선택이에요, 사령관.",
	"이 머신이라면 믿을 수 있어요.", "빠른 손이 최고죠.",
]

const CHAR_W         := 72
const CENTER_W       := 700
const SLOT_SZ        := 44
const PREVIEW_SZ     := 86
const BAY_CARD_W     := 170
const BAR_H          := 38
const DRAG_THRESHOLD := 5.0

var _selected_bay:  int        = -1
var _selected_slot: String     = ""
var _equipped:      Dictionary = {"body": 0, "weapon": 0, "legs": 0}

# 중앙 패널 뷰
var _bay_view:       Control         = null
var _schematic_view: Control         = null
var _bay_scroll:     ScrollContainer = null
var _bay_card_row:   HBoxContainer   = null
var _bay_label:      Button          = null
var _drag_start_x:   float           = -1.0
var _drag_start_h:   int             = 0
var _was_dragging:   bool            = false

# 설계도 refs
var _slot_btns:    Dictionary = {}
var _slot_labels:  Dictionary = {}
var _stat_mission: Label      = null
var _stat_rate:    Label      = null
var _stat_return:  Label      = null

# 우측 패널 refs
var _right_hint:   Label          = null
var _parts_header: Label          = null
var _parts_scroll: ScrollContainer = null
var _parts_list:   VBoxContainer  = null
var _cost_lbl:     Label          = null
var _asm_btn:      Button         = null

# 말풍선
var _bubble:    Control = null
var _bubble_tw: Tween   = null

# ── 탭 시스템 ─────────────────────────────────────────────────
const WS_TAB_H  := 24
const INV_COLS  := 20
const INV_ROWS  := 3

var _workshop_tab:     Control      = null
var _inventory_tab:    Control      = null
var _current_ws_tab:   String       = "workshop"
var _inv_grid_vb:      VBoxContainer = null
var _inv_detail_con:   Control      = null
var _inv_selected_iid: String       = ""

func _ready() -> void:
	PanelManager.register_panel("workshop", self)
	back_button.pressed.connect(func(): PanelManager.go_back())
	back_button.text = "← %s" % PanelManager.get_back_label()
	PanelManager.panel_changed.connect(func(id: String):
		if id == "workshop": back_button.text = "← %s" % PanelManager.get_back_label()
	)
	GameState.part_purchased.connect(func(_pt, _t):
		_refresh_parts_list(); _refresh_stats(); _refresh_bottom()
		if _current_ws_tab == "inventory": _refresh_inv_grid()
	)
	GameState.auto_slot_changed.connect(func(_i):
		_refresh_bay_cards()
		if _current_ws_tab == "inventory": _refresh_inv_grid()
	)
	GameState.credits_changed.connect(func(_v): _refresh_bottom())
	visibility_changed.connect(func():
		if visible: _apply_preselect()
	)
	_build_ws_tab_bar()
	_workshop_tab  = _make_ws_tab_con()
	_inventory_tab = _make_ws_tab_con()
	_inventory_tab.visible = false
	_build_ui()
	_build_inventory_ui()

func _apply_preselect() -> void:
	var presel := GameState.workshop_preselect_slot
	if presel >= 0:
		GameState.workshop_preselect_slot = -1
		_select_bay(presel)
	else:
		# preselect 없이 진입 = 브릿지 등 다른 경로 → 항상 BAY 선택 화면으로 초기화
		_deselect_bay()

# ── UI 빌드 ───────────────────────────────────────────────

func _build_ws_tab_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = WS_TAB_H
	bar.add_theme_constant_override("separation", 2)
	_body.add_child(bar)

	var btn_group := ButtonGroup.new()
	for tab in [{"id": "workshop", "label": "조립"}, {"id": "inventory", "label": "인벤토리"}]:
		var btn := Button.new()
		btn.text    = tab["label"]
		btn.toggle_mode = true
		btn.button_group = btn_group
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size   = Vector2(0, WS_TAB_H)
		if tab["id"] == "workshop": btn.set_pressed_no_signal(true)

		var norm := StyleBoxFlat.new()
		norm.bg_color = Color(0.06, 0.10, 0.18, 0.80)
		norm.border_color = Color(0.15, 0.26, 0.42); norm.border_width_bottom = 2
		norm.corner_radius_top_left = 3; norm.corner_radius_top_right = 3
		norm.content_margin_left = 8; norm.content_margin_right = 8
		btn.add_theme_stylebox_override("normal", norm)

		var sel := StyleBoxFlat.new()
		sel.bg_color = Color(0.10, 0.18, 0.34, 0.90)
		sel.border_color = Color(0.30, 0.55, 1.0); sel.border_width_bottom = 2
		sel.corner_radius_top_left = 3; sel.corner_radius_top_right = 3
		sel.content_margin_left = 8; sel.content_margin_right = 8
		btn.add_theme_stylebox_override("pressed",       sel)
		btn.add_theme_stylebox_override("hover_pressed", sel.duplicate())

		var hov := norm.duplicate() as StyleBoxFlat
		hov.bg_color = Color(0.08, 0.14, 0.24, 0.82)
		hov.border_color = Color(0.22, 0.36, 0.60)
		btn.add_theme_stylebox_override("hover", hov)

		var tid: String = tab["id"]
		btn.pressed.connect(func(): _select_ws_tab(tid))
		bar.add_child(btn)

func _make_ws_tab_con() -> Control:
	var con := Control.new()
	con.set_anchors_preset(Control.PRESET_FULL_RECT)
	con.offset_top = WS_TAB_H
	_body.add_child(con)
	return con

func _select_ws_tab(tab_id: String) -> void:
	_current_ws_tab       = tab_id
	_workshop_tab.visible  = (tab_id == "workshop")
	_inventory_tab.visible = (tab_id == "inventory")
	if tab_id == "inventory":
		_refresh_inv_grid()
		_refresh_inv_detail()

func _build_ui() -> void:
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	_workshop_tab.add_child(hbox)

	_build_char_strip(hbox)
	_add_gap(hbox, 14); _add_vsep(hbox); _add_gap(hbox, 14)
	_build_center(hbox)
	_add_gap(hbox, 14); _add_vsep(hbox); _add_gap(hbox, 14)
	_build_right_panel(hbox)

func _add_gap(p: HBoxContainer, w: int) -> void:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(w, 0)
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(sp)

func _add_vsep(p: HBoxContainer) -> void:
	var sep := ColorRect.new()
	sep.color = Color(0.20, 0.26, 0.42, 0.50)
	sep.custom_minimum_size = Vector2(1, 0)
	sep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_child(sep)

# ── 정비사 스트립 ─────────────────────────────────────────

func _build_char_strip(parent: HBoxContainer) -> void:
	var strip := Control.new()
	strip.custom_minimum_size = Vector2(CHAR_W, 0)
	strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(strip)

	var bg := ColorRect.new()
	bg.color = Color(0.14, 0.18, 0.30, 0.88)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = 2; bg.offset_right = -2; bg.offset_top = 6; bg.offset_bottom = -6
	strip.add_child(bg)

	var border := Panel.new()
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.offset_left = 2; border.offset_right = -2; border.offset_top = 6; border.offset_bottom = -6
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bsty := StyleBoxFlat.new()
	bsty.bg_color = Color(0,0,0,0)
	bsty.border_color = Color(0.30, 0.38, 0.58, 0.70)
	bsty.set_border_width_all(1); bsty.set_corner_radius_all(4)
	border.add_theme_stylebox_override("panel", bsty)
	strip.add_child(border)

	var lbl := Label.new()
	lbl.text = "정\n비\n사"
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.modulate = Color(0.55, 0.62, 0.82)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(lbl)

	var btn := Button.new()
	btn.text = ""
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ts := StyleBoxFlat.new(); ts.bg_color = Color(0,0,0,0); ts.set_border_width_all(0)
	for state in ["normal","hover","pressed","focus"]:
		btn.add_theme_stylebox_override(state, ts)
	btn.pressed.connect(_show_bubble)
	strip.add_child(btn)

# ── 말풍선 ────────────────────────────────────────────────

func _show_bubble() -> void:
	if _bubble != null and is_instance_valid(_bubble): _bubble.queue_free()
	if _bubble_tw != null: _bubble_tw.kill()

	var bubble := PanelContainer.new()
	var sty := StyleBoxFlat.new()
	sty.bg_color = Color(0.10, 0.14, 0.26, 0.95)
	sty.border_color = Color(0.38, 0.52, 0.85)
	sty.set_border_width_all(1); sty.set_corner_radius_all(5)
	sty.content_margin_left = 10; sty.content_margin_right = 10
	sty.content_margin_top = 5; sty.content_margin_bottom = 5
	bubble.add_theme_stylebox_override("panel", sty)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.z_index = 10

	var txt := Label.new()
	txt.text = BUBBLE_LINES[randi() % BUBBLE_LINES.size()]
	txt.add_theme_font_size_override("font_size", 11)
	txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(txt)

	bubble.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	bubble.offset_left = CHAR_W + 20; bubble.offset_top = 80
	add_child(bubble)
	_bubble = bubble

	_bubble_tw = create_tween()
	_bubble_tw.tween_interval(3.2)
	_bubble_tw.tween_callback(func():
		if _bubble == null or not is_instance_valid(_bubble): return
		var tw2 := _bubble.create_tween()
		tw2.tween_property(_bubble, "modulate:a", 0.0, 0.35)
		tw2.tween_callback(func():
			if _bubble != null and is_instance_valid(_bubble): _bubble.queue_free()
			_bubble = null
		)
	)

# ── 중앙 패널 ─────────────────────────────────────────────

func _build_center(parent: HBoxContainer) -> void:
	var center := Control.new()
	center.custom_minimum_size = Vector2(CENTER_W, 0)
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(center)

	_bay_view = Control.new()
	_bay_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_child(_bay_view)
	_build_bay_view()

	_schematic_view = Control.new()
	_schematic_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_schematic_view.visible = false
	center.add_child(_schematic_view)
	_build_schematic_view()

# ── BAY 선택 뷰 ──────────────────────────────────────────

func _build_bay_view() -> void:
	_bay_scroll = ScrollContainer.new()
	_bay_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bay_scroll.offset_top    = 6
	_bay_scroll.offset_bottom = -6
	_bay_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_bay_scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_DISABLED
	_bay_view.add_child(_bay_scroll)

	_bay_card_row = HBoxContainer.new()
	_bay_card_row.add_theme_constant_override("separation", 12)
	_bay_card_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bay_scroll.add_child(_bay_card_row)

	_refresh_bay_cards()

func _refresh_bay_cards() -> void:
	if _bay_card_row == null: return
	for c in _bay_card_row.get_children():
		_bay_card_row.remove_child(c); c.queue_free()

	# 좌측 여백
	var lpad := Control.new()
	lpad.custom_minimum_size = Vector2(8, 0)
	lpad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bay_card_row.add_child(lpad)

	var found := false
	for i: int in GameState.auto_slots.size():
		var slot: DispatchManager.AutoSlot = GameState.auto_slots[i]
		if slot.state != "empty": continue
		found = true

		var btn := Button.new()
		btn.text = ""
		btn.custom_minimum_size = Vector2(BAY_CARD_W, 0)
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.add_theme_stylebox_override("normal",  _bay_card_sty(false))
		btn.add_theme_stylebox_override("hover",   _bay_card_sty(true))
		btn.add_theme_stylebox_override("pressed", _bay_card_sty(false))
		btn.add_theme_stylebox_override("focus",   _bay_card_sty(false))

		var vb := VBoxContainer.new()
		vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 6)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(vb)

		# "BAY" 소형 레이블
		var bay_tag := Label.new()
		bay_tag.text = "BAY"
		bay_tag.add_theme_font_size_override("font_size", 9)
		bay_tag.modulate = Color(0.40, 0.50, 0.70)
		bay_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bay_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(bay_tag)

		# 베이 번호 (크게)
		var num := Label.new()
		num.text = "%02d" % (i + 1)
		num.add_theme_font_size_override("font_size", 32)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(num)

		# 구분선
		var div := ColorRect.new()
		div.color = Color(0.28, 0.36, 0.55, 0.50)
		div.custom_minimum_size = Vector2(40, 1)
		div.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		div.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(div)

		# 상태
		var st := Label.new()
		st.text = "● EMPTY"
		st.add_theme_font_size_override("font_size", 10)
		st.modulate = Color(0.36, 0.80, 0.46)
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(st)

		var cap := i
		btn.pressed.connect(func():
			if not _was_dragging: _select_bay(cap)
		)
		_bay_card_row.add_child(btn)

	if not found:
		# 빈 슬롯 없음 메시지는 카드 행 바깥에 배치
		var lbl := Label.new()
		lbl.text = "조립 가능한 빈 슬롯이 없습니다"
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.modulate = Color(0.55, 0.28, 0.28, 0.85)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
		_bay_card_row.add_child(lbl)

# ── 설계도 뷰 ─────────────────────────────────────────────

func _build_schematic_view() -> void:
	# 상단 바 배경
	var bar_bg := ColorRect.new()
	bar_bg.color         = Color(0.08, 0.11, 0.20, 0.85)
	bar_bg.anchor_right  = 1.0
	bar_bg.anchor_bottom = 0.0
	bar_bg.offset_bottom = BAR_H
	_schematic_view.add_child(bar_bg)

	# 하단 구분선
	var bar_sep := ColorRect.new()
	bar_sep.color         = Color(0.28, 0.38, 0.62, 0.60)
	bar_sep.anchor_right  = 1.0
	bar_sep.anchor_bottom = 0.0
	bar_sep.offset_top    = BAR_H - 1
	bar_sep.offset_bottom = BAR_H
	_schematic_view.add_child(bar_sep)

	# 상단 바: BAY 번호 전체가 하나의 변경 버튼
	_bay_label = Button.new()
	_bay_label.text       = "← BAY --"
	_bay_label.add_theme_font_size_override("font_size", 11)
	_bay_label.anchor_right  = 0.0
	_bay_label.anchor_bottom = 0.0
	_bay_label.offset_left   = 8
	_bay_label.offset_top    = 4
	_bay_label.offset_right  = 270
	_bay_label.offset_bottom = BAR_H - 4
	_bay_label.alignment     = HORIZONTAL_ALIGNMENT_LEFT
	_bay_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var btn_sty := StyleBoxFlat.new()
	btn_sty.bg_color     = Color(0.12, 0.18, 0.34, 0.0)
	btn_sty.border_color = Color(0.35, 0.50, 0.80, 0.70)
	btn_sty.set_border_width_all(1)
	btn_sty.set_corner_radius_all(4)
	btn_sty.content_margin_left = 10
	var btn_hov := btn_sty.duplicate() as StyleBoxFlat
	btn_hov.bg_color     = Color(0.14, 0.22, 0.42, 0.70)
	btn_hov.border_color = Color(0.45, 0.62, 1.00)
	_bay_label.add_theme_stylebox_override("normal",  btn_sty)
	_bay_label.add_theme_stylebox_override("hover",   btn_hov)
	_bay_label.add_theme_stylebox_override("pressed", btn_sty)
	_bay_label.add_theme_stylebox_override("focus",   btn_sty)
	_bay_label.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
	_bay_label.pressed.connect(_deselect_bay)
	_schematic_view.add_child(_bay_label)

	# 설계도 컨텐츠 영역 (바 아래부터 시작)
	var content := Control.new()
	content.anchor_right  = 1.0
	content.anchor_bottom = 1.0
	content.offset_top    = BAR_H + 2
	content.offset_bottom = 0.0
	content.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_schematic_view.add_child(content)
	_build_schematic_content(content)

func _build_schematic_content(parent: Control) -> void:
	# 미리보기 박스
	var prev_panel := Panel.new()
	prev_panel.offset_left   = 8
	prev_panel.offset_top    = 4
	prev_panel.offset_right  = 8 + PREVIEW_SZ
	prev_panel.offset_bottom = 4 + PREVIEW_SZ
	prev_panel.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.08, 0.14, 0.88)
	ps.border_color = Color(0.28, 0.36, 0.55)
	ps.set_border_width_all(1); ps.set_corner_radius_all(4)
	prev_panel.add_theme_stylebox_override("panel", ps)
	parent.add_child(prev_panel)

	var prev_lbl := Label.new()
	prev_lbl.text = "PREVIEW"
	prev_lbl.add_theme_font_size_override("font_size", 8)
	prev_lbl.modulate = Color(0.35, 0.40, 0.52)
	prev_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prev_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	prev_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prev_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prev_panel.add_child(prev_lbl)

	# 스텟
	var stat_box := VBoxContainer.new()
	stat_box.offset_left   = 8
	stat_box.offset_top    = 4 + PREVIEW_SZ + 6
	stat_box.offset_right  = 8 + PREVIEW_SZ
	stat_box.offset_bottom = 210
	stat_box.add_theme_constant_override("separation", 3)
	stat_box.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	parent.add_child(stat_box)

	_stat_mission = _make_stat_lbl("임무  --")
	_stat_rate    = _make_stat_lbl("CR/s  --")
	_stat_return  = _make_stat_lbl("복귀  --")
	stat_box.add_child(_stat_mission)
	stat_box.add_child(_stat_rate)
	stat_box.add_child(_stat_return)

	# 로봇 슬롯
	var rx := float(8 + PREVIEW_SZ + 52)

	var head_lbl := Label.new()
	head_lbl.text = "[ ]"
	head_lbl.add_theme_font_size_override("font_size", 13)
	head_lbl.modulate = Color(0.30, 0.36, 0.50)
	head_lbl.offset_left   = rx + 6; head_lbl.offset_top    = 4
	head_lbl.offset_right  = rx + 6 + SLOT_SZ; head_lbl.offset_bottom = 26
	head_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(head_lbl)

	_add_slot(parent, "body",   rx,                48)
	_add_slot(parent, "weapon", rx + SLOT_SZ + 26, 66)
	_add_slot(parent, "legs",   rx + 2,            138)

	_add_connector(parent, rx + SLOT_SZ / 2, 92, 2, 46)
	_add_connector(parent, rx + SLOT_SZ,     74, 26, 2)

func _add_slot(parent: Control, slot_type: String, ox: float, oy: float) -> void:
	var btn := Button.new()
	btn.offset_left = ox; btn.offset_top    = oy
	btn.offset_right = ox + SLOT_SZ; btn.offset_bottom = oy + SLOT_SZ
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_stylebox_override("normal",  _slot_sty_idle())
	btn.add_theme_stylebox_override("hover",   _slot_sty_hover())
	btn.add_theme_stylebox_override("pressed", _slot_sty_idle())
	btn.add_theme_stylebox_override("focus",   _slot_sty_idle())

	var inner := Label.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	inner.add_theme_font_size_override("font_size", 10)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match slot_type:
		"body":   inner.text = "몸"
		"weapon": inner.text = "무"
		"legs":   inner.text = "다"
	inner.modulate = Color(0.38, 0.44, 0.58)
	btn.add_child(inner)

	var cap := slot_type
	btn.pressed.connect(func(): _on_slot_clicked(cap))
	parent.add_child(btn)
	_slot_btns[slot_type]   = btn
	_slot_labels[slot_type] = inner

func _add_connector(parent: Control, ox: float, oy: float, w: float, h: float) -> void:
	var line := ColorRect.new()
	line.color = Color(0.25, 0.30, 0.45, 0.55)
	line.offset_left = ox; line.offset_top    = oy
	line.offset_right = ox + w; line.offset_bottom = oy + h
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)

func _make_stat_lbl(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.modulate = Color(0.50, 0.56, 0.72)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl

# ── 우측 패널 ─────────────────────────────────────────────

func _build_right_panel(parent: HBoxContainer) -> void:
	var panel := Control.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	# 힌트 레이블 (기본/슬롯 미선택 상태)
	_right_hint = Label.new()
	_right_hint.text = "BAY를 선택하세요"
	_right_hint.add_theme_font_size_override("font_size", 12)
	_right_hint.modulate = Color(0.30, 0.36, 0.50)
	_right_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_right_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_right_hint)

	# 파츠 헤더
	_parts_header = Label.new()
	_parts_header.text = ""
	_parts_header.add_theme_font_size_override("font_size", 10)
	_parts_header.modulate = Color(0.50, 0.58, 0.78)
	_parts_header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_parts_header.offset_left = 4; _parts_header.offset_right = -8
	_parts_header.offset_top = 6;  _parts_header.offset_bottom = 24
	_parts_header.visible = false
	panel.add_child(_parts_header)

	# 파츠 스크롤
	_parts_scroll = ScrollContainer.new()
	_parts_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_parts_scroll.offset_left = 2; _parts_scroll.offset_right = -6
	_parts_scroll.offset_top = 28; _parts_scroll.offset_bottom = -36
	_parts_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_parts_scroll.visible = false
	panel.add_child(_parts_scroll)

	_parts_list = VBoxContainer.new()
	_parts_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_parts_list.add_theme_constant_override("separation", 3)
	_parts_scroll.add_child(_parts_list)

	# 하단: [여백][조립비용][조립하기]
	var bottom := HBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 2; bottom.offset_right = -6
	bottom.offset_top = -30; bottom.offset_bottom = -4
	bottom.add_theme_constant_override("separation", 10)
	bottom.visible = false
	panel.add_child(bottom)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)

	_cost_lbl = Label.new()
	_cost_lbl.text = "조립비용  --"
	_cost_lbl.add_theme_font_size_override("font_size", 10)
	_cost_lbl.modulate = Color(0.65, 0.68, 0.76)
	_cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom.add_child(_cost_lbl)

	_asm_btn = Button.new()
	_asm_btn.text = "조립하기"
	_asm_btn.custom_minimum_size = Vector2(96, 0)
	_asm_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_asm_btn.disabled = true
	_asm_btn.pressed.connect(_on_assemble_pressed)
	bottom.add_child(_asm_btn)

	# bottom 노드 참조 보관 (가시성 제어용)
	_right_bottom = bottom

# ── 드래그 스크롤 ─────────────────────────────────────────

var _right_bottom: HBoxContainer = null

func _input(event: InputEvent) -> void:
	if _bay_scroll == null or not _bay_view.visible: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var rect := Rect2(_bay_scroll.global_position, _bay_scroll.size)
			if rect.has_point(event.global_position):
				_drag_start_x = event.global_position.x
				_drag_start_h = _bay_scroll.scroll_horizontal
				_was_dragging = false
		else:
			if _was_dragging: get_viewport().set_input_as_handled()
			_drag_start_x = -1.0
			_was_dragging = false
	elif event is InputEventMouseMotion and _drag_start_x >= 0.0:
		var delta: float = _drag_start_x - event.global_position.x
		if abs(delta) > DRAG_THRESHOLD:
			_was_dragging = true
			_bay_scroll.scroll_horizontal = _drag_start_h + int(delta)

# ── 상태 전환 ─────────────────────────────────────────────

func _select_bay(index: int) -> void:
	_selected_bay  = index
	_selected_slot = ""
	_equipped      = {"body": 0, "weapon": 0, "legs": 0}
	_bay_view.visible       = false
	_schematic_view.visible = true
	_bay_label.text = "← BAY %02d  ●  EMPTY" % (index + 1)
	_refresh_slot_visuals()
	_refresh_right_state()
	_refresh_stats()
	_refresh_bottom()

func _deselect_bay() -> void:
	_selected_bay  = -1
	_selected_slot = ""
	_equipped      = {"body": 0, "weapon": 0, "legs": 0}
	_bay_view.visible       = true
	_schematic_view.visible = false
	_drag_start_x = -1.0
	_was_dragging = false
	_refresh_bay_cards()
	_refresh_right_state()

func _on_slot_clicked(slot_type: String) -> void:
	_selected_slot = slot_type
	_refresh_slot_visuals()
	_refresh_parts_list()
	_refresh_right_state()

func _refresh_right_state() -> void:
	var bay_ok:  bool = _selected_bay >= 0
	var slot_ok: bool = _selected_slot != ""

	_right_hint.visible    = not (bay_ok and slot_ok)
	_parts_header.visible  = bay_ok and slot_ok
	_parts_scroll.visible  = bay_ok and slot_ok
	_right_bottom.visible  = bay_ok

	if not bay_ok:
		_right_hint.text = "BAY를 선택하세요"
	elif not slot_ok:
		_right_hint.text = "슬롯을 선택하세요"

# ── 슬롯 비주얼 ───────────────────────────────────────────

func _refresh_slot_visuals() -> void:
	for stype in _slot_btns:
		var btn:    Button = _slot_btns[stype]
		var lbl:    Label  = _slot_labels[stype]
		var eq:     int    = _equipped.get(stype, 0)
		var is_sel: bool   = (stype == _selected_slot)

		if is_sel:
			btn.add_theme_stylebox_override("normal", _slot_sty_selected())
			btn.add_theme_stylebox_override("hover",  _slot_sty_selected())
		elif eq > 0:
			btn.add_theme_stylebox_override("normal", _slot_sty_equipped())
			btn.add_theme_stylebox_override("hover",  _slot_sty_hover())
		else:
			btn.add_theme_stylebox_override("normal", _slot_sty_idle())
			btn.add_theme_stylebox_override("hover",  _slot_sty_hover())

		if eq > 0:
			lbl.text    = "T%d" % eq
			lbl.modulate = TIER_COLORS[mini(eq - 1, 2)]
		else:
			match stype:
				"body":   lbl.text = "몸"
				"weapon": lbl.text = "무"
				"legs":   lbl.text = "다"
			lbl.modulate = Color(0.38, 0.44, 0.58)

# ── 파츠 목록 ─────────────────────────────────────────────

func _refresh_parts_list() -> void:
	if _parts_list == null or _selected_slot == "": return
	for c in _parts_list.get_children():
		_parts_list.remove_child(c); c.queue_free()

	var slot_names := {"body": "몸체", "weapon": "무기", "legs": "다리"}
	_parts_header.text = "%s  파츠" % slot_names.get(_selected_slot, _selected_slot)

	var items: Array = []
	for item: Dictionary in GameState.part_inventory:
		if item.get("type", "") == _selected_slot:
			items.append(item)
	items.sort_custom(func(a, b): return int(a.get("tier", 1)) < int(b.get("tier", 1)))

	if items.is_empty():
		var lbl := Label.new()
		lbl.text = "보유 파츠 없음"
		lbl.modulate = Color(0.7, 0.3, 0.3, 0.8)
		lbl.add_theme_font_size_override("font_size", 11)
		_parts_list.add_child(lbl)
		return

	var eq_tier: int  = _equipped.get(_selected_slot, 0)
	var eq_found := false
	for item: Dictionary in items:
		var tier: int = int(item.get("tier", 1))
		var is_eq: bool = (tier == eq_tier and not eq_found)
		if is_eq: eq_found = true
		_parts_list.add_child(_make_part_row(_selected_slot, tier, is_eq))

func _make_part_row(part_type: String, tier: int, is_equipped: bool) -> Button:
	var data: Dictionary = GameState.PARTS[part_type]
	var td:   Dictionary = data["tiers"][tier - 1]
	var tcol: Color      = TIER_COLORS[mini(tier - 1, 2)]

	var btn := Button.new()
	btn.text = ""
	btn.custom_minimum_size = Vector2(0, 30)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_stylebox_override("normal",  _part_sty(tcol, is_equipped, false))
	btn.add_theme_stylebox_override("hover",   _part_sty(tcol, is_equipped, true))
	btn.add_theme_stylebox_override("pressed", _part_sty(tcol, is_equipped, false))
	btn.add_theme_stylebox_override("focus",   _part_sty(tcol, is_equipped, false))

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(row)

	var tier_lbl := Label.new()
	tier_lbl.text = "T%d" % tier
	tier_lbl.add_theme_font_size_override("font_size", 10)
	tier_lbl.modulate = tcol
	tier_lbl.custom_minimum_size = Vector2(20, 0)
	tier_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tier_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tier_lbl)

	var name_lbl := Label.new()
	name_lbl.text = td.get("name", "파츠 T%d" % tier)
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_lbl)

	if is_equipped:
		var eq_lbl := Label.new()
		eq_lbl.text = "장착중"
		eq_lbl.add_theme_font_size_override("font_size", 9)
		eq_lbl.modulate = Color(0.28, 1.0, 0.52)
		eq_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		eq_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(eq_lbl)

	var pt := part_type; var t := tier
	btn.pressed.connect(func():
		_equipped[pt] = t
		_refresh_slot_visuals(); _refresh_parts_list()
		_refresh_stats(); _refresh_bottom()
	)
	return btn

# ── 스텟 / 하단 ───────────────────────────────────────────

func _refresh_stats() -> void:
	if _stat_mission == null: return
	var b: int = _equipped.get("body", 0)
	var w: int = _equipped.get("weapon", 0)
	var l: int = _equipped.get("legs", 0)
	var p: Dictionary = GameState.get_machine_preview(b, w, l)
	_stat_mission.text = "임무  %s" % (("%ds" % int(p.get("mission_time", 0))) if b > 0 else "--")
	_stat_rate.text    = "CR/s  %s" % (("×%d"  % p.get("rate", 0))            if w > 0 else "--")
	_stat_return.text  = "복귀  %s" % (("%ds"  % int(p.get("return_time", 0))) if l > 0 else "--")

func _refresh_bottom() -> void:
	if _asm_btn == null: return
	var b: int = _equipped.get("body", 0)
	var w: int = _equipped.get("weapon", 0)
	var l: int = _equipped.get("legs", 0)
	var all_sel: bool = (_selected_bay >= 0 and b > 0 and w > 0 and l > 0)
	var cost := 0
	if all_sel: cost = GameState.get_assembly_cost(b, w, l)
	_cost_lbl.text = "조립비용  %s" % (("%d CR" % cost) if all_sel else "--")
	var can_afford: bool = all_sel and GameState.total_credits >= cost
	_asm_btn.disabled = not can_afford
	_asm_btn.modulate = Color(0.32, 1.0, 0.55) if can_afford else Color(1, 1, 1, 0.5)

func _on_assemble_pressed() -> void:
	var b: int = _equipped.get("body", 0)
	var w: int = _equipped.get("weapon", 0)
	var l: int = _equipped.get("legs", 0)
	if GameState.assemble_machine(_selected_bay, b, w, l):
		_deselect_bay()

# ── 스타일 ────────────────────────────────────────────────

func _bay_card_sty(hover: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color     = Color(0.10, 0.14, 0.26, 0.90) if hover else Color(0.07, 0.10, 0.18, 0.88)
	s.border_color = Color(0.38, 0.50, 0.72) if hover else Color(0.24, 0.34, 0.54)
	s.set_border_width_all(1); s.set_corner_radius_all(6)
	s.content_margin_top = 6; s.content_margin_bottom = 6
	return s

func _slot_sty_idle() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.11, 0.20, 0.85)
	s.border_color = Color(0.28, 0.36, 0.56)
	s.set_border_width_all(1); s.set_corner_radius_all(4)
	return s

func _slot_sty_hover() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.17, 0.30, 0.88)
	s.border_color = Color(0.45, 0.55, 0.80)
	s.set_border_width_all(1); s.set_corner_radius_all(4)
	return s

func _slot_sty_selected() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.16, 0.26, 0.50, 0.92)
	s.border_color = Color(0.52, 0.72, 1.00)
	s.set_border_width_all(2); s.set_corner_radius_all(4)
	return s

func _slot_sty_equipped() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.20, 0.14, 0.88)
	s.border_color = Color(0.28, 0.80, 0.50)
	s.set_border_width_all(1); s.set_corner_radius_all(4)
	return s

func _part_sty(tcol: Color, equipped: bool, hover: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	if equipped:
		s.bg_color     = Color(0.08, 0.20, 0.14, 0.85).lightened(0.06 if hover else 0.0)
		s.border_color = Color(0.28, 0.82, 0.50)
	else:
		s.bg_color     = Color(0.08, 0.10, 0.18, 0.80).lightened(0.07 if hover else 0.0)
		s.border_color = tcol.darkened(0.35)
	s.set_border_width_all(1); s.set_corner_radius_all(3)
	s.content_margin_left = 8; s.content_margin_right = 8
	s.content_margin_top = 2; s.content_margin_bottom = 2
	return s

# ── 인벤토리 탭 ───────────────────────────────────────────────

func _build_inventory_ui() -> void:
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	_inventory_tab.add_child(hbox)

	var grid_scroll := ScrollContainer.new()
	grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid_scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO
	hbox.add_child(grid_scroll)

	_inv_grid_vb = VBoxContainer.new()
	_inv_grid_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inv_grid_vb.add_theme_constant_override("separation", 3)
	grid_scroll.add_child(_inv_grid_vb)

	var vsep := ColorRect.new()
	vsep.color = Color(0.20, 0.26, 0.42, 0.50)
	vsep.custom_minimum_size = Vector2(1, 0)
	vsep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(vsep)

	_inv_detail_con = Control.new()
	_inv_detail_con.custom_minimum_size = Vector2(260, 0)
	_inv_detail_con.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(_inv_detail_con)

func _refresh_inv_grid() -> void:
	if _inv_grid_vb == null or not is_instance_valid(_inv_grid_vb): return
	for c in _inv_grid_vb.get_children():
		c.queue_free()

	var items: Array = GameState.part_inventory.duplicate()
	var type_order := {"body": 0, "weapon": 1, "legs": 2}
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta: int = type_order.get(a.get("type", ""), 9)
		var tb: int = type_order.get(b.get("type", ""), 9)
		if ta != tb: return ta < tb
		return int(a.get("tier", 1)) < int(b.get("tier", 1))
	)

	var row_count: int = maxi(INV_ROWS, ceili(float(items.size()) / INV_COLS) + 1)

	for row_i in row_count:
		var row_hbox := HBoxContainer.new()
		row_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_hbox.add_theme_constant_override("separation", 3)
		_inv_grid_vb.add_child(row_hbox)

		for col_i in INV_COLS:
			var slot_i: int = row_i * INV_COLS + col_i
			var btn := Button.new()
			btn.text = ""
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size   = Vector2(0, 40)
			row_hbox.add_child(btn)

			if slot_i < items.size():
				var item: Dictionary  = items[slot_i]
				var iid: String       = item.get("iid", "")
				var part_type: String = item.get("type", "")
				var tier: int         = int(item.get("tier", 1))
				var tcol: Color       = TIER_COLORS[mini(tier - 1, 2)]
				var is_sel: bool      = (_inv_selected_iid == iid)

				btn.add_theme_stylebox_override("normal",  _inv_slot_filled(tcol, is_sel))
				btn.add_theme_stylebox_override("hover",   _inv_slot_filled(tcol, true))
				btn.add_theme_stylebox_override("pressed", _inv_slot_filled(tcol, is_sel))
				btn.add_theme_stylebox_override("focus",   _inv_slot_filled(tcol, is_sel))
				btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

				var vb := VBoxContainer.new()
				vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				vb.alignment = BoxContainer.ALIGNMENT_CENTER
				vb.add_theme_constant_override("separation", 2)
				vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
				btn.add_child(vb)

				var type_icons := {"body": "몸", "weapon": "무", "legs": "다"}
				var icon_lbl := Label.new()
				icon_lbl.text = type_icons.get(part_type, "?")
				icon_lbl.add_theme_font_size_override("font_size", 9)
				icon_lbl.modulate = Color(0.50, 0.55, 0.68)
				icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				vb.add_child(icon_lbl)

				var tier_lbl := Label.new()
				tier_lbl.text = "T%d" % tier
				tier_lbl.add_theme_font_size_override("font_size", 14)
				tier_lbl.modulate = tcol
				tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				tier_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				vb.add_child(tier_lbl)

				btn.pressed.connect(func():
					_inv_selected_iid = iid
					_refresh_inv_grid()
					_refresh_inv_detail()
				)
			else:
				btn.add_theme_stylebox_override("normal",  _inv_slot_empty())
				btn.add_theme_stylebox_override("hover",   _inv_slot_empty())
				btn.add_theme_stylebox_override("pressed", _inv_slot_empty())
				btn.add_theme_stylebox_override("focus",   _inv_slot_empty())
				btn.mouse_default_cursor_shape = Control.CURSOR_ARROW

func _refresh_inv_detail() -> void:
	if _inv_detail_con == null or not is_instance_valid(_inv_detail_con): return
	for c in _inv_detail_con.get_children():
		c.queue_free()

	if _inv_selected_iid == "":
		var hint := Label.new()
		hint.text = "파츠를 선택하세요"
		hint.add_theme_font_size_override("font_size", 11)
		hint.modulate = Color(1, 1, 1, 0.20)
		hint.set_anchors_preset(Control.PRESET_CENTER)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_inv_detail_con.add_child(hint)
		return

	var found: Dictionary = {}
	for item: Dictionary in GameState.part_inventory:
		if item.get("iid", "") == _inv_selected_iid:
			found = item; break

	if found.is_empty():
		_inv_selected_iid = ""
		_refresh_inv_detail()
		return

	var part_type: String     = found.get("type", "")
	var tier: int             = int(found.get("tier", 1))
	var data: Dictionary      = GameState.PARTS.get(part_type, {})
	if data.is_empty(): return
	var tiers: Array          = data["tiers"]
	if tier < 1 or tier > tiers.size(): return
	var tier_data: Dictionary = tiers[tier - 1]
	var tcol: Color           = TIER_COLORS[mini(tier - 1, 2)]

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 16; vb.offset_right = -16
	vb.offset_top = 14;  vb.offset_bottom = -14
	vb.add_theme_constant_override("separation", 8)
	_inv_detail_con.add_child(vb)

	var tier_lbl := Label.new()
	tier_lbl.text = "T%d" % tier
	tier_lbl.add_theme_font_size_override("font_size", 28)
	tier_lbl.modulate = tcol
	vb.add_child(tier_lbl)

	var name_lbl := Label.new()
	name_lbl.text = tier_data.get("name", "파츠 T%d" % tier)
	name_lbl.add_theme_font_size_override("font_size", 14)
	vb.add_child(name_lbl)

	var type_names := {"body": "몸체", "weapon": "무기", "legs": "다리"}
	var type_lbl := Label.new()
	type_lbl.text = type_names.get(part_type, part_type)
	type_lbl.add_theme_font_size_override("font_size", 11)
	type_lbl.modulate = Color(0.44, 0.52, 0.68)
	vb.add_child(type_lbl)

	var sep := HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.10)
	vb.add_child(sep)

	var eff_lbl := Label.new()
	eff_lbl.text = data["effect"] % tier_data["value"]
	eff_lbl.add_theme_font_size_override("font_size", 12)
	eff_lbl.modulate = Color(0.55, 0.80, 1.0)
	eff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(eff_lbl)

func _inv_slot_empty() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color    = Color(0.04, 0.06, 0.10, 0.70)
	s.border_color = Color(0.16, 0.20, 0.30, 0.50)
	s.set_border_width_all(1); s.set_corner_radius_all(3)
	return s

func _inv_slot_filled(tcol: Color, highlight: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color    = Color(0.10, 0.15, 0.26, 0.92) if highlight else Color(0.07, 0.10, 0.18, 0.85)
	s.border_color = tcol if highlight else tcol.darkened(0.30)
	s.set_border_width_all(2 if highlight else 1); s.set_corner_radius_all(3)
	return s
