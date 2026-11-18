class_name DevRunner
extends Node
## Modos de revisão e medição da linha de comando (`-- --autostart`, `--bag_shot`, `--tour`, `--soak`, `--perf`...).
## Só existe quando há argumentos depois de `--`; o Main chama `before_start`, `after_start` e `tick`.
## Fotos da tela inicial (RETURN_CHECK, --select_shot, --title_shot) ficam em game/menu/start.gd.
## Pode mexer direto no estado da sim (montar cenas de revisão) — o jogo normal nunca passa por aqui.

var main: Node                    # game/main.gd

## Paradas nas fortalezas: já no mapa girado (zone_lib.FORT_TURN; o desenho original tem a chegada ao sul).
const TOURS := {
	# Ato II, fase 1: Costa Partida, Porto Esperança e Grutas Goblin
	"field_coast": [["ponte_costa", Vector3(-62.2, 0, 38.9)], ["encruzilhada", Vector3(4, 0, 6)], ["praia", Vector3(-12, 0, 62)], ["mae_das_mares", Vector3(4, 0, 60)], ["farol", Vector3(54, 0, 74)],
		["santuario", Vector3(86, 0, 26)], ["ginetes", Vector3(62, 0, -50)], ["falesias", Vector3(-6, 0, -74)], ["palafitas", Vector3(-78, 0, 18)],
		["grutas", Vector3(-70, 0, -28)], ["ponte_mangue", Vector3(-52, 0, -10)], ["chegada", Vector3(92, 0, 12)], ["passo_estepes", Vector3(28, 0, -72)],
		["varas_farol", Vector3(46, 0, 71)]],
	"city_port": [["chegada_navio", Vector3(-3, 0, 52)], ["praca", Vector3(0, 0, 18)], ["portao_norte", Vector3(0, 0, -30)], ["cais", Vector3(4, 0, 58)],
		["farolete", Vector3(45, 0, 56)], ["taverna", Vector3(-21, 0, 14)], ["garganta", Vector3(40, 0, -60)],
		["estaleiro", Vector3(-40, 0, 58)], ["hortas", Vector3(-62, 0, 2)], ["posto", Vector3(57, 0, -26)], ["portao_oeste", Vector3(-40, 0, 8)], ["garganta_costa", Vector3(-72, 0, -25)],
		["pescadores_cais", Vector3(3, 0, 66)], ["cais_oeste", Vector3(-6, 0, 65.5)]],
	# Ato II, fase 2: Estepes de Cinza e os três acampamentos de guerra
	"field_steppe": [["posto_caravana", Vector3(0, 0, 4)], ["vao_oeste", Vector3(-24, 0, 0)], ["ponte_oeste", Vector3(-45, 0, -5)], ["front_trolls", Vector3(-80, 0, 2)],
		["front_ghar", Vector3(58, 0, -32)], ["front_fogo", Vector3(66, 0, 46)], ["mamutes", Vector3(-84, 0, 52)], ["desertores", Vector3(-34, 0, -78)],
		["totem_partido", Vector3(34, 0, -68)], ["totem_ventos", Vector3(22, 0, -58)], ["passo_kharzun", Vector3(0, 0, -92)], ["chegada_costa", Vector3(-15, 0, 88)],
		["cabana_marfim", Vector3(-56, 0, 78)], ["ravina_leste", Vector3(96, 0, 22)]],
	# Ato II, fase 3: Monte Kharzun
	"field_kharzun": [["acampamento", Vector3(0, 0, 4)], ["chegada", Vector3(0, 0, 88)], ["portao_leste", Vector3(30, 0, 0)], ["canil", Vector3(84, 0, 6)],
		["minas", Vector3(-76, 0, -2)], ["cabana_xama", Vector3(-44, 0, 20)], ["santuario_anoes", Vector3(-72, 0, 42)], ["libertos", Vector3(32, 0, 56)],
		["ponte_norte", Vector3(1.6, 0, -50)], ["forja", Vector3(56, 0, -68)], ["matadores", Vector3(-66, 0, -60)], ["portao_cidadela", Vector3(0, 0, -84)]],
	# Salão dos Matadores e Cidadela de Kharzun (masmorras do Monte Kharzun)
	"dg_slayers": [["entrada", Vector3(0, 0, 40)], ["vestibulo", Vector3(0, 0, 29)], ["galeria", Vector3(-15, 0, -8)], ["venenos", Vector3(30, 0, -13)], ["mestre", Vector3(5, 0, -46)]],
	"kharzun_citadel": [["chegada", Vector3(0, 0, 94)], ["barbaca", Vector3(0, 0, 74)], ["patio", Vector3(0, 0, 40)], ["canis", Vector3(-44, 0, 46)], ["rampa", Vector3(-72, 0, 26)],
		["arena_lobo", Vector3(-78, 0, -6)], ["caverna", Vector3(44, 0, 46)], ["pocas", Vector3(72, 0, 26)], ["arena_pedra", Vector3(78, 0, -6)], ["fundicao", Vector3(34, 0, 4)],
		["arena_forja", Vector3(50, 0, -40)], ["selo", Vector3(0, 0, -4)], ["porta_trono", Vector3(0, 0, -20)], ["trono", Vector3(0, 0, -48)]],
	"fort_trolls": [["chegada", Vector3(90, 0, 0)], ["ponte_fenda", Vector3(44, 0, -13)], ["portao", Vector3(4, 0, 0)], ["toca", Vector3(-30, 0, 0)]],
	"fort_fire": [["chegada", Vector3(-73.7, 0, -51.6)], ["torres", Vector3(-41, 0, -28.7)], ["portao", Vector3(-3.3, 0, -2.3)], ["pira", Vector3(27.9, 0, 19.5)]],
	"fort_war": [["chegada", Vector3(-77.9, 0, 45)], ["posto", Vector3(-59.6, 0, -23.3)], ["portao", Vector3(-3.5, 0, 2)], ["arena", Vector3(24.2, 0, -14)]],
	"dg_goblin": [["entrada", Vector3(0, 0, 40)], ["lamacal", Vector3(0, 0, 26)], ["forja", Vector3(-36, 0, -4)], ["tambores", Vector3(34, 0, -18)], ["selo", Vector3(0, 0, -42)]],
	"dg_gruta": [["entrada", Vector3(0, 0, 40)], ["salao", Vector3(-20, 0, 22)], ["chefe", Vector3(8, 0, -30)]],
	"dg_catacumbas": [["entrada", Vector3(0, 0, 40)], ["vestibulo", Vector3(0, 0, 22)], ["oeste", Vector3(-30, 0, 18)], ["capitao", Vector3(-24, 0, -32)], ["alcova", Vector3(40, 0, 38)], ["viuva", Vector3(24, 0, -32)], ["selo", Vector3(0, 0, -6)]],
	"dg_catacumbas_trono": [["galeria", Vector3(0, 0, 18)], ["trono", Vector3(0, 0, -14)]],
	"dg_coracao": [["entrada", Vector3(0, 0, 40)], ["raizes", Vector3(0, 0, 24)], ["seiva", Vector3(-30, 0, -8)], ["trono", Vector3(8, 0, -40)]],
	"dg_pedreira": [["entrada", Vector3(0, 0, 40)], ["mineiros", Vector3(0, 0, 26)], ["musgo", Vector3(-36, 0, 18)], ["ancestral", Vector3(-30, 0, -38)],
		["cristal", Vector3(36, 0, 18)], ["guardia", Vector3(30, 0, -38)], ["veio", Vector3(0, 0, -8)]],
	"dg_pedreira_coracao": [["galeria", Vector3(0, 0, 22)], ["coracao", Vector3(0, 0, -16)]],
	"dg_ninho": [["entrada", Vector3(0, 0, 40)], ["salao", Vector3(20, 0, 22)], ["chefe", Vector3(-8, 0, -30)]],
	"dg_cripta": [["entrada", Vector3(0, 0, 40)], ["salao", Vector3(-20, 0, 22)], ["chefe", Vector3(8, 0, -30)]],
	"field_forest": [["ponte_leste", Vector3(32.2, 0, -2)], ["cristal_posto", Vector3(-2.5, 0, -1.5)], ["herborista", Vector3(-41, 0, 38)], ["cacador", Vector3(62, 0, -14)], ["emboscada", Vector3(38, 0, 88)], ["circulo", Vector3(-27, 0, -92)], ["ninho", Vector3(-60, 0, 86)], ["pedreira", Vector3(-74, 0, -26)],
		["hub", Vector3(0, 0, 5)], ["chegada", Vector3(-100, 0, 9)], ["ponte", Vector3(26, 0, -6)],
		["bandidos_portao", Vector3(52, 0, -40)], ["bandidos_centro", Vector3(66, 0, -56)], ["aranhas", Vector3(-50, 0, -50)],
		["ents", Vector3(56, 0, 54)], ["arvore_mae", Vector3(8, 0, -76)], ["pantano", Vector3(-30, 0, 66)],
		["borda_norte", Vector3(-18, 0, -104)], ["borda_leste", Vector3(94, 0, 25)]],
	"fort_ghoul": [["chegada", Vector3(90, 0, 0)], ["lagoa", Vector3(74, 0, 14)], ["ninho_oeste", Vector3(58, 0, 52)], ["ponte_oeste", Vector3(42.7, 0, 52.7)], ["ponte_leste", Vector3(38.3, 0, -42.5)], ["ninho_leste", Vector3(18, 0, -50)], ["brecha", Vector3(6, 0, 0)], ["patio", Vector3(-22, 0, -4)], ["cranio", Vector3(-50, 0, 0)]],
	"fort_bones": [["chegada", Vector3(0, 0, 90)], ["cemiterio", Vector3(-60, 0, 84)], ["ponte_ossos", Vector3(-6, 0, 50)], ["cripta_oeste", Vector3(-50, 0, 66)], ["cripta_leste", Vector3(52, 0, 16)], ["patamar", Vector3(-20, 0, 0)], ["portao", Vector3(0, 0, 4)], ["patio", Vector3(4, 0, -22)]],
	"fort_frost": [["chegada", Vector3(0, 0, -90)], ["lago", Vector3(12, 0, -56)], ["navio", Vector3(30, 0, -84)], ["acamp_oeste", Vector3(54, 0, -40)], ["acamp_leste", Vector3(-52, 0, -30)], ["ponte_gelo", Vector3(0, 0, -10)], ["patio", Vector3(-4, 0, 22)]],
	"lich_citadel": [["chegada", Vector3(-58.9, 0, 65.4)], ["portao_cidade", Vector3(-47.1, 0, 46.4)], ["avenida", Vector3(-32.4, 0, 30)], ["rua_oeste", Vector3(-66.9, 0, -6.4)],
		["posto_oeste", Vector3(-64.8, 0, -20.7)], ["posto_leste", Vector3(32.5, 0, 53.5)], ["ossuario", Vector3(-7.7, 0, 14.6)], ["anel_leste", Vector3(44.9, 0, 18.9)],
		["portao_palacio", Vector3(-1.3, 0, 1.5)], ["trono", Vector3(20.4, 0, -16.6)], ["cemiterio", Vector3(20.1, 0, -76.1)]],
	"field_ruins": [["cais_bren", Vector3(86, 0, -22)], ["front_oeste", Vector3(-78, 0, -13)], ["torre", Vector3(-66, 0, 24)], ["praca_catedral", Vector3(0, 0, 18)], ["mercado", Vector3(26, 0, 30)], ["quartel", Vector3(-26, 0, -30)], ["portao_oeste", Vector3(-46, 0, 0)],
		["portao_norte", Vector3(0, 0, -46)], ["portao_sul", Vector3(0, 0, 46)], ["front_carnical", Vector3(-76, 0, -6)], ["front_ossos", Vector3(8, 0, -80)],
		["front_gelo", Vector3(-6, 0, 80)], ["cripta", Vector3(20, 0, -80)], ["chegada", Vector3(94, 0, -5)], ["dragonete", Vector3(64, 0, 44)], ["capela", Vector3(90, 0, 18)],
		["ninho", Vector3(-66, 0, 36)], ["coveiro", Vector3(70, 0, -32)]],
	"elf_city": [["praca_arvore", Vector3(12, 0, 14)], ["mercado", Vector3(30, 0, 30)], ["quartel", Vector3(40, 0, -20)], ["jardim", Vector3(-30, 0, 30)],
		["anel_externo", Vector3(-42, 0, -4)], ["casas_norte", Vector3(-6, 0, -46)], ["portao_sul", Vector3(0, 0, 66)], ["chegada", Vector3(0, 0, 92)],
		["forte_matilha", Vector3(16, 0, -76)], ["forte_ninho", Vector3(-40, 0, -68)], ["forte_seiva", Vector3(76, 0, 14)], ["bosque", Vector3(60, 0, -50)],
		["poco", Vector3(-90, 0, 8)], ["cerco", Vector3(30, 0, 74)],
		["ponte_oeste", Vector3(-80.9, 0, 1.7)], ["ponte_sudoeste", Vector3(-53.1, 0, 83.6)], ["margem_oeste", Vector3(-76, 0, 60)]],
}
const TOUR := [["ponte_lago", Vector3(-15.5, 0, 70)], ["anciao", Vector3(2, 0, -8)], ["lenhador", Vector3(-92, 0, -46)], ["eremita", Vector3(47, 0, 96)], ["covil", Vector3(-20, 0, -48)], ["marco", Vector3(-54, 0, 78)], ["gruta", Vector3(84, 0, -29)],
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
var _water_dir := ""         # --water_tour=<pasta>: foto da água em vários mapas (rio, ponte, lago, mar...) e sai
var _water_i := 0
var _water_t := 0.0
var _tour_k := 0                         # foto da parada atual (--tour_seq)
var showcase: Showcase = null     # --showcase=<classe|all> [--skill=<id>] --out=<pasta> [--check]: bancada de skills
var _playtest_dir := ""
var _playtest: Playtest = null
var _soak_left := 0.0
var _soak_brain: BotBrain = null
var _soak_t := 0.0
var _soak_frames := 0
var _soak_ticks0 := 0
var _soak_worst := 0.0

var _soak_map := ""
var _soak_boss := ""            # --soak_boss=<id>: o grupo vai até o chefe e briga com ele (medir FPS na luta)
var _soak_boss_placed := false
var _soak_gpu := 0.0
var _soak_rcpu := 0.0
var _soak_phys := 0.0
var _soak_draws := 0.0

## Só a DECISÃO da partida automática, sem efeito nenhum (a tela inicial chama antes de montar o menu; design/ux/start-flow.md §8).
## Devolve a classe ("" = tela inicial). Decidem: --autostart, --tour, --water_tour, --showcase, --playtest, --soak, --perf;
## --preset/--level/--ascend/--gear são parâmetros e nunca disparam. `returning` (voltou pelo Esc) cancela tudo.
static func autostart_class(args: PackedStringArray, returning: bool) -> String:
	if returning:
		return ""
	var autostart := ""
	if _arg_flag(args, "--tour"):
		autostart = "paladin"
	if _arg_flag(args, "--water_tour"):
		autostart = "paladin"
	if "--autostart" in args or _arg_flag(args, "--autostart"):
		autostart = _arg_value(args, "--autostart", "paladin")
	if _arg_flag(args, "--showcase"):
		var sc_cls := _arg_value(args, "--showcase")
		autostart = sc_cls if GameData.classes.has(sc_cls) else "paladin"
	if _arg_flag(args, "--playtest"):
		autostart = "paladin" if autostart == "" else autostart
	if _arg_flag(args, "--soak"):
		autostart = "berserker" if autostart == "" else autostart
	if "--perf" in args:
		autostart = "paladin"
	return autostart

## `--x=<valor>` está em `args` (como DevArgs.flag, mas sobre uma lista dada).
static func _arg_flag(args: PackedStringArray, name: String) -> bool:
	for a in args:
		if a.begins_with(name + "="):
			return true
	return false

## Valor de `--x=<valor>` em `args` (o último); `default` se não veio.
static func _arg_value(args: PackedStringArray, name: String, default: String = "") -> String:
	var out := default
	var pre := name + "="
	for a in args:
		if a.begins_with(pre):
			out = a.substr(pre.length())
	return out

## Antes do jogo (no main): liga as chaves de medição e monta o que a partida automática pede. A decisão em si é
## `autostart_class` (a tela inicial já a tomou); devolve a mesma classe ("" = partida do jogador).
## `returning` = não é partida automática (voltou pelo Esc / veio do menu): não arma tour nem bancada.
func before_start(returning: bool) -> String:
	var autostart := autostart_class(DevArgs.all(), returning)
	_shot_path = DevArgs.value("--screenshot")
	_tour_map = DevArgs.value("--tour_map", _tour_map)
	if DevArgs.flag("--tour"):
		_tour_dir = DevArgs.value("--tour")
	if DevArgs.flag("--water_tour"):
		_water_dir = DevArgs.value("--water_tour")
	if DevArgs.flag("--showcase") and not returning:
		var sc_cls := DevArgs.value("--showcase")
		showcase = Showcase.new()
		showcase.setup(main, sc_cls, DevArgs.value("--skill"), DevArgs.value("--out"), DevArgs.has("--check"))
	if DevArgs.flag("--gfx"):        # --gfx=<n>: preset de GraphicsSettings só nesta partida (não salva); comparar FPS/imagem
		GraphicsSettings.preset = clampi(int(DevArgs.value("--gfx")), 0, GraphicsSettings.PRESETS.size() - 1)
		GraphicsSettings.apply(main.get_viewport())
	if DevArgs.has("--fx_shadows"):      # medir: efeitos com sombra (como era)
		FxManager.fx_shadows = true
	if DevArgs.has("--no_buff_fx"):     # medir: sem buffs no boneco (BuffAura)
		BuffAura.enabled = false
	if DevArgs.has("--no_prune"):
		KitModel.prune = false
	if DevArgs.has("--no_away"):
		Sim.away_every = 1
	if DevArgs.has("--no_merge"):
		KitModel.merge = false
		RigidMerge.enabled = false
	if DevArgs.has("--no_vcol_merge"):  # fusão antiga do kit: uma superfície por cor
		KitModel.vcol_merge = false
	main._cull_test = DevArgs.value("--cull_test")          # hide|noproc (medir: só esconde / só para de processar)
	if DevArgs.flag("--view_budget"):    # ms por quadro para criar bonecos da fila (0 = tudo de uma vez, como antes)
		main.view_budget_ms = float(DevArgs.value("--view_budget"))
	elif _review_shots():                # foto/filme de revisão: todos os bonecos já no quadro (o orçamento é para jogar)
		main.view_budget_ms = 0.0
	if DevArgs.has("--anim_test"):
		EntityView.anim_test = true
	if DevArgs.has("--no_anim_lod"):
		EntityView.anim_lod = false
	if DevArgs.flag("--cull"):        # medir: distância de corte dos bonecos
		main.VIEW_CULL_DIST = float(DevArgs.value("--cull"))
	_soak_map = DevArgs.value("--soak_map")
	_soak_boss = DevArgs.value("--soak_boss")
	if _soak_boss != "":                 # mapa do chefe: o do spawner dele
		for mid in GameData.maps:
			for sp in GameData.maps[mid].spawners:
				if sp["monster_id"] == _soak_boss:
					_soak_map = mid
	if DevArgs.flag("--playtest"):    # playtest: segue a cadeia principal como jogador e grava log/fotos (game/dev/playtest.gd)
		_playtest_dir = DevArgs.value("--playtest")
	if DevArgs.flag("--soak"):        # joga sozinho (cérebro de bot) por N s e imprime FPS/nós/memória a cada 5 s
		_soak_left = float(DevArgs.value("--soak"))
	if DevArgs.flag("--gather_shot"):   # colhendo minério e erva (fotos <png>_ore.png / <png>_herb.png)
		_gather_shot.call_deferred(DevArgs.value("--gather_shot"))
	if DevArgs.flag("--recall_shot"):   # --recall_shot=<png> [--recall_close]: barreira nas barras, F1-F3 com recargas próprias, volta à cidade (quadros) e interrupção
		_recall_shot.call_deferred(DevArgs.value("--recall_shot"))
	if DevArgs.has("--perf") and not returning:     # mede a cidade cheia por ~8 s e sai (FPS, draw calls, nós, tempo da sim)
		_perf_run()
	if returning:
		autostart = ""
		_tour_dir = ""
		showcase = null
	return autostart

## Modo de revisão que tira foto/filme (o boneco tem de estar lá quando a foto sai): `*shot*`, `*film*`, `--tour`...
static func _review_shots() -> bool:
	for a in DevArgs.all():
		for k in ["shot", "film", "tour", "showcase", "playtest", "sheet"]:
			if a.begins_with("--") and a.split("=")[0].contains(k):
				return true
	return false

## Logo depois do start_game da partida automática: monta a cena de revisão pedida.
func after_start() -> void:
	if DevArgs.has("--return_check"):      # revisão: menu do Esc (foto) e "voltar ao menu"
		_menu_check()
		return
	if DevArgs.flag("--tip_shot"):          # revisão: cartão de dica (--tip=<id>, padrão attack)
		_tip_shot(DevArgs.value("--tip_shot"))
		return
	if DevArgs.flag("--act_end_shot"):      # revisão: festa do fim do Ato I (praça) e a tela de encerramento
		_act_end_shot(DevArgs.value("--act_end_shot"))
		return
	_smoke_test = showcase == null and not DevArgs.has("--perf")
	if DevArgs.flag("--block_shot"):      # fotos do bloqueio e do aparar (escudo: --shield=<id>)
		_smoke_test = false
		_block_shot(DevArgs.value("--block_shot"))
	if DevArgs.flag("--probe_px") or DevArgs.flag("--probe_at"):   # lista o que se desenha perto de um ponto (pixel 1920x1080 ou x,z) e sai
		_smoke_test = false
		_probe_near.call_deferred()
	if showcase:
		main.camera.distance = 9.0
		main.add_child(showcase)
	if DevArgs.flag("--map_shot"):  # foto do mapa em tela cheia (M) e sai
		_smoke_test = false
		_map_shot.call_deferred(DevArgs.value("--map_shot"))
	if DevArgs.flag("--quests"):    # começa com estas quests concluídas (revisar conquista: --quests=dw_ghoul_boss)
		for qid in DevArgs.value("--quests").split(","):
			if not Sim.player.quests_completed.has(qid):
				Sim.player.quests_completed.append(qid)
		MapBuilder.apply_conquest(main.map_node)
	if DevArgs.flag("--mount_kind"):    # --mount_kind=dire_wolf: libera (missão) e escolhe o bicho (revisar a montaria)
		var mk := DevArgs.value("--mount_kind")
		var mq: String = Balance.MOUNT_KINDS.get(mk, {}).get("quest", "")
		if mq != "" and not Sim.player.quests_completed.has(mq):
			Sim.player.quests_completed.append(mq)
		Sim.set_mount_kind(Sim.player, mk)
	if DevArgs.has("--mount"):      # começa a cavalo (revisar a montaria)
		Sim.player.mounted = true
	if DevArgs.has("--ascend") and not DevArgs.flag("--bag_shot"):     # ascendido (nível 35 ou --level): teias gastas como bot, barra de 10
		_ascend_player()
	if DevArgs.has("--loot_demo"):  # amostra de drops ao lado do jogador (revisar o baú)
		_smoke_test = false
		_loot_demo()
	if DevArgs.flag("--gear"):      # --gear=<set_id>: começa vestindo um conjunto (revisar visual/ícones do lendário no smoke)
		_wear_set(DevArgs.value("--gear"))
	if DevArgs.flag("--bag_shot"):      # foto da bolsa e da ficha com uma amostra de cada tipo de item
		_smoke_test = false
		_bag_shot(DevArgs.value("--bag_shot"))
	if DevArgs.flag("--boss_film"):     # --boss_film=<chefe>[,..] --out=<pasta>: cada skill do chefe lançada num grupo parado, 3 quadros por skill
		_smoke_test = false
		_boss_film(Array(DevArgs.value("--boss_film").split(",")), DevArgs.value("--out"))
	if DevArgs.flag("--event_shot"):    # --event_shot=<png> [--event_point=N]: evento de estrada em andamento (RoadEventSystem) e sai
		_smoke_test = false
		_event_shot(DevArgs.value("--event_shot"))
	if DevArgs.flag("--siege_shot"):    # --siege_shot=<pasta> [--quests=...]: Cerco Vivo do Porto (cais, brechas, cenário, assédio, leva, Chamas) e sai
		_smoke_test = false
		_siege_shot(DevArgs.value("--siege_shot"))
	if DevArgs.flag("--raid_shot"):     # --raid_shot=<png>: investida élfica na Floresta (fotos _marcha e _portao) e sai
		_smoke_test = false
		_raid_shot(DevArgs.value("--raid_shot"))
	if DevArgs.flag("--siege_perf"):    # --siege_perf=<png>: último front do Bastião (Covil e Ossos retomados) no portão sul; FPS e sim
		_smoke_test = false
		_siege_perf(DevArgs.value("--siege_perf"))
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
	if DevArgs.flag("--aura_shot"):     # --aura_shot=<png>: bando da Horda com Agitador ao lado do jogador (anel do raio da aura no chão, buffados marcados)
		_smoke_test = false
		_aura_shot(DevArgs.value("--aura_shot"))
	if DevArgs.flag("--quest_shot"):    # --quest_shot=<png>: seta amarela do minimapa (objetivo neste mapa / noutro mapa) e sai
		_smoke_test = false
		_quest_shot(DevArgs.value("--quest_shot"))
	if DevArgs.flag("--morph_film"):    # --morph_film=<png> [--morph=phantom|demon|wolf|bear]: quadros da transformação de perto
		_smoke_test = false
		_morph_film(DevArgs.value("--morph_film"), DevArgs.value("--morph", "phantom"))
	if DevArgs.flag("--buff_shot"):     # --buff_shot=<pasta> [--only=<id>,...] [--close]: cada buff num boneco (ao lado de um sem buff), câmera do jogo
		_smoke_test = false
		_buff_shot(DevArgs.value("--buff_shot"), DevArgs.value("--only"))
	if DevArgs.flag("--spot_shot"):     # --spot_shot=<png> --spot=<mapa>:<x>,<z> [--dist=14] [--wait=3] [--hide] [--form=<forma>]: foto de um ponto do mapa (adereços, vida)
		_smoke_test = false
		_spot_shot.call_deferred(DevArgs.value("--spot_shot"))
	if DevArgs.flag("--sig_shot"):      # --sig_shot=<pasta> [--boss=<id>,...]: aviso de cada assinatura de chefe (GDD act2-boss-signatures)
		_smoke_test = false
		_sig_shot.call_deferred(DevArgs.value("--sig_shot"))
	if DevArgs.flag("--lock_shot"):     # --lock_shot=<pasta> [--boss=<id>]: Tab trava no chefe, D gira em volta e W chega perto (fotos + raio no log)
		_smoke_test = false
		_lock_shot.call_deferred(DevArgs.value("--lock_shot"))
	if DevArgs.flag("--carry_shot"):    # --carry_shot=<png>: um morador com cada carga (caixa, saco, estaca, pedra), de 3/4 (_jogo) e de lado (_lado)
		_smoke_test = false
		_carry_shot.call_deferred(DevArgs.value("--carry_shot"))
	if DevArgs.flag("--ride_shot"):     # --ride_shot=<pasta>: Paladino ascendido a cavalo: básico, Carga, Pisotear e Modo Arcano (asas)
		_smoke_test = false
		_ride_shot(DevArgs.value("--ride_shot"))
	if DevArgs.flag("--choir_shot"):    # --choir_shot=<png>: Bispo ascendido: Barreira Sagrada + Anjo Guardião (_cupula) e a bênção (_bencao)
		_smoke_test = false
		_choir_shot.call_deferred(DevArgs.value("--choir_shot"))
	if DevArgs.flag("--asc_shot"):      # --asc_shot=<png>: Ranger ascendido: torreta (_torreta) e Salto Dracônico (_salto, _queda); Assassino: clone (_clone, _golpe) e Execução (_execucao)
		_smoke_test = false
		_asc_shot.call_deferred(DevArgs.value("--asc_shot"))
	if DevArgs.flag("--lord_shot"):     # --lord_shot=<png>: Necromante ascendido: Pacto + Miasma (_miasma), Marca da Cova (_cova), Forma de Lich (_lich)
		_smoke_test = false
		_lord_shot.call_deferred(DevArgs.value("--lord_shot"))
	if DevArgs.flag("--falcon_shot"):   # --falcon_shot=<png>: Caçador ascendido: falcão planando (_falcao), mergulho (_mergulho) e Revoada (_revoada)
		_smoke_test = false
		_falcon_shot.call_deferred(DevArgs.value("--falcon_shot"))
	if DevArgs.flag("--buff_cast"):     # --buff_cast=<skill_id> [--buff_hold]: o jogador lança o buff no início (com --buff_hold dura até o --screenshot)
		_cast_buff_at_start.call_deferred(DevArgs.value("--buff_cast"))

## Chamado pelo _process do Main com o jogo rodando.
func tick(delta: float) -> void:
	if _playtest_dir != "":
		if _playtest == null and Sim.player != null:
			_smoke_test = false
			Engine.time_scale = float(DevArgs.value("--speed", "1"))
			_playtest = Playtest.new()
			_playtest.setup(main, _playtest_dir, float(DevArgs.value("--playtest_time", "600")))
		if _playtest and not _playtest.tick(delta):
			get_tree().quit()
		return
	if _soak_left > 0.0:
		_soak(delta)
	if _water_dir != "":
		_water_tour(delta)
	elif _tour_dir != "":
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

## Bando com Agitador parado (e o Agitador-Mor mais longe): anel do raio no chão, quem está dentro com a marca do buff
## e um de fora sem ela. Fotos <png> (Agitador) e <png>_boss.png (Agitador-Mor).
func _aura_shot(path: String) -> void:
	var p: SimEntity = Sim.player
	p.brain = null
	Sim._change_map(p, "field_coast", Vector3(4, 0, 6))
	await get_tree().create_timer(1.0).timeout
	for e in Sim.map_entities("field_coast").duplicate():
		if e.kind == SimEntity.Kind.MONSTER:
			Sim.despawn(e)
	Sim.maps["field_coast"]["spawners"].clear()
	var shots := [["goblin_agitator", Vector3(0, 0, -7), path], ["boss_agitator_lord", Vector3(60, 0, -9), path.replace(".png", "_boss.png")]]
	for sh in shots:
		var c: Vector3 = p.position + sh[1]
		var reach := FxManager.mob_aura_reach(GameData.monsters[sh[0]])
		var pack := [[sh[0], Vector3.ZERO], ["goblin_lancer", Vector3(-3, 0, 2)], ["goblin_lancer", Vector3(3.5, 0, 1.5)], ["orc_recruit", Vector3(0, 0, 4)],
			["goblin_impaler", Vector3(-reach * 0.8, 0, -1)], ["goblin_lancer", Vector3(reach + 2.5, 0, 2)]]      # o último fica fora do raio
		for it in pack:
			var e := Sim.spawn_monster(GameData.monsters[it[0]], "field_coast", c + it[1])
			e.brain = null
			e.facing = 0.0
	main.camera.distance = main.camera.max_distance
	for sh in shots:
		p.position = p.position + Vector3(sh[1].x, 0, 0)
		await get_tree().create_timer(2.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(sh[2])
		print("AURA_SHOT " + str(sh[2]))
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

## Buff no boneco (BuffAura): para cada buff de BuffLooks (ou --only), dois bonecos da classe dona lado a lado —
## à esquerda sem nada, à direita com o buff — fotografados pela câmera do jogo no estouro (_pop) e parado.
## Saída: <pasta>/<id>.png, <pasta>/<id>_pop.png e <pasta>/folha.png (todas as fotos paradas, 6 por linha, ordem do log).
const BUFF_SHOT_EXTRA := ["shield@necromancer", "shield@elementalist", "bastion_aura@ally", "blessing@ally",
	"dbf_slow", "dbf_root", "dbf_stun", "dbf_burn", "dbf_poison", "dbf_curse"]
const BUFF_SHOT_CLASS := {"legend_frenzy": "berserker", "bastion": "paladin", "juramento": "paladin", "wild_run": "druid", "shield": "paladin",
	"elixir": "berserker", "stoneskin": "paladin", "apex_tempest": "berserker", "apex_cadence": "assassin",
	"fus_aurora": "bishop"}

func _buff_shot(dir: String, only: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var p: SimEntity = Sim.player
	p.brain = null
	Sim._change_map(p, "city_aldara", Vector3(DevArgs.value("--buff_at", "4,0,34").split(",")[0].to_float(), 0, DevArgs.value("--buff_at", "4,0,34").split(",")[2].to_float()))
	main.camera.distance = 9.0 if DevArgs.has("--close") else 24.0
	await get_tree().create_timer(1.2).timeout
	if main.views.has(p.id):            # o jogador fica no meio (a câmera o segue), invisível
		var pv: EntityView = main.views[p.id]
		pv.model_root.visible = false
		pv.hide_name_dev()
		if pv.hp_bar:
			pv.hp_bar.visible = false
	var ids: Array = []
	for id in BuffLooks.LOOKS:
		if BuffLooks.LOOKS[id][0] != "form":
			ids.append(id)
	ids += BUFF_SHOT_EXTRA
	if only != "":
		ids = Array(only.split(","))
	var shots: Array = []
	for id in ids:
		var parts: PackedStringArray = str(id).split("@")
		var bid: String = parts[0]
		var extra: String = parts[1] if parts.size() > 1 else ""
		var cls_id := _buff_class(bid, extra)
		var cls: ClassDef = GameData.classes.get(cls_id, p.class_def)
		var cam_pos: Vector3 = main.camera.cam.global_position
		var pair: Array = []
		for k in 2:
			var b := Sim.spawn_bot(cls, "B%d" % k, p.map_id, p.position + Vector3(-0.9 + 1.8 * k, 0, 0), 30)
			b.brain = null
			b.ct = {}
			b.buffs.clear()
			b.recompute_stats()
			b.face_towards(Vector3(cam_pos.x, 0, cam_pos.z))
			pair.append(b)
		await get_tree().create_timer(0.8).timeout
		for v in main.views.values():        # só o par aparece (bots, guardas e o jogador somem da foto)
			var ev: EntityView = v
			if not pair.has(ev.entity):
				ev.model_root.visible = false
				ev.hide_name_dev()
				if ev.hp_bar:
					ev.hp_bar.visible = false
		var t: SimEntity = pair[1]
		_put_buff_demo(t, bid, extra, pair[0])
		for b in t.buffs:
			if float(b.get("remaining", 0.0)) != INF:
				b["remaining"] = 999.0
		await get_tree().create_timer(0.12).timeout
		await RenderingServer.frame_post_draw
		var pop := _buff_crop(p.position)
		await get_tree().create_timer(1.3).timeout
		await RenderingServer.frame_post_draw
		var still := _buff_crop(p.position)
		var fname := str(id).replace("@", "_")
		pop.save_png(dir.path_join(fname + "_pop.png"))
		still.save_png(dir.path_join(fname + ".png"))
		shots.append(still)
		print("BUFF_SHOT %d %s (%s) -> %s" % [shots.size(), id, cls_id, dir.path_join(fname + ".png")])
		for b in pair:
			Sim.despawn(b)
		await get_tree().create_timer(0.2).timeout
	if shots.size() > 1:
		var w: int = shots[0].get_width()
		var h: int = shots[0].get_height()
		var cols := mini(6, shots.size())
		var rows := (shots.size() + cols - 1) / cols
		var sheet := Image.create(w * cols, h * rows, false, shots[0].get_format())
		for i in shots.size():
			sheet.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
		sheet.save_png(dir.path_join("folha.png"))
	print("BUFF_SHOT_END %d" % shots.size())
	get_tree().quit()

func _buff_class(bid: String, extra: String) -> String:
	if extra != "" and extra != "ally":
		return extra
	if BUFF_SHOT_CLASS.has(bid):
		return BUFF_SHOT_CLASS[bid]
	for sid in GameData.skills:
		var s: SkillDef = GameData.skills[sid]
		if s.effects.get("buff") is Dictionary and s.effects["buff"].get("id", "") == bid and s.class_id != "":
			return s.class_id
	return Sim.player.class_def.id

## Põe o buff (ou debuff de amostra, "dbf_*") como a sim poria: pela skill que o dá, pelo item, ou o dicionário do sistema.
func _put_buff_demo(t: SimEntity, bid: String, extra: String, other: SimEntity) -> void:
	match bid:
		"dbf_slow":
			t.debuffs.append({"kind": "slow", "remaining": 999.0, "pct": 30.0})
			return
		"dbf_root":
			t.debuffs.append({"kind": "root", "remaining": 999.0})
			return
		"dbf_stun":
			t.set_state(SimEntity.State.STUNNED, 999.0)
			return
		"dbf_burn":
			t.debuffs.append({"kind": "dot", "remaining": 999.0, "dps": 0.0, "fire": true, "src": -1})
			return
		"dbf_poison":
			t.debuffs.append({"kind": "dot", "remaining": 999.0, "dps": 0.0, "src": -1})
			return
		"dbf_curse":
			t.debuffs.append({"kind": "curse", "remaining": 999.0, "taken_pct": 0.0, "weaken_pct": 0.0})
			return
		"shield":
			Sim._apply_effects(t, t, {"shield": {"amount_pct_hp": 25, "duration": 6}}, 1.0)
			return
		"legend_frenzy":
			t.put_buff({"id": "legend_frenzy", "remaining": 999.0, "stacks": 3, "aspd_pct": 15.0})
			return
		"bastion":
			t.put_buff({"id": "bastion", "remaining": 999.0, "def_pct": 10})
			return
		"juramento":
			t.put_buff({"id": "juramento", "remaining": 999.0, "stacks": 3})
			return
	for iid in GameData.items:
		var it: ItemDef = GameData.items[iid]
		if it.consume.get("buff") is Dictionary and it.consume["buff"].get("id", "") == bid:
			Sim._apply_effects(t, t, {"buff": it.consume["buff"]}, 1.0)
			return
	for tid in GameData.talents:
		var td: TalentDef = GameData.talents[tid]
		if td.mods.get("buff") is Dictionary and td.mods["buff"].get("id", "") == bid:
			Sim._apply_effects(t, t, {"buff": td.mods["buff"]}, 1.0)
			return
	for sid in GameData.skills:
		var s: SkillDef = GameData.skills[sid]
		if s.effects.get("buff") is Dictionary and s.effects["buff"].get("id", "") == bid:
			if extra == "ally":            # aura/bênção recebida de um aliado: a versão fraca (só a borda)
				var nb: Dictionary = s.effects["buff"].duplicate()
				nb.erase("toggle")
				nb["aura_from"] = other.id
				nb["remaining"] = 999.0
				t.put_buff(nb)
				t.recompute_stats()
				return
			var fx := {"buff": s.effects["buff"]}
			if s.effects.has("shield"):
				fx["shield"] = s.effects["shield"]
			Sim._apply_effects(t, t, fx, 1.0)
			return
	if BuffLooks.SYSTEM_BUFFS.has(bid):      # buff que a sim põe no código (Fusões etc.): o id basta para o visual
		t.put_buff({"id": bid, "remaining": 999.0, "stacks": 3})
		return
	push_warning("buff_shot: sem fonte para " + bid)

## Recorte da tela em volta dos dois bonecos (o par fica no centro da câmera, que segue o jogador escondido).
func _buff_crop(at: Vector3) -> Image:
	var img := get_viewport().get_texture().get_image()
	var c: Vector2 = main.camera.cam.unproject_position(at + Vector3(0, 0.9, 0))
	var vs := get_viewport().get_visible_rect().size
	var sx := img.get_width() / vs.x
	var ch := int(img.get_height() * (0.62 if DevArgs.has("--close") else 0.3))
	var cw := int(ch * 1.25)
	var r := Rect2i(int(c.x * sx) - cw / 2, int(c.y * sx) - ch / 2, cw, ch)
	r = r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	return img.get_region(r)

## --ascend: o jogador ascendido (nível >= ASC_LEVEL, missão hx_asc_<classe>), com a teia comum e a de ascensão gastas como
## um bot da build e a barra de 10 montada (7-0 = ascensão). Revisar a barra e a aba Ascensão da janela K.
func _ascend_player() -> void:
	var ap: SimEntity = Sim.player
	ap.level = maxi(ap.level, Balance.ASC_LEVEL)
	if ap.build_id == "" and not ap.class_def.builds.is_empty():
		ap.build_id = ap.class_def.builds[int(DevArgs.value("--build_i", "0"))]["id"]
	if not ap.quests_completed.has("hx_asc_" + ap.class_def.id):
		ap.quests_completed.append("hx_asc_" + ap.class_def.id)
	if not DevArgs.flag("--level"):
		ProgressionSystem.bot_spend(Sim, ap, true)
	ProgressionSystem.bot_spend_asc(Sim, ap)
	Sim._slot_bot(ap)
	ap.recompute_stats()
	ap.heal_full()
	Events.equipment_changed.emit(ap.id)

## --spot_shot=<png>: leva o jogador (parado) a um ponto de um mapa e fotografa com a câmera do jogo. Revisar adereços de
## zona, NPCs que carregam carga, rebanho; --form=<forma> põe o jogador na forma (ex.: lich) antes da foto.
## Com --autostart: --level=N (teia gasta como bot da build, igual ao --tour) e --mount (fica montado: o jogador
## não leva golpe direto durante a espera, senão cai do cavalo). --spot ausente ou mapa inválido = erro e sai
## (antes caía calado em Aldara, nível 1).
func _spot_shot(path: String) -> void:
	var spot := DevArgs.value("--spot")
	var xz := spot.get_slice(":", 1).split(",")
	var map_id := spot.get_slice(":", 0)
	if not GameData.maps.has(map_id) or xz.size() < 2:
		push_error("SPOT_SHOT: use --spot=<mapa>:<x>,<z> (veio '%s')" % spot)
		get_tree().quit(1)
		return
	var at := Vector3(float(xz[0]), 0, float(xz[1]))
	Sim.sync()                                  # o tick pode estar rodando na thread (SimSync)
	var p: SimEntity = Sim.player
	p.brain = null
	var form := DevArgs.value("--form")
	if DevArgs.flag("--level"):
		p.level = int(DevArgs.value("--level"))
		if p.build_id == "" and form != "":
			p.build_id = _build_for_form(p, form)       # --form=wolf: teia gasta como a build do Lobo, não a 1ª
		if p.build_id == "" and not p.class_def.builds.is_empty():
			p.build_id = p.class_def.builds[0]["id"]
		ProgressionSystem.bot_spend(Sim, p, true)
		p.recompute_stats()
		Events.equipment_changed.emit(p.id)
	Sim._change_map(p, map_id, at)
	if DevArgs.has("--mount") and not GameData.maps[map_id].no_mount():     # o after_start só liga a flag; o boneco precisa do aviso
		p.mounted = true
		Events.post(&"mount_changed", p.id, true)
	p.iframe_left = 2.0                         # cobre a chegada (1 s) até o laço da espera
	main.camera.distance = float(DevArgs.value("--dist", "14"))
	if form != "":
		_arm_for_form(p, form)      # a forma exige arma (FORM_REQUIRES): sem ela o recompute_stats volta à forma humana
		if p.form != form:          # liga/desliga: não desligar a que o --gear já ligou
			Sim._apply_effects(p, p, {"form": form}, 1.0)
	await get_tree().create_timer(1.0).timeout
	Sim.sync()
	p.position = at
	p.stats.max_hp = 1.0e9
	p.hp = 1.0e9
	if DevArgs.has("--hide") and main.views.has(p.id):
		main.views[p.id].visible = false
	var wait_end := Time.get_ticks_msec() + int(float(DevArgs.value("--wait", "3")) * 1000.0)
	while Time.get_ticks_msec() < wait_end:     # turista: golpe direto passa (não cai do cavalo, foto sem tela de morte)
		Sim.sync()
		p.iframe_left = 1.0
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("SPOT_SHOT %s %s draws=%d" % [spot, path, int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))])
	get_tree().quit()

## Build da classe cuja arma serve à forma (lobo -> Fera, urso -> Guardião); "" se nenhuma.
func _build_for_form(p: SimEntity, form: String) -> String:
	var req: String = str(Balance.FORM_REQUIRES.get(form, ""))
	var t := req.substr(5) if req.begins_with("dual_") else req
	for b in p.class_def.builds:
		if (b["main"] as Array).has(t):
			return str(b["id"])
	return ""

## Veste a arma (e a 2ª, se dupla) que a forma exige: da bolsa se tiver, senão a comum de menor nível do tipo.
func _arm_for_form(p: SimEntity, form: String) -> void:
	var req: String = str(Balance.FORM_REQUIRES.get(form, ""))
	if req == "" or p.stats.meets([req]):
		return
	var dual := req.begins_with("dual_")
	var t := req.substr(5) if dual else req
	for to_off in ([false, true] if dual else [false]):
		var pick := ""
		for iid in p.inventory:
			var it: ItemDef = GameData.items.get(iid)
			if it and it.weapon_type == t and int(p.inventory[iid]) > 0:
				pick = iid
				break
		if pick == "":
			var best_lv := 1 << 30
			for iid in GameData.items:
				var it: ItemDef = GameData.items[iid]
				if it.weapon_type == t and it.slot == ItemDef.Slot.WEAPON and not it.is_legendary() and it.set_id == "" and it.level_req < best_lv:
					best_lv = it.level_req
					pick = iid
			if pick == "":
				return
			p.add_item(pick)
		Sim.equip(p, pick, to_off)
	p.recompute_stats()
	Events.equipment_changed.emit(p.id)

## --carry_shot=<png>: moradores parados com cada carga de CarryPose lado a lado (altura da carga no ombro/braços).
## Duas fotos: câmera do jogo de perto (_jogo) e quase de lado (_lado).
func _carry_shot(path: String) -> void:
	var p: SimEntity = Sim.player
	p.brain = null
	var at := Vector3(-14, 0, 40)
	Sim._change_map(p, "city_aldara", at)
	await get_tree().create_timer(1.0).timeout
	Sim.sync()
	var kinds := ["carry_crate", "carry_sack", "carry_log", "carry_rock"]
	if DevArgs.flag("--carry"):         # --carry=cart_draft: só essa carga (carroça de tiro com o cavalo), com mais distância
		kinds = [DevArgs.value("--carry")]
	for i in kinds.size():
		var n := {"id": "carry_demo_%d" % i, "name": kinds[i], "pos": at + Vector3(-2.7 + i * 1.8, 0, -2.0), "role": "villager",
			"color": Color(0.6, 0.5, 0.4), "dialog": [], "facing": 20.0, "carry": kinds[i], "look_seed": 900 + i * 7}
		if DevArgs.flag("--carry"):     # uma carga só: no centro da foto, de lado (--facing=<graus>)
			n["pos"] = at
			n["facing"] = float(DevArgs.value("--facing", "110"))
		Sim._spawn_npc(n, p.map_id)
	await get_tree().create_timer(1.5).timeout
	Sim.sync()
	if main.views.has(p.id):
		main.views[p.id].model_root.visible = false
		main.views[p.id].hide_name_dev()
	main.camera.distance = 11.0 if DevArgs.flag("--carry") else 7.0
	for shot in [["_jogo", 52.0], ["_lado", 12.0]]:
		main.camera.pitch_deg = float(shot[1])
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(path.replace(".png", str(shot[0]) + ".png"))
	print("CARRY_SHOT " + path)
	get_tree().quit()

## --ride_shot=<pasta>: Combate Montado (ascensão do Paladino). Um bot paladino ascendido a cavalo, de 3/4 para a câmera,
## golpeia um boneco: fotos no impacto do básico, da Carga Montada e do Pisotear, e do Modo Arcano (desce, rajada, asas).
## Por último a Muralha a Cavalo (escudo erguido; --shield_turn=<graus> gira o inimigo a partir da câmera) e sai.
func _ride_shot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var p: SimEntity = Sim.player
	p.brain = null
	Sim._change_map(p, "city_aldara", Vector3(4, 0, 34))
	main.camera.distance = 11.0
	await get_tree().create_timer(1.2).timeout
	Sim.sync()
	if main.views.has(p.id):
		main.views[p.id].model_root.visible = false
		main.views[p.id].hide_name_dev()
	var r: SimEntity = Sim.spawn_bot(GameData.classes["paladin"], "Cavaleiro", p.map_id, p.position + Vector3(-1.5, 0, 0), 30)
	r.brain = null
	r.level = Balance.ASC_LEVEL
	r.quests_completed.append("hx_asc_paladin")
	if DevArgs.flag("--mount_kind"):      # --mount_kind=dire_wolf: o cavaleiro monta o lobo atroz
		r.quests_completed.append(str(Balance.MOUNT_KINDS.get(DevArgs.value("--mount_kind"), {}).get("quest", "")))
		Sim.set_mount_kind(r, DevArgs.value("--mount_kind"))
	for sid in ProgressionSystem.ascension_skills(r):
		r.learned[sid] = true
	r.ensure_slots()
	for i in 3:
		r.skills[Balance.SKILL_SLOTS + i] = GameData.skills[["pal_mounted_charge", "pal_trample", "pal_arcane_mode"][i]]     # barra 7-9
	r.recompute_stats()
	r.heal_full()
	r.mounted = true
	var dummy: SimEntity = Sim.spawn_monster(GameData.monsters["slime"], p.map_id, r.position + Vector3(2.4, 0, 0.6))
	dummy.brain = null
	dummy.stats.max_hp = 1.0e9
	dummy.hp = 1.0e9
	r.face_towards(dummy.position)
	var home: Vector3 = r.position
	await get_tree().create_timer(1.0).timeout
	var shots: Array = []
	for step in [["basico", -1], ["pisotear", 1], ["carga", 0], ["asas", 2]]:
		Sim.sync()
		r.set_state(SimEntity.State.IDLE)
		r.current_skill = null
		r.cooldowns.clear()
		r.mp = r.stats.max_mp
		r.position = home
		dummy.position = home + (Vector3(7.0, 0, 0.6) if step[0] == "carga" else Vector3(2.4, 0, 0.6))
		r.face_towards(dummy.position)
		var startup := 0.15
		if int(step[1]) < 0:
			var bs: SkillDef = MountedCombat.mounted_basic(Sim, r.basic_skill)
			Sim._start_skill(r, bs, -1, dummy.position)
			startup = bs.startup
		else:
			Sim.try_cast(r, Balance.SKILL_SLOTS + int(step[1]), dummy.position, Sim.maps[r.map_id])
			startup = r.current_skill.startup if r.current_skill else 0.15
		await get_tree().create_timer(maxf(0.05, startup * 0.9) if step[0] != "asas" else 0.9).timeout
		await RenderingServer.frame_post_draw
		var img := _buff_crop(r.position)
		img.save_png(dir.path_join("montado_%s.png" % step[0]))
		shots.append(img)
		print("RIDE_SHOT %s montado=%s asas=%s pos=%s img=%dx%d" % [step[0], str(r.mounted), str(Sim.arcane_on(r)), str(r.position), img.get_width(), img.get_height()])
		await get_tree().create_timer(0.6).timeout
		Sim.sync()
		if step[0] != "asas":
			r.mounted = true
	# Muralha a Cavalo (Guardião 45): escudo erguido na sela
	Sim.sync()
	MountedCombat.arcane_off(Sim, r, "")
	r.build_id = "guardiao"
	Sim._gear_bot(r)
	r.recompute_stats()
	r.set_state(SimEntity.State.IDLE)
	r.current_skill = null
	r.position = home
	r.mounted = true
	# o escudo encara o inimigo: com o inimigo de lado para a câmera ele aparece de perfil (fino). Inimigo a 3/4 entre
	# a câmera e o lado, para a face do escudo aparecer por cima do pescoço do cavalo.
	var to_cam: Vector3 = main.camera.cam.global_position - home
	to_cam.y = 0.0
	dummy.position = home + to_cam.normalized().rotated(Vector3.UP, deg_to_rad(float(DevArgs.value("--shield_turn", "-35")))) * 2.6
	r.face_towards(dummy.position)
	r.is_blocking = true
	r.set_state(SimEntity.State.BLOCKING)
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var bimg := _buff_crop(r.position)
	bimg.save_png(dir.path_join("montado_escudo.png"))
	shots.append(bimg)
	print("RIDE_SHOT escudo montado=%s bloqueando=%s escudo=%s" % [str(r.mounted), str(r.is_blocking), str(r.stats.has_shield)])
	if shots.size() > 1:
		var w: int = shots[0].get_width()
		var h: int = shots[0].get_height()
		var sheet := Image.create(w * shots.size(), h, false, shots[0].get_format())
		for i in shots.size():
			sheet.blit_rect(shots[i], Rect2i(0, 0, mini(w, shots[i].get_width()), mini(h, shots[i].get_height())), Vector2i(i * w, 0))
		sheet.save_png(dir.path_join("montado_folha.png"))
	print("RIDE_SHOT_END %d" % shots.size())
	get_tree().quit()
## Ascensão do Bispo (Ato II, Coro Celeste): ascende o jogador com dois aliados de grupo e um boneco inimigo, chama o
## Anjo Guardião, ergue a Barreira Sagrada e fotografa; depois lança as bênçãos e fotografa. Sai no fim.
func _choir_shot(path: String) -> void:
	await get_tree().create_timer(1.0).timeout
	Sim.sync()
	var p := Sim.player
	p.level = maxi(p.level, Balance.RES_LEVEL)
	if not p.quests_completed.has("hx_asc_bishop"):
		p.quests_completed.append("hx_asc_bishop")
	var m: Dictionary = Sim.maps[p.map_id]
	var def: MapDef = m["def"]
	p.position = MapGeometry.random_walkable(Sim, def, def.town_center + Vector3(-9, 0, 9), 1.0)
	p.facing = PI * 0.75
	var fwd := p.forward()
	var side := Vector3(-fwd.z, 0, fwd.x)
	var mates: Array = []
	for row in [["paladin", "guardiao", fwd * 3.0 + side * 1.5], ["berserker", "carniceiro", fwd * 2.0 - side * 2.0]]:
		var b := Sim.spawn_bot(GameData.classes[row[0]], "Aliado", p.map_id, p.position + row[2], 35)
		b.brain = null
		b.hp = b.stats.max_hp * 0.45
		b.facing = p.facing
		Sim.party_invite(p, b)
		Sim.party_accept(b)
		mates.append(b)
	var d := Sim.spawn_monster(GameData.monsters["golem"], p.map_id, p.position + fwd * 9.0)
	d.brain = null
	d.stats.max_hp = 1.0e7
	d.hp = d.stats.max_hp
	p.ensure_slots()
	var ids := ["bis_choir_angel", "bis_choir_barrier", "bis_choir_wings", "bis_choir_aegis"]
	for i in ids.size():
		p.learned[ids[i]] = true              # (sem teia de ascensão comprada: só a foto)
		p.skills[Balance.SKILL_SLOTS + i] = GameData.skills[ids[i]]
	p.mp = p.stats.max_mp
	p.cooldowns.clear()
	await get_tree().create_timer(0.4).timeout
	Sim.sync()
	print("CHOIR_SHOT anjo cast=%s" % str(Sim.try_cast(p, Balance.SKILL_SLOTS, p.position, m)))
	await get_tree().create_timer(1.0).timeout
	Sim.sync()
	print("CHOIR_SHOT barreira cast=%s" % str(Sim.try_cast(p, Balance.SKILL_SLOTS + 1, p.position + fwd * 2.0, m)))
	await get_tree().create_timer(2.0).timeout
	Sim.sync()
	print("CHOIR_SHOT anjos=%d cupulas=%d" % [ChoirSystem.angels_of(Sim, p).size(), ChoirSystem.barriers(m).size()])
	get_viewport().get_texture().get_image().save_png(path.trim_suffix(".png") + "_cupula.png")
	for i in [2, 3]:
		Sim.sync()
		p.mp = p.stats.max_mp
		print("CHOIR_SHOT bencao cast=%s" % str(Sim.try_cast(p, Balance.SKILL_SLOTS + i, p.position, m)))
		await get_tree().create_timer(0.9).timeout
	get_viewport().get_texture().get_image().save_png(path.trim_suffix(".png") + "_bencao.png")
	print("CHOIR_SHOT done")
	get_tree().quit()

## Ascensão do Ranger (Ato II): ascende o jogador, monta a torreta perto de dois bonecos e fotografa; depois troca para a
## lança, salta e fotografa no alto e no pouso. Sai no fim.
func _asc_shot(path: String) -> void:
	await get_tree().create_timer(1.0).timeout
	Sim.sync()
	var p := Sim.player
	if p.class_def.id == "assassin":
		_asc_shot_assassin(path)
		return
	p.level = maxi(p.level, Balance.ASC_LEVEL)
	if not p.quests_completed.has("hx_asc_ranger"):
		p.quests_completed.append("hx_asc_ranger")
	var m: Dictionary = Sim.maps[p.map_id]
	var def: MapDef = m["def"]
	p.position = MapGeometry.random_walkable(Sim, def, def.town_center + Vector3(-9, 0, 9), 1.0)     # praça aberta, longe de porta/portal
	p.facing = PI * 0.75
	var fwd := p.forward()
	var dummies: Array = []
	for off in [Vector3(-1.5, 0, 0), Vector3(1.5, 0, 0)]:
		var d := Sim.spawn_monster(GameData.monsters["golem"], p.map_id, p.position + fwd * 9.0 + off)
		d.brain = null
		d.stats.max_hp = 1.0e7
		d.hp = d.stats.max_hp
		dummies.append(d)
	var shots := {"rifle": ["ran_turret", fwd * 3.5 + Vector3(-2.0, 0, 0)], "spear": ["ran_dragon_jump", fwd * 7.5]}
	for w in ["rifle", "spear"]:
		Sim.sync()
		var it: ItemDef = GameData.items.get(w + "_t3", GameData.items.get(w + "_t0"))
		p.equipment[ItemDef.Slot.WEAPON] = it
		p.equipment.erase(ItemDef.Slot.OFFHAND)
		p.recompute_stats()
		p.hp = p.stats.max_hp
		p.mp = p.stats.max_mp
		Events.equipment_changed.emit(p.id)
		await get_tree().create_timer(0.5).timeout
		Sim.sync()
		var sid: String = shots[w][0]
		p.ensure_slots()
		p.learned[sid] = true                 # (sem teia de ascensão comprada: só a foto)
		p.skills[Balance.SKILL_SLOTS] = GameData.skills[sid]     # vaga 7: só skills de ascensão
		p.cooldowns.clear()
		var ok := Sim.try_cast(p, Balance.SKILL_SLOTS, p.position + shots[w][1], m)
		print("ASC_SHOT %s cast=%s" % [sid, str(ok)])
		if sid == "ran_turret":
			await get_tree().create_timer(2.2).timeout
			get_viewport().get_texture().get_image().save_png(path.trim_suffix(".png") + "_torreta.png")
		else:
			var s: SkillDef = GameData.skills[sid]
			while p.sky_left <= 0.0 or p.state_time < s.startup + s.active * 0.3:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(path.trim_suffix(".png") + "_salto.png")
			while p.sky_left > 0.0:
				await get_tree().process_frame
			await get_tree().create_timer(0.08).timeout
			get_viewport().get_texture().get_image().save_png(path.trim_suffix(".png") + "_queda.png")
	print("ASC_SHOT done")
	get_tree().quit()

## Ascensão do Necromante (Senhor dos Mortos): ascende o jogador (45), ergue cães, lança o Pacto e o Miasma em dois bonecos
## (_miasma), marca e derruba um bando de lobos (_cova) e entra na Forma de Lich (_lich).
func _lord_shot(path: String) -> void:
	await get_tree().create_timer(1.0).timeout
	Sim.sync()
	var p := Sim.player
	p.brain = null
	p.level = maxi(p.level, Balance.ASC_MAX_LEVEL)
	if not p.quests_completed.has("hx_asc_necromancer"):
		p.quests_completed.append("hx_asc_necromancer")
	p.recompute_stats()
	p.heal_full()
	var m: Dictionary = Sim.maps[p.map_id]
	var def: MapDef = m["def"]
	p.position = MapGeometry.random_walkable(Sim, def, def.town_center + Vector3(-9, 0, 9), 1.0)
	p.facing = PI * 0.75
	var fwd := p.forward()
	var side := Vector3(fwd.z, 0, -fwd.x)
	for off in [-1.5, 1.5]:
		var d := Sim.spawn_monster(GameData.monsters["golem"], p.map_id, p.position + fwd * 6.0 + side * off)
		d.brain = null
		d.stats.max_hp = 1.0e7
		d.hp = d.stats.max_hp
	var base := path.trim_suffix(".png")
	var cast := func(sid: String, aim: Vector3) -> void:
		Sim.sync()
		p.learned[sid] = true                 # (sem teia comprada: só a foto)
		p.skill_aim = aim
		p.face_towards(aim)
		Sim._apply_skill(p, Sim.resolve_skill(p, GameData.skills[sid]), m)
	cast.call("nec_bone_hound", p.position + fwd)
	cast.call("nec_bone_hound", p.position + fwd)
	await get_tree().create_timer(0.8).timeout
	cast.call("nec_asc_pact", p.position + fwd)
	cast.call("nec_asc_miasma", p.position + fwd * 6.0)
	await get_tree().create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(base + "_miasma.png")
	print("LORD_SHOT miasma invocações=%d nuvem=%s" % [NecroAscension.minions_of(Sim, p).size(), str(not NecroAscension.miasma_of(Sim, p).is_empty())])
	Sim.sync()
	var wolves: Array = []
	for i in range(3):
		var w := Sim.spawn_monster(GameData.monsters["wolf"], p.map_id, p.position + side * 5.0 + fwd * (1.2 * i))
		w.brain = null
		wolves.append(w)
	await get_tree().create_timer(0.4).timeout
	cast.call("nec_asc_grave_mark", p.position + side * 5.0 + fwd * 1.2)
	await get_tree().create_timer(0.5).timeout
	Sim.sync()
	for w in wolves:
		Sim._deal_damage(p, w, int(w.stats.max_hp) + 10, false, false, "magical")
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(base + "_cova.png")
	print("LORD_SHOT cova erguidos=%d" % NecroAscension.graves_of(Sim, p).size())
	Sim.sync()
	Sim._apply_effects(p, p, {"form": "lich"}, 1.0)
	cast.call("nec_bone_hound", p.position + fwd)
	await get_tree().create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(base + "_lich.png")
	print("LORD_SHOT lich forma=%s invocações=%d" % [p.form, NecroAscension.minions_of(Sim, p).size()])
## Ascensão do Assassino (Sombras Gêmeas): ascende o jogador, chama o clone ao lado de um boneco (_clone), golpeia com o
## clone repetindo (_golpe) e executa o boneco abaixo de 25% (_execucao). Sai no fim.
func _asc_shot_assassin(path: String) -> void:
	var p := Sim.player
	p.level = maxi(p.level, Balance.ASC_LEVEL)
	if not p.quests_completed.has("hx_asc_assassin"):
		p.quests_completed.append("hx_asc_assassin")
	var m: Dictionary = Sim.maps[p.map_id]
	var def: MapDef = m["def"]
	p.position = MapGeometry.random_walkable(Sim, def, def.town_center + Vector3(2, 0, 7), 0.5)      # praça aberta, à frente do chafariz
	p.facing = PI * 0.75
	var d := Sim.spawn_monster(GameData.monsters["golem"], p.map_id, p.position + p.forward() * 1.7)
	d.brain = null
	d.stats.max_hp = 1.0e6
	d.hp = d.stats.max_hp
	p.ensure_slots()
	var i := 0
	for sid in [Balance.SHADOW_SKILL, Balance.EXECUTION_SKILL]:
		p.learned[sid] = true                 # (sem teia de ascensão comprada: só a foto)
		p.skills[Balance.SKILL_SLOTS + i] = GameData.skills[sid]
		i += 1
	p.cooldowns.clear()
	p.mp = p.stats.max_mp
	print("ASC_SHOT %s cast=%s" % [Balance.SHADOW_SKILL, str(Sim.try_cast(p, Balance.SKILL_SLOTS, d.position, m))])
	await get_tree().create_timer(0.9).timeout
	get_viewport().get_texture().get_image().save_png(path.trim_suffix(".png") + "_clone.png")
	Sim.sync()
	var c := ShadowSystem.clone_of(Sim, p)
	Sim._start_skill(p, p.basic_skill, -1, d.position)
	var guard := 0
	while c != null and guard < 240 and not (c.state == SimEntity.State.CASTING and c.skill_applied):
		guard += 1
		await get_tree().process_frame
	await get_tree().create_timer(0.05).timeout
	get_viewport().get_texture().get_image().save_png(path.trim_suffix(".png") + "_golpe.png")
	await get_tree().create_timer(0.5).timeout
	Sim.sync()
	d.hp = d.stats.max_hp * 0.2
	p.mp = p.stats.max_mp
	print("ASC_SHOT %s cast=%s" % [Balance.EXECUTION_SKILL, str(Sim.try_cast(p, Balance.SKILL_SLOTS + 1, d.position, m))])
	await get_tree().create_timer(GameData.skills[Balance.EXECUTION_SKILL].startup + 0.12).timeout
	get_viewport().get_texture().get_image().save_png(path.trim_suffix(".png") + "_execucao.png")
	print("ASC_SHOT done")
	get_tree().quit()

## Ascensão do Caçador (Falcoeiro): ascende o jogador com arco, chama o falcão e fotografa planando, no meio de um
## Mergulho e na Revoada (Olhos do Céu com o refino 45). Sai no fim.
func _falcon_shot(path: String) -> void:
	await get_tree().create_timer(1.0).timeout
	Sim.sync()
	var p := Sim.player
	p.level = Balance.ASC_MAX_LEVEL
	if not p.quests_completed.has("hx_asc_ranger"):
		p.quests_completed.append("hx_asc_ranger")
	var m: Dictionary = Sim.maps[p.map_id]
	var def: MapDef = m["def"]
	p.position = MapGeometry.random_walkable(Sim, def, def.town_center + Vector3(-5, 0, 5), 1.0)
	p.facing = PI * 1.25
	var fwd := p.forward()
	p.equipment[ItemDef.Slot.WEAPON] = GameData.items.get("bow_dragon", GameData.items.get("bow_short"))
	p.equipment.erase(ItemDef.Slot.OFFHAND)
	p.recompute_stats()
	p.heal_full()
	Events.equipment_changed.emit(p.id)
	var dummies: Array = []
	for off in [Vector3(-2.5, 0, 0), Vector3(0, 0, 0), Vector3(2.5, 0, 0)]:
		var d := Sim.spawn_monster(GameData.monsters["golem"], p.map_id, p.position + fwd * 7.0 + off)
		d.brain = null
		d.stats.max_hp = 1.0e7
		d.hp = d.stats.max_hp
		d.aggro_target = p.id
		dummies.append(d)
	p.ensure_slots()
	var ids := ["ran_falcon", "ran_dive", "ran_sky_eyes"]
	for i in range(ids.size()):
		p.learned[ids[i]] = true              # (sem teia de ascensão comprada: só a foto)
		p.skills[Balance.SKILL_SLOTS + i] = GameData.skills[ids[i]]
	p.asc_tree["ranger_a_x_falcon_flock"] = true
	p.cooldowns.clear()
	await get_tree().create_timer(0.5).timeout
	Sim.sync()
	p.mp = p.stats.max_mp
	print("FALCON_SHOT chamado=%s" % str(Sim.try_cast(p, Balance.SKILL_SLOTS, p.position, m)))
	await get_tree().create_timer(1.6).timeout
	get_viewport().get_texture().get_image().save_png(path.trim_suffix(".png") + "_falcao.png")
	Sim.sync()
	p.falcon_cd = 99.0                        # só os mergulhos pedidos aparecem
	print("FALCON_SHOT mergulho=%s" % str(Sim.try_cast(p, Balance.SKILL_SLOTS + 1, dummies[1].position, m)))
	var guard := 0
	while p.falcon_dive_pos.is_empty() and guard < 240:
		guard += 1
		await get_tree().process_frame
	await get_tree().create_timer(Balance.FALCON_DIVE_SHOW * 0.3).timeout
	get_viewport().get_texture().get_image().save_png(path.trim_suffix(".png") + "_mergulho.png")
	await get_tree().create_timer(1.5).timeout
	Sim.sync()
	var seen := p.falcon_dive_time
	print("FALCON_SHOT olhos=%s" % str(Sim.try_cast(p, Balance.SKILL_SLOTS + 2, p.position, m)))
	guard = 0
	while p.falcon_dive_time == seen and guard < 240:
		guard += 1
		await get_tree().process_frame
	await get_tree().create_timer(Balance.FALCON_DIVE_SHOW * 0.3).timeout
	get_viewport().get_texture().get_image().save_png(path.trim_suffix(".png") + "_revoada.png")
	print("FALCON_SHOT presas=%d buff=%s" % [dummies.filter(func(d): return Combat.has_prey(d)).size(), str(p.buffs.any(func(b): return b.get("id") == FalconSystem.EYES_BUFF))])
	get_tree().quit()

## --buff_cast=<skill>: lança o buff no jogador logo no início (o --screenshot do smoke sai com ele).
func _cast_buff_at_start(sid: String) -> void:
	await get_tree().create_timer(0.6).timeout
	var s: SkillDef = GameData.skills.get(sid)
	if s == null:
		push_warning("buff_cast: skill desconhecida " + sid)
		return
	var fx := {}
	for k in ["buff", "shield", "form", "stealth"]:
		if s.effects.has(k):
			fx[k] = s.effects[k]
	Sim._apply_effects(Sim.player, Sim.player, fx, 1.0)
	if DevArgs.has("--buff_hold"):          # o buff dura a partida toda (a foto do smoke sai no fim)
		for b in Sim.player.buffs:
			b["remaining"] = 600.0
	var got: Array = []
	for b in Sim.player.buffs:
		got.append(b.get("id"))
	print("BUFF_CAST %s buffs=%s shield=%d" % [sid, str(got), int(Sim.player.shield_hp)])

## Investida élfica: leva o jogador à Floresta, solta uma leva e fotografa a marcha na estrada norte e a luta no portão.
## O jogador fica de pé no caminho (vida cheia o tempo todo) para a câmera seguir a ação.
## --event_shot=<png>: põe o jogador perto de um ponto de evento de estrada do mapa dele, começa o evento e fotografa
## (`_grito` logo no começo, `_luta` com os monstros em cima dele). Imprime EVENT_SHOT com o estado.
func _event_shot(path: String) -> void:
	var p := Sim.player
	await get_tree().create_timer(2.0).timeout
	var def: MapDef = GameData.maps[p.map_id]
	var i := int(DevArgs.value("--event_point", "0"))
	if def.road_events.size() <= i:
		print("EVENT_SHOT sem ponto %d em %s" % [i, def.id])
		get_tree().quit()
		return
	var pos: Vector3 = def.road_events[i]["pos"]
	Sim.sync()
	p.position = pos + (def.town_center - pos).normalized() * 9.0
	var a := Sim.road_event_start(def.id, i)
	for sh in [[1.5, "_grito"], [5.0, "_luta"]]:
		await get_tree().create_timer(float(sh[0])).timeout
		Sim.sync()
		p.hp = p.stats.max_hp
		get_viewport().get_texture().get_image().save_png(path.trim_suffix(".png") + str(sh[1]) + ".png")
		print("EVENT_SHOT %s %s" % [sh[1], Sim.road_event_status(def.id)])
	print("EVENT_SHOT ids=%d" % (a.get("ids", []) as Array).size())
	get_tree().quit()

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

## Fotos do Cerco Vivo em Porto Esperança (estágio = --quests): cais/prancha do navio, as três brechas, casas queimadas,
## refugiados, enfermaria, uma salva de assédio no meio do aviso, a leva chegando e as Chamas.
func _siege_shot(dir: String) -> void:
	var p := Sim.player
	var def: MapDef = GameData.maps["city_port"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir) if dir.begins_with("res://") else dir)
	Sim._change_map(p, def.id, def.spawn_point)
	await get_tree().create_timer(2.5).timeout
	p.hp = p.stats.max_hp * 1000.0          # jogador de nível baixo: a leva não pode mandá-lo de volta à cidade no meio das fotos
	p.brain = null                          # sem o piloto automático do autostart (ele voltava para a cidade durante a leva)
	var m: Dictionary = Sim.maps[def.id]
	var st := SiegeSystem.state(m)
	st["hold"] = true
	MapBuilder.apply_conquest(main.map_node)
	var all := RaidSystem.routes(def)
	var snap := func(tag: String) -> void:
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, tag])
		print("SIEGE_SHOT %s" % tag)
	var spots := [["cais_prancha", Vector3(-9.5, 0, 61.0)], ["cais_barreira", Vector3(-8.0, 0, 66.2)], ["refugiados", Vector3(17.0, 0, 49.5)], ["enfermaria", Vector3(24.5, 0, 16.5)]]
	for seg in def.siege["segments"]:
		spots.append(["brecha_" + str(seg["id"]), all[SiegeSystem.route_index(def, seg["route"])]["target"]])
	for mk in def.fx:
		if mk["kind"] == "fire":
			spots.append(["casa_%d" % spots.size(), mk["pos"] + Vector3(0, 0, 5.0)])
	for sp in spots:
		p.position = sp[1]
		p.hp = p.stats.max_hp * 1000.0
		await get_tree().create_timer(1.2).timeout
		snap.call(sp[0])
	# assédio: atiradores no ponto de tiro, a salva no meio do aviso
	var aim := SiegeSystem.harass_aim(Sim, def)
	p.position = aim + Vector3(0, 0, 4.0)
	var shooters := SiegeSystem.start_harass(Sim, m)
	SiegeSystem.volley(Sim, m, shooters)
	st["shot"] = true
	await get_tree().create_timer(Balance.SIEGE_HARASS_WARN * 0.6).timeout
	snap.call("assedio_salva")
	p.position = all[SiegeSystem.route_index(def, def.siege["harass_route"])]["from"] + Vector3(0, 0, 5.0)
	await get_tree().create_timer(1.0).timeout
	snap.call("assedio_atiradores")
	for id in shooters:
		if Sim.entities.has(id):
			Sim.despawn(Sim.entities[id])
	st["shooters"] = []
	# leva: o lado da vez (brecha aberta ou portão)
	var i := SiegeSystem.next_route(Sim, m, maxi(2, SiegeSystem.pressure(Sim, def)))
	if i >= 0:
		SiegeSystem.start_wave(Sim, m, i)
		p.position = all[i]["target"] + Vector3(0, 0, 3.0)
		var t := 0.0
		var rs := RaidSystem.state(m, i)
		var marched := false
		while t < 120.0 and not (rs["ids"] as Array).is_empty() and not (rs["arrived"] and float(rs["t"]) > float(rs.get("arrived_t", 1e9)) + 3.0):
			await get_tree().process_frame
			t += get_process_delta_time()
			p.hp = p.stats.max_hp * 1000.0
			if p.map_id != def.id:                # algo levou o jogador embora (visto: volta para Aldara no meio da leva): traz de volta
				print("SIEGE_SHOT jogador estava em %s t=%.0f state=%s" % [p.map_id, float(rs["t"]), str(p.state)])
				Sim._change_map(p, def.id, all[i]["target"] + Vector3(0, 0, 3.0))
				await get_tree().create_timer(1.5).timeout
			if rs["arrived"] and not rs.has("arrived_t"):
				rs["arrived_t"] = rs["t"]
			if not marched and float(rs["t"]) >= Balance.RAID_MUSTER + 10.0:       # a leva em marcha: a câmera vai até ela
				marched = true
				var lead: SimEntity = Sim.entities.get(rs["ids"][0])
				if lead != null:
					p.position = MapGeometry.random_walkable(Sim, def, (lead.position as Vector3).lerp(def.town_center, 0.12), 1.5)
					for _f in 40:                     # a câmera chega; o jogador (nível baixo) não pode morrer no meio da leva
						p.hp = p.stats.max_hp
						await get_tree().process_frame
					snap.call("leva_marcha")
					p.position = all[i]["target"] + Vector3(0, 0, 3.0)
		snap.call("leva_%s" % str(all[i]["side"]))
		print("SIEGE_SHOT leva t=%.0f vivos=%d" % [float(rs["t"]), (rs["ids"] as Array).size()])
	# Chamas
	if p.map_id != def.id:
		Sim._change_map(p, def.id, def.spawn_point)
		await get_tree().create_timer(1.5).timeout
	st["scorch"] = true
	Events.siege_event.emit(def.id, "scorch")
	var fire: Array = def.fx.filter(func(mk): return mk["kind"] == "fire")
	if not fire.is_empty():
		p.position = fire[0]["pos"] + Vector3(0, 0, 6.0)
		await get_tree().create_timer(2.5).timeout
		snap.call("chamas")
	get_tree().quit()

