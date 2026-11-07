class_name PortalSystem
extends RefCounted
## Portais, portões de progressão, troca de mapa (com invocações e grupo) e recall.

static func check_portals(sim: WorldSim, e: SimEntity, m: Dictionary) -> void:
	var def: MapDef = m["def"]
	for pt in def.portals:
		if pt.get("player_only", false) and e != sim.player:
			continue                      # porta de casa: só o jogador entra
		var pos: Vector3 = pt["pos"]
		if Vector2(e.position.x, e.position.z).distance_to(Vector2(pos.x, pos.z)) <= float(pt.get("radius", 2.0)):
			var blocked := portal_block_reason(sim, e, pt)
			if blocked == "":
				sim._pending_map_changes.append({"e": e, "map": pt["target_map"], "pos": pt["target_pos"]})
			elif e == sim.player and sim.time >= e.portal_notice_at:
				e.portal_notice_at = sim.time + Balance.PORTAL_NOTICE_CD
				Events.notification.emit(blocked)
			return

## Por que `e` não passa neste portal; "" = passa. Vale só para o jogador: bots não ficam presos em quest.
static func portal_block_reason(sim: WorldSim, e: SimEntity, pt: Dictionary) -> String:
	var g: Dictionary = pt.get("gate", {})
	if g.is_empty() or e.kind != SimEntity.Kind.PLAYER or e.gates_open.has(pt["id"]):
		return ""
	if e.level < int(g.get("level", 1)):
		return "%s: precisa de nível %d." % [pt["label"], int(g["level"])]
	var q: String = g.get("quest", "")
	if q != "" and not (q in e.quests_completed):
		return g.get("text", "%s: ainda fechado." % pt["label"])
	for boss in g.get("bosses", []):
		if not e.bosses_killed.has(boss):
			return g.get("text", "%s: ainda fechado." % pt["label"])
	e.gates_open[pt["id"]] = true
	return ""

## Save antigo não pode prender ninguém: abre os portões de história que o nível alcança e o mapa onde o
## personagem já está. Selos de chefe continuam valendo.
static func grandfather_gates(sim: WorldSim, e: SimEntity, map_id: String) -> void:
	for mid in GameData.maps:
		for pt in GameData.maps[mid].portals:
			var g: Dictionary = pt.get("gate", {})
			if g.is_empty() or g.has("bosses"):
				continue
			if e.level >= int(g.get("level", 1)) or map_within(sim, map_id, pt["target_map"]):
				e.gates_open[pt["id"]] = true

## Primeiro portal do caminho mais curto (em mapas) até `target_map`; sem caminho, o que leva à vila
## (de lá há portal pra todo lado). Usado pelos bots (seguir o líder) e pela seta da quest no minimapa.
static func portal_towards(def: MapDef, target_map: String) -> Dictionary:
	for p in def.portals:
		if p["target_map"] == target_map:
			return p
	# busca em largura pelo grafo de portais; guarda o portal de saída de cada ramo
	var seen := {def.id: true}
	var open: Array = []
	for p in def.portals:
		if not seen.has(p["target_map"]):
			seen[p["target_map"]] = true
			open.append([p["target_map"], p])
	while not open.is_empty():
		var cur: Array = open.pop_front()
		var md: MapDef = GameData.maps.get(cur[0])
		if md == null:
			continue
		for p in md.portals:
			var nxt: String = p["target_map"]
			if nxt == target_map:
				return cur[1]
			if not seen.has(nxt):
				seen[nxt] = true
				open.append([nxt, cur[1]])
	if GameData.maps.has(target_map) and GameData.maps[target_map].parent_map != "":
		return portal_towards(def, GameData.maps[target_map].parent_map)     # dungeon: vai pela zona da entrada
	for p in def.portals:
		if p["target_map"] == GameData.town_map_id():
			return p
	return def.portals[0] if def.portals.size() > 0 else {}

## Ponto de retorno (G e renascer): o cristal vinculado, ou a entrada da cidade inicial.
static func home_of(e: SimEntity) -> Dictionary:
	if e.bind_map != "" and GameData.maps.has(e.bind_map):
		return {"map": e.bind_map, "pos": e.bind_pos}
	var town := GameData.town_map_id()
	return {"map": town, "pos": GameData.maps[town].spawn_point}

