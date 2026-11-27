class_name GvgHud
extends Control
## HUD da Guerra de Guildas (design/gdd/guerra-de-guildas.md; contrato wave6 §3): tela de preparação (30 s: elenco com
## papéis, escolha do seu papel, mapinha com o plano, contagem), faixa da guerra no topo (relógio, portões e cristais dos
## dois lados, plano, comandante), contagem de renascer, dica do canhão com o anel de recarga no cursor, roda de ordens
## (segurar `gvg_orders`) e o resumo do fim. Só lê `GvgUi.status()/objects()` e age por `GvgUi` (métodos Sim.gvg_*).

const BAR_W := 560.0
const POLL := 0.2
const PREP_SIZE := Vector2(980, 560)
const COMMENT_COLOR := Color("#8fe3c8")     # mesma cor da guilda no chat (Hud.GUILD_CHAT_COLOR)

var hud                                  # game/ui/hud.gd
var bar: PanelContainer                  # faixa do topo
var _timer: Label
var _plan: Label
var _cmd: Label
var _bars: Dictionary = {}               # "main_N"/"side_N"/"crystal_N"... -> ProgressBar
var _bar_text: Dictionary = {}           # mesma chave -> Label
var prep: PanelContainer
var _prep_title: Label
var _prep_count: Label
var _prep_plan: Label
var _prep_roster: VBoxContainer
var _prep_roles: HBoxContainer
var _prep_map: GvgMap
var _roster_sig := ""
var respawn_label: Label
var cannon_label: Label
var ring: GvgRing
var wheel: GvgWheel
var summary: PanelContainer
var _sum_title: Label
var _sum_text: Label
var _sum_comment: Label
var last_guild_line := ""                # último "Nome: fala" da guilda (comentário do resumo)
var _t := 0.0
var _st: Dictionary = {}

func _ready() -> void:
	name = "GvgHud"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)    # no _ready (já com pai) o set_anchors_preset guardaria o tamanho 0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_bar()
	_build_prep()
	respawn_label = UiKit.label("", 26, Color(1.0, 0.55, 0.45))
	respawn_label.name = "GvgRespawn"
	respawn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	respawn_label.anchor_left = 0.5; respawn_label.anchor_right = 0.5; respawn_label.anchor_top = 0.38
	respawn_label.offset_left = -300; respawn_label.offset_right = 300
	respawn_label.visible = false
	_outline(respawn_label)
	add_child(respawn_label)
	cannon_label = UiKit.label("", 15, Color(1.0, 0.88, 0.6))
	cannon_label.name = "GvgCannonHint"
	cannon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cannon_label.anchor_left = 0.5; cannon_label.anchor_right = 0.5; cannon_label.anchor_top = 1.0; cannon_label.anchor_bottom = 1.0
	cannon_label.offset_left = -330; cannon_label.offset_right = 330; cannon_label.offset_top = -268; cannon_label.offset_bottom = -244
	cannon_label.visible = false
	_outline(cannon_label)
	add_child(cannon_label)
	ring = GvgRing.new()
	add_child(ring)
	wheel = GvgWheel.new()
	wheel.chosen.connect(_on_wheel_chosen)
	add_child(wheel)
	_build_summary()
	_hook(&"gvg_phase", _on_phase)
	_hook(&"gvg_plan_changed", _on_plan_changed)
	_hook(&"gvg_gate_broken", _on_gate_broken)
	_hook(&"gvg_ended", show_summary)
	Events.chat_message.connect(_on_chat)

## Texto solto sobre o mundo: contorno escuro para ler em chão claro (pedra, muralha).
static func _outline(l: Label) -> void:
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.95))
	l.add_theme_constant_override("outline_size", 6)

func _hook(sig: StringName, f: Callable) -> void:
	if Events.has_signal(sig):
		Events.connect(sig, f)

