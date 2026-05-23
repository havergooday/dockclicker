extends Control

@onready var back_button: Button = $Header/BackButton
@onready var dispatch_button: Button = $ContentArea/VBox/DispatchButton
@onready var planet_container: HBoxContainer = $ContentArea/VBox/PlanetContainer

func _ready() -> void:
	PanelManager.register_panel("dispatch", self)
	back_button.pressed.connect(func(): PanelManager.show_bridge())
	dispatch_button.pressed.connect(_on_dispatch_pressed)
	GameState.player_status_changed.connect(_on_player_status_changed)
	GameState.planet_unlocked.connect(func(_id): _rebuild_planet_buttons())
	GameState.credits_changed.connect(func(_v): _rebuild_planet_buttons())
	_rebuild_planet_buttons()

func _rebuild_planet_buttons() -> void:
	for child in planet_container.get_children():
		child.queue_free()
	for planet in GameState.PLANETS:
		planet_container.add_child(_make_planet_button(planet))

func _make_planet_button(planet: Dictionary) -> Button:
	var planet_id: String = planet["id"]
	var is_unlocked := GameState.is_planet_unlocked(planet_id)
	var is_selected := GameState.selected_planet == planet_id
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(150, 70)
	btn.toggle_mode = true
	btn.button_pressed = is_selected
	if is_unlocked:
		btn.text = planet["name"]
		if is_selected:
			btn.text += "\n[선택됨]"
	else:
		btn.text = "%s\n🔒 %d CR" % [planet["name"], planet["unlock_cost"]]
		btn.disabled = GameState.total_credits < int(planet["unlock_cost"])
	btn.pressed.connect(func(): _on_planet_pressed(planet_id))
	return btn

func _on_planet_pressed(planet_id: String) -> void:
	if not GameState.is_planet_unlocked(planet_id):
		if not GameState.unlock_planet(planet_id):
			return
	GameState.selected_planet = planet_id
	_rebuild_planet_buttons()

func _on_dispatch_pressed() -> void:
	if not GameState.is_planet_unlocked(GameState.selected_planet):
		return
	GameState.start_direct_dispatch()
	PanelManager.show_panel("clicker")

func _on_player_status_changed(status: String) -> void:
	dispatch_button.disabled = status != "idle"
