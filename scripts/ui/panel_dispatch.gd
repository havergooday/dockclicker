extends Control

@onready var _back_button: Button = $Header/BackButton
@onready var _body: Control = $Body
@onready var _toast_label: Label = $ToastLabel

# Top strip
var _planet_strip: HBoxContainer
var _direct_btn: Button

# Slot card nodes (created once, content rebuilt on state change)
var _slot_cards: Array = [null, null, null]   # PanelContainer — style updated per state
var _slot_inner: Array = [null, null, null]   # VBoxContainer  — content cleared/refilled

# Live-update refs for timer slots
var _slot_progress:   Array = [null, null, null]
var _slot_timer_lbl:  Array = [null, null, null]
var _slot_total_time: Array = [0.0,  0.0,  0.0]

# Assignment wizard state
var _sel_slot: int = -1
var _sel_pilot_tier: int = 0
var _sel_planet: String = ""

func _ready() -> void:
	PanelManager.register_panel("dispatch", self)
	_back_button.pressed.connect(func(): PanelManager.show_bridge())
	GameState.player_status_changed.connect(func(_s): _rebuild_planet_strip())
	GameState.planet_unlocked.connect(func(_id): _rebuild_planet_strip())
	GameState.credits_changed.connect(func(_v): _refresh_credits_dependent())
	GameState.auto_slot_changed.connect(func(i: int): _rebuild_slot(i))
	GameState.auto_dispatch_returned.connect(func(i: int): _rebuild_slot(i))
	visibility_changed.connect(func():
		if visible:
			_apply_preselect()
	)
	_build_layout()

func _process(_delta: float) -> void:
	if not visible:
		return
	var now := Time.get_unix_time_from_system()
	for i in GameState.auto_slots.size():
		var slot: DispatchManager.AutoSlot = GameState.auto_slots[i] as DispatchManager.AutoSlot
		if slot.state == "on_mission":
			_tick_timer(i, slot.mission_end_time, now)
		elif slot.state == "returning":
			_tick_timer(i, slot.return_end_time, now)

func _tick_timer(index: int, end_time: float, now: float) -> void:
	var remaining := maxf(0.0, end_time - now)
	var lbl: Label = _slot_timer_lbl[index]
	var bar: ProgressBar = _slot_progress[index]
	if lbl:
		lbl.text = "%d:%02d 남음" % [int(remaining) / 60, int(remaining) % 60]
	if bar:
		var total: float = _slot_total_time[index]
		if total > 0.0:
			bar.value = ((total - remaining) / total) * 100.0

func _apply_preselect() -> void:
	var presel: int = GameState.dispatch_preselect_slot
	if presel < 0:
		return
	GameState.dispatch_preselect_slot = -1
	if presel < GameState.auto_slots.size():
		var s: DispatchManager.AutoSlot = GameState.auto_slots[presel] as DispatchManager.AutoSlot
		if s.state == "offline":
			_sel_slot = presel
			_sel_pilot_tier = 0
			_sel_planet = ""
			_rebuild_slot(presel)

func _refresh_credits_dependent() -> void:
	_rebuild_planet_strip()
	for i in 3:
		if i < GameState.auto_slots.size():
			var s: DispatchManager.AutoSlot = GameState.auto_slots[i] as DispatchManager.AutoSlot
			if s.state == "locked":
				_rebuild_slot(i)

# ── Layout ────────────────────────────────────────────────────

