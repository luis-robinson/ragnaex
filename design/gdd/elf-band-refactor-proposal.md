# Proposta: refatorar a faixa élfica 10-20 (zonas opcionais, cidade viva, investida)

> **DECISÕES DO USUÁRIO (2026-11-24):**
> - D1/D2 zonas opcionais: **1 campo + 1 mini-masmorra** — Brejo das Teias (12-16, sul do Posto) + Viveiro de Seiva.
> - D4/D5 invasão: **SiegeSystem completo** (migrar o Posto para o modelo do Ato II: pressão, trechos, assédio, batedores com
>   corneta); tamanho/escalonamento sai do desenho do cerco.
> - D3/D6 conquista: **só o Rei** — depois do Rei Élfico as investidas param e o Posto fica em paz; os fortes não mudam o mundo.
> - D7 vida: **rotinas + mudanças de conquista** (cidade e acampamentos com rotina/trabalho/vida ambiente/eventos de estrada,
>   Posto vivo com alarme/refugiados/carroça; a mudança de conquista vem da queda do Rei, coerente com D3).
> - Ordem: depois do polimento (sementes dos testes + spawners de Kharzun).


> Status: **PROPOSTA** (world-builder, 2026-11-24). Nada foi alterado em `data/`, `core/`, `game/`, `tools/`.
> Pedido do usuário: "some refactor on the elven part 10 - 20, with more optional zones, and the elf city and camps being
> more alive, and the invasion as well, the enemies come too stacked".
> Pontos marcados **(a confirmar)** não foram verificados no código nesta passada.

---

## 1. Estado atual (resumo com referências)

| Peça | Hoje | Onde |
|---|---|---|
| Hub | Posto dos Caçadores (vila murada r 24 m, 4 portões, Fogueira Comunal com Trompa do Cerco) | `data/zones/field_forest.json` `town`, `tools/blender/zones/town_dress.py` `posto()` |
| Campo principal | Floresta Sombria 10-20: aranhas, bandidos (linha de fora-da-lei), ents/trents | `field_forest.json` (21 spawners) |
| Lugares da Floresta | herborista, cacador (cabanas), emboscada (camp), circulo (santuário), ninho, pedreira (dungeons) | `field_forest.json` `places` |
| Lateral existente | Bosque dos Xamãs 14-18 (`field_grove`), Pedreira dos Golens 11-15 (`dg_pedreira` + `dg_pedreira_coracao`) | `maps_catalog.gd` `_grove`, `DUNGEON_DEFS` |
| Linha principal | el1 → el2 (24 batedores) → el3 (portão nível 16) → el4 → el5 → el6 Rei (exige também `q10b_nest`, logo o Ninho é obrigatório) | `quests_catalog.gd` 489-520 |
| Cidade Élfica 17-21 | anel r 66 m, 6 portões, 6 grupos fixos (`ELF_CITY_GROUPS`), 5 sargentos em ronda, 3 fortes de capitão (places `fort`), 16 cidadãos (`ELF_CITIZENS`, wander ou anel) | `maps_catalog.gd` 754, 2026-2050; `elf_city.json` |
| Vida no Posto | 6 refugiados (`POST_VILLAGERS`), 3 rotinas (`LIVING_NPCS["field_forest"]`: 2 lenhadores com tora, caçador com saco), corvos e mariposas (`AMBIENT_LIFE`), 22 sentinelas (`FOREST_NPCS`, `GuardBrain`) | `maps_catalog.gd` 773-812, 1118, 546 |
| Vida na Cidade Élfica | **sem** `LIVING_NPCS`, **sem** `AMBIENT_LIFE`, **sem** `ROAD_EVENTS`, **sem** `conquest_vis`; só cidadãos com wander/anel | idem |
| Investida | 1 rota (`field_forest.json` `raid`), leva base 21 (+6 a cada 2ª, +3 grifos a cada 3ª, +3/+3 por força), até ~36; a cada 240 ± 45 s; dura 210 s | `MapsCatalog.RAIDS["field_forest"]`, `RaidSystem`, `MonsterBrain._march` |
| Modelo novo (Ato II) | `SiegeSystem`: pressão 0-3 pela história, uma leva por vez revezando lados, assédio com círculos avisados, batedores com trompa, calmaria, Chamas | `core/sim/systems/siege_system.gd`, `design/gdd/act2-siege-life.md` |

