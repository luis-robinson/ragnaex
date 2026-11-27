class_name RosterSystem
extends RefCounted
## Bots com Memória (design/gdd/bots-com-memoria.md; decisões §9): o elenco fixo do save (Balance.ROSTER_SIZE bots com nome,
## classe/build, personalidade e nível que persistem), as lembranças do jogador (afinidade), o rival (classe pela tabela
## Balance.RIVAL_CLASS, nível do jogador ±1), o pedido de socorro, a comemoração e o ritmo de fala do elenco.
## Estado: `sim.roster` (entradas) e `sim.social` (relógio, rival, pedido, títulos, ritmos). A guilda é do GuildSystem.
## Só funciona com `sim.roster_on` (o jogo liga com `Sim.roster_start()` ao entrar no mundo; os testes ligam à mão).
## Contrato da UI: production/session-state/wave3-contract.md.
##
## Entrada do elenco (salva): rid, name, class, build, personality, level, look, affinity, memories, rival, guild.
## Só em tempo de jogo: entity_id, line_at, saved_at, group_at, loot_at, greet_at.

const MEMORY_KINDS := ["salvou", "grupo", "abandonou", "ajudou_pedido", "perdeu_saque", "corrida", "presente", "guerra"]
const SAVE_KEYS := ["rid", "name", "class", "build", "personality", "level", "look", "affinity", "memories", "rival", "guild"]

# ---------------------------------------------------------------------------
# INÍCIO, SAVE E LIGAÇÃO COM O MUNDO

## Liga o elenco: usa o save guardado por `from_save` ou sorteia dos bots do mundo (save antigo / personagem novo).
## Chame com o jogador e os bots já na sim. Repetir não faz nada.
static func start(sim: WorldSim) -> void:
	if sim.player == null or sim.roster_on:
		return
	sim.roster_on = true
	_social_defaults(sim)
	var pending: Dictionary = sim.social.get("pending", {})
	sim.social.erase("pending")
	if not pending.is_empty() and pending.get("roster") is Dictionary:
		_load(sim, pending)
	if sim.roster.is_empty():
		draft(sim)
	bind(sim)
	GuildSystem.ensure_world(sim)
	Events.post(&"roster_changed")

static func _social_defaults(sim: WorldSim) -> void:
	var s := sim.social
	s.get_or_add("clock", 0.0)
	s.get_or_add("next_update", 0.0)
	s.get_or_add("next_help", Balance.BOT_HELP_EVERY * 60.0 * 0.5)
	s.get_or_add("next_rival", Balance.RIVAL_STEP_MIN * 60.0)
	s.get_or_add("line_at", -1.0e9)          # última fala solta de qualquer bot do elenco
	s.get_or_add("rival", {"rid": -1, "wins": 0, "losses": 0, "bosses": [], "race": {}, "dev": 1})
	s.get_or_add("offer", {"state": "none", "guild_id": "", "from": ""})
	s.get_or_add("player_guild", "")
	s.get_or_add("help", {})
	s.get_or_add("help_seq", 0)
	s.get_or_add("titles", [])
	s.get_or_add("next_rid", 1)
	s.get_or_add("gq", [])                   # falas da guilda esperando (resposta com atraso)

## Save carregado (SaveSystem.apply_to): guarda para o `start` (os bots do mundo podem ainda não existir).
static func from_save(sim: WorldSim, d: Dictionary) -> void:
	if d.get("roster") is Dictionary:
		sim.social["pending"] = {"roster": d["roster"], "guild": d.get("guild", {})}

## Campo `roster` do save ({} se o elenco não existe).
static func to_save(sim: WorldSim) -> Dictionary:
	if sim.roster.is_empty():
		return {}
	_sync(sim)
	var bots: Array = []
	for r: Dictionary in sim.roster:
		var o := {}
		for k in SAVE_KEYS:
			o[k] = r.get(k)
		bots.append(o)
	var s := sim.social
	var rv: Dictionary = s.get("rival", {})
	return {"v": 1, "bots": bots, "clock": float(s.get("clock", 0.0)), "next_rid": int(s.get("next_rid", 1)),
		"next_help": float(s.get("next_help", 0.0)), "next_rival": float(s.get("next_rival", 0.0)),
		"rival": {"rid": int(rv.get("rid", -1)), "wins": int(rv.get("wins", 0)), "losses": int(rv.get("losses", 0)),
			"bosses": (rv.get("bosses", []) as Array).duplicate(), "dev": int(rv.get("dev", 1))},
		"titles": (s.get("titles", []) as Array).duplicate()}

static func _load(sim: WorldSim, pending: Dictionary) -> void:
	var d: Dictionary = pending["roster"]
	var s := sim.social
	sim.roster.clear()
	for o in d.get("bots", []):
		if not (o is Dictionary) or not GameData.classes.has(str(o.get("class", ""))):
			continue                                 # classe que saiu do jogo: o bot sai do elenco
		var r := {"rid": int(o.get("rid", 0)), "name": str(o.get("name", "")), "class": str(o["class"]), "build": str(o.get("build", "")),
			"personality": str(o.get("personality", "calmo")), "level": clampi(int(o.get("level", 1)), 1, Balance.MAX_LEVEL),
			"look": o.get("look", {}) if o.get("look") is Dictionary else {}, "affinity": 0, "memories": [],
			"rival": bool(o.get("rival", false)), "guild": str(o.get("guild", ""))}
		if not r["personality"] in BotsCatalog.PERSONALITIES:
			r["personality"] = "calmo"
		for mem in o.get("memories", []):
			if mem is Dictionary and str(mem.get("kind", "")) in MEMORY_KINDS:
				r["memories"].append({"kind": str(mem["kind"]), "at": float(mem.get("at", 0.0)), "map": str(mem.get("map", ""))})
		_runtime(r)
		r["affinity"] = affinity_of(r)
		sim.roster.append(r)
	s["clock"] = float(d.get("clock", 0.0))
	s["next_update"] = s["clock"]
	s["next_rid"] = maxi(int(d.get("next_rid", 1)), _max_rid(sim) + 1)
	s["next_help"] = float(d.get("next_help", s["clock"] + Balance.BOT_HELP_EVERY * 60.0 * 0.5))
	s["next_rival"] = float(d.get("next_rival", s["clock"] + Balance.RIVAL_STEP_MIN * 60.0))
	var rv: Dictionary = d.get("rival", {}) if d.get("rival") is Dictionary else {}
	s["rival"] = {"rid": int(rv.get("rid", -1)), "wins": int(rv.get("wins", 0)), "losses": int(rv.get("losses", 0)),
		"bosses": (rv.get("bosses", []) as Array).duplicate(), "race": {}, "dev": int(rv.get("dev", 1))}
	s["titles"] = (d.get("titles", []) as Array).duplicate()
	GuildSystem.from_save(sim, pending.get("guild", {}) if pending.get("guild") is Dictionary else {})
	_fix_rival(sim)

