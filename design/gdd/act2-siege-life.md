# Ato II — Cerco Vivo (barricadas, assédio, cenário de guerra)

> **Status**: P1 implementado (Porto Esperança) — 2026-11-17. P2 (Estepes, Kharzun) e P3 (Costa, Grutas, acabamento) pendentes.
> **Decisões do usuário (§9, 2026-11-17)**: todas as recomendadas (1b, 2a, 3a, 4a, 5a, 7a), exceto a cadência: **6c "Intenso"** —
> leva a cada ~90 s, assédio na mesma proporção (48 s), guarnição sozinha repele ≥ 75% com 0 bots. Ver "Implementação P1" no fim.
> **Autor**: game-designer (a pedido do usuário, playtest: "Por que as pessoas vão ao Ato II? Invasão, certo? Cadê as
> barricadas, a sensação de estar sendo atacado o tempo todo?")
> **Direção aprovada pelo usuário**: o Ato II tem de parecer um **cerco vivo**.
> **Depende de**: [`ato2-horda.md`](ato2-horda.md) (R2, R4, States and Transitions), [`kharzun-fase3-plan.md`](kharzun-fase3-plan.md),
> `core/sim/systems/raid_system.gd`, `core/sim/systems/world_state.gd`, `GuardBrain`, `MapsCatalog.RAIDS`/`conquest_vis`.
> **Regra deste doc**: **reusar antes de criar**. Toda peça nova abaixo diz qual sistema existente ela estende.

---

## 1. Overview

O Ato II já tem as peças de um cerco — investidas (`RaidSystem`) em Porto Esperança, nas Estepes e em Kharzun, sentinelas
(`GuardBrain`), estágios por missão (`WorldState` + `conquest_vis`) e a música "investida" —, mas elas soam a cada ~4 min, a
paliçada do porto é binária (`hx_palisade` liga tudo de uma vez) e, entre uma leva e outra, o mapa fica quieto. Este GDD
transforma esses sistemas num **cerco contínuo em camadas**: (1) **barricadas em trechos** que o jogador fecha com missões de
defesa, cada trecho mudando o visual, a colisão, os postos de sentinela e **por onde a Horda entra**; (2) um **ritmo de
ataques em três camadas** — assédio curto (flechas de fogo, trompas), batedores nas estradas e levas menores e mais
frequentes — que **sobe** antes de cada vitória e **desce** depois dela; (3) **cenário de guerra** (casas queimadas,
refugiados, enfermaria, torres de vigia, fumaça no horizonte) e uma **linha de frente visível** que anda com as missões.
Tudo é lido de `quests_completed` (sem campo novo no save), a falha nunca bloqueia progresso e o custo cabe no orçamento
de ≤ 10 ms/tick com Kharzun carregado.

---

## 2. Player Fantasy

**"Cheguei numa colônia que está caindo — e fui eu que fechei o muro."**

- **Chegada (C0)**: o navio encosta e o porto está **em obra sob fogo**: vãos abertos na paliçada, fumaça de casa queimada,
  feridos numa tenda, trompas no morro. Em menos de 1 minuto alguma coisa acontece (uma salva de flechas de fogo cai perto do
  vão nordeste). O jogador **sente urgência** sem ser punido por ela.
- **Construir a defesa**: cada missão de defesa fecha um trecho **à vista** — andaime vira estaca, um besteiro sobe na
  torre nova, a leva seguinte **desvia** para o vão que sobrou. O jogador **vê o próprio trabalho** mudar a geografia do
  combate (Expression + Competence).
- **Empurrar a frente**: ao destruir o Acampamento dos Ginetes, o assédio do porto cala, a fumaça do nordeste some e a
  fumaça passa a subir **no horizonte das Estepes**. A guerra não acaba, **muda de lugar** — e o jogador vai atrás dela.
- **Nunca sozinho**: quando a trompa toca, bots largam a caça e correm para o vão, sentinelas descem dos postos. É o
  "MMO com bots" funcionando como fantasia de guarnição (Relatedness).

**MDA — estéticas-alvo**: **Fantasy** (colônia sitiada), **Challenge** (segurar o vão, sair dos círculos), **Expression**
(eu escolhi qual trecho fechar primeiro), **Fellowship** simulada (bots e sentinelas defendendo junto).
**SDT**: Autonomy (ordem dos trechos e das defesas opcionais; defender ou ignorar), Competence (repelir → recompensa
legível e visual), Relatedness (feridos que melhoram, refugiados que viram moradores).
**Flow**: o ritmo segue **dente de serra** — pressão sobe até o marco da zona (chefe/acampamento), alivia, e recomeça mais
alto na zona seguinte.

---

## 3. Detailed Design

### 3.1 Conceitos

| Termo | Definição | Sistema que estende |
|---|---|---|
| **Trecho** (segmento de barricada) | parte nomeada da muralha de um povoado do Ato II; `aberto` (andaime/vão, passável) ou `fechado` (estaca, colide). Fechado = missão concluída. | `conquest_vis` (lotes `tag` do `Dress`) + colisores de estágio (`MapGeometry.sync_stage`) |
| **Brecha** | o ponto de um trecho aberto que uma rota de investida usa como alvo | `MapDef.raids[*]` com `unless` |
| **Pressão** `p` | nível 0–3 de agressividade da Horda num mapa, derivado das missões | novo campo `pressure` por mapa em `MapsCatalog.SIEGE` (dados) |
| **Assédio** | evento curto sem marcha: salva de flechas de fogo / pedregulho avisada no chão perto da muralha | rota de investida `kind: "harass"` (usa `barrage`, `MobSystem.place_barrage`) |
| **Batedores** | 2 monstros que rondam uma estrada; se sobrevivem em luta por `SIEGE_HORN_DELAY` s, tocam a **trompa** e adiantam a próxima leva | `MOB_PATROLS` (ronda já existe) + flag `horn` no spawner |
| **Leva** | a investida que marcha até a brecha/portão (já existe) | `RaidSystem` sem mudança de regra de marcha |
| **Calmaria** | janela mínima sem leva depois de uma leva repelida | novo `Balance.SIEGE_QUIET_MIN` no cálculo do `timer` |
| **Chamas** (falha) | se a leva **chega** e **não é repelida** (recua por `lifetime`), o povoado ganha focos de incêndio visuais até a próxima leva repelida | estado `m["siege"]["scorch"]` + `Events.post(&"siege_event", ...)` |
| **Colônia de Pé** (sucesso) | buff curto no jogador e no grupo ao repelir uma leva perto da muralha | `put_buff` (renova, não acumula) + `BuffLooks.LOOKS` |
| **Linha de frente** | faixa de estacas/estandartes/fumaça que marca até onde a Aurora domina; troca de lugar por estágio | lotes `tag` com `if`/`unless` em cadeia |

### 3.2 Regras — Barricadas em trechos

- **R1.** Cada povoado do Ato II com investida declara seus trechos em `MapsCatalog.SIEGE[<mapa>]["segments"]`:
  `{id, quest, label}`. O trecho está **fechado** se e somente se `quest` está em `quests_completed` (`WorldState.active`).
  Sem estado novo, sem campo novo no save.
- **R2.** No Blender, cada trecho tem dois lotes no mesmo ponto: `pal_<id>_obra` (andaime, toras no chão, vão; `unless quest`)
  e `pal_<id>_pronta` (estacas, passadiço, tocha; `if quest`), via `Dress(z, seed, tag=...)` como os acampamentos da Horda
  (`act2_dress.fort`). Os sorteios de `d.rnd` são gastos igualmente nos dois para o `data/zones/<zona>.json` não mudar
  além dos colisores.
- **R3.** Colisão: os colisores do trecho entram como **colisores de estágio** com o `if` do trecho (o mecanismo de
  `MapGeometry.sync_stage` que hoje liga os 23 colisores do porto todos em `hx_palisade` passa a ligar por trecho).
  Aberto = passável; fechado = sólido. `MapGeometry.sync_stage` roda na conclusão da missão (como hoje).
- **R4.** Cada trecho tem uma **rota de investida própria** (rota no JSON, levas em `RAIDS[<mapa>][<lado>]`) com
  `unless: <quest do trecho>`: enquanto aberto, a Horda entra por ele. Fechado, a rota cala e a leva daquele lado passa a ir
  para o **portão** do povoado (rota `muralha`, que já existe e para no portão). Resultado: fechar trechos **afunila** o
  ataque — a defesa que o jogador montou vira geografia de combate.
- **R5.** Cada trecho fechado ganha um **posto de sentinela** (2 besteiros, `dawn_garrison(npc_pos, "<mapa>_w_<id>_")` com
  `if` = quest do trecho, `power` = guarda do mapa) e, onde o layout permitir, uma **torre de vigia** no lote `_pronta`.
- **R6.** **Trechos nunca reabrem.** Falhar uma defesa não destrói barricada (ver 3.5). Decisão a confirmar (Q2).
- **R7.** A última missão de muralha do povoado (no porto, `hx_palisade`) fecha **todos** os trechos que ainda estiverem
  abertos (o `if` de cada trecho é `[quest_do_trecho] OR hx_palisade`; `WorldState.active` com lista `any`). Assim os trechos
  opcionais nunca bloqueiam o estágio C1 que o resto do jogo já usa.

### 3.3 Regras — Ritmo de ataques em três camadas

Todas as camadas só andam com **o jogador no mapa** (regra atual do `RaidSystem`: `sim.player.map_id == def.id`). Interiores
e masmorras são mapas próprios: entrar numa casa ou na masmorra **pausa** o cerco daquele mapa.

- **R8. Assédio** (`kind: "harass"` numa rota de `RAIDS`): a cada `T_harass` (F1), nascem `SIEGE_HARASS_SHOOTERS` atiradores
  (arqueiro orc / ginete com tocha / catapulta em Kharzun — sempre um monstro já existente) num ponto de tiro **fora** da
  muralha (`from` da rota), que lançam 1 `barrage` de `SIEGE_HARASS_CIRCLES` círculos avisados num raio de
  `SIEGE_HARASS_SPREAD` m em volta de uma brecha aberta (ou do portão, se todas fechadas). Depois de `SIEGE_HARASS_LIFE` s
  recuam e somem (`lifetime` curto). Diferenças para a leva: aviso de chat **curto e sem faixa do HUD** (só a trompa e a
  linha de chat), não toca a música "investida", não conta como leva para recompensa nem para Chamas.
  - Os círculos seguem a gramática de cor de perigo (`FxManager.DANGER*`), são **dano de zona avisada** (não esquivável,
    `_deal_damage(..., dodgeable=false)`, regra de 2026-11-13) e **nunca** caem a menos de `SIEGE_SAFE_RADIUS` m do
    cristal, da chegada de portal ou de um NPC de serviço.
  - Matar os atiradores antes da salva cancela a salva (recompensa por reagir rápido).
- **R9. Batedores**: spawners de ronda (`MOB_PATROLS[<mapa>]`, formato atual) com `horn: true`. Regra nova (pequena): um
  monstro com `horn` que está **em luta** há `SIEGE_HORN_DELAY` s e ainda vive toca a trompa: som + chat
  ("Uma trompa soa na estrada!"), e o `timer` da próxima leva **do lado mais perto** cai `SIEGE_HORN_HASTEN` s (F4).
  Uma trompa por batedor por vida. Batedores têm `unless` = a missão que limpa aquela estrada.
- **R10. Levas**: as levas existentes ficam **menores e mais frequentes** no estágio de pressão alta (F1/F2): o `every` da
  rota é multiplicado por `SIEGE_EVERY_MULT[p]` e o tamanho por `SIEGE_SIZE_MULT[p]`. A cada `SIEGE_BIG_EVERY_NTH`-ésima leva
  entra a leva grande (já existe como `every_nth` nas `waves`).
- **R11. Calmaria**: depois de uma leva **repelida**, o próximo `timer` nunca é menor que `SIEGE_QUIET_MIN` s, nem com trompas.
  O assédio também espera `SIEGE_QUIET_MIN / 2` depois de uma leva repelida.
- **R12. Uma coisa por vez**: nunca há assédio enquanto uma leva do mesmo mapa está em `march`/`walls`; o relógio do assédio
  fica parado nesse tempo. Isso limita entidades e mantém a leitura clara.

### 3.4 Regras — Pressão e escalada pela história

- **R13.** A pressão `p` de um mapa é o **maior** `p` cuja condição vale em `MapsCatalog.SIEGE[<mapa>]["pressure"]`
  (lista ordenada de `{p, if, unless}`), e é lida a cada `WorldState.SYNC_EVERY` (1 s). Padrão do dente de serra por zona:

  | p | Nome | Quando | Assédio | Batedores | Levas |
  |---|---|---|---|---|---|
  | 3 | **Fúria** | da penúltima missão da zona até o marco (chefe/acampamento) | sim, rápido | todas as estradas | frequentes, grandes |
  | 2 | **Cerco** | chegada à zona | sim | todas as estradas | frequentes, menores |
  | 1 | **Fustigar** | marco da zona concluído | não | 1 estrada | patrulha rara (rota `patrulha` atual) |
  | 0 | **Paz** | fim do Ato II (`hx_warlord`) | não | não | não |

- **R14.** Escalada **entre** zonas: a força absoluta sobe pelo nível dos monstros da faixa (já é assim) e por
  `RAID_MAP_POWER`; a pressão relativa (frequência, camadas) recomeça em 2 em cada zona nova. A frente **anda**: a zona
  anterior cai para `p = 1` (nunca 0 antes do fim do Ato) — o mundo ainda está em guerra, só que longe.

### 3.5 Regras — Sucesso e falha (sem bloqueio)

- **R15. Repelida** (todos os invasores mortos antes do `lifetime`, regra atual): todo jogador/bot a menos de
  `radius + RAID_RALLY_MARGIN` do alvo durante a leva (os mesmos que recebem o Bastião, `_rally`) ganha o buff
  **Colônia de Pé** por `SIEGE_MORALE_TIME` s (F6). Se havia Chamas, elas apagam. Chat `say_repelled` (atual).
- **R16. Não repelida** (a leva chegou à muralha — `arrived` — e recuou por `lifetime`): o mapa entra em **Chamas**
  (`m["siege"]["scorch"] = true`): `SIEGE_FIRE_SPOTS` marcadores `FX_fire_NN` do JSON mostram fogo + fumaça baixa, moradores que
  andam (`LIVING_NPCS`) trocam a fala por uma de incêndio. **Nenhuma** perda de missão, item, serviço, trecho ou progresso.
  As Chamas apagam na próxima leva repelida.
- **R17.** Uma leva que recua **sem chegar** (jogador longe, ninguém lutou, `arrived = false`) não causa Chamas — o mundo não
  pune quem está caçando do outro lado do mapa.
- **R18. Defesa nunca depende do jogador**: com 0 bots e o jogador ausente da muralha, a guarnição repele ≥ 75% das levas
  (padrão já usado em `KHARZUN_GUARD_POWER`/`PORT_GUARD_POWER`, medido no `raid_probe`).
- **R19. Missões de defesa** (Q5): tipo novo `DEFEND` (alvo = mapa, conta 1 por leva **repelida** em que o jogador estava no
  raio do Bastião em algum momento). Se o usuário recusar o tipo novo, o fallback é `KILL` do monstro da leva (as levas usam
  o mesmo id; quests já contam), com a perda de que matar o mesmo monstro no campo também conta.

### 3.6 Regras — Bots e sentinelas

- **R20.** Bots: regra atual (`RAID_DEFEND_RANGE`, `RAID_DEFEND_CHANCE`, recuo/retorno). Acréscimo: a **trompa** (R9) conta
  como início de leva para a decisão de defender do bot do grupo do jogador (vai junto se o jogador estiver indo).
- **R21.** Sentinelas de posto (`GuardBrain`) com `responder: true` (dado) descem até o `gate_point` da rota atacada na fase
  `walls`, com coleira de `SIEGE_GUARD_LEASH` m em volta do posto, e voltam ao posto quando a leva acaba. As do portão
  continuam fixas (o portão nunca fica vazio).
- **R22.** Assédio: bots e sentinelas **saem dos círculos** (bots já fogem de `hazards`); sentinelas com arco atiram nos
  atiradores do assédio se estiverem no alcance (aggro normal).

### 3.7 Cenário de guerra (o que cada mapa ganha)

Todo item é **lote com `tag`** (`if`/`unless` de missão, `conquest_vis`) ou **NPC com `if`/`unless`** — sem regra nova na sim,
exceto Chamas (R16) e fumaça/fogo, que são apresentação lendo marcadores.

| Elemento | Forma | Vive quando | Muda para |
|---|---|---|---|
| **Casas queimadas** | casa com telhado caído, vigas pretas, cinza no chão (variante em `places.py`/`prop_kit`) | `unless` a missão de muralha | casa com andaime e telhado novo (`if`) |
| **Acampamento de refugiados** | 4–6 tendas baixas, fogueira, carroça parada, 4 refugiados (`LIVING_NPCS`, `carry`) | do início até o marco da zona | tendas somem; 2 refugiados viram moradores (`VILLAGERS` com `if`) |
| **Enfermaria** | tenda aberta com catres; curandeira (NPC de serviço: vende poção, `shop: merchant` de consumíveis) + feridos | sempre até `p = 1`; nº de feridos cai por estágio (3 → 1) | curandeira fica, catres vazios, um ferido curado vira sentinela |
| **Torres de vigia** | torre de madeira ≤ 6 m (regra de leitura de cima), tocha, besteiro em cima | `if` o trecho dela | — |
| **Fumaça no horizonte** | colunas de fumaça (partículas) em marcadores `FX_smoke_NN` **fora** do vale, na direção da ameaça | `unless` o marco que cala aquela direção | a fumaça "anda": a próxima zona tem a sua na direção do inimigo seguinte |
| **Linha de frente** | faixa de estacas cruzadas + estandarte da Aurora + braseiro, ~20 m; uma por estágio | `if` estágio N `unless` estágio N+1 | avança na direção do marco (a do estágio seguinte aparece) |
| **Chamas** (falha, R16) | fogo + fumaça baixa em 3–4 casas (`FX_fire_NN`) | estado da sim, não missão | apaga na próxima leva repelida |

### 3.8 Mapa a mapa

**Porto Esperança (`city_port`, 30–35) — P1**
- Trechos (o porto já nasce **meio feito**: o lado do mar e o cais estão prontos):
  1. `ne` **Vão da Garganta** (onde os ginetes descem) — fecha com `hx_stakes` (principal, existente).
  2. `e` **Trecho do Mangue** — fecha com `hx_df_logs` (nova, opcional, Mestre de Obras: COLLECT toras numa colheita `crate`
     na borda do mangue, 6) — ou `hx_palisade`.
  3. `n` **Portão Norte e torre** — fecha com `hx_df_tower` (nova, opcional: `DEFEND` 2 levas, ou KILL batedores 6) — ou
     `hx_palisade`.
  - `hx_palisade` (existente) continua sendo C1 e fecha o que faltar (R7).
- Pressão: `p = 2` na chegada; `p = 3` com `hx_banners` (Punhos Vermelhos) até `hx_riders_camp`; `p = 1` depois de
  `hx_riders_camp` (rota `patrulha` atual); `p = 0` em `hx_warlord`.
- Assédio: ginetes com tocha / arqueiros na crista nordeste; alvo = brecha aberta mais perto da garganta.
- Batedores: 2 rondas de 2 ginetes na estrada porto↔costa e na trilha da garganta, `unless hx_riders_camp`.
- Cenário: 3 casas queimadas (`unless hx_palisade`), refugiados do Gaivota no cais (`unless hx_riders_camp`), enfermaria ao
  lado do templo, fumaça NE (`unless hx_riders_camp`) e depois fumaça a leste-norte (direção das Estepes,
  `if hx_riders_camp unless hx_fort_war`), linha de frente: vão NE (C0) → crista NE (C1) → fora do vale (C3).

**Costa Partida (`field_coast`, 30–35) — P3** (zona de campo sem povoado: não ganha levas)
- Batedores ginetes nas estradas (`horn`): a trompa aqui adianta a leva **do porto** (o porto é o alvo da guerra; R9 aceita
  `horn_map: "city_port"`).
- Cenário: fazenda queimada no lugar da futura fazenda dos colonos (já existe a troca em C3), fumaça do Acampamento dos
  Ginetes, estacas da linha de frente na encruzilhada da Batedora Nádia (andam até o acampamento em C3).

**Grutas Goblin (`dg_goblin`, masmorra) — P3** (sem levas: bots não caçam lá sozinhos)
- Um **Tamborileiro de alarme** por salão (monstro existente com `horn`): se toca, nasce um bando pequeno do salão seguinte
  (reusa `boss_summon`/lacaios com 0 XP). Recompensa quem entra em silêncio.

**Estepes de Cinza (`field_steppe`, 35–40) — P2**
- Trechos do anel de carroças: `w` (vão oeste, `hx_trolls_bridge`), `se` (vão sudeste, `hx_fire_road`), `ne` (vão leste,
  `hx_war_drums`) — cada um a 1ª missão do lado; o acampamento retomado (`hx_fort_*`) já cala a rota (regra atual).
- Pressão: `p = 2` em E0; `p = 3` quando **só sobra um** acampamento (já existe `say_last` + `RAID_LAST_FRONT_MULT`: não somar
  mais multiplicador por cima, ver Edge Cases); `p = 1` em E5.
- Assédio: flechas de fogo do lado `fire` (`unless hx_fort_fire`) — a identidade do Mestre Besteiro chega ao Posto antes
  do jogador ir até ele.
- Batedores: 1 ronda por estrada de acampamento, `unless` do acampamento.
- Cenário: carroças queimadas viradas nos vãos abertos, enfermaria da caravana, fumaça sobre cada acampamento ativo (some
  com `hx_fort_*`), linha de frente em cada uma das 3 estradas (anda até o acampamento retomado).

**Monte Kharzun (`field_kharzun`, 40–45) — P2**
- Trechos: a paliçada do Acampamento Avançado já cresce por estágio K0–K2; vira 2 trechos (`leste` com `hx_mines`, `norte`
  com `hx_kennel`), mantendo as tags de estágio atuais.
- Assédio: **pedregulhos de catapulta** da cidadela sobre o portão norte (`unless hx_citadel_gate`); em K2 as catapultas da
  Aurora respondem (só visual, já previstas).
- Batedores: os Assassinos de estrada (até K1d) recebem `horn`.
- Pressão: `p = 2` K0; `p = 3` de `hx_slayers` a `hx_citadel_gate`; `p = 1` depois de K2 (a Ofensiva da Aurora assume, regra
  atual); `p = 0` em K4.
- Linha de frente: sobe a avenida da cidadela K2 → K3 → K4 (coincide com a Ofensiva).

### 3.9 Ritmo-alvo (cadência)

| Estágio | "Algo acontece" a cada | Assédio | Leva | Leva grande |
|---|---|---|---|---|
| p = 3 Fúria | 35–60 s | 60 s ±20% | 120 s ±20% | toda 2ª |
| p = 2 Cerco | 45–90 s | 80 s ±20% | 150 s ±20% | toda 3ª |
| p = 1 Fustigar | 4–6 min | — | 300 s ±20% (patrulha) | — |
| p = 0 Paz | — | — | — | — |

Primeiro evento ao entrar no mapa: assédio em 40 s, leva em 75 s (dá tempo de achar o cristal e a Governadora).

### 3.10 Arte × dados × código

| Camada | O que | Onde |
|---|---|---|
| **Arte (Blender)** | trechos `pal_<id>_obra`/`_pronta`, torres de vigia, casas queimadas e reconstruídas, refugiados (tendas), enfermaria (catres), linha de frente por estágio, marcadores `FX_smoke_NN`/`FX_fire_NN`, pontos de tiro do assédio (rota no JSON) | `build_city_port.py`, `act2_dress.py` (função `siege(z, ...)`), `places.py`, `prop_kit.py`; pose de ferido deitado no kit (`rest_lying`) — fallback: sentado |
| **Dados** | `MapsCatalog.SIEGE` (trechos, pressão, falas), rotas novas em `RAIDS`, `kind: "harass"`, `MOB_PATROLS` com `horn`, `conquest_vis` novos, NPCs (curandeira, feridos, refugiados) com `if`/`unless`, 2 missões de defesa por zona, todos os números em `Balance.SIEGE_*` | `maps_catalog.gd`, `quests_catalog.gd`, `balance.gd` |
| **Código (sim)** | pressão por mapa (`SiegeSystem.pressure`), multiplicadores no `RaidSystem.start_raid`/`timer`, `kind: harass` (sem faixa/música, barragem), trompa (`horn`), calmaria, Chamas + `siege_event`, buff Colônia de Pé, `responder` no `GuardBrain`, `if` com lista `any` nos colisores de estágio (se ainda não houver), tipo `DEFEND` (se aprovado) | `core/sim/systems/siege_system.gd` (novo, estático) + ganchos pequenos em `raid_system.gd`, `monster_brain.gd`, `guard_brain.gd`, `quest_system.gd` |
| **Código (apresentação)** | fumaça/fogo por marcador (pool de partículas, `set_vis_range`), aviso curto de assédio (sem faixa), visual do buff | `game/world/`, `game/fx/`, `BuffLooks.LOOKS`, `Sfx` (trompa, incêndio) |

### 3.11 Plano por fases

**P1 — fatia jogável em Porto Esperança**
1. Arte: paliçada do porto dividida em 3 trechos (obra/pronta) + 3 colisores de estágio por trecho; 3 casas queimadas;
   refugiados no cais; enfermaria; 1 torre de vigia (trecho `n`); `FX_smoke` NE; `FX_fire` em 3 casas.
2. Dados: `SIEGE["city_port"]`, rotas `cerco_ne`/`cerco_e`/`cerco_n` (`unless` do trecho), rota `assedio` (`harass`),
   2 rondas de batedores com `horn`, 2 missões `hx_df_*`, NPCs da enfermaria/refugiados, `Balance.SIEGE_*`.
3. Código: `SiegeSystem` (pressão, calmaria, Chamas, Colônia de Pé), `harass`, trompa, `responder`.
4. Provas: checks (`_check_siege_*`), `raid_probe` no porto (repelidas ≥ 75% com 0 bots; tempo entre eventos), `sim_probe`
   com Kharzun carregado (≤ 10 ms/tick), fotos `--raid_shot` de C0 e C1 em `production/qa/evidence/siege/`.

**P2 — Estepes e Kharzun**: trechos do anel de carroças e da paliçada de Kharzun, assédio de fogo e de catapulta, batedores,
fumaça por acampamento, linhas de frente, enfermarias. Pressão `p = 1` residual nos mapas já vencidos.

**P3 — Costa, Grutas e acabamento**: batedores da Costa com trompa para o porto, tamborileiro de alarme nas Grutas, linha de
frente no minimapa (Q7), música/sons de trompa e incêndio refinados, falas de Chamas por NPC.

---

## 4. Formulas

### F1. Intervalo até o próximo evento

```
T_leva    = max(Q_min,  (E_rota × M_every[p]  + u × J_rota) × R_every^k  −  H × h)
T_assedio = max(Q_min/2, E_harass × M_harass[p] + u × J_harass)
```

| Variável | Significado | Faixa | Fonte |
|---|---|---|---|
| `E_rota` | `every` da rota (catálogo) | 150–300 s | `RAIDS` |
| `M_every[p]` | multiplicador por pressão | p3 0,8 · p2 1,0 · p1 2,0 | `SIEGE_EVERY_MULT` |
| `u` | sorteio uniforme da sim | −1..1 | `sim.rng` |
| `J_rota` | `jitter` | 20% de `E` | `RAIDS` |
| `R_every`, `k` | regra do Bastião (fortes retomados) | 0,8, 0–2 | `RAID_RECLAIM_EVERY`, `reclaimed` |
| `H` | adianto por trompa | 30 s | `SIEGE_HORN_HASTEN` |
| `h` | trompas tocadas desde a última leva | 0–`SIEGE_HORN_MAX` (2) | estado |
| `Q_min` | calmaria | 45 s | `SIEGE_QUIET_MIN` |
| `E_harass` | intervalo-base do assédio | 80 s | `SIEGE_HARASS_EVERY` |
| `M_harass[p]` | p3 0,75 · p2 1,0 · p1/p0 = sem assédio | — | `SIEGE_HARASS_MULT` |

**Exemplo** (porto, p = 2, `E` = 150, `J` = 30, u = +0,4, sem fortes, 1 trompa):
`T_leva = max(45, (150 × 1,0 + 0,4 × 30) × 1 − 30 × 1) = max(45, 132) = 132 s`.
Pior caso de pressão (p = 3, u = −1, 2 trompas): `max(45, (150×0,8 − 30) − 60) = max(45, 30) = 45 s` → a calmaria segura.

### F2. Tamanho da leva

```
N_g = max(1, round(n_g × S[p] × RECLAIM_MULT^k × fit))       fit = min(1, cap / Σ)
```
`n_g` = monstros do grupo no catálogo; `S[p]` = `SIEGE_SIZE_MULT` (p3 1,0 · p2 0,7 · p1 0,5); o resto é a regra atual
(`RAID_RECLAIM_MULT`, `RAID_WAVE_CAP`/`_LAST`). **Exemplo** (porto C0, `{wolf_rider: 3, goblin_lancer: 3}`, p = 2):
3 × 0,7 = 2,1 → 2 e 2 → **4 invasores** por leva pequena (hoje 6), leva grande toda 3ª soma `wolf_raider`.

### F3. Assédio

```
dano por círculo = SIEGE_HARASS_DMG_PCT × vida_max do alvo        (percentual: vale para 30 e para 45)
aviso            = SIEGE_HARASS_WARN s antes do impacto
```
Padrão: 3 círculos de raio 3 m, 12% da vida, aviso 1,2 s. **Exemplo**: personagem com 4.000 de vida parado num círculo
perde 480 (12%); dois círculos sobrepostos no máximo 24% — nunca mata de vida cheia (Edge Cases).

### F4. Densidade de eventos (validação do "o tempo todo")

```
λ = 1/T̄_assedio + 1/T̄_leva + λ_trompa            intervalo médio = 1/λ
```
Porto p = 2: `1/80 + 1/150 ≈ 0,0192/s` → **um evento a cada ~52 s** (alvo 45–90 s). p = 3: `1/60 + 1/120 = 0,025/s` → ~40 s.
p = 1: `1/600` (patrulha 300 s × 2,0) → ~10 min (alvo "a guerra está longe").

### F5. XP do cerco não vira fazenda

```
XP_cerco/min = Σ_leva(N_g × xp_g) / T̄_leva  +  Σ_assedio(xp_atiradores) / T̄_assedio
Restrição:  XP_cerco/min ≤ SIEGE_XP_SHARE × XP_caça/min  (caça de 4 monstros seguidos, band_probe da faixa)
```
`SIEGE_XP_SHARE` = 0,8: defender rende **um pouco menos** que caçar, porque vem com buff e sem andar. Se o probe
passar disso, o knob é `S[p]` (não o XP do monstro, que as missões e o campo dividem).
Comparação de vazão (porto, sem pressão vs p = 2): hoje 6 invasores / 240 s = 1,5/min; proposto 4 / 150 s + leva grande
≈ 1,9/min — +27% de alvos, distribuídos em 60% mais eventos.

### F6. Colônia de Pé

```
buff "colonia_de_pe": SIEGE_MORALE_TIME s; +SIEGE_MORALE_XP_PCT % de XP de abate no mesmo mapa; renova, não acumula
```
Padrão: 180 s, +10%. **Exemplo**: a leva seguinte (≥ 45 s, média 150 s) chega com o buff ainda ativo; repelir de novo
renova para 180 s — quem fica defendendo mantém o buff, quem sai para caçar o perde em 3 min.

### F7. Guarnição por trecho

```
repelidas_sem_bots ≥ SIEGE_GUARD_REPEL (0,75) com 0 bots e o jogador ausente   (raid_probe --bots=0)
```
Knob: `PORT_GUARD_POWER` (1,2) e o nº de besteiros por posto (2). Cada trecho fechado afunila e soma 2 besteiros: a taxa de
repelidas **sobe** com o progresso, e é medida em C0 (pior caso: 0 trechos, só a guarnição do portão).

---

## 5. Edge Cases

| Caso | O que acontece |
|---|---|
| Missão do trecho termina **durante** uma leva que vai para aquela brecha | a leva atual continua (regra atual: rota inativa só não solta leva nova); o colisor liga na hora; invasor que estiver **dentro** do colisor recebe `MapGeometry` empurrão para o lado aberto mais perto (mesma regra de desprender do `unstick`); a próxima leva já vai para o portão |
| Jogador **dentro** de um trecho no momento em que fecha | mesmo empurrão para fora do colisor, para o lado de dentro do povoado |
| Jogador sai do mapa no meio da leva | relógios param; a leva em curso continua no ritmo de mapa ausente (`AWAY_MAP_EVERY`); se chegar e recuar **sem** o jogador ter estado lá, **sem Chamas** (R17) |
| Jogador entra num interior / masmorra | é outro mapa: cerco pausado; nada acontece com o povoado enquanto ele compra ou faz a masmorra |
| Save/carregar | trechos, pressão e cenário vêm de `quests_completed`; relógios e Chamas **não** são salvos: ao carregar, primeiro assédio em 40 s e leva em 75 s, sem Chamas |
| Círculo de assédio em cima de NPC de serviço, cristal ou chegada | proibido: sorteio refeito fora de `SIEGE_SAFE_RADIUS`; após 8 tentativas, o círculo não nasce |
| Dois círculos sobrepostos + golpe de invasor | teto: dano de assédio por alvo por salva ≤ `2 × SIEGE_HARASS_DMG_PCT` (24%); assédio nunca mata quem estava com vida ≥ 30% antes da salva (o golpe que mataria deixa 1 de vida) |
| Trompa durante uma leva ativa | guardada (`h` conta para a próxima), teto `SIEGE_HORN_MAX` = 2 |
| Jogador deixa a trompa tocar de propósito para farmar | calmaria `Q_min` + F5 limitam a vazão; recompensa por leva é a mesma |
| Estepes com 1 acampamento restante (`RAID_LAST_FRONT_MULT` ×2 + `p = 3`) | `S[3]` = 1,0 e `M_every[3]` só encurta o intervalo; o tamanho segue a regra do Bastião atual (não se multiplica por cima). `say_last` continua pedindo grupo |
| Todos os trechos fechados e a pressão ainda alta | levas vão ao portão (rota `muralha`); assédio mira o portão |
| Jogador muito acima do nível da zona (voltou do Kharzun ao porto) | `p ≤ 1` lá (marco concluído); força segue o nível dos monstros da faixa; nada escala para ele |
| Jogador morre seguidamente na brecha | volta no cristal **dentro** da muralha; levas têm `lifetime` e recuam; o Bastião (`RAID_RALLY_*`) segue valendo; nada se perde |
| Jogador que nunca defende | guarnição repele ≥ 75% (R18); as poucas que passam só dão Chamas visuais; missões opcionais `hx_df_*` ficam por fazer, mas `hx_palisade` fecha tudo (R7) |
| Bot em grupo do jogador numa masmorra quando a trompa toca | ignora (só bots no mapa e no `RAID_DEFEND_RANGE` decidem) |
| `DEFEND` aceita sem o jogador ter lutado | só conta se o jogador esteve no raio do Bastião durante a leva (mesma área do buff) |
| Fim do Ato II (`hx_warlord`) | `p = 0` em todos os mapas; assédio, batedores e levas param; refugiados viram festa (festival existente) |

**Estratégias degeneradas** (Sirlin): (1) *ficar só no portão farmando levas* — limitado por F5 (≤ 80% da caça) e pela
calmaria; é jogo saudável se render menos que caçar. (2) *nunca fechar os trechos opcionais para ter mais brechas* — não
dá vantagem: mais brechas = levas espalhadas e menos sentinelas; e `hx_palisade` fecha tudo. (3) *puxar invasores para
dentro do povoado onde as sentinelas são fortes* — já é a defesa pretendida (Bastião).

---

## 6. Dependencies

| Sistema | Entra (este doc pede) | Sai (este doc dá) | Dono |
|---|---|---|---|
| `RaidSystem` | rotas por trecho com `unless`, `kind: harass`, multiplicadores `M_every`/`S` por pressão, calmaria, trompa | `raid_event` (e `siege_event`) | Raid — regra de marcha **sem mudança**; acréscimos pequenos |
| `WorldState` | `if`/`unless` (inclusive lista `any` para R7) | estágios, colisores de estágio | WorldState |
| `MapGeometry.sync_stage` | colisores por trecho | — | MapGeometry |
| `MobSystem.place_barrage` / `hazards` | salva do assédio | círculos avisados | Bosses/Mob |
| `MonsterBrain` | flag `horn` na ronda | `SiegeSystem.horn(...)` | Mob AI |
| `GuardBrain` | `responder` + coleira | — | Guard AI |
| `BotBrain` | trompa como início de leva (R20), fuga de círculos (já existe) | — | Bot AI |
| `QuestSystem` | tipo `DEFEND` (se aprovado) | — | Quests |
| Dress / `act2_dress` / `places.py` / `prop_kit` | lotes `tag` (trechos, casas, refugiados, frente), marcadores `FX_*` | `data/zones/<zona>.json` | Zonas (world-builder / blender-modeler) |
| `conquest_vis` / `MapBuilder.apply_conquest` | tags novas | — | Apresentação |
| FX / Som / Música | fumaça, fogo, trompa, incêndio; **não** tocar "investida" no assédio | — | Áudio/FX |
| HUD | faixa de investida só para levas; aviso curto para assédio | — | UI |
| [`ato2-horda.md`](ato2-horda.md) | este doc **substitui** a linha C0/C1 do porto (paliçada binária → trechos) e acrescenta pressão às tabelas K0–K2 e E0–E5 | — | **ato2-horda.md precisa ganhar um link para cá** (States and Transitions / R4) |
| `kharzun-fase3-plan.md` | trechos da paliçada K0–K2 e catapulta da Horda | — | idem: link de volta |

---

## 7. Tuning Knobs

Todos em `data/balance.gd` (prefixo `SIEGE_`), exceto o que é conteúdo (rotas, falas, trechos) no `maps_catalog.gd`.

| Knob | Padrão | Faixa segura | Tipo | Afeta | Por que o padrão |
|---|---|---|---|---|---|
| `SIEGE_EVERY_MULT` | {3: 0.8, 2: 1.0, 1: 2.0} | 0,6–2,5 | gate | frequência das levas por pressão | F4: 1 evento a cada ~40–55 s em p2/p3 |
| `SIEGE_SIZE_MULT` | {3: 1.0, 2: 0.7, 1: 0.5} | 0,4–1,2 | curve | invasores por leva | "menores e mais frequentes"; vazão +27% (F5) |
| `SIEGE_QUIET_MIN` | 45 s | 30–90 | gate | respiro depois de repelir | tempo de entregar missão/comprar poção |
| `SIEGE_HARASS_EVERY` | 80 s | 50–150 | gate | ritmo do assédio | F4 |
| `SIEGE_HARASS_MULT` | {3: 0.75, 2: 1.0} | 0,5–1,5 | gate | assédio por pressão | — |
| `SIEGE_HARASS_SHOOTERS` | 2 | 1–4 | feel | atiradores por salva | matar antes da salva tem de ser possível sozinho |
| `SIEGE_HARASS_CIRCLES` | 3 | 2–6 | feel | círculos por salva | leitura clara, pouco custo de hazards |
| `SIEGE_HARASS_DMG_PCT` | 12% | 6–20 | feel | dano do círculo | ameaça sem matar (Edge Cases) |
| `SIEGE_HARASS_WARN` | 1,2 s | 0,8–2,0 | feel | aviso | igual à gramática dos avisos de chefe menores |
| `SIEGE_HARASS_SPREAD` | 10 m | 6–16 | feel | espalhamento | — |
| `SIEGE_HARASS_LIFE` | 25 s | 15–40 | gate | quanto o atirador fica | janela para caçá-los |
| `SIEGE_SAFE_RADIUS` | 8 m | 6–12 | feel | zona sem círculos (cristal, chegada, serviços) | — |
| `SIEGE_HORN_DELAY` | 6 s | 3–10 | feel | tempo para o batedor tocar | 2 batedores lv 30 morrem em ~4–6 s de uma build média (confirmar no `band_probe`) |
| `SIEGE_HORN_HASTEN` | 30 s | 10–60 | gate | adianto por trompa | perceptível, sem atropelar a calmaria |
| `SIEGE_HORN_MAX` | 2 | 1–3 | gate | teto de trompas acumuladas | — |
| `SIEGE_MORALE_TIME` | 180 s | 90–300 | gate | duração da Colônia de Pé | cobre a leva seguinte média |
| `SIEGE_MORALE_XP_PCT` | 10 | 5–15 | curve | XP de abate no mapa | recompensa sem virar fazenda (F5) |
| `SIEGE_FIRE_SPOTS` | 3 | 2–4 | feel | focos de Chamas | orçamento de FX |
| `SIEGE_GUARD_LEASH` | 18 m | 10–25 | feel | quanto o posto `responder` desce | portão nunca vazio |
| `SIEGE_GUARD_REPEL` | 0,75 | 0,6–0,9 | gate (meta do probe) | defesa sem jogador | padrão do Kharzun |
| `SIEGE_XP_SHARE` | 0,8 | 0,6–1,0 | curve (meta do probe) | teto de XP do cerco vs caça | F5 |
| `SIEGE_FIRST_HARASS` / `SIEGE_FIRST_WAVE` | 40 / 75 s | 30–90 | gate | primeiro evento ao entrar | "algo em < 1 min" sem atropelar a chegada |

---

## 8. Acceptance Criteria

### Funcionais (checks em `tools/tests/run_tests.gd`, `--only=siege`)
- **AC-1** Todo trecho de `SIEGE[<mapa>]["segments"]` tem: quest existente, tags `pal_<id>_obra`/`_pronta` em `conquest_vis`
  com `unless`/`if` coerentes, ≥ 1 colisor de estágio com o `if` do trecho e uma rota em `RAIDS` com `unless` igual.
- **AC-2** Com a quest do trecho concluída, a rota dele não solta leva em 600 s simulados e a leva daquele lado vai para o
  portão; sem a quest, a brecha é andável (`MapGeometry`) e com ela não é.
- **AC-3** `hx_palisade` fecha todos os trechos do porto (R7), com ou sem as missões opcionais.
- **AC-4** Pressão: para cada mapa, a tabela de quests → `p` bate com 3.8 (teste por conjunto de `quests_completed`).
- **AC-5** Intervalos: em 30 min simulados com o jogador no porto em `p = 2`, o intervalo médio entre eventos (assédio +
  leva) fica em 45–90 s; nenhum intervalo entre leva repelida e a próxima < `SIEGE_QUIET_MIN`; nenhum assédio durante leva.
- **AC-6** Relógios param com o jogador fora do mapa ou num interior (0 eventos em 600 s).
- **AC-7** Nenhum círculo de assédio nasce a < `SIEGE_SAFE_RADIUS` de cristal, chegada de portal ou NPC de serviço
  (10.000 sorteios); dano do assédio por salva ≤ 24% da vida máxima.
- **AC-8** Trompa: batedor vivo em luta há `SIEGE_HORN_DELAY` s reduz o `timer` em `SIEGE_HORN_HASTEN`, uma vez por vida.
- **AC-9** Chamas só com `arrived` e não repelida; apagam na próxima repelida; nenhuma missão, item ou trecho muda.
- **AC-10** Colônia de Pé: aplicada a quem estava no raio do Bastião, renova sem acumular, tem visual em `BuffLooks.LOOKS`.
- **AC-11** Save: carregar um save com qualquer conjunto de missões reproduz trechos, cenário e pressão sem campo novo.

### Sondas
- **AC-12** `raid_probe --bots=0` no porto C0 e no Kharzun K0: repelidas ≥ 75%, `presos` = 0.
- **AC-13** F5: XP/min do cerco ≤ 0,8 × XP/min da caça da faixa (`band_probe`), no porto em `p = 2` e `p = 3`.
- **AC-14** `sim_probe` com Kharzun carregado: ≤ 10 ms/tick (GDD `ato2-horda` AC-36), e o acréscimo do cerco ≤ 0,5 ms/tick
  médio no porto em `p = 3` comparado com o cerco desligado; invasores + atiradores + batedores vivos por mapa ≤
  `RAID_WAVE_CAP`; `hazards` simultâneos ≤ 8 por mapa.
- **AC-15** `--perf` no porto durante leva + Chamas: draw calls ≤ +20 sobre a linha de base; FX de fumaça/fogo ≤ 6 emissores
  por mapa, com distância de desenho.
- **AC-16** Smoke `--autostart` sem `SCRIPT ERROR`; testes 0 failed.

### Experienciais (playtest — `production/qa/` checklist)
- **AC-17** Em 10 min no porto recém-chegado, o testador relata ≥ 3 vezes "estou sendo atacado" sem ter procurado combate,
  e **nenhuma** morte por assédio com vida cheia.
- **AC-18** Ao fechar um trecho, o testador percebe (sem ser avisado) que a leva seguinte entrou por outro lugar.
- **AC-19** Depois de `hx_riders_camp`, o testador nota a calmaria **e** a fumaça nova na direção das Estepes ("a guerra foi
  para lá").
- **AC-20** Fotos retidas em `production/qa/evidence/siege/`: porto C0 (vãos, queimadas, refugiados, enfermaria), C1 (trechos
  fechados, torre), assédio no meio da salva, Chamas, e a linha de frente em dois estágios.

---

## 9. Decisões para o usuário

> Respondidas em 2026-11-17: 1 (b), 2 (a), 3 (a), 4 (a), 5 (a), 6 (c, "Intenso"), 7 (a).

1. **Como os trechos fecham?** — (a) só missões da linha principal; (b) **híbrido: o vão crítico (NE) pela principal
   `hx_stakes`, os outros 2 por uma mini-cadeia opcional de defesa, e `hx_palisade` fecha o que faltar** *(recomendado:
   autonomia sem bloqueio)*; (c) todos por missões opcionais.
2. **Barricada pode ser destruída?** — (a) **não: trecho fechado nunca reabre; falha é só visual (Chamas)** *(recomendado)*;
   (b) trecho tem vida e a leva o quebra até a próxima missão/reparo (mais tensão, mais código, risco de frustração).
3. **Consequência de falhar uma leva** — (a) **Chamas visuais + sem Colônia de Pé, nada perdido** *(recomendado)*;
   (b) também fecha uma loja até a próxima repelida; (c) nada.
4. **Recompensa de repelir** — (a) **buff Colônia de Pé (+10% XP de abate no mapa, 180 s)** *(recomendado)*; (b) bolsa de
   moedas por leva; (c) só o XP dos invasores, como hoje.
5. **Tipo de missão `DEFEND` (conta levas repelidas)?** — (a) **sim, tipo novo pequeno, 1–2 missões por zona**
   *(recomendado)*; (b) não, usar KILL do monstro da leva.
6. **Cadência** — (a) **p2: leva 150 s / assédio 80 s; p3: 120 s / 60 s** *(recomendado; ~1 evento por minuto)*;
   (b) mais calmo (manter 240 s, só somar assédio a 120 s); (c) mais intenso (leva 90 s).
7. **Mapas já vencidos** — (a) **pressão residual `p = 1` (patrulha rara + fumaça distante) até o fim do Ato** *(recomendado)*;
   (b) silêncio total depois do marco da zona.

---

## Implementação P1 (2026-11-17) — o que ficou diferente do texto acima

- **Cadência Intenso**: `every` das rotas do porto = 90 s ±20% (não 150); `SIEGE_HARASS_EVERY` 48 s; `SIEGE_QUIET_MIN` 30 s;
  `SIEGE_FIRST_HARASS`/`SIEGE_FIRST_WAVE` 25/45 s; `SIEGE_HORN_HASTEN` 20 s. O intervalo é de **início a início** e a leva seguinte espera a
  atual acabar: medido, uma leva a cada ~100 s e um evento (leva ou assédio) a cada ~50 s em p = 2 e ~46 s em p = 3.
- **Trechos do porto**: `ne` Vão da Garganta (297–315°, `hx_stakes`), `e` Trecho do Farolete (27–45°, `hx_df_logs`: 6 Toras de Estaca do
  estaleiro; o porto não tem mangue), `n` Vão do Portão Norte (247–259°, `hx_df_tower`: `DEFEND` 2 levas, torre de vigia). As duas opcionais
  são do Carpinteiro Bruno, em cadeia depois de `hx_first_wave`. Cada brecha é um corredor entre duas casas do anel.
- **Um relógio por mapa** (`SiegeSystem`), não um por rota: uma leva por vez, revezando os três lados; lado fechado = rota `muralha`
  (até `hx_riders_camp`), depois só `patrulha` (300 s × 2,0). Trecho fechado não conta como "fortaleza retomada" (sem fúria no porto).
- **Reserva em vez de coleira (R21)**: 3 sentinelas `responder` na praça (`port_r_*`) correm para o alvo da leva atacada, em qualquer brecha
  (a coleira de 18 m não alcançava as brechas a partir do portão); `SIEGE_GUARD_LEASH` não existe. A guarnição do portão continua fixa.
  `PORT_GUARD_POWER` 1,2 → 1,4.
- **Retune do playtest (2026-11-17, "os invasores são fracos, a guarda limpa fácil")**: leva = 3 Ginetes, 2 Lanceiros, 1 Arqueiro Orc e 1
  Saqueador de líder (+2 Empaladores na leva grande); `SIEGE_SIZE_MULT` {3: 1,2 · 2: 1,0 · 1: 0,6} (não 1,0/0,7/0,5); invasores do porto × 1,2
  (`RAID_MAP_POWER["city_port"]`); guarnição com vida × 1,8 a mais (`PORT_GUARD_HP`, novo: a guarda aguenta sem matar depressa); os lanceiros e o
  cavaleiro do portão também acodem a brecha (6 `responder`; os 2 besteiros ficam); `lifetime` das levas 200 s.
- **Assédio**: atiradores = `orc_archer` (2) na crista nordeste; a salva sai `SIEGE_HARASS_WINDUP` (8 s) depois de aparecerem; o círculo
  fere **só jogador e bots** (a guarnição não, para a taxa de repelidas não depender do sorteio dos círculos); "NPC de serviço" = ferreiro,
  alquimista, mercador, depósito, cristal e quadro (os mestres de ascensão não entram).
- **Ajuste final** (bots do porto matavam a leva antes de ela chegar): `RAID_MAP_HP["city_port"]` 1,4 (vida a mais só dos invasores) e
  `SIEGE_BOT_DEFENDERS` 1 (bots avulsos que acodem cada leva; o grupo do jogador vai sempre). Medido, 12 levas por rota, só a guarnição:
  12/12, luta mediana 59–80 s, 2,3–3,9 sentinelas mortas, 2,4–5,7 invasores dentro do alvo; 1 bot: leva inteira 40–47 s (contra 100–124 s);
  relógio de 30 min 11/11 (0 bots) e 14/14 (6 bots na praça). Os números de "Medido depois do retune" abaixo são de antes deste ajuste.
- **R20** (trompa como início de leva para o bot do grupo) e a **linha de frente** não entraram no P1. Feridos ficam de pé ao lado dos
  catres (sem pose deitada). Sons reusados (`war_drum`, `wolf_howl`, `fire`); trompa e incêndio próprios ficam para o P3.
- **Medido depois do retune** (`raid_probe --side=<lado> --bots=0,1,3 --trials=20 --level=32 --raid_level=32`): só a guarnição 19/20, 19/20,
  20/20 (brechas) e 20/20 (portão), luta mediana 34–55 s (leva inteira 77–101 s), 1,1–2,8 sentinelas mortas por leva, 1,5–5,7 invasores dentro
  do alvo; com 1 bot a leva inteira cai para 38–42 s, com 3 para 30 s. Relógio de verdade (`--siege_run=1800 --bots=0`, 3 sementes): C0 92%, 92%,
  83% repelidas, ~1 Chamas por meia hora, leva a cada ~135 s (a guarnição sozinha não fecha a leva em 90 s), evento a cada ~70 s; `presos` 0; no
  máximo 14 invasores (p = 3) e 3 círculos vivos. AC-13 (XP do cerco × caça) e AC-15 (`--perf`) e os
  experienciais AC-17 a AC-19 **não foram medidos**.
