class_name MonsterDef
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var level: int = 1
@export var hp: float = 40.0
@export var atk: float = 8.0
@export var matk: float = 0.0
@export var def: float = 2.0
@export var mdef: float = 2.0
@export var move_speed: float = 3.5
@export var attack_range: float = 1.6
@export var attack_cooldown: float = 1.4
@export var attack_startup: float = 0.35
@export var aggro_range: float = 7.0
@export var leash_range: float = 18.0
@export var xp: int = 12
@export var radius: float = 0.5           ## raio de colisão/alvo
@export var scale: float = 1.0
@export var color: Color = Color(0.6, 0.3, 0.3)
@export var shape: String = "box"         ## placeholder: box | sphere | capsule | cone
@export var model: String = ""            ## GLB em assets/models
@export var is_boss: bool = false
@export var elite_of: String = ""         ## Rei que surge depois de muitos abates: id do monstro comum (quests contam por ele)
@export var ranged: bool = false          ## ataca à distância (projétil)
@export var loot_table: String = ""
@export var gold_min: int = 1
@export var gold_max: int = 5
@export var skill_ids: Array[String] = [] ## skills especiais opcionais (usam SkillDef)
@export var phases: Array = []            ## chefe, em ordem de HP: {hp (0-1), say, skills, summon: {id, count, max}, enrage}
