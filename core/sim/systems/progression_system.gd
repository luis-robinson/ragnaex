class_name ProgressionSystem
extends RefCounted
## Progressão: XP/nível, renascer, árvore de pontos, talentos, loadout de skills/poções e skill resolvida (maestria, evoluções, forma).

## A ascensão da classe está liberada (nível e missão de ascensão).
static func has_ascension(e: SimEntity) -> bool:
	return e.class_def != null and e.level >= Balance.ASC_LEVEL and e.quests_completed.has("hx_asc_" + e.class_def.id)

## Skills de ascensão da classe (SkillDef.ascension): fora da teia comum, aprendidas na teia de ascensão e na barra
## só nas vagas 7-0.
static func ascension_skills(e: SimEntity) -> Array:
	var out: Array = []
	if e.class_def == null:
		return out
	for sid in e.class_def.skill_ids:
		var s: SkillDef = GameData.skills.get(sid)
		if s and s.ascension:
			out.append(sid)
	return out

# --- Teia de ascensão (R6): GameData.asc_trees, nós em e.asc_tree, pontos próprios (calculados, não salvos) ---

static func asc_tree_of(e: SimEntity) -> Dictionary:
	return GameData.asc_trees.get(e.class_def.id, {}) if e.class_def else {}

static func is_asc_node(e: SimEntity, node_id: String) -> bool:
	var tr := asc_tree_of(e)
	return not tr.is_empty() and tr["nodes"].has(node_id)

## Pontos de ascensão ganhos: ASC_POINTS_PER_LEVEL por nível do ASC_LEVEL ao ASC_MAX_LEVEL + ASC_QUEST_POINTS da missão.
static func asc_points_total(e: SimEntity) -> int:
	if not has_ascension(e):
		return 0
	return Balance.ASC_POINTS_PER_LEVEL * (mini(e.level, Balance.ASC_MAX_LEVEL) - Balance.ASC_LEVEL + 1) + Balance.ASC_QUEST_POINTS

## Pontos gastos na teia de ascensão (maestria conta 1 por nível).
static func asc_points_spent(e: SimEntity) -> int:
	var tr := asc_tree_of(e)
	if tr.is_empty():
		return 0
	var n := 0
	for nid in e.asc_tree:
		var nd: Dictionary = tr["nodes"].get(nid, {})
		if nd.is_empty():
			continue
		n += int(nd["cost"]) * (e.mastery_of(nd["ref"]) if nd["kind"] == "mastery" else 1)
	return n

static func asc_points(e: SimEntity) -> int:
	return asc_points_total(e) - asc_points_spent(e)

## Portão da teia de ascensão comprado (nó com `flag`, AscensionCatalog.NODES): ex. "elem_ancestral".
static func asc_flag(e: SimEntity, flag: String) -> bool:
	var tr := asc_tree_of(e)
	if tr.is_empty():
		return false
	for nid in e.asc_tree:
		if str(tr["nodes"].get(nid, {}).get("flag", "")) == flag:
			return true
	return false

static func _asc_block_reason(e: SimEntity, node_id: String) -> String:
	var tr := asc_tree_of(e)
	var n: Dictionary = tr["nodes"][node_id]
	if not has_ascension(e):
		return "requer a ascensão da classe (nível %d e a missão)" % Balance.ASC_LEVEL
	if n["kind"] == "start":
		return "já comprado"
	if e.asc_tree.has(node_id) and n["kind"] != "mastery":
		return "já comprado"
	var linked := false
	for l in n["links"]:
		if l == tr["start"] or e.asc_tree.has(l):
			linked = true
			break
	if not linked:
		return "precisa de um nó vizinho comprado"
	if e.level < int(n["level"]):
		return "requer nível %d" % int(n["level"])
	if asc_points(e) < int(n["cost"]):
		return "pontos de ascensão insuficientes (%d)" % int(n["cost"])
	if n["kind"] == "mastery" and e.mastery_of(n["ref"]) >= Balance.MASTERY_MAX:
		return "maestria já no máximo"
	return ""

static func _asc_allocate(sim: WorldSim, e: SimEntity, node_id: String) -> bool:
	var why := _asc_block_reason(e, node_id)
	if why != "":
		if e == sim.player:
			Events.post(&"notification", "Ascensão: " + why)
		return false
	var n: Dictionary = asc_tree_of(e)["nodes"][node_id]
	e.asc_tree[node_id] = true
	var ref: String = n["ref"]
	match n["kind"]:
		"skill":
			e.learned[ref] = true
			e.mastery[ref] = e.mastery_of(ref)
			e.ensure_slots()
			var free := ItemSystem.first_free_slot(sim, e, true)
			if free >= 0 and e.slot_of(ref) < 0:
				e.skills[free] = GameData.skills[ref]
		"mastery":
			e.mastery[ref] = mini(Balance.MASTERY_MAX, e.mastery_of(ref) + 1)
		"stat", "notable":
			recompute_tree_bonus(sim, e)
	Events.post(&"mastery_changed", e.id, ref, e.mastery_of(ref))
	return true

