extends Node2D
## 多個矩形刀片繞玩家公轉，傷害等同玩家子彈。

const BULLET_LAYER := 8
const ENEMY_LAYER := 2
const ORBIT_RADIUS := 114.0 # 原 76 × 1.5
const ROT_SPEED := 2.75

# 初次取得技能時保持原本行為：2 把刀片。
const DEFAULT_BLADE_COUNT := 2

var _blade_cd: Array[float] = []
var _blade_count: int = DEFAULT_BLADE_COUNT
var _player: CharacterBody2D
## 世界空間公轉角（不受玩家瞄準旋轉影響）
var _world_orbit_angle: float = 0.0

var _ready_done: bool = false


func _ready() -> void:
	add_to_group("player_weapon")
	_player = get_parent() as CharacterBody2D
	if _player == null:
		return
	_ready_done = true
	_rebuild_blades()


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


## Player 升級會呼叫：刀片數量增加（每次 +1）。
func set_blade_count(count: int) -> void:
	var c := maxi(1, int(count))
	if c == _blade_count:
		return
	_blade_count = c
	if _ready_done:
		_rebuild_blades()


func _rebuild_blades() -> void:
	# 清掉舊刀片，避免升級後重複碰撞/多次傷害
	var to_free: Array[Node] = []
	for child in get_children():
		if child is Area2D:
			to_free.append(child)
	for n in to_free:
		n.free()

	_blade_cd.clear()
	for _i in range(_blade_count):
		_blade_cd.append(0.0)

	for i in range(_blade_count):
		var idx := i
		var a := Area2D.new()
		a.name = "Blade%d" % idx
		a.collision_layer = BULLET_LAYER
		a.collision_mask = ENEMY_LAYER
		a.monitoring = true

		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(26, 11)
		cs.shape = shape
		a.add_child(cs)

		# 把刀片平均分佈在圓周上
		var ang := float(idx) * TAU / float(_blade_count)
		a.position = Vector2(ORBIT_RADIUS, 0).rotated(ang)
		a.body_entered.connect(func(b: Node): _on_blade_hit(b, idx))
		add_child(a)

		var poly := Polygon2D.new()
		poly.color = Color(1.0, 1.0, 1.0, 0.95)
		poly.polygon = PackedVector2Array([
			Vector2(-13, -5), Vector2(13, -5), Vector2(13, 5), Vector2(-13, 5)
		])
		a.add_child(poly)


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
