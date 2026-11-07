class_name Combat
extends RefCounted
## Fórmulas de dano/cura/bloqueio e seleção de alvos. Funções puras sobre SimEntity.

## Ordem na faixa: quem está no eixo, depois quem está de lado, por último quem está atrás; dentro de cada grupo, o mais perto.
static func _lane_rank(e: SimEntity, start: Vector3, dir: Vector3) -> float:
	var rel: Vector3 = e.position - start
	rel.y = 0.0
	var along := rel.dot(dir)
	if along < 0.0:
		return 2000.0 - along
	return along if absf(rel.cross(dir).y) <= e.radius else 1000.0 + along

## O golpe vindo de `from` entra no arco de guarda de `target`? De cima do alvo conta como frente.
static func in_guard_arc(target: SimEntity, from: Vector3) -> bool:
	var d := Vector2(from.x - target.position.x, from.z - target.position.z)
	if d.length_squared() < 0.0025:
		return true
	var f := target.forward()
	return absf(Vector2(f.x, f.z).angle_to(d)) <= deg_to_rad(Balance.BLOCK_ARC_DEG * 0.5)

## Calcula o dano de `attacker` em `target`.
## kind: SkillDef.Kind.PHYSICAL ou MAGICAL. `from`: de onde o golpe vem (padrão: posição de quem bate).
## Soma de um campo das maldições ativas (taken_pct / weaken_pct).
static func curse_sum(e: SimEntity, key: String) -> float:
	var s := 0.0
	for d in e.debuffs:
		if d.get("kind") == "curse":
			s += float(d.get(key, 0.0))
	return s

## Atacante está atrás do alvo (pelas costas)?
static func is_behind(attacker: SimEntity, target: SimEntity) -> bool:
	var to := attacker.position - target.position
	to.y = 0.0
	if to.length() < 0.01:
		return false
	return target.forward().dot(to.normalized()) < Balance.BACKSTAB_ARC

## Gelo estilhaça: skill de gelo (elemento "frost" ou tema "ice") em alvo retardado, preso ou atordoado bate mais forte.
static func frost_mult(skill: SkillDef, target: SimEntity) -> float:
	if skill == null or not (skill.elements.has("frost") or skill.vfx == "ice"):
		return 1.0
	return Balance.FROST_SHATTER_MULT if is_chilled(target) else 1.0

## Raio: skill de raio (elemento "storm" ou tema "lightning") que causa dano e ainda não atordoa rola a chance de atordoar.
static func storm_can_stun(skill: SkillDef) -> bool:
	return skill != null and (skill.elements.has("storm") or skill.vfx == "lightning") and skill.power > 0.0 \
		and not skill.effects.has("stun") and skill.kind in [SkillDef.Kind.PHYSICAL, SkillDef.Kind.MAGICAL]

static func is_chilled(t: SimEntity) -> bool:
	if t.state == SimEntity.State.STUNNED:
		return true
	for d in t.debuffs:
		if d.get("kind") in ["slow", "root"]:
			return true
	return false

static func calc_damage(attacker: SimEntity, target: SimEntity, power: float, kind: int, rng: RandomNumberGenerator, from: Variant = null) -> Dictionary:
	var magical := kind == SkillDef.Kind.MAGICAL
	var atk := attacker.stats.matk if magical else attacker.stats.patk
	var def := target.stats.mdef if magical else target.stats.pdef
	var crit_chance := attacker.stats.crit_mag if magical else attacker.stats.crit_phys
	var behind := attacker.stats.backstab > 0.0 and is_behind(attacker, target)
	if behind:              # Assassino pelas costas: mais crítico e mais dano
		crit_chance += Balance.BACKSTAB_CRIT
		power *= 1.0 + attacker.stats.backstab / 100.0
	var raw := atk * power - def * Balance.DEF_FACTOR
	raw = maxf(raw, atk * power * 0.15)   # piso: 15% do dano bruto
	var variance := 1.0 + rng.randf_range(-Balance.DMG_VARIANCE, Balance.DMG_VARIANCE)
	var crit := rng.randf() * 100.0 < crit_chance
	var amount := raw * variance * (Balance.CRIT_MULT if crit else 1.0)

	# bloqueio: passivo (escudo) ou ativo (segurando RMB)
	var blocked := false
	var origin: Vector3 = attacker.position if from == null else from
	if (target.is_character() or target.kind == SimEntity.Kind.SUMMON) and in_guard_arc(target, origin):
		var reduction := 0.0
		if target.is_blocking and target.state != SimEntity.State.STUNNED:
			# bloqueio ativo: sempre bloqueia, redução = redução base + bônus de guarda
			blocked = true
			reduction = target.stats.block_reduction + Balance.GUARD_HOLD_REDUCTION_BONUS
			if target.stats.has_shield:
				reduction += 10.0
		elif target.stats.block_chance > 0.0 and rng.randf() * 100.0 < target.stats.block_chance:
			blocked = true
			reduction = target.stats.block_reduction
		if blocked:
			reduction = minf(reduction, 85.0)
			amount *= 1.0 - reduction / 100.0
			crit = false
	return {"amount": maxi(1, int(round(amount))), "crit": crit, "blocked": blocked}


