class_name SummonRites
extends RefCounted
## Oferecer as próprias invocações (efeito "sacrifice"; GDD design/gdd/skills-fill-2026-11-19.md M4; Oferenda Sombria).
## Sem estado próprio. (GROUND) até `max` invocações SUAS a pick_radius m do ponto mirado, das mais perto para as mais
## longe, fora as de Balance.SACRIFICE_EXCLUDE (Rei Esqueleto, Lich, companheiros/elementais) e os elementais da ascensão.
## Cada uma explode em blast_radius: power x (1 - hp_weight + hp_weight x % de vida dela) x MATK, e some (sem XP/saque:
## invocação não dá nada ao morrer). Inimigo pego por várias explosões leva todas. Sem nenhuma elegível, a skill é
## recusada antes de gastar MP (WorldSim.try_cast).

## Invocações que a oferenda pegaria em volta de `at` (ordem: mais perto primeiro).
static func pick(sim: WorldSim, e: SimEntity, at: Vector3, sd: Dictionary) -> Array:
	var out: Array = []
	if not sim.maps.has(e.map_id):
		return out
	var R := float(sd.get("pick_radius", 6.0))
	for o: SimEntity in sim.maps[e.map_id]["entities"]:
		if o.kind != SimEntity.Kind.SUMMON or o.owner_id != e.id or not o.is_alive() or o.monster_def == null:
			continue
		if o.monster_def.id in Balance.SACRIFICE_EXCLUDE or o.elem_form != "":
			continue
		if Vector2(o.position.x - at.x, o.position.z - at.z).length() <= R:
			out.append(o)
	out.sort_custom(func(a, b): return Vector2(a.position.x - at.x, a.position.z - at.z).length_squared() < Vector2(b.position.x - at.x, b.position.z - at.z).length_squared())
	if out.size() > int(sd.get("max", 4)):
		out.resize(int(sd.get("max", 4)))
	return out

## Motivo de recusa (vazio = pode lançar).
static func block_reason(sim: WorldSim, e: SimEntity, s: SkillDef, aim: Vector3) -> String:
	var at := Combat.clamp_aim(e, aim, s.range)
	if pick(sim, e, at, s.effects["sacrifice"]).is_empty():
		return "Sem mortos-vivos por perto"
	return ""

## Lança: cada invocação escolhida estoura e some. Devolve quantos inimigos foram atingidos (soma das explosões).
static func offer(sim: WorldSim, e: SimEntity, s: SkillDef, aim: Vector3, power: float, sd: Dictionary) -> int:
	var hits := 0
	var m: Dictionary = sim.maps[e.map_id]
	var R := float(sd.get("blast_radius", 3.0))
	var w := clampf(float(sd.get("hp_weight", 0.5)), 0.0, 1.0)
	for o: SimEntity in pick(sim, e, aim, sd):
		var frac := clampf(o.hp / maxf(1.0, o.stats.max_hp), 0.0, 1.0)
		var p := power * (1.0 - w + w * frac)
		var pos := o.position
		Events.post(&"skill_effect", s.id, pos, pos, R)
		for t: SimEntity in m["entities"].duplicate():
			if absf(t.position.x - pos.x) > R + 2.0 or absf(t.position.z - pos.z) > R + 2.0:
				continue
			if t.is_alive() and e.is_hostile_to(t) and Vector2(t.position.x - pos.x, t.position.z - pos.z).length() <= R + t.radius:
				var r := Combat.calc_damage(e, t, p, SkillDef.Kind.MAGICAL, sim.rng, pos)
				sim._deal_damage(e, t, r["amount"], r["crit"], r["blocked"], "magical", pos)
				hits += 1
		sim.despawn(o)          # oferecida: some na hora (invocação não dá XP nem saque)
	return hits
