extends Control

const GRID := 20.0

func _draw() -> void:
	var col := Color(1, 1, 1, 0.07)
	var dot  := Color(1, 1, 1, 0.18)
	for x in range(0, int(size.x) + 1, int(GRID)):
		draw_line(Vector2(x, 0), Vector2(x, size.y), col, 1.0)
	for y in range(0, int(size.y) + 1, int(GRID)):
		draw_line(Vector2(0, y), Vector2(size.x, y), col, 1.0)
	for x in range(0, int(size.x) + 1, int(GRID)):
		for y in range(0, int(size.y) + 1, int(GRID)):
			draw_circle(Vector2(x, y), 1.5, dot)
