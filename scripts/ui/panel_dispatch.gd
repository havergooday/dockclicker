extends Control

@onready var _back_button: Button = $Header/BackButton
@onready var _body: Control = $Body
@onready var _toast_label: Label = $ToastLabel

var _planet_zone: Control = null
var _slot_zone: Control   = null
var _dispatch_mode: bool  = false

# Live timer refs keyed by slot index
var _timer_labels:  Dictionary = {}
var _progress_bars: Dictionary = {}
var _total_times:   Dictionary = {}

var _unlock_popup: Control = null

const COMPACT_RATIO := 0.20
const TWEEN_DUR     := 0.28
const ROW_H         := 34


func _ready() -> void:
	PanelManager.register_panel("dispatch", self)
	_back_button.pressed.connect(func(): PanelManager.go_back())
	_back_button.text = "← %s" % PanelManager.get_back_label()
	PanelManager.panel_changed.connect(func(id: String):
		if id == "dispatch":
			_back_button.text = "← %s" % PanelManager.get_back_label()
	)
	GameState.player_status_changed.connect(func(_s):
		if not _dispatch_mode: _rebuild_planet_full()
		else: _rebuild_planet_compact()
	)
	GameState.planet_unlocked.connect(func(_id):
		_dismiss_popup()
		if _dispatch_mode: _rebuild_planet_compact()
		else: _rebuild_planet_full()
	)
	GameState.credits_changed.connect(func(_v):
		if not _dispatch_mode: _rebuild_planet_full()
	)
	GameState.auto_slot_changed.connect(func(_i):
		if _dispatch_mode: _rebuild_slot_list(GameState.selected_planet)
	)
	GameState.auto_dispatch_returned.connect(func(_i):
		if _dispatch_mode: _rebuild_slot_list(GameState.selected_planet)
	)
	visibility_changed.connect(func():
		if visible: _apply_preselect()
		else: _dismiss_popup()
	)
	_build_layout()


func _process(_delta: float) -> void:
	if not visible: return
	var now := Time.get_unix_time_from_system()
	for idx in _timer_labels:
		if idx >= GameState.auto_slots.size(): continue
		var slot: DispatchManager.AutoSlot = GameState.auto_slots[idx]
		if slot.state not in ["on_mission", "returning"]: continue
		var end_t := slot.mission_end_time if slot.state == "on_mission" else slot.return_end_time
		var remaining := maxf(0.0, end_t - now)
		var lbl: Label = _timer_labels[idx]
		if is_instance_valid(lbl):
			lbl.text = "%d:%02d" % [int(remaining) / 60, int(remaining) % 60]
		var bar: ProgressBar = _progress_bars.get(idx)
		if bar and is_instance_valid(bar):
			var total: float = _total_times.get(idx, 1.0)
			bar.value = ((total - remaining) / total) * 100.0


func _apply_preselect() -> void:
	var presel: int = GameState.dispatch_preselect_slot
	if presel < 0: return
	GameState.dispatch_preselect_slot = -1
	if presel < GameState.auto_slots.size():
		var s: DispatchManager.AutoSlot = GameState.auto_slots[presel]
		if s.state == "offline" and not _dispatch_mode:
			_enter_dispatch_mode(GameState.selected_planet)


# ── 레이아웃 기반 ──────────────────────────────────────────────

func _build_layout() -> void:
	for c in _body.get_children():
		c.queue_free()
	_timer_labels.clear()
	_progress_bars.clear()
	_total_times.clear()

	_planet_zone = Control.new()
	_planet_zone.anchor_left   = 0.0
	_planet_zone.anchor_top    = 0.0
	_planet_zone.anchor_right  = 1.0
	_planet_zone.anchor_bottom = 1.0
	_body.add_child(_planet_zone)

	_slot_zone = Control.new()
	_slot_zone.anchor_left   = 1.0
	_slot_zone.anchor_top    = 0.0
	_slot_zone.anchor_right  = 1.0
	_slot_zone.anchor_bottom = 1.0
	_slot_zone.visible = false
	_body.add_child(_slot_zone)

	_rebuild_planet_full()


# ── 행성 영역 (full) ───────────────────────────────────────────

