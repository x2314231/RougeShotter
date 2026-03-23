extends Control
## 虛擬搖桿：左側移動、右側開火／瞄準方向。

enum Role { MOVE, FIRE }

@export var role: Role = Role.MOVE
@export var outer_radius: float = 72.0
@export var knob_radius: float = 22.0

var _center: Vector2 = Vector2.ZERO
var _knob_offset: Vector2 = Vector2.ZERO
var _active_index: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_update_center()
	call_deferred("_refresh_joystick_rect")
	resized.connect(_on_resized)
	visibility_changed.connect(_on_visibility_changed)
	visible = OS.get_name() == "Web" or DisplayServer.is_touchscreen_available()


func _on_resized() -> void:
	_update_center()
	_refresh_joystick_rect()


func _on_visibility_changed() -> void:
	if visible:
		_refresh_joystick_rect()


func _update_center() -> void:
	_center = size * 0.5


func _refresh_joystick_rect() -> void:
	var r := get_global_rect()
	if role == Role.MOVE:
		MobileControls.set_joystick_rect(r)
	else:
		MobileControls.set_fire_joystick_rect(r)


func _draw() -> void:
	var c := _center
	var ring := Color(1, 1, 1, 0.18)
	var hub := Color(1, 1, 1, 0.35)
	var knob := Color(1, 1, 1, 0.45)
	if role == Role.FIRE:
		ring = Color(1.0, 0.55, 0.2, 0.28)
		hub = Color(1.0, 0.65, 0.25, 0.45)
		knob = Color(1.0, 0.72, 0.3, 0.55)
	draw_arc(c, outer_radius, 0.0, TAU, 48, ring, 2.0, true)
	draw_circle(c, 4.0, hub)
	draw_circle(c + _knob_offset, knob_radius, knob)


## Web／行動版：觸控在 _gui_input 常無連續 Drag，改在 _input 統一處理（視窗座標 → 搖桿本地座標）。
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		var pos: Vector2 = st.position
		if st.pressed:
			if _active_index != -1:
				return
			if not get_global_rect().has_point(pos):
				return
			_active_index = st.index
			_set_finger_index(st.index)
			# 注意：ScreenTouch 的 position 是「視窗/螢幕座標」；Control 沒有 to_local()，
			# 直接用全域 rect 的左上角換算成 local 座標。
			var r := get_global_rect()
			var local_p: Vector2 = pos - r.position
			_update_knob_from_local(local_p)
		else:
			if st.index == _active_index:
				_reset_joystick()
	elif event is InputEventScreenDrag:
		if _active_index < 0:
			return
		var sd := event as InputEventScreenDrag
		if sd.index != _active_index:
			return
		var r2 := get_global_rect()
		var local_d: Vector2 = sd.position - r2.position
		_update_knob_from_local(local_d)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			if _active_index != -1:
				return
			if not get_global_rect().has_point(get_global_mouse_position()):
				return
			_active_index = -2
			_set_finger_index(-2)
			_update_knob_from_local(get_local_mouse_position())
		else:
			if _active_index == -2:
				_reset_joystick()
	elif _active_index == -2 and event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_update_knob_from_local(get_local_mouse_position())


func _set_finger_index(i: int) -> void:
	if role == Role.MOVE:
		MobileControls.set_joystick_finger_index(i)
	else:
		MobileControls.set_fire_joystick_finger_index(i)


func _update_knob_from_local(local_pos: Vector2) -> void:
	var offset := local_pos - _center
	if offset.length() > outer_radius and outer_radius > 0.0:
		offset = offset.normalized() * outer_radius
	_knob_offset = offset
	var vec := offset / outer_radius if outer_radius > 0.0 else Vector2.ZERO
	if role == Role.MOVE:
		MobileControls.set_joystick_vector(vec)
	else:
		MobileControls.set_fire_joystick_vector(vec)
	queue_redraw()


func _reset_joystick() -> void:
	_active_index = -1
	_knob_offset = Vector2.ZERO
	if role == Role.MOVE:
		MobileControls.set_joystick_finger_index(-1)
		MobileControls.set_joystick_vector(Vector2.ZERO)
	else:
		MobileControls.set_fire_joystick_finger_index(-1)
		MobileControls.set_fire_joystick_vector(Vector2.ZERO)
	queue_redraw()
