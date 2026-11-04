shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, depth_test_disabled;

// Retículo de mira no chão (anel + preenchimento suave), estilo MOBA.
uniform vec4 color : source_color = vec4(1.0, 0.9, 0.4, 0.8);
uniform float ring : hint_range(0.0, 0.5) = 0.08;
uniform float fill_alpha : hint_range(0.0, 1.0) = 0.18;
uniform int shape = 0; // 0 círculo, 1 linha (direção), 2 cone

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float a = 0.0;
	if (shape == 0) {
		float r = length(uv);
		float edge = 1.0 - smoothstep(1.0 - ring, 1.0, r);
		float inner = smoothstep(1.0 - ring * 2.0, 1.0 - ring, r);
		a = (r < 1.0) ? max(fill_alpha, inner * edge) : 0.0;
	} else if (shape == 1) {
		float border = step(abs(uv.x), 1.0) * step(abs(uv.y), 1.0);
		float edge = max(smoothstep(1.0 - ring * 2.0, 1.0, abs(uv.x)), smoothstep(1.0 - ring * 2.0, 1.0, abs(uv.y)));
		a = border * max(fill_alpha, edge);
		a *= 0.6 + 0.4 * fract(UV.y * 3.0 - TIME * 1.5);
	} else {
		float r = length(uv);
		float ang = abs(atan(uv.x, -uv.y));
		float inside = step(r, 1.0) * step(ang, 0.78);
		float edge = max(smoothstep(1.0 - ring * 2.0, 1.0, r), smoothstep(0.78 - ring * 2.0, 0.78, ang));
		a = inside * max(fill_alpha, edge);
	}
	ALBEDO = color.rgb;
	ALPHA = a * color.a;
}
