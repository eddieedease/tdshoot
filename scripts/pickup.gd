@tool
class_name Pickup
extends Area2D

enum Kind { AMMO, HEALTH, KEY, CREDITS }

const TEX_AMMO := preload("res://assets/Topdown Shooter/PNG/weapon_machine.png")

@export var kind := Kind.AMMO:
	set(v):
		kind = v
		_update_icon()
@export var ammo_amount := 60
@export var health_amount := 35
@export var credits_amount := 250

var _t := 0.0

@onready var icon: Sprite2D = $Icon


func _ready() -> void:
	_t = randf() * TAU
	_update_icon()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _update_icon() -> void:
	if not is_node_ready():
		return
	icon.texture = TEX_AMMO
	icon.visible = kind == Kind.AMMO
	queue_redraw()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	# Pulse via the icon and the draw transform, never our own scale (keeps scenes clean).
	var s := 1.0 + sin(_t * 4.0) * 0.06
	icon.scale = Vector2(s, s)
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if not body is Player:
		return
	var p := body as Player
	var hud: Hud = p.level.hud
	match kind:
		Kind.AMMO:
			p.add_ammo(ammo_amount)
			Sfx.play("pickup_ammo")
			hud.show_message("+%d AMMO" % ammo_amount, 1.2)
		Kind.HEALTH:
			if not p.heal(health_amount):
				return
			Sfx.play("pickup_health")
			hud.show_message("MEDKIT  +%d" % health_amount, 1.2)
		Kind.KEY:
			p.keys += 1
			p.stats_changed.emit()
			Sfx.play("pickup_key")
			hud.show_message("KEY CARD ACQUIRED", 1.5)
		Kind.CREDITS:
			p.credits += credits_amount
			Game.score += credits_amount
			p.stats_changed.emit()
			Sfx.play("pickup_credits")
			hud.show_message("+%d CREDITS" % credits_amount, 1.2)
	Fx.spark(p.level.effects, global_position, Color(0.6, 1, 0.9))
	queue_free()


func _draw() -> void:
	# Soft glow ring so pickups read in the dark.
	var glow := 0.25 + 0.15 * sin(_t * 3.0)
	match kind:
		Kind.AMMO:
			draw_circle(Vector2.ZERO, 22, Color(1, 0.8, 0.2, glow))
			draw_rect(Rect2(-20, -12, 40, 24), Color(0.36, 0.33, 0.18))
			draw_rect(Rect2(-20, -12, 40, 24), Color(0.95, 0.78, 0.25), false, 3.0)
		Kind.HEALTH:
			draw_circle(Vector2.ZERO, 22, Color(1, 0.3, 0.3, glow))
			draw_rect(Rect2(-16, -16, 32, 32), Color(0.95, 0.95, 0.95))
			draw_rect(Rect2(-4, -11, 8, 22), Color(0.85, 0.15, 0.15))
			draw_rect(Rect2(-11, -4, 22, 8), Color(0.85, 0.15, 0.15))
			draw_rect(Rect2(-16, -16, 32, 32), Color(0.6, 0.6, 0.65), false, 2.0)
		Kind.KEY:
			draw_circle(Vector2.ZERO, 24, Color(1, 0.9, 0.2, glow + 0.1))
			draw_rect(Rect2(-14, -19, 28, 38), Color(1, 0.82, 0.15))
			draw_rect(Rect2(-14, -19, 28, 38), Color(0.4, 0.3, 0.05), false, 2.0)
			draw_rect(Rect2(-9, -13, 18, 6), Color(0.25, 0.2, 0.05))
			draw_circle(Vector2(0, 8), 5, Color(0.25, 0.2, 0.05))
		Kind.CREDITS:
			draw_circle(Vector2.ZERO, 20, Color(0.3, 1, 0.6, glow))
			draw_circle(Vector2.ZERO, 13, Color(0.2, 0.75, 0.45))
			draw_arc(Vector2.ZERO, 13, 0, TAU, 32, Color(0.85, 1, 0.9), 2.5)
			draw_rect(Rect2(-2, -8, 4, 16), Color(0.9, 1, 0.92))
