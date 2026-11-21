extends Node
## Teste de jogo de uma faixa de nível (padrão 10-20): auditoria das quests e duelos de bot contra cada monstro da faixa.
##   godot --headless --path . tools/tests/band_probe.tscn -- [--from=10] [--to=20] [--trials=6] [--only=audit|duel] [--mob=<id>,...] [--class=<id>,...] [--build=<id>,...] [--why]
## AUDIT: quest sem NPC, alvo que não nasce em mapa nenhum, nível do alvo fora da quest, item de coleta sem fonte, abates esperados.
## DUEL <monstro> nv=N vitorias=V/T ttk=Ss vida_perdida=P% (bot do nível do monstro, classes se revezam; CHAIN monstros
##   seguidos sem descanso nem poção: ttk = média por monstro; vida perdida = o ponto mais baixo da caçada).
##   FLAG difícil: vitórias < 70% ou vida perdida > 75%; FLAG lento: ttk > 25 s; FLAG trivial: ttk < 3 s e vida perdida < 8%.
## SOAK (--soak=<mapa> [--no_raid]): o mapa sozinho, sem jogador, 8 min; conta as entidades por tipo a cada minuto (vazamento).
## PACK (--pack [--no_focus] [--party=1..4] [--level=37] [--trials=N] [--why]): grupo de 4 bots nv 37 contra um bando da Horda nas Estepes (recrutas, Guerreiro,
##   Agitador, troll): tempo para limpar, mortes, em que ordem o Agitador/troll caíram (foco dos bots, GDD AC-20).

const DT := 1.0 / 20.0
const LIMIT := 45.0
const CHAIN := 4              # monstros seguidos por caçada
const ELITE_HP := 1500.0      # monstro com mais vida que isto é elite: luta sozinho (1 por caçada)
const BAND_MAPS := ["field_forest", "dg_ninho", "elf_city", "dg_coracao", "dg_catacumbas", "dg_catacumbas_trono", "dg_pedreira", "dg_pedreira_coracao", "field_ruins", "fort_ghoul", "fort_bones", "fort_frost", "lich_citadel", "field_coast", "field_steppe", "fort_trolls", "fort_fire", "fort_war", "dg_goblin", "field_kharzun", "field_crab_beach"]

var _trace := false
var _trace_last := ""
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
		if a == "--trace": _trace = true
		if a.begins_with("--seed="): Sim.rng.seed = int(a.get_slice("=", 1))   # semente fixa por padrão: pedaços com sementes diferentes
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--soak="):
			_soak(a.get_slice("=", 1))
			get_tree().quit()
			return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--late_"):          # --late_<papel>=hp:1.2,startup:0.6,cooldown:0.8 — experimenta o fator 35+ sem mexer no Balance
			var role := a.get_slice("=", 0).trim_prefix("--late_")
			for kv in a.get_slice("=", 1).split(","):
				var k := kv.get_slice(":", 0)
				var v := float(kv.get_slice(":", 1))
				for md: MonsterDef in GameData.monsters.values():
					if md.stat_role != role or md.level < Balance.HORDE_ATK_35_LEVEL or md.is_boss:
						continue
					match k:
						"hp": md.hp *= v
						"startup": md.attack_startup *= v
						"cooldown": md.attack_cooldown *= v
						"skill_delay": md.skill_delay = v
	if OS.get_cmdline_user_args().has("--hits"):
		_hits()
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--pack"):
		BotBrain.focus_enabled = not OS.get_cmdline_user_args().has("--no_focus")
		_pack(trials)
		get_tree().quit()
		return
	if only != "duel":
		_audit()
	if only != "audit":
		_duels(trials)
	print("BAND_END flags=%d" % flags)
	get_tree().quit()

