class_name GuildSystem
extends RefCounted
## Guildas (design/gdd/bots-com-memoria.md §3.4, §9.3, §9.6): a do elenco (nasce no GUILD_LEVEL com os 4-6 bots de maior
## afinidade, nome dado pelos bots, convite opcional), a que o jogador funda num NPC de guilda (nome digitado) e as
## guildas de bots do mundo (dados para a GvG, guerra-de-guildas.md). Estado em `sim.guilds` (id -> guilda) e
## `sim.social` ("offer", "player_guild", "gq" = respostas da guilda esperando). Formato no wave3-contract.md.
## Campos reservados para o banco da guilda (banco-da-guilda.md): `player_rank`, `contribution`.

const SAVE_KEYS := ["id", "name", "tag", "personality", "crest", "bot_guild", "player_member", "founded_by_player", "leader",
	"members", "player_rank", "contribution", "created_at"]

# ---------------------------------------------------------------------------
# SAVE

static func to_save(sim: WorldSim) -> Dictionary:
	if not sim.roster_on and sim.guilds.is_empty():
		return {}
	var list: Array = []
	for gid in sim.guilds:
		var g: Dictionary = sim.guilds[gid]
		var o := {}
		for k in SAVE_KEYS:
			o[k] = g.get(k)
		o["members"] = (g["members"] as Array).map(func(m: Dictionary): return {"name": m["name"], "class": m["class"],
			"build": m["build"], "level": int(m["level"]), "personality": m["personality"], "rid": int(m["rid"])})
		list.append(o)
	return {"v": 1, "offer": (sim.social.get("offer", {}) as Dictionary).duplicate(), "player_guild": str(sim.social.get("player_guild", "")),
		"list": list}

static func from_save(sim: WorldSim, d: Dictionary) -> void:
	sim.guilds.clear()
	for o in d.get("list", []):
		if not (o is Dictionary) or str(o.get("id", "")) == "":
			continue
		var g := {}
		for k in SAVE_KEYS:
			g[k] = o.get(k)
		g["members"] = []
		for m in o.get("members", []):
			if m is Dictionary and GameData.classes.has(str(m.get("class", ""))):
				g["members"].append({"name": str(m.get("name", "")), "class": str(m["class"]), "build": str(m.get("build", "")),
					"level": int(m.get("level", 1)), "personality": str(m.get("personality", "")), "rid": int(m.get("rid", -1))})
		g["crest"] = int(g.get("crest", 0) if g.get("crest") != null else 0)
		g["contribution"] = int(g.get("contribution", 0) if g.get("contribution") != null else 0)
		g["player_rank"] = str(g.get("player_rank", "recruta") if g.get("player_rank") != null else "recruta")
		g["created_at"] = float(g.get("created_at", 0.0) if g.get("created_at") != null else 0.0)
		for k in ["bot_guild", "player_member", "founded_by_player"]:
			g[k] = bool(g.get(k, false) if g.get(k) != null else false)
		for k in ["name", "tag", "personality", "leader"]:
			g[k] = str(g.get(k, "") if g.get(k) != null else "")
		sim.guilds[str(g["id"])] = g
	var off: Dictionary = d.get("offer", {}) if d.get("offer") is Dictionary else {}
	sim.social["offer"] = {"state": str(off.get("state", "none")), "guild_id": str(off.get("guild_id", "")), "from": str(off.get("from", ""))}
	var pg := str(d.get("player_guild", ""))
	sim.social["player_guild"] = pg if sim.guilds.has(pg) and bool(sim.guilds[pg]["player_member"]) else ""
	# o elenco aponta para guildas que existem (save editado / guilda sumida)
	for r: Dictionary in sim.roster:
		if r["guild"] != "" and not sim.guilds.has(r["guild"]):
			r["guild"] = ""

# ---------------------------------------------------------------------------
# GUILDAS DE BOTS DO MUNDO

