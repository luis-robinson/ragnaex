class_name ItemDef
extends Resource
## Itens: materiais, consumíveis e equipamentos. Equipamento é o que dá pontos de atributo.

enum Type { MATERIAL, CONSUMABLE, EQUIPMENT, QUEST }
## Slots novos ficam no fim para não mudar os ints do save. ACCESSORY não é mais usado: o save antigo
## move o que estava lá para AMULET ou RING (SaveSystem.saved_slot). RING2 = segundo anel, mesmo item.slot RING.
enum Slot { NONE, WEAPON, OFFHAND, HEAD, BODY, BOOTS, ACCESSORY, GLOVES, LEGS, CAPE, AMULET, RING, RING2 }

## armas que ocupam as duas mãos (não combinam com escudo/orbe/segunda arma)
const TWO_HANDED := ["sword2h", "mace2h", "axe2h", "staff", "bow", "scythe", "scepter", "rifle"]
## armas de 1 mão que podem ir na mão secundária (empunhar duas)
const ONE_HANDED_MELEE := ["sword", "mace", "axe", "dagger"]
const MELEE_TYPES := ["sword", "sword2h", "mace", "mace2h", "axe", "axe2h", "dagger"]
const RARITY_LEGENDARY := 4

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var type: Type = Type.MATERIAL
@export var slot: Slot = Slot.NONE
@export var icon_color: Color = Color.WHITE
@export var stack_max: int = 99
@export var price: int = 10
@export var level_req: int = 1
@export var rarity: int = 0                 ## 0 comum, 1 incomum, 2 raro, 3 épico, 4 lendário

## equipamento
## sword, sword2h, mace, mace2h, axe, axe2h, dagger, bow, staff, wand, scythe, scepter | mão secundária: shield, orb
@export var weapon_type: String = ""
@export var atk: float = 0.0
@export var matk: float = 0.0
@export var def: float = 0.0
@export var mdef: float = 0.0
@export var attributes: Dictionary = {}     ## {"FOR":2,"AGI":0,"VIT":1,"WILL":0,"INT":0}
@export var class_restriction: Array[String] = []
@export var base_id: String = ""            ## versão aprimorada (+N): id do item de origem ("" = item normal)
@export var plus: int = 0                   ## nível de aprimoramento desta versão (0..Balance.PLUS_MAX)
@export var set_id: String = ""             ## peça de conjunto (SetDef) — bônus por nº de peças equipadas
@export var armor_style: String = ""        ## visual da armadura no kit: plate | leather | cloth | <conjunto> (ex.: pal1)
@export var icon: String = ""               ## ícone em assets/icons/<icon>.png ("" = quadrado da cor)
@export var shield_style: String = ""       ## modelo do escudo (tools/blender/shield_kit.py); "" = escudo comum
@export var legend_effect: Dictionary = {}  ## arma lendária: {"kind": echo|thorns|ward, "chance", "pct"}
@export var weapon_style: String = ""       ## arma própria de conjunto (wpn_main_<tipo>_<estilo> no kit); "" = arma comum do tipo
## reação ao bloquear: {"theme":"holy","heal_pct":3,"mana_pct":4,"barrier_pct":6,"reflect_pct":10,"stun_chance":25,
##   "dot":{"dps":6,"duration":3},"slow":{"pct":40,"duration":3},"root":{"duration":1}}; "block_bonus" é passivo
@export var shield_effect: Dictionary = {}

## consumível: {"heal": 50, "heal_pct": 0.2, "mana": 30, "buff": {"id":"might","duration":30,"atk_pct":15}}
@export var consume: Dictionary = {}
@export var consume_cooldown: float = 3.0

## Segunda cor da roupa: oposta à principal no círculo cromático, escura e saturada para contrastar.
static func accent(c: Color) -> Color:
	if c.s < 0.2:
		return Color(0.62, 0.13, 0.17)        # roupa clara/cinza: carmim (o oposto de um tom quase sem cor é aleatório)
	var h := fposmod(c.h + 0.55, 1.0)
	if h > 0.1 and h < 0.26:
		return Color(0.86, 0.66, 0.2)         # amarelos escuros viram verde-oliva: usa dourado
	return Color.from_hsv(h, clampf(c.s + 0.45, 0.45, 0.78), clampf(c.v * 0.72, 0.32, 0.68))

func is_equipment() -> bool:
	return type == Type.EQUIPMENT

func is_two_handed() -> bool:
	return slot == Slot.WEAPON and weapon_type in TWO_HANDED

func is_legendary() -> bool:
	return rarity >= RARITY_LEGENDARY

func attr(name: String) -> int:
	return int(attributes.get(name, 0))
