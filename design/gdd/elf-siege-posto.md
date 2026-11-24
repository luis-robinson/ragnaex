# Cerco do Posto dos Caçadores (Floresta Sombria, faixa 10-20)

> Status: **APROVADO PARA IMPLEMENTAR** (decisões do usuário 2026-11-24 em `design/gdd/elf-band-refactor-proposal.md`, D4/D5 = Cerco Vivo
> completo, D3/D6 = só o Rei muda o mundo). Autor: world-builder. Modelo: `design/gdd/act2-siege-life.md` (Porto Esperança).
> Substitui a investida única de `RAIDS["field_forest"]` (uma leva de ~21-30 elfos a cada 240 s, nascida num disco de 3,5 m — causa
> raiz em §5.1 da proposta).
> Canon: Established (cerco élfico, Comandante Hela, garganta norte, Rei Aelthar). Novo: os dois flancos e o assédio da crista.
> Visível ao jogador: Sim (avisos no chat, faixa do HUD). Cross-refs: `act2-siege-life.md`, `elf-band-refactor-proposal.md` §5,
> `docs/roteiro_10_20*` (a confirmar). Contradições: nenhuma — a fala do el6 ("as trompas pararam") passa a ser verdade no código.

## 1. Overview

O Posto dos Caçadores deixa de receber "a" investida e passa a viver um **cerco**: os elfos descem a garganta norte e atacam por
**três lados** — o portão norte (sempre) e dois **flancos** (Portão Oeste pela trilha das teias, Portão Leste pelo bosque) que
ficam abertos até o jogador fechá-los com quests da faixa. Uma leva por vez, revezando os lados, de tamanho médio (~10-12),
nascendo em **escalões** (linces → espadas → arqueiros/magos → grifos) num arco, longe da chegada do portal. A **pressão** sobe
com a história: patrulhas raras antes do alarme (el1), cerco depois dele, fúria quando os Guardiões da Raiz caem (el5), e **paz**
depois do Rei (el6). Assédio: arqueiros na crista nordeste soltam salvas avisadas. Batedores (linces com trompa) na estrada
adiantam a próxima leva. Dois soldados de **reserva** correm para o lado atacado. Mesmo motor do Porto (`SiegeSystem`),
generalizado por mapa; o Porto não muda.

## 2. Player Fantasy

"Eu seguro o Posto e, a cada quest, ele fica mais fácil de segurar." O jogador de nível 14-19 ouve a trompa, lê no chat **por qual
portão** vêm, corre para lá, vê a leva chegar em ondas (linces primeiro, a linha de espadas, os arqueiros atrás) e não como um
bloco. Fechar um flanco é visível (a leva daquele lado passa a ir ao portão norte, onde a guarnição é forte). Caçar os batedores
na estrada é recompensado (menos levas). Matar o Rei calou as trompas: o Posto descansa. Pilar: mundo vivo que responde às suas
quests; MDA — Dinâmica de "ler o aviso → posicionar" e Estética de desafio + descoberta; SDT — competência (escalões legíveis)
e autonomia (escolher que flanco fechar primeiro).

## 3. Detailed Rules

R1. `MapsCatalog.SIEGE["field_forest"]` liga o `SiegeSystem` na Floresta; o relógio próprio do `RaidSystem` para (como no Porto).
R2. **Rotas** (lado = `side`): `muralha_norte` (portão norte, `gate_route`), `flanco_oeste` (trecho `oeste`), `flanco_leste`
    (trecho `leste`), `patrulha_norte` (`low_route`), `assedio_crista` (`kind: harass`). Todas com `unless: el6_king`.
    Gravadas no JSON da zona (`raids` com `side`, `build_field_forest.RAIDS`, desde 2026-11-24); o `raid` antigo
    (from = chegada do portal) saiu do JSON.
R3. **Trechos** (`segments`): `oeste` "Portão das Teias" fecha com `els_steel` (Gunnar reforça o portão oeste com aço élfico);
    `leste` "Portão da Ponte" fecha com `els_lynx` (sem os linces os elfos perdem a trilha do bosque). Sem `close_all`.
    Aberto = a leva daquele lado vai pelo flanco até o portão dele; fechado = vai ao portão norte. Reuso de quests existentes;
    nenhuma quest nova (as duas abrem logo depois de el1, nível 15-16).
R4. **Pressão** (1ª linha que vale): `p0` se `el6_king` (paz); `p3` se `el5_wardens` (fúria); `p2` se `el1_alarm` (cerco);
    `p1` sem nada (patrulha rara `patrulha_norte`). Fortes dos capitães não mudam nada (D6).
R5. **Revezamento**: as levas giram `oeste → norte → leste → norte → …` (rotação `rotation` do cerco); lado de trecho fechado cai
    no portão norte. Uma leva viva por vez; calmaria `SIEGE_QUIET_MIN` depois de repelida.
