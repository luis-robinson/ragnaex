extends Node
## Sonda do Mestre de Skills (ranks por ouro + materiais, plano tidy-painting-biscuit 2026-11-18). Sem tela.
##   godot --headless --path . tools/tests/trainer_probe.tscn -- [--spots] [--economy]
## --spots: por hub, o centro, os NPCs de serviço e o Mestre (posição, folga até o colisor mais perto, NPC mais perto).
## --economy: por faixa, quem derruba cada material de rank (chance média por abate) e quanto custa levar as 6 skills da
## barra da build ao rank 3 (ouro e materiais), contra o ouro das quests da faixa.

const HUBS := ["city_aldara", "field_forest", "elf_city", "field_ruins", "city_port", "field_kharzun"]

func _ready() -> void:
	await get_tree().process_frame
	Sim.running = false
	if DevArgs.has("--spots"):
		_spots()
	if DevArgs.has("--economy"):
		_economy()
	if DevArgs.has("--pick"):
		_pick()
	get_tree().quit()

## Ponto livre mais perto da âncora (folga >= 1,0 m, 2,5 m de todo NPC, 1,5 m de ponto de bot, fora da faixa das bancas de Aldara).
const ANCHORS := {"city_aldara": [-13.0, -5.0], "field_forest": [-13.0, -1.0], "elf_city": [28.0, 80.0], "field_ruins": [-9.0, -22.0],
	"city_port": [4.0, -5.0], "field_kharzun": [-12.0, -3.0]}
## --anchors=mapa:x:z,mapa:x:z troca as âncoras (outro NPC de serviço; ex. Intendente das Caçadas).
func _pick() -> void:
	var anchors: Dictionary = ANCHORS
	if DevArgs.flag("--anchors"):
		anchors = {}
		for t in DevArgs.value("--anchors").split(","):
			var q := t.split(":")
			anchors[q[0]] = [float(q[1]), float(q[2])]
	for mid in anchors:
		var def: MapDef = GameData.maps[mid]
		if not Sim.maps.has(mid):
			Sim.load_map(def)
		var a: Array = anchors[mid]
		var best := Vector3.INF
		var bd := INF
		for ix in range(-28, 29):
			for iz in range(-28, 29):
				var p := Vector3(float(a[0]) + ix * 0.25, 0.0, float(a[1]) + iz * 0.25)
				var d := Vector2(p.x - float(a[0]), p.z - float(a[1])).length()
				if d >= bd or not Sim.is_walkable(p, def, 1.0):
					continue
				if def.npcs.any(func(n): return (n["pos"] as Vector3).distance_to(p) < 2.5 or (n.has("route") and (n["route"] as Array).any(func(q): return Vector2(float(q[0]), float(q[1])).distance_to(Vector2(p.x, p.z)) < 1.5))):
					continue
				if def.bot_hangouts.any(func(h): return (h as Vector3).distance_to(p) < 1.5):
					continue
				if mid == "city_aldara" and p.length() < 15.0:
					continue
				best = p
				bd = d
		print("PICK %s (%.2f, %.2f) d=%.2f folga=%.1f" % [mid, best.x, best.z, bd, _clearance(def, best) if best != Vector3.INF else -1.0])

func _clearance(def: MapDef, p: Vector3) -> float:
	var r := 0.2
	while r < 4.0 and Sim.is_walkable(p, def, r):
		r += 0.1
	return r - 0.1

func _spots() -> void:
	for mid in HUBS:
		var def: MapDef = GameData.maps[mid]
		if not Sim.maps.has(mid):
			Sim.load_map(def)
		print("HUB %s center=(%.1f, %.1f) r=%.1f spawn=(%.1f, %.1f)" % [mid, def.town_center.x, def.town_center.z, def.town_radius, def.spawn_point.x, def.spawn_point.z])
		for n in def.npcs:
			var role := str(n.get("role", ""))
			if role in ["villager", "guard"] and not str(n["id"]).contains("trainer"):
				continue
			var p: Vector3 = n["pos"]
			var near := INF
			var near_id := ""
			for o in def.npcs:
				if o == n:
					continue
				var d := (o["pos"] as Vector3).distance_to(p)
				if d < near:
					near = d
					near_id = str(o["id"])
			print("  %-22s %-9s (%7.2f, %7.2f) folga=%.1f perto=%s %.1f m" % [n["id"], role, p.x, p.z, _clearance(def, p), near_id, near])

