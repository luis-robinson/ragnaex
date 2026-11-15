class_name DruidAscension
extends RefCounted
## Ascensão do Druida (Ato II, 35; GDD ato2-horda R6.1): Forma Ancestral — a 3ª forma de cada build.
## Urso -> Ent ("ent": raízes que prendem e provocam em área, grupo protegido), Lobo -> Lobo Alfa ("alpha": chama a
## matilha, uivo de velocidade), Xamã -> Pássaro Arcano ("bird": voa por cima do chão — só desenho, a sim é plana —,
## raio em cadeia, chuva de penas de luz que cura, rajada de vento que empurra).
## As formas são skills de ligar/desligar como Lobo/Urso (SimEntity.form, Balance.FORM_STATS/FORM_REQUIRES) e trocam as
## skills da build pelas variantes de SkillsCatalog.FORM_MODS. Regras sem estado próprio; números em Balance.ANC_*.

const FORMS := ["ent", "alpha", "bird"]

static func is_ancestral(form: String) -> bool:
	return form in FORMS

## Forma de base da ancestral ("" se não tiver): o Ent vale por urso, o Lobo Alfa por lobo.
static func base_of(form: String) -> String:
	return str(Balance.ANC_FORM_BASE.get(form, ""))

## `SkillDef.requires_form` atendida: a própria forma ou a ancestral dela (Espreitar sai como Lobo Alfa).
static func form_ok(e: SimEntity, need: String) -> bool:
	return need == "" or e.form == need or (e.form != "" and base_of(e.form) == need)

## Variante da skill na forma (SkillsCatalog.FORM_MODS); a ancestral sem entrada própria usa a da forma de base.
static func form_mods(skill_id: String, form: String) -> Dictionary:
	var by: Dictionary = SkillsCatalog.form_variants(skill_id)
	if by.has(form):
		return by[form]
	var base := base_of(form)
	return by.get(base, {}) if base != "" else {}

## Tanque do grupo: sem grupo, ou o primeiro membro vivo no mapa com papel "tank" (a mesma regra do BotBrain._tank_of) é ele, ou não há nenhum.
static func is_group_tank(sim: WorldSim, e: SimEntity) -> bool:
	if e.party_id < 0:
		return true
	for o: SimEntity in sim.party_members(e):
		if o.is_alive() and o.map_id == e.map_id and sim.role_of(o) == "tank":
			return o == e
	return true

## Provocação em área (Raízes Ancestrais): o Ent só provoca quando é o tanque do grupo; ao lado de outro tanque as raízes ferem e prendem, sem puxar o chefe (2026-11-12).
static func may_provoke(sim: WorldSim, e: SimEntity) -> bool:
	return e.form != "ent" or is_group_tank(sim, e)

## % de ameaça a mais que `e` gera (Stats.threat_pct). A ameaça extra do Ent (FORM_STATS) só vale se ele for o tanque do grupo:
## como 2º membro ao lado de outro tanque ele não rouba o chefe (decisão do autor, 2026-11-12).
static func threat_pct(sim: WorldSim, e: SimEntity) -> float:
	if e.form != "ent" or is_group_tank(sim, e):
		return e.stats.threat_pct
	return e.stats.threat_pct - float(SimEntity.scaled_bonus(Balance.FORM_STATS["ent"], e.form_mult).get("threat_pct", 0.0))

## Peso F5 da ascensão da build no nível do dono (Balance.asc_power).
static func asc_power(build: String, level: int) -> float:
	return Balance.asc_power(build, level)

## Refinos comprados (0-2) da forma ancestral em que `e` está: nós da teia de ascensão com portão de nível 40 e 45.
static func refines(e: SimEntity) -> int:
	if not is_ancestral(e.form) or not e.is_character() or e.asc_tree.is_empty():
		return 0
	var n := 0
	for flag in Balance.ANC_REFINE_FLAGS.get(e.form, []):
		if ProgressionSystem.asc_flag(e, flag):
			n += 1
	return n

## Poder somado dos refinos comprados da forma ancestral de `e` (ANC_REFINE_POWER por nó; o do 45 pode ter
## peso próprio em ANC_REFINE_POWER_NODE, F5 no 45 sem mexer no 35/40).
static func refine_power(e: SimEntity) -> float:
	if not is_ancestral(e.form) or not e.is_character() or e.asc_tree.is_empty():
		return 0.0
	var p := 0.0
	for flag in Balance.ANC_REFINE_FLAGS.get(e.form, []):
		if ProgressionSystem.asc_flag(e, flag):
			p += float(Balance.ANC_REFINE_POWER_NODE.get(flag, Balance.ANC_REFINE_POWER))
	return p

## Refino (40/45): na forma ancestral, as variantes (`variant`) e as skills só da forma ganham poder e duração.
## `base` = a skill do catálogo; `out` = a resolvida até aqui. Sem refino devolve `out` (sem alocação).
static func refine(e: SimEntity, base: SkillDef, out: SkillDef, variant: bool) -> SkillDef:
	if not is_ancestral(e.form) or not (variant or base.requires_form == e.form):
		return out
	var n := refines(e)
	if n <= 0:
		return out
	if out == base or not variant:
		var te: Dictionary = out.talent_effects        # duplicate() não leva variável sem @export
		out = out.duplicate()
		out.talent_effects = te.duplicate()
	out.power *= 1.0 + refine_power(e)
	var longer := 1.0 + Balance.ANC_REFINE_TIME * n
	for k in ["root", "stun", "slow", "provoke", "taunt", "buff"]:
		var fx = out.talent_effects.get(k, out.effects.get(k))
		if fx is Dictionary and fx.has("duration"):
			var d: Dictionary = (fx as Dictionary).duplicate()
			d["duration"] = float(d["duration"]) * longer
			out.talent_effects[k] = d
	return out