static func _runtime(r: Dictionary) -> void:
	r["entity_id"] = -1
	r["line_at"] = -1.0e9
	r["saved_at"] = -1.0e9
	r["group_at"] = -1.0e9
	r["loot_at"] = -1.0e9
	r["greet_at"] = -1.0e9

static func _max_rid(sim: WorldSim) -> int:
	var hi := 0
	for r: Dictionary in sim.roster:
		hi = maxi(hi, int(r["rid"]))
	return hi

## O rival existe, é um só e é da classe da tabela (o jogador pode ter trocado de personagem num save editado).
static func _fix_rival(sim: WorldSim) -> void:
	var want: String = Balance.RIVAL_CLASS.get(sim.player.class_def.id, "")
	var rv: Dictionary = sim.social["rival"]
	var cur: Dictionary = entry(sim, int(rv.get("rid", -1)))
	for r: Dictionary in sim.roster:
		r["rival"] = false
	if cur.is_empty() or cur["class"] != want:
		cur = {}
		for r: Dictionary in sim.roster:
			if r["class"] == want and r["guild"] == "":
				cur = r
				break
	if cur.is_empty() and want != "":
		cur = _new_entry(sim, want, _free_name(sim), mini(sim.player.level + 1, Balance.MAX_LEVEL))
		sim.roster.append(cur)
	if not cur.is_empty():
		cur["rival"] = true
		rv["rid"] = cur["rid"]

## Sorteia o elenco a partir dos bots que já estão no mundo (nomes mantidos; os de nível mais perto do jogador primeiro).
## Faltando bots (mundo vazio, testes), nascem bots novos com nomes livres. O rival é da classe de RIVAL_CLASS.
static func draft(sim: WorldSim) -> void:
	var pl := sim.player
	sim.roster.clear()
	var cands: Array = []
	for e: SimEntity in sim.entities.values():
		if e.kind == SimEntity.Kind.BOT and e.owner_id < 0 and e.roster_id < 0 and e.class_def != null and e.name != pl.name:
			cands.append(e)
	cands.sort_custom(func(a: SimEntity, b: SimEntity): return absi(a.level - pl.level) < absi(b.level - pl.level) \
		or (absi(a.level - pl.level) == absi(b.level - pl.level) and a.id < b.id))
	var names := {}
	var want: String = Balance.RIVAL_CLASS.get(pl.class_def.id, "")
	var rival: Dictionary = {}
	for e: SimEntity in cands:
		if e.class_def.id == want:
			rival = _adopt_entry(sim, e)
			names[e.name] = true
			break
	if rival.is_empty() and want != "":
		rival = _new_entry(sim, want, _free_name(sim, names), pl.level + 1)
		names[rival["name"]] = true
	rival["level"] = mini(pl.level + 1, Balance.MAX_LEVEL)
	rival["rival"] = true
	sim.roster.append(rival)
	sim.social["rival"]["rid"] = rival["rid"]
	for e: SimEntity in cands:
		if sim.roster.size() >= Balance.ROSTER_SIZE:
			break
		if names.has(e.name) or e.id == int(rival.get("entity_id", -1)):
			continue
		names[e.name] = true
		sim.roster.append(_adopt_entry(sim, e))
	while sim.roster.size() < Balance.ROSTER_SIZE:
		var classes: Array = GameData.class_list()
		var cls: ClassDef = classes[sim.rng.randi() % classes.size()]
		var lv := clampi(pl.level + sim.rng.randi_range(-Balance.ROSTER_LEVEL_SPREAD, Balance.ROSTER_LEVEL_SPREAD), 1, Balance.MAX_LEVEL)
		var r := _new_entry(sim, cls.id, _free_name(sim, names), lv)
		names[r["name"]] = true
		sim.roster.append(r)

static func _base_entry(sim: WorldSim, cls_id: String, nm: String, level: int) -> Dictionary:
	var rid: int = sim.social["next_rid"]
	sim.social["next_rid"] = rid + 1
	var pers: Array = BotsCatalog.PERSONALITIES
	var r := {"rid": rid, "name": nm, "class": cls_id, "build": "", "personality": pers[sim.rng.randi() % pers.size()],
		"level": clampi(level, 1, Balance.MAX_LEVEL), "look": {}, "affinity": 0, "memories": [], "rival": false, "guild": ""}
	_runtime(r)
	return r

## Bot do mundo vira do elenco (fica com o corpo, o nome e a build dele; nível puxado para a faixa do jogador).
static func _adopt_entry(sim: WorldSim, e: SimEntity) -> Dictionary:
	var lv := clampi(e.level, sim.player.level - Balance.ROSTER_LEVEL_SPREAD, sim.player.level + Balance.ROSTER_LEVEL_SPREAD)
	var r := _base_entry(sim, e.class_def.id, e.name, maxi(1, lv))
	r["build"] = e.build_id
	r["look"] = e.look.duplicate()
	r["entity_id"] = e.id
	e.roster_id = r["rid"]
	return r

