class_name ChromaClone
extends Node2D

## One of the copies of Lord Chroma in the clone pierce ult. Stands upright like Chroma, whichever way it charges, and
## draws its warning strip from its center out along direction, under its body. The clone pierce moves it and
## switches its contact on to charge.

var size := Vector2(80, 160)
var color := Color(1.0, 0.85, 0.1)
var direction := Vector2.RIGHT
var warning_length := 1000.0
var warning_width := 50.0
var warning_color := Color(1, 0, 0, 0.35)
## 0 hides the warning, 1 shows it at warning_color's full opacity
var warning_alpha := 0.0:
	set(value):
		warning_alpha = value
		queue_redraw()

func _ready() -> void:
	z_index = 5

func _draw() -> void:
	if warning_alpha > 0:
		draw_set_transform(Vector2.ZERO, direction.angle())
		draw_rect(Rect2(0, -warning_width / 2, warning_length, warning_width), Color(warning_color, warning_color.a * warning_alpha))
		draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(-size / 2, size), color)
