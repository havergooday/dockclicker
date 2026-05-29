extends Control

const STAR_MAP_SCENE         := preload("res://scenes/ui/star_map_popup.tscn")
const HANGAR_BAY_POPUP_SCENE := preload("res://scenes/ui/hangar_bay_popup.tscn")
const SHOP_POPUP_SCENE       := preload("res://scenes/ui/shop_popup.tscn")
const PARTS_POPUP_SCENE      := preload("res://scenes/ui/parts_shop_popup.tscn")
const BRIDGE_PILOT_SCR       := preload("res://scripts/ui/bridge_pilot.gd")
const HANGAR_ZONE_SCR := preload("res://scripts/ui/hangar_zone.gd")

const NAV_ITEMS: Array = [
	{"id": "hangar", "label": "격납고", "x": 0.0},
	{"id": "bridge", "label": "브릿지", "x": 1200.0},
	{"id": "control", "label": "관제실", "x": 2420.0},
]

var _scroll: ScrollContainer
var _content: Control
var _star_map_popup: Control
var _hangar_bay_popup: Control
var _shop_popup: Control
var _parts_popup: Control
var _bridge_zone_root: Control = null  # 파일럿 로밍용 컨테이너 참조
var _bridge_pilots: Dictionary = {}    # pilot_id → BridgePilot node
var _dragging := false
var _drag_anchor := Vector2.ZERO
var _drag_scroll_start := 0
var _nav_buttons: Dictionary = {}


func _ready() -> void:
	PanelManager.register_panel("bridge", self)
	_build_ui()
	visibility_changed.connect(_on_visibility_changed)
	call_deferred("_scroll_to_zone", 1200.0)


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.07, 0.11, 1.0)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.name = "ShipScroll"
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scroll)
	_scroll = scroll

	_content = Control.new()
	_content.name = "ShipContent"
	_content.custom_minimum_size = Vector2(3700, 0)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(_content)

	_build_background()
	_build_zone_panels()
	_build_zone_dividers()
	_build_nav_bar()
	_build_star_map_popup()
	_build_hangar_bay_popup()
	_build_shop_popup()
	_build_parts_popup()


func _build_background() -> void:
	var lane := ColorRect.new()
	lane.set_anchors_preset(Control.PRESET_FULL_RECT)
	lane.color = Color(0.08, 0.10, 0.15, 0.35)
	_content.add_child(lane)


func _build_nav_bar() -> void:
	var bar := PanelContainer.new()
	bar.anchor_left = 0.5
	bar.anchor_top = 0.0
	bar.anchor_right = 0.5
	bar.anchor_bottom = 0.0
	bar.offset_left = -260.0
	bar.offset_right = 260.0
	bar.offset_top = 10.0
	bar.offset_bottom = 46.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.10, 0.78)
	style.border_color = Color(0.30, 0.42, 0.62, 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("panel", style)
	add_child(bar)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.offset_top = 5
	row.offset_bottom = -5
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)

	var nav_group := ButtonGroup.new()
	_nav_buttons.clear()
	for item in NAV_ITEMS:
		var zone_x := float(item["x"])
		var btn := Button.new()
		btn.text = str(item["label"])
		btn.custom_minimum_size = Vector2(0, 26)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		btn.button_group = nav_group
		btn.pressed.connect(func():
			_scroll_to_zone(zone_x)
		)
		row.add_child(btn)
		_nav_buttons[str(item["id"])] = btn

	if _nav_buttons.has("bridge"):
		_nav_buttons["bridge"].button_pressed = true


func _build_zone_panels() -> void:
	_make_hangar_zone()
	_make_bridge_zone()
	_make_control_zone()


func _make_hangar_zone() -> void:
	var zone: Control = HANGAR_ZONE_SCR.new()
	zone.anchor_left   = 0.0
	zone.anchor_top    = 0.0
	zone.anchor_right  = 0.0
	zone.anchor_bottom = 1.0
	zone.offset_left   = 0.0
	zone.offset_top    = 0.0
	zone.offset_right  = 1200.0
	zone.offset_bottom = 0.0
	zone.connect("navigate_to_control_requested", func():
		_scroll_to_zone(2420.0)
		get_tree().create_timer(0.28).timeout.connect(_open_star_map)
	)
	zone.connect("bay_detail_requested", func(slot_index: int):
		_open_hangar_bay_popup(slot_index)
	)
	_content.add_child(zone)


