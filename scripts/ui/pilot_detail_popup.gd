extends Control

const POPUP_HEIGHT  := 340.0
const POPUP_W       := 480.0
const ANIM_DURATION := 0.20

var _popup_w_half: float = 0.0  # 런타임에 뷰포트 기준으로 계산

var _main_panel:  PanelContainer = null
var _content_vb:  VBoxContainer  = null

var _pilot_id: String = ""
var _bed_idx:  int    = -1
var _slot_idx: int    = -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	hide()


func _build_ui() -> void:
	# 딤 오버레이 (항성지도와 동일)
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.46)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			close_popup()
	)
	add_child(overlay)

	# 메인 패널 — 뷰포트 기준 중앙 정렬
	# anchor 0 기준 + 뷰포트 너비로 offset 직접 계산 → 스크롤 여부와 무관하게 화면 중앙
	var vp_w := get_viewport_rect().size.x
	_popup_w_half = POPUP_W * 0.5
	_main_panel = PanelContainer.new()
	_main_panel.anchor_left   = 0.0
	_main_panel.anchor_top    = 0.0
	_main_panel.anchor_right  = 0.0
	_main_panel.anchor_bottom = 0.0
	_main_panel.offset_left   = (vp_w - POPUP_W) * 0.5
	_main_panel.offset_right  = (vp_w + POPUP_W) * 0.5
	_main_panel.offset_top    = -POPUP_HEIGHT  # 숨김 상태
	_main_panel.offset_bottom = 0.0
	var sty := StyleBoxFlat.new()
	sty.bg_color     = Color(0.04, 0.06, 0.11, 0.98)
	sty.border_color = Color(0.28, 0.40, 0.62, 0.96)
	sty.set_border_width_all(1)
	sty.content_margin_left = 16; sty.content_margin_right  = 16
	sty.content_margin_top  = 10; sty.content_margin_bottom = 10
	_main_panel.add_theme_stylebox_override("panel", sty)
	add_child(_main_panel)

	_content_vb = VBoxContainer.new()
	_content_vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content_vb.add_theme_constant_override("separation", 8)
	_content_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_panel.add_child(_content_vb)


# ── 공개 API ──────────────────────────────────────────────────

func open(pilot_id: String, bed_idx: int, slot_idx: int) -> void:
	_pilot_id = pilot_id
	_bed_idx  = bed_idx
	_slot_idx = slot_idx
	_rebuild()
	show()
	_main_panel.offset_top    = -POPUP_HEIGHT
	_main_panel.offset_bottom = 0.0
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_main_panel, "offset_top",    0.0,          ANIM_DURATION)
	tween.parallel().tween_property(_main_panel, "offset_bottom", POPUP_HEIGHT, ANIM_DURATION)


func close_popup() -> void:
	if not visible: return
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_main_panel, "offset_top",    -POPUP_HEIGHT, ANIM_DURATION)
	tween.parallel().tween_property(_main_panel, "offset_bottom", 0.0, ANIM_DURATION)
	tween.tween_callback(func(): hide())


# ── 콘텐츠 ────────────────────────────────────────────────────

