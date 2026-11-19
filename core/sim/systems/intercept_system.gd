class_name InterceptSystem
extends RefCounted
## Proteção (efeito "intercept"; Suprema Bastião da Aurora, GDD ultimates-lv40 §9): aliados a `radius` m de quem lançou
## levam -pct% de dano e essa parte vai para ele (passa pelo escudo, aparar e esquiva dele; não enche a Carga Suprema).
## Fora do DR_CAP (mesmo caminho da cúpula do Coro). Duas Proteções não somam: vale a do protetor mais perto; quem protege
## não é protegido. Acaba sozinha se o protetor cair abaixo de stop_below% da vida.
## Estado: buff Balance.INTERCEPT_BUFF no protetor ({radius, pct, stop_below}) + m["interceptors"] (ids, para o caminho
## rápido: mapa sem protetor não procura nada).
## d = {"radius", "pct", "duration", "stop_below"}

## Liga a Proteção em `e`.
static func start(sim: WorldSim, e: SimEntity, d: Dictionary) -> void:
	var dur := float(d.get("duration", 8.0))
	e.put_buff({"id": Balance.INTERCEPT_BUFF, "remaining": dur, "radius": float(d.get("radius", 8.0)), "pct": float(d.get("pct", 30.0)),
		"stop_below": float(d.get("stop_below", 25.0))})
	var m: Dictionary = sim.maps[e.map_id]
	if not m.has("interceptors"):
		m["interceptors"] = []
	if not (m["interceptors"] as Array).has(e.id):
		m["interceptors"].append(e.id)
	Events.post(&"buff_applied", e.id, Balance.INTERCEPT_BUFF, dur)

static func _buff(e: SimEntity) -> Dictionary:
	for b in e.buffs:
		if b.get("id") == Balance.INTERCEPT_BUFF:
			return b
	return {}

## Protetor ativo agora (buff e vida acima do limite).
static func active(e: SimEntity) -> bool:
	return e.is_alive() and not _buff(e).is_empty()

## Dano que `target` leva (já depois da DEF dele): devolve o que sobra para ele; a parte redirecionada já foi aplicada no
## protetor. Chamado por WorldSim._deal_damage depois da esquiva e da cúpula do Coro (a cúpula corta primeiro).
static func damage_in(sim: WorldSim, attacker: SimEntity, target: SimEntity, amount: int) -> int:
	var m: Dictionary = sim.maps.get(target.map_id, {})
	var ids: Array = m.get("interceptors", [])
	if ids.is_empty() or amount <= 1 or not _buff(target).is_empty():
		return amount
	var best: SimEntity = null
	var best_d := INF
	var best_b: Dictionary = {}
	for id in ids.duplicate():
		var p: SimEntity = sim.entities.get(id)
		var b: Dictionary = _buff(p) if p != null and p.is_alive() and p.map_id == target.map_id else {}
		if b.is_empty():
			ids.erase(id)                            # acabou/morreu/saiu: some da lista
			continue
		if p == target or not p.is_friend(target):
			continue
		var dd := p.position.distance_to(target.position)
		if dd <= float(b["radius"]) + target.radius and dd < best_d:
			best = p
			best_d = dd
			best_b = b
	if best == null:
		return amount
	var part := int(round(float(amount) * float(best_b["pct"]) / 100.0))
	var room := int(floor(best.hp - best.stats.max_hp * float(best_b["stop_below"]) / 100.0))
	part = mini(part, maxi(0, room))                 # nunca suicida: o protetor não passa do limite por causa da Proteção
	if part <= 0:
		stop(sim, best)
		return amount
	sim._deal_damage(attacker, best, part, false, false, "intercept")
	if best.is_alive() and best.hp <= best.stats.max_hp * float(best_b["stop_below"]) / 100.0 + 1.0:      # chegou ao limite
		stop(sim, best)
	return amount - part

## Encerra a Proteção de `e` (vida baixa); o aviso aparece para o jogador.
static func stop(sim: WorldSim, e: SimEntity) -> void:
	e.drop_buff(Balance.INTERCEPT_BUFF)
	Events.post(&"buff_applied", e.id, Balance.INTERCEPT_BUFF, 0.0)
	if e == sim.player:
		Events.post(&"notification", "Proteção encerrada: vida baixa")
