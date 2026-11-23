class_name ChargeSystem
## Cargas de skill (2026-11-21): com o nó da teia "<Skill> em Cargas" (<classe>_k_<id>) a skill guarda até
## Balance.SKILL_CHARGE_MAX usos. As cargas voltam uma de cada vez (fila): cada uma leva a recarga do lançamento
## (já com Ágil, rank e redução) x Balance.SKILL_CHARGE_RECHARGE_MULT. `e.cooldowns[id]` continua sendo "tempo até
## poder lançar" (0 enquanto sobra carga), então bots, HUD e o resto da sim não mudam. Estado em `e.charges`
## (id -> [usadas, s até a próxima voltar, s de uma carga]); não vai no save: carrega cheio.

## Id do nó da teia. Ex.: `ChargeSystem.node_id("elementalist", "ele_meteor")` -> "elementalist_k_ele_meteor".
static func node_id(class_id: String, skill_id: String) -> String:
	return "%s_k_%s" % [class_id, skill_id]

## Cargas máximas da skill para a entidade (1 = sem o nó).
## Luvas do 50 (PieceEffects, "charges"): sem o nó valem como o nó; com o nó, +LEG50_CHARGE_BONUS até LEG50_CHARGE_CAP.
static func max_of(e: SimEntity, skill_id: String) -> int:
	var node := e.class_def != null and e.tree.size() > 1 and e.tree.has(node_id(e.class_def.id, skill_id))
	if e.stats != null and e.stats.piece_charges.has(skill_id):
		return mini(Balance.SKILL_CHARGE_MAX + Balance.LEG50_CHARGE_BONUS, Balance.LEG50_CHARGE_CAP) if node else Balance.SKILL_CHARGE_MAX
	if not node:
		return 1
	return Balance.SKILL_CHARGE_MAX

## Cargas prontas agora (sem o nó: 1 se a recarga acabou, senão 0).
static func available(e: SimEntity, skill_id: String) -> int:
	var mx := max_of(e, skill_id)
	if mx <= 1:
		return 0 if float(e.cooldowns.get(skill_id, 0.0)) > 0.0 else 1
	var st: Array = e.charges.get(skill_id, [])
	return mx - (int(st[0]) if not st.is_empty() else 0)

## Segundos até a próxima carga voltar (0 = cheio) e o tempo de uma carga: Vector2(restante, cheio).
static func next_charge(e: SimEntity, skill_id: String) -> Vector2:
	var st: Array = e.charges.get(skill_id, [])
	if st.is_empty():
		return Vector2.ZERO
	return Vector2(maxf(0.0, float(st[1])), float(st[2]))

## Lançou `s` (já resolvida) com recarga `cd`: gasta uma carga e devolve o valor de `e.cooldowns[s.id]`
## (0 se ainda sobra carga; o tempo até a próxima se gastou a última). Sem o nó devolve `cd` (regra de sempre).
static func on_cast(e: SimEntity, s: SkillDef, cd: float) -> float:
	var mx := max_of(e, s.id)
	if mx <= 1 or cd <= 0.0:
		return cd
	var full := cd * Balance.SKILL_CHARGE_RECHARGE_MULT
	var st: Array = e.charges.get(s.id, [])
	if st.is_empty():
		st = [0, 0.0, full]
		e.charges[s.id] = st
	if int(st[0]) < mx:            # cheio de usadas só se algo zerou a recarga (cd_reset): sai de graça
		st[0] = int(st[0]) + 1
	if float(st[1]) <= 0.0:
		st[1] = full
	st[2] = full                   # a próxima da fila usa a recarga do último lançamento
	return float(st[1]) if int(st[0]) >= mx else 0.0

## Lançamento cancelado antes do impacto (dash): a carga volta.
static func refund(e: SimEntity, skill_id: String) -> void:
	var st: Array = e.charges.get(skill_id, [])
	if st.is_empty():
		return
	st[0] = int(st[0]) - 1
	if int(st[0]) <= 0:
		e.charges.erase(skill_id)

## Recarga zerada por efeito (cd_reset): todas as cargas voltam.
static func refill(e: SimEntity, skill_id: String) -> void:
	e.charges.erase(skill_id)

## Passo do tick: anda a carga da frente da fila; ao voltar, a skill fica pronta e a próxima começa.
static func tick(e: SimEntity, dt: float) -> void:
	for sid in e.charges.keys():
		var st: Array = e.charges[sid]
		st[1] = float(st[1]) - dt
		if float(st[1]) > 0.0:
			continue
		st[0] = int(st[0]) - 1
		if float(e.cooldowns.get(sid, 0.0)) > 0.0 and float(e.cooldowns[sid]) <= float(st[2]) * 0.05 + dt:
			e.cooldowns[sid] = 0.0     # a carga voltou: pronta (sobra de arredondamento da recarga)
		if int(st[0]) <= 0:
			e.charges.erase(sid)
		else:
			st[1] = float(st[1]) + float(st[2])
