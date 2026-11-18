class_name WebGain
## Quanto a teia rende para um bot da build no nível `lv`: {atk, hp, nodes, attrs} (razões com/sem tree_bonus),
## left (pontos sobrando) e spent (pontos por tipo de nó).
## Usado por web_probe.tscn e por _check_web_strength (run_tests).

static func measure(sim, cls: ClassDef, build_id: String, lv: int) -> Dictionary:
	var e: SimEntity = sim.spawn_bot(cls, "W", "city_aldara", Vector3(0, 0, 8), lv)
	e.brain = null
	e.build_id = build_id
	sim._gear_bot(e)
	sim._skill_bot(e)
	var with_atk := maxf(e.stats.patk, e.stats.matk)
	var with_hp := e.stats.max_hp
	var bonus: Dictionary = e.tree_bonus.duplicate()
	var nodes: int = e.tree.size()
	var left: int = e.mastery_points
	var spent := {}                    # pontos por tipo de nó (+ "rank": soma dos ranks, fora da teia)
	var tr: Dictionary = ProgressionSystem.tree_of(sim, e)
	for nid in e.tree:
		var kind: String = tr["nodes"][nid]["kind"] if tr["nodes"].has(nid) else "?"
		if kind != "start":
			spent[kind] = int(spent.get(kind, 0)) + int(tr["nodes"][nid]["cost"])
	for sid in e.mastery:
		spent["rank"] = int(spent.get("rank", 0)) + int(e.mastery[sid])      # ranks de graça do bot (não gastam ponto; só informativo)
	e.tree_bonus = {}
	e.recompute_stats()
	var no_atk := maxf(e.stats.patk, e.stats.matk)
	var no_hp := e.stats.max_hp
	sim.despawn(e)
	var attrs := {}
	for k in bonus:
		if str(k).begins_with("attr_"):
			attrs[k] = int(bonus[k])
	return {"atk": with_atk / maxf(1.0, no_atk), "hp": with_hp / maxf(1.0, no_hp), "nodes": nodes, "attrs": attrs, "left": left, "spent": spent}