## Cria as guildas de bots (BOT_GUILD_COUNT, de BotsCatalog.BOT_GUILDS) se ainda não existem.
static func ensure_world(sim: WorldSim) -> void:
	var have := 0
	for gid in sim.guilds:
		if bool(sim.guilds[gid]["bot_guild"]):
			have += 1
	if have >= Balance.BOT_GUILD_COUNT:
		return
	var taken := {}
	for r: Dictionary in sim.roster:
		taken[r["name"]] = true
	for gid in sim.guilds:
		for m in sim.guilds[gid]["members"]:
			taken[m["name"]] = true
	var classes: Array = GameData.class_list()
	for spec: Dictionary in BotsCatalog.BOT_GUILDS:
		if have >= Balance.BOT_GUILD_COUNT:
			break
		var gid := "g_" + slug(spec["name"])
		if sim.guilds.has(gid):
			continue
		var g := _new_guild(sim, gid, spec["name"], spec["tag"], spec["personality"], int(spec["crest"]))
		g["bot_guild"] = true
		var n := sim.rng.randi_range(Balance.BOT_GUILD_MEMBERS.x, Balance.BOT_GUILD_MEMBERS.y)
		for i in n:
			var nm := _free_bot_name(sim, taken)
			taken[nm] = true
			var cls: ClassDef = classes[sim.rng.randi() % classes.size()]
			var build: String = cls.builds[sim.rng.randi() % cls.builds.size()]["id"] if cls.builds.size() > 0 else ""
			var lv := clampi(sim.player.level + sim.rng.randi_range(-Balance.BOT_GUILD_LEVEL_SPREAD, Balance.BOT_GUILD_LEVEL_SPREAD), 1, Balance.MAX_LEVEL)
			var pers: Array = BotsCatalog.PERSONALITIES
			g["members"].append({"name": nm, "class": cls.id, "build": build, "level": lv, "personality": pers[sim.rng.randi() % pers.size()], "rid": -1})
		g["leader"] = g["members"][0]["name"] if not g["members"].is_empty() else ""
		sim.guilds[gid] = g
		have += 1
	Events.post(&"guild_changed", "")

static func _free_bot_name(sim: WorldSim, taken: Dictionary) -> String:
	var pool: Array = BotsCatalog.NAMES
	var start := sim.rng.randi() % pool.size()
	for i in pool.size():
		var nm: String = pool[(start + i) % pool.size()]
		if not taken.has(nm):
			return nm
	var k := 2
	while taken.has("%s%d" % [pool[start], k]):
		k += 1
	return "%s%d" % [pool[start], k]

static func _new_guild(sim: WorldSim, gid: String, nm: String, tag: String, personality: String, crest: int) -> Dictionary:
	return {"id": gid, "name": nm, "tag": tag, "personality": personality, "crest": crest, "bot_guild": false, "player_member": false,
		"founded_by_player": false, "leader": "", "members": [], "player_rank": "recruta", "contribution": 0,
		"created_at": float(sim.social.get("clock", 0.0))}

## "Coração de Aldara" -> "coracao_de_aldara" (id estável da guilda).
static func slug(nm: String) -> String:
	var low := nm.to_lower()
	var from := "áàâãäéèêëíìîïóòôõöúùûüç"
	var to := "aaaaaeeeeiiiiooooouuuuc"
	var out := ""
	for c in low:
		var ch := c
		var i := from.find(ch)
		if i >= 0:
			ch = to[i]
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
		elif not out.ends_with("_") and out != "":
			out += "_"
	return out.trim_suffix("_")

## Etiqueta de 2-4 letras pelas iniciais das palavras ("Coração de Aldara" -> "CDA"; uma palavra = 3 primeiras letras).
static func make_tag(nm: String) -> String:
	var words := slug(nm).split("_", false)
	if words.size() == 1:
		return words[0].substr(0, 3).to_upper()
	var t := ""
	for w in words:
		t += w.substr(0, 1)
	return t.substr(0, 4).to_upper()

