class_name FistSystem
extends RefCounted
## Punhos de Fúria (Berserker com duas garras): quem esquiva um golpe direto ganha uma carga de Fúria do Punho
## (ATK e velocidade de ataque por carga, até Balance.FIST_FURY_MAX; o tempo renova a cada carga) e devolve um
## contra-ataque no agressor se ele estiver perto. O Punho Final gasta todas as cargas ("fury_spend" na skill).
## A arma lendária da build (Punho Vingativo, legend "fist_counter") deixa o contra-ataque mais forte.

## Empunha duas garras (o que liga a esquiva que vira fúria).
static func has_claws(e: SimEntity) -> bool:
	return e.is_character() and e.stats != null and e.stats.weapon_type == "claw" and e.stats.offhand_type == "claw"

## `target` esquivou o golpe de `attacker`: +1 Fúria e contra-ataque (o contra-ataque não gera outro).
static func on_dodge(sim: WorldSim, target: SimEntity, attacker: SimEntity, kind: String) -> void:
	if not has_claws(target) or kind == "riposte":
		return
	gain_fury(sim, target, 1)
	if attacker != null and attacker.is_alive() and attacker.position.distance_to(target.position) <= Balance.FIST_COUNTER_RANGE:
		var pct := Balance.FIST_COUNTER_PCT
		if str(target.stats.legend.get("kind", "")) == "fist_counter":
			pct += float(target.stats.legend["pct"])
		sim._deal_damage(target, attacker, maxi(1, int(target.stats.patk * pct / 100.0)), false, false, "riposte")
		Events.post(&"skill_effect", "ber_fist_flurry", target.position, attacker.position, 0.0)     # o soco do contra-ataque

## +n cargas de Fúria do Punho (até o máximo; renova o tempo). O bônus por carga vai no próprio buff (Stats soma).
static func gain_fury(sim: WorldSim, e: SimEntity, n: int) -> void:
	if n <= 0 or e == null or not e.is_alive():
		return
	var cur := e.buff_stacks(Balance.FIST_FURY_BUFF)
	var now := mini(Balance.FIST_FURY_MAX, cur + n)
	e.put_buff({"id": Balance.FIST_FURY_BUFF, "remaining": Balance.FIST_FURY_TIME, "stacks": now,
		"atk_pct": Balance.FIST_FURY_ATK_PCT * now, "aspd_pct": Balance.FIST_FURY_ASPD_PCT * now})
	e.recompute_stats()
	if now != cur:
		Events.post(&"buff_applied", e.id, Balance.FIST_FURY_BUFF, Balance.FIST_FURY_TIME)

## Punho Final: gasta todas as cargas; devolve o multiplicador de dano (1 + power_pct% por carga).
static func spend_fury(e: SimEntity, power_pct: float) -> float:
	var n := e.buff_stacks(Balance.FIST_FURY_BUFF)
	if n <= 0:
		return 1.0
	e.drop_buff(Balance.FIST_FURY_BUFF)
	e.recompute_stats()
	e.combo_spent = n
	return 1.0 + power_pct / 100.0 * n
