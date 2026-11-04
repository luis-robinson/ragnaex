shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// Toon "Tree of Savior": 3 tons suaves, sombra azulada, rim e brilho especular (toon_light.gdshaderinc).
uniform vec4 albedo : source_color = vec4(0.8, 0.8, 0.8, 1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, hint_default_white;
uniform float flash : hint_range(0.0, 1.0) = 0.0;   // hit flash (branco)
uniform vec4 status : source_color = vec4(0.0, 0.0, 0.0, 0.0);   // estado (gelo azulado, queimando laranja): cor + força em alpha
uniform float emission_amount : hint_range(0.0, 2.0) = 0.0;
uniform vec4 plus_glow : source_color = vec4(0.0, 0.0, 0.0, 0.0);   // aprimoramento +5/+9: cor + força em alpha (borda pulsando)
uniform float paint : hint_range(0.0, 1.0) = 0.0;   // personagens: pintura à mão (pés mais escuros, manchas suaves)

varying vec3 obj_pos;

#include "res://shaders/toon_light.gdshaderinc"

void vertex() {
	obj_pos = VERTEX;
}

float blot(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float h000 = fract(sin(dot(i, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float h100 = fract(sin(dot(i + vec3(1, 0, 0), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float h010 = fract(sin(dot(i + vec3(0, 1, 0), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float h110 = fract(sin(dot(i + vec3(1, 1, 0), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float h001 = fract(sin(dot(i + vec3(0, 0, 1), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float h101 = fract(sin(dot(i + vec3(1, 0, 1), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float h011 = fract(sin(dot(i + vec3(0, 1, 1), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float h111 = fract(sin(dot(i + vec3(1, 1, 1), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	return mix(mix(mix(h000, h100, f.x), mix(h010, h110, f.x), f.y), mix(mix(h001, h101, f.x), mix(h011, h111, f.x), f.y), f.z);
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	vec3 base = albedo.rgb * tex.rgb * COLOR.rgb;
	if (paint > 0.0) {
		float height = smoothstep(0.0, 1.5, obj_pos.y);
		float mottle = blot(obj_pos * 11.0) * 0.6 + blot(obj_pos * 27.0) * 0.4 - 0.5;
		// sombra quente nos pés, luz fria no topo: dá volume mesmo com uma cor só
		vec3 painted = base * mix(vec3(0.68, 0.62, 0.72), vec3(1.1, 1.08, 1.04), height);
		base = mix(base, painted * (1.0 + mottle * 0.22), paint);
	}
	base = mix(base, status.rgb, status.a);
	ALBEDO = mix(base, vec3(1.0), flash);
	EMISSION = base * emission_amount + vec3(flash) * 0.6 + status.rgb * status.a * 0.35;
	if (plus_glow.a > 0.0) {
		float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
		float pulse = 0.75 + 0.25 * sin(TIME * 2.6);
		EMISSION += plus_glow.rgb * plus_glow.a * (0.1 + 1.1 * rim) * pulse;
	}
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
}
