class_name NecroAscension
extends RefCounted
## Ascensão do Necromante (Ato II, 35): Senhor dos Mortos (GDD ato2-horda R6.1, AC-30b).
## - de graça com a ascensão: invocações temporárias duram LORD_SUMMON_TIME_MULT e cabe +LORD_SUMMON_EXTRA por tipo;
## - Pacto Sombrio (efeito "summon_pact"): buff nas invocações a LORD_PACT_RADIUS m (dano, velocidade, roubo de vida para o mago);
## - Miasma (efeito "miasma"): nuvem no chão que enfraquece e retarda quem está dentro (m["lord_zones"]);
## - Marca da Cova (efeito "grave_mark"): quem morre marcado (monstro comum) levanta como esqueleto aliado;
## - Forma de Lich (forma "lich", nível 45): magias mais fortes, maldições espalham, +1 invocação por tipo; ao sair, o excesso
##   de invocações some da mais antiga para a mais nova.
## Refinos 40/45 = nós da teia de ascensão (AscensionCatalog.NODES, `flag` nec_*). Regras sem estado próprio; números em
## Balance.LORD_*.

const CLASS_ID := "necromancer"
const PACT_BUFF := "lord_pact"                 # no necromante: o pacto está valendo
const PACT_MINION := "lord_pact_minion"        # nas invocações: dano, velocidade e roubo de vida
const LICH := "lich"
const ZONES := "lord_zones"                    # m[ZONES]: nuvens de Miasma vivas no mapa
const CMD_CD := "_lord_cmd"                    # chave em e.cooldowns: intervalo da ordem da foice

static func is_necro(e: SimEntity) -> bool:
	return e != null and e.class_def != null and e.class_def.id == CLASS_ID and e.is_character()

## Necromante com a ascensão liberada.
static func active(e: SimEntity) -> bool:
	return is_necro(e) and ProgressionSystem.has_ascension(e)

## Skill de ascensão do Necromante (as que o BotBrain pontua por aqui).
static func is_mine(s: SkillDef) -> bool:
	return s != null and s.ascension and s.class_id == CLASS_ID

# ---------------------------------------------------------------------------
# Invocações: duram mais, +1 por tipo
# ---------------------------------------------------------------------------
## Vagas a mais por tipo de invocação: a ascensão, o refino Exército e a Forma de Lich (`in_lich` = contar a forma).
static func summon_extra(e: SimEntity, in_lich: bool = true) -> int:
	if not active(e):
		return 0
	var n := Balance.LORD_SUMMON_EXTRA
	if ProgressionSystem.asc_flag(e, "nec_army"):
		n += Balance.LORD_ARMY_EXTRA
	if in_lich and e.form == LICH:
		n += Balance.LORD_LICH_SUMMON_EXTRA
	return n

## Multiplicador da duração das invocações temporárias.
static func summon_time_mult(e: SimEntity) -> float:
	return Balance.LORD_SUMMON_TIME_MULT if active(e) else 1.0

## Invocação recém-erguida: com o refino Exército ganha parte da vida do mago.
static func on_summoned(owner: SimEntity, minion: SimEntity) -> void:
	if minion == null or not is_necro(owner) or not ProgressionSystem.asc_flag(owner, "nec_army"):
		return
	minion.summon_hp = minion.stats.max_hp + owner.stats.max_hp * Balance.LORD_ARMY_HP_SHARE
	minion.recompute_stats()
	minion.heal_full()

## Invocações vivas do dono no mapa dele, da mais antiga para a mais nova (sem elemental; `graves` = contar as da Marca).
static func minions_of(sim: WorldSim, owner: SimEntity, graves: bool = true) -> Array:
	var out: Array = []
	if not sim.maps.has(owner.map_id):
		return out
	for o in sim.maps[owner.map_id]["entities"]:
		if o.kind == SimEntity.Kind.SUMMON and o.owner_id == owner.id and o.is_alive() and o.elem_form == "" and (graves or not o.grave):
			out.append(o)
	out.sort_custom(func(a, b): return a.id < b.id)
	return out

## Limite normal (fora da Forma de Lich) por tipo de invocação das skills que o necromante sabe: {monster_id: máximo}.
static func summon_caps(e: SimEntity) -> Dictionary:
	var caps := {}
	var extra := summon_extra(e, false)
	for sid in e.learned:
		var s: SkillDef = GameData.skills.get(sid)
		if s == null or not s.effects.has("summon"):
			continue
		var sm: Dictionary = s.effects["summon"]
		var mx: Variant = s.mastery_entry(e.mastery_of(s.id)).get("extra", {}).get("summon")
		if mx is Dictionary:
			sm = mx
		var mid := str(sm.get("monster_id", ""))
		caps[mid] = maxi(int(caps.get(mid, 0)), int(sm.get("max", 3)) + ClassTalentSystem.summon_extra(e, s.id) + extra)
	return caps

