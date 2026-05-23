extends Control

@export var panel_id: String = ""
@onready var back_button: Button = $Header/BackButton


func _ready() -> void:
	back_button.pressed.connect(func(): PanelManager.show_bridge())
	if panel_id != "":
		PanelManager.register_panel(panel_id, self)
