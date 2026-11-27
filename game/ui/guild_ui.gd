class_name GuildUi
extends RefCounted
## Janela Guilda (O) e textos do lado social (GDD design/gdd/bots-com-memoria.md; contrato
## production/session-state/wave3-contract.md). Só lê a sim pelos métodos do contrato e age por eles;
## método que a sim ainda não tem = a UI some/cala em vez de quebrar (`has`/`api`).
## `src` troca a fonte (testes e --guild_shot usam GuildFake); null = a autoload Sim.

static var src: Object = null
static var revision := 0              # sobe quando guilda/elenco mudam: plaquinhas de nome redesenham
static var tab := "members"           # aba aberta
static var selected_rid := -1         # Conhecidos: quem está selecionado
static var found_name := ""           # texto digitado para fundar
static var found_msg := ""            # resposta da última tentativa de fundar
static var race_boss := ""            # Rival: chefe escolhido para o desafio
static var hunt_pick: Array = []      # Campo de Caça: rids escolhidos (vazio = os sugeridos)
static var hunt_msg := ""             # resposta da última tentativa de entrar

## [id, título, método da sim que libera a aba ("" = sempre)]. Missões = encomendas e pedidos dos bots (aviso ao lado do minimapa abre). As três últimas esperam as specs
## banco-da-guilda / arena-da-guilda / guerra-de-guildas (nomes dos métodos a confirmar com a sim).
const TABS := [["members", "Membros", ""], ["known", "Conhecidos", "roster_list"], ["rival", "Rival", "rival_info"],
	["bank", "Banco", "guild_bank"], ["missions", "Missões", "guild_bank"], ["hunt", "Campo de Caça", "guild_hunt_field"], ["war", "Guerra", "guild_war"]]
const RIVAL_COLOR := Color(1.0, 0.45, 0.35)
const RIVAL_MARK := "⚔"
const HELP_COLOR := Color(1.0, 0.42, 0.55)
const AFFINITY_COLORS := [[-30, Color(0.9, 0.3, 0.3)], [0, Color(0.75, 0.6, 0.5)], [30, Color(0.8, 0.8, 0.85)], [60, Color(0.5, 0.9, 0.55)], [101, Color(1.0, 0.85, 0.4)]]

# --- fonte -----------------------------------------------------------------
static func _api() -> Object:
	return src if src != null else Sim

static func has(m: String) -> bool:
	var o := _api()
	return o != null and o.has_method(m)

## Chama `m` na fonte se existir; senão devolve `fallback`.
static func api(m: String, args: Array = [], fallback: Variant = null) -> Variant:
	if not has(m):
		return fallback
	return _api().callv(m, args)

static func _dict(m: String, args: Array = []) -> Dictionary:
	var v: Variant = api(m, args, {})
	return v if v is Dictionary else {}

static func _arr(m: String, args: Array = []) -> Array:
	var v: Variant = api(m, args, [])
	return v if v is Array else []

static func player_guild() -> Dictionary:
	return _dict("player_guild")

static func offer() -> Dictionary:
	return _dict("guild_offer")

static func help_requests() -> Array:
	return _arr("help_requests")

static func in_guild() -> bool:
	return not player_guild().is_empty()

## Nível da guilda (Balance.GUILD_LEVEL; a sim cria a constante). Sem ela, 15 do GDD §3.4 só para não quebrar.
static func guild_level() -> int:
	var v: Variant = Balance.get("GUILD_LEVEL")
	return int(v) if v != null else 15

## A janela O aparece? Só com guilda, com convite/recusa já feitos ou do nível da guilda em diante (e a sim com o elenco).
static func available(p: SimEntity) -> bool:
	if p == null or not has("player_guild"):
		return false
	if in_guild() or str(offer().get("state", "none")) != "none":
		return true
	return p.level >= guild_level()

## Abas que existem agora (as das specs futuras ficam escondidas até a sim ter o método).
static func visible_tabs() -> Array:
	return TABS.filter(func(t): return t[2] == "" or has(t[2]))

