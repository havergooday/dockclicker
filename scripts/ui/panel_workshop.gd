extends Control

@onready var back_button: Button = $Header/BackButton
@onready var _body: Control = $Body

const PART_LABELS: Dictionary = {"body": "몸체", "weapon": "무기", "legs": "다리"}

const TIER_COLORS: Array = [
	Color(0.5,  0.5,  0.5,  1.0),  # Tier 1 — gray
	Color(1.0,  1.0,  1.0,  1.0),  # Tier 2 — white
	Color(0.35, 0.65, 1.0,  1.0),  # Tier 3 — blue
]

var _current_tab: int = 0
var _tab_inv_btn: Button
var _tab_asm_btn: Button

# ── 파츠 목록 탭 ──────────────────────────────────────────
var _tab_inv_panel: Control
var _item_grid: GridContainer
var _detail_vbox: VBoxContainer
var _sel_part_type: String = ""
var _sel_part_tier: int = -1

# ── 파츠 조립 탭 ──────────────────────────────────────────
var _tab_asm_panel: Control
var _col_slots_inner: VBoxContainer
var _col_body_inner: VBoxContainer
var _col_weapon_inner: VBoxContainer
var _col_legs_inner: VBoxContainer
var _col_specs_inner: VBoxContainer
var _asm_sel := {"body": 0, "weapon": 0, "legs": 0}
var _asm_slot: int = -1
var _asm_btn: Button = null

func _ready() -> void:
	PanelManager.register_panel("workshop", self)
	back_button.pressed.connect(func(): PanelManager.show_bridge())
	GameState.part_purchased.connect(func(_pt, _t): _refresh_current_tab())
	GameState.auto_slot_changed.connect(func(_i): _refresh_current_tab())
	GameState.credits_changed.connect(func(_v): _update_asm_cost())
	visibility_changed.connect(func():
		if visible:
			_apply_preselect()
	)
	_build_tab_bar()
	_build_inventory_panel()
	_build_assembly_panel()
	_switch_tab(0)

func _apply_preselect() -> void:
	var presel := GameState.workshop_preselect_slot
	if presel >= 0:
		GameState.workshop_preselect_slot = -1
		_asm_slot = presel
		_switch_tab(1)

# ── 탭 전환 ───────────────────────────────────────────────

func _build_tab_bar() -> void:
	var tab_bar := HBoxContainer.new()
	tab_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tab_bar.offset_bottom = 28.0
	tab_bar.add_theme_constant_override("separation", 4)
	_body.add_child(tab_bar)

	_tab_inv_btn = Button.new()
	_tab_inv_btn.text = "파츠 목록"
	_tab_inv_btn.toggle_mode = true
	_tab_inv_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_inv_btn.pressed.connect(func(): _switch_tab(0))
	tab_bar.add_child(_tab_inv_btn)

	_tab_asm_btn = Button.new()
	_tab_asm_btn.text = "파츠 조립"
	_tab_asm_btn.toggle_mode = true
	_tab_asm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_asm_btn.pressed.connect(func(): _switch_tab(1))
	tab_bar.add_child(_tab_asm_btn)

func _switch_tab(tab: int) -> void:
	_current_tab = tab
	_tab_inv_btn.set_pressed_no_signal(tab == 0)
	_tab_asm_btn.set_pressed_no_signal(tab == 1)
	_tab_inv_panel.visible = (tab == 0)
	_tab_asm_panel.visible = (tab == 1)
	_refresh_current_tab()

func _refresh_current_tab() -> void:
	if not is_node_ready():
		return
	if _current_tab == 0:
		_refresh_inventory()
	else:
		_refresh_assembly()

# ── 파츠 목록 탭 ──────────────────────────────────────────

func _build_inventory_panel() -> void:
	_tab_inv_panel = Control.new()
	_tab_inv_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tab_inv_panel.offset_top = 32.0
	_body.add_child(_tab_inv_panel)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 6)
	_tab_inv_panel.add_child(hbox)

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_stretch_ratio = 1.0
	hbox.add_child(left_scroll)

	_item_grid = GridContainer.new()
	_item_grid.columns = 2
	_item_grid.add_theme_constant_override("h_separation", 4)
	_item_grid.add_theme_constant_override("v_separation", 4)
	_item_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(_item_grid)

	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 1.1
	right_panel.custom_minimum_size = Vector2(110, 0)
	hbox.add_child(right_panel)

	_detail_vbox = VBoxContainer.new()
	_detail_vbox.add_theme_constant_override("separation", 5)
	right_panel.add_child(_detail_vbox)

