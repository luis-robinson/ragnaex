class_name BotLeaderSystem
extends RefCounted
## Bot líder do grupo do jogador (o jogador passou a liderança: janela P "Líder" ou /lider <nome>).
## 1) Completa o grupo até PARTY_MAX: bots livres do mesmo mapa (à toa na vila ou caçando sozinhos), na faixa
##    (BOT_LEADER_LEVEL_GAP), papel que falta primeiro (tanque, cura, depois dano; papel = ProgressionSystem.role_of),
##    um convite por vez (BOT_LEADER_INVITE_CD) pelo mesmo `party_invite` do jogador; o convidado decide como sempre
##    (`BotBrain.wants_party`). Na vila segura a saída até encher ou BOT_LEADER_FILL_MAX_S; sem ninguém perto vai ao
##    ponto de encontro do povoado. Nos primeiros BOT_LEADER_ROLE_PATIENCE s só chama quem tem o papel que falta.
## 2) Conta o plano no canal do grupo a cada decisão real do BotBrain (sair para caçar, chegar, voltar, chefe à vista,
##    esperar o jogador): no máximo uma fala a cada BOT_LEADER_SAY_GAP s, a mesma de BOT_LEADER_SAY_REPEAT em
##    BOT_LEADER_SAY_REPEAT s; a que não coube espera a vez (só a mais nova) e some depois de BOT_LEADER_SAY_STALE s.
## 3) Fora da vila espera o jogador que ficou para trás no mesmo mapa (até BOT_LEADER_WAIT_MAX_S, depois vai na frente).
## Estado no `BotBrain.lead` (dicionário; vazio quando não lidera). Grupo liderado pelo jogador ou só de bots: nada muda.
## Falas em `BotsCatalog.LEADER_LINES`.

const S := BotBrain.S
const ROLE_WORDS := {"tank": "um tanque", "healer": "um curandeiro", "dps": "mais dano"}

## `e` lidera um grupo em que está o jogador?
static func active(sim, e: SimEntity) -> bool:
	return e != null and e.kind == SimEntity.Kind.BOT and e.party_id >= 0 and sim.player != null \
		and sim.player.party_id == e.party_id and sim.party_leader(e) == e

## Papel de grupo: tanque, cura ou dano (dps, caster e ranged contam como dano).
static func group_role(role: String) -> String:
	return role if role in ["tank", "healer"] else "dps"

static func _role(sim, o: SimEntity) -> String:
	return group_role(o.brain._role(o, sim) if o.brain is BotBrain else sim.role_of(o))

## Papéis que faltam no grupo de `e`, em ordem de prioridade (tanque, cura, dano). Vazio = grupo cheio.
static func missing_roles(sim, e: SimEntity) -> Array:
	var members: Array = sim.party_members(e)
	var free: int = Balance.PARTY_MAX - members.size()
	if free <= 0:
		return []
	var have := {"tank": 0, "healer": 0, "dps": 0}
	for o: SimEntity in members:
		have[_role(sim, o)] += 1
	var out: Array = []
	for r in ["tank", "healer"]:
		if have[r] == 0 and out.size() < free:
			out.append(r)
	if out.size() < free:
		out.append("dps")
	return out

## "um tanque e um curandeiro"
static func role_words(roles: Array) -> String:
	var words: Array = roles.map(func(r): return ROLE_WORDS[r])
	if words.size() <= 1:
		return "" if words.is_empty() else str(words[0])
	return ", ".join(words.slice(0, words.size() - 1)) + " e " + str(words.back())

## Bots que dá para chamar agora: mesmo mapa, até `range` m, vivos, sem grupo, sem convite pendente, na faixa, à toa ou
## caçando sozinhos, e que não recusaram há pouco.
static func recruits(sim, e: SimEntity, range: float) -> Array:
	var out: Array = []
	if not sim.maps.has(e.map_id):
		return out
	var no: Dictionary = (e.brain as BotBrain).lead.get("no", {})
	for o: SimEntity in sim.maps[e.map_id]["entities"]:
		if o == e or o.kind != SimEntity.Kind.BOT or o.party_id >= 0 or not o.is_alive():
			continue
		if o.position.distance_to(e.position) > range or absi(o.level - e.level) > Balance.BOT_LEADER_LEVEL_GAP:
			continue
		if sim.invites.has(o.id) or sim.time < float(no.get(o.id, -1.0)):
			continue
		if not (o.brain is BotBrain) or not (o.brain.state in [S.TOWN_IDLE, S.TOWN_WALK, S.HUNT]):
			continue
		out.append(o)
	return out