# --- textos puros (testados) -------------------------------------------------
## Nome na plaquinha: "[LAN] Rook", rival com a marca no fim ("[LAN] Sable ⚔").
static func plate_name(name: String, tag: String, rival: bool) -> String:
	var s := ("[%s] %s" % [tag, name]) if tag != "" else name
	return s + (" " + RIVAL_MARK if rival else "")

static func tag_of(entity_id: int) -> String:
	return str(api("guild_tag_of", [entity_id], ""))

static func is_rival(entity_id: int) -> bool:
	return bool(_dict("roster_of", [entity_id]).get("rival", false))

## Plaquinha de uma entidade viva (jogador ou bot).
static func plate_for(e: SimEntity) -> String:
	if e == null:
		return ""
	if not has("guild_tag_of"):
		return e.name
	return plate_name(e.name, tag_of(e.id), e.kind == SimEntity.Kind.BOT and is_rival(e.id))

static func help_notice(req: Dictionary) -> String:
	return "%s pede ajuda em %s" % [str(req.get("name", "?")), map_name(str(req.get("map", "")))]

static func invite_text(guild_name: String) -> String:
	return "A guilda %s te convidou" % guild_name

static func map_name(map_id: String) -> String:
	if map_id == "":
		return "—"
	var d: MapDef = Sim.map_def(map_id) if Sim.has_method("map_def") else null
	return d.name if d else map_id

static func affinity_color(v: int) -> Color:
	for a in AFFINITY_COLORS:
		if v < int(a[0]):
			return a[1]
	return AFFINITY_COLORS.back()[1]

static func _aff_label(v: int) -> String:
	return str(api("affinity_label", [v], str(v)))

static func _pers_label(id: String) -> String:
	return str(api("personality_label", [id], id))

static func _mem_label(kind: String) -> String:
	return str(api("memory_label", [kind], kind))

## "há 5 min" pelo relógio social.
static func ago(at: float) -> String:
	var now := float(api("social_clock", [], at))
	var m := int(maxf(0.0, now - at) / 60.0)
	if m < 1:
		return "agora"
	if m < 60:
		return "há %d min" % m
	return "há %d h" % (m / 60)

static func _class_icon(cid: String, px: int) -> Control:
	var c: ClassDef = GameData.classes.get(cid)
	return UiKit.class_icon(c, px) if c else UiKit.color_square(Color(0.3, 0.3, 0.35), px)

static func _class_name(cid: String) -> String:
	var c: ClassDef = GameData.classes.get(cid)
	return c.name if c else cid

# --- janela ----------------------------------------------------------------
## Conteúdo da janela "guild" (windows.gd chama dentro do corpo rolável).
static func build(w: Control, body: VBoxContainer) -> void:
	var tabs := visible_tabs()
	if not tabs.any(func(t): return t[0] == tab):
		tab = "members"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.name = "GuildTabs"
	body.add_child(row)
	for t in tabs:
		var b := UiKit.button(str(t[1]), _set_tab.bind(w, str(t[0])))
		b.name = "tab_" + str(t[0])
		b.toggle_mode = true
		b.button_pressed = t[0] == tab
		row.add_child(b)
	body.add_child(UiKit.hsep(4))
	match tab:
		"members": _members(w, body)
		"known": _known(w, body)
		"rival": _rival(w, body)
		"hunt": _hunt(w, body)
		"bank": GuildBankUi.build(w, body)     # Banco da Guilda (guild_bank_ui.gd)
		"missions": GuildMissionsUi.build(w, body)   # encomendas e pedidos dos bots (guild_missions_ui.gd)
		"war": GvgUi.build_tab(w, body)        # Guerra de Guildas (gvg_ui.gd)
		_: body.add_child(UiKit.para("Em breve.", 12, UiKit.MUTED))

static func _set_tab(w: Control, t: String) -> void:
	tab = t
	_refresh(w)

