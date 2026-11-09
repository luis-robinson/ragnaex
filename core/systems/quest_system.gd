class_name QuestSystem
extends RefCounted
## Quests data-driven. Progresso vive na entidade (quests_active / quests_completed).

const LOCKED := "locked"
const REPEAT := "↻"           # NPC com quest repetível disponível
const REACH_RANGE := 12.0    # m de um lugar para contar como chegada

static func available_from_npc(e: SimEntity, npc_id: String) -> Array:
	var out: Array = []
	for qid in GameData.quests:
		var q: QuestDef = GameData.quests[qid]
		if q.giver_npc != npc_id:
			continue
		if can_accept(e, q):
			out.append(q)
	return out

static func can_accept(e: SimEntity, q: QuestDef) -> bool:
	if e.quests_active.has(q.id) or (q.id in e.quests_completed and not q.repeatable):
		return false
	if e.level < q.level_req:
		return false
	if q.prereq_quest != "" and not (q.prereq_quest in e.quests_completed):
		return false
	for pid in q.prereq_all:
		if not (pid in e.quests_completed):
			return false
	return true

static func accept(e: SimEntity, q: QuestDef) -> void:
	if not can_accept(e, q):
		return
	e.quests_active[q.id] = 0
	for iid in q.give_items:                 # entrega: o pacote vai para a bolsa
		e.add_item(iid, int(q.give_items[iid]))
	Events.post(&"quest_accepted", e.id, q.id)
	# COLLECT: conta o que já tem; TALK ao próprio NPC completa na hora
	if q.type == QuestDef.Type.COLLECT:
		on_item_changed(e, q.target_id)
	on_position(e)

## Desiste: o progresso se perde e a quest volta a ser oferecida.
static func abandon(e: SimEntity, q: QuestDef) -> void:
	if e.quests_active.erase(q.id):
		for iid in q.give_items:
			e.remove_item(iid, mini(int(q.give_items[iid]), int(e.inventory.get(iid, 0))))
		Events.post(&"quest_abandoned", e.id, q.id)

static func progress(e: SimEntity, q: QuestDef) -> int:
	if q.type == QuestDef.Type.COLLECT:
		return mini(int(e.inventory.get(q.target_id, 0)), q.count)
	return int(e.quests_active.get(q.id, 0))

static func is_complete(e: SimEntity, q: QuestDef) -> bool:
	return e.quests_active.has(q.id) and progress(e, q) >= q.count

static func on_kill(e: SimEntity, monster_id: String) -> void:
	for qid in e.quests_active.keys():
		var q: QuestDef = GameData.quests.get(qid)
		if q and q.type == QuestDef.Type.KILL and (q.target_id == monster_id or monster_id in q.also_counts):
			var cur := mini(int(e.quests_active[qid]) + 1, q.count)
			e.quests_active[qid] = cur
			Events.post(&"quest_progress", e.id, qid, cur, q.count)

static func on_item_changed(e: SimEntity, item_id: String) -> void:
	for qid in e.quests_active.keys():
		var q: QuestDef = GameData.quests.get(qid)
		if q and q.type == QuestDef.Type.COLLECT and q.target_id == item_id:
			Events.post(&"quest_progress", e.id, qid, progress(e, q), q.count)

static func on_craft(e: SimEntity, item_id: String, count: int) -> void:
	for qid in e.quests_active.keys():
		var q: QuestDef = GameData.quests.get(qid)
		if q and q.type == QuestDef.Type.CRAFT and q.target_id == item_id:
			var cur := mini(int(e.quests_active[qid]) + count, q.count)
			e.quests_active[qid] = cur
			Events.post(&"quest_progress", e.id, qid, cur, q.count)

static func on_talk(e: SimEntity, npc_id: String) -> void:
	for qid in e.quests_active.keys():
		var q: QuestDef = GameData.quests.get(qid)
		if q and q.type == QuestDef.Type.TALK and q.target_id == npc_id:
			e.quests_active[qid] = q.count
			Events.post(&"quest_progress", e.id, qid, q.count, q.count)

## REACH: chegou ao mapa alvo, ou perto do lugar alvo no mapa atual.
static func on_position(e: SimEntity) -> void:
	for qid in e.quests_active.keys():
		var q: QuestDef = GameData.quests.get(qid)
		if q and q.type == QuestDef.Type.REACH and not is_complete(e, q) and _arrived(e, q.target_id):
			e.quests_active[qid] = q.count
			Events.post(&"quest_progress", e.id, qid, q.count, q.count)

static func _arrived(e: SimEntity, target: String) -> bool:
	if e.map_id == target:
		return true
	var def: MapDef = GameData.maps.get(e.map_id)
	if def:
		for pl in def.places:
			if pl["id"] == target and e.position.distance_to(pl["pos"]) <= REACH_RANGE:
				return true
	return false

