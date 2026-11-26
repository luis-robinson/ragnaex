class_name ArenaSystem
extends RefCounted
## Campo de Caça da Guilda (design/gdd/arena-da-guilda.md; decisões §0/§9): você + até 4 bots da guilda entram numa
## instância (`MapDef.instance`, mapa MapsCatalog.GUILD_GROUNDS_ID) e as levas chegam pelos portões, sem fim, cada uma mais
## dura, até o grupo cair ou sair. Saque só ouro ×3, cartas e consumíveis; XP pela metade. Recorde da guilda = maior leva.
## Estado em `sim.arena`: "charges" (float, 1 por hora de jogo, teto ARENA_CHARGES_MAX), "records" (guild_id -> recorde),
## "personal" (nome -> maior leva), "last" (resumo da última corrida) e "run" (corrida em andamento, fora do save).
## Números SÓ em Balance.ARENA_*. Estados da corrida: "break" (pausa) -> "fight" (leva) -> "break" ... -> fim (wipe/leave/left).

# ---------------------------------------------------------------------------
# SAVE (campo opcional `arena`)

static func to_save(sim: WorldSim) -> Dictionary:
	_defaults(sim)
	var a := sim.arena
	return {"v": 1, "charges": float(a["charges"]), "records": (a["records"] as Dictionary).duplicate(true),
		"personal": (a["personal"] as Dictionary).duplicate()}

static func from_save(sim: WorldSim, d: Dictionary) -> void:
	sim.arena.clear()
	_defaults(sim)
	var o: Dictionary = d.get("arena", {}) if d.get("arena") is Dictionary else {}
	if o.is_empty():
		return
	sim.arena["charges"] = clampf(float(o.get("charges", Balance.ARENA_CHARGES_START)), 0.0, float(Balance.ARENA_CHARGES_MAX))
	var rec: Dictionary = o.get("records", {}) if o.get("records") is Dictionary else {}
	for gid in rec:
		var r: Variant = rec[gid]
		if r is Dictionary:
			sim.arena["records"][str(gid)] = {"wave": int(r.get("wave", 0)), "names": (r.get("names", []) as Array).map(func(x): return str(x)) if r.get("names") is Array else [],
				"at": float(r.get("at", 0.0))}
	var per: Dictionary = o.get("personal", {}) if o.get("personal") is Dictionary else {}
	for nm in per:
		sim.arena["personal"][str(nm)] = int(per[nm])

static func _defaults(sim: WorldSim) -> void:
	sim.arena.get_or_add("charges", float(Balance.ARENA_CHARGES_START))
	sim.arena.get_or_add("records", {})
	sim.arena.get_or_add("personal", {})
	sim.arena.get_or_add("last", {})
	sim.arena.get_or_add("run", {})

## Lugar que o save grava: dentro da arena vale o lugar de onde o grupo entrou (fechar no meio = corrida terminada, §5).
static func save_place(sim: WorldSim, p: SimEntity) -> Dictionary:
	var run: Dictionary = sim.arena.get("run", {})
	var def: MapDef = sim.map_def(p.map_id)
	if def != null and def.instance:
		if not run.is_empty():
			var fp: Vector3 = run["from_pos"]
			return {"map": str(run["from_map"]), "pos": [fp.x, fp.z]}
		var home := PortalSystem.home_of(p, sim)
		return {"map": str(home["map"]), "pos": [(home["pos"] as Vector3).x, (home["pos"] as Vector3).z]}
	return {"map": p.map_id, "pos": [p.position.x, p.position.z]}

# ---------------------------------------------------------------------------
# CARGAS (1 por hora de jogo)

static func charges(sim: WorldSim) -> int:
	_defaults(sim)
	return int(floor(float(sim.arena["charges"]) + 0.0001))

## s de jogo até a próxima entrada (0 = cheio ou já tem uma inteira a caminho da cheia).
static func next_charge_in(sim: WorldSim) -> float:
	_defaults(sim)
	var c := float(sim.arena["charges"])
	if c >= float(Balance.ARENA_CHARGES_MAX):
		return 0.0
	return (1.0 - (c - floor(c))) * Balance.ARENA_CHARGE_MIN * 60.0

static func tick(sim: WorldSim, dt: float) -> void:
	_defaults(sim)
	var c := float(sim.arena["charges"])
	if c < float(Balance.ARENA_CHARGES_MAX):
		sim.arena["charges"] = minf(float(Balance.ARENA_CHARGES_MAX), c + dt / (Balance.ARENA_CHARGE_MIN * 60.0))
	var run: Dictionary = sim.arena["run"]
	if not run.is_empty():
		_update_run(sim, run, dt)

# ---------------------------------------------------------------------------
# FÓRMULAS (§4)

static func wave_size(n: int) -> int:
	return Balance.ARENA_WAVE_BASE + Balance.ARENA_WAVE_PER * n

static func hp_mult(n: int) -> float:
	return (1.0 + Balance.ARENA_HP_STEP * (n - 1)) * Balance.ARENA_HP_MULT

