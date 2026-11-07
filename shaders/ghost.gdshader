shader_type spatial;
// Forma Fantasma (Necromancer): só a casca da frente aparece (prepass de profundidade: cabelo, olhos e camadas de
// armadura não se mostram umas através das outras), cor espectral clara, borda brilhante, faixa de brilho subindo
// e as pernas somem em fumaça perto do chão.
render_mode blend_mix, depth_prepass_alpha, cull_back, unshaded;

uniform vec4 tint : source_color = vec4(0.72, 0.8, 1.0, 1.0);       // cor espectral
uniform vec4 rim_color : source_color = vec4(0.82, 0.7, 1.0, 1.0);  // borda
uniform vec4 base : source_color = vec4(0.8, 0.8, 0.8, 1.0);        // cor da peça (capa vermelha continua lembrando a capa)
uniform float body_alpha : hint_range(0.0, 1.0) = 0.5;
uniform float flash : hint_range(0.0, 1.0) = 0.0;                  // hit flash
uniform float appear : hint_range(0.0, 1.0) = 1.0;                 // 0 = ainda não materializou (transformação)
uniform bool vcol_srgb = false;                                     // kit fundido: cor da peça no vértice (sRGB)

varying float height;

void vertex() {
	height = VERTEX.y;
	// ondulação leve: o fantasma flutua e o contorno "respira"
	VERTEX.x += sin(TIME * 3.0 + VERTEX.y * 6.0) * 0.012;
	VERTEX.z += cos(TIME * 2.6 + VERTEX.y * 5.0) * 0.012;
}

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	// faixa clara que sobe pelo corpo
	float band = smoothstep(0.85, 1.0, sin(height * 7.0 - TIME * 3.2) * 0.5 + 0.5);
	// pés: some num rastro de fumaça
	float feet = smoothstep(0.05, 0.55, height);
	vec3 vc = COLOR.rgb;
	if (vcol_srgb) {
		vc = mix(vc / 12.92, pow((vc + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), vc));
	}
	vec3 b = base.rgb * vc;                                   // como no toon: cor da peça x cor do vértice (kit juntado)
	float lum = dot(b, vec3(0.3, 0.59, 0.11));
	vec3 own = mix(vec3(lum), b, 0.8) + 0.12;           // a cor da peça, desbotada e clara
	vec3 col = mix(tint.rgb, own, 0.68) * (0.85 + 0.25 * band) + rim_color.rgb * rim * 1.2;
	ALBEDO = mix(col, vec3(1.0), flash);
	ALPHA = clamp((body_alpha + rim * 0.55 + band * 0.12) * feet * appear + flash * 0.4, 0.0, 1.0);
}