## Quests ativas que podem ser entregues neste NPC
static func turnins_at(e: SimEntity, npc_id: String) -> Array:
	var out: Array = []
	for qid in e.quests_active.keys():
		var q: QuestDef = GameData.quests.get(qid)
		if q and q.turnin() == npc_id and is_complete(e, q):
			out.append(q)
	return out

## Marcador do NPC (cabeça e minimapa): "?" = entregar/conversar aqui, "!" = quest nova,
## LOCKED = tem quest que ainda não libera (nível ou quest anterior), "" = nada.
## Entregar vem primeiro: é o que o jogador veio fazer.
static func npc_marker(e: SimEntity, npc_id: String) -> String:
	if not turnins_at(e, npc_id).is_empty():
		return "?"
	for qid in e.quests_active.keys():
		var q: QuestDef = GameData.quests.get(qid)
		if q and q.type == QuestDef.Type.TALK and q.target_id == npc_id and not is_complete(e, q):
			return "?"
	var avail: Array = available_from_npc(e, npc_id)
	if avail.any(func(q): return not q.repeatable):
		return "!"
	if not avail.is_empty():
		return REPEAT               # só repetíveis: marcador próprio (azul), diferente do "!" de história
	for qid in GameData.quests:
		var q: QuestDef = GameData.quests[qid]
		if q.giver_npc == npc_id and not q.repeatable and not e.quests_active.has(qid) and not (qid in e.quests_completed):
			return LOCKED
	return ""

## Onde cumprir o próximo passo da quest: {"map", "pos"} ({} = não sabe). Pronta → NPC de entrega;
## senão o alvo pelo tipo (spawner, colheita, quem dropa, NPC, lugar, bancada). Mapa atual tem preferência.
static func objective(e: SimEntity, q: QuestDef) -> Dictionary:
	if is_complete(e, q):
		return _npc_spot(e, q.turnin())
	match q.type:
		QuestDef.Type.KILL:
			var ids: Array = [q.target_id] + Array(q.also_counts)
			var spot := _find(e, func(def: MapDef): return _spawner_of(def, ids))           # onde o monstro vive (um front, um ninho)
			if spot.is_empty():
				spot = _find(e, func(def: MapDef): return _raid_of(def, q.target_id))   # só vem nas investidas: o povoado atacado
			return spot
		QuestDef.Type.COLLECT:
			var spot := _find(e, func(def: MapDef): return _gather_of(def, q.target_id))
			if spot.is_empty():
				spot = _find(e, func(def: MapDef): return _spawner_of(def, _droppers(q.target_id)))
			return spot if not spot.is_empty() else _npc_spot(e, q.turnin())   # entrega: o pacote já está na bolsa
		QuestDef.Type.TALK:
			return _npc_spot(e, q.target_id)
		QuestDef.Type.REACH:
			if GameData.maps.has(q.target_id):
				return {"map": q.target_id, "pos": GameData.maps[q.target_id].spawn_point}
			return _find(e, func(def: MapDef): return _place_of(def, q.target_id))
		QuestDef.Type.CRAFT:
			for rid in GameData.recipes:
				var r: RecipeDef = GameData.recipes[rid]
				if r.result_item == q.target_id:
					return _find(e, func(def: MapDef): return _role_of(def, r.station))
	return {}

## Ponto para onde a seta aponta no mapa atual: o objetivo, ou o portal que leva até ele.
static func guide_point(e: SimEntity, q: QuestDef) -> Dictionary:
	var obj := objective(e, q)
	if obj.is_empty():
		return {}
	var def: MapDef = GameData.maps.get(e.map_id)
	if def == null:
		return {}
	var dest: Vector3 = obj["pos"]
	var via := false
	if obj["map"] != e.map_id:
		var pt := PortalSystem.portal_towards(def, obj["map"])
		if pt.is_empty():
			return {}
		dest = pt["pos"]
		via = true
	var gate := _gate_between(def, e.position, dest)
	if gate != Vector3.INF:
		return {"pos": gate, "via_portal": via, "via_gate": true}
	return {"pos": dest, "via_portal": via}

## Muralha entre o jogador e o destino (um dentro, o outro fora do povoado): o portão que melhor leva até lá.
static func _gate_between(def: MapDef, from: Vector3, to: Vector3) -> Vector3:
	if def.town_gates.is_empty() or def.town_radius <= 0.0:
		return Vector3.INF
	var c := def.town_center
	var r := def.town_radius
	var a_in := Vector2(from.x - c.x, from.z - c.z).length() < r - 1.0
	var b_in := Vector2(to.x - c.x, to.z - c.z).length() < r - 1.0
	if a_in == b_in:
		return Vector3.INF
	var best := Vector3.INF
	var bd := INF
	for g in def.town_gates:
		var gp: Vector3 = g
		if Vector2(gp.x - from.x, gp.z - from.z).length() < 3.0:
			return Vector3.INF                # já no portão: segue direto
		var d := from.distance_to(gp) + gp.distance_to(to)
		if d < bd:
			bd = d
			best = gp
	return best

