extends Control

# ── 상수 ─────────────────────────────────────────────────────
const POPUP_W_RATIO := 0.72
const ANIM_DURATION := 0.20
const CARD_NAV_DUR  := 0.14
const ART_W         := 240   # 전신 아트 존 너비
const ROW1_H        := 62    # 초상화+이름 행 높이
const ACTION_H      := 36    # 비용+버튼 행 높이
const HIRE_BAR_W    := 88    # 우측 고용 버튼 폭

const TIER_COLORS: Array = [
	Color(0.55, 0.55, 0.58),
	Color(1.00, 1.00, 1.00),
	Color(0.95, 0.76, 0.28),
]
const CUSTOM_COLORS: Array = [
	"#DD6644", "#DD9933", "#AACC44",
	"#44AADD", "#7766DD", "#DD4499",
]

# ── 노드 참조 ─────────────────────────────────────────────────
var _panel:          Control       = null
var _timer_label:    Label         = null
var _refresh_btn:    Button        = null
var _refresh_timer:  Timer         = null
var _custom_form:    Control       = null
var _card_container: Control       = null
var _nav_prev:       Button        = null
var _nav_next:       Button        = null
var _page_dots:      HBoxContainer = null

var _popup_w:      float  = 0.0
var _custom_name:  String = ""
var _custom_color: String = "#44AADD"
var _board_data:   Array  = []
var _current_idx:  int    = 0
var _navigating:   bool   = false


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	_build_ui()
	GameState.board_refreshed.connect(_on_board_refreshed)
	GameState.credits_changed.connect(func(_v): _update_refresh_button(); _refresh_card())
	GameState.planet_unlocked.connect(func(_id): _on_board_refreshed())


# ── 공개 API ──────────────────────────────────────────────────

func open_popup() -> void:
	GameState.ensure_board_fresh()
	_board_data = _filtered_board()
	_current_idx = 0
	_refresh_card()
	_update_refresh_button()
	visible = true
	_panel.position.y = -_panel.size.y - 10.0
	var tween := create_tween()
	tween.tween_property(_panel, "position:y", 0.0, ANIM_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func close_popup() -> void:
	if _custom_form != null:
		_custom_form.queue_free()
		_custom_form = null
	var tween := create_tween()
	tween.tween_property(_panel, "position:y", -_panel.size.y - 10.0, ANIM_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): visible = false)


# ── UI 빌드 ───────────────────────────────────────────────────

