class_name FalconSystem
extends RefCounted
## Ascensão do Caçador (Ato II, 35) — Falcoeiro: Olhos do Céu (design/gdd/ato2-proposals-2026-11-11.md §2 opção A).
## O falcão é um segundo companheiro INTOCÁVEL: não é entidade (sem vida, sem aggro, sem chão) — é estado no dono
## (`SimEntity.falcon`), fica até o dono cair. A cada Balance.FALCON_DIVE_CD ele mergulha no alvo do caçador (o último
## inimigo que o caçador acertou) e marca a Presa (maldição `falcon_prey`: o alvo recebe +FALCON_TAKEN% de todos).
## Regras sem estado próprio; números em Balance.FALCON_* / MARK_*.

const BUILD := "cacador"                 # build do Falcoeiro (peso F5: Balance.ASC_BUILD_POWER)
const EYES_BUFF := "sky_eyes"            # buff de Olhos do Céu (grupo)
const DIVE_FX := "ran_dive"              # skill cujo efeito visual o mergulho usa (Events skill_effect)

## Alcance do falcão a partir do caçador: FALCON_RANGE com o bônus de alcance das skills de arco (igual ao do Mergulho).
static func reach() -> float:
	return Balance.FALCON_RANGE * Balance.ARCHER_RANGE_MULT

static func is_skill(s: SkillDef) -> bool:
	return s.effects.has("falcon_call") or s.effects.has("falcon_dive") or s.effects.has("falcon_eyes")

## Por que a sim recusa a skill ("" = pode): chamar com o falcão no ar; Mergulho/Olhos do Céu sem falcão.
static func cast_block(e: SimEntity, s: SkillDef) -> String:
	if s.effects.has("falcon_call"):
		return "Seu falcão já está com você" if e.falcon else ""
	if (s.effects.has("falcon_dive") or s.effects.has("falcon_eyes")) and not e.falcon:
		return "%s: chame o falcão primeiro" % s.name
	return ""

## Chamado do Falcão: o falcão passa a voar sobre o caçador (1 por caçador; fica até o dono cair).
static func call_falcon(e: SimEntity, s: SkillDef) -> void:
	e.falcon = true
	e.falcon_cd = 0.0                    # o primeiro mergulho sai no primeiro golpe do caçador
	e.falcon_target = -1
	Events.post(&"skill_effect", s.id, e.position, e.position, 0.0)

## O dono caiu: o falcão vai embora (chamar de novo).
static func dismiss(e: SimEntity) -> void:
	e.falcon = false
	e.falcon_target = -1
	e.falcon_dive_pos = []

## Golpe direto do caçador: é esse o alvo que o falcão acompanha.
static func on_strike(e: SimEntity, t: SimEntity) -> void:
	if e.falcon and t != e and e.is_hostile_to(t):
		e.falcon_target = t.id

## Relógio do mergulho automático (só de quem tem falcão).
static func tick(sim: WorldSim, e: SimEntity, dt: float) -> void:
	e.falcon_cd = maxf(0.0, e.falcon_cd - dt)
	if e.falcon_cd > 0.0 or e.falcon_target < 0 or not e.is_alive():
		return
	var t: SimEntity = sim.entities.get(e.falcon_target)
	if not can_dive(e, t):
		if t == null or not t.is_alive():
			e.falcon_target = -1
		return
	e.falcon_cd = Balance.FALCON_DIVE_CD
	dive(sim, e, t, Balance.FALCON_DIVE_POWER)

## O falcão alcança `t`? (vivo, inimigo do dono, no mapa dele, a reach() m, fora de dash/salto)
static func can_dive(e: SimEntity, t: SimEntity) -> bool:
	return t != null and t.is_alive() and t.map_id == e.map_id and e.is_hostile_to(t) and t.iframe_left <= 0.0 \
		and t.position.distance_to(e.position) <= reach() + t.radius

