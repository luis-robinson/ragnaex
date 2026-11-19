class_name ChoirSystem
extends RefCounted
## Ascensão do Bispo (Ato II, 35): Coro Celeste — Anjo Guardião, Barreira Sagrada, bênçãos de grupo e Retorno (45).
## Regras sem estado próprio (GDD ato2-horda R6.1 + F9); números em Balance.BARRIER_* / ANGEL_* / BLESS_* / RES_*.
## Estado: anjos = entidades SUMMON com `spirit` (ids em sim.choir_angels); cúpulas em m["barriers"]
## ({id, owner, pos, offset, born, until, burn_t, hold, burn, march}); quem já voltou na luta em sim.choir_returned.

const ANGEL_SKILL := "bis_choir_angel"
const BARRIER_SKILL := "bis_choir_barrier"
const RETURN_SKILL := "bis_choir_return"
const AEGIS_BUFF := "choir_aegis"
## Portões da teia de ascensão (AscensionCatalog.NODES["bishop"], ProgressionSystem.asc_flag).
const FLAG_HOLD := "choir_hold"
const FLAG_ANGEL_STRONG := "choir_angel_strong"
const FLAG_TWO_ANGELS := "choir_two_angels"
const FLAG_BURN := "choir_barrier_burn"
const FLAG_MARCH := "choir_barrier_march"
const FLAG_RES_SHIELD := "choir_res_shield"

static func _flag(e: SimEntity, flag: String) -> bool:
	return e.is_character() and ProgressionSystem.asc_flag(e, flag)

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

# ---------------------------------------------------------------------------
# Anjo Guardião
# ---------------------------------------------------------------------------
static func is_angel(e: SimEntity) -> bool:
	return e != null and e.spirit and e.kind == SimEntity.Kind.SUMMON

## Anjos que o Bispo pode ter (Dois Anjos: +1).
static func angel_max(e: SimEntity) -> int:
	return Balance.ANGEL_MAX + (1 if _flag(e, FLAG_TWO_ANGELS) else 0)

## Anjos vivos do dono, do mais antigo para o mais novo.
static func angels_of(sim: WorldSim, owner: SimEntity) -> Array:
	var out: Array = []
	for id in sim.choir_angels:
		var a: SimEntity = sim.entities.get(id)
		if a != null and a.owner_id == owner.id and a.is_alive():
			out.append(a)
	return out

## Chama o anjo atrás do Bispo; passou do limite, o mais antigo se despede (sem a Luz de Partida).
static func summon_angel(sim: WorldSim, e: SimEntity, s: SkillDef) -> SimEntity:
	var mdef: MonsterDef = GameData.monsters.get(Balance.ANGEL_MONSTER)
	if mdef == null or not sim.maps.has(e.map_id):
		return null
	var mine := angels_of(sim, e)
	while mine.size() >= angel_max(e):
		sim.despawn(mine.pop_front())
	var a := sim.spawn_summon(e, mdef, _angel_spot(e, mine.size()), Balance.ANGEL_TIME)
	a.spirit = true
	a.brain = null                         # sem cérebro: tick() move e cura
	a.choir_t = Balance.ANGEL_HEAL_EVERY
	a.facing = e.facing
	sim.choir_angels.append(a.id)
	Events.post(&"skill_effect", s.id, e.position, a.position, 0.0)
	return a

## Lugar do anjo: atrás do Bispo (o 2º ao lado do 1º).
static func _angel_spot(owner: SimEntity, index: int) -> Vector3:
	var back := -owner.forward()
	var side := Vector3(-back.z, 0.0, back.x) * (0.0 if index == 0 else 1.4)
	return owner.position + back * Balance.ANGEL_FOLLOW_DIST + side

