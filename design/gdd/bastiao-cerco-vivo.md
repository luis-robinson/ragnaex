# Cerco Vivo do Bastião da Aurora (`field_ruins`, faixa 20-30)
> **DECISÕES DO USUÁRIO (2026-11-25):** S1 + S2 APROVADAS (tabela de pressão por mapa em `SIEGE_MAP`; trecho fechado sai do revezamento;
> opt-in, Porto e Posto iguais). Buff de moral: **um por lugar** (mesmo efeito, nome/ícone/visual próprios; Bastião "Muralha de Pé",
> Posto "Posto de Pé" = provisórios, writer confere). Fim do cerco no 3º forte (D5).
> Medido (2026-11-25): norte só com a guarnição 1/20 = **aceito** pelo usuário (o front pede jogador/bots); aglomeração 20-35 em 6 m = **aceita** (AC-7 relaxado; era 78).


> Status: **PRONTO PARA IMPLEMENTAR** (game-designer, 2026-11-25). WP2 + WP3 de `design/gdd/dawn-band-refactor-proposal.md`.
> Decisões do usuário (2026-11-25): **D3 = B** (`SiegeSystem`, os 3 fronts como trechos, uma leva por vez); **D4** = forte caído sobe a
> **pressão** (frequência), não o tamanho; batedores com trompa, assédio de arqueiros de osso e surtida da catedral ficam;
> **D5 = B** (conquista por forte + Restos da Noite, já em `CATALOG_SPAWNERS`, + eco dos chefes).
> Modelos: `design/gdd/act2-siege-life.md` (Porto Esperança), `design/gdd/elf-siege-posto.md` (Posto dos Caçadores).
> Substitui: `MapsCatalog.RAIDS["field_ruins"]` em modo `RAID_SYNC_MAPS` (3 levas juntas, fúria ×1,5/×2 + líder).
> Linha de base WP1 (`production/session-state/agent-dawn-wp1.md`): 3 fronts juntos = **154 invasores**, **4/10 repelidos** com a guarnição
> sozinha, tick **32,9 ms** no pior caso; FPS **20,9 com 85 invasores** (26,8 com 38); uma rota só (76) = 20/20 repelida, aglomerado máx. 78.
> Canon: Established ("cada fortaleza retomada limpa aquele lado e cala a investida dele", `docs/roteiro_20_30`; Lyria "é assim que a noite
> encolhe"). Novo: o assédio dos arqueiros de osso, os batedores e a "noite se desespera" como cadência. Falas abaixo são esboço de tom (writer).

## 1. Overview

O Bastião deixa de ser atacado pelos três lados **ao mesmo tempo** e passa a viver um **cerco** no motor que o Porto e o Posto já usam
(`SiegeSystem`): cada front (pântano a oeste, ossos ao norte, gelo ao sul) é um **trecho** do cerco, aberto enquanto a fortaleza daquele
lado está nas mãos da noite. **Uma leva por vez**, revezando os fronts abertos, de tamanho médio (33-47), nascendo em **escalões** num
arco longe das chegadas de portal e marchando até o **portão** daquele lado (não mais até a praça). Retomar um forte **fecha o trecho**: o
lado dele cala para sempre (canon) e a pressão **sobe** — os fronts que sobram atacam **mais vezes**, nunca com levas maiores. Caindo a
terceira fortaleza (Torre de Gelo), o cerco acaba: pressão 0, só Restos da Noite e ecos. Enquanto a Fortaleza dos Ossos resiste, arqueiros de
osso num outeiro a nordeste do portão norte soltam salvas avisadas; batedores com trompa nas estradas dos fronts adiantam a próxima leva;
a surtida da catedral continua sendo a resposta grande do Bastião.

## 2. Player Fantasy

"Eu seguro o último muro da Aurora, e cada fortaleza que eu derrubo arranca um braço da noite — e o que sobra dela bate mais vezes,
desesperado." O jogador de nível 20-24 ouve a trompa, lê no chat **qual portão**, corre para lá e vê a leva chegar em ondas (larvas e lobos
primeiro, a linha de zumbis/esqueletos, os carniçais e arqueiros atrás). Ele **escolhe** entre defender (XP do cerco, Bastião de pé) e sair
para a fortaleza (fechar um lado de vez). Quando o último front está aberto, o Bastião vive sob pressão contínua: a vitória fica perto e
barulhenta, nunca um bolo de 80 corpos no portão.

- **Pilares**: mundo vivo que responde às suas quests (cada forte muda o cerco e o mapa); grupo com bots (a defesa pesa, a guarnição segura).
- **MDA**: Estética de Desafio + Narrativa (a noite encolhe e se desespera); Dinâmicas "ouvir → ler o portão → posicionar", "caçar o batedor
  antes da trompa", "derrubar o arqueiro no outeiro antes da salva".
- **SDT**: competência (escalões e círculos legíveis, leva de tamanho previsível), autonomia (defender ou ir ao forte; caçar batedores).
- **Fluxo**: dente de serra — pressão 2 → 3 → 4 sobe a frequência e fecha um lado a cada passo; o pico de tensão (p4, último front) vem
  logo antes do alívio total (Torre caída = paz).

