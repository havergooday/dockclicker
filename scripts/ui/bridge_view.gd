extends Control


func _ready() -> void:
	PanelManager.register_panel("bridge", self)
