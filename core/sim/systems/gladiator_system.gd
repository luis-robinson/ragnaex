class_name GladiatorSystem
extends RefCounted
## Modo Gladiador (ascensão do Berserker, F9b): postura liga/desliga (skill com "aura" sem raio: o buff
## Balance.GLADIATOR_BUFF fica até desligar ou morrer, +dano e −defesa). Na postura a Fúria vira Glória (buff
## Balance.GLORY_BUFF com cargas, até GLORY_MAX; esfria GLORY_TIME s depois do último ganho):
##   +1 por golpe crítico e por abate, +1 por inimigo provocado no Brado da Arena (até GLORY_SHOUT_MAX),
##   e a Fúria do Punho que o Punhos ganharia vira Glória.
## Lâminas Elementais ("glory_scale"): power + GLORY_STEP por Glória que tem. Golpe Final ("glory_spend"): gasta tudo.
## Sair da postura zera a Glória; Punhos (duas garras) guarda por GLORY_KEEP_FISTS s.

## Skill que só sai na postura ("gladiator"/"glory_full" em requires): entra na barra mesmo com a postura desligada.
static func stance_gated(s: SkillDef) -> bool:
	return s.requires.has("gladiator") or s.requires.has("glory_full")

static func stance_on(e: SimEntity) -> bool:
	return e != null and e.is_character() and e.buffs.any(func(b): return b.get("id") == Balance.GLADIATOR_BUFF)

## +n de Glória (só na postura; renova o tempo).
static func gain_glory(sim: WorldSim, e: SimEntity, n: int) -> void:
	if n <= 0 or not stance_on(e) or not e.is_alive():
		return
	var cur := e.buff_stacks(Balance.GLORY_BUFF)
	var now := mini(Balance.GLORY_MAX, cur + n)
	e.put_buff({"id": Balance.GLORY_BUFF, "remaining": glory_time(e), "stacks": now})
	e.recompute_stats()
	if now != cur:
		Events.post(&"buff_applied", e.id, Balance.GLORY_BUFF, glory_time(e))

## Golpe de `attacker` (crítico) ou abate: Glória.
static func on_hit(sim: WorldSim, attacker: SimEntity, crit: bool, killed: bool) -> void:
	if attacker == null or not attacker.is_character():
		return
	gain_glory(sim, attacker, (1 if crit else 0) + (1 if killed else 0))

## Multiplicador das Lâminas Elementais: (power + STEP × Glória) ÷ power.
static func blade_mult(e: SimEntity, base_power: float) -> float:
	var n := e.buff_stacks(Balance.GLORY_BUFF)
	if n <= 0 or base_power <= 0.0:
		return 1.0
	return (base_power + Balance.GLORY_STEP * n) / base_power

## Golpe Final: gasta toda a Glória (a skill só sai com ela cheia; Stats.meets "glory_full"). Devolve quanto gastou.
static func spend(e: SimEntity) -> int:
	var n := e.buff_stacks(Balance.GLORY_BUFF)
	e.drop_buff(Balance.GLORY_BUFF)
	e.recompute_stats()
	e.combo_spent = n
	return n

## A postura desligou: Glória zera (Punhos guarda por GLORY_KEEP_FISTS s).
static func on_stance_off(e: SimEntity) -> void:
	if e.buff_stacks(Balance.GLORY_BUFF) <= 0:
		return
	if FistSystem.has_claws(e):
		for b in e.buffs:
			if b.get("id") == Balance.GLORY_BUFF:
				b["remaining"] = minf(float(b.get("remaining", 0.0)), Balance.GLORY_KEEP_FISTS + (Balance.GLORY_KEEP_TIME if keeps_glory(e) else 0.0))
		return
	e.drop_buff(Balance.GLORY_BUFF)
	e.recompute_stats()

## Glória que Não Esfria (Punhos 45, portão Balance.GLORY_KEEP_FLAG)?
static func keeps_glory(e: SimEntity) -> bool:
	return TitanSystem.refined(e, Balance.GLORY_KEEP_FLAG)

## Segundos até a Glória esfriar (renova a cada ganho): GLORY_TIME, + GLORY_KEEP_TIME com a Glória que Não Esfria.
static func glory_time(e: SimEntity) -> float:
	return Balance.GLORY_TIME + (Balance.GLORY_KEEP_TIME if keeps_glory(e) else 0.0)

## Skill resolvida (ProgressionSystem.resolve_skill): Golpe Final da Arena (Executor 45) — o Golpe Final ganha
## Balance.ARENA_FINALE.power de poder e atordoa por ARENA_FINALE.stun s.
static func resolve(e: SimEntity, s: SkillDef) -> SkillDef:
	if not s.effects.get("glory_spend", false) or not TitanSystem.refined(e, Balance.ARENA_FINALE_FLAG):
		return s
	var te: Dictionary = s.talent_effects          # duplicate() não leva variável sem @export
	var out: SkillDef = s.duplicate()
	out.talent_effects = te.duplicate()
	out.power = s.power * float(Balance.ARENA_FINALE["power"])
	out.talent_effects["stun"] = {"duration": float(Balance.ARENA_FINALE["stun"])}
	return out
