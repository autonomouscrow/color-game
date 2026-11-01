// Swaps each source color in the art for the matching target color; Hue.gd fills these from its Palette Swap exports
shader_type canvas_item;

const int MAX_COLORS = 16;
uniform int color_count = 0;
uniform vec4 source_colors[16];
uniform vec4 target_colors[16];
uniform float tolerance = 0.02;

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	for (int i = 0; i < MAX_COLORS; i++) {
		if (i >= color_count) {
			break;
		}
		if (distance(c.rgb, source_colors[i].rgb) <= tolerance) {
			c.rgb = target_colors[i].rgb;
			break;
		}
	}
	COLOR = c * modulate;
}