## Quem o anjo cura agora: o tanque do grupo abaixo de ANGEL_TANK_BELOW; senão o mais ferido abaixo de ANGEL_HEAL_BELOW
## (a mesma ordem dos bots que curam). null = ninguém precisa.
static func angel_target(sim: WorldSim, angel: SimEntity, owner: SimEntity) -> SimEntity:
	var best: SimEntity = null
	var worst := Balance.ANGEL_HEAL_BELOW
	for o in sim.maps[angel.map_id]["entities"]:
		if not o.is_character() or not o.is_alive() or not owner.is_friend(o) or _flat(o.position, angel.position) > Balance.ANGEL_RANGE:
			continue
		var r: float = o.hp / maxf(1.0, o.stats.max_hp)
		if r < Balance.ANGEL_TANK_BELOW and o != owner and sim.role_of(o) == "tank":
			return o
		if r < worst:
			worst = r
			best = o
	return best

## Cura do anjo: poder × maestria da skill (como o poder das outras) × Anjo Forte.
static func _angel_power(owner: SimEntity, power: float) -> float:
	var s: SkillDef = GameData.skills.get(ANGEL_SKILL)
	var m := float(s.mastery_entry(owner.mastery_of(ANGEL_SKILL)).get("power_mult", 1.0)) if s != null and owner.is_character() else 1.0
	return power * m * (1.0 + (Balance.ANGEL_STRONG_PCT / 100.0 if _flag(owner, FLAG_ANGEL_STRONG) else 0.0))

## Luz de Partida: o tempo do anjo acabou; cura em área os aliados em volta dele.
static func _parting_light(sim: WorldSim, angel: SimEntity, owner: SimEntity) -> void:
	for o in sim.maps[angel.map_id]["entities"]:
		if o.is_character() and o.is_alive() and owner.is_friend(o) and _flat(o.position, angel.position) <= Balance.ANGEL_PARTING_RADIUS:
			sim._heal(owner, o, Combat.calc_heal(owner, _angel_power(owner, Balance.ANGEL_PARTING_HEAL), sim.rng))
	Events.post(&"skill_effect", ANGEL_SKILL, angel.position, angel.position, Balance.ANGEL_PARTING_RADIUS)

static func _tick_angel(sim: WorldSim, a: SimEntity, dt: float) -> void:
	var owner: SimEntity = sim.entities.get(a.owner_id)
	if owner == null or not owner.is_alive() or owner.map_id != a.map_id:
		sim.despawn(a)                      # some com o Bispo (morte ou troca de mapa)
		return
	if sim.time + dt >= a.summon_expires:
		_parting_light(sim, a, owner)
		sim.despawn(a)
		return
	# voa atrás do Bispo, por cima de tudo (sem colisão)
	var spot := _angel_spot(owner, angels_of(sim, owner).find(a))
	if _flat(a.position, spot) > Balance.SUMMON_LEASH:
		a.position = spot
	else:
		a.position = a.position.move_toward(spot, Balance.ANGEL_FLY_SPEED * dt)
	a.facing = owner.facing
	a.choir_t -= dt
	if a.choir_t > 0.0:
		return
	a.choir_t = Balance.ANGEL_HEAL_EVERY
	var t := angel_target(sim, a, owner)
	if t == null:
		return
	a.face_towards(t.position)
	sim._heal(owner, t, Combat.calc_heal(owner, _angel_power(owner, Balance.ANGEL_HEAL), sim.rng))
	Events.post(&"skill_effect", ANGEL_SKILL, a.position, t.position, 0.0)

# ---------------------------------------------------------------------------
# Barreira Sagrada
# ---------------------------------------------------------------------------
## Cúpulas do mapa (lista viva; vazia se não há).
static func barriers(m: Dictionary) -> Array:
	return m.get("barriers", [])

