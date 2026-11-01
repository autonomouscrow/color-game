extends Control

@export var G: Texture2D
@export var R: Texture2D
@export var B: Texture2D
@export var Y: Texture2D

var spawned_image: TextureRect = null  # Change to Sprite2D if you specifically need a 2D node

func _ready() -> void:
	hide()

## General helper that handles creating the node, adding it, and showing the Control
func display_image(tex: Texture2D) -> void:
	# Clean up any image that was already spawned previously
	remove_image()
	
	if tex == null:
		push_warning("Attempted to show a null texture.")
		return

	# 1. Create the image node and assign the texture
	spawned_image = TextureRect.new()
	spawned_image.texture = tex
	
	# Optional: make the texture expand or center within the Control
	# spawned_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# spawned_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# 2. Add it as a child so it renders on screen
	add_child(spawned_image)
	
	# 3. Make this Control visible
	show()

## Removes the spawned node and hides the Control
func remove_image() -> void:
	if is_instance_valid(spawned_image):
		spawned_image.queue_free()
		spawned_image = null
	
	hide()

# --- Convenience Functions ---

func show_g() -> void:
	display_image(G)

func show_r() -> void:
	display_image(R)

func show_b() -> void:
	display_image(B)

func show_y() -> void:
	display_image(Y)
