extends Control

const STAR_MAP_SCENE := preload("res://scenes/ui/star_map_popup.tscn")

const NAV_ITEMS: Array = [
	{"id": "hangar", "label": "격납고", "x": 0.0},
	{"id": "bridge", "label": "브릿지", "x": 1220.0},
	{"id": "control", "label": "관제실", "x": 2420.0},
]

var _scroll: ScrollContainer
var _content: Control
var _star_map_popup: Control
var _dragging := false
var _drag_anchor := Vector2.ZERO
var _drag_scroll_start := 0
var _nav_buttons: Dictionary = {}


func _ready() -> void:
	PanelManager.register_panel("bridge", self)
	_build_ui()
	visibility_changed.connect(_on_visibility_changed)
	call_deferred("_scroll_to_zone", 1220.0)


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
	_content.custom_minimum_size = Vector2(3600, 300)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(_content)

	_build_background()
	_build_zone_panels()
	_build_nav_bar()
	_build_star_map_popup()


func _build_background() -> void:
	var lane := ColorRect.new()
	lane.set_anchors_preset(Control.PRESET_FULL_RECT)
	lane.color = Color(0.08, 0.10, 0.15, 0.35)
	_content.add_child(lane)

	var line := ColorRect.new()
	line.position = Vector2(0, 149)
	line.size = Vector2(3600, 2)
	line.color = Color(0.22, 0.32, 0.48, 0.35)
	_content.add_child(line)


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
	_make_hangar_panel()
	_make_bridge_panel()
	_make_control_panel()


func _make_hangar_panel() -> Control:
	var panel := _make_zone_panel(Vector2(20, 58), Vector2(1080, 216), "좌측 격납고")
	var body := panel.get_node("Root/Body") as VBoxContainer

	var note := Label.new()
	note.text = "베이가 좌측으로 계속 붙는 확장형 구조"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	body.add_child(row)

	var workshop_btn := Button.new()
	workshop_btn.text = "공작실 팝업"
	workshop_btn.disabled = true
	row.add_child(workshop_btn)

	var status := Label.new()
	status.text = "베이 / 머신 / 수령 상태가 이 공간에 누적됩니다."
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(status)
	return panel


func _make_bridge_panel() -> Control:
	var panel := _make_zone_panel(Vector2(1180, 58), Vector2(1080, 216), "브릿지 / 파일럿 라운지")
	var body := panel.get_node("Root/Body") as VBoxContainer

	var intro := Label.new()
	intro.text = "파일럿 로밍과 꾸미기 가구가 누적되는 홈 공간"
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(intro)

	var pilot_count := Label.new()
	pilot_count.text = "고용 파일럿: %d명" % GameState.hired_pilots.size()
	body.add_child(pilot_count)

	var deco := Label.new()
	deco.text = "가구 / 오브젝트 / 생활 연출 자리"
	deco.modulate = Color(0.70, 0.82, 1.0)
	body.add_child(deco)
	return panel


func _make_control_panel() -> Control:
	var panel := _make_zone_panel(Vector2(2360, 58), Vector2(1060, 216), "관제실")
	var body := panel.get_node("Root/Body") as VBoxContainer
	body.add_theme_constant_override("separation", 8)

	var intro := Label.new()
	intro.text = "항성지도 팝업으로 파견, 슬롯, 기체 선택을 시작"
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(intro)

	var star_btn := Button.new()
	star_btn.text = "항성지도 열기"
	star_btn.custom_minimum_size = Vector2(0, 34)
	star_btn.pressed.connect(func():
		_open_star_map()
	)
	body.add_child(star_btn)

	var shop_btn := Button.new()
	shop_btn.text = "상점 / 고용"
	shop_btn.disabled = true
	body.add_child(shop_btn)

	var note := Label.new()
	note.text = "상점/고용 팝업은 같은 관제실 영역으로 이식됩니다."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)
	return panel


func _make_zone_panel(pos: Vector2, size: Vector2, title: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.size = size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.12, 0.88)
	style.border_color = Color(0.26, 0.40, 0.58, 0.92)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	_content.add_child(panel)

	var root := VBoxContainer.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.modulate = Color(0.76, 0.88, 1.0)
	root.add_child(title_lbl)

	var body := VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 6)
	root.add_child(body)
	return panel


func _build_star_map_popup() -> void:
	_star_map_popup = STAR_MAP_SCENE.instantiate()
	_star_map_popup.visible = false
	add_child(_star_map_popup)
	move_child(_star_map_popup, get_child_count() - 1)


func _open_star_map() -> void:
	if is_instance_valid(_star_map_popup):
		(_star_map_popup as Control).call("open_for_control_room")


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
	if is_instance_valid(_star_map_popup) and _star_map_popup.visible:
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
