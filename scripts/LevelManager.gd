extends Node

var player: Node
var ui: Node

@export var total_waves: int = 10
const GROUP_ENEMY := "enemy"

var score: int = 0
var current_wave: int = 1
var enemies_alive: int = 0
var prev_wave_enemy_count: int = 0

var rng := RandomNumberGenerator.new()

# ========= 玩家基準值（用於重開重置） =========
var _base_max_hp: int
var _base_move_speed: float
var _base_bullet_damage: int
var _base_bullet_speed: float
var _base_bullet_count: int
var _base_fire_cooldown: float
var _base_penetration_count: int
var _base_bounce_count: int
var _base_dot_damage: int
var _base_dot_duration: float
var _base_knockback_strength: float
var _base_pickup_radius: float
var _base_orbital_blades: bool
var _base_gaster_blaster: bool
var _base_gaster_blaster_count: int

const ENEMY_SCENE := preload("res://scenes/enemies/BaseEnemy.tscn")

## 關卡內分批生成：啟動時排好本波敵人類型佇列，每 3 秒生成一批，在 15～20 秒內發完
const SPAWN_INTERVAL_SEC := 3.0
const SPAWN_WINDOW_MIN := 15.0
const SPAWN_WINDOW_MAX := 20.0

var _spawn_active: bool = false
var _spawn_batches: Array = []
var _spawn_batch_index: int = 0
var _time_until_next_batch: float = 0.0

## 防止過關流程重入（雙重 died / 同幀結算）
var _wave_cleared_busy: bool = false

func _ready() -> void:
	add_to_group("level_manager")
	rng.randomize()
	var players := get_tree().get_nodes_in_group("player")
	player = players[0] if not players.is_empty() else null

	# 等一個 frame 確保 GameUI 的 onready 變數已初始化
	await get_tree().process_frame

	ui = get_node_or_null("../GameUI")
	if ui == null:
		push_error("找不到 GameUI，請確認 Main.tscn 內有節點名稱 GameUI。")
		return

	_cache_player_baselines()
	_connect_signals()
	ui.set_wave(current_wave, total_waves)
	ui.set_hp(player.hp, player.max_hp)
	ui.set_score(score)

	start_wave(1)


func _process(delta: float) -> void:
	if not _spawn_active:
		return
	_time_until_next_batch -= delta
	if _time_until_next_batch > 0.0:
		return
	_spawn_current_batch()
	_spawn_batch_index += 1
	if _spawn_batch_index >= _spawn_batches.size():
		_spawn_active = false
		# 若玩家在空批次／排程收尾前已清光場上敵人，須在排程結束時補結算
		if enemies_alive <= 0:
			_on_wave_cleared()
		return
	_time_until_next_batch = SPAWN_INTERVAL_SEC


func _cache_player_baselines() -> void:
	_base_max_hp = int(player.max_hp)
	_base_move_speed = float(player.move_speed)
	_base_bullet_damage = int(player.bullet_damage)
	_base_bullet_speed = float(player.bullet_speed)
	_base_bullet_count = int(player.bullet_count)
	_base_fire_cooldown = float(player.fire_cooldown)
	_base_penetration_count = int(player.penetration_count)
	_base_bounce_count = int(player.bounce_count)
	_base_dot_damage = int(player.dot_damage)
	_base_dot_duration = float(player.dot_duration)
	_base_knockback_strength = float(player.knockback_strength)
	_base_pickup_radius = float(player.pickup_radius)
	_base_orbital_blades = bool(player.orbital_blades_enabled)
	_base_gaster_blaster = bool(player.gaster_blaster_enabled)
	_base_gaster_blaster_count = int(player.gaster_blaster_count)

func _connect_signals() -> void:
	player.player_died.connect(_on_player_died)
	ui.restart_requested.connect(restart_game)
	ui.upgrade_chosen.connect(_on_upgrade_chosen)
	ui.pause_toggled.connect(_on_pause_toggled)
	player.hp_changed.connect(ui.set_hp)

func add_score(amount: int) -> void:
	score += amount
	if ui:
		ui.set_score(score)


func _update_terrain_background() -> void:
	var bg: Node = get_node_or_null("../TerrainLayer/TerrainBackground")
	if bg != null and bg.has_method("set_for_wave"):
		bg.call("set_for_wave", current_wave)

func start_wave(wave: int) -> void:
	_clear_spawn_state()
	_wave_cleared_busy = false
	current_wave = wave
	enemies_alive = 0
	ui.set_wave(current_wave, total_waves)
	_update_terrain_background()

	if wave == 10:
		_spawn_boss()
		return

	var unlocked_count: int = min(5, int(ceil(float(wave) / 2.0)))
	var types := ["A", "B", "C", "D", "E"].slice(0, unlocked_count)

	var enemy_count: int
	if wave == 1:
		enemy_count = rng.randi_range(8, 16)
	else:
		enemy_count = int(max(1, prev_wave_enemy_count * rng.randf_range(1.25, 1.5)))
	prev_wave_enemy_count = enemy_count

	_begin_timed_wave_spawns(types, enemy_count)


