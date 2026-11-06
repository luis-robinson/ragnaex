class_name DevRunner
extends Node
## Modos de revisão e medição da linha de comando (`-- --autostart`, `--bag_shot`, `--tour`, `--soak`, `--perf`...).
## Só existe quando há argumentos depois de `--`; o Main chama `before_start`, `after_start`/`at_title` e `tick`.
## Pode mexer direto no estado da sim (montar cenas de revisão) — o jogo normal nunca passa por aqui.

var main: Node                    # game/main.gd

const TOURS := {
	"dg_gruta": [["entrada", Vector3(0, 0, 40)], ["salao", Vector3(-20, 0, 22)], ["chefe", Vector3(8, 0, -30)]],
	"dg_catacumbas": [["entrada", Vector3(0, 0, 40)], ["vestibulo", Vector3(0, 0, 22)], ["oeste", Vector3(-30, 0, 18)], ["capitao", Vector3(-24, 0, -32)], ["alcova", Vector3(30, 0, 40)], ["viuva", Vector3(24, 0, -32)], ["selo", Vector3(0, 0, -6)]],
	"dg_catacumbas_trono": [["galeria", Vector3(0, 0, 18)], ["trono", Vector3(0, 0, -14)]],
	"dg_coracao": [["entrada", Vector3(0, 0, 40)], ["raizes", Vector3(0, 0, 24)], ["seiva", Vector3(-30, 0, -8)], ["trono", Vector3(8, 0, -40)]],
	"dg_pedreira": [["entrada", Vector3(0, 0, 40)], ["mineiros", Vector3(0, 0, 26)], ["musgo", Vector3(-36, 0, 18)], ["ancestral", Vector3(-30, 0, -38)],
		["cristal", Vector3(36, 0, 18)], ["guardia", Vector3(30, 0, -38)], ["veio", Vector3(0, 0, -8)]],
	"dg_pedreira_coracao": [["galeria", Vector3(0, 0, 22)], ["coracao", Vector3(0, 0, -16)]],
	"dg_ninho": [["entrada", Vector3(0, 0, 40)], ["salao", Vector3(20, 0, 22)], ["chefe", Vector3(-8, 0, -30)]],
	"dg_cripta": [["entrada", Vector3(0, 0, 40)], ["salao", Vector3(-20, 0, 22)], ["chefe", Vector3(8, 0, -30)]],
	"field_forest": [["cristal_posto", Vector3(-2.5, 0, -1.5)], ["herborista", Vector3(-41, 0, 38)], ["cacador", Vector3(62, 0, -14)], ["emboscada", Vector3(38, 0, 88)], ["circulo", Vector3(-27, 0, -92)], ["ninho", Vector3(-60, 0, 86)], ["pedreira", Vector3(-74, 0, -26)],
		["hub", Vector3(0, 0, 5)], ["chegada", Vector3(-100, 0, 9)], ["ponte", Vector3(26, 0, -6)],
		["bandidos_portao", Vector3(52, 0, -40)], ["bandidos_centro", Vector3(66, 0, -56)], ["aranhas", Vector3(-50, 0, -50)],
		["ents", Vector3(56, 0, 54)], ["arvore_mae", Vector3(8, 0, -76)], ["pantano", Vector3(-30, 0, 66)],
		["borda_norte", Vector3(-18, 0, -104)], ["borda_leste", Vector3(94, 0, 25)]],
	"fort_ghoul": [["jardim", Vector3(-44, 0, 66)], ["chegada", Vector3(0, 0, 90)], ["estrada", Vector3(8, 0, 44)], ["posto_oeste", Vector3(-52, 0, 40)], ["posto_leste", Vector3(50, 0, 30)], ["portao", Vector3(0, 0, 4)], ["patio", Vector3(4, 0, -22)]],
	"fort_bones": [["chegada", Vector3(0, 0, 90)], ["estrada", Vector3(8, 0, 44)], ["posto_oeste", Vector3(-52, 0, 40)], ["posto_leste", Vector3(50, 0, 30)], ["portao", Vector3(0, 0, 4)], ["patio", Vector3(4, 0, -22)]],
	"fort_frost": [["chegada", Vector3(0, 0, 90)], ["estrada", Vector3(8, 0, 44)], ["posto_oeste", Vector3(-52, 0, 40)], ["posto_leste", Vector3(50, 0, 30)], ["portao", Vector3(0, 0, 4)], ["patio", Vector3(4, 0, -22)]],
	"lich_citadel": [["chegada", Vector3(0, 0, 90)], ["estrada", Vector3(8, 0, 44)], ["posto_oeste", Vector3(-52, 0, 40)], ["posto_leste", Vector3(50, 0, 30)], ["portao", Vector3(0, 0, 4)], ["patio", Vector3(4, 0, -22)]],
	"field_ruins": [["torre", Vector3(-66, 0, 24)], ["praca_catedral", Vector3(0, 0, 18)], ["mercado", Vector3(26, 0, 30)], ["quartel", Vector3(-26, 0, -30)], ["portao_oeste", Vector3(-46, 0, 0)],
		["portao_norte", Vector3(0, 0, -46)], ["portao_sul", Vector3(0, 0, 46)], ["front_carnical", Vector3(-76, 0, -6)], ["front_ossos", Vector3(8, 0, -80)],
		["front_gelo", Vector3(-6, 0, 80)], ["cripta", Vector3(20, 0, -80)], ["chegada", Vector3(94, 0, -5)], ["dragonete", Vector3(64, 0, 44)], ["capela", Vector3(90, 0, 18)],
		["ninho", Vector3(-66, 0, 36)], ["coveiro", Vector3(70, 0, -32)]],
	"elf_city": [["praca_arvore", Vector3(12, 0, 14)], ["mercado", Vector3(30, 0, 30)], ["quartel", Vector3(40, 0, -20)], ["jardim", Vector3(-30, 0, 30)],
		["anel_externo", Vector3(-42, 0, -4)], ["casas_norte", Vector3(-6, 0, -46)], ["portao_sul", Vector3(0, 0, 66)], ["chegada", Vector3(0, 0, 92)],
		["forte_matilha", Vector3(16, 0, -76)], ["forte_ninho", Vector3(-40, 0, -68)], ["forte_seiva", Vector3(76, 0, 14)], ["bosque", Vector3(60, 0, -50)],
		["poco", Vector3(-84, 0, 18)], ["cerco", Vector3(30, 0, 74)]],
}
const TOUR := [["anciao", Vector3(2, 0, -8)], ["lenhador", Vector3(-92, 0, -46)], ["eremita", Vector3(47, 0, 96)], ["covil", Vector3(-20, 0, -48)], ["marco", Vector3(-54, 0, 78)], ["gruta", Vector3(84, 0, -29)],
	["hub", Vector3(0, 0, 4)], ["portao_sul", Vector3(0, 0, 38)], ["lago", Vector3(6, 0, 58)],
	["bosque", Vector3(66, 0, 8)], ["colinas", Vector3(-4, 0, -68)], ["clareira", Vector3(-70, 0, 26)],
	["castelo", Vector3(28, 0, -38)], ["ponte", Vector3(-47, 0, 9)], ["fazenda", Vector3(-48, 0, 58)],
	["portal_floresta", Vector3(94, 0, -28)], ["portal_ruinas", Vector3(-94, 0, -26)],
	["borda_norte", Vector3(0, 0, -111)], ["borda_leste", Vector3(107, 0, 39)], ["borda_sudoeste", Vector3(-58, 0, 100)]]

