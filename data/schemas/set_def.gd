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
## conjunto híbrido (GDD Ato II R7.1): [build A, build B]; vazio = conjunto da build. O 5 peças dele é a Fusão
## ({"fusion": {...}} em bonuses[5], FusionEffects).
@export var pair: Array[String] = []
@export var fusion: String = ""             ## id da Fusão ("<A>+<B>", chave de Balance.FUSION_NUMBERS)

## Conjunto Ápice (design/gdd/apice-sets.md): build cuja mecânica ele aprofunda; vazio fora do Ápice. O 5 peças é o
## efeito Ápice ({"fusion": {"id": "apice_<build>", ...}}, FusionEffects); 2-4 peças = os do conjunto da build.
@export var apex: String = ""

func is_hybrid() -> bool:
	return not pair.is_empty()

func is_apex() -> bool:
	return apex != ""

## Build dona do conjunto (Ápice: a dele; híbrido: a do lado A; conjunto da build: tirada do id).
func build_of() -> String:
	if is_apex():
		return apex
	if is_hybrid():
		return pair[0]
	return GearCatalog.bid_of_set(id).trim_prefix(class_id + "_")

## Bônus ativos com `count` peças equipadas, em ordem crescente de peças.
func bonuses_for(count: int) -> Array:
	var ks := bonuses.keys()
	ks.sort()
	var out: Array = []
	for k in ks:
		if count >= int(k):
			out.append(bonuses[k])
	return out
