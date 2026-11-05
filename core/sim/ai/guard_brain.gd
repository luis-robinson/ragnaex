class_name GuardBrain
extends RefCounted
## Sentinela do povoado (NPC com `fighter`): defende o posto. Acha monstro perto do posto, luta sem sair
## mais que Balance.GUARD_LEASH de casa e volta à ronda (`route`/`wander` do NPC) quando acaba.

const SKILL_GAP := 2.5

var skill_timer: float = 0.0
var returning := false

func think(e: SimEntity, sim, m: Dictionary, dt: float) -> InputCommand:
	var cmd := InputCommand.new()
	cmd.aim = e.position + e.forward()
	skill_timer -= dt
	var mdef := e.monster_def
	var home := e.home_position
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
		var patrols: bool = e.npc_data.has("route") or e.npc_data.has("wander")
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
		else:
			cmd.move = MonsterBrain._dir_to(e, target.position)
		return cmd
	# sem luta: ronda/passeio do NPC, ou fica no posto
	var nd := e.npc_data
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