func _build_layout() -> void:
	# ── Planet strip (top, fixed height) ────────────────────
	var strip := PanelContainer.new()
	strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	strip.offset_bottom = 58
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0.08, 0.05, 0.14)
	ss.border_color = Color(0.28, 0.16, 0.45)
	ss.border_width_bottom = 1
	ss.content_margin_left = 10
	ss.content_margin_right = 10
	ss.content_margin_top = 8
	ss.content_margin_bottom = 8
	strip.add_theme_stylebox_override("panel", ss)
	_body.add_child(strip)

	var strip_row := HBoxContainer.new()
	strip_row.add_theme_constant_override("separation", 10)
	strip.add_child(strip_row)

	var strip_lbl := Label.new()
	strip_lbl.text = "직접 출격"
	strip_lbl.add_theme_font_size_override("font_size", 11)
	strip_lbl.modulate = Color(0.75, 0.65, 1.0)
	strip_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	strip_lbl.custom_minimum_size = Vector2(72, 0)
	strip_row.add_child(strip_lbl)

	_planet_strip = HBoxContainer.new()
	_planet_strip.add_theme_constant_override("separation", 6)
	_planet_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_planet_strip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	strip_row.add_child(_planet_strip)

	_direct_btn = Button.new()
	_direct_btn.text = "직접 출격  ▶▶"
	_direct_btn.custom_minimum_size = Vector2(148, 36)
	_direct_btn.pressed.connect(_on_direct_dispatch_pressed)
	strip_row.add_child(_direct_btn)

	# ── Slot cards (fill remaining body) ────────────────────
	var slots_hbox := HBoxContainer.new()
	slots_hbox.add_theme_constant_override("separation", 8)
	slots_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	slots_hbox.offset_top = 62
	_body.add_child(slots_hbox)

	for i in 3:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		slots_hbox.add_child(card)
		_slot_cards[i] = card

		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 8)
		card.add_child(inner)
		_slot_inner[i] = inner

	_rebuild_planet_strip()
	for i in 3:
		_rebuild_slot(i)

# ── Planet strip ──────────────────────────────────────────────

func _rebuild_planet_strip() -> void:
	for c in _planet_strip.get_children():
		c.queue_free()

	for planet in GameState.PLANETS:
		var pid: String = planet["id"]
		var unlocked := GameState.is_planet_unlocked(pid)
		var selected := GameState.selected_planet == pid

		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_pressed = selected
		btn.custom_minimum_size = Vector2(118, 36)

		if unlocked:
			btn.text = planet["name"]
		else:
			btn.text = "%s  🔒 %d CR" % [planet["name"], planet["unlock_cost"]]
			btn.disabled = GameState.total_credits < int(planet["unlock_cost"])

		var norm := StyleBoxFlat.new()
		norm.bg_color = Color(0.11, 0.07, 0.20)
		norm.border_color = Color(0.35, 0.22, 0.55)
		norm.set_border_width_all(1)
		norm.set_corner_radius_all(4)
		norm.content_margin_left = 10
		norm.content_margin_right = 10
		norm.content_margin_top = 4
		norm.content_margin_bottom = 4
		btn.add_theme_stylebox_override("normal", norm)

		var sel := StyleBoxFlat.new()
		sel.bg_color = Color(0.20, 0.10, 0.38)
		sel.border_color = Color(0.68, 0.48, 1.0)
		sel.set_border_width_all(2)
		sel.set_corner_radius_all(4)
		sel.content_margin_left = 10
		sel.content_margin_right = 10
		sel.content_margin_top = 4
		sel.content_margin_bottom = 4
		btn.add_theme_stylebox_override("pressed", sel)
		btn.add_theme_stylebox_override("hover_pressed", sel.duplicate())

		btn.pressed.connect(func(): _on_planet_pressed(pid))
		_planet_strip.add_child(btn)

	_direct_btn.disabled = GameState.player_status != "idle"

func _on_planet_pressed(planet_id: String) -> void:
	if not GameState.is_planet_unlocked(planet_id):
		GameState.unlock_planet(planet_id)
		return
	GameState.selected_planet = planet_id
	_rebuild_planet_strip()

func _on_direct_dispatch_pressed() -> void:
	if GameState.player_status != "idle":
		return
	GameState.start_direct_dispatch()
	PanelManager.show_panel("clicker")

# ── Slot rebuild ──────────────────────────────────────────────

