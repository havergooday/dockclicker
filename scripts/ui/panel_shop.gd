extends Control

@onready var back_button: Button = $Header/BackButton
@onready var damage_info: Label = $ContentArea/VBox/DamageInfo
@onready var upgrade_button: Button = $ContentArea/VBox/UpgradeButton

func _ready() -> void:
	PanelManager.register_panel("shop", self)
	back_button.pressed.connect(func(): PanelManager.show_bridge())
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	GameState.credits_changed.connect(func(_v): _refresh())
	_refresh()

func _refresh() -> void:
	var level := GameState.damage_upgrade_level
	var damage := GameState.click_damage
	damage_info.text = "클릭 데미지: %d  (강화 %d/%d)" % [damage, level, GameState.DAMAGE_UPGRADE_COSTS.size()]
	var cost := GameState.get_damage_upgrade_cost()
	if cost < 0:
		upgrade_button.text = "최대 강화 달성"
		upgrade_button.disabled = true
	else:
		upgrade_button.text = "데미지 강화  +1  (%d CR)" % cost
		upgrade_button.disabled = GameState.total_credits < cost

func _on_upgrade_pressed() -> void:
	GameState.upgrade_click_damage()
