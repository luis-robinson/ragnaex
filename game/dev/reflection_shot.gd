extends RefCounted
## Revisão do Reflexo Vaidoso (GDD ato3-excesso-45-50: silhueta no tom de quem olha):
## `-- --autostart=<c> --preset=45 --reflection_shot=<pasta>`. Três Reflexos parados na costa: um mirando um
## Elementalista, um mirando um Berserker, um sem alvo (azul-cinza). Grava <pasta>/reflection_far.png e _close.png e sai.

const PAIRS := [["elementalist", -3.6], ["berserker", 0.0], ["", 3.6]]     # classe de quem olha ("" = sem alvo), x

static func run(runner: Node, main: Node, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var p: SimEntity = Sim.player
	p.brain = null
	Sim._change_map(p, "field_coast", Vector3(4, 0, 6))
	await runner.get_tree().create_timer(1.0).timeout
	for e in Sim.map_entities("field_coast").duplicate():
		if e.kind == SimEntity.Kind.MONSTER:
			Sim.despawn(e)
	Sim.maps["field_coast"]["spawners"].clear()
	var aims: Array = []                            # [reflexo, id do alvo]: a sim larga alvo de quem não tem cérebro
	for pair in PAIRS:
		var at: Vector3 = p.position + Vector3(float(pair[1]), 0, 1.4)      # entre o jogador e a câmera
		var r := Sim.spawn_monster(GameData.monsters["vain_reflection"], "field_coast", at)
		r.brain = null
		r.facing = 0.0                               # vidro virado para a câmera
		if str(pair[0]) != "":
			var b := Sim.spawn_bot(GameData.classes[str(pair[0])], "Olha" + str(pair[0]), "field_coast", at + Vector3(1.1, 0, -1.6), 45)      # atrás e ao lado: não tapa o vidro
			b.brain = null
			r.aggro_target = b.id                   # só para a foto: quem o Reflexo encara
			aims.append([r, b.id])
			print("REFLECTION_SHOT x=%s alvo=%s tom=%s" % [pair[1], pair[0], EntityView.reflection_tone(b).to_html(false)])
	for shot in [["far", 13.0], ["close", 9.5]]:
		main.camera.distance = float(shot[1])
		for _f in 120:
			for a in aims:
				(a[0] as SimEntity).aggro_target = int(a[1])
			await runner.get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := dir.path_join("reflection_%s.png" % shot[0])
		runner.get_viewport().get_texture().get_image().save_png(path)
		print("REFLECTION_SHOT " + path)
	runner.get_tree().quit()
