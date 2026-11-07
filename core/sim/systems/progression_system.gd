class_name ProgressionSystem
extends RefCounted
## Progressão: XP/nível, renascer, árvore de pontos, talentos, loadout de skills/poções e skill resolvida (maestria, evoluções, forma).

static func gain_xp(sim: WorldSim, e: SimEntity, amount: int) -> void:
	if e.level >= Balance.MAX_LEVEL:
		return
	e.xp += amount
	Events.xp_gained.emit(e.id, amount)
	while e.level < Balance.MAX_LEVEL and e.xp >= Balance.xp_for_level(e.level):
		e.xp -= Balance.xp_for_level(e.level)
		e.level += 1
		e.mastery_points += Balance.points_at(e.level)
		e.recompute_stats()
		e.hp = minf(e.stats.max_hp, e.hp + e.stats.max_hp * Balance.LEVEL_UP_RESTORE)
		e.mp = minf(e.stats.max_mp, e.mp + e.stats.max_mp * Balance.LEVEL_UP_RESTORE)
		Events.level_up.emit(e.id, e.level)
		if e == sim.player:
			Events.notification.emit("Nível %d! +%d ponto(s) de skill (tecla K)" % [e.level, Balance.points_at(e.level)])
			BotChat.party_event(sim, e, "player_levelup", {"lv": str(e.level)})
		elif BotChat.in_player_party(sim, e):
			BotChat.party_event(sim, e, "self_levelup", {"lv": str(e.level)}, e, 0.6)
		elif e.kind == SimEntity.Kind.BOT and sim.rng.randf() < 0.35:
			Events.chat_message.emit(e.name, GameData.random_bot_line("levelup") % e.level, "global")
		if e.kind == SimEntity.Kind.BOT and e.class_def:
			bot_spend(sim, e)                  # bot gasta os pontos novos na teia
		if e.level == Balance.MAX_LEVEL:
			e.xp = 0

## Começo rápido (StartCatalog.PRESETS): nível com os pontos de skill de cada nível, equipamento comum do tier,
## itens, ouro e a cadeia de história até `quest` (concluída, sem recompensas) com `quest` ativa. Portões abrem pelo nível.
static func apply_start_preset(sim: WorldSim, e: SimEntity, preset_id: int) -> void:
	var pr: Dictionary = StartCatalog.PRESETS.get(preset_id, {})
	if pr.is_empty() or int(pr.get("level", 1)) <= 1:
		return
	while e.level < mini(int(pr["level"]), Balance.MAX_LEVEL):
		e.level += 1
		e.mastery_points += Balance.points_at(e.level)
	e.xp = 0
	e.gold += int(pr.get("gold", 0))
	for iid in pr.get("items", {}):
		e.add_item(iid, int(pr["items"][iid]))
	if pr.has("gear_tier") and not e.class_def.builds.is_empty():
		var keep := e.build_id
		e.build_id = e.class_def.builds[0]["id"]
		sim._gear_bot(e)                   # mesmo critério dos bots: tier pelo nível, armas da build
		e.build_id = keep
	var qid: String = pr.get("quest", "")
	if GameData.quests.has(qid):
		var lv := int(pr["level"])
		var done_ids: Array = _chain_before(qid)
		for oid in GameData.quests:             # tudo da faixa anterior (laterais incluídas) já feito
			var oq: QuestDef = GameData.quests[oid]
			if not oq.repeatable and oq.level_req < lv and oid != qid:
				done_ids.append(oid)
		for done in done_ids:
			if not (done in e.quests_completed):
				e.quests_completed.append(done)
		QuestSystem.accept(e, GameData.quests[qid])
	if pr.has("map") and GameData.maps.has(pr["map"]):
		var at: Array = pr.get("at", [])
		var pos: Vector3 = Vector3(float(at[0]), 0, float(at[1])) if at.size() == 2 else GameData.maps[pr["map"]].spawn_point
		sim.place_loaded(e, pr["map"], pos)       # começa longe de Aldara (o grupo nasce ao lado)
	PortalSystem.grandfather_gates(sim, e, e.map_id)
	e.recompute_stats()
	e.heal_full()
	Events.equipment_changed.emit(e.id)
	_start_party(sim, e, pr.get("party", []))

