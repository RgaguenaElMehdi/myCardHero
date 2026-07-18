extends Node
## Audio autoload: pooled SFX playback + looping music, driven by asset files
## under assets/audio/. Missing files fail silently (assets are generated).

const SFX_DIR := "res://assets/audio/sfx"
const MUSIC_DIR := "res://assets/audio/music"
const POOL_SIZE := 8

var _pool: Array[AudioStreamPlayer] = []
var _music := AudioStreamPlayer.new()
var _current_music := ""


func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_music.bus = "Master"
	add_child(_music)
	apply_settings()
	Game.profile_changed.connect(apply_settings)


func apply_settings() -> void:
	var settings: Dictionary = Game.profile.get("settings", {})
	var sfx_vol := float(settings.get("sfx_volume", 0.9))
	var music_vol := float(settings.get("music_volume", 0.8))
	for p in _pool:
		p.volume_db = linear_to_db(clampf(sfx_vol, 0.0001, 1.0))
	_music.volume_db = linear_to_db(clampf(music_vol * 0.8, 0.0001, 1.0))


func play_sfx(name: String) -> void:
	var path := "%s/%s.ogg" % [SFX_DIR, name]
	if not ResourceLoader.exists(path):
		path = "%s/%s.wav" % [SFX_DIR, name]
		if not ResourceLoader.exists(path):
			return
	for p in _pool:
		if not p.playing:
			p.stream = load(path)
			p.pitch_scale = randf_range(0.95, 1.05)
			p.play()
			return


func play_music(name: String) -> void:
	if _current_music == name:
		return
	var path := "%s/%s.ogg" % [MUSIC_DIR, name]
	if not ResourceLoader.exists(path):
		path = "%s/%s.wav" % [MUSIC_DIR, name]
		if not ResourceLoader.exists(path):
			return
	_current_music = name
	_music.stream = load(path)
	if _music.stream is AudioStreamWAV:
		(_music.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif _music.stream is AudioStreamOggVorbis:
		(_music.stream as AudioStreamOggVorbis).loop = true
	_music.play()


func stop_music() -> void:
	_current_music = ""
	_music.stop()
