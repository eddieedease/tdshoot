@tool
class_name ExitPad
extends Area2D
## The exit lift. Standing on it finishes the level.
## Place its origin on a tile corner (grid snap 64) and set the size in tiles.

@export var size_tiles := Vector2i(2, 2):
	set(v):
		size_tiles = Vector2i(maxi(v.x, 1), maxi(v.y, 1))
		_rebuild()

var _t := 0.0

@onready var shape: CollisionShape2D = $Shape
@onready var label: Label = $Label


func _ready() -> void:
	_rebuild()
	if not Engine.is_editor_hint():
		body_entered.connect(func(body: Node) -> void:
			if body is Player and Level.current:
				Level.current.on_exit_reached())


func _rebuild() -> void:
	if not is_node_ready():
		return
	var size := Vector2(size_tiles) * Level.TILE
	var rect := RectangleShape2D.new()
	rect.size = size * 0.6
	shape.shape = rect
	shape.position = size * 0.5
	label.size = Vector2(size.x, 30)
	label.position = Vector2(0, 10)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var size := Vector2(size_tiles) * Level.TILE
	var r := Rect2(Vector2.ZERO, size).grow(-6)
	var c := size * 0.5
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	draw_rect(r, Color(0.12, 0.14, 0.13))
	draw_rect(r.grow(-10), Color(0.2, 0.85, 0.4, 0.25 + 0.35 * pulse))
	draw_rect(r, Color(0.2, 0.85, 0.4), false, 6.0)
	for i in 3:
		var y := c.y - 10.0 + i * 18.0 - fmod(_t * 20.0, 18.0)
		draw_polyline(PackedVector2Array([Vector2(c.x - 18, y - 8), Vector2(c.x, y + 6), Vector2(c.x + 18, y - 8)]),
			Color(0.2, 0.95, 0.45, 0.9), 5.0)