## 3. Detailed Design

### 3.1 Trechos (os 3 fronts)

R1. `MapsCatalog.SIEGE["field_ruins"]` liga o `SiegeSystem` no Bastião. Com ele, `RaidSystem.update_raids` deixa de usar o relógio único
    (`sync = not siege and ...`): `Balance.RAID_SYNC_MAPS["field_ruins"]` fica morto e **sai** (limpeza de dado).
R2. **Trechos** (`segments`), um por front; o trecho fecha com a quest do chefe do forte (a mesma que hoje cala a rota):

| id | label (HUD/chat) | fecha com | rota (`side` no JSON) | portão |
|---|---|---|---|---|
| `ghoul` | "Portão do Pântano" | `dw_ghoul_boss` | `cerco_ghoul` | oeste (-56, 0) |
| `bones` | "Portão dos Ossos" | `dw_bones_boss` | `cerco_bones` | norte (0, -56) |
| `frost` | "Portão do Gelo" | `dw_frost_boss` | `cerco_frost` | sul (0, 56) |

    Sem `close_all` (não há quest que feche tudo de uma vez; a paz vem da pressão, R5). Sem `gate_route`: no Bastião **trecho fechado =
    lado calado** (canon), não "a leva vai ao portão". Sem `pal_<id>_obra/pronta` (muralha de pedra; `siege_conquest_vis` não é chamado
    para este mapa — a troca de cenário continua em `DAWN_CONQUEST_VIS`).
R3. **O que retomar cada forte faz** (tudo pela quest do chefe, lida de `player.quests_completed`, §3.9):

| Forte retomado | Trecho | Pressão | Assédio | Batedores | Também (já existe) |
|---|---|---|---|---|---|
| Covil do Carniçal (`dw_ghoul_boss`) | `ghoul` fecha; oeste calado | 2 → **3** | continua | lobos do oeste somem | Restos do oeste (`CATALOG_SPAWNERS`), reforço `reforco_ghoul`, `limpo_ghoul` |
| Fortaleza dos Ossos (`dw_bones_boss`) | `bones` fecha; norte calado | 3 → **4** | **acaba** (arqueiros eram da legião de Vorhag) | tamboreiros somem | Restos do norte, `reforco_bones`, assalto da Aurora na Torre |
| Torre de Gelo (`dw_frost_boss`) | `frost` fecha; sul calado | → **0 (paz)** | — | morcegos somem | Restos do sul, `reforco_frost`; o Lich segue como raide, sem levas |

    Ordem real da linha principal: Covil → Ossos → Torre (`quests_catalog` dw_*). A tabela vale em qualquer ordem (pressão conta fortes, §3.2).

### 3.2 Pressão

R4. `pressure` (1ª linha que vale; vai da mais específica à geral):

| p | Condição | Significa | Rotas que valem |
|---|---|---|---|
| 0 | `if: [dw_ghoul_boss, dw_bones_boss, dw_frost_boss]` (todas) | paz: nada nasce | nenhuma |
| 4 | `if: dw_bones_boss` **ou** 2 fortes quaisquer (ver nota) | "a noite se desespera": último front | o trecho aberto que sobra |
| 3 | `if: dw_ghoul_boss` (1 forte) | fúria | 2 trechos |
| 2 | `if: dw_gates` | cerco | 3 trechos + assédio |
| 1 | (nenhuma) | patrulha rara antes de `dw_gates` | `patrulha_oeste` |

    Nota: como `pressure` só testa "todas as quests da linha", as linhas de 2 fortes são três (`[ghoul, bones]`, `[ghoul, frost]`,
    `[bones, frost]` → 4) e as de 1 forte três (`ghoul` / `bones` / `frost` → 3), em ordem depois da linha p0. A linha principal só passa por
    `ghoul` → `ghoul+bones`, mas o dado cobre qualquer ordem (QA, `--quests=` das sondas).
R5. **O Lich não faz parte do cerco**: a terceira fortaleza encerra as levas (canon: cada forte cala o seu lado; não sobra lado). Depois
    disso o Bastião é só Restos, ecos e (WP5) reconstrução. Leva viva no instante da 3ª retomada termina normalmente (R14).
R6. **D4 cumprido por número**: em toda pressão o **tamanho é ×1,0** (o Bastião não usa `SIEGE_SIZE_MULT[3]` = 1,2 do Porto/Posto) e a
    frequência sobe. `RaidSystem.reclaimed` já devolve 0 em mapa com cerco: `RAID_RECLAIM_MULT`, `RAID_LAST_FRONT_MULT`, `reclaim_extra`,
    `leader`, `say_reclaim` e `say_sync` param de valer aqui sem código (os campos saem do `RAIDS` novo).

### 3.3 Revezamento e cadência

