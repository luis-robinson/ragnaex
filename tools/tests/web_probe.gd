extends Node
## Sonda da teia: o que um bot de cada build ganha da teia (soma do tree_bonus) e quanto isso muda os stats,
## num nível (-- --level=30). Uso: --headless --path . tools/tests/web_probe.tscn -- [--level=30]

func _ready() -> void:
	Sim.running = false
	Sim.load_map(GameData.maps[GameData.town_map_id()])
	var lv := int(DevArgs.value("--level", "30"))
	var sum_atk := 0.0
	var sum_hp := 0.0
	var n := 0
	for cid in GameData.classes:
		var cls: ClassDef = GameData.classes[cid]
		for b in cls.builds:
			var r := WebGain.measure(Sim, cls, b["id"], lv)
			sum_atk += r["atk"]
			sum_hp += r["hp"]
			n += 1
			print("WEB %s/%s nós=%d atk x%.2f hp x%.2f atk*hp x%.2f attrs=%s" % [cid, b["id"], r["nodes"], r["atk"], r["hp"], r["atk"] * r["hp"], r["attrs"]])
	print("WEB média atk x%.2f (alvo %s) hp x%.2f (alvo %s); por build atk*hp em %s" % [sum_atk / n, Balance.WEB_GAIN_ATK, sum_hp / n, Balance.WEB_GAIN_HP, Balance.WEB_GAIN_BUILD])
	print("WEB_END")
	get_tree().quit()