func _rebuild_slot(index: int) -> void:
	if index < 0 or index >= _slot_inner.size():
		return
	var inner: VBoxContainer = _slot_inner[index]
	if inner == null:
		return

	_slot_progress[index]  = null
	_slot_timer_lbl[index] = null
	_slot_total_time[index] = 0.0

	for c in inner.get_children():
		c.queue_free()

	var slot: DispatchManager.AutoSlot = null
	if index < GameState.auto_slots.size():
		slot = GameState.auto_slots[index] as DispatchManager.AutoSlot
	if slot == null:
		return

	(_slot_cards[index] as PanelContainer).add_theme_stylebox_override("panel", _card_style(slot.state))

	_add_header(inner, index, slot)
	inner.add_child(HSeparator.new())

	match slot.state:
		"locked":   _body_locked(inner, index, slot)
		"empty":    _body_empty(inner, index)
		"offline":  _body_offline(inner, index)
		"on_mission": _body_active(inner, index, slot, false)
		"returning":  _body_active(inner, index, slot, true)
		"returned":   _body_returned(inner, index, slot)

# ── Slot header row ───────────────────────────────────────────

func _add_header(parent: VBoxContainer, index: int, slot: DispatchManager.AutoSlot) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var slot_lbl := Label.new()
	slot_lbl.text = "SLOT %d" % (index + 1)
	slot_lbl.add_theme_font_size_override("font_size", 11)
	slot_lbl.modulate = Color(0.55, 0.55, 0.70)
	slot_lbl.custom_minimum_size = Vector2(58, 0)
	row.add_child(slot_lbl)

	if slot.state not in ["locked", "empty"]:
		var b: int = slot.machine.get("body",   0)
		var w: int = slot.machine.get("weapon", 0)
		var l: int = slot.machine.get("legs",   0)
		var mach_lbl := Label.new()
		mach_lbl.text = "몸체T%d  무기T%d  다리T%d" % [b, w, l]
		mach_lbl.add_theme_font_size_override("font_size", 11)
		mach_lbl.modulate = Color(0.72, 0.72, 0.85)
		mach_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(mach_lbl)

		if slot.state in ["on_mission", "returning", "returned"]:
			var mission_lbl := Label.new()
			mission_lbl.text = "T%d  •  %s" % [slot.pilot_tier, _planet_name(slot.planet)]
			mission_lbl.add_theme_font_size_override("font_size", 11)
			mission_lbl.modulate = Color(0.60, 0.85, 1.0)
			row.add_child(mission_lbl)
	else:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)

	var badge := Label.new()
	badge.text = _state_text(slot.state)
	badge.add_theme_font_size_override("font_size", 11)
	badge.modulate = _state_color(slot.state)
	row.add_child(badge)

# ── Slot bodies ───────────────────────────────────────────────

func _body_locked(parent: VBoxContainer, index: int, slot: DispatchManager.AutoSlot) -> void:
	parent.add_child(_vspacer())

	var cost_lbl := Label.new()
	cost_lbl.text = "%d CR" % slot.unlock_cost
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 20)
	cost_lbl.modulate = Color(0.85, 0.75, 0.50)
	parent.add_child(cost_lbl)

	var hint := Label.new()
	hint.text = "잠금 해제 비용"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(0.45, 0.45, 0.50)
	parent.add_child(hint)

	parent.add_child(_vspacer())

	var btn := Button.new()
	btn.text = "잠금 해제  ▶"
	btn.custom_minimum_size = Vector2(160, 36)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.disabled = GameState.total_credits < slot.unlock_cost
	btn.pressed.connect(func():
		if GameState.unlock_auto_slot(index):
			_show_toast("슬롯 %d 해금!" % (index + 1))
	)
	parent.add_child(btn)
	parent.add_child(_vspacer())

func _body_empty(parent: VBoxContainer, index: int) -> void:
	parent.add_child(_vspacer())

	var lbl := Label.new()
	lbl.text = "머신 없음"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.modulate = Color(0.45, 0.45, 0.60)
	parent.add_child(lbl)

	parent.add_child(_vspacer())

	var btn := Button.new()
	btn.text = "공작실에서 조립  ▶"
	btn.custom_minimum_size = Vector2(180, 36)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func():
		GameState.workshop_preselect_slot = index
		PanelManager.show_panel("workshop")
	)
	parent.add_child(btn)
	parent.add_child(_vspacer())

