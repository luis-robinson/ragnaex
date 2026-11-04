class_name LegendEffects
extends RefCounted
## Efeitos das armas lendárias (GearCatalog.LEGEND_EFFECTS): ao acertar, ao bater com a arma, ao abater.

## Multiplicador de dano da arma lendária no alvo (Carrasco: alvo com pouca vida apanha mais).
static func _legend_power(sim: WorldSim, e: SimEntity, t: SimEntity) -> float:
	var le: Dictionary = e.stats.legend if e.is_character() else {}
	if str(le.get("kind", "")) == "execute" and t.hp < t.stats.max_hp * float(le.get("below", 0.3)):
		return 1.0 + float(le["pct"]) / 100.0
	return 1.0

## Lança uma skill de graça (sem mana nem recarga) a partir de `e`, mirando em `aim`: os efeitos que "lançam" algo.
static func _legend_cast(sim: WorldSim, e: SimEntity, skill_id: String, aim: Vector3) -> void:
	var s: SkillDef = GameData.skills.get(skill_id)
	if s == null or not sim.maps.has(e.map_id):
		return
	var keep := e.skill_aim
	e.skill_aim = aim
	sim._apply_skill(e, s, sim.maps[e.map_id])
	e.skill_aim = keep

## Efeitos da arma lendária ao acertar (golpe direto de quem a usa). `s` = skill do golpe (o básico começa com "basic_").
static func _legend_on_hit(sim: WorldSim, e: SimEntity, t: SimEntity, s: SkillDef, amount: int) -> void:
	if not e.is_character() or e.stats.legend.is_empty() or amount <= 0 or not t.is_alive() and str(e.stats.legend.get("kind", "")) != "splash":
		return
	var le: Dictionary = e.stats.legend
	var basic: bool = s != null and s.id.begins_with("basic_")
	match str(le.get("kind", "")):
		"cast_on_basic":
			if basic and t.is_alive() and sim.rng.randf() * 100.0 < float(le["chance"]):
				_legend_cast(sim, e, str(le["skill"]), t.position)
		"chain":
			if basic:
				var left: int = int(le.get("targets", 1))
				for o in sim.maps[e.map_id]["entities"]:
					if left <= 0:
						break
					if o != t and o.is_alive() and e.is_hostile_to(o) and o.position.distance_to(t.position) <= 6.0:
						sim._deal_damage(e, o, maxi(1, int(amount * float(le["pct"]) / 100.0)), false, false, "chain")
						left -= 1
		"splash":
			if basic:
				for o in sim.maps[e.map_id]["entities"]:
					if o != t and o.is_alive() and e.is_hostile_to(o) and o.position.distance_to(t.position) <= float(le.get("radius", 2.5)):
						sim._deal_damage(e, o, maxi(1, int(amount * float(le["pct"]) / 100.0)), false, false, "splash")
		"stun":
			if t.is_alive() and sim.time >= e.legend_ready_at and sim.rng.randf() * 100.0 < float(le["chance"]):
				e.legend_ready_at = sim.time + float(le.get("icd", 6.0))
				sim._apply_effects(e, t, {"stun": {"duration": float(le["dur"])}}, 0.0)
		"frenzy":
			var fb: Array = e.buffs.filter(func(b): return b.get("id") == "legend_frenzy")
			var n: int = mini(int(le.get("max", 5)), (int(fb[0].get("stacks", 0)) if not fb.is_empty() else 0) + 1)
			e.buffs = e.buffs.filter(func(b): return b.get("id") != "legend_frenzy")
			e.buffs.append({"id": "legend_frenzy", "remaining": 4.0, "stacks": n, "aspd_pct": float(le["pct"]) * n})
			e.recompute_stats()
		"bleed", "poison":
			if t.is_alive() and sim.rng.randf() * 100.0 < float(le["chance"]):
				var did := "legend_%s_%d" % [le["kind"], e.id]
				t.debuffs = t.debuffs.filter(func(d): return d.get("id") != did)       # renova, não acumula
				t.debuffs.append({"kind": "dot", "id": did, "remaining": 3.0, "dps": maxf(1.0, e.stats.patk * float(le["pct"]) / 100.0), "src": e.id})
		"mark":
			if t.is_alive():
				sim._apply_effects(e, t, {"curse": {"id": "legend_mark", "duration": 4.0, "taken_pct": float(le["pct"])}}, 0.0)

## Arma lendária: Eco (o golpe direto bate de novo), Retaliação (devolve parte do corpo a corpo recebido). Eco e
## retaliação não disparam a si mesmos.
static func _legend_weapon(sim: WorldSim, attacker: SimEntity, target: SimEntity, amount: int, kind: String) -> void:
	if amount <= 0 or attacker == target or not (kind in ["physical", "magical", "shatter"]):
		return
	if target.is_character() and target.is_alive() and str(target.stats.legend.get("kind", "")) == "cast_when_hit" and sim.time >= target.legend_ready_at:
		target.legend_ready_at = sim.time + float(target.stats.legend.get("icd", 20.0))      # Coração de Gelo / Casca Viva
		_legend_cast(sim, target, str(target.stats.legend["skill"]), attacker.position)
	if attacker.is_character() and str(attacker.stats.legend.get("kind", "")) == "echo" and attacker.stats.echo_chance > 0.0 and target.is_alive() and sim.rng.randf() * 100.0 < attacker.stats.echo_chance:
		sim._deal_damage(attacker, target, maxi(1, int(amount * attacker.stats.echo_pct / 100.0)), false, false, "echo")
	if kind == "physical" and target.is_character() and target.is_alive() and attacker.is_alive() and target.stats.thorns_pct > 0.0 \
			and attacker.position.distance_to(target.position) <= Balance.LEG_THORNS_RANGE:
		sim._deal_damage(target, attacker, maxi(1, int(amount * target.stats.thorns_pct / 100.0)), false, false, "thorns")

## Arma lendária no abate: Legião levanta um esqueleto (com recarga), Ceifa cura.
static func _legend_on_kill(sim: WorldSim, e: SimEntity, mob: SimEntity) -> void:
	var le: Dictionary = e.stats.legend
	match str(le.get("kind", "")):
		"raise_on_kill":
			if sim.time >= e.legend_ready_at and GameData.monsters.has("skeleton_minion"):
				e.legend_ready_at = sim.time + float(le.get("icd", 12.0))
				sim.spawn_summon(e, GameData.monsters["skeleton_minion"], mob.position, float(le.get("time", 15.0)), true)
		"heal_on_kill":
			sim._heal(e, e, int(e.stats.max_hp * float(le["pct"]) / 100.0))
