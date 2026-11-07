class_name SkillsCatalog
extends RefCounted
## 8 classes × 20+ skills (o jogador aprende com pontos e equipa 6). Cada skill tem nível mínimo,
## build ("" = geral) e arma exigida (requires). As 6 originais de cada classe estão em `_all()` e recebem
## nível/build/arma por META; as demais vêm de `_more()` via construtores compactos.
## target: 0 SELF, 1 DIRECTION, 2 GROUND, 3 CONE, 4 TARGET · kind: 0 PHYS, 1 MAG, 2 HEAL, 3 BUFF, 4 SUMMON, 5 MOVE

const T_SELF := 0; const T_DIR := 1; const T_GROUND := 2; const T_CONE := 3; const T_TARGET := 4
const K_PHYS := 0; const K_MAG := 1; const K_HEAL := 2; const K_BUFF := 3; const K_SUMMON := 4; const K_MOVE := 5

## skills originais: id -> [nível, build, requires]
const META := {
	"pal_holy_strike": [1, "", []], "pal_shield_bash": [3, "guardiao", ["shield"]], "pal_consecrate": [6, "cruzado", ["two_handed"]],
	"pal_lay_hands": [10, "", []], "pal_taunt": [8, "guardiao", ["shield"]], "pal_divine_shield": [20, "guardiao", ["shield"]],
	"ber_cleave": [1, "", []], "ber_leap": [3, "", []], "ber_whirlwind": [6, "executor", ["two_handed"]],
	"ber_fury": [10, "", []], "ber_execute": [15, "executor", ["two_handed"]], "ber_warcry": [20, "", []],
	"bis_heal": [1, "", []], "bis_smite": [3, "inquisidor", []], "bis_blessing": [6, "sacerdote", ["mace", "shield"]],
	"bis_sanctuary": [10, "sacerdote", ["mace", "shield"]], "bis_purify": [15, "inquisidor", ["scepter"]], "bis_judgement": [20, "inquisidor", ["scepter"]],
	"dru_thorns": [1, "", []], "dru_entangle": [3, "", []], "dru_regrowth": [6, "", []],
	"dru_swarm": [10, "xama", ["staff"]], "dru_bear_form": [3, "guardiao_verde", ["mace2h"]], "dru_wild_growth": [20, "xama", ["staff"]],
	"ran_power_shot": [1, "", ["bow", "rifle"]], "ran_multishot": [3, "cacador", ["bow"]], "ran_disengage": [1, "", []],
	"ran_trap": [3, "atirador", ["rifle"]], "ran_mark": [15, "atirador", ["rifle"]], "ran_rain": [20, "cacador", ["bow"]],
	"ass_backstab": [1, "", ["dagger", "sword"]], "ass_shadowstep": [3, "", []], "ass_poison": [6, "laminas", ["dual_dagger"]],
	"ass_fan": [10, "laminas", []], "ass_smoke": [15, "", []], "ass_execute": [20, "", []],
	"ele_fireball": [1, "", []], "ele_frost_nova": [3, "gelo", ["staff"]], "ele_lightning": [6, "raio", ["staff"]],
	"ele_meteor": [10, "fogo", ["staff"]], "ele_blink": [15, "", []], "ele_blizzard": [20, "gelo", ["staff"]],
	"nec_drain": [1, "", []], "nec_raise": [3, "invocador", ["scythe"]], "nec_plague": [6, "pestilento", ["scythe"]],
	"nec_bone_wall": [10, "", []], "nec_curse": [15, "pestilento", ["scythe"]], "nec_harvest": [20, "ceifador", ["scythe"]],
}

static func _mk(d: Dictionary) -> SkillDef:
	var s := SkillDef.new()
	for k in d:
		s.set(k, d[k])
	return s

## maestria padrão: +12% poder, -4% MP, -5% CD por nível; `extras` opcional por nível (índice 1..5)
static func _mastery(extras: Dictionary = {}) -> Array:
	var arr := []
	for lv in range(6):
		arr.append({"power_mult": 1.0 + 0.12 * lv, "mp_mult": 1.0 - 0.04 * lv, "cd_mult": 1.0 - 0.05 * lv, "extra": extras.get(lv, {})})
	return arr