## Zera a teia de ascensão (respec): esquece as skills dela e a maestria, tira da barra; os pontos voltam (são calculados).
static func asc_reset(sim: WorldSim, e: SimEntity) -> void:
	for sid in ascension_skills(e):
		e.learned.erase(sid)
		e.mastery.erase(sid)
		var at := e.slot_of(sid)
		if at >= 0:
			e.skills[at] = null
	e.asc_tree = {}

## Bot ascendido compra caminho na teia de ascensão como na comum: as skills na ordem da build
## (AscensionCatalog.bot_order), maestria delas até nível/6, portões e passivos; o resto em entradas. Sem ascensão: nada.
static func bot_spend_asc(sim: WorldSim, e: SimEntity) -> void:
	var tr := asc_tree_of(e)
	if tr.is_empty():
		return
	asc_reset(sim, e)
	if not has_ascension(e):
		recompute_tree_bonus(sim, e)
		return
	var cid := e.class_def.id
	var nodes: Dictionary = tr["nodes"]
	var order := AscensionCatalog.bot_order(e.class_def, e.build_id, GameData.skills)
	var want_m := clampi(e.level / 6, 0, Balance.MASTERY_MAX)
	for sid in order:
		var target := "%s_a_s_%s" % [cid, sid]
		if not nodes.has(target) or int(nodes[target]["level"]) > e.level:
			continue
		var path := _asc_path_to(e, tr, target)
		if path.is_empty() or path.size() > asc_points(e):
			continue
		for nid in path:
			if not _asc_allocate(sim, e, nid):
				break
	for nid in nodes:              # refinos (portões) da build e do Geral antes das maestrias: o bot usa o que a build escolheu
		var g: Dictionary = nodes[nid]
		if not g.has("flag") or e.asc_tree.has(nid) or not (str(g["branch"]) in ["", e.build_id]) or int(g["level"]) > e.level:
			continue
		for pid in _asc_path_to(e, tr, nid):
			if not _asc_allocate(sim, e, pid):
				break
	for sid in order:
		if not e.learned.has(sid):
			continue
		while e.mastery_of(sid) < want_m and asc_points(e) > 0:
			if not _asc_allocate(sim, e, "%s_a_m_%s" % [cid, sid]):
				break
	var guard := 0
	while asc_points(e) > 0 and guard < 100:            # portões e passivos, depois entradas
		guard += 1
		var best := ""
		var best_score := -INF
		for nid in nodes:
			var n: Dictionary = nodes[nid]
			if not (n["kind"] in ["stat", "notable"]) or e.asc_tree.has(nid) or _asc_block_reason(e, nid) != "":
				continue
			var score := (3.0 if n["kind"] == "notable" else 1.0) + (2.0 if n["branch"] == e.build_id else 0.0)
			if str(n["branch"]) != "" and n["branch"] != e.build_id:
				score -= 2.0          # ramo de outra build: só depois do Geral e do próprio (o portão Geral não fica para trás)
			score -= (n["pos"] as Vector2).length() * 0.05
			if score > best_score:
				best_score = score
				best = nid
		if best == "" or not _asc_allocate(sim, e, best):
			break

## Caminho (nós a comprar) do início/do comprado até `target` na teia de ascensão (BFS, sem maestria nem acima do nível).
static func _asc_path_to(e: SimEntity, tr: Dictionary, target: String) -> Array:
	var nodes: Dictionary = tr["nodes"]
	var prev := {tr["start"]: ""}
	var queue: Array = [tr["start"]]
	for nid in e.asc_tree:
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
			if prev.has(l) or int(nodes[l]["level"]) > e.level or nodes[l]["kind"] == "mastery":
				continue
			prev[l] = cur
			queue.append(l)
	if not prev.has(target):
		return []
	var path: Array = []
	var at := target
	while at != "" and at != tr["start"] and not e.asc_tree.has(at):
		path.push_front(at)
		at = prev[at]
	return path