var _smoke_test := false
var _smoke_t := 0.0
var _smoke_stage := 0
var _shot_path := ""
var _tour_dir := ""          # --tour=<pasta>: screenshots pelos POIs da zona e sai
var _tour_i := 0
var _tour_t := 0.0
var _tour_map := "city_aldara"
var showcase: Showcase = null     # --showcase=<classe|all> [--skill=<id>] --out=<pasta> [--check]: bancada de skills
var _soak_left := 0.0
var _soak_brain: BotBrain = null
var _soak_t := 0.0
var _soak_frames := 0
var _soak_ticks0 := 0
var _soak_worst := 0.0

var _soak_map := ""

## Antes do jogo: liga as chaves de medição e decide a partida automática. Devolve a classe ("" = tela inicial).
## `returning` = voltou ao menu pelo Esc: não repete o --autostart.
func before_start(returning: bool) -> String:
	var autostart := ""
	_shot_path = DevArgs.value("--screenshot")
	_tour_map = DevArgs.value("--tour_map", _tour_map)
	if DevArgs.flag("--tour"):
		_tour_dir = DevArgs.value("--tour")
		autostart = "paladin"
	if DevArgs.has("--autostart") or DevArgs.flag("--autostart"):
		autostart = DevArgs.value("--autostart", "paladin")
	if DevArgs.flag("--showcase"):
		var sc_cls := DevArgs.value("--showcase")
		autostart = sc_cls if GameData.classes.has(sc_cls) else "paladin"
		showcase = Showcase.new()
		showcase.setup(main, sc_cls, DevArgs.value("--skill"), DevArgs.value("--out"), DevArgs.has("--check"))
	if DevArgs.flag("--gfx"):        # --gfx=<n>: preset de GraphicsSettings só nesta partida (não salva); comparar FPS/imagem
		GraphicsSettings.preset = clampi(int(DevArgs.value("--gfx")), 0, GraphicsSettings.PRESETS.size() - 1)
		GraphicsSettings.apply(main.get_viewport())
	if DevArgs.has("--no_prune"):
		KitModel.prune = false
	if DevArgs.has("--no_away"):
		Sim.away_every = 1
	if DevArgs.has("--no_merge"):
		KitModel.merge = false
		RigidMerge.enabled = false
	main._cull_test = DevArgs.value("--cull_test")          # hide|noproc (medir: só esconde / só para de processar)
	if DevArgs.has("--anim_test"):
		EntityView.anim_test = true
	if DevArgs.has("--no_anim_lod"):
		EntityView.anim_lod = false
	if DevArgs.flag("--cull"):        # medir: distância de corte dos bonecos
		main.VIEW_CULL_DIST = float(DevArgs.value("--cull"))
	_soak_map = DevArgs.value("--soak_map")
	if DevArgs.flag("--soak"):        # joga sozinho (cérebro de bot) por N s e imprime FPS/nós/memória a cada 5 s
		_soak_left = float(DevArgs.value("--soak"))
		autostart = "berserker" if autostart == "" else autostart
	if DevArgs.flag("--gather_shot"):   # colhendo minério e erva (fotos <png>_ore.png / <png>_herb.png)
		_gather_shot.call_deferred(DevArgs.value("--gather_shot"))
	if DevArgs.flag("--title_shot"):    # foto da tela de criação com uma classe escolhida (revisar o layout)
		_title_shot.call_deferred(DevArgs.value("--title_shot"))
	if DevArgs.has("--perf"):                 # mede a cidade cheia por ~8 s e sai (FPS, draw calls, nós, tempo da sim)
		autostart = "paladin"
		_perf_run()
	if returning:
		autostart = ""
		_tour_dir = ""
		showcase = null
	return autostart

## Logo depois do start_game da partida automática: monta a cena de revisão pedida.
func after_start() -> void:
	if DevArgs.has("--return_check"):      # revisão: menu do Esc (foto) e "voltar ao menu"
		_menu_check()
		return
	_smoke_test = showcase == null and not DevArgs.has("--perf")
	if DevArgs.flag("--block_shot"):      # fotos do bloqueio e do aparar (escudo: --shield=<id>)
		_smoke_test = false
		_block_shot(DevArgs.value("--block_shot"))
	if showcase:
		main.camera.distance = 9.0
		main.add_child(showcase)
	if DevArgs.has("--mount"):      # começa a cavalo (revisar a montaria)
		Sim.player.mounted = true
	if DevArgs.has("--loot_demo"):  # amostra de drops ao lado do jogador (revisar o baú)
		_smoke_test = false
		_loot_demo()
	if DevArgs.flag("--gear"):      # --gear=<set_id>: começa vestindo um conjunto (revisar visual/ícones do lendário no smoke)
		_wear_set(DevArgs.value("--gear"))
	if DevArgs.flag("--bag_shot"):      # foto da bolsa e da ficha com uma amostra de cada tipo de item
		_smoke_test = false
		_bag_shot(DevArgs.value("--bag_shot"))
	if DevArgs.flag("--raid_shot"):     # --raid_shot=<png>: investida élfica na Floresta (fotos _marcha e _portao) e sai
		_smoke_test = false
		_raid_shot(DevArgs.value("--raid_shot"))
	if DevArgs.flag("--sig_film"):      # --sig_film=<png>: cada build da classe segurando o ataque num boneco, assinatura forçada (uma linha por build)
		_smoke_test = false
		_sig_film(DevArgs.value("--sig_film"))
	if DevArgs.flag("--npc_shot"):      # --npc_shot=<png> --npc=<id> [--level=N] [--gold=N]: diálogo do NPC aberto
		_smoke_test = false
		_npc_shot(DevArgs.value("--npc_shot"), DevArgs.value("--npc", "elder"))
	if DevArgs.flag("--repeat_shot"):   # --repeat_shot=<png>: quest repetível no diálogo do quadro (_dialogo), no rastreador e na janela L (_janela)
		_smoke_test = false
		_repeat_shot(DevArgs.value("--repeat_shot"))
	if DevArgs.flag("--elf_shot"):      # --elf_shot=<png>: leva élfica parada ao lado do jogador (batedor, batedor com arco, mago, lince, grifo, espírito)
		_smoke_test = false
		_elf_shot(DevArgs.value("--elf_shot"))
	if DevArgs.flag("--quest_shot"):    # --quest_shot=<png>: seta amarela do minimapa (objetivo neste mapa / noutro mapa) e sai
		_smoke_test = false
		_quest_shot(DevArgs.value("--quest_shot"))
	if DevArgs.flag("--morph_film"):    # --morph_film=<png> [--morph=phantom|demon|wolf|bear]: quadros da transformação de perto
		_smoke_test = false
		_morph_film(DevArgs.value("--morph_film"), DevArgs.value("--morph", "phantom"))