## Carga do último front: Bastião com Covil e Ossos retomados (a Torre joga tudo: leva x2, teto RAID_WAVE_CAP_LAST, líder),
## reforços das duas fortalezas na praça, jogador (imortal) no portão sul. A cada 5 s: FPS, pior quadro, ms/tick da sim,
## vivos da leva; foto quando a leva chega ao portão. Medir com janela (o FPS headless não vale).
func _siege_perf(path: String) -> void:
	var p := Sim.player
	for q in ["dw_gates", "dw_ghoul_posts", "dw_ghoul_boss", "dw_bones_posts", "dw_bones_boss"]:
		if not p.quests_completed.has(q):
			p.quests_completed.append(q)
	var def: MapDef = GameData.maps["field_ruins"]
	var frost := -1
	for i in RaidSystem.routes(def).size():
		if RaidSystem.route_def(def, i).get("side", "") == "frost":
			frost = i
	var gate := RaidSystem.gate_point(def, frost)
	Sim._change_map(p, def.id, gate + Vector3(0, 0, -4))
	await get_tree().create_timer(2.0).timeout
	MapBuilder.apply_conquest(main.map_node)
	var m: Dictionary = Sim.maps[def.id]
	for i in def.assaults.size():                  # reforços já descidos (até o max de cada fortaleza retomada)
		if WorldState.active(Sim, def.assaults[i]):
			for id in WorldState.spawn_assault(Sim, m, i):
				var e: SimEntity = Sim.entities[id]
				e.position = MapGeometry.random_walkable(Sim, def, def.assaults[i]["target"], 4.0)
				e.raid_leg = (e.npc_data["march"] as Array).size() - 1
	var ids := RaidSystem.start_raid(Sim, m, frost)
	print("SIEGE start leva=%d" % ids.size())
	var t := 0.0
	var frames := 0
	var worst := 0.0
	var t_win := 0.0
	var shot := false
	var fps_sum := 0.0
	var fps_n := 0
	var worst_all := 0.0
	while t < float(DevArgs.value("--siege_time", "90")):
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		t_win += dt
		frames += 1
		worst = maxf(worst, dt)
		p.hp = p.stats.max_hp
		var st := RaidSystem.state(m, frost)
		if not shot and st["arrived"]:
			shot = true
			get_viewport().get_texture().get_image().save_png(path)
		if t_win >= 5.0:
			var fps := frames / t_win
			fps_sum += fps
			fps_n += 1
			worst_all = maxf(worst_all, worst)
			print("SIEGE t=%.0f fps=%.1f worst_ms=%.0f tick_ms=%.2f leva_viva=%d entidades=%d views=%d" % [t, fps, worst * 1000.0, Sim.tick_usec / 1000.0,
				(st["ids"] as Array).size(), m["entities"].size(), main.views.size()])
			frames = 0
			worst = 0.0
			t_win = 0.0
	var mus: Music = main.get_node_or_null("Music")
	print("SIEGE_END fps_medio=%.1f pior_ms=%.0f musica=%s tocadas=%s" % [fps_sum / maxf(1, fps_n), worst_all * 1000.0, mus.current if mus else "-", mus.played if mus else {}])
	get_tree().quit()

