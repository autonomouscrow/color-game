class_name Attack
extends Area2D

## Emitted once, on the frame a timed hitbox reaches full size; the Diver's parry check uses the uppercut's
signal fully_extended

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
@export_group("Effect")
## Animation to play from the Effect node (an AnimatedSprite2D child); nothing happens if there's no Effect node or it has no frames yet
@export var effect_animation := &"default"
## On: the effect is stretched to cover the hitbox's full size, so art drawn for the hitbox lines up with it
@export var effect_fit_to_hitbox := true
## Extra scale on top of the fit (or the only scale, with fitting off)
@export var effect_scale := Vector2.ONE
## Nudges the effect from the hitbox's center, in the facing-right / upward orientation (x is mirrored when facing left)
@export var effect_offset := Vector2.ZERO
## On: the animation's speed is changed so it plays exactly once over extend_time + hold_time; off: it plays at its own FPS and is cut off when the hitbox disappears
@export var effect_fit_lifetime := true
## On: the red debug ColorRect is hidden once the effect has frames
@export var hide_color_with_effect := true
@export_group("")

@onready var hitbox: CollisionShape2D = $Hitbox
## Optional; a sprite attack like Bullet has none
@onready var color_rect: ColorRect = get_node_or_null("Color")
## Optional AnimatedSprite2D that plays the hitbox's drawn effect
@onready var effect: AnimatedSprite2D = get_node_or_null("Effect")

var hitbox_shape: RectangleShape2D
var time := 0.0
var hit_enemies: Array[Node] = []
var extended := false

func _ready() -> void:
	# Own copy of the shape so resizing it doesn't affect other hitboxes
	hitbox_shape = hitbox.shape.duplicate()
	hitbox.shape = hitbox_shape
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	if timed:
		_apply_length(0.0)
	_start_effect()

## Places the effect over the hitbox's full area and plays it once; the hitbox growing doesn't move it
func _start_effect() -> void:
	if effect == null or effect.sprite_frames == null:
		return
	var frames := effect.sprite_frames
	if not frames.has_animation(effect_animation) or frames.get_frame_count(effect_animation) == 0:
		effect.visible = false
		return
	if color_rect and hide_color_with_effect:
		color_rect.visible = false
	effect.visible = true
	effect.centered = true
	var flip := direction.x < 0
	effect.flip_h = flip
	var scale_fit := Vector2.ONE
	var texture := frames.get_frame_texture(effect_animation, 0)
	if effect_fit_to_hitbox and texture and texture.get_width() > 0 and texture.get_height() > 0:
		scale_fit = size / texture.get_size()
	effect.scale = scale_fit * effect_scale
	var offset := effect_offset
	if flip:
		offset.x = -offset.x
	effect.position = direction * size / 2 + offset
	effect.speed_scale = 1.0
	var lifetime := extend_time + hold_time
	if effect_fit_lifetime and timed and lifetime > 0:
		var anim_length := _effect_length(frames)
		if anim_length > 0:
			effect.speed_scale = anim_length / lifetime
	effect.play(effect_animation)

## Seconds the effect animation lasts at speed_scale 1
func _effect_length(frames: SpriteFrames) -> float:
	var fps := frames.get_animation_speed(effect_animation)
	if fps <= 0:
		return 0.0
	var total := 0.0
	for i in frames.get_frame_count(effect_animation):
		total += frames.get_frame_duration(effect_animation, i)
	return total / fps

func _physics_process(delta: float) -> void:
	if not timed:
		return
	time += delta
	if time >= extend_time + hold_time:
		queue_free()
		return
	var progress := 1.0 if extend_time <= 0 else minf(time / extend_time, 1.0)
	_apply_length(progress)
	if progress >= 1.0 and not extended:
		extended = true
		fully_extended.emit()

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
	if color_rect:
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
	var health_before: int = target.health
	target.take_damage(damage)
	# Hue gains MP only when this hit is the one that kills the enemy
	var receiver := _kill_receiver()
	if health_before > 0 and target.health <= 0 and is_instance_valid(receiver) and receiver.has_method("on_attack_kill"):
		receiver.on_attack_kill()

## Who gets on_attack_kill: the hitbox's parent (Hue) by default; a bullet isn't Hue's child, so it overrides this
func _kill_receiver() -> Node:
	return get_parent()
