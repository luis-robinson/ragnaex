# Forja e Refino — telas novas do Ferreiro e do Alquimista

> Status: **APROVADA PARA IMPLEMENTAR** (2026-11-26, pedido do usuário: "melhorias na tela de craft e no refino"). Nada implementado.
> Escopo escolhido pelo usuário: **abas/filtro/ordem, prévia antes/depois, de onde vem o material, ações em lote**.
> Só apresentação: as regras continuam em `CraftSystem` / `WorldSim.enhance` (custos e efeitos não mudam).
> Liga com `mvp-premios.md` (Pergaminho de Refino usado aqui).

## 1. Overview

Hoje (fotos em `production/qa/evidence/forja-refino/antes_*.png`):
- **Forja/caldeirão** (`npc_ui._craft`): uma lista longa de cartões com TODAS as receitas da estação, começando no nível 1
  (um nível 30 rola até achar as dele); materiais em texto vermelho/verde sem ícone; nada diz onde achar o que falta; cria 1 por clique.
- **Refino** (`npc_ui._enhance`): uma lista só com o vestido e a bolsa misturados; mostra custo e "→ +N", mas não o que
  a peça **ganha**; materiais que você tem só no topo; um passo por clique, sem retorno visual.

A proposta troca as duas por uma tela de **duas colunas** (lista à esquerda, detalhe à direita), com abas, filtro,
prévia e lote.

## 2. Player Fantasy

"Entro no ferreiro, vejo na hora o que dá para fazer e quanto a minha espada melhora." Menos rolagem, menos conta de cabeça,
e o refino tem o seu momento (o brilho, o som do martelo).

## 3. Detailed Rules

**3.1 Forja e caldeirão.**
```
 Brom, o Ferreiro                                   Ouro 5.000
 [Amuletos][Anéis][Capas][Bolsas]        [x] Só o que posso fazer  [x] Minha faixa
 ┌ lista ───────────────────────┐ ┌ detalhe ──────────────────────────────┐
 │ ◇ Amuleto do Guerreiro de Aço │ │ [ícone 64] Amuleto do Guerreiro de Aço │
 │   Lv 25  ●●●  pode fazer      │ │ FOR +38  VIT +24  Vida +3%             │
 │ ◇ Amuleto do Caçador de Aço   │ │ vs. vestido: FOR +12 ▲  VIT −4 ▼       │
 │   Lv 25  ●●○  falta 1         │ │ Materiais: [ícone] Lingote 3/3          │
 │ ...                           │ │            [ícone] Presa de Lince 1/2 ⓘ │
 └───────────────────────────────┘ │ 120 ouro         [ - 1 + ] [Criar]     │
                                   └────────────────────────────────────────┘
```
- **Abas por tipo** do resultado: Ferreiro = Amuletos, Anéis, Capas (as que ele faz hoje); Alquimista = Poções, Elixires,
  Capas, Bolsas (o que `recipes_for_station` devolver, agrupado pelo tipo/slot do item). Aba sem receita não aparece.
- **Filtros** (lembrados por personagem durante a sessão): "Só o que posso fazer" (desligado por padrão) e
  "Minha faixa" (ligado: `level_req` entre `nível − CRAFT_BAND_BELOW` e o nível; as acima do nível aparecem no fim em cinza
  com "Lv N"). **Ordem**: nível da receita, maior primeiro; dentro do nível, as que pode fazer primeiro.
- **Linha da lista**: ícone, nome, nível e um ponto por material (cheio = tem). Clique seleciona; duplo clique = Criar x1.
- **Detalhe**: o tooltip do item (o mesmo `UiKit.item_tooltip`) + **comparação** com a peça vestida no mesmo slot
  (anel: compara com o pior dos dois). Materiais com **ícone** e tem/precisa; o que falta em vermelho com **ⓘ de onde vem** (§3.3).
- **Lote**: seletor de quantidade (1 até o máximo que dá com o que você tem, `CraftSystem.max_craftable`), "Criar xN".
  Em bolsa sem espaço para N, o máximo já conta isso.

**3.2 Refino.**
```
 Brom, o Ferreiro — Refino                Ouro 5.000 · Minério de Ferro 30 · Minério Estelar 6
 [Vestido][Bolsa]
 ┌ lista ───────────────────┐ ┌ detalhe ─────────────────────────────────────────┐
 │ +9 Espada Enferrujada  máx│ │ [ícone 64]  +5 Cota do Escudeiro  →  +6           │
 │ +2 Escudo de Madeira      │ │ DEF   120 → 126 ▲6    MDEF  80 → 84 ▲4            │
 │ +5 Cota do Escudeiro  ◀   │ │ VIT    20 → 21  ▲1    brilho: leve → leve         │
 │ +2 Elmo do Escudeiro      │ │ Custo +6: 440 ouro · Minério Estelar 1/1 ⓘ        │
 └───────────────────────────┘ │ Até: [+6 v]  total 440 ouro · 1 Estelar           │
                               │ [Refinar]   [Usar Pergaminho (+5)] (tem 0)       │
                               └──────────────────────────────────────────────────┘
```
- **Abas** Vestido / Bolsa (hoje é tudo junto). Ordem do Vestido = ordem dos slots do boneco; Bolsa = raridade, depois nível.
- **Prévia antes → depois** com as contas de `GameData.plus_item` (o mesmo que a sim usa): ATK/MATK ou DEF/MDEF, cada
  atributo, e o degrau de brilho (`PLUS_GLOW_LOW/HIGH`). Ganho em verde.
