class_name SeedSystem
extends RefCounted
## Semente que explode e espalha (efeito "seed"; GDD design/gdd/skills-fill-2026-11-19.md M3; Semente Ígnea).
## Sem estado próprio: a semente é o debuff "seed_<lançador>" do alvo (kind "seed") com os números da explosão.
## Explode quando o tempo acaba (WorldSim._update_entity) OU quando o alvo morre antes (WorldSim._kill): power x MATK em
## até max_targets inimigos a `radius` m da posição dele (ele incluso se vivo) e, com spread_dot, a queimadura da skill
## neles (WorldSim._put_dot: teto de cópias por skill). A explosão não planta semente nova. Uma por (lançador, alvo):
## relançar renova o tempo. Dono morto/fora do mapa: a semente some sem explodir.

const KIND := "seed"

static func seed_id(src: SimEntity) -> String:
	return "seed_%d" % src.id

## Planta (ou renova) a semente. `sd` = efeito "seed" já com "mult" (o que multiplicou o lançamento) e "skill";
## `dot` = o dano no tempo da skill (espalhado na explosão).
static func plant(src: SimEntity, t: SimEntity, sd: Dictionary, dot: Variant) -> void:
	if t == null or not t.is_alive() or not src.is_hostile_to(t):
		return
	t.put_debuff({"kind": KIND, "id": seed_id(src), "remaining": float(sd.get("delay", 4.0)), "src": src.id,
		"seed": sd, "dot": dot if dot is Dictionary else {}})

## Sementes no alvo (para o teste e o bot).
static func seeds_on(t: SimEntity) -> Array:
	return t.debuffs.filter(func(d): return d.get("kind") == KIND)

## A semente `d` estoura em volta de `t` (tempo acabou ou o alvo morreu).
static func burst(sim: WorldSim, t: SimEntity, d: Dictionary, dying := false) -> void:
	var owner: SimEntity = sim.entities.get(int(d.get("src", -1)))
	if owner == null or not owner.is_alive() or owner.map_id != t.map_id or not sim.maps.has(t.map_id):
		return                                   # dono morto/fora do mapa: some sem explodir
	var sd: Dictionary = d.get("seed", {})
	var pos := t.position
	var radius := float(sd.get("radius", 3.0))
	var near: Array = []
	for o: SimEntity in sim.maps[t.map_id]["entities"]:
		if absf(o.position.x - pos.x) > radius + 2.0 or absf(o.position.z - pos.z) > radius + 2.0:
			continue
		if o == t and dying:
			continue                             # o alvo está morrendo (_kill): não apanha de novo
		if o.is_alive() and o.hp > 0.0 and owner.is_hostile_to(o) and Vector2(o.position.x - pos.x, o.position.z - pos.z).length() <= radius + o.radius:
			near.append(o)
	near.sort_custom(func(a, b): return a.position.distance_squared_to(pos) < b.position.distance_squared_to(pos))
	if near.size() > int(sd.get("max_targets", 6)):
		near.resize(int(sd.get("max_targets", 6)))
	var power := float(sd.get("power", 1.0)) * float(sd.get("mult", 1.0))
	var dot: Dictionary = d.get("dot", {})
	Events.post(&"skill_effect", str(sd.get("skill", "")), pos, pos, radius)
	for o: SimEntity in near:
		var r := Combat.calc_damage(owner, o, power, SkillDef.Kind.MAGICAL, sim.rng, pos)
		sim._deal_damage(owner, o, r["amount"], r["crit"], r["blocked"], "magical", pos)
		if bool(sd.get("spread_dot", false)) and not dot.is_empty() and o.is_alive():
			sim._apply_effects(owner, o, {"dot": dot}, power)     # só o dot: nada de semente nova

## Alvo morreu com sementes: todas estouram antes de limpar os debuffs.
static func on_death(sim: WorldSim, t: SimEntity) -> void:
	var seeds := seeds_on(t)
	if seeds.is_empty():
		return
	t.debuffs = t.debuffs.filter(func(d): return d.get("kind") != KIND)     # tira antes: explosões em cadeia não voltam a ele
	for d in seeds:
		burst(sim, t, d, true)
