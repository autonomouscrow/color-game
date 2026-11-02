extends CanvasLayer
## MenuSkeff: the in-game menus. Put one in Main.
## I toggles the controls menu, O the sound menu, M the map. Space closes whichever is open.
## Each menu is a full-screen black screen that pauses the game while it's up, and unpauses when closed.
## Pressing another menu's key while one is open switches straight to it (the game stays paused).
## The sound menu has three sliders, each -30 to +30 dB starting at 0, wired to AudioSkeff:
## Master sets master_volume_db (added to every sound), Music sets music_volume_db (normal and boss music),
## and SFX sets attack_sound_volume_db, hurt_sound_volume_db and ability_volume_db (every other sound).
## The title screen opens the controls and sound pages with open_from_start(). Those pages then only close: Space or the
## page's own key goes back to the title screen (back_to_start is emitted), the game stays paused, and other keys do nothing.
## Power windows: show_power(color) opens the explanation picture for a color the first time Hue gains it from a crystal.
## They pause like the other menus and only Space closes them; the menu keys do nothing while one is up.

signal back_to_start

enum Menu { NONE, CONTROLS, SOUND, MAP, POWER }

@export_group("Keys")
@export var controls_key: Key = KEY_I  ## Toggles the controls menu
@export var sound_key: Key = KEY_O  ## Toggles the sound menu
@export var map_key: Key = KEY_M  ## Toggles the map
@export var close_key: Key = KEY_SPACE  ## Closes whichever menu is open

@export_group("Sound Menu")
@export var sound_background: Texture2D  ## Full-screen picture behind the sliders, stretched to fill the screen; leave empty for plain black.
## The sliders sit on the right like the mock-up: move them by selecting MasterSlider/MusicSlider/SFXSlider and changing their anchors
@export var master_fill_color := Color(0.6, 0.0, 1.0)  ## Filled part of the Master bar (left of the handle)
@export var music_fill_color := Color(1.0, 0.0, 1.0)  ## Filled part of the Music bar
@export var sfx_fill_color := Color(0.0, 1.0, 1.0)  ## Filled part of the SFX bar
@export var track_color := Color(1, 1, 1)  ## Empty part of every bar (right of the handle)
@export var track_height := 12  ## Thickness of the bars in pixels
@export var master_handle: Texture2D  ## Sprite for the Master slider's handle
@export var music_handle: Texture2D  ## Sprite for the Music slider's handle
@export var sfx_handle: Texture2D  ## Sprite for the SFX slider's handle
@export var handle_size := 48  ## Width in pixels the handle sprites are scaled to (height keeps their shape); 0 draws them at their own size
@export_range(-30.0, 30.0, 0.5) var slider_min_db := -30.0  ## Lowest dB a slider can reach
@export_range(-30.0, 30.0, 0.5) var slider_max_db := 30.0  ## Highest dB a slider can reach
@export_range(0.1, 5.0, 0.1) var slider_step_db := 0.5  ## dB per slider notch

@export_group("Map")
@export var map_image: Texture2D  ## Picture shown on the map screen; leave empty for plain black

@export_group("Power Windows")
## Picture shown the first time Hue gains each color, fitted to the screen with its aspect kept. A crystal's own tutorial slot overrides these.
@export var red_power_image: Texture2D
@export var blue_power_image: Texture2D
@export var yellow_power_image: Texture2D
@export var green_power_image: Texture2D

@onready var _power: Control = $PowerMenu
@onready var _power_image: TextureRect = $PowerMenu/PowerImage
@onready var _controls: Control = $ControlsMenu
@onready var _sound: Control = $SoundMenu
@onready var _map: Control = $MapMenu
@onready var _sound_bg: TextureRect = $SoundMenu/Background
@onready var _map_image: TextureRect = $MapMenu/MapImage
@onready var _master_slider: HSlider = $SoundMenu/MasterSlider
@onready var _music_slider: HSlider = $SoundMenu/MusicSlider
@onready var _sfx_slider: HSlider = $SoundMenu/SFXSlider

var _open := Menu.NONE
var _from_start := false  # The open page came from the title screen
var _powers_shown := {}  # Colors (Hue.HueColor ints) whose power window has already been shown

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("MenuSkeff")
	# A texture set directly on the node in the scene is kept if the export slot is empty
	if sound_background:
		_sound_bg.texture = sound_background
	if map_image:
		_map_image.texture = map_image
	_setup_slider(_master_slider, master_handle, master_fill_color, func(db: float): _set_audio(["master_volume_db"], db))
	_setup_slider(_music_slider, music_handle, music_fill_color, func(db: float): _set_audio(["music_volume_db"], db))
	_setup_slider(_sfx_slider, sfx_handle, sfx_fill_color, func(db: float): _set_audio(["attack_sound_volume_db", "hurt_sound_volume_db", "ability_volume_db"], db))
	_show(Menu.NONE)

