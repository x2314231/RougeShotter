extends Camera2D
## 以 offset 疊加震動，不影響 Player 每幀設定的 global_position。

@export var trauma_decay: float = 3.2
@export var max_offset: float = 28.0

var _trauma: float = 0.0


func _process(delta: float) -> void:
	if _trauma <= 0.0:
		offset = Vector2.ZERO
		return
	_trauma = maxf(0.0, _trauma - trauma_decay * delta)
	var shake: float = _trauma * _trauma
	offset = Vector2(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	) * shake * max_offset


## 受傷時呼叫；amount 約 0.25～0.55
func add_hit_shake(amount: float = 0.42) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)
