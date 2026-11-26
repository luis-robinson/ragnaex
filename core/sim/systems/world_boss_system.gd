class_name WorldBossSystem
extends RefCounted
## Chefes de Mundo com hora marcada (GDD design/gdd/momentos-do-mundo.md §3.1, §4, §5, §9; contrato
## production/session-state/wave5-contract.md A). Um por faixa (MonstersCatalog.WORLD_BOSSES), no lugar fixo da zona.
##  - relógio por faixa: WORLD_BOSS_EVERY × (ROLL.x + ROLL.y × sorteio) min, que só anda com o jogador no ATO da faixa;
##  - aviso WORLD_BOSS_WARN_S s antes no chat de todos os mapas (+ marca no mapa e contagem no HUD), depois nasce;
##  - um chefe de mundo por vez; cerco/investida no mapa dele = espera (tenta de novo a cada WORLD_BOSS_HOLD_S);
##  - bots da faixa (± WORLD_BOSS_BOT_SLACK) no mapa ou a 1 portal vão até ele (BotBrain._world_boss);
##  - prêmio igual (§9.3): todo mundo com dano+cura >= SHARE_MIN × vida / participantes ganha a XP do chefe (regra de
##    nível de sempre); o resto (moedas, baú, pergaminhos, carta, montaria) é do MvpSystem.award (se existir);
##  - some em WORLD_BOSS_LIFE min com fala de despedida; o save guarda os relógios (chefe vivo/avisado volta avisado).
## Estado em sim.world_boss: {rng, bands {id: {left}}, warn {boss, left}, active {boss, id, map, at, left, heal {id: n}}}.

static func _ensure(sim: WorldSim) -> Dictionary:
	var st := sim.world_boss
	if not st.has("rng"):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([sim.rng.seed, "world_boss"])      # sorteio próprio: não gasta o rng da sim (somas das sondas iguais)
		st["rng"] = rng
	if not st.has("bands"):
		st["bands"] = {}
	for bid in MonstersCatalog.WORLD_BOSSES:
		if not (st["bands"] as Dictionary).has(bid):
			st["bands"][bid] = {"left": roll(st["rng"])}
	if not st.has("warn"):
		st["warn"] = {}
	if not st.has("active"):
		st["active"] = {}
	return st

## Próximo nascimento em s de jogo (§4).
static func roll(rng: RandomNumberGenerator) -> float:
	return Balance.WORLD_BOSS_EVERY * 60.0 * (Balance.WORLD_BOSS_ROLL.x + Balance.WORLD_BOSS_ROLL.y * rng.randf())

## Ato pelo topo de uma faixa de níveis: 1 (até 30), 2 (até 45), 3.
static func act_of_top(top: int) -> int:
	var tops: Array = Balance.WORLD_BOSS_ACT_TOPS
	for i in tops.size():
		if top <= int(tops[i]):
			return i + 1
	return tops.size() + 1

static func act_of_boss(bid: String) -> int:
	var band: Array = MonstersCatalog.WORLD_BOSSES[bid]["band"]
	return act_of_top(int(band[1]))

## Ato do mapa (masmorra/casa = o da zona de fora).
static func act_of_map(map_id: String) -> int:
	var def: MapDef = GameData.maps.get(map_id)
	var guard := 0
	while def != null and def.parent_map != "" and GameData.maps.has(def.parent_map) and guard < 4:
		def = GameData.maps[def.parent_map]
		guard += 1
	return act_of_top(def.level_range.y) if def != null else 0

static func tick(sim: WorldSim, dt: float) -> void:
	if sim.player == null:
		return
	var st := _ensure(sim)
	var act := act_of_map(sim.player.map_id)
	var a: Dictionary = st["active"]
	if not a.is_empty():
		_update_active(sim, st, a, dt)
	var w: Dictionary = st["warn"]
	if not w.is_empty():
		w["left"] = float(w["left"]) - dt
		if float(w["left"]) <= 0.0:
			if blocked(sim, str(w["boss"])):
				w["left"] = Balance.WORLD_BOSS_HOLD_S
			else:
				spawn(sim, str(w["boss"]))
		return
	for bid in st["bands"]:
		if act_of_boss(bid) != act:
			continue                                 # fora do ato da faixa: o relógio dela não anda
		var b: Dictionary = st["bands"][bid]
		b["left"] = maxf(0.0, float(b["left"]) - dt)
	if not (st["active"] as Dictionary).is_empty():
		return                                       # um por vez: quem chegou a 0 espera
	for bid in st["bands"]:
		if act_of_boss(bid) == act and float(st["bands"][bid]["left"]) <= 0.0:
			warn(sim, bid)
			return

