# Proposta: polir a faixa da Aurora 20-30 (Luz contra Trevas) como a faixa élfica

> **DECISÕES DO USUÁRIO (2026-11-25): todas as recomendadas.** D1 = B (Campo dos Juramentos + Arquivo de Vel'Thar); D2 = Azhar de Vel'Thar
> (Provisória, narrative-director confere); D3 = B Cerco Vivo com os 3 fronts como trechos; D4 = fúria sobe a pressão; D5 = B por forte +
> Restos da Noite + eco de chefe; D6 = B rotinas + fortes vivos + conquista; D7 = campo novo + Restos (alvo 44-48%); D8 = sim, corrigir rótulos.
> D7 extra (2026-11-25): `Balance.XP_QUEST_SHARE_BAND[20]` 0,65 -> **0,78** (~45%; quests do campo novo somam XP, as antigas ficam ~iguais).
>
> Status: **PROPOSTA** (world-builder, 2026-11-25). Nada foi alterado em `data/`, `core/`, `game/`, `tools/`.
> Pedido do usuário: "o mesmo polimento" que a faixa élfica 10-20 recebeu (`elf-band-refactor-proposal.md` → `brejo-das-teias.md`,
> `elf-band-living.md`, cerco do Posto no `SiegeSystem`), agora para o Bastião da Aurora, os 3 fortes, a Cidadela do Lich, as ruínas e a conquista.
> Pontos marcados **(a confirmar)** não foram verificados no código nesta passada. Lore nova está marcada **Provisória** (precisa do `narrative-director`).

---

## 1. Estado atual (resumo com referências)

| Peça | Hoje | Onde |
|---|---|---|
| Hub | Bastião da Aurora (id `field_ruins`, mapa 260 m, anel murado r 56 m, 4 portões, catedral com surtida de 20 soldados, besteiros nas torres, guarnição `dawn_g_*` que renasce em 12 s, 55 NPCs no JSON) | `data/zones/field_ruins.json` `town`, `maps_catalog.gd` `DAWN_NPCS`/`DAWN_ROLE_*`/`SORTIES` |
| Fronts | 3 fronts no próprio Bastião (oeste pântano, norte ossos, sul gelo) com 11 spawners, **todos** `unless: dw_<forte>_boss` | `field_ruins.json` `spawners` |
| Lugares | coveiro (cabana, Osric), escavacao (cabana, Vera/Senna, SE), capela (santuário, caçadas), ninho_putrido (camp), cripta (`dg_cripta` 25-30), covil_dragao (`dg_covil_dragao` 28-30, chefe opcional) | `field_ruins.json` `places` |
| Fortes | `fort_ghoul` 20-23 (12 spawners, Carniçal Gigante), `fort_bones` 23-26 (9, Vorhag), `fort_frost` 26-29 (8, Morvath), `lich_citadel` 29-30 (7, Azhar). Nenhum tem `places`. Retomado: presos somem, nascem 3 colonos (capitão/ferreiro/mercador) e a guarnição | `FORT_DEFS`, `FORT_NPCS`, `build_dawn_forts.py` |
| Linha principal | q12_ruins → dw_gates (30 larvas) → dw_ghoul_posts → dw_ghoul_boss → dw_ghoul_settle → dw_bones_posts → dw_bones_boss → dw_frost_posts → dw_frost_boss → dw_lich → dw_epilogue (fim do Ato I) | `quests_catalog.gd` 373-430 |
| Portões | to_fort_ghoul nv 20 + dw_gates; bones nv 21; frost nv 23; citadel nv 27 + dw_frost_boss | `PORTAL_GATES` 1901-1904 |
| Investida | `RaidSystem` antigo, **3 rotas ao mesmo tempo** (`say_sync`: "o Bastião está cercado"): oeste ~75 (39 larvas + 18 zumbis + 12 carniçais + 6 lobos, +3 ursos a cada 2ª), norte 38, sul 38 (+3 cavaleiros a cada 2ª); a cada 200/230/260 s ± 40. **Fúria**: cada forte retomado multiplica os fronts que sobram por `RAID_RECLAIM_MULT` 1,5 e soma elites; o último front ×`RAID_LAST_FRONT_MULT` 2,0 + líder elite (~80 na leva). Cada rota para com `unless` do chefe dela | `MapsCatalog.RAIDS["field_ruins"]`, `raid_system.gd` 135-195, `Balance` 1256/1280 |
| Aliados que marcham | reforços de cada forte retomado à praça (`REINFORCE_MAX` 3 por forte, a cada 120 s); assaltos da Aurora em `fort_bones`/`fort_frost`/`lich_citadel` | `ASSAULTS` |
| Conquista no cenário | `DAWN_CONQUEST_VIS`: chão do front e ninho pútrido somem, `limpo_<forte>` aparece (só no Bastião; nos fortes só a troca de NPCs) | `maps_catalog.gd` 119 |
| Festa | `FESTIVAL["field_ruins"]` (3 NPCs) `if: dw_lich` | `maps_catalog.gd` 141 |
| Vida | **sem** `LIVING_NPCS`, **sem** `AMBIENT_LIFE`, **sem** `ROAD_EVENTS`, **sem** `MOB_PATROLS`, **sem** `SIEGE`, **sem** `FORT_LIFE` (os 3 fortes do Ato II têm; os do Ato I não) | buscas em `maps_catalog.gd` |
| Música | `field_ruins` = "bastiao", `lich_citadel` = "cidadela", `fort_*` = "trevas" (Act I), cripta/covil = masmorra/caverna | `game/audio/music.gd` 17-64 |

### 1.1 XP da faixa (`band_probe --from=20 --to=30 --only=audit`, 2026-11-25)

`AUDIT xp das quests 235720 de 611000 para subir 20->30 (39%)` — **abaixo** do alvo de 40-50% (`QuestsCatalog.scale_xp`).
Quests por nível: `{20: 7, 21: 4, 22: 5, 23: 3, 24: 5, 25: 2, 26: 2, 27: 6, 28: 1, 29: 2, 30: 9}`, mas as de 28-30 são quase todas do Ato II
(Porto, `h_goblin_lancer`/`h_wolf_rider`/`h_naga_tide`, `hx_*`). Da faixa da Aurora mesmo:

| Nível | Quests da Aurora | Comentário |
|---|---|---|
| 20-22 | 16 | cheio (linha principal + Senna + caçadas) |
| 23-24 | 8 | ok; aqui a linha principal já derruba Ossos (22) e Torre (24) |
| **25-26** | **4** (q13b_crypt, b_ghosts, b_cult, s_crypt) | **buraco**: só Cripta e laterais |
| 27 | 4 caçadas da Cidadela + dw_lich | só a raide do Lich (grupo; solo 1/20) |
| **28-29** | **0** | **buraco**: só o Dragonete (nv 30, grupo 4+) |

## 2. Problemas encontrados

1. **A linha principal corre na frente dos rótulos**: `FORT_DEFS` diz Ossos 23-26 e Torre 26-29, mas o roteiro (e a sonda) derruba Ossos no 22 e a Torre no 24. Do 24 ao 27 o jogador "prepara" sem conteúdo próprio, e do 27 ao 30 só há a raide do Lich e o Dragonete.
2. **O mundo esvazia com a vitória**: todos os spawners dos fronts e dos fortes são `unless` do chefe; depois da Torre (nv ~24) o Bastião **não tem monstro nenhum** fora da Cripta, e os chefes somem (memória `dawn-third-floor`: "só o Lich pode ser farmado"). Exatamente quando faltam quests, falta caça.
3. **Investida empilhada, em triplo**: mesmo `RaidSystem` que empilhava no Posto (mesmo ponto, mesmo tick, mesma rota; ver §5.1 da proposta élfica), mas com **3 levas juntas** (~150 corpos no pico) e a fúria levando o último front a ~80 com líder. O Posto já migrou para o `SiegeSystem` (uma leva por vez, escalões, pressão); o Bastião não.
4. **Fúria ao contrário da sensação**: quanto mais o jogador vence, mais pesada a leva que sobra (×1,5, ×2). É boa lore ("a noite se desespera"), mas soma com o item 3 e é a pior hora para perf (a confirmar com `--soak` no Bastião; não medido nesta passada).
5. **Bastião estático**: guarnição e surtida existem, mas ninguém trabalha, carrega, reza ou foge. Nenhum alarme quando a trompa toca (o `alarm` de `LIVING_NPCS` já existe desde a faixa élfica).
6. **Fortes do Ato I sem vida**: só troca de 3 presos por 3 colonos. Os do Ato II (`FORT_LIFE`) têm cativos com carga antes e sapador/cozinheiro/ferido/sentinelas depois — o mesmo molde serve aqui sem código.
7. **Pouco opcional e nada no meio**: os opcionais são a Cripta (25-30) e o Dragonete (30, grupo). A faixa 10-20 agora tem Bosque dos Xamãs, Pedreira e Brejo das Teias; a 20-30 não tem campo lateral.
8. **Mistério sem lugar**: a lore já planta perguntas sem resposta — "Jurei à Aurora antes de Vorhag jurar à noite. Fomos irmãos" (Sir Malcom), "Morvath congelou o próprio coração" (Mago Aurélio), "Ele guarda as almas da cidade antiga no trono" (Alma Presa), "A noite tem um coração. Está no peito dele" (Velha Sacerdotisa), "Cacos de Vel'Thar" (Senna). Nada no jogo diz **por que** Vel'Thar caiu nem **por que** cavaleiros da Aurora juraram à noite. É o equivalente da "seiva" élfica.

---

## 3. Pedido 1 — Zonas opcionais

Regra de lore usada (**Provisória**, só costura o que já está dito): Vel'Thar foi a cidade antiga sob o Bastião; **Azhar foi o último rei-sacerdote de Vel'Thar**, que, para não perder os mortos da peste, prendeu as almas da cidade no trono ("guarda as almas da cidade antiga") e virou Lich. A promessa dele aos vivos é **falar com os mortos de novo** — foi isso que comprou o juramento de Vorhag (irmão de armas de Sir Malcom) e o coração congelado de Morvath. O opcional é onde o jogador **descobre isso**, sem travar a linha principal. Ganchos já existentes: Erudita Senna e a escavação (SE, [60, 92]), Vera ("achei uma cripta sob o zigurate"), Osric ("enterro os mesmos mortos toda semana").

| Opção | O que é | Escopo | Toca |
|---|---|---|---|
| **A. POIs dentro dos mapas** | Escavação vira mini-zona (bando de saqueadores + elite raro + baú, cadeia de 3 quests da Senna sobre Azhar); Ninho Pútrido e Capela ganham elite noturno e colheita própria; cada forte ganha 1 lugar (`places`: cabana de desertor, santuário profanado) com quest | **S** | dados (`quests_catalog`, `GATHER`, spawners extras, `PLACE_NPCS`), pouco Blender (lugares nos `build_dawn_forts.py`) |
| **B. 1 campo + 1 mini-masmorra (recomendada)** | **Campo "Campo dos Juramentos"** 24-28, pela escavação (borda SE do Bastião, perto da Capela; vão na borda **a confirmar**): o velho campo de batalha onde a Ordem da Aurora se partiu — ruínas baixas de Vel'Thar meio enterradas, estandartes caídos, cemitério de cavaleiros. Monstros: **Juramentados** (cavaleiros-espectro que ainda guardam o juramento à noite), **Corvos de Carniça** grandes, **Penitentes** (vivos do Culto da Noite que cavam túmulos para o Lich, reuso do `cultist` re-tintado + 1 novo), mini-chefe **o Porta-Estandarte Caído** (skill própria `mob_*`: finca o estandarte e ergue Juramentados num círculo avisado). Cadeia de Sir Malcom: achar o túmulo vazio de Vorhag (lore). **Mini-masmorra "Arquivo de Vel'Thar"** 27-29, sob o zigurate da escavação: salões de registro da cidade antiga; 1 chefe (o **Escrivão de Azhar**, que lê nomes e "chama" os mortos: invoca o eco de quem ele nomeia) + 1 sala de leitura (quebra-cabeça leve: placas na ordem certa); recompensa = Fragmento da Aurora / Prata Consagrada (material de tier do Doran) e a verdade sobre Azhar (texto para o `writer`) | **M** | Blender (`build_field_oaths.py` + entrada em `places.DUNGEONS`), dados (MapDef, portais ida/volta, spawners, NPC guia, `bot_population`, quests, loot, `PORTAL_GATES` só por nível), 2-3 monstros novos (modelos, Fable), música (`Music.MAP_THEME`; "trevas" serve), arte de carregamento (`loading_art.ZONES`/`BOSSES`) |
| C. 2 campos + 2 masmorras | B + **"Pântano Assentado"** 22-25 (a oeste do Covil, o que sobrou do pântano depois da retomada: brejo de cura sendo drenado, restos da ninhada) + **"Ossuário do Palácio"** ala da Cidadela pós-Lich (farm de nível 30) | **L** | tudo de B em dobro; risco de diluir o XP e o povoamento de bots |

Regras comuns: XP por `QuestsCatalog.scale_xp`, meta é levar a faixa de 39% para **44-48%** (6-10 quests novas nos níveis 25-29); loot 0,3-0,7 materiais, raro ≤ 0,05, chefe garante material de tier; portão só por nível; layout Erenshor (vale fechado, POIs 60-120 m, estrada curva, landmark: o estandarte gigante quebrado / zigurate).
Riscos: XP inflar (rodar `band_probe --from=20 --to=30`), mais um mapa no `start_enter`/`sim_maps` (pequeno), bots espalhados (rever `bot_population` do Bastião). Monstro "fala com os mortos" = implicação de jogo (eco que copia quem foi nomeado) → **`game-designer`** antes de virar mecânica.

---

## 4. Pedido 2 — Investida / cerco no Bastião

### 4.1 Por que vem empilhada aqui

Herda as 6 causas do Posto (nascer no mesmo disco e tick, 12 s de muster parado, rota única afunilando, mesma velocidade, separação só até encostar, mesmo alvo — `elf-band-refactor-proposal.md` §5.1), **mais**:
- 3 rotas disparam juntas (`say_sync`) e os 3 relógios (200/230/260 s ± 40) se alinham de novo com frequência;
- a fúria multiplica a leva justo quando o jogador já é forte (último front ~80 + líder);
- a surtida de 20 soldados + reforços + guarnição renascendo em 12 s fazem a luta virar um bolo no portão (a confirmar no `--soak`).

### 4.2 Opções

| Opção | O que muda | Escopo | Toca |
|---|---|---|---|
| A. Espaçar o que existe | dessincronizar as 3 rotas (nunca duas dentro de `X` s), escalões e nascimento em arco (o que o `SiegeSystem` já faz no Posto), fúria com teto (`RAID_RECLAIM_MULT` 1,5 → 1,25, último front ×1,5) | **S** | dados + `Balance.RAID_*`; nenhum Blender |
| **B. Cerco Vivo no Bastião (recomendada)** | `MapsCatalog.SIEGE["field_ruins"]` como o Posto: **segments = os 3 fronts** (`ghoul`/`bones`/`frost`, cada um fecha com o chefe do forte), uma leva por vez revezando os fronts abertos, **pressão** pela história (dw_gates → 2; cada forte caído **sobe** a pressão em vez de multiplicar o tamanho: "a noite se desespera" vira mais frequência, não um bolo maior; Torre caída → 0 paz). **Assédio**: arqueiros de osso no morro do norte (`skel_archer`, salva de círculos avisados; tema `blood`/sombra). **Batedores com trompa**: morcegos da Torre e um tamboreiro de osso em `MOB_PATROLS` com `{"horn": true}`. A surtida da catedral continua (é a assinatura do Bastião) e vira a "resposta" do cerco (`responder`) | **M** | sim: `SiegeSystem` já aceita `kind: "gates"` (Posto) — **a confirmar** se aceita 3 segmentos que fecham por quest de outro mapa; Blender: rotas `cerco_<front>`, `harass_route` e `low_route` no `build_field_ruins.py` (Fable) + JSON; dados `SIEGE`, falas por front; testes `--only=siege`, `raid_probe --map=field_ruins` |
| C. B + Noite Longa | B + evento raro depois da Torre e antes do Lich (nv 24-27): **"A Noite Longa"**, o Lich manda uma leva da Cidadela pelo nordeste (`citadel_*`) e o céu escurece (fx `smoke`/`fire` de `SiegeFx` nas casas do anel, Chamas só visuais); repetível com prêmio de quadro. Cobre o buraco 24-27 com defesa em vez de só caçada | **L** | B + rota NE no Blender, `RAIDS`/`SIEGE` com `if: dw_frost_boss` `unless: dw_lich`, música "investida", `conquest_vis` de casas queimadas no anel |

**Reuso do Cerco Vivo (recomendação)**: pegar **pressão por quest**, **revezar fronts**, **escalões/arco**, **batedores com trompa** e **assédio** (aqui o nível 20-24 aguenta salva não esquivável melhor que o 13-16 do Posto; medir). **Não** pegar a paliçada em obra (`segments` com `pal_<id>_obra`) — o Bastião é muralha de pedra; o "trecho aberto" é o front com forte vivo.

### 4.3 Riscos

| Risco | Mitigação |
|---|---|
| Perf (não medido; 3 levas + surtida + guarnição) | B baixa o pico (uma leva por vez); medir `--soak` no Bastião antes/depois e `--perf_at` na praça |
| Ficar fácil demais | memória "raids must be a threat": reportar repelidas %, mediana, mortes de guarda, chegadas; ajustar tamanho, não poder da guarda; `raid_probe --map=field_ruins --bots=0,1,3 --trials=20` |
| dw_gates (30 larvas) depende das levas do oeste | manter larvas nas levas do oeste e no front; conferir no `band_probe` |
| Bots defensores olham uma rota | rever `BotBrain._defend` com fronts revezando (já feito no Posto? **a confirmar**) |
| Assédio/eco = mecânica | `game-designer` antes; `class-designer` se mexer em skills |

---

## 5. Pedido 3 — Regra da conquista

A faixa élfica escolheu "**só o Rei muda o mundo**" porque lá os fortes são de capitão, dentro da cidade inimiga. Aqui é o contrário: **cada forte é um lado do cerco** e a retomada por forte é a identidade da faixa (front limpo, reforços, colonos). Trocar isso seria perder o que já funciona. O problema real é o item 2 da §2: a vitória **esvazia** o mapa.

| Opção | Regra | Escopo | Toca |
|---|---|---|---|
| A. Fica como está | cada forte limpa o front dele; tudo some | — | nada (o buraco 24-29 fica) |
| **B. Por forte + Restos da Noite (recomendada)** | mantém a retomada por forte; o front limpo ganha **Restos** (spawners `if: dw_<forte>_boss`, metade da densidade, monstros 3-4 níveis acima: carniçais de brejo drenado, ossos soltos, espectros de gelo derretendo) para caça de 24-29; **o forte retomado mantém um bolsão hostil** ("a ala que ninguém limpou": 2-3 spawners no fundo) e o **chefe volta como eco** repetível na capela da Senna (quadro de caçadas). O Lich continua sendo o fim: depois de `dw_lich` os Restos ficam e o Bastião entra em reconstrução (§6) | **M** | dados (spawners com `if` no catálogo ou no JSON via Blender — **a confirmar** se spawner `if` pode vir do catálogo sem refazer o GLB), `quests_catalog` (caçadas `repeatable`), loot |
| C. Só o Lich muda o mundo (como os elfos) | fronts e investidas continuam até `dw_lich`; fortes viram só posto avançado | **M** | reescreve `RAIDS`/spawners/`DAWN_CONQUEST_VIS`, roteiro e o texto dos portões. **Contradiz canon** (roteiro_20_30: "cada fortaleza retomada limpa aquele lado e cala a investida dele"; falas de Lyria "Cada fortaleza retomada vira um posto da Aurora. É assim que a noite encolhe") — exige aprovação do `narrative-director` |

**Consistência**: B não contradiz nada (os Restos são "a noite recua, mas não morre", fala do Arauto da Aurora na Cidadela). C contradiz o roteiro e falas estabelecidas — se escolhida, as falas mudam junto.

---

## 6. Pedido 4 — Vida no Bastião e nos acampamentos

Ferramental existente (sem código novo): `LIVING_NPCS` (`carry`, `flow`, paradas, barks, `if`/`unless`, `alarm`/`alarm_cry`), `AMBIENT_LIFE`, `ROAD_EVENTS` (+ `CATALOG_EVENT_POINTS` provisórios), `FORT_LIFE` (`pre`/`post`), `conquest_vis` com lotes `tag` do `Dress`, `SiegeFx`.

### 6.1 Rotinas propostas (só dados, salvo nota)

| Id | Rotina | Mapa |
|---|---|---|
| B1 | **Aguadeiros da catedral**: 2 irmãs levam água benta (`carry_sack`) da catedral aos 4 portões; barks "Água benta no portão norte!" | field_ruins |
| B2 | **Virotes para as torres**: aprendiz do Doran leva `carry_crate` da forja às torres dos besteiros | field_ruins |
| B3 | **Osric enterra**: o coveiro sai com a carroça (`cart`) do front que acabou de ser repelido até o cemitério do coveiro ([74, -38]); bark seco ("Mais um. Dos nossos.") | field_ruins |
| B4 | **Carroça da escavação**: Vera e um carregador trazem cacos (`cart_draft`) da escavação ao relicário do Irmão Anselmo; ponte com a lore de Vel'Thar | field_ruins |
| B5 | **Alarme**: refugiados e civis com `alarm: [catedral]` correm para dentro quando houver leva viva; vigia da torre com `alarm_cry` ("Trompas no pântano! Para a catedral!") | field_ruins |
| B6 | **Bichos**: corvos sobre os fronts vivos, morcegos no front sul, mariposas nas lanternas da praça, pombas na catedral depois de `dw_lich` (`AMBIENT_LIFE` com tipos que já existem; pomba = `crow` re-tintado ou tipo novo **a confirmar**) | field_ruins |
| F1 | **`FORT_LIFE` dos 3 fortes do Ato I** no molde do Ato II: `pre` = presos trabalhando (Covil: carregam carne ao monte do Carniçal; Ossos: polem armaduras negras; Torre: quebram gelo com `carry_rock`); `post` = sapador desmontando o ninho/a torre negra, cozinheiro, ferido, 2 sentinelas `fighter` | fort_ghoul, fort_bones, fort_frost |
| F2 | **Cidadela pós-Lich**: procissão de libertação das almas (sacerdotisas `flow` até o trono), Intendente Clara com carroça | lich_citadel |
| E1 | **Evento de estrada "Relíquia na Estrada"**: Penitentes cercam a carroça da escavação (B4); salvar dá consumível + bark da Senna | field_ruins (`EVENT_POINTS` no build; até lá `CATALOG_EVENT_POINTS`) |
| E2 | **Evento "Desertor da Noite"**: um Juramentado que lembra o nome pede para ser enterrado (some se matar; prêmio se escoltar ao Osric) — liga com o Campo dos Juramentos | field_ruins / campo novo |

### 6.2 Mudança de estado pela conquista

| Gatilho | Bastião | Forte |
|---|---|---|
| Cada forte | front limpo (já existe), Restos (§5 B), aguadeiro daquele portão vira festa de soldado, enfermaria do portão esvazia (`tag` no `build_field_ruins.py`) | `pre` → `post` do `FORT_LIFE`, estandarte da Aurora (`tag`, como `horde_fort_vis`) |
| `dw_lich` | reconstrução: andaimes e pedreiros no anel (`tag`), sinos da catedral, pombas, investida zero, festa (já existe) | Cidadela vira posto da Aurora com F2 |

### 6.3 Opções

| Opção | Escopo | Toca |
|---|---|---|
| A. Rotinas e bichos (B1-B6) | **S** | só dados (`LIVING_NPCS["field_ruins"]`, `AMBIENT_LIFE`, barks); B3/B4 reusam `cart`/`cart_draft` |
| **B. A + fortes vivos + conquista (recomendada)** | **M** | A + F1/F2 (`FORT_LIFE`, só dados), tags de estandarte/enfermaria/andaime em `build_field_ruins.py` e `build_dawn_forts.py` (Fable; JSON tem de sair igual fora as tags), E1 |
| C. B + som e estado | **L** | sinos/trompas de osso (`Sfx`), música "bastiao" de dia depois do Lich (`Music`), troca de guarda, E2 (depende do campo novo) |

Riscos: perf da praça com guarnição + surtida + rotinas (teto de +8 rotinas, como a elf_city); `carry` novo só se faltar prop (`life_props.py`); tags no GLB exigem `_check_places`, travessia e chegadas.

---

## 7. Decisões para o usuário

| # | Pergunta | Opções | Recomendada |
|---|---|---|---|
| D1 | Tamanho do pacote de zonas opcionais | A POIs nos mapas atuais · B 1 campo + 1 mini-masmorra · C 2 campos + 2 masmorras | **B** |
| D2 | Lore do opcional (Provisória) | Azhar foi o último rei-sacerdote de Vel'Thar e comprou juramentos com "falar com os mortos" · outra origem (diga qual) · sem revelação, só caça | **Azhar de Vel'Thar** (só costura falas existentes) |
| D3 | Modelo da investida do Bastião | A só espaçar · B Cerco Vivo com os 3 fronts como trechos · C B + Noite Longa (24-27) | **B** |
| D4 | O que a "fúria" (forte caído) faz | sobe a pressão (mais frequente, leva normal) · mantém leva maior (×1,5/×2) com teto · some | **sobe a pressão** |
| D5 | Regra da conquista | A como está · B por forte + Restos da Noite + eco de chefe · C só o Lich muda o mundo (contradiz canon) | **B** |
| D6 | Vida no Bastião e nos fortes | A rotinas · B + fortes vivos + conquista · C + som e estado | **B** |
| D7 | Fechar o buraco de XP 25-29 com | quests do campo novo + Restos · também Noite Longa repetível · só caçadas repetíveis | **campo novo + Restos** (alvo 44-48%) |
| D8 | Corrigir os rótulos `FORT_DEFS.levels` para o ritmo real (Ossos 21-24, Torre 23-26) | sim · não, puxar a linha principal para os rótulos (portões de nível mais altos) | **sim** (só dado; menos atrito que travar o jogador) |

## 8. Ordem sugerida de pacotes

| WP | Conteúdo | Agente | Depende |
|---|---|---|---|
| WP1 | Medir antes: `--soak` e `--perf_at` no Bastião com as 3 levas, `raid_probe --map=field_ruins --bots=0,1,3 --trials=20`, linha de base do `band_probe` (39%) | qa-tester | — |
| WP2 | Cerco Vivo no Bastião: `SIEGE["field_ruins"]` (3 fronts como trechos, pressão, revezamento, fúria → pressão), batedores com trompa em `MOB_PATROLS`; conferir se o `SiegeSystem` aceita trecho fechado por quest de outro mapa | gameplay-programmer (sim, se preciso) + world-builder (dados/números) | D3/D4, WP1 |
| WP3 | Rotas `cerco_*`, `harass_route`, `low_route` no `build_field_ruins.py` + JSON; assédio dos arqueiros de osso | **Blender = Fable** + world-builder; `game-designer` aprova o assédio | WP2 |
| WP4 | Conquista B: Restos da Noite (spawners `if`), bolsão no forte, eco dos chefes na capela (repetíveis), `FORT_DEFS.levels` (D8) | world-builder | D5/D8 |
| WP5 | Bastião vivo: B1-B6, `AMBIENT_LIFE`, alarme, E1 (`CATALOG_EVENT_POINTS` até o build) | world-builder (+ writer para falas) | D6, WP2 (alarme lê leva viva) |
| WP6 | Fortes vivos F1/F2 + tags de estandarte/enfermaria/andaime nos builds | world-builder + **Fable** (tags) | D6 |
| WP7 | Campo dos Juramentos (layout `/layout-zone`, places, spawners, NPC guia, quests da cadeia de Sir Malcom, loot, mini-chefe com `mob_*`, música, loading art) | world-builder (design) → **Fable** (zona e monstros) → writer (falas) → `class-designer` só se a skill do mini-chefe pedir regra nova | D1/D2/D7 |
| WP8 | Mini-masmorra Arquivo de Vel'Thar (chefe Escrivão de Azhar, sala de leitura) | **Fable** + world-builder; `game-designer` para o eco que copia o nomeado | WP7 |
| WP9 | QA: testes, `band_probe --from=20 --to=30` (alvo 44-48%), `raid_probe`, `boss_probe` do mini-chefe e do Escrivão, soak no Bastião e no campo novo, smoke, `docs/roteiro_20_30.md` e `docs/DESIGN.md` | qa-tester | cada WP |

### Checagem de consistência (lore)

- Nomes usados existem: Marechal Aldric, Alta Sacerdotisa Lyria, Erudita Senna, Osric, Vera, Doran, Irmão Anselmo, Sir Malcom, Mago Aurélio, Vorhag, Morvath, Azhar, Vel'Thar, Carniçal Gigante, Capitã Rena, Comandante Viana, Paladina Sofia, Arauto da Aurora, Intendente Clara.
- Nada do proposto apaga canon, exceto a opção C da §5 (marcada). A origem de Azhar (D2) é **Provisória**: precisa do `narrative-director` antes de virar texto do jogo.
- Texto de jogador (falas, diálogos, quests) fica com o `writer`; os barks acima são esboço de tom.
