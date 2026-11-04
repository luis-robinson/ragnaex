// Iluminação toon compartilhada (personagens, chão, grama).
// 3 tons (sombra azulada / meio-tom / luz) com transição suave, sombra projetada suave,
// brilho especular "de anime" e rim light. Requer os uniforms abaixo no shader que inclui.
uniform float band_softness : hint_range(0.0, 0.3) = 0.08;
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.42;
uniform vec3 shadow_tint : source_color = vec3(0.62, 0.66, 0.9);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.22;
uniform float spec_strength : hint_range(0.0, 1.0) = 0.1;

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float wrap = ndl * 0.5 + 0.5;
	// terminador principal + meio-tom mais claro
	float lit = smoothstep(0.42 - band_softness, 0.42 + band_softness, wrap);
	float hi = smoothstep(0.75 - band_softness, 0.75 + band_softness, wrap);
	vec3 shade = mix(vec3(1.0), shadow_tint, shadow_strength);
	float falloff = 1.0;
	if (LIGHT_IS_DIRECTIONAL) {
		// sol: ATTENUATION = sombra projetada, que entra suave no mesmo "tom de sombra"
		lit *= smoothstep(0.2, 0.6, ATTENUATION);   // sombra "fraca" (filtro/cascata) conta como luz
	} else {
		// luzes pontuais (loot, projéteis): somem por completo fora do alcance
		falloff = ATTENUATION;
	}
	vec3 lighting = mix(shade, vec3(1.0) + 0.1 * hi, lit) * falloff;
	// rim: contorno claro no lado da luz, mais fraco na sombra
	float rim = smoothstep(0.55, 0.8, 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0)) * rim_strength * (0.35 + 0.65 * lit) * falloff;
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * lighting * (0.9 / PI) + rim * LIGHT_COLOR * 0.25;
	// especular em "mancha" (cabelo, metal, olhos)
	vec3 h = normalize(LIGHT + VIEW);
	// mancha pequena e fraca: em superfícies grandes e lisas (copas, pedras) não pode virar "neve"
	// luz com light_specular = 0 (tocha da dungeon) não faz mancha: no chão liso ela vira um reflexo solto
	float spec = smoothstep(0.975, 0.99, dot(NORMAL, h)) * spec_strength * 0.35 * lit * falloff * step(0.001, SPECULAR_AMOUNT);
	SPECULAR_LIGHT += LIGHT_COLOR * spec;
}
