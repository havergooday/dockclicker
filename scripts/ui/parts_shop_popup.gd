extends Control

const POPUP_W_RATIO := 0.74
const ANIM_DURATION := 0.20
const HEADER_COST := 300
const PANEL_H_PAD := 14
const PANEL_V_PAD := 6
const DETAIL_W := 320
const GRID_COLS := 3
const TILE_MIN := Vector2(0, 68)
const PART_ORDER: Array = ["body", "weapon", "legs"]

const TIER_COLORS: Array = [
	Color(0.56, 0.58, 0.62),
	Color(0.90, 0.92, 0.96),
	Color(0.94, 0.77, 0.28),
]

const PART_TINTS := {
	"body": Color(0.44, 0.70, 1.0),
	"weapon": Color(0.95, 0.74, 0.28),
	"legs": Color(0.52, 0.88, 0.62),
}

var _panel: Control = null
var _close_btn: Button = null
var _timer_label: Label = null
var _refresh_btn: Button = null
var _refresh_timer: Timer = null
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

var _current_part_type: String = "body"
var _current_item_iid: String = ""
var _shop_items: Array = []
var _stock_last_day: int = -1
var _stock_refresh_count: int = 0
var _body_node: Control = null
var _upgrade_body: Control = null
var _upgrade_list_box: VBoxContainer = null
var _facility_body: Control = null
var _facility_list_box: VBoxContainer = null

signal open_facility_management_requested

const UPGRADE_IDS: Array = ["click_damage", "auto_attack", "click_range", "combo"]


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	_rebuild_stock(true)
	_build_ui()
	_refresh_all()
	GameState.credits_changed.connect(func(_v): _update_refresh_button(); _refresh_detail(); _rebuild_upgrade_cards())
	GameState.planet_unlocked.connect(func(_id): _rebuild_stock(true); _refresh_all())
	GameState.part_purchased.connect(func(_pt, _t): _refresh_detail())
	GameState.upgrade_changed.connect(_rebuild_upgrade_cards)

	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = 1.0
	_refresh_timer.autostart = true
	_refresh_timer.timeout.connect(_on_refresh_tick)
	add_child(_refresh_timer)


func open_popup() -> void:
	_ensure_stock_fresh()
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
	_body_node = _build_body()
	root.add_child(_body_node)
	_upgrade_body = _build_upgrade_body()
	root.add_child(_upgrade_body)
	_facility_body = _build_facility_body()
	root.add_child(_facility_body)


func _build_top_bar() -> Control:
	var hb := HBoxContainer.new()
	hb.custom_minimum_size = Vector2(0, 28)
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var left := HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	hb.add_child(left)

	_timer_label = Label.new()
	_timer_label.text = "--:--:--"
	_timer_label.add_theme_font_size_override("font_size", 10)
	_timer_label.modulate = Color(0.60, 0.70, 0.85)
	_timer_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_timer_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.add_child(_timer_label)

	var center := Control.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(center)

	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.custom_minimum_size = Vector2(32, 24)
	_close_btn.pressed.connect(func(): close_popup())
	center.add_child(_close_btn)

	var right := HBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	hb.add_child(right)

	_refresh_btn = Button.new()
	_refresh_btn.text = "새로고침  %d CR" % HEADER_COST
	_refresh_btn.custom_minimum_size = Vector2(130, 24)
	_refresh_btn.add_theme_font_size_override("font_size", 10)
	_refresh_btn.pressed.connect(_on_refresh_pressed)
	right.add_child(_refresh_btn)

	return hb


