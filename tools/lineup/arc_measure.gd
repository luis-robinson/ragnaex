extends SceneTree
## Mede a posição de ossos de um GLB quadro a quadro (lado do golpe, contato no chão) para as tabelas dos arcos
## (game/fx/weapon_arcs.gd: CLIP_ARC, DUAL_ARC, FORM_ARC). Modelo no espaço dele (x = +X do modelo, y para cima,
## z para a frente), 24 fps, quadros contados a partir de 1, antes de qualquer escala do jogo.
##   godot --headless --path . -s tools/lineup/arc_measure.gd -- --model=<glb sem .glb> --clip=<clipe>
##     [--bones=hand.R,hand.L] [--from=1] [--to=<último>] [--offset=x,y,z]
##   --offset: ponto no espaço do osso em vez da origem (ex.: a pata na ponta do osso da perna, 0,<comprimento>,0).
## Saída: uma linha "MEAS <modelo> <clipe> <osso>: fN(x,y,z) ..." por osso. Precisa esperar um quadro depois de pôr
## o modelo na árvore e depois de cada seek (sem isso lê a pose de repouso).

func _initialize() -> void:
	_go.call_deferred()

func _arg(name: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(name + "="):
			return a.substr(name.length() + 1)
	return def

func _go() -> void:
	var model := _arg("--model", "")
	var clip := _arg("--clip", "")
	var path := "res://assets/models/%s.glb" % model
	if model == "" or clip == "" or not ResourceLoader.exists(path):
		printerr("arc_measure: --model=<glb em assets/models, sem .glb> --clip=<clipe> obrigatórios (%s)" % path)
		quit(2)
		return
	var inst := (load(path) as PackedScene).instantiate()
	root.add_child(inst)
	await process_frame
	var aps := inst.find_children("*", "AnimationPlayer", true, false)
	var sks := inst.find_children("*", "Skeleton3D", true, false)
	if aps.is_empty() or sks.is_empty():
		printerr("arc_measure: %s sem AnimationPlayer/Skeleton3D" % model)
		quit(2)
		return
	var ap: AnimationPlayer = aps[0]
	var sk: Skeleton3D = sks[0]
	if not ap.has_animation(clip):
		printerr("arc_measure: %s não tem o clipe %s (%s)" % [model, clip, ", ".join(ap.get_animation_list())])
		quit(2)
		return
	var last := int(round(ap.get_animation(clip).length * 24.0)) + 1
	var f0 := int(_arg("--from", "1"))
	var f1 := mini(int(_arg("--to", str(last))), last)
	var off := Vector3.ZERO
	var ov := _arg("--offset", "").split(",")
	if ov.size() == 3:
		off = Vector3(float(ov[0]), float(ov[1]), float(ov[2]))
	for bn in _arg("--bones", "hand.R,hand.L").split(","):
		var bi := sk.find_bone(bn)
		if bi < 0:
			printerr("arc_measure: osso %s não existe" % bn)
			continue
		var line := "MEAS %s %s %s:" % [model, clip, bn]
		for f in range(f0, f1 + 1):
			ap.play(clip)
			ap.seek(float(f - 1) / 24.0, true)
			ap.advance(0.0)
			await process_frame
			var o := sk.get_bone_global_pose(bi) * off
			line += " f%d(%.2f,%.2f,%.2f)" % [f, o.x, o.y, o.z]
		print(line)
	inst.queue_free()
	quit()