static func dmg_mult(n: int) -> float:
	return (1.0 + Balance.ARENA_DMG_STEP * (n - 1)) * Balance.ARENA_DMG_MULT

static func is_elite_wave(n: int) -> bool:
	return n > 0 and n % Balance.ARENA_ELITE_EVERY == 0

static func is_boss_wave(n: int) -> bool:
	return n > 0 and n % Balance.ARENA_BOSS_EVERY == 0

## Ajuste da faixa do grupo (Balance.ARENA_BAND_MULT: limite de cima da faixa -> [vida, dano]) por cima dos globais.
static func band_mult(level: int) -> Vector2:
	var keys: Array = Balance.ARENA_BAND_MULT.keys()
	keys.sort()
	for k in keys:
		if level <= int(k):
			var v: Array = Balance.ARENA_BAND_MULT[k]
			return Vector2(float(v[0]), float(v[1]))
	var last: Array = Balance.ARENA_BAND_MULT[keys.back()]
	return Vector2(float(last[0]), float(last[1]))

## Monstros comuns das zonas de campo da faixa (nível ± ARENA_BAND_SPREAD); sem nenhum, os 6 de nível mais perto.
static func band_pool(level: int) -> Array:
	return _pool(level, false, Balance.ARENA_BAND_SPREAD)

## Chefes de campo da faixa (spawner num mapa de campo; sem masmorra, sem Rei).
static func boss_pool(level: int) -> Array:
	return _pool(level, true, Balance.ARENA_BOSS_SPREAD)

static func _pool(level: int, bosses: bool, spread: int) -> Array:
	var seen := {}
	var all: Array = []
	var mids: Array = GameData.maps.keys()
	mids.sort()
	for mid in mids:
		var md: MapDef = GameData.maps[mid]
		if md.parent_map != "" or md.instance or md.interior:
			continue
		for sp in md.spawners:
			var id := str(sp.get("monster_id", ""))
			if seen.has(id) or not GameData.monsters.has(id):
				continue
			seen[id] = true
			var m: MonsterDef = GameData.monsters[id]
			if m.dummy or m.elite_of != "" or m.is_boss != bosses or m.xp <= 0:
				continue
			all.append(m)
	var near: Array = all.filter(func(m: MonsterDef): return absi(m.level - level) <= spread)
	if near.is_empty():
		all.sort_custom(func(a: MonsterDef, b: MonsterDef): return absi(a.level - level) < absi(b.level - level) or (absi(a.level - level) == absi(b.level - level) and a.id < b.id))
		near = all.slice(0, 6)
	near.sort_custom(func(a: MonsterDef, b: MonsterDef): return a.id < b.id)
	return near

## Monstro da leva `n` (cópia guardada na corrida): nível do grupo, vida/dano da leva, aggro da arena inteira, modificador.
static func wave_def(sim: WorldSim, run: Dictionary, base: MonsterDef, n: int, mod: String) -> MonsterDef:
	var key := "%s|%d|%s" % [base.id, n, mod]
	var cache: Dictionary = run["defs"]
	if cache.has(key):
		return cache[key]
	var d: MonsterDef = base.duplicate()
	d.level = int(run["level"]) + (2 if base.elite_of != "" else 0)
	var band := band_mult(int(run["level"]))
	var dm := dmg_mult(n) * band.y * float((Balance.ARENA_MODS.get(mod, {}) as Dictionary).get("dmg", 1.0))
	d.hp = base.hp * hp_mult(n) * band.x
	d.atk = base.atk * dm
	d.matk = base.matk * dm
	d.move_speed = base.move_speed * float((Balance.ARENA_MODS.get(mod, {}) as Dictionary).get("speed", 1.0))
	d.aggro_range = Balance.ARENA_AGGRO
	d.leash_range = Balance.ARENA_LEASH
	cache[key] = d
	return d

# ---------------------------------------------------------------------------
# ENTRADA

## Por que `p` não pode entrar agora ("" = pode).
static func enter_error(sim: WorldSim, p: SimEntity) -> String:
	if p == null or not p.is_alive():
		return "Indisponível agora."
	if GuildSystem.player_guild(sim).is_empty():
		return "Só para quem está numa guilda."
	if p.level < Balance.ARENA_LEVEL:
		return "Campo de Caça a partir do nível %d." % Balance.ARENA_LEVEL
	if not (sim.arena.get("run", {}) as Dictionary).is_empty():
		return "Já há uma corrida em andamento."
	var def: MapDef = sim.map_def(p.map_id)
	if def != null and (def.instance or def.parent_map != ""):
		return "Saia da masmorra antes."
	if charges(sim) <= 0:
		var s := int(ceil(next_charge_in(sim)))
		return "Sem entradas: a próxima em %d min %02d s de jogo." % [s / 60, s % 60]
	return ""

