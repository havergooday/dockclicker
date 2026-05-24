extends Control

@onready var back_button: Button = $Header/BackButton
@onready var content_vbox: VBoxContainer = $ScrollContainer/ContentVBox

var _inventory_content: VBoxContainer

func _ready() -> void:
	PanelManager.register_panel("workshop", self)
	back_button.pressed.connect(func(): PanelManager.show_bridge())
	GameState.part_purchased.connect(func(_pt, _t): _refresh())
	GameState.auto_slot_changed.connect(func(_i): _refresh())
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var title := Label.new()
	title.text = "── 보유 파츠 ──"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_vbox.add_child(title)

	content_vbox.add_child(HSeparator.new())

	_inventory_content = VBoxContainer.new()
	_inventory_content.add_theme_constant_override("separation", 3)
	content_vbox.add_child(_inventory_content)

	content_vbox.add_child(HSeparator.new())

	var note := Label.new()
	note.text = "머신 조립은 격납고에서"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.modulate = Color(1, 1, 1, 0.4)
	content_vbox.add_child(note)

func _refresh() -> void:
	for child in _inventory_content.get_children():
		child.queue_free()

	var has_any := false

	for part_type in ["pilot", "body", "weapon", "legs"]:
		var data: Dictionary = GameState.PARTS[part_type]
		var qtys: Array = GameState.owned_parts[part_type]

		for i in qtys.size():
			var idle_qty: int = qtys[i]
			var in_field_qty := 0

			# 파견 중인 파일럿 수 별도 계산
			if part_type == "pilot":
				for _slot in GameState.auto_slots:
					var s: DispatchManager.AutoSlot = _slot
					if (s.state == "on_mission" or s.state == "returning") and s.pilot_tier == i + 1:
						in_field_qty += 1

			# 대기 중 아이템 — 개별 슬롯
			for _j in idle_qty:
				has_any = true
				_inventory_content.add_child(_make_item_row(data, i, false))

			# 파견 중 파일럿 — 개별 슬롯 (반투명)
			for _j in in_field_qty:
				has_any = true
				_inventory_content.add_child(_make_item_row(data, i, true))

	if not has_any:
		var none_lbl := Label.new()
		none_lbl.text = "보유한 파츠 없음"
		none_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none_lbl.modulate = Color(1, 1, 1, 0.5)
		_inventory_content.add_child(none_lbl)

func _make_item_row(data: Dictionary, tier_index: int, in_field: bool) -> HBoxContainer:
	var td: Dictionary = data["tiers"][tier_index]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var tag := Label.new()
	tag.text = data["name"]
	tag.custom_minimum_size = Vector2(44, 0)
	tag.modulate = Color(1, 1, 1, 0.6)
	row.add_child(tag)

	var name_lbl := Label.new()
	name_lbl.text = "Lv.%d  %s" % [tier_index + 1, td["name"]]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var effect_lbl := Label.new()
	effect_lbl.text = data["effect"] % td["value"]
	effect_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(effect_lbl)

	if in_field:
		var field_lbl := Label.new()
		field_lbl.text = "파견중"
		field_lbl.modulate = Color(1.0, 0.4, 0.4, 1.0)
		field_lbl.custom_minimum_size = Vector2(48, 0)
		field_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(field_lbl)
		row.modulate = Color(1, 1, 1, 0.5)

	return row
