# Casa de Leilões — o mercado do mundo

> Status: **APROVADA PARA IMPLEMENTAR** (2026-11-25, decisão D6 de `cartas.md`). Nada implementado. Decisões do usuário em §0 e §9.
> Vem depois de `cartas.md`. §5-8 entram por escrito no começo da implementação.
> Liga com: `cartas.md` (repetidas vão para cá), `pocoes-de-caca.md` (poções à venda), `bots-com-memoria.md` (bots que vendem).

## 0. Decisões do usuário (2026-11-25)

| # | Pergunta | Decisão |
|---|---|---|
| D1 | Compra | **Compra direta, preço fixo** (sem lances). |
| D2 | Bots | **Mercado simulado**: anúncios gerados pelas tabelas de saque da faixa, assinados com nomes de bots reais; comprar/vender não mexe no inventário nem no ouro de bot nenhum. |
| D3 | Lendários | **Não** se vendem (só saque). |
| D4 | Cidades | Leiloeiro em **Aldara, Porto Esperança e Lumeria** (um mercado só). |

## 1. Overview

Um balcão de leilões nas cidades grandes, compartilhado pelo mundo inteiro (um mercado só, como a Casa de Leilões do WoW).
O jogador **anuncia** o que não quer (cartas repetidas, materiais, poções, equipamento) com um preço e um prazo, e **compra**
o que outros anunciaram. Os "outros" são os **bots**: eles vendem o que acham caçando e compram o que precisam, então o
mercado tem gente, preço que sobe e desce, e coisa nova a cada visita. É o que faz o mundo parecer cheio de jogadores
mesmo longe deles.

## 2. Player Fantasy

"Vou ver o que apareceu no leilão." Achar a carta que faltava anunciada por um bot, vender três repetidas e pagar o
Elixir da Fortuna, notar que a Carta do Lich está caríssima porque todo mundo quer. Fantasia de comércio (Bartle:
Socializador/Conquistador): esperteza vira ouro, ouro vira a peça que faltava.

## 3. Detailed Rules (conceito)

**3.1 Onde.** NPC **Leiloeiro** em Aldara, Porto Esperança e Lumeria (D4). Todos acessam o
mesmo mercado. Ícone de serviço novo (`NpcServices`: martelo de leilão).

**3.2 O que pode.** Cartas, materiais, poções e elixires, equipamento comum (não lendário). **Não**: lendários (conjunto,
arma, escudo nomeado, acessório lendário, Ápice; D3), itens de quest.

**3.3 Vender.** O jogador escolhe item, quantidade, **preço** (o balcão sugere o preço médio dos últimos negócios) e
**prazo** (2 / 8 / 24 h de jogo). Paga uma **taxa de anúncio** pequena na hora (sumidouro de ouro); quando vende, o balcão
fica com uma **comissão** (5%) e o ouro vai para a **caixa de correio** do jogador no Leiloeiro. Não vendeu no prazo: o
item volta para a caixa (a taxa não volta).

**3.4 Comprar.** Lista com busca e filtros (tipo, encaixe de carta, nível, preço), ordenada pelo mais barato. Compra na
hora, preço fixo (D1). O item vai para a caixa de correio, que se abre no próprio Leiloeiro.

**3.5 Bots no mercado (simulado, D2).** Os bots são os outros jogadores do mercado, mas os anúncios deles são **gerados**
(tabelas de saque da faixa dos bots que existem no mundo, com o nome de um deles); nada sai nem entra no inventário de um bot:
- **Vendem** o que conseguem caçando na faixa deles (as mesmas tabelas de saque do mundo, cartas inclusive), a um preço
  perto da média com variação de personalidade (o "esperto" pede caro, o "apressado" vende barato).
- **Compram** de tempos em tempos o que estiver abaixo da média e o que "precisam" (poções antes de masmorra, material
  de receita da faixa). Compram anúncios do jogador também — é assim que as repetidas do jogador viram ouro.
- Os negócios aparecem no chat às vezes ("comprei a Carta do Golem no leilão, finalmente").

**3.6 Preço.** Cada item tem um **preço de referência**: preço da loja para o que tem (`ItemDef.price`), e para cartas um
preço pela raridade (comum < elite < núcleo) e pela procura (quantos anúncios há × quantos foram vendidos). O balcão guarda
a média dos últimos negócios por item e mostra uma setinha de alta/baixa.

**3.7 Tempo.** O mercado só anda com o jogo aberto (como as investidas): anúncios vencem e bots compram/vendem em pulsos
de `AH_TICK` min de jogo, não a cada tique da sim. Fica no save (anúncios, caixa de correio, médias).

## 4. Formulas (propostas, calibrar depois)

- Taxa de anúncio: `max(1, preço × AH_LIST_FEE × prazo_h / 24)`, `AH_LIST_FEE` = 1%.
- Comissão na venda: `AH_CUT` = 5%.
- Preço de referência de carta: `CARD_PRICE[espécie] × (1 + procura)`, `procura = clamp((vendidas − anunciadas) / 10, −0,5, 1,0)`.
- Bot compra anúncio se `preço ≤ referência × (1 + humor)`, `humor` sorteado em −0,2..+0,1 por bot (personalidade).
- Pulso do mercado: a cada `AH_TICK` (2 min de jogo) entram `AH_BOT_LISTINGS` anúncios novos de bots (proposta 3-6) e cada
  anúncio barato tem chance `AH_BOT_BUY_CHANCE` de ser comprado.
- Meta: uma carta comum repetida do jogador vende em ~10-30 min de jogo no preço médio.

## 5-8. Edge Cases, Dependencies, Tuning Knobs, Acceptance Criteria

Depois do conceito fechado. Dependências já vistas: `SimEntity.gold` e o inventário, `SaveSystem` (campo novo `market`:
anúncios, caixa, médias), `BotBrain` (bots "visitam" o mercado sem andar até lá: o mercado é abstrato), `BotsCatalog` (falas),
`npc_ui` (janela do Leiloeiro), `NpcServices` (ícone), `cartas.md`, `pocoes-de-caca.md`. Na sim (`core/`): o mercado é um
sistema estático novo (`MarketSystem`) com o estado no `WorldSim`, para valer também no futuro servidor.

## 9. Perguntas abertas

Nenhuma. Respondida em 2026-11-25:
1. **Sumidouro**: fica **taxa 1% + comissão 5%** (`AH_LIST_FEE`, `AH_CUT`); ajuste fino na calibragem com o mercado rodando.