## Mergulho do falcão em `t`: dano com o ATK do caçador (vem de cima e por trás: guarda de frente não pega) e Presa.
static func dive(sim: WorldSim, e: SimEntity, t: SimEntity, power: float) -> void:
	var from := t.position - t.forward() * (t.radius + 0.5)
	var p := power * (1.0 + e.stats.falcon_pct / 100.0) * RangerAscension.asc_power(BUILD)
	var r := Combat.calc_damage(e, t, p, SkillDef.Kind.PHYSICAL, sim.rng, from)
	sim._deal_damage(e, t, r["amount"], r["crit"], r["blocked"], "physical", from)
	if t.is_alive():
		mark(e, t)
	show_dive(sim, e, t.position)

## Presa: maldição-marca do caçador `src` em `t` (renova; cada caçador tem a sua, o teto MARK_TAKEN_CAP segura a soma).
static func mark(src: SimEntity, t: SimEntity) -> void:
	t.put_debuff({"kind": "curse", "id": "curse_%s_%d" % [Balance.FALCON_PREY_ID, src.id], "remaining": Balance.FALCON_PREY_TIME,
		"taken_pct": Balance.FALCON_TAKEN, "weaken_pct": 0.0, "mark": true, "prey": true, "owner": src.id})

## Anota o mergulho para o desenho (FalconView lê `falcon_dive_time`/`falcon_dive_pos`) e solta o efeito.
static func show_dive(sim: WorldSim, e: SimEntity, at: Vector3) -> void:
	if e.falcon_dive_time != sim.time:
		e.falcon_dive_pos = []
	e.falcon_dive_time = sim.time
	e.falcon_dive_pos.append(at)
	Events.post(&"skill_effect", DIVE_FX, e.position + Vector3(0, Balance.FALCON_HOVER, 0), at, 0.6)

## Skill Mergulho (o golpe e o atordoamento já saíram pelo caminho normal): Presa no alvo, o falcão passa a segui-lo
## e os linces saltam nele (como o Ataque da Fera, sem a mordida extra).
static func stoop(sim: WorldSim, e: SimEntity, targets: Array, m: Dictionary) -> void:
	for t in targets:
		if not e.is_hostile_to(t):
			continue
		if t.is_alive():
			mark(e, t)
			e.falcon_target = t.id
			send_pets(sim, e, t, m)
		show_dive(sim, e, t.position)
		return

## Manda os companheiros permanentes do dono (linces) saltarem em `t` e segurarem o alvo um tempo.
static func send_pets(sim: WorldSim, e: SimEntity, t: SimEntity, m: Dictionary) -> int:
	var n := 0
	for o in m["entities"]:
		if o.kind != SimEntity.Kind.SUMMON or o.owner_id != e.id or not o.is_alive() or o.summon_expires != INF \
				or o.elem_form != "" or RangerAscension.is_turret(o):
			continue
		var dir: Vector3 = o.position - t.position
		dir.y = 0.0
		dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
		o.position = t.position + dir.rotated(Vector3.UP, 0.6 * n) * (t.radius + o.radius + 0.2)
		o.face_towards(t.position)
		o.aggro_target = t.id
		if o.brain is MonsterBrain:
			o.brain.skill_rethink = Balance.PET_COMMAND_FOCUS
		n += 1
	return n

## Olhos do Céu (o buff do grupo sai pelo caminho normal da skill). Refino 45, Revoada: FALCON_FLOCK falcões mergulham
## em alvos diferentes (o do caçador primeiro, depois os mais perto que já estão em luta).
static func eyes(sim: WorldSim, e: SimEntity, m: Dictionary) -> int:
	if not ProgressionSystem.asc_flag(e, Balance.FALCON_FLAG_FLOCK):
		return 0
	var picks: Array = []
	var cur: SimEntity = sim.entities.get(e.falcon_target)
	if can_dive(e, cur):
		picks.append(cur)
	var rest: Array = []
	for o in m["entities"]:
		if o == cur or not can_dive(e, o):
			continue
		if o.kind == SimEntity.Kind.MONSTER and o.aggro_target < 0:
			continue                          # bicho quieto fica quieto: a revoada não puxa o mapa
		rest.append(o)
	rest.sort_custom(func(a, b): return a.position.distance_squared_to(e.position) < b.position.distance_squared_to(e.position))
	for o in rest:
		if picks.size() >= Balance.FALCON_FLOCK:
			break
		picks.append(o)
	for t in picks:
		dive(sim, e, t, Balance.FALCON_DIVE_POWER)
	return picks.size()

