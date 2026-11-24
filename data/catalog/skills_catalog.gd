class_name SkillsCatalog
extends RefCounted
## 8 classes × 20+ skills (o jogador aprende com pontos e equipa 6). Cada skill tem nível mínimo,
## build ("" = geral) e arma exigida (requires). Todas pelos construtores compactos `_s`/`_buff`: as 6 originais de
## cada classe em `_originals()` (registradas primeiro), as demais em `_more()`.
## target: 0 SELF, 1 DIRECTION, 2 GROUND, 3 CONE, 4 TARGET · kind: 0 PHYS, 1 MAG, 2 HEAL, 3 BUFF, 4 SUMMON, 5 MOVE

const T_SELF := 0; const T_DIR := 1; const T_GROUND := 2; const T_CONE := 3; const T_TARGET := 4
const K_PHYS := 0; const K_MAG := 1; const K_HEAL := 2; const K_BUFF := 3; const K_SUMMON := 4; const K_MOVE := 5


static func _mk(d: Dictionary) -> SkillDef:
	var s := SkillDef.new()
	CatalogUtil.fill(s, d)
	return s

## maestria padrão: +12% poder, -4% MP, -5% CD por nível; `extras` opcional por nível (índice 1..5)
static func _mastery(extras: Dictionary = {}) -> Array:
	var arr := []
	for lv in range(6):
		arr.append({"power_mult": 1.0 + Balance.MASTERY_POWER_PER_LV * lv, "mp_mult": 1.0 - Balance.MASTERY_MP_PER_LV * lv, "cd_mult": 1.0 - Balance.MASTERY_CD_PER_LV * lv, "extra": extras.get(lv, {})})
	return arr

