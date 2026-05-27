extends Control

var _enemies: Dictionary = {}
var _wave_kills: int = 0
var _planet_data: Dictionary = {}
var _auto_attack_timer: float = 0.0

const AUTO_ATTACK_INTERVAL := 1.5

@onready var battle_area: Control = $BattleArea
@onready var session_label: Label = $Header/SessionLabel
@onready var return_button: Button = $ReturnButton

func _ready() -> void:
	PanelManager.register_panel("clicker", self)
	return_button.pressed.connect(_on_return_pressed)
	PanelManager.panel_changed.connect(_on_panel_changed)

func _process(delta: float) -> void:
	if not visible or not GameState.auto_attack_unlocked or _enemies.is_empty():
		return
	_auto_attack_timer -= delta
	if _auto_attack_timer <= 0.0:
		_auto_attack_timer = AUTO_ATTACK_INTERVAL
		_do_auto_attack()


func _do_auto_attack() -> void:
	var keys := _enemies.keys()
	if keys.is_empty():
		return
	var enemy: Button = keys[randi() % keys.size()]
	if not is_instance_valid(enemy) or not _enemies.has(enemy):
		return
	var dmg := maxi(1, GameState.click_damage / 2)
	_enemies[enemy]["hp"] -= dmg
	if _enemies[enemy]["hp"] <= 0:
		_kill_enemy(enemy)
	else:
		_update_enemy_display(enemy)
		var tw := enemy.create_tween()
		tw.tween_property(enemy, "modulate", Color(0.45, 0.85, 1.0), 0.05)
		tw.tween_property(enemy, "modulate", Color.WHITE, 0.12)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_return_pressed()
		get_viewport().set_input_as_handled()

func _on_panel_changed(panel_id: String) -> void:
	if panel_id == "clicker":
		_start_session()

func _start_session() -> void:
	_planet_data = GameState.get_selected_planet_data()
	_wave_kills = 0
	_auto_attack_timer = AUTO_ATTACK_INTERVAL
	_clear_enemies()
	_refresh_session_label()
	_fill_to_max.call_deferred()

func _clear_enemies() -> void:
	for enemy in _enemies.keys():
		enemy.queue_free()
	_enemies.clear()

func _fill_to_max() -> void:
	if _planet_data.is_empty():
		return
	var max_on_screen: int = _planet_data.get("max_on_screen", 2)
	var wave_size: int = _planet_data.get("wave_size", 5)
	var total := _wave_kills + _enemies.size()
	while _enemies.size() < max_on_screen and total < wave_size:
		_spawn_enemy()
		total += 1

func _spawn_enemy() -> void:
	var enemy_hp: int = _planet_data.get("enemy_hp", 2)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(80, 60)
	battle_area.add_child(btn)
	_enemies[btn] = {"hp": enemy_hp, "max_hp": enemy_hp}
	_update_enemy_display(btn)
	btn.pressed.connect(func(): _on_enemy_clicked(btn))
	_randomize_position(btn)

func _randomize_position(node: Button) -> void:
	var area_size := battle_area.size
	var w := maxf(area_size.x - node.custom_minimum_size.x, 0.0)
	var h := maxf(area_size.y - node.custom_minimum_size.y, 0.0)
	node.position = Vector2(randf_range(0, w), randf_range(0, h))

func _update_enemy_display(enemy: Button) -> void:
	var data: Dictionary = _enemies[enemy]
	enemy.text = "👾\n%d/%d" % [data["hp"], data["max_hp"]]

func _on_enemy_clicked(enemy: Button) -> void:
	if not _enemies.has(enemy):
		return
	_enemies[enemy]["hp"] -= GameState.click_damage
	if _enemies[enemy]["hp"] <= 0:
		_kill_enemy(enemy)
	else:
		_update_enemy_display(enemy)

func _kill_enemy(enemy: Button) -> void:
	var credit_per_kill: int = _planet_data.get("credit_per_kill", 10)
	GameState.add_pending_credit(credit_per_kill)
	_enemies.erase(enemy)
	enemy.queue_free()
	_wave_kills += 1
	_refresh_session_label()
	var wave_size: int = _planet_data.get("wave_size", 5)
	if _wave_kills >= wave_size:
		_on_wave_complete()
	else:
		_fill_to_max()

func _on_wave_complete() -> void:
	_on_return_pressed()

func _refresh_session_label() -> void:
	var wave_size: int = _planet_data.get("wave_size", 5)
	session_label.text = "%s  처치: %d/%d  보류: %d CR" % [
		_planet_data.get("name", ""),
		_wave_kills, wave_size,
		GameState.pending_credits
	]

func _on_return_pressed() -> void:
	_clear_enemies()
	GameState.return_from_dispatch()
	GameState.collect_player_credits(return_button.global_position)
	PanelManager.go_back()