## Tela inicial (sem partida automática): fotos da tela de classes.
func at_title(returning: bool) -> void:
	if returning and DevArgs.has("--return_check"):     # revisão: foto da tela inicial depois de voltar
		await get_tree().create_timer(1.5).timeout
		var shot := DevArgs.value("--return_shot")
		if shot != "":
			get_viewport().get_texture().get_image().save_png(shot)
		print("RETURN_CHECK ok entities=%d maps=%d player=%s" % [Sim.entities.size(), Sim.maps.size(), str(Sim.player != null)])
		get_tree().quit()
	if DevArgs.flag("--select_shot"):      # --select_shot=<png>: foto da tela de classes e sai
		await get_tree().create_timer(2.0).timeout
		get_viewport().get_texture().get_image().save_png(DevArgs.value("--select_shot"))
		get_tree().quit()

## Chamado pelo _process do Main com o jogo rodando.
func tick(delta: float) -> void:
	if _soak_left > 0.0:
		_soak(delta)
	if _tour_dir != "":
		_tour(delta)
	elif _smoke_test:
		_smoke(delta)

const SIG_SHOTS := [0.15, 0.35, 0.55, 0.8, 1.05, 1.35, 1.7, 2.1]

func _sig_film(path: String) -> void:
	var p: SimEntity = Sim.player
	p.brain = null
	main.controller.set_physics_process(false)
	Sim._change_map(p, "field_forest", Vector3(-90, 0, 9))
	main.camera.distance = 9.0
	await get_tree().create_timer(1.5).timeout
	Sim.signature_force = true
	var rows: Array = []
	for b in p.class_def.builds:
		p.build_id = b["id"]
		Sim._gear_bot(p)
		Sim._skill_bot(p)
		p.recompute_stats()
		var mob: SimEntity = Sim.spawn_monster(GameData.monsters["spider"], "field_forest", p.position + Vector3(2.2, 0, -1.2))
		mob.brain = null
		mob.stats.max_hp = 1.0e7
		mob.hp = 1.0e7
		await get_tree().create_timer(0.6).timeout
		p.sig_ready_at = 0.0
		var frames: Array = []
		var t0 := Time.get_ticks_msec()
		for at in SIG_SHOTS:
			while (Time.get_ticks_msec() - t0) / 1000.0 < float(at):
				var c := InputCommand.new()
				c.aim = mob.position
				c.attack = true
				Sim.set_player_command(c)
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			frames.append(get_viewport().get_texture().get_image())
		rows.append(frames)
		Sim.set_player_command(InputCommand.new())
		Sim.despawn(mob)
		await get_tree().create_timer(0.8).timeout
	Sim.signature_force = false
	var full: Image = rows[0][0]
	var ch := int(full.get_height() * 0.5)
	var cw := int(ch * 0.9)
	var cx := (full.get_width() - cw) / 2 + int(cw * 0.12)
	var cy := (full.get_height() - ch) / 2 - int(ch * 0.08)
	var sheet := Image.create(cw * SIG_SHOTS.size(), ch * rows.size(), false, full.get_format())
	for r in range(rows.size()):
		for i in range(SIG_SHOTS.size()):
			sheet.blit_rect(rows[r][i], Rect2i(cx, cy, cw, ch), Vector2i(i * cw, r * ch))
	sheet.resize(sheet.get_width() / 2, sheet.get_height() / 2)
	sheet.save_png(path)
	print("SIG_FILM %s builds=%d" % [path, rows.size()])
	get_tree().quit()

func _npc_shot(path: String, npc_id: String) -> void:
	var p: SimEntity = Sim.player
	p.brain = null
	if DevArgs.flag("--level"):
		p.level = int(DevArgs.value("--level"))
	p.gold = int(DevArgs.value("--gold", str(p.gold)))
	for e in Sim.map_entities(p.map_id):
		if e.kind == SimEntity.Kind.NPC and e.npc_data.get("id", "") == npc_id:
			p.position = e.position + Vector3(0, 0, 1.6)
	await get_tree().create_timer(1.2).timeout
	Events.dialog_requested.emit(npc_id)
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("NPC_SHOT " + path)
	get_tree().quit()

func _repeat_shot(path: String) -> void:
	var p: SimEntity = Sim.player
	p.brain = null
	p.level = 12
	QuestSystem.accept(p, GameData.quests["h_slime"])
	p.quests_completed.append("b_wolves")
	p.quests_completed.append("q01_welcome")
	for e in Sim.map_entities(p.map_id):
		if e.kind == SimEntity.Kind.NPC and e.npc_data.get("id", "") == "board":
			p.position = e.position + Vector3(0, 0, 2)
	await get_tree().create_timer(1.2).timeout
	Events.dialog_requested.emit("board")
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path.replace(".png", "_dialogo.png"))
	main.hud.npc_ui.close()
	main.hud.windows_script.toggle("quests")
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path.replace(".png", "_janela.png"))
	print("REPEAT_SHOT " + path)
	get_tree().quit()

func _elf_shot(path: String) -> void:
	var p: SimEntity = Sim.player
	p.brain = null
	Sim._change_map(p, "field_forest", Vector3(-5, 0, 40))
	await get_tree().create_timer(1.0).timeout
	var ids := ["elf_raider", "elf_raider", "elf_raider_mage", "elf_raider_archer", "elf_lynx", "griffin_raider", "elf_wisp"]
	for i in ids.size():
		var mdef: MonsterDef = RaidSystem.scaled_def(Sim, GameData.monsters[ids[i]], 0)
		var e := Sim.spawn_monster(mdef, "field_forest", p.position + Vector3(-6.0 + i * 2.0, 0, -3.5))
		e.brain = null
		e.facing = 0.0
		if i == 1:
			e.stance = "bow"                       # o segundo batedor já trocou para o arco
	main.camera.distance = 13.0
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("ELF_SHOT " + path)
	get_tree().quit()