func _rebuild_planet_full() -> void:
	for c in _planet_zone.get_children():
		c.queue_free()

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left   =  28
	root.offset_right  = -28
	root.offset_top    =  14
	root.offset_bottom = -14
	root.add_theme_constant_override("separation", 10)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	_planet_zone.add_child(root)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 22)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(btn_row)

	for planet in GameState.PLANETS:
		btn_row.add_child(_make_planet_btn_full(planet))

	var sel_data := GameState.get_planet(GameState.selected_planet)
	if not sel_data.is_empty():
		var spec_lbl := Label.new()
		spec_lbl.text = "적 HP %d  ·  %d CR/킬  ·  %d웨이브" % [
			sel_data.get("enemy_hp", 0),
			sel_data.get("credit_per_kill", 0),
			sel_data.get("wave_size", 0),
		]
		spec_lbl.add_theme_font_size_override("font_size", 11)
		spec_lbl.modulate = Color(0.58, 0.60, 0.78)
		spec_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(spec_lbl)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 14)
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(action_row)

	var direct_btn := Button.new()
	direct_btn.text = "직접 출격  ▶▶"
	direct_btn.custom_minimum_size = Vector2(152, 30)
	direct_btn.disabled = GameState.player_status != "idle"
	direct_btn.pressed.connect(_on_direct_dispatch_pressed)
	action_row.add_child(direct_btn)

	var dispatch_btn := Button.new()
	dispatch_btn.text = "파견  ▶"
	dispatch_btn.custom_minimum_size = Vector2(110, 30)
	dispatch_btn.pressed.connect(func():
		_enter_dispatch_mode(GameState.selected_planet)
	)
	action_row.add_child(dispatch_btn)


func _make_planet_btn_full(planet: Dictionary) -> Button:
	var pid: String     = planet["id"]
	var unlocked        := GameState.is_planet_unlocked(pid)
	var selected        := GameState.selected_planet == pid

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(142, 58)
	btn.toggle_mode = true
	btn.button_pressed = selected
	btn.add_theme_font_size_override("font_size", 12)
	btn.text = str(planet["name"]) if unlocked else "%s\n🔒  %s CR" % [planet["name"], _fmt_cr(int(planet["unlock_cost"]))]

	var sty := StyleBoxFlat.new()
	sty.bg_color     = Color(0.18, 0.10, 0.34, 0.88) if selected else Color(0.10, 0.06, 0.18, 0.80)
	sty.border_color = Color(0.58, 0.44, 0.88) if selected else (Color(0.36, 0.23, 0.56) if unlocked else Color(0.24, 0.24, 0.34))
	sty.set_border_width_all(1)
	sty.border_width_bottom = 3 if selected else 1
	sty.set_corner_radius_all(6)
	sty.content_margin_left   = 16
	sty.content_margin_right  = 16
	sty.content_margin_top    = 10
	sty.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal",  sty)
	btn.add_theme_stylebox_override("pressed", sty)
	if not unlocked:
		btn.modulate = Color(0.62, 0.62, 0.68)

	btn.pressed.connect(func():
		if not GameState.is_planet_unlocked(pid):
			_show_unlock_popup(pid)
			return
		GameState.selected_planet = pid
		_rebuild_planet_full()
	)
	return btn


# ── 행성 영역 (compact) ────────────────────────────────────────

func _rebuild_planet_compact() -> void:
	for c in _planet_zone.get_children():
		c.queue_free()

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left   =  8
	root.offset_right  = -6
	root.offset_top    = 10
	root.offset_bottom = -10
	root.add_theme_constant_override("separation", 6)
	_planet_zone.add_child(root)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size    = Vector2(0, 30)
	scroll.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 5)
	scroll.add_child(btn_row)

	for planet in GameState.PLANETS:
		btn_row.add_child(_make_planet_btn_compact(planet))

	var sel_data := GameState.get_planet(GameState.selected_planet)
	if not sel_data.is_empty():
		var name_lbl := Label.new()
		name_lbl.text = str(sel_data.get("name", ""))
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.modulate = Color(0.80, 0.78, 1.0)
		root.add_child(name_lbl)

	root.add_child(_vspacer())

	var direct_btn := Button.new()
	direct_btn.text = "직접 출격  ▶▶"
	direct_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	direct_btn.custom_minimum_size   = Vector2(0, 26)
	direct_btn.add_theme_font_size_override("font_size", 10)
	direct_btn.disabled = GameState.player_status != "idle"
	direct_btn.pressed.connect(_on_direct_dispatch_pressed)
	root.add_child(direct_btn)


