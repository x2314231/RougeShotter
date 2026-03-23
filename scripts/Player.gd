extends CharacterBody2D

# ========= 基礎屬性 =========
signal hp_changed(hp: int, max_hp: int)
signal player_died(total_score: int)

@export var max_hp: int = 5
@export var move_speed: float = 240.0

@export var bullet_damage: int = 1
@export var bullet_speed: float = 650.0
@export var bullet_count: int = 1 # 彈幕：每次射擊子彈數量
@export var spread_degrees: float = 14.0 # 散彈總張角（當 bullet_count > 1 生效）

@export var fire_cooldown: float = 0.22 # 子彈發射冷卻（秒，越大越慢）
@export var bullet_lifetime: float = 3.0

@export var penetration_count: int = 0 # 貫穿：額外可穿透的敵人數（0 = 不穿透）
@export var bounce_count: int = 0 # 彈跳：子彈反彈次數
@export var pickup_radius: float = 90.0 # 磁鐵升級會影響拾取/自動收集距離

# ========= 角色狀態 =========
var hp: int
var is_dead: bool = false

# 子彈附帶效果（升級會修改）
var dot_damage: int = 0
var dot_duration: float = 0.0
var knockback_strength: float = 0.0

var _time_since_shot: float = 0.0

const PLAYER_LAYER := 1
const ENEMY_LAYER := 2
const WALL_LAYER := 4
const BULLET_LAYER := 8

const PLAYER_BULLET_SCENE := preload("res://scenes/bullets/PlayerBullet.tscn")
const ORBITAL_BLADES_SCENE := preload("res://scenes/player/OrbitalBlades.tscn")
const GASTER_BLASTER_SCENE := preload("res://scenes/player/GasterBlaster.tscn")

## 升級：迴旋刀片 / Gaster Blaster（由 LevelManager 開關）
var orbital_blades_enabled: bool = false
## 迴旋刀片疊加次數：每次升級會讓刀片數 +1
## （總刀片 = orbital_blades_upgrades + 1；第一次升級後仍保持原本 2 把刀片）
var orbital_blades_upgrades: int = 0
var gaster_blaster_enabled: bool = false
## 每選一次 Gaster Blaster +1；每輪依此數量召喚多架（間隔見 GasterBlaster.gd）
var gaster_blaster_count: int = 0
var _orbital_weapon: Node2D = null
var _gaster_weapon: Node2D = null

@onready var muzzle: Marker2D = $Muzzle
@onready var _body_visual: Node2D = $Visual

var _hurt_flash_tween: Tween

func _ready() -> void:
	add_to_group("player")
	hp = max_hp
	hp_changed.emit(hp, max_hp)

	# Player 只用來被子彈命中；不與其他物理體互相推擠
	collision_layer = PLAYER_LAYER
	# 僅保留「敵人層」碰撞遮罩：避免玩家自身子彈在生成同幀造成碰撞推擠
	# （敵方子彈在 EnemyBullet / BulletBase 內會把 collision_mask 設為包含 PLAYER_LAYER）
	collision_mask = ENEMY_LAYER

func _process(delta: float) -> void:
	if is_dead:
		return
	# 瞄準：滑鼠／觸控第二指；僅搖桿時（觸控網頁）用移動方向當炮口方向
	var dir := _aim_world_delta()
	if dir.length_squared() > 0.0001:
		rotation = dir.angle()

	# 射擊：滑鼠左鍵，或右側開火搖桿。Web 觸控會把單指模擬成滑鼠左鍵，推左搖桿移動時勿當成開火。
	_time_since_shot += delta
	var mouse_fire := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if OS.get_name() == "Web" and DisplayServer.is_touchscreen_available():
		if MobileControls.joystick_vector.length_squared() > 0.0001:
			if not MobileControls.has_touch_aim and not MobileControls.is_fire_joystick_active():
				mouse_fire = false
	var want_fire := mouse_fire or MobileControls.is_fire_joystick_active()
	if want_fire and _time_since_shot >= fire_cooldown:
		_time_since_shot = 0.0
		var sfx := get_node_or_null("../SFX")
		if sfx != null and sfx.has_method("play_player_shoot"):
			sfx.call("play_player_shoot", global_position)
		_shoot(dir)

	# 跟隨相機（Main.tscn 裡有 Camera2D）
	var cam := get_node_or_null("../Camera2D")
	if cam:
		cam.global_position = global_position

func _physics_process(_delta: float) -> void:
	if is_dead:
		return
	# 鍵盤（WASD＋方向鍵）＋ 虛擬搖桿
	var kb := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var input_vec := kb + MobileControls.joystick_vector
	if input_vec.length_squared() > 1.0:
		input_vec = input_vec.normalized()

	velocity = input_vec * move_speed
	move_and_slide()

	# 簡單限制：不要離開視野太遠
	var cam := get_node_or_null("../Camera2D")
	if cam:
		var viewport_size: Vector2 = Vector2(get_viewport_rect().size)
		var half: Vector2 = viewport_size * 0.5
		var min_pos: Vector2 = cam.global_position - half
		var max_pos: Vector2 = cam.global_position + half
		global_position.x = clamp(global_position.x, min_pos.x, max_pos.x)
		global_position.y = clamp(global_position.y, min_pos.y, max_pos.y)