## Melhor bot para chamar (null = ninguém). Nota = distância + nível de diferença × BOT_LEADER_LEVEL_WEIGHT, menos
## BOT_LEADER_ROLE_BONUS se tem um papel que falta (× 2 o primeiro). `strict` = só quem tem papel que falta.
static func pick_recruit(sim, e: SimEntity, range: float, strict: bool) -> SimEntity:
	var miss := missing_roles(sim, e)
	if miss.is_empty():
		return null
	var best: SimEntity = null
	var best_s := INF
	for o: SimEntity in recruits(sim, e, range):
		var r := _role(sim, o)
		if strict and not miss.has(r):
			continue
		var s: float = o.position.distance_to(e.position) + absi(o.level - e.level) * Balance.BOT_LEADER_LEVEL_WEIGHT
		if r == miss[0]:
			s -= Balance.BOT_LEADER_ROLE_BONUS * 2.0
		elif miss.has(r):
			s -= Balance.BOT_LEADER_ROLE_BONUS
		if s < best_s:
			best_s = s
			best = o
	return best

## Plano atual do líder de `e` (última fala; "" = líder não é bot ou não disse nada). Janela P.
static func plan_of(sim, e: SimEntity) -> String:
	var lead: SimEntity = sim.party_leader(e) if e else null
	if lead == null or not (lead.brain is BotBrain):
		return ""
	return str(lead.brain.lead.get("plan", ""))

# ---------------------------------------------------------------------------

## Um pensamento do líder (BotBrain._think, depois do combate reativo e antes da rotina). Devolve um comando quando o
## líder segura a rotina (recrutando na vila, esperando o jogador); null = segue a rotina do BotBrain.
static func lead(b: BotBrain, e: SimEntity, sim, m: Dictionary, cmd: InputCommand, dt: float) -> InputCommand:
	if not active(sim, e):
		if not b.lead.is_empty():
			b.lead = {}
		return null
	var L: Dictionary = b.lead
	if int(L.get("pid", -1)) != e.party_id:
		L.clear()
		L["pid"] = e.party_id
		L["state"] = b.state
		L["dest"] = b.dest_map
		L["fill"] = -1.0
		L["new"] = true
	_flush(sim, e, L)
	var town: bool = b.state == S.TOWN_IDLE or b.state == S.TOWN_WALK
	var full: bool = sim.party_members(e).size() >= Balance.PARTY_MAX
	if L.get("new", false):
		L.erase("new")
		if full:
			say(sim, e, L, "lead_full")
		else:
			say(sim, e, L, "fill", {"role": role_words(missing_roles(sim, e))})
	_watch(b, e, sim, L, full)
	if not full:
		_invite_step(e, sim, L, town)
	if not town:
		L["fill"] = -1.0
		L["gave_up"] = false
		return _wait_player(b, e, sim, cmd, dt, L)
	# na vila: segura a saída até encher (ou desistir)
	var t0: float = L.get("fill", -1.0)
	if full:
		if t0 >= 0.0:
			L["fill"] = -1.0
			b._plan_trip(e, sim)                  # encheu: sai já (a fala da viagem sai no próximo _watch)
		return null
	if L.get("gave_up", false):
		return null
	if t0 < 0.0:
		L["fill"] = sim.time
		t0 = sim.time
		say(sim, e, L, "fill", {"role": role_words(missing_roles(sim, e))})
	if sim.time - t0 >= Balance.BOT_LEADER_FILL_MAX_S:
		L["gave_up"] = true
		L["fill"] = -1.0
		b._plan_trip(e, sim)
		say(sim, e, L, "go_partial", _trip_vars(b, e), "trip")
		L["state"] = b.state
		L["dest"] = b.dest_map
		return null
	return _recruit_walk(b, e, sim, m, cmd, dt, L)