func _build_ui() -> void:
	_popup_w = get_viewport_rect().size.x * POPUP_W_RATIO

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			close_popup()
	)
	add_child(dim)

	_panel = Control.new()
	_panel.anchor_left   = 0.5
	_panel.anchor_right  = 0.5
	_panel.anchor_top    = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left   = -_popup_w * 0.5
	_panel.offset_right  =  _popup_w * 0.5
	_panel.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color     = Color(0.07, 0.10, 0.15, 0.97)
	bg_style.border_color = Color(0.26, 0.40, 0.62, 0.80)
	bg_style.set_border_width_all(1)
	var panel_bg := PanelContainer.new()
	panel_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_bg.add_theme_stylebox_override("panel", bg_style)
	panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(panel_bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left   = 16
	root.offset_right  = -16
	root.offset_top    = 8
	root.offset_bottom = -8
	root.add_theme_constant_override("separation", 6)
	root.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(root)

	root.add_child(_build_top_bar())
	root.add_child(_build_viewer_section())
	root.add_child(_build_custom_row())

	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = 1.0
	_refresh_timer.autostart = true
	_refresh_timer.timeout.connect(_on_refresh_tick)
	add_child(_refresh_timer)


func _build_top_bar() -> Control:
	var hb := HBoxContainer.new()
	hb.custom_minimum_size = Vector2(0, 26)
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var left := HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	hb.add_child(left)

	_timer_label = Label.new()
	_timer_label.text = "--:--:--"
	_timer_label.add_theme_font_size_override("font_size", 10)
	_timer_label.modulate = Color(0.55, 0.65, 0.82)
	_timer_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_timer_label.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	left.add_child(_timer_label)

	var center := Control.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(center)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(24, 24)
	close_btn.pressed.connect(func(): close_popup())
	center.add_child(close_btn)

	var right := HBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	hb.add_child(right)

	_refresh_btn = Button.new()
	_refresh_btn.text = "새로고침  %d CR" % GameState.BOARD_REFRESH_COST
	_refresh_btn.custom_minimum_size = Vector2(130, 24)
	_refresh_btn.add_theme_font_size_override("font_size", 10)
	_refresh_btn.pressed.connect(func(): GameState.refresh_board_paid())
	right.add_child(_refresh_btn)

	return hb


func _build_viewer_section() -> Control:
	var section := VBoxContainer.new()
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 6)
	section.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 카드 컨테이너 — 카드가 이 안을 꽉 채움
	_card_container = Control.new()
	_card_container.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_card_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_container.clip_contents         = true
	_card_container.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	section.add_child(_card_container)

	# 내비 행: ◀이전   ●○○   다음▶
	var nav_hb := HBoxContainer.new()
	nav_hb.custom_minimum_size = Vector2(0, 30)
	nav_hb.add_theme_constant_override("separation", 8)
	nav_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section.add_child(nav_hb)

	_nav_prev = Button.new()
	_nav_prev.text = "◀  이전"
	_nav_prev.custom_minimum_size = Vector2(90, 28)
	_nav_prev.add_theme_font_size_override("font_size", 11)
	_nav_prev.pressed.connect(func(): _navigate(-1))
	nav_hb.add_child(_nav_prev)

	var spacer_l := Control.new()
	spacer_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_hb.add_child(spacer_l)

	_page_dots = HBoxContainer.new()
	_page_dots.alignment            = BoxContainer.ALIGNMENT_CENTER
	_page_dots.size_flags_vertical  = Control.SIZE_SHRINK_CENTER
	_page_dots.add_theme_constant_override("separation", 7)
	_page_dots.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	nav_hb.add_child(_page_dots)

	var spacer_r := Control.new()
	spacer_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_hb.add_child(spacer_r)

	_nav_next = Button.new()
	_nav_next.text = "다음  ▶"
	_nav_next.custom_minimum_size = Vector2(90, 28)
	_nav_next.add_theme_font_size_override("font_size", 11)
	_nav_next.pressed.connect(func(): _navigate(1))
	nav_hb.add_child(_nav_next)

	return section


func _build_custom_row() -> Control:
	var btn := Button.new()
	btn.text = "+ 커스텀 파일럿 생성  300 CR"
	btn.custom_minimum_size = Vector2(0, 24)
	btn.add_theme_font_size_override("font_size", 10)
	btn.pressed.connect(_open_custom_form)
	return btn


# ── 카드 관리 ─────────────────────────────────────────────────

func _filtered_board() -> Array:
	var out: Array = []
	for d in GameState.get_board_pilot_data():
		if not d.is_empty():
			out.append(d)
	return out


func _clear_card() -> void:
	for c in _card_container.get_children():
		_card_container.remove_child(c)
		c.queue_free()


func _refresh_card() -> void:
	_clear_card()
	_place_card()


func _place_card() -> void:
	var count := _board_data.size()

	if count == 0:
		var lbl := Label.new()
		lbl.text = "현재 모집 가능한 파일럿이 없습니다\n새 섹터를 해금하면 더 많은 파일럿이 등장합니다"
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.modulate = Color(1, 1, 1, 0.40)
		lbl.set_anchors_preset(Control.PRESET_CENTER)
		_card_container.add_child(lbl)
		if _nav_prev != null: _nav_prev.visible = false
		if _nav_next != null: _nav_next.visible = false
		_update_page_dots(0, 0)
		return

	_current_idx = clampi(_current_idx, 0, count - 1)
	var card := _make_pilot_card(_board_data[_current_idx])
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_container.add_child(card)

	if _nav_prev != null: _nav_prev.visible = count > 1
	if _nav_next != null: _nav_next.visible = count > 1
	_update_page_dots(_current_idx, count)


