extends Control

const STAR_MAP_SCENE         := preload("res://scenes/ui/star_map_popup.tscn")
const HANGAR_BAY_POPUP_SCENE := preload("res://scenes/ui/hangar_bay_popup.tscn")
const SHOP_POPUP_SCENE       := preload("res://scenes/ui/shop_popup.tscn")
const PARTS_POPUP_SCENE      := preload("res://scenes/ui/parts_shop_popup.tscn")
const FACILITY_POPUP_SCENE   := preload("res://scenes/ui/facility_management_popup.tscn")
const BRIDGE_PILOT_SCR       := preload("res://scripts/ui/bridge_pilot.gd")
const HANGAR_ZONE_SCR        := preload("res://scripts/ui/hangar_zone.gd")
const QUARTERS_ZONE_SCR      := preload("res://scripts/ui/quarters_zone.gd")
const PILOT_DETAIL_SCR       := preload("res://scripts/ui/pilot_detail_popup.gd")
const BED_DETAIL_SCR         := preload("res://scripts/ui/bed_detail_popup.gd")

const NAV_ITEMS: Array = [
	{"id": "quarters", "label": "숙소",   "x": 0.0},
	{"id": "bridge",   "label": "브릿지", "x": 1200.0},
	{"id": "control",  "label": "관제실", "x": 2420.0},
]

const DECK_HEIGHT      := 300.0  # 데크 한 층 높이 (= 창 높이)
const DECK_SNAP_THRESH := 55.0   # 이 거리 이상 드래그해야 데크 전환
const AXIS_LOCK_PX     := 10.0   # H/V 축 고정 임계값
const OPTIONS_H        := 200.0  # 옵션 팝업 높이

var _scroll: ScrollContainer
var _content: Control
var _popups: Dictionary = {}           # key → Control
var _bridge_zone_root: Control = null  # 파일럿 로밍용 컨테이너 참조
var _bridge_pilots: Dictionary = {}    # pilot_id → BridgePilot node
var _lounge_facility_layer: Control = null
var _dragging := false
var _drag_anchor := Vector2.ZERO
var _drag_current_pos := Vector2.ZERO
var _drag_scroll_start := 0
var _drag_axis: String = ""            # "" | "h" | "v"
var _current_deck: int = 0            # 0 = 상부, 1 = 하부
var _deck_btn: Button = null
var _hint_label: Label = null
var _options_popup: Control = null
var _options_panel: PanelContainer = null
var _placement_edit_btn: Button = null
var _grid_overlay: Control = null
var _nav_buttons: Dictionary = {}
var _hire_btn: Button = null
var _parts_btn: Button = null
var _facility_btn: Button = null
var _canvas_toast: Label = null
var _unlock_confirm_popup: Control = null
var _unlock_confirm_callback: Callable = Callable()
var _unlock_confirm_is_base_area: bool = false
var _locked_room_layer: Control = null


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
	_build_grid_overlay()
	_build_nav_bar()
	_build_popups()
	_build_options_popup()
	_build_canvas_toast()
	call_deferred("_refresh_control_buttons")
	call_deferred("_refresh_nav_buttons")
	GameState.feature_unlocked.connect(func(_id: String):
		_refresh_control_buttons()
		_refresh_nav_buttons()
	)
	GameState.ui_edit_mode_changed.connect(func(enabled: bool):
		_refresh_placement_edit_ui()
		_refresh_lounge_facilities()
		if is_instance_valid(_grid_overlay):
			_grid_overlay.queue_redraw()
		if enabled:
			_show_canvas_toast("배치 이동 모드 — 시설·침대를 끌어다 놓으세요")
		else:
			_show_canvas_toast("배치 완료")
	)


func _build_background() -> void:
	var lane := ColorRect.new()
	lane.set_anchors_preset(Control.PRESET_FULL_RECT)
	lane.color = Color(0.08, 0.10, 0.15, 0.35)
	_content.add_child(lane)


func _build_hint_label() -> void:
	var lbl := Label.new()
	lbl.anchor_left = 0.0; lbl.anchor_top = 0.0
	lbl.anchor_right = 0.0; lbl.anchor_bottom = 0.0
	lbl.offset_left   = 1230.0
	lbl.offset_top    = 220.0
	lbl.offset_right  = 2390.0
	lbl.offset_bottom = 290.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.modulate = Color(0.60, 0.70, 0.88, 0.65)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(lbl)
	_hint_label = lbl
	_refresh_hint_label()


func _refresh_hint_label() -> void:
	if not is_instance_valid(_hint_label):
		return
	var hint := _compute_hint()
	_hint_label.text = hint
	_hint_label.visible = hint != ""


