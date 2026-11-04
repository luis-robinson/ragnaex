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

func think(e: SimEntity, sim, m: Dictionary, dt: float) -> InputCommand:
	var cmd := InputCommand.new()
	cmd.aim = e.position + e.forward()      # sem alvo: mantém o rumo (padrão do comando é a origem do mundo)
	timer -= dt
	skill_timer -= dt
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
	if target == null and state != S.RETURN:
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
	if not is_summon and e.position.distance_to(e.home_position) > mdef.leash_range:
		state = S.RETURN
		e.aggro_target = -1
		e.taunt_left = 0.0
		target = null

	if target != null:
		state = S.CHASE
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

static func _dir_to(e: SimEntity, p: Vector3) -> Vector2:
	var d := p - e.position
	var v := Vector2(d.x, d.z)
	return v.normalized() if v.length() > 0.05 else Vector2.ZERO