## Convites: espera a resposta do anterior; depois de BOT_LEADER_INVITE_CD chama o próximo (recusou = fora por
## BOT_LEADER_DECLINE_MEMORY s).
static func _invite_step(e: SimEntity, sim, L: Dictionary, town: bool) -> void:
	var pend: int = L.get("pend", -1)
	if pend >= 0:
		var inv: Dictionary = sim.invites.get(pend, {})
		if not inv.is_empty() and int(inv["from"]) == e.id:
			return
		L["pend"] = -1
		var o: SimEntity = sim.entities.get(pend)
		if o and o.party_id != e.party_id:
			(L.get_or_add("no", {}) as Dictionary)[pend] = sim.time + Balance.BOT_LEADER_DECLINE_MEMORY
	if sim.time < float(L.get("next_inv", 0.0)):
		return
	var t0: float = L.get("fill", -1.0)
	var strict: bool = town and t0 >= 0.0 and sim.time - t0 < Balance.BOT_LEADER_ROLE_PATIENCE
	var o := pick_recruit(sim, e, Balance.BOT_LEADER_RECRUIT_RANGE, strict)
	if o == null:
		L["next_inv"] = sim.time + Balance.BOT_LEADER_SCAN
		return
	L["next_inv"] = sim.time + Balance.BOT_LEADER_INVITE_CD
	if sim.party_invite(e, o):
		L["pend"] = o.id
		var cls: String = o.class_def.name if o.class_def else "?"
		say(sim, e, L, "invite", {"name": o.name, "cls": cls, "role": ROLE_WORDS[_role(sim, o)]}, "invite:%d" % o.id)

## Recrutando na vila: com alguém para chamar fica parado olhando para ele; sem ninguém perto vai ao ponto de encontro.
static func _recruit_walk(b: BotBrain, e: SimEntity, sim, m: Dictionary, cmd: InputCommand, dt: float, L: Dictionary) -> InputCommand:
	var pend: SimEntity = sim.entities.get(int(L.get("pend", -1)))
	if pend:
		cmd.aim = pend.position
		return cmd
	if not recruits(sim, e, Balance.BOT_LEADER_RECRUIT_RANGE).is_empty():
		return cmd
	var def: MapDef = m["def"]
	if not L.has("spot"):
		L["spot"] = b._pick_hangout(e, m, def) if def.bot_hangouts.size() > 0 else def.town_center
		var md: MapDef = GameData.maps.get(e.map_id)
		say(sim, e, L, "recruit_walk", {"role": role_words(missing_roles(sim, e)), "map": md.name if md else "aqui"})
	var spot: Vector3 = L["spot"]
	if e.position.distance_to(spot) > 2.0:
		cmd.move = b._steer(e, spot, dt) * 0.8
		cmd.aim = spot
	return cmd

## Fora da vila: jogador vivo no mesmo mapa a mais de BOT_LEADER_WAIT_DIST m = espera (parado, relógios da rotina
## parados) até ele chegar a BOT_LEADER_WAIT_RESUME m; depois de BOT_LEADER_WAIT_MAX_S esperando segue sem ele.
static func _wait_player(b: BotBrain, e: SimEntity, sim, cmd: InputCommand, dt: float, L: Dictionary) -> InputCommand:
	var pl: SimEntity = sim.player
	if pl == null or not pl.is_alive() or pl.map_id != e.map_id:
		L["waiting"] = false
		return null
	var d: float = pl.position.distance_to(e.position)
	if d <= Balance.BOT_LEADER_WAIT_RESUME:
		L["waiting"] = false
		L["wait_t"] = 0.0
		return null
	var waiting: bool = L.get("waiting", false)
	if not waiting and d > Balance.BOT_LEADER_WAIT_DIST and float(L.get("wait_t", 0.0)) < Balance.BOT_LEADER_WAIT_MAX_S:
		L["waiting"] = true
		waiting = true
		say(sim, e, L, "wait")
	if not waiting:
		return null
	L["wait_t"] = float(L.get("wait_t", 0.0)) + dt
	if float(L["wait_t"]) >= Balance.BOT_LEADER_WAIT_MAX_S:
		L["waiting"] = false
		say(sim, e, L, "wait_over")
		return null
	b.timer += dt                                  # a viagem/caçada não vence enquanto espera
	cmd.aim = pl.position
	return cmd