## --boss_film=<chefe>[,<chefe>...] --out=<pasta>: no mapa do chefe, ele lança cada skill do kit (base + fases) num grupo
## parado (jogador ao lado, bot a 11 m). Uma folha por skill: preparo, impacto e depois (chuva: até os círculos caírem).
## Revisa gesto, aviso no chão, corda do gancho e lacaios. Sai no fim.
func _boss_film(ids: Array, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var p := Sim.player
	var probe = load("res://tools/tests/boss_probe.gd")
	for bid in ids:
		var md: MonsterDef = GameData.monsters.get(bid)
		if md == null or not probe.BOSSES.has(bid):
			print("BOSS_FILM %s: chefe desconhecido" % bid)
			continue
		var mid: String = probe.BOSSES[bid]
		var at := Vector3.ZERO
		for sp in GameData.maps[mid].spawners:
			if sp["monster_id"] == bid:
				at = sp["pos"]
		Sim._change_map(p, mid, at + Vector3(2.5, 0, 2.0))
		await get_tree().create_timer(2.0).timeout
		var m: Dictionary = Sim.maps[mid]
		m["spawners"].clear()
		for e in m["entities"].duplicate():
			if e != p and e.kind != SimEntity.Kind.NPC:
				Sim.despawn(e)
		var boss := Sim.spawn_monster(md, mid, at)
		boss.brain = null
		var far := Sim.spawn_bot(GameData.classes["ranger"], "Longe", mid, at + Vector3(-9.0, 0, 6.0), md.level)
		far.brain = null
		p.brain = null
		var kit: Array = md.skill_ids.duplicate()      # cópia: Array(tipado) devolve o MESMO array (append mexeria no MonsterDef)
		for ph in md.phases:
			for sid in ph.get("skills", []):
				if not kit.has(sid):
					kit.append(sid)
		Sim._add_skills(boss, kit.filter(func(sid): return not boss.skills.any(func(s): return s != null and s.id == sid)))
		for sid in kit:
			var s: SkillDef = GameData.skills.get(sid)
			if s == null:
				continue
			for e in [p, far, boss]:
				e.hp = e.stats.max_hp
				e.debuffs.clear()
				e.set_state(SimEntity.State.IDLE)
			p.position = at + Vector3(2.5, 0, 2.0)
			far.position = at + Vector3(-9.0, 0, 6.0)
			boss.cooldowns.clear()
			boss.aggro_target = p.id
			var victim := p
			if s.mob_pick != "":
				victim = MobSystem.pick_victim(Sim, boss, s.mob_pick)
			var aim: Vector3 = (victim if victim else p).position
			boss.face_towards(aim)
			var slot := -1
			for i in range(boss.skills.size()):
				if boss.skills[i] != null and boss.skills[i].id == sid:
					slot = i
			if slot < 0 or not Sim.try_cast(boss, slot, aim, m):
				print("BOSS_FILM %s %s: não lançou" % [bid, sid])
				continue
			var times: Array = [s.startup * 0.5, s.startup + s.active * 0.5, s.startup + s.active + 0.35]
			if s.effects.has("barrage"):
				var d := float(s.effects["barrage"].get("delay", Balance.BOSS_HAZARD_DELAY))
				times = [s.startup * 0.6, s.startup + d * 0.6, s.startup + d + 0.1]
			var frames: Array = []
			var t0 := Time.get_ticks_msec()
			for want in times:
				while (Time.get_ticks_msec() - t0) / 1000.0 < float(want):
					await get_tree().process_frame
					p.hp = p.stats.max_hp
					far.hp = far.stats.max_hp
				var img := get_viewport().get_texture().get_image()
				img.resize(img.get_width() / 2, img.get_height() / 2)
				frames.append(img)
			var sheet := Image.create(frames[0].get_width() * frames.size(), frames[0].get_height(), false, frames[0].get_format())
			for i in range(frames.size()):
				sheet.blit_rect(frames[i], Rect2i(Vector2i.ZERO, frames[i].get_size()), Vector2i(frames[0].get_width() * i, 0))
			var path := "%s/%s_%s.png" % [out, bid, sid]
			sheet.save_png(path)
			print("BOSS_FILM %s %s -> %s" % [bid, sid, path])
			await get_tree().create_timer(maxf(0.3, s.recovery + 0.3)).timeout
			for e in m["entities"].duplicate():
				if e.boss_id == boss.id:
					Sim.despawn(e)
		Sim.despawn(boss)
		Sim.despawn(far)
	print("BOSS_FILM_END")
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
	var wear: Array = sd.pieces.duplicate()
	if sd.is_apex():             # Ápice: arma principal e mão secundária da build
		wear.append_array(sd.alt_pieces.filter(func(x): return x.ends_with("_weapon") or x.ends_with("_offhand")))
	elif sd.is_hybrid():           # híbrido: armas da build A (ou B com --face=b)
		var side: String = sd.pair[1] if DevArgs.value("--face") == "b" else sd.pair[0]
		wear.append_array(sd.alt_pieces.filter(func(x): return x.contains("_%s_weapon" % side) or x.contains("_%s_offhand" % side)))
	if DevArgs.flag("--gear_partial"):      # --gear_partial=N: só as N primeiras peças de armadura (revisar peça faltando na aba Conjuntos)
		var keep: Array = sd.armor.slice(0, int(DevArgs.value("--gear_partial")))
		wear = wear.filter(func(x): return keep.has(x) or not sd.armor.has(x))
		var sd2: SetDef = GameData.sets.get(DevArgs.value("--gear2", ""))
		if sd2:                             # --gear2=<set_id>: as peças que faltam vêm de outro conjunto (2 cartões)
			wear.append_array(sd2.armor.slice(keep.size()))
	for iid in wear:
		Sim.player.add_item(iid)
		Sim.equip(Sim.player, iid, iid.ends_with("_offhand") and GameData.items[iid].weapon_type != "shield")
	if DevArgs.flag("--form"):      # --form=wolf|bear: já começa transformado (revisar a forma do Druida)
		Sim._apply_effects(Sim.player, Sim.player, {"form": DevArgs.value("--form")}, 1.0)
	if DevArgs.has("--mace"):     # --mace: a maça/martelo do conjunto na mão (Templário: é a arma principal, a 2ª peça é a espada)
		for mid in sd.pieces + sd.alt_pieces:
			var mit: ItemDef = GameData.items.get(mid)
			if mit and mit.weapon_type in ["mace", "mace2h"] and not mid.ends_with("_offhand"):
				Sim.player.add_item(mid)
				Sim.equip(Sim.player, mid, false)
				break

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

func _recall_shot(path: String) -> void:
	await get_tree().create_timer(3.0).timeout
	_smoke_test = false
	var p := Sim.player
	var base := path.trim_suffix(".png")
	var out := p.position if Sim.recall_blocked(p) == "" else Vector3(70, 0, 10)     # na cidade: fora das muralhas (dentro, G não começa)
	_place(p, out)
	if DevArgs.has("--recall_close"):
		main.camera.distance = 8.0
	p.hp = p.stats.max_hp * 0.7
	p.shield_hp = p.stats.max_hp * 0.22             # como a Armadura de Gelo
	p.buffs.append({"id": "shield", "remaining": 12.0})
	for iid in ["potion_hp_s", "potion_mp_s", "potion_hp_m"]:
		p.add_item(iid, 5)
	Sim.set_potion_slot(p, 0, "potion_hp_s"); Sim.set_potion_slot(p, 1, "potion_mp_s"); Sim.set_potion_slot(p, 2, "potion_hp_m")
	p.potion_cds[0] = 3.6
	p.potion_cds[2] = 1.4
	var near: Array = Sim.map_entities(p.map_id).filter(func(e): return e.kind == SimEntity.Kind.BOT and e.party_id < 0 and e.is_alive())
	if p.party_id < 0 and near.size() > 0 and Sim.party_invite(p, near[0]):
		Sim.party_accept(near[0])
	var nsh := 0
	for m in Sim.party_members(p):
		if m != p:                                      # 1º: passa do máximo (faixa no fim); 2º: cabe depois da vida
			m.hp = m.stats.max_hp * (0.8 if nsh == 0 else 0.5)
			m.shield_hp = m.stats.max_hp * (0.5 if nsh == 0 else 0.25)
			nsh += 1
			if nsh >= 2:
				break
	await get_tree().create_timer(0.4).timeout
	main.controller.queue_recall()                 # o mesmo caminho do G e do clique no slot
	var shots := [0.35, 1.0, 1.8, 2.6, 3.2]
	var t0 := 0.0
	for k in range(shots.size()):
		await get_tree().create_timer(shots[k] - t0).timeout
		t0 = shots[k]
		print("RECALL_SHOT %d recall_left=%.2f map=%s" % [k, p.recall_left, p.map_id])
		get_viewport().get_texture().get_image().save_png("%s_%d.png" % [base, k])
	await get_tree().create_timer(1.2).timeout
	print("RECALL_SHOT done map=%s pos=%s" % [p.map_id, str(p.position)])
	# de novo, e um golpe interrompe
	_place(p, p.position if Sim.recall_blocked(p) == "" else Vector3(70, 0, 10))
	await get_tree().create_timer(0.8).timeout
	main.controller.queue_recall()
	await get_tree().create_timer(1.2).timeout
	var mob := Sim.spawn_monster(GameData.monsters["slime"], p.map_id, p.position + Vector3(2, 0, 1))
	mob.brain = null
	p.shield_hp = 0.0
	Sim._deal_damage(mob, p, 25, false, false, "physical")
	await get_tree().create_timer(0.25).timeout
	print("RECALL_SHOT interrupted recall_left=%.2f" % p.recall_left)
	get_viewport().get_texture().get_image().save_png("%s_interrompido.png" % base)
	get_tree().quit()

func _place(p: SimEntity, at: Vector3) -> void:
	p.position = at
	main.views[p.id].position = at
	main.views[p.id]._smooth_pos = at

func _tip_shot(path: String) -> void:
	await get_tree().create_timer(1.0).timeout
	var tips: Tips = main.hud.tips
	tips.seen.clear()
	tips._queue.clear()
	tips._hide_card()
	tips._gap = 0.0
	tips.request(DevArgs.value("--tip", "attack"))
	await get_tree().create_timer(1.0).timeout
	print("TIP na tela: ", tips.current(), " rect=", tips._card.get_global_rect() if tips._card else Rect2(), " tips=", tips.get_global_rect(), " vis=", tips.is_visible_in_tree())
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()

## Lich morto: festeiros nascem e os fogos começam (foto <png>_festa.png); depois a tela do fim do ato (<png>).
func _act_end_shot(path: String) -> void:
	Sim.sync()
	var act := int(DevArgs.value("--act", "1"))           # --act=2: fim do Ato II (vá ao porto/acampamento com --map)
	Sim.player.quests_completed.append(MapsCatalog.VICTORY2_QUEST if act == 2 else MapsCatalog.VICTORY_QUEST)
	await get_tree().create_timer(3.0).timeout
	var fest: FestivalFx = main.world_root.get_node("FestivalFx")
	for i in 3:
		fest.launch()
	await get_tree().create_timer(fest.RISE + 0.25).timeout
	get_viewport().get_texture().get_image().save_png(path.get_basename() + "_festa.png")
	main.hud.show_act_end(act)
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()

func _menu_check() -> void:
	await get_tree().create_timer(1.5).timeout
	main.hud.open_game_menu()
	await get_tree().create_timer(0.5).timeout
	if DevArgs.flag("--menu_shot"):
		get_viewport().get_texture().get_image().save_png(DevArgs.value("--menu_shot"))
	print("RETURN_CHECK views=%d fila=%d" % [main.views.size(), main.view_queue.size()])     # fila com gente longe: a volta não pode tropeçar nela
	main.hud._menu_to_title()

func _demo_shot() -> void:
	await get_tree().create_timer(2.0).timeout
	if _shot_path != "":
		get_viewport().get_texture().get_image().save_png(_shot_path)
	get_tree().quit()

func _map_shot(path: String) -> void:
	await get_tree().create_timer(2.0).timeout
	main.hud.toggle_world_map()
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("MAP_SHOT ", path)
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
	if DevArgs.flag("--perf_raid") and Sim.player:    # pior caso da investida: --perf_raid=<retomadas>, leva do norte na muralha + surtida
		var m: Dictionary = Sim.maps[Sim.player.map_id]
		var def: MapDef = m["def"]
		RaidSystem.state(m)["force_reclaimed"] = int(DevArgs.value("--perf_raid"))
		var ri := 0
		for i in RaidSystem.routes(def).size():
			if RaidSystem.route_def(def, i).get("side", "") == "bones":
				ri = i
		var ids := RaidSystem.start_raid(Sim, m, ri)
		var gate := RaidSystem.gate_point(def, ri)
		for id in ids:
			Sim.entities[id].position = Sim.random_walkable(def, gate * 1.25, 8.0)
		Sim.player.position = gate * 0.9
		print("PERF raid=%d invasores" % ids.size())
	if DevArgs.flag("--shadow_max"):                   # experimento: alcance da sombra do sol (m) e divisão das cascatas
		for l in main.map_node.find_children("*", "DirectionalLight3D", true, false):
			l.directional_shadow_max_distance = float(DevArgs.value("--shadow_max"))
			if DevArgs.flag("--shadow_split"):
				l.directional_shadow_split_1 = float(DevArgs.value("--shadow_split"))
	if DevArgs.has("--no_prop_shadow"):                # experimento: props do mapa sem sombra
		for g in main.map_node.find_children("*", "GeometryInstance3D", true, false):
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if DevArgs.has("--hide_minimap"):                  # experimento: custo do minimapa (2D)
		main.hud.minimap.visible = false
	if DevArgs.flag("--hide_props"):                   # experimento: some com props por nome (ex.: --hide_props=prop_rock,prop_bush)
		var pre := DevArgs.value("--hide_props").split(",")
		for mi in main.map_node.find_children("*", "MeshInstance3D", true, false):
			for p in pre:
				if str(mi.name).begins_with(p):
					mi.visible = false
	# espera assentar: spawners do mapa cheios (1º enchimento) e a fila de bonecos de perto vazia por 1 s; teto 15 s
	var st0 := Time.get_ticks_usec()
	var calm := 0.0
	var settle := 0.0
	while true:
		await get_tree().process_frame
		settle = (Time.get_ticks_usec() - st0) / 1_000_000.0
		var ok: bool = settle >= 2.5 and _perf_primed() and main.views_pending_near() == 0
		calm = calm + get_process_delta_time() if ok else 0.0
		if calm >= 1.0 or settle >= 15.0:
			break
	print("PERF settle_s=%.1f primed=%s views_queued=%d (perto=%d) map_build_ms=%.0f" % [settle, str(_perf_primed()), main.view_queue.size(), main.views_pending_near(), main.map_build_ms])
	Sim.profile = true
	Sim.prof.clear()
	if get_tree().physics_frame.is_connected(Sim.sync):     # mede cada espera do Sim.sync no passo de física (thread + Events.flush)
		get_tree().physics_frame.disconnect(Sim.sync)
		get_tree().physics_frame.connect(_perf_sync_step)
	_sync_worst = 0.0; _sync_sum = 0.0; _sync_n = 0
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
	print("PERF sync_step avg_ms=%.2f worst_ms=%.2f steps=%d (espera do Sim.sync + Events.flush por passo de física)" % [_sync_sum / maxi(1, _sync_n), _sync_worst, _sync_n])
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
	var esurf := {}                      # superfícies desenhadas dos bonecos visíveis por tipo de malha (cada uma: cor + contorno + sombras)
	for v in main.views.values():
		if not v.visible:
			continue
		for mi in v.find_children("*", "MeshInstance3D", true, false):
			if mi.is_visible_in_tree() and mi.mesh:
				var k := str(mi.name) if str(mi.name) in ["KitMerged", "RigidMerged", "SkinMerged"] else "outros"
				esurf[k] = int(esurf.get(k, 0)) + mi.mesh.get_surface_count()
	print("PERF entity_surfaces ", esurf)
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
	print("PERF avg process_ms=%.2f physics_max1s_ms=%.2f gpu_ms=%.2f render_cpu_ms=%.2f" % [proc_us / frames / 1000.0, sim_us / frames / 1000.0, gpu_sum / frames, rcpu_sum / frames])
	print("PERF process_ms=%.2f phys_objects=%d pairs=%d islands=%d gpu_ms=%.2f cpu_ms=%.2f prims=%d" % [Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS), Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS),
		Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT), RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()),
		RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	var vp_rid := get_viewport().get_viewport_rid()      # último quadro, só a passada de cor (sem sombras): objetos e draws
	print("PERF canvas_pass objects=%d draws=%d" % [
		RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
		RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)])
	print("PERF visible_pass objects=%d draws=%d prims=%d | shadow_pass objects=%d draws=%d" % [
		RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
		RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
		RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
		RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)])
	print("PERF fps=%.1f frame_ms=%.2f draws=%.0f nodes=%d objects=%d mem_mb=%.0f physics_max1s_ms=%.2f prune=%s" % [frames / secs, secs * 1000.0 / frames,
		draws / frames, Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, sim_us / frames / 1000.0, str(KitModel.prune)])
	get_tree().quit()