## Bots da guilda que podem entrar com o jogador (entradas do elenco vivas), sugeridos primeiro: os que já estão no seu
## grupo, depois tanque + cura + 2 dano pelos papéis das builds (§3.1).
static func candidates(sim: WorldSim) -> Array:
	var g := GuildSystem.player_guild(sim)
	var out: Array = []
	for m: Dictionary in g.get("members", []):
		var e: SimEntity = sim.entities.get(int(m.get("entity_id", -1)))
		if e == null or e.kind != SimEntity.Kind.BOT or int(m.get("rid", -1)) < 0:
			continue
		var away := float(sim.call("guild_mission_away", int(m["rid"]))) if sim.has_method("guild_mission_away") else 0.0
		out.append({"rid": int(m["rid"]), "name": e.name, "away": away, "class": e.class_def.id if e.class_def else "", "level": e.level,
			"role": ProgressionSystem.role_of(sim, e), "entity_id": e.id,
			"in_party": sim.player != null and sim.same_party(e, sim.player)})
	return out

## rids sugeridos (até ARENA_MAX_BOTS): quem já está no grupo, depois 1 tanque, 1 cura e o resto dano (maior nível primeiro).
static func suggest(cands: Array) -> Array:
	var pick: Array = []
	var by_lv := cands.filter(func(c: Dictionary): return float(c.get("away", 0.0)) <= 0.0)     # fora numa encomenda: indisponível
	by_lv.sort_custom(func(a: Dictionary, b: Dictionary): return int(a["level"]) > int(b["level"]) or (int(a["level"]) == int(b["level"]) and int(a["rid"]) < int(b["rid"])))
	for c: Dictionary in by_lv:
		if bool(c["in_party"]) and pick.size() < Balance.ARENA_MAX_BOTS:
			pick.append(c)
	for role in ["tank", "healer"]:
		if pick.any(func(c: Dictionary): return c["role"] == role):
			continue
		for c: Dictionary in by_lv:
			if c["role"] == role and not (c in pick) and pick.size() < Balance.ARENA_MAX_BOTS:
				pick.append(c)
				break
	for c: Dictionary in by_lv:
		if pick.size() >= Balance.ARENA_MAX_BOTS:
			break
		if not (c in pick) and c["role"] != "tank" and c["role"] != "healer":
			pick.append(c)
	for c: Dictionary in by_lv:
		if pick.size() >= Balance.ARENA_MAX_BOTS:
			break
		if not (c in pick):
			pick.append(c)
	return pick.map(func(c: Dictionary): return int(c["rid"]))

## Entra com os bots do elenco `rids` (até ARENA_MAX_BOTS; os que não estão vivos ficam de fora). "" = entrou.
static func enter(sim: WorldSim, rids: Array) -> String:
	var p := sim.player
	var err := enter_error(sim, p)
	if err != "":
		return err
	var bots: Array = []
	for rid in rids:
		var r := RosterSystem.entry(sim, int(rid))
		var b: SimEntity = RosterSystem.entity_of(sim, r) if not r.is_empty() else null
		if sim.has_method("guild_mission_away") and float(sim.call("guild_mission_away", int(rid))) > 0.0:
			continue                                 # bot fora numa encomenda do banco da guilda: não entra
		if b != null and not (b in bots) and bots.size() < Balance.ARENA_MAX_BOTS:
			bots.append(b)
	sim.arena["charges"] = float(sim.arena["charges"]) - 1.0
	start_run(sim, p, bots, str(sim.social.get("player_guild", "")))
	return ""

## Começa a corrida com `leader` (jogador ou, nas sondas, um bot) e `bots`; põe todos num grupo só e na arena.
static func start_run(sim: WorldSim, leader: SimEntity, bots: Array, guild_id: String = "") -> Dictionary:
	_defaults(sim)
	var def: MapDef = GameData.maps.get(MapsCatalog.GUILD_GROUNDS_ID)
	if def == null:
		return {}
	if not sim.maps.has(def.id):
		sim.load_map(def)
	_clear_map(sim, def.id)
	var members: Array = [leader] + bots
	_form_party(sim, leader, bots)
	var lv := 0
	for e: SimEntity in members:
		lv += e.level
	var run := {"map": def.id, "from_map": leader.map_id, "from_pos": leader.position, "members": members.map(func(e: SimEntity): return e.id),
		"names": members.map(func(e: SimEntity): return e.name), "guild": guild_id, "level": roundi(float(lv) / members.size()),
		"wave": 0, "phase": "break", "break_left": Balance.ARENA_FIRST_BREAK_S, "queue": [], "alive": [], "mod": "", "boss": false,
		"elite": false, "defs": {}, "release": 0.0, "gate_i": 0, "near": {}, "heal_t": 0.0, "t0": sim.time, "kills": 0,
		"last_kill": sim.time, "stalls": 0, "healers": [],
		"gold": 0, "cards0": _cards_of(leader), "leader": leader.id, "gates": MapsCatalog.guild_grounds_gates(),
		"exit": MapsCatalog.guild_grounds_exit(), "rec0": int(((sim.arena["records"] as Dictionary).get(guild_id, {}) as Dictionary).get("wave", 0))}
	sim.arena["run"] = run
	var i := 0
	for e: SimEntity in members:
		if not e.is_alive():
			_revive(sim, e, 1.0)
		if e.mounted:
			sim.dismount(e)
		e.recall_left = 0.0
		PortalSystem.change_map(sim, e, def.id, def.spawn_point + _ring(i, members.size(), 1.8 if i > 0 else 0.0))
		i += 1
	if leader == sim.player:
		Events.post(&"notification", "Campo de Caça: a 1ª leva chega em %d s." % int(Balance.ARENA_FIRST_BREAK_S))
	Events.post(&"arena_wave", 0, {"phase": "break"})
	return run