static func gain_xp(sim: WorldSim, e: SimEntity, amount: int) -> void:
	if e.level >= Balance.MAX_LEVEL:
		return
	e.xp += amount
	Events.post(&"xp_gained", e.id, amount)
	while e.level < Balance.MAX_LEVEL and e.xp >= Balance.xp_for_level(e.level):
		e.xp -= Balance.xp_for_level(e.level)
		e.level += 1
		e.mastery_points += Balance.points_at(e.level)
		e.recompute_stats()
		var fresh_skills := grant_level_skills(sim, e, e.kind != SimEntity.Kind.BOT)
		e.hp = minf(e.stats.max_hp, e.hp + e.stats.max_hp * Balance.LEVEL_UP_RESTORE)
		e.mp = minf(e.stats.max_mp, e.mp + e.stats.max_mp * Balance.LEVEL_UP_RESTORE)
		Events.post(&"level_up", e.id, e.level)
		if e == sim.player:
			Events.post(&"notification", "Nível %d! +%d ponto(s) de skill (tecla K)" % [e.level, Balance.points_at(e.level)])
			for sid in fresh_skills:
				Events.post(&"notification", "Nova skill: %s (tecla K)" % GameData.skills[sid].name)
			if has_ascension(e) and e.level <= Balance.ASC_MAX_LEVEL:
				Events.post(&"notification", "+%d ponto(s) de ascensão (tecla K, aba Ascensão)" % Balance.ASC_POINTS_PER_LEVEL)
			BotChat.party_event(sim, e, "player_levelup", {"lv": str(e.level)})
		elif BotChat.in_player_party(sim, e):
			BotChat.party_event(sim, e, "self_levelup", {"lv": str(e.level)}, e, 0.6)
		elif e.kind == SimEntity.Kind.BOT and sim.rng.randf() < 0.35:
			Events.post(&"chat_message", e.name, GameData.random_bot_line("levelup") % e.level, "global")
		if e.kind == SimEntity.Kind.BOT and e.class_def:
			bot_spend(sim, e)                  # bot gasta os pontos novos na teia
			bot_spend_asc(sim, e)              # e na de ascensão (pontos próprios)
			sim._slot_bot(e)                   # barra na ordem da build (senão a skill nova nunca entrava: 6 vagas cheias)
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
	e.recompute_stats()
	grant_level_skills(sim, e)               # skills do nível (as primeiras na barra)
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
	for s in e.skills:                       # ranks como os de um bot do nível nas skills da barra (Balance.BOT_SKILL_RANK_PER_LEVELS)
		if s and not s.ascension:
			e.mastery[s.id] = maxi(e.mastery_of(s.id), bot_rank(e, s))
	e.heal_full()
	Events.post(&"equipment_changed", e.id)
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
	var home := PortalSystem.home_of(e, sim)
	e.hp = e.stats.max_hp * Balance.RESPAWN_SHARE
	e.mp = e.stats.max_mp * Balance.RESPAWN_SHARE
	e.set_state(SimEntity.State.IDLE)
	e.threat.clear()
	PortalSystem.change_map(sim, e, home["map"], home["pos"])      # cristal vinculado, ou a cidade
	Events.post(&"entity_respawned", e.id)

## Cópia da skill com as evoluções do personagem aplicadas (só as cuja arma exigida ele empunha).
## Sem evolução ativa devolve a própria skill (sem alocação).
static func resolve_skill(sim: WorldSim, e: SimEntity, s: SkillDef) -> SkillDef:
	var out := resolve_talents(sim, e, s)
	out = _web_upgrades(e, s, out)                          # nós "Aprimorada"/"Ágil" da teia
	if not e.ct.is_empty():
		out = ClassTalentSystem.apply_mods(e, out)          # talentos de classe (recarga, área, efeitos...)
	if out.ascension:
		out = NecroAscension.resolve(e, out)                # nós da teia de ascensão do Necromante (raio, duração)
		out = RangerAscension.resolve(e, out)               # refinos da torreta (recarga)
		out = MountedCombat.resolve(e, out)                 # Lança Pesada (alcance da Carga Montada)
		out = TitanSystem.resolve(e, out)                   # Giro dos Dois Machados (Ciclone de Titã mais longo)
		out = GladiatorSystem.resolve(e, out)               # Golpe Final da Arena
	var fm: Dictionary = DruidAscension.form_mods(s.id, e.form) if e.form != "" else {}
	if fm.is_empty():
		return DruidAscension.refine(e, s, out, false)
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
	return DruidAscension.refine(e, s, out, true)

## Nós da teia da skill: "<Skill> Aprimorada" (<classe>_s_<id>, +SKILL_UP_POWER de poder) e "<Skill> Ágil"
## (<classe>_m_<id>, -SKILL_QUICK_PCT de recarga e MP). Copia a skill só se algum dos dois foi comprado.
static func _web_upgrades(e: SimEntity, s: SkillDef, out: SkillDef) -> SkillDef:
	if e.class_def == null or e.tree.size() <= 1 or s.ascension:
		return out
	var up := e.tree.has("%s_s_%s" % [e.class_def.id, s.id])
	var quick := e.tree.has("%s_m_%s" % [e.class_def.id, s.id])
	if not up and not quick:
		return out
	if out == s:
		out = s.duplicate()
		out.talent_effects = s.talent_effects.duplicate()
	if up:
		out.power *= 1.0 + Balance.SKILL_UP_POWER
	if quick:
		out.cooldown *= 1.0 - Balance.SKILL_QUICK_PCT
		out.mp_cost *= 1.0 - Balance.SKILL_QUICK_PCT
	return out

## Multiplicador de MP do nó "Ágil" (try_cast cobra antes de resolver a skill).
static func web_mp_mult(e: SimEntity, sid: String) -> float:
	if e.class_def == null or e.tree.size() <= 1 or not e.tree.has("%s_m_%s" % [e.class_def.id, sid]):
		return 1.0
	return 1.0 - Balance.SKILL_QUICK_PCT

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
		"axe2h": "machado de duas mãos", "dagger": "adaga", "claw": "garra", "bow": "arco", "staff": "cajado", "wand": "varinha", "scythe": "foice", "scepter": "cetro", "rifle": "mosquete", "spear": "lança", "pistol": "pistola",
		"titan": "Empunhadura de Titã", "gladiator": "Modo Gladiador", "glory_full": "%d de Glória" % Balance.GLORY_MAX}
	var plural := {"sword": "duas espadas", "mace": "duas maças", "axe": "dois machados", "dagger": "duas adagas", "claw": "duas garras"}
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
	if is_asc_node(e, node_id):
		return _asc_block_reason(e, node_id)
	var tr := tree_of(sim, e)
	if tr.is_empty() or not tr["nodes"].has(node_id):
		return "nó inexistente"
	var n: Dictionary = tr["nodes"][node_id]
	if e.tree.has(node_id):
		return "já comprado"
	if n["kind"] in ["skill_up", "skill_quick"] and not e.knows(n["ref"]):
		return "requer a skill (nível %d)" % int(n["level"])
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
	for x in n.get("excludes", []):          # pedra-angular: a outra opção do círculo já foi comprada
		if e.tree.has(x):
			return "exclui %s (já escolhida)" % str(tr["nodes"][x]["name"])
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
	return ""

