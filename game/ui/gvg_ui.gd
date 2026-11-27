class_name GvgUi
extends RefCounted
## Guerra de Guildas na apresentação (design/gdd/guerra-de-guildas.md; contrato production/session-state/wave6-contract.md §3):
## aba "Guerra" da janela da Guilda, textos puros do HUD da guerra, comandos do chat e ordens da roda.
## Só lê a sim pelos métodos do contrato e age por eles; a fonte é a mesma do GuildUi (`GuildUi.src`: testes e
## --gvg_shot usam GvgFake; null = a autoload Sim). Método que a sim ainda não tem = a UI cala em vez de quebrar.

const MAP_ID := "gvg_field"
const SIDES := ["N", "S"]
const SIDE_NAMES := {"N": "Norte", "S": "Sul"}
## Cor de cada lado quando a guilda não tem brasão conhecido (só apresentação).
const SIDE_COLORS := {"N": Color(0.35, 0.55, 0.95), "S": Color(0.9, 0.35, 0.3)}
## Brasão (GuildSystem "crest", 0..5) -> [pano, desenho]. Paleta só de apresentação (estandartes, faixas, aríetes).
const CREST_COLORS := [
	[Color(0.95, 0.72, 0.3), Color(0.25, 0.18, 0.1)],    # 0 lanterna dourada
	[Color(0.45, 0.5, 0.58), Color(0.9, 0.9, 0.95)],     # 1 lobo de ferro
	[Color(0.28, 0.36, 0.3), Color(0.12, 0.1, 0.14)],    # 2 corvo do brejo
	[Color(0.62, 0.2, 0.18), Color(0.95, 0.8, 0.45)],    # 3 escudo de Kharzun
	[Color(0.5, 0.3, 0.7), Color(0.95, 0.7, 0.95)],      # 4 fenda
	[Color(0.2, 0.45, 0.65), Color(0.95, 0.95, 0.88)],   # 5 porto
]
const CREST_MARKS := ["✦", "▲", "◆", "■", "●", "▼"]
const PERSONALITY_LABELS := {"agressiva": "agressiva", "defensiva": "defensiva", "astuta": "astuta", "equilibrada": "equilibrada"}
const WAR_COLOR := Color(1.0, 0.62, 0.32)
const OVERHEARD_COLOR := "#ff9a6a"     # chat: linha "ouvida do campo" (inimigo)

## Planos do comandante (GDD §3.6): id -> [nome, descrição, ataque?].
const PLANS := {
	"martelo": ["Martelo", "Tudo no portão principal.", true],
	"pinca": ["Pinça", "Portão principal e lateral ao mesmo tempo.", true],
	"bateria": ["Bateria", "Primeiro tomar o morro dos canhões.", true],
	"cerco_lento": ["Cerco Lento", "Os canhões derrubam o portão; ninguém se expõe.", true],
	"muralha": ["Muralha", "Todos em cima da muralha.", false],
	"surtida": ["Surtida", "Sair e queimar os aríetes.", false],
	"recuo": ["Recuo", "Abrir mão do portão e segurar a escada.", false],
}
## Ordens da roda (ids do contrato): [id, rótulo, lado que pode dar: "atk" | "def" | ""].
const ORDERS := [
	["attack_gate_main", "Todos no portão", "atk"],
	["attack_gate_side", "Portão lateral", "atk"],
	["protect_ram", "Proteger o aríete", "atk"],
	["take_hill", "Tomar o morro", ""],
	["hold_stair", "Segurar a escada", "def"],
	["sally", "Surtida", "def"],
	["retreat", "Recuar", ""],
	["all_to_me", "Comigo!", ""],
]
const TAKE_COMMAND := "take_command"
## Papéis da guerra (GDD §3.6): id -> [nome, letra do ícone, cor].
const ROLES := {
	"muro": ["Muro", "M", Color(0.45, 0.65, 1.0)],
	"cura": ["Cura", "C", Color(0.5, 0.95, 0.55)],
	"artilharia": ["Artilharia", "A", Color(1.0, 0.75, 0.3)],
	"ponta": ["Ponta", "P", Color(1.0, 0.42, 0.38)],
	"batedor": ["Batedores", "B", Color(0.8, 0.55, 1.0)],
}
const ROLE_ORDER := ["muro", "cura", "artilharia", "ponta", "batedor"]
const GATE_LABELS := {"main": "Portão", "side": "Lateral"}
const GVG_MODELS := ["mob_siege_ram", "mob_siege_cannon", "mob_throne_crystal"]

