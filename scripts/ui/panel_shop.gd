extends Control

@onready var _back_button: Button = $Header/BackButton
@onready var _body: Control = $Body

const CATEGORIES: Array = [
	{"id": "click",     "label": "클릭강화"},
	{"id": "pilot",     "label": "파일럿"},
	{"id": "body",      "label": "몸체"},
	{"id": "weapon",    "label": "무기"},
	{"id": "legs",      "label": "다리"},
	{"id": "inventory", "label": "보유 파츠"},
]

const TIER_COLORS: Array = [
	Color(0.55, 0.55, 0.55),  # T1 — gray
	Color(0.90, 0.90, 0.90),  # T2 — white
	Color(0.30, 0.55, 0.95),  # T3 — blue
]

const CUSTOM_COLORS: Array = [
	"#DD6644", "#DD9933", "#AACC44",
	"#44AADD", "#7766DD", "#DD4499",
]

var _current_category: String = "click"
var _cat_buttons: Dictionary = {}
var _content_vbox: VBoxContainer
var _custom_pilot_name: String = ""
var _custom_pilot_color: String = "#44AADD"

func _ready() -> void:
	PanelManager.register_panel("shop", self)
	_back_button.pressed.connect(func(): PanelManager.show_bridge())
	GameState.credits_changed.connect(func(_v): _refresh())
	GameState.planet_unlocked.connect(func(_id): _refresh())
	GameState.part_purchased.connect(func(_pt, _t): _refresh())
	GameState.pilot_hired.connect(func(_id): _rebuild_content())
	GameState.pilot_status_changed.connect(func(_id): _rebuild_content())
	_build_layout()
	_select_category("click")