static func _ring(i: int, n: int, r: float) -> Vector3:
	var a := TAU * float(i) / maxf(1.0, float(n))
	return Vector3(cos(a) * r, 0.0, sin(a) * r)

static func _form_party(sim: WorldSim, leader: SimEntity, bots: Array) -> void:
	for b: SimEntity in bots:
		if b.party_id >= 0 and b.party_id != leader.party_id:
			PartySystem.party_leave(sim, b)
	var p := PartySystem.party_of(sim, leader)
	if p.is_empty():
		p = {"id": sim._next_party_id, "leader": leader.id, "members": [leader.id]}
		sim._next_party_id += 1
		sim.parties[p["id"]] = p
		PartySystem.set_party(sim, leader, p["id"])
	p["leader"] = leader.id
	for b: SimEntity in bots:
		if not (p["members"] as Array).has(b.id):
			p["members"].append(b.id)
			PartySystem.set_party(sim, b, p["id"])
	Events.post(&"party_changed", p["id"])

# ---------------------------------------------------------------------------
# CORRIDA

static func run_of(sim: WorldSim) -> Dictionary:
	return sim.arena.get("run", {})

## `e` está numa corrida ativa, dentro da arena.
static func in_run(sim: WorldSim, e: SimEntity) -> bool:
	var run: Dictionary = sim.arena.get("run", {})
	return not run.is_empty() and e != null and e.map_id == str(run["map"]) and (run["members"] as Array).has(e.id)

## Morto na arena não renasce em casa: fica de espectador até a pausa (§3.6).
static func holds(sim: WorldSim, e: SimEntity) -> bool:
	return in_run(sim, e)

## Bot que pode entrar na instância (party_catchup): só quem está na corrida.
static func admits(sim: WorldSim, map_id: String, e: SimEntity) -> bool:
	var def: MapDef = GameData.maps.get(map_id)
	if def == null or not def.instance:
		return true
	var run: Dictionary = sim.arena.get("run", {})
	return not run.is_empty() and (run["members"] as Array).has(e.id)

## "Próxima": a pausa acaba agora.
static func next_wave(sim: WorldSim) -> bool:
	var run: Dictionary = sim.arena.get("run", {})
	if run.is_empty() or run["phase"] != "break":
		return false
	run["break_left"] = 0.0
	return true

## Sair (botão ou ponto de saída na pausa).
static func leave(sim: WorldSim) -> void:
	if not (sim.arena.get("run", {}) as Dictionary).is_empty():
		finish(sim, "leave")

static func _members(sim: WorldSim, run: Dictionary) -> Array:
	var out: Array = []
	for id in run["members"]:
		var e: SimEntity = sim.entities.get(int(id))
		if e != null and e.map_id == str(run["map"]):
			out.append(e)
	return out

