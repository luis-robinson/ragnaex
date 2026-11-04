shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

// Tufos de grama (MultiMesh): base escura -> ponta clara, balanço do vento por posição no mundo.
// Normal "para cima" para a grama iluminar igual ao chão (sem facetas).
uniform vec4 base_color : source_color = vec4(0.28, 0.48, 0.24, 1.0);
uniform vec4 tip_color : source_color = vec4(0.62, 0.82, 0.45, 1.0);
uniform float wind_strength = 0.09;
uniform float wind_speed = 1.6;

#include "res://shaders/toon_light.gdshaderinc"

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = UV.y * UV.y;
	float sway = sin(TIME * wind_speed + wp.x * 0.45 + wp.z * 0.3) + 0.4 * sin(TIME * wind_speed * 2.3 + wp.x * 1.3);
	VERTEX.x += sway * wind_strength * h;
	VERTEX.z += cos(TIME * wind_speed * 0.8 + wp.z * 0.5) * wind_strength * 0.6 * h;
	NORMAL = (inverse(MODEL_MATRIX) * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
}

void fragment() {
	ALBEDO = mix(base_color.rgb, tip_color.rgb, UV.y) * COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