## Grupo pronto do começo rápido: bots do nível do jogador, na build pedida, entram já no grupo dele (líder).
static func _start_party(sim: WorldSim, e: SimEntity, members: Array) -> void:
	var names: Array = GameData.bot_names.duplicate()
	for i in range(members.size()):
		var cls: ClassDef = GameData.classes.get(members[i][0])
		if cls == null or PartySystem.party_members(sim, e).size() >= Balance.PARTY_MAX:
			continue
		var nm: String = names[sim.rng.randi() % names.size()] if not names.is_empty() else "Aliado%d" % i
		names.erase(nm)
		var a := TAU * i / maxf(1.0, members.size())
		var b := sim.spawn_bot(cls, nm, e.map_id, sim.random_walkable(sim.map_def(e.map_id), e.position + Vector3(cos(a) * 2.0, 0, sin(a) * 2.0), 1.5), e.level)
		if cls.build_by_id(str(members[i][1])).size() > 0 and b.build_id != members[i][1]:
			b.build_id = members[i][1]
			sim._gear_bot(b)
			sim._skill_bot(b)
		if PartySystem.party_invite(sim, e, b):
			PartySystem.party_accept(sim, b)

## Todos os pré-requisitos (diretos e de ramos) de uma quest, em qualquer profundidade.
static func _chain_before(qid: String) -> Array:
	var out: Array = []
	var todo: Array = [qid]
	while not todo.is_empty():
		var q: QuestDef = GameData.quests.get(todo.pop_back())
		if q == null:
			continue
		for pid in [q.prereq_quest] + Array(q.prereq_all):
			if pid != "" and not (pid in out):
				out.append(pid)
				todo.append(pid)
	return out

static func respawn_character(sim: WorldSim, e: SimEntity) -> void:
	var home := PortalSystem.home_of(e)
	e.hp = e.stats.max_hp * Balance.RESPAWN_SHARE
	e.mp = e.stats.max_mp * Balance.RESPAWN_SHARE
	e.set_state(SimEntity.State.IDLE)
	e.threat.clear()
	PortalSystem.change_map(sim, e, home["map"], home["pos"])      # cristal vinculado, ou a cidade
	Events.entity_respawned.emit(e.id)

## Cópia da skill com as evoluções do personagem aplicadas (só as cuja arma exigida ele empunha).
## Sem evolução ativa devolve a própria skill (sem alocação).
static func resolve_skill(sim: WorldSim, e: SimEntity, s: SkillDef) -> SkillDef:
	var out := resolve_talents(sim, e, s)
	if not e.ct.is_empty():
		out = ClassTalentSystem.apply_mods(e, out)          # talentos de classe (recarga, área, efeitos...)
	var fm: Dictionary = SkillsCatalog.FORM_MODS.get(s.id, {}).get(e.form, {}) if e.form != "" else {}
	if fm.is_empty():
		return out
	out = out.duplicate()          # forma de animal: a skill vira o golpe do bicho
	out.talent_effects = out.talent_effects.duplicate()
	if fm.has("name"):
		out.name = fm["name"]
	for k in fm.get("set", {}):
		out.set(k, fm["set"][k])
	for k in fm.get("mult", {}):
		out.set(k, float(out.get(k)) * float(fm["mult"][k]))
	for k in fm.get("effects", {}):
		out.talent_effects[k] = fm["effects"][k]
	return out

static func resolve_talents(sim: WorldSim, e: SimEntity, s: SkillDef) -> SkillDef:
	if not e.is_character() or e.talents.is_empty():
		return s
	var out: SkillDef = null
	for tid in e.talents:
		var t: TalentDef = GameData.talents.get(tid)
		if t == null or t.skill_id != s.id or not e.stats.meets(t.requires):
			continue
		if out == null:
			out = s.duplicate()
			out.talent_effects = {}
		var md := t.mods
		var sets: Dictionary = md.get("set", {})
		for k in sets:
			out.set(k, sets[k])
		var mults: Dictionary = md.get("mult", {})
		for k in mults:
			out.set(k, float(out.get(k)) * float(mults[k]))
		var fx: Dictionary = md.get("effects", {})
		for k in fx:
			out.talent_effects[k] = fx[k]
	return out if out else s