func _build_layout() -> void:
	# ── 상단 가로 탭바 ────────────────────────────────────────
	var tab_bar := HBoxContainer.new()
	tab_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tab_bar.offset_bottom = 26.0
	tab_bar.add_theme_constant_override("separation", 2)
	_body.add_child(tab_bar)

	var btn_group := ButtonGroup.new()
	for cat in CATEGORIES:
		var btn := Button.new()
		btn.text = cat["label"]
		btn.toggle_mode = true
		btn.button_group = btn_group
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 26)

		var norm := StyleBoxFlat.new()
		norm.bg_color = Color(0.06, 0.12, 0.18, 0.80)
		norm.border_color = Color(0.15, 0.28, 0.42)
		norm.border_width_bottom = 2
		norm.corner_radius_top_left    = 3
		norm.corner_radius_top_right   = 3
		norm.content_margin_left  = 6
		norm.content_margin_right = 6
		btn.add_theme_stylebox_override("normal", norm)

		var sel := StyleBoxFlat.new()
		sel.bg_color = Color(0.10, 0.20, 0.36, 0.88)
		sel.border_color = Color(0.30, 0.60, 1.0)
		sel.border_width_bottom = 2
		sel.corner_radius_top_left    = 3
		sel.corner_radius_top_right   = 3
		sel.content_margin_left  = 6
		sel.content_margin_right = 6
		btn.add_theme_stylebox_override("pressed",       sel)
		btn.add_theme_stylebox_override("hover_pressed", sel.duplicate())

		var hov := StyleBoxFlat.new()
		hov.bg_color = Color(0.09, 0.16, 0.26, 0.80)
		hov.border_color = Color(0.22, 0.40, 0.62)
		hov.border_width_bottom = 2
		hov.corner_radius_top_left    = 3
		hov.corner_radius_top_right   = 3
		hov.content_margin_left  = 6
		hov.content_margin_right = 6
		btn.add_theme_stylebox_override("hover", hov)

		var cid: String = cat["id"]
		btn.pressed.connect(func(): _select_category(cid))
		_cat_buttons[cid] = btn
		tab_bar.add_child(btn)

	# ── 콘텐츠 영역 ───────────────────────────────────────────
	var content_panel := PanelContainer.new()
	content_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_panel.offset_top = 30.0
	var cp_style := StyleBoxFlat.new()
	cp_style.bg_color = Color(0.04, 0.08, 0.13, 0.80)
	cp_style.border_color = Color(0.14, 0.24, 0.40)
	cp_style.set_border_width_all(1)
	cp_style.set_corner_radius_all(3)
	cp_style.content_margin_left   = 10
	cp_style.content_margin_right  = 10
	cp_style.content_margin_top    = 6
	cp_style.content_margin_bottom = 6
	content_panel.add_theme_stylebox_override("panel", cp_style)
	_body.add_child(content_panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	content_panel.add_child(scroll)

	_content_vbox = VBoxContainer.new()
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_theme_constant_override("separation", 5)
	scroll.add_child(_content_vbox)

# ── Category selection ────────────────────────────────────────────

func _select_category(cat_id: String) -> void:
	_current_category = cat_id
	if _cat_buttons.has(cat_id):
		(_cat_buttons[cat_id] as Button).set_pressed_no_signal(true)
	_rebuild_content()

func _rebuild_content() -> void:
	for c in _content_vbox.get_children():
		c.queue_free()
	match _current_category:
		"click":
			_build_click_content()
		"pilot":
			_build_pilot_content()
		"inventory":
			_build_inventory_content()
		_:
			_build_parts_content(_current_category)

# ── Click upgrade content ────────────────────────────────────

func _build_click_content() -> void:
	var level := GameState.damage_upgrade_level
	var damage := GameState.click_damage
	var cost := GameState.get_damage_upgrade_cost()

	var info_card := _make_card()
	var info_inner: VBoxContainer = info_card.get_child(0) as VBoxContainer
	var info_lbl := Label.new()
	info_lbl.text = "현재 클릭 데미지:  %d\n강화 단계:  %d / %d" % [damage, level, GameState.DAMAGE_UPGRADE_COSTS.size()]
	info_lbl.add_theme_font_size_override("font_size", 13)
	info_inner.add_child(info_lbl)
	_content_vbox.add_child(info_card)

	var upg_card := _make_card()
	var upg_inner: VBoxContainer = upg_card.get_child(0) as VBoxContainer
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	upg_inner.add_child(row)

	var desc := Label.new()
	desc.text = "클릭 데미지 +1 강화"
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(desc)

	var upg_btn := Button.new()
	upg_btn.custom_minimum_size = Vector2(100, 26)
	if cost < 0:
		upg_btn.text = "최대 달성"
		upg_btn.disabled = true
	else:
		upg_btn.text = "%d CR" % cost
		upg_btn.disabled = GameState.total_credits < cost
	upg_btn.pressed.connect(func():
		GameState.upgrade_click_damage()
		_rebuild_content()
	)
	row.add_child(upg_btn)
	_content_vbox.add_child(upg_card)

# ── Pilot content ─────────────────────────────────────────────

func _build_pilot_content() -> void:
	# ── 고용 가능 파일럿 (고정 풀) ──────────────────────────
	var section_lbl := Label.new()
	section_lbl.text = "── 파일럿 고용 ──"
	section_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section_lbl.add_theme_font_size_override("font_size", 11)
	section_lbl.modulate = Color(0.55, 0.65, 0.85)
	_content_vbox.add_child(section_lbl)

	var avail_any := false
	for pilot_data in GameState.PILOTS:
		var pid: String = pilot_data["id"]
		if GameState.is_pilot_hired(pid):
			continue
		avail_any = true
		_content_vbox.add_child(_make_pilot_hire_card(pilot_data))

	if not avail_any:
		var lbl := Label.new()
		lbl.text = "모든 파일럿 고용 완료"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.modulate = Color(1, 1, 1, 0.35)
		lbl.add_theme_font_size_override("font_size", 12)
		_content_vbox.add_child(lbl)

	# ── 커스텀 파일럿 생성 ───────────────────────────────────
	_content_vbox.add_child(HSeparator.new())
	_content_vbox.add_child(_make_custom_pilot_card())

	# ── 내 파견단 ────────────────────────────────────────────
	if GameState.hired_pilots.size() > 0:
		_content_vbox.add_child(HSeparator.new())
		var roster_lbl := Label.new()
		roster_lbl.text = "── 내 파견단 ──"
		roster_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		roster_lbl.add_theme_font_size_override("font_size", 11)
		roster_lbl.modulate = Color(0.55, 0.65, 0.85)
		_content_vbox.add_child(roster_lbl)
		for p in GameState.hired_pilots:
			_content_vbox.add_child(_make_hired_pilot_card(p))

func _make_pilot_hire_card(pilot_data: Dictionary) -> Control:
	var outer := PanelContainer.new()
	var s := StyleBoxFlat.new()
	var tier: int = int(pilot_data.get("tier", 1))
	s.bg_color = Color(0.07, 0.12, 0.19, 0.85)
	s.border_color = _tier_color(tier)
	s.border_width_left = 3
	s.border_width_top = 0
	s.border_width_right = 0
	s.border_width_bottom = 0
	s.set_corner_radius_all(4)
	s.content_margin_left = 10
	s.content_margin_right = 8
	s.content_margin_top = 7
	s.content_margin_bottom = 7
	outer.add_theme_stylebox_override("panel", s)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	outer.add_child(row)

	# Portrait
	row.add_child(_make_portrait(pilot_data))

	# Info
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	info.add_child(name_row)

	var name_lbl := Label.new()
	name_lbl.text = str(pilot_data.get("name", ""))
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_row.add_child(name_lbl)

	var tier_lbl := Label.new()
	tier_lbl.text = "T%d" % tier
	tier_lbl.add_theme_font_size_override("font_size", 11)
	tier_lbl.modulate = _tier_color(tier)
	name_row.add_child(tier_lbl)

	var bonus_type: String = pilot_data.get("bonus_type", "none")
	if bonus_type != "none":
		var bonus_lbl := Label.new()
		bonus_lbl.text = str(pilot_data.get("desc", ""))
		bonus_lbl.add_theme_font_size_override("font_size", 11)
		bonus_lbl.modulate = Color(0.65, 0.85, 1.0) if bonus_type == "speed" else Color(0.65, 1.0, 0.70)
		info.add_child(bonus_lbl)
	else:
		var desc_lbl := Label.new()
		desc_lbl.text = str(pilot_data.get("desc", ""))
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.modulate = Color(0.55, 0.55, 0.55)
		info.add_child(desc_lbl)

	# Hire button
	var cost: int = int(pilot_data.get("cost", 0))
	var hire_btn := Button.new()
	hire_btn.text = "%d CR  고용" % cost
	hire_btn.custom_minimum_size = Vector2(110, 28)
	hire_btn.disabled = GameState.total_credits < cost
	var pid: String = pilot_data.get("id", "")
	hire_btn.pressed.connect(func():
		GameState.hire_pilot(pid)
	)
	row.add_child(hire_btn)

	return outer

func _make_custom_pilot_card() -> Control:
	var outer := _make_card()
	var inner: VBoxContainer = outer.get_child(0) as VBoxContainer

	var title_lbl := Label.new()
	title_lbl.text = "── 커스텀 파일럿 생성  (300 CR) ──"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 11)
	title_lbl.modulate = Color(0.72, 0.72, 0.85)
	inner.add_child(title_lbl)

	# Name input row
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	inner.add_child(name_row)

	var name_hint := Label.new()
	name_hint.text = "이름"
	name_hint.add_theme_font_size_override("font_size", 11)
	name_hint.modulate = Color(0.55, 0.55, 0.72)
	name_hint.custom_minimum_size = Vector2(28, 0)
	name_row.add_child(name_hint)

	var name_edit := LineEdit.new()
	name_edit.text = _custom_pilot_name
	name_edit.placeholder_text = "파일럿 이름 입력"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.max_length = 12
	name_edit.text_changed.connect(func(v: String): _custom_pilot_name = v)
	name_row.add_child(name_edit)

	# Color picker row
	var color_row := HBoxContainer.new()
	color_row.add_theme_constant_override("separation", 4)
	inner.add_child(color_row)

	var col_hint := Label.new()
	col_hint.text = "색상"
	col_hint.add_theme_font_size_override("font_size", 11)
	col_hint.modulate = Color(0.55, 0.55, 0.72)
	col_hint.custom_minimum_size = Vector2(28, 0)
	color_row.add_child(col_hint)

	for hex in CUSTOM_COLORS:
		var cbtn := Button.new()
		cbtn.custom_minimum_size = Vector2(22, 22)
		cbtn.toggle_mode = true
		cbtn.button_pressed = (_custom_pilot_color == hex)
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(hex)
		btn_style.set_corner_radius_all(3)
		btn_style.set_border_width_all(0)
		cbtn.add_theme_stylebox_override("normal", btn_style)
		var sel_style := StyleBoxFlat.new()
		sel_style.bg_color = Color(hex)
		sel_style.set_corner_radius_all(3)
		sel_style.set_border_width_all(2)
		sel_style.border_color = Color.WHITE
		cbtn.add_theme_stylebox_override("pressed", sel_style)
		cbtn.add_theme_stylebox_override("hover_pressed", sel_style.duplicate())
		var cap_hex: String = hex
		cbtn.pressed.connect(func():
			_custom_pilot_color = cap_hex
			_rebuild_content()
		)
		color_row.add_child(cbtn)

	# Create button
	var create_btn := Button.new()
	create_btn.text = "생성  ▶"
	create_btn.custom_minimum_size = Vector2(100, 26)
	create_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	create_btn.disabled = GameState.total_credits < 300
	create_btn.pressed.connect(func():
		if GameState.create_custom_pilot(_custom_pilot_name, _custom_pilot_color):
			_custom_pilot_name = ""
			_rebuild_content()
	)
	inner.add_child(create_btn)

	return outer

