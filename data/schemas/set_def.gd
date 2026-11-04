class_name SetDef
extends Resource
## Conjunto de equipamentos (lendários). Bônus ativam pelo nº de peças equipadas.
## Formato de cada bônus (todas as chaves opcionais):
##   {"attrs": {"INT": 2}, "atk_pct": 8, "matk_pct": 8, "def_pct": 8, "heal_pct": 8, "crit": 3,
##    "skill_dmg": {"ele_fireball": 20}, "skill_cdr": {"ele_frost_nova": 10}}
## skill_dmg multiplica o poder da skill (dano ou cura); skill_cdr reduz a recarga (%).

@export var id: String = ""
@export var name: String = ""
@export var class_id: String = ""
@export var level: int = 1
@export var pieces: Array[String] = []      ## ids de ItemDef
## variantes de uma peça (ex.: maça no lugar da espada): ocupam o mesmo slot, contam como aquela peça, não somam no total
@export var alt_pieces: Array[String] = []
@export var armor: Array[String] = []        ## as peças de armadura (são elas que contam para os bônus; a arma tem efeito próprio)
@export var bonuses: Dictionary = {}        ## nº de peças (int) -> bônus (Dictionary)

## Bônus ativos com `count` peças equipadas, em ordem crescente de peças.
func bonuses_for(count: int) -> Array:
	var ks := bonuses.keys()
	ks.sort()
	var out: Array = []
	for k in ks:
		if count >= int(k):
			out.append(bonuses[k])
	return out