## Vincula o cristal `npc` (NPC de role "crystal" do mapa atual): o retorno passa a ser na frente dele.
static func bind_crystal(sim: WorldSim, e: SimEntity, npc_id: String) -> bool:
	var npc: SimEntity = null
	for o in sim.maps[e.map_id]["entities"] if sim.maps.has(e.map_id) else []:
		if o.kind == SimEntity.Kind.NPC and o.npc_data.get("id", "") == npc_id:
			npc = o
	if npc == null or npc.npc_data.get("role", "") != "crystal":
		return false
	var def: MapDef = sim.maps[e.map_id]["def"]
	var to_center := def.town_center - npc.position
	to_center.y = 0.0
	var dir := to_center.normalized() if to_center.length() > 0.5 else Vector3(0, 0, 1)
	var pos := npc.position + dir * Balance.CRYSTAL_ARRIVE
	for i in range(8):                     # frente do cristal livre (banco, barraca): gira até achar chão
		if sim.is_walkable(pos, def, 0.5):
			break
		pos = npc.position + dir.rotated(Vector3.UP, PI * 0.25 * (i + 1)) * Balance.CRYSTAL_ARRIVE
	e.bind_map = e.map_id
	e.bind_pos = pos
	if e == sim.player:
		Events.notification.emit("Ponto de retorno: %s. O G e o renascer trazem você aqui." % npc.name)
	return true

## `map_id` é `area` ou fica dentro dela (dungeon da zona).
static func map_within(sim: WorldSim, map_id: String, area: String) -> bool:
	var cur := map_id
	while cur != "":
		if cur == area:
			return true
		var def: MapDef = GameData.maps.get(cur)
		cur = def.parent_map if def else ""
	return false

static func process_map_changes(sim: WorldSim) -> void:
	var moving := {}
	for ch in sim._pending_map_changes:
		moving[ch["e"].id] = true
	var extra: Array = []
	for ch in sim._pending_map_changes:            # o líder passou pelo portal: os bots do grupo por perto vão junto
		var e: SimEntity = ch["e"]
		if e.party_id < 0 or PartySystem.party_leader(sim, e) != e:
			continue
		var k := 0
		for o in PartySystem.party_members(sim, e):
			if o == e or moving.has(o.id) or o.kind != SimEntity.Kind.BOT or not o.is_alive() or o.map_id != e.map_id:
				continue
			if o.position.distance_to(e.position) > Balance.PARTY_PORTAL_FOLLOW:
				continue
			k += 1
			moving[o.id] = true
			var pos: Vector3 = ch["pos"]
			extra.append({"e": o, "map": ch["map"], "pos": pos + Vector3(cos(k * 2.1), 0, sin(k * 2.1)) * 1.6})
	for ch in sim._pending_map_changes + extra:
		change_map(sim, ch["e"], ch["map"], ch["pos"])
	sim._pending_map_changes.clear()

## Voltar à cidade (G): conjuração de RECALL_TIME s (vale em combate). Andar, agir (golpe, skill, dash, pulo, guarda)
## ou apertar G de novo cancela; levar dano (WorldSim._deal_damage) ou ser atordoado interrompe.
## Chega no ponto de retorno; os bots do grupo por perto vêm junto (mesma regra do portal).
static func update_recall(sim: WorldSim, e: SimEntity, cmd: InputCommand, action_cmd: InputCommand, dt: float) -> void:
	if not e.is_character():
		return
	var home := home_of(e)
	var town: String = home["map"]
	if cmd.recall:
		if e.recall_left > 0.0:
			stop_recall(sim, e, "cancel")
			return
		var why := recall_blocked(sim, e)
		if why == "" and cmd.move.length_squared() > 0.04:
			why = "Pare para voltar à cidade"
		if why != "":
			if e == sim.player:
				Events.notification.emit(why)
			return
		if e.mounted:
			sim.dismount(e)                    # conjura a pé
		e.is_blocking = false
		e.recall_left = Balance.RECALL_TIME
		Events.recall_cast.emit(e.id, "start")
		if e == sim.player:
			Events.notification.emit("Voltando para %s... (andar ou levar dano interrompe)" % GameData.maps[town].name)
		return
	if e.recall_left <= 0.0:
		return
	if not e.is_alive() or cmd.move.length_squared() > 0.04 or action_cmd.attack or action_cmd.skill_slot >= 0 \
			or action_cmd.dash or action_cmd.jump or cmd.block or cmd.mount:
		stop_recall(sim, e, "cancel")
		return
	e.recall_left -= dt
	if e.recall_left <= 0.0:
		e.recall_left = 0.0
		e.mounted = false
		Events.recall_cast.emit(e.id, "done")
		sim._pending_map_changes.append({"e": e, "map": town, "pos": home["pos"]})