static var msg := ""                      # resposta da última ação da aba Guerra (gvg_start)
static var picked_role := ""              # papel escolhido na preparação (se a sim não devolver o dela)

# --- fonte -----------------------------------------------------------------
static func has(m: String) -> bool:
	return GuildUi.has(m)

static func api(m: String, args: Array = [], fallback: Variant = null) -> Variant:
	return GuildUi.api(m, args, fallback)

static func status() -> Dictionary:
	return GuildUi._dict("gvg_status")

static func objects() -> Array:
	return GuildUi._arr("gvg_objects")

## Há guerra (preparação, luta ou fim) com o jogador nela?
static func in_war() -> bool:
	return not status().is_empty()

static func is_war_map(map_id: String) -> bool:
	return map_id == MAP_ID

# --- textos puros (testados) ---------------------------------------------------
## "12:05" (relógio da guerra).
static func clock(s: float) -> String:
	var t := int(ceil(maxf(0.0, s)))
	return "%d:%02d" % [t / 60, t % 60]

static func side_name(side: String) -> String:
	return str(SIDE_NAMES.get(side, side))

static func other(side: String) -> String:
	return "S" if side == "N" else "N"

static func player_attacks(st: Dictionary) -> bool:
	return str(st.get("attacker", "")) != "" and st.get("attacker") == st.get("player_side")

static func plan_name(id: String) -> String:
	return str(PLANS[id][0]) if PLANS.has(id) else (id.capitalize() if id != "" else "—")

static func plan_desc(id: String) -> String:
	return str(PLANS[id][1]) if PLANS.has(id) else ""

static func order_label(id: String) -> String:
	for o in ORDERS:
		if o[0] == id:
			return str(o[1])
	return "Assumir o comando" if id == TAKE_COMMAND else id

static func role_name(id: String) -> String:
	id = role_key(id)
	return str(ROLES[id][0]) if ROLES.has(id) else id

## A IA chama o papel de "batedores"; a UI usa "batedor".
static func role_key(id: String) -> String:
	return "batedor" if id == "batedores" else id

## Papel da guerra pelo papel da build (contrato §3: tank → Muro, healer → Cura, ranged → Artilharia, dps → Ponta;
## assassino/ranger → Batedores). A sim manda o dela no elenco; isto é só a reserva.
static func role_of(class_id: String, build_role: String) -> String:
	if class_id in ["assassin", "ranger"] and build_role != "healer" and build_role != "tank":
		return "batedor"
	return {"tank": "muro", "healer": "cura", "ranged": "artilharia", "caster": "artilharia"}.get(build_role, "ponta")

## Linha do relógio: "⚔ 12:05 · Você ataca o Norte" / "Preparação 0:25".
static func timer_line(st: Dictionary) -> String:
	var ph := str(st.get("phase", ""))
	var t := clock(float(st.get("time_left", 0.0)))
	if ph == "prep":
		return "Preparação  %s" % t
	if ph == "end":
		return "Fim da guerra"
	var mine := str(st.get("player_side", ""))
	if player_attacks(st):
		return "⚔ %s  ·  Você ataca o castelo %s" % [t, side_name(other(mine))]
	return "⚔ %s  ·  Você defende o castelo %s" % [t, side_name(mine)]