## Fim da Forma de Lich: o que passa do limite normal some, da invocação mais antiga para a mais nova.
static func trim_summons(sim: WorldSim, e: SimEntity) -> int:
	var caps := summon_caps(e)
	var by_type := {}
	for o in minions_of(sim, e, false):
		var mid: String = o.monster_def.id if o.monster_def else ""
		if not caps.has(mid):
			continue                     # tipo sem skill conhecida (arma lendária): não tem limite para passar
		if not by_type.has(mid):
			by_type[mid] = []
		by_type[mid].append(o)
	var gone := 0
	for mid in by_type:
		var list: Array = by_type[mid]
		while list.size() > int(caps[mid]):
			sim.despawn(list.pop_front())
			gone += 1
	return gone

# ---------------------------------------------------------------------------
# Pacto Sombrio
# ---------------------------------------------------------------------------
static func has_pact(e: SimEntity) -> bool:
	for b in e.buffs:
		if b.get("id") == PACT_BUFF:
			return true
	return false

## Lança o pacto: só as invocações que estão a LORD_PACT_RADIUS m agora recebem (as que chegam depois, não).
static func pact(sim: WorldSim, e: SimEntity, effects: Dictionary, m: Dictionary) -> int:
	var p: Dictionary = effects["summon_pact"]
	var dur := float((effects.get("buff", {}) as Dictionary).get("duration", Balance.LORD_PACT_TIME))
	var n := 0
	for o in m["entities"]:
		if o.kind != SimEntity.Kind.SUMMON or o.owner_id != e.id or not o.is_alive() or o.position.distance_to(e.position) > Balance.LORD_PACT_RADIUS:
			continue
		var pdef: float = o.stats.pdef
		var mdef: float = o.stats.mdef
		o.put_buff({"id": PACT_MINION, "remaining": dur, "mob_stat": true, "speed_pct": float(p.get("speed_pct", 0)),
			"dmg_pct": float(p.get("dmg_pct", 0)), "leech_pct": float(p.get("leech_pct", 0))})
		o.recompute_stats()
		o.stats.pdef = pdef                  # defesa herdada do dono (companheiro, torreta) não se perde no recálculo
		o.stats.mdef = mdef
		Events.post(&"buff_applied", o.id, PACT_MINION, dur)
		n += 1
	return n

static func _pact_of(minion: SimEntity) -> Dictionary:
	for b in minion.buffs:
		if b.get("id") == PACT_MINION:
			return b
	return {}

## Dano da invocação sob o pacto (WorldSim._deal_damage).
static func pact_damage(minion: SimEntity, amount: int) -> int:
	var b := _pact_of(minion)
	if b.is_empty():
		return amount
	return maxi(1, int(round(amount * (1.0 + float(b.get("dmg_pct", 0)) / 100.0))))

## O que a invocação sob o pacto causa cura o necromante (parte do dano que entrou).
static func pact_leech(sim: WorldSim, minion: SimEntity, amount: int) -> void:
	var b := _pact_of(minion)
	if b.is_empty() or float(b.get("leech_pct", 0)) <= 0.0:
		return
	var owner: SimEntity = sim.entities.get(minion.owner_id)
	if owner != null and owner.is_alive() and owner.map_id == minion.map_id:
		owner.hp = minf(owner.stats.max_hp, owner.hp + amount * float(b["leech_pct"]) / 100.0 * owner.heal_factor())

# ---------------------------------------------------------------------------
# Miasma (nuvem no chão)
# ---------------------------------------------------------------------------
static func zones_of(m: Dictionary) -> Array:
	if not m.has(ZONES):
		m[ZONES] = []
	return m[ZONES]

## Põe a nuvem no ponto mirado: uma por necromante (a anterior some). Quem está dentro fica enfraquecido e lento.
static func place_miasma(sim: WorldSim, e: SimEntity, s: SkillDef, aim: Vector3, effects: Dictionary, m: Dictionary) -> Dictionary:
	var z: Dictionary = effects["miasma"]
	var zones := zones_of(m)
	for old in zones.duplicate():
		if old["owner"] == e.id:
			zones.erase(old)
			Events.post(&"trap_removed", old["id"], false)
	var pos := Vector3(aim.x, 0.0, aim.z)
	var zone := {"id": sim._next_trap_id, "kind": "miasma", "owner": e.id, "pos": pos, "radius": s.radius,
		"expires": sim.time + float(z.get("duration", Balance.LORD_MIASMA_TIME)), "next": 0.0,
		"weaken_pct": float(z.get("weaken_pct", 0)), "slow_pct": float(z.get("slow_pct", 0))}
	sim._next_trap_id += 1
	zones.append(zone)
	Events.post(&"trap_placed", zone["id"], "miasma", pos, s.radius, e.map_id)       # o desenho da nuvem usa o canal das armadilhas
	Events.post(&"skill_effect", s.id, e.position, pos, s.radius)
	_pulse(sim, zone, e, m)
	return zone