func _aim_world_delta() -> Vector2:
	# 右側開火搖桿：推動方向 = 炮口／子彈方向（優先於點擊瞄準）
	if MobileControls.is_fire_joystick_active():
		return MobileControls.fire_joystick_vector * 200.0
	if MobileControls.has_touch_aim:
		return MobileControls.aim_world_pos - global_position
	# 僅左搖桿、無右搖桿與觸控瞄準時：炮口與移動同向
	if OS.get_name() == "Web" and DisplayServer.is_touchscreen_available():
		if MobileControls.joystick_vector.length_squared() > 0.01:
			return MobileControls.joystick_vector * 200.0
	return get_global_mouse_position() - global_position


func _shoot(raw_dir: Vector2) -> void:
	if raw_dir.length_squared() < 0.0001:
		return
	var aim_dir := raw_dir.normalized()

	# 散彈：計算每顆子彈的角度偏移
	var base_angle := aim_dir.angle()
	if bullet_count <= 1:
		_spawn_bullet(base_angle)
		return

	var span := spread_degrees
	var step := 0.0
	if bullet_count > 1:
		step = span / float(bullet_count - 1)

	var center := (bullet_count - 1) * 0.5
	for i in range(bullet_count):
		var offset_deg := (float(i) - center) * step
		_spawn_bullet(base_angle + deg_to_rad(offset_deg))

func _spawn_bullet(angle: float) -> void:
	var b := PLAYER_BULLET_SCENE.instantiate()
	var dir := Vector2.RIGHT.rotated(angle)
	# 子彈生成點稍微往外推，避免和玩家碰撞體在同幀發生接觸造成「後座/強制位移」的錯覺
	b.global_position = muzzle.global_position + dir * 18.0
	get_tree().current_scene.add_child(b)

	# 角色子彈只打敵人/牆面（避免誤傷自己）
	# Godot GDScript 於此處改用位置參數，避免命名參數在換行下的語法解析問題
	b.setup(
		dir,
		bullet_damage,
		bullet_speed,
		bullet_lifetime,
		penetration_count,
		bounce_count,
		dot_damage,
		dot_duration,
		knockback_strength
	)

func take_damage(amount: int) -> void:
	if is_dead:
		return
	hp -= amount
	hp_changed.emit(hp, max_hp)
	_play_hurt_feedback()
	var sfx := get_node_or_null("../SFX")
	if sfx != null and sfx.has_method("play_player_hurt"):
		sfx.call("play_player_hurt", global_position)
	if hp <= 0:
		is_dead = true
		hp = 0
		player_died.emit(0)
		# 不直接 queue_free，讓 UI 可以顯示 Game Over 並按重新開始


func _play_hurt_feedback() -> void:
	if _body_visual != null:
		if _hurt_flash_tween != null and _hurt_flash_tween.is_valid():
			_hurt_flash_tween.kill()
		_hurt_flash_tween = create_tween()
		_hurt_flash_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_body_visual.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_hurt_flash_tween.tween_property(_body_visual, "modulate", Color(1.65, 0.35, 0.35, 1.0), 0.045)
		_hurt_flash_tween.tween_property(_body_visual, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.11)
		_hurt_flash_tween.tween_property(_body_visual, "modulate", Color(1.35, 0.55, 0.55, 1.0), 0.06)
		_hurt_flash_tween.tween_property(_body_visual, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)

	var cam := get_node_or_null("../Camera2D")
	if cam != null and cam.has_method("add_hit_shake"):
		cam.add_hit_shake(0.68)


func heal(amount: int) -> void:
	if is_dead:
		return
	hp = clamp(hp + amount, 0, max_hp)
	hp_changed.emit(hp, max_hp)

func increase_max_hp(amount: int) -> void:
	max_hp += amount
	hp = clamp(hp + amount, 0, max_hp)
	hp_changed.emit(hp, max_hp)


## 迴旋刀片／雷射與子彈共用傷害與附加效果
func deal_weapon_hit_to_enemy(body: Node) -> void:
	if body == null or not body.is_in_group("enemy"):
		return
	if body.has_method("take_damage"):
		body.take_damage(bullet_damage)
	if dot_damage > 0 and body.has_method("apply_dot"):
		body.apply_dot(dot_damage, dot_duration)
	if knockback_strength > 0 and body.has_method("apply_knockback"):
		var kb_dir: Vector2 = (body as Node2D).global_position - global_position
		kb_dir = kb_dir.normalized()
		body.apply_knockback(kb_dir, knockback_strength)


func _ensure_orbital_blades() -> void:
	if not orbital_blades_enabled:
		return
	if _orbital_weapon == null:
		_orbital_weapon = ORBITAL_BLADES_SCENE.instantiate() as Node2D
		add_child(_orbital_weapon)
	# 升級可以堆疊：即使已存在刀片也要更新數量
	var blade_total := maxi(1, orbital_blades_upgrades + 1)
	if _orbital_weapon != null and _orbital_weapon.has_method("set_blade_count"):
		_orbital_weapon.call("set_blade_count", blade_total)


func _ensure_gaster_blaster() -> void:
	if not gaster_blaster_enabled:
		return
	if _gaster_weapon != null:
		return
	_gaster_weapon = GASTER_BLASTER_SCENE.instantiate() as Node2D
	add_child(_gaster_weapon)


func _reset_weapon_upgrades() -> void:
	if _orbital_weapon != null:
		_orbital_weapon.queue_free()
		_orbital_weapon = null
	if _gaster_weapon != null:
		_gaster_weapon.queue_free()
		_gaster_weapon = null
	if orbital_blades_enabled:
		_ensure_orbital_blades()
	if gaster_blaster_enabled:
		_ensure_gaster_blaster()
