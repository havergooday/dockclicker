extends Control

# ── 상수 ─────────────────────────────────────────────────────
const POPUP_W_RATIO   := 0.72
const ANIM_DURATION   := 0.20
const CARD_MIN_W      := 220.0
const TIER_COLORS: Array = [
	Color(0.55, 0.55, 0.58),
	Color(1.00, 1.00, 1.00),
	Color(0.95, 0.76, 0.28),
]

# ── 노드 참조 ─────────────────────────────────────────────────
var _panel:        Control = null
var _card_row:     HBoxContainer = null
var _timer_label:  Label = null
var _refresh_btn:  Button = null
var _refresh_timer: Timer = null

var _popup_w: float = 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	_build_ui()
	GameState.board_refreshed.connect(_on_board_refreshed)
	GameState.credits_changed.connect(func(_v): _update_refresh_button())
	GameState.planet_unlocked.connect(func(_id): _on_board_refreshed())


# ── 공개 API ──────────────────────────────────────────────────

func open_popup() -> void:
	GameState.ensure_board_fresh()
	_rebuild_cards()
	_update_refresh_button()
	visible = true
	_panel.position.y = -_panel.size.y - 10.0
	var tween := create_tween()
	tween.tween_property(_panel, "position:y", 0.0, ANIM_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func close_popup() -> void:
	var tween := create_tween()
	tween.tween_property(_panel, "position:y", -_panel.size.y - 10.0, ANIM_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): visible = false)


# ── UI 빌드 ───────────────────────────────────────────────────

func _build_ui() -> void:
	_popup_w = get_viewport_rect().size.x * POPUP_W_RATIO

	# 배경 딤
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			close_popup()
	)
	add_child(dim)

	# 팝업 패널
	_panel = Control.new()
	_panel.anchor_left  = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top   = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left  = -_popup_w * 0.5
	_panel.offset_right =  _popup_w * 0.5
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var bg := StyleBoxFlat.new()
	bg.bg_color     = Color(0.07, 0.10, 0.15, 0.97)
	bg.border_color = Color(0.26, 0.40, 0.62, 0.80)
	bg.set_border_width_all(1)
	var panel_bg := PanelContainer.new()
	panel_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_bg.add_theme_stylebox_override("panel", bg)
	panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(panel_bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left   = 20
	root.offset_right  = -20
	root.offset_top    = 16
	root.offset_bottom = -16
	root.add_theme_constant_override("separation", 14)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(root)

	root.add_child(_build_header())
	root.add_child(_build_board_section())

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)

	root.add_child(_build_custom_section())

	# 갱신 타이머
	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = 1.0
	_refresh_timer.autostart = true
	_refresh_timer.timeout.connect(_on_refresh_tick)
	add_child(_refresh_timer)


func _build_header() -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = "파일럿 모집 공고"
	title.add_theme_font_size_override("font_size", 17)
	title.modulate = Color(0.82, 0.92, 1.0)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(title)

	_timer_label = Label.new()
	_timer_label.text = "갱신 --:--:--"
	_timer_label.add_theme_font_size_override("font_size", 11)
	_timer_label.modulate = Color(0.60, 0.70, 0.88)
	_timer_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(_timer_label)

	_refresh_btn = Button.new()
	_refresh_btn.text = "새로고침   %d CR" % GameState.BOARD_REFRESH_COST
	_refresh_btn.custom_minimum_size = Vector2(160, 28)
	_refresh_btn.pressed.connect(func():
		GameState.refresh_board_paid()
	)
	hb.add_child(_refresh_btn)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.pressed.connect(func(): close_popup())
	hb.add_child(close_btn)

	return hb


func _build_board_section() -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 10)
	section.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sub := Label.new()
	sub.text = "오늘의 모집 파일럿"
	sub.add_theme_font_size_override("font_size", 10)
	sub.modulate = Color(0.48, 0.62, 0.88)
	section.add_child(sub)

	_card_row = HBoxContainer.new()
	_card_row.add_theme_constant_override("separation", 12)
	_card_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section.add_child(_card_row)

	return section


func _build_custom_section() -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)

	var lbl := Label.new()
	lbl.text = "커스텀 파일럿을 직접 만들 수도 있습니다"
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.modulate = Color(0.62, 0.72, 0.90)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(lbl)

	var btn := Button.new()
	btn.text = "+ 커스텀 파일럿 생성   300 CR"
	btn.custom_minimum_size = Vector2(230, 30)
	btn.pressed.connect(_open_custom_form)
	hb.add_child(btn)

	return hb


# ── 카드 빌드 ─────────────────────────────────────────────────