static func _refresh(w: Control) -> void:
	if w and w.has_method("refresh_window"):
		w.refresh_window("guild")

static func _members(w: Control, body: VBoxContainer) -> void:
	var g := player_guild()
	if g.is_empty():
		_no_guild(w, body)
		return
	body.add_child(UiKit.label("%s  [%s]" % [g.get("name", "?"), g.get("tag", "")], 16, UiKit.GOLD))
	body.add_child(UiKit.label("Líder: %s  ·  Poder %d  ·  %d membros  ·  Você: %s" % [g.get("leader", "?"), int(g.get("power", 0)),
		(g.get("members", []) as Array).size(), str(g.get("player_rank", "recruta")).capitalize()], 12, UiKit.MUTED))
	for m in g.get("members", []):
		body.add_child(_member_row(m))
	var bar := HBoxContainer.new()
	body.add_child(bar)
	bar.add_child(UiKit.para("Fale com a guilda na aba Guilda do chat (ou /gu texto).", 11, UiKit.MUTED))
	if has("guild_leave"):
		bar.add_child(UiKit.button("Sair da guilda", func(): api("guild_leave"); _refresh(w), 130))

static func _member_row(m: Dictionary) -> Control:
	var rid := int(m.get("rid", -1))
	var r := _dict("roster_entry", [rid]) if rid >= 0 else {}
	var card := UiKit.panel(UiKit.BG_LIGHT, RIVAL_COLOR.darkened(0.3) if r.get("rival", false) else Color(0.3, 0.27, 0.36))
	card.name = "member_" + str(m.get("name", ""))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	row.add_child(_class_icon(str(m.get("class", "")), 30))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 1)
	row.add_child(v)
	var online := int(m.get("entity_id", -1)) >= 0
	var nm := str(m.get("name", "?")) + ("  " + RIVAL_MARK + " rival" if r.get("rival", false) else "")
	v.add_child(UiKit.label(nm, 13, RIVAL_COLOR if r.get("rival", false) else UiKit.TEXT))
	v.add_child(UiKit.label("%s Nv.%d  ·  %s  ·  %s" % [_class_name(str(m.get("class", ""))), int(m.get("level", 1)),
		_pers_label(str(m.get("personality", ""))), ("● " + map_name(str(r.get("map", "")))) if online else "○ fora"], 11,
		Color(0.6, 0.95, 0.65) if online else UiKit.MUTED))
	var mem: Array = r.get("memories", [])
	if not mem.is_empty():
		var last: Dictionary = mem.back()
		v.add_child(UiKit.label("“%s” · %s" % [_mem_label(str(last.get("kind", ""))), ago(float(last.get("at", 0.0)))], 11, Color(0.85, 0.8, 0.95)))
	if not r.is_empty():
		row.add_child(_affinity_box(int(r.get("affinity", 0))))
	return card

## Rótulo + barra -100..100 da afinidade.
static func _affinity_box(v: int) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(96, 0)
	box.add_child(UiKit.label("%s (%d)" % [_aff_label(v), v], 11, affinity_color(v)))
	var b := UiKit.bar(affinity_color(v), 8)
	b.min_value = -100
	b.max_value = 100
	b.value = v
	box.add_child(b)
	return box