## Fotos da seta da quest: rastreia uma quest com alvo neste mapa (<png>_aqui.png) e outra noutro mapa
## (<png>_portal.png, aponta para o portal), recortadas no minimapa + rastreador.
func _quest_shot(path: String) -> void:
	var p: SimEntity = Sim.player
	p.brain = null
	var here := ""
	var away := ""
	for qid in GameData.quests:
		var obj: Dictionary = QuestSystem.objective(p, GameData.quests[qid])
		if obj.is_empty():
			continue
		if here == "" and obj["map"] == p.map_id and p.position.distance_to(obj["pos"]) > 60.0:
			here = qid
		elif away == "" and obj["map"] != p.map_id:
			away = qid
	for qid in [here, away]:
		if qid != "":
			p.quests_active[qid] = 0
	var hud = main.hud
	for pair in [[here, "_aqui"], [away, "_portal"]]:
		if pair[0] == "":
			continue
		hud.tracked_quest_id = pair[0]
		hud.refresh_quest_tracker()
		await get_tree().create_timer(1.5).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var w := img.get_width()
		img = img.get_region(Rect2i(w - 420, 0, 420, 520))
		img.save_png(path.replace(".png", pair[1] + ".png"))
		print("QUEST_SHOT %s %s guide=%s" % [pair[0], pair[1], QuestSystem.guide_point(p, GameData.quests[pair[0]])])
	get_tree().quit()

## Filme da transformação: câmera perto, liga a forma e fotografa os instantes (linha de cima), segura a forma
## (último quadro da linha) e desliga (linha de baixo). Uma folha só, recortada em volta do jogador.
const MORPH_SHOTS := [0.0, 0.06, 0.12, 0.18, 0.26, 0.36, 0.5, 1.2]

func _morph_film(path: String, form: String) -> void:
	main.camera.distance = 7.0
	Sim.player.brain = null
	await get_tree().create_timer(1.5).timeout
	var rows: Array = []
	for row in range(2):
		var frames: Array = []
		Sim._apply_effects(Sim.player, Sim.player, {"form": form}, 1.0)      # liga, depois desliga (alterna)
		var t0 := Time.get_ticks_msec()
		for at in MORPH_SHOTS:
			while (Time.get_ticks_msec() - t0) / 1000.0 < float(at):
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			frames.append(get_viewport().get_texture().get_image())
		rows.append(frames)
		await get_tree().create_timer(0.8).timeout
	var full: Image = rows[0][0]
	var ch := int(full.get_height() * 0.62)
	var cw := int(ch * 0.62)
	var cx := (full.get_width() - cw) / 2
	var cy := (full.get_height() - ch) / 2 - int(ch * 0.08)
	var sheet := Image.create(cw * MORPH_SHOTS.size(), ch * 2, false, full.get_format())
	for r in range(2):
		for i in range(MORPH_SHOTS.size()):
			var img: Image = rows[r][i]
			sheet.blit_rect(img, Rect2i(cx, cy, cw, ch), Vector2i(i * cw, r * ch))
	sheet.save_png(path)
	print("MORPH_FILM ok %s" % path)
	get_tree().quit()

## Investida élfica: leva o jogador à Floresta, solta uma leva e fotografa a marcha na estrada norte e a luta no portão.
## O jogador fica de pé no caminho (vida cheia o tempo todo) para a câmera seguir a ação.
func _raid_shot(path: String) -> void:
	var p := Sim.player
	var def: MapDef = GameData.maps["field_forest"]
	Sim._change_map(p, def.id, def.raid["route"][3])
	await get_tree().create_timer(2.5).timeout
	var m: Dictionary = Sim.maps[def.id]
	for e in m["entities"]:
		if e.kind == SimEntity.Kind.MONSTER and e.raid_id < 0:
			e.brain = null                    # só a investida se mexe
	RaidSystem.start_raid(Sim, m)
	var t := 0.0
	var shots := [[Balance.RAID_MUSTER + 14.0, "_marcha", def.raid["route"][3]], [-1.0, "_portao", def.raid["route"][def.raid["route"].size() - 1]]]
	for sh in shots:
		p.position = sh[2] + Vector3(0, 0, 3)
		while true:
			await get_tree().process_frame
			t += get_process_delta_time()
			p.hp = p.stats.max_hp
			var st := RaidSystem.state(m)
			if (float(sh[0]) > 0.0 and float(st["t"]) >= float(sh[0])) or (float(sh[0]) < 0.0 and st["arrived"] and float(st["t"]) > 4.0 + float(st.get("arrived_t", 0.0))) or t > 150.0:
				break
			if st["arrived"] and not st.has("arrived_t"):
				st["arrived_t"] = st["t"]
		get_viewport().get_texture().get_image().save_png(path.trim_suffix(".png") + sh[1] + ".png")
		print("RAID_SHOT %s t=%.0f vivos=%d" % [sh[1], float(RaidSystem.state(m)["t"]), RaidSystem.state(m)["ids"].size()])
	get_tree().quit()

func _loot_demo() -> void:
	var lm: Dictionary = Sim.maps[Sim.player.map_id]
	var samples := ["gold", "legend_coin", "slime_gel", "sword_iron", "leg_paladin_guardiao_30_head"]
	for i in range(samples.size()):
		if samples[i] == "gold" or GameData.items.has(samples[i]):
			var lp: Vector3 = Sim.player.position + Vector3(-2.4 + i * 1.2, 0, 2.0)
			lm["loot"].append({"pos": lp, "item": samples[i], "count": 1, "timer": 999.0, "owner": -1, "free_at": 0.0})
			Events.loot_dropped.emit(Sim.player.map_id, lp, samples[i], 1)
	var king := Sim.spawn_monster(Sim.elite_def(GameData.monsters["slime"]), Sim.player.map_id, Sim.player.position + Vector3(3.5, 0, -2.5))
	king.brain = null                     # Rei Slime parado ao lado (revisar tamanho e cor)
	king.hp = king.stats.max_hp * 0.3     # barras de vida: Rei a 30%, jogador a 50%
	king.aggro_target = Sim.player.id
	Sim.player.hp = Sim.player.stats.max_hp * 0.5
	# itens entrando na bolsa: aparece o aviso de "pegou" com a arte
	get_tree().create_timer(1.6).timeout.connect(func(): Sim.player.add_item("wolf_pelt", 3); Sim.player.add_item("sword_iron", 1); Sim.player.add_item("potion_mp_m", 2))
	_demo_shot()

func _wear_set(set_id: String) -> void:
	var sd: SetDef = GameData.sets.get(set_id)
	if sd == null:
		return
	Sim.player.level = maxi(Sim.player.level, sd.level)
	for iid in sd.pieces:
		Sim.player.add_item(iid)
		Sim.equip(Sim.player, iid, iid.ends_with("_offhand") and GameData.items[iid].weapon_type != "shield")
	if DevArgs.flag("--form"):      # --form=wolf|bear: já começa transformado (revisar a forma do Druida)
		Sim._apply_effects(Sim.player, Sim.player, {"form": DevArgs.value("--form")}, 1.0)
	if DevArgs.has("--mace") and not sd.alt_pieces.is_empty():     # --mace: a maça do conjunto no lugar da espada
		Sim.player.add_item(sd.alt_pieces[0])
		Sim.equip(Sim.player, sd.alt_pieces[0], false)

