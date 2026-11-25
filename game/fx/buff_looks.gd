class_name BuffLooks
extends RefCounted
## Como cada buff aparece NO BONECO enquanto dura (BuffAura). Só apresentação: lê ids que a sim põe em SimEntity.buffs.
##
## LOOKS: id do buff -> [família, tema]. Tema = paleta de SkillFx.PALETTE ("" = o tema (vfx) da skill que dá o buff).
## Famílias (o que aparece):
##   armor  defesa: borda + padrão na pele pelo tema (gelo cristal, pedra/osso placas, casca, brilho sagrado)
##          + partículas lentas do tema; gelo ganha casca de cristal facetada
##   shield escudo de HP (efeito "shield"): bolha translúcida que some junto com o escudo restante
##   power  ATK/crítico/velocidade de ataque: chama do tema em volta (línguas subindo) + borda tremendo + brasas (raio: faíscas)
##   holy   bênção: auréola sobre a cabeça + brilho dourado subindo + motas
##   speed  velocidade: rastros de vento no chão atrás dos pés
##   smoke  cortina de fumaça: fumaça nos pés
##   poison lâmina envenenada: gotas verdes pingando da arma
##   dark   pacto sombrio: sombra subindo pelo corpo + fumaça roxa
##   aura   aura de liga/desliga (anel no chão do FxManager) + borda; quem recebe vê só a borda, fraca
##   wings  Modo Arcano (Paladino ascendido): asas de luz nas costas que batem devagar + motas + borda sagrada
##   form   forma/furtividade: o próprio boneco muda (EntityView: bicho, fantasma, transparência)
## Buff novo sem linha aqui = falha no teste (_check_buff_visuals): nada de buff invisível.
const LOOKS := {
	# defesa
	"frost_armor": ["armor", "ice"], "crystal_ward": ["armor", "ice"],
	"stoneskin": ["armor", "earth"], "shell_hide": ["armor", "earth"],      # Concha (Caranguejo-Eremita)
	"bark": ["armor", "nature"], "oak_skin": ["armor", "nature"], "bellow": ["armor", "nature"],
	"bone_armor": ["armor", "bone"], "bonewall": ["armor", "bone"],
	"blessed_armor": ["armor", "holy"], "ward": ["armor", "holy"], "bulwark": ["armor", "holy"],
	"hallowed": ["armor", "holy"],            # Chão Sagrado (Templário): +DEF enquanto está dentro da zona
	"shield_wall": ["armor", "holy"], "bastion": ["armor", "holy"], "colonia_de_pe": ["holy", "holy"],
	"juramento": ["armor", "holy"],
	"muralha_de_pe": ["holy", "fire"], "posto_de_pe": ["holy", "nature"],      # moral do cerco por lugar (Bastião, Posto): mesmo efeito, cor própria
	"duel_guard": ["armor", "physical"], "chakra": ["armor", "holy"],
	"guard_crit": ["power", "holy"],          # Contra-Ataque (notável do Guardião): bloqueou -> crítico por pouco tempo
	# escudo de HP
	"shield": ["shield", ""], "boss_ward": ["shield", ""],
	# ataque
	"fury": ["power", "blood"], "boss_berserk": ["power", "blood"], "warcry": ["power", "blood"], "bloodlust": ["power", "blood"], "titan_grip": ["power", "blood"],
	"headsman_roar": ["power", "blood"],      # Brado do Carrasco (Executor): +DEF/+ATK no grupo
	"frenzy": ["power", "blood"], "legend_frenzy": ["power", "blood"], "elixir": ["power", "fire"],
	"valor": ["power", "holy"], "zeal": ["power", "holy"], "fervor": ["power", "holy"], "battle_hymn": ["power", "holy"],
	"mark": ["power", "physical"], "deadeye": ["power", "physical"], "focus": ["power", "physical"], "duel_focus": ["power", "physical"],
	"impeto": ["power", "physical"],          # Ímpeto (Duelista: cargas das aparadas, o Golpe de Mestre gasta)
	"shout_flame": ["power", "fire"], "shout_flame_ally": ["power", "fire"], "shout_frost": ["power", "ice"],
	"shout_thunder": ["speed", "lightning"], "shout_thunder_ally": ["speed", "lightning"],
	"sky_eyes": ["speed", "wind"],          # Olhos do Céu (Falcoeiro): o grupo corre mais e acerta a Presa
	"pack": ["power", "nature"], "overload": ["power", "lightning"], "blood_instinct": ["power", "blood"], "black_flag": ["power", "fire"], "fist_fury": ["power", "blood"],
	"horde_fury": ["power", "blood"], "war_cry": ["power", "blood"], "clan_wolf": ["speed", "blood"],
	"mob_frenzy": ["power", "blood"], "boss_channel": ["power", "blood"], "boss_temper": ["power", "fire"],     # assinaturas de chefe
	"ghar_wall": ["armor", "earth"],
	"troll_regen": ["holy", "nature"],
	"glory": ["power", "fire"],
	"elem_ember": ["power", "fire"], "elem_fusion": ["power", "lightning"],
	"fus_aurora": ["power", "holy"],          # Aurora (Fusão Martelo da Aurora)
	"apex_tempest": ["power", "blood"],       # Frenesi da Tormenta (Ápice do Carniceiro: golpes empilham velocidade de ataque)
	"apex_cadence": ["power", "physical"],    # Cadência (Ápice do Duelista: crítico junta; com 5 vira Foco)
	"legend_determination": ["power", "holy"],   # Determinação (escudo lendário do Paladino/Clérigo de Batalha): cargas de dano e cura recebida
	"legend_bulwark": ["armor", "holy"],         # Baluarte (maça lendária do Paladino): a bolha vem do "shield"; a borda sagrada marca a origem
	"apex_judged": ["power", "holy"],         # Julgado (Ápice do Cruzado: debuff no alvo, todo o dano do Cruzado nele é maior)
	# bênçãos
	"choir_wings": ["speed", "holy"], "choir_aegis": ["armor", "holy"],        # bênçãos do Coro Celeste (Bispo ascendido)
	"blessing": ["holy", "holy"], "angel": ["holy", "holy"], "avenging_wrath": ["holy", "holy"], "grove": ["holy", "nature"],
	# movimento
	"swift": ["speed", "wind"], "elem_gale": ["speed", "lightning"], "reflexes": ["speed", "wind"], "counter_stance": ["speed", "wind"], "wild_run": ["speed", "nature"],
	"field_dressing": ["speed", "nature"],    # Curativo de Campo (Ranger)
	"smoke": ["smoke", "shadow"],
	# arma / sombra
	"plague_blade": ["poison", "poison"],
	"dark_pact": ["dark", "shadow"], "twin_shadow": ["dark", "shadow"], "exec_ready": ["power", "physical"], "horde_dismay": ["dark", "shadow"],
	# ascensão do Necromante: pacto no mago e nas invocações
	"lord_pact": ["dark", "shadow"], "lord_pact_minion": ["power", "shadow"],
	# auras de liga/desliga
	"bastion_aura": ["aura", "holy"], "gladiator": ["aura", "blood"],
	# ascensão do Paladino: asas do Modo Arcano; caiu do cavalo (imune a controle)
	"blessed_hammers": ["power", "holy"],          # Martelos Abençoados (os martelos girando são do FxManager._orbit_fx)
	"arcane_wings": ["wings", "holy"], "unhorsed": ["armor", "physical"], "arcane_ward": ["armor", "holy"],      # Asas Protetoras no grupo
	# o boneco muda (EntityView)
	"stealth": ["form", "shadow"], "form_wolf": ["form", "nature"], "form_bear": ["form", "nature"],
	"form_phantom": ["form", "lunar"], "form_demon": ["form", "fire"], "form_lich": ["form", "ice"],
	# ascensão do Druida (Forma Ancestral): as formas e os buffs de grupo delas
	"form_ent": ["form", "nature"], "form_alpha": ["form", "nature"], "form_bird": ["form", "lightning"],
	"ent_grove": ["armor", "nature"], "alpha_howl": ["speed", "nature"], "bird_flock": ["speed", "holy"],
	# Supremas B1 (GDD ultimates-lv40): Proteção do Bastião, martelos do Céu, Festim, Avatar, Colosso
	"intercept": ["aura", "holy"], "hammer_sky": ["power", "holy"], "blood_feast": ["power", "blood"], "faith_avatar": ["holy", "holy"],
	"primal_colossus": ["armor", "nature"],
	# Supremas B2: Laço Selvagem (você, o lince e o lince espiritual), Olho da Tempestade, Maré dos Mortos, Ceifa das Almas
	"wild_bond": ["power", "nature"], "wild_bond_pet": ["power", "nature"], "wild_bond_spirit": ["dark", "nature"],
	"grand_duel": ["armor", "physical"], "storm_eye": ["speed", "lightning"], "tide_of_dead": ["dark", "bone"], "tide_frenzy": ["power", "bone"], "soul_reaping": ["power", "shadow"],
	# Ato III (Lumeria, WP12): motivos da Festa (fitas, confete, névoa rosa, cacos de porcelana); cor/partículas em LUMERIA
	"festim": ["power", "blood"], "festim_dismay": ["dark", "shadow"], "sede": ["speed", "blood"], "unison": ["power", "lunar"],
	"banquet": ["power", "blood"], "banquet_vuln": ["dark", "blood"], "sweet_smoke": ["smoke", "poison"],
}
## Ato III (Lumeria): id -> [partículas (BuffAura.PRESETS, com cor própria), cor da borda, destaque]. Sem casca de chama:
## a festa não pega fogo. Paleta da Festa (§4.4): rosa, ouro, vinho, lilás, porcelana; nada saturado no chão.
const LUMERIA := {
	"festim": ["confetti", Color(1.0, 0.72, 0.62), Color(1.0, 0.86, 0.52)],          # aura do Mestre de Cerimônias: confete rosa-ouro
	"festim_dismay": ["ribbons_wilt", Color(0.7, 0.58, 0.66), Color(0.55, 0.5, 0.56)],   # Mestre caído: fitas murchas caindo
	"sede": ["rose_mist", Color(0.96, 0.56, 0.68), Color(1.0, 0.8, 0.86)],          # aura da Matriarca: névoa rosa nos pés
	"unison": ["ribbons", Color(0.8, 0.66, 1.0), Color(1.0, 0.9, 0.62)],            # Uníssono do Maestro: fitas lilás subindo em volta
	"banquet": ["wine", Color(0.82, 0.24, 0.38), Color(1.0, 0.82, 0.5)],             # Banquete (Varo e convidados): vinho escorrendo
	"banquet_vuln": ["shards", Color(0.96, 0.92, 0.86), Color(0.95, 0.8, 0.45)],     # Banquete quebrado: a porcelana racha e cai
	"sweet_smoke": ["rose_mist", Color(0.86, 0.66, 0.92), Color(1.0, 0.84, 0.92)],   # Fumo Doce: névoa lilás-rosa nos pés
}
## Debuffs (SimEntity.debuffs) que também aparecem no boneco pela BuffAura (o resto dos debuffs é do CcLook/estado).
const DEBUFF_LOOKS := {"banquet_vuln": true, "sweet_smoke": true}
const FAMILIES := ["armor", "shield", "power", "holy", "speed", "smoke", "poison", "dark", "aura", "wings", "form"]