R6. **Escalões** (novo, só em mapas com `Balance.SIEGE_STAGGER[<mapa>]`): a leva nasce em escalões pela ordem `order`
    (lince 0, espada 1, arqueiro/mago 2, grifo 3), um escalão a cada `gap` s, cada um num **arco** de `arc` m de largura
    perpendicular à 1ª perna da rota; cada invasor marcha numa **vaga** lateral fixa (±`lane` m) que vale só se o ponto deslocado é
    andável; a junta (trompas) dura `muster` s contados do nascimento do escalão. A leva só acaba quando nada falta nascer.
    Mapas sem a entrada (Porto, Bastião, Estepes, Kharzun) seguem byte a byte iguais.
R7. **Assédio** (p ≥ 2): `SIEGE_HARASS_SHOOTERS` Arqueiros Batedores nascem na crista nordeste e, depois do preparo, soltam uma
    salva de círculos avisados na brecha aberta mais próxima (sem brecha: o portão norte). Números por mapa (§7).
    Tema/som da salva: `mob_root_arrow` (`siege.volley_skill`). Dano não esquivável, regras de teto do Porto (2 círculos, não mata
    quem estava ≥ 30%).
R8. **Batedores com trompa**: dois pares de `elf_lynx` em `MOB_PATROLS["field_forest"]` com `{"horn": true}` (estrada norte e
    trilha oeste), `unless el6_king`. Em luta há `SIEGE_HORN_DELAY` s tocam a trompa e adiantam a próxima leva.
R9. **Reserva**: as sentinelas `MapsCatalog.FOREST_SIEGE_RESPONDERS` (Soldada Yara do norte e Soldado Juno do sul) ganham
    `responder` e correm para o lado atacado.
R10. **Paz** depois de `el6_king`: pressão 0, rotas e batedores calados (`unless`), nenhum assédio. Leva viva no momento da quest
    termina normalmente.
R11. Força: `RaidSystem.scaled_def` e `scale_extra` continuam (nível do jogador 15-20); `RAID_MAP_POWER` não muda na Floresta.
R12. Repelida = buff de moral do cerco (`colonia_de_pe`, hoje com o nome do Porto — ver Decisões abertas) e +XP no mapa.
R13. Chamas (leva chega e não é repelida): só a fala `say_scorch` até o Blender pôr marcadores `fx` no Posto (BLENDER REQUEST).

## 4. Formulas

- F1 intervalo da leva: `max(SIEGE_QUIET_MIN, every × SIEGE_EVERY_MULT[p] + u × jitter)` (igual ao Porto). Floresta: `every` 120 s,
  jitter 20 → p2 = 100-140 s, p3 = 80-112 s, p1 (patrulha, every 150) = 280-320 s.
- F2 tamanho: `round(n × SIEGE_SIZE_MULT[p] × fit)` por monstro (igual ao Porto).
  Flanco: lince 2, espada 4, arqueiro 3, mago 1 = 10; portão norte: 2/5/3/2 = 12; leva grande (a cada `SIEGE_BIG_NTH[p]`):
  +2 grifos +1 lince. Patrulha: espada 2 + lince 2 (×0,6 = 1+1).
- **Mesmo total**: antes ~25 elfos / 240 s (21 + 6 a cada 2ª + 3 a cada 3ª); agora (p2, revezando 10/12/10/12) ≈ 22 + 2 (grande)
  ≈ 24 / 240 s, mais 2 atiradores por assédio. Pico vivo: ~12-15 (antes 21-36).
- F6 escalões: invasor do escalão k nasce em `t = k × gap`; posição = `from + perp × (s - 0,5) × arc + jitter 1,5 m` com
  `s = (i + 0,5) / n` no escalão; vaga lateral = `((id % 5) - 2) / 2 × lane` m.
- Chegada espalhada (meta AC-5): desvio padrão dos tempos de chegada dos invasores ao raio do alvo ≥ 8 s; maior aglomerado
  (círculo de 6 m) ≤ 8 invasores durante a marcha.

## 5. Edge Cases

- Jogador sai do mapa: o relógio do cerco para (como o Porto); levas vivas terminam (lifetime).
- `el6_king` com leva viva: ela termina; nenhuma nova. Batedores somem ao respawn (`unless`).
- Todas as brechas fechadas: levas de flanco caem no portão norte; o assédio mira o portão norte.
- Escalão sem andável no arco: `random_walkable` em volta do ponto (fallback = `from`).
- Vaga lateral dentro de obstáculo/água: usa o ponto da rota sem deslocamento.
- Leva toda morta antes do último escalão: o próximo escalão sai na hora (a leva não "acaba" com gente por nascer).
- Bots: `BotBrain._defend` usa `raid_status.gate` (portão mais perto do fim da rota) — já serve aos três lados;
  `SIEGE_BOT_DEFENDERS` avulsos por leva; grupo do jogador sempre.
- Save: nada novo (pressão e trechos saem das quests).
- Sondas/testes com `hold`: o relógio não anda; `start_wave` à mão continua.

## 6. Dependencies

