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
uniform bool vcol_srgb = false;
uniform vec4 buff_rim : source_color = vec4(0.0, 0.0, 0.0, 0.0);   // buff ativo (BuffAura): cor + força em alpha
uniform float buff_style = 0.0;   // 0 borda, 1 cristal de gelo, 2 pedra/osso, 3 chama tremendo, 4 casca, 5 brilho sagrado, 6 fumaça   // boneco fundido (KitModel._remerge): a cor de cada peça vem no COLOR do vértice, em sRGB

varying vec3 obj_pos;
varying float vspec;

#define TOON_VSPEC
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
	vec3 vc = COLOR.rgb;
	vspec = spec_strength;
	if (vcol_srgb) {
		vc = mix(vc / 12.92, pow((vc + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), vc));
		vspec = COLOR.a;
	}
	vec3 base = albedo.rgb * tex.rgb * vc;
	if (paint > 0.0) {
		float height = smoothstep(0.0, 1.5, obj_pos.y);
		float mottle = blot(obj_pos * 11.0) * 0.6 + blot(obj_pos * 27.0) * 0.4 - 0.5;
		// sombra quente nos pés, luz fria no topo: dá volume mesmo com uma cor só
		vec3 painted = base * mix(vec3(0.68, 0.62, 0.72), vec3(1.1, 1.08, 1.04), height);
		base = mix(base, painted * (1.0 + mottle * 0.22), paint);
	}
	base = mix(base, status.rgb, status.a);
	vec3 bglow = vec3(0.0);
	if (buff_rim.a > 0.0) {
		// buff: borda colorida + padrão do tema na própria pele (sem malha extra)
		float a = buff_rim.a;
		float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
		int st = int(buff_style + 0.5);
		float pulse = 0.8 + 0.2 * sin(TIME * 3.0);
		float pat = 0.0;
		if (st == 1) {          // gelo: placas claras de cristal + geada
			float c = blot(obj_pos * 9.0);
			pat = step(0.6, c) * 0.75 + step(0.8, blot(obj_pos * 23.0)) * 0.5;
			base = mix(base, mix(buff_rim.rgb, vec3(1.0), 0.45), a * (0.1 + 0.3 * pat));
		} else if (st == 2) {   // pedra/osso: manchas de placa
			pat = smoothstep(0.5, 0.62, blot(obj_pos * 7.0));
			base = mix(base, buff_rim.rgb * 0.85, a * (0.15 + 0.5 * pat));
		} else if (st == 3) {   // chama: tremor subindo pelo corpo
			pulse = 0.55 + 0.45 * sin(TIME * 13.0 + obj_pos.y * 9.0 + blot(obj_pos * 5.0 + vec3(0.0, -TIME * 2.0, 0.0)) * 6.0);
			base = mix(base, buff_rim.rgb, a * 0.06);
		} else if (st == 4) {   // casca: veios verticais
			pat = smoothstep(0.55, 0.7, blot(vec3(obj_pos.x * 18.0, obj_pos.y * 2.5, obj_pos.z * 18.0)));
			base = mix(base, buff_rim.rgb * 0.7, a * (0.12 + 0.45 * pat));
		} else if (st == 5) {   // sagrado: faixa dourada subindo
			pat = smoothstep(0.8, 1.0, sin(obj_pos.y * 6.0 - TIME * 2.6) * 0.5 + 0.5);
			base = mix(base, buff_rim.rgb, a * 0.1);
		} else if (st == 6) {   // sombra: escurece de baixo para cima, ondulando
			pat = 1.0 - smoothstep(0.2, 0.9, obj_pos.y + 0.3 * blot(obj_pos * 4.0 + vec3(0.0, -TIME, 0.0)));
			base = mix(base, buff_rim.rgb * 0.5, a * 0.45 * pat);
		} else {
			base = mix(base, buff_rim.rgb, a * 0.1);
		}
		bglow = buff_rim.rgb * a * ((0.05 + 1.4 * rim) * pulse + pat * 0.25);
	}
	ALBEDO = mix(base, vec3(1.0), flash);
	EMISSION = base * emission_amount + vec3(flash) * 0.6 + status.rgb * status.a * 0.35 + bglow;
	if (plus_glow.a > 0.0) {
		float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
		float pulse = 0.75 + 0.25 * sin(TIME * 2.6);
		EMISSION += plus_glow.rgb * plus_glow.a * (0.1 + 1.1 * rim) * pulse;
	}
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
}
