class_name AuraSystem
extends RefCounted
## Auras de liga/desliga (efeito "aura" de skill, ex.: Aura do Bastião do Paladino Guardião).
## Ligar = o `buff` da skill (com "toggle", sem fim) fica em quem lançou; enquanto durar, o grupo e as invocações
## a `radius` m recebem o `ally` com o mesmo id, renovado a cada Balance.AURA_TICK (some Balance.AURA_KEEP s depois
## de sair do raio ou da aura desligar). Lançar de novo desliga. Morrer limpa os buffs (desliga também).

## A aura desta skill está ligada em `e`?
static func aura_on(e: SimEntity, s: SkillDef) -> bool:
	var id := aura_id(s)
	return id != "" and e.buffs.any(func(b): return b.get("id") == id and b.get("toggle", false))

static func aura_id(s: SkillDef) -> String:
	var b = s.effects.get("buff")
	return str(b.get("id", "")) if b is Dictionary else ""

static func switch_off(sim: WorldSim, e: SimEntity, s: SkillDef) -> void:
	e.drop_buff(aura_id(s))
	e.recompute_stats()
	Events.buff_applied.emit(e.id, aura_id(s) + "_off", 0.0)
	if e == sim.player:
		Events.notification.emit("%s desligada" % s.name)

## Renova o buff de aliado de cada aura ligada no mapa.
static func tick(sim: WorldSim, m: Dictionary, dt: float) -> void:
	m["aura_t"] = float(m.get("aura_t", 0.0)) + dt
	if float(m["aura_t"]) < Balance.AURA_TICK:
		return
	m["aura_t"] = 0.0
	for e in m["entities"]:
		if not e.is_alive() or e.buffs.is_empty() or not e.is_character():
			continue
		for b in e.buffs:
			if not b.get("toggle", false) or not (b.get("aura") is Dictionary):
				continue
			var au: Dictionary = b["aura"]
			var ally: Dictionary = au.get("ally", {}).duplicate()
			ally["id"] = b["id"]
			ally["aura_from"] = e.id
			for t in receivers(sim, e, m, float(au.get("radius", 12.0))):
				_keep(t, ally)

## Quem recebe a aura: o grupo de `e` e as invocações dele a até R metros (sem ele: o dele é o buff da skill).
static func receivers(sim: WorldSim, e: SimEntity, m: Dictionary, R: float) -> Array:
	var out: Array = []
	for t in m["entities"]:
		if t == e or not t.is_alive() or t.position.distance_to(e.position) > R:
			continue
		if (t.is_character() and e.party_id >= 0 and t.party_id == e.party_id) or (t.kind == SimEntity.Kind.SUMMON and t.owner_id == e.id):
			out.append(t)
	return out

static func _keep(t: SimEntity, ally: Dictionary) -> void:
	for x in t.buffs:
		if x.get("id") == ally["id"]:
			if x.get("toggle", false):
				return                         # ele mesmo tem a aura ligada (dois tanques): vale a dele
			if x.has("aura_from"):
				x["remaining"] = Balance.AURA_KEEP
				return
	var nb := ally.duplicate()
	nb["remaining"] = Balance.AURA_KEEP
	t.put_buff(nb)
	t.recompute_stats()
	Events.buff_applied.emit(t.id, nb["id"], Balance.AURA_KEEP)