## Controle no corpo (debuff `kind` -> [forma, cor]); não são buffs (sem fonte em sources()), por isso fora de LOOKS.
## stars = estrelas girando na cabeça, roots = raízes nos pés (CcLook.roots), drag = rastro de poeira fria nos pés
## (CcLook.drag), frost = anel de gelo (lento de gelo: slow.frost). Check _check_cc_looks: todo kind de controle tem linha.
const CC_LOOKS := {
	"stun": ["stars", Color(1.0, 0.9, 0.35)],
	"root": ["roots", Color(0.46, 0.32, 0.17)],
	"slow": ["drag", Color(0.74, 0.8, 0.92)],
	"slow_frost": ["frost", Color(0.6, 0.9, 1.0)],
}
const CC_SHAPES := ["stars", "roots", "drag", "frost"]

## [forma, cor] do controle `kind` (lento de gelo = "slow_frost"); [] = sem visual.
static func cc_look(kind: String, frost: bool = false) -> Array:
	if kind == "slow" and frost:
		kind = "slow_frost"
	return CC_LOOKS.get(kind, [])

## Buffs que a sim põe direto no código (sem catálogo): id -> onde.
const SYSTEM_BUFFS := {
	"legend_frenzy": "LegendEffects (arma lendária: frenesi)",
	"legend_bulwark": "LegendEffects.bulwark (maça lendária: Baluarte)",
	"legend_determination": "LegendEffects.determination_gain (escudo lendário: Determinação)",
	"lord_pact_minion": "NecroAscension (Pacto dos Mortos nas invocações)",
	"shout_flame_ally": "RangerAscension (Brado das Chamas no grupo)",
	"shout_thunder_ally": "RangerAscension (Brado do Trovão no grupo)",
	"twin_shadow": "ShadowSystem (Sombra Gêmea: clone de sombra ativo)",
	"exec_ready": "ShadowSystem (Contra-Ataque em Cadeia: Execução preparada pela esquiva)",
	"fist_fury": "FistSystem (Punhos de Fúria: esquivar dá Fúria do Punho)",
	"impeto": "RiposteSystem (Duelista: aparar dá Ímpeto)",
	"glory": "GladiatorSystem (Modo Gladiador: Glória por crítico, abate e Brado da Arena)",
	"bastion": "RaidSystem (sentinela: reunir)",
	"colonia_de_pe": "SiegeSystem (Colônia de Pé: leva repelida, +XP de abate no mapa)",
	"muralha_de_pe": "SiegeSystem (Muralha de Pé: moral do Bastião, siege.morale_buff)",
	"posto_de_pe": "SiegeSystem (Posto de Pé: moral do Posto dos Caçadores, siege.morale_buff)",
	"juramento": "ShieldSystem (Juramento ao bloquear)",
	"guard_crit": "Combat.role_on_hit (notável Contra-Ataque: bloqueou, +crítico)",
	"blessed_hammers": "AuraSystem.start_orbit (Martelos Abençoados: efeito orbit)",
	"intercept": "InterceptSystem.start (Proteção do Bastião da Aurora)",
	"hammer_sky": "AuraSystem.start_orbit (Céu de Martelos: efeito orbit da Suprema)",
	"wild_bond_pet": "UltEffects.pet_revive (Laço Selvagem: buff do lince)",
	"wild_bond_spirit": "UltEffects.spirit_pet (Laço Selvagem: o 2º lince, espiritual)",
	"tide_frenzy": "UltEffects.buff_summons (Maré dos Mortos: invocações mais rápidas)",
	"shield": "WorldSim (efeito shield, Égide lendária)",
	"boss_ward": "MobSystem (chefe protegido pelos lacaios: fase com ward)",
	"boss_berserk": "MobSystem (chefe enlouquecido: berserk_after)",
	"horde_fury": "AuraSystem.mob_aura (aura do Agitador nos monstros da Horda)",
	"horde_dismay": "AuraSystem.on_mob_death (bando desanimado: Agitador morto)",
	"clan_wolf": "AuraSystem.mob_aura (Estandarte do Clã do Lobo do Durgash: a Horda corre e golpeia mais rápido)",
	"war_cry": "MobSystem.rally (grito de guerra do Guerreiro Orc / Ghar no bando da Horda)",
	"boss_channel": "BossSignatures.channel_start (canal interrompível do chefe: Rufar da Turba)",
	"mob_frenzy": "BossSignatures._channel_done (Frenesi da turba: o tambor tocou até o fim)",
	"ghar_wall": "BossSignatures.wall_start (Muralha de Escudos do Ghar)",
	"boss_temper": "BossSignatures._empower (Têmpera: chefe fortalecido dentro da poça)",
	"troll_regen": "MobSystem.update_regen (troll regenerando: some quando queima ou está envenenado)",
	"unhorsed": "MountedCombat (derrubado do cavalo: imune a controle)",
	"arcane_ward": "MountedCombat.ward_tick (Asas Protetoras: redução de dano no grupo perto do Templário)",
	"elem_ember": "ElementalSystem (elemental de fogo no modo apoiar)",
	"elem_gale": "ElementalSystem (elemental de raio no modo apoiar)",
	"elem_fusion": "ElementalSystem (Fusão Elemental)",
	"fus_aurora": "FusionEffects.on_cast (Ápice Iluminado: magia sagrada dá Aurora)",
	"apex_tempest": "FusionEffects._tempest (Ápice do Carniceiro: Frenesi da Tormenta)",
	"apex_cadence": "FusionEffects._cadence (Ápice do Duelista: Cadência)",
	"apex_judged": "FusionEffects.judge (Ápice do Cruzado: alvo Julgado)",
	"festim": "AuraSystem.mob_aura (aura festim do Mestre de Cerimônias, Balance.MOB_AURAS)",
	"festim_dismay": "AuraSystem.on_mob_death (Mestre de Cerimônias caído: foliões desanimados)",
	"sede": "AuraSystem.mob_aura (aura sede da Matriarca Velada)",
	"unison": "MobSystem.rally (Uníssono do Maestro do Coro: mob_unison)",
	"banquet": "BossSignatures._channel_done (Banquete do Varo: on_done.buff)",
	"banquet_vuln": "BossSignatures._channel_break (Banquete quebrado: on_break.vuln_id, debuff)",
	"sweet_smoke": "WorldSim._apply_effects (lento do Fumo Doce com id: debuff)",
}

