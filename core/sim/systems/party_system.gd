class_name PartySystem
extends RefCounted
## Grupo (party): convites, entrar/sair/expulsar/promover, /party (bots chamam), quem divide o abate, reagrupar ao trocar de mapa.
## Estado no WorldSim (`parties`, `invites`, `party_seek`). Números em Balance.PARTY_*.

## Bot do grupo em outro mapa que o líder por mais de PARTY_CATCHUP_TIME (preso no caminho, renasceu na vila):
## reaparece ao lado do líder. Assim o grupo segue o jogador para dentro das dungeons e ajuda lá.
static func party_catchup(sim: WorldSim, dt: float) -> void:
	for p in sim.parties.values():
		var leader: SimEntity = sim.entities.get(p["leader"])
		if leader == null or not leader.is_alive():
			continue
		for id in p["members"]:
			var o: SimEntity = sim.entities.get(id)
			if o == null or o == leader or o.kind != SimEntity.Kind.BOT:
				continue
			if not o.is_alive() or o.map_id == leader.map_id:
				o.lost_leader_t = 0.0
				continue
			o.lost_leader_t += dt
			if o.lost_leader_t >= Balance.PARTY_CATCHUP_TIME:
				o.lost_leader_t = 0.0
				sim._pending_map_changes.append({"e": o, "map": leader.map_id, "pos": leader.position - leader.forward() * 2.0})

static func party_of(sim: WorldSim, e: SimEntity) -> Dictionary:
	return sim.parties.get(e.party_id, {}) if e else {}

## Membros do grupo de `e` (ele incluso; sem grupo = só ele), na ordem de entrada.
static func party_members(sim: WorldSim, e: SimEntity) -> Array:
	var p := party_of(sim, e)
	if p.is_empty():
		return [e]
	var out: Array = []
	for id in p["members"]:
		if sim.entities.has(id):
			out.append(sim.entities[id])
	return out

static func party_leader(sim: WorldSim, e: SimEntity) -> SimEntity:
	var p := party_of(sim, e)
	return sim.entities.get(p["leader"]) if not p.is_empty() else null

static func same_party(sim: WorldSim, a: SimEntity, b: SimEntity) -> bool:
	return a != null and b != null and a.party_id >= 0 and a.party_id == b.party_id

## Quem divide o abate com `killer`: grupo vivo, no mesmo mapa, perto e com nível próximo.
static func kill_sharers(sim: WorldSim, killer: SimEntity, mob: SimEntity) -> Array:
	var out: Array = [killer]
	if killer.party_id < 0:
		return out
	for o in party_members(sim, killer):
		if o == killer or not o.is_alive() or o.map_id != mob.map_id:
			continue
		if o.position.distance_to(mob.position) > Balance.PARTY_SHARE_RANGE:
			continue
		if absi(o.level - killer.level) > Balance.PARTY_LEVEL_GAP:
			continue
		out.append(o)
	return out

## Por que `from` não pode convidar `to`; "" = pode.
static func party_invite_error(sim: WorldSim, from: SimEntity, to: SimEntity) -> String:
	if from == null or to == null or from == to or not to.is_character() or not sim.entities.has(to.id):
		return "Alvo inválido."
	if to.party_id >= 0:
		return "%s já está em um grupo." % to.name
	if sim.invites.has(to.id):
		return "%s já tem um convite pendente." % to.name
	if to.brain and absi(to.level - from.level) > Balance.PARTY_LEVEL_GAP:
		return "%s não entra em grupo com nível tão diferente (máx. %d)." % [to.name, Balance.PARTY_LEVEL_GAP]
	var p := party_of(sim, from)
	if not p.is_empty():
		if p["leader"] != from.id:
			return "Só o líder pode convidar."
		if p["members"].size() >= Balance.PARTY_MAX:
			return "O grupo está cheio (%d)." % Balance.PARTY_MAX
	return ""

static func party_invite(sim: WorldSim, from: SimEntity, to: SimEntity) -> bool:
	var err := party_invite_error(sim, from, to)
	if err != "":
		if from == sim.player:
			Events.notification.emit(err)
		return false
	sim.invites[to.id] = {"from": from.id, "expires": sim.time + Balance.PARTY_INVITE_TIME, "decide_at": sim.time + sim.rng.randf_range(1.0, 3.0)}
	Events.party_invited.emit(from.id, to.id)
	if from == sim.player:
		Events.notification.emit("Convite enviado para %s." % to.name)
	return true

static func party_accept(sim: WorldSim, e: SimEntity) -> bool:
	var inv: Dictionary = sim.invites.get(e.id, {})
	sim.invites.erase(e.id)
	if inv.is_empty() or e.party_id >= 0:
		return false
	var from: SimEntity = sim.entities.get(inv["from"])
	if from == null:
		return false
	var p := party_of(sim, from)
	if p.is_empty():
		p = {"id": sim._next_party_id, "leader": from.id, "members": [from.id]}
		sim._next_party_id += 1
		sim.parties[p["id"]] = p
		set_party(sim, from, p["id"])
	if p["members"].size() >= Balance.PARTY_MAX:
		return false
	p["members"].append(e.id)
	set_party(sim, e, p["id"])
	party_say(sim, p, "%s entrou no grupo." % e.name)
	var lead: SimEntity = sim.entities.get(p["leader"])
	if e.kind == SimEntity.Kind.PLAYER and lead and lead.kind == SimEntity.Kind.BOT:
		p["leader"] = e.id                       # grupo com o jogador: os bots seguem e ajudam o jogador
		party_say(sim, p, "%s agora lidera o grupo." % e.name)
	Events.party_changed.emit(p["id"])
	return true

