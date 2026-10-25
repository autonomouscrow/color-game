@tool
extends CanvasLayer

## Hue's health orb and MP diamonds. Values are read every frame from the player's
## `health`, `max_health`, `mp` and `max_mp` properties when it has them, or can be set directly
@export var player: Node

@export var max_health := 100.0:
	set(value):
		max_health = maxf(value, 0.001)
		health = minf(health, max_health)
		_redraw()
@export var health := 100.0:
	set(value):
		health = clampf(value, 0.0, max_health)
		_redraw()
## One diamond is drawn per point of max MP
@export var max_mp := 10:
	set(value):
		max_mp = maxi(value, 0)
		mp = mini(mp, max_mp)
		_redraw()
@export var mp := 10:
	set(value):
		mp = clampi(value, 0, max_mp)
		_redraw()

@export_group("Layout")
## Top-left corner of the health orb, from the top-left of the screen
@export var margin := Vector2(48, 40):
	set(value):
		margin = value
		_redraw()
@export var orb_radius := 63.0:
	set(value):
		orb_radius = value
		_redraw()
@export var orb_outline_width := 4.0:
	set(value):
		orb_outline_width = value
		_redraw()
## Center of the first diamond, measured from the orb's right edge at its vertical center
@export var diamonds_offset := Vector2(38, 0):
	set(value):
		diamonds_offset = value
		_redraw()
## Width and height of each diamond
@export var diamond_size := Vector2(28, 52):
	set(value):
		diamond_size = value
		_redraw()
## Distance between the centers of neighbouring diamonds
@export var diamond_spacing := 26.0:
	set(value):
		diamond_spacing = value
		_redraw()
## Every other diamond is shifted by this much: positive raises the even ones and lowers the odd ones
@export var diamond_zigzag := 44.0:
	set(value):
		diamond_zigzag = value
		_redraw()
@export var diamond_outline_width := 3.0:
	set(value):
		diamond_outline_width = value
		_redraw()

@export_group("Colors")
@export var health_color := Color(1, 1, 1):
	set(value):
		health_color = value
		_redraw()
@export var orb_empty_color := Color(0.75, 0.75, 0.75):
	set(value):
		orb_empty_color = value
		_redraw()
@export var orb_outline_color := Color(0, 0, 0):
	set(value):
		orb_outline_color = value
		_redraw()
@export var mp_color := Color(1, 1, 1):
	set(value):
		mp_color = value
		_redraw()
@export var diamond_empty_color := Color(0.75, 0.75, 0.75):
	set(value):
		diamond_empty_color = value
		_redraw()
@export var diamond_outline_color := Color(0, 0, 0):
	set(value):
		diamond_outline_color = value
		_redraw()

const ORB_POINTS := 64

@onready var canvas: Control = $Canvas

func _ready() -> void:
	canvas.draw.connect(_draw_hud)
	if not player and not Engine.is_editor_hint():
		player = get_tree().get_first_node_in_group("Player")

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not player:
		return
	# Only read the values the player actually has, so the HUD works before they're all added
	for property in ["max_health", "health", "max_mp", "mp"]:
		var value = player.get(property)
		if value != null and value != get(property):
			set(property, value)

func _redraw() -> void:
	if is_node_ready():
		canvas.queue_redraw()

func _draw_hud() -> void:
	var orb_center := margin + Vector2(orb_radius, orb_radius)
	_draw_orb(orb_center)
	var first := orb_center + Vector2(orb_radius, 0) + diamonds_offset
	for i in max_mp:
		var zigzag := -diamond_zigzag if i % 2 == 0 else diamond_zigzag
		_draw_diamond(first + Vector2(i * diamond_spacing, zigzag / 2), i < mp)

func _draw_orb(center: Vector2) -> void:
	canvas.draw_circle(center, orb_radius, orb_empty_color)
	var fill := health / max_health
	# The orb fills by height, not area: the top of the liquid rises linearly with health
	var fill_height := fill * orb_radius * 2
	if fill >= 1.0:
		canvas.draw_circle(center, orb_radius, health_color)
	elif fill_height >= 0.5:
		# Arc of the circle below the fill line; the polygon closes along the line itself
		var line_y := orb_radius - fill_height
		var start := asin(line_y / orb_radius)
		var end := PI - start
		var points := PackedVector2Array()
		for i in ORB_POINTS + 1:
			var angle := lerpf(start, end, float(i) / ORB_POINTS)
			points.append(center + Vector2(cos(angle), sin(angle)) * orb_radius)
		canvas.draw_colored_polygon(points, health_color)
	canvas.draw_arc(center, orb_radius, 0, TAU, ORB_POINTS, orb_outline_color, orb_outline_width, true)

func _draw_diamond(center: Vector2, filled: bool) -> void:
	var half := diamond_size / 2
	var points := PackedVector2Array([
		center + Vector2(0, -half.y),
		center + Vector2(half.x, 0),
		center + Vector2(0, half.y),
		center + Vector2(-half.x, 0),
	])
	canvas.draw_colored_polygon(points, mp_color if filled else diamond_empty_color)
	points.append(points[0])
	canvas.draw_polyline(points, diamond_outline_color, diamond_outline_width, true)
