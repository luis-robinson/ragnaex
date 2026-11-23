extends Node
## Roteamento de clipes (pacote C1, 2026-11-23): imprime o clipe lógico que cada skill de cada build toca com a arma da
## build (`EntityView.clip_for_skill`) e o clipe real que um kit tocaria hoje (`EntityView.CLIP_FALLBACK` quando o kit
## não tem o clipe novo). Uso: --headless --path . tools/tests/clip_route_probe.tscn -- [--class=necromancer,...] [--out=<csv>]
## Linha: "ROUTE <classe> <build> <skill> kind target vfx arma -> clipe [-> reserva]". Só mede, não julga.

func _ready() -> void:
	var only: Array = []
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--class="):
			only = a.substr(8).split(",")
		elif a.begins_with("--out="):
			out = a.substr(6)
	var rows: Array[String] = ["class,build,skill,kind,target,vfx,weapon,offhand,clip,fallback,forced"]
	var counts := {}
	for cid in GameData.classes:
		if not only.is_empty() and not (cid in only):
			continue
		var c: ClassDef = GameData.classes[cid]
		for b in c.builds:
			var w: String = b["main"][0]
			var off: String = b["off"][0] if b["off"].size() > 0 else ""
			for sid in c.skill_ids:
				var s: SkillDef = GameData.skills[sid]
				if not (s.build in [b["id"], ""]):
					continue
				var clip := EntityView.clip_for_skill(s, w, off, 0)
				var fb := EntityView.fallback_clip(clip)
				var kind: String = SkillDef.Kind.keys()[s.kind]
				var tgt: String = SkillDef.Target.keys()[s.target]
				print("ROUTE %s %s %s %s %s %s %s -> %s%s%s" % [cid, b["id"], sid, kind, tgt, s.vfx, w, clip,
					(" -> " + fb) if fb != clip else "", " (clip)" if s.clip != "" else ""])
				rows.append("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s" % [cid, b["id"], sid, kind, tgt, s.vfx, w, off, clip, fb, s.clip != ""])
				counts[clip] = int(counts.get(clip, 0)) + 1
	var keys := counts.keys()
	keys.sort()
	for k in keys:
		print("COUNT %s %d" % [k, counts[k]])
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f:
			f.store_string("\n".join(rows) + "\n")
	get_tree().quit()
