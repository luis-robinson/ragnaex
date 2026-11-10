class_name ClassDef
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var color: Color = Color.WHITE
@export var model: String = ""               ## GLB antigo por classe (fallback se o kit não existir)
@export var body_type: String = "male"        ## kit modular: assets/models/kit_<body_type>.glb
@export var hair_color: Color = Color(0.4, 0.28, 0.18)
@export var weapon_types: Array[String] = []  ## mão principal permitida (sword, sword2h, mace, mace2h, axe, axe2h, dagger, bow, staff, wand, scythe)
@export var offhand_types: Array[String] = [] ## mão secundária: shield, orb e/ou arma de 1 mão (empunhar duas)
@export var can_use_shield: bool = false      ## derivado de offhand_types (ClassesCatalog._mk)
@export var base_hp: float = 100.0            ## HP base no lv1 (por nível soma hp_per_level)
@export var base_mp: float = 50.0
@export var hp_per_level: float = 12.0
@export var mp_per_level: float = 6.0
@export var move_speed: float = 5.5
@export var basic_attack_power: float = 1.0
@export var basic_attack_cooldown: float = 0.65
@export var basic_attack_range: float = 1.8
@export var basic_attack_is_ranged: bool = false
@export var basic_attack_kind: int = 0        ## SkillDef.Kind (0 physical, 1 magical)
@export var starting_equipment: Array[String] = []
@export var starting_bag: Array[String] = []        ## vão para a bolsa no lv1 (armas das outras builds, para provar)
@export var skill_ids: Array[String] = []     ## TODAS as skills da classe (20+); o jogador aprende com pontos e equipa 6
@export var starting_skills: Array[String] = [] ## aprendidas de graça no lv1 e postas nos slots 1..n
@export var role: String = "dps"              ## tank | dps | healer | ranged | caster
## escudo da afinidade certa (ShieldSystem): "oath" = junta Juramento (Paladino), "grace" = Graça cura e protege (Bispo); "" = nenhum
@export var shield_charge: String = ""
## chefes miram primeiro em quem é da classe (MonsterBrain: quem cura cai primeiro); a build também pode ter "boss_priority"
@export var boss_priority: bool = false
## builds: [{id, name, role, main:[tipos], off:[tipos], armor: plate|leather|cloth, attr, attr2, stat, skills:[ids em prioridade]}]
## Guiam bots (equipamento + skills), conjuntos lendários e o agrupamento da janela de skills.
@export var builds: Array = []

func build_by_id(build_id: String) -> Dictionary:
	for b in builds:
		if b["id"] == build_id:
			return b
	return {}