func _navigate(dir: int) -> void:
	if _navigating:
		return
	var count := _board_data.size()
	if count <= 1:
		return

	_navigating = true
	_current_idx = (_current_idx + dir + count) % count

	# 기존 카드 슬라이드아웃
	var old_card: Control = null
	for c in _card_container.get_children():
		old_card = c
		break

	_place_card()

	# 새 카드 슬라이드인 (컨테이너 너비 기반)
	var new_card: Control = null
	for c in _card_container.get_children():
		new_card = c
		break

	var slide_w := _popup_w * 0.9
	if new_card != null:
		new_card.position.x = slide_w * dir
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(new_card, "position:x", 0.0, CARD_NAV_DUR) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if old_card != null and is_instance_valid(old_card):
			tween.tween_property(old_card, "position:x", -slide_w * dir, CARD_NAV_DUR) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(func():
			if old_card != null and is_instance_valid(old_card):
				old_card.queue_free()
			_navigating = false
		)
	else:
		if old_card != null: old_card.queue_free()
		_navigating = false


func _update_page_dots(current: int, total: int) -> void:
	for c in _page_dots.get_children():
		c.queue_free()
	for i in total:
		var dot := Label.new()
		dot.text = "●" if i == current else "○"
		dot.add_theme_font_size_override("font_size", 9)
		dot.modulate = Color(0.65, 0.85, 1.0) if i == current else Color(0.30, 0.42, 0.65)
		_page_dots.add_child(dot)


# ── 카드 빌더 ─────────────────────────────────────────────────

func _make_pilot_card(p: Dictionary) -> Control:
	var pid:        String = str(p.get("id", ""))
	var hired:      bool   = GameState.is_pilot_hired(pid)
	var tier:       int    = int(p.get("tier", 1))
	var cost:       int    = int(p.get("cost", 0))
	var can_afford: bool   = GameState.total_credits >= cost
	var col_str:    String = str(p.get("portrait_color", "#4499DD"))
	var col        := Color(col_str) if col_str.begins_with("#") else Color.CORNFLOWER_BLUE
	var accent     := _tier_color(tier) if not hired else Color(0.28, 0.70, 0.42)

	var card := Control.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	# 카드 배경
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cs := StyleBoxFlat.new()
	cs.bg_color         = Color(0.08, 0.12, 0.20, 0.97)
	cs.border_color     = accent.darkened(0.10)
	cs.set_border_width_all(1)
	cs.border_width_top = 3
	cs.set_corner_radius_all(6)
	bg.add_theme_stylebox_override("panel", cs)
	card.add_child(bg)

	# 내부 HBox (전신 | 구분선 | 우측패널 | 구분선 | 고용버튼)
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 0)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hb)

	hb.add_child(_make_art_zone(p, col))

	var vsep := ColorRect.new()
	vsep.color = Color(0.20, 0.30, 0.50, 0.35)
	vsep.custom_minimum_size = Vector2(1, 0)
	vsep.size_flags_vertical  = Control.SIZE_EXPAND_FILL
	hb.add_child(vsep)

	# 우측 VBox (3행)
	var right_vb := VBoxContainer.new()
	right_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vb.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	right_vb.add_theme_constant_override("separation", 0)
	right_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(right_vb)

	right_vb.add_child(_make_row1(p, hired, tier))

	var sep1 := _make_hsep()
	right_vb.add_child(sep1)

	right_vb.add_child(_make_row2(p))

	var sep2 := _make_hsep()
	right_vb.add_child(sep2)

	right_vb.add_child(_make_row3(cost))

	var vsep2 := ColorRect.new()
	vsep2.color = Color(0.20, 0.30, 0.50, 0.35)
	vsep2.custom_minimum_size = Vector2(1, 0)
	vsep2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_child(vsep2)

	hb.add_child(_make_hire_bar(pid, hired, can_afford))

	return card