## --perf: todos os spawners ativos do mapa do jogador já encheram a 1ª vez.
func _perf_primed() -> bool:
	if Sim.player == null:
		return true
	for sp in Sim.maps[Sim.player.map_id]["spawners"]:
		if not sp.get("primed", false) and WorldState.active(Sim, sp["def"]):
			return false
	return true

var _sync_worst := 0.0
var _sync_sum := 0.0
var _sync_n := 0
## --perf: Sim.sync do passo de física, cronometrado (physics_ms do Godot é o PIOR passo de cada segundo).
func _perf_sync_step() -> void:
	var t := Time.get_ticks_usec()
	Sim.sync()
	var ms := (Time.get_ticks_usec() - t) / 1000.0
	_sync_worst = maxf(_sync_worst, ms)
	_sync_sum += ms
	_sync_n += 1

## Confere o arrastar e soltar: capacete da bolsa no slot da cabeça, depois de volta para a bolsa; anel no 2º slot.
func _fake_drag(from: Control, to: Control) -> void:
	var vp := get_viewport()
	var a := from.get_global_transform_with_canvas() * Vector2(minf(40.0, from.size.x * 0.5), minf(12.0, from.size.y * 0.5))
	var b := to.get_global_transform_with_canvas() * (to.size * 0.5)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = a; ev.global_position = a
	vp.push_input(ev, true)
	for k in range(1, 13):
		var mv := InputEventMouseMotion.new()
		mv.button_mask = MOUSE_BUTTON_MASK_LEFT
		mv.position = a.lerp(b, k / 12.0); mv.global_position = mv.position
		mv.relative = (b - a) / 12.0
		vp.push_input(mv, true)
		await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = b; up.global_position = b
	vp.push_input(up, true)
	await get_tree().process_frame