## Talento de escolha já comprado na mesma linha (outra opção do mesmo grupo), ou "".
static func pick_sibling(sim: WorldSim, e: SimEntity, node_id: String) -> String:
	var nodes: Dictionary = tree_of(sim, e)["nodes"]
	var g: String = nodes[node_id].get("group", "")
	for nid in e.tree:
		if nid != node_id and nodes.has(nid) and nodes[nid].get("group", "") == g and g != "":
			return nid
	return ""

## Compra um nó da árvore e aplica: evolução, passivo; "Aprimorada"/"Ágil" valem pelo resolve_skill.
## `batch` = não refaz os atributos a cada passivo (quem chama refaz uma vez no fim; ex.: bot_spend de bot novo).
## Ex.: `ProgressionSystem.tree_allocate(sim, e, "paladin_m_pal_holy_strike")`.
static func tree_allocate(sim: WorldSim, e: SimEntity, node_id: String, batch: bool = false) -> bool:
	if is_asc_node(e, node_id):
		return _asc_allocate(sim, e, node_id)
	var why := tree_block_reason(sim, e, node_id)
	if why != "":
		if e == sim.player:
			Events.post(&"notification", "Árvore: " + why)
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
		"talent":
			e.talents[ref] = true
		"stat", "notable", "pick":
			if not batch:
				recompute_tree_bonus(sim, e)
	Events.post(&"mastery_changed", e.id, ref, e.mastery_of(ref))
	return true

## Nó cuja compra refaz os atributos (só estes têm `stats`).
static func _changes_stats(n: Dictionary) -> bool:
	return n["kind"] in ["stat", "notable", "pick"]

## Bot gasta os pontos na teia como um jogador da build: caminho mais curto até cada skill da build (na ordem da
## build), maestria nas skills da barra (nível/6), evoluções às vezes, e o resto em notáveis e atributos do próprio
## braço (depois dos anéis). `fresh` = recomeça do início (troca de build / bot novo).
## `batch` = refaz os atributos uma vez no fim, não a cada passivo (bot novo, que nasce com heal_full: o HP no meio
## do caminho, que as pedras-angulares com hp_pct < 0 cortariam, não importa). Subir de nível usa o padrão.
## Ex.: `ProgressionSystem.bot_spend(sim, bot, true, true)`.
static func bot_spend(sim: WorldSim, e: SimEntity, fresh: bool = false, batch: bool = false) -> void:
	var tr := tree_of(sim, e)
	if tr.is_empty():
		return
	var nodes: Dictionary = tr["nodes"]
	var cid := e.class_def.id
	if fresh:
		e.tree = {tr["start"]: true}
		e.learned = {}
		e.talents = {}
		e.mastery = {}
		e.mastery_points = points_for_level(e.level)
	grant_level_skills(sim, e, false)                             # skills pelo nível (a barra é do _slot_bot)
	var build := e.class_def.build_by_id(e.build_id)
	var wanted: Array = build.get("skills", e.class_def.skill_ids)
	# ranks de graça pelo nível nas skills da build (o jogador paga no Mestre de Skills)
	for sid in wanted:
		var ws: SkillDef = GameData.skills.get(sid)
		if ws and e.learned.has(sid) and not ws.ascension:
			e.mastery[sid] = maxi(e.mastery_of(sid), bot_rank(e, ws))
	var dirty := ClassTalentSystem.bot_pick(sim, e, batch)        # talentos de classe (grátis, pelo nível)
	# 0) notáveis de base (anel do Início, Balance.CORE_NOTABLES): todos primeiro (1 ponto cada, sem nível)
	for i in range((Balance.CORE_NOTABLES.get(cid, []) as Array).size() if bot_core else 0):
		var cid_core := "%s_core_%d" % [cid, i]
		if nodes.has(cid_core) and not e.tree.has(cid_core) and e.mastery_points > 0 and tree_block_reason(sim, e, cid_core) == "":
			if tree_allocate(sim, e, cid_core, batch):
				dirty = true
	# 1) "Aprimorada" das skills da build (que o nível já libera), pelo caminho mais curto; depois "Ágil" ao lado
	for sid in wanted:
		var target := "%s_s_%s" % [cid, sid]
		if not nodes.has(target) or e.tree.has(target) or int(nodes[target]["level"]) > e.level:
			continue
		var path := _path_to(e, nodes, target)
		if path.is_empty() or path.size() > e.mastery_points:
			continue
		for nid in path:
			if not tree_allocate(sim, e, nid, batch):
				break
			dirty = dirty or _changes_stats(nodes[nid])
	for sid in wanted:
		var quick := "%s_m_%s" % [cid, sid]
		if nodes.has(quick) and not e.tree.has(quick) and tree_block_reason(sim, e, quick) == "":
			tree_allocate(sim, e, quick, batch)
	# 2b) notáveis de papel da classe para esta build (sobrevivência / dano de tanque), do mais perto ao mais longe
	dirty = _bot_role_notes(sim, e, nodes, batch) or dirty
	# 3) evoluções das skills aprendidas (metade, como antes)
	for nid in nodes:
		var n: Dictionary = nodes[nid]
		if n["kind"] == "talent" and not e.tree.has(nid) and sim.rng.randf() < 0.5 and tree_block_reason(sim, e, nid) == "":
			tree_allocate(sim, e, nid, batch)
	# 4) o resto: notáveis e atributos vizinhos, primeiro do braço da build, depois anéis e Geral
	var guard := 0
	var lean := "def" if build.get("role", "") in ["tank", "healer"] else "atk"     # pedra-angular que o bot escolhe
	if bot_spawn_cache:
		var order := _web_order(nodes, cid, e.build_id, lean)
		while e.mastery_points > 0 and guard < Balance.BOT_WEB_SPEND_GUARD:
			guard += 1
			var best := ""
			for nid in order:           # 1º livre na ordem de nota = o mesmo que a varredura escolheria
				if not e.tree.has(nid) and (bot_core or not nodes[nid].has("core")) and _web_open(e, nodes[nid]):
					best = nid
					break
			if best == "" or not tree_allocate(sim, e, best, batch):
				break
			dirty = dirty or _changes_stats(nodes[best])
		if batch and dirty:
			recompute_tree_bonus(sim, e)
		return
	while e.mastery_points > 0 and guard < Balance.BOT_WEB_SPEND_GUARD:
		guard += 1
		var best := ""
		var best_score := -INF
		for nid in nodes:
			var n: Dictionary = nodes[nid]
			if not (n["kind"] in ["stat", "notable"]) or e.tree.has(nid) or n.get("keystone", lean) != lean or (n.has("core") and not bot_core) or tree_block_reason(sim, e, nid) != "":
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
		if best == "" or not tree_allocate(sim, e, best, batch):
			break
		dirty = dirty or _changes_stats(nodes[best])
	if batch and dirty:
		recompute_tree_bonus(sim, e)