func _rebuild_cards() -> void:
	for c in _card_row.get_children():
		c.queue_free()

	var board := GameState.get_board_pilot_data()
	if board.is_empty():
		var lbl := Label.new()
		lbl.text = "현재 모집 가능한 파일럿이 없습니다\n(새로운 섹터를 해금하면 더 많은 파일럿이 등장합니다)"
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.modulate = Color(1, 1, 1, 0.40)
		_card_row.add_child(lbl)
		return

	for pilot_data in board:
		if pilot_data.is_empty():
			continue
		_card_row.add_child(_make_pilot_card(pilot_data))


func _make_pilot_card(p: Dictionary) -> Control:
	var pid:   String = str(p.get("id", ""))
	var hired: bool   = GameState.is_pilot_hired(pid)
	var tier:  int    = int(p.get("tier", 1))
	var cost:  int    = int(p.get("cost", 0))
	var can_afford: bool = GameState.total_credits >= cost

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size   = Vector2(CARD_MIN_W, 0)

	var border_col := _tier_color(tier) if not hired else Color(0.28, 0.70, 0.42)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color     = Color(0.09, 0.13, 0.20, 0.90)
	card_style.border_color = border_col.darkened(0.25)
	card_style.border_width_top = 2
	card_style.set_border_width_all(1)
	card_style.border_width_top = 3
	card_style.set_corner_radius_all(6)
	card_style.content_margin_left   = 14
	card_style.content_margin_right  = 14
	card_style.content_margin_top    = 14
	card_style.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", card_style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)

	# 초상화
	vb.add_child(_make_portrait(p, 64, 20, 22))

	# 이름 + 티어
	var name_lbl := Label.new()
	name_lbl.text = str(p.get("name", ""))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 14)
	vb.add_child(name_lbl)

	var tier_row := HBoxContainer.new()
	tier_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tier_row.add_theme_constant_override("separation", 4)
	vb.add_child(tier_row)

	var tier_lbl := Label.new()
	tier_lbl.text = "T%d" % tier
	tier_lbl.add_theme_font_size_override("font_size", 11)
	tier_lbl.modulate = _tier_color(tier)
	tier_row.add_child(tier_lbl)

	for i in 3:
		var dot := Label.new()
		dot.text = "●" if i < tier else "○"
		dot.add_theme_font_size_override("font_size", 9)
		dot.modulate = _tier_color(tier) if i < tier else Color(1, 1, 1, 0.25)
		tier_row.add_child(dot)

	# 구분선
	var sep := ColorRect.new()
	sep.color = Color(0.22, 0.32, 0.50, 0.45)
	sep.custom_minimum_size = Vector2(0, 1)
	vb.add_child(sep)

	# 보너스
	var bonus_lbl := Label.new()
	bonus_lbl.text = str(p.get("desc", "보너스 없음"))
	bonus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bonus_lbl.add_theme_font_size_override("font_size", 11)
	bonus_lbl.modulate = _bonus_color(str(p.get("bonus_type", "none")))
	vb.add_child(bonus_lbl)

	# 플레이버
	var flavor_lbl := Label.new()
	flavor_lbl.text = '"%s"' % str(p.get("flavor", ""))
	flavor_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flavor_lbl.add_theme_font_size_override("font_size", 10)
	flavor_lbl.modulate = Color(0.65, 0.72, 0.88)
	vb.add_child(flavor_lbl)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)

	# 비용 + 버튼
	var cost_lbl := Label.new()
	cost_lbl.text = "%d CR" % cost
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 12)
	cost_lbl.modulate = Color(0.95, 0.82, 0.40) if can_afford and not hired else Color(1, 1, 1, 0.35)
	vb.add_child(cost_lbl)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 30)
	if hired:
		btn.text = "✓ ON BOARD"
		btn.disabled = true
		btn.modulate = Color(0.38, 0.88, 0.52)
	else:
		btn.text = "고용하기"
		btn.disabled = not can_afford
		btn.pressed.connect(func():
			GameState.hire_pilot(pid)
		)
	vb.add_child(btn)

	return card


# ── 커스텀 파일럿 폼 ──────────────────────────────────────────

var _custom_form: Control = null
var _custom_name: String  = ""
var _custom_color: String = "#44AADD"

const CUSTOM_COLORS: Array = [
	"#DD6644", "#DD9933", "#AACC44",
	"#44AADD", "#7766DD", "#DD4499",
]

func _open_custom_form() -> void:
	if _custom_form != null:
		_custom_form.queue_free()

	_custom_form = _build_custom_form_overlay()
	add_child(_custom_form)