## "Plano: Pinça — Portão principal e lateral ao mesmo tempo."
static func plan_line(st: Dictionary) -> String:
	var plan: Dictionary = st.get("plan", {})
	var id := str(plan.get(str(st.get("player_side", "")), ""))
	if id == "":
		return "Plano: —"
	return "Plano: %s — %s" % [plan_name(id), plan_desc(id)]

## "Você comanda" / "O comandante é Rook". `name_of` = id -> nome (a sim; nos testes um dicionário).
static func commander_line(st: Dictionary, player_id: int, name_of: Callable) -> String:
	if bool(st.get("player_commands", false)):
		return "Você comanda  ·  roda de ordens: %s" % KeyBindings.label("gvg_orders")
	var cid := int((st.get("commander", {}) as Dictionary).get(str(st.get("player_side", "")), -1))
	if cid == player_id and cid >= 0:
		return "Você comanda  ·  roda de ordens: %s" % KeyBindings.label("gvg_orders")
	var nm := str(name_of.call(cid)) if cid >= 0 else ""
	return ("O comandante é %s" % nm) if nm != "" else "Sem comandante"

static func respawn_text(s: float) -> String:
	return "Você caiu  ·  renasce em %d s" % int(ceil(maxf(0.0, s)))

## Dica do canhão: perto = "[F] Operar o canhão"; operando = mira e recarga.
static func cannon_hint(near: bool, operating: bool, cd: float) -> String:
	var k := KeyBindings.label("interact")
	if operating:
		var ready := "pronto: %s atira" % KeyBindings.label("attack") if cd <= 0.0 else "recarga %.1f s" % cd
		return "Canhão  ·  mire com o cursor  ·  %s  ·  [%s] sair" % [ready, k]
	if near:
		return "[%s] Operar o canhão" % k
	return ""

## Barra de vida de um objeto: "Portão 64%".
static func pct_text(label: String, pct: float) -> String:
	return "%s %d%%" % [label, roundi(frac(pct) * 100.0)]

## % do contrato pode vir 0-1 ou 0-100: sempre 0-1.
static func frac(v: Variant) -> float:
	var f := float(v) if v != null else 0.0
	return clampf(f / 100.0 if f > 1.0 else f, 0.0, 1.0)

## Ordem pode ser dada por este lado?
static func order_ok(order: Array, attacker: bool) -> bool:
	return order[2] == "" or (order[2] == "atk") == attacker

## Setor da roda pelo vetor do centro até o mouse (0 = em cima, sentido horário); -1 = perto demais do centro.
static func wheel_index(v: Vector2, count: int, dead: float = 28.0) -> int:
	if v.length() < dead or count <= 0:
		return -1
	var a := fposmod(atan2(v.x, -v.y), TAU)       # 0 em cima, cresce para a direita
	return int(floor(a / TAU * count + 0.5)) % count

## Ids da roda: as 8 ordens e por último assumir/devolver o comando.
static func wheel_ids() -> Array:
	var out: Array = ORDERS.map(func(o): return o[0])
	out.append(TAKE_COMMAND)
	return out

# --- comandos do chat ------------------------------------------------------------
## Tira acentos e sobra só letras minúsculas: "Pinça" -> "pinca", "portão" -> "portao".
static func plain(s: String) -> String:
	var t := s.strip_edges().to_lower()
	for pair in [["ç", "c"], ["ã", "a"], ["á", "a"], ["â", "a"], ["à", "a"], ["é", "e"], ["ê", "e"], ["í", "i"], ["ó", "o"], ["ô", "o"], ["õ", "o"], ["ú", "u"]]:
		t = t.replace(pair[0], pair[1])
	return t

## Ordens do catálogo da IA (data/catalog/gvg_catalog.gd, se já existir).
static func catalog_orders() -> Dictionary:
	var path := "res://data/catalog/gvg_catalog.gd"
	if not ResourceLoader.exists(path):
		return {}
	var s: Script = load(path)
	var c: Dictionary = s.get_script_constant_map() if s else {}
	var o: Variant = c.get("ORDERS", {})
	return o if o is Dictionary else {}

