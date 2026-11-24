# Faixa élfica viva (10-20): Cidade Élfica, fortes, acampamentos e Posto dos Caçadores

> Status: **EM IMPLEMENTAÇÃO** (world-builder, 2026-11-24). Pacote LIVING do refactor élfico
> (`design/gdd/elf-band-refactor-proposal.md` §4, decisões D3 "só o Rei" e D7 "B").
> Base: `design/gdd/living-towns.md` (rotinas, eventos de estrada, orçamento). Notas do agente:
> `production/session-state/agent-elf-living.md`. A investida/cerco do Posto é de outro pacote (SIEGE): aqui só o alarme reage a ela.

| Canon | Visível ao jogador | Fonte |
|---|---|---|
| Provisional (nomes e falas novas; o resto já é canon da faixa) | Sim (rotinas, eventos), Descobrível (falas da seiva) | este doc + proposta §4 |

**Cross-references**: `MapsCatalog.ELF_CITIZENS`, `POST_VILLAGERS`, `FOREST_NPCS`, `PLACE_NPCS["elf_city"]`, quests `el1..el6`,
`elf_fort_*`, `GDD living-towns` §3.4-3.9.
**Contradições conferidas**: Aryn já era "recados para os fortes, todo dia, ida e volta" (a rota agora cumpre a fala);
Thalindra "tudo vai para o quartel" (o aprendiz leva); Dalva "meu marido ficou para soltar as cabras" (ele aparece no
Posto só depois do Rei); Caelir "corte a raiz e eles dormem" (depois do Rei a seiva "dorme"). Nenhum forte muda o mundo
sozinho (D3): toda troca de estado lê só `el6_king`.

---

## 1. Overview

A Cidade Élfica (`elf_city`), os três fortes dos capitães (Matilha, Ninho, Seiva — lugares dentro do mesmo mapa), os
acampamentos humanos do cerco (cabana da Batedora Yara, acampamento da patrulha) e o Posto dos Caçadores (`field_forest`)
ganham **gente que trabalha** (rotas com carga e paradas, `MapsCatalog.LIVING_NPCS`), **bichos de ambiente**
(`AMBIENT_LIFE`), **eventos de estrada** (`RoadEventSystem`) e um **antes/depois** visível que só a queda do Rei Aelthar
(`el6_king`) dispara: a cidade entra em luto e trégua, os fortes desarmam, os acampamentos relaxam e o Posto vê os
refugiados voltando. O Posto ganha também **alarme**: quando uma leva da investida/cerco está viva no mapa, a trompa toca e
os refugiados correm para a Fogueira Comunal. Tudo usa sistemas que já existem; o código novo é pequeno (alarme no
`NpcSystem`, condição `if`/`unless` por tipo de evento, grito/som do alarme e sinos de luto na apresentação).

## 2. Player Fantasy

"Eu estou dentro da casa do inimigo, e ela é uma casa." Antes do Rei, a cidade trabalha para a guerra: lanças saem da forja
para o quartel, baldes de seiva saem da Árvore-Mãe para os fortes, a mensageira corre entre eles, recrutas tremem no pátio,
e há humanos presos nos fortes. O jogador lê a guerra no chão, não num texto. Depois do Rei, a mesma cidade fica quieta:
a seiva volta para a árvore, a forja passa a fazer enxadas, um emissário humano espera na praça, os presos somem dos fortes e
aparecem no Posto, e a Dalva reencontra o marido. No Posto, a trompa e a correria dos refugiados dizem "estamos sob ataque"
antes de qualquer aviso. (SDT: competência e impacto — o mundo responde à vitória; MDA: estética de narrativa ambiental.)

## 3. Detailed Rules

### 3.1 Quem vive onde (estado "guerra" = `unless: el6_king`, "trégua" = `if: el6_king`)

**Cidade Élfica (dentro do anel, r = 66 m)**