# ---------------------------------------------------------------------------
# GUILDA DO ELENCO (convite no GUILD_LEVEL)

## Passada (RosterSystem.update): convite no 15, membros que saem/entram pela afinidade, respostas no chat da guilda.
static func update(sim: WorldSim, _step: float) -> void:
	var offer: Dictionary = sim.social["offer"]
	if offer["state"] == "none" and sim.player.level >= Balance.GUILD_LEVEL:
		form(sim)
	_flush(sim)

## Os GUILD_SIZE_MIN..MAX bots de maior afinidade (fora o rival e quem já tem guilda) formam a guilda e convidam.
static func form(sim: WorldSim) -> Dictionary:
	var cands: Array = sim.roster.filter(func(r: Dictionary): return not r["rival"] and r["guild"] == "")
	cands.sort_custom(func(a: Dictionary, b: Dictionary): return int(a["affinity"]) > int(b["affinity"]) or (int(a["affinity"]) == int(b["affinity"]) and int(a["rid"]) < int(b["rid"])))
	var n := mini(cands.size(), sim.rng.randi_range(Balance.GUILD_SIZE_MIN, Balance.GUILD_SIZE_MAX))
	if n <= 0:
		return {}
	var nm := _pick_name(sim)
	var g := _new_guild(sim, "g_" + slug(nm), nm, make_tag(nm), "equilibrada", sim.rng.randi() % maxi(1, BotsCatalog.BOT_GUILDS.size()))
	for i in n:
		_add_member(g, cands[i])
	g["leader"] = cands[0]["name"]
	sim.guilds[g["id"]] = g
	sim.social["offer"] = {"state": "pending", "guild_id": g["id"], "from": g["leader"]}
	Events.post(&"guild_changed", g["id"])
	Events.post(&"guild_invite", g["id"], g["leader"])
	Events.post(&"roster_changed")
	RosterSystem.say(sim, cands[0], "guild_invite", "whisper", {"guild": nm}, true)
	return g

static func _pick_name(sim: WorldSim) -> String:
	var used := {}
	for gid in sim.guilds:
		used[sim.guilds[gid]["name"]] = true
	var free: Array = BotsCatalog.GUILD_NAMES.filter(func(x): return not used.has(x))
	if free.is_empty():
		return "%s %d" % [BotsCatalog.GUILD_NAMES[0], sim.guilds.size() + 1]
	return free[sim.rng.randi() % free.size()]

static func _add_member(g: Dictionary, r: Dictionary) -> void:
	r["guild"] = g["id"]
	g["members"].append({"name": r["name"], "class": r["class"], "build": r["build"], "level": int(r["level"]), "personality": r["personality"], "rid": int(r["rid"])})

static func _drop_member(g: Dictionary, r: Dictionary) -> void:
	r["guild"] = ""
	g["members"] = (g["members"] as Array).filter(func(m: Dictionary): return int(m["rid"]) != int(r["rid"]))
	if g["leader"] == r["name"] and not (g["founded_by_player"] and g["player_member"]):
		g["leader"] = g["members"][0]["name"] if not (g["members"] as Array).is_empty() else ""

## Responde o convite pendente.
static func respond(sim: WorldSim, accept: bool) -> void:
	if not sim.roster_on:
		return
	var offer: Dictionary = sim.social["offer"]
	if offer["state"] != "pending" or not sim.guilds.has(offer["guild_id"]):
		return
	var g: Dictionary = sim.guilds[offer["guild_id"]]
	if accept:
		offer["state"] = "accepted"
		_join_player(sim, g)
		_cheer(sim, g, "guild_welcome", 2)
	else:
		offer["state"] = "refused"
		var r := RosterSystem.entry(sim, _rid_of(g, g["leader"]))
		if not r.is_empty():
			RosterSystem.say(sim, r, "guild_refused", "whisper", {"guild": g["name"]}, true)
	Events.post(&"guild_changed", g["id"])
	Events.post(&"roster_changed")