func _refresh_inventory() -> void:
	for child in _item_grid.get_children():
		child.queue_free()

	var found_sel := false
	for part_type in ["pilot", "body", "weapon", "legs"]:
		var qtys: Array = GameState.owned_parts[part_type]
		for i: int in qtys.size():
			var qty: int = qtys[i]
			if qty <= 0:
				continue
			var pt := i + 1
			var is_sel: bool = (_sel_part_type == part_type and _sel_part_tier == pt)
			if is_sel:
				found_sel = true
			for _j in qty:
				_item_grid.add_child(_make_item_box(part_type, pt, is_sel))

	if not found_sel:
		_sel_part_type = ""
		_sel_part_tier = -1
	_refresh_detail()

func _make_item_box(part_type: String, tier: int, is_sel: bool) -> Button:
	var data: Dictionary = GameState.PARTS[part_type]
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(48, 48)
	btn.text = "%s\nLv.%d" % [data["name"], tier]

	btn.add_theme_stylebox_override("normal",  _tier_stylebox(tier, is_sel, false))
	btn.add_theme_stylebox_override("hover",   _tier_stylebox(tier, is_sel, true))
	btn.add_theme_stylebox_override("pressed", _tier_stylebox(tier, true,  false))
	btn.add_theme_stylebox_override("focus",   _tier_stylebox(tier, is_sel, false))

	var cap_type := part_type
	var cap_tier := tier
	btn.pressed.connect(func():
		_sel_part_type = cap_type
		_sel_part_tier = cap_tier
		_refresh_inventory()
	)
	return btn

func _tier_stylebox(tier: int, selected: bool, hover: bool) -> StyleBoxFlat:
	var tier_color: Color = TIER_COLORS[mini(tier - 1, TIER_COLORS.size() - 1)]
	var s := StyleBoxFlat.new()
	s.border_color = tier_color
	var bw := 3 if selected else 2
	s.border_width_left   = bw
	s.border_width_right  = bw
	s.border_width_top    = bw
	s.border_width_bottom = bw
	var base_bg := Color(0.22, 0.18, 0.40, 0.85) if selected else Color(0.10, 0.10, 0.16, 0.78)
	s.bg_color = base_bg.lightened(0.08) if hover else base_bg
	s.corner_radius_top_left     = 3
	s.corner_radius_top_right    = 3
	s.corner_radius_bottom_left  = 3
	s.corner_radius_bottom_right = 3
	s.content_margin_left   = 3
	s.content_margin_right  = 3
	s.content_margin_top    = 3
	s.content_margin_bottom = 3
	return s

func _refresh_detail() -> void:
	for child in _detail_vbox.get_children():
		child.queue_free()

	if _sel_part_type == "" or _sel_part_tier < 1:
		var hint := Label.new()
		hint.text = "파츠를\n선택하세요"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.modulate = Color(1, 1, 1, 0.4)
		hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_detail_vbox.add_child(hint)
		return

	var data: Dictionary = GameState.PARTS[_sel_part_type]
	var td: Dictionary = data["tiers"][_sel_part_tier - 1]
	var tier_color: Color = TIER_COLORS[mini(_sel_part_tier - 1, TIER_COLORS.size() - 1)]

	var name_lbl := Label.new()
	name_lbl.text = td["name"]
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_color_override("font_color", tier_color)
	_detail_vbox.add_child(name_lbl)

	var type_lbl := Label.new()
	type_lbl.text = "%s  Lv.%d" % [data["name"], _sel_part_tier]
	type_lbl.modulate = Color(1, 1, 1, 0.6)
	type_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_vbox.add_child(type_lbl)

	_detail_vbox.add_child(HSeparator.new())

	var eff_lbl := Label.new()
	eff_lbl.text = data["effect"] % td["value"]
	eff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_vbox.add_child(eff_lbl)

	var qty: int = GameState.owned_parts[_sel_part_type][_sel_part_tier - 1]
	var qty_lbl := Label.new()
	qty_lbl.text = "보유: %d" % qty
	qty_lbl.modulate = Color(1, 1, 1, 0.7)
	_detail_vbox.add_child(qty_lbl)

	if "required_planet" in td:
		var planet_name: String = str(
			GameState.get_planet(td["required_planet"]).get("name", td["required_planet"])
		)
		var req_lbl := Label.new()
		req_lbl.text = "지역: %s" % planet_name
		req_lbl.modulate = Color(1.0, 0.8, 0.4, 0.85)
		req_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_vbox.add_child(req_lbl)

# ── 파츠 조립 탭 ──────────────────────────────────────────

