extends Node
## Global game state + helpers. Autoloaded as "Game".

const MENU_SCENE := "res://scenes/menu.tscn"
## Levels started from the menu. Further levels are chained via each Level's "Next Level" property.
const LEVELS := ["res://scenes/levels/level_1.tscn"]

const ASSET_DIR := "res://assets/Topdown Shooter/"
const TILESHEET_2X := ASSET_DIR + "Tilesheet/tilesheet_complete_2X.png"

signal input_device_changed(using_gamepad: bool)

## True when the last meaningful input came from a controller.
var using_gamepad := false

var current_level := 0
var current_level_path := ""
var score := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_add_stick_to_ui_actions()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen") or (event is InputEventKey and event.pressed and event.keycode == KEY_ENTER and event.alt_pressed):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return

	var gamepad := using_gamepad
	if event is InputEventJoypadButton:
		gamepad = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.4:
		gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		gamepad = false
	elif event is InputEventMouseMotion and event.relative.length() > 2.0:
		gamepad = false
	if gamepad != using_gamepad:
		using_gamepad = gamepad
		input_device_changed.emit(using_gamepad)


func toggle_fullscreen() -> void:
	var win := get_window()
	if win.mode == Window.MODE_FULLSCREEN or win.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		win.mode = Window.MODE_WINDOWED
	else:
		win.mode = Window.MODE_FULLSCREEN


func start_new_game() -> void:
	score = 0
	current_level = 0
	load_level(current_level)


func load_level(index: int) -> void:
	current_level = index
	current_level_path = LEVELS[index]
	get_tree().paused = false
	get_tree().change_scene_to_file(LEVELS[index])


func next_level(path := "") -> void:
	if path == "":
		go_to_menu()
		return
	current_level_path = path
	get_tree().paused = false
	get_tree().change_scene_to_file(path)


func restart_level() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func go_to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MENU_SCENE)


## Returns a region (in 64px tile units) of the Kenney tilesheet, taken from the 2X sheet.
## Use with a node scale of 0.5 so it covers one 64px world tile at double resolution.
func tile_texture(col: int, row: int, size := Vector2i.ONE) -> AtlasTexture:
	var tex := AtlasTexture.new()
	tex.atlas = load(TILESHEET_2X)
	tex.region = Rect2(col * 128, row * 128, size.x * 128, size.y * 128)
	return tex


## Godot's default ui_* actions only know the d-pad; let the left stick drive menus too.
func _add_stick_to_ui_actions() -> void:
	var map := {
		"ui_left": [JOY_AXIS_LEFT_X, -1.0],
		"ui_right": [JOY_AXIS_LEFT_X, 1.0],
		"ui_up": [JOY_AXIS_LEFT_Y, -1.0],
		"ui_down": [JOY_AXIS_LEFT_Y, 1.0],
	}
	for action in map:
		var ev := InputEventJoypadMotion.new()
		ev.device = -1
		ev.axis = map[action][0]
		ev.axis_value = map[action][1]
		InputMap.action_add_event(action, ev)
		InputMap.action_set_deadzone(action, 0.5)