static func _grow_aldara(v: Vector3) -> Vector3:
	var r := Vector2(v.x, v.z).length()
	if r <= 36.0:
		return v
	var k := (36.0 + (r - 36.0) * 1.2) / r
	return Vector3(v.x * k, v.y, v.z * k)

func _gather_shot(path: String) -> void:
	await get_tree().create_timer(3.0).timeout
	_smoke_test = false                          # o smoke mandaria andar/atacar (cancela a colheita)
	var p := Sim.player
	p.mounted = false
	for want in ["ore", "herb"]:
		for g in Sim.maps[p.map_id]["gather"]:
			if g["kind"] == want:
				g["ready_at"] = 0.0
				p.position = g["pos"] + Vector3(0.9, 0, 0.6)
				main.views[p.id].position = p.position
				main.views[p.id]._smooth_pos = p.position
				break
		await get_tree().create_timer(0.6).timeout
		var cmd := InputCommand.new()
		cmd.interact = true
		cmd.aim = p.position
		Sim.set_player_command(cmd)
		await get_tree().process_frame
		Sim.set_player_command(InputCommand.new())
		await get_tree().create_timer(0.55).timeout
		print("GATHER_SHOT %s gathering=%.2f" % [want, p.gather_left])
		get_viewport().get_texture().get_image().save_png(path.trim_suffix(".png") + "_" + want + ".png")
		await get_tree().create_timer(1.0).timeout
	get_tree().quit()

func _title_shot(path: String) -> void:
	await get_tree().create_timer(2.5).timeout
	var cs = main.hud.class_select
	if cs:
		var cid := DevArgs.value("--title_class", "druid")
		var step := DevArgs.value("--title_step")      # slots | class | look
		var tab := DevArgs.value("--title_tab")        # body | hair | face
		if step != "slots" and step != "":
			if cs._page != "create":
				cs._go_create()
			cs._select(GameData.classes[cid])
			if tab != "":
				cs._look_tab = tab
			cs._set_step(step)
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()

func _menu_check() -> void:
	await get_tree().create_timer(1.5).timeout
	main.hud.open_game_menu()
	await get_tree().create_timer(0.5).timeout
	if DevArgs.flag("--menu_shot"):
		get_viewport().get_texture().get_image().save_png(DevArgs.value("--menu_shot"))
	main.hud._menu_to_title()

func _demo_shot() -> void:
	await get_tree().create_timer(2.0).timeout
	if _shot_path != "":
		get_viewport().get_texture().get_image().save_png(_shot_path)
	get_tree().quit()

func _perf_run() -> void:
	await get_tree().create_timer(1.0).timeout
	if DevArgs.flag("--perf_map") and Sim.player:     # medir dentro de outro mapa (ex.: --perf_map=dg_catacumbas)
		var pm := DevArgs.value("--perf_map")
		Sim._change_map(Sim.player, pm, GameData.maps[pm].spawn_point)
		Sim._process_map_changes()
	if DevArgs.flag("--perf_at") and Sim.player:      # medir num ponto do mapa (ex.: --perf_at=80,14)
		var xz := DevArgs.value("--perf_at").split(",")
		Sim.player.position = Vector3(float(xz[0]), 0, float(xz[1]))
	await get_tree().create_timer(2.5).timeout
	Sim.profile = true
	Sim.prof.clear()
	if DevArgs.has("--test_no_anim"):
		for v in main.views.values():
			for a in v.find_children("*", "AnimationMixer", true, false):
				a.process_mode = Node.PROCESS_MODE_DISABLED
	if DevArgs.has("--test_no_labels") or DevArgs.has("--test_no_shadow"):
		for v in main.views.values():
			for g in v.find_children("*", "GeometryInstance3D", true, false):
				if g is Label3D and DevArgs.has("--test_no_labels"):
					g.visible = false
				elif DevArgs.has("--test_no_shadow"):
					g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var ticks0 := Sim.tick_count
	EntityView.prof_us = 0.0
	var frames := 0
	var t0 := Time.get_ticks_usec()
	var sim_us := 0.0
	var draws := 0.0
	var tick_sum := 0.0
	var proc_us := 0.0
	var gpu_sum := 0.0
	var rcpu_sum := 0.0
	while Time.get_ticks_usec() - t0 < 5_000_000:
		await get_tree().process_frame
		frames += 1
		tick_sum += Sim.tick_usec
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		sim_us += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1_000_000.0
		proc_us += Performance.get_monitor(Performance.TIME_PROCESS) * 1_000_000.0
		gpu_sum += RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
		rcpu_sum += RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid())
	var secs := (Time.get_ticks_usec() - t0) / 1_000_000.0
	print("PERF sim_tick_ms=%.2f away=%d ticks_per_frame=%.2f" % [tick_sum / frames / 1000.0, Sim.away_every, float(Sim.tick_count - ticks0) / frames])
	print("PERF views_script_ms=%.2f per_frame (%d bonecos visíveis)" % [EntityView.prof_us / frames / 1000.0, main.views.values().filter(func(v): return v.visible).size()])
	var nt := maxi(1, Sim.tick_count - ticks0)
	var keys: Array = Sim.prof.keys()
	keys.sort_custom(func(a, b): return Sim.prof[a] > Sim.prof[b])
	for k in keys:
		print("PERF   %-24s %.3f ms/tick" % [k, Sim.prof[k] / nt / 1000.0])
	var counts := {}
	for mid in Sim.maps:
		for e in Sim.maps[mid]["entities"]:
			var key: String = "%s:%s" % [mid, SimEntity.Kind.keys()[e.kind]]
			counts[key] = int(counts.get(key, 0)) + 1
	print("PERF entities ", counts)
	var merged := 0
	var msurf := 0
	var vis_src := 0
	for v in main.views.values():
		if not v.visible or v.kit == null:
			continue
		for mi in v.kit.find_children("*", "MeshInstance3D", true, false):
			if mi.name == "KitMerged":
				merged += 1
				msurf += mi.mesh.get_surface_count() if mi.mesh else 0
			elif mi.visible and mi.name != "WeaponTrail":
				vis_src += 1
	print("PERF kits merged=%d surfaces=%d visible_unmerged_pieces=%d" % [merged, msurf, vis_src])
	# triângulos por grupo de malha (prefixo do nome) e por dono: mapa x bonecos
	var tri := {}
	var cnt := {}
	for mi in get_tree().root.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var n := 0
		for si in range(mi.mesh.get_surface_count()):
			var arr: Array = mi.mesh.surface_get_arrays(si)
			n += (arr[Mesh.ARRAY_INDEX].size() if arr[Mesh.ARRAY_INDEX] != null else arr[Mesh.ARRAY_VERTEX].size()) / 3
		var key: String = String(mi.name).rstrip("0123456789._").left(28)
		var p_node: Node = mi
		var owner_kind := "?"
		while p_node:
			if p_node is EntityView:
				owner_kind = "entity"
				break
			p_node = p_node.get_parent()
		if owner_kind == "entity":
			key = "ENTITY"
		tri[key] = int(tri.get(key, 0)) + n
		cnt[key] = int(cnt.get(key, 0)) + 1
	var tk: Array = tri.keys()
	tk.sort_custom(func(a, b): return tri[a] > tri[b])
	for k in tk.slice(0, 18):
		print("PERF   tri %-28s %8d  (%d malhas)" % [k, tri[k], cnt[k]])
	print("PERF avg process_ms=%.2f physics_ms=%.2f gpu_ms=%.2f render_cpu_ms=%.2f" % [proc_us / frames / 1000.0, sim_us / frames / 1000.0, gpu_sum / frames, rcpu_sum / frames])
	print("PERF process_ms=%.2f phys_objects=%d pairs=%d islands=%d gpu_ms=%.2f cpu_ms=%.2f prims=%d" % [Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS), Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS),
		Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT), RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()),
		RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	print("PERF fps=%.1f frame_ms=%.2f draws=%.0f nodes=%d objects=%d mem_mb=%.0f physics_ms=%.2f prune=%s" % [frames / secs, secs * 1000.0 / frames,
		draws / frames, Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, sim_us / frames / 1000.0, str(KitModel.prune)])
	get_tree().quit()

