class_name GvgSystem
extends RefCounted
## Guerra de Guildas (design/gdd/guerra-de-guildas.md; decisões §0/§9; contrato production/session-state/wave6-contract.md §1/§3/§4).
## A sua guilda contra uma guilda de bots, 12 × 12, num mapa instanciado (MapsCatalog.GVG_FIELD_ID) com dois castelos.
## O jogador começa pela janela da Guilda (`start`): 30 s de preparação no mapa, depois a luta. O atacante derruba o portão
## (aríete, canhões, área), toma o pátio e quebra o Cristal do Trono antes de GVG_TIME_MIN; senão vence o defensor.
## Sem estado próprio: a partida em `sim.gvg` ({} = nenhuma), o recorde/loja em `sim.gvg_meta` (vai no save).
## O lado do jogador é sempre o SUL ("S"); quem ataca é o sul (atacar) ou o norte (defender).
## Objetos de cerco = SimEntity MONSTER sem cérebro (gvg_obj gate|ram|cannon|crystal), presos no lugar por este sistema.
## A barreira de cada portão é daqui: quem não é do castelo é empurrado para fora enquanto o portão está de pé (o dono passa).
## Os bots pensam pelo GvgBrain (gancho no BotBrain); aqui só o comandante, 1 vez por segundo (`GvgBrain.commander_tick`).
## Números SÓ em Balance.GVG_*. Fases: "prep" -> "fight" -> "end" (trégua com o resumo) -> todos voltam (sim.gvg = {}).

const SIDES := ["N", "S"]
const GATES := ["main_N", "side_N", "main_S", "side_S"]
const ATTACK_PLANS := ["martelo", "pinca", "bateria", "cerco_lento"]
const DEFENSE_PLANS := ["muralha", "surtida", "recuo"]
const ORDER_IDS := ["attack_gate_main", "attack_gate_side", "take_hill", "protect_ram", "hold_stair", "sally", "retreat", "all_to_me", "cannons"]
const ORDER_LABELS := {"attack_gate_main": "Todos no portão principal!", "attack_gate_side": "Todos no portão lateral!",
	"take_hill": "Tomem o morro dos canhões!", "protect_ram": "Protejam o aríete!", "hold_stair": "Segurem a escada!",
	"sally": "Surtida! Queimem os aríetes!", "retreat": "Recuar!", "all_to_me": "Todos comigo!", "cannons": "Nos canhões!"}
const PLAN_LABELS := {"martelo": "Martelo", "pinca": "Pinça", "bateria": "Bateria", "cerco_lento": "Cerco Lento",
	"muralha": "Muralha", "surtida": "Surtida", "recuo": "Recuo"}
const BRAIN_PATH := "res://core/sim/ai/gvg_brain.gd"
const CATALOG_PATH := "res://data/catalog/gvg_catalog.gd"

static var _brain: Script = null
static var _brain_tried := false

# ---------------------------------------------------------------------------
# LEITURA SIMPLES

## A guerra está acontecendo (preparo, luta ou trégua do fim)?
static func running(sim: WorldSim) -> bool:
	return not sim.gvg.is_empty()

## Lado de `e` na guerra ("N" | "S"; objetos também; "" = fora). Canhão do morro: "".
static func side_of(sim: WorldSim, e: SimEntity) -> String:
	if e == null or sim.gvg.is_empty() or e.map_id != str(sim.gvg["map_id"]):
		return ""
	return e.gvg_side if e.gvg_side in SIDES else ""

## `e` é um dos combatentes (não objeto, não invocação).
static func is_fighter(sim: WorldSim, e: SimEntity) -> bool:
	return e != null and not sim.gvg.is_empty() and e.gvg_side in SIDES and e.gvg_obj == "" and e.is_character()

## Etiqueta da guilda do lado do combatente ("" = nenhuma): recrutas levam a da guilda.
static func tag_of(sim: WorldSim, e: SimEntity) -> String:
	if sim.gvg.is_empty() or e.gvg_obj != "" or not (e.gvg_side in SIDES):
		return ""
	return str(sim.gvg["sides"][e.gvg_side].get("tag", ""))

## Objetos da guerra: a MESMA lista de dicionários a cada chamada (o GvgBrain guarda): {id, type, key, side, pos, alive,
## operator_id, cd, hp_pct}. Atualizada no tick.
static func objects(sim: WorldSim) -> Array:
	return sim.gvg.get("objects", [])

## Cópia para a UI (Sim.gvg_objects).
static func objects_public(sim: WorldSim) -> Array:
	var out: Array = []
	for o: Dictionary in objects(sim):
		var c := o.duplicate()
		out.append(c)
	return out

static func _obj(sim: WorldSim, key: String) -> Dictionary:
	return (sim.gvg.get("by_key", {}) as Dictionary).get(key, {})

static func _ent(sim: WorldSim, o: Dictionary) -> SimEntity:
	return sim.entities.get(int(o.get("id", -1))) if not o.is_empty() else null

## Vida (0-1) do objeto `key` (0 = caído / não existe).
static func hp_pct(sim: WorldSim, key: String) -> float:
	var e := _ent(sim, _obj(sim, key))
	return clampf(e.hp / maxf(1.0, e.stats.max_hp), 0.0, 1.0) if e != null and e.is_alive() else 0.0

static func other(side: String) -> String:
	return "S" if side == "N" else "N"

## Combatentes vivos do lado no mapa da guerra.
static func alive_of(sim: WorldSim, side: String) -> Array:
	var out: Array = []
	for id in sim.gvg["sides"][side]["ids"]:
		var e: SimEntity = sim.entities.get(int(id))
		if e != null and e.is_alive() and e.map_id == str(sim.gvg["map_id"]):
			out.append(e)
	return out

# ---------------------------------------------------------------------------
# ABA "GUERRA" (Sim.guild_war)

static func _meta(sim: WorldSim) -> Dictionary:
	var m := sim.gvg_meta
	m.get_or_add("wins", 0)
	m.get_or_add("losses", 0)
	m.get_or_add("vs", {})
	m.get_or_add("owned", {})
	m.get_or_add("banner", "")
	m.get_or_add("crest", "")
	m.get_or_add("last", {})
	return m

static func guild_war(sim: WorldSim) -> Dictionary:
	var meta := _meta(sim)
	var gl: Array = []
	for g: Dictionary in GuildSystem.list(sim):
		if not bool(g.get("bot_guild", false)):
			continue
		var vs: Dictionary = (meta["vs"] as Dictionary).get(str(g["id"]), {})
		gl.append({"id": g["id"], "name": g["name"], "tag": g["tag"], "personality": g["personality"], "power": int(g.get("power", 0)),
			"castle_owner": not bool(vs.get("taken", false)), "wins": int(vs.get("wins", 0)), "losses": int(vs.get("losses", 0)),
			"members": (g.get("members", []) as Array).size()})
	var why := start_error(sim, "" if gl.is_empty() else str(gl[0]["id"]))
	return {"guilds": gl, "record": {"wins": int(meta["wins"]), "losses": int(meta["losses"])}, "can_start": why == "", "why": why,
		"insignias": sim.player.war_insignias if sim.player else 0, "running": running(sim), "last": (meta["last"] as Dictionary).duplicate(),
		"side_size": Balance.GVG_SIDE_SIZE, "minutes": Balance.GVG_TIME_MIN}

## Por que a guerra contra `enemy` não pode começar agora ("" = pode; `enemy` "" = só as regras gerais).
static func start_error(sim: WorldSim, enemy: String) -> String:
	var p := sim.player
	if p == null or not p.is_alive():
		return "Indisponível agora."
	if GuildSystem.player_guild(sim).is_empty():
		return "Só para quem está numa guilda."
	if p.level < Balance.GVG_MIN_LEVEL:
		return "Guerra de Guildas a partir do nível %d." % Balance.GVG_MIN_LEVEL
	if running(sim):
		return "Já há uma guerra em andamento."
	if not (sim.arena.get("run", {}) as Dictionary).is_empty():
		return "Saia do Campo de Caça antes."
	var def: MapDef = sim.map_def(p.map_id)
	if def != null and (def.instance or def.parent_map != "" or def.interior):
		return "Saia da masmorra antes."
	if not GameData.maps.has(MapsCatalog.GVG_FIELD_ID):
		return "O campo da guerra não existe."
	if enemy != "":
		if not sim.guilds.has(enemy) or not bool(sim.guilds[enemy].get("bot_guild", false)):
			return "Escolha uma guilda de bots."
	return ""

# ---------------------------------------------------------------------------
# COMEÇO

## Começa a guerra (Sim.gvg_start). "" = começou (preparação no mapa da guerra).
static func start(sim: WorldSim, enemy: String, attack: bool) -> String:
	var err := start_error(sim, enemy)
	if err != "":
		return err
	var p := sim.player
	var pg := GuildSystem.player_guild(sim)
	var allies: Array = []
	for m: Dictionary in pg.get("members", []):
		var r := RosterSystem.entry(sim, int(m.get("rid", -1)))
		var b: SimEntity = RosterSystem.entity_of(sim, r) if not r.is_empty() else null
		if b == null or b.kind != SimEntity.Kind.BOT:
			continue
		if GuildBankSystem.is_away(sim, int(r["rid"])):
			continue                                     # fora numa encomenda do banco: não vem
		allies.append([int(r.get("affinity", 0)), b])
	allies.sort_custom(func(a, b): return int(a[0]) > int(b[0]) or (int(a[0]) == int(b[0]) and (a[1] as SimEntity).id < (b[1] as SimEntity).id))
	var bots: Array = allies.map(func(x): return x[1])
	begin(sim, p, bots, str(pg.get("id", "")), enemy, attack)
	return ""