## "/canhoes": ordem própria se a IA tiver ("man_cannons"), senão tomar o morro (a bateria do meio).
static func cannons_order() -> String:
	return "man_cannons" if catalog_orders().has("man_cannons") else "take_hill"

## Texto do chat -> {"kind": "order"|"plan"|"command"|"", "id": String}. Puro (testado).
static func parse_command(text: String) -> Dictionary:
	var t := plain(text)
	var cmd := t.get_slice(" ", 0)
	var arg := t.substr(cmd.length()).strip_edges()
	match cmd:
		"/plano":
			var id := arg.replace(" ", "_")
			return {"kind": "plan", "id": id}
		"/todos":
			if arg.begins_with("portao") or arg == "":
				return {"kind": "order", "id": "attack_gate_side" if arg.contains("lateral") else "attack_gate_main"}
			if arg.begins_with("lateral"):
				return {"kind": "order", "id": "attack_gate_side"}
			if arg in ["aqui", "comigo", "a mim"]:
				return {"kind": "order", "id": "all_to_me"}
			if arg.begins_with("morro"):
				return {"kind": "order", "id": "take_hill"}
			if arg.begins_with("escada"):
				return {"kind": "order", "id": "hold_stair"}
			return {"kind": "", "id": ""}
		"/lateral": return {"kind": "order", "id": "attack_gate_side"}
		"/canhoes", "/canhao": return {"kind": "order", "id": cannons_order()}
		"/recuar", "/recuo": return {"kind": "order", "id": "retreat"}
		"/morro": return {"kind": "order", "id": "take_hill"}
		"/escada": return {"kind": "order", "id": "hold_stair"}
		"/surtida": return {"kind": "order", "id": "sally"}
		"/ariete": return {"kind": "order", "id": "protect_ram"}
		"/comigo": return {"kind": "order", "id": "all_to_me"}
		"/comando", "/comandar": return {"kind": "command", "id": arg}
	return {"kind": "", "id": ""}

## Chat: se for comando da guerra, manda para a sim e devolve a resposta ("" = ok); null = não era da guerra.
## Com `Sim.gvg_chat_command` a sim lê o texto ela mesma (dona da regra; "" = não era da guerra); sem ele, parse_command.
static func handle_command(text: String) -> Variant:
	if not in_war():
		return null
	if has("gvg_chat_command"):
		var r := str(api("gvg_chat_command", [text], ""))
		return null if r == "" else r
	var c := parse_command(text)
	if str(c["kind"]) == "":
		return null
	match str(c["kind"]):
		"plan": return str(api("gvg_plan", [c["id"]], "Indisponível."))
		"order": return give_order(str(c["id"]))
		"command": return take_command(str(c["id"]) != "devolver")
	return null

## Ordem (roda ou chat). "" = ok.
static func give_order(id: String) -> String:
	if id == TAKE_COMMAND:
		return take_command(not bool(status().get("player_commands", false)))
	return str(api("gvg_order", [id, null], "Indisponível."))

static func take_command(on: bool) -> String:
	var r: Variant = api("gvg_take_command", [on], "Indisponível.")
	return r if r is String else ""

static func start(guild_id: String, attack: bool) -> String:
	msg = str(api("gvg_start", [guild_id, attack], "Indisponível."))
	return msg

static func pick_role(role: String) -> String:
	picked_role = role
	var r: Variant = api("gvg_pick_role", [role], "")
	return r if r is String else ""

## Cores de uma guilda (pano, desenho) pelo brasão.
static func crest_colors(crest: int) -> Array:
	return CREST_COLORS[posmod(crest, CREST_COLORS.size())]

static func crest_mark(crest: int) -> String:
	return CREST_MARKS[posmod(crest, CREST_MARKS.size())]