- **"Até +N"**: seletor de alvo (+cur+1 até `PLUS_MAX` ou até onde o ouro/material dá); mostra o **total** de todos os
  passos; "Refinar" paga tudo de uma vez (na sim: N chamadas de `enhance`, para no 1º erro; nada de regra nova).
- **Material especial** do lendário (élfico, Aurora, Aço Anão/Brasa) aparece no custo de cada linha, em qualquer ferreiro
  (hoje só aparece no topo do Ferreiro Anão). Se aquele ferreiro não pode (lendário 40+ fora do Anão), o botão diz o motivo
  e o nome do ferreiro certo.
- **Pergaminho de Refino** (`mvp-premios.md` §3.3): botão aparece quando a peça está em +0..+4 (ou +5..+6 com o Superior)
  e você tem o pergaminho; confirma antes de gastar.
- **Retorno**: no sucesso, o ícone da peça pisca no tom do brilho, som de martelo (`Sfx`, nome novo `enhance_ok`) e a
  linha sobe o número; ao chegar em +5/+9, texto "A peça brilha!".

**3.3 De onde vem (ⓘ).** Passar o mouse no material mostra até 4 fontes, nesta ordem:
1. Colheita: mapa + forma (`MapsCatalog.GATHER`).
2. Monstros que dropam (tabela de saque), os do nível mais próximo do jogador primeiro, com o mapa.
3. Lojas que vendem (mercador, Intendente).
4. Receita que faz (ex.: lingote).
Função pura `ItemSources.of(item_id) -> Array` em `game/ui/` (lê catálogos, guarda em cache na 1ª chamada). Item sem fonte: "Fonte desconhecida" (há check de que todo material de receita tem fonte).

## 4. Formulas

Nenhuma regra nova. Contas mostradas = as da sim:
- Prévia do refino = `GameData.plus_item(base, cur+k)` comparado com `plus_item(base, cur)`.
- Total do "Até +N" = Σ `Sim.enhance_cost(it, cur..N−1)`.
- Máximo do lote da forja = `min(⌊tem_i / precisa_i⌋ para cada material, ⌊ouro / custo⌋, espaço na bolsa)`.

## 5. Edge Cases

- Peça vestida com cópia igual na bolsa: o refino é por cópia (`<id>+N`), a lista mostra cada uma na sua aba.
- Lote interrompido (bolsa encheu no meio): para, aviso com quantos fez.
- "Até +N" que cruza o +6 (troca de minério): o total mostra os dois minérios.
- Ferreiro sem receita no seu nível com "Minha faixa" ligado: lista vazia com o texto "Nada na sua faixa — desligue o filtro".
- Janela pequena (`_is_compact`): as duas colunas viram uma (detalhe embaixo da lista).
- Rolagem: trocar de aba volta ao topo; criar/refinar mantém a rolagem (já há `--craft_check`).

## 6. Dependencies

`game/ui/npc_ui.gd` (`_craft`, `_enhance` reescritos; pode virar `craft_panel.gd`/`refine_panel.gd`), `UiKit`
(tooltip, ícones), `CraftSystem` (`can_craft`, `craft`, + `max_craftable` puro), `WorldSim.enhance/enhance_cost/enhance_error`,
`GameData.plus_item`, `ItemSources` (novo, catálogos: `MapsCatalog.GATHER`, tabelas de saque, lojas, receitas),
`Sfx` (`enhance_ok` em `Sfx.VOL` + `build_sfx.py`), `mvp-premios.md` (pergaminho).

## 7. Tuning Knobs

| Constante | Proposta | Faixa | O que muda |
|---|---|---|---|
| `CRAFT_BAND_BELOW` | 10 | 5-15 | quantos níveis abaixo o filtro "Minha faixa" ainda mostra |
| `CRAFT_BATCH_MAX` | 20 | 10-99 | teto do "Criar xN" |
| `SOURCES_SHOWN` | 4 | 3-6 | fontes no ⓘ |

## 8. Acceptance Criteria

1. Nível 30 no Brom com "Minha faixa": a 1ª linha da aba Amuletos é de nível ≥ 20 (check).
2. "Só o que posso fazer" esconde as que faltam material (check com bolsa montada).
3. Prévia do refino bate com o item que a sim cria depois de refinar (check: compara stats).
4. "Até +7" de +3 paga a soma certa e deixa a peça +7; sem ouro para tudo, o seletor não oferece +7 (check).
5. Todo material de receita tem ao menos uma fonte em `ItemSources` (check).
6. "Criar x5" cria 5 e gasta 5× (check); bolsa cheia no meio para e avisa.
7. Fotos depois em `production/qa/evidence/forja-refino/` (forja, refino, ⓘ aberto, flash do +5) e janela compacta.
Checks `--only=craft_ui,refine_ui`; revisar `--bag_shot=<png> --wins= --craft_tip` / `--enhance`.

## 9. Decisões do usuário (2026-11-26)

1. **"Minha faixa" ligado por padrão.**
2. **"Até +N" confirma** quando o total é ≥ 1.000 ouro (`REFINE_CONFIRM_GOLD`).
3. **Forja compara com o vestido** no mesmo slot.
Nada em aberto. O botão do Pergaminho entra quando `mvp-premios.md` existir (até lá, escondido).
