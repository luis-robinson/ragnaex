class_name ClassesCatalog
extends RefCounted
## As 8 classes. Atributos vêm do equipamento (ver items_catalog / gear_catalog).
## Cada classe tem 2-3 builds (arma + skills + conjunto lendário). skill_ids é preenchido pelo
## GameData com todas as skills da classe (skills_catalog); starting_skills são as 2 de nível 1.

static func _mk(d: Dictionary) -> ClassDef:
	var c := ClassDef.new()
	CatalogUtil.fill(c, d)
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
## Cada build também diz `of` ("do X" das peças), `signature` (magia que dispara de graça ao acertar com o básico ou
## skills, LegendEffects.signature_on_hit; `look` = tema visual do básico), `legend` (efeito da arma lendária: kind/name/skill;
## números em Balance.LEGEND_NUMBERS) e, no Elementalista, `element`. Números por build: Balance.BUILD_POWER,
## SIGNATURE_BUILD_POWER e LEGEND_NUMBERS (há check de que toda build está em todas).

static func _b(id: String, name: String, role: String, main: Array, off: Array, armor: String, attr: String, attr2: String, stat: String, skills: Array) -> Dictionary:
	var d := {"id": id, "name": name, "role": role, "main": main, "off": off, "armor": armor,
		"attr": attr, "attr2": attr2, "stat": stat, "skills": skills}
	if Balance.BUILD_PASSIVES.has(id):           # números da build ficam em Balance (passivos da teia e bônus extra do conjunto)
		d["passives"] = Balance.BUILD_PASSIVES[id]
	if Balance.BUILD_SET_EXTRA.has(id):
		d["set_extra"] = Balance.BUILD_SET_EXTRA[id]
	return d