## Padrão na pele (uniform buff_style do toon) por tema.
const RIM_STYLE := {"ice": 1, "earth": 2, "bone": 2, "blood": 3, "fire": 3, "lightning": 3, "nature": 4, "holy": 5, "shadow": 6}
## Partículas da família armor por tema (as outras famílias têm uma só).
const ARMOR_PARTS := {"ice": "snow", "earth": "dust", "nature": "leaves", "bone": "bone", "holy": "motes"}
const FAMILY_PARTS := {"holy": "motes", "wings": "motes", "speed": "streaks", "smoke": "smoke", "poison": "drip", "dark": "shadow"}
## Escudo de HP: tema pela classe de quem tem (ossos do necro, gelo do mago...)
const SHIELD_THEME := {"necromancer": "bone", "elementalist": "ice", "druid": "nature"}

static var _cache: Dictionary = {}
static var _skill_theme: Dictionary = {}
static var _shield_cache: Dictionary = {}

## Visual resolvido do buff `id` em `e` (cacheado; nada alocado depois do primeiro):
## {family, theme, color, accent, rim_style, parts, shell (0 nada, 1 bolha, 2 cristal, 3 chama), halo}
static func look(id: String, e: SimEntity = null) -> Dictionary:
	var key := id
	if id == "shield" and e != null and e.class_def != null:
		if _shield_cache.has(e.class_def.id):          # sem montar string a cada consulta (BuffAura pergunta 10x/s)
			return _shield_cache[e.class_def.id]
		key = "shield:" + e.class_def.id
	elif _cache.has(key):
		return _cache[key]
	var row: Array = LOOKS.get(id, [])
	if row.is_empty():
		_cache[key] = {}
		return _cache[key]
	var fam: String = row[0]
	var th: String = row[1]
	if id == "shield":
		th = SHIELD_THEME.get(e.class_def.id if e != null and e.class_def != null else "", "holy")
	if th == "":
		th = skill_theme(id)
	var parts := ""
	match fam:
		"armor":
			parts = ARMOR_PARTS.get(th, "")
		"power":
			parts = "sparks" if th in ["lightning", "physical"] else "embers"
		_:
			parts = FAMILY_PARTS.get(fam, "")
	var shell := 0
	if fam == "shield":
		shell = 1
	elif fam == "armor" and th == "ice":
		shell = 2
	elif fam == "power":
		shell = 3
	var d := {"family": fam, "theme": th, "color": SkillFx.col(th, 0), "accent": SkillFx.col(th, 1),
		"rim_style": int(RIM_STYLE.get(th, 0)), "parts": parts, "shell": shell, "halo": fam == "holy"}
	if fam == "dark":
		d["color"] = Color(0.62, 0.32, 0.95)      # o roxo escuro da paleta some na pele: borda mais clara
	if fam == "power" and th == "physical":
		d["color"] = Color(1.0, 0.78, 0.3)        # foco/crítico: brilho dourado (o branco do aço só desbota o boneco)
		d["accent"] = Color(1.0, 0.95, 0.7)
	if fam == "smoke":
		d["color"] = Color(0.7, 0.72, 0.78)
	if LUMERIA.has(id):
		var lum: Array = LUMERIA[id]
		d["parts"] = lum[0]
		d["color"] = lum[1]
		d["accent"] = lum[2]
		d["shell"] = 0
	_cache[key] = d
	if key.begins_with("shield:"):
		_shield_cache[e.class_def.id] = d
	return d