func _body_offline(parent: VBoxContainer, index: int) -> void:
	var is_sel := _sel_slot == index

	# ── 파일럿 선택 ───────────────────────────
	parent.add_child(_section_lbl("파일럿"))

	var pilot_qtys: Array = GameState.owned_parts["pilot"]
	var has_pilot := false
	var pilot_grp := ButtonGroup.new()
	var pilot_row := HBoxContainer.new()
	pilot_row.add_theme_constant_override("separation", 6)
	parent.add_child(pilot_row)

	for i in pilot_qtys.size():
		if pilot_qtys[i] <= 0:
			continue
		has_pilot = true
		var pt := i + 1
		var pd: Dictionary = GameState.PARTS["pilot"]["tiers"][i]
		var pbtn := Button.new()
		pbtn.text = "T%d  %s  ×%d" % [pt, pd["name"], pilot_qtys[i]]
		pbtn.toggle_mode = true
		pbtn.button_group = pilot_grp
		pbtn.button_pressed = (is_sel and _sel_pilot_tier == pt)
		pbtn.custom_minimum_size = Vector2(0, 32)
		var cap_pt: int = pt
		pbtn.pressed.connect(func():
			var prev := _sel_slot
			_sel_slot = index
			_sel_pilot_tier = cap_pt
			_sel_planet = ""
			if prev != index and prev >= 0:
				_rebuild_slot(prev)
			_rebuild_slot(index)
		)
		pilot_row.add_child(pbtn)

	if not has_pilot:
		var lbl := Label.new()
		lbl.text = "파일럿 없음  →  PC 터미널에서 고용"
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.modulate = Color(1.0, 0.55, 0.55)
		pilot_row.add_child(lbl)

	# ── 파견 지역 (파일럿 선택 후에만 표시) ──
	var sortie_btn := Button.new()
	sortie_btn.text = "출격  ▶▶"
	sortie_btn.custom_minimum_size = Vector2(120, 36)
	sortie_btn.disabled = true

	if is_sel and _sel_pilot_tier > 0:
		parent.add_child(_section_lbl("파견 지역"))

		var planet_row := HBoxContainer.new()
		planet_row.add_theme_constant_override("separation", 6)
		parent.add_child(planet_row)

		var accessible: Array = GameState.get_pilot_accessible_planets(_sel_pilot_tier)
		if accessible.is_empty():
			var lbl := Label.new()
			lbl.text = "접근 가능 지역 없음  →  PC 터미널에서 해금"
			lbl.add_theme_font_size_override("font_size", 11)
			lbl.modulate = Color(1.0, 0.75, 0.40)
			planet_row.add_child(lbl)
		else:
			var planet_grp := ButtonGroup.new()
			for planet in accessible:
				var pid: String = planet["id"]
				var plbtn := Button.new()
				plbtn.text = planet["name"]
				plbtn.toggle_mode = true
				plbtn.button_group = planet_grp
				plbtn.button_pressed = (_sel_planet == pid)
				plbtn.custom_minimum_size = Vector2(0, 32)
				plbtn.pressed.connect(func():
					_sel_planet = pid
					sortie_btn.disabled = false
				)
				planet_row.add_child(plbtn)

		if _sel_planet != "":
			sortie_btn.disabled = false

	parent.add_child(_vspacer())

	var btn_row := HBoxContainer.new()
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btn_spacer := Control.new()
	btn_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(btn_spacer)
	btn_row.add_child(sortie_btn)
	parent.add_child(btn_row)

	var cap_slot := index
	sortie_btn.pressed.connect(func():
		if GameState.start_auto_dispatch(cap_slot, _sel_pilot_tier, _sel_planet):
			_show_toast("슬롯 %d  파견 시작!" % (cap_slot + 1))
			_sel_slot = -1
			_sel_pilot_tier = 0
			_sel_planet = ""
	)

