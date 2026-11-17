# Cidades com Identidade e Mapas Vivos (níveis 1-20)

> **Status**: P1 IMPLEMENTADA (world-builder, 2026-11-17): Feira do Trigo, pátio da forja NE, celeiro S, Estátua do Fundador, R1, R2, galinhas/corvos, `RoadEventSystem` + E1. Decisões do usuário: 1 = Feira do Trigo, 2 = Aldara + Posto, 3-8 = recomendadas. Do Posto (P2) entrou só o que o usuário pôs no escopo: Fogueira Comunal + roda de carroças + varais + Trompa (visual) e R8 (lenhadores/caçador). Em aberto: relógio de turnos, R3/R4/R6/R7/R9, E2-E5, templo L e taverna SO de Aldara, P3 (ver seção 9).
> **Origem**: playtest do usuário — "senti falta de mapa vivo"; "a cidade com aquela estátua é meio estranha, podia ter diferenciais". Direção aprovada.
> **Escopo**: (A) identidade visual/funcional de cada cidade-hub; (B) rotinas de ambiente e pequenos eventos de estrada nos mapas 1-20.
> **Fora do escopo**: ciclo dia/noite de iluminação, sistemas de economia, quests novas de história (só recompensas mínimas de evento).

---

## 1. Overview

Os mapas do Ato I (Vale de Aldara 1-10, Floresta Sombria 10-20) foram feitos antes das ferramentas de "mapa vivo" do Ato II
(`LIVING_NPCS` com carga/carroça/barks, `AMBIENT_LIFE`, carroças `cart_draft`, sentinelas que trocam de estágio por quest).
Hoje o Ato II (Porto, Costa, Estepes, Kharzun) tem estivadores, caravanas, pescadores no cais, gaivotas; o Ato I tem só
11 moradores que passeiam em círculo na praça de Aldara e 6 refugiados no Posto. **A primeira hora do jogo é a parte
menos viva do jogo.** Este documento faz duas coisas:

- **A. Identidade de cidade**: cada hub troca o par genérico chafariz + estátua por um **centro com função**, legível
  da câmera de 52°/24 m, ligado à região e à história.
- **B. Mapas vivos 1-20**: rotinas de ambiente (quase todas só dados, sistemas que já existem) e um sistema pequeno e novo de
  **eventos de estrada** (lobos no lavrador, carroça quebrada, emboscada), opcionais, curtos, nunca bloqueiam nada.

Entrega em 3 fases; a P1 é a fatia mínima: centro de Aldara + 2 rotinas + 1 evento.

---

## 2. Player Fantasy

"Eu chego numa vila que tem vida própria e que **não precisa de mim para existir** — mas, quando eu passo, às vezes ela
precisa." O jogador deve sentir:

- **Lugar** (Aldara é a vila do trigo; o Posto é um acampamento de refugiados sitiado) e não "círculo de casas nº 1".
- **Movimento na estrada**: carroças, gente indo e voltando do campo, guardas trocando de turno — o mundo anda enquanto ele caça.
- **Pequenos heroísmos**: correr 20 m para salvar um lavrador dos lobos e ouvir "obrigado!" vale mais pela sensação do que pelo prêmio.
- **Orientação**: "a feira fica no centro, a forja solta fumaça a nordeste, o templo é a leste" — a cidade se lê sem minimapa.

Referências: Erenshor (vilas com rotina simples e estradas com tráfego), Ragnarok (Prontera = mercado + catedral, Payon =
árvores e tendas, Morroc = poço do deserto — cada cidade com UMA silhueta), Tree of Savior (praças de cor, feiras com toldo).

---

## 3. Detailed Rules

### 3.1 O que lê errado na praça de Aldara hoje

Visto na arte de carregamento (`assets/ui/loading/city_aldara.jpg`, foto aérea do modelo real) e no build
(`tools/blender/zones/build_city_aldara.py` linhas 460-491). **Pendente**: confirmar com o tour na câmera do jogo
(`-- --tour=<pasta> --tour_map=city_aldara`); este agente não tem shell para rodar o Godot.