## Outro chefe de mundo vivo, mapa fora do mundo ou cerco/investida no mapa dele (§5): espera.
static func blocked(sim: WorldSim, bid: String) -> bool:
	if not (sim.world_boss.get("active", {}) as Dictionary).is_empty():
		return true
	var map_id := str(MonstersCatalog.WORLD_BOSSES[bid]["map"])
	if not sim.maps.has(map_id):
		return true
	var m: Dictionary = sim.maps[map_id]
	return RoadEventSystem.raid_on(m) or not ((m.get("raid", {}) as Dictionary).get("ids", []) as Array).is_empty() or not ((m.get("siege", {}) as Dictionary).get("shooters", []) as Array).is_empty()     # leva de cerco = rota de investida; assédio = atiradores

## Aviso WORLD_BOSS_WARN_S s antes: chat de todos os mapas; o relógio da faixa recomeça já.
static func warn(sim: WorldSim, bid: String, seconds: float = -1.0) -> void:
	var st := _ensure(sim)
	if seconds < 0.0:
		seconds = Balance.WORLD_BOSS_WARN_S
	st["warn"] = {"boss": bid, "left": seconds}
	st["bands"][bid]["left"] = roll(st["rng"])
	var map_id := str(MonstersCatalog.WORLD_BOSSES[bid]["map"])
	Events.post(&"chat_message", "Sistema", str(MomentsCatalog.WORLD_BOSS_LINES.get(bid, {}).get("warn", "Um Chefe de Mundo vai despertar!")), "system")
	Events.post(&"world_boss_warning", bid, map_id, seconds)

## Nasce agora no lugar dele (também a sonda/testes/--moments_shot). Devolve o chefe (null = não deu).
static func spawn(sim: WorldSim, bid: String) -> SimEntity:
	var st := _ensure(sim)
	var wb: Dictionary = MonstersCatalog.WORLD_BOSSES.get(bid, {})
	var mdef: MonsterDef = GameData.monsters.get(bid)
	var map_id := str(wb.get("map", ""))
	if mdef == null or not sim.maps.has(map_id) or not (st["active"] as Dictionary).is_empty():
		return null
	var at := spot(bid)
	var e := sim.spawn_monster(mdef, map_id, at)
	e.world_boss = true
	e.home_position = at
	st["warn"] = {}
	st["active"] = {"boss": bid, "id": e.id, "map": map_id, "at": at, "left": Balance.WORLD_BOSS_LIFE * 60.0, "heal": {}}
	Events.post(&"chat_message", "Sistema", str(MomentsCatalog.WORLD_BOSS_LINES.get(bid, {}).get("spawn", "%s apareceu!" % mdef.name)), "system")
	Events.post(&"world_boss_spawned", bid, map_id)
	_bots_shout(sim, st, e, MomentsCatalog.WORLD_BOSS_BOT_GO)
	return e

static func spot(bid: String) -> Vector3:
	var at: Array = MonstersCatalog.WORLD_BOSSES[bid]["at"]
	return Vector3(float(at[0]), 0.0, float(at[1]))

static func _update_active(sim: WorldSim, st: Dictionary, a: Dictionary, dt: float) -> void:
	var e: SimEntity = sim.entities.get(int(a["id"]))
	if e == null or not e.is_alive():
		st["active"] = {}                            # sumiu por fora (troca de mundo, teste): libera
		return
	a["left"] = float(a["left"]) - dt
	if float(a["left"]) <= 0.0:
		despawn(sim, "life")

## Some sem morrer (fim da vida ou limpeza): fala de despedida, leva os lacaios junto.
static func despawn(sim: WorldSim, why: String = "life") -> void:
	var st := _ensure(sim)
	var a: Dictionary = st["active"]
	if a.is_empty():
		return
	st["active"] = {}
	var e: SimEntity = sim.entities.get(int(a["id"]))
	if e != null:
		var m: Dictionary = sim.maps.get(e.map_id, {})
		for o: SimEntity in (m.get("entities", []) as Array).duplicate():
			if o.kind == SimEntity.Kind.MONSTER and o.boss_id == e.id:
				sim.despawn(o)
		sim.despawn(e)
	if why == "life":
		Events.post(&"chat_message", "Sistema", str(MomentsCatalog.WORLD_BOSS_LINES.get(str(a["boss"]), {}).get("farewell", "")), "system")
	Events.post(&"world_boss_despawned", str(a["boss"]), str(a["map"]))