func _build_tabs_row() -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var group := ButtonGroup.new()
	var all_tabs: Array = PART_ORDER + ["upgrade", "facility"]
	for part_type in all_tabs:
		var btn := Button.new()
		btn.text = _tab_caption(part_type)
		btn.toggle_mode = true
		btn.button_group = group
		btn.custom_minimum_size = Vector2(80, 26)
		btn.add_theme_font_size_override("font_size", 11)
		var cap: String = part_type
		btn.pressed.connect(func():
			_select_part_type(cap)
		)
		_tab_buttons[part_type] = btn
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
	_detail_preview_icon.text = "NPC"
	_detail_preview_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_preview_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_preview_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_detail_preview_icon.add_theme_font_size_override("font_size", 12)
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
	_detail_price_label.text = "가격: --"
	_detail_price_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_price_label.add_theme_font_size_override("font_size", 11)
	_detail_price_label.modulate = Color(0.82, 0.90, 1.0)
	_detail_price_row.add_child(_detail_price_label)

	_detail_buy_btn = Button.new()
	_detail_buy_btn.text = "구매"
	_detail_buy_btn.custom_minimum_size = Vector2(0, 32)
	_detail_buy_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_detail_buy_btn.pressed.connect(_on_buy_pressed)
	_detail_price_row.add_child(_detail_buy_btn)

	return panel


func _build_detail_box(title: String) -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.11, 0.16, 0.55), true))
	box.custom_minimum_size = Vector2(0, 56)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 6
	vb.offset_right = -6
	vb.offset_top = 5
	vb.offset_bottom = -5
	vb.add_theme_constant_override("separation", 2)
	box.add_child(vb)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 10)
	title_lbl.modulate = Color(0.82, 0.90, 1.0)
	vb.add_child(title_lbl)

	return box


func _refresh_all() -> void:
	_ensure_selection()
	_sync_body_visibility()
	_refresh_tabs()
	if _current_part_type == "upgrade":
		_rebuild_upgrade_cards()
	elif _current_part_type == "facility":
		_refresh_facility_body()
	else:
		_refresh_grid()
		_refresh_detail()
		_update_refresh_button()
		_update_timer_label()


func _sync_body_visibility() -> void:
	var is_upgrade  := _current_part_type == "upgrade"
	var is_facility := _current_part_type == "facility"
	var is_parts    := not is_upgrade and not is_facility
	if _body_node != null:
		_body_node.visible = is_parts
	if _upgrade_body != null:
		_upgrade_body.visible = is_upgrade
	if _facility_body != null:
		_facility_body.visible = is_facility
	if _timer_label != null:
		_timer_label.visible = is_parts
	if _refresh_btn != null:
		_refresh_btn.visible = is_parts


func _refresh_tabs() -> void:
	for part_type in PART_ORDER:
		var btn: Button = _tab_buttons.get(part_type, null) as Button
		if btn != null:
			btn.set_pressed_no_signal(part_type == _current_part_type)


func _refresh_grid() -> void:
	if _grid == null:
		return
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()

	for item: Dictionary in _shop_items:
		if str(item.get("type", "")) != _current_part_type:
			continue
		_grid.add_child(_make_part_tile(item))


func _refresh_detail() -> void:
	var item := _get_selected_item()
	if item.is_empty():
		_detail_name.text = ""
		_detail_preview.visible = true
		_detail_preview_icon.text = "NPC"
		_detail_preview_text.text = "아이템을 선택하세요.\n선택하면 상세 정보와 구매 버튼이 표시됩니다."
		_detail_option_panel.visible = false
		_detail_price_row.visible = false
		_detail_buy_btn.disabled = true
		_detail_buy_btn.text = "구매"
		return

	var part_type := str(item.get("type", ""))
	var tier := int(item.get("tier", 1))
	var locked := _is_locked(part_type, item)
	var req := str(item.get("required_planet", ""))
	var req_txt := "기본 해금" if req.is_empty() else "해금 완료" if GameState.is_planet_unlocked(req) else "🔒 %s 필요" % GameState.get_planet(req).get("name", req)
	var cost := int(item.get("cost", 0))

	_detail_preview.visible = true
	_detail_preview_icon.text = _part_short_code(part_type)
	_detail_preview_text.text = "%s\nT%d" % [str(item.get("name", "")), tier]
	_detail_name.text = str(item.get("name", ""))
	_detail_option_panel.visible = true
	_detail_price_row.visible = true
	var effect_text := str(item.get("effect_text", ""))
	if effect_text.is_empty():
		effect_text = _part_effect_text(part_type, tier)
	_detail_option_text.text = "옵션: %s\n조건: %s" % [
		effect_text,
		req_txt,
	]
	_detail_price_label.text = "가격: %d CR" % cost
	_detail_buy_btn.disabled = locked or GameState.total_credits < cost
	_detail_buy_btn.text = "구매"


