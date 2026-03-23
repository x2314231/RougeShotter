extends CanvasLayer

## Web/HTML5 匯出時需內嵌 CJK 字型，否則中文會顯示成方塊（豆腐字）。
const UI_FONT_PATH := "res://fonts/NotoSansTC-wght.ttf"

signal upgrade_chosen(upgrade_id: String)
signal restart_requested()
signal pause_toggled(paused: bool)
signal back_to_main_menu_requested()

var hp_label: Label
var hp_bar: ProgressBar
var score_label: Label
var wave_label: Label

var upgrade_panel: PanelContainer
var upgrade_title: Label
var btn1: Button
var btn2: Button
var btn3: Button

var game_over_panel: PanelContainer
var restart_button: Button

var victory_panel: PanelContainer
var restart_button2: Button
var victory_label: Label

var pause_panel: PanelContainer
var resume_button: Button
var pause_toggle_button: Button
var back_to_main_menu_button: Button
var _is_paused: bool = false

## 內嵌 CJK 字型（僅 Control 可套用 Theme；CanvasLayer 無 theme，故用 override）
var _ui_font: Font

func _ready() -> void:
	# 確保 UI 在 get_tree().paused = true 時仍能收到滑鼠/鍵盤輸入
	set_process_input(true)
	set_process_unhandled_input(true)
	set_process(true)

	_apply_embedded_cjk_font_theme()
	_build_ui()
	_bind_signals()
	hide_upgrade_menu()
	hide_game_over()
	hide_victory()
	_hide_pause()

