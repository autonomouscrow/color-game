@tool
extends Area2D

## Same order as Hue's HueColor enum, so the two can be compared directly
enum ZoneColor { WHITE, RED, BLUE, YELLOW, GREEN }

## Display colors for each ZoneColor; they match Hue's default colors
const FILL_COLORS := [Color(1, 1, 1), Color(0.9, 0.15, 0.15), Color(0.2, 0.4, 1.0), Color(1.0, 0.85, 0.1), Color(0.2, 0.8, 0.25)]

## While Hue overlaps this zone in the same color, enemies act as if Hue isn't there
@export var zone_color := ZoneColor.WHITE:
	set(value):
		zone_color = value
		queue_redraw()
## Full size of the rectangle, centered on the zone's position
@export var size := Vector2(256, 128):
	set(value):
		size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		if shape:
			shape.size = size
		queue_redraw()
## Seconds after Hue spends any MP before this zone hides Hue again
@export var reveal_time := 3.0
## Opacity of the rectangle's fill; the outline is always fully opaque
@export var fill_alpha := 0.25

var shape: RectangleShape2D

func _ready() -> void:
	queue_redraw()
	if Engine.is_editor_hint():
		return
	# Built at runtime so every zone has its own shape and the editor never saves a copy of it
	shape = RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _draw() -> void:
	var rect := Rect2(-size / 2, size)
	var color: Color = FILL_COLORS[zone_color]
	draw_rect(rect, Color(color, fill_alpha))
	draw_rect(rect, color, false, 2.0)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("enter_color_zone"):
		body.enter_color_zone(self)

func _on_body_exited(body: Node2D) -> void:
	if body.has_method("exit_color_zone"):
		body.exit_color_zone(self)
