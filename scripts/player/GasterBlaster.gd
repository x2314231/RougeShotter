extends Node2D
## 每輪間隔觸發：依玩家 gaster_blaster_count 召喚多架 Blaster，彼此間隔 0.5 秒飛入。

const INTERVAL_SEC := 4.0
const BLASTER_STAGGER_SEC := 0.5
const SequenceScene := preload("res://scenes/player/GasterBlasterSequence.tscn")

var _player: CharacterBody2D
var _timer: float = INTERVAL_SEC
var _spawning: bool = false


func _ready() -> void:
	add_to_group("player_weapon")
	_player = get_parent() as CharacterBody2D


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if not _player.is_processing():
		return
	if _spawning:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_spawn_wave()


func _spawn_wave() -> void:
	_spawning = true
	var count: int = maxi(1, _player.gaster_blaster_count)
	for i in range(count):
		if i > 0:
			await get_tree().create_timer(BLASTER_STAGGER_SEC).timeout
		var seq := SequenceScene.instantiate()
		get_tree().current_scene.add_child(seq)
		seq.start(_player)
	_spawning = false
	_timer = INTERVAL_SEC
