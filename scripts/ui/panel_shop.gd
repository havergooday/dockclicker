extends Control

@onready var _back_button: Button = $Header/BackButton
@onready var _body: Control = $Body

const CATEGORIES: Array = [
	{"id": "shop",  "label": "강화 · 파츠"},
	{"id": "pilot", "label": "파일럿"},
]

const TIER_COLORS: Array = [
	Color(0.55, 0.55, 0.58, 1.0),
	Color(1.00, 1.00, 1.00, 1.0),
	Color(0.35, 0.65, 1.00, 1.0),
]

const CUSTOM_COLORS: Array = [
	"#DD6644", "#DD9933", "#AACC44",
	"#44AADD", "#7766DD", "#DD4499",
]

const TAB_H   := 28
const LEFT_W  := 340
const RIGHT_W := 300

var _current_category: String   = "shop"
var _cat_buttons:      Dictionary = {}
var _content_area:     Control   = null

# 파일럿 탭
var _pilot_center_mode: String  = "hint"  # hint | detail | custom
var _pilot_selected_id: String  = ""
var _pilot_center_con:  Control = null
var _custom_pilot_name:  String = ""
var _custom_pilot_color: String = "#44AADD"

func _ready() -> void:
	PanelManager.register_panel("shop", self)
	_back_button.pressed.connect(func(): PanelManager.go_back())
	_back_button.text = "← %s" % PanelManager.get_back_label()
	PanelManager.panel_changed.connect(func(id: String):
		if id == "shop": _back_button.text = "← %s" % PanelManager.get_back_label()
	)
	GameState.credits_changed.connect(func(_v): _rebuild_content())
	GameState.planet_unlocked.connect(func(_id): _rebuild_content())
	GameState.part_purchased.connect(func(_pt, _t): _rebuild_content())
	GameState.pilot_hired.connect(func(_id): _rebuild_content())
	GameState.pilot_status_changed.connect(func(_id): _rebuild_content())
	_build_layout()
	_select_category("shop")

# ── 레이아웃 뼈대 ─────────────────────────────────────────────────────

func _build_layout() -> void:
	var tab_bar := HBoxContainer.new()
	tab_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tab_bar.offset_bottom = TAB_H
	tab_bar.add_theme_constant_override("separation", 2)
	_body.add_child(tab_bar)

	var btn_group := ButtonGroup.new()
	for cat in CATEGORIES:
		var btn := Button.new()
		btn.text = cat["label"]
		btn.toggle_mode = true
		btn.button_group = btn_group
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, TAB_H)

		var norm := StyleBoxFlat.new()
		norm.bg_color = Color(0.06, 0.12, 0.18, 0.80)
		norm.border_color = Color(0.15, 0.28, 0.42)
		norm.border_width_bottom = 2
		norm.corner_radius_top_left = 3; norm.corner_radius_top_right = 3
		norm.content_margin_left = 6; norm.content_margin_right = 6
		btn.add_theme_stylebox_override("normal", norm)

		var sel := StyleBoxFlat.new()
		sel.bg_color = Color(0.10, 0.20, 0.36, 0.88)
		sel.border_color = Color(0.30, 0.60, 1.0)
		sel.border_width_bottom = 2
		sel.corner_radius_top_left = 3; sel.corner_radius_top_right = 3
		sel.content_margin_left = 6; sel.content_margin_right = 6
		btn.add_theme_stylebox_override("pressed", sel)
		btn.add_theme_stylebox_override("hover_pressed", sel.duplicate())

		var hov := norm.duplicate() as StyleBoxFlat
		hov.bg_color = Color(0.09, 0.16, 0.26, 0.80)
		hov.border_color = Color(0.22, 0.40, 0.62)
		btn.add_theme_stylebox_override("hover", hov)

		var cid: String = cat["id"]
		btn.pressed.connect(func(): _select_category(cid))
		_cat_buttons[cid] = btn
		tab_bar.add_child(btn)

	_content_area = Control.new()
	_content_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content_area.offset_top = TAB_H + 2
	_body.add_child(_content_area)

func _select_category(cat_id: String) -> void:
	_current_category = cat_id
	if _cat_buttons.has(cat_id):
		(_cat_buttons[cat_id] as Button).set_pressed_no_signal(true)
	_rebuild_content()