## Procura em todos os mapas (o atual primeiro); `pick(def)` devolve a posição ou null.
static func _find(e: SimEntity, pick: Callable) -> Dictionary:
	var order: Array = [e.map_id]
	for mid in GameData.maps:
		if mid != e.map_id:
			order.append(mid)
	for mid in order:
		var def: MapDef = GameData.maps.get(mid)
		if def:
			var pos = pick.call(def)
			if pos != null:
				return {"map": mid, "pos": pos}
	return {}

static func _npc_spot(e: SimEntity, npc_id: String) -> Dictionary:
	return _find(e, func(def: MapDef): return _npc_of(def, npc_id))

static func _npc_of(def: MapDef, npc_id: String):
	for n in def.npcs:
		if n.get("id", "") == npc_id:
			return n["pos"]
	return null

static func _role_of(def: MapDef, role: String):
	for n in def.npcs:
		if n.get("role", "") == role:
			return n["pos"]
	return null

static func _spawner_of(def: MapDef, monster_ids: Array):
	for s in def.spawners:
		if s.get("monster_id", "") in monster_ids:
			return s["pos"]
	return null

## Monstro que só vem na investida: o povoado atacado (onde a defesa acontece).
static func _raid_of(def: MapDef, monster_id: String):
	for r in RaidSystem.routes(def):
		for w in r.get("waves", []):
			if w.get("mobs", {}).has(monster_id):
				return r["target"]
	return null

static func _gather_of(def: MapDef, item_id: String):
	for g in def.gather:
		if g.get("item", "") == item_id:
			return g["at"]
	return null

static func _place_of(def: MapDef, place_id: String):
	for pl in def.places:
		if pl["id"] == place_id:
			return pl["pos"]
	return null

## Monstros cuja tabela de loot tem o item.
static func _droppers(item_id: String) -> Array:
	var out: Array = []
	for mid in GameData.monsters:
		var m: MonsterDef = GameData.monsters[mid]
		var lt: LootTable = GameData.loot_tables.get(m.loot_table)
		if lt and lt.entries.any(func(en): return en.get("item", "") == item_id):
			out.append(mid)
	return out

## Etiqueta de repetível (UI e avisos): "" quando a quest é de uma vez só.
static func repeat_tag(q: QuestDef) -> String:
	return "↻ Repetível" if q.repeatable else ""

## Nome do NPC (procura em todos os mapas); id quando não acha.
static func npc_name(npc_id: String) -> String:
	for mid in GameData.maps:
		for n in GameData.maps[mid].npcs:
			if n.get("id", "") == npc_id:
				return str(n.get("name", npc_id))
	return npc_id

## Lembrete de repetível: onde pegar de novo.
static func repeat_note(q: QuestDef) -> String:
	return "↻ Repetível: pegue de novo com %s quando quiser." % npc_name(q.giver_npc) if q.repeatable else ""

## Peça do tier da quest que este personagem consegue vestir.
static func gear_reward(e: SimEntity, q: QuestDef, sim) -> String:
	if q.reward_gear_tier < 0:
		return ""
	var pool: Array = GearCatalog.wearables(q.reward_gear_tier).filter(func(it): return sim.equip_error(e, it) == "")
	return pool[sim.rng.randi() % pool.size()].id if pool.size() > 0 else ""

static func complete(e: SimEntity, q: QuestDef, sim) -> void:
	if not is_complete(e, q):
		return
	if q.type == QuestDef.Type.COLLECT:
		e.remove_item(q.target_id, q.count)
	e.quests_active.erase(q.id)
	if not (q.id in e.quests_completed):
		e.quests_completed.append(q.id)
	sim.gain_xp(e, q.reward_xp)
	e.gold += q.reward_gold
	for item_id in q.reward_items:
		e.add_item(item_id, int(q.reward_items[item_id]))
	var gear := gear_reward(e, q, sim)
	if gear != "":
		e.add_item(gear)
		if e == sim.player:
			Events.post(&"notification", "Recompensa: %s" % GameData.items[gear].name)
	Events.post(&"quest_completed", e.id, q.id)
	var again := "  —  " + repeat_note(q) if q.repeatable else ""
	Events.post(&"notification", "Quest concluída: %s (+%d XP, +%d ouro)%s" % [q.title, q.reward_xp, q.reward_gold, again])