func _make_art_zone(p: Dictionary, col: Color) -> Control:
	var zone := Control.new()
	zone.custom_minimum_size = Vector2(ART_W, 0)
	zone.size_flags_vertical  = Control.SIZE_EXPAND_FILL
	zone.mouse_filter         = Control.MOUSE_FILTER_IGNORE

	# 배경
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = col.darkened(0.62)
	zone.add_child(bg)

	# 좌상단 둥근 코너 재현용 (panel_bg의 코너가 bg에 겹치도록)
	# → 그냥 일체형 배경으로 처리, 바깥 카드 bg에서 corner 담당

	# 전신 플레이스홀더: 중앙 세로 rect
	var body := ColorRect.new()
	body.color = col.darkened(0.44)
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.offset_left   = 24
	body.offset_right  = -24
	body.offset_top    = 16
	body.offset_bottom = -16
	zone.add_child(body)

	# 전신 라벨
	var lbl := Label.new()
	lbl.text = "전신"
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.modulate = col.lightened(0.12)
	zone.add_child(lbl)

	return zone


func _make_row1(p: Dictionary, hired: bool, tier: int) -> Control:
	var hb := HBoxContainer.new()
	hb.custom_minimum_size = Vector2(0, ROW1_H)
	hb.add_theme_constant_override("separation", 0)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 초상화 (패딩 포함 MarginContainer)
	var portrait_margin := MarginContainer.new()
	portrait_margin.add_theme_constant_override("margin_left",   14)
	portrait_margin.add_theme_constant_override("margin_right",  12)
	portrait_margin.add_theme_constant_override("margin_top",    10)
	portrait_margin.add_theme_constant_override("margin_bottom", 10)
	portrait_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait := _make_portrait(p, 40, 11, 12)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait_margin.add_child(portrait)
	hb.add_child(portrait_margin)

	# 이름 / 티어 / 상태
	var info_margin := MarginContainer.new()
	info_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_margin.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	info_margin.add_theme_constant_override("margin_left",   0)
	info_margin.add_theme_constant_override("margin_right",  14)
	info_margin.add_theme_constant_override("margin_top",    10)
	info_margin.add_theme_constant_override("margin_bottom", 8)
	info_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(info_margin)

	var info_vb := VBoxContainer.new()
	info_vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_vb.add_theme_constant_override("separation", 3)
	info_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_margin.add_child(info_vb)

	var name_lbl := Label.new()
	name_lbl.text = str(p.get("name", ""))
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.modulate = Color(0.92, 0.96, 1.0)
	info_vb.add_child(name_lbl)

	var tier_hb := HBoxContainer.new()
	tier_hb.add_theme_constant_override("separation", 4)
	tier_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vb.add_child(tier_hb)

	var tier_lbl := Label.new()
	tier_lbl.text = "TIER %d" % tier
	tier_lbl.add_theme_font_size_override("font_size", 10)
	tier_lbl.modulate = _tier_color(tier)
	tier_hb.add_child(tier_lbl)

	for i in 3:
		var dot := Label.new()
		dot.text = "●" if i < tier else "○"
		dot.add_theme_font_size_override("font_size", 8)
		dot.modulate = _tier_color(tier) if i < tier else Color(1, 1, 1, 0.22)
		tier_hb.add_child(dot)

	var status_lbl := Label.new()
	status_lbl.add_theme_font_size_override("font_size", 9)
	if hired:
		status_lbl.text    = "✓ ON BOARD"
		status_lbl.modulate = Color(0.38, 0.88, 0.52)
	else:
		status_lbl.text    = "모집 가능"
		status_lbl.modulate = Color(0.40, 0.58, 0.88)
	info_vb.add_child(status_lbl)

	return hb