static func _join_player(sim: WorldSim, g: Dictionary) -> void:
	g["player_member"] = true
	g["player_rank"] = "recruta"
	sim.social["player_guild"] = g["id"]

static func _rid_of(g: Dictionary, nm: String) -> int:
	for m in g["members"]:
		if m["name"] == nm:
			return int(m["rid"])
	return -1

## Por que o jogador não pode fundar `guild_name` agora ("" = pode).
static func found_error(sim: WorldSim, guild_name: String) -> String:
	var pl := sim.player
	if pl == null or not sim.roster_on:
		return "Indisponível agora."
	if pl.level < Balance.GUILD_LEVEL:
		return "Guilda só a partir do nível %d." % Balance.GUILD_LEVEL
	if str(sim.social.get("player_guild", "")) != "":
		return "Você já está numa guilda."
	if sim.social["offer"]["state"] == "pending":
		return "Responda antes o convite da guilda."
	if not near_guild_npc(sim, pl):
		return "Fale com o registro de guildas (o quadro de missões de uma cidade) para fundar."
	var nm := guild_name.strip_edges()
	if nm.length() < Balance.GUILD_NAME_LEN.x or nm.length() > Balance.GUILD_NAME_LEN.y:
		return "O nome precisa de %d a %d letras." % [Balance.GUILD_NAME_LEN.x, Balance.GUILD_NAME_LEN.y]
	var s := slug(nm)
	if s == "":
		return "Nome inválido."
	for gid in sim.guilds:
		if gid == "g_" + s or str(sim.guilds[gid]["name"]).to_lower() == nm.to_lower():
			return "Já existe uma guilda com esse nome."
	return ""

static func near_guild_npc(sim: WorldSim, e: SimEntity) -> bool:
	var def: MapDef = sim.map_def(e.map_id)
	if def == null:
		return false
	for n in def.npcs:
		if str(n.get("role", "")) in Balance.GUILD_NPC_ROLES and Vector2(n["pos"].x, n["pos"].z).distance_to(Vector2(e.position.x, e.position.z)) <= Balance.GUILD_NPC_RANGE:
			return true
	return false

## Funda a guilda do jogador. Entram os bots do elenco sem guilda (fora o rival) com afinidade >= 0, de maior afinidade.
static func found(sim: WorldSim, guild_name: String) -> String:
	var err := found_error(sim, guild_name)
	if err != "":
		return err
	var nm := guild_name.strip_edges()
	var g := _new_guild(sim, "g_" + slug(nm), nm, make_tag(nm), "equilibrada", sim.rng.randi() % maxi(1, BotsCatalog.BOT_GUILDS.size()))
	g["founded_by_player"] = true
	g["leader"] = sim.player.name
	_join_player(sim, g)
	g["player_rank"] = "lider"
	var cands: Array = sim.roster.filter(func(r: Dictionary): return not r["rival"] and r["guild"] == "" and int(r["affinity"]) >= 0)
	cands.sort_custom(func(a: Dictionary, b: Dictionary): return int(a["affinity"]) > int(b["affinity"]) or (int(a["affinity"]) == int(b["affinity"]) and int(a["rid"]) < int(b["rid"])))
	for i in mini(cands.size(), Balance.GUILD_SIZE_MAX):
		_add_member(g, cands[i])
	sim.guilds[g["id"]] = g
	sim.social["offer"]["state"] = "founded"
	sim.social["offer"]["guild_id"] = g["id"]
	Events.post(&"guild_changed", g["id"])
	Events.post(&"roster_changed")
	Events.post(&"chat_message", "Sistema", "Guilda %s fundada." % nm, "guild")
	_cheer(sim, g, "guild_founded", 2)
	return ""