static func _new_entry(sim: WorldSim, cls_id: String, nm: String, level: int) -> Dictionary:
	var r := _base_entry(sim, cls_id, nm, level)
	var cls: ClassDef = GameData.classes[cls_id]
	if cls.builds.size() > 0:
		r["build"] = cls.builds[sim.rng.randi() % cls.builds.size()]["id"]
	return r

## Nome livre da lista dos bots (fora do elenco e do jogador); acabando, nome com número.
static func _free_name(sim: WorldSim, taken: Dictionary = {}) -> String:
	var used := taken.duplicate()
	for r: Dictionary in sim.roster:
		used[r["name"]] = true
	if sim.player:
		used[sim.player.name] = true
	var pool: Array = BotsCatalog.NAMES
	var start := sim.rng.randi() % pool.size()
	for i in pool.size():
		var nm: String = pool[(start + i) % pool.size()]
		if not used.has(nm):
			return nm
	var k := 2
	while used.has("%s%d" % [pool[start], k]):
		k += 1
	return "%s%d" % [pool[start], k]

## Cada entrada do elenco ganha (ou reencontra) o seu bot no mundo: bot vivo com o mesmo nome e classe, senão nasce
## um no povoado da faixa dele. Bot descartável com o nome de alguém do elenco troca de nome (nomes do elenco são únicos).
static func bind(sim: WorldSim) -> void:
	var by_name := {}
	for r: Dictionary in sim.roster:
		if not GuildBankSystem.is_away(sim, int(r["rid"])):      # fora numa encomenda do banco: fica sem corpo
			by_name[r["name"]] = r
	for e: SimEntity in sim.entities.values():
		if e.kind != SimEntity.Kind.BOT or e.owner_id >= 0:
			continue
		var r: Dictionary = by_name.get(e.name, {})
		if r.is_empty():
			continue
		var cur: SimEntity = sim.entities.get(int(r["entity_id"]))
		if cur == null and (e.roster_id == r["rid"] or (e.roster_id < 0 and e.class_def and e.class_def.id == r["class"])):
			r["entity_id"] = e.id
			e.roster_id = r["rid"]
		elif e.id != int(r["entity_id"]):
			if e.roster_id == r["rid"]:
				e.roster_id = -1
			e.name = _free_name(sim)               # homônimo descartável
	for r: Dictionary in sim.roster:
		if GuildBankSystem.is_away(sim, int(r["rid"])):
			continue
		var e: SimEntity = sim.entities.get(int(r["entity_id"]))
		if e == null or e.roster_id != r["rid"]:
			e = _spawn(sim, r)
		_match(sim, r, e)

static func _spawn(sim: WorldSim, r: Dictionary) -> SimEntity:
	var mid := BotBandSystem.home_map(int(r["level"]), sim)
	var def: MapDef = GameData.maps[mid]
	if not sim.maps.has(mid):
		sim.load_map(def)
	var pos := sim.random_walkable(def, def.spawn_point, 10.0)
	if def.is_town:
		pos = sim.random_walkable(def, BotBandSystem.spawn_spot(def, int(r["rid"])), 2.0)
	var e := sim.spawn_bot(GameData.classes[r["class"]], r["name"], mid, pos, int(r["level"]))
	r["entity_id"] = e.id
	e.roster_id = r["rid"]
	return e

## O corpo bate com a entrada: build, nível e visual (refaz equipamento/teia só se mudou).
static func _match(sim: WorldSim, r: Dictionary, e: SimEntity) -> void:
	if r["build"] == "" or e.class_def.build_by_id(r["build"]).is_empty():
		r["build"] = e.build_id
	if not (r["look"] as Dictionary).is_empty():
		e.look = (r["look"] as Dictionary).duplicate()
	else:
		r["look"] = e.look.duplicate()
	if e.build_id != r["build"] or e.level != int(r["level"]):
		set_level(sim, e, int(r["level"]), r["build"])

## Põe o bot no nível `level` (e na build) como um bot que nasceu ali: equipamento, teia, ascensão, barra, vida cheia.
static func set_level(sim: WorldSim, e: SimEntity, level: int, build: String = "") -> void:
	e.level = clampi(level, 1, Balance.MAX_LEVEL)
	e.xp = 0
	if build != "":
		e.build_id = build
	sim._gear_bot(e)
	ProgressionSystem.bot_spend(sim, e, true)
	ProgressionSystem.bot_spend_asc(sim, e)
	sim._slot_bot(e)
	e.recompute_stats()
	if e.is_alive():
		e.heal_full()

# ---------------------------------------------------------------------------
# LEITURA

static func entry(sim: WorldSim, rid: int) -> Dictionary:
	for r: Dictionary in sim.roster:
		if int(r["rid"]) == rid:
			return r
	return {}

static func entry_of(sim: WorldSim, e: SimEntity) -> Dictionary:
	return entry(sim, e.roster_id) if e != null and e.roster_id >= 0 else {}

static func entity_of(sim: WorldSim, r: Dictionary) -> SimEntity:
	var e: SimEntity = sim.entities.get(int(r.get("entity_id", -1)))
	return e if e != null and e.roster_id == int(r["rid"]) else null

static func rival_entry(sim: WorldSim) -> Dictionary:
	return entry(sim, int(sim.social.get("rival", {}).get("rid", -1))) if sim.roster_on else {}

## Cópia de uma entrada no formato do contrato (com `map` e sem os relógios internos).
static func public_entry(sim: WorldSim, r: Dictionary) -> Dictionary:
	var o := {}
	for k in SAVE_KEYS:
		o[k] = r[k]
	o.erase("look")
	o["memories"] = (r["memories"] as Array).duplicate(true)
	var e := entity_of(sim, r)
	o["entity_id"] = e.id if e else -1
	o["map"] = e.map_id if e else ""
	if e:
		o["level"] = e.level
	return o

