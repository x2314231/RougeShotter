extends Control
## 全螢幕地形背景：每 3 關（Wave）切換一種風格。
## Wave 1–3 → 主題 0，4–6 → 1，7–9 → 2，Wave 10（Boss）→ 主題 3

var _theme_idx: int = 0
var _stars: Array[Vector2] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_stars_for_theme(0)


func set_for_wave(wave: int) -> void:
	var w: int = maxi(1, wave)
	_theme_idx = int((w - 1) / 3)
	_theme_idx = clampi(_theme_idx, 0, 3)
	_fill_stars_for_theme(_theme_idx)
	queue_redraw()


func _fill_stars_for_theme(theme: int) -> void:
	_stars.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(8200 + theme * 199)
	var n_stars: int = 36 if theme != 1 else 18
	for i in range(n_stars):
		_stars.append(Vector2(rng.randf(), rng.randf() * 0.42))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var s: Vector2 = size
	if s.x < 4.0:
		s = get_viewport_rect().size
	if s.x < 4.0:
		return

	var pal: Dictionary = _palette(_theme_idx)
	_draw_sky_gradient(s, pal.sky_top, pal.sky_bot)
	if pal.stars:
		_draw_stars(s, pal.star_color)
	_draw_ground_mass(s, pal)
	_draw_silhouette(s, pal, _theme_idx)


func _palette(idx: int) -> Dictionary:
	match idx:
		0:
			# 深空荒原
			return {
				"sky_top": Color(0.03, 0.04, 0.09, 1.0),
				"sky_bot": Color(0.1, 0.11, 0.2, 1.0),
				"ground_a": Color(0.07, 0.08, 0.12, 1.0),
				"ground_b": Color(0.05, 0.06, 0.1, 1.0),
				"ridge": Color(0.04, 0.05, 0.09, 1.0),
				"accent": Color(0.15, 0.18, 0.28, 0.35),
				"stars": true,
				"star_color": Color(0.85, 0.9, 1.0, 0.55),
				"grid": true,
			}
		1:
			# 鏽色荒谷
			return {
				"sky_top": Color(0.18, 0.09, 0.05, 1.0),
				"sky_bot": Color(0.35, 0.22, 0.12, 1.0),
				"ground_a": Color(0.22, 0.14, 0.08, 1.0),
				"ground_b": Color(0.14, 0.1, 0.06, 1.0),
				"ridge": Color(0.1, 0.07, 0.05, 1.0),
				"accent": Color(0.4, 0.28, 0.15, 0.25),
				"stars": false,
				"star_color": Color.WHITE,
				"grid": false,
			}
		2:
			# 霓虹遺跡
			return {
				"sky_top": Color(0.04, 0.12, 0.14, 1.0),
				"sky_bot": Color(0.12, 0.06, 0.22, 1.0),
				"ground_a": Color(0.06, 0.1, 0.12, 1.0),
				"ground_b": Color(0.05, 0.06, 0.14, 1.0),
				"ridge": Color(0.1, 0.05, 0.18, 1.0),
				"accent": Color(0.2, 0.85, 0.75, 0.12),
				"stars": true,
				"star_color": Color(0.6, 0.95, 0.9, 0.45),
				"grid": true,
			}
		_:
			# Boss 風暴競技
			return {
				"sky_top": Color(0.08, 0.02, 0.06, 1.0),
				"sky_bot": Color(0.28, 0.05, 0.1, 1.0),
				"ground_a": Color(0.12, 0.04, 0.08, 1.0),
				"ground_b": Color(0.06, 0.02, 0.05, 1.0),
				"ridge": Color(0.04, 0.02, 0.04, 1.0),
				"accent": Color(0.9, 0.2, 0.35, 0.2),
				"stars": true,
				"star_color": Color(1.0, 0.4, 0.45, 0.5),
				"grid": false,
			}