## Jogador sai da guilda: ela segue com os bots (o líder vira o de maior afinidade).
static func leave(sim: WorldSim) -> void:
	var gid: String = sim.social.get("player_guild", "")
	if gid == "" or not sim.guilds.has(gid):
		return
	var g: Dictionary = sim.guilds[gid]
	g["player_member"] = false
	if g["leader"] == sim.player.name:
		g["leader"] = g["members"][0]["name"] if not (g["members"] as Array).is_empty() else ""
	sim.social["player_guild"] = ""
	sim.social["offer"]["state"] = "refused"        # fora de guilda: pode fundar outra no NPC
	Events.post(&"chat_message", "Sistema", "Você saiu da guilda %s." % g["name"], "guild")
	Events.post(&"guild_changed", gid)
	Events.post(&"roster_changed")

## Afinidade do bot mudou (RosterSystem.remember): abaixo de 0 sai da guilda do jogador; com GUILD_JOIN_AFFINITY entra.
static func on_affinity(sim: WorldSim, r: Dictionary) -> void:
	var gid: String = sim.social.get("player_guild", "")
	if gid == "" or not sim.guilds.has(gid):
		return
	var g: Dictionary = sim.guilds[gid]
	if r["guild"] == gid and int(r["affinity"]) < 0:
		RosterSystem.say(sim, r, "guild_leave_low", "guild", {"guild": g["name"]}, true)
		_drop_member(g, r)
		Events.post(&"guild_changed", gid)
	elif r["guild"] == "" and not r["rival"] and int(r["affinity"]) >= Balance.GUILD_JOIN_AFFINITY \
			and (g["members"] as Array).size() < Balance.GUILD_MEMBERS_MAX:
		_add_member(g, r)
		RosterSystem.say(sim, r, "guild_join", "guild", {"guild": g["name"]}, true)
		Events.post(&"guild_changed", gid)

## Até `n` membros falam a fala `key` no chat da guilda (com atraso).
static func _cheer(sim: WorldSim, g: Dictionary, key: String, n: int) -> void:
	var said := 0
	for m in g["members"]:
		if said >= n:
			break
		var r := RosterSystem.entry(sim, int(m["rid"]))
		if r.is_empty():
			continue
		_queue(sim, r, RosterSystem.line(sim, r, key, {"guild": g["name"]}), sim.rng.randf_range(Balance.GUILD_REPLY_DELAY.x, Balance.GUILD_REPLY_DELAY.y) * (said + 1))
		said += 1

## Jogador falou no chat da guilda: a linha dele sai no canal e às vezes um membro responde.
static func say(sim: WorldSim, text: String) -> void:
	var gid: String = sim.social.get("player_guild", "") if sim.roster_on else ""
	if gid == "" or sim.player == null or text.strip_edges() == "":
		return
	Events.post(&"chat_message", sim.player.name, text.strip_edges(), "guild")
	if sim.rng.randf() > Balance.GUILD_REPLY_CHANCE:
		return
	var mates: Array = (sim.guilds[gid]["members"] as Array).filter(func(m: Dictionary): return int(m["rid"]) >= 0)
	if mates.is_empty():
		return
	var r := RosterSystem.entry(sim, int(mates[sim.rng.randi() % mates.size()]["rid"]))
	if not r.is_empty():
		_queue(sim, r, RosterSystem.line(sim, r, "guild_reply"), sim.rng.randf_range(Balance.GUILD_REPLY_DELAY.x, Balance.GUILD_REPLY_DELAY.y))

static func _queue(sim: WorldSim, r: Dictionary, text: String, delay: float) -> void:
	if text == "":
		return
	(sim.social["gq"] as Array).append({"at": float(sim.social["clock"]) + delay, "rid": int(r["rid"]), "text": text})

