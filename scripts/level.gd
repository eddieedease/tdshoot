class_name Level
extends Node2D
## A playable level, designed entirely in the editor:
##   - Floor / Decor / Walls are TileMapLayers you paint with tiles/level_tiles.tres
##   - Entities holds dragged-in scenes (player, aliens, nests, doors, pickups, ...)
## At runtime this node runs the level-wide systems: alien pathfinding, win/lose.

const TILE := 64
const WALL_LAYER := 1
const PLAYER_LAYER := 2
const ENEMY_LAYER := 4
const PICKUP_LAYER := 8

const DIRS4: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const DIRS8: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
const FAR := 1 << 30


## The level currently being played (set before any entity's _ready runs).
static var current: Level

@export var level_name := "LEVEL"
@export_multiline var intro_text := "FIND THE EXIT LIFT"
## Level to load after this one is completed (leave empty to return to the menu).
@export_file("*.tscn") var next_level := ""

@onready var floor_layer: TileMapLayer = $Floor
@onready var walls_layer: TileMapLayer = $Walls
@onready var decals: Node2D = $Decals
@onready var entities: Node2D = $Entities
@onready var effects: Node2D = $Effects
@onready var hud: Hud = $HUD

## Grid covering every painted cell; `origin` is the top-left cell.
var origin := Vector2i.ZERO
var width := 0
var height := 0
var walkable := PackedByteArray()
var flow := PackedInt32Array()
var player: Player
var kills := 0
var elapsed := 0.0
var finished := false

var _flow_timer := 0.0
var _flow_origin := Vector2i(-1, -1)


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


func _ready() -> void:
	_build_grid()
	for n in get_tree().get_nodes_in_group("blockers"):
		for c in blocked_cells_of(n):
			set_walkable(c, false)
	player = get_tree().get_first_node_in_group("player")
	assert(player != null, "Level needs a Player (scenes/entities/player.tscn) under Entities")
	player.died.connect(_on_player_died)
	var bounds := Rect2(Vector2(origin * TILE), Vector2(width, height) * TILE)
	player.set_camera_limits(bounds)
	_recompute_flow()
	hud.setup(self)
	Sfx.start_ambience()
	hud.show_message(level_name + "  —  " + intro_text, 4.0)


func _physics_process(delta: float) -> void:
	if not finished:
		elapsed += delta
	_flow_timer -= delta
	if player and _flow_timer <= 0.0:
		_flow_timer = 0.2
		if world_to_cell(player.global_position) != _flow_origin:
			_recompute_flow()


# --- Grid ------------------------------------------------------------------------

func _build_grid() -> void:
	var rect := floor_layer.get_used_rect().merge(walls_layer.get_used_rect())
	origin = rect.position
	width = rect.size.x
	height = rect.size.y
	walkable.resize(width * height)
	for y in height:
		for x in width:
			var c := origin + Vector2i(x, y)
			var open := floor_layer.get_cell_source_id(c) != -1 and walls_layer.get_cell_source_id(c) == -1
			walkable[y * width + x] = 1 if open else 0


## Cells a blocker node occupies. Nodes can override with get_blocked_cells().
func blocked_cells_of(n: Node) -> Array[Vector2i]:
	if n.has_method("get_blocked_cells"):
		return n.get_blocked_cells()
	return [world_to_cell(n.global_position)]


func _index(c: Vector2i) -> int:
	var l := c - origin
	if l.x < 0 or l.y < 0 or l.x >= width or l.y >= height:
		return -1
	return l.y * width + l.x


func is_wall(c: Vector2i) -> bool:
	return walls_layer.get_cell_source_id(c) != -1


func is_walkable(c: Vector2i) -> bool:
	var i := _index(c)
	return i >= 0 and walkable[i] == 1


func set_walkable(c: Vector2i, value: bool) -> void:
	var i := _index(c)
	if i < 0:
		return
	walkable[i] = 1 if value else 0
	_flow_origin = Vector2i(-1, -1)


static func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


static func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + TILE * 0.5, c.y * TILE + TILE * 0.5)


# --- Alien navigation --------------------------------------------------------------

## Breadth-first distance field from the player's cell. Aliens walk downhill on it.
func _recompute_flow() -> void:
	if player == null:
		return
	var start := world_to_cell(player.global_position)
	_flow_origin = start
	flow.resize(width * height)
	flow.fill(FAR)
	var si := _index(start)
	if si < 0 or walkable[si] == 0:
		return
	var queue: Array[Vector2i] = [start]
	flow[si] = 0
	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		var dist := flow[_index(cur)] + 1
		for d in DIRS4:
			var n := cur + d
			var ni := _index(n)
			if ni >= 0 and walkable[ni] == 1 and flow[ni] > dist:
				flow[ni] = dist
				queue.append(n)


func flow_distance(c: Vector2i) -> int:
	var i := _index(c)
	if i < 0 or flow.is_empty():
		return FAR
	return flow[i]


## Direction an alien at `pos` should walk to get closer to the player.
func flow_direction(pos: Vector2) -> Vector2:
	var c := world_to_cell(pos)
	var best := c
	var best_dist := flow_distance(c)
	for d in DIRS8:
		var n := c + d
		if not is_walkable(n):
			continue
		# No cutting corners diagonally past walls.
		if d.x != 0 and d.y != 0 and (not is_walkable(c + Vector2i(d.x, 0)) or not is_walkable(c + Vector2i(0, d.y))):
			continue
		var nd := flow_distance(n)
		if nd < best_dist:
			best_dist = nd
			best = n
	if best == c:
		return Vector2.ZERO
	return (cell_center(best) - pos).normalized()


func has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(from, to, WALL_LAYER)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


# --- Events -------------------------------------------------------------------------

func on_alien_killed(_alien: Node) -> void:
	kills += 1
	Game.score += 100


func on_nest_destroyed() -> void:
	Game.score += 500
	hud.show_message("NEST DESTROYED", 2.0)


func on_exit_reached() -> void:
	if finished or player == null or player.dead:
		return
	finished = true
	player.frozen = true
	Game.score += player.health * 10
	Sfx.play("level_complete")
	hud.show_level_complete()


func _on_player_died() -> void:
	finished = true
	await get_tree().create_timer(1.6).timeout
	hud.show_game_over()


func shake(amount: float) -> void:
	if player:
		player.add_shake(amount)