## Sem guilda: convite pendente (Aceitar/Recusar) ou fundar a própria no NPC.
static func _no_guild(w: Control, body: VBoxContainer) -> void:
	var o := offer()
	var st := str(o.get("state", "none"))
	if st == "pending":
		var gi := _dict("guild_info", [str(o.get("guild_id", ""))])
		body.add_child(UiKit.label(invite_text(str(gi.get("name", "?"))), 15, UiKit.GOLD))
		body.add_child(UiKit.para("%s convidou em nome de todos. Aceitar é opcional." % o.get("from", "?"), 12, UiKit.TEXT))
		var h := HBoxContainer.new()
		body.add_child(h)
		h.add_child(UiKit.button("Aceitar", func(): respond(true); _refresh(w), 110))
		h.add_child(UiKit.button("Recusar", func(): respond(false); _refresh(w), 110))
		return
	body.add_child(UiKit.label("Você não está em uma guilda.", 15, UiKit.GOLD))
	if not has("guild_found"):
		return
	body.add_child(UiKit.para("Funde a sua no quadro de avisos de uma cidade: os conhecidos que gostam de você entram junto.", 12, UiKit.TEXT))
	var h2 := HBoxContainer.new()
	h2.add_theme_constant_override("separation", 6)
	body.add_child(h2)
	var le := LineEdit.new()
	le.name = "FoundName"
	le.placeholder_text = "Nome da guilda"
	le.max_length = 24
	le.text = found_name
	le.custom_minimum_size = Vector2(240, 0)
	le.text_changed.connect(func(t: String): found_name = t)
	h2.add_child(le)
	var why := str(api("guild_found_error", [found_name.strip_edges()], ""))
	var b := UiKit.button("Fundar guilda", func(): found(found_name.strip_edges()); _refresh(w), 130)
	b.name = "FoundButton"
	h2.add_child(b)
	var msg := found_msg if found_msg != "" else why
	if msg != "":
		body.add_child(UiKit.para(msg, 11, Color(1.0, 0.6, 0.5)))

## Respostas do jogador (únicos caminhos que mudam a sim).
static func respond(accept: bool) -> void:
	api("guild_respond", [accept])
	revision += 1

static func found(guild_name: String) -> String:
	found_msg = str(api("guild_found", [guild_name], "Indisponível."))
	revision += 1
	return found_msg

static func say(text: String) -> void:
	api("guild_say", [text])

static func _known(w: Control, body: VBoxContainer) -> void:
	var lst := _arr("roster_list")
	body.add_child(UiKit.label("Conhecidos  %d" % lst.size(), 14, UiKit.GOLD))
	for r in lst:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.name = "known_%d" % int(r.get("rid", -1))
		body.add_child(row)
		row.add_child(_class_icon(str(r.get("class", "")), 24))
		var rv: bool = r.get("rival", false)
		var b := UiKit.button("%s%s  ·  Nv.%d  ·  %s" % [r.get("name", "?"), "  " + RIVAL_MARK + " RIVAL" if rv else "", int(r.get("level", 1)),
			_pers_label(str(r.get("personality", "")))], func(): selected_rid = int(r.get("rid", -1)); _refresh(w))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.button_pressed = int(r.get("rid", -1)) == selected_rid
		if rv:
			b.add_theme_color_override("font_color", RIVAL_COLOR)
		row.add_child(b)
		row.add_child(_affinity_box(int(r.get("affinity", 0))))
		if int(r.get("rid", -1)) == selected_rid:
			body.add_child(_memories(r))

static func _memories(r: Dictionary) -> Control:
	var card := UiKit.panel(Color(0.1, 0.09, 0.14, 0.95), Color(0.4, 0.36, 0.5))
	card.name = "Memories"
	var v := VBoxContainer.new()
	card.add_child(v)
	var mem: Array = r.get("memories", [])
	var g := str(r.get("guild", ""))
	var gi := _dict("guild_info", [g]) if g != "" else {}
	v.add_child(UiKit.label("%s  ·  %s %s  ·  %s" % [_class_name(str(r.get("class", ""))), str(r.get("build", "")).capitalize(),
		("· guilda " + str(gi.get("name", g))) if g != "" else "", ("em " + map_name(str(r.get("map", "")))) if int(r.get("entity_id", -1)) >= 0 else "fora do mundo"], 11, UiKit.MUTED))
	if mem.is_empty():
		v.add_child(UiKit.label("Nenhuma lembrança de você ainda.", 12, UiKit.MUTED))
	for i in range(mem.size() - 1, -1, -1):          # mais nova primeiro
		var m: Dictionary = mem[i]
		v.add_child(UiKit.label("• %s  —  %s, %s" % [_mem_label(str(m.get("kind", ""))), map_name(str(m.get("map", ""))), ago(float(m.get("at", 0.0)))], 12, UiKit.TEXT))
	return card