| # | Problema | Por que lê errado de cima |
|---|---|---|
| 1 | Praça = disco de terra lisa de ~45 m de diâmetro | É a maior superfície única da imagem e está vazia: lê como **arena**, não como praça de vila. |
| 2 | Centro = chafariz 3,6 m + estátua 1,2 × 2,6 m | Ocupa ~8% do diâmetro; de 24 m a estátua é um **pino branco**. O que mais brilha no centro é o **Cristal de Retorno** (efeito de UI), então o "símbolo" de Aldara hoje é um portal azul. |
| 3 | Simetria radial perfeita | 4 quadrantes iguais, 4 portões iguais, 8 torres iguais, 16 casas iguais viradas para o centro: **não dá para saber qual portão é o leste** sem o minimapa. |
| 4 | Detalhes espalhados por igual | 2 bancas, 2 caixas, 4 bancos e lampiões distribuídos em pontos isolados: não há **aglomerado** (lugar onde algo acontece). |
| 5 | Casas do anel interno (r = 14 m) | Flutuam como ilhas na terra, sem quintal, sem cerca, sem rua — reforçam o "tabuleiro". |
| 6 | Estátua sem dono | Ninguém fala dela, não tem nome, não tem quest: é enfeite genérico (o usuário notou exatamente isso). |

**Regra que sai daqui**: o centro de uma cidade precisa ter (a) **área de leitura ≥ 25% do diâmetro da praça** vista de cima,
(b) **altura ≤ 6 m** no raio de 20 m do hub (manual, `zonas.md`), (c) **cor própria** que não seja a do chão nem a dos avisos de
golpe (`FxManager.DANGER*`), (d) **gente parada ou andando ali por motivo** (função), (e) **assimetria**: cada quadrante da cidade com um ofício.

### 3.2 Lista de hubs e proposta de centro (A)

Hubs encontrados no catálogo (`data/catalog/maps_catalog.gd`):

| Mapa | Nome | Faixa | Centro hoje | Proposta (recomendada) | Prioridade |
|---|---|---|---|---|---|
| `city_aldara` | Vale de Aldara | 1-10 | chafariz + estátua + poço | **Feira do Trigo** (roseta de toldos + Balança/Mó do Trigo + carroças) | **P1** |
| `field_forest` (hub) | Posto dos Caçadores | 10-20 | poço + estátua (build_field_forest.py:77-78) | **Fogueira Comunal + Roda de Carroças dos refugiados + Varal de Peles** | P2 |
| `field_ruins` (hub) | Bastião da Aurora | 20-30 | catedral (bom) + chafariz no mercado + estátua no salão | manter catedral; estátua vira **Muro dos Caídos** (velas, nomes); chafariz vira **Feira de Armas** | P3 |
| `elf_city` | Cidade Élfica | 17-21 | Árvore-Mãe | **nenhuma mudança** — é o exemplo do que funciona (uma silhueta, uma história) | — |
| `city_port` | Porto Esperança | 30-35 | "âncora de pedra" (`statue`) + memorial | **Guindaste do Cais** sobre a âncora (fora de 1-20, listado para coerência) | P3 |
| `field_steppe` (posto) | Posto da Caravana | 35-40 | a própria caravana | já tem identidade (forja sobre rodas) | — |

#### Aldara — Feira do Trigo (recomendada) e alternativas

História usada: Aldara "resiste há 300 anos" (Ancião Ravi), vive da fazenda do Ferdinando/Lavrador Beto, do lago (Pescadora Nalu)
e do mel da floresta (Padeira Rosa). É a vila-celeiro do vale e a primeira cidade do jogador.

| Opção | Forma de cima | Prós | Contras |
|---|---|---|---|
| **A1. Feira do Trigo** (recom.) | Anel de 8 bancas com toldos listrados em 2 tons pastel alternados (cada um ~3 × 2,4 m, altura ≤ 3,2 m), formando uma **roseta** de ~18 m em volta de uma **Mó/Balança do Trigo** (pedra redonda 4 m + braço de balança 4,5 m) com sacos e cestos; 2 carroças paradas descarregando | Cor alta e baixa, lê ótimo a 52°; função clara (comércio); dá motivo para a rotina R1/R2; não esconde NPCs (toldo baixo, oclusão mínima) | Muitos objetos (custo de draw: resolver por `Dress` em lote); tem de reservar vaga para os NPCs de serviço |
| A2. Árvore do Conselho | Copa de ~14 m (disco verde-escuro) com banco em anel; o Ancião senta ali | Silhueta fortíssima; "300 anos" vira árvore | Copa no centro **cobre a praça** na câmera alta (fere a regra ≤ 6 m perto do hub); depende do fade de oclusão; repete a ideia da Cidade Élfica |
| A3. Poço com fila + lavadeiras | Poço grande com cobertura, varais de roupa coloridos em raio | Barato; rotina natural (fila de moradores) | Pequeno de cima; poço já existe em outros hubs (o Posto tem um) |

