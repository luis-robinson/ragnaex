class_name SunderSystem
extends RefCounted
## Rachadura do Executor (efeito "sunder"/"sunder_consume"; GDD design/gdd/skills-fill-2026-11-19.md M2).
## Sem estado próprio: as cargas moram no debuff Balance.SUNDER_ID do alvo (kind "curse", marca, `stacks`).
## Cada acerto de "sunder" põe/renova o debuff e soma `add` cargas até `max`; cada carga = +taken_per % de dano recebido
## (marca: entra no teto Balance.MARK_TAKEN_CAP com as outras marcas; Combat.taken_pct). "sunder_consume" lê as cargas
## antes do golpe (power x (1 + per x cargas)) e zera o debuff.

## Cargas de rachadura no alvo (0 sem o debuff).
static func stacks(t: SimEntity) -> int:
	if t == null or t.debuffs.is_empty():
		return 0
	for d in t.debuffs:
		if d.get("id") == Balance.SUNDER_ID:
			return int(d.get("stacks", 0))
	return 0

## Acerto que racha: +add cargas (até max), renova o tempo. Vale em chefe (não é controle).
static func apply(src: SimEntity, t: SimEntity, sd: Dictionary) -> void:
	if t == null or not t.is_alive() or not src.is_hostile_to(t):
		return
	var n := mini(int(sd.get("max", 5)), stacks(t) + int(sd.get("add", 1)))
	t.put_debuff({"kind": "curse", "id": Balance.SUNDER_ID, "remaining": float(sd.get("duration", 8.0)), "stacks": n,
		"taken_pct": float(sd.get("taken_per", 4.0)) * n, "weaken_pct": 0.0, "mark": true, "src": src.id})

## Finalizador: devolve o multiplicador de poder pelas cargas no alvo e zera a rachadura.
static func consume(t: SimEntity, cd: Dictionary) -> float:
	var n := stacks(t)
	if n <= 0:
		return 1.0
	t.debuffs = t.debuffs.filter(func(d): return d.get("id") != Balance.SUNDER_ID)
	return 1.0 + float(cd.get("per", 0.0)) * n
