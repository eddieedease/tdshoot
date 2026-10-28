class_name Nest
extends StaticBody2D
## Alien nest: keeps hatching aliens while the player is close. Shoot it to destroy it.

@export var max_health := 18
@export var spawn_interval := 3.5
@export var activation_range := 750.0
@export var max_alive := 4

var level: Level
var health := 0
var _spawn_timer := 1.5
var _children: Array = []
var _t := 0.0
var _hurt_flash := 0.0

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	add_to_group("nests")
	health = max_health
	add_to_group("blockers")
	level = Level.current


func _process(delta: float) -> void:
	_t += delta
	var pulse := 1.0 + sin(_t * 3.0) * 0.06
	sprite.scale = Vector2(0.5, 0.5) * 1.15 * pulse
	_hurt_flash = maxf(_hurt_flash - delta * 6.0, 0.0)
	sprite.modulate = Color(0.55, 0.25, 0.7).lerp(Color(2, 2, 2), _hurt_flash)
	queue_redraw()

	var player := level.player if level else null
	if player == null or player.dead:
		return
	if global_position.distance_to(player.global_position) > activation_range:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = spawn_interval * randf_range(0.8, 1.2)
		_spawn()


func _spawn() -> void:
	_children = _children.filter(func(a): return is_instance_valid(a))
	if _children.size() >= max_alive:
		return
	# Pop out on a free side of the nest.
	var c := level.world_to_cell(global_position)
	var options: Array[Vector2i] = []
	for d in Level.DIRS8:
		if level.is_walkable(c + d):
			options.append(c + d)
	if options.is_empty():
		return
	var alien: Alien = load("res://scenes/entities/alien_runner.tscn" if randf() < 0.3 else "res://scenes/entities/alien.tscn").instantiate()
	alien.position = level.cell_center(options.pick_random())
	alien.awake = true
	level.entities.add_child(alien)
	_children.append(alien)


func take_damage(amount: int, _from_dir := Vector2.ZERO) -> void:
	if health <= 0:
		return
	health -= amount
	_hurt_flash = 1.0
	if health <= 0:
		_die()


func _die() -> void:
	Fx.explosion(level.effects, global_position, 90.0)
	Fx.blood(level.decals, global_position, Color(0.4, 0.2, 0.5), 1.6)
	level.set_walkable(level.world_to_cell(global_position), true)
	level.shake(8.0)
	level.on_nest_destroyed()
	queue_free()


func _draw() -> void:
	# Glowing eye in the middle so the nest reads as something alive.
	var glow := 0.6 + 0.4 * sin(_t * 5.0)
	draw_circle(Vector2.ZERO, 11.0, Color(0.12, 0.05, 0.15))
	draw_circle(Vector2.ZERO, 7.0, Color(0.9, 0.3, 1.0, glow))
	# Health ring.
	var k := float(health) / max_health
	draw_arc(Vector2.ZERO, 30.0, -PI / 2, -PI / 2 + TAU * k, 40, Color(0.85, 0.35, 1.0, 0.8), 3.0)
