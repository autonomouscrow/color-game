extends CanvasLayer
## The title screen, shown over everything at startup. The game sits paused behind it and no game keys do anything.
## Start unpauses and closes it. Sound and Controls open MenuSkeff's pages; Space (or that page's own key, O or I)
## comes back here and the game stays paused.
## SkipButton is an invisible button over Lord Chroma: it unlocks every color, puts Hue at the topmost canvas of the
## gauntlet (just below the boss arena), makes that canvas the active spawn point and starts the game there.
## Select SkipButton (or any button) and drag its edges in the 2D view to move or resize it.

@export_group("Background")
@export var background_image: Texture2D  ## The title screen picture, stretched to fill the screen

@export_group("Buttons")
## Color laid over Start, Sound and Controls while the mouse is on them (the buttons themselves are drawn in the picture)
@export var hover_color := Color(1, 1, 1, 0.18)
## Color laid over them while held down
@export var pressed_color := Color(1, 1, 1, 0.3)
@export var show_skip_hover := false  ## Turn on to see the skip button light up under the mouse, handy while resizing it

@export_group("Skip To Boss")
@export var skip_room := "Gauntlet"  ## Room id (a key in RoomControl's room_scenes) the skip button loads
@export var skip_door := "Canvas3"  ## Node in that room Hue is placed on (Canvas3 is the gauntlet's topmost canvas)
@export var skip_spawn_point := "Canvas3"  ## Canvas in that room set as the active spawn point, so Hue respawns there after dying
@export var skip_unlock_all_colors := true  ## Turns on every color in Hue's CanColor

@export_group("Timing")
@export_range(0.0, 5.0, 0.05) var fade_out_time := 0.4  ## Seconds for the title screen to fade away once the game starts

@onready var _root: Control = $Root
@onready var _background: TextureRect = $Root/Background
@onready var _start: Button = $Root/StartButton
@onready var _sound: Button = $Root/SoundButton
@onready var _controls: Button = $Root/ControlsButton
@onready var _skip: Button = $Root/SkipButton

var _leaving := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if background_image:
		_background.texture = background_image
	for button in [_start, _sound, _controls]:
		_style_button(button, hover_color, pressed_color)
	_style_button(_skip, hover_color if show_skip_hover else Color(0, 0, 0, 0), pressed_color if show_skip_hover else Color(0, 0, 0, 0))
	_start.pressed.connect(_on_start_pressed)
	_sound.pressed.connect(_open_page.bind(2))  # MenuSkeff.Menu.SOUND
	_controls.pressed.connect(_open_page.bind(1))  # MenuSkeff.Menu.CONTROLS
	_skip.pressed.connect(_on_skip_pressed)
	var menus := _menu_skeff()
	if menus:
		menus.back_to_start.connect(_on_back_to_start)
	Pause.menu_open = true
	Pause.set_paused(true)

## Mouse-only, see-through button: no keyboard focus, so Space and arrows never press it
func _style_button(button: Button, hover: Color, pressed: Color) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.text = ""
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", _flat(hover))
	button.add_theme_stylebox_override("pressed", _flat(pressed))
	button.add_theme_stylebox_override("hover_pressed", _flat(pressed))

func _flat(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	return style

func _menu_skeff() -> Node:
	return get_tree().get_first_node_in_group("MenuSkeff")

func _open_page(menu: int) -> void:
	var menus := _menu_skeff()
	if not menus or _leaving:
		return
	visible = false
	menus.open_from_start(menu)

func _on_back_to_start() -> void:
	visible = true

func _on_start_pressed() -> void:
	_start_game()

func _on_skip_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	var hue := get_tree().get_first_node_in_group("Player")
	if hue and skip_unlock_all_colors:
		var colors = hue.get("CanColor")
		if colors is Array:
			for i in colors.size():
				colors[i] = true
	if hue is CharacterBody2D:
		hue.velocity = Vector2.ZERO
	var spawn := get_tree().get_first_node_in_group("spawnSkeff")
	if spawn:
		spawn.SetSpawn(skip_room, skip_spawn_point)
	var rooms := get_tree().get_first_node_in_group("RoomControl")
	if rooms:
		await rooms.change_room(skip_room, skip_door)
	_leaving = false
	_start_game()

func _start_game() -> void:
	if _leaving:
		return
	_leaving = true
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, fade_out_time)
	tween.tween_callback(func():
		Pause.menu_open = false
		Pause.set_paused(false)
		queue_free()
	)
