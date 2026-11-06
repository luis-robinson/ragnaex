class_name GuardBrain
extends RefCounted
## Sentinela do povoado (NPC com `fighter`): defende o posto. Acha monstro perto do posto, luta sem sair
## mais que Balance.GUARD_LEASH de casa e volta à ronda (`route`/`wander` do NPC) quando acaba.

const SKILL_GAP := 2.5

var skill_timer: float = 0.0
var returning := false
# marcha (assalto, reforço, surtida): caminho pelas pontes e desvio quando trava (como MonsterBrain._steer)
var water_path: Array = []
var water_goal := Vector3.INF
var water_timer := 0.0
var last_pos := Vector3.ZERO
var stuck := 0.0
var detour := Vector2.ZERO
var detour_left := 0.0

func think(e: SimEntity, sim, m: Dictionary, dt: float) -> InputCommand:
	var cmd := InputCommand.new()
	cmd.aim = e.position + e.forward()
	skill_timer -= dt
	var mdef := e.monster_def
	var home := e.home_position
	if e.is_perched():                                # torre: só mira e atira no que chegar ao alcance
		var foe: SimEntity = Combat.nearest_hostile(e, m["entities"], mdef.attack_range)
		e.aggro_target = foe.id if foe else -1
		if foe:
			cmd.aim = foe.position
			cmd.attack = e.basic_cd <= 0.0 and e.can_act()
		return cmd
	if e.position.distance_to(home) > Balance.GUARD_LEASH:
		returning = true
	if returning:
		e.aggro_target = -1
		if e.position.distance_to(home) < 2.0:
			returning = false
		else:
			cmd.move = MonsterBrain._dir_to(e, home)
			cmd.aim = home
			return cmd
	# alvo: o que já tem, senão o monstro mais perto (que esteja perto do posto)
	var target: SimEntity = sim.entities.get(e.aggro_target) if e.aggro_target >= 0 else null
	if target and (not target.is_alive() or target.map_id != e.map_id or target.position.distance_to(home) > Balance.GUARD_LEASH + 2.0):
		target = null
	if target == null:
		var patrols: bool = e.npc_data.has("route") or e.npc_data.has("wander") or e.npc_data.has("march")
		target = Combat.nearest_hostile(e, m["entities"], Balance.GUARD_AGGRO)
		if target and not patrols and target.position.distance_to(home) > Balance.GUARD_LEASH + 2.0:
			target = null
		if target and patrols:
			e.home_position = e.position        # ronda: a âncora da luta é onde ela começou
		e.aggro_target = target.id if target else -1
	if target != null:
		var dist := e.position.distance_to(target.position) - target.radius
		cmd.aim = target.position
		if skill_timer <= 0.0 and e.can_act():
			for i in range(e.skills.size() - 1, -1, -1):
				var s: SkillDef = e.skills[i]
				if float(e.cooldowns.get(s.id, 0.0)) <= 0.0 and dist <= maxf(s.range, s.radius) + 0.3:
					cmd.skill_slot = i
					skill_timer = SKILL_GAP
					return cmd
		var reach := mdef.attack_range
		if dist <= reach * 0.85:
			if e.basic_cd <= 0.0 and e.can_act():
				cmd.attack = true
		elif not e.is_perched():
			cmd.move = MonsterBrain._dir_to(e, target.position)
		return cmd
	# sem luta: marcha do assalto, ronda/passeio do NPC, ou fica no posto
	var nd := e.npc_data
	if nd.has("march"):
		return _march(e, sim, m, cmd, dt)
	if nd.has("route") or nd.has("wander"):
		if e.npc_wait > 0.0:
			e.npc_wait -= dt
			return cmd
		if e.npc_goal == Vector3.ZERO or e.position.distance_to(e.npc_goal) < 0.6:
			if e.npc_goal != Vector3.ZERO:
				e.npc_wait = sim.rng.randf_range(Balance.NPC_WAIT_MIN, Balance.NPC_WAIT_MAX) * 0.4
			e.npc_goal = NpcSystem.npc_next_goal(sim, e, m["def"])
			return cmd
		cmd.move = MonsterBrain._dir_to(e, e.npc_goal) * Balance.GUARD_PATROL_PACE
		cmd.aim = e.npc_goal
	elif e.position.distance_to(home) > 0.8:
		cmd.move = MonsterBrain._dir_to(e, home) * Balance.GUARD_PATROL_PACE
		cmd.aim = home
	else:
		cmd.aim = e.position + Vector3(sin(deg_to_rad(float(nd.get("facing", 180.0)))), 0, cos(deg_to_rad(float(nd.get("facing", 180.0)))))
	return cmd

