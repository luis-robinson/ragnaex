extends RefCounted
## Revisão do dash na tela (DashGauge + vaga Shift da barra):
## `-- --autostart=<c> [--preset=N] --dash_shot=<pasta> [--dash_talent=<id da evolução>]`.
## Aperta Shift (todas as cargas) e grava <pasta>/<classe>_1_gap.png (só com 2+ cargas: logo após o 1º),
## <classe>_2_mid.png (recarga no meio), <classe>_3_ready.png (logo depois de voltar: brilho) e <classe>_4_idle.png (sumiu). Sai.

static func run(runner: Node, main: Node, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var p: SimEntity = Sim.player
	p.brain = null
	var tid := DevArgs.value("--dash_talent")
	if tid != "":
		p.talents[tid] = true                 # só para a foto: a evolução do dash comprada
	await runner.get_tree().create_timer(2.0).timeout
	Sim.sync()
	var dp: Dictionary = Sim.dash_params(p)
	var n := int(dp["charges"])
	var cls := p.class_def.id
	main.camera.distance = 16.0
	for i in range(n):
		_press(runner)
		await runner.get_tree().create_timer(0.08).timeout
		if i == 0 and n > 1:
			await _snap(runner, dir.path_join("%s_1_gap.png" % cls), p)
		await runner.get_tree().create_timer(Balance.DASH_CHARGE_WINDOW * 0.25 + 0.05).timeout
	Sim.sync()
	var total: float = Balance.DASH_COOLDOWN * float(dp["cooldown_mult"])
	while p.dash_cd > total * 0.5:
		await runner.get_tree().process_frame
		Sim.sync()
	await _snap(runner, dir.path_join("%s_2_mid.png" % cls), p)
	while p.dash_cd > 0.0:
		await runner.get_tree().process_frame
		Sim.sync()
	await runner.get_tree().create_timer(0.06).timeout
	await _snap(runner, dir.path_join("%s_3_ready.png" % cls), p)
	await runner.get_tree().create_timer(1.5).timeout
	await _snap(runner, dir.path_join("%s_4_idle.png" % cls), p)
	runner.get_tree().quit()

static func _press(runner: Node) -> void:
	for down in [true, false]:
		var ev := InputEventAction.new()
		ev.action = &"dash"
		ev.pressed = down
		Input.parse_input_event(ev)
		await runner.get_tree().process_frame

static func _snap(runner: Node, path: String, p: SimEntity) -> void:
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(path)
	Sim.sync()
	print("DASH_SHOT %s cd=%.2f used=%d" % [path, p.dash_cd, p.dash_charges_used])
