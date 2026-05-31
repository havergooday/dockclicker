extends Control

# 브릿지에서 돌아다니는 파일럿 캐릭터
# 클릭 → 말풍선, 드래그 → 위치 이동, idle 시 좌우 로밍

const GREETINGS: Array = [
	"잘 부탁드립니다!",
	"오늘도 열심히 해볼게요.",
	"언제든 불러주세요.",
	"임무 준비 완료!",
	"대기 중입니다.",
	"뭐 시킬 거 있어요?",
]
const PERSONALITY_GREETINGS: Dictionary = {
	"활발함": ["가죠! 언제든지요!", "임무 기다리고 있었어요!", "준비 완료!", "빨리 출발해요!"],
	"차분함": ["잘 부탁드립니다.", "언제든 불러주세요.", "대기 중입니다.", "준비되어 있습니다."],
	"사교적": ["반가워요! 오늘도 잘 부탁해요.", "같이하면 더 재미있죠.", "뭐 도와드릴까요?", "항상 여기 있을게요."],
	"독립적": ["부르셨나요?", "알겠습니다.", "맡겨두세요.", "혼자서도 잘 할게요."],
}
const REST_LINES: Array = [
	"잠깐만 쉬고 갈게요.",
	"소파가 있으니 좀 살겠네요.",
	"금방 다시 움직일게요.",
]
const PLAY_LINES: Array = [
	"한 판만 하고 갈게요.",
	"머리 좀 식히고 있어요.",
	"이거 은근히 집중되네요.",
]
const EAT_LINES: Array = [
	"커피 한 잔 하고 갈게요.",
	"기분 전환이 필요했어요.",
	"따뜻한 게 좀 들어가니 낫네요.",
]
const RECOVER_LINES: Array = [
	"좀 쉬어야 할 것 같아요.",
	"몸이 무거워서요, 잠깐만요.",
	"이번 임무가 좀 힘들었어요.",
]

const ROAM_SPEED     := 40.0
const ROAM_PAUSE_MIN := 1.5
const ROAM_PAUSE_MAX := 4.0
const BUBBLE_DURATION := 2.4
const ACTIVITY_TICK_SECONDS := 4.0

var pilot_data: Dictionary = {}
var current_activity: String = "wander"
var target_point: Vector2 = Vector2.ZERO
var activity_until: float = 0.0
var activity_point_provider: Callable = Callable()

var _dragging:       bool    = false
var _drag_offset:    Vector2 = Vector2.ZERO
var _roam_target_x:  float   = 0.0
var _roam_paused:    bool    = false
var _roam_dir:       int     = 1
var _bubble:         Control = null
var _bubble_timer:   float   = 0.0
var _bounds_min_x:   float   = 0.0
var _bounds_max_x:   float   = 800.0
var _mood_label: Label = null
var _fatigue_label: Label = null
var _stress_label: Label = null
var _activity_label: Label = null
var _activity_tick_accum: float = 0.0

const SIZE := 48


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_build_mood_label()
	_roam_target_x = position.x
	_start_new_roam()


func setup(p: Dictionary, bounds_min: float, bounds_max: float) -> void:
	pilot_data = p
	_bounds_min_x = bounds_min
	_bounds_max_x = bounds_max - SIZE
	_refresh_mood_label()
	queue_redraw()


func update_pilot_data(p: Dictionary) -> void:
	pilot_data = p
	_refresh_mood_label()
	queue_redraw()


func set_activity_point_provider(provider: Callable) -> void:
	activity_point_provider = provider


func _draw() -> void:
	var col_str: String = str(pilot_data.get("portrait_color", "#4499DD"))
	var col := Color(col_str) if col_str.begins_with("#") else Color.CORNFLOWER_BLUE

	# 몸체 원
	draw_circle(Vector2(SIZE * 0.5, SIZE * 0.5), SIZE * 0.46, col.darkened(0.3))
	# 테두리
	draw_arc(Vector2(SIZE * 0.5, SIZE * 0.5), SIZE * 0.46, 0, TAU, 32, col, 2.0)
	# 이니셜
	# (draw_string으로 텍스트 표시)


func _process(delta: float) -> void:
	if _bubble_timer > 0.0:
		_bubble_timer -= delta
		if _bubble_timer <= 0.0:
			_hide_bubble()

	if _dragging:
		return

	_process_activity_tick(delta)
	_do_roam(delta)


