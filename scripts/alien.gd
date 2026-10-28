class_name Alien
extends CharacterBody2D
## Basic alien: wakes up when the player is near (or it gets shot), then hunts
## the player using the level's flow field, and claws on contact.

@export var speed := 150.0
@export var acceleration := 900.0
@export var max_health := 4
@export var damage := 6
@export var attack_interval := 0.8
@export var wake_range := 650.0
@export var attack_range := 34.0

var level: Level
var awake := false
var health := 0

var _attack_cooldown := 0.0
var _los_timer := 0.0
var _has_los := false
var _hurt_flash := 0.0
var _wander := Vector2.ZERO
var _wander_timer := 0.0

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	add_to_group("aliens")
	level = Level.current
	health = max_health
	speed *= randf_range(0.9, 1.1)
	_los_timer = randf() * 0.2


func _physics_process(delta: float) -> void:
	var player := level.player if level else null
	var desired := Vector2.ZERO
	if player and not player.dead:
		var to_player := player.global_position - global_position
		var dist := to_player.length()

		_los_timer -= delta
		if _los_timer <= 0.0:
			_los_timer = 0.2
			_has_los = dist < wake_range * 1.5 and level.has_line_of_sight(global_position, player.global_position)
		if not awake and ((dist < wake_range and _has_los) or dist < 200.0):
			awake = true

		if awake:
			if _has_los or dist < 80.0:
				desired = to_player / maxf(dist, 0.001)
			else:
				desired = level.flow_direction(global_position)
			_attack_cooldown -= delta
			if dist < attack_range + 15.0 and _attack_cooldown <= 0.0:
				_attack_cooldown = attack_interval
				player.take_damage(damage, to_player.normalized())
		else:
			desired = _idle_wander(delta)
	else:
		desired = _idle_wander(delta)

	desired += _separation() * 0.8
	velocity = velocity.move_toward(desired.limit_length(1.0) * speed, acceleration * delta)
	move_and_slide()
	if velocity.length() > 10.0:
		rotation = lerp_angle(rotation, velocity.angle(), minf(delta * 10.0, 1.0))

	_hurt_flash = maxf(_hurt_flash - delta * 6.0, 0.0)
	sprite.modulate = Color.WHITE.lerp(Color(2, 2, 2), _hurt_flash)


func _idle_wander(delta: float) -> Vector2:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(1.0, 3.0)
		_wander = Vector2.ZERO if randf() < 0.5 else Vector2.RIGHT.rotated(randf() * TAU) * 0.3
	return _wander


## Push away from nearby aliens so the swarm spreads out instead of stacking.
func _separation() -> Vector2:
	var push := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("aliens"):
		if other == self:
			continue
		var d: Vector2 = global_position - other.global_position
		var l := d.length()
		if l < 36.0 and l > 0.01:
			push += d / l * (1.0 - l / 36.0)
	return push


func take_damage(amount: int, from_dir := Vector2.ZERO) -> void:
	if health <= 0:
		return
	health -= amount
	awake = true
	_hurt_flash = 1.0
	velocity += from_dir * 160.0
	Fx.blood(level.decals, global_position, Color(0.35, 0.75, 0.15, 0.8), 0.45)
	if health <= 0:
		_die()


func _die() -> void:
	Fx.blood(level.decals, global_position, Color(0.3, 0.7, 0.12), 1.1)
	level.on_alien_killed(self)
	# Small chance to drop something useful.
	var roll := randf()
	if roll < 0.08:
		_drop(Pickup.Kind.AMMO)
	elif roll < 0.18:
		_drop(Pickup.Kind.CREDITS)
	queue_free()


func _drop(kind: Pickup.Kind) -> void:
	var p: Pickup = load("res://scenes/entities/pickup.tscn").instantiate()
	p.kind = kind
	p.position = global_position
	level.entities.add_child.call_deferred(p)
