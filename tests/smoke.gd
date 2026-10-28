extends Node

var level: Level
var frame := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	level = load("res://scenes/levels/level_1.tscn").instantiate()
	add_child(level)
	level.player.health = 100000
	print("grid ", level.width, "x", level.height, " origin=", level.origin, " aliens=", get_tree().get_nodes_in_group("aliens").size(), " nests=", get_tree().get_nodes_in_group("nests").size(), " blockers=", get_tree().get_nodes_in_group("blockers").size())
	print("walkable start=", level.is_walkable(Vector2i(4, 3)), " crate cell=", level.is_walkable(Vector2i(8, 2)), " door cell=", level.is_walkable(Vector2i(44, 13)), " wall=", level.is_walkable(Vector2i(0, 0)))

func _physics_process(_d: float) -> void:
	frame += 1
	var p := level.player
	if frame == 5:
		Input.action_press("move_down")
	if frame == 60:
		Input.action_release("move_down")
		print("after move pos=", p.global_position, " flowdir=", level.flow_direction(level.cell_center(Vector2i(30, 13))))
		Input.action_press("fire")
	if frame == 120:
		Input.action_release("fire")
		print("ammo mag=", p.mag, " reserve=", p.reserve_ammo)
	if frame == 200:
		var nest: Nest = get_tree().get_nodes_in_group("nests")[0]
		p.global_position = nest.global_position + Vector2(-128, 0)
	if frame == 450:
		print("aliens=", get_tree().get_nodes_in_group("aliens").size())
		get_tree().get_nodes_in_group("nests")[0].take_damage(100)
		get_tree().get_nodes_in_group("barrels")[0].take_damage(10)
	if frame == 520:
		print("nests left=", get_tree().get_nodes_in_group("nests").size(), " barrels=", get_tree().get_nodes_in_group("barrels").size(), " score=", Game.score)
		p.keys = 1
		var door: Door = level.get_node("Entities/Doors/Door1")
		p.global_position = door.global_position + Vector2(-20, 32)
	if frame == 600:
		print("doors left=", level.get_node("Entities/Doors").get_child_count(), " keys=", p.keys, " door cell walkable=", level.is_walkable(Vector2i(44, 13)))
		p.global_position = level.cell_center(Vector2i(58, 35)) + Vector2(32, 32)
	if frame == 640:
		print("finished=", level.finished)
		get_tree().quit()