R7. Uma leva viva por vez no mapa; revezamento **oeste → norte → sul** entre os trechos **abertos** (trecho fechado é pulado sem custo, ver
    SIM CHANGES S2). Intervalo início-a-início pela F1; depois de repelida, calmaria `SIEGE_QUIET_MIN` (30 s).
R8. Escalões (`Balance.SIEGE_STAGGER["field_ruins"]`, mesmo motor do Posto, só dado): ordem por papel —
    0 = rápidos (`larva`, `rot_wolf`, `tower_bat`), 1 = linha (`rot_zombie`, `skeleton`, `cultist`), 2 = pesados (`rot_ghoul`, `skel_guard`, `ghost`),
    3 = atrás/elite (`skel_archer`, `citadel_adept`, `rot_bear`, `citadel_knight`, `citadel_horror`). `gap` 5 s, `arc` 14 m, `lane` 3 m, `muster` 4 s.

### 3.4 Levas (novas entradas de `RAIDS["field_ruins"]`, por `side`)

| Rota | `every` / `jitter` / `lifetime` | Leva normal | Leva grande (`every_nth` → `SIEGE_BIG_NTH[p]`) |
|---|---|---|---|
| `cerco_ghoul` | 150 / 20 / 180 s | larva 20, rot_zombie 10, rot_ghoul 7, rot_wolf 4 = **41** | + rot_bear 3, citadel_horror 1 = **45** |
| `cerco_bones` | 150 / 20 / 180 s | skeleton 16, skel_archer 10, skel_guard 7 = **33** | + skel_guard 3, citadel_knight 1 = **37** |
| `cerco_frost` | 150 / 20 / 180 s | cultist 9, tower_bat 10, ghost 8, citadel_adept 5 = **32** | + citadel_knight 3 = **35** |
| `patrulha_oeste` (p1) | 150 / 20 / 150 s | larva 6, rot_zombie 2 (×0,6 = 4 + 1) | — |
| `assedio_norte` (`kind: harass`) | — | 3 × `skel_archer` (`harass_mob`) | — |

    Larvas continuam nas levas do oeste e no front (dw_gates = 30 larvas não fica mais lento: p1 já traz larvas a cada ~5 min, e o front
    tem o spawner de larvas). `scale_extra` / `RAID_SCALE_TO_MAP` 30 continuam (a leva acompanha o nível do jogador até o 30).
    O "líder" do último front some como regra e volta como **membro da leva grande** (`citadel_horror` / `citadel_knight` 1): sem elite.
    Todas as rotas de cerco com o `unless` do chefe delas; `patrulha_oeste` com `unless: dw_gates` (assim ela nunca vira fallback em p ≥ 2:
    `next_route` cai no `low_route` se ele valer).

### 3.5 Assédio — arqueiros de osso (aprovação do game-designer)

**Aprovado, com três mudanças em relação ao rascunho da proposta:**
1. **Só enquanto a Fortaleza dos Ossos resiste** (`assedio_norte` com `unless: dw_bones_boss`). Motivo: `harass_aim` mira a brecha aberta mais
   perto do ponto de tiro; com o norte fechado a salva cruzaria o Bastião inteiro até o portão sul (ilegível, e sem sentido de lore: os arqueiros
   são da legião de Vorhag). Assim o assédio existe em p2-p3 e some em p4, onde a frequência já é o castigo.
2. **Mira no portão, nunca na praça**: as rotas `cerco_*` passam a ter `target` no pátio de dentro do portão (12 m para dentro), raio 20
   (hoje é a praça (0,0) com raio 50, e a salva cairia sobre a catedral e os serviços). `SIEGE_SAFE_RADIUS` continua protegendo portais,
   chegadas, cristal e serviço.
3. **Números entre o Posto e o Porto**: 3 atiradores (nível 24, 360 de vida, mortais para o nível 20-24 em ~6-8 s de um personagem),
   **10%** da vida por círculo (Porto 12, Posto 8), teto de 2 círculos por salva, não mata quem tinha ≥ 30% (regra existente), preparo 8 s,
   a cada 55 s em p2 (×0,75 em p3 ≈ 41 s). Dano não esquivável (decisão 2026-11-13: zona avisada no chão só se evita saindo dela).

Por que aprovar: é a única pressão do cerco que pede **posição** e não DPS (Sirlin: contra-jogo claro — sair do círculo ou matar o atirador
dentro da janela de 8 s), e o outeiro a ~36 m do portão norte fica a ~7 s de corrida (5,5 m/s), então a janela é real. Regras de legibilidade:
aviso na gramática de perigo (`FxManager.DANGER*`, vermelho-laranja), tema `blood` (golpe físico de monstro), som de flecha. `volley_skill` =
a skill de flecha do `skel_archer` (**a confirmar** o id no `skills_catalog`; sem ela, `mob_fire_arrows` não serve de tema — pedir ao
class-designer uma `mob_bone_arrow` só de tema/som).

### 3.6 Batedores com trompa

R9. `MOB_PATROLS["field_ruins"]` (rondas com `{"horn": true}`; somem pelo `unless` quando o forte cai):

