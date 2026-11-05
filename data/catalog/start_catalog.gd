class_name StartCatalog
extends RefCounted
## Começos rápidos da criação de personagem (MVP: testar cada faixa sem jogar a anterior).
## `quest` = quest que começa ATIVA; toda a cadeia de pré-requisitos dela vem concluída (sem as recompensas), e também
## toda quest não repetível abaixo do nível do começo (laterais do Vale, Catacumbas): o diário começa limpo na faixa nova.
## `gear_tier` = equipamento comum desse tier vestido (armas da 1ª build da classe), como um bot do nível.
## `party` = bots do mesmo nível já no grupo, com o jogador de líder: [classe, build].
## `map`/`at` = onde começa (sem isso, Aldara); `welcome` = aviso ao entrar.

const PRESETS := {
	1: {"label": "Nível 1", "hint": "O começo normal, em Aldara."},
	10: {"label": "Nível 10", "hint": "Teste: nível 10, equipamento de Ferro, 100 Moedas Lendárias, a quest para a Floresta e um grupo pronto (caçadora, elementalista, druida e paladino).",
		"level": 10, "gold": 1500, "gear_tier": 1, "quest": "q08_forest",
		"items": {"legend_coin": 100, "potion_hp_m": 10, "potion_mp_m": 10},
		"party": [["ranger", "cacador"], ["elementalist", "fogo"], ["druid", "xama"], ["paladin", "guardiao"]],
		"welcome": "Começo rápido (nível 10): a Capitã Mira manda você à Floresta. Portão leste do vale, depois o Ranger Teo."},
	16: {"label": "Nível 16", "hint": "Teste da Cidade Élfica: nível 16, equipamento de Mitril, 100 Moedas Lendárias, grupo pronto, no Posto dos Caçadores com a garganta élfica aberta.",
		"level": 16, "gold": 4000, "gear_tier": 2, "quest": "el3_scout", "map": "field_forest", "at": [-5.0, -12.0],
		"items": {"legend_coin": 100, "potion_hp_m": 15, "potion_mp_m": 15, "elixir_might": 3},
		"party": [["ranger", "cacador"], ["elementalist", "fogo"], ["druid", "xama"], ["paladin", "guardiao"]],
		"welcome": "Começo rápido (nível 16): Posto dos Caçadores. Saia pelo portão norte, passe a Árvore-Mãe e a garganta élfica: a Batedora Yara espera no cerco."},
}