## Monta a guerra: `leader` (jogador ou, nas sondas, um bot) + `bots` no SUL; a guilda `enemy` (dados) no NORTE.
## Completa os dois lados com recrutas até GVG_SIDE_SIZE. Devolve sim.gvg.
static func begin(sim: WorldSim, leader: SimEntity, bots: Array, my_guild: String, enemy: String, attack: bool) -> Dictionary:
	var def: MapDef = GameData.maps.get(MapsCatalog.GVG_FIELD_ID)
	if not sim.maps.has(def.id):
		sim.load_map(def)
	_clear_map(sim, def.id)
	var lv := leader.level
	var me_side := "S"
	var foe := "N"
	var attacker := me_side if attack else foe
	var mg: Dictionary = sim.guilds.get(my_guild, {})
	var eg: Dictionary = sim.guilds.get(enemy, {})
	var run := {"map_id": def.id, "phase": "prep", "attacker": attacker, "defender": other(attacker), "player_side": me_side,
		"time_left": Balance.GVG_TIME_MIN * 60.0, "prep_left": Balance.GVG_PREP_S, "end_left": 0.0, "t0": sim.time, "fight_t0": -1.0,
		"level": lv, "enemy_guild": enemy, "my_guild": my_guild, "leader": leader.id, "from_map": leader.map_id, "from_pos": leader.position,
		"restore": {}, "spawned": [], "respawn": {}, "deaths": {}, "objects": [], "by_key": {}, "operating": {}, "forward": false,
		"gates_broken": {}, "hill": "", "commander_t": 0.0, "crystal_evt": {"N": 1.0, "S": 1.0}, "crystal_evt_t": 0.0,
		"stats": {"cannon_shots": 0, "cannon_hits": 0, "cannon_ram_shots": 0, "cannon_ram_hits": 0, "gate_dmg": {"siege": 0, "area": 0, "plain": 0},
			"ram_hits": 0, "kills": {"N": 0, "S": 0}}, "me": {"kills": 0, "deaths": 0, "gate_dmg": 0, "crystal_dmg": 0, "cannon_hits": 0, "role": ""},
		"winner": "", "reason": "", "ref_atk": 0.0,
		"sides": {}}
	sim.gvg = run
	for s in SIDES:
		var g: Dictionary = mg if s == me_side else eg
		run["sides"][s] = {"ids": [], "guild_id": str(g.get("id", "")), "guild_name": str(g.get("name", "Recrutas")), "tag": str(g.get("tag", "")),
			"personality": str(g.get("personality", "equilibrada")), "plan": "", "commander_id": -1, "bot_commander_id": -1,
			"player_commands": false, "order": {}, "dead": 0, "rams_lost": 0, "kills": 0}
	# lado do jogador: ele + bots da guilda (nível igualado) + recrutas
	var mine: Array = [leader]
	for b: SimEntity in bots:
		if mine.size() >= Balance.GVG_SIDE_SIZE:
			break
		if b != leader and not (b in mine):
			_enlist_existing(sim, run, b, lv)
			mine.append(b)
	var taken := _taken_names(sim)
	while mine.size() < Balance.GVG_SIDE_SIZE:
		mine.append(_recruit(sim, run, def.id, lv, "", "", "", taken))
	# lado inimigo: membros da guilda de bots (pelos dados) + recrutas
	var theirs: Array = []
	for m: Dictionary in eg.get("members", []):
		if theirs.size() >= Balance.GVG_SIDE_SIZE:
			break
		var nm := str(m.get("name", ""))
		if taken.has(nm) or not GameData.classes.has(str(m.get("class", ""))):
			nm = ""
		theirs.append(_recruit(sim, run, def.id, lv, str(m.get("class", "")), str(m.get("build", "")), nm, taken))
	while theirs.size() < Balance.GVG_SIDE_SIZE:
		theirs.append(_recruit(sim, run, def.id, lv, "", "", "", taken))
	_seat(sim, run, me_side, mine)
	_seat(sim, run, foe, theirs)
	# comandantes: do seu lado o bot de maior afinidade (a lista já vem nessa ordem) / maior nível; do inimigo o líder da guilda
	for s in SIDES:
		var sd: Dictionary = run["sides"][s]
		var best: SimEntity = null
		for id in sd["ids"]:
			var e: SimEntity = sim.entities[id]
			if e == leader:
				continue
			if s == foe and e.name == str(eg.get("leader", "")):
				best = e
				break
			if best == null or (s == foe and e.level > best.level):
				best = e
		sd["commander_id"] = best.id if best else -1
		sd["bot_commander_id"] = sd["commander_id"]
	var atk := 0.0
	var n := 0
	for s in SIDES:
		for id in run["sides"][s]["ids"]:
			var e: SimEntity = sim.entities[id]
			atk += maxf(e.stats.patk, e.stats.matk)
			n += 1
	run["ref_atk"] = atk / maxf(1.0, float(n))
	_spawn_objects(sim, run, def.id, lv)
	_refresh_objects(sim, run)
	_nav(sim, def.id)                              # grade do caminho: uma vez por mapa, aqui (não no 1º passo de um bot)
	_nav_prebuild(sim, run)                        # campos dos objetivos: montados aos poucos no preparo
	Events.post(&"gvg_phase", "prep")
	if leader == sim.player:
		Events.post(&"notification", "Guerra contra %s: %s em %d s!" % [run["sides"][foe]["guild_name"], "o ataque começa" if attack else "defenda o castelo", int(Balance.GVG_PREP_S)])
	return run

static func _taken_names(sim: WorldSim) -> Dictionary:
	var taken := {}
	for e: SimEntity in sim.entities.values():
		if e.is_character():
			taken[e.name] = true
	for r: Dictionary in sim.roster:
		taken[str(r["name"])] = true
	return taken

## Bot que já existe (elenco da guilda) entra: guarda o que ele era e iguala o nível.
static func _enlist_existing(sim: WorldSim, run: Dictionary, b: SimEntity, lv: int) -> void:
	var eq := {}
	for slot in b.equipment:
		eq[slot] = b.equipment[slot]
	run["restore"][b.id] = {"map": b.map_id, "pos": b.position, "level": b.level, "xp": b.xp, "build": b.build_id, "equipment": eq,
		"hp": b.hp / maxf(1.0, b.stats.max_hp)}
	if not b.is_alive():
		_revive(sim, b, 1.0)
	var to := clampi(lv + sim.rng.randi_range(-Balance.GVG_LEVEL_SPREAD, Balance.GVG_LEVEL_SPREAD), 1, Balance.MAX_LEVEL)
	RosterSystem.set_level(sim, b, to, b.build_id)

## Recruta (ou membro de guilda de bots pelos dados): bot novo no mapa da guerra, no nível igualado; some no fim.
static func _recruit(sim: WorldSim, run: Dictionary, map_id: String, lv: int, cls_id: String, build: String, nm: String, taken: Dictionary) -> SimEntity:
	var classes: Array = GameData.class_list()
	var cls: ClassDef = GameData.classes.get(cls_id) if cls_id != "" else null
	if cls == null:
		cls = classes[sim.rng.randi() % classes.size()]
	if nm == "":
		nm = _free_name(sim, taken)
	taken[nm] = true
	var to := clampi(lv + sim.rng.randi_range(-Balance.GVG_LEVEL_SPREAD, Balance.GVG_LEVEL_SPREAD), 1, Balance.MAX_LEVEL)
	var b := sim.spawn_bot(cls, nm, map_id, Vector3.ZERO, to)
	if build != "" and not cls.build_by_id(build).is_empty() and build != b.build_id:
		RosterSystem.set_level(sim, b, to, build)
	run["spawned"].append(b.id)
	return b

static func _free_name(sim: WorldSim, taken: Dictionary) -> String:
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

## Põe o lado no mapa: gvg_side, a pé, vivo, em volta do renascer de trás.
static func _seat(sim: WorldSim, run: Dictionary, side: String, ents: Array) -> void:
	var ids: Array = run["sides"][side]["ids"]
	var i := 0
	for e: SimEntity in ents:
		ids.append(e.id)
		e.gvg_side = side
		if not e.is_alive():
			_revive(sim, e, 1.0)
		if e.mounted:
			sim.dismount(e)
		e.mount_left = 0.0
		e.recall_left = 0.0
		e.threat.clear()
		e.heal_full()
		var at := _spawn_pos(sim, run, side, i)
		if e.map_id != str(run["map_id"]):
			PortalSystem.change_map(sim, e, str(run["map_id"]), at)
		else:
			e.position = at
			e.velocity = Vector3.ZERO
		for o: SimEntity in sim.entities.values():
			if o.kind == SimEntity.Kind.SUMMON and o.owner_id == e.id:
				o.gvg_side = side
		i += 1

static func _spawn_pos(sim: WorldSim, run: Dictionary, side: String, i: int) -> Vector3:
	var base := MapsCatalog.gvg_point(("forward_" if bool(run["forward"]) and side == str(run["attacker"]) else "spawn_") + side)
	var a := TAU * float(i) / 12.0
	var at := base + Vector3(cos(a), 0.0, sin(a)) * (Balance.GVG_RESPAWN_SPREAD if i > 0 else 0.0)
	var m: Dictionary = sim.maps[str(run["map_id"])]
	return sim._resolve_obstacles(at, Balance.ENTITY_RADIUS, m)

# ---------------------------------------------------------------------------
# OBJETOS DE CERCO

static func _obj_def(type: String, key: String, lv: int) -> MonsterDef:
	var d := MonsterDef.new()
	d.id = "gvg_" + type
	d.level = lv
	d.atk = 0.0
	d.matk = 0.0
	d.def = 0.0
	d.mdef = 0.0
	d.move_speed = 0.0
	d.aggro_range = 0.0
	d.leash_range = 0.0
	d.xp = 0
	d.gold_min = 0
	d.gold_max = 0
	d.attack_range = 0.0
	match type:
		"gate":
			var main := key.begins_with("main")
			d.name = "Portão Principal" if main else "Portão Lateral"
			d.hp = Balance.GVG_GATE_HP * lv * (1.0 if main else Balance.GVG_SIDE_GATE_MULT)
			d.radius = float(MapsCatalog.GVG_GATE_HALF["main" if main else "side"]) * 0.7
			d.shape = "box"
			d.color = Color(0.45, 0.32, 0.2)
		"ram":
			d.name = "Aríete"
			d.hp = Balance.GVG_RAM_HP * lv
			d.def = Balance.GVG_RAM_DEF * lv
			d.mdef = Balance.GVG_RAM_DEF * lv
			d.radius = Balance.GVG_RAM_RADIUS
			d.model = "mob_siege_ram"
			d.color = Color(0.5, 0.36, 0.22)
		"cannon":
			d.name = "Canhão"
			d.hp = 1000.0
			d.radius = 0.9
			d.model = "mob_siege_cannon"
			d.color = Color(0.3, 0.3, 0.32)
		"crystal":
			d.name = "Cristal do Trono"
			d.hp = Balance.GVG_CRYSTAL_HP * lv
			d.radius = 1.4
			d.model = "mob_throne_crystal"
			d.shape = "cone"
			d.color = Color(0.55, 0.8, 1.0)
	return d

static func _spawn_obj(sim: WorldSim, run: Dictionary, map_id: String, type: String, key: String, side: String, pos: Vector3, lv: int, inv: bool) -> SimEntity:
	var e := sim.spawn_monster(_obj_def(type, key, lv), map_id, pos)
	e.brain = null
	e.position = pos
	e.home_position = pos
	e.gvg_side = side if side != "" else "H"
	e.gvg_obj = type
	e.gvg_inv = inv
	e.facing = 0.0 if side == "N" else PI
	var o := {"id": e.id, "type": type, "key": key, "side": side, "pos": pos, "alive": true, "operator_id": -1, "cd": 0.0, "hp_pct": 1.0,
		"hill": key.contains("hill"), "side_owner": side}
	if type == "ram":
		var ram_n := key.get_slice("_", 2)
		o["route"] = MapsCatalog.gvg_ram_route(side, "ram_" + ram_n)
		o["leg"] = 1
		o["hit_t"] = Balance.GVG_RAM_HIT_S
		o["moved_t"] = 0.0
		o["pushers"] = 0
		o["target"] = "main_" + other(side)
	run["objects"].append(o)
	run["by_key"][key] = o
	return e