func _make_planet_btn_compact(planet: Dictionary) -> Button:
	var pid: String = planet["id"]
	var unlocked    := GameState.is_planet_unlocked(pid)
	var selected    := GameState.selected_planet == pid

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(54, 26)
	btn.toggle_mode = true
	btn.button_pressed = selected
	btn.add_theme_font_size_override("font_size", 10)
	btn.text = str(planet.get("name", pid)) + ("" if unlocked else " 🔒")

	var sty := StyleBoxFlat.new()
	sty.bg_color     = Color(0.18, 0.10, 0.34, 0.88) if selected else Color(0.10, 0.06, 0.18, 0.80)
	sty.border_color = Color(0.55, 0.42, 0.85) if selected else Color(0.30, 0.20, 0.48)
	sty.set_border_width_all(1)
	sty.border_width_bottom = 2 if selected else 1
	sty.set_corner_radius_all(4)
	sty.content_margin_left   = 7
	sty.content_margin_right  = 7
	sty.content_margin_top    = 3
	sty.content_margin_bottom = 3
	btn.add_theme_stylebox_override("normal",  sty)
	btn.add_theme_stylebox_override("pressed", sty)
	if not unlocked:
		btn.modulate = Color(0.55, 0.55, 0.62)

	btn.pressed.connect(func():
		if not GameState.is_planet_unlocked(pid):
			_show_unlock_popup(pid)
			return
		GameState.selected_planet = pid
		_rebuild_planet_compact()
		_rebuild_slot_list(pid)
	)
	return btn


# ── 파견 모드 전환 ─────────────────────────────────────────────

func _enter_dispatch_mode(planet_id: String) -> void:
	if _dispatch_mode: return
	_dispatch_mode = true
	GameState.selected_planet = planet_id
	_rebuild_slot_list(planet_id)
	_rebuild_planet_compact()
	_slot_zone.visible = true
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(_planet_zone, "anchor_right", COMPACT_RATIO, TWEEN_DUR)
	tw.parallel().tween_property(_slot_zone,   "anchor_left",  COMPACT_RATIO, TWEEN_DUR)


func _exit_dispatch_mode() -> void:
	if not _dispatch_mode: return
	_dispatch_mode = false
	_timer_labels.clear()
	_progress_bars.clear()
	_total_times.clear()
	var tw := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(_planet_zone, "anchor_right", 1.0, TWEEN_DUR * 0.85)
	tw.parallel().tween_property(_slot_zone,   "anchor_left",  1.0, TWEEN_DUR * 0.85)
	tw.tween_callback(func():
		_slot_zone.visible = false
		_rebuild_planet_full()
	)


# ── 슬롯 리스트 ────────────────────────────────────────────────

func _rebuild_slot_list(planet_id: String) -> void:
	for c in _slot_zone.get_children():
		c.queue_free()
	_timer_labels.clear()
	_progress_bars.clear()
	_total_times.clear()

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left   =  8
	root.offset_right  = -10
	root.offset_top    =  6
	root.offset_bottom = -6
	root.add_theme_constant_override("separation", 0)
	_slot_zone.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header.custom_minimum_size = Vector2(0, 30)
	root.add_child(header)

	var planet_data := GameState.get_planet(planet_id)
	var hdr_lbl := Label.new()
	hdr_lbl.text = "→  %s  파견" % str(planet_data.get("name", planet_id))
	hdr_lbl.add_theme_font_size_override("font_size", 12)
	hdr_lbl.modulate = Color(0.70, 0.62, 1.0)
	hdr_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	header.add_child(hdr_lbl)

	var cancel_btn := Button.new()
	cancel_btn.text = "← 취소"
	cancel_btn.custom_minimum_size = Vector2(72, 24)
	cancel_btn.add_theme_font_size_override("font_size", 10)
	cancel_btn.pressed.connect(_exit_dispatch_mode)
	header.add_child(cancel_btn)

	var div := ColorRect.new()
	div.color = Color(0.28, 0.20, 0.45, 0.70)
	div.custom_minimum_size = Vector2(0, 1)
	root.add_child(div)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)

	for i in GameState.auto_slots.size():
		list.add_child(_make_slot_row(i, planet_id))


