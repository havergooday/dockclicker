extends Control

@onready var back_button: Button = $Header/BackButton
@onready var main_scroll: ScrollContainer = $MainScroll
@onready var main_vbox: VBoxContainer = $MainScroll/MainVBox
@onready var sub_scroll: ScrollContainer = $SubScroll
@onready var sub_vbox: VBoxContainer = $SubScroll/SubVBox

var _status_label: Label
var _reward_label: Label
var _collect_button: Button
var _auto_slots_container: GridContainer

# 조립 선택 상태
var _asm_sel := {"body": 0, "weapon": 0, "legs": 0}
var _asm_cost_lbl: Label = null
var _asm_btn: Button = null

func _ready() -> void:
	PanelManager.register_panel("hangar", self)
	back_button.pressed.connect(func(): PanelManager.show_bridge())
	GameState.player_status_changed.connect(func(_s): _refresh_player_slot())
	GameState.credits_changed.connect(func(_v): _rebuild_auto_slots())
	GameState.auto_slot_changed.connect(func(_i): _rebuild_auto_slots())
	visibility_changed.connect(func():
		if visible:
			_show_main()
	)
	_build_main_view()
	_show_main()

# ── view switching ────────────────────────

func _show_main() -> void:
	main_scroll.visible = true
	sub_scroll.visible = false
	_rebuild_auto_slots()

func _show_assembly(slot_index: int) -> void:
	_asm_sel = {"body": 0, "weapon": 0, "legs": 0}
	main_scroll.visible = false
	sub_scroll.visible = true
	for child in sub_vbox.get_children():
		child.queue_free()
	_build_assembly_view(slot_index)

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
	for i in GameState.auto_slots.size():
		_auto_slots_container.add_child(_make_slot_btn(i))

func _make_slot_btn(index: int) -> Button:
	var slot: Dictionary = GameState.auto_slots[index]
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(90, 90)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL

	match slot["state"]:
		"locked":
			var cost: int = slot.get("unlock_cost", 0)
			btn.text = "슬롯 %d\n🔒 잠금\n%d CR" % [index + 1, cost]
			btn.disabled = GameState.total_credits < cost
			btn.pressed.connect(func(): GameState.unlock_auto_slot(index))

		"empty":
			btn.text = "슬롯 %d\n비어있음\n+ 조립" % (index + 1)
			btn.pressed.connect(func(): _show_assembly(index))

		"offline":
			var machine: Dictionary = slot.get("machine", {})
			var b: int = machine.get("body", 0)
			var w: int = machine.get("weapon", 0)
			var l: int = machine.get("legs", 0)
			btn.text = "슬롯 %d\nOFFLINE\n몸%d 무%d 다%d" % [index + 1, b, w, l]
			btn.pressed.connect(func():
				GameState.dispatch_preselect_slot = index
				PanelManager.show_panel("dispatch")
			)

		"on_mission":
			var planet_id: String = slot.get("planet", "")
			var planet_name: String = planet_id
			if planet_id != "":
				var pd := GameState.get_planet(planet_id)
				planet_name = str(pd.get("name", planet_id))
			btn.text = "슬롯 %d\n파견중\n→ %s" % [index + 1, planet_name]
			btn.modulate = Color(1.0, 0.55, 0.55, 1.0)
			btn.disabled = true

		"returning":
			var planet_id: String = slot.get("planet", "")
			var planet_name: String = planet_id
			if planet_id != "":
				var pd := GameState.get_planet(planet_id)
				planet_name = str(pd.get("name", planet_id))
			btn.text = "슬롯 %d\n귀환중\n← %s" % [index + 1, planet_name]
			btn.modulate = Color(1.0, 0.85, 0.4, 1.0)
			btn.disabled = true

		"returned":
			var credits: int = slot.get("credits_earned", 0)
			btn.text = "슬롯 %d\n복귀완료!\n%d CR 수령" % [index + 1, credits]
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

# ── assembly sub-view ─────────────────────

func _build_assembly_view(slot_index: int) -> void:
	# 헤더
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	sub_vbox.add_child(hbox)

	var back_btn := Button.new()
	back_btn.text = "← 목록"
	back_btn.custom_minimum_size = Vector2(80, 32)
	back_btn.pressed.connect(_show_main)
	hbox.add_child(back_btn)

	var title_lbl := Label.new()
	title_lbl.text = "머신 조립  —  슬롯 %d" % (slot_index + 1)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(title_lbl)

	sub_vbox.add_child(HSeparator.new())

	# 비용·조립 버튼을 먼저 생성해서 파츠 버튼 클로저에서 참조
	_asm_cost_lbl = Label.new()
	_asm_cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_asm_btn = Button.new()
	_asm_btn.text = "조립하기"
	_asm_btn.custom_minimum_size = Vector2(0, 40)
	_asm_btn.disabled = true
	_asm_btn.pressed.connect(func():
		if GameState.assemble_machine(slot_index, _asm_sel["body"], _asm_sel["weapon"], _asm_sel["legs"]):
			_show_main()
	)

	# 파츠 선택 섹션
	for part_type in ["body", "weapon", "legs"]:
		_build_asm_part_rows(part_type)

	sub_vbox.add_child(HSeparator.new())
	sub_vbox.add_child(_asm_cost_lbl)
	sub_vbox.add_child(_asm_btn)
	_update_asm_cost()

func _build_asm_part_rows(part_type: String) -> void:
	var data: Dictionary = GameState.PARTS[part_type]
	var qtys: Array = GameState.owned_parts[part_type]

	var sec_lbl := Label.new()
	sec_lbl.text = "── %s ──" % data["name"]
	sec_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_vbox.add_child(sec_lbl)

	var grp := ButtonGroup.new()
	var has_any := false

	for i in qtys.size():
		if qtys[i] <= 0:
			continue
		has_any = true
		var tier := i + 1
		var td: Dictionary = data["tiers"][i]

		var btn := Button.new()
		btn.text = "Lv.%d  %s  (%s)  ×%d" % [
			tier, td["name"], data["effect"] % td["value"], qtys[i]
		]
		btn.toggle_mode = true
		btn.button_group = grp
		sub_vbox.add_child(btn)

		var pt := part_type
		var t := tier
		btn.pressed.connect(func():
			_asm_sel[pt] = t
			_update_asm_cost()
		)

	if not has_any:
		var none_lbl := Label.new()
		none_lbl.text = "보유한 파츠 없음  (PC 터미널에서 구매)"
		none_lbl.modulate = Color(1, 0.45, 0.45, 1)
		none_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub_vbox.add_child(none_lbl)

func _update_asm_cost() -> void:
	var b: int = _asm_sel.get("body", 0)
	var w: int = _asm_sel.get("weapon", 0)
	var l: int = _asm_sel.get("legs", 0)
	if b > 0 and w > 0 and l > 0:
		var cost := GameState.get_assembly_cost(b, w, l)
		_asm_cost_lbl.text = "조립 비용: %d CR" % cost
		_asm_btn.disabled = GameState.total_credits < cost
	else:
		_asm_cost_lbl.text = "파츠를 모두 선택하세요"
		_asm_btn.disabled = true