## Nuvens do mapa: pulsam a cada LORD_MIASMA_PULSE s; o efeito dura LORD_MIASMA_KEEP s em quem sai (some logo).
static func tick(sim: WorldSim, m: Dictionary) -> void:
	var zones: Variant = m.get(ZONES)
	if zones == null or (zones as Array).is_empty():
		return
	for z in (zones as Array).duplicate():
		var owner: SimEntity = sim.entities.get(z["owner"])
		if sim.time >= float(z["expires"]) or owner == null or owner.map_id != m["def"].id:
			(zones as Array).erase(z)
			Events.post(&"trap_removed", z["id"], false)
			continue
		if sim.time >= float(z["next"]):
			_pulse(sim, z, owner, m)

static func _pulse(sim: WorldSim, z: Dictionary, owner: SimEntity, m: Dictionary) -> void:
	z["next"] = sim.time + Balance.LORD_MIASMA_PULSE
	var pos: Vector3 = z["pos"]
	var r := float(z["radius"])
	for o in m["entities"]:
		if not o.is_alive() or absf(o.position.x - pos.x) > r + 2.0 or absf(o.position.z - pos.z) > r + 2.0:
			continue
		if not owner.is_hostile_to(o) or Vector3(o.position.x, 0.0, o.position.z).distance_to(pos) > r + o.radius:
			continue
		o.put_debuff({"kind": "curse", "id": "curse_miasma_%d" % owner.id, "remaining": Balance.LORD_MIASMA_KEEP,
			"taken_pct": 0.0, "weaken_pct": float(z["weaken_pct"])})
		o.put_debuff({"kind": "slow", "id": "miasma_slow_%d" % owner.id, "remaining": Balance.LORD_MIASMA_KEEP, "pct": float(z["slow_pct"])})

## Nuvem viva do necromante no mapa ({} = nenhuma).
static func miasma_of(sim: WorldSim, e: SimEntity) -> Dictionary:
	if not sim.maps.has(e.map_id):
		return {}
	for z in sim.maps[e.map_id].get(ZONES, []):
		if z["owner"] == e.id:
			return z
	return {}

# ---------------------------------------------------------------------------
# Marca da Cova
# ---------------------------------------------------------------------------
## Marca os inimigos na área; devolve quantos.
static func grave_mark(sim: WorldSim, e: SimEntity, s: SkillDef, aim: Vector3, effects: Dictionary, m: Dictionary) -> int:
	var g: Dictionary = effects["grave_mark"]
	var pos := Vector3(aim.x, 0.0, aim.z)
	var n := 0
	for o in m["entities"]:
		if o.is_alive() and e.is_hostile_to(o) and Vector3(o.position.x, 0.0, o.position.z).distance_to(pos) <= s.radius + o.radius:
			o.put_debuff({"kind": "grave_mark", "id": "grave_mark", "remaining": float(g.get("duration", Balance.LORD_GRAVE_MARK_TIME)),
				"src": e.id, "raise": float(g.get("raise", Balance.LORD_GRAVE_RAISE_TIME))})
			n += 1
	Events.post(&"skill_effect", s.id, e.position, pos, s.radius)
	return n

static func is_marked(e: SimEntity) -> bool:
	return e.has_debuff("grave_mark")

## Esqueletos da Marca vivos do necromante.
static func graves_of(sim: WorldSim, owner: SimEntity) -> Array:
	return minions_of(sim, owner).filter(func(o): return o.grave)

## Morte (WorldSim._kill, antes de limpar os debuffs): monstro comum marcado levanta como aliado; necromante que cai
## na Forma de Lich perde o excesso de invocações.
static func on_death(sim: WorldSim, e: SimEntity) -> void:
	if e.kind == SimEntity.Kind.MONSTER:
		if e.debuffs.is_empty():
			return
		for d in e.debuffs:
			if d.get("kind") == "grave_mark":
				_raise(sim, e, d)
				return
	elif e.form == LICH:
		trim_summons(sim, e)