static func _rival(w: Control, body: VBoxContainer) -> void:
	var ri := _dict("rival_info")
	if ri.is_empty():
		body.add_child(UiKit.para("Ainda sem rival.", 12, UiKit.MUTED))
		return
	var p: SimEntity = Sim.player
	var card := UiKit.panel(UiKit.BG_LIGHT, RIVAL_COLOR.darkened(0.2))
	card.name = "RivalCard"
	body.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	row.add_child(_class_icon(str(ri.get("class", "")), 64))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	v.add_child(UiKit.label("%s %s" % [RIVAL_MARK, ri.get("name", "?")], 18, RIVAL_COLOR))
	var lv := int(ri.get("level", 1))
	var mine := p.level if p else lv
	var diff := "um nível à frente" if lv > mine else ("um nível atrás" if lv < mine else "no mesmo nível")
	v.add_child(UiKit.label("%s  ·  Nv.%d  (você %d: %s)" % [_class_name(str(ri.get("class", ""))), lv, mine, diff], 13, UiKit.TEXT))
	v.add_child(UiKit.label("Corridas de chefe: %d vitórias · %d derrotas" % [int(ri.get("wins", 0)), int(ri.get("losses", 0))], 13, UiKit.GOLD))
	var titles := _arr("player_titles")
	if not titles.is_empty():
		v.add_child(UiKit.label("Títulos: " + ", ".join(PackedStringArray(titles)), 11, Color(1.0, 0.85, 0.45)))
	body.add_child(UiKit.hsep(4))
	var race: Dictionary = ri.get("race", {})
	if not race.is_empty():
		var left := float(race.get("until", 0.0)) - float(api("social_clock", [], 0.0))
		body.add_child(UiKit.label("Corrida: quem matar %s primeiro" % race.get("boss_name", "?"), 14, UiKit.GOLD))
		body.add_child(UiKit.label(("Suspensa: %s está no seu grupo." % ri.get("name", "?")) if race.get("suspended", false)
			else "Prazo: %d min %02d s" % [int(maxf(0.0, left) / 60.0), int(maxf(0.0, left)) % 60], 12, UiKit.TEXT))
		if has("rival_challenge_cancel"):
			body.add_child(UiKit.button("Desistir da corrida", func(): api("rival_challenge_cancel"); _refresh(w), 170))
		return
	if not has("rival_challenge"):
		return
	body.add_child(UiKit.label("Desafiar para uma corrida de chefe", 14, UiKit.GOLD))
	var bosses := race_bosses(mine)
	if bosses.is_empty():
		body.add_child(UiKit.para("Nenhum chefe da sua faixa para correr.", 12, UiKit.MUTED))
		return
	if not bosses.any(func(m): return m.id == race_boss):
		race_boss = bosses[0].id
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	body.add_child(h)
	var ob := OptionButton.new()
	ob.name = "RaceBoss"
	for i in bosses.size():
		ob.add_item("%s (Nv.%d)" % [bosses[i].name, bosses[i].level], i)
		if bosses[i].id == race_boss:
			ob.select(i)
	ob.item_selected.connect(func(i: int): race_boss = bosses[i].id)
	h.add_child(ob)
	var b := UiKit.button("Desafiar", func(): found_msg = str(api("rival_challenge", [race_boss], "")); _refresh(w), 110)
	b.name = "Challenge"
	h.add_child(b)
	body.add_child(UiKit.para("Quem matar o chefe primeiro vence. Ganhar dá título e afinidade.", 11, UiKit.MUTED))

## Chefes de verdade perto do nível (escolha do desafio; a sim recusa o que não valer).
static func race_bosses(level: int) -> Array:
	var out: Array = []
	for mid in GameData.monsters:
		var m: MonsterDef = GameData.monsters[mid]
		if m.is_boss and absi(m.level - level) <= 5:
			out.append(m)
	out.sort_custom(func(a, b): return a.level < b.level)
	return out.slice(0, 12)

