shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// Chão pintado: manchas grandes de cor (fbm em coordenada de mundo), terra aparecendo em
// clareiras e grão fino — sem textura, sem repetição visível. Mesma luz toon dos personagens.
uniform vec4 color_a : source_color = vec4(0.48, 0.68, 0.38, 1.0);
uniform vec4 color_b : source_color = vec4(0.36, 0.56, 0.3, 1.0);
uniform vec4 color_dirt : source_color = vec4(0.58, 0.48, 0.34, 1.0);
uniform float dirt_amount : hint_range(0.0, 1.0) = 0.18;
uniform float patch_scale = 0.05;
uniform float grain = 0.16;
uniform float seed = 0.0;
// lajes/paralelepípedos (voronoi): 0 = nada, 0..1 = manchas de calçamento, 1 = tudo calçado
uniform float stones : hint_range(0.0, 1.0) = 0.0;
uniform float stone_size = 1.2;
uniform vec4 stone_color : source_color = vec4(0.72, 0.7, 0.65, 1.0);

#include "res://shaders/toon_light.gdshaderinc"

varying vec3 wpos;

// hash sem sin() (Dave Hoskins): estável com coordenadas grandes de mundo (sin perde precisão na GPU
// e o grão mudava de triângulo pra triângulo, desenhando "faixas" retas no chão)
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

vec2 hash2(vec2 p) { return vec2(hash(p), hash(p + 19.19)); }
// (distância ao centro, distância até a borda da célula, id da célula)
vec3 voronoi(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash2(n + g) * 0.75 + 0.125;
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < d1) { d2 = d1; d1 = d; id = hash(n + g); }
			else if (d < d2) { d2 = d; }
		}
	}
	return vec3(sqrt(d1), sqrt(d2) - sqrt(d1), id);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz + vec2(seed * 1.37, seed * 0.71);
	float big = fbm(p * patch_scale);
	float mid = fbm(p * 0.22 + 41.0);
	float fine = vnoise(p * 3.5) * 0.6 + vnoise(p * 9.0) * 0.4;
	vec3 c = mix(color_a.rgb, color_b.rgb, smoothstep(0.32, 0.68, big));
	// clareiras de terra
	c = mix(c, color_dirt.rgb, smoothstep(1.0 - dirt_amount, 1.0 - dirt_amount * 0.4, mid) * step(0.001, dirt_amount));
	c *= 1.0 - grain * 0.5 + grain * fine;
	if (stones > 0.0) {
		vec3 v = voronoi(p / stone_size);
		float mask = stones >= 0.99 ? 1.0 : smoothstep(0.66 - stones * 0.3, 0.72 - stones * 0.3, fbm(p * 0.07 + 7.0));
		vec3 sc = stone_color.rgb * (0.82 + 0.3 * v.z) * (0.95 + 0.1 * fine);
		float gap = smoothstep(0.04, 0.1, v.y);                 // junta escura entre as pedras
		float bevel = 1.0 + 0.12 * smoothstep(0.1, 0.35, v.y);   // centro da pedra um pouco mais claro
		vec3 paved = mix(c * 0.5, sc * bevel, gap);
		c = mix(c, paved, mask);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
