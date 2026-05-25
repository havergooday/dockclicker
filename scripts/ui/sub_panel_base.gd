extends Control

@export var panel_id: String = ""
@onready var back_button: Button = $Header/BackButton


func _ready() -> void:
	back_button.pressed.connect(func(): PanelManager.go_back())
	back_button.text = "← %s" % PanelManager.get_back_label()
	PanelManager.panel_changed.connect(func(id: String):
		if id == panel_id: back_button.text = "← %s" % PanelManager.get_back_label()
	)
	if panel_id != "":
		PanelManager.register_panel(panel_id, self)
