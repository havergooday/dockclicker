class_name HangarBayDetail


# slot 상태별 팝업 content를 vb에 빌드한다.
# on_hide      : 팝업 닫기 콜백
# on_navigate  : 관제실로 이동 요청 콜백
static func build_content(
		vb: VBoxContainer,
		slot_idx: int,
		on_hide: Callable,
		on_navigate: Callable) -> void:
	var slot: DispatchManager.AutoSlot = GameState.auto_slots[slot_idx]
	var accent := HangarHelpers.border_color(slot.state)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 6)
	vb.add_child(hdr)

	var slot_cname: String = str(GameState.auto_slots[slot_idx].custom_name) if slot_idx < GameState.auto_slots.size() else ""
	var title := Label.new()
	title.text = slot_cname if slot_cname != "" else "BAY %02d" % (slot_idx + 1)
	title.add_theme_font_size_override("font_size", 13)
	title.modulate = Color(0.75, 0.80, 0.95)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(title)

	var state_lbl := Label.new()
	state_lbl.text = HangarHelpers.state_label(slot.state)
	state_lbl.add_theme_font_size_override("font_size", 9)
	state_lbl.modulate = accent
	state_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hdr.add_child(state_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.custom_minimum_size = Vector2(22, 22)
	close_btn.pressed.connect(on_hide)
	hdr.add_child(close_btn)

	var div := ColorRect.new()
	div.color = Color(accent.r, accent.g, accent.b, 0.30)
	div.custom_minimum_size = Vector2(0, 1)
	div.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(div)

	match slot.state:
		"empty":                   _empty(vb, slot_idx, on_hide)
		"offline":                 _offline(vb, slot, slot_idx, on_hide, on_navigate)
		"on_mission", "returning": _active(vb, slot)
		"returned":                _returned(vb, slot, slot_idx, on_hide)


static func _empty(vb: VBoxContainer, slot_idx: int, on_hide: Callable) -> void:
	HangarHelpers.add_lbl(vb, "머신 없음", 12, HORIZONTAL_ALIGNMENT_LEFT, Color(0.45, 0.45, 0.60))
	HangarHelpers.add_lbl(vb, "이 베이에 배치된 머신이 없습니다.", 10, HORIZONTAL_ALIGNMENT_LEFT, Color(0.42, 0.44, 0.55))
	vb.add_child(HangarHelpers.vspacer())
	var btn := Button.new()
	btn.text = "⚙ 격납고 조립하기"
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(func():
		GameState.hangar_preselect_slot = slot_idx
		on_hide.call()
		PanelManager.show_panel("hangar_assembly")
	)
	vb.add_child(btn)


static func _offline(vb: VBoxContainer, slot: DispatchManager.AutoSlot,
		slot_idx: int, on_hide: Callable, on_navigate: Callable) -> void:
	var b: int = slot.machine.get("body",   0)
	var w: int = slot.machine.get("weapon", 0)
	var l: int = slot.machine.get("legs",   0)
	HangarHelpers.add_lbl(vb, "몸체 T%d  ·  무기 T%d  ·  다리 T%d" % [b, w, l], 11,
			HORIZONTAL_ALIGNMENT_LEFT, Color(0.65, 0.70, 0.82))

	var pilot_hdr := Label.new()
	pilot_hdr.text = "배정 파일럿"
	pilot_hdr.add_theme_font_size_override("font_size", 9)
	pilot_hdr.modulate = Color(0.40, 0.42, 0.55)
	vb.add_child(pilot_hdr)

	var assigned_id := slot.assigned_pilot_id
	if assigned_id != "":
		var pilot := GameState.get_hired_pilot(assigned_id)
		var pname: String = str(pilot.get("name", assigned_id)) if not pilot.is_empty() else assigned_id
		HangarHelpers.add_lbl(vb, "👤 " + pname, 11, HORIZONTAL_ALIGNMENT_LEFT, Color(0.65, 0.88, 1.0))
	else:
		HangarHelpers.add_lbl(vb, "대기", 11, HORIZONTAL_ALIGNMENT_LEFT, Color(0.72, 0.40, 0.40))

	var idle := GameState.get_idle_pilots()
	if not idle.is_empty():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		vb.add_child(row)
		for p in idle:
			var pid: String = str(p.get("id", ""))
			var pbtn := Button.new()
			pbtn.text = str(p.get("name", pid))
			pbtn.toggle_mode = true
			pbtn.button_pressed = (assigned_id == pid)
			pbtn.custom_minimum_size = Vector2(0, 22)
			pbtn.add_theme_font_size_override("font_size", 10)
			var cap_idx := slot_idx
			var cap_pid := pid
			var cap_aid := assigned_id
			pbtn.pressed.connect(func():
				var new_id := "" if cap_aid == cap_pid else cap_pid
				GameState.assign_pilot_to_slot(cap_idx, new_id)
				on_hide.call()
			)
			row.add_child(pbtn)
	elif assigned_id == "":
		HangarHelpers.add_lbl(vb, "대기 파일럿 없음", 10, HORIZONTAL_ALIGNMENT_LEFT, Color(0.55, 0.35, 0.35))

	vb.add_child(HangarHelpers.vspacer())

	var rebuild_btn := Button.new()
	rebuild_btn.text = "⚙ 조립 편집"
	rebuild_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rebuild_btn.pressed.connect(func():
		GameState.hangar_preselect_slot = slot_idx
		on_hide.call()
		PanelManager.show_panel("hangar_assembly")
	)
	vb.add_child(rebuild_btn)

	var disassemble_btn := Button.new()
	disassemble_btn.text = "🧩 머신 분해"
	disassemble_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	disassemble_btn.modulate = Color(0.95, 0.60, 0.48)
	disassemble_btn.pressed.connect(func():
		if GameState.disassemble_machine(slot_idx):
			on_hide.call()
	)
	vb.add_child(disassemble_btn)

	var control_btn := Button.new()
	control_btn.text = "관제실로 이동  ▶"
	control_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control_btn.pressed.connect(func():
		on_hide.call()
		on_navigate.call()
	)
	vb.add_child(control_btn)


static func _active(vb: VBoxContainer, slot: DispatchManager.AutoSlot) -> void:
	var b: int = slot.machine.get("body",   0)
	var w: int = slot.machine.get("weapon", 0)
	var l: int = slot.machine.get("legs",   0)
	HangarHelpers.add_lbl(vb, "몸체 T%d  ·  무기 T%d  ·  다리 T%d" % [b, w, l], 11,
			HORIZONTAL_ALIGNMENT_LEFT, Color(0.65, 0.70, 0.82))

	if slot.planet != "":
		var planet := GameState.get_planet(slot.planet)
		HangarHelpers.add_lbl(vb, "도착 행성  " + str(planet.get("name", slot.planet)), 11,
				HORIZONTAL_ALIGNMENT_LEFT, Color(0.75, 0.65, 1.0))

	var remain_lbl := "남은 시간"
	var remain_text := "00:00"
	if slot.state == "on_mission":
		remain_text = HangarHelpers.fmt_time(slot.mission_end_time)
	elif slot.state == "returning":
		remain_lbl = "귀환 ETA"
		remain_text = HangarHelpers.fmt_time(slot.return_end_time)
	HangarHelpers.add_lbl(vb, "%s  %s" % [remain_lbl, remain_text], 11,
			HORIZONTAL_ALIGNMENT_LEFT, Color(0.50, 0.90, 0.55))

	vb.add_child(HangarHelpers.vspacer())
	HangarHelpers.add_lbl(vb, "파견 중인 베이는 읽기 전용입니다.", 9, HORIZONTAL_ALIGNMENT_LEFT, Color(0.42, 0.44, 0.55))


static func _fmt_rewards(slot: DispatchManager.AutoSlot) -> String:
	var rewards: Dictionary = slot.rewards
	if rewards.is_empty():
		return "+ %s CR" % HangarHelpers.fmt(slot.credits_earned)
	var parts: Array = []
	if int(rewards.get("cp", 0)) > 0:
		parts.append("+%s CR" % HangarHelpers.fmt(int(rewards["cp"])))
	var abbr := {"alloy": "합금", "supplies": "물자", "circuit": "칩"}
	for id in ["alloy", "supplies", "circuit"]:
		if int(rewards.get(id, 0)) > 0:
			parts.append("+%d %s" % [int(rewards[id]), abbr[id]])
	return "  ".join(parts) if not parts.is_empty() else "+ %s CR" % HangarHelpers.fmt(slot.credits_earned)


static func _add_breakdown_lines(vb: VBoxContainer, slot: DispatchManager.AutoSlot) -> void:
	var brk: Dictionary = slot.reward_breakdown
	if brk.is_empty():
		return
	HangarHelpers.add_lbl(vb, "기본 %s CR" % HangarHelpers.fmt(int(brk.get("raw_credits", 0))),
		10, HORIZONTAL_ALIGNMENT_CENTER, Color(0.60, 0.66, 0.80))
	var line: Array = []
	var cmult := float(brk.get("credits_mult", 1.0))
	if cmult > 1.0:
		line.append("파츠+%d%%" % int(round((cmult - 1.0) * 100.0)))
	var pbonus := int(brk.get("pilot_credits_pct", 0))
	if pbonus > 0:
		line.append("파일럿+%d%%" % pbonus)
	var fpen := int(brk.get("fatigue_penalty_pct", 0))
	if fpen > 0:
		line.append("피로-%d%%" % fpen)
	var ymult := float(brk.get("yield_mult", 1.0))
	if ymult > 1.0:
		line.append("재료+%d%%" % int(round((ymult - 1.0) * 100.0)))
	if not line.is_empty():
		HangarHelpers.add_lbl(vb, "  ".join(line), 10, HORIZONTAL_ALIGNMENT_CENTER, Color(0.72, 0.86, 1.0))


static func _returned(vb: VBoxContainer, slot: DispatchManager.AutoSlot,
		slot_idx: int, on_hide: Callable) -> void:
	HangarHelpers.add_lbl(vb, "수령 대기", 11, HORIZONTAL_ALIGNMENT_LEFT, Color(0.52, 0.60, 0.75))
	var cr_lbl := Label.new()
	cr_lbl.text = _fmt_rewards(slot)
	cr_lbl.add_theme_font_size_override("font_size", 18)
	cr_lbl.modulate = Color(0.28, 1.00, 0.48)
	cr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cr_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cr_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(cr_lbl)

	_add_breakdown_lines(vb, slot)

	vb.add_child(HangarHelpers.vspacer())

	var btn := Button.new()
	btn.text = "수령  ▶"
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(func():
		GameState.collect_auto_slot(slot_idx)
		on_hide.call()
	)
	vb.add_child(btn)