func _build_custom_form_overlay() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.60)
	overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left   = 0.5
	panel.anchor_right  = 0.5
	panel.anchor_top    = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left   = -220.0
	panel.offset_right  =  220.0
	panel.offset_top    = -160.0
	panel.offset_bottom =  160.0
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.08, 0.11, 0.17, 0.98)
	style.border_color = Color(0.30, 0.44, 0.68, 0.80)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left   = 18
	vb.offset_right  = -18
	vb.offset_top    = 14
	vb.offset_bottom = -14
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "커스텀 파일럿 생성"
	title.add_theme_font_size_override("font_size", 14)
	title.modulate = Color(0.82, 0.92, 1.0)
	vb.add_child(title)

	var name_lbl := Label.new()
	name_lbl.text = "이름 (최대 12자)"
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.modulate = Color(0.70, 0.80, 0.98)
	vb.add_child(name_lbl)

	var name_edit := LineEdit.new()
	name_edit.text = _custom_name
	name_edit.placeholder_text = "파일럿 이름 입력"
	name_edit.max_length = 12
	name_edit.text_changed.connect(func(v: String): _custom_name = v)
	vb.add_child(name_edit)

	var color_lbl := Label.new()
	color_lbl.text = "색상"
	color_lbl.add_theme_font_size_override("font_size", 10)
	color_lbl.modulate = Color(0.70, 0.80, 0.98)
	vb.add_child(color_lbl)

	var color_row := HBoxContainer.new()
	color_row.add_theme_constant_override("separation", 8)
	vb.add_child(color_row)
	for hex in CUSTOM_COLORS:
		var cbtn := Button.new()
		cbtn.custom_minimum_size = Vector2(32, 28)
		cbtn.toggle_mode = true
		cbtn.button_pressed = (_custom_color == hex)
		var chip_on  := _make_color_chip(hex, true)
		var chip_off := _make_color_chip(hex, false)
		cbtn.add_theme_stylebox_override("normal",        chip_off)
		cbtn.add_theme_stylebox_override("pressed",       chip_on)
		cbtn.add_theme_stylebox_override("hover_pressed", chip_on)
		var picked: String = hex
		cbtn.pressed.connect(func():
			_custom_color = picked
		)
		color_row.add_child(cbtn)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)

	var hint := Label.new()
	hint.text = "비용: 300 CR  ·  기본 T1 / 보너스 없음"
	hint.add_theme_font_size_override("font_size", 10)
	hint.modulate = Color(0.60, 0.70, 0.88)
	vb.add_child(hint)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	vb.add_child(actions)

	var cancel_btn := Button.new()
	cancel_btn.text = "취소"
	cancel_btn.custom_minimum_size = Vector2(90, 30)
	cancel_btn.pressed.connect(func():
		if _custom_form != null:
			_custom_form.queue_free()
			_custom_form = null
	)
	actions.add_child(cancel_btn)

	var create_btn := Button.new()
	create_btn.text = "생성하기  300 CR"
	create_btn.custom_minimum_size = Vector2(140, 30)
	create_btn.pressed.connect(func():
		if GameState.create_custom_pilot(_custom_name, _custom_color):
			_custom_name = ""
			if _custom_form != null:
				_custom_form.queue_free()
				_custom_form = null
	)
	actions.add_child(create_btn)

	return overlay


# ── 헬퍼 ─────────────────────────────────────────────────────

func _make_portrait(pilot: Dictionary, sz: int, radius: int, font_sz: int) -> Control:
	var col_str: String = str(pilot.get("portrait_color", "#4499DD"))
	var col := Color(col_str) if col_str.begins_with("#") else Color.CORNFLOWER_BLUE
	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = Vector2(sz, sz)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = col.darkened(0.3)
	style.border_color = col
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	portrait.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	var name: String = str(pilot.get("name", "?"))
	lbl.text = name.substr(0, 1) if name.length() > 0 else "?"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.modulate = col.lightened(0.4)
	portrait.add_child(lbl)
	return portrait


func _make_color_chip(hex: String, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(hex)
	style.set_corner_radius_all(4)
	style.set_border_width_all(2 if selected else 0)
	style.border_color = Color.WHITE
	return style


func _tier_color(tier: int) -> Color:
	if tier < 1 or tier > TIER_COLORS.size():
		return Color.WHITE
	return TIER_COLORS[tier - 1]


func _bonus_color(bonus_type: String) -> Color:
	match bonus_type:
		"speed":   return Color(0.55, 0.82, 1.0)
		"credits": return Color(0.55, 1.0,  0.65)
		_:         return Color(0.60, 0.65, 0.75)


func _update_refresh_button() -> void:
	if _refresh_btn == null:
		return
	_refresh_btn.disabled = GameState.total_credits < GameState.BOARD_REFRESH_COST


func _on_board_refreshed() -> void:
	_rebuild_cards()
	_update_refresh_button()


func _on_refresh_tick() -> void:
	if not visible or _timer_label == null:
		return
	var secs := GameState.get_board_next_refresh_secs()
	var h  := secs / 3600
	var m  := (secs % 3600) / 60
	var s  := secs % 60
	_timer_label.text = "갱신 %02d:%02d:%02d" % [h, m, s]
	GameState.ensure_board_fresh()
