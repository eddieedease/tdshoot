class_name Crosshair
extends Control
## Mouse crosshair, drawn as vector shapes so it stays sharp at any resolution.

var reloading := false:
	set(v):
		if v != reloading:
			reloading = v
			queue_redraw()


func _draw() -> void:
	var col := Color(1, 0.55, 0.2) if reloading else Color(0.6, 1, 0.85)
	var shadow := Color(0, 0, 0, 0.6)
	for pass_i in 2:
		var c := shadow if pass_i == 0 else col
		var w := 5.0 if pass_i == 0 else 2.5
		draw_arc(Vector2.ZERO, 14, 0, TAU, 32, c, w)
		for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(d * 8, d * 22, c, w)
	draw_circle(Vector2.ZERO, 2.0, col)