func _build_ui() -> void:
	# 即使 tscn 內節點載入不完整，也能保證 UI 可用。

	# ----- TopHUD -----
	var top_hud := get_node_or_null("TopHUD") as Control
	if top_hud == null:
		top_hud = Control.new()
		top_hud.name = "TopHUD"
		add_child(top_hud)
		# 勿用 PRESET_FULL_RECT(15)：會鋪滿全螢幕並攔截觸控，導致下層搖桿（較低 CanvasLayer）永遠收不到觸控
		top_hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
		top_hud.offset_left = 10
		top_hud.offset_top = 10
		# 錨點全在左上時：right/bottom 為相對父視窗左／上邊的絕對位置，寬高 = right-left、bottom-top
		top_hud.offset_right = 10 + 420
		top_hud.offset_bottom = 10 + 80

	hp_label = _get_or_create_label(top_hud, "HpLabel", "HP: 5/5", Vector2(0, 0))

	hp_bar = top_hud.get_node_or_null("HpBar") as ProgressBar
	if hp_bar == null:
		hp_bar = ProgressBar.new()
		hp_bar.name = "HpBar"
		top_hud.add_child(hp_bar)
	hp_bar.position = Vector2(0, 22)
	hp_bar.custom_minimum_size = Vector2(240, 18)
	hp_bar.size = Vector2(240, 18)
	hp_bar.show_percentage = false
	hp_bar.max_value = 5.0
	hp_bar.value = 5.0
	hp_bar.step = 1.0

	score_label = _get_or_create_label(top_hud, "ScoreLabel", "Score: 0", Vector2(0, 48))
	wave_label = _get_or_create_label(top_hud, "WaveLabel", "Wave: 1/10", Vector2(0, 76))

	# ----- Pause button (mobile/web) -----
	# 桌面版用 ESC；手機/Web 顯示右上角暫停按鈕。
	pause_toggle_button = _get_or_create_button(top_hud, "PauseToggleButton", "暫停")
	pause_toggle_button.position = Vector2(300, 0)
	pause_toggle_button.custom_minimum_size = Vector2(110, 40)
	pause_toggle_button.visible = OS.get_name() == "Web" or DisplayServer.is_touchscreen_available()
	pause_toggle_button.pressed.connect(func(): _on_pause_toggle_pressed())

	# ----- Upgrade menu -----
	upgrade_panel = get_node_or_null("UpgradePanel") as PanelContainer
	if upgrade_panel == null:
		upgrade_panel = PanelContainer.new()
		upgrade_panel.name = "UpgradePanel"
		add_child(upgrade_panel)
		upgrade_panel.anchors_preset = 15
		upgrade_panel.anchor_left = 0.5
		upgrade_panel.anchor_top = 0.5
		upgrade_panel.anchor_right = 0.5
		upgrade_panel.anchor_bottom = 0.5
		upgrade_panel.offset_left = -260
		upgrade_panel.offset_top = -160
		upgrade_panel.offset_right = 260
		upgrade_panel.offset_bottom = 160

	var upgrade_vbox := upgrade_panel.get_node_or_null("UpgradeVBox") as VBoxContainer
	if upgrade_vbox == null:
		upgrade_vbox = VBoxContainer.new()
		upgrade_vbox.name = "UpgradeVBox"
		upgrade_panel.add_child(upgrade_vbox)
		upgrade_vbox.offset_left = 0
		upgrade_vbox.offset_top = 0
		upgrade_vbox.offset_right = 520
		upgrade_vbox.offset_bottom = 320

	upgrade_title = _get_or_create_label(upgrade_vbox, "UpgradeTitle", "三選一升級", Vector2.ZERO)
	# 清掉舊按鈕
	for c in upgrade_vbox.get_children():
		if c is Button and c.name.begins_with("Btn"):
			c.queue_free()

	btn1 = _get_or_create_button(upgrade_vbox, "Btn1", "Option 1")
	btn2 = _get_or_create_button(upgrade_vbox, "Btn2", "Option 2")
	btn3 = _get_or_create_button(upgrade_vbox, "Btn3", "Option 3")

	# ----- Game Over -----
	game_over_panel = get_node_or_null("GameOverPanel") as PanelContainer
	if game_over_panel == null:
		game_over_panel = PanelContainer.new()
		game_over_panel.name = "GameOverPanel"
		add_child(game_over_panel)
		game_over_panel.anchors_preset = 15
		game_over_panel.anchor_left = 0.5
		game_over_panel.anchor_top = 0.5
		game_over_panel.anchor_right = 0.5
		game_over_panel.anchor_bottom = 0.5
		game_over_panel.offset_left = -280
		game_over_panel.offset_top = -160
		game_over_panel.offset_right = 280
		game_over_panel.offset_bottom = 160

	var go_vbox := game_over_panel.get_node_or_null("GameOverVBox") as VBoxContainer
	if go_vbox == null:
		go_vbox = VBoxContainer.new()
		go_vbox.name = "GameOverVBox"
		game_over_panel.add_child(go_vbox)
		go_vbox.offset_left = 0
		go_vbox.offset_top = 0
		go_vbox.offset_right = 560
		go_vbox.offset_bottom = 320

	_get_or_create_label(go_vbox, "GameOverLabel", "Game Over", Vector2.ZERO)
	restart_button = _get_or_create_button(go_vbox, "RestartButton", "重新開始")

	# ----- Victory -----
	victory_panel = get_node_or_null("VictoryPanel") as PanelContainer
	if victory_panel == null:
		victory_panel = PanelContainer.new()
		victory_panel.name = "VictoryPanel"
		add_child(victory_panel)
		victory_panel.anchors_preset = 15
		victory_panel.anchor_left = 0.5
		victory_panel.anchor_top = 0.5
		victory_panel.anchor_right = 0.5
		victory_panel.anchor_bottom = 0.5
		victory_panel.offset_left = -280
		victory_panel.offset_top = -160
		victory_panel.offset_right = 280
		victory_panel.offset_bottom = 160

	var vic_vbox := victory_panel.get_node_or_null("VictoryVBox") as VBoxContainer
	if vic_vbox == null:
		vic_vbox = VBoxContainer.new()
		vic_vbox.name = "VictoryVBox"
		victory_panel.add_child(vic_vbox)
		vic_vbox.offset_left = 0
		vic_vbox.offset_top = 0
		vic_vbox.offset_right = 560
		vic_vbox.offset_bottom = 320

	victory_label = _get_or_create_label(vic_vbox, "VictoryLabel", "恭喜通關", Vector2.ZERO)
	restart_button2 = _get_or_create_button(vic_vbox, "RestartButton2", "再玩一次")

	# ----- Pause -----
	pause_panel = get_node_or_null("PausePanel") as PanelContainer
	if pause_panel == null:
		pause_panel = PanelContainer.new()
		pause_panel.name = "PausePanel"
		add_child(pause_panel)
		pause_panel.anchors_preset = 15
		pause_panel.anchor_left = 0.5
		pause_panel.anchor_top = 0.5
		pause_panel.anchor_right = 0.5
		pause_panel.anchor_bottom = 0.5
		pause_panel.offset_left = -280
		pause_panel.offset_top = -160
		pause_panel.offset_right = 280
		pause_panel.offset_bottom = 160

	var pause_vbox := pause_panel.get_node_or_null("PauseVBox") as VBoxContainer
	if pause_vbox == null:
		pause_vbox = VBoxContainer.new()
		pause_vbox.name = "PauseVBox"
		pause_panel.add_child(pause_vbox)
		pause_vbox.offset_left = 0
		pause_vbox.offset_top = 0
		pause_vbox.offset_right = 560
		pause_vbox.offset_bottom = 320

	_get_or_create_label(pause_vbox, "PauseLabel", "已暫停（ESC 解除）", Vector2.ZERO)
	resume_button = _get_or_create_button(pause_vbox, "ResumeButton", "繼續")
	back_to_main_menu_button = _get_or_create_button(pause_vbox, "BackToMainMenuButton", "退回主選單")

