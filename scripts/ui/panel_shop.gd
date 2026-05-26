extends Control

@onready var _back_button: Button = $Header/BackButton
@onready var _body: Control = $Body

const CATEGORIES: Array = [
	{"id": "parts", "label": "파츠", "enabled": true},
	{"id": "upgrade", "label": "함선 강화", "enabled": true},
	{"id": "pilot", "label": "파일럿", "enabled": true},
	{"id": "divider", "label": "", "enabled": false},
	{"id": "facility", "label": "시설", "enabled": false},
	{"id": "cosmetic", "label": "꾸밈", "enabled": false},
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

const MENU_W := 232
const PILOT_LIST_W := 640
const CUSTOM_PREVIEW_W := 360
const PADDING := 10
const ROW_H := 34

var _current_category: String = "parts"
var _cat_buttons: Dictionary = {}
var _content_area: Control = null
var _scroll_positions: Dictionary = {}

var _pilot_view_mode: String = "detail" # detail | custom
var _pilot_selected_id: String = ""
var _custom_pilot_name: String = ""
var _custom_pilot_color: String = "#44AADD"


func _ready() -> void:
	PanelManager.register_panel("shop", self)
	_back_button.pressed.connect(func(): PanelManager.go_back())
	_back_button.text = "← %s" % PanelManager.get_back_label()
	PanelManager.panel_changed.connect(func(id: String):
		if id == "shop":
			_back_button.text = "← %s" % PanelManager.get_back_label()
	)
	GameState.credits_changed.connect(func(_v): _rebuild_content())
	GameState.planet_unlocked.connect(func(_id): _rebuild_content())
	GameState.part_purchased.connect(func(_pt, _t): _rebuild_content())
	GameState.pilot_hired.connect(func(_id): _rebuild_content())
	GameState.pilot_status_changed.connect(func(_id): _rebuild_content())
	_build_layout()
	_select_category("parts")


func _build_layout() -> void:
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	_body.add_child(root)

	var menu := _build_side_menu()
	menu.custom_minimum_size = Vector2(MENU_W, 0)
	menu.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(menu)

	_add_vsep(root)

	_content_area = Control.new()
	_content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_content_area)


func _build_side_menu() -> Control:
	var con := Control.new()
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.11, 0.16, 0.52)))
	con.add_child(panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 14
	vb.offset_right = -14
	vb.offset_top = 12
	vb.offset_bottom = -18
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	var btn_group := ButtonGroup.new()
	for cat in CATEGORIES:
		if cat["id"] == "divider":
			vb.add_child(_make_menu_divider())
			continue
		var btn := Button.new()
		btn.text = str(cat["label"])
		btn.custom_minimum_size = Vector2(0, 28)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.toggle_mode = true
		btn.button_group = btn_group
		btn.disabled = not bool(cat["enabled"])
		btn.add_theme_stylebox_override("normal", _make_menu_button_style(false, btn.disabled))
		btn.add_theme_stylebox_override("hover", _make_menu_button_style(false, btn.disabled, true))
		btn.add_theme_stylebox_override("pressed", _make_menu_button_style(true, btn.disabled))
		btn.add_theme_stylebox_override("hover_pressed", _make_menu_button_style(true, btn.disabled, true))
		btn.add_theme_stylebox_override("disabled", _make_menu_button_style(false, true))
		if bool(cat["enabled"]):
			var cid: String = cat["id"]
			btn.pressed.connect(func(): _select_category(cid))
			_cat_buttons[cid] = btn
		vb.add_child(btn)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)

	return con


func _select_category(cat_id: String) -> void:
	_current_category = cat_id
	if _cat_buttons.has(cat_id):
		(_cat_buttons[cat_id] as Button).set_pressed_no_signal(true)
	if cat_id != "pilot":
		_pilot_view_mode = "detail"
	_rebuild_content()


func _rebuild_content() -> void:
	if _content_area == null:
		return
	_capture_scroll_positions()
	for child in _content_area.get_children():
		child.queue_free()
	match _current_category:
		"parts":
			_build_parts_content()
		"upgrade":
			_build_upgrade_content()
		"pilot":
			if _pilot_view_mode == "custom":
				_build_custom_pilot_content()
			else:
				_build_pilot_content()
	call_deferred("_restore_scroll_positions")


