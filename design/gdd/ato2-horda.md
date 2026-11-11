# Ato II — A Horda

> **Status**: Designed (aguarda `/design-review` em sessão nova)
> **Author**: Luis Robinson + Claude
> **Last Updated**: 2026-11-10
> **Last Verified**: 2026-11-10
> **Implements Pillar**: 4 (Mundo vivo) e o foco em grupo (bots + chefes que escalam com o grupo); 3 (Equipamento é poder, build é escolha)
> **Origem**: plano aprovado em 2026-11-10 (`~/.claude/plans/goofy-yawning-charm.md`). Sistema fora de índice (o projeto não tem `systems-index.md`; o design legado vive em `docs/DESIGN.md`).

## Summary

O Ato II leva o jogador e os bots ao continente de **Kharzun**, níveis **30 a 45**, contra a **Horda**: clãs de orcs, goblins e
trolls unidos à força pelo **Grão-Senhor da Guerra** porque fogem de algo pior que vem do leste. São três cenários (Costa
Partida, Estepes de Cinza, Monte Kharzun) que **mudam com as missões**, como a Floresta e o Bastião do Ato I; uma linha de
inimigos em evolução inspirada nos arquétipos dos Northerners de Wesnoth (nomes e visual próprios); missões paralelas por
lugar; e uma **ascensão por classe** (35/40/45) que abre estratégias mais fortes, como combate montado, elemental que evolui e
duas armas de duas mãos.

> **Quick reference** — Layer: `Feature` · Priority: `Full Vision (Ato II)` · Key deps: `Progression, Bosses, Combat & Skills, RaidSystem, WorldState, Party/Bot AI`

## Overview

**O que é.** Uma expansão de conteúdo e progressão: o nível máximo passa de 30 para 45, um continente novo entra no mapa do
mundo pelo cais do Bastião, e o jogo ganha um inimigo com identidade própria — uma Horda organizada em linhas de unidades que
evoluem (recruta → guerreiro → senhor da guerra; filhote de troll → troll → lança-pedras; ginete de lobo → saqueador → ginete do
lobo atroz; arqueiro → besteiro → arco de fogo; assassino goblin → matador; lanceiro goblin → empalador → agitador), mais as
nagas da costa.

**Como o jogador vive isso.** Chega de navio a uma colônia sitiada, ajuda a defendê-la das investidas de ginetes, empurra a
Horda costa adentro, toma os três acampamentos de guerra das estepes um por um e termina numa raide de cinco pessoas contra o
Grão-Senhor na cidadela da montanha. **Cada missão principal muda o cenário** (regra do Ato I: `WorldState` lido de
`quests_completed`): investidas ficam menores ou maiores, colonos ocupam o que foi retomado, NPCs novos aparecem, rotas se
abrem. As **missões paralelas também crescem**: começam como pedidos pequenos de um morador e viram cadeias que mudam um
lugar (o farol aceso traz navios e um mercador; os desertores ajudados viram um acampamento aliado; os escravos libertados
viram ferreiros). No meio do caminho, cada classe faz a sua **missão de ascensão** e ganha uma mecânica nova que muda o jeito
de jogar em grupo.

**Por que existe.** O Ato I terminou com o mundo salvo e nada para fazer além de farmar. O jogo é de grupo e o foco é a IA dos
bots: o Ato II dá um inimigo que pede grupo (bandos com líder, aura de agitador, trolls que regeneram, assassinos que pegam
quem fica para trás), chefes que já escalam com o número de pessoas, e ascensões que dão a cada papel uma ferramenta nova de
grupo. Sem ele, o progresso de build para no 30 e as builds novas (montado, elemental evoluído, titã) não têm onde existir.

**Fora de escopo deste documento**: fórmulas de dano e de atributos (`combat-skills.md`), regras gerais de chefe
(`bosses.md`), curva de XP do Ato I (`progression.md` — este documento só estende as faixas).

## Detailed Design

### Core Rules

#### R1. Chegada e travessia
1. O cais fica no lado leste do Bastião (`field_ruins`), hoje sem saída. O **Capitão Bren** (NPC do cais) oferece "Zarpar para
   Kharzun" como portal-NPC para `city_port`.
2. Portão de progressão (`MapsCatalog.PORTAL_GATES`): nível 30 e a missão `dw_epilogue` concluída. A volta (navio de chegada
   no cais de Porto Esperança → Bastião) não tem portão.
3. Bots usam o mesmo portal (`PortalSystem.portal_towards` / `BotBrain._find_portal`) e escolhem caçar em Kharzun pelo
   `MapDef.level_range` dos mapas novos, como hoje.
4. O cristal de retorno de Porto Esperança (`role: crystal`) pode ser vinculado; G leva ao ponto vinculado (regra do Ato I).

#### R2. Faixas, mapas e o que cada um tem
| Faixa | Campo | Hub | Masmorra / forte | Chefes (grupo, com reforço por pessoas) |
|---|---|---|---|---|
| 30–35 | `field_coast` — Costa Partida | `city_port` — Porto Esperança | `dg_goblin` — Grutas Goblin (3 salões + selo) | Mãe das Marés (naga, campo), Agitador-Mor (grutas) |
| 35–40 | `field_steppe` — Estepes de Cinza | Posto da Caravana (dentro do campo, muralha de carroças) | `fort_trolls`, `fort_fire`, `fort_war` (acampamentos de guerra, conquistáveis) | Troll Rei-da-Rocha, Mestre Besteiro, Senhor da Guerra Ghar |
| 40–45 | `field_kharzun` — Monte Kharzun | (acampamento avançado da Aurora no sopé) | `dg_slayers` — Salão dos Matadores; `kharzun_citadel` — a cidadela | Mestre Matador, três Chefes de Clã (cidadela), **Grão-Senhor da Guerra** (raide de 5) |

Toda zona segue o layout do Ato I (vale ~240 m, hub, 3–5 POIs a 60–120 m, estradas curvas, marco visível de qualquer
ponto, borda natural) e os quatro tipos de lugar por zona (`_check_places`: cabana com NPC, acampamento, santuário, entrada
de masmorra). Os POIs de cada zona são os do plano: Costa = Praia dos Naufrágios, Aldeia Goblin de Palafitas, Falésias dos
Ninhos, Acampamento dos Ginetes, Santuário Afogado (marco: o farol); Estepes = os três acampamentos, Cemitério dos Mamutes,
Acampamento dos Desertores (marco: o Totem Partido); Kharzun = Minas de Escravos, Canil dos Lobos Atrozes, Forja Negra, Salão
dos Matadores, Portão da Cidadela (marco: a cidadela no pico).

#### R3. A Horda — linhas de evolução
Cada linha tem 2–3 estágios em faixas crescentes; o estágio de cima sempre aparece **liderando** os de baixo (escolta,
`MonsterDef.escort`) — o grupo aprende a matar o líder ou a aguentar o bando.