func _rebuild_content() -> void:
	for c in _content_area.get_children():
		c.queue_free()
	match _current_category:
		"shop":  _build_shop_content()
		"pilot": _build_pilot_content()

# ── 강화 · 파츠 (합성 탭) ─────────────────────────────────────────────

func _build_shop_content() -> void:
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	_content_area.add_child(hbox)
	_build_click_col(hbox)
	_add_vsep(hbox)
	_build_parts_col(hbox)

# ── 클릭강화 컬럼 ────────────────────────────────────────────────────

func _build_click_col(parent: HBoxContainer) -> void:
	var con := Control.new()
	con.custom_minimum_size = Vector2(220, 0)
	con.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(con)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 18; vb.offset_right = -18
	vb.offset_top = 0; vb.offset_bottom = 0
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	con.add_child(vb)

	var level  := GameState.damage_upgrade_level
	var damage := GameState.click_damage
	var cost   := GameState.get_damage_upgrade_cost()

	# 스탯 표시
	var stat_vb := VBoxContainer.new()
	stat_vb.add_theme_constant_override("separation", 4)
	vb.add_child(stat_vb)

	var dmg_lbl := Label.new()
	dmg_lbl.text = "데미지  %d" % damage
	dmg_lbl.add_theme_font_size_override("font_size", 18)
	stat_vb.add_child(dmg_lbl)

	var lvl_lbl := Label.new()
	lvl_lbl.text = "단계  %d / %d" % [level, GameState.DAMAGE_UPGRADE_COSTS.size()]
	lvl_lbl.add_theme_font_size_override("font_size", 11)
	lvl_lbl.modulate = Color(0.55, 0.60, 0.76)
	stat_vb.add_child(lvl_lbl)

	# 강화 버튼
	var upg_btn := Button.new()
	upg_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upg_btn.custom_minimum_size = Vector2(0, 32)
	if cost < 0:
		upg_btn.text = "최대 달성"
		upg_btn.disabled = true
	else:
		upg_btn.text = "강화   %d CR" % cost
		upg_btn.disabled = GameState.total_credits < cost
	upg_btn.pressed.connect(func():
		GameState.upgrade_click_damage()
		_rebuild_content()
	)
	vb.add_child(upg_btn)

# ── 파츠 구매 컬럼 ───────────────────────────────────────────────────

func _build_parts_col(parent: HBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 4)
	scroll.add_child(vb)

	for part_type in ["body", "weapon", "legs"]:
		_add_parts_section(vb, part_type)

# ── 파일럿 ────────────────────────────────────────────────────────────

func _build_pilot_content() -> void:
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	_content_area.add_child(hbox)

	var left := _build_pilot_left()
	left.custom_minimum_size = Vector2(LEFT_W, 0)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(left)

	_add_vsep(hbox)

	var center_con := Control.new()
	center_con.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_con.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	hbox.add_child(center_con)
	_pilot_center_con = center_con
	_refresh_pilot_center()

	_add_vsep(hbox)

	var right := _build_pilot_right()
	right.custom_minimum_size = Vector2(RIGHT_W, 0)
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(right)

func _build_pilot_left() -> Control:
	var con := Control.new()
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 10; vb.offset_right = -10
	vb.offset_top = 8;   vb.offset_bottom = -8
	vb.add_theme_constant_override("separation", 6)
	con.add_child(vb)

	vb.add_child(_make_section_label("고용 가능"))

	var any_hirable := false
	for pilot_data in GameState.PILOTS:
		var pid: String = pilot_data["id"]
		if GameState.is_pilot_hired(pid): continue
		any_hirable = true
		vb.add_child(_make_pilot_pool_card(pilot_data))

	if not any_hirable:
		var done_lbl := Label.new()
		done_lbl.text = "모든 파일럿 고용 완료"
		done_lbl.modulate = Color(1, 1, 1, 0.28)
		done_lbl.add_theme_font_size_override("font_size", 11)
		vb.add_child(done_lbl)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)

	var custom_btn := Button.new()
	custom_btn.text = "+ 커스텀 파일럿 생성  ▶"
	custom_btn.add_theme_font_size_override("font_size", 11)
	custom_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_btn.custom_minimum_size = Vector2(0, 28)
	custom_btn.pressed.connect(func():
		_pilot_selected_id  = ""
		_pilot_center_mode = "custom"
		_refresh_pilot_center()
	)
	vb.add_child(custom_btn)
	return con

