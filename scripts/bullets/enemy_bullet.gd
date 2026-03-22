extends BulletBase
## 敵方子彈：粉紅色，命中玩家與牆面；與發射者互設碰撞例外。

const ENEMY_BULLET_COLOR := Color(1.0, 0.45, 0.78, 1.0)


func setup_enemy(
		shooter: Node2D,
		p_direction: Vector2,
		p_damage: int,
		p_speed: float,
		p_lifetime: float = 2.0
	) -> void:
	_internal_setup(
		"enemy",
		shooter,
		p_direction,
		p_damage,
		p_speed,
		p_lifetime,
		0,
		0,
		0,
		0.0,
		0.0
	)
	_apply_visual_color(ENEMY_BULLET_COLOR)
