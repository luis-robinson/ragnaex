class_name MountedCombat
extends RefCounted
## Ascensão do Paladino (GDD ato2-horda R6.1, F8, F9b): Combate Montado e Modo Arcano (asas de luz).
## Montado com a ascensão: básico e skills `mountable` saem a cavalo (as outras ficam apagadas), básico com
## Balance.MOUNT_REACH_BONUS de alcance, velocidade Balance.MOUNT_FIGHT_SPEED_MULT em combate; levar golpe não derruba,
## só atordoar/prender/gancho (e a rede, que prende), com Balance.MOUNT_CC_IMMUNE s imune a controle depois.
## Modo Arcano: liga/desliga o buff das asas (Balance.ARCANE_WINGS), gasta Balance.ARCANE_MP_PER_S, desliga com MP 0;
## ao ligar desmonta e solta a rajada de penas; desligar dá Balance.ARCANE_CD de recarga. Montar desliga o modo.

## `e` luta montado (classe com Combate Montado e ascensão liberada)?
static func fights_mounted(e: SimEntity) -> bool:
	return e.is_character() and e.class_def != null and e.class_def.id in Balance.MOUNT_FIGHT_CLASSES and ProgressionSystem.has_ascension(e)

## Por que `s` não sai agora por causa do cavalo ("" = pode). Só montado: Carga/Pisotear; montado: só `mountable`
## (o Modo Arcano sai e desmonta). Sem a ascensão, agir desmonta como sempre (não bloqueia aqui).
static func block_reason(e: SimEntity, s: SkillDef) -> String:
	if s.mount_only and not e.mounted:
		return "%s: só montado (H)" % s.name
	if e.mounted and fights_mounted(e) and not s.mountable and not s.effects.has("arcane") and not wall_skill(e, s):
		return "%s: desça do cavalo (H)" % s.name
	return ""

## Muralha a Cavalo (Guardião 45, portão Balance.MOUNT_WALL_FLAG): o Provocar sai montado.
static func wall_skill(e: SimEntity, s: SkillDef) -> bool:
	return s.id in Balance.MOUNT_WALL_SKILLS and mounted_wall(e)

## Tem a Muralha a Cavalo (provoca e bloqueia montado)?
static func mounted_wall(e: SimEntity) -> bool:
	return e.is_character() and not e.asc_tree.is_empty() and ProgressionSystem.asc_flag(e, Balance.MOUNT_WALL_FLAG)

## Estandarte (Templário 45, portão Balance.MOUNT_BANNER_FLAG): montado, as auras de grupo alcançam × MOUNT_BANNER_MULT.
static func banner_mult(e: SimEntity) -> float:
	if not e.mounted or e.asc_tree.is_empty() or not fights_mounted(e) or not ProgressionSystem.asc_flag(e, Balance.MOUNT_BANNER_FLAG):
		return 1.0
	return Balance.MOUNT_BANNER_MULT

## Skill resolvida (ProgressionSystem.resolve_skill): Lança Pesada (portão pal_long_lance) leva a Carga Montada mais longe.
static func resolve(e: SimEntity, s: SkillDef) -> SkillDef:
	if s.id != Balance.MOUNT_CHARGE_SKILL or not e.is_character() or e.asc_tree.is_empty() or not ProgressionSystem.asc_flag(e, Balance.MOUNT_LANCE_FLAG):
		return s
	var te: Dictionary = s.talent_effects          # duplicate() não leva variável sem @export
	var out: SkillDef = s.duplicate()
	out.talent_effects = te.duplicate()
	out.range = s.range * Balance.MOUNT_LANCE_MULT
	out.talent_effects["dash"] = float(te.get("dash", s.effects.get("dash", s.range))) * Balance.MOUNT_LANCE_MULT
	return out

## Multiplicador de velocidade da montaria (1 a pé).
static func move_mult(e: SimEntity) -> float:
	if not e.mounted:
		return 1.0
	if e.combat_timer > 0.0 and fights_mounted(e):
		return Balance.MOUNT_FIGHT_SPEED_MULT
	return Balance.MOUNT_SPEED_MULT

## Básico montado: a mesma skill com mais alcance (cópia guardada por skill em `sim.mounted_basics`).
static func mounted_basic(sim: WorldSim, s: SkillDef) -> SkillDef:
	if s == null:
		return null
	var c: SkillDef = sim.mounted_basics.get(s)
	if c == null:
		c = s.duplicate()
		if c.target == SkillDef.Target.CONE or c.target == SkillDef.Target.SELF:
			c.radius += Balance.MOUNT_REACH_BONUS
		else:
			c.range += Balance.MOUNT_REACH_BONUS
		sim.mounted_basics[s] = c
	return c

## Controle (atordoar/prender/gancho) chegando em `t`: imune devolve os efeitos sem controle; montado e com a
## ascensão, cai do cavalo (o controle vale) e fica imune. Devolve os efeitos a aplicar.
static func filter_cc(sim: WorldSim, src: SimEntity, t: SimEntity, effects: Dictionary) -> Dictionary:
	if t == src or not (effects.get("stun") != null or effects.get("root") != null or effects.get("pull") != null):
		return effects
	if t.cc_immune_left > 0.0:
		var out := effects.duplicate()
		out.erase("stun"); out.erase("root"); out.erase("pull")
		return out
	if t.mounted and fights_mounted(t):
		knock_off(sim, t)
	return effects