## --hits: golpe básico (poder 1, sem crítico) de cada monstro da faixa num bot do nível dele, em % da vida, por classe,
## e a DEF física do bot. Mostra quem bate no piso da DEF (dano "trivial" que não sobe com ATK).
func _hits() -> void:
	var cls := ["paladin", "berserker", "bishop", "druid", "ranger", "assassin", "elementalist", "necromancer"]
	if not Sim.maps.has("city_aldara"):
		Sim.load_map(GameData.maps["city_aldara"])
	for mon_id in GameData.monsters:
		var md: MonsterDef = GameData.monsters[mon_id]
		if md.is_boss or md.level < lv_from or md.level > lv_to or md.xp <= 0:
			continue
		var tot := 0.0
		var line := ""
		for cid in cls:
			var bot = Sim.spawn_bot(GameData.classes[cid], "Golpe", "city_aldara", Vector3(80, 0, 80), md.level)
			var mob = Sim.spawn_monster(md, "city_aldara", Vector3(82, 0, 80))
			var raw: float = maxf(mob.stats.patk - bot.stats.pdef * Balance.DEF_FACTOR, mob.stats.patk * 0.15)
			var pct: float = 100.0 * raw / bot.stats.max_hp
			tot += pct
			line += " %s=%.1f/%d" % [cid.substr(0, 3), pct, int(bot.stats.pdef)]
			Sim.despawn(bot)
			Sim.despawn(mob)
		print("HITS %-18s nv=%-2d atk=%-5.0f media=%.2f%% %s" % [mon_id, md.level, md.atk, tot / cls.size(), line])

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

