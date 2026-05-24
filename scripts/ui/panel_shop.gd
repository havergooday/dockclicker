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

var _current_category: String = "click"
var _cat_buttons: Dictionary = {}
var _content_vbox: VBoxContainer

func _ready() -> void:
	PanelManager.register_panel("shop", self)
	_back_button.pressed.connect(func(): PanelManager.show_bridge())
	GameState.credits_changed.connect(func(_v): _refresh())
	GameState.planet_unlocked.connect(func(_id): _refresh())
	GameState.part_purchased.connect(func(_pt, _t): _refresh())
	_build_layout()
	_select_category("click")

func _build_layout() -> void:
	# Main layout: sidebar + content
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.add_child(hbox)

	# ── Left sidebar ──────────────────────────────────────────
	var sidebar := VBoxContainer.new()
	sidebar.add_theme_constant_override("separation", 6)
	sidebar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sidebar.custom_minimum_size = Vector2(108, 0)
	hbox.add_child(sidebar)

	# Portrait box
	var portrait_panel := PanelContainer.new()
	portrait_panel.custom_minimum_size = Vector2(108, 90)
	var portrait_style := StyleBoxFlat.new()
	portrait_style.bg_color = Color(0.05, 0.09, 0.16)
	portrait_style.border_color = Color(0.25, 0.45, 0.72)
	portrait_style.set_border_width_all(1)
	portrait_style.set_corner_radius_all(4)
	portrait_style.content_margin_top = 8
	portrait_style.content_margin_bottom = 6
	portrait_panel.add_theme_stylebox_override("panel", portrait_style)
	sidebar.add_child(portrait_panel)

	var portrait_inner := VBoxContainer.new()
	portrait_inner.alignment = BoxContainer.ALIGNMENT_CENTER
	portrait_inner.add_theme_constant_override("separation", 4)
	portrait_panel.add_child(portrait_inner)

	var portrait_rect := TextureRect.new()
	portrait_rect.custom_minimum_size = Vector2(48, 48)
	portrait_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait_inner.add_child(portrait_rect)

	var portrait_lbl := Label.new()
	portrait_lbl.text = "COMMANDER"
	portrait_lbl.add_theme_font_size_override("font_size", 9)
	portrait_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_lbl.modulate = Color(0.55, 0.75, 1.0)
	portrait_inner.add_child(portrait_lbl)

	# Divider
	sidebar.add_child(HSeparator.new())

	# Category buttons
	var btn_group := ButtonGroup.new()
	for cat in CATEGORIES:
		var btn := Button.new()
		btn.text = cat["label"]
		btn.toggle_mode = true
		btn.button_group = btn_group
		btn.custom_minimum_size = Vector2(108, 34)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		var norm := StyleBoxFlat.new()
		norm.bg_color = Color(0.08, 0.13, 0.20)
		norm.set_border_width_all(0)
		norm.set_corner_radius_all(3)
		norm.content_margin_left = 10
		btn.add_theme_stylebox_override("normal", norm)

		var sel := StyleBoxFlat.new()
		sel.bg_color = Color(0.10, 0.20, 0.36)
		sel.border_color = Color(0.30, 0.55, 0.92)
		sel.border_width_left = 3
		sel.set_corner_radius_all(3)
		sel.content_margin_left = 10
		btn.add_theme_stylebox_override("pressed", sel)

		var hov := StyleBoxFlat.new()
		hov.bg_color = Color(0.10, 0.17, 0.26)
		hov.set_border_width_all(0)
		hov.set_corner_radius_all(3)
		hov.content_margin_left = 10
		btn.add_theme_stylebox_override("hover", hov)

		btn.add_theme_stylebox_override("hover_pressed", sel.duplicate())

		var cid: String = cat["id"]
		btn.pressed.connect(func(): _select_category(cid))
		_cat_buttons[cid] = btn
		sidebar.add_child(btn)

	# ── Right content area ────────────────────────────────────
	var content_panel := PanelContainer.new()
	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var cp_style := StyleBoxFlat.new()
	cp_style.bg_color = Color(0.04, 0.08, 0.13)
	cp_style.border_color = Color(0.14, 0.24, 0.40)
	cp_style.set_border_width_all(1)
	cp_style.set_corner_radius_all(4)
	cp_style.content_margin_left = 8
	cp_style.content_margin_right = 8
	cp_style.content_margin_top = 8
	cp_style.content_margin_bottom = 8
	content_panel.add_theme_stylebox_override("panel", cp_style)
	hbox.add_child(content_panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_panel.add_child(scroll)

	_content_vbox = VBoxContainer.new()
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(_content_vbox)

# ── Category selection ────────────────────────────────────────

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
	upg_btn.custom_minimum_size = Vector2(110, 30)
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

# ── Inventory content ────────────────────────────────────────

func _build_inventory_content() -> void:
	var has_any := false
	for part_type in ["pilot", "body", "weapon", "legs"]:
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
			s.bg_color = Color(0.07, 0.12, 0.19)
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
	s.bg_color = Color(0.07, 0.12, 0.19)
	s.border_color = _tier_color(tier)
	s.border_width_left = 3
	s.border_width_top = 0
	s.border_width_right = 0
	s.border_width_bottom = 0
	s.set_corner_radius_all(3)
	s.content_margin_left = 10
	s.content_margin_right = 8
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	outer.add_theme_stylebox_override("panel", s)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	outer.add_child(vbox)

	# Top row: tier badge + name + effect
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

	# Bottom row: stock + lock notice + buy button
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
	buy_btn.custom_minimum_size = Vector2(100, 30)
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
	style.bg_color = Color(0.07, 0.12, 0.19)
	style.set_border_width_all(0)
	style.set_corner_radius_all(3)
	style.content_margin_left = 10
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
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
