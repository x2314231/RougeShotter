extends Node2D
## 兩個矩形刀片繞玩家公轉，傷害等同玩家子彈。

const BULLET_LAYER := 8
const ENEMY_LAYER := 2
const ORBIT_RADIUS := 114.0 # 原 76 × 1.5
const ROT_SPEED := 2.75

var _blade_cd: Array[float] = [0.0, 0.0]
var _player: CharacterBody2D
## 世界空間公轉角（不受玩家瞄準旋轉影響）
var _world_orbit_angle: float = 0.0


func _ready() -> void:
	add_to_group("player_weapon")
	_player = get_parent() as CharacterBody2D
	if _player == null:
		return
	for i in 2:
		var a := Area2D.new()
		a.name = "Blade%d" % i
		a.collision_layer = BULLET_LAYER
		a.collision_mask = ENEMY_LAYER
		a.monitoring = true
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(26, 11)
		cs.shape = shape
		a.add_child(cs)
		a.position = Vector2(ORBIT_RADIUS, 0).rotated(float(i) * PI)
		a.body_entered.connect(func(b: Node): _on_blade_hit(b, i))
		add_child(a)
		var poly := Polygon2D.new()
		poly.color = Color(1.0, 1.0, 1.0, 0.95)
		poly.polygon = PackedVector2Array([
			Vector2(-13, -5), Vector2(13, -5), Vector2(13, 5), Vector2(-13, 5)
		])
		a.add_child(poly)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if not _player.is_processing():
		return
	global_position = _player.global_position
	_world_orbit_angle += ROT_SPEED * delta
	global_rotation = _world_orbit_angle
	for i in _blade_cd.size():
		_blade_cd[i] = maxf(0.0, _blade_cd[i] - delta)


func _on_blade_hit(body: Node, blade_idx: int) -> void:
	if _player == null:
		return
	if blade_idx >= 0 and blade_idx < _blade_cd.size() and _blade_cd[blade_idx] > 0.0:
		return
	if body == null or not body.is_in_group("enemy"):
		return
	if blade_idx >= 0 and blade_idx < _blade_cd.size():
		_blade_cd[blade_idx] = 0.18
	_player.deal_weapon_hit_to_enemy(body)
