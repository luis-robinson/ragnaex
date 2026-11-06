class_name WorldState
extends RefCounted
## Mundo que muda com a conquista (por personagem: lê `player.quests_completed`, sem campo novo no save).
## - Spawner, NPC, rota de investida e assalto aceitam `if` (quest feita) e `unless` (quest ainda não feita);
##   valor = id de quest ou lista de ids (todas). Sem jogador (testes/servidor) nenhuma quest conta como feita.
## - Spawner que deixa de valer recolhe os monstros dele (fortaleza retomada esvazia); NPC condicional nasce/some.
## - Assalto aliado (`MapDef.assaults`): levas de NPCs lutadores (`fighter`) nascem em `from`, sobem a `route` até
##   `target` e brigam lá (GuardBrain, modo marcha); quem cai não volta, a leva se repõe a cada `every` s até `max`.

const SYNC_EVERY := 1.0

static func done(sim: WorldSim) -> Array:
	return sim.player.quests_completed if sim.player != null else []

## A entrada (spawner, NPC, rota) vale agora?
static func active(sim: WorldSim, d: Dictionary) -> bool:
	if not d.has("if") and not d.has("unless"):
		return true
	var q := done(sim)
	if d.has("if"):
		for id in _ids(d["if"]):
			if not q.has(id):
				return false
	if d.has("unless"):
		var all_done := true
		for id in _ids(d["unless"]):
			if not q.has(id):
				all_done = false
		if all_done:
			return false
	return true

static func _ids(v) -> Array:
	if v is Array:
		return (v as Array).map(func(x): return str(x))
	return [str(v)]

## Por mapa, a cada SYNC_EVERY s: NPCs condicionais, spawners que deixaram de valer e as levas aliadas.
static func update(sim: WorldSim, m: Dictionary, dt: float) -> void:
	m["ws_t"] = float(m.get("ws_t", 0.0)) - dt
	if float(m["ws_t"]) > 0.0:
		return
	m["ws_t"] = SYNC_EVERY
	sync_npcs(sim, m)
	for sp in m["spawners"]:
		if active(sim, sp["def"]):
			continue
		for id in sp["alive"] + sp.get("escort", []):
			var e: SimEntity = sim.entities.get(id)
			if e and e.aggro_target < 0:
				sim.despawn(e)
		sp["alive"] = sp["alive"].filter(func(id): return sim.entities.has(id))
		sp["timer"] = 0.5
		sp["primed"] = false
	update_assaults(sim, m, SYNC_EVERY)

## NPCs com `if`/`unless`: nasce quem passou a valer, some quem deixou de valer (índice no MapDef.npcs).
static func sync_npcs(sim: WorldSim, m: Dictionary) -> void:
	var def: MapDef = m["def"]
	var live: Dictionary = m.get("cond_npcs", {})
	m["cond_npcs"] = live
	for i in def.npcs.size():
		var n: Dictionary = def.npcs[i]
		if not (n.has("if") or n.has("unless")):
			continue
		var want := active(sim, n)
		var e: SimEntity = sim.entities.get(int(live.get(i, -1)))
		if want and e == null:
			live[i] = sim._spawn_npc(n, def.id).id
		elif not want and e != null:
			sim.despawn(e)
			live.erase(i)

# ----------------------------------------------------------------------------
# Assalto aliado
# ----------------------------------------------------------------------------
static func update_assaults(sim: WorldSim, m: Dictionary, dt: float) -> void:
	var def: MapDef = m["def"]
	if def.assaults.is_empty():
		return
	var st: Dictionary = m.get("assault", {})
	m["assault"] = st
	for i in def.assaults.size():
		var a: Dictionary = def.assaults[i]
		var s: Dictionary = st.get(i, {"ids": [], "timer": float(a.get("first", 4.0))})
		st[i] = s
		s["ids"] = (s["ids"] as Array).filter(func(id): return sim.entities.has(id) and sim.entities[id].is_alive())
		if not active(sim, a):
			continue
		s["timer"] = float(s["timer"]) - dt
		if float(s["timer"]) > 0.0 or (s["ids"] as Array).size() >= int(a.get("max", 8)):
			continue
		s["timer"] = float(a.get("every", 30.0))
		s["ids"].append_array(spawn_assault(sim, m, i))