| Id | Quem | Estado | Rotina | Carga | Falas (tema) |
|---|---|---|---|---|---|
| `elf_courier` (já existe) | Mensageira Aryn | guerra | rota de verdade aos 3 fortes, parada em cada um (era um anel na cidade) | — | pressa, recados |
| `elf_courier_peace` | Mensageira Aryn | trégua | portão do lado da Floresta → acampamento do cerco → volta | — | "levo a resposta da trégua" |
| `elf_l_apprentice` | Aprendiz Fendrel | guerra | forja da Thalindra → pátio do Quartel (parada) → portão leste | `carry_crate` | "tudo vai para o quartel" |
| `elf_l_apprentice_peace` | Aprendiz Fendrel | trégua | Quartel → forja (lanças voltam para virar enxada) | `carry_crate` | "lança vira enxada" |
| `elf_l_sap_a` | Coletor Ithil | guerra | cocho FORA do portão leste (71,1; -0,5) → Forte da Seiva (decisão 2026-11-24: fora da praça) | `carry_sack` | seiva inquieta (pista) |
| `elf_l_sap_b` | Coletora Merien | guerra | cocho FORA do portão noroeste (-37,8; -63,0) → Forte do Ninho (decisão 2026-11-24) | `carry_sack` | "a árvore geme quando tiramos" |
| `elf_l_sap_peace` | Coletora Merien | trégua | praça → jardim da Saelis (devolve a seiva à terra) | `carry_sack` | "a seiva dorme" |
| `elf_l_recruit` | Recruta Nerys | guerra | parada no pátio do Quartel, de frente para o Caelan (treino) | — | contagem de tiro |
| `elf_l_mourner` | Viúva Elandra | trégua | vigília parada a sudeste da Árvore-Mãe, (9,4; 16,3), lado que a câmera vê | — | luto pelo rei |
| `elf_l_envoy` | Emissário Bento Sá (humano) | trégua | parado na praça, (-7,5; 19,0), ao lado da barraca, fora das raízes | — | trégua da Comandante Hela |

**Fortes (lugares do mapa)** — um NPC parado por forte, neutro:

| Forte | Guerra (`unless`) | Trégua (`if`) |
|---|---|---|
| Matilha (14, -90) | Cativo Abel (humano preso, "me tirem daqui") | Guarda Desarmado Faelan ("o forte é só madeira agora") |
| Ninho (-48, -82) | Cativa Rosa (humana presa, alimenta grifos à força) | Tratadora Lysa (solta os grifos) |
| Seiva (90, 16) | Cativo Nestor (carrega baldes de seiva) | Sentinela Desarmada Ilyra |

**Acampamentos humanos (sul do anel, lado da Floresta)**

| Id | Quem | Estado | Rotina |
|---|---|---|---|
| `elf_l_camp_runner` | Batedor Quim | guerra | cabana da Yara ↔ acampamento da patrulha, com `carry_sack` (flechas) |
| `elf_l_camp_cook` | Cozinheira Nena | trégua | parada na fogueira do acampamento da patrulha |

**Posto dos Caçadores (`field_forest`)** — soma aos 3 de hoje (lenhadores, caçador):

| Id | Quem | Estado | Rotina |
|---|---|---|---|
| `post_l_horn` | Vigia Lauro | sempre | parado na Trompa do Cerco (centerpiece `horn`); no alarme grita e a trompa toca |
| `post_l_cart` | Carroceira Joana + mula (`cart_draft`) | guerra | estrada de Aldara (oeste) → portão oeste → fogueira (parada) → volta |
| `post_l_refugee_a` | Refugiado Simão | guerra | anda entre as carroças; **alarme**: corre para a fogueira |
| `post_l_refugee_b` | Refugiada Cida + trouxa (`carry_sack`) | guerra | varal de peles → fogueira; **alarme**: fogueira |
| `post_l_return` | Família voltando (Simão) | trégua | portão norte → estrada da garganta → volta (os refugiados voltam para casa) |
| `post_l_husband` | Seu Bento, marido da Dalva | trégua **E** carta entregue (`if: ["el6_king", "m9_letter"]`, `MapsCatalog.BENTO_HOME`; decisão 2026-11-24) | parado ao lado da Dalva; até lá mora no Brejo (`marsh_bento`) |
| Dalva e Tito (`POST_VILLAGERS`, já existem) | — | sempre | ganham **alarme** (fogueira) por `VILLAGER_EXTRAS` |

### 3.2 Alarme do Posto (P1)

- Regra na sim (`NpcSystem`): NPC com `alarm = [x, z]` troca o destino para esse ponto enquanto `RoadEventSystem.raid_on(m)`
  (alguma leva de investida ou do Cerco viva no mapa) e fica lá parado; quando a leva acaba, volta à rotina no próximo
  ponto. Não depende de qual sistema mandou a leva (RaidSystem hoje, SiegeSystem depois do pacote SIEGE).