## Cache do passo 4 do bot_spend: "<classe>|<build>|<lean>" -> {"nodes": dicionário da teia, "order": ids}.
## Só leitura de dados fixos (GameData.trees); uso na thread da sim, uma de cada vez.
static var _web_cache := {}
## false = caminho antigo (varre a teia toda a cada ponto; equipamento de bot sem cache). Só o teste desliga.
static var bot_spawn_cache := true
## Bots compram os notáveis de base (CORE_NOTABLES) antes de tudo; os testes de outras mecânicas desligam para medir como antes.
static var bot_core := true

## Nós stat/notável que o bot da build compraria no passo 4, por nota decrescente; empate na ordem da teia
## (o `>` estrito da varredura antiga fica com o primeiro). Ex.: `for nid in _web_order(nodes, "paladin", "cruzado", "atk")`.
## Bot compra os notáveis de papel (TreeCatalog._role_notables) marcados para a build dele, pelo caminho mais curto,
## se o caminho tiver até Balance.BOT_ROLE_NOTE_PATH nós e couber nos pontos. Devolve se mudou atributo.
static func _bot_role_notes(sim: WorldSim, e: SimEntity, nodes: Dictionary, batch: bool) -> bool:
	var dirty := false
	for _i in range(4):                  # até 4 notáveis: o mais barato primeiro, refazendo o caminho a cada compra
		var best: Array = []
		for nid in nodes:
			var n: Dictionary = nodes[nid]
			if not n.has("role_note") or e.tree.has(nid) or not (e.build_id in n["role_bots"]) or int(n["level"]) > e.level:
				continue
			var path := _path_to(e, nodes, nid)
			if path.is_empty() or path.size() > Balance.BOT_ROLE_NOTE_PATH or path.size() > e.mastery_points:
				continue
			if best.is_empty() or path.size() < best.size():
				best = path
		if best.is_empty():
			break
		for nid in best:
			if not tree_allocate(sim, e, nid, batch):
				return dirty
			dirty = dirty or _changes_stats(nodes[nid])
	return dirty

static func _web_order(nodes: Dictionary, cid: String, build_id: String, lean: String) -> PackedStringArray:
	var key := "%s|%s|%s" % [cid, build_id, lean]
	var c: Dictionary = _web_cache.get(key, {})
	if not c.is_empty() and is_same(c["nodes"], nodes):
		return c["order"]
	var rows: Array = []
	var idx := 0
	for nid in nodes:
		var n: Dictionary = nodes[nid]
		idx += 1
		if not (n["kind"] in ["stat", "notable"]) or n.get("keystone", lean) != lean:
			continue
		var score := 2.0 if n["kind"] == "notable" else 1.0       # mesma conta do caminho antigo (mesmo float)
		if n["branch"] == build_id:
			score += 3.0
		elif n["branch"] == "ring":
			score += 1.0
		score -= (n["pos"] as Vector2).length() * 0.05
		rows.append([score, idx, nid])
	rows.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	var order := PackedStringArray()
	for r in rows:
		order.append(r[2])
	_web_cache[key] = {"nodes": nodes, "order": order}
	return order