func _make_part_tile(item: Dictionary) -> Control:
	var part_type := str(item.get("type", ""))
	var tier := int(item.get("tier", 1))
	var locked := _is_locked(part_type, item)
	var selected := str(item.get("iid", "")) == _current_item_iid

	var btn := Button.new()
	btn.custom_minimum_size = TILE_MIN
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_FILL
	btn.text = ""
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", _make_tile_style(part_type, tier, selected, locked))
	btn.add_theme_stylebox_override("hover", _make_tile_style(part_type, tier, selected, locked, true))
	btn.add_theme_stylebox_override("pressed", _make_tile_style(part_type, tier, true, locked))
	btn.add_theme_stylebox_override("disabled", _make_tile_style(part_type, tier, selected, true))

	var iid := str(item.get("iid", ""))
	btn.pressed.connect(func():
		_select_part_item(iid)
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
	icon.add_theme_stylebox_override("panel", _make_panel_style(_part_tint(part_type, tier), false))
	hb.add_child(icon)

	var icon_lbl := Label.new()
	icon_lbl.text = _part_short_code(part_type)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_lbl.add_theme_font_size_override("font_size", 13)
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
	name_lbl.modulate = Color(0.92, 0.96, 1.0) if not locked else Color(1, 1, 1, 0.35)
	text_vb.add_child(name_lbl)

	var info_lbl := Label.new()
	info_lbl.text = "%d CR" % int(item.get("cost", 0))
	info_lbl.add_theme_font_size_override("font_size", 10)
	info_lbl.modulate = Color(0.72, 0.82, 0.96) if not locked else Color(1, 1, 1, 0.22)
	text_vb.add_child(info_lbl)

	return btn


func _select_part_type(part_type: String) -> void:
	if _current_part_type == part_type:
		return
	_current_part_type = part_type
	_current_item_iid = ""
	_refresh_all()


func _select_part_item(iid: String) -> void:
	_current_item_iid = iid
	_refresh_all()


func _ensure_selection() -> void:
	if _current_part_type in ["upgrade", "facility"]:
		return
	if not GameState.PARTS.has(_current_part_type):
		_current_part_type = "body"
	if _current_item_iid != "":
		var found := _get_selected_item()
		if found.is_empty():
			_current_item_iid = ""


func _reset_selection() -> void:
	_current_part_type = "body"
	_current_item_iid = ""


func _on_buy_pressed() -> void:
	var item := _get_selected_item()
	if item.is_empty():
		return
	var part_type := str(item.get("type", ""))
	var tier := int(item.get("tier", 1))
	if GameState.buy_part(part_type, tier):
		var sold_iid := str(item.get("iid", ""))
		for i in _shop_items.size():
			if str(_shop_items[i].get("iid", "")) == sold_iid:
				_shop_items.remove_at(i)
				break
		_current_item_iid = ""
		_refresh_all()


func _on_refresh_pressed() -> void:
	if GameState.total_credits < HEADER_COST:
		return
	GameState.total_credits -= HEADER_COST
	GameState.credits_changed.emit(GameState.total_credits)
	_stock_refresh_count += 1
	_rebuild_stock(true)
	_refresh_all()


func _on_refresh_tick() -> void:
	_ensure_stock_fresh()
	_update_timer_label()
	_update_refresh_button()


func _ensure_stock_fresh(force: bool = false) -> void:
	var day := _today_unix_day()
	if force or _stock_last_day != day:
		_stock_last_day = day
		_stock_refresh_count = 0
		_rebuild_stock(force)


func _rebuild_stock(reset_selection: bool) -> void:
	_shop_items = _generate_shop_items()
	if reset_selection:
		_current_item_iid = ""


func _generate_shop_items() -> Array:
	var items: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = _shop_seed()
	var idx := 0
	for part_type in PART_ORDER:
		var part_data: Dictionary = GameState.PARTS.get(part_type, {}) as Dictionary
		var tiers: Array = part_data.get("tiers", []) as Array
		for tier_idx in tiers.size():
			var tier := tier_idx + 1
			var tier_data: Dictionary = tiers[tier_idx] as Dictionary
			for copy_idx in 3:
				items.append({
					"iid": "shop_%s_%d_%d_%d" % [part_type, tier, copy_idx, idx],
					"type": part_type,
					"tier": tier,
					"name": str(tier_data.get("name", "")),
					"cost": int(tier_data.get("cost", 0)),
					"required_planet": str(tier_data.get("required_planet", "")),
					"effect_text": _part_effect_text(part_type, tier),
				})
				idx += 1
	_shuffle_array(items, rng)
	return items


func _shuffle_array(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _get_selected_item() -> Dictionary:
	for item: Dictionary in _shop_items:
		if str(item.get("iid", "")) == _current_item_iid:
			return item
	return {}


func _update_timer_label() -> void:
	if _timer_label == null:
		return
	var secs := _seconds_until_midnight()
	var h := secs / 3600
	var m := (secs % 3600) / 60
	var s := secs % 60
	_timer_label.text = "다음 갱신 %02d:%02d:%02d" % [h, m, s]


func _update_refresh_button() -> void:
	if _refresh_btn == null:
		return
	_refresh_btn.disabled = GameState.total_credits < HEADER_COST


func _today_unix_day() -> int:
	return int(Time.get_unix_time_from_system()) / 86400


func _seconds_until_midnight() -> int:
	var now := int(Time.get_unix_time_from_system())
	return 86400 - (now % 86400)


func _shop_seed() -> int:
	return _today_unix_day() * 1000 + _stock_refresh_count


func _is_locked(part_type: String, item_data: Dictionary) -> bool:
	var req := str(item_data.get("required_planet", ""))
	return req != "" and not GameState.is_planet_unlocked(req)


func _tab_caption(tab: String) -> String:
	match tab:
		"body":     return "몸체"
		"weapon":   return "무기"
		"legs":     return "다리"
		"upgrade":  return "강화"
		"facility": return "시설"
		_:          return tab


func _part_caption(part_type: String) -> String:
	return _tab_caption(part_type)


# ── 시설 탭 ───────────────────────────────────────────────────

func _build_facility_body() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.visible = false

	_facility_list_box = VBoxContainer.new()
	_facility_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_facility_list_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_facility_list_box)
	return scroll


func _refresh_facility_body() -> void:
	if _facility_list_box == null:
		return
	for child in _facility_list_box.get_children():
		_facility_list_box.remove_child(child)
		child.queue_free()

	var title := Label.new()
	title.text = "설치된 시설"
	title.add_theme_font_size_override("font_size", 13)
	title.modulate = Color(0.72, 0.88, 1.0)
	_facility_list_box.add_child(title)

	var slot_labels := {"rest": "휴식", "table": "테이블", "service": "서비스",
		"medical": "의료", "wall": "벽면", "decor": "장식"}
	for slot_id in GameState.lounge_slots.keys():
		var facility_id := GameState.get_installed_facility(str(slot_id))
		var facility_name := "—"
		if facility_id != "":
			var fd := GameState.get_facility_data(facility_id)
			facility_name = str(fd.get("name", facility_id))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var slot_lbl := Label.new()
		slot_lbl.text = slot_labels.get(slot_id, slot_id)
		slot_lbl.custom_minimum_size = Vector2(60, 0)
		slot_lbl.add_theme_font_size_override("font_size", 11)
		slot_lbl.modulate = Color(0.60, 0.68, 0.82)
		row.add_child(slot_lbl)
		var val_lbl := Label.new()
		val_lbl.text = facility_name
		val_lbl.add_theme_font_size_override("font_size", 11)
		val_lbl.modulate = Color(0.88, 0.96, 0.90) if facility_id != "" else Color(1, 1, 1, 0.28)
		row.add_child(val_lbl)
		_facility_list_box.add_child(row)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	_facility_list_box.add_child(spacer)

	var mgmt_btn := Button.new()
	mgmt_btn.text = "시설관리 열기 →"
	mgmt_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mgmt_btn.custom_minimum_size = Vector2(0, 32)
	mgmt_btn.pressed.connect(func(): open_facility_management_requested.emit())
	_facility_list_box.add_child(mgmt_btn)


# ── 강화 탭 ───────────────────────────────────────────────────

func _build_upgrade_body() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.visible = false

	_upgrade_list_box = VBoxContainer.new()
	_upgrade_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrade_list_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_upgrade_list_box)
	return scroll


