shader_type spatial;
// Casca de buff em volta do boneco (BuffAura): bolha de escudo lisa, cristal de gelo facetado ou chama (fúria).
// Um material só para todos os bonecos: cor/força/modo por instância (instance uniform), sem material por boneco.
// O miolo é quase transparente (fresnel): o boneco continua legível de cima.
render_mode blend_mix, depth_draw_never, cull_back, unshaded, shadows_disabled, fog_disabled;

instance uniform vec4 shell_color : source_color = vec4(0.6, 0.85, 1.0, 1.0);
instance uniform float shell_amount = 0.0;    // 0..1 (some com o escudo restante / fim do buff)
instance uniform float facets = 0.0;          // modo: 0 bolha, 1 cristal (facetas chapadas), 2 chama

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void fragment() {
	int mode = int(facets + 0.5);
	vec3 n = NORMAL;
	if (mode == 1) {
		n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	}
	float ndv = abs(dot(n, VIEW));
	float fres = pow(1.0 - ndv, 1.6);
	float a;
	vec3 c;
	if (mode == 2) {
		// chama: línguas subindo (ruído rolando para cima), mais forte embaixo e na borda
		float tongue = vnoise(vec3(lp.x * 3.5, lp.y * 2.5 - TIME * 3.2, lp.z * 3.5)) * 0.65 + vnoise(vec3(lp.x * 7.0, lp.y * 5.0 - TIME * 5.0, lp.z * 7.0)) * 0.35;
		float h = clamp(lp.y * 0.5 + 0.5, 0.0, 1.0);       // 0 embaixo, 1 em cima
		float f = smoothstep(0.36 + 0.3 * h, 0.8, tongue);
		f *= 1.0 - smoothstep(0.45, 1.0, h);                   // as línguas acabam antes do topo (não fecha a bolha)
		c = mix(vec3(1.0, 0.9, 0.55), shell_color.rgb, 0.3 + 0.7 * h);
		a = f * (0.95 - 0.4 * h) * (0.45 + 0.55 * fres);     // sem contorno: chama, não bolha; miolo mais limpo
	} else {
		// faixa clara que corre pela casca (lê como "ligado" mesmo parado)
		float band = smoothstep(0.92, 1.0, sin(VERTEX.y * 4.0 + TIME * 2.2) * 0.5 + 0.5);
		float sparkle = 0.0;
		if (mode == 1) {
			float hh = hash3(floor(n * 6.0));        // cada faceta pisca no seu tempo
			sparkle = smoothstep(0.82, 1.0, sin(TIME * 2.5 + hh * 30.0) * 0.5 + 0.5);
		}
		c = shell_color.rgb * (0.75 + 0.6 * fres) + vec3(1.0) * (sparkle * 0.55 + band * 0.25);
		a = mode == 1 ? (0.05 + 0.5 * fres + sparkle * 0.2) : (0.03 + 0.6 * fres + band * 0.08);
	}
	ALBEDO = c;
	ALPHA = clamp(a * shell_amount * shell_color.a, 0.0, 1.0);
}