## Solta uma leva aliada do assalto i agora; devolve os ids.
static func spawn_assault(sim: WorldSim, m: Dictionary, i: int) -> Array:
	var def: MapDef = m["def"]
	var a: Dictionary = def.assaults[i]
	var out: Array = []
	var k := 0
	for fid in a.get("fighters", {}):
		for j in int(a["fighters"][fid]):
			var mdef: MonsterDef = GameData.monsters.get(str(fid))
			if mdef == null:
				continue
			var n := {"id": "assault_%d_%d" % [i, k], "name": mdef.name, "role": "guard", "fighter": str(fid), "respawn": -1.0,
				"pos": MapGeometry.random_walkable(sim, def, a["from"], 3.0), "facing": 180.0, "color": Color(0.85, 0.82, 0.7),
				"march": (a.get("route", []) as Array) + [a["target"]], "march_radius": float(a.get("radius", 10.0))}
			k += 1
			var e := sim._spawn_npc(n, def.id)
			e.npc_data = n
			out.append(e.id)
	if not out.is_empty() and sim.player and sim.player.map_id == def.id and a.has("say"):
		Events.chat_message.emit("Sistema", str(a["say"]), "system")
	return out

## Ponto da marcha do aliado (GuardBrain): o próximo da rota; no fim, o alvo.
static func march_goal(e: SimEntity) -> Vector3:
	var route: Array = e.npc_data.get("march", [])
	if route.is_empty():
		return e.home_position
	e.raid_leg = clampi(e.raid_leg, 0, route.size() - 1)
	return route[e.raid_leg]

# ----------------------------------------------------------------------------
# Surtida da catedral (MapDef.sortie): investida chegou à muralha -> 20 soldados saem pela porta até o portão atacado
# ----------------------------------------------------------------------------
static func spawn_sortie(sim: WorldSim, m: Dictionary, route_i: int) -> Array:
	var def: MapDef = m["def"]
	var so: Dictionary = def.sortie
	var door: Vector3 = so["from"]
	var gate := RaidSystem.gate_point(def, route_i)
	var ga := atan2(gate.z - def.town_center.z, gate.x - def.town_center.x)
	var mid := def.town_center + Vector3(cos(ga), 0, sin(ga)) * 30.0          # anel da praça na direção do portão
	var out: Array = []
	var k := 0
	for fid in so.get("fighters", {}):
		var mdef: MonsterDef = GameData.monsters.get(str(fid))
		if mdef == null:
			continue
		for j in int(so["fighters"][fid]):
			var n := {"id": "sortie_%d" % k, "name": mdef.name, "role": "guard", "fighter": str(fid), "respawn": -1.0, "model": mdef.model,
				"pos": MapGeometry.random_walkable(sim, def, door, 3.0), "facing": 180.0, "color": Color(0.9, 0.88, 0.8),
				"march": [mid, gate], "march_radius": 10.0, "sortie": true}
			k += 1
			out.append(sim._spawn_npc(n, def.id).id)
	if sim.player and sim.player.map_id == def.id and so.has("say"):
		Events.chat_message.emit("Sistema", str(so["say"]), "system")
	return out

## Leva acabou: a surtida volta à porta e some ao chegar (ou em RAID_SORTIE_LINGER s).
static func end_sortie(sim: WorldSim, ids: Array) -> void:
	for id in ids:
		var e: SimEntity = sim.entities.get(id)
		if e == null or not e.is_alive():
			continue
		var door: Vector3 = (sim.maps[e.map_id]["def"] as MapDef).sortie.get("from", e.position)
		e.npc_data["march"] = [door]
		e.npc_data["march_radius"] = 1.0
		e.npc_data["sortie_return"] = true
		e.npc_data["sortie_left"] = Balance.RAID_SORTIE_LINGER
		e.raid_leg = 0
		e.aggro_target = -1