static func list(sim: WorldSim) -> Array:
	var out: Array = []
	for r: Dictionary in sim.roster:
		out.append(public_entry(sim, r))
	out.sort_custom(func(a, b): return int(a["affinity"]) > int(b["affinity"]) or (int(a["affinity"]) == int(b["affinity"]) and int(a["rid"]) < int(b["rid"])))
	return out

static func affinity_of(r: Dictionary) -> int:
	var sum := 0
	for mem in r["memories"]:
		sum += int(Balance.BOT_MEMORY_WEIGHT.get(str(mem["kind"]), 0))
	return clampi(sum, -Balance.AFFINITY_MAX, Balance.AFFINITY_MAX)

static func affinity_label(v: int) -> String:
	for t in Balance.AFFINITY_TIERS:
		if v < int(t[0]):
			return str(t[1])
	return str(Balance.AFFINITY_TIERS.back()[1])

static func rival_info(sim: WorldSim) -> Dictionary:
	var r := rival_entry(sim)
	if r.is_empty():
		return {}
	var rv: Dictionary = sim.social["rival"]
	var e := entity_of(sim, r)
	var race: Dictionary = (rv.get("race", {}) as Dictionary).duplicate()
	race.erase("rival_at")
	return {"rid": r["rid"], "name": r["name"], "class": r["class"], "level": e.level if e else int(r["level"]),
		"wins": int(rv.get("wins", 0)), "losses": int(rv.get("losses", 0)), "race": race}

# ---------------------------------------------------------------------------
# PASSADA (a cada ROSTER_UPDATE_S de relógio social)

static func tick(sim: WorldSim, dt: float) -> void:
	if sim.player == null:
		return
	var s := sim.social
	s["clock"] = float(s["clock"]) + dt
	if float(s["clock"]) < float(s["next_update"]):
		return
	var step: float = Balance.ROSTER_UPDATE_S + float(s["clock"]) - float(s["next_update"])
	s["next_update"] = float(s["clock"]) + Balance.ROSTER_UPDATE_S
	update(sim, step)

## Uma passada: corpo no mundo, rival, pedido de socorro, cumprimentos, guilda.
static func update(sim: WorldSim, step: float) -> void:
	_sync(sim)
	_rival_update(sim, step)
	_help_update(sim)
	_greet(sim)
	GuildSystem.update(sim, step)
	GuildBankSystem.update(sim, step)      # banco da guilda: retiradas, pulso, encomendas, pedidos

## Nível/build vêm do bot no mundo; bot que sumiu (despawn) nasce de novo.
static func _sync(sim: WorldSim) -> void:
	var lost := false
	for r: Dictionary in sim.roster:
		var e := entity_of(sim, r)
		if e == null:
			lost = lost or not GuildBankSystem.is_away(sim, int(r["rid"]))
			continue
		if e.gvg_side != "":
			continue                     # na Guerra de Guildas o nível é o igualado: a entrada guarda o de verdade
		r["level"] = e.level
		r["build"] = e.build_id
	if lost:
		bind(sim)
		Events.post(&"roster_changed")

# ---------------------------------------------------------------------------
# FALA (ritmo do elenco)

## O bot pode falar agora? Bot do elenco: no máximo 1 fala a cada BOT_CAST_LINE_GAP s, e o elenco todo uma a cada
## ROSTER_CHAT_GAP s. `important` (pedido de socorro, convite, lembrança) passa pelo do elenco todo. Bot comum: sempre.
## Dizer "sim" marca a fala.
static func can_speak(sim: WorldSim, e: SimEntity, important: bool = false) -> bool:
	if e == null or e.roster_id < 0 or not sim.roster_on:
		return true
	var r := entry(sim, e.roster_id)
	if r.is_empty():
		return true
	var clock: float = sim.social["clock"]
	if clock < float(r["line_at"]) + Balance.BOT_CAST_LINE_GAP:
		return false
	if not important and clock < float(sim.social["line_at"]) + Balance.ROSTER_CHAT_GAP:
		return false
	r["line_at"] = clock
	sim.social["line_at"] = clock
	return true

## Fala do evento `key` na voz da personalidade (lista própria ou a "*").
static func line(sim: WorldSim, r: Dictionary, key: String, extra: Dictionary = {}) -> String:
	var pools: Dictionary = BotsCatalog.ROSTER_LINES.get(key, {})
	var own: Array = pools.get(r["personality"], [])
	var gen: Array = pools.get("*", [])
	var lines := own if not own.is_empty() and (gen.is_empty() or sim.rng.randf() < 0.6) else gen
	if lines.is_empty():
		return ""
	var e := entity_of(sim, r)
	var v := {"p": sim.player.name if sim.player else "", "me": r["name"], "lv": str(r["level"]), "map": "aqui", "boss": "o chefe", "item": "", "guild": ""}
	if e:
		var md: MapDef = GameData.maps.get(e.map_id)
		v["map"] = md.name if md else "aqui"
	v.merge(extra, true)
	return str(lines[sim.rng.randi() % lines.size()]).format(v)

## Diz a fala `key` no `channel` se o ritmo deixa. Devolve se falou.
static func say(sim: WorldSim, r: Dictionary, key: String, channel: String, extra: Dictionary = {}, important: bool = false) -> bool:
	var e := entity_of(sim, r)
	if e == null or not can_speak(sim, e, important):
		return false
	var text := line(sim, r, key, extra)
	if text == "":
		return false
	Events.post(&"chat_message", r["name"], text, channel)
	return true

## Conversa solta do bot do elenco (BotChat.ambient): ritmo do elenco; às vezes a fala da personalidade.
static func ambient(sim: WorldSim, e: SimEntity) -> void:
	var r := entry_of(sim, e)
	if r.is_empty() or sim.rng.randf() > float(Balance.ROSTER_TALK.get(r["personality"], 0.7)):
		return
	if not can_speak(sim, e):
		return
	var text := line(sim, r, "ambient") if sim.rng.randf() < Balance.ROSTER_AMBIENT_OWN else BotChat.ambient_line(sim, e)
	if text != "":
		Events.post(&"chat_message", e.name, text, "global")

