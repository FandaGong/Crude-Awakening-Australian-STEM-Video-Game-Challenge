extends Node

enum Music { NONE, WATER, LAND, BOSS }

const SFX_PATHS := {
	"button_click": "res://assets/soundEffects/button_click.mp3",
	"land_movement": "res://assets/soundEffects/otter_above_ground_movement.mp3",
	"swimming": "res://assets/soundEffects/otter_swimming.mp3",
	"otter_hit": "res://assets/soundEffects/otter_hit.mp3",
	"robot_shoot": "res://assets/soundEffects/robot_shoot.mp3",
	"splash": "res://assets/soundEffects/splash.mp3",
}

const MUSIC_PATHS := {
	Music.WATER: "res://assets/Music BGM /game-music-for-ocean-exploration-loop-fantagong.mp3",
	Music.LAND: "res://assets/Music BGM /Gamemusic-beach-loop_–_fantagong.mp3",
	Music.BOSS: "res://assets/Music BGM /Gamemusc-bossfight_–_fantagong.mp3",
}

var sfx_enabled: bool = true
var music_enabled: bool = true
var master_volume := 1.0
var music_volume := 1.0
var sfx_volume := 1.0

var _sfx_players: Dictionary = {}
var _music_player: AudioStreamPlayer
var _music_streams: Dictionary = {}
var _current_music: int = Music.NONE

func _ready() -> void:
	for sfx_name in SFX_PATHS:
		if not ResourceLoader.exists(SFX_PATHS[sfx_name]):
			continue
		var player := AudioStreamPlayer.new()
		player.stream = load(SFX_PATHS[sfx_name])
		add_child(player)
		_sfx_players[sfx_name] = player

	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)
	for track in MUSIC_PATHS:
		if not ResourceLoader.exists(MUSIC_PATHS[track]):
			continue
		var stream: AudioStream = load(MUSIC_PATHS[track])
		if stream is AudioStreamMP3:
			stream.loop = true
		_music_streams[track] = stream

func play_sfx(sfx_name: String) -> void:
	if not sfx_enabled:
		return
	var player: AudioStreamPlayer = _sfx_players.get(sfx_name)
	if player:
		player.play()

func stop_sfx(sfx_name: String) -> void:
	var player: AudioStreamPlayer = _sfx_players.get(sfx_name)
	if player:
		player.stop()

func play_music(track: int) -> void:
	if track == _current_music:
		return
	_current_music = track
	if music_enabled:
		_apply_music_track()

func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	if enabled:
		_apply_music_track()
	else:
		_music_player.stop()

func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()

func _apply_volumes() -> void:
	_music_player.volume_db = linear_to_db(maxf(0.001, master_volume * music_volume))
	for player: AudioStreamPlayer in _sfx_players.values():
		player.volume_db = linear_to_db(maxf(0.001, master_volume * sfx_volume))

func _apply_music_track() -> void:
	var stream: AudioStream = _music_streams.get(_current_music)
	if not stream:
		_music_player.stop()
		return
	_music_player.stream = stream
	_music_player.play()
