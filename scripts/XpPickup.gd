extends Node2D

@export var value: int = 1

const GROUP_PLAYER := "player"
const GROUP_LEVEL_MANAGER := "level_manager"

func _ready() -> void:
	add_to_group("xp_pickup")

func _process(_delta: float) -> void:
	var players := get_tree().get_nodes_in_group(GROUP_PLAYER)
	if players.is_empty():
		return
	var player := players[0]

	var radius := 90.0
	if player.has_method("get_pickup_radius"):
		radius = player.get_pickup_radius()
	else:
		# 直接讀取屬性（若不存在則用預設）
		var r = player.get("pickup_radius")
		if typeof(r) == TYPE_FLOAT or typeof(r) == TYPE_INT:
			radius = float(r)

	if global_position.distance_squared_to(player.global_position) <= radius * radius:
		_collect()

func _collect() -> void:
	var managers := get_tree().get_nodes_in_group(GROUP_LEVEL_MANAGER)
	if not managers.is_empty():
		var lm = managers[0]
		if lm.has_method("add_score"):
			lm.add_score(value * 10)
	queue_free()