| Linha | Estágios (nível) | Faixa | Papel | Mecânica própria |
|---|---|---|---|---|
| Goblins | Lanceiro Goblin (30) → Empalador (33) → **Agitador** (36) | 30–40 | bando barato / estocada que atravessa | o Agitador dá **aura** de dano e velocidade aos aliados perto; morto, o bando desanima (perde a aura) |
| Ginetes | Ginete de Lobo (31) → Saqueador (35) → Ginete do Lobo Atroz (41) | 30–45 | rápidos, flanqueiam quem cura/atira | Saqueador joga **rede** (prende); são o grosso das investidas |
| Orcs | Recruta Orc (32) → Guerreiro Orc (37) → Senhor da Guerra (42) | 30–45 | corpo a corpo pesado | o Senhor lidera escolta e dá grito de guerra (buff do bando) |
| Trolls | Trollzinho (35) → Troll (38) → Lança-Pedras / Brutamontes (41) | 35–45 | tanques inimigos | **regeneração** de vida; fogo e veneno cortam a regeneração enquanto queimam |
| Arqueiros | Arqueiro Orc (35) → Besteiro (38) → Arco de Fogo (42) | 35–45 | à distância | chuva de flechas de fogo em círculos avisados (`barrage`) |
| Assassinos | Assassino Goblin (40) → Matador (43) | 40–45 | caçadores de quem fica isolado | **somem** (furtividade simples) e aparecem pelas costas com faca envenenada |
| Nagas | Naga das Marés (31) → Guerreira Naga (34) | 30–35 | costa | puxam para a água, golpe em linha |

#### R4. Cenários que crescem com as missões (o coração do Ato II)
Cada zona tem **estágios** lidos de `quests_completed` (`WorldState`): monstros, NPCs, investidas e passagens mudam quando
a missão que os controla é concluída — sem campo novo no save. As cadeias paralelas também mexem no mundo. O detalhe por
zona está em States and Transitions.

#### R5. Missões
- **Linha principal**: 8–10 missões por faixa (padrão do Ato I), cada uma mudando o cenário ao terminar.
- **Paralelas que crescem**: toda cabana/acampamento abre uma cadeia de 2–4 missões; a última muda o lugar (NPC novo, serviço
  novo, aliado, montaria). As do plano: Costa — *O Farol Apagado*, *Náufragos*, *Pérolas das Marés*, *Goblin Comerciante*
  (Nikki), *O Diário do Capitão*, quadro de caçadas da taverna; Estepes — *A Caravana*, *Os Desertores* (escolha: ajudar ou
  entregar — muda NPC e recompensa), *Marfim de Mamute*, *Totem dos Ventos*, *Corrida dos Lobos*; Kharzun — *Correntes
  Quebradas*, *O Ferreiro Anão*, *Ecos da Noite* (gancho do Ato III), *Ovos do Lobo Atroz* (montaria lobo atroz).
- **Ascensão de classe**: uma missão por classe aos 35 (na Costa), com mestre próprio no porto; refinamentos aos 40 e 45 pelas
  linhas de talento novas.
- XP de missão segue `QuestsCatalog.scale_xp` (40–50% da faixa, 10+ missões por faixa — checks existentes).

#### R6. Ascensões de classe (35 / 40 / 45)
A missão de ascensão (35) libera a mecânica-assinatura da classe para **todas as builds** dela; aos 40 e 45 chegam linhas de
talento novas (`class_talents_catalog.gd`, 3 escolhas por linha, cada uma pensada para uma das 3 builds, sem trava) e nós novos na teia. Toda ascensão
tem uso pelos bots (`BotBrain`; alvo: bot ascendido usa a ascensão ao menos 1× em 60 s de luta contra chefe) — sem isso ela não entra.
| Classe | Ascensão (35) | Regra principal | 40 / 45 (refinos por build) |
|---|---|---|---|
| Paladino | **Combate Montado** | montado, o paladino ataca e usa skills marcadas como montáveis; básico do alto (alcance maior), **Carga Montada** (avanço longo que atropela a linha), **Pisotear** (área em volta); a aura vale montado; atordoar/prender/gancho **derruba** do cavalo | Guardião provoca montado com escudo · Cruzado com lança pesada (Carga mais longa) · Templário com estandarte (aura maior no grupo) |
| Elementalista | **Elemental que evolui e muda de forma** | o elemental (um por vez, regra atual) ganha **experiência** com abates feitos perto do mago e evolui: Básico → **Maior** (35) → **Ancestral** (40/45); o mago **troca a forma** entre fogo/gelo/raio sem perder o estágio; cada forma tem skills e um **modo** (atacar, proteger, apoiar) | Fogo: Salamandra → Ifrit (área) · Gelo: Golem de Gelo → Ondina (escudo no grupo) · Raio: Silfo → Tempestade (velocidade) |
| Berserker | **Empunhadura de Titã** | pode equipar **arma de duas mãos também na mão secundária** (só machado de 2 mãos, as builds de machado); golpe duplo, penalidade de velocidade de ataque que a teia reduz | Gêmeos: os dois machados giram juntos · Carniceiro/Executor: execução com o segundo machado |
| Bispo | **Santuário** | área no chão: ninguém do grupo dentro **morre** por alguns segundos (vida para em 1) + **ressurreição em combate** (uma por aliado por luta; ver F9) | Sacerdote: santuário maior · Iluminado: santuário fere mortos-vivos/orcs · Batalha: ressurreição com escudo |
| Druida | **Forma Ancestral** | terceira forma por build: Urso → **Ent** (raízes, provoca em área); Lobo → **Lobo Alfa** (chama a matilha); Xamã → espírito da tempestade | variantes de skill por forma (como Lobo/Urso hoje) |
| Ranger | **Companheiro Evoluído** | Caçador: lince → **Tigre Dente-de-Sabre**; Atirador: **torreta** de campo (armadilha que atira); Lanceiro: arremesso que salta | tigre com investida · torreta dupla · salto que provoca |
| Assassino | **Sombras Gêmeas** | **clone de sombra** que repete seus golpes por alguns segundos + **execução** (dano enorme em alvo abaixo de 25%) | Duelista: contra-ataque em cadeia · Corsário: canhão de mão |
| Necromante | **Senhor dos Mortos** | limite de invocações maior + **Forma de Lich** temporária (nova forma, como fantasma/demônio) com magias amplificadas | Invocador: exército · Ceifador: lich corpo a corpo · Sombras: lich das maldições |

#### R7. Progressão estendida
- Nível máximo **45**. XP por nível segue a mesma fórmula (Formulas F1); três faixas novas em `XP_BANDS` e `XP_QUEST_SHARE_BAND`.
- Teia: `points_at` continua 8 por nível, com **+1 ponto uma vez** ao chegar no 40 (`points_at(40)` = 9, como no 10/20/30); nós novos para as ascensões.
- Talentos de classe: linhas novas aos **35, 40, 45** (hoje 6 linhas de 5 a 30).
- Equipamento comum: tiers novos aos **32 e 40** (`COMMON_TIER_LEVELS`), pelos laços de `gear_catalog.gd`.
- Lendários: níveis **35, 40, 45** (`LEGENDARY_LEVELS`) — 24 builds × 3 = 72 conjuntos, nomes pela regra (`set_piece_name`);
  na fatia 1 o visual reaproveita o conjunto de nível 30 da build com paleta nova, modelos próprios no polimento.
- Moedas Lendárias, Relicária e aprimoramento +1..+9 seguem iguais; preço em moedas continua `índice do tier + 1`.