## Põe a cúpula no ponto mirado (a anterior do mesmo Bispo some). Refinos vêm dos portões comprados na teia.
static func place_barrier(sim: WorldSim, e: SimEntity, s: SkillDef, aim: Vector3, m: Dictionary) -> Dictionary:
	if not m.has("barriers"):
		m["barriers"] = []
	var list: Array = m["barriers"]
	for b in list.duplicate():
		if int(b["owner"]) == e.id and not b.get("dome", false):     # a Cúpula da Graça (Suprema) fica
			list.erase(b)
	var pos := Combat.clamp_aim(e, aim, s.range)
	pos.y = 0.0
	sim.choir_next_id += 1
	var b := {"id": sim.choir_next_id, "owner": e.id, "pos": pos, "offset": pos - Vector3(e.position.x, 0.0, e.position.z),
		"born": sim.time, "until": sim.time + Balance.BARRIER_TIME, "burn_t": 0.0, "radius": s.radius,
		"hold": _flag(e, FLAG_HOLD), "burn": _flag(e, FLAG_BURN), "march": _flag(e, FLAG_MARCH)}
	list.append(b)
	if b["march"]:                          # Barreira em Marcha: escudo em quem está dentro ao lançar
		for o in m["entities"]:
			if o.is_alive() and e.is_friend(o) and (o.is_character() or o.guard) and inside(b, o.position):
				sim._apply_effects(e, o, {"shield": {"amount_pct_hp": Balance.BARRIER_MARCH_SHIELD, "duration": Balance.BARRIER_MARCH_SHIELD_TIME}}, 0.0)
	Events.post(&"skill_effect", s.id, e.position, pos, s.radius)
	return b

## Cúpula da Graça (Suprema do Sacerdote): cúpula PARADA no ponto, -dr% (d = {"duration", "dr"}); a anterior dele some.
## Mesma lista da Barreira Sagrada (desenho, projéteis, chuva de chefe); com as duas em cima vale a maior redução.
static func place_dome(sim: WorldSim, e: SimEntity, s: SkillDef, aim: Vector3, m: Dictionary, d: Dictionary) -> Dictionary:
	if not m.has("barriers"):
		m["barriers"] = []
	var list: Array = m["barriers"]
	for b in list.duplicate():
		if int(b["owner"]) == e.id and b.get("dome", false):
			list.erase(b)
	var pos := Combat.clamp_aim(e, aim, s.range)
	pos.y = 0.0
	sim.choir_next_id += 1
	var b := {"id": sim.choir_next_id, "owner": e.id, "pos": pos, "offset": Vector3.ZERO, "born": sim.time,
		"until": sim.time + float(d.get("duration", 8.0)), "burn_t": 0.0, "radius": s.radius, "hold": false, "burn": false, "march": false,
		"dome": true, "anchored": true, "dr": float(d.get("dr", 50.0))}
	list.append(b)
	return b

## Redução de dano da cúpula `b` (Barreira Sagrada: BARRIER_DR; Cúpula da Graça: a dela).
static func dr_of(b: Dictionary) -> float:
	return float(b.get("dr", Balance.BARRIER_DR))

static func inside(b: Dictionary, p: Vector3) -> bool:
	return _flat(b["pos"], p) <= float(b["radius"])

## Cúpula aliada que cobre `e` (a de maior tempo restante; {} = nenhuma).
static func barrier_over(sim: WorldSim, e: SimEntity) -> Dictionary:
	var m: Dictionary = sim.maps.get(e.map_id, {})
	var list: Array = m.get("barriers", [])
	if list.is_empty():
		return {}
	var best := {}
	for b in list:
		if not inside(b, e.position):
			continue
		var owner: SimEntity = sim.entities.get(int(b["owner"]))
		if owner == null or not owner.is_friend(e):
			continue
		if best.is_empty() or dr_of(b) > dr_of(best) or (dr_of(b) == dr_of(best) and float(b["until"]) > float(best["until"])):
			best = b                         # duas cúpulas não somam: vale a maior redução
	return best

## Dano que vai entrar em `target` (chamado antes de tirar a vida): dentro de cúpula aliada, −BARRIER_DR % (duas cúpulas
## não somam: vale uma) e, com o nó dos 45, a vida não cai abaixo de 1 nos primeiros BARRIER_HOLD s da cúpula.
static func damage_in(sim: WorldSim, attacker: SimEntity, target: SimEntity, amount: int) -> int:
	if amount <= 0 or attacker == target:
		return amount
	var b := barrier_over(sim, target)
	if b.is_empty():
		return amount
	amount = maxi(1, int(round(amount * (1.0 - dr_of(b) / 100.0))))
	if holding(sim, target):
		amount = mini(amount, maxi(0, int(target.hp) - 1))
	return amount

