class_name MapDef
extends Resource
## Um mapa é 100% dados: a simulação usa `obstacles` para colisão e a apresentação
## constrói o blockout a partir dos mesmos dados (ou carrega o GLB quando existir).
## O chão é o plano y = 0.

@export var id: String = ""
@export var name: String = ""
@export var is_town: bool = false                  ## tem a cidade (respawn/loja); a vila pode ser só uma região (town_radius)
@export var level_range: Vector2i = Vector2i(1, 10)
@export var size: Vector2 = Vector2(80, 80)        ## área caminhável centrada em (0,0)
@export var ground_color: Color = Color(0.35, 0.55, 0.3)
@export var ground_color_alt: Color = Color(0.3, 0.5, 0.27)
@export var ambient: Color = Color(0.9, 0.9, 1.0)
@export var sun_energy: float = 1.2
@export var spawn_point: Vector3 = Vector3.ZERO
@export var model: String = ""                     ## GLB do cenário em assets/models (opcional)

## obstáculos: {"kind":"house|wall|tree|rock|fence|well|fountain|stall|pillar|ruin|crate",
##   "pos":Vector3, "size":Vector3, "rot":float(deg), "color":Color, "solid":bool}
@export var obstacles: Array = []
## portais: {"id":"to_forest","pos":Vector3,"radius":2.0,"target_map":"field_forest","target_pos":Vector3,"label":"Floresta"}
@export var portals: Array = []
## npcs: {"id":"elder","name":"Ancião Ravi","pos":Vector3,"role":"quest|smith|alchemy|merchant|board|guard",
##   "color":Color,"dialog":["..."],"quests":["q01"],"shop":["potion_hp_s"],"facing":float}
@export var npcs: Array = []
## spawners: {"monster_id":"slime","pos":Vector3,"radius":8.0,"count":5,"respawn":12.0}
@export var spawners: Array = []
## pontos de interesse para bots (praça, ferreiro, etc.)
@export var bot_hangouts: Array = []               ## Array[Vector3]
@export var bot_population: int = 0
@export var gather: Array = []                     ## pontos de colheita: {"item", "kind", "at": Vector3, "radius", "count"} (a sim espalha)
@export var interior: bool = false               ## dentro de uma casa da cidade (luz quente, sem grama/névoa, chão só da sala)
@export var parent_map: String = ""               ## dungeon: zona onde fica a entrada (bots não vão caçar aqui sozinhos)
## lugares do mapa (tools/blender/zones/places.py): {"id":"lenhador","type":"cabin|camp|shrine|dungeon","pos":Vector3}
@export var places: Array = []
## zona estilo Erenshor (data/zones/<id>.json): vila murada como região dentro do mapa
@export var town_center: Vector3 = Vector3.ZERO
@export var town_radius: float = 0.0               ## 0 = o mapa inteiro é cidade se is_town
@export var town_gates: Array = []                 ## Array[Vector3] (centro do portão, na muralha)
@export var hub: bool = false                      ## povoado com cristal (Posto): troca de skills dentro de town_radius, sem ser `is_town`
## estradas/água só para o visual (grama evita): {"kind":"road|street","w":4.2,"pts":PackedVector2Array,"r":float}
@export var roads: Array = []
@export var water: Array = []                      ## {"kind":"river","w":7,"pts":...} | {"kind":"lake","pos":Vector2,"r":13}
## investida periódica (RaidSystem): {"from":Vector3, "route":[Vector3...], "target":Vector3, "radius":float,
##   "every":s, "first":s, "jitter":s, "lifetime":s, "waves":[{"mobs":{"id":n}, "every_nth":int}], "name":"..."}
@export var raid: Dictionary = {}
@export var raids: Array = []             ## investidas extras (cidade atacada por vários lados): formato de `raid` + `side`, `if`/`unless`
@export var conquest_vis: Array = []      ## peças do GLB que mudam com a conquista: {tag (parte do nome), if/unless} (MapBuilder.apply_conquest)
@export var sortie: Dictionary = {}         ## surtida quando a investida chega à muralha: {from (porta), fighters {guard_id: n}, cooldown, say}
@export var assaults: Array = []          ## levas aliadas que marcham (WorldState): {from, route, target, radius, fighters {guard_id: n}, every, max, first, say, if/unless}
@export var decor: Array = []                       ## {"kind":"grass|flower|lamp|banner|path","pos":Vector3,"size":Vector3,"color":Color}

## Dentro da cidade (sem combate de bots, troca de skills, chat de cidade)?
func in_town(p: Vector3) -> bool:
	if not is_town:
		return false
	if town_radius <= 0.0:
		return true
	return Vector2(p.x - town_center.x, p.z - town_center.z).length() < town_radius

## Lugar seguro para trocar skills: a cidade, ou dentro do muro de um povoado com cristal (`hub`).
func in_hub(p: Vector3) -> bool:
	if in_town(p):
		return true
	return hub and town_radius > 0.0 and Vector2(p.x - town_center.x, p.z - town_center.z).length() < town_radius

## Tem área de caça (spawners) — campo puro ou zona com vila + campina.
func has_hunting() -> bool:
	return spawners.size() > 0

func half() -> Vector2:
	return size * 0.5

func clamp_inside(p: Vector3, margin: float = 0.5) -> Vector3:
	var h := half() - Vector2(margin, margin)
	return Vector3(clampf(p.x, -h.x, h.x), p.y, clampf(p.z, -h.y, h.y))