## Tema (vfx) da skill que dá o buff `id` ("holy" se nenhuma).
static func skill_theme(id: String) -> String:
	if _skill_theme.is_empty():
		for sid in GameData.skills:
			var s: SkillDef = GameData.skills[sid]
			var b = s.effects.get("buff")
			if b is Dictionary and not _skill_theme.has(str(b.get("id", ""))):
				_skill_theme[str(b.get("id", ""))] = s.vfx
	return _skill_theme.get(id, "holy")

## Todos os buffs que o jogo pode pôr: [{id, source}] — skills (buff/shield/form/stealth/aura), evoluções,
## mods de forma, talentos de classe, consumíveis e os buffs fixos dos sistemas. Usado pelo teste e pelo buff_audit.
static func sources() -> Array:
	var out: Array = []
	for sid in GameData.skills:
		var s: SkillDef = GameData.skills[sid]
		_from_effects(out, s.effects, "skill %s (%s)" % [sid, s.name])
	for tid in GameData.talents:
		var t: TalentDef = GameData.talents[tid]
		if t.mods.get("buff") is Dictionary:
			out.append({"id": str(t.mods["buff"].get("id", "")), "source": "evolução %s" % tid})
		if t.mods.get("effects") is Dictionary:
			_from_effects(out, t.mods["effects"], "evolução %s" % tid)
	for sid in SkillsCatalog.FORM_MODS:
		for f in SkillsCatalog.FORM_MODS[sid]:
			var fm: Dictionary = SkillsCatalog.FORM_MODS[sid][f]
			if fm.get("effects") is Dictionary:
				_from_effects(out, fm["effects"], "forma %s/%s" % [sid, f])
	for oid in GameData.class_talents:
		var o: Dictionary = GameData.class_talents[oid]
		for sk in o.get("skill_mods", {}):
			var m: Dictionary = o["skill_mods"][sk]
			if m.get("effects") is Dictionary:
				_from_effects(out, m["effects"], "talento %s" % oid)
	for iid in GameData.items:
		var it: ItemDef = GameData.items[iid]
		if it.consume.get("buff") is Dictionary:
			out.append({"id": str(it.consume["buff"].get("id", "")), "source": "item %s" % iid})
	for id in SYSTEM_BUFFS:
		out.append({"id": id, "source": SYSTEM_BUFFS[id]})
	return out

static func _from_effects(out: Array, fx: Dictionary, src: String) -> void:
	if fx.get("buff") is Dictionary:
		out.append({"id": str(fx["buff"].get("id", "")), "source": src})
	if fx.has("shield"):
		out.append({"id": "shield", "source": src})
	if fx.get("zone") is Dictionary and (fx["zone"] as Dictionary).get("ally_buff") is Dictionary and not (fx["zone"]["ally_buff"] as Dictionary).is_empty():
		out.append({"id": str(fx["zone"]["ally_buff"].get("id", "")), "source": src + " (zona)"})
	if fx.has("form"):
		out.append({"id": "form_" + str(fx["form"]), "source": src})
	if fx.has("stealth"):
		out.append({"id": "stealth", "source": src})