static func build(classes: Dictionary) -> Array:
	var out: Array = []
	var build_element := {}            # build -> elementos (campo `element` da build, só no Elementalista)
	for cid in classes:
		for b in classes[cid].builds:
			if b.has("element"):
				build_element[b["id"]] = b["element"]
	var defs := _originals()
	for cls_id in defs:
		for d in defs[cls_id]:
			out.append(_finish(d, cls_id))
	var more := _more()
	for cls_id in more:
		for d in more[cls_id]:
			out.append(_finish(d, cls_id))
	var ults := _ultimates()
	ults.merge(_ultimates_b1())          # onda B1 (Paladino, Berserker, Bispo, Druida)
	for d in _ult_helpers_b1():
		out.append(_finish(d, ""))
	for cls_id in ults:
		for d in ults[cls_id]:
			out.append(_finish(d, cls_id))
	var ults_b2 := _ultimates_b2()          # onda B2 (Ranger, Assassino, Gelo/Raio, Necromante)
	for cls_id in ults_b2:
		for d in ults_b2[cls_id]:
			out.append(_finish(d, cls_id))
	# skills de monstros/bosses
	for d in [
		{"id": "mob_charge", "name": "Investida", "target": T_DIR, "kind": K_PHYS, "power": 1.8, "cooldown": 7.0, "range": 7.0, "radius": 1.0, "startup": 0.6, "active": 0.1, "recovery": 0.6, "hit_stop_frames": 4, "icon_color": Color(1, 0.6, 0.3),
		 "effects": {"dash": 6.0, "stun": {"duration": 0.8}}},
		{"id": "mob_whirl", "name": "Giro Mortal", "target": T_SELF, "kind": K_PHYS, "power": 1.6, "cooldown": 8.0, "radius": 3.2, "startup": 0.7, "active": 0.2, "recovery": 0.5, "hit_stop_frames": 4, "icon_color": Color(1, 0.4, 0.3)},
		{"id": "mob_firebreath", "name": "Bafo de Fogo", "target": T_CONE, "kind": K_MAG, "power": 1.5, "cooldown": 6.0, "radius": 6.5, "cone_angle_deg": 70, "startup": 0.8, "active": 0.2, "recovery": 0.6, "hit_stop_frames": 4, "icon_color": Color(1, 0.3, 0.1),
		 "effects": {"dot": {"dps": 8, "duration": 4}}},
		# Dragonete Ancestral (chefe opcional do 30, mais forte que o Lich): sopro, cauda, mergulho, rugido e chuva de meteoros
		{"id": "mob_dragon_breath", "name": "Sopro de Dragão", "vfx": "fire", "target": T_CONE, "kind": K_MAG, "power": 1.9, "cooldown": 8.0, "radius": 8.5, "cone_angle_deg": 75, "startup": 1.0, "active": 0.3, "recovery": 0.7, "hit_stop_frames": 5, "icon_color": Color(1, 0.35, 0.1),
		 "effects": {"dot": {"dps": 14, "duration": 5}}},
		{"id": "mob_dragon_tail", "name": "Varrida de Cauda", "clip": "atk_sweep", "target": T_SELF, "kind": K_PHYS, "power": 1.5, "cooldown": 9.0, "radius": 4.6, "startup": 0.7, "active": 0.2, "recovery": 0.6, "hit_stop_frames": 4, "icon_color": Color(0.8, 0.45, 0.3),
		 "effects": {"slow": {"pct": 45, "duration": 2.5}}},
		{"id": "mob_dragon_dive", "name": "Mergulho de Asa", "vfx": "fire", "target": T_DIR, "kind": K_PHYS, "power": 2.0, "cooldown": 13.0, "range": 12.0, "radius": 2.2, "startup": 0.9, "active": 0.15, "recovery": 0.7, "hit_stop_frames": 5, "icon_color": Color(1, 0.55, 0.25), "mob_pick": "far",
		 "effects": {"dash": 10.0, "stun": {"duration": 0.8}}},
		{"id": "mob_dragon_roar", "name": "Rugido Ancestral", "clip": "shout", "vfx": "fire", "target": T_SELF, "kind": K_MAG, "power": 0.7, "cooldown": 20.0, "radius": 10.0, "startup": 1.3, "active": 0.2, "recovery": 0.6, "hit_stop_frames": 6, "icon_color": Color(1, 0.7, 0.3),
		 "effects": {"stun": {"duration": 1.4}}},
		{"id": "mob_dragon_meteor", "name": "Chuva de Meteoros", "clip": "cast_ground", "vfx": "fire", "target": T_GROUND, "kind": K_MAG, "power": 1.6, "cooldown": 14.0, "range": 16.0, "radius": 2.6, "startup": 0.7, "active": 0.1, "recovery": 0.5, "icon_color": Color(1, 0.4, 0.15), "mob_pick": "far",
		 "effects": {"barrage": {"count": 6, "radius": 2.6, "delay": 1.4, "spread": 11.0}, "dot": {"dps": 10, "duration": 3}}},
		{"id": "mob_dragon_call", "name": "Chamado da Ninhada", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 16.0, "radius": 8.0, "startup": 1.0, "active": 0.1, "recovery": 0.5, "icon_color": Color(1, 0.5, 0.35),
		 "effects": {"boss_summon": {"id": "dragon_whelp", "count": 2, "max": 4}}},
		# Catacumbas do Conde
		{"id": "mob_wail", "name": "Lamento", "target": T_CONE, "kind": K_MAG, "power": 1.3, "cooldown": 7.0, "radius": 7.0, "cone_angle_deg": 80, "startup": 0.8, "active": 0.2, "recovery": 0.5, "hit_stop_frames": 3, "icon_color": Color(0.6, 0.8, 1),
		 "effects": {"slow": {"pct": 40, "duration": 3}}},
		{"id": "mob_grave_touch", "name": "Toque da Cova", "target": T_TARGET, "kind": K_MAG, "power": 1.0, "cooldown": 9.0, "range": 8.0, "radius": 0.0, "max_targets": 1, "startup": 0.5, "active": 0.1, "recovery": 0.4, "icon_color": Color(0.5, 0.75, 0.5),
		 "effects": {"dot": {"dps": 5, "duration": 6}, "wither": {"pct": 50, "duration": 6}}},
		{"id": "mob_soul_drain", "name": "Dreno de Almas", "target": T_TARGET, "kind": K_MAG, "power": 1.4, "cooldown": 8.0, "range": 8.0, "radius": 0.0, "max_targets": 1, "startup": 0.6, "active": 0.1, "recovery": 0.4, "icon_color": Color(0.7, 0.3, 0.9),
		 "effects": {"heal_pct_of_dmg": 1.5}},
		{"id": "mob_raise_dead", "name": "Erguer os Mortos", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 20.0, "radius": 9.0, "startup": 1.0, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.8, 0.9, 0.75),
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
		{"id": "mob_thorn_lash", "name": "Chicote de Cipó", "clip": "atk_sweep", "target": T_TARGET, "kind": K_PHYS, "power": 0.9, "cooldown": 7.0, "range": 8.0, "radius": 0.0, "max_targets": 1, "startup": 0.55, "active": 0.1, "recovery": 0.45, "hit_stop_frames": 3, "icon_color": Color(0.45, 0.7, 0.3),
		 "effects": {"root": {"duration": 1.2}}},
		# investida élfica: mago, salto do lince
		{"id": "mob_light_beam", "name": "Raio de Luz", "target": T_TARGET, "kind": K_MAG, "power": 1.3, "cooldown": 5.0, "range": 9.0, "radius": 0.0, "max_targets": 1, "startup": 0.5, "active": 0.1, "recovery": 0.4, "hit_stop_frames": 2, "icon_color": Color(0.95, 1.0, 0.75)},
		{"id": "mob_raise_wisps", "name": "Chamar Espíritos", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 18.0, "radius": 12.0, "startup": 0.9, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.5, 1.0, 0.6),
		 "effects": {"boss_summon": {"id": "elf_wisp", "count": 2, "max": 2}}},
		{"id": "mob_lynx_leap", "name": "Salto do Lince", "target": T_DIR, "kind": K_PHYS, "power": 1.4, "cooldown": 9.0, "range": 9.0, "radius": 1.6, "startup": 0.45, "active": 0.15, "recovery": 0.5, "hit_stop_frames": 3, "icon_color": Color(0.9, 0.75, 0.4),
		 "effects": {"dash": 8.0, "slow": {"pct": 40, "duration": 2}}},
		# Pedreira dos Golens
		{"id": "mob_quarry_slam", "name": "Soco da Pedreira", "target": T_CONE, "kind": K_PHYS, "power": 1.6, "cooldown": 7.0, "radius": 4.2, "cone_angle_deg": 80, "startup": 0.6, "active": 0.2, "recovery": 0.6, "hit_stop_frames": 5, "icon_color": Color(0.7, 0.6, 0.45),
		 "effects": {"slow": {"pct": 40, "duration": 2}}},
		{"id": "mob_boulder_toss", "name": "Pedregulho", "target": T_GROUND, "kind": K_PHYS, "power": 1.7, "cooldown": 9.0, "range": 10.0, "radius": 2.2, "startup": 1.0, "active": 0.2, "recovery": 0.5, "hit_stop_frames": 4, "icon_color": Color(0.6, 0.55, 0.45),
		 "effects": {"stun": {"duration": 0.6}}},
		{"id": "mob_rockfall", "name": "Desabamento", "target": T_GROUND, "kind": K_PHYS, "power": 1.6, "cooldown": 12.0, "range": 12.0, "radius": 2.5, "startup": 1.25, "active": 0.25, "recovery": 0.6, "hit_stop_frames": 4, "icon_color": Color(0.55, 0.5, 0.42),
		 "effects": {"slow": {"pct": 35, "duration": 2}}},
		{"id": "mob_magnet_pull", "name": "Veio Magnético", "target": T_SELF, "kind": K_MAG, "power": 0.7, "cooldown": 22.0, "radius": 10.0, "startup": 1.1, "active": 0.2, "recovery": 0.6, "hit_stop_frames": 3, "icon_color": Color(0.85, 0.45, 0.25),
		 "effects": {"pull": {"gap": 2.5}, "slow": {"pct": 40, "duration": 2}}},
		{"id": "mob_shard_fan", "name": "Leque de Lascas", "target": T_CONE, "kind": K_MAG, "power": 1.3, "cooldown": 8.0, "radius": 7.5, "cone_angle_deg": 60, "startup": 0.6, "active": 0.15, "recovery": 0.45, "hit_stop_frames": 3, "icon_color": Color(0.5, 0.78, 1.0)},
		{"id": "mob_crystal_prison", "name": "Prisão de Cristal", "target": T_GROUND, "kind": K_MAG, "power": 1.0, "cooldown": 12.0, "range": 9.0, "radius": 2.0, "startup": 1.0, "active": 0.2, "recovery": 0.5, "hit_stop_frames": 3, "icon_color": Color(0.55, 0.8, 1.0),
		 "effects": {"stun": {"duration": 1.0}}},
		# Praia dos Caranguejos: o eremita se fecha na concha; o da areia dá o bote saltando
		{"id": "mob_shell_hide", "name": "Concha", "clip": "block", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 9.0, "radius": 0.0, "startup": 0.3, "active": 0.1, "recovery": 0.3, "icon_color": Color(0.75, 0.55, 0.4),
		 "effects": {"buff": {"id": "shell_hide", "duration": 3, "def_pct": 150}}},
		{"id": "mob_sand_leap", "name": "Bote da Areia", "target": T_DIR, "kind": K_PHYS, "power": 1.3, "cooldown": 7.0, "range": 6.0, "radius": 1.2, "startup": 0.4, "active": 0.12, "recovery": 0.45, "hit_stop_frames": 3, "icon_color": Color(0.9, 0.8, 0.5),
		 "effects": {"dash": 5.5}},
		{"id": "mob_crystal_ward", "name": "Escudo de Cristal", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 18.0, "radius": 0.0, "startup": 0.6, "active": 0.1, "recovery": 0.4, "icon_color": Color(0.55, 0.85, 1.0),
		 "effects": {"buff": {"id": "crystal_ward", "duration": 6, "def_pct": 50}}},
		# chefes da faixa 10-20 (Floresta, Ninho, Coração da Árvore, Trono do Conde)
		# linha dos fora-da-lei (Floresta): funda, facada pelas costas, laço e porrete
		{"id": "mob_sling_stone", "name": "Pedrada", "clip": "atk_throw", "target": T_TARGET, "kind": K_PHYS, "power": 0.9, "cooldown": 6.0, "range": 8.0, "radius": 0.0, "max_targets": 1, "startup": 0.4, "active": 0.1, "recovery": 0.4, "hit_stop_frames": 2, "icon_color": Color(0.7, 0.65, 0.55),
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
		{"id": "mob_raise_brood", "name": "Ninhada", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 14.0, "radius": 8.0, "startup": 0.9, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.85, 0.82, 0.6),
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
		# ---- chefes: ganchos, saltos na retaguarda, chuvas avisadas no chão e lacaios no ritmo da recarga ----
		{"id": "mob_bone_hook", "name": "Gancho de Ossos", "clip": "atk_throw", "target": T_TARGET, "kind": K_PHYS, "power": 0.8, "cooldown": 11.0, "range": 15.0, "radius": 0.0, "max_targets": 1, "startup": 0.55, "active": 0.1, "recovery": 0.45, "hit_stop_frames": 3, "icon_color": Color(0.9, 0.85, 0.7), "mob_pick": "far",
		 "effects": {"pull": {"gap": 0.6}, "stun": {"duration": 0.5}}},
		{"id": "mob_thorn_hook", "name": "Laço de Espinhos", "clip": "atk_throw", "target": T_TARGET, "kind": K_PHYS, "power": 0.7, "cooldown": 12.0, "range": 15.0, "radius": 0.0, "max_targets": 1, "startup": 0.55, "active": 0.1, "recovery": 0.45, "hit_stop_frames": 3, "icon_color": Color(0.45, 0.75, 0.35), "mob_pick": "far",
		 "effects": {"pull": {"gap": 0.6}, "root": {"duration": 0.8}}},
		{"id": "mob_rot_hook", "name": "Língua Podre", "clip": "atk_throw", "target": T_TARGET, "kind": K_PHYS, "power": 0.5, "cooldown": 14.0, "range": 14.0, "radius": 0.0, "max_targets": 1, "startup": 0.55, "active": 0.1, "recovery": 0.45, "hit_stop_frames": 3, "icon_color": Color(0.55, 0.8, 0.3), "mob_pick": "far",
		 "effects": {"pull": {"gap": 0.6}, "stun": {"duration": 0.4}, "dot": {"dps": 6, "duration": 4}}},
		{"id": "mob_web_pull", "name": "Fio da Rainha", "clip": "atk_throw", "target": T_TARGET, "kind": K_PHYS, "power": 0.7, "cooldown": 11.0, "range": 15.0, "radius": 0.0, "max_targets": 1, "startup": 0.55, "active": 0.1, "recovery": 0.45, "hit_stop_frames": 3, "icon_color": Color(0.85, 0.85, 0.9), "mob_pick": "far", "vfx": "poison",
		 "effects": {"pull": {"gap": 0.6}, "slow": {"pct": 40, "duration": 3}}},
		{"id": "mob_grapple_hook", "name": "Arpéu", "clip": "atk_throw", "target": T_TARGET, "kind": K_PHYS, "power": 0.8, "cooldown": 12.0, "range": 14.0, "radius": 0.0, "max_targets": 1, "startup": 0.5, "active": 0.1, "recovery": 0.45, "hit_stop_frames": 3, "icon_color": Color(0.7, 0.6, 0.5), "mob_pick": "far", "vfx": "physical",
		 "effects": {"pull": {"gap": 0.6}, "stun": {"duration": 0.4}}},
		{"id": "mob_tusk_rush", "name": "Disparada", "target": T_DIR, "kind": K_PHYS, "power": 1.4, "cooldown": 10.0, "range": 13, "radius": 1.2, "startup": 0.7, "active": 0.15, "recovery": 0.6, "hit_stop_frames": 4, "icon_color": Color(0.8, 0.55, 0.35), "mob_pick": "far", "vfx": "earth",
		 "effects": {"dash": 12.0, "stun": {"duration": 0.6}}},
		{"id": "mob_sky_dive", "name": "Mergulho do Capitão", "target": T_DIR, "kind": K_PHYS, "power": 1.5, "cooldown": 11.0, "range": 14, "radius": 1.8, "startup": 0.7, "active": 0.15, "recovery": 0.6, "hit_stop_frames": 4, "icon_color": Color(0.95, 0.9, 0.7), "mob_pick": "soft", "vfx": "wind",
		 "effects": {"dash": 13.0, "stun": {"duration": 0.5}}},
		{"id": "mob_boulder_barrage", "name": "Chuva de Pedras", "target": T_GROUND, "kind": K_PHYS, "power": 1.3, "cooldown": 13.0, "range": 14.0, "radius": 2.2, "startup": 0.6, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.6, 0.55, 0.45), "mob_pick": "far",
		 "effects": {"barrage": {"count": 4, "radius": 2.2, "delay": 1.4, "spread": 9.0}, "slow": {"pct": 35, "duration": 2}}},
		{"id": "mob_hail_barrage", "name": "Granizo", "target": T_GROUND, "kind": K_MAG, "power": 1.2, "cooldown": 12.0, "range": 14.0, "radius": 2.0, "startup": 0.6, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.7, 0.9, 1.0), "mob_pick": "far",
		 "effects": {"barrage": {"count": 5, "radius": 2.0, "delay": 1.3, "spread": 9.0}, "slow": {"pct": 40, "duration": 2}}},
		{"id": "mob_soul_barrage", "name": "Chuva de Almas", "target": T_GROUND, "kind": K_MAG, "power": 1.2, "cooldown": 13.0, "range": 14.0, "radius": 2.2, "startup": 0.6, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.55, 0.3, 0.75), "mob_pick": "far",
		 "effects": {"barrage": {"count": 4, "radius": 2.2, "delay": 1.3, "spread": 9.0}, "wither": {"pct": 30, "duration": 5}}},
		{"id": "mob_thorn_barrage", "name": "Espinhos do Chão", "target": T_GROUND, "kind": K_MAG, "power": 1.1, "cooldown": 13.0, "range": 14.0, "radius": 2.0, "startup": 0.6, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.5, 0.85, 0.4), "mob_pick": "far",
		 "effects": {"barrage": {"count": 4, "radius": 2.0, "delay": 1.3, "spread": 9.0}, "root": {"duration": 0.8}}},
		# Rainha Aranha com 4+ (MonsterDef.crowd_skills): prende um frágil num casulo que o grupo precisa quebrar (MobSystem.cocoon)
		{"id": "mob_cocoon", "name": "Casulo de Seda", "clip": "atk_throw", "target": T_TARGET, "kind": K_PHYS, "power": 0.3, "cooldown": 13.0, "range": 14.0, "radius": 0.0, "max_targets": 1, "startup": 0.7, "active": 0.1, "recovery": 0.45, "hit_stop_frames": 3, "icon_color": Color(0.92, 0.92, 0.95), "mob_pick": "soft", "vfx": "poison",
		 "effects": {"cocoon": {"id": "web_cocoon"}}},
		{"id": "mob_venom_barrage", "name": "Chuva de Bile", "target": T_GROUND, "kind": K_MAG, "power": 1.0, "cooldown": 12.0, "range": 14.0, "radius": 2.4, "startup": 0.6, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.55, 0.85, 0.25), "mob_pick": "far",
		 "effects": {"barrage": {"count": 4, "radius": 2.4, "delay": 1.4, "spread": 9.0}, "dot": {"dps": 6, "duration": 4}}},
		{"id": "mob_flame_barrage", "name": "Chamas da Cripta", "target": T_GROUND, "kind": K_MAG, "power": 1.2, "cooldown": 12.0, "range": 14.0, "radius": 2.2, "startup": 0.6, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.7, 0.4, 1.0), "mob_pick": "far",
		 "effects": {"barrage": {"count": 4, "radius": 2.2, "delay": 1.3, "spread": 9.0}, "dot": {"dps": 6, "duration": 3}}},
		{"id": "mob_fire_kegs", "name": "Barris de Pólvora", "clip": "atk_throw", "target": T_GROUND, "kind": K_PHYS, "power": 1.4, "cooldown": 14.0, "range": 13.0, "radius": 2.6, "startup": 0.6, "active": 0.1, "recovery": 0.5, "icon_color": Color(1.0, 0.5, 0.2), "mob_pick": "far", "vfx": "fire",
		 "effects": {"barrage": {"count": 3, "radius": 2.6, "delay": 1.6, "spread": 8.0}, "dot": {"dps": 6, "duration": 3}}},
		{"id": "mob_crab_bubbles", "name": "Bolhas do Lago", "target": T_GROUND, "kind": K_MAG, "power": 0.9, "cooldown": 11.0, "range": 14, "radius": 1.8, "startup": 0.6, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.55, 0.8, 1.0), "mob_pick": "far", "vfx": "ice",
		 "effects": {"barrage": {"count": 3, "radius": 1.8, "delay": 1.4, "spread": 7.0}, "slow": {"pct": 35, "duration": 2}}},
		# Mata dos Zumbidos: ferrão com veneno, patada em leque, rugido que retarda (Ursa-Mãe) e o enxame da Colmeia
		{"id": "mob_wasp_sting", "name": "Ferroada", "target": T_DIR, "kind": K_PHYS, "power": 1.1, "cooldown": 7.0, "range": 2.4, "radius": 0.9, "startup": 0.35, "active": 0.1, "recovery": 0.4, "hit_stop_frames": 2, "icon_color": Color(0.75, 0.85, 0.3), "vfx": "poison",
		 "effects": {"dot": {"dps": 4, "duration": 4}}},
		{"id": "mob_bear_swipe", "name": "Patada de Urso", "vfx": "blood", "target": T_CONE, "kind": K_PHYS, "power": 1.5, "cooldown": 8.0, "radius": 2.8, "cone_angle_deg": 90, "startup": 0.6, "active": 0.15, "recovery": 0.55, "hit_stop_frames": 4, "icon_color": Color(0.6, 0.4, 0.25)},
		{"id": "mob_bear_roar", "name": "Rugido da Toca", "vfx": "blood", "target": T_SELF, "kind": K_PHYS, "power": 0.6, "cooldown": 14.0, "radius": 6.0, "startup": 1.0, "active": 0.2, "recovery": 0.6, "hit_stop_frames": 4, "icon_color": Color(0.7, 0.45, 0.3),
		 "effects": {"slow": {"pct": 40, "duration": 3}}},
		# Bosque dos Xamãs: Chamador (bichos fracos, teto 3 vivos somando as três) e o Arquidruida
		{"id": "mob_call_boar", "name": "Chamar Javali", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 14.0, "radius": 10.0, "startup": 0.8, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.6, 0.45, 0.3), "vfx": "nature",
		 "effects": {"boss_summon": {"id": "grove_boar", "count": 1, "max": 3}}},
		{"id": "mob_call_rabbits", "name": "Chamar Coelhos", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 12.0, "radius": 10.0, "startup": 0.8, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.8, 0.75, 0.6), "vfx": "nature",
		 "effects": {"boss_summon": {"id": "grove_rabbit", "count": 2, "max": 3}}},
		{"id": "mob_call_deer", "name": "Chamar Cervo", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 16.0, "radius": 10.0, "startup": 0.8, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.7, 0.5, 0.3), "vfx": "nature",
		 "effects": {"boss_summon": {"id": "grove_deer", "count": 1, "max": 3}}},
		{"id": "mob_call_pack", "name": "Chamar a Matilha", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 28.0, "radius": 0.0, "startup": 0.9, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.5, 0.55, 0.6), "vfx": "summon",
		 "effects": {"boss_summon": {"id": "archdruid_wolf", "count": 2, "max": 4}}},
		{"id": "mob_entangle", "name": "Enlaçar", "target": T_GROUND, "kind": K_MAG, "power": 0.6, "cooldown": 10.0, "range": 14.0, "radius": 2.4, "startup": 1.3, "active": 0.2, "recovery": 0.5, "hit_stop_frames": 3, "icon_color": Color(0.45, 0.7, 0.3), "vfx": "nature", "mob_pick": "random",
		 "effects": {"root": {"duration": 2.5}}},
		{"id": "mob_hive_swarm", "name": "Enxame", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 10.0, "radius": 12.0, "startup": 0.6, "active": 0.1, "recovery": 0.4, "icon_color": Color(0.95, 0.8, 0.25),
		 "effects": {"boss_summon": {"id": "hive_wasp", "count": 2, "max": 4}}},
		{"id": "mob_toxic_rain", "name": "Chuva Ácida", "target": T_GROUND, "kind": K_MAG, "power": 0.9, "cooldown": 12.0, "range": 12.0, "radius": 2.0, "startup": 0.6, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.45, 0.85, 0.5), "mob_pick": "far",
		 "effects": {"barrage": {"count": 3, "radius": 2.0, "delay": 1.4, "spread": 7.0}, "dot": {"dps": 5, "duration": 4}}},
		# lacaios no ritmo da recarga (chefe: invocar vale a qualquer distância; o `max` limita quantos vivem juntos)
		{"id": "mob_call_thugs", "name": "Chamar Capangas", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 26.0, "radius": 0.0, "startup": 0.8, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.75, 0.3, 0.25), "vfx": "summon",
		 "effects": {"boss_summon": {"id": "bandit_thug", "count": 2, "max": 3}}},
		{"id": "mob_raise_spiderlings", "name": "Chocar Ovos", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 22.0, "radius": 0.0, "startup": 0.8, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.6, 0.35, 0.7),
		 "effects": {"boss_summon": {"id": "spiderling", "count": 3, "max": 5}}},
		{"id": "mob_raise_thralls", "name": "Erguer Servos", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 25.0, "radius": 0.0, "startup": 0.9, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.6, 0.45, 0.85),
		 "effects": {"boss_summon": {"id": "crypt_thrall", "count": 2, "max": 4}}},
		{"id": "mob_call_souls", "name": "Chamar Almas", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 24.0, "radius": 0.0, "startup": 0.8, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.7, 0.8, 1.0), "vfx": "summon",
		 "effects": {"boss_summon": {"id": "lost_soul", "count": 2, "max": 3, "pick": "soft"}}},
		{"id": "mob_raise_moss", "name": "Acordar o Musgo", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 24.0, "radius": 0.0, "startup": 0.9, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.45, 0.6, 0.35),
		 "effects": {"boss_summon": {"id": "golem_mossling", "count": 2, "max": 4}}},
		{"id": "mob_raise_shards", "name": "Brotar Lascas", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 24.0, "radius": 0.0, "startup": 0.8, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.5, 0.78, 1.0),
		 "effects": {"boss_summon": {"id": "crystal_shardling", "count": 2, "max": 4}}},
		{"id": "mob_call_lynx", "name": "Chamar a Matilha", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 24.0, "radius": 0.0, "startup": 0.7, "active": 0.1, "recovery": 0.4, "icon_color": Color(0.9, 0.75, 0.4), "vfx": "summon",
		 "effects": {"boss_summon": {"id": "pack_lynx", "count": 2, "max": 5, "pick": "soft"}}},
		{"id": "mob_call_griffins", "name": "Chamar Grifos", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 26.0, "radius": 0.0, "startup": 0.8, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.95, 0.85, 0.55), "vfx": "summon",
		 "effects": {"boss_summon": {"id": "griffin_young", "count": 2, "max": 3, "pick": "far"}}},
		{"id": "mob_call_guard", "name": "Chamar a Guarda Real", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 30.0, "radius": 0.0, "startup": 0.9, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.95, 0.85, 0.4), "vfx": "summon",
		 "effects": {"boss_summon": {"id": "king_guard", "count": 2, "max": 2}}},
		{"id": "mob_raise_fallen", "name": "Erguer os Caídos", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 24.0, "radius": 0.0, "startup": 0.9, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.8, 0.9, 0.75),
		 "effects": {"boss_summon": {"id": "bone_raised", "count": 2, "max": 5}}},
		{"id": "mob_raise_wraiths", "name": "Erguer Espectros", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 26.0, "radius": 0.0, "startup": 0.9, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.6, 0.9, 1.0),
		 "effects": {"boss_summon": {"id": "frost_wraith", "count": 2, "max": 4, "pick": "far"}}},
		# ---- Ato II, a Horda (30-35): goblins, ginetes, orcs e nagas ----
		# Empalador: estocada em linha que atravessa todos no caminho (sem avanço)
		{"id": "mob_impale", "name": "Empalar", "clip": "atk_thrust", "target": T_DIR, "kind": K_PHYS, "power": 1.6, "cooldown": 8.0, "range": 5.5, "radius": 0.9, "startup": 0.6, "active": 0.1, "recovery": 0.5, "hit_stop_frames": 4, "icon_color": Color(0.7, 0.75, 0.45)},
		# Agitador: batida do tambor (empurra o bando a cercar: lentidão em volta)
		{"id": "mob_drum_beat", "name": "Batida de Guerra", "clip": "shout", "target": T_SELF, "kind": K_PHYS, "power": 0.8, "cooldown": 10.0, "radius": 4.0, "startup": 0.7, "active": 0.2, "recovery": 0.5, "hit_stop_frames": 3, "icon_color": Color(0.8, 0.3, 0.2),
		 "effects": {"slow": {"pct": 30, "duration": 2.5}}},
		# Saqueador: rede (projétil visível; prende e, com dano, derruba de quem está montado)
		{"id": "mob_net_throw", "name": "Rede do Saqueador", "clip": "atk_throw", "target": T_TARGET, "kind": K_PHYS, "power": 0.6, "cooldown": 11.0, "range": 9.0, "radius": 0.0, "max_targets": 1, "startup": 0.5, "active": 0.1, "recovery": 0.45, "hit_stop_frames": 2, "icon_color": Color(0.75, 0.65, 0.45), "mob_pick": "soft",
		 "effects": {"root": {"duration": 2.0}}},
		# Recruta Orc: talho largo
		{"id": "mob_orc_chop", "name": "Talho Orc", "target": T_CONE, "kind": K_PHYS, "power": 1.5, "cooldown": 7.0, "radius": 2.8, "cone_angle_deg": 100, "startup": 0.55, "active": 0.15, "recovery": 0.5, "hit_stop_frames": 4, "icon_color": Color(0.5, 0.6, 0.35)},
		# Nagas: puxam para a beira d'água (onde ficam) e golpeiam em linha
		{"id": "mob_tide_pull", "name": "Laço da Maré", "clip": "atk_throw", "target": T_TARGET, "kind": K_MAG, "power": 0.7, "cooldown": 12.0, "range": 10.0, "radius": 0.0, "max_targets": 1, "startup": 0.55, "active": 0.1, "recovery": 0.45, "hit_stop_frames": 3, "icon_color": Color(0.3, 0.8, 0.8), "mob_pick": "far", "vfx": "ice",
		 "effects": {"pull": {"gap": 0.6}, "slow": {"pct": 30, "duration": 2.0}}},
		{"id": "mob_tide_lance", "name": "Lança das Marés", "clip": "atk_thrust", "target": T_DIR, "kind": K_PHYS, "power": 1.7, "cooldown": 7.0, "range": 6.0, "radius": 0.9, "startup": 0.6, "active": 0.1, "recovery": 0.5, "hit_stop_frames": 4, "icon_color": Color(0.35, 0.85, 0.8)},
		# Mãe das Marés: onda em volta, gêiseres avisados e chamar a ninhada
		{"id": "mob_tide_wave", "name": "Onda Quebrada", "clip": "shout", "target": T_SELF, "kind": K_MAG, "power": 1.2, "cooldown": 11.0, "radius": 5.5, "startup": 0.9, "active": 0.2, "recovery": 0.5, "hit_stop_frames": 4, "icon_color": Color(0.35, 0.75, 0.95), "vfx": "ice",
		 "effects": {"slow": {"pct": 40, "duration": 2.5}}},
		{"id": "mob_tide_geysers", "name": "Gêiseres", "clip": "cast_ground", "target": T_GROUND, "kind": K_MAG, "power": 1.1, "cooldown": 13.0, "range": 14.0, "radius": 2.2, "startup": 0.6, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.4, 0.85, 0.95), "mob_pick": "far", "vfx": "ice",
		 "effects": {"barrage": {"count": 4, "radius": 2.2, "delay": 1.4, "spread": 9.0}, "slow": {"pct": 40, "duration": 2.0}}},
		{"id": "mob_call_brood", "name": "Chamar a Ninhada", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 26.0, "radius": 0.0, "startup": 0.8, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.35, 0.8, 0.75), "vfx": "summon",
		 "effects": {"boss_summon": {"id": "naga_spawn", "count": 2, "max": 4, "pick": "soft"}}},
		# Agitador-Mor: tambor que atordoa, chuva de lanças e chamar a turba
		{"id": "mob_war_drum", "name": "Tambor do Agitador", "clip": "shout", "target": T_SELF, "kind": K_PHYS, "power": 1.0, "cooldown": 14.0, "radius": 5.0, "startup": 1.0, "active": 0.2, "recovery": 0.5, "hit_stop_frames": 5, "icon_color": Color(0.85, 0.25, 0.2),
		 "effects": {"stun": {"duration": 0.8}}},
		{"id": "mob_spear_rain", "name": "Chuva de Lanças", "clip": "cast_ground", "target": T_GROUND, "kind": K_PHYS, "power": 1.2, "cooldown": 13.0, "range": 14.0, "radius": 2.0, "startup": 0.6, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.75, 0.7, 0.45), "mob_pick": "far",
		 "effects": {"barrage": {"count": 4, "radius": 2.0, "delay": 1.3, "spread": 9.0}}},
		{"id": "mob_call_rabble", "name": "Chamar a Turba", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 24.0, "radius": 0.0, "startup": 0.8, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.6, 0.7, 0.35), "vfx": "summon",
		 "effects": {"boss_summon": {"id": "goblin_rabble", "count": 3, "max": 5}}},
		# ---- Ato II, a Horda (35-40): trolls, arqueiros, guerreiro orc e os chefes dos acampamentos das Estepes ----
		# Troll: pancada no chão em volta (retarda)
		{"id": "mob_troll_slam", "name": "Pancada de Troll", "target": T_SELF, "kind": K_PHYS, "power": 1.5, "cooldown": 9.0, "radius": 3.4, "startup": 0.8, "active": 0.2, "recovery": 0.6, "hit_stop_frames": 4, "icon_color": Color(0.5, 0.6, 0.7),
		 "effects": {"slow": {"pct": 35, "duration": 2.5}}},
		# Arqueiro/Besteiro: chuva de flechas de fogo em círculos avisados (queima) e virote em linha que atravessa
		{"id": "mob_fire_arrows", "name": "Flechas de Fogo", "target": T_GROUND, "kind": K_PHYS, "power": 0.9, "cooldown": 10.0, "range": 11.0, "radius": 2.0, "startup": 0.6, "active": 0.1, "recovery": 0.5, "icon_color": Color(1.0, 0.5, 0.2), "vfx": "fire",
		 "effects": {"barrage": {"count": 2, "radius": 2.0, "delay": 1.5, "spread": 5.0}, "dot": {"dps": 4, "duration": 3}}},
		{"id": "mob_bolt_pierce", "name": "Virote Perfurante", "clip": "atk_throw", "target": T_DIR, "kind": K_PHYS, "power": 1.3, "cooldown": 10.0, "range": 11.0, "radius": 0.8, "startup": 0.7, "active": 0.1, "recovery": 0.5, "hit_stop_frames": 4, "icon_color": Color(0.75, 0.72, 0.6), "mob_pick": "far"},
		# Guerreiro Orc: grito de guerra (buff do bando da Horda em volta; renova, não soma)
		{"id": "mob_war_cry", "name": "Grito de Guerra", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 18.0, "radius": 6.0, "startup": 0.6, "active": 0.1, "recovery": 0.4, "icon_color": Color(0.85, 0.3, 0.2), "vfx": "blood",
		 "effects": {"rally": {"id": "war_cry", "radius": 9.0, "duration": 8.0, "atk_pct": 15.0, "speed_pct": 10.0}}},
		# Troll Rei-da-Rocha: abalo que atordoa e chamar as crias (a Chuva de Pedras é a mob_boulder_barrage)
		{"id": "mob_rock_quake", "name": "Abalo da Rocha", "clip": "shout", "target": T_SELF, "kind": K_PHYS, "power": 1.3, "cooldown": 13.0, "radius": 5.5, "startup": 1.0, "active": 0.2, "recovery": 0.6, "hit_stop_frames": 5, "icon_color": Color(0.55, 0.6, 0.7), "vfx": "earth",
		 "effects": {"stun": {"duration": 0.8}}},
		{"id": "mob_call_trolls", "name": "Chamar as Crias", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 26.0, "radius": 0.0, "startup": 0.8, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.5, 0.65, 0.75), "vfx": "summon",
		 "effects": {"boss_summon": {"id": "troll_runt", "count": 2, "max": 3}}},
		# Mestre Besteiro: chuva e tempestade de flechas de fogo, chamar os atiradores
		{"id": "mob_fire_rain", "name": "Chuva de Flechas de Fogo", "clip": "cast_ground", "target": T_GROUND, "kind": K_PHYS, "power": 1.2, "cooldown": 11.0, "range": 16.0, "radius": 2.2, "startup": 0.6, "active": 0.1, "recovery": 0.5, "icon_color": Color(1.0, 0.45, 0.15), "mob_pick": "far", "vfx": "fire",
		 "effects": {"barrage": {"count": 5, "radius": 2.2, "delay": 1.4, "spread": 10.0}, "dot": {"dps": 5, "duration": 3}}},
		{"id": "mob_fire_storm", "name": "Tempestade de Fogo", "clip": "cast_ground", "target": T_GROUND, "kind": K_PHYS, "power": 1.4, "cooldown": 17.0, "range": 16.0, "radius": 2.6, "startup": 0.8, "active": 0.1, "recovery": 0.6, "icon_color": Color(1.0, 0.35, 0.1), "mob_pick": "random", "vfx": "fire",
		 "effects": {"barrage": {"count": 6, "radius": 2.6, "delay": 1.7, "spread": 13.0}, "dot": {"dps": 6, "duration": 4}}},
		{"id": "mob_call_marksmen", "name": "Chamar os Atiradores", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 26.0, "radius": 0.0, "startup": 0.8, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.8, 0.5, 0.3), "vfx": "summon",
		 "effects": {"boss_summon": {"id": "orc_marksman", "count": 2, "max": 3, "pick": "far"}}},
		# Senhor da Guerra Ghar: brado (buff do bando), talho largo, terra rachada e chamar a vanguarda
		{"id": "mob_ghar_cry", "name": "Brado de Ghar", "clip": "shout", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 20.0, "radius": 0.0, "startup": 0.8, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.9, 0.25, 0.15), "vfx": "blood",
		 "effects": {"rally": {"id": "war_cry", "radius": 14.0, "duration": 10.0, "atk_pct": 20.0, "speed_pct": 10.0}}},
		{"id": "mob_ghar_cleave", "name": "Talho de Ghar", "clip": "atk_sweep", "target": T_CONE, "kind": K_PHYS, "power": 1.7, "cooldown": 7.0, "radius": 3.6, "cone_angle_deg": 120, "startup": 0.65, "active": 0.15, "recovery": 0.5, "hit_stop_frames": 5, "icon_color": Color(0.6, 0.6, 0.4)},
		{"id": "mob_ghar_quake", "name": "Terra Rachada", "clip": "cast_ground", "target": T_GROUND, "kind": K_PHYS, "power": 1.3, "cooldown": 13.0, "range": 14.0, "radius": 2.4, "startup": 0.6, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.65, 0.5, 0.35), "mob_pick": "far", "vfx": "earth",
		 "effects": {"barrage": {"count": 5, "radius": 2.4, "delay": 1.4, "spread": 10.0}, "slow": {"pct": 40, "duration": 2.0}}},
		{"id": "mob_call_vanguard", "name": "Chamar a Vanguarda", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 26.0, "radius": 0.0, "startup": 0.8, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.6, 0.65, 0.4), "vfx": "summon",
		 "effects": {"boss_summon": {"id": "orc_vanguard", "count": 2, "max": 4}}},
		# ---- Ato II, Monte Kharzun (40-45): estágios de cima da Horda e nativos da montanha ----
		# Assassino Goblin / Matador: passo sombrio (avanço curto, faca envenenada), sumir na fumaça e execução de quem está caído
		{"id": "mob_shadow_step", "name": "Passo Sombrio", "target": T_DIR, "kind": K_PHYS, "power": 1.3, "cooldown": 9.0, "range": 6.0, "radius": 1.0, "startup": 0.4, "active": 0.1, "recovery": 0.5, "hit_stop_frames": 3, "icon_color": Color(0.4, 0.3, 0.5),
		 "effects": {"dash": 5.0, "dot": {"dps": 6, "duration": 4}}},
		{"id": "mob_slayer_vanish", "name": "Sumir na Fumaça", "clip": "shout", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 16.0, "radius": 0.0, "startup": 0.4, "active": 0.1, "recovery": 0.3, "icon_color": Color(0.5, 0.5, 0.55), "vfx": "poison",
		 "effects": {"stealth": 1.5}},
		{"id": "mob_slayer_execute", "name": "Execução do Matador", "target": T_DIR, "kind": K_PHYS, "power": 2.4, "cooldown": 10.0, "range": 5.0, "radius": 1.0, "startup": 0.5, "active": 0.1, "recovery": 0.5, "hit_stop_frames": 5, "icon_color": Color(0.55, 0.2, 0.3), "vfx": "shadow",
		 "effects": {"dash": 4.0, "execute": {}}},
		# Lobo Atroz / Ginete do Lobo Atroz: investida em linha
		{"id": "mob_dire_charge", "name": "Investida Atroz", "target": T_DIR, "kind": K_PHYS, "power": 1.5, "cooldown": 9.0, "range": 8.0, "radius": 1.1, "startup": 0.6, "active": 0.15, "recovery": 0.55, "hit_stop_frames": 4, "icon_color": Color(0.6, 0.6, 0.62), "vfx": "earth",
		 "effects": {"dash": 7.0}},
		# Arco de Fogo: três círculos de brasa avisados (queimam)
		{"id": "mob_ember_volley", "name": "Saraivada de Brasas", "target": T_GROUND, "kind": K_PHYS, "power": 1.0, "cooldown": 10.0, "range": 12.0, "radius": 2.0, "startup": 0.6, "active": 0.1, "recovery": 0.5, "icon_color": Color(1.0, 0.45, 0.15), "vfx": "fire",
		 "effects": {"barrage": {"count": 3, "radius": 2.0, "delay": 1.5, "spread": 6.0}, "dot": {"dps": 5, "duration": 3}}},
		# Senhor da Guerra: talho largo
		{"id": "mob_warlord_cleave", "name": "Talho do Senhor da Guerra", "clip": "atk_sweep", "target": T_CONE, "kind": K_PHYS, "power": 1.6, "cooldown": 8.0, "radius": 3.4, "cone_angle_deg": 130, "startup": 0.6, "active": 0.15, "recovery": 0.5, "hit_stop_frames": 5, "icon_color": Color(0.6, 0.5, 0.35)},
		# Brutamontes: abalo que atordoa (menor que o do Rei-da-Rocha)
		{"id": "mob_brute_quake", "name": "Abalo do Brutamontes", "clip": "shout", "target": T_SELF, "kind": K_PHYS, "power": 1.3, "cooldown": 13.0, "radius": 4.5, "startup": 0.9, "active": 0.2, "recovery": 0.6, "hit_stop_frames": 5, "icon_color": Color(0.45, 0.5, 0.6), "vfx": "earth",
		 "effects": {"stun": {"duration": 0.7}}},
		# Guarda de Clã: golpe de escudo
		{"id": "mob_shield_bash", "name": "Golpe de Escudo-Torre", "target": T_DIR, "kind": K_PHYS, "power": 1.3, "cooldown": 9.0, "range": 2.6, "radius": 1.1, "startup": 0.45, "active": 0.1, "recovery": 0.5, "hit_stop_frames": 4, "icon_color": Color(0.6, 0.4, 0.3), "vfx": "earth",
		 "effects": {"stun": {"duration": 0.5}}},
		# Salamandra de Lava: cuspe de lava em cone (queima)
		{"id": "mob_lava_spit", "name": "Cuspe de Lava", "target": T_CONE, "kind": K_MAG, "power": 1.3, "cooldown": 7.0, "radius": 5.0, "cone_angle_deg": 60, "startup": 0.6, "active": 0.15, "recovery": 0.5, "hit_stop_frames": 3, "icon_color": Color(1.0, 0.4, 0.1), "vfx": "fire",
		 "effects": {"dot": {"dps": 8, "duration": 3}}},
		# Golem de Basalto: pisão em volta (retarda) e fendas de lava avisadas no chão
		{"id": "mob_basalt_stomp", "name": "Pisão de Basalto", "clip": "shout", "target": T_SELF, "kind": K_PHYS, "power": 1.5, "cooldown": 10.0, "radius": 4.0, "startup": 0.9, "active": 0.2, "recovery": 0.6, "hit_stop_frames": 5, "icon_color": Color(0.35, 0.32, 0.35), "vfx": "earth",
		 "effects": {"slow": {"pct": 40, "duration": 2.5}}},
		{"id": "mob_lava_crack", "name": "Fendas de Lava", "clip": "cast_ground", "target": T_GROUND, "kind": K_PHYS, "power": 1.1, "cooldown": 12.0, "range": 11.0, "radius": 2.2, "startup": 0.7, "active": 0.1, "recovery": 0.5, "icon_color": Color(1.0, 0.4, 0.12), "vfx": "fire",
		 "effects": {"barrage": {"count": 3, "radius": 2.2, "delay": 1.5, "spread": 6.0}, "dot": {"dps": 6, "duration": 3}}},
		# ---- Assinaturas dos chefes (design/gdd/act2-boss-signatures.md; regras em BossSignatures; somam ao kit) ----
		# Mãe das Marés — Maré Cheia (3.1): ilhas; quem fica fora leva o golpe e fica lento
		{"id": "mob_tide_flood", "name": "Maré Cheia", "clip": "shout", "target": T_SELF, "kind": K_MAG, "power": 1.6, "cooldown": 30.0, "radius": 0.0, "startup": 0.6, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.3, 0.6, 0.95), "vfx": "ice", "boss_signature": true,
		 "effects": {"islands": {"radius": 2.5, "delay": 3.0, "near_min": 6.0, "near_max": 12.0, "slow": {"pct": 40, "duration": 3.0}, "say": "A maré sobe! Só as pedras ficam secas!"}}},
		# Agitador-Mor Grukk — Rufar da Turba (3.2): canal de 4 s; quebra com atordoar ou 6% da vida
		{"id": "mob_drum_frenzy", "name": "Rufar da Turba", "clip": "shout", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 35.0, "radius": 0.0, "startup": 0.5, "active": 4.0, "recovery": 0.4, "icon_color": Color(0.9, 0.3, 0.15), "vfx": "blood", "boss_signature": true,
		 "effects": {"boss_channel": {"say": "Ouçam o rufar! Quando ele parar, a turba vira TUMULTO!", "warn": "INTERROMPAM O TAMBOR!", "break_say": "O tambor rasgou!", "break_radius": 2.5,
			"on_done": {"buff": {"id": "mob_frenzy", "atk_pct": 40.0, "duration": 12.0}, "radius": 20.0, "heal_pct": 0.3, "summon": {"id": "goblin_rabble", "count": 2, "max": 7}, "say": "TUMULTO!"}}}},
		# Troll Rei-da-Rocha — Avalanche (3.3): onda em volta; quem tem pedregulho entre si e ele não leva (MonsterDef.cover)
		{"id": "mob_troll_avalanche", "name": "Avalanche", "clip": "shout", "target": T_SELF, "kind": K_PHYS, "power": 2.2, "cooldown": 30.0, "radius": 0.0, "startup": 2.5, "active": 0.2, "recovery": 0.8, "hit_stop_frames": 6, "icon_color": Color(0.6, 0.6, 0.66), "vfx": "earth", "boss_signature": true,
		 "effects": {"avalanche": {"radius": 18.0, "stun": 1.0, "guarantee": 2, "near_min": 5.0, "near_max": 9.0}}},
		# Mestre Besteiro Vorgul — Marca do Atirador (3.4): mira que segue a vítima; explode e deixa fogo no chão
		{"id": "mob_marksman_brand", "name": "Marca do Atirador", "clip": "cast_ground", "target": T_SELF, "kind": K_PHYS, "power": 0.9, "cooldown": 18.0, "radius": 0.0, "startup": 0.5, "active": 0.1, "recovery": 0.4, "icon_color": Color(1.0, 0.3, 0.2), "vfx": "fire", "boss_signature": true,
		 "effects": {"mark": {"mode": "spread", "count": 2, "solo_count": 1, "radius": 4.0, "time": 4.0, "linger": 4.0, "tick_power": 0.15, "no_tank": true}}},
		# Senhor da Guerra Ghar — Muralha de Escudos (3.5): frente perde 90% e soma fúria; contragolpe em cone no fim
		{"id": "mob_ghar_wall", "name": "Muralha de Escudos", "clip": "shout", "target": T_SELF, "kind": K_PHYS, "power": 1.0, "cooldown": 25.0, "radius": 0.0, "startup": 0.6, "active": 0.1, "recovery": 0.3, "icon_color": Color(0.9, 0.65, 0.2), "vfx": "earth", "boss_signature": true,
		 "effects": {"wall": {"time": 6.0, "say": "Escudos! Pela frente ninguém passa!", "counter": {"base": 1.0, "step": 0.15, "cap": 2.5, "cone": 150.0, "range": 5.5}}}},
		# Presa-de-Cinza — Três Botes (3.6): 3 investidas seguidas na mesma vítima, re-miradas; root/stun cortam
		{"id": "mob_dire_pounce", "name": "Três Botes", "target": T_DIR, "kind": K_PHYS, "power": 1.2, "cooldown": 20.0, "range": 10.0, "radius": 0.8, "startup": 0.8, "active": 0.15, "recovery": 0.35, "hit_stop_frames": 3, "icon_color": Color(0.7, 0.4, 0.35), "mob_pick": "far", "boss_signature": true,
		 "effects": {"dash": 10.0, "repeat": {"times": 3, "gap": 0.6}}},
		# Mestre Matador Shazka — Sombras Gêmeas (3.7): some na fumaça e volta com 2 cópias (MonsterDef.decoy) que morrem com
		# 1 golpe e soltam veneno; só ele projeta sombra; golpe nele desfaz as cópias
		{"id": "mob_shazka_twins", "name": "Sombras Gêmeas", "clip": "shout", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 24.0, "radius": 0.0, "startup": 0.5, "active": 0.1, "recovery": 0.2, "icon_color": Color(0.3, 0.25, 0.42), "vfx": "shadow", "boss_signature": true,
		 "effects": {"stealth": 1.5, "decoys": {"id": "shazka_decoy", "count": 2, "time": 10.0, "spread": 2.6, "say": "Qual de nós é o mestre?",
			"cloud": {"radius": 2.0, "delay": 0.4, "power": 0.4, "linger": 4.0, "tick_power": 0.15, "dot": {"dps": 10, "duration": 3}}}}},
		# Ulgra Presa-Atroz — Estouro da Matilha (3.8): 3 faixas paralelas de 3 m (uma no tanque), vãos de 3 m, caem 2,0/2,6/3,2 s
		{"id": "mob_ulgra_stampede", "name": "Estouro da Matilha", "clip": "shout", "target": T_GROUND, "kind": K_PHYS, "power": 1.6, "cooldown": 28.0, "range": 40.0, "radius": 1.5, "startup": 0.6, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.6, 0.45, 0.3), "vfx": "earth", "boss_signature": true,
		 "effects": {"barrage": {"shape": "line", "count": 3, "width": 3.0, "gap": 3.0, "length": 30.0, "delay": 2.0, "stagger": 0.6, "say": "A MATILHA INTEIRA! ATROPELEM!"}, "stun": {"duration": 0.8}}},
		# Gorbash Pele-de-Rocha — Ondas da Montanha (3.9): 3 pisadas; cada uma solta 3 anéis de 2 m (até 16 m) que caem a cada 0,5 s
		{"id": "mob_gorbash_waves", "name": "Ondas da Montanha", "clip": "shout", "target": T_SELF, "kind": K_PHYS, "power": 1.1, "cooldown": 24.0, "radius": 0.0, "startup": 0.8, "active": 3.4, "recovery": 0.5, "hit_stop_frames": 4, "icon_color": Color(0.45, 0.5, 0.58), "vfx": "earth", "boss_signature": true,
		 "effects": {"barrage": {"shape": "ring", "count": 3, "width": 2.0, "inner": 2.0, "spacing": 5.0, "delay": 1.5, "stagger": 0.5, "pulses": 3, "pulse_gap": 1.2, "pulse_shift": 2.0, "say": "A MONTANHA ANDA!"}}},
		# ---- Ato II fase 3, chefes de Kharzun (40-45; design/gdd/kharzun-fase3-plan.md §4) ----
		# Presa-de-Cinza: mordida que sangra e uivo que chama as crias
		{"id": "mob_dire_bite", "name": "Mordida da Mãe-Loba", "target": T_CONE, "kind": K_PHYS, "power": 1.6, "cooldown": 6.0, "radius": 2.8, "cone_angle_deg": 80, "startup": 0.45, "active": 0.1, "recovery": 0.45, "hit_stop_frames": 4, "icon_color": Color(0.6, 0.55, 0.5), "vfx": "blood",
		 "effects": {"dot": {"dps": 12, "duration": 4}}},
		{"id": "mob_dire_leap", "name": "Salto da Mãe-Loba", "target": T_DIR, "kind": K_PHYS, "power": 1.4, "cooldown": 10.0, "range": 10.0, "radius": 1.6, "startup": 0.5, "active": 0.15, "recovery": 0.5, "hit_stop_frames": 3, "icon_color": Color(0.55, 0.52, 0.5), "mob_pick": "far",
		 "effects": {"dash": 9.0, "slow": {"pct": 40, "duration": 2}}},
		{"id": "mob_call_apprentices", "name": "Chamar os Aprendizes", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 30.0, "radius": 0.0, "startup": 0.7, "active": 0.1, "recovery": 0.4, "icon_color": Color(0.35, 0.3, 0.45), "vfx": "summon",
		 "effects": {"boss_summon": {"id": "shadow_apprentice", "count": 2, "max": 2, "pick": "soft"}}},
		{"id": "mob_dire_howl", "name": "Uivo da Matilha", "clip": "shout", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 28.0, "radius": 0.0, "startup": 0.8, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.55, 0.55, 0.6), "vfx": "summon",
		 "effects": {"boss_summon": {"id": "dire_pup", "count": 2, "max": 3, "pick": "soft"}}},
		# Shazka: faca envenenada em quem cura, some, reaparece nas costas do frágil, nuvens de veneno e golpe de misericórdia
		{"id": "mob_shazka_knife", "name": "Faca Envenenada", "clip": "atk_throw", "target": T_TARGET, "kind": K_PHYS, "power": 1.0, "cooldown": 9.0, "range": 13.0, "radius": 0.0, "max_targets": 1, "startup": 0.5, "active": 0.1, "recovery": 0.4, "hit_stop_frames": 2, "icon_color": Color(0.5, 0.85, 0.3), "mob_pick": "soft", "vfx": "poison",
		 "effects": {"dot": {"dps": 10, "duration": 4}, "slow": {"pct": 25, "duration": 2.0}}},
		{"id": "mob_shazka_vanish", "name": "Sumir na Fumaça", "clip": "shout", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 18.0, "radius": 0.0, "startup": 0.5, "active": 0.1, "recovery": 0.2, "icon_color": Color(0.35, 0.3, 0.45), "vfx": "shadow",
		 "effects": {"stealth": 1.5}},
		{"id": "mob_shazka_step", "name": "Passo nas Costas", "target": T_DIR, "kind": K_PHYS, "power": 1.6, "cooldown": 18.0, "range": 12.0, "radius": 1.4, "startup": 0.5, "active": 0.15, "recovery": 0.5, "hit_stop_frames": 4, "icon_color": Color(0.4, 0.3, 0.55), "mob_pick": "soft", "vfx": "shadow",
		 "effects": {"dash": 11.0, "stun": {"duration": 0.5}}},
		{"id": "mob_shazka_venom_rain", "name": "Nuvens de Veneno", "clip": "cast_ground", "target": T_GROUND, "kind": K_MAG, "power": 1.1, "cooldown": 13.0, "range": 14.0, "radius": 2.4, "startup": 0.6, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.5, 0.85, 0.3), "mob_pick": "far", "vfx": "poison",
		 "effects": {"barrage": {"count": 4, "radius": 2.4, "delay": 1.4, "spread": 9.0}, "dot": {"dps": 10, "duration": 4}}},
		{"id": "mob_shazka_mercy", "name": "Golpe de Misericórdia", "clip": "atk_thrust", "target": T_TARGET, "kind": K_PHYS, "power": 2.0, "cooldown": 16.0, "range": 3.5, "radius": 0.0, "max_targets": 1, "startup": 0.7, "active": 0.1, "recovery": 0.5, "hit_stop_frames": 6, "icon_color": Color(0.7, 0.2, 0.3), "mob_pick": "soft", "vfx": "shadow"},
		# Ulgra: investida montada, corrente no mais longe, ginetes e chuva de lanças
		{"id": "mob_ulgra_charge", "name": "Investida do Lobo Atroz", "target": T_DIR, "kind": K_PHYS, "power": 1.8, "cooldown": 9.0, "range": 9.0, "radius": 1.3, "startup": 0.6, "active": 0.15, "recovery": 0.6, "hit_stop_frames": 4, "icon_color": Color(0.6, 0.5, 0.4),
		 "effects": {"dash": 9.0, "stun": {"duration": 0.6}}},
		{"id": "mob_ulgra_chain", "name": "Corrente de Caça", "clip": "atk_throw", "target": T_TARGET, "kind": K_PHYS, "power": 0.8, "cooldown": 12.0, "range": 16.0, "radius": 0.0, "max_targets": 1, "startup": 0.6, "active": 0.1, "recovery": 0.45, "hit_stop_frames": 3, "icon_color": Color(0.7, 0.7, 0.72), "mob_pick": "far",
		 "effects": {"pull": {"gap": 0.8}, "root": {"duration": 0.8}}},
		{"id": "mob_call_riders", "name": "Chamar os Ginetes", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 28.0, "radius": 0.0, "startup": 0.8, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.55, 0.5, 0.45), "vfx": "summon",
		 "effects": {"boss_summon": {"id": "ulgra_rider", "count": 2, "max": 3, "pick": "far"}}},
		{"id": "mob_ulgra_spears", "name": "Chuva de Lanças do Clã", "clip": "cast_ground", "target": T_GROUND, "kind": K_PHYS, "power": 1.3, "cooldown": 12.0, "range": 15.0, "radius": 2.2, "startup": 0.6, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.75, 0.7, 0.45), "mob_pick": "far",
		 "effects": {"barrage": {"count": 5, "radius": 2.2, "delay": 1.3, "spread": 10.0}}},
		# Gorbash: xamãs que curam o chefe (e o Estandarte da Pedra do Durgash)
		{"id": "mob_stone_mend", "name": "Canto da Pedra", "clip": "shout", "target": T_SELF, "kind": K_HEAL, "power": 1.0, "cooldown": 6.0, "radius": 16.0, "startup": 0.8, "active": 0.1, "recovery": 0.4, "icon_color": Color(0.5, 0.75, 0.6), "vfx": "nature"},
		{"id": "mob_call_shamans", "name": "Chamar os Xamãs", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 30.0, "radius": 0.0, "startup": 0.8, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.5, 0.62, 0.6), "vfx": "summon",
		 "effects": {"boss_summon": {"id": "stone_shaman", "count": 2, "max": 2}}},
		# Kragmar: martelo largo, ondas de lava (círculos avisados) e golens do molde
		{"id": "mob_kragmar_hammer", "name": "Martelo Negro", "clip": "atk_sweep", "target": T_CONE, "kind": K_PHYS, "power": 1.8, "cooldown": 7.0, "radius": 3.6, "cone_angle_deg": 110, "startup": 0.7, "active": 0.15, "recovery": 0.5, "hit_stop_frames": 5, "icon_color": Color(0.3, 0.28, 0.26),
		 "effects": {"stun": {"duration": 0.4}}},
		{"id": "mob_lava_waves", "name": "Ondas de Lava", "clip": "cast_ground", "target": T_GROUND, "kind": K_PHYS, "power": 1.2, "cooldown": 12.0, "range": 15.0, "radius": 2.4, "startup": 0.6, "active": 0.1, "recovery": 0.5, "icon_color": Color(1.0, 0.45, 0.1), "mob_pick": "random", "vfx": "fire",
		 "effects": {"barrage": {"count": 6, "radius": 2.4, "delay": 1.5, "spread": 12.0}, "dot": {"dps": 10, "duration": 3}}},
		# Kragmar — Têmpera na Lava (GDD act2-boss-signatures 3.10): círculo embaixo dele vira poça por 20 s; dentro
		# delas ele ganha Têmpera (+dano, cura); o tanque tem de arrastá-lo para fora (BossSignatures._empower)
		{"id": "mob_kragmar_temper", "name": "Têmpera na Lava", "clip": "cast_ground", "target": T_SELF, "kind": K_PHYS, "power": 1.0, "cooldown": 18.0, "radius": 0.0, "startup": 0.6, "active": 0.1, "recovery": 0.5, "icon_color": Color(1.0, 0.38, 0.08), "vfx": "fire", "boss_signature": true,
		 "effects": {"barrage": {"count": 1, "radius": 2.4, "delay": 1.6, "spread": 8.0, "on_self": true, "linger": 20.0, "tick_power": 0.15,
			"empower": {"id": "boss_temper"}, "say": "A lava tempera o aço!"}}},
		{"id": "mob_call_forge_golems", "name": "Abrir os Moldes", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 28.0, "radius": 0.0, "startup": 0.8, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.85, 0.42, 0.18), "vfx": "summon",
		 "effects": {"boss_summon": {"id": "forge_golemling", "count": 2, "max": 3}}},
		# Durgash: talho de 150°, investida, machado arremessado, brado, corrente, Terra Rachada e a Guarda do Trono
		{"id": "mob_durgash_cleave", "name": "Talho do Grão-Senhor", "clip": "atk_sweep", "target": T_CONE, "kind": K_PHYS, "power": 1.8, "cooldown": 7.0, "radius": 4.0, "cone_angle_deg": 150, "startup": 0.7, "active": 0.15, "recovery": 0.5, "hit_stop_frames": 5, "icon_color": Color(0.6, 0.55, 0.4)},
		{"id": "mob_durgash_charge", "name": "Avanço do Trono", "target": T_DIR, "kind": K_PHYS, "power": 1.7, "cooldown": 11.0, "range": 8.0, "radius": 1.3, "startup": 0.6, "active": 0.15, "recovery": 0.6, "hit_stop_frames": 4, "icon_color": Color(1, 0.6, 0.3),
		 "effects": {"dash": 8.0, "stun": {"duration": 0.6}}},
		{"id": "mob_durgash_axe", "name": "Machado Arremessado", "clip": "atk_throw", "target": T_TARGET, "kind": K_PHYS, "power": 1.0, "cooldown": 10.0, "range": 16.0, "radius": 0.0, "max_targets": 1, "startup": 0.7, "active": 0.1, "recovery": 0.45, "hit_stop_frames": 4, "icon_color": Color(0.7, 0.65, 0.55), "mob_pick": "far",
		 "effects": {"slow": {"pct": 35, "duration": 2.0}}},
		{"id": "mob_durgash_cry", "name": "Brado do Grão-Senhor", "clip": "shout", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 22.0, "radius": 0.0, "startup": 0.8, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.9, 0.25, 0.15), "vfx": "blood",
		 "effects": {"rally": {"id": "war_cry", "radius": 18.0, "duration": 10.0, "atk_pct": 20.0, "speed_pct": 10.0}}},
		# Durgash — Machado do Trono (GDD act2-boss-signatures 3.11): círculo de 3,5 m segue uma vítima (não o tanque) 5 s;
		# o golpe é dividido por quem está dentro (BossSignatures._land, mode soak). Números em Balance.DURGASH_AXE_*
		{"id": "mob_durgash_throneaxe", "name": "Machado do Trono", "clip": "shout", "target": T_SELF, "kind": K_PHYS, "power": Balance.DURGASH_AXE_POWER, "cooldown": Balance.DURGASH_AXE_EVERY, "radius": 0.0, "startup": 0.6, "active": 0.1, "recovery": 0.4, "hit_stop_frames": 6, "icon_color": Color(0.95, 0.75, 0.3), "vfx": "earth", "boss_signature": true,
		 "effects": {"mark": {"mode": "soak", "count": 1, "solo_count": 1, "radius": Balance.DURGASH_AXE_RADIUS, "time": Balance.DURGASH_AXE_TIME, "no_tank": true, "say": "O Machado do Trono cai! Ajoelhem-se juntos... ou morram sozinhos!"}}},
		{"id": "mob_durgash_chain", "name": "Corrente do Trono", "clip": "atk_throw", "target": T_TARGET, "kind": K_PHYS, "power": 0.9, "cooldown": 13.0, "range": 16.0, "radius": 0.0, "max_targets": 1, "startup": 0.6, "active": 0.1, "recovery": 0.45, "hit_stop_frames": 3, "icon_color": Color(0.7, 0.7, 0.72), "mob_pick": "far",
		 "effects": {"pull": {"gap": 0.8}, "stun": {"duration": 0.5}}},
		{"id": "mob_durgash_quake", "name": "Terra Rachada do Trono", "clip": "cast_ground", "target": T_GROUND, "kind": K_PHYS, "power": 1.3, "cooldown": 12.0, "range": 15.0, "radius": 2.4, "startup": 0.6, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.65, 0.5, 0.35), "mob_pick": "random", "vfx": "earth",
		 "effects": {"barrage": {"count": 6, "radius": 2.4, "delay": 1.4, "spread": 12.0}, "slow": {"pct": 40, "duration": 2.0}}},
		{"id": "mob_call_throne_guard", "name": "Chamar a Guarda do Trono", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 30.0, "radius": 0.0, "startup": 0.9, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.36, 0.42, 0.3), "vfx": "summon",
		 "effects": {"boss_summon": {"id": "throne_guard", "count": 1, "max": 2}}},
		# Estandarte da Forja: brasas em volta (queima quem bate nele de perto)
		{"id": "mob_forge_embers", "name": "Brasas do Clã", "target": T_SELF, "kind": K_MAG, "power": 0.6, "cooldown": 3.0, "radius": 5.0, "startup": 0.3, "active": 0.1, "recovery": 0.3, "icon_color": Color(1.0, 0.45, 0.1), "vfx": "fire",
		 "effects": {"dot": {"dps": 10, "duration": 3}}},
		# ---- Ato III, o Excesso (45-50; design/gdd/ato3-excesso-45-50.md §3, WP3): foliões, demônios do Véu, vinhas ----
		# "Esquivos" sem esquiva (D4 = b): bote/salto (dash), furtividade curta, golpes em sequência (strikes) e atirador que recua (kite).
		# Folião Mascarado: taça arremessada (projétil que retarda)
		{"id": "mob_goblet_throw", "name": "Taça Arremessada", "clip": "atk_throw", "target": T_TARGET, "kind": K_PHYS, "power": 1.1, "cooldown": 7.0, "range": 9.0, "radius": 0.0, "max_targets": 1, "projectile_speed": 16.0, "startup": 0.45, "active": 0.1, "recovery": 0.4, "hit_stop_frames": 2, "icon_color": Color(0.75, 0.25, 0.35), "mob_pick": "far",
		 "effects": {"slow": {"pct": 25, "duration": 2.5}}},
		# Mestre de Cerimônias: brinde (grito do bando) e bastão de sinos em leque. TODO(WP12): buff próprio no lugar de war_cry
		{"id": "mob_toast_rally", "name": "Brinde!", "clip": "shout", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 18.0, "radius": 6.0, "startup": 0.6, "active": 0.1, "recovery": 0.4, "icon_color": Color(0.95, 0.75, 0.35),
		 "effects": {"rally": {"id": "war_cry", "radius": 10.0, "duration": 8.0, "atk_pct": 15.0, "speed_pct": 10.0}}},
		{"id": "mob_bell_staff", "name": "Bastão de Sinos", "clip": "atk_sweep", "target": T_CONE, "kind": K_PHYS, "power": 1.4, "cooldown": 7.0, "radius": 3.0, "cone_angle_deg": 110, "startup": 0.5, "active": 0.15, "recovery": 0.5, "hit_stop_frames": 4, "icon_color": Color(0.9, 0.8, 0.4),
		 "effects": {"slow": {"pct": 20, "duration": 2.0}}},
		# Bailarino do Véu: três talhos de leque em sequência e o Salto Leque (bote de 8 m)
		{"id": "mob_fan_strikes", "name": "Leques em Três Tempos", "target": T_CONE, "kind": K_PHYS, "power": 1.6, "cooldown": 6.0, "radius": 2.6, "cone_angle_deg": 100, "startup": 0.35, "active": 0.4, "recovery": 0.4, "hit_stop_frames": 2, "icon_color": Color(0.95, 0.75, 0.8), "vfx": "blood",
		 "effects": {"strikes": {"weights": [0.3, 0.3, 0.4], "at": [0.0, 0.15, 0.3]}}},
		{"id": "mob_fan_leap", "name": "Salto Leque", "target": T_DIR, "kind": K_PHYS, "power": 1.3, "cooldown": 8.0, "range": 9.0, "radius": 1.4, "startup": 0.45, "active": 0.15, "recovery": 0.5, "hit_stop_frames": 3, "icon_color": Color(0.95, 0.7, 0.75), "mob_pick": "soft", "vfx": "blood",
		 "effects": {"dash": 8.0, "slow": {"pct": 30, "duration": 2}}},
		# Primeiro Bailarino: quatro talhos (o último crítico) e o véu de fitas (some 1,5 s e volta com o salto).
		# O GDD pede `repeat` (R-D) de 3 saltos: a sequência é regra de chefe (BossSignatures só roda em chefe) — aqui o salto tem recarga curta.
		{"id": "mob_first_fan_strikes", "name": "Leques em Quatro Tempos", "target": T_CONE, "kind": K_PHYS, "power": 2.0, "cooldown": 7.0, "radius": 2.8, "cone_angle_deg": 110, "startup": 0.4, "active": 0.5, "recovery": 0.45, "hit_stop_frames": 2, "icon_color": Color(0.95, 0.8, 0.6), "vfx": "blood",
		 "effects": {"strikes": {"weights": [0.2, 0.2, 0.25, 0.35], "at": [0.0, 0.12, 0.24, 0.4], "crit_last": true}}},
		{"id": "mob_first_fan_leap", "name": "Salto Leque do Primeiro Bailarino", "target": T_DIR, "kind": K_PHYS, "power": 1.4, "cooldown": 5.0, "range": 9.0, "radius": 1.5, "startup": 0.45, "active": 0.15, "recovery": 0.45, "hit_stop_frames": 3, "icon_color": Color(0.95, 0.75, 0.6), "mob_pick": "soft", "vfx": "blood",
		 "effects": {"dash": 8.0, "slow": {"pct": 30, "duration": 2}}},
		{"id": "mob_ribbon_vanish", "name": "Véu de Fitas", "clip": "shout", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 14.0, "radius": 5.0, "startup": 0.3, "active": 0.1, "recovery": 0.3, "icon_color": Color(0.9, 0.8, 0.85), "vfx": "wind",
		 "effects": {"stealth": 1.5}},
		# Galgo de Seda: investida curta e mordida que sangra; Galgo Alfa: laço de fita no mais longe
		{"id": "mob_silk_lunge", "name": "Investida de Seda", "target": T_DIR, "kind": K_PHYS, "power": 1.2, "cooldown": 7.0, "range": 7.0, "radius": 1.0, "startup": 0.4, "active": 0.12, "recovery": 0.45, "hit_stop_frames": 3, "icon_color": Color(0.92, 0.88, 0.8), "vfx": "blood",
		 "effects": {"dash": 6.0}},
		{"id": "mob_silk_bite", "name": "Mordida Sangrenta", "target": T_DIR, "kind": K_PHYS, "power": 1.1, "cooldown": 8.0, "range": 2.2, "radius": 1.0, "startup": 0.3, "active": 0.1, "recovery": 0.4, "hit_stop_frames": 3, "icon_color": Color(0.8, 0.25, 0.3), "vfx": "blood",
		 "effects": {"dot": {"dps": 12, "duration": 4}}},
		{"id": "mob_ribbon_lash", "name": "Laço de Fita", "clip": "atk_throw", "target": T_TARGET, "kind": K_PHYS, "power": 0.8, "cooldown": 11.0, "range": 12.0, "radius": 0.0, "max_targets": 1, "startup": 0.55, "active": 0.1, "recovery": 0.45, "hit_stop_frames": 3, "icon_color": Color(0.95, 0.8, 0.45), "mob_pick": "far",
		 "effects": {"pull": {"gap": 0.8}, "slow": {"pct": 30, "duration": 2.0}}},
		# Coro Ferido: Nota Aguda (círculo avisado no alvo, 1,2 s). Maestro: Uníssono = preparo longo de 1,5 s que o atordoar corta
		# (o "canal" R-C é regra de chefe) e estocada da batuta. TODO(WP12): buff próprio no lugar de war_cry
		{"id": "mob_shrill_note", "name": "Nota Aguda", "clip": "cast_ground", "target": T_GROUND, "kind": K_MAG, "power": 1.1, "cooldown": 8.0, "range": 11.0, "radius": 2.2, "startup": 0.5, "active": 0.1, "recovery": 0.45, "icon_color": Color(0.85, 0.75, 1.0), "vfx": "lunar",
		 "effects": {"barrage": {"count": 1, "radius": 2.2, "delay": 1.2, "spread": 0.5}}},
		{"id": "mob_unison", "name": "Uníssono", "clip": "shout", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 20.0, "radius": 8.0, "startup": 1.5, "active": 0.1, "recovery": 0.4, "icon_color": Color(0.8, 0.7, 1.0), "vfx": "lunar",
		 "effects": {"rally": {"id": "unison", "radius": 12.0, "duration": 10.0, "atk_pct": 30.0}}},
		{"id": "mob_baton_thrust", "name": "Estocada da Batuta", "clip": "atk_thrust", "target": T_DIR, "kind": K_PHYS, "power": 1.6, "cooldown": 7.0, "range": 5.0, "radius": 0.9, "startup": 0.5, "active": 0.1, "recovery": 0.45, "hit_stop_frames": 4, "icon_color": Color(0.9, 0.85, 0.95)},
		# Reflexo Vaidoso: some no espelho e volta num lampejo (as cópias R-F são regra de chefe)
		{"id": "mob_mirror_fade", "name": "Sumir no Espelho", "clip": "shout", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 12.0, "radius": 4.0, "startup": 0.3, "active": 0.1, "recovery": 0.3, "icon_color": Color(0.85, 0.88, 0.95), "vfx": "lunar",
		 "effects": {"stealth": 1.2}},
		{"id": "mob_mirror_lunge", "name": "Lampejo do Espelho", "target": T_DIR, "kind": K_PHYS, "power": 1.5, "cooldown": 7.0, "range": 6.0, "radius": 1.0, "startup": 0.4, "active": 0.12, "recovery": 0.45, "hit_stop_frames": 3, "icon_color": Color(0.9, 0.9, 1.0), "vfx": "blood",
		 "effects": {"dash": 5.0}},
		# Incensário Vivo: Fumo Doce (círculos que ficam e pulsam, retardam) e balanço do turíbulo
		{"id": "mob_sweet_smoke", "name": "Fumo Doce", "clip": "cast_ground", "target": T_GROUND, "kind": K_MAG, "power": 0.6, "cooldown": 10.0, "range": 10.0, "radius": 2.6, "startup": 0.6, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.8, 0.65, 0.9), "vfx": "poison",
		 "effects": {"barrage": {"count": 2, "radius": 2.6, "delay": 1.3, "spread": 5.0, "linger": 4.0, "tick_power": 0.15}, "slow": {"pct": 30, "duration": 2.0, "id": "sweet_smoke"}}},
		{"id": "mob_censer_swing", "name": "Balanço do Turíbulo", "target": T_SELF, "kind": K_PHYS, "power": 1.3, "cooldown": 8.0, "radius": 3.2, "startup": 0.6, "active": 0.2, "recovery": 0.5, "hit_stop_frames": 4, "icon_color": Color(0.7, 0.55, 0.3),
		 "effects": {"slow": {"pct": 25, "duration": 2.0}}},
		# Vinha Sedenta: cepa que prende e puxa
		{"id": "mob_vine_grasp", "name": "Cepa Faminta", "clip": "atk_sweep", "target": T_TARGET, "kind": K_PHYS, "power": 0.9, "cooldown": 9.0, "range": 9.0, "radius": 0.0, "max_targets": 1, "startup": 0.55, "active": 0.1, "recovery": 0.45, "hit_stop_frames": 3, "icon_color": Color(0.55, 0.3, 0.55), "mob_pick": "far", "vfx": "nature",
		 "effects": {"pull": {"gap": 0.8}, "root": {"duration": 1.5}}},
		# ---- Veladas (§3.1): sem esquiva (D4); "esquiva" = furtividade, recuo, salto e distância ----
		# Sedutora: some (o golpe seguinte é emboscada × Balance.AMBUSH_MULT), garras em 2 tempos e recua 5 m depois de bater
		{"id": "mob_thirst_vanish", "name": "Véu Baixado", "clip": "shout", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 13.0, "radius": 4.5, "startup": 0.3, "active": 0.1, "recovery": 0.25, "icon_color": Color(0.95, 0.8, 0.85), "vfx": "wind",
		 "effects": {"stealth": 1.5}},
		{"id": "mob_thirst_claws", "name": "Garras em Dois Tempos", "target": T_CONE, "kind": K_PHYS, "power": 1.5, "cooldown": 6.0, "radius": 2.4, "cone_angle_deg": 90, "startup": 0.3, "active": 0.3, "recovery": 0.35, "hit_stop_frames": 2, "icon_color": Color(0.95, 0.72, 0.78), "vfx": "blood",
		 "effects": {"strikes": {"weights": [0.45, 0.55], "at": [0.0, 0.18]}}},
		{"id": "mob_thirst_recoil", "name": "Recuo de Véus", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 9.0, "radius": 2.6, "startup": 0.1, "active": 0.1, "recovery": 0.2, "lock_facing": true, "icon_color": Color(0.92, 0.82, 0.86), "vfx": "wind",
		 "effects": {"dash": -5.0}},
		# Açoitadora: chicote de fita-lâmina (cone longo, sangra) e laço que puxa quem está longe
		{"id": "mob_thirst_whip", "name": "Chicote de Fitas", "clip": "atk_sweep", "target": T_CONE, "kind": K_PHYS, "power": 1.4, "cooldown": 7.0, "radius": 6.0, "cone_angle_deg": 45, "startup": 0.5, "active": 0.12, "recovery": 0.45, "hit_stop_frames": 3, "icon_color": Color(0.85, 0.3, 0.4), "vfx": "blood",
		 "effects": {"dot": {"dps": 14, "duration": 4}}},
		{"id": "mob_thirst_lash", "name": "Laço de Fita", "clip": "atk_throw", "target": T_TARGET, "kind": K_PHYS, "power": 0.8, "cooldown": 11.0, "range": 11.0, "radius": 0.0, "max_targets": 1, "startup": 0.55, "active": 0.1, "recovery": 0.45, "hit_stop_frames": 3, "icon_color": Color(0.9, 0.55, 0.6), "mob_pick": "far", "vfx": "blood",
		 "effects": {"pull": {"gap": 0.8}, "slow": {"pct": 25, "duration": 2.0}}},
		# Carpideira: Lamento (golpe direto que retarda e a cura) e anel avisado em volta dela (R-A ring; dano = vermelho)
		{"id": "mob_veil_lament", "name": "Lamento", "target": T_TARGET, "kind": K_MAG, "power": 1.2, "cooldown": 7.0, "range": 10.0, "radius": 0.0, "max_targets": 1, "startup": 0.5, "active": 0.1, "recovery": 0.4, "icon_color": Color(0.88, 0.75, 0.92), "vfx": "lunar",
		 "effects": {"slow": {"pct": 30, "duration": 2.5}, "heal_pct_of_dmg": 0.5}},
		{"id": "mob_veil_ring", "name": "Anel do Lamento", "clip": "cast_ground", "target": T_SELF, "kind": K_MAG, "power": 1.3, "cooldown": 12.0, "radius": 5.0, "startup": 0.5, "active": 0.1, "recovery": 0.45, "icon_color": Color(0.85, 0.7, 0.95), "vfx": "lunar",
		 "effects": {"barrage": {"shape": "ring", "count": 1, "inner": 1.5, "width": 3.0, "delay": 1.2}}},
		# Matriarca Velada: garras longas, salto em leque e duas faixas avisadas (o `repeat` R-D é regra de chefe: aqui as
		# 2 faixas saem em sequência pelo `stagger` e o salto tem recarga curta, como no Primeiro Bailarino)
		{"id": "mob_matriarch_claws", "name": "Garras da Matriarca", "target": T_CONE, "kind": K_PHYS, "power": 1.9, "cooldown": 7.0, "radius": 2.8, "cone_angle_deg": 110, "startup": 0.4, "active": 0.4, "recovery": 0.45, "hit_stop_frames": 2, "icon_color": Color(0.95, 0.78, 0.6), "vfx": "blood",
		 "effects": {"strikes": {"weights": [0.3, 0.3, 0.4], "at": [0.0, 0.15, 0.3], "crit_last": true}}},
		{"id": "mob_matriarch_leap", "name": "Salto da Matriarca", "target": T_DIR, "kind": K_PHYS, "power": 1.4, "cooldown": 6.0, "range": 9.0, "radius": 1.5, "startup": 0.45, "active": 0.15, "recovery": 0.45, "hit_stop_frames": 3, "icon_color": Color(0.95, 0.75, 0.6), "mob_pick": "soft", "vfx": "blood",
		 "effects": {"dash": 8.0, "slow": {"pct": 30, "duration": 2}}},
		{"id": "mob_matriarch_trail", "name": "Rastro de Véus", "clip": "cast_ground", "target": T_GROUND, "kind": K_PHYS, "power": 1.5, "cooldown": 14.0, "range": 10.0, "radius": 2.0, "startup": 0.5, "active": 0.1, "recovery": 0.45, "icon_color": Color(0.95, 0.7, 0.7), "vfx": "blood",
		 "effects": {"barrage": {"shape": "line", "count": 2, "width": 2.0, "gap": 2.5, "length": 14.0, "delay": 1.4, "stagger": 0.7}}},
		# ---- Ato III, chefes de mundo (WP8a; GDD ato3-excesso-45-50 §4.1, D11: afinados para trio) ----
		# Dona Vindima, a Vinha que Bebe (field_perfume, Poço de Névoa): pisada, chicote que puxa, cachos que caem, brotos e Fumo Doce
		{"id": "mob_vindima_stomp", "name": "Pisada do Lagar", "clip": "atk_sweep", "target": T_CONE, "kind": K_PHYS, "power": 1.6, "cooldown": 7.0, "radius": 3.2, "cone_angle_deg": 100, "startup": 0.55, "active": 0.15, "recovery": 0.5, "hit_stop_frames": 4, "icon_color": Color(0.45, 0.25, 0.4), "vfx": "earth",
		 "effects": {"slow": {"pct": 25, "duration": 2.0}}},
		{"id": "mob_vindima_lash", "name": "Chicote de Vinha", "clip": "atk_throw", "target": T_TARGET, "kind": K_PHYS, "power": 1.0, "cooldown": 11.0, "range": 12.0, "radius": 0.0, "max_targets": 1, "startup": 0.55, "active": 0.1, "recovery": 0.45, "hit_stop_frames": 3, "icon_color": Color(0.5, 0.28, 0.5), "mob_pick": "far", "vfx": "nature",
		 "effects": {"pull": {"gap": 0.8}, "slow": {"pct": 30, "duration": 2.0}}},
		{"id": "mob_vindima_grapes", "name": "Cachos Maduros", "clip": "cast_ground", "target": T_GROUND, "kind": K_PHYS, "power": 1.2, "cooldown": 12.0, "range": 14.0, "radius": 2.4, "startup": 0.6, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.55, 0.22, 0.45), "mob_pick": "random", "vfx": "poison",
		 "effects": {"barrage": {"count": 3, "radius": 2.4, "delay": 1.4, "spread": 9.0}, "slow": {"pct": 30, "duration": 2.0}}},
		{"id": "mob_vindima_sprouts", "name": "Brotos Sedentos", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 22.0, "radius": 0.0, "startup": 0.8, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.42, 0.2, 0.4), "vfx": "summon",
		 "effects": {"boss_summon": {"id": "vine_sprout", "count": 2, "max": 3, "pick": "soft"}}},
		{"id": "mob_vindima_smoke", "name": "Fumo Doce do Poço", "clip": "cast_ground", "target": T_GROUND, "kind": K_MAG, "power": 0.7, "cooldown": 11.0, "range": 12.0, "radius": 2.6, "startup": 0.6, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.8, 0.65, 0.9), "mob_pick": "random", "vfx": "poison",
		 "effects": {"barrage": {"count": 3, "radius": 2.6, "delay": 1.3, "spread": 7.0, "linger": 4.0, "tick_power": 0.15}, "slow": {"pct": 30, "duration": 2.0}}},
		# Dona Vindima — Prensa (assinatura, verbo "sair do centro"): puxa todos a até 14 m e esmaga um círculo de 6 m em volta dela
		# 1,5 s depois (R-A circle on_self + `pull` antes do círculo, BossSignatures.pull_in). Números em Balance.ACT3_PRESS_*
		{"id": "mob_vindima_press", "name": "Prensa", "clip": "shout", "target": T_SELF, "kind": K_PHYS, "power": Balance.ACT3_PRESS_POWER, "cooldown": Balance.ACT3_PRESS_EVERY, "radius": 0.0, "startup": 0.6, "active": 0.1, "recovery": 0.5, "hit_stop_frames": 6, "icon_color": Color(0.5, 0.2, 0.42), "vfx": "earth", "boss_signature": true,
		 "effects": {"barrage": {"count": 1, "radius": Balance.ACT3_PRESS_RADIUS, "delay": Balance.ACT3_PRESS_DELAY, "on_self": true, "pull": {"radius": Balance.ACT3_PRESS_PULL_R, "gap": 0.6},
			"say": "Venham para a prensa, meus cachos! Ninguém sai do lagar!"}}},
		# A Prima-Donna do Palco (field_parade, Palco Grande): leque, duas notas agudas, fortíssimo que empurra e o coro
		{"id": "mob_prima_fan", "name": "Leque de Palco", "target": T_CONE, "kind": K_PHYS, "power": 1.5, "cooldown": 7.0, "radius": 2.8, "cone_angle_deg": 90, "startup": 0.45, "active": 0.12, "recovery": 0.45, "hit_stop_frames": 3, "icon_color": Color(0.95, 0.78, 0.82), "vfx": "blood"},
		{"id": "mob_prima_notes", "name": "Duas Notas Agudas", "clip": "cast_ground", "target": T_GROUND, "kind": K_MAG, "power": 1.2, "cooldown": 9.0, "range": 13.0, "radius": 2.2, "startup": 0.5, "active": 0.1, "recovery": 0.45, "icon_color": Color(0.85, 0.75, 1.0), "mob_pick": "random", "vfx": "lunar",
		 "effects": {"barrage": {"count": 2, "radius": 2.2, "delay": 1.2, "spread": 6.0}}},
		{"id": "mob_prima_forte", "name": "Fortíssimo", "clip": "shout", "target": T_SELF, "kind": K_MAG, "power": 1.1, "cooldown": 14.0, "radius": 4.5, "startup": 0.5, "active": 0.1, "recovery": 0.45, "hit_stop_frames": 3, "icon_color": Color(0.9, 0.85, 1.0), "vfx": "wind",
		 "effects": {"knockback": {"dist": 3.0}}},
		{"id": "mob_prima_chorus", "name": "Chamar o Coro", "clip": "summon", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 22.0, "radius": 0.0, "startup": 0.8, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.82, 0.74, 0.9), "vfx": "summon",
		 "effects": {"boss_summon": {"id": "chorister_echo", "count": 2, "max": 3, "pick": "far"}}},
		# A Prima-Donna — Ária em Três Tempos (assinatura, verbo "ritmo"): 3 anéis em volta dela, perto/meio/longe, um a cada
		# 1,2 s (R-A ring com stagger, molde das Ondas da Montanha). Números em Balance.ACT3_ARIA_*
		{"id": "mob_prima_aria", "name": "Ária em Três Tempos", "clip": "shout", "target": T_SELF, "kind": K_MAG, "power": Balance.ACT3_ARIA_POWER, "cooldown": Balance.ACT3_ARIA_EVERY, "radius": 0.0, "startup": 0.6, "active": 2.6, "recovery": 0.5, "hit_stop_frames": 4, "icon_color": Color(0.9, 0.72, 0.95), "vfx": "lunar", "boss_signature": true,
		 "effects": {"barrage": {"shape": "ring", "count": 3, "width": Balance.ACT3_ARIA_WIDTH, "inner": 0.0, "spacing": Balance.ACT3_ARIA_WIDTH, "delay": Balance.ACT3_ARIA_DELAY, "stagger": Balance.ACT3_ARIA_STAGGER,
			"say": "Primeiro tempo... segundo... TERCEIRO!"}}},
		# ---- Ato III, chefe da história e raide (WP8b; GDD ato3-excesso-45-50 §4.1, D8/D9). Números em Balance.ACT3_CORTEGE_*/STAGE_*/THIRST_* ----
		# Vessaline — Cortejo de Lâminas (assinatura, verbo "ler a sequência"): 4 faixas encadeadas em vítimas sorteadas (nunca o
		# tanque), todas desenhadas juntas; ela investe por cada uma quando cai e a cauda de fitas deixa a faixa (BossSignatures.place_cortege)
		{"id": "mob_vess_cortege", "name": "Cortejo de Lâminas", "clip": "shout", "target": T_SELF, "kind": K_PHYS, "power": Balance.ACT3_CORTEGE_POWER, "cooldown": Balance.ACT3_CORTEGE_EVERY, "radius": 0.0, "startup": 0.6, "active": 0.1, "recovery": Balance.ACT3_CORTEGE_DELAY + Balance.ACT3_CORTEGE_STAGGER * (Balance.ACT3_CORTEGE_COUNT - 1), "hit_stop_frames": 4, "icon_color": Color(0.95, 0.85, 0.8), "vfx": "blood", "boss_signature": true,
		 "effects": {"barrage": {"shape": "cortege", "count": Balance.ACT3_CORTEGE_COUNT, "length": Balance.ACT3_CORTEGE_LEN, "width": Balance.ACT3_CORTEGE_W, "delay": Balance.ACT3_CORTEGE_DELAY,
			"stagger": Balance.ACT3_CORTEGE_STAGGER, "linger": Balance.ACT3_CORTEGE_LINGER, "tick_power": Balance.ACT3_CORTEGE_TICK, "arena": 19.0, "say": "Um, dois, três, quatro... o cortejo passa por cima!"}}},
		# Vessaline F3 — Palco Seguro: as 4 ilhas do Pavilhão (rift_garden boss_hint.islands); quem fica fora leva o golpe (R-A invert)
		{"id": "mob_vess_stage", "name": "Palco Seguro", "clip": "shout", "target": T_SELF, "kind": K_PHYS, "power": Balance.ACT3_STAGE_POWER, "cooldown": Balance.ACT3_STAGE_EVERY, "radius": 22.0, "startup": 0.6, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.9, 0.86, 0.75), "vfx": "blood",
		 "effects": {"islands": {"radius": Balance.ACT3_STAGE_ISLAND_R, "delay": Balance.ACT3_STAGE_DELAY, "spots": [[7.78, -66.22], [-7.78, -66.22], [-7.78, -81.78], [7.78, -81.78]],
			"slow": {"pct": 40, "duration": 3.0}, "say": "Ao palco! Quem não tem lugar... vira cenário!"}}},
		# O Eco de Amarante — Brinde Dividido (assinatura, verbo "ler juntar × espalhar"): a marca alterna dividir (dourado) e espalhar
		# (roxo) a cada ACT3_THIRST_EVERY s; entre ACT3_THIRST_BOTH_HP as duas juntas (BossSignatures.place_marks, mode "alternate")
		{"id": "mob_echo_thirst", "name": "Brinde Dividido", "clip": "cast_ground", "target": T_SELF, "kind": K_MAG, "power": Balance.ACT3_THIRST_SOAK_POWER, "cooldown": Balance.ACT3_THIRST_EVERY, "radius": 0.0, "startup": 0.5, "active": 0.1, "recovery": 0.4, "hit_stop_frames": 4, "icon_color": Color(0.95, 0.8, 0.45), "vfx": "lunar", "boss_signature": true,
		 "effects": {"mark": {"mode": "alternate", "spread_count": 2, "solo_count": 1, "radius": Balance.ACT3_THIRST_RADIUS, "time": Balance.ACT3_THIRST_TIME, "no_tank": true,
			"soak_power": Balance.ACT3_THIRST_SOAK_POWER, "spread_power": Balance.ACT3_THIRST_SPREAD_POWER, "both_hp": Balance.ACT3_THIRST_BOTH_HP}}},
		# Eco F3: 4 cópias (R-F, como as Sombras Gêmeas) e as ilhas da sala (rift_heart boss_hint.islands)
		{"id": "mob_echo_decoys", "name": "Reflexos do Brinde", "clip": "shout", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 30.0, "radius": 0.0, "startup": 0.5, "active": 0.1, "recovery": 0.2, "icon_color": Color(0.86, 0.84, 0.94), "vfx": "shadow",
		 "effects": {"stealth": 1.5, "decoys": {"id": "echo_decoy", "count": 4, "time": 12.0, "spread": 3.5, "say": "Qual de nós vocês querem provar?"}}},
		{"id": "mob_echo_stage", "name": "Maré de Perfume", "clip": "shout", "target": T_SELF, "kind": K_MAG, "power": Balance.ACT3_STAGE_POWER, "cooldown": Balance.ACT3_STAGE_EVERY, "radius": 22.0, "startup": 0.6, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.82, 0.74, 0.9), "vfx": "lunar",
		 "effects": {"islands": {"radius": Balance.ACT3_STAGE_ISLAND_R, "delay": Balance.ACT3_STAGE_DELAY, "spots": [[0.0, -27.5], [8.66, -12.5], [-8.66, -12.5]],
			"slow": {"pct": 40, "duration": 3.0}, "say": "O perfume sobe! Só as ilhas de mármore ficam limpas!"}}},
		# Pedestais dos Sentidos (Eco F2; parados): Audição = nota em todos a cada ACT3_NOTE_EVERY s, Olfato = Fumo Doce, Paladar = cura
		# o Eco quando ela está a até 14 m (o tanque pode arrastá-la para longe; os outros pedestais ficam a 17+ m e não saram)
		{"id": "mob_sense_note", "name": "Nota do Ouvido", "clip": "shout", "target": T_SELF, "kind": K_MAG, "power": 1.0, "cooldown": Balance.ACT3_NOTE_EVERY, "radius": 24.0, "startup": 0.5, "active": 0.1, "recovery": 0.4, "icon_color": Color(0.85, 0.75, 1.0), "vfx": "lunar"},
		{"id": "mob_sense_smoke", "name": "Fumo do Olfato", "clip": "cast_ground", "target": T_GROUND, "kind": K_MAG, "power": 0.8, "cooldown": 9.0, "range": 24.0, "radius": 2.6, "startup": 0.6, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.8, 0.65, 0.9), "vfx": "poison",
		 "effects": {"barrage": {"count": 2, "radius": 2.6, "delay": 1.5, "spread": 5.0, "linger": 4.0, "tick_power": 0.2}, "slow": {"pct": 30, "duration": 2.0}}},
		{"id": "mob_sense_taste", "name": "Gole do Paladar", "clip": "shout", "target": T_SELF, "kind": K_HEAL, "power": 1.0, "cooldown": 3.0, "radius": 14.0, "startup": 0.4, "active": 0.1, "recovery": 0.3, "icon_color": Color(0.75, 0.25, 0.35), "vfx": "nature"},
		# ---- Ato III, chefes das masmorras (WP8b; GDD ato3-excesso-45-50 §4.1; grupo de 4; números das assinaturas em Balance.ACT3_*) ----
		# Varo Taça-Cheia (dg_cellars): talho com o garrafão, taça no mais longe, barrigada que empurra, Fumo Doce em fileiras (F3)
		{"id": "mob_varo_cleave", "name": "Talho do Garrafão", "clip": "atk_sweep", "target": T_CONE, "kind": K_PHYS, "power": 1.8, "cooldown": 7.0, "radius": 3.4, "cone_angle_deg": 120, "startup": 0.6, "active": 0.15, "recovery": 0.5, "hit_stop_frames": 5, "icon_color": Color(0.5, 0.14, 0.22), "vfx": "blood"},
		{"id": "mob_varo_goblet", "name": "Taça Arremessada do Anfitrião", "clip": "atk_throw", "target": T_TARGET, "kind": K_PHYS, "power": 1.3, "cooldown": 9.0, "range": 16.0, "radius": 0.0, "max_targets": 1, "projectile_speed": 16.0, "startup": 0.5, "active": 0.1, "recovery": 0.4, "hit_stop_frames": 3, "icon_color": Color(0.75, 0.25, 0.35), "mob_pick": "far", "vfx": "blood",
		 "effects": {"slow": {"pct": 30, "duration": 2.0}}},
		{"id": "mob_varo_belly", "name": "Barrigada", "clip": "shout", "target": T_SELF, "kind": K_PHYS, "power": 1.2, "cooldown": 13.0, "radius": 3.5, "startup": 0.5, "active": 0.1, "recovery": 0.45, "hit_stop_frames": 4, "icon_color": Color(0.6, 0.2, 0.25), "vfx": "blood",
		 "effects": {"knockback": {"dist": 3.0}}},
		{"id": "mob_varo_smoke_lines", "name": "Fumo Doce em Fileiras", "clip": "cast_ground", "target": T_GROUND, "kind": K_MAG, "power": 1.1, "cooldown": 14.0, "range": 14.0, "radius": 1.25, "startup": 0.6, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.8, 0.65, 0.9), "mob_pick": "random", "vfx": "poison",
		 "effects": {"barrage": {"shape": "line", "count": 2, "width": 2.5, "gap": 3.0, "length": 16.0, "delay": 1.5, "stagger": 0.6, "linger": 4.0, "tick_power": 0.15}, "slow": {"pct": 30, "duration": 2.0}}},
		# Varo — O Banquete (assinatura, verbo "interromper"; R-C): canal; no fim cura e dá fúria a ele e aos convidados;
		# quebrado (dano ou atordoar) = vulnerável
		{"id": "mob_varo_banquet", "name": "O Banquete", "clip": "cast_channel", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": Balance.ACT3_BANQUET_EVERY, "radius": 0.0, "startup": 0.5, "active": Balance.ACT3_BANQUET_TIME, "recovery": 0.4, "icon_color": Color(0.6, 0.15, 0.25), "vfx": "blood", "boss_signature": true,
		 "effects": {"boss_channel": {"say": "Sirvam o banquete! Quem come comigo não morre de fome!", "warn": "INTERROMPAM O BANQUETE!", "break_say": "A taça... caiu da minha mão!", "break_radius": 2.5,
			"on_break": {"vuln": Balance.ACT3_BANQUET_VULN, "vuln_time": Balance.ACT3_BANQUET_VULN_S, "vuln_id": "banquet_vuln"},
			"on_done": {"self": true, "buff": {"id": "banquet", "atk_pct": Balance.ACT3_BANQUET_ATK, "duration": Balance.ACT3_BANQUET_BUFF_S}, "radius": 24.0, "heal_pct": Balance.ACT3_BANQUET_HEAL, "vfx": "mob_varo_banquet", "say": "Ahhh... mais um prato!"}}}},
		# A Condessa Refletida (dg_mirrors): florete em quatro tempos (o último crítico), Salto Leque, Máscaras (cópias, F2), Chuva de Cacos (F3)
		{"id": "mob_countess_rapier", "name": "Florete em Quatro Tempos", "target": T_CONE, "kind": K_PHYS, "power": 2.0, "cooldown": 7.0, "radius": 2.8, "cone_angle_deg": 70, "startup": 0.45, "active": 0.5, "recovery": 0.45, "hit_stop_frames": 2, "icon_color": Color(0.88, 0.9, 0.98), "vfx": "blood",
		 "effects": {"strikes": {"weights": [0.2, 0.2, 0.25, 0.35], "at": [0.0, 0.12, 0.24, 0.4], "crit_last": true}}},
		{"id": "mob_countess_leap", "name": "Salto Leque da Condessa", "target": T_DIR, "kind": K_PHYS, "power": 1.4, "cooldown": 10.0, "range": 9.0, "radius": 1.5, "startup": 0.45, "active": 0.15, "recovery": 0.45, "hit_stop_frames": 3, "icon_color": Color(0.9, 0.9, 1.0), "mob_pick": "soft", "vfx": "blood",
		 "effects": {"dash": 8.0, "slow": {"pct": 30, "duration": 2}}},
		{"id": "mob_countess_masks", "name": "Máscaras Refletidas", "clip": "shout", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 26.0, "radius": 0.0, "startup": 0.5, "active": 0.1, "recovery": 0.2, "icon_color": Color(0.85, 0.88, 0.96), "vfx": "lunar",
		 "effects": {"stealth": 1.5, "decoys": {"id": "countess_decoy", "count": 3, "time": 10.0, "spread": 3.0, "say": "Qual de nós é a verdadeira? Nenhuma, querida."}}},
		{"id": "mob_countess_shards", "name": "Chuva de Cacos", "clip": "cast_ground", "target": T_GROUND, "kind": K_PHYS, "power": 1.2, "cooldown": 12.0, "range": 15.0, "radius": 2.2, "startup": 0.6, "active": 0.1, "recovery": 0.5, "icon_color": Color(0.85, 0.88, 0.96), "mob_pick": "random", "vfx": "blood",
		 "effects": {"barrage": {"count": 4, "radius": 2.2, "delay": 1.4, "spread": 10.0}, "dot": {"dps": 12, "duration": 3}}},
		# A Condessa — Olhar Que Julga (assinatura, verbo "usar cobertura"; R-E): sobem os Espelhos de Pé nos pontos da sala
		# (MonsterDef.cover + `mirrors` = deslocamentos do boss_hint.cover do JSON), 3 s depois o raio bate em quem não tem
		# espelho entre si e ela; o espelho que protegeu racha
		{"id": "mob_countess_gaze", "name": "Olhar Que Julga", "clip": "shout", "target": T_SELF, "kind": K_MAG, "power": Balance.ACT3_GAZE_POWER, "cooldown": Balance.ACT3_GAZE_EVERY, "radius": 0.0, "startup": Balance.ACT3_GAZE_WARN, "active": 0.2, "recovery": 0.8, "hit_stop_frames": 6, "icon_color": Color(0.9, 0.92, 1.0), "vfx": "lunar", "boss_signature": true,
		 "effects": {"avalanche": {"radius": Balance.ACT3_GAZE_RADIUS, "stun": 0.0, "mirrors": [[-7.97, 4.6], [0.0, -9.2], [7.97, 4.6]], "say": "Olhem para mim. Quem não tiver um espelho... que se julgue."}}},
		# Mestra Ressoa, a Regente (dg_conservatory): estocada da batuta, duas notas agudas, fermata que empurra, Uníssono (F3, anel)
		{"id": "mob_ressoa_baton", "name": "Estocada da Regente", "clip": "atk_thrust", "target": T_DIR, "kind": K_PHYS, "power": 1.8, "cooldown": 7.0, "range": 5.0, "radius": 0.9, "startup": 0.5, "active": 0.1, "recovery": 0.45, "hit_stop_frames": 4, "icon_color": Color(0.9, 0.85, 0.95), "vfx": "blood"},
		{"id": "mob_ressoa_notes", "name": "Notas Agudas da Regente", "clip": "cast_ground", "target": T_GROUND, "kind": K_MAG, "power": 1.2, "cooldown": 9.0, "range": 14.0, "radius": 2.2, "startup": 0.5, "active": 0.1, "recovery": 0.45, "icon_color": Color(0.85, 0.75, 1.0), "mob_pick": "random", "vfx": "lunar",
		 "effects": {"barrage": {"count": 2, "radius": 2.2, "delay": 1.3, "spread": 8.0}}},
		{"id": "mob_ressoa_fermata", "name": "Fermata", "clip": "shout", "target": T_SELF, "kind": K_MAG, "power": 1.1, "cooldown": 14.0, "radius": 4.0, "startup": 0.5, "active": 0.1, "recovery": 0.45, "hit_stop_frames": 3, "icon_color": Color(0.9, 0.85, 1.0), "vfx": "wind",
		 "effects": {"knockback": {"dist": 2.0}}},
		{"id": "mob_ressoa_unison", "name": "Uníssono do Órgão", "clip": "shout", "target": T_SELF, "kind": K_MAG, "power": 1.5, "cooldown": 16.0, "radius": 0.0, "startup": 0.6, "active": 0.1, "recovery": 0.5, "hit_stop_frames": 4, "icon_color": Color(0.8, 0.7, 1.0), "vfx": "lunar",
		 "effects": {"barrage": {"shape": "ring", "count": 1, "inner": 4.0, "width": 5.0, "delay": 1.6, "say": "Todos juntos... UNÍSSONO!"}}},
		# Tubo de Órgão (lacaio parado da Ressoa, F2): uma nota avisada num personagem sorteado
		{"id": "mob_pipe_note", "name": "Nota do Tubo", "clip": "cast_ground", "target": T_GROUND, "kind": K_MAG, "power": 1.0, "cooldown": 10.0, "range": 24.0, "radius": 2.4, "startup": 0.4, "active": 0.1, "recovery": 0.4, "icon_color": Color(0.75, 0.65, 0.4), "mob_pick": "random", "vfx": "lunar",
		 "effects": {"barrage": {"count": 1, "radius": 2.4, "delay": 1.5, "spread": 0.5}}},
		# Mestra Ressoa — Cânone (assinatura, verbo "espalhar"; R-B spread + `touch`): 3 marcas; as que se encostam dobram o dano das duas
		{"id": "mob_ressoa_canon", "name": "Cânone", "clip": "cast_ground", "target": T_SELF, "kind": K_MAG, "power": Balance.ACT3_CANON_POWER, "cooldown": Balance.ACT3_CANON_EVERY, "radius": 0.0, "startup": 0.5, "active": 0.1, "recovery": 0.4, "icon_color": Color(0.8, 0.6, 1.0), "vfx": "lunar", "boss_signature": true,
		 "effects": {"mark": {"mode": "spread", "count": Balance.ACT3_CANON_COUNT, "solo_count": 1, "radius": Balance.ACT3_CANON_RADIUS, "time": Balance.ACT3_CANON_TIME, "touch": Balance.ACT3_CANON_TOUCH, "touch_mult": Balance.ACT3_CANON_TOUCH_MULT, "no_tank": true,
			"say": "Cânone! Cada voz no seu lugar... ou as vozes se somam."}}},
		# ---- elemental que evolui (ascensão do Elementalista): Maior (1) e Ancestral (2) por forma; área x ELEM_STAGE_MULT ----
		{"id": "elem_salamander_spit", "name": "Cuspe da Salamandra", "vfx": "fire", "target": T_CONE, "kind": K_MAG, "power": 1.5, "cooldown": 5.0, "radius": _elem_area(5.0, 1), "cone_angle_deg": 60, "startup": 0.35, "active": 0.15, "recovery": 0.4, "hit_stop_frames": 3, "icon_color": Color(1, 0.45, 0.15),
		 "effects": {"dot": {"dps": 8, "duration": 3}}},
		{"id": "elem_golem_stomp", "name": "Pisão do Golem", "vfx": "ice", "target": T_SELF, "kind": K_MAG, "power": 1.2, "cooldown": 7.0, "radius": _elem_area(3.0, 1), "startup": 0.4, "active": 0.1, "recovery": 0.45, "hit_stop_frames": 4, "icon_color": Color(0.55, 0.85, 1.0),
		 "effects": {"slow": {"pct": 40, "duration": 2.5}, "taunt": {"duration": 2.0}}},
		{"id": "elem_sylph_arc", "name": "Arco do Silfo", "vfx": "lightning", "target": T_TARGET, "kind": K_MAG, "power": 1.3, "cooldown": 5.0, "range": 8.0, "radius": _elem_area(3.0, 1), "max_targets": 4, "startup": 0.3, "active": 0.1, "recovery": 0.35, "hit_stop_frames": 3, "icon_color": Color(0.8, 0.8, 1.0),
		 "effects": {"stun": {"duration": 0.3}}},
		{"id": "elem_ifrit_pyre", "name": "Pira do Ifrit", "vfx": "fire", "target": T_SELF, "kind": K_MAG, "power": 1.8, "cooldown": 9.0, "radius": _elem_area(3.5, 2), "startup": 0.5, "active": 0.15, "recovery": 0.5, "hit_stop_frames": 5, "icon_color": Color(1, 0.35, 0.1),
		 "effects": {"dot": {"dps": 12, "duration": 4}}},
		{"id": "elem_undine_tide", "name": "Maré da Ondina", "description": "Escudo de água nos aliados do dono em volta.", "vfx": "ice", "target": T_SELF, "kind": K_BUFF, "power": 0.0, "cooldown": 14.0, "radius": _elem_area(8.0, 2), "startup": 0.5, "active": 0.1, "recovery": 0.4, "icon_color": Color(0.5, 0.8, 1.0),
		 "effects": {"shield": {"amount_pct_hp": 10, "duration": 6}}},
		{"id": "elem_tempest_chain", "name": "Corrente da Tempestade", "vfx": "lightning", "target": T_TARGET, "kind": K_MAG, "power": 1.6, "cooldown": 6.0, "range": 9.0, "radius": _elem_area(4.0, 2), "max_targets": 6, "startup": 0.3, "active": 0.1, "recovery": 0.35, "hit_stop_frames": 3, "icon_color": Color(0.75, 0.75, 1.0),
		 "effects": {"stun": {"duration": 0.4}}},
	]:
		d["mp_cost"] = 0
		d["mastery"] = _mastery()
		if BOSS_PICK.has(d["id"]):
			d["mob_pick"] = BOSS_PICK[d["id"]]
		if BOSS_RANGE.has(d["id"]):
			d["range"] = BOSS_RANGE[d["id"]]
		out.append(_mk(d))
	for s in out:
		s.vfx = vfx_theme(s)
		if s.class_id == "ranger" and s.target != SkillDef.Target.SELF and (s.requires.has("bow") or s.requires.has("rifle")):
			s.range *= Balance.ARCHER_RANGE_MULT
		if s.class_id == "elementalist":
			s.elements.assign(ELEMENTS.get(s.id, build_element.get(s.build, [])))
		if s.effects.has("dot") and (s.vfx == "fire" or s.elements.has("fire")):     # dano no tempo de fogo = queimadura (número laranja)
			var burn: Dictionary = (s.effects["dot"] as Dictionary).duplicate()
			burn["fire"] = true
			s.effects["dot"] = burn
	return out