## Alguma cúpula aliada sobre `e` ainda segura a vida em 1 (primeiros BARRIER_HOLD s, inclusive o tick do fim).
static func holding(sim: WorldSim, e: SimEntity) -> bool:
	for b in barriers(sim.maps.get(e.map_id, {})):
		if b["hold"] and sim.time <= float(b["born"]) + Balance.BARRIER_HOLD + 0.0001 and inside(b, e.position):
			var owner: SimEntity = sim.entities.get(int(b["owner"]))
			if owner != null and owner.is_friend(e):
				return true
	return false

## Projétil de inimigo que veio de fora e chegou à borda de uma cúpula: para ali.
static func stops_projectile(sim: WorldSim, m: Dictionary, p: SimProjectile, shooter: SimEntity) -> bool:
	var list: Array = m.get("barriers", [])
	if list.is_empty():
		return false
	for b in list:
		if not inside(b, p.position) or inside(b, p.position - p.direction * p.traveled):
			continue                        # fora da cúpula, ou atirado de dentro dela
		var owner: SimEntity = sim.entities.get(int(b["owner"]))
		if owner != null and shooter.is_hostile_to(owner):
			Events.post(&"skill_effect", BARRIER_SKILL + "_stop", p.position, p.position, 0.6)
			return true
	return false

## Chuva de chefe (barrage) caindo em `o`: quem está dentro de cúpula aliada com o chefe do lado de fora não leva.
static func shelters(sim: WorldSim, striker: SimEntity, o: SimEntity) -> bool:
	var b := barrier_over(sim, o)
	return not b.is_empty() and not inside(b, striker.position)

static func _tick_barrier(sim: WorldSim, m: Dictionary, b: Dictionary, dt: float) -> bool:
	if b.get("dome", false):
		return sim.time < float(b["until"])     # Cúpula da Graça: parada no ponto e fica até acabar, mesmo com o Sacerdote morto ou longe
	var owner: SimEntity = sim.entities.get(int(b["owner"]))
	if owner == null or not owner.is_alive() or owner.map_id != m["def"].id or sim.time >= float(b["until"]):
		return false
	if b.get("anchored", false):
		return true
	# anda com o Bispo: persegue (Bispo + deslocamento do lançamento) BARRIER_LAG mais devagar que ele; em Marcha, colada
	var want: Vector3 = Vector3(owner.position.x, 0.0, owner.position.z) + b["offset"]
	if b["march"]:
		b["pos"] = want
	else:
		b["pos"] = (b["pos"] as Vector3).move_toward(want, maxf(0.0, owner.stats.move_speed - Balance.BARRIER_LAG) * dt)
	if b["burn"]:                           # Barreira que Fere: inimigo dentro queima
		b["burn_t"] = float(b["burn_t"]) + dt
		if float(b["burn_t"]) >= Balance.BARRIER_BURN_EVERY:
			b["burn_t"] = float(b["burn_t"]) - Balance.BARRIER_BURN_EVERY
			for o in m["entities"].duplicate():
				if o.is_alive() and owner.is_hostile_to(o) and not o.is_perched() and _flat(o.position, b["pos"]) <= float(b["radius"]) + o.radius:
					var r := Combat.calc_damage(owner, o, Balance.BARRIER_BURN_POWER * Balance.BARRIER_BURN_EVERY, SkillDef.Kind.MAGICAL, sim.rng, b["pos"])
					sim._deal_damage(owner, o, r["amount"], r["crit"], false, "magical", b["pos"])
	return true

