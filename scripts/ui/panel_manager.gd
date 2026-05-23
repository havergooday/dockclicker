extends Node

signal panel_changed(panel_id: String)

var current_panel: String = "bridge"
var _panels: Dictionary = {}
var _is_transitioning: bool = false


func register_panel(id: String, node: Control) -> void:
	_panels[id] = node


func show_panel(panel_id: String) -> void:
	if _is_transitioning or panel_id == current_panel:
		return
	if not _panels.has(panel_id) or not _panels.has(current_panel):
		return
	_flip_to(current_panel, panel_id)


func show_bridge() -> void:
	show_panel("bridge")


func _flip_to(from_id: String, to_id: String) -> void:
	_is_transitioning = true
	var from_node: Control = _panels[from_id]
	var to_node: Control = _panels[to_id]

	from_node.pivot_offset = from_node.size / 2.0

	var tween := create_tween()

	tween.tween_property(from_node, "scale:y", 0.0, 0.12) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)

	tween.tween_callback(func():
		from_node.visible = false
		from_node.scale.y = 1.0
		to_node.pivot_offset = to_node.size / 2.0
		to_node.scale.y = 0.0
		to_node.visible = true
	)

	tween.tween_property(to_node, "scale:y", 1.0, 0.12) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

	tween.tween_callback(func():
		current_panel = to_id
		_is_transitioning = false
		panel_changed.emit(to_id)
	)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and current_panel != "bridge" and not _is_transitioning:
		show_bridge()
		get_viewport().set_input_as_handled()
