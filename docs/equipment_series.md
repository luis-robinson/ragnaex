# Séries de equipamento: especificação

Guia de arte e de dados para cada série do RagnaEx. É uma especificação: **nada aqui além dos escudos tem arte nova ainda**.

Regras de todas as séries, vindas da revisão dos escudos:
- A câmera é alta: cabeça, ombros e costas decidem a leitura. Detalhe vai primeiro neles.
- Silhueta antes de cor. Teste em `lineup` da câmera do jogo, não só de frente.
- Massa antes de detalhe: ornamento abaixo de 3 cm some no contorno e na distância da câmera.
- Corpo escuro, ouro por cima e uma joia só: é o que dá leitura de item raro. Vale também nos tiers altos das armaduras.
- Três alturas em cada peça principal: corpo, relevo e foco.
- Tiers altos ganham assimetria e vazios.
- `tint` recebe a cor do item, `tint2` o destaque; o resto é material fixo.
- Inspiração em MMOs é princípio de forma, nunca traçado (`reference/shields/mmo_notes.md`).

Custo de produção: **P** = cor e dados; **M** = peças novas de kit reaproveitadas por um grupo; **G** = estilo próprio em `chibi_kit.SET_STYLES`, ícones e revisão.

## 1. Comuns por tier

Quatro tiers (níveis 1, 8, 16, 24) nos três tipos de armadura, gerados por `GearCatalog`. Hoje mudam só de cor e número.

| Tier | Fantasia | Silhueta | Paleta | Material | Foco de cabeça e ombro | Custo |
|---|---|---|---|---|---|---|
| Bronze | Recruta da vila | Peças lisas, sem ombreira | Marrom, bronze fosco | Couro cru, rebite | Testeira simples | P |
| Ferro | Guarda de Aldara | Ombreira redonda pequena | Cinza-azulado | Placa com filete | Crista curta no elmo | M |
| Mitril | Veterano | Ombreira em duas lâminas | Prata fria, azul | Metal claro com brilho | Asas pequenas no elmo | M |
| Obsidiana | Elite das Ruínas | Ombreira angulosa, assimétrica | Preto violeta, gume claro | Vidro escuro facetado | Coroa de lâminas | M |

Por tipo: placa = volume nos ombros; couro = camadas, cintos e capuz; tecido = barra longa, mangas e faixa. Obtido por loja, drop e forja. Papel: base de atributos até o lendário.

## 2. Capas, amuletos e anéis temáticos

| Tema | Fantasia | Atributos | Paleta | Capa | Joias | Custo |
|---|---|---|---|---|---|---|
| Guerreiro | Estandarte | FOR, VIT | Vermelho, ferro | Barra rasgada com faixa | Selo quadrado | M |
| Caçador | Mata | AGI, FOR | Verde, couro | Capa curta com pelo no ombro | Dente e cordão | M |
| Sábio | Biblioteca | INT, WILL | Azul, prata | Longa com runas na barra | Gema lapidada | M |

De cima a capa é a maior área de cor do boneco: é a peça de melhor retorno. Status: geradas, todas com a mesma capa.

## 3. Equipamento escrito à mão

Itens fixos em `items_catalog.gd`. Mantêm os nomes e ganham identidade por família de monstro.

| Família | Itens | Fantasia | Silhueta e foco | Custo |
|---|---|---|---|---|
| Inicial de classe | `start_*`, arma inicial | Roupa de quem saiu de casa | Lisa; a classe se lê pelo cabelo | P |
| Lobo | Armadura e Botas de Lobo | Caçador da Campina | Pelo nos ombros, focinho no capuz | M |
| Seda | Capuz, Túnica, Cajado e Varinha de Seda | Tecelã da Floresta | Véu leve, fios soltos na barra | M |
| Ent | Armadura, Botas, Espada e Arco de Ent | Casca viva | Placas de casca, folhas nos ombros | M |
| Osso | Elmo, Machado e Foice de Osso | Saque de cemitério | Crânio de elmo, costelas | M |
| Espectral | Coroa, Túnica, Cajado, Adaga, Varinha, Foice e Anel | Luz fria | Partes vazadas, azul translúcido | M |
| Dracônica | Armadura, Túnica, Espada, Cajado, Arco e Varinha | Fim de jogo comum | Escamas, chifres para trás | G |
| Golem | Machado, Adaga, Foice e Amuleto | Pedra rúnica | Blocos com veios de luz | M |

## 4. Assinaturas de chefe

Saque único: precisa ser reconhecido de longe por quem não o tem.