# --- montagem -----------------------------------------------------------------
func _build_bar() -> void:
	bar = PanelContainer.new()
	bar.name = "GvgBar"
	var st := UiKit.panel_style(Color(0.07, 0.05, 0.04, 0.92), GvgUi.WAR_COLOR.darkened(0.3), 6, 2)
	st.set_content_margin_all(6)
	bar.add_theme_stylebox_override("panel", st)
	bar.anchor_left = 0.5; bar.anchor_right = 0.5
	bar.offset_left = -BAR_W * 0.5; bar.offset_right = BAR_W * 0.5; bar.offset_top = 6
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.visible = false
	add_child(bar)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	bar.add_child(col)
	_timer = UiKit.label("", 17, GvgUi.WAR_COLOR)
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_timer)
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 14)
	col.add_child(sides)
	for s in GvgUi.SIDES:
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 1)
		box.name = "side_" + s
		sides.add_child(box)
		var hdr := UiKit.label("", 12, GvgUi.SIDE_COLORS[s])
		hdr.name = "head"
		box.add_child(hdr)
		for k in ["main", "side", "crystal"]:
			var key := "%s_%s" % [k, s]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			box.add_child(row)
			var l := UiKit.label("", 11, UiKit.TEXT)
			l.custom_minimum_size.x = 92
			row.add_child(l)
			var pb := UiKit.bar(Color(0.95, 0.4, 0.75) if k == "crystal" else Color(0.85, 0.65, 0.35), 9)
			pb.max_value = 1.0
			pb.step = 0.001
			pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(pb)
			_bars[key] = pb
			_bar_text[key] = l
	_plan = UiKit.label("", 12, Color(1.0, 0.9, 0.65))
	_plan.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plan.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_plan)
	_cmd = UiKit.label("", 11, UiKit.MUTED)
	_cmd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_cmd)

func _build_prep() -> void:
	prep = UiKit.panel(Color(0.06, 0.05, 0.05, 0.96), GvgUi.WAR_COLOR)
	prep.name = "GvgPrep"
	prep.anchor_left = 0.5; prep.anchor_right = 0.5; prep.anchor_top = 0.5; prep.anchor_bottom = 0.5
	prep.offset_left = -PREP_SIZE.x * 0.5; prep.offset_right = PREP_SIZE.x * 0.5
	prep.offset_top = -PREP_SIZE.y * 0.5; prep.offset_bottom = PREP_SIZE.y * 0.5
	prep.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prep.grow_vertical = Control.GROW_DIRECTION_BOTH
	prep.visible = false
	add_child(prep)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	prep.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	_prep_title = UiKit.label("", 20, GvgUi.WAR_COLOR)
	_prep_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_prep_title)
	_prep_count = UiKit.label("", 26, UiKit.GOLD)
	_prep_count.name = "PrepCount"
	top.add_child(_prep_count)
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 14)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(mid)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 330
	mid.add_child(left)
	left.add_child(UiKit.label("Seu lado", 14, UiKit.GOLD))
	_prep_roster = VBoxContainer.new()
	_prep_roster.name = "PrepRoster"
	_prep_roster.add_theme_constant_override("separation", 2)
	left.add_child(_prep_roster)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	mid.add_child(right)
	right.add_child(UiKit.label("Plano do comandante", 14, UiKit.GOLD))
	_prep_map = GvgMap.new()
	_prep_map.name = "PrepMap"
	_prep_map.custom_minimum_size = Vector2(600, 360)
	right.add_child(_prep_map)
	_prep_plan = UiKit.label("", 13, Color(1.0, 0.9, 0.65))
	_prep_plan.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_prep_plan)
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 10)
	right.add_child(legend)
	for r in GvgUi.ROLE_ORDER:
		legend.add_child(GvgUi.role_chip(r, 18))
		legend.add_child(UiKit.label(GvgUi.role_name(r), 11, GvgUi.ROLES[r][2]))
	var pick := HBoxContainer.new()
	pick.add_theme_constant_override("separation", 6)
	v.add_child(pick)
	pick.add_child(UiKit.label("Seu papel:", 14, UiKit.TEXT))
	_prep_roles = HBoxContainer.new()
	_prep_roles.name = "PrepRoles"
	_prep_roles.add_theme_constant_override("separation", 4)
	pick.add_child(_prep_roles)
	for r in GvgUi.ROLE_ORDER:
		var b := UiKit.button(GvgUi.role_name(r), _on_pick_role.bind(r), 110)
		b.name = "role_" + r
		b.toggle_mode = true
		b.add_theme_color_override("font_color", GvgUi.ROLES[r][2])
		_prep_roles.add_child(b)

