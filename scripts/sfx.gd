extends Node
## Sound effects + ambience. Autoloaded as "Sfx".
##
##   Sfx.play("shoot")                 # non-positional (player, UI)
##   Sfx.play_at("alien_die", pos)     # positional, fades with distance from the camera
##
## To change which file plays for an event, edit SOUNDS below. Several files per
## event are picked at random. Mix levels live on the SFX / UI / Ambience buses
## (Audio panel at the bottom of the editor).

const DIR := "res://assets/audio effects/"

## event: { files, volume (dB), pitch (base), jitter (± random pitch), gap (min seconds between plays) }
const SOUNDS := {
	# Player / weapon
	"shoot": {"files": ["Weapons/shot_muffled.wav"], "volume": -6.0, "pitch": 1.15, "jitter": 0.08},
	"reload_start": {"files": ["Weapons/weapon_unequip.wav"], "volume": -4.0},
	"reload_done": {"files": ["Weapons/weapon_equip_short.wav"], "volume": -3.0},
	"empty": {"files": ["Environment/lock_quick.wav"], "volume": -6.0, "pitch": 1.4, "gap": 0.25},
	"player_hurt": {"files": ["Combat and Gore/punch.wav", "Combat and Gore/punch_2.wav", "Combat and Gore/punch_3.wav"], "volume": -4.0, "jitter": 0.1, "gap": 0.15},
	"player_die": {"files": ["Combat and Gore/bone_snap.wav"], "volume": 0.0, "pitch": 0.85},
	"bullet_wall": {"files": ["Weapons/sword_clash.wav", "Weapons/sword_clash_2.wav"], "volume": -22.0, "pitch": 1.8, "jitter": 0.2, "gap": 0.07},

	# Aliens / nests
	"alien_hit": {"files": ["Combat and Gore/splat_quick.wav", "Combat and Gore/squelching_1.wav", "Combat and Gore/squelching_2.wav"], "volume": -10.0, "jitter": 0.15, "gap": 0.05},
	"alien_die": {"files": ["Combat and Gore/crunch_splat.wav", "Combat and Gore/crunch_splat_2.wav", "Combat and Gore/splat_double_quick.wav"], "volume": -3.0, "jitter": 0.12},
	"alien_attack": {"files": ["Combat and Gore/swipe.wav"], "volume": -6.0, "jitter": 0.15, "gap": 0.1},
	"nest_spawn": {"files": ["Environment/gurgling.wav", "Combat and Gore/squelching_3.wav"], "volume": -8.0, "pitch": 0.7, "jitter": 0.1},
	"nest_hit": {"files": ["Combat and Gore/squelching_4.wav", "Combat and Gore/squelching_2.wav"], "volume": -12.0, "pitch": 0.8, "jitter": 0.1, "gap": 0.08},
	"nest_die": {"files": ["Combat and Gore/crunch.wav"], "volume": 0.0, "pitch": 0.6},

	# World
	"explosion": {"files": ["Weapons/harsh_thud.wav"], "volume": 2.0, "pitch": 0.55, "jitter": 0.08},
	"explosion_tail": {"files": ["Environment/air_burst.wav"], "volume": -2.0, "pitch": 0.6, "jitter": 0.08},
	"door_open": {"files": ["Environment/air_burst.wav"], "volume": -4.0, "pitch": 1.2},
	"door_unlock": {"files": ["Environment/lock_unlock.wav"], "volume": -2.0},
	"door_locked": {"files": ["Environment/lock_lock.wav"], "volume": -4.0},

	# Pickups
	"pickup_ammo": {"files": ["Weapons/weapon_pick_up.wav"], "volume": -3.0},
	"pickup_health": {"files": ["Environment/zipper_up.wav"], "volume": -4.0, "pitch": 1.2},
	"pickup_key": {"files": ["Weapons/weapon_upgrade.wav"], "volume": -3.0, "pitch": 1.2},
	"pickup_credits": {"files": ["Environment/water_drop_synthetic.wav"], "volume": -4.0, "pitch": 1.3, "jitter": 0.1},
	"level_complete": {"files": ["Weapons/weapon_upgrade.wav"], "volume": 0.0, "pitch": 0.8},

	# UI
	"ui_move": {"files": ["Environment/clock_tick_only.wav"], "volume": -8.0, "bus": "UI", "gap": 0.04},
	"ui_select": {"files": ["Weapons/weapon_equip_short.wav"], "volume": -6.0, "bus": "UI"},
}