## Skills de monstro já existentes que, num CHEFE, miram quem está longe (atirador, curandeiro) em vez do tanque.
## Monstro comum ignora `mob_pick` (MonsterBrain.think), então vale até para skill dividida com o lixo.
const BOSS_PICK := {"mob_shadow_bolt": "far", "mob_frost_shard": "far", "mob_light_beam": "far", "mob_thorn_lash": "far",
	"mob_root_arrow": "far", "mob_blood_mark": "far", "mob_grave_touch": "far", "mob_acid_spit": "far", "mob_snare_shot": "far",
	"mob_sling_stone": "far", "mob_venom_pool": "far", "mob_rot_bile": "far", "mob_boulder_toss": "far", "mob_rockfall": "far",
	"mob_crystal_prison": "far", "mob_blizzard": "far", "mob_arrow_rain": "far", "mob_shadow_bats": "far", "mob_soul_drain": "far",
	"mob_lynx_leap": "soft", "mob_dive": "soft"}
## Alcance maior para skills que só chefes usam (respondem a quem luta de longe).
const BOSS_RANGE := {"mob_blood_mark": 12.0, "mob_grave_touch": 12.0, "mob_acid_spit": 11.0, "mob_rot_bile": 12.0,
	"mob_shadow_bats": 12.0, "mob_venom_pool": 12.0, "mob_arrow_rain": 12.0}