func _bind_signals() -> void:
	btn1.pressed.connect(func(): _choose_from_button(btn1))
	btn2.pressed.connect(func(): _choose_from_button(btn2))
	btn3.pressed.connect(func(): _choose_from_button(btn3))
	restart_button.pressed.connect(func(): restart_requested.emit())
	restart_button2.pressed.connect(func(): restart_requested.emit())
	resume_button.pressed.connect(func(): _toggle_pause(false))
	back_to_main_menu_button.pressed.connect(func(): back_to_main_menu_requested.emit())

func force_set_paused(paused: bool) -> void:
	_toggle_pause(paused)

func set_hp(hp: int, max_hp: int) -> void:
	hp_label.text = "HP: %d/%d" % [hp, max_hp]
	if hp_bar != null:
		hp_bar.max_value = float(max_hp)
		hp_bar.value = float(hp)

func set_score(score: int) -> void:
	score_label.text = "Score: %d" % score

func set_wave(wave: int, total_waves: int) -> void:
	wave_label.text = "Wave: %d/%d" % [wave, total_waves]

func show_upgrade_menu(options: Array[Dictionary]) -> void:
	upgrade_title.text = "三選一升級"
	upgrade_panel.visible = true

	_config_button(btn1, options[0])
	_config_button(btn2, options[1])
	_config_button(btn3, options[2])

func hide_upgrade_menu() -> void:
	upgrade_panel.visible = false

func _config_button(btn: Button, opt: Dictionary) -> void:
	btn.text = "%s" % str(opt.get("name", opt.get("id", "")))
	btn.set_meta("upgrade_id", opt.get("id", ""))

func _choose_from_button(btn: Button) -> void:
	var id := str(btn.get_meta("upgrade_id"))
	if id == "":
		return
	upgrade_panel.visible = false
	upgrade_chosen.emit(id)

func show_game_over() -> void:
	game_over_panel.visible = true

func hide_game_over() -> void:
	game_over_panel.visible = false

func show_victory(total_score: int) -> void:
	victory_panel.visible = true
	victory_label.text = "恭喜通關！總得分: %d" % total_score

func hide_victory() -> void:
	victory_panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE and k.pressed and not k.echo:
			# 主選單畫面時，ESC 不允許切換暫停（避免遊戲在使用者還沒按「開始遊玩」前就被解除）
			var main_menu := get_node_or_null("../MainMenuLayer") as CanvasLayer
			if main_menu != null and main_menu.visible:
				return
			# 升級/結束畫面時不允許用 ESC 反覆切換暫停
			if upgrade_panel and upgrade_panel.visible:
				return
			if game_over_panel and game_over_panel.visible:
				return
			if victory_panel and victory_panel.visible:
				return
			_toggle_pause(not _is_paused)

func _toggle_pause(paused: bool) -> void:
	if paused == _is_paused:
		return
	_is_paused = paused
	if pause_panel:
		pause_panel.visible = paused
	# 通知 LevelManager 暫停/恢復遊戲邏輯（玩家/敵人/子彈）
	pause_toggled.emit(paused)

func _hide_pause() -> void:
	_is_paused = false
	if pause_panel:
		pause_panel.visible = false


func _on_pause_toggle_pressed() -> void:
	# 模擬桌面版 ESC：升級/結束/勝利畫面時不允許切換暫停
	if upgrade_panel and upgrade_panel.visible:
		return
	if game_over_panel and game_over_panel.visible:
		return
	if victory_panel and victory_panel.visible:
		return
	_toggle_pause(not _is_paused)


func _apply_embedded_cjk_font_theme() -> void:
	_ui_font = load(UI_FONT_PATH) as Font
	if _ui_font == null:
		push_warning("GameUI: 無法載入 UI 字型：%s（中文可能顯示為方塊）" % UI_FONT_PATH)


func _apply_font_to_control(c: Control) -> void:
	if _ui_font == null:
		return
	c.add_theme_font_override("font", _ui_font)
	c.add_theme_font_size_override("font_size", 32)


func _get_or_create_label(parent: Node, name: String, text: String, offset: Vector2) -> Label:
	var l := parent.get_node_or_null(name) as Label
	if l == null:
		l = Label.new()
		l.name = name
		parent.add_child(l)
	l.text = text
	l.position = offset
	_apply_font_to_control(l)
	return l

func _get_or_create_button(parent: Node, name: String, text: String) -> Button:
	var b := parent.get_node_or_null(name) as Button
	if b == null:
		b = Button.new()
		b.name = name
		parent.add_child(b)
	b.text = text
	_apply_font_to_control(b)
	return b

