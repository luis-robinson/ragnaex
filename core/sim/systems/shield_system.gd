class_name ShieldSystem
extends RefCounted
## Escudos: reação ao bloquear/aparar (shield_effect), bônus por classe (Juramento/Graça), poder do escudo nas skills.

## O escudo responde ao bloqueio: cada escudo nomeado tem a sua reação; aparar dobra e atordoa quem bateu de perto.
static func shield_reaction(sim: WorldSim, target: SimEntity, attacker: SimEntity, amount: int, parried: bool, from: Variant = null) -> void:
	var origin: Vector3 = attacker.position if from == null else from
	var off: ItemDef = target.equipment.get(ItemDef.Slot.OFFHAND)
	var fx: Dictionary = off.shield_effect if off else {}
	var theme: String = fx.get("theme", "physical")
	if parried and attacker.is_alive() and attacker.position.distance_to(target.position) <= Balance.PARRY_MELEE_RANGE:
		sim._apply_effects(target, attacker, {"stun": {"duration": Balance.PARRY_STUN}}, 1.0)
	if target.shield_react_cd > 0.0 and not parried:
		Events.shield_block.emit(target.id, attacker.id, theme, parried, origin)
		return
	target.shield_react_cd = Balance.SHIELD_REACT_CD
	shield_class_bonus(sim, target, off, parried)
	var k: float = Balance.PARRY_EFFECT_MULT if parried else 1.0
	var max_hp: float = target.stats.max_hp
	if fx.has("heal_pct"):
		target.hp = minf(max_hp, target.hp + max_hp * float(fx["heal_pct"]) * k / 100.0)
	if fx.has("mana_pct"):
		target.mp = minf(target.stats.max_mp, target.mp + target.stats.max_mp * float(fx["mana_pct"]) * k / 100.0)
	if fx.has("barrier_pct"):
		sim._apply_effects(target, target, {"shield": {"amount_pct_hp": float(fx["barrier_pct"]) * k, "duration": Balance.SHIELD_BARRIER_TIME}}, 1.0)
	if attacker.is_alive():
		var hits := {}
		for key in ["dot", "slow", "root"]:
			if fx.has(key):
				hits[key] = fx[key]
		if not hits.is_empty():
			sim._apply_effects(target, attacker, hits, 1.0)
		if fx.has("stun_chance") and sim.rng.randf() * 100.0 < float(fx["stun_chance"]) * k:
			sim._apply_effects(target, attacker, {"stun": {"duration": 0.8}}, 1.0)
		if fx.has("reflect_pct"):
			sim._deal_damage(target, attacker, maxi(1, int(round(amount * float(fx["reflect_pct"]) * k / 100.0))), false, false, "physical")
	Events.shield_block.emit(target.id, attacker.id, theme, parried, origin)

## Escudo da afinidade certa: paladino junta Juramento; bispo cura o aliado mais ferido e, ao aparar, protege o grupo.
static func shield_class_bonus(sim: WorldSim, e: SimEntity, off: ItemDef, parried: bool) -> void:
	if off == null or e.class_def == null:
		return
	var aff: String = GearCatalog.SHIELD_AFFINITY.get(off.shield_style if off.shield_style != "" else "juramento", "")     # sem estilo = escudo de conjunto
	if not (e.class_def.id == aff or (aff == "both" and e.class_def.id in ["paladin", "bishop"])):
		return
	if e.class_def.id == "paladin":
		var stacks := mini(oath_stacks(sim, e) + (2 if parried else 1), ClassTalentSystem.oath_max(e))
		e.put_buff({"id": "juramento", "remaining": Balance.SHIELD_OATH_TIME, "stacks": stacks})
		Events.buff_applied.emit(e.id, "juramento", Balance.SHIELD_OATH_TIME)
		return
	var hurt := sim.most_hurt_friend(e, Balance.SHIELD_GRACE_RANGE)
	var ents: Array = sim.maps[e.map_id]["entities"]
	if e.grace_cd <= 0.0:
		e.grace_cd = Balance.SHIELD_GRACE_CD
		sim._heal(e, hurt, int(hurt.stats.max_hp * Balance.SHIELD_GRACE_PCT / 100.0))
	if parried:
		for o in ents:
			var ward: float = o.stats.max_hp * Balance.SHIELD_WARD_PCT / 100.0 if o.is_character() else 0.0
			if o.is_character() and o.is_alive() and e.is_friend(o) and o.shield_hp < ward and o.position.distance_to(e.position) <= Balance.SHIELD_WARD_RANGE:
				sim._apply_effects(e, o, {"shield": {"amount_pct_hp": Balance.SHIELD_WARD_PCT, "duration": Balance.SHIELD_WARD_TIME}}, 1.0)     # não encurta escudo maior

static func oath_stacks(sim: WorldSim, e: SimEntity) -> int:
	return e.buff_stacks("juramento")

## Skill de escudo escala com a DEF do escudo; skill sagrada ou de escudo do paladino gasta o Juramento.
static func shield_power(sim: WorldSim, e: SimEntity, s: SkillDef) -> float:
	var off: ItemDef = e.equipment.get(ItemDef.Slot.OFFHAND)
	if off == null or off.weapon_type != "shield" or e.class_def == null or s.kind == SkillDef.Kind.BUFF:
		return 1.0
	var mult := 1.0
	var shield_skill: bool = "shield" in s.requires and e.class_def.id == "paladin"
	if shield_skill:
		mult += minf(off.def * Balance.SHIELD_DEF_POWER, Balance.SHIELD_DEF_POWER_MAX)
	var stacks := oath_stacks(sim, e)
	if stacks > 0 and (shield_skill or s.vfx == "holy"):
		mult += stacks * Balance.SHIELD_OATH_POWER
		e.drop_buff("juramento")
	return mult
