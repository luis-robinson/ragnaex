shader_type spatial;
// Peça brilhante de buff (auréola, anel): aditiva, cor/força por instância — um material para todos os bonecos.
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled, fog_disabled;

instance uniform vec4 glow_color : source_color = vec4(1.0, 0.85, 0.4, 1.0);
instance uniform float glow_amount = 0.0;

void fragment() {
	float pulse = 0.8 + 0.2 * sin(TIME * 3.0);
	ALBEDO = glow_color.rgb * (1.2 * pulse);
	ALPHA = clamp(glow_amount * glow_color.a, 0.0, 1.0);
}
