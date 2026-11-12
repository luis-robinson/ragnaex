class_name Materials
extends RefCounted
## Fábrica de materiais toon (com outline) — cache por cor.

static var _toon_shader: Shader = null
static var _outline_shader: Shader = null
static var _cache: Dictionary = {}

static func toon(color: Color, outline: bool = true, emission: float = 0.0) -> ShaderMaterial:
	var key := "%s_%s_%.2f" % [color.to_html(), outline, emission]
	if _cache.has(key):
		return _cache[key]
	if _toon_shader == null:
		_toon_shader = load("res://shaders/toon.gdshader")
		_outline_shader = load("res://shaders/outline.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _toon_shader
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("emission_amount", emission)
	if outline:
		var o := ShaderMaterial.new()
		o.shader = _outline_shader
		o.set_shader_parameter("width", 0.03)
		m.next_pass = o
	_cache[key] = m
	return m

static func toon_shader() -> Shader:
	if _toon_shader == null:
		toon(Color.WHITE)
	return _toon_shader

## Material próprio (não cacheado) para entidades que precisam de hit-flash individual.
static func toon_unique(color: Color, outline_width: float = 0.025) -> ShaderMaterial:
	var base := toon(color, true)
	var m: ShaderMaterial = base.duplicate()
	var o: ShaderMaterial = base.next_pass.duplicate()
	o.set_shader_parameter("width", outline_width)
	m.next_pass = o
	return m

static func flat(color: Color, transparent: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

## Chama (fogueira, braseiro, lava do mapa): miolo amarelo virado para a câmera, borda na cor dada, tremula e passa do limiar do brilho.
## Ex.: `mi.set_surface_override_material(i, Materials.fire(Color(1.0, 0.56, 0.2)))`.
static func fire(color: Color, energy: float = 1.3) -> ShaderMaterial:
	var key := "fire_%s_%.2f" % [color.to_html(), energy]
	if _cache.has(key):
		return _cache[key]
	if _fire_shader == null:
		_fire_shader = Shader.new()
		_fire_shader.code = FIRE_SHADER
	var m := ShaderMaterial.new()
	m.shader = _fire_shader
	m.set_shader_parameter("base_color", color)
	m.set_shader_parameter("energy", energy)
	_cache[key] = m
	return m

static var _fire_shader: Shader = null
const FIRE_SHADER := """shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec4 base_color : source_color = vec4(1.0, 0.56, 0.2, 1.0);
uniform float energy = 1.3;
varying float seed;
void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	seed = dot(floor(wp.xz * 0.6), vec2(12.9898, 78.233));
}
void fragment() {
	float core = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.5);
	float flick = 0.82 + 0.1 * sin(TIME * 7.3 + seed) + 0.08 * sin(TIME * 13.1 + seed * 1.7);
	vec3 col = mix(base_color.rgb, vec3(1.0, 0.9, 0.5), core * 0.85);
	ALBEDO = col;
	EMISSION = col * energy * flick;
}
"""

static func glow(color: Color, energy: float = 1.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m