static func _spawn_objects(sim: WorldSim, run: Dictionary, map_id: String, lv: int) -> void:
	var atk: String = run["attacker"]
	for s in SIDES:
		var attacker_castle: bool = s == atk                  # castelo de quem ataca: ninguém o ataca (portões/cristal intocáveis)
		for g in ["main", "side"]:
			_spawn_obj(sim, run, map_id, "gate", "%s_%s" % [g, s], s, MapsCatalog.gvg_point("gate_%s_%s" % [g, s]), lv, attacker_castle)
		_spawn_obj(sim, run, map_id, "crystal", "crystal_" + s, s, MapsCatalog.gvg_point("crystal_" + s), lv, attacker_castle)
		for i in range(1, 5):
			var k := "cannon_%s_%02d" % [s, i]
			_spawn_obj(sim, run, map_id, "cannon", k, s, MapsCatalog.gvg_point(k), lv, true)
	for i in range(1, 3):
		var k := "cannon_hill_%02d" % i
		_spawn_obj(sim, run, map_id, "cannon", k, "", MapsCatalog.gvg_point(k), lv, true)
		var rk := "ram_%s_%02d" % [atk, i]
		_spawn_obj(sim, run, map_id, "ram", rk, atk, MapsCatalog.gvg_point("ram_spawn_%s_%02d" % [atk, i]), lv, false)

static func _refresh_objects(sim: WorldSim, run: Dictionary) -> void:
	for o: Dictionary in run["objects"]:
		var e: SimEntity = sim.entities.get(int(o["id"]))
		var alive := e != null and e.is_alive()
		o["alive"] = alive
		o["hp_pct"] = clampf(e.hp / maxf(1.0, e.stats.max_hp), 0.0, 1.0) if alive else 0.0
		if e != null:
			o["pos"] = e.position

## Dano num objeto (WorldSim._deal_damage): portão leva 10% do golpe comum; aríete/canhão ("siege") e skill de área, inteiro.
static func object_damage(sim: WorldSim, attacker: SimEntity, target: SimEntity, amount: int, kind: String) -> int:
	if target.gvg_inv or sim.gvg.is_empty() or str(sim.gvg["phase"]) != "fight":
		return 0
	var out := amount
	if target.gvg_obj == "gate":
		var st: Dictionary = sim.gvg["stats"]["gate_dmg"]
		if kind == "siege":
			st["siege"] = int(st["siege"]) + amount
		elif is_area_hit(attacker):
			out = maxi(1, int(round(amount * Balance.GVG_GATE_AREA_MULT)))
			st["area"] = int(st["area"]) + out
		else:
			out = maxi(1, int(round(amount * Balance.GVG_GATE_PLAIN_MULT)))
			st["plain"] = int(st["plain"]) + out
	_count_me(sim, attacker, target, out)
	return out

## Linha "Você: ..." do resumo: dano do jogador (ou do líder da sonda) e das invocações dele em portão/cristal.
static func _count_me(sim: WorldSim, attacker: SimEntity, target: SimEntity, amount: int) -> void:
	if attacker == null:
		return
	var who := attacker
	if who.kind == SimEntity.Kind.SUMMON:
		who = sim.entities.get(who.owner_id)
	if who == null or who.id != int(sim.gvg["leader"]):
		return
	var me: Dictionary = sim.gvg["me"]
	if target.gvg_obj == "gate":
		me["gate_dmg"] = int(me["gate_dmg"]) + amount
	elif target.gvg_obj == "crystal":
		me["crystal_dmg"] = int(me["crystal_dmg"]) + amount

## O golpe de agora de `a` é de área (skill que não é o básico, com raio >= GVG_AREA_RADIUS no chão, em volta ou em cone)?
static func is_area_hit(a: SimEntity) -> bool:
	var s := a.current_skill
	if s == null or s == a.basic_skill:
		return false
	return s.target in [SkillDef.Target.GROUND, SkillDef.Target.SELF, SkillDef.Target.CONE] and s.radius >= Balance.GVG_AREA_RADIUS

# ---------------------------------------------------------------------------
# TICK

static func tick(sim: WorldSim, dt: float) -> void:
	var run := sim.gvg
	if run.is_empty():
		return
	var leader: SimEntity = sim.entities.get(int(run["leader"]))
	var phase := str(run["phase"])
	if phase == "end":
		run["end_left"] = float(run["end_left"]) - dt
		if float(run["end_left"]) <= 0.0:
			close(sim)
		return
	if leader == null or leader.map_id != str(run["map_id"]):
		finish(sim, str(run["defender"]) if str(run["attacker"]) == str(run["player_side"]) else str(run["attacker"]), "left")
		close(sim)                                  # saiu do mapa (G, desconectou): derrota (§5)
		return
	var pt := Time.get_ticks_usec() if sim.profile else 0
	_nav_drain(sim, run)
	if sim.profile:
		sim._prof("gvg_nav", pt)
		pt = Time.get_ticks_usec()
	if phase == "prep":
		run["prep_left"] = float(run["prep_left"]) - dt
		_hold_prep(sim, run)
		if float(run["prep_left"]) <= 0.0:
			run["phase"] = "fight"
			run["fight_t0"] = sim.time
			Events.post(&"gvg_phase", "fight")
			if leader == sim.player:
				Events.post(&"notification", "A guerra começou!")
			_commander(sim, run, true)
		_refresh_objects(sim, run)
		if sim.profile:
			sim._prof("gvg_prep", pt)
		return
	run["time_left"] = float(run["time_left"]) - dt
	_gates(sim, run)
	_rams(sim, run, dt)
	_cannons(sim, run, dt)
	_crystal(sim, run, dt)
	_hill(sim, run)
	_respawns(sim, run, dt)
	_orders(sim, run)
	_refresh_objects(sim, run)
	run["commander_t"] = float(run["commander_t"]) - dt
	if float(run["commander_t"]) <= 0.0:
		run["commander_t"] = Balance.GVG_COMMANDER_S
		_commander(sim, run, false)
	if sim.profile:
		sim._prof("gvg_rest", pt)
	if sim.gvg.is_empty() or str(run["phase"]) != "fight":
		return
	if float(run["time_left"]) <= 0.0:
		finish(sim, str(run["defender"]), "time")

## Preparação: cada um fica perto do próprio renascer.
static func _hold_prep(sim: WorldSim, run: Dictionary) -> void:
	for s in SIDES:
		var base := MapsCatalog.gvg_point("spawn_" + s)
		for e: SimEntity in alive_of(sim, s):
			var off := e.position - base
			off.y = 0.0
			if off.length() > Balance.GVG_PREP_RADIUS:
				e.position = base + off.normalized() * Balance.GVG_PREP_RADIUS
				e.velocity = Vector3.ZERO

## Comandante de cada lado (GvgBrain.commander_tick, se existe); sem plano depois dele = o plano padrão.
static func _commander(sim: WorldSim, run: Dictionary, first: bool) -> void:
	var gb := brain_script()
	for s in SIDES:
		if gb != null:
			gb.call("commander_tick", sim, s)
		if sim.gvg.is_empty():
			return
		var sd: Dictionary = run["sides"][s]
		if str(sd["plan"]) == "" and first:
			set_plan(sim, s, "martelo" if s == str(run["attacker"]) else "muralha", "start")

## GvgBrain carregado pelo caminho (null = ainda não existe).
static func brain_script() -> Script:
	if not _brain_tried:
		_brain_tried = true
		if ResourceLoader.exists(BRAIN_PATH):
			_brain = load(BRAIN_PATH)
	return _brain

# --- portões: barreira de quem não é do castelo -----------------------------------------------

static func _gates(sim: WorldSim, run: Dictionary) -> void:
	var boxes: Dictionary = run.get_or_add("gate_boxes", {})
	if boxes.is_empty():
		for k in NAV_GATES:
			boxes[k] = gate_box_of(k)
	for k in NAV_GATES:
		var owner := str(k).get_slice("_", 1)
		if not str(k).begins_with("rear"):                  # postigo de trás: não é objeto, nunca cai
			var o: Dictionary = run["by_key"][k]
			var g := _ent(sim, o)
			if g == null or not g.is_alive():
				continue
			g.position = o["pos"]
		var box: Dictionary = boxes[k]
		if box["c"] == Vector3.INF:
			continue
		var c: Vector3 = box["c"]
		var half: float = box["half"]
		var nz: bool = box["normal_z"]
		for e: SimEntity in alive_of(sim, other(owner)):
			_push_out(e, c, half, nz)
		for e: SimEntity in (sim.maps[str(run["map_id"])]["entities"] as Array):
			if e.kind == SimEntity.Kind.SUMMON and e.gvg_side != owner and e.is_alive():
				_push_out(e, c, half, nz)

static func _push_out(e: SimEntity, c: Vector3, half: float, nz: bool) -> void:
	var r := e.radius
	var along := (e.position.x - c.x) if nz else (e.position.z - c.z)
	var across := (e.position.z - c.z) if nz else (e.position.x - c.x)
	var depth := Balance.GVG_GATE_DEPTH + r
	if absf(along) >= half + r or absf(across) >= depth:
		return
	var sg := signf(across) if absf(across) > 0.01 else signf(-c.z if nz else -c.x)     # sem lado: para fora do castelo
	if nz:
		e.position.z = c.z + sg * depth
	else:
		e.position.x = c.x + sg * depth

## Portão caiu: passagem livre, renascer avançado do atacante (portão principal), aviso.
static func _gate_broken(sim: WorldSim, run: Dictionary, key: String) -> void:
	run["gates_broken"][key] = sim.time - float(run["fight_t0"])
	if key.begins_with("main") and key.ends_with(str(run["defender"])):
		run["forward"] = true
	Events.post(&"gvg_gate_broken", key)
	_nav_prebuild(sim, run)                        # portão caído = máscara nova: refaz os campos dos objetivos primeiro
	var mine := key.ends_with(str(run["player_side"]))
	Events.post(&"notification", "%s %s caiu!" % ["Nosso" if mine else "O", "portão principal" if key.begins_with("main") else "portão lateral"])

# --- aríetes -----------------------------------------------------------------------------------

static func _rams(sim: WorldSim, run: Dictionary, dt: float) -> void:
	for o: Dictionary in run["objects"]:
		if o["type"] != "ram":
			continue
		var e := _ent(sim, o)
		if e == null or not e.is_alive():
			continue
		var side: String = o["side"]
		var push := 0
		for a: SimEntity in alive_of(sim, side):
			if a.position.distance_to(e.position) <= Balance.GVG_RAM_PUSH_R + e.radius:
				push += 1
		o["pushers"] = push
		var gate := _ent(sim, _obj(sim, str(o["target"])))
		var route: Array = o["route"]
		var gate_up := gate != null and gate.is_alive()
		var at_gate := gate_up and e.position.distance_to(gate.position) <= Balance.GVG_RAM_REACH + gate.radius
		e.velocity = Vector3.ZERO
		if at_gate:
			o["hit_t"] = float(o["hit_t"]) - dt
			e.face_towards(gate.position)
			if float(o["hit_t"]) <= 0.0 and push >= 1:
				o["hit_t"] = Balance.GVG_RAM_HIT_S
				run["stats"]["ram_hits"] = int(run["stats"]["ram_hits"]) + 1
				Events.post(&"skill_cast", e.id, e.basic_skill.id if e.basic_skill else "attack", "active")
				sim._deal_damage(e, gate, int(round(Balance.GVG_RAM_HIT * int(run["level"]))), false, false, "siege", e.position, false)
			continue
		var leg := int(o["leg"])
		if push < Balance.GVG_RAM_PUSHERS or leg >= route.size() or not gate_up:
			e.position = o["pos"]                     # parado: ninguém empurra (ou o portão já caiu)
			continue
		var to: Vector3 = route[leg]
		var d := to - e.position
		d.y = 0.0
		var step := Balance.GVG_RAM_SPEED * dt
		if d.length() <= step:
			e.position = to
			o["leg"] = leg + 1
		else:
			e.position += d.normalized() * step
			e.velocity = d.normalized() * Balance.GVG_RAM_SPEED
			e.face_towards(to)
		o["pos"] = e.position