## 2. Problemas encontrados

1. **Leva empilhada** (causa raiz na §5.1): nasce toda no mesmo ponto, no mesmo tick, espera 12 s parada e segue os mesmos waypoints.
2. **O ponto de nascimento da leva é a chegada do portal da Cidade Élfica** (`raid.from` = [-5,3, -101] = `target_pos` do portal `to_forest` da `elf_city`). Quem volta da cidade pode cair dentro da leva reunida.
3. **A investida não tem `if`/`unless`**: continua igual depois do Rei Aelthar cair (a confirmar se é intencional). Os fortes de capitão também não mudam nada fora deles.
4. **Cidade Élfica estática**: o único movimento é o anel de passeio dos cidadãos e os sargentos. Matar capitão/rei não muda o cenário. Não há som/bicho de ambiente.
5. **R7 do GDD living-towns ("Posto em alarme": refugiados correm para a fogueira quando a trompa toca) e R3 (troca da guarda) não foram feitos** (a confirmar: não há condição de investida no `WorldState`).
6. **Pouco opcional na faixa**: o Ninho é obrigatório (`prereq_all` do el6), a Pedreira é a única masmorra lateral, o Bosque dos Xamãs é o único campo lateral. Os lugares (cabanas, camp, santuário) dão quests mas não têm cara de "zona" própria. Na faixa 1-10 há dois campos opcionais (Mata dos Zumbidos, Praia dos Caranguejos); na 10-20, um.
7. **Desempenho**: soak com janela na Floresta cai a ~37 FPS no pico da investida (~110 bonecos); Cidade Élfica 44-61 FPS. Qualquer mudança não pode aumentar o pico de invasores vivos visíveis.

---

## 3. Pedido 1 — Mais zonas opcionais

Regra de lore usada: os elfos estão sob a **seiva** (o rei "era um bom menino antes da seiva", Ancião Vaeril; Sacerdotisa Myrel duvida). O opcional é o lugar natural para o jogador **descobrir o que é a seiva** sem travar a linha principal. Desertores (Caelir) e refugiados (Dalva espera o marido no portão norte) já dão ganchos.

| Opção | O que é | Escopo | Toca |
|---|---|---|---|
| **A. POIs dentro dos mapas** | Cada lugar existente vira mini-zona: elite raro + baú, 1 cadeia lateral de 2-3 quests, colheita própria. Ex.: Círculo Druídico com "eco da seiva" (elite noturno a confirmar), Emboscada com acampamento de bandidos completo, Cabana do Desertor com missão de resgate | **S** | dados (`quests_catalog`, `GATHER`, spawners extras), pouco Blender (props) |
| **B. 1 campo + 1 mini-masmorra (recomendada)** | **Campo "Brejo das Teias"** 12-16 ao sul do Posto (portão sul: "Do pântano só vem mosquito e aranha", Soldada Meri): pântano com passarelas, aranhas de brejo, bandidos contrabandistas, sapo/serpente de mini-chefe, a casa do marido da Dalva (cadeia de reencontro). **Mini-masmorra élfica "Viveiro de Seiva"** 18-20 numa ala da Cidade Élfica (entrada num forte ou na encosta): onde a seiva é colhida; 1 chefe + 1 sala de quebra-cabeça leve; recompensa = material de tier do Gunnar (+6) | **M** | Blender (zona nova `build_field_marsh.py` + `places.DUNGEONS`), dados (MapDef, portais, spawners, NPC guia, `bot_population`, quests, loot), 2-4 monstros novos (modelos, Fable), música (`Music.MAP_THEME`), arte de carregamento |
| C. 2 campos + 2 masmorras | B + "Bosque dos Grifos" 17-20 (encosta NO da Cidade, ninhos de grifo, cavaleiros desertores) + "Biblioteca do Escriba" (interior élfico com livros-arquivo, Orelien) | **L** | tudo de B em dobro; risco de diluir o XP da faixa |