static func build() -> Array:
	var out: Array = []
	var defs := _all()
	for cls_id in defs:
		for d in defs[cls_id]:
			var meta: Array = META[d["id"]]
			d["unlock_level"] = meta[0]
			d["build"] = meta[1]
			d["requires"] = _req(meta[2])
			out.append(_finish(d, cls_id))
	var more := _more()
	for cls_id in more:
		for d in more[cls_id]:
			out.append(_finish(d, cls_id))
	# skills de monstros/bosses
	for d in [
		{"id": "mob_charge", "name": "Investida", "target": T_DIR, "kind": K_PHYS, "power": 1.8, "cooldown": 7.0, "range": 7.0, "radius": 1.0, "startup": 0.6, "active": 0.1, "recovery": 0.6, "hit_stop_frames": 4, "icon_color": Color(1, 0.6, 0.3),
		 "effects": {"dash": 6.0, "stun": {"duration": 0.8}}},
		{"id": "mob_whirl", "name": "Giro Mortal", "target": T_SELF, "kind": K_PHYS, "power": 1.6, "cooldown": 8.0, "radius": 3.2, "startup": 0.7, "active": 0.2, "recovery": 0.5, "hit_stop_frames": 4, "icon_color": Color(1, 0.4, 0.3)},
		{"id": "mob_firebreath", "name": "Bafo de Fogo", "target": T_CONE, "kind": K_MAG, "power": 1.5, "cooldown": 6.0, "radius": 6.5, "cone_angle_deg": 70, "startup": 0.8, "active": 0.2, "recovery": 0.6, "hit_stop_frames": 4, "icon_color": Color(1, 0.3, 0.1),
		 "effects": {"dot": {"dps": 8, "duration": 4}}},
		# Catacumbas do Conde
		{"id": "mob_wail", "name": "Lamento", "target": T_CONE, "kind": K_MAG, "power": 1.3, "cooldown": 7.0, "radius": 7.0, "cone_angle_deg": 80, "startup": 0.8, "active": 0.2, "recovery": 0.5, "hit_stop_frames": 3, "icon_color": Color(0.6, 0.8, 1),
		 "effects": {"slow": {"pct": 40, "duration": 3}}},
		{"id": "mob_grave_touch", "name": "Toque da Cova", "target": T_TARGET, "kind": K_MAG, "power": 1.0, "cooldown": 9.0, "range": 8.0, "radius": 0.0, "max_targets": 1, "startup": 0.5, "active": 0.1, "recovery": 0.4, "icon_color": Color(0.5, 0.75, 0.5),
		 "effects": {"dot": {"dps": 5, "duration": 6}, "wither": {"pct": 50, "duration": 6}}},
		{"id": "mob_soul_drain", "name": "Dreno de Almas", "target": T_TARGET, "kind": K_MAG, "power": 1.4, "cooldown": 8.0, "range": 8.0, "radius": 0.0, "max_targets": 1, "startup": 0.6, "active": 0.1, "recovery": 0.4, "icon_color": Color(0.7, 0.3, 0.9),
		 "effects": {"heal_pct_of_dmg": 1.5}},
		{"id": "mob_raise_dead", "name": "Erguer os Mortos", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 20.0, "radius": 9.0, "startup": 1.0, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.8, 0.9, 0.75),
		 "effects": {"boss_summon": {"id": "bone_servant", "count": 2, "max": 4}}},
		{"id": "mob_death_wave", "name": "Onda de Morte", "target": T_SELF, "kind": K_MAG, "power": 1.5, "cooldown": 12.0, "radius": 6.0, "startup": 1.2, "active": 0.2, "recovery": 0.6, "hit_stop_frames": 5, "icon_color": Color(0.55, 0.2, 0.7),
		 "effects": {"wither": {"pct": 40, "duration": 5}}},
		# chefes das dungeons antigas
		{"id": "mob_frost_shard", "name": "Estilhaço de Gelo", "target": T_TARGET, "kind": K_MAG, "power": 1.2, "cooldown": 5.0, "range": 8.0, "radius": 0.0, "max_targets": 1, "startup": 0.4, "active": 0.1, "recovery": 0.4, "icon_color": Color(0.6, 0.9, 1),
		 "effects": {"slow": {"pct": 40, "duration": 2}}},
		{"id": "mob_static_bolt", "name": "Descarga", "target": T_TARGET, "kind": K_MAG, "power": 1.3, "cooldown": 7.0, "range": 8.0, "radius": 1.6, "max_targets": 3, "startup": 0.4, "active": 0.1, "recovery": 0.4, "icon_color": Color(0.85, 0.85, 1),
		 "effects": {"stun": {"duration": 0.5}}},
		{"id": "mob_frost_ring", "name": "Anel Gélido", "target": T_SELF, "kind": K_MAG, "power": 1.0, "cooldown": 9.0, "radius": 3.2, "startup": 0.5, "active": 0.1, "recovery": 0.4, "icon_color": Color(0.6, 0.9, 1),
		 "effects": {"root": {"duration": 1.0}, "slow": {"pct": 50, "duration": 2}}},
		{"id": "mob_acid_spit", "name": "Cuspe Ácido", "target": T_TARGET, "kind": K_MAG, "power": 1.1, "cooldown": 8.0, "range": 8.0, "radius": 0.0, "max_targets": 1, "startup": 0.5, "active": 0.1, "recovery": 0.4, "icon_color": Color(0.4, 0.85, 0.5),
		 "effects": {"slow": {"pct": 45, "duration": 3}, "dot": {"dps": 4, "duration": 4}}},
		# Cerco élfico (Floresta Sombria / Cidade Élfica)
		{"id": "mob_elf_lunge", "name": "Estocada Élfica", "target": T_DIR, "kind": K_PHYS, "power": 1.4, "cooldown": 7.0, "range": 5.0, "radius": 1.0, "startup": 0.45, "active": 0.1, "recovery": 0.5, "hit_stop_frames": 3, "icon_color": Color(0.55, 0.9, 0.5),
		 "effects": {"dash": 4.5}},
		{"id": "mob_root_arrow", "name": "Flecha Enraizante", "target": T_TARGET, "kind": K_PHYS, "power": 1.1, "cooldown": 8.0, "range": 9.0, "radius": 0.0, "max_targets": 1, "startup": 0.5, "active": 0.1, "recovery": 0.4, "icon_color": Color(0.45, 0.8, 0.35),
		 "effects": {"root": {"duration": 1.0}}},
		{"id": "mob_pounce", "name": "Bote", "target": T_DIR, "kind": K_PHYS, "power": 1.3, "cooldown": 6.0, "range": 4.5, "radius": 1.0, "startup": 0.35, "active": 0.1, "recovery": 0.45, "hit_stop_frames": 3, "icon_color": Color(0.85, 0.7, 0.4),
		 "effects": {"dash": 4.0, "slow": {"pct": 30, "duration": 2}}},
		{"id": "mob_dive", "name": "Mergulho do Grifo", "target": T_DIR, "kind": K_PHYS, "power": 1.6, "cooldown": 9.0, "range": 7.0, "radius": 1.8, "startup": 0.6, "active": 0.15, "recovery": 0.6, "hit_stop_frames": 4, "icon_color": Color(0.95, 0.85, 0.55),
		 "effects": {"dash": 6.0, "stun": {"duration": 0.6}}},
		{"id": "mob_root_grasp", "name": "Raízes Famintas", "target": T_SELF, "kind": K_MAG, "power": 0.9, "cooldown": 11.0, "radius": 4.5, "startup": 0.9, "active": 0.2, "recovery": 0.6, "hit_stop_frames": 3, "icon_color": Color(0.4, 0.65, 0.3),
		 "effects": {"root": {"duration": 2.0}}},
		{"id": "mob_volley", "name": "Saraivada", "target": T_CONE, "kind": K_PHYS, "power": 1.2, "cooldown": 9.0, "radius": 8.0, "cone_angle_deg": 50, "startup": 0.6, "active": 0.2, "recovery": 0.5, "hit_stop_frames": 3, "icon_color": Color(0.7, 0.95, 0.6)},
		{"id": "mob_king_roots", "name": "Ira da Árvore-Mãe", "target": T_SELF, "kind": K_MAG, "power": 1.1, "cooldown": 14.0, "radius": 9.0, "startup": 1.2, "active": 0.2, "recovery": 0.6, "hit_stop_frames": 5, "icon_color": Color(0.5, 0.9, 0.4),
		 "effects": {"root": {"duration": 1.6}}},
		{"id": "mob_thorn_lash", "name": "Chicote de Cipó", "target": T_TARGET, "kind": K_PHYS, "power": 0.9, "cooldown": 7.0, "range": 8.0, "radius": 0.0, "max_targets": 1, "startup": 0.55, "active": 0.1, "recovery": 0.45, "hit_stop_frames": 3, "icon_color": Color(0.45, 0.7, 0.3),
		 "effects": {"root": {"duration": 1.2}}},
		# investida élfica: mago, salto do lince
		{"id": "mob_light_beam", "name": "Raio de Luz", "target": T_TARGET, "kind": K_MAG, "power": 1.3, "cooldown": 5.0, "range": 9.0, "radius": 0.0, "max_targets": 1, "startup": 0.5, "active": 0.1, "recovery": 0.4, "hit_stop_frames": 2, "icon_color": Color(0.95, 1.0, 0.75)},
		{"id": "mob_raise_wisps", "name": "Chamar Espíritos", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 18.0, "radius": 12.0, "startup": 0.9, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.5, 1.0, 0.6),
		 "effects": {"boss_summon": {"id": "elf_wisp", "count": 2, "max": 2}}},
		{"id": "mob_lynx_leap", "name": "Salto do Lince", "target": T_DIR, "kind": K_PHYS, "power": 1.4, "cooldown": 9.0, "range": 9.0, "radius": 1.6, "startup": 0.45, "active": 0.15, "recovery": 0.5, "hit_stop_frames": 3, "icon_color": Color(0.9, 0.75, 0.4),
		 "effects": {"dash": 8.0, "slow": {"pct": 40, "duration": 2}}},
		# Pedreira dos Golens
		{"id": "mob_quarry_slam", "name": "Soco da Pedreira", "target": T_CONE, "kind": K_PHYS, "power": 1.6, "cooldown": 7.0, "radius": 4.2, "cone_angle_deg": 80, "startup": 0.6, "active": 0.2, "recovery": 0.6, "hit_stop_frames": 5, "icon_color": Color(0.7, 0.6, 0.45),
		 "effects": {"slow": {"pct": 40, "duration": 2}}},
		{"id": "mob_boulder_toss", "name": "Pedregulho", "target": T_GROUND, "kind": K_PHYS, "power": 1.7, "cooldown": 9.0, "range": 10.0, "radius": 2.2, "startup": 1.0, "active": 0.2, "recovery": 0.5, "hit_stop_frames": 4, "icon_color": Color(0.6, 0.55, 0.45),
		 "effects": {"stun": {"duration": 0.6}}},
		{"id": "mob_rockfall", "name": "Desabamento", "target": T_GROUND, "kind": K_PHYS, "power": 1.6, "cooldown": 12.0, "range": 12.0, "radius": 3.0, "startup": 1.25, "active": 0.25, "recovery": 0.6, "hit_stop_frames": 4, "icon_color": Color(0.55, 0.5, 0.42),
		 "effects": {"slow": {"pct": 35, "duration": 2}}},
		{"id": "mob_magnet_pull", "name": "Veio Magnético", "target": T_SELF, "kind": K_MAG, "power": 0.7, "cooldown": 16.0, "radius": 6.0, "startup": 1.1, "active": 0.2, "recovery": 0.6, "hit_stop_frames": 3, "icon_color": Color(0.85, 0.45, 0.25),
		 "effects": {"root": {"duration": 1.0}}},
		{"id": "mob_shard_fan", "name": "Leque de Lascas", "target": T_CONE, "kind": K_MAG, "power": 1.3, "cooldown": 6.0, "radius": 7.5, "cone_angle_deg": 60, "startup": 0.6, "active": 0.15, "recovery": 0.45, "hit_stop_frames": 3, "icon_color": Color(0.5, 0.78, 1.0)},
		{"id": "mob_crystal_prison", "name": "Prisão de Cristal", "target": T_GROUND, "kind": K_MAG, "power": 1.0, "cooldown": 12.0, "range": 9.0, "radius": 2.0, "startup": 1.0, "active": 0.2, "recovery": 0.5, "hit_stop_frames": 3, "icon_color": Color(0.55, 0.8, 1.0),
		 "effects": {"stun": {"duration": 1.0}}},
		{"id": "mob_crystal_ward", "name": "Escudo de Cristal", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 18.0, "radius": 0.0, "startup": 0.6, "active": 0.1, "recovery": 0.4, "icon_color": Color(0.55, 0.85, 1.0),
		 "effects": {"buff": {"id": "crystal_ward", "duration": 6, "def_pct": 50}}},
		# chefes da faixa 10-20 (Floresta, Ninho, Coração da Árvore, Trono do Conde)
		# linha dos fora-da-lei (Floresta): funda, facada pelas costas, laço e porrete
		{"id": "mob_sling_stone", "name": "Pedrada", "target": T_TARGET, "kind": K_PHYS, "power": 0.9, "cooldown": 6.0, "range": 8.0, "radius": 0.0, "max_targets": 1, "startup": 0.4, "active": 0.1, "recovery": 0.4, "hit_stop_frames": 2, "icon_color": Color(0.7, 0.65, 0.55),
		 "effects": {"slow": {"pct": 35, "duration": 2}}},
		{"id": "mob_ambush_stab", "name": "Facada pelas Costas", "target": T_DIR, "kind": K_PHYS, "power": 1.4, "cooldown": 8.0, "range": 5.0, "radius": 1.0, "startup": 0.35, "active": 0.1, "recovery": 0.5, "hit_stop_frames": 3, "icon_color": Color(0.45, 0.35, 0.5),
		 "effects": {"dash": 4.5, "dot": {"dps": 4, "duration": 3}}},
		{"id": "mob_snare_shot", "name": "Laço do Clandestino", "target": T_TARGET, "kind": K_PHYS, "power": 1.0, "cooldown": 9.0, "range": 9.0, "radius": 0.0, "max_targets": 1, "startup": 0.5, "active": 0.1, "recovery": 0.4, "hit_stop_frames": 2, "icon_color": Color(0.6, 0.5, 0.3),
		 "effects": {"root": {"duration": 1.2}}},
		{"id": "mob_club_slam", "name": "Porretada", "target": T_CONE, "kind": K_PHYS, "power": 1.5, "cooldown": 8.0, "radius": 3.0, "cone_angle_deg": 80, "startup": 0.6, "active": 0.15, "recovery": 0.55, "hit_stop_frames": 4, "icon_color": Color(0.65, 0.45, 0.3),
		 "effects": {"stun": {"duration": 0.6}}},
		# terceiro andar (Luz contra Trevas): mortos-vivos das fortalezas e a guarnição da Aurora
		{"id": "mob_venom_claw", "name": "Garra Pútrida", "target": T_DIR, "kind": K_PHYS, "power": 1.2, "cooldown": 6.0, "range": 2.6, "radius": 1.0, "startup": 0.35, "active": 0.1, "recovery": 0.45, "hit_stop_frames": 3, "icon_color": Color(0.55, 0.8, 0.3),
		 "effects": {"dot": {"dps": 9, "duration": 4}}},
		{"id": "mob_rot_maul", "name": "Patada Podre", "target": T_CONE, "kind": K_PHYS, "power": 1.5, "cooldown": 8.0, "radius": 3.2, "cone_angle_deg": 90, "startup": 0.6, "active": 0.15, "recovery": 0.55, "hit_stop_frames": 4, "icon_color": Color(0.5, 0.65, 0.3),
		 "effects": {"dot": {"dps": 10, "duration": 4}}},
		{"id": "mob_rot_bile", "name": "Vômito de Bile", "target": T_GROUND, "kind": K_MAG, "power": 1.0, "cooldown": 9.0, "range": 10.0, "radius": 3.2, "startup": 0.85, "active": 0.2, "recovery": 0.5, "icon_color": Color(0.55, 0.85, 0.25),
		 "effects": {"dot": {"dps": 10, "duration": 5}, "slow": {"pct": 30, "duration": 3}}},
		{"id": "mob_raise_brood", "name": "Ninhada", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 14.0, "radius": 8.0, "startup": 0.9, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.85, 0.82, 0.6),
		 "effects": {"boss_summon": {"id": "larva_brood", "count": 2, "max": 4}}},
		{"id": "mob_bone_cleave", "name": "Corte de Ossos", "target": T_CONE, "kind": K_PHYS, "power": 1.5, "cooldown": 7.0, "radius": 3.0, "cone_angle_deg": 100, "startup": 0.55, "active": 0.15, "recovery": 0.5, "hit_stop_frames": 4, "icon_color": Color(0.85, 0.85, 0.8)},
		{"id": "mob_blizzard", "name": "Nevasca", "target": T_GROUND, "kind": K_MAG, "power": 1.3, "cooldown": 12.0, "range": 11.0, "radius": 4.0, "startup": 1.1, "active": 0.25, "recovery": 0.6, "hit_stop_frames": 3, "icon_color": Color(0.7, 0.9, 1.0),
		 "effects": {"slow": {"pct": 50, "duration": 3}}},
		{"id": "mob_shadow_bolt", "name": "Raio Sombrio", "target": T_TARGET, "kind": K_MAG, "power": 1.2, "cooldown": 5.0, "range": 9.0, "radius": 0.0, "max_targets": 1, "startup": 0.45, "active": 0.1, "recovery": 0.4, "hit_stop_frames": 2, "icon_color": Color(0.55, 0.3, 0.75)},
		{"id": "mob_spear_lunge", "name": "Estocada de Lança", "target": T_DIR, "kind": K_PHYS, "power": 1.4, "cooldown": 7.0, "range": 4.5, "radius": 1.0, "startup": 0.4, "active": 0.1, "recovery": 0.5, "hit_stop_frames": 3, "icon_color": Color(0.85, 0.85, 0.9),
		 "effects": {"dash": 3.5}},
		{"id": "mob_holy_light", "name": "Luz da Aurora", "target": T_SELF, "kind": K_HEAL, "power": 1.6, "cooldown": 9.0, "radius": 7.0, "startup": 0.6, "active": 0.1, "recovery": 0.4, "icon_color": Color(1.0, 0.92, 0.6)},
		{"id": "mob_venom_knives", "name": "Facas Envenenadas", "target": T_CONE, "kind": K_PHYS, "power": 0.9, "cooldown": 8.0, "radius": 7.0, "cone_angle_deg": 40, "startup": 0.5, "active": 0.15, "recovery": 0.45, "hit_stop_frames": 2, "icon_color": Color(0.5, 0.8, 0.35),
		 "effects": {"dot": {"dps": 8, "duration": 4}}},
		{"id": "mob_smoke_bomb", "name": "Bomba de Fumaça", "target": T_GROUND, "kind": K_MAG, "power": 0.7, "cooldown": 12.0, "range": 9.0, "radius": 3.0, "startup": 0.8, "active": 0.2, "recovery": 0.5, "icon_color": Color(0.55, 0.55, 0.6),
		 "effects": {"slow": {"pct": 50, "duration": 3}}},
		{"id": "mob_venom_pool", "name": "Poça de Veneno", "target": T_GROUND, "kind": K_MAG, "power": 0.8, "cooldown": 9.0, "range": 9.0, "radius": 2.6, "startup": 0.75, "active": 0.2, "recovery": 0.5, "icon_color": Color(0.5, 0.85, 0.3),
		 "effects": {"dot": {"dps": 10, "duration": 5}}},
		{"id": "mob_queen_leap", "name": "Salto da Rainha", "target": T_DIR, "kind": K_PHYS, "power": 1.5, "cooldown": 12.0, "range": 8.0, "radius": 2.2, "startup": 0.65, "active": 0.15, "recovery": 0.6, "hit_stop_frames": 4, "icon_color": Color(0.6, 0.35, 0.7),
		 "effects": {"dash": 7.0, "stun": {"duration": 0.6}}},
		{"id": "mob_crown_blade", "name": "Lâmina da Coroa", "target": T_DIR, "kind": K_PHYS, "power": 1.5, "cooldown": 8.0, "range": 6.0, "radius": 1.2, "startup": 0.5, "active": 0.1, "recovery": 0.5, "hit_stop_frames": 3, "icon_color": Color(0.95, 0.85, 0.45),
		 "effects": {"dash": 5.0, "dot": {"dps": 8, "duration": 4}}},
		{"id": "mob_arrow_rain", "name": "Chuva de Flechas", "target": T_GROUND, "kind": K_PHYS, "power": 1.1, "cooldown": 10.0, "range": 11.0, "radius": 3.5, "startup": 0.95, "active": 0.2, "recovery": 0.5, "hit_stop_frames": 2, "icon_color": Color(0.7, 0.95, 0.6),
		 "effects": {"slow": {"pct": 40, "duration": 2}}},
		{"id": "mob_king_thorn_burst", "name": "Julgamento de Espinhos", "target": T_SELF, "kind": K_MAG, "power": 1.6, "cooldown": 14.0, "radius": 5.0, "startup": 1.3, "active": 0.2, "recovery": 0.6, "hit_stop_frames": 5, "icon_color": Color(0.55, 0.9, 0.4),
		 "effects": {"stun": {"duration": 0.8}}},
		{"id": "mob_blood_mark", "name": "Marca de Sangue", "target": T_TARGET, "kind": K_MAG, "power": 0.8, "cooldown": 11.0, "range": 9.0, "radius": 0.0, "max_targets": 1, "startup": 0.5, "active": 0.1, "recovery": 0.4, "icon_color": Color(0.8, 0.15, 0.25),
		 "effects": {"dot": {"dps": 6, "duration": 6}, "wither": {"pct": 30, "duration": 6}}},
		{"id": "mob_shadow_bats", "name": "Revoada", "target": T_GROUND, "kind": K_MAG, "power": 1.0, "cooldown": 10.0, "range": 9.0, "radius": 3.0, "startup": 0.8, "active": 0.2, "recovery": 0.5, "hit_stop_frames": 2, "icon_color": Color(0.35, 0.25, 0.45),
		 "effects": {"slow": {"pct": 35, "duration": 2}}},
		{"id": "mob_web", "name": "Teia", "target": T_CONE, "kind": K_PHYS, "power": 0.7, "cooldown": 10.0, "radius": 6.0, "cone_angle_deg": 60, "startup": 0.7, "active": 0.2, "recovery": 0.5, "icon_color": Color(0.85, 0.85, 0.9),
		 "effects": {"root": {"duration": 1.5}}},
	]:
		d["mp_cost"] = 0
		d["mastery"] = _mastery()
		out.append(_mk(d))
	for s in out:
		s.vfx = vfx_theme(s)
		if s.class_id == "ranger" and s.target != SkillDef.Target.SELF and (s.requires.has("bow") or s.requires.has("rifle")):
			s.range *= Balance.ARCHER_RANGE_MULT
		if s.class_id == "elementalist":
			s.elements.assign(ELEMENTS.get(s.id, BUILD_ELEMENT.get(s.build, [])))
		if s.effects.has("dot") and (s.vfx == "fire" or s.elements.has("fire")):     # dano no tempo de fogo = queimadura (número laranja)
			var burn: Dictionary = (s.effects["dot"] as Dictionary).duplicate()
			burn["fire"] = true
			s.effects["dot"] = burn
	return out