## Canal da fala pessoal: grupo se está com o jogador, senão sussurro.
static func _personal_channel(sim: WorldSim, e: SimEntity) -> String:
	return "party" if e != null and BotChat.in_player_party(sim, e) else "whisper"

# ---------------------------------------------------------------------------
# LEMBRANÇAS E AFINIDADE

## Nova lembrança (a mais velha sai além de ROSTER_MEMORY_MAX); afinidade refeita; o bot comenta.
static func remember(sim: WorldSim, r: Dictionary, kind: String, extra: Dictionary = {}) -> void:
	var e := entity_of(sim, r)
	var mems: Array = r["memories"]
	mems.append({"kind": kind, "at": float(sim.social.get("clock", 0.0)), "map": e.map_id if e else ""})
	while mems.size() > Balance.ROSTER_MEMORY_MAX:
		mems.pop_front()
	r["affinity"] = affinity_of(r)
	Events.post(&"roster_memory", int(r["rid"]), kind)
	Events.post(&"roster_changed")
	say(sim, r, "mem_" + kind, _personal_channel(sim, e), extra, true)
	GuildSystem.on_affinity(sim, r)

## Cura (WorldSim._heal): o jogador curou um bot do elenco que estava abaixo de ROSTER_SAVE_HP.
static func on_heal(sim: WorldSim, src: SimEntity, target: SimEntity, before: float) -> void:
	if src != sim.player or target.hp <= before or before >= target.stats.max_hp * Balance.ROSTER_SAVE_HP:
		return
	_saved(sim, target)

static func _saved(sim: WorldSim, target: SimEntity) -> void:
	var r := entry_of(sim, target)
	if r.is_empty() or float(sim.social["clock"]) < float(r["saved_at"]) + Balance.ROSTER_SAVE_CD:
		return
	r["saved_at"] = sim.social["clock"]
	remember(sim, r, "salvou")

## Monstro morreu (WorldSim._kill, antes do saque): salvou (o jogador matou quem batia no bot do elenco caído),
## e, no chefe: grupo, corrida do rival, notícia do rival e a comemoração.
static func on_kill(sim: WorldSim, mob: SimEntity, killer: SimEntity) -> void:
	var pl := sim.player
	if pl == null or mob.monster_def == null:
		return
	var by_player := killer != null and (killer == pl or killer.owner_id == pl.id)
	if by_player and mob.aggro_target >= 0:
		var victim: SimEntity = sim.entities.get(mob.aggro_target)
		if victim and victim.roster_id >= 0 and victim.is_alive() and victim.hp < victim.stats.max_hp * Balance.ROSTER_SAVE_HP:
			_saved(sim, victim)
	var md := mob.monster_def
	if not md.is_boss or mob.boss_id >= 0 or md.dummy or md.decoy or md.elite_of != "":
		return
	var with_player := by_player or (killer != null and killer.party_id >= 0 and killer.party_id == pl.party_id and killer.map_id == pl.map_id)
	if with_player:
		for id in PartySystem.party_members(sim, pl).map(func(o: SimEntity): return o.id):
			var o: SimEntity = sim.entities.get(id)
			if o and o.roster_id >= 0 and o.map_id == mob.map_id:
				var r := entry_of(sim, o)
				if not r.is_empty() and float(sim.social["clock"]) >= float(r["group_at"]) + Balance.ROSTER_GROUP_CD:
					r["group_at"] = sim.social["clock"]
					remember(sim, r, "grupo", {"boss": md.name})
		_race_won(sim, md)
		GuildBankSystem.on_boss_kill(sim, md)      # pedidos de abate do quadro da guilda
		celebrate(sim, "boss", {"boss": md.name})
	else:
		var rr := rival_entry(sim)
		var rival := entity_of(sim, rr) if not rr.is_empty() else null
		if rival and killer and (killer == rival or (rival.party_id >= 0 and killer.party_id == rival.party_id)) and not pl.bosses_killed.has(md.id):
			_rival_boss_news(sim, rr, md)

## Jogador saiu do grupo (PartySystem.party_leave) dentro de masmorra: quem do elenco ficou lembra.
static func on_player_left_party(sim: WorldSim, member_ids: Array) -> void:
	var pl := sim.player
	var def: MapDef = sim.map_def(pl.map_id)
	if def == null or def.parent_map == "" or not pl.is_alive():
		return
	for id in member_ids:
		var o: SimEntity = sim.entities.get(id)
		if o and o != pl and o.roster_id >= 0 and o.map_id == pl.map_id:
			var r := entry_of(sim, o)
			if not r.is_empty():
				remember(sim, r, "abandonou")

## Jogador pegou um lendário (LootSystem.pickup): quem do elenco no grupo o usaria lembra; o elenco comemora.
static func on_player_legendary(sim: WorldSim, it: ItemDef) -> void:
	var pl := sim.player
	if pl.party_id >= 0:
		for o: SimEntity in PartySystem.party_members(sim, pl):
			if o.roster_id < 0 or o.class_def == null or not LootSystem.fits_class(sim, o, it):
				continue
			var r := entry_of(sim, o)
			if not r.is_empty() and float(sim.social["clock"]) >= float(r["loot_at"]) + Balance.ROSTER_LOOT_CD:
				r["loot_at"] = sim.social["clock"]
				remember(sim, r, "perdeu_saque", {"item": it.name})
	celebrate(sim, "legend", {"item": it.name})

## Convite do jogador a um bot do elenco: sempre aceita (§9.4); afinidade negativa = fala seca.
static func accepts_player(sim: WorldSim, e: SimEntity) -> bool:
	var r := entry_of(sim, e)
	if not r.is_empty() and int(r["affinity"]) < 0:
		say(sim, r, "party_dry", "whisper", {}, true)
	return true

# ---------------------------------------------------------------------------
# COMEMORAR (§3.6)