## Mesmo resultado de tree_block_reason(...) == "" para nó stat/notável ainda não comprado (sem as strings).
static func _web_open(e: SimEntity, n: Dictionary) -> bool:
	for x in n.get("excludes", []):
		if e.tree.has(x):
			return false
	var linked := false
	for l in n["links"]:
		if e.tree.has(l):
			linked = true
			break
	return linked and e.level >= int(n["level"]) and e.mastery_points >= int(n["cost"])

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
			if prev.has(l) or int(nodes[l]["level"]) > e.level or nodes[l]["kind"] in ["skill_quick", "talent"]:
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

## Reset da árvore (Ancião Ravi): volta ao nó inicial (as skills do nível e os ranks ficam; sai a teia de ascensão),
## sem evoluções, e devolve todos os pontos do nível. Os talentos de escolha ficam (não gastam pontos). A barra guarda só o que ainda conhece.
static func reset_tree(sim: WorldSim, e: SimEntity) -> bool:
	if e.class_def == null:
		return false
	if not Balance.SKILL_RESET_NPCS.any(func(nid): return near_npc(sim, e, nid)):
		if e == sim.player:
			Events.post(&"notification", "Fale com o Ancião Ravi, na praça de Aldara, para resetar as skills")
		return false
	var tr := tree_of(sim, e)
	var keep := {tr["start"]: true}
	for nid in e.tree:
		if tr["nodes"].has(nid) and tr["nodes"][nid]["kind"] == "pick":
			keep[nid] = true
	e.tree = keep
	e.talents = {}
	for sid in ascension_skills(e):            # a teia de ascensão volta: as skills dela e a maestria saem
		e.mastery.erase(sid)
	e.learned = {}
	grant_level_skills(sim, e, false)          # as skills do nível ficam (e os ranks pagos no Mestre de Skills também)
	e.mastery_points = points_for_level(e.level)
	e.ensure_slots()
	for i in range(e.skills.size()):
		if e.skills[i] and not e.learned.has(e.skills[i].id):
			e.skills[i] = null
	e.asc_tree = {}                            # teia de ascensão também volta (os pontos dela são calculados); a ascensão fica
	recompute_tree_bonus(sim, e)
	Events.post(&"mastery_changed", e.id, "", 0)
	if e == sim.player:
		Events.post(&"notification", "Skills resetadas: %d pontos para distribuir (tecla K)" % e.mastery_points)
	return true

## Soma os passivos comprados (chamar ao carregar o save).
static func recompute_tree_bonus(sim: WorldSim, e: SimEntity) -> void:
	e.tree_bonus = {}
	var tr := tree_of(sim, e)
	for nid in e.tree:
		var n: Dictionary = tr["nodes"].get(nid, {})
		for k in n.get("stats", {}):
			e.tree_bonus[k] = float(e.tree_bonus.get(k, 0.0)) + float(n["stats"][k])
	var atr := asc_tree_of(e)
	for nid in e.asc_tree:
		var n: Dictionary = atr.get("nodes", {}).get(nid, {})
		for k in n.get("stats", {}):
			e.tree_bonus[k] = float(e.tree_bonus.get(k, 0.0)) + float(n["stats"][k])
	ClassTalentSystem.refresh(e)
	e.recompute_stats()

## Atalho antigo (dev/testes): skills vêm pelo nível (grant_level_skills); aprende só uma skill comum da classe já
## liberada pelo nível que ainda não conhece (ex.: save editado) e põe na 1ª vaga livre. Ascensão: pela teia dela.
static func learn_skill(sim: WorldSim, e: SimEntity, skill_id: String) -> bool:
	var s: SkillDef = GameData.skills.get(skill_id)
	if s == null or e.knows(skill_id) or e.class_def == null or s.ascension or not (skill_id in e.class_def.skill_ids) or e.level < s.unlock_level:
		return false
	e.learned[skill_id] = true
	e.mastery[skill_id] = e.mastery_of(skill_id)
	_slot_new(sim, e, s)
	Events.post(&"mastery_changed", e.id, skill_id, e.mastery_of(skill_id))
	return true

## Skills comuns da classe (fora ascensão) que o nível `level` libera: as iniciais primeiro, depois por nível.
## Ex.: `ProgressionSystem.level_skill_ids(GameData.classes["paladin"], 10)`.
static func level_skill_ids(cls: ClassDef, level: int) -> Array:
	var out: Array = []
	for sid in cls.starting_skills:
		var s0: SkillDef = GameData.skills.get(sid)
		if s0 and not s0.ascension and s0.unlock_level <= level:
			out.append(sid)
	var rest: Array = []
	for sid in cls.skill_ids:
		var s: SkillDef = GameData.skills.get(sid)
		if s and not s.ascension and s.unlock_level <= level and not (sid in out):
			rest.append(s)
	rest.sort_custom(func(a, b): return a.unlock_level < b.unlock_level)
	for s in rest:
		out.append(s.id)
	return out

