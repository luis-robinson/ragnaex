class_name SummonBuffs
extends RefCounted
## Buff do dono que passa para as invocações dele enquanto dura (buff com `minion_share`, hoje o Pacto Sombrio).
## Na invocação vira um buff de mesmo id com `pet_atk_pct` = o `matk_pct` do dono e o mesmo tempo restante: vale ao
## vivo para quem já está de pé, e o mesmo id liga o visual do pacto no corpo dela (BuffLooks.LOOKS).
## A foto do MATK na hora de invocar (WorldSim.spawn_summon) tira esse buff (snapshot_mult) para não contar duas vezes.

## Multiplicador que tira da foto do MATK do dono os buffs que passam para a invocação (os % de buff multiplicam um a um).
static func snapshot_mult(owner: SimEntity) -> float:
	var k := 1.0
	for b in owner.buffs:
		if b.get("minion_share", false):
			k /= 1.0 + float(b.get("matk_pct", 0)) / 100.0
	return k

## Passa os buffs compartilhados do dono para todas as invocações vivas dele no mapa.
static func share(sim: WorldSim, owner: SimEntity) -> void:
	if not sim.maps.has(owner.map_id):
		return
	for s in sim.maps[owner.map_id]["entities"]:
		if s.kind == SimEntity.Kind.SUMMON and s.owner_id == owner.id and s.is_alive():
			give(sim, owner, s)

## Uma invocação recebe os buffs compartilhados que o dono tem agora.
static func give(sim: WorldSim, owner: SimEntity, s: SimEntity) -> void:
	var any := false
	for b in owner.buffs:
		if not b.get("minion_share", false):
			continue
		var id: String = str(b.get("id", "shared"))
		s.put_buff({"id": id, "pet_atk_pct": float(b.get("matk_pct", 0)), "remaining": float(b.get("remaining", 0.0))})
		Events.post(&"buff_applied", s.id, id, float(b.get("remaining", 0.0)))
		any = true
	if any:
		s.recompute_stats()
