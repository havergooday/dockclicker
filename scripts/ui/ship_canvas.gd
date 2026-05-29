extends Control

const STAR_MAP_SCENE         := preload("res://scenes/ui/star_map_popup.tscn")
const HANGAR_BAY_POPUP_SCENE := preload("res://scenes/ui/hangar_bay_popup.tscn")
const SHOP_POPUP_SCENE       := preload("res://scenes/ui/shop_popup.tscn")
const PARTS_POPUP_SCENE      := preload("res://scenes/ui/parts_shop_popup.tscn")
const BRIDGE_PILOT_SCR       := preload("res://scripts/ui/bridge_pilot.gd")
const HANGAR_ZONE_SCR        := preload("res://scripts/ui/hangar_zone.gd")

const NAV_ITEMS: Array = [
	{"id": "hangar", "label": "격납고", "x": 0.0},
	{"id": "bridge", "label": "브릿지", "x": 1200.0},
	{"id": "control", "label": "관제실", "x": 2420.0},
]

const DECK_HEIGHT      := 300.0  # 데크 한 층 높이 (= 창 높이)
const DECK_SNAP_THRESH := 55.0   # 이 거리 이상 드래그해야 데크 전환
const AXIS_LOCK_PX     := 10.0   # H/V 축 고정 임계값
const OPTIONS_H        := 168.0  # 옵션 팝업 높이

var _scroll: ScrollContainer
var _content: Control
var _popups: Dictionary = {}           # key → Control
var _bridge_zone_root: Control = null  # 파일럿 로밍용 컨테이너 참조
var _bridge_pilots: Dictionary = {}    # pilot_id → BridgePilot node
var _dragging := false
var _drag_anchor := Vector2.ZERO
var _drag_current_pos := Vector2.ZERO
var _drag_scroll_start := 0
var _drag_axis: String = ""            # "" | "h" | "v"
var _current_deck: int = 0            # 0 = 상부, 1 = 하부
var _deck_btn: Button = null
var _options_popup: Control = null
var _options_panel: PanelContainer = null
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
	scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scroll)
	_scroll = scroll

	_content = Control.new()
	_content.name = "ShipContent"
	_content.custom_minimum_size = Vector2(3700, DECK_HEIGHT * 2.0)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(_content)

	_build_background()
	_build_zone_panels()
	_build_zone_dividers()
	_build_nav_bar()
	_build_popups()
	_build_options_popup()


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
	bar.offset_left = -310.0
	bar.offset_right = 310.0
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

	# 왼쪽 옵션 버튼
	var opt_btn := Button.new()
	opt_btn.text = "⚙"
	opt_btn.custom_minimum_size = Vector2(30, 26)
	opt_btn.add_theme_font_size_override("font_size", 12)
	opt_btn.pressed.connect(func():
		if is_instance_valid(_options_popup) and _options_popup.visible:
			_close_options()
		else:
			_open_options()
	)
	row.add_child(opt_btn)

	var sep_l := ColorRect.new()
	sep_l.custom_minimum_size = Vector2(1, 0)
	sep_l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sep_l.color = Color(0.28, 0.40, 0.60, 0.45)
	row.add_child(sep_l)

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

	# 데크 구분선
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(1, 0)
	sep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sep.color = Color(0.28, 0.40, 0.60, 0.45)
	row.add_child(sep)

	# 데크 전환 버튼
	_deck_btn = Button.new()
	_deck_btn.text = "▼ 숙소"
	_deck_btn.custom_minimum_size = Vector2(66, 26)
	_deck_btn.add_theme_font_size_override("font_size", 10)
	_deck_btn.pressed.connect(func(): _snap_to_deck(1 - _current_deck))
	row.add_child(_deck_btn)


func _build_zone_panels() -> void:
	_make_hangar_zone()
	_make_bridge_zone()
	_make_control_zone()
	_make_lower_deck()


