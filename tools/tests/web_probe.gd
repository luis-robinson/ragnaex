extends Node
## Sonda da teia: o que um bot de cada build ganha da teia (soma do tree_bonus) e quanto isso muda os stats,
## num nível (-- --level=30). Uso: --headless --path . tools/tests/web_probe.tscn -- [--level=30]

func _ready() -> void:
	Sim.running = false
	Sim.load_map(GameData.maps[GameData.town_map_id()])
	var lv := int(DevArgs.value("--level", "30"))
	for cid in GameData.classes:
		var cls: ClassDef = GameData.classes[cid]
		for b in cls.builds:
			var e: SimEntity = Sim.spawn_bot(cls, "W", "city_aldara", Vector3(0, 0, 8), lv)
			e.brain = null
			e.build_id = b["id"]
			Sim._gear_bot(e)
			Sim._skill_bot(e)
			var with_atk := maxf(e.stats.patk, e.stats.matk)
			var with_hp := e.stats.max_hp
			var bonus := e.tree_bonus.duplicate()
			e.tree_bonus = {}
			e.recompute_stats()
			var no_atk := maxf(e.stats.patk, e.stats.matk)
			var no_hp := e.stats.max_hp
			var attrs := {}
			for k in bonus:
				if str(k).begins_with("attr_"):
					attrs[k] = int(bonus[k])
			print("WEB %s/%s nós=%d atk x%.2f hp x%.2f attrs=%s" % [cid, b["id"], e.tree.size(), with_atk / maxf(1, no_atk), with_hp / maxf(1, no_hp), attrs])
			Sim.despawn(e)
	print("WEB_END")
	get_tree().quit()