## Looping background layers for levels: [file, volume dB, pitch].
const AMBIENCE := [
	["Environment/ambient_wind.wav", -16.0, 0.7],
	["Environment/water_dripping.wav", -24.0, 1.0],
]

## Positional sounds are inaudible beyond this distance (world pixels).
const MAX_DISTANCE := 1600.0

var _streams := {}  # event -> Array[AudioStream]
var _last_played := {}  # event -> time (sec)
var _players := {}  # event -> AudioStreamPlayer (non-positional, polyphonic)
var _ambience: Array[AudioStreamPlayer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for event in SOUNDS:
		var list: Array[AudioStream] = []
		for f in SOUNDS[event].files:
			var s: AudioStream = load(DIR + f)
			if s:
				list.append(s)
			else:
				push_warning("Sfx: missing sound file " + DIR + f)
		_streams[event] = list
	# Every Button in the game gets move/select sounds automatically.
	get_tree().node_added.connect(_on_node_added)


func play(event: String) -> void:
	var cfg: Dictionary = _ready_to_play(event)
	if cfg.is_empty():
		return
	var p: AudioStreamPlayer = _players.get(event)
	if p == null:
		p = AudioStreamPlayer.new()
		p.max_polyphony = 6
		p.bus = cfg.get("bus", "SFX")
		add_child(p)
		_players[event] = p
	p.stream = _streams[event].pick_random()
	p.volume_db = cfg.get("volume", 0.0)
	p.pitch_scale = _pitch(cfg)
	p.play()


func play_at(event: String, pos: Vector2) -> void:
	var cfg: Dictionary = _ready_to_play(event)
	if cfg.is_empty():
		return
	var parent := get_tree().current_scene
	if parent == null:
		return
	var p := AudioStreamPlayer2D.new()
	p.stream = _streams[event].pick_random()
	p.volume_db = cfg.get("volume", 0.0)
	p.pitch_scale = _pitch(cfg)
	p.bus = cfg.get("bus", "SFX")
	p.max_distance = MAX_DISTANCE
	p.attenuation = 1.6
	p.position = pos
	p.finished.connect(p.queue_free)
	parent.add_child(p)
	p.play()


func start_ambience() -> void:
	stop_ambience()
	for layer in AMBIENCE:
		var p := AudioStreamPlayer.new()
		p.stream = load(DIR + layer[0])
		p.volume_db = layer[1]
		p.pitch_scale = layer[2]
		p.bus = "Ambience"
		# Loop by restarting, so the .wav import settings don't need touching.
		p.finished.connect(p.play)
		add_child(p)
		p.play(randf() * 2.0)
		_ambience.append(p)


func stop_ambience() -> void:
	for p in _ambience:
		p.queue_free()
	_ambience.clear()


func _ready_to_play(event: String) -> Dictionary:
	if not SOUNDS.has(event) or _streams[event].is_empty():
		return {}
	var cfg: Dictionary = SOUNDS[event]
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_played.get(event, -100.0) < cfg.get("gap", 0.0):
		return {}
	_last_played[event] = now
	return cfg


func _pitch(cfg: Dictionary) -> float:
	var j: float = cfg.get("jitter", 0.0)
	return cfg.get("pitch", 1.0) * randf_range(1.0 - j, 1.0 + j)


func _on_node_added(node: Node) -> void:
	if node is Button:
		node.focus_entered.connect(play.bind("ui_move"))
		node.mouse_entered.connect(play.bind("ui_move"))
		node.pressed.connect(play.bind("ui_select"))