# --- canhões -----------------------------------------------------------------------------------

## Por que `e` não pode operar o canhão `cannon_id` ("" = pode).
static func cannon_error(sim: WorldSim, e: SimEntity, cannon_id: int) -> String:
	if sim.gvg.is_empty() or e == null or not is_fighter(sim, e):
		return "Sem guerra."
	if str(sim.gvg["phase"]) != "fight":
		return "A guerra ainda não começou."
	if not e.is_alive():
		return "Indisponível agora."
	var o := _cannon_obj(sim, cannon_id)
	if o.is_empty():
		return "Isso não é um canhão."
	var c := _ent(sim, o)
	if c == null or e.position.distance_to(c.position) > Balance.GVG_CANNON_USE_R + c.radius:
		return "Chegue mais perto do canhão."
	if str(o["side"]) != "" and str(o["side"]) != e.gvg_side:
		return "Canhão do inimigo."
	if int(o["operator_id"]) >= 0 and int(o["operator_id"]) != e.id:
		return "Alguém já opera este canhão."
	return ""

static func _cannon_obj(sim: WorldSim, cannon_id: int) -> Dictionary:
	for o: Dictionary in objects(sim):
		if o["type"] == "cannon" and int(o["id"]) == cannon_id:
			return o
	return {}

## Opera o canhão (jogador pelo F, bots pelo GvgBrain). O primeiro fica. "" = operando.
static func cannon_use(sim: WorldSim, e: SimEntity, cannon_id: int) -> String:
	var err := cannon_error(sim, e, cannon_id)
	if err != "":
		return err
	cannon_leave(sim, e)
	var o := _cannon_obj(sim, cannon_id)
	o["operator_id"] = e.id
	if o["hill"]:
		o["side_owner"] = e.gvg_side
	sim.gvg["operating"][e.id] = o
	e.velocity = Vector3.ZERO
	return ""

static func cannon_leave(sim: WorldSim, e: SimEntity) -> void:
	if e == null or sim.gvg.is_empty():
		return
	var o: Dictionary = (sim.gvg["operating"] as Dictionary).get(e.id, {})
	if not o.is_empty() and int(o["operator_id"]) == e.id:
		o["operator_id"] = -1
	(sim.gvg["operating"] as Dictionary).erase(e.id)

## Comando de quem opera um canhão (WorldSim._apply_command): andar larga; atacar atira no ponto mirado. true = consumido.
static func cannon_cmd(sim: WorldSim, e: SimEntity, cmd: InputCommand) -> bool:
	var o: Dictionary = (sim.gvg["operating"] as Dictionary).get(e.id, {})
	if o.is_empty():
		return false
	if cmd.move.length_squared() > 0.04 or cmd.dash or cmd.skill_slot >= 0 or cmd.jump:
		cannon_leave(sim, e)
		return false
	var c := _ent(sim, o)
	if c == null:
		cannon_leave(sim, e)
		return false
	e.velocity = Vector3.ZERO
	c.face_towards(cmd.aim)
	e.face_towards(cmd.aim)
	if cmd.attack and float(o["cd"]) <= 0.0 and str(sim.gvg["phase"]) == "fight":
		fire(sim, o, e, cmd.aim)
	return true

## Tiro: círculo avisado no ponto (puxado para o alcance), cai em GVG_CANNON_WARN s (GvgSystem.land).
static func fire(sim: WorldSim, o: Dictionary, op: SimEntity, aim: Vector3) -> void:
	var run := sim.gvg
	var c := _ent(sim, o)
	var d := aim - c.position
	d.y = 0.0
	var dist := clampf(d.length(), Balance.GVG_CANNON_MIN, Balance.GVG_CANNON_RANGE)
	var at := c.position + (d.normalized() if d.length() > 0.01 else c.forward()) * dist
	at.y = 0.0
	o["cd"] = Balance.GVG_CANNON_CD
	var m: Dictionary = sim.maps[c.map_id]
	var near_ram := false
	for r: Dictionary in run["objects"]:
		if r["type"] == "ram" and bool(r["alive"]) and str(r["side"]) != op.gvg_side and (r["pos"] as Vector3).distance_to(at) <= Balance.GVG_CANNON_RADIUS + 3.0:
			near_ram = true
	var h := {"owner": c.id, "pos": at, "radius": Balance.GVG_CANNON_RADIUS, "at": sim.time + Balance.GVG_CANNON_WARN, "power": 0.0,
		"kind": SkillDef.Kind.PHYSICAL, "effects": {}, "skill": "gvg_cannon", "gvg": true, "side": op.gvg_side, "op": op.id,
		"dmg": Balance.GVG_CANNON_POWER * float(run["ref_atk"]), "ram_shot": near_ram}
	BossSignatures.add_hazard(m, h, sim.time)
	run["stats"]["cannon_shots"] = int(run["stats"]["cannon_shots"]) + 1
	if near_ram:
		run["stats"]["cannon_ram_shots"] = int(run["stats"]["cannon_ram_shots"]) + 1
	Events.post(&"hazard_placed", c.map_id, at, Balance.GVG_CANNON_RADIUS, Balance.GVG_CANNON_WARN, "gvg_cannon")
	Events.post(&"skill_cast", c.id, c.basic_skill.id if c.basic_skill else "attack", "active")
	Events.post(&"gvg_cannon_fired", c.id, at)

## O tiro cai (BossSignatures.update_hazards): dano em quem é do outro lado dentro do círculo; × GVG_CANNON_SIEGE_MULT só em portão.
static func land(sim: WorldSim, m: Dictionary, owner: SimEntity, h: Dictionary) -> void:
	if sim.gvg.is_empty():
		return
	var run := sim.gvg
	var side := str(h["side"])
	var pos: Vector3 = h["pos"]
	var op: SimEntity = sim.entities.get(int(h["op"]))
	var src: SimEntity = op if op != null and op.is_alive() and op.map_id == owner.map_id else owner
	var hit := false
	var hit_ram := false
	for o: SimEntity in (m["entities"] as Array).duplicate():
		if not o.is_alive() or o.gvg_side == "" or o.gvg_side == side or o.gvg_inv or o.gvg_side == "H":
			continue
		var dv := o.position - pos
		dv.y = 0.0
		if dv.length() > float(h["radius"]) + o.radius:
			continue
		var dmg := float(h["dmg"]) * (Balance.GVG_CANNON_SIEGE_MULT if o.gvg_obj == "gate" else 1.0)     # aríete leva o dano comum (usuário 2026-11-27)
		sim._deal_damage(src, o, int(round(dmg)), false, false, "siege", pos, false)
		hit = true
		hit_ram = hit_ram or o.gvg_obj == "ram"
	if hit:
		run["stats"]["cannon_hits"] = int(run["stats"]["cannon_hits"]) + 1
		if op != null and op.id == int(run["leader"]):
			run["me"]["cannon_hits"] = int(run["me"]["cannon_hits"]) + 1
	if hit_ram:
		run["stats"]["cannon_ram_hits"] = int(run["stats"]["cannon_ram_hits"]) + 1

static func _cannons(sim: WorldSim, run: Dictionary, dt: float) -> void:
	for o: Dictionary in run["objects"]:
		if o["type"] != "cannon":
			continue
		var c := _ent(sim, o)
		if c != null:
			c.position = o["pos"]
		o["cd"] = maxf(0.0, float(o["cd"]) - dt)
		var opid := int(o["operator_id"])
		if opid < 0:
			continue
		var op: SimEntity = sim.entities.get(opid)
		if op == null or not op.is_alive() or op.map_id != str(run["map_id"]) or c == null \
				or op.position.distance_to(c.position) > Balance.GVG_CANNON_USE_R + c.radius + 0.5:
			o["operator_id"] = -1
			(run["operating"] as Dictionary).erase(opid)

# --- cristal, morro, renascer, ordens ------------------------------------------------------------

static func _crystal(sim: WorldSim, run: Dictionary, dt: float) -> void:
	var dside: String = run["defender"]
	var o: Dictionary = run["by_key"]["crystal_" + dside]
	var c := _ent(sim, o)
	if c == null or not c.is_alive():
		return
	c.position = o["pos"]
	var near := false
	for a: SimEntity in alive_of(sim, str(run["attacker"])):
		if a.position.distance_to(c.position) <= Balance.GVG_CRYSTAL_SAFE_R:
			near = true
			break
	if not near and c.hp < c.stats.max_hp:
		c.hp = minf(c.stats.max_hp, c.hp + c.stats.max_hp * Balance.GVG_CRYSTAL_REGEN * dt)
	var pct := c.hp / maxf(1.0, c.stats.max_hp)
	var last := float(run["crystal_evt"][dside])
	if absf(last - pct) >= Balance.GVG_CRYSTAL_EVENT_STEP and sim.time - float(run["crystal_evt_t"]) >= 1.0:
		run["crystal_evt"][dside] = pct
		run["crystal_evt_t"] = sim.time
		Events.post(&"gvg_crystal_hit", dside, pct)
	var ao: Dictionary = run["by_key"]["crystal_" + str(run["attacker"])]
	var ac := _ent(sim, ao)
	if ac != null:
		ac.position = ao["pos"]
		ac.hp = ac.stats.max_hp

static func _hill(sim: WorldSim, run: Dictionary) -> void:
	if (sim.tick_count % 10) != 0:
		return
	var here := {"N": 0, "S": 0}
	for s in SIDES:
		for a: SimEntity in alive_of(sim, s):
			if Vector2(a.position.x, a.position.z).length() <= Balance.GVG_HILL_R:
				here[s] = int(here[s]) + 1
	if int(here["N"]) > 0 and int(here["S"]) == 0:
		run["hill"] = "N"
	elif int(here["S"]) > 0 and int(here["N"]) == 0:
		run["hill"] = "S"
	for o: Dictionary in run["objects"]:
		if bool(o.get("hill", false)) and int(o["operator_id"]) < 0:
			o["side_owner"] = str(run["hill"])

static func _respawns(sim: WorldSim, run: Dictionary, dt: float) -> void:
	var rs: Dictionary = run["respawn"]
	if rs.is_empty():
		return
	for id in rs.keys():
		rs[id] = float(rs[id]) - dt
		if float(rs[id]) > 0.0:
			continue
		rs.erase(id)
		var e: SimEntity = sim.entities.get(int(id))
		if e == null or e.is_alive() or e.map_id != str(run["map_id"]):
			continue
		_revive(sim, e, 1.0)
		e.position = _spawn_pos(sim, run, e.gvg_side, sim.rng.randi_range(1, 11))