## Chance média por abate de cada material nos monstros comuns do mapa (spawners).
func _drops(def: MapDef) -> Dictionary:
	var out := {}
	var total := 0
	for sp in def.spawners:
		var m: MonsterDef = GameData.monsters.get(sp["monster_id"])
		if m == null or m.is_boss:
			continue
		total += int(sp["count"])
		for row in _rows(m):
			var iid := str(row.get("item", ""))
			out[iid] = float(out.get(iid, 0.0)) + float(row.get("chance", 0.0)) * (int(row.get("min", 1)) + int(row.get("max", 1))) * 0.5 * int(sp["count"])
	for k in out:
		out[k] = out[k] / maxf(1.0, total)
	return out

func _rows(m: MonsterDef) -> Array:
	var lt: LootTable = GameData.loot_tables.get(m.loot_table)
	return lt.entries if lt != null else []

func _economy() -> void:
	# quem derruba cada material de rank, por mapa
	for tier in Balance.SKILL_RANK_MATS.size():
		var mats: Array = Balance.SKILL_RANK_MATS[tier]
		for iid in mats:
			var where: Array = []
			for mid in GameData.maps:
				var dr := _drops(GameData.maps[mid])
				if float(dr.get(iid, 0.0)) > 0.0:
					where.append("%s %.2f" % [mid, float(dr[iid])])
			var mons: Array = []
			for mid2 in GameData.monsters:
				var m: MonsterDef = GameData.monsters[mid2]
				for row in _rows(m):
					if str(row.get("item", "")) == iid:
						mons.append("%s(L%d %.2f)" % [mid2, m.level, float(row.get("chance", 0.0))])
			print("MAT tier=%d %s (lv %d+) mapas=[%s]\n      monstros=%s" % [tier, iid, Balance.COMMON_TIER_LEVELS[tier], ", ".join(where), mons])
	# custo de levar as 6 skills da barra de cada build ao rank 3 no fim de cada faixa
	var bands := [[1, 10], [10, 20], [20, 30], [30, 40], [40, 45]]
	for b in bands:
		var lv: int = b[1]
		var worst_gold := 0
		var worst := ""
		var sum_gold := 0
		var n_builds := 0
		for cid in GameData.classes:
			var cd: ClassDef = GameData.classes[cid]
			for build in cd.builds:
				var skills: Array = (build.get("skills", []) as Array).filter(func(s): return GameData.skills.has(s) and not GameData.skills[s].ascension and GameData.skills[s].unlock_level <= lv)
				skills = skills.slice(0, 6)
				var gold := 0
				var e := SimEntity.new()
				e.level = lv
				for sid in skills:
					var s: SkillDef = GameData.skills[sid]
					for r in range(1, 4):
						if ProgressionSystem.rank_level(s, r) > lv:
							break
						var c := ProgressionSystem.rank_cost(e, sid, r)
						gold += int(c["gold"])
				# materiais (pior build)
				sum_gold += gold
				n_builds += 1
				if gold > worst_gold:
					worst_gold = gold
					worst = "%s/%s" % [cid, build.get("id", "?")]
		var qgold := 0
		for qid in GameData.quests:
			var q: QuestDef = GameData.quests[qid]
			if q.repeatable:
				continue
			if q.level_req >= b[0] and q.level_req < b[1]:
				qgold += q.reward_gold
		print("BAND %d-%d: rank<=3 nas 6 da barra: ouro médio %d, pior %d (%s); ouro de quests na faixa %d" % [b[0], b[1], sum_gold / maxi(1, n_builds), worst_gold, worst, qgold])
		_band_mats(b, lv)

## Materiais por build no fim da faixa (soma de todos os ranks <= 3 das 6 da barra), pior build.
func _band_mats(b: Array, lv: int) -> void:
	var worst := {}
	for cid in GameData.classes:
		var cd: ClassDef = GameData.classes[cid]
		for build in cd.builds:
			var skills: Array = (build.get("skills", []) as Array).filter(func(s): return GameData.skills.has(s) and not GameData.skills[s].ascension and GameData.skills[s].unlock_level <= lv)
			skills = skills.slice(0, 6)
			var need := {}
			var e := SimEntity.new()
			e.level = lv
			for sid in skills:
				var s: SkillDef = GameData.skills[sid]
				for r in range(1, 4):
					if ProgressionSystem.rank_level(s, r) > lv:
						break
					var c := ProgressionSystem.rank_cost(e, sid, r)
					for iid in c["items"]:
						need[iid] = int(need.get(iid, 0)) + int(c["items"][iid])
			for iid in need:
				worst[iid] = maxi(int(worst.get(iid, 0)), int(need[iid]))
	print("   materiais (pior build, por item): %s" % [worst])