static func _update_run(sim: WorldSim, run: Dictionary, dt: float) -> void:
	var leader: SimEntity = sim.entities.get(int(run["leader"]))
	if leader == null or leader.map_id != str(run["map"]):
		finish(sim, "left")                     # o jogador saiu (G, morte fora daqui, sumiu)
		return
	var members := _members(sim, run)
	if not members.any(func(e: SimEntity): return e.is_alive()):
		finish(sim, "wipe")
		return
	var m: Dictionary = sim.maps[str(run["map"])]
	if run["phase"] == "break":
		run["break_left"] = float(run["break_left"]) - dt
		if leader.is_alive() and Vector2(leader.position.x - (run["exit"] as Vector3).x, leader.position.z - (run["exit"] as Vector3).z).length() <= Balance.ARENA_EXIT_RADIUS \
				and int(run["wave"]) > 0:
			finish(sim, "leave")
			return
		if float(run["break_left"]) <= 0.0:
			_start_wave(sim, run, int(run["wave"]) + 1)
		return
	# leva: solta da fila pelos portões, até ARENA_WAVE_CAP vivos
	var alive: Array = (run["alive"] as Array).filter(func(id): return sim.entities.has(id) and (sim.entities[id] as SimEntity).is_alive())
	run["alive"] = alive
	run["release"] = float(run["release"]) - dt
	var q: Array = run["queue"]
	var gates: Array = run["gates"]
	while not q.is_empty() and alive.size() < Balance.ARENA_WAVE_CAP and float(run["release"]) <= 0.0:
		var md: MonsterDef = q.pop_front()
		var gi := int(run["gate_i"]) % gates.size()
		run["gate_i"] = gi + 1
		var at: Vector3 = (gates[gi] as Vector3) * 0.92 + Vector3(sim.rng.randf_range(-1.0, 1.0), 0.0, sim.rng.randf_range(-1.0, 1.0))
		var e := _spawn(sim, run, md, at, m)
		alive.append(e.id)
		if float((Balance.ARENA_MODS.get(str(run["mod"]), {}) as Dictionary).get("heal", 0.0)) > 0.0 and (run["healers"] as Array).size() < Balance.ARENA_HEALERS_MAX:
			run["healers"].append(e.id)                   # Curandeiros: só os primeiros ARENA_HEALERS_MAX curam (matá-los para a cura)
		if gi == gates.size() - 1:
			run["release"] = Balance.ARENA_RELEASE_S        # uma volta pelos portões = uma soltura
	_mod_tick(sim, run, alive, dt)
	_unstick(sim, run, alive, members)
	if not alive.is_empty() and sim.time - float(run["last_kill"]) > Balance.ARENA_STALL_S:
		_unstall(sim, run, alive)
		if (sim.arena.get("run", {}) as Dictionary).is_empty():
			return
	if q.is_empty() and alive.is_empty():
		_end_wave(sim, run, members)

static func _spawn(sim: WorldSim, run: Dictionary, md: MonsterDef, at: Vector3, m: Dictionary) -> SimEntity:
	var e := sim.spawn_monster(md, str(run["map"]), sim._resolve_obstacles(at, md.radius, m))
	e.field_mob = MobSystem.is_field(md)
	e.recompute_stats()
	e.heal_full()
	var sh := float((Balance.ARENA_MODS.get(str(run["mod"]), {}) as Dictionary).get("shield", 0.0))
	if sh > 0.0:
		e.shield_hp = e.stats.max_hp * sh
	e.home_position = Vector3.ZERO                    # "casa" no centro: o leash nunca puxa de volta ao portão
	run["near"][e.id] = sim.time
	return e

static func _start_wave(sim: WorldSim, run: Dictionary, n: int) -> void:
	run["wave"] = n
	run["phase"] = "fight"
	run["release"] = 0.0
	var mod := ""
	if n >= Balance.ARENA_MOD_FROM:
		var keys: Array = Balance.ARENA_MODS.keys()
		keys.sort()
		mod = str(keys[sim.rng.randi() % keys.size()])
	run["mod"] = mod
	var lv := int(run["level"])
	var pool := band_pool(lv)
	var q: Array = []
	for i in wave_size(n):
		var base: MonsterDef = pool[sim.rng.randi() % pool.size()]
		q.append(wave_def(sim, run, base, n, mod))
	run["elite"] = is_elite_wave(n)
	if run["elite"]:                                  # Rei do monstro no meio da leva
		var base: MonsterDef = pool[sim.rng.randi() % pool.size()]
		q.insert(q.size() / 2, wave_def(sim, run, LootSystem.elite_def(sim, base), n, mod))
	run["boss"] = is_boss_wave(n)
	if run["boss"]:
		var bp := boss_pool(lv)
		if not bp.is_empty():
			var bd: MonsterDef = bp[sim.rng.randi() % bp.size()]
			run["boss_name"] = bd.name
			q.insert(q.size() / 2, wave_def(sim, run, bd, n, mod))
	run["queue"] = q
	run["last_kill"] = sim.time
	run["healers"] = []
	run["size"] = q.size()
	_record(sim, run)                                  # fechar o jogo no meio: a leva atual já vale (§5)
	var info := {"phase": "fight", "size": q.size(), "elite": run["elite"], "boss": run["boss"], "mod": mod,
		"mod_label": str((Balance.ARENA_MODS.get(mod, {}) as Dictionary).get("label", ""))}
	Events.post(&"arena_wave", n, info)
	if sim.entities.get(int(run["leader"])) == sim.player:
		var txt := "Leva %d" % n
		if run["boss"]:
			txt += " — chefe: %s!" % str(run.get("boss_name", "?"))
		elif run["elite"]:
			txt += " — um Rei vem junto!"
		if mod != "":
			txt += " (%s)" % info["mod_label"]
		Events.post(&"notification", txt)

static func _end_wave(sim: WorldSim, run: Dictionary, members: Array) -> void:
	run["phase"] = "break"
	run["break_left"] = Balance.ARENA_BREAK_S
	run["cleared"] = int(run["wave"])
	for e: SimEntity in members:
		if not e.is_alive():
			_revive(sim, e, Balance.ARENA_REVIVE_SHARE)
			e.position = sim.random_walkable(sim.map_def(str(run["map"])), Vector3.ZERO, 3.0)
	_clear_loot_hazards(sim, run)
	Events.post(&"arena_wave", int(run["wave"]), {"phase": "break", "cleared": int(run["wave"])})