func _make_row2(p: Dictionary) -> Control:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left",   16)
	margin.add_theme_constant_override("margin_right",  14)
	margin.add_theme_constant_override("margin_top",    10)
	margin.add_theme_constant_override("margin_bottom",  8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vb := VBoxContainer.new()
	vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vb)

	var bonus_lbl := Label.new()
	bonus_lbl.text = str(p.get("desc", "보너스 없음"))
	bonus_lbl.add_theme_font_size_override("font_size", 12)
	bonus_lbl.modulate = _bonus_color(str(p.get("bonus_type", "none")))
	vb.add_child(bonus_lbl)

	var sep := ColorRect.new()
	sep.color = Color(0.22, 0.32, 0.50, 0.32)
	sep.custom_minimum_size = Vector2(0, 1)
	vb.add_child(sep)

	var flavor_lbl := Label.new()
	flavor_lbl.text = '"%s"' % str(p.get("flavor", ""))
	flavor_lbl.add_theme_font_size_override("font_size", 11)
	flavor_lbl.modulate = Color(0.52, 0.64, 0.88)
	flavor_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(flavor_lbl)

	return margin


func _make_row3(cost: int) -> Control:
	var hb := HBoxContainer.new()
	hb.custom_minimum_size = Vector2(0, ACTION_H)
	hb.add_theme_constant_override("separation", 0)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var lpad := Control.new()
	lpad.custom_minimum_size = Vector2(16, 0)
	hb.add_child(lpad)

	var cost_lbl := Label.new()
	cost_lbl.text = "%d CR" % cost
	cost_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_lbl.add_theme_font_size_override("font_size", 13)
	cost_lbl.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	cost_lbl.modulate = Color(0.95, 0.82, 0.40)
	hb.add_child(cost_lbl)

	var rpad := Control.new()
	rpad.custom_minimum_size = Vector2(14, 0)
	hb.add_child(rpad)

	return hb


func _make_hire_bar(pid: String, hired: bool, can_afford: bool) -> Control:
	var wrap := MarginContainer.new()
	wrap.custom_minimum_size = Vector2(HIRE_BAR_W, 0)
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("margin_left", 10)
	wrap.add_theme_constant_override("margin_right", 14)
	wrap.add_theme_constant_override("margin_top", 8)
	wrap.add_theme_constant_override("margin_bottom", 8)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var btn := Button.new()
	btn.text = "고용"
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(func(): GameState.hire_pilot(pid))
	btn.disabled = hired or not can_afford

	if hired:
		btn.text = "고용됨"
		btn.modulate = Color(0.38, 0.88, 0.52)

	wrap.add_child(btn)
	return wrap


func _make_hsep() -> ColorRect:
	var sep := ColorRect.new()
	sep.color = Color(0.20, 0.30, 0.50, 0.28)
	sep.custom_minimum_size = Vector2(0, 1)
	return sep