func _body_active(parent: VBoxContainer, index: int, slot: DispatchManager.AutoSlot, is_return: bool) -> void:
	var state_lbl := Label.new()
	state_lbl.text = "귀환 중" if is_return else "파견 진행 중"
	state_lbl.add_theme_font_size_override("font_size", 13)
	state_lbl.modulate = _state_color(slot.state)
	parent.add_child(state_lbl)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	bar.custom_minimum_size = Vector2(0, 18)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(bar)
	_slot_progress[index] = bar

	var timer_lbl := Label.new()
	timer_lbl.add_theme_font_size_override("font_size", 12)
	timer_lbl.modulate = Color(0.70, 0.70, 0.75)
	parent.add_child(timer_lbl)
	_slot_timer_lbl[index] = timer_lbl

	var b: int = slot.machine.get("body",   1)
	var w: int = slot.machine.get("weapon", 1)
	var l: int = slot.machine.get("legs",   1)
	var preview: Dictionary = GameState.get_machine_preview(b, w, l)
	_slot_total_time[index] = preview["return_time"] if is_return else preview["mission_time"]

	parent.add_child(_vspacer())

	var cr_lbl := Label.new()
	cr_lbl.text = "예상 수익: %d CR" % preview["credits"]
	cr_lbl.add_theme_font_size_override("font_size", 12)
	cr_lbl.modulate = Color(0.70, 1.0, 0.60)
	cr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	parent.add_child(cr_lbl)

func _body_returned(parent: VBoxContainer, index: int, slot: DispatchManager.AutoSlot) -> void:
	parent.add_child(_vspacer())

	var title := Label.new()
	title.text = "귀환 완료"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	title.modulate = _state_color("returned")
	parent.add_child(title)

	var cr_lbl := Label.new()
	cr_lbl.text = "%d CR 획득" % slot.credits_earned
	cr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cr_lbl.add_theme_font_size_override("font_size", 22)
	cr_lbl.modulate = Color(1.0, 0.90, 0.30)
	parent.add_child(cr_lbl)

	parent.add_child(_vspacer())

	var btn := Button.new()
	btn.text = "수령  ▶"
	btn.custom_minimum_size = Vector2(160, 40)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func():
		if GameState.collect_auto_slot(index):
			_show_toast("슬롯 %d  수령 완료!" % (index + 1))
	)
	parent.add_child(btn)
	parent.add_child(_vspacer())

# ── Helpers ───────────────────────────────────────────────────

func _vspacer() -> Control:
	var s := Control.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s

func _section_lbl(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.modulate = Color(0.55, 0.55, 0.72)
	return lbl

func _planet_name(planet_id: String) -> String:
	return GameState.get_planet(planet_id).get("name", planet_id)

func _state_color(state: String) -> Color:
	match state:
		"locked":     return Color(0.45, 0.40, 0.55)
		"empty":      return Color(0.45, 0.45, 0.65)
		"offline":    return Color(0.45, 0.65, 1.00)
		"on_mission": return Color(0.95, 0.70, 0.25)
		"returning":  return Color(0.25, 0.82, 0.92)
		"returned":   return Color(0.35, 0.95, 0.55)
	return Color.WHITE

func _state_text(state: String) -> String:
	match state:
		"locked":     return "🔒 잠금"
		"empty":      return "비어있음"
		"offline":    return "대기 중"
		"on_mission": return "파견 중"
		"returning":  return "귀환 중"
		"returned":   return "귀환 완료 ✓"
	return state

func _card_style(state: String) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	var accent := _state_color(state)
	s.bg_color = Color(0.07, 0.05, 0.13)
	s.border_color = accent.darkened(0.25)
	s.set_border_width_all(1)
	s.border_width_top = 3
	s.set_corner_radius_all(5)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

func _show_toast(msg: String) -> void:
	_toast_label.text = msg
	_toast_label.modulate.a = 1.0
	_toast_label.visible = true
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(_toast_label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func(): _toast_label.visible = false)