func _make_hired_pilot_card(pilot: Dictionary) -> Control:
	var outer := PanelContainer.new()
	var s := StyleBoxFlat.new()
	var tier: int = int(pilot.get("tier", 1))
	var status: String = pilot.get("status", "idle")
	s.bg_color = Color(0.06, 0.10, 0.16, 0.80)
	s.border_color = _tier_color(tier).darkened(0.3) if status != "idle" else _tier_color(tier)
	s.border_width_left = 3
	s.border_width_top = 0
	s.border_width_right = 0
	s.border_width_bottom = 0
	s.set_corner_radius_all(4)
	s.content_margin_left = 10
	s.content_margin_right = 8
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	outer.add_theme_stylebox_override("panel", s)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	outer.add_child(row)

	row.add_child(_make_portrait(pilot))

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = str(pilot.get("name", ""))
	name_lbl.add_theme_font_size_override("font_size", 12)
	if status != "idle":
		name_lbl.modulate = Color(0.6, 0.6, 0.6)
	info.add_child(name_lbl)

	var bonus_type: String = pilot.get("bonus_type", "none")
	if bonus_type != "none":
		var bl := Label.new()
		bl.text = str(pilot.get("desc", ""))
		bl.add_theme_font_size_override("font_size", 10)
		bl.modulate = Color(0.65, 0.85, 1.0) if bonus_type == "speed" else Color(0.65, 1.0, 0.70)
		info.add_child(bl)

	var status_lbl := Label.new()
	status_lbl.text = "대기중" if status == "idle" else "파견중"
	status_lbl.add_theme_font_size_override("font_size", 11)
	status_lbl.modulate = Color(0.45, 0.90, 0.55) if status == "idle" else Color(0.95, 0.70, 0.25)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(status_lbl)

	return outer

