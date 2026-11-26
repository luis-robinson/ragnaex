class_name MountLook
extends RefCounted
## Aparência da montaria (mvp-premios.md §3.4; contrato wave5 B): modelo por tipo, cor (Balance.MOUNT_DYES) e armadura
## (nós `barding_<estilo>_<parte>` do GLB, todos escondidos; mostra os do estilo escolhido). Só apresentação.
## Tipo sem GLB ainda (modelos dos Chefes de Mundo em produção) cai no cavalo: o jogo roda sem eles.

## tipo -> modelo (assets/models/<modelo>.glb)
const MODELS := {"horse": "mob_horse", "dire_wolf": "mob_dire_wolf_mount", "war_boar": "mob_mount_war_boar",
	"forest_elk": "mob_mount_forest_elk", "ruins_lizard": "mob_mount_ruins_lizard", "armored_rhino": "mob_mount_armored_rhino",
	"iron_wolf": "mob_mount_iron_wolf", "porcelain_stag": "mob_mount_porcelain_stag"}

static func path_of(model: String) -> String:
	return "res://assets/models/%s.glb" % model

## Modelo do tipo; sem o arquivo (ou tipo desconhecido) = o cavalo.
static func model_of(kind: String) -> String:
	var m: String = MODELS.get(kind, MODELS["horse"])
	return m if ResourceLoader.exists(path_of(m)) else MODELS["horse"]

## O tipo tem modelo próprio pronto?
static func has_model(kind: String) -> bool:
	return MODELS.has(kind) and ResourceLoader.exists(path_of(MODELS[kind]))

## Cor: a escolhida (`dye` >= 0) ou, sem escolha (bots), uma pelagem pelo id (variedade de sempre).
static func coat(kind: String, dye: int, entity_id: int) -> Color:
	var dyes: Array = Balance.MOUNT_DYES.get(kind, Balance.MOUNT_DYES["horse"])
	if dye >= 0 and dye < dyes.size():
		return dyes[dye]
	return dyes[absi(entity_id) % dyes.size()]

## Estilo de armadura de um nó ("" = não é barda): o estilo de Balance.MOUNT_BARDINGS mais longo que prefixa o nome
## (barding_iron_wolf_* é do Lobo de Ferro, não da barda de ferro).
static func barding_style_of(node_name: String) -> String:
	var best := ""
	for st in Balance.MOUNT_BARDINGS:
		var s: String = st
		if node_name.begins_with(s + "_") and s.length() > best.length():
			best = s
	if best == "" and node_name.begins_with("barding_"):
		return "?"
	return best

## Liga só as peças do estilo (`""` = nenhuma). Devolve quantas peças ficaram à vista.
static func apply_barding(root: Node, style: String) -> int:
	var shown := 0
	for n in root.find_children("barding_*", "Node3D", true, false):
		var st := barding_style_of(String(n.name))
		var on := style != "" and st == style
		(n as Node3D).visible = on
		if on:
			shown += 1
	return shown

## Montaria pronta (sem fusão; quem chama funde com RigidMerge se quiser). null se nem o cavalo existe.
static func create(kind: String, dye: int, barding: String, entity_id: int = 0) -> FormModel:
	var f := FormModel.create_from(path_of(model_of(kind)))
	if f == null:
		return null
	f.paint(coat(kind, dye, entity_id))
	apply_barding(f, barding)
	return f

## Chave de fusão (RigidMerge guarda a malha por modelo + o que aparece).
static func merge_key(kind: String, barding: String) -> String:
	return model_of(kind) + ("|" + barding if barding != "" else "")
