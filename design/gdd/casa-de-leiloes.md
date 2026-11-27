# Casa de Leilões — o mercado do mundo

> Status: **IMPLEMENTADA** (2026-11-27: `AuctionSystem`, `AuctionUi`; regra resumida em `docs/DESIGN.md` "Casa de Leilões"). Aprovada em 2026-11-25 (decisão D6 de `cartas.md`). Decisões do usuário em §0 e §9.
> Vem depois de `cartas.md`. §5-8 entram por escrito no começo da implementação (escritas 2026-11-27, **aprovadas pelo usuário 2026-11-27** com as 4 recomendações de §10).
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

## 5. Edge Cases

Termos usados abaixo (contas na §7): `venda_loja(it)` = o que o mercador paga hoje (`floor(price × 0,5)`, `CraftSystem.sell`);
`ref(it)` = preço de referência (§3.6/§4); `piso_bot(it)` = menor preço de um anúncio de bot; `teto_bot(it)` = o máximo que um bot paga.

**O que pode ser anunciado** (uma função só, `AuctionSystem.sellable(it) -> String`, "" = pode; o texto é o motivo da recusa):
- **Lendários (D3)**: recusa se `it.is_legendary()`, `set_id != ""`, `legend_effect` ou `piece_fx` não vazios (conjunto, arma lendária,
  escudo nomeado, acessório lendário, Ápice, lendário do 50, híbridos). Cópia aprimorada de lendário (`base_id` aponta para lendário): recusa.
  Texto: "Lendários não vão a leilão: só saem de saque."
- **Item de quest** (`Type.QUEST`): recusa. Material comum que uma quest COLLECT conta pode ser anunciado e comprado; tirar ou pôr na
  bolsa chama `QuestSystem.on_item_changed`, como a loja.
- **Item sem preço** (`price <= 0`: Moeda Lendária, Pergaminhos de Refino, Baús do MVP, prêmios de loja de GvG/MVP): recusa na 1ª leva (§10, P4).
- **Não existe "preso à alma"** no jogo hoje; a regra acima cobre o que seria preso (lendário, quest, prêmio sem preço). Item novo que
  precise ser preso entra por esta função, não por um campo novo.