func _build_assembly_panel() -> void:
	_tab_asm_panel = Control.new()
	_tab_asm_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tab_asm_panel.offset_top = 32.0
	_body.add_child(_tab_asm_panel)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_vbox.add_theme_constant_override("separation", 4)
	_tab_asm_panel.add_child(outer_vbox)

	# 5열 가로 배치: [격납고] [몸체] [무기] [다리] [SYS SPEC]
	var col_row := HBoxContainer.new()
	col_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_row.add_theme_constant_override("separation", 4)
	outer_vbox.add_child(col_row)

	# ── 격납고 (슬롯 선택) fixed 110 ───────────────────────────
	var col1 := _make_col_panel(Color(0.07, 0.09, 0.18, 1.0), Color(0.4, 0.6, 1.0))
	col1.custom_minimum_size = Vector2(110, 0)
	col1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_row.add_child(col1)
	var col1_vbox := VBoxContainer.new()
	col1_vbox.add_theme_constant_override("separation", 4)
	col1.add_child(col1_vbox)
	col1_vbox.add_child(_make_col_header("격납고", Color(0.5, 0.72, 1.0)))
	_col_slots_inner = VBoxContainer.new()
	_col_slots_inner.add_theme_constant_override("separation", 4)
	col1_vbox.add_child(_col_slots_inner)

	# ── 몸체 파츠 ──────────────────────────────────────────────
	var col2 := _make_col_panel(Color(0.09, 0.07, 0.18, 1.0), Color(0.55, 0.4, 1.0))
	col2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_row.add_child(col2)
	var col2_vbox := VBoxContainer.new()
	col2_vbox.add_theme_constant_override("separation", 4)
	col2.add_child(col2_vbox)
	col2_vbox.add_child(_make_col_header("몸체", Color(0.7, 0.55, 1.0)))
	_col_body_inner = VBoxContainer.new()
	_col_body_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_col_body_inner.add_theme_constant_override("separation", 4)
	col2_vbox.add_child(_col_body_inner)

	# ── 무기 파츠 ──────────────────────────────────────────────
	var col3 := _make_col_panel(Color(0.18, 0.07, 0.07, 1.0), Color(1.0, 0.4, 0.4))
	col3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col3.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_row.add_child(col3)
	var col3_vbox := VBoxContainer.new()
	col3_vbox.add_theme_constant_override("separation", 4)
	col3.add_child(col3_vbox)
	col3_vbox.add_child(_make_col_header("무기", Color(1.0, 0.55, 0.55)))
	_col_weapon_inner = VBoxContainer.new()
	_col_weapon_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_col_weapon_inner.add_theme_constant_override("separation", 4)
	col3_vbox.add_child(_col_weapon_inner)

	# ── 다리 파츠 ──────────────────────────────────────────────
	var col4 := _make_col_panel(Color(0.07, 0.14, 0.10, 1.0), Color(0.3, 0.8, 0.5))
	col4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col4.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_row.add_child(col4)
	var col4_vbox := VBoxContainer.new()
	col4_vbox.add_theme_constant_override("separation", 4)
	col4.add_child(col4_vbox)
	col4_vbox.add_child(_make_col_header("다리", Color(0.4, 0.95, 0.6)))
	_col_legs_inner = VBoxContainer.new()
	_col_legs_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_col_legs_inner.add_theme_constant_override("separation", 4)
	col4_vbox.add_child(_col_legs_inner)

	# ── SYS SPEC fixed 160 ────────────────────────────────────
	var col5 := _make_col_panel(Color(0.13, 0.10, 0.04, 1.0), Color(0.85, 0.65, 0.2))
	col5.custom_minimum_size = Vector2(160, 0)
	col5.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_row.add_child(col5)
	var col5_vbox := VBoxContainer.new()
	col5_vbox.add_theme_constant_override("separation", 4)
	col5.add_child(col5_vbox)
	col5_vbox.add_child(_make_col_header("SYS SPEC", Color(1.0, 0.82, 0.35)))
	_col_specs_inner = VBoxContainer.new()
	_col_specs_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_col_specs_inner.add_theme_constant_override("separation", 4)
	col5_vbox.add_child(_col_specs_inner)

	# ── 조립 버튼 (full width) ──────────
	_asm_btn = Button.new()
	_asm_btn.text = "▶  조립하기"
	_asm_btn.custom_minimum_size = Vector2(0, 28)
	_asm_btn.disabled = true
	_asm_btn.pressed.connect(func():
		if GameState.assemble_machine(_asm_slot, _asm_sel["body"], _asm_sel["weapon"], _asm_sel["legs"]):
			_asm_slot = -1
			_asm_sel = {"body": 0, "weapon": 0, "legs": 0}
			_refresh_assembly()
	)
	outer_vbox.add_child(_asm_btn)

