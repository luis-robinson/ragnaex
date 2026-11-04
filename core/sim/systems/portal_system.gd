class_name PortalSystem
extends RefCounted
## Portais, portões de progressão, troca de mapa (com invocações e grupo) e recall.

static func _check_portals(sim: WorldSim, e: SimEntity, m: Dictionary) -> void:
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
			if e.level >= int(g.get("level", 1)) or _map_within(sim, map_id, pt["target_map"]):
				e.gates_open[pt["id"]] = true

## `map_id` é `area` ou fica dentro dela (dungeon da zona).
static func _map_within(sim: WorldSim, map_id: String, area: String) -> bool:
	var cur := map_id
	while cur != "":
		if cur == area:
			return true
		var def: MapDef = GameData.maps.get(cur)
		cur = def.parent_map if def else ""
	return false

static func _process_map_changes(sim: WorldSim) -> void:
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
		_change_map(sim, ch["e"], ch["map"], ch["pos"])
	sim._pending_map_changes.clear()

## Voltar à cidade (G): RECALL_TIME s parado e fora de combate; andar, agir, levar dano ou apertar G de novo cancela.
## Chega no ponto de entrada da vila; os bots do grupo por perto vêm junto (mesma regra do portal).
static func _update_recall(sim: WorldSim, e: SimEntity, cmd: InputCommand, action_cmd: InputCommand, dt: float) -> void:
	if not e.is_character():
		return
	var town := GameData.town_map_id()
	if cmd.recall:
		if e.recall_left > 0.0:
			e.recall_left = 0.0
			if e == sim.player:
				Events.notification.emit("Retorno à cidade cancelado")
			return
		var why := ""
		if not e.is_alive():
			why = "Não dá agora"
		elif e.combat_timer > 0.0:
			why = "Não dá para voltar à cidade em combate"
		elif e.map_id == town and sim.maps[town]["def"].in_town(e.position):
			why = "Você já está na cidade"
		if why != "":
			if e == sim.player:
				Events.notification.emit(why)
			return
		e.recall_left = Balance.RECALL_TIME
		if e == sim.player:
			Events.notification.emit("Voltando para %s... fique parado" % GameData.maps[town].name)
		return
	if e.recall_left <= 0.0:
		return
	if not e.is_alive() or e.combat_timer > 0.0 or cmd.move.length_squared() > 0.04 or action_cmd.attack or action_cmd.skill_slot >= 0 \
			or action_cmd.dash or action_cmd.jump or cmd.block:
		e.recall_left = 0.0
		if e == sim.player:
			Events.notification.emit("Retorno à cidade cancelado")
		return
	e.recall_left -= dt
	if e.recall_left <= 0.0:
		e.recall_left = 0.0
		e.mounted = false
		sim._pending_map_changes.append({"e": e, "map": town, "pos": GameData.maps[town].spawn_point})

static func _change_map(sim: WorldSim, e: SimEntity, map_id: String, pos: Vector3) -> void:
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
	for o in sim.entities.values():
		if o.kind == SimEntity.Kind.SUMMON and o.owner_id == e.id and o.map_id != map_id:
			sim.maps[o.map_id]["entities"].erase(o)
			o.map_id = map_id
			o.position = pos + Vector3(1, 0, 1)
			sim.maps[map_id]["entities"].append(o)
			Events.entity_changed_map.emit(o.id, map_id)