func _rebuild() -> void:
	for c in _content_vb.get_children(): c.queue_free()

	var pilot: Dictionary = GameState.get_hired_pilot(_pilot_id)
	if pilot.is_empty(): close_popup(); return

	# 헤더 행
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 12)
	hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_vb.add_child(hdr)

	var pcol := Color.html(str(pilot.get("portrait_color", "#4499DD")))
	var portrait := Panel.new()
	portrait.custom_minimum_size = Vector2(56, 56)
	var ps := StyleBoxFlat.new()
	ps.bg_color = pcol.darkened(0.55); ps.border_color = pcol.darkened(0.15)
	ps.set_border_width_all(2); ps.set_corner_radius_all(5)
	portrait.add_theme_stylebox_override("panel", ps)
	var init_lbl := Label.new()
	init_lbl.text = str(pilot.get("name", "?")).substr(0, 1)
	init_lbl.add_theme_font_size_override("font_size", 24)
	init_lbl.modulate = pcol.lightened(0.30)
	init_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	init_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	init_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	init_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.add_child(init_lbl)
	hdr.add_child(portrait)

	var hdr_vb := VBoxContainer.new()
	hdr_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_vb.add_theme_constant_override("separation", 3)
	hdr_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr.add_child(hdr_vb)

	var name_lbl := Label.new()
	name_lbl.text = str(pilot.get("name", ""))
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.modulate = Color(0.90, 0.94, 1.0)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr_vb.add_child(name_lbl)

	var tier_lbl := Label.new()
	tier_lbl.text = "T%d 파일럿" % int(pilot.get("tier", 1))
	tier_lbl.add_theme_font_size_override("font_size", 11)
	tier_lbl.modulate = Color(0.55, 0.68, 0.88)
	tier_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr_vb.add_child(tier_lbl)

	var close_btn := Button.new()
	close_btn.text = "× 닫기"
	close_btn.flat = true
	close_btn.add_theme_color_override("font_color", Color(0.70, 0.80, 1.0))
	close_btn.pressed.connect(close_popup)
	hdr.add_child(close_btn)

	_content_vb.add_child(_hsep())

	# 정보 그리드
	var info_hb := HBoxContainer.new()
	info_hb.add_theme_constant_override("separation", 24)
	info_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_vb.add_child(info_hb)

	var left_vb := VBoxContainer.new()
	left_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vb.add_theme_constant_override("separation", 6)
	left_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_hb.add_child(left_vb)

	var status: String = str(pilot.get("status", "idle"))
	left_vb.add_child(_info_row("상태",
		"파견 중" if status == "on_mission" else "대기 중",
		Color(0.55, 0.78, 1.0) if status == "on_mission" else Color(0.38, 1.0, 0.55)))

	var bay_idx := _find_assigned_bay()
	left_vb.add_child(_info_row("배정 베이",
		"BAY %02d" % (bay_idx + 1) if bay_idx >= 0 else "없음",
		Color(0.75, 0.82, 1.0) if bay_idx >= 0 else Color(0.40, 0.46, 0.58)))

	left_vb.add_child(_info_row("숙소 위치",
		"침대 %d  %s" % [_bed_idx + 1, "상단" if _slot_idx == 0 else "하단"],
		Color(0.68, 0.75, 0.90)))

	var bonus_type: String = str(pilot.get("bonus_type", "none"))
	if bonus_type != "none":
		left_vb.add_child(_info_row("특성",
			_bonus_label(bonus_type, int(pilot.get("bonus_value", 0))),
			Color(0.50, 0.95, 0.68)))

	var personality := str(pilot.get("personality", ""))
	if personality != "":
		left_vb.add_child(_info_row("성격", personality, Color(0.62, 0.90, 0.68)))

	var pref_regions: Array = pilot.get("preferred_regions", [])
	if not pref_regions.is_empty():
		var rnames := pref_regions.map(func(r: String) -> String: return _region_label(r))
		left_vb.add_child(_info_row("선호 지역", ", ".join(rnames), Color(0.72, 0.82, 0.96)))

	var right_vb := VBoxContainer.new()
	right_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vb.add_theme_constant_override("separation", 6)
	right_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_hb.add_child(right_vb)

	var fat := int(pilot.get("fatigue", 0))
	var stress := int(pilot.get("stress", 0))
	var mood := int(pilot.get("mood", 70))
	# 낮을수록 좋은 지표(피로/스트레스)는 빨강 경고, 높을수록 좋은 지표(기분)는 반대
	right_vb.add_child(_stat_bar_row("피로", fat, 100, _bar_color(fat, false)))
	right_vb.add_child(_stat_bar_row("스트레스", stress, 100, _bar_color(stress, false)))
	right_vb.add_child(_stat_bar_row("기분", mood, 100, _bar_color(mood, true)))
	var exp := int(pilot.get("exp", 0))
	var tier := int(pilot.get("tier", 1))
	if tier < 3:
		var threshold: int = GameState.EXP_PER_TIER[tier - 1]
		right_vb.add_child(_stat_bar_row("경험치", exp, threshold, Color(0.55, 0.78, 1.0)))
	else:
		right_vb.add_child(_stat_bar_row("경험치", 1, 1, Color(0.80, 0.58, 1.0), "MAX"))

	# 상태 한마디 (성격 + 현재 상태 기반 대사 연출)
	_content_vb.add_child(_hsep())
	_content_vb.add_child(_build_status_quote(pilot, fat, stress, mood))

	# 침대 이동 버튼 + 목록


# ── 헬퍼 ──────────────────────────────────────────────────────

func _find_assigned_bay() -> int:
	for i in GameState.auto_slots.size():
		var s: DispatchManager.AutoSlot = GameState.auto_slots[i]
		if s.assigned_pilot_id == _pilot_id or s.pilot_id == _pilot_id:
			return i
	return -1

func _region_label(region_id: String) -> String:
	match region_id:
		"scrap":      return "폐기 위성"
		"trade":      return "교역 항로"
		"city_ruins": return "버려진 도시"
		"bio":        return "생태 행성"
	return region_id


func _bonus_label(btype: String, bval: int) -> String:
	match btype:
		"credits_pct":       return "수익 +%d%%" % bval
		"dispatch_time_pct": return "파견 -%d%%" % bval
		"return_time_pct":   return "복귀 -%d%%" % bval
	return btype