| Par | Monstro | Rota [[x, z]...] | respawn | unless |
|---|---|---|---|---|
| Lobos do pântano | `rot_wolf` ×2 | [-74,-20] → [-66,-8] → [-74,14] → [-66,-8] | 60 s | `dw_ghoul_boss` |
| Tamboreiros de osso | `skeleton` ×2 (nome "Tamboreiro de Ossos" **a confirmar**: hoje é o esqueleto comum) | [-14,-74] → [-6,-66] → [2,-74] → [-6,-66] | 60 s | `dw_bones_boss` |
| Morcegos da Torre | `tower_bat` ×2 | [14,74] → [4,66] → [-14,76] → [4,66] | 60 s | `dw_frost_boss` |

    Todas as rondas ≥ 15 m de chegada de portal (fort_ghoul (-96,0), fort_bones (0,-88), cripta (20,-81,5), fort_frost (0,100), campo
    (44,8,100,7)). Em luta há `SIEGE_HORN_DELAY` (6 s) tocam: −20 s na próxima leva, no máx. 2 por leva. Caçar o par antes de 6 s = nenhuma trompa.
    Não contam como caça do mapa (`MapDef.has_hunting`, regra existente).

### 3.7 Surtida da catedral e reserva

R10. A surtida continua igual (`SORTIES["field_ruins"]`, 20 soldados, sai quando a leva **chega** ao raio do alvo, vai ao portão atacado por
     `RaidSystem.gate_point`). Muda só a recarga: `cooldown` 180 → **270 s**, para sair mais ou menos a cada 2ª leva em p3/p4 (com levas a
     cada 90-115 s, 180 s soltaria 20 soldados quase sempre e somaria ~20 corpos ao pico; ver F3).
R11. **Reserva**: 3 sentinelas da guarnição do **portão leste** (o lado sem front) ganham `responder` e correm para o portão atacado
     (`SiegeSystem._responders`). Ids **a confirmar** em `dawn_garrison` (`dawn_g_*` perto de (56, 0)). Elas voltam ao posto quando a leva acaba.

### 3.8 Alarme, Chamas e prêmio

R12. **Alarme** (WP5, já implementado): `NpcSystem.alarm_on` = `RoadEventSystem.raid_on`, que olha os `ids` de **toda rota** do mapa; a leva do
     cerco é uma rota, então civis com `alarm` correm para a catedral durante qualquer leva viva, sem código. O assédio **não** dispara alarme
     (atiradores não são ids de rota) — de propósito: são 25 s, e esvaziar a praça a cada salva cansaria. Vigia com `alarm_cry` grita quando a leva começa.
R13. **Repelida** (`SiegeSystem.on_wave_end`): buff de moral em quem esteve no raio do alvo (+10% XP de abate no mapa por 180 s), conta quest
     `DEFEND` com `target_id: "field_ruins"`, apaga as Chamas. Pedido de conteúdo (writer/world-builder, `quests_catalog`): uma repetível de
     quadro na Capela dos Pedidos, "Muralhas da Aurora" (DEFEND ×3, nível 21, `repeatable`, XP pela `scale_xp`, prêmio consumível) — `unless`
     do último forte não é preciso (sem leva, ela só não progride; o quadro a esconde com `unless: dw_frost_boss`).
     Nome do buff: hoje "Colônia de Pé" (do Porto) — mesma decisão aberta do Posto (§ Decisões).
R14. **Chamas** (leva chegou e recuou sem ser repelida): só `say_scorch` até o Blender pôr marcadores `fire` no `fx` do JSON (BLENDER REQUEST);
     depois, `siege_fx.gd` acende os focos sozinho.

### 3.9 Pergunta técnica da proposta §8: trecho fechado por quest de OUTRO mapa

**Resposta: funciona hoje, sem mudança na sim.** `SiegeSystem.segment_closed` → `WorldState.active(sim, {"if": quest})` → `WorldState.done(sim)` =
`sim.player.quests_completed`, que é **do personagem**, não do mapa. A quest `dw_ghoul_boss` concluída em qualquer lugar fecha o trecho `ghoul`
no próximo `next_route`/`status` do Bastião — o mesmo mecanismo que já cala as rotas atuais pelo `unless` e que o Porto usa (`Q_DF_TOWER` etc.).
Ressalvas (não exigem código):
- Fecha na **conclusão** da quest (se `dw_ghoul_boss` se entrega ao NPC, fecha na entrega, como hoje).
- Sem jogador (testes/servidor) nenhuma quest conta: sondas e checks passam `--quests=` (já suportado por `raid_probe`).
- O relógio do Bastião só anda com o jogador **no** Bastião: enquanto ele luta no forte, nada se acumula lá.
O que **precisa** de mudança é outra coisa (SIM CHANGES S1/S2): tamanho ×1,0 com p até 4, e pular trecho fechado sem calmaria.

## 4. Formulas

**F1 — intervalo da leva (início a início)**: `T = max(SIEGE_QUIET_MIN, every × EVERY_MULT[p] + u × jitter)`, `u` ∈ [-1, 1] (rng da sim).
Bastião (`every` 150, `jitter` 20, tabela por mapa, S1):

