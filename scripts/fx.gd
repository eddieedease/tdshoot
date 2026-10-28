class_name Fx
extends Node2D
## Short-lived vector effects (sparks, explosions) plus decal helpers.

enum Kind { SPARK, EXPLOSION }

const SPLAT := Vector2i(22, 11)  # Kenney tilesheet: dark splat

static var _unshaded: CanvasItemMaterial

var kind := Kind.SPARK
var color := Color.WHITE
var radius := 10.0
var duration := 0.18
var _t := 0.0
var _dirs: Array[Vector2] = []


static func unshaded() -> CanvasItemMaterial:
	if _unshaded == null:
		_unshaded = CanvasItemMaterial.new()
		_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _unshaded


static func spark(parent: Node, pos: Vector2, col: Color) -> void:
	if parent == null:
		return
	var fx := Fx.new()
	fx.kind = Kind.SPARK
	fx.color = col
	fx.radius = 14.0
	fx.duration = 0.16
	fx.position = pos
	parent.add_child(fx)


static func explosion(parent: Node, pos: Vector2, r: float) -> void:
	var fx := Fx.new()
	fx.kind = Kind.EXPLOSION
	fx.color = Color(1, 0.6, 0.15)
	fx.radius = r
	fx.duration = 0.45
	fx.position = pos
	parent.add_child(fx)
	var light := PointLight2D.new()
	var grad := GradientTexture2D.new()
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color.WHITE)
	grad.gradient.set_color(1, Color(1, 1, 1, 0))
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.5)
	grad.fill_to = Vector2(0.5, 0.0)
	light.texture = grad
	light.texture_scale = r / 20.0
	light.color = Color(1, 0.6, 0.25)
	light.energy = 2.0
	fx.add_child(light)


## Persistent splat on the floor, made from the Kenney splat tile.
static func blood(decal_parent: Node, pos: Vector2, col: Color, size := 1.0) -> void:
	var s := Sprite2D.new()
	s.texture = Game.tile_texture(SPLAT.x, SPLAT.y)
	s.modulate = col
	s.position = pos + Vector2(randf_range(-6, 6), randf_range(-6, 6))
	s.rotation = randf() * TAU
	s.scale = Vector2.ONE * 0.5 * size * randf_range(0.8, 1.2)
	decal_parent.add_child(s)
	# Keep the decal count bounded.
	if decal_parent.get_child_count() > 250:
		for child in decal_parent.get_children():
			if child is Sprite2D:
				child.queue_free()
				break


func _ready() -> void:
	material = unshaded()
	z_index = 5
	var n := 6 if kind == Kind.SPARK else 14
	for i in n:
		_dirs.append(Vector2.RIGHT.rotated(randf() * TAU) * randf_range(0.5, 1.0))


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / duration
	var fade := Color(color, 1.0 - k)
	match kind:
		Kind.SPARK:
			for d in _dirs:
				draw_line(d * radius * k, d * radius * (k + 0.5), fade, 2.0)
			draw_circle(Vector2.ZERO, 5.0 * (1.0 - k), Color(1, 1, 1, 1.0 - k))
		Kind.EXPLOSION:
			var r := radius * ease(k, 0.3)
			draw_circle(Vector2.ZERO, r, Color(1, 0.55, 0.15, 0.55 * (1.0 - k)))
			draw_circle(Vector2.ZERO, r * 0.6, Color(1, 0.9, 0.5, 0.8 * (1.0 - k)))
			draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(1, 0.95, 0.7, 1.0 - k), 4.0)
			for d in _dirs:
				draw_line(d * r * 0.7, d * r * 1.15, fade, 3.0)