## Texto pt-BR de uma exigência de arma ("escudo", "duas espadas"...).
static func requires_text(req: Array) -> String:
	var names := {"shield": "escudo", "orb": "orbe", "dual": "duas armas de 1 mão", "two_handed": "arma de duas mãos",
		"sword": "espada", "sword2h": "montante", "mace": "maça", "mace2h": "martelo de duas mãos", "axe": "machadinha",
		"axe2h": "machado de duas mãos", "dagger": "adaga", "bow": "arco", "staff": "cajado", "wand": "varinha", "scythe": "foice", "scepter": "cetro", "rifle": "mosquete", "spear": "lança"}
	var plural := {"sword": "duas espadas", "mace": "duas maças", "axe": "dois machados", "dagger": "duas adagas"}
	var parts: Array = []
	for r in req:
		if r.begins_with("dual_"):
			parts.append(plural.get(r.substr(5), r))
		else:
			parts.append(names.get(r, r))
	return " ou ".join(parts)

static func tree_of(sim: WorldSim, e: SimEntity) -> Dictionary:
	return GameData.trees.get(e.class_def.id, {}) if e.class_def else {}

## "" se pode comprar o nó; senão o motivo.
static func tree_block_reason(sim: WorldSim, e: SimEntity, node_id: String) -> String:
	var tr := tree_of(sim, e)
	if tr.is_empty() or not tr["nodes"].has(node_id):
		return "nó inexistente"
	var n: Dictionary = tr["nodes"][node_id]
	if e.tree.has(node_id) and n["kind"] != "mastery":      # maestria compra de novo até o máximo (1 ponto por nível)
		return "já comprado"
	if n["kind"] == "pick":                  # talento de escolha: sem vizinho; um por linha, troca na cidade
		if e.level < int(n["level"]):
			return "requer nível %d" % int(n["level"])
		var other := pick_sibling(sim, e, node_id)
		if other != "":
			if Balance.PICK_SWAP_TOWN_ONLY and sim.maps.has(e.map_id) and not sim.maps[e.map_id]["def"].in_hub(e.position):
				return "troque a escolha desta linha na cidade"
			return ""                          # troca: o ponto da escolha antiga volta
		if e.mastery_points < int(n["cost"]):
			return "pontos insuficientes (%d)" % int(n["cost"])
		return ""
	var linked := false
	for l in n["links"]:
		if e.tree.has(l):
			linked = true
			break
	if not linked:
		return "precisa de um nó vizinho comprado"
	if e.level < int(n["level"]):
		return "requer nível %d" % int(n["level"])
	if e.mastery_points < int(n["cost"]):
		return "pontos insuficientes (%d)" % int(n["cost"])
	if n["kind"] == "mastery" and e.mastery_of(n["ref"]) >= Balance.MASTERY_MAX:
		return "maestria já no máximo"
	return ""

## Talento de escolha já comprado na mesma linha (outra opção do mesmo grupo), ou "".
static func pick_sibling(sim: WorldSim, e: SimEntity, node_id: String) -> String:
	var nodes: Dictionary = tree_of(sim, e)["nodes"]
	var g: String = nodes[node_id].get("group", "")
	for nid in e.tree:
		if nid != node_id and nodes.has(nid) and nodes[nid].get("group", "") == g and g != "":
			return nid
	return ""

## Compra um nó da árvore e aplica: skill nova (vai pro 1º slot livre), evolução, +1 maestria ou passivo.
static func tree_allocate(sim: WorldSim, e: SimEntity, node_id: String) -> bool:
	var why := tree_block_reason(sim, e, node_id)
	if why != "":
		if e == sim.player:
			Events.notification.emit("Árvore: " + why)
		return false
	var n: Dictionary = tree_of(sim, e)["nodes"][node_id]
	if n["kind"] == "pick":
		var other := pick_sibling(sim, e, node_id)
		if other != "":
			e.tree.erase(other)
			e.mastery_points += int(tree_of(sim, e)["nodes"][other]["cost"])
	e.mastery_points -= int(n["cost"])
	e.tree[node_id] = true
	var ref: String = n["ref"]
	match n["kind"]:
		"skill":
			e.learned[ref] = true
			e.mastery[ref] = e.mastery_of(ref)
			var free := ItemSystem.first_free_slot(sim, e)
			if free >= 0 and e.slot_of(ref) < 0:
				e.skills[free] = GameData.skills[ref]
		"talent":
			e.talents[ref] = true
		"mastery":
			e.mastery[ref] = mini(Balance.MASTERY_MAX, e.mastery_of(ref) + 1)
		"stat", "notable", "pick":
			recompute_tree_bonus(sim, e)
	Events.mastery_changed.emit(e.id, ref, e.mastery_of(ref))
	return true