**Diferenciadores por quadrante de Aldara** (quebram a simetria, ajudam a orientação; todos ≤ 4 m):
- **NE — Pátio da Forja do Brom**: chão de pedra escura, bigorna, pilha de lenha/carvão, fumaça (partícula já usada nas forjas do Ato II). Bate com a estrada das colinas/castelo.
- **L — Escadaria do Templo (Irmão Odo, Irmã Alba)**: 3 degraus largos de pedra clara + toldo/telhado azul; velas. Leste = Floresta.
- **SO — Quintal do Javali Dourado (taverna)**: mesas e barris na frente da porta (`INTERIORS` já tem a taverna). Oeste = Ruínas/Rei Javali.
- **S — Celeiro e Carroças**: portão sul ganha celeiro baixo + cercado; é onde a carroça da colheita (R1) entra. Sul = lago/fazenda.
- **Estandartes dos portões** com cor/símbolo por direção (trigo, sol, javali, lobo) — já existe `estandarte_<gname>` no build; só muda cor e glifo.

**O que acontece com a estátua e o chafariz**: o chafariz sai (a mó ocupa o centro); a estátua **vira personagem**: passa a
"Estátua do Fundador" no pátio do Ancião (fora da praça), com nome e uma fala no Quadro de Avisos — ou é removida. Ver Decisão 3.

#### Posto dos Caçadores — Fogueira Comunal (P2)

História: refugiados expulsos pelos elfos, cerco diário pela garganta norte, Cozinheira Bia ("quem segura o portão come primeiro").
Centro: **fogueira grande** (anel de pedras 5 m, brilho quente — cor quente é segura aqui porque é um prop de fogo, não chão
pintado) com **caldeirão da Bia**, **roda de 4-5 carroças de refugiados** com lona (de cima: retângulos claros em círculo,
lê "acampamento de gente sem casa") e **varais de peles** (retângulos ocre). Diferenciador funcional: **Trompa do Cerco** na
torre norte — quando a investida (`RAIDS`) começa, o NPC da torre "toca" (bark + som) e os refugiados correm para a fogueira
(troca de rota, ver R7). A estátua sai.

#### Bastião da Aurora (P3, nota curta)
A catedral já é o marco. Troca só as duas peças genéricas: estátua do salão → **Muro dos Caídos** (muro baixo com velas, nomes
dos que morreram nas fortalezas; acende uma vela por fortaleza retomada via `conquest_vis`/`when`), chafariz do mercado →
**Feira de Armas** (bancas de armeiro com escudos pendurados).

### 3.3 Blender vs dados (A)

| O quê | Onde | Observação |
|---|---|---|
| Mó/balança, bancas com toldo, celeiro, degraus do templo, pátio da forja | `build_city_aldara.py` (troca linhas 476-485) + função nova em `zones/act2_dress.py`-estilo (ex. `town_dress.aldara`) com `Dress` em lote por célula | peça grande nasce onde `Dress.ok()` deixa e ganha `Dress.solid()`; toldo = pano dobrado (`Dress.cloth`), nunca placa chata |
| Cor do chão dos pátios | `Zone.patch` com y num vão livre da pilha de planos (anotar no comentário, regra de `zonas.md`) | tons do próprio chão ±13% (pedra da forja, terra batida da feira) |
| Colisão das bancas/mó | `OB_box_*`/`OB_circle_*` → `data/zones/city_aldara.json` | **o JSON muda** (é esperado): rodar `_check_places`, travessia, chegadas de portal |
| Posições de NPC de serviço | `SPAWN_npc_*` no build | mercador vai para uma banca da feira; ferreiro para o pátio NE; alquimista perto do templo |
| Nomes/falas da estátua, barks da feira | `maps_catalog.gd` (`ALDARA_NPCS`, `VILLAGERS`, `LIVING_NPCS["city_aldara"]`) | só dados |
| Ícone/arte de carregamento | `tools/blender/loading_art.py` refaz `city_aldara.jpg` | check `_check_loading_art` |
| Cristal de Retorno | `CRYSTALS["city_aldara"]` (-7,5, 0) | **mover** para a borda da feira (não pode ser o elemento mais forte do centro) |

### 3.4 Rotinas de ambiente (B) — o que entra por mapa

