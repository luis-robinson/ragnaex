class_name ShiftSystem
extends RefCounted
## Metamorfose de monstro (xamã que vira urso/lobo/gavião; plano shaman-grove, pacote C). Sem estado próprio.
## Contrato de dados (MonsterDef):
##   base.shift_forms = [{"form": <id de MonsterDef>, "weight": n}, ...]   (vazio = não se transforma)
##   base.shift_cast  = s de conjuração (0 = Balance.SHIFT_CAST_S)
##   forma: MonsterDef completo (modelo, vida, ataque, skills, velocidade, alcance, ranged, aggro/leash, nome curto "Urso");
##          forma.shift_stealth = entra furtiva (emboscada × Balance.SHIFT_AMBUSH_MULT); forma.kite = recua entre os tiros.
## Regras: ao ganhar alvo (aggro) sorteia UMA forma por luta (rng da sim) e conjura; ao fim troca o monster_def guardando o %
## da vida, o aggro/ameaça/alvo/posição/buffs. Volta à base no leash/reset de chefe ou Balance.SHIFT_REVERT_S s fora de combate.
## Morre como a forma (o desenho fica), mas o _kill devolve a base antes do saque: XP, saque, quest KILL e Rei contam pela base.
## Eventos: Events.monster_shift(id, form_id, "cast" | "done" | "revert" | "cancel").

## Tick do monstro com metamorfose (chamado pelo _update_entity só quando há forma ou conjuração).
static func update(sim: WorldSim, e: SimEntity, dt: float) -> void:
	if not e.is_alive() or e.kind != SimEntity.Kind.MONSTER:
		return
	var fighting := e.aggro_target >= 0
	if e.shift_left > 0.0:
		if not fighting:
			_cancel(e)
			return
		e.shift_left -= dt
		if e.shift_left <= 0.0:
			e.shift_left = 0.0
			var form: MonsterDef = GameData.monsters.get(e.shift_pick)
			e.shift_pick = ""
			if form:
				apply(sim, e, form)
		return
	if e.shift_base != null:
		if fighting or e.combat_timer > 0.0:
			e.shift_calm = 0.0
		else:
			e.shift_calm += dt
			if e.shift_calm >= Balance.SHIFT_REVERT_S:
				revert(sim, e)
		return
	if fighting and not e.monster_def.shift_forms.is_empty() and e.state != SimEntity.State.CASTING and e.can_act():
		begin(sim, e)

## Começa a conjuração: sorteia a forma (rng da sim) e avisa o desenho (gesto + redemoinho de folhas).
static func begin(sim: WorldSim, e: SimEntity) -> void:
	var id := pick_form(e.monster_def.shift_forms, sim.rng.randf())
	if id == "" or not GameData.monsters.has(id):
		return
	e.shift_pick = id
	e.shift_left = e.monster_def.shift_cast if e.monster_def.shift_cast > 0.0 else Balance.SHIFT_CAST_S
	Events.post(&"monster_shift", e.id, id, "cast")

## Forma sorteada por peso: `roll` em [0, 1). Pura (testes): mesmo roll, mesma forma. Peso <= 0 nunca sai.
static func pick_form(forms: Array, roll: float) -> String:
	var total := 0.0
	for f in forms:
		total += maxf(0.0, float((f as Dictionary).get("weight", 1.0)))
	if total <= 0.0:
		return ""
	var acc := 0.0
	var at := clampf(roll, 0.0, 0.999999) * total
	for f in forms:
		var w := maxf(0.0, float((f as Dictionary).get("weight", 1.0)))
		acc += w
		if w > 0.0 and at < acc:
			return str((f as Dictionary).get("form", ""))
	return ""

## Vira a forma: vida no mesmo %, skills/ataque/alcance/velocidade da forma; aggro, ameaça, buffs e posição ficam.
static func apply(sim: WorldSim, e: SimEntity, form: MonsterDef) -> void:
	var base: MonsterDef = e.shift_base if e.shift_base != null else e.monster_def
	var pct := e.hp / maxf(1.0, e.stats.max_hp)
	e.shift_base = base
	e.shift_calm = 0.0
	_set_def(sim, e, form, "%s (%s)" % [base.name, form.name])
	e.hp = clampf(pct * e.stats.max_hp, 1.0, e.stats.max_hp)
	if form.shift_stealth:
		e.stealth_left = Balance.SHIFT_STEALTH_S
		e.ambush = false
		Events.post(&"buff_applied", e.id, "stealth", e.stealth_left)
	Events.post(&"monster_shift", e.id, form.id, "done")

## Volta à base (leash, reset, fora de combate, morte). `silent` = sem evento (morte: o corpo continua a forma).
static func revert(sim: WorldSim, e: SimEntity, silent: bool = false) -> void:
	if e.shift_left > 0.0:
		_cancel(e, silent)
	if e.shift_base == null:
		return
	var base := e.shift_base
	var pct := e.hp / maxf(1.0, e.stats.max_hp)
	e.shift_base = null
	e.shift_calm = 0.0
	e.stealth_left = 0.0
	e.ambush = false
	_set_def(sim, e, base, base.name)
	e.hp = clampf(pct * e.stats.max_hp, 1.0, e.stats.max_hp) if e.hp > 0.0 else 0.0
	if not silent:
		Events.post(&"monster_shift", e.id, "", "revert")

## Emboscada: a forma furtiva usa Balance.SHIFT_AMBUSH_MULT; o resto, a regra de sempre (talento de classe).
static func ambush_mult(e: SimEntity) -> float:
	if e.shift_base != null:
		return Balance.SHIFT_AMBUSH_MULT
	return ClassTalentSystem.ambush_mult(e)

## MonsterDef de origem (o da base quando transformado).
static func base_def(e: SimEntity) -> MonsterDef:
	return e.shift_base if e.shift_base != null else e.monster_def

static func _cancel(e: SimEntity, silent: bool = false) -> void:
	e.shift_left = 0.0
	e.shift_pick = ""
	if not silent:
		Events.post(&"monster_shift", e.id, "", "cancel")

static func _set_def(sim: WorldSim, e: SimEntity, d: MonsterDef, display: String) -> void:
	if e.state == SimEntity.State.CASTING:
		sim._end_skill(e)
	e.monster_def = d
	e.name = display
	e.radius = d.radius
	e.scale = d.scale
	e.stance = ""
	e.basic_skill = GameData.basic_skill_for_monster(d)
	e.basic_cd = maxf(e.basic_cd, 0.0)
	e.skills.clear()
	sim._add_skills(e, d.skill_ids)
	e.recompute_stats()
