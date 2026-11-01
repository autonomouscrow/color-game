extends CanvasLayer
## Black title screen shown over everything at startup. The game sits paused behind it; Start unpauses and closes the menu.

@export var start_text := "Start"  ## Label on the start button
@export var button_size := Vector2(240, 64)  ## Size of the start button in pixels
@export var button_font_size := 32  ## Font size of the start button text

@onready var _button: Button = $Center/StartButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_button.text = start_text
	_button.custom_minimum_size = button_size
	_button.add_theme_font_size_override("font_size", button_font_size)
	_button.pressed.connect(_on_start_pressed)
	_button.grab_focus()
	Pause.menu_open = true
	Pause.set_paused(true)

func _on_start_pressed() -> void:
	Pause.menu_open = false
	Pause.set_paused(false)
	queue_free()