| p | `EVERY_MULT` | T (s) | Trechos abertos | Cada portão é atacado a cada |
|---|---|---|---|---|
| 1 | 2,0 | 280-320 (patrulha) | 0 | — |
| 2 | 1,0 | 130-170 | 3 | ~7,5 min |
| 3 | 0,77 | 96-136 (média 115) | 2 | ~3,8 min |
| 4 | 0,6 | 70-110 (média 90) | 1 | ~1,5 min |

Exemplo (p4): u = 0,5 → T = 150 × 0,6 + 10 = 100 s. A leva dura ~55-75 s (WP1: 74 s com 76 invasores, 0 bots); com calmaria de 30 s depois
de repelida, o próximo começa em max(100, 75 + 30) = 105 s → em p4 o portão sul tem ~30 s de respiro entre levas. Isso é o "desespero": contínuo, nunca empilhado.

**F2 — tamanho**: `n_mob = round(base × SIZE_MULT[p] × fit)`, `SIZE_MULT` = 1,0 em p2/p3/p4 e 0,6 em p1 (S1); `fit = min(1, RAID_WAVE_CAP_MAP 80 / total)` (nunca aciona).
Leva grande a cada `BIG_NTH[p]` levas do mapa: p2 = 3, p3 = 3, p4 = 2.

**F3 — pico de corpos hostis + aliados móveis no Bastião** (orçamento do brief ≤ ~76):
`pico = maior leva (45) + atiradores (3, só p2-p3 e só se a leva começou durante a salva) + batedores (≤ 6) + surtida (20, no máx. 1 por 270 s) ≈ 74`.
Invasores (hostis de leva + assédio) ≤ **48**; antes: 154 (sync) e 75-85 no último front. Escalões de 5 s fazem o número **vivo ao mesmo tempo**
ficar abaixo do total (meta: ≤ 40 vivos com a guarnição matando os primeiros escalões).

**F4 — volume por hora (mesmo total de antes, outra forma)**: antes, p2 ≈ 154 a cada ~240 s + luta ≈ **1.900 invasores/h** em 3 surtos.
Agora p2 = 3 levas de ~37 a cada 450 s ≈ **890/h**; p3 = 2 de ~41 a cada 230 s ≈ 1.280/h; p4 = 1 de ~35 a cada 90-105 s ≈ 1.300/h.
Menos corpos totais em p2 (o jogador de nível 20-21 está saindo para o Covil), mais pressão sentida em p3/p4, sempre um portão por vez.
Meta de XP do cerco: XP/min defendendo ≤ `SIEGE_XP_SHARE` (0,8) × XP/min caçando na faixa (o buff +10% conta).

**F5 — assédio**: a cada `55 × HARASS_MULT[p] ± 10` s (p2 45-65, p3 31-51), só sem leva viva; dano por círculo = `max_hp × 10%`, no máx. 2 círculos por alvo por salva (20%);
quem tinha ≥ 30% não morre. Janela de cancelamento = 8 s de preparo; distância do outeiro ao portão norte ≈ 36 m ≈ 6,6 s de corrida.

**F6 — escalões**: invasor do escalão k nasce em `t = k × 5 s`; 4 escalões → a leva toda está em campo aos 15 s; posição = `from + perp × (s − 0,5) × 14 m + jitter`
(motor do Posto, `elf-siege-posto` F6).

## 5. Edge Cases

- **Jogador fora do Bastião** (no forte, na cripta, no campo): relógio do cerco parado; leva viva termina pelo `lifetime` (180 s) e recua.
- **Forte retomado com leva viva daquele lado**: a leva termina normalmente (`_update_wave` roda para toda rota com `ids`, valha ou não); nenhuma nova
  nasce lá. Se ela não for repelida, acende Chamas — a próxima leva repelida (de outro lado) apaga.
- **3ª retomada com leva viva**: idem; p0 a partir dali, nem leva nem assédio. Chamas acesas apagam no fim? Não: `on_wave_end` só apaga em repelida.
  Regra: com p0, o `SiegeFx` não mostra Chamas (`unless` do último forte nos marcadores `fire`), para o Bastião não ficar queimando para sempre.
- **Turno de trecho fechado** (S2): pula para o próximo aberto no mesmo instante; nunca gasta calmaria. Todos fechados = p0, nada a escolher.
- **Assédio com o norte fechado**: rota `assedio_norte` não vale (`unless dw_bones_boss`) → nenhum atirador. Atirador vivo no instante da retomada:
  termina a salva e some no `SIEGE_HARASS_LIFE`.
- **Círculo sem ponto válido** (portão perto de cristal/serviço): `volley_spot` tenta 8 vezes e desiste daquele círculo (regra existente).
- **Retorno do forte no meio da leva**: os `from` novos ficam ≥ 25 m das chegadas (hoje o `from` do oeste é **exatamente** a chegada de `fort_ghoul`, (-96,1, 0):
  o jogador voltando do forte cairia no meio do 1º escalão). Requisito do BLENDER REQUEST.
