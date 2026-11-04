shader_type spatial;
render_mode cull_front, unshaded, depth_draw_opaque;

// Outline por "inverted hull": usado como next_pass do material toon.
uniform vec4 outline_color : source_color = vec4(0.12, 0.10, 0.16, 1.0);
uniform float width : hint_range(0.0, 0.1) = 0.022;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
