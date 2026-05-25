extends Button

@export var target_panel: String = ""
@export var accent_color: Color = Color(0.50, 0.75, 1.00)

const GRID := 20.0

var _dragging: bool = false
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_offsets: Array = []
var _default_offsets: Array = []   # [ol, ot, or_, ob] — scene 기본값

func _ready() -> void:
	_default_offsets = [offset_left, offset_top, offset_right, offset_bottom]
	_apply_saved_position()
	_apply_hotspot_style()
	GameState.ui_edit_mode_changed.connect(_on_edit_mode_changed)
	GameState.ui_positions_reset.connect(_on_positions_reset)
	pressed.connect(func():
		if not GameState.ui_edit_mode:
			PanelManager.show_panel(target_panel)
	)

func _apply_saved_position() -> void:
	if not GameState.ui_positions.has(target_panel):
		return
	var p: Dictionary = GameState.ui_positions[target_panel]
	var w: float = offset_right - offset_left
	var h: float = offset_bottom - offset_top
	var new_l: float = float(p.get("ol", offset_left))
	var new_t: float = float(p.get("ot", offset_top))
	offset_left   = new_l
	offset_top    = new_t
	offset_right  = new_l + w
	offset_bottom = new_t + h

func _apply_hotspot_style() -> void:
	clip_text = false
	_set_normal_style()

func _set_normal_style() -> void:
	var a := accent_color

	var norm := StyleBoxFlat.new()
	norm.bg_color     = Color(a.r, a.g, a.b, 0.08)
	norm.border_color = Color(a.r, a.g, a.b, 0.35)
	norm.set_border_width_all(1)
	norm.set_corner_radius_all(5)
	add_theme_stylebox_override("normal", norm)

	var hov := StyleBoxFlat.new()
	hov.bg_color     = Color(a.r, a.g, a.b, 0.18)
	hov.border_color = Color(a.r, a.g, a.b, 0.80)
	hov.set_border_width_all(1)
	hov.set_corner_radius_all(5)
	add_theme_stylebox_override("hover", hov)

	var prs := StyleBoxFlat.new()
	prs.bg_color     = Color(a.r, a.g, a.b, 0.28)
	prs.border_color = a
	prs.set_border_width_all(2)
	prs.set_corner_radius_all(5)
	add_theme_stylebox_override("pressed", prs)

	add_theme_font_size_override("font_size", 10)
	add_theme_color_override("font_color",       Color(a.r, a.g, a.b, 0.70))
	add_theme_color_override("font_hover_color", a.lightened(0.2))

func _set_edit_style() -> void:
	var norm := StyleBoxFlat.new()
	norm.bg_color     = Color(1.0, 0.80, 0.20, 0.10)
	norm.border_color = Color(1.0, 0.85, 0.30, 0.75)
	norm.set_border_width_all(1)
	norm.set_corner_radius_all(5)
	add_theme_stylebox_override("normal", norm)

	var hov := StyleBoxFlat.new()
	hov.bg_color     = Color(1.0, 0.80, 0.20, 0.22)
	hov.border_color = Color(1.0, 0.95, 0.50, 1.00)
	hov.set_border_width_all(2)
	hov.set_corner_radius_all(5)
	add_theme_stylebox_override("hover", hov)

	add_theme_color_override("font_color",       Color(1.00, 0.90, 0.50, 0.85))
	add_theme_color_override("font_hover_color", Color(1.00, 1.00, 0.70, 1.00))

func _on_edit_mode_changed(enabled: bool) -> void:
	if enabled:
		_set_edit_style()
		mouse_default_cursor_shape = Control.CURSOR_MOVE
	else:
		_set_normal_style()
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_dragging = false

func _gui_input(event: InputEvent) -> void:
	if not GameState.ui_edit_mode:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_start_mouse = get_global_mouse_position()
			_drag_start_offsets = [offset_left, offset_top, offset_right, offset_bottom]
		else:
			if _dragging:
				_dragging = false
				_save_position()
		accept_event()

	elif event is InputEventMouseMotion and _dragging:
		var delta := get_global_mouse_position() - _drag_start_mouse
		var w: float = _drag_start_offsets[2] - _drag_start_offsets[0]
		var h: float = _drag_start_offsets[3] - _drag_start_offsets[1]
		var new_l := snappedf(_drag_start_offsets[0] + delta.x, GRID)
		var new_t := snappedf(_drag_start_offsets[1] + delta.y, GRID)
		offset_left   = new_l
		offset_top    = new_t
		offset_right  = new_l + w
		offset_bottom = new_t + h
		accept_event()

func _on_positions_reset() -> void:
	offset_left   = _default_offsets[0]
	offset_top    = _default_offsets[1]
	offset_right  = _default_offsets[2]
	offset_bottom = _default_offsets[3]

func _save_position() -> void:
	GameState.ui_positions[target_panel] = {
		"ol": offset_left,
		"ot": offset_top,
	}
	SaveManager.save()