# ---------------------------------------------------------------------------
# Lobo Alfa: a matilha
# ---------------------------------------------------------------------------
static func is_pack(e: SimEntity) -> bool:
	return e != null and e.kind == SimEntity.Kind.SUMMON and e.monster_def != null and e.monster_def.id == Balance.ANC_PACK_MONSTER

## Lobos da matilha vivos do dono no mapa dele.
static func pack_of(sim: WorldSim, owner: SimEntity) -> Array:
	var out: Array = []
	if not sim.maps.has(owner.map_id):
		return out
	for o in sim.maps[owner.map_id]["entities"]:
		if o.owner_id == owner.id and o.is_alive() and is_pack(o):
			out.append(o)
	return out

## Chama a matilha: `count` lobos por ANC_PACK_TIME s (x refino), com parte da vida/ataque/defesa do dono. Os antigos somem.
static func call_pack(sim: WorldSim, e: SimEntity, s: SkillDef, pk: Dictionary) -> Array:
	var out: Array = []
	var mdef: MonsterDef = GameData.monsters.get(str(pk.get("monster_id", Balance.ANC_PACK_MONSTER)))
	if mdef == null or not sim.maps.has(e.map_id):
		return out
	for o in pack_of(sim, e):
		sim.despawn(o)
	var dur := Balance.ANC_PACK_TIME * (1.0 + Balance.ANC_REFINE_TIME * refines(e))
	var n := int(pk.get("count", Balance.ANC_PACK_COUNT))
	var md: MapDef = sim.maps[e.map_id]["def"]
	for i in range(n):
		var a := TAU * (i + 0.5) / float(n)
		var pos := e.position + e.forward() * 1.2 + Vector3(cos(a), 0, sin(a)) * 1.3
		if not sim.is_walkable(pos, md, mdef.radius):
			pos = e.position
		var w := sim.spawn_summon(e, mdef, pos, dur, false)
		w.summon_hp = e.stats.max_hp * Balance.ANC_PACK_HP_SHARE
		w.summon_patk = e.stats.patk * Balance.ANC_PACK_ATK_SHARE * asc_power(s.build, e.level)
		w.recompute_stats()
		w.stats.pdef = e.stats.pdef * Balance.ANC_PACK_DEF_SHARE
		w.stats.mdef = e.stats.mdef * Balance.ANC_PACK_DEF_SHARE
		w.stats.patk = w.summon_patk
		w.stats.matk = w.summon_patk
		w.heal_full()
		out.append(w)
	Events.post(&"skill_effect", s.id, e.position, e.position, 2.0)
	return out

# ---------------------------------------------------------------------------
# Pássaro Arcano: penas que curam e vento que empurra
# ---------------------------------------------------------------------------
## Cura (x MATK) quem lançou e os aliados dentro da área do golpe (centro = ponto mirado no GROUND, senão quem lançou).
static func area_heal(sim: WorldSim, e: SimEntity, s: SkillDef, aim: Vector3, ah: Dictionary, m: Dictionary) -> int:
	var center: Vector3 = aim if s.target == SkillDef.Target.GROUND else e.position
	var pw := float(ah.get("power", Balance.ANC_FEATHER_HEAL)) * asc_power(s.build, e.level)
	var healed := 0
	for o in m["entities"]:
		if not o.is_alive() or not (o == e or e.is_friend(o)) or o.kind == SimEntity.Kind.NPC:
			continue
		if Vector2(o.position.x, o.position.z).distance_to(Vector2(center.x, center.z)) > s.radius + o.radius:
			continue
		sim._heal(e, o, Combat.calc_heal(e, pw, sim.rng))
		healed += 1
	return healed

## Empurra `t` para longe de `kb.from` (ou de quem lançou) por `dist` m, parando em parede/água. Chefe e quem está
## em torre ficam no lugar.
static func knockback(sim: WorldSim, src: SimEntity, t: SimEntity, kb: Dictionary) -> void:
	if not src.is_hostile_to(t) or (t.monster_def and t.monster_def.is_boss) or t.is_perched() or not sim.maps.has(t.map_id):
		return
	var from: Vector3 = kb.get("from", src.position)
	var away := t.position - from
	away.y = 0.0
	if away.length() < 0.05:
		away = t.position - src.position
		away.y = 0.0
	if away.length() < 0.05:
		away = src.forward()
	sim._charge(t, away.normalized() * float(kb.get("dist", Balance.ANC_GUST_PUSH)), sim.maps[t.map_id])

# ---------------------------------------------------------------------------
# Bots
# ---------------------------------------------------------------------------
## Skill de forma ancestral que o bot tem na barra e pode usar agora ("" = nenhuma): nível, arma e a skill aprendida.
static func bot_ancestral(e: SimEntity) -> String:
	if e.class_def == null or e.class_def.id != "druid":
		return ""
	for s in e.skills:
		if s == null or not s.ascension:
			continue
		var f: String = str(s.effects.get("form", ""))
		if is_ancestral(f) and e.knows(s.id) and e.level >= s.unlock_level and e.stats.meets(s.requires):
			return f
	return ""

## BotBrain: o bot ascendido entra na forma ancestral e fica nela — não volta para a forma de base (Urso/Lobo) nem pede
## skill que só sai em outra forma (a sim recusaria e ele ficaria parado pedindo).
static func bot_skips(e: SimEntity, s: SkillDef) -> bool:
	if not form_ok(e, s.requires_form):
		return true
	var f: String = str(s.effects.get("form", ""))
	if f == "" or is_ancestral(f):
		return false
	var anc := bot_ancestral(e)
	return anc != "" and base_of(anc) == f