func _make_col_panel(bg: Color, border: Color) -> PanelContainer:
	var pc := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(bg.r, bg.g, bg.b, 0.78)
	s.border_color = border
	s.border_width_left   = 1
	s.border_width_right  = 1
	s.border_width_top    = 1
	s.border_width_bottom = 1
	s.corner_radius_top_left     = 4
	s.corner_radius_top_right    = 4
	s.corner_radius_bottom_left  = 4
	s.corner_radius_bottom_right = 4
	s.content_margin_left   = 4
	s.content_margin_right  = 4
	s.content_margin_top    = 4
	s.content_margin_bottom = 4
	pc.add_theme_stylebox_override("panel", s)
	return pc

func _make_col_header(text: String, color: Color) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s := StyleBoxFlat.new()
	s.bg_color = Color(color.r * 0.22, color.g * 0.22, color.b * 0.22, 0.82)
	s.border_color = color
	s.border_width_bottom = 1
	s.content_margin_left   = 4
	s.content_margin_right  = 4
	s.content_margin_top    = 3
	s.content_margin_bottom = 3
	pc.add_theme_stylebox_override("panel", s)
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", color)
	pc.add_child(lbl)
	return pc

# ── 조립 탭 — 컬럼별 갱신 ────────────────────────────────

func _refresh_assembly() -> void:
	_refresh_slot_column()
	_refresh_parts_column()
	_refresh_spec_column()

func _refresh_slot_column() -> void:
	for child in _col_slots_inner.get_children():
		child.queue_free()

	var empty_slots: Array = []
	for i: int in GameState.auto_slots.size():
		var s: DispatchManager.AutoSlot = GameState.auto_slots[i] as DispatchManager.AutoSlot
		if s.state == "empty":
			empty_slots.append(i)

	if empty_slots.is_empty():
		_asm_slot = -1
		var lbl := Label.new()
		lbl.text = "빈 슬롯\n없음"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.modulate = Color(1, 0.4, 0.4, 1)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_col_slots_inner.add_child(lbl)
		return

	if _asm_slot != -1 and not (_asm_slot in empty_slots):
		_asm_slot = -1

	var grp := ButtonGroup.new()
	for si: int in empty_slots:
		var is_sel: bool = (_asm_slot == si)
		var btn := Button.new()
		btn.text = "No.%d\nEMPTY" % (si + 1)
		btn.custom_minimum_size = Vector2(0, 36)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		btn.button_group = grp
		btn.button_pressed = is_sel
		btn.add_theme_stylebox_override("normal",        _slot_stylebox(false, false))
		btn.add_theme_stylebox_override("hover",         _slot_stylebox(false, true))
		btn.add_theme_stylebox_override("pressed",       _slot_stylebox(true,  false))
		btn.add_theme_stylebox_override("hover_pressed", _slot_stylebox(true,  true))
		btn.add_theme_stylebox_override("focus",         _slot_stylebox(false, false))
		var cap := si
		btn.pressed.connect(func():
			_asm_slot = cap
			_refresh_spec_column()
		)
		_col_slots_inner.add_child(btn)