func _clear_spawn_state() -> void:
	_spawn_active = false
	_spawn_batches.clear()
	_spawn_batch_index = 0
	_time_until_next_batch = 0.0


## 關卡開始時決定本波每種敵人的數量（總量 = enemy_count），再拆成每 3 秒一批，於 15～20 秒內發完
func _begin_timed_wave_spawns(types: Array, enemy_count: int) -> void:
	if types.is_empty() or enemy_count <= 0:
		return

	# 本波「預定生成表」：長度 enemy_count，每隻敵人的類型在開局就決定好
	var type_queue: Array[String] = []
	for i in range(enemy_count):
		type_queue.append(str(types[rng.randi_range(0, types.size() - 1)]))
	type_queue.shuffle()

	var spawn_window: float = rng.randf_range(SPAWN_WINDOW_MIN, SPAWN_WINDOW_MAX)
	var tick_count: int = int(floor(spawn_window / SPAWN_INTERVAL_SEC)) + 1
	tick_count = maxi(1, tick_count)

	_spawn_batches = _split_into_batches(type_queue, tick_count)
	_spawn_batch_index = 0
	_spawn_active = true
	_time_until_next_batch = 0.0 # 第一幀立刻生成第一批


func _split_into_batches(items: Array, batch_count: int) -> Array:
	var batches: Array = []
	var n: int = items.size()
	if batch_count <= 0:
		return batches
	var base: int = n / batch_count
	var rem: int = n % batch_count
	var idx: int = 0
	for i in range(batch_count):
		var sz: int = base + (1 if i < rem else 0)
		batches.append(items.slice(idx, idx + sz))
		idx += sz
	return batches


func _spawn_current_batch() -> void:
	if _spawn_batch_index >= _spawn_batches.size():
		return
	var batch: Variant = _spawn_batches[_spawn_batch_index]
	if batch is not Array:
		return
	for tvar in batch:
		var t: String = str(tvar)
		var pos := _get_spawn_world_position_outside_view()
		var e := _spawn_enemy_at(t, pos)
		e.died.connect(_on_enemy_died)
		enemies_alive += 1


func _spawn_boss() -> void:
	var pos := _get_spawn_world_position_outside_view()
	var boss := _spawn_enemy_at("BOSS", pos)
	boss.died.connect(_on_enemy_died)
	enemies_alive = 1


func _spawn_enemy_at(t: String, spawn_pos: Vector2) -> Node:
	var e := ENEMY_SCENE.instantiate()
	e.global_position = spawn_pos

	_apply_enemy_config(e, t)
	# 必須先設定，再 add_child 讓 _ready() 用到正確數值
	get_tree().current_scene.add_child(e)
	return e


## 生成在攝影機可視範圍外（以目前 Camera2D 視野為準）
func _get_spawn_world_position_outside_view() -> Vector2:
	var cam: Camera2D = get_viewport().get_camera_2d()
	var center: Vector2 = player.global_position
	var half_ext: Vector2
	if cam != null:
		center = cam.get_screen_center_position()
		half_ext = get_viewport().get_visible_rect().size * 0.5 / cam.zoom
	else:
		half_ext = get_viewport().get_visible_rect().size * 0.5

	var margin := 110.0
	var min_radius: float = maxf(half_ext.x, half_ext.y) + margin
	var dist: float = rng.randf_range(min_radius + 30.0, min_radius + 320.0)
	var ang: float = rng.randf() * TAU
	return center + Vector2.RIGHT.rotated(ang) * dist