# --- Campo de Caça (design/gdd/arena-da-guilda.md; Sim.guild_hunt_field / arena_enter) ---------------
const ROLE_LABELS := {"tank": "Tanque", "healer": "Cura", "dps": "Dano", "caster": "Dano mágico", "ranged": "Distância"}
const HUNT_COLOR := Color(0.95, 0.75, 0.35)

## "12 min 05 s" (tempo de jogo até a próxima entrada).
static func mmss(s: float) -> String:
	var t := int(ceil(maxf(0.0, s)))
	return "%d min %02d s" % [t / 60, t % 60]

## Botão "Entrar": cinza sem entrada, com o tempo até a próxima (§8.3). Puro (testado).
static func hunt_button(hf: Dictionary) -> Dictionary:
	if hf.is_empty():
		return {"disabled": true, "text": "Entrar"}
	if int(hf.get("charges", 0)) <= 0:
		return {"disabled": true, "text": "Sem entradas · próxima em %s" % mmss(float(hf.get("next_in", 0.0)))}
	if not bool(hf.get("can_enter", false)):
		return {"disabled": true, "text": "Entrar"}
	return {"disabled": false, "text": "Entrar (%d/%d)" % [int(hf.get("charges", 0)), int(hf.get("max", 3))]}

## Escolha valida: só rids que ainda são candidatos, até max_bots; vazia = sugeridos.
static func hunt_selection(hf: Dictionary) -> Array:
	var ok := {}
	for c in hf.get("candidates", []):
		if float(c.get("away", 0.0)) <= 0.0:
			ok[int(c.get("rid", -1))] = true
	var pick: Array = hunt_pick.filter(func(r): return ok.has(int(r)))
	if pick.is_empty() and hunt_pick.is_empty():
		pick = (hf.get("suggested", []) as Array).duplicate()
	return pick.slice(0, int(hf.get("max_bots", 4)))

