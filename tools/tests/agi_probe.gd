extends Node
## Sonda de AGI e esquiva: para cada build, um bot no nível (equipamento, teia, talentos e — do ASC_LEVEL em diante — a
## ascensão como os bots ganham) e imprime FOR/AGI/VIT/WILL/INT totais, a esquiva total e a parte que vem da AGI.
## Uso: --headless --path . tools/tests/agi_probe.tscn -- [--levels=20,30,40,45]

func _ready() -> void:
	Sim.running = false
	Sim.load_map(GameData.maps[GameData.town_map_id()])
	var levels: Array = Array(DevArgs.value("--levels", "20,30,40,45").split(","))
	for lv_s in levels:
		var lv := int(lv_s)
		var rows: Array = []
		for cid in GameData.classes:
			var cls: ClassDef = GameData.classes[cid]
			for b in cls.builds:
				var e: SimEntity = Sim.spawn_bot(cls, "A", GameData.town_map_id(), Vector3(0, 0, 8), lv)
				e.brain = null
				e.level = lv
				e.build_id = b["id"]
				if lv >= Balance.ASC_LEVEL:
					e.quests_completed.append("hx_asc_" + cid)      # ascensão como o bot do nível
				Sim._gear_bot(e)
				Sim._skill_bot(e)
				e.recompute_stats()
				var a: Dictionary = e.stats.attrs
				var agi_eva := Stats.agi_evasion(float(a["AGI"]) / Balance.ATTR_SCALE)
				rows.append([cid, b["id"], int(a["FOR"]), int(a["AGI"]), int(a["VIT"]), int(a["WILL"]), int(a["INT"]), e.stats.evasion, agi_eva, e.stats.weapon_type])
				Sim.despawn(e)
		rows.sort_custom(func(x, y): return int(x[3]) > int(y[3]))
		for r in rows:
			print("AGI lv%d %-12s %-12s FOR=%4d AGI=%4d VIT=%4d WILL=%4d INT=%4d esquiva=%5.1f%% (da AGI %4.1f%%) arma=%s" % [lv, r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9]])
	print("AGI_END")
	get_tree().quit()