## Tempo do renascer da morte número `n` (1 = a 1ª).
static func respawn_time(n: int) -> float:
	return minf(Balance.GVG_RESPAWN_MAX, Balance.GVG_RESPAWN_S + Balance.GVG_RESPAWN_STEP * maxi(0, n - 1))

static func _orders(sim: WorldSim, run: Dictionary) -> void:
	for s in SIDES:
		var od: Dictionary = run["sides"][s]["order"]
		if not od.is_empty() and sim.time >= float(od.get("until", INF)):
			run["sides"][s]["order"] = {}

static func _revive(sim: WorldSim, e: SimEntity, share: float) -> void:
	e.hp = e.stats.max_hp * share
	e.mp = maxf(e.mp, e.stats.max_mp * share)
	e.set_state(SimEntity.State.IDLE)
	e.threat.clear()
	e.dead_time = 0.0
	e.res_hold = 0.0
	Events.post(&"entity_respawned", e.id)

# ---------------------------------------------------------------------------
# MORTE (WorldSim._kill)

static func on_death(sim: WorldSim, e: SimEntity, killer: SimEntity) -> void:
	var run := sim.gvg
	if run.is_empty() or e.map_id != str(run["map_id"]):
		return
	match e.gvg_obj:
		"gate":
			for k in GATES:
				if int(run["by_key"][k]["id"]) == e.id:
					_gate_broken(sim, run, k)
			return
		"crystal":
			if str(run["phase"]) == "fight" and e.gvg_side == str(run["defender"]):
				run["crystal_t"] = sim.time - float(run["fight_t0"])
				finish(sim, str(run["attacker"]), "crystal")
			return
		"ram":
			var sd: Dictionary = run["sides"][e.gvg_side]
			sd["rams_lost"] = int(sd["rams_lost"]) + 1
			return
		"cannon":
			return
	if not e.is_character() or not (e.gvg_side in SIDES):
		return
	cannon_leave(sim, e)
	var n := int(run["deaths"].get(e.id, 0)) + 1
	run["deaths"][e.id] = n
	run["sides"][e.gvg_side]["dead"] = int(run["sides"][e.gvg_side]["dead"]) + 1
	if e.id == int(run["leader"]):
		run["me"]["deaths"] = int(run["me"]["deaths"]) + 1
	var who: SimEntity = killer
	if who != null and who.kind == SimEntity.Kind.SUMMON:
		who = sim.entities.get(who.owner_id)
	if who != null and who.gvg_side in SIDES and who.gvg_side != e.gvg_side:
		run["sides"][who.gvg_side]["kills"] = int(run["sides"][who.gvg_side]["kills"]) + 1
		run["stats"]["kills"][who.gvg_side] = int(run["stats"]["kills"][who.gvg_side]) + 1
		if who.id == int(run["leader"]):
			run["me"]["kills"] = int(run["me"]["kills"]) + 1
	run["respawn"][e.id] = respawn_time(n)

# ---------------------------------------------------------------------------
# PLANOS E ORDENS

static func _plan_ok(attack: bool, plan_id: String) -> bool:
	if ResourceLoader.exists(CATALOG_PATH):
		var cat: Script = load(CATALOG_PATH)
		if cat != null and cat.has_method("plan_ok"):
			return bool(cat.call("plan_ok", attack, plan_id))
	return plan_id in (ATTACK_PLANS if attack else DEFENSE_PLANS)

## Plano do lado (comandante bot ou jogador). Posta gvg_plan_changed; as falas são do GvgBrain.
static func set_plan(sim: WorldSim, side: String, plan_id: String, reason: String) -> void:
	if sim.gvg.is_empty() or not (side in SIDES):
		return
	var sd: Dictionary = sim.gvg["sides"][side]
	sd["plan"] = plan_id
	sd["plan_at"] = sim.time
	sd["plan_reason"] = reason
	Events.post(&"gvg_plan_changed", side, plan_id, reason)

## Ordem para o lado (`from_id` = quem deu). Com o jogador no comando a ordem dele fica até outra (§5).
static func set_order(sim: WorldSim, side: String, order_id: String, target: Variant, from_id: int) -> void:
	var sd: Dictionary = sim.gvg["sides"][side]
	var hold := INF if (bool(sd["player_commands"]) and sim.player != null and from_id == sim.player.id) else sim.time + Balance.GVG_ORDER_HOLD_S
	sd["order"] = {"id": order_id, "target": target, "from_id": from_id, "until": hold, "at": sim.time}
	Events.post(&"gvg_order", side, order_id, from_id)

static func player_order(sim: WorldSim, order_id: String, target: Variant = null) -> String:
	if sim.gvg.is_empty() or sim.player == null or not is_fighter(sim, sim.player):
		return "Sem guerra em andamento."
	if str(sim.gvg["phase"]) == "end":
		return "A guerra acabou."
	if not (order_id in ORDER_IDS):
		return "Ordem desconhecida."
	var side: String = sim.player.gvg_side
	set_order(sim, side, order_id, target, sim.player.id)
	Events.post(&"chat_message", sim.player.name, str(ORDER_LABELS.get(order_id, order_id)), "guild")
	return ""

## Plano do jogador: assumir o plano é assumir o comando (o bot comandante para de trocar).
static func player_plan(sim: WorldSim, plan_id: String) -> String:
	if sim.gvg.is_empty() or sim.player == null or not is_fighter(sim, sim.player):
		return "Sem guerra em andamento."
	var side: String = sim.player.gvg_side
	var attack := side == str(sim.gvg["attacker"])
	if not _plan_ok(attack, plan_id):
		return "Plano de %s: %s." % ["ataque" if attack else "defesa", ", ".join((ATTACK_PLANS if attack else DEFENSE_PLANS).map(func(p): return PLAN_LABELS.get(p, p)))]
	if not bool(sim.gvg["sides"][side]["player_commands"]):
		take_command(sim, true)
	set_plan(sim, side, plan_id, "player")
	Events.post(&"chat_message", sim.player.name, "Plano: %s!" % PLAN_LABELS.get(plan_id, plan_id), "guild")
	return ""

## Papel escolhido pelo jogador na preparação (Sim.gvg_pick_role): só guardado (resumo / comandante); os bots não mudam.
static func pick_role(sim: WorldSim, role: String) -> String:
	if sim.gvg.is_empty() or sim.player == null or not is_fighter(sim, sim.player):
		return "Sem guerra em andamento."
	if not (role in GvgCatalog.ROLES):
		return "Papel desconhecido."
	sim.gvg["me"]["role"] = role
	sim.gvg["sides"][sim.player.gvg_side]["player_role"] = role
	return ""

static func take_command(sim: WorldSim, on: bool) -> void:
	if sim.gvg.is_empty() or sim.player == null or not is_fighter(sim, sim.player):
		return
	var sd: Dictionary = sim.gvg["sides"][sim.player.gvg_side]
	sd["player_commands"] = on
	sd["commander_id"] = sim.player.id if on else int(sd["bot_commander_id"])
	if not on and not sd["order"].is_empty() and float(sd["order"].get("until", 0.0)) == INF:
		sd["order"]["until"] = sim.time + Balance.GVG_ORDER_HOLD_S
	Events.post(&"notification", "Você comanda a guilda." if on else "O comandante volta a mandar.")

## Comandos de chat da guerra. "" = não é comando da guerra; senão a resposta para o jogador.
static func chat_command(sim: WorldSim, text: String) -> String:
	var t := text.strip_edges().to_lower()
	for pair in [["ã", "a"], ["õ", "o"], ["ç", "c"], ["á", "a"], ["é", "e"], ["í", "i"], ["ó", "o"], ["ú", "u"], ["â", "a"], ["ê", "e"]]:
		t = t.replace(pair[0], pair[1])
	var parts := t.split(" ", false)
	if parts.is_empty():
		return ""
	var cmd := parts[0]
	var arg := " ".join(parts.slice(1)) if parts.size() > 1 else ""
	var order := ""
	match cmd:
		"/plano":
			if sim.gvg.is_empty():
				return "Sem guerra em andamento."
			var err := player_plan(sim, arg.replace(" ", "_"))
			return err if err != "" else "Plano: %s." % PLAN_LABELS.get(arg.replace(" ", "_"), arg)
		"/todos":
			order = {"portao": "attack_gate_main", "principal": "attack_gate_main", "lateral": "attack_gate_side", "morro": "take_hill",
				"escada": "hold_stair", "aqui": "all_to_me", "comigo": "all_to_me", "ariete": "protect_ram"}.get(arg, "")
			if order == "":
				return "Use: /todos portao | lateral | morro | escada | ariete | comigo"
		"/canhoes":
			order = "cannons"
		"/recuar":
			order = "retreat"
		"/surtida":
			order = "sally"
		"/ariete":
			order = "protect_ram"
		"/comando":
			if sim.gvg.is_empty():
				return "Sem guerra em andamento."
			var sd: Dictionary = sim.gvg["sides"][str(sim.gvg["player_side"])]
			take_command(sim, not bool(sd["player_commands"]))
			return "Você comanda." if bool(sd["player_commands"]) else "O comandante bot manda."
		_:
			return ""
	var e2 := player_order(sim, order)
	return e2 if e2 != "" else str(ORDER_LABELS.get(order, order))

# ---------------------------------------------------------------------------
# FIM

## Desistir (botão Sair): derrota.
static func forfeit(sim: WorldSim) -> void:
	if sim.gvg.is_empty():
		return
	var run := sim.gvg
	if str(run["phase"]) != "end":
		var ps: String = run["player_side"]
		finish(sim, other(ps), "forfeit")
	close(sim)