- **Antes do Blender** (só dado): os trechos podem apontar para as rotas atuais `ghoul`/`bones`/`frost` (o cerco funciona), mas com `from` na chegada e
  alvo na praça. Nesse modo provisório o **assédio fica desligado** (sem `harass_route`), senão as salvas cairiam na praça.
- **dw_gates** (30 larvas): p1 traz 4 larvas a cada ~5 min + spawner do front; sem regressão no tempo da quest (AC-9).
- **Sem jogador** (sim headless, servidor): nenhuma quest → p1 eterno (patrulha). Sondas usam `--quests`.
- **Bots**: `BotBrain._defend` usa o portão da rota (`raid_status.gate`), serve aos três; `SIEGE_BOT_DEFENDERS` = 1 avulso por leva; grupo do jogador sempre.
- **Surtida em recarga**: a leva chega e a surtida não sai; a reserva (R11) e a guarnição seguram (AC-4 é medido assim, com a surtida em recarga em metade das levas).
- **Save**: nada novo (pressão e trechos saem das quests; relógios em `m["siege"]`, fora do save). Carregar no meio = `first_wave` (60 s).
- **Festa/Lich**: `FESTIVAL` (`if dw_lich`) não conflita: em p0 não há leva.

## 6. Dependencies

| Sistema | Direção | Contrato |
|---|---|---|
| `SiegeSystem` (`core/sim/systems/siege_system.gd`) | este GDD → sim | consome `MapDef.siege`; S1/S2 abaixo |
| `RaidSystem` | sim | escalões (`SIEGE_STAGGER`), `start_raid`, `gate_point`, surtida; `reclaimed` = 0 sob cerco (fúria desligada) |
| `WorldState` | sim | `if`/`unless` das rotas/rondas; fechamento por quest de outro mapa (§3.9) |
| `MapsCatalog` | dados | `SIEGE["field_ruins"]`, `RAIDS["field_ruins"]` (novas chaves), `MOB_PATROLS["field_ruins"]`, `SORTIES` (cooldown), responders |
| `Balance` | dados | `SIEGE_MAP["field_ruins"]` (+ tabelas por mapa), `SIEGE_STAGGER["field_ruins"]`, remover `RAID_SYNC_MAPS["field_ruins"]` |
| `QuestsCatalog` | dados | dw_gates, dw_ghoul_boss, dw_bones_boss, dw_frost_boss (existentes); repetível DEFEND nova (R13) |
| `build_field_ruins.py` + `field_ruins.json` | Blender → dados | rotas `cerco_*`, `patrulha_oeste`, `assedio_norte`, `fx` (BLENDER REQUEST) |
| Bastião vivo (WP5, `LIVING_NPCS` `alarm`) | lê | `RoadEventSystem.raid_on` (sem mudança) |
| Conquista (WP4, `CATALOG_SPAWNERS` Restos/eco) | paralelo | mesma quest fecha o trecho e liga os Restos; sem conflito de posição (Restos a ~88 m, rotas de cerco passam por ali: Restos não têm `aggro` de leva, ok) |
| HUD (`RaidSystem.status`, faixa do cerco), `siege_fx.gd`, `Music` "investida" | apresentação | sem mudança; label do trecho no chat |
| `act2-siege-life.md`, `elf-siege-posto.md` | irmãos | S1/S2 não mudam Porto nem Posto (sem as chaves novas = comportamento atual) — estes GDDs devem citar este |

## 7. Tuning Knobs

| Knob | Onde | Valor | Faixa segura | Categoria / afeta |
|---|---|---|---|---|
| `every` / `jitter` das rotas de cerco | `RAIDS.field_ruins.cerco_*` | 150 / 20 s | 120-200 / 10-30 | gate: ritmo base (p2) |
| `every_mult` por p | `SIEGE_MAP.field_ruins.every_mult` | {1: 2,0, 2: 1,0, 3: 0,77, 4: 0,6} | p4 0,5-0,75 | gate: "desespero" |
| `size_mult` por p | `SIEGE_MAP.field_ruins.size_mult` | {1: 0,6, 2-4: 1,0} | 0,9-1,1 (D4: não subir) | curve: tamanho |
| `big_nth` por p | `SIEGE_MAP.field_ruins.big_nth` | {2: 3, 3: 3, 4: 2} | 2-4 | curve: elites |
| tamanho das levas | `RAIDS` waves | 41 / 33 / 32 (+4/+4/+3) | 28-48 (pico F3 ≤ 76) | curve + perf |
| `lifetime` | `RAIDS` | 180 s | 150-210 | gate: Chamas |
| `first_wave` | `SIEGE_MAP` | 60 s | 45-90 | gate: entrada no mapa |
| assédio `harass_every` / `harass_dmg_pct` / `harass_shooters` / `harass_mult` | `SIEGE_MAP` | 55 s / 10% / 3 / {3: 0,75} | 45-75 / 8-12 / 2-3 | feel: ameaça posicional |
| escalões `gap` / `arc` / `lane` / `muster` | `SIEGE_STAGGER.field_ruins` | 5 s / 14 m / 3 m / 4 s | 4-8 / 10-18 / 0-5 / 0-8 | feel: leitura da leva, perf |
| batedores | `MOB_PATROLS` | 3 pares, respawn 60 s | 2-3 pares, 45-90 s | gate: trompas |
| surtida `cooldown` | `SORTIES.field_ruins` | 270 s | 180-360 | perf + alívio |
| reserva | responders | 3 | 0-4 | curve: repelidas sem jogador |
| `RAID_MAP_POWER.field_ruins` | `Balance` | (ausente = 1,0) | 0,9-1,2 | curve: ajuste se AC-4 falhar (tamanho primeiro, memória "raids must be a threat") |