static func _revive(sim: WorldSim, e: SimEntity, share: float) -> void:
	e.hp = e.stats.max_hp * share
	e.mp = maxf(e.mp, e.stats.max_mp * share)
	e.set_state(SimEntity.State.IDLE)
	e.threat.clear()
	e.dead_time = 0.0
	Events.post(&"entity_respawned", e.id)

static func _clear_loot_hazards(sim: WorldSim, run: Dictionary) -> void:
	var m: Dictionary = sim.maps[str(run["map"])]
	m["hazards"].clear()

## Leva sem abate há ARENA_STALL_S: a leva sempre termina. Os que sobraram vão ao centro, perdem escudo e a cura da leva.
static func _unstall(sim: WorldSim, run: Dictionary, alive: Array) -> void:
	run["last_kill"] = sim.time
	run["stalls"] = int(run["stalls"]) + 1
	run["healers"] = []
	run["stall_streak"] = int(run.get("stall_streak", 0)) + 1
	var names: Dictionary = run.get("stall_names", {})
	for id in alive:
		var nm: String = (sim.entities[id] as SimEntity).monster_def.id
		names[nm] = int(names.get(nm, 0)) + 1
	run["stall_names"] = names
	if int(run["stall_streak"]) > Balance.ARENA_STALL_MAX and alive.size() > Balance.ARENA_STALL_LEFT:
		finish(sim, "wipe")                       # muitos de pé e ninguém cai: o grupo não dá conta (um vivo fugindo para sempre)
		return
	if int(run["stall_streak"]) > Balance.ARENA_STALL_MAX:     # poucos que ninguém consegue derrubar: somem sem saque, a leva acaba
		for id in alive.duplicate():
			sim.despawn(sim.entities[id])
		alive.clear()
		run["stall_streak"] = 0
		return
	for id in alive:
		var e: SimEntity = sim.entities[id]
		e.shield_hp = 0.0
		e.position = sim.random_walkable(sim.map_def(str(run["map"])), Vector3.ZERO, 4.0)
		e.velocity = Vector3.ZERO

## Modificador "curandeiros": enquanto um dos curandeiros da leva vive, quem está ferido recupera ARENA_MODS.heal da vida por s.
static func _mod_tick(sim: WorldSim, run: Dictionary, alive: Array, dt: float) -> void:
	var heal := float((Balance.ARENA_MODS.get(str(run["mod"]), {}) as Dictionary).get("heal", 0.0))
	if heal <= 0.0:
		return
	if not (run["healers"] as Array).any(func(id): return alive.has(id)):
		return
	for id in alive:
		var e: SimEntity = sim.entities[id]
		if e.hp < e.stats.max_hp:
			e.hp = minf(e.stats.max_hp, e.hp + e.stats.max_hp * heal * dt)

## Monstro preso (atrás de pilar, fora da arena): longe do grupo e sem chegar perto por ARENA_STUCK_S volta ao centro.
static func _unstick(sim: WorldSim, run: Dictionary, alive: Array, members: Array) -> void:
	if (sim.tick_count % 30) != 0:
		return
	var near: Dictionary = run["near"]
	for id in alive:
		var e: SimEntity = sim.entities[id]
		var close := false
		for o: SimEntity in members:
			if o.is_alive() and o.position.distance_to(e.position) <= Balance.ARENA_STUCK_DIST:
				close = true
				break
		if close or e.hurt_at > float(near.get(id, sim.time)):
			near[id] = sim.time
		elif sim.time - float(near.get(id, sim.time)) >= Balance.ARENA_STUCK_S:
			e.position = sim.random_walkable(sim.map_def(str(run["map"])), Vector3.ZERO, 4.0)
			e.velocity = Vector3.ZERO
			near[id] = sim.time

# ---------------------------------------------------------------------------
# ABATE (§3.4): ouro ×3, cartas, consumíveis, XP pela metade; nada de equipamento/material/moeda lendária

