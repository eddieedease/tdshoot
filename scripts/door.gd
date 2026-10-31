@tool
class_name Door
extends StaticBody2D
## Locked security door. Touching it with a key opens it (and uses the key).
## Place its origin on the top-left corner of the doorway (grid snap 64) and set
## the size in tiles. Paint floor under it, not wall.

@export var size_tiles := Vector2i(1, 1):
	set(v):
		size_tiles = Vector2i(maxi(v.x, 1), maxi(v.y, 1))
		_rebuild()
## Halves slide up/down instead of left/right (use for doorways in a vertical wall).
@export var slides_vertically := false:
	set(v):
		slides_vertically = v
		queue_redraw()

var level: Level
var opening := false
var _open_amount := 0.0
var _locked_msg_cooldown := 0.0

@onready var shape: CollisionShape2D = $Shape
@onready var sensor_shape: CollisionShape2D = $Sensor/Shape


func _ready() -> void:
	add_to_group("blockers")
	_rebuild()
	if Engine.is_editor_hint():
		return
	level = Level.current
	$Sensor.body_entered.connect(_on_body_entered)


func _rebuild() -> void:
	if not is_node_ready():
		return
	var size := _size()
	# Each instance gets its own shapes so differently sized doors don't share them.
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = size * 0.5
	var srect := RectangleShape2D.new()
	srect.size = size + Vector2(56, 56)  # bigger than the body so bumping into it counts
	sensor_shape.shape = srect
	sensor_shape.position = size * 0.5
	queue_redraw()


func _size() -> Vector2:
	return Vector2(size_tiles) * Level.TILE


func get_blocked_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var start := Level.world_to_cell(global_position + Vector2(1, 1))
	for y in size_tiles.y:
		for x in size_tiles.x:
			cells.append(start + Vector2i(x, y))
	return cells


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_locked_msg_cooldown -= delta
	if opening:
		_open_amount = minf(_open_amount + delta * 2.5, 1.0)
		queue_redraw()
		if _open_amount >= 1.0:
			queue_free()


func _on_body_entered(body: Node) -> void:
	if opening or not body is Player:
		return
	var p := body as Player
	if p.keys > 0:
		p.keys -= 1
		p.stats_changed.emit()
		open()
	elif _locked_msg_cooldown <= 0.0:
		_locked_msg_cooldown = 2.0
		Sfx.play_at("door_locked", global_position + _size() * 0.5)
		level.hud.show_message("DOOR LOCKED  —  KEY REQUIRED", 2.0)


func open() -> void:
	opening = true
	Sfx.play_at("door_unlock", global_position + _size() * 0.5)
	Sfx.play_at("door_open", global_position + _size() * 0.5)
	shape.set_deferred("disabled", true)
	for c in get_blocked_cells():
		level.set_walkable(c, true)
	level.hud.show_message("DOOR OPENED", 1.5)


func _draw() -> void:
	var size := _size()
	var r := Rect2(Vector2.ZERO, size)
	var horizontal := not slides_vertically
	var slide := _open_amount * (size.x if horizontal else size.y) * 0.5
	var halves: Array[Rect2] = []
	if horizontal:
		halves = [Rect2(Vector2(-slide, 0), Vector2(size.x * 0.5, size.y)),
			Rect2(Vector2(size.x * 0.5 + slide, 0), Vector2(size.x * 0.5, size.y))]
	else:
		halves = [Rect2(Vector2(0, -slide), Vector2(size.x, size.y * 0.5)),
			Rect2(Vector2(0, size.y * 0.5 + slide), Vector2(size.x, size.y * 0.5))]
	var dark := Color(0.12, 0.12, 0.14)
	for h in halves:
		var inner := h.intersection(r)
		if inner.size.x <= 0 or inner.size.y <= 0:
			continue
		draw_rect(inner, Color(0.85, 0.62, 0.12))
		# Hazard stripes, clipped to the door half.
		var box := PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y),
			inner.end, Vector2(inner.position.x, inner.end.y)])
		var i := -inner.size.y
		while i < inner.size.x:
			var a := inner.position + Vector2(i, inner.size.y)
			var stripe := PackedVector2Array([a, a + Vector2(8, 0),
				a + Vector2(8 + inner.size.y, -inner.size.y), a + Vector2(inner.size.y, -inner.size.y)])
			for poly in Geometry2D.intersect_polygons(stripe, box):
				draw_colored_polygon(poly, dark)
			i += 18.0
		draw_rect(inner, dark, false, 4.0)
	if not opening:
		draw_circle(size * 0.5, 7.0, dark)
		draw_circle(size * 0.5, 5.0, Color(1, 0.2, 0.15))