## Elementos das skills do Elementalista: o ramo dá o elemento; as gerais e as combinações dizem aqui.
const ELEMENTALS := ["fire_elemental", "frost_elemental", "storm_elemental"]     # um por vez (o novo substitui)
## Elemental que evolui (ascensão do Elementalista, ElementalSystem): monstro, skill de invocação e nome de cada estágio por forma.
const ELEM_FORMS := ["fire", "frost", "storm"]
const ELEM_MODES := ["attack", "protect", "support"]
const ELEM_MODE_LABELS := {"attack": "atacar", "protect": "proteger", "support": "apoiar"}
const ELEM_FORM_LABELS := {"fire": "fogo", "frost": "gelo", "storm": "raio"}
const ELEM_FORM_MONSTER := {"fire": "fire_elemental", "frost": "frost_elemental", "storm": "storm_elemental"}
const ELEM_FORM_SKILL := {"fire": "ele_summon_fire", "frost": "ele_summon_ice", "storm": "ele_summon_storm"}
const ELEM_STAGE_NAMES := {"fire": ["Elemental de Fogo", "Salamandra", "Ifrit"], "frost": ["Elemental de Gelo", "Golem de Gelo", "Ondina"],
	"storm": ["Elemental de Raio", "Silfo", "Tempestade"]}
const ELEM_STAGE_LABELS := ["Básico", "Maior", "Ancestral"]
## skills que o elemental ganha em cada estágio (somam com as do monstro; o estágio de cima leva as de baixo)
const ELEM_STAGE_SKILLS := {"fire": [[], ["elem_salamander_spit"], ["elem_ifrit_pyre"]], "frost": [[], ["elem_golem_stomp"], ["elem_undine_tide"]],
	"storm": [[], ["elem_sylph_arc"], ["elem_tempest_chain"]]}

static func elem_stage_skills(form: String, stage: int) -> Array:
	var out: Array = []
	var by: Array = ELEM_STAGE_SKILLS.get(form, [])
	for i in range(mini(stage + 1, by.size())):
		out.append_array(by[i])
	return out

## raio de skill do elemental no estágio (Balance.ELEM_STAGE_MULT "area")
static func _elem_area(r: float, stage: int) -> float:
	return snappedf(r * float(Balance.ELEM_STAGE_MULT[stage]["area"]), 0.05)

const ELEMENTS := {"ele_fireball": ["fire"], "ele_spark": ["storm"], "ele_blink": [], "ele_asc_fusion": ["fire", "frost", "storm"],
	"ele_firestorm": ["fire", "storm"], "ele_frost_flare": ["fire", "frost"], "ele_hailstorm": ["frost", "storm"], "ele_prism": ["fire", "frost", "storm"]}

## Tema visual de cada skill (FxManager desenha cor + partículas + forma por tema). Ordem: palavra no id → classe → tipo.
const VFX_THEMES := ["fire", "ice", "lightning", "holy", "lunar", "shadow", "poison", "bone", "nature", "earth", "blood", "wind", "heal", "summon", "physical"]
const VFX_RULES := [
	["summon", ["raise", "golem", "army", "summon"]],
	["lightning", ["prism"]],
	["lunar", ["moonfire", "starfall"]],
	["fire", ["fire", "flame", "combust", "inferno", "phoenix", "meteor", "explosive", "firebreath"]],
	["ice", ["ice", "frost", "glacier", "shatter", "absolute_zero", "blizzard", "hail", "crystal", "shard"]],
	["lightning", ["spark", "chain", "static", "overload", "thunder", "storm_lord", "lightning", "dru_storm"]],
	["wind", ["cyclone", "whirl", "disengage"]],
	["bone", ["bone", "corpse"]],
	["poison", ["toxic", "venom", "paralyze", "plague", "virulence", "poison", "rot", "swarm", "decay", "pandemic", "curse", "smoke"]],
	["shadow", ["shadow", "expose", "ambush", "veil", "dark", "soul", "grim", "harvest", "reap", "death", "drain", "assassinate", "ass_execute"]],
	["blood", ["blood", "rend", "hack", "butcher", "crimson", "fury", "rampage", "frenzy", "savage", "eviscerate", "warcry", "titan", "ber_execute", "decapitate"]],
	["earth", ["earth", "mountain", "stampede", "slam", "overhead", "maul", "splitter", "leap", "pounce", "boulder", "rockfall", "magnet"]],
	["holy", ["shield_throw", "holy", "light", "bless", "consecrate", "judg", "purge", "purify", "smite", "divine", "nova", "angel", "miracle", "sanct", "wrath", "crusad", "zeal", "valor", "exorc", "condemn", "martyr", "prayer", "ward", "hammer", "radiant", "lay_hands", "retribution"]],
	["nature", ["bark", "oak", "thorn", "entangle", "growth", "regrowth", "dru_"]],
]
const VFX_CLASS := {"bishop": "holy", "paladin": "holy", "necromancer": "shadow", "druid": "nature"}

static func vfx_theme(s: SkillDef) -> String:
	if s.vfx != "":
		return s.vfx                 # tema escrito na skill (quando a palavra do id engana)
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

## Skills existentes que saem montadas no Combate Montado (escudo, aura, bênçãos e cura do Paladino; GDD ato2-horda R6.1).
const MOUNTABLE := ["pal_blessed_armor", "pal_shield_wall", "pal_bastion_aura", "pal_divine_shield", "pal_lay_hands",
	"pal_valor", "pal_zeal", "pal_avenging_wrath"]

static func _finish(d: Dictionary, cls_id: String) -> SkillDef:
	d["class_id"] = cls_id
	if d["id"] in MOUNTABLE:
		d["mountable"] = true
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
	"nec_ult_soul_reaping": {"phantom": {"name": "Ceifa Fantasma", "effects": {"dash": Balance.ULT_NUMBERS["nec_ult_soul_reaping"]["phantom_dash"]}},
		"demon": {"name": "Ceifa Infernal", "mult": {"power": Balance.ULT_NUMBERS["nec_ult_soul_reaping"]["demon"]}}},     # Suprema do Ceifador
	"dru_maul": {"bear": {"name": "Patada do Urso", "mult": {"radius": 1.3, "power": 1.15}, "set": {"cone_angle_deg": 140.0}}},
	"dru_bellow": {"bear": {"name": "Rugido do Urso", "mult": {"radius": 1.3}}},
	"dru_lacerate": {"bear": {"name": "Garra Laceradora", "mult": {"power": 1.15}, "set": {"radius": 2.2, "max_targets": 3}}},
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
## Forma Ancestral (Druida ascendido, DruidAscension): variantes do Ent, do Lobo Alfa e do Pássaro Arcano. Entram em
## conta de `form_variants`; skill sem entrada aqui usa a variante da forma de base (Balance.ANC_FORM_BASE). Cura das penas e
## empurrão da rajada: Balance.ANC_FEATHER_HEAL / ANC_GUST_PUSH.
const ANCESTRAL_MODS := {
	# Ent (Urso): raízes e galhos, áreas maiores, provoca e prende
	"dru_maul": {"ent": {"name": "Golpe de Galho", "mult": {"radius": 1.35, "power": 1.18}, "set": {"cone_angle_deg": 150.0}}},
	"dru_bellow": {"ent": {"name": "Chamado do Bosque", "mult": {"radius": 1.5}}},
	"dru_earth_slam": {"ent": {"name": "Tremor de Raízes", "mult": {"radius": 1.3, "power": 1.15}, "effects": {"stun": {"duration": 0.9}, "root": {"duration": 1.5}}}},
	"dru_stampede": {"ent": {"name": "Marcha do Ent", "mult": {"power": 1.22}, "effects": {"dash": 6.0}}},
	"dru_mountain": {"ent": {"name": "Chuva de Troncos", "mult": {"radius": 1.25, "power": 1.12}}},
	"dru_oak_skin": {"ent": {"name": "Casca Milenar", "effects": {"shield": {"amount_pct_hp": 40, "duration": 8}}}},
	# Lobo Alfa (Lobo): os golpes do lobo, mais fortes
	"dru_claw": {"alpha": {"name": "Mordida do Alfa", "mult": {"startup": 0.7, "power": 1.16}, "effects": {"dot": {"dps": 7, "duration": 4}}}},
	"dru_pounce": {"alpha": {"name": "Salto do Alfa", "mult": {"range": 1.4, "power": 1.2}, "effects": {"dash": 7.0}}},
	"dru_maim": {"alpha": {"name": "Dilacerar do Alfa", "mult": {"power": 1.06}, "effects": {"slow": {"pct": 50, "duration": 2.5}}}},
	"dru_frenzy": {"alpha": {"name": "Uivo da Matilha", "set": {"radius": 8.0}}},
	"dru_rampage": {"alpha": {"name": "Redemoinho do Alfa", "mult": {"radius": 1.25, "startup": 0.8, "power": 1.06}}},
	"dru_savage": {"alpha": {"name": "Bote da Matilha", "mult": {"power": 1.06}, "effects": {"heal_pct_of_dmg": 0.4}}},
	# Pássaro Arcano (Xamã): raio em cadeia, chuva de penas de luz que cura, rajada de vento que empurra
	"dru_thorns": {"bird": {"name": "Pena Cortante", "mult": {"power": 1.08}}},
	"dru_moonfire": {"bird": {"name": "Raio em Cadeia", "set": {"projectile_speed": 0.0}, "effects": {"chain": {"count": 3, "radius": 5.0, "falloff": 0.6}}}},
	"dru_starfall": {"bird": {"name": "Chuva de Penas de Luz", "mult": {"radius": 1.2}, "effects": {"area_heal": {}}}},
	"dru_cyclone": {"bird": {"name": "Rajada de Vento", "mult": {"radius": 1.15}, "effects": {"knockback": {}}}},
	"dru_storm": {"bird": {"name": "Tempestade de Raios", "mult": {"power": 1.06}, "effects": {"chain": {"count": 2, "radius": 5.0, "falloff": 0.5}}}},
}

## Variantes de uma skill por forma: FORM_MODS + ANCESTRAL_MODS (sem a forma de base: isso é de DruidAscension.form_mods).
static func form_variants(skill_id: String) -> Dictionary:
	var out: Dictionary = FORM_MODS.get(skill_id, {})
	var anc: Dictionary = ANCESTRAL_MODS.get(skill_id, {})
	return out.merged(anc) if not anc.is_empty() else out

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
		if k in SkillDef.EFFECT_KEYS:
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

## Duração dos buffs de "ligar e esquecer" no texto (Balance.BUFF_KEEP_S).
static func _keep_s() -> String:
	return "%ds" % int(Balance.BUFF_KEEP_S)

static func _dot(dps: float, dur: float) -> Dictionary:
	return {"dps": dps, "duration": dur}

## Queimadura (dano no tempo de fogo, número laranja) numa skill que não é do tema fogo (martelos de luz do Templário).
static func _burn(dps: float, dur: float) -> Dictionary:
	return {"dps": dps, "duration": dur, "fire": true}

static func _slow(pct: float, dur: float) -> Dictionary:
	return {"pct": pct, "duration": dur}

static func _dur(dur: float) -> Dictionary:
	return {"duration": dur}

