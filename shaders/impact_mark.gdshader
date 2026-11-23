// Impactos por material (V3) e clarão de soltura (V5): anel de poeira, risco de estocada, fumaça de flecha/bala e marcas no chão
// que ficam 1,5-4 s (rachadura, queimado, geada, selo, mancha). Um material para todos; o que muda por efeito é instance uniform.
// kind 0 = anel de poeira (chão) · 1 = risco (UV.x ao longo cauda 0..cabeça 1, UV.y de lado) · 2 = fumaça/brilho redondo
//      3 = rachadura · 4 = queimado · 5 = geada · 6 = selo sagrado · 7 = mancha (sombra/veneno/sangue seco)
// Alvo: Forward+ (Godot 4.7); 1 draw por efeito vivo (pools de ImpactFx, tetos fixos); sem textura; sem sombra.
// As marcas do chão usam tons rebaixados (nunca o anel vermelho cheio: isso é aviso de golpe; ver zonas.md "Cor do chão").
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

instance uniform int kind = 0;
instance uniform float progress = 0.0;      // 0..1 da vida
instance uniform vec4 col = vec4(1.0);      // linear
instance uniform vec4 col2 = vec4(1.0);     // linear: brasa/miolo
instance uniform float alpha = 1.0;         // opacidade geral (marca no chão <= 0,55)
instance uniform float seed = 0.0;

float hash(float n) {
	return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float p = clamp(progress, 0.0, 1.0);
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float a = 0.0;
	vec3 c = col.rgb;
	float fade = (1.0 - smoothstep(0.55, 1.0, p)) * smoothstep(0.0, 0.05, p);   // marcas do chão: entra rápido, some no fim
	if (kind == 0) {
		float rr = mix(0.35, 0.95, 1.0 - pow(1.0 - p, 2.0));
		float w = mix(0.24, 0.06, p);
		a = (1.0 - smoothstep(0.0, w, abs(r - rr))) * (1.0 - p) * 0.85;
	} else if (kind == 1) {
		float d = abs(UV.y - 0.5) * 2.0;
		a = pow(UV.x, 1.4) * (1.0 - smoothstep(0.2, 1.0, d)) * (1.0 - p);
		c = mix(c, col2.rgb, pow(UV.x, 3.0) * (1.0 - d));
	} else if (kind == 2) {
		float rr = mix(0.4, 1.0, p);
		a = (1.0 - smoothstep(rr * 0.35, rr, r)) * (1.0 - p) * (1.0 - p);
		c = mix(col2.rgb, col.rgb, smoothstep(0.0, 0.7, r / rr));
	} else if (kind == 3) {
		// rachadura: raios tortos a partir do centro, afinando para a ponta
		float lines = 0.0;
		for (int i = 0; i < 7; i++) {
			float fi = float(i);
			float aa = hash(fi + seed) * 6.2832;
			vec2 dir = vec2(cos(aa), sin(aa));
			float along = dot(q, dir);
			float wob = (vnoise(vec2(along * 6.0 + fi, seed)) - 0.5) * 0.14;
			float perp = abs(dot(q, vec2(-dir.y, dir.x)) + wob);
			float len = 0.55 + 0.4 * hash(fi * 3.1 + seed);
			float thick = 0.032 * (1.0 - clamp(along / len, 0.0, 1.0) * 0.75);
			lines = max(lines, (1.0 - smoothstep(0.0, thick, perp)) * step(0.04, along) * step(along, len));
		}
		a = lines * 0.85 * fade;
		c = col.rgb * 0.5;
	} else if (kind == 4) {
		// queimado: mancha escura de borda irregular e brasa fina que esfria
		float edge = 0.56 + 0.26 * vnoise(q * 3.2 + seed);
		float body = 1.0 - smoothstep(edge - 0.28, edge, r);
		float ember = smoothstep(edge - 0.14, edge - 0.02, r) * (1.0 - smoothstep(edge - 0.02, edge + 0.04, r)) * (1.0 - smoothstep(0.0, 0.6, p));
		a = max(body * 0.62, ember * 0.8) * fade;
		c = mix(col.rgb * 0.35, col2.rgb, ember);
	} else if (kind == 5) {
		// geada: estrela de 6 pontas fosca
		float ang = atan(q.y, q.x);
		float s = abs(cos(ang * 3.0));
		float rad = mix(0.4, 1.0, pow(s, 3.0)) * 0.92;
		a = (1.0 - smoothstep(rad * 0.55, rad, r)) * (0.35 + 0.45 * vnoise(q * 6.0 + seed)) * fade;
		c = mix(col.rgb, col2.rgb, (1.0 - r) * 0.6);
	} else if (kind == 6) {
		// selo sagrado: dois anéis finos e seis raios, dourado pálido
		float ang = atan(q.y, q.x);
		float ring = (1.0 - smoothstep(0.0, 0.035, abs(r - 0.88))) + (1.0 - smoothstep(0.0, 0.03, abs(r - 0.6))) * 0.8;
		float spoke = (1.0 - smoothstep(0.0, 0.04, abs(sin(ang * 3.0)) * r)) * step(r, 0.86) * step(0.18, r);
		a = clamp(ring + spoke * 0.8, 0.0, 1.0) * 0.8 * fade;
		c = mix(col.rgb, col2.rgb, 0.4 * (1.0 - p));
	} else {
		// mancha: poça irregular fosca
		float edge = 0.5 + 0.3 * vnoise(q * 2.6 + seed);
		a = (1.0 - smoothstep(edge - 0.3, edge, r)) * 0.55 * fade;
		c = col.rgb * (0.75 + 0.25 * vnoise(q * 7.0));
	}
	if (a <= 0.003) {
		discard;
	}
	ALBEDO = c;
	ALPHA = clamp(a * alpha, 0.0, 1.0);
}