## Bot gasta os pontos na teia como um jogador da build: caminho mais curto até cada skill da build (na ordem da
## build), maestria nas skills da barra (nível/6), evoluções às vezes, e o resto em notáveis e atributos do próprio
## braço (depois dos anéis). `fresh` = recomeça do início (troca de build / bot novo).
static func bot_spend(sim: WorldSim, e: SimEntity, fresh: bool = false) -> void:
	var tr := tree_of(sim, e)
	if tr.is_empty():
		return
	var nodes: Dictionary = tr["nodes"]
	var cid := e.class_def.id
	if fresh:
		e.tree = {tr["start"]: true}
		e.learned = {}
		for sid in e.class_def.starting_skills:
			e.tree["%s_s_%s" % [cid, sid]] = true
			e.learned[sid] = true
		e.talents = {}
		e.mastery = {}
		e.mastery_points = points_for_level(e.level)
	var build := e.class_def.build_by_id(e.build_id)
	var wanted: Array = build.get("skills", e.class_def.skill_ids)
	ClassTalentSystem.bot_pick(sim, e)        # talentos de classe (grátis, pelo nível)
	# 1) skills da build (que o nível já libera), pelo caminho mais curto
	for sid in wanted:
		var target := "%s_s_%s" % [cid, sid]
		if not nodes.has(target) or e.tree.has(target) or int(nodes[target]["level"]) > e.level:
			continue
		var path := _path_to(e, nodes, target)
		if path.is_empty() or path.size() > e.mastery_points:
			continue
		for nid in path:
			if not tree_allocate(sim, e, nid):
				break
	# 2) maestria das skills da build aprendidas, até nível/6
	var want_m := clampi(e.level / 6, 0, Balance.MASTERY_MAX)
	for sid in wanted:
		if not e.learned.has(sid):
			continue
		while e.mastery_of(sid) < want_m and e.mastery_points > 0:
			if not tree_allocate(sim, e, "%s_m_%s" % [cid, sid]):
				break
	# 3) evoluções das skills aprendidas (metade, como antes)
	for nid in nodes:
		var n: Dictionary = nodes[nid]
		if n["kind"] == "talent" and not e.tree.has(nid) and sim.rng.randf() < 0.5 and tree_block_reason(sim, e, nid) == "":
			tree_allocate(sim, e, nid)
	# 4) o resto: notáveis e atributos vizinhos, primeiro do braço da build, depois anéis e Geral
	var guard := 0
	while e.mastery_points > 0 and guard < 200:
		guard += 1
		var best := ""
		var best_score := -INF
		for nid in nodes:
			var n: Dictionary = nodes[nid]
			if not (n["kind"] in ["stat", "notable"]) or e.tree.has(nid) or tree_block_reason(sim, e, nid) != "":
				continue
			var score := 2.0 if n["kind"] == "notable" else 1.0
			if n["branch"] == e.build_id:
				score += 3.0
			elif n["branch"] == "ring":
				score += 1.0
			score -= (n["pos"] as Vector2).length() * 0.05      # perto do centro primeiro (caminho barato)
			if score > best_score:
				best_score = score
				best = nid
		if best == "" or not tree_allocate(sim, e, best):
			break

## Caminho (nós a comprar, em ordem) do pedaço já comprado até `target`, por BFS; nós acima do nível não entram.
static func _path_to(e: SimEntity, nodes: Dictionary, target: String) -> Array:
	var prev := {}
	var queue: Array = []
	for nid in e.tree:
		if nodes.has(nid):
			prev[nid] = ""
			queue.append(nid)
	var head := 0
	while head < queue.size():
		var cur: String = queue[head]
		head += 1
		if cur == target:
			break
		for l in nodes[cur]["links"]:
			if prev.has(l) or int(nodes[l]["level"]) > e.level or nodes[l]["kind"] in ["mastery", "talent"]:
				continue
			prev[l] = cur
			queue.append(l)
	if not prev.has(target):
		return []
	var path: Array = []
	var at := target
	while at != "" and not e.tree.has(at):
		path.push_front(at)
		at = prev[at]
	return path

## Pontos de skill que o nível dá no total (o reset devolve isto).
static func points_for_level(level: int) -> int:
	var n := 0
	for lv in range(2, level + 1):
		n += Balance.points_at(lv)
	return n

## Perto do NPC `npc_id` no mapa atual.
static func near_npc(sim: WorldSim, e: SimEntity, npc_id: String) -> bool:
	if not sim.maps.has(e.map_id):
		return false
	for n in sim.maps[e.map_id]["def"].npcs:
		if n.get("id", "") == npc_id and Vector2(n["pos"].x, n["pos"].z).distance_to(Vector2(e.position.x, e.position.z)) <= Balance.STATION_RANGE:
			return true
	return false