## Skills além das 6 originais (14-16 por classe). Agrupadas por build.
static func _more() -> Dictionary:
	return {
	"paladin": [
		_buff("pal_blessed_armor", "Armadura Abençoada", 1, "", [], 10, 18, "+20% DEF por " + _keep_s() + ".", {"id": "blessed_armor", "duration": Balance.BUFF_KEEP_S, "def_pct": 20}),
		_s("pal_purge", "Purgar", 28, "", [], T_SELF, K_MAG, 2.4, 30, 18, "Purga sagrada ao redor: dano e lentidão.", {"radius": 4.0, "slow": _slow(40, 2.5)}),
		# Guardião (espada/maça + escudo)
		_buff("pal_shield_wall", "Muralha de Escudo", 8, "guardiao", ["shield"], 18, 24, "+45% DEF e -20% velocidade por 6s.", {"id": "shield_wall", "duration": 6, "def_pct": 45, "speed_pct": -20}),
		_s("pal_aegis_slam", "Golpe de Égide", 12, "guardiao", ["shield"], T_CONE, K_PHYS, 1.4, 14, 9, "Golpe de escudo em cone que atordoa 0.7s.", {"radius": 2.6, "cone_angle_deg": 100, "stun": _dur(0.7)}),
		_s("pal_retribution", "Retribuição", 24, "guardiao", ["shield"], T_SELF, K_PHYS, 1.9, 26, 16, "Explosão de luz ao redor; cura 30% do dano causado.", {"radius": 3.5, "heal_pct_of_dmg": 0.3}),
		_s("pal_shield_throw", "Escudo Ricochete", 6, "guardiao", ["shield"], T_TARGET, K_PHYS, 1.8, 14, 7,
			"Arremessa o escudo no alvo: ele ricocheteia em até 3 inimigos (15% menos a cada salto), provoca cada um por 3s, interrompe quem está preparando um golpe e volta para a sua mão.",
			{"range": 10.0, "projectile_speed": 24.0, "bounce": {"count": 3, "radius": 6.0, "falloff": 0.85, "taunt": 3.0, "interrupt": 0.5},
			 "startup": 0.2, "recovery": 0.3, "cancel_after": 0.12, "hit_stop_frames": 3,
			 "mastery": _mastery({3: {"bounce": {"count": 4, "radius": 6.0, "falloff": 0.85, "taunt": 3.0, "interrupt": 0.5}},
				5: {"bounce": {"count": 5, "radius": 7.0, "falloff": 0.85, "taunt": 3.5, "interrupt": 0.6}}})}),
		_s("pal_bastion_aura", "Aura do Bastião", 10, "guardiao", ["shield"], T_SELF, K_BUFF, 0.0, 20, 6,
			"Liga/desliga. Você gera 150% mais ameaça, tem +10% DEF e queima com luz quem está a 3.5 m (40% do ATK por segundo); o grupo a 12 m recebe 10% menos dano e +10% DEF.",
			{"buff": {"id": "bastion_aura", "toggle": true, "threat_pct": 150, "def_pct": 10},
			 "aura": {"radius": 12.0, "ally": {"dr_pct": 10, "def_pct": 10}, "pulse": {"radius": 3.5, "power": 0.4}}}),
		# Cruzado: mais golpes de arma de duas mãos
		_s("pal_twin_slash", "Arco Radiante", 2, "cruzado", ["two_handed"], T_CONE, K_PHYS, 1.5, 8, 3, "Varre um arco de luz em leque com a arma de duas mãos: dano e lentidão de 30% por 1,5s em quem for atingido.",
			{"radius": 2.6, "cone_angle_deg": 110, "max_targets": 4, "clip": "atk_sweep", "vfx": "holy", "slow": _slow(30, 1.5)}),
		_s("pal_blade_dance", "Giro do Cruzado", 7, "cruzado", ["two_handed"], T_SELF, K_PHYS, 2.0, 16, 9, "Gira a arma pesada: dano em tudo ao redor.", {"radius": 3.0, "active": 0.3, "clip": "atk_spin", "vfx": "holy"}),
		_s("pal_lunge", "Estocada Sagrada", 11, "cruzado", ["two_handed"], T_DIR, K_PHYS, 1.8, 12, 7, "Avança 4.5m perfurando quem estiver no caminho.", {"range": 5.0, "radius": 0.9, "dash": 4.5}),
		_s("pal_flurry", "Sentença", 17, "cruzado", ["two_handed"], T_TARGET, K_PHYS, 3.0, 20, 10, "Sequência de golpes pesados em um alvo.", {"hit_stop_frames": 5}),
		_buff("pal_valor", "Valor", 22, "cruzado", ["two_handed"], 20, 24, "+30% ATK e +10 crit por 8s.", {"id": "valor", "duration": 8, "atk_pct": 30, "crit": 10}),
		# Cruzado (arma de duas mãos)
		# 3 golpes em sequência (efeito "strikes"): partes 0,55/0,55/0,75 do power (soma = 1,85), o último sempre crítico
		_s("pal_crusader_strike", "Golpe do Cruzado", 4, "cruzado", ["two_handed"], T_CONE, K_PHYS, 1.85, 12, 5,
			"Sequência de 3 golpes com a arma de duas mãos: corte, revés e um golpe de cima que é sempre crítico.",
			{"radius": 3.0, "cone_angle_deg": 120, "startup": 0.16, "active": 0.6, "recovery": 0.3, "cancel_after": 0.1, "hit_stop_frames": 3, "clip": "atk_2h_chain_a", "vfx": "physical",
			 "strikes": {"weights": [0.55, 0.55, 0.75], "at": [0.0, 0.28, 0.6], "crit_last": true, "last_stop": 6, "clips": ["atk_2h_chain_a", "atk_2h_chain_b", "atk_2h_chain_c"]}}),
		# Martelo da Justiça: martelo de luz arremessado (efeito "bounce" de 1 alvo, sem provocar) que atordoa e volta para a mão
		_s("pal_justice_hammer", "Martelo da Justiça", 9, "cruzado", ["two_handed"], T_TARGET, K_PHYS, 3.0, 16, 9,
			"Arremessa um martelo de luz no alvo: dano, atordoa %.1f s e o martelo volta para a sua mão." % Balance.PAL_JUSTICE_STUN,
			{"range": 10.0, "projectile_speed": 24.0, "bounce": {"count": 1, "radius": 0.0, "falloff": 1.0, "taunt": 0.0, "interrupt": 0.0, "stun": Balance.PAL_JUSTICE_STUN},
			 "startup": 0.2, "recovery": 0.3, "cancel_after": 0.12, "hit_stop_frames": 4, "clip": "atk_throw", "vfx": "holy", "icon_color": Color(1.0, 0.88, 0.5)}),
		_s("pal_holy_wave", "Onda Sagrada", 14, "cruzado", ["two_handed"], T_DIR, K_MAG, 1.8, 16, 7, "Onda sagrada que atravessa inimigos.", {"range": 9.0, "radius": 0.8, "projectile_speed": 16.0, "projectile_pierce": true}),
		_buff("pal_zeal", "Zelo", 18, "cruzado", ["two_handed"], 18, 22, "+25% ATK/MATK e +10% velocidade por 10s.", {"id": "zeal", "duration": 10, "atk_pct": 25, "matk_pct": 25, "speed_pct": 10}),
		_s("pal_judgement_blade", "Lâmina do Juízo", 26, "cruzado", ["two_handed"], T_GROUND, K_PHYS, 3.4, 30, 16, "Lâmina gigante de luz no cursor: dano enorme e atordoa 1s.", {"range": 6.0, "radius": 2.5, "stun": _dur(1.0), "hit_stop_frames": 6}),
		# Templário (martelo/maça ou espada + escudo): martelos de luz (dano físico do ATK) com um pouco de fogo sagrado (queimadura do MATK),
		# marca de penitência. Toda skill dele exige escudo, então gasta o Juramento (ShieldSystem.shield_power: +8% por carga).
		_s("pal_wrath_hammer", "Martelo da Ira", 2, "templario", ["shield"], T_GROUND, K_PHYS, 1.8, 8, 3.5,
			"Um martelo de luz cai do céu no cursor: dano em área, atordoa %.1f s e queima com fogo sagrado por 3 s." % Balance.PAL_WRATH_STUN,
			{"range": 8.0, "radius": 1.8, "startup": 0.3, "recovery": 0.2, "cancel_after": 0.12, "hit_stop_frames": 4, "clip": "cast_holy", "vfx": "holy",
			 "dot": _burn(5, 3), "stun": _dur(Balance.PAL_WRATH_STUN), "icon_color": Color(1.0, 0.82, 0.4)}),
		_s("pal_brand", "Marca da Penitência", 7, "templario", ["shield"], T_TARGET, K_PHYS, 1.8, 12, 9, "Golpe que marca o alvo com luz: dano e ele recebe +15% de dano de todos por 6s.", {"range": 8.0, "startup": 0.15, "curse": {"id": "penance", "duration": 6, "taken_pct": 15}}),
		_s("pal_righteous_hammer", "Martelo dos Justos", 13, "templario", ["shield"], T_CONE, K_PHYS, 2.2, 16, 8,
			"Martelada no chão que solta uma onda de luz em leque: dano e queima com fogo sagrado por 3 s. Gasta o Juramento: +8% de dano por carga.",
			{"radius": 4.5, "cone_angle_deg": 70, "startup": 0.25, "recovery": 0.3, "cancel_after": 0.12, "hit_stop_frames": 5, "clip": "atk_finisher", "vfx": "holy",
			 "dot": _burn(7, 3), "icon_color": Color(1.0, 0.75, 0.35)}),
		# Martelos Abençoados (efeito "orbit"): o golpe de lançar bate em volta e deixa 3 martelos girando em você que batem de novo
		# a cada orbit.every s enquanto o buff durar, com o mesmo poder do lançamento (Juramento gasto nele vale para todos os pulsos)
		_s("pal_blessed_hammers", "Martelos Abençoados", 16, "templario", ["shield"], T_SELF, K_PHYS, Balance.PAL_HAMMERS_POWER, 18, 12,
			"Três martelos de luz giram em espiral à sua volta por %.0f s, batendo em quem estiver a %.1f m a cada %.1f s. O Juramento gasto ao lançar vale para todas as batidas." % [Balance.PAL_HAMMERS_TIME, Balance.PAL_HAMMERS_RADIUS, Balance.PAL_HAMMERS_EVERY],
			{"radius": Balance.PAL_HAMMERS_RADIUS, "startup": 0.15, "recovery": 0.2, "cancel_after": 0.1, "hit_stop_frames": 2, "clip": "buff_power", "vfx": "holy",
			 "orbit": {"id": "blessed_hammers", "duration": Balance.PAL_HAMMERS_TIME, "every": Balance.PAL_HAMMERS_EVERY, "count": 3}, "icon_color": Color(1.0, 0.9, 0.55)}),
		_buff("pal_avenging_wrath", "Ira Vingadora", 19, "templario", ["shield"], 20, 24, "+25% ATK, +25% MATK e +8 crit por 10s.", {"id": "avenging_wrath", "duration": 10, "atk_pct": 25, "matk_pct": 25, "crit": 8}),
		# Preenchimento (GDD skills-fill-2026-11-19): chão sagrado que pulsa (efeito "zone") e coluna de luz que salta ("chain")
		_s("pal_hallowed_ground", "Chão Sagrado", 10, "templario", ["shield"], T_GROUND, K_PHYS, 1.0, 16, 12,
			"Finca o martelo no cursor e consagra o chão (3 m) por %.0f s: o golpe queima com fogo sagrado e, a cada %.0f s, quem está dentro leva %d%% do ATK e a queimadura renova; você e os aliados dentro ganham +%d%% DEF." % [
				float(Balance.HALLOWED_ZONE["duration"]), float(Balance.HALLOWED_ZONE["pulse"]), roundi(float(Balance.HALLOWED_ZONE["foe_power"]) * 100.0), int(Balance.HALLOWED_ZONE["ally_buff"]["def_pct"])],
			{"range": 8.0, "radius": 3.0, "startup": 0.25, "recovery": 0.25, "cancel_after": 0.12, "hit_stop_frames": 4, "clip": "cast_holy", "vfx": "holy",
			 "dot": _burn(5, 2), "zone": Balance.HALLOWED_ZONE, "icon_color": Color(1.0, 0.85, 0.45)}),
		_s("pal_dawn_pillar", "Coluna da Alvorada", 22, "templario", ["shield"], T_GROUND, K_PHYS, 2.4, 24, 15,
			"Uma coluna de luz cai no cursor (2,2 m): dano, atordoa 0,5 s e queima por 3 s; a luz salta para mais 2 inimigos a 5 m (metade do dano).",
			{"range": 9.0, "radius": 2.2, "startup": 0.3, "recovery": 0.3, "cancel_after": 0.15, "hit_stop_frames": 5, "clip": "cast_holy", "vfx": "holy",
			 "stun": _dur(0.5), "dot": _burn(6, 3), "chain": {"count": 2, "radius": 5.0, "falloff": 0.5}, "icon_color": Color(1.0, 0.92, 0.6)}),
		_s("pal_sun_strike", "Golpe Solar", 25, "templario", ["shield"], T_CONE, K_PHYS, 4.0, 28, 15, "Golpe de luz solar em leque: dano enorme, atordoa 0.8s e cura 20% do dano.", {"radius": 3.2, "cone_angle_deg": 110, "startup": 0.25, "stun": _dur(0.8), "heal_pct_of_dmg": 0.2, "hit_stop_frames": 6}),
		# Ascensão (35): Combate Montado + Modo Arcano (GDD ato2-horda R6.1, F8, F9b); liberadas pela missão, fora da teia
		_s("pal_mounted_charge", "Carga Montada", Balance.ASC_LEVEL, "", [], T_DIR, K_PHYS, Balance.MOUNT_CHARGE_POWER, 16, Balance.MOUNT_CHARGE_CD,
			"Só montado. O corcel dispara %.1f m em linha reta e atropela todos no caminho; para em parede ou água." % Balance.MOUNT_CHARGE_DIST,
			{"range": Balance.MOUNT_CHARGE_DIST, "radius": 1.2, "dash": Balance.MOUNT_CHARGE_DIST, "startup": 0.2, "active": 0.15, "recovery": 0.3,
			 "cancel_after": 0.12, "hit_stop_frames": 4, "mountable": true, "mount_only": true, "ascension": true, "clip": "atk_thrust", "vfx": "holy",
			 "icon_color": Color(1, 0.85, 0.45)}),
		_s("pal_trample", "Pisotear", Balance.ASC_LEVEL, "", [], T_SELF, K_PHYS, float(Balance.MOUNT_TRAMPLE["power"]), 12, float(Balance.MOUNT_TRAMPLE["cd"]),
			"Só montado. O corcel empina e pisoteia em volta (%.1f m): dano e lentidão de %d%% por %.0f s." % [float(Balance.MOUNT_TRAMPLE["radius"]), int(Balance.MOUNT_TRAMPLE["slow_pct"]), float(Balance.MOUNT_TRAMPLE["slow_time"])],
			{"radius": float(Balance.MOUNT_TRAMPLE["radius"]), "startup": 0.18, "active": 0.1, "recovery": 0.3, "cancel_after": 0.12, "hit_stop_frames": 3,
			 "slow": _slow(float(Balance.MOUNT_TRAMPLE["slow_pct"]), float(Balance.MOUNT_TRAMPLE["slow_time"])),
			 "mountable": true, "mount_only": true, "ascension": true, "clip": "atk_finisher", "vfx": "earth", "icon_color": Color(0.85, 0.7, 0.45)}),
		_s("pal_arcane_mode", "Modo Arcano", Balance.ASC_LEVEL, "", [], T_SELF, K_BUFF, 0.0, 10, Balance.ARCANE_TOGGLE_CD,
			"Liga/desliga. Asas de luz brotam nas costas: +%d%% de dano e +%d%% DEF/MDEF enquanto durar a MP (%.0f MP/s e metade da regeneração). Ao ligar, uma rajada de penas fere e empurra quem está a %.0f m. Montado, desce do cavalo. Desligar (ou ficar sem MP) dá %.0f s de recarga." % [
				int(Balance.ARCANE_WINGS["atk_pct"]), int(Balance.ARCANE_WINGS["def_pct"]), Balance.ARCANE_MP_PER_S, float(Balance.ARCANE_BURST["radius"]), Balance.ARCANE_CD],
			{"buff": ({"id": "arcane_wings", "toggle": true} as Dictionary).merged(Balance.ARCANE_WINGS), "arcane": {},
			 "startup": 0.2, "active": 0.1, "recovery": 0.25, "ascension": true, "clip": "buff_power", "vfx": "holy", "icon_color": Color(0.75, 0.85, 1)}),
	],
	"berserker": [
		_buff("ber_bloodlust", "Sede de Sangue", 1, "", [], 10, 18, "+15% ATK por 10s.", {"id": "bloodlust", "duration": 10, "atk_pct": 15}),
		# Armas Gêmeas (duas armas de 1 mão)
		_s("ber_hack", "Talho Duplo", 2, "carniceiro", ["dual"], T_TARGET, K_PHYS, 1.7, 8, 3, "Dois talhos com as duas armas: sangramento por 4s (conta como veneno: corta a regeneração do troll).", {"dot": _dot(4, 4)}),
		_s("ber_rend", "Dilacerar", 8, "carniceiro", ["dual"], T_CONE, K_PHYS, 1.4, 12, 7, "Dilacera em cone: sangramento forte (conta como veneno: corta a regeneração do troll).", {"radius": 2.6, "cone_angle_deg": 110, "dot": _dot(6, 5)}),
		_s("ber_axe_storm", "Tempestade de Aço", 13, "carniceiro", ["dual"], T_SELF, K_PHYS, 2.4, 20, 11, "Tempestade de golpes ao redor: tudo sangra por 4s (conta como veneno: corta a regeneração do troll).", {"radius": 3.2, "active": 0.3, "dot": _dot(6, 4)}),
		_s("ber_throw_axe", "Arremesso Brutal", 16, "carniceiro", ["dual"], T_DIR, K_PHYS, 1.9, 14, 8, "Arremessa a arma da mão secundária: dano e lentidão.", {"range": 9.0, "radius": 0.5, "projectile_speed": 18.0, "slow": _slow(35, 2)}),
		_s("ber_butcher", "Carnificina", 24, "carniceiro", ["dual"], T_TARGET, K_PHYS, 3.6, 26, 14, "Golpe brutal em um alvo; cura 25% do dano.", {"heal_pct_of_dmg": 0.25, "hit_stop_frames": 6}),
		# Armas Gêmeas: golpes rápidos
		_s("ber_twin_fang", "Presas Gêmeas", 2, "carniceiro", ["dual"], T_CONE, K_PHYS, 1.45, 8, 3,
			"Dois cortes rápidos em leque que retardam 25%% e mantêm as feridas abertas: seus sangramentos nos atingidos duram +%ds (até %ds)." % [int(Balance.WOUND_EXTEND["add"]), int(Balance.WOUND_EXTEND["cap"])],
			{"radius": 2.6, "cone_angle_deg": 100, "slow": _slow(25, 1.5), "wound_extend": Balance.WOUND_EXTEND, "clip": "atk_flurry", "vfx": "blood"}),
		_s("ber_blade_rush", "Investida de Lâminas", 7, "carniceiro", ["dual"], T_DIR, K_PHYS, 1.6, 12, 7, "Investida de 5m cortando tudo no caminho.", {"range": 5.0, "radius": 0.9, "dash": 5.0}),
		_s("ber_steel_whirl", "Sangria", 12, "carniceiro", ["dual"], T_SELF, K_PHYS, 2.2, 18, 10,
			"Giro dos dois machados ao redor: cura %d%% da vida máxima por inimigo atingido que já sangrava (até %d)." % [int(Balance.WOUND_WHIRL["pct"]), int(Balance.WOUND_WHIRL["max"])],
			{"radius": 3.0, "wound_heal": Balance.WOUND_WHIRL, "vfx": "blood"}),
		_s("ber_crimson_flurry", "Rajada Rubra", 18, "carniceiro", ["dual"], T_TARGET, K_PHYS, 3.2, 22, 11, "Rajada de cortes em um alvo.", {"hit_stop_frames": 5}),
		_s("ber_bladestorm", "Tempestade de Lâminas", 26, "carniceiro", ["dual"], T_SELF, K_PHYS, 3.0, 32, 18, "Dano altíssimo em tudo ao redor.", {"radius": 3.6, "active": 0.4}),
		# Executor (duas mãos)
		_s("ber_overhead", "Golpe Avassalador", 4, "executor", ["two_handed"], T_TARGET, K_PHYS, 2.4, 12, 6, "Golpe vertical que atordoa 0.5s. Gasta a rachadura do alvo: +%d%% de dano por carga." % roundi(float(Balance.SUNDER_CONSUME["per"]) * 100.0),
			{"stun": _dur(0.5), "hit_stop_frames": 6, "sunder_consume": Balance.SUNDER_CONSUME}),
		# Preenchimento (GDD skills-fill-2026-11-19): rachar ("sunder") -> executar ("sunder_consume"); brado de apoio ao grupo
		_s("ber_sunder", "Fender Armadura", 8, "executor", ["two_handed"], T_CONE, K_PHYS, 1.6, 10, 5,
			"Golpe largo que racha a armadura: cada acerto põe 1 carga de rachadura (até %d, %.0f s): +%d%% de dano recebido por carga. Golpe Avassalador, Executar e Decapitar gastam as cargas para bater mais." % [
				int(Balance.SUNDER["max"]), float(Balance.SUNDER["duration"]), int(Balance.SUNDER["taken_per"])],
			{"radius": 2.8, "cone_angle_deg": 100, "startup": 0.22, "recovery": 0.3, "cancel_after": 0.15, "hit_stop_frames": 4, "vfx": "blood",
			 "sunder": Balance.SUNDER, "icon_color": Color(0.85, 0.55, 0.45)}),
		_buff("ber_headsman_roar", "Brado do Carrasco", 22, "executor", ["two_handed"], 22, 30,
			"Brado de guerra: você e os aliados a 8 m ganham +20% DEF e +10% ATK por 10 s e um escudo de 12% da vida por 6 s.",
			{"id": "headsman_roar", "duration": 10, "def_pct": 20, "atk_pct": 10},
			{"radius": 8.0, "shield": {"amount_pct_hp": 12, "duration": 6}, "startup": 0.15, "recovery": 0.2, "clip": "shout", "vfx": "blood"}),
		_s("ber_earthsplitter", "Racha-Terra", 11, "executor", ["two_handed"], T_DIR, K_PHYS, 2.2, 16, 9, "Racha o chão em linha reta: dano e lentidão.", {"range": 7.0, "radius": 1.0, "slow": _slow(40, 2)}),
		_buff("ber_titan_grip", "Pegada de Titã", 17, "executor", ["two_handed"], 18, 24, "+35% ATK e -15% DEF por 10s.", {"id": "titan_grip", "duration": 10, "atk_pct": 35, "def_pct": -15}),
		_s("ber_decapitate", "Decapitar", 28, "executor", ["two_handed"], T_TARGET, K_PHYS, 4.0, 34, 18, "Golpe final devastador em um alvo. Gasta a rachadura: +%d%% de dano por carga." % roundi(float(Balance.SUNDER_CONSUME["per"]) * 100.0),
			{"hit_stop_frames": 7, "sunder_consume": Balance.SUNDER_CONSUME}),
		# Punhos de Fúria (duas garras): muita AGI e esquiva; cada golpe esquivado vira Fúria do Punho e contra-ataque
		# (FistSystem); o Punho Final gasta a Fúria. Monge da fúria: socos, ki em linha, chakra e postura.
		_s("ber_fist_flurry", "Socos Repetidos", 2, "punhos", ["dual_claw"], T_TARGET, K_PHYS, 1.8, 7, 3, "Rajada de socos com as garras em um alvo.",
			{"clip": "atk_flurry", "vfx": "blood", "hit_stop_frames": 3}),
		_s("ber_shockwave", "Onda de Choque", 5, "punhos", ["dual_claw"], T_DIR, K_PHYS, 1.5, 10, 6, "Soco no chão que solta uma onda de ki em linha: atravessa inimigos.",
			{"range": 9.0, "radius": 0.9, "projectile_speed": 16.0, "projectile_pierce": true, "vfx": "holy"}),
		_buff("ber_chakra", "Chakra", 8, "punhos", ["dual_claw"], 0, 16, "Concentra o ki: cura 25% da vida, devolve 15% da mana e +15% DEF por 6s.",
			{"id": "chakra", "duration": 6, "def_pct": 15}, {"heal_pct": 25, "mana_pct": 15, "vfx": "holy"}),
		_s("ber_earth_slash", "Fenda na Terra", 12, "punhos", ["dual_claw"], T_CONE, K_PHYS, 2.0, 14, 8, "Soco que racha o chão em leque até 5m: dano e lentidão.",
			{"radius": 5.0, "cone_angle_deg": 50, "slow": _slow(30, 2), "hit_stop_frames": 4, "vfx": "earth"}),
		_buff("ber_counter_stance", "Postura do Contra-Golpe", 15, "punhos", ["dual_claw"], 14, 20, "+25% de esquiva por 8s: cada golpe esquivado vira Fúria e contra-ataque.",
			{"id": "counter_stance", "duration": 8, "evasion": 25}),
		_s("ber_tiger_pounce", "Bote do Tigre", 18, "punhos", ["dual_claw"], T_DIR, K_PHYS, 2.0, 16, 9, "Avança 6m com as garras: dano e atordoa 0.5s.",
			{"range": 6.0, "radius": 1.0, "dash": 6.0, "stun": _dur(0.5), "vfx": "blood"}),
		_s("ber_final_fist", "Punho Final", 22, "punhos", ["dual_claw"], T_TARGET, K_PHYS, 2.6, 18, 10, "Golpe que gasta toda a Fúria do Punho: +30% de dano por carga.",
			{"fury_spend": {"power_pct": 30}, "hit_stop_frames": 7, "vfx": "blood"}),
		_s("ber_hundred_fists", "Cem Punhos", 27, "punhos", ["dual_claw"], T_SELF, K_PHYS, 3.0, 30, 16, "Tempestade de socos ao redor; se acertar alguém, +2 de Fúria do Punho.",
			{"radius": 3.2, "active": 0.4, "fury_gain": 2, "vfx": "blood"}),
		# Ascensão (35, ProgressionSystem.has_ascension): Empunhadura de Titã e Modo Gladiador (TitanSystem, GladiatorSystem).
		# Fora da teia comum (SkillDef.ascension: teia de ascensão própria), todas as builds. Glória: crítico, abate, Brado.
		_s("ber_titan_cyclone", "Ciclone de Titã", Balance.ASC_LEVEL, "", ["titan", "dual", "dual_claw"], T_SELF, K_PHYS, 0.6, 18, 12,
			"Gira com as duas armas por 2s: 4 giros em tudo a 3 m (com dois machados de duas mãos, cada giro bate com os dois).",
			{"ascension": true, "radius": 3.0, "channel": {"ticks": 4}, "active": 2.0, "startup": 0.15, "recovery": 0.2, "titan_hit": true, "vfx": "wind", "hit_stop_frames": 2}),
		_s("ber_gladiator", "Modo Gladiador", Balance.ASC_LEVEL, "", [], T_SELF, K_BUFF, 0.0, 10, 6,
			"Liga/desliga a postura de arena: +%d%% de dano e %d%% de defesa. Na postura a Fúria vira Glória (até %d): golpe crítico e abate dão 1. Desligar zera a Glória." % [Balance.GLADIATOR_STANCE["atk_pct"], Balance.GLADIATOR_STANCE["def_pct"], Balance.GLORY_MAX],
			{"ascension": true, "buff": Balance.GLADIATOR_STANCE.merged({"id": Balance.GLADIATOR_BUFF, "toggle": true}), "aura": {"radius": 0.0, "ally": {}},
			 "startup": 0.1, "recovery": 0.2, "vfx": "blood"}),
		_s("ber_glad_fire", "Lâmina Ígnea", Balance.ASC_LEVEL, "", ["gladiator"], T_CONE, K_PHYS, Balance.GLADIATOR_BLADE_POWER, 12, 8,
			"Golpe de arena com a arma em chamas (Modo Gladiador): queima por 4s; +%.1f de poder por Glória." % Balance.GLORY_STEP,
			{"ascension": true, "radius": 3.0, "cone_angle_deg": 110, "startup": 0.18, "dot": _dot(8, 4), "glory_scale": true, "titan_hit": true, "vfx": "fire", "hit_stop_frames": 4}),
		_s("ber_glad_frost", "Lâmina Gélida", Balance.ASC_LEVEL, "", ["gladiator"], T_CONE, K_PHYS, Balance.GLADIATOR_BLADE_POWER, 12, 8,
			"Golpe de arena com a arma congelada (Modo Gladiador): lentidão de 40%% e estilhaça quem já está lento; +%.1f de poder por Glória." % Balance.GLORY_STEP,
			{"ascension": true, "radius": 3.0, "cone_angle_deg": 110, "startup": 0.18, "slow": _slow(40, 2.5), "glory_scale": true, "titan_hit": true, "vfx": "ice", "hit_stop_frames": 4}),
		_s("ber_glad_storm", "Lâmina Trovejante", Balance.ASC_LEVEL, "", ["gladiator"], T_DIR, K_PHYS, Balance.GLADIATOR_BLADE_POWER, 12, 8,
			"Estocada de arena com a arma eletrizada (Modo Gladiador): o raio salta para 2 vizinhos; +%.1f de poder por Glória." % Balance.GLORY_STEP,
			{"ascension": true, "range": 4.0, "radius": 1.0, "startup": 0.16, "chain": {"count": 2, "radius": 4.5, "falloff": 0.6}, "glory_scale": true, "titan_hit": true, "vfx": "lightning", "hit_stop_frames": 4}),
		_s("ber_glad_rush", "Investida do Gladiador", Balance.ASC_LEVEL, "", ["gladiator"], T_DIR, K_PHYS, 1.6, 12, 10,
			"Avança 7m (Modo Gladiador) e derruba o primeiro que atingir (atordoa 0.8s).",
			{"ascension": true, "range": 7.0, "radius": 1.0, "dash": 7.0, "max_targets": 1, "stun": _dur(0.8), "startup": 0.12, "vfx": "blood", "hit_stop_frames": 5}),
		_s("ber_arena_shout", "Brado da Arena", Balance.ASC_LEVEL, "", ["gladiator"], T_SELF, K_BUFF, 0.0, 14, 25,
			"Brado para a plateia (Modo Gladiador): provoca os inimigos a 8 m por 2s e dá +1 de Glória por inimigo provocado (até %d)." % Balance.GLORY_SHOUT_MAX,
			{"ascension": true, "radius": 8.0, "taunt": _dur(2.0), "glory_gain": true, "startup": 0.15, "vfx": "blood"}),
		_s("ber_glad_finale", "Golpe Final", Balance.ASC_LEVEL, "", ["glory_full"], T_CONE, K_PHYS, Balance.GLADIATOR_FINALE_POWER, 20, 6,
			"Gasta %d de Glória: golpe com as duas armas em leque de 3 m na frente." % Balance.GLORY_MAX,
			{"ascension": true, "radius": 3.0, "cone_angle_deg": 120, "startup": 0.3, "recovery": 0.4, "glory_spend": true, "titan_hit": true, "clip": "atk_finisher", "vfx": "blood", "hit_stop_frames": 7}),
	],
	"bishop": [
		_s("bis_light", "Luz Sagrada", 1, "", [], T_DIR, K_MAG, 1.2, 6, 1.8, "Pequeno projétil de luz.", {"range": 9.0, "radius": 0.4, "projectile_speed": 20.0}),
		_s("bis_renew", "Renovar", 5, "", [], T_SELF, K_HEAL, 0.9, 10, 5, "Cura rápida em si mesmo.", {"startup": 0.2, "lock_facing": false}),
		_s("bis_holy_nova", "Nova Sagrada", 12, "", [], T_SELF, K_MAG, 1.4, 18, 10, "Explosão de luz ao redor.", {"radius": 3.5}),
		_s("bis_martyr", "Mártir", 24, "", [], T_SELF, K_BUFF, 0.0, 20, 30, "Escudo sagrado de 30% do HP por 6s.", {"shield": {"amount_pct_hp": 30, "duration": 6}}),
		# Sacerdote (orbe ou cajado)
		_s("bis_guardian_light", "Luz Protetora", 3, "sacerdote", ["mace", "shield"], T_TARGET, K_HEAL, 0.8, 14, 8,
			"Cura o aliado sob o cursor (ou você) e o envolve num escudo de 10% da vida dele por 5 s.",
			{"range": 9.0, "startup": 0.2, "recovery": 0.25, "cancel_after": 0.12, "vfx": "holy", "lock_facing": false,
			 "shield": {"amount_pct_hp": 10, "duration": 5}, "icon_color": Color(1.0, 0.95, 0.75)}),
		_s("bis_prayer", "Prece", 8, "sacerdote", ["mace", "shield"], T_SELF, K_HEAL, 1.4, 22, 14, "Cura você e aliados num raio de 6m.", {"radius": 6.0, "startup": 0.35}),
		_buff("bis_ward", "Égide Divina", 13, "sacerdote", ["mace", "shield"], 18, 20, "+25% DEF para você e aliados próximos por " + _keep_s() + ".", {"id": "ward", "duration": Balance.BUFF_KEEP_S, "def_pct": 25}, {"radius": 6.0}),
		_s("bis_mend", "Remendo Sagrado", 17, "sacerdote", ["mace", "shield"], T_GROUND, K_HEAL, 1.8, 24, 10, "Cura forte em área no cursor.", {"range": 9.0, "radius": 2.5}),
		_buff("bis_angel", "Asas Angelicais", 22, "sacerdote", ["mace", "shield"], 28, 35, "+20% MATK, +20% velocidade e +15% DEF no grupo por 10s (você e aliados próximos).", {"id": "angel", "duration": 10, "matk_pct": 20, "speed_pct": 20, "def_pct": 15}, {"radius": 7.0}),
		_s("bis_miracle", "Milagre", 28, "sacerdote", ["mace", "shield"], T_SELF, K_HEAL, 3.0, 40, 45, "Cura enorme em todos num raio de 8m.", {"radius": 8.0, "startup": 0.5}),
		# Inquisidor (martelo de duas mãos)
		_s("bis_hammer", "Martelo de Luz", 4, "inquisidor", ["scepter"], T_TARGET, K_MAG, 2.3, 10, 6, "Um martelo de luz cai no alvo: dano e atordoa 0.6s.", {"range": 8.0, "stun": _dur(0.6), "hit_stop_frames": 5, "startup": 0.25}),
		_s("bis_condemn", "Condenar", 9, "inquisidor", ["scepter"], T_GROUND, K_MAG, 1.4, 16, 9, "Chão condenado: dano contínuo.", {"range": 8.0, "radius": 2.4, "dot": _dot(7, 5)}),
		_s("bis_exorcism", "Exorcismo", 11, "inquisidor", ["scepter"], T_DIR, K_MAG, 2.0, 16, 7, "Raio exorcista que atravessa inimigos.", {"range": 9.0, "radius": 0.7, "projectile_speed": 18.0, "projectile_pierce": true}),
		_buff("bis_zealot", "Fervor", 14, "inquisidor", ["scepter"], 18, 22, "+25% ATK/MATK por 10s.", {"id": "fervor", "duration": 10, "atk_pct": 25, "matk_pct": 25}),
		_s("bis_crusade", "Cruzada", 18, "inquisidor", ["scepter"], T_CONE, K_MAG, 2.2, 22, 10, "Cone de fogo sagrado.", {"radius": 4.0, "cone_angle_deg": 90}),
		_s("bis_wrath", "Ira Divina", 25, "inquisidor", ["scepter"], T_GROUND, K_MAG, 3.6, 34, 20, "Dano enorme em área e atordoa 1.2s.", {"range": 8.0, "radius": 3.0, "stun": _dur(1.2), "hit_stop_frames": 6}),
		# Clérigo de Batalha (maça + escudo, placa): corpo a corpo, cada golpe cura o aliado mais ferido
		_s("bis_holy_blow", "Martelada da Fé", 2, "batalha", ["mace"], T_CONE, K_PHYS, 3.0, 8, 3, "Golpe largo com a maça; 25% do dano cura o aliado mais ferido por perto.", {"radius": 2.4, "cone_angle_deg": 100, "startup": 0.14, "mend_pct_of_dmg": 0.25}),
		_s("bis_shield_smite", "Castigo do Escudo", 7, "batalha", ["mace", "shield"], T_DIR, K_PHYS, 2.6, 12, 8, "Avança 3m com o escudo: dano e atordoa o primeiro alvo 0.8s.", {"range": 3.5, "radius": 0.9, "max_targets": 1, "startup": 0.1, "dash": 3.0, "stun": _dur(0.8)}),
		_buff("bis_battle_hymn", "Hino de Batalha", 10, "batalha", ["mace"], 18, 24, "+20% ATK e +15% DEF para você e aliados próximos por " + _keep_s() + ".", {"id": "battle_hymn", "duration": Balance.BUFF_KEEP_S, "atk_pct": 20, "def_pct": 15}, {"radius": 6.0}),
		_s("bis_holy_quake", "Tremor Sagrado", 14, "batalha", ["mace"], T_SELF, K_PHYS, 3.4, 18, 9, "Bate a maça no chão: dano ao redor, lentidão e 20% do dano cura o aliado mais ferido.", {"radius": 3.2, "startup": 0.2, "slow": _slow(30, 2), "mend_pct_of_dmg": 0.2, "hit_stop_frames": 5}),
		_s("bis_faith_leap", "Salto da Fé", 20, "batalha", ["mace"], T_GROUND, K_PHYS, 3.6, 20, 12, "Salta até o cursor e esmaga o chão: dano, atordoa 0.6s e 20% do dano cura o aliado mais ferido.", {"range": 6.0, "radius": 2.4, "startup": 0.12, "dash": 5.5, "stun": _dur(0.6), "mend_pct_of_dmg": 0.2}),
		# Preenchimento (GDD skills-fill-2026-11-19): estandarte que fica no chão ("zone") e golpe que cura e salta
		_s("bis_faith_banner", "Estandarte da Fé", 17, "batalha", ["mace"], T_GROUND, K_PHYS, 1.2, 22, 18,
			"Finca o estandarte no cursor (3,5 m) por %.0f s: a cada %.0f s fere os inimigos dentro (%d%% do ATK) e os retarda %d%%, e cura você e os aliados dentro." % [
				float(Balance.FAITH_BANNER_ZONE["duration"]), float(Balance.FAITH_BANNER_ZONE["pulse"]), roundi(float(Balance.FAITH_BANNER_ZONE["foe_power"]) * 100.0), int(Balance.FAITH_BANNER_ZONE["foe_slow"])],
			{"range": 6.0, "radius": 3.5, "startup": 0.25, "recovery": 0.25, "cancel_after": 0.12, "hit_stop_frames": 4, "clip": "cast_ground", "vfx": "holy",
			 "zone": Balance.FAITH_BANNER_ZONE, "icon_color": Color(1.0, 0.9, 0.55)}),
		_s("bis_chain_of_faith", "Corrente da Fé", 23, "batalha", ["mace"], T_TARGET, K_PHYS, 2.6, 22, 14,
			"Golpe de maça carregado de luz: 25% do dano cura o aliado mais ferido por perto e a luz salta para mais 2 inimigos a 5 m (60% do dano).",
			{"startup": 0.2, "recovery": 0.3, "cancel_after": 0.15, "hit_stop_frames": 5, "vfx": "holy", "mend_pct_of_dmg": 0.25,
			 "chain": {"count": 2, "radius": 5.0, "falloff": 0.6}, "icon_color": Color(1.0, 0.85, 0.5)}),
		_s("bis_divine_hammer", "Martelo Divino", 26, "batalha", ["mace"], T_TARGET, K_PHYS, 5.5, 30, 16, "Golpe divino num alvo: dano enorme, atordoa 1s e 35% do dano cura o aliado mais ferido.", {"startup": 0.25, "stun": _dur(1.0), "mend_pct_of_dmg": 0.35, "hit_stop_frames": 6}),
		# Ascensão (Ato II, 35 + missão hx_asc_bishop): Coro Celeste. Fora da teia comum, compradas na teia de ascensão
		# (SkillDef.ascension); valem para as 3 builds. Regras em ChoirSystem, números em Balance.BARRIER_*/ANGEL_*/BLESS_*/RES_*.
		_s("bis_choir_angel", "Anjo Guardião", Balance.ASC_LEVEL, "", [], T_SELF, K_SUMMON, 0.0, 30, Balance.ANGEL_CD,
			"Chama um anjo que voa atrás de você por 30 s: a cada 1,5 s ele cura quem mais precisa a 12 m (o tanque primeiro). Monstros não o miram; quando o tempo acaba, a Luz de Partida cura o grupo em volta dele. Um por vez. A maestria fortalece a cura do anjo.",
			{"startup": 0.25, "recovery": 0.3, "cancel_after": 0.1, "choir_angel": {}, "clip": "summon", "vfx": "holy", "ascension": true}),
		_s("bis_choir_barrier", "Barreira Sagrada", Balance.ASC_LEVEL, "", [], T_GROUND, K_BUFF, 0.0, 32, Balance.BARRIER_CD,
			"Ergue uma cúpula de luz de 5 m por 8 s no ponto mirado: quem é do grupo e está dentro recebe 30% menos dano, e projéteis e chuvas vindos de fora param na borda. A cúpula anda com você, 2 m/s mais devagar: o grupo precisa andar junto.",
			{"range": Balance.BARRIER_RANGE, "radius": Balance.BARRIER_RADIUS, "startup": 0.2, "recovery": 0.25, "cancel_after": 0.1,
			 "choir_barrier": {}, "vfx": "holy", "ascension": true}),
		_buff("bis_choir_wings", "Asas da Aurora", Balance.ASC_LEVEL, "", [], 22, Balance.BLESS_CD,
			"Bênção em você e nos aliados a 12 m por 20 s: +15% de velocidade de movimento e de ataque.",
			{"id": "choir_wings", "duration": Balance.BLESS_TIME}.merged(Balance.BLESS_WINGS), {"radius": Balance.BLESS_RADIUS, "vfx": "holy", "ascension": true}),
		_buff("bis_choir_aegis", "Égide Coral", Balance.ASC_LEVEL, "", [], 22, Balance.BLESS_CD,
			"Bênção em você e nos aliados a 12 m por 20 s: +12% de DEF e MDEF, e cada golpe recebido cura 4% da vida (uma vez por segundo).",
			{"id": "choir_aegis", "duration": Balance.BLESS_TIME}.merged(Balance.BLESS_AEGIS), {"radius": Balance.BLESS_RADIUS, "vfx": "holy", "ascension": true}),
		_s("bis_choir_return", "Retorno", Balance.RES_LEVEL, "", [], T_GROUND, K_BUFF, 0.0, 60, Balance.RES_CD,
			"Conjura por 2,5 s e levanta um aliado caído do grupo a até 15 m (o mais perto do ponto mirado) com 35% da vida, ali mesmo. Cada aliado só volta uma vez por luta.",
			{"range": Balance.RES_RANGE, "radius": 1.5, "startup": Balance.RES_CAST, "recovery": 0.3, "cancel_after": 0.1,
			 "choir_return": {}, "clip": "cast_channel", "vfx": "holy", "ascension": true}),
	],
	"druid": [
		_buff("dru_bark", "Pele de Casca", 1, "", [], 10, 18, "+20% DEF por " + _keep_s() + ".", {"id": "bark", "duration": Balance.BUFF_KEEP_S, "def_pct": 20}),
		# Guardião da Floresta (martelo de duas mãos, tanque)
		_s("dru_maul", "Esmagar", 2, "guardiao_verde", ["mace2h"], T_CONE, K_PHYS, 1.6, 8, 4, "Esmaga em cone e retarda.", {"radius": 2.8, "cone_angle_deg": 110, "slow": _slow(30, 1.5)}),
		_s("dru_bellow", "Urro da Mata", 8, "guardiao_verde", ["mace2h"], T_SELF, K_BUFF, 0.0, 12, 12, "Prende os inimigos em 7 m em você por 4s (chefes: 2s) e ganha +20% DEF por 6s.", {"radius": 7.0, "taunt": {"duration": 4}, "buff": {"id": "bellow", "duration": 6, "def_pct": 20}}),
		_s("dru_earth_slam", "Golpe da Terra", 8, "guardiao_verde", ["mace2h"], T_SELF, K_PHYS, 1.8, 16, 10, "Golpeia o chão: dano ao redor e atordoa 0.6s.", {"radius": 3.0, "stun": _dur(0.6)}),
		_s("dru_oak_skin", "Pele de Carvalho", 12, "guardiao_verde", ["mace2h"], T_SELF, K_BUFF, 0.0, 20, 24, "Escudo de 25% do HP por 8s e +20% DEF por " + _keep_s() + ".", {"shield": {"amount_pct_hp": 25, "duration": 8}, "buff": {"id": "oak_skin", "duration": Balance.BUFF_KEEP_S, "def_pct": 20}}),
		# Preenchimento (GDD skills-fill-2026-11-19): ameaça contínua num alvo (sangra e provoca)
		_s("dru_lacerate", "Lacerar", 15, "guardiao_verde", ["mace2h"], T_TARGET, K_PHYS, 1.2, 10, 6,
			"Rasga o alvo: sangra por 6 s (acumula até 3 vezes) e o prende em você por 3 s (chefes: metade). Na forma de urso pega até 3 inimigos juntos.",
			{"startup": 0.18, "recovery": 0.3, "cancel_after": 0.12, "hit_stop_frames": 3, "vfx": "nature", "dot": _dot(4, 6), "provoke": {"duration": 3.0},
			 "icon_color": Color(0.75, 0.5, 0.35)}),
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
		_buff("dru_grove", "Bênção do Bosque", 6, "xama", ["staff"], 18, 20, "+15% ATK, MATK e cura para você e aliados próximos por " + _keep_s() + ".",
			{"id": "grove", "duration": Balance.BUFF_KEEP_S, "atk_pct": 15, "matk_pct": 15, "heal_pct": 15}, {"radius": 7.0}),
		_s("dru_spirit_wolves", "Lobos Espirituais", 9, "xama", ["staff"], T_SELF, K_SUMMON, 0.0, 24, 18, "Invoca 2 lobos espirituais por 20s.",
			{"summon": {"monster_id": "spirit_wolf", "count": 2, "duration": 20, "max": 4}, "startup": 0.35}),
		_s("dru_treant", "Despertar o Ent", 19, "xama", ["staff"], T_SELF, K_SUMMON, 0.0, 34, 30, "Desperta um ent guardião por 25s que provoca os inimigos.",
			{"summon": {"monster_id": "treant", "count": 1, "duration": 25, "max": 2}, "startup": 0.5}),
		_s("dru_wolf_form", "Forma de Lobo", 3, "fera", ["dual_mace"], T_SELF, K_BUFF, 0.0, 10, 1.5, "Vira lobo (lance de novo para voltar): +25% velocidade de ataque, +20% velocidade, +10% ATK, +5 crítico. As skills da Fera viram golpes de lobo.",
			{"form": "wolf", "startup": 0.25}),
		_s("dru_prowl", "Espreitar", 5, "fera", ["dual_mace"], T_SELF, K_BUFF, 0.0, 14, 12, "Só na forma de lobo: some da vista dos inimigos por 8s. O primeiro golpe sai da sombra com +60% de dano.",
			{"stealth": 8.0, "startup": 0.15, "requires_form": "wolf"}),
		_s("dru_storm", "Tempestade da Natureza", 27, "xama", ["staff"], T_GROUND, K_MAG, 3.4, 36, 18, "Tempestade enorme: dano e lentidão.", {"range": 9.0, "radius": 3.5, "slow": _slow(40, 3)}),
		# Ascensão (Ato II, 35 + missão hx_asc_druid): Forma Ancestral (DruidAscension). Fora da teia comum (SkillDef.ascension:
		# teia de ascensão, barra 7-0). Cada build ganha a 3ª forma (liga/desliga) e duas skills que só saem nela.
		_s("dru_ent_form", "Forma de Ent", Balance.ASC_LEVEL, "guardiao_verde", ["mace2h"], T_SELF, K_BUFF, 0.0, 14, 1.5,
			"Ascensão. Vira um Ent ancestral (lance de novo para voltar): +%d%% DEF, +%d%% HP, +%d%% ATK, 5%% menos dano recebido, mais ameaça, mais lento. As skills do Guardião viram golpes de galho e raiz." % [Balance.FORM_STATS["ent"]["def_pct"], Balance.FORM_STATS["ent"]["hp_pct"], Balance.FORM_STATS["ent"]["atk_pct"]],
			{"ascension": true, "form": "ent", "radius": 0.0, "startup": 0.25, "active": 0.05, "recovery": 0.25, "vfx": "earth", "icon_color": Color(0.45, 0.6, 0.3)}),
		_s("dru_ent_roots", "Raízes Ancestrais", Balance.ASC_LEVEL, "guardiao_verde", ["mace2h"], T_SELF, K_PHYS, Balance.ANC_ROOTS_POWER, 18, 14,
			"Só como Ent: raízes brotam em volta (6 m): ferem, prendem por 2,5 s e provocam por 4 s (chefes: metade) quem estiver na área.",
			{"ascension": true, "requires_form": "ent", "radius": Balance.ANC_ROOTS_RADIUS, "root": _dur(Balance.ANC_ROOTS_ROOT), "provoke": _dur(Balance.ANC_ROOTS_TAUNT),
			 "startup": 0.28, "recovery": 0.3, "cancel_after": 0.15, "vfx": "nature", "hit_stop_frames": 5}),
		_buff("dru_ent_grove", "Bosque Protetor", Balance.ASC_LEVEL, "guardiao_verde", ["mace2h"], 20, 20,
			"Só como Ent: a copa cobre o grupo. Você e os aliados a 8 m recebem %d%% menos dano por %d s." % [Balance.ANC_GROVE_DR, Balance.ANC_GROVE_TIME],
			{"id": "ent_grove", "duration": Balance.ANC_GROVE_TIME, "dr_pct": Balance.ANC_GROVE_DR},
			{"ascension": true, "requires_form": "ent", "radius": Balance.ANC_GROVE_RADIUS, "vfx": "nature"}),
		_s("dru_alpha_form", "Lobo Alfa", Balance.ASC_LEVEL, "fera", ["dual_mace"], T_SELF, K_BUFF, 0.0, 14, 1.5,
			"Ascensão. Vira o Lobo Alfa (lance de novo para voltar): +%d%% velocidade de ataque, +%d%% velocidade, +%d%% ATK, +%d crítico. Vale como forma de lobo (Espreitar) e os golpes da Fera ficam mais fortes." % [Balance.FORM_STATS["alpha"]["aspd_pct"], Balance.FORM_STATS["alpha"]["speed_pct"], Balance.FORM_STATS["alpha"]["atk_pct"], Balance.FORM_STATS["alpha"]["crit"]],
			{"ascension": true, "form": "alpha", "radius": 0.0, "startup": 0.25, "active": 0.05, "recovery": 0.25, "vfx": "lunar", "icon_color": Color(0.8, 0.84, 0.95)}),
		_s("dru_alpha_pack", "Chamar a Matilha", Balance.ASC_LEVEL, "fera", ["dual_mace"], T_SELF, K_SUMMON, 0.0, 22, 30,
			"Só como Lobo Alfa: uiva e chama 2 lobos da matilha por 15 s. Eles têm parte da sua vida e do seu ataque e caçam o seu alvo.",
			{"ascension": true, "requires_form": "alpha", "pack": {"monster_id": Balance.ANC_PACK_MONSTER, "count": Balance.ANC_PACK_COUNT},
			 "startup": 0.3, "recovery": 0.25, "cancel_after": 0.1, "vfx": "nature"}),
		_buff("dru_alpha_howl", "Uivo do Alfa", Balance.ASC_LEVEL, "fera", ["dual_mace"], 16, 22,
			"Só como Lobo Alfa: o uivo apressa o grupo. Você e os aliados a 10 m ganham +%d%% de velocidade e +%d%% de velocidade de ataque por %d s." % [Balance.ANC_HOWL_SPEED, Balance.ANC_HOWL_ASPD, Balance.ANC_HOWL_TIME],
			{"id": "alpha_howl", "duration": Balance.ANC_HOWL_TIME, "speed_pct": Balance.ANC_HOWL_SPEED, "aspd_pct": Balance.ANC_HOWL_ASPD},
			{"ascension": true, "requires_form": "alpha", "radius": Balance.ANC_HOWL_RADIUS, "vfx": "wind"}),
		_s("dru_bird_form", "Pássaro Arcano", Balance.ASC_LEVEL, "xama", ["staff"], T_SELF, K_BUFF, 0.0, 14, 1.5,
			"Ascensão. Vira um pássaro arcano que voa por cima do chão (lance de novo para voltar): +%d%% velocidade, +%d%% MATK. Fogo Lunar vira Raio em Cadeia, Chuva Estelar vira Chuva de Penas de Luz (cura o grupo embaixo) e Ciclone vira Rajada de Vento (empurra). Golpes no chão ainda o acertam." % [Balance.FORM_STATS["bird"]["speed_pct"], Balance.FORM_STATS["bird"]["matk_pct"]],
			{"ascension": true, "form": "bird", "radius": 0.0, "startup": 0.25, "active": 0.05, "recovery": 0.25, "vfx": "lightning", "icon_color": Color(0.6, 0.75, 1.0)}),
		_s("dru_bird_bolt", "Relâmpago Arcano", Balance.ASC_LEVEL, "xama", ["staff"], T_GROUND, K_MAG, Balance.ANC_BOLT_POWER, 20, 9,
			"Só como Pássaro Arcano: um raio cai no ponto mirado (2 m) e salta para até 2 inimigos a 5 m com metade do dano.",
			{"ascension": true, "requires_form": "bird", "range": 10.0, "radius": 2.0, "chain": Balance.ANC_BOLT_CHAIN,
			 "startup": 0.25, "recovery": 0.3, "cancel_after": 0.12, "vfx": "lightning", "hit_stop_frames": 4}),
		_s("dru_bird_flock", "Revoada de Luz", Balance.ASC_LEVEL, "xama", ["staff"], T_SELF, K_HEAL, Balance.ANC_FLOCK_POWER, 24, 16,
			"Só como Pássaro Arcano: penas de luz caem em volta (8 m): curam você e o grupo e dão +10% de velocidade por 6 s.",
			{"ascension": true, "requires_form": "bird", "radius": Balance.ANC_FLOCK_RADIUS,
			 "buff": {"id": "bird_flock", "duration": Balance.ANC_FLOCK_TIME, "speed_pct": Balance.ANC_FLOCK_SPEED},
			 "startup": 0.25, "recovery": 0.3, "cancel_after": 0.12, "vfx": "holy"}),
	],
	"ranger": [
		_s("ran_anchor", "Flecha Âncora", 6, "", ["bow", "rifle"], T_DIR, K_PHYS, 1.3, 9, 8, "Disparo que prende o alvo no chão por 1.5s.",
			{"range": 10.0, "radius": 0.5, "projectile_speed": 24.0, "max_targets": 1, "root": _dur(1.5)}),
		# Atirador (arco, alvo único)
		# Preenchimento (GDD skills-fill-2026-11-19): cura de campo para as três armas (o lince também ganha o buff, se estiver)
		_buff("ran_field_dressing", "Curativo de Campo", 11, "", [], 14, 20,
			"Ata um curativo: cura 20% da vida na hora e +20% de velocidade por 4 s (o companheiro também, se estiver com você).",
			{"id": "field_dressing", "duration": 4, "speed_pct": 20},
			{"heal_pct": 20, "pet_buff": "if_any", "startup": 0.15, "recovery": 0.2, "cancel_after": 0.1, "clip": "buff_power", "vfx": "nature"}),
		_s("ran_snipe", "Tiro Certeiro", 8, "atirador", ["rifle"], T_DIR, K_PHYS, 2.6, 14, 9, "Tiro instantâneo de longuíssimo alcance (além do alcance do mosquete).", {"range": 15.0, "radius": 0.4, "startup": 0.3, "max_targets": 1}),     # C8: teto 0,3 s (era 0,45)
		_s("ran_piercing", "Flecha Perfurante", 12, "cacador", ["bow"], T_DIR, K_PHYS, 1.9, 12, 6, "Flecha que atravessa inimigos.", {"range": 11.0, "radius": 0.5, "projectile_speed": 26.0, "projectile_pierce": true}),
		_s("ran_headshot", "Tiro na Cabeça", 18, "atirador", ["rifle"], T_TARGET, K_PHYS, 3.4, 20, 12, "Tiro preciso no alvo: atordoa 0.5s.", {"range": 12.0, "stun": _dur(0.5), "hit_stop_frames": 5}),
		_buff("ran_deadeye", "Olho de Águia", 24, "atirador", ["rifle"], 20, 28, "+20 crit e +15% ATK por 10s.", {"id": "deadeye", "duration": 10, "crit": 20, "atk_pct": 15}),
		# Caçador (arco, área e controle)
		# Caçador: companheiro (bicho permanente que segue o dono)
		_s("ran_companion", "Companheiro", 2, "cacador", ["bow"], T_SELF, K_SUMMON, 0.0, 20, 20, "Chama o seu lince companheiro (fica com você até cair; vida e ataque vêm dos seus).",
			{"summon": {"monster_id": "companion", "count": 1, "duration": 0.0, "max": 1, "owner_stats": true}, "startup": 0.4}),
		_s("ran_sic", "Ataque da Fera", 7, "cacador", ["bow"], T_TARGET, K_PHYS, 2.2, 12, 8, "O companheiro salta no alvo: dano alto e atordoa 0.8s.",
			{"range": 12.0, "pet_command": {"stun": 0.8}, "startup": 0.1}),
		_buff("ran_pack", "Instinto da Matilha", 16, "cacador", ["bow"], 18, 24, "+20% ATK e +20% velocidade de ataque para você e o companheiro por " + _keep_s() + ".",
			{"id": "pack", "duration": Balance.BUFF_KEEP_S, "atk_pct": 20, "aspd_pct": 20}, {"pet_buff": true}),
		# Atirador: mosquete e armadilhas
		_s("ran_scatter", "Tiro de Dispersão", 6, "atirador", ["rifle"], T_CONE, K_PHYS, 1.8, 12, 6, "Carga de chumbo em cone curto (5 m): acerta até 5 inimigos, empurra 2,5 m para trás e retarda 30% por 1.5s.",
			{"radius": 5.0, "cone_angle_deg": 55, "max_targets": 5, "slow": _slow(30, 1.5), "knockback": {"dist": Balance.SCATTER_PUSH}}),
		_s("ran_mine", "Mina Explosiva", 9, "atirador", ["rifle"], T_GROUND, K_PHYS, 2.6, 16, 9, "Mina no chão (conta no limite de 3): explode em área quando um inimigo pisa.",
			{"range": 7.0, "radius": 2.6, "trap": {"kind": "mine", "duration": 30.0, "hit_radius": 1.2}, "hit_stop_frames": 5, "clip": "atk_throw", "vfx": "fire"}),
		_s("ran_frost_trap", "Armadilha de Gelo", 13, "atirador", ["bow", "rifle"], T_GROUND, K_PHYS, 1.0, 14, 10, "Armadilha no chão (conta no limite de 3): congela a área, retarda 60% por 3s.",
			{"range": 7.0, "radius": 3.0, "trap": {"kind": "frost", "duration": 30.0, "hit_radius": 1.3}, "slow": _slow(60, 3.0)}),
		_s("ran_explosive", "Flecha Explosiva", 5, "cacador", ["bow"], T_GROUND, K_PHYS, 1.6, 12, 7, "Flecha que explode no cursor: dano em área (2,2 m).", {"range": 10.0, "radius": 2.2}),
		_s("ran_frost_arrow", "Flecha Gélida", 9, "cacador", ["bow"], T_DIR, K_PHYS, 1.4, 10, 5, "Retarda 45% por 2.5s.", {"range": 10.0, "radius": 0.5, "projectile_speed": 22.0, "slow": _slow(45, 2.5)}),
		_s("ran_net", "Rede", 13, "cacador", ["bow"], T_GROUND, K_PHYS, 0.4, 14, 12, "Rede no cursor prende por 2.5s.", {"range": 9.0, "radius": 2.4, "root": _dur(2.5)}),
		_s("ran_volley", "Saraivada", 22, "cacador", ["bow"], T_CONE, K_PHYS, 2.4, 22, 10, "Leque de flechas longo e estreito: vai até o alcance do arco (13 m) e acerta até 8 inimigos.", {"radius": 13.0, "cone_angle_deg": 40, "max_targets": 8}),
		_s("ran_barrage", "Barragem", 27, "cacador", ["bow"], T_GROUND, K_PHYS, 3.2, 32, 18, "Bombardeio de flechas em área grande (4 m) no cursor.", {"range": 11.0, "radius": 4.0}),
		# Lanceiro (lança de duas mãos): caça de perto. Estocadas longas em linha, salto na presa, dardo e armadilha de mão;
		# a presa sangra (dot com atk_pct: dano por segundo = % do ATK) e a Marca do Predador a deixa mais frágil
		_s("ran_double_thrust", "Estocada Dupla", 2, "lanceiro", ["spear"], T_CONE, K_PHYS, 1.9, 7, 3,
			"Duas estocadas rápidas em linha (3,6 m): atravessa até 3 inimigos e faz sangrar (12% do ATK por segundo, 4 s).",
			{"radius": 3.6, "cone_angle_deg": 36, "line_width": Balance.SPEAR_LINE_WIDTH, "max_targets": 3, "startup": 0.1, "recovery": 0.24, "cancel_after": 0.08,
			 "dot": {"atk_pct": 12, "duration": 4.0}, "clip": "atk_thrust", "vfx": "blood", "hit_stop_frames": 3}),
		_s("ran_javelin", "Dardo de Caça", 4, "lanceiro", ["spear"], T_DIR, K_PHYS, 1.6, 9, 5,
			"Tira um dardo do cinto e arremessa: acerta o primeiro inimigo na linha (10 m) e o retarda 35% por 2s.",
			{"range": 10.0, "radius": 0.45, "projectile_speed": 26.0, "max_targets": 1, "startup": 0.16, "recovery": 0.24,
			 "slow": _slow(35, 2.0), "clip": "atk_throw", "vfx": "earth"}),
		_s("ran_spear_leap", "Salto do Predador", 6, "lanceiro", ["spear"], T_GROUND, K_PHYS, 2.1, 12, 8,
			"Salta até o cursor com a lança para baixo: dano na área da queda e prende os atingidos por 1s.",
			{"range": 6.5, "radius": 2.2, "dash": 6.0, "startup": 0.2, "root": _dur(1.0), "clip": "atk_leap", "vfx": "earth", "hit_stop_frames": 5}),
		_s("ran_spear_sweep", "Lança Giratória", 9, "lanceiro", ["spear"], T_SELF, K_PHYS, 1.7, 12, 7,
			"Gira a lança pela haste: dano em tudo a 3,4 m e retarda 30% por 2s.",
			{"radius": 3.4, "active": 0.25, "startup": 0.14, "slow": _slow(30, 2.0), "clip": "atk_spin", "vfx": "wind"}),
		_s("ran_snare_toss", "Armadilha Lançada", 12, "lanceiro", ["spear"], T_GROUND, K_PHYS, 1.0, 12, 10,
			"Arremessa uma armadilha de mandíbula aberta nos pés do inimigo: fecha na hora, prende 2s e faz sangrar (15% do ATK por segundo, 4 s).",
			{"range": 8.0, "radius": 1.8, "startup": 0.18, "root": _dur(2.0), "dot": {"atk_pct": 15, "duration": 4.0}, "clip": "atk_throw", "vfx": "blood"}),
		_s("ran_predator", "Marca do Predador", 15, "lanceiro", ["spear"], T_TARGET, K_PHYS, 1.0, 14, 12,
			"Crava um dardo marcado na presa: ela recebe +18% de dano de todos por 10s, sangra (10% do ATK por segundo, 6 s) e fica 25% mais lenta por 2s.",
			{"range": 9.0, "startup": 0.16, "curse": {"id": "predator", "duration": 10.0, "taken_pct": 18}, "dot": {"atk_pct": 10, "duration": 6.0},
			 "slow": _slow(25, 2.0), "clip": "atk_throw", "vfx": "blood"}),
		_buff("ran_blood_instinct", "Instinto do Predador", 18, "lanceiro", ["spear"], 18, 22, "+25% de velocidade de ataque, +10 de crítico e 5% de roubo de vida por 10s.",
			{"id": "blood_instinct", "duration": 10, "aspd_pct": 25, "crit": 10, "lifesteal": 5}),
		_s("ran_impale", "Empalar", 24, "lanceiro", ["spear"], T_DIR, K_PHYS, 3.8, 26, 14,
			"Avança 5 m com a lança à frente atravessando a fila: dano alto, atordoa 0.6s e faz sangrar (20% do ATK por segundo, 4 s).",
			{"range": 6.0, "radius": 1.0, "dash": 5.0, "startup": 0.28, "stun": _dur(0.6), "dot": {"atk_pct": 20, "duration": 4.0},
			 "clip": "atk_charge", "vfx": "blood", "hit_stop_frames": 6}),
		# Ascensão (Ato II, 35 + missão hx_asc_ranger): fora da teia comum, compradas na teia de ascensão (SkillDef.ascension).
		_s("ran_turret", "Torreta de Campo", Balance.ASC_LEVEL, "atirador", ["rifle"], T_GROUND, K_SUMMON, 0.0, 24, 18,
			"Monta uma torreta no ponto mirado: ela fica ali e atira sozinha no inimigo mais perto (11 m) por 15 s, com parte da sua vida e do seu ataque. Uma por vez.",
			{"range": 8.0, "radius": Balance.TURRET_AREA, "startup": 0.2, "recovery": 0.25, "cancel_after": 0.1,
			 "turret": {"monster_id": Balance.TURRET_MONSTER}, "clip": "atk_throw", "vfx": "earth", "ascension": true}),
		_s("ran_dragon_jump", "Salto Dracônico", Balance.ASC_LEVEL, "lanceiro", ["spear"], T_GROUND, K_PHYS, Balance.DRAGON_JUMP_POWER, 18, 14,
			"Salta alto e some do chão por 1,2 s (golpes, projéteis e chuva não o pegam; quem o mirava volta para o tanque) e cai no ponto mirado com a lança: dano forte no centro (1,5 m) e menor na borda (3 m). Com um Brado ativo, a queda leva o elemento.",
			{"range": 9.0, "radius": 3.0, "startup": 0.12, "active": Balance.DRAGON_JUMP_AIR, "recovery": 0.25, "cancel_after": 0.05,
			 "dragon_jump": {}, "clip": "atk_leap", "vfx": "earth", "hit_stop_frames": 5, "ascension": true}),
		_buff("ran_shout_flame", "Brado das Chamas", Balance.ASC_LEVEL, "lanceiro", ["spear"], 14, Balance.SHOUT_CD,
			"Grito de guerra (12 s, um Brado por vez): a lança queima quem acerta; o grupo a 10 m ganha +10% de dano de fogo. Provoca por 1 s os monstros a 4 m.",
			{"id": "shout_flame", "duration": Balance.SHOUT_TIME, "fire_pct": Balance.SHOUT_BUFF},
			{"shout": {"element": "fire"}, "clip": "shout", "vfx": "fire", "ascension": true}),
		_buff("ran_shout_frost", "Brado da Geada", Balance.ASC_LEVEL, "lanceiro", ["spear"], 14, Balance.SHOUT_CD,
			"Grito de guerra (12 s, um Brado por vez): a lança deixa lento quem acerta; inimigos a 6 m atacam 10% mais devagar. Provoca por 1 s os monstros a 4 m.",
			{"id": "shout_frost", "duration": Balance.SHOUT_TIME, "frost_pct": Balance.SHOUT_BUFF},
			{"shout": {"element": "frost"}, "clip": "shout", "vfx": "ice", "ascension": true}),
		_buff("ran_shout_thunder", "Brado do Trovão", Balance.ASC_LEVEL, "lanceiro", ["spear"], 14, Balance.SHOUT_CD,
			"Grito de guerra (12 s, um Brado por vez): o golpe da lança salta para 1 vizinho; o grupo a 10 m fica 10% mais rápido. Provoca por 1 s os monstros a 4 m.",
			{"id": "shout_thunder", "duration": Balance.SHOUT_TIME, "speed_pct": Balance.SHOUT_BUFF},
			{"shout": {"element": "storm"}, "clip": "shout", "vfx": "lightning", "ascension": true}),
		# Caçador — Falcoeiro: Olhos do Céu (FalconSystem). O falcão é intocável e mergulha sozinho a cada FALCON_DIVE_CD.
		_s("ran_falcon", "Chamado do Falcão", Balance.ASC_LEVEL, "cacador", ["bow"], T_SELF, K_SUMMON, 0.0, 20, 20,
			"Chama o seu falcão: ele voa sobre você (ninguém o atinge) e fica até você cair. A cada 6 s mergulha no inimigo que você está acertando e o marca como Presa: por 8 s ele recebe +6% de dano de todos.",
			{"falcon_call": true, "startup": 0.3, "recovery": 0.25, "cancel_after": 0.1, "clip": "summon", "vfx": "wind", "ascension": true}),
		_s("ran_dive", "Mergulho", Balance.ASC_LEVEL, "cacador", ["bow"], T_TARGET, K_PHYS, Balance.FALCON_STOOP_POWER, 14, Balance.FALCON_STOOP_CD,
			"O falcão mergulha no alvo, de longe: dano, atordoa 0,6 s, marca a Presa e manda o lince saltar no mesmo alvo.",
			{"range": Balance.FALCON_RANGE, "startup": 0.12, "recovery": 0.2, "cancel_after": 0.08, "stun": _dur(Balance.FALCON_STOOP_STUN),
			 "falcon_dive": true, "clip": "cast_target", "vfx": "wind", "hit_stop_frames": 4, "ascension": true}),
		_buff("ran_sky_eyes", "Olhos do Céu", Balance.ASC_LEVEL, "cacador", ["bow"], 22, Balance.FALCON_EYES_CD,
			"O falcão mostra a luta de cima por 10 s: você e os aliados do grupo a 15 m ganham +8 de crítico contra a Presa e +10% de velocidade de movimento.",
			{"id": "sky_eyes", "duration": Balance.FALCON_EYES_TIME, "prey_crit": Balance.FALCON_EYES_CRIT, "speed_pct": Balance.FALCON_EYES_SPEED},
			{"radius": Balance.FALCON_EYES_RADIUS, "falcon_eyes": true, "cancel_after": 0.05, "clip": "shout", "vfx": "wind", "ascension": true}),
	],
	"assassin": [
		_s("ass_quick_stab", "Estocada Rápida", 1, "", [], T_CONE, K_PHYS, 1.2, 5, 2, "Estocada curta em até 2 alvos.", {"radius": 2.2, "cone_angle_deg": 70, "max_targets": 2}),
		# Lâminas (duas adagas): veneno, esquiva, furtividade e pelas costas
		_s("ass_twin_strike", "Golpe Gêmeo", 2, "laminas", ["dual_dagger"], T_TARGET, K_PHYS, 1.8, 8, 3, "Duas adagas no mesmo alvo."),
		_s("ass_blade_flurry", "Rajada de Lâminas", 8, "laminas", ["dual_dagger"], T_CONE, K_PHYS, 1.6, 12, 6, "Cortes rápidos em leque.", {"radius": 2.6, "cone_angle_deg": 110}),
		_s("ass_eviscerate", "Eviscerar", 13, "laminas", ["dual_dagger"], T_TARGET, K_PHYS, 2.2, 18, 9,
			"Corte profundo que consome os seus venenos no alvo: o veneno que faltava explode na hora e o golpe ganha +%d%% de dano por veneno (até %d)." % [roundi(float(Balance.EVISCERATE_POISON["per"]) * 100.0), int(Balance.EVISCERATE_POISON["max"])],
			{"hit_stop_frames": 5, "combust": Balance.EVISCERATE_POISON}),
		_s("ass_dance", "Dança da Morte", 19, "laminas", ["dual_dagger"], T_SELF, K_PHYS, 2.4, 22, 11, "Gira entre os inimigos ao redor.", {"radius": 3.0}),
		_s("ass_thousand", "Mil Cortes", 26, "laminas", ["dual_dagger"], T_TARGET, K_PHYS, 4.0, 30, 16, "Rajada final em um alvo.", {"hit_stop_frames": 7}),
		# Duelista: duas espadas, equilibrado (golpes largos, guarda, avanço e golpe de mestre)
		_s("ass_cross_slash", "Corte Cruzado", 2, "duelista", ["dual_sword"], T_CONE, K_PHYS, 1.6, 9, 4, "Duas espadas em X num leque largo.", {"radius": 2.9, "cone_angle_deg": 110}),
		_s("ass_thrust", "Estocada Dupla", 6, "duelista", ["dual", "pistol"], T_TARGET, K_PHYS, 2.0, 11, 6, "Duas estocadas no alvo que fazem sangrar.", {"range": 2.6, "dot": _dot(6, 4)}),
		_buff("ass_guard", "Guarda do Duelista", 9, "duelista", ["dual", "pistol"], 8, Balance.RIPOSTE_CD,
			"Apara por %.0fs: golpe de perto e de frente não causa dano (de chefe, -%d%%), você responde com %d%% do ATK e ganha 1 Ímpeto (+%d de crítico por carga, até %d; o Golpe de Mestre gasta)." % [Balance.RIPOSTE_WINDOW, roundi(Balance.RIPOSTE_BOSS_CUT * 100.0), int(Balance.RIPOSTE_COUNTER_PCT), int(Balance.RIPOSTE_MOMENTUM_CRIT), Balance.RIPOSTE_MOMENTUM_MAX],
			{"id": Balance.RIPOSTE_BUFF, "duration": Balance.RIPOSTE_WINDOW, "def_pct": 30, "evasion": 15},
			{"riposte": true, "startup": 0.05, "recovery": 0.1, "cancel_after": 0.05}),
		_s("ass_lunge", "Avanço do Duelista", 12, "duelista", ["dual_sword"], T_DIR, K_PHYS, 2.4, 15, 9, "Avança 6m com as duas espadas à frente.", {"range": 6.0, "radius": 0.9, "dash": 6.0}),
		_s("ass_steel_whirl", "Turbilhão de Aço", 16, "duelista", ["dual_sword"], T_SELF, K_PHYS, 2.2, 18, 10, "Gira com as duas espadas: dano ao redor.", {"radius": 3.0}),
		_s("ass_crimson", "Lâmina Carmesim", 20, "duelista", ["dual_sword"], T_TARGET, K_PHYS, 2.8, 18, 9, "Golpe que cura 25% do dano.", {"heal_pct_of_dmg": 0.25}),
		_buff("ass_focus", "Foco do Duelista", 23, "duelista", ["dual_sword"], 20, 26, "+20 crítico, +15% ATK e +15% velocidade de ataque por 8s.", {"id": "duel_focus", "duration": 8, "crit": 20, "atk_pct": 15, "aspd_pct": 15}),
		_s("ass_master", "Golpe de Mestre", 28, "duelista", ["dual_sword"], T_TARGET, K_PHYS, 4.4, 32, 16,
			"Sequência final das duas espadas no alvo. Gasta o Ímpeto: +%d%% de dano por carga." % int(Balance.RIPOSTE_SPEND_PCT),
			{"hit_stop_frames": 7, "momentum_spend": {"power_pct": Balance.RIPOSTE_SPEND_PCT}}),
		_s("ass_toxic_cloud", "Nuvem Tóxica", 5, "laminas", ["dual"], T_GROUND, K_PHYS, 0.5, 12, 9, "Nuvem no cursor: veneno forte por 6s.", {"range": 8.0, "radius": 2.4, "dot": _dot(8, 6)}),
		_s("ass_venom_dart", "Dardo Venenoso", 9, "laminas", ["dual"], T_DIR, K_PHYS, 1.0, 8, 3, "Dardo que envenena por 5s.", {"range": 10.0, "radius": 0.4, "projectile_speed": 24.0, "dot": _dot(6, 5)}),
		_s("ass_paralyze", "Toxina Paralisante", 14, "laminas", ["dual"], T_TARGET, K_PHYS, 0.8, 14, 12, "Paralisa o alvo por 1.5s.", {"range": 3.0, "stun": _dur(1.5)}),
		_buff("ass_plague_blade", "Lâmina Pestilenta", 4, "laminas", ["dual_dagger"], 14, 22, "Envenena as lâminas por " + _keep_s() + ": cada golpe aplica veneno (renova) e +15% velocidade de ataque.",
			{"id": "plague_blade", "duration": Balance.BUFF_KEEP_S, "hit_poison": 9, "aspd_pct": 15}),
		_s("ass_vanish", "Sumir", 7, "laminas", ["dual"], T_SELF, K_BUFF, 0.0, 16, 14, "Some da vista dos inimigos por 6s. O primeiro golpe sai da sombra com +60% de dano (e pelas costas, crítico).",
			{"stealth": 6.0, "startup": 0.1}),
		_buff("ass_reflexes", "Reflexos", 11, "laminas", ["dual_dagger"], 12, 18, "+35% de esquiva, -30% de dano sofrido e +20% velocidade por 5s.", {"id": "reflexes", "duration": 5, "evasion": 35, "dr_pct": 30, "speed_pct": 20}),
		_s("ass_virulence", "Virulência", 25, "laminas", ["dual_dagger"], T_GROUND, K_PHYS, 1.2, 30, 16, "Epidemia no cursor: veneno altíssimo.", {"range": 8.0, "radius": 3.2, "dot": _dot(16, 6)}),
		_s("ass_expose", "Expor Fraqueza", 9, "duelista", ["dual", "pistol"], T_TARGET, K_PHYS, 2.0, 10, 8, "Golpe que expõe o alvo: recebe +20% de dano de todos por 6s.",
			{"curse": {"id": "expose", "duration": 6.0, "taken_pct": 20}}),
		_s("ass_caltrops", "Abrolhos", 13, "", [], T_GROUND, K_PHYS, 1.1, 14, 10, "Espalha estrepes no cursor: lentidão de 40% e sangramento por 5s.",
			{"range": 8.0, "radius": 3.2, "dot": _dot(10, 5), "slow": _slow(40, 4)}),
		# Corsário (sabre + pistola): tiros e cortes juntam Bravata (Balance.BRAVADO_*); o Tiro Entre os Olhos gasta tudo.
		# "shot" = sai da pistola (clarão na boca do cano + rastro da bala no FX; a arma lendária Bala na Agulha também atira)
		_s("ass_pistol_shot", "Tiro de Pistola", 2, "corsario", ["pistol"], T_TARGET, K_PHYS, 1.3, 6, 3,
			"Tiro rápido de pistola no alvo sob o cursor (até 9 m). +1 Bravata.",
			{"range": 9.0, "startup": 0.12, "recovery": 0.22, "cancel_after": 0.08, "hit_stop_frames": 3, "combo_gain": 1, "shot": true, "vfx": "fire", "clip": "atk_pistol"}),
		_s("ass_slash_shot", "Corte e Tiro", 5, "corsario", ["pistol"], T_TARGET, K_PHYS, 2.0, 10, 6,
			"Corte de sabre e um tiro à queima-roupa no mesmo alvo. +2 Bravata.",
			{"range": 2.8, "startup": 0.2, "recovery": 0.28, "cancel_after": 0.12, "hit_stop_frames": 4, "combo_gain": 2, "shot": true, "vfx": "fire", "clip": "atk_slash_shot"}),
		_s("ass_dice", "Dados da Sorte", 9, "corsario", ["pistol"], T_SELF, K_BUFF, 0.0, 14, 24,
			"Rola os dados: por 12s ganha UM entre +25% de ATK, +20 de crítico, +25% de velocidade de ataque (e 15% de corrida) ou -25% de recarga. O resultado aparece na barra de efeitos.",
			{"vfx": "holy", "dice": [{"id": "lucky_dice", "duration": 12, "atk_pct": 25, "label": "Ataque"}, {"id": "lucky_dice", "duration": 12, "crit": 20, "label": "Crítico"},
				{"id": "lucky_dice", "duration": 12, "aspd_pct": 25, "speed_pct": 15, "label": "Velocidade"}, {"id": "lucky_dice", "duration": 12, "cdr": 25, "label": "Recarga"}]}),
		_s("ass_grapple", "Gancho de Abordagem", 12, "corsario", ["pistol"], T_GROUND, K_PHYS, 1.4, 12, 10,
			"Dispara o gancho e se puxa até o ponto do cursor (até 9 m): corta quem estiver lá e retarda 40% por 2s. +1 Bravata.",
			{"range": 9.0, "radius": 1.8, "dash": 9.0, "dash_to_aim": true, "startup": 0.12, "recovery": 0.25, "cancel_after": 0.12, "slow": _slow(40, 2), "combo_gain": 1}),
		_s("ass_ricochet_shot", "Bala Ricochete", 16, "corsario", ["pistol"], T_TARGET, K_PHYS, 1.8, 14, 8,
			"Bala que ricocheteia em até 4 inimigos (15% menos a cada salto). +1 Bravata.",
			{"range": 10.0, "projectile_speed": 40.0, "bounce": {"count": 4, "radius": 6.0, "falloff": 0.85, "taunt": 0.0, "back": false},
			 "startup": 0.14, "recovery": 0.24, "cancel_after": 0.1, "hit_stop_frames": 3, "combo_gain": 1, "shot": true, "vfx": "fire", "clip": "atk_pistol"}),
		_s("ass_between_eyes", "Tiro Entre os Olhos", 20, "corsario", ["pistol"], T_TARGET, K_PHYS, 2.2, 18, 12,
			"Finalizador: mira e atira no alvo (até 10 m), atordoando 0.3s. Gasta toda a Bravata: +25% de dano e +0.3s de atordoamento por carga.",
			{"range": 10.0, "startup": 0.28, "recovery": 0.3, "cancel_after": 0.15, "hit_stop_frames": 6, "stun": _dur(0.3), "combo_spend": {"power_pct": 25, "stun_per": 0.3},
			 "shot": true, "vfx": "fire", "clip": "atk_pistol"}),
		_buff("ass_black_flag", "Bandeira Negra", 24, "corsario", ["pistol"], 20, 26,
			"Ergue a bandeira do capitão: você e os aliados a 8 m ganham +15% de ATK e +15% de velocidade de ataque por 10s; você ganha 3 de Bravata.",
			{"id": "black_flag", "duration": 10, "atk_pct": 15, "aspd_pct": 15}, {"radius": 8.0, "combo_gain": 3}),
		_s("ass_broadside", "Bordada", 28, "corsario", ["pistol"], T_CONE, K_PHYS, 2.4, 26, 14,
			"Saca as pistolas de reserva e descarrega tudo num leque de 6 m à frente (até 5 inimigos). +2 Bravata.",
			{"radius": 6.0, "cone_angle_deg": 50, "max_targets": 5, "startup": 0.24, "recovery": 0.32, "cancel_after": 0.15, "hit_stop_frames": 5, "combo_gain": 2,
			 "shot": true, "vfx": "fire", "clip": "atk_pistol"}),
		# Ascensão (Ato II, 35 + missão hx_asc_assassin): Sombras Gêmeas (ShadowSystem). Fora da teia comum, todas as builds.
		_s(Balance.SHADOW_SKILL, "Sombra Gêmea", Balance.ASC_LEVEL, "", [], T_SELF, K_BUFF, 0.0, 20, Balance.SHADOW_CD,
			"Chama um clone de sombra por 6 s: ele fica ao seu lado e repete cada golpe seu (skills, básico e tiros) com 50% do dano. Monstros o ignoram; ele some se você cair.",
			{"shadow_clone": {}, "startup": 0.1, "recovery": 0.15, "cancel_after": 0.05, "clip": "buff_power", "vfx": "shadow", "ascension": true, "icon_color": Color(0.45, 0.3, 0.7)}),
		_s(Balance.EXECUTION_SKILL, "Execução", Balance.ASC_LEVEL, "", [], T_TARGET, K_PHYS, Balance.EXECUTION_POWER, 16, Balance.EXECUTION_CD,
			"Golpe de misericórdia: dano enorme em alvo abaixo de 25% da vida; acima disso, só um corte fraco.",
			{"execute": {}, "startup": 0.16, "recovery": 0.28, "cancel_after": 0.12, "hit_stop_frames": 7, "clip": "atk_finisher", "vfx": "shadow", "ascension": true, "icon_color": Color(0.7, 0.2, 0.3)}),
		_s("ass_hand_cannon", "Canhão de Mão", 40, "corsario", ["pistol"], T_DIR, K_PHYS, Balance.HAND_CANNON_POWER, 20, Balance.HAND_CANNON_CD,
			"Tiro pesado em linha (9 m) que atravessa e empurra 3 m quem acerta (chefes não saem do lugar). +2 Bravata.",
			{"range": Balance.HAND_CANNON_RANGE, "radius": 0.7, "projectile_speed": 34.0, "projectile_pierce": true, "knockback": {"dist": Balance.HAND_CANNON_PUSH},
			 "startup": 0.22, "recovery": 0.32, "cancel_after": 0.15, "hit_stop_frames": 5, "combo_gain": 2, "shot": true, "vfx": "fire", "clip": "atk_pistol", "ascension": true}),
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
		# Ascensão (35, missão O Núcleo Elemental): o elemental vira companheiro que evolui (ElementalSystem)
		_s("ele_asc_command", "Comando Elemental", Balance.ASC_LEVEL, "", [], T_SELF, K_BUFF, 0.0, 0, 0,
			"Ascensão. Sem elemental: chama o seu (na forma escolhida, com o estágio que ele alcançou). Com ele: troca o modo — atacar (segue o seu alvo), proteger (provoca quem bate em você e ganha defesa) ou apoiar (fogo dá ataque, gelo dá escudo, raio dá velocidade ao grupo).",
			{"elem_command": true, "ascension": true, "startup": 0.1, "recovery": 0.15, "cancel_after": 0.05, "vfx": "summon", "clip": "summon"}),
		_s("ele_asc_fusion", "Fusão Elemental", Balance.ASC_LEVEL, "", [], T_TARGET, K_MAG, 5.0, 8, 25,     # C6 2026-11-23: 3,0/40 s -> 5,0/25 s (skill_audit 23% -> 62%)
			"Ascensão. Você solta a magia-assinatura da forma do seu elemental no alvo (fogo queima, gelo retarda, raio atordoa; até 5 inimigos a 2.5 m) e por 8s ganha +MATK e bônus no elemento dele (maior com o estágio).",
			{"elem_fusion": true, "ascension": true, "vfx": "lightning", "range": 9.0, "radius": 2.5, "max_targets": 5, "startup": 0.3, "recovery": 0.3, "cancel_after": 0.15, "hit_stop_frames": 4}),
		# Fogo (orbe)
		_s("ele_flame_wave", "Onda de Chamas", 5, "fogo", ["staff"], T_CONE, K_MAG, 1.6, 14, 6, "Chamas em cone (5 m) que queimam até 6 inimigos.", {"radius": 5.0, "cone_angle_deg": 75, "max_targets": 6, "dot": _dot(5, 3)}),
		_s("ele_combustion", "Combustão", 9, "fogo", ["staff"], T_TARGET, K_MAG, 2.1, 18, 9, "Marca o alvo sob o cursor e o faz explodir (2.6 m): suas queimaduras nos atingidos detonam na hora (125% do que faltava) e o fogo reacende em todos por 4s.",
			{"range": 9.0, "radius": 2.6, "max_targets": 6, "dot": _dot(7, 4), "combust": {"detonate": 1.25}, "startup": 0.3, "recovery": 0.3, "cancel_after": 0.15, "hit_stop_frames": 4}),
		_s("ele_fire_wall", "Muralha de Fogo", 13, "fogo", ["staff"], T_GROUND, K_MAG, 1.2, 22, 12, "Ergue uma muralha de fogo de 6 m atravessada no cursor: queima quem está nela e fica 5 s acesa, queimando quem passar (4 s de queimadura).",
			{"range": 8.0, "radius": 3.0, "dot": _dot(10, 4), "fire_wall": {"width": Balance.FIRE_WALL_WIDTH, "duration": Balance.FIRE_WALL_TIME, "pulse": Balance.FIRE_WALL_PULSE}}),
		# Preenchimento (GDD skills-fill-2026-11-19): semente que explode e espalha a queimadura ("seed")
		_s("ele_ember_seed", "Semente Ígnea", 17, "fogo", ["staff"], T_TARGET, K_MAG, 1.2, 18, 8,
			"Planta uma brasa no alvo sob o cursor: queima por 4 s e, em %.0f s (ou se ele morrer antes), explode em %.0f m: %d%% do MATK em até %d inimigos, que pegam fogo também." % [
				float(Balance.EMBER_SEED["delay"]), float(Balance.EMBER_SEED["radius"]), roundi(float(Balance.EMBER_SEED["power"]) * 100.0), int(Balance.EMBER_SEED["max_targets"])],
			{"range": 9.0, "startup": 0.25, "recovery": 0.25, "cancel_after": 0.12, "hit_stop_frames": 3, "vfx": "fire", "dot": _dot(8, 4),
			 "seed": Balance.EMBER_SEED, "icon_color": Color(1.0, 0.55, 0.25)}),
		_s("ele_inferno", "Inferno", 22, "fogo", ["staff"], T_SELF, K_MAG, 2.6, 30, 16, "Explosão de fogo ao redor.", {"radius": 4.0, "dot": _dot(10, 4)}),
		_s("ele_phoenix", "Fênix", 27, "fogo", ["staff"], T_DIR, K_MAG, 3.4, 36, 16, "Fênix atravessa tudo na linha e queima.", {"range": 11.0, "radius": 1.2, "projectile_speed": 16.0, "projectile_pierce": true, "dot": _dot(8, 3)}),
		# Gelo (cajado)
		_s("ele_ice_lance", "Lança de Gelo", 2, "gelo", ["staff"], T_DIR, K_MAG, 1.5, 8, 3, "Lança que retarda 35%.", {"range": 9.0, "radius": 0.4, "projectile_speed": 22.0, "slow": _slow(35, 2)}),
		_s("ele_frost_armor", "Armadura de Gelo", 8, "gelo", ["staff"], T_SELF, K_BUFF, 0.0, 16, 24, "Escudo de 15%% do HP por 8s e corta %d%% do dano recebido (+1%% a cada %d INT, até %d%%) por " % [int(Balance.FROST_ARMOR_DR_BASE), int(Balance.FROST_ARMOR_DR_PER_INT), int(Balance.FROST_ARMOR_DR_CAP)] + _keep_s() + ".", {"shield": {"amount_pct_hp": 15, "duration": 8}, "buff": {"id": "frost_armor", "duration": Balance.BUFF_KEEP_S, "dr_int": true}}),
		_s("ele_glacier", "Geleira", 12, "gelo", ["staff"], T_GROUND, K_MAG, 1.8, 20, 11, "Gelo prende inimigos por 1.5s.", {"range": 8.0, "radius": 2.4, "root": _dur(1.5)}),
		_s("ele_shatter", "Estilhaçar", 18, "gelo", ["staff"], T_TARGET, K_MAG, 2.8, 22, 10, "Estilhaça o alvo: atordoa 0.6s e fere ao redor.", {"range": 9.0, "radius": 1.5, "max_targets": 4, "stun": _dur(0.6)}),
		_s("ele_absolute_zero", "Zero Absoluto", 26, "gelo", ["staff"], T_SELF, K_MAG, 3.0, 36, 20, "Congela tudo ao redor por 1.5s.", {"radius": 4.5, "stun": _dur(1.5), "hit_stop_frames": 5}),
		# Raio (varinha)
		_s("ele_chain", "Corrente Elétrica", 4, "raio", ["staff"], T_TARGET, K_MAG, 1.6, 10, 4, "Raio salta para até 3 inimigos próximos.", {"range": 9.0, "radius": 3.0, "max_targets": 4}),
		_s("ele_static", "Campo Estático", 11, "raio", ["staff"], T_GROUND, K_MAG, 1.8, 16, 9, "Campo elétrico: dano e lentidão.", {"range": 8.0, "radius": 3.0, "slow": _slow(40, 2.5)}),
		_buff("ele_overload", "Sobrecarga", 16, "raio", ["staff"], 18, 24, "+30% MATK e +15% velocidade por 10s.", {"id": "overload", "duration": 10, "matk_pct": 30, "speed_pct": 15}),
		# Preenchimento (GDD skills-fill-2026-11-19): o mago móvel; teleporte que cai como raio (dash no GROUND pousa no cursor)
		_s("ele_bolt_step", "Passo Relampejante", 13, "raio", ["staff"], T_GROUND, K_MAG, 1.7, 14, 9,
			"Vira raio e reaparece no cursor (até 7 m): o pouso fere quem está a 2,4 m e pode atordoar.",
			{"range": 7.0, "radius": 2.4, "dash": 7.0, "startup": 0.1, "active": 0.15, "recovery": 0.2, "cancel_after": 0.1, "hit_stop_frames": 3,
			 "vfx": "lightning", "icon_color": Color(0.7, 0.8, 1.0)}),
		_s("ele_thunder", "Trovão", 21, "raio", ["staff"], T_GROUND, K_MAG, 2.8, 26, 12, "Trovão no cursor: atordoa 0.8s.", {"range": 9.0, "radius": 2.2, "stun": _dur(0.8), "hit_stop_frames": 5}),
		_s("ele_storm_lord", "Senhor da Tempestade", 28, "raio", ["staff"], T_GROUND, K_MAG, 3.6, 38, 18, "Tempestade elétrica gigante (4,2 m) no cursor.", {"range": 10.0, "radius": 4.2}),
	],
	"necromancer": [
		_s("nec_bone_spear", "Lança de Osso", 1, "", [], T_DIR, K_MAG, 1.2, 6, 2, "Projétil de osso.", {"range": 9.0, "radius": 0.4, "projectile_speed": 20.0}),
		# Invocador (cajado)
		_buff("nec_dark_pact", "Pacto Sombrio", 8, "invocador", ["scythe"], 16, 24, "+25% MATK por " + _keep_s() + " (invocações ficam mais fortes).", {"id": "dark_pact", "duration": Balance.BUFF_KEEP_S, "matk_pct": 25}),
		_s("nec_corpse_explosion", "Explosão de Cadáver", 16, "invocador", ["scythe"], T_GROUND, K_MAG, 2.4, 22, 10, "Explosão de carne no cursor.", {"range": 8.0, "radius": 3.0}),
		# Preenchimento (GDD skills-fill-2026-11-19): oferecer os próprios mortos-vivos ("sacrifice"); garra que puxa (geral)
		_s("nec_dark_offering", "Oferenda Sombria", 21, "invocador", ["scythe"], T_GROUND, K_MAG, 1.5, 20, 12,
			"Oferece até %d mortos-vivos seus a %.0f m do cursor: cada um explode em %.0f m (mais forte quanto mais vida ele tinha) e se desfaz. Sem nenhum por perto, não sai." % [
				int(Balance.DARK_OFFERING["max"]), float(Balance.DARK_OFFERING["pick_radius"]), float(Balance.DARK_OFFERING["blast_radius"])],
			{"range": 9.0, "radius": float(Balance.DARK_OFFERING["pick_radius"]), "startup": 0.3, "recovery": 0.3, "cancel_after": 0.15, "hit_stop_frames": 4,
			 "clip": "summon", "vfx": "bone", "sacrifice": Balance.DARK_OFFERING, "icon_color": Color(0.75, 0.9, 0.75)}),
		_s("nec_grave_grasp", "Garra da Cova", 16, "", [], T_TARGET, K_MAG, 1.2, 12, 8,
			"Uma mão de ossos sai do chão sob o alvo (até 9 m), puxa-o até você e o prende 1 s. Chefes não são puxados.",
			{"range": 9.0, "startup": 0.2, "recovery": 0.25, "cancel_after": 0.12, "hit_stop_frames": 3, "vfx": "shadow",
			 "pull": {"gap": 1.5}, "root": _dur(1.0), "icon_color": Color(0.6, 0.5, 0.8)}),
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
		_s("nec_bone_armor", "Armadura de Ossos", 18, "ceifador", ["scythe"], T_SELF, K_BUFF, 0.0, 20, 26, "Escudo de 20% do HP por 8s e +35% DEF por " + _keep_s() + ".", {"shield": {"amount_pct_hp": 20, "duration": 8}, "buff": {"id": "bone_armor", "duration": Balance.BUFF_KEEP_S, "def_pct": 35}}),
		_s("nec_grim", "Ceifeiro Sinistro", 26, "ceifador", ["scythe"], T_TARGET, K_MAG, 4.0, 32, 16, "Golpe final; cura 40% do dano.", {"range": 3.0, "heal_pct_of_dmg": 0.4, "hit_stop_frames": 6}),
		# Pestilento (varinha ou orbe)
		_s("nec_rot", "Podridão", 4, "pestilento", ["scythe"], T_TARGET, K_MAG, 0.6, 8, 4, "Apodrece o alvo por 6s.", {"range": 9.0, "dot": _dot(7, 6)}),
		_s("nec_swarm", "Enxame de Moscas", 11, "pestilento", ["scythe"], T_GROUND, K_MAG, 0.8, 16, 10, "Moscas: dano contínuo e lentidão.", {"range": 8.0, "radius": 2.5, "dot": _dot(9, 5), "slow": _slow(30, 3)}),
		_s("nec_decay", "Decadência", 17, "pestilento", ["scythe"], T_CONE, K_MAG, 1.4, 18, 8, "Cone de decadência que corrói.", {"radius": 4.5, "cone_angle_deg": 70, "dot": _dot(8, 5)}),
		_s("nec_pandemic", "Pandemia", 24, "pestilento", ["scythe"], T_GROUND, K_MAG, 1.4, 32, 18, "Doença em área enorme por 6s.", {"range": 9.0, "radius": 3.5, "dot": _dot(18, 6)}),
		# Ascensão (Ato II, 35 + missão hx_asc_necromancer): Senhor dos Mortos (NecroAscension). Fora da teia comum (teia de
		# ascensão, barra 7-0), de todas as builds. Com a ascensão as invocações já duram x1,5 e cabe +1 por tipo.
		_buff("nec_asc_pact", "Pacto dos Mortos", Balance.ASC_LEVEL, "", ["scythe"], 24, Balance.LORD_PACT_CD,
			"Pacto sombrio com os seus mortos: por 12 s as invocações a 15 m causam +25% de dano, andam 20% mais rápido e 10% do dano delas cura você. Só as que estão perto ao lançar.",
			{"id": "lord_pact", "duration": Balance.LORD_PACT_TIME},
			{"summon_pact": {"dmg_pct": Balance.LORD_PACT_DMG_PCT, "speed_pct": Balance.LORD_PACT_SPEED_PCT, "leech_pct": Balance.LORD_PACT_LEECH_PCT},
			 "startup": 0.2, "recovery": 0.25, "cancel_after": 0.1, "clip": "summon", "vfx": "shadow", "icon_color": Color(0.6, 0.35, 0.85), "ascension": true}),
		_s("nec_asc_miasma", "Miasma", Balance.ASC_LEVEL, "", ["scythe"], T_GROUND, K_MAG, 0.0, 22, Balance.LORD_MIASMA_CD,
			"Nuvem podre no ponto mirado por 8 s: inimigos dentro causam 20% menos dano e andam 15% mais devagar. Soma com as maldições. Uma nuvem por vez.",
			{"range": 9.0, "radius": Balance.LORD_MIASMA_RADIUS, "startup": 0.25, "recovery": 0.3, "cancel_after": 0.1,
			 "miasma": {"duration": Balance.LORD_MIASMA_TIME, "weaken_pct": Balance.LORD_MIASMA_WEAKEN_PCT, "slow_pct": Balance.LORD_MIASMA_SLOW_PCT},
			 "clip": "cast_ground", "vfx": "poison", "icon_color": Color(0.55, 0.75, 0.35), "ascension": true}),
		_s("nec_asc_grave_mark", "Marca da Cova", Balance.ASC_LEVEL, "", ["scythe"], T_GROUND, K_MAG, 0.0, 26, Balance.LORD_GRAVE_CD,
			"Marca os inimigos na área por 10 s: monstro comum que morrer marcado levanta como esqueleto aliado por 15 s (até 4 de pé). Chefes e elites não levantam.",
			{"range": 9.0, "radius": Balance.LORD_GRAVE_RADIUS, "startup": 0.25, "recovery": 0.3, "cancel_after": 0.1,
			 "grave_mark": {"duration": Balance.LORD_GRAVE_MARK_TIME, "raise": Balance.LORD_GRAVE_RAISE_TIME},
			 "clip": "cast_ground", "vfx": "bone", "icon_color": Color(0.8, 0.8, 0.7), "ascension": true}),
		_s("nec_asc_lich_form", "Forma de Lich", Balance.ASC_MAX_LEVEL, "", ["scythe"], T_SELF, K_BUFF, 0.0, 40, Balance.LORD_LICH_CD,
			"Vira um lich por 15 s: +30% MATK, as maldições que você lança passam para os inimigos a 4 m do alvo e cabe +1 invocação de cada tipo. Ao sair, as invocações a mais somem, da mais antiga para a mais nova.",
			{"form": "lich", "startup": 0.3, "recovery": 0.3, "clip": "buff_power", "vfx": "ice", "icon_color": Color(0.55, 0.85, 1.0), "ascension": true}),
	],
	}