Princípio: **usar o que já existe** (`VILLAGERS` wander/route, `LIVING_NPCS` com `carry`/`cart`/`cart_draft`/barks/`if`/`unless`,
`AMBIENT_LIFE`, `GuardBrain`). Achado importante: `city_aldara` e `field_forest` **não chamam** `living_npcs(LIVING_NPCS[...])`
(só os mapas do Ato II, `maps_catalog.gd` 1652/1680/1714/1831) e não têm entrada em `AMBIENT_LIFE`. Ligar isso é uma linha
por mapa e destrava quase toda a parte B sem sistema novo.

| Id | Rotina | Mapa | Sistema | Novo? |
|---|---|---|---|---|
| **R1** | **Carroça da Colheita**: carroceiro + cavalo (`cart_draft`) sai da fazenda (-66, 67), estrada oeste, portão sul, para no celeiro/feira, volta. Carregador Juca (já existe) passa a ir da carroça às bancas com `carry_sack` | Aldara | `LIVING_NPCS` rota + carry | só dados (+1 linha para ligar `LIVING_NPCS` em Aldara) |
| **R2** | **Feira com fregueses**: 4-6 moradores com rota curta banca→banca→poço→banca (paradas), barks de pregão ("Pão quentinho!", "Olha o mel!") nos feirantes parados (`stay`) | Aldara | `LIVING_NPCS` (`stay`, rota, barks) | só dados |
| R3 | **Troca da guarda**: a cada turno o guarda de ronda vai ao portão, o guarda do portão volta ao quartel (dois NPCs trocam de rota) | Aldara, Posto | precisa do **relógio de turnos** (3.6) | código pequeno |
| R4 | **Lavradores no campo**: 2-3 com rota em zigue-zague nas leiras da fazenda, `carry_sack`, paradas longas | Aldara (fazenda) | `LIVING_NPCS` | só dados |
| R5 | **Crianças e bichos**: galinhas soltas na fazenda e no celeiro, corvos no trigal, cão que segue a rota das crianças | Aldara | `AMBIENT_LIFE` tipo novo `hen` (não voa, como `crab`) e `crow`; cão = `LIVING_NPCS` com `model` | `hen` = 1 tipo novo em `AmbientLife.KINDS` (apresentação); o cão precisa de modelo (ver Decisão 6) |
| R6 | **Pescadora no píer do lago** (Nalu passa a `stay` na vara) | Aldara | `LIVING_NPCS` `stay/perch` | só dados |
| R7 | **Posto em alarme**: na investida, refugiados trocam de rota para a fogueira (`if/unless` de estado de investida) | Posto | `RaidSystem` estado → condição de NPC | código pequeno |
| R8 | **Lenhadores e caçadores voltando**: `carry_log` da clareira ao Posto; caçador com `carry_sack` (pele) | Floresta | `LIVING_NPCS` | só dados |
| R9 | **Carroça dos refugiados chegando** de Aldara pelo portão oeste do Posto (rota longa na estrada) | Floresta | `LIVING_NPCS` `cart` | só dados |

### 3.5 Eventos de estrada (B) — sistema novo `RoadEventSystem`

Pequenos encontros que **aparecem** perto do jogador numa estrada/campo, duram pouco e somem se ninguém ajudar.

**Regras gerais**
1. Roda só no mapa onde o jogador está (como o relógio do `RaidSystem`); mapa sem jogador não sorteia nem simula evento.
2. **No máximo 1 evento ativo por mapa** (Decisão 5 pode subir para 2 na Floresta).
3. Nasce num **ponto de evento** pré-marcado no build (`SPAWN_event_<tipo>_NN`, à beira da estrada), escolhido entre os que ficam
   a **35-70 m do jogador**, fora do hub (≥ 40 m do centro), ≥ 25 m de portal, chegada, lugar com NPC e spawner de chefe.
4. Aviso: grito/bark do NPC do evento + ponto no minimapa + som curto. Nada de janela, nada de pausa.
5. **Nunca bloqueia**: não fecha estrada nem portal, não é pré-requisito de quest, não dá debuff, o NPC do evento **não morre**
   (perde → "foge ferido para a vila" e some), monstros do evento **não perseguem além de 30 m** do ponto e somem com ele.
6. Expira em `Balance.EVENT_LIFETIME` s sem interação; ao terminar (resolvido ou não) o ponto entra em recarga.
7. Recompensa **pequena e única por evento**: XP = fração do nível (`Balance.EVENT_XP_FRAC`), moedas pequenas, 1 consumível
   (pão = cura fora de combate, poção). Nunca equipamento, nunca moeda lendária.