func _build_parts_content() -> void:
	var root := _make_content_root()
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	root.add_child(_wrap_with_scroll(list, "parts_list"))

	for part_type in ["body", "weapon", "legs"]:
		list.add_child(_make_section_header(str(GameState.PARTS[part_type]["name"])))
		var data: Dictionary = GameState.PARTS[part_type]
		var tiers: Array = data["tiers"]
		for i in tiers.size():
			list.add_child(_make_part_row(part_type, i + 1, tiers[i], data))


func _build_upgrade_content() -> void:
	var root := _make_content_root()
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	root.add_child(_wrap_with_scroll(list, "upgrade_list"))

	var cost := GameState.get_damage_upgrade_cost()
	list.add_child(_make_upgrade_row(
		"클릭 데미지",
		"현재 %d → 다음 %d" % [GameState.click_damage, GameState.click_damage + 1 if cost >= 0 else GameState.click_damage],
		"직접 파견 기본 공격력 증가",
		cost,
		cost < 0,
		func():
			GameState.upgrade_click_damage()
	))
	list.add_child(_make_upgrade_row("클릭 범위", "추후 해금 예정", "범위형 공격 업그레이드", -1, true, func(): pass))
	list.add_child(_make_upgrade_row("무기 교체", "추후 해금 예정", "직접 파견 무기 유형 확장", -1, true, func(): pass))


func _build_pilot_content() -> void:
	_ensure_valid_pilot_selection()

	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	_content_area.add_child(root)

	var left := _build_pilot_list_pane()
	left.custom_minimum_size = Vector2(PILOT_LIST_W, 0)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(left)

	_add_vsep(root)

	var detail := _build_pilot_detail_pane()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(detail)


func _build_custom_pilot_content() -> void:
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	_content_area.add_child(root)

	var preview := _build_custom_preview_pane()
	preview.custom_minimum_size = Vector2(CUSTOM_PREVIEW_W, 0)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(preview)

	_add_vsep(root)

	var form := _build_custom_form_pane()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(form)


func _build_pilot_list_pane() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.10, 0.13, 0.18, 0.44)))

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 14
	vb.offset_right = -14
	vb.offset_top = 12
	vb.offset_bottom = -12
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(_wrap_with_scroll(vb, "pilot_list"))

	vb.add_child(_make_section_header("고용 가능 파일럿"))
	for pilot_data in GameState.PILOTS:
		var pid: String = pilot_data["id"]
		if GameState.is_pilot_hired(pid):
			continue
		vb.add_child(_make_pilot_select_row(pilot_data, false))

	if vb.get_child_count() == 1:
		vb.add_child(_make_hint_label("모든 기본 파일럿 고용 완료"))

	vb.add_child(_make_section_header("내 파견단"))
	if GameState.hired_pilots.is_empty():
		vb.add_child(_make_hint_label("고용된 파일럿 없음"))
	else:
		for pilot in GameState.hired_pilots:
			vb.add_child(_make_pilot_select_row(pilot, true))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)

	var custom_btn := Button.new()
	custom_btn.text = "+ 커스텀 파일럿 생성"
	custom_btn.custom_minimum_size = Vector2(0, 30)
	custom_btn.pressed.connect(func():
		_pilot_view_mode = "custom"
		_rebuild_content()
	)
	vb.add_child(custom_btn)
	return panel