## As 6 skills originais de cada classe (registradas antes das de `_more()`, nesta ordem).
## Supremas do nível 40 (GDD design/gdd/ultimates-lv40.md): uma por build, tecla R, sai com a Carga Suprema cheia
## (UltimateSystem). `ultimate: true` = fora da teia, da barra, do rank e da ClassDef.skill_ids (GameData.ultimates);
## custo 0 e sem recarga própria; `ult_bot` = regra do bot ("boss", "save", "self"). Números: Balance.ULT_NUMBERS[<id>].
## Onda A: só a do Fogo (prova o caminho inteiro); as outras 23 entram na onda B.
static func _ultimates() -> Dictionary:
	var mr: Dictionary = Balance.ULT_NUMBERS["ele_ult_meteor_rain"]
	return {
		"elementalist": [
			_s("ele_ult_meteor_rain", "Chuva de Meteoros", Balance.ULT_LEVEL, "fogo", ["staff"], T_SELF, K_MAG, float(mr["power"]), 0, 0.0,
				"Suprema (R): por %ds caem meteoros a até %dm de onde você lançou (um a cada %.1fs, a maioria sobre inimigos que ainda não queimam). Cada um queima. A chuva fica no lugar: você anda e lança à vontade." % [int(mr["duration"]), int(mr["radius"]), float(mr["every"])],
				{"ultimate": true, "ult_bot": "boss", "vfx": "fire", "clip": "cast_ground", "radius": 0.0, "startup": 0.3, "active": 0.1, "recovery": 0.35,
				 "hit_stop_frames": 0, "icon_color": Color(1, 0.45, 0.15),
				 "storm": {"anchor": "ground", "mode": "strikes", "duration": float(mr["duration"]), "every": float(mr["every"]), "radius": float(mr["radius"]),
					"strike_radius": float(mr["strike_radius"]), "bias": float(mr["bias"]), "warn": float(mr["warn"]), "prefer": "unburnt",
					"effects": {"dot": {"dps": float(mr["burn_dps"]), "duration": float(mr["burn_time"]), "fire": true}}}}),
		],
	}

