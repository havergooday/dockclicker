extends Control

var _missions_vbox: VBoxContainer
var _countdown_data: Array = []

func _ready() -> void:
	PanelManager.register_panel("bridge", self)
	GameState.auto_slot_changed.connect(func(_i): _refresh_missions())
	GameState.auto_dispatch_returned.connect(func(_i): _refresh_missions())
	_build_mission_panel()
	_refresh_missions()

func _process(_delta: float) -> void:
	if not visible:
		return
	var now := Time.get_unix_time_from_system()
	for entry in _countdown_data:
		var lbl: Label = entry["label"]
		if not is_instance_valid(lbl):
			continue
		var remaining: float = maxf(0.0, float(entry["end_time"]) - now)
		var mins := int(remaining) / 60
		var secs := int(remaining) % 60
		lbl.text = "%02d:%02d" % [mins, secs]

func _build_mission_panel() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -120
	add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "── 파견 현황 ──"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_missions_vbox = VBoxContainer.new()
	_missions_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(_missions_vbox)

func _refresh_missions() -> void:
	_countdown_data.clear()
	for child in _missions_vbox.get_children():
		child.queue_free()

	var has_active := false
	for i in GameState.auto_slots.size():
		var slot: Dictionary = GameState.auto_slots[i]
		var state: String = slot.get("state", "")
		if state != "on_mission" and state != "returning":
			continue
		has_active = true

		var row := HBoxContainer.new()
		_missions_vbox.add_child(row)

		var info_lbl := Label.new()
		info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var end_time: float = 0.0

		if state == "on_mission":
			var planet_id: String = slot.get("planet", "")
			var planet_name: String = planet_id
			if planet_id != "":
				var pd := GameState.get_planet(planet_id)
				planet_name = str(pd.get("name", planet_id))
			info_lbl.text = "슬롯 %d  →  %s" % [i + 1, planet_name]
			end_time = float(slot.get("mission_end_time", 0.0))
		else:
			info_lbl.text = "슬롯 %d  ←  귀환중" % (i + 1)
			info_lbl.modulate = Color(1.0, 0.8, 0.4, 1.0)
			end_time = float(slot.get("return_end_time", 0.0))

		row.add_child(info_lbl)

		var countdown_lbl := Label.new()
		countdown_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		countdown_lbl.custom_minimum_size = Vector2(52, 0)
		row.add_child(countdown_lbl)

		_countdown_data.append({"label": countdown_lbl, "end_time": end_time})

	if not has_active:
		var lbl := Label.new()
		lbl.text = "파견 중인 머신 없음"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.modulate = Color(1, 1, 1, 0.35)
		_missions_vbox.add_child(lbl)