func _build_pilot_detail_pane() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.10, 0.13, 0.18, 0.44)))

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 18
	vb.offset_right = -18
	vb.offset_top = 14
	vb.offset_bottom = -14
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	var pilot := _get_selected_pilot()
	if pilot.is_empty():
		vb.add_child(_make_hint_label("파일럿을 선택하세요"))
		return panel

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	vb.add_child(head)

	head.add_child(_make_portrait(pilot, 92, 40, 28))

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = str(pilot.get("name", ""))
	name_lbl.add_theme_font_size_override("font_size", 19)
	info.add_child(name_lbl)

	var tier: int = int(pilot.get("tier", 1))
	var tier_lbl := Label.new()
	tier_lbl.text = "Tier %d" % tier
	tier_lbl.add_theme_font_size_override("font_size", 11)
	tier_lbl.modulate = _tier_color(tier)
	info.add_child(tier_lbl)

	var state_lbl := Label.new()
	if GameState.is_pilot_hired(str(pilot.get("id", ""))):
		var hired := GameState.get_hired_pilot(str(pilot.get("id", "")))
		state_lbl.text = "상태: %s" % ("대기중" if hired.get("status", "idle") == "idle" else "파견중")
	else:
		state_lbl.text = "상태: 고용 가능"
	state_lbl.add_theme_font_size_override("font_size", 11)
	state_lbl.modulate = Color(0.70, 0.80, 0.95)
	info.add_child(state_lbl)

	var bonus := Label.new()
	bonus.text = str(pilot.get("desc", ""))
	bonus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bonus.add_theme_font_size_override("font_size", 12)
	bonus.modulate = _bonus_color(str(pilot.get("bonus_type", "none")))
	vb.add_child(bonus)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_END
	action_row.add_theme_constant_override("separation", 8)
	vb.add_child(action_row)

	var custom_btn := Button.new()
	custom_btn.text = "커스텀 생성"
	custom_btn.custom_minimum_size = Vector2(120, 30)
	custom_btn.pressed.connect(func():
		_pilot_view_mode = "custom"
		_rebuild_content()
	)
	action_row.add_child(custom_btn)

	if GameState.is_pilot_hired(str(pilot.get("id", ""))):
		var hired_lbl := Label.new()
		hired_lbl.text = "✓ 고용 완료"
		hired_lbl.modulate = Color(0.38, 0.88, 0.52)
		hired_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		action_row.add_child(hired_lbl)
	else:
		var cost: int = int(pilot.get("cost", 0))
		var hire_btn := Button.new()
		hire_btn.text = "고용하기   %d CR" % cost
		hire_btn.custom_minimum_size = Vector2(150, 30)
		hire_btn.disabled = GameState.total_credits < cost
		var pid: String = str(pilot.get("id", ""))
		hire_btn.pressed.connect(func():
			GameState.hire_pilot(pid)
			_pilot_selected_id = pid
		)
		action_row.add_child(hire_btn)
	return panel


func _build_custom_preview_pane() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.10, 0.13, 0.18, 0.44)))

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 18
	vb.offset_right = -18
	vb.offset_top = 14
	vb.offset_bottom = -14
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var preview_name := _custom_pilot_name.strip_edges()
	if preview_name.is_empty():
		preview_name = "신규 파일럿"

	var preview_data := {
		"name": preview_name,
		"portrait_color": _custom_pilot_color,
	}

	vb.add_child(_make_section_header("커스텀 파일럿 미리보기"))
	vb.add_child(_make_portrait(preview_data, 108, 44, 32))

	var name_lbl := Label.new()
	name_lbl.text = preview_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 16)
	vb.add_child(name_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "기본 T1 / 보너스 없음"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 11)
	sub_lbl.modulate = Color(0.70, 0.80, 0.95)
	vb.add_child(sub_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = "비용: 300 CR"
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 12)
	cost_lbl.modulate = Color(0.95, 0.82, 0.42)
	vb.add_child(cost_lbl)
	return panel


func _build_custom_form_pane() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.10, 0.13, 0.18, 0.44)))

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 18
	vb.offset_right = -18
	vb.offset_top = 14
	vb.offset_bottom = -14
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(_wrap_with_scroll(vb, "custom_form"))

	vb.add_child(_make_section_header("커스텀 파일럿 생성"))

	var name_lbl := Label.new()
	name_lbl.text = "이름"
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.modulate = Color(0.75, 0.82, 0.98)
	vb.add_child(name_lbl)

	var name_edit := LineEdit.new()
	name_edit.text = _custom_pilot_name
	name_edit.placeholder_text = "파일럿 이름 입력"
	name_edit.max_length = 12
	name_edit.text_changed.connect(func(v: String):
		_custom_pilot_name = v
		_rebuild_content()
	)
	vb.add_child(name_edit)

	var color_lbl := Label.new()
	color_lbl.text = "색상 선택"
	color_lbl.add_theme_font_size_override("font_size", 11)
	color_lbl.modulate = Color(0.75, 0.82, 0.98)
	vb.add_child(color_lbl)

	var color_row := HBoxContainer.new()
	color_row.add_theme_constant_override("separation", 8)
	vb.add_child(color_row)
	for hex in CUSTOM_COLORS:
		var cbtn := Button.new()
		cbtn.custom_minimum_size = Vector2(32, 28)
		cbtn.toggle_mode = true
		cbtn.button_pressed = (_custom_pilot_color == hex)
		cbtn.add_theme_stylebox_override("normal", _make_color_chip(hex, false))
		cbtn.add_theme_stylebox_override("pressed", _make_color_chip(hex, true))
		cbtn.add_theme_stylebox_override("hover_pressed", _make_color_chip(hex, true))
		var picked_hex: String = hex
		cbtn.pressed.connect(func():
			_custom_pilot_color = picked_hex
			call_deferred("_rebuild_content")
		)
		color_row.add_child(cbtn)

	var rules := Label.new()
	rules.text = "- 이름 길이 제한\n- 기본 T1 파일럿\n- 선택 색상 즉시 미리보기 반영"
	rules.add_theme_font_size_override("font_size", 11)
	rules.modulate = Color(0.70, 0.80, 0.95)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(rules)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	vb.add_child(actions)

	var cancel_btn := Button.new()
	cancel_btn.text = "취소"
	cancel_btn.custom_minimum_size = Vector2(96, 30)
	cancel_btn.pressed.connect(func():
		_pilot_view_mode = "detail"
		_rebuild_content()
	)
	actions.add_child(cancel_btn)

	var create_btn := Button.new()
	create_btn.text = "생성하기   300 CR"
	create_btn.custom_minimum_size = Vector2(150, 30)
	create_btn.disabled = GameState.total_credits < 300 or _custom_pilot_name.strip_edges().is_empty()
	create_btn.pressed.connect(func():
		var name := _custom_pilot_name
		var color := _custom_pilot_color
		if GameState.create_custom_pilot(name, color):
			_custom_pilot_name = ""
			_pilot_view_mode = "detail"
			_pilot_selected_id = ""
	)
	actions.add_child(create_btn)
	return panel