func _make_bridge_zone() -> void:
	var zone := _make_zone_base(1200.0, 2420.0, "브릿지 / 파일럿 라운지")

	# 파일럿 로밍 레이어 — ZoneRoot 위에 별도 Control
	var roam_layer := Control.new()
	roam_layer.name = "RoamLayer"
	roam_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	roam_layer.offset_top    = 50.0
	roam_layer.offset_bottom = -10.0
	roam_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(roam_layer)
	_bridge_zone_root = roam_layer

	GameState.pilot_hired.connect(func(_id): _sync_bridge_pilots())
	_sync_bridge_pilots()


func _make_control_zone() -> void:
	var zone := _make_zone_base(2420.0, 3700.0, "관제실")
	var body := zone.get_node("ZoneRoot/Body") as VBoxContainer
	body.add_theme_constant_override("separation", 8)

	var intro := Label.new()
	intro.text = "항성지도 팝업으로 파견, 슬롯, 기체 선택을 시작"
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(intro)

	var star_btn := Button.new()
	star_btn.text = "항성지도 열기"
	star_btn.custom_minimum_size = Vector2(0, 34)
	star_btn.pressed.connect(func(): _open_star_map())
	body.add_child(star_btn)

	var hire_btn := Button.new()
	hire_btn.text = "파일럿 고용"
	hire_btn.custom_minimum_size = Vector2(0, 34)
	hire_btn.pressed.connect(func(): _open_shop())
	body.add_child(hire_btn)

	var parts_btn := Button.new()
	parts_btn.text = "파츠 구매"
	parts_btn.custom_minimum_size = Vector2(0, 34)
	parts_btn.pressed.connect(func(): _open_parts_shop())
	body.add_child(parts_btn)


func _make_zone_base(x_start: float, x_end: float, title: String) -> Control:
	var zone := Control.new()
	zone.anchor_left   = 0.0
	zone.anchor_top    = 0.0
	zone.anchor_right  = 0.0
	zone.anchor_bottom = 1.0
	zone.offset_left   = x_start
	zone.offset_top    = 0.0
	zone.offset_right  = x_end
	zone.offset_bottom = 0.0
	zone.mouse_filter  = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.05, 0.08, 0.12, 0.82)
	style.border_color = Color(0.22, 0.34, 0.52, 0.70)
	style.set_border_width_all(1)
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", style)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(bg)

	var vb := VBoxContainer.new()
	vb.name = "ZoneRoot"
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left   = 16
	vb.offset_right  = -16
	vb.offset_top    = 58
	vb.offset_bottom = -12
	vb.add_theme_constant_override("separation", 8)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(vb)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.modulate = Color(0.76, 0.88, 1.0)
	vb.add_child(title_lbl)

	var body := VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 6)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(body)

	_content.add_child(zone)
	return zone


func _build_zone_dividers() -> void:
	for x in [1200.0, 2420.0]:
		var wall := ColorRect.new()
		wall.anchor_left   = 0.0
		wall.anchor_top    = 0.0
		wall.anchor_right  = 0.0
		wall.anchor_bottom = 1.0
		wall.offset_left   = x - 8.0
		wall.offset_right  = x + 8.0
		wall.offset_top    = 0.0
		wall.offset_bottom = 0.0
		wall.color = Color(0.07, 0.09, 0.13, 1.0)
		wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(wall)

		for dx in [-7.0, 6.0]:
			var edge := ColorRect.new()
			edge.anchor_left   = 0.0
			edge.anchor_top    = 0.0
			edge.anchor_right  = 0.0
			edge.anchor_bottom = 1.0
			edge.offset_left   = x + dx
			edge.offset_right  = x + dx + 2.0
			edge.offset_top    = 0.0
			edge.offset_bottom = 0.0
			edge.color = Color(0.18, 0.26, 0.40, 0.85)
			edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_content.add_child(edge)


func _build_star_map_popup() -> void:
	_star_map_popup = STAR_MAP_SCENE.instantiate()
	_star_map_popup.visible = false
	add_child(_star_map_popup)
	move_child(_star_map_popup, get_child_count() - 1)