## Leva de assalto (WorldState.assaults): sobe a rota com a âncora junto; no alvo, ronda o pátio procurando briga.
func _march(e: SimEntity, sim, m: Dictionary, cmd: InputCommand, dt: float) -> InputCommand:
	e.home_position = e.position
	if e.npc_data.get("sortie_return", false):        # surtida voltando: some na porta da catedral (ou no tempo)
		e.npc_data["sortie_left"] = float(e.npc_data.get("sortie_left", 0.0)) - dt
		var door: Vector3 = e.npc_data["march"][0]
		if e.position.distance_to(door) < 2.5 or float(e.npc_data["sortie_left"]) <= 0.0:
			sim.despawn(e)
			return cmd
		cmd.move = _steer(e, sim, door, dt)
		cmd.aim = door
		return cmd
	var route: Array = e.npc_data["march"]
	var goal := WorldState.march_goal(e)
	var last := e.raid_leg >= route.size() - 1
	if e.position.distance_to(goal) < (2.5 if not last else 1.5):
		if not last:
			e.raid_leg += 1
			goal = WorldState.march_goal(e)
		else:
			if e.npc_goal == Vector3.ZERO or e.position.distance_to(e.npc_goal) < 1.0:
				e.npc_goal = sim.random_walkable(m["def"], goal, float(e.npc_data.get("march_radius", 10.0)))
			cmd.move = MonsterBrain._dir_to(e, e.npc_goal) * 0.7
			cmd.aim = e.npc_goal
			return cmd
	elif last and e.npc_goal != Vector3.ZERO and e.position.distance_to(goal) < float(e.npc_data.get("march_radius", 10.0)):
		goal = e.npc_goal                   # já no pátio: segue rondando
		if e.position.distance_to(goal) < 1.0:
			e.npc_goal = sim.random_walkable(m["def"], route[route.size() - 1], float(e.npc_data.get("march_radius", 10.0)))
	cmd.move = _steer(e, sim, goal, dt)
	cmd.aim = goal
	return cmd

func _steer(e: SimEntity, sim, p: Vector3, dt: float) -> Vector2:
	water_timer -= dt
	if water_timer <= 0.0 or water_goal.distance_to(p) > 3.0:
		water_timer = 1.5
		water_goal = p
		water_path = sim.water_path(e.map_id, e.position, p)
	while not water_path.is_empty() and Vector2(e.position.x, e.position.z).distance_to(water_path[0]) < 1.2:
		water_path.pop_front()
	if not water_path.is_empty():
		p = Vector3(water_path[0].x, 0.0, water_path[0].y)
	var v := MonsterBrain._dir_to(e, p)
	stuck = stuck + dt if e.position.distance_to(last_pos) < 0.02 else 0.0
	last_pos = e.position
	if stuck > 0.5 and detour_left <= 0.0:
		detour = v.rotated(PI * 0.5 * (1.0 if sim.rng.randf() < 0.5 else -1.0))
		detour_left = sim.rng.randf_range(0.8, 1.4)
		stuck = 0.0
	detour_left -= dt
	if detour_left > 0.0:
		return (v * 0.3 + detour).normalized()
	return v
