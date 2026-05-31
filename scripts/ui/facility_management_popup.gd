extends Control

signal unlock_confirm_requested(feature_id: String, title: String, body: String, cost_text: String)

const POPUP_W_RATIO := 0.74
const ANIM_DURATION := 0.20
const PANEL_H_PAD := 14
const PANEL_V_PAD := 6
const DETAIL_W := 320
const GRID_COLS := 3
const TILE_MIN := Vector2(0, 68)

const TAB_FACILITIES := "facilities"
const TAB_ZONES := "zones"
const TAB_ORDER: Array = [TAB_FACILITIES, TAB_ZONES]

var _panel: Control = null
var _close_btn: Button = null
var _title_label: Label = null
var _tab_buttons: Dictionary = {}
var _grid: GridContainer = null
var _grid_scroll: ScrollContainer = null
var _detail_preview: PanelContainer = null
var _detail_preview_icon: Label = null
var _detail_preview_text: Label = null
var _detail_name: Label = null
var _detail_option_panel: PanelContainer = null
var _detail_option_text: Label = null
var _detail_price_row: HBoxContainer = null
var _detail_price_label: Label = null
var _detail_buy_btn: Button = null

var _current_tab := TAB_FACILITIES
var _selected_kind := ""
var _selected_id := ""


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	_build_ui()
	_refresh_all()
	GameState.facilities_changed.connect(_refresh_all)
	GameState.feature_unlocked.connect(func(_id: String): _refresh_all())
	GameState.credits_changed.connect(func(_v: int): _refresh_detail())
	GameState.resources_changed.connect(func(_v: Dictionary): _refresh_detail())


func open_popup() -> void:
	_reset_selection()
	_refresh_all()
	visible = true
	_panel.position.y = -_panel.size.y - 10.0
	var tween := create_tween()
	tween.tween_property(_panel, "position:y", 0.0, ANIM_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func close_popup() -> void:
	_reset_selection()
	var tween := create_tween()
	tween.tween_property(_panel, "position:y", -_panel.size.y - 10.0, ANIM_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): visible = false)


func _build_ui() -> void:
	var popup_w := get_viewport_rect().size.x * POPUP_W_RATIO

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
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -popup_w * 0.5
	_panel.offset_right = popup_w * 0.5
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.07, 0.10, 0.15, 0.97)
	bg_style.border_color = Color(0.26, 0.40, 0.62, 0.80)
	bg_style.set_border_width_all(1)

	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", bg_style)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = PANEL_H_PAD
	root.offset_right = -PANEL_H_PAD
	root.offset_top = 4
	root.offset_bottom = -4
	root.add_theme_constant_override("separation", PANEL_V_PAD)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(root)

	root.add_child(_build_top_bar())
	root.add_child(_build_tabs_row())
	root.add_child(_build_body())


func _build_top_bar() -> Control:
	var hb := HBoxContainer.new()
	hb.custom_minimum_size = Vector2(0, 28)
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var left := HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	hb.add_child(left)

	_title_label = Label.new()
	_title_label.text = "시설관리"
	_title_label.add_theme_font_size_override("font_size", 10)
	_title_label.modulate = Color(0.60, 0.70, 0.85)
	_title_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.add_child(_title_label)

	var center := Control.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(center)

	_close_btn = Button.new()
	_close_btn.text = "X"
	_close_btn.custom_minimum_size = Vector2(32, 24)
	_close_btn.pressed.connect(func(): close_popup())
	center.add_child(_close_btn)

	var right := HBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	hb.add_child(right)

	return hb


func _build_tabs_row() -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var group := ButtonGroup.new()
	for tab in TAB_ORDER:
		var btn := Button.new()
		btn.text = _tab_caption(tab)
		btn.toggle_mode = true
		btn.button_group = group
		btn.custom_minimum_size = Vector2(80, 26)
		btn.add_theme_font_size_override("font_size", 11)
		var cap: String = tab
		btn.pressed.connect(func(): _select_tab(cap))
		_tab_buttons[tab] = btn
		hb.add_child(btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(spacer)
	return hb


func _build_body() -> Control:
	var hb := HBoxContainer.new()
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var left := _build_catalog_pane()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_child(left)

	var sep := ColorRect.new()
	sep.color = Color(0.20, 0.30, 0.50, 0.35)
	sep.custom_minimum_size = Vector2(1, 0)
	sep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_child(sep)

	var right := _build_detail_pane()
	right.custom_minimum_size = Vector2(DETAIL_W, 0)
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_child(right)
	return hb


func _build_catalog_pane() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.10, 0.13, 0.18, 0.44)))

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 10
	vb.offset_right = -10
	vb.offset_top = 8
	vb.offset_bottom = -8
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)

	_grid_scroll = ScrollContainer.new()
	_grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid_scroll.follow_focus = true
	vb.add_child(_grid_scroll)

	_grid = GridContainer.new()
	_grid.columns = GRID_COLS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	_grid_scroll.add_child(_grid)
	return panel