func _make_pilot_pool_card(pilot_data: Dictionary) -> Control:
	var pid: String = pilot_data["id"]
	var tier: int   = int(pilot_data.get("tier", 1))
	var tcol        := _tier_color(tier)

	var btn := Button.new()
	btn.text = ""
	btn.custom_minimum_size = Vector2(0, 48)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var sty := StyleBoxFlat.new()
	sty.bg_color      = Color(0.07, 0.11, 0.19, 0.85)
	sty.border_color  = tcol.darkened(0.25)
	sty.border_width_left = 3; sty.set_corner_radius_all(4)
	sty.content_margin_left = 10; sty.content_margin_right = 8
	sty.content_margin_top = 6; sty.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", sty)

	var sty_hov := sty.duplicate() as StyleBoxFlat
	sty_hov.bg_color     = Color(0.11, 0.17, 0.30, 0.92)
	sty_hov.border_color = tcol
	btn.add_theme_stylebox_override("hover",   sty_hov)
	btn.add_theme_stylebox_override("pressed", sty)
	btn.add_theme_stylebox_override("focus",   sty)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(row)

	row.add_child(_make_portrait_small(pilot_data))

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = str(pilot_data.get("name", ""))
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(name_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "T%d  %s" % [tier, str(pilot_data.get("desc", ""))]
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.modulate = tcol.lerp(Color.WHITE, 0.3)
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(sub_lbl)

	btn.pressed.connect(func():
		_pilot_selected_id = pid
		_pilot_center_mode = "detail"
		_refresh_pilot_center()
	)
	return btn

func _build_pilot_right() -> Control:
	var con := Control.new()
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 10; vb.offset_right = -10
	vb.offset_top = 8;   vb.offset_bottom = -8
	vb.add_theme_constant_override("separation", 6)
	con.add_child(vb)

	vb.add_child(_make_section_label("내 파견단"))

	if GameState.hired_pilots.is_empty():
		var lbl := Label.new()
		lbl.text = "고용된 파일럿 없음"
		lbl.modulate = Color(1, 1, 1, 0.25)
		lbl.add_theme_font_size_override("font_size", 11)
		vb.add_child(lbl)
	else:
		for p in GameState.hired_pilots:
			vb.add_child(_make_hired_card(p))
	return con

func _make_hired_card(pilot: Dictionary) -> Control:
	var tier: int    = int(pilot.get("tier", 1))
	var is_idle: bool = pilot.get("status", "idle") == "idle"
	var tcol         := _tier_color(tier)

	var outer := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color     = Color(0.06, 0.10, 0.16, 0.80)
	s.border_color = tcol if is_idle else tcol.darkened(0.45)
	s.border_width_left = 3; s.set_corner_radius_all(4)
	s.content_margin_left = 10; s.content_margin_right = 8
	s.content_margin_top = 5; s.content_margin_bottom = 5
	outer.add_theme_stylebox_override("panel", s)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	outer.add_child(row)

	row.add_child(_make_portrait_small(pilot))

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = str(pilot.get("name", ""))
	name_lbl.add_theme_font_size_override("font_size", 12)
	if not is_idle: name_lbl.modulate = Color(0.6, 0.6, 0.6)
	info.add_child(name_lbl)

	var bonus_type: String = pilot.get("bonus_type", "none")
	if bonus_type != "none":
		var bl := Label.new()
		bl.text = str(pilot.get("desc", ""))
		bl.add_theme_font_size_override("font_size", 10)
		bl.modulate = Color(0.65, 0.85, 1.0) if bonus_type == "speed" else Color(0.65, 1.0, 0.70)
		info.add_child(bl)

	var st_lbl := Label.new()
	st_lbl.text    = "대기중" if is_idle else "파견중"
	st_lbl.add_theme_font_size_override("font_size", 11)
	st_lbl.modulate = Color(0.40, 0.90, 0.55) if is_idle else Color(0.95, 0.70, 0.25)
	row.add_child(st_lbl)

	return outer

func _refresh_pilot_center() -> void:
	if _pilot_center_con == null or not is_instance_valid(_pilot_center_con): return
	for c in _pilot_center_con.get_children():
		c.queue_free()
	match _pilot_center_mode:
		"hint":   _build_pilot_hint()
		"detail": _build_pilot_detail()
		"custom": _build_pilot_custom_form()

func _build_pilot_hint() -> void:
	var lbl := Label.new()
	lbl.text = "파일럿을 선택하세요"
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.modulate = Color(1, 1, 1, 0.22)
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pilot_center_con.add_child(lbl)

func _build_pilot_detail() -> void:
	var pilot_data := GameState.get_pilot_data(_pilot_selected_id)
	if pilot_data.is_empty(): return
	var tier: int     = int(pilot_data.get("tier", 1))
	var is_hired: bool = GameState.is_pilot_hired(_pilot_selected_id)
	var tcol          := _tier_color(tier)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 24; vb.offset_right = -24
	vb.offset_top = 16;  vb.offset_bottom = -16
	vb.add_theme_constant_override("separation", 8)
	_pilot_center_con.add_child(vb)

	var portrait_row := HBoxContainer.new()
	portrait_row.add_theme_constant_override("separation", 16)
	vb.add_child(portrait_row)

	portrait_row.add_child(_make_portrait_large(pilot_data))

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait_row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = str(pilot_data.get("name", ""))
	name_lbl.add_theme_font_size_override("font_size", 17)
	info.add_child(name_lbl)

	var tier_lbl := Label.new()
	tier_lbl.text = "Tier %d" % tier
	tier_lbl.add_theme_font_size_override("font_size", 11)
	tier_lbl.modulate = tcol
	info.add_child(tier_lbl)

	var bonus_type: String = pilot_data.get("bonus_type", "none")
	var bonus_lbl := Label.new()
	bonus_lbl.text = str(pilot_data.get("desc", ""))
	bonus_lbl.add_theme_font_size_override("font_size", 12)
	if bonus_type == "speed":
		bonus_lbl.modulate = Color(0.65, 0.85, 1.0)
	elif bonus_type == "credits":
		bonus_lbl.modulate = Color(0.65, 1.0, 0.70)
	else:
		bonus_lbl.modulate = Color(0.50, 0.52, 0.55)
	info.add_child(bonus_lbl)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)

	if is_hired:
		var lbl := Label.new()
		lbl.text = "✓ 이미 고용된 파일럿"
		lbl.modulate = Color(0.38, 0.88, 0.52)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vb.add_child(lbl)
	else:
		var cost: int   = int(pilot_data.get("cost", 0))
		var pid: String = _pilot_selected_id
		var hire_btn    := Button.new()
		hire_btn.text = "고용하기   %d CR" % cost
		hire_btn.custom_minimum_size = Vector2(160, 32)
		hire_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
		hire_btn.disabled = GameState.total_credits < cost
		hire_btn.pressed.connect(func():
			_pilot_center_mode = "hint"
			_pilot_selected_id = ""
			GameState.hire_pilot(pid)
		)
		vb.add_child(hire_btn)

