extends CharacterBody2D

# 簡單敵人基礎類別：
# 1) 狀態機：追蹤(CHASE) / 攻擊(ATTACK)
# 2) 攻擊類型可透過旗標啟用：B(定距離射擊)、C(衝撞)、E(定時環形子彈)
# 3) 扣血：子彈命中 take_damage()、近戰以 HitArea 造成碰撞傷害

signal died(score_gained: int)

enum State { CHASE, ATTACK }
var state: State = State.CHASE

const PLAYER_LAYER := 1
const ENEMY_LAYER := 2
const WALL_LAYER := 4
const BULLET_LAYER := 8

const GROUP_PLAYER := "player"
const GROUP_ENEMY := "enemy"
const GROUP_WALL := "wall"

@export var enemy_color: Color = Color(1, 1, 1, 1)
@export var visual_radius: float = 18.0

@export var max_hp: int = 3
@export var move_speed: float = 100.0

@export var contact_damage: int = 1
@export var contact_cooldown: float = 0.35
var _contact_cd: float = 0.0

# 用於狀態切換
@export var melee_range: float = 70.0

# B：定距離射擊
@export var enable_ranged: bool = false
@export var ranged_range: float = 250.0
@export var ranged_interval: float = 1.2
@export var ranged_bullet_damage: int = 1
@export var ranged_bullet_speed: float = 320.0
@export var ranged_bullet_lifetime: float = 2.5
var _ranged_timer: float = 0.0

# C：近戰衝撞
@export var enable_dash: bool = false
@export var dash_speed_multiplier: float = 2.5
@export var dash_duration: float = 0.20
@export var dash_cooldown: float = 1.2
var _dash_timer: float = 0.0
var _dash_cd_timer: float = 0.0

# E：定時環形子彈
@export var enable_ring: bool = false
@export var ring_interval: float = 2.2
@export var ring_bullet_count: int = 10
@export var ring_bullet_damage: int = 1
@export var ring_bullet_speed: float = 260.0
@export var ring_bullet_lifetime: float = 2.5
var _ring_timer: float = 0.0

# 分數/掉落
@export var score_value: int = 10
@export var xp_value: int = 1

var hp: int
var _dead: bool = false

# ---------- 升級效果：DOT/擊退 ----------
var _dot_damage: int = 0
var _dot_time_left: float = 0.0
var _dot_tick_timer: float = 0.0
var _dot_tick_interval: float = 1.0

var _dot_flicker_timer: float = 0.0
var _dot_flicker_interval: float = 0.15
var _dot_flash_on: bool = true

var _knockback_vec: Vector2 = Vector2.ZERO
var _knockback_time_left: float = 0.0

@onready var visual: Node2D = $Visual
@onready var hit_area: Area2D = $HitArea

var _hurt_feedback_tween: Tween

const ENEMY_BULLET_SCENE := preload("res://scenes/bullets/EnemyBullet.tscn")

func _ready() -> void:
	add_to_group(GROUP_ENEMY)
	hp = max_hp

	# 設定視覺顏色
	if visual.has_method("set"):
		# DebugCircleVisual.gd 有填色變數，因此用 set 避免硬綁型別
		visual.set("radius", visual_radius)
		visual.set("fill_color", enemy_color)

	# 讓子彈能打到：enemy layer=2、mask 只吃 bullet layer=8
	collision_layer = ENEMY_LAYER
	collision_mask = BULLET_LAYER

	hit_area.collision_layer = ENEMY_LAYER
	hit_area.collision_mask = PLAYER_LAYER
	hit_area.body_entered.connect(_on_hit_area_body_entered)

	# 讓不同敵人的攻擊冷卻有初始偏移，避免同步出怪
	_ranged_timer = ranged_interval * randf_range(0.2, 1.0)
	_ring_timer = ring_interval * randf_range(0.2, 1.0)
	_dash_cd_timer = dash_cooldown * randf_range(0.0, 0.5)

func take_damage(amount: int) -> void:
	if _dead:
		return
	_play_hurt_feedback()
	hp -= amount
	if hp <= 0:
		_die()