## Aprende as skills que o nível dá (no spawn, ao subir de nível, ao carregar). `slot_new` = põe cada nova na 1ª vaga
## livre de 1-6 se a arma serve (jogador; o bot refaz a barra com WorldSim._slot_bot). Devolve os ids novos.
## Ex.: `ProgressionSystem.grant_level_skills(sim, player)`.
static func grant_level_skills(sim: WorldSim, e: SimEntity, slot_new: bool = true) -> Array:
	var out: Array = []
	if e.class_def == null:
		return out
	e.ensure_slots()
	for sid in level_skill_ids(e.class_def, e.level):
		if e.learned.has(sid):
			continue
		e.learned[sid] = true
		e.mastery[sid] = e.mastery_of(sid)
		out.append(sid)
		if slot_new:
			_slot_new(sim, e, GameData.skills[sid])
	return out

## Skill nova na 1ª vaga livre de 1-6 (arma que não serve: fica na janela K, não ocupa a barra).
static func _slot_new(sim: WorldSim, e: SimEntity, s: SkillDef) -> void:
	var free := ItemSystem.first_free_slot(sim, e)
	if free >= 0 and e.slot_of(s.id) < 0 and e.stats.meets(s.requires):
		e.skills[free] = s

# --- Rank da skill (1-5, e.mastery) no Mestre de Skills: ouro + materiais da faixa da skill ---

## Tier da skill pelo nível dela (Balance.COMMON_TIER_LEVELS; 0..5): escolhe o ouro e os materiais do rank.
static func skill_tier(s: SkillDef) -> int:
	var t := 0
	for i in range(Balance.COMMON_TIER_LEVELS.size()):
		if s.unlock_level >= Balance.COMMON_TIER_LEVELS[i]:
			t = i
	return mini(t, Balance.SKILL_RANK_MATS.size() - 1)

## Nível exigido para o rank `rank` da skill: nível dela + SKILL_RANK_LEVEL_STEP × (rank-1), até MAX_LEVEL.
static func rank_level(s: SkillDef, rank: int) -> int:
	return mini(Balance.MAX_LEVEL, s.unlock_level + Balance.SKILL_RANK_LEVEL_STEP * maxi(0, rank - 1))

## Custo do rank `to_rank` (padrão: o próximo) da skill: {"gold", "items": {id: n}, "level", "rank"}; {} se não existe.
## Ex.: `ProgressionSystem.rank_cost(p, "pal_holy_strike")` -> {"gold": 40, "items": {"iron_ore": 2}, "level": 1, "rank": 1}.
static func rank_cost(e: SimEntity, skill_id: String, to_rank: int = -1) -> Dictionary:
	var s: SkillDef = GameData.skills.get(skill_id)
	if s == null:
		return {}
	var r := to_rank if to_rank > 0 else e.mastery_of(skill_id) + 1
	if r > Balance.MASTERY_MAX:
		return {}
	var tier := skill_tier(s)
	var mats: Array = Balance.SKILL_RANK_MATS[tier]
	var items := {str(mats[0]): r}     # comum: r unidades (era r+1; ferro do 1-10 virava gargalo, playtest 2026-11-18)
	if r >= Balance.SKILL_RANK_RARE_FROM:
		items[str(mats[1])] = r - Balance.SKILL_RANK_RARE_FROM + 1
	return {"gold": int(Balance.SKILL_RANK_GOLD_BASE * (tier + 1) * pow(r, 1.5)), "items": items, "level": rank_level(s, r), "rank": r}

## Perto de um NPC com papel de Mestre de Skills (Balance.SKILL_TRAINER_ROLES).
static func near_trainer(sim: WorldSim, e: SimEntity) -> bool:
	for role in Balance.SKILL_TRAINER_ROLES:
		if ItemSystem.near_station(sim, e, str(role)):
			return true
	return false

## Por que não dá para subir o rank agora ("" = dá). `ignore_npc` = sem exigir o Mestre por perto (testes, dev).
static func rank_error(sim: WorldSim, e: SimEntity, skill_id: String, ignore_npc: bool = false) -> String:
	var s: SkillDef = GameData.skills.get(skill_id)
	if s == null or e.class_def == null or not (skill_id in e.class_def.skill_ids):
		return "Skill de outra classe"
	if s.ascension:
		return "Skill de ascensão: o rank sobe na teia de ascensão"
	if not e.knows(skill_id):
		return "Skill ainda não aprendida (nível %d)" % s.unlock_level
	if e.mastery_of(skill_id) >= Balance.MASTERY_MAX:
		return "Rank já no máximo (%d)" % Balance.MASTERY_MAX
	var c := rank_cost(e, skill_id)
	if e.level < int(c["level"]):
		return "Rank %d pede nível %d" % [int(c["rank"]), int(c["level"])]
	if not ignore_npc and not near_trainer(sim, e):
		return "Fale com o Mestre de Skills (na cidade) para subir o rank"
	if e.gold < int(c["gold"]):
		return "Ouro insuficiente (%d)" % int(c["gold"])
	for iid in c["items"]:
		var need := int(c["items"][iid])
		if not e.has_item(iid, need):
			return "Faltam %d %s" % [need - int(e.inventory.get(iid, 0)), GameData.items[iid].name if GameData.items.has(iid) else iid]
	return ""

