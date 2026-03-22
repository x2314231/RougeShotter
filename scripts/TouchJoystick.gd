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


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if _active_index != -1:
				return
			_active_index = st.index
			_set_finger_index(st.index)
			_update_knob_from_local(st.position)
			accept_event()
		else:
			if st.index == _active_index:
				_reset_joystick()
				accept_event()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _active_index:
			_update_knob_from_local(sd.position)
			accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_active_index = -2
				_set_finger_index(-2)
				_update_knob_from_local(mb.position)
			else:
				if _active_index == -2:
					_reset_joystick()
			accept_event()


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