func _hotbar_drag_check() -> void:
	var w = main.hud.windows_script
	var p := Sim.player
	p.add_item("potion_hp_m", 3)
	Sim.set_potion_slot(p, 2, "")
	w.close_all()
	w.toggle("inventory")
	await get_tree().process_frame
	await get_tree().process_frame
	var cell: Control = w.drag_sources.get("potion_hp_m")
	if cell:
		await _fake_drag(cell, main.hud.potion_slots[2]["root"])
	print("HOTBAR_DRAG potion F3=%s ok=%s" % [p.potion_slots[2], p.potion_slots[2] == "potion_hp_m"])
	w.close_all()
	w.toggle("skills")
	await get_tree().process_frame
	await get_tree().process_frame
	var sid := ""
	for s in p.class_def.skill_ids:
		if p.knows(s) and p.slot_of(s) != 5:
			sid = s
			break
	var card: Control = w.drag_sources.get(sid)
	if card:
		await _fake_drag(card, w.drag_sources["bar_5"])      # barra da própria janela K (o HUD fica atrás dela)
	var got5: String = p.skills[5].id if p.skills.size() > 5 and p.skills[5] else ""
	print("HOTBAR_DRAG skill K-bar %s slot6=%s ok=%s" % [sid, got5, got5 == sid and sid != ""])
	w.close_all()
	await get_tree().process_frame
	await _fake_drag(main.hud.skill_slots[5]["root"], main.hud.skill_slots[0]["root"])     # HUD 6 -> 1: troca
	var got0: String = p.skills[0].id if p.skills[0] else ""
	print("HOTBAR_DRAG hud 6->1 slot1=%s ok=%s" % [got0, got0 == sid])
	await _hotbar_clear_check()

