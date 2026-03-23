extends Node
## 一次性音效（SFX）管理器
## 會嘗試載入 res://audio/sfx/ 下的音效；若檔案不存在則安靜跳過。

@export var sfx_volume_db: float = 6.0
@export var shoot_stream_path: String = "res://audio/sfx/player_shoot.ogg"
@export var player_hurt_stream_path: String = "res://audio/sfx/player_hurt.ogg"
@export var enemy_hurt_stream_path: String = "res://audio/sfx/enemy_hurt.ogg"
@export var enemy_die_stream_path: String = "res://audio/sfx/enemy_die.ogg"

var _shoot_stream: AudioStream
var _player_hurt_stream: AudioStream
var _enemy_hurt_stream: AudioStream
var _enemy_die_stream: AudioStream


func _ready() -> void:
	_shoot_stream = _load_stream_with_fallback(shoot_stream_path)
	_player_hurt_stream = _load_stream_with_fallback(player_hurt_stream_path)
	_enemy_hurt_stream = _load_stream_with_fallback(enemy_hurt_stream_path)
	_enemy_die_stream = _load_stream_with_fallback(enemy_die_stream_path)


func _load_stream_with_fallback(p: String) -> AudioStream:
	var s := load(p) as AudioStream
	if s != null:
		return s

	# 支援 ogg / wav / mp3 的副檔名 fallback
	var candidates: Array[String] = []
	if p.ends_with(".ogg"):
		candidates = [p.trim_suffix(".ogg") + ".wav", p.trim_suffix(".ogg") + ".mp3"]
	elif p.ends_with(".wav"):
		candidates = [p.trim_suffix(".wav") + ".ogg", p.trim_suffix(".wav") + ".mp3"]
	elif p.ends_with(".mp3"):
		candidates = [p.trim_suffix(".mp3") + ".ogg", p.trim_suffix(".mp3") + ".wav"]

	for alt in candidates:
		s = load(alt) as AudioStream
		if s != null:
			return s
	return s


func play_player_shoot(at: Vector2) -> void:
	_play(_shoot_stream, at)


func play_player_hurt(at: Vector2) -> void:
	_play(_player_hurt_stream, at)


func play_enemy_hurt(at: Vector2) -> void:
	_play(_enemy_hurt_stream, at)

func play_enemy_die(at: Vector2) -> void:
	_play(_enemy_die_stream, at)


func _play(stream: AudioStream, at: Vector2) -> void:
	if stream == null:
		return
	var p := AudioStreamPlayer2D.new()
	p.stream = stream
	p.volume_db = sfx_volume_db
	p.global_position = at
	# 使用預設 bus（通常是 Master），音量由 MainMenu 設定的 bus volume 影響
	add_child(p)
	p.play()
	# 釋放節點
	p.finished.connect(func(): p.queue_free())