## --build=<build>[,...]: nos duelos, o bot da classe usa essa build (se a classe a tiver); "" = a sorteada.
func _arg_build(cid: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--build="):
			for bid in a.get_slice("=", 1).split(","):
				if not GameData.classes[cid].build_by_id(bid).is_empty():
					return bid
	return ""

func _duels(trials: int) -> void:
	var src := _sources()
	var classes: Array = GameData.classes.keys()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--class="):          # só essas classes se revezam nos duelos (ex.: --class=assassin,ranger)
			classes = Array(a.get_slice("=", 1).split(","))
	Sim.load_map(GameData.maps[GameData.town_map_id()])
	var seen := {}
	var only_mobs: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mob="):
			only_mobs = Array(a.get_slice("=", 1).split(","))
	var jobs: Array = []
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
			jobs.append([mid, sp])
	# arena de teste (só da sonda): monstro da faixa sem spawner em mapa nenhum (ex.: Kharzun 40-45 antes do WP5) duela
	# num ponto andável conhecido das Estepes; quando o mapa dele existir, o spawner de verdade ganha (seen).
	var arena: Dictionary = {}
	for sp in GameData.maps["field_steppe"].spawners:
		if sp["monster_id"] == "troll":
			arena = sp
	for mon_id in GameData.monsters:
		var md: MonsterDef = GameData.monsters[mon_id]
		if arena.is_empty() or seen.has(mon_id) or md.is_boss or md.xp <= 0 or md.level < lv_from or md.level > lv_to + 1 or md.stat_role == "":
			continue
		if not only_mobs.is_empty() and not (mon_id in only_mobs):
			continue
		seen[mon_id] = true
		jobs.append(["field_steppe", {"monster_id": mon_id, "pos": arena["pos"], "radius": 4.0, "arena": true}])
	for job in jobs:
		var mid: String = job[0]
		var sp: Dictionary = job[1]
		var m: Dictionary = Sim.maps[mid]
		var mon_id: String = sp["monster_id"]
		var md: MonsterDef = GameData.monsters[mon_id]
		if true:
			var wins := 0
			var ttk := 0.0
			var lost := 0.0
			var chain := 1 if md.hp >= ELITE_HP else CHAIN
			var died := 0
			var stalls := 0
			var blows := 0                            # golpes que tiraram vida do bot (todos os monstros da caçada)
			var first_sum := 0.0                      # s até o 1º golpe de cada monstro que acertou
			var first_n := 0
			for trial in range(trials):
				for e in m["entities"].duplicate():
					if e.kind != SimEntity.Kind.NPC:
						Sim.despawn(e)
				var cid: String = classes[(trial * 5 + mon_id.length()) % classes.size()]
				var area: float = minf(float(sp.get("radius", 4.0)), 4.0)       # todos dentro da área do spawner (sala de verdade)
				var bot = Sim.spawn_bot(GameData.classes[cid], "Duelo", mid, Sim.random_walkable(GameData.maps[mid], sp["pos"], area), md.level)
				var want_build := _arg_build(cid)
				if want_build != "" and bot.build_id != want_build:      # --build=<build>: só essa build da classe
					bot.build_id = want_build
					Sim._gear_bot(bot)
					Sim._skill_bot(bot)
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
					var hit_once := false
					while tk < LIMIT and mob.is_alive() and bot.is_alive() and bot.map_id == mid:
						var hp0: float = bot.hp
						Sim.tick(DT)
						tk += DT
						if _trace and k == 0:              # --trace: estado do 1º monstro da caçada a cada mudança (por que não acerta)
							var tr := "%s/%s d=%.1f cd=%.2f deb=%s bot=%s" % [SimEntity.State.keys()[mob.state], mob.current_skill.id if mob.current_skill else "-", mob.position.distance_to(bot.position) - bot.radius,
								mob.basic_cd, ",".join(mob.debuffs.map(func(d): return str(d.get("kind", "?")))), SimEntity.State.keys()[bot.state]]
							if tr.get_slice(" ", 0) + tr.get_slice(" ", 3) != _trace_last or bot.hp < hp0 - 0.5:
								print("    T %s %.2f %s%s botpos=%s mobpos=%s sh=%.0f if=%.2f bskill=%s" % [cid, tk, tr, (" HIT%.1f%%" % (100.0 * (hp0 - bot.hp) / bot.stats.max_hp)) if bot.hp < hp0 - 0.5 else "", str(bot.position.snapped(Vector3.ONE * 0.1)),
									str(mob.position.snapped(Vector3.ONE * 0.1)), bot.shield_hp, bot.iframe_left, bot.current_skill.id if bot.current_skill else "-"])
								_trace_last = tr.get_slice(" ", 0) + tr.get_slice(" ", 3)
						if bot.hp < hp0 - 0.5:
							blows += 1
							if not hit_once:
								hit_once = true
								first_sum += tk
								first_n += 1
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
			print("DUEL %-18s %-20s nv=%-2d vitorias=%d/%d mortes=%d ttk=%.1fs vida_perdida=%.0f%% golpes/monstro=%.2f 1o_golpe=%.1fs%s" % [mon_id, mid + (" (arena)" if sp.get("arena", false) else ""), md.level, wins, trials, died, avg_ttk, avg_lost * 100.0,
				float(blows) / maxf(1.0, trials * chain), first_sum / maxf(1.0, first_n), note])

var _pack_n := 4
var _pack_lv := 37
const PACK := ["orc_recruit", "orc_recruit", "orc_warrior", "goblin_agitator", "troll"]
const PACK_COMP := [["paladin", "guardiao"], ["berserker", "executor"], ["elementalist", "fogo"], ["bishop", "sacerdote"]]

## Bando da Horda contra um grupo de 4 bots (foco no Agitador / troll com fogo).
func _pack(trials: int) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--party="): _pack_n = int(a.get_slice("=", 1))
		if a.begins_with("--level="): _pack_lv = int(a.get_slice("=", 1))
	var mid := "field_steppe"
	Sim.load_map(GameData.maps[GameData.town_map_id()])
	var m: Dictionary = Sim.load_map(GameData.maps[mid])
	m["spawners"].clear()
	var at: Vector3 = GameData.maps[mid].spawners[8]["pos"]    # acampamento de guerreiros, longe do posto
	var clear_t := 0.0
	var wins := 0
	var deaths := 0
	var agit_rank := 0.0
	var troll_rank := 0.0
	for trial in range(trials):
		for e in m["entities"].duplicate():
			if e.kind != SimEntity.Kind.NPC:
				Sim.despawn(e)
		m["hazards"] = []
		var bots: Array = []
		for i in mini(_pack_n, PACK_COMP.size()):
			var pc: Array = PACK_COMP[i]
			var b = Sim.spawn_bot(GameData.classes[pc[0]], "G%d" % i, mid, Sim.random_walkable(GameData.maps[mid], at + Vector3(6 + i, 0, 0), 1.0), _pack_lv)
			if b.build_id != pc[1]:
				b.build_id = pc[1]
				Sim._gear_bot(b)
				Sim._skill_bot(b)
			b.brain.state = BotBrain.S.TOWN_IDLE
			b.brain.timer = 999.0
			bots.append(b)
		for i in range(1, bots.size()):
			Sim.party_invite(bots[0], bots[i])
			Sim.party_accept(bots[i])
		var mobs: Array = []
		for i in PACK.size():
			var o = Sim.spawn_monster(GameData.monsters[PACK[i]], mid, Sim.random_walkable(GameData.maps[mid], at + Vector3(-1.5 * i + 2.0, 0, (trial % 3) - 1.0), 1.0))
			o.aggro_target = bots[0].id
			o.aggro_timer = 5.0
			mobs.append(o)
		var t := 0.0
		var order: Array = []
		while t < 90.0 and bots.any(func(b): return b.is_alive()):
			Sim.tick(DT)
			t += DT
			for o in mobs:
				if not o.is_alive() and not (o in order):
					order.append(o)
					if trial == 0 and OS.get_cmdline_user_args().has("--why"):
						print("    %.2fs morreu %s por %s (pos %s)" % [t, o.monster_def.id, Sim.entities[o.last_damage_from].name if Sim.entities.has(o.last_damage_from) else "?", str(o.position)])
			if order.size() == mobs.size():
				break
		if trial == 0 and OS.get_cmdline_user_args().has("--why"):
			print("  t0: hp bando %s  atk bots %s" % [str(mobs.map(func(o): return roundi(o.stats.max_hp))), str(bots.map(func(b): return roundi(b.stats.patk + b.stats.matk)))])
		var dead := bots.filter(func(b): return not b.is_alive()).size()
		deaths += dead
		if order.size() == mobs.size():
			wins += 1
			clear_t += t
		agit_rank += order.find(mobs[3]) + 1 if mobs[3] in order else 6
		troll_rank += order.find(mobs[4]) + 1 if mobs[4] in order else 6
		for b in bots:
			Sim.party_leave(b)
	print("PACK foco=%s vitorias=%d/%d limpa=%.1fs mortes=%.2f agitador_cai=%.1fº troll_cai=%.1fº" % [str(BotBrain.focus_enabled), wins, trials,
		clear_t / maxf(1, wins), float(deaths) / trials, agit_rank / trials, troll_rank / trials])

func _soak(mid: String) -> void:
	Sim.load_map(GameData.maps[GameData.town_map_id()])
	var m: Dictionary = Sim.load_map(GameData.maps[mid])
	if OS.get_cmdline_user_args().has("--no_raid"):
		for ri in RaidSystem.routes(m["def"]).size():
			RaidSystem.state(m, ri)["timer"] = INF
		RaidSystem.sync_state(m)["timer"] = INF      # Bastião: relógio único dos três lados
	for step in 8:
		for i in 1200:
			Sim.tick(DT)
		var kinds := {}
		for o in m["entities"]:
			var key: String = o.monster_def.id if o.monster_def else SimEntity.Kind.keys()[o.kind]
			kinds[key] = int(kinds.get(key, 0)) + 1
		print("SOAK t=%ds n=%d %s" % [(step + 1) * 60, (m["entities"] as Array).size(), str(kinds)])