## Playtest 2026-11-16 ("com a bolsa/ficha aberta, o botão esquerdo ataca"). Eventos pelo Input de verdade
## (Input.parse_input_event atualiza Input.is_action_pressed, como o mouse; push_input não), segurando o botão
## alguns passos e contando os comandos do controle com ataque/bloqueio. Imprime UI_CLICK <alvo> ... ok=.
func _ui_click_check() -> void:
	var w = main.hud.windows_script
	var pc: PlayerController = main.controller
	w.close_all()
	w.toggle("inventory")
	w.toggle("character")
	await get_tree().process_frame
	await get_tree().process_frame
	var vp_size := get_viewport().get_visible_rect().size
	var world_at := vp_size * Vector2(0.5, 0.3)          # céu/chão no meio da tela, fora das janelas
	var spots := []
	for wn in ["inventory", "character"]:
		var pnl: Control = w.wins[wn]["panel"]
		spots.append([wn + "_titulo", pnl.get_global_transform_with_canvas() * Vector2(pnl.size.x * 0.4, 12.0)])
		spots.append([wn + "_corpo", pnl.get_global_transform_with_canvas() * Vector2(pnl.size.x * 0.5, pnl.size.y - 14.0)])
	var bar: Control = main.hud.skill_slots[0]["root"]
	spots.append(["barra_1", bar.get_global_transform_with_canvas() * (bar.size * 0.5)])
	var all_ok := true
	for sp in spots:
		var at: Vector2 = sp[1]
		var hov := await _ui_hold(at, at, MOUSE_BUTTON_LEFT)
		var ok: bool = hov[0] == 0 and hov[1] != ""
		all_ok = all_ok and ok
		print("UI_CLICK %s LMB attack_ticks=%d hovered=%s ok=%s" % [sp[0], hov[0], hov[1], ok])
		if not str(sp[0]).begins_with("barra"):      # RMB num slot da barra esvazia o slot (comportamento da barra)
			var hb := await _ui_hold(at, at, MOUSE_BUTTON_RIGHT)
			var okb: bool = hb[0] == 0
			all_ok = all_ok and okb
			print("UI_CLICK %s RMB block_ticks=%d ok=%s" % [sp[0], hb[0], okb])
	var hw := await _ui_hold(world_at, world_at, MOUSE_BUTTON_LEFT)
	print("UI_CLICK mundo LMB attack_ticks=%d hovered=%s ok=%s" % [hw[0], hw[1], hw[0] > 0])
	all_ok = all_ok and hw[0] > 0 and hw[1] == ""
	var hr := await _ui_hold(world_at, world_at, MOUSE_BUTTON_RIGHT)
	print("UI_CLICK mundo RMB block_ticks=%d ok=%s" % [hr[0], hr[0] > 0])
	all_ok = all_ok and hr[0] > 0
	# segurou no mundo e passou por cima da bolsa: continua (o aperto decide); soltar sobre a janela encerra
	var bag_at: Vector2 = spots[1][1]
	var hm := await _ui_hold(world_at, bag_at, MOUSE_BUTTON_LEFT)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var after_release: bool = pc.last_cmd != null and pc.last_cmd.attack
	print("UI_CLICK mundo->bolsa LMB attack_ticks=%d solto_na_janela_ataca=%s ok=%s" % [hm[0], after_release, hm[0] > 0 and not after_release])
	all_ok = all_ok and hm[0] > 0 and not after_release
	# arrastar da bolsa e soltar no mundo: nenhum golpe no caminho nem ao soltar
	var hd := await _ui_hold(bag_at, world_at, MOUSE_BUTTON_LEFT)
	await get_tree().physics_frame
	var drag_after: bool = pc.last_cmd != null and pc.last_cmd.attack
	print("UI_CLICK bolsa->mundo LMB attack_ticks=%d solto_no_mundo_ataca=%s ok=%s" % [hd[0], drag_after, hd[0] == 0 and not drag_after])
	all_ok = all_ok and hd[0] == 0 and not drag_after
	print("UI_CLICK all ok=%s" % all_ok)

## Aperta `button` em `from` (coordenadas da viewport), arrasta até `to` e segura ~10 passos de física, solta em `to`.
## Devolve [passos com ataque (LMB) ou bloqueio (RMB) no comando do controle, controle sob o mouse no aperto ("" = mundo)].
func _ui_hold(from: Vector2, to: Vector2, button: MouseButton) -> Array:
	var pc: PlayerController = main.controller
	var xf := get_viewport().get_screen_transform()       # viewport -> janela (o Input recebe coordenadas da janela)
	Input.warp_mouse(xf * from)
	var mv0 := InputEventMouseMotion.new()
	mv0.position = xf * from; mv0.global_position = mv0.position
	Input.parse_input_event(mv0)
	await get_tree().process_frame
	await get_tree().process_frame
	var hc := get_viewport().gui_get_hovered_control()
	var hovered := "" if hc == null else str(hc.get_class())
	var mask := MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.button_mask = mask
	ev.pressed = true
	ev.position = xf * from; ev.global_position = ev.position
	Input.parse_input_event(ev)
	var ticks := 0
	for k in range(12):
		var p: Vector2 = from.lerp(to, minf(1.0, k / 6.0))
		var mv := InputEventMouseMotion.new()
		mv.button_mask = mask
		mv.position = xf * p; mv.global_position = mv.position
		mv.relative = (to - from) / 6.0 if k <= 6 else Vector2.ZERO
		Input.parse_input_event(mv)
		await get_tree().physics_frame
		await get_tree().process_frame
		if pc.last_cmd and ((button == MOUSE_BUTTON_LEFT and pc.last_cmd.attack) or (button == MOUSE_BUTTON_RIGHT and pc.last_cmd.block)):
			ticks += 1
	var up := InputEventMouseButton.new()
	up.button_index = button
	up.pressed = false
	up.position = xf * to; up.global_position = up.position
	Input.parse_input_event(up)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	return [ticks, hovered]

