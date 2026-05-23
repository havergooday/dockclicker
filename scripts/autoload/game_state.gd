extends Node

var layout_mode := "horizontal"
var total_credits: int = 0
var pending_credits: int = 0
var player_status: String = "idle"  # idle / on_mission / returned

signal credits_changed(new_total: int)
signal credits_collected(amount: int, from_global_pos: Vector2)
signal player_status_changed(status: String)


func start_direct_dispatch() -> void:
	player_status = "on_mission"
	pending_credits = 0
	player_status_changed.emit(player_status)


func return_from_dispatch() -> void:
	player_status = "returned"
	player_status_changed.emit(player_status)


func add_pending_credit(amount: int) -> void:
	pending_credits += amount


func collect_player_credits(from_global_pos: Vector2) -> void:
	if player_status != "returned" or pending_credits <= 0:
		return
	var amount := pending_credits
	total_credits += amount
	pending_credits = 0
	player_status = "idle"
	player_status_changed.emit(player_status)
	credits_changed.emit(total_credits)
	credits_collected.emit(amount, from_global_pos)