func _make_hangar_zone() -> void:
	var zone: Control = HANGAR_ZONE_SCR.new()
	zone.anchor_left   = 0.0
	zone.anchor_top    = 0.0
	zone.anchor_right  = 0.0
	zone.anchor_bottom = 0.0
	zone.offset_left   = 0.0
	zone.offset_top    = 0.0
	zone.offset_right  = 1200.0
	zone.offset_bottom = DECK_HEIGHT
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
	call_deferred("_sync_bridge_pilots")


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
	zone.anchor_bottom = 0.0
	zone.offset_left   = x_start
	zone.offset_top    = 0.0
	zone.offset_right  = x_end
	zone.offset_bottom = DECK_HEIGHT
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
		wall.anchor_bottom = 0.0
		wall.offset_left   = x - 8.0
		wall.offset_right  = x + 8.0
		wall.offset_top    = 0.0
		wall.offset_bottom = DECK_HEIGHT
		wall.color = Color(0.07, 0.09, 0.13, 1.0)
		wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(wall)

		for dx in [-7.0, 6.0]:
			var edge := ColorRect.new()
			edge.anchor_left   = 0.0
			edge.anchor_top    = 0.0
			edge.anchor_right  = 0.0
			edge.anchor_bottom = 0.0
			edge.offset_left   = x + dx
			edge.offset_right  = x + dx + 2.0
			edge.offset_top    = 0.0
			edge.offset_bottom = DECK_HEIGHT
			edge.color = Color(0.18, 0.26, 0.40, 0.85)
			edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_content.add_child(edge)


func _make_lower_deck() -> void:
	var zone := Control.new()
	zone.anchor_left   = 0.0
	zone.anchor_top    = 0.0
	zone.anchor_right  = 0.0
	zone.anchor_bottom = 0.0
	zone.offset_left   = 0.0
	zone.offset_top    = DECK_HEIGHT
	zone.offset_right  = 3700.0
	zone.offset_bottom = DECK_HEIGHT * 2.0
	zone.mouse_filter  = Control.MOUSE_FILTER_IGNORE

	# 배경
	var bg_sty := StyleBoxFlat.new()
	bg_sty.bg_color       = Color(0.03, 0.05, 0.09, 1.0)
	bg_sty.border_color   = Color(0.20, 0.32, 0.50, 0.70)
	bg_sty.border_width_top = 2
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", bg_sty)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(bg)

	# 바닥 줄무늬 — 숙소 느낌
	for i in 6:
		var stripe := ColorRect.new()
		stripe.anchor_left   = 0.0
		stripe.anchor_top    = 0.0
		stripe.anchor_right  = 1.0
		stripe.anchor_bottom = 0.0
		stripe.offset_top    = float(i) * 50.0
		stripe.offset_bottom = float(i) * 50.0 + 1.0
		stripe.color = Color(0.12, 0.20, 0.34, 0.18)
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		zone.add_child(stripe)

	# 플레이스홀더 레이블
	var lbl := Label.new()
	lbl.text = "하부 데크 — 숙소"
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.modulate = Color(0.22, 0.32, 0.48)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(lbl)

	_content.add_child(zone)


# ── 팝업 관리 ─────────────────────────────────────────────────

func _build_popups() -> void:
	var bay_popup: Control = HANGAR_BAY_POPUP_SCENE.instantiate()
	bay_popup.connect("navigate_to_control_requested", func():
		_scroll_to_zone(2420.0)
		get_tree().create_timer(0.28).timeout.connect(_open_star_map)
	)
	_register_popup("star_map",  STAR_MAP_SCENE.instantiate())
	_register_popup("hangar_bay", bay_popup)
	_register_popup("shop",      SHOP_POPUP_SCENE.instantiate())
	_register_popup("parts",     PARTS_POPUP_SCENE.instantiate())


func _register_popup(key: String, node: Control) -> void:
	node.visible = false
	add_child(node)
	move_child(node, get_child_count() - 1)
	_popups[key] = node


func _open_star_map() -> void:
	if is_instance_valid(_popups.get("star_map")):
		_popups["star_map"].call("open_for_control_room")


func _open_hangar_bay_popup(slot_index: int) -> void:
	if is_instance_valid(_popups.get("hangar_bay")):
		_popups["hangar_bay"].call("open_for_slot", slot_index)


