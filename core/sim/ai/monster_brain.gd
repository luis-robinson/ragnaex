class_name MonsterBrain
extends RefCounted
## IA de monstro (e de invocações): idle → wander → chase → attack → leash.
## Produz InputCommand igual a um jogador.

enum S { IDLE, WANDER, CHASE, RETURN }
const SKILL_GAP := 2.0      # s mínimos entre skills de um monstro
const RETURN_LIMIT := 15.0  # s voltando para casa; preso em obstáculo reaparece lá

var state: S = S.IDLE
var timer: float = 0.0
var wander_target: Vector3 = Vector3.ZERO
var skill_timer: float = 0.0
var return_time: float = 0.0
# investida (RaidSystem): marcha pela rota
var calm: float = 0.0          # s sem puxar briga nova (acabou de largar um alvo longe da rota)
var was_retreat := false
var fought := false
var water_path: Array = []
var water_goal := Vector3.INF
var water_timer: float = 0.0
var last_pos := Vector3.ZERO
var stuck: float = 0.0
var detour := Vector2.ZERO
var detour_left: float = 0.0

func think(e: SimEntity, sim, m: Dictionary, dt: float) -> InputCommand:
	var cmd := InputCommand.new()
	cmd.aim = e.position + e.forward()      # sem alvo: mantém o rumo (padrão do comando é a origem do mundo)
	timer -= dt
	skill_timer -= dt
	calm -= dt
	var raider := e.raid_id >= 0
	var def: MapDef = m["def"]
	var mdef := e.monster_def
	var is_summon := e.kind == SimEntity.Kind.SUMMON
	var owner: SimEntity = sim.entities.get(e.owner_id) if is_summon else null

	# --- escolher alvo ---
	var target: SimEntity = null
	if state == S.RETURN and not is_summon:
		e.aggro_target = -1          # voltando: só chega em casa, senão fica indo e vindo no limite do leash
	if e.aggro_target >= 0:
		target = sim.entities.get(e.aggro_target)
		if target and (not target.is_alive() or target.map_id != e.map_id or (target.stealth_left > 0.0 and e.taunt_left <= 0.0)):
			target = null
			e.aggro_target = -1
			e.taunt_left = 0.0
	if target == null and state != S.RETURN and not (raider and calm > 0.0):
		var aggro := mdef.aggro_range if not is_summon else 9.0
		target = Combat.nearest_hostile(e, m.get("chars", m["entities"]), aggro)     # só personagens e invocações (lista do tick)
		if target:
			e.aggro_target = target.id
			e.aggro_timer = Balance.AGGRO_LOSE_TIME
	# invocação volta pro dono se ele se afastar
	if is_summon and owner and target == null:
		var d := owner.position.distance_to(e.position)
		if d > 3.0:
			cmd.move = _dir_to(e, owner.position + Vector3(0.8, 0, 0.8))
			cmd.aim = owner.position
			return cmd
		cmd.aim = e.position + e.forward()
		return cmd

	# --- leash: longe demais de casa ---
	if raider and target != null and e.position.distance_to(e.home_position) > mdef.leash_range:
		e.aggro_target = -1             # investida: larga quem foge e volta para a rota (sem teleporte para casa)
		e.taunt_left = 0.0
		target = null
		calm = 4.0
	elif not is_summon and not raider and e.position.distance_to(e.home_position) > mdef.leash_range:
		state = S.RETURN
		e.aggro_target = -1
		e.taunt_left = 0.0
		target = null

	if target != null:
		state = S.CHASE
		fought = true
		var dist := e.position.distance_to(target.position) - target.radius    # o acerto mede do centro de quem bate até a borda do alvo
		cmd.aim = target.position
		# skill especial? As últimas da lista são as mais novas (fases de chefe)
		if skill_timer <= 0.0 and e.can_act():
			for i in range(e.skills.size() - 1, -1, -1):
				var s: SkillDef = e.skills[i]
				var reach_s: float = s.radius - 0.3 if s.target == SkillDef.Target.SELF else maxf(s.range, s.radius) + (0.0 if s.effects.has("dash") else 0.5)
				if float(e.cooldowns.get(s.id, 0.0)) <= 0.0 and dist <= reach_s and (not s.is_charge() or sim.charge_lands(e, s, target, m)):
					cmd.skill_slot = i
					skill_timer = minf(s.cooldown + 1.0, SKILL_GAP)
					return cmd
		var reach := mdef.attack_range if not is_summon or mdef.ranged else 1.5
		if dist <= reach * 0.85:
			if e.basic_cd <= 0.0 and e.can_act():
				cmd.attack = true
			elif mdef.ranged and dist < reach * 0.5 and e.position.distance_to(e.home_position) < mdef.leash_range * 0.7:
				cmd.move = -_dir_to(e, target.position)      # recua entre os tiros
		else:
			cmd.move = _dir_to(e, target.position)
		return cmd

	if raider:
		return _march(e, sim, cmd, dt)

	# chefe sem alvo e fora de combate volta para casa e reseta: só wipe de verdade, não quem atira de longe
	if mdef.is_boss and state != S.RETURN and e.combat_timer <= 0.0 and (e.hp < e.stats.max_hp or e.phase > 0):
		state = S.RETURN

	match state:
		S.RETURN:
			return_time += dt
			if return_time >= RETURN_LIMIT:
				e.position = e.home_position
			if e.position.distance_to(e.home_position) < 1.0:
				state = S.IDLE
				timer = 1.0
				return_time = 0.0
				e.threat.clear()
				e.damage_by.clear()
				if mdef.is_boss:
					sim.reset_boss(e)
				else:
					e.hp = minf(e.stats.max_hp, e.hp + e.stats.max_hp * 0.5)
			else:
				cmd.move = _dir_to(e, e.home_position)
				cmd.aim = e.home_position
		S.IDLE:
			if timer <= 0.0:
				state = S.WANDER
				wander_target = sim.random_walkable(def, e.home_position, 5.0)
				timer = 6.0
			cmd.aim = e.position + e.forward()
		S.WANDER:
			if timer <= 0.0 or e.position.distance_to(wander_target) < 0.6:
				state = S.IDLE
				timer = sim.rng.randf_range(1.5, 4.0)
			else:
				cmd.move = _dir_to(e, wander_target) * 0.5
				cmd.aim = wander_target
		_:
			state = S.IDLE
	return cmd

