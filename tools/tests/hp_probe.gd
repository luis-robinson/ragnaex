extends Node
## Sonda de vida: HP máximo, redução de dano, esquiva e HP efetivo de um bot de cada build (equipamento comum do nível +
## teia como o bot gasta), nos níveis pedidos. EHP = HP / ((1 - redução) x (1 - esquiva)). Também o ATK/MATK e quantos
## notáveis de sobrevivência/dano da classe (TreeCatalog: nó com "role_note") o bot comprou.
## Uso: --headless --path . tools/tests/hp_probe.tscn -- [--levels=10,20,30,45] [--class=assassin,...]

func _ready() -> void:
	Sim.running = false
	Sim.load_map(GameData.maps[GameData.town_map_id()])
	var levels: Array = []
	for s in DevArgs.value("--levels", "10,20,30,45").split(","):
		levels.append(int(s))
	var only := DevArgs.value("--class", "")
	if DevArgs.has("--notes"):           # onde ficam os notáveis de papel: raio e nós do início até eles
		for cid in GameData.trees:
			var nodes: Dictionary = GameData.trees[cid]["nodes"]
			var fake := SimEntity.new()
			fake.level = 30
			fake.tree = {GameData.trees[cid]["start"]: true}
			var by_branch := {}
			for nid in nodes:
				if nodes[nid]["kind"] == "notable" and int(nodes[nid]["level"]) <= 30:
					var br := str(nodes[nid]["branch"])
					by_branch[br] = int(by_branch.get(br, 0)) + 1
			print("NOTES %s notáveis por ramo %s" % [cid, by_branch])
			for nid in nodes:
				var n: Dictionary = nodes[nid]
				if n.has("role_note"):
					print("NOTES %s %s %s r=%.1f caminho=%d %s" % [cid, n["role_note"], n["name"], (n["pos"] as Vector2).length(), ProgressionSystem._path_to(fake, nodes, nid).size(), n["stats"]])
	for lv in levels:
		print("HP nível %d" % lv)
		for cid in GameData.classes:
			if only != "" and not (cid in only.split(",")):
				continue
			var cls: ClassDef = GameData.classes[cid]
			for b in cls.builds:
				var r := measure(cls, b["id"], lv)
				print("HP %2d %-12s %-15s hp=%5d dr=%4.1f eva=%4.1f ehp=%5d atk=%5d notes=%d" % [lv, cid, b["id"], r["hp"], r["dr"], r["eva"], r["ehp"], r["atk"], r["notes"]])
	print("HP_END")
	get_tree().quit()

func measure(cls: ClassDef, build_id: String, lv: int) -> Dictionary:
	var e: SimEntity = Sim.spawn_bot(cls, "H", "city_aldara", Vector3(0, 0, 8), lv)
	e.brain = null
	e.build_id = build_id
	Sim._gear_bot(e)
	Sim._skill_bot(e)
	var st: Stats = e.stats
	var dr := minf(st.dr_pct, Balance.DR_CAP)
	var eva := st.evasion
	var notes := 0
	var tr: Dictionary = ProgressionSystem.tree_of(Sim, e)
	for nid in e.tree:
		if tr["nodes"].has(nid) and tr["nodes"][nid].has("role_note"):
			notes += 1
	var out := {"hp": st.max_hp, "dr": dr, "eva": eva, "ehp": st.max_hp / ((1.0 - dr / 100.0) * (1.0 - eva / 100.0)),
		"atk": maxf(st.patk, st.matk), "notes": notes}
	Sim.despawn(e)
	return out