func _build_pilot_custom_form() -> void:
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 24; vb.offset_right = -24
	vb.offset_top = 16;  vb.offset_bottom = -16
	vb.add_theme_constant_override("separation", 10)
	_pilot_center_con.add_child(vb)

	var title := Label.new()
	title.text = "커스텀 파일럿 생성"
	title.add_theme_font_size_override("font_size", 13)
	title.modulate = Color(0.75, 0.78, 0.95)
	vb.add_child(title)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	vb.add_child(name_row)

	var name_hint := Label.new()
	name_hint.text = "이름"
	name_hint.custom_minimum_size = Vector2(32, 0)
	name_hint.add_theme_font_size_override("font_size", 11)
	name_hint.modulate = Color(0.55, 0.55, 0.72)
	name_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(name_hint)

	var name_edit := LineEdit.new()
	name_edit.text = _custom_pilot_name
	name_edit.placeholder_text = "파일럿 이름 입력"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.max_length = 12
	name_edit.text_changed.connect(func(v: String): _custom_pilot_name = v)
	name_row.add_child(name_edit)

	var color_row := HBoxContainer.new()
	color_row.add_theme_constant_override("separation", 6)
	vb.add_child(color_row)

	var col_hint := Label.new()
	col_hint.text = "색상"
	col_hint.custom_minimum_size = Vector2(32, 0)
	col_hint.add_theme_font_size_override("font_size", 11)
	col_hint.modulate = Color(0.55, 0.55, 0.72)
	col_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	color_row.add_child(col_hint)

	for hex in CUSTOM_COLORS:
		var cbtn := Button.new()
		cbtn.custom_minimum_size = Vector2(24, 24)
		cbtn.toggle_mode = true
		cbtn.button_pressed = (_custom_pilot_color == hex)
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(hex); bs.set_corner_radius_all(3); bs.set_border_width_all(0)
		cbtn.add_theme_stylebox_override("normal", bs)
		var bss := bs.duplicate() as StyleBoxFlat
		bss.set_border_width_all(2); bss.border_color = Color.WHITE
		cbtn.add_theme_stylebox_override("pressed",       bss)
		cbtn.add_theme_stylebox_override("hover_pressed", bss.duplicate())
		var cap_hex: String = hex
		cbtn.pressed.connect(func():
			_custom_pilot_color = cap_hex
			_refresh_pilot_center()
		)
		color_row.add_child(cbtn)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)

	var create_btn := Button.new()
	create_btn.text = "생성하기   300 CR"
	create_btn.custom_minimum_size = Vector2(160, 32)
	create_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	create_btn.disabled = GameState.total_credits < 300
	create_btn.pressed.connect(func():
		var n := _custom_pilot_name
		var c := _custom_pilot_color
		_pilot_center_mode = "hint"
		_custom_pilot_name = ""
		GameState.create_custom_pilot(n, c)
	)
	vb.add_child(create_btn)