func _compute_hint() -> String:
	if not GameState.is_feature_unlocked("pc_terminal"):
		var terminal_cost := GameState.get_feature_cost("pc_terminal")
		if GameState.total_credits < terminal_cost:
			return "직접 파견으로 크레딧을 모아 PC 터미널을 해금하세요 (%s)" % GameState.format_feature_cost("pc_terminal")
		return "PC 터미널 해금 준비됨 → 관제실의 파츠 버튼"
	if not GameState.is_feature_unlocked("pilot_workshop"):
		var workshop_cost := GameState.get_feature_cost("pilot_workshop")
		if GameState.total_credits < workshop_cost:
			return "직접 파견으로 크레딧을 모아 공작실 해금 비용을 모으세요 (%s)" % GameState.format_feature_cost("pilot_workshop")
		return "공작실 해금 준비됨 → 상단 ▼ 격납고 [잠] 버튼"
	if GameState.hired_pilots.is_empty():
		return "관제실에서 파일럿을 고용하고 머신을 조립해 자동 파견을 시작하세요"
	for slot_raw in GameState.auto_slots:
		var s := slot_raw as DispatchManager.AutoSlot
		if s.state in ["on_mission", "returning", "returned"]:
			return ""
	return "항성지도에서 파일럿·머신·행성을 배정해 자동 파견을 시작하세요"


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
		var zone_id := str(item["id"])
		var btn := Button.new()
		btn.text = str(item["label"])
		btn.custom_minimum_size = Vector2(0, 26)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		btn.button_group = nav_group
		btn.pressed.connect(func():
			if not _can_navigate_to_zone(zone_id):
				if zone_id == "quarters":
					_open_unlock_confirm("quarters", "숙소 해금", "침대 1개와 파일럿 거주 공간을 해금합니다.", "300 CR", func():
						_scroll_to_zone(zone_x)
					)
				return
			_scroll_to_zone(zone_x)
		)
		row.add_child(btn)
		_nav_buttons[zone_id] = btn

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
	_deck_btn.text = "▼ 격납고"
	_deck_btn.custom_minimum_size = Vector2(88, 26)
	_deck_btn.add_theme_font_size_override("font_size", 10)
	_deck_btn.pressed.connect(func():
		if not GameState.is_feature_unlocked("pilot_workshop"):
			if GameState.unlock_feature("pilot_workshop"):
				_snap_to_deck(1 - _current_deck)
			else:
				_show_canvas_toast("크레딧 부족 (%s 필요)" % GameState.format_feature_cost("pilot_workshop"))
			return
		_snap_to_deck(1 - _current_deck)
	)
	row.add_child(_deck_btn)


func _build_zone_panels() -> void:
	_make_quarters_zone()
	_make_bridge_zone()
	_make_control_zone()
	_make_hangar_zone()
	_build_locked_room_overlays()
	GameState.base_area_unlocks_changed.connect(_refresh_locked_room_overlays)


# 잠긴 생활 구역(라운지/식당/의무실)을 어두운 실루엣 + "복구 필요"로 표시하고
# 클릭하면 기지 해금(구역 해금) 확인 팝업을 띄운다.
const LOCKED_ROOM_DEFS: Array = [
	{"id": "lounge",  "x_start": 1280.0, "x_end": 1700.0, "label": "라운지"},
	{"id": "canteen", "x_start": 1720.0, "x_end": 2060.0, "label": "간이 식당"},
	{"id": "medbay",  "x_start": 2080.0, "x_end": 2400.0, "label": "의무실"},
]


func _build_locked_room_overlays() -> void:
	var layer := Control.new()
	layer.name = "LockedRoomLayer"
	layer.set_anchors_preset(Control.PRESET_TOP_LEFT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(layer)
	_locked_room_layer = layer
	_refresh_locked_room_overlays()


func _refresh_locked_room_overlays() -> void:
	if not is_instance_valid(_locked_room_layer):
		return
	for child in _locked_room_layer.get_children():
		child.queue_free()
	for def in LOCKED_ROOM_DEFS:
		var area_id := str(def["id"])
		if GameState.is_base_area_unlocked(area_id):
			continue
		_locked_room_layer.add_child(_make_locked_room_card(def))


func _make_locked_room_card(def: Dictionary) -> Control:
	var area_id := str(def["id"])
	var btn := Button.new()
	btn.anchor_left = 0.0; btn.anchor_top = 0.0
	btn.anchor_right = 0.0; btn.anchor_bottom = 0.0
	btn.offset_left   = float(def["x_start"])
	btn.offset_top    = 64.0
	btn.offset_right  = float(def["x_end"])
	btn.offset_bottom = DECK_HEIGHT - 16.0
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	var sty := StyleBoxFlat.new()
	sty.bg_color = Color(0.02, 0.03, 0.05, 0.88)
	sty.border_color = Color(0.32, 0.40, 0.55, 0.55)
	sty.set_border_width_all(1)
	sty.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", sty)
	var hov := sty.duplicate() as StyleBoxFlat
	hov.bg_color = Color(0.05, 0.08, 0.13, 0.85)
	hov.border_color = Color(0.50, 0.66, 0.90, 0.70)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", hov)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vb)

	var name_lbl := Label.new()
	name_lbl.text = str(def["label"])
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.modulate = Color(0.55, 0.62, 0.76)
	vb.add_child(name_lbl)

	var lock_lbl := Label.new()
	lock_lbl.text = "🔒 복구 필요"
	lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_lbl.add_theme_font_size_override("font_size", 10)
	lock_lbl.modulate = Color(0.78, 0.66, 0.42)
	vb.add_child(lock_lbl)

	var area := GameState.get_base_area_data(area_id)
	var cost_lbl := Label.new()
	cost_lbl.text = GameState.format_cost(area.get("cost", {}))
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 9)
	cost_lbl.modulate = Color(0.60, 0.72, 0.92)
	vb.add_child(cost_lbl)

	btn.pressed.connect(func(): _request_base_area_unlock(area_id))
	return btn


