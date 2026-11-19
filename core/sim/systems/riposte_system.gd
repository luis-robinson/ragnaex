class_name RiposteSystem
extends RefCounted
## Aparar e contra-atacar do Duelista (GDD design/gdd/skills-fill-2026-11-19.md §8.3). Sem estado próprio.
## A Guarda do Duelista (efeito "riposte") põe o buff Balance.RIPOSTE_BUFF por RIPOSTE_WINDOW s. Com ele (a cópia
## permanente do talento, `ct`, não conta), golpe direto de perto e de frente sai 0 (chefe: corta RIPOSTE_BOSS_CUT),
## devolve uma resposta (até RIPOSTE_MAX_COUNTERS por janela) e dá 1 Ímpeto (RIPOSTE_MOMENTUM_BUFF, +crítico por carga).
## O Golpe de Mestre ("momentum_spend") gasta o Ímpeto. A Riposte lendária (esquivar responde) usa a mesma resposta.

## A janela de aparar ativa em `e` (o buff lançado, não a cópia do talento); {} sem janela.
static func window(e: SimEntity) -> Dictionary:
	for b in e.buffs:
		if b.get("id") == Balance.RIPOSTE_BUFF and not b.get("ct", false):
			return b
	return {}

## Golpe direto de `attacker` em `target` (o chamador já tirou dano no tempo, zona avisada e golpe em si mesmo).
## Devolve -1 = aparado por inteiro (o golpe não entra); >= 0 = dano que passa (chefe); -2 = não aparou.
static func on_hit(sim: WorldSim, target: SimEntity, attacker: SimEntity, amount: int, from: Variant) -> int:
	var w := window(target)
	if w.is_empty() or attacker.position.distance_to(target.position) > Balance.RIPOSTE_RANGE + attacker.radius + target.radius:
		return -2
	if not Combat.in_guard_arc(target, attacker.position if from == null else from):
		return -2
	gain(target, 1)
	var n := int(w.get("counters", 0))
	if n < Balance.RIPOSTE_MAX_COUNTERS and attacker.is_alive():
		w["counters"] = n + 1
		counter(sim, target, attacker, Balance.RIPOSTE_COUNTER_PCT + legend_pct(target))
	Events.post(&"blocked_hit", target.id)
	if attacker.monster_def != null and attacker.monster_def.is_boss:
		return maxi(1, int(round(amount * (1.0 - Balance.RIPOSTE_BOSS_CUT))))
	return -1

## % do ATK que a arma lendária Riposte soma à resposta (0 sem ela).
static func legend_pct(e: SimEntity) -> float:
	return float(e.stats.legend.get("pct", 0.0)) if str(e.stats.legend.get("kind", "")) == "riposte" else 0.0

## Resposta: pct% do ATK de `e` em `attacker` (tipo "riposte": não gera outra resposta).
static func counter(sim: WorldSim, e: SimEntity, attacker: SimEntity, pct: float) -> void:
	sim._deal_damage(e, attacker, maxi(1, int(e.stats.patk * pct / 100.0)), false, false, "riposte")
	Events.post(&"skill_effect", "ass_cross_slash", e.position, attacker.position, 0.0)     # o corte da resposta

## Riposte lendária: `target` esquivou o golpe de `attacker` (perto): responde e ganha 1 Ímpeto.
static func legend_dodge(sim: WorldSim, target: SimEntity, attacker: SimEntity, kind: String) -> void:
	if kind == "riposte" or str(target.stats.legend.get("kind", "")) != "riposte" or not attacker.is_alive() \
			or attacker.position.distance_to(target.position) > Balance.LEG_RIPOSTE_RANGE:
		return
	counter(sim, target, attacker, float(target.stats.legend["pct"]))
	gain(target, 1)

## +n Ímpeto (até o máximo; o tempo renova a cada ganho).
static func gain(e: SimEntity, n: int) -> void:
	var cur := e.buff_stacks(Balance.RIPOSTE_MOMENTUM_BUFF)
	var now := mini(Balance.RIPOSTE_MOMENTUM_MAX, cur + n)
	e.put_buff({"id": Balance.RIPOSTE_MOMENTUM_BUFF, "remaining": Balance.RIPOSTE_MOMENTUM_TIME, "stacks": now,
		"crit": Balance.RIPOSTE_MOMENTUM_CRIT * now})
	e.recompute_stats()
	if now != cur:
		Events.post(&"buff_applied", e.id, Balance.RIPOSTE_MOMENTUM_BUFF, Balance.RIPOSTE_MOMENTUM_TIME)

## Golpe de Mestre: gasta todo o Ímpeto; devolve o multiplicador de poder (1 + power_pct% por carga).
static func spend(e: SimEntity, power_pct: float) -> float:
	var n := e.buff_stacks(Balance.RIPOSTE_MOMENTUM_BUFF)
	if n <= 0:
		return 1.0
	e.drop_buff(Balance.RIPOSTE_MOMENTUM_BUFF)
	e.recompute_stats()
	return 1.0 + power_pct / 100.0 * n

## Bot: abre a Guarda com um inimigo colado preparando um golpe nele, ou com BOT_RIPOSTE_CROWD+ inimigos em cima.
static func bot_wants(sim: WorldSim, e: SimEntity) -> bool:
	if not sim.maps.has(e.map_id):
		return false
	var reach := Balance.RIPOSTE_RANGE + e.radius
	var on_me := 0
	for o: SimEntity in sim.maps[e.map_id]["entities"]:
		if o.kind != SimEntity.Kind.MONSTER or o.aggro_target != e.id or o.position.distance_to(e.position) > reach + o.radius or not o.is_alive():
			continue
		if o.current_skill != null and o.skill_phase == "startup":
			return true
		on_me += 1
	return on_me >= Balance.BOT_RIPOSTE_CROWD
