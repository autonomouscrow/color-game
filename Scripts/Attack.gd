class_name Attack
extends Area2D

## Damage dealt to each enemy this hitbox touches; each enemy is only hit once per hitbox, however long it stays inside
@export var damage := 15.0
## On: extends from zero to full size over extend_time, stays for hold_time, then frees itself (punch, uppercut).
## Off: stays until Hue removes it, and Hue sets its shape every frame with set_rect (slide, slam, dive).
@export var timed := true
@export_group("Timed")
## Full size of the hitbox once it has finished extending
@export var size := Vector2(53, 48)
## Seconds to extend from zero length at Hue's side out to full size
@export var extend_time := 0.1
## Seconds the hitbox stays at full size before it disappears
@export var hold_time := 0.1
## Which way the hitbox extends from its origin: right, left or up; set by Hue before it's added
@export var direction := Vector2.RIGHT
@export_group("")

@onready var hitbox: CollisionShape2D = $Hitbox
@onready var color_rect: ColorRect = $Color

var hitbox_shape: RectangleShape2D
var time := 0.0
var hit_enemies: Array[Node] = []

func _ready() -> void:
	# Own copy of the shape so resizing it doesn't affect other hitboxes
	hitbox_shape = hitbox.shape.duplicate()
	hitbox.shape = hitbox_shape
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	if timed:
		_apply_length(0.0)

func _physics_process(delta: float) -> void:
	if not timed:
		return
	time += delta
	if time >= extend_time + hold_time:
		queue_free()
		return
	var progress := 1.0 if extend_time <= 0 else minf(time / extend_time, 1.0)
	_apply_length(progress)

func _apply_length(progress: float) -> void:
	# The origin is the edge nearest Hue; only the side facing direction grows, away from Hue
	var current_size := size
	if direction.x != 0:
		current_size.x *= progress
	else:
		current_size.y *= progress
	var center := direction * current_size / 2
	set_rect(Rect2(center - current_size / 2, current_size))

func set_rect(rect: Rect2) -> void:
	hitbox_shape.size = rect.size
	hitbox.position = rect.get_center()
	color_rect.size = rect.size
	color_rect.position = rect.position

func _on_area_entered(area: Area2D) -> void:
	# Only an enemy's hurtbox counts, so its other areas (like a detection range) don't get hit
	var target := area.get_parent()
	if target is enemy and target.hurtbox == area:
		_hit(target)

func _on_body_entered(body: Node2D) -> void:
	# Enemies without a hurtbox are hit on their own body
	if body is enemy and body.hurtbox == null:
		_hit(body)

func _hit(target: enemy) -> void:
	if target in hit_enemies:
		return
	hit_enemies.append(target)
	target.take_damage(damage)