static func _raise(sim: WorldSim, mob: SimEntity, d: Dictionary) -> SimEntity:
	var md: MonsterDef = mob.monster_def
	if md == null or md.is_boss or md.elite_of != "":
		return null                           # chefe e elite não levantam (só monstro comum)
	var owner: SimEntity = sim.entities.get(int(d.get("src", -1)))
	var mdef: MonsterDef = GameData.monsters.get(Balance.LORD_GRAVE_MONSTER)
	if owner == null or mdef == null or not owner.is_alive() or owner.map_id != mob.map_id:
		return null
	if graves_of(sim, owner).size() >= Balance.LORD_GRAVE_MAX:
		return null
	var sk := sim.spawn_summon(owner, mdef, mob.position, float(d.get("raise", Balance.LORD_GRAVE_RAISE_TIME)))
	sk.grave = true                            # não ocupa vaga dos esqueletos do Erguer Mortos
	sk.facing = mob.facing
	on_summoned(owner, sk)
	Events.post(&"skill_effect", Balance.LORD_GRAVE_SKILL, mob.position, mob.position, 1.0)
	return sk

# ---------------------------------------------------------------------------
# Forma de Lich
# ---------------------------------------------------------------------------
## Entrou ou saiu de uma forma (WorldSim._apply_effects / end_form): `was` = a forma de antes.
static func form_changed(sim: WorldSim, e: SimEntity, was: String) -> void:
	if e.form == LICH and was != LICH:
		if ProgressionSystem.asc_flag(e, "nec_lich_reaper"):
			e.form_left += Balance.LORD_LICH_REAPER_TIME
	elif was == LICH and e.form != LICH:
		trim_summons(sim, e)

## Na Forma de Lich a maldição lançada passa para os inimigos a LORD_LICH_SPREAD m do amaldiçoado.
static func spread_curse(sim: WorldSim, src: SimEntity, t: SimEntity, curse: Dictionary) -> int:
	if src.form != LICH or not sim.maps.has(t.map_id):
		return 0
	var r := Balance.LORD_LICH_SPREAD * (Balance.LORD_LICH_PLAGUE_MULT if ProgressionSystem.asc_flag(src, "nec_lich_plague") else 1.0)
	var n := 0
	for o in sim.maps[t.map_id]["entities"]:
		if o != t and o.is_alive() and src.is_hostile_to(o) and o.position.distance_to(t.position) <= r + o.radius:
			o.put_debuff(curse.duplicate())
			n += 1
	return n

# ---------------------------------------------------------------------------
# Refinos (nós da teia de ascensão)
# ---------------------------------------------------------------------------
## Skill de ascensão com os nós comprados: Miasma/Marca mais largos e longos, Pacto mais longo e com mais roubo de vida.
## Sem nó que mexa nela devolve a própria skill (sem alocação).
static func resolve(e: SimEntity, s: SkillDef) -> SkillDef:
	if not s.ascension or s.class_id != CLASS_ID or not e.is_character():
		return s
	var fx := s.effects
	var area: bool = fx.has("miasma") or fx.has("grave_mark")
	var wide: bool = area and ProgressionSystem.asc_flag(e, "nec_wide")
	var fog: bool = fx.has("miasma") and ProgressionSystem.asc_flag(e, "nec_fog")
	var deep: bool = fx.has("grave_mark") and ProgressionSystem.asc_flag(e, "nec_deep_grave")
	var bond: bool = fx.has("summon_pact") and ProgressionSystem.asc_flag(e, "nec_bond")
	var blood: bool = fx.has("summon_pact") and ProgressionSystem.asc_flag(e, "nec_blood_pact")
	if not (wide or fog or deep or bond or blood):
		return s
	var out: SkillDef = s.duplicate()
	out.talent_effects = s.talent_effects.duplicate(true)
	if wide:
		out.radius = s.radius * Balance.LORD_WIDE_MULT
	if fog:
		var z: Dictionary = (out.talent_effects.get("miasma", fx["miasma"]) as Dictionary).duplicate()
		z["duration"] = float(z.get("duration", Balance.LORD_MIASMA_TIME)) + Balance.LORD_FOG_TIME
		out.talent_effects["miasma"] = z
	if deep:
		var g: Dictionary = (out.talent_effects.get("grave_mark", fx["grave_mark"]) as Dictionary).duplicate()
		g["raise"] = float(g.get("raise", Balance.LORD_GRAVE_RAISE_TIME)) + Balance.LORD_DEEP_GRAVE_TIME
		out.talent_effects["grave_mark"] = g
	if bond:
		var b: Dictionary = (out.talent_effects.get("buff", fx["buff"]) as Dictionary).duplicate()
		b["duration"] = float(b.get("duration", Balance.LORD_PACT_TIME)) + Balance.LORD_BOND_TIME
		out.talent_effects["buff"] = b
	if blood:
		var p: Dictionary = (out.talent_effects.get("summon_pact", fx["summon_pact"]) as Dictionary).duplicate()
		p["leech_pct"] = float(p.get("leech_pct", 0)) * Balance.LORD_BLOOD_PACT_MULT
		out.talent_effects["summon_pact"] = p
	return out

