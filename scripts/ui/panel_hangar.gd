extends Control

@onready var back_button: Button = $Header/BackButton
@onready var main_scroll: ScrollContainer = $MainScroll
@onready var main_vbox: VBoxContainer = $MainScroll/MainVBox

var _status_label: Label
var _reward_label: Label
var _collect_button: Button
var _auto_slots_container: GridContainer

func _ready() -> void:
	PanelManager.register_panel("hangar", self)
	back_button.pressed.connect(func(): PanelManager.show_bridge())
	GameState.player_status_changed.connect(func(_s): _refresh_player_slot())
	GameState.credits_changed.connect(func(_v): _rebuild_auto_slots())
	GameState.auto_slot_changed.connect(func(_i): _rebuild_auto_slots())
	visibility_changed.connect(func():
		if visible:
			_rebuild_auto_slots()
	)
	_build_main_view()

# ── main view ─────────────────────────────

func _build_main_view() -> void:
	_build_player_slot_section()
	main_vbox.add_child(HSeparator.new())
	_build_auto_slots_section()

func _build_player_slot_section() -> void:
	var title := Label.new()
	title.text = "── 플레이어 슬롯 ──"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)

	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.10, 0.18, 0.78)
	panel_style.set_corner_radius_all(4)
	panel_style.content_margin_left   = 8
	panel_style.content_margin_right  = 8
	panel_style.content_margin_top    = 6
	panel_style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", panel_style)
	main_vbox.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_status_label)

	_reward_label = Label.new()
	_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_label.visible = false
	vbox.add_child(_reward_label)

	_collect_button = Button.new()
	_collect_button.text = "수령"
	_collect_button.visible = false
	_collect_button.pressed.connect(func():
		GameState.collect_player_credits(_collect_button.get_global_rect().get_center())
	)
	vbox.add_child(_collect_button)

	_refresh_player_slot()

func _build_auto_slots_section() -> void:
	var title := Label.new()
	title.text = "── 자동 파견 슬롯 ──"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)

	_auto_slots_container = GridContainer.new()
	_auto_slots_container.columns = 3
	_auto_slots_container.add_theme_constant_override("h_separation", 6)
	_auto_slots_container.add_theme_constant_override("v_separation", 6)
	_auto_slots_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(_auto_slots_container)

	_rebuild_auto_slots()

func _rebuild_auto_slots() -> void:
	if _auto_slots_container == null:
		return
	for child in _auto_slots_container.get_children():
		child.queue_free()
	for i: int in GameState.auto_slots.size():
		_auto_slots_container.add_child(_make_slot_btn(i))

func _make_slot_btn(index: int) -> Button:
	var slot: DispatchManager.AutoSlot = GameState.auto_slots[index] as DispatchManager.AutoSlot
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(90, 90)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL

	match slot.state:
		"locked":
			btn.text = "슬롯 %d\n🔒 잠금\n%d CR" % [index + 1, slot.unlock_cost]
			btn.disabled = GameState.total_credits < slot.unlock_cost
			btn.pressed.connect(func(): GameState.unlock_auto_slot(index))

		"empty":
			btn.text = "슬롯 %d\n비어있음\n+ 조립" % (index + 1)
			btn.pressed.connect(func():
				GameState.workshop_preselect_slot = index
				PanelManager.show_panel("workshop")
			)

		"offline":
			var b: int = slot.machine.get("body", 0)
			var w: int = slot.machine.get("weapon", 0)
			var l: int = slot.machine.get("legs", 0)
			btn.text = "슬롯 %d\nOFFLINE\n몸%d 무%d 다%d" % [index + 1, b, w, l]
			btn.pressed.connect(func():
				GameState.dispatch_preselect_slot = index
				PanelManager.show_panel("dispatch")
			)

		"on_mission":
			var planet_name: String = slot.planet
			if slot.planet != "":
				planet_name = str(GameState.get_planet(slot.planet).get("name", slot.planet))
			btn.text = "슬롯 %d\n파견중\n→ %s" % [index + 1, planet_name]
			btn.modulate = Color(1.0, 0.55, 0.55, 1.0)
			btn.disabled = true

		"returning":
			var planet_name: String = slot.planet
			if slot.planet != "":
				planet_name = str(GameState.get_planet(slot.planet).get("name", slot.planet))
			btn.text = "슬롯 %d\n귀환중\n← %s" % [index + 1, planet_name]
			btn.modulate = Color(1.0, 0.85, 0.4, 1.0)
			btn.disabled = true

		"returned":
			btn.text = "슬롯 %d\n복귀완료!\n%d CR 수령" % [index + 1, slot.credits_earned]
			btn.modulate = Color(0.4, 1.0, 0.55, 1.0)
			btn.pressed.connect(func(): GameState.collect_auto_slot(index))

	return btn

# ── player slot refresh ───────────────────

func _refresh_player_slot() -> void:
	match GameState.player_status:
		"idle":
			_status_label.text = "대기중"
			_reward_label.visible = false
			_collect_button.visible = false
		"on_mission":
			_status_label.text = "임무중"
			_reward_label.visible = false
			_collect_button.visible = false
		"returned":
			_status_label.text = "귀환완료"
			_reward_label.text = "보류: %d CR" % GameState.pending_credits
			_reward_label.visible = true
			_collect_button.visible = true
