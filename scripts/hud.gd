class_name Hud
extends CanvasLayer
## In-game HUD, crosshair, and the pause / game over / level complete overlays.

@onready var health_bar: ProgressBar = %HealthBar
@onready var ammo_label: Label = %AmmoLabel
@onready var keys_label: Label = %KeysLabel
@onready var credits_label: Label = %CreditsLabel
@onready var nests_label: Label = %NestsLabel
@onready var score_label: Label = %ScoreLabel
@onready var message_label: Label = %Message
@onready var crosshair: Crosshair = %Crosshair
@onready var overlay: Control = %Overlay
@onready var overlay_title: Label = %OverlayTitle
@onready var overlay_info: Label = %OverlayInfo
@onready var buttons: Array[Button] = [%Button1, %Button2, %Button3]

var level: Level
var _actions: Array[Callable] = []
var _message_time := 0.0
var _overlay_mode := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.visible = false
	message_label.modulate.a = 0.0
	for i in buttons.size():
		var idx := i
		buttons[i].pressed.connect(func() -> void: _on_button(idx))
	Game.input_device_changed.connect(func(_g: bool) -> void: _update_mouse_mode())


func setup(lvl: Level) -> void:
	level = lvl
	level.player.stats_changed.connect(_refresh)
	_refresh()
	_update_mouse_mode()


func _process(delta: float) -> void:
	if _message_time > 0.0:
		_message_time -= delta
		message_label.modulate.a = clampf(_message_time * 2.0, 0.0, 1.0)
	crosshair.visible = not overlay.visible and not Game.using_gamepad
	crosshair.position = crosshair.get_viewport().get_mouse_position()
	if level:
		score_label.text = "SCORE  %06d" % Game.score
		nests_label.text = "NESTS  %d" % get_tree().get_node_count_in_group("nests")
		if level.player:
			crosshair.reloading = level.player.is_reloading()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _overlay_mode == "pause":
			_resume()
		elif _overlay_mode == "" and not level.finished:
			show_pause()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	var p := level.player
	health_bar.max_value = p.max_health
	health_bar.value = p.health
	ammo_label.text = "AMMO  %02d / %d%s" % [p.mag, p.reserve_ammo, "  RELOADING" if p.is_reloading() else ""]
	keys_label.text = "KEYS  %d" % p.keys
	credits_label.text = "CREDITS  %d" % p.credits


func show_message(text: String, duration := 2.0) -> void:
	message_label.text = text
	_message_time = duration
	message_label.modulate.a = 1.0


func show_pause() -> void:
	_show_overlay("pause", "PAUSED", "", ["RESUME", "RESTART LEVEL", "MAIN MENU"],
		[_resume, Game.restart_level, Game.go_to_menu])


func show_game_over() -> void:
	_show_overlay("gameover", "YOU DIED", "Score  %06d" % Game.score, ["TRY AGAIN", "MAIN MENU"],
		[Game.restart_level, Game.go_to_menu])


func show_level_complete() -> void:
	var t := int(level.elapsed)
	var info := "Time  %d:%02d\nAliens killed  %d\nCredits  %d\nScore  %06d" % [
		t / 60, t % 60, level.kills, level.player.credits, Game.score]
	_show_overlay("complete", "LEVEL COMPLETE", info, ["CONTINUE", "MAIN MENU"],
		[Game.next_level.bind(level.next_level), Game.go_to_menu])


func _show_overlay(mode: String, title: String, info: String, labels: Array, actions: Array) -> void:
	_overlay_mode = mode
	get_tree().paused = true
	overlay.visible = true
	overlay_title.text = title
	overlay_info.text = info
	overlay_info.visible = info != ""
	_actions.clear()
	for i in buttons.size():
		buttons[i].visible = i < labels.size()
		if i < labels.size():
			buttons[i].text = labels[i]
			_actions.append(actions[i])
	buttons[0].grab_focus()
	_update_mouse_mode()


func _resume() -> void:
	_overlay_mode = ""
	overlay.visible = false
	get_tree().paused = false
	_update_mouse_mode()


func _on_button(i: int) -> void:
	if i < _actions.size():
		_actions[i].call()


func _update_mouse_mode() -> void:
	if overlay.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if not Game.using_gamepad else Input.MOUSE_MODE_HIDDEN
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