# ── 커스텀 파일럿 폼 ──────────────────────────────────────────

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
	dim.color = Color(0, 0, 0, 0.65)
	overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left   = 0.5
	panel.anchor_right  = 0.5
	panel.anchor_top    = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left   = -220.0
	panel.offset_right  =  220.0
	panel.offset_top    = -110.0
	panel.offset_bottom =  110.0
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.08, 0.11, 0.17, 0.98)
	style.border_color = Color(0.30, 0.44, 0.68, 0.80)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left   = 14
	vb.offset_right  = -14
	vb.offset_top    = 10
	vb.offset_bottom = -10
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vb.add_child(title_row)

	var title := Label.new()
	title.text = "커스텀 파일럿 생성"
	title.add_theme_font_size_override("font_size", 13)
	title.modulate = Color(0.82, 0.92, 1.0)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var cancel_x := Button.new()
	cancel_x.text = "✕"
	cancel_x.custom_minimum_size = Vector2(22, 22)
	cancel_x.pressed.connect(func():
		if _custom_form != null:
			_custom_form.queue_free()
			_custom_form = null
	)
	title_row.add_child(cancel_x)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	vb.add_child(name_row)

	var name_lbl := Label.new()
	name_lbl.text = "이름"
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.modulate = Color(0.70, 0.80, 0.98)
	name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(name_lbl)

	var name_edit := LineEdit.new()
	name_edit.text             = _custom_name
	name_edit.placeholder_text = "파일럿 이름 입력 (최대 12자)"
	name_edit.max_length       = 12
	name_edit.custom_minimum_size    = Vector2(0, 26)
	name_edit.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(v: String): _custom_name = v)
	name_row.add_child(name_edit)

	var color_row := HBoxContainer.new()
	color_row.add_theme_constant_override("separation", 6)
	vb.add_child(color_row)

	var color_lbl := Label.new()
	color_lbl.text = "색상"
	color_lbl.add_theme_font_size_override("font_size", 10)
	color_lbl.modulate = Color(0.70, 0.80, 0.98)
	color_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	color_row.add_child(color_lbl)

	for hex in CUSTOM_COLORS:
		var cbtn := Button.new()
		cbtn.custom_minimum_size = Vector2(28, 24)
		cbtn.toggle_mode    = true
		cbtn.button_pressed = (_custom_color == hex)
		cbtn.add_theme_stylebox_override("normal",        _make_color_chip(hex, false))
		cbtn.add_theme_stylebox_override("pressed",       _make_color_chip(hex, true))
		cbtn.add_theme_stylebox_override("hover_pressed", _make_color_chip(hex, true))
		var picked: String = hex
		cbtn.pressed.connect(func(): _custom_color = picked)
		color_row.add_child(cbtn)

	var hint := Label.new()
	hint.text = "T1 기본 파일럿  ·  보너스 없음  ·  300 CR"
	hint.add_theme_font_size_override("font_size", 9)
	hint.modulate = Color(0.55, 0.65, 0.85)
	vb.add_child(hint)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	vb.add_child(actions)

	var cancel_btn := Button.new()
	cancel_btn.text = "취소"
	cancel_btn.custom_minimum_size = Vector2(80, 26)
	cancel_btn.add_theme_font_size_override("font_size", 10)
	cancel_btn.pressed.connect(func():
		if _custom_form != null:
			_custom_form.queue_free()
			_custom_form = null
	)
	actions.add_child(cancel_btn)

	var create_btn := Button.new()
	create_btn.text = "생성하기  300 CR"
	create_btn.custom_minimum_size = Vector2(130, 26)
	create_btn.add_theme_font_size_override("font_size", 10)
	create_btn.disabled = GameState.total_credits < 300
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
	portrait.custom_minimum_size   = Vector2(sz, sz)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color     = col.darkened(0.3)
	style.border_color = col
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	portrait.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	var n: String = str(pilot.get("name", "?"))
	lbl.text                 = n.substr(0, 1) if n.length() > 0 else "?"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.modulate = col.lightened(0.4)
	portrait.add_child(lbl)
	return portrait


func _make_color_chip(hex: String, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(hex)
	style.set_corner_radius_all(3)
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
		_:         return Color(0.58, 0.64, 0.78)


func _update_refresh_button() -> void:
	if _refresh_btn == null:
		return
	_refresh_btn.disabled = GameState.total_credits < GameState.BOARD_REFRESH_COST


func _on_board_refreshed() -> void:
	_board_data  = _filtered_board()
	_current_idx = 0
	_refresh_card()
	_update_refresh_button()


func _on_refresh_tick() -> void:
	if not visible or _timer_label == null:
		return
	var secs := GameState.get_board_next_refresh_secs()
	var h := secs / 3600
	var m := (secs % 3600) / 60
	var s := secs % 60
	_timer_label.text = "%02d:%02d:%02d" % [h, m, s]
	GameState.ensure_board_fresh()