func _build_summary() -> void:
	summary = UiKit.panel(Color(0.07, 0.05, 0.04, 0.97), GvgUi.WAR_COLOR)
	summary.name = "GvgSummary"
	summary.anchor_left = 0.5; summary.anchor_right = 0.5; summary.anchor_top = 0.5; summary.anchor_bottom = 0.5
	summary.offset_left = -280; summary.offset_right = 280; summary.offset_top = -100; summary.offset_bottom = 100
	summary.grow_vertical = Control.GROW_DIRECTION_BOTH     # cresce com o texto, sempre centrado
	summary.visible = false
	summary.visibility_changed.connect(_on_summary_visibility)
	summary.z_index = 5                              # desenha por cima dos quadros do HUD que nascem depois (convite, avisos)
	add_child(summary)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	summary.add_child(v)
	_sum_title = UiKit.label("", 26, UiKit.GOLD)
	_sum_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_sum_title)
	_sum_text = UiKit.label("", 14, UiKit.TEXT)
	_sum_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_sum_text)
	_sum_comment = UiKit.label("", 13, COMMENT_COLOR)
	_sum_comment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_sum_comment)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	var lv := UiKit.button("Sair da guerra", _leave, 150)
	lv.name = "GvgLeave"
	h.add_child(lv)
	h.add_child(UiKit.button("Fechar", func(): summary.visible = false, 110))

# --- atualização ----------------------------------------------------------------
func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = POLL
		refresh()
	ring.visible = cannon_label.visible and _operating_cd() >= 0.0

## Relê o estado e redesenha tudo (também chamado direto pelas fotos e testes).
func refresh() -> void:
	_st = GvgUi.status()
	var on := not _st.is_empty()
	var ph := str(_st.get("phase", ""))
	bar.visible = on and ph != "prep"
	prep.visible = on and ph == "prep"
	if not on:
		respawn_label.visible = false
		cannon_label.visible = false
		if wheel.visible:
			wheel.close()
		return
	if prep.visible:
		_refresh_prep()
	if bar.visible:
		_refresh_bar()
	var p: SimEntity = Sim.player
	var dead := p != null and not p.is_alive() and ph == "fight"
	respawn_label.visible = dead
	if dead:
		respawn_label.text = GvgUi.respawn_text(float(_st.get("respawn_in", 0.0)))
	_refresh_cannon(p)

func _name_of(id: int) -> String:
	for it in GvgUi.roster(_st, str(_st.get("player_side", ""))):
		if int(it.get("id", -2)) == id:
			return str(it.get("name", ""))
	var e: SimEntity = Sim.entities.get(id)
	return e.name if e else ""

func _refresh_bar() -> void:
	_timer.text = GvgUi.timer_line(_st)
	var gates: Dictionary = _st.get("gates", {})
	var atk := str(_st.get("attacker", ""))
	for s in GvgUi.SIDES:
		var box := bar.find_child("side_" + s, true, false)
		var g := GvgUi.side_guild(_st, s)
		var who := ("[%s] " % g["tag"]) if g.has("tag") else ""
		var head := box.get_node("head") as Label
		head.text = "%s%s · %s%s" % [who, GvgUi.side_name(s), "ataca" if s == atk else "defende", "  (você)" if s == _st.get("player_side") else ""]
		head.add_theme_color_override("font_color", GvgUi.side_color(_st, s).lightened(0.25))
		for k in ["main", "side"]:
			var key := "%s_%s" % [k, s]
			var f := GvgUi.frac(gates.get(key, 1.0))
			(_bars[key] as ProgressBar).value = f
			(_bar_text[key] as Label).text = GvgUi.pct_text(GvgUi.GATE_LABELS[k], f) if f > 0.0 else GvgUi.GATE_LABELS[k] + " caiu"
			(_bar_text[key] as Label).add_theme_color_override("font_color", UiKit.TEXT if f > 0.0 else Color(1.0, 0.5, 0.35))
		var cf := GvgUi.frac(_st.get("crystal_" + s, 1.0))
		(_bars["crystal_" + s] as ProgressBar).value = cf
		(_bar_text["crystal_" + s] as Label).text = GvgUi.pct_text("Cristal", cf)
	_plan.text = GvgUi.plan_line(_st)
	_cmd.text = GvgUi.commander_line(_st, Sim.player.id if Sim.player else -1, _name_of)