## Reset da árvore (Ancião Ravi): volta ao nó inicial com as skills iniciais, sem evoluções nem maestria, e devolve
## todos os pontos do nível. Os talentos de escolha ficam (não gastam pontos). A barra guarda só o que ainda conhece.
static func reset_tree(sim: WorldSim, e: SimEntity) -> bool:
	if e.class_def == null:
		return false
	if not Balance.SKILL_RESET_NPCS.any(func(nid): return near_npc(sim, e, nid)):
		if e == sim.player:
			Events.notification.emit("Fale com o Ancião Ravi, na praça de Aldara, para resetar as skills")
		return false
	var tr := tree_of(sim, e)
	var keep := {tr["start"]: true}
	for nid in e.tree:
		if tr["nodes"].has(nid) and tr["nodes"][nid]["kind"] == "pick":
			keep[nid] = true
	e.learned = {}
	for sid in e.class_def.starting_skills:
		keep["%s_s_%s" % [e.class_def.id, sid]] = true
		e.learned[sid] = true
	e.tree = keep
	e.talents = {}
	e.mastery = {}
	e.mastery_points = points_for_level(e.level)
	e.ensure_slots()
	for i in range(e.skills.size()):
		if e.skills[i] and not e.learned.has(e.skills[i].id):
			e.skills[i] = null
	recompute_tree_bonus(sim, e)
	Events.mastery_changed.emit(e.id, "", 0)
	if e == sim.player:
		Events.notification.emit("Skills resetadas: %d pontos para distribuir (tecla K)" % e.mastery_points)
	return true

## Soma os passivos comprados (chamar ao carregar o save).
static func recompute_tree_bonus(sim: WorldSim, e: SimEntity) -> void:
	e.tree_bonus = {}
	var tr := tree_of(sim, e)
	for nid in e.tree:
		var n: Dictionary = tr["nodes"].get(nid, {})
		for k in n.get("stats", {}):
			e.tree_bonus[k] = float(e.tree_bonus.get(k, 0.0)) + float(n["stats"][k])
	ClassTalentSystem.refresh(e)
	e.recompute_stats()

## Atalhos pela árvore (UI antiga, testes): aprender skill / comprar evolução = comprar o nó dela.
static func learn_skill(sim: WorldSim, e: SimEntity, skill_id: String) -> bool:
	if e.knows(skill_id) or e.class_def == null:
		return false
	return tree_allocate(sim, e, "%s_s_%s" % [e.class_def.id, skill_id])

static func learn_talent(sim: WorldSim, e: SimEntity, talent_id: String) -> bool:
	if e.has_talent(talent_id) or e.class_def == null:
		return false
	return tree_allocate(sim, e, "%s_t_%s" % [e.class_def.id, talent_id])

## Põe uma skill aprendida no slot (ou "" para esvaziar). Troca de lugar se já estiver na barra.
static func set_skill_slot(sim: WorldSim, e: SimEntity, slot: int, skill_id: String) -> bool:
	if slot < 0 or slot >= Balance.SKILL_SLOTS:
		return false
	if Balance.LOADOUT_TOWN_ONLY and sim.maps.has(e.map_id) and not sim.maps[e.map_id]["def"].in_hub(e.position):
		Events.notification.emit("Troque skills da barra na cidade ou num povoado com cristal")
		return false
	e.ensure_slots()
	if skill_id == "":
		e.skills[slot] = null
		Events.mastery_changed.emit(e.id, "", 0)
		return true
	var s: SkillDef = GameData.skills.get(skill_id)
	if s == null or not e.knows(skill_id):
		return false
	var cur := e.slot_of(skill_id)
	if cur >= 0:
		e.skills[cur] = e.skills[slot]
	e.skills[slot] = s
	Events.mastery_changed.emit(e.id, skill_id, e.mastery_of(skill_id))
	return true

## +1 maestria com pontos = comprar a folha de maestria da skill na árvore (repete até Balance.MASTERY_MAX).
static func upgrade_mastery(sim: WorldSim, e: SimEntity, skill_id: String) -> bool:
	if e.class_def == null or not e.knows(skill_id):
		return false
	return tree_allocate(sim, e, "%s_m_%s" % [e.class_def.id, skill_id])

static func set_potion_slot(sim: WorldSim, e: SimEntity, slot: int, item_id: String) -> void:
	e.potion_slots[slot] = item_id