func _make_part_row(part_type: String, tier: int, tier_data: Dictionary, part_data: Dictionary) -> Control:
	var req: String = str(tier_data.get("required_planet", ""))
	var locked: bool = req != "" and not GameState.is_planet_unlocked(req)
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_H)
	row.add_theme_stylebox_override("panel", _make_row_style(_tier_color(tier), locked))

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 8)
	row.add_child(hb)

	var tier_lbl := Label.new()
	tier_lbl.text = "T%d" % tier
	tier_lbl.custom_minimum_size = Vector2(26, 0)
	tier_lbl.add_theme_font_size_override("font_size", 11)
	tier_lbl.modulate = _tier_color(tier) if not locked else Color(1, 1, 1, 0.3)
	hb.add_child(tier_lbl)

	var name_lbl := Label.new()
	name_lbl.text = str(tier_data.get("name", ""))
	name_lbl.custom_minimum_size = Vector2(150, 0)
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.modulate = Color(0.90, 0.94, 1.0) if not locked else Color(1, 1, 1, 0.3)
	hb.add_child(name_lbl)

	var effect_lbl := Label.new()
	effect_lbl.text = str(part_data.get("effect", "")) % tier_data.get("value", 0)
	effect_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_lbl.add_theme_font_size_override("font_size", 10)
	effect_lbl.modulate = Color(0.58, 0.84, 1.0) if not locked else Color(1, 1, 1, 0.22)
	hb.add_child(effect_lbl)

	var cond_lbl := Label.new()
	cond_lbl.custom_minimum_size = Vector2(128, 0)
	if locked:
		var planet := GameState.get_planet(req)
		cond_lbl.text = "🔒 %s 필요" % planet.get("name", req)
		cond_lbl.modulate = Color(0.95, 0.72, 0.28)
	else:
		cond_lbl.text = "기본 해금" if req.is_empty() else "해금 완료"
		cond_lbl.modulate = Color(0.60, 0.70, 0.84)
	cond_lbl.add_theme_font_size_override("font_size", 10)
	hb.add_child(cond_lbl)

	var price_lbl := Label.new()
	price_lbl.text = "%d CR" % int(tier_data.get("cost", 0))
	price_lbl.custom_minimum_size = Vector2(72, 0)
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_lbl.add_theme_font_size_override("font_size", 10)
	hb.add_child(price_lbl)

	var buy_btn := Button.new()
	buy_btn.text = "구매"
	buy_btn.custom_minimum_size = Vector2(84, 26)
	buy_btn.disabled = locked or GameState.total_credits < int(tier_data.get("cost", 0))
	var pt := part_type
	var tr := tier
	buy_btn.pressed.connect(func():
		GameState.buy_part(pt, tr)
	)
	hb.add_child(buy_btn)
	return row


