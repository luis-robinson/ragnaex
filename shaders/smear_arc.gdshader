// Arco de golpe (smear) e faíscas de impacto. Um material para todos: tudo que muda por golpe é instance uniform.
// shape 0 = crescente do golpe (malha em grade: UV.x = ângulo 0 cauda..1 cabeça, UV.y = 0 dentro..1 fora; a forma sai do vertex)
// shape 1 = leque de faíscas (riscos: UV.x = ao longo 0..1, UV.y = de lado; COLOR.g = velocidade do risco)
// shape 2 = estrela de impacto (quad virado para a câmera)
// shape 3 = cunha de estocada (mesma grade do arco: UV.x = ao longo inner_r..1 (24 divisões), UV.y = de lado 0..1, ponta fina na frente)
// shape 4 = garras no chão das formas de bicho (malha de riscos de WeaponArcs.k_mesh: UV.x 0 cabeça..1 ponta, UV.y de lado)
// Alvo: Forward+ (Godot 4.7), 1 material compartilhado, sem textura; custo: 1 draw por arco/faísca/estrela vivos (pool de 8 cada; garras K 8).
// Alfa pré-multiplicado: o miolo claro soma luz (lê no chão pastel) e a borda escura cobre (contorno toon).
shader_type spatial;
render_mode blend_premul_alpha, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

instance uniform int shape = 0;
instance uniform float progress = 0.0;      // 0..1 da vida
instance uniform float arc_deg = 110.0;     // abertura do arco (graus)
instance uniform float inner_r = 0.3;       // raio de dentro da malha (fração do de fora)
instance uniform float sweep = 1.0;         // 1 = cabeça no lado +X do golpe, -1 = espelhado
instance uniform vec4 core_col = vec4(1.0, 1.0, 1.0, 1.0);    // linear
instance uniform vec4 band_col = vec4(0.8, 0.85, 1.0, 1.0);   // linear
instance uniform vec4 rim_col = vec4(0.05, 0.05, 0.12, 1.0);  // linear
instance uniform float glow = 1.0;          // força do miolo
instance uniform float width = 0.1;         // cunha: meia-largura máxima (fração do raio)
instance uniform float alpha = 1.0;         // opacidade geral (marca no chão: <= 0,6)
instance uniform float rim_boost = 0.0;     // marca no chão: 0..1 contorno mais largo e mais escuro (lê na areia clara; não mexe no alfa)

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	if (shape == 0) {
		float th = radians(arc_deg) * (UV.x - 0.5) * sweep;
		float r = mix(inner_r, 1.0, UV.y);
		VERTEX = vec3(sin(th) * r, 0.0, cos(th) * r);
	} else if (shape == 3) {
		// perfil: fina atrás, cheia a 70% do alcance, ponta afiada no fim
		float y = UV.x;
		float prof = smoothstep(0.0, 0.7, y) * (1.0 - smoothstep(0.7, 1.0, y) * 0.92);
		VERTEX = vec3((UV.y - 0.5) * 2.0 * width * max(prof, 0.04), 0.0, mix(inner_r, 1.0, y));
	} else if (shape == 2) {
		float s = length(MODEL_MATRIX[0].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		VERTEX *= s;
	}
}

// Mistura de camadas em alfa pré-multiplicado (por cima de 'dst').
vec4 over(vec4 dst, vec3 c, float a) {
	return vec4(c * a + dst.rgb * (1.0 - a), a + dst.a * (1.0 - a));
}

