class_name NpcSystem
extends RefCounted
## NPCs que passeiam (MapsCatalog.VILLAGERS) e param para conversar.

## A janela de conversa aberta segura o NPC (a apresentação chama a cada quadro).
static func hold_npc(sim: WorldSim, npc_id: String) -> void:
	if sim.player == null or not sim.maps.has(sim.player.map_id):
		return
	for o: SimEntity in sim.maps[sim.player.map_id]["entities"]:
		if o.kind == SimEntity.Kind.NPC and o.npc_data.get("id", "") == npc_id:
			if o.npc_hold <= 0.0:
				o.face_towards(sim.player.position)
			o.npc_hold = Balance.NPC_TALK_HOLD
			npc_stop(sim, o)

## Morador que passeia: `wander` = raio em volta de casa, `route` = ronda por pontos [[x, z], ...].
## Sem nenhum dos dois o NPC fica no posto (serviços, pescador na vara): depois da conversa volta a olhar para `facing`.
static func update_npc(sim: WorldSim, e: SimEntity, m: Dictionary, dt: float) -> void:
	var nd := e.npc_data
	if not nd.has("wander") and not nd.has("route"):
		if e.npc_hold > 0.0:
			e.npc_hold -= dt
			if e.npc_hold <= 0.0 and nd.has("facing"):
				e.facing = deg_to_rad(float(nd["facing"]))
		return
	if e.npc_hold > 0.0:
		e.npc_hold -= dt
		return
	if nd.has("alarm"):                      # faixa élfica viva: leva viva no mapa = corre para o abrigo e fica lá
		var on := alarm_on(sim, m)
		if on != e.npc_alarm:
			e.npc_alarm = on
			e.npc_goal = npc_next_goal(sim, e, m["def"])
			e.npc_wait = 0.0
			e.npc_stuck = 0.0
		if on and e.position.distance_to(e.npc_goal) < 0.35:
			npc_stop(sim, e)
			return
	if e.npc_wait > 0.0:
		e.npc_wait -= dt
		if e.npc_wait <= 0.0:
			e.npc_goal = npc_next_goal(sim, e, m["def"])
			e.npc_stuck = 0.0
		return
	if e.npc_goal == Vector3.ZERO:
		e.npc_goal = npc_next_goal(sim, e, m["def"])
	var to := e.npc_goal - e.position
	to.y = 0.0
	if to.length() < 0.35:
		npc_stop(sim, e)
		e.npc_wait = sim.rng.randf_range(Balance.NPC_WAIT_MIN, Balance.NPC_WAIT_MAX)
		if nd.has("route"):
			e.npc_wait *= 0.4                  # ronda: para pouco
			var pts: Array = nd["route"]
			var at: Array = pts[(e.npc_leg - 1 + pts.size()) % pts.size()] if e.npc_leg > 0 else []
			if at.size() > 2:                  # ponto com parada própria [x, z, s] (carroça descarregando)
				e.npc_wait = float(at[2])
			elif nd.get("flow", false):        # rota de estrada: não para nos pontos de passagem
				e.npc_wait = 0.02
		return
	var step := to.normalized() * minf(to.length(), Balance.NPC_WALK_SPEED * dt)
	var before := e.position
	sim._move(e, step, m)
	var moved := e.position - before
	moved.y = 0.0
	e.velocity = moved / maxf(dt, 0.0001)
	e.face_towards(e.position + step)
	if e.state != SimEntity.State.MOVING:
		e.set_state(SimEntity.State.MOVING)
	if moved.length() < step.length() * 0.3:   # travou num canto: desiste deste ponto
		e.npc_stuck += dt
		if e.npc_stuck > 1.2:
			npc_stop(sim, e)
			e.npc_wait = 1.0
	else:
		e.npc_stuck = 0.0

## Alarme do povoado (GDD elf-band-living §3.2): alguma leva de investida/cerco viva no mapa. Uma conta por mapa por instante
## da sim (cache em m["alarm_at"]/m["alarm_on"]); não gasta sim.rng.
static func alarm_on(sim: WorldSim, m: Dictionary) -> bool:
	if float(m.get("alarm_at", -1.0)) != sim.time:
		m["alarm_at"] = sim.time
		m["alarm_on"] = RoadEventSystem.raid_on(m)
	return bool(m["alarm_on"])

static func npc_stop(sim: WorldSim, e: SimEntity) -> void:
	e.velocity = Vector3.ZERO
	if e.state != SimEntity.State.IDLE:
		e.set_state(SimEntity.State.IDLE)

static func npc_next_goal(sim: WorldSim, e: SimEntity, def: MapDef) -> Vector3:
	var nd := e.npc_data
	var home: Vector3 = nd.get("pos", e.position)
	if e.npc_alarm and nd.has("alarm"):
		return Vector3(float(nd["alarm"][0]), 0.0, float(nd["alarm"][1]))
	if nd.has("route"):
		var pts: Array = nd["route"]
		var p: Array = pts[e.npc_leg % pts.size()]
		e.npc_leg += 1
		return Vector3(float(p[0]), 0.0, float(p[1]))
	return MapGeometry.random_walkable(sim, def, home, float(nd["wander"]))