## Confere o arrastar e soltar: capacete da bolsa no slot da cabeça, depois de volta para a bolsa; anel no 2º slot.
func _dnd_check() -> void:
	var w = main.hud.windows_script
	var p := Sim.player
	var ok := true
	var head := ""
	var ring := ""
	for iid in p.inventory:
		var it: ItemDef = GameData.items[iid]
		if head == "" and it.slot == ItemDef.Slot.HEAD and Sim.equip_error(p, it) == "":
			head = iid
		if ring == "" and it.slot == ItemDef.Slot.RING and Sim.equip_error(p, it) == "":
			ring = iid
	ok = ok and head != "" and w._can_drop_on_slot(Vector2.ZERO, {"rx_drag": "bag", "item": head}, ItemDef.Slot.HEAD)
	ok = ok and not w._can_drop_on_slot(Vector2.ZERO, {"rx_drag": "bag", "item": head}, ItemDef.Slot.BOOTS)
	w._drop_on_slot(Vector2.ZERO, {"rx_drag": "bag", "item": head}, ItemDef.Slot.HEAD)
	ok = ok and p.equipment.get(ItemDef.Slot.HEAD) != null and p.equipment[ItemDef.Slot.HEAD].id == head
	ok = ok and w._can_drop_on_bag(Vector2.ZERO, {"rx_drag": "slot", "slot": ItemDef.Slot.HEAD})
	w._drop_on_bag(Vector2.ZERO, {"rx_drag": "slot", "slot": ItemDef.Slot.HEAD})
	ok = ok and p.equipment.get(ItemDef.Slot.HEAD) == null and p.has_item(head)
	if ring != "":
		w._drop_on_slot(Vector2.ZERO, {"rx_drag": "bag", "item": ring}, ItemDef.Slot.RING2)
		ok = ok and p.equipment.get(ItemDef.Slot.RING2) != null and p.equipment.get(ItemDef.Slot.RING) == null
	print("DND_CHECK ", "ok" if ok else "FAIL", " head=", head, " ring=", ring)

func _bag_shot(path: String) -> void:
	var seen := {}
	for iid in GameData.items:
		var it: ItemDef = GameData.items[iid]
		var g := UiKit.item_glyph(it) if it.icon == "" else "own_" + it.icon.get_slice("_", 0)
		if not seen.has(g) and Sim.player.inventory.size() < 40:
			seen[g] = true
			Sim.player.add_item(iid)
	var wins := ["inventory", "character"]
	if DevArgs.flag("--wins"):          # outras janelas: --wins=skills (com --level=N para um boneco do meio do jogo)
		wins = Array(DevArgs.value("--wins").split(","))
	if DevArgs.flag("--level"):
		var lv := int(DevArgs.value("--level"))
		Sim.player.level = lv
		Sim.player.mastery_points = lv
		for sid in Sim.player.class_def.skill_ids:       # maestria como a de um bot do mesmo nível (anel da árvore)
			if Sim.player.knows(sid):
				Sim.player.mastery[sid] = clampi(lv / 6 - Sim.player.class_def.skill_ids.find(sid) % 3, 0, Balance.MASTERY_MAX)
	if DevArgs.has("--status_demo"):     # buffs e debuffs de amostra na barra (revisar ícones e tempos)
		Sim.player.buffs.append({"id": "elixir", "remaining": 44.0, "atk_pct": 20})
		Sim.player.buffs.append({"id": "frost_armor", "remaining": 7.2, "def_pct": 30})
		Sim.player.buffs.append({"id": "juramento", "remaining": 5.0, "stacks": 3})
		Sim.player.debuffs.append({"kind": "dot", "remaining": 3.4, "dps": 0.0, "fire": true, "src": -1})
		Sim.player.debuffs.append({"kind": "dot", "remaining": 8.0, "dps": 0.0, "src": -1})
		Sim.player.debuffs.append({"kind": "slow", "remaining": 2.6, "pct": 30.0})
		Sim.player.debuffs.append({"kind": "curse", "remaining": 75.0, "taken_pct": 0.0, "weaken_pct": 0.0})
	if DevArgs.has("--picks"):           # janela K na aba Talentos (revisar as escolhas)
		main.hud.windows_script._skills_tab = "picks"
	if DevArgs.has("--dnd_check"):      # arrastar e soltar pelos mesmos métodos da janela
		_dnd_check()
	await get_tree().create_timer(0.5).timeout
	for w in wins:
		if w != "":
			main.hud.windows_script.toggle(w)
	if DevArgs.has("--craft_check"):      # forja aberta e rolada: a rolagem não pode voltar ao topo
		main.hud.windows_script.close_all()
		main.hud.npc_ui.open("smith")
		main.hud.npc_ui.mode = "craft"
		main.hud.npc_ui._rebuild()
		await get_tree().process_frame
		await get_tree().process_frame
		main.hud.npc_ui._scroll.scroll_vertical = 300
		var at0: int = main.hud.npc_ui._scroll.scroll_vertical
		await get_tree().create_timer(4.0).timeout          # bots pegando itens na cidade não mexem na janela
		var at1: int = main.hud.npc_ui._scroll.scroll_vertical
		Sim.player.add_item("iron_ore", 1)                  # item do jogador: reconstrói e mantém a rolagem
		await get_tree().create_timer(0.3).timeout
		print("CRAFT_CHECK start=%d after_bots=%d after_rebuild=%d" % [at0, at1, main.hud.npc_ui._scroll.scroll_vertical])
	if DevArgs.has("--enhance"):          # ferreiro: aprimorar; arma +9 e peito +5 para ver o brilho
		var pp := Sim.player
		pp.gold = 5000
		pp.add_item("iron_ore", 30)
		pp.add_item("star_ore", 6)
		for sl in pp.equipment:
			var eit: ItemDef = pp.equipment[sl]
			if eit:
				pp.equipment[sl] = GameData.plus_item(eit, 9 if sl == ItemDef.Slot.WEAPON else (5 if sl == ItemDef.Slot.BODY else 2))
		pp.recompute_stats()
		Events.equipment_changed.emit(pp.id)
		main.hud.windows_script.close_all()
		if DevArgs.has("--glow_only"):     # sem janela, câmera perto: ver o brilho do +9/+5
			main.camera.distance = main.camera.min_distance
			main.hud.root.visible = false
			await get_tree().create_timer(0.8).timeout
		else:
			main.hud.npc_ui.open("smith")
			main.hud.npc_ui.mode = "enhance"
			main.hud.npc_ui._rebuild()
	if DevArgs.has("--shop"):             # loja do mercador com a bolsa de amostra (revisar compra/venda)
		Sim.player.gold = 350
		main.hud.windows_script.close_all()
		main.hud.npc_ui.open("merchant")
		main.hud.npc_ui.mode = "shop"
		main.hud.npc_ui._rebuild()
	if DevArgs.has("--relic"):            # janela da Relicária com moedas (revisar a troca)
		for n in Sim.maps[Sim.player.map_id]["def"].npcs:
			if n["role"] == "relic":
				Sim.player.position = n["pos"] + Vector3(0, 0, 1.5)
		Sim.player.add_item("legend_coin", 3)
		main.hud.windows_script.close_all()
		main.hud.npc_ui.open("relic")
		main.hud.npc_ui.mode = "relic"
		main.hud.npc_ui._rebuild()
	if DevArgs.has("--storage"):          # janela do depósito, perto do Guarda-volumes
		for n in Sim.maps[Sim.player.map_id]["def"].npcs:
			if n["role"] == "storage":
				Sim.player.position = n["pos"] + Vector3(0, 0, 1.5)
		Sim.player.storage = {"wolf_pelt": 6, "iron_ore": 12, "potion_hp_m": 3}
		main.hud.windows_script.close_all()
		main.hud.npc_ui.open("storage")
		main.hud.npc_ui.mode = "storage"
		main.hud.npc_ui._rebuild()
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(path)
	print("bag_shot: " + path)
	get_tree().quit()

