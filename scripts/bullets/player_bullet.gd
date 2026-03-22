extends BulletBase
## 玩家子彈：白色，命中敵人與牆面。

const PLAYER_BULLET_COLOR := Color(1.0, 1.0, 1.0, 1.0)


func setup(
		p_direction: Vector2,
		p_damage: int,
		p_speed: float,
		p_lifetime: float = 2.0,
		p_penetration_left: int = 0,
		p_bounce_left: int = 0,
		p_dot_damage: int = 0,
		p_dot_duration: float = 0.0,
		p_knockback_strength: float = 0.0
	) -> void:
	_internal_setup(
		"player",
		null,
		p_direction,
		p_damage,
		p_speed,
		p_lifetime,
		p_penetration_left,
		p_bounce_left,
		p_dot_damage,
		p_dot_duration,
		p_knockback_strength
	)
	_apply_visual_color(PLAYER_BULLET_COLOR)