## Conquista do jogador (`kind`: level | legend | card | boss): até BOT_CELEBRATE_MAX do elenco reagem (guilda, grupo,
## perto) dentro do ritmo de fala, e às vezes um bot de fora perto.
static func celebrate(sim: WorldSim, kind: String, extra: Dictionary = {}) -> void:
	var pl := sim.player
	if pl == null or not sim.roster_on:
		return
	var gid: String = sim.social.get("player_guild", "")
	var picks: Array = []
	for r: Dictionary in sim.roster:
		var e := entity_of(sim, r)
		if e == null or not e.is_alive() or int(r["affinity"]) < 0:
			continue
		var near := e.map_id == pl.map_id and e.position.distance_to(pl.position) < Balance.BOT_CELEBRATE_RANGE
		var mate: bool = gid != "" and r["guild"] == gid
		var party := BotChat.in_player_party(sim, e)
		if near or mate or party:
			picks.append([r, "party" if party else ("guild" if mate else "global")])
	var said := 0
	var start := sim.rng.randi() % maxi(1, picks.size())
	for i in picks.size():
		if said >= Balance.BOT_CELEBRATE_MAX:
			break
		var pk: Array = picks[(start + i) % picks.size()]
		var r: Dictionary = pk[0]
		if sim.rng.randf() > float(Balance.ROSTER_TALK.get(r["personality"], 0.7)):
			continue
		if say(sim, r, "celebrate_" + kind, pk[1], extra):
			said += 1
	if sim.rng.randf() < Balance.BOT_CELEBRATE_STRANGER:
		for o: SimEntity in sim.map_entities(pl.map_id):
			if o.kind == SimEntity.Kind.BOT and o.roster_id < 0 and o.owner_id < 0 and o.is_alive() \
					and o.position.distance_to(pl.position) < Balance.BOT_CELEBRATE_RANGE:
				var pools: Array = BotsCatalog.ROSTER_LINES["stranger_cheer"]["*"]
				Events.post(&"chat_message", o.name, str(pools[sim.rng.randi() % pools.size()]), "global")
				break

## Bot do elenco perto do jogador cumprimenta pelo nome (tom pela afinidade), uma vez a cada ROSTER_GREET_CD.
static func _greet(sim: WorldSim) -> void:
	var pl := sim.player
	if not pl.is_alive():
		return
	for r: Dictionary in sim.roster:
		var e := entity_of(sim, r)
		if e == null or e.map_id != pl.map_id or not e.is_alive() or e.combat_timer > 0.0 \
				or e.position.distance_to(pl.position) > Balance.ROSTER_GREET_RANGE:
			continue
		if float(sim.social["clock"]) < float(r["greet_at"]) + Balance.ROSTER_GREET_CD:
			continue
		r["greet_at"] = sim.social["clock"]
		var aff := int(r["affinity"])
		var key := "greet_dry" if aff < 0 else ("greet_hi" if aff >= 30 else "greet")
		say(sim, r, key, _personal_channel(sim, e))

# ---------------------------------------------------------------------------
# RIVAL (§3.3, §9.2, §9.5)

## Nível do rival: desvio sorteado a cada RIVAL_STEP_MIN min; fora de ±1 do jogador volta na hora.
static func _rival_update(sim: WorldSim, step: float) -> void:
	var r := rival_entry(sim)
	var e := entity_of(sim, r) if not r.is_empty() else null
	if e == null:
		return
	var rv: Dictionary = sim.social["rival"]
	var pl_lv := sim.player.level
	var clock: float = sim.social["clock"]
	var stepped := false
	if clock >= float(sim.social["next_rival"]):
		sim.social["next_rival"] = clock + Balance.RIVAL_STEP_MIN * 60.0
		var w: Array = Balance.RIVAL_DEV_WEIGHTS
		var roll := sim.rng.randi_range(1, int(w[0]) + int(w[1]) + int(w[2]))
		rv["dev"] = -1 if roll <= int(w[0]) else (0 if roll <= int(w[0]) + int(w[1]) else 1)
		stepped = true
	var lo := maxi(1, pl_lv - 1)
	var hi := mini(Balance.MAX_LEVEL, pl_lv + 1)
	# no passo do desvio vai ao alvo; entre passos só volta para dentro da faixa
	var want := e.level
	if stepped:
		want = clampi(pl_lv + int(rv.get("dev", 1)), lo, hi)
	elif e.level < lo or e.level > hi:
		want = clampi(e.level, lo, hi)
	if want != e.level and e.state != SimEntity.State.DEAD:
		var up := want > e.level
		set_level(sim, e, want)
		r["level"] = want
		Events.post(&"roster_changed")
		if up:
			_rival_level_news(sim, r)
	_race_update(sim, r, e, step)

static func _rival_level_news(sim: WorldSim, r: Dictionary) -> void:
	var text := line(sim, r, "rival_level", {"lv": str(r["level"])})
	Events.post(&"rival_news", int(r["rid"]), "level", text)
	var e := entity_of(sim, r)
	if text != "" and can_speak(sim, e, true):
		Events.post(&"chat_message", r["name"], text, _personal_channel(sim, e) if BotChat.in_player_party(sim, e) else "global")
	if sim.rng.randf() < Balance.RIVAL_BOSS_NEWS_CHANCE:
		var md := _news_boss(sim, int(r["level"]))
		if md:
			_rival_boss_news(sim, r, md)

## Chefe da faixa do rival que o jogador ainda não matou e o rival ainda não contou (ou null).
static func _news_boss(sim: WorldSim, level: int) -> MonsterDef:
	var told: Array = sim.social["rival"]["bosses"]
	var opts: Array = []
	for mid in GameData.monsters:
		var md: MonsterDef = GameData.monsters[mid]
		if md.is_boss and not md.dummy and not md.decoy and md.elite_of == "" and md.level <= level and md.level >= level - Balance.RIVAL_BOSS_BAND \
				and not sim.player.bosses_killed.has(md.id) and not told.has(md.id):
			opts.append(md)
	if opts.is_empty():
		return null
	opts.sort_custom(func(a: MonsterDef, b: MonsterDef): return a.id < b.id)
	return opts[sim.rng.randi() % opts.size()]

