extends CharacterBody2D

@export var max_hp: int = 3
@export var move_speed: float = 0.0

var hp: int

const PLAYER_LAYER := 1
const ENEMY_LAYER := 2
const WALL_LAYER := 4
const BULLET_LAYER := 8

const GROUP_ENEMY := "enemy"

@onready var shape_color: Node2D = $Visual

func _ready() -> void:
	add_to_group(GROUP_ENEMY)
	hp = max_hp

	# 這個敵人是「用於顯示」與暫時測試用：讓玩家子彈能打到它
	collision_layer = ENEMY_LAYER
	collision_mask = BULLET_LAYER

func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		queue_free()