## Guilda de um lado na guerra: {id, name, tag, crest}. status.guilds[side] (fonte falsa) ou, na sim de verdade,
## status.names/tags + o brasão da guilda do lado (sim.gvg.sides[side].guild_id); vazio = só a cor do lado.
static func side_guild(st: Dictionary, side: String) -> Dictionary:
	var g: Variant = (st.get("guilds", {}) as Dictionary).get(side, {})
	if g is Dictionary and not (g as Dictionary).is_empty():
		return g
	var nm := str((st.get("names", {}) as Dictionary).get(side, ""))
	if nm == "":
		return {}
	var out := {"name": nm}
	var tag := str((st.get("tags", {}) as Dictionary).get(side, ""))
	if tag != "":
		out["tag"] = tag
	var gid := str(((run().get("sides", {}) as Dictionary).get(side, {}) as Dictionary).get("guild_id", ""))
	if gid != "":
		out["id"] = gid
		var info := GuildUi._dict("guild_info", [gid])
		if info.has("crest"):
			out["crest"] = int(info["crest"])
	return out

## Estado cru da guerra na fonte (`Sim.gvg`; {} sem guerra ou na fonte falsa). Só leitura.
static func run() -> Dictionary:
	var o: Object = GuildUi._api()
	var v: Variant = o.get("gvg") if o != null else null
	return v if v is Dictionary else {}

## Elenco de um lado: status.roster[side] (fonte falsa) ou montado das entidades de sim.gvg.sides[side].ids:
## [{id, name, class, level, role, is_player, recruit}]. Papel = o que a IA deu (GvgBrain) ou o da build.
static func roster(st: Dictionary, side: String) -> Array:
	var rs: Variant = (st.get("roster", {}) as Dictionary).get(side)
	if rs is Array:
		return rs
	var r := run()
	var sd: Dictionary = (r.get("sides", {}) as Dictionary).get(side, {})
	var roles: Dictionary = ((r.get("ai", {}) as Dictionary).get("role_of", {})) if r.get("ai") is Dictionary else {}
	var spawned: Array = r.get("spawned", [])
	var out: Array = []
	for id in sd.get("ids", []):
		var e: SimEntity = Sim.entities.get(int(id))
		if e == null:
			continue
		var role := str(roles.get(e.id, ""))
		if role == "" and e.class_def != null:
			role = GvgBrain.war_role(Sim, e)
		out.append({"id": e.id, "name": e.name, "class": e.class_def.id if e.class_def else "", "level": e.level, "role": role_key(role),
			"is_player": e == Sim.player, "recruit": spawned.has(e.id)})
	return out

## Cor do lado: pano da guilda dele (tint) ou o desenho do brasão (tint2).
static func side_color(st: Dictionary, side: String, accent: bool = false) -> Color:
	var g := side_guild(st, side)
	if g.has("crest"):
		return crest_colors(int(g["crest"]))[1 if accent else 0]
	var c: Color = SIDE_COLORS.get(side, Color(0.7, 0.7, 0.7))
	return c.lightened(0.5) if accent else c

## Lado de um objeto da guerra (portão, aríete, canhão, cristal) pelo id da entidade; "" = neutro/nenhum.
static func object_side(entity_id: int) -> String:
	for o in objects():
		if int(o.get("id", -1)) == entity_id:
			return str(o.get("side", ""))
	return ""

## Cor do material `tint`/`tint2` de um modelo da guerra (EntityView); alfa 0 = não pinta.
static func model_tint(e: SimEntity, mat_name: String) -> Color:
	if e == null or e.monster_def == null or not mat_name.begins_with("tint"):
		return Color(0, 0, 0, 0)
	var obj := str(e.get("gvg_obj")) if e.get("gvg_obj") != null else ""
	if obj == "" and not (e.monster_def.model in GVG_MODELS):
		return Color(0, 0, 0, 0)
	var side := str(e.get("gvg_side")) if e.get("gvg_side") != null else ""
	if side == "":
		side = object_side(e.id)
	if side == "":
		return Color(0.6, 0.58, 0.55)               # canhão neutro do morro
	return side_color(status(), side, mat_name.begins_with("tint2"))

