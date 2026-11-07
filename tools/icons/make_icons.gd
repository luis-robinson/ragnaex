extends Node2D
## Gera os ícones de skill e de classe (assets/icons/skill_<id>.png, class_<id>.png), 128 px.
## A arte dos itens vem de tools/icons/item_icons.tscn (art_<id>.png).
##   godot --path . tools/icons/make_icons.tscn [-- --sheet=<png> --only=<classe>]
## Símbolo = GLYPHS (o que a skill é); fundo = tema (SkillDef.vfx); marca = o que os dados dizem:
## buff (seta), avanço (riscos), área (anel no chão), cone (arcos), em volta de si (anel), dano no tempo (gotas).
## Skill nova sem entrada em GLYPHS: o script avisa e usa o símbolo do tipo de skill.

const SIZE := 512               # desenha grande e reduz: bordas limpas em 128 px
const OUT := 128
const INK := Color(0.08, 0.06, 0.1)

## tema: [fundo em cima, fundo embaixo, símbolo, sombra do símbolo, detalhe]
const THEMES := {
	"fire": [Color(0.86, 0.3, 0.1), Color(0.35, 0.05, 0.05), Color(1.0, 0.8, 0.3), Color(0.95, 0.42, 0.12), Color(1.0, 0.92, 0.6)],
	"ice": [Color(0.3, 0.62, 0.9), Color(0.08, 0.16, 0.42), Color(0.86, 0.96, 1.0), Color(0.5, 0.76, 0.96), Color(1, 1, 1)],
	"lightning": [Color(0.42, 0.28, 0.86), Color(0.1, 0.07, 0.34), Color(1.0, 0.95, 0.5), Color(0.96, 0.72, 0.2), Color(0.8, 0.85, 1.0)],
	"wind": [Color(0.36, 0.72, 0.68), Color(0.07, 0.26, 0.3), Color(0.9, 1.0, 0.95), Color(0.56, 0.84, 0.78), Color(1, 1, 1)],
	"bone": [Color(0.5, 0.46, 0.4), Color(0.14, 0.12, 0.13), Color(0.95, 0.92, 0.8), Color(0.72, 0.68, 0.56), Color(0.4, 0.95, 0.7)],
	"poison": [Color(0.4, 0.62, 0.16), Color(0.1, 0.2, 0.08), Color(0.8, 1.0, 0.34), Color(0.46, 0.76, 0.2), Color(0.86, 0.5, 1.0)],
	"shadow": [Color(0.34, 0.2, 0.56), Color(0.06, 0.04, 0.14), Color(0.8, 0.66, 1.0), Color(0.52, 0.36, 0.84), Color(0.4, 0.95, 0.8)],
	"blood": [Color(0.74, 0.1, 0.13), Color(0.2, 0.02, 0.05), Color(0.98, 0.84, 0.76), Color(0.9, 0.3, 0.26), Color(1.0, 0.4, 0.34)],
	"earth": [Color(0.6, 0.42, 0.22), Color(0.2, 0.12, 0.07), Color(0.96, 0.82, 0.56), Color(0.74, 0.54, 0.3), Color(1.0, 0.9, 0.7)],
	"lunar": [Color(0.24, 0.3, 0.68), Color(0.05, 0.06, 0.22), Color(0.94, 0.94, 1.0), Color(0.66, 0.7, 0.96), Color(1.0, 0.9, 0.6)],
	"holy": [Color(0.96, 0.74, 0.28), Color(0.5, 0.26, 0.08), Color(1.0, 0.98, 0.84), Color(1.0, 0.82, 0.4), Color(1, 1, 1)],
	"nature": [Color(0.3, 0.64, 0.3), Color(0.06, 0.22, 0.12), Color(0.8, 1.0, 0.6), Color(0.42, 0.78, 0.36), Color(1.0, 0.95, 0.6)],
	"heal": [Color(0.36, 0.84, 0.56), Color(0.06, 0.3, 0.24), Color(1.0, 1.0, 0.92), Color(0.62, 0.95, 0.72), Color(1, 1, 1)],
	"summon": [Color(0.2, 0.44, 0.4), Color(0.04, 0.1, 0.12), Color(0.76, 1.0, 0.86), Color(0.42, 0.8, 0.66), Color(0.8, 0.5, 1.0)],
	"physical": [Color(0.5, 0.54, 0.62), Color(0.14, 0.15, 0.2), Color(0.95, 0.96, 1.0), Color(0.66, 0.7, 0.8), Color(1.0, 0.85, 0.45)],
}
## símbolo -> skills
const GLYPHS := {
	"sword": ["nec_skeleton_king", "ran_cross_cut", "ass_thrust", "ass_cross_slash", "ass_lunge", "ass_crimson", "bis_crusade", "pal_holy_strike", "pal_twin_slash", "pal_blade_dance", "pal_lunge", "pal_flurry", "pal_crusader_strike", "pal_judgement_blade",
		"ber_blade_rush", "ber_bladestorm", "ran_twin_cut", "ran_hunter_dash", "ran_whirl"],
	"axe": ["ber_cleave", "ber_leap", "ber_execute", "ber_hack", "ber_axe_storm", "ber_throw_axe", "ber_butcher",
		"ber_crimson_flurry", "ber_whirlwind", "ber_hatchet", "ber_hatchet_fan", "ber_tomahawk_rain"],
	"dagger": ["ass_backstab", "ass_poison", "ass_fan", "ass_execute", "ass_quick_stab", "ass_twin_strike", "ass_blade_flurry", "ass_dance", "ass_thousand",
		"ass_plague_blade", "ass_eviscerate", "ass_shadow_knives"],
	"hammer": ["bis_holy_blow", "bis_divine_hammer", "pal_hammer_light", "bis_hammer", "bis_judgement", "bis_condemn", "ber_overhead"],
	"scythe": ["nec_reap", "nec_harvest", "nec_grim"],
	"arrow": ["ran_scatter", "ran_power_shot", "ran_multishot", "ran_rain", "ran_explosive", "ran_frost_arrow", "ran_volley", "ass_venom_dart"],
	"shield": ["bis_shield_smite", "pal_shield_bash", "pal_divine_shield", "pal_shield_wall", "pal_aegis_slam", "bis_martyr", "pal_shield_throw"],
	"armor": ["ass_guard", "dru_oak_skin", "bis_ward", "pal_blessed_armor", "ele_frost_armor", "nec_bone_armor"],
	"cross": ["pal_consecrate", "bis_blessing", "bis_smite", "bis_purify", "pal_bastion_aura"],
	"sun": ["pal_sun_strike", "ele_combustion", "pal_holy_wave", "pal_valor", "pal_retribution", "bis_light", "bis_holy_nova", "bis_wrath", "bis_zealot"],
	"hand": ["nec_drain_soul", "pal_lay_hands", "bis_prayer", "bis_mend"],
	"heart": ["ber_bloodlust", "bis_heal", "bis_sanctuary", "nec_drain"],
	"wing": ["bis_faith_leap", "bis_angel", "ran_disengage", "ass_reflexes"],
	"shout": ["bis_battle_hymn", "ran_pack", "pal_taunt", "ber_warcry", "dru_bellow"],
	"fist": ["pal_avenging_wrath", "ber_titan_grip", "ass_cheap_shot"],
	"drop": ["ran_prey", "ass_virulence", "ber_fury", "ass_paralyze", "nec_plague", "nec_rot", "nec_decay"],
	"claw": ["ran_sic", "ass_thousand", "dru_pounce", "dru_claw", "dru_savage", "dru_frenzy", "ran_maul", "ber_rend", "ber_twin_fang"],
	"paw": ["nec_bone_hound", "ran_companion", "dru_spirit_wolves", "dru_maim", "dru_bear_form", "dru_maul", "dru_stampede", "dru_rampage", "ran_wild"],
	"leaf": ["dru_grove", "bis_renew", "dru_regrowth", "dru_wild_growth"],
	"thorn": ["ran_caltrops", "nec_curse_agony", "dru_thorns", "dru_entangle", "ass_caltrops"],
	"tree": ["dru_treant", "dru_bark"],
	"bug": ["dru_swarm", "nec_swarm"],
	"mountain": ["bis_holy_quake", "dru_earth_slam", "dru_mountain", "ber_earthsplitter"],
	"moon": ["dru_wolf_form", "dru_moonfire"],
	"star": ["bis_miracle", "dru_starfall", "ele_spark"],
	"tornado": ["ran_tumble", "ber_ricochet", "ele_firestorm", "nec_death_spin", "ber_steel_whirl", "ass_steel_whirl", "dru_cyclone", "ele_blink"],
	"bolt": ["nec_void_beam", "ele_summon_storm", "dru_storm", "ele_lightning", "ele_static", "ele_overload", "ele_storm_lord"],
	"chain": ["ele_chain", "nec_curse_weakness", "ran_anchor"],
	"target": ["pal_brand", "nec_curse_doom", "ass_focus", "ass_expose", "ran_barrage", "ran_snipe", "ran_mark"],
	"eye": ["nec_mind_flay", "dru_prowl", "ran_deadeye", "ass_vanish", "ass_shadowstep"],
	"trap": ["ran_trap"],
	"net": ["ran_net"],
	"cloud": ["ele_hailstorm", "nec_pandemic", "ele_thunder", "ass_smoke", "ass_toxic_cloud", "nec_curse"],
	"flame": ["pal_sacred_flame", "pal_cleansing_fire", "pal_flame_pyre", "nec_demon_form", "ele_frost_flare", "ele_summon_fire", "pal_zeal", "pal_purge", "ele_fireball", "ele_flame_wave", "ele_fire_wall", "ele_inferno"],
	"meteor": ["ran_mine", "ele_meteor", "ass_smoke_bomb", "ber_great_throw"],
	"bird": ["ran_gale", "ele_phoenix"],
	"crystal": ["ele_prism", "ele_summon_ice", "ele_absolute_zero", "ele_ice_lance", "ele_glacier"],
	"snowflake": ["nec_lich", "ran_frost_trap", "ele_shatter", "ele_frost_nova", "ele_blizzard"],
	"skull": ["ran_headshot", "ass_master", "ber_decapitate", "nec_raise", "nec_army", "nec_dark_pact"],
	"ghost": ["bis_exorcism", "nec_phantom", "nec_soul_rend"],
	"spear": ["ran_piercing"],
	"bone": ["nec_bone_spear", "nec_bone_wall", "nec_corpse_explosion"],
}
const TWIN := ["ass_cross_slash", "ass_thrust", "ass_master", "pal_twin_slash", "ber_hack", "ber_twin_fang", "ran_twin_cut", "ass_twin_strike", "ass_blade_flurry", "ber_axe_storm", "ber_bladestorm", "ass_dance", "pal_flurry", "ber_crimson_flurry"]
const RAIN := ["ber_tomahawk_rain", "ran_rain", "ran_volley", "dru_starfall", "ele_blizzard", "ele_storm_lord"]
const FAN := ["ran_multishot", "ass_fan", "ber_hatchet_fan", "ass_shadow_knives"]
const WALL := ["ele_fire_wall", "nec_bone_wall", "pal_shield_wall", "nec_army"]
const FALLBACK := ["sword", "star", "heart", "sun", "skull", "boot"]    # por SkillDef.Kind