func _add_parts_section(parent: VBoxContainer, part_type: String) -> void:
	if part_type not in GameState.PARTS: return
	var data: Dictionary  = GameState.PARTS[part_type]
	var tiers: Array      = data["tiers"]
	var type_names        := {"body": "몸체", "weapon": "무기", "legs": "다리"}

	var sec_con := Control.new()
	sec_con.custom_minimum_size = Vector2(0, 16)
	sec_con.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sec_con)

	var sec_lbl := Label.new()
	sec_lbl.text = type_names.get(part_type, part_type)
	sec_lbl.add_theme_font_size_override("font_size", 10)
	sec_lbl.modulate = Color(0.45, 0.55, 0.75)
	sec_lbl.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	sec_lbl.offset_right = 50; sec_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sec_con.add_child(sec_lbl)

	var line := ColorRect.new()
	line.color = Color(0.22, 0.30, 0.48, 0.45)
	line.anchor_right = 1.0; line.offset_left = 54
	line.anchor_bottom = 0.0; line.offset_top = 7; line.offset_bottom = 8
	sec_con.add_child(line)

	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 10)
	parent.add_child(card_row)

	for i in tiers.size():
		card_row.add_child(_make_parts_shop_card(part_type, i + 1, tiers[i], data))

func _make_parts_shop_card(part_type: String, tier: int, tier_data: Dictionary, part_data: Dictionary) -> Control:
	var req: String   = tier_data.get("required_planet", "")
	var locked: bool  = req != "" and not GameState.is_planet_unlocked(req)
	var cost: int     = tier_data["cost"]
	var tcol          := _tier_color(tier)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(140, 0)
	var s := StyleBoxFlat.new()
	s.bg_color     = Color(0.07, 0.10, 0.18, 0.88)
	s.border_color = tcol.darkened(0.35) if locked else tcol.darkened(0.12)
	s.set_border_width_all(1); s.set_corner_radius_all(5)
	s.content_margin_left = 10; s.content_margin_right = 10
	s.content_margin_top = 8;   s.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", s)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)

	var tier_lbl := Label.new()
	tier_lbl.text = "T%d" % tier
	tier_lbl.add_theme_font_size_override("font_size", 11)
	tier_lbl.modulate = tcol if not locked else Color(1, 1, 1, 0.25)
	vb.add_child(tier_lbl)

	var name_lbl := Label.new()
	name_lbl.text = tier_data.get("name", "파츠 T%d" % tier)
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.modulate = Color(0.88, 0.92, 1.0) if not locked else Color(1, 1, 1, 0.25)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(name_lbl)

	var eff_lbl := Label.new()
	eff_lbl.text = part_data["effect"] % tier_data["value"]
	eff_lbl.add_theme_font_size_override("font_size", 11)
	eff_lbl.modulate = Color(0.50, 0.78, 1.0) if not locked else Color(1, 1, 1, 0.18)
	vb.add_child(eff_lbl)

	if locked:
		var planet_data := GameState.get_planet(req)
		var lock_lbl := Label.new()
		lock_lbl.text = "🔒 %s" % planet_data.get("name", req)
		lock_lbl.add_theme_font_size_override("font_size", 10)
		lock_lbl.modulate = Color(0.90, 0.65, 0.20)
		vb.add_child(lock_lbl)
	else:
		var stock_lbl := Label.new()
		stock_lbl.text = "보유: %d" % GameState.get_owned_qty(part_type, tier)
		stock_lbl.add_theme_font_size_override("font_size", 10)
		stock_lbl.modulate = Color(0.48, 0.54, 0.66)
		vb.add_child(stock_lbl)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)

	var buy_btn := Button.new()
	buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_btn.custom_minimum_size = Vector2(0, 24)
	if locked:
		buy_btn.text = "미해금"
		buy_btn.disabled = true
	else:
		buy_btn.text = "%d CR" % cost
		buy_btn.disabled = GameState.total_credits < cost
	var pt := part_type; var t := tier
	buy_btn.pressed.connect(func():
		GameState.buy_part(pt, t)
		_rebuild_content()
	)
	vb.add_child(buy_btn)
	return panel

