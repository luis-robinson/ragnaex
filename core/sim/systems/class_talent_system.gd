class_name ClassTalentSystem
extends RefCounted
## Talentos de classe (ClassTalentsCatalog): escolhas da aba Talentos, guardadas como nós "pick" da teia
## (`<classe>_c_<opção>`, um por linha). Aqui só as regras; o estado fica na entidade:
##   e.ct (ganchos das escolhas, refeito em `refresh`), e.ct_ready_at (próximo "recusa a morrer"), e.immortal_left.
## Os `stats` das escolhas já entram pelo tree_bonus (recompute_tree_bonus soma os nós comprados).

static var bot_picks := true      # testes desligam: bots de teste sem talentos sorteados (comportamento padrão)
const TICK := 0.5                 # permanentes, auras e regeneração: a cada meio segundo
const KEEP := 1.3                 # buff permanente/aura dura isto e é renovado no tick (some logo se a escolha sair)

## Escolhas da entidade (dicionários do catálogo), na ordem das linhas.
static func picked(e: SimEntity) -> Array:
	var out: Array = []
	if e.class_def == null:
		return out
	var tr: Dictionary = GameData.trees.get(e.class_def.id, {})
	if tr.is_empty():
		return out
	for nid in e.tree:
		var n: Dictionary = tr["nodes"].get(nid, {})
		if n.get("kind", "") == "pick" and GameData.class_talents.has(n["ref"]):
			out.append(GameData.class_talents[n["ref"]])
	return out

## Junta os ganchos das escolhas em e.ct (chamado sempre que a teia muda: compra, troca, reset, carregar).
static func refresh(e: SimEntity) -> void:
	var ct := {}
	for o in picked(e):
		for skill_id in o.get("permanent", []):
			ct["permanent"] = ct.get("permanent", []) + [[skill_id, float(o.get("strength", 1.0)), 0.0]]
		for skill_id in o.get("aura", []):
			ct["permanent"] = ct.get("permanent", []) + [[skill_id, float(o.get("strength", 1.0)), float(o.get("radius", ClassTalentsCatalog.AURA_RADIUS))]]
		for skill_id in o.get("summon_permanent", []):
			var sp: Dictionary = ct.get("summon_permanent", {})
			sp[skill_id] = true
			ct["summon_permanent"] = sp
		for skill_id in o.get("summon_extra", {}):
			var se: Dictionary = ct.get("summon_extra", {})
			se[skill_id] = int(se.get(skill_id, 0)) + int(o["summon_extra"][skill_id])
			ct["summon_extra"] = se
		for skill_id in o.get("skill_mods", {}):
			var sm: Dictionary = ct.get("skill_mods", {})
			sm[skill_id] = sm.get(skill_id, []) + [o["skill_mods"][skill_id]]
			ct["skill_mods"] = sm
		if o.has("form_mult"):
			ct["form_mult"] = float(ct.get("form_mult", 1.0)) * float(o["form_mult"])
		for f in o.get("form_time", {}):
			var ft: Dictionary = ct.get("form_time", {})
			ft[f] = float(o["form_time"][f])
			ct["form_time"] = ft
		for k in ["cheat_death", "ally_save", "regen", "mana_shield", "low_hp", "execute"]:
			if o.has(k):
				ct[k] = o[k]
		if o.has("on_kill"):
			ct["on_kill"] = ct.get("on_kill", []) + [o["on_kill"]]
		for k in ["ambush_mult", "trap_max", "oath_max"]:
			if o.has(k):
				ct[k] = o[k]
	e.ct = ct

# --- skills -----------------------------------------------------------------------------------------------------
## Skill com os mods das escolhas (set/mult/effects; "duration" multiplica as durações dos efeitos).
static func apply_mods(e: SimEntity, s: SkillDef) -> SkillDef:
	var list: Array = e.ct.get("skill_mods", {}).get(s.id, [])
	if list.is_empty():
		return s
	var out: SkillDef = s.duplicate()
	out.talent_effects = s.talent_effects.duplicate(true)
	for md in list:
		for k in md.get("set", {}):
			out.set(k, md["set"][k])
		for k in md.get("mult", {}):
			if k == "duration":
				_scale_durations(out, float(md["mult"][k]))
			else:
				out.set(k, float(out.get(k)) * float(md["mult"][k]))
		for k in md.get("effects", {}):
			out.talent_effects[k] = md["effects"][k]
	return out

static func _scale_durations(s: SkillDef, f: float) -> void:
	for k in s.effects:
		var v: Variant = s.talent_effects.get(k, s.effects[k])
		if v is Dictionary and (v as Dictionary).has("duration"):
			var d: Dictionary = (v as Dictionary).duplicate(true)
			d["duration"] = float(d["duration"]) * f
			s.talent_effects[k] = d
		elif k == "stealth":
			s.talent_effects[k] = float(v) * f

static func summon_permanent(e: SimEntity, skill_id: String) -> bool:
	return e.ct.get("summon_permanent", {}).has(skill_id)