func _do_roam(delta: float) -> void:
	if _roam_paused:
		return

	var diff := _roam_target_x - position.x
	if abs(diff) < 2.0:
		position.x = _roam_target_x
		if current_activity == "rest":
			if not _roam_paused:
				_show_bubble(REST_LINES[randi() % REST_LINES.size()])
			_roam_paused = true
			return
		if current_activity == "play":
			if not _roam_paused:
				_show_bubble(PLAY_LINES[randi() % PLAY_LINES.size()])
			_roam_paused = true
			return
		if current_activity == "eat":
			if not _roam_paused:
				_show_bubble(EAT_LINES[randi() % EAT_LINES.size()])
			_roam_paused = true
			return
		if current_activity == "recover":
			if not _roam_paused:
				_show_bubble(RECOVER_LINES[randi() % RECOVER_LINES.size()])
			_roam_paused = true
			return
		_schedule_pause()
		return

	var step: float = ROAM_SPEED * delta * sign(diff)
	position.x += step
	_roam_dir = int(sign(diff))


func _schedule_pause() -> void:
	_roam_paused = true
	var wait := randf_range(ROAM_PAUSE_MIN, ROAM_PAUSE_MAX)
	get_tree().create_timer(wait).timeout.connect(_start_new_roam, CONNECT_ONE_SHOT)


func _start_new_roam() -> void:
	_roam_paused = false
	if int(pilot_data.get("fatigue", 0)) >= 50 and activity_point_provider.is_valid():
		var rest_points: Array = activity_point_provider.call("rest")
		if not rest_points.is_empty():
			current_activity = "rest"
			target_point = rest_points[0]
			activity_until = Time.get_unix_time_from_system() + 6.0
			_activity_tick_accum = 0.0
			_roam_target_x = clampf(target_point.x, _bounds_min_x, _bounds_max_x)
			return
	if int(pilot_data.get("stress", 0)) >= 70 and activity_point_provider.is_valid():
		var recover_points: Array = activity_point_provider.call("recover")
		if not recover_points.is_empty():
			current_activity = "recover"
			target_point = recover_points[0]
			activity_until = Time.get_unix_time_from_system() + 6.0
			_activity_tick_accum = 0.0
			_roam_target_x = clampf(target_point.x, _bounds_min_x, _bounds_max_x)
			return
	if int(pilot_data.get("stress", 0)) >= 50 and activity_point_provider.is_valid():
		var play_points: Array = activity_point_provider.call("play")
		if not play_points.is_empty():
			current_activity = "play"
			target_point = play_points[0]
			activity_until = Time.get_unix_time_from_system() + 6.0
			_activity_tick_accum = 0.0
			_roam_target_x = clampf(target_point.x, _bounds_min_x, _bounds_max_x)
			return
	var eat_threshold := 50 if GameState.get_installed_facility("table") == "dine_table_1" else 40
	if int(pilot_data.get("mood", 70)) <= eat_threshold and activity_point_provider.is_valid():
		var eat_points: Array = activity_point_provider.call("eat")
		if not eat_points.is_empty():
			current_activity = "eat"
			target_point = eat_points[0]
			activity_until = Time.get_unix_time_from_system() + 6.0
			_activity_tick_accum = 0.0
			_roam_target_x = clampf(target_point.x, _bounds_min_x, _bounds_max_x)
			return
	current_activity = "wander"
	_activity_tick_accum = 0.0
	var margin := SIZE * 2.0
	_roam_target_x = randf_range(_bounds_min_x + margin, _bounds_max_x - margin)


func _process_activity_tick(delta: float) -> void:
	if current_activity != "rest" and current_activity != "play" and current_activity != "eat" and current_activity != "recover":
		return
	if Time.get_unix_time_from_system() >= activity_until:
		current_activity = "wander"
		_activity_tick_accum = 0.0
		_roam_paused = false
		_start_new_roam()
		return
	if abs(position.x - _roam_target_x) > 2.0:
		return
	_activity_tick_accum += delta
	if _activity_tick_accum < ACTIVITY_TICK_SECONDS:
		return
	_activity_tick_accum = 0.0
	if str(pilot_data.get("id", "")) == "":
		return
	var pid := str(pilot_data.get("id", ""))
	var fav: Array = pilot_data.get("favorite_facilities", [])
	var fav_bonus := 1 if current_activity in fav else 0
	if current_activity == "rest":
		GameState.apply_pilot_state_delta(pid, {"fatigue": -2, "mood": 1 + fav_bonus})
	elif current_activity == "play":
		GameState.apply_pilot_state_delta(pid, {"stress": -2, "mood": 1 + fav_bonus})
	elif current_activity == "eat":
		var mood_gain := 3 if GameState.is_feature_unlocked("canteen") else 2
		GameState.apply_pilot_state_delta(pid, {"mood": mood_gain + fav_bonus})
	elif current_activity == "recover":
		GameState.apply_pilot_state_delta(pid, {"stress": -2, "fatigue": -1 - fav_bonus})


func gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_drag_offset = position - get_global_mouse_position()
				get_viewport().set_input_as_handled()
			else:
				if _dragging:
					_dragging = false
					get_viewport().set_input_as_handled()
				else:
					_on_clicked()
	elif event is InputEventMouseMotion and _dragging:
		var new_x := clampf(
			(get_global_mouse_position() + _drag_offset).x,
			_bounds_min_x, _bounds_max_x
		)
		position.x = new_x
		_roam_target_x = new_x
		get_viewport().set_input_as_handled()


func _on_clicked() -> void:
	var personality := str(pilot_data.get("personality", ""))
	var lines: Array = PERSONALITY_GREETINGS.get(personality, GREETINGS) as Array
	_show_bubble(lines[randi() % lines.size()])


func _show_bubble(text: String) -> void:
	_hide_bubble()
	_bubble_timer = BUBBLE_DURATION

	var bubble := PanelContainer.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.08, 0.12, 0.20, 0.92)
	style.border_color = Color(0.40, 0.60, 0.90, 0.75)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	bubble.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.modulate = Color(0.88, 0.94, 1.0)
	bubble.add_child(lbl)

	# 위치: 파일럿 위
	bubble.position = Vector2(SIZE * 0.5 - 60.0, -38.0)
	add_child(bubble)
	_bubble = bubble


func _hide_bubble() -> void:
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.queue_free()
	_bubble = null


func _build_mood_label() -> void:
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.position = Vector2(-10.0, SIZE + 1.0)
	vb.custom_minimum_size = Vector2(SIZE + 20.0, 42.0)
	vb.add_theme_constant_override("separation", 1)
	add_child(vb)
	_fatigue_label = _make_status_label(vb)
	_stress_label  = _make_status_label(vb)
	_mood_label    = _make_status_label(vb)
	_activity_label = _make_status_label(vb)
	_refresh_mood_label()


func _make_status_label(parent: Control) -> Label:
	var lbl := Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.custom_minimum_size = Vector2(SIZE + 20.0, 13.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 9)
	parent.add_child(lbl)
	return lbl


func _refresh_mood_label() -> void:
	var fatigue := clampi(int(pilot_data.get("fatigue", 0)), 0, 100)
	var stress := clampi(int(pilot_data.get("stress", 0)), 0, 100)
	var mood := clampi(int(pilot_data.get("mood", 70)), 0, 100)
	if is_instance_valid(_fatigue_label):
		_fatigue_label.text = "피로 %d" % fatigue
		_fatigue_label.modulate = _status_color_hi_bad(fatigue)
	if is_instance_valid(_stress_label):
		_stress_label.text = "스트 %d" % stress
		_stress_label.modulate = _status_color_hi_bad(stress)
	if is_instance_valid(_mood_label):
		_mood_label.text = "기분 %d" % mood
		if mood >= 70:
			_mood_label.modulate = Color(0.58, 0.92, 1.0)
		elif mood >= 40:
			_mood_label.modulate = Color(0.78, 0.82, 0.94)
		else:
			_mood_label.modulate = Color(1.0, 0.62, 0.62)
	if is_instance_valid(_activity_label):
		_activity_label.text = "활동 %s" % _activity_text(current_activity)
		_activity_label.modulate = _activity_color(current_activity)


func _status_color_hi_bad(val: int) -> Color:
	if val < 40:
		return Color(0.58, 0.92, 1.0)
	if val < 70:
		return Color(0.85, 0.75, 0.50)
	return Color(1.0, 0.62, 0.62)


func _activity_text(activity: String) -> String:
	match activity:
		"rest":
			return "휴식"
		"play":
			return "놀이"
		"eat":
			return "식사"
		"recover":
			return "회복"
		"wander":
			return "순회"
		_:
			return "대기"


func _activity_color(activity: String) -> Color:
	match activity:
		"rest":
			return Color(0.72, 0.86, 1.0)
		"play":
			return Color(0.78, 0.94, 0.72)
		"eat":
			return Color(0.94, 0.86, 0.58)
		"recover":
			return Color(1.0, 0.72, 0.72)
		_:
			return Color(0.68, 0.76, 0.90)