func _request_base_area_unlock(area_id: String) -> void:
	var area := GameState.get_base_area_data(area_id)
	if area.is_empty():
		return
	_open_unlock_confirm(
		area_id,
		"%s 기지 해금" % str(area.get("name", area_id)),
		"%s\n%s" % [str(area.get("desc", "")), "이 생활 구역을 복구합니다."],
		GameState.format_cost(area.get("cost", {})),
		Callable(),
		true
	)


func _make_hangar_zone() -> void:
	var zone: Control = HANGAR_ZONE_SCR.new()
	zone.anchor_left   = 0.0
	zone.anchor_top    = 0.0
	zone.anchor_right  = 0.0
	zone.anchor_bottom = 0.0
	zone.offset_left   = 0.0
	zone.offset_top    = DECK_HEIGHT        # 하부 데크
	zone.offset_right  = 3700.0
	zone.offset_bottom = DECK_HEIGHT * 2.0
	zone.connect("navigate_to_control_requested", func():
		_scroll_to_zone(2420.0)
		get_tree().create_timer(0.28).timeout.connect(_open_star_map)
	)
	zone.connect("bay_detail_requested", func(slot_index: int):
		_open_hangar_bay_popup(slot_index)
	)
	_content.add_child(zone)


func _make_quarters_zone() -> void:
	var zone: Control = QUARTERS_ZONE_SCR.new()
	zone.anchor_left   = 0.0; zone.anchor_top    = 0.0
	zone.anchor_right  = 0.0; zone.anchor_bottom = 0.0
	zone.offset_left   = 0.0;    zone.offset_top    = 0.0
	zone.offset_right  = 1200.0; zone.offset_bottom = DECK_HEIGHT
	zone.connect("bed_clicked", func(bed_idx: int):
		_open_bed_detail(bed_idx)
	)
	_content.add_child(zone)


func _make_bridge_zone() -> void:
	_make_zone_base(1200.0, 2420.0, "브릿지 / 파일럿 라운지")

	var facility_layer := Control.new()
	facility_layer.name = "LoungeFacilityLayer"
	facility_layer.anchor_left = 0.0
	facility_layer.anchor_top = 0.0
	facility_layer.anchor_right = 0.0
	facility_layer.anchor_bottom = 0.0
	facility_layer.offset_left = 1200.0
	facility_layer.offset_top = 80.0
	facility_layer.offset_right = 2420.0
	facility_layer.offset_bottom = DECK_HEIGHT - 10.0
	facility_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(facility_layer)
	_lounge_facility_layer = facility_layer

	# 파일럿 로밍 레이어 — 숙소(0~1200) + 브릿지(1200~2420) 전체를 커버
	var roam_layer := Control.new()
	roam_layer.name = "RoamLayer"
	roam_layer.anchor_left   = 0.0; roam_layer.anchor_top    = 0.0
	roam_layer.anchor_right  = 0.0; roam_layer.anchor_bottom = 0.0
	roam_layer.offset_left   = 0.0
	roam_layer.offset_top    = 50.0
	roam_layer.offset_right  = 2420.0
	roam_layer.offset_bottom = DECK_HEIGHT - 10.0
	roam_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(roam_layer)
	_bridge_zone_root = roam_layer

	GameState.pilot_hired.connect(func(_id): _sync_bridge_pilots())
	GameState.pilot_status_changed.connect(func(_id): _refresh_bridge_pilot_data())
	GameState.pilot_tier_up.connect(func(pid: String):
		var p := GameState.get_hired_pilot(pid)
		if not p.is_empty():
			_show_canvas_toast("%s 승급! → T%d" % [str(p.get("name", pid)), int(p.get("tier", 1))])
	)
	GameState.facilities_changed.connect(_refresh_lounge_facilities)
	call_deferred("_refresh_lounge_facilities")
	call_deferred("_sync_bridge_pilots")
	_build_hint_label()
	GameState.feature_unlocked.connect(func(_id): _refresh_hint_label())
	GameState.pilot_hired.connect(func(_id): _refresh_hint_label())
	GameState.auto_slot_changed.connect(func(_i): _refresh_hint_label())
	GameState.credits_changed.connect(func(_v): _refresh_hint_label())


