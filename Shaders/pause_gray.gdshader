shader_type canvas_item;
// Grays out everything drawn beneath this layer. Used by Scenes/PauseTint.tscn while the game is paused.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float gray_amount : hint_range(0.0, 1.0) = 1.0; // 1 = fully gray, 0 = original colors
uniform float brightness : hint_range(0.0, 2.0) = 0.7; // Darkens (below 1) or brightens (above 1) the paused image

void fragment() {
	vec4 c = texture(screen_texture, SCREEN_UV);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(c.rgb, vec3(g), gray_amount) * brightness, 1.0);
}