static func _rival_boss_news(sim: WorldSim, r: Dictionary, md: MonsterDef) -> void:
	var told: Array = sim.social["rival"]["bosses"]
	if told.has(md.id):
		return
	told.append(md.id)
	var text := line(sim, r, "rival_boss", {"boss": md.name})
	Events.post(&"rival_news", int(r["rid"]), "boss", text)
	if text != "":
		Events.post(&"chat_message", r["name"], text, "global")

## Desafio: correr o chefe `boss_id` contra o rival (quem mata primeiro). "" = começou.
static func race_error(sim: WorldSim, boss_id: String) -> String:
	var r := rival_entry(sim)
	if r.is_empty():
		return "Você ainda não tem um rival."
	var md: MonsterDef = GameData.monsters.get(boss_id)
	if md == null or not md.is_boss or md.dummy or md.decoy or md.elite_of != "":
		return "Isso não é um chefe."
	if not (sim.social["rival"]["race"] as Dictionary).is_empty():
		return "Já há uma corrida em andamento."
	var e := entity_of(sim, r)
	if e and BotChat.in_player_party(sim, e):
		return "%s está no seu grupo: a corrida fica para depois." % r["name"]
	return ""

static func race_start(sim: WorldSim, boss_id: String) -> String:
	var err := race_error(sim, boss_id)
	if err != "":
		return err
	var r := rival_entry(sim)
	var md: MonsterDef = GameData.monsters[boss_id]
	var clock: float = sim.social["clock"]
	var rival_at := clock + sim.rng.randf_range(Balance.RIVAL_RACE_RIVAL.x, Balance.RIVAL_RACE_RIVAL.y)
	if sim.rng.randf() < Balance.RIVAL_RACE_FAIL:
		rival_at = 1.0e12                            # o rival não consegue no prazo
	sim.social["rival"]["race"] = {"boss": boss_id, "boss_name": md.name, "until": clock + Balance.RIVAL_RACE_TIME, "suspended": false, "rival_at": rival_at}
	var text := line(sim, r, "rival_race_start", {"boss": md.name})
	Events.post(&"rival_news", int(r["rid"]), "race_start", text)
	if text != "":
		Events.post(&"chat_message", r["name"], text, "whisper")
	return ""

static func race_cancel(sim: WorldSim) -> void:
	if sim.roster_on:
		sim.social["rival"]["race"] = {}
		Events.post(&"roster_changed")

## Corrida: suspensa com o rival no seu grupo (o prazo anda junto); o rival termina no tempo sorteado.
static func _race_update(sim: WorldSim, r: Dictionary, e: SimEntity, step: float) -> void:
	var race: Dictionary = sim.social["rival"]["race"]
	if race.is_empty():
		return
	race["suspended"] = BotChat.in_player_party(sim, e)
	if race["suspended"]:
		race["until"] = float(race["until"]) + step
		race["rival_at"] = float(race["rival_at"]) + step
		return
	var clock: float = sim.social["clock"]
	if clock >= float(race["rival_at"]):
		_race_end(sim, r, "race_lost")
	elif clock >= float(race["until"]):
		_race_end(sim, r, "race_expired")

## O jogador matou o chefe da corrida: título + lembrança "corrida" (afinidade).
static func _race_won(sim: WorldSim, md: MonsterDef) -> void:
	var race: Dictionary = sim.social.get("rival", {}).get("race", {})
	if race.is_empty() or race["boss"] != md.id or race.get("suspended", false):
		return
	var r := rival_entry(sim)
	var title: String = Balance.RIVAL_TITLE % r["name"]
	var titles: Array = sim.social["titles"]
	if not titles.has(title):
		titles.append(title)
		Events.post(&"notification", "Título novo: %s" % title)
	_race_end(sim, r, "race_won")
	remember(sim, r, "corrida")

static func _race_end(sim: WorldSim, r: Dictionary, kind: String) -> void:
	var rv: Dictionary = sim.social["rival"]
	var race: Dictionary = rv["race"]
	if kind == "race_won":
		rv["wins"] = int(rv["wins"]) + 1
	elif kind == "race_lost":
		rv["losses"] = int(rv["losses"]) + 1
	var text := line(sim, r, "rival_" + kind, {"boss": race.get("boss_name", "o chefe")})
	rv["race"] = {}
	Events.post(&"rival_news", int(r["rid"]), kind, text)
	if text != "":
		Events.post(&"chat_message", r["name"], text, "whisper")
	Events.post(&"roster_changed")

# ---------------------------------------------------------------------------
# PEDIDO DE SOCORRO (§3.5)

## Pedidos abertos (um por vez hoje), no formato do contrato.
static func help_requests(sim: WorldSim) -> Array:
	var h: Dictionary = sim.social.get("help", {}) if sim.roster_on else {}
	if h.is_empty() or h["state"] != "open":
		return []
	var o := h.duplicate()
	o["left"] = maxf(0.0, float(h["expires"]) - float(sim.social["clock"]))
	return [o]

static func _help_update(sim: WorldSim) -> void:
	var s := sim.social
	var h: Dictionary = s["help"]
	var clock: float = s["clock"]
	if not h.is_empty():
		var r := entry(sim, int(h["rid"]))
		var e := entity_of(sim, r) if not r.is_empty() else null
		var pl := sim.player
		if e != null and e.is_alive():
			h["pos"] = e.position
			h["map"] = e.map_id
		if e != null and pl.is_alive() and pl.map_id == e.map_id and pl.position.distance_to(e.position) <= Balance.BOT_HELP_ARRIVE_RANGE:
			_help_arrived(sim, r, h)
		elif e == null or clock >= float(h["expires"]):
			h["state"] = "expired"
			s["help"] = {}
			Events.post(&"bot_help_ended", int(h["id"]), "expired")
		return
	if clock < float(s["next_help"]):
		return
	s["next_help"] = clock + Balance.BOT_HELP_EVERY * 60.0 * sim.rng.randf_range(0.5, 1.5)
	open_help(sim)