static func calc_heal(healer: SimEntity, power: float, rng: RandomNumberGenerator) -> int:
	var base := healer.stats.matk * power * healer.stats.heal_power
	var crit := rng.randf() * 100.0 < healer.stats.crit_mag
	return int(round(base * (1.0 + rng.randf_range(-0.08, 0.08)) * (Balance.CRIT_MULT if crit else 1.0)))


## Seleciona alvos de uma skill no mapa do caster. `entities` = todas as entidades do mapa.
## `from`/`reach`: faixa DIRECTION que parte de outro ponto com outro comprimento (o caminho de uma investida).
static func select_targets(caster: SimEntity, skill: SkillDef, aim: Vector3, entities: Array, from: Variant = null, reach: float = -1.0) -> Array:
	var out: Array = []
	var friendly := skill.kind == SkillDef.Kind.HEAL or skill.kind == SkillDef.Kind.BUFF
	match skill.target:
		SkillDef.Target.SELF:
			if friendly:
				out.append(caster)
			# cura/buff em área ao redor do caster atinge o grupo por perto; dano, os inimigos em volta
			if skill.radius > 0.0:
				for e in entities:
					if e == caster or not _valid(caster, e, friendly):
						continue
					if e.position.distance_to(caster.position) <= skill.radius + (0.0 if friendly else e.radius):
						out.append(e)
		SkillDef.Target.DIRECTION:
			var dir := caster.forward()
			var start: Vector3 = caster.position if from == null else from
			var length: float = skill.range if reach < 0.0 else reach
			for e in entities:
				if not _valid(caster, e, friendly):
					continue
				var rel: Vector3 = e.position - start
				rel.y = 0.0
				var along: float = rel.dot(dir)
				if along < -e.radius or along > length + e.radius:
					continue
				var side := absf(rel.cross(dir).y)
				if side <= skill.radius + e.radius:
					out.append(e)
			out.sort_custom(func(a, b): return _lane_rank(a, start, dir) < _lane_rank(b, start, dir))
		SkillDef.Target.GROUND:
			var center := clamp_aim(caster, aim, skill.range)
			for e in entities:
				if not _valid(caster, e, friendly):
					continue
				if Vector2(e.position.x, e.position.z).distance_to(Vector2(center.x, center.z)) <= skill.radius + e.radius:
					out.append(e)
		SkillDef.Target.CONE:
			var dir := caster.forward()
			var half_angle := deg_to_rad(skill.cone_angle_deg * 0.5)
			for e in entities:
				if not _valid(caster, e, friendly):
					continue
				var rel: Vector3 = e.position - caster.position
				rel.y = 0.0
				var dist: float = rel.length()
				if dist > skill.radius + e.radius:
					continue
				if dist < 0.01 or absf(dir.angle_to(rel.normalized())) <= half_angle + (e.radius / maxf(dist, 0.5)):
					out.append(e)
		SkillDef.Target.TARGET:
			var best: SimEntity = null
			var best_d := 1.6
			for e in entities:
				if not _valid(caster, e, friendly):
					continue
				if e.position.distance_to(caster.position) > skill.range + e.radius:
					continue
				var d: float = Vector2(e.position.x, e.position.z).distance_to(Vector2(aim.x, aim.z)) - e.radius
				if d < best_d:
					best_d = d
					best = e
			if best == null and friendly:
				best = caster         # cura/buff sem aliado sob o cursor: em si mesmo
			if best:
				out.append(best)
				if skill.radius > 0.0:
					for e in entities:
						if e != best and _valid(caster, e, friendly) and e.position.distance_to(best.position) <= skill.radius + e.radius:
							out.append(e)
	if out.size() > skill.max_targets:
		out.resize(skill.max_targets)
	return out


static func _valid(caster: SimEntity, e: SimEntity, friendly: bool) -> bool:
	if e == null or not e.is_alive() or (e.kind == SimEntity.Kind.NPC and not e.guard):
		return false
	if friendly:
		return caster.is_friend(e)
	return caster.is_hostile_to(e)


static func clamp_aim(caster: SimEntity, aim: Vector3, range: float) -> Vector3:
	var rel := aim - caster.position
	rel.y = 0.0
	if rel.length() > range:
		rel = rel.normalized() * range
	return caster.position + rel


## Entidades hostis no raio (para ataque básico / IA)
static func nearest_hostile(from: SimEntity, entities: Array, max_dist: float) -> SimEntity:
	var best: SimEntity = null
	var best_d := max_dist
	var at := from.position
	for e in entities:
		# longe primeiro (o barato): a maioria do mapa cai aqui sem chamar is_hostile_to; folga de 0,1% mantém o resultado exato
		var reach: float = best_d + e.radius
		if e.position.distance_squared_to(at) > reach * reach * 1.001 + 0.0001:
			continue
		if e == from or not e.is_alive() or not from.is_hostile_to(e) or e.stealth_left > 0.0:     # furtivo: ninguém acha
			continue
		var d: float = e.position.distance_to(at) - e.radius
		if d < best_d:
			best_d = d
			best = e
	return best