func _rebuild_upgrade_cards() -> void:
	if _upgrade_list_box == null or _current_part_type != "upgrade":
		return
	for c in _upgrade_list_box.get_children():
		c.queue_free()
	for id in UPGRADE_IDS:
		_upgrade_list_box.add_child(_make_upgrade_card(id))


func _make_upgrade_card(upg_id: String) -> Control:
	var cur_lv  := _upg_level(upg_id)
	var max_lv  := _upg_max(upg_id)
	var cost    := _upg_cost(upg_id)
	var maxed   := cur_lv >= max_lv
	var tint    := _upg_tint(upg_id)
	var affordable := not maxed and GameState.total_credits >= cost

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var csty := StyleBoxFlat.new()
	csty.bg_color     = tint.darkened(0.68)
	csty.border_color = tint.darkened(0.15) if not maxed else tint.darkened(0.30)
	csty.set_border_width_all(1)
	csty.set_corner_radius_all(6)
	csty.content_margin_left   = 10
	csty.content_margin_right  = 10
	csty.content_margin_top    = 8
	csty.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", csty)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	card.add_child(hb)

	# 아이콘
	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(44, 44)
	var isty := StyleBoxFlat.new()
	isty.bg_color = tint.darkened(0.40)
	isty.border_color = tint
	isty.set_border_width_all(1)
	isty.set_corner_radius_all(5)
	icon_box.add_theme_stylebox_override("panel", isty)
	hb.add_child(icon_box)

	var icon_lbl := Label.new()
	icon_lbl.text = _upg_icon(upg_id)
	icon_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 10)
	icon_lbl.modulate = tint.lightened(0.35)
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.add_child(icon_lbl)

	# 중앙 정보
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	hb.add_child(info)

	var name_row := HBoxContainer.new()
	info.add_child(name_row)

	var name_lbl := Label.new()
	name_lbl.text = _upg_name(upg_id)
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.modulate = Color(0.90, 0.95, 1.0) if not maxed else Color(0.65, 0.75, 0.90)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_lbl)

	var lv_lbl := Label.new()
	lv_lbl.text = "MAX" if maxed else "Lv %d / %d" % [cur_lv, max_lv]
	lv_lbl.add_theme_font_size_override("font_size", 10)
	lv_lbl.modulate = tint if maxed else Color(0.65, 0.72, 0.85)
	name_row.add_child(lv_lbl)

	var eff_lbl := Label.new()
	eff_lbl.text = _upg_effect(upg_id, cur_lv)
	eff_lbl.add_theme_font_size_override("font_size", 10)
	eff_lbl.modulate = Color(0.72, 0.82, 0.96)
	eff_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(eff_lbl)

	# 우측 버튼
	if maxed:
		var done_lbl := Label.new()
		done_lbl.text = "✓"
		done_lbl.add_theme_font_size_override("font_size", 18)
		done_lbl.modulate = tint
		done_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hb.add_child(done_lbl)
	else:
		var btn_vb := VBoxContainer.new()
		btn_vb.add_theme_constant_override("separation", 2)
		btn_vb.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.add_child(btn_vb)

		var cost_lbl := Label.new()
		cost_lbl.text = "%d CR" % cost
		cost_lbl.add_theme_font_size_override("font_size", 10)
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.modulate = Color(0.85, 0.75, 0.50) if affordable else Color(0.90, 0.35, 0.35)
		btn_vb.add_child(cost_lbl)

		var btn := Button.new()
		btn.text = "강화"
		btn.custom_minimum_size = Vector2(64, 26)
		btn.disabled = not affordable
		var bsty := StyleBoxFlat.new()
		bsty.bg_color     = tint.darkened(0.35) if affordable else Color(0.12, 0.14, 0.20)
		bsty.border_color = tint if affordable else Color(0.30, 0.32, 0.42)
		bsty.set_border_width_all(1)
		bsty.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", bsty)
		btn.add_theme_stylebox_override("hover",  bsty)
		btn.add_theme_stylebox_override("focus",  bsty)
		var cap_id := upg_id
		btn.pressed.connect(func(): _do_upgrade(cap_id))
		btn_vb.add_child(btn)

	return card


