extends Control

@onready var floor_rect: TextureRect = $Floor
@onready var start_button: Button = $Center/VBox/Start

var _scroll := Vector2.ZERO


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Center/VBox/Start.pressed.connect(Game.start_new_game)
	$Center/VBox/Fullscreen.pressed.connect(Game.toggle_fullscreen)
	$Center/VBox/Quit.pressed.connect(get_tree().quit)
	start_button.grab_focus()


func _process(delta: float) -> void:
	# Slow diagonal drift of the floor; wrap at one tile so it never runs out.
	_scroll += Vector2(18, 10) * delta
	floor_rect.position = -Vector2(fposmod(_scroll.x, 64.0), fposmod(_scroll.y, 64.0)) - Vector2(64, 64)
