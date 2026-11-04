class_name LootTable
extends Resource

@export var id: String = ""
## entradas: {"item":"slime_gel","chance":0.6,"min":1,"max":2}
@export var entries: Array = []

func roll(rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	for e in entries:
		if rng.randf() <= float(e.get("chance", 1.0)):
			var n := rng.randi_range(int(e.get("min", 1)), int(e.get("max", 1)))
			out[e["item"]] = int(out.get(e["item"], 0)) + n
	return out