## Relato do Lanceiro (2026-11-16): skill de arco presa na barra. --lancer = Ranger nível 20 da build Lanceiro com lança;
## botão direito num slot do HUD esvazia, skill da janela K por cima de uma de arco a troca, arrastar para fora da barra tira.
func _hotbar_clear_check() -> void:
	var w = main.hud.windows_script
	var p := Sim.player
	if DevArgs.has("--lancer") and p.class_def.id == "ranger":
		p.level = 20
		p.build_id = "lanceiro"
		ProgressionSystem.bot_spend(Sim, p, true)
		p.build_id = ""
		for iid in GameData.items:
			var it: ItemDef = GameData.items[iid]
			if it.weapon_type == "spear" and it.level_req <= p.level and it.base_id == "":
				p.equipment[it.slot] = it
				break
		var lan: Array = p.class_def.build_by_id("lanceiro").get("skills", [])
		var k := 2
		for i in range(Balance.SKILL_SLOTS):
			p.skills[i] = null
		p.skills[0] = GameData.skills["ran_power_shot"]     # o começo do Ranger: 2 de arco + 4 de lança
		p.skills[1] = GameData.skills["ran_disengage"]
		for sid in lan:
			if k < Balance.SKILL_SLOTS and p.knows(sid) and p.slot_of(sid) < 0:
				p.skills[k] = GameData.skills[sid]
				k += 1
		p.recompute_stats()
		Events.equipment_changed.emit(p.id)
		await get_tree().process_frame
	print("HOTBAR_CLEAR bar=%s" % [p.skills.slice(0, Balance.SKILL_SLOTS).map(func(s): return s.id if s else "")])
	var vp := get_viewport()
	var at: Vector2 = main.hud.skill_slots[0]["root"].get_global_transform_with_canvas() * (main.hud.skill_slots[0]["root"].size * 0.5)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = true
	ev.position = at; ev.global_position = at
	vp.push_input(ev, true)
	var up: InputEventMouseButton = ev.duplicate()
	up.pressed = false
	vp.push_input(up, true)
	await get_tree().process_frame
	print("HOTBAR_CLEAR right-click slot1 empty=%s ok=%s" % [p.skills[0] == null, p.skills[0] == null])
	var spare := ""
	for s in p.class_def.skill_ids:
		if p.knows(s) and p.slot_of(s) < 0 and not GameData.skills[s].ascension and (spare == "" or p.stats.meets(GameData.skills[s].requires)):
			spare = s          # de preferência uma que a arma na mão permite
			if p.stats.meets(GameData.skills[s].requires):
				break
	var bow_at := -1
	for i in range(Balance.SKILL_SLOTS):
		if p.skills[i] and p.skills[i].id != spare and not p.stats.meets(p.skills[i].requires):
			bow_at = i
			break
	bow_at = bow_at if bow_at >= 0 else 1
	var was: String = p.skills[bow_at].id if p.skills[bow_at] else ""
	w.toggle("skills")
	await get_tree().process_frame
	await get_tree().process_frame
	var card: Control = w.drag_sources.get(spare)
	if card:
		await _fake_drag(card, w.drag_sources["bar_%d" % bow_at])
	var now: String = p.skills[bow_at].id if p.skills[bow_at] else ""
	print("HOTBAR_CLEAR K %s over %s slot%d=%s ok=%s" % [spare, was, bow_at + 1, now, now == spare and spare != "" and p.slot_of(was) < 0])
	w.close_all()
	await get_tree().process_frame
	var gone: String = p.skills[2].id if p.skills[2] else ""
	var hud_root: Control = main.hud.skill_slots[2]["root"]
	var off := Control.new()             # alvo do arrasto: um ponto no meio da tela, longe da barra
	off.size = Vector2(4, 4)
	off.position = get_viewport().get_visible_rect().size * Vector2(0.5, 0.35)
	main.hud.add_child(off)
	await get_tree().process_frame
	await _fake_drag(hud_root, off)
	off.queue_free()
	print("HOTBAR_CLEAR drag-off %s slot3 empty=%s ok=%s" % [gone, p.skills[2] == null, gone != "" and p.skills[2] == null])
	if DevArgs.has("--field"):          # fora da cidade: a troca é recusada e o aviso aparece na tela (foto logo depois)
		var md: MapDef = Sim.maps[p.map_id]["def"]
		for r in [40.0, 60.0, 80.0, 100.0]:
			var spot: Vector3 = md.town_center + Vector3(r, 0, 0)
			if not md.in_hub(spot) and Sim.is_walkable(spot, md):
				p.position = spot
				break
		await get_tree().create_timer(0.5).timeout
		var keep: String = p.skills[3].id if p.skills[3] else ""
		var at3: Vector2 = main.hud.skill_slots[3]["root"].get_global_transform_with_canvas() * (main.hud.skill_slots[3]["root"].size * 0.5)
		var rc := InputEventMouseButton.new()
		rc.button_index = MOUSE_BUTTON_RIGHT
		rc.pressed = true
		rc.position = at3; rc.global_position = at3
		vp.push_input(rc, true)
		await get_tree().process_frame
		print("HOTBAR_CLEAR field right-click kept=%s ok=%s" % [keep, p.skills[3] != null and p.skills[3].id == keep])
	await get_tree().create_timer(0.3).timeout

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

## Teia: 3 passos de roda (afasta) pelo mesmo _web_input da janela, foto, compra um nó disponível como o clique faz
## (_web_buy reconstrói a janela) e deixa a foto final para o _bag_shot. Relato: "o clique compra, mas as linhas somem".
func _web_click_check(path: String) -> void:
	var ws = main.hud.windows_script
	await get_tree().process_frame
	var view: Control = ws._web_view
	var web: Control = ws._web_node
	for k in int(DevArgs.value("--wheel", "3")):
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_WHEEL_DOWN if not DevArgs.has("--zoom_in") else MOUSE_BUTTON_WHEEL_UP
		ev.pressed = true
		ev.position = view.size * 0.5 + Vector2(140, 90)
		ws._web_input(ev, view, web)
	if DevArgs.flag("--pan"):                 # arrasto (x,y em px) pelo mesmo _web_input: leva a origem da teia para longe
		var pan := Array(DevArgs.value("--pan").split(","))
		ws._web_dragging = true
		var mv := InputEventMouseMotion.new()
		mv.button_mask = MOUSE_BUTTON_MASK_LEFT
		mv.relative = Vector2(float(pan[0]), float(pan[1]))
		ws._web_input(mv, view, web)
		ws._web_dragging = false
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png(path.get_basename() + "_antes.png")
	var p := Sim.player
	var tr: Dictionary = GameData.trees.get(p.class_def.id, {})
	for nid in tr.get("nodes", {}):
		if not p.tree.has(nid) and Sim.tree_block_reason(p, nid) == "" and tr["nodes"][nid]["kind"] != "pick":
			ws._web_moved = 0.0
			ws._web_buy(p, nid)
			print("WEB_CLICK comprado=%s zoom=%.2f" % [nid, ws._web_zoom])
			break
	await get_tree().create_timer(0.4).timeout

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
		if Sim.player.build_id == "" and not Sim.player.class_def.builds.is_empty():
			Sim.player.build_id = Sim.player.class_def.builds[int(DevArgs.value("--build_i", "0"))]["id"]
		ProgressionSystem.bot_spend(Sim, Sim.player, true)       # teia gasta como um bot da build (--build_i=N escolhe a build)
		Sim.player.mastery_points += int(DevArgs.value("--spare", "4"))     # sobra para ver nós verdes
	if DevArgs.has("--asc") or DevArgs.has("--ascend"):             # ascensão feita (precisa de --level=35+): Elementalista chama o elemental (--elem_stage=N, --elem_xp=N)
		var ap: SimEntity = Sim.player
		_ascend_player()
		if DevArgs.has("--asc_tab"):    # janela K na aba Ascensão (com --wins=skills)
			main.hud.windows_script._skills_tab = "asc"
		ap.elem_stage = int(DevArgs.value("--elem_stage", "0"))
		ap.elem_xp = int(DevArgs.value("--elem_xp", "0"))
		ap.mp = ap.stats.max_mp
		Sim.elem_command(ap, ElementalSystem.default_form(ap), "")
	if DevArgs.has("--status_demo"):     # buffs e debuffs de amostra na barra (revisar ícones e tempos)
		Sim.player.buffs.append({"id": "elixir", "remaining": 44.0, "atk_pct": 20})
		Sim.player.buffs.append({"id": "frost_armor", "remaining": 7.2, "def_pct": 30})
		Sim.player.buffs.append({"id": "juramento", "remaining": 5.0, "stacks": 3})
		Sim.player.debuffs.append({"kind": "dot", "remaining": 3.4, "dps": 0.0, "fire": true, "src": -1})
		Sim.player.debuffs.append({"kind": "dot", "remaining": 8.0, "dps": 0.0, "src": -1})
		Sim.player.debuffs.append({"kind": "slow", "remaining": 2.6, "pct": 30.0})
		Sim.player.debuffs.append({"kind": "curse", "remaining": 75.0, "taken_pct": 0.0, "weaken_pct": 0.0})
	if DevArgs.flag("--roteiro"):        # janela L na aba Roteiro: --roteiro=1_10|10_20|20_30 (com --wins=quests)
		main.hud.windows_script._quests_tab = "roteiro"
		main.hud.windows_script._roteiro_band = DevArgs.value("--roteiro")
	if DevArgs.flag("--char_tab"):       # janela C numa aba: --char_tab=status|sets
		main.hud.windows_script._char_tab = DevArgs.value("--char_tab")
	if DevArgs.has("--picks"):           # janela K na aba Talentos (revisar as escolhas)
		main.hud.windows_script._skills_tab = "picks"
	if DevArgs.flag("--web_zoom"):       # teia: zoom e deslocamento iniciais (--web_pan=x,y em px), p.ex. a Fronteira inteira
		main.hud.windows_script._web_zoom = float(DevArgs.value("--web_zoom"))
		var pan := DevArgs.value("--web_pan", "0,0").split(",")
		main.hud.windows_script._web_pan = Vector2(float(pan[0]), float(pan[1]))
	if DevArgs.has("--dnd_check"):      # arrastar e soltar pelos mesmos métodos da janela
		_dnd_check()
	await get_tree().create_timer(0.5).timeout
	for w in wins:
		if w != "":
			main.hud.windows_script.toggle(w)
	if DevArgs.has("--hotbar_drag_check"):    # mouse simulado: poção da bolsa -> F3, skill da janela K -> slot 6
		await _hotbar_drag_check()
	if DevArgs.has("--ui_click_check"):       # mouse real (Input.parse_input_event): clique em janela/barra não ataca, no mundo ataca
		await _ui_click_check()
	if DevArgs.has("--web_click_check"):      # teia (janela K): zoom pela roda e compra de um nó; foto antes em <png>_antes.png
		await _web_click_check(path)
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
	if DevArgs.has("--craft_tip") or DevArgs.flag("--craft_tip"):      # forja/caldeirão: mouse sobre o cartão (--craft_tip=<receita>, padrão: 1º amuleto)
		var station := "alchemist" if DevArgs.value("--craft_tip").begins_with("rec_cape") or DevArgs.value("--craft_tip").begins_with("rec_bag") or DevArgs.value("--craft_tip").begins_with("rec_potion") else "smith"
		main.hud.windows_script.close_all()
		main.hud.npc_ui.open(station)
		main.hud.npc_ui.mode = "craft"
		main.hud.npc_ui._rebuild()
		await get_tree().process_frame
		await get_tree().process_frame
		var rid := DevArgs.value("--craft_tip")
		if rid == "":
			for k in main.hud.npc_ui.craft_cards:
				if str(k).begins_with("rec_amulet"):
					rid = k
					break
		var cc: Control = main.hud.npc_ui.craft_cards.get(rid)
		if cc:
			main.hud.npc_ui._scroll.ensure_control_visible(cc)
			await get_tree().process_frame
			var mv := InputEventMouseMotion.new()
			mv.position = cc.get_global_transform_with_canvas() * Vector2(30, cc.size.y * 0.5)      # em cima do ícone
			mv.global_position = mv.position
			get_viewport().push_input(mv, true)
			Input.warp_mouse(mv.position)
			await get_tree().create_timer(0.3).timeout
		var tp = main.hud.windows_script.get("tooltip")
		print("CRAFT_TIP %s card=%s tip_visible=%s" % [rid, cc != null, tp.visible if tp is Control else "?"])
	if DevArgs.has("--enhance") or DevArgs.flag("--enhance"):          # ferreiro: aprimorar; arma +9 e peito +5 para ver o brilho (--enhance=dwarf_smith: Thrain e lendário 40+)
		var pp := Sim.player
		var smith_id := DevArgs.value("--enhance")
		smith_id = smith_id if smith_id != "" else "smith"
		pp.gold = 5000
		pp.add_item("iron_ore", 30)
		pp.add_item("star_ore", 6)
		if smith_id in Balance.PLUS_KHARZUN_SMITHS:
			pp.gold = 200000
			pp.add_item(Balance.PLUS_KHARZUN_STEEL, 20)
			pp.add_item(Balance.PLUS_KHARZUN_EMBER, 4)
			var lp: Array = GameData.legendary_pool(pp.class_def, Balance.PLUS_KHARZUN_LEVEL)
			if not lp.is_empty():                # vestido: aparece no topo da lista (o +N vem do laço abaixo)
				var li: ItemDef = GameData.items[lp[0]]
				pp.equipment[li.slot] = li
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
			main.hud.npc_ui.open(smith_id)
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
	if DevArgs.flag("--item_tip"):        # dica de um item (--item_tip=<id>): vai para a bolsa e a dica abre ao lado (revisar textos)
		var tip_id := DevArgs.value("--item_tip")
		if GameData.items.has(tip_id):
			Sim.player.add_item(tip_id)
			main.hud.windows_script.show_tip(UiKit.item_tooltip(GameData.items[tip_id]))
			main.hud.windows_script.tooltip.position = Vector2(40, 120)
	if DevArgs.has("--storage"):          # janela do depósito, perto do Guarda-volumes
		for n in Sim.maps[Sim.player.map_id]["def"].npcs:
			if n["role"] == "storage":
				Sim.player.position = n["pos"] + Vector3(0, 0, 1.5)
		Sim.player.storage = {"wolf_pelt": 6, "iron_ore": 12, "potion_hp_m": 3}
		main.hud.windows_script.close_all()
		main.hud.npc_ui.open("storage")
		main.hud.npc_ui.mode = "storage"
		main.hud.npc_ui._rebuild()
	if DevArgs.has("--mount_keeper"):     # tratadora de montarias (Kharzun): --quests=hx_ov_hatch libera o lobo, --mount_kind=dire_wolf já o escolhe
		main.hud.windows_script.close_all()
		main.hud.npc_ui.open(Balance.MOUNT_KEEPER_NPCS[0])
	await get_tree().create_timer(1.0).timeout
	if DevArgs.has("--relic_end"):        # Relicária rolada até o fim (híbridos 35/40 ficam embaixo)
		for sc in main.hud.npc_ui.win.find_children("*", "ScrollContainer", true, false):
			sc.scroll_vertical = 100000
		await get_tree().create_timer(0.3).timeout
	if DevArgs.has("--fps"):              # média de FPS por 3 s com a janela aberta (custo da UI)
		var t0 := Time.get_ticks_msec()
		var frames := 0
		while Time.get_ticks_msec() - t0 < 3000:
			await get_tree().process_frame
			frames += 1
		print("BAG_FPS %.1f" % (frames / 3.0))
	var cw: Dictionary = main.hud.windows_script.wins.get("character", {})
	if not cw.is_empty():               # tamanho da janela C (unidades da tela base 1600×900)
		var cr: Rect2 = (cw["panel"] as Control).get_global_rect()
		print("CHARWIN size=%dx%d pos=%d,%d vp=%s" % [cr.size.x, cr.size.y, cr.position.x, cr.position.y, get_viewport().get_visible_rect().size])
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

## Investigar mancha na tela: `--probe_px=X,Y` (pixel numa tela 1920x1080, levado ao chão y=0 pela câmera) ou
## `--probe_at=x,z`; `--probe_r=<m>` (6). Imprime `PROBE` de cada MeshInstance3D/Decal/Sprite3D/Label3D/luz
## nesse raio (nome, caminho, malha, material, cor, transparência, script do dono) e salva `--screenshot`.
func _probe_near() -> void:
	await get_tree().create_timer(2.5).timeout
	var cam := get_viewport().get_camera_3d()
	var at := Vector3.ZERO
	if DevArgs.flag("--probe_at"):
		var v := DevArgs.value("--probe_at").split(",")
		at = Vector3(float(v[0]), 0, float(v[1]))
	else:
		var v := DevArgs.value("--probe_px").split(",")
		var vs := get_viewport().get_visible_rect().size
		var px := Vector2(float(v[0]) * vs.x / 1920.0, float(v[1]) * vs.y / 1080.0)
		var o := cam.project_ray_origin(px)
		var d := cam.project_ray_normal(px)
		if absf(d.y) > 0.0001:
			at = o + d * (-o.y / d.y)
	var r := float(DevArgs.value("--probe_r", "6"))
	print("PROBE ponto=", at, " jogador=", Sim.player.position if Sim.player else Vector3.ZERO, " raio=", r)
	for n in get_tree().root.find_children("*", "VisualInstance3D", true, false):
		var vi := n as Node3D
		if not vi.is_visible_in_tree():
			continue
		var gp := vi.global_position
		if Vector2(gp.x - at.x, gp.z - at.z).length() > r:
			continue
		var info := "PROBE %s pos=%s path=%s" % [vi.get_class(), gp, vi.get_path()]
		var owner_script := ""
		var up: Node = vi
		while up and owner_script == "":
			if up.get_script():
				owner_script = (up.get_script() as Script).resource_path
			up = up.get_parent()
		info += " script=" + owner_script
		if vi is MeshInstance3D:
			var mi := vi as MeshInstance3D
			info += " mesh=%s aabb=%s" % [mi.mesh.get_class() if mi.mesh else "-", mi.get_aabb().size]
			var mat: Material = mi.material_override
			if mat == null and mi.mesh and mi.mesh.get_surface_count() > 0:
				mat = mi.get_active_material(0)
			if mat is BaseMaterial3D:
				var bm := mat as BaseMaterial3D
				info += " mat=Base albedo=%s transp=%d emis=%s" % [bm.albedo_color, bm.transparency, bm.emission if bm.emission_enabled else Color.BLACK]
			elif mat is ShaderMaterial:
				info += " mat=Shader " + ((mat as ShaderMaterial).shader.resource_path if (mat as ShaderMaterial).shader else "")
		elif vi is Label3D:
			info += " text=" + (vi as Label3D).text.replace("\n", "|")
		elif vi is Light3D:
			info += " light=%s" % (vi as Light3D).light_color
		print(info)
	if _shot_path != "":
		get_viewport().get_texture().get_image().save_png(_shot_path)
	get_tree().quit()

## Paradas da revisão da água: [nome, mapa, tipo (bridge|river|lake|fixed), índice ou ponto].
const WATER_STOPS := [
	["aldara_ponte", "city_aldara", "bridge", 0], ["aldara_rio", "city_aldara", "river", 0], ["aldara_lago", "city_aldara", "lake", 0],
	["floresta_lago", "field_forest", "lake", 0], ["floresta_rio", "field_forest", "river", 0],
	["costa_mar", "field_coast", "lake", 0], ["costa_mangue", "field_coast", "river", 0],
	["porto_cais", "city_port", "fixed", Vector3(4, 0, 58)], ["porto_mar", "city_port", "lake", 0],
	["elfos_riacho", "elf_city", "river", 0], ["elfos_poco", "elf_city", "lake", 1],
	["gelo_lago", "fort_frost", "lake", 0], ["gelo_rio", "fort_frost", "river", 0],
	["lich_poco", "lich_citadel", "lake", 0], ["bile_lago", "fort_ghoul", "lake", 0],
]

