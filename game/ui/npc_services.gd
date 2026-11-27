class_name NpcServices
extends RefCounted
## Serviço de um NPC (vende, guarda, forja...): ícone sobre a cabeça (EntityView), cor do nome e ícone no minimapa.
## Só apresentação: lê `npc_data.role` (MapsCatalog) e o id (tratador de montarias). Quest não é serviço: tem o "!"/"?".
## Ícones `assets/icons/service_<serviço>.png`, feitos por `tools/icons/make_icons.tscn -- --only=service` (SERVICE_ICONS).

## Papéis que viram serviço (a ordem é a da legenda).
const SERVICES := ["merchant", "storage", "smith", "alchemy", "trainer", "relic", "crystal", "board", "mount", "hunt", "auction"]
const LABELS := {"merchant": "Mercador", "storage": "Depósito", "smith": "Ferreiro", "alchemy": "Alquimista", "trainer": "Mestre de Skills",
	"relic": "Relicária", "crystal": "Cristal", "board": "Quadro", "mount": "Montarias", "hunt": "Caçadas", "auction": "Leiloeiro"}
const NAME_COLOR := Color(1.0, 0.84, 0.42)       # nome de quem presta serviço (morador fica verde)
const HEAD_SIZE := 0.5                           # m: largura do ícone sobre a cabeça
const HEAD_LIFT := 1.35                          # m acima do topo do boneco: acima do nome (+0,32, duas linhas), altura do "!" de quest
const BESIDE_MARK := 0.75                        # com marca de quest o ícone vai para a esquerda (× largura)
const MAP_SIZE := 15.0                           # px: ícone no minimapa (o mapa grande usa x1,4)

static var _tex := {}

## Serviço do NPC ("" = morador, guarda, quest).
static func service_of(npc: Dictionary) -> String:
	if str(npc.get("id", "")) in Balance.MOUNT_KEEPER_NPCS:
		return "mount"
	var r := str(npc.get("role", ""))
	return r if r in SERVICES else ""

static func icon(service: String) -> Texture2D:
	if service == "":
		return null
	if not _tex.has(service):
		var path := "res://assets/icons/service_%s.png" % service
		_tex[service] = load(path) if ResourceLoader.exists(path) else null
	return _tex[service]