func _make_slot_row(index: int, planet_id: String) -> Control:
	var slot: DispatchManager.AutoSlot = GameState.auto_slots[index]

	var is_dispatchable := false
	if slot.state == "offline" and slot.assigned_pilot_id != "":
		var pilot := GameState.get_hired_pilot(slot.assigned_pilot_id)
		if not pilot.is_empty() and pilot.get("status", "") == "idle":
			for p in GameState.get_pilot_accessible_planets(slot.assigned_pilot_id):
				if p["id"] == planet_id:
					is_dispatchable = true
					break

	var is_returned := slot.state == "returned"

	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size   = Vector2(0, ROW_H)

	var sty := StyleBoxFlat.new()
	sty.set_corner_radius_all(3)
	sty.content_margin_left   = 10
	sty.content_margin_right  = 6
	sty.content_margin_top    = 0
	sty.content_margin_bottom = 0
	match slot.state:
		"offline":
			sty.bg_color     = Color(0.07, 0.10, 0.16, 0.70) if is_dispatchable else Color(0.05, 0.05, 0.09, 0.50)
			sty.border_color = Color(0.30, 0.40, 0.65, 0.80) if is_dispatchable else Color(0.16, 0.16, 0.26, 0.55)
		"on_mission":
			sty.bg_color     = Color(0.09, 0.07, 0.03, 0.70)
			sty.border_color = Color(0.65, 0.45, 0.15, 0.80)
		"returning":
			sty.bg_color     = Color(0.03, 0.08, 0.10, 0.70)
			sty.border_color = Color(0.20, 0.60, 0.72, 0.80)
		"returned":
			sty.bg_color     = Color(0.04, 0.10, 0.06, 0.80)
			sty.border_color = Color(0.22, 0.75, 0.38, 0.90)
		_:
			sty.bg_color     = Color(0.04, 0.04, 0.07, 0.35)
			sty.border_color = Color(0.14, 0.14, 0.20, 0.50)
	sty.set_border_width_all(1)
	row.add_theme_stylebox_override("panel", sty)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_child(hbox)

	# BAY 번호
	var bay_lbl := Label.new()
	bay_lbl.text = "BAY %02d" % (index + 1)
	bay_lbl.custom_minimum_size = Vector2(52, 0)
	bay_lbl.add_theme_font_size_override("font_size", 10)
	bay_lbl.modulate = Color(0.40, 0.42, 0.55) if slot.state in ["locked", "empty"] else Color(0.58, 0.62, 0.78)
	bay_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(bay_lbl)

	# 파일럿
	var pilot_lbl := Label.new()
	pilot_lbl.custom_minimum_size = Vector2(118, 0)
	pilot_lbl.add_theme_font_size_override("font_size", 11)
	pilot_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	match slot.state:
		"locked":
			pilot_lbl.text     = "🔒  %s CR" % _fmt_cr(slot.unlock_cost)
			pilot_lbl.modulate = Color(0.42, 0.42, 0.50)
		"empty":
			pilot_lbl.text     = "머신 없음"
			pilot_lbl.modulate = Color(0.38, 0.40, 0.54)
		"offline":
			if slot.assigned_pilot_id != "":
				var p := GameState.get_hired_pilot(slot.assigned_pilot_id)
				pilot_lbl.text     = str(p.get("name", slot.assigned_pilot_id)) if not p.is_empty() else slot.assigned_pilot_id
				pilot_lbl.modulate = Color(0.75, 0.88, 1.0) if is_dispatchable else Color(0.50, 0.60, 0.75)
			else:
				pilot_lbl.text     = "파일럿 미배정"
				pilot_lbl.modulate = Color(0.65, 0.42, 0.42)
		_:
			var pid := slot.pilot_id
			if pid != "":
				var p := GameState.get_hired_pilot(pid)
				pilot_lbl.text = str(p.get("name", pid)) if not p.is_empty() else pid
			else:
				pilot_lbl.text = "—"
			pilot_lbl.modulate = Color(0.65, 0.78, 0.95)
	hbox.add_child(pilot_lbl)

	# 머신 스펙
	var spec_lbl := Label.new()
	spec_lbl.custom_minimum_size = Vector2(96, 0)
	spec_lbl.add_theme_font_size_override("font_size", 10)
	spec_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if not slot.machine.is_empty():
		var b: int = slot.machine.get("body", 0)
		var w: int = slot.machine.get("weapon", 0)
		var l: int = slot.machine.get("legs", 0)
		spec_lbl.text     = "T%d · T%d · T%d" % [b, w, l]
		spec_lbl.modulate = Color(0.52, 0.58, 0.72)
	else:
		spec_lbl.text     = "—"
		spec_lbl.modulate = Color(0.28, 0.28, 0.38)
	hbox.add_child(spec_lbl)

	# 상태 / 타이머
	var status_area := HBoxContainer.new()
	status_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_area.add_theme_constant_override("separation", 8)
	hbox.add_child(status_area)

	match slot.state:
		"offline":
			var st_lbl := Label.new()
			st_lbl.text = "OFFLINE"
			st_lbl.add_theme_font_size_override("font_size", 10)
			st_lbl.modulate = Color(0.38, 0.55, 0.90) if is_dispatchable else Color(0.30, 0.32, 0.45)
			st_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			status_area.add_child(st_lbl)
		"on_mission", "returning":
			var bar := ProgressBar.new()
			bar.min_value = 0.0
			bar.max_value = 100.0
			bar.value     = 0.0
			bar.custom_minimum_size   = Vector2(90, 10)
			bar.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			status_area.add_child(bar)
			_progress_bars[index] = bar

			var timer_lbl := Label.new()
			timer_lbl.add_theme_font_size_override("font_size", 10)
			timer_lbl.modulate            = Color(0.90, 0.68, 0.22) if slot.state == "on_mission" else Color(0.22, 0.80, 0.90)
			timer_lbl.vertical_alignment  = VERTICAL_ALIGNMENT_CENTER
			timer_lbl.custom_minimum_size = Vector2(48, 0)
			status_area.add_child(timer_lbl)
			_timer_labels[index] = timer_lbl

			var preview := GameState.get_machine_preview(
				slot.machine.get("body", 1),
				slot.machine.get("weapon", 1),
				slot.machine.get("legs", 1)
			)
			_total_times[index] = preview["return_time"] if slot.state == "returning" else preview["mission_time"]
		"returned":
			var cr_lbl := Label.new()
			cr_lbl.text            = "+ %s CR" % _fmt_cr(slot.credits_earned)
			cr_lbl.add_theme_font_size_override("font_size", 11)
			cr_lbl.modulate        = Color(0.28, 1.00, 0.48)
			cr_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			status_area.add_child(cr_lbl)
		"locked":
			var lbl := Label.new()
			lbl.text     = "잠금"
			lbl.add_theme_font_size_override("font_size", 10)
			lbl.modulate = Color(0.32, 0.32, 0.42)
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			status_area.add_child(lbl)
		"empty":
			var lbl := Label.new()
			lbl.text     = "머신 없음"
			lbl.add_theme_font_size_override("font_size", 10)
			lbl.modulate = Color(0.32, 0.32, 0.48)
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			status_area.add_child(lbl)

	# 액션 버튼
	var action_w := Control.new()
	action_w.custom_minimum_size = Vector2(74, ROW_H)
	hbox.add_child(action_w)

	if is_dispatchable:
		var disp_btn := Button.new()
		disp_btn.text = "파견  ▶"
		disp_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		disp_btn.add_theme_font_size_override("font_size", 10)
		var cap_i      := index
		var cap_pid    := slot.assigned_pilot_id
		var cap_planet := planet_id
		disp_btn.pressed.connect(func():
			if GameState.start_auto_dispatch(cap_i, cap_pid, cap_planet):
				_show_toast("BAY %02d  파견 출발!" % (cap_i + 1))
			else:
				_show_toast("BAY %02d  파견 실패" % (cap_i + 1))
		)
		action_w.add_child(disp_btn)
	elif is_returned:
		var col_btn := Button.new()
		col_btn.text = "수령  ▶"
		col_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col_btn.add_theme_font_size_override("font_size", 10)
		var cap_i := index
		col_btn.pressed.connect(func():
			if GameState.collect_auto_slot(cap_i):
				_show_toast("BAY %02d  수령 완료!" % (cap_i + 1))
		)
		action_w.add_child(col_btn)

	return row