# --- resumo do fim ---------------------------------------------------------------
## Linhas do resumo (puro; testado). `s` = summary do gvg_ended.
static func summary_lines(winner: String, s: Dictionary, player_side: String) -> Array:
	var won := winner != "" and winner == player_side
	var t := int(float(s.get("time", 0.0)))
	var how := str(s.get("how", s.get("reason", "")))           # GvgSystem.finish: "reason"
	var lines: Array = ["VITÓRIA!" if won else ("DERROTA" if winner != "" else "Empate")]
	var why: String = {"crystal": "O Cristal do Trono caiu.", "time": "O relógio acabou com o Cristal de pé.", "leave": "Você saiu da guerra.",
		"forfeit": "Você saiu da guerra.", "left": "Você deixou o campo da guerra."}.get(how, "")
	if why != "":
		lines.append(why)
	lines.append("Tempo: %d min %02d s" % [t / 60, t % 60])
	if s.get("player") is Dictionary:
		var me: Dictionary = s["player"]
		lines.append("Você: %d abates · %d quedas · %d de dano no portão · %d no Cristal" % [int(me.get("kills", 0)), int(me.get("deaths", 0)),
			int(me.get("gate_dmg", 0)), int(me.get("crystal_dmg", 0))])
		if int(me.get("cannon_hits", 0)) > 0:
			lines.append("Tiros de canhão certeiros: %d" % int(me["cannon_hits"]))
	elif s.get("kills") is Dictionary:
		# a sim de verdade conta por lado: abates e quedas de cada um
		var foe := other(player_side)
		var k: Dictionary = s["kills"]
		var d: Dictionary = s.get("deaths", {}) if s.get("deaths") is Dictionary else {}
		lines.append("Seu lado: %d abates · %d quedas  ·  Inimigo: %d abates · %d quedas" % [int(k.get(player_side, 0)), int(d.get(player_side, 0)),
			int(k.get(foe, 0)), int(d.get(foe, 0))])
		var gb: Variant = s.get("gates_broken", {})
		if gb is Dictionary and not (gb as Dictionary).is_empty():
			lines.append("Portões derrubados: %d" % (gb as Dictionary).size())
		var cs: Dictionary = s.get("stats", {}) if s.get("stats") is Dictionary else {}
		if int(cs.get("cannon_hits", 0)) > 0:
			lines.append("Tiros de canhão certeiros: %d" % int(cs["cannon_hits"]))
	lines.append("Insígnias de Guerra: +%d  ·  Ouro: +%d" % [int(s.get("insignias", 0)), int(s.get("gold", 0))])
	return lines

# --- aba Guerra da janela da Guilda ------------------------------------------------
## Botão Atacar/Defender: {disabled, text, why}. Puro (testado).
static func start_button(gw: Dictionary, g: Dictionary, attack: bool) -> Dictionary:
	var text := "Atacar" if attack else "Defender"
	if not bool(gw.get("can_start", false)):
		return {"disabled": true, "text": text, "why": str(gw.get("why", ""))}
	var why := str(g.get("why_attack" if attack else "why_defend", ""))
	return {"disabled": why != "", "text": text, "why": why}

static func build_tab(w: Control, body: VBoxContainer) -> void:
	var gw := GuildUi._dict("guild_war")
	body.add_child(UiKit.label("Guerra de Guildas", 16, WAR_COLOR))
	body.add_child(UiKit.para("Ataque o castelo de uma guilda ou defenda o da sua contra ela: 12 contra 12, níveis igualados ao seu. "
		+ "Derrube o portão e quebre o Cristal do Trono; quem defende segura até o relógio acabar.", 11, UiKit.MUTED))
	if gw.is_empty():
		body.add_child(UiKit.para("Entre numa guilda para guerrear.", 12, UiKit.MUTED))
		return
	var rec: Dictionary = gw.get("record", {})
	var head := UiKit.label("Vitórias %d · Derrotas %d  ·  Insígnias de Guerra: %d" % [int(rec.get("wins", 0)), int(rec.get("losses", 0)),
		int(gw.get("insignias", 0))], 13, UiKit.GOLD)
	head.name = "WarRecord"
	body.add_child(head)
	var st := status()
	if not st.is_empty():
		body.add_child(UiKit.label("Guerra em andamento: " + timer_line(st), 13, WAR_COLOR))
	for g in gw.get("guilds", []):
		body.add_child(_guild_card(w, gw, g))
	var why := msg if msg != "" else ("" if bool(gw.get("can_start", false)) else str(gw.get("why", "")))
	if why != "":
		var l := UiKit.para(why, 11, Color(1.0, 0.6, 0.5))
		l.name = "WarWhy"
		body.add_child(l)