8. Os monstros do evento **contam no teto de monstros** do mapa e não dão loot de tabela (só a recompensa do evento), para não virar farm.
9. Determinístico com a semente da sim (testes).

**Catálogo de eventos (1-20)**

| Id | Evento | Mapa / faixa | Como resolve | Recompensa | Fase |
|---|---|---|---|---|---|
| **E1** | **Lobos no Lavrador**: lavrador encurralado por 2-3 lobos do nível do ponto, grita "Socorro! Os lobos!" | Aldara, colinas N e estrada da fazenda | matar os lobos; o lavrador agradece e volta andando para a fazenda | XP pequena + Pão do Lavrador (×2) | **P1** |
| E2 | **Carroça Quebrada**: carroça parada com roda solta; carroceiro pede ajuda | Aldara estrada leste / Floresta estrada oeste | interagir (F) 2 s na carroça (`GatherSystem`-like); 30% de chance de 2 slimes/javalis aparecerem "atraídos pelo cheiro da carga" | moedas + poção pequena; a carroça segue a rota | P2 |
| E3 | **Mercador pede escolta**: mercador no portão pede escolta até o POI/Posto | Aldara → Floresta | andar ao lado (≤ 15 m); 1-2 emboscadas leves no caminho; se o jogador se afastar 60 m, o mercador espera, depois volta | moedas maiores + desconto 1 compra | P3 |
| E4 | **Emboscada de Bandidos**: 3 foras-da-lei (roster `outlaw`) saem de trás das árvores quando o jogador passa | Floresta, estradas do sul/leste | matar | baú pequeno de bandido (moedas + consumível) | P2 |
| E5 | **Refugiados perseguidos**: família foge de 2 linces élficos pela estrada | Floresta, garganta norte | matar os linces | XP + bark da família no Posto depois | P2 |

### 3.6 Relógio de turnos (P2) — "a vila tem horário"

Não existe relógio de dia na sim (grep: nenhum `time_of_day`). Proposta mínima, **sem mudar a luz**:
- `WorldState` ganha um **turno do mapa** que gira em ciclo: `manhã → feira → tarde → recolher` (`Balance.TOWN_SHIFT_S`, ex. 4 × 180 s).
- NPC de `LIVING_NPCS` pode ter `shift: {"feira": rota, "recolher": rota}`; sem `shift`, tudo como hoje.
- Feira: bancas "abertas" (toldo esticado, fregueses) só em `feira`; no `recolher` toldos enrolados (apresentação lê o turno), feirantes vão para casa.
- Troca da guarda (R3) acontece na virada de turno.
Ver Decisão 4 (fazer o relógio ou ficar só com rotinas contínuas).

### 3.7 Bots e eventos

- Bots já caçam monstros hostis perto deles; os lobos do E1 são hostis comuns, então **bots entram sozinhos** se estiverem perto.
- Para não "roubar" o evento do jogador: nos primeiros `Balance.EVENT_BOT_GRACE` s (ex. 25 s) os bots ignoram monstros de evento
  se o jogador está a ≤ 70 m; depois disso (ou sem jogador perto) entram normalmente. Recompensa do evento vai para quem
  contribuiu (`kill_sharers`); bot que resolve sozinho gera uma fala no chat (`BotChat`: "Salvei um lavrador lá nas colinas!").
- Bots **não** iniciam evento, não aceitam escolta e não são o NPC do evento.
- Ver Decisão 7.

### 3.8 Sim (`core/`) vs apresentação (`game/`)

| Peça | Camada | Onde |
|---|---|---|
| Rotas, carga, `stay`, turno do NPC | sim | `NpcSystem.update_npc` (já existe) + `shift` (novo, P2) |
| Relógio de turnos | sim | `WorldState` (estado por mapa) |
| Evento: sorteio, ponto, spawn, expiração, recompensa, recarga | sim | `core/sim/systems/road_event_system.gd` (novo, estático `f(sim, ...)`; repasse em `world_sim.gd`) |
| Catálogo de eventos e pontos | dados | `MapsCatalog.ROAD_EVENTS` + `SPAWN_event_*` no JSON da zona; números em `Balance.EVENT_*` |
| Sinais | sim → apres. | `Events.post(&"road_event_started"/"road_event_ended", ...)` (nunca `.emit` em `core/`) |
| Grito, ponto no minimapa, som, barks, toldos enrolados, galinhas | apresentação | `AmbientLife`, `Minimap`, `Sfx`, view da zona |
| Centro da cidade, quadrantes | Blender + JSON | `build_city_aldara.py`, `Dress` |

