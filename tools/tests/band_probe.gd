extends Node
## Teste de jogo de uma faixa de nível (padrão 10-20): auditoria das quests e duelos de bot contra cada monstro da faixa.
##   godot --headless --path . tools/tests/band_probe.tscn -- [--from=10] [--to=20] [--trials=6] [--only=audit|duel] [--mob=<id>,...] [--why]
## AUDIT: quest sem NPC, alvo que não nasce em mapa nenhum, nível do alvo fora da quest, item de coleta sem fonte, abates esperados.
## DUEL <monstro> nv=N vitorias=V/T ttk=Ss vida_perdida=P% (bot do nível do monstro, classes se revezam; CHAIN monstros
##   seguidos sem descanso nem poção: ttk = média por monstro; vida perdida = o ponto mais baixo da caçada).
##   FLAG difícil: vitórias < 70% ou vida perdida > 75%; FLAG lento: ttk > 25 s; FLAG trivial: ttk < 3 s e vida perdida < 8%.

const DT := 1.0 / 20.0
const LIMIT := 45.0
const CHAIN := 4              # monstros seguidos por caçada
const ELITE_HP := 1500.0      # monstro com mais vida que isto é elite: luta sozinho (1 por caçada)
const BAND_MAPS := ["field_forest", "dg_ninho", "elf_city", "dg_coracao", "dg_catacumbas", "dg_catacumbas_trono", "dg_pedreira", "dg_pedreira_coracao"]

var lv_from := 10
var lv_to := 20
var flags := 0

func _ready() -> void:
	await get_tree().process_frame
	var trials := 6
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--from="): lv_from = int(a.get_slice("=", 1))
		if a.begins_with("--to="): lv_to = int(a.get_slice("=", 1))
		if a.begins_with("--trials="): trials = int(a.get_slice("=", 1))
		if a.begins_with("--only="): only = a.get_slice("=", 1)
	if only != "duel":
		_audit()
	if only != "audit":
		_duels(trials)
	print("BAND_END flags=%d" % flags)
	get_tree().quit()

func _flag(text: String) -> void:
	flags += 1
	print("  FLAG " + text)

## Onde cada monstro nasce (mapa -> spawner) e de onde vem cada item (loot de quem nasce, colheita, entrega).
func _sources() -> Dictionary:
	var spawns := {}       # monster_id -> [map_id]
	for mid in GameData.maps:
		for sp in GameData.maps[mid].spawners:
			var arr: Array = spawns.get(sp["monster_id"], [])
			arr.append(mid)
			spawns[sp["monster_id"]] = arr
	for mid in GameData.maps:              # investidas: os invasores só nascem nas levas (todas as rotas do mapa)
		for r in RaidSystem.routes(GameData.maps[mid]):
			for w in r.get("waves", []):
				for mon_id in w["mobs"]:
					var arr: Array = spawns.get(mon_id, [])
					if not ("investida " + mid) in arr:
						arr.append("investida " + mid)
					spawns[mon_id] = arr
	var drops := {}        # item_id -> [[monster_id, chance, média]]
	for mon_id in spawns:
		var md: MonsterDef = GameData.monsters.get(mon_id)
		if md == null or md.loot_table == "" or not GameData.loot_tables.has(md.loot_table):
			continue
		for en in GameData.loot_tables[md.loot_table].entries:
			var arr: Array = drops.get(en["item"], [])
			arr.append([mon_id, float(en.get("chance", 1.0)), (float(en.get("min", 1)) + float(en.get("max", 1))) * 0.5])
			drops[en["item"]] = arr
	var gather := {}
	for mid in MapsCatalog.GATHER:
		for g in MapsCatalog.GATHER[mid]:
			var gm: Array = gather.get(g[0], [])
			if not mid in gm:
				gm.append(mid)
			gather[g[0]] = gm
	return {"spawns": spawns, "drops": drops, "gather": gather}