static func _hunt(w: Control, body: VBoxContainer) -> void:
	var hf := _dict("guild_hunt_field")
	if hf.is_empty():
		body.add_child(UiKit.para("Entre numa guilda para usar o Campo de Caça.", 12, UiKit.MUTED))
		return
	body.add_child(UiKit.label("Campo de Caça da Guilda", 16, UiKit.GOLD))
	body.add_child(UiKit.para("Levas sem fim chegam pelos portões, cada uma mais dura. Só cai ouro (×3), cartas e consumíveis; XP pela metade.", 11, UiKit.MUTED))
	var run: Dictionary = hf.get("run", {})
	if not run.is_empty():
		body.add_child(UiKit.label("Corrida em andamento: leva %d" % int(run.get("wave", 0)), 14, HUNT_COLOR))
		body.add_child(UiKit.button("Sair do Campo", func(): api("arena_leave"); _refresh(w), 150))
		return
	var full := int(hf.get("charges", 0)) >= int(hf.get("max", 3))
	body.add_child(UiKit.label("Entradas: %d/%d%s" % [int(hf.get("charges", 0)), int(hf.get("max", 3)),
		"" if full else "  ·  próxima em " + mmss(float(hf.get("next_in", 0.0)))], 13, UiKit.TEXT))
	# quadro de recordes
	var card := UiKit.panel(Color(0.1, 0.09, 0.14, 0.95), HUNT_COLOR.darkened(0.35))
	card.name = "HuntRecords"
	body.add_child(card)
	var v := VBoxContainer.new()
	card.add_child(v)
	var rec: Dictionary = hf.get("record", {})
	if int(rec.get("wave", 0)) > 0:
		v.add_child(UiKit.label("Recorde da guilda: leva %d" % int(rec["wave"]), 15, HUNT_COLOR))
		v.add_child(UiKit.label(", ".join(PackedStringArray((rec.get("names", []) as Array).map(func(x): return str(x)))), 11, UiKit.MUTED))
	else:
		v.add_child(UiKit.label("Recorde da guilda: nenhum ainda", 13, UiKit.MUTED))
	var per: Dictionary = hf.get("personal", {})
	var parts: Array = []
	for nm in per:
		if int(per[nm]) > 0:
			parts.append("%s %d" % [nm, int(per[nm])])
	if not parts.is_empty():
		v.add_child(UiKit.label("Pessoais: " + "  ·  ".join(PackedStringArray(parts)), 11, UiKit.TEXT))
	var last: Dictionary = hf.get("last", {})
	if not last.is_empty():
		v.add_child(UiKit.label(summary_line(last), 11, Color(0.85, 0.8, 0.95)))
	# grupo
	var pick := hunt_selection(hf)
	var cands: Array = hf.get("candidates", [])
	body.add_child(UiKit.label("Grupo: você + até %d da guilda (%d escolhidos)" % [int(hf.get("max_bots", 4)), pick.size()], 13, UiKit.GOLD))
	if cands.is_empty():
		body.add_child(UiKit.para("Nenhum membro da guilda no mundo agora: você entra sozinho.", 11, UiKit.MUTED))
	for c in cands:
		var rid := int(c.get("rid", -1))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.name = "hunt_%d" % rid
		body.add_child(row)
		row.add_child(_class_icon(str(c.get("class", "")), 24))
		var b := UiKit.button("%s  ·  Nv.%d  ·  %s%s" % [c.get("name", "?"), int(c.get("level", 1)), ROLE_LABELS.get(str(c.get("role", "")), str(c.get("role", ""))),
			"  · no seu grupo" if c.get("in_party", false) else ""], _toggle_pick.bind(w, rid, pick, int(hf.get("max_bots", 4))))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.button_pressed = rid in pick
		var away := float(c.get("away", 0.0))
		if away > 0.0:                                # banco da guilda: fora numa encomenda
			b.disabled = true
			b.button_pressed = false
			b.text += "  · fora numa encomenda, %d min" % maxi(1, int(ceil(away / 60.0)))
		row.add_child(b)
	var st := hunt_button(hf)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	body.add_child(h)
	var go := UiKit.button(str(st["text"]), func(): hunt_msg = str(api("arena_enter", [pick], "Indisponível.")); hunt_pick = []; _refresh(w), 220)
	go.name = "HuntEnter"
	go.disabled = bool(st["disabled"])
	h.add_child(go)
	h.add_child(UiKit.button("Sugeridos", func(): hunt_pick = []; _refresh(w), 110))
	var why := hunt_msg if hunt_msg != "" else (str(hf.get("why", "")) if int(hf.get("charges", 0)) > 0 else "")
	if why != "":
		body.add_child(UiKit.para(why, 11, Color(1.0, 0.6, 0.5)))

static func _toggle_pick(w: Control, rid: int, cur: Array, max_bots: int) -> void:
	var p := cur.duplicate()
	if rid in p:
		p.erase(rid)
	elif p.size() < max_bots:
		p.append(rid)
	hunt_pick = p if not p.is_empty() else [-1]          # [-1] = ninguém escolhido (não volta aos sugeridos)
	_refresh(w)

## Resumo de uma corrida numa linha (janela e aviso do HUD).
static func summary_line(s: Dictionary) -> String:
	var why: String = {"wipe": "o grupo caiu", "leave": "saída", "left": "saída"}.get(str(s.get("reason", "")), "")
	var t := int(float(s.get("time", 0.0)))
	return "Última: leva %d (%s) · %d ouro · %d carta%s · %d:%02d%s" % [int(s.get("wave", 0)), why, int(s.get("gold", 0)), int(s.get("cards", 0)),
		"" if int(s.get("cards", 0)) == 1 else "s", t / 60, t % 60, "  · RECORDE!" if s.get("new_record", false) else ""]
