extends Control

var _enemies: Dictionary = {}
var _wave_kills: int = 0
var _planet_data: Dictionary = {}
var _auto_attack_timer: float = 0.0
var _returning := false
var _float_label: Label
var _combo_count: int = 0
var _last_click_time: float = 0.0
var _combo_label: Label = null

const AUTO_ATTACK_INTERVAL := 1.5

@onready var battle_area: Control = $BattleArea
@onready var session_label: Label = $Header/SessionLabel
@onready var return_button: Button = $Header/ReturnButton

func _ready() -> void:
	PanelManager.register_panel("clicker", self)
	return_button.pressed.connect(_on_return_pressed)
	PanelManager.panel_changed.connect(_on_panel_changed)
	_build_float_label()
	_build_combo_label()


func _build_combo_label() -> void:
	_combo_label = Label.new()
	_combo_label.anchor_right  = 1.0
	_combo_label.anchor_bottom = 0.0
	_combo_label.offset_top    = 4.0
	_combo_label.offset_bottom = 24.0
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo_label.add_theme_font_size_override("font_size", 12)
	_combo_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.30))
	_combo_label.modulate.a = 0.0
	_combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_combo_label)

func _build_float_label() -> void:
	_float_label = Label.new()
	_float_label.anchor_left = 0.5
	_float_label.anchor_right = 0.5
	_float_label.anchor_top = 0.5
	_float_label.anchor_bottom = 0.5
	_float_label.offset_left = -200.0
	_float_label.offset_right = 200.0
	_float_label.offset_top = -50.0
	_float_label.offset_bottom = 50.0
	_float_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_float_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_float_label.add_theme_font_size_override("font_size", 42)
	_float_label.add_theme_color_override("font_color", Color(0.88, 0.96, 1.0))
	_float_label.modulate.a = 0.0
	_float_label.z_index = 20
	_float_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_float_label)

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
	_combo_count = 0
	_last_click_time = 0.0
	_returning = false
	return_button.disabled = false
	if is_instance_valid(_float_label):
		_float_label.modulate.a = 0.0
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
	var dmg := _calc_click_damage()
	var click_center := enemy.position + enemy.custom_minimum_size * 0.5

	# 피격 대상 수집 (범위 포함)
	var targets: Array = [enemy]
	var range_px := GameState.get_click_range_px()
	if range_px > 0.0:
		for other in _enemies.keys():
			if other == enemy:
				continue
			var other_center := (other as Button).position + (other as Button).custom_minimum_size * 0.5
			if click_center.distance_to(other_center) <= range_px:
				targets.append(other)

	for target in targets:
		if not _enemies.has(target):
			continue
		_enemies[target]["hp"] -= dmg
		if _enemies[target]["hp"] <= 0:
			_kill_enemy(target)
		else:
			_update_enemy_display(target)


func _calc_click_damage() -> int:
	var now := Time.get_unix_time_from_system()
	if GameState.combo_level > 0 and now - _last_click_time <= PartsData.COMBO_WINDOW_SEC:
		_combo_count += 1
	else:
		_combo_count = 1
	_last_click_time = now

	var base := GameState.click_damage
	var threshold := GameState.get_combo_threshold()
	if GameState.combo_level > 0 and _combo_count >= threshold:
		var mult := GameState.get_combo_multiplier()
		_show_combo_active(mult)
		return int(ceil(float(base) * mult))
	return base


func _show_combo_active(mult: float) -> void:
	if _combo_label == null:
		return
	_combo_label.text = "COMBO ×%.1f" % mult
	_combo_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(_combo_label, "modulate:a", 0.0, 0.3)

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
	if _returning:
		return
	_returning = true
	return_button.disabled = true
	_show_float_then("미션완료", 0.8, _do_return)


func _on_return_pressed() -> void:
	if _returning:
		return
	_returning = true
	return_button.disabled = true
	_show_float_then("함선복귀", 0.5, _do_return)


func _show_float_then(text: String, hold: float, callback: Callable) -> void:
	_float_label.text = text
	_float_label.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_float_label, "modulate:a", 1.0, 0.18)
	tween.tween_interval(hold)
	tween.tween_callback(callback)


func _do_return() -> void:
	_clear_enemies()
	GameState.return_from_dispatch()
	GameState.collect_player_credits(return_button.global_position)
	PanelManager.go_back()

func _refresh_session_label() -> void:
	var wave_size: int = _planet_data.get("wave_size", 5)
	session_label.text = "%s  처치: %d/%d  보류: %d CR" % [
		_planet_data.get("name", ""),
		_wave_kills, wave_size,
		GameState.pending_credits
	]