## Cura que conta para a participação (WorldSim._heal): curado no mapa do chefe, a até WORLD_BOSS_SHARE_RANGE m dele.
static func on_heal(sim: WorldSim, src: SimEntity, target: SimEntity, amount: float) -> void:
	var a: Dictionary = sim.world_boss.get("active", {})
	if a.is_empty() or amount <= 0.0 or not src.is_character() or target.map_id != str(a["map"]):
		return
	var e: SimEntity = sim.entities.get(int(a["id"]))
	if e == null or target.position.distance_squared_to(e.position) > Balance.WORLD_BOSS_SHARE_RANGE * Balance.WORLD_BOSS_SHARE_RANGE:
		return
	a["heal"][src.id] = float((a["heal"] as Dictionary).get(src.id, 0.0)) + amount

## Contribuição de cada um (dano no chefe + cura na luta): {id: valor}.
static func contributions(sim: WorldSim, boss: SimEntity) -> Dictionary:
	var out := {}
	for id in boss.damage_by:
		out[id] = float(boss.damage_by[id])
	var a: Dictionary = sim.world_boss.get("active", {})
	if not a.is_empty() and int(a["id"]) == boss.id:
		for id in a["heal"]:
			out[id] = float(out.get(id, 0.0)) + float(a["heal"][id])
	return out

## Quem passou do mínimo (§4): valor >= SHARE_MIN × vida / participantes (participante = quem fez algo > 0).
static func qualifies(contrib: Dictionary, boss_hp: float) -> Array:
	var n := 0
	for id in contrib:
		if float(contrib[id]) > 0.0:
			n += 1
	var out: Array = []
	if n == 0:
		return out
	var need := Balance.WORLD_BOSS_SHARE_MIN * boss_hp / float(n)
	for id in contrib:
		if float(contrib[id]) > 0.0 and float(contrib[id]) >= need:
			out.append(int(id))
	out.sort()
	return out

## Chefe de mundo do evento caiu (LootSystem.on_monster_killed): XP igual a quem participou, evento e MvpSystem.award.
static func on_boss_killed(sim: WorldSim, mob: SimEntity, _killer: SimEntity) -> void:
	var st := _ensure(sim)
	var a: Dictionary = st["active"]
	var contrib := contributions(sim, mob)
	var ids: Array = []
	for id in qualifies(contrib, mob.stats.max_hp):
		var c: SimEntity = sim.entities.get(id)
		if c != null and c.is_character():
			ids.append(id)
	var bid := mob.monster_def.id
	for id in ids:
		var c: SimEntity = sim.entities[id]
		var mult := clampf(1.0 + (mob.level - c.level) * 0.08, 0.3, 1.6)       # a regra de nível de sempre (§5)
		ProgressionSystem.gain_xp(sim, c, int(mob.monster_def.xp * Balance.WORLD_BOSS_XP_MULT * mult))
		QuestSystem.on_kill(c, bid)
		c.bosses_killed[bid] = true
	if not a.is_empty() and int(a["id"]) == mob.id:
		st["active"] = {}
	st["last"] = {"boss": bid, "participants": ids.duplicate(), "contrib": contrib.size()}
	Events.post(&"chat_message", "Sistema", str(MomentsCatalog.WORLD_BOSS_LINES.get(bid, {}).get("killed", "%s caiu!" % mob.name)), "system")
	Events.post(&"world_boss_killed", bid, ids)
	var mvp := mvp_script()
	if mvp != null:
		mvp.call("award", sim, bid, ids)
	_bots_shout(sim, st, mob, MomentsCatalog.WORLD_BOSS_BOT_WON, ids)

## MvpSystem (agente dos prêmios) se existir: o contrato deixa qualquer um dos dois chegar primeiro.
static func mvp_script() -> Script:
	for c in ProjectSettings.get_global_class_list():
		if str(c["class"]) == "MvpSystem":
			return load(str(c["path"])) as Script
	return null

## Uns poucos bots da faixa falam no chat (mundo vivo).
static func _bots_shout(sim: WorldSim, st: Dictionary, boss: SimEntity, lines: Array, only: Array = []) -> void:
	var rng: RandomNumberGenerator = st["rng"]
	var said := 0
	for id in (only if not only.is_empty() else sim.entities.keys()):
		var b: SimEntity = sim.entities.get(id)
		if b == null or b.kind != SimEntity.Kind.BOT or not b.is_alive():
			continue
		if only.is_empty() and not eligible(sim, b, boss):
			continue
		if rng.randf() < Balance.WORLD_BOSS_BOT_SHOUT and said < 3:
			said += 1
			Events.post(&"chat_message", b.name, str(lines[rng.randi() % lines.size()]).format({"boss": boss.monster_def.name}), "global")