#### R8. Loops de qualidade (decisão do autor: "use loops para garantir qualidade")
Nada fecha sem passar pelo loop medido da sua categoria:
- **Zona**: `/layout-zone` até nota ≥ 8 nos 5 critérios (máx. 6 iterações), depois tour de screenshots no jogo.
- **Faixa**: `band_probe --from --to` com 0 `travou` e tempo médio por abate a ±25% da média da faixa 20–30 do Ato I.
- **Chefe**: `boss_probe --comp` (40 lutas) — grupo completo de 4 vence ≥ 95% com 0,3–1 morte por luta; grupo de 4 sorteado vence 65–85%; o solo é só observado (alarme, sem alvo).
- **Investida/conquista**: `raid_probe` sem `presos`, repelida pela defesa do porto com bots.
- **Ascensão**: build com e sem a ascensão no `boss_probe --comp` e no `combat_probe` (0 FLAG); o ganho entra no orçamento de F5.
- **Desempenho**: `sim_probe` ≤ 5 ms/tick em média com Kharzun carregado (regra do projeto) e o porto em investida com 10+ bots sem trecho < 25 FPS no `PerfWatch`.
- **Missões**: auditoria do `band_probe` (XP 40–50% da faixa), checks de cadeia (pré-requisitos, NPCs existem).

### States and Transitions

Estágios de cada cenário (lidos de `quests_completed` pelo `WorldState`; cada linha é "o que muda quando a missão termina").

**Costa Partida / Porto Esperança**
| Estágio | Gatilho (missão concluída) | O que muda |
|---|---|---|
| C0 Cerco | chegada | porto com paliçada meio feita, investida de ginetes a cada 240 s (±20%), praia e mangue cheios de goblins, farol apagado |
| C1 Muralha | `hx_palisade` (ajudar a fechar a paliçada) | portões de terra prontos, sentinelas no muro, investidas maiores mas param no portão |
| C2 Farol | `hx_lighthouse` (paralela, *O Farol Apagado*) | farol aceso (luz visível), 2º navio no cais, mercador de importados |
| C3 Ginetes quebrados | `hx_riders_camp` (destruir o Acampamento dos Ginetes) | investida vira patrulha pequena; colonos montam fazenda no lugar do acampamento |
| C4 Grutas | `hx_goblin_boss` (Agitador-Mor) | Aldeia de Palafitas vira mista: goblins comerciantes (Nikki) e moradores; passagem para as Estepes abre |

**Estepes de Cinza**
| Estágio | Gatilho | O que muda |
|---|---|---|
| E0 Terra de ninguém | chegada ao Posto da Caravana | três acampamentos de guerra ativos, investidas sobre o Posto vindas dos três lados |
| E1/E2/E3 Acampamento retomado | `hx_fort_trolls` / `hx_fort_fire` / `hx_fort_war` (qualquer ordem) | o acampamento vira posto aliado (prisioneiros → colonos, ferreiro de campo), a frente dele para de mandar investida, as restantes ficam mais fortes (regra do Bastião, `RAID_RECLAIM_MULT`) |
| E4 Desertores | escolha em *Os Desertores* | ajudou: acampamento aliado com mercador orc e montaria de lobo à venda; entregou: recompensa em ouro/moedas e o acampamento some |
| E5 Caminho da montanha | os 3 acampamentos | passagem para Monte Kharzun abre; a Horda recua para a montanha |

**Monte Kharzun**
| Estágio | Gatilho | O que muda |
|---|---|---|
| K0 Sopé | chegada | acampamento avançado da Aurora, Minas e Forja controladas pela Horda |
| K1 Correntes | `hx_mines` (*Correntes Quebradas*) | escravos libertados viram ferreiros (o Ferreiro Anão melhora lendários 40+) e aliados que lutam no acampamento |
| K2 Portão | `hx_citadel_gate` | cidadela abre (portão de progressão) |
| K3 Clãs | os três Chefes de Clã | sala do trono abre |
| K4 Fim do Ato II | `hx_warlord` | Grão-Senhor cai; a Horda se rende em parte (festival no porto, como o do Bastião), *Ecos da Noite* revela o que vem do leste; tela "Fim do Ato II" |

**Ascensão (por personagem)**: `bloqueada` (nível < 35) → `disponível` (35, mestre no porto) → `concluída` (missão feita: mecânica liberada) → refinos 40/45 por talento. Conta como missão concluída (sem campo novo no save), exceto o estágio do elemental (ver Edge Cases).

### Interactions with Other Systems

| Sistema | Entra | Sai | Dono |
|---|---|---|---|
| Progression (`progression.md`) | `MAX_LEVEL` 45, faixas novas de XP, talentos 35/40/45, nós de ascensão | nível, pontos, ascensão liberada | Progression; este doc define os números das faixas novas |
| Bosses (`bosses.md`) | chefes novos com fases, `mob_pick`, `barrage`, lacaios | — | Bosses (regras); este doc define quem são e onde estão |
| Reforço por pessoas (`Balance.BOSS_CROWD_MULT`) | vale para todos os chefes novos sem mudança | — | Bosses |
| Combat & Skills (`combat-skills.md`) | skills das ascensões, regen/aura/furtividade de monstro | dano, cura, estados | Combat |
| `RaidSystem` + `GuardBrain` | rotas de investida das zonas novas, `MapsCatalog.RAIDS` | ondas, defesa | Raid (sem mudança de regra) |
| `WorldState` | condições `if`/`unless` de missão nos spawners/NPCs/investidas novos | estágios da zona | WorldState (sem mudança de regra) |
| Party / IA de bots | papéis, posição, cura; **uso das ascensões** e leitura das mecânicas novas (aura do Agitador = alvo prioritário, troll = foco com fogo/veneno, assassino = proteger quem cura) | comandos dos bots | BotBrain |
| Itens / Relicária | tiers 32/40, lendários 35/40/45, montaria lobo atroz | — | Gear |
| Save | ascensões e cenários por `quests_completed`; estágio/forma do elemental é campo novo (`save_version`) | — | SaveSystem |
| Música / Som | temas por mapa novo (`Music.MAP_THEME`), sons de orc/troll/lobo | — | Audio |

## Formulas

> Proposta do `systems-designer` (2026-11-10), baseada em `data/balance.gd`, `aura_system.gd` e nos monstros 20–30 de
> `monsters_catalog.gd`; decisões do autor marcadas. **(H)** = hipótese sem base no código, calibrar com as sondas.
> Toda constante nova vive só em `data/balance.gd`.

### F1. XP para o próximo nível (31–45) — decisão: **achatar**
A fórmula do Ato I continua (`progression.md` 3.1); só o tempo planejado por nível cresce mais devagar depois do 30.

`level_minutes(L) = XP_MIN_BASE + XP_MIN_PER_LEVEL × (L − 1)` se L < 30; `level_minutes_act1(30) + XP_MIN_PER_LEVEL_ACT2 × (L − 30)` se L ≥ 30, onde `level_minutes_act1(30)` = 6,5 + 1,75 × 29 = 57,25 (derivado, não constante)
`xp_for_level(L) = round10( level_minutes(L) × XP_KILLS_PER_MIN × mob_xp(L) ÷ (1 − XP_QUEST_SHARE) )`, 0 em `MAX_LEVEL` (45)

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| L | int | 30–44 | argumento | nível atual |
| XP_MIN_PER_LEVEL_ACT2 | float | 0.75 | data file | crescimento do tempo por nível depois do 30 (Ato I: 1.75) |
| mob_xp(L) | float | 141–204 | `6 + 4.5 × L` | XP de um monstro comum do nível |
| XP_KILLS_PER_MIN, XP_QUEST_SHARE | float | 3, 0.45 | data file | iguais ao Ato I; o divisor usa sempre o `XP_QUEST_SHARE` fixo (0,45) — o `XP_QUEST_SHARE_BAND` só escala a XP das missões (`scale_xp`) |