## Refino 40, Falcão Real: a Presa de quem morreu passa para o inimigo mais perto (FALCON_ROYAL_RANGE m) sem a Presa
## desse caçador. Chamado ANTES de limpar os debuffs do morto.
static func on_death(sim: WorldSim, dead: SimEntity) -> void:
	if not sim.maps.has(dead.map_id):
		return
	for d in dead.debuffs:
		if not d.get("prey", false):
			continue
		var src: SimEntity = sim.entities.get(int(d.get("owner", -1)))
		if src == null or not src.is_alive() or not src.falcon or src.map_id != dead.map_id \
				or not ProgressionSystem.asc_flag(src, Balance.FALCON_FLAG_ROYAL):
			continue
		var pid := "curse_%s_%d" % [Balance.FALCON_PREY_ID, src.id]
		var best: SimEntity = null
		var best_d := Balance.FALCON_ROYAL_RANGE
		for o in sim.maps[dead.map_id]["entities"]:
			if o == dead or not o.is_alive() or not src.is_hostile_to(o):
				continue
			var dist: float = o.position.distance_to(dead.position) - o.radius
			if dist > best_d or o.debuffs.any(func(x): return x.get("id") == pid):
				continue
			best_d = dist
			best = o
		if best != null:
			mark(src, best)
			show_dive(sim, src, best.position)

# ---------------------------------------------------------------------------
# Bots
# ---------------------------------------------------------------------------
## Nota da skill do falcão para o bot (0 = agora não): chama o falcão ao entrar em luta; Mergulho sempre que sai da
## recarga; Olhos do Céu em chefe (abertura e a cada recarga) e quando há círculos de barragem no chão.
static func bot_score(e: SimEntity, s: SkillDef, mob: SimEntity, dist: float, m: Dictionary) -> float:
	if s.effects.has("falcon_call"):
		return 0.0 if e.falcon else Balance.BOT_FALCON_CALL_SCORE
	if not e.falcon:
		return 0.0
	if s.effects.has("falcon_dive"):
		return Balance.BOT_FALCON_DIVE_SCORE if dist <= s.range - 0.5 else 0.0
	if s.effects.has("falcon_eyes"):
		if e.buffs.any(func(x): return x.get("id") == EYES_BUFF):
			return 0.0
		var boss: bool = mob != null and mob.monster_def != null and mob.monster_def.is_boss and dist <= reach()
		return Balance.BOT_FALCON_EYES_SCORE if boss or not (m.get("hazards", []) as Array).is_empty() else 0.0
	return 0.0

## Slot de Olhos do Céu pronto para usar agora, fugindo de barragem (-1 = não).
static func bot_eyes_slot(e: SimEntity, m: Dictionary) -> int:
	if not e.falcon or (m.get("hazards", []) as Array).is_empty() or e.buffs.any(func(x): return x.get("id") == EYES_BUFF):
		return -1
	for i in range(e.skills.size()):
		var s: SkillDef = e.skills[i]
		if s != null and s.effects.has("falcon_eyes") and e.knows(s.id) and e.stats.meets(s.requires) \
				and float(e.cooldowns.get(s.id, 0.0)) <= 0.0 and e.mp >= s.mp_cost_at(e.mastery_of(s.id)):
			return i
	return -1

## Onde o bot mira o Mergulho: no alvo do tanque (o monstro grudado no tanque mais perto dele), se o falcão alcança;
## senão no alvo do próprio bot.
static func bot_dive_aim(e: SimEntity, mob: SimEntity, tank: SimEntity, m: Dictionary) -> Vector3:
	if tank == null or tank == e or mob.aggro_target == tank.id:
		return mob.position
	var best: SimEntity = null
	var best_d := INF
	for o in m["entities"]:
		if o.kind != SimEntity.Kind.MONSTER or o.aggro_target != tank.id or not can_dive(e, o):
			continue
		var d: float = o.position.distance_squared_to(tank.position)
		if d < best_d:
			best_d = d
			best = o
	return best.position if best != null else mob.position