## Derrubado do cavalo por controle: desce e fica imune a controle por Balance.MOUNT_CC_IMMUNE.
static func knock_off(sim: WorldSim, e: SimEntity) -> void:
	sim.dismount(e)
	e.cc_immune_left = Balance.MOUNT_CC_IMMUNE
	e.put_buff({"id": "unhorsed", "remaining": Balance.MOUNT_CC_IMMUNE})     # ícone "derrubado" na barra de buffs
	Events.post(&"buff_applied", e.id, "unhorsed", Balance.MOUNT_CC_IMMUNE)
	if e == sim.player:
		Events.post(&"notification", "Derrubado do cavalo!")

static func arcane_on(e: SimEntity) -> bool:
	for b in e.buffs:
		if b.get("id") == Balance.ARCANE_BUFF:
			return true
	return false

## Desliga o Modo Arcano (de propósito, montando ou sem MP) e começa a recarga.
static func arcane_off(sim: WorldSim, e: SimEntity, why: String) -> void:
	if not arcane_on(e):
		return
	e.drop_buff(Balance.ARCANE_BUFF)
	e.recompute_stats()
	e.cooldowns[Balance.ARCANE_SKILL] = Balance.ARCANE_CD
	Events.post(&"buff_applied", e.id, Balance.ARCANE_BUFF + "_off", 0.0)
	if e == sim.player and why != "":
		Events.post(&"notification", why)

## Lançou o Modo Arcano: ligado desliga; senão desmonta, solta a rajada de penas (dano + empurrão) e põe as asas.
static func arcane_cast(sim: WorldSim, e: SimEntity, s: SkillDef, effects: Dictionary, m: Dictionary) -> void:
	if arcane_on(e):
		arcane_off(sim, e, "Modo Arcano desligado")
		return
	if float(e.cooldowns.get(s.id, 0.0)) > s.cooldown + 0.5:
		return                  # pediu para desligar e a MP acabou antes do impacto: já desligou (recarga cheia)
	if e.mounted:
		sim.dismount(e)
	var R := float(Balance.ARCANE_BURST["radius"])
	var push := float(Balance.ARCANE_BURST["push"])
	var power := float(Balance.ARCANE_BURST["power"]) * sim.power_scale
	var kind := SkillDef.Kind.MAGICAL if e.stats.matk > e.stats.patk else SkillDef.Kind.PHYSICAL
	var any_hit := false
	for t: SimEntity in m["entities"].duplicate():           # o golpe pode matar (a lista muda)
		if not t.is_alive() or not e.is_hostile_to(t) or t.position.distance_to(e.position) > R + t.radius:
			continue
		sim._strike(e, t, s, power, kind, e.position)
		any_hit = true
		if t.is_alive() and not (t.monster_def and t.monster_def.is_boss) and t.iframe_left <= 0.0:
			var away: Vector3 = t.position - e.position
			away.y = 0.0
			if away.length_squared() > 0.0001:
				sim._charge(t, away.normalized() * push, m)
	Events.post(&"skill_effect", s.id, e.position, e.position, R)
	sim._apply_effects(e, e, {"buff": wings_buff(e, effects.get("buff"))}, 0.0)
	if any_hit and s.hit_stop_frames > 0 and e == sim.player:
		Events.post(&"hit_stop", s.hit_stop_frames)

## Buff das asas com os refinos da teia (ficam no próprio buff: o tick e a aura não releem a teia):
## Asas com Bloqueio (+bloqueio) e Asas Protetoras ("ward": metade da MP e a aura de redução de dano no grupo).
static func wings_buff(e: SimEntity, base) -> Variant:
	if not (base is Dictionary) or not e.is_character() or e.asc_tree.is_empty():
		return base
	var b: Dictionary = base
	if ProgressionSystem.asc_flag(e, Balance.ARCANE_GUARD_FLAG):
		b = b.duplicate()
		b["block"] = Balance.ARCANE_GUARD_BLOCK
	if ProgressionSystem.asc_flag(e, Balance.ARCANE_WARD_FLAG):
		b = b.duplicate()
		b["ward"] = true
	return b

## Buff das asas ligado com Asas Protetoras (ou {}).
static func ward_buff(e: SimEntity) -> Dictionary:
	for b in e.buffs:
		if b.get("id") == Balance.ARCANE_BUFF and b.get("ward", false):
			return b
	return {}

## Asas Protetoras: o grupo a ARCANE_WARD.radius m recebe a redução de dano (AuraSystem.tick, a cada AURA_TICK).
static func ward_tick(sim: WorldSim, e: SimEntity, m: Dictionary) -> void:
	var ally := {"id": Balance.ARCANE_WARD["id"], "dr_pct": Balance.ARCANE_WARD["dr_pct"], "aura_from": e.id}
	for t in AuraSystem.receivers(sim, e, m, float(Balance.ARCANE_WARD["radius"])):
		if t.is_character():
			AuraSystem._keep(t, ally)

## Por tick (personagens): imunidade a controle e o gasto de MP do Modo Arcano.
static func tick(sim: WorldSim, e: SimEntity, dt: float) -> void:
	if e.cc_immune_left > 0.0:
		e.cc_immune_left = maxf(0.0, e.cc_immune_left - dt)
	if e.buffs.is_empty() or not arcane_on(e):
		return
	e.mp = maxf(0.0, e.mp - Balance.ARCANE_MP_PER_S * (Balance.ARCANE_WARD_MP_MULT if not ward_buff(e).is_empty() else 1.0) * dt)
	if e.mp <= 0.0:
		arcane_off(sim, e, "Modo Arcano: MP esgotada")