## Por que G não começa agora ("" = pode). Combate não impede: o dano é que interrompe.
static func recall_blocked(sim: WorldSim, e: SimEntity) -> String:
	if not e.is_alive():
		return "Não dá agora"
	var home := home_of(e)
	var town: String = home["map"]
	if e.map_id == town and (e.position.distance_to(home["pos"]) < Balance.RECALL_NEAR or (e.bind_map == "" and sim.maps[town]["def"].in_town(e.position))):
		return "Você já está no seu ponto de retorno"
	return ""

## Fração já conjurada da volta (0..1; 0 = não está voltando). Barra de conjuração do HUD e da cabeça.
static func recall_progress(e: SimEntity) -> float:
	if e.recall_left <= 0.0:
		return 0.0
	return clampf(1.0 - e.recall_left / Balance.RECALL_TIME, 0.0, 1.0)

## Levou dano / atordoado no meio da volta.
static func interrupt_recall(sim: WorldSim, e: SimEntity) -> void:
	stop_recall(sim, e, "interrupted")

## Para a conjuração: "cancel" (andou, agiu, G de novo) ou "interrupted" (dano, atordoamento).
static func stop_recall(sim: WorldSim, e: SimEntity, why: String) -> void:
	if e.recall_left <= 0.0:
		return
	e.recall_left = 0.0
	Events.recall_cast.emit(e.id, why)
	if e == sim.player:
		Events.notification.emit("Retorno à cidade interrompido!" if why == "interrupted" else "Retorno à cidade cancelado")

static func change_map(sim: WorldSim, e: SimEntity, map_id: String, pos: Vector3) -> void:
	if e.mounted and GameData.maps.has(map_id) and GameData.maps[map_id].parent_map != "":
		sim.dismount(e)                    # dungeon: entra a pé
	if not sim.maps.has(map_id):
		var def: MapDef = GameData.maps.get(map_id)
		if def == null:
			return
		sim.load_map(def)
	if sim.maps.has(e.map_id):
		sim.maps[e.map_id]["entities"].erase(e)
		if sim.maps[e.map_id].has("chars"):
			sim.maps[e.map_id]["chars"].erase(e)
	# invocações seguem o dono
	e.map_id = map_id
	e.position = pos
	e.velocity = Vector3.ZERO
	e.aggro_target = -1
	sim.maps[map_id]["entities"].append(e)
	Events.entity_changed_map.emit(e.id, map_id)
	if e == sim.player and e.party_id >= 0:              # o grupo comenta a chegada (dungeon ou mapa novo)
		var nd: MapDef = sim.maps[map_id]["def"]
		if not nd.interior and not nd.is_town:             # voltar para casa (morte, retorno) não é novidade
			BotChat.party_event(sim, e, "enter_dungeon" if nd.parent_map != "" else "enter_map", {"map": nd.name}, null, 1.0 if nd.parent_map != "" else 0.6)
	for o in sim.entities.values():
		if o.kind == SimEntity.Kind.SUMMON and o.owner_id == e.id and o.map_id != map_id:
			sim.maps[o.map_id]["entities"].erase(o)
			o.map_id = map_id
			o.position = pos + Vector3(1, 0, 1)
			sim.maps[map_id]["entities"].append(o)
			Events.entity_changed_map.emit(o.id, map_id)