### 3.9 Orçamento de desempenho

| Item | Limite | Como medir |
|---|---|---|
| Tick da sim | Aldara/Floresta: **+≤ 0,3 ms/tick** sobre a linha de base; teto global ≤ 10 ms com Kharzun (AC-36 do Ato II) | `sim_probe.tscn -- --map=city_aldara --phases` antes/depois |
| Entidades a mais | Aldara **≤ +12** NPCs de ambiente (carroça = carroceiro + cavalo), Floresta **≤ +10** | `sim_probe --census` |
| Views | entram pela `ViewQueue` como qualquer NPC; NPC de ambiente atrás de grupo/alvo na prioridade | `--perf --perf_at=0,0` (draws da praça **+≤ 40**) |
| Nomes | NPC de ambiente sem nome visível longe (só ao passar o mouse/perto), passa por `NameplateCrowd` | `--perf` + foto |
| Bichos | 1 MultiMesh por tipo (galinha, corvo) = 1 draw cada | `--perf` |
| Feira (props) | lotes `Dress` por célula 36 m, cor no vértice | `--perf`, `canvas/visible/shadow_pass` |
| Evento | ≤ 4 monstros por evento, contam no teto do mapa | `band_probe` na faixa (não pode mudar a caçada) |

---

## 4. Formulas

Todas as constantes em `data/balance.gd` (nomes propostos; valores iniciais para playtest):

- **Próximo evento** no mapa do jogador:
  `t_next = EVENT_FIRST_S + rng.randf() * EVENT_JITTER_S` na entrada; depois de cada evento:
  `t_next = EVENT_EVERY_S + rng.randf() * EVENT_JITTER_S`.
  Início: `EVENT_FIRST_S = 90`, `EVENT_EVERY_S = 240`, `EVENT_JITTER_S = 180` → um evento a cada **4-7 min** de presença.
  (Aldara: ~1 evento por 2 quests; perceptível, não ruidoso.)
- **Ponto válido**: `EVENT_NEAR_M (35) ≤ dist(jogador, ponto) ≤ EVENT_FAR_M (70)` e `agora ≥ ponto.recarga_ate`.
  Recarga do ponto: `EVENT_POINT_CD_S = 600`.
- **Duração**: `EVENT_LIFETIME = 120` s sem ninguém a ≤ 30 m; ao chegar alguém, `EVENT_RESOLVE_S = 90` s para resolver.
- **Nível dos monstros do evento**: `clamp(nível_do_spawner_mais_perto, faixa_do_mapa)` — nunca acima do spawner da área.
- **XP**: `xp = round(Balance.xp_to_next(nível_jogador) * EVENT_XP_FRAC)`, `EVENT_XP_FRAC = 0.04` (≈ 4% do nível; um abate de
  lobo na faixa dá ~1-2%: o evento vale ~3 abates + o prêmio). Dividido por `kill_sharers` como abate.
- **Moedas**: `EVENT_COIN_BASE + EVENT_COIN_PER_LV * nível` (ex. 5 + 2/nível).
- **Bots**: ignoram monstro de evento enquanto `t_evento < EVENT_BOT_GRACE (25)` e `dist(jogador, ponto) ≤ EVENT_FAR_M`.
- **Turno** (P2): `turno = floor(tempo_no_mapa / TOWN_SHIFT_S) % 4`, `TOWN_SHIFT_S = 180`.

---

## 5. Edge Cases

| Caso | Regra |
|---|---|
| Jogador entra numa dungeon/interior com evento ativo | O evento continua o relógio só com o jogador no mapa: congela; se ele volta em ≤ `EVENT_LIFETIME`, segue; senão expira sem prêmio. |
| Jogador usa Cristal de Retorno / troca de mapa | Igual ao acima. Nada fica pendurado (evento termina limpo, monstros somem). |
| Investida (`RAIDS`) começa no mapa | Evento ativo termina em silêncio; nenhum evento novo enquanto a investida dura. |
| Lobos do E1 puxados para longe (kite) | Além de 30 m do ponto voltam (leash) e curam como monstro normal; o lavrador não sai do lugar. |
| Jogador morre no evento | Evento continua até expirar; nada de penalidade extra. |
| Bot mata tudo antes do jogador chegar | Bot recebe a parte dele, o lavrador agradece em voz alta, chat do bot; o jogador vê o fim (mundo vivo). |
| Grupo (party) | Prêmio igual ao de um abate dividido (`PartySystem`), consumível para cada membro que contribuiu. |
| Ponto de evento bloqueado por lugar/estrada nova | Check rejeita (`_check_road_events`: ponto andável, fora de água, ≥ 25 m de portal/chegada/NPC). |
| Carroça (R1) cruza com o jogador na ponte/portão | NPCs já desviam como hoje (rota com folga); a rota não passa no vão de 4 m do portão em sentido contrário à ronda (conferir no check de rotas). |
| Save | Nada de evento vai para o save (efêmero). Turno idem. Formato do save inalterado. |
| Interior aberto (taverna) com feira | Turno não vale para interiores. |
| Monstros do evento + teto do mapa cheio | Evento não nasce (tenta de novo em 30 s). |
| Jogador de nível muito acima da faixa | Evento nasce igual (é vida do mundo), prêmio de XP segue a fórmula do nível (pequeno de qualquer jeito). |

