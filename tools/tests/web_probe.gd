extends Node
## Sonda da teia: o que um bot de cada build ganha da teia (soma do tree_bonus) e quanto isso muda os stats,
## num nível (-- --level=30). Uso: --headless --path . tools/tests/web_probe.tscn -- [--level=30] [--dump=<arquivo>]

func _ready() -> void:
	Sim.running = false
	Sim.load_map(GameData.maps[GameData.town_map_id()])
	var lv := int(DevArgs.value("--level", "30"))
	var dump := DevArgs.value("--dump", "")
	if dump != "":                      # ids, nível, custo, posição e stats de cada nó (comparar teia antes/depois: diff)
		var f := FileAccess.open(dump, FileAccess.WRITE)
		for cid in GameData.trees:
			var nd: Dictionary = GameData.trees[cid]["nodes"]
			var ids: Array = nd.keys()
			ids.sort()
			for nid in ids:
				var n: Dictionary = nd[nid]
				f.store_line("%s %s lv%d c%d (%.3f,%.3f) %s" % [nid, n["kind"], int(n["level"]), int(n["cost"]), n["pos"].x, n["pos"].y, n["stats"]])
		f.close()
	var sum_atk := 0.0
	var sum_hp := 0.0
	var n := 0
	print("WEB nível %d: %d pontos" % [lv, ProgressionSystem.points_for_level(lv)])
	for cid in GameData.classes:
		var cls: ClassDef = GameData.classes[cid]
		var tr: Dictionary = GameData.trees[cid]
		var cost := 0
		var kinds := {}
		var radius := 0.0
		for nid in tr["nodes"]:
			var nd: Dictionary = tr["nodes"][nid]
			if nd["kind"] in ["start", "pick"]:
				continue
			kinds[nd["kind"]] = int(kinds.get(nd["kind"], 0)) + 1
			cost += int(nd["cost"]) * (Balance.MASTERY_MAX if nd["kind"] == "mastery" else 1)
			radius = maxf(radius, (nd["pos"] as Vector2).length())
		print("WEB %s: custo total %d, raio %.1f, nós %s" % [cid, cost, radius, kinds])
		for b in cls.builds:
			var r := WebGain.measure(Sim, cls, b["id"], lv)
			sum_atk += r["atk"]
			sum_hp += r["hp"]
			n += 1
			print("WEB %s/%s nós=%d atk x%.2f hp x%.2f atk*hp x%.2f sobra=%d gasto=%s attrs=%s" % [cid, b["id"], r["nodes"], r["atk"], r["hp"], r["atk"] * r["hp"], r["left"], r["spent"], r["attrs"]])
	var band: Dictionary = Balance.WEB_GAIN_LATE.get(lv, {"atk": Balance.WEB_GAIN_ATK, "hp": Balance.WEB_GAIN_HP, "build": Balance.WEB_GAIN_BUILD})
	print("WEB média atk x%.2f (alvo %s) hp x%.2f (alvo %s); por build atk*hp em %s" % [sum_atk / n, band["atk"], sum_hp / n, band["hp"], band["build"]])
	print("WEB_END")
	get_tree().quit()