## Elementos das skills do Elementalista: o ramo dá o elemento; as gerais e as combinações dizem aqui.
const ELEMENTALS := ["fire_elemental", "frost_elemental", "storm_elemental"]     # um por vez (o novo substitui)
const BUILD_ELEMENT := {"fogo": ["fire"], "gelo": ["frost"], "raio": ["storm"]}
const ELEMENTS := {"ele_fireball": ["fire"], "ele_spark": ["storm"], "ele_blink": [],
	"ele_firestorm": ["fire", "storm"], "ele_frost_flare": ["fire", "frost"], "ele_hailstorm": ["frost", "storm"], "ele_prism": ["fire", "frost", "storm"]}

## Tema visual de cada skill (FxManager desenha cor + partículas + forma por tema). Ordem: palavra no id → classe → tipo.
const VFX_THEMES := ["fire", "ice", "lightning", "holy", "lunar", "shadow", "poison", "bone", "nature", "earth", "blood", "wind", "heal", "summon", "physical"]
const VFX_RULES := [
	["summon", ["raise", "golem", "army", "summon"]],
	["lightning", ["prism"]],
	["fire", ["fire", "flame", "combust", "inferno", "phoenix", "meteor", "explosive", "firebreath"]],
	["ice", ["ice", "frost", "glacier", "shatter", "absolute_zero", "blizzard", "hail", "crystal", "shard"]],
	["lightning", ["spark", "chain", "static", "overload", "thunder", "storm_lord", "lightning", "dru_storm"]],
	["wind", ["cyclone", "whirl", "disengage"]],
	["bone", ["bone", "corpse"]],
	["poison", ["toxic", "venom", "paralyze", "plague", "virulence", "poison", "rot", "swarm", "decay", "pandemic", "curse", "smoke"]],
	["shadow", ["shadow", "ambush", "veil", "dark", "soul", "grim", "harvest", "reap", "death", "drain", "assassinate", "ass_execute"]],
	["blood", ["blood", "rend", "hack", "butcher", "crimson", "fury", "rampage", "frenzy", "savage", "eviscerate", "warcry", "titan", "ber_execute", "decapitate"]],
	["earth", ["earth", "mountain", "stampede", "slam", "overhead", "maul", "splitter", "leap", "pounce", "boulder", "rockfall", "magnet"]],
	["lunar", ["moonfire", "starfall"]],
	["holy", ["holy", "light", "bless", "consecrate", "judg", "purge", "purify", "smite", "divine", "nova", "angel", "miracle", "sanct", "wrath", "crusad", "zeal", "valor", "exorc", "condemn", "martyr", "prayer", "ward", "hammer", "radiant", "lay_hands", "retribution"]],
	["nature", ["bark", "oak", "thorn", "entangle", "growth", "regrowth", "dru_"]],
]
const VFX_CLASS := {"bishop": "holy", "paladin": "holy", "necromancer": "shadow", "druid": "nature"}

static func vfx_theme(s: SkillDef) -> String:
	if s.kind == SkillDef.Kind.HEAL:
		return "heal"
	if s.kind == SkillDef.Kind.SUMMON:
		return "summon"
	for rule in VFX_RULES:
		for tok in rule[1]:
			if tok in s.id:
				return rule[0]
	# magia/buff sem palavra-chave: tema da classe; físico: aço
	if s.kind != SkillDef.Kind.PHYSICAL and VFX_CLASS.has(s.class_id):
		return VFX_CLASS[s.class_id]
	return "physical"

static func _req(a: Array) -> Array[String]:
	var out: Array[String] = []
	for x in a:
		out.append(x)
	return out

const KIND_COLORS := [Color(1, 0.7, 0.5), Color(0.6, 0.7, 1), Color(0.7, 1, 0.7), Color(1, 0.9, 0.5), Color(0.7, 0.9, 0.7), Color(0.8, 0.8, 1)]

static func _finish(d: Dictionary, cls_id: String) -> SkillDef:
	d["class_id"] = cls_id
	if not d.has("mastery"):
		d["mastery"] = _mastery()
	if not d.has("icon_color"):
		d["icon_color"] = KIND_COLORS[int(d.get("kind", 0))]
	return _mk(d)

## Construtor compacto: geometria/efeitos/timing extras vão em `ext`.
## Padrões por alvo: TARGET corpo a corpo (alcance 2.6, 1 alvo), SELF sem raio (só você).
## Skills em forma de animal (Druida): id -> forma -> mods no formato dos talentos {"name", "set", "mult", "effects"}.
## WorldSim.resolve_skill aplica quando o druida está transformado.
const FORM_MODS := {
	"nec_reap": {"phantom": {"name": "Ceifa Espectral", "mult": {"startup": 0.6, "radius": 1.15}}, "demon": {"name": "Garra Infernal", "mult": {"radius": 1.3, "power": 1.2}, "set": {"cone_angle_deg": 160.0}}},
	"nec_soul_rend": {"phantom": {"name": "Toque Espectral", "effects": {"slow": {"pct": 50, "duration": 2}}}, "demon": {"name": "Devorar Alma", "mult": {"power": 1.25}, "effects": {"heal_pct_of_dmg": 0.45}}},
	"nec_death_spin": {"phantom": {"name": "Rodopio Fantasma", "mult": {"startup": 0.7}}, "demon": {"name": "Turbilhão Infernal", "mult": {"radius": 1.3, "power": 1.2}}},
	"nec_grim": {"phantom": {"name": "Sentença Fantasma", "mult": {"range": 1.5}, "effects": {"dash": 3.0}}, "demon": {"name": "Execução Demoníaca", "mult": {"power": 1.3}}},
	"dru_maul": {"bear": {"name": "Patada do Urso", "mult": {"radius": 1.3, "power": 1.15}, "set": {"cone_angle_deg": 140.0}}},
	"dru_bellow": {"bear": {"name": "Rugido do Urso", "mult": {"radius": 1.3}}},
	"dru_earth_slam": {"bear": {"name": "Pisão do Urso", "mult": {"radius": 1.25, "power": 1.15}, "effects": {"stun": {"duration": 0.9}}}},
	"dru_stampede": {"bear": {"name": "Investida do Urso", "mult": {"power": 1.2}, "effects": {"dash": 6.5}}},
	"dru_mountain": {"bear": {"name": "Avalanche do Urso", "mult": {"radius": 1.2, "power": 1.1}}},
	"dru_oak_skin": {"bear": {"name": "Couro de Carvalho", "effects": {"shield": {"amount_pct_hp": 35, "duration": 8}}}},
	"dru_claw": {"wolf": {"name": "Mordida", "mult": {"startup": 0.7, "power": 1.1}, "effects": {"dot": {"dps": 6, "duration": 4}}}},
	"dru_pounce": {"wolf": {"name": "Salto do Lobo", "mult": {"range": 1.4, "power": 1.15}, "effects": {"dash": 7.0}}},
	"dru_maim": {"wolf": {"name": "Dilacerar Feral", "effects": {"slow": {"pct": 50, "duration": 2.5}}}},
	"dru_frenzy": {"wolf": {"name": "Uivo da Matilha", "set": {"radius": 6.0}}},
	"dru_rampage": {"wolf": {"name": "Redemoinho de Presas", "mult": {"radius": 1.2, "startup": 0.8}}},
	"dru_savage": {"wolf": {"name": "Golpe da Matilha", "effects": {"heal_pct_of_dmg": 0.35}}},
}

static func _s(id: String, name: String, lvl: int, build: String, req: Array, tgt: int, kind: int,
		power: float, mp: float, cd: float, desc: String, ext: Dictionary = {}) -> Dictionary:
	var d := {"id": id, "name": name, "unlock_level": lvl, "build": build, "requires": _req(req), "target": tgt,
		"kind": kind, "power": power, "mp_cost": mp, "cooldown": cd, "description": desc}
	match tgt:
		T_TARGET:
			d["range"] = 2.6; d["radius"] = 0.0; d["max_targets"] = 1
		T_SELF:
			d["radius"] = 0.0
	if kind == K_BUFF:
		d["power"] = 0.0; d["startup"] = 0.1; d["recovery"] = 0.2
	for k in ext:
		if k in ["dot", "slow", "stun", "root", "buff", "shield", "dash", "summon", "heal_pct_of_dmg", "taunt", "boss_summon", "wither", "form", "stealth", "trap", "pet_command", "pet_buff", "curse", "channel", "mend_pct_of_dmg"]:
			if not d.has("effects"):
				d["effects"] = {}
			d["effects"][k] = ext[k]
		else:
			d[k] = ext[k]
	return d

static func _buff(id: String, name: String, lvl: int, build: String, req: Array, mp: float, cd: float, desc: String, buff: Dictionary, ext: Dictionary = {}) -> Dictionary:
	var e2 := ext.duplicate()
	e2["buff"] = buff
	return _s(id, name, lvl, build, req, T_SELF, K_BUFF, 0.0, mp, cd, desc, e2)

static func _dot(dps: float, dur: float) -> Dictionary:
	return {"dps": dps, "duration": dur}

static func _slow(pct: float, dur: float) -> Dictionary:
	return {"pct": pct, "duration": dur}

static func _dur(dur: float) -> Dictionary:
	return {"duration": dur}