# ---------------------------------------------------------------------------
# Égide Coral
# ---------------------------------------------------------------------------
## Golpe direto recebido com a Égide Coral: cura BLESS_AEGIS_HEAL % do HP (uma a cada BLESS_AEGIS_HEAL_ICD s).
static func on_hit_taken(sim: WorldSim, target: SimEntity, amount: int) -> void:
	if amount <= 0 or target.buffs.is_empty() or not target.is_alive() or sim.time < target.aegis_cd:
		return
	for b in target.buffs:
		if b.get("id") == AEGIS_BUFF:
			target.aegis_cd = sim.time + Balance.BLESS_AEGIS_HEAL_ICD
			sim._heal(target, target, maxi(1, int(target.stats.max_hp * Balance.BLESS_AEGIS_HEAL / 100.0)))
			return

# ---------------------------------------------------------------------------
# Retorno (ressurreição em combate)
# ---------------------------------------------------------------------------
## Caído do grupo que o Retorno alcança: o mais perto do ponto mirado (RES_PICK_RADIUS), senão o mais perto do Bispo.
## `any` = inclui quem já voltou nesta luta (para dizer por que recusa).
static func fallen(sim: WorldSim, e: SimEntity, aim: Vector3, any: bool = false) -> SimEntity:
	var best: SimEntity = null
	var best_d := INF
	for o in sim.party_members(e):
		if o == e or o.is_alive() or o.map_id != e.map_id or (o.returned and not any) or _flat(o.position, e.position) > Balance.RES_RANGE:
			continue
		var d := _flat(o.position, aim)
		if d > Balance.RES_PICK_RADIUS:
			d = Balance.RES_PICK_RADIUS + _flat(o.position, e.position)
		if d < best_d:
			best_d = d
			best = o
	return best

## Por que o Retorno não sai agora ("" = pode).
static func return_block(sim: WorldSim, e: SimEntity, aim: Vector3) -> String:
	if fallen(sim, e, aim) != null:
		return ""
	var again := fallen(sim, e, aim, true)
	if again != null:
		return "%s já voltou nesta luta" % again.name
	return "Retorno: ninguém do grupo caído por perto"

## Começo da conjuração: o caído espera (não renasce na cidade) até ela terminar.
static func begin_return(sim: WorldSim, e: SimEntity, s: SkillDef, aim: Vector3) -> void:
	var t := fallen(sim, e, aim)
	e.res_target = t.id if t != null else -1
	if t != null:
		t.res_hold = s.startup + Balance.RES_HOLD_PAD

## Fim da conjuração: o caído levanta onde está com RES_HP_PCT da vida e da mana; marcado até a luta acabar.
static func finish_return(sim: WorldSim, e: SimEntity, s: SkillDef) -> bool:
	var t: SimEntity = sim.entities.get(e.res_target)
	e.res_target = -1
	if t == null or t.is_alive() or t.map_id != e.map_id or t.returned:
		return false
	t.res_hold = 0.0
	t.dead_time = 0.0
	t.set_state(SimEntity.State.IDLE)
	t.recompute_stats()
	t.hp = maxf(1.0, t.stats.max_hp * Balance.RES_HP_PCT)
	t.mp = maxf(t.mp, t.stats.max_mp * Balance.RES_HP_PCT)
	t.returned = true
	t.combat_timer = Balance.AGGRO_LOSE_TIME
	sim.choir_returned.append(t.id)
	if _flag(e, FLAG_RES_SHIELD):           # Retorno Blindado (Batalha)
		sim._apply_effects(e, t, {"shield": {"amount_pct_hp": Balance.RES_BATTLE_SHIELD, "duration": Balance.RES_BATTLE_SHIELD_TIME}}, 0.0)
	Events.post(&"entity_respawned", t.id)
	Events.post(&"skill_effect", s.id, e.position, t.position, 1.5)
	if t == sim.player or e == sim.player:
		Events.post(&"notification", "%s voltou à luta!" % t.name)
	return true

## A luta do grupo acabou (ninguém em combate): quem voltou pode voltar de novo na próxima.
static func _fight_over(sim: WorldSim, e: SimEntity) -> bool:
	if e.combat_timer > 0.0:
		return false
	for o in sim.party_members(e):
		if o.combat_timer > 0.0 and o.is_alive():
			return false
	return true