func _apply_enemy_config(e: Node, t: String) -> void:
	# 用顏色對應規格：
	# A紅 B黃 C綠 D紫 E橘
	if t == "A":
		e.max_hp = 3
		e.move_speed = 90.0
		e.melee_range = 65.0
		e.enable_ranged = false
		e.enable_dash = false
		e.enable_ring = false
		e.enemy_color = Color(1, 0.1, 0.1, 1)
		e.score_value = 10
		e.xp_value = 1
	elif t == "B":
		e.max_hp = 2
		e.move_speed = 105.0
		e.enable_ranged = true
		e.ranged_range = 260.0
		e.ranged_interval = 1.0
		e.enable_dash = false
		e.enable_ring = false
		e.enemy_color = Color(1, 0.9, 0.1, 1)
		e.score_value = 12
		e.xp_value = 1
	elif t == "C":
		e.max_hp = 1
		e.move_speed = 150.0
		e.enable_dash = true
		e.melee_range = 90.0
		e.dash_speed_multiplier = 3.0
		e.dash_duration = 0.18
		e.dash_cooldown = 1.0
		e.enable_ranged = false
		e.enable_ring = false
		e.enemy_color = Color(0.2, 1.0, 0.3, 1)
		e.score_value = 14
		e.xp_value = 1
	elif t == "D":
		e.max_hp = 5
		e.move_speed = 60.0
		e.melee_range = 70.0
		e.enable_ranged = false
		e.enable_dash = false
		e.enable_ring = false
		e.enemy_color = Color(0.7, 0.2, 1.0, 1)
		e.score_value = 18
		e.xp_value = 2
	elif t == "E":
		e.max_hp = 3
		e.move_speed = 75.0
		e.enable_ring = true
		e.ring_interval = 2.2
		e.enable_ranged = false
		e.enable_dash = false
		e.ring_bullet_count = 10
		e.enemy_color = Color(1.0, 0.6, 0.15, 1)
		e.score_value = 16
		e.xp_value = 1
	elif t == "BOSS":
		e.max_hp = 50
		e.move_speed = 35.0
		e.melee_range = 90.0

		# B 特性：定距離射擊
		e.enable_ranged = true
		e.ranged_range = 320.0
		e.ranged_interval = 0.9
		e.ranged_bullet_speed = 340.0

		# D 特性：坦型血量與慢移
		e.enable_dash = false

		# E 特性：定時 360 度環形子彈
		e.enable_ring = true
		e.ring_interval = 2.0
		e.ring_bullet_count = 10
		e.ring_bullet_speed = 280.0

		e.enemy_color = Color(1.0, 0.3, 0.8, 1) # Boss 顏色：偏亮紫
		e.score_value = 150
		e.xp_value = 10

func _on_enemy_died(score_gained: int) -> void:
	add_score(score_gained)
	enemies_alive = maxi(0, enemies_alive - 1)
	# 分批生成期間可能暫時全滅，須等本波排程發完才能結算過關
	if enemies_alive <= 0 and not _spawn_active:
		_on_wave_cleared()

func _on_wave_cleared() -> void:
	if _wave_cleared_busy:
		return
	if _spawn_active:
		return
	if enemies_alive > 0:
		return
	_wave_cleared_busy = true
	# Wave 10 由 boss 死亡觸發勝利
	if current_wave >= total_waves:
		ui.show_victory(score)
		# 先顯示畫面，再下一個 frame 才暫停，避免點不到
		await get_tree().process_frame
		_set_game_paused(true)
		return

	# 子彈可能在敵人死亡後短暫存在，升級期間清掉避免玩家被「殘留彈」再次擊中
	for b in get_tree().get_nodes_in_group("bullet"):
		b.queue_free()

	show_upgrade_menu()

func show_upgrade_menu() -> void:
	# 每關結束三選一
	var pool := _upgrade_pool()
	var choices: Array[Dictionary] = []

	while choices.size() < 3 and pool.size() > 0:
		var idx := rng.randi_range(0, pool.size() - 1)
		choices.append(pool[idx])
		pool.remove_at(idx)

	ui.show_upgrade_menu(choices)
	# 先顯示選單再下一個 frame 才暫停，避免同幀切換 pause 導致點不到
	await get_tree().process_frame
	_set_game_paused(true)

func _on_upgrade_chosen(upgrade_id: String) -> void:
	ui.hide_upgrade_menu()
	_set_game_paused(false)

	_apply_upgrade_to_player(upgrade_id)

	# 切下一關
	start_wave(current_wave + 1)

func _apply_upgrade_to_player(upgrade_id: String) -> void:
	if upgrade_id == "quick":
		player.move_speed += 35.0
	elif upgrade_id == "barrage":
		player.bullet_count += 1
	elif upgrade_id == "heal":
		if player.hp < player.max_hp:
			player.heal(1)
		else:
			player.increase_max_hp(1)
	elif upgrade_id == "reload":
		# 裝填：小幅提高射速
		player.fire_cooldown = max(0.06, player.fire_cooldown * 0.85)
	elif upgrade_id == "rapid_fire":
		player.fire_cooldown = max(0.06, player.fire_cooldown * 0.75)
	elif upgrade_id == "power":
		player.bullet_damage += 1
	elif upgrade_id == "toxic":
		# DOT：每秒扣 1 點生命，並刷新/延長持續時間
		player.dot_damage = 1
		player.dot_duration += 3.0
	elif upgrade_id == "shock":
		player.knockback_strength += 140.0
	elif upgrade_id == "break":
		player.bullet_damage += 2
	elif upgrade_id == "penetrate":
		player.penetration_count += 1
	elif upgrade_id == "magnet":
		player.pickup_radius += 70.0
	elif upgrade_id == "bounce":
		player.bounce_count += 1
	elif upgrade_id == "orbital_blades":
		player.orbital_blades_enabled = true
		player._ensure_orbital_blades()
	elif upgrade_id == "gaster_blaster":
		player.gaster_blaster_enabled = true
		player.gaster_blaster_count += 1
		player._ensure_gaster_blaster()

	# 升級後立即更新 UI
	ui.set_hp(player.hp, player.max_hp)

