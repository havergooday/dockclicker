extends Control

var _credit_label: Label
var _dispatch_label: Label
var _dispatch_icon: Label
var _return_label: Label
var _return_icon: Label
var _waiting_label: Label
var _waiting_icon: Label
var _resource_labels: Dictionary = {}
var _displayed_credits: int = 0
var _pill: PanelContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_hud()
	GameState.hud_position_changed.connect(func(_p): _rebuild_hud())
	GameState.credits_changed.connect(_on_credits_changed)
	GameState.credits_collected.connect(_on_credits_collected)
	GameState.resources_changed.connect(func(_resources: Dictionary): _refresh_resources())
	GameState.resource_changed.connect(func(_id: String, _amount: int): _refresh_resources())
	GameState.auto_slot_changed.connect(func(_i): _refresh_dispatch())
	GameState.auto_dispatch_returned.connect(func(_i): _refresh_dispatch())
	GameState.resources_collected.connect(_on_resources_collected)
	_displayed_credits = GameState.total_credits
	_credit_label.text = _fmt_credits(_displayed_credits)
	_refresh_resources()
	_refresh_dispatch()

func _build_hud() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vertical := GameState.hud_position in ["left", "right"]

	# 고정 필 컨테이너 (내용 크기에 맞춰 자동 크기)
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_pill_anchors(pill)
	_pill = pill

	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.04, 0.07, 0.12, 0.94)
	ps.border_color = Color(0.22, 0.36, 0.58, 0.65)
	ps.set_border_width_all(1)
	ps.set_corner_radius_all(5)
	ps.content_margin_left   = 18 if not vertical else 12
	ps.content_margin_right  = 18 if not vertical else 12
	ps.content_margin_top    = 4 if not vertical else 10
	ps.content_margin_bottom = 4 if not vertical else 10
	pill.add_theme_stylebox_override("panel", ps)
	add_child(pill)

	var box: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
	box.add_theme_constant_override("separation", 10 if not vertical else 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(box)

	# ── CR ─────────────────────────────────────────────────────
	_make_icon(box, "◆", Color(1.00, 0.82, 0.28))
	_credit_label = _make_val(box)

	_sep(box, vertical)

	# ── 재료 ────────────────────────────────────────────────────
	for id in ["alloy", "supplies", "circuit"]:
		var icon := _make_icon(box, "■", _resource_color(id))
		icon.text = _resource_abbr(id)
		_resource_labels[id] = _make_val(box)

	_sep(box, vertical)

	# ── 파견 ────────────────────────────────────────────────────
	_dispatch_icon = _make_icon(box, "▶", Color(0.40, 0.72, 1.00))
	_dispatch_label = _make_val(box)

	_sep(box, vertical)

	# ── 귀환 ────────────────────────────────────────────────────
	_return_icon = _make_icon(box, "↩", Color(1.00, 0.65, 0.20))
	_return_label = _make_val(box)

	_sep(box, vertical)

	# ── 대기 (격납고 수령 대기) ──────────────────────────────────
	_waiting_icon = _make_icon(box, "◉", Color(0.28, 1.00, 0.48))
	_waiting_label = _make_val(box)


func _apply_pill_anchors(pill: PanelContainer) -> void:
	# 선택된 위치에 맞춰 필을 화면 가장자리에 고정
	match GameState.hud_position:
		"top":
			pill.anchor_left = 0.5; pill.anchor_right = 0.5
			pill.anchor_top  = 0.0; pill.anchor_bottom = 0.0
			pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
			pill.grow_vertical   = Control.GROW_DIRECTION_END
			pill.offset_top = 4.0; pill.offset_bottom = 29.0
		"left":
			pill.anchor_left = 0.0; pill.anchor_right = 0.0
			pill.anchor_top  = 0.5; pill.anchor_bottom = 0.5
			pill.grow_horizontal = Control.GROW_DIRECTION_END
			pill.grow_vertical   = Control.GROW_DIRECTION_BOTH
			pill.offset_left = 6.0
		"right":
			pill.anchor_left = 1.0; pill.anchor_right = 1.0
			pill.anchor_top  = 0.5; pill.anchor_bottom = 0.5
			pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			pill.grow_vertical   = Control.GROW_DIRECTION_BOTH
			pill.offset_right = -6.0
		_:  # "bottom"
			pill.anchor_left = 0.5; pill.anchor_right = 0.5
			pill.anchor_top  = 1.0; pill.anchor_bottom = 1.0
			pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
			pill.grow_vertical   = Control.GROW_DIRECTION_BEGIN
			pill.offset_top = -28.0; pill.offset_bottom = -3.0


func _rebuild_hud() -> void:
	if is_instance_valid(_pill):
		_pill.queue_free()
	_resource_labels.clear()
	_build_hud()
	_credit_label.text = _fmt_credits(_displayed_credits)
	_refresh_resources()
	_refresh_dispatch()


func _make_icon(parent: BoxContainer, glyph: String, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = glyph
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.modulate = color
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)
	return lbl

func _make_val(parent: BoxContainer) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.modulate = Color(0.90, 0.95, 1.00)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)
	return lbl

