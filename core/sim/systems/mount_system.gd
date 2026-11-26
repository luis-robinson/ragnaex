class_name MountSystem
extends RefCounted
## Tipos de montaria (Balance.MOUNT_KINDS): qual bicho o H chama. Só visual: todas andam igual (Kharzun D5).
## Liberada pela missão do tipo (`quest`); quem a entrega já troca para o bicho novo; o tratador (MOUNT_KEEPER_NPCS) troca de volta.

## A montaria `kind` está liberada para `e`?
static func unlocked(e: SimEntity, kind: String) -> bool:
	if not Balance.MOUNT_KINDS.has(kind):
		return false
	if str(Balance.MOUNT_KINDS[kind].get("mvp", "")) != "":         # tipo de Chefe de Mundo: só pela coleção (MvpSystem)
		return e.mount_cosmetics.has("kind:" + kind)
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
	if e.mount_dye >= dyes_of(kind).size():
		e.mount_dye = 0
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

## Cores do tipo (Balance.MOUNT_DYES; tipo sem lista = nenhuma).
static func dyes_of(kind: String) -> Array:
	return Balance.MOUNT_DYES.get(kind, [])

## A cor `i` do tipo está na coleção? A 0 vem com o tipo; cavalo/lobo (sem `mvp`) têm todas.
static func dye_owned(e: SimEntity, kind: String, i: int) -> bool:
	if i < 0 or i >= dyes_of(kind).size():
		return false
	return i == 0 or str(Balance.MOUNT_KINDS.get(kind, {}).get("mvp", "")) == "" or e.mount_cosmetics.has("dye:%s:%d" % [kind, i])

## Armadura de montaria na coleção ("" = nenhuma, sempre vale).
static func barding_owned(e: SimEntity, style: String) -> bool:
	return style == "" or (Balance.MOUNT_BARDINGS.has(style) and e.mount_cosmetics.has("barding:" + style))

## Por que a escolha da aba Montaria não vale ("" = vale).
static func look_error(e: SimEntity, kind: String, dye: int, barding: String) -> String:
	if not unlocked(e, kind):
		return "Montaria travada"
	if not dye_owned(e, kind, dye):
		return "Cor travada"
	if not barding_owned(e, barding):
		return "Armadura travada"
	return ""

## Aba Montaria (C): tipo, cor e armadura de uma vez (desce se estiver montado num bicho de outro tipo). Só aparência.
static func set_look(sim: WorldSim, e: SimEntity, kind: String, dye: int, barding: String) -> bool:
	if look_error(e, kind, dye, barding) != "":
		return false
	if kind != e.mount_kind and not set_kind(sim, e, kind, false):
		return false
	e.mount_dye = dye
	e.mount_barding = barding
	Events.post(&"mvp_changed", e.id)
	return true

## Save: `mount_look` = {"kind", "dye", "barding"} (mvp-premios.md; contrato wave5 B). Sem o campo: dye 0 e sem barda.
static func look_to_save(e: SimEntity) -> Dictionary:
	return {"kind": e.mount_kind, "dye": maxi(e.mount_dye, 0), "barding": e.mount_barding}

static func look_from_save(e: SimEntity, d: Dictionary) -> void:
	var ml = d.get("mount_look")
	e.mount_dye = 0
	e.mount_barding = ""
	if not (ml is Dictionary):
		return
	var k := str(ml.get("kind", e.mount_kind))
	if unlocked(e, k):
		e.mount_kind = k
	var dy := int(ml.get("dye", 0))
	e.mount_dye = dy if dye_owned(e, e.mount_kind, dy) else 0
	var b := str(ml.get("barding", ""))
	e.mount_barding = b if barding_owned(e, b) else ""

## Save: tipo conhecido e liberado, senão o padrão (save antigo = cavalo).
static func from_save(e: SimEntity, kind: String) -> String:
	return kind if unlocked(e, kind) else Balance.MOUNT_DEFAULT