# ---------------------------------------------------------------------------
# tick
# ---------------------------------------------------------------------------
static func tick(sim: WorldSim, m: Dictionary, dt: float) -> void:
	var list: Array = m.get("barriers", [])
	if not list.is_empty():
		for b in list.duplicate():
			if not _tick_barrier(sim, m, b, dt):
				list.erase(b)
	if not sim.choir_angels.is_empty():
		var map_id: String = m["def"].id
		for id in sim.choir_angels.duplicate():
			var a: SimEntity = sim.entities.get(id)
			if a == null or not a.is_alive():
				sim.choir_angels.erase(id)
			elif a.map_id == map_id:
				_tick_angel(sim, a, dt)
	if not sim.choir_returned.is_empty():
		for id in sim.choir_returned.duplicate():
			var o: SimEntity = sim.entities.get(id)
			if o == null or _fight_over(sim, o):
				sim.choir_returned.erase(id)
				if o != null:
					o.returned = false

# ---------------------------------------------------------------------------
# Bots
# ---------------------------------------------------------------------------
## Cúpula do grupo em que o bot deve ficar ({} = nenhuma no mapa).
static func party_barrier(sim: WorldSim, e: SimEntity) -> Dictionary:
	var best := {}
	for b in barriers(sim.maps.get(e.map_id, {})):
		var owner: SimEntity = sim.entities.get(int(b["owner"]))
		if owner != null and owner.is_friend(e) and (best.is_empty() or float(b["until"]) > float(best["until"])):
			best = b
	return best

## O Bispo bot deve erguer a cúpula agora: chuva/golpe avisado de chefe perto do grupo, ou BOT_BARRIER_HURT_N membros
## abaixo de BOT_BARRIER_HURT da vida.
static func wants_barrier(sim: WorldSim, e: SimEntity, m: Dictionary, members: Array) -> bool:
	var hurt := 0
	for o in members:
		if o.is_alive() and o.map_id == e.map_id and o.hp < o.stats.max_hp * Balance.BOT_BARRIER_HURT:
			hurt += 1
	if hurt >= Balance.BOT_BARRIER_HURT_N:
		return true
	for h in m.get("hazards", []):
		var hp: Vector3 = h["pos"]
		for o in members:
			if o.is_alive() and o.map_id == e.map_id and _flat(o.position, hp) <= Balance.BOT_BARRIER_NEAR:
				return true
	for o in m["entities"]:
		if o.kind != SimEntity.Kind.MONSTER or o.state != SimEntity.State.CASTING or o.current_skill == null or o.skill_phase != "startup":
			continue
		if o.monster_def == null or not o.monster_def.is_boss or (o.current_skill.mob_pick == "" and not o.current_skill.effects.has("barrage")):
			continue
		if _flat(o.position, e.position) <= Balance.BOT_BARRIER_NEAR + o.current_skill.range:
			return true
	return false

## O Bispo bot deve chamar o anjo agora: chefe em luta a BOT_BARRIER_NEAR + RES_RANGE m, ou alguém do grupo ferido.
static func wants_angel(sim: WorldSim, e: SimEntity, m: Dictionary, members: Array) -> bool:
	for o in members:
		if o.is_alive() and o.map_id == e.map_id and o.hp < o.stats.max_hp * Balance.BOT_ANGEL_HURT:
			return true
	for o in m["entities"]:
		if o.kind == SimEntity.Kind.MONSTER and o.aggro_target >= 0 and o.monster_def != null and o.monster_def.is_boss and o.is_alive() 				and _flat(o.position, e.position) <= Balance.BOT_BARRIER_NEAR + Balance.RES_RANGE:
			return true
	return false

## Onde o bot põe a cúpula: no meio do grupo (vivos a RES_RANGE dele), dentro do alcance da skill.
static func barrier_spot(e: SimEntity, members: Array) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for o in members:
		if o.is_alive() and o.map_id == e.map_id and _flat(o.position, e.position) <= Balance.RES_RANGE:
			sum += o.position
			n += 1
	return sum / float(n) if n > 0 else e.position