# ── 공통 헬퍼 ────────────────────────────────────────────────────────

func _make_section_label(text: String) -> Control:
	var con := Control.new()
	con.custom_minimum_size = Vector2(0, 18)
	con.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.modulate = Color(0.45, 0.55, 0.75)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	lbl.offset_right = 60; lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	con.add_child(lbl)

	var line := ColorRect.new()
	line.color = Color(0.22, 0.30, 0.48, 0.45)
	line.anchor_right = 1.0; line.offset_left = 64
	line.anchor_bottom = 0.0; line.offset_top = 8; line.offset_bottom = 9
	con.add_child(line)
	return con

func _make_info_card() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.12, 0.19, 0.80)
	style.set_border_width_all(1); style.border_color = Color(0.18, 0.28, 0.46)
	style.set_corner_radius_all(5)
	style.content_margin_left = 14; style.content_margin_right = 14
	style.content_margin_top = 10;  style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	return panel

func _make_portrait_small(pilot: Dictionary) -> Control:
	return _make_portrait(pilot, 32, 16, 13)

func _make_portrait_large(pilot: Dictionary) -> Control:
	return _make_portrait(pilot, 62, 31, 22)

func _make_portrait(pilot: Dictionary, sz: int, radius: int, font_sz: int) -> Control:
	var col_str: String = pilot.get("portrait_color", "#4499DD")
	var col := Color(col_str) if col_str.begins_with("#") else Color.CORNFLOWER_BLUE
	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = Vector2(sz, sz)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ps := StyleBoxFlat.new()
	ps.bg_color = col.darkened(0.3); ps.border_color = col
	ps.set_border_width_all(2); ps.set_corner_radius_all(radius)
	portrait.add_theme_stylebox_override("panel", ps)
	var lbl := Label.new()
	var name: String = pilot.get("name", "?")
	lbl.text = name.substr(0, 1) if name.length() > 0 else "?"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.modulate = col.lightened(0.4)
	portrait.add_child(lbl)
	return portrait

func _add_vsep(parent: HBoxContainer) -> void:
	var sep := ColorRect.new()
	sep.color = Color(0.20, 0.26, 0.42, 0.50)
	sep.custom_minimum_size = Vector2(1, 0)
	sep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(sep)

func _tier_color(tier: int) -> Color:
	if tier < 1 or tier > TIER_COLORS.size(): return Color.WHITE
	return TIER_COLORS[tier - 1]