---

## 6. Dependencies

- **Usa (existente)**: `NpcSystem` (rotas/stay), `MapsCatalog.VILLAGERS`/`LIVING_NPCS`/`AMBIENT_LIFE`, `CarryPose`/`life_props.py`
  (`cart_draft`), `AmbientLife` (barks, bichos), `MobSystem` (aggro/leash), `LootSystem`/`PartySystem` (`kill_sharers`),
  `RaidSystem` (padrão do relógio com jogador no mapa; supressão), `BotBrain`/`BotChat`, `ViewQueue`, `NameplateCrowd`, `Sfx`.
- **Cria**: `RoadEventSystem` (core), `MapsCatalog.ROAD_EVENTS`, marcadores `SPAWN_event_*` no pipeline de zona, constantes `Balance.EVENT_*`/`TOWN_SHIFT_S`,
  tipo `hen` em `AmbientLife.KINDS`, função de acabamento de cidade (`Dress`), relógio de turnos em `WorldState` (P2).
- **Coordenação**: `world-builder` (builds), `blender-modeler` (mó, toldo, celeiro; cão), `narrative-director` (falas, estátua do fundador),
  `audio-director` (pregão, trompa, grito de socorro), `ai-programmer` (graça dos bots), `art-director` (cores dos toldos x gramática de cor).

---

## 7. Tuning Knobs

| Knob | Inicial | Faixa segura | Efeito |
|---|---|---|---|
| `EVENT_FIRST_S` | 90 | 60-180 | quanto o jogador anda antes do 1º evento |
| `EVENT_EVERY_S` + `EVENT_JITTER_S` | 240 + 180 | 180-600 | densidade de eventos (alto = ruído; baixo = "não aconteceu nada") |
| `EVENT_LIFETIME` | 120 | 60-180 | janela para chegar |
| `EVENT_NEAR_M` / `EVENT_FAR_M` | 35 / 70 | 25-90 | quão perto aparece (fora da tela, mas audível) |
| `EVENT_POINT_CD_S` | 600 | 300-1200 | repetição no mesmo lugar |
| `EVENT_XP_FRAC` | 0.04 | 0.02-0.06 | valor do evento (acima de 0,06 vira farm) |
| `EVENT_BOT_GRACE` | 25 | 0-45 | quanto o jogador tem antes dos bots |
| `TOWN_SHIFT_S` (P2) | 180 | 120-300 | ritmo da vila |
| NPCs de ambiente por mapa | Aldara 12 / Floresta 10 | — | vida x custo (orçamento 3.9) |

---

## 8. Acceptance Criteria

**A — Identidade**
- AC-A1: em `city_aldara.json` não existe `statue` nem `fountain` dentro de 20 m do centro; existe a peça central (mó/balança) e ≥ 6 bancas em roseta. (check `_check_town_identity`)
- AC-A2: nenhuma peça nova com altura > 6 m no raio de 25 m do centro; nenhum `PLACE_CONFLICT`; `_check_places`, travessia e chegadas de portal passam.
- AC-A3: foto `CAM_game` da praça e `CAM_top` retidas em `production/qa/evidence/living-towns/aldara/`; nota ≥ 8 no loop de layout (legibilidade/multidão) e o usuário consegue dizer qual portão é leste sem minimapa (pergunta no playtest).
- AC-A4: Cristal de Retorno fora do centro; `loading_art` refeito (`_check_loading_art`).

