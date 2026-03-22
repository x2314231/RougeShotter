extends Area2D
## 黃色柱狀雷射：存在一段時間內，以固定間隔對重疊敵人重複造成傷害（等同玩家子彈單次效果）。

var _player: Node

## 雷射總存在時間（秒）
const BEAM_DURATION_SEC := 0.55
## 傷害判定間隔（秒）— 數值越小命中越頻繁
const DAMAGE_TICK_INTERVAL_SEC := 0.12

var _elapsed_sec: float = 0.0
var _next_tick_at_sec: float = 0.0


func setup(p: Node) -> void:
	_player = p


func _ready() -> void:
	add_to_group("bullet")
	collision_layer = 8
	collision_mask = 2
	monitoring = true

	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(430.0, 12.0)
	cs.position = Vector2(shape.size.x * 0.5, 0.0)
	cs.shape = shape
	add_child(cs)

	var poly := Polygon2D.new()
	poly.color = Color(0.547, 0.998, 0.941, 0.9)
	poly.polygon = PackedVector2Array([
		Vector2(0, -30), Vector2(1430, -30), Vector2(1430, 30), Vector2(0, 30)
	])
	add_child(poly)

	# 等碰撞進入物理步驟後再開始計時與傷害
	await get_tree().physics_frame
	await get_tree().physics_frame
	_elapsed_sec = 0.0
	_next_tick_at_sec = 0.0
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		queue_free()
		return

	_elapsed_sec += delta

	while _next_tick_at_sec <= _elapsed_sec and _elapsed_sec <= BEAM_DURATION_SEC + 0.001:
		_apply_damage_tick()
		_next_tick_at_sec += DAMAGE_TICK_INTERVAL_SEC

	if _elapsed_sec >= BEAM_DURATION_SEC:
		queue_free()
		set_physics_process(false)


func _apply_damage_tick() -> void:
	for b in get_overlapping_bodies():
		if b.is_in_group("enemy"):
			_player.deal_weapon_hit_to_enemy(b)