static func build() -> Array:
	return [
		_mk({"id": "paladin", "shield_charge": "oath", "body_type": "male", "hair_color": Color(0.85, 0.65, 0.3), "name": "Paladino", "role": "tank", "color": Color(0.95, 0.85, 0.45),
			"description": "Guerreiro sagrado. Tanque de escudo, cruzado de arma de duas mãos ou templário de espada e escudo que queima com fogo sagrado.",
			"weapon_types": _s(["sword", "mace", "sword2h", "mace2h"]), "offhand_types": _s(["shield"]),
			"base_hp": 140.0, "base_mp": 45.0, "hp_per_level": 16.0, "mp_per_level": 5.0, "move_speed": 5.2,
			"basic_attack_power": 1.0, "basic_attack_cooldown": 0.7, "basic_attack_range": 1.9,
			"starting_equipment": _s(["sword_rusty", "shield_wood"] + ItemsCatalog.starter_ids("paladin")),
			"starting_skills": _s(["pal_holy_strike", "pal_blessed_armor"]),
			"builds": [
				_b("guardiao", "Guardião", "tank", ["sword", "mace"], ["shield"], "plate", "VIT", "FOR", "def_pct",
					# os 6 primeiros que o nível libera vão na barra do bot: ricochete, aura e provocar sempre entram
					["pal_holy_strike", "pal_shield_throw", "pal_bastion_aura", "pal_taunt", "pal_lay_hands", "pal_retribution",
					 "pal_shield_wall", "pal_aegis_slam", "pal_shield_bash", "pal_divine_shield", "pal_blessed_armor"]).merged({
					"of": "do Guardião", "signature": {"skill": "pal_holy_strike", "look": "holy"}, "legend": {"kind": "thorns", "name": "Retaliação"}}),
				_b("cruzado", "Cruzado", "dps", ["sword2h", "mace2h"], [], "plate", "FOR", "WILL", "atk_pct",
					["pal_holy_strike", "pal_crusader_strike", "pal_twin_slash", "pal_consecrate", "pal_lunge", "pal_hammer_light", "pal_blade_dance",
					 "pal_holy_wave", "pal_flurry", "pal_zeal", "pal_valor", "pal_judgement_blade", "pal_purge"]).merged({
					"of": "do Cruzado", "signature": {"skill": "pal_holy_wave", "look": "holy"}, "legend": {"kind": "stun", "name": "Julgamento"}}),
				# Templário: espada (ou maça) e escudo como o Guardião, mas para causar dano: golpes de fogo sagrado que marcam
				# e queimam (FOR no golpe, INT na queimadura); as skills de escudo do Guardião e a Retribuição entram na mistura
				_b("templario", "Templário", "dps", ["sword", "mace"], ["shield"], "plate", "FOR", "INT", "atk_pct",
					["pal_sacred_flame", "pal_holy_strike", "pal_brand", "pal_cleansing_fire", "pal_sun_strike", "pal_shield_bash", "pal_flame_pyre", "pal_avenging_wrath",
					 "pal_aegis_slam", "pal_retribution", "pal_blessed_armor", "pal_lay_hands", "pal_purge"]).merged({
					"of": "do Templário", "signature": {"skill": "pal_sacred_flame", "look": "holy"}, "legend": {"kind": "penance", "name": "Penitência"}}),
			]}),
		_mk({"id": "berserker", "body_type": "male", "hair_color": Color(0.55, 0.2, 0.12), "name": "Berserker", "role": "dps", "color": Color(0.85, 0.3, 0.25),
			"description": "Fúria pura. Dois machados velozes que bebem o sangue do inimigo, um machado de duas mãos que aguenta o tranco e executa, ou duas garras de monge da fúria: esquiva tudo e devolve cada golpe.",
			"weapon_types": _s(["axe2h", "axe", "claw"]), "offhand_types": _s(["axe", "claw"]),
			"base_hp": 125.0, "base_mp": 40.0, "hp_per_level": 14.0, "mp_per_level": 4.0, "move_speed": 5.4,
			"basic_attack_power": 1.25, "basic_attack_cooldown": 0.85, "basic_attack_range": 2.2,
			"starting_equipment": _s(["axe_old"] + ItemsCatalog.starter_ids("berserker")),
			"starting_skills": _s(["ber_cleave", "ber_bloodlust"]),
			"builds": [
				_b("carniceiro", "Machados Gêmeos", "dps", ["axe"], ["axe"], "leather", "FOR", "AGI", "aspd_pct",
					["ber_hack", "ber_twin_fang", "ber_cleave", "ber_rend", "ber_blade_rush", "ber_axe_storm", "ber_steel_whirl", "ber_throw_axe",
					 "ber_crimson_flurry", "ber_fury", "ber_butcher", "ber_bladestorm", "ber_leap"]).merged({
					"of": "das Armas Gêmeas", "signature": {"skill": "ber_throw_axe", "look": "blood"}, "legend": {"kind": "frenzy", "name": "Frenesi"}}),
				_b("executor", "Executor", "dps", ["axe2h"], [], "plate", "FOR", "VIT", "atk_pct",
					["ber_cleave", "ber_overhead", "ber_bloodlust", "ber_whirlwind", "ber_earthsplitter", "ber_execute", "ber_titan_grip", "ber_warcry", "ber_decapitate"]).merged({
					"of": "do Executor", "signature": {"skill": "ber_overhead", "look": "blood"}, "legend": {"kind": "execute", "name": "Carrasco"}}),
				# monge da fúria: duas garras, muita AGI e esquiva; esquivar dá Fúria do Punho e contra-ataca (FistSystem)
				_b("punhos", "Punhos de Fúria", "dps", ["claw"], ["claw"], "leather", "AGI", "FOR", "aspd_pct",
					["ber_final_fist", "ber_hundred_fists", "ber_tiger_pounce", "ber_fist_flurry", "ber_shockwave", "ber_earth_slash", "ber_counter_stance",
					 "ber_chakra", "ber_rend", "ber_blade_rush", "ber_fury", "ber_bloodlust", "ber_leap", "ber_warcry", "ber_cleave"]).merged({
					"of": "dos Punhos de Fúria", "signature": {"skill": "ber_shockwave", "look": "blood"}, "legend": {"kind": "fist_counter", "name": "Punho Vingativo"}}),
			]}),
		_mk({"id": "bishop", "shield_charge": "grace", "boss_priority": true, "body_type": "female", "hair_color": Color(0.95, 0.85, 0.55), "name": "Bispo", "role": "healer", "color": Color(0.95, 0.95, 0.9),
			"description": "Fé. Sacerdote de maça e escudo que cura e fortalece o grupo, Iluminado de cetro que fere com luz e cura com o próprio golpe, ou Clérigo de Batalha de placa que luta na linha de frente e cura o grupo a cada golpe.",
			"weapon_types": _s(["scepter", "mace"]), "offhand_types": _s(["shield"]),
			"base_hp": 90.0, "base_mp": 90.0, "hp_per_level": 9.0, "mp_per_level": 10.0, "move_speed": 5.3,
			"basic_attack_power": 0.9, "basic_attack_cooldown": 0.75, "basic_attack_range": 7.0, "basic_attack_is_ranged": true, "basic_attack_kind": 1,
			"starting_equipment": _s(["scepter_t0"] + ItemsCatalog.starter_ids("bishop")),
			"starting_skills": _s(["bis_heal", "bis_light"]),
			"builds": [
				_b("sacerdote", "Sacerdote", "healer", ["mace"], ["shield"], "cloth", "WILL", "VIT", "heal_pct",
					["bis_heal", "bis_light", "bis_holy_nova", "bis_renew", "bis_prayer", "bis_blessing", "bis_sanctuary", "bis_ward", "bis_mend", "bis_angel", "bis_martyr", "bis_miracle"]).merged({
					"of": "do Sacerdote", "signature": {"skill": "bis_light", "look": "holy"}, "legend": {"kind": "ward", "name": "Égide"}}),
				_b("inquisidor", "Iluminado", "dps", ["scepter"], [], "cloth", "INT", "WILL", "matk_pct",
					["bis_light", "bis_smite", "bis_holy_nova", "bis_hammer", "bis_condemn", "bis_exorcism", "bis_zealot", "bis_purify", "bis_crusade", "bis_judgement", "bis_wrath"]).merged({
					"of": "do Inquisidor", "signature": {"skill": "bis_hammer", "look": "holy"}, "legend": {"kind": "cast_on_basic", "name": "Castigo Sagrado", "skill": "bis_smite"}}),
				# Clérigo de Batalha: maça e escudo como o Sacerdote, mas de placa e na linha de frente: golpes físicos que curam
				# o aliado mais ferido (mend_pct_of_dmg), bênçãos do Sacerdote como apoio
				_b("batalha", "Clérigo de Batalha", "dps", ["mace"], ["shield"], "plate", "FOR", "WILL", "atk_pct",
					["bis_holy_blow", "bis_shield_smite", "bis_holy_quake", "bis_battle_hymn", "bis_faith_leap", "bis_divine_hammer", "bis_heal", "bis_blessing", "bis_ward", "bis_renew",
					 "bis_holy_nova", "bis_martyr", "bis_prayer", "bis_light"]).merged({
					"of": "do Clérigo de Batalha", "signature": {"skill": "bis_holy_nova", "look": "holy"}, "legend": {"kind": "mend", "name": "Mão que Cura"}}),
			]}),
		_mk({"id": "druid", "body_type": "female", "hair_color": Color(0.4, 0.28, 0.16), "name": "Druida", "role": "caster", "color": Color(0.45, 0.8, 0.35),
			"description": "Natureza. Xamã de cajado que invoca e abençoa, lobo veloz que some nas sombras (duas maças) ou urso que segura a linha (malho).",
			"weapon_types": _s(["staff", "mace", "mace2h"]), "offhand_types": _s(["mace"]),
			"base_hp": 110.0, "base_mp": 75.0, "hp_per_level": 12.5, "mp_per_level": 8.0, "move_speed": 5.5,
			"basic_attack_power": 0.9, "basic_attack_cooldown": 0.7, "basic_attack_range": 6.5, "basic_attack_is_ranged": true, "basic_attack_kind": 1,
			"starting_equipment": _s(["staff_oak"] + ItemsCatalog.starter_ids("druid")),
			"starting_skills": _s(["dru_thorns", "dru_bark"]),
			"starting_bag": _s(["mace_t0", "mace_t0", "mace2h_t0"]),     # Fera (duas maças: lobo) e Guardião (martelo: urso) desde o início
			"builds": [
				_b("guardiao_verde", "Urso", "tank", ["mace2h"], [], "plate", "VIT", "WILL", "def_pct",
					["dru_bear_form", "dru_maul", "dru_bellow", "dru_thorns", "dru_earth_slam", "dru_bark", "dru_oak_skin", "dru_stampede", "dru_regrowth", "dru_mountain"]).merged({
					"of": "do Guardião da Floresta", "signature": {"skill": "dru_moonfire", "look": "nature"}, "legend": {"kind": "cast_when_hit", "name": "Casca Viva", "skill": "dru_oak_skin"}}),
				_b("fera", "Lobo", "dps", ["mace"], ["mace"], "leather", "FOR", "AGI", "atk_pct",
					["dru_wolf_form", "dru_claw", "dru_prowl", "dru_maim", "dru_thorns", "dru_pounce", "dru_frenzy", "dru_rampage", "dru_regrowth", "dru_savage", "dru_entangle"]).merged({
					"of": "da Fera Selvagem", "signature": {"skill": "dru_claw", "look": "nature"}, "legend": {"kind": "bleed", "name": "Sangue da Matilha"}}),
				_b("xama", "Xamã", "caster", ["staff"], [], "cloth", "INT", "WILL", "matk_pct",
					["dru_thorns", "dru_moonfire", "dru_grove", "dru_entangle", "dru_spirit_wolves", "dru_swarm", "dru_starfall", "dru_cyclone", "dru_treant", "dru_wild_growth", "dru_regrowth", "dru_storm"]).merged({
					"of": "do Xamã", "boss_priority": true, "signature": {"skill": "dru_moonfire", "look": "lunar"}, "legend": {"kind": "cast_on_basic", "name": "Lua Cheia", "skill": "dru_moonfire"}}),
			]}),
		_mk({"id": "ranger", "body_type": "female", "hair_color": Color(0.75, 0.4, 0.2), "name": "Ranger", "role": "ranged", "color": Color(0.5, 0.75, 0.55),
			"description": "Caçador de arco com um lince companheiro, atirador de mosquete que espalha armadilhas pelo chão, ou lanceiro que caça de perto: estoca, salta na presa, lança dardos e armadilhas e a faz sangrar.",
			"weapon_types": _s(["bow", "rifle", "spear"]), "offhand_types": _s([]),
			"base_hp": 110.0, "base_mp": 55.0, "hp_per_level": 11.5, "mp_per_level": 6.0, "move_speed": 5.8,
			"basic_attack_power": 1.0, "basic_attack_cooldown": 0.55, "basic_attack_range": 13.0, "basic_attack_is_ranged": true,
			"starting_equipment": _s(["bow_short"] + ItemsCatalog.starter_ids("ranger")),
			"starting_skills": _s(["ran_power_shot", "ran_disengage"]),
			"builds": [
				_b("cacador", "Caçador", "ranged", ["bow"], [], "leather", "AGI", "VIT", "atk_pct",
					["ran_power_shot", "ran_companion", "ran_multishot", "ran_anchor", "ran_frost_arrow", "ran_sic", "ran_explosive", "ran_piercing", "ran_net",
					 "ran_pack", "ran_rain", "ran_volley", "ran_barrage", "ran_disengage"]).merged({
					"of": "do Caçador", "signature": {"skill": "ran_frost_arrow", "look": "ice"}, "legend": {"kind": "mark", "name": "Marca do Caçador"}}),
				_b("atirador", "Atirador", "ranged", ["rifle"], [], "leather", "AGI", "FOR", "atk_pct",
					["ran_power_shot", "ran_trap", "ran_anchor", "ran_scatter", "ran_snipe", "ran_mine", "ran_frost_trap", "ran_mark", "ran_headshot", "ran_deadeye", "ran_disengage"]).merged({
					"of": "do Atirador", "signature": {"skill": "ran_snipe", "look": "fire"}, "legend": {"kind": "splash", "name": "Pólvora"}}),
				# caçador de perto com a lança: estocadas longas, salto na presa, dardos e armadilhas de mão; a presa sangra
				_b("lanceiro", "Lanceiro", "dps", ["spear"], [], "leather", "AGI", "FOR", "atk_pct",
					["ran_double_thrust", "ran_javelin", "ran_spear_leap", "ran_spear_sweep", "ran_snare_toss", "ran_predator", "ran_blood_instinct",
					 "ran_impale", "ran_mark", "ran_trap", "ran_disengage"]).merged({
					"of": "do Lanceiro", "signature": {"skill": "ran_javelin", "look": "blood"}, "legend": {"kind": "open_wound", "name": "Ferida Aberta"}}),
			]}),
		_mk({"id": "assassin", "body_type": "male", "hair_color": Color(0.2, 0.18, 0.25), "name": "Assassino", "role": "dps", "color": Color(0.55, 0.35, 0.75),
			"description": "Sombras. Duas adagas velozes com veneno, esquiva e golpes pelas costas saindo da furtividade, duelista equilibrado de duas espadas, ou corsário de sabre e pistola que junta Bravata com tiros e a gasta num tiro entre os olhos.",
			"weapon_types": _s(["dagger", "sword"]), "offhand_types": _s(["dagger", "sword", "pistol"]),
			"base_hp": 100.0, "base_mp": 60.0, "hp_per_level": 11.0, "mp_per_level": 6.0, "move_speed": 6.2,
			"basic_attack_power": 0.75, "basic_attack_cooldown": 0.38, "basic_attack_range": 1.7,
			"starting_equipment": _s(["dagger_iron"] + ItemsCatalog.starter_ids("assassin")),
			"starting_skills": _s(["ass_backstab", "ass_quick_stab"]),
			"builds": [
				_b("laminas", "Lâminas", "dps", ["dagger"], ["dagger"], "leather", "AGI", "FOR", "aspd_pct",
					["ass_twin_strike", "ass_backstab", "ass_plague_blade", "ass_reflexes", "ass_shadowstep", "ass_vanish", "ass_quick_stab", "ass_poison", "ass_blade_flurry", "ass_venom_dart",
					 "ass_fan", "ass_eviscerate", "ass_paralyze", "ass_toxic_cloud", "ass_dance", "ass_execute", "ass_virulence", "ass_thousand"]).merged({
					"of": "das Lâminas Gêmeas", "signature": {"skill": "ass_venom_dart", "look": "poison"}, "legend": {"kind": "poison", "name": "Veneno Letal"}}),
				_b("duelista", "Duelista", "dps", ["sword"], ["sword"], "leather", "AGI", "FOR", "atk_pct",
					["ass_cross_slash", "ass_backstab", "ass_quick_stab", "ass_thrust", "ass_shadowstep", "ass_guard", "ass_lunge", "ass_steel_whirl", "ass_crimson",
					 "ass_execute", "ass_focus", "ass_master", "ass_expose"]).merged({
					"of": "do Duelista", "signature": {"skill": "ass_thrust", "look": "blood"}, "legend": {"kind": "riposte", "name": "Riposte"}}),
				# Corsário: sabre (espada) na direita e pistola de pederneira na esquerda. Tiros e cortes juntam Bravata
				# (até 5 cargas); o Tiro Entre os Olhos gasta tudo num tiro que atordoa. Dados da Sorte, gancho e a bandeira do capitão.
				_b("corsario", "Corsário", "dps", ["sword"], ["pistol"], "leather", "AGI", "FOR", "atk_pct",
					["ass_pistol_shot", "ass_slash_shot", "ass_between_eyes", "ass_dice", "ass_backstab", "ass_ricochet_shot", "ass_grapple",
					 "ass_black_flag", "ass_broadside", "ass_quick_stab", "ass_thrust", "ass_guard", "ass_expose", "ass_shadowstep", "ass_execute", "ass_smoke"]).merged({
					"of": "do Corsário", "signature": {"skill": "ass_pistol_shot", "look": "fire"}, "legend": {"kind": "spare_shot", "name": "Bala na Agulha"}}),
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
					"of": "do Fogo", "signature": {"skill": "ele_fireball", "look": "fire"}, "legend": {"kind": "cast_on_basic", "name": "Brasa Viva", "skill": "ele_fireball"}, "element": ["fire"]}),
				_b("gelo", "Gelo", "caster", ["staff"], [], "cloth", "INT", "VIT", "matk_pct",
					["ele_ice_lance", "ele_frost_nova", "ele_fireball", "ele_frost_armor", "ele_glacier", "ele_summon_ice", "ele_frost_flare", "ele_shatter",
					 "ele_hailstorm", "ele_blizzard", "ele_blink", "ele_absolute_zero", "ele_prism"]).merged({
					"of": "do Gelo", "signature": {"skill": "ele_ice_lance", "look": "ice"}, "legend": {"kind": "cast_when_hit", "name": "Coração de Gelo", "skill": "ele_frost_nova"}, "element": ["frost"]}),
				_b("raio", "Raio", "caster", ["staff"], [], "cloth", "INT", "WILL", "matk_pct",
					["ele_spark", "ele_lightning", "ele_chain", "ele_static", "ele_firestorm", "ele_summon_storm", "ele_overload", "ele_hailstorm",
					 "ele_thunder", "ele_blink", "ele_storm_lord", "ele_prism"]).merged({
					"of": "do Raio", "signature": {"skill": "ele_chain", "look": "lightning"}, "legend": {"kind": "chain", "name": "Arco Voltaico"}, "element": ["storm"]}),
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
					"of": "do Invocador", "signature": {"skill": "nec_bone_spear", "look": "bone"}, "legend": {"kind": "raise_on_kill", "name": "Legião"}}),
				_b("ceifador", "Ceifador", "dps", ["scythe"], [], "leather", "INT", "VIT", "matk_pct",
					["nec_reap", "nec_phantom", "nec_drain", "nec_soul_rend", "nec_death_spin", "nec_bone_armor", "nec_harvest", "nec_demon_form", "nec_bone_wall", "nec_grim"]).merged({
					"of": "do Ceifador", "signature": {"skill": "nec_soul_rend", "look": "shadow"}, "legend": {"kind": "heal_on_kill", "name": "Ceifa"}}),
				_b("pestilento", "Sombras", "caster", ["scythe"], [], "cloth", "INT", "WILL", "matk_pct",
					["nec_rot", "nec_drain", "nec_mind_flay", "nec_plague", "nec_curse_weakness", "nec_swarm", "nec_drain_soul", "nec_curse", "nec_decay", "nec_curse_doom",
					 "nec_void_beam", "nec_pandemic", "nec_curse_agony"]).merged({
					"of": "das Sombras", "signature": {"skill": "nec_mind_flay", "look": "shadow"}, "legend": {"kind": "cast_on_basic", "name": "Praga", "skill": "nec_curse_agony"}}),
			]}),
	]