## Sobe o rank da skill em 1: cobra ouro e materiais e escreve e.mastery (efeitos da maestria de sempre).
## Ex.: `ProgressionSystem.rank_up(sim, p, "pal_holy_strike")`.
static func rank_up(sim: WorldSim, e: SimEntity, skill_id: String, ignore_npc: bool = false) -> bool:
	var why := rank_error(sim, e, skill_id, ignore_npc)
	if why != "":
		if e == sim.player:
			Events.post(&"notification", why)
		return false
	var c := rank_cost(e, skill_id)
	e.gold -= int(c["gold"])
	for iid in c["items"]:
		e.remove_item(iid, int(c["items"][iid]))
	e.mastery[skill_id] = int(c["rank"])
	Events.post(&"mastery_changed", e.id, skill_id, e.mastery_of(skill_id))
	if e == sim.player:
		Events.post(&"notification", "%s: rank %d!" % [GameData.skills[skill_id].name, e.mastery_of(skill_id)])
	return true

## Rank de graça do bot (e do começo rápido): nível / BOT_SKILL_RANK_PER_LEVELS, sem passar do que o nível libera.
static func bot_rank(e: SimEntity, s: SkillDef) -> int:
	var r := clampi(e.level / Balance.BOT_SKILL_RANK_PER_LEVELS, 0, Balance.MASTERY_MAX)
	while r > 0 and rank_level(s, r) > e.level:
		r -= 1
	return r

static func learn_talent(sim: WorldSim, e: SimEntity, talent_id: String) -> bool:
	if e.has_talent(talent_id) or e.class_def == null:
		return false
	return tree_allocate(sim, e, "%s_t_%s" % [e.class_def.id, talent_id])

## Põe uma skill aprendida no slot (ou "" para esvaziar). Troca de lugar se já estiver na barra.
static func set_skill_slot(sim: WorldSim, e: SimEntity, slot: int, skill_id: String) -> bool:
	e.ensure_slots()
	if slot < 0 or slot >= e.skills.size():
		return false
	if Balance.LOADOUT_TOWN_ONLY and sim.maps.has(e.map_id) and not sim.maps[e.map_id]["def"].in_hub(e.position):
		Events.post(&"notification", "Troque skills da barra na cidade ou num povoado com cristal")
		return false
	e.ensure_slots()
	if skill_id == "":
		e.skills[slot] = null
		Events.post(&"mastery_changed", e.id, "", 0)
		return true
	var s: SkillDef = GameData.skills.get(skill_id)
	if s == null or not e.knows(skill_id):
		return false
	if s.ascension != (slot >= Balance.SKILL_SLOTS):
		if e == sim.player:
			Events.post(&"notification", "%s é skill de ascensão: vai nas teclas 7, 8, 9 e 0" % s.name if s.ascension else "%s: as teclas 7, 8, 9 e 0 são só das skills de ascensão (use 1-6)" % s.name)
		return false
	var cur := e.slot_of(skill_id)
	if cur >= 0:
		e.skills[cur] = e.skills[slot]
	e.skills[slot] = s
	Events.post(&"mastery_changed", e.id, skill_id, e.mastery_of(skill_id))
	return true

## +1 maestria: skill de ascensão compra a folha de maestria na teia de ascensão; skill comum sobe o rank no
## Mestre de Skills (rank_up: ouro + materiais, perto do NPC).
static func upgrade_mastery(sim: WorldSim, e: SimEntity, skill_id: String) -> bool:
	if e.class_def == null or not e.knows(skill_id):
		return false
	if GameData.skills[skill_id].ascension:
		return tree_allocate(sim, e, "%s_a_m_%s" % [e.class_def.id, skill_id])
	return rank_up(sim, e, skill_id)

static func set_potion_slot(sim: WorldSim, e: SimEntity, slot: int, item_id: String) -> void:
	e.potion_slots[slot] = item_id

## Build principal: a do bot; no jogador, a do conjunto que mais veste, senão a do braço da teia com mais nós.
static func main_build(sim: WorldSim, e: SimEntity) -> String:
	if e.build_id != "" or e.class_def == null or e.class_def.builds.is_empty():
		return e.build_id
	var score := {}
	for b in e.class_def.builds:
		score[b["id"]] = 0.0
	for sl in e.equipment:
		var it: ItemDef = e.equipment[sl]
		if it and it.set_id != "":
			var hsd: SetDef = GameData.sets.get(it.set_id)
			var bid := hsd.build_of() if hsd else GearCatalog.bid_of_set(it.set_id).trim_prefix(e.class_def.id + "_")
			if score.has(bid):
				score[bid] += 10.0
	var nodes: Dictionary = tree_of(sim, e)["nodes"]
	for nid in e.tree:
		var n: Dictionary = nodes.get(nid, {})
		if score.has(n.get("branch", "")):
			score[n["branch"]] += 1.0
	var best: String = e.class_def.builds[0]["id"]
	for bid in score:
		if score[bid] > score[best]:
			best = bid
	return best

## Papel no grupo pela build principal ("tank", "healer", "dps", "caster", "ranged"; ClassDef.builds[].role).
static func role_of(sim: WorldSim, e: SimEntity) -> String:
	if e.class_def == null:
		return "dps"
	return str(e.class_def.build_by_id(main_build(sim, e)).get("role", "dps"))
