class_name StartRequest
extends RefCounted
## O pedido que a tela inicial (start.tscn) passa ao jogo (main.tscn): quem entra e como.
## Vive em estáticos porque a troca de cena libera tudo; o `main` consome com `take()` no `_ready`.
## Também guarda `returning` (voltou do jogo pelo Esc) e o último espaço jogado, que a tela inicial lê ao reabrir.
## Spec: design/ux/start-flow.md §5, §7, §8.

## Pedido à espera do `main` (null = ninguém pediu: o `main` aberto direto decide sozinho).
static var pending: StartRequest = null
## Voltou do jogo pelo Esc ("Salvar e voltar ao menu"): a tela inicial abre em Personagens e não repete o --autostart.
static var returning := false
## Espaço do personagem que acabou de sair (card já selecionado na lista); -1 = nenhum.
static var last_slot := -1
## Última falha do Carregamento (texto do log; a faixa vermelha mostra a frase fixa). A lista pode ler e limpar.
static var error := ""

var class_id := ""               # id da ClassDef (save carregado: a do save vence no `start_game`)
var char_name := ""
var load_save := false           # true = carregar o save de `slot`
var look: Dictionary = {}        # SimEntity.look da criação
var preset := 1                  # começo rápido (StartCatalog.PRESETS); 1 = nível 1 normal
var slot := -1                   # SaveSystem.slot do personagem; -1 = partida de teste (nunca grava)
var dev := false                 # partida de dev (--autostart, --tour...): montagem síncrona, sem Carregamento
var held: Array = []             # Resources carregados em thread, guardados vivos até o `main` avisar "pronto" (§7)
var load_paths: PackedStringArray = []     # o que o Carregamento pediu em thread (main.tscn, GLB do mapa, kit)
var loading: Node = null         # overlay de Carregamento na raiz (o `main` libera depois do "pronto")

## Personagem novo vindo da Criação, no espaço livre `slot`.
static func new_character(cls_id: String, name: String, look_: Dictionary, preset_: int, slot_: int) -> StartRequest:
	var r := StartRequest.new()
	r.class_id = cls_id
	r.char_name = name
	r.look = look_.duplicate()
	r.preset = preset_
	r.slot = slot_
	return r

## Personagem salvo no espaço `slot` (classe/nome do resumo; o save manda no `start_game`).
static func from_slot(slot_: int, cls_id: String, name: String) -> StartRequest:
	var r := StartRequest.new()
	r.class_id = cls_id
	r.char_name = name
	r.load_save = true
	r.slot = slot_
	return r

## Partida automática de dev/smoke (`DevRunner.autostart_class`): espaço -1, nome "Smoke".
static func dev_start(cls_id: String, preset_: int) -> StartRequest:
	var r := StartRequest.new()
	r.class_id = cls_id
	r.char_name = "Smoke"
	r.preset = preset_
	r.slot = -1
	r.dev = true
	return r

## Consome e solta as cargas em thread ainda não entregues (`load_paths`): falha no Carregamento antes do
## `main._await_loads`. Uma carga em curso é esperada (o load_threaded_get bloqueia até ela acabar). Devolve quantas soltou.
func drop_loads() -> int:
	var n := 0
	for p in load_paths:
		if ResourceLoader.load_threaded_get_status(p) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_get(p)      # o Resource some com a referência
			n += 1
	load_paths = PackedStringArray()
	return n

## Entrega o pedido pendente e o limpa (null se não houver).
static func take() -> StartRequest:
	var r := pending
	pending = null
	return r

## Lê e limpa `returning` (vale uma vez: a próxima abertura da tela inicial é normal).
static func take_returning() -> bool:
	var r := returning
	returning = false
	return r

## Mapa onde o personagem vai aparecer (arte e nome do Carregamento, GLB pedido em thread): o do save, o do
## começo rápido ou a cidade (mesma regra do `main._spawn_player` / `ProgressionSystem.apply_start_preset`).
func destination_map() -> String:
	var town := GameData.town_map_id()
	if load_save:
		var m := str(SaveSystem.load_data(slot).get("map", ""))
		return m if GameData.maps.has(m) else town
	var pr: Dictionary = StartCatalog.PRESETS.get(preset, {})
	var pm := str(pr.get("map", ""))
	return pm if GameData.maps.has(pm) else town

## Kit do personagem (`KitModel.path_for`): classe e sexo do save ou da criação.
func kit_path() -> String:
	var cid := class_id
	var lk := look
	if load_save:
		var d := SaveSystem.load_data(slot)
		cid = str(d.get("class", cid))
		var dl: Variant = d.get("look", {})
		lk = dl if dl is Dictionary else {}
	var cls: ClassDef = GameData.classes.get(cid, GameData.classes.get("paladin"))
	var body := str(lk.get("sex", cls.body_type if cls else "male"))
	return KitModel.path_for(body, cls.id if cls else "")

## O que vale carregar em thread enquanto o Carregamento aparece (só caminhos que existem).
func preload_list(main_scene: String) -> PackedStringArray:
	var out := PackedStringArray()
	var def: MapDef = GameData.maps.get(destination_map())
	var cands := [main_scene, kit_path()]
	if def and def.model != "":
		cands.append("res://assets/models/%s.glb" % def.model)
	for c in cands:
		if c != "" and not out.has(c) and ResourceLoader.exists(c):
			out.append(c)
	return out