func _open_shop() -> void:
	if is_instance_valid(_popups.get("shop")):
		_popups["shop"].call("open_popup")


func _open_parts_shop() -> void:
	if is_instance_valid(_popups.get("parts")):
		_popups["parts"].call("open_popup")


# ── 파일럿 동기화 ─────────────────────────────────────────────

func _sync_bridge_pilots() -> void:
	if _bridge_zone_root == null:
		return
	var zone_w := 1220.0
	var zone_h := maxf(_bridge_zone_root.size.y, 240.0)
	var current_ids := {}
	for p in GameState.hired_pilots:
		var pid: String = str(p.get("id", ""))
		current_ids[pid] = true
		if _bridge_pilots.has(pid):
			continue
		var node: Control = BRIDGE_PILOT_SCR.new()
		_bridge_zone_root.add_child(node)
		node.position = Vector2(randf_range(20.0, zone_w - 68.0), zone_h * 0.55)
		node.call("setup", p, 0.0, zone_w)
		_bridge_pilots[pid] = node
	for pid in _bridge_pilots.keys():
		if not current_ids.has(pid):
			(_bridge_pilots[pid] as Control).queue_free()
			_bridge_pilots.erase(pid)


# ── 네비게이션 ────────────────────────────────────────────────

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
	for popup in _popups.values():
		if is_instance_valid(popup) and popup.visible:
			return
	if is_instance_valid(_options_popup) and _options_popup.visible:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_dragging = true
			_drag_anchor       = event.position
			_drag_current_pos  = event.position
			_drag_scroll_start = _scroll.scroll_horizontal
			_drag_axis         = ""
			get_viewport().set_input_as_handled()
		else:
			if _dragging and _drag_axis == "v":
				_handle_deck_snap()
			_dragging  = false
			_drag_axis = ""
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _dragging:
		_drag_current_pos = event.position
		var delta: Vector2 = (event as InputEventMouseMotion).position - _drag_anchor

		if _drag_axis == "":
			if abs(delta.x) >= AXIS_LOCK_PX:
				_drag_axis = "h"
			elif abs(delta.y) >= AXIS_LOCK_PX:
				_drag_axis = "v"

		if _drag_axis == "h":
			var dx := int(_drag_anchor.x - event.position.x)
			var max_h := maxi(0, int(_content.custom_minimum_size.x - _scroll.size.x))
			_scroll.scroll_horizontal = clampi(_drag_scroll_start + dx, 0, max_h)
			get_viewport().set_input_as_handled()
		elif _drag_axis == "v":
			# 드래그 중 부분 스크롤로 시각적 피드백
			var dy: float = event.position.y - _drag_anchor.y
			var base_y := int(_current_deck * DECK_HEIGHT)
			_scroll.scroll_vertical = clampi(int(float(base_y) - dy), 0, int(DECK_HEIGHT))
			get_viewport().set_input_as_handled()


func _handle_deck_snap() -> void:
	var dy: float = _drag_current_pos.y - _drag_anchor.y
	var target := _current_deck
	if _current_deck == 0 and dy < -DECK_SNAP_THRESH:
		target = 1
	elif _current_deck == 1 and dy > DECK_SNAP_THRESH:
		target = 0
	_snap_to_deck(target)