**Output Range:** 30→31 ≈ 44 030; 44→45 ≈ 75 mil. Faixas de ~4,9 h / 5,2 h / 5,5 h (Ato II ≈ 16 h; com a fórmula sem
achatar seriam 5,1 / 5,8 / 6,5 h).
**Example:** L = 34 → minutos 60,25; mob 159; 60,25 × 3 × 159 ÷ 0,55 = 52 252 → **52 250**.
Faixas novas: `XP_BANDS += [[30,35],[35,40],[40,45]]`, `XP_QUEST_SHARE_BAND += {30: 0.55, 35: 0.55, 40: 0.5}` **(H)**.
XP por papel: comum ×1,0 · bruto ×1,7 · elite `ELITE_XP_MULT` (6) · chefe ~×22 (Lich nível 30 = 3200 ≈ 22,7×) · escolta/lacaio 0.

### F2. Atributos dos monstros 30–45
`stat(papel, L) = ANCHOR30[papel][stat] × (1 + k_stat × (L − 30)) × mod_unidade[stat]`; DEF é somada: `def30 + d_def × (L − 30)`.

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| ANCHOR30 | tabela | ver abaixo | data file | valores no nível 30 por papel, tirados dos monstros 22–30 |
| k_hp | float | 0.065 | data file | HP ×1,975 no 45 |
| k_atk | float | 0.04 | data file | ATK ×1,6 no 45 |
| d_def | float | 1.8 (comum 0.8) | data file | DEF por nível |
| mod_unidade | dict | hp/atk ×0,6–2,0 | data file (catálogo do monstro) | ajuste por unidade sobre o papel (ex.: troll `hp` ×1,8; goblin `hp` ×0,7) |

| Papel | HP 30 | ATK 30 | DEF 30 | Base no Ato I |
|---|---|---|---|---|
| comum | 720 | 60 | 12 | carniçal 22 (560/44), morcego 26 (ATK 66) |
| bruto | 1200 | 88 | 38 | horror/cavaleiro da cidadela 29 (1100–1150, 74–84) |
| elite | 3600 | 75 | 42 | cavaleiro-guarda 27 (3200/62/38) |
| chefe | 90 000 | 100 | 34 | Azhar 30 (88 mil), Senhor da Cripta |

**Output Range:** comum 45 = 1422 HP / 96 ATK; chefe 45 = 177 750 HP / 160 ATK, multiplicado por `BOSS_CROWD_MULT` como hoje.
O poder do jogador sobe ~×2 de 30 a 45 (ATK base ×1,43 × equipamento ×1,44) **(H)**: conferir com as sondas.
**Example:** Troll (bruto, tanque ×1,8 de HP) nível 38: HP 1200 × 1,52 × 1,8 = **3283**; ATK 88 × 1,32 = **116**; DEF 38 + 14,4 = **52**.

### F3. Regeneração do troll
`regen_por_s = TROLL_REGEN_PCT × max_hp`, zero enquanto queima ou está envenenado e por `TROLL_REGEN_LINGER` s depois.
Tempo efetivo para matar: `TTK_ef = T ÷ (1 − r × T)` (só vale com r × T < 1; acima disso o troll não morre).

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| TROLL_REGEN_PCT (r) | float | 0.015 | data file | fração da vida por segundo |
| TROLL_REGEN_LINGER | float | 2.0 s | data file | regeneração parada depois do fogo/veneno |
| T | float | s | `max_hp ÷ dps` | tempo para matar sem regeneração |

**Output Range:** o grupo precisa de DPS acima de `r × max_hp` (abaixo disso o troll não morre: armadilha para build fraca sozinha).
**Example:** grupo de 4 com T = 10 s → r × T = 0,15 → TTK **11,8 s** (+18%); com fogo ou veneno, 10 s. Build fraca sozinha, T = 33 s → **66 s** **(H)**.

### F4. Aura do Agitador
Mesmo ritmo do `AuraSystem` (pulso 0,5 s, dura `AURA_KEEP` 1,3 s), com receptores por facção (os de hoje são só grupo/invocações).

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| AGITATOR_RADIUS | float | 10 m (chefe 14) | data file | raio da aura |
| AGITATOR_AURA | dict | atk_pct 20 (chefe 30), aspd_pct 10, speed_pct 10 | data file | buff dos aliados perto |
| AGITATOR_DEMORALIZE | dict | atk_pct −15, speed_pct −10, 8 s, 12 m | data file | debuff nos aliados quando ele morre |

**Output Range:** várias auras não somam (renovam pelo id); some 1,3 s depois de o Agitador morrer ou de o aliado sair do raio.
**Example:** Guerreiro Orc nível 37, ATK 88 × 1,28 = 112,6 → com a aura **135**; depois da morte do Agitador, 95,7 por 8 s.

### F5. Orçamento de poder da ascensão — decisão: **+20% no total**
`ganho(tier) = ASC_GAIN[tier]`, `ASC_GAIN = [0.08 (35), 0.06 (40), 0.06 (45)]`, aplicado por `ASC_BUILD_POWER[build]` (padrão 1,0,
mesmo padrão de `BUILD_POWER`).

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| ASC_GAIN | array | 0.06–0.08 | data file | ganho por tier |
| razão | float | 1,06–1,10 (35), ≤ 1,215 (45, multiplicativo: 1,08 × 1,06 × 1,06) | `boss_probe --comp` | tempo do grupo de 4 sem ÷ com a ascensão |

**Output Range:** o ganho de cada build (razão − 1, em pontos percentuais) a ±3 p.p. da média das 24; `combat_probe` 0 FLAG; sempre
abaixo de um terço do ganho da teia (ATK ×1,3–1,5). Ascensões de utilidade (Bispo, Necromante, Druida) são medidas sob pressão
(`boss_probe --comp --dmg=6`): o ganho é a queda relativa de mortes por luta com/sem a ascensão, com o mesmo alvo (6–10% aos 35).
**Example:** Gêmeos mata o chefe em 100 s sem a Empunhadura de Titã e em 92 s com ela → razão **1,087**, dentro da faixa.

### F6. Evolução do elemental
`elem_xp += max(1, xp_do_abate ÷ mob_xp(nível_do_monstro))` por abate **que dá XP** (escolta e lacaio com 0 XP não contam) a até `ELEM_XP_RADIUS` do mago; teto `ELEM_XP_MAX` (400).

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| ELEM_XP_RADIUS | float | 13 m | data file | igual ao alcance de assistência das invocações |
| ELEM_STAGE_XP | array | [120 Maior, 400 Ancestral] | data file | limiares acumulados (~40 min e ~2,2 h no ritmo solo) |
| ELEM_STAGE_MULT | tabela | ver abaixo | data file | multiplicadores do estágio |
| ELEM_SWAP_CD | float | 20 s | data file | recarga da troca de forma (mantém estágio e % de vida) |
| ELEM_DEATH_LOSS | float | 0.10 | data file | parte do `elem_xp` perdida se o elemental morre **(H)** |

| Estágio | HP | ATK | Área |
|---|---|---|---|
| Básico | ×1,0 | ×1,0 | ×1,0 |
| Maior | ×1,6 | ×1,4 | ×1,15 |
| Ancestral | ×2,4 | ×2,0 | ×1,3 |

