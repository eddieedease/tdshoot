class_name Player
extends CharacterBody2D

signal stats_changed
signal died

@export var speed := 270.0
@export var acceleration := 2400.0
@export var max_health := 100
@export var fire_interval := 0.085
@export var mag_size := 30
@export var reload_time := 1.1
@export var bullet_speed := 1600.0
@export var bullet_damage := 1
@export var spread_degrees := 3.5
@export var camera_lookahead := 140.0

const TEX_MACHINE := preload("res://assets/Topdown Shooter/PNG/Soldier 1/soldier1_machine.png")
const TEX_RELOAD := preload("res://assets/Topdown Shooter/PNG/Soldier 1/soldier1_reload.png")

var level: Level
var health := 0
var mag := 0
var reserve_ammo := 90
var keys := 0
var credits := 0
var dead := false
var frozen := false
var aim_dir := Vector2.RIGHT

var _fire_cooldown := 0.0
var _reload_left := 0.0
var _hurt_flash := 0.0
var _shake := 0.0
var _flash_left := 0.0

@onready var body: Node2D = $Body
@onready var sprite: Sprite2D = $Body/Sprite
@onready var muzzle: Marker2D = $Body/Muzzle
@onready var muzzle_flash: Polygon2D = $Body/Muzzle/Flash
@onready var muzzle_light: PointLight2D = $Body/Muzzle/Light
@onready var camera: Camera2D = $Camera


func _ready() -> void:
	health = max_health
	mag = mag_size
	muzzle_flash.visible = false
	muzzle_light.visible = false
	level = Level.current
	add_to_group("player")


func set_camera_limits(bounds: Rect2) -> void:
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)
	camera.reset_smoothing.call_deferred()


func _physics_process(delta: float) -> void:
	if dead:
		return
	var move := Vector2.ZERO
	if not frozen:
		move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = velocity.move_toward(move * speed, acceleration * delta)
	move_and_slide()

	_update_aim(move)
	body.rotation = aim_dir.angle()

	_fire_cooldown -= delta
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_finish_reload()
	elif not frozen:
		if Input.is_action_pressed("fire") and _fire_cooldown <= 0.0:
			_shoot()
		if Input.is_action_just_pressed("reload"):
			start_reload()


func _process(delta: float) -> void:
	_flash_left -= delta
	if _flash_left <= 0.0:
		muzzle_flash.visible = false
		muzzle_light.visible = false

	_hurt_flash = maxf(_hurt_flash - delta * 4.0, 0.0)
	sprite.modulate = Color.WHITE.lerp(Color(1, 0.3, 0.3), _hurt_flash)

	# Camera: look ahead towards where we aim, plus screen shake.
	var look := aim_dir * camera_lookahead
	if not Game.using_gamepad:
		look = (get_global_mouse_position() - global_position) * 0.3
		look = look.limit_length(camera_lookahead * 1.6)
	_shake = maxf(_shake - delta * 30.0, 0.0)
	var jitter := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	camera.offset = camera.offset.lerp(look, minf(delta * 5.0, 1.0))
	camera.position = jitter


func _update_aim(move: Vector2) -> void:
	if frozen:
		return
	if Game.using_gamepad:
		var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		if stick.length() > 0.25:
			aim_dir = stick.normalized()
		elif move.length() > 0.2:
			# Twin-stick fallback: no right stick input -> face where you walk.
			aim_dir = aim_dir.slerp(move.normalized(), 0.25)
	else:
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length() > 8.0:
			aim_dir = to_mouse.normalized()


func _shoot() -> void:
	if mag <= 0:
		if reserve_ammo <= 0:
			Sfx.play("empty")
		start_reload()
		return
	mag -= 1
	_fire_cooldown = fire_interval
	var bullet := Bullet.new()
	var spread := deg_to_rad(randf_range(-spread_degrees, spread_degrees))
	bullet.velocity = aim_dir.rotated(spread) * bullet_speed
	bullet.damage = bullet_damage
	bullet.fx_parent = level.effects
	# Trace from the body to the muzzle first so we can't shoot through a wall we hug.
	bullet.position = global_position
	level.effects.add_child(bullet)
	bullet.travel_to(muzzle.global_position)
	Sfx.play("shoot")

	muzzle_flash.visible = true
	muzzle_flash.scale = Vector2.ONE * randf_range(0.8, 1.2)
	muzzle_light.visible = true
	_flash_left = 0.04
	add_shake(1.5)
	stats_changed.emit()
	if mag == 0:
		start_reload()


func start_reload() -> void:
	if _reload_left > 0.0 or mag >= mag_size or reserve_ammo <= 0:
		if mag == 0 and reserve_ammo <= 0:
			level.hud.show_message("OUT OF AMMO", 1.0)
		return
	_reload_left = reload_time
	Sfx.play("reload_start")
	sprite.texture = TEX_RELOAD
	sprite.offset = Vector2(3.5, 0)
	stats_changed.emit()


func _finish_reload() -> void:
	var needed := mag_size - mag
	var taken := mini(needed, reserve_ammo)
	mag += taken
	reserve_ammo -= taken
	sprite.texture = TEX_MACHINE
	sprite.offset = Vector2(8.5, 0)
	Sfx.play("reload_done")
	stats_changed.emit()


func is_reloading() -> bool:
	return _reload_left > 0.0


func take_damage(amount: int, _from_dir := Vector2.ZERO) -> void:
	if dead or frozen:
		return
	health = maxi(health - amount, 0)
	_hurt_flash = 1.0
	add_shake(6.0)
	Sfx.play("player_hurt")
	stats_changed.emit()
	if health <= 0:
		_die()


func heal(amount: int) -> bool:
	if health >= max_health:
		return false
	health = mini(health + amount, max_health)
	stats_changed.emit()
	return true


func add_ammo(amount: int) -> void:
	reserve_ammo += amount
	stats_changed.emit()
	if mag == 0:
		start_reload()


func add_shake(amount: float) -> void:
	_shake = minf(_shake + amount, 14.0)


func _die() -> void:
	dead = true
	Sfx.play("player_die")
	velocity = Vector2.ZERO
	collision_layer = 0
	Fx.blood(level.decals, global_position, Color(0.55, 0.05, 0.05), 1.4)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(0.4, 0.1, 0.1, 0.0), 0.8)
	died.emit()
