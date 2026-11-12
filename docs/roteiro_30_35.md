# Roteiro do Ato II, primeira faixa (nível 30-35): Costa Partida e Porto Esperança

Tema: a colônia contra a Horda. Porto Esperança tem três semanas, uma paliçada pela metade e a Horda do outro lado do morro.
Goblins, ginetes de lobo, orcs e nagas. A pista que atravessa a faixa: a Horda não ataca por conquista,
ela **foge de algo no leste** (insígnias de muitos clãs juntos, as fogueiras que a Faroleira vê, o diário do Capitão Odran). Só dicas; a resposta é do Ato III.

O cenário cresce com as missões (estágios do GDD `design/gdd/ato2-horda.md`, States and Transitions):
- **C0 Cerco** (chegada): paliçada meio feita, investida de ginetes a cada ~4 min, mangue e praia cheios, farol apagado.
- **C1 Muralha** (`hx_palisade`): portões de terra, besteiros no muro, investidas maiores que param no portão.
- **C2 Farol** (`hx_lighthouse`, paralela): farol aceso, 2º navio no cais, Dona Celina (importados).
- **C3 Ginetes quebrados** (`hx_riders_camp`, exige C1): investida vira patrulha; colonos plantam no lugar do acampamento.
- **C4 Grutas** (`hx_goblin_boss`): aldeia de palafitas mista (Nikki, Gobo, Ziza), passagem para as Estepes.

Quem chega: o navio do Capitão Bren sai do cais leste do Bastião depois de "De Volta a Aldara" (`dw_epilogue`).

## Nível 30: chegada e cerco

| Quest | Quem dá | O que é |
|---|---|---|
| Terra à Vista | Marinheira Dora (cais) → Governadora Alba | A primeira pessoa no cais manda você à praça. |
| Os Ginetes no Portão | Governadora Alba | 12 ginetes, saqueadores ou lanceiros goblins (investidas no portão norte ou estrada nordeste). |
| Cavilhas de Presa | Alba → Carpinteiro Bruno | 6 Presas de Orc (recrutas nas falésias ao norte). |
| Quem Levou o Óleo (Farol) | Ilda, a Faroleira | 10 goblins do mangue. |
| Os Outros do Gaivota (Náufragos) | Tomás, o Náufrago | 10 Nagas das Marés na praia. |

## Nível 31: a paliçada (C1)

| Quest | Quem dá | O que é |
|---|---|---|
| Fechar a Paliçada | Carpinteiro Bruno → Alba | 15 lanceiros, empaladores ou ginetes. **Muda para C1.** Rende Moeda Lendária. |
| Olhos na Costa | Alba → Batedora Nádia | Sair pelo portão sul até a encruzilhada. |
| O Mangue dos Lanceiros | Batedora Nádia | 15 lanceiros ou empaladores no mangue (dica: derrube o Agitador primeiro). |
| A Lente de Escamas (Farol) | Ilda | 8 Escamas de Naga. |
| Remendo de Casco / Os Nomes do Gaivota (Náufragos) | Tomás → Irmão Celso | Colher 6 cascos na areia (F); levar a notícia ao porto. |
| Escamas Turquesa (Pérolas) | Pescadora Iara (porto) | 10 Escamas de Naga. |
| A Inscrição do Santuário (Diário) | Marujo Lino (taverna) | Chegar ao Santuário Afogado. |

## Nível 32: os punhos vermelhos e o acampamento (C2, C3)

| Quest | Quem dá | O que é |
|---|---|---|
| Punhos Vermelhos | Nádia → Alba | 8 Insígnias da Horda. Alba percebe que a Horda está **se mudando**, do leste. |
| O Acampamento dos Ginetes | Governadora Alba | 4 Saqueadores Goblins no acampamento a nordeste (grupo). Exige a paliçada. **Muda para C3.** Peça do tier 32 + Moeda. |
| Uma Gota que Não Apaga (Farol) | Ilda | 1 Essência da Maré (Mãe das Marés, grupo). **Muda para C2.** A Faroleira vê fogueiras no leste. |
| As Guardiãs do Recife (Pérolas) | Iara | 8 Guerreiras Nagas. |
| O Estrela nas Falésias / O Diário de Odran (Diário) | Lino → Alba | 12 recrutas orcs; o diário vai à Governadora. **Ergue o Memorial do Estrela** na praça. "Os orcs subiram a montanha fugindo do leste." |

## Nível 33-34: as Grutas (C4)

| Quest | Quem dá | O que é |
|---|---|---|
| A Boca das Grutas | Nádia | Entrar nas Grutas Goblin (noroeste da Costa). |
| O Tambor de Grukk | Nádia → Alba | Agitador-Mor Grukk no último salão (grupo). **Muda para C4.** Peça do tier 32 + 2 Moedas. |
| Lia no Recife (Náufragos) | Tomás | 6 Guerreiras Nagas. **A cozinheira Lia volta à cabana.** Peça do tier 32. |
| A Mãe das Marés (Pérolas) | Iara | Chefe de campo no meio da praia (grupo). **A mergulhadora Naia aparece na praia.** Peça + Moeda. |
| Coisa Brilhante / Um Tambor para a Feira (Nikki) | Nikki (aldeia, depois de C4) | 8 Insígnias; 1 Couro do Tambor de Guerra. **Tum-Tum, o tamborileiro, toca na aldeia.** |

Repetíveis: o **Quadro de Caçadas** da Taverna da Âncora tem as caçadas geradas de todo monstro comum da Costa e das Grutas.

## Nível 35: ascensão

Cada classe tem um mestre na praça de Porto Esperança. Só a classe dele recebe a cadeia (provar → buscar → enfrentar);
a última, `hx_asc_<classe>`, libera a ascensão (`ProgressionSystem.has_ascension`).

| Classe | Mestre | Cadeia (a última libera) |
|---|---|---|
| Paladino | Sir Aldwin | Provar a Lança (10 empaladores) · Ferraduras de Presa (6 presas) · **O Corcel de Guerra** (4 Agitadores nas Grutas) |
| Elementalista | Arquimaga Ysolde | A Maré Responde (8 guerreiras) · Três Essências · **O Núcleo Elemental** (chegar ao Santuário Afogado) |
| Berserker | Gorm Duas-Lâminas | Músculo de Orc (15 recrutas) · Cabos de Presa (8 presas) · **O Peso do Titã** (10 guerreiras no recife) |
| Bispo | Madre Celene | Água Turva (8 guerreiras) · Incenso de Mangue (8 ervas azuis) · **A Chama do Coro** (Santuário Afogado) |
| Druida | Ancião Bhoran | Quem Queima o Mangue (8 empaladores) · Terra Doce (10 ervas azuis) · **Raízes no Sal** (3 Agitadores) |
| Ranger | Kaya Olho-de-Falcão | Quem Caça o Mesmo Bicho (12 recrutas) · Isca de Maré (10 escamas) · **O Rastro do Dente-de-Sabre** (3 Agitadores) |
| Assassino | Ninguém | Sem Testemunhas (10 empaladores) · Papéis da Horda (8 insígnias) · **A Sombra que Anda Sozinha** (4 Agitadores) |
| Necromante | O Último Escriba de Azhar | Afogados (8 guerreiras) · Couro que Vibra (2 couros do tambor) · **O Filactério Vazio** (2 Essências da Maré) |

Conferir a faixa: `--headless --path . tools/tests/band_probe.tscn -- --from=30 --to=35 --trials=16`.