func _do_upgrade(upg_id: String) -> void:
	match upg_id:
		"click_damage": GameState.upgrade_click_damage()
		"auto_attack":  GameState.unlock_auto_attack()
		"click_range":  GameState.upgrade_click_range()
		"combo":        GameState.upgrade_combo()


func _upg_level(id: String) -> int:
	match id:
		"click_damage": return GameState.damage_upgrade_level
		"auto_attack":  return 1 if GameState.auto_attack_unlocked else 0
		"click_range":  return GameState.click_range_level
		"combo":        return GameState.combo_level
	return 0


func _upg_max(id: String) -> int:
	match id:
		"click_damage": return PartsData.DAMAGE_UPGRADE_COSTS.size()
		"auto_attack":  return 1
		"click_range":  return PartsData.CLICK_RANGE_COSTS.size()
		"combo":        return PartsData.COMBO_COSTS.size()
	return 1


func _upg_cost(id: String) -> int:
	match id:
		"click_damage": return GameState.get_damage_upgrade_cost()
		"auto_attack":  return GameState.AUTO_ATTACK_COST
		"click_range":  return GameState.get_click_range_cost()
		"combo":        return GameState.get_combo_cost()
	return -1


func _upg_name(id: String) -> String:
	match id:
		"click_damage": return "클릭 데미지"
		"auto_attack":  return "자동 공격"
		"click_range":  return "클릭 범위"
		"combo":        return "연타 콤보"
	return id


