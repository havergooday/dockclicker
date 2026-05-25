extends Node

signal panel_changed(panel_id: String)

var current_panel: String = "bridge"
var _panels: Dictionary = {}
var _is_transitioning: bool = false
var _history: Array[String] = []


func register_panel(id: String, node: Control) -> void:
	_panels[id] = node


func show_panel(panel_id: String) -> void:
	if _is_transitioning or panel_id == current_panel:
		return
	if not _panels.has(panel_id) or not _panels.has(current_panel):
		return
	_history.append(current_panel)
	_flip_to(current_panel, panel_id)


func go_back() -> void:
	var target: String = _history.pop_back() if not _history.is_empty() else "bridge"
	if _is_transitioning or target == current_panel:
		return
	if not _panels.has(target) or not _panels.has(current_panel):
		return
	_flip_to(current_panel, target)


func show_bridge() -> void:
	_history.clear()
	show_panel("bridge")


func get_back_label() -> String:
	var names: Dictionary = {
		"bridge":   "브릿지",
		"hangar":   "격납고",
		"workshop": "공작실",
		"shop":     "상점",
		"dispatch": "파견 관제",
		"clicker":  "클리커",
	}
	var prev: String = _history.back() if not _history.is_empty() else "bridge"
	return names.get(prev, prev)


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
		go_back()
		get_viewport().set_input_as_handled()
