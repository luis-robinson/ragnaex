class_name WebGain
## Quanto a teia rende para um bot da build no nível `lv`: {atk, hp, nodes, attrs} (razões com/sem tree_bonus).
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
	e.tree_bonus = {}
	e.recompute_stats()
	var no_atk := maxf(e.stats.patk, e.stats.matk)
	var no_hp := e.stats.max_hp
	sim.despawn(e)
	var attrs := {}
	for k in bonus:
		if str(k).begins_with("attr_"):
			attrs[k] = int(bonus[k])
	return {"atk": with_atk / maxf(1.0, no_atk), "hp": with_hp / maxf(1.0, no_hp), "nodes": nodes, "attrs": attrs}
