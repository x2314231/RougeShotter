extends CharacterBody2D

const PLAYER_LAYER := 1
const ENEMY_LAYER := 2
const WALL_LAYER := 4
const BULLET_LAYER := 8

const GROUP_WALL := "wall"
const GROUP_ENEMY := "enemy"
const GROUP_PLAYER := "player"

var bullet_owner: String = "player" # "player" or "enemy"
var direction: Vector2 = Vector2.RIGHT
var speed: float = 650.0
var damage: int = 1

var penetration_left: int = 0 # 可穿透剩餘次數（擊中目標後遞減；未穿透為0）
var bounce_left: int = 0 # 反彈剩餘次數

var lifetime: float = 2.0
var _age: float = 0.0

# 之後升級用（DOT/擊退等），第一步先保留接口
var dot_damage: int = 0
var dot_duration: float = 0.0
var knockback_strength: float = 0.0

func _ready() -> void:
	# 子彈只需要跟指定 layer 碰撞即可
	collision_layer = BULLET_LAYER
	add_to_group("bullet")

func setup(
		shooter_owner: String,
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
	self.bullet_owner = shooter_owner
	self.direction = p_direction.normalized()
	self.damage = p_damage
	self.speed = p_speed
	self.lifetime = p_lifetime
	self.penetration_left = p_penetration_left
	self.bounce_left = p_bounce_left
	self.dot_damage = p_dot_damage
	self.dot_duration = p_dot_duration
	self.knockback_strength = p_knockback_strength

	rotation = self.direction.angle()

	# Player 子彈：打敵人 + 牆面；Enemy 子彈：打玩家 + 牆面
	if bullet_owner == "player":
		collision_mask = ENEMY_LAYER | WALL_LAYER
	else:
		collision_mask = PLAYER_LAYER | WALL_LAYER

	velocity = self.direction * self.speed

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	# 用 move_and_collide 取得碰撞法線（之後彈跳會用到）
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

	# 牆面碰撞：本版本的「彈跳」改成鏈式打下一個目標，所以牆面就直接消失
	if collider.is_in_group(GROUP_WALL):
		queue_free()
		return

	# 依子彈持有者判斷要打誰
	if bullet_owner == "player":
		if collider.is_in_group(GROUP_ENEMY):
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
	# 讓子彈在命中後「從命中目標」重新定向到下一個目標
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
		# 僅鏈到仍可被扣血的目標
		if not c.has_method("take_damage"):
			continue

		var pos := (c as Node2D).global_position
		var d := pos.distance_squared_to(from_pos)
		if d < best_dist_sq:
			best_dist_sq = d
			best = c as Node2D

	if best == null:
		return false

	# 成功鏈式彈跳：扣除一次彈跳並重新導向
	bounce_left -= 1
	var new_dir := (best.global_position - from_pos)
	if new_dir.length_squared() <= 0.0001:
		return false
	new_dir = new_dir.normalized()

	direction = new_dir
	velocity = direction * speed
	rotation = direction.angle()
	# 從命中點略微往外偏移，避免立刻再次撞到同一個目標
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