void fragment() {
	float p = clamp(progress, 0.0, 1.0);
	vec4 o = vec4(0.0);
	if (shape == 0) {
		float u = UV.x;                       // 0 cauda .. 1 cabeça (ponta da lâmina agora)
		float v = UV.y;                       // 0 dentro .. 1 fora (caminho da ponta)
		float span = 1.0 - inner_r;
		// espessura do crescente: fina na cauda, cheia na cabeça; medida a partir da borda de fora
		float w = mix(0.16, 1.0, pow(u, 1.3)) * (1.0 - 0.25 * p);
		float d = (1.0 - v) / max(w, 0.001);  // 0 = borda de fora, 1 = borda de dentro
		// cabeça arredondada e erosão da cauda para a cabeça, com borda quebrada
		float n = vnoise(vec2(u * 14.0, v * 4.0));
		float cut = p * 1.08 - 0.06;
		float head = smoothstep(1.0, 0.965, u);
		float erode = smoothstep(cut, cut + 0.05, u + (n - 0.5) * 0.10);
		float inside = (1.0 - smoothstep(0.92, 1.0, d)) * head * erode;
		if (inside <= 0.002) {
			discard;
		}
		// contorno toon: linha escura na borda de fora e na de dentro (fina)
		// marca no chão (rim_boost): as duas linhas engrossam para dentro da faixa
		float rim_out = 1.0 - smoothstep(0.0, 0.07 + 0.13 * rim_boost, d);
		float rim_in = smoothstep(0.80 - 0.22 * rim_boost, 0.93, d);
		float tail = mix(0.30, 1.0, pow(u, 0.7));          // cauda mais apagada que a cabeça
		vec3 band = band_col.rgb;
		float band_a = (1.0 - smoothstep(0.35, 0.95, d)) * 0.85 * tail;
		o = over(o, band, band_a);
		// miolo branco logo dentro da borda de fora; mais forte na cabeça (diz para onde o golpe foi)
		float core = smoothstep(0.05, 0.11, d) * (1.0 - smoothstep(0.18, 0.42, d)) * pow(u, 1.6);
		o = over(o, core_col.rgb * glow, clamp(core, 0.0, 1.0) * 0.95);
		float rim = max(rim_out, rim_in * mix(0.6, 0.95, rim_boost)) * mix(0.35 + 0.45 * rim_boost, 0.85 + 0.15 * rim_boost, u);
		o = over(o, rim_col.rgb * (1.0 - 0.5 * rim_boost), min(rim, 1.0));
		o *= inside * (1.0 - smoothstep(0.75, 1.0, p) * 0.6);
	} else if (shape == 3) {
		float v = UV.x;                       // 0 atrás .. 1 ponta
		float d = abs(UV.y - 0.5) * 2.0;      // 0 linha do meio .. 1 borda
		float n = vnoise(vec2(UV.y * 9.0, v * 3.0));
		float cut = p * 1.08 - 0.06;
		float erode = smoothstep(cut, cut + 0.06, v + (n - 0.5) * 0.12);   // some de trás para a ponta
		// atrás a cunha se desfaz em riscos de velocidade (3-4 linhas ao longo)
		float lines = smoothstep(0.35, 0.6, abs(sin(UV.y * 3.14159 * 4.0)));
		float fringe = mix(lines, 1.0, smoothstep(0.25, 0.6, v));
		float inside = erode * fringe * (1.0 - smoothstep(0.9, 1.0, d));
		if (inside <= 0.002) {
			discard;
		}
		float tail = mix(0.35, 1.0, pow(v, 0.8));
		o = over(o, band_col.rgb, (1.0 - smoothstep(0.55, 0.95, d)) * 0.85 * tail);
		o = over(o, core_col.rgb * glow, (1.0 - smoothstep(0.12, 0.32, d)) * pow(v, 1.4) * 0.95);
		o = over(o, rim_col.rgb, smoothstep(0.72, 0.92, d) * mix(0.35, 0.85, v));
		o *= inside * (1.0 - smoothstep(0.75, 1.0, p) * 0.6);
	} else if (shape == 4) {
		// garras no chão (formas de bicho): UV.x 0 cabeça (onde a pata bateu) .. 1 ponta; some da ponta para a cabeça
		float v = UV.x;
		float d = abs(UV.y - 0.5) * 2.0;      // 0 meio do risco .. 1 borda
		float n = vnoise(vec2(UV.y * 7.0, v * 5.0));
		float cut = p * 1.08 - 0.06;
		float erode = smoothstep(cut, cut + 0.06, (1.0 - v) + (n - 0.5) * 0.12);
		float inside = erode * (1.0 - smoothstep(0.86, 1.0, d)) * smoothstep(0.0, 0.03, v + 0.01);
		if (inside <= 0.002) {
			discard;
		}
		float tail = mix(1.0, 0.4, pow(v, 0.8));
		o = over(o, band_col.rgb, (1.0 - smoothstep(0.5, 0.9, d)) * 0.9 * tail);
		o = over(o, core_col.rgb * glow, (1.0 - smoothstep(0.1, 0.3, d)) * (1.0 - v) * 0.8);
		// contorno escuro: lê no chão claro (areia); rim_boost começa mais para dentro, mais forte e mais escuro
		float k_rim = smoothstep(0.6 - 0.22 * rim_boost, 0.86 - 0.12 * rim_boost, d) * mix(0.9 + 0.1 * rim_boost, 0.45 + 0.35 * rim_boost, v);
		o = over(o, rim_col.rgb * (1.0 - 0.5 * rim_boost), k_rim);
		o *= inside * (1.0 - smoothstep(0.7, 1.0, p) * 0.6);
	} else if (shape == 1) {
		float speed = COLOR.g;
		float hd = clamp(pow(p, 0.55) * (0.75 + 0.45 * speed), 0.0, 1.1);
		float tl = hd - 0.40;
		float along = smoothstep(tl, tl + 0.12, UV.x) * (1.0 - smoothstep(hd - 0.02, hd, UV.x));
		float across = 1.0 - abs(UV.y * 2.0 - 1.0);
		float a = along * smoothstep(0.0, 0.35, across) * (1.0 - smoothstep(0.6, 1.0, p));
		if (a <= 0.002) {
			discard;
		}
		o = over(o, rim_col.rgb, a * 0.55);
		o = over(o, band_col.rgb, a * smoothstep(0.25, 0.55, across) * 0.9);
		o = over(o, core_col.rgb * glow, a * smoothstep(0.6, 0.9, across));
	} else {
		vec2 q = UV * 2.0 - 1.0;
		float r = length(q);
		float sz = mix(1.0, 0.35, p);
		vec2 q2 = abs(q) / sz;
		float star = clamp(0.035 / (q2.x * q2.y + 0.012) - 0.15, 0.0, 1.0) * (1.0 - smoothstep(0.55, 1.0, r / sz));
		float disc = 1.0 - smoothstep(0.10, 0.22, r / sz);
		float a = clamp(star + disc, 0.0, 1.0) * (1.0 - smoothstep(0.4, 1.0, p));
		if (a <= 0.002) {
			discard;
		}
		o = over(o, band_col.rgb, a * 0.8);
		o = over(o, core_col.rgb * glow, clamp(disc * 1.2 + star * 0.5, 0.0, 1.0) * (1.0 - p));
	}
	o *= clamp(alpha, 0.0, 1.0);
	ALBEDO = o.rgb;
	ALPHA = o.a;
}
