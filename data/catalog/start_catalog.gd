class_name StartCatalog
extends RefCounted
## Começos rápidos da criação de personagem (MVP: testar cada faixa sem jogar a anterior).
## `quest` = quest que começa ATIVA; toda a cadeia de pré-requisitos dela vem concluída (sem as recompensas).
## `gear_tier` = equipamento comum desse tier vestido (armas da 1ª build da classe), como um bot do nível.

const PRESETS := {
	1: {"label": "Nível 1", "hint": "O começo normal, em Aldara."},
	10: {"label": "Nível 10 · teste", "hint": "Nível 10, equipamento de Ferro, 100 Moedas Lendárias e a quest para a Floresta.",
		"level": 10, "gold": 1500, "gear_tier": 1, "quest": "q08_forest",
		"items": {"legend_coin": 100, "potion_hp_m": 10, "potion_mp_m": 10}},
}
