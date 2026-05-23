extends Control

@onready var back_button: Button = $Header/BackButton
@onready var dispatch_button: Button = $ContentArea/DispatchButton

func _ready() -> void:
	PanelManager.register_panel("dispatch", self)
	back_button.pressed.connect(func(): PanelManager.show_bridge())
	dispatch_button.pressed.connect(_on_dispatch_pressed)
	GameState.player_status_changed.connect(_on_player_status_changed)

func _on_dispatch_pressed() -> void:
	GameState.start_direct_dispatch()
	PanelManager.show_panel("clicker")

func _on_player_status_changed(status: String) -> void:
	dispatch_button.disabled = status != "idle"