## Supremas da onda B2 (GDD ultimates-lv40 §3.5, 13-24): Ranger, Assassino, Elementalista Gelo/Raio e Necromante.
## Bloco à parte (a onda A está em `_ultimates`, a B1 em `_ultimates_b1`); `load_all` junta todos. Números: Balance.ULT_NUMBERS[<id>].
static func _ultimates_b2() -> Dictionary:
	var N: Dictionary = Balance.ULT_NUMBERS
	var wb: Dictionary = N["ran_ult_wild_bond"]
	var es: Dictionary = N["ran_ult_end_shot"]
	var el: Dictionary = N["ran_ult_endless_lance"]
	var rt: Dictionary = N["ass_ult_royal_toxin"]
	var gd: Dictionary = N["ass_ult_grand_duel"]
	var fc: Dictionary = N["ass_ult_fleet_call"]
	var ew: Dictionary = N["ele_ult_eternal_winter"]
	var se: Dictionary = N["ele_ult_storm_eye"]
	var td: Dictionary = N["nec_ult_tide_of_dead"]
	var sr: Dictionary = N["nec_ult_soul_reaping"]
	var ve: Dictionary = N["nec_ult_void_eclipse"]
	return {
		# --- Ranger ---
		"ranger": [
			_s("ran_ult_wild_bond", "Laço Selvagem", Balance.ULT_LEVEL, "cacador", ["bow"], T_SELF, K_BUFF, 0.0, 0, 0.0,
				"Suprema (R): o lince volta (morto, com a vida cheia) e por %ds você e ele causam +%d%% de dano; ele cresce e resiste %d%% ao controle. Um 2º lince, espiritual, luta junto pelo mesmo tempo com %d%% da força." % [
					int(wb["duration"]), int(wb["atk_pct"]), int(wb["pet_cc_resist"]), roundi(float(wb["spirit_mult"]) * 100.0)],
				{"ultimate": true, "ult_bot": "boss", "vfx": "nature", "clip": "shout", "startup": 0.2, "active": 0.05, "recovery": 0.3, "cancel_after": 0.1,
				 "icon_color": Color(0.55, 0.9, 0.45), "buff": {"id": "wild_bond", "duration": float(wb["duration"]), "atk_pct": float(wb["atk_pct"])},
				 "pet_revive": {"skill": "ran_companion", "buff": {"id": "wild_bond_pet", "duration": float(wb["duration"]), "atk_pct": float(wb["atk_pct"]),
					"cc_resist_pct": float(wb["pet_cc_resist"]), "scale": float(wb["pet_grow"])},
					"spirit": {"mult": float(wb["spirit_mult"]), "duration": float(wb["duration"]), "buff": "wild_bond_spirit"}}}),
			_s("ran_ult_end_shot", "Disparo do Fim", Balance.ULT_LEVEL, "atirador", ["rifle"], T_DIR, K_PHYS, float(es["power"]), 0, 0.0,
				"Suprema (R): mira %.1fs parado (o dash cancela e a carga fica) e dispara um tiro de %dm que atravessa todos: crítico garantido, dano enorme no 1º (%d%% nos outros) e empurra %dm (chefes não)." % [
					float(es["aim"]), int(es["range"]), roundi(float(es["rest"]) * 100.0), int(es["push"])],
				{"ultimate": true, "ult_bot": "boss", "vfx": "fire", "range": float(es["range"]), "radius": float(es["width"]) * 0.5, "projectile_speed": float(es["speed"]),
				 "projectile_pierce": true, "startup": float(es["aim"]), "active": 0.05, "recovery": 0.4, "hit_stop_frames": 6, "icon_color": Color(1.0, 0.6, 0.25),
				 "sure_crit": true, "pierce_rest": float(es["rest"]), "knockback": {"dist": float(es["push"])}, "shot": true}),
			_s("ran_ult_endless_lance", "Lança Incansável", Balance.ULT_LEVEL, "lanceiro", ["spear"], T_DIR, K_PHYS, float(el["power"]), 0, 0.0,
				"Suprema (R): %d estocadas em %.1fs numa linha de %dm à frente (segue o cursor); cada uma faz sangrar e renova a Marca do Predador. No fim arremessa a lança (%dm): dano forte e prende %.1fs." % [
					int(el["ticks"]), float(el["channel"]), int(el["length"]), int(el["throw_range"]), float(el["throw_root"])],
				{"ultimate": true, "ult_bot": "boss", "vfx": "blood", "clip": "atk_thrust", "range": float(el["length"]), "radius": float(el["width"]) * 0.5,
				 "startup": 0.15, "active": float(el["channel"]), "recovery": 0.3, "hit_stop_frames": 2, "icon_color": Color(0.9, 0.35, 0.3),
				 "channel": {"ticks": int(el["ticks"])}, "dot": {"atk_pct": float(el["bleed_atk_pct"]), "duration": float(el["bleed_time"])},
				 "curse": {"id": "predator", "duration": 10.0, "taken_pct": 18},
				 "channel_end": {"power": float(el["throw_power"]), "range": float(el["throw_range"]), "speed": float(el["throw_speed"]), "root": float(el["throw_root"])}}),
		],
		# --- Assassino ---
		"assassin": [
			_s("ass_ult_royal_toxin", "Toxina Real", Balance.ULT_LEVEL, "laminas", ["dual_dagger"], T_TARGET, K_PHYS, float(rt["power"]), 0, 0.0,
				"Suprema (R): golpe que marca o alvo por %ds: os seus venenos nele causam %d%% do dano. No fim (ou se ele cair) todos os seus venenos nele explodem (%d%% do que faltava) e passam para os inimigos a %dm." % [
					int(rt["duration"]), roundi(float(rt["mult"]) * 100.0), roundi(float(rt["detonate"]) * 100.0), int(rt["spread"])],
				{"ultimate": true, "ult_bot": "boss", "vfx": "poison", "clip": "atk_finisher", "range": float(rt["range"]), "startup": 0.15, "active": 0.06, "recovery": 0.3,
				 "cancel_after": 0.12, "hit_stop_frames": 6, "icon_color": Color(0.55, 0.9, 0.3),
				 "dot_amp": {"mult": float(rt["mult"]), "duration": float(rt["duration"]), "detonate": float(rt["detonate"]), "spread_radius": float(rt["spread"])}}),
			_buff("ass_ult_grand_duel", "Duelo Supremo", Balance.ULT_LEVEL, "duelista", ["dual_sword"], 0, 0.0,
				"Suprema (R): por %ds apara todo golpe de perto num arco de %d° à sua frente (de chefe: -%d%%) e responde no máximo um a cada %.1fs; +%d de crítico. Cada aparo soma %d ao Duelo e cada golpe seu soma %d (até %d dos golpes; Duelo até %d). No fim sai um Golpe de Mestre grátis com o Ímpeto cheio, +%d%% por ponto de Duelo." % [
					int(gd["duration"]), int(gd["arc"]), roundi(Balance.RIPOSTE_BOSS_CUT * 100.0), float(gd["gap"]), int(gd["crit"]), int(gd["gain"]), int(gd["hit_gain"]),
					int(gd["hit_cap"]), int(gd["duel_cap"]), roundi(float(gd["duel_per"]) * 100.0)],
				{"id": "grand_duel", "duration": float(gd["duration"]), "crit": float(gd["crit"]), "end_cast": "ass_master", "end_power": float(gd["end_power"]),
				 "riposte_arc": float(gd["arc"]), "riposte_gain": int(gd["gain"]), "riposte_gap": float(gd["gap"]), "momentum_fill": true,
				 "duel_cap": int(gd["duel_cap"]), "hit_gain": int(gd["hit_gain"]), "hit_cap": int(gd["hit_cap"]), "duel_per": float(gd["duel_per"])},
				{"ultimate": true, "ult_bot": "boss", "riposte": true, "vfx": "physical", "clip": "buff_power", "startup": 0.1, "recovery": 0.15, "cancel_after": 0.05,
				 "icon_color": Color(0.85, 0.85, 1.0)}),
			_s("ass_ult_fleet_call", "Chamado da Frota", Balance.ULT_LEVEL, "corsario", ["pistol"], T_GROUND, K_PHYS, float(fc["power"]), 0, 0.0,
				"Suprema (R): um navio fora da vista bombardeia o ponto por %ds: %d balas de canhão em círculos de %dm (metade sobre inimigos), cada uma avisada antes, ferem e empurram. Bravata cheia." % [
					int(fc["duration"]), int(fc["shots"]), int(fc["strike_radius"])],
				{"ultimate": true, "ult_bot": "boss", "vfx": "fire", "clip": "shout", "range": float(fc["range"]), "radius": float(fc["radius"]), "startup": 0.2, "active": 0.05,
				 "recovery": 0.3, "cancel_after": 0.1, "hit_stop_frames": 0, "icon_color": Color(0.95, 0.75, 0.35), "combo_gain": Balance.BRAVADO_MAX,
				 "storm": {"anchor": "ground", "mode": "strikes", "duration": float(fc["duration"]), "every": float(fc["duration"]) / float(fc["shots"]),
					"radius": float(fc["radius"]), "strike_radius": float(fc["strike_radius"]), "bias": float(fc["bias"]), "warn": float(fc["warn"]),
					"effects": {"knockback": {"dist": float(fc["push"])}}}}),
		],
		# --- Elementalista (Gelo e Raio; a do Fogo está em _ultimates) ---
		"elementalist": [
			_s("ele_ult_eternal_winter", "Inverno Eterno", Balance.ULT_LEVEL, "gelo", ["staff"], T_GROUND, K_MAG, float(ew["power"]), 0, 0.0,
				"Suprema (R): tempestade de gelo presa no ponto (%dm) por %ds. A cada %ds fere quem está dentro e deixa %d%% mais lento (acumula até %d%%); no %dº pulso o alvo congela %ds (chefe menos; uma vez por lançamento). O gelo estilhaça em quem está lento." % [
					int(ew["radius"]), int(ew["duration"]), int(ew["every"]), int(ew["slow_step"]), int(ew["slow_max"]), int(ew["freeze_hits"]), int(ew["freeze"])],
				{"ultimate": true, "ult_bot": "boss", "vfx": "ice", "clip": "cast_ground", "range": float(ew["range"]), "radius": float(ew["radius"]), "startup": 0.3,
				 "active": 0.1, "recovery": 0.35, "hit_stop_frames": 0, "icon_color": Color(0.6, 0.85, 1.0), "elements": ["frost"],
				 "storm": {"anchor": "ground", "mode": "pulse", "duration": float(ew["duration"]), "every": float(ew["every"]), "radius": float(ew["radius"]),
					"slow_stack": {"step": float(ew["slow_step"]), "max": float(ew["slow_max"]), "duration": float(ew["slow_time"])},
					"freeze": {"hits": int(ew["freeze_hits"]), "duration": float(ew["freeze"])}}}),
			_s("ele_ult_storm_eye", "Olho da Tempestade", Balance.ULT_LEVEL, "raio", ["staff"], T_SELF, K_MAG, float(se["power"]), 0, 0.0,
				"Suprema (R): por %ds a tempestade anda com você (%dm): a cada %.1fs um raio cai num inimigo (prefere quem não levou agora), salta para %d vizinhos e pode atordoar. Você fica %d%% mais rápido e o Passo Relampejante volta na hora." % [
					int(se["duration"]), int(se["radius"]), float(se["every"]), int(se["chain"]), int(se["speed_pct"])],
				{"ultimate": true, "ult_bot": "boss", "vfx": "lightning", "clip": "buff_power", "startup": 0.2, "active": 0.05, "recovery": 0.3, "cancel_after": 0.1,
				 "hit_stop_frames": 0, "icon_color": Color(0.7, 0.8, 1.0), "elements": ["storm"],
				 "buff": {"id": "storm_eye", "duration": float(se["duration"]), "speed_pct": float(se["speed_pct"])}, "cd_reset": ["ele_bolt_step"],
				 "storm": {"anchor": "caster", "mode": "strikes", "duration": float(se["duration"]), "every": float(se["every"]), "radius": float(se["radius"]),
					"strike_radius": float(se["strike_radius"]), "bias": 1.0, "warn": 0.0, "prefer": "fresh", "fresh_s": float(se["fresh"]),
					"chain": {"count": int(se["chain"]), "radius": float(se["chain_radius"]), "falloff": float(se["falloff"])},
					"stun_chance": {"pct": float(se["stun_pct"]), "duration": float(se["stun"])}}}),
		],
		# --- Necromante ---
		"necromancer": [
			_s("nec_ult_tide_of_dead", "Maré dos Mortos", Balance.ULT_LEVEL, "invocador", ["scythe"], T_SELF, K_SUMMON, float(td["blast_power"]), 0, 0.0,
				"Suprema (R): ergue %d esqueletos por %ds fora do limite de invocações. Por %ds você ganha +%d%% de MATK e suas invocações atacam %d%% mais rápido. Quando os esqueletos se desfazem, explodem (%dm; mais forte quanto mais vida eles tinham)." % [
					int(td["count"]), int(td["duration"]), int(td["buff_time"]), int(td["matk_pct"]), int(td["summon_aspd"]), int(td["blast_radius"])],
				{"ultimate": true, "ult_bot": "boss", "vfx": "bone", "clip": "summon", "startup": 0.3, "active": 0.05, "recovery": 0.35, "cancel_after": 0.12,
				 "icon_color": Color(0.75, 0.9, 0.75), "buff": {"id": "tide_of_dead", "duration": float(td["buff_time"]), "matk_pct": float(td["matk_pct"])},
				 "summon": {"monster_id": "skeleton_minion", "count": int(td["count"]), "duration": float(td["duration"]), "max": int(td["count"]), "ignore_max": true,
					"buff_first": true, "summon_buff": {"id": "tide_frenzy", "duration": float(td["buff_time"]), "aspd_pct": float(td["summon_aspd"])},
					"expire_blast": {"radius": float(td["blast_radius"]), "power": float(td["blast_power"])}}}),
			_s("nec_ult_soul_reaping", "Ceifa das Almas", Balance.ULT_LEVEL, "ceifador", ["scythe"], T_SELF, K_MAG, float(sr["power"]), 0, 0.0,
				"Suprema (R): giro enorme da foice (%dm): cura %d%% da vida por inimigo atingido (até %d) e depois +%d%% de ATK/MATK e +%d de roubo de vida por %ds. Demoníaca: o giro bate mais forte; Fantasma: avança no giro." % [
					int(sr["radius"]), int(sr["heal_pct"]), int(sr["heal_max"]), int(sr["atk_pct"]), int(sr["lifesteal"]), int(sr["buff_time"])],
				{"ultimate": true, "ult_bot": "self", "vfx": "shadow", "clip": "atk_spin", "radius": float(sr["radius"]), "startup": 0.2, "active": 0.25, "recovery": 0.35,
				 "cancel_after": 0.15, "hit_stop_frames": 6, "icon_color": Color(0.6, 0.3, 0.75),
				 "hit_heal": {"pct": float(sr["heal_pct"]), "max": int(sr["heal_max"])},
				 "buff": {"id": "soul_reaping", "duration": float(sr["buff_time"]), "atk_pct": float(sr["atk_pct"]), "matk_pct": float(sr["matk_pct"]), "lifesteal": float(sr["lifesteal"])}}),
			_s("nec_ult_void_eclipse", "Eclipse do Vazio", Balance.ULT_LEVEL, "pestilento", ["scythe"], T_GROUND, K_MAG, float(ve["power"]), 0, 0.0,
				"Suprema (R): disco de vazio (%dm) no ponto por %ds: quem está dentro fica %d%% mais lento, recebe cópia das suas maldições e os seus danos no tempo nele valem %d%%. No fim implode: puxa todos ao centro (chefes não) e fere." % [
					int(ve["radius"]), int(ve["duration"]), int(ve["slow"]), roundi(float(ve["amp"]) * 100.0)],
				{"ultimate": true, "ult_bot": "boss", "vfx": "shadow", "clip": "cast_ground", "range": float(ve["range"]), "radius": float(ve["radius"]), "startup": 0.3,
				 "active": 0.1, "recovery": 0.35, "hit_stop_frames": 5, "icon_color": Color(0.45, 0.25, 0.7),
				 "storm": {"anchor": "ground", "mode": "pulse", "duration": float(ve["duration"]), "every": float(ve["every"]), "radius": float(ve["radius"]), "strike_mult": 0.0,
					"slow_stack": {"step": float(ve["slow"]), "max": float(ve["slow"]), "duration": float(ve["every"]) + 0.3, "frost": false},
					"effects": {"dot_amp": {"mult": float(ve["amp"]), "duration": float(ve["every"]) + 0.3}, "curse_spread": {"radius": float(ve["curse_radius"])}},
					"end": {"power": float(ve["power"]), "radius": float(ve["radius"]), "pull": true}}}),
		],
	}