## Skills além das 6 originais (14-16 por classe). Agrupadas por build.
static func _more() -> Dictionary:
	return {
	"paladin": [
		_buff("pal_blessed_armor", "Armadura Abençoada", 1, "", [], 10, 18, "+20% DEF por 10s.", {"id": "blessed_armor", "duration": 10, "def_pct": 20}),
		_s("pal_purge", "Purgar", 28, "", [], T_SELF, K_MAG, 2.4, 30, 18, "Purga sagrada ao redor: dano e lentidão.", {"radius": 4.0, "slow": _slow(40, 2.5)}),
		# Guardião (espada/maça + escudo)
		_buff("pal_shield_wall", "Muralha de Escudo", 8, "guardiao", ["shield"], 18, 24, "+45% DEF e -20% velocidade por 6s.", {"id": "shield_wall", "duration": 6, "def_pct": 45, "speed_pct": -20}),
		_s("pal_aegis_slam", "Golpe de Égide", 12, "guardiao", ["shield"], T_CONE, K_PHYS, 1.4, 14, 9, "Golpe de escudo em cone que atordoa 0.7s.", {"radius": 2.6, "cone_angle_deg": 100, "stun": _dur(0.7)}),
		_s("pal_retribution", "Retribuição", 24, "guardiao", ["shield"], T_SELF, K_PHYS, 1.9, 26, 16, "Explosão de luz ao redor; cura 30% do dano causado.", {"radius": 3.5, "heal_pct_of_dmg": 0.3}),
		# Cruzado: mais golpes de arma de duas mãos
		_s("pal_twin_slash", "Arco Radiante", 2, "cruzado", ["two_handed"], T_CONE, K_PHYS, 1.5, 8, 3, "Corte largo em leque com a arma de duas mãos.", {"radius": 2.6, "cone_angle_deg": 110, "max_targets": 4}),
		_s("pal_blade_dance", "Giro do Cruzado", 7, "cruzado", ["two_handed"], T_SELF, K_PHYS, 2.0, 16, 9, "Gira a arma pesada: dano em tudo ao redor.", {"radius": 3.0, "active": 0.3}),
		_s("pal_lunge", "Estocada Sagrada", 11, "cruzado", ["two_handed"], T_DIR, K_PHYS, 1.8, 12, 7, "Avança 4.5m perfurando quem estiver no caminho.", {"range": 5.0, "radius": 0.9, "dash": 4.5}),
		_s("pal_flurry", "Sentença", 17, "cruzado", ["two_handed"], T_TARGET, K_PHYS, 3.0, 20, 10, "Sequência de golpes pesados em um alvo.", {"hit_stop_frames": 5}),
		_buff("pal_valor", "Valor", 22, "cruzado", ["two_handed"], 20, 24, "+30% ATK e +10 crit por 8s.", {"id": "valor", "duration": 8, "atk_pct": 30, "crit": 10}),
		# Cruzado (arma de duas mãos)
		_s("pal_crusader_strike", "Golpe do Cruzado", 4, "cruzado", ["two_handed"], T_CONE, K_PHYS, 2.0, 12, 5, "Golpe largo com a arma de duas mãos.", {"radius": 3.0, "cone_angle_deg": 120, "hit_stop_frames": 5}),
		_s("pal_hammer_light", "Martelo de Luz", 9, "cruzado", ["two_handed"], T_GROUND, K_MAG, 2.0, 18, 10, "Martelo de luz cai no cursor e atordoa 0.8s.", {"range": 7.0, "radius": 2.2, "stun": _dur(0.8)}),
		_s("pal_holy_wave", "Onda Sagrada", 14, "cruzado", ["two_handed"], T_DIR, K_MAG, 1.8, 16, 7, "Onda sagrada que atravessa inimigos.", {"range": 9.0, "radius": 0.8, "projectile_speed": 16.0, "projectile_pierce": true}),
		_buff("pal_zeal", "Zelo", 18, "cruzado", ["two_handed"], 18, 22, "+25% ATK/MATK e +10% velocidade por 10s.", {"id": "zeal", "duration": 10, "atk_pct": 25, "matk_pct": 25, "speed_pct": 10}),
		_s("pal_judgement_blade", "Lâmina do Juízo", 26, "cruzado", ["two_handed"], T_GROUND, K_PHYS, 3.4, 30, 16, "Lâmina gigante de luz no cursor: dano enorme e atordoa 1s.", {"range": 6.0, "radius": 2.5, "stun": _dur(1.0), "hit_stop_frames": 6}),
		# Templário (espada/maça + escudo): golpes de fogo sagrado (dano físico do ATK, queimadura do MATK), marca de penitência
		_s("pal_sacred_flame", "Chama Sagrada", 2, "templario", ["shield"], T_DIR, K_PHYS, 1.8, 8, 3, "Corte que lança uma chama sagrada: dano e queimadura por 4s.", {"range": 9.0, "radius": 0.5, "projectile_speed": 20.0, "startup": 0.14, "dot": _dot(5, 4)}),
		_s("pal_brand", "Marca da Penitência", 7, "templario", ["shield"], T_TARGET, K_PHYS, 1.8, 12, 9, "Golpe que marca o alvo com luz: dano e ele recebe +15% de dano de todos por 6s.", {"range": 8.0, "startup": 0.15, "curse": {"id": "penance", "duration": 6, "taken_pct": 15}}),
		_s("pal_cleansing_fire", "Fogo Purificador", 13, "templario", ["shield"], T_GROUND, K_PHYS, 1.9, 16, 9, "Chão em chamas sagradas no cursor: dano, queimadura e lentidão.", {"range": 8.0, "radius": 2.6, "startup": 0.2, "dot": _dot(9, 5), "slow": _slow(25, 2)}),
		_s("pal_flame_pyre", "Pira Sagrada", 16, "templario", ["shield"], T_SELF, K_PHYS, 2.2, 18, 10, "Ergue chamas sagradas à sua volta: dano e queimadura em quem estiver perto.", {"radius": 3.4, "startup": 0.2, "dot": _dot(7, 4)}),
		_buff("pal_avenging_wrath", "Ira Vingadora", 19, "templario", ["shield"], 20, 24, "+25% ATK, +25% MATK e +8 crit por 10s.", {"id": "avenging_wrath", "duration": 10, "atk_pct": 25, "matk_pct": 25, "crit": 8}),
		_s("pal_sun_strike", "Golpe Solar", 25, "templario", ["shield"], T_CONE, K_PHYS, 4.0, 28, 15, "Golpe de luz solar em leque: dano enorme, atordoa 0.8s e cura 20% do dano.", {"radius": 3.2, "cone_angle_deg": 110, "startup": 0.25, "stun": _dur(0.8), "heal_pct_of_dmg": 0.2, "hit_stop_frames": 6}),
	],
	"berserker": [
		_buff("ber_bloodlust", "Sede de Sangue", 1, "", [], 10, 18, "+15% ATK por 10s.", {"id": "bloodlust", "duration": 10, "atk_pct": 15}),
		# Armas Gêmeas (duas armas de 1 mão)
		_s("ber_hack", "Talho Duplo", 2, "carniceiro", ["dual"], T_TARGET, K_PHYS, 1.7, 8, 3, "Dois talhos com as duas armas: sangramento por 4s.", {"dot": _dot(4, 4)}),
		_s("ber_rend", "Dilacerar", 8, "carniceiro", ["dual"], T_CONE, K_PHYS, 1.4, 12, 7, "Dilacera em cone: sangramento forte.", {"radius": 2.6, "cone_angle_deg": 110, "dot": _dot(6, 5)}),
		_s("ber_axe_storm", "Tempestade de Aço", 13, "carniceiro", ["dual"], T_SELF, K_PHYS, 2.4, 20, 11, "Tempestade de golpes ao redor: tudo sangra por 4s.", {"radius": 3.2, "active": 0.3, "dot": _dot(6, 4)}),
		_s("ber_throw_axe", "Arremesso Brutal", 16, "carniceiro", ["dual"], T_DIR, K_PHYS, 1.9, 14, 8, "Arremessa a arma da mão secundária: dano e lentidão.", {"range": 9.0, "radius": 0.5, "projectile_speed": 18.0, "slow": _slow(35, 2)}),
		_s("ber_butcher", "Carnificina", 24, "carniceiro", ["dual"], T_TARGET, K_PHYS, 3.6, 26, 14, "Golpe brutal em um alvo; cura 25% do dano.", {"heal_pct_of_dmg": 0.25, "hit_stop_frames": 6}),
		# Armas Gêmeas: golpes rápidos
		_s("ber_twin_fang", "Presas Gêmeas", 2, "carniceiro", ["dual"], T_CONE, K_PHYS, 1.5, 8, 3, "Dois cortes rápidos em leque que retardam 25%.", {"radius": 2.6, "cone_angle_deg": 100, "slow": _slow(25, 1.5)}),
		_s("ber_blade_rush", "Investida de Lâminas", 7, "carniceiro", ["dual"], T_DIR, K_PHYS, 1.6, 12, 7, "Investida de 5m cortando tudo no caminho.", {"range": 5.0, "radius": 0.9, "dash": 5.0}),
		_s("ber_steel_whirl", "Turbilhão de Aço", 12, "carniceiro", ["dual"], T_SELF, K_PHYS, 2.2, 18, 10, "Turbilhão de aço ao redor: cura 15% do dano causado.", {"radius": 3.0, "heal_pct_of_dmg": 0.15}),
		_s("ber_crimson_flurry", "Rajada Rubra", 18, "carniceiro", ["dual"], T_TARGET, K_PHYS, 3.2, 22, 11, "Rajada de cortes em um alvo.", {"hit_stop_frames": 5}),
		_s("ber_bladestorm", "Tempestade de Lâminas", 26, "carniceiro", ["dual"], T_SELF, K_PHYS, 3.0, 32, 18, "Dano altíssimo em tudo ao redor.", {"radius": 3.6, "active": 0.4}),
		# Executor (duas mãos)
		_s("ber_overhead", "Golpe Avassalador", 4, "executor", ["two_handed"], T_TARGET, K_PHYS, 2.4, 12, 6, "Golpe vertical que atordoa 0.5s.", {"stun": _dur(0.5), "hit_stop_frames": 6}),
		_s("ber_earthsplitter", "Racha-Terra", 11, "executor", ["two_handed"], T_DIR, K_PHYS, 2.2, 16, 9, "Racha o chão em linha reta: dano e lentidão.", {"range": 7.0, "radius": 1.0, "slow": _slow(40, 2)}),
		_buff("ber_titan_grip", "Pegada de Titã", 17, "executor", ["two_handed"], 18, 24, "+35% ATK e -15% DEF por 10s.", {"id": "titan_grip", "duration": 10, "atk_pct": 35, "def_pct": -15}),
		_s("ber_decapitate", "Decapitar", 28, "executor", ["two_handed"], T_TARGET, K_PHYS, 4.4, 34, 18, "Golpe final devastador em um alvo.", {"hit_stop_frames": 7}),
	],
	"bishop": [
		_s("bis_light", "Luz Sagrada", 1, "", [], T_DIR, K_MAG, 1.2, 6, 1.8, "Pequeno projétil de luz.", {"range": 9.0, "radius": 0.4, "projectile_speed": 20.0}),
		_s("bis_renew", "Renovar", 5, "", [], T_SELF, K_HEAL, 0.9, 10, 5, "Cura rápida em si mesmo.", {"startup": 0.2, "lock_facing": false}),
		_s("bis_holy_nova", "Nova Sagrada", 12, "", [], T_SELF, K_MAG, 1.4, 18, 10, "Explosão de luz ao redor.", {"radius": 3.5}),
		_s("bis_martyr", "Mártir", 24, "", [], T_SELF, K_BUFF, 0.0, 20, 30, "Escudo sagrado de 30% do HP por 6s.", {"shield": {"amount_pct_hp": 30, "duration": 6}}),
		# Sacerdote (orbe ou cajado)
		_s("bis_prayer", "Prece", 8, "sacerdote", ["mace", "shield"], T_SELF, K_HEAL, 1.4, 22, 14, "Cura você e aliados num raio de 6m.", {"radius": 6.0, "startup": 0.35}),
		_buff("bis_ward", "Égide Divina", 13, "sacerdote", ["mace", "shield"], 18, 20, "+25% DEF para você e aliados próximos por 10s.", {"id": "ward", "duration": 10, "def_pct": 25}, {"radius": 6.0}),
		_s("bis_mend", "Remendo Sagrado", 17, "sacerdote", ["mace", "shield"], T_GROUND, K_HEAL, 1.8, 24, 10, "Cura forte em área no cursor.", {"range": 9.0, "radius": 2.5}),
		_buff("bis_angel", "Asas Angelicais", 22, "sacerdote", ["mace", "shield"], 28, 35, "+20% MATK, +20% velocidade e +15% DEF no grupo por 10s (você e aliados próximos).", {"id": "angel", "duration": 10, "matk_pct": 20, "speed_pct": 20, "def_pct": 15}, {"radius": 7.0}),
		_s("bis_miracle", "Milagre", 28, "sacerdote", ["mace", "shield"], T_SELF, K_HEAL, 3.0, 40, 45, "Cura enorme em todos num raio de 8m.", {"radius": 8.0, "startup": 0.5}),
		# Inquisidor (martelo de duas mãos)
		_s("bis_hammer", "Martelo de Luz", 4, "inquisidor", ["scepter"], T_TARGET, K_MAG, 2.0, 10, 6, "Um martelo de luz cai no alvo: dano e atordoa 0.6s.", {"range": 8.0, "stun": _dur(0.6), "hit_stop_frames": 5}),
		_s("bis_condemn", "Condenar", 9, "inquisidor", ["scepter"], T_GROUND, K_MAG, 1.4, 16, 9, "Chão condenado: dano contínuo.", {"range": 8.0, "radius": 2.4, "dot": _dot(7, 5)}),
		_s("bis_exorcism", "Exorcismo", 11, "inquisidor", ["scepter"], T_DIR, K_MAG, 2.0, 16, 7, "Raio exorcista que atravessa inimigos.", {"range": 9.0, "radius": 0.7, "projectile_speed": 18.0, "projectile_pierce": true}),
		_buff("bis_zealot", "Fervor", 14, "inquisidor", ["scepter"], 18, 22, "+25% ATK/MATK por 10s.", {"id": "fervor", "duration": 10, "atk_pct": 25, "matk_pct": 25}),
		_s("bis_crusade", "Cruzada", 18, "inquisidor", ["scepter"], T_CONE, K_MAG, 2.2, 22, 10, "Cone de fogo sagrado.", {"radius": 4.0, "cone_angle_deg": 90}),
		_s("bis_wrath", "Ira Divina", 25, "inquisidor", ["scepter"], T_GROUND, K_MAG, 3.6, 34, 20, "Dano enorme em área e atordoa 1.2s.", {"range": 8.0, "radius": 3.0, "stun": _dur(1.2), "hit_stop_frames": 6}),
		# Clérigo de Batalha (maça + escudo, placa): corpo a corpo, cada golpe cura o aliado mais ferido
		_s("bis_holy_blow", "Martelada da Fé", 2, "batalha", ["mace"], T_CONE, K_PHYS, 3.0, 8, 3, "Golpe largo com a maça; 25% do dano cura o aliado mais ferido por perto.", {"radius": 2.4, "cone_angle_deg": 100, "startup": 0.14, "mend_pct_of_dmg": 0.25}),
		_s("bis_shield_smite", "Castigo do Escudo", 7, "batalha", ["mace", "shield"], T_DIR, K_PHYS, 2.6, 12, 8, "Avança 3m com o escudo: dano e atordoa o primeiro alvo 0.8s.", {"range": 3.5, "radius": 0.9, "max_targets": 1, "startup": 0.1, "dash": 3.0, "stun": _dur(0.8)}),
		_buff("bis_battle_hymn", "Hino de Batalha", 10, "batalha", ["mace"], 18, 24, "+20% ATK e +15% DEF para você e aliados próximos por 10s.", {"id": "battle_hymn", "duration": 10, "atk_pct": 20, "def_pct": 15}, {"radius": 6.0}),
		_s("bis_holy_quake", "Tremor Sagrado", 14, "batalha", ["mace"], T_SELF, K_PHYS, 3.4, 18, 9, "Bate a maça no chão: dano ao redor, lentidão e 20% do dano cura o aliado mais ferido.", {"radius": 3.2, "startup": 0.2, "slow": _slow(30, 2), "mend_pct_of_dmg": 0.2, "hit_stop_frames": 5}),
		_s("bis_faith_leap", "Salto da Fé", 20, "batalha", ["mace"], T_GROUND, K_PHYS, 3.6, 20, 12, "Salta até o cursor e esmaga o chão: dano, atordoa 0.6s e 20% do dano cura o aliado mais ferido.", {"range": 6.0, "radius": 2.4, "startup": 0.12, "dash": 5.5, "stun": _dur(0.6), "mend_pct_of_dmg": 0.2}),
		_s("bis_divine_hammer", "Martelo Divino", 26, "batalha", ["mace"], T_TARGET, K_PHYS, 5.5, 30, 16, "Golpe divino num alvo: dano enorme, atordoa 1s e 35% do dano cura o aliado mais ferido.", {"startup": 0.25, "stun": _dur(1.0), "mend_pct_of_dmg": 0.35, "hit_stop_frames": 6}),
	],
	"druid": [
		_buff("dru_bark", "Pele de Casca", 1, "", [], 10, 18, "+20% DEF por 10s.", {"id": "bark", "duration": 10, "def_pct": 20}),
		# Guardião da Floresta (martelo de duas mãos, tanque)
		_s("dru_maul", "Esmagar", 2, "guardiao_verde", ["mace2h"], T_CONE, K_PHYS, 1.6, 8, 4, "Esmaga em cone e retarda.", {"radius": 2.8, "cone_angle_deg": 110, "slow": _slow(30, 1.5)}),
		_s("dru_bellow", "Urro da Mata", 8, "guardiao_verde", ["mace2h"], T_SELF, K_BUFF, 0.0, 12, 12, "Prende os inimigos em 7 m em você por 4s (chefes: 2s) e ganha +20% DEF por 6s.", {"radius": 7.0, "taunt": {"duration": 4}, "buff": {"id": "bellow", "duration": 6, "def_pct": 20}}),
		_s("dru_earth_slam", "Golpe da Terra", 8, "guardiao_verde", ["mace2h"], T_SELF, K_PHYS, 1.8, 16, 10, "Golpeia o chão: dano ao redor e atordoa 0.6s.", {"radius": 3.0, "stun": _dur(0.6)}),
		_s("dru_oak_skin", "Pele de Carvalho", 12, "guardiao_verde", ["mace2h"], T_SELF, K_BUFF, 0.0, 20, 24, "Escudo de 25% do HP e +20% DEF por 8s.", {"shield": {"amount_pct_hp": 25, "duration": 8}, "buff": {"id": "oak_skin", "duration": 8, "def_pct": 20}}),
		_s("dru_stampede", "Estouro", 18, "guardiao_verde", ["mace2h"], T_DIR, K_PHYS, 2.0, 18, 10, "Avança 5m atropelando e atordoando 0.5s.", {"range": 6.0, "radius": 1.0, "dash": 5.0, "stun": _dur(0.5)}),
		_s("dru_mountain", "Fúria da Montanha", 25, "guardiao_verde", ["mace2h"], T_GROUND, K_PHYS, 3.2, 30, 18, "Rochas caem no cursor: dano e atordoa 1s.", {"range": 6.0, "radius": 3.0, "stun": _dur(1.0), "hit_stop_frames": 6}),
		# Fera Selvagem (duas maças)
		_s("dru_claw", "Garras", 2, "fera", ["dual_mace"], T_TARGET, K_PHYS, 1.6, 8, 3, "Golpes duplos que fazem sangrar.", {"dot": _dot(4, 4)}),
		_s("dru_pounce", "Bote", 7, "fera", ["dual_mace"], T_DIR, K_PHYS, 1.7, 12, 7, "Bote de 5m que fere quem estiver no caminho.", {"range": 5.0, "radius": 0.9, "dash": 5.0}),
		_s("dru_maim", "Dilacerar", 7, "fera", ["dual_mace"], T_TARGET, K_PHYS, 1.9, 11, 6, "Dilacera o alvo: retarda 35% e faz sangrar.", {"slow": _slow(35, 2.0), "dot": _dot(5, 4)}),
		_buff("dru_frenzy", "Frenesi", 12, "fera", ["dual_mace"], 16, 22, "+30% ATK e +15% velocidade por 8s.", {"id": "frenzy", "duration": 8, "atk_pct": 30, "speed_pct": 15}),
		_s("dru_rampage", "Fúria Selvagem", 17, "fera", ["dual_mace"], T_SELF, K_PHYS, 2.3, 20, 10, "Golpeia tudo ao redor.", {"radius": 3.0}),
		_s("dru_savage", "Golpe Feral", 24, "fera", ["dual_mace"], T_TARGET, K_PHYS, 3.6, 26, 14, "Golpe brutal; cura 20% do dano.", {"heal_pct_of_dmg": 0.2, "hit_stop_frames": 6}),
		# Xamã (varinha)
		_s("dru_moonfire", "Fogo Lunar", 4, "xama", ["staff"], T_DIR, K_MAG, 1.5, 10, 3.5, "Projétil lunar que queima.", {"range": 9.0, "radius": 0.5, "projectile_speed": 18.0, "dot": _dot(5, 4)}),
		_s("dru_starfall", "Chuva Estelar", 11, "xama", ["staff"], T_GROUND, K_MAG, 2.2, 20, 10, "Estrelas caem no cursor.", {"range": 9.0, "radius": 2.8}),
		_s("dru_cyclone", "Ciclone", 16, "xama", ["staff"], T_GROUND, K_MAG, 1.6, 20, 12, "Ciclone prende inimigos por 1.5s.", {"range": 8.0, "radius": 2.6, "root": _dur(1.5)}),
		_buff("dru_grove", "Bênção do Bosque", 6, "xama", ["staff"], 18, 20, "+15% ATK, MATK e cura para você e aliados próximos por 12s.",
			{"id": "grove", "duration": 12, "atk_pct": 15, "matk_pct": 15, "heal_pct": 15}, {"radius": 7.0}),
		_s("dru_spirit_wolves", "Lobos Espirituais", 9, "xama", ["staff"], T_SELF, K_SUMMON, 0.0, 24, 18, "Invoca 2 lobos espirituais por 20s.",
			{"summon": {"monster_id": "spirit_wolf", "count": 2, "duration": 20, "max": 4}, "startup": 0.35}),
		_s("dru_treant", "Despertar o Ent", 19, "xama", ["staff"], T_SELF, K_SUMMON, 0.0, 34, 30, "Desperta um ent guardião por 25s que provoca os inimigos.",
			{"summon": {"monster_id": "treant", "count": 1, "duration": 25, "max": 2}, "startup": 0.5}),
		_s("dru_wolf_form", "Forma de Lobo", 3, "fera", ["dual_mace"], T_SELF, K_BUFF, 0.0, 10, 1.5, "Vira lobo (lance de novo para voltar): +25% velocidade de ataque, +20% velocidade, +10% ATK, +5 crítico. As skills da Fera viram golpes de lobo.",
			{"form": "wolf", "startup": 0.25}),
		_s("dru_prowl", "Espreitar", 5, "fera", ["dual_mace"], T_SELF, K_BUFF, 0.0, 14, 12, "Só na forma de lobo: some da vista dos inimigos por 8s. O primeiro golpe sai da sombra com +60% de dano.",
			{"stealth": 8.0, "startup": 0.15}),
		_s("dru_storm", "Tempestade da Natureza", 27, "xama", ["staff"], T_GROUND, K_MAG, 3.4, 36, 18, "Tempestade enorme: dano e lentidão.", {"range": 9.0, "radius": 3.5, "slow": _slow(40, 3)}),
	],
	"ranger": [
		_s("ran_anchor", "Flecha Âncora", 6, "", ["bow", "rifle"], T_DIR, K_PHYS, 1.3, 9, 8, "Disparo que prende o alvo no chão por 1.5s.",
			{"range": 10.0, "radius": 0.5, "projectile_speed": 24.0, "max_targets": 1, "root": _dur(1.5)}),
		# Atirador (arco, alvo único)
		_s("ran_snipe", "Tiro Certeiro", 8, "atirador", ["rifle"], T_DIR, K_PHYS, 2.6, 14, 9, "Tiro instantâneo de longuíssimo alcance.", {"range": 13.0, "radius": 0.4, "startup": 0.45, "max_targets": 1}),
		_s("ran_piercing", "Flecha Perfurante", 12, "cacador", ["bow"], T_DIR, K_PHYS, 1.9, 12, 6, "Flecha que atravessa inimigos.", {"range": 11.0, "radius": 0.5, "projectile_speed": 26.0, "projectile_pierce": true}),
		_s("ran_headshot", "Tiro na Cabeça", 18, "atirador", ["rifle"], T_TARGET, K_PHYS, 3.4, 20, 12, "Tiro preciso no alvo: atordoa 0.5s.", {"range": 11.0, "stun": _dur(0.5), "hit_stop_frames": 5}),
		_buff("ran_deadeye", "Olho de Águia", 24, "atirador", ["rifle"], 20, 28, "+20 crit e +15% ATK por 10s.", {"id": "deadeye", "duration": 10, "crit": 20, "atk_pct": 15}),
		# Caçador (arco, área e controle)
		# Caçador: companheiro (bicho permanente que segue o dono)
		_s("ran_companion", "Companheiro", 2, "cacador", ["bow"], T_SELF, K_SUMMON, 0.0, 20, 20, "Chama o seu lince companheiro (fica com você até cair; vida e ataque vêm dos seus).",
			{"summon": {"monster_id": "companion", "count": 1, "duration": 0.0, "max": 1, "owner_stats": true}, "startup": 0.4}),
		_s("ran_sic", "Ataque da Fera", 7, "cacador", ["bow"], T_TARGET, K_PHYS, 2.2, 12, 8, "O companheiro salta no alvo: dano alto e atordoa 0.8s.",
			{"range": 12.0, "pet_command": {"stun": 0.8}, "startup": 0.1}),
		_buff("ran_pack", "Instinto da Matilha", 16, "cacador", ["bow"], 18, 24, "+20% ATK e +20% velocidade de ataque para você e o companheiro por 10s.",
			{"id": "pack", "duration": 10, "atk_pct": 20, "aspd_pct": 20}, {"pet_buff": true}),
		# Atirador: mosquete e armadilhas
		_s("ran_scatter", "Tiro de Dispersão", 6, "atirador", ["rifle"], T_CONE, K_PHYS, 1.8, 12, 6, "Carga de chumbo em cone curto que empurra o alvo para trás.",
			{"radius": 5.0, "cone_angle_deg": 55, "max_targets": 5, "slow": _slow(30, 1.5)}),
		_s("ran_mine", "Mina Explosiva", 9, "atirador", ["rifle"], T_GROUND, K_PHYS, 2.6, 16, 9, "Mina no chão (conta no limite de 3): explode em área quando um inimigo pisa.",
			{"range": 7.0, "radius": 2.6, "trap": {"kind": "mine", "duration": 30.0, "hit_radius": 1.2}, "hit_stop_frames": 5}),
		_s("ran_frost_trap", "Armadilha de Gelo", 13, "atirador", ["rifle"], T_GROUND, K_PHYS, 1.0, 14, 10, "Armadilha no chão (conta no limite de 3): congela a área, retarda 60% por 3s.",
			{"range": 7.0, "radius": 3.0, "trap": {"kind": "frost", "duration": 30.0, "hit_radius": 1.3}, "slow": _slow(60, 3.0)}),
		_s("ran_explosive", "Flecha Explosiva", 5, "cacador", ["bow"], T_GROUND, K_PHYS, 1.6, 12, 7, "Explode no cursor.", {"range": 10.0, "radius": 2.2}),
		_s("ran_frost_arrow", "Flecha Gélida", 9, "cacador", ["bow"], T_DIR, K_PHYS, 1.4, 10, 5, "Retarda 45% por 2.5s.", {"range": 10.0, "radius": 0.5, "projectile_speed": 22.0, "slow": _slow(45, 2.5)}),
		_s("ran_net", "Rede", 13, "cacador", ["bow"], T_GROUND, K_PHYS, 0.4, 14, 12, "Rede no cursor prende por 2.5s.", {"range": 9.0, "radius": 2.4, "root": _dur(2.5)}),
		_s("ran_volley", "Saraivada", 22, "cacador", ["bow"], T_CONE, K_PHYS, 2.4, 22, 10, "Leque de flechas longo e estreito.", {"radius": 8.0, "cone_angle_deg": 50}),
		_s("ran_barrage", "Barragem", 27, "cacador", ["bow"], T_GROUND, K_PHYS, 3.2, 32, 18, "Bombardeio de flechas em área grande.", {"range": 11.0, "radius": 3.5}),
		# Patrulheiro (duas armas de 1 mão)
	],
	"assassin": [
		_s("ass_quick_stab", "Estocada Rápida", 1, "", [], T_CONE, K_PHYS, 1.2, 5, 2, "Estocada curta em até 2 alvos.", {"radius": 2.2, "cone_angle_deg": 70, "max_targets": 2}),
		# Lâminas (duas adagas): veneno, esquiva, furtividade e pelas costas
		_s("ass_twin_strike", "Golpe Gêmeo", 2, "laminas", ["dual_dagger"], T_TARGET, K_PHYS, 1.8, 8, 3, "Duas adagas no mesmo alvo."),
		_s("ass_blade_flurry", "Rajada de Lâminas", 8, "laminas", ["dual_dagger"], T_CONE, K_PHYS, 1.6, 12, 6, "Cortes rápidos em leque.", {"radius": 2.6, "cone_angle_deg": 110}),
		_s("ass_eviscerate", "Eviscerar", 13, "laminas", ["dual_dagger"], T_TARGET, K_PHYS, 3.0, 18, 9, "Corte profundo em um alvo.", {"hit_stop_frames": 5}),
		_s("ass_dance", "Dança da Morte", 19, "laminas", ["dual_dagger"], T_SELF, K_PHYS, 2.4, 22, 11, "Gira entre os inimigos ao redor.", {"radius": 3.0}),
		_s("ass_thousand", "Mil Cortes", 26, "laminas", ["dual_dagger"], T_TARGET, K_PHYS, 4.0, 30, 16, "Rajada final em um alvo.", {"hit_stop_frames": 7}),
		# Duelista: duas espadas, equilibrado (golpes largos, guarda, avanço e golpe de mestre)
		_s("ass_cross_slash", "Corte Cruzado", 2, "duelista", ["dual_sword"], T_CONE, K_PHYS, 1.6, 9, 4, "Duas espadas em X num leque largo.", {"radius": 2.9, "cone_angle_deg": 110}),
		_s("ass_thrust", "Estocada Dupla", 6, "duelista", ["dual_sword"], T_TARGET, K_PHYS, 2.0, 11, 6, "Duas estocadas no alvo que fazem sangrar.", {"range": 2.6, "dot": _dot(6, 4)}),
		_buff("ass_guard", "Guarda do Duelista", 9, "duelista", ["dual_sword"], 14, 18, "+30% DEF e +15% de esquiva por 6s.", {"id": "duel_guard", "duration": 6, "def_pct": 30, "evasion": 15}),
		_s("ass_lunge", "Avanço do Duelista", 12, "duelista", ["dual_sword"], T_DIR, K_PHYS, 2.4, 15, 9, "Avança 6m com as duas espadas à frente.", {"range": 6.0, "radius": 0.9, "dash": 6.0}),
		_s("ass_steel_whirl", "Turbilhão de Aço", 16, "duelista", ["dual_sword"], T_SELF, K_PHYS, 2.2, 18, 10, "Gira com as duas espadas: dano ao redor.", {"radius": 3.0}),
		_s("ass_crimson", "Lâmina Carmesim", 20, "duelista", ["dual_sword"], T_TARGET, K_PHYS, 2.8, 18, 9, "Golpe que cura 25% do dano.", {"heal_pct_of_dmg": 0.25}),
		_buff("ass_focus", "Foco do Duelista", 23, "duelista", ["dual_sword"], 20, 26, "+20 crítico, +15% ATK e +15% velocidade de ataque por 8s.", {"id": "duel_focus", "duration": 8, "crit": 20, "atk_pct": 15, "aspd_pct": 15}),
		_s("ass_master", "Golpe de Mestre", 28, "duelista", ["dual_sword"], T_TARGET, K_PHYS, 4.4, 32, 16, "Sequência final das duas espadas no alvo.", {"hit_stop_frames": 7}),
		_s("ass_toxic_cloud", "Nuvem Tóxica", 5, "laminas", ["dual_dagger"], T_GROUND, K_PHYS, 0.5, 12, 9, "Nuvem no cursor: veneno forte por 6s.", {"range": 8.0, "radius": 2.4, "dot": _dot(8, 6)}),
		_s("ass_venom_dart", "Dardo Venenoso", 9, "laminas", ["dual_dagger"], T_DIR, K_PHYS, 1.0, 8, 3, "Dardo que envenena por 5s.", {"range": 10.0, "radius": 0.4, "projectile_speed": 24.0, "dot": _dot(6, 5)}),
		_s("ass_paralyze", "Toxina Paralisante", 14, "laminas", ["dual_dagger"], T_TARGET, K_PHYS, 0.8, 14, 12, "Paralisa o alvo por 1.5s.", {"range": 3.0, "stun": _dur(1.5)}),
		_buff("ass_plague_blade", "Lâmina Pestilenta", 4, "laminas", ["dual_dagger"], 14, 22, "Envenena as lâminas por 14s: cada golpe aplica veneno (renova) e +15% velocidade de ataque.",
			{"id": "plague_blade", "duration": 14, "hit_poison": 9, "aspd_pct": 15}),
		_s("ass_vanish", "Sumir", 7, "laminas", ["dual_dagger"], T_SELF, K_BUFF, 0.0, 16, 14, "Some da vista dos inimigos por 6s. O primeiro golpe sai da sombra com +60% de dano (e pelas costas, crítico).",
			{"stealth": 6.0, "startup": 0.1}),
		_buff("ass_reflexes", "Reflexos", 11, "laminas", ["dual_dagger"], 12, 18, "+35% de esquiva e +20% velocidade por 5s.", {"id": "reflexes", "duration": 5, "evasion": 35, "speed_pct": 20}),
		_s("ass_virulence", "Virulência", 25, "laminas", ["dual_dagger"], T_GROUND, K_PHYS, 1.2, 30, 16, "Epidemia no cursor: veneno altíssimo.", {"range": 8.0, "radius": 3.2, "dot": _dot(16, 6)}),
	],
	"elementalist": [
		# Combinações (geral: qualquer foco usa; o dano soma a média dos bônus dos dois elementos)
		_s("ele_firestorm", "Tempestade de Brasas", 12, "", ["staff"], T_GROUND, K_MAG, 2.2, 24, 11, "Fogo e raio no cursor: queima por 3s e atordoa 0.5s.",
			{"range": 9.0, "radius": 2.8, "dot": _dot(6, 3), "stun": _dur(0.5), "startup": 0.4}),
		_s("ele_frost_flare", "Choque Térmico", 16, "", ["staff"], T_TARGET, K_MAG, 2.6, 22, 10, "Gelo e fogo de uma vez no alvo: explode ao redor, queima e retarda 40%.",
			{"range": 9.0, "radius": 1.8, "max_targets": 5, "dot": _dot(7, 3), "slow": _slow(40, 2)}),
		_s("ele_hailstorm", "Granizo Trovejante", 19, "", ["staff"], T_GROUND, K_MAG, 2.4, 28, 13, "Granizo eletrificado no cursor: retarda 50% e atordoa 0.4s.",
			{"range": 9.0, "radius": 3.2, "slow": _slow(50, 3), "stun": _dur(0.4), "startup": 0.45}),
		_s("ele_prism", "Prisma Elemental", 29, "", ["staff"], T_DIR, K_MAG, 4.2, 42, 18, "Raio dos três elementos: atravessa tudo na linha, queima e retarda.",
			{"range": 12.0, "radius": 1.0, "projectile_speed": 20.0, "projectile_pierce": true, "dot": _dot(10, 3), "slow": _slow(40, 2), "hit_stop_frames": 6}),
		# Elementais (um por foco; só um vivo por vez: invocar outro substitui o atual)
		_s("ele_summon_fire", "Elemental de Fogo", 10, "fogo", ["staff"], T_SELF, K_SUMMON, 0.0, 30, 24, "Invoca um elemental de fogo por 25s que sopra chamas (um elemental por vez: substitui o anterior).",
			{"summon": {"monster_id": "fire_elemental", "count": 1, "duration": 25, "max": 1, "replaces": ELEMENTALS}, "startup": 0.45}),
		_s("ele_summon_ice", "Elemental de Gelo", 14, "gelo", ["staff"], T_SELF, K_SUMMON, 0.0, 30, 24, "Invoca um elemental de gelo por 25s que atira estilhaços que retardam (um elemental por vez: substitui o anterior).",
			{"summon": {"monster_id": "frost_elemental", "count": 1, "duration": 25, "max": 1, "replaces": ELEMENTALS}, "startup": 0.45}),
		_s("ele_summon_storm", "Elemental de Raio", 17, "raio", ["staff"], T_SELF, K_SUMMON, 0.0, 30, 24, "Invoca um elemental de raio por 25s que solta descargas que atordoam (um elemental por vez: substitui o anterior).",
			{"summon": {"monster_id": "storm_elemental", "count": 1, "duration": 25, "max": 1, "replaces": ELEMENTALS}, "startup": 0.45}),
		_s("ele_spark", "Faísca", 1, "", [], T_DIR, K_MAG, 1.0, 4, 1.5, "Faísca instantânea em linha.", {"range": 8.0, "radius": 0.6, "max_targets": 1}),
		# Fogo (orbe)
		_s("ele_flame_wave", "Onda de Chamas", 5, "fogo", ["staff"], T_CONE, K_MAG, 1.6, 14, 6, "Chamas em cone que queimam.", {"radius": 4.0, "cone_angle_deg": 80, "dot": _dot(5, 3)}),
		_s("ele_combustion", "Combustão", 9, "fogo", ["staff"], T_TARGET, K_MAG, 2.2, 16, 8, "Incendeia o alvo sob o cursor.", {"range": 9.0, "dot": _dot(8, 4)}),
		_s("ele_fire_wall", "Muralha de Fogo", 13, "fogo", ["staff"], T_GROUND, K_MAG, 1.2, 22, 12, "Fogo no chão queima por 5s.", {"range": 8.0, "radius": 2.6, "dot": _dot(10, 5)}),
		_s("ele_inferno", "Inferno", 22, "fogo", ["staff"], T_SELF, K_MAG, 2.6, 30, 16, "Explosão de fogo ao redor.", {"radius": 4.0, "dot": _dot(10, 4)}),
		_s("ele_phoenix", "Fênix", 27, "fogo", ["staff"], T_DIR, K_MAG, 3.4, 36, 16, "Fênix atravessa tudo na linha e queima.", {"range": 11.0, "radius": 1.2, "projectile_speed": 16.0, "projectile_pierce": true, "dot": _dot(8, 3)}),
		# Gelo (cajado)
		_s("ele_ice_lance", "Lança de Gelo", 2, "gelo", ["staff"], T_DIR, K_MAG, 1.5, 8, 3, "Lança que retarda 35%.", {"range": 9.0, "radius": 0.4, "projectile_speed": 22.0, "slow": _slow(35, 2)}),
		_s("ele_frost_armor", "Armadura de Gelo", 8, "gelo", ["staff"], T_SELF, K_BUFF, 0.0, 16, 24, "Escudo de 15% do HP e +30% DEF por 8s.", {"shield": {"amount_pct_hp": 15, "duration": 8}, "buff": {"id": "frost_armor", "duration": 8, "def_pct": 30}}),
		_s("ele_glacier", "Geleira", 12, "gelo", ["staff"], T_GROUND, K_MAG, 1.8, 20, 11, "Gelo prende inimigos por 1.5s.", {"range": 8.0, "radius": 2.4, "root": _dur(1.5)}),
		_s("ele_shatter", "Estilhaçar", 18, "gelo", ["staff"], T_TARGET, K_MAG, 2.8, 22, 10, "Estilhaça o alvo: atordoa 0.6s e fere ao redor.", {"range": 9.0, "radius": 1.5, "max_targets": 4, "stun": _dur(0.6)}),
		_s("ele_absolute_zero", "Zero Absoluto", 26, "gelo", ["staff"], T_SELF, K_MAG, 3.0, 36, 20, "Congela tudo ao redor por 1.5s.", {"radius": 4.5, "stun": _dur(1.5), "hit_stop_frames": 5}),
		# Raio (varinha)
		_s("ele_chain", "Corrente Elétrica", 4, "raio", ["staff"], T_TARGET, K_MAG, 1.6, 10, 4, "Raio salta para até 3 inimigos próximos.", {"range": 9.0, "radius": 3.0, "max_targets": 4}),
		_s("ele_static", "Campo Estático", 11, "raio", ["staff"], T_GROUND, K_MAG, 1.4, 16, 9, "Campo elétrico: dano e lentidão.", {"range": 8.0, "radius": 3.0, "slow": _slow(40, 2.5)}),
		_buff("ele_overload", "Sobrecarga", 16, "raio", ["staff"], 18, 24, "+30% MATK e +15% velocidade por 10s.", {"id": "overload", "duration": 10, "matk_pct": 30, "speed_pct": 15}),
		_s("ele_thunder", "Trovão", 21, "raio", ["staff"], T_GROUND, K_MAG, 2.8, 26, 12, "Trovão no cursor: atordoa 0.8s.", {"range": 9.0, "radius": 2.2, "stun": _dur(0.8), "hit_stop_frames": 5}),
		_s("ele_storm_lord", "Senhor da Tempestade", 28, "raio", ["staff"], T_GROUND, K_MAG, 3.8, 38, 18, "Tempestade elétrica gigante.", {"range": 10.0, "radius": 3.5}),
	],
	"necromancer": [
		_s("nec_bone_spear", "Lança de Osso", 1, "", [], T_DIR, K_MAG, 1.2, 6, 2, "Projétil de osso.", {"range": 9.0, "radius": 0.4, "projectile_speed": 20.0}),
		# Invocador (cajado)
		_buff("nec_dark_pact", "Pacto Sombrio", 8, "invocador", ["scythe"], 16, 24, "+25% MATK por 12s (invocações ficam mais fortes).", {"id": "dark_pact", "duration": 12, "matk_pct": 25}),
		_s("nec_corpse_explosion", "Explosão de Cadáver", 16, "invocador", ["scythe"], T_GROUND, K_MAG, 2.4, 22, 10, "Explosão de carne no cursor.", {"range": 8.0, "radius": 3.0}),
		_s("nec_army", "Exército dos Mortos", 27, "invocador", ["scythe"], T_SELF, K_SUMMON, 0.0, 40, 45, "Invoca 4 esqueletos por 25s.", {"summon": {"monster_id": "skeleton_minion", "count": 4, "duration": 25, "max": 8}, "startup": 0.5}),
		# Ceifador (foice)
		# Invocador: mortos-vivos (cada tipo tem o próprio limite)
		_s("nec_bone_hound", "Cães de Ossos", 7, "invocador", ["scythe"], T_SELF, K_SUMMON, 0.0, 22, 18, "Ergue 2 cães de ossos velozes por 25s (máx. 2).",
			{"summon": {"monster_id": "bone_hound", "count": 2, "duration": 25, "max": 2}, "startup": 0.35}),
		_s("nec_lich", "Erguer Lich", 14, "invocador", ["scythe"], T_SELF, K_SUMMON, 0.0, 34, 30, "Ergue um lich por 30s que lança gelo: estilhaços e anel congelante (máx. 1).",
			{"summon": {"monster_id": "lich_servant", "count": 1, "duration": 30, "max": 1}, "startup": 0.5}),
		_s("nec_skeleton_king", "Rei Esqueleto", 26, "invocador", ["scythe"], T_SELF, K_SUMMON, 0.0, 45, 50, "Ergue o Rei Esqueleto por 30s: grande, provoca e gira a espada (máx. 1).",
			{"summon": {"monster_id": "skeleton_king", "count": 1, "duration": 30, "max": 1}, "startup": 0.6}),
		# Ceifador: formas (ligam/desligam) e golpes de foice
		_s("nec_phantom", "Forma Fantasma", 6, "ceifador", ["scythe"], T_SELF, K_BUFF, 0.0, 16, 4, "Vira um fantasma por 10 s (usar de novo desfaz): +25% velocidade, +20% esquiva, +10% MATK. Golpes de foice mudam.",
			{"form": "phantom", "startup": 0.2}),
		_s("nec_demon_form", "Forma Demoníaca", 22, "ceifador", ["scythe"], T_SELF, K_BUFF, 0.0, 30, 6, "Vira um demônio (liga/desliga): grande, +25% HP, +20% DEF e MATK, roubo de vida. Golpes de foice mudam.",
			{"form": "demon", "startup": 0.45}),
		# Sombras: maldições (debuffs) e canalizações (segura o efeito em pulsos; dash corta)
		_s("nec_mind_flay", "Açoite Mental", 5, "pestilento", ["scythe"], T_TARGET, K_MAG, 0.55, 10, 4, "Canaliza 2.4s no alvo: 4 pulsos de dano que retardam 40%.",
			{"range": 9.0, "channel": {"ticks": 4}, "active": 2.4, "slow": _slow(40, 1.0), "startup": 0.15, "recovery": 0.15}),
		_s("nec_curse_weakness", "Maldição da Fraqueza", 8, "pestilento", ["scythe"], T_GROUND, K_MAG, 0.2, 12, 10, "Inimigos na área causam 25% menos dano por 8s.",
			{"range": 9.0, "radius": 3.0, "curse": {"id": "weakness", "duration": 8.0, "weaken_pct": 25}}),
		_s("nec_drain_soul", "Sugar Alma", 13, "pestilento", ["scythe"], T_TARGET, K_MAG, 0.7, 16, 8, "Canaliza 3s no alvo: 5 pulsos que curam 50% do dano.",
			{"range": 8.0, "channel": {"ticks": 5}, "active": 3.0, "heal_pct_of_dmg": 0.5, "startup": 0.15, "recovery": 0.15}),
		_s("nec_curse_doom", "Condenação", 19, "pestilento", ["scythe"], T_TARGET, K_MAG, 0.6, 16, 12, "Marca o alvo: recebe 20% a mais de dano de todos por 10s.",
			{"range": 9.0, "curse": {"id": "doom", "duration": 10.0, "taken_pct": 20}}),
		_s("nec_void_beam", "Raio do Vazio", 23, "pestilento", ["scythe"], T_DIR, K_MAG, 0.7, 28, 12, "Canaliza 3s um raio que atravessa a linha: 6 pulsos em até 4 inimigos.",
			{"range": 10.0, "radius": 0.8, "max_targets": 4, "channel": {"ticks": 6}, "active": 3.0, "startup": 0.2, "recovery": 0.2}),
		_s("nec_curse_agony", "Agonia", 28, "pestilento", ["scythe"], T_GROUND, K_MAG, 0.8, 30, 16, "Maldição em área: dor contínua forte e +15% de dano recebido por 8s.",
			{"range": 9.0, "radius": 3.2, "dot": _dot(14, 8), "curse": {"id": "agony", "duration": 8.0, "taken_pct": 15}}),
		_s("nec_reap", "Ceifar", 2, "ceifador", ["scythe"], T_CONE, K_MAG, 1.6, 8, 3.5, "Ceifa em arco largo; cura 15%.", {"radius": 3.0, "cone_angle_deg": 120, "heal_pct_of_dmg": 0.15}),
		_s("nec_soul_rend", "Rasgar Alma", 9, "ceifador", ["scythe"], T_TARGET, K_MAG, 2.2, 14, 7, "Rasga a alma do alvo; cura 30%.", {"range": 3.0, "heal_pct_of_dmg": 0.3}),
		_s("nec_death_spin", "Giro da Morte", 14, "ceifador", ["scythe"], T_SELF, K_MAG, 2.2, 20, 10, "Gira a foice ao redor; cura 10%.", {"radius": 3.2, "heal_pct_of_dmg": 0.1}),
		_s("nec_bone_armor", "Armadura de Ossos", 18, "ceifador", ["scythe"], T_SELF, K_BUFF, 0.0, 20, 26, "Escudo de 20% do HP e +35% DEF por 8s.", {"shield": {"amount_pct_hp": 20, "duration": 8}, "buff": {"id": "bone_armor", "duration": 8, "def_pct": 35}}),
		_s("nec_grim", "Ceifeiro Sinistro", 26, "ceifador", ["scythe"], T_TARGET, K_MAG, 4.0, 32, 16, "Golpe final; cura 40% do dano.", {"range": 3.0, "heal_pct_of_dmg": 0.4, "hit_stop_frames": 6}),
		# Pestilento (varinha ou orbe)
		_s("nec_rot", "Podridão", 4, "pestilento", ["scythe"], T_TARGET, K_MAG, 0.6, 8, 4, "Apodrece o alvo por 6s.", {"range": 9.0, "dot": _dot(7, 6)}),
		_s("nec_swarm", "Enxame de Moscas", 11, "pestilento", ["scythe"], T_GROUND, K_MAG, 0.8, 16, 10, "Moscas: dano contínuo e lentidão.", {"range": 8.0, "radius": 2.5, "dot": _dot(9, 5), "slow": _slow(30, 3)}),
		_s("nec_decay", "Decadência", 17, "pestilento", ["scythe"], T_CONE, K_MAG, 1.4, 18, 8, "Cone de decadência que corrói.", {"radius": 4.5, "cone_angle_deg": 70, "dot": _dot(8, 5)}),
		_s("nec_pandemic", "Pandemia", 24, "pestilento", ["scythe"], T_GROUND, K_MAG, 1.4, 32, 18, "Doença em área enorme por 6s.", {"range": 9.0, "radius": 3.5, "dot": _dot(18, 6)}),
	],
	}