## Chamado por LootSystem.on_monster_killed. true = monstro da arena (o saque normal não roda).
static func on_kill(sim: WorldSim, mob: SimEntity, killer: SimEntity) -> bool:
	var def: MapDef = sim.map_def(mob.map_id)
	if def == null or not def.instance:
		return false
	var run: Dictionary = sim.arena.get("run", {})
	if not run.is_empty():
		run["kills"] = int(run["kills"]) + 1
		run["last_kill"] = sim.time
		run["stall_streak"] = 0
	var credit := LootSystem.top_damager(sim, mob, killer)
	if credit == null or not credit.is_character():
		return true
	var md := mob.monster_def
	var sharers := PartySystem.kill_sharers(sim, credit, mob)
	var each := md.xp * (Balance.FIELD_MOB_XP_MULT if mob.field_mob else 1.0) * (1.0 + Balance.PARTY_XP_BONUS * (sharers.size() - 1)) / sharers.size()
	for c: SimEntity in sharers:
		var mult := clampf(1.0 + (mob.level - c.level) * 0.08, 0.3, 1.6)
		ProgressionSystem.gain_xp(sim, c, int(each * mult * LootSystem.xp_mult(c, mob.map_id) * Balance.ARENA_XP_MULT))
		QuestSystem.on_kill(c, md.elite_of if md.elite_of != "" else md.id)
	var gold := arena_gold(sim, md)
	var m: Dictionary = sim.maps[mob.map_id]
	if not run.is_empty() and sim.player in sharers:
		run["gold"] = int(run["gold"]) + (gold / sharers.size() if sharers.size() > 1 else (gold if credit == sim.player else 0))
	if gold > 0 and sharers.size() > 1:
		LootSystem.split_gold(sim, sharers, gold)
	elif gold > 0:
		LootSystem.drop(m, mob, 0, 0.5, "gold", gold, 45.0, credit.id, sim.time + Balance.LOOT_LOCK_TIME)
	var looter := LootSystem.next_looter(sim, credit, sharers)
	var item := roll_consumable(sim, int(run.get("level", mob.level)) if not run.is_empty() else mob.level)
	if item != "":
		LootSystem.drop(m, mob, 1, 0.6, item, 1, 60.0, looter.id, sim.time + Balance.LOOT_LOCK_TIME)
	CardSystem.on_kill(sim, sharers, mob)
	return true

## Ouro do abate na arena: o ouro normal do monstro (chefe ×3 como no campo) × ARENA_GOLD_MULT.
static func arena_gold(sim: WorldSim, md: MonsterDef) -> int:
	return sim.rng.randi_range(md.gold_min, md.gold_max) * (3 if md.is_boss else 1) * Balance.ARENA_GOLD_MULT

## Consumível do abate ("" = nada): poção/elixir pela tabela ARENA_CONSUMABLES ou, raro, uma Poção de Caça do grau do nível.
static func roll_consumable(sim: WorldSim, level: int) -> String:
	if sim.rng.randf() < Balance.ARENA_HUNT_POTION_CHANCE:
		var grade := HuntPotionSystem.grade_for(level)
		if grade > 0:
			var kinds: Array = HuntPotionSystem.KINDS
			var id := HuntPotionSystem.item_id(str(kinds[sim.rng.randi() % kinds.size()]), grade)
			if GameData.items.has(id):
				return id
	if sim.rng.randf() >= Balance.ARENA_CONSUMABLE_CHANCE:
		return ""
	var total := 0
	for c in Balance.ARENA_CONSUMABLES:
		if level >= int(c[2]) and GameData.items.has(str(c[0])):
			total += int(c[1])
	if total <= 0:
		return ""
	var r := sim.rng.randi() % total
	for c in Balance.ARENA_CONSUMABLES:
		if level >= int(c[2]) and GameData.items.has(str(c[0])):
			r -= int(c[1])
			if r < 0:
				return str(c[0])
	return ""

# ---------------------------------------------------------------------------
# FIM (§3.5)

static func finish(sim: WorldSim, reason: String) -> Dictionary:
	var run: Dictionary = sim.arena.get("run", {})
	if run.is_empty():
		return {}
	sim.arena["run"] = {}
	var wave := int(run["wave"])
	var rec := _record(sim, run)
	var leader: SimEntity = sim.entities.get(int(run["leader"]))
	var summary := {"wave": wave, "cleared": int(run.get("cleared", 0)), "reason": reason, "gold": int(run["gold"]), "kills": int(run["kills"]),
		"cards": maxi(0, _cards_of(leader) - int(run["cards0"])) if leader else 0, "time": sim.time - float(run["t0"]),
		"record": int(rec["record"]), "new_record": bool(rec["new"]), "names": (run["names"] as Array).duplicate(),
		"guild": str(run["guild"])}
	sim.arena["last"] = summary
	# todos de volta para onde entraram; mortos voltam com a vida do renascer (sem perder XP)
	var i := 0
	for id in run["members"]:
		var e: SimEntity = sim.entities.get(int(id))
		if e == null:
			continue
		if not e.is_alive():
			_revive(sim, e, Balance.RESPAWN_SHARE)
		var to_map := str(run["from_map"])
		var to_pos: Vector3 = (run["from_pos"] as Vector3) + _ring(i, (run["members"] as Array).size(), 1.6 if i > 0 else 0.0)
		if reason == "left" and leader != null and leader.map_id != str(run["map"]):
			to_map = leader.map_id                  # o líder saiu por conta própria (G): o grupo vai para perto dele
			to_pos = leader.position + _ring(i, 5, 1.6)
		if e.map_id == str(run["map"]):
			PortalSystem.change_map(sim, e, to_map, to_pos)
		i += 1
	_clear_map(sim, str(run["map"]))
	Events.post(&"arena_ended", summary)
	_chat(sim, run, summary)
	return summary

