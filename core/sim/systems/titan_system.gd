class_name TitanSystem
extends RefCounted
## Empunhadura de Titã (ascensão do Berserker, F7): com a ascensão, Executor e Machados Gêmeos põem um machado de 2 mãos
## também na mão secundária. O básico (e as skills com "titan_hit") batem com as duas armas: dano × (1 + Stats.titan_hit),
## e o básico fica mais lento (Stats.titan_speed; os nós "titan_relief" da teia devolvem parte).
## Punhos de Fúria ascendido: Garras de Titã — as duas garras viram arma pesada (básico +TITAN_CLAW_POWER, empurra,
## −TITAN_CLAW_ASPD_PEN de velocidade). A 2ª arma não soma ATK nem atributos (Balance.TITAN_OFFHAND_ATTR_MULT).

## Por que `e` não pode pôr `item` (2 mãos) na mão secundária ("" = pode).
static func offhand_error(e: SimEntity, item: ItemDef) -> String:
	if e.class_def == null or e.class_def.id != "berserker" or not (item.weapon_type in Balance.TITAN_WEAPONS):
		return "Sua classe não usa isso na mão secundária"
	if not ProgressionSystem.has_ascension(e):
		return "Requer Empunhadura de Titã"
	var main: ItemDef = e.equipment.get(ItemDef.Slot.WEAPON)
	if main == null or not (main.weapon_type in Balance.TITAN_WEAPONS):
		return "Empunhadura de Titã: ponha antes um machado de duas mãos na mão principal"
	return ""

## As duas mãos seguram machados de 2 mãos (e a ascensão vale)?
static func pair_ok(e: SimEntity) -> bool:
	var main: ItemDef = e.equipment.get(ItemDef.Slot.WEAPON)
	var off: ItemDef = e.equipment.get(ItemDef.Slot.OFFHAND)
	return main != null and off != null and main.weapon_type in Balance.TITAN_WEAPONS and off.weapon_type in Balance.TITAN_WEAPONS \
		and ProgressionSystem.has_ascension(e)

const CLAW_BUILD := "punhos"          # build das Garras de Titã (chave do ASC_POWER_35_MULT)

## Depois de Stats.compute (SimEntity.recompute_stats): Garras de Titã no Punhos ascendido.
static func apply(e: SimEntity, st: Stats) -> void:
	if st.titan_pair or not e.is_character() or e.class_def == null or e.class_def.id != "berserker":
		return
	if st.weapon_type == "claw" and st.offhand_type == "claw" and ProgressionSystem.has_ascension(e):
		st.titan_claws = true
		st.titan_hit = Balance.TITAN_CLAW_POWER * Balance.asc_level_mult(CLAW_BUILD, e.level)     # F5: fator do 35 (ASC_POWER_35_MULT)
		st.titan_speed = 1.0 - Balance.TITAN_CLAW_ASPD_PEN

## O golpe bate com as duas armas? Básico sempre; skill só com o efeito "titan_hit".
static func double_hit(e: SimEntity, s: SkillDef) -> bool:
	if not e.is_character() or e.stats == null or not (e.stats.titan_pair or e.stats.titan_claws):
		return false
	return s.id.begins_with("basic_") or bool(s.effects.get("titan_hit", false))

## Multiplicador de poder do golpe (1.0 = sem empunhadura).
static func power_mult(e: SimEntity, s: SkillDef) -> float:
	return 1.0 + e.stats.titan_hit if double_hit(e, s) else 1.0

## Garras de Titã: o básico empurra o alvo (chefe não sai do lugar).
static func on_hit(sim: WorldSim, e: SimEntity, t: SimEntity, s: SkillDef) -> void:
	if not e.stats.titan_claws or not s.id.begins_with("basic_") or not t.is_alive() or not e.is_hostile_to(t):
		return
	if (t.monster_def and t.monster_def.resists_cc()) or t.is_perched() or not sim.maps.has(t.map_id):
		return
	var away := t.position - e.position
	away.y = 0.0
	if away.length() > 0.01:
		sim._charge(t, away.normalized() * Balance.TITAN_CLAW_PUSH, sim.maps[t.map_id])

## Refino comprado na teia de ascensão (portão `flag`)?
static func refined(e: SimEntity, flag: String) -> bool:
	return e.is_character() and not e.asc_tree.is_empty() and ProgressionSystem.asc_flag(e, flag)

## Skill resolvida (ProgressionSystem.resolve_skill): Giro dos Dois Machados (Gêmeos 40) — o Ciclone de Titã gira
## Balance.CYCLONE_LONG_MULT vezes mais (giros e duração).
static func resolve(e: SimEntity, s: SkillDef) -> SkillDef:
	if s.id != Balance.TITAN_CYCLONE_SKILL or not refined(e, Balance.CYCLONE_LONG_FLAG):
		return s
	var te: Dictionary = s.talent_effects          # duplicate() não leva variável sem @export
	var out: SkillDef = s.duplicate()
	out.talent_effects = te.duplicate()
	out.effects = s.effects.duplicate(true)
	var ch: Dictionary = out.effects.get("channel", {})
	ch["ticks"] = int(round(float(ch.get("ticks", 3)) * Balance.CYCLONE_LONG_MULT))
	out.effects["channel"] = ch
	out.active = s.active * Balance.CYCLONE_LONG_MULT
	return out

## Lançou (WorldSim.try_cast): Fúria Acesa (Punhos 40) — o Ciclone de Titã segura a Fúria (e a Glória, que é a Fúria
## na postura) Balance.FURY_LIT_TIME s a mais antes de esfriar.
static func on_cast(e: SimEntity, s: SkillDef) -> void:
	if s.id != Balance.TITAN_CYCLONE_SKILL or e.buffs.is_empty() or not refined(e, Balance.FURY_LIT_FLAG):
		return
	for b in e.buffs:
		if b.get("id") in [Balance.FIST_FURY_BUFF, Balance.GLORY_BUFF]:
			b["remaining"] = float(b.get("remaining", 0.0)) + Balance.FURY_LIT_TIME

## Segundo Machado (Executor 40): alvo abaixo de Balance.SECOND_AXE_BELOW da vida apanha também da 2ª arma em toda
## skill (o básico e as "titan_hit" já batem com as duas). 1.0 = sem efeito.
static func second_axe_mult(e: SimEntity, t: SimEntity, s: SkillDef) -> float:
	if e.stats == null or not e.stats.titan_pair or t.stats == null or t.hp > t.stats.max_hp * Balance.SECOND_AXE_BELOW:
		return 1.0
	if s.kind == SkillDef.Kind.BUFF or double_hit(e, s) or not refined(e, Balance.SECOND_AXE_FLAG):
		return 1.0
	return 1.0 + e.stats.titan_hit

## Bot ascendido de Executor/Gêmeos empunha dois machados de 2 mãos.
static func bot_wants_pair(b: SimEntity) -> bool:
	return b.build_id in Balance.TITAN_BUILDS and ProgressionSystem.has_ascension(b)