func _build_detail_pane() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.10, 0.13, 0.18, 0.44)))

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 10
	vb.offset_right = -10
	vb.offset_top = 8
	vb.offset_bottom = -8
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)

	_detail_name = Label.new()
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_name.add_theme_font_size_override("font_size", 14)
	_detail_name.modulate = Color(0.92, 0.96, 1.0)
	vb.add_child(_detail_name)

	_detail_preview = PanelContainer.new()
	_detail_preview.custom_minimum_size = Vector2(0, 60)
	_detail_preview.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.11, 0.16, 0.65), true))
	vb.add_child(_detail_preview)

	var preview_hb := HBoxContainer.new()
	preview_hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_hb.offset_left = 6
	preview_hb.offset_right = -6
	preview_hb.offset_top = 6
	preview_hb.offset_bottom = -6
	preview_hb.add_theme_constant_override("separation", 6)
	_detail_preview.add_child(preview_hb)

	var preview_icon := PanelContainer.new()
	preview_icon.custom_minimum_size = Vector2(38, 38)
	preview_icon.add_theme_stylebox_override("panel", _make_panel_style(Color(0.45, 0.55, 0.72), false))
	preview_hb.add_child(preview_icon)

	_detail_preview_icon = Label.new()
	_detail_preview_icon.text = "FAC"
	_detail_preview_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_preview_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_preview_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_detail_preview_icon.add_theme_font_size_override("font_size", 10)
	_detail_preview_icon.modulate = Color(1, 1, 1, 0.85)
	preview_icon.add_child(_detail_preview_icon)

	_detail_preview_text = Label.new()
	_detail_preview_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_preview_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_preview_text.add_theme_font_size_override("font_size", 10)
	_detail_preview_text.modulate = Color(0.80, 0.88, 1.0)
	preview_hb.add_child(_detail_preview_text)

	_detail_option_panel = PanelContainer.new()
	_detail_option_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.11, 0.16, 0.55), true))
	_detail_option_panel.custom_minimum_size = Vector2(0, 72)
	vb.add_child(_detail_option_panel)

	var option_pad := MarginContainer.new()
	option_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	option_pad.add_theme_constant_override("margin_left", 6)
	option_pad.add_theme_constant_override("margin_right", 6)
	option_pad.add_theme_constant_override("margin_top", 5)
	option_pad.add_theme_constant_override("margin_bottom", 5)
	_detail_option_panel.add_child(option_pad)

	_detail_option_text = Label.new()
	_detail_option_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_option_text.add_theme_font_size_override("font_size", 10)
	_detail_option_text.modulate = Color(0.72, 0.82, 0.96)
	_detail_option_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_option_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	option_pad.add_child(_detail_option_text)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)

	_detail_price_row = HBoxContainer.new()
	_detail_price_row.add_theme_constant_override("separation", 8)
	_detail_price_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_price_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_detail_price_row)

	_detail_price_label = Label.new()
	_detail_price_label.text = "비용: --"
	_detail_price_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_price_label.add_theme_font_size_override("font_size", 11)
	_detail_price_label.modulate = Color(0.82, 0.90, 1.0)
	_detail_price_row.add_child(_detail_price_label)

	_detail_buy_btn = Button.new()
	_detail_buy_btn.text = "구매"
	_detail_buy_btn.custom_minimum_size = Vector2(0, 32)
	_detail_buy_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_detail_buy_btn.pressed.connect(_on_action_pressed)
	_detail_price_row.add_child(_detail_buy_btn)

	return panel


func _refresh_all() -> void:
	_refresh_tabs()
	_refresh_catalog()
	_refresh_detail()


func _refresh_tabs() -> void:
	for tab in TAB_ORDER:
		var btn: Button = _tab_buttons.get(tab, null) as Button
		if btn != null:
			btn.set_pressed_no_signal(tab == _current_tab)


func _refresh_catalog() -> void:
	if _grid == null:
		return
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for item: Dictionary in _catalog_items():
		_grid.add_child(_make_catalog_tile(item))