func _refresh_prep() -> void:
	var mine := str(_st.get("player_side", ""))
	var enemy := GvgUi.side_guild(_st, GvgUi.other(mine))
	var verb := "Ataque a" if GvgUi.player_attacks(_st) else "Defesa contra"
	_prep_title.text = "Preparação — %s %s" % [verb, str(enemy.get("name", "guilda inimiga"))]
	_prep_count.text = GvgUi.clock(float(_st.get("time_left", 0.0)))
	var plan_id := str((_st.get("plan", {}) as Dictionary).get(mine, ""))
	_prep_plan.text = "%s — %s" % [GvgUi.plan_name(plan_id), GvgUi.plan_desc(plan_id)] if plan_id != "" else "O comandante ainda escolhe o plano."
	_prep_map.plan = plan_id
	_prep_map.attacker = str(_st.get("attacker", "S"))
	_prep_map.player_side = mine
	_prep_map.gates = {}
	_prep_map.queue_redraw()
	var lst: Array = GvgUi.roster(_st, mine)
	var my_role := str(_st.get("player_role", GvgUi.picked_role))
	var sig := "%s|%s|%d" % [mine, my_role, lst.size()]
	if sig != _roster_sig:
		_roster_sig = sig
		for c in _prep_roster.get_children():
			c.queue_free()
		if lst.is_empty():
			_prep_roster.add_child(UiKit.para("O elenco ainda está chegando...", 12, UiKit.MUTED))
		var cid := int((_st.get("commander", {}) as Dictionary).get(mine, -1))
		for it in lst:
			_prep_roster.add_child(_roster_row(it, cid, my_role))
	for b in _prep_roles.get_children():
		(b as Button).set_pressed_no_signal(b.name == "role_" + my_role)