## estados na barra de buffs/debuffs do HUD (status_<chave>.png): [tema, símbolo]
const STATUS_ICONS := {"burn": ["fire", "flame"], "poison": ["poison", "drop"], "slow": ["ice", "snowflake"], "root": ["nature", "thorn"],
	"stun": ["lightning", "star"], "curse": ["shadow", "skull"], "wither": ["bone", "bone"], "shield": ["holy", "shield"],
	"juramento": ["holy", "cross"], "buff": ["heal", "sun"]}
## classe: [tema, símbolo, símbolo de trás (ou "")]
const CLASS_ICONS := {
	"paladin": ["holy", "shield", "sword"], "berserker": ["blood", "axe", "axe"], "bishop": ["heal", "cross", ""], "druid": ["nature", "leaf", "paw"],
	"ranger": ["wind", "bow", "arrow"], "assassin": ["shadow", "dagger", "dagger"], "elementalist": ["fire", "flame", "snowflake"], "necromancer": ["bone", "skull", "scythe"],
}

var _queue: Array = []
var _cur: Dictionary = {}
var _vp: SubViewport
var _canvas: Node2D
var _t: Array = []
var _sheet: Array = []

func _ready() -> void:
	var sheet_path := ""
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sheet="): sheet_path = a.get_slice("=", 1)
		if a.begins_with("--only="): only = a.get_slice("=", 1)
	var glyph_of := {}
	var seen := {}
	for g in GLYPHS:
		for sid in GLYPHS[g]:
			glyph_of[sid] = g
	for cid in CLASS_ICONS:
		_queue.append({"file": "class_" + cid, "cls": cid})
	if only == "" or only == "status":
		for k in STATUS_ICONS:
			_queue.append({"file": "status_" + k, "status": k})
	for sid in GameData.skills:
		var s: SkillDef = GameData.skills[sid]
		if s.class_id == "" or (only != "" and s.class_id != only):
			continue
		if not glyph_of.has(sid):
			push_warning("sem símbolo: " + sid)
		var sign_of := "%s/%s/%s" % [s.class_id, glyph_of.get(sid, FALLBACK[s.kind]), _signature(s)]
		if seen.has(sign_of):
			print("DUP ", sid, " = ", seen[sign_of], " (", s.name, ")")
		seen[sign_of] = sid
		_queue.append({"file": "skill_" + sid, "skill": s, "glyph": glyph_of.get(sid, FALLBACK[s.kind])})
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.transparent_bg = true
	_vp.msaa_2d = Viewport.MSAA_8X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_canvas = Node2D.new()
	_canvas.draw.connect(_paint)
	_vp.add_child(_canvas)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/icons"))
	for job in _queue:
		_cur = job
		_canvas.queue_redraw()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := _vp.get_texture().get_image()
		img.resize(OUT, OUT, Image.INTERPOLATE_LANCZOS)
		img.save_png("res://assets/icons/%s.png" % job["file"])
		_sheet.append(img)
	if sheet_path != "":
		_save_sheet(sheet_path)
	print("ICONS_OK ", _queue.size())
	get_tree().quit()