## Foice que Comanda (refino do Ceifador): o golpe do necromante manda as invocações no mesmo alvo.
static func on_strike(sim: WorldSim, e: SimEntity, t: SimEntity) -> void:
	if e.class_def == null or e.class_def.id != CLASS_ID or e.asc_tree.is_empty() or not t.is_alive() or not e.is_hostile_to(t):
		return
	if float(e.cooldowns.get(CMD_CD, 0.0)) > 0.0 or not ProgressionSystem.asc_flag(e, "nec_command") or not sim.maps.has(e.map_id):
		return
	e.cooldowns[CMD_CD] = Balance.LORD_COMMAND_EVERY
	for o in sim.maps[e.map_id]["entities"]:
		if o.kind == SimEntity.Kind.SUMMON and o.owner_id == e.id and o.is_alive() and o.elem_form == "":
			o.aggro_target = t.id
			if o.brain is MonsterBrain:
				o.brain.skill_rethink = Balance.LORD_COMMAND_FOCUS      # ordem do dono: segura este alvo um tempo

# ---------------------------------------------------------------------------
# Bots
# ---------------------------------------------------------------------------
## Inimigos vivos a `r` m de `pos` (para o bot decidir área).
static func _foes_near(e: SimEntity, m: Dictionary, pos: Vector3, r: float) -> Array:
	var out: Array = []
	for o in m["entities"]:
		if o.kind == SimEntity.Kind.MONSTER and o.is_alive() and absf(o.position.x - pos.x) <= r + 1.5 and o.position.distance_to(pos) <= r + o.radius:
			out.append(o)
	return out

static func _big(mob: SimEntity) -> bool:
	return mob.monster_def != null and (mob.monster_def.is_boss or mob.monster_def.elite_of != "")

## Nota do bot para uma skill de ascensão do Necromante (0 = agora não): Pacto com BOT_LORD_PACT_MIN+ invocações por
## perto em luta; Miasma no chefe/elite ou onde há BOT_LORD_PACK+ inimigos; Marca da Cova no bando com pouca vida;
## Forma de Lich contra chefe/elite ou bando.
static func bot_score(sim: WorldSim, e: SimEntity, s: SkillDef, mob: SimEntity, dist: float, m: Dictionary) -> float:
	var fx := s.effects
	if fx.has("summon_pact"):
		if has_pact(e) or dist > Balance.LORD_PACT_RADIUS:
			return 0.0
		var near := 0
		for o in m["entities"]:
			if o.kind == SimEntity.Kind.SUMMON and o.owner_id == e.id and o.is_alive() and o.position.distance_to(e.position) <= Balance.LORD_PACT_RADIUS:
				near += 1
		return Balance.BOT_LORD_SCORE if near >= Balance.BOT_LORD_PACT_MIN else 0.0
	if fx.has("miasma"):
		if dist > s.range or not miasma_of(sim, e).is_empty():
			return 0.0
		if _big(mob) or _foes_near(e, m, mob.position, s.radius).size() >= Balance.BOT_LORD_PACK:
			return Balance.BOT_LORD_SCORE
		return 0.0
	if fx.has("grave_mark"):
		if dist > s.range or _big(mob) or is_marked(mob) or graves_of(sim, e).size() >= Balance.LORD_GRAVE_MAX:
			return 0.0
		var pack := _foes_near(e, m, mob.position, s.radius).filter(func(o): return not _big(o))
		if pack.size() < Balance.BOT_LORD_GRAVE_PACK:
			return 0.0
		return Balance.BOT_LORD_SCORE if pack.any(func(o): return o.hp <= o.stats.max_hp * Balance.BOT_LORD_GRAVE_HP) else 0.0
	if str(fx.get("form", "")) == LICH:
		if e.form != "" or dist > Balance.BOT_FORM_RANGE:
			return 0.0
		if _big(mob) or _foes_near(e, m, mob.position, Balance.LORD_MIASMA_RADIUS).size() >= Balance.BOT_LORD_PACK:
			return Balance.BOT_FORM_SCORE
		return 0.0
	return 0.0
