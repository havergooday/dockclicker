extends Control

const GAME_HEIGHT := 300

var _dragging := false
var _drag_start_mouse := Vector2i.ZERO
var _drag_start_win := Vector2i.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit_to_screen()
	get_tree().set_auto_accept_quit(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveManager.save()
		get_tree().quit()

func _fit_to_screen() -> void:
	var usable := DisplayServer.screen_get_usable_rect()
	DisplayServer.window_set_size(Vector2i(usable.size.x, GAME_HEIGHT))
	DisplayServer.window_set_position(Vector2i(usable.position.x, usable.position.y + usable.size.y - GAME_HEIGHT))

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