## Abre um pedido: um bot do elenco num mapa a até 1 portal do jogador, fora do grupo dele (em apuros de verdade
## primeiro: vida baixa, cercado, chefe). `rid` força o bot (testes). Devolve o pedido ({} se ninguém pode).
static func open_help(sim: WorldSim, rid: int = -1) -> Dictionary:
	var pl := sim.player
	var best: Dictionary = {}
	var best_score := -1
	for r: Dictionary in sim.roster:
		if rid >= 0 and int(r["rid"]) != rid:
			continue
		var e := entity_of(sim, r)
		if e == null or not e.is_alive() or BotChat.in_player_party(sim, e) or not _near_map(sim, pl.map_id, e.map_id):
			continue
		var def: MapDef = sim.map_def(e.map_id)
		if def.interior:
			continue
		var reason := ""
		var score := 0
		var boss := BotChat.near_boss(sim, e)
		if e.hp < e.stats.max_hp * Balance.BOT_HELP_LOW_HP:
			reason = "low_hp"; score = 3
		elif boss:
			reason = "boss"; score = 2
		elif _attackers(sim, e) >= 2:
			reason = "surrounded"; score = 2
		else:
			reason = "surrounded"; score = 1 if not def.in_town(e.position) else 0
		score = score * 10 + sim.rng.randi_range(0, 9)
		if score > best_score:
			best_score = score
			best = {"r": r, "e": e, "reason": reason, "boss": boss}
	if best.is_empty():
		return {}
	var s := sim.social
	s["help_seq"] = int(s["help_seq"]) + 1
	var e: SimEntity = best["e"]
	var r: Dictionary = best["r"]
	var h := {"id": s["help_seq"], "rid": r["rid"], "name": r["name"], "map": e.map_id, "pos": e.position, "reason": best["reason"],
		"expires": float(s["clock"]) + Balance.BOT_HELP_WINDOW, "state": "open"}
	s["help"] = h
	var extra := {"boss": (best["boss"] as SimEntity).monster_def.name} if best["boss"] != null else {}
	var text := line(sim, r, "help_" + str(best["reason"]), extra)
	can_speak(sim, e, true)                     # conta no ritmo do bot
	if text != "":
		var gid: String = s.get("player_guild", "")
		Events.post(&"chat_message", r["name"], text, "guild" if gid != "" and r["guild"] == gid else "global")
	var pub := h.duplicate()
	pub["left"] = Balance.BOT_HELP_WINDOW
	Events.post(&"bot_help_request", pub)
	return h

static func _help_arrived(sim: WorldSim, r: Dictionary, h: Dictionary) -> void:
	var pl := sim.player
	h["state"] = "helped"
	sim.social["help"] = {}
	var gold := Balance.BOT_HELP_GOLD_PER_LV * pl.level
	pl.gold += gold
	var potion: ItemDef = GameData.items.get(Balance.BOT_HELP_POTION)
	if potion:
		pl.add_item(potion.id, Balance.BOT_HELP_POTIONS)
		Events.post(&"item_gained", pl.id, potion.id, Balance.BOT_HELP_POTIONS)
	Events.post(&"notification", "%s agradece: +%d ouro%s" % [r["name"], gold, (", +%d %s" % [Balance.BOT_HELP_POTIONS, potion.name]) if potion else ""])
	Events.post(&"bot_help_ended", int(h["id"]), "helped")
	say(sim, r, "help_thanks", _personal_channel(sim, entity_of(sim, r)), {}, true)
	remember(sim, r, "ajudou_pedido")

## O mapa `b` é o mesmo de `a` ou fica a um portal dele (ida ou volta).
static func _near_map(sim: WorldSim, a: String, b: String) -> bool:
	if a == b:
		return true
	for pair in [[a, b], [b, a]]:
		var def: MapDef = sim.map_def(pair[0])
		if def == null:
			continue
		for pt in def.portals:
			if str(pt.get("target_map", "")) == pair[1]:
				return true
	return false

static func _attackers(sim: WorldSim, e: SimEntity) -> int:
	var n := 0
	for o: SimEntity in sim.map_entities(e.map_id):
		if o.kind == SimEntity.Kind.MONSTER and o.aggro_target == e.id and o.is_alive():
			n += 1
	return n

# ---------------------------------------------------------------------------
# REVISÃO (dev)

## Só para fotos/revisão (`--guild_shot`): jogador no nível `level` (> 0), elenco ligado com algumas lembranças,
## convite da guilda pendente e um pedido de socorro aberto a ~25 m do jogador.
static func dev_demo(sim: WorldSim, level: int) -> void:
	var pl := sim.player
	if pl == null:
		return
	if level > 0:
		pl.level = clampi(level, 1, Balance.MAX_LEVEL)
		pl.recompute_stats()
	start(sim)
	var friends: Array = sim.roster.filter(func(r: Dictionary): return not r["rival"])
	if friends.size() >= 2 and (friends[0]["memories"] as Array).is_empty():
		remember(sim, friends[0], "salvou")
		remember(sim, friends[0], "grupo")
		remember(sim, friends[1], "ajudou_pedido")
	if str(sim.social["player_guild"]) == "" and sim.social["offer"]["state"] != "pending":
		sim.social["offer"] = {"state": "none", "guild_id": "", "from": ""}
		GuildSystem.form(sim)
	var h: Dictionary = sim.social["help"]
	if h.is_empty() and friends.size() >= 3:
		var r: Dictionary = friends[friends.size() - 1]
		var e := entity_of(sim, r)
		if e:
			if BotChat.in_player_party(sim, e):
				PartySystem.party_leave(sim, e)
			var at := pl.position + Vector3(25, 0, 0)
			if e.map_id != pl.map_id:
				sim._change_map(e, pl.map_id, at)
			else:
				e.position = at
			open_help(sim, int(r["rid"]))
	Events.post(&"roster_changed")