## O bot vai ao chefe? Da faixa (± SLACK), no mapa dele ou a 1 portal, fora do grupo do jogador.
static func eligible(sim: WorldSim, e: SimEntity, boss: SimEntity) -> bool:
	var band: Array = MonstersCatalog.WORLD_BOSSES[boss.monster_def.id]["band"]
	if e.level < int(band[0]) - Balance.WORLD_BOSS_BOT_SLACK or e.level > int(band[1]) + Balance.WORLD_BOSS_BOT_SLACK:
		return false
	if sim.player != null and e.party_id >= 0 and e.party_id == sim.player.party_id:
		return false                                 # o grupo do jogador segue o jogador
	if e.map_id == boss.map_id:
		return true
	var def: MapDef = GameData.maps.get(e.map_id)
	if def == null or def.instance:
		return false
	for p in def.portals:
		if str(p.get("target_map", "")) == boss.map_id:
			return true
	return false

## Chefe de mundo para onde este bot vai agora (null = nenhum). Barato: sem chefe vivo devolve logo.
static func bot_goal(sim: WorldSim, e: SimEntity) -> SimEntity:
	var a: Dictionary = sim.world_boss.get("active", {})
	if a.is_empty():
		return null
	var boss: SimEntity = sim.entities.get(int(a["id"]))
	if boss == null or not boss.is_alive() or not eligible(sim, e, boss):
		return null
	return boss

## Resumo (contrato A): {active, boss, map, at [x, z], warn_until, next_in, hp_pct} (+ left, name, warned, place).
static func status(sim: WorldSim) -> Dictionary:
	var st := sim.world_boss
	var out := {"active": false, "boss": "", "map": "", "at": [0.0, 0.0], "warn_until": 0.0, "next_in": 0.0, "hp_pct": 0.0,
		"left": 0.0, "name": "", "warned": false, "place": ""}
	if not st.has("bands"):
		return out
	var a: Dictionary = st.get("active", {})
	var w: Dictionary = st.get("warn", {})
	var bid := ""
	if not a.is_empty():
		bid = str(a["boss"])
		var e: SimEntity = sim.entities.get(int(a["id"]))
		out["active"] = true
		out["left"] = float(a["left"])
		if e != null:
			out["at"] = [e.position.x, e.position.z]
			out["hp_pct"] = e.hp / maxf(1.0, e.stats.max_hp)
	elif not w.is_empty():
		bid = str(w["boss"])
		out["warned"] = true
		out["warn_until"] = sim.time + float(w["left"])
		out["next_in"] = float(w["left"])
		var sp := spot(bid)
		out["at"] = [sp.x, sp.z]
	else:
		var best := INF
		for b in st["bands"]:
			var t: float = float(st["bands"][b]["left"]) + Balance.WORLD_BOSS_WARN_S
			if t < best:
				best = t
		out["next_in"] = best
	if bid != "":
		out["boss"] = bid
		out["map"] = str(MonstersCatalog.WORLD_BOSSES[bid]["map"])
		var md: MonsterDef = GameData.monsters.get(bid)
		out["name"] = md.name if md != null else bid
		out["place"] = str(MomentsCatalog.WORLD_BOSS_LINES.get(bid, {}).get("place", ""))
	return out

## Save (campo opcional "world_boss"): relógios das faixas; chefe vivo ou avisado volta AVISADO (nasce de novo no load).
static func to_save(sim: WorldSim) -> Dictionary:
	var st := _ensure(sim)
	var bands := {}
	for bid in st["bands"]:
		bands[bid] = float(st["bands"][bid]["left"])
	var pending := ""
	if not (st["active"] as Dictionary).is_empty():
		pending = str(st["active"]["boss"])
	elif not (st["warn"] as Dictionary).is_empty():
		pending = str(st["warn"]["boss"])
	return {"v": 1, "bands": bands, "pending": pending}

static func from_save(sim: WorldSim, d: Dictionary) -> void:
	sim.world_boss.clear()
	var st := _ensure(sim)
	var o: Dictionary = d.get("world_boss", {}) if d.get("world_boss") is Dictionary else {}
	var bands: Dictionary = o.get("bands", {}) if o.get("bands") is Dictionary else {}
	for bid in bands:
		if (st["bands"] as Dictionary).has(str(bid)):
			st["bands"][str(bid)]["left"] = clampf(float(bands[bid]), 0.0, Balance.WORLD_BOSS_EVERY * 60.0 * (Balance.WORLD_BOSS_ROLL.x + Balance.WORLD_BOSS_ROLL.y))
	var pending := str(o.get("pending", ""))
	if MonstersCatalog.WORLD_BOSSES.has(pending):
		st["warn"] = {"boss": pending, "left": Balance.WORLD_BOSS_WARN_S}
