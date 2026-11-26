class_name UnlockNotice
extends Control
## Aviso de uma linha da introdução dos sistemas (GDD design/gdd/introducao-de-sistemas.md §3.3): enquanto o NPC
## dono de um sistema chama (UnlockSystem.pending), uma faixa no alto diz quem quer falar com você; a 1ª vez também
## sai como notificação. Quando o sistema abre, a dica (Tips) daquele sistema sai junto. Só apresentação.

## Sistema -> nome curto do que o NPC ensina (texto da faixa).
const LABELS := {"basics": "primeiros passos", "web": "teia de skills", "shop": "loja", "talents": "talentos de classe",
	"party": "grupo", "ranks": "ranks de skill", "sets": "conjuntos lendários", "enhance": "aprimoramento",
	"bags": "bolsas", "evolutions": "evoluções e cargas", "apex": "Ápice e híbridos"}
## Sistema -> dica de Tips.TIPS que sai quando ele abre.
const TIP_OF := {"basics": "quest", "web": "web", "talents": "talents", "party": "party", "bags": "bag"}
const POLL := 0.5

var hud
var line: PanelContainer
var label: Label
var announced: Dictionary = {}     # sistemas já avisados por notificação nesta partida
var _poll := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line = UiKit.panel(Color(0.1, 0.09, 0.14, 0.9), UiKit.GOLD)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label = UiKit.label("", 15, UiKit.GOLD)
	line.add_child(label)
	add_child(line)
	line.grow_horizontal = Control.GROW_DIRECTION_BOTH
	line.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 78)
	line.visible = false
	Events.system_unlocked.connect(_on_unlocked)
	Events.level_up.connect(func(_id: int, _lv: int): _poll = 0.0)

func _process(delta: float) -> void:
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL
		refresh()

## Texto do aviso para `e` ("" = ninguém chama). Puro: testes e revisão.
static func text_for(e: SimEntity) -> String:
	var pend: Array = UnlockSystem.pending(e)
	if pend.is_empty():
		return ""
	var q: QuestDef = GameData.quests[pend[0][1]]
	return "%s quer falar com você (%s)" % [QuestSystem.npc_name(q.giver_npc), LABELS.get(pend[0][0], pend[0][0])]

func refresh() -> void:
	var p: SimEntity = Sim.player
	var t := text_for(p) if p else ""
	if t != "" and not announced.has(t):
		announced[t] = true
		Events.notification.emit(t)
	if label.text != t:
		label.text = t
		line.reset_size()
		line.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 78)
	line.visible = t != ""

func _on_unlocked(id: int, sys: String) -> void:
	if Sim.player == null or id != Sim.player.id or hud == null or hud.tips == null:
		return
	if TIP_OF.has(sys):
		hud.tips.request(TIP_OF[sys])
	_poll = 0.0
