class_name CardDef
extends Resource
## Carta de Monstro (GDD design/gdd/cartas.md). Uma por monstro elegível; o item da bolsa tem o mesmo id.

@export var id: String = ""            ## "card_<monster_id>" (também é o id do ItemDef)
@export var monster_id: String = ""
@export var name: String = ""
@export var slot: String = ""          ## encaixe fixo (Balance.CARD_SLOTS)
@export var core: bool = false         ## núcleo: forte, fora de grupo, no máximo Balance.CARD_CORE_MAX encaixados
@export var effect: String = ""        ## chave de Balance.CARD_COMMON / CARD_CORE
@export var family: String = ""        ## family_dmg / family_def: família alvo (CardsCatalog.FAMILY)
@export var group: String = ""         ## grupo de combo (Balance.CARD_GROUP_BONUS); "" no núcleo
@export var tier: int = 0              ## 0..2 pelo nível do monstro (Balance.CARD_TIER_LEVELS); preenchido ao carregar
@export var value: float = 0.0         ## número do efeito (tabela da faixa); preenchido ao carregar
@export var boss: bool = false         ## carta de chefe (chance Balance.CARD_CHANCE_BOSS)
