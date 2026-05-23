extends Node

var layout_mode := "horizontal"
var total_credits: int = 0
var pending_credits: int = 0
var player_status: String = "idle"  # idle / on_mission / returned
var click_damage: int = 1
var damage_upgrade_level: int = 0
var unlocked_planets: Array = ["sector_a"]
var selected_planet: String = "sector_a"

const PLANETS: Array = [
	{
		"id": "sector_a",
		"name": "섹터 A",
		"unlock_cost": 0,
		"max_on_screen": 2,
		"wave_size": 5,
		"credit_per_kill": 10,
		"enemy_hp": 2,
	},
	{
		"id": "sector_b",
		"name": "섹터 B",
		"unlock_cost": 50,
		"max_on_screen": 3,
		"wave_size": 8,
		"credit_per_kill": 15,
		"enemy_hp": 3,
	},
	{
		"id": "sector_c",
		"name": "섹터 C",
		"unlock_cost": 200,
		"max_on_screen": 4,
		"wave_size": 12,
		"credit_per_kill": 25,
		"enemy_hp": 5,
	},
]

const DAMAGE_UPGRADE_COSTS: Array = [20, 50, 100, 200]

signal credits_changed(new_total: int)
signal credits_collected(amount: int, from_global_pos: Vector2)
signal player_status_changed(status: String)
signal planet_unlocked(planet_id: String)


func get_planet(planet_id: String) -> Dictionary:
	for p in PLANETS:
		if p["id"] == planet_id:
			return p
	return {}


func get_selected_planet_data() -> Dictionary:
	return get_planet(selected_planet)


func is_planet_unlocked(planet_id: String) -> bool:
	return planet_id in unlocked_planets


func unlock_planet(planet_id: String) -> bool:
	if is_planet_unlocked(planet_id):
		return false
	var data := get_planet(planet_id)
	if data.is_empty() or total_credits < int(data["unlock_cost"]):
		return false
	total_credits -= int(data["unlock_cost"])
	unlocked_planets.append(planet_id)
	credits_changed.emit(total_credits)
	planet_unlocked.emit(planet_id)
	return true


func get_damage_upgrade_cost() -> int:
	if damage_upgrade_level >= DAMAGE_UPGRADE_COSTS.size():
		return -1
	return DAMAGE_UPGRADE_COSTS[damage_upgrade_level]


func upgrade_click_damage() -> bool:
	var cost := get_damage_upgrade_cost()
	if cost < 0 or total_credits < cost:
		return false
	total_credits -= cost
	damage_upgrade_level += 1
	click_damage += 1
	credits_changed.emit(total_credits)
	return true


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
