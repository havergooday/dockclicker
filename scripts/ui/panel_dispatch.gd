extends Control

@onready var back_button: Button = $Header/BackButton
@onready var content_vbox: VBoxContainer = $ScrollContainer/ContentVBox
@onready var toast_label: Label = $ToastLabel

var _planet_container: HBoxContainer
var _direct_dispatch_btn: Button
var _auto_section: VBoxContainer

var _sel_slot: int = -1
var _sel_pilot_tier: int = 0
var _sel_planet: String = ""

func _ready() -> void:
	PanelManager.register_panel("dispatch", self)
	back_button.pressed.connect(func(): PanelManager.show_bridge())
	GameState.player_status_changed.connect(_on_player_status_changed)
	GameState.planet_unlocked.connect(func(_id): _rebuild_planet_buttons())
	GameState.credits_changed.connect(func(_v): _rebuild_planet_buttons())
	GameState.auto_slot_changed.connect(func(_i): _rebuild_auto_section())
	visibility_changed.connect(func():
		if visible:
			_apply_preselect()
	)
	_build_ui()


func _apply_preselect() -> void:
	var presel: int = GameState.dispatch_preselect_slot
	if presel < 0:
		return
	GameState.dispatch_preselect_slot = -1
	var presel_slot: DispatchManager.AutoSlot = GameState.auto_slots[presel] \
			if presel < GameState.auto_slots.size() else null
	if presel_slot != null and presel_slot.state == "offline":
		_sel_slot = presel
		_sel_pilot_tier = 0
		_sel_planet = ""
		_rebuild_auto_section()

func _build_ui() -> void:
	_build_direct_section()
	content_vbox.add_child(HSeparator.new())
	_build_auto_section_container()

# ── 직접 출격 ─────────────────────────────

func _build_direct_section() -> void:
	var title := Label.new()
	title.text = "── 직접 출격 ──"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_vbox.add_child(title)

	_planet_container = HBoxContainer.new()
	_planet_container.add_theme_constant_override("separation", 8)
	content_vbox.add_child(_planet_container)

	_direct_dispatch_btn = Button.new()
	_direct_dispatch_btn.text = "직접 출격"
	_direct_dispatch_btn.custom_minimum_size = Vector2(0, 44)
	_direct_dispatch_btn.pressed.connect(_on_direct_dispatch_pressed)
	content_vbox.add_child(_direct_dispatch_btn)

	_rebuild_planet_buttons()

func _rebuild_planet_buttons() -> void:
	for child in _planet_container.get_children():
		child.queue_free()
	for planet in GameState.PLANETS:
		_planet_container.add_child(_make_planet_btn(planet))
	_direct_dispatch_btn.disabled = GameState.player_status != "idle"

func _make_planet_btn(planet: Dictionary) -> Button:
	var pid: String = planet["id"]
	var unlocked := GameState.is_planet_unlocked(pid)
	var selected := GameState.selected_planet == pid
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(90, 60)
	btn.toggle_mode = true
	btn.button_pressed = selected
	if unlocked:
		btn.text = planet["name"] + ("\n[선택]" if selected else "")
	else:
		btn.text = "%s\n🔒 %d CR" % [planet["name"], planet["unlock_cost"]]
		btn.disabled = GameState.total_credits < int(planet["unlock_cost"])
	btn.pressed.connect(func(): _on_planet_pressed(pid))
	return btn

func _on_planet_pressed(planet_id: String) -> void:
	if not GameState.is_planet_unlocked(planet_id):
		if not GameState.unlock_planet(planet_id):
			return
	GameState.selected_planet = planet_id
	_rebuild_planet_buttons()

func _on_direct_dispatch_pressed() -> void:
	if GameState.player_status != "idle":
		return
	GameState.start_direct_dispatch()
	PanelManager.show_panel("clicker")

func _on_player_status_changed(status: String) -> void:
	_direct_dispatch_btn.disabled = status != "idle"

# ── 자동 파견 ─────────────────────────────

func _build_auto_section_container() -> void:
	var title := Label.new()
	title.text = "── 자동 파견 ──"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_vbox.add_child(title)

	_auto_section = VBoxContainer.new()
	_auto_section.add_theme_constant_override("separation", 6)
	content_vbox.add_child(_auto_section)

	_rebuild_auto_section()

