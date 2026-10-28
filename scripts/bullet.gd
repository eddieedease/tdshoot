class_name Bullet
extends Node2D
## Fast projectile using ray casts each frame (no tunnelling through thin things).

var velocity := Vector2.ZERO
var damage := 1
var life := 0.9
var collision_mask := Level.WALL_LAYER | Level.ENEMY_LAYER
var color := Color(1, 0.9, 0.5)
var fx_parent: Node


func _ready() -> void:
	rotation = velocity.angle()
	material = Fx.unshaded()


func _physics_process(delta: float) -> void:
	travel_to(global_position + velocity * delta)
	life -= delta
	if life <= 0.0:
		queue_free()


## Moves to `target`, hitting whatever is in between. Returns true if something was hit.
func travel_to(target: Vector2) -> bool:
	if is_queued_for_deletion():
		return true
	var q := PhysicsRayQueryParameters2D.create(global_position, target, collision_mask)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		global_position = target
		return false
	var collider: Object = hit.collider
	if collider.has_method("take_damage"):
		collider.take_damage(damage, velocity.normalized())
	var is_enemy := collider is Alien or collider is Nest
	Fx.spark(fx_parent if fx_parent else get_parent(), hit.position,
		Color(0.55, 0.95, 0.3) if is_enemy else Color(1, 0.85, 0.4))
	queue_free()
	return true


func _draw() -> void:
	draw_line(Vector2(-22, 0), Vector2(4, 0), Color(color, 0.35), 5.0)
	draw_line(Vector2(-14, 0), Vector2(6, 0), color, 2.5)
