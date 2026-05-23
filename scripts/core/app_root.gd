extends Control

var _dragging := false
var _drag_start_mouse := Vector2i.ZERO
var _drag_start_win := Vector2i.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_position_at_bottom()


func _position_at_bottom() -> void:
	var screen := DisplayServer.screen_get_size()
	var win := DisplayServer.window_get_size()
	var x := (screen.x - win.x) / 2
	var y := screen.y - win.y
	DisplayServer.window_set_position(Vector2i(x, y))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_start_mouse = DisplayServer.mouse_get_position()
			_drag_start_win = DisplayServer.window_get_position()
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var delta := DisplayServer.mouse_get_position() - _drag_start_mouse
		DisplayServer.window_set_position(_drag_start_win + delta)