func _npc_maps() -> Dictionary:
	var out := {}
	for mid in GameData.maps:
		for n in GameData.maps[mid].npcs:
			out[n["id"]] = mid
	return out

func _audit() -> void:
	var src := _sources()
	var npcs := _npc_maps()
	var xp_band := 0
	var per_level := {}
	print("AUDIT quests %d-%d" % [lv_from, lv_to])
	for qid in GameData.quests:
		var q: QuestDef = GameData.quests[qid]
		if q.level_req < lv_from or q.level_req > lv_to:
			continue
		per_level[q.level_req] = int(per_level.get(q.level_req, 0)) + 1
		if not q.repeatable:
			xp_band += q.reward_xp
		var where := ""
		if not npcs.has(q.giver_npc):
			_flag("%s: giver %s não existe em mapa nenhum" % [qid, q.giver_npc])
		if q.turnin_npc != "" and not npcs.has(q.turnin_npc):
			_flag("%s: turnin %s não existe" % [qid, q.turnin_npc])
		if q.map_hint == "":
			_flag("%s: sem map_hint" % qid)
		match q.type:
			QuestDef.Type.KILL:
				var md: MonsterDef = GameData.monsters.get(q.target_id)
				if md == null:
					_flag("%s: monstro %s não existe" % [qid, q.target_id])
					continue
				var maps: Array = src["spawns"].get(q.target_id, [])
				if maps.is_empty():
					_flag("%s: %s não nasce em mapa nenhum" % [qid, q.target_id])
				var uniq: Array = []
				for x in maps:
					if not x in uniq:
						uniq.append(x)
				where = ",".join(uniq)
				if md.level < q.level_req - 3 or md.level > q.level_req + 5:
					_flag("%s: alvo nv %d longe da quest nv %d" % [qid, md.level, q.level_req])
			QuestDef.Type.COLLECT:
				if not q.give_items.is_empty():
					where = "entrega"
				elif src["gather"].has(q.target_id):
					where = "colheita em " + str(src["gather"][q.target_id])
				elif src["drops"].has(q.target_id):
					var best := 0.0
					var who := ""
					for d in src["drops"][q.target_id]:
						var dm: MonsterDef = GameData.monsters[d[0]]
						var per: float = d[1] * d[2] * (0.05 if dm.is_boss else 1.0)    # chefe é fonte de reserva, não de farm
						if per > best:
							best = per
							who = d[0]
					var kills := ceili(q.count / maxf(best, 0.001))
					where = "loot de %s (~%d abates)" % [who, kills]
					if kills > 30:
						_flag("%s: %d abates esperados para %d %s" % [qid, kills, q.count, q.target_id])
				else:
					_flag("%s: item %s sem fonte (loot/colheita/entrega)" % [qid, q.target_id])
		print("  %-14s nv%-2d %-8s %-18s x%-2d xp=%-5d %s" % [qid, q.level_req, QuestDef.Type.keys()[q.type], q.target_id, q.count, q.reward_xp, where])
	var need := 0
	for lv in range(lv_from, lv_to):
		need += Balance.xp_for_level(lv)
	print("AUDIT xp das quests %d de %d para subir %d->%d (%.0f%%); quests por nível %s" % [xp_band, need, lv_from, lv_to, 100.0 * xp_band / maxf(1, need), str(per_level)])

