class_name Tips
extends Control
## Dicas contextuais (começo guiado): um cartão pequeno aparece UMA vez quando a mecânica fica relevante
## (monstro perto -> ataque; levou dano -> dash/bloqueio; nível 2 -> teia...). Não trava o jogo: some sozinho ou no clique.
## Vistas ficam em user://settings.cfg (seção "tips", vale para todos os personagens); Esc → "Dicas" liga/desliga.
## Só apresentação: lê o estado do jogador e reage a Events.

## id -> texto (pt-BR). A ordem não importa: cada uma tem seu gatilho em `_poll`/eventos.
const TIPS := {
	"move": "WASD anda. O personagem sempre encara o mouse: é para lá que golpes e skills vão.",
	"attack": "Clique esquerdo ataca na direção do mouse. Segure para continuar batendo.",
	"skills": "1-6 usam as skills da barra. Segure o número para ver a mira e solte para lançar.",
	"dash": "Shift dá um dash com um instante de invencibilidade. Botão direito segura a guarda.",
	"potion": "F1-F3 bebem as poções da barra. Arraste outras poções da bolsa para lá.",
	"gather": "F colhe ervas, minérios e caixas brilhando: viram poção, joia e entrega de quest.",
	"quest": "NPCs com ! têm quest: chegue perto e aperte F. L mostra suas quests e o roteiro.",
	"bag": "Item novo na bolsa! I abre a bolsa; arraste a peça para o boneco (C) para equipar.",
	"web": "Você ganhou pontos de skill. K abre a teia: compre caminhos, atributos e skills novas.",
	"talents": "Talentos de classe liberados: aba Talentos na janela K (trocar, só na cidade).",
	"recall": "Longe de casa? G volta para a cidade depois de alguns segundos parado.",
	"mount": "H chama o cavalo: corre bem mais, mas golpes e dano derrubam você da sela.",
	"party": "Convite de grupo! P abre o grupo: caçar junto divide a XP e o saque.",
	"camera": "Q e E giram a câmera. M abre o mapa da zona.",
	"death": "Ao cair você volta para a cidade e perde um pouco de XP. Nada da bolsa se perde.",
}
const SHOW_TIME := 9.0             # s na tela
const GAP := 2.5                   # s entre duas dicas seguidas
const POLL := 0.5
const NEAR_FOE := 12.0             # m: monstro hostil perto = hora de aprender a atacar
const FAR_FROM_TOWN := 60.0        # m do centro da cidade para lembrar do G

static var cfg_path := "user://settings.cfg"     # testes trocam por um arquivo próprio

var hud
var enabled := true
var seen: Dictionary = {}
var _queue: Array[String] = []
var _card: PanelContainer = null
var _label: Label = null
var _left := 0.0
var _gap := 0.0
var _poll := 0.0
var _t := 0.0                      # s desde que o personagem entrou (não conta a tela de seleção)
var _player_id := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	load_state()
	Events.item_gained.connect(_on_item_gained)
	Events.party_invited.connect(_on_party_invited)
	Events.entity_died.connect(_on_died)
	Events.level_up.connect(func(_id: int, _lv: int): _poll = 0.0)

# ---------------------------------------------------------------- estado salvo
func load_state() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(cfg_path) != OK:
		return
	enabled = bool(cfg.get_value("tips", "enabled", true))
	for id in TIPS:
		if bool(cfg.get_value("tips", id, false)):
			seen[id] = true

func _save() -> void:
	if SaveSystem.slot < 0 and cfg_path == "user://settings.cfg":
		return                          # partida automática (smoke/revisão) não gasta as dicas do jogador
	var cfg := ConfigFile.new()
	cfg.load(cfg_path)                  # mantém gráficos/áudio
	cfg.set_value("tips", "enabled", enabled)
	for id in seen:
		cfg.set_value("tips", id, true)
	cfg.save(cfg_path)

func set_enabled(on: bool) -> void:
	enabled = on
	if not on:
		_queue.clear()
		_hide_card()
	_save()