Regras comuns: XP pela `QuestsCatalog.scale_xp` (faixa 40-50%, 10+ quests), loot 0,3-0,7 materiais, raro ≤ 0,05, chefe garante material de tier; nada trava a linha principal (portão só por nível); layout Erenshor (vale fechado, POIs 60-120 m, estrada curva, landmark).
Riscos: XP da faixa inflar (rodar `band_probe`), mais mapas = mais `start_enter`/`sim_maps` (pequeno), bots espalhados (rever `bot_population`).

---

## 4. Pedido 2 — Cidade Élfica e acampamentos mais vivos

O ferramental já existe (`LIVING_NPCS` com `carry`/`flow`/paradas/barks/`if`/`unless`, `AMBIENT_LIFE`, `ROAD_EVENTS`, `conquest_vis` com lotes `tag` do `Dress`, `SiegeFx` para fogo/fumaça). A Cidade Élfica não usa nenhum.

### 4.1 Rotinas propostas (só dados, salvo nota)

| Id | Rotina | Mapa |
|---|---|---|
| E1 | **Mensageira Aryn de verdade**: rota até os 3 fortes e volta (hoje anel), parada em cada forte; some quando o forte cai | elf_city |
| E2 | **Forja para o quartel**: Ferreira Thalindra + aprendiz levam `carry_crate` (lanças) da forja ao quartel ("Tudo vai para o quartel") | elf_city |
| E3 | **Coletores de seiva**: 2 elfos com baldes (`carry_sack`) da Árvore-Mãe aos fortes; barks inquietos sobre a seiva (pista do mistério) | elf_city |
| E4 | **Treino de recrutas**: Recruta Caelan + 3 recrutas em pátio, bonecos de treino como enfeite (não `training_dummy` da sim) | elf_city |
| E5 | **Grifos no lago** (Ilsa dá peixe): `AMBIENT_LIFE` novo tipo `griffin_far` (voo alto, só visual) ou `hawk` como substituto; borboletas no jardim da Saelis, mariposas nas lanternas élficas | elf_city |
| E6 | **Vida nos fortes**: troca de sentinela, fogueira, prisioneiro humano (barks `FORT_BARKS`-estilo, solto pela quest) | fortes da elf_city |
| P1 | **R7 Posto em alarme** (do living-towns): trompa toca, refugiados trocam para rota curta até a fogueira; guardas da reserva correm ao portão (`responder` do Cerco) | field_forest (código pequeno: condição de investida viva no `WorldState`/NPC) |
| P2 | **R9 Carroça dos refugiados** chegando de Aldara pelo portão oeste (`cart_draft`) | field_forest |
| P3 | **Evento de estrada "Emboscada na Trilha"**: bandidos cercam o carroceiro (`ROAD_EVENTS["field_forest"]`, `EVENT_POINTS` no build) | field_forest (Blender: ponto no JSON) |
| P4 | **Evento élfico "Patrulha com Prisioneiro"**: sargento conduz um refugiado; libertar dá prêmio + bark da Dalva | elf_city |

### 4.2 Mudança de estado pela conquista

| Gatilho | Cidade Élfica | Posto/Floresta |
|---|---|---|
| Forte caído (cada um) | estandarte do capitão cai no forte e no portão do lado (`tag`), sargento daquele setor some, cidadão comenta | lado da investida ligado ao forte cala ou enfraquece (ver §5) |
| `el6_king` | cidade "acorda": guardas sem arco erguido, citizens neutros oferecem troca, festa pequena (reuso do `FESTIVAL` do Bastião) | investida para (`unless: el6_king`), refugiados começam a voltar (rota para a garganta norte), Dalva reencontra o marido |

### 4.3 Opções

| Opção | Escopo | Toca |
|---|---|---|
| A. Rotinas e bichos (E1-E5, P2) | **S** | só dados (`LIVING_NPCS` ligado na elf_city, `AMBIENT_LIFE`, barks) |
| **B. A + conquista (recomendada)** | **M** | A + `conquest_vis` da elf_city (lotes `tag` no `build_elf_city.py`, Fable), `if`/`unless` em NPCs/spawners, `unless` na investida; P1 (código pequeno) |
| C. B + relógio de turnos e som | **L** | R3 troca de guarda (código), harpa/sino élfico (`Sfx`), música por estado (`Music`), eventos P3/P4 |

