// spatial_env_water: água toon dos mapas (rio, lago, mar, mangue, gelo, almas, bile). Autor: godot-shader-specialist.
// Alvo: Forward+ (desktop). Orçamento: 1 textura (margem) + ~6 ruídos de valor por pixel, 1 passada, sem laço de textura.
// Variantes: nenhuma (tudo por uniform; um material por tipo de água, WaterFx.material_for).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled;   // sem sombra recebida: o chão a 2 cm dava manchas

// Água toon (Tree of Savior): 3 tons de profundidade (raso -> fundo), linhas de onda que derivam,
// manchas de céu, brilhos que piscam e espuma que vai e volta na margem.
// A distância até a margem vem de uma textura por mapa (WaterFx.bake_shore): 0 = na margem, 1 = longe (shore_max m).
// A malha de água do Blender não tem UV nem profundidade, então a margem é medida contra as bordas das próprias malhas.
// Luz: o mesmo toon do chão (toon_light.gdshaderinc), então sombra de árvore/ponte cai na água.

uniform vec4 shallow_color : source_color = vec4(0.45, 0.78, 0.92, 1.0);
uniform vec4 deep_color : source_color = vec4(0.22, 0.5, 0.78, 1.0);
uniform vec4 foam_color : source_color = vec4(0.95, 0.99, 1.0, 1.0);
uniform vec4 sky_color : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform float deep_dist = 4.0;                          // m da margem até o tom mais fundo
uniform float alpha_base : hint_range(0.0, 1.0) = 0.93;  // opacidade no meio da água
uniform float flow_speed = 1.0;                         // 0 = parada, 1 = normal
uniform float sparkle_amount : hint_range(0.0, 1.0) = 0.7;
uniform float foam_amount : hint_range(0.0, 1.0) = 1.0;
uniform float glow_amount : hint_range(0.0, 2.0) = 0.0;  // água que brilha (poço de almas)
uniform vec4 glow_color : source_color = vec4(0.3, 1.0, 0.5, 1.0);
uniform sampler2D shore_tex : filter_linear, repeat_disable, hint_default_white;
uniform vec2 shore_origin = vec2(-1000.0);              // canto (x, z) da textura no mundo
uniform vec2 shore_size = vec2(2000.0);                 // largura/altura da textura em m
uniform float shore_max = 10.0;                         // m que o valor 1.0 da textura representa
uniform vec4 ripples[12];                               // (x, z, início, força): ondas dos passos/peixes (WaterFx)
uniform float fx_clock = 0.0;                           // relógio das ondas (mesmo do WaterFx)

// rim e brilho do toon ficam nos valores do include: o rim some na água plana pela própria luz
varying vec2 wpos;

#include "res://shaders/toon_light.gdshaderinc"

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 grad2(vec2 i) {
	return vec2(hash21(i), hash21(i + 17.3)) * 2.0 - 1.0;
}

