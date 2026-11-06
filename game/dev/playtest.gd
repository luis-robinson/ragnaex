class_name Playtest
extends RefCounted
## Playtest automático (`-- --autostart=<classe> --preset=20 --playtest=<pasta> [--playtest_time=600] [--speed=2]`):
## o jogador segue a cadeia principal como uma pessoa faria (seta da quest, portais, fala com NPCs, aceita/entrega,
## briga com o que aparece usando skills e poções) e grava em <pasta>/playtest_<classe>.log:
## quests aceitas/concluídas (com tempo), mortes, níveis, travadas, FPS e picos de quadro, e fotos periódicas.

const CHAIN := ["q12_ruins", "dw_gates", "dw_ghoul_posts", "dw_ghoul_boss", "dw_ghoul_settle", "dw_bones_posts", "dw_bones_boss",
	"dw_frost_posts", "dw_frost_boss", "dw_lich"]
const SHOT_EVERY := 40.0
const LOG_EVERY := 10.0

var main: Node
var dir := ""
var left := 600.0
var t := 0.0
var log_t := 0.0
var shot_t := 5.0
var frames := 0
var frame_t := 0.0
var worst := 0.0
var spikes := 0
var fps_min := 999.0
var fps_sum := 0.0
var fps_n := 0
var file: FileAccess
var skill_t := 0.0
var skill_i := 0
var last_pos := Vector3.ZERO
var still := 0.0
var wander := Vector3.INF
var path: Array = []
var path_goal := Vector3.INF
var path_t := 0.0
var detour := Vector2.ZERO
var detour_left := 0.0
var deaths := 0
var stats := {"quests": 0, "kills": 0, "stuck": 0, "potions": 0}
var quest_t0 := {}

func setup(m: Node, out_dir: String, seconds: float) -> void:
	main = m
	dir = out_dir
	left = seconds
	DirAccess.make_dir_recursive_absolute(dir)
	var p: SimEntity = Sim.player
	file = FileAccess.open(dir.path_join("playtest_%s.log" % p.class_def.id), FileAccess.WRITE)
	_log("START classe=%s build=%s nv=%d mapa=%s grupo=%d" % [p.class_def.id, p.build_id, p.level, p.map_id, PartySystem.party_members(Sim, p).size()])
	Events.quest_accepted.connect(func(eid, qid): if eid == Sim.player.id: quest_t0[qid] = Time.get_ticks_msec() / 1000.0; _log("QUEST_ACEITA %s" % qid))
	Events.quest_completed.connect(_on_quest_done)
	Events.entity_died.connect(_on_died)
	Events.level_up.connect(func(eid, lv): if eid == Sim.player.id: _log("NIVEL %d" % lv))
	Events.raid_event.connect(func(mid, kind): if mid == Sim.player.map_id: _log("INVESTIDA %s" % kind))
	Events.chat_message.connect(func(who, text, ch): if ch == "system": _log("SISTEMA %s" % text))

func _log(s: String) -> void:
	var line := "[%6.1f] %s" % [t, s]
	print("PLAYTEST " + line)
	if file:
		file.store_line(line)
		file.flush()

func _on_quest_done(eid: int, qid: String) -> void:
	if eid != Sim.player.id:
		return
	stats["quests"] += 1
	var took: float = Time.get_ticks_msec() / 1000.0 - float(quest_t0.get(qid, Time.get_ticks_msec() / 1000.0))
	_log("QUEST_CONCLUIDA %s em %.0fs (real)" % [qid, took])
	_shot("quest_" + qid)

func _on_died(eid: int, killer: int) -> void:
	var p: SimEntity = Sim.player
	if eid == p.id:
		deaths += 1
		var k: SimEntity = Sim.entities.get(killer)
		_log("MORTE #%d mapa=%s por=%s" % [deaths, p.map_id, k.name if k else "?"])
		_shot("morte_%d" % deaths)
	else:
		var e: SimEntity = Sim.entities.get(eid)
		if e and e.kind == SimEntity.Kind.MONSTER and killer == p.id:
			stats["kills"] += 1

func _shot(tag: String) -> void:
	var img := main.get_viewport().get_texture().get_image()
	if img:
		img.save_png(dir.path_join("%s_%04d_%s.png" % [Sim.player.class_def.id, int(t), tag]))