## O que muda a aparência além do símbolo: dois ícones iguais na mesma classe confundem na barra.
func _signature(s: SkillDef) -> String:
	var shape := "buff" if s.kind == SkillDef.Kind.BUFF else str(s.target if s.target != SkillDef.Target.SELF or s.power > 0.0 else 9)
	return "%s/%s/%s/%s/%s/%s/%s" % [s.vfx, shape, s.effects.has("dash"), s.effects.has("dot"), s.effects.has("heal_pct_of_dmg") or s.effects.has("mend_pct_of_dmg"),
		"t" if s.id in TWIN else ("r" if s.id in RAIN else ("f" if s.id in FAN else ("w" if s.id in WALL else ""))), s.kind == SkillDef.Kind.BUFF]

func _save_sheet(path: String) -> void:
	var cols := 16
	var cell := OUT + 8
	var rows := ceili(_sheet.size() / float(cols))
	var out := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.1, 0.1, 0.12))
	for i in range(_sheet.size()):
		var im: Image = _sheet[i]
		im.convert(Image.FORMAT_RGBA8)
		out.blend_rect(im, Rect2i(0, 0, OUT, OUT), Vector2i(i % cols * cell + 4, i / cols * cell + 4))
	out.save_png(path)

# ---------------------------------------------------------------------------
func _paint() -> void:
	if _cur.is_empty():
		return
	if _cur.has("cls"):
		_paint_class(_cur["cls"])
		return
	if _cur.has("status"):
		var st: Array = STATUS_ICONS[_cur["status"]]
		_t = THEMES[st[0]]
		_frame()
		_glyph(st[1], Vector2(256, 256), _base_angle(st[1]), GLYPH_SIZE * 1.05 * float(GLYPH_WEIGHT.get(st[1], 1.0)))
		_flush()
		return
	var s: SkillDef = _cur["skill"]
	_t = THEMES.get(s.vfx, THEMES["physical"])
	_frame()
	var g: String = _cur["glyph"]
	var id := s.id
	# marcas que dizem a forma ficam ATRÁS do símbolo, finas e translúcidas; selos (buff, dano no tempo, dreno) vão nos cantos
	var badges: Array = []
	if s.kind == SkillDef.Kind.BUFF:
		badges.append("up")
	if s.effects.has("dot"):
		badges.append("drops")
	if s.effects.has("heal_pct_of_dmg") or s.effects.has("mend_pct_of_dmg"):
		badges.append("leech")
	var at := Vector2(256, 256)
	var sc: float = GLYPH_SIZE * float(GLYPH_WEIGHT.get(g, 1.0))
	if s.kind == SkillDef.Kind.BUFF:
		pass
	elif s.target == SkillDef.Target.GROUND:
		_ground()
		at.y -= 30.0
		sc *= 0.88
	elif s.target == SkillDef.Target.CONE:
		_cone()
		at.y += 14.0
	elif s.target == SkillDef.Target.SELF and s.power > 0.0 and s.kind in [SkillDef.Kind.PHYSICAL, SkillDef.Kind.MAGICAL]:
		_ring()
		sc *= 0.86
	if s.effects.has("dash"):
		_speed()
		at.x += 26.0
		sc *= 0.92
	if not badges.is_empty():
		at += Vector2(-10, -14)
		sc *= 0.92
	var base := _base_angle(g)
	if id in WALL:
		for x in [-1, 0, 1]:
			_glyph(g, at + Vector2(x * 112, 30 - absi(x) * 18), base, sc * 0.6)
	elif id in RAIN:
		for q in [[-90, -46], [8, 10], [96, -64]]:
			_glyph(g, at + Vector2(q[0], q[1]), PI * 0.75 if g == "arrow" else 0.0, sc * 0.6)
	elif id in FAN:
		for a in [-0.55, 0.55, 0.0]:
			_glyph(g, at + Vector2(0, 28), a, sc * 0.9)
	elif id in TWIN:
		_glyph(g, at, -0.55, sc * 0.9, true)
		_glyph(g, at, 0.55, sc * 0.9)
	else:
		_glyph(g, at, base, sc)
	_flush()
	var corners := [Vector2(398, 398), Vector2(114, 398)]
	for k in range(mini(badges.size(), corners.size())):
		_badge(badges[k], corners[k])

func _paint_class(cid: String) -> void:
	var c: Array = CLASS_ICONS[cid]
	_t = THEMES[c[0]]
	var center := Vector2(256, 256)
	_circle(center, 248.0, _t[1])
	_disc_gradient(center, 232.0, _t[0], _t[1])
	_ring_line(center, 232.0, Color(0.95, 0.8, 0.45), 14.0)
	if c[2] != "":
		_glyph(c[2], center + Vector2(-34, -10), -0.6, 138.0, true)
	if c[2] == "dagger" or c[2] == "axe":
		_glyph(c[1], center + Vector2(34, -10), 0.6, 138.0)
	else:
		_glyph(c[1], center + Vector2(14, 16), 0.0, 150.0)
	_flush()

# --- moldura e marcas ---
func _frame() -> void:
	var r := 44.0
	var pts := _rounded(Rect2(6, 6, 500, 500), r)
	_canvas.draw_colored_polygon(pts, INK)
	# aro em bisel: claro em cima/esquerda, escuro embaixo/direita
	var bevel := _rounded(Rect2(14, 14, 484, 484), r - 6.0)
	var bc := PackedColorArray()
	for p in bevel:
		var k := clampf((p.x + p.y) / 1000.0, 0.0, 1.0)
		bc.append((_t[0] as Color).lightened(0.45).lerp((_t[1] as Color).darkened(0.35), k))
	_canvas.draw_polygon(bevel, bc)
	var inner := _rounded(Rect2(26, 26, 460, 460), r - 16.0)
	var cols := PackedColorArray()
	for p in inner:
		cols.append((_t[0] as Color).lerp(_t[1], clampf((p.y + p.x * 0.3 - 40.0) / 560.0, 0.0, 1.0)))
	_canvas.draw_polygon(inner, cols)
	# raios suaves saindo do centro
	for i in range(12):
		var a := TAU * i / 12.0 + 0.13
		var c := Vector2(256, 240)
		_canvas.draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a - 0.09) * 330.0, c + Vector2.from_angle(a + 0.09) * 330.0]), Color(_t[4], 0.045))
	# clarão atrás do símbolo
	for i in range(6):
		_canvas.draw_circle(Vector2(256, 238), 190.0 - i * 28.0, Color(_t[4], 0.04))
	# vinheta: bordas de dentro escurecem
	for i in range(7):
		var ring := _rounded(Rect2(26 + i * 7, 26 + i * 7, 460 - i * 14, 460 - i * 14), maxf(4.0, r - 16.0 - i * 5.0))
		ring.append(ring[0])
		_canvas.draw_polyline(ring, Color(INK, 0.1 - i * 0.012), 8.0, true)
	# brilho de vidro em cima
	var gloss := PackedVector2Array()
	for k in range(25):
		var t := k / 24.0
		gloss.append(Vector2(lerpf(48, 464, t), 44.0 + sin(t * PI) * -6.0))
	for k in range(25):
		var t := 1.0 - k / 24.0
		gloss.append(Vector2(lerpf(48, 464, t), 44.0 + sin(t * PI) * 92.0))
	_canvas.draw_colored_polygon(gloss, Color(1, 1, 1, 0.07))
	var rim := inner.duplicate()
	rim.append(inner[0])
	_canvas.draw_polyline(rim, Color(INK, 0.55), 5.0, true)