// Ruído de gradiente (Perlin 2D, curva quíntica): suave, sem células quadradas; ~0..1 centrado em 0,5
float gnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = dot(grad2(i), f);
	float b = dot(grad2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
	float c = dot(grad2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
	float d = dot(grad2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 0.75 + 0.5;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float t = TIME * flow_speed;
	vec2 w = wpos;

	// distância da margem (m): textura por mapa; fora dela conta como "longe"
	vec2 suv = (w - shore_origin) / shore_size;
	float d = shore_max;
	if (suv.x > 0.0 && suv.y > 0.0 && suv.x < 1.0 && suv.y < 1.0) {
		d = texture(shore_tex, suv).r * shore_max;
	}

	// ondulação: dois ruídos andando em sentidos diferentes
	// só 2 amostras de ruído por pixel (n1, n2); o resto reaproveita
	vec2 wr = vec2(w.x * 0.8 + w.y * 0.6, -w.x * 0.6 + w.y * 0.8);
	float n1 = gnoise(wr * 0.5 + vec2(t * 0.10, t * 0.06));
	float n2 = gnoise(w * 0.85 + vec2(-t * 0.07, t * 0.11) + 7.3);
	float h = n1 * 0.55 + n2 * 0.45;

	// 3 tons de profundidade, com transição curta (toon)
	float dt = clamp(d / max(deep_dist, 0.01), 0.0, 1.0);
	float tone = 0.5 * (smoothstep(0.2, 0.3, dt) + smoothstep(0.55, 0.65, dt));
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, tone);

	// mancha mais clara que desliza (meio-tom da onda) e linhas finas de crista
	col = mix(col, shallow_color.rgb, smoothstep(0.5, 0.72, h) * 0.25);
	float line = 1.0 - smoothstep(0.0, 0.06, abs(fract(h * 6.0 + t * 0.04) - 0.5));
	line *= smoothstep(0.42, 0.56, n2) * smoothstep(0.1, 0.5, d);
	col = mix(col, sky_color.rgb, line * 0.5);

	// reflexo do céu: recorte suave do próprio n1 (sem amostra extra)
	col = mix(col, sky_color.rgb, smoothstep(0.55, 0.85, n1) * 0.16);

	// brilho do sol: pontinhos que piscam
	vec2 sg = w * 3.0 + vec2(t * 0.35, t * 0.22);
	vec2 sc = floor(sg);
	vec2 soff = (vec2(hash21(sc + 3.1), hash21(sc + 7.7)) - 0.5) * 0.5;
	float blink = 0.5 + 0.5 * sin(t * 3.0 + hash21(sc) * 6.28);
	// pontinho redondo por célula (nunca quadrado): só ~10% das células brilham
	float sparkle = step(0.9, hash21(sc)) * (1.0 - smoothstep(0.07, 0.17, length(fract(sg) - 0.5 - soff))) * blink * sparkle_amount * smoothstep(0.4, 1.2, d);

	// espuma da margem: faixa que vai e volta + um filete atrás, quebrado por ruído
	float wob = (n1 + n2) * 0.5 * 0.7;    // reaproveita o ruído da onda
	float pulse = 0.5 + 0.5 * sin(t * 1.1 + wob * 5.0);
	float fw = 0.16 + 0.2 * pulse + wob * 0.16;
	float foam = 1.0 - smoothstep(fw - 0.07, fw, d);
	float d2 = 0.7 + 0.55 * (0.5 + 0.5 * sin(t * 1.1 - 1.2 + wob * 5.0));
	float foam2 = (1.0 - smoothstep(0.0, 0.09, abs(d - d2))) * step(0.5, n2) * smoothstep(0.35, 0.5, d);
	float f = max(foam, foam2 * 0.85);

	// ondas dos passos/peixes (WaterFx): anéis que abrem e somem
	float ring = 0.0;
	for (int i = 0; i < 12; i++) {
		vec4 rp = ripples[i];
		float age = fx_clock - rp.z;
		if (rp.w > 0.0 && age > 0.0 && age < 1.8) {
			float r = distance(w, rp.xy);
			float rad = age * 1.3;
			float wid = 0.07 + age * 0.06;
			float k = (1.0 - smoothstep(0.0, wid, abs(r - rad))) + 0.6 * (1.0 - smoothstep(0.0, wid, abs(r - rad + 0.35)));
			ring += k * (1.0 - age / 1.8) * rp.w;
		}
	}
	f = max(f * foam_amount, clamp(ring, 0.0, 1.0) * 0.9);

	col = mix(col, foam_color.rgb, f);
	ALBEDO = col;
	EMISSION = vec3(sparkle * 0.7) + glow_color.rgb * glow_amount * (0.5 + 0.5 * h) * (1.0 - f);
	ALPHA = clamp(max(alpha_base * smoothstep(0.0, 0.1, d), f * 0.95), 0.0, 1.0);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
