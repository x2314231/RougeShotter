extends Node2D

# 用於在開發階段用「幾何圖形」快速顯示節點位置（不依賴貼圖）。
@export var radius: float = 14.0
@export var fill_color: Color = Color(0.2, 0.8, 1.0, 1.0)

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, fill_color)