static func party_decline(sim: WorldSim, e: SimEntity) -> void:
	var inv: Dictionary = sim.invites.get(e.id, {})
	sim.invites.erase(e.id)
	if not inv.is_empty() and sim.player and inv["from"] == sim.player.id:
		Events.notification.emit("%s recusou o convite." % e.name)

static func party_leave(sim: WorldSim, e: SimEntity) -> void:
	var p := party_of(sim, e)
	if p.is_empty():
		return
	party_say(sim, p, "%s saiu do grupo." % e.name)
	p["members"].erase(e.id)
	set_party(sim, e, -1)
	if e == sim.player:
		Events.notification.emit("Você saiu do grupo.")
	if p["members"].size() < 2:
		if sim.player and p["members"].has(sim.player.id):
			Events.notification.emit("O grupo foi desfeito.")
		for id in p["members"]:
			if sim.entities.has(id):
				set_party(sim, sim.entities[id], -1)
		sim.parties.erase(p["id"])
	elif p["leader"] == e.id:
		p["leader"] = p["members"][0]
		party_say(sim, p, "%s agora é o líder." % sim.entities[p["leader"]].name)
	Events.party_changed.emit(p["id"])

static func party_kick(sim: WorldSim, leader: SimEntity, target: SimEntity) -> bool:
	if not same_party(sim, leader, target) or leader == target or party_of(sim, leader)["leader"] != leader.id:
		return false
	if target == sim.player:
		Events.notification.emit("Você foi removido do grupo.")
	party_leave(sim, target)
	return true

static func party_promote(sim: WorldSim, leader: SimEntity, target: SimEntity) -> bool:
	if not same_party(sim, leader, target) or leader == target or party_of(sim, leader)["leader"] != leader.id:
		return false
	var p := party_of(sim, leader)
	p["leader"] = target.id
	party_say(sim, p, "%s agora é o líder." % target.name)
	Events.party_changed.emit(p["id"])
	return true

static func set_party(sim: WorldSim, e: SimEntity, party_id: int) -> void:
	e.party_id = party_id
	for o in sim.entities.values():
		if o.kind == SimEntity.Kind.SUMMON and o.owner_id == e.id:
			o.party_id = party_id

## Mensagem de sistema no canal do grupo (só aparece se o jogador está nele).
static func party_say(sim: WorldSim, p: Dictionary, text: String) -> void:
	if sim.player and p["members"].has(sim.player.id):
		Events.chat_message.emit("Grupo", text, "party")

## /party: bots do mesmo mapa, sozinhos ou líderes com vaga e de nível próximo, se oferecem (fala no chat) e
## convidam um por vez: recusou ou deixou passar → o próximo; entrou num grupo → acaba. Devolve quantos se ofereceram.
const SEEK_LINES := ["Bora, %s! Te chamo pro grupo.", "Opa, %s, cola com a gente!", "Tô indo caçar, %s, vem junto?", "Chamando, %s!"]

static func party_seek_start(sim: WorldSim, e: SimEntity) -> int:
	if e == null or e.party_id >= 0:
		return -1
	var cd: Dictionary = sim.party_seek.get(e.id, {})
	if not cd.is_empty() and sim.time < float(cd.get("until", 0.0)):
		return -2
	var cands: Array = []
	for o in sim.maps[e.map_id]["entities"]:
		if o.kind != SimEntity.Kind.BOT or not o.is_alive() or sim.invites.has(o.id):
			continue
		if absi(o.level - e.level) > Balance.PARTY_LEVEL_GAP:
			continue
		var p := party_of(sim, o)
		if not p.is_empty() and (p["leader"] != o.id or p["members"].size() >= Balance.PARTY_MAX):
			continue
		cands.append(o)
	cands.sort_custom(func(a, b): return absi(a.level - e.level) * 30.0 + a.position.distance_to(e.position) < absi(b.level - e.level) * 30.0 + b.position.distance_to(e.position))
	cands = cands.slice(0, Balance.PARTY_SEEK_MAX)
	var q: Array = []
	for i in range(cands.size()):
		q.append(cands[i].id)
		Events.chat_message.emit(cands[i].name, SEEK_LINES[(i + e.id) % SEEK_LINES.size()] % e.name, "say")
	sim.party_seek[e.id] = {"queue": q, "next_at": sim.time + 1.0, "until": sim.time + Balance.PARTY_SEEK_COOLDOWN}
	return q.size()

static func update_party_seek(sim: WorldSim) -> void:
	for id in sim.party_seek.keys():
		var s: Dictionary = sim.party_seek[id]
		var e: SimEntity = sim.entities.get(id)
		if e == null or e.party_id >= 0:
			s["queue"] = []                   # entrou num grupo: os outros desistem (o tempo de espera continua)
		if (s["queue"] as Array).is_empty() or sim.invites.has(id) or sim.time < float(s["next_at"]):
			continue
		var bot: SimEntity = sim.entities.get(int(s["queue"].pop_front()))
		if bot and bot.is_alive() and bot.map_id == e.map_id and party_invite_error(sim, bot, e) == "":
			party_invite(sim, bot, e)
		s["next_at"] = sim.time + 0.8

## Convites: expiram; bots decidem depois de 1-3 s (o jogador decide pela UI).
static func update_invites(sim: WorldSim) -> void:
	update_party_seek(sim)
	for to_id in sim.invites.keys():
		var inv: Dictionary = sim.invites[to_id]
		var to: SimEntity = sim.entities.get(to_id)
		if to == null or sim.time >= inv["expires"]:
			sim.invites.erase(to_id)
			continue
		if to.kind == SimEntity.Kind.BOT and sim.time >= inv["decide_at"]:
			var from: SimEntity = sim.entities.get(inv["from"])
			if from and to.brain and to.brain.wants_party(to, from, sim):
				party_accept(sim, to)
			else:
				party_decline(sim, to)
