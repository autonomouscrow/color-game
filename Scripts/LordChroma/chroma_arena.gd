extends Node2D

## Lord Chroma's arena. Holds one child per color, named White, Red, Blue, Yellow and Green; only the one matching
## Chroma's color is shown and solid. Anything outside those five children stays the same in every color.

const VARIANT_NAMES := ["White", "Red", "Blue", "Yellow", "Green"]  ## In ChromaColor order

## The boss whose color picks the variant
@export var boss: LordChroma
## The arena's walls, floor and ceiling, recolored to match the shown variant
@export var wall_rects: Array[ColorRect] = []
## Wall color for each variant, in ChromaColor order (White, Red, Blue, Yellow, Green)
@export var wall_colors: Array[Color] = [
	Color(0.78, 0.78, 0.83),
	Color(0.32, 0.08, 0.08),
	Color(0.1, 0.15, 0.36),
	Color(0.36, 0.3, 0.05),
	Color(0.1, 0.25, 0.12),
]

func _ready() -> void:
	if boss:
		boss.color_changed.connect(show_color)
		show_color(boss.current_color)
	else:
		show_color(0)

func show_color(color: int) -> void:
	if color >= 0 and color < wall_colors.size():
		for rect in wall_rects:
			if rect:
				rect.color = wall_colors[color]
	for i in VARIANT_NAMES.size():
		var variant := get_node_or_null(VARIANT_NAMES[i]) as CanvasItem
		if variant == null:
			continue
		var on := i == color
		variant.visible = on
		# Disabled nodes drop out of physics, so a hidden variant's platforms aren't solid
		variant.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