- **Equipado, carta encaixada, bolsa vestida, item no Depósito**: só se anuncia da **bolsa**. Tire antes (a janela diz "Tire do
  encaixe/boneco primeiro").
- **Aprimorado +N** (não lendário): pode; o anúncio é da cópia `<id>+N`. `ref` e `teto_bot` seguem a §7 (o bot nunca paga mais do que
  custou aprimorar). Bots nunca anunciam peça aprimorada.
- **Conjunto/Ápice**: nunca (são lendários). Peça comum gerada (`gear_pool`) pode.
- **Cartas**: comum e de núcleo podem (D6). Carta comprada entra no Bestiário como "achada" quando sai da caixa para a bolsa
  (regra de `cartas.md` §5: "entrou na sua bolsa"; §10, P3).
- **Poções de Caça e elixires**: podem (`pocoes-de-caca.md` §3.6). `ref` = custo de fabricar (§7), não o `price` (que é menor que o
  ouro da receita).

**Anunciar**
- Quantidade: 1..`min(o que tem na bolsa, stack_max)`; o lote é vendido inteiro (sem compra parcial). Preço digitado é **por unidade**;
  total = unidade × quantidade.
- O item **sai da bolsa na hora** (fica guardado no anúncio): não há como vender o mesmo item duas vezes nem duplicá-lo com save.
- **Preço fora da faixa**: recusa abaixo de `max(1, venda_loja)` ("O mercador paga mais que isso") e acima de
  `ref × AUCTION_PLAYER_PRICE_MAX` ("Preço alto demais"). O campo já abre com a média dos últimos negócios (sugestão).
- **Ouro para a taxa**: sem ouro para a taxa de anúncio, recusa ("Ouro insuficiente para a taxa"); nada sai da bolsa.
- **Limite de anúncios**: com `AUCTION_PLAYER_LISTINGS` ativos, recusa ("Você já tem N anúncios").
- **Cancelar**: só no Leiloeiro; o item volta para a **caixa**, a taxa não volta.

**Comprar**
- **Ouro insuficiente**: recusa ("Ouro insuficiente"); nada muda.
- **Próprio anúncio**: aparece na lista com a marca "Seu" e sem botão de comprar (só Cancelar). Não há como comprar de volta.
- **Anúncio sumiu** entre abrir a lista e clicar (pulso de mercado vendeu/venceu): recusa ("Este anúncio não está mais lá") e a lista recarrega.
- **Caixa cheia** (`AUCTION_MAIL_MAX` entradas): compra recusada ("Esvazie a caixa do Leiloeiro"). Vendas, vencidos e cancelados
  **sempre** entram na caixa, mesmo passando do teto: nunca se perde item nem ouro.
- O item comprado vai para a caixa, nunca direto para a bolsa.

**Caixa de correio**
- **Bolsa cheia** ao pegar: pega o que couber (pilha por pilha, regra de `add_item`), o resto fica na caixa ("Bolsa cheia: N ficaram na caixa").
  Ouro sempre sai inteiro.
- A caixa é a mesma nos três Leiloeiros (D4).

**Vencer / tempo**
- Prazo 2/8/24 h **de jogo** (§3.3); o relógio do mercado só anda com o jogo aberto (§3.7): nada vence nem vende com o jogo fechado.
  No save vai o tempo que **falta** de cada anúncio; ao carregar, continua de onde parou (0 s passam no carregamento).
- Venceu sem vender: item para a caixa ("Não vendeu: X voltou para a caixa"), taxa perdida.
- Morrer, trocar de mapa, montar, ficar numa masmorra: não mexem no mercado (ele é abstrato; só a janela exige estar no Leiloeiro).

**Save / carregar**
- Campo novo opcional `market` no save do personagem (como `roster`): o mercado é **por personagem/espaço**. Save sem o campo = mercado novo
  (os bots enchem no 1º pulso). Item de anúncio ou da caixa que saiu do catálogo: passa por `GameData.resolve_item`; se não resolve, some
  (aviso no log), igual à carta que saiu do catálogo.
- Gravar no meio de um anúncio: o item está no anúncio, não na bolsa; o save grava os dois juntos (gravação atômica de `save_player`).
  Fechar sem salvar volta ao save anterior inteiro (item na bolsa, sem anúncio): sem duplicação.
- Anúncios de bots também vão no save (senão recarregar seria um jeito de sortear a vitrine de novo). Os preços deles são presos de novo
  na faixa `[piso_bot, ref × AUCTION_BOT_ASK_MAX]` ao carregar, caso o `Balance` tenha mudado.

**Bots (D2)**
- Nome do vendedor = um bot que existe: do elenco (`RosterSystem`) com chance `AUCTION_ROSTER_SHARE`, senão um bot vivo da faixa; sem
  bot vivo na faixa, um do elenco. Se o bot sair do mundo depois, o anúncio fica com o nome (é simulado).
- Comprar de um bot ou vender para "um bot" **nunca** mexe no inventário nem no ouro de bot nenhum.
- Chat de leilão respeita o ritmo do elenco (`RosterSystem.can_speak`, `ROSTER_CHAT_GAP`): nada de spam.

**Preço e laços de dinheiro (degenerados)**
- *Comprar do bot e vender ao mercador*: impossível lucrar, `piso_bot > venda_loja` sempre (§7).
- *Comprar no mercador (até na Feira, −15%) e vender para bot*: impossível lucrar; o bot paga no máximo `AUCTION_SHOP_PAY_MAX` do preço de loja
  e, tirada a comissão, fica abaixo de `1 − CHAIN_FAIR_DISCOUNT` (§7).
- *Fabricar com material comprado e vender para bot*: o bot paga no máximo o custo mínimo de fabricar; com a comissão, dá prejuízo. Com
  material caçado, dá lucro (é o certo: o material vira ouro).
- *Aprimorar para vender*: o bot paga só `AUCTION_PLUS_RECOVER` do ouro gasto no aprimoramento.
- *Arbitragem* (comprar anúncio barato de bot e revender para bot): possível e limitada pelo **orçamento de bots** (`AUCTION_BOT_BUDGET_PER_LV`
  por nível do jogador por hora de jogo) e pela queda por enxurrada; §10, P2.
- *Enxurrada* (anunciar 50 do mesmo item): cada venda do mesmo item para bot baixa o `teto_bot` dele (`AUCTION_FLOOD_STEP`), que volta com o tempo.
- *Banco da Guilda* (itens de graça dos bots): pode anunciar o que tirou (não lendário); cabe no mesmo orçamento.
- Preço gigante: o teto de anúncio (`AUCTION_PLAYER_PRICE_MAX`) segura erro de digitação e estouro de inteiro (unidade × 999 cabe em `int`).

**Lugar**
- Só os Leiloeiros (papel `auction`) de Aldara, Porto Esperança e Lumeria abrem a janela. Toda chamada de `Sim.auction_*` que mexe em item
  ou ouro confere `ProgressionSystem.near_npc` (alcance `STATION_RANGE`) de um NPC `auction` no mapa atual; em mapa sem Leiloeiro recusa
  ("Fale com um Leiloeiro"). Busca/lista podem ser lidas de qualquer lugar (prévia para a UI e os testes).
- Lumeria muda por estágios (L0-L4): o Leiloeiro tem de estar no hub em **todos** os estágios (check).

## 6. Dependencies

**Sim (`core/`, futuro servidor).** Nome do sistema: **`AuctionSystem`** (`core/sim/systems/auction_system.gd`; o rascunho antigo chamava de
`MarketSystem`), funções estáticas `f(sim: WorldSim, ...)`, sem estado próprio.
- `core/sim/world_sim.gd`: estado `auction: Dictionary` (`listings`, `mail`, `history`, `flood`, `budget`, `clock`, `next_id`) e um
  `auction_rng: RandomNumberGenerator` **próprio** (o mercado não gasta o `sim.rng`: combate e `sim_probe` continuam com a mesma soma);
  `tick` chama `AuctionSystem.update(self, dt)` (só soma tempo; o trabalho é no pulso de `AUCTION_TICK_S`; liga junto com o elenco,
  `Sim.roster_start`, como o `RosterSystem`). Repasses no fim do arquivo: `auction_sellable(item_id)`, `auction_ref(item_id)`,
  `auction_suggest(item_id)`, `auction_search(filtros) -> Array`, `auction_list(e, item_id, count, unit_price, hours) -> String`,
  `auction_buy(e, listing_id) -> String`, `auction_cancel(e, listing_id) -> String`, `auction_collect(e, mail_id = -1) -> String`,
  `auction_status(e) -> Dictionary` (meus anúncios, caixa, orçamento; para a UI).
- `core/events.gd`: sinais `auction_sold`, `auction_expired`, `auction_changed` (via `Events.post`, nunca `emit` no `core/`).
- `core/save_system.gd`: campo opcional `market` (`AuctionSystem.to_save/from_save`), sem subir `save_version`.
- `core/systems/craft_system.gd`: a fração de venda do mercador (0,5, hoje literal em `CraftSystem.sell` e em `npc_ui`) vira
  `Balance.MERCHANT_SELL_PCT` + `CraftSystem.sell_price(it)`; o piso do leilão lê dali (senão os dois podem se separar e abrir um laço).
- Lê (não muda): `LootSystem.gear_pool` + `LootTable.roll(auction_rng)` (vitrine dos bots por faixa), `MapsCatalog`/spawners (que monstros
  são de cada faixa), `GameData.cards`/`CardSystem` (carta comum/núcleo), `HuntPotionSystem`/`HUNT_POTION_GRADES` e `GameData.recipes`
  (custo de fabricar), `ItemSystem.enhance_cost` (+N), `ChainSystem`/`CHAIN_FAIR_DISCOUNT` (invariante da loja), `RosterSystem` (nomes,
  personalidade, `can_speak`), `BotBandSystem`/entidades (bots vivos por faixa), `BotChat` + `BotsCatalog.AUCTION_LINES` (falas),
  `QuestSystem.on_item_changed`, `ProgressionSystem.near_npc`.
- **Não** usa `BotBrain`: os bots não andam até o Leiloeiro nem mudam de bolsa/ouro (D2).

**Dados (`data/`).** `Balance.AUCTION_*` (§7) e `MERCHANT_SELL_PCT`; `MapsCatalog`: NPC Leiloeiro com `role: "auction"` em `city_aldara`,
`city_port` e no hub de Lumeria (todos os estágios); `BotsCatalog.AUCTION_LINES` (por personalidade do elenco).

**Apresentação (`game/`).** `game/ui/auction_ui.gd` (novo; abas Comprar / Vender / Meus anúncios / Caixa, busca e filtros tipo,
encaixe de carta, nível, preço; setinha de tendência), aberto por `npc_ui` no papel `auction`; `NpcServices.SERVICES/LABELS` += `auction`
("Leiloeiro") + `SERVICE_ICONS` `service_auction` (martelo) em `tools/icons/make_icons.gd`; aviso de venda no `hud` (notificação).
A UI só chama `Sim.auction_*` e reage a `Events`.

**Outros GDDs (dependência nos dois sentidos; atualizar na implementação).** `cartas.md` §3.7/§6 (repetidas: "Futuro" vira esta spec),
`pocoes-de-caca.md` §3.6, `bots-com-memoria.md` §6 (elenco assina anúncios e fala do leilão), `banco-da-guilda.md` §4 (a Contribuição
pode passar a usar `AuctionSystem.ref` em vez do `price`). README/`docs/DESIGN.md` quando a regra entrar.

**Testes.** `tools/tests/run_tests.gd` (`--only=auction`) e sonda nova `tools/tests/auction_probe.tscn` (§8).

## 7. Tuning Knobs (`data/balance.gd`)

Nomes: os `AH_*` da §4/§9 viram `AUCTION_*` com os mesmos valores (`AH_LIST_FEE` = `AUCTION_LIST_FEE`, `AH_CUT` = `AUCTION_CUT`,
`AH_TICK` = `AUCTION_TICK_S`, `AH_BOT_LISTINGS`, `AH_BOT_BUY_CHANCE`).

**Contas de preço (complemento da §4; o que impede o dinheiro infinito).**
```
venda_loja(it) = floor(price × MERCHANT_SELL_PCT)                              # 0,5 hoje
ref(it)        = price                                       (material, equipamento comum, consumível de loja)
               = CARD_PRICE_* × (1 + procura)                (carta, §4)
               = ouro_receita + Σ qtd × ref(ingrediente)     (o que se fabrica: poções de caça, joias, capas, bolsas; por unidade)
               = ref(base) + AUCTION_PLUS_RECOVER × Σ ouro de aprimorar 1..N   (cópia +N)
piso_bot(it)   = max(ceil(venda_loja × AUCTION_FLOOR_OVER_SELL), venda_loja + 1)
preço_bot(it)  = clamp(ref × (1 + humor_vendedor), piso_bot, ref × AUCTION_BOT_ASK_MAX)
teto_bot(it)   = min(ref × (1 + humor_comprador) × enxurrada, teto_fonte)
teto_fonte     = preço_loja × AUCTION_SHOP_PAY_MAX            se o mercador vende o item
               = custo mínimo de fabricar × AUCTION_CRAFT_PAY_MAX  (ingredientes no menor entre loja e piso_bot)
               = sem teto                                      se só cai de monstro
enxurrada      = 1 − AUCTION_FLOOD_STEP × min(vendidos_recentes[id], AUCTION_FLOOD_MAX)
chance de um bot comprar no pulso = AUCTION_BOT_BUY_CHANCE, só se preço ≤ teto_bot e o orçamento cobre
orçamento/h    = AUCTION_BOT_BUDGET_PER_LV × nível do jogador (balde de 1 h, enche aos poucos a cada pulso)
```
Invariantes (viram check): `AUCTION_SHOP_PAY_MAX × (1 − AUCTION_CUT) < 1 − CHAIN_FAIR_DISCOUNT`; `piso_bot > venda_loja`;
`AUCTION_CRAFT_PAY_MAX × (1 − AUCTION_CUT) < 1`; `AUCTION_PLUS_RECOVER × (1 + humor máx) × (1 − AUCTION_CUT) < 1`.
Exemplo: carta comum (30) sem procura: piso_bot = max(ceil(15 × 1,25), 16) = 19; um bot pede 26-34; um bot compra a do jogador por até
33 (humor +0,1); listada a 30 por 8 h: taxa max(1, 30 × 0,01 × 8/24) = 1, recebe 30 × 0,95 = 28 (o mercador dava 15).
Exemplo de laço fechado: Poção do mercador a 50, comprada na Feira por 43; o bot paga no máximo 50 × 0,8 = 40 → 38 líquidos: prejuízo de 5 + taxa.

| Botão | Valor | Faixa segura | Tipo | Mexe em / por quê |
|---|---|---|---|---|
| `AUCTION_LIST_FEE` | 0,01 (por 24 h) | 0,005-0,03 | curva | sumidouro na hora de anunciar (§9.1) |
| `AUCTION_CUT` | 0,05 | 0,03-0,10 | curva | sumidouro na venda (§9.1) |
| `AUCTION_DURATIONS_H` | [2, 8, 24] | — | portão | prazos (h de jogo, §3.3) |
| `AUCTION_TICK_S` | 120 | 60-300 | portão | pulso do mercado; meta de venda 10-30 min = poucos pulsos |
| `AUCTION_BOT_LISTINGS` | [3, 6] por pulso | 2-10 | portão | vitrine nova a cada visita |
| `AUCTION_BAND_MAX` | 20 por faixa (`XP_BANDS`, 7) | 10-40 | portão | lista cheia sem virar mar de itens; total ≤ 140 |
| `AUCTION_BAND_MIN_WEIGHT` | 0,15 | 0-0,5 | curva | faixa sem bot vivo ainda ganha anúncio (peso por bots vivos na faixa) |
| `AUCTION_BOT_KIND_WEIGHTS` | material 55, equipamento 20, carta 15, poção 10 | — | curva | o que aparece na vitrine |
| `AUCTION_BOT_LOT` | material 1-5 rolagens da tabela | 1-10 | curva | tamanho dos lotes de material |
| `AUCTION_BOT_LISTING_S` | [1800, 7200] | 900-14400 | portão | quanto um anúncio de bot fica |
| `AUCTION_BOT_CHURN` | 0,08 por pulso | 0,02-0,2 | curva | anúncio de bot "vendido" para outro bot: média anda |
| `AUCTION_BOT_BUY_CHANCE` | 0,12 por pulso | 0,05-0,3 | curva | 2 min / 0,12 ≈ 17 min por venda no preço (meta §4: 10-30) |
| `AUCTION_MOODS` | competitivo +0,15..+0,35, calmo −0,05..+0,10, brincalhão −0,15..+0,25, tímido −0,25..−0,05, heroico −0,10..+0,05, fora do elenco −0,20..+0,25 | ±0,4 | sensação | "esperto pede caro, apressado vende barato" (§3.5) pelas personalidades do elenco |
| `AUCTION_BUY_MOOD` | −0,20..+0,10 | −0,3..+0,15 | curva | humor do comprador (§4) |
| `AUCTION_BOT_ASK_MAX` | 1,6 | 1,3-2,5 | curva | teto do que um bot pede |
| `AUCTION_FLOOR_OVER_SELL` | 1,25 | 1,1-1,5 | curva | piso dos bots acima do mercador (fecha o laço bot→mercador) |
| `AUCTION_SHOP_PAY_MAX` | 0,80 | 0,6-0,8 | curva | fecha o laço mercador→bot, mesmo com a Feira (0,8 × 0,95 = 0,76 < 0,85) |
| `AUCTION_CRAFT_PAY_MAX` | 1,0 | 0,8-1,0 | curva | fabricar com material comprado nunca dá lucro |
| `AUCTION_PLUS_RECOVER` | 0,7 | 0,4-0,8 | curva | aprimorar para vender nunca dá lucro (0,7 × 1,1 × 0,95 = 0,73) |
| `AUCTION_FLOOD_STEP` / `AUCTION_FLOOD_MAX` / `AUCTION_FLOOD_HALF_S` | 0,04 / 10 / 1800 | 0,02-0,1 / 5-15 / 900-3600 | curva | vender muito do mesmo item derruba o preço (até −40%), volta pela metade a cada 30 min |
| `AUCTION_BOT_BUDGET_PER_LV` | **220** ouro por nível por h (usuário 2026-11-27; caça medida ≈ 750/h por nível) | 150-300 | curva | **torneira**: o máximo que bots pagam ao jogador por hora (nível 20 = 4.400/h); calibrar para ≈ 30% do ouro/h de caça medido na faixa (§10, P1) |
| `AUCTION_PLAYER_LISTINGS` | 12 | 6-30 | portão | anúncios ativos do jogador |
| `AUCTION_PLAYER_PRICE_MAX` | 10 × ref | 3-20 | portão | erro de digitação / estouro |
| `AUCTION_MAIL_MAX` | 60 | 30-120 | portão | caixa cheia bloqueia só compra |
| `AUCTION_HISTORY_N` | 10 negócios por item | 5-20 | sensação | média sugerida e setinha |
| `AUCTION_TREND_PCT` | 0,05 | 0,03-0,15 | sensação | setinha só se a média dos 3 últimos sai mais que isso da média |
| `AUCTION_ROSTER_SHARE` | 0,35 | 0,2-0,6 | sensação | quanto da vitrine é assinada por nomes do elenco |
| `AUCTION_CHAT_CHANCE` | 0,15 por negócio de bot | 0-0,3 | sensação | "comprei a Carta do Golem no leilão" (passa por `can_speak`) |
| `MERCHANT_SELL_PCT` | 0,5 | — (hoje fixo) | curva | sai do literal em `CraftSystem.sell`/`npc_ui`; o piso depende dele |

## 8. Acceptance Criteria (`--only=auction` em `tools/tests/run_tests.gd`)

Funcionais (cada um um `check(...)`, `TEST_SLOT`, `auction_rng` com semente fixa):
1. `_check_auction_sellable`: percorre `GameData.items`; todo lendário, peça de conjunto/Ápice, `legend_effect`/`piece_fx`, `+N` de lendário,
   `QUEST` e `price <= 0` recusa com motivo; material, equipamento comum (e `+N` comum), carta comum/núcleo e as 6 Poções de Caça passam.
2. `_check_auction_list`: anunciar tira da bolsa e cobra a taxa da fórmula (30 × 8 h = 1); recusa sem ouro para a taxa, acima do limite de
   anúncios, preço < `venda_loja` ou > `ref × AUCTION_PLAYER_PRICE_MAX`, quantidade > o que tem, item equipado/encaixado.
3. `_check_auction_buy`: comprar anúncio de bot tira o ouro e põe o item na caixa (não na bolsa); recusa ouro insuficiente, próprio anúncio,
   anúncio que sumiu e caixa cheia; fora de um Leiloeiro (`near_npc`) recusa.
4. `_check_auction_mail`: pegar com a bolsa cheia deixa o resto na caixa; ouro sai inteiro; venda/vencido entram mesmo com a caixa no teto.
5. `_check_auction_expire`: avançar o relógio do mercado vence o anúncio → item na caixa, taxa não volta; cancelar faz o mesmo.
6. `_check_auction_bot_sale`: com chance forçada a 1, anúncio ≤ `teto_bot` vende e a caixa recebe `preço × (1 − AUCTION_CUT)`; acima do teto
   nunca vende; com o orçamento zerado não vende; a média/histórico do item muda; enxurrada baixa o teto do mesmo item.
7. `_check_auction_no_loop`: as 4 invariantes da §7 com os `Balance` de agora; para **todo** item: `piso_bot > venda_loja`; item de loja:
   `teto_bot × (1 − cut) < preço × (1 − CHAIN_FAIR_DISCOUNT)`; toda receita: `teto_bot ≤ custo mínimo de fabricar`; `+1..+9`: teto abaixo
   de base + ouro gasto.
8. `_check_auction_bot_listings`: 200 pulsos: nenhum lendário/quest; preço em `[piso_bot, ref × ASK_MAX]`; ≤ `AUCTION_BAND_MAX` por faixa;
   o item sai das tabelas/`gear_pool`/cartas/poções daquela faixa; o vendedor é um nome de bot que existe (elenco ou vivo).
9. `_check_auction_d2`: inventário e ouro de todos os bots iguais antes e depois de 200 pulsos com compras e vendas.
10. `_check_auction_save`: anúncios (com o tempo que falta), caixa, histórico e orçamento voltam iguais; save sem `market` = mercado novo;
    item que saiu do catálogo some sem erro; carregar não avança o relógio.
11. `_check_auction_npc`: Leiloeiro `role: "auction"` em `city_aldara`, `city_port` e Lumeria (em todos os estágios), ícone em `NpcServices`.
12. `_check_auction_rng`: N ticks de combate com o mercado ligado e desligado dão o mesmo estado de entidades (o mercado não usa `sim.rng`).

Sonda `tools/tests/auction_probe.tscn -- [--hours=4] [--level=20] [--exploit]`:
- `SELL` = minutos até vender uma carta comum no preço de referência (mediana de 50; **alvo 10-30 min**, §4).
- `SHOW` = anúncios novos na faixa do jogador entre duas visitas de 10 min (alvo ≥ 5) e % assinados pelo elenco.
- `BUDGET` = ouro/h pago pelos bots vs o orçamento e vs o ouro/h de caça da faixa.
- `--exploit`: roda os 5 laços da §5 por 1 h; mercador↔bot, fabricar com material comprado e aprimorar ≤ 0 ouro/h; arbitragem ≤ orçamento.

Experienciais (teste de jogo; fotos em `production/qa/evidence/casa-de-leiloes/`: 4 abas, ícone do Leiloeiro, aviso de venda):
- "Vou ver o que apareceu": em toda visita depois de 10+ min há coisa nova da minha faixa; reconheço nomes do elenco.
- Vender repetidas compensa ir ao Leiloeiro (≈ 2× o mercador) sem que vender no leilão vire a principal fonte de ouro.
- A setinha e a sugestão de preço fazem sentido (quem anuncia na sugestão vende dentro do prazo de 2 h).

## 9. Perguntas abertas

Nenhuma. Respondida em 2026-11-25:
1. **Sumidouro**: fica **taxa 1% + comissão 5%** (`AH_LIST_FEE`, `AH_CUT`); ajuste fino na calibragem com o mercado rodando.

## 10. Perguntas de §5-8 (2026-11-27) — **decididas: o usuário aceitou as 4 recomendações**

1. **Tamanho da torneira** (o leilão cria ouro: os bots pagam sem ter ouro, D2). Quanto os bots podem pagar ao jogador por hora?
   *Recomendação:* orçamento `AUCTION_BOT_BUDGET_PER_LV` = 40 × nível por hora de jogo, calibrado na sonda para ≈ 30% do ouro/h de caça
   da faixa: vender no leilão rende ~2× o mercador, mas não passa a caça como fonte de ouro.
2. **Arbitragem** (comprar barato de um bot e revender para bot). *Recomendação:* **permitir** (é a fantasia "esperteza vira ouro", §2),
   limitada pelo mesmo orçamento e pela queda por enxurrada; nada de regra extra.
3. **Carta comprada conta no Bestiário** como "achada" (e para o título de zona)? *Recomendação:* **sim**, como `cartas.md` §5 já diz
   ("entrou na sua bolsa"); o título é de coleção, e o leilão é o caminho das repetidas (D6).
4. **Itens sem preço** (Pergaminhos de Refino, Baús do MVP, Moeda Lendária, prêmios de GvG/MVP) no leilão? *Recomendação:* **não na 1ª leva**:
   são prêmios de atividades próprias e não têm preço de referência; reavaliar depois do teste de jogo.