## Investida sem alvo: segue a rota (ida ou recuo), desviando do rio pelas pontes e de obstáculos.
## A âncora da luta (home_position) anda junto: a perseguição se mede de onde a briga começou.
func _march(e: SimEntity, sim, cmd: InputCommand, dt: float) -> InputCommand:
	state = S.IDLE
	e.home_position = e.position
	var retreat: bool = RaidSystem.retreating(sim, e)
	if retreat != was_retreat or fought:
		was_retreat = retreat
		fought = false
		e.raid_leg = RaidSystem.nearest_leg(sim, e)
	var goal := RaidSystem.march_point(sim, e)
	if not retreat and RaidSystem.mustering(sim, e):
		cmd.aim = goal                      # trompas: a leva se junta na garganta antes de descer
		return cmd
	var last := e.raid_leg >= RaidSystem.march_len(sim, e) - 1
	if e.position.distance_to(goal) < (2.5 if not last else 1.5):
		if not last:
			e.raid_leg += 1
			goal = RaidSystem.march_point(sim, e)
		elif not retreat:
			# chegou ao povoado: ronda pela praça procurando briga
			var r: float = float(sim.maps[e.map_id]["def"].raid.get("radius", 25.0)) * 0.6
			wander_target = sim.random_walkable(sim.maps[e.map_id]["def"], goal, r)
			cmd.move = _dir_to(e, wander_target) * 0.6
			cmd.aim = wander_target
			return cmd
	cmd.move = _steer(e, sim, goal, dt) * (Balance.RAID_MARCH_PACE if not retreat else 1.0)     # marcha cautelosa; na luta, velocidade cheia
	cmd.aim = e.position + Vector3(cmd.move.x, 0.0, cmd.move.y)
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
	var v := _dir_to(e, p)
	if e.position.distance_to(last_pos) < 0.02 * (dt * 60.0):
		stuck += dt
	else:
		stuck = 0.0
	last_pos = e.position
	if stuck > 0.5 and detour_left <= 0.0:
		detour = v.rotated(PI * 0.5 * (1.0 if sim.rng.randf() < 0.5 else -1.0))
		detour_left = sim.rng.randf_range(0.8, 1.4)
		stuck = 0.0
	detour_left -= dt
	if detour_left > 0.0:
		return (v * 0.3 + detour).normalized()
	return v

static func _dir_to(e: SimEntity, p: Vector3) -> Vector2:
	var d := p - e.position
	var v := Vector2(d.x, d.z)
	return v.normalized() if v.length() > 0.05 else Vector2.ZERO