func _block_shot(path: String) -> void:
	await get_tree().create_timer(2.0).timeout
	var p: SimEntity = Sim.player
	var shield := DevArgs.value("--shield", "shield_deus_guerra")
	p.equipment[ItemDef.Slot.OFFHAND] = GameData.items[shield]
	p.recompute_stats()
	Events.equipment_changed.emit(p.id)
	var foe: SimEntity = Sim.spawn_monster(GameData.monsters["wolf"], p.map_id, p.position + Vector3(1.4, 0, -1.2))
	foe.state_time = 0.0
	await get_tree().create_timer(0.3).timeout
	for shot in ["_bloqueio", "_aparo"]:
		p.face_towards(foe.position)
		p.is_blocking = true                     # o comando do tick limpa: precisa valer no golpe
		p.parry_left = Balance.PARRY_WINDOW if shot == "_aparo" else 0.0
		p.shield_react_cd = 0.0
		Sim._deal_damage(foe, p, 30, false, true, "physical")
		await get_tree().create_timer(0.14, true, false, true).timeout
		get_viewport().get_texture().get_image().save_png(path.replace(".png", shot + ".png"))
		await get_tree().create_timer(1.2).timeout
	Sim.running = false                          # sem tick a guarda fica erguida: foto limpa do arco
	p.is_blocking = true
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(path.replace(".png", "_arco.png"))
	get_tree().quit()

func _tour(delta: float) -> void:
	_tour_t += delta
	var p := Sim.player
	p.hp = p.stats.max_hp
	if _tour_t < 2.0:
		return
	var stops: Array = TOURS.get(_tour_map, TOUR)
	if GameData.maps.has(_tour_map) and GameData.maps[_tour_map].interior:      # casa: uma foto da sala, perto da porta
		stops = [["sala", Vector3(0, 0, GameData.maps[_tour_map].size.y * 0.5 - 3.0)]]
	elif not TOURS.has(_tour_map):             # paradas do Vale: escritas no layout antigo; o vale cresceu 20% (places.grow_aldara)
		stops = stops.map(func(st): return [st[0], _grow_aldara(st[1])])
		stops.append(["praia_caranguejos", Vector3(6.7, 0, 111.0)])
		stops.append(["portas_casas", Vector3(13.0, 0, 12.0)])
	if p.map_id != _tour_map:
		Sim._change_map(p, _tour_map, stops[0][1])
		_tour_t = 0.5
		return
	if _tour_i >= stops.size():
		get_tree().quit()
		return
	if not has_meta("tour_moved"):
		set_meta("tour_moved", true)
		p.position = stops[_tour_i][1]
		_tour_t = 2.0
	elif _tour_t > 3.6:
		get_viewport().get_texture().get_image().save_png("%s/tour_%s_%02d_%s.png" % [_tour_dir, _tour_map, _tour_i, stops[_tour_i][0]])
		_tour_i += 1
		remove_meta("tour_moved")

func _soak_fight(p: SimEntity) -> void:
	p.hp = p.stats.max_hp
	p.mp = p.stats.max_mp
	var best: SimEntity = null
	var bd := 1e9
	for e in Sim.map_entities(p.map_id):
		if e.kind == SimEntity.Kind.MONSTER and e.is_alive():
			var d: float = e.position.distance_squared_to(p.position)
			if d < bd:
				bd = d
				best = e
	var cmd := InputCommand.new()
	if best:
		var to := best.position - p.position
		cmd.aim = best.position
		if to.length() > 2.0:
			cmd.move = Vector2(to.x, to.z).normalized()
		else:
			cmd.attack = true
			cmd.skill_slot = (Engine.get_process_frames() / 10) % 6 if Engine.get_process_frames() % 10 == 0 else -1
	Sim.set_player_command(cmd)

