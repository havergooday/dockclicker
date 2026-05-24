extends Control

var _displayed_value: int = 0

@onready var credit_label: Label = $CreditLabel

func _ready() -> void:
	GameState.credits_changed.connect(_on_credits_changed)
	GameState.credits_collected.connect(_on_credits_collected)
	_displayed_value = GameState.total_credits
	credit_label.text = "CR  %d" % _displayed_value
	credit_label.add_theme_font_size_override("font_size", 12)
	credit_label.modulate = Color(0.75, 1.0, 0.65)

func _on_credits_changed(new_total: int) -> void:
	var tween := create_tween()
	tween.tween_method(
		func(v: float): credit_label.text = "CR  %d" % int(v),
		float(_displayed_value), float(new_total), 0.5
	)
	_displayed_value = new_total

func _on_credits_collected(amount: int, from_global_pos: Vector2) -> void:
	var fly := Label.new()
	fly.text = "+%d" % amount
	fly.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	fly.add_theme_font_size_override("font_size", 14)
	fly.z_index = 100
	get_parent().add_child(fly)
	fly.global_position = from_global_pos
	var target := get_global_rect().get_center()
	var tween := fly.create_tween()
	tween.tween_property(fly, "global_position", target, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(fly.queue_free)