**Output Range:** `elem_xp` 0–400. O ATK de invocação já é limitado (`SUMMON_ATK_MAX` 2,5): o multiplicador do estágio vem
**depois** do limite, senão some no 35+.
**Example:** 30 comuns nível 36 (1 cada) + 2 chefes (22 cada) = **74** → ainda Básico.

### F7. Empunhadura de Titã
`razão_dps = (1 + TITAN_OFFHAND_MULT) × (1 − (TITAN_ASPD_PEN − TITAN_WEB_RELIEF × n))`, n = nós da teia (0–3).

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| TITAN_OFFHAND_MULT | float | 0.45 | data file | dano da 2ª arma de 2 mãos (a mão secundária comum usa 0,6; a de 2 mãos tem mais ATK) **(H)** |
| TITAN_ASPD_PEN | float | 0.25 | data file | perda de velocidade de ataque |
| TITAN_WEB_RELIEF | float | 0.03 | data file | quanto cada nó da teia devolve |

**Output Range:** 1,0875 com n = 0 (+8,75%, bate com F5) até 1,218 com n = 3; nunca passa de +25%.
**Example:** machado de 2 mãos com 100 de DPS sozinho → **108,75** sem nós, **121,8** com 3 nós.

### F8. Combate montado (Paladino)
| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| MOUNT_FIGHT_SPEED_MULT | float | 1.3 | data file | velocidade montado em combate (fora de combate continua `MOUNT_SPEED_MULT` 1,7) |
| MOUNT_REACH_BONUS | float | 0.8 m | data file | alcance a mais do básico montado |
| MOUNT_CHARGE_DIST | float | 11.2 m (`DASH_DISTANCE` × 3,5; lança pesada ×1,3) | data file | distância da Carga Montada; para em parede/água |
| MOUNT_CHARGE_POWER / CD | float | 1.6 × ATK / 14 s | data file | **(H)** |
| MOUNT_TRAMPLE | dict | raio 3,5, poder 0,9, recarga 8 s | data file | Pisotear **(H)** |
| MOUNT_CC_IMMUNE | float | 2 s | data file | imune a controle depois de cair (evita atordoar em cadeia) **(H)** |

Derrubam: atordoar, prender, gancho. Lentidão não derruba. Remontar leva `MOUNT_CAST_TIME` (1,5 s).
**Example:** paladino a 5,5 m/s a pé → **9,35** montado fora de combate, **7,15** montado em combate.

### F9. Santuário e ressurreição em combate (Bispo)
| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| SANCTUARY_TIME / RADIUS / CD | float | 6 s / 6 m (Sacerdote 8) / 45 s | data file | dentro, a vida do grupo não cai abaixo de 1 (dano no tempo também não mata) |
| RES_HP_PCT / CAST / RANGE / CD | float | 0,35 / 2,5 s / 15 m / 120 s | data file | ressurreição em combate, uma por aliado por luta **(H)**; "luta" = do primeiro golpe num chefe até ele morrer ou resetar (`reset_boss`); fora de chefe, até o `combat_timer` do grupo zerar |
| RES_BATTLE_SHIELD | float | 0,20 do HP por 6 s | data file | refino do Clérigo de Batalha |

**Output Range:** santuário cobre ~13% de um ciclo de 45 s; como o reforço do chefe chega a ×5, 6 s é o teto antes de trivializar.
**Example:** chefe tirando 30% da vida por segundo do grupo → todos ficam em 1 de vida por 6 s; o Bispo cura nos 6 s seguintes.

### F10. Equipamento 35/40/45 — decisão: **moedas sem mudança (7/8/9)**
`gear_factor(L) = (L + 4) ÷ 28` (linear, já existe) → 30: 1,214 · 35: 1,393 · 40: 1,571 · 45: 1,75. `LEGENDARY_MULT` 1,2 igual.
`LEGENDARY_LEVELS += [35, 40, 45]` (índices 6, 7, 8); `COMMON_TIER_LEVELS += [32, 40]`.
Bônus percentuais de conjunto acima do índice 5 crescem pela metade, para não somar demais com a ascensão:
`i_ef = min(i, 5) + 0,5 × max(0, i − 5)` e `bônus% = base + por_tier × i_ef` (com `base`/`por_tier` atuais de `Balance.SET_*`) →
4 peças 42/44/46% de dano de skill (Ato I: 40%), 5 peças 17/18/19%, recarga 21/22/23% (valores conferidos por check).
Atributos continuam lineares. Preço em moedas `i + 1` = **7 / 8 / 9** (decisão do autor: o lendário do Ato II é objetivo de longo prazo).

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| L | int | 32–45 | catálogo | nível do item |
| i | int | 6–8 | `LEGENDARY_LEVELS` | índice do tier lendário |
| i_ef | float | 5,5–6,5 | calculado | índice efetivo dos bônus percentuais |

**Example:** lendário nível 40: fator de atributo 1,571 × 1,2 = **1,89** do item base 24; custa **8 moedas**.

## Edge Cases

> `systems-designer` não consultado nesta seção — modo lean. Revisar antes da produção.

**Travessia e progressão**
- **Se o jogador tem nível 30 mas não concluiu `dw_epilogue`**: o capitão recusa com o texto do portão ("Termine o que começou em Aldara").
- **Se um save do Ato I (nível 30, XP 0) carrega com o cap novo**: o personagem continua no 30 com XP 0 e passa a ganhar XP normalmente; não recebe pontos retroativos.
- **Se um bot de nível < 30 está no grupo do jogador que zarpa**: o portão vale só para o jogador (regra atual); o bot segue o líder, mas não escolhe Kharzun sozinho para caçar (fora do `level_range`).
- **Se o jogador volta ao Bastião no meio do Ato II**: tudo do Ato I continua como estava; o estágio das zonas de Kharzun não muda sem ele.

**Cenários que crescem**
- **Se a missão que muda o estágio é concluída com o jogador em outro mapa**: o estágio vale na próxima vez que o mapa carregar (WorldState lê `quests_completed` ao montar spawners/NPCs).
- **Se monstros de um estágio antigo estão vivos quando o estágio muda**: eles ficam até morrer ou até o mapa recarregar; nascimentos novos seguem o estágio novo (sem sumir monstros na frente do jogador).
- **Se os três acampamentos são retomados fora de ordem**: qualquer ordem vale; a última frente ativa recebe o reforço da regra do Bastião (`RAID_RECLAIM_MULT`, ×2 e líder).
- **Se o jogador entrega os Desertores**: o acampamento aliado nunca aparece; a montaria de lobo continua disponível pelos *Ovos do Lobo Atroz* em Kharzun (nenhum conteúdo fica inacessível por causa da escolha).

**Horda**
- **Se o Agitador morre com o aliado fora do raio**: o aliado não recebe o desânimo (só quem está a 12 m na hora).
- **Se dois Agitadores cobrem o mesmo orc**: a aura não soma (mesmo id renova); matar um não tira a aura do outro.
- **Se o troll está queimando e envenenado ao mesmo tempo**: a regeneração para uma vez só; volta 2 s depois do último efeito acabar.
- **Se o DPS do grupo é menor que a regeneração do troll**: o troll não morre; ele não reseta enquanto houver alguém em combate (o grupo precisa de fogo/veneno ou sair). Bots com fogo/veneno priorizam o troll.
- **Se o assassino some com a vida baixa**: a furtividade não cura; ele reaparece pelas costas de quem cura/atira (alvo `soft`), nunca do tanque.
- **Se a rede do Saqueador pega alguém montado**: derruba do cavalo (é "prender").

