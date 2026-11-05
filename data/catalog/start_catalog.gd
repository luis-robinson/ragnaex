class_name StartCatalog
extends RefCounted
## Começos rápidos da criação de personagem (MVP: testar cada faixa sem jogar a anterior).
## `quest` = quest que começa ATIVA; toda a cadeia de pré-requisitos dela vem concluída (sem as recompensas), e também
## toda quest não repetível abaixo do nível do começo (laterais do Vale, Catacumbas): o diário começa limpo na faixa nova.
## `gear_tier` = equipamento comum desse tier vestido (armas da 1ª build da classe), como um bot do nível.
## `party` = bots do mesmo nível já no grupo, com o jogador de líder: [classe, build].

const PRESETS := {
	1: {"label": "Nível 1", "hint": "O começo normal, em Aldara."},
	10: {"label": "Nível 10 · teste", "hint": "Nível 10, equipamento de Ferro, 100 Moedas Lendárias, a quest para a Floresta e um grupo pronto (caçadora, elementalista, druida e paladino).",
		"level": 10, "gold": 1500, "gear_tier": 1, "quest": "q08_forest",
		"items": {"legend_coin": 100, "potion_hp_m": 10, "potion_mp_m": 10},
		"party": [["ranger", "cacador"], ["elementalist", "fogo"], ["druid", "xama"], ["paladin", "guardiao"]]},
}
