extends Node
## Sonda dos escudos: ponto mais baixo por clipe (antes/depois da ponta que encolhe) e guarda montada contra a montaria.
##   --headless --path . tools/tests/shield_probe.tscn -- [--kits=paladin_male,bishop_male] [--samples=8] [--all]
## Linhas: LOW <kit> <estilo> pior antes -> depois (clipe), idle/corrida/guarda; RIDE <kit> <montaria> arestas que cruzam.
## --all lista todos os clipes que ainda passam do chão.

const MOUNTS := ["mob_horse", "mob_dire_wolf_mount"]

func _ready() -> void:
	Sim.running = false
	var kits: PackedStringArray = DevArgs.value("--kits", "paladin_male,paladin_female,bishop_male,bishop_female").split(",", false)
	var samples := int(DevArgs.value("--samples", "8"))
	for model in kits:
		var root := Node3D.new()
		add_child(root)
		var k := KitModel.create(model.get_slice("_", 1), Color.WHITE, 0.025, model.get_slice("_", 0))
		root.add_child(k)
		var styles: Array = ShieldProbe.shields_of(k).keys()
		styles.sort()
		var clips: Array = Array(k.anim.get_animation_list())
		var lows := ShieldProbe.ground_lows(k, styles, clips, samples)
		var worst_b := 0.0
		var worst_a := 0.0
		for st in styles:
			var per: Dictionary = lows[st]
			var wb := INF
			var wa := INF
			var wc := ""
			var still: Array = []
			for clip in per:
				if per[clip][0] < wb:
					wb = per[clip][0]
				if per[clip][1] < wa:
					wa = per[clip][1]
					wc = clip
				if per[clip][1] < 0.0:
					still.append("%s %.3f" % [clip, per[clip][1]])
			worst_b = minf(worst_b, wb)
			worst_a = minf(worst_a, wa)
			var tall: bool = st in KitModel.TALL_SHIELDS
			var run: String = "run_shield_tall" if tall else "run"
			var grd: String = "block_shield_tall" if tall else "block_shield"
			print("LOW %-14s %-10s %s pior %.3f -> %.3f (%s) idle %.3f -> %.3f corrida %.3f -> %.3f guarda %.3f -> %.3f abaixo do chao: %d clipes%s" % [
				model, st, "alto " if tall else "comum", wb, wa, wc, per["idle"][0], per["idle"][1], per[run][0], per[run][1], per[grd][0], per[grd][1],
				still.size(), (" " + str(still)) if DevArgs.has("--all") and not still.is_empty() else ""])
		print("LOW %s TOTAL pior antes %.3f, depois %.3f" % [model, worst_b, worst_a])
		RidePose.ensure_guard_clip(k.anim, k.skeleton)
		RidePose._guard_from(k.anim, k.skeleton, "block_ride_tall_old", "block_shield_tall")
		var tall_styles: Array = styles.filter(func(s): return s in KitModel.TALL_SHIELDS)
		for mname in MOUNTS:
			var m := FormModel.create_from("res://assets/models/%s.glb" % mname)
			if m == null:
				continue
			m.scale = Vector3.ONE * EntityView.HORSE_SCALE
			root.add_child(m)
			for mc in ["idle", "run"]:
				var now := ShieldProbe.mounted_crossings(k, m, tall_styles, RidePose.GUARD_CLIP_TALL, mc)
				var old := ShieldProbe.mounted_crossings(k, m, tall_styles, "block_ride_tall_old", mc)
				var bad_now := tall_styles.filter(func(s): return now[s] > 0)
				var bad_old := tall_styles.filter(func(s): return old[s] > 0)
				print("RIDE %-14s %-20s %-4s cruzam: antes %d de %d, depois %d %s" % [model, mname, mc, bad_old.size(), tall_styles.size(), bad_now.size(), str(bad_now)])
			k.transform = Transform3D.IDENTITY
			m.free()
		root.free()
	print("SHIELD_PROBE_END")
	get_tree().quit()
