extends Node
## 手機／網頁觸控：左搖桿移動、右搖桿瞄準／開火方向 + 空白處觸控瞄準。
## 鍵盤移動改由 InputMap（move_*）處理，見 _setup_input_map。

var joystick_vector: Vector2 = Vector2.ZERO
var _joystick_finger_index: int = -1
var _joystick_rect: Rect2 = Rect2()

## 右側開火搖桿：推動方向 = 射擊方向（非零時持續開火，見 Player）
var fire_joystick_vector: Vector2 = Vector2.ZERO
var _fire_joystick_finger_index: int = -1
var _fire_joystick_rect: Rect2 = Rect2()

var aim_world_pos: Vector2 = Vector2.ZERO
var has_touch_aim: bool = false
var _aim_touch_index: int = -1


func _ready() -> void:
	_setup_input_map()


func _setup_input_map() -> void:
	_ensure_action("move_left", [KEY_A, KEY_LEFT])
	_ensure_action("move_right", [KEY_D, KEY_RIGHT])
	_ensure_action("move_up", [KEY_W, KEY_UP])
	_ensure_action("move_down", [KEY_S, KEY_DOWN])


func _ensure_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.5)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key as Key
		InputMap.action_add_event(action, ev)


func set_joystick_vector(v: Vector2) -> void:
	joystick_vector = v


func set_joystick_finger_index(i: int) -> void:
	_joystick_finger_index = i


func set_joystick_rect(r: Rect2) -> void:
	_joystick_rect = r


func set_fire_joystick_vector(v: Vector2) -> void:
	fire_joystick_vector = v


func set_fire_joystick_finger_index(i: int) -> void:
	_fire_joystick_finger_index = i


func set_fire_joystick_rect(r: Rect2) -> void:
	_fire_joystick_rect = r


func is_fire_joystick_active() -> bool:
	return fire_joystick_vector.length_squared() > 0.0001


func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	var idx := _get_event_index(event)
	if idx == _joystick_finger_index:
		return
	if idx == _fire_joystick_finger_index:
		return
	var pos: Vector2 = event.position
	if _joystick_rect.has_point(pos):
		return
	if _fire_joystick_rect.has_point(pos):
		return
	var world := _screen_to_world(pos)
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_aim_touch_index = idx
			has_touch_aim = true
			aim_world_pos = world
		else:
			if idx == _aim_touch_index:
				_aim_touch_index = -1
				has_touch_aim = false
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _aim_touch_index:
			aim_world_pos = world


func _get_event_index(event: InputEvent) -> int:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).index
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).index
	return -1


func _screen_to_world(screen: Vector2) -> Vector2:
	var inv := get_viewport().get_canvas_transform().affine_inverse()
	return inv * screen