## Sessão longa automática: o jogador vira um bot (caça, viaja, entra em dungeon) e a cada 5 s sai uma linha de medição.
func _soak(delta: float) -> void:
	var p := Sim.player
	if p == null:
		return
	if _soak_brain == null:
		_soak_brain = BotBrain.new()
		_soak_brain.setup(p, Sim.rng)
		_smoke_test = false
		Sim.profile = true
		_soak_ticks0 = Sim.tick_count
	_soak_left -= delta
	_soak_t += delta
	_soak_frames += 1
	_soak_worst = maxf(_soak_worst, delta)
	if _soak_map != "" and p.map_id != _soak_map:
		Sim._change_map(p, _soak_map, GameData.maps[_soak_map].spawn_point)
		Sim._process_map_changes()
		p.level = 12
		p.mastery_points = 40
		for sid in p.class_def.skill_ids:          # aprende o que der e enche a barra
			Sim.learn_skill(p, sid)
		p.recompute_stats()
		var k := 0
		for cid in ["paladin", "bishop", "elementalist"]:      # grupo de bots junto, brigando também
			var b := Sim.spawn_bot(GameData.classes[cid], "Grupo%d" % k, _soak_map, p.position + Vector3(2 + k, 0, 2), 12)
			Sim.party_invite(p, b)
			Sim.party_accept(b)
			k += 1
	if _soak_map != "":
		_soak_fight(p)                     # dungeon: briga com o monstro mais perto (bot não caça em dungeon sozinho)
	elif Sim.maps.has(p.map_id):
		Sim.set_player_command(_soak_brain.think(p, Sim, Sim.maps[p.map_id], delta))
	if _soak_t >= 5.0:
		var near := 0
		for e in Sim.map_entities(p.map_id):
			if e.kind == SimEntity.Kind.MONSTER and not e.dormant:
				near += 1
		print("SOAK t=%.0f fps=%.1f map=%s lv=%d awake_mobs=%d nodes=%d objects=%d mem_mb=%.0f tick_ms=%.2f views=%d worst_ms=%.0f" % [Time.get_ticks_msec() / 1000.0,
			_soak_frames / _soak_t, p.map_id, p.level, near, Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Sim.tick_usec / 1000.0, main.views.size(), _soak_worst * 1000.0])
		_soak_worst = 0.0
		_soak_t = 0.0
		_soak_frames = 0
	if _soak_left <= 0.0:
		var nt := maxi(1, Sim.tick_count - _soak_ticks0)
		var keys: Array = Sim.prof.keys()
		keys.sort_custom(func(a, b): return Sim.prof[a] > Sim.prof[b])
		for k in keys.slice(0, 14):
			print("SOAK   %-24s %.3f ms/tick" % [k, Sim.prof[k] / nt / 1000.0])
		get_tree().quit()

func _smoke(delta: float) -> void:
	_smoke_t += delta
	var p := Sim.player
	var cmd := InputCommand.new()
	cmd.aim = p.position + p.forward() * 3.0
	match _smoke_stage:
		0:
			cmd.move = Vector2(0, 1)
			cmd.jump = _smoke_t > 0.8 and _smoke_t < 0.85      # pula correndo (pulo + pouso no smoke)
			if _smoke_t > 2.0: _smoke_stage = 1
		1:
			cmd.attack = true
			cmd.skill_slot = int(_smoke_t * 4.0) % 6
			if _smoke_t > 4.0: _smoke_stage = 2
		2:
			cmd.dash = true
			cmd.potion_slot = 0
			main.hud.windows_script.toggle("inventory")
			main.hud.windows_script.toggle("character")
			main.hud.windows_script.toggle("skills")
			main.hud.windows_script.toggle("quests")
			main.hud.windows_script.close_all()
			main.hud.npc_ui.open("elder")
			main.hud.npc_ui.mode = "shop"; main.hud.npc_ui._rebuild()
			main.hud.npc_ui.mode = "craft"; main.hud.npc_ui._rebuild()
			main.hud.npc_ui.close()
			_smoke_party(p)
			if _shot_path != "":
				main.hud.windows_script.toggle("skills")
				_smoke_stage = 20
			else:
				_smoke_stage = 3
		20:
			if _smoke_t > 4.6:
				get_viewport().get_texture().get_image().save_png(_shot_path.replace(".png", "_skills.png"))
				main.hud.windows_script.close_all()
				main.hud.windows_script.toggle("character")
				main.hud.windows_script.toggle("inventory")
				_smoke_stage = 22
		22:
			if _smoke_t > 5.0:
				get_viewport().get_texture().get_image().save_png(_shot_path.replace(".png", "_char.png"))
				main.hud.windows_script.close_all()
				main.hud.windows_script.toggle("party")
				_smoke_stage = 23
		23:
			if _smoke_t > 5.3:
				get_viewport().get_texture().get_image().save_png(_shot_path.replace(".png", "_party.png"))
				main.hud.windows_script.close_all()
				main.hud.npc_ui.open("smith")
				main.hud.npc_ui.mode = "craft"; main.hud.npc_ui._rebuild()
				_smoke_stage = 21
		21:
			if _smoke_t > 5.9:
				get_viewport().get_texture().get_image().save_png(_shot_path.replace(".png", "_craft.png"))
				main.hud.npc_ui.close()
				_smoke_stage = 3
		3:
			if _shot_path != "":
				var img := get_viewport().get_texture().get_image()
				img.save_png(_shot_path.replace(".png", "_town.png"))
			p.position = Vector3(6, 0, 52)      # Campina: estrada sul, perto do lago dos slimes
			_smoke_stage = 4
			_smoke_t = 0.0
		4:
			if _smoke_t > 0.3 and not has_meta("smoke_mobs"):
				set_meta("smoke_mobs", true)
				for i in range(3):
					Sim.spawn_monster(GameData.monsters["slime"], p.map_id, p.position + Vector3(2.5 + i * 0.8, 0, 1.0 + i * 0.6))
				Sim.spawn_monster(GameData.monsters["wolf"], p.map_id, p.position + Vector3(-3.0, 0, 2.0))
			cmd.aim = p.position + Vector3(3.0, 0, 1.5)
			if _smoke_t > 0.6:
				cmd.attack = true
			if _smoke_t > 1.4 and _smoke_t < 1.5:
				cmd.skill_slot = 0
			if _smoke_t > 2.0:
				Input.action_press("skill_4")
			if _smoke_t > 2.6: _smoke_stage = 5
		5:
			if _shot_path != "":
				var img := get_viewport().get_texture().get_image()
				img.save_png(_shot_path)
				print("screenshot: " + _shot_path)
			print("SMOKE OK: map=%s hp=%d entities=%d views=%d" % [p.map_id, p.hp, Sim.entities.size(), main.views.size()])
			get_tree().quit(0)
	Sim.set_player_command(cmd)

## Smoke do grupo: bot convida o jogador (popup → aceitar), passa a liderança, jogador convida mais um bot.
func _smoke_party(p: SimEntity) -> void:
	var near: Array = Sim.map_entities(p.map_id).filter(func(e): return e.kind == SimEntity.Kind.BOT and e.party_id < 0 and e.is_alive())
	near.sort_custom(func(a, b): return a.position.distance_squared_to(p.position) < b.position.distance_squared_to(p.position))
	if near.size() < 2:
		print("SMOKE party: poucos bots por perto")
		return
	Sim.party_invite(near[0], p)
	main.hud.answer_invite(true)
	Sim.party_promote(near[0], p)
	Sim.party_invite(p, near[1])
	Sim.party_accept(near[1])
	main.hud._chat_command("/p bora pra campina")
	main.hud.windows_script.toggle("party")
	main.hud.windows_script.close("party")
	print("SMOKE party: %d membros, líder=%s" % [Sim.party_members(p).size(), Sim.party_leader(p).name])