Riscos: perf da elf_city (44-61 FPS) — teto de +8 rotinas e `AMBIENT_LIFE` barato; JSON da zona muda ao pôr tags (rodar `_check_places`, travessia, chegadas); `carry` novo precisa de prop (`life_props.py`).

---

## 5. Pedido 3 — A investida

### 5.1 Por que vem "empilhada" (causa raiz)

| # | Fato | Código |
|---|---|---|
| 1 | **Todos nascem no mesmo tick** num disco de 3,5 m em volta de `from` (até ~36 corpos) | `RaidSystem.start_raid`: `MapGeometry.random_walkable(sim, def, from, 3.5)` |
| 2 | **Esperam 12 s parados** (trompas) no mesmo lugar: viram uma bola | `RaidSystem.mustering` + `Balance.RAID_MUSTER` 12; `_march` devolve sem `move` |
| 3 | **Uma única rota** com waypoints-ponto; cada um precisa chegar a 2,5 m do MESMO ponto antes de seguir: a coluna afunila em cada curva | `field_forest.json` `raid.route` (7 pontos); `_march` (`distance_to(goal) < 2.5`) |
| 4 | **Velocidade quase igual**: 5,0-6,2 × `RAID_MARCH_PACE` 0,6 = 3,0-3,7 m/s; em ~110 m a diferença é ≤ ~7 s (a confirmar com sonda) | `monsters_catalog.gd` 239-249 |
| 5 | **Separação só até encostar** (raio + raio): nada mantém espaço de formação | `WorldSim._separate_from` |
| 6 | **Mesmo alvo para todos**: `_raid_target` dá a mesma nota a todos (curador, ferido, isolado) com aggro ×1,5 (`RAID_SMART`): a bola inteira cai no mesmo herói | `MonsterBrain._raid_target` |

Resumo: uma leva de até ~36 nasce num ponto, se aglomera 12 s, marcha pela mesma linha na mesma velocidade e escolhe o mesmo alvo — chega e bate como um bloco só.

### 5.2 Opções

| Opção | O que muda | Escopo | Toca |
|---|---|---|---|
| **A. Espaçar a mesma leva** | (a) **escalões**: batedores/linces saem primeiro, depois espadas, arqueiros+magos, grifos por último (atraso `Balance.RAID_ECHELON_GAP` ~6-10 s, ordem por `waves`); (b) **nascimento em arco** de 10-15 m na garganta, não disco de 3,5; (c) **vaga de formação**: cada invasor ganha um deslocamento lateral fixo (±4-6 m) perpendicular ao trecho da rota, e o waypoint vale a 4-5 m; (d) arqueiros/magos marcham 6-8 m atrás da linha; (e) alvo com variedade (penalidade se ≥ N invasores já miram o mesmo) | **S-M** | só sim (`raid_system.gd`, `monster_brain.gd`) + `Balance.RAID_*`; nenhum Blender |
| **B. A + flancos (recomendada)** | 2-3 rotas: garganta norte (principal), flanco NE pelo bosque dos ents até o portão leste, flanco NO pelas teias até o portão oeste; a leva se **divide** entre os lados (mesmo total, ~10-15 por lado) e sai em tempos diferentes; mover `from` para longe da chegada do portal | **M** | sim (A), Blender: `raids` com `side` no `build_field_forest.py` (Fable) + JSON, dados `RAIDS["field_forest"][<lado>]`, falas por lado |
| C. Migrar para o `SiegeSystem` | pressão pela história (el1 → 2; cada forte caído −1 e cala o lado dele; rei → 0 paz), uma leva por vez revezando lados, **assédio** de arqueiros élficos (salva de círculos avisados, `mob_root_arrow` como tema), **batedores com trompa** (linces em `MOB_PATROLS` com `horn`), calmaria, Chamas visuais | **L** | sim (generalizar `SiegeSystem` para mapa sem `segments`), dados, Blender (fogo/fumaça `fx` no Posto), áudio (trompa élfica), testes `--only=siege` |