**Ascensões**
- **Se o Paladino montado é atordoado**: cai, fica 2 s imune a controle, e remontar leva 1,5 s.
- **Se o Paladino tenta montar dentro de masmorra**: proibido (regra atual de montaria); a ascensão vale onde montar vale.
- **Se o elemental morre**: perde 10% do `elem_xp` mas nunca cai de estágio (o estágio só sobe).
- **Se o mago troca de forma com o elemental ferido**: a nova forma nasce com a mesma % de vida; recarga 20 s.
- **Se o save é de antes do Ato II**: `elem_xp` = 0, forma = a do último elemental; `save_version` sobe e a migração preenche o padrão.
- **Se o Berserker sem ascensão tenta pôr arma de 2 mãos na secundária**: recusa com "requer Empunhadura de Titã"; se perder o acesso (respec não tira ascensão, então não acontece), a arma volta para a bolsa.
- **Se dois Santuários se sobrepõem**: não somam; vale o maior tempo restante.
- **Se alguém morre no exato tick em que o Santuário termina**: o Santuário vale até o fim do tick (dano aplicado antes da expiração no mesmo tick é segurado em 1).
- **Se a ressurreição em combate é usada em quem já foi ressuscitado nesta luta**: recusa ("já voltou nesta luta").
- **Se o chefe tem golpe de execução ou fúria final**: o Santuário segura em 1, mas a regra do chefe pode furar (decisão por chefe em `bosses.md`, nunca global).
- **Se o clone de sombra recebe aggro**: o clone não segura aggro (monstros o ignoram); ele some ao fim do tempo ou se o dono morrer.
- **Se a Forma de Lich termina com mais invocações que o limite normal**: as que passam do limite somem da mais antiga para a mais nova.

## Dependencies

**Depende de (upstream)**
| Sistema | Tipo | Interface |
|---|---|---|
| Progression (`progression.md`) | **forte** | nível máximo, curva de XP, teia, talentos de classe; o Ato II estende as faixas e as linhas de talento |
| Bosses (`bosses.md`) | **forte** | fases, `mob_pick`, `barrage`, `berserk_after`, reforço por pessoas (`BOSS_CROWD_MULT`) |
| Combat & Skills (`combat-skills.md`) | **forte** | skills das ascensões, estados (prender, atordoar, queimar, envenenar), formas, invocações |
| `WorldState` (core/sim/systems/world_state.gd) | **forte** | estágios dos cenários por `quests_completed` |
| `RaidSystem` / `GuardBrain` | **forte** | investidas no porto, nas estepes e defesas |
| Party + IA dos bots (`BotBrain`, `PartySystem`) | **forte** | bots seguem, defendem, usam ascensões e leem as mecânicas novas |
| Pipeline de zonas (`tools/blender/zones/`, `places.py`, `build_dungeons.py`) | **forte** | mapas, colisão, lugares, masmorras |
| Gear (`gear_catalog.gd`, Relicária) | **forte** | tiers comuns e lendários novos |
| Montaria (H, cavalo) | **forte para o Paladino** | combate montado parte do estado montado que já existe |
| Música / Som (`Music`, `Sfx`) | fraca | temas e sons novos; sem eles o jogo roda mudo nesses mapas |

**Dependem dele (downstream)**: o futuro Ato III (gancho de *Ecos da Noite*), roteiros `docs/roteiro_30_35.md` / `35_40` /
`40_45`, os probes (`band_probe`, `boss_probe`, `raid_probe`, `web_probe --level=45`) que ganham faixas e chefes novos.

**Bidirecionalidade a corrigir**: `progression.md` e `bosses.md` ainda dizem "1 a 30" e não citam o Ato II; ao aprovar este
documento, acrescentar neles uma linha "estendido por `ato2-horda.md`".

## Visual/Audio Requirements

> `art-director` e `audio-director` não consultados — modo lean. Revisar antes da produção dos modelos.

**Leitura de cima (câmera alta, 52°)** — o que define cada zona é o chão e as manchas de cor:
- **Costa**: areia clara, mar turquesa com espuma na borda, mangue verde-escuro com palafitas marrons, paliçada de troncos
  claros (nova) contra pedra antiga da Aurora no Santuário Afogado; o farol branco com faixas é o marco.
- **Estepes**: capim dourado queimado, manchas de cinza cinzenta, rio largo azul-acinzentado, acampamentos de estacas escuras
  com estandartes vermelhos da Horda; o Totem Partido é o marco.
- **Kharzun**: rocha escura e basalto, rios de lava laranja (colidem como água), fumaça das forjas, cidadela entalhada no pico.
- **Mudança por estágio** precisa ser visível de cima: paliçada completa, farol aceso (luz), fazendas no lugar do acampamento
  dos ginetes, estandartes trocados (vermelho da Horda → branco-dourado da Aurora) nos acampamentos retomados.

**A Horda (modelos em `mob_kit`, chibi toon + contorno)**: orc = humanoide chibi com presas, pele verde-acinzentada, ombreiras
de osso/ferro escuro; **cada estágio da linha mais pesado e mais enfeitado** que o anterior (recruta de couro → guerreiro de
ferro → senhor da guerra com chifres e estandarte nas costas). Goblin = baixo, orelhas grandes, lança; o Agitador com tambor.
Troll = grande e curvado, pele cinza-azulada, pedras incrustadas; regeneração **visível** (brilho verde pulsando; some quando
queima). Ginete = lobo (`quadruped(kind="wolf")`) + goblin montado. Assassino com capuz e brilho de veneno nas facas. Naga
com cauda e escamas turquesa.

**Mecânicas que o grupo precisa ler**: aura do Agitador (anel vermelho no chão em volta dele e dos buffados), rede do Saqueador
(projétil visível + rede no alvo), chuva de flechas de fogo (círculos avisados, já existe), troll regenerando (brilho), assassino
reaparecendo (fumaça + aviso curto antes do golpe).

**Ascensões**: Paladino montado com clipes `ride_attack`/`ride_charge`; elemental com **três estágios visíveis** por forma
(tamanho, partículas e detalhe crescem); Berserker com o segundo machado de 2 mãos na esquerda (o kit já tem o nó da mão
secundária); Santuário com cúpula de luz no chão; clone de sombra semitransparente; Forma de Lich; Ent e Lobo Alfa; tigre.

**Áudio**: temas novos (CC0 do OpenGameArt, `build_music.py`, licença conferida por faixa): porto (mar, esperança tensa),
costa, estepes (tambores), Kharzun (pesado), cidadela/raide; os temas "chefe" e "investida" do Ato I valem aqui. Sons novos em
`build_sfx.py`: grito orc, tambor do Agitador (laço enquanto a aura vive), troll, uivo de lobo, rede, cavalo galopando em combate.

## UI Requirements

- **Janela do elemental** (Elementalista com ascensão): estágio atual, barra de experiência até o próximo, forma e modo, troca
  de forma (com recarga). Pode morar na janela de skills (K) ou num quadro perto da barra de vida.