- Apresentação (`AmbientLife`): em `Events.raid_event("start")` e `Events.siege_event("horn"|"harass")` do mapa atual,
  NPCs com `alarm_cry` gritam uma vez e toca o som de trompa (`ALARM_SOUND`).
- Depois do Rei não há investida no Posto (pacote SIEGE, `unless: el6_king`), então o alarme simplesmente não dispara.

### 3.3 Eventos de estrada

| Mapa | Tipo | Nome | Monstros | Vítima | Condição | Prêmio |
|---|---|---|---|---|---|---|
| `field_forest` | `ambush` | Emboscada na Trilha (P3) | 2-3 `bandit` "Salteador da Trilha" | Carroceiro Tião | sempre | `potion_hp_m` × 2 |
| `elf_city` | `prisoner` | Patrulha com Prisioneiro (P4) | 2-3 `elf_warrior` "Escolta Élfica" | Refugiado Amarrado | `unless: el6_king` (regra nova: `if`/`unless` por tipo) | `potion_mp_m` × 2 |

Pontos: marcadores `SPAWN_event_<tipo>_NN` no build da zona (BLENDER REQUEST). Até o Blender gravar, o catálogo dá os
pontos (`MapsCatalog.CATALOG_EVENT_POINTS`, usados só se o JSON não tiver `events`). Mesmas regras do GDD living-towns 3.5
(35-70 m do jogador, fora do hub, ≥ 25 m de portal/chegada/NPC parado/chefe, ≥ 30 m entre pontos).

### 3.4 O que muda depois do Rei (só `el6_king`)

| Lugar | Guerra | Trégua |
|---|---|---|
| Cidade | aprendiz → quartel, coletores → fortes, mensageira → fortes, recruta no pátio | luto na praça, emissário humano, seiva devolvida, lanças voltando à forja, sinos de luto (`Sfx.PLACE_BELLS`, `since`) |
| Fortes | humanos presos | elfos desarmados; presos somem |
| Acampamentos humanos | batedor correndo flechas | cozinheira na fogueira |
| Posto | carroça de refugiados chegando, alarme | família voltando pela estrada da garganta, Seu Bento com a Dalva (só se a carta do Brejo, `m9_letter`, já foi entregue) |
| Cenário (`MapDef.conquest_vis`, lotes do `build_elf_city.py`) | `elfa_guerra_det`: estandartes verde-prata nos 6 portões e nos 3 fortes, cavaletes de lanças no Quartel, cochos de seiva fora dos portões leste e noroeste e um na Árvore-Mãe (sudeste), jaulas fechadas nos fortes | `elfa_tregua_det`: mastros com fita de luto e o pano dobrado ao pé, vigília de flores e lanternas na praça, caixotes de arcos entregues, jaulas abertas, barraca do emissário; bonecos de treino do pátio ficam nos dois estados (lote neutro) |

Spawners de monstros **não mudam** (decisão em aberto, §10 do relatório): a caçada 17-21 continua igual.

### 3.5 Som e música

- Forja élfica: `elf_smith` entra em `Sfx.HAMMER_NPCS` (martelo perto da Thalindra).
- Luto: `Sfx.PLACE_BELLS["elf_city"]` com `since: el6_king` (sino lento a cada 14 s, perto da Árvore-Mãe).
- Alarme do Posto: `AmbientLife.ALARM_SOUND` (hoje `cortege_horn`; pedido ao sound-designer: `alarm_horn` próprio, grave e curto).
- Música por estado (cidade em luto) fica para o pacote C (fora do escopo).

## 4. Formulas

- Alarme: `alarm_on(m) = RoadEventSystem.raid_on(m)` (avaliado uma vez por tick por mapa, cache `m["alarm_at"]`).
  Destino no alarme = `alarm` ± 0 (sem sorteio, sem `sim.rng`: a soma de conferência das sondas não muda).
- Orçamento de NPCs vivos por estado: `N_vivo(estado) = |{n ∈ LIVING_NPCS[mapa] : WorldState.active(n)}|`;
  `N_vivo ≤ ELF_LIVING_MAX` (10) na cidade e `≤ 10` a mais na Floresta (`LIVING_NPCS["field_forest"].size() ≤ 10`, check já existe).
