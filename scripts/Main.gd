extends Node2D
## 將主選單接到現有遊戲場景：初始先暫停，按「開始遊玩」後恢復。

@onready var _menu_layer: CanvasLayer = $MainMenuLayer
@onready var _brightness_modulate: CanvasModulate = $BrightnessModulate
@onready var _touch_controls_layer: CanvasLayer = $TouchControlsLayer
@onready var _game_ui: Node = $GameUI
@onready var _level_manager: Node = $LevelManager
@onready var _player: Node = $Player

const SETTINGS_PATH := "user://settings.cfg"

var _volume_linear: float = 1.0
var _brightness_factor: float = 1.0


func _ready() -> void:
	_load_settings()
	_apply_volume_linear(_volume_linear)
	_apply_brightness_factor(_brightness_factor)

	# 先停在選單：不要用 get_tree().paused，避免 Godot 在暫停時吞掉 UI 的滑鼠事件
	_set_game_still(true)
	_menu_layer.visible = true
	_touch_controls_layer.visible = false

	_menu_layer.start_game_requested.connect(_on_start_game_requested)
	_menu_layer.exit_game_requested.connect(_on_exit_game_requested)
	_menu_layer.volume_changed.connect(_on_volume_changed)
	_menu_layer.brightness_changed.connect(_on_brightness_changed)
	# 暫停畫面的「退回主選單」訊號，來自 GameUI
	if _game_ui != null and _game_ui.has_signal("back_to_main_menu_requested"):
		_game_ui.connect("back_to_main_menu_requested", _on_back_to_main_menu_requested)

	# 等 MainMenuLayer 的 @onready 節點完成初始化後再填入初始值
	_menu_layer.call_deferred("set_settings", _volume_linear, _brightness_factor)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		return

	_volume_linear = float(cfg.get_value("audio", "volume_linear", 1.0))
	_brightness_factor = float(cfg.get_value("video", "brightness_factor", 1.0))

	_volume_linear = clampf(_volume_linear, 0.0, 1.0)
	_brightness_factor = clampf(_brightness_factor, 0.5, 1.5)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume_linear", _volume_linear)
	cfg.set_value("video", "brightness_factor", _brightness_factor)
	cfg.save(SETTINGS_PATH)


func _on_start_game_requested() -> void:
	_menu_layer.visible = false
	_touch_controls_layer.visible = true
	if _game_ui != null and _game_ui.has_method("force_set_paused"):
		_game_ui.call("force_set_paused", false)
	_set_game_still(false)


func _on_exit_game_requested() -> void:
	get_tree().quit()


func _on_back_to_main_menu_requested() -> void:
	# 回到主選單時：停在選單，且先把遊戲邏輯狀態確保為未暫停（之後開始遊玩時正常運作）
	_touch_controls_layer.visible = false
	_menu_layer.visible = true
	if _game_ui != null and _game_ui.has_method("force_set_paused"):
		_game_ui.call("force_set_paused", false)
	_set_game_still(true)


func _set_game_still(still: bool) -> void:
	# 凍結遊戲邏輯（不凍結輸入），確保主選單可點擊。
	if _level_manager:
		_level_manager.set_process(!still)
		_level_manager.set_physics_process(!still)

	# 玩家/敵人/子彈/武器/掉落物
	_set_group_processing("player", !still)
	_set_group_processing("enemy", !still)
	_set_group_processing("bullet", !still)
	_set_group_processing("xp_pickup", !still)
	_set_group_processing("player_weapon", !still)

	# Player 可能不在 group（理論上在），保險再處理一次
	if _player:
		(_player as Node).set_process(!still)
		(_player as Node).set_physics_process(!still)


func _set_group_processing(group_name: String, enabled: bool) -> void:
	var nodes := get_tree().get_nodes_in_group(group_name)
	for n in nodes:
		if n == null:
			continue
		n.set_process(enabled)
		n.set_physics_process(enabled)


func _on_volume_changed(v: float) -> void:
	_volume_linear = clampf(v, 0.0, 1.0)
	_apply_volume_linear(_volume_linear)
	_save_settings()


func _on_brightness_changed(v: float) -> void:
	_brightness_factor = clampf(v, 0.5, 1.5)
	_apply_brightness_factor(_brightness_factor)
	_save_settings()


func _apply_volume_linear(v: float) -> void:
	# AudioServer bus 0 通常是 Master
	var safe := maxf(v, 0.0001)
	var db := linear_to_db(safe)
	AudioServer.set_bus_volume_db(0, db)


func _apply_brightness_factor(f: float) -> void:
	# CanvasModulate 會把所有 2D 畫面顏色乘上這個值（用於模擬亮度調整）
	if _brightness_modulate:
		_brightness_modulate.color = Color(f, f, f, 1.0)