func _refresh_detail() -> void:
	var item := _selected_item()
	if item.is_empty():
		_detail_name.text = ""
		_detail_preview.visible = true
		_detail_preview_icon.text = "FAC"
		_detail_preview_text.text = "항목을 선택하세요.\n선택하면 상세 정보와 진행 버튼이 표시됩니다."
		_detail_option_panel.visible = false
		_detail_price_row.visible = false
		_detail_buy_btn.disabled = true
		_detail_buy_btn.text = "선택 필요"
		return

	var disabled := bool(item.get("disabled", false))
	_detail_name.text = str(item.get("name", ""))
	_detail_preview.visible = true
	_detail_preview_icon.text = str(item.get("icon", "FAC"))
	_detail_preview_text.text = str(item.get("preview", ""))
	_detail_option_panel.visible = true
	_detail_price_row.visible = true
	_detail_option_text.text = str(item.get("desc", ""))
	_detail_price_label.text = "비용: %s" % str(item.get("cost_text", ""))
	_detail_buy_btn.text = str(item.get("action_text", "진행"))
	_detail_buy_btn.disabled = disabled


func _make_catalog_tile(item: Dictionary) -> Control:
	var selected := str(item.get("kind", "")) == _selected_kind and str(item.get("id", "")) == _selected_id
	var done := bool(item.get("done", false))

	var btn := Button.new()
	btn.custom_minimum_size = TILE_MIN
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.text = ""
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", _make_tile_style(selected, done))
	btn.add_theme_stylebox_override("hover", _make_tile_style(selected, done, true))
	btn.add_theme_stylebox_override("pressed", _make_tile_style(true, done))
	btn.add_theme_stylebox_override("disabled", _make_tile_style(selected, true))

	var kind := str(item.get("kind", ""))
	var item_id := str(item.get("id", ""))
	btn.pressed.connect(func():
		_selected_kind = kind
		_selected_id = item_id
		_refresh_all()
	)

	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 7
	hb.offset_right = -7
	hb.offset_top = 7
	hb.offset_bottom = -7
	hb.add_theme_constant_override("separation", 8)
	btn.add_child(hb)

	var icon := PanelContainer.new()
	icon.custom_minimum_size = Vector2(34, 34)
	icon.add_theme_stylebox_override("panel", _make_panel_style(_item_tint(item), false))
	hb.add_child(icon)

	var icon_lbl := Label.new()
	icon_lbl.text = str(item.get("icon", "FAC"))
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_lbl.add_theme_font_size_override("font_size", 10)
	icon_lbl.modulate = Color(1, 1, 1, 0.8)
	icon.add_child(icon_lbl)

	var text_vb := VBoxContainer.new()
	text_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vb.add_theme_constant_override("separation", 2)
	hb.add_child(text_vb)

	var name_lbl := Label.new()
	name_lbl.text = str(item.get("name", ""))
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.modulate = Color(0.92, 0.96, 1.0) if not done else Color(1, 1, 1, 0.42)
	text_vb.add_child(name_lbl)

	var info_lbl := Label.new()
	info_lbl.text = str(item.get("state_text", ""))
	info_lbl.add_theme_font_size_override("font_size", 10)
	info_lbl.modulate = Color(0.72, 0.82, 0.96) if not done else Color(1, 1, 1, 0.28)
	text_vb.add_child(info_lbl)

	return btn