static func _flush(sim: WorldSim) -> void:
	var q: Array = sim.social["gq"]
	if q.is_empty():
		return
	var gid: String = sim.social.get("player_guild", "")
	var keep: Array = []
	for it: Dictionary in q:
		if float(it["at"]) > float(sim.social["clock"]):
			keep.append(it)
			continue
		var r := RosterSystem.entry(sim, int(it["rid"]))
		if gid != "" and not r.is_empty() and r["guild"] == gid:
			Events.post(&"chat_message", r["name"], str(it["text"]), "guild")
	sim.social["gq"] = keep

# ---------------------------------------------------------------------------
# LEITURA

static func player_guild(sim: WorldSim) -> Dictionary:
	var gid: String = sim.social.get("player_guild", "") if sim.roster_on else ""
	return info(sim, gid) if gid != "" else {}

## Cópia da guilda no formato do contrato (poder e entity_id dos membros calculados agora).
static func info(sim: WorldSim, gid: String) -> Dictionary:
	if not sim.guilds.has(gid):
		return {}
	var g: Dictionary = sim.guilds[gid]
	var o := {}
	for k in SAVE_KEYS:
		o[k] = g[k]
	var by_name := {}
	for e: SimEntity in sim.entities.values():
		if e.kind == SimEntity.Kind.BOT and e.owner_id < 0:
			by_name[e.name] = e
	var members: Array = []
	var sum := 0
	for m: Dictionary in g["members"]:
		var mm := m.duplicate()
		var r := RosterSystem.entry(sim, int(m["rid"])) if int(m["rid"]) >= 0 else {}
		var e: SimEntity = RosterSystem.entity_of(sim, r) if not r.is_empty() else by_name.get(m["name"])
		if e != null and int(m["rid"]) < 0 and e.roster_id >= 0:
			e = null                                    # homônimo do elenco não é deste membro
		if not r.is_empty():
			mm["level"] = e.level if e else int(r["level"])
			mm["build"] = r["build"]
		mm["entity_id"] = e.id if e else -1
		sum += int(mm["level"])
		members.append(mm)
	o["members"] = members
	o["power"] = roundi(float(sum) / members.size()) if not members.is_empty() else 0
	return o

static func list(sim: WorldSim) -> Array:
	var out: Array = []
	var pg: String = sim.social.get("player_guild", "")
	if pg != "":
		out.append(info(sim, pg))
	var ids: Array = sim.guilds.keys()
	ids.sort()
	for gid in ids:
		if gid != pg:
			out.append(info(sim, gid))
	return out

## Etiqueta da guilda de quem tem uma ("" = nenhuma): jogador, bot do elenco e bot com o nome de um membro de guilda de bots.
static func tag_of(sim: WorldSim, entity_id: int) -> String:
	if not sim.roster_on:
		return ""
	var e: SimEntity = sim.entities.get(entity_id)
	if e == null:
		return ""
	if e.gvg_side != "" and not sim.gvg.is_empty():
		var wt := GvgSystem.tag_of(sim, e)    # Guerra de Guildas: recruta leva a etiqueta da guilda do lado
		if wt != "":
			return wt
	if e == sim.player:
		var pg: String = sim.social.get("player_guild", "")
		return str(sim.guilds[pg]["tag"]) if pg != "" and sim.guilds.has(pg) else ""
	if e.kind != SimEntity.Kind.BOT:
		return ""
	if e.roster_id >= 0:
		var r := RosterSystem.entry(sim, e.roster_id)
		return str(sim.guilds[r["guild"]]["tag"]) if not r.is_empty() and r["guild"] != "" and sim.guilds.has(r["guild"]) else ""
	var tags: Dictionary = sim.social.get("tag_names", {})
	if int(sim.social.get("tag_rev", -1)) != sim.guilds.size():
		tags = {}
		for gid in sim.guilds:
			var g: Dictionary = sim.guilds[gid]
			if bool(g["bot_guild"]):
				for m in g["members"]:
					tags[m["name"]] = g["tag"]
		sim.social["tag_names"] = tags
		sim.social["tag_rev"] = sim.guilds.size()
	return str(tags.get(e.name, ""))