static func summon_extra(e: SimEntity, skill_id: String) -> int:
	return int(e.ct.get("summon_extra", {}).get(skill_id, 0))

static func form_mult(e: SimEntity) -> float:
	return float(e.ct.get("form_mult", 1.0))

static func form_time(e: SimEntity, form: String) -> float:
	return float(e.ct.get("form_time", {}).get(form, 1.0))

static func ambush_mult(e: SimEntity) -> float:
	return float(e.ct.get("ambush_mult", Balance.AMBUSH_MULT))

static func trap_max(e: SimEntity) -> int:
	return int(e.ct.get("trap_max", Balance.TRAP_MAX))

static func oath_max(e: SimEntity) -> int:
	return int(e.ct.get("oath_max", Balance.SHIELD_OATH_MAX))

## Bônus da skill que vira permanente/aura: só os números positivos × força (a lentidão da Muralha fica de fora).
static func passive_buff(skill_id: String, strength: float) -> Dictionary:
	var s: SkillDef = GameData.skills.get(skill_id)
	if s == null or not (s.effects.get("buff") is Dictionary):
		return {}
	var b: Dictionary = s.effects["buff"]
	var out := {"id": b.get("id", skill_id), "ct": true}
	for k in b:
		if k in ["id", "duration"]:
			continue
		if (b[k] is float or b[k] is int) and float(b[k]) > 0.0:
			out[k] = float(b[k]) * strength
	return out

# --- tick: permanentes, auras, regeneração, imortalidade ----------------------------------------------------------
static func tick(sim: WorldSim, m: Dictionary, dt: float) -> void:
	m["ct_t"] = float(m.get("ct_t", 0.0)) + dt
	if float(m["ct_t"]) < TICK:
		return
	var step: float = m["ct_t"]
	m["ct_t"] = 0.0
	for e in m["entities"]:
		if e.immortal_left > 0.0:
			e.immortal_left = maxf(0.0, e.immortal_left - step)
		if e.ct.is_empty() or not e.is_alive() or not e.is_character():
			continue
		for pb in e.ct.get("permanent", []):
			var b := passive_buff(pb[0], float(pb[1]))
			if b.size() <= 2:
				continue
			var R: float = pb[2]
			for t in _receivers(sim, e, m, R):
				_keep_buff(t, b)
			var sk: SkillDef = GameData.skills.get(pb[0])
			if R <= 0.0 and sk and sk.effects.get("pet_buff", false):      # Instinto da Matilha: no lince também
				var pet := sim.pet_of(e)
				if pet:
					_keep_buff(pet, b)
		var rg: Dictionary = e.ct.get("regen", {})
		if not rg.is_empty() and (not rg.get("form", false) or e.form != ""):
			for t in _receivers(sim, e, m, ClassTalentsCatalog.AURA_RADIUS if rg.get("aura", false) else 0.0):
				if t.hp < t.stats.max_hp:
					sim._heal(e, t, maxi(1, int(t.stats.max_hp * float(rg["pct"]) / 100.0 * step)))

## Quem recebe: só você (R = 0) ou você + grupo + suas invocações a até R metros.
static func _receivers(sim: WorldSim, e: SimEntity, m: Dictionary, R: float) -> Array:
	if R <= 0.0:
		return [e]
	var out: Array = []
	for t in m["entities"]:
		if not t.is_alive() or t.position.distance_to(e.position) > R:
			continue
		if t == e or (t.is_character() and e.party_id >= 0 and t.party_id == e.party_id) or (t.kind == SimEntity.Kind.SUMMON and t.owner_id == e.id):
			out.append(t)
	return out

static func _keep_buff(t: SimEntity, b: Dictionary) -> void:
	for x in t.buffs:
		if x.get("id") == b["id"]:
			if not x.get("ct", false) and float(x.get("remaining", 0.0)) > KEEP:
				return                       # o lançado (mais forte) ainda está valendo
			if x.get("ct", false):
				x["remaining"] = KEEP
				return
	var nb := b.duplicate()
	nb["remaining"] = KEEP
	t.put_buff(nb)
	t.recompute_stats()

# --- dano e morte -------------------------------------------------------------------------------------------------
## Multiplicador de dano do atacante (ferido / execução).
static func damage_mult(attacker: SimEntity, target: SimEntity) -> float:
	var src := attacker
	if attacker.ct.is_empty():
		return 1.0
	var mult := 1.0
	var lo: Dictionary = src.ct.get("low_hp", {})
	if not lo.is_empty() and src.hp < src.stats.max_hp * float(lo["below"]):
		mult *= 1.0 + float(lo["dmg_pct"]) / 100.0
	var ex: Dictionary = src.ct.get("execute", {})
	if not ex.is_empty() and target.stats and target.hp < target.stats.max_hp * float(ex["below"]):
		mult *= 1.0 + float(ex["dmg_pct"]) / 100.0
	return mult