| Item | Chefe | Papel | Visual proposto | Custo | Status |
|---|---|---|---|---|---|
| Anel do Capitão | Capitão de Ossos | FOR, VIT | Elo de osso com dragona dourada | P | Ícone genérico |
| Lágrima da Viúva | Viúva Lamentosa | INT, WILL | Gota azul presa em prata | P | Ícone genérico |
| Selo de Vargo | Conde Vargo | INT, AGI | Sinete violeta | P | Ícone genérico |
| Manto do Conde | Conde Vargo | VIT, WILL | Capa violeta com gola alta e coroa bordada | M | Usa a capa comum |

Pendência: Rei Slime, Rainha Aranha e Senhor da Cripta ainda dropam tabelas de outros chefes. Cada um pede uma assinatura própria.

## 5. Conjuntos lendários

21 builds × 6 tiers = 126 conjuntos gerados. Nome = peça + build + epíteto do tier. Só `set_paladin_guardiao_5` tem visual próprio (`pal1`).

Proposta: **um estilo por build**, com o tier mudando brilho e detalhe. São 20 estilos a fazer, e não 125.

| Classe | Build | Fantasia | Silhueta de cima | Paleta | Foco |
|---|---|---|---|---|---|
| Paladino | Guardião | Fortaleza viva | Ombreiras-torre | Prata, violeta | Crista de ameias |
| Paladino | Cruzado | Lâmina da fé | Tabardo longo e cruz | Branco, vermelho | Halo partido nas costas |
| Berserker | Armas Gêmeas | Açougueiro veloz | Tiras e duas bainhas | Vermelho, couro | Cicatrizes pintadas |
| Berserker | Executor | Carrasco | Ombreira única, enorme | Ferro, sangue | Capuz de carrasco |
| Bispo | Sacerdote | Mão que cura | Mitra e estola | Branco, ouro | Cruz flutuante |
| Bispo | Inquisidor | Tribunal | Placa com selos de cera | Preto, ouro | Mitra de ferro |
| Druida | Guardião da Floresta | Carvalho que anda | Casca e galhos nos ombros | Marrom, musgo | Chifres de galho |
| Druida | Fera Selvagem | Matilha | Pele de fera e crânio | Pardo, osso | Capuz de lobo |
| Druida | Xamã | Tempestade verde | Penas e amuletos | Verde, âmbar | Cocar |
| Ranger | Atirador | Olho de falcão | Capa curta, aljava alta | Verde-escuro | Capuz com pena |
| Ranger | Caçador | Armadilheiro | Bolsas e correntes | Couro, latão | Máscara de caça |
| Ranger | Lanceiro | Caça de feras | Gola de pelo, troféu no ombro, dardos nas costas | Couro, osso | Cabeça de bicho |
| Assassino | Lâminas Gêmeas | Dança | Faixas soltas | Preto, carmim | Máscara e lenço longo |
| Assassino | Envenenador | Alquimista | Frascos no cinto | Roxo, verde | Máscara de bico |
| Assassino | Sombra | Duelista | Sobretudo longo | Preto, prata | Gola alta |
| Elementalista | Fogo | Fornalha | Ombros com brasas | Vermelho, ouro | Coroa de chamas |
| Elementalista | Gelo | Geleira | Gola de cristais | Azul, branco | Tiara de gelo |
| Elementalista | Raio | Trovão | Anéis em volta dos ombros | Amarelo, índigo | Tiara com raio |
| Necromante | Invocador | Mestre de ossos | Costelas e crânios nos ombros | Osso, verde | Coroa de ossos |
| Necromante | Ceifador | Colheita | Capuz fundo e manto | Preto, cinza | Capuz sem rosto |
| Necromante | Pestilento | Praga | Trapos e frascos | Verde-doente | Máscara de peste |

Tiers: 5 e 10 = forma base; 15 e 20 = + relevo e `tint2`; 25 = + peça que rompe a silhueta; 30 = + foco brilhante e assimetria.

Papel: atributos da build, bônus de 2 a 5 peças e skill-assinatura. Custo: G cada.

## 6. Escudos

Feitos: 18 modelos únicos em `tools/blender/shield_kit.py`, notas em `docs/shields_review.md`. Afinidade dá Juramento ao Paladino e Graça ao Bispo. Ícones são fotos do modelo (`tools/icons/shield_icons.tscn`).

Próximos passos: escudo de conjunto do Guardião e do Sacerdote; passada de pintura (textura por escudo) se a meta for o acabamento do Priston Tale, já que geometria não chega lá.

## Ordem recomendada

1. Capas temáticas e Manto do Conde (M): maior ganho por esforço, visível de cima.
2. Cabeças dos comuns, tier a tier (M).
3. Assinaturas de chefe, ícones e tabelas próprias (P).
4. Conjuntos: Sacerdote e Guardião da Floresta primeiro, que completam os papéis de grupo; depois um por classe; depois o resto (G).
5. Famílias escritas à mão, conforme a zona for revisada (M).
