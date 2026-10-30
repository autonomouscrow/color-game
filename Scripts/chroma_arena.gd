extends Node2D

## Lord Chroma's arena. Holds one child per color, named White, Red, Blue, Yellow and Green; only the one matching
## Chroma's color is shown and solid. Anything outside those five children stays the same in every color.

const VARIANT_NAMES := ["White", "Red", "Blue", "Yellow", "Green"]  ## In ChromaColor order

## The boss whose color picks the variant
@export var boss: LordChroma

func _ready() -> void:
	if boss:
		boss.color_changed.connect(show_color)
		show_color(boss.current_color)
	else:
		show_color(0)

func show_color(color: int) -> void:
	for i in VARIANT_NAMES.size():
		var variant := get_node_or_null(VARIANT_NAMES[i]) as CanvasItem
		if variant == null:
			continue
		var on := i == color
		variant.visible = on
		# Disabled nodes drop out of physics, so a hidden variant's platforms aren't solid
		variant.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
