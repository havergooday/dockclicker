extends Control

@onready var back_button: Button = $Header/BackButton
@onready var status_label: Label = $ContentArea/PlayerSlot/VBox/StatusLabel
@onready var reward_label: Label = $ContentArea/PlayerSlot/VBox/RewardLabel
@onready var collect_button: Button = $ContentArea/PlayerSlot/VBox/CollectButton

func _ready() -> void:
	PanelManager.register_panel("hangar", self)
	back_button.pressed.connect(func(): PanelManager.show_bridge())
	collect_button.pressed.connect(_on_collect_pressed)
	GameState.player_status_changed.connect(_on_player_status_changed)
	_refresh_slot()

func _on_player_status_changed(_status: String) -> void:
	_refresh_slot()

func _refresh_slot() -> void:
	match GameState.player_status:
		"idle":
			status_label.text = "대기중"
			reward_label.visible = false
			collect_button.visible = false
		"on_mission":
			status_label.text = "임무중"
			reward_label.visible = false
			collect_button.visible = false
		"returned":
			status_label.text = "귀환완료"
			reward_label.text = "보류: %d 크레딧" % GameState.pending_credits
			reward_label.visible = true
			collect_button.visible = true

func _on_collect_pressed() -> void:
	GameState.collect_player_credits(collect_button.get_global_rect().get_center())
