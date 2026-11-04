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
	Events.quest_accepted.emit(e.id, q.id)
	# COLLECT: conta o que já tem; TALK ao próprio NPC completa na hora
	if q.type == QuestDef.Type.COLLECT:
		on_item_changed(e, q.target_id)
	on_position(e)

## Desiste: o progresso se perde e a quest volta a ser oferecida.
static func abandon(e: SimEntity, q: QuestDef) -> void:
	if e.quests_active.erase(q.id):
		for iid in q.give_items:
			e.remove_item(iid, mini(int(q.give_items[iid]), int(e.inventory.get(iid, 0))))
		Events.quest_abandoned.emit(e.id, q.id)

static func progress(e: SimEntity, q: QuestDef) -> int:
	if q.type == QuestDef.Type.COLLECT:
		return mini(int(e.inventory.get(q.target_id, 0)), q.count)
	return int(e.quests_active.get(q.id, 0))

static func is_complete(e: SimEntity, q: QuestDef) -> bool:
	return e.quests_active.has(q.id) and progress(e, q) >= q.count

static func on_kill(e: SimEntity, monster_id: String) -> void:
	for qid in e.quests_active.keys():
		var q: QuestDef = GameData.quests.get(qid)
		if q and q.type == QuestDef.Type.KILL and q.target_id == monster_id:
			var cur := mini(int(e.quests_active[qid]) + 1, q.count)
			e.quests_active[qid] = cur
			Events.quest_progress.emit(e.id, qid, cur, q.count)

static func on_item_changed(e: SimEntity, item_id: String) -> void:
	for qid in e.quests_active.keys():
		var q: QuestDef = GameData.quests.get(qid)
		if q and q.type == QuestDef.Type.COLLECT and q.target_id == item_id:
			Events.quest_progress.emit(e.id, qid, progress(e, q), q.count)

static func on_craft(e: SimEntity, item_id: String, count: int) -> void:
	for qid in e.quests_active.keys():
		var q: QuestDef = GameData.quests.get(qid)
		if q and q.type == QuestDef.Type.CRAFT and q.target_id == item_id:
			var cur := mini(int(e.quests_active[qid]) + count, q.count)
			e.quests_active[qid] = cur
			Events.quest_progress.emit(e.id, qid, cur, q.count)

static func on_talk(e: SimEntity, npc_id: String) -> void:
	for qid in e.quests_active.keys():
		var q: QuestDef = GameData.quests.get(qid)
		if q and q.type == QuestDef.Type.TALK and q.target_id == npc_id:
			e.quests_active[qid] = q.count
			Events.quest_progress.emit(e.id, qid, q.count, q.count)

## REACH: chegou ao mapa alvo, ou perto do lugar alvo no mapa atual.
static func on_position(e: SimEntity) -> void:
	for qid in e.quests_active.keys():
		var q: QuestDef = GameData.quests.get(qid)
		if q and q.type == QuestDef.Type.REACH and not is_complete(e, q) and _arrived(e, q.target_id):
			e.quests_active[qid] = q.count
			Events.quest_progress.emit(e.id, qid, q.count, q.count)

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
			Events.notification.emit("Recompensa: %s" % GameData.items[gear].name)
	Events.quest_completed.emit(e.id, q.id)
	Events.notification.emit("Quest concluída: %s (+%d XP, +%d ouro)" % [q.title, q.reward_xp, q.reward_gold])