**Reuso do Cerco Vivo (recomendação)**: pegar **pressão por quest**, **revezar lados**, **calmaria** e **batedores com trompa**; **não** pegar `segments` (o Posto não tem paliçada em obra) nem assédio na 1ª fase (dano não esquivável no nível 13-16 pode ser duro; deixar para P2 depois de medir).

### 5.3 Riscos

| Risco | Mitigação |
|---|---|
| Perf (37 FPS no pico) | escalões e flancos **baixam** o pico de bonecos juntos; manter `RAID_WAVE_CAP`; medir com `--soak` na Floresta antes/depois |
| Investida fácil demais (guardas matam aos poucos) | hoje guarda sozinha repele 85/40/15/0% por força (memória elf-siege); refazer `raid_probe --bots=0,1,3` e reajustar tamanho, não poder da guarda (memória: "raids must be a threat") |
| Quest el2 (24 batedores) fica lenta se a leva encolher | manter o total por leva; só distribuir |
| Bots defensores (`BotBrain._defend`) só olham uma rota | rever a escolha do portão com vários lados (a confirmar no código) |
| Divisão sim/apresentação | tudo novo na sim (`core/`); HUD lê `RaidSystem.status` (já suporta `route`/`side`) |
| Mecânica de combate | assédio/alvo variado = implicação de jogo → passar pelo `game-designer` |

Medição sugerida: a `raid_probe` não imprime dispersão; adicionar métrica `SPREAD` (desvio dos tempos de chegada e largura da coluna a 30 m do portão). Alvo: chegada espalhada em ≥ 20 s, nenhum círculo de 6 m com > 8 invasores.

---

## 6. Decisões para o usuário

| # | Pergunta | Opções | Recomendada |
|---|---|---|---|
| D1 | Tamanho do pacote de zonas opcionais | A POIs nos mapas atuais · B 1 campo + 1 mini-masmorra · C 2 campos + 2 masmorras | **B** |
| D2 | Qual campo novo primeiro | Brejo das Teias (12-16, sul do Posto) · Bosque dos Grifos (17-20, NO da Cidade) | **Brejo** (preenche o meio da faixa, que só tem a Pedreira) |
| D3 | Depois do Rei Aelthar | investida para e o Posto vira paz · continua mais rara (desertores/bandos) · fica como está | **para** (`unless: el6_king`) |
| D4 | Modelo da investida | A só espaçar · B espaçar + flancos · C Cerco Vivo completo | **B**, com pressão por quest do C |
| D5 | Tamanho da leva | mesmo total dividido · menor · maior | **mesmo total dividido** |
| D6 | Fortes caídos mudam o mundo | sim, cada forte (visual + cala um flanco) · só o rei · não | **cada forte** |
| D7 | Vida na Cidade Élfica | A rotinas · B + conquista · C + turnos e som | **B** |

## 7. Ordem sugerida de pacotes

| WP | Conteúdo | Agente | Depende |
|---|---|---|---|
| WP1 | Investida opção A (escalões, arco, vagas, alvo variado) + métrica `SPREAD` na `raid_probe` | gameplay-programmer (sim) + world-builder (números) | D4/D5 |
| WP2 | Flancos: `raids` com `side` em `build_field_forest.py`, novo `from` longe do portal, `RAIDS` por lado, `unless` do rei/fortes | **Blender = Fable** + world-builder | WP1, D3, D6 |
| WP3 | Posto vivo: P1 alarme (código pequeno), P2 carroça, P3 evento de estrada | world-builder (+ programmer para P1) | WP2 |
| WP4 | Cidade Élfica viva: E1-E6, `AMBIENT_LIFE`, `conquest_vis` (tags no `build_elf_city.py`) | world-builder + **Fable** (tags/props) + sound-designer | D7 |
| WP5 | Zona opcional: Brejo das Teias (layout `/layout-zone`, places, spawners, NPC guia, quests, loot, música, loading art) | world-builder (design) → **Fable** (zona e monstros) → writer (falas) | D1/D2 |
| WP6 | Mini-masmorra Viveiro de Seiva | **Fable** + world-builder | WP5 |
| WP7 | QA: testes, `band_probe --from=10 --to=20`, `raid_probe --trials=20 --bots=0,1,3`, soak na Floresta e na Cidade, smoke | qa-tester | cada WP |