func _make_control_zone() -> void:
	var zone := _make_zone_base(2420.0, 3700.0, "관제실")
	var body := zone.get_node("ZoneRoot/Body") as VBoxContainer
	body.add_theme_constant_override("separation", 8)

	var star_btn := Button.new()
	star_btn.text = "항성지도"
	star_btn.custom_minimum_size = Vector2(0, 34)
	star_btn.pressed.connect(func(): _open_star_map())
	body.add_child(star_btn)

	var facility_btn := Button.new()
	facility_btn.text = "시설관리"
	facility_btn.custom_minimum_size = Vector2(0, 34)
	facility_btn.pressed.connect(func(): _open_facility_management())
	body.add_child(facility_btn)
	_facility_btn = facility_btn

	var hire_btn := Button.new()
	hire_btn.custom_minimum_size = Vector2(0, 34)
	hire_btn.pressed.connect(func():
		if not GameState.is_feature_unlocked("pilot_workshop"):
			if GameState.unlock_feature("pilot_workshop"):
				_open_shop()
			else:
				_show_canvas_toast("크레딧 부족 (%s 필요)" % GameState.format_feature_cost("pilot_workshop"))
			return
		_open_shop()
	)
	body.add_child(hire_btn)
	_hire_btn = hire_btn

	var parts_btn := Button.new()
	parts_btn.custom_minimum_size = Vector2(0, 34)
	parts_btn.pressed.connect(func():
		if not GameState.is_feature_unlocked("pc_terminal"):
			if GameState.unlock_feature("pc_terminal"):
				_open_parts_shop()
			else:
				_show_canvas_toast("크레딧 부족 (%s 필요)" % GameState.format_feature_cost("pc_terminal"))
			return
		_open_parts_shop()
	)
	body.add_child(parts_btn)
	_parts_btn = parts_btn


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


func _build_grid_overlay() -> void:
	_grid_overlay = Control.new()
	_grid_overlay.name = "PlacementGridOverlay"
	_grid_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grid_overlay.custom_minimum_size = _content.custom_minimum_size
	_grid_overlay.draw.connect(_draw_grid_overlay)
	_content.add_child(_grid_overlay)
	_grid_overlay.queue_redraw()


func _draw_grid_overlay() -> void:
	if not GameState.ui_edit_mode:
		return
	_draw_grid_region("quarters", Color(0.46, 0.68, 1.0, 0.28), Color(0.18, 0.36, 0.82, 0.10))
	_draw_grid_region("lounge", Color(0.52, 0.90, 0.65, 0.30), Color(0.18, 0.58, 0.32, 0.10))


func _draw_grid_region(region_tag: String, line_color: Color, fill_color: Color) -> void:
	var bounds := GameState.get_placement_bounds(region_tag)
	if bounds.size == Vector2.ZERO:
		return
	var step := int(GameState.PLACEABLE_GRID_SIZE)
	_grid_overlay.draw_rect(bounds, fill_color, true)
	_grid_overlay.draw_rect(bounds, line_color, false, 1.0)
	for x in range(int(bounds.position.x), int(bounds.end.x) + 1, step):
		_grid_overlay.draw_line(Vector2(float(x), bounds.position.y), Vector2(float(x), bounds.end.y), line_color, 1.0)
	for y in range(int(bounds.position.y), int(bounds.end.y) + 1, step):
		_grid_overlay.draw_line(Vector2(bounds.position.x, float(y)), Vector2(bounds.end.x, float(y)), line_color, 1.0)




# ── 팝업 관리 ─────────────────────────────────────────────────

func _build_popups() -> void:
	var bay_popup: Control = HANGAR_BAY_POPUP_SCENE.instantiate()
	bay_popup.connect("navigate_to_control_requested", func():
		_scroll_to_zone(2420.0)
		get_tree().create_timer(0.28).timeout.connect(_open_star_map)
	)
	_register_popup("star_map",     STAR_MAP_SCENE.instantiate())
	_register_popup("hangar_bay",   bay_popup)
	_register_popup("shop",         SHOP_POPUP_SCENE.instantiate())
	var parts_popup: Control = PARTS_POPUP_SCENE.instantiate()
	parts_popup.open_facility_management_requested.connect(func():
		_close_exclusive_popups("facilities")
		_open_facility_management()
	)
	_register_popup("parts",        parts_popup)
	var facilities: Control = FACILITY_POPUP_SCENE.instantiate()
	facilities.unlock_confirm_requested.connect(func(feature_id: String, title: String, body: String, cost_text: String):
		_open_unlock_confirm(feature_id, title, body, cost_text, func():
			if is_instance_valid(_popups.get("facilities")):
				_popups["facilities"].call("_refresh_all")
		)
	)
	_register_popup("facilities",   facilities)
	_register_popup("pilot_detail", PILOT_DETAIL_SCR.new())
	_register_popup("bed_detail", BED_DETAIL_SCR.new())


