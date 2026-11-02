extends CanvasLayer
## CreditsSkeff: the end credits. Put one in Main.
## When Lord Chroma dies, the boss music fades out. credits_delay seconds after his death animation ends, the credits
## image fades in over everything, the normal music fades back in, and the image scrolls down to its bottom.
## When it reaches the end, the screen fades to black and the whole game restarts from the title screen.
## The game stays paused while the credits are up, so nothing behind them moves and no keys do anything.

@export var credits_image: Texture2D  ## The tall credits picture; stretched to the screen's width and scrolled from its top to its bottom

@export_group("Timing")
@export_range(0.0, 30.0, 0.1) var credits_delay := 5.0  ## Seconds after Chroma's death animation finishes before the credits show
@export_range(0.0, 10.0, 0.1) var boss_music_fade_time := 2.0  ## Seconds for the boss music to fade out once Chroma dies
@export_range(0.0, 10.0, 0.1) var fade_in_time := 1.5  ## Seconds for the credits to fade in over the game
@export_range(0.0, 10.0, 0.1) var hold_top_time := 2.0  ## Seconds the top of the credits stays still before scrolling
@export_range(1.0, 2000.0, 1.0) var scroll_speed := 60.0  ## How fast the credits scroll, in screen pixels per second
@export_range(0.0, 10.0, 0.1) var hold_bottom_time := 3.0  ## Seconds the bottom of the credits stays still before the game resets
@export_range(0.0, 10.0, 0.1) var fade_out_time := 1.5  ## Seconds to fade to black before the game resets

@onready var _root: Control = $Root
@onready var _image: TextureRect = $Root/CreditsImage
@onready var _fade: ColorRect = $Root/FadeToBlack

var _started := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("CreditsSkeff")
	if credits_image:
		_image.texture = credits_image
	_root.visible = false
	# Rooms are loaded and freed as Hue moves, so catch every Lord Chroma as it enters the tree
	get_tree().node_added.connect(_on_node_added)
	for node in get_tree().root.find_children("*", "", true, false):
		_on_node_added(node)

func _on_node_added(node: Node) -> void:
	if node is LordChroma and not node.has_meta(&"credits_hooked"):
		node.set_meta(&"credits_hooked", true)
		node.defeated.connect(_on_chroma_defeated.bind(node))

func _on_chroma_defeated(chroma: LordChroma) -> void:
	if _started:
		return
	_started = true
	var audio := get_tree().get_first_node_in_group("AudioSkeff")
	if audio and audio.has_method("fade_out_boss_music"):
		audio.fade_out_boss_music(boss_music_fade_time)
	# These timers stop while the game is paused or frozen, so the wait matches what's on screen
	await get_tree().create_timer(_death_length(chroma) + credits_delay, false).timeout
	play()

## How long Chroma's death animation lasts, in seconds
func _death_length(chroma: LordChroma) -> float:
	if not is_instance_valid(chroma):
		return 0.0
	var player: AnimationPlayer = chroma.animation_player
	if player == null or not player.has_animation(&"death"):
		return 0.0
	var speed := absf(player.speed_scale) if player.speed_scale != 0 else 1.0
	return player.get_animation(&"death").length / speed

## Shows the credits right away; also callable from anywhere for testing
func play() -> void:
	_started = true
	Pause.menu_open = true
	Pause.set_paused(true)
	var audio := get_tree().get_first_node_in_group("AudioSkeff")
	if audio and audio.has_method("start_credits_music"):
		audio.start_credits_music()

	var screen := get_viewport().get_visible_rect().size
	var tex_size := _image.texture.get_size() if _image.texture else screen
	var height := screen.x * tex_size.y / maxf(tex_size.x, 1.0)
	_image.position = Vector2.ZERO
	_image.size = Vector2(screen.x, height)
	var end_y := minf(screen.y - height, 0.0)
	_fade.color.a = 0.0
	_root.modulate.a = 0.0
	_root.visible = true

	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 1.0, fade_in_time)
	tween.tween_interval(hold_top_time)
	tween.tween_property(_image, "position:y", end_y, absf(end_y) / scroll_speed)
	tween.tween_interval(hold_bottom_time)
	tween.tween_property(_fade, "color:a", 1.0, fade_out_time)
	tween.tween_callback(_reset_game)

func _reset_game() -> void:
	Pause.menu_open = false
	Pause.set_paused(false)
	get_tree().reload_current_scene()