func _play_hurt_feedback() -> void:
	if visual == null:
		return
	if _hurt_feedback_tween != null and _hurt_feedback_tween.is_valid():
		_hurt_feedback_tween.kill()
	var orig_pos: Vector2 = visual.position
	_hurt_feedback_tween = create_tween()
	_hurt_feedback_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 2-1 閃爍偏白
	_hurt_feedback_tween.tween_property(visual, "modulate", Color(1.85, 1.85, 1.85, 1.0), 0.05)
	_hurt_feedback_tween.tween_property(visual, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.09)
	# 2-2 視覺輕微位移震動
	_hurt_feedback_tween.tween_property(visual, "position", orig_pos + Vector2(4.0, -3.0), 0.035)
	_hurt_feedback_tween.tween_property(visual, "position", orig_pos + Vector2(-3.5, 3.5), 0.035)
	_hurt_feedback_tween.tween_property(visual, "position", orig_pos, 0.05)

func _die() -> void:
	if _dead:
		return
	_dead = true
	# 掉落經驗/得分：用撿取物件讓「磁鐵」升級後可測試
	_spawn_xp_pickup()
	died.emit(score_value)
	queue_free()

func _spawn_xp_pickup() -> void:
	var pickup_scene := preload("res://scenes/XpPickup.tscn")
	var p := pickup_scene.instantiate()
	p.global_position = global_position
	p.value = xp_value
	get_tree().current_scene.add_child(p)

func _physics_process(delta: float) -> void:
	_contact_cd = maxf(0.0, _contact_cd - delta)
	if _dash_timer > 0.0:
		_dash_timer = maxf(0.0, _dash_timer - delta)
	if _dash_cd_timer > 0.0:
		_dash_cd_timer = maxf(0.0, _dash_cd_timer - delta)

	if enable_ranged:
		_ranged_timer = maxf(0.0, _ranged_timer - delta)
	if enable_ring:
		_ring_timer = maxf(0.0, _ring_timer - delta)

	var player := _get_player()
	if player == null:
		return

	# DOT（持續傷害）：定時扣血
	if _dot_time_left > 0.0:
		_dot_time_left -= delta
		_dot_tick_timer -= delta
		_dot_flicker_timer -= delta

		# 閃爍效果：快速切換可見性
		if _dot_flicker_timer <= 0.0 and visual:
			_dot_flash_on = not _dot_flash_on
			visual.visible = _dot_flash_on
			_dot_flicker_timer = _dot_flicker_interval

		# 每秒扣 1 點生命
		if _dot_tick_timer <= 0.0:
			_dot_tick_timer = _dot_tick_interval
			# 規格要求：DOT 固定每秒扣 1 點生命（只在 DOT 尚未結束時扣血）
			if _dot_time_left > 0.0:
				take_damage(1)
	else:
		# DOT 結束後還原可見性
		if visual:
			visual.visible = true

	# 擊退：疊加移動向量
	if _knockback_time_left > 0.0:
		_knockback_time_left -= delta
		if _knockback_time_left <= 0.0:
			_knockback_vec = Vector2.ZERO
		else:
			_knockback_vec *= maxf(0.0, 1.0 - delta * 8.0)

	var to_player := player.global_position - global_position
	var dist := to_player.length()
	var dir := Vector2.ZERO
	if dist > 0.001:
		dir = to_player / dist

	# ---------- 狀態機 ----------
	if state == State.CHASE:
		if _should_enter_attack(dist):
			state = State.ATTACK
		# 追蹤移動
		velocity = dir * move_speed + _knockback_vec
		move_and_slide()
		return

	# ATTACK
	# 衝撞：持續期間強制移動（不靠近則不進入）
	if enable_dash and _dash_timer > 0.0:
		velocity = dir * move_speed * dash_speed_multiplier + _knockback_vec
		move_and_slide()
		if _dash_timer <= 0.0:
			state = State.CHASE
		return

	# 觸發攻擊動作
	_do_attack(dist, dir)

	# 若剛剛觸發衝撞，則維持 ATTACK 直到 dash 結束；否則射擊/環形為一次觸發後回追蹤。
	if enable_dash and _dash_timer > 0.0:
		state = State.ATTACK
		velocity = dir * move_speed * dash_speed_multiplier + _knockback_vec
	else:
		state = State.CHASE
		velocity = dir * move_speed + _knockback_vec
	move_and_slide()

