extends Control

const BASE_HP := 20
const CLICK_DAMAGE := 1
const CREDIT_PER_KILL := 10

var _enemy_hp: int = 0

@onready var enemy_button: Button = $ContentArea/VBox/EnemyButton
@onready var hp_bar: ProgressBar = $ContentArea/VBox/HPBar
@onready var session_label: Label = $ContentArea/VBox/SessionLabel
@onready var return_button: Button = $ReturnButton

func _ready() -> void:
	PanelManager.register_panel("clicker", self)
	enemy_button.pressed.connect(_on_enemy_clicked)
	return_button.pressed.connect(_on_return_pressed)
	PanelManager.panel_changed.connect(_on_panel_changed)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_return_pressed()
		get_viewport().set_input_as_handled()

func _on_panel_changed(panel_id: String) -> void:
	if panel_id == "clicker":
		_spawn_enemy()

func _spawn_enemy() -> void:
	_enemy_hp = BASE_HP
	_refresh_display()

func _on_enemy_clicked() -> void:
	_enemy_hp -= CLICK_DAMAGE
	if _enemy_hp <= 0:
		GameState.add_pending_credit(CREDIT_PER_KILL)
		_spawn_enemy()
	else:
		_refresh_display()

func _refresh_display() -> void:
	hp_bar.max_value = BASE_HP
	hp_bar.value = _enemy_hp
	session_label.text = "보류 크레딧: %d" % GameState.pending_credits

func _on_return_pressed() -> void:
	GameState.return_from_dispatch()
	PanelManager.show_panel("hangar")