func _upgrade_pool() -> Array[Dictionary]:
	return [
		{ "id": "quick", "name": "迅捷" },
		{ "id": "barrage", "name": "彈幕（散彈 +1）" },
		{ "id": "heal", "name": "療癒/擴充（+1 HP 或上限）" },
		{ "id": "reload", "name": "裝填（冷卻降低）" },
		{ "id": "rapid_fire", "name": "射速強化（冷卻降低）" },
		{ "id": "power", "name": "強力（傷害 +1）" },
		{ "id": "toxic", "name": "劇毒（DOT）" },
		{ "id": "shock", "name": "震盪（擊退）" },
		{ "id": "break", "name": "破壞（傷害 +2）" },
		{ "id": "penetrate", "name": "貫穿（穿透 +1）" },
		{ "id": "magnet", "name": "磁鐵（拾取範圍 +70）" },
		{ "id": "bounce", "name": "彈跳（連鎖 +1）" },
		{ "id": "orbital_blades", "name": "迴旋刀片（環身旋轉傷害）" },
		{ "id": "gaster_blaster", "name": "Gaster Blaster（雷射砲／疊加召喚數）" },
	]

func restart_game() -> void:
	# 重新開始：清除敵人/子彈/掉落物並重置玩家
	_clear_spawn_state()
	_set_game_paused(false)
	ui.hide_upgrade_menu()
	ui.hide_game_over()
	ui.hide_victory()

	_clear_groups()
	_reset_player()

	score = 0
	current_wave = 1
	prev_wave_enemy_count = 0
	ui.set_wave(current_wave, total_waves)
	ui.set_score(score)

	start_wave(1)

func _clear_groups() -> void:
	for n in get_tree().get_nodes_in_group(GROUP_ENEMY):
		n.queue_free()
	for n in get_tree().get_nodes_in_group("bullet"):
		n.queue_free()
	for n in get_tree().get_nodes_in_group("xp_pickup"):
		n.queue_free()

func _reset_player() -> void:
	player.is_dead = false
	player.set_process(true)
	player.set_physics_process(true)

	player.max_hp = _base_max_hp
	player.move_speed = _base_move_speed
	player.bullet_damage = _base_bullet_damage
	player.bullet_speed = _base_bullet_speed
	player.bullet_count = _base_bullet_count
	player.fire_cooldown = _base_fire_cooldown
	player.penetration_count = _base_penetration_count
	player.bounce_count = _base_bounce_count
	player.dot_damage = _base_dot_damage
	player.dot_duration = _base_dot_duration
	player.knockback_strength = _base_knockback_strength
	player.pickup_radius = _base_pickup_radius
	player.orbital_blades_enabled = _base_orbital_blades
	player.gaster_blaster_enabled = _base_gaster_blaster
	player.gaster_blaster_count = _base_gaster_blaster_count
	player._reset_weapon_upgrades()

	player.hp = player.max_hp
	player.hp_changed.emit(player.hp, player.max_hp)

func _on_player_died(_total_score: int) -> void:
	ui.show_game_over()
	# 先顯示畫面，再下一個 frame 才暫停，避免點不到
	await get_tree().process_frame
	_set_game_paused(true)

func _set_game_paused(paused: bool) -> void:
	# 不用 get_tree().paused（會影響輸入/訊號在暫停狀態下的處理），
	# 改成只暫停玩家/敵人/子彈等「遊戲邏輯」節點，確保升級按鈕可正常點擊。
	_set_group_processing("player", !paused)
	_set_group_processing(GROUP_ENEMY, !paused)
	_set_group_processing("bullet", !paused)
	_set_group_processing("xp_pickup", !paused)
	_set_group_processing("player_weapon", !paused)
	# 暫停時停止分批生成計時，避免 ESC 選單期間仍繼續生怪
	set_process(!paused)

func _set_group_processing(group_name: String, enabled: bool) -> void:
	var nodes := get_tree().get_nodes_in_group(group_name)
	for n in nodes:
		if n == null:
			continue
		n.set_process(enabled)
		n.set_physics_process(enabled)

func _on_pause_toggled(paused: bool) -> void:
	# 暫停/解除時同步玩家/敵人/子彈邏輯
	_set_game_paused(paused)