func apply_dot(dmg: int, duration: float) -> void:
	# 規格要求：DOT 閃爍並「每秒扣 1 點生命」
	_dot_damage = 1
	_dot_time_left = maxf(_dot_time_left, duration)
	_dot_tick_timer = _dot_tick_interval
	_dot_flicker_timer = 0.0
	_dot_flash_on = true
	if visual:
		visual.visible = true

func apply_knockback(from_dir: Vector2, strength: float) -> void:
	_knockback_vec = from_dir.normalized() * strength
	_knockback_time_left = 0.25

func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group(GROUP_PLAYER)
	if players.is_empty():
		return null
	return players[0] as Node2D

func _should_enter_attack(dist: float) -> bool:
	# E：只要冷卻到就進攻（不受距離影響）
	if enable_ring and _ring_timer <= 0.0:
		return true

	# B：靠近距離且冷卻到才進攻
	if enable_ranged and dist <= ranged_range and _ranged_timer <= 0.0:
		return true

	# C：進入衝撞條件（距離足夠且衝撞冷卻結束）
	if enable_dash and dist <= melee_range and _dash_cd_timer <= 0.0:
		return true

	# A/D：靠近即可進入攻擊狀態（實際扣血在 HitArea）
	if not enable_ranged and not enable_ring and not enable_dash:
		return dist <= melee_range

	return dist <= melee_range

func _do_attack(dist: float, dir: Vector2) -> void:
	# 讓「B(射擊)」與「E(環形)」可以在同一個攻擊判定內同時觸發（Boss 需要）。
	var started_dash := false

	# C：衝撞開始（持續在 _physics_process 的 _dash_timer 期間處理移動）
	if enable_dash and dist <= melee_range and _dash_cd_timer <= 0.0:
		_dash_timer = dash_duration
		_dash_cd_timer = dash_cooldown
		started_dash = true

	# B：朝玩家射擊
	if enable_ranged and dist <= ranged_range and _ranged_timer <= 0.0:
		_shoot_bullet(dir, ranged_bullet_damage, ranged_bullet_speed, ranged_bullet_lifetime)
		_ranged_timer = ranged_interval

	# E：環形子彈（360 度 10 發）
	if enable_ring and _ring_timer <= 0.0:
		_shoot_ring(ring_bullet_damage, ring_bullet_speed, ring_bullet_lifetime, ring_bullet_count)
		_ring_timer = ring_interval

	if started_dash:
		# 衝撞期間由上層狀態分支處理移動，不在這裡額外追擊
		return

func _shoot_bullet(dir: Vector2, dmg: int, spd: float, life: float) -> void:
	var d := dir.normalized()
	var b := ENEMY_BULLET_SCENE.instantiate()
	# 沿發射方向外推，避免子彈生成在敵人碰撞體內與自身發生物理互推（非後座力設計）
	b.global_position = global_position + d * (visual_radius + 10.0)
	get_tree().current_scene.add_child(b)
	b.setup_enemy(self, d, dmg, spd, life)

func _shoot_ring(dmg: int, spd: float, life: float, count: int) -> void:
	# 360 度：十發間隔 36 度
	for i in range(count):
		var a := float(i) * TAU / float(count)
		var d := Vector2.RIGHT.rotated(a)
		_shoot_bullet(d, dmg, spd, life)

func _on_hit_area_body_entered(body: Node) -> void:
	if _contact_cd > 0.0:
		return
	if not body.is_in_group(GROUP_PLAYER):
		return

	_contact_cd = contact_cooldown
	if body.has_method("take_damage"):
		body.take_damage(contact_damage)