func _build_hangar_bay_popup() -> void:
	_hangar_bay_popup = HANGAR_BAY_POPUP_SCENE.instantiate()
	_hangar_bay_popup.visible = false
	_hangar_bay_popup.connect("navigate_to_control_requested", func():
		_scroll_to_zone(2420.0)
		get_tree().create_timer(0.28).timeout.connect(_open_star_map)
	)
	add_child(_hangar_bay_popup)
	move_child(_hangar_bay_popup, get_child_count() - 1)


func _sync_bridge_pilots() -> void:
	if _bridge_zone_root == null:
		return
	# 새로 고용된 파일럿 추가
	for p in GameState.hired_pilots:
		var pid: String = str(p.get("id", ""))
		if _bridge_pilots.has(pid):
			continue
		var node: Control = BRIDGE_PILOT_SCR.new()
		_bridge_zone_root.add_child(node)
		var zone_w := 1220.0  # 브릿지 폭
		var zone_h := _bridge_zone_root.size.y if _bridge_zone_root.size.y > 0 else 240.0
		var start_x := randf_range(20.0, zone_w - 68.0)
		var start_y := zone_h * 0.55
		node.position = Vector2(start_x, start_y)
		node.call("setup", p, 0.0, zone_w)
		_bridge_pilots[pid] = node
	# 혹시 제거된 파일럿 정리 (현재는 고용 제한 없으므로 거의 없음)
	for pid in _bridge_pilots.keys():
		var still_hired := false
		for p in GameState.hired_pilots:
			if str(p.get("id", "")) == pid:
				still_hired = true
				break
		if not still_hired:
			(_bridge_pilots[pid] as Control).queue_free()
			_bridge_pilots.erase(pid)


func _build_shop_popup() -> void:
	_shop_popup = SHOP_POPUP_SCENE.instantiate()
	_shop_popup.visible = false
	add_child(_shop_popup)
	move_child(_shop_popup, get_child_count() - 1)


func _build_parts_popup() -> void:
	_parts_popup = PARTS_POPUP_SCENE.instantiate()
	_parts_popup.visible = false
	add_child(_parts_popup)
	move_child(_parts_popup, get_child_count() - 1)


func _open_shop() -> void:
	if is_instance_valid(_shop_popup):
		(_shop_popup as Control).call("open_popup")


func _open_parts_shop() -> void:
	if is_instance_valid(_parts_popup):
		(_parts_popup as Control).call("open_popup")


func _open_star_map() -> void:
	if is_instance_valid(_star_map_popup):
		(_star_map_popup as Control).call("open_for_control_room")


func _open_hangar_bay_popup(slot_index: int) -> void:
	if is_instance_valid(_hangar_bay_popup):
		(_hangar_bay_popup as Control).call("open_for_slot", slot_index)


func _scroll_to_zone(x_pos: float) -> void:
	if _scroll == null:
		return
	var max_scroll := maxi(0, int(_content.custom_minimum_size.x - _scroll.size.x))
	var target := clampi(int(x_pos), 0, max_scroll)
	var tween := create_tween()
	tween.tween_property(_scroll, "scroll_horizontal", target, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _input(event: InputEvent) -> void:
	if not visible or _scroll == null:
		return
	if (is_instance_valid(_star_map_popup) and _star_map_popup.visible) \
			or (is_instance_valid(_hangar_bay_popup) and _hangar_bay_popup.visible) \
			or (is_instance_valid(_shop_popup) and _shop_popup.visible) \
			or (is_instance_valid(_parts_popup) and _parts_popup.visible):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_dragging = true
			_drag_anchor = event.position
			_drag_scroll_start = _scroll.scroll_horizontal
			get_viewport().set_input_as_handled()
		else:
			_dragging = false
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		var delta := int(_drag_anchor.x - event.position.x)
		var max_scroll := maxi(0, int(_content.custom_minimum_size.x - _scroll.size.x))
		_scroll.scroll_horizontal = clampi(_drag_scroll_start + delta, 0, max_scroll)
		get_viewport().set_input_as_handled()


func _on_visibility_changed() -> void:
	if not visible and is_instance_valid(_star_map_popup):
		_star_map_popup.hide()
	if not visible and is_instance_valid(_hangar_bay_popup):
		_hangar_bay_popup.hide()
	if not visible and is_instance_valid(_shop_popup):
		_shop_popup.hide()
	if not visible and is_instance_valid(_parts_popup):
		_parts_popup.hide()
