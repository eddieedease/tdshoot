class_name Barrel
extends StaticBody2D
## Explosive barrel. Hurts everything nearby (including you) and chains to other barrels.

@export var max_health := 3
@export var blast_radius := 150.0
@export var blast_damage := 6
@export var player_damage := 35

var level: Level
var health := 0
var _exploded := false


func _ready() -> void:
	health = max_health
	add_to_group("blockers")
	level = Level.current


func take_damage(amount: int, _from_dir := Vector2.ZERO) -> void:
	if _exploded:
		return
	health -= amount
	$Sprite.modulate = Color(1.6, 1.3, 1.3)
	create_tween().tween_property($Sprite, "modulate", Color.WHITE, 0.15)
	if health <= 0:
		# Tiny delay makes chain reactions ripple instead of popping all at once.
		_exploded = true
		await get_tree().create_timer(0.08).timeout
		_explode()


func _explode() -> void:
	var pos := global_position
	Fx.explosion(level.effects, pos, blast_radius)
	Sfx.play_at("explosion", pos)
	Sfx.play_at("explosion_tail", pos)
	Fx.blood(level.decals, pos, Color(0.05, 0.05, 0.05, 0.85), 2.2)
	level.shake(12.0)
	for group in ["aliens", "nests"]:
		for n in get_tree().get_nodes_in_group(group):
			if n.global_position.distance_to(pos) < blast_radius:
				n.take_damage(blast_damage, (n.global_position - pos).normalized())
	for b in get_tree().get_nodes_in_group("barrels"):
		if b != self and b.global_position.distance_to(pos) < blast_radius:
			b.take_damage(99)
	var p := level.player
	if p and p.global_position.distance_to(pos) < blast_radius:
		p.take_damage(player_damage)
	level.set_walkable(level.world_to_cell(pos), true)
	queue_free()