## Um quadro: mede, decide e manda o comando do jogador. Devolve false quando acabou.
func tick(delta: float) -> bool:
	var p: SimEntity = Sim.player
	if p == null:
		return true
	t += delta
	left -= delta
	frames += 1
	frame_t += delta
	worst = maxf(worst, delta)
	if delta > 0.1:
		spikes += 1
	log_t += delta
	shot_t -= delta
	if frame_t >= 1.0:
		var fps := frames / frame_t
		fps_min = minf(fps_min, fps)
		fps_sum += fps
		fps_n += 1
		frames = 0
		frame_t = 0.0
	if log_t >= LOG_EVERY:
		log_t = 0.0
		var q := _current_quest(p)
		var prog := "-" if q == null else "%s %d/%d" % [q.id, QuestSystem.progress(p, q), q.count]
		_log("ESTADO mapa=%s pos=(%.0f,%.0f) nv=%d hp=%d%% quest=%s fps_med=%.0f fps_min=%.0f pior_quadro=%.0fms picos=%d grupo=%d" % [p.map_id, p.position.x, p.position.z,
			p.level, int(100.0 * p.hp / p.stats.max_hp), prog, fps_sum / maxf(1.0, fps_n), fps_min, worst * 1000.0, spikes, PartySystem.party_members(Sim, p).size()])
		worst = 0.0
	if shot_t <= 0.0:
		shot_t = SHOT_EVERY
		_shot("tick")
	if left <= 0.0:
		_finish(p)
		return false
	if not p.is_alive():
		return true
	Sim.set_player_command(_think(p, delta))
	return true

func _finish(p: SimEntity) -> void:
	var done := CHAIN.filter(func(q): return p.quests_completed.has(q))
	_log("FIM classe=%s nv=%d quests_feitas=%d cadeia=%d/%d (%s) mortes=%d abates=%d travadas=%d pocoes=%d fps_med=%.0f fps_min=%.0f picos>100ms=%d" % [
		p.class_def.id, p.level, stats["quests"], done.size(), CHAIN.size(), ",".join(done), deaths, stats["kills"], stats["stuck"], stats["potions"],
		fps_sum / maxf(1.0, fps_n), fps_min, spikes])
	_shot("fim")
	if file:
		file.close()

func _current_quest(p: SimEntity) -> QuestDef:
	for qid in CHAIN:
		if p.quests_active.has(qid):
			return GameData.quests[qid]
	for qid in p.quests_active:
		var q: QuestDef = GameData.quests.get(qid)
		if q and not q.repeatable:
			return q
	return null

## Próximo passo da cadeia sem quest ativa: o NPC que dá a próxima quest.
func _next_giver(p: SimEntity) -> String:
	for qid in CHAIN:
		if not p.quests_completed.has(qid) and not p.quests_active.has(qid):
			return GameData.quests[qid].giver_npc
	return ""

func _think(p: SimEntity, dt: float) -> InputCommand:
	var cmd := InputCommand.new()
	cmd.aim = p.position + p.forward()
	var m: Dictionary = Sim.maps[p.map_id]
	_npc_chores(p, m)
	if p.hp < p.stats.max_hp * 0.4 and Sim.use_potion(p, 0):
		stats["potions"] += 1
	# briga: o que estiver perto (prioriza o alvo da quest)
	var q := _current_quest(p)
	var foe := _pick_foe(p, m, q)
	if foe:
		return _fight(p, foe, cmd, dt)
	# rumo: objetivo da quest (ou o NPC da próxima)
	var goal := Vector3.INF
	if q:
		var gp := QuestSystem.guide_point(p, q)
		if not gp.is_empty():
			goal = gp["pos"]
			if not gp["via_portal"] and not gp.get("via_gate", false) and q.type == QuestDef.Type.KILL and not QuestSystem.is_complete(p, q) and p.position.distance_to(goal) < 18.0:
				if wander == Vector3.INF or p.position.distance_to(wander) < 2.0:
					wander = Sim.random_walkable(m["def"], goal, 16.0)
				goal = wander
	else:
		var giver := _next_giver(p)
		if giver != "":
			var spot := QuestSystem._npc_spot(p, giver)
			if not spot.is_empty():
				if spot["map"] == p.map_id:
					goal = spot["pos"]
				else:
					var pt := PortalSystem.portal_towards(m["def"], spot["map"])
					if not pt.is_empty():
						goal = pt["pos"]
	if goal == Vector3.INF:
		return cmd
	cmd.move = _steer(p, goal, dt)
	cmd.aim = goal
	return cmd