func _water_stop_pos(def: MapDef, kind: String, arg) -> Vector3:
	if kind == "fixed":
		return arg
	if kind == "bridge":
		var cr := MapGeometry.water_crossings(def)
		return Vector3(cr[0]["pos"].x, 0, cr[0]["pos"].y) if not cr.is_empty() else Vector3.ZERO
	var n := 0
	for w in def.water:
		if w["kind"] != kind:
			continue
		if n == int(arg):
			if kind == "lake":
				var c: Vector2 = w["pos"]
				var toward := (-c).normalized() if c.length() > 1.0 else Vector2.RIGHT
				var q := c + toward * (float(w["r"]) + 1.5)
				return Vector3(q.x, 0, q.y)
			var pts: PackedVector2Array = w["pts"]
			var i := pts.size() / 2
			var d := (pts[mini(i + 1, pts.size() - 1)] - pts[i]).normalized()
			var q := pts[i] + Vector2(-d.y, d.x) * (float(w["w"]) * 0.5 + 1.2)
			return Vector3(q.x, 0, q.y)
		n += 1
	return Vector3.ZERO

func _water_tour(delta: float) -> void:
	_water_t += delta
	var p := Sim.player
	p.hp = p.stats.max_hp
	if _water_t < 2.0:
		return
	if _water_i >= WATER_STOPS.size():
		get_tree().quit()
		return
	var st: Array = WATER_STOPS[_water_i]
	if DevArgs.flag("--water_only") and not str(st[0]).contains(DevArgs.value("--water_only")):
		_water_i += 1
		return
	var def: MapDef = GameData.maps[st[1]]
	var pos := _water_stop_pos(def, st[2], st[3])
	if p.map_id != st[1]:
		Sim._change_map(p, st[1], pos)
		_water_t = 0.5
		return
	if not has_meta("water_moved"):
		set_meta("water_moved", true)
		p.position = pos
		_water_t = 2.0
	elif _water_t > 4.0:
		get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [_water_dir, _water_i, st[0]])
		if DevArgs.has("--water_mask") and main.map_node and main.map_node.has_meta("water_fx"):     # a textura de margem como PNG
			var wf: WaterFx = main.map_node.get_meta("water_fx")
			Image.create_from_data(wf._bake_size.x, wf._bake_size.y, false, Image.FORMAT_L8, wf._bake_bytes).save_png("%s/%02d_%s_mask.png" % [_water_dir, _water_i, st[0]])
		_water_i += 1
		remove_meta("water_moved")

func _tour(delta: float) -> void:
	_tour_t += delta
	var p := Sim.player
	if not has_meta("tour_leveled"):          # --level=N: turista do nível da zona (teia gasta como bot da build)
		set_meta("tour_leveled", true)
		if DevArgs.flag("--level"):
			p.level = int(DevArgs.value("--level"))
			if p.build_id == "" and not p.class_def.builds.is_empty():
				p.build_id = p.class_def.builds[0]["id"]
			ProgressionSystem.bot_spend(Sim, p, true)
			p.recompute_stats()
	p.hp = p.stats.max_hp
	p.iframe_left = 1.0                        # turista não leva golpe direto (a foto não vira tela de morte)
	if DevArgs.has("--far"):                   # zoom máximo do jogador: ver marcos e o desenho da zona
		main.camera.distance = main.camera.max_distance
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
	elif _tour_t > 3.6 + _tour_k * float(DevArgs.value("--tour_gap", "1.5")):
		var seq := int(DevArgs.value("--tour_seq", "1"))     # --tour_seq=N: N fotos por parada (ver movimento), --tour_gap s entre elas
		var suffix := "" if seq <= 1 else "_%d" % _tour_k
		get_viewport().get_texture().get_image().save_png("%s/tour_%s_%02d_%s%s.png" % [_tour_dir, _tour_map, _tour_i, stops[_tour_i][0], suffix])
		_tour_k += 1
		if _tour_k >= seq:
			_tour_k = 0
			_tour_i += 1
			remove_meta("tour_moved")

func _soak_fight(p: SimEntity) -> void:
	p.hp = p.stats.max_hp
	p.mp = p.stats.max_mp
	var best: SimEntity = null
	var bd := 1e9
	for e in Sim.map_entities(p.map_id):
		if e.kind == SimEntity.Kind.MONSTER and e.is_alive() and (_soak_boss == "" or e.monster_def.id == _soak_boss or e.boss_id >= 0):
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
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
		EntityView.prof_us = 0.0
		if DevArgs.has("--exp_no_hud"):              # medir: HUD inteiro desligado (não desenha nem processa)
			main.hud.visible = false
			main.hud.process_mode = Node.PROCESS_MODE_DISABLED
		if DevArgs.has("--exp_no_minimap"):          # medir: só o minimapa desligado
			main.hud.minimap.visible = false
			main.hud.minimap.process_mode = Node.PROCESS_MODE_DISABLED
	_soak_gpu += RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
	_soak_rcpu += RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid())
	_soak_phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_soak_draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
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
	if _soak_boss != "" and not _soak_boss_placed and p.map_id == _soak_map:
		for e in Sim.map_entities(p.map_id):           # chega com o grupo ao lado do chefe
			if e.kind == SimEntity.Kind.MONSTER and e.monster_def.id == _soak_boss and e.is_alive():
				for c in Sim.map_entities(p.map_id):
					if c == p or (c.kind == SimEntity.Kind.BOT and Sim.same_party(c, p)):
						c.position = e.position + Vector3(4, 0, 4)
				_soak_boss_placed = true
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
		var fx_n: int = main.fx.get_child_count() if main.fx else 0
		if main.fx:
			var kinds := {}
			for c in main.fx.get_children():
				var k: String = c.get_class() + ":" + String(c.name).rstrip("0123456789@")
				kinds[k] = int(kinds.get(k, 0)) + 1
			print("SOAKFX ", kinds)
		var vis_by := {}
		for v in main.views.values():
			if v.visible:
				var kk: String = SimEntity.Kind.keys()[v.entity.kind]
				vis_by[kk] = int(vis_by.get(kk, 0)) + 1
		print("SOAKUI hud_ms=%.2f minimap_ms=%.2f" % [Hud.prof_us / maxf(1, _soak_frames) / 1000.0, Minimap.prof_us / maxf(1, _soak_frames) / 1000.0])
		print("SOAKF frame_ms=%.2f render_cpu_ms=%.2f physics_ms=%.2f" % [_soak_t * 1000.0 / maxf(1, _soak_frames), _soak_rcpu / maxf(1, _soak_frames), _soak_phys / maxf(1, _soak_frames)])
		_soak_rcpu = 0.0
		_soak_phys = 0.0
		Hud.prof_us = 0.0
		Minimap.prof_us = 0.0
		print("SOAKX views_ms=%.2f gpu_ms=%.2f draws=%.0f fx_nodes=%d process_ms=%.2f visiveis=%s" % [EntityView.prof_us / maxf(1, _soak_frames) / 1000.0,
			_soak_gpu / maxf(1, _soak_frames), _soak_draws / maxf(1, _soak_frames), fx_n, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, vis_by])
		EntityView.prof_us = 0.0
		_soak_gpu = 0.0
		_soak_draws = 0.0
		_soak_worst = 0.0
		_soak_t = 0.0
		_soak_frames = 0
	if _soak_left <= 0.0:
		var nt := maxi(1, Sim.tick_count - _soak_ticks0)
		var keys: Array = Sim.prof.keys()
		keys.sort_custom(func(a, b): return Sim.prof[a] > Sim.prof[b])
		for k in keys.slice(0, 14):
			print("SOAK   %-24s %.3f ms/tick" % [k, Sim.prof[k] / nt / 1000.0])
		print("SMOKE SOM: " + Sfx.played_summary())          # o que soou e tocou no mapa visitado (--soak_map)
		var mus: Music = main.get_node_or_null("Music")
		if mus:
			print("SMOKE MUSICA: atual=%s tocadas=%s" % [mus.current, mus.played])
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
			print("SMOKE SOM: " + Sfx.played_summary())
			var mus: Music = main.get_node_or_null("Music")
			if mus:
				print("SMOKE MUSICA: atual=%s tocadas=%s" % [mus.current, mus.played])
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

## --sig_shot=<pasta> [--boss=<id>,...]: aviso de cada assinatura de chefe (GDD act2-boss-signatures) visto da câmera do jogo.
## Leva o jogador (imortal) ao chefe, dois aliados parados ao lado, lança a assinatura e fotografa no meio do aviso.
const BOSS_SIG_SHOTS := {"boss_tide_mother": ["mob_tide_flood", 1.9, 30.0], "boss_agitator_lord": ["mob_drum_frenzy", 2.4, 20.0],
	"boss_troll_king": ["mob_troll_avalanche", 1.4, 30.0], "boss_crossbow_master": ["mob_marksman_brand", 2.2, 20.0],
	"boss_ghar": ["mob_ghar_wall", 1.2, 18.0], "boss_dire_mother": ["mob_dire_pounce", 0.45, 20.0],
	"boss_shazka": ["mob_shazka_twins", 2.7, 20.0], "boss_ulgra": ["mob_ulgra_stampede", 1.7, 30.0], "boss_gorbash": ["mob_gorbash_waves", 2.2, 30.0],
	"boss_kragmar": ["mob_kragmar_temper", 4.6, 22.0], "boss_durgash": ["mob_durgash_throneaxe", 3.0, 22.0]}

func _sig_shot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var only := DevArgs.value("--boss")
	var p: SimEntity = Sim.player
	p.brain = null
	var shots: Dictionary = BOSS_SIG_SHOTS.duplicate()
	# --sig_skill=<skill> [--sig_wait=<s>] [--sig_dist=<m>] [--sig_map=<mapa>] [--sig_burst=N]: filma qualquer skill de
	# qualquer monstro (--boss=<monstro>); burst = N quadros seguidos a partir da espera (_1.._N)
	if DevArgs.flag("--sig_skill"):
		shots = {only: [DevArgs.value("--sig_skill"), float(DevArgs.value("--sig_wait", "0.45")), float(DevArgs.value("--sig_dist", "14"))]}
	var want_map := DevArgs.value("--sig_map")
	for bid in shots:
		if only != "" and not bid in only.split(","):
			continue
		var map_id := ""
		var home := Vector3.ZERO
		for mid in GameData.maps:
			if want_map != "" and mid != want_map:
				continue
			for sp in GameData.maps[mid].spawners:
				if sp["monster_id"] == bid and map_id == "":
					map_id = mid
					home = sp["pos"]
		if map_id == "":
			push_error("SIG_SHOT: %s sem spawner" % bid)
			continue
		Sim.sync()
		Sim._change_map(p, map_id, home + Vector3(7, 0, 0))
		var arrive := Time.get_ticks_msec() + 2000
		while Time.get_ticks_msec() < arrive:      # chegada: imortal antes da escolta do chefe chegar
			Sim.sync()
			p.iframe_left = 1.0
			p.stats.max_hp = 1.0e9
			p.hp = 1.0e9
			await get_tree().process_frame
		Sim.sync()
		var boss: SimEntity = null
		for e: SimEntity in Sim.maps[map_id]["entities"]:
			if e.monster_def != null and e.monster_def.id == bid and e.is_alive():
				boss = e
		if boss == null and bid == "boss_durgash":         # o spawner do trono tem condição (os três clãs): põe direto
			boss = Sim.spawn_monster(GameData.monsters[bid], map_id, home)
		if boss == null:
			push_error("SIG_SHOT: %s não nasceu em %s" % [bid, map_id])
			continue
		var keep_brain = boss.brain
		boss.brain = null
		p.stats.max_hp = 1.0e9
		p.hp = 1.0e9
		p.position = boss.position + Vector3(0, 0, 3.0)
		var allies: Array = []
		for i in 2:
			var b: SimEntity = Sim.spawn_bot(GameData.classes[["paladin", "bishop"][i]], "Aliado %d" % i, map_id, boss.position + Vector3(-3.0 + 6.0 * i, 0, -3.5), boss.level)
			b.brain = null
			b.stats.max_hp = 1.0e9
			b.hp = 1.0e9
			allies.append(b)
		boss.aggro_target = p.id
		p.last_target_id = boss.id            # como em luta: o anel creme do alvo fica sob o chefe
		boss.crowd = 3
		boss.face_towards(p.position)
		main.camera.distance = float(DevArgs.value("--sig_cam", str(shots[bid][2])))     # --sig_cam=<m>: zoom da foto (nomes a 24/34 m)
		await get_tree().create_timer(1.0).timeout
		Sim.sync()
		var s: SkillDef = GameData.skills[shots[bid][0]]
		Sim._add_skills(boss, [s.id])
		if bid == "boss_troll_king":
			for i in 2:                       # chuva de pedras antes: pedregulhos no chão
				BossSignatures.add_cover(Sim, Sim.maps[map_id], boss, boss.position + Vector3(6.0 * (1 - 2 * i), 0, 4.0))
		Sim._start_skill(boss, s, boss.skills.find(s), p.position if bid != "boss_dire_mother" else p.position + Vector3(0, 0, 5))
		if bid == "boss_dire_mother":
			p.position = boss.position + Vector3(0, 0, 8)
		var wait_end := Time.get_ticks_msec() + int(float(shots[bid][1]) * 1000.0)
		while Time.get_ticks_msec() < wait_end:
			Sim.sync()
			p.iframe_left = 1.0
			if bid == "boss_kragmar" and BossSignatures.in_empower_pool(Sim.maps[map_id], boss):
				if boss.buff_stacks(BossSignatures.TEMPER_BUFF) < 3:       # foto: já temperado (anel e brasas da Têmpera)
					boss.put_buff({"id": BossSignatures.TEMPER_BUFF, "remaining": 1.0e9, "stacks": 3})
					MobSystem._apply_fury(boss)
			if bid == "boss_durgash":                       # Machado do Trono: o grupo junta na vítima (as vagas acendem)
				for h in Sim.maps[map_id].get("hazards", []):
					if str(h.get("mode", "")) == "soak" and not h.has("posed"):
						h["posed"] = true
						var c: Vector3 = h["pos"]
						var k := 0
						for o in [p] + allies:
							if o.id != int(h["victim"]):
								o.position = c + Vector3(1.2 * (k * 2 - 1), 0, 0.9)
								k += 1
			if bid == "boss_ghar" and boss.sig.has("wall") and int(boss.sig["wall"]["fury"]) < 4:
				Sim._deal_damage(p, boss, 5, false, false, "physical")      # golpes de frente: fúria contida (pips)
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := dir.path_join("%s.png" % bid)
		get_viewport().get_texture().get_image().save_png(path)
		print("SIG_SHOT %s %s" % [bid, path])
		for i in int(DevArgs.value("--sig_burst", "0")):        # quadros seguidos (golpe curto: impacto some em ~0,4 s)
			Sim.sync()
			p.iframe_left = 1.0
			await RenderingServer.frame_post_draw
			var bp := dir.path_join("%s_%d.png" % [bid, i + 1])
			get_viewport().get_texture().get_image().save_png(bp)
			print("SIG_SHOT %s %s" % [bid, bp])
		Sim.sync()
		for b in allies:
			Sim.despawn(b)
		Sim.reset_boss(boss)
		boss.brain = keep_brain
	get_tree().quit()

## Revisão da trava no chefe (Tab, BossLock): jogador imortal a 7 m do chefe parado, trava, segura D e depois W.
## Grava <pasta>/lock_0_travado.png, lock_1_orbita.png, lock_2_perto.png e lock_3_solto.png; imprime LOCK_SHOT com o raio.
func _lock_shot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var bid := DevArgs.value("--boss", "boss_troll_king")
	var p: SimEntity = Sim.player
	p.brain = null
	var map_id := ""
	var home := Vector3.ZERO
	for mid in GameData.maps:
		for sp in GameData.maps[mid].spawners:
			if sp["monster_id"] == bid and map_id == "":
				map_id = mid
				home = sp["pos"]
	if map_id == "":
		push_error("LOCK_SHOT: %s sem spawner" % bid)
		get_tree().quit()
		return
	Sim.sync()
	Sim._change_map(p, map_id, home + Vector3(7, 0, 0))
	var arrive := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < arrive:
		Sim.sync()
		p.iframe_left = 1.0
		p.stats.max_hp = 1.0e9
		p.hp = 1.0e9
		await get_tree().process_frame
	Sim.sync()
	var boss: SimEntity = null
	for e: SimEntity in Sim.maps[map_id]["entities"]:
		if e.monster_def != null and e.monster_def.id == bid and e.is_alive():
			boss = e
	if boss == null:
		boss = Sim.spawn_monster(GameData.monsters[bid], map_id, home)
	boss.brain = null
	for e: SimEntity in Sim.maps[map_id]["entities"]:     # o resto do mapa não entra na foto brigando
		if e.kind == SimEntity.Kind.MONSTER and e != boss:
			e.brain = null
	p.position = boss.position + Vector3(0, 0, 7.0)
	main.camera.distance = 22.0
	await get_tree().create_timer(0.8).timeout
	Sim.sync()
	main.controller.toggle_lock(Vector3(9999, 0, 9999))     # cursor longe: escolhe o mais perto
	await get_tree().create_timer(0.6).timeout
	await _lock_snap(dir + "/lock_0_travado.png", p, boss)
	var r0 := Vector2(p.position.x - boss.position.x, p.position.z - boss.position.z).length()
	Input.action_press("move_right")
	await get_tree().create_timer(2.5).timeout
	await _lock_snap(dir + "/lock_1_orbita.png", p, boss)
	Input.action_release("move_right")
	Sim.sync()
	var r1 := Vector2(p.position.x - boss.position.x, p.position.z - boss.position.z).length()
	Input.action_press("move_forward")
	await get_tree().create_timer(0.6).timeout
	Input.action_release("move_forward")
	await _lock_snap(dir + "/lock_2_perto.png", p, boss)
	Sim.sync()
	var r2 := Vector2(p.position.x - boss.position.x, p.position.z - boss.position.z).length()
	print("LOCK_SHOT boss=%s locked=%s r_start=%.2f r_after_D=%.2f r_after_W=%.2f" % [bid, main.controller.lock.target_id == boss.id, r0, r1, r2])
	main.controller.toggle_lock(Vector3.ZERO)
	await get_tree().create_timer(0.4).timeout
	await _lock_snap(dir + "/lock_3_solto.png", p, boss)
	print("LOCK_SHOT released=%s" % (not main.controller.lock.active()))
	get_tree().quit()

func _lock_snap(path: String, p: SimEntity, boss: SimEntity) -> void:
	Sim.sync()
	p.hp = p.stats.max_hp
	boss.hp = boss.stats.max_hp
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("LOCK_SHOT " + path)
