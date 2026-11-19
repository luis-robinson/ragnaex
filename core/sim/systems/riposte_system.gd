class_name RiposteSystem
extends RefCounted
## Aparar e contra-atacar do Duelista (GDD design/gdd/skills-fill-2026-11-19.md §8.3). Sem estado próprio.
## A Guarda do Duelista (efeito "riposte") põe o buff Balance.RIPOSTE_BUFF por RIPOSTE_WINDOW s. Com ele (a cópia
## permanente do talento, `ct`, não conta), golpe direto de perto e de frente sai 0 (chefe: corta RIPOSTE_BOSS_CUT),
## devolve uma resposta (até RIPOSTE_MAX_COUNTERS por janela) e dá 1 Ímpeto (RIPOSTE_MOMENTUM_BUFF, +crítico por carga).
## O Golpe de Mestre ("momentum_spend") gasta o Ímpeto. A Riposte lendária (esquivar responde) usa a mesma resposta.

## A janela de aparar ativa em `e` (o buff lançado, não a cópia do talento); {} sem janela.
static func window(e: SimEntity) -> Dictionary:
	var found: Dictionary = {}
	for b in e.buffs:
		if b.has("riposte_gap"):
			return b                          # Duelo Supremo (id próprio: a Guarda comum não o substitui)
		if b.get("id") == Balance.RIPOSTE_BUFF and not b.get("ct", false):
			found = b
	return found

## Golpe direto de `attacker` em `target` (o chamador já tirou dano no tempo, zona avisada e golpe em si mesmo).
## Devolve -1 = aparado por inteiro (o golpe não entra); >= 0 = dano que passa (chefe); -2 = não aparou.
## A janela pode trazer "riposte_arc" (° do arco, senão o da guarda), "riposte_gain" (Ímpeto por aparo) e "riposte_gap".
static func on_hit(sim: WorldSim, target: SimEntity, attacker: SimEntity, amount: int, from: Variant) -> int:
	var w := window(target)
	if w.is_empty() or attacker.position.distance_to(target.position) > Balance.RIPOSTE_RANGE + attacker.radius + target.radius:
		return -2
	if not in_arc(target, attacker.position if from == null else from, float(w.get("riposte_arc", 0.0))):
		return -2
	gain(target, int(w.get("riposte_gain", 1)))
	if w.has("duel_cap"):                            # Duelo Supremo: aparar enche o contador do Duelo
		w["duel"] = mini(int(w["duel_cap"]), int(w.get("duel", 0)) + int(w.get("riposte_gain", 1)))
	var n := int(w.get("counters", 0))
	if w.has("riposte_gap"):                          # Duelo Supremo: respostas sem teto, no máximo uma a cada riposte_gap s
		if attacker.is_alive() and sim.time >= float(w.get("next_counter", -1.0)):
			w["next_counter"] = sim.time + float(w["riposte_gap"])
			sim.ult_tag += 1                          # resposta do Duelo = dano de Suprema (medição)
			counter(sim, target, attacker, Balance.RIPOSTE_COUNTER_PCT + legend_pct(target))
			sim.ult_tag -= 1
	elif n < Balance.RIPOSTE_MAX_COUNTERS and attacker.is_alive():
		w["counters"] = n + 1
		counter(sim, target, attacker, Balance.RIPOSTE_COUNTER_PCT + legend_pct(target))
	Events.post(&"blocked_hit", target.id)
	if attacker.monster_def != null and attacker.monster_def.is_boss:
		return maxi(1, int(round(amount * (1.0 - Balance.RIPOSTE_BOSS_CUT))))
	return -1

## Golpe vindo de `from` está no arco da janela (`arc_deg` 0 = o arco da guarda comum, Balance.BLOCK_ARC_DEG).
static func in_arc(target: SimEntity, from: Vector3, arc_deg: float) -> bool:
	if arc_deg <= 0.0:
		return Combat.in_guard_arc(target, from)
	var d := Vector2(from.x - target.position.x, from.z - target.position.z)
	if d.length_squared() < 0.0025:
		return true
	var f := target.forward()
	return absf(Vector2(f.x, f.z).angle_to(d)) <= deg_to_rad(arc_deg * 0.5)

## % do ATK que a arma lendária Riposte soma à resposta (0 sem ela).
static func legend_pct(e: SimEntity) -> float:
	return float(e.stats.legend.get("pct", 0.0)) if str(e.stats.legend.get("kind", "")) == "riposte" else 0.0

## Resposta: pct% do ATK de `e` em `attacker` (tipo "riposte": não gera outra resposta).
static func counter(sim: WorldSim, e: SimEntity, attacker: SimEntity, pct: float) -> void:
	sim._deal_damage(e, attacker, maxi(1, int(e.stats.patk * pct / 100.0)), false, false, "riposte")
	Events.post(&"skill_effect", "ass_cross_slash", e.position, attacker.position, 0.0)     # o corte da resposta

## Duelo Supremo: golpe direto do próprio duelista (básico ou skill, não a Suprema) durante a guarda soma "hit_gain" ao
## contador do Duelo, até "hit_cap" vindos de golpes (o contador todo vai até "duel_cap"; aparar soma "riposte_gain").
## O Golpe de Mestre do fim vale × (1 + "duel_per" × contador) (UltEffects.end_cast).
static func duel_hit(e: SimEntity) -> void:
	for b in e.buffs:
		if b.has("duel_cap"):
			var h := int(b.get("duel_hits", 0))
			if h < int(b.get("hit_cap", 0)):
				b["duel_hits"] = h + 1
				b["duel"] = mini(int(b["duel_cap"]), int(b.get("duel", 0)) + int(b.get("hit_gain", 1)))
			return

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