func _bar_color(value: int, high_is_good: bool) -> Color:
	# high_is_good=false: 피로/스트레스 (높을수록 나쁨)
	# high_is_good=true:  기분 (낮을수록 나쁨)
	var bad := (value >= 70) if not high_is_good else (value < 40)
	var warn := (value >= 40) if not high_is_good else (value < 70)
	if bad:
		return Color(1.0, 0.50, 0.50)
	if warn:
		return Color(1.0, 0.82, 0.42)
	return Color(0.46, 0.86, 1.0)


func _stat_bar_row(label: String, cur: int, maxv: int, fill_col: Color, override_text: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.modulate = Color(0.46, 0.52, 0.66)
	lbl.custom_minimum_size = Vector2(60, 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = maxf(1.0, float(maxv))
	bar.value = clampf(float(cur), 0.0, bar.max_value)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.13, 0.20, 0.95)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_col
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)

	var val := Label.new()
	val.text = override_text if override_text != "" else str(cur)
	val.add_theme_font_size_override("font_size", 10)
	val.modulate = fill_col
	val.custom_minimum_size = Vector2(34, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(val)
	return row


func _build_status_quote(pilot: Dictionary, fat: int, stress: int, mood: int) -> PanelContainer:
	var personality := str(pilot.get("personality", ""))
	var quote := _status_quote_text(personality, fat, stress, mood)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sty := StyleBoxFlat.new()
	sty.bg_color = Color(0.07, 0.10, 0.16, 0.92)
	sty.border_color = Color(0.30, 0.42, 0.64, 0.55)
	sty.border_width_left = 3
	sty.set_corner_radius_all(4)
	sty.content_margin_left = 10; sty.content_margin_right = 10
	sty.content_margin_top = 6; sty.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sty)
	var lbl := Label.new()
	lbl.text = "“%s”" % quote
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.modulate = Color(0.78, 0.84, 0.98)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lbl)
	return panel


func _status_quote_text(personality: String, fat: int, stress: int, mood: int) -> String:
	# 우선순위: 스트레스 > 피로 > 낮은 기분 > 좋은 컨디션 > 평상시
	var state := "neutral"
	if stress >= 70:
		state = "stress"
	elif fat >= 70:
		state = "fatigue"
	elif mood < 40:
		state = "low_mood"
	elif mood >= 70 and fat < 40 and stress < 40:
		state = "good"
	var lines: Dictionary = {
		"stress": {
			"활발함": "으, 머리 터질 것 같아! 좀 쉬어야겠어.",
			"차분함": "조금... 지친 것 같아요. 정비가 필요해요.",
			"사교적": "다들 좀 쉬자고, 나 진짜 한계야.",
			"독립적": "신경 쓰지 마. ...근데 좀 빡세긴 했어.",
		},
		"fatigue": {
			"활발함": "몸이 안 따라주네. 잠깐 눈 좀 붙일게.",
			"차분함": "피로가 쌓였어요. 침대가 그립네요.",
			"사교적": "다리가 후들거려… 휴식 좀 줘.",
			"독립적": "쉬는 건 시간 낭비지만… 오늘은 좀 눕고 싶군.",
		},
		"low_mood": {
			"활발함": "기분이 영 별로야. 뭐 재밌는 거 없나?",
			"차분함": "마음이 가라앉네요. 커피라도 한 잔…",
			"사교적": "요즘 좀 외로워. 같이 게임할 사람?",
			"독립적": "별일 아냐. ...그냥 좀 가라앉았을 뿐.",
		},
		"good": {
			"활발함": "컨디션 최고야! 언제든 출격 가능!",
			"차분함": "상태 양호합니다. 명령만 내려주세요.",
			"사교적": "오늘 기분 좋은데? 다음 임무 어디야?",
			"독립적": "준비 끝났어. 내 걱정은 안 해도 돼.",
		},
		"neutral": {
			"활발함": "음, 그럭저럭이야. 슬슬 움직여볼까.",
			"차분함": "특이사항 없습니다.",
			"사교적": "뭐, 나쁘지 않아. 다음 일정은?",
			"독립적": "평소대로야.",
		},
	}
	var by_state: Dictionary = lines[state]
	if personality != "" and by_state.has(personality):
		return str(by_state[personality])
	# 성격 미지정 폴백
	match state:
		"stress":   return "스트레스가 한계에 가까워요."
		"fatigue":  return "피로가 많이 쌓였습니다."
		"low_mood": return "기분이 가라앉아 있어요."
		"good":     return "컨디션이 아주 좋습니다."
		_:          return "이상 없습니다."


func _info_row(label: String, value: String, val_col: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.modulate = Color(0.46, 0.52, 0.66)
	lbl.custom_minimum_size = Vector2(72, 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)
	var val := Label.new()
	val.text = value
	val.add_theme_font_size_override("font_size", 11)
	val.modulate = val_col
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(val)
	return row

func _hsep() -> HSeparator:
	var sep := HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.10)
	return sep