func _catalog_items() -> Array:
	var items: Array = []
	if _current_tab == TAB_FACILITIES:
		for raw in GameState.FACILITIES:
			var facility: Dictionary = raw
			var facility_id := str(facility.get("id", ""))
			var slot_id := str(facility.get("slot_type", ""))
			var installed := GameState.get_installed_facility(slot_id) == facility_id
			var upgrades_from := str(facility.get("upgrades_from", ""))
			var is_upgrade := upgrades_from != "" and GameState.get_installed_facility(slot_id) == upgrades_from
			var can_pay := GameState.can_pay(facility.get("cost", {}))
			var action_text: String
			var disabled: bool
			if installed:
				action_text = "설치됨"
				disabled = true
			elif is_upgrade:
				action_text = "업그레이드"
				disabled = not can_pay
			else:
				action_text = "설치"
				disabled = not can_pay
			items.append({
				"kind": "facility",
				"id": facility_id,
				"name": str(facility.get("name", "")),
				"icon": _facility_icon(slot_id),
				"preview": "%s\n%s" % [str(facility.get("name", "")), _slot_caption(slot_id)],
				"desc": "%s\n활동: %s" % [str(facility.get("desc", "생활 시설")), _activity_caption(str(facility.get("activity", "")))],
				"cost_text": GameState.format_cost(facility.get("cost", {})),
				"state_text": "설치됨" if installed else GameState.format_cost(facility.get("cost", {})),
				"action_text": action_text,
				"disabled": disabled,
				"done": installed,
				"tint": Color(0.68, 0.92, 1.0) if is_upgrade else Color(0.52, 0.88, 0.62),
			})
	else:
		for raw in GameState.FEATURE_DEFS:
			var feature: Dictionary = raw
			var feature_id := str(feature.get("id", ""))
			var unlocked := GameState.is_feature_unlocked(feature_id)
			var cost := int(feature.get("cost", 0))
			items.append({
				"kind": "feature",
				"id": feature_id,
				"name": str(feature.get("name", "")),
				"icon": "KEY",
				"preview": str(feature.get("name", "")),
				"desc": str(feature.get("desc", "")),
				"cost_text": "%d CR" % cost,
				"state_text": "해금됨" if unlocked else "%d CR" % cost,
				"action_text": "해금됨" if unlocked else "해금",
				"disabled": unlocked or GameState.total_credits < cost,
				"done": unlocked,
				"tint": Color(0.44, 0.70, 1.0),
			})
	return items


func _selected_item() -> Dictionary:
	for item: Dictionary in _catalog_items():
		if str(item.get("kind", "")) == _selected_kind and str(item.get("id", "")) == _selected_id:
			return item
	return {}


func _select_tab(tab: String) -> void:
	if _current_tab == tab:
		return
	_current_tab = tab
	_reset_selection()
	_refresh_all()


func _reset_selection() -> void:
	_selected_kind = ""
	_selected_id = ""


func _on_action_pressed() -> void:
	var item := _selected_item()
	if item.is_empty() or bool(item.get("disabled", false)):
		return
	if _selected_kind == "facility":
		var facility := GameState.get_facility_data(_selected_id)
		if not facility.is_empty() and GameState.install_facility(str(facility.get("slot_type", "")), _selected_id):
			_refresh_all()
	elif _selected_kind == "feature":
		var feature_id := _selected_id
		if feature_id == "quarters":
			unlock_confirm_requested.emit(
				feature_id,
				"숙소 해금",
				"침대 1개와 파일럿 거주 공간을 해금합니다.",
				str(item.get("cost_text", ""))
			)
		elif GameState.unlock_feature(feature_id):
			_refresh_all()


func _tab_caption(tab: String) -> String:
	match tab:
		TAB_FACILITIES: return "생활시설"
		TAB_ZONES: return "구역해금"
	return tab


func _facility_icon(slot_id: String) -> String:
	match slot_id:
		"rest": return "RST"
		"table": return "PLY"
		"service": return "SVC"
		"medical": return "MED"
		"decor": return "DEC"
		"wall": return "WAL"
	return "FAC"


func _slot_caption(slot_id: String) -> String:
	match slot_id:
		"rest": return "휴식 시설"
		"table": return "놀이 시설"
		"service": return "서비스 시설"
		"medical": return "의료 시설"
		"decor": return "장식 시설"
		"wall": return "벽면 시설"
	return "생활 시설"


func _activity_caption(activity: String) -> String:
	match activity:
		"rest": return "피로 회복"
		"play": return "스트레스 회복"
		"eat": return "기분 회복"
		"recover": return "스트레스/피로 회복"
	return "-"


func _item_tint(item: Dictionary) -> Color:
	return item.get("tint", Color(0.60, 0.65, 0.80)) as Color


func _make_panel_style(color: Color, solid: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color if solid else color.darkened(0.14)
	style.border_color = color.lightened(0.08)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style


func _make_tile_style(selected: bool, disabled: bool, hover: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var tint := Color(0.52, 0.88, 0.62) if _current_tab == TAB_FACILITIES else Color(0.44, 0.70, 1.0)
	if disabled:
		style.bg_color = Color(0.08, 0.10, 0.14, 0.48)
		style.border_color = tint.darkened(0.40)
	elif selected:
		style.bg_color = tint.darkened(0.50)
		style.border_color = tint.lightened(0.18)
	elif hover:
		style.bg_color = tint.darkened(0.58)
		style.border_color = tint.lightened(0.10)
	else:
		style.bg_color = Color(0.09, 0.12, 0.18, 0.84)
		style.border_color = tint
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
