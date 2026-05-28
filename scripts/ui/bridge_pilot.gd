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

const ROAM_SPEED     := 40.0
const ROAM_PAUSE_MIN := 1.5
const ROAM_PAUSE_MAX := 4.0
const BUBBLE_DURATION := 2.4

var pilot_data: Dictionary = {}

var _dragging:       bool    = false
var _drag_offset:    Vector2 = Vector2.ZERO
var _roam_target_x:  float   = 0.0
var _roam_paused:    bool    = false
var _roam_dir:       int     = 1
var _bubble:         Control = null
var _bubble_timer:   float   = 0.0
var _bounds_min_x:   float   = 0.0
var _bounds_max_x:   float   = 800.0

const SIZE := 48


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_roam_target_x = position.x
	_start_new_roam()


func setup(p: Dictionary, bounds_min: float, bounds_max: float) -> void:
	pilot_data = p
	_bounds_min_x = bounds_min
	_bounds_max_x = bounds_max - SIZE
	queue_redraw()


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

	_do_roam(delta)


func _do_roam(delta: float) -> void:
	if _roam_paused:
		return

	var diff := _roam_target_x - position.x
	if abs(diff) < 2.0:
		position.x = _roam_target_x
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
	var margin := SIZE * 2.0
	_roam_target_x = randf_range(_bounds_min_x + margin, _bounds_max_x - margin)


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
	var greeting: String = GREETINGS[randi() % GREETINGS.size()]
	_show_bubble(greeting)


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