static func _cards_of(e: SimEntity) -> int:
	if e == null:
		return 0
	var n := 0
	for id in e.inventory:
		if GameData.cards.has(id):
			n += int(e.inventory[id])
	return n

## Grava o recorde da guilda e os pessoais com a leva atual. {record, new}.
static func _record(sim: WorldSim, run: Dictionary) -> Dictionary:
	var wave := int(run["wave"])
	var gid := str(run["guild"])
	var recs: Dictionary = sim.arena["records"]
	var cur: Dictionary = recs.get(gid, {"wave": 0, "names": [], "at": 0.0})
	var was := int(cur.get("wave", 0))
	if wave > was:
		recs[gid] = {"wave": wave, "names": (run["names"] as Array).duplicate(), "at": float(sim.social.get("clock", sim.time))}
	for nm in run["names"]:
		sim.arena["personal"][str(nm)] = maxi(int(sim.arena["personal"].get(str(nm), 0)), wave)
	return {"record": maxi(was, wave), "new": wave > int(run["rec0"])}

## Tira da arena o que sobrou (monstros, saque no chão, perigos).
static func _clear_map(sim: WorldSim, map_id: String) -> void:
	if not sim.maps.has(map_id):
		return
	var m: Dictionary = sim.maps[map_id]
	for e: SimEntity in (m["entities"] as Array).duplicate():
		if e.kind == SimEntity.Kind.MONSTER or (e.kind == SimEntity.Kind.SUMMON and e.owner_id < 0):
			sim.despawn(e)
	m["loot"].clear()
	m["hazards"].clear()
	m["traps"].clear()

## Bots comentam no chat da guilda (§3.5).
static func _chat(sim: WorldSim, run: Dictionary, s: Dictionary) -> void:
	if str(run["guild"]) == "" or sim.rng.randf() > Balance.ARENA_CHAT_CHANCE:
		return
	var bots: Array = []
	for id in run["members"]:
		var e: SimEntity = sim.entities.get(int(id))
		if e != null and e.kind == SimEntity.Kind.BOT:
			bots.append(e)
	if bots.is_empty():
		return
	var who: SimEntity = bots[sim.rng.randi() % bots.size()]
	var other: SimEntity = bots[sim.rng.randi() % bots.size()]
	var lines: Array = BotsCatalog.ARENA_LINES["record" if bool(s["new_record"]) else ("leave" if s["reason"] == "leave" else "wipe")]
	var text := str(lines[sim.rng.randi() % lines.size()]).format({"wave": int(s["wave"]), "name": other.name})
	Events.post(&"chat_message", who.name, text, "guild")

# ---------------------------------------------------------------------------
# LEITURA (aba "Campo de Caça" da janela da Guilda)

## Estado da aba ({} = nada a mostrar: sem guilda). Formato no fim do wave3-contract.md.
static func hunt_field(sim: WorldSim) -> Dictionary:
	var g := GuildSystem.player_guild(sim)
	if g.is_empty() or sim.player == null:
		return {}
	_defaults(sim)
	var cands := candidates(sim)
	var run: Dictionary = sim.arena["run"]
	var gid := str(g.get("id", ""))
	var personal := {}
	for nm in [sim.player.name] + cands.map(func(c: Dictionary): return str(c["name"])):
		personal[nm] = int(sim.arena["personal"].get(nm, 0))
	return {"charges": charges(sim), "max": Balance.ARENA_CHARGES_MAX, "next_in": next_charge_in(sim),
		"can_enter": enter_error(sim, sim.player) == "", "why": enter_error(sim, sim.player),
		"record": (sim.arena["records"] as Dictionary).get(gid, {}).duplicate(), "personal": personal,
		"candidates": cands, "suggested": suggest(cands), "max_bots": Balance.ARENA_MAX_BOTS,
		"run": status(sim), "last": (sim.arena["last"] as Dictionary).duplicate()}

## Corrida em andamento para o HUD ({} = nenhuma).
static func status(sim: WorldSim) -> Dictionary:
	var run: Dictionary = sim.arena.get("run", {})
	if run.is_empty():
		return {}
	var alive := 0
	for id in run["alive"]:
		if sim.entities.has(id) and (sim.entities[id] as SimEntity).is_alive():
			alive += 1
	return {"wave": int(run["wave"]), "phase": str(run["phase"]), "break_left": maxf(0.0, float(run.get("break_left", 0.0))),
		"alive": alive, "waiting": (run["queue"] as Array).size(), "size": int(run.get("size", 0)), "mod": str(run["mod"]),
		"mod_label": str((Balance.ARENA_MODS.get(str(run["mod"]), {}) as Dictionary).get("label", "")), "boss": bool(run["boss"]),
		"elite": bool(run["elite"]), "gold": int(run["gold"]), "kills": int(run["kills"]), "time": sim.time - float(run["t0"]),
		"exit": run["exit"], "map": str(run["map"]), "stalls": int(run["stalls"]), "stall_names": (run.get("stall_names", {}) as Dictionary).duplicate()}
