class_name MountSystem
extends RefCounted
## Tipos de montaria (Balance.MOUNT_KINDS): qual bicho o H chama. Só visual: todas andam igual (Kharzun D5).
## Liberada pela missão do tipo (`quest`); quem a entrega já troca para o bicho novo; o tratador (MOUNT_KEEPER_NPCS) troca de volta.

## A montaria `kind` está liberada para `e`?
static func unlocked(e: SimEntity, kind: String) -> bool:
	if not Balance.MOUNT_KINDS.has(kind):
		return false
	var q: String = Balance.MOUNT_KINDS[kind]["quest"]
	return q == "" or q in e.quests_completed

## Troca a montaria (desce do bicho antigo se estiver montado). Devolve false se não está liberada.
## `notify` = false quando quem chama já avisa (entrega da missão: um aviso só).
static func set_kind(sim: WorldSim, e: SimEntity, kind: String, notify := true) -> bool:
	if not unlocked(e, kind):
		return false
	if e.mount_kind == kind:
		return true
	if e.mounted:
		sim.dismount(e)
	e.mount_kind = kind
	if notify and e == sim.player:
		Events.post(&"notification", "Montaria: %s (tecla H)" % Balance.MOUNT_KINDS[kind]["name"])
	return true

## Missão entregue: libera a montaria dela e já a escolhe.
static func on_quest_done(sim: WorldSim, e: SimEntity, quest_id: String) -> void:
	for kind in Balance.MOUNT_KINDS:
		if Balance.MOUNT_KINDS[kind]["quest"] == quest_id and quest_id != "":
			set_kind(sim, e, kind, false)
			if e == sim.player:
				Events.post(&"notification", "Nova montaria: %s! Troque no tratador do acampamento de Kharzun." % Balance.MOUNT_KINDS[kind]["name"])

## Save: tipo conhecido e liberado, senão o padrão (save antigo = cavalo).
static func from_save(e: SimEntity, kind: String) -> String:
	return kind if unlocked(e, kind) else Balance.MOUNT_DEFAULT