func _setup_slider(slider: HSlider, handle: Texture2D, fill: Color, apply: Callable) -> void:
	slider.add_theme_stylebox_override("slider", _bar_style(track_color))
	slider.add_theme_stylebox_override("grabber_area", _bar_style(fill))
	slider.add_theme_stylebox_override("grabber_area_highlight", _bar_style(fill))
	handle = _sized_handle(handle)
	if handle:
		slider.add_theme_icon_override("grabber", handle)
		slider.add_theme_icon_override("grabber_highlight", handle)
		slider.add_theme_icon_override("grabber_disabled", handle)
	slider.min_value = slider_min_db
	slider.max_value = slider_max_db
	slider.step = slider_step_db
	slider.value = 0.0
	apply.call(0.0)
	slider.value_changed.connect(apply)

## A copy of handle scaled to handle_size wide, since a slider draws its grabber at the texture's own size
func _sized_handle(handle: Texture2D) -> Texture2D:
	if handle == null or handle_size <= 0 or handle.get_width() == handle_size:
		return handle
	var image := handle.get_image()
	if image == null:
		return handle
	if image.is_compressed():
		image.decompress()
	var height := maxi(1, roundi(float(handle_size) * image.get_height() / image.get_width()))
	image.resize(handle_size, height, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)

func _bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.content_margin_top = track_height / 2.0
	style.content_margin_bottom = track_height / 2.0
	return style

## Sets each of these AudioSkeff volume properties to db
func _set_audio(properties: Array, db: float) -> void:
	var audio := get_tree().get_first_node_in_group("AudioSkeff")
	if not audio:
		return
	for property in properties:
		audio.set(property, db)

func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key or not key.pressed or key.echo:
		return
	var code := key.physical_keycode
	# A power window only closes with Space
	if _open == Menu.POWER:
		if code == close_key:
			close()
		get_viewport().set_input_as_handled()
		return
	if _from_start:
		if _open == Menu.NONE:
			return
		if code == close_key or code == _key_for(_open):
			_from_start = false
			_show(Menu.NONE)
			back_to_start.emit()
			get_viewport().set_input_as_handled()
		# Other keys fall through (arrows still move the sound sliders); the game is paused, so nothing else reacts
		return
	var target := Menu.NONE
	if code == controls_key:
		target = Menu.CONTROLS
	elif code == sound_key:
		target = Menu.SOUND
	elif code == map_key:
		target = Menu.MAP
	elif code == close_key and _open != Menu.NONE:
		close()
		get_viewport().set_input_as_handled()
		return
	else:
		return
	# The title screen owns the pause while it's up
	if _open == Menu.NONE and Pause.menu_open:
		return
	if _open == target:
		close()
	else:
		open(target)
	get_viewport().set_input_as_handled()

func _key_for(menu: Menu) -> Key:
	match menu:
		Menu.CONTROLS:
			return controls_key
		Menu.SOUND:
			return sound_key
		Menu.MAP:
			return map_key
	return KEY_NONE

## Opens a page on top of the title screen without touching the pause
func open_from_start(menu: Menu) -> void:
	_from_start = true
	_show(menu)

func open(menu: Menu) -> void:
	_show(menu)
	Pause.menu_open = true
	Pause.set_paused(true)

## Shows the power window for this color (Hue.HueColor: 1 red, 2 blue, 3 yellow, 4 green), only the first time it's asked for.
## override replaces the picture from the export slots. Returns true if the window opened.
func show_power(color: int, override: Texture2D = null) -> bool:
	if _powers_shown.has(color):
		return false
	var tex := override if override else _power_texture(color)
	if not tex:
		return false
	_powers_shown[color] = true
	_power_image.texture = tex
	open(Menu.POWER)
	return true

func _power_texture(color: int) -> Texture2D:
	match color:
		1:
			return red_power_image
		2:
			return blue_power_image
		3:
			return yellow_power_image
		4:
			return green_power_image
	return null

func close() -> void:
	_show(Menu.NONE)
	Pause.menu_open = false
	Pause.set_paused(false)

func is_open() -> bool:
	return _open != Menu.NONE

func _show(menu: Menu) -> void:
	_open = menu
	_controls.visible = menu == Menu.CONTROLS
	_sound.visible = menu == Menu.SOUND
	_map.visible = menu == Menu.MAP
	_power.visible = menu == Menu.POWER
	var focused := get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
	# Arrow keys adjust the sliders while the sound menu is up
	if menu == Menu.SOUND:
		_master_slider.grab_focus()
