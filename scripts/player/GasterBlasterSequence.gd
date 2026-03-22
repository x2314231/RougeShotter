extends Node2D
## 從畫面外飛入玩家 → 對最近 3 敵發射雷射 → 飛出畫面外消滅

const LaserBeamScript := preload("res://scripts/player/LaserBeam.gd")

const MOVE_IN_SEC := 1.00
const MOVE_OUT_SEC := 1.00
const FIRE_DELAY_SEC := 1.0

var _player: Node2D
var _triangle: Polygon2D


func _ready() -> void:
	add_to_group("player_weapon")
	_triangle = Polygon2D.new()
	_triangle.color = Color(1.0, 1.0, 1.0, 0.96)
	_triangle.polygon = PackedVector2Array([
		Vector2(22, 0), Vector2(-14, 18.5), Vector2(-14, -18.5)
	])
	add_child(_triangle)


func start(player: Node2D) -> void:
	_player = player
	if _player == null or not is_instance_valid(_player):
		queue_free()
		return
	await _execute_sequence()
	queue_free()


func _execute_sequence() -> void:
	var from_pos: Vector2 = _random_offscreen_point()
	var to_pos: Vector2 = _player.global_position
	global_position = from_pos
	rotation = (to_pos - from_pos).angle()

	var tw_in := create_tween()
	tw_in.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var move_in := func(tt: float) -> void:
		var p: float = clampf(tt, 0.0, 1.0)
		global_position = from_pos.lerp(to_pos, p)
		var dir: Vector2 = to_pos - global_position
		if dir.length_squared() > 1.0:
			rotation = dir.angle()
	tw_in.tween_method(move_in, 0.0, 1.0, MOVE_IN_SEC)
	await tw_in.finished

	global_position = to_pos
	_fire_three_lasers()

	await get_tree().create_timer(FIRE_DELAY_SEC).timeout

	var exit_pos: Vector2 = _random_offscreen_point()
	var start_exit: Vector2 = global_position
	var tw_out := create_tween()
	tw_out.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var move_out := func(tt: float) -> void:
		var p2: float = clampf(tt, 0.0, 1.0)
		global_position = start_exit.lerp(exit_pos, p2)
		var dir2: Vector2 = exit_pos - global_position
		if dir2.length_squared() > 1.0:
			rotation = dir2.angle()
	tw_out.tween_method(move_out, 0.0, 1.0, MOVE_OUT_SEC)
	await tw_out.finished


func _random_offscreen_point() -> Vector2:
	var cam: Camera2D = get_viewport().get_camera_2d()
	var center: Vector2 = Vector2.ZERO
	var half_ext: Vector2 = Vector2(400, 300)
	if cam != null:
		center = cam.get_screen_center_position()
		half_ext = get_viewport().get_visible_rect().size * 0.5 / cam.zoom
	var margin := 200.0
	var ang: float = randf() * TAU
	var dist: float = maxf(half_ext.x, half_ext.y) + margin + randf_range(120.0, 420.0)
	return center + Vector2.RIGHT.rotated(ang) * dist


func _fire_three_lasers() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var targets: Array[Node2D] = _nearest_enemies(1)
	for enemy in targets:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var d: Vector2 = enemy.global_position - global_position
		if d.length_squared() < 0.0001:
			continue
		d = d.normalized()
		var beam: Area2D = LaserBeamScript.new() as Area2D
		beam.setup(_player)
		get_tree().current_scene.add_child(beam)
		beam.global_position = global_position
		beam.global_rotation = d.angle()


func _nearest_enemies(count: int) -> Array[Node2D]:
	var arr: Array[Node2D] = []
	for n in get_tree().get_nodes_in_group("enemy"):
		if n != null and n is Node2D:
			arr.append(n as Node2D)
	var origin: Vector2 = global_position
	arr.sort_custom(
		func(a: Node2D, b: Node2D) -> bool:
			return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
	)
	var out: Array[Node2D] = []
	for i in range(mini(count, arr.size())):
		out.append(arr[i])
	return out