func _sep(parent: BoxContainer, vertical: bool) -> void:
	var sep: Separator = HSeparator.new() if vertical else VSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.16)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(sep)

func _fmt_credits(v: int) -> String:
	if v >= 1_000_000:
		return "%d,%03d,%03d CR" % [v / 1_000_000, (v / 1000) % 1000, v % 1000]
	if v >= 1000:
		return "%d,%03d CR" % [v / 1000, v % 1000]
	return "%d CR" % v

func _refresh_resources() -> void:
	for id in ["alloy", "supplies", "circuit"]:
		if not _resource_labels.has(id):
			continue
		var lbl: Label = _resource_labels[id]
		lbl.text = "%d" % GameState.get_resource(id)

func _resource_abbr(id: String) -> String:
	match id:
		"alloy": return "AL"
		"supplies": return "SUP"
		"circuit": return "CHIP"
		_: return id.to_upper()

func _resource_color(id: String) -> Color:
	match id:
		"alloy": return Color(0.70, 0.78, 0.86)
		"supplies": return Color(0.48, 0.86, 0.56)
		"circuit": return Color(0.54, 0.76, 1.00)
		_: return Color(0.90, 0.95, 1.00)

func _on_credits_changed(new_total: int) -> void:
	var tween := create_tween()
	tween.tween_method(
		func(v: float): _credit_label.text = _fmt_credits(int(v)),
		float(_displayed_credits), float(new_total), 0.5
	)
	_displayed_credits = new_total

func _on_credits_collected(amount: int, from_global_pos: Vector2) -> void:
	var fly := Label.new()
	fly.text = "+%d" % amount
	fly.add_theme_color_override("font_color", Color(1.0, 0.90, 0.2))
	fly.add_theme_font_size_override("font_size", 14)
	fly.z_index = 100
	get_parent().add_child(fly)
	fly.global_position = from_global_pos
	var target := _pill.get_global_rect().get_center() if is_instance_valid(_pill) else get_global_rect().get_center()
	var tween := fly.create_tween()
	tween.tween_property(fly, "global_position", target, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(fly.queue_free)

func _on_resources_collected(rewards: Dictionary) -> void:
	var parts: Array = []
	if int(rewards.get("cp", 0)) > 0:
		parts.append("+%d CR" % int(rewards["cp"]))
	for id in ["alloy", "supplies", "circuit"]:
		if int(rewards.get(id, 0)) > 0:
			parts.append("+%d %s" % [int(rewards[id]), _resource_abbr(id)])
	if parts.is_empty():
		return
	var fly := Label.new()
	fly.text = "  ".join(parts)
	fly.add_theme_color_override("font_color", Color(0.68, 0.92, 1.0))
	fly.add_theme_font_size_override("font_size", 12)
	fly.z_index = 100
	fly.anchor_left   = 0.5
	fly.anchor_top    = 1.0
	fly.anchor_right  = 0.5
	fly.anchor_bottom = 1.0
	fly.offset_left   = -200.0
	fly.offset_right  =  200.0
	fly.offset_top    = -58.0
	fly.offset_bottom = -36.0
	fly.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	get_parent().add_child(fly)
	var tween := fly.create_tween()
	tween.tween_property(fly, "offset_top", -74.0, 1.0).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(fly, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tween.tween_callback(fly.queue_free)


func _refresh_dispatch() -> void:
	var active := 0
	var returning := 0
	var waiting := 0
	var total_unlocked := 0
	for slot: DispatchManager.AutoSlot in GameState.auto_slots:
		if slot.state != "locked":
			total_unlocked += 1
		match slot.state:
			"on_mission": active   += 1
			"returning":  returning += 1
			"returned":   waiting   += 1

	_dispatch_label.text = "파견  %d / %d" % [active, total_unlocked]
	var dispatch_active := active > 0
	_dispatch_icon.modulate  = Color(0.40, 0.72, 1.00) if dispatch_active else Color(1, 1, 1, 0.22)
	_dispatch_label.modulate = Color(0.90, 0.95, 1.00) if dispatch_active else Color(1, 1, 1, 0.35)

	_return_label.text = "귀환  %d" % returning
	var return_active := returning > 0
	_return_icon.modulate  = Color(1.00, 0.65, 0.20) if return_active else Color(1, 1, 1, 0.22)
	_return_label.modulate = Color(0.90, 0.95, 1.00) if return_active else Color(1, 1, 1, 0.35)

	_waiting_label.text = "대기  %d" % waiting
	var waiting_active := waiting > 0
	_waiting_icon.modulate  = Color(0.28, 1.00, 0.48) if waiting_active else Color(1, 1, 1, 0.22)
	_waiting_label.modulate = Color(0.28, 1.00, 0.48) if waiting_active else Color(1, 1, 1, 0.35)