func _duels(trials: int) -> void:
	var src := _sources()
	var classes: Array = GameData.classes.keys()
	Sim.load_map(GameData.maps[GameData.town_map_id()])
	var seen := {}
	var only_mobs: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mob="):
			only_mobs = Array(a.get_slice("=", 1).split(","))
	for mid in BAND_MAPS:
		if not GameData.maps.has(mid):
			continue
		var m: Dictionary = Sim.load_map(GameData.maps[mid])
		m["spawners"].clear()
		for sp in GameData.maps[mid].spawners:
			var mon_id: String = sp["monster_id"]
			var md: MonsterDef = GameData.monsters.get(mon_id)
			if not only_mobs.is_empty() and not (mon_id in only_mobs):
				continue
			if md == null or md.is_boss or md.xp <= 0 or seen.has(mon_id) or md.level < lv_from or md.level > lv_to + 1:
				continue
			seen[mon_id] = true
			var wins := 0
			var ttk := 0.0
			var lost := 0.0
			var chain := 1 if md.hp >= ELITE_HP else CHAIN
			var died := 0
			var stalls := 0
			for trial in range(trials):
				for e in m["entities"].duplicate():
					if e.kind != SimEntity.Kind.NPC:
						Sim.despawn(e)
				var cid: String = classes[(trial * 5 + mon_id.length()) % classes.size()]
				var area: float = minf(float(sp.get("radius", 4.0)), 4.0)       # todos dentro da área do spawner (sala de verdade)
				var bot = Sim.spawn_bot(GameData.classes[cid], "Duelo", mid, Sim.random_walkable(GameData.maps[mid], sp["pos"], area), md.level)
				for i in 3:
					bot.potion_slots[i] = ""              # caçada limpa: sem poção
				bot.brain.state = BotBrain.S.TOWN_IDLE    # parado; o combate reativo do bot responde ao monstro
				bot.brain.timer = 999.0
				var t := 0.0
				var low := 1.0
				var killed := 0
				for k in chain:                           # caçada: CHAIN monstros seguidos, sem descanso (elite: 1)
					var mob = Sim.spawn_monster(md, mid, Sim.random_walkable(GameData.maps[mid], sp["pos"], area))
					bot.brain.hunt_target_id = mob.id
					mob.aggro_target = bot.id
					mob.aggro_timer = 5.0                 # como no boss_probe: sem isso, monstro de aggro curto nascido longe largava o bot (travou falso)
					var tk := 0.0
					while tk < LIMIT and mob.is_alive() and bot.is_alive() and bot.map_id == mid:
						Sim.tick(DT)
						tk += DT
						low = minf(low, bot.hp / bot.stats.max_hp)
					t += tk
					if mob.is_alive():
						if bot.is_alive():
							stalls += 1                   # ninguém morreu: o bot não alcança/acerta o monstro (IA, não dificuldade)
							if OS.get_cmdline_user_args().has("--why"):
								print("    travou: %s/%s dist=%.1f bot_estado=%s mob_estado=%s mob_alvo=%d mob_hp=%.0f%% bot_hp=%.0f%% mob_casa=%.1f" % [cid, bot.build_id,
									bot.position.distance_to(mob.position), SimEntity.State.keys()[bot.state], SimEntity.State.keys()[mob.state], mob.aggro_target,
									100.0 * mob.hp / mob.stats.max_hp, 100.0 * bot.hp / bot.stats.max_hp, mob.position.distance_to(mob.home_position)])
						Sim.despawn(mob)
						break
					killed += 1
				if killed == chain:
					wins += 1
					ttk += t / chain
				lost += 1.0 - (low if bot.is_alive() else 0.0)
				if not bot.is_alive():
					died += 1
				Sim.despawn(bot)
			var avg_ttk := ttk / maxf(1, wins)
			var avg_lost := lost / trials
			var note := ""
			if stalls > 0:
				note = "  FLAG travou(%d)" % stalls
			if died > trials * 0.3 or avg_lost > 0.75:
				note += "  FLAG difícil"
			elif avg_ttk > (25.0 if chain == 1 else 12.0):
				note += "  FLAG lento"
			elif avg_ttk < 3.0 and avg_lost < 0.08:
				note += "  FLAG trivial"
			if note != "":
				flags += 1
			print("DUEL %-18s %-20s nv=%-2d vitorias=%d/%d mortes=%d ttk=%.1fs vida_perdida=%.0f%%%s" % [mon_id, mid, md.level, wins, trials, died, avg_ttk, avg_lost * 100.0, note])