# ── 직접 출격 ──────────────────────────────────────────────────

func _on_direct_dispatch_pressed() -> void:
	if GameState.player_status != "idle": return
	GameState.start_direct_dispatch()
	PanelManager.show_panel("clicker")


# ── 잠금 행성 팝업 ─────────────────────────────────────────────

func _show_unlock_popup(planet_id: String) -> void:
	_dismiss_popup()
	var planet    := GameState.get_planet(planet_id)
	var cost: int  = int(planet.get("unlock_cost", 0))
	var can_afford := GameState.total_credits >= cost

	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 10
	_unlock_popup = overlay
	add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.60)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var popup := PanelContainer.new()
	popup.custom_minimum_size = Vector2(300, 0)
	var sty := StyleBoxFlat.new()
	sty.bg_color = Color(0.06, 0.04, 0.13, 0.97)
	sty.border_color = Color(0.52, 0.30, 0.80)
	sty.set_border_width_all(1)
	sty.border_width_top = 3
	sty.set_corner_radius_all(6)
	sty.content_margin_left   = 20
	sty.content_margin_right  = 20
	sty.content_margin_top    = 14
	sty.content_margin_bottom = 14
	popup.add_theme_stylebox_override("panel", sty)
	center.add_child(popup)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 7)
	popup.add_child(vb)

	var header_lbl := Label.new()
	header_lbl.text = "행성 해금"
	header_lbl.add_theme_font_size_override("font_size", 10)
	header_lbl.modulate = Color(0.55, 0.40, 0.80)
	vb.add_child(header_lbl)

	var name_lbl := Label.new()
	name_lbl.text = str(planet.get("name", planet_id))
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.modulate = Color(0.90, 0.88, 1.0)
	vb.add_child(name_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = "%s CR" % _fmt_cr(cost)
	cost_lbl.add_theme_font_size_override("font_size", 15)
	cost_lbl.modulate = Color(0.85, 0.74, 0.40) if can_afford else Color(1.0, 0.38, 0.38)
	vb.add_child(cost_lbl)

	if not can_afford:
		var short: int = cost - GameState.total_credits
		var warn := Label.new()
		warn.text = "크레딧 %s CR 부족" % _fmt_cr(short)
		warn.add_theme_font_size_override("font_size", 10)
		warn.modulate = Color(1.0, 0.45, 0.45)
		vb.add_child(warn)

	vb.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vb.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "취소"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.pressed.connect(_dismiss_popup)
	btn_row.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = "해금  ▶"
	confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_btn.disabled = not can_afford
	var cap_id := planet_id
	confirm_btn.pressed.connect(func():
		if GameState.unlock_planet(cap_id):
			GameState.selected_planet = cap_id
			_dismiss_popup()
	)
	btn_row.add_child(confirm_btn)

	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_dismiss_popup()
	)


func _dismiss_popup() -> void:
	if _unlock_popup:
		_unlock_popup.queue_free()
		_unlock_popup = null


# ── 헬퍼 ──────────────────────────────────────────────────────

func _vspacer() -> Control:
	var s := Control.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s


func _fmt_cr(n: int) -> String:
	var s := str(n)
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return out


func _show_toast(msg: String) -> void:
	_toast_label.text = msg
	_toast_label.modulate.a = 1.0
	_toast_label.visible = true
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(_toast_label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func(): _toast_label.visible = false)
