extends Node2D

## Lord Chroma's entrance. Chroma starts hidden and switched off (no moves, no hitbox, no health bar). Once Hue has
## walked trigger_distance into the arena, Chroma appears spawn_offset in front of Hue, the title image
## shows, and the whole game freezes for freeze_time while the title fades away. Then the fight starts.
## Put this node after LordChroma in the scene tree so Chroma's own _ready (which builds his health bar) runs first.

## The boss to hide until the intro plays
@export var boss: LordChroma
## The arena's inside, in the room's own coordinates (the parent node's). Hue's walk is measured from where Hue is
## first seen inside it
@export var arena_rect := Rect2(1496, -21067, 1920, 900)

@export_group("Trigger")
## How far Hue has to walk (sideways, in pixels) from where Hue entered before Chroma shows up
@export var trigger_distance := 200.0

@export_group("Spawn")
## Where Chroma appears: x is how far in front of Hue (in the way Hue is facing), y is added to Chroma's height as placed
## in the scene
@export var spawn_offset := Vector2(350, 0)
## Chroma never spawns closer than this to the arena's left or right edge; if the spot in front of Hue is too close,
## he spawns behind Hue instead
@export var spawn_edge_margin := 100.0

@export_group("Freeze")
## How long the game stays frozen while the title shows
@export var freeze_time := 3.0

@export_group("Title")
## The title image shown during the freeze; drop a PNG here. Nothing shows if it's empty
@export var title_image: Texture2D
## Multiplies the image's own size on screen
@export var title_image_scale := 1.0
## Where the title sits on screen, from 0 (top) to 1 (bottom)
@export_range(0, 1) var title_screen_height := 0.35
## Seconds for the title to fade in
@export var title_fade_in_time := 0.3
## Seconds the title stays fully shown before it starts to fade
@export var title_hold_time := 1.0
## Seconds for the title to dissipate (fade out while growing); fade in + hold + this should add up to freeze_time
@export var title_fade_out_time := 1.7
## How big the title grows to as it dissipates
@export var title_end_scale := 1.4

var player: Node2D
var entered := false
var entry_x := 0.0
var done := false

func _ready() -> void:
	if boss == null:
		done = true
		return
	_set_boss_active(false)

func _physics_process(_delta: float) -> void:
	if done:
		return
	if not is_instance_valid(boss):
		done = true
		return
	# Beaten on an earlier visit: no entrance, just put him back
	if boss.dead:
		_set_boss_active(true)
		done = true
		return
	player = get_tree().get_first_node_in_group("Player") as Node2D
	if player == null:
		return
	if not _arena().has_point(player.global_position):
		return
	if not entered:
		entered = true
		entry_x = player.global_position.x
		return
	if absf(player.global_position.x - entry_x) >= trigger_distance:
		_play_intro()

func _play_intro() -> void:
	done = true
	var facing := 1.0
	var hue_facing = player.get("facing")
	if hue_facing is float or hue_facing is int:
		facing = signf(hue_facing) if hue_facing != 0 else 1.0
	var arena := _arena()
	var left := arena.position.x + spawn_edge_margin
	var right := arena.end.x - spawn_edge_margin
	var x := player.global_position.x + facing * spawn_offset.x
	if x < left or x > right:
		x = clampf(player.global_position.x - facing * spawn_offset.x, left, right)
	boss.global_position = Vector2(x, boss.global_position.y + spawn_offset.y)
	boss.velocity = Vector2.ZERO
	_set_boss_active(true)
	boss.face_toward(player.global_position.x)
	_show_title()
	Pause.hitstop(freeze_time)

## arena_rect in world coordinates
func _arena() -> Rect2:
	var room := get_parent() as Node2D
	if room == null:
		return arena_rect
	return Rect2(room.to_global(arena_rect.position), arena_rect.size * room.global_scale.abs())

## Hides Chroma and takes him out of processing and physics, or brings him back
func _set_boss_active(on: bool) -> void:
	boss.visible = on
	boss.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	# His health bar lives on a CanvasLayer, which doesn't follow his visibility
	for child in boss.get_children():
		if child is CanvasLayer:
			child.visible = on

func _show_title() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var title := TextureRect.new()
	title.texture = title_image
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var image_size: Vector2 = title_image.get_size() * title_image_scale if title_image else Vector2.ZERO
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.anchor_top = title_screen_height
	title.anchor_bottom = title_screen_height
	title.offset_left = -image_size.x / 2
	title.offset_right = image_size.x / 2
	title.offset_top = -image_size.y / 2
	title.offset_bottom = image_size.y / 2
	title.pivot_offset = image_size / 2
	title.modulate.a = 0.0
	layer.add_child(title)

	# The tween belongs to the always-processing layer, so it keeps running through the freeze
	var tween := layer.create_tween()
	tween.tween_property(title, "modulate:a", 1.0, title_fade_in_time)
	tween.tween_interval(title_hold_time)
	tween.tween_property(title, "modulate:a", 0.0, title_fade_out_time).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(title, "scale", Vector2.ONE * title_end_scale, title_fade_out_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(layer.queue_free)
