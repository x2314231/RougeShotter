extends CharacterBody2D
class_name BulletBase
## 子彈共用邏輯：玩家子彈與敵方子彈皆繼承此類別。

const PLAYER_LAYER := 1
const ENEMY_LAYER := 2
const WALL_LAYER := 4
const BULLET_LAYER := 8

const GROUP_WALL := "wall"
const GROUP_ENEMY := "enemy"
const GROUP_PLAYER := "player"

var bullet_owner: String = "player" # "player" or "enemy"
## 敵方子彈：發射者，用於碰撞例外（避免與自身子彈互撞造成位移）
var shooter_node: Node2D = null

var direction: Vector2 = Vector2.RIGHT
var speed: float = 650.0
var damage: int = 1

var penetration_left: int = 0
var bounce_left: int = 0

var lifetime: float = 2.0
var _age: float = 0.0

var dot_damage: int = 0
var dot_duration: float = 0.0
var knockback_strength: float = 0.0

## 玩家子彈：已造成過傷害的敵人（避免穿透／停留時每幀重複命中）；彈跳時亦不再選這些目標
var _damaged_enemy_ids: Array[int] = []

func _ready() -> void:
	collision_layer = BULLET_LAYER
	add_to_group("bullet")


func _internal_setup(
		owner_type: String,
		shooter: Node2D,
		p_direction: Vector2,
		p_damage: int,
		p_speed: float,
		p_lifetime: float = 2.0,
		p_penetration_left: int = 0,
		p_bounce_left: int = 0,
		p_dot_damage: int = 0,
		p_dot_duration: float = 0.0,
		p_knockback_strength: float = 0.0
	) -> void:
	bullet_owner = owner_type
	shooter_node = shooter
	direction = p_direction.normalized()
	damage = p_damage
	speed = p_speed
	lifetime = p_lifetime
	penetration_left = p_penetration_left
	bounce_left = p_bounce_left
	dot_damage = p_dot_damage
	dot_duration = p_dot_duration
	knockback_strength = p_knockback_strength

	rotation = direction.angle()

	if bullet_owner == "player":
		collision_mask = ENEMY_LAYER | WALL_LAYER
	else:
		collision_mask = PLAYER_LAYER | WALL_LAYER

	velocity = direction * speed

	# 敵人 collision_mask 含 BULLET_LAYER，子彈與發射者會互撞 → 必須加例外（延遲到本節點已在樹上）
	if bullet_owner == "enemy" and is_instance_valid(shooter_node):
		call_deferred("_add_shooter_collision_exception")


func _add_shooter_collision_exception() -> void:
	if is_instance_valid(shooter_node):
		add_collision_exception_with(shooter_node)


func _apply_visual_color(c: Color) -> void:
	var v := get_node_or_null("Visual")
	if v != null and v.has_method("set"):
		v.set("fill_color", c)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	var col := move_and_collide(velocity * delta)
	if col == null:
		return

	var collider := col.get_collider()
	var normal := col.get_normal()

	_handle_hit(collider, normal)


func _handle_hit(collider: Object, normal: Vector2) -> void:
	if collider == null:
		queue_free()
		return

	if collider.is_in_group(GROUP_WALL):
		queue_free()
		return

	if bullet_owner == "player":
		if collider.is_in_group(GROUP_ENEMY):
			var eid: int = collider.get_instance_id()
			if eid in _damaged_enemy_ids:
				return
			_damaged_enemy_ids.append(eid)
			if collider is CollisionObject2D:
				add_collision_exception_with(collider as CollisionObject2D)
			_apply_damage(collider)
			_apply_effects(collider)
			if _try_chain_bounce(collider, GROUP_ENEMY):
				return
		queue_free_or_penetrate()
		return
	else:
		if collider.is_in_group(GROUP_PLAYER):
			_apply_damage(collider)
			_apply_effects(collider)
			if _try_chain_bounce(collider, GROUP_PLAYER):
				return
		queue_free_or_penetrate()
		return


func queue_free_or_penetrate() -> void:
	if penetration_left > 0:
		penetration_left -= 1
		return
	queue_free()


func _try_chain_bounce(hit_target: Object, target_group: String) -> bool:
	if bounce_left <= 0:
		return false
	if hit_target == null:
		return false
	if not (hit_target is Node2D):
		return false

	var from_pos: Vector2 = (hit_target as Node2D).global_position

	var candidates := get_tree().get_nodes_in_group(target_group)
	if candidates.is_empty():
		return false

	var best: Node2D = null
	var best_dist_sq: float = INF

	for c in candidates:
		if c == null:
			continue
		if c == hit_target:
			continue
		if not (c is Node2D):
			continue
		if not c.has_method("take_damage"):
			continue
		if c.get_instance_id() in _damaged_enemy_ids:
			continue

		var pos := (c as Node2D).global_position
		var d := pos.distance_squared_to(from_pos)
		if d < best_dist_sq:
			best_dist_sq = d
			best = c as Node2D

	if best == null:
		return false

	bounce_left -= 1
	var new_dir := (best.global_position - from_pos)
	if new_dir.length_squared() <= 0.0001:
		return false
	new_dir = new_dir.normalized()

	direction = new_dir
	velocity = direction * speed
	rotation = direction.angle()
	global_position = from_pos + direction * 6.0
	return true


func _apply_damage(target: Object) -> void:
	if not target.has_method("take_damage"):
		return
	target.take_damage(damage)


func _apply_effects(target: Object) -> void:
	if dot_damage > 0 and target.has_method("apply_dot"):
		target.apply_dot(dot_damage, dot_duration)
	if knockback_strength > 0 and target.has_method("apply_knockback"):
		target.apply_knockback(direction, knockback_strength)
