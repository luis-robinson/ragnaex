# Druida — animações para revisitar

Estado em 2026-11-03: as formas funcionam (sim, modelo, armadura de animal), mas a animação é a mínima.
Este documento lista o que falta, em que ordem fazer e como revisar.

## O que existe hoje

- **Modelos**: `form_wolf.glb` e `form_bear.glb` (`druid_sets.build_forms`, corpo de `mob_kit.quadruped`).
- **Clipes do bicho**: só `idle`, `run`, `attack`, `hit`, `die` (`build_monsters.mob_actions(quadruped=True)`).
- **Em forma, toda skill toca `attack`** (`EntityView._animate_glb` cai em `attack` quando o clipe pedido não existe).
  O tempo de impacto usa `IMPACT_FRAME.get(clip, 5)`, que não foi medido para o `attack` do bicho.
- **Sem pulo, dash, bloqueio nem queda**: o bicho usa `run` no lugar.
- **Transformar não tem transição**: o kit some e o bicho aparece no mesmo quadro.
- **Furtividade**: só transparência (0,7), sem animação de andar abaixado.
- **Forma humana**: as skills novas (`dru_spirit_wolves`, `dru_treant`, `dru_grove`, `dru_prowl`, `dru_wolf_form`,
  `dru_bear_form`) usam os clipes de família genéricos do kit (`cast_buff`, `cast`, `summon`).

## Clipes que faltam no bicho (lobo e urso)

Prioridade 1 (aparecem toda hora):

| Clipe | Uso | Lobo | Urso |
|---|---|---|---|
| `bite` | golpe básico, Mordida, Dilacerar | bote curto com a cabeça | — |
| `swipe` | golpe básico, Patada do Urso, Esmagar | — | patada lateral com a pata da frente |
| `pounce` | Salto do Lobo, Investida do Urso (skills com `dash`) | salto longo, patas estendidas | corrida de ombro baixo |
| `slam` | Pisão do Urso, Avalanche (área ao redor) | — | ergue nas patas de trás e cai |
| `spin` | Redemoinho de Presas (área ao redor) | giro de 360° mordendo | — |
| `howl` | Uivo da Matilha, Rugido do Urso (buff/provocar) | cabeça para cima | ergue e ruge |

Prioridade 2 (deixam o bicho vivo):

| Clipe | Uso |
|---|---|
| `dash` | dash do jogador em forma (hoje usa `run`) |
| `jump` / `fall` / `land` | pulo (Espaço) em forma |
| `prowl` | andar abaixado durante a furtividade (corpo baixo, passo lento) |
| `idle_alert` | parado em combate (respiração mais rápida, cabeça baixa) |
| `shift_in` / `shift_out` | 0,3 s de transformação (encolhe/cresce + partículas de folha) |

## Mapeamento skill → clipe em forma

Hoje `EntityView._action_clip` só conhece os clipes do kit. Proposta: `_form_clip(s)` quando `form_view != null`,
pela forma da skill (como `_action_clip` faz por família):

- `SkillDef.Target.TARGET` ou básico → `bite` (lobo) / `swipe` (urso)
- tem `dash` → `pounce`
- `Target.SELF` com raio e dano → `spin` (lobo) / `slam` (urso)
- `Kind.BUFF` ou `taunt` → `howl`
- `Target.CONE` → `swipe` (urso) / `bite` (lobo)
- qualquer outro → `attack`

Cada clipe novo entra em `IMPACT_FRAME` com o quadro medido do impacto (a skill acerta no fim do `startup`).

## Forma humana (kit)

- `dru_wolf_form` / `dru_bear_form`: clipe próprio `shapeshift` (agacha e se encolhe), casado com `shift_in`.
- `dru_spirit_wolves` / `dru_treant`: usar `summon` com partículas verdes (tema `nature`/`summon` em `SkillFx`).
- `dru_grove`: `cast_buff` com o cajado erguido; conferir se o cajado de duas mãos não atravessa a cabeça.
- Cajado do Xamã: o idle do cajado (`idle_staff`) foi feito para o cajado comum; conferir com as cabeças grandes
  (cristal, galhada, semente) de frente e de lado.

## Como fazer

1. Clipes do bicho: em `build_monsters.mob_actions` (ou uma função só para as formas, para não mexer nos monstros),
   com `lp.add_action(arm, "<nome>", {osso: [(quadro, rotação, posição)]}, fim)`. Ossos: `body`, `head`,
   `leg_fr`, `leg_fl`, `leg_br`, `leg_bl`.
2. Refazer só as formas: `druid_sets.build_forms(<pasta>)` + `--import`.
3. `EntityView`: `_form_clip(s)` e loop em `idle`/`run`/`prowl`.
4. Transição: um nó de partículas em `SkillFx` no `_swap_form`, mais `shift_in`/`shift_out` no bicho.

## Como revisar (loop)

- Filme de cada clipe: `lineup.tscn -- --strip=druid --set=<fera|guardiao_verde> --form=<wolf|bear> --anim=<clipe>`
  (8 quadros; falta um modo `--strip` para formas, hoje `--form` mostra os 6 conjuntos lado a lado).
- No jogo: `-- --autostart=druid --gear=<set_id> --form=<wolf|bear>` e lançar cada skill.
- Nota 0–2 em: pose (lê de cima?), tempo (impacto no quadro certo), forma (casa com a área da skill),
  identidade (lobo ≠ urso), retorno (volta ao idle sem pulo). Passa com ≥ 8, como em `docs/skills_review.md`.
- Testes a adicionar: cada clipe da tabela existe nos dois GLBs; `_form_clip` nunca devolve vazio para skill da build.