`SiegeSystem` (generalizado: rotação, números por mapa, tema da salva), `RaidSystem` (escalões/arco/vaga opt-in), `MonsterBrain._march`
(junta por escalão), `MapsCatalog` (SIEGE, rotas, patrulhas, reserva), `QuestsCatalog` (els_steel, els_lynx, el1, el5, el6 —
textos de dica), `Balance` (`SIEGE_MAP`, `SIEGE_STAGGER`), `BotBrain._defend`, HUD (`RaidSystem.status`, sem mudança),
`siege_fx.gd` (Chamas, quando houver `fx`), Blender `build_field_forest.py` (rotas/fx definitivos), agente "Posto vivo" (alarme,
refugiados: não é deste pacote).

## 7. Tuning Knobs

| Knob | Onde | Valor | Faixa segura |
|---|---|---|---|
| every / jitter das rotas | `FOREST_RAIDS` | 120 / 20 s | 90-180 |
| tamanho flanco / norte | `FOREST_RAIDS` waves | 10 / 12 | 8-14 |
| first_wave | `Balance.SIEGE_MAP.field_forest` | 60 s | 45-90 |
| harass_every / dmg_pct / shooters | `SIEGE_MAP` | 60 s / 8% / 2 | 45-90 / 6-12 |
| gap / arc / lane / muster | `Balance.SIEGE_STAGGER.field_forest` | 4 s / 12 m / 3 m / 4 s | 4-10 / 8-16 / 0-5 / 0-12 |
| força dos invasores do Posto | `Balance.RAID_MAP_POWER.field_forest` | 1,2 | 1,0-1,3 |
| ordem dos escalões | `SIEGE_STAGGER.order` | lince 0, espada 1, arco/mago 2, grifo 3 | — |
| reserva | `FOREST_SIEGE_RESPONDERS` | 2 | 0-3 |

## 8. Acceptance Criteria

- AC-1 `SIEGE["field_forest"]` existe; segmentos `oeste`/`leste` com quests que existem e são da faixa (nível ≤ 20); `gate_route`,
  `low_route`, `harass_route` apontam para rotas do mapa; toda rota tem `unless` com `el6_king`.
- AC-2 Pressão: sem quests = 1; `el1_alarm` = 2; `+el5_wardens` = 3; `+el6_king` = 0, e com 0 o relógio não solta leva
  (sim de 600 s: 0 levas, 0 assédio).
- AC-3 Trecho aberto → `next_route` = rota do flanco; fechado (`els_steel`/`els_lynx`) → portão norte.
- AC-4 Nenhuma rota nasce a menos de 20 m de chegada de portal/`spawn_point`.
- AC-5 Escalões: no tick do início nasce só o 1º escalão; o resto nasce em ≥ 3 instantes diferentes espaçados ≥ `gap`; nenhum
  escalão tem dois invasores no mesmo ponto; largura do nascimento ≥ `arc × 0,5`.
- AC-6 Porto sem mudança: `--only=siege` verde; rota sem `SIEGE_STAGGER` nasce toda no mesmo tick (regressão).
- AC-7 `raid_probe --map=field_forest --side=<lado> --bots=0,1,3`: guarnição sozinha repele ≥ 70% no portão norte e ≥ 50% nos
  flancos (os flancos são o lugar onde o jogador faz falta), 0 presos; `--siege_run=1800`: p2 com 0 bots repele ≥ 60%,
  `invasores_max` ≤ 20 (antes ~36).
- AC-8 `tests.tscn` 0 falhas; smoke sem SCRIPT ERROR.

## Medições (2026-11-24, `raid_probe`, nível 16, 20 levas por lado, `--quests=el1_alarm` = p2; `RAID_MAP_POWER` 1,2, `gap` 4 s)

| Lado | 0 bots | 1 bot | 3 bots |
|---|---|---|---|
| Portão norte (12-15 elfos) | 20/20, luta 105 s, 8,8 sentinelas mortas | 20/20, 34 s | 20/20, 30 s |
| Flanco oeste (11) | 16/20 (80%), luta 97 s, 6,3 mortas | 20/20 | 20/20 |
| Flanco leste (11) | **7/20 (35%)**, luta 130 s, 8,1 mortas | 18/20 | 20/20 |
| Relógio real 30 min (`--siege_run=1800`, revezando) | 75% (6/8, 2 Chamas) | 92% | 90% |

Chegada espalhada: desvio dos tempos de chegada 19-22 s (antes: leva única, ~0-7 s); vivos ao mesmo tempo 13-18 (antes até 36);
presos 0. O flanco leste fica abaixo do AC-7 (≥ 50% só com a guarnição): é o lado com menos gente (2 soldados + 2 caçadoras na
torre) — de propósito "o lugar onde o jogador faz falta", e fecha com `els_lynx`. Knobs se o usuário quiser mais folga: `RAID_MAP_POWER`
1,2 → 1,1, ou um 3º `responder`.

## Decisões abertas (para o usuário)

1. Nome do buff de moral no Posto ("Colônia de Pé" é do Porto): buff próprio "Posto de Pé" (HUD + BuffLooks, outro agente) ou manter.
2. Alvo variado dos invasores (proposta §5.2 A-e) — mecânica de combate: passar pelo game-designer.
3. Marcadores de Chamas/fumaça no Posto e as rotas definitivas no Blender (BLENDER REQUEST nas notas do agente).
