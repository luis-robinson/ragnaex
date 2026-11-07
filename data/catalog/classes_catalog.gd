class_name ClassesCatalog
extends RefCounted
## As 8 classes. Atributos vêm do equipamento (ver items_catalog / gear_catalog).
## Cada classe tem 2-3 builds (arma + skills + conjunto lendário). skill_ids é preenchido pelo
## GameData com todas as skills da classe (skills_catalog); starting_skills são as 2 de nível 1.

static func _mk(d: Dictionary) -> ClassDef:
	var c := ClassDef.new()
	for k in d:
		c.set(k, d[k])
	if c.model == "":
		c.model = c.id   # assets/models/<id>.glb (gerado por tools/blender/chibi_kit.py)
	c.can_use_shield = "shield" in c.offhand_types
	return c

static func _s(a: Array) -> Array[String]:
	var out: Array[String] = []
	for x in a:
		out.append(x)
	return out

## Build: armas (main/off), armadura do conjunto, atributos e stat do bônus de 5 peças, skills em prioridade.
## Efeito-assinatura de cada build (LegendEffects.signature_on_hit): magia que dispara de graça ao acertar com o
## básico ou com skills, em qualquer nível e com qualquer arma. `look` = tema visual do básico da build (só aparência).
const SIGNATURES := {
	"guardiao": {"skill": "pal_holy_strike", "look": "holy"}, "cruzado": {"skill": "pal_holy_wave", "look": "holy"},
	"carniceiro": {"skill": "ber_throw_axe", "look": "blood"}, "executor": {"skill": "ber_overhead", "look": "blood"}, "arremessador": {"skill": "ber_hatchet", "look": "blood", "power": 0.8},
	"sacerdote": {"skill": "bis_light", "look": "holy"}, "inquisidor": {"skill": "bis_hammer", "look": "holy"},
	"guardiao_verde": {"skill": "dru_moonfire", "look": "nature"}, "fera": {"skill": "dru_claw", "look": "nature", "power": 0.8}, "xama": {"skill": "dru_moonfire", "look": "lunar", "power": 0.85},
	"cacador": {"skill": "ran_frost_arrow", "look": "ice"}, "atirador": {"skill": "ran_snipe", "look": "fire"},
	"laminas": {"skill": "ass_venom_dart", "look": "poison", "power": 0.8}, "duelista": {"skill": "ass_thrust", "look": "blood", "power": 0.55}, "trapaceiro": {"skill": "ass_shadow_knives", "look": "shadow", "power": 0.7},
	"fogo": {"skill": "ele_fireball", "look": "fire"}, "gelo": {"skill": "ele_ice_lance", "look": "ice", "power": 0.9}, "raio": {"skill": "ele_chain", "look": "lightning"},
	"invocador": {"skill": "nec_bone_spear", "look": "bone"}, "ceifador": {"skill": "nec_soul_rend", "look": "shadow", "power": 0.8}, "pestilento": {"skill": "nec_mind_flay", "look": "shadow", "power": 0.7},
}

static func _b(id: String, name: String, role: String, main: Array, off: Array, armor: String, attr: String, attr2: String, stat: String, skills: Array) -> Dictionary:
	return {"id": id, "name": name, "role": role, "main": main, "off": off, "armor": armor,
		"attr": attr, "attr2": attr2, "stat": stat, "skills": skills}