func _snap_to_deck(deck: int) -> void:
	_current_deck = deck
	var target_y := int(float(deck) * DECK_HEIGHT)
	var tween := create_tween()
	tween.tween_property(_scroll, "scroll_vertical", target_y, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_update_deck_indicator()


func _update_deck_indicator() -> void:
	if is_instance_valid(_deck_btn):
		_deck_btn.text = "▼ 숙소" if _current_deck == 0 else "▲ 상부"


func _build_options_popup() -> void:
	_options_popup = Control.new()
	_options_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options_popup.visible = false
	_options_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_options_popup)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.38)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_close_options()
	)
	_options_popup.add_child(dim)

	_options_panel = PanelContainer.new()
	_options_panel.anchor_left   = 0.0
	_options_panel.anchor_top    = 0.0
	_options_panel.anchor_right  = 1.0
	_options_panel.anchor_bottom = 0.0
	_options_panel.offset_top    = -OPTIONS_H
	_options_panel.offset_bottom = OPTIONS_H
	_options_panel.mouse_filter  = Control.MOUSE_FILTER_STOP
	var sty := StyleBoxFlat.new()
	sty.bg_color     = Color(0.04, 0.06, 0.11, 0.98)
	sty.border_color = Color(0.26, 0.38, 0.60, 0.88)
	sty.border_width_bottom = 1
	sty.content_margin_left   = 18
	sty.content_margin_right  = 18
	sty.content_margin_top    = 8
	sty.content_margin_bottom = 10
	_options_panel.add_theme_stylebox_override("panel", sty)
	_options_popup.add_child(_options_panel)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	_options_panel.add_child(root)

	# 헤더
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	root.add_child(hdr)
	var title := Label.new()
	title.text = "⚙  옵션"
	title.add_theme_font_size_override("font_size", 13)
	title.modulate = Color(0.80, 0.90, 1.0)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.custom_minimum_size = Vector2(26, 22)
	close_btn.pressed.connect(_close_options)
	hdr.add_child(close_btn)

	root.add_child(HSeparator.new())

	# 전체 음소거
	var mute_row := HBoxContainer.new()
	mute_row.add_theme_constant_override("separation", 8)
	root.add_child(mute_row)
	var mute_lbl := Label.new()
	mute_lbl.text = "전체 음소거"
	mute_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mute_lbl.add_theme_font_size_override("font_size", 11)
	mute_row.add_child(mute_lbl)
	var muted := AudioServer.is_bus_mute(0)
	var mute_btn := Button.new()
	mute_btn.toggle_mode = true
	mute_btn.button_pressed = muted
	mute_btn.text = "ON" if muted else "OFF"
	mute_btn.custom_minimum_size = Vector2(44, 22)
	mute_btn.modulate = Color(1.0, 0.50, 0.50) if muted else Color(0.60, 0.62, 0.68)
	mute_btn.toggled.connect(func(v: bool):
		mute_btn.text = "ON" if v else "OFF"
		mute_btn.modulate = Color(1.0, 0.50, 0.50) if v else Color(0.60, 0.62, 0.68)
		AudioServer.set_bus_mute(0, v)
	)
	mute_row.add_child(mute_btn)

	# 볼륨 슬라이더
	root.add_child(_build_volume_row("마스터", 0))
	var bgm_idx := AudioServer.get_bus_index("BGM")
	if bgm_idx >= 0:
		root.add_child(_build_volume_row("BGM", bgm_idx))
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		root.add_child(_build_volume_row("SFX", sfx_idx))


func _build_volume_row(label: String, bus_idx: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(56, 0)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.modulate = Color(0.68, 0.76, 0.90)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	var cur: float = db_to_linear(AudioServer.get_bus_volume_db(bus_idx))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = cur
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 20)
	row.add_child(slider)
	var val_lbl := Label.new()
	val_lbl.text = "%d%%" % int(cur * 100.0)
	val_lbl.custom_minimum_size = Vector2(34, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 10)
	val_lbl.modulate = Color(0.80, 0.88, 1.0)
	row.add_child(val_lbl)
	slider.value_changed.connect(func(v: float):
		val_lbl.text = "%d%%" % int(v * 100.0)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(maxf(v, 0.001)))
	)
	return row


func _open_options() -> void:
	if not is_instance_valid(_options_popup):
		return
	_options_popup.visible = true
	_options_panel.offset_top = -OPTIONS_H
	var tween := create_tween()
	tween.tween_property(_options_panel, "offset_top", 0.0, 0.20) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


func _close_options() -> void:
	if not is_instance_valid(_options_popup) or not _options_popup.visible:
		return
	var tween := create_tween()
	tween.tween_property(_options_panel, "offset_top", -OPTIONS_H, 0.16) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func(): _options_popup.visible = false)


func _on_visibility_changed() -> void:
	if visible:
		return
	for popup in _popups.values():
		if is_instance_valid(popup):
			popup.hide()