func _draw_sky_gradient(s: Vector2, top: Color, bot: Color) -> void:
	var steps: int = 56
	for i in range(steps):
		var t: float = float(i) / float(steps - 1)
		var c: Color = top.lerp(bot, t)
		var y0: float = s.y * float(i) / float(steps)
		var y1: float = s.y * float(i + 1) / float(steps)
		draw_rect(Rect2(0, y0, s.x, y1 - y0 + 1.0), c)


func _draw_stars(s: Vector2, c: Color) -> void:
	for p in _stars:
		var pos: Vector2 = Vector2(p.x * s.x, p.y * s.y)
		draw_rect(Rect2(pos, Vector2(2, 2)), c)
		draw_rect(Rect2(pos + Vector2(1, 0), Vector2(1, 1)), c)


func _draw_ground_mass(s: Vector2, pal: Dictionary) -> void:
	var y0: float = s.y * 0.52
	draw_rect(Rect2(0, y0, s.x, s.y - y0 + 2.0), pal.ground_a)
	draw_rect(Rect2(0, y0 + s.y * 0.12, s.x, s.y), pal.ground_b)


func _draw_silhouette(s: Vector2, pal: Dictionary, seed_theme: int) -> void:
	var base_y: float = s.y * 0.52
	var pts: PackedVector2Array = PackedVector2Array()
	pts.append(Vector2(0, s.y + 4))
	pts.append(Vector2(0, base_y + _h(0.0, seed_theme)))
	var seg: int = 28
	for i in range(seg + 1):
		var xf: float = float(i) / float(seg)
		var x: float = xf * s.x
		pts.append(Vector2(x, base_y + _h(xf, seed_theme)))
	pts.append(Vector2(s.x, s.y + 4))
	_draw_poly_solid(pts, pal.ridge)

	var pts2: PackedVector2Array = PackedVector2Array()
	var base2: float = base_y + s.y * 0.06
	pts2.append(Vector2(0, s.y + 4))
	pts2.append(Vector2(0, base2 + _h2(0.0, seed_theme)))
	for i in range(seg + 1):
		var xf2: float = float(i) / float(seg)
		var x2: float = xf2 * s.x
		pts2.append(Vector2(x2, base2 + _h2(xf2, seed_theme)))
	pts2.append(Vector2(s.x, s.y + 4))
	_draw_poly_solid(pts2, pal.ground_a)

	if pal.accent.a > 0.01:
		for i in range(5):
			var xx: float = s.x * (0.12 + float(i) * 0.18)
			var yy: float = base_y + s.y * 0.08 + sin(xx * 0.01 + float(seed_theme)) * 12.0
			draw_line(Vector2(xx, yy), Vector2(xx + 40, yy - 20), pal.accent, 3.0)

	if pal.get("grid", false):
		_draw_grid(s, Color(1, 1, 1, 0.04))


func _draw_poly_solid(pts: PackedVector2Array, c: Color) -> void:
	var cols := PackedColorArray()
	for _i in range(pts.size()):
		cols.append(c)
	draw_polygon(pts, cols)


func _h(xf: float, t: int) -> float:
	return sin(xf * TAU * 1.8 + float(t) * 1.3) * 18.0 + sin(xf * TAU * 4.1) * 8.0 + cos(xf * 12.0 + float(t)) * 5.0


func _h2(xf: float, t: int) -> float:
	return sin(xf * TAU * 2.2 + float(t)) * 12.0 + sin(xf * TAU * 6.0) * 5.0


func _draw_grid(s: Vector2, c: Color) -> void:
	var step: float = 48.0
	var y: float = fposmod(s.y * 0.35, step)
	while y < s.y:
		draw_line(Vector2(0, y), Vector2(s.x, y), c, 1.0)
		y += step
	var x: float = fposmod(s.x * 0.2, step)
	while x < s.x:
		draw_line(Vector2(x, 0), Vector2(x, s.y), c, 1.0)
		x += step