func _rounded(rc: Rect2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var corners := [rc.position + Vector2(rc.size.x - r, r), rc.end - Vector2(r, r), rc.position + Vector2(r, rc.size.y - r), rc.position + Vector2(r, r)]
	for i in range(4):
		for k in range(9):
			out.append(corners[i] + Vector2.from_angle(-PI * 0.5 + i * PI * 0.5 + k * PI / 16.0) * r)
	return out

func _circle(c: Vector2, r: float, col: Color) -> void:
	_canvas.draw_circle(c, r, col, true, -1.0, true)

func _ring_line(c: Vector2, r: float, col: Color, w: float) -> void:
	_canvas.draw_arc(c, r, 0.0, TAU, 96, col, w, true)

func _disc_gradient(c: Vector2, r: float, a: Color, b: Color) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in range(96):
		var p := c + Vector2.from_angle(TAU * i / 96.0) * r
		pts.append(p)
		cols.append(a.lerp(b, clampf((p.y - c.y + r) / (r * 2.0), 0.0, 1.0)))
	_canvas.draw_polygon(pts, cols)

const GLYPH_SIZE := 160.0
## peso visual: símbolos finos/diagonais crescem, os cheios (sol, chama) encolhem, para todos parecerem do mesmo tamanho
const GLYPH_WEIGHT := {"sword": 1.16, "dagger": 1.22, "arrow": 1.14, "spear": 1.12, "bone": 1.1, "crystal": 1.12, "chain": 1.2,
	"scythe": 1.2, "axe": 1.06, "hammer": 1.04, "sun": 0.9, "flame": 0.94, "star": 0.94, "snowflake": 0.94, "cloud": 0.94, "heart": 0.96}

## Área no chão: duas elipses claras embaixo do símbolo.
func _ground() -> void:
	_canvas.draw_set_transform(Vector2(256, 384), 0.0, Vector2(1.0, 0.34))
	_garc(Vector2.ZERO, 176.0, 72, Color(INK, 0.55), 16.0)
	_garc(Vector2.ZERO, 176.0, 72, Color(_t[4], 0.8), 8.0)
	_garc(Vector2.ZERO, 104.0, 72, Color(_t[4], 0.45), 6.0)
	_canvas.draw_set_transform(Vector2.ZERO)

## Cone: leque translúcido que abre de baixo para cima, atrás do símbolo.
func _cone() -> void:
	var o := Vector2(256, 476)
	var pts := PackedVector2Array([o])
	for k in range(25):
		pts.append(o + Vector2.from_angle(-PI * 0.5 + lerpf(-0.6, 0.6, k / 24.0)) * 420.0)
	_canvas.draw_colored_polygon(pts, Color(_t[4], 0.2))
	for a in [-0.6, 0.6]:
		_canvas.draw_line(o, o + Vector2.from_angle(-PI * 0.5 + a) * 420.0, Color(_t[4], 0.55), 7.0, true)
	_canvas.draw_arc(o, 330.0, -PI * 0.5 - 0.6, -PI * 0.5 + 0.6, 24, Color(_t[4], 0.45), 6.0, true)

## Em volta de si: anel inteiro, fino, atrás do símbolo.
func _ring() -> void:
	_garc(Vector2(256, 256), 200.0, 72, Color(INK, 0.5), 18.0)
	_garc(Vector2(256, 256), 200.0, 72, Color(_t[4], 0.75), 9.0)

## Avanço: três riscos curtos à esquerda, atrás do símbolo.
func _speed() -> void:
	for k in range(3):
		var y := 196.0 + k * 62.0
		var x0 := 60.0 + absf(k - 1.0) * 24.0
		_canvas.draw_line(Vector2(x0, y), Vector2(x0 + 92.0, y), Color(INK, 0.5), 18.0, true)
		_canvas.draw_line(Vector2(x0, y), Vector2(x0 + 92.0, y), Color(_t[4], 0.85), 9.0, true)

## Selo no canto: disco escuro com borda, o símbolo do selo por cima.
func _badge(kind: String, c: Vector2) -> void:
	_circle(c, 70.0, INK)
	var bg: Color = Color(0.2, 0.62, 0.32) if kind == "up" else (Color(0.62, 0.1, 0.16) if kind == "leech" else (_t[1] as Color).lerp(INK, 0.2))
	_circle(c, 58.0, bg.darkened(0.35))
	_circle(c + Vector2(-3, -4), 52.0, bg)
	_canvas.draw_arc(c, 54.0, PI * 1.05, PI * 1.6, 16, Color(1, 1, 1, 0.35), 6.0, true)
	match kind:
		"up":
			for dy in [14.0, -16.0]:
				var pl := PackedVector2Array([c + Vector2(-28, 12 + dy), c + Vector2(0, -14 + dy), c + Vector2(28, 12 + dy)])
				_canvas.draw_polyline(pl, Color(1, 1, 0.9), 12.0, true)
		"drops":
			_drop_at(c + Vector2(-16, 10), 20.0, _t[4])
			_drop_at(c + Vector2(18, -6), 16.0, _t[4])
		"leech":
			_drop_at(c + Vector2(0, 8), 28.0, Color(1.0, 0.45, 0.5))

func _drop_at(p: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(17):
		var a := PI * 0.5 + (i - 8) * PI * 0.09
		pts.append(p + Vector2.from_angle(a) * r)
	pts.append(p + Vector2(0, -r * 1.7))
	var o := PackedVector2Array()
	for q in pts:
		o.append(p + (q - p) * 1.32)
	_canvas.draw_colored_polygon(o, INK)
	_canvas.draw_colored_polygon(pts, col)

# --- símbolos: desenhados em unidade (-1..1), virados para cima ---
func _base_angle(g: String) -> float:
	return {"sword": 0.72, "dagger": 0.72, "arrow": 0.78, "axe": 0.25, "hammer": 0.3, "scythe": 0.12, "bone": 0.72, "crystal": 0.4, "spear": 0.78}.get(g, 0.0)

var _ox := 1.0        # espelho

var _rot := 0.0
var _shadow := false      # passada da sombra: o símbolo inteiro numa cor só, deslocado
var _pending: Array = []
const LIGHT := Vector2(-0.55, -0.83)

## Guarda o símbolo; _flush desenha todas as sombras primeiro e depois os símbolos (dois símbolos cruzados não sombreiam um ao outro).
func _glyph(g: String, at: Vector2, rot: float, sc: float, mirror: bool = false) -> void:
	_pending.append([g, at, rot, sc, mirror])

func _flush() -> void:
	var shade := (_t[1] as Color).darkened(0.55)
	for pass_shadow in [true, false]:
		_shadow = pass_shadow
		for q in _pending:
			_ox = -1.0 if q[4] else 1.0
			_rot = q[2]
			var off: Vector2 = Vector2(12, 17) if pass_shadow else Vector2.ZERO
			_canvas.draw_set_transform(q[1] + off, _rot, Vector2(q[3], q[3]))
			if pass_shadow:
				_shadow_col = Color(shade, 0.78)
			call("_g_" + str(q[0]))
	_canvas.draw_set_transform(Vector2.ZERO)
	_shadow = false
	_ox = 1.0
	_rot = 0.0
	_pending.clear()

var _shadow_col := Color(0, 0, 0, 0.5)

func _fill(pts: PackedVector2Array, col: Color) -> void:
	if pts.size() >= 3 and not Geometry2D.triangulate_polygon(pts).is_empty():
		_canvas.draw_colored_polygon(pts, col)

func _shift(pts: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + d)
	return out

## Tom toon por cima do preenchimento: faixa escura do lado oposto à luz e filete claro do lado dela.
func _toon(pts: PackedVector2Array, c: Color, depth: float) -> void:
	var l := LIGHT.normalized().rotated(-_rot)
	for q in Geometry2D.clip_polygons(pts, _shift(pts, l * depth)):
		_fill(q, c.darkened(0.36))
	for q in Geometry2D.clip_polygons(pts, _shift(pts, -l * depth * 0.4)):
		_fill(q, c.lightened(0.55))

func _v(a: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var i := 0
	while i < a.size():
		out.append(Vector2(float(a[i]) * _ox, float(a[i + 1])))
		i += 2
	return out

## Polígono com contorno; `col`: 2 = símbolo, 3 = sombra, 4 = detalhe, ou uma Color.
func _p(a: Array, col: Variant = 2, w: float = 0.075) -> void:
	var pts := _v(a)
	var c: Color = _t[col] if col is int else col
	var loop := pts.duplicate()
	loop.append(pts[0])
	loop.append(pts[1])
	if _shadow:
		if w > 0.0:
			_canvas.draw_polyline(loop, _shadow_col, w * 2.0, true)
			_fill(pts, _shadow_col)
		return
	_canvas.draw_polyline(loop, INK, w * 2.0, true)
	_fill(pts, c)
	if w > 0.0 and c != INK:
		_toon(pts, c, 0.16)

func _c(x: float, y: float, r: float, col: Variant = 2, w: float = 0.075) -> void:
	var c: Color = _t[col] if col is int else col
	if _shadow:
		if w > 0.0:
			_canvas.draw_circle(Vector2(x * _ox, y), r + w, _shadow_col)
		return
	_canvas.draw_circle(Vector2(x * _ox, y), r + w, INK)
	_canvas.draw_circle(Vector2(x * _ox, y), r, c)
	if w > 0.0 and c != INK and r > 0.12:
		var pts := PackedVector2Array()
		for i in range(28):
			pts.append(Vector2(x * _ox, y) + Vector2.from_angle(TAU * i / 28.0) * r)
		_toon(pts, c, r * 0.32)

## Anel dentro de um símbolo (corrente, alvo, armadilha): respeita a passada da sombra.
func _garc(c: Vector2, r: float, n: int, col: Color, w: float) -> void:
	if _shadow:
		if col == INK:
			_canvas.draw_arc(c, r, 0.0, TAU, n, _shadow_col, w, true)
		return
	_canvas.draw_arc(c, r, 0.0, TAU, n, col, w, true)

func _l(a: Array, col: Variant = 2, w: float = 0.09) -> void:
	var pts := _v(a)
	var c: Color = _t[col] if col is int else col
	if _shadow:
		_canvas.draw_polyline(pts, _shadow_col, w + 0.13, true)
		return
	_canvas.draw_polyline(pts, INK, w + 0.13, true)
	_canvas.draw_polyline(pts, c, w, true)
	if w >= 0.07:
		_canvas.draw_polyline(_shift(pts, LIGHT.normalized().rotated(-_rot) * w * 0.22), Color(c.lightened(0.5), 0.8), w * 0.32, true)

func _arc_pts(cx: float, cy: float, r: float, a0: float, a1: float, n: int = 14) -> Array:
	var out: Array = []
	for i in range(n + 1):
		var a: float = lerpf(a0, a1, float(i) / n)
		out.append(cx + cos(a) * r)
		out.append(cy + sin(a) * r)
	return out

func _g_sword() -> void:
	_p([0, -1.05, 0.15, -0.8, 0.15, 0.42, -0.15, 0.42, -0.15, -0.8])
	_p([0, -1.05, 0.15, -0.8, 0.15, 0.42, 0, 0.42], 3, 0.0)
	_p([-0.42, 0.42, 0.42, 0.42, 0.42, 0.58, -0.42, 0.58], 4)
	_p([-0.09, 0.58, 0.09, 0.58, 0.09, 0.92, -0.09, 0.92], Color(0.46, 0.28, 0.17))
	_c(0, 0.98, 0.1, 4, 0.06)

func _g_dagger() -> void:
	_p([0, -0.95, 0.2, -0.45, 0.13, 0.25, -0.13, 0.25, -0.2, -0.45])
	_p([0, -0.95, 0.2, -0.45, 0.13, 0.25, 0, 0.25], 3, 0.0)
	_p([-0.3, 0.25, 0.3, 0.25, 0.3, 0.38, -0.3, 0.38], 4)
	_p([-0.08, 0.38, 0.08, 0.38, 0.08, 0.76, -0.08, 0.76], Color(0.3, 0.2, 0.26))
	_c(0, 0.82, 0.1, 4, 0.06)

func _g_axe() -> void:
	_p([-0.07, -0.85, 0.07, -0.85, 0.07, 1.0, -0.07, 1.0], Color(0.5, 0.33, 0.2))
	_p([0.05, -0.72, 0.42, -0.86, 0.78, -0.42, 0.72, 0.1, 0.42, -0.08, 0.05, -0.18])
	_p([0.78, -0.42, 0.72, 0.1, 0.56, 0.0, 0.6, -0.6], 3, 0.0)
	_p([-0.05, -0.68, -0.34, -0.8, -0.56, -0.44, -0.52, -0.08, -0.32, -0.2, -0.05, -0.22], 3)

func _g_hammer() -> void:
	_p([-0.08, -0.5, 0.08, -0.5, 0.08, 1.0, -0.08, 1.0], Color(0.5, 0.33, 0.2))
	_p([-0.72, -0.86, 0.72, -0.86, 0.72, -0.2, -0.72, -0.2])
	_p([0.1, -0.86, 0.72, -0.86, 0.72, -0.2, 0.1, -0.2], 3, 0.0)
	_p([-0.14, -0.72, 0.14, -0.72, 0.14, -0.36, -0.14, -0.36], 4, 0.04)

func _g_scythe() -> void:
	# cabo de pé, um pouco inclinado; lâmina em arco para a direita, tudo centrado
	_p([-0.42, -0.9, -0.28, -0.9, 0.0, 1.02, -0.14, 1.02], Color(0.36, 0.26, 0.3))
	var outer: Array = []
	var inner: Array = []
	for k in range(13):
		var t := k / 12.0
		outer.append(lerpf(-0.36, 0.86, t)); outer.append(-0.9 - sin(t * PI) * 0.2 + t * 0.62)
	for k in range(13):
		var t := 1.0 - k / 12.0
		inner.append(lerpf(-0.3, 0.86, t)); inner.append(-0.5 - sin(t * PI) * 0.1 + t * 0.22)
	_p(outer + inner)
	_p(outer.slice(12) + inner.slice(0, 14), 3, 0.0)
func _g_arrow() -> void:
	_p([-0.055, -0.6, 0.055, -0.6, 0.055, 0.82, -0.055, 0.82], Color(0.62, 0.44, 0.26))
	_p([0, -1.05, 0.28, -0.52, 0, -0.62, -0.28, -0.52])
	for s in [-1.0, 1.0]:
		_p([0, 0.5, 0.28 * s, 0.78, 0.28 * s, 1.0, 0, 0.8], 4, 0.05)

func _g_spear() -> void:
	_p([-0.05, -0.6, 0.05, -0.6, 0.05, 1.0, -0.05, 1.0], Color(0.62, 0.44, 0.26))
	_p([0, -1.08, 0.22, -0.56, 0, -0.42, -0.22, -0.56])
	_p([0, -1.08, 0.22, -0.56, 0, -0.42], 3, 0.0)
	for y in [0.0, 0.26, 0.52]:
		_l([-0.26, y, 0.26, y], 4, 0.04)

func _g_bow() -> void:
	_l(_arc_pts(-0.5, 0.0, 1.0, -1.05, 1.05), 2, 0.13)
	_l([0.0, -0.87, -0.3, 0.0, 0.0, 0.87], 4, 0.035)

func _g_shield() -> void:
	_p([0, -0.95, 0.78, -0.72, 0.78, 0.05, 0.42, 0.65, 0, 1.0, -0.42, 0.65, -0.78, 0.05, -0.78, -0.72])
	_p([0, -0.95, 0.78, -0.72, 0.78, 0.05, 0.42, 0.65, 0, 1.0], 3, 0.0)
	_p([-0.11, -0.6, 0.11, -0.6, 0.11, -0.2, 0.42, -0.2, 0.42, 0.02, 0.11, 0.02, 0.11, 0.56, -0.11, 0.56, -0.11, 0.02, -0.42, 0.02, -0.42, -0.2, -0.11, -0.2], 4, 0.04)

func _g_armor() -> void:
	_p([-0.5, -0.86, -0.18, -0.74, 0, -0.5, 0.18, -0.74, 0.5, -0.86, 0.92, -0.5, 0.64, -0.14, 0.5, -0.24, 0.5, 0.86, -0.5, 0.86, -0.5, -0.24, -0.64, -0.14, -0.92, -0.5])
	_p([0, -0.5, 0.18, -0.74, 0.5, -0.86, 0.5, 0.86, 0, 0.86], 3, 0.0)
	_l([-0.46, 0.2, 0.46, 0.2], 4, 0.05)
	_l([0, -0.42, 0, 0.82], 4, 0.05)

func _g_cross() -> void:
	_p([-0.17, -1.0, 0.17, -1.0, 0.17, -0.42, 0.68, -0.42, 0.68, -0.1, 0.17, -0.1, 0.17, 1.0, -0.17, 1.0, -0.17, -0.1, -0.68, -0.1, -0.68, -0.42, -0.17, -0.42])
	_p([0, -1.0, 0.17, -1.0, 0.17, -0.42, 0.68, -0.42, 0.68, -0.1, 0.17, -0.1, 0.17, 1.0, 0, 1.0], 3, 0.0)

func _g_sun() -> void:
	var a: Array = []
	for i in range(24):
		var r := 1.05 if i % 2 == 0 else 0.56
		a.append(cos(i * TAU / 24.0) * r)
		a.append(sin(i * TAU / 24.0) * r)
	_p(a, 3)
	_c(0, 0, 0.42, 2, 0.05)

func _g_star() -> void:
	var a: Array = []
	for i in range(10):
		var r := 1.05 if i % 2 == 0 else 0.42
		a.append(cos(i * TAU / 10.0 - PI * 0.5) * r)
		a.append(sin(i * TAU / 10.0 - PI * 0.5) * r)
	_p(a)

func _g_hand() -> void:
	_p([-0.56, 0.1, -0.56, -0.5, -0.36, -0.5, -0.3, -0.04, -0.27, -0.84, -0.06, -0.84, -0.02, -0.1, 0.04, -0.92, 0.26, -0.9, 0.2, -0.04, 0.34, -0.72, 0.54, -0.68, 0.44, 0.06, 0.66, -0.24, 0.84, -0.12, 0.5, 0.56, 0.22, 0.96, -0.36, 0.96])
	_p([-0.05, 0.0, 0.42, 0.4, -0.05, 0.8, -0.5, 0.4], 3, 0.0)

func _g_heart() -> void:
	_p([0, 0.98, -0.82, 0.08, -0.94, -0.3, -0.8, -0.66, -0.46, -0.8, -0.14, -0.68, 0, -0.42, 0.14, -0.68, 0.46, -0.8, 0.8, -0.66, 0.94, -0.3, 0.82, 0.08], Color(0.95, 0.3, 0.36))
	_p([-0.6, -0.48, -0.34, -0.58, -0.46, -0.3, -0.66, -0.2], Color(1, 0.75, 0.75), 0.0)

func _g_wing() -> void:
	_p([-0.9, 0.5, -0.6, -0.5, 0.0, -0.95, 0.86, -0.95, 0.72, -0.56, 0.88, -0.48, 0.62, -0.1, 0.74, -0.02, 0.4, 0.3, 0.46, 0.4, -0.1, 0.56, -0.5, 0.42])
	_l([-0.6, 0.26, -0.1, -0.5, 0.56, -0.68], 3, 0.05)
	_l([-0.5, 0.36, 0.1, -0.1, 0.44, -0.2], 3, 0.05)

func _g_shout() -> void:
	_p([-0.86, -0.28, -0.42, -0.28, 0.1, -0.74, 0.1, 0.74, -0.42, 0.28, -0.86, 0.28])
	_p([-0.42, 0.28, 0.1, 0.74, 0.1, 0.0, -0.86, 0.0, -0.86, 0.28], 3, 0.0)
	for r in [0.46, 0.76]:
		_l(_arc_pts(0.14, 0, r, -0.72, 0.72), 4, 0.075)

func _g_fist() -> void:
	_p([-0.7, -0.5, -0.46, -0.84, 0.46, -0.84, 0.72, -0.56, 0.72, 0.12, 0.44, 0.46, 0.44, 0.98, -0.44, 0.98, -0.44, 0.46, -0.7, 0.14])
	for x in [-0.26, 0.2]:
		_l([x, -0.82, x, -0.34], 3, 0.06)
	_p([-0.74, -0.2, 0.28, -0.2, 0.36, 0.1, -0.5, 0.2], 3, 0.06)

func _g_drop() -> void:
	var a: Array = [0.0, -1.05]
	for i in range(19):
		var t := PI * 0.5 + (i - 9) * PI * 0.08
		a.append(cos(t) * 0.68)
		a.append(0.3 + sin(t) * 0.68)
	_p(a)
	_c(-0.24, 0.4, 0.13, 4, 0.0)

func _g_claw() -> void:
	for x in [-0.56, 0.0, 0.56]:
		_p([x + 0.36, -1.0, x + 0.2, 0.0, x - 0.32, 0.96, x - 0.08, 0.0])

func _g_paw() -> void:
	_c(0, 0.36, 0.56, 2)
	for p in [[-0.72, -0.08], [-0.28, -0.56], [0.28, -0.56], [0.72, -0.08]]:
		_c(p[0], p[1], 0.24, 3)

func _g_leaf() -> void:
	_p([0, -1.0, 0.56, -0.56, 0.68, 0.0, 0.36, 0.56, 0, 0.74, -0.36, 0.56, -0.68, 0.0, -0.56, -0.56])
	_p([0, -1.0, 0.56, -0.56, 0.68, 0.0, 0.36, 0.56, 0, 0.74], 3, 0.0)
	_l([0, -0.56, 0, 1.0], 1, 0.07)
	for y in [-0.2, 0.2]:
		_l([0, y + 0.2, 0.36, y - 0.14], 1, 0.04)
		_l([0, y + 0.2, -0.36, y - 0.14], 1, 0.04)

func _g_thorn() -> void:
	_l([-0.3, 1.0, 0.3, 0.4, -0.3, -0.2, 0.2, -0.95], 3, 0.2)
	for p in [[0.28, 0.42, 0.72, 0.2], [-0.28, -0.18, -0.72, -0.42], [0.04, 0.72, -0.54, 0.62], [-0.06, -0.58, 0.46, -0.7]]:
		var dx: float = p[2] - p[0]
		var dy: float = p[3] - p[1]
		var n := Vector2(-dy, dx).normalized() * 0.13
		_p([p[0] - n.x, p[1] - n.y, p[2], p[3], p[0] + n.x, p[1] + n.y], 2, 0.05)

func _g_tree() -> void:
	_p([-0.16, 0.2, 0.16, 0.2, 0.26, 1.0, -0.26, 1.0], Color(0.5, 0.33, 0.2))
	_c(-0.44, -0.1, 0.42, 3)
	_c(0.44, -0.1, 0.42, 3)
	_c(0, -0.52, 0.5, 2)

func _g_bug() -> void:
	for y in [-0.2, 0.2, 0.56]:
		_l([-0.72, y - 0.14, 0.72, y - 0.14], 1, 0.04)
	_p([0, -0.32, 0.86, -0.72, 0.9, -0.34, 0.3, 0.14], 4, 0.05)
	_p([0, -0.32, -0.86, -0.72, -0.9, -0.34, -0.3, 0.14], 4, 0.05)
	_c(0, 0.28, 0.42, 3)
	_c(0, -0.42, 0.3, 2)

func _g_mountain() -> void:
	_p([-1.0, 0.86, -0.3, -0.62, 0.0, -0.1, 0.34, -0.92, 1.0, 0.86], 3)
	_p([-0.3, -0.62, -0.5, -0.18, -0.26, -0.28, -0.1, -0.16], 2, 0.0)
	_p([0.34, -0.92, 0.1, -0.34, 0.32, -0.48, 0.56, -0.3], 2, 0.0)

func _g_moon() -> void:
	# crescente abrindo para a direita
	var a: Array = _arc_pts(0, 0, 0.95, PI * 0.42, PI * 1.58, 24)
	var tip := Vector2(cos(PI * 1.58) * 0.95, sin(PI * 1.58) * 0.95)
	var bot := Vector2(cos(PI * 0.42) * 0.95, sin(PI * 0.42) * 0.95)
	var b: Array = []
	for k in range(1, 16):
		var t := k / 16.0
		b.append(lerpf(tip.x, bot.x, t) - 0.58 * (1.0 - pow(2.0 * t - 1.0, 2.0))); b.append(lerpf(tip.y, bot.y, t))
	_p(a + b)
	_c(-0.52, -0.3, 0.1, 4, 0.0)
	_c(-0.6, 0.2, 0.07, 4, 0.0)
func _g_tornado() -> void:
	# funil: anéis achatados que estreitam para baixo e ondulam de lado
	for i in range(5):
		var t := i / 4.0
		var rx: float = lerpf(0.92, 0.22, t)
		var cx := sin(i * 1.3) * 0.14
		var y := -0.72 + i * 0.4
		var pts: Array = []
		for k in range(15):
			var a := PI * k / 14.0
			pts.append(cx + cos(a) * rx); pts.append(y + sin(a) * rx * 0.28)
		_l(pts, 2 if i % 2 == 0 else 3, 0.11)
	_l([sin(5.2) * 0.14, 0.9, 0.1, 1.04], 3, 0.08)
func _g_bolt() -> void:
	_p([0.28, -1.0, -0.56, 0.12, -0.08, 0.12, -0.36, 1.0, 0.6, -0.26, 0.08, -0.26, 0.5, -1.0])
	_p([0.28, -1.0, 0.5, -1.0, 0.08, -0.26, -0.1, -0.2], 3, 0.0)

func _g_chain() -> void:
	for i in range(3):
		var c := Vector2(-0.56 + i * 0.56, 0.56 - i * 0.56)
		_garc(c, 0.34, 28, INK, 0.3)
		_garc(c, 0.34, 28, _t[2], 0.14)

func _g_target() -> void:
	_garc(Vector2.ZERO, 0.66, 36, INK, 0.28)
	_garc(Vector2.ZERO, 0.66, 36, Color(0.95, 0.25, 0.22), 0.14)
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		_l([d.x * 0.42, d.y * 0.42, d.x * 1.0, d.y * 1.0], 2, 0.1)
	_c(0, 0, 0.14, 4, 0.05)

func _g_eye() -> void:
	var up: Array = _arc_pts(0, 0.82, 1.3, -PI + 0.72, -0.72, 14)
	var dn: Array = _arc_pts(0, -0.82, 1.3, 0.72, PI - 0.72, 14)
	_p(up + dn)
	_c(0, 0, 0.36, 3, 0.05)
	_c(0, 0, 0.17, INK, 0.0)

func _g_trap() -> void:
	_garc(Vector2(0, 0.12), 0.8, 36, INK, 0.3)
	_garc(Vector2(0, 0.12), 0.8, 36, _t[3], 0.15)
	for i in range(8):
		var a := i * TAU / 8.0
		var o := Vector2.from_angle(a) * 0.74 + Vector2(0, 0.12)
		var t := Vector2.from_angle(a) * 0.2 + Vector2(0, 0.12)
		var n := Vector2.from_angle(a + PI * 0.5) * 0.2
		_p([o.x - n.x, o.y - n.y, t.x, t.y, o.x + n.x, o.y + n.y], 2, 0.04)

func _g_net() -> void:
	for i in range(5):
		var k := -0.8 + i * 0.4
		_l([k, -0.9, k + 0.0, 0.9], 2, 0.06)
		_l([-0.9, k, 0.9, k], 2, 0.06)

func _g_boot() -> void:
	_p([-0.44, -0.9, 0.3, -0.9, 0.34, 0.14, 0.92, 0.42, 0.98, 0.9, -0.5, 0.9])
	_p([-0.5, 0.62, 0.98, 0.62, 0.98, 0.9, -0.5, 0.9], 3, 0.04)
	_l([-0.44, -0.66, 0.3, -0.66], 4, 0.06)

func _g_cloud() -> void:
	_c(-0.48, 0.2, 0.42, 3)
	_c(0.48, 0.2, 0.42, 3)
	_c(0, -0.14, 0.56, 2)
	_c(-0.04, 0.34, 0.36, 2, 0.0)
	_c(-0.3, 0.3, 0.26, 2, 0.0)
	_c(0.3, 0.3, 0.26, 2, 0.0)

func _g_flame() -> void:
	_p([0.0, -1.05, 0.34, -0.56, 0.3, -0.26, 0.56, -0.5, 0.78, 0.14, 0.62, 0.72, 0, 1.0, -0.62, 0.72, -0.78, 0.14, -0.52, -0.3, -0.34, -0.06, -0.24, -0.56], 3)
	_p([0.04, -0.3, 0.4, 0.22, 0.34, 0.66, 0, 0.84, -0.34, 0.66, -0.4, 0.24, -0.2, 0.08, -0.12, 0.22], 2, 0.0)

func _g_meteor() -> void:
	for p in [[-0.26, -0.24, 0.72, -0.98], [0.08, 0.08, 0.98, -0.72], [-0.42, -0.0, 0.4, -0.66]]:
		_p([p[0] - 0.17, p[1] - 0.17, p[2], p[3], p[0] + 0.17, p[1] + 0.17], 3, 0.05)
	_c(-0.3, 0.32, 0.56, Color(0.46, 0.24, 0.18))
	_c(-0.44, 0.2, 0.15, 2, 0.0)
	_c(-0.12, 0.5, 0.11, 2, 0.0)

func _g_bird() -> void:
	_p([0, -0.62, 0.3, -0.34, 0.92, -0.92, 0.84, -0.3, 0.98, -0.16, 0.56, 0.2, 0.2, 0.3, 0.26, 1.0, 0, 0.74, -0.26, 1.0, -0.2, 0.3, -0.56, 0.2, -0.98, -0.16, -0.84, -0.3, -0.92, -0.92, -0.3, -0.34])
	_p([0, -0.62, 0.3, -0.34, 0.2, 0.3, 0.26, 1.0, 0, 0.74], 3, 0.0)
	_c(0, -0.72, 0.17, 2, 0.05)

func _g_crystal() -> void:
	_p([0, -1.05, 0.44, -0.42, 0.3, 0.72, 0, 1.0, -0.3, 0.72, -0.44, -0.42])
	_p([0, -1.05, 0.44, -0.42, 0.3, 0.72, 0, 1.0, 0.08, -0.34], 3, 0.0)

func _g_snowflake() -> void:
	for i in range(3):
		var d := Vector2.from_angle(i * PI / 3.0 + PI * 0.5)
		_l([-d.x, -d.y, d.x, d.y], 2, 0.13)
	for i in range(6):
		var d := Vector2.from_angle(i * PI / 3.0)
		var m := d * 0.62
		for s in [-0.75, 0.75]:
			var t := m + d.rotated(s) * 0.34
			_l([m.x, m.y, t.x, t.y], 3, 0.09)

func _g_skull() -> void:
	_p([-0.34, 0.42, -0.74, 0.14, -0.84, -0.3, -0.56, -0.78, 0, -0.96, 0.56, -0.78, 0.84, -0.3, 0.74, 0.14, 0.34, 0.42, 0.3, 0.84, -0.3, 0.84])
	_p([0, -0.96, 0.56, -0.78, 0.84, -0.3, 0.74, 0.14, 0.34, 0.42, 0.3, 0.84, 0, 0.84], 3, 0.0)
	_c(-0.34, -0.14, 0.22, INK, 0.0)
	_c(0.34, -0.14, 0.22, INK, 0.0)
	_p([0, 0.1, 0.11, 0.32, -0.11, 0.32], INK, 0.0)
	for x in [-0.14, 0.14]:
		_l([x, 0.58, x, 0.84], INK, 0.03)
	_c(-0.34, -0.14, 0.07, 4, 0.0)
	_c(0.34, -0.14, 0.07, 4, 0.0)

func _g_ghost() -> void:
	_p([-0.62, 0.92, -0.62, -0.3, -0.42, -0.8, 0, -0.98, 0.42, -0.8, 0.62, -0.3, 0.62, 0.92, 0.36, 0.64, 0.14, 0.92, -0.1, 0.64, -0.34, 0.92])
	_c(-0.22, -0.3, 0.13, INK, 0.0)
	_c(0.22, -0.3, 0.13, INK, 0.0)
	_c(0, 0.08, 0.14, INK, 0.0)

func _g_bone() -> void:
	_p([-0.14, -0.72, 0.14, -0.72, 0.14, 0.72, -0.14, 0.72])
	for p in [[-0.2, -0.86], [0.2, -0.86], [-0.2, 0.86], [0.2, 0.86]]:
		_c(p[0], p[1], 0.24)
	_p([-0.12, -0.74, 0.12, -0.74, 0.12, 0.74, -0.12, 0.74], 2, 0.0)