## Vencedor decidido: prêmios, recorde, trégua (ninguém é hostil) por GVG_END_S s, depois `close`.
static func finish(sim: WorldSim, winner: String, reason: String) -> Dictionary:
	var run := sim.gvg
	if run.is_empty() or str(run["phase"]) == "end":
		return {}
	run["phase"] = "end"
	run["winner"] = winner
	run["reason"] = reason
	run["end_left"] = Balance.GVG_END_S
	var ps: String = run["player_side"]
	var won := winner == ps
	var attacking := str(run["attacker"]) == ps
	var lv := int(run["level"])
	var bonus := Balance.GVG_REWARD_ATTACK_BONUS if attacking and won else 1.0
	var gold := int(round(Balance.GVG_REWARD_GOLD * lv * bonus)) if won else 0
	var ins := int(round(Balance.GVG_REWARD_INSIGNIAS * bonus)) if won else int(round(Balance.GVG_REWARD_INSIGNIAS * Balance.GVG_REWARD_LOSS_SHARE))
	var leader: SimEntity = sim.entities.get(int(run["leader"]))
	if leader != null and leader == sim.player:
		leader.gold += gold
		leader.war_insignias += ins
	var meta := _meta(sim)
	meta["wins" if won else "losses"] = int(meta["wins" if won else "losses"]) + 1
	var gid := str(run["enemy_guild"])
	if gid != "":
		var vs: Dictionary = (meta["vs"] as Dictionary).get_or_add(gid, {"wins": 0, "losses": 0, "taken": false})
		vs["wins" if won else "losses"] = int(vs.get("wins" if won else "losses", 0)) + 1
		if won and attacking:
			vs["taken"] = true                           # tomou o castelo deles
		elif not won and not attacking:
			vs["taken"] = false                          # perdeu a defesa: eles retomam
	var fought: Array = []
	for id in run["sides"][ps]["ids"]:
		var e: SimEntity = sim.entities.get(int(id))
		if e != null and e.roster_id >= 0:
			fought.append(e.name)
			if won and sim.roster_on:
				var r := RosterSystem.entry(sim, e.roster_id)
				if not r.is_empty():
					RosterSystem.remember(sim, r, "guerra")
	var fight_s := sim.time - float(run["fight_t0"]) if float(run["fight_t0"]) >= 0.0 else 0.0
	var summary := {"winner": winner, "won": won, "attacker": run["attacker"], "player_side": ps, "reason": reason, "time": fight_s,
		"gates_broken": (run["gates_broken"] as Dictionary).duplicate(), "crystal_pct": hp_pct(sim, "crystal_" + str(run["defender"])),
		"crystal_t": float(run.get("crystal_t", -1.0)), "kills": {"N": int(run["sides"]["N"]["kills"]), "S": int(run["sides"]["S"]["kills"])},
		"deaths": {"N": int(run["sides"]["N"]["dead"]), "S": int(run["sides"]["S"]["dead"])}, "gold": gold, "insignias": ins,
		"enemy": str(run["sides"][other(ps)]["guild_name"]), "enemy_guild": gid, "fought": fought, "stats": (run["stats"] as Dictionary).duplicate(true),
		"player": (run["me"] as Dictionary).duplicate()}
	run["summary"] = summary
	meta["last"] = summary
	for s in SIDES:
		for id in run["sides"][s]["ids"]:
			var e: SimEntity = sim.entities.get(int(id))
			if e != null:
				e.gvg_inv = true                          # trégua até todos voltarem
				cannon_leave(sim, e)
	Events.post(&"gvg_phase", "end")
	Events.post(&"gvg_ended", winner, summary)
	if leader == sim.player:
		Events.post(&"notification", ("Vitória! +%d ouro, +%d Insígnias de Guerra." % [gold, ins]) if won else ("Derrota. +%d Insígnias de Guerra." % ins))
	return summary

## Todos voltam: recrutas somem, bots da guilda voltam ao nível/equipamento e ao lugar de antes, o jogador para onde estava.
static func close(sim: WorldSim) -> void:
	var run := sim.gvg
	if run.is_empty():
		return
	var map_id := str(run["map_id"])
	var leader: SimEntity = sim.entities.get(int(run["leader"]))
	for id in run["spawned"]:
		var e: SimEntity = sim.entities.get(int(id))
		if e != null:
			sim.despawn(e)
	for s in SIDES:
		for id in run["sides"][s]["ids"]:
			var e: SimEntity = sim.entities.get(int(id))
			if e == null:
				continue
			e.gvg_side = ""
			e.gvg_inv = false
			if not e.is_alive():
				_revive(sim, e, Balance.RESPAWN_SHARE)
			var rs: Dictionary = (run["restore"] as Dictionary).get(e.id, {})
			if not rs.is_empty():
				RosterSystem.set_level(sim, e, int(rs["level"]), str(rs["build"]))
				e.xp = int(rs["xp"])
				var eq: Dictionary = rs["equipment"]
				e.equipment.clear()
				for slot in eq:
					e.equipment[slot] = eq[slot]
				e.recompute_stats()
				e.heal_full()
				if e.map_id == map_id:
					PortalSystem.change_map(sim, e, str(rs["map"]), rs["pos"])
			elif e == leader and e.map_id == map_id:
				PortalSystem.change_map(sim, e, str(run["from_map"]), run["from_pos"])
			if e.brain is BotBrain:
				(e.brain as BotBrain).war.clear()
	for e: SimEntity in sim.entities.values():
		if e.kind == SimEntity.Kind.SUMMON and e.gvg_side != "":
			e.gvg_side = ""
	_clear_map(sim, map_id)
	sim.gvg = {}
	Events.post(&"gvg_phase", "")

static func _clear_map(sim: WorldSim, map_id: String) -> void:
	if not sim.maps.has(map_id):
		return
	var m: Dictionary = sim.maps[map_id]
	for e: SimEntity in (m["entities"] as Array).duplicate():
		if e.kind == SimEntity.Kind.MONSTER or (e.kind == SimEntity.Kind.SUMMON and (e.owner_id < 0 or not sim.entities.has(e.owner_id))):
			sim.despawn(e)
	m["loot"].clear()
	m["hazards"].clear()
	m["traps"].clear()

# ---------------------------------------------------------------------------
# CAMINHO (os castelos têm muro: o renascer fica atrás deles e o BotBrain só anda em linha reta + desvio)
# Grade de GVG_NAV_CELL m sobre o mapa (montada uma vez por mapa, em m["gvg_nav"]): 0 = sólido, 1 = livre, 2.. = célula de
# portão (código = índice em NAV_GATES + 2). Portão barra quem não é do castelo enquanto está de pé (o postigo de trás
# nunca cai). Campo de distância (BFS) por destino + lado + portões que barram, guardado em m["gvg_fields"] (poucos:
# só é preciso quando a linha reta não serve). `waypoint` = o próximo ponto que se vê em linha reta no caminho.

const NAV_GATES := ["main_N", "side_N", "rear_N", "main_S", "side_S", "rear_S"]

static func _nav(sim: WorldSim, map_id: String) -> Dictionary:
	var m: Dictionary = sim.maps[map_id]
	if m.has("gvg_nav"):
		return m["gvg_nav"]
	var def: MapDef = m["def"]
	var raw := MapsCatalog.gvg_field_raw()
	var bounds: Array = ((raw.get("gvg", {}) as Dictionary).get("bounds", []) as Array) if raw.get("gvg") is Dictionary else []
	var half := def.half()
	var x0: float = float(bounds[0]) if bounds.size() == 4 else -half.x
	var x1: float = float(bounds[1]) if bounds.size() == 4 else half.x
	var z0: float = float(bounds[2]) if bounds.size() == 4 else -half.y
	var z1: float = float(bounds[3]) if bounds.size() == 4 else half.y
	var cell := Balance.GVG_NAV_CELL
	var w := int(ceil((x1 - x0) / cell))
	var h := int(ceil((z1 - z0) / cell))
	var grid := PackedByteArray()
	grid.resize(w * h)
	for iz in h:
		for ix in w:
			var p := Vector3(x0 + (ix + 0.5) * cell, 0.0, z0 + (iz + 0.5) * cell)
			grid[iz * w + ix] = 1 if MapGeometry.resolve_obstacles(sim, p, Balance.GVG_NAV_RADIUS, m).distance_squared_to(p) < 0.0001 else 0
	var nav := {"x0": x0, "z0": z0, "w": w, "h": h, "cell": cell, "grid": grid, "boxes": {}}
	for gi in NAV_GATES.size():
		var key: String = NAV_GATES[gi]
		var bx := gate_box_of(key)
		nav["boxes"][key] = bx
		var c: Vector3 = bx["c"]
		var ext := Vector2(float(bx["half"]) + 0.6, Balance.GVG_GATE_DEPTH + 0.8)
		if not bool(bx["normal_z"]):
			ext = Vector2(ext.y, ext.x)
		for iz in range(maxi(0, int((c.z - ext.y - z0) / cell)), mini(h, int((c.z + ext.y - z0) / cell) + 1)):
			for ix in range(maxi(0, int((c.x - ext.x - x0) / cell)), mini(w, int((c.x + ext.x - x0) / cell) + 1)):
				var p := Vector3(x0 + (ix + 0.5) * cell, 0.0, z0 + (iz + 0.5) * cell)
				if absf(p.x - c.x) <= ext.x and absf(p.z - c.z) <= ext.y and grid[iz * w + ix] != 0:
					grid[iz * w + ix] = gi + 2
	m["gvg_nav"] = nav
	m["gvg_fields"] = {}
	return nav

## Caixa da barreira do portão `key` (main_N, side_S, rear_N...): centro, meia-largura e se a passagem corre em z.
static func gate_box_of(key: String) -> Dictionary:
	var side := key.get_slice("_", 1)
	var which := key.get_slice("_", 0)
	var raw := MapsCatalog.gvg_field_raw()
	var mk: Dictionary = raw.get("markers", {}) if raw.get("markers") is Dictionary else {}
	var md: Dictionary = mk.get("OBJ_gate_%s_%s" % [which, side], {}) if mk.get("OBJ_gate_%s_%s" % [which, side]) is Dictionary else {}
	var c := MapsCatalog.gvg_point("gate_%s_%s" % [which, side])
	if md.has("pos"):
		c = Vector3(float(md["pos"][0]), 0.0, float(md["pos"][1]))
	var half: float = float(md.get("width", 0.0)) * 0.5 if md.has("width") else float(MapsCatalog.GVG_GATE_HALF.get(which, 1.5))
	var nz := true
	if md.get("dir") is Array:
		nz = absf(float(md["dir"][1])) >= absf(float(md["dir"][0]))     # portão num muro leste-oeste: passa em z
	return {"c": c, "half": half, "normal_z": nz, "side": side}

## Código de célula `code` deixa o lado `side` passar agora? (portões: dono passa; caído passa; postigo nunca cai)
static func _nav_pass(sim: WorldSim, code: int, side: String) -> bool:
	if code <= 1:
		return code == 1
	var key: String = NAV_GATES[code - 2]
	if key.ends_with(side):
		return true
	if key.begins_with("rear"):
		return false
	return hp_pct(sim, key) <= 0.0

static func _nav_cell(nav: Dictionary, p: Vector3) -> int:
	var ix := int(floor((p.x - float(nav["x0"])) / float(nav["cell"])))
	var iz := int(floor((p.z - float(nav["z0"])) / float(nav["cell"])))
	if ix < 0 or iz < 0 or ix >= int(nav["w"]) or iz >= int(nav["h"]):
		return -1
	return iz * int(nav["w"]) + ix

static func _nav_center(nav: Dictionary, i: int) -> Vector3:
	var w := int(nav["w"])
	return Vector3(float(nav["x0"]) + (i % w + 0.5) * float(nav["cell"]), 0.0, float(nav["z0"]) + (i / w + 0.5) * float(nav["cell"]))

## Linha reta a→b passa só por células livres para `side` (amostra a cada meia célula)?
static func _nav_los(sim: WorldSim, nav: Dictionary, a: Vector3, b: Vector3, side: String) -> bool:
	var grid: PackedByteArray = nav["grid"]
	var x0: float = nav["x0"]
	var z0: float = nav["z0"]
	var cell: float = nav["cell"]
	var w: int = nav["w"]
	var h: int = nav["h"]
	var dx := b.x - a.x
	var dz := b.z - a.z
	var n := int(ceil(sqrt(dx * dx + dz * dz) / (cell * 0.5)))
	var last := -1
	for k in range(1, n + 1):
		var t := float(k) / float(n)
		var ix := int(floor((a.x + dx * t - x0) / cell))
		var iz := int(floor((a.z + dz * t - z0) / cell))
		if ix < 0 or iz < 0 or ix >= w or iz >= h:
			return false
		var i := iz * w + ix
		if i == last:
			continue
		last = i
		var c := grid[i]
		if c == 1:
			continue
		if c == 0 or not _nav_pass(sim, c, side):
			return false
	return true