## 8. Acceptance Criteria

Funcionais (checks em `run_tests.gd`, `--only=siege`):
- **AC-1** `SIEGE["field_ruins"]` existe; 3 trechos com quests que existem; `low_route`/`harass_route` apontam para rotas do mapa; toda rota de cerco tem o
  `unless` do chefe dela; `patrulha_oeste` tem `unless: dw_gates`; sem `gate_route`; `RAID_SYNC_MAPS` sem `field_ruins`.
- **AC-2** Pressão: `[]` = 1; `dw_gates` = 2; `+dw_ghoul_boss` = 3; `+dw_bones_boss` = 4; os três chefes = 0 (e qualquer par = 4, qualquer um = 3).
  Com p0 uma sim de 600 s solta 0 levas e 0 assédios.
- **AC-3** Trecho fechado por quest concluída **fora** do Bastião (o jogador em `fort_ghoul` conclui `dw_ghoul_boss`, volta): `status.segments.ghoul` = true
  e 10 `next_route` seguidos nunca devolvem `cerco_ghoul` e nunca devolvem -1 com outro trecho aberto (S2: sem calmaria perdida).
- **AC-4** Tamanho por p: a mesma rota em p2, p3 e p4 nasce com o mesmo número (± leva grande) — D4.
- **AC-5** Nenhum `from` de rota de cerco/assédio/patrulha a menos de 25 m de chegada de portal ou `spawn_point`; nenhum círculo de salva a menos de
  `SIEGE_SAFE_RADIUS + SIEGE_HARASS_RADIUS` de ponto seguro; alvo de toda rota de cerco a ≤ 20 m de um `town_gate`.
- **AC-6** Porto e Posto sem mudança: `sim_probe --map=city_port` e `--map=field_forest` com a mesma soma de conferência antes/depois de S1/S2.

Medidos (sondas; comparar com WP1, `production/qa/evidence/dawn-wp1/`):
- **AC-7** `raid_probe --map=field_ruins --side=cerco_<lado> --level=22 --quests=dw_gates --bots=0,1,3 --trials=20`: guarnição sozinha repele ≥ 75% em cada
  lado (`SIEGE_GUARD_REPEL`; WP1 sync = 40%), 3 bots ≥ 95%, presos 0, aglomerado máx. (círculo 6 m) ≤ 12 (WP1: 78), desvio dos tempos de chegada ≥ 8 s.
- **AC-8** `raid_probe --map=field_ruins --siege_run=1800 --bots=0 --level=22|23|24` com `--quests` de p2, p3 e p4: repelidas ≥ 70%; intervalo médio entre levas
  dentro de ±15% de 150 / 115 / 90 s; `invasores_max` ≤ 48 (WP1: 154); tick da sim médio ≤ 6 ms e máx. ≤ 20 ms (WP1: 5,87 / 32,9).
- **AC-9** `--perf --perf_at=0,0` com a maior leva viva + surtida: FPS ≥ 25 (WP1: 20,9 com 85), `physics_max1s_ms` ≤ 30 (WP1: 37).
  `--soak=300 --soak_map=field_ruins` sem trecho < 20 FPS.
- **AC-10** `band_probe --from=20 --to=30`: tempo até `dw_gates` sem piora > 10%; XP/min do cerco ≤ 0,8 × caça da faixa.

Experienciais (playtest, nível 21-24, um teste por pressão):
- **AC-11** Sem olhar o mapa, o jogador diz por qual portão vem a leva só pelo chat e pela trompa em ≥ 4 de 5 levas.
- **AC-12** Em p2 o jogador consegue derrubar ao menos 1 dos 3 arqueiros antes da salva em ≥ 1 de cada 2 assédios em que tenta; nenhuma morte "sem saber por quê".
- **AC-13** Em p4 o testador descreve o Bastião como "sob pressão constante" e **não** como "um bolo no portão"; quer ir à Torre para acabar com isso.

---

## SIM CHANGES (mínimas; gameplay-programmer)