func _slot_stylebox(selected: bool, hover: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.border_color = Color(0.5, 0.72, 1.0)
	var bw := 2 if selected else 1
	s.border_width_left   = bw
	s.border_width_right  = bw
	s.border_width_top    = bw
	s.border_width_bottom = bw
	var base := Color(0.18, 0.28, 0.52, 0.85) if selected else Color(0.07, 0.09, 0.20, 0.78)
	s.bg_color = base.lightened(0.07) if hover else base
	s.corner_radius_top_left     = 3
	s.corner_radius_top_right    = 3
	s.corner_radius_bottom_left  = 3
	s.corner_radius_bottom_right = 3
	s.content_margin_left   = 4
	s.content_margin_right  = 4
	s.content_margin_top    = 4
	s.content_margin_bottom = 4
	return s

func _refresh_parts_column() -> void:
	_fill_part_col("body",   _col_body_inner)
	_fill_part_col("weapon", _col_weapon_inner)
	_fill_part_col("legs",   _col_legs_inner)

func _fill_part_col(part_type: String, inner: VBoxContainer) -> void:
	for child in inner.get_children():
		child.queue_free()
	var qtys: Array = GameState.owned_parts[part_type]
	var grp := ButtonGroup.new()
	var any := false
	var sel_assigned := false
	for i: int in qtys.size():
		var qty: int = qtys[i]
		if qty <= 0:
			continue
		any = true
		var tier := i + 1
		var sel_tier: int = _asm_sel.get(part_type, 0)
		for _j in qty:
			var is_this_sel := (sel_tier == tier and not sel_assigned)
			if sel_tier == tier:
				sel_assigned = true
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(0, 32)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.text = "T%d" % tier
			btn.toggle_mode = true
			btn.button_group = grp
			btn.button_pressed = is_this_sel
			btn.add_theme_stylebox_override("normal",        _tier_stylebox(tier, false, false))
			btn.add_theme_stylebox_override("hover",         _tier_stylebox(tier, false, true))
			btn.add_theme_stylebox_override("pressed",       _tier_stylebox(tier, true,  false))
			btn.add_theme_stylebox_override("hover_pressed", _tier_stylebox(tier, true,  true))
			btn.add_theme_stylebox_override("focus",         _tier_stylebox(tier, false, false))
			var pt := part_type
			var t  := tier
			btn.pressed.connect(func():
				_asm_sel[pt] = t
				_refresh_spec_column()
			)
			inner.add_child(btn)
	if not any:
		var lbl := Label.new()
		lbl.text = "없음"
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.modulate = Color(1.0, 0.45, 0.45, 1)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(lbl)

# ── SYS SPEC 컬럼 ─────────────────────────────────────────

func _refresh_spec_column() -> void:
	if _col_specs_inner == null:
		return
	for child in _col_specs_inner.get_children():
		child.queue_free()

	var b: int = _asm_sel.get("body",   0)
	var w: int = _asm_sel.get("weapon", 0)
	var l: int = _asm_sel.get("legs",   0)

	# 선택 요약
	var sel_lbl := Label.new()
	sel_lbl.text = "%s / %s / %s" % [
		("몸체T%d" % b) if b > 0 else "몸체--",
		("무기T%d" % w) if w > 0 else "무기--",
		("다리T%d" % l) if l > 0 else "다리--",
	]
	sel_lbl.add_theme_font_size_override("font_size", 10)
	sel_lbl.modulate = Color(0.7, 0.7, 0.85)
	sel_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_col_specs_inner.add_child(sel_lbl)

	_col_specs_inner.add_child(HSeparator.new())

	var preview: Dictionary = GameState.get_machine_preview(b, w, l)
	_add_stat_row("미션",  ("%ds" % int(preview.get("mission_time", 0.0))) if b > 0 else "--")
	_add_stat_row("CR/s",  ("×%d" % preview.get("rate", 0))               if w > 0 else "--")
	_add_stat_row("복귀",  ("%ds" % int(preview.get("return_time",  0.0))) if l > 0 else "--")

	_col_specs_inner.add_child(HSeparator.new())

	_add_stat_row("예상", ("%d CR" % preview.get("credits", 0)) if (b > 0 and w > 0) else "--")

	var cost := 0
	if b > 0 and w > 0 and l > 0:
		cost = GameState.get_assembly_cost(b, w, l)
	_add_stat_row("비용", ("%d CR" % cost) if cost > 0 else "--")

	_col_specs_inner.add_child(HSeparator.new())

	var all_sel: bool    = _asm_slot >= 0 and b > 0 and w > 0 and l > 0
	var can_afford: bool = all_sel and GameState.total_credits >= cost
	var status_lbl := Label.new()
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 11)
	if not all_sel:
		status_lbl.text = "◌  STANDBY"
		status_lbl.modulate = Color(1, 1, 1, 0.3)
	elif not can_afford:
		status_lbl.text = "●  CR 부족"
		status_lbl.modulate = Color(1.0, 0.3, 0.3, 1.0)
	else:
		status_lbl.text = "●  READY"
		status_lbl.modulate = Color(0.35, 1.0, 0.5, 1.0)
	_col_specs_inner.add_child(status_lbl)

	if _asm_btn != null:
		_asm_btn.disabled = not can_afford
		_asm_btn.modulate = Color(0.35, 1.0, 0.55, 1.0) if can_afford else Color(1, 1, 1, 0.6)


func _add_stat_row(key: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	_col_specs_inner.add_child(row)

	var key_lbl := Label.new()
	key_lbl.text = key
	key_lbl.modulate = Color(1, 1, 1, 0.5)
	key_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(key_lbl)

	var val_lbl := Label.new()
	val_lbl.text = value
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val_lbl)

func _update_asm_cost() -> void:
	if not is_node_ready() or _col_specs_inner == null:
		return
	if _current_tab != 1:
		return
	_refresh_spec_column()