static func _all() -> Dictionary:
	return {
	"paladin": [
		{"id": "pal_holy_strike", "name": "Golpe Sagrado", "description": "Golpe frontal com luz. Cura 15% do dano causado.", "target": T_CONE, "kind": K_PHYS,
		 "power": 1.6, "mp_cost": 8, "cooldown": 3.0, "radius": 2.4, "cone_angle_deg": 90, "startup": 0.14, "active": 0.06, "recovery": 0.3, "cancel_after": 0.12, "icon_color": Color(1, 0.95, 0.6),
		 "effects": {"heal_pct_of_dmg": 0.15}, "mastery": _mastery({3: {"heal_pct_of_dmg": 0.25}, 5: {"heal_pct_of_dmg": 0.35}})},
		{"id": "pal_shield_bash", "name": "Pancada de Escudo", "description": "Avança e atordoa o alvo à frente por 1s.", "target": T_DIR, "kind": K_PHYS,
		 "power": 1.1, "mp_cost": 10, "cooldown": 7.0, "range": 3.0, "radius": 0.9, "max_targets": 1, "startup": 0.1, "active": 0.08, "recovery": 0.3, "icon_color": Color(0.8, 0.8, 0.9),
		 "effects": {"stun": {"duration": 1.0}, "dash": 1.5}, "mastery": _mastery({2: {"stun": {"duration": 1.3}}, 4: {"stun": {"duration": 1.6}}})},
		{"id": "pal_consecrate", "name": "Consagração", "description": "Abençoa o chão: dano sagrado em área ao redor.", "target": T_SELF, "kind": K_MAG,
		 "power": 1.4, "mp_cost": 16, "cooldown": 9.0, "radius": 3.2, "startup": 0.25, "active": 0.1, "recovery": 0.4, "icon_color": Color(1, 0.9, 0.4)},
		{"id": "pal_lay_hands", "name": "Imposição de Mãos", "description": "Cura forte em si mesmo (ou aliado próximo).", "target": T_SELF, "kind": K_HEAL,
		 "power": 2.2, "mp_cost": 22, "cooldown": 14.0, "radius": 2.0, "startup": 0.3, "active": 0.05, "recovery": 0.35, "icon_color": Color(1, 1, 0.8)},
		{"id": "pal_taunt", "name": "Provocar", "description": "Prende os inimigos em 7 m em você por 4s (chefes: 2s) e ganha +25% DEF por 6s.", "target": T_SELF, "kind": K_BUFF,
		 "power": 0.0, "mp_cost": 12, "cooldown": 12.0, "radius": 7.0, "startup": 0.1, "active": 0.05, "recovery": 0.25, "icon_color": Color(1, 0.6, 0.4),
		 "effects": {"taunt": {"duration": 4}, "buff": {"id": "bulwark", "duration": 6, "def_pct": 25}}},
		{"id": "pal_divine_shield", "name": "Escudo Divino", "description": "Escudo que absorve 25% do HP máximo por 6s.", "target": T_SELF, "kind": K_BUFF, "radius": 0.0,
		 "power": 0.0, "mp_cost": 28, "cooldown": 22.0, "startup": 0.15, "active": 0.05, "recovery": 0.2, "icon_color": Color(1, 1, 0.5),
		 "effects": {"shield": {"amount_pct_hp": 25, "duration": 6}}, "mastery": _mastery({2: {"shield": {"amount_pct_hp": 32, "duration": 6}}, 4: {"shield": {"amount_pct_hp": 40, "duration": 7}}})},
	],
	"berserker": [
		{"id": "ber_cleave", "name": "Rachar", "description": "Golpe largo que acerta até 4 inimigos.", "target": T_CONE, "kind": K_PHYS,
		 "power": 1.8, "mp_cost": 9, "cooldown": 3.5, "radius": 2.8, "cone_angle_deg": 120, "max_targets": 4, "startup": 0.18, "active": 0.06, "recovery": 0.35, "hit_stop_frames": 4, "icon_color": Color(1, 0.45, 0.3)},
		{"id": "ber_leap", "name": "Salto Selvagem", "description": "Salta até o ponto do cursor e esmaga o chão.", "target": T_GROUND, "kind": K_PHYS,
		 "power": 1.5, "mp_cost": 12, "cooldown": 8.0, "range": 6.0, "radius": 2.2, "startup": 0.12, "active": 0.1, "recovery": 0.35, "icon_color": Color(1, 0.6, 0.3),
		 "effects": {"dash": 5.5, "slow": {"pct": 30, "duration": 1.5}}},
		{"id": "ber_whirlwind", "name": "Redemoinho", "description": "Gira a arma: dano em todos ao redor.", "target": T_SELF, "kind": K_PHYS,
		 "power": 2.2, "mp_cost": 18, "cooldown": 10.0, "radius": 3.0, "startup": 0.2, "active": 0.3, "recovery": 0.4, "icon_color": Color(1, 0.5, 0.5)},
		{"id": "ber_fury", "name": "Fúria", "description": "+35% ATK e +15% velocidade por 8s.", "target": T_SELF, "kind": K_BUFF, "radius": 0.0,
		 "power": 0.0, "mp_cost": 15, "cooldown": 20.0, "startup": 0.1, "active": 0.05, "recovery": 0.2, "icon_color": Color(1, 0.3, 0.2),
		 "effects": {"buff": {"id": "fury", "duration": 8, "atk_pct": 35, "speed_pct": 15}}},
		{"id": "ber_execute", "name": "Executar", "description": "Golpe devastador em um alvo. Dano enorme.", "target": T_TARGET, "kind": K_PHYS,
		 "power": 3.4, "mp_cost": 20, "cooldown": 12.0, "range": 2.6, "radius": 0.0, "startup": 0.3, "active": 0.06, "recovery": 0.5, "hit_stop_frames": 6, "icon_color": Color(0.9, 0.2, 0.2)},
		{"id": "ber_warcry", "name": "Grito de Guerra", "description": "Atordoa inimigos próximos por 1.2s.", "target": T_SELF, "kind": K_MAG,
		 "power": 0.4, "mp_cost": 22, "cooldown": 24.0, "radius": 4.0, "startup": 0.2, "active": 0.05, "recovery": 0.3, "icon_color": Color(1, 0.8, 0.5),
		 "effects": {"stun": {"duration": 1.2}}},
	],
	"bishop": [
		{"id": "bis_heal", "name": "Curar", "description": "Cura o aliado do grupo sob o cursor (ou você).", "target": T_TARGET, "kind": K_HEAL,
		 "power": 1.5, "mp_cost": 14, "cooldown": 2.5, "range": 12.0, "radius": 0.0, "max_targets": 5, "startup": 0.3, "active": 0.05, "recovery": 0.25, "lock_facing": false, "icon_color": Color(0.8, 1, 0.8)},
		{"id": "bis_smite", "name": "Castigar", "description": "Raio de luz que atravessa inimigos.", "target": T_DIR, "kind": K_MAG,
		 "power": 1.7, "mp_cost": 12, "cooldown": 3.0, "range": 8.0, "radius": 0.5, "projectile_speed": 20.0, "projectile_pierce": true, "startup": 0.2, "active": 0.05, "recovery": 0.3, "icon_color": Color(1, 1, 0.7)},
		{"id": "bis_blessing", "name": "Bênção", "description": "+20% ATK/MATK e +5 crit para aliados próximos por 15s.", "target": T_SELF, "kind": K_BUFF,
		 "power": 0.0, "mp_cost": 20, "cooldown": 25.0, "radius": 6.0, "startup": 0.25, "active": 0.05, "recovery": 0.3, "icon_color": Color(1, 0.95, 0.6),
		 "effects": {"buff": {"id": "blessing", "duration": 15, "atk_pct": 20, "matk_pct": 20, "crit": 5}}},
		{"id": "bis_sanctuary", "name": "Santuário", "description": "Cura em área no ponto do cursor.", "target": T_GROUND, "kind": K_HEAL,
		 "power": 1.2, "mp_cost": 26, "cooldown": 12.0, "range": 8.0, "radius": 3.0, "startup": 0.35, "active": 0.05, "recovery": 0.35, "icon_color": Color(0.9, 1, 0.9)},
		{"id": "bis_purify", "name": "Purificar", "description": "Explosão sagrada: dano e lentidão em cone.", "target": T_CONE, "kind": K_MAG,
		 "power": 1.5, "mp_cost": 18, "cooldown": 8.0, "radius": 4.5, "cone_angle_deg": 80, "startup": 0.25, "active": 0.05, "recovery": 0.35, "icon_color": Color(1, 1, 0.9),
		 "effects": {"slow": {"pct": 40, "duration": 2.5}}},
		{"id": "bis_judgement", "name": "Julgamento", "description": "Pilar de luz no cursor: dano alto e atordoa.", "target": T_GROUND, "kind": K_MAG,
		 "power": 2.8, "mp_cost": 32, "cooldown": 18.0, "range": 9.0, "radius": 2.2, "startup": 0.45, "active": 0.05, "recovery": 0.4, "hit_stop_frames": 5, "icon_color": Color(1, 0.95, 0.5),
		 "effects": {"stun": {"duration": 1.0}}},
	],
	"druid": [
		{"id": "dru_thorns", "name": "Espinhos", "description": "Lança espinhos envenenados na direção do cursor.", "target": T_DIR, "kind": K_MAG,
		 "power": 1.3, "mp_cost": 9, "cooldown": 2.5, "range": 8.0, "radius": 0.4, "projectile_speed": 18.0, "startup": 0.15, "active": 0.05, "recovery": 0.25, "icon_color": Color(0.5, 0.9, 0.4),
		 "effects": {"dot": {"dps": 4, "duration": 4}}},
		{"id": "dru_entangle", "name": "Enraizar", "description": "Raízes prendem inimigos na área por 2.5s.", "target": T_GROUND, "kind": K_MAG,
		 "power": 0.6, "mp_cost": 15, "cooldown": 10.0, "range": 8.0, "radius": 2.5, "startup": 0.25, "active": 0.05, "recovery": 0.3, "icon_color": Color(0.4, 0.7, 0.3),
		 "effects": {"root": {"duration": 2.5}}},
		{"id": "dru_regrowth", "name": "Rebrotar", "description": "Cura a si e aliados próximos.", "target": T_SELF, "kind": K_HEAL,
		 "power": 1.3, "mp_cost": 18, "cooldown": 8.0, "radius": 4.0, "startup": 0.3, "active": 0.05, "recovery": 0.3, "icon_color": Color(0.6, 1, 0.6)},
		{"id": "dru_swarm", "name": "Enxame", "description": "Insetos devoram inimigos em cone (dano contínuo).", "target": T_CONE, "kind": K_MAG,
		 "power": 1.0, "mp_cost": 20, "cooldown": 9.0, "radius": 5.0, "cone_angle_deg": 70, "startup": 0.2, "active": 0.05, "recovery": 0.3, "icon_color": Color(0.7, 0.6, 0.2),
		 "effects": {"dot": {"dps": 7, "duration": 5}, "slow": {"pct": 25, "duration": 3}}},
		{"id": "dru_bear_form", "name": "Forma de Urso", "description": "Vira urso (lance de novo para voltar): +40% DEF, +25% HP, +10% ATK, um pouco mais lento. As skills do Guardião viram golpes de urso.", "target": T_SELF, "kind": K_BUFF, "radius": 0.0,
		 "power": 0.0, "mp_cost": 10, "cooldown": 1.5, "startup": 0.25, "active": 0.05, "recovery": 0.25, "icon_color": Color(0.55, 0.4, 0.25),
		 "effects": {"form": "bear"}},
		{"id": "dru_wild_growth", "name": "Crescimento Selvagem", "description": "Floresta explode no cursor: dano alto + raízes.", "target": T_GROUND, "kind": K_MAG,
		 "power": 2.6, "mp_cost": 34, "cooldown": 20.0, "range": 9.0, "radius": 3.2, "startup": 0.4, "active": 0.05, "recovery": 0.4, "icon_color": Color(0.3, 0.9, 0.4),
		 "effects": {"root": {"duration": 1.5}}},
	],
	"ranger": [
		{"id": "ran_power_shot", "name": "Tiro Poderoso", "description": "Flecha perfurante de longo alcance.", "target": T_DIR, "kind": K_PHYS,
		 "power": 2.0, "mp_cost": 8, "cooldown": 3.0, "range": 12.0, "radius": 0.4, "projectile_speed": 28.0, "projectile_pierce": true, "startup": 0.22, "active": 0.05, "recovery": 0.3, "icon_color": Color(0.7, 1, 0.7)},
		{"id": "ran_multishot", "name": "Tiro Múltiplo", "description": "Leque de flechas em cone curto.", "target": T_CONE, "kind": K_PHYS,
		 "power": 1.3, "mp_cost": 12, "cooldown": 5.0, "radius": 6.0, "cone_angle_deg": 60, "max_targets": 5, "startup": 0.18, "active": 0.05, "recovery": 0.3, "icon_color": Color(0.8, 1, 0.6)},
		{"id": "ran_disengage", "name": "Recuar", "description": "Salta para trás e ganha +30% de velocidade por 3s.", "target": T_SELF, "kind": K_BUFF, "radius": 0.0,
		 "power": 0.0, "mp_cost": 8, "cooldown": 9.0, "startup": 0.05, "active": 0.05, "recovery": 0.15, "lock_facing": true, "icon_color": Color(0.6, 0.9, 0.9),
		 "effects": {"dash": -4.5, "buff": {"id": "swift", "duration": 3, "speed_pct": 30}}},
		{"id": "ran_trap", "name": "Armadilha de Mandíbula", "description": "Coloca no chão uma armadilha (até 3): quem pisar fica preso 2.5s e sofre dano.", "target": T_GROUND, "kind": K_PHYS,
		 "power": 1.6, "mp_cost": 12, "cooldown": 6.0, "range": 7.0, "radius": 1.4, "startup": 0.25, "active": 0.05, "recovery": 0.3, "icon_color": Color(0.7, 0.6, 0.4),
		 "effects": {"trap": {"kind": "jaw", "duration": 30.0, "hit_radius": 1.4}, "root": {"duration": 2.5}}},
		{"id": "ran_mark", "name": "Marca do Caçador", "description": "+40% ATK e +15 crit por 8s.", "target": T_SELF, "kind": K_BUFF, "radius": 0.0,
		 "power": 0.0, "mp_cost": 16, "cooldown": 22.0, "startup": 0.1, "active": 0.05, "recovery": 0.2, "icon_color": Color(1, 0.8, 0.4),
		 "effects": {"buff": {"id": "mark", "duration": 8, "atk_pct": 40, "crit": 15}}},
		{"id": "ran_rain", "name": "Chuva de Flechas", "description": "Chuva de flechas em grande área no cursor.", "target": T_GROUND, "kind": K_PHYS,
		 "power": 2.4, "mp_cost": 30, "cooldown": 18.0, "range": 11.0, "radius": 3.8, "startup": 0.4, "active": 0.05, "recovery": 0.4, "icon_color": Color(0.6, 0.8, 1),
		 "effects": {"slow": {"pct": 30, "duration": 2}}},
	],
	"assassin": [
		{"id": "ass_backstab", "name": "Apunhalar", "description": "Golpe rápido com chance de crítico altíssima (pelas costas, ainda mais).", "target": T_TARGET, "kind": K_PHYS,
		 "power": 1.7, "mp_cost": 7, "cooldown": 2.5, "range": 2.2, "startup": 0.08, "active": 0.05, "recovery": 0.22, "cancel_after": 0.05, "icon_color": Color(0.8, 0.5, 1),
		 "effects": {"buff": {"id": "focus", "duration": 0.3, "crit": 40}}},
		{"id": "ass_shadowstep", "name": "Passo das Sombras", "description": "Teleporta até o cursor e corta tudo ao redor.", "target": T_GROUND, "kind": K_PHYS,
		 "power": 1.2, "mp_cost": 12, "cooldown": 7.0, "range": 7.0, "radius": 1.8, "startup": 0.05, "active": 0.05, "recovery": 0.25, "icon_color": Color(0.5, 0.3, 0.7),
		 "effects": {"dash": 6.5}},
		{"id": "ass_poison", "name": "Lâmina Venenosa", "description": "Corte em cone que envenena por 6s.", "target": T_CONE, "kind": K_PHYS,
		 "power": 1.1, "mp_cost": 10, "cooldown": 6.0, "radius": 2.3, "cone_angle_deg": 100, "startup": 0.1, "active": 0.05, "recovery": 0.25, "icon_color": Color(0.4, 0.9, 0.3),
		 "effects": {"dot": {"dps": 6, "duration": 6}}},
		{"id": "ass_fan", "name": "Leque de Facas", "description": "Lança facas em todas as direções.", "target": T_SELF, "kind": K_PHYS,
		 "power": 1.5, "mp_cost": 16, "cooldown": 9.0, "radius": 4.5, "startup": 0.15, "active": 0.05, "recovery": 0.3, "icon_color": Color(0.8, 0.8, 0.9)},
		{"id": "ass_smoke", "name": "Cortina de Fumaça", "description": "Lentidão em área e +25% velocidade própria.", "target": T_SELF, "kind": K_MAG,
		 "power": 0.3, "mp_cost": 18, "cooldown": 16.0, "radius": 4.0, "startup": 0.1, "active": 0.05, "recovery": 0.2, "icon_color": Color(0.5, 0.5, 0.55),
		 "effects": {"slow": {"pct": 50, "duration": 3}, "buff": {"id": "smoke", "duration": 4, "speed_pct": 25}}},
		{"id": "ass_execute", "name": "Golpe Mortal", "description": "Dano brutal em um alvo isolado.", "target": T_TARGET, "kind": K_PHYS,
		 "power": 3.6, "mp_cost": 24, "cooldown": 14.0, "range": 2.4, "startup": 0.2, "active": 0.05, "recovery": 0.4, "hit_stop_frames": 6, "icon_color": Color(0.9, 0.2, 0.5)},
	],
	"elementalist": [
		{"id": "ele_fireball", "name": "Bola de Fogo", "description": "Projétil de fogo que explode e queima.", "target": T_DIR, "kind": K_MAG,
		 "power": 1.8, "mp_cost": 11, "cooldown": 2.5, "range": 9.0, "radius": 0.5, "projectile_speed": 16.0, "startup": 0.22, "active": 0.05, "recovery": 0.3, "icon_color": Color(1, 0.5, 0.2),
		 "effects": {"dot": {"dps": 5, "duration": 3}}},
		{"id": "ele_frost_nova", "name": "Nova de Gelo", "description": "Congela e retarda tudo ao redor.", "target": T_SELF, "kind": K_MAG,
		 "power": 1.1, "mp_cost": 16, "cooldown": 9.0, "radius": 3.5, "startup": 0.15, "active": 0.05, "recovery": 0.3, "icon_color": Color(0.6, 0.9, 1),
		 "effects": {"root": {"duration": 1.2}, "slow": {"pct": 50, "duration": 3}}},
		{"id": "ele_lightning", "name": "Relâmpago", "description": "Raio instantâneo em linha reta.", "target": T_DIR, "kind": K_MAG,
		 "power": 2.0, "mp_cost": 14, "cooldown": 4.0, "range": 10.0, "radius": 0.6, "max_targets": 3, "startup": 0.2, "active": 0.05, "recovery": 0.3, "hit_stop_frames": 4, "icon_color": Color(0.8, 0.8, 1)},
		{"id": "ele_meteor", "name": "Meteoro", "description": "Meteoro cai no cursor: dano enorme em área.", "target": T_GROUND, "kind": K_MAG,
		 "power": 3.0, "mp_cost": 30, "cooldown": 14.0, "range": 10.0, "radius": 3.0, "startup": 0.55, "active": 0.05, "recovery": 0.45, "hit_stop_frames": 6, "icon_color": Color(1, 0.4, 0.1),
		 "effects": {"dot": {"dps": 6, "duration": 3}}},
		{"id": "ele_blink", "name": "Piscar", "description": "Teleporta curta distância na direção do cursor.", "target": T_SELF, "kind": K_MOVE, "radius": 0.0,
		 "power": 0.0, "mp_cost": 10, "cooldown": 8.0, "startup": 0.02, "active": 0.02, "recovery": 0.1, "icon_color": Color(0.7, 0.6, 1),
		 "effects": {"dash": 6.0}},
		{"id": "ele_blizzard", "name": "Nevasca", "description": "Tempestade de gelo gigante no cursor.", "target": T_GROUND, "kind": K_MAG,
		 "power": 2.6, "mp_cost": 38, "cooldown": 20.0, "range": 10.0, "radius": 4.5, "startup": 0.5, "active": 0.05, "recovery": 0.5, "icon_color": Color(0.5, 0.8, 1),
		 "effects": {"slow": {"pct": 60, "duration": 4}, "dot": {"dps": 5, "duration": 4}}},
	],
	"necromancer": [
		{"id": "nec_drain", "name": "Drenar Vida", "description": "Dreno sombrio: cura 40% do dano.", "target": T_DIR, "kind": K_MAG,
		 "power": 1.4, "mp_cost": 10, "cooldown": 2.5, "range": 7.0, "radius": 0.7, "max_targets": 1, "startup": 0.2, "active": 0.05, "recovery": 0.3, "icon_color": Color(0.4, 1, 0.6),
		 "effects": {"heal_pct_of_dmg": 0.4}},
		{"id": "nec_raise", "name": "Erguer Mortos", "description": "Invoca 2 esqueletos por 25s (máx 3).", "target": T_SELF, "kind": K_SUMMON, "radius": 0.0,
		 "power": 0.0, "mp_cost": 22, "cooldown": 12.0, "startup": 0.4, "active": 0.05, "recovery": 0.3, "icon_color": Color(0.7, 0.9, 0.7),
		 "effects": {"summon": {"monster_id": "skeleton_minion", "count": 2, "duration": 25, "max": 3}},
		 "mastery": _mastery({2: {"summon": {"monster_id": "skeleton_minion", "count": 2, "duration": 30, "max": 4}}, 4: {"summon": {"monster_id": "skeleton_minion", "count": 3, "duration": 35, "max": 5}}})},
		{"id": "nec_plague", "name": "Praga", "description": "Nuvem de doença no cursor: dano contínuo forte.", "target": T_GROUND, "kind": K_MAG,
		 "power": 0.8, "mp_cost": 18, "cooldown": 9.0, "range": 9.0, "radius": 3.0, "startup": 0.3, "active": 0.05, "recovery": 0.3, "icon_color": Color(0.5, 0.7, 0.3),
		 "effects": {"dot": {"dps": 9, "duration": 6}, "slow": {"pct": 20, "duration": 3}}},
		{"id": "nec_bone_wall", "name": "Muralha de Ossos", "description": "Escudo de ossos (20% HP) e +20% DEF por 6s.", "target": T_SELF, "kind": K_BUFF, "radius": 0.0,
		 "power": 0.0, "mp_cost": 20, "cooldown": 18.0, "startup": 0.15, "active": 0.05, "recovery": 0.25, "icon_color": Color(0.9, 0.9, 0.8),
		 "effects": {"shield": {"amount_pct_hp": 20, "duration": 6}, "buff": {"id": "bonewall", "duration": 6, "def_pct": 20}}},
		{"id": "nec_curse", "name": "Maldição", "description": "Cone de trevas: dano e lentidão pesada.", "target": T_CONE, "kind": K_MAG,
		 "power": 1.6, "mp_cost": 20, "cooldown": 10.0, "radius": 5.0, "cone_angle_deg": 75, "startup": 0.25, "active": 0.05, "recovery": 0.35, "icon_color": Color(0.5, 0.2, 0.6),
		 "effects": {"slow": {"pct": 45, "duration": 3}}},
		{"id": "nec_harvest", "name": "Colheita Sombria", "description": "Explosão de almas: dano alto em área e cura 25%.", "target": T_SELF, "kind": K_MAG,
		 "power": 2.6, "mp_cost": 36, "cooldown": 22.0, "radius": 4.5, "startup": 0.45, "active": 0.05, "recovery": 0.45, "hit_stop_frames": 5, "icon_color": Color(0.3, 1, 0.7),
		 "effects": {"heal_pct_of_dmg": 0.25}},
	],
	}
