extends Button

@export var target_panel: String = ""


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if target_panel != "":
		PanelManager.show_panel(target_panel)
