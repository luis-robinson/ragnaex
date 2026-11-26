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

## 5-8. Edge Cases, Dependencies, Tuning Knobs, Acceptance Criteria

Depois do conceito fechado. Dependências já vistas: `Stats.STAT_KEYS` (+ `xp_pct`, `drop_pct`), `LootSystem` (XP e sorteios),
`RecipesCatalog`, `ItemsCatalog` (consumíveis), arte (`item_icons`: frasco por tipo/grau), `BuffLooks` (visual do buff no corpo),
ícone na barra de buffs do HUD, `cartas.md`.

## 9. Decisões do usuário (2026-11-25)

1. **Números da §4 ficam como estão** (incluindo os tetos `XP_PCT_CAP` 60 e `DROP_PCT_CAP` 100).
2. **Fortuna vale só para itens e cartas**: o ouro não muda.
3. **Só quem tomou**, **30 min** de jogo (§3.3/§3.4 como escritos; sem versão de grupo).
4. **Primeira leva = Saber + Fortuna.** Depois do teste de jogo entram três na mesma linha: colheita mais rápida,
   mais material por abate e menos XP perdido ao morrer.
