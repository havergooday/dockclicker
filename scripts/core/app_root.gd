extends Control

@onready var main_panel: Control = $MainPanel


func _ready() -> void:
	main_panel.mouse_filter = Control.MOUSE_FILTER_PASS
