extends CanvasLayer
## 主選單 UI：開始遊玩 / 選項(音量+亮度) / 退出遊戲。
## 由 Main.tscn 的腳本接收訊號並控制 get_tree().paused 與套用設定。

signal start_game_requested()
signal exit_game_requested()
signal volume_changed(volume_linear: float)
signal brightness_changed(brightness_factor: float)

const UI_FONT_PATH := "res://fonts/NotoSansTC-wght.ttf"
const UI_FONT_SIZE := 32

@onready var _menu_panel: Control = $MenuPanel
@onready var _options_panel: Control = $OptionsPanel

@onready var _start_button: Button = $MenuPanel/VBoxContainer/StartButton
@onready var _options_button: Button = $MenuPanel/VBoxContainer/OptionsButton
@onready var _exit_button: Button = $MenuPanel/VBoxContainer/ExitButton

@onready var _back_button: Button = $OptionsPanel/VBoxContainer/BackButton

@onready var _volume_slider: HSlider = $OptionsPanel/VBoxContainer/VolumeRow/VolumeSlider
@onready var _volume_value_label: Label = $OptionsPanel/VBoxContainer/VolumeRow/VolumeValueLabel

@onready var _brightness_slider: HSlider = $OptionsPanel/VBoxContainer/BrightnessRow/BrightnessSlider
@onready var _brightness_value_label: Label = $OptionsPanel/VBoxContainer/BrightnessRow/BrightnessValueLabel

var _ui_font: Font
var _suppress_slider_signals := false


func _ready() -> void:
	_ui_font = load(UI_FONT_PATH) as Font
	_apply_font_recursive(self)

	# 確保主選單在 get_tree().paused = true 時仍能接到觸控/滑鼠事件
	set_process_input(true)
	set_process_unhandled_input(true)

	_options_panel.visible = false
	_menu_panel.visible = true

	# Slider 顯示/拖拉範圍：1~100
	_volume_slider.min_value = 1.0
	_volume_slider.max_value = 100.0
	_volume_slider.step = 1.0
	_volume_slider.value = 100.0

	_brightness_slider.min_value = 1.0
	_brightness_slider.max_value = 100.0
	_brightness_slider.step = 1.0
	_brightness_slider.value = 100.0

	_update_volume_label(int(roundf(_volume_slider.value)))
	_update_brightness_label(int(roundf(_brightness_slider.value)))

	_start_button.pressed.connect(func(): start_game_requested.emit())
	_options_button.pressed.connect(func(): _show_options())
	_exit_button.pressed.connect(func(): exit_game_requested.emit())
	_back_button.pressed.connect(func(): _show_main_menu())

	_volume_slider.value_changed.connect(_on_volume_slider_changed)
	_brightness_slider.value_changed.connect(_on_brightness_slider_changed)

	# 僅保險：若 paused 狀態下 Button 的 pressed 沒收到觸控，
	# 改用下方自訂 _unhandled_input 依座標直接觸發，確保三顆按鈕可用。


func _input(event: InputEvent) -> void:
	if not visible:
		return

	# 只在「按下」那一幀觸發一次（避免滑動造成重複）
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_try_click_at(st.position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_try_click_at(mb.position)

func _try_click_at(pos: Vector2) -> void:
	# 用座標判斷落在哪顆按鈕上，避免暫停時 Button 輸入被吞掉導致完全無反應
	if _control_hit(_start_button, pos):
		# 不依賴 Button.pressed 內部輸入處理，直接發送訊號
		start_game_requested.emit()
		return
	if _control_hit(_options_button, pos):
		_show_options()
		return
	if _control_hit(_exit_button, pos):
		exit_game_requested.emit()
		return

func _control_hit(c: Control, pos: Vector2) -> bool:
	# 將「viewport 座標」轉成 Control 自己的 local 座標，再用 get_rect() 判斷。
	# 這比直接用 get_global_rect() 更不容易因為 CanvasLayer/scale 而座標不一致。
	var local := c.get_global_transform_with_canvas().affine_inverse() * pos
	return c.get_rect().has_point(local)

func _apply_font_recursive(n: Node) -> void:
	if n is Control:
		var c := n as Control
		if _ui_font != null:
			c.add_theme_font_override("font", _ui_font)
			c.add_theme_font_size_override("font_size", UI_FONT_SIZE)
	for ch in n.get_children():
		_apply_font_recursive(ch)


func _show_main_menu() -> void:
	_options_panel.visible = false
	_menu_panel.visible = true


func _show_options() -> void:
	_menu_panel.visible = false
	_options_panel.visible = true


func set_settings(volume_linear: float, brightness_factor: float) -> void:
	# 讓 Main.tscn 載入設定後刷新 UI（避免 set_value 引發訊號重複儲存也可選擇 suppress）
	_suppress_slider_signals = true
	var vol_pct := int(roundf(clampf(volume_linear, 0.0, 1.0) * 100.0))
	vol_pct = clampi(vol_pct, 1, 100)
	var bri_pct := int(roundf(_brightness_percent_from_factor(brightness_factor)))
	bri_pct = clampi(bri_pct, 1, 100)
	_volume_slider.value = float(vol_pct)
	_brightness_slider.value = float(bri_pct)
	_suppress_slider_signals = false
	_update_volume_label(vol_pct)
	_update_brightness_label(bri_pct)


func _on_volume_slider_changed(v: float) -> void:
	var vol_pct := int(roundf(v))
	var vol_linear := float(vol_pct) / 100.0
	_update_volume_label(vol_pct)
	if _suppress_slider_signals:
		return
	volume_changed.emit(vol_linear)


func _on_brightness_slider_changed(v: float) -> void:
	var bri_pct := int(roundf(v))
	var bri_factor := _brightness_factor_from_percent(bri_pct)
	_update_brightness_label(bri_pct)
	if _suppress_slider_signals:
		return
	brightness_changed.emit(bri_factor)


func _update_volume_label(pct: int) -> void:
	_volume_value_label.text = "音量: %d%%" % pct


func _update_brightness_label(pct: int) -> void:
	_brightness_value_label.text = "亮度: %d%%" % pct

func _brightness_factor_from_percent(pct: int) -> float:
	# 1~100 -> 0.5~1.5 線性映射（保留你原本亮度因子的語意）
	var p := clampf(float(pct), 1.0, 100.0)
	return 0.5 + (p - 1.0) / 99.0

func _brightness_percent_from_factor(factor: float) -> float:
	# 0.5~1.5 -> 1~100 反推
	var f := clampf(factor, 0.5, 1.5)
	return (f - 0.5) * 99.0 + 1.0