- **Combate montado**: a barra de ação mostra as skills montáveis acesas e as outras apagadas enquanto montado; ícone de
  "derrubado" ao cair do cavalo.
- **Ascensão**: entrada própria na janela K (aba Talentos) com a mecânica liberada e os refinos 40/45.
- **Estágio da zona**: o L (quests/roteiro) mostra o que cada missão principal vai mudar no cenário ("ao concluir: o farol acende").
- **Escolha dos Desertores**: diálogo com duas respostas e o resumo do que cada uma faz.
- **Tela "Fim do Ato II"** (como a do Ato I em `hud.gd`).
- Nada de UI nova para regeneração/aura de monstro além do visual no corpo e da barra de buffs/debuffs que já existe.

> 📌 **UX Flag — Ato II**: este sistema tem requisitos de UI (janela do elemental, barra montada, ascensão na K). Antes das
> histórias de UI, rodar `/ux-design` para essas telas.

## Cross-References

| Este documento usa | Do documento | Seção |
|---|---|---|
| curva de XP, teia, talentos de classe, `points_at` | `design/gdd/progression.md` | 2.1, 2.2, 2.5, 3.1–3.4 |
| fases, `mob_pick`, `barrage`, `berserk_after`, reforço por pessoas | `design/gdd/bosses.md` | 2.1–2.4, 3 |
| formas, invocações, estados, dano de fogo/veneno | `design/gdd/combat-skills.md` | — |
| layout de zona (vale, hub, POIs, marco, leitura de cima) | `.claude/docs/ragnaex/zonas.md` | Layout de zonas |
| conquista por `WorldState`, investidas, fortes | `docs/DESIGN.md` / `docs/roteiro_20_30.md` | Mundo / Bastião |
| linha de foras da lei estilo Wesnoth (precedente de arquétipo) | memória outlaw-line, `mob_kit.outlaw_parts` | — |
| IA de grupo por papel, `boss_probe --comp` | `docs/DESIGN.md` | IA dos bots no combate |

## Acceptance Criteria

> Rascunho do `qa-lead` (2026-11-10), com as 11 ambiguidades que ele apontou resolvidas no texto acima. Verificação: **check** =
> `check(...)` em `tools/tests/run_tests.gd` (nomes `_check_*` abaixo são **propostos**; hoje só existem `_check_places`,
> `_check_music`, `_check_web_strength`, `_check_build_entries`, `_check_catalog_keys`) · **sonda** = comando headless com alvo ·
> **evidência** = screenshot guardado em `production/qa/evidence/`.

### Travessia / Progressão
- **AC-01 (R1)** **GIVEN** jogador nível 30 sem `dw_epilogue`, **WHEN** fala com o Capitão Bren, **THEN** não viaja e vê "Termine o que começou em Aldara"; com nível 30 e `dw_epilogue` chega em `city_port`; a volta não tem portão. — check `_check_act2_gate`.
- **AC-02 (R1)** **GIVEN** bot nível 32 sem grupo no Bastião, **WHEN** escolhe onde caçar, **THEN** usa o portal-NPC e caça num mapa de Kharzun; bot nível 28 nunca escolhe Kharzun sozinho. — check `_check_act2_bot_travel`.
- **AC-03 (R1)** **GIVEN** cristal de Porto Esperança vinculado, **WHEN** aperta G, **THEN** chega ao cristal. — check `_check_act2_gate`.
- **AC-04 (R7)** **GIVEN** `MAX_LEVEL` 45, **THEN** `xp_for_level(45)` = 0, `XP_BANDS` tem 30–35/35–40/40–45, há linhas de talento aos 35/40/45 com 3 escolhas cada e `points_at(40)` = 9 (os demais 31–45 = 8). — check `_check_act2_progression`.
- **AC-05 (F1)** **GIVEN** L = 34, **THEN** `xp_for_level(34)` = 52 250; 30→31 ≈ 44 030 (±1%); 44→45 ≈ 75 390 (±1%); `level_minutes` cresce 0,75 por nível de 30 a 44. — check `_check_act2_xp_curve`.
- **AC-06 (save)** **GIVEN** save do Ato I (nível 30, XP 0, sem `elem_xp`), **WHEN** carrega, **THEN** fica no 30 com XP 0, sem pontos retroativos, `elem_xp` = 0, forma = a do último elemental, `save_version` sobe; usa `TEST_SLOT`. — check `_check_act2_save_migration`.

### Cenários
- **AC-07 (R2)** **GIVEN** as 3 zonas novas, **THEN** cada uma tem os 4 tipos de lugar, tudo alcançável a pé, `level_range` na faixa e tema de música. — checks `_check_places`, `_check_music`.
- **AC-08 (R2/R8)** **GIVEN** cada zona, **WHEN** passa por `/layout-zone`, **THEN** nota ≥ 8 em ≤ 6 iterações. — evidência: `CAM_top`/`CAM_game`/`CAM_poi` + tour `--tour=<pasta> --tour_map=<zona>`.
- **AC-09 (R4)** **GIVEN** `quests_completed` com o gatilho de cada estágio (C1–C4, E1–E5, K1–K4), **WHEN** o mapa monta spawners/NPCs/investidas, **THEN** o conteúdo é o do estágio; sem o gatilho, o anterior. — check `_check_act2_stages` (tabela).
- **AC-10 (R4)** **GIVEN** monstros do estágio antigo vivos, **WHEN** o estágio muda, **THEN** eles ficam até morrer e os nascimentos novos seguem o estágio novo. — check `_check_act2_stages`.
- **AC-11 (WorldState)** **GIVEN** os 3 acampamentos retomados em cada uma das 6 ordens, **THEN** a frente restante recebe `RAID_RECLAIM_MULT` e líder; depois dos 3, abre a passagem para Kharzun. — check `_check_act2_forts`.
- **AC-12 (E4)** **GIVEN** Desertores entregues, **THEN** o acampamento aliado não aparece e os Ovos do Lobo Atroz continuam disponíveis. — check `_check_act2_stages`.
- **AC-13 (R4)** **GIVEN** porto em C0 e em C3, **WHEN** roda a investida, **THEN** é repelida sem `presos`, o intervalo em C0 é 240 s ±20% e a leva em C3 é menor que em C0. — sonda `raid_probe -- --trials=20 --bots=0,1,3`.
- **AC-14 (R5)** **GIVEN** cada faixa nova, **THEN** 8–10 principais, toda cabana com cadeia de 2–4, todo giver existe, XP de missão 40–50% da faixa. — checks de missão existentes + sonda `band_probe -- --from=30 --to=45 --only=audit`.