func _make_portrait(pilot: Dictionary) -> Control:
	var col_str: String = pilot.get("portrait_color", "#4499DD")
	var col := Color(col_str) if col_str.begins_with("#") else Color.CORNFLOWER_BLUE

	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = Vector2(36, 36)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ps := StyleBoxFlat.new()
	ps.bg_color = col.darkened(0.3)
	ps.border_color = col
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(18)
	portrait.add_theme_stylebox_override("panel", ps)

	var initial_lbl := Label.new()
	var name: String = pilot.get("name", "?")
	initial_lbl.text = name.substr(0, 1) if name.length() > 0 else "?"
	initial_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial_lbl.add_theme_font_size_override("font_size", 14)
	initial_lbl.modulate = col.lightened(0.4)
	portrait.add_child(initial_lbl)

	return portrait

# ── Inventory content ────────────────────────────────────────

func _build_inventory_content() -> void:
	var has_any := false
	for part_type in ["body", "weapon", "legs"]:
		var data: Dictionary = GameState.PARTS[part_type]
		var tiers: Array = data["tiers"]
		for i in tiers.size():
			var qty := GameState.get_owned_qty(part_type, i + 1)
			if qty <= 0:
				continue
			has_any = true
			var tier := i + 1
			var tier_data: Dictionary = tiers[i]

			var card := PanelContainer.new()
			var s := StyleBoxFlat.new()
			s.bg_color = Color(0.07, 0.12, 0.19, 0.80)
			s.border_color = _tier_color(tier)
			s.border_width_left = 3
			s.border_width_top = 0
			s.border_width_right = 0
			s.border_width_bottom = 0
			s.set_corner_radius_all(3)
			s.content_margin_left = 10
			s.content_margin_right = 8
			s.content_margin_top = 7
			s.content_margin_bottom = 7
			card.add_theme_stylebox_override("panel", s)

			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			card.add_child(row)

			var type_lbl := Label.new()
			type_lbl.text = data["name"]
			type_lbl.custom_minimum_size = Vector2(36, 0)
			type_lbl.modulate = Color(0.55, 0.55, 0.55)
			type_lbl.add_theme_font_size_override("font_size", 11)
			row.add_child(type_lbl)

			var tier_lbl := Label.new()
			tier_lbl.text = "T%d" % tier
			tier_lbl.custom_minimum_size = Vector2(22, 0)
			tier_lbl.modulate = _tier_color(tier)
			tier_lbl.add_theme_font_size_override("font_size", 11)
			row.add_child(tier_lbl)

			var name_lbl := Label.new()
			name_lbl.text = tier_data["name"]
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_lbl.add_theme_font_size_override("font_size", 13)
			row.add_child(name_lbl)

			var eff_lbl := Label.new()
			eff_lbl.text = data["effect"] % tier_data["value"]
			eff_lbl.modulate = Color(0.65, 0.85, 1.0)
			eff_lbl.add_theme_font_size_override("font_size", 11)
			row.add_child(eff_lbl)

			var qty_lbl := Label.new()
			qty_lbl.text = "×%d" % qty
			qty_lbl.custom_minimum_size = Vector2(32, 0)
			qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			qty_lbl.modulate = Color(0.9, 0.9, 0.7)
			qty_lbl.add_theme_font_size_override("font_size", 13)
			row.add_child(qty_lbl)

			_content_vbox.add_child(card)

	if not has_any:
		var empty_card := _make_card()
		var lbl := Label.new()
		lbl.text = "보유한 파츠 없음"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.modulate = Color(1, 1, 1, 0.4)
		(empty_card.get_child(0) as VBoxContainer).add_child(lbl)
		_content_vbox.add_child(empty_card)