static func _originals() -> Dictionary:
	return {
	"paladin": [
		_s("pal_holy_strike", "Golpe Sagrado", 1, "", [], T_CONE, K_PHYS, 1.6, 8, 3.0, "Golpe frontal com luz. Cura 15% do dano causado.",
			{"radius": 2.4, "cone_angle_deg": 90, "startup": 0.14, "active": 0.06, "recovery": 0.3, "cancel_after": 0.12, "icon_color": Color(1, 0.95, 0.6), "heal_pct_of_dmg": 0.15, "mastery": _mastery({3: {"heal_pct_of_dmg": 0.25}, 5: {"heal_pct_of_dmg": 0.35}})}),
		_s("pal_shield_bash", "Pancada de Escudo", 3, "guardiao", ["shield"], T_DIR, K_PHYS, 1.1, 10, 7.0, "Avança e atordoa o alvo à frente por 1s.",
			{"range": 3.0, "radius": 0.9, "max_targets": 1, "startup": 0.1, "active": 0.08, "recovery": 0.3, "icon_color": Color(0.8, 0.8, 0.9), "stun": {"duration": 1.0}, "dash": 1.5, "mastery": _mastery({2: {"stun": {"duration": 1.3}}, 4: {"stun": {"duration": 1.6}}})}),
		_s("pal_consecrate", "Consagração", 6, "cruzado", ["two_handed"], T_SELF, K_MAG, 1.4, 16, 9.0, "Abençoa o chão: dano sagrado em área ao redor.",
			{"radius": 3.2, "startup": 0.25, "active": 0.1, "recovery": 0.4, "icon_color": Color(1, 0.9, 0.4)}),
		_s("pal_lay_hands", "Imposição de Mãos", 10, "", [], T_SELF, K_HEAL, 2.2, 22, 14.0, "Cura forte em si mesmo (ou aliado próximo).",
			{"radius": 2.0, "startup": 0.3, "active": 0.05, "recovery": 0.35, "icon_color": Color(1, 1, 0.8)}),
		_s("pal_taunt", "Provocar", 8, "guardiao", ["shield"], T_SELF, K_BUFF, 0.0, 12, 12.0, "Prende os inimigos em 7 m em você por 4s (chefes: 2s) e ganha +25% DEF por 6s.",
			{"radius": 7.0, "startup": 0.1, "active": 0.05, "recovery": 0.25, "icon_color": Color(1, 0.6, 0.4), "taunt": {"duration": 4}, "buff": {"id": "bulwark", "duration": 6, "def_pct": 25}}),
		_s("pal_divine_shield", "Escudo Divino", 20, "guardiao", ["shield"], T_SELF, K_BUFF, 0.0, 28, 22.0, "Escudo que absorve 25% do HP máximo por 6s.",
			{"radius": 0.0, "startup": 0.15, "active": 0.05, "recovery": 0.2, "icon_color": Color(1, 1, 0.5), "shield": {"amount_pct_hp": 25, "duration": 6}, "mastery": _mastery({2: {"shield": {"amount_pct_hp": 32, "duration": 6}}, 4: {"shield": {"amount_pct_hp": 40, "duration": 7}}})}),
	],
	"berserker": [
		_s("ber_cleave", "Rachar", 1, "", [], T_CONE, K_PHYS, 1.8, 9, 3.5, "Golpe largo que acerta até 4 inimigos.",
			{"radius": 2.8, "cone_angle_deg": 120, "max_targets": 4, "startup": 0.18, "active": 0.06, "recovery": 0.35, "hit_stop_frames": 4, "icon_color": Color(1, 0.45, 0.3)}),
		_s("ber_leap", "Salto Selvagem", 3, "", [], T_GROUND, K_PHYS, 1.9, 12, 8.0, "Salta até o ponto do cursor e esmaga o chão.",
			{"range": 6.0, "radius": 2.2, "startup": 0.2, "active": 0.1, "recovery": 0.35, "icon_color": Color(1, 0.6, 0.3), "dash": 5.5, "slow": {"pct": 30, "duration": 1.5}}),
		_s("ber_whirlwind", "Redemoinho", 6, "executor", ["two_handed"], T_SELF, K_PHYS, 2.2, 18, 10.0, "Gira a arma: dano em todos ao redor.",
			{"radius": 3.0, "startup": 0.2, "active": 0.3, "recovery": 0.4, "icon_color": Color(1, 0.5, 0.5)}),
		_s("ber_fury", "Fúria", 10, "", [], T_SELF, K_BUFF, 0.0, 15, 20.0, "+35% ATK e +15% velocidade por 8s.",
			{"radius": 0.0, "startup": 0.1, "active": 0.05, "recovery": 0.2, "icon_color": Color(1, 0.3, 0.2), "buff": {"id": "fury", "duration": 8, "atk_pct": 35, "speed_pct": 15}}),
		_s("ber_execute", "Executar", 15, "executor", ["two_handed"], T_TARGET, K_PHYS, 3.1, 20, 12.0, "Golpe devastador em um alvo. Dano enorme. Gasta a rachadura: +%d%% de dano por carga." % roundi(float(Balance.SUNDER_CONSUME["per"]) * 100.0),
			{"sunder_consume": Balance.SUNDER_CONSUME, "range": 2.6, "radius": 0.0, "startup": 0.3, "active": 0.06, "recovery": 0.5, "hit_stop_frames": 6, "icon_color": Color(0.9, 0.2, 0.2), "max_targets": 99}),
		_s("ber_warcry", "Grito de Guerra", 20, "", [], T_SELF, K_MAG, 1.4, 22, 20.0, "Brado que fere e atordoa inimigos a 4.5 m por 1.2s; você ganha +20% ATK por 8s.",
			{"radius": 4.5, "startup": 0.2, "active": 0.05, "recovery": 0.3, "icon_color": Color(1, 0.8, 0.5), "stun": {"duration": 1.2}, "buff": {"id": "warcry", "duration": 8, "atk_pct": 20}}),
	],
	"bishop": [
		_s("bis_heal", "Curar", 1, "", [], T_TARGET, K_HEAL, 1.5, 14, 2.5, "Cura o aliado do grupo sob o cursor (ou você).",
			{"range": 12.0, "radius": 0.0, "max_targets": 5, "startup": 0.3, "active": 0.05, "recovery": 0.25, "lock_facing": false, "icon_color": Color(0.8, 1, 0.8)}),
		_s("bis_smite", "Castigar", 3, "inquisidor", [], T_DIR, K_MAG, 1.7, 12, 3.0, "Raio de luz que atravessa inimigos.",
			{"range": 8.0, "radius": 0.5, "projectile_speed": 20.0, "projectile_pierce": true, "startup": 0.2, "active": 0.05, "recovery": 0.3, "icon_color": Color(1, 1, 0.7)}),
		_s("bis_blessing", "Bênção", 6, "sacerdote", ["mace", "shield"], T_SELF, K_BUFF, 0.0, 20, 25.0, "+20% ATK/MATK e +5 crit para aliados próximos por " + _keep_s() + ".",
			{"radius": 6.0, "startup": 0.25, "active": 0.05, "recovery": 0.3, "icon_color": Color(1, 0.95, 0.6), "buff": {"id": "blessing", "duration": Balance.BUFF_KEEP_S, "atk_pct": 20, "matk_pct": 20, "crit": 5}}),
		_s("bis_sanctuary", "Santuário", 10, "sacerdote", ["mace", "shield"], T_GROUND, K_HEAL, 1.2, 26, 12.0, "Cura em área no ponto do cursor.",
			{"range": 8.0, "radius": 3.0, "startup": 0.35, "active": 0.05, "recovery": 0.35, "icon_color": Color(0.9, 1, 0.9)}),
		_s("bis_purify", "Purificar", 15, "inquisidor", ["scepter"], T_CONE, K_MAG, 1.5, 18, 8.0, "Explosão sagrada: dano e lentidão em cone.",
			{"radius": 4.5, "cone_angle_deg": 80, "startup": 0.25, "active": 0.05, "recovery": 0.35, "icon_color": Color(1, 1, 0.9), "slow": {"pct": 40, "duration": 2.5}}),
		_s("bis_judgement", "Julgamento", 20, "inquisidor", ["scepter"], T_GROUND, K_MAG, 2.8, 32, 18.0, "Pilar de luz no cursor: dano alto e atordoa.",
			{"range": 9.0, "radius": 2.2, "startup": 0.45, "active": 0.05, "recovery": 0.4, "hit_stop_frames": 5, "icon_color": Color(1, 0.95, 0.5), "stun": {"duration": 1.0}}),
	],
	"druid": [
		_s("dru_thorns", "Espinhos", 1, "", [], T_DIR, K_MAG, 1.3, 9, 2.5, "Lança espinhos envenenados na direção do cursor.",
			{"range": 8.0, "radius": 0.4, "projectile_speed": 18.0, "startup": 0.15, "active": 0.05, "recovery": 0.25, "icon_color": Color(0.5, 0.9, 0.4), "dot": {"dps": 4, "duration": 4}}),
		_s("dru_entangle", "Enraizar", 3, "", [], T_GROUND, K_MAG, 0.6, 15, 10.0, "Raízes prendem inimigos na área por 2.5s.",
			{"range": 8.0, "radius": 2.5, "startup": 0.25, "active": 0.05, "recovery": 0.3, "icon_color": Color(0.4, 0.7, 0.3), "root": {"duration": 2.5}}),
		_s("dru_regrowth", "Rebrotar", 6, "", [], T_SELF, K_HEAL, 1.3, 18, 8.0, "Cura a si e aliados próximos.",
			{"radius": 4.0, "startup": 0.3, "active": 0.05, "recovery": 0.3, "icon_color": Color(0.6, 1, 0.6)}),
		_s("dru_swarm", "Enxame", 10, "xama", ["staff"], T_CONE, K_MAG, 1.0, 20, 9.0, "Insetos devoram inimigos em cone (dano contínuo).",
			{"radius": 5.0, "cone_angle_deg": 70, "startup": 0.2, "active": 0.05, "recovery": 0.3, "icon_color": Color(0.7, 0.6, 0.2), "dot": {"dps": 7, "duration": 5}, "slow": {"pct": 25, "duration": 3}}),
		_s("dru_bear_form", "Forma de Urso", 3, "guardiao_verde", ["mace2h"], T_SELF, K_BUFF, 0.0, 10, 1.5, "Vira urso (lance de novo para voltar): +40% DEF, +25% HP, +10% ATK, 150% mais ameaça, um pouco mais lento. As skills do Guardião viram golpes de urso.",
			{"radius": 0.0, "startup": 0.25, "active": 0.05, "recovery": 0.25, "icon_color": Color(0.55, 0.4, 0.25), "form": "bear"}),
		_s("dru_wild_growth", "Crescimento Selvagem", 20, "xama", ["staff"], T_GROUND, K_MAG, 2.6, 34, 20.0, "Floresta explode no cursor: dano alto + raízes.",
			{"range": 9.0, "radius": 3.2, "startup": 0.4, "active": 0.05, "recovery": 0.4, "icon_color": Color(0.3, 0.9, 0.4), "root": {"duration": 1.5}}),
	],
	"ranger": [
		_s("ran_power_shot", "Tiro Poderoso", 1, "", ["bow", "rifle"], T_DIR, K_PHYS, 2.0, 8, 3.0, "Flecha perfurante de longo alcance.",
			{"range": 12.0, "radius": 0.4, "projectile_speed": 28.0, "projectile_pierce": true, "startup": 0.22, "active": 0.05, "recovery": 0.3, "icon_color": Color(0.7, 1, 0.7)}),
		_s("ran_multishot", "Tiro Múltiplo", 3, "cacador", ["bow"], T_CONE, K_PHYS, 1.3, 12, 5.0, "Leque de flechas à frente, quase no alcance do arco.",
			{"radius": 11.0, "cone_angle_deg": 70, "max_targets": 6, "startup": 0.18, "active": 0.05, "recovery": 0.3, "icon_color": Color(0.8, 1, 0.6)}),
		_s("ran_disengage", "Recuar", 1, "", [], T_SELF, K_BUFF, 0.0, 8, 9.0, "Salta para trás e ganha +30% de velocidade por 3s.",
			{"radius": 0.0, "startup": 0.05, "active": 0.05, "recovery": 0.15, "lock_facing": true, "icon_color": Color(0.6, 0.9, 0.9), "dash": -4.5, "buff": {"id": "swift", "duration": 3, "speed_pct": 30}}),
		_s("ran_trap", "Armadilha de Mandíbula", 3, "atirador", ["bow", "rifle", "spear"], T_GROUND, K_PHYS, 1.6, 12, 6.0, "Coloca no chão uma armadilha (até 3): quem pisar fica preso 2.5s e sofre dano.",
			{"range": 7.0, "radius": 1.4, "startup": 0.25, "active": 0.05, "recovery": 0.3, "icon_color": Color(0.7, 0.6, 0.4), "trap": {"kind": "jaw", "duration": 30.0, "hit_radius": 1.4}, "root": {"duration": 2.5}}),
		_s("ran_mark", "Foco Mortal", 15, "atirador", ["bow", "rifle", "spear"], T_SELF, K_BUFF, 0.0, 16, 22.0, "+40% ATK e +15 crit por 8s.",
			{"radius": 0.0, "startup": 0.1, "active": 0.05, "recovery": 0.2, "icon_color": Color(1, 0.8, 0.4), "buff": {"id": "mark", "duration": 8, "atk_pct": 40, "crit": 15}}),
		_s("ran_rain", "Chuva de Flechas", 20, "cacador", ["bow"], T_GROUND, K_PHYS, 2.4, 30, 18.0, "Chuva de flechas em grande área no cursor.",
			{"range": 11.0, "radius": 3.8, "startup": 0.4, "active": 0.05, "recovery": 0.4, "icon_color": Color(0.6, 0.8, 1), "slow": {"pct": 30, "duration": 2}}),
	],
	"assassin": [
		_s("ass_backstab", "Apunhalar", 1, "", ["dagger", "sword"], T_TARGET, K_PHYS, 1.7, 7, 2.5, "Golpe rápido com chance de crítico altíssima (pelas costas, ainda mais).",
			# C8 2026-11-23: pesada (2,4x o básico) -> preparo 0,2 s pela regra (GameData._heavy_startup); recuperação 0,22 -> 0,3 para o
			# atk_flurry não correr demais depois do impacto (combat_probe)
			{"range": 2.2, "startup": 0.2, "active": 0.05, "recovery": 0.3, "cancel_after": 0.05, "icon_color": Color(0.8, 0.5, 1), "buff": {"id": "focus", "duration": 0.3, "crit": 40}, "radius": 1.5, "max_targets": 99}),
		_s("ass_shadowstep", "Passo das Sombras", 3, "", [], T_GROUND, K_PHYS, 1.2, 12, 7.0, "Teleporta até o cursor e corta tudo ao redor.",
			{"range": 7.0, "radius": 1.8, "startup": 0.05, "active": 0.05, "recovery": 0.25, "icon_color": Color(0.5, 0.3, 0.7), "dash": 6.5}),
		_s("ass_poison", "Lâmina Venenosa", 6, "laminas", ["dual_dagger"], T_CONE, K_PHYS, 1.1, 10, 6.0, "Corte em cone que envenena por 6s.",
			{"radius": 2.3, "cone_angle_deg": 100, "startup": 0.1, "active": 0.05, "recovery": 0.25, "icon_color": Color(0.4, 0.9, 0.3), "dot": {"dps": 6, "duration": 6}}),
		_s("ass_fan", "Leque de Facas", 10, "laminas", [], T_SELF, K_PHYS, 1.5, 16, 9.0, "Lança facas em todas as direções.",
			{"radius": 4.5, "startup": 0.15, "active": 0.05, "recovery": 0.3, "icon_color": Color(0.8, 0.8, 0.9)}),
		_s("ass_smoke", "Cortina de Fumaça", 15, "", [], T_SELF, K_MAG, 0.3, 18, 16.0, "Lentidão em área e +25% velocidade própria.",
			{"radius": 4.0, "startup": 0.1, "active": 0.05, "recovery": 0.2, "icon_color": Color(0.5, 0.5, 0.55), "slow": {"pct": 50, "duration": 3}, "buff": {"id": "smoke", "duration": 4, "speed_pct": 25}}),
		_s("ass_execute", "Golpe Mortal", 20, "", [], T_TARGET, K_PHYS, 3.6, 24, 14.0, "Dano brutal em um alvo isolado.",
			{"range": 2.4, "startup": 0.2, "active": 0.05, "recovery": 0.4, "hit_stop_frames": 6, "icon_color": Color(0.9, 0.2, 0.5), "radius": 1.5, "max_targets": 99}),
	],
	"elementalist": [
		_s("ele_fireball", "Bola de Fogo", 1, "", [], T_DIR, K_MAG, 1.7, 11, 2.5, "Projétil de fogo que explode no impacto (1,5 m): o alvo leva o golpe cheio, quem está em volta 45%, e todos queimam por 3s.",
			{"range": 9.0, "radius": 0.5, "projectile_speed": 16.0, "explode": {"radius": Balance.FIREBALL_EXPLODE_RADIUS, "power_pct": Balance.FIREBALL_EXPLODE_PCT}, "startup": 0.22, "active": 0.05, "recovery": 0.3, "icon_color": Color(1, 0.5, 0.2), "dot": {"dps": 5, "duration": 3}}),
		_s("ele_frost_nova", "Nova de Gelo", 3, "gelo", ["staff"], T_SELF, K_MAG, 1.85, 16, 9.0,     # C6: 1,5 -> 1,85 (skill_audit 54% -> 63%)
			 "Congela e retarda tudo ao redor.",
			{"radius": 3.5, "startup": 0.15, "active": 0.05, "recovery": 0.3, "icon_color": Color(0.6, 0.9, 1), "root": {"duration": 1.2}, "slow": {"pct": 50, "duration": 3}}),
		_s("ele_lightning", "Relâmpago", 6, "raio", ["staff"], T_DIR, K_MAG, 2.0, 14, 4.0, "Raio instantâneo em linha reta.",
			{"range": 10.0, "radius": 0.6, "max_targets": 3, "startup": 0.2, "active": 0.05, "recovery": 0.3, "hit_stop_frames": 4, "icon_color": Color(0.8, 0.8, 1)}),
		_s("ele_meteor", "Meteoro", 10, "fogo", ["staff"], T_GROUND, K_MAG, 3.0, 30, 14.0, "Meteoro cai no cursor: dano enorme em área.",
			{"range": 10.0, "radius": 3.0, "startup": 0.55, "active": 0.05, "recovery": 0.45, "hit_stop_frames": 6, "icon_color": Color(1, 0.4, 0.1), "dot": {"dps": 6, "duration": 3}}),
		_s("ele_blink", "Piscar", 15, "", [], T_SELF, K_MOVE, 0.0, 10, 8.0, "Teleporta curta distância na direção do cursor.",
			{"radius": 0.0, "startup": 0.02, "active": 0.02, "recovery": 0.1, "icon_color": Color(0.7, 0.6, 1), "dash": 6.0}),
		_s("ele_blizzard", "Nevasca", 20, "gelo", ["staff"], T_GROUND, K_MAG, 2.6, 38, 20.0, "Tempestade de gelo gigante no cursor.",
			{"range": 10.0, "radius": 4.5, "startup": 0.5, "active": 0.05, "recovery": 0.5, "icon_color": Color(0.5, 0.8, 1), "slow": {"pct": 60, "duration": 4}, "dot": {"dps": 5, "duration": 4}}),
	],
	"necromancer": [
		_s("nec_drain", "Drenar Vida", 1, "", [], T_DIR, K_MAG, 1.4, 10, 5.0, "Dreno sombrio: cura 20% do dano.",
			{"range": 7.0, "radius": 0.7, "max_targets": 1, "startup": 0.2, "active": 0.05, "recovery": 0.3, "icon_color": Color(0.4, 1, 0.6), "heal_pct_of_dmg": 0.2}),
		_s("nec_raise", "Erguer Mortos", 3, "invocador", ["scythe"], T_SELF, K_SUMMON, 0.0, 22, 12.0, "Invoca 2 esqueletos por 25s (máx 3).",
			{"radius": 0.0, "startup": 0.4, "active": 0.05, "recovery": 0.3, "icon_color": Color(0.7, 0.9, 0.7), "summon": {"monster_id": "skeleton_minion", "count": 2, "duration": 25, "max": 3}, "mastery": _mastery({2: {"summon": {"monster_id": "skeleton_minion", "count": 2, "duration": 30, "max": 4}}, 4: {"summon": {"monster_id": "skeleton_minion", "count": 3, "duration": 35, "max": 5}}})}),
		_s("nec_plague", "Praga", 6, "pestilento", ["scythe"], T_GROUND, K_MAG, 0.8, 18, 9.0, "Nuvem de doença no cursor: dano contínuo forte.",
			{"range": 9.0, "radius": 3.0, "startup": 0.3, "active": 0.05, "recovery": 0.3, "icon_color": Color(0.5, 0.7, 0.3), "dot": {"dps": 9, "duration": 6}, "slow": {"pct": 20, "duration": 3}}),
		_s("nec_bone_wall", "Muralha de Ossos", 10, "", [], T_SELF, K_BUFF, 0.0, 20, 24.0, "Escudo de ossos (20% HP) e +20% DEF por 6s.",
			{"radius": 0.0, "startup": 0.15, "active": 0.05, "recovery": 0.25, "icon_color": Color(0.9, 0.9, 0.8), "shield": {"amount_pct_hp": 20, "duration": 6}, "buff": {"id": "bonewall", "duration": 6, "def_pct": 20}}),
		_s("nec_curse", "Maldição", 15, "pestilento", ["scythe"], T_CONE, K_MAG, 1.6, 20, 10.0, "Cone de trevas: dano e lentidão pesada.",
			{"radius": 5.0, "cone_angle_deg": 75, "startup": 0.25, "active": 0.05, "recovery": 0.35, "icon_color": Color(0.5, 0.2, 0.6), "slow": {"pct": 45, "duration": 3}}),
		_s("nec_harvest", "Colheita Sombria", 20, "ceifador", ["scythe"], T_SELF, K_MAG, 3.4, 36, 18.0, "Explosão de almas: dano alto em área e cura 25%.",
			{"radius": 4.5, "startup": 0.45, "active": 0.05, "recovery": 0.45, "hit_stop_frames": 5, "icon_color": Color(0.3, 1, 0.7), "heal_pct_of_dmg": 0.25}),
	],
	}

## Supremas da onda B1 (GDD design/gdd/ultimates-lv40.md §3.5 1-12): Paladino, Berserker, Bispo, Druida.
## Somadas às de `_ultimates()` em `build()`. Números: Balance.ULT_NUMBERS[<id>].
static func _ultimates_b1() -> Dictionary:
	var U: Dictionary = Balance.ULT_NUMBERS
	var bas: Dictionary = U["pal_ult_dawn_bastion"]
	var jud: Dictionary = U["pal_ult_dawn_judgement"]
	var sky: Dictionary = U["pal_ult_hammer_sky"]
	var fea: Dictionary = U["ber_ult_blood_feast"]
	var ver: Dictionary = U["ber_ult_headsman_verdict"]
	var win: Dictionary = U["ber_ult_seven_winds"]
	var dom: Dictionary = U["bis_ult_grace_dome"]
	var sun: Dictionary = U["bis_ult_judgement_sun"]
	var ava: Dictionary = U["bis_ult_faith_avatar"]
	var col: Dictionary = U["dru_ult_primal_colossus"]
	var moo: Dictionary = U["dru_ult_blood_moon"]
	var elh: Dictionary = U["dru_ult_elder_heart"]
	var penance := {"id": "penance", "duration": float(sky["penance_time"]), "taken_pct": float(sky["penance_pct"])}
	return {
		"paladin": [
			_s("pal_ult_dawn_bastion", "Bastião da Aurora", Balance.ULT_LEVEL, "guardiao", ["shield"], T_SELF, K_BUFF, 0.0, 0, 0.0,
				"Suprema (R): finca um estandarte de luz. Provoca os inimigos a %dm (%ds; chefes: metade), ganha escudo de %d%% da vida por %ds e o Juramento enche. Por %ds, aliados a %dm recebem %d%% menos dano: essa parte vem para você (passa pela sua DEF, bloqueio e escudo). Acaba sozinha se você cair abaixo de %d%% da vida." % [
					int(bas["radius"]), int(bas["taunt"]), int(bas["shield_pct"]), int(bas["duration"]), int(bas["duration"]), int(bas["radius"]), int(bas["pct"]), int(bas["stop_below"])],
				{"ultimate": true, "ult_bot": "save", "vfx": "holy", "clip": "buff_power", "radius": float(bas["radius"]), "startup": 0.25, "active": 0.05, "recovery": 0.3,
				 "cancel_after": 0.1, "hit_stop_frames": 4, "icon_color": Color(1.0, 0.86, 0.45),
				 "taunt": {"duration": float(bas["taunt"])}, "shield": {"amount_pct_hp": float(bas["shield_pct"]), "duration": float(bas["duration"])},
				 "intercept": {"radius": float(bas["radius"]), "pct": float(bas["pct"]), "duration": float(bas["duration"]), "stop_below": float(bas["stop_below"])},
				 "oath_fill": true}),
			_s("pal_ult_dawn_judgement", "Juízo da Alvorada", Balance.ULT_LEVEL, "cruzado", ["two_handed"], T_GROUND, K_PHYS, float(jud["power"]), 0, 0.0,
				"Suprema (R): salta até o cursor (até %dm, intocável no ar) e desce em 3 golpes do montante em %.1fm: %.1f + %.1f + %.1f de poder. O último é sempre crítico e atordoa %ds." % [
					int(jud["range"]), float(jud["radius"]), float(jud["power"]) * float(jud["weights"][0]), float(jud["power"]) * float(jud["weights"][1]),
					float(jud["power"]) * float(jud["weights"][2]), int(jud["stun"])],
				{"ultimate": true, "ult_bot": "boss", "vfx": "holy", "clip": "atk_2h_chain_a", "range": float(jud["range"]), "radius": float(jud["radius"]),
				 "startup": 0.22, "active": 0.62, "recovery": 0.3, "cancel_after": 0.1, "hit_stop_frames": 4, "icon_color": Color(1.0, 0.9, 0.5),
				 "dash": float(jud["range"]), "leap_iframe": float(jud["iframe"]),
				 "strikes": {"weights": jud["weights"], "at": [0.0, 0.28, 0.6], "crit_last": true, "last_stop": 6,
					"clips": ["atk_2h_chain_a", "atk_2h_chain_b", "atk_2h_chain_c"], "last_effects": {"stun": {"duration": float(jud["stun"])}}}}),
			_s("pal_ult_hammer_sky", "Céu de Martelos", Balance.ULT_LEVEL, "templario", ["shield"], T_SELF, K_PHYS, float(sky["power"]), 0, 0.0,
				"Suprema (R): por %ds, %d martelos de luz gigantes giram a %dm de você, batendo %.2f de poder em cada inimigo a cada %.1fs e pondo a Marca da Penitência (+%d%% de dano recebido). O Juramento fica cheio e não esfria enquanto durar." % [
					int(sky["duration"]), int(sky["count"]), int(sky["radius"]), float(sky["power"]), float(sky["every"]), int(sky["penance_pct"])],
				{"ultimate": true, "ult_bot": "boss", "vfx": "holy", "clip": "buff_power", "radius": float(sky["radius"]), "startup": 0.2, "active": 0.05, "recovery": 0.25,
				 "cancel_after": 0.1, "hit_stop_frames": 3, "icon_color": Color(1.0, 0.92, 0.6), "curse": penance,
				 "orbit": {"id": "hammer_sky", "duration": float(sky["duration"]), "every": float(sky["every"]), "count": int(sky["count"]), "oath_lock": true,
					"effects": {"curse": penance}}}),
		],
		"berserker": [
			_s("ber_ult_blood_feast", "Festim de Sangue", Balance.ULT_LEVEL, "carniceiro", ["dual"], T_SELF, K_BUFF, 0.0, 0, 0.0,
				"Suprema (R): por %ds, +%d%% de velocidade de ataque e +%d de roubo de vida; todo golpe abre uma ferida e suas feridas não fecham enquanto durar. No fim, uma Sangria gigante sai sozinha (%.1fm, %.1f de poder) e cura %d%% da vida por inimigo que sangrava (até %d)." % [
					int(fea["duration"]), int(fea["aspd_pct"]), int(fea["lifesteal"]), float(fea["end_radius"]), float(fea["end_power"]), int(fea["end_heal_pct"]), int(fea["end_heal_max"])],
				{"ultimate": true, "ult_bot": "boss", "vfx": "blood", "clip": "shout", "startup": 0.2, "active": 0.05, "recovery": 0.25, "cancel_after": 0.1,
				 "icon_color": Color(0.95, 0.25, 0.25),
				 "buff": {"id": "blood_feast", "duration": float(fea["duration"]), "aspd_pct": float(fea["aspd_pct"]), "lifesteal": float(fea["lifesteal"]),
					"hit_poison": float(fea["bleed_dps"]), "wound_hold": true, "end_cast": "ber_ult_blood_feast_end"}}),
			_s("ber_ult_headsman_verdict", "Veredito do Carrasco", Balance.ULT_LEVEL, "executor", ["two_handed"], T_TARGET, K_PHYS, float(ver["power"]), 0, 0.0,
				"Suprema (R): salta no alvo (até %dm), racha a armadura dele e de quem está a %.1fm (%d cargas) e desce um golpe de %.1f de poder que consome a rachadura do alvo (+%d%%). Abaixo de %d%% da vida o golpe vale x%.1f (chefe x%.2f). Os vizinhos ficam rachados para o grupo." % [
					int(ver["range"]), float(ver["radius"]), int(ver["stacks"]), float(ver["power"]), roundi(float(Balance.SUNDER_CONSUME["per"]) * int(ver["stacks"]) * 100.0),
					roundi(float(ver["below"]) * 100.0), float(ver["exec_mult"]), float(ver["boss_mult"])],
				{"ultimate": true, "ult_bot": "boss", "vfx": "blood", "clip": "atk_leap", "range": float(ver["range"]), "startup": 0.25, "active": 0.08, "recovery": 0.35,
				 "cancel_after": 0.12, "hit_stop_frames": 7, "icon_color": Color(0.85, 0.2, 0.2),
				 "dash": float(ver["range"]), "dash_to_aim": true,
				 "sunder_fill": {"stacks": int(ver["stacks"]), "radius": float(ver["radius"])}, "sunder_consume": Balance.SUNDER_CONSUME,
				 "ult_execute": {"below": float(ver["below"]), "mult": float(ver["exec_mult"]), "boss_mult": float(ver["boss_mult"])}}),
			_s("ber_ult_seven_winds", "Sete Ventos", Balance.ULT_LEVEL, "punhos", ["dual_claw"], T_TARGET, K_PHYS, float(win["power"]), 0, 0.0,
				"Suprema (R): some e reaparece em %d golpes em %.1fs (%.1f de poder cada), saltando entre os inimigos a %dm (um alvo só leva todos). Intocável durante; termina com a Fúria do Punho cheia." % [
					int(win["count"]), float(win["every"]) * int(win["count"]), float(win["power"]), int(win["radius"])],
				{"ultimate": true, "ult_bot": "boss", "vfx": "wind", "clip": "atk_flurry", "range": float(win["range"]), "startup": 0.15, "active": 0.05, "recovery": 0.2,
				 "cancel_after": 0.1, "hit_stop_frames": 2, "icon_color": Color(0.85, 0.9, 1.0),
				 "hop_strikes": {"count": int(win["count"]), "every": float(win["every"]), "radius": float(win["radius"]), "iframe": "all", "fury_end": int(win["fury"])}}),
		],
		"bishop": [
			_s("bis_ult_grace_dome", "Cúpula da Graça", Balance.ULT_LEVEL, "sacerdote", ["mace", "shield"], T_GROUND, K_HEAL, float(dom["heal"]), 0, 0.0,
				"Suprema (R): ergue no cursor (até %dm) uma cúpula PARADA de %dm por %ds: o grupo dentro recebe %d%% menos dano. Ao erguer, cura todos dentro (%.1f de poder). Com a Barreira Sagrada em cima vale a maior, não somam." % [
					int(dom["range"]), int(dom["radius"]), int(dom["duration"]), int(dom["dr"]), float(dom["heal"])],
				{"ultimate": true, "ult_bot": "save", "vfx": "holy", "clip": "cast_holy", "range": float(dom["range"]), "radius": float(dom["radius"]), "startup": 0.25,
				 "active": 0.05, "recovery": 0.3, "cancel_after": 0.1, "hit_stop_frames": 0, "icon_color": Color(1.0, 0.95, 0.7),
				 "grace_dome": {"duration": float(dom["duration"]), "dr": float(dom["dr"])}}),
			_s("bis_ult_judgement_sun", "Sol do Julgamento", Balance.ULT_LEVEL, "inquisidor", ["scepter"], T_GROUND, K_MAG, float(sun["power"]), 0, 0.0,
				"Suprema (R): um raio de sol cai no cursor (até %dm): %.1f de poder e atordoa %ds em %.1fm. O chão fica aceso %ds, batendo %.2f a cada %.1fs, e %d%% de todo esse dano cura o aliado mais ferido." % [
					int(sun["range"]), float(sun["power"]), int(sun["stun"]), float(sun["radius"]), int(sun["duration"]), float(sun["pulse_power"]), float(sun["pulse"]), roundi(float(sun["mend"]) * 100.0)],
				{"ultimate": true, "ult_bot": "boss", "vfx": "holy", "clip": "cast_ground", "range": float(sun["range"]), "radius": float(sun["radius"]), "startup": 0.3,
				 "active": 0.08, "recovery": 0.35, "cancel_after": 0.12, "hit_stop_frames": 6, "icon_color": Color(1.0, 0.85, 0.35),
				 "stun": {"duration": float(sun["stun"])}, "mend_pct_of_dmg": float(sun["mend"]),
				 "zone": {"id": "judgement_sun", "duration": float(sun["duration"]), "pulse": float(sun["pulse"]), "foe_power": float(sun["pulse_power"]),
					"mend_pct": float(sun["mend"])}}),
			_s("bis_ult_faith_avatar", "Avatar da Fé", Balance.ULT_LEVEL, "batalha", ["mace"], T_SELF, K_PHYS, float(ava["power"]), 0, 0.0,
				"Suprema (R): martelo de luz no chão em volta (%.1fm, %.1f de poder) e cura o grupo a %dm (%.1f de poder). Depois, %ds de Avatar: maior, +%d%% ATK, +%d%% DEF, +%d%% de resistência a controle e %d%% de todo o seu dano físico cura o aliado mais ferido." % [
					float(ava["radius"]), float(ava["power"]), int(ava["heal_radius"]), float(ava["heal"]), int(ava["duration"]), int(ava["atk_pct"]), int(ava["def_pct"]),
					int(ava["cc_resist_pct"]), int(ava["mend_pct"])],
				{"ultimate": true, "ult_bot": "self", "vfx": "holy", "clip": "atk_finisher", "radius": float(ava["radius"]), "startup": 0.28, "active": 0.08, "recovery": 0.3,
				 "cancel_after": 0.12, "hit_stop_frames": 6, "icon_color": Color(1.0, 0.88, 0.5),
				 "ally_heal": {"radius": float(ava["heal_radius"]), "power": float(ava["heal"])},
				 "buff": {"id": "faith_avatar", "duration": float(ava["duration"]), "atk_pct": float(ava["atk_pct"]), "def_pct": float(ava["def_pct"]),
					"cc_resist_pct": float(ava["cc_resist_pct"]), "phys_mend": float(ava["mend_pct"]), "scale": float(ava["scale"])}}),
		],
		"druid": [
			_s("dru_ult_primal_colossus", "Colosso Primevo", Balance.ULT_LEVEL, "guardiao_verde", ["mace2h"], T_SELF, K_BUFF, 0.0, 0, 0.0,
				"Suprema (R): só como Urso (em forma humana vira urso na hora; como Ent não sai). Urra e provoca a %dm (%ds; chefes: metade) e vira Colosso por %ds: urso gigante, +%d%% de vida máxima (a vida ganha entra cheia), +%d%% DEF, +%d%% ATK, +%d%% de ameaça e +%d%% de resistência a controle. Ao acabar, a vida máxima volta e a porcentagem de vida fica." % [
					int(col["radius"]), int(col["taunt"]), int(col["duration"]), int(col["hp_pct"]), int(col["def_pct"]), int(col["atk_pct"]), int(col["threat_pct"]), int(col["cc_resist_pct"])],
				{"ultimate": true, "ult_bot": "self", "vfx": "nature", "clip": "shout", "radius": float(col["radius"]), "startup": 0.25, "active": 0.05, "recovery": 0.3,
				 "cancel_after": 0.1, "hit_stop_frames": 4, "icon_color": Color(0.6, 0.45, 0.25),
				 "force_form": "bear", "taunt": {"duration": float(col["taunt"])},
				 "buff": {"id": "primal_colossus", "duration": float(col["duration"]), "hp_pct": float(col["hp_pct"]), "def_pct": float(col["def_pct"]),
					"atk_pct": float(col["atk_pct"]), "threat_pct": float(col["threat_pct"]), "cc_resist_pct": float(col["cc_resist_pct"]), "scale": float(col["scale"]),
					"keep_hp": true, "form_bound": "bear"}}),
			_s("dru_ult_blood_moon", "Garras da Lua Rubra", Balance.ULT_LEVEL, "fera", ["dual_mace"], T_SELF, K_PHYS, float(moo["power"]), 0, 0.0,
				"Suprema (R): só como lobo (o Alfa conta). Por %ds, a cada %.1fs o lobo salta sozinho num inimigo a %dm (prefere quem não sangra): %.1f de poder e o sangramento das Garras. Entre os saltos você anda; o dash corta o resto." % [
					int(round(float(moo["every"]) * int(moo["count"]))), float(moo["every"]), int(moo["radius"]), float(moo["power"])],
				{"ultimate": true, "ult_bot": "boss", "vfx": "lunar", "clip": "atk_leap", "requires_form": "wolf", "startup": 0.15, "active": 0.05, "recovery": 0.2,
				 "cancel_after": 0.1, "hit_stop_frames": 2, "icon_color": Color(0.85, 0.2, 0.3),
				 "hop_strikes": {"count": int(moo["count"]), "every": float(moo["every"]), "radius": float(moo["radius"]), "iframe": float(moo["iframe"]),
					"prefer": "unbled", "effects": {"dot": {"dps": float(moo["bleed_dps"]), "duration": float(moo["bleed_time"]), "skill": "dru_ult_blood_moon"}}}}),
			_s("dru_ult_elder_heart", "Coração do Bosque Ancião", Balance.ULT_LEVEL, "xama", ["staff"], T_GROUND, K_MAG, float(elh["power"]), 0, 0.0,
				"Suprema (R): uma árvore ancestral brota no cursor (até %dm) por %ds, intocável. Ao nascer: %.1f de poder e prende %ds os inimigos a %dm. A cada %.1fs lança Fogo Lunar em até %d inimigos a %dm (%.1f cada, com queimadura lunar) e cura os aliados a %dm (%.2f de poder)." % [
					int(elh["range"]), int(elh["duration"]), float(elh["power"]), int(elh["root"]), int(elh["radius"]), float(elh["pulse"]), int(elh["foe_max"]), int(elh["foe_radius"]),
					float(elh["foe_power"]), int(elh["radius"]), float(elh["heal"])],
				{"ultimate": true, "ult_bot": "boss", "vfx": "nature", "clip": "cast_ground", "range": float(elh["range"]), "radius": float(elh["radius"]), "startup": 0.3,
				 "active": 0.08, "recovery": 0.35, "cancel_after": 0.12, "hit_stop_frames": 4, "icon_color": Color(0.5, 0.85, 0.45),
				 "root": {"duration": float(elh["root"])}, "dot": _dot(float(elh["dot_dps"]), float(elh["dot_time"])),
				 "zone": {"id": "elder_heart", "duration": float(elh["duration"]), "pulse": float(elh["pulse"]), "foe_power": float(elh["foe_power"]),
					"ally_heal": float(elh["heal"]), "foe_radius": float(elh["foe_radius"]), "foe_max": int(elh["foe_max"])}}),
		],
	}

## Skills de apoio das Supremas B1 (sem classe: nunca entram na teia/barra/livro; só saem pelo efeito que as chama).
static func _ult_helpers_b1() -> Array:
	var fea: Dictionary = Balance.ULT_NUMBERS["ber_ult_blood_feast"]
	return [
		_s("ber_ult_blood_feast_end", "Sangria do Festim", Balance.ULT_LEVEL, "", [], T_SELF, K_PHYS, float(fea["end_power"]), 0, 0.0,
			"Fecho do Festim de Sangue: giro dos dois machados que cura por inimigo que sangrava.",
			{"vfx": "blood", "clip": "atk_spin", "radius": float(fea["end_radius"]), "startup": 0.0, "active": 0.05, "recovery": 0.0, "hit_stop_frames": 4,
			 "icon_color": Color(0.95, 0.25, 0.25), "wound_heal": {"pct": float(fea["end_heal_pct"]), "max": int(fea["end_heal_max"])}}),
	]