func _roster_row(it: Dictionary, commander_id: int, my_role: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var me := bool(it.get("is_player", false))
	var role := my_role if me and my_role != "" else str(it.get("role", GvgUi.role_of(str(it.get("class", "")), str(it.get("build_role", "")))))
	row.add_child(GvgUi.role_chip(role, 22))
	row.add_child(GuildUi._class_icon(str(it.get("class", "")), 22))
	var nm := ("♛ " if int(it.get("id", -2)) == commander_id else "") + str(it.get("name", "?"))
	var l := UiKit.label("%s  Nv.%d  ·  %s" % [nm, int(it.get("level", 1)), GvgUi.role_name(role)], 12, UiKit.GOLD if me else UiKit.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	if str(it.get("guild_tag", "")) == "" and bool(it.get("recruit", false)):
		row.add_child(UiKit.label("recruta", 10, UiKit.MUTED))
	return row

func _on_pick_role(role: String) -> void:
	var r := GvgUi.pick_role(role)
	if r != "" and hud:
		hud._notify(r)
	_roster_sig = ""
	refresh()

# --- canhão ----------------------------------------------------------------------
## Canhão mais perto ao alcance de uso (entrada de objects) ou {}.
func near_cannon(p: SimEntity) -> Dictionary:
	if p == null:
		return {}
	var r: float = float(Balance.get("GVG_CANNON_USE_R")) if Balance.get("GVG_CANNON_USE_R") != null else 3.0
	var best := {}
	var bd := r * r
	for o in GvgUi.objects():
		if str(o.get("type", "")) != "cannon" or not bool(o.get("alive", true)):
			continue
		var pos: Vector3 = o.get("pos", Vector3.INF)
		var d := Vector2(pos.x - p.position.x, pos.z - p.position.z).length_squared()
		if d <= bd:
			bd = d
			best = o
	return best

## Canhão que o jogador opera agora ou {}.
func operated_cannon() -> Dictionary:
	var p: SimEntity = Sim.player
	if p == null:
		return {}
	for o in GvgUi.objects():
		if str(o.get("type", "")) == "cannon" and int(o.get("operator_id", -1)) == p.id:
			return o
	for c in _st.get("cannons", []):
		if int(c.get("operator_id", -1)) == p.id:
			return c
	return {}

func _operating_cd() -> float:
	var c := operated_cannon()
	return -1.0 if c.is_empty() else float(c.get("cd", 0.0))

func _refresh_cannon(p: SimEntity) -> void:
	var op := operated_cannon()
	var near := near_cannon(p)
	var txt := GvgUi.cannon_hint(not near.is_empty(), not op.is_empty(), float(op.get("cd", 0.0)))
	cannon_label.text = txt
	cannon_label.visible = txt != "" and str(_st.get("phase", "")) == "fight" and p != null and p.is_alive()
	var full: float = float(Balance.get("GVG_CANNON_CD")) if Balance.get("GVG_CANNON_CD") != null else 6.0
	ring.frac = 0.0 if op.is_empty() else clampf(float(op.get("cd", 0.0)) / maxf(0.1, full), 0.0, 1.0)

## F perto do canhão: operar / sair (contrato: a tecla de interagir de sempre).
func use_cannon() -> String:
	var op := operated_cannon()
	if not op.is_empty():
		GvgUi.api("gvg_cannon_leave")
		return ""
	var c := near_cannon(Sim.player)
	if c.is_empty():
		return "Nenhum canhão perto."
	return str(GvgUi.api("gvg_cannon_use", [int(c.get("id", -1))], "Indisponível."))

# --- entrada ----------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if _st.is_empty() or Sim.player == null:
		return
	if hud and hud._chat_focus:
		return
	if event.is_action_pressed("gvg_orders") and not event.is_echo():
		open_wheel()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("gvg_orders") and wheel.visible:
		wheel.confirm()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and not event.is_echo() and str(_st.get("phase", "")) == "fight" \
			and (not operated_cannon().is_empty() or not near_cannon(Sim.player).is_empty()):
		var r := use_cannon()
		if r != "" and hud:
			hud._notify(r)
		get_viewport().set_input_as_handled()

func open_wheel() -> void:
	wheel.open(GvgUi.player_attacks(_st), bool(_st.get("player_commands", false)))
	if hud:
		hud._update_blocking()

func wheel_open() -> bool:
	return wheel != null and wheel.visible

func _on_wheel_chosen(id: String) -> void:
	var r := GvgUi.give_order(id)
	if hud:
		hud._notify(r if r != "" else ("Ordem: " + GvgUi.order_label(id) if id != GvgUi.TAKE_COMMAND else "Comando trocado."))
		hud._update_blocking()
	refresh()

# --- eventos -----------------------------------------------------------------------
func _on_phase(phase: String) -> void:
	if hud and phase == "fight":
		hud._notify("A guerra começou!")
	_roster_sig = ""
	refresh()

func _on_plan_changed(side: String, plan_id: String, _reason: String) -> void:
	if hud and side == str(GvgUi.status().get("player_side", "")):
		hud._notify("Novo plano: %s" % GvgUi.plan_name(plan_id))

## Texto do aviso de portão caído (puro; testado). `gate_id` = "main_N" (aceita "gate_main_N").
static func gate_notice(gate_id: String, player_side: String) -> String:
	var k := gate_id.trim_prefix("gate_")
	var side := k.get_slice("_", 1)
	var what := "principal" if k.begins_with("main") else "lateral"
	return "O portão %s %s caiu!" % [what, "do NOSSO castelo" if side == player_side else "do castelo " + GvgUi.side_name(side)]

func _on_gate_broken(gate_id: String) -> void:
	if hud:
		hud._notify(gate_notice(gate_id, str(GvgUi.status().get("player_side", ""))))
	refresh()

func _on_chat(sender: String, text: String, channel: String) -> void:
	if channel == "guild" and (Sim.player == null or sender != Sim.player.name):
		last_guild_line = "%s: %s" % [sender, text]

func show_summary(winner: String, s: Dictionary) -> void:
	var side := str(s.get("player_side", GvgUi.status().get("player_side", "")))
	var lines := GvgUi.summary_lines(winner, s, side)
	_sum_title.text = str(lines[0])
	_sum_title.add_theme_color_override("font_color", UiKit.GOLD if winner == side else Color(1.0, 0.5, 0.45))
	_sum_text.text = "\n".join(PackedStringArray(lines.slice(1)))
	var c: Dictionary = s.get("comment", {})
	var line := ("%s: %s" % [c.get("name", "?"), c.get("text", "")]) if not c.is_empty() else last_guild_line
	_sum_comment.text = ("[Guilda] " + line) if line != "" else ""
	var lv := summary.find_child("GvgLeave", true, false) as Button
	if lv:
		lv.visible = GvgUi.in_war()                 # já de volta (saiu antes): só "Fechar"
	summary.visible = true

## O resumo está na tela (o convite de grupo espera ele fechar: hud._on_party_invited).
func summary_open() -> bool:
	return summary != null and summary.visible

func _on_summary_visibility() -> void:
	if hud == null:
		return
	if summary.visible:
		hud.hold_invite()
	else:
		hud.release_invite()

func _leave() -> void:
	GvgUi.api("gvg_leave")
	summary.visible = false