**B — Vida**
- AC-B1: Aldara e Floresta chamam `living_npcs(LIVING_NPCS[...])`; toda rota passa por chão andável, cruza água só em ponte e não termina dentro de colisor (check `_check_living_routes`).
- AC-B2: R1 completa ida e volta em ≤ 4 min sem ficar presa (`sim_probe` 20 min, 0 NPC parado > 30 s fora de `stay`).
- AC-B3: `RoadEventSystem`: com semente fixa, o 1º evento nasce entre `FIRST` e `FIRST+JITTER`; nunca 2 ativos; não nasce sem jogador no mapa, durante investida, a < 25 m de portal; expira e limpa monstros; prêmio pago 1 vez; nada no save. (check `_check_road_events`)
- AC-B4: NPC de evento não morre; nenhum evento muda estado de quest/portão.
- AC-B5: desempenho dentro do orçamento 3.9 (números antes/depois no relatório da tarefa).
- AC-B6: `band_probe --from=1 --to=10` sem regressão (eventos não mudam a caçada da faixa).
- AC-B7: smoke `--autostart` sem `SCRIPT ERROR`; foto do E1 em andamento retida.

---

## 9. Plano em fases

**P1 — fatia mínima (Aldara)**
1. **Feira do Trigo** no centro de Aldara (mó/balança + roseta de 8 toldos + 2 carroças paradas), chafariz sai, estátua vira Estátua do Fundador fora da praça (ou sai), cristal vai para a borda. Quadrantes: só o **pátio da forja NE** e o **celeiro S** nesta fase.
2. **R1 Carroça da Colheita** (fazenda → portão sul → celeiro/feira → volta) — só dados + ligar `LIVING_NPCS` em Aldara.
3. **R2 Feira com fregueses** (feirantes `stay` com pregão + 4 fregueses em rota curta) — só dados.
4. **E1 Lobos no Lavrador** com `RoadEventSystem` mínimo (1 tipo de evento, 3-4 pontos nas colinas N e na estrada da fazenda).
5. Checks AC-A1/A2/A4, AC-B1/B3/B4, fotos, sim_probe/perf.

**P2 — vila com horário e Floresta viva**
Relógio de turnos (3.6), troca da guarda (R3), feira por turno, lavradores (R4), galinhas/corvos (R5), pescadora no píer (R6);
Posto dos Caçadores: fogueira comunal + roda de carroças + trompa (R7), lenhadores/caçadores (R8), carroça de refugiados (R9);
eventos E2 Carroça Quebrada, E4 Emboscada, E5 Refugiados; quadrantes restantes de Aldara (templo L, taverna SO).

**P3 — acabamento**
E3 Escolta; Bastião (Muro dos Caídos, Feira de Armas); Guindaste do Porto; cão das crianças; ajuste dos bots com evento; revisão de áudio.

---

## 10. Decisões para o usuário

1. **Centro de Aldara**: A1 Feira do Trigo **(Recomendado)** / A2 Árvore do Conselho / A3 Poço com fila. — Feira lê melhor de cima e alimenta as rotinas; a árvore é mais icônica mas cobre a praça.
2. **Escopo das cidades nesta rodada**: só Aldara + Posto **(Recomendado)** / todos os hubs 1-30 / todos incluindo Porto. — Foco na primeira hora, onde o problema foi sentido.
3. **Destino da estátua**: vira Estátua do Fundador fora da praça, com nome e fala **(Recomendado)** / remover / manter no centro da feira. — Reaproveita o modelo e dá história ao que o usuário achou estranho.
4. **Relógio de turnos (feira por horário, troca da guarda)**: sim, na P2, sem mudar a luz **(Recomendado)** / não, só rotinas contínuas / sim com dia-noite de iluminação. — Relógio barato dá "horário"; dia-noite visual é outro projeto (afeta arte de todas as zonas).
5. **Densidade de eventos**: 1 ativo por mapa, 4-7 min **(Recomendado)** / 2 ativos na Floresta / mais raro (8-12 min). — Perceptível sem virar ruído; ajustável em `Balance`.
6. **Bichos/cão**: galinhas e corvos por `AmbientLife` (1 draw cada) **(Recomendado)** / também um cão com modelo novo (Blender) / nenhum. — Galinha é quase de graça; cão exige modelo e animação.
7. **Bots nos eventos**: entram depois de 25 s de graça e falam no chat **(Recomendado)** / entram na hora / nunca entram. — Mundo vivo sem tirar o momento do jogador.
8. **Recompensa**: XP ~4% do nível + consumível + moedas **(Recomendado)** / só consumível e agradecimento / incluir chance de peça. — Peça vira farm; nada além de "obrigado" esvazia o incentivo.