## Perto de NPCs: aceita o que tiverem, fala (TALK) e entrega.
func _npc_chores(p: SimEntity, m: Dictionary) -> void:
	for e in m["entities"]:
		if e.kind != SimEntity.Kind.NPC or e.position.distance_to(p.position) > 4.0:
			continue
		var nid: String = e.npc_data.get("id", "")
		QuestSystem.on_talk(p, nid)
		for q in QuestSystem.turnins_at(p, nid):
			if QuestSystem.is_complete(p, q):
				QuestSystem.complete(p, q, Sim)
		for q in QuestSystem.available_from_npc(p, nid):
			if not q.repeatable:
				QuestSystem.accept(p, q)

func _pick_foe(p: SimEntity, m: Dictionary, q: QuestDef) -> SimEntity:
	var ids: Array = [] if q == null or q.type != QuestDef.Type.KILL else [q.target_id] + Array(q.also_counts)
	var best: SimEntity = null
	var bs := INF
	for e in m["entities"]:
		if e.kind != SimEntity.Kind.MONSTER or not e.is_alive() or e.monster_def.xp <= 0 and not e.monster_def.is_boss and e.aggro_target != p.id:
			continue
		var d: float = e.position.distance_to(p.position)
		var reach := 16.0 if (ids.has(e.monster_def.id) or e.aggro_target == p.id) else 9.0
		if d > reach:
			continue
		var s := d - (6.0 if ids.has(e.monster_def.id) else 0.0) - (8.0 if e.aggro_target == p.id else 0.0)
		if s < bs:
			bs = s
			best = e
	return best

func _fight(p: SimEntity, foe: SimEntity, cmd: InputCommand, dt: float) -> InputCommand:
	cmd.aim = foe.position
	var reach := 2.0
	if p.class_def.basic_attack_is_ranged:
		reach = 8.0
	var d := p.position.distance_to(foe.position) - foe.radius
	if d > reach:
		cmd.move = _steer(p, foe.position, dt)
	else:
		cmd.attack = true
		if d < reach * 0.4 and reach > 3.0:      # à distância: recua um pouco (kite)
			var away := p.position - foe.position
			cmd.move = Vector2(away.x, away.z).normalized() * 0.6
	skill_t -= dt
	if skill_t <= 0.0:
		skill_t = 0.45
		var n := p.skills.size()
		for k in range(n):
			var i := (skill_i + k) % maxi(1, n)
			var sk: SkillDef = p.skills[i]
			if sk != null and float(p.cooldowns.get(sk.id, 0.0)) <= 0.0 and p.mp >= sk.mp_cost:
				cmd.skill_slot = i
				skill_i = i + 1
				break
	return cmd

func _steer(p: SimEntity, goal: Vector3, dt: float) -> Vector2:
	path_t -= dt
	if path_t <= 0.0 or path_goal.distance_to(goal) > 3.0:
		path_t = 1.5
		path_goal = goal
		path = Sim.water_path(p.map_id, p.position, goal)
	while not path.is_empty() and Vector2(p.position.x, p.position.z).distance_to(path[0]) < 1.2:
		path.pop_front()
	var g := goal if path.is_empty() else Vector3(path[0].x, 0, path[0].y)
	var v := Vector2(g.x - p.position.x, g.z - p.position.z).normalized()
	if p.position.distance_to(last_pos) < 0.03:
		still += dt
	else:
		still = 0.0
	last_pos = p.position
	if still > 0.6 and detour_left <= 0.0:
		detour = v.rotated(PI * 0.5 * (1.0 if randf() < 0.5 else -1.0))
		detour_left = randf_range(0.7, 1.4)
		if still > 6.0:
			stats["stuck"] += 1
			_log("TRAVADO mapa=%s pos=(%.0f,%.0f) rumo=(%.0f,%.0f)" % [p.map_id, p.position.x, p.position.z, goal.x, goal.z])
			_shot("travado")
			still = 0.0
	detour_left -= dt
	if detour_left > 0.0:
		return (v * 0.3 + detour).normalized()
	return v