- **S0 — fechamento por quest de outro mapa**: **nenhuma** (§3.9).
- **S1 — tabelas de pressão por mapa** (`SiegeSystem`): `size_mult`, `big_nth`, `wave_interval` e `harass_interval` leem primeiro
  `Balance.SIEGE_MAP[<mapa>]["size_mult" | "every_mult" | "big_nth" | "harass_mult"][p]` e só depois as tabelas gerais. `wave_interval(r, p, u)` passa a
  receber o `def` (ou o mapa) como `harass_interval` já recebe. Necessário para D4 (×1,0 em p3, onde a tabela geral dá 1,2) e para **p = 4**
  (as comparações `p >= 2` / `p < 2` já servem; nada mais muda). Porto/Posto sem as chaves = idênticos (AC-6).
  Alternativa sem código (pior): chaves `4` nas tabelas gerais e aceitar 1,2 em p3 — contraria D4.
- **S2 — pular trecho fechado** (`SiegeSystem.next_route`, ramo sem `rotation`, mapa sem `gate_route`): a partir de `side`, procurar o próximo trecho cuja
  rota vale (até `segments.size()` tentativas) e avançar `st["side"]` até ele. Hoje um trecho fechado sem portão cai no `low_route`/-1 e
  `_start_wave` gasta `SIEGE_QUIET_MIN` (30 s) por turno pulado, o que comeria o ganho de frequência de p3/p4 (p4 cairia de 90 para ~150 s
  efetivos). Ligar só com `def.siege.get("skip_closed", false)` para não mexer em Porto/Posto.
- **Sem código**: `RaidSystem.reclaimed` já é 0 sob cerco (fúria/líder/`say_reclaim` desligados); `RAID_SYNC_MAPS` deixa de valer sozinho; escalões
  vêm de `SIEGE_STAGGER`; alarme via `raid_on`; Chamas via `siege_fx`. Check novo: `_check_bastion_siege` (AC-1..AC-6).

## BLENDER REQUEST (`tools/blender/zones/build_field_ruins.py` → `data/zones/field_ruins.json`; Fable)

Trocar a lista `raids` (hoje `ghoul`/`bones`/`frost` com `from` = chegada dos fortes e alvo na praça, raio 50) por estas, no formato do
`build_field_forest.RAIDS` (com `side`). O resto do JSON (spawners, obstáculos, NPCs, assaults) sai **byte a byte igual**. Coordenadas sugeridas
(x, z), conferir andável e trocar se cair em obstáculo, respeitando as restrições:

| side | from | route | target | radius | if/unless | Restrições |
|---|---|---|---|---|---|---|
| `cerco_ghoul` | (-91,3, -29,7) | (-84,9, -13,5) → (-62,0, 0,0) | (-44,0, 0,0) | 20 | unless `dw_ghoul_boss` | `from` ≥ 25 m de (-96,1, 0) (chegada do Covil) |
| `cerco_bones` | (-27,2, -83,7) | (-14,0, -72,0) → (0,0, -62,0) | (0,0, -44,0) | 20 | unless `dw_bones_boss` | ≥ 25 m de (0, -88,2) e (20, -81,5) (Cripta) |
| `cerco_frost` | (24,0, 80,0) | (14,0, 72,0) → (0,0, 62,0) | (0,0, 44,0) | 20 | unless `dw_frost_boss` | ≥ 25 m de (0, 99,8) e (44,8, 100,7) (Campo dos Juramentos) |
| `patrulha_oeste` | (-91,3, -29,7) | (-84,9, -13,5) → (-62,0, 0,0) | (-44,0, 0,0) | 20 | unless `dw_gates` | igual à do oeste |
| `assedio_norte` (`kind: "harass"`) | (36,0, -62,0) | — | (0,0, -44,0) | — | unless `dw_bones_boss` | andável; ≥ 25 m de (20, -81,5) e (66,3, -73,7); ≤ 40 m de caminho a pé do portão norte; fora da rota `cerco_bones` |

- **Outeiro de ossos** no ponto do assédio: monte baixo de ossos e estacas (< 2 m, visual, sem colisor no topo onde os atiradores ficam), ler de cima a 52°.
- **Chamas** (`fx`, `kind: "fire"`, `unless: ["dw_ghoul_boss","dw_bones_boss","dw_frost_boss"]`): 1 foco no pátio de dentro de cada portão de front, a ≥ 8 m de NPC de serviço —
  sugestões (-40, 6), (6, -40), (-6, 40); fumaça `smoke_low` opcional nos mesmos pontos.
- `first`/`every`/levas **não** vão no JSON (ficam em `RAIDS`). Depois do build: `--only=siege`, `_check_places`, travessia, `raid_probe` (AC-7).

## Decisões abertas (do usuário)

1. **Nome do buff de moral** no Bastião ("Colônia de Pé" é do Porto): buff próprio "Muralha de Pé"/"Bênção da Muralha" (HUD + `BuffLooks`) ou manter — mesma pergunta do Posto; decidir as duas juntas.
2. **S1/S2 na sim** (pequenas, opt-in por mapa): aprovar, ou aceitar a alternativa sem código (p3 com leva ×1,2 e p4 perdendo ~40% da frequência).
