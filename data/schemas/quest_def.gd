class_name QuestDef
extends Resource

enum Type { KILL, COLLECT, TALK, CRAFT, REACH }

@export var id: String = ""
@export var title: String = ""
@export var description: String = ""
@export var giver_npc: String = ""        ## NPC que dá a quest
@export var turnin_npc: String = ""       ## NPC que recebe (vazio = o mesmo)
@export var type: Type = Type.KILL
@export var target_id: String = ""        ## monster_id / item_id / npc_id / item craftado / mapa ou lugar (REACH)
@export var count: int = 1
@export var level_req: int = 1
@export var reward_xp: int = 50
@export var reward_gold: int = 20
@export var reward_items: Dictionary = {}  ## {item_id: count}
@export var give_items: Dictionary = {}    ## entrega: o NPC entrega isto ao aceitar (sai da bolsa se desistir)
@export var reward_gear_tier: int = -1    ## >= 0: uma peça comum desse tier (GearCatalog.wearables) que a classe pode usar
@export var repeatable: bool = false       ## recompensa de quadro: pode repetir
@export var prereq_quest: String = ""
@export var prereq_all: Array[String] = [] ## quests extras exigidas (ramos que se juntam)
@export var map_hint: String = ""          ## onde o objetivo está (texto)
@export var dialog_offer: String = ""
@export var dialog_progress: String = ""
@export var dialog_complete: String = ""

func turnin() -> String:
	return turnin_npc if turnin_npc != "" else giver_npc