func _make_upgrade_row(title: String, current: String, desc: String, cost: int, disabled: bool, callback: Callable) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_H)
	row.add_theme_stylebox_override("panel", _make_row_style(Color(0.44, 0.74, 1.0), disabled))

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 8)
	row.add_child(hb)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.custom_minimum_size = Vector2(140, 0)
	title_lbl.add_theme_font_size_override("font_size", 11)
	hb.add_child(title_lbl)

	var current_lbl := Label.new()
	current_lbl.text = current
	current_lbl.custom_minimum_size = Vector2(180, 0)
	current_lbl.add_theme_font_size_override("font_size", 10)
	current_lbl.modulate = Color(0.70, 0.80, 0.95)
	hb.add_child(current_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.modulate = Color(0.62, 0.86, 1.0) if not disabled else Color(1, 1, 1, 0.24)
	hb.add_child(desc_lbl)

	var price_lbl := Label.new()
	price_lbl.text = "-----" if cost < 0 else "%d CR" % cost
	price_lbl.custom_minimum_size = Vector2(72, 0)
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_lbl.add_theme_font_size_override("font_size", 10)
	hb.add_child(price_lbl)

	var btn := Button.new()
	btn.text = "잠김" if cost < 0 else "강화"
	btn.custom_minimum_size = Vector2(84, 26)
	btn.disabled = disabled or (cost >= 0 and GameState.total_credits < cost)
	if not disabled:
		btn.pressed.connect(func():
			callback.call()
		)
	hb.add_child(btn)
	return row


func _make_pilot_select_row(pilot_data: Dictionary, hired_instance: bool) -> Control:
	var pid: String = str(pilot_data.get("id", ""))
	var tier: int = int(pilot_data.get("tier", 1))
	var row_btn := Button.new()
	row_btn.text = ""
	row_btn.custom_minimum_size = Vector2(0, 36)
	row_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row_btn.add_theme_stylebox_override("normal", _make_menu_button_style(_pilot_selected_id == pid, false))
	row_btn.add_theme_stylebox_override("hover", _make_menu_button_style(_pilot_selected_id == pid, false, true))
	row_btn.add_theme_stylebox_override("pressed", _make_menu_button_style(true, false))

	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 10
	hb.offset_right = -10
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_btn.add_child(hb)

	hb.add_child(_make_portrait(pilot_data, 28, 14, 12))

	var name_lbl := Label.new()
	name_lbl.text = str(pilot_data.get("name", ""))
	name_lbl.custom_minimum_size = Vector2(104, 0)
	name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(name_lbl)

	var tier_lbl := Label.new()
	tier_lbl.text = "T%d" % tier
	tier_lbl.custom_minimum_size = Vector2(30, 0)
	tier_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tier_lbl.add_theme_font_size_override("font_size", 10)
	tier_lbl.modulate = _tier_color(tier)
	tier_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(tier_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = str(pilot_data.get("desc", ""))
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	desc_lbl.add_theme_font_size_override("font_size", 9)
	desc_lbl.modulate = _bonus_color(str(pilot_data.get("bonus_type", "none")))
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(desc_lbl)

	var status_lbl := Label.new()
	status_lbl.custom_minimum_size = Vector2(60, 0)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_lbl.add_theme_font_size_override("font_size", 10)
	if hired_instance:
		status_lbl.text = "대기중" if str(pilot_data.get("status", "idle")) == "idle" else "파견중"
		status_lbl.modulate = Color(0.38, 0.88, 0.52) if status_lbl.text == "대기중" else Color(0.95, 0.70, 0.25)
	else:
		status_lbl.text = "고용 가능"
		status_lbl.modulate = Color(0.70, 0.80, 0.95)
	status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(status_lbl)

	row_btn.pressed.connect(func():
		_pilot_selected_id = pid
		_pilot_view_mode = "detail"
		_rebuild_content()
	)
	return row_btn


func _make_content_root() -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	_content_area.add_child(panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 14
	vb.offset_right = -14
	vb.offset_top = 12
	vb.offset_bottom = -18
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	return vb


func _make_section_header(text: String) -> Control:
	var con := Control.new()
	con.custom_minimum_size = Vector2(0, 16)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.modulate = Color(0.48, 0.62, 0.88)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	lbl.offset_right = 180
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	con.add_child(lbl)

	var line := ColorRect.new()
	line.color = Color(0.22, 0.30, 0.48, 0.45)
	line.anchor_right = 1.0
	line.offset_left = 100
	line.anchor_bottom = 0.0
	line.offset_top = 8
	line.offset_bottom = 9
	con.add_child(line)
	return con


func _make_hint_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.modulate = Color(1, 1, 1, 0.32)
	return lbl


func _make_menu_divider() -> Control:
	var line := ColorRect.new()
	line.color = Color(0.20, 0.26, 0.42, 0.55)
	line.custom_minimum_size = Vector2(0, 1)
	return line


func _make_panel_style(bg: Color = Color(0.10, 0.13, 0.18, 0.44)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = Color(0.18, 0.26, 0.40, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 14
	return style


func _make_row_style(accent: Color, disabled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if not disabled:
		style.bg_color = Color(0.10, 0.13, 0.18, 0.54)
		style.border_color = accent.darkened(0.32)
	else:
		style.bg_color = Color(0.10, 0.13, 0.18, 0.28)
		style.border_color = Color(0.24, 0.26, 0.31, 0.45)
	style.border_width_left = 3
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style


func _make_menu_button_style(selected: bool, disabled: bool, hovered: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if disabled:
		style.bg_color = Color(0.08, 0.10, 0.14, 0.32)
		style.border_color = Color(0.18, 0.20, 0.24, 0.30)
	elif selected:
		style.bg_color = Color(0.12, 0.22, 0.38, 0.90)
		style.border_color = Color(0.34, 0.64, 1.0)
	elif hovered:
		style.bg_color = Color(0.10, 0.16, 0.27, 0.84)
		style.border_color = Color(0.24, 0.40, 0.62)
	else:
		style.bg_color = Color(0.07, 0.11, 0.19, 0.78)
		style.border_color = Color(0.15, 0.28, 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _make_color_chip(hex: String, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(hex)
	style.set_corner_radius_all(4)
	style.set_border_width_all(2 if selected else 0)
	style.border_color = Color.WHITE
	return style


func _wrap_with_scroll(content: Control, key: String) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.set_meta("scroll_key", key)
	scroll.add_child(content)
	return scroll


func _make_portrait(pilot: Dictionary, sz: int, radius: int, font_sz: int) -> Control:
	var col_str: String = str(pilot.get("portrait_color", "#4499DD"))
	var col := Color(col_str) if col_str.begins_with("#") else Color.CORNFLOWER_BLUE
	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = Vector2(sz, sz)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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


func _add_vsep(parent: HBoxContainer) -> void:
	var sep := ColorRect.new()
	sep.color = Color(0.20, 0.26, 0.42, 0.50)
	sep.custom_minimum_size = Vector2(1, 0)
	sep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(sep)


func _tier_color(tier: int) -> Color:
	if tier < 1 or tier > TIER_COLORS.size():
		return Color.WHITE
	return TIER_COLORS[tier - 1]


func _bonus_color(bonus_type: String) -> Color:
	match bonus_type:
		"speed":
			return Color(0.65, 0.85, 1.0)
		"credits":
			return Color(0.65, 1.0, 0.70)
		_:
			return Color(0.62, 0.66, 0.74)


func _capture_scroll_positions() -> void:
	if _content_area == null:
		return
	_scroll_positions.clear()
	var stack: Array = [_content_area]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is ScrollContainer:
			var scroll := node as ScrollContainer
			var key := str(scroll.get_meta("scroll_key", ""))
			if not key.is_empty():
				_scroll_positions[key] = scroll.scroll_vertical
		for child in node.get_children():
			stack.append(child)


func _restore_scroll_positions() -> void:
	if _content_area == null or _scroll_positions.is_empty():
		return
	var stack: Array = [_content_area]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is ScrollContainer:
			var scroll := node as ScrollContainer
			var key := str(scroll.get_meta("scroll_key", ""))
			if _scroll_positions.has(key):
				scroll.scroll_vertical = int(_scroll_positions[key])
		for child in node.get_children():
			stack.append(child)


func _ensure_valid_pilot_selection() -> void:
	if _current_category != "pilot":
		return
	if not _pilot_selected_id.is_empty():
		var selected := _get_selected_pilot()
		if not selected.is_empty():
			return
	for pilot in GameState.PILOTS:
		var pid: String = pilot["id"]
		if not GameState.is_pilot_hired(pid):
			_pilot_selected_id = pid
			return
	if not GameState.hired_pilots.is_empty():
		_pilot_selected_id = str(GameState.hired_pilots[0].get("id", ""))
		return
	_pilot_selected_id = ""


func _get_selected_pilot() -> Dictionary:
	if _pilot_selected_id.is_empty():
		return {}
	var hired := GameState.get_hired_pilot(_pilot_selected_id)
	if not hired.is_empty():
		return hired
	return GameState.get_pilot_data(_pilot_selected_id)