func _rebuild_auto_section() -> void:
	if _auto_section == null:
		return
	for child in _auto_section.get_children():
		child.queue_free()

	var offline_slots: Array = []
	for i in GameState.auto_slots.size():
		var s: DispatchManager.AutoSlot = GameState.auto_slots[i]
		if s.state == "offline":
			offline_slots.append(i)

	if offline_slots.is_empty():
		var lbl := Label.new()
		lbl.text = "출격 가능한 머신 없음\n(격납고에서 조립)"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.modulate = Color(1, 1, 1, 0.5)
		_auto_section.add_child(lbl)
		return

	# _sel_slot이 더 이상 offline이 아니면 초기화
	if _sel_slot != -1:
		var sel_valid := _sel_slot < GameState.auto_slots.size()
		if sel_valid:
			var sel_s: DispatchManager.AutoSlot = GameState.auto_slots[_sel_slot]
			sel_valid = sel_s.state == "offline"
		if not sel_valid:
			_sel_slot = -1
			_sel_pilot_tier = 0
			_sel_planet = ""

	# 머신 선택
	var machine_title := Label.new()
	machine_title.text = "머신 선택"
	_auto_section.add_child(machine_title)

	var machine_grp := ButtonGroup.new()
	for si in offline_slots:
		var slot_si: DispatchManager.AutoSlot = GameState.auto_slots[si]
		var mbtn := Button.new()
		mbtn.text = "슬롯 %d   몸체%d / 무기%d / 다리%d" % [
			si + 1,
			slot_si.machine.get("body", 0),
			slot_si.machine.get("weapon", 0),
			slot_si.machine.get("legs", 0),
		]
		mbtn.toggle_mode = true
		mbtn.button_group = machine_grp
		mbtn.button_pressed = (_sel_slot == si)
		var captured_si: int = si
		mbtn.pressed.connect(func():
			_sel_slot = captured_si
			_sel_pilot_tier = 0
			_sel_planet = ""
			_rebuild_auto_section()
		)
		_auto_section.add_child(mbtn)

	if _sel_slot == -1:
		return

	_auto_section.add_child(HSeparator.new())

	# 파일럿 선택 (보유 수량 > 0인 등급만 표시)
	var pilot_title := Label.new()
	pilot_title.text = "파일럿 선택"
	_auto_section.add_child(pilot_title)

	var pilot_qtys: Array = GameState.owned_parts["pilot"]
	var has_pilot := false

	var sortie_btn := Button.new()
	sortie_btn.text = "출격"
	sortie_btn.custom_minimum_size = Vector2(0, 40)
	sortie_btn.disabled = true

	var pilot_grp := ButtonGroup.new()
	for i in pilot_qtys.size():
		if pilot_qtys[i] <= 0:
			continue
		has_pilot = true
		var pt := i + 1
		var pd: Dictionary = GameState.PARTS["pilot"]["tiers"][i]
		var pbtn := Button.new()
		pbtn.text = "%s  Lv.%d  ×%d" % [pd["name"], pt, pilot_qtys[i]]
		pbtn.toggle_mode = true
		pbtn.button_group = pilot_grp
		pbtn.button_pressed = (_sel_pilot_tier == pt)
		pbtn.pressed.connect(func():
			_sel_pilot_tier = pt
			_sel_planet = ""
			sortie_btn.disabled = true
			_rebuild_auto_section()
		)
		_auto_section.add_child(pbtn)

	if not has_pilot:
		var no_pilot := Label.new()
		no_pilot.text = "파일럿 없음  (PC 터미널에서 고용)"
		no_pilot.modulate = Color(1, 0.5, 0.5, 1)
		no_pilot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_auto_section.add_child(no_pilot)
		return

	if _sel_pilot_tier == 0:
		_auto_section.add_child(sortie_btn)
		return

	# 파견 지역 선택
	_auto_section.add_child(HSeparator.new())
	var planet_title := Label.new()
	planet_title.text = "파견 지역"
	_auto_section.add_child(planet_title)

	var accessible: Array = GameState.get_pilot_accessible_planets(_sel_pilot_tier)
	if accessible.is_empty():
		var no_planet := Label.new()
		no_planet.text = "접근 가능한 지역 없음  (지역 해금 필요)"
		no_planet.modulate = Color(1, 1, 1, 0.5)
		no_planet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_auto_section.add_child(no_planet)
		_auto_section.add_child(sortie_btn)
		return

	var planet_grp := ButtonGroup.new()
	for planet in accessible:
		var pid: String = planet["id"]
		var plbtn := Button.new()
		plbtn.text = planet["name"]
		plbtn.toggle_mode = true
		plbtn.button_group = planet_grp
		plbtn.button_pressed = (_sel_planet == pid)
		plbtn.pressed.connect(func():
			_sel_planet = pid
			sortie_btn.disabled = false
		)
		_auto_section.add_child(plbtn)

	_auto_section.add_child(sortie_btn)

	var cap_slot := _sel_slot
	var cap_pilot := _sel_pilot_tier
	sortie_btn.pressed.connect(func():
		if GameState.start_auto_dispatch(cap_slot, cap_pilot, _sel_planet):
			_show_toast("슬롯 %d  파견 시작!" % (cap_slot + 1))
			_sel_slot = -1
			_sel_pilot_tier = 0
			_sel_planet = ""
			_rebuild_auto_section()
	)

# ── 토스트 알림 ───────────────────────────

func _show_toast(msg: String) -> void:
	toast_label.text = msg
	toast_label.modulate.a = 1.0
	toast_label.visible = true
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(toast_label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func(): toast_label.visible = false)