static func _guild_card(w: Control, gw: Dictionary, g: Dictionary) -> Control:
	var gid := str(g.get("id", ""))
	var crest := int(g.get("crest", GuildUi._dict("guild_info", [gid]).get("crest", 0)))
	var cols := crest_colors(crest)
	var card := UiKit.panel(UiKit.BG_LIGHT, (cols[0] as Color).darkened(0.2))
	card.name = "war_" + gid
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	row.add_child(crest_chip(crest, str(g.get("tag", "")), 40))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 1)
	row.add_child(v)
	v.add_child(UiKit.label("%s  [%s]" % [g.get("name", "?"), g.get("tag", "")], 14, UiKit.TEXT))
	var pers := str(g.get("personality", ""))
	var info := "%s  ·  Poder %d" % [str(PERSONALITY_LABELS.get(pers, GuildUi._pers_label(pers))).capitalize(), int(g.get("power", 0))]
	if bool(g.get("castle_owner", false)):
		info += "  ·  ♜ dona do castelo"
	v.add_child(UiKit.label(info, 11, Color(1.0, 0.85, 0.5) if bool(g.get("castle_owner", false)) else UiKit.MUTED))
	var btns := VBoxContainer.new()
	btns.add_theme_constant_override("separation", 3)
	row.add_child(btns)
	for attack in [true, false]:
		var sb := start_button(gw, g, attack)
		var b := UiKit.button(str(sb["text"]), _on_start.bind(w, gid, attack), 96)
		b.name = ("gvg_attack_" if attack else "gvg_defend_") + gid
		b.disabled = bool(sb["disabled"])
		if str(sb["why"]) != "":
			b.tooltip_text = str(sb["why"])
		btns.add_child(b)
	var why_g := str(g.get("why_attack", g.get("why_defend", "")))
	if why_g != "" and bool(gw.get("can_start", false)):
		v.add_child(UiKit.label(why_g, 10, Color(1.0, 0.6, 0.5)))
	return card

static func _on_start(w: Control, gid: String, attack: bool) -> void:
	start(gid, attack)
	GuildUi._refresh(w)

## Quadradinho do brasão: pano da guilda, marca e a sigla.
static func crest_chip(crest: int, tag: String, px: int) -> Control:
	var cols := crest_colors(crest)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(px, px)
	p.add_theme_stylebox_override("panel", UiKit.panel_style(cols[0], cols[1], 4, 2))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", -2)
	p.add_child(v)
	var m := UiKit.label(crest_mark(crest), int(px * 0.4), cols[1])
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.add_theme_font_override("font", UiKit.mark_font())
	v.add_child(m)
	if tag != "" and px >= 32:
		var t := UiKit.label(tag, int(px * 0.24), cols[1])
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
	return p

## Ícone redondo de papel (letra na cor do papel).
static func role_chip(role: String, px: int) -> Control:
	var info: Array = ROLES.get(role_key(role), ["?", "?", Color(0.6, 0.6, 0.6)])
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(px, px)
	p.add_theme_stylebox_override("panel", UiKit.panel_style((info[2] as Color).darkened(0.6), info[2], px / 2, 2))
	var l := UiKit.label(str(info[1]), int(px * 0.55), info[2])
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.tooltip_text = str(info[0])
	return p