## Células livres para `side` em volta de `p` (a até 3 células), da mais perto para a mais longe (vazio = nenhuma).
static func _nav_free_near(sim: WorldSim, nav: Dictionary, p: Vector3, side: String) -> Array:
	var grid: PackedByteArray = nav["grid"]
	var i := _nav_cell(nav, p)
	if i >= 0 and _nav_pass(sim, grid[i], side):
		return [i]
	var out: Array = []
	var w := int(nav["w"])
	var h := int(nav["h"])
	var cx := int(floor((p.x - float(nav["x0"])) / float(nav["cell"])))
	var cz := int(floor((p.z - float(nav["z0"])) / float(nav["cell"])))
	for dz in range(-3, 4):
		for dx in range(-3, 4):
			var x := cx + dx
			var z := cz + dz
			if x < 0 or z < 0 or x >= w or z >= h or not _nav_pass(sim, grid[z * w + x], side):
				continue
			out.append([_nav_center(nav, z * w + x).distance_squared_to(p), z * w + x])
	out.sort()
	return out.map(func(c): return c[1])

## Portões que barram o lado `side` agora (bit = índice em NAV_GATES).
static func _nav_mask(sim: WorldSim, side: String) -> int:
	var mask := 0
	for gi in NAV_GATES.size():
		if not _nav_pass(sim, gi + 2, side):
			mask |= 1 << gi
	return mask

## Campo de distância (passos de célula, -1 = não chega) até a célula `dest` para o lado `side`; guardado por destino + lado +
## portões que barram (cai um portão = chave nova), com despejo do menos usado (LRU) acima de GVG_NAV_FIELDS.
## `budget` (bots, via `waypoint`): campo que não está pronto entra na fila e volta vazio; a fila é montada em `tick`,
## no máximo GVG_NAV_BUILDS_PER_TICK por passo (cada BFS da grade custa ~10 ms). Sem `budget` monta na hora.
static func _nav_field(sim: WorldSim, m: Dictionary, nav: Dictionary, dest: int, side: String, budget := false) -> PackedInt32Array:
	var mask := _nav_mask(sim, side)
	var key := "%d|%s|%d" % [dest, side, mask]
	var fields: Dictionary = m["gvg_fields"]
	if fields.has(key):
		var f: PackedInt32Array = fields[key]
		fields.erase(key)                         # LRU: o usado agora vai para o fim da ordem
		fields[key] = f
		return f
	if budget:
		_nav_enqueue(sim, dest, side, false)
		return PackedInt32Array()
	return _nav_build(sim, m, nav, dest, side, mask, key)

## Pede o campo (dest, side) para a fila (`front` = antes dos outros: objetivos). Repetido não entra duas vezes.
static func _nav_enqueue(sim: WorldSim, dest: int, side: String, front: bool) -> void:
	if sim.gvg.is_empty():
		return
	var q: Array = sim.gvg.get_or_add("nav_q", [])
	var qs: Dictionary = sim.gvg.get_or_add("nav_qs", {})
	var qk := "%d|%s" % [dest, side]
	if qs.has(qk):
		return
	if not front and q.size() >= Balance.GVG_NAV_QUEUE:
		return                                    # fila cheia: o bot pede de novo no próximo passo
	qs[qk] = true
	if front:
		q.push_front([dest, side])
	else:
		q.append([dest, side])

## Campos montados neste passo (zera quando sim.time muda).
static func _nav_spent(sim: WorldSim) -> int:
	if sim.gvg.is_empty() or float(sim.gvg.get("nav_tick", -1.0)) != sim.time:
		return 0
	return int(sim.gvg.get("nav_n", 0))

## Monta campos da fila até o orçamento do passo.
static func _nav_drain(sim: WorldSim, run: Dictionary) -> void:
	var q: Array = run.get("nav_q", [])
	if q.is_empty():
		return
	var m: Dictionary = sim.maps[str(run["map_id"])]
	var nav := _nav(sim, str(run["map_id"]))
	var qs: Dictionary = run["nav_qs"]
	while not q.is_empty() and _nav_spent(sim) < Balance.GVG_NAV_BUILDS_PER_TICK:
		var it: Array = q.pop_front()
		var dest: int = it[0]
		var side: String = it[1]
		qs.erase("%d|%s" % [dest, side])
		var mask := _nav_mask(sim, side)
		var key := "%d|%s|%d" % [dest, side, mask]
		if not (m["gvg_fields"] as Dictionary).has(key):
			_nav_build(sim, m, nav, dest, side, mask, key)

## Objetivos fixos dos dois lados (portões, cristais, canhões, renasceres, morro, frente) na frente da fila: montados no
## preparo e de novo quando um portão cai (máscara nova). Mesmo destino que `_waypoint` usaria (célula livre + encaixe).
static func _nav_prebuild(sim: WorldSim, run: Dictionary) -> void:
	var nav := _nav(sim, str(run["map_id"]))
	var pts: Array = [GvgCatalog.HILL]
	for o: Dictionary in run["objects"]:
		if o["type"] != "ram":
			pts.append(o["pos"])
	for s in SIDES:
		pts.append(MapsCatalog.gvg_point("spawn_" + s))
		pts.append(GvgCatalog.point("front", s))
	var todo: Array = []
	for s in SIDES:
		for p: Vector3 in pts:
			var bb := _nav_free_near(sim, nav, p, s)
			if not bb.is_empty():
				todo.append([_nav_snap(sim, nav, int(bb[0]), s), s])
	todo.reverse()                                # push_front: a ordem final fica a da lista
	for it: Array in todo:
		_nav_enqueue(sim, int(it[0]), str(it[1]), true)

## Destino do campo compartilhado: a célula livre do bloco de GVG_NAV_SNAP células de `cell` mais perto do centro do
## bloco que vê `cell` em linha reta (= mesma região, o caminho continua certo). Nenhuma = a própria `cell`.
static func _nav_snap(sim: WorldSim, nav: Dictionary, cell: int, side: String) -> int:
	var sn := Balance.GVG_NAV_SNAP
	if sn <= 1:
		return cell
	var memo: Dictionary = nav.get_or_add("snap", {})
	var mk := Vector3i(cell, SIDES.find(side), _nav_mask(sim, side))
	if memo.has(mk):
		return memo[mk]
	var r := _nav_snap_find(sim, nav, cell, side, sn)
	memo[mk] = r
	return r

static func _nav_snap_find(sim: WorldSim, nav: Dictionary, cell: int, side: String, sn: int) -> int:
	var w := int(nav["w"])
	var h := int(nav["h"])
	var grid: PackedByteArray = nav["grid"]
	var bx := (cell % w) / sn * sn
	var bz := (cell / w) / sn * sn
	var mid := (float(sn) - 1.0) * 0.5
	var target := _nav_center(nav, cell)
	var best := cell
	var best_d := INF
	for dz in sn:
		for dx in sn:
			var x := bx + dx
			var z := bz + dz
			if x >= w or z >= h:
				continue
			var i := z * w + x
			if not _nav_pass(sim, grid[i], side):
				continue
			var d := (float(dx) - mid) * (float(dx) - mid) + (float(dz) - mid) * (float(dz) - mid)
			if d < best_d and (i == cell or _nav_los(sim, nav, _nav_center(nav, i), target, side)):
				best_d = d
				best = i
	return best

## BFS de verdade (conta no orçamento do passo; despeja o campo menos usado).
static func _nav_build(sim: WorldSim, m: Dictionary, nav: Dictionary, dest: int, side: String, mask: int, key: String) -> PackedInt32Array:
	var fields: Dictionary = m["gvg_fields"]
	while fields.size() >= Balance.GVG_NAV_FIELDS:
		fields.erase(fields.keys()[0])
	if not sim.gvg.is_empty():
		var run := sim.gvg
		if float(run.get("nav_tick", -1.0)) != sim.time:
			run["nav_tick"] = sim.time
			run["nav_n"] = 0
		run["nav_n"] = int(run["nav_n"]) + 1
		run["nav_peak"] = maxi(int(run.get("nav_peak", 0)), int(run["nav_n"]))
		run["stats"]["nav_builds"] = int(run["stats"].get("nav_builds", 0)) + 1
	var grid: PackedByteArray = nav["grid"]
	var w := int(nav["w"])
	var n := grid.size()
	var opens: Dictionary = m.get_or_add("gvg_open", {})
	var ok_key := "%s|%d" % [side, mask]
	if not opens.has(ok_key):
		var ok := PackedByteArray()
		ok.resize(n)
		for i in n:
			var c := grid[i]
			ok[i] = 1 if c == 1 or (c >= 2 and (mask & (1 << (c - 2))) == 0) else 0
		opens[ok_key] = ok
	var open_ok: PackedByteArray = opens[ok_key]
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(-1)
	var q := PackedInt32Array()
	q.resize(n)
	var head := 0
	var tail := 0
	dist[dest] = 0
	q[tail] = dest
	tail += 1
	while head < tail:
		var u := q[head]
		head += 1
		var du := dist[u] + 1
		var ux := u % w
		var v := u - w
		if v >= 0 and dist[v] < 0 and open_ok[v] == 1:
			dist[v] = du
			q[tail] = v
			tail += 1
		v = u + w
		if v < n and dist[v] < 0 and open_ok[v] == 1:
			dist[v] = du
			q[tail] = v
			tail += 1
		v = u - 1
		if ux > 0 and dist[v] < 0 and open_ok[v] == 1:
			dist[v] = du
			q[tail] = v
			tail += 1
		v = u + 1
		if ux < w - 1 and dist[v] < 0 and open_ok[v] == 1:
			dist[v] = du
			q[tail] = v
			tail += 1
	fields[key] = dist
	return dist

## Próximo ponto do caminho de `e` até `to` no campo da guerra (= `to` quando a linha reta serve ou não há caminho).
## Guardado por bot por GVG_NAV_REPATH_S s (sim.gvg["nav_wp"]).
static func waypoint(sim: WorldSim, e: SimEntity, to: Vector3) -> Vector3:
	if sim.gvg.is_empty() or e.map_id != str(sim.gvg["map_id"]) or not (e.gvg_side in SIDES):
		return to
	var cache: Dictionary = sim.gvg.get_or_add("nav_wp", {})
	# duas vagas por bot: o andar e o `_blocked` (alvo da briga) pedem destinos diferentes no mesmo pensamento
	var slots: Array = cache.get_or_add(e.id, [{}, {}])
	var s0: Dictionary = slots[0]
	var s1: Dictionary = slots[1]
	var si := 0
	if not s1.is_empty() and (s0.is_empty() or (s1["to"] as Vector3).distance_squared_to(to) < (s0["to"] as Vector3).distance_squared_to(to)):
		si = 1
	var c: Dictionary = slots[si]
	if not c.is_empty() and sim.time < float(c["t"]) and (c["to"] as Vector3).distance_squared_to(to) < 4.0 \
			and Vector2(e.position.x - (c["wp"] as Vector3).x, e.position.z - (c["wp"] as Vector3).z).length() > 1.0:
		return c["wp"]
	var near := not c.is_empty() and (c["to"] as Vector3).distance_to(to) <= Balance.GVG_NAV_SNAP * Balance.GVG_NAV_CELL
	if not near:                                  # destino novo: troca a vaga usada há mais tempo
		si = 1 if float(s0.get("used", -1.0)) > float(s1.get("used", -1.0)) else 0
	var wp := _waypoint(sim, e, to, true)
	if wp == Vector3.INF:
		# campo ainda na fila: segue o último ponto do mesmo destino (se não chegou nele) ou a linha reta; tenta de novo no próximo passo
		wp = to
		if near and Vector2(e.position.x - (c["wp"] as Vector3).x, e.position.z - (c["wp"] as Vector3).z).length() > 1.0:
			wp = c["wp"]
		slots[si] = {"t": sim.time, "to": c["to"] if near else to, "wp": wp, "used": sim.time}
		return wp
	slots[si] = {"t": sim.time + Balance.GVG_NAV_REPATH_S, "to": to, "wp": wp, "used": sim.time}
	return wp

