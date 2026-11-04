class_name RecipeDef
extends Resource

@export var id: String = ""
@export var result_item: String = ""
@export var result_count: int = 1
@export var ingredients: Dictionary = {}  ## {item_id: count}
@export var gold_cost: int = 0
@export var station: String = "smith"      ## smith | alchemy
@export var level_req: int = 1