## Decisões do BotBrain que viram fala: saiu para caçar (com o grupo cheio ou não), chegou, voltou à cidade, chefe à vista.
static func _watch(b: BotBrain, e: SimEntity, sim, L: Dictionary, full: bool) -> void:
	var st: int = b.state
	var prev: int = L.get("state", st)
	if st != prev or (st == S.TRAVEL and b.dest_map != str(L.get("dest", ""))):
		if st == S.TRAVEL:
			say(sim, e, L, "trip_full" if full else "trip", _trip_vars(b, e), "trip")
		elif st == S.RETURN:
			var why := "return"
			if e.hp < e.stats.max_hp * 0.3:
				why = "return_hurt"
			elif e.inventory_weight() > 60:
				why = "return_bag"
			say(sim, e, L, why, {}, "return")
		elif st == S.HUNT and prev == S.TRAVEL:
			say(sim, e, L, "hunt", _trip_vars(b, e))
	L["state"] = st
	L["dest"] = b.dest_map
	if (st == S.HUNT or st == S.TRAVEL) and sim.time >= float(L.get("scan", 0.0)):
		L["scan"] = sim.time + Balance.BOT_LEADER_SCAN
		var boss := BotChat.near_boss(sim, e)
		if boss and boss.id != int(L.get("boss", -1)):
			L["boss"] = boss.id
			say(sim, e, L, "boss", {"boss": boss.monster_def.name}, "boss:%d" % boss.id)

## Marcas da viagem: {em} "no Vale de Aldara", {mob} = monstro do mapa de destino com o nível mais perto do líder.
static func _trip_vars(b: BotBrain, e: SimEntity) -> Dictionary:
	var md: MapDef = GameData.maps.get(b.dest_map)
	if md == null:
		md = GameData.maps.get(e.map_id)
	var v := {"em": "por aqui", "mob": "monstros", "dest": "aqui"}
	if md == null:
		return v
	v["em"] = BotsCatalog.place_words(md.name)["em"]
	v["dest"] = md.name
	var best := 1 << 30
	for sp in md.spawners:
		var mdef: MonsterDef = GameData.monsters.get(str(sp.get("monster_id", "")))
		if mdef == null or mdef.is_boss or mdef.xp <= 0:
			continue
		var gap := absi(mdef.level - e.level)
		if gap < best:
			best = gap
			v["mob"] = mdef.name
	return v

# ---------------------------------------------------------------------------
# FALA DO PLANO (canal do grupo)

## Diz uma fala do tipo `kind` (BotsCatalog.LEADER_LINES). `key` = o que não se repete antes de BOT_LEADER_SAY_REPEAT
## (padrão: o próprio tipo). Devolve se a fala foi aceita (dita agora ou guardada para a próxima vez).
static func say(sim, e: SimEntity, L: Dictionary, kind: String, vars: Dictionary = {}, key: String = "") -> bool:
	if key == "":
		key = kind
	var said: Dictionary = L.get_or_add("said", {})
	if sim.time < float(said.get(key, -1.0e9)):
		return false
	var lines: Array = BotsCatalog.LEADER_LINES.get(kind, [])
	var text := BotChat.pick(sim, e, lines, BotChat.vars_for(sim, e, vars))
	if text == "":
		return false
	said[key] = sim.time + Balance.BOT_LEADER_SAY_REPEAT
	L["plan"] = text
	var held: Array = L.get_or_add("held", [])
	if held.is_empty() and sim.time >= float(L.get("say_next", 0.0)):
		_emit(sim, e, L, text)
	else:
		held.append({"text": text, "at": sim.time})     # espera a vez; cheia, a mais velha sai
		while held.size() > Balance.BOT_LEADER_SAY_QUEUE:
			held.pop_front()
	return true

static func _flush(sim, e: SimEntity, L: Dictionary) -> void:
	var held: Array = L.get("held", [])
	while not held.is_empty() and sim.time >= float(L.get("say_next", 0.0)):
		var h: Dictionary = held.pop_front()
		if sim.time - float(h["at"]) <= Balance.BOT_LEADER_SAY_STALE:
			_emit(sim, e, L, str(h["text"]))

static func _emit(sim, e: SimEntity, L: Dictionary, text: String) -> void:
	L["say_next"] = sim.time + Balance.BOT_LEADER_SAY_GAP
	Events.post(&"chat_message", e.name, text, "party")