## `budget` = campo pela fila (Vector3.INF = ainda não pronto); sem ele monta na hora (sondas, testes).
static func _waypoint(sim: WorldSim, e: SimEntity, to: Vector3, budget := false) -> Vector3:
	var m: Dictionary = sim.maps[e.map_id]
	var nav := _nav(sim, e.map_id)
	var side := e.gvg_side
	if _nav_los(sim, nav, e.position, to, side):
		return to
	var aa := _nav_free_near(sim, nav, e.position, side)
	var bb := _nav_free_near(sim, nav, to, side)
	if aa.is_empty() or bb.is_empty():
		return to
	var a: int = aa[0]
	var dist := PackedInt32Array()
	var tried := {}
	for k in mini(bb.size(), 4):                 # destino dentro de portão fechado: a célula livre do lado de cá
		var dc := _nav_snap(sim, nav, int(bb[k]), side)     # vizinhos dividem o campo (bloco de GVG_NAV_SNAP células)
		if tried.has(dc):
			continue
		tried[dc] = true
		dist = _nav_field(sim, m, nav, dc, side, budget)
		if dist.is_empty():
			return Vector3.INF
		if dist[a] >= 0:
			break
	if dist.is_empty() or dist[a] < 0:
		return to
	var w := int(nav["w"])
	var grid: PackedByteArray = nav["grid"]
	var n := dist.size()
	# desce o campo até GVG_NAV_LOOKAHEAD células (vizinhos na ordem N, S, O, L e diagonais; empate = o primeiro)
	var path := PackedInt32Array()
	path.resize(Balance.GVG_NAV_LOOKAHEAD)
	var np := 0
	var cur := a
	while np < Balance.GVG_NAV_LOOKAHEAD and dist[cur] != 0:
		var nxt := -1
		var cx := cur % w
		for j in 8:
			var v := -1
			match j:
				0: v = cur - w
				1: v = cur + w
				2: v = cur - 1 if cx > 0 else -1
				3: v = cur + 1 if cx < w - 1 else -1
				4: v = cur - w - 1 if cx > 0 else -1
				5: v = cur - w + 1 if cx < w - 1 else -1
				6: v = cur + w - 1 if cx > 0 else -1
				7: v = cur + w + 1 if cx < w - 1 else -1
			if v >= 0 and v < n and dist[v] >= 0 and dist[v] < dist[cur] and (nxt < 0 or dist[v] < dist[nxt]) and _nav_pass(sim, grid[v], side):
				nxt = v
		if nxt < 0:
			break
		cur = nxt
		path[np] = cur
		np += 1
	if np == 0:
		return to
	# o mais longe que se vê em linha reta, de trás para a frente (no trecho reto o 1º teste já serve)
	var best := path[0]                      # nem o 1º passo se vê (canto): vai a ele assim mesmo
	for k in range(np - 1, 0, -1):
		if _nav_los(sim, nav, e.position, _nav_center(nav, path[k]), side):
			best = path[k]
			break
	if dist[best] == 0:
		return to
	return _nav_center(nav, best)

# ---------------------------------------------------------------------------
# HUD (Sim.gvg_status)

static func status(sim: WorldSim) -> Dictionary:
	var run := sim.gvg
	if run.is_empty():
		return {}
	var gates := {}
	for k in GATES:
		gates[k] = hp_pct(sim, k)
	var cannons: Array = []
	for o: Dictionary in run["objects"]:
		if o["type"] == "cannon":
			cannons.append({"id": o["id"], "key": o["key"], "side_owner": o["side_owner"], "operator_id": o["operator_id"], "cd": o["cd"], "pos": o["pos"]})
	var p := sim.player
	var ps: String = run["player_side"]
	var phase := str(run["phase"])
	return {"phase": phase, "time_left": maxf(0.0, float(run["prep_left"] if phase == "prep" else run["time_left"])),
		"prep_left": maxf(0.0, float(run["prep_left"])), "fight_left": maxf(0.0, float(run["time_left"])),
		"attacker": run["attacker"], "defender": run["defender"], "player_side": ps, "gates": gates,
		"crystal_N": hp_pct(sim, "crystal_N"), "crystal_S": hp_pct(sim, "crystal_S"),
		"plan": {"N": run["sides"]["N"]["plan"], "S": run["sides"]["S"]["plan"]},
		"order": {"N": (run["sides"]["N"]["order"] as Dictionary).duplicate(), "S": (run["sides"]["S"]["order"] as Dictionary).duplicate()},
		"commander": {"N": run["sides"]["N"]["commander_id"], "S": run["sides"]["S"]["commander_id"]},
		"player_commands": bool(run["sides"][ps]["player_commands"]),
		"score": {"kills_N": run["sides"]["N"]["kills"], "kills_S": run["sides"]["S"]["kills"], "dead_N": run["sides"]["N"]["dead"],
			"dead_S": run["sides"]["S"]["dead"], "rams_lost": run["sides"][str(run["attacker"])]["rams_lost"]},
		"cannons": cannons, "hill": run["hill"], "forward": run["forward"],
		"names": {"N": run["sides"]["N"]["guild_name"], "S": run["sides"]["S"]["guild_name"]},
		"tags": {"N": run["sides"]["N"]["tag"], "S": run["sides"]["S"]["tag"]},
		"respawn_in": float((run["respawn"] as Dictionary).get(p.id, 0.0)) if p else 0.0,
		"operating": int(((run["operating"] as Dictionary).get(p.id, {}) as Dictionary).get("id", -1)) if p else -1,
		"winner": run["winner"], "reason": run["reason"], "summary": (run.get("summary", {}) as Dictionary).duplicate(),
		"end_left": maxf(0.0, float(run["end_left"])), "map": run["map_id"]}

# ---------------------------------------------------------------------------
# SAVE (campo opcional `gvg` + `war_insignias` no personagem). A guerra em andamento não vai: conta como derrota (§5).

static func to_save(sim: WorldSim) -> Dictionary:
	var meta := _meta(sim)
	var o := {"v": 1, "wins": int(meta["wins"]), "losses": int(meta["losses"]), "vs": (meta["vs"] as Dictionary).duplicate(true),
		"owned": (meta["owned"] as Dictionary).keys(), "banner": meta["banner"], "crest": meta["crest"]}
	if running(sim) and str(sim.gvg["phase"]) != "end":
		o["losses"] = int(o["losses"]) + 1                 # fechar no meio = derrota
		var gid := str(sim.gvg["enemy_guild"])
		if gid != "":
			var vs: Dictionary = (o["vs"] as Dictionary).get_or_add(gid, {"wins": 0, "losses": 0, "taken": false})
			vs["losses"] = int(vs.get("losses", 0)) + 1
	return o

static func from_save(sim: WorldSim, d: Dictionary) -> void:
	sim.gvg_meta.clear()
	var meta := _meta(sim)
	var o: Dictionary = d.get("gvg", {}) if d.get("gvg") is Dictionary else {}
	if o.is_empty():
		return
	meta["wins"] = maxi(0, int(o.get("wins", 0)))
	meta["losses"] = maxi(0, int(o.get("losses", 0)))
	var vs: Dictionary = o.get("vs", {}) if o.get("vs") is Dictionary else {}
	for gid in vs:
		if vs[gid] is Dictionary:
			meta["vs"][str(gid)] = {"wins": int(vs[gid].get("wins", 0)), "losses": int(vs[gid].get("losses", 0)), "taken": bool(vs[gid].get("taken", false))}
	for k in (o.get("owned", []) if o.get("owned") is Array else []):
		if Balance.GVG_SHOP.has(str(k)):
			meta["owned"][str(k)] = true
	meta["banner"] = str(o.get("banner", ""))
	meta["crest"] = str(o.get("crest", ""))

## Lugar que o save grava estando na guerra: de onde o jogador veio.
static func save_place(sim: WorldSim, p: SimEntity) -> Dictionary:
	var fp: Vector3 = sim.gvg.get("from_pos", p.position)
	return {"map": str(sim.gvg.get("from_map", p.map_id)), "pos": [fp.x, fp.z]}

# ---------------------------------------------------------------------------
# LOJA DE GUERRA (Intendente das Caçadas, aba "Guerra")

static func shop_rows(sim: WorldSim, e: SimEntity) -> Array:
	var meta := _meta(sim)
	var out: Array = []
	var ids: Array = Balance.GVG_SHOP.keys()
	for id in ids:
		var it: Dictionary = Balance.GVG_SHOP[id]
		var why := ""
		var owned := (meta["owned"] as Dictionary).has(id)
		if owned:
			why = "Você já tem"
		elif e == null or e.war_insignias < int(it["price"]):
			why = "Faltam %d insígnias" % (int(it["price"]) - (e.war_insignias if e else 0))
		out.append({"id": id, "name": it["name"], "price": int(it["price"]), "kind": it["kind"], "ok": why == "", "why": why, "owned": owned,
			"color": it.get("color", Color.WHITE), "in_use": meta["banner"] == id or meta["crest"] == id})
	return out

static func owns(sim: WorldSim, id: String) -> bool:
	return (_meta(sim)["owned"] as Dictionary).has(id)

static func buy(sim: WorldSim, e: SimEntity, id: String) -> String:
	if e == null:
		return "Indisponível agora."
	for r: Dictionary in shop_rows(sim, e):
		if r["id"] != id:
			continue
		if not r["ok"]:
			return str(r["why"])
		var it: Dictionary = Balance.GVG_SHOP[id]
		var meta := _meta(sim)
		e.war_insignias -= int(it["price"])
		meta["owned"][id] = true
		match str(it["kind"]):
			"banner":
				meta["banner"] = id                        # o castelo da guerra usa o último comprado
			"crest":
				meta["crest"] = id
			"title":
				var titles: Array = sim.social.get_or_add("titles", [])
				if not titles.has(str(it["title"])):
					titles.append(str(it["title"]))
		Events.post(&"mvp_changed", e.id)
		if e == sim.player:
			Events.post(&"notification", "Comprado: %s" % it["name"])
		return ""
	return "Fora da loja"
