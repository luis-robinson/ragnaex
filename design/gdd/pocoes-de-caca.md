# Poções de Caça — XP e sorte feitas na alquimia

> Status: **APROVADA PARA IMPLEMENTAR** (2026-11-25, pedido do usuário). Nada implementado. Decisões do usuário em §9 (confirmadas 2026-11-26).
> §5-8 entram por escrito no começo da implementação.
> Liga com: `cartas.md` (a sorte aumenta a chance de carta), `casa-de-leiloes.md` (poções à venda).

## 1. Overview

A alquimia ganha uma linha nova de **Poções de Caça**, feitas no Alquimista com materiais que caem dos monstros:
- **Tônico do Saber**: +% de XP de monstro por um tempo.
- **Elixir da Fortuna**: +% de chance de saque (itens, lendários e **cartas**) por um tempo.
Cada uma tem **3 graus** (Menor, Comum, Maior), um por faixa de nível, com materiais da faixa. Elas dão ao jogador um
motivo para guardar e caçar materiais, e um jeito de "preparar" uma sessão de caça ("hoje eu tomo Fortuna e vou atrás
da Carta do Lobo Alfa").

## 2. Player Fantasy

"Preparei a caçada." O jogador junta material, faz as poções e sai para uma sessão com objetivo. A poção é a ferramenta
de quem planeja, não um atalho obrigatório: sem ela o jogo continua no ritmo certo.

## 3. Detailed Rules (conceito)

**3.1 Onde e como.** Receitas no Alquimista (`RecipesCatalog`, estação `alchemy`), como os elixires de hoje. Custo =
ouro + materiais de monstro da faixa (ex.: Menor = pele de lobo + gel de lodo; Maior = materiais do 30+). Grau maior
exige nível mínimo para **fazer**, não para tomar.

Materiais escolhidos (2026-11-26, de monstros comuns da faixa; ouro e quantidades em `RecipesCatalog.HUNT_MATS` e
`Balance.HUNT_POTION_GRADES`):

| Receita | Nível | Ouro | Materiais (fonte) |
|---|---|---|---|
| Tônico do Saber Menor | 5 | 30 | Gel de Slime ×2 (slimes 1-5), Pele de Lobo ×1 (lobo 7), Erva Azul ×2 |
| Elixir da Fortuna Menor | 5 | 30 | Casco de Caranguejo ×2 (caranguejos 4-5), Ferrão de Vespa ×2 (vespas 4-7), Erva Verde ×1 |
| Tônico do Saber Comum | 20 | 150 | Fragmento de Osso ×3 (mortos-vivos 21-25), Essência Espectral ×2 (fantasmas 26-28), Erva Azul ×2 |
| Elixir da Fortuna Comum | 20 | 150 | Bile Pútrida ×3 (podres 20-25), Minério Estelar ×2 (esqueletos 24-28), Erva Verde ×2 |
| Tônico do Saber Maior | 35 | 400 | Insígnia da Horda ×3 (Horda 30-38), Escama de Naga ×2 (nagas 31-34), Erva Azul ×3 |
| Elixir da Fortuna Maior | 35 | 400 | Dente de Goblin ×3 (goblins 30-40), Couro de Troll ×2 (trolls 35-44), Erva Verde ×3 |

**3.2 Efeito.** Buff com tempo (como os elixires, `consume.buff`), com stats novos:
- `xp_pct`: XP de **monstro** × (1 + xp_pct/100). Quest, evento e chefe de mundo **não** (a poção é para caçar).
- `drop_pct`: chance de saque × (1 + drop_pct/100) — itens, lendários e cartas; o ouro não muda (§9.2).

**3.3 Duração e pilha.** Duração longa (proposta **30 min de jogo**), relógio só anda com o jogo aberto. Um de cada tipo
ao mesmo tempo (Saber + Fortuna juntos pode); tomar outro do mesmo tipo **renova** (não soma), regra de buff que já existe.
Morrer **não** tira (a poção é cara de fazer).

**3.4 Grupo.** Só vale para quem tomou (o abate do grupo continua dividindo como hoje).

**3.5 Bots.** Bots também fazem e tomam às vezes (aparece no chat: "tomei um Tônico, bora caçar"); calibragem dos bots
continua sem poção na sonda.

**3.6 Venda.** As poções podem ser vendidas na Casa de Leilões (quando existir); o mercador não vende (só a alquimia faz).

## 4. Formulas (propostas, calibrar depois)

| Poção | Grau | Nível p/ fazer | Efeito | Duração |
|---|---|---|---|---|
| Tônico do Saber | Menor / Comum / Maior | 5 / 20 / 35 | +15% / +25% / +35% XP de monstro | 30 min |
| Elixir da Fortuna | Menor / Comum / Maior | 5 / 20 / 35 | +20% / +35% / +50% chance de saque | 30 min |

- Teto de `xp_pct` e `drop_pct` somados de todas as fontes (poção + carta de acessório + evento): `XP_PCT_CAP` 60,
  `DROP_PCT_CAP` 100.
- Exemplo: carta comum a 1/75 por abate; com Fortuna Maior (+50%) = 1/50 → de ~2,4 para ~3,6 cartas/h.
- Exemplo: Tônico Comum (+25%) numa faixa em que caçar dá 45% do XP → o nível sai ~11% mais rápido.

## 5. Edge Cases

- **Grau menor por cima de um maior**: recusado (§9.5): a poção não é gasta e o jogador vê "Você já está sob um efeito
  mais forte" (`HuntPotionSystem.weaker`, em `ItemSystem.use_potion`). Mesmo grau ou mais forte renova/troca com 30 min cheios.
  Bots nunca gastam uma (só tomam sem poção do mesmo tipo ativa).
- **Morte**: o buff fica (`keep_death`); enquanto morto o relógio não anda (a sim não conta buffs de morto).
- **Sair do jogo**: o tempo que sobra vai no save (`hunt_buffs`, campo opcional; save antigo = sem poção) e volta ao carregar.
- **Duração**: fixa em 30 min; bênção do Sacerdote (`buff_duration`) **não** estica.
- **Teto**: `xp_pct` soma poção + Colônia de Pé (cerco, só no mapa dela) + futuras cartas, cortado em 60; `drop_pct` soma e corta em 100.
- **Grupo**: cada um que divide o abate usa o próprio `xp_pct`; equipamento e Moeda Lendária usam o `drop_pct` de quem rola
  (o saque comum do grupo rola com quem saqueia na vez).
- **O que a Fortuna não mexe**: ouro e os materiais da tabela de saque (a futura "mais material por abate" cuida disso).
  Mexe: equipamento que cai (`roll_gear`), Moeda Lendária (`roll_legendary`) e cartas (`LootSystem.drop_mult`).
- **XP que não conta**: missão, evento de estrada (sem XP de abate) e lacaios de chefe com 0 XP. Chefe comum de campo/masmorra conta (é abate).
- **Chance passando de 1**: a chance multiplicada é cortada em 1 (o sorteio continua um só).
- **Bots**: tomam às vezes ao chegar no mapa de caça (pagam o ouro da receita, sem material), falam no chat; desligado nas sondas de calibragem e nos testes.

## 6. Dependencies

`Stats` (`xp_pct`, `drop_pct` em `STAT_KEYS`/`compute`), `LootSystem` (`xp_mult`, `drop_mult`, abate), `ItemSystem.roll_legendary`,
`WorldSim._kill` (não tira `keep_death`), `HuntPotionSystem` (core/sim/systems), `ItemsCatalog`/`RecipesCatalog` (laço por grau),
`SaveSystem` (`hunt_buffs`), `BotBrain` + `BotsCatalog.HUNT_POTION_LINES`, `BuffLooks.HUNT`, `Hud._buff_source`, `item_icons` (`_a_tonic`, `_a_fortune`),
`cartas.md` (o sorteio de carta chama `LootSystem.drop_mult(e)`), `SiegeSystem.xp_mult` (soma no mesmo teto), `casa-de-leiloes.md` (poções à venda no leilão, `AuctionSystem`).

## 7. Tuning Knobs (`data/balance.gd`)

| Knob | Valor | Faixa segura | O que muda |
|---|---|---|---|
| `HUNT_POTION_TIME` | 1800 s | 600-3600 | duração da sessão preparada |
| `HUNT_POTION_GRADES` | [nível, ouro, %Saber, %Fortuna, preço] por grau | % até o teto | força e custo de cada grau |
| `XP_PCT_CAP` | 60 | 40-100 | quanto a XP de caça pode subir somando fontes |
| `DROP_PCT_CAP` | 100 | 50-200 | quanto a chance de saque pode subir |
| `BOT_HUNT_POTION_CHANCE` | 0,2 | 0-0,5 | quantos bots chegam na caça com poção |

## 8. Acceptance Criteria

1. Tomar o Tônico Comum põe `hunt_xp` com 1800 s e `stats.xp_pct` 25; o Maior por cima troca para 35 (não 60); o Menor por cima
   do Maior é recusado e não é gasto; o mesmo grau renova os 1800 s.
2. Abate de monstro com Saber Maior dá XP × 1,35; XP de missão igual com ou sem poção.
3. Com `drop_pct` 50 a chance de equipamento/Moeda sobe × 1,5; o ouro do abate é o mesmo com ou sem poção.
4. Duas fontes acima do teto: `xp_mult` = 1,6 e `drop_mult` = 2,0.
5. Morrer não tira as poções; `buff_duration` não estica; o restante volta do save.
6. As 6 receitas existem no Alquimista, nível 5/20/35, e todo material delas cai de algum monstro comum.
7. Ícone pintado das 6 poções e ícone/visual do buff no HUD e no corpo (evidência em `production/qa/evidence/pocoes-de-caca/`).

## 9. Decisões do usuário (2026-11-25)

1. **Números da §4 ficam como estão** (incluindo os tetos `XP_PCT_CAP` 60 e `DROP_PCT_CAP` 100).
2. **Fortuna vale só para itens e cartas**: o ouro não muda.
3. **Só quem tomou**, **30 min** de jogo (§3.3/§3.4 como escritos; sem versão de grupo).
4. **Primeira leva = Saber + Fortuna.** Depois do teste de jogo entram três na mesma linha: colheita mais rápida,
   mais material por abate e menos XP perdido ao morrer.
5. **Grau mais fraco não rebaixa** (2026-11-26): tomar uma poção mais fraca com uma mais forte do mesmo tipo ativa é recusado,
   a poção não é gasta e aparece "Você já está sob um efeito mais forte". Igual ou mais forte renova/troca. Bots nunca gastam uma.
   O campo `hunt_buffs` do save fica como está.