# ── Parts content ─────────────────────────────────────────────

func _build_parts_content(part_type: String) -> void:
	if part_type not in GameState.PARTS:
		return
	var data: Dictionary = GameState.PARTS[part_type]
	var tiers: Array = data["tiers"]
	for i in tiers.size():
		var tier := i + 1
		var tier_data: Dictionary = tiers[i]
		_content_vbox.add_child(_make_part_card(part_type, tier, tier_data, data))

func _make_part_card(part_type: String, tier: int, tier_data: Dictionary, part_data: Dictionary) -> Control:
	var outer := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.07, 0.12, 0.19, 0.80)
	s.border_color = _tier_color(tier)
	s.border_width_left = 3
	s.border_width_top = 0
	s.border_width_right = 0
	s.border_width_bottom = 0
	s.set_corner_radius_all(3)
	s.content_margin_left = 10
	s.content_margin_right = 8
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	outer.add_theme_stylebox_override("panel", s)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	outer.add_child(vbox)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	vbox.add_child(top)

	var t_lbl := Label.new()
	t_lbl.text = "T%d" % tier
	t_lbl.custom_minimum_size = Vector2(22, 0)
	t_lbl.modulate = _tier_color(tier)
	t_lbl.add_theme_font_size_override("font_size", 11)
	top.add_child(t_lbl)

	var name_lbl := Label.new()
	name_lbl.text = tier_data["name"]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 13)
	top.add_child(name_lbl)

	var eff_lbl := Label.new()
	eff_lbl.text = part_data["effect"] % tier_data["value"]
	eff_lbl.modulate = Color(0.65, 0.85, 1.0)
	eff_lbl.add_theme_font_size_override("font_size", 11)
	top.add_child(eff_lbl)

	var bot := HBoxContainer.new()
	bot.add_theme_constant_override("separation", 8)
	vbox.add_child(bot)

	var qty := GameState.get_owned_qty(part_type, tier)
	var stock_lbl := Label.new()
	stock_lbl.text = "보유: %d" % qty
	stock_lbl.custom_minimum_size = Vector2(64, 0)
	stock_lbl.modulate = Color(0.55, 0.55, 0.55)
	stock_lbl.add_theme_font_size_override("font_size", 11)
	bot.add_child(stock_lbl)

	var req: String = tier_data.get("required_planet", "")
	if req != "":
		var planet_data: Dictionary = GameState.get_planet(req)
		var req_lbl := Label.new()
		req_lbl.text = "요구: %s" % planet_data.get("name", req)
		req_lbl.modulate = Color(0.9, 0.65, 0.25)
		req_lbl.add_theme_font_size_override("font_size", 11)
		req_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bot.add_child(req_lbl)
	else:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bot.add_child(spacer)

	var locked: bool = req != "" and not GameState.is_planet_unlocked(req)
	var buy_btn := Button.new()
	buy_btn.custom_minimum_size = Vector2(90, 26)
	if locked:
		buy_btn.text = "행성 미해금"
		buy_btn.disabled = true
	else:
		buy_btn.text = "%d CR" % tier_data["cost"]
		buy_btn.disabled = GameState.total_credits < tier_data["cost"]

	var pt := part_type
	var t: int = tier
	buy_btn.pressed.connect(func():
		GameState.buy_part(pt, t)
		_rebuild_content()
	)
	bot.add_child(buy_btn)

	return outer

# ── Helpers ───────────────────────────────────────────────────

func _make_card() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.12, 0.19, 0.80)
	style.set_border_width_all(0)
	style.set_corner_radius_all(3)
	style.content_margin_left = 10
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	return panel

func _tier_color(tier: int) -> Color:
	if tier < 1 or tier > TIER_COLORS.size():
		return Color.WHITE
	return TIER_COLORS[tier - 1]

func _refresh() -> void:
	if not is_node_ready():
		return
	_rebuild_content()
