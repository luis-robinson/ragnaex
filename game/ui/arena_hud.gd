class_name ArenaHud
extends PanelContainer
## Faixa do Campo de Caça da Guilda no topo central do HUD (design/gdd/arena-da-guilda.md): leva, vivos, no portão,
## modificador; na pausa a contagem e os botões "Próxima" e "Sair". No fim, o resumo (`Events.arena_ended`) num cartão
## no meio da tela até fechar. Só lê `Sim.arena_status()` e chama `Sim.arena_next/arena_leave`.

const WIDTH := 460.0
const COL := Color(0.95, 0.75, 0.35)

var _title: Label
var _info: Label
var _buttons: HBoxContainer
var _summary: PanelContainer
var _sum_text: Label
var _t := 0.0

func _init() -> void:
	var st := UiKit.panel_style(Color(0.08, 0.06, 0.04, 0.9), COL.darkened(0.3), 6, 2)
	st.set_content_margin_all(6)
	add_theme_stylebox_override("panel", st)
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -WIDTH * 0.5
	offset_right = WIDTH * 0.5
	offset_top = 6
	visible = false
	name = "ArenaHud"
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	add_child(col)
	_title = UiKit.label("", 16, COL)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)
	_info = UiKit.label("", 12, UiKit.TEXT)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_info)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 8)
	col.add_child(_buttons)
	var nx := UiKit.button("Próxima", func(): Sim.arena_next(), 110)
	nx.name = "ArenaNext"
	_buttons.add_child(nx)
	var lv := UiKit.button("Sair", func(): Sim.arena_leave(), 90)
	lv.name = "ArenaLeave"
	_buttons.add_child(lv)

## Cartão do resumo (filho do HUD, no meio da tela).
func make_summary(parent: Control) -> void:
	_summary = UiKit.panel(Color(0.08, 0.06, 0.04, 0.95), COL)
	_summary.name = "ArenaSummary"
	_summary.anchor_left = 0.5; _summary.anchor_right = 0.5; _summary.anchor_top = 0.5; _summary.anchor_bottom = 0.5
	_summary.offset_left = -220; _summary.offset_right = 220; _summary.offset_top = -120; _summary.offset_bottom = 120
	_summary.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_summary.add_child(v)
	var t := UiKit.label("Campo de Caça — resumo", 18, COL)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	_sum_text = UiKit.label("", 14, UiKit.TEXT)
	v.add_child(_sum_text)
	var b := UiKit.button("Fechar", func(): _summary.visible = false, 120)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
	parent.add_child(_summary)
	Events.arena_ended.connect(show_summary)

## Texto do resumo (puro; testado).
static func summary_text(s: Dictionary) -> String:
	var why: String = {"wipe": "O grupo caiu", "leave": "Vocês saíram", "left": "Você saiu"}.get(str(s.get("reason", "")), "Fim")
	var t := int(float(s.get("time", 0.0)))
	var lines := ["%s na leva %d." % [why, int(s.get("wave", 0))],
		"Ouro: %d   ·   Cartas: %d   ·   Abates: %d" % [int(s.get("gold", 0)), int(s.get("cards", 0)), int(s.get("kills", 0))],
		"Tempo: %d min %02d s" % [t / 60, t % 60]]
	if s.get("new_record", false):
		lines.append("RECORDE DA GUILDA: leva %d!" % int(s.get("record", 0)))
	elif int(s.get("record", 0)) > 0:
		lines.append("Recorde da guilda: leva %d" % int(s.get("record", 0)))
	return "\n".join(PackedStringArray(lines))

func show_summary(s: Dictionary) -> void:
	if _summary == null:
		return
	_sum_text.text = summary_text(s)
	_summary.visible = true

## Linha de cima e de baixo a partir do estado (puro; testado).
static func lines_for(st: Dictionary) -> Array:
	var title := "Leva %d" % int(st.get("wave", 0)) if int(st.get("wave", 0)) > 0 else "Campo de Caça"
	if st.get("boss", false) and st.get("phase", "") == "fight":
		title += " · Chefe"
	elif st.get("elite", false) and st.get("phase", "") == "fight":
		title += " · Rei"
	if str(st.get("mod_label", "")) != "" and st.get("phase", "") == "fight":
		title += " · " + str(st["mod_label"])
	var info: String
	if st.get("phase", "") == "break":
		info = "Próxima leva em %d s  ·  %d ouro" % [int(ceil(float(st.get("break_left", 0.0)))), int(st.get("gold", 0))]
	else:
		info = "%d vivos · %d no portão  ·  %d ouro" % [int(st.get("alive", 0)), int(st.get("waiting", 0)), int(st.get("gold", 0))]
	return [title, info]

func update(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.2
	var st: Dictionary = Sim.arena_status() if Sim.has_method("arena_status") else {}
	visible = not st.is_empty()
	if not visible:
		return
	var l := lines_for(st)
	_title.text = l[0]
	_info.text = l[1]
	_buttons.visible = st.get("phase", "") == "break"