func _upg_icon(id: String) -> String:
	match id:
		"click_damage": return "DMG"
		"auto_attack":  return "AUTO"
		"click_range":  return "RNG"
		"combo":        return "CMB"
	return "?"


func _upg_tint(id: String) -> Color:
	match id:
		"click_damage": return Color(0.95, 0.74, 0.28)
		"auto_attack":  return Color(0.52, 0.88, 0.62)
		"click_range":  return Color(0.44, 0.70, 1.00)
		"combo":        return Color(0.85, 0.45, 0.95)
	return Color(0.60, 0.65, 0.80)


func _upg_effect(id: String, level: int) -> String:
	match id:
		"click_damage":
			if level == 0: return "클릭 데미지  1"
			return "클릭 데미지  %d" % (level + 1)
		"auto_attack":
			return "해금됨 — 1.5초마다 자동 공격" if level > 0 else "미해금"
		"click_range":
			if level == 0: return "단일 클릭"
			return "클릭 반경  %d px" % int(PartsData.CLICK_RANGE_PX[level - 1])
		"combo":
			if level == 0: return "비활성"
			return "%.1f초 내 %d연타  → ×%.1f 배율" % [
				PartsData.COMBO_WINDOW_SEC,
				PartsData.COMBO_THRESHOLDS[level - 1],
				PartsData.COMBO_MULTIPLIERS[level - 1],
			]
	return ""


func _part_short_code(part_type: String) -> String:
	match part_type:
		"body":
			return "B"
		"weapon":
			return "W"
		"legs":
			return "L"
		_:
			return "?"


func _part_tint(part_type: String, tier: int) -> Color:
	var base: Color = PART_TINTS.get(part_type, Color.WHITE) as Color
	var idx := clampi(tier - 1, 0, TIER_COLORS.size() - 1)
	return TIER_COLORS[idx].lerp(base, 0.55)


func _part_effect_text(part_type: String, tier: int) -> String:
	var part: Dictionary = GameState.PARTS.get(part_type, {}) as Dictionary
	var tiers: Array = part.get("tiers", []) as Array
	if tier < 1 or tier > tiers.size():
		return ""
	var tier_data: Dictionary = tiers[tier - 1] as Dictionary
	var effect: String = str(part.get("effect", ""))
	return effect % tier_data.get("value", 0)


func _make_tile_style(part_type: String, tier: int, selected: bool, disabled: bool, hover: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var tint := _part_tint(part_type, tier)
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


func _make_panel_style(color: Color, solid: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color if solid else color.darkened(0.14)
	style.border_color = color.lightened(0.08)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style
