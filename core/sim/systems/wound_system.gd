class_name WoundSystem
extends RefCounted
## Feridas (venenos e sangramentos) de quem bate (GDD design/gdd/skills-fill-2026-11-19.md §8.1/8.2). Sem estado próprio.
## Ferida = debuff "dot" do próprio lançador que não é queimadura (`fire`) nem o sangramento por % do ATK do Lanceiro
## (`bleed`). Eviscerar consome (combust kind "poison"), Sangria cura por alvo ferido, Presas Gêmeas estende.

## O debuff `d` é uma ferida de `src`.
static func is_wound(d: Dictionary, src: SimEntity) -> bool:
	return d.get("kind") == "dot" and int(d.get("src", -1)) == src.id and not bool(d.get("fire", false)) and not bool(d.get("bleed", false))

## Quantas feridas de `src` há em `t` (cópias contam uma a uma).
static func count(src: SimEntity, t: SimEntity) -> int:
	var n := 0
	for d in t.debuffs:
		if is_wound(d, src):
			n += 1
	return n

## Eviscerar: tira as feridas de `src` em `t`. Devolve [dano que faltava, quantas saíram].
static func consume(src: SimEntity, t: SimEntity) -> Array:
	var left := 0.0
	var n := 0
	var keep: Array = []
	for d in t.debuffs:
		if is_wound(d, src):
			left += float(d.get("dps", 0.0)) * maxf(0.0, float(d.get("remaining", 0.0))) + float(d.get("acc", 0.0))
			n += 1
		else:
			keep.append(d)
	if n > 0:
		t.debuffs = keep
	return [left, n]

## Presas Gêmeas: +add s em cada ferida de `src` em `t`, sem passar de cap s restantes.
static func extend(src: SimEntity, t: SimEntity, ex: Dictionary) -> void:
	var add := float(ex.get("add", 0.0))
	var cap := float(ex.get("cap", 8.0))
	for d in t.debuffs:
		if is_wound(d, src):
			d["remaining"] = maxf(float(d.get("remaining", 0.0)), minf(cap, float(d.get("remaining", 0.0)) + add))

## Sangria: cura de `e` por `n` alvos feridos atingidos (pct% da vida máx. cada, até max).
static func whirl_heal(sim: WorldSim, e: SimEntity, n: int, wh: Dictionary) -> void:
	var k := mini(n, int(wh.get("max", 4)))
	if k <= 0 or not e.is_alive():
		return
	sim._heal(e, e, maxi(1, int(e.stats.max_hp * float(wh.get("pct", 0.0)) / 100.0 * k)))