static func build() -> Array:
	return [
		_mk({"id": "paladin", "body_type": "male", "hair_color": Color(0.85, 0.65, 0.3), "name": "Paladino", "role": "tank", "color": Color(0.95, 0.85, 0.45),
			"description": "Guerreiro sagrado. Tanque de escudo ou cruzado de arma de duas mãos.",
			"weapon_types": _s(["sword", "mace", "sword2h", "mace2h"]), "offhand_types": _s(["shield"]),
			"base_hp": 140.0, "base_mp": 45.0, "hp_per_level": 16.0, "mp_per_level": 5.0, "move_speed": 5.2,
			"basic_attack_power": 1.0, "basic_attack_cooldown": 0.7, "basic_attack_range": 1.9,
			"starting_equipment": _s(["sword_rusty", "shield_wood"] + ItemsCatalog.starter_ids("paladin")),
			"starting_skills": _s(["pal_holy_strike", "pal_blessed_armor"]),
			"builds": [
				_b("guardiao", "Guardião", "tank", ["sword", "mace"], ["shield"], "plate", "VIT", "FOR", "def_pct",
					["pal_holy_strike", "pal_shield_bash", "pal_blessed_armor", "pal_shield_wall", "pal_aegis_slam", "pal_lay_hands", "pal_taunt", "pal_divine_shield", "pal_retribution"]),
				_b("cruzado", "Cruzado", "dps", ["sword2h", "mace2h"], [], "plate", "FOR", "WILL", "atk_pct",
					["pal_holy_strike", "pal_crusader_strike", "pal_twin_slash", "pal_consecrate", "pal_lunge", "pal_hammer_light", "pal_blade_dance",
					 "pal_holy_wave", "pal_flurry", "pal_zeal", "pal_valor", "pal_judgement_blade", "pal_purge"]),
			]}),
		_mk({"id": "berserker", "body_type": "male", "hair_color": Color(0.55, 0.2, 0.12), "name": "Berserker", "role": "dps", "color": Color(0.85, 0.3, 0.25),
			"description": "Fúria pura. Dois machados velozes que bebem o sangue do inimigo, um machado de duas mãos que aguenta o tranco e executa, ou machadinhas arremessadas que deixam tudo sangrando.",
			"weapon_types": _s(["axe2h", "axe"]), "offhand_types": _s(["axe"]),
			"base_hp": 125.0, "base_mp": 40.0, "hp_per_level": 14.0, "mp_per_level": 4.0, "move_speed": 5.4,
			"basic_attack_power": 1.25, "basic_attack_cooldown": 0.85, "basic_attack_range": 2.2,
			"starting_equipment": _s(["axe_old"] + ItemsCatalog.starter_ids("berserker")),
			"starting_skills": _s(["ber_cleave", "ber_bloodlust"]),
			"builds": [
				_b("carniceiro", "Machados Gêmeos", "dps", ["axe"], ["axe"], "leather", "FOR", "AGI", "aspd_pct",
					["ber_hack", "ber_twin_fang", "ber_cleave", "ber_rend", "ber_blade_rush", "ber_axe_storm", "ber_steel_whirl", "ber_throw_axe",
					 "ber_crimson_flurry", "ber_fury", "ber_butcher", "ber_bladestorm", "ber_leap"]).merged({
					# velocidade de ataque e roubo de vida (árvore e conjunto)
					"passives": [{"aspd_pct": 3}, {"lifesteal": 1}], "set_extra": {3: {"lifesteal": [3.0, 0.8]}}}),
				_b("executor", "Executor", "dps", ["axe2h"], [], "plate", "FOR", "VIT", "atk_pct",
					["ber_cleave", "ber_overhead", "ber_bloodlust", "ber_whirlwind", "ber_earthsplitter", "ber_execute", "ber_titan_grip", "ber_warcry", "ber_decapitate"]).merged({
					# tanque de apoio: vida e defesa na árvore e no conjunto, sem perder o dano
					"passives": [{"atk_pct": 3}, {"hp_pct": 4}, {"def_pct": 3}], "set_extra": {3: {"hp_pct": [5.0, 1.5], "def_pct": [5.0, 1.5]}}}),
				# meia distância: machadinhas arremessadas e sangramento; mistura os talhos dos Gêmeos com os gritos gerais
				_b("arremessador", "Arremessador", "dps", ["axe"], ["axe"], "leather", "FOR", "AGI", "atk_pct",
					["ber_hatchet", "ber_great_throw", "ber_tomahawk_rain", "ber_hatchet_fan", "ber_ricochet", "ber_throw_axe", "ber_hack", "ber_rend",
					 "ber_fury", "ber_bloodlust", "ber_leap", "ber_warcry", "ber_cleave"]).merged({
					# crítico e recarga: mais arremessos (árvore e conjunto); a arma dá Hemorragia (alvo sangrando apanha mais)
					"passives": [{"atk_pct": 3}, {"crit": 1.5}, {"cdr": 2}], "set_extra": {3: {"crit": [3.0, 0.6], "cdr": [3.0, 0.8]}}}),
			]}),
		_mk({"id": "bishop", "body_type": "female", "hair_color": Color(0.95, 0.85, 0.55), "name": "Bispo", "role": "healer", "color": Color(0.95, 0.95, 0.9),
			"description": "Fé. Sacerdote de maça e escudo que cura e fortalece o grupo, ou Iluminado de cetro que fere com luz e cura com o próprio golpe.",
			"weapon_types": _s(["scepter", "mace"]), "offhand_types": _s(["shield"]),
			"base_hp": 90.0, "base_mp": 90.0, "hp_per_level": 9.0, "mp_per_level": 10.0, "move_speed": 5.3,
			"basic_attack_power": 0.9, "basic_attack_cooldown": 0.75, "basic_attack_range": 7.0, "basic_attack_is_ranged": true, "basic_attack_kind": 1,
			"starting_equipment": _s(["scepter_t0"] + ItemsCatalog.starter_ids("bishop")),
			"starting_skills": _s(["bis_heal", "bis_light"]),
			"builds": [
				_b("sacerdote", "Sacerdote", "healer", ["mace"], ["shield"], "cloth", "WILL", "VIT", "heal_pct",
					["bis_heal", "bis_light", "bis_renew", "bis_prayer", "bis_blessing", "bis_sanctuary", "bis_ward", "bis_mend", "bis_angel", "bis_martyr", "bis_miracle"]).merged({
					# suporte: cura mais forte e bênçãos que duram mais (árvore e conjunto)
					"passives": [{"heal_pct": 4}, {"buff_pct": 6}], "set_extra": {3: {"buff_pct": [10.0, 3.0]}}}),
				_b("inquisidor", "Iluminado", "dps", ["scepter"], [], "cloth", "INT", "WILL", "matk_pct",
					["bis_light", "bis_smite", "bis_holy_nova", "bis_hammer", "bis_condemn", "bis_exorcism", "bis_zealot", "bis_purify", "bis_crusade", "bis_judgement", "bis_wrath"]).merged({
					# luz: dano mágico e Radiância (parte do dano cura o aliado mais ferido por perto)
					"passives": [{"matk_pct": 3}, {"radiance": 2}], "set_extra": {3: {"radiance": [6.0, 1.5]}}}),
			]}),
		_mk({"id": "druid", "body_type": "female", "hair_color": Color(0.4, 0.28, 0.16), "name": "Druida", "role": "caster", "color": Color(0.45, 0.8, 0.35),
			"description": "Natureza. Xamã de cajado que invoca e abençoa, lobo veloz que some nas sombras (duas maças) ou urso que segura a linha (malho).",
			"weapon_types": _s(["staff", "mace", "mace2h"]), "offhand_types": _s(["mace"]),
			"base_hp": 105.0, "base_mp": 75.0, "hp_per_level": 11.0, "mp_per_level": 8.0, "move_speed": 5.5,
			"basic_attack_power": 0.9, "basic_attack_cooldown": 0.7, "basic_attack_range": 6.5, "basic_attack_is_ranged": true, "basic_attack_kind": 1,
			"starting_equipment": _s(["staff_oak"] + ItemsCatalog.starter_ids("druid")),
			"starting_skills": _s(["dru_thorns", "dru_bark"]),
			"starting_bag": _s(["mace_t0", "mace_t0", "mace2h_t0"]),     # Fera (duas maças: lobo) e Guardião (martelo: urso) desde o início
			"builds": [
				_b("guardiao_verde", "Urso", "tank", ["mace2h"], [], "plate", "VIT", "WILL", "def_pct",
					["dru_bear_form", "dru_maul", "dru_bellow", "dru_thorns", "dru_earth_slam", "dru_bark", "dru_oak_skin", "dru_stampede", "dru_regrowth", "dru_mountain"]).merged({
					"passives": [{"hp_pct": 4}, {"def_pct": 3}], "set_extra": {3: {"hp_pct": [5.0, 1.5]}}}),
				_b("fera", "Lobo", "dps", ["mace"], ["mace"], "leather", "FOR", "AGI", "atk_pct",
					["dru_wolf_form", "dru_claw", "dru_prowl", "dru_maim", "dru_thorns", "dru_pounce", "dru_frenzy", "dru_rampage", "dru_regrowth", "dru_savage", "dru_entangle"]).merged({
					"passives": [{"aspd_pct": 3}, {"crit": 1.5}], "set_extra": {3: {"aspd_pct": [6.0, 2.0]}}}),
				_b("xama", "Xamã", "caster", ["staff"], [], "cloth", "INT", "WILL", "matk_pct",
					["dru_thorns", "dru_moonfire", "dru_grove", "dru_entangle", "dru_spirit_wolves", "dru_swarm", "dru_starfall", "dru_cyclone", "dru_treant", "dru_wild_growth", "dru_regrowth", "dru_storm"]).merged({
					# natureza: magia, invocações e bênçãos que duram mais
					"passives": [{"matk_pct": 3}, {"buff_pct": 6}], "set_extra": {3: {"buff_pct": [10.0, 3.0]}}}),
			]}),
		_mk({"id": "ranger", "body_type": "female", "hair_color": Color(0.75, 0.4, 0.2), "name": "Ranger", "role": "ranged", "color": Color(0.5, 0.75, 0.55),
			"description": "Caçador de arco com um lince companheiro, ou atirador de mosquete que espalha armadilhas pelo chão.",
			"weapon_types": _s(["bow", "rifle"]), "offhand_types": _s([]),
			"base_hp": 100.0, "base_mp": 55.0, "hp_per_level": 10.0, "mp_per_level": 6.0, "move_speed": 5.8,
			"basic_attack_power": 1.0, "basic_attack_cooldown": 0.55, "basic_attack_range": 13.0, "basic_attack_is_ranged": true,
			"starting_equipment": _s(["bow_short"] + ItemsCatalog.starter_ids("ranger")),
			"starting_skills": _s(["ran_power_shot", "ran_disengage"]),
			"builds": [
				_b("cacador", "Caçador", "ranged", ["bow"], [], "leather", "AGI", "VIT", "atk_pct",
					["ran_power_shot", "ran_companion", "ran_multishot", "ran_anchor", "ran_frost_arrow", "ran_sic", "ran_explosive", "ran_piercing", "ran_net",
					 "ran_pack", "ran_rain", "ran_volley", "ran_barrage", "ran_disengage"]).merged({
					# companheiro mais forte (árvore e conjunto)
					"passives": [{"atk_pct": 3}, {"pet_pct": 5}], "set_extra": {3: {"pet_pct": [10.0, 3.0]}}}),
				_b("atirador", "Atirador", "ranged", ["rifle"], [], "leather", "AGI", "FOR", "atk_pct",
					["ran_power_shot", "ran_trap", "ran_anchor", "ran_scatter", "ran_snipe", "ran_mine", "ran_frost_trap", "ran_mark", "ran_headshot", "ran_deadeye", "ran_disengage"]).merged({
					"passives": [{"atk_pct": 3}, {"crit": 1.5}], "set_extra": {3: {"crit": [4.0, 1.0]}}}),
			]}),
		_mk({"id": "assassin", "body_type": "male", "hair_color": Color(0.2, 0.18, 0.25), "name": "Assassino", "role": "dps", "color": Color(0.55, 0.35, 0.75),
			"description": "Sombras. Duas adagas velozes com veneno, esquiva e golpes pelas costas saindo da furtividade, duelista equilibrado de duas espadas, ou trapaceiro de espada e adaga que controla a luta com fumaça, estrepes e golpes baixos.",
			"weapon_types": _s(["dagger", "sword"]), "offhand_types": _s(["dagger", "sword"]),
			"base_hp": 95.0, "base_mp": 60.0, "hp_per_level": 10.0, "mp_per_level": 6.0, "move_speed": 6.2,
			"basic_attack_power": 0.75, "basic_attack_cooldown": 0.38, "basic_attack_range": 1.7,
			"starting_equipment": _s(["dagger_iron"] + ItemsCatalog.starter_ids("assassin")),
			"starting_skills": _s(["ass_backstab", "ass_quick_stab"]),
			"builds": [
				_b("laminas", "Lâminas", "dps", ["dagger"], ["dagger"], "leather", "AGI", "FOR", "aspd_pct",
					["ass_twin_strike", "ass_backstab", "ass_plague_blade", "ass_quick_stab", "ass_shadowstep", "ass_poison", "ass_vanish", "ass_blade_flurry", "ass_venom_dart",
					 "ass_fan", "ass_reflexes", "ass_eviscerate", "ass_paralyze", "ass_toxic_cloud", "ass_dance", "ass_execute", "ass_virulence", "ass_thousand"]).merged({
					# velocidade, esquiva e pelas costas (árvore e conjunto)
					"passives": [{"aspd_pct": 3}, {"evasion": 1.5}, {"backstab": 6}], "set_extra": {3: {"evasion": [4.0, 1.0], "backstab": [10.0, 3.0]}}}),
				_b("duelista", "Duelista", "dps", ["sword"], ["sword"], "leather", "AGI", "FOR", "atk_pct",
					["ass_cross_slash", "ass_backstab", "ass_quick_stab", "ass_thrust", "ass_shadowstep", "ass_guard", "ass_lunge", "ass_steel_whirl", "ass_crimson",
					 "ass_execute", "ass_focus", "ass_master"]).merged({
					# equilibrado: ataque, defesa e um pouco de crítico
					"passives": [{"atk_pct": 3}, {"def_pct": 3}, {"crit": 1.5}], "set_extra": {3: {"def_pct": [5.0, 1.5], "crit": [3.0, 0.5]}}}),
				# controle: espada + adaga de aparar, fumaça, estrepes e golpes baixos; mistura venenos das Lâminas e a guarda do Duelista
				_b("trapaceiro", "Trapaceiro", "dps", ["sword"], ["dagger"], "leather", "AGI", "VIT", "atk_pct",
					["ass_shadow_knives", "ass_cheap_shot", "ass_expose", "ass_smoke_bomb", "ass_backstab", "ass_caltrops", "ass_paralyze", "ass_vanish",
					 "ass_thrust", "ass_quick_stab", "ass_shadowstep", "ass_guard", "ass_toxic_cloud", "ass_smoke", "ass_execute", "ass_venom_dart"]).merged({
					# recarga e defesa (árvore e conjunto): mais controle na mão; a arma dá Truque Sujo (alvo preso/lento apanha mais)
					"passives": [{"atk_pct": 3}, {"cdr": 2}, {"def_pct": 3}], "set_extra": {3: {"cdr": [4.0, 1.0], "def_pct": [4.0, 1.0]}}}),
			]}),
		_mk({"id": "elementalist", "body_type": "female", "hair_color": Color(0.25, 0.3, 0.55), "name": "Elementalista", "role": "caster", "color": Color(0.35, 0.6, 0.95),
			"description": "Cajado e três elementos que se misturam: fogo, gelo e raio, combinações e elementais invocados. O maior dano mágico do jogo.",
			"weapon_types": _s(["staff"]), "offhand_types": _s([]),
			"base_hp": 85.0, "base_mp": 100.0, "hp_per_level": 8.0, "mp_per_level": 11.0, "move_speed": 5.3,
			"basic_attack_power": 1.0, "basic_attack_cooldown": 0.65, "basic_attack_range": 8.0, "basic_attack_is_ranged": true, "basic_attack_kind": 1,
			"starting_equipment": _s(["staff_novice"] + ItemsCatalog.starter_ids("elementalist")),
			"starting_skills": _s(["ele_fireball", "ele_spark"]),
			"builds": [
				# foco, não caminho fechado: todos usam cajado, então dá para misturar ramos à vontade
				_b("fogo", "Fogo", "caster", ["staff"], [], "cloth", "INT", "WILL", "matk_pct",
					["ele_fireball", "ele_flame_wave", "ele_combustion", "ele_summon_fire", "ele_meteor", "ele_firestorm", "ele_fire_wall", "ele_frost_flare",
					 "ele_blink", "ele_inferno", "ele_phoenix", "ele_prism"]).merged({
					"passives": [{"matk_pct": 3}, {"fire_pct": 4}], "set_extra": {3: {"fire_pct": [6.0, 2.0]}}}),
				_b("gelo", "Gelo", "caster", ["staff"], [], "cloth", "INT", "VIT", "matk_pct",
					["ele_ice_lance", "ele_frost_nova", "ele_fireball", "ele_frost_armor", "ele_glacier", "ele_summon_ice", "ele_frost_flare", "ele_shatter",
					 "ele_hailstorm", "ele_blizzard", "ele_blink", "ele_absolute_zero", "ele_prism"]).merged({
					"passives": [{"matk_pct": 3}, {"frost_pct": 4}, {"hp_pct": 3}], "set_extra": {3: {"frost_pct": [6.0, 2.0]}}}),
				_b("raio", "Raio", "caster", ["staff"], [], "cloth", "INT", "WILL", "matk_pct",
					["ele_spark", "ele_lightning", "ele_chain", "ele_static", "ele_firestorm", "ele_summon_storm", "ele_overload", "ele_hailstorm",
					 "ele_thunder", "ele_blink", "ele_storm_lord", "ele_prism"]).merged({
					"passives": [{"matk_pct": 3}, {"storm_pct": 4}], "set_extra": {3: {"storm_pct": [6.0, 2.0]}}}),
			]}),
		_mk({"id": "necromancer", "body_type": "male", "hair_color": Color(0.85, 0.85, 0.9), "name": "Necromancer", "role": "caster", "color": Color(0.4, 0.85, 0.65),
			"description": "Morte, de foice. Ergue mortos-vivos (esqueletos, cães, lich, rei), amaldiçoa e canaliza sombras, ou vira fantasma e demônio.",
			"weapon_types": _s(["scythe"]), "offhand_types": _s([]),
			"base_hp": 95.0, "base_mp": 95.0, "hp_per_level": 9.0, "mp_per_level": 10.0, "move_speed": 5.2,
			"basic_attack_power": 0.95, "basic_attack_cooldown": 0.7, "basic_attack_range": 7.5, "basic_attack_is_ranged": true, "basic_attack_kind": 1,
			"starting_equipment": _s(["scythe_bone"] + ItemsCatalog.starter_ids("necromancer")),
			"starting_skills": _s(["nec_drain", "nec_bone_spear"]),
			"builds": [
				# focos, não caminhos fechados: todos de foice, dá para misturar
				_b("invocador", "Invocador", "caster", ["scythe"], [], "cloth", "INT", "WILL", "matk_pct",
					["nec_raise", "nec_bone_spear", "nec_bone_hound", "nec_dark_pact", "nec_drain", "nec_lich", "nec_curse_weakness", "nec_corpse_explosion",
					 "nec_bone_wall", "nec_army", "nec_skeleton_king"]).merged({
					"passives": [{"matk_pct": 3}, {"pet_pct": 5}], "set_extra": {3: {"pet_pct": [10.0, 3.0]}}}),
				_b("ceifador", "Ceifador", "dps", ["scythe"], [], "leather", "INT", "VIT", "matk_pct",
					["nec_reap", "nec_phantom", "nec_drain", "nec_soul_rend", "nec_death_spin", "nec_bone_armor", "nec_harvest", "nec_demon_form", "nec_bone_wall", "nec_grim"]).merged({
					"passives": [{"matk_pct": 3}, {"lifesteal": 1}, {"hp_pct": 3}], "set_extra": {3: {"lifesteal": [2.0, 0.5]}}}),
				_b("pestilento", "Sombras", "caster", ["scythe"], [], "cloth", "INT", "WILL", "matk_pct",
					["nec_rot", "nec_mind_flay", "nec_plague", "nec_curse_weakness", "nec_swarm", "nec_drain_soul", "nec_curse", "nec_decay", "nec_curse_doom",
					 "nec_void_beam", "nec_pandemic", "nec_curse_agony"]).merged({
					"passives": [{"matk_pct": 3}, {"mp_pct": 4}]}),
			]}),
	]