### Horda
- **AC-15 (R3)** **GIVEN** o estágio de cima de cada linha, **THEN** nasce com `escort` dos de baixo. — check `_check_horde_lines`.
- **AC-16 (F2)** **GIVEN** monstros 30–45, **THEN** HP/ATK/DEF = fórmula F2 com `mod_unidade` (±2%); Troll 38 = 3283/116/52. — check `_check_horde_stats`.
- **AC-17 (F3)** **GIVEN** troll a 50% de vida, **WHEN** passa 1 s sem dano, **THEN** cura 1,5% do HP máximo; queimando ou envenenado cura 0 até 2 s depois do último efeito. — check `_check_troll_regen`.
- **AC-18 (F4)** **GIVEN** Guerreiro Orc 37 a 10 m de um Agitador, **THEN** ATK = 135; dois Agitadores não somam; morto o Agitador, a aura some em ≤ 1,3 s, quem está a ≤ 12 m fica com ATK 95,7 por 8 s e quem está a 13 m não. — check `_check_agitator_aura`.
- **AC-19 (R3)** **GIVEN** assassino furtivo, **WHEN** reaparece, **THEN** mira quem cura ou atira, nunca o tanque, e a furtividade não cura; a rede derruba quem está montado. — check `_check_horde_ai`.
- **AC-20 (bots)** **GIVEN** grupo de bots com fogo/veneno contra troll + Agitador, **THEN** o primeiro alvo focado é o Agitador e quem tem fogo/veneno ataca o troll. — check `_check_horde_ai`.
- **AC-21 (R8)** **GIVEN** a faixa 30–45, **THEN** `band_probe` dá 0 `travou` e tempo por abate a ±25% da faixa 20–30. — sonda `band_probe -- --from=30 --to=45 --trials=16 --why`.

### Chefes
- **AC-22 (R8)** **GIVEN** cada chefe novo, **THEN** grupo completo de 4 vence ≥ 95% com 0,3–1 morte por luta e grupo de 4 sorteado vence 65–85%, com `BOSS_CROWD_MULT` sem mudança. — sonda `boss_probe -- --comp=<...> --trials=40 --boss=<id>`.
- **AC-23 (K4)** **GIVEN** `hx_warlord` concluída, **THEN** festival no porto e tela "Fim do Ato II". — check do estágio + evidência: screenshot.

### Ascensões
- **AC-24 (R6)** **GIVEN** classe nível 35 sem a missão, **THEN** a mecânica fica travada; concluída a missão, liberada em todas as builds; o respec não a tira. — check `_check_ascensions`.
- **AC-25 (R6, bots)** **GIVEN** bot ascendido de cada classe, **WHEN** luta 60 s contra um chefe, **THEN** usa a ascensão ≥ 1 vez. — check `_check_ascension_bots`.
- **AC-26 (F5)** **GIVEN** cada build com e sem a ascensão, **THEN** razão de tempo 1,06–1,10 aos 35 e ≤ 1,215 aos 45; o ganho de cada build a ±3 p.p. da média; utilidade (Bispo, Necromante, Druida) medida pela queda de mortes a `--dmg=6` no mesmo alvo; `combat_probe` 0 FLAG. — sonda `boss_probe --comp` (+ `--dmg=6`) e `combat_probe -- --class=<id>`.
- **AC-27 (F6)** **GIVEN** 30 comuns nível 36 + 2 chefes mortos a ≤ 13 m do mago, **THEN** `elem_xp` = 74 e Básico; aos 120, Maior; lacaio/escolta com 0 XP não soma; morte perde 10% sem cair de estágio; trocar de forma mantém estágio e % de vida, recarga 20 s; o ATK do estágio vem depois de `SUMMON_ATK_MAX`. — check `_check_elemental_evolution`.
- **AC-28 (F7)** **GIVEN** machado de 2 mãos com 100 de DPS, **THEN** 108,75 com n = 0 e 121,8 com n = 3; sem a ascensão, a mão secundária recusa com "requer Empunhadura de Titã". — check `_check_titan_grip`.
- **AC-29 (F8)** **GIVEN** paladino a 5,5 m/s, **THEN** 9,35 montado fora de combate e 7,15 em combate; Carga anda 11,2 m e para em parede/água; atordoar/prender/gancho derrubam, lentidão não; 2 s imune depois de cair; remontar 1,5 s; não monta em masmorra. — check `_check_mounted_combat`.
- **AC-30 (F9)** **GIVEN** grupo dentro do Santuário levando 30%/s, **THEN** ninguém cai abaixo de 1 em 6 s, nem por dano no tempo, inclusive no tick da expiração; dois Santuários não somam; ressuscitar o mesmo aliado 2× na mesma luta (até o chefe morrer/resetar) é recusado. — check `_check_sanctuary`.
- **AC-31 (R6)** **GIVEN** clone de sombra, **THEN** monstros não o miram e ele some com o dono; execução vale abaixo de 25%; o fim da Forma de Lich remove o excesso de invocações da mais antiga para a mais nova. — check `_check_ascensions`.

### Equipamento
- **AC-32 (F10)** **GIVEN** lendários 35/40/45, **THEN** 72 conjuntos, fator 40 = 1,89, preço 7/8/9 moedas, 4 peças 42/44/46%; tiers comuns aos 32 e 40. — checks `_check_act2_gear` + `_check_build_entries`.
- **AC-33** **GIVEN** lendário 40+, **WHEN** K1 está ativo, **THEN** o Ferreiro Anão aprimora a peça. — check `_check_act2_stages` + evidência `--bag_shot=<png> --wins= --enhance`.

### Desempenho / Qualidade
- **AC-34** **GIVEN** testes completos + `--autostart` com classe ascendida, **THEN** 0 failed e 0 `SCRIPT ERROR`.
- **AC-35** **GIVEN** kits com as peças novas, **THEN** cada kit < 200 malhas. — check existente.
- **AC-36** **GIVEN** Kharzun carregado e o porto em investida com 10+ bots, **THEN** `sim_probe` ≤ 5 ms/tick em média e nenhum trecho < 25 FPS no `PerfWatch`. — sondas `sim_probe -- --phases` e `--perf --perf_at=<porto>`.

Valores **(H)** de Formulas (F3 66 s, Carga/Pisotear, `RES_*`, `ELEM_DEATH_LOSS`, poder do jogador ×2) são hipóteses: os critérios
checam a mecânica, e cada número é calibrado pela sonda na fase em que entra.

## Open Questions

| # | Pergunta | Dono | Quando resolver |
|---|---|---|---|
| 1 | O que exatamente vem do leste (a "noite" de Azhar, outra coisa)? Só o suficiente para *Ecos da Noite* — o Ato III decide o resto | autor | antes das missões de Kharzun (fase 3) |
| 2 | Visual próprio dos 72 conjuntos lendários: ordem por classe e quanto reaproveitar dos conjuntos de nível 30 | autor + art-director | fase 4 (polimento) |
| 3 | Valores marcados **(H)** em Formulas (quest share das faixas novas, poder do jogador ×2, tempo do troll solo, perda de `elem_xp`, Carga/Pisotear, ressurreição, imunidade depois de cair) | systems-designer + sondas | cada um na fase em que a mecânica entra |
| 4 | Combate montado vale para outras classes depois (ex.: Ranger atirador montado)? Hoje é só a ascensão do Paladino | autor | depois da fatia 1 |
| 5 | Montaria lobo atroz (*Ovos do Lobo Atroz*): só visual ou mais rápida que o cavalo? | autor | fase 3 |
| 6 | As cinco ascensões que você não pediu explicitamente (Bispo, Druida, Ranger, Assassino, Necromante) ficam como estão ou mudam? | autor | antes de implementar cada uma (fase 1, depois das três primeiras) |
| 7 | Leitura das mecânicas novas pelos bots (focar o Agitador, fogo/veneno no troll, proteger quem cura do assassino): cabe na IA de grupo atual ou pede regras novas? | ai-programmer | fase 1 (Agitador) e fase 2 (troll) |
| 8 | Precisa de um `systems-index.md`/`game-concept.md` (hoje o projeto não tem; este documento ficou fora de índice)? | autor | quando rodar `/map-systems` |