## Pede a dica `id` (uma vez na vida). Devolve se entrou na fila.
func request(id: String) -> bool:
	if not enabled or not TIPS.has(id) or seen.has(id) or _queue.has(id):
		return false
	seen[id] = true
	_save()
	_queue.append(id)
	return true

# ---------------------------------------------------------------- gatilhos
func _process(delta: float) -> void:
	var pid: int = Sim.player.id if Sim.player else -1
	if pid != _player_id:
		_player_id = pid
		_t = 0.0
	_t += delta
	if _card:
		_left -= delta
		if _left <= 0.0:
			_hide_card()
	elif _gap > 0.0:
		_gap -= delta
	elif not _queue.is_empty():
		_show_card(_queue.pop_front())
	_poll -= delta
	if _poll <= 0.0 and enabled:
		_poll = POLL
		_check()

func _check() -> void:
	var p: SimEntity = Sim.player
	if p == null or not p.is_alive() or hud == null or hud.main == null:
		return
	if _t > 2.0:
		request("move")
	if _t > 60.0:
		request("camera")
	if _t > 25.0 and p.quests_active.is_empty() and p.quests_completed.is_empty():
		request("quest")
	var foe := _foe_near(p)
	if foe:
		request("attack")
		if seen.has("attack") and _t > 20.0 and p.skills.any(func(s): return s != null):
			request("skills")
	if p.hp < p.stats.max_hp * 0.75 and foe:
		request("dash")
	if p.hp < p.stats.max_hp * 0.45:
		request("potion")
	if not Sim.nearest_gather(p).is_empty():
		request("gather")
	if p.level >= 2:
		request("web")
	if p.level >= 3:
		request("mount")
	if p.level >= 5:
		request("talents")
	if p.level >= 3 and not foe:
		var def: MapDef = GameData.maps.get(p.map_id)
		if def and (not def.is_town or p.position.distance_to(def.town_center) > FAR_FROM_TOWN):
			request("recall")

func _foe_near(p: SimEntity) -> SimEntity:
	for e in Sim.map_entities(p.map_id):
		if e.kind == SimEntity.Kind.MONSTER and e.is_alive() and e.position.distance_to(p.position) < NEAR_FOE and e.is_hostile_to(p):
			return e
	return null

func _on_item_gained(id: int, item_id: String, _count: int) -> void:
	if Sim.player == null or id != Sim.player.id or _t < 3.0:
		return
	var it: ItemDef = GameData.items.get(item_id)
	if it and it.type == ItemDef.Type.EQUIPMENT:
		request("bag")

func _on_party_invited(_from: int, to_id: int) -> void:
	if Sim.player and to_id == Sim.player.id:
		request("party")

func _on_died(id: int, _killer: int) -> void:
	if Sim.player and id == Sim.player.id:
		request("death")

# ---------------------------------------------------------------- cartão
func _show_card(id: String) -> void:
	_card = UiKit.panel(Color(0.1, 0.09, 0.14, 0.92), UiKit.GOLD)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.gui_input.connect(func(ev: InputEvent): _on_card_input(ev))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	_card.add_child(h)
	h.add_child(UiKit.label("Dica", 13, UiKit.GOLD))
	_label = UiKit.label(TIPS[id], 14, UiKit.TEXT)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size.x = 460
	h.add_child(_label)
	add_child(_card)
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 150)     # acima da barra de ações
	_card.set_meta("tip", id)
	_card.modulate.a = 0.0
	_card.create_tween().tween_property(_card, "modulate:a", 1.0, 0.25)
	_left = SHOW_TIME

func _on_card_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		_hide_card()

func _hide_card() -> void:
	if _card:
		_card.queue_free()
		_card = null
		_label = null
		_gap = GAP

## Dica na tela agora ("" = nenhuma). Revisão e testes.
func current() -> String:
	return str(_card.get_meta("tip", "")) if _card else ""