func _register_popup(key: String, node: Control) -> void:
	node.visible = false
	add_child(node)
	move_child(node, get_child_count() - 1)
	_popups[key] = node


# 독점 팝업 키 목록 — 동시에 하나만 열릴 수 있음
const EXCLUSIVE_POPUPS: Array = ["star_map", "hangar_bay", "shop", "parts", "facilities"]

# 독점 팝업을 열기 전 나머지 독점 팝업을 모두 닫음
func _close_exclusive_popups(except_key: String = "") -> void:
	for key in EXCLUSIVE_POPUPS:
		if key == except_key: continue
		var popup = _popups.get(key)
		if is_instance_valid(popup) and popup.visible:
			if popup.has_method("close_popup"): popup.call("close_popup")
			else: popup.hide()


func _open_star_map() -> void:
	_close_exclusive_popups("star_map")
	if is_instance_valid(_popups.get("star_map")):
		_popups["star_map"].call("open_for_control_room")


func _open_hangar_bay_popup(slot_index: int) -> void:
	_close_exclusive_popups("hangar_bay")
	if is_instance_valid(_popups.get("hangar_bay")):
		_popups["hangar_bay"].call("open_for_slot", slot_index)


func _open_shop() -> void:
	_close_exclusive_popups("shop")
	if is_instance_valid(_popups.get("shop")):
		_popups["shop"].call("open_popup")


func _open_parts_shop() -> void:
	_close_exclusive_popups("parts")
	if is_instance_valid(_popups.get("parts")):
		_popups["parts"].call("open_popup")


func _open_facility_management() -> void:
	_close_exclusive_popups("facilities")
	if is_instance_valid(_popups.get("facilities")):
		_popups["facilities"].call("open_popup")


func _open_pilot_detail(pilot_id: String, bed_idx: int, slot_idx: int) -> void:
	if is_instance_valid(_popups.get("pilot_detail")):
		_popups["pilot_detail"].call("open", pilot_id, bed_idx, slot_idx)


func _open_bed_detail(bed_idx: int) -> void:
	if is_instance_valid(_popups.get("bed_detail")):
		_popups["bed_detail"].call("open", bed_idx)


