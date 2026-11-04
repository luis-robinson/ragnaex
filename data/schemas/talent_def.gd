class_name TalentDef
extends Resource
## Evolução comprada com pontos de skill: modifica uma skill (ou o dash, skill_id = "dash").
## Ex.: Curar também cura aliados próximos; dash do paladino atordoa (exige escudo).
##
## mods para skill:
##   {"set": {"radius": 6.0}, "mult": {"power": 1.2, "cooldown": 0.8, "range": 1.5}, "effects": {"stun": {"duration": 1}}}
## mods para dash (somam/multiplicam os padrões de Balance.DASH_*):
##   {"distance_mult": 1.6, "charges": 2, "ghost": true, "stun": 1.0, "power": 0.8, "radius": 1.6,
##    "heal_pct": 5, "buff": {"id": "x", "duration": 3, "speed_pct": 30}, "cooldown_mult": 0.8}

const DASH := "dash"

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var class_id: String = ""
@export var skill_id: String = ""           ## skill evoluída ou "dash"
@export var unlock_level: int = 1
@export var cost: int = 2                   ## pontos de skill
@export var requires: Array[String] = []    ## arma exigida para o efeito valer (mesmas fichas de SkillDef)
@export var mods: Dictionary = {}