## Escudo de Mana: parte do dano sai do MP. Devolve o dano que sobra para o HP.
static func mana_shield(target: SimEntity, amount: int) -> int:
	var ms: Dictionary = target.ct.get("mana_shield", {})
	if ms.is_empty() or amount <= 0:
		return amount
	var take := minf(target.mp, amount * float(ms["pct"]) / 100.0)
	target.mp -= take
	return amount - int(take)

## Dano que vai ser aplicado: imortal não passa de 1 HP; golpe fatal pode acionar "recusa a morrer" (seu ou de um
## aliado com Intercessão). Devolve o dano ajustado.
static func before_hit(sim: WorldSim, target: SimEntity, amount: int) -> int:
	if amount <= 0:
		return amount
	if target.immortal_left > 0.0:
		return mini(amount, maxi(0, int(target.hp) - 1))
	if target.hp - amount > 0.0 or not target.is_character():
		return amount
	var cd: Dictionary = target.ct.get("cheat_death", {})
	if not cd.is_empty() and sim.time >= target.ct_ready_at:
		_save(sim, target, target, float(cd["cd"]), float(cd["dur"]), cd.get("stealth", false))
		return maxi(0, int(target.hp) - 1)
	for o in sim.maps[target.map_id]["entities"] if sim.maps.has(target.map_id) else []:
		if o == target or not o.is_alive() or o.ct.is_empty() or o.party_id < 0 or o.party_id != target.party_id:
			continue
		var al: Dictionary = o.ct.get("ally_save", {})
		if not al.is_empty() and sim.time >= o.ct_ready_at and o.position.distance_to(target.position) <= float(al["radius"]):
			_save(sim, o, target, float(al["cd"]), float(al["dur"]), false)
			return maxi(0, int(target.hp) - 1)
	return amount

static func _save(sim: WorldSim, owner: SimEntity, target: SimEntity, cd: float, dur: float, stealth: bool) -> void:
	owner.ct_ready_at = sim.time + cd
	target.immortal_left = dur
	if stealth:
		sim._apply_effects(target, target, {"stealth": dur}, 0.0)
	Events.buff_applied.emit(target.id, "immortal", dur)
	if target == sim.player or owner == sim.player:
		Events.notification.emit("%s se recusa a cair! (%d s)" % [target.name, int(dur)])

## Abate: cura, MP, furtividade ou buff renovado (escolhas "on_kill"). Abate da invocação conta para o dono se `minions`.
static func on_kill(sim: WorldSim, killer: SimEntity, victim: SimEntity) -> void:
	if killer == null or victim == null or victim.kind != SimEntity.Kind.MONSTER:
		return
	var e := killer
	var by_minion := false
	if killer.kind == SimEntity.Kind.SUMMON:
		e = sim.entities.get(killer.owner_id)
		by_minion = true
	if e == null or e.ct.is_empty() or not e.is_alive():
		return
	for ok in e.ct.get("on_kill", []):
		if by_minion and not ok.get("minions", false):
			continue
		if ok.has("heal_pct"):
			sim._heal(e, e, maxi(1, int(e.stats.max_hp * float(ok["heal_pct"]) / 100.0)))
		if ok.has("mp_pct"):
			e.mp = minf(e.stats.max_mp, e.mp + e.stats.max_mp * float(ok["mp_pct"]) / 100.0)
		if ok.has("stealth"):
			sim._apply_effects(e, e, {"stealth": float(ok["stealth"])}, 0.0)
		if ok.has("buff"):
			var sk: SkillDef = GameData.skills.get(ok["buff"])
			if sk and sk.effects.get("buff") is Dictionary:
				sim._apply_effects(e, e, {"buff": sk.effects["buff"]}, 0.0)

# --- bots ---------------------------------------------------------------------------------------------------------
## Bot escolhe uma opção por linha liberada: de preferência a que fala de uma skill da build (ou genérica).
static func bot_pick(sim: WorldSim, e: SimEntity) -> void:
	if not bot_picks:
		return
	var rows: Array = ClassTalentsCatalog.build().get(e.class_def.id, [])
	var build := e.class_def.build_by_id(e.build_id)
	var mine: Array = build.get("skills", e.class_def.skill_ids)
	for row in rows:
		if int(row[0]) > e.level:
			continue
		var good: Array = []
		for o in row[1]:
			var refs: Array = o.get("permanent", []) + o.get("aura", []) + o.get("summon_permanent", []) + o.get("skill_mods", {}).keys() + o.get("summon_extra", {}).keys()
			if refs.is_empty() or refs.any(func(r): return r in mine):
				good.append(o)
		if good.is_empty():
			good = row[1]
		var o: Dictionary = good[sim.rng.randi() % good.size()]
		var nid := "%s_c_%s" % [e.class_def.id, o["id"]]
		if not e.tree.has(nid) and ProgressionSystem.pick_sibling(sim, e, nid) == "":
			ProgressionSystem.tree_allocate(sim, e, nid)