func _open_unlock_confirm(feature_id: String, title: String, body: String, cost_text: String, success_callback: Callable = Callable(), is_base_area: bool = false) -> void:
	_close_exclusive_popups()
	_hide_unlock_confirm()
	_unlock_confirm_callback = success_callback
	_unlock_confirm_is_base_area = is_base_area

	_unlock_confirm_popup = Control.new()
	_unlock_confirm_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_unlock_confirm_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_unlock_confirm_popup)
	move_child(_unlock_confirm_popup, get_child_count() - 1)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.56)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_hide_unlock_confirm()
	)
	_unlock_confirm_popup.add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -190
	panel.offset_right = 190
	panel.offset_top = -96
	panel.offset_bottom = 96
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sty := StyleBoxFlat.new()
	sty.bg_color = Color(0.05, 0.07, 0.13, 0.98)
	sty.border_color = Color(0.48, 0.64, 0.86, 0.90)
	sty.set_border_width_all(1)
	sty.set_corner_radius_all(6)
	sty.content_margin_left = 14
	sty.content_margin_right = 14
	sty.content_margin_top = 12
	sty.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sty)
	_unlock_confirm_popup.add_child(panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.modulate = Color(0.90, 0.96, 1.0)
	vb.add_child(title_lbl)

	var body_lbl := Label.new()
	body_lbl.text = body
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.add_theme_font_size_override("font_size", 11)
	body_lbl.modulate = Color(0.72, 0.82, 0.96)
	body_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(body_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = "비용: %s" % cost_text
	cost_lbl.add_theme_font_size_override("font_size", 11)
	cost_lbl.modulate = Color(0.85, 0.78, 0.56)
	vb.add_child(cost_lbl)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	var cancel_btn := Button.new()
	cancel_btn.text = "취소"
	cancel_btn.custom_minimum_size = Vector2(0, 30)
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.pressed.connect(_hide_unlock_confirm)
	row.add_child(cancel_btn)
	var confirm_btn := Button.new()
	confirm_btn.text = "해금"
	confirm_btn.custom_minimum_size = Vector2(0, 30)
	confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_btn.pressed.connect(func():
		if _unlock_confirm_is_base_area:
			_confirm_unlock_base_area(feature_id)
		else:
			_confirm_unlock_feature(feature_id)
	)
	row.add_child(confirm_btn)


func _confirm_unlock_feature(feature_id: String) -> void:
	var ok := false
	if feature_id == "quarters":
		ok = GameState.unlock_feature("quarters")
	else:
		ok = GameState.unlock_feature(feature_id)
	if ok:
		var callback := _unlock_confirm_callback
		_hide_unlock_confirm()
		_show_canvas_toast("해금 완료")
		if callback.is_valid():
			callback.call()
	else:
		_show_canvas_toast("재화 부족")


func _confirm_unlock_base_area(area_id: String) -> void:
	if GameState.unlock_base_area(area_id):
		# canteen 구역은 기존 식사 보너스 feature와도 연동
		if area_id == "canteen" and not GameState.is_feature_unlocked("canteen"):
			GameState.unlocked_features.append("canteen")
		var callback := _unlock_confirm_callback
		_hide_unlock_confirm()
		_show_canvas_toast("구역 해금 완료")
		_refresh_locked_room_overlays()
		if callback.is_valid():
			callback.call()
	else:
		_show_canvas_toast("재화 부족 — 기지 해금 실패")


func _hide_unlock_confirm() -> void:
	_unlock_confirm_callback = Callable()
	if is_instance_valid(_unlock_confirm_popup):
		_unlock_confirm_popup.queue_free()
	_unlock_confirm_popup = null


# ── 파일럿 동기화 ─────────────────────────────────────────────

func _sync_bridge_pilots() -> void:
	if _bridge_zone_root == null:
		return
	var zone_w := 2400.0  # 숙소(0~1200) + 브릿지(1200~2420) 전체
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
		node.call("set_activity_point_provider", Callable(self, "get_activity_points"))
		_bridge_pilots[pid] = node
	for pid in _bridge_pilots.keys():
		if not current_ids.has(pid):
			(_bridge_pilots[pid] as Control).queue_free()
			_bridge_pilots.erase(pid)
	_refresh_bridge_pilot_data()


func _refresh_bridge_pilot_data() -> void:
	for p in GameState.hired_pilots:
		var pid: String = str(p.get("id", ""))
		if _bridge_pilots.has(pid):
			var node: Control = _bridge_pilots[pid]
			node.call("update_pilot_data", p)


func get_activity_points(activity: String) -> Array:
	var points: Array = []
	for slot_id in GameState.lounge_slots.keys():
		var facility_id := GameState.get_installed_facility(str(slot_id))
		if facility_id == "":
			continue
		var facility := GameState.get_facility_data(facility_id)
		if facility.is_empty():
			continue
		if facility.get("activity", "") == activity:
			var fallback: Vector2 = facility.get("use_point", Vector2.ZERO)
			points.append(GameState.get_placeable_position("facility_%s" % facility_id, fallback))
	return points


func _refresh_lounge_facilities() -> void:
	if not is_instance_valid(_lounge_facility_layer):
		return
	for child in _lounge_facility_layer.get_children():
		child.queue_free()
	for slot_id in GameState.lounge_slots.keys():
		var facility_id := GameState.get_installed_facility(str(slot_id))
		if facility_id == "":
			continue
		var facility := GameState.get_facility_data(facility_id)
		if facility.is_empty():
			continue
		_lounge_facility_layer.add_child(_make_lounge_facility_node(facility))


func _make_lounge_facility_node(facility: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(144, 56)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var use_point: Vector2 = facility.get("use_point", Vector2(1536, 192))
	var placeable_id := "facility_%s" % str(facility.get("id", ""))
	GameState.ensure_placeable_position(placeable_id, "lounge", use_point)
	var saved_pos := GameState.get_placeable_position(placeable_id, use_point)
	card.position = Vector2(saved_pos.x - 1200.0, saved_pos.y - 80.0)
	card.set_meta("placeable_id", placeable_id)
	card.set_meta("region_tag", "lounge")
	card.gui_input.connect(func(ev: InputEvent): _handle_placeable_drag(card, ev, Vector2(1200.0, 80.0)))

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.18, 0.16, 0.92)
	style.border_color = Color(0.48, 0.82, 0.62, 0.88)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	card.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 6
	vb.offset_right = -6
	vb.offset_top = 5
	vb.offset_bottom = -5
	vb.add_theme_constant_override("separation", 1)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vb)

	var label := Label.new()
	label.text = str(facility.get("name", "시설"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.modulate = Color(0.88, 0.96, 0.90)
	label.clip_text = true
	vb.add_child(label)

	var meta := Label.new()
	meta.text = "%s · %s" % [
		_facility_slot_caption(str(facility.get("slot_type", ""))),
		_facility_activity_caption(str(facility.get("activity", ""))),
	]
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta.add_theme_font_size_override("font_size", 9)
	meta.modulate = Color(0.66, 0.78, 0.82)
	meta.clip_text = true
	vb.add_child(meta)
	card.add_child(_make_placeable_drag_handle(placeable_id, "lounge"))
	return card


func _make_placeable_drag_handle(placeable_id: String, region_tag: String) -> Control:
	var handle := ColorRect.new()
	handle.visible = GameState.ui_edit_mode
	handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	handle.color = Color(0.52, 0.90, 0.65, 0.22)
	handle.set_anchors_preset(Control.PRESET_FULL_RECT)
	handle.set_meta("placeable_id", placeable_id)
	handle.set_meta("region_tag", region_tag)
	return handle


func _facility_slot_caption(slot_id: String) -> String:
	match slot_id:
		"rest":
			return "휴식"
		"table":
			return "식탁"
		"service":
			return "서비스"
		"medical":
			return "의무"
		"decor":
			return "장식"
		"wall":
			return "벽면"
	return "시설"


func _facility_activity_caption(activity: String) -> String:
	match activity:
		"rest":
			return "피로 회복"
		"play":
			return "스트레스 회복"
		"eat":
			return "기분 회복"
		"recover":
			return "회복"
	return "-"


func _handle_placeable_drag(node: Control, ev: InputEvent, local_origin: Vector2) -> void:
	if not GameState.ui_edit_mode:
		return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			node.set_meta("drag_offset", node.position - node.get_parent().get_local_mouse_position())
			get_viewport().set_input_as_handled()
		else:
			var placeable_id := str(node.get_meta("placeable_id", ""))
			var region_tag := str(node.get_meta("region_tag", "lounge"))
			GameState.set_placeable_position(placeable_id, region_tag, node.position + local_origin)
			node.modulate = Color(1, 1, 1)
			node.remove_meta("drag_offset")
			get_viewport().set_input_as_handled()
	elif ev is InputEventMouseMotion and node.has_meta("drag_offset"):
		var offset: Vector2 = node.get_meta("drag_offset")
		var placeable_id := str(node.get_meta("placeable_id", ""))
		var region_tag := str(node.get_meta("region_tag", "lounge"))
		var world_pos: Vector2 = node.get_parent().get_local_mouse_position() + offset + local_origin
		var candidate := GameState.clamp_placeable_position(placeable_id, region_tag, world_pos)
		if GameState.can_place_at(placeable_id, region_tag, candidate):
			node.position = candidate - local_origin
			node.modulate = Color(1, 1, 1)
		else:
			node.modulate = Color(1.0, 0.45, 0.45, 0.80)
		get_viewport().set_input_as_handled()


# ── 네비게이션 ────────────────────────────────────────────────

func _scroll_to_zone(x_pos: float) -> void:
	if _scroll == null:
		return
	var max_scroll := maxi(0, int(_content.custom_minimum_size.x - _scroll.size.x))
	var target := clampi(int(x_pos), 0, max_scroll)
	var tween := create_tween()
	tween.tween_property(_scroll, "scroll_horizontal", target, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 상부 존 이동 시 하부 데크(격납고)에 있으면 상부로 올라옴
	if _current_deck != 0:
		_snap_to_deck(0)


func _input(event: InputEvent) -> void:
	if not visible or _scroll == null:
		return
	# 상단 고정 팝업은 하단 캔버스 드래그 허용
	for key in _popups:
		var popup: Control = _popups[key]
		if key == "pilot_detail" or key == "bed_detail": continue
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
		_deck_btn.text = "▼ 격납고" if _current_deck == 0 else "▲ 상부"


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
	_options_panel.anchor_left   = 0.3
	_options_panel.anchor_top    = 0.0
	_options_panel.anchor_right  = 0.7
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

	var place_row := HBoxContainer.new()
	place_row.add_theme_constant_override("separation", 8)
	root.add_child(place_row)
	var place_lbl := Label.new()
	place_lbl.text = "배치 이동"
	place_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	place_lbl.add_theme_font_size_override("font_size", 11)
	place_row.add_child(place_lbl)
	var place_btn := Button.new()
	place_btn.toggle_mode = true
	place_btn.button_pressed = GameState.ui_edit_mode
	place_btn.custom_minimum_size = Vector2(44, 22)
	place_btn.toggled.connect(func(v: bool):
		GameState.set_ui_edit_mode(v)
	)
	place_row.add_child(place_btn)
	_placement_edit_btn = place_btn
	_refresh_placement_edit_ui()

	# 상태표시줄 위치 (상/하/좌/우)
	var hud_row := HBoxContainer.new()
	hud_row.add_theme_constant_override("separation", 6)
	root.add_child(hud_row)
	var hud_lbl := Label.new()
	hud_lbl.text = "상태표시줄"
	hud_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_lbl.add_theme_font_size_override("font_size", 11)
	hud_row.add_child(hud_lbl)
	var hud_btns: Dictionary = {}
	for opt in [["top", "상"], ["bottom", "하"], ["left", "좌"], ["right", "우"]]:
		var pos_id: String = opt[0]
		var btn := Button.new()
		btn.text = str(opt[1])
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(30, 22)
		btn.button_pressed = GameState.hud_position == pos_id
		btn.pressed.connect(func():
			GameState.set_hud_position(pos_id)
			for p in hud_btns.keys():
				(hud_btns[p] as Button).button_pressed = (p == pos_id)
		)
		hud_btns[pos_id] = btn
		hud_row.add_child(btn)

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
	_options_panel.offset_bottom = 0.0
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_options_panel, "offset_top", 0.0, 0.20)
	tween.parallel().tween_property(_options_panel, "offset_bottom", OPTIONS_H, 0.20)


func _close_options() -> void:
	if not is_instance_valid(_options_popup) or not _options_popup.visible:
		return
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_options_panel, "offset_top", -OPTIONS_H, 0.16)
	tween.parallel().tween_property(_options_panel, "offset_bottom", 0.0, 0.16)
	tween.tween_callback(func(): _options_popup.visible = false)


func _on_visibility_changed() -> void:
	if visible:
		return
	for popup in _popups.values():
		if is_instance_valid(popup) and popup.visible:
			if popup.has_method("close_popup"): popup.call("close_popup")
			else: popup.hide()


func _can_navigate_to_zone(zone_id: String) -> bool:
	match zone_id:
		"quarters": return GameState.is_feature_unlocked("quarters")
		_: return true


func _refresh_control_buttons() -> void:
	if is_instance_valid(_hire_btn):
		var locked := not GameState.is_feature_unlocked("pilot_workshop")
		_hire_btn.modulate = Color(0.50, 0.50, 0.60) if locked else Color(1, 1, 1)
		_hire_btn.text = "파일럿  [잠금]" if locked else "파일럿"
	if is_instance_valid(_parts_btn):
		var locked := not GameState.is_feature_unlocked("pc_terminal")
		_parts_btn.modulate = Color(0.50, 0.50, 0.60) if locked else Color(1, 1, 1)
		_parts_btn.text = "파츠  [잠금]" if locked else "파츠"


func _refresh_placement_edit_ui() -> void:
	if not is_instance_valid(_placement_edit_btn):
		return
	_placement_edit_btn.button_pressed = GameState.ui_edit_mode
	_placement_edit_btn.text = "ON" if GameState.ui_edit_mode else "OFF"
	_placement_edit_btn.modulate = Color(0.52, 0.90, 0.65) if GameState.ui_edit_mode else Color(0.60, 0.62, 0.68)


func _refresh_nav_buttons() -> void:
	var q_locked := not GameState.is_feature_unlocked("quarters")
	if _nav_buttons.has("quarters"):
		var btn: Button = _nav_buttons["quarters"]
		btn.modulate = Color(0.50, 0.50, 0.60) if q_locked else Color(1, 1, 1)
		btn.text = "숙소 [잠]" if q_locked else "숙소"
	if is_instance_valid(_deck_btn):
		var h_locked := not GameState.is_feature_unlocked("pilot_workshop")
		_deck_btn.modulate = Color(0.50, 0.50, 0.60) if h_locked else Color(1, 1, 1)
		if h_locked:
			_deck_btn.text = "▼ 격납고 [잠]"
		else:
			_update_deck_indicator()






func _build_canvas_toast() -> void:
	_canvas_toast = Label.new()
	_canvas_toast.visible = false
	_canvas_toast.anchor_left   = 0.5
	_canvas_toast.anchor_top    = 1.0
	_canvas_toast.anchor_right  = 0.5
	_canvas_toast.anchor_bottom = 1.0
	_canvas_toast.offset_left   = -200.0
	_canvas_toast.offset_right  =  200.0
	_canvas_toast.offset_top    = -52.0
	_canvas_toast.offset_bottom = -16.0
	_canvas_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_canvas_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_canvas_toast.add_theme_font_size_override("font_size", 11)
	_canvas_toast.modulate = Color(1.0, 0.85, 0.50)
	add_child(_canvas_toast)


func _show_canvas_toast(msg: String) -> void:
	if not is_instance_valid(_canvas_toast):
		return
	_canvas_toast.text = msg
	_canvas_toast.visible = true
	var tween := create_tween()
	tween.tween_interval(2.2)
	tween.tween_callback(func(): _canvas_toast.visible = false)