- Evento: os números são os de `Balance.EVENT_*` (inalterados); nível do monstro = spawner comum mais perto (`point_level`).

## 5. Edge Cases

- **Alarme no meio do caminho**: troca o destino na hora; a carga continua visível (correr com a trouxa é a imagem certa).
- **Alarme acaba com o NPC na fogueira**: volta à rota pelo próximo ponto (`npc_leg` não reinicia).
- **Conversa durante o alarme**: `npc_hold` vence (o jogador segura o NPC), como hoje.
- **Jogador mata o Rei com a cidade carregada**: `WorldState.sync_npcs` (1 s) troca os conjuntos; os adereços trocam pelo
  `conquest` da apresentação.
- **Bots**: não completam quest para o mundo (lê só o jogador), então em teste/servidor sem jogador fica "guerra".
- **Evento `prisoner` ativo e o jogador mata o Rei**: o evento ativo termina normal; só novos pontos deixam de valer.
- **Ponto de evento dentro do raio de uma investida**: `raid_on` já impede.
- **Carroça na estrada de Aldara cruzando a emboscada**: a vítima do evento é outro NPC; a carroça só passa.
- **Prisioneiro no forte com o capitão vivo**: NPC neutro, nem alvo nem atacante; fica fora do raio do spawner (≥ 6 m).

## 6. Dependencies

- `NpcSystem` (rotas, `flow`, paradas, `alarm` novo), `WorldState` (`if`/`unless`), `RoadEventSystem` (regra `if`/`unless` nova),
  `RaidSystem`/`SiegeSystem` (só leitura via `raid_on`), `AmbientLife` (bichos, barks, grito de alarme), `Sfx`
  (`HAMMER_NPCS`, `PLACE_BELLS`), `MapBuilder` (adereços condicionais), `CarryPose` (`carry_crate`, `carry_sack`, `cart_draft`).
- Pacote SIEGE (Posto no `SiegeSystem`): o alarme reage às levas dele; o pacote BREJO: pontos de evento longe do portal sul.
- Blender (Fable): pontos de evento no JSON, `conquest_vis` da cidade, bonecos de treino no pátio, barraca do emissário.

## 7. Tuning Knobs

| Knob | Onde | Valor | Faixa segura |
|---|---|---|---|
| `ELF_LIVING_MAX` | `MapsCatalog` | 10 NPCs vivos por estado | 6-12 (FPS da cidade 44-61) |
| paradas `[x, z, s]` | rotas | 6-12 s | 4-20 s |
| `PLACE_BELLS["elf_city"].every` | `Sfx` | 14 s | 8-30 s |
| prêmio dos eventos | `ROAD_EVENTS` | 2 poções M | consumível, nunca equipamento |
| bichos `elf_city` | `AMBIENT_LIFE` | 4 grupos | ≤ 1 draw por tipo |

## 8. Acceptance Criteria

1. `_check_living_routes`: `elf_city` em `TOWN_LIVING`; toda rota da cidade e da Floresta em chão livre, água só na ponte; 6+ bichos.
2. `_check_elf_living` (novo): os ids do §3.1 existem no `MapDef`; sem `el6_king` vale o conjunto "guerra" e com `el6_king` o
   "trégua" (`WorldState.sync_npcs` troca de verdade numa sim); cada estado ≤ `ELF_LIVING_MAX`; Aryn passa a ≤ 10 m de cada
   forte; presos parados a ≥ 6 m do capitão e em chão livre; adereços condicionais não são sólidos.
3. Alarme: com uma leva viva no Posto, os NPCs com `alarm` chegam à fogueira em ≤ 20 s; sem leva voltam à rota.
4. `_check_road_events` (estendido): pontos de `field_forest` e `elf_city` válidos pelas mesmas regras de Aldara; prêmio
   consumível; `prisoner` não vale depois de `el6_king`.
5. `_check_town_identity` (estendido): Cidade Élfica com a Árvore-Mãe no centro (colisor r ≥ 8), feira (6+ bancas) e pátio do
   Quartel com a Ferreira por perto; nenhum NPC vivo nasce em colisor.
6. Smoke sem `SCRIPT ERROR`; `--perf` na praça élfica: FPS e draws antes/depois registrados (alvo: queda ≤ 3 FPS, draws ≤ +40).
