@tool
class_name WallTrim
extends Node2D
## Draws the coloured trim along every wall edge that faces open floor, in the
## Kenney style. Reads the Walls TileMapLayer and redraws whenever you paint,
## so the editor shows exactly what the game shows.
##
## Wall style = the wall tile's atlas column in tiles/walls.png:
##   0 steel   1 orange   2 hazard yellow   3 alien green

const STYLES: Array[Color] = [
	Color(0.56, 0.71, 0.75),
	Color(0.93, 0.45, 0.13),
	Color(0.95, 0.78, 0.15),
	Color(0.45, 0.8, 0.3),
]

@export var walls: TileMapLayer:
	set(v):
		if walls and walls.changed.is_connected(queue_redraw):
			walls.changed.disconnect(queue_redraw)
		walls = v
		if walls:
			walls.changed.connect(queue_redraw)
		queue_redraw()
@export var trim_width := 10.0
@export var deep_shade := Color(0, 0, 0, 0.4)

const T := 64.0


func _ready() -> void:
	queue_redraw()


func _is_wall(c: Vector2i) -> bool:
	return walls.get_cell_source_id(c) != -1


func _draw() -> void:
	if walls == null:
		return
	var tw := trim_width
	for c in walls.get_used_cells():
		var o := Vector2(c) * T
		var style := clampi(walls.get_cell_atlas_coords(c).x, 0, STYLES.size() - 1)
		var trim := STYLES[style]
		var shadow := trim.darkened(0.45)
		var open_l := not _is_wall(c + Vector2i.LEFT)
		var open_r := not _is_wall(c + Vector2i.RIGHT)
		var open_u := not _is_wall(c + Vector2i.UP)
		var open_d := not _is_wall(c + Vector2i.DOWN)
		var near_open := open_l or open_r or open_u or open_d
		for d in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
			if not _is_wall(c + d):
				near_open = true
		if not near_open:
			# Deep inside a wall mass: shade it darker for depth.
			draw_rect(Rect2(o, Vector2(T, T)), deep_shade)
			continue

		if open_l:
			draw_rect(Rect2(o + Vector2(tw, 0), Vector2(3, T)), shadow)
			draw_rect(Rect2(o, Vector2(tw, T)), trim)
		if open_r:
			draw_rect(Rect2(o + Vector2(T - tw - 3, 0), Vector2(3, T)), shadow)
			draw_rect(Rect2(o + Vector2(T - tw, 0), Vector2(tw, T)), trim)
		if open_u:
			draw_rect(Rect2(o + Vector2(0, tw), Vector2(T, 3)), shadow)
			draw_rect(Rect2(o, Vector2(T, tw)), trim)
		if open_d:
			draw_rect(Rect2(o + Vector2(0, T - tw - 3), Vector2(T, 3)), shadow)
			draw_rect(Rect2(o + Vector2(0, T - tw), Vector2(T, tw)), trim)

		# Inner corners: open only diagonally, walls on both sides.
		for d in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
			if _is_wall(c + d) or not _is_wall(c + Vector2i(d.x, 0)) or not _is_wall(c + Vector2i(0, d.y)):
				continue
			var cx := o.x if d.x < 0 else o.x + T - tw
			var cy := o.y if d.y < 0 else o.y + T - tw
			draw_rect(Rect2(cx, cy, tw, tw), trim)
