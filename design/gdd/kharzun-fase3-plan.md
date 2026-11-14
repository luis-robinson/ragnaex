# Ato II — Fase 3: Monte Kharzun (40–45) — PLANO

> **Status**: **Aprovado** em 2026-11-12 ("aprove o plano do Kharzun com as recomendadas e comece") — decisões D1–D12 =
> Recomendado, aprovadas pelo usuário. A tabela da seção 0 é o registro dessas decisões. Implementação a partir do WP0
> (este documento + `ato2-horda.md` alinhado).
> **Author**: game-designer (Claude) · **Data**: 2026-11-12 · **Base**: master `fcb72e3` + int2b (aprovação sobre `964e3f1`)
> **GDD pai**: [`ato2-horda.md`](ato2-horda.md) (R2, R3, R4 Monte Kharzun K0–K4, R5, R6, R7, R8, F1, F2, F10, AC-01..36, OQ 1 e 5)
> **Fontes lidas**: `ato2-horda.md`, `ato2-proposals-2026-11-11.md`, `production/session-state/active.md`, `docs/DESIGN.md`
> (Mundo/Bastião/Cidadela, Chefes, Ato II), `.claude/docs/ragnaex/{zonas,conteudo,desempenho}.md`, `data/catalog/maps_catalog.gd`
> (`PORTAL_GATES["to_field_kharzun"]`, `Q_STEPPE_FORTS`), `data/balance.gd` (`MAX_LEVEL` 40, `LEGENDARY_LEVELS`, `BOSS_CROWD_MULT`, `PARTY_MAX` 5).

---

## 0. Decisões (aprovadas pelo usuário em 2026-11-12: todas na opção Recomendada)

| # | Decisão | Opções | Recomendado (= aprovado) | Por quê (uma linha) |
|---|---|---|---|---|
| D1 | Hub numa terra inimiga | (a) **Acampamento Avançado da Aurora**: paliçada de estacas + carroças no sopé, cresce por estágio · (b) sem hub (só cristal), serviços no Posto da Caravana · (c) a Forja Negra retomada vira o hub | **(a)** | Cumpre a regra "hub murado no centro" (`zonas.md`) com o tema de cerco, e repete o padrão do Posto da Caravana (estágios visíveis). |
| D2 | Quantos mapas | (a) **`field_kharzun` + `dg_slayers` (masmorra) + `kharzun_citadel` (mapa próprio)** · (b) dois campos (sopé + encosta) · (c) cidadela dentro do campo | **(a)** | É o que o GDD R2 já diz e espelha Bastião + Cidadela do Lich; (b) dobra arte e custo de tick; (c) estoura o vale de 240 m. |
| D3 | Três Chefes de Clã | (a) **três alas da cidadela** (masmorra ramificada, `layout` em `places.DUNGEONS`, qualquer ordem) · (b) três mapas de forte como nas Estepes · (c) um chefe + corredor | **(a)** | Escolha de rota sem repetir as Estepes; uma cidadela só = menos mapas carregados (AC-36). |
| D4 | Tamanho da raide final | (a) **Grão-Senhor afinado para 5** (`BOSS_CROWD_MULT[5]` = 5,0) · (b) afinado para 4 como os outros | **(a)** | O GDD promete "raide de 5"; `PARTY_MAX` já é 5 e o reforço por pessoas já existe. 4 completo fica como "difícil, possível". |
| D5 | Montaria lobo atroz (OQ 5) | (a) **mesma velocidade do cavalo, visual próprio** · (b) +10% de velocidade | **(a)** | Evita "a montaria certa" dominar e não mexe na F8 (combate montado do Paladino). |
| D6 | *Ecos da Noite* (OQ 1) | (a) **mínimo**: inscrições nas Minas + visão no trono após o Grão-Senhor ("a noite que anda do leste"), sem nomear · (b) nomear a volta de Azhar · (c) inimigo-amostra do Ato III | **(a)** | O GDD diz "só o suficiente"; não fecha nada que o Ato III precise decidir. Texto final = narrative-director. |
| D7 | Ascensão 45 | (a) **refinos 45 continuam nós-portão** (já feitos); o **Arauto dos Mestres** no acampamento dá uma prova opcional `hx_asc45_<classe>` (moedas + título, 0 poder) · (b) missão 45 obrigatória que trava os refinos | **(a)** | Os refinos 45 já existem como portão da teia (R6, `ASC_REFINES_PENDING` vazio); (b) desfaz trabalho e muda save. |
| D8 | Investidas / conquista | (a) **Contra-ataque da Horda** no acampamento (2 frentes: Canil e Cidadela) até K2; depois a **Ofensiva da Aurora** sobe a avenida da cidadela (`ASSAULTS`) · (b) sem investidas em Kharzun | **(a)** | Padrão Bastião/Estepes; o mundo "cresce com as missões" (R4) e dá trabalho para os bots. |
| D9 | Portão da cidadela | (a) **nível 43 + `hx_citadel_gate`**; sala do trono = os 3 clãs · (b) só missão | **(a)** | Segura a faixa 44–45 da cidadela; padrão `PORTAL_GATES` (`level` + `quests`). |
| D10 | Modelos dos monstros 40–45 | (a) **variantes paramétricas** de `mob_kit.horde_parts`/`act2_bosses.boss_extras` + 5 chefes com peças grandes próprias · (b) tudo novo do zero · (c) só troca de cor | **(a)** | O jeito que já funcionou nas Estepes (stand-in primeiro, modelo depois); (c) quebra "cada estágio mais pesado" (Visual/Audio do GDD). |
| D11 | Aprimoramento 40+ (K1) | (a) **Ferreiro Anão aprimora lendários 40+** com Aço Anão (+1..+5) e Brasa de Kharzun (+6..+9), como `PLUS_DAWN_*` · (b) só o ferreiro comum | **(a)** | O GDD (K1, AC-33) já promete; dá destino aos materiais da Forja e dos chefes. |
| D12 | Nome do Grão-Senhor | (a) **placeholder "Durgash, o Grão-Senhor da Guerra"** até o narrative-director · (b) sem nome próprio | **(a)** | Ghar, Grukk e Vorgul têm nome; o chefe final sem nome fica fraco. Placeholder, não lore. |

**Decisões de 2026-11-13 (usuário)**, por cima da tabela: teto **45** confirmado; a Cidadela **aceita montaria** (`MapDef.mounts_ok`;
`dg_slayers` segue sem); tick ≤ **10 ms** (§8); mudanças de esquema aprovadas (save `mount`, `QuestDef.reward_title` — D5/D7);
Durgash usa a tabela própria `Balance.BOSS_CROWD_RAID` (`[1, 1, 1, 2, 4,9, 3,25]`, o `BOSS_CROWD_MULT` global não muda) + berserk
×20 (`MonsterDef.berserk_mult`), luta do 5 completo ~**100 s** (§4); Gêmeos ganha o nó 45 **Fúria Gêmea** + Ciclone de Titã no
`BOT_ORDER` (KAC-13); cada chefe ganha uma **assinatura** por cima do kit ([`act2-boss-signatures.md`](act2-boss-signatures.md));
pontas das trilhas corrigidas em todas as zonas (`places._trail`, JSONs iguais byte a byte).

---

## 1. Objetivos e fantasia (40–45, fim do Ato II)

**Objetivo de produto**: levar o jogo de `MAX_LEVEL` 40 a **45**, fechar a linha da Horda (estágios de cima de cada linha,
R3) e terminar o Ato II com uma **raide de 5** e a tela "Fim do Ato II" (K4, AC-23). Nada de regra nova de sim se uma
ferramenta existente resolver (fases, `ward`, `summon`, `barrage`, `pull`, `mob_pick`, `berserk_after`, `rally`, aura de facção,
`front_guard`, `RaidSystem`, `ASSAULTS`, `WorldState`).

**Fantasia (MDA)** — estética-alvo: **Challenge** e **Fellowship** (grupo de bots que sobe a montanha), com **Narrative**
de fecho. "A Horda recuou para a montanha porque não tem para onde fugir; nós somos a ponta de lança da Aurora."
- **40–42**: entrar em terra inimiga. Acampamento pequeno, cercado, investidas de lobo atroz à noite; o grupo aprende que
  **quem fica para trás é caçado** (Assassinos/Matadores).
- **42–44**: virar o jogo. Libertar escravos, tomar a Forja, limpar o Salão dos Matadores; o acampamento **cresce** (anões,
  forja aliada, máquinas de cerco) — o mundo responde (pilar 4, Mundo vivo).
- **44–45**: a cidadela. Três clãs em qualquer ordem (autonomia), elites de todas as linhas juntas, depois o trono: 5
  pessoas, uma luta que pede papéis (tanque segura, cura sustenta, dps mata estandartes) — o "teste final" de tudo que a IA
  de grupo aprendeu no Ato II.
- **SDT**: Autonomia (ordem dos clãs, cadeias paralelas, prova 45 opcional) · Competência (cada chefe ensina a ler uma
  mecânica da Horda) · Relação (os escravos libertados, o Ferreiro Anão, o acampamento que vira vila, o festival).
- **Ritmo**: F1 dá ~65 min planejados no 40 → ~68 no 44; a faixa 40–45 ≈ **5,5–6 h** (missões 40–50% do XP).

---

## 2. Zonas

### 2.1 `field_kharzun` — Monte Kharzun (40–45), vale ~240 × 240 m
Regras de `zonas.md`: borda natural (anel de penhascos de basalto + encosta da montanha ao norte), estradas curvas de 4 m,
3–5 POIs a 60–120 m do hub, rios de **lava** (colidem como água; só pontes de basalto nas estradas), marco visível de qualquer ponto.

```
                    N  (encosta: penhascos, cidadela no pico = MARCO)
          [Salão dos      [Portão da Cidadela] ──garganta──> kharzun_citadel
           Matadores]          |
            NW ~110 m          | ~115 m
               \           ponte de basalto
   [Minas de    \  ~~~~lava~~~~~~~~~~~~~~~~  [Forja Negra]
    Escravos]    \        |                   NE ~100 m (do outro lado da lava)
     W ~80 m ─── [ACAMPAMENTO AVANÇADO DA AURORA] ─── [Canil dos Lobos Atrozes] E ~90 m
                          | (hub, raio ~26 m, paliçada + carroças)
                     garganta sul ──> field_steppe (chegada)
```
- **Hub (D1)**: Acampamento Avançado da Aurora — paliçada de estacas e carroças (props `fort camp/scaffold`, `Dress.tent_aurora`
  já existem), praça com braseiro-marco, 2 portões (sul → Estepes, norte → montanha), cristal (`CRYSTALS`), comandante,
  ferreiro da Aurora, alquimista, mercador, quadro de caçadas, Arauto dos Mestres (D7). Cabe 10+ bots. **Cresce por estágio** (2.4).
- **POIs**: Minas de Escravos (W; boca de mina, trilhos, jaulas; colheita de minério), Canil dos Lobos Atrozes (E; currais, ossos,
  ninhos — Ovos do Lobo Atroz), Forja Negra (NE, além da lava; bigornas, chaminés com fumaça, lava canalizada), Salão dos
  Matadores (NW, entrada de masmorra num paredão), Portão da Cidadela (N, garganta com portão e barbacã).
- **Os 4 tipos de lugar** (`_check_places`): cabana = **Cabana do Xamã Exilado** (orc velho, entre Minas e hub); acampamento =
  o próprio hub + **posto dos libertos** (K1); santuário = **Santuário Partido dos Anões** (pedra rúnica, perto das Minas);
  entrada de masmorra = Salão dos Matadores.
- **Leitura de cima**: rocha escura e basalto, lava laranja (shader de água do Ato II com variante `lava`: brilho, sem espuma),
  fumaça das forjas, trilhas de cinza clara (pontas suavizadas, `places._trail`), estandartes vermelhos da Horda → branco-dourado da Aurora quando retomado.
  Nada > 6 m colado nas estradas perto do hub.
- **Portais**: `to_field_kharzun` já tem portão em `PORTAL_GATES` (nível 40 + `Q_STEPPE_FORTS`) e posição em
  `field_steppe.json` → `future_portals`; vira `TRIG_portal` de verdade e ganha `SPAWN_chegada_field_steppe` no Kharzun.
  Volta sem portão. `to_kharzun_citadel` com portão D9. Entrada `dg_slayers` sem portão de nível (portão de missão: `hx_slayers_open`).
- **Altura**: a sim é plana — a "subida" é visual (patamares sólidos, penhascos), como no Bastião.

### 2.2 `dg_slayers` — Salão dos Matadores (42–44), masmorra
Mapa compartilhado (`parent_map: field_kharzun`), `layout` de 3 salões em linha + 1 lateral (`build_dungeons.build_graph`):
vestíbulo (Assassinos em furtividade), galeria de treino (bonecos, Matadores + Arcos de Fogo), cripta de venenos (lateral,
colheita/baú), salão do Mestre. Lugar onde o grupo **aprende a proteger quem cura** antes da cidadela. Sem montaria (regra atual). A Cidadela, ao contrário, aceita montaria (`MapDef.mounts_ok`, usuário 2026-11-13).

### 2.3 `kharzun_citadel` — a Cidadela (44–45)
Mapa próprio entalhado no pico (como `build_citadel` do Lich: um laço gera tudo). Barbacã → pátio de armas → **três alas**
(D3) por portões laterais: **Ala do Lobo** (W, canis e rampa de ginetes), **Ala da Pedra** (E, caverna de trolls, poças de
musgo), **Ala da Forja** (N-NE, salão de fundição com canais de lava) → **sala do trono** (N, abre com os 3 clãs, K3).
A Ofensiva da Aurora (D8) sobe do barbacã ao pátio. Check novo `_check_kharzun_citadel` (tudo alcançável; Ofensiva chega ao pátio;
fechar uma ala ainda deixa as outras e o trono alcançáveis depois de K3). Bots só entram com o grupo do jogador (regra de masmorra).

### 2.4 Estágios (WorldState, `quests_completed`; detalha K0–K4 do GDD)
| Estágio | Gatilho | Muda |
|---|---|---|
| K0 Sopé | chegada | acampamento só com tendas; Contra-ataque de 2 frentes (Canil e Cidadela) a cada ~240 s ±20%; Minas, Canil, Forja da Horda |
| K1 Correntes | `hx_mines` | escravos libertados (anões e humanos) no posto dos libertos; **Ferreiro Anão** (D11); guardas libertos no muro |
| K1b Canil | `hx_kennel` | frente do Canil cala; restante × `RAID_RECLAIM_MULT` com líder; Ovos do Lobo Atroz disponíveis |
| K1c Forja | `hx_black_forge` | Forja vira aliada (estandartes trocam, anões trabalham, mercador de armas 40); Brasa de Kharzun cai |
| K1d Matadores | `hx_slayers` | emboscadas de Assassinos nas estradas param |
| K2 Portão | `hx_citadel_gate` | portão da cidadela aberto; Contra-ataque para; máquinas de cerco no acampamento; Ofensiva da Aurora sobe |
| K3 Clãs | `hx_clan_wolf` + `hx_clan_stone` + `hx_clan_forge` | sala do trono abre |
| K4 Fim do Ato II | `hx_warlord` | Horda se rende em parte (orcs desarmados no acampamento), festival no porto e no acampamento (`FESTIVAL`, `FestivalFx`), tela "Fim do Ato II" |

---

## 3. Monstros 40–45

Atributos **só pela F2** (`Balance.horde_stat`, `stat_role` + `unit_mods`) com `HORDE_LATE_35` valendo (brutos com vida ×1,3,
preparação mais rápida). Todo estágio de cima nasce com `escort` dos de baixo (AC-15). Modelos por D10.

| Monstro | Nível | Papel F2 | Linha / origem | Mecânica (ferramenta existente) | Modelo |
|---|---|---|---|---|---|
| Assassino Goblin | 40 | comum (hp ×0,8) | Assassinos | furtividade simples + aparece pelas costas de quem cura/atira (`mob_pick: soft`), faca envenenada | goblin + capuz, facas com brilho |
| Lobo Atroz | 40 | comum | nativo | matilha de 3, investida | `quadruped(kind="wolf")` maior, pelagem cinza |
| Ginete do Lobo Atroz | 41 | bruto | Ginetes (topo) | investida em linha + rede do Saqueador; lidera 2 Saqueadores | lobo atroz + goblin montado |
| Lança-Pedras | 41 | bruto (à distância) | Trolls (topo A) | pedregulho no mais longe (`mob_pick: far`), regeneração F3 | troll + saco de pedras |
| Arco de Fogo | 42 | comum (à distância) | Arqueiros (topo) | `mob_fire_arrows` 3 círculos; lidera 2 Besteiros | orc arqueiro + aljava em brasa |
| Senhor da Guerra | 42 | elite | Orcs (topo) | `rally` (grito), talho largo; lidera 2 Guerreiros | Guerreiro Orc + chifres/estandarte (peças de Ghar menores) |
| Matador | 43 | elite (hp ×0,7) | Assassinos (topo) | furtividade + execução em alvo < 30%; lidera 2 Assassinos | goblin alto, capa, duas lâminas |
| Salamandra de Lava | 43 | comum | nativo (Forja) | `dot` de fogo em cone; **imune a queimadura** | `mob_kit.elemental` fogo, menor |
| Brutamontes | 44 | bruto (hp ×1,8) | Trolls (topo B) | regeneração F3 + abalo que atordoa; lidera 2 Trolls | troll com armadura de ferro |
| Guarda de Clã | 44 | elite | cidadela | `front_guard` (bloqueia golpe físico de frente) | orc pesado com escudo-torre |
| Golem de Basalto | 45 | elite (raro) | nativo (encosta/Forja) | lento, área no chão; caçada do quadro | golem existente, cor basalto + fendas de lava |

**Pacing por nível** (o jogador sobe ~1 nível a cada ~65–68 min):
- **40–41** sopé + Minas: Assassino Goblin, Lobo Atroz, Trolls 38 de escolta; caçada de Golem só a partir do 44.
- **41–42** Canil + estradas: Ginete do Lobo Atroz, Lança-Pedras, bandos com Agitador (36) de enchimento.
- **42–43** Forja Negra + Salão dos Matadores: Arco de Fogo, Senhor da Guerra, Salamandra, Matador.
- **43–45** encosta/Portão + cidadela: Brutamontes, Guarda de Clã, Golem de Basalto, elites de todas as linhas.
**Bandos de grupo**: Senhor da Guerra + 2 Guerreiros + Agitador; Brutamontes + 2 Trolls + Lança-Pedras; Matador + 2 Assassinos.
Alvo R8: `band_probe --from=40 --to=45` 0 `travou`, tempo por abate a ±25% da faixa 20–30, vida perdida 14–20% por caçada (35–40 deu 16%).
Materiais: Pele de Lobo Atroz, Escama de Salamandra, Basalto Rúnico, Aço Negro Orc (já existe), Aço Anão, Brasa de Kharzun.

---

## 4. Chefes (grupo primeiro: calibrar em grupo de bots, nunca pela vitória solo)

Regras: `BOSS_CROWD_MULT` sem mudança (exceção aprovada 2026-11-13: Durgash com `BOSS_CROWD_RAID`); lacaios com 0 XP via `summon`;
3 fases; berserk ~180–240 s (Kragmar 150 s; Durgash ×20, ver abaixo); **+1 assinatura por chefe** por cima do kit
([`act2-boss-signatures.md`](act2-boss-signatures.md), medida com ela ligada). **Alvos R8**: grupo completo de 4 ≥ 95% com 0,3–1 morte; 4 sorteados 65–85%; solo observado.
Vida/ATK pela F2 (`chefe` 45 = 177 750 HP / 160 ATK) × `unit_mods` **(H)**, calibrados na sonda (40 lutas, `--seed` padrão e 7).

| Chefe | Onde / nível | Fases e mecânicas (ferramentas existentes) | Ensina |
|---|---|---|---|
| **Presa-de-Cinza, a Mãe-Loba** (campo, opcional) | Canil, 41 | 100%: mordida + investida; 60%: uivo `summon` 2 Lobos Atrozes; 30%: `enrage`. Faixa **campo**: solo 60–100%, trio 90–100% | matilha; bom para o quadro de caçadas |
| **Mestre Matador Shazka** | `dg_slayers`, 43 | F1: golpes + faca envenenada (`mob_pick: soft`); F2 (70%): some (furtividade) e `summon` 2 Sombras-Aprendizes, `ward` 0,5 enquanto uma vive, reaparece nas costas de quem cura; F3 (35%): `barrage` de nuvens de veneno + execução em alvo < 30% | proteger quem cura; matar lacaio de `ward` |
| **Ulgra Presa-Atroz** (Clã do Lobo) | cidadela W, 44 | montada no lobo atroz: investida em linha, `pull` (corrente) no mais longe (`mob_pick: far`); F2: `summon` Ginetes; F3: `enrage` + chuva de lanças (`barrage`) | posição/kite controlado; tanque segura o puxado |
| **Gorbash Pele-de-Rocha** (Clã da Pedra) | cidadela E, 44 | regeneração ×0,3 (F3; fogo/veneno corta); F2: `summon` 2 Xamãs-Pedra com `ward` 0,5; pedregulho no mais longe; F3: abalo que atordoa + desabamento (`barrage`) | fogo/veneno no troll (AC-20), foco no Xamã |
| **Kragmar Martelo-Negro** (Clã da Forja) | cidadela N-NE, 44 | martelo + ondas de lava (`barrage` em linhas); F2: `summon` Golens de Forja (pequenos); F3: forja superaquecida = `berserk_after` mais cedo (150 s) — corrida de DPS | DPS sob pressão de chão |
| **Durgash, o Grão-Senhor da Guerra** (D12) | trono, 45 — **raide de 5** (D4) | **F1 (100–70%)**: talho 150°, investida, machado arremessado (`mob_pick: far`), `rally` 18 m. **F2 (70–40%)**: finca **3 Estandartes de Clã** (lacaios parados; `ward` 0,6 enquanto ≥ 1 vive; cada um dá a aura do seu clã: Lobo = velocidade, Pedra = regeneração, Forja = queimadura no chão em volta). **F3 (40–15%)**: `pull` corrente + Terra Rachada (`barrage` em linhas), `summon` Guarda de Clã a cada 30 s. **F4 (< 15%)**: `enrage` + `say`; berserk ×20 (`berserk_mult`; aprovado 90 s, tempo final reajustado junto com a vida para a luta de ~100 s). `intro`/`last_words` (texto do narrative-director) | papéis completos: tanque segura, cura aguenta F3, dps divide-se para os estandartes |

**Alvos da raide (D4)**: 5 completo (Guardião, Sacerdote, Executor, Fogo + Bispo Batalha **ou** Druida Urso) ≥ 90% com 0,5–1,5 morte,
**~100 s** (usuário 2026-11-13; era 90–150 s); 5 sorteados 60–80%; 4 completo **tem de perder** (≤ ~20%; o berserk ×20 separa 4 de 5).
Reforço por pessoas próprio: `BOSS_CROWD_RAID["boss_durgash"]` = `[1, 1, 1, 2, 4,9, 3,25]` (aprovado 2026-11-13). Pontos de partida **(H)**:
`unit_mods` hp ×2,4 / atk ×1,5 (Ghar 40: 1,9/1,45). Estandarte: vida ~4% do chefe cada. Bots precisam mirar estandarte (WP8).

Arenas provisórias: as sondas rodam no mapa final quando existir; antes, numa arena do `boss_probe` (como na fase 1).

---

## 5. Missões

XP por `QuestsCatalog.scale_xp` (40–50% da faixa, 10+ missões por faixa — checks existentes). Ids `hx_*` como no Ato II.

**Linha principal (10)** — cada uma muda o cenário (R4):
1. `hx_kh_arrival` *A Ponta de Lança* — REACH o acampamento + TALK Comandante (K0).
2. `hx_kh_scouts` *Olhos no Escuro* — KILL Assassinos Goblin nas estradas (ensina furtividade).
3. `hx_mines` *Correntes Quebradas* — KILL capatazes + TALK escravos → **K1**.
4. `hx_kennel` *O Canil* — KILL Ginetes do Lobo Atroz + Presa-de-Cinza → K1b (frente do Canil cala).
5. `hx_black_forge` *A Forja Negra* — KILL Senhor da Guerra da Forja + COLLECT Aço Negro → K1c.
6. `hx_slayers` *O Salão dos Matadores* — Mestre Matador Shazka → K1d. (`hx_slayers_open` = entrada, dada pelo Xamã Exilado.)
7. `hx_citadel_gate` *O Aríete* — defender o aríete da Aurora até o portão (investida inversa: leva aliada + `RaidSystem` sobre ela) → **K2**.
8–10. `hx_clan_wolf` / `hx_clan_stone` / `hx_clan_forge` — um chefe de clã cada, **qualquer ordem** (`prereq_all` → K3).
11. `hx_warlord` *O Trono de Kharzun* — Durgash → **K4**; o Comandante dá `hx_act2_epilogue` (voltar ao Porto Esperança, festival, tela "Fim do Ato II").

**Paralelas que crescem** (toda cabana tem cadeia — `_check_places`):
- *O Ferreiro Anão* (3, Ferreiro Anão, pós-K1): ferramentas nas Minas → Basalto Rúnico → CRAFT; destrava aprimoramento 40+ (D11).
- *Ecos da Noite* (3, Xamã Exilado + Faroleira): inscrições nas Minas → fogos a leste (gancho já aprovado) → visão no trono pós-K4 (D6).
- *Ovos do Lobo Atroz* (3, posto dos libertos, pós-K1b): roubar ovos no Canil → chocar (COLLECT carne) → montaria (D5).
- *O Xamã Exilado* (2, cabana): ervas de cinza + Totem dos Ventos; se os Desertores foram ajudados (E4), um passo extra com o mercador orc.
- *Brasas da Forja* (quadro, `repeatable`) + caçadas geradas ↻ (Golem de Basalto, Salamandra, Lobo Atroz).
- **Prova 45** (D7): `hx_asc45_<classe>`, Arauto dos Mestres no acampamento, requer nível 45 + `hx_asc_<classe>`: matar um chefe de clã
  usando a ascensão (contagem pela sim: skill `ascension` acertou o chefe) → moedas + título; 0 XP, 0 ponto de ascensão (os 36 já fecham no 45).

**Contra-ataque / Ofensiva (D8)**: `MapsCatalog.RAIDS["field_kharzun"]` com 2 rotas (Canil → portão leste do hub; Cidadela → portão norte),
levas de Ginetes do Lobo Atroz + Assassinos (+ Senhor da Guerra a cada 3ª), relógio só com o jogador no mapa. Guarnição do acampamento
com `KHARZUN_GUARD_POWER` (como `PORT_GUARD_POWER`): **com 0 bots repele ≥ 75%** (regra do autor para o porto, estendida). Pós-K2:
`ASSAULTS` da Aurora na cidadela (`ASSAULT_FORT_MAX` 4 / 90 s, `ASSAULT_FORT_POWER` 0,5 — apoio, não limpeza).

---

## 6. Recompensas (nível 45)

- `MAX_LEVEL` 40 → **45**; `XP_BANDS`/`XP_QUEST_SHARE_BAND` ganham 40–45 (F1: 44→45 ≈ 75 390, AC-05).
- `LEGENDARY_LEVELS` + **45**: os 24 conjuntos de build e os 24 híbridos de 45 **já existem nos dados** (`balance.gd` linha ~739) e passam a
  cair/aparecer na Relicária; preço 9 moedas (F10, sem mudança). Fusões 45 pela F-FUS1 (tier 8).
- Talentos linha 45 e refinos 45 já implementados: só "acordam" com o nível.
- Ferreiro Anão (D11): Aço Anão (+1..+5) e Brasa de Kharzun (+6..+9) em lendários 40+ (`PLUS_KHARZUN_*`, espelho de `PLUS_DAWN_*`).
- Chefes: Moedas Lendárias (principais e chefes, regra atual) + troféu de material (Presa de Ulgra, Coração de Basalto, Martelo Partido,
  Estandarte de Durgash) usados nas receitas de joia/capa 45 (`RecipesCatalog.gear_recipes` tier novo).
- Montaria lobo atroz (D5), título da Prova 45, "Fim do Ato II".
- Sem tier comum novo (32 e 40 bastam, R7).

---

## 7. Música, som e vida

- **Música** (`build_music.py`, CC0 conferido, `Music.MAP_THEME`, check `_check_music`): `kharzun` (pesado, tambores lentos) para o campo
  e `dg_slayers`; `kharzun_citadel` (raide, coro grave); "chefe" e "investida" do Ato I por cima; festival reaproveita o do Ato I.
- **Sfx** (`build_sfx.py`, `Sfx.VOL`): borbulhar de lava (laço perto da lava), martelo de forja (Forja/Ferreiro Anão), corrente partindo,
  fumaça de sumir (Assassino/Matador), uivo do lobo atroz (`MOB_VOICE`), pedregulho, estandarte fincado, `AURA_SOUND` dos estandartes.
- **Vida** (`VILLAGERS`/`LIVING_NPCS`, `ambient_life.gd`, check `_check_living_act2` estendido): soldados da Aurora treinando,
  carroças de suprimento vindo das Estepes (`prop_cart_draft` já existe), anões na bigorna (K1+), libertos carregando caixas (`CarryPose`),
  corvos/abutres, brasas no ar perto da lava, vagonetes nas Minas; falas novas de bots (`place:kharzun`).
- **Visual de leitura**: estandarte com anel no chão da cor do clã; Matador com aviso curto (fumaça) antes do golpe; lava com brilho
  — revisar com `--tour` e `--buff_shot` para buffs novos (`BuffLooks.LOOKS` tem check).

---

## 8. Orçamento de desempenho (AC-36 — não muda; se apertar, otimiza-se a sim)

| Medida | Limite | Como medir |
|---|---|---|
| Tick médio com Kharzun carregado + porto em investida + 10 bots | **≤ 10 ms** (era 5; usuário 2026-11-13) | `tools/tests/sim_probe.tscn -- --phases --map=field_kharzun` e `--census` |
| Monstros no campo / na cidadela | ≤ 140 / ≤ 120 vivos (alvo de desenho, não regra) | `sim_probe --census` |
| FPS no hub com 10+ bots e investida | nenhum trecho < 25 FPS no `PerfWatch` | `--perf --perf_at=<hub x,z>` |
| Draws | ≤ dos fortes das Estepes (dress em lote por célula de 36 m) | `--perf` (`visible_pass`, `shadow_pass`) |
| GLB por mapa | ≤ ~6 MB (fortes atuais 4,2–4,4 MB) | tamanho do arquivo |
| Kits | < 200 malhas | check existente (AC-35) |
Lava = colisor de água (grade existente); estandartes e lacaios contam no laço de entidades — nada de alocar por entidade por tick.

---

## 9. Pacotes de trabalho (agentes em paralelo)

Regra do autor: no máximo 3–4 agentes, 1 de Blender (Fable só para Blender), ≤ 2 processos Godot por agente; cada agente no seu
worktree semeado, merge 3-way por arquivo. Tamanho: P (≤ ½ dia de agente), M (~1 dia), G (2+ dias).

| WP | O quê | Agente | Depende de | Tam. |
|---|---|---|---|---|
| WP0 | Aprovar este plano (feito 2026-11-12); atualizar `ato2-horda.md` (R2/R4/OQ 1 e 5) e `docs/DESIGN.md` | game-designer + autor | — | P |
| WP1 | Teto 45: `MAX_LEVEL`, faixas de XP, `LEGENDARY_LEVELS` 45, Relicária 45, F5 no 45 (≤ 1,215), `web_probe --level=45` | class-designer | WP0 | M |
| WP2 | `build_kharzun.py` (vale, lava, hub, POIs, lugares, estradas, pontes, marco) + `/layout-zone` ≥ 8 + JSON | blender-modeler (Fable) | WP0 | G |
| WP3 | Monstros 40–45 no catálogo (F2, escoltas, skills, loot) **com stand-ins**; band_probe 40–45 | world-builder | WP0 | M |
| WP4 | Modelos: 7 variantes da Horda + 3 nativos + 6 chefes (`boss_extras`) + montaria lobo atroz | blender-modeler (Fable) | WP2 (slot de Blender) | G |
| WP5 | Mapa na sim: `maps_catalog` (campo, spawners, NPCs, GATHER, cristal), portal `to_field_kharzun` real, estágios K0–K4, RAIDS, guarnição | world-builder | WP2 (JSON), WP3 | G |
| WP6 | `dg_slayers` + `kharzun_citadel` (Blender: `build_dungeons`/laço da cidadela; sim: `DUNGEON_DEFS`, alas, portões, ASSAULTS) | Fable + world-builder | WP2, WP5 | G |
| WP7 | 6 chefes: skills, fases, falas-placeholder; `boss_probe` (40 lutas por linha, raide de 5) | world-builder + systems-designer | WP3; arena final pede WP6 | G |
| WP8 | IA: bot mira estandarte/lacaio de `ward` na raide, proteger quem cura do Matador, raide de 5 (posições), viagem a Kharzun aos 40, uso da montaria | ai-programmer | WP3, WP7 | M |
| WP9 | Missões (11 principais + 5 cadeias + Prova 45 + epílogo) + "Fim do Ato II" + `docs/roteiro_40_45.md` | world-builder (+ narrative-director p/ texto) | WP5, WP7 | M |
| WP10 | Recompensas: Ferreiro Anão + `PLUS_KHARZUN_*`, receitas 45, materiais, ícones (`item_icons`), montaria | class-designer | WP1, WP9 | M |
| WP11 | Música, sfx, vida (VILLAGERS, ambient, falas) | sound-designer + world-builder | WP5 | M |
| WP12 | Integração + QA: suíte completa, smokes 8 classes, tours, sondas, perf, evidências, DESIGN/README | qa-lead + integração | todos | M |

**Ondas** (3 agentes + 1 Blender):
1. **WP1** (class-designer) · **WP3** (world-builder, stand-ins) · **WP2** (Fable).
2. **WP5** (assim que o JSON do WP2 sai) · **WP7** em arena provisória · **WP4** (Fable).
3. **WP6** (Fable + world-builder) · **WP8** · **WP9**.
4. **WP10** · **WP11** · **WP12** (merge final, sem commit até o autor mandar).
Caminho crítico: WP2 → WP5 → WP6 → WP7 (arena final) → WP12. O slot de Blender é o gargalo: stand-ins evitam que WP3/WP7/WP8 esperem.

---

## 10. Critérios de aceitação (testáveis)

Check = `check(...)` em `tools/tests/run_tests.gd` (nomes **propostos**). Sonda = comando headless. Evidência = PNG em `production/qa/evidence/kharzun/`.

- **KAC-01 (portal)** GIVEN jogador 40 sem um dos 3 fortes, WHEN entra em `to_field_kharzun`, THEN não passa e vê o texto do portão; com os 3 + nível 40 chega em `SPAWN_chegada_field_steppe`; a volta não tem portão. — `_check_act2_gate` (estendido).
- **KAC-02 (bots)** GIVEN bot 41 sem grupo, THEN caça em `field_kharzun`; bot 38 nunca escolhe Kharzun sozinho; nenhum bot entra em `dg_slayers`/cidadela sozinho. — `_check_act2_bot_travel`.
- **KAC-03 (teto)** `MAX_LEVEL` 45, `xp_for_level(45)` = 0, 44→45 ≈ 75 390 (±1%), Relicária mostra 45 e cobra 9 moedas. — `_check_act2_progression`, `_check_act2_xp_curve`, `_check_act2_gear`.
- **KAC-04 (zona)** `field_kharzun` com os 4 tipos de lugar, tudo alcançável, lava só cruzável nas pontes, `level_range` 40–45, tema de música. — `_check_places`, `_check_music`, `_cross_river` (lava); `/layout-zone` ≥ 8 em ≤ 6 iterações + tour `-- --tour=<pasta> --tour_map=field_kharzun`.
- **KAC-05 (cidadela)** tudo alcançável; trono fechado até K3 e aberto depois; Ofensiva chega ao pátio sem atravessar sólido. — `_check_kharzun_citadel`, `_check_assault_routes`, `_check_assault_march`.
- **KAC-06 (estágios)** para cada gatilho K1–K4 o conteúdo é o do estágio, e sem ele o anterior; monstros antigos ficam até morrer. — `_check_act2_stages` (tabela K).
- **KAC-07 (Contra-ataque)** sem `presos`; com 0 bots o acampamento repele ≥ 75% em K0; K1b reduz a leva. — `raid_probe -- --map=field_kharzun --trials=20 --bots=0,1,3`.
- **KAC-08 (Horda)** estágios de cima com `escort`; atributos = F2 ±2%; Salamandra não queima; Matador some e reaparece em quem cura/atira, nunca no tanque. — `_check_horde_lines`, `_check_horde_stats`, `_check_horde_ai`.
- **KAC-09 (faixa)** `band_probe -- --from=40 --to=45 --trials=16 --why`: 0 `travou`, tempo por abate a ±25% da faixa 20–30; `--only=audit` com XP de missão 40–50% e 10+ missões.
- **KAC-10 (chefes de grupo)** Shazka e os 3 clãs: completo de 4 ≥ 95% (0,3–1 morte), 4 sorteados 65–85%. — `boss_probe -- --party=4 --comp=paladin:guardiao,bishop:sacerdote,berserker:executor,elementalist:fogo --trials=40 --boss=<id>` (+ `--seed=7`).
- **KAC-11 (raide)** Durgash: 5 completo ≥ 90% (0,5–1,5 morte, ~100 s); 5 sorteados 60–80%; 4 completo ≤ ~20% (berserk ×20, `BOSS_CROWD_RAID`). — `boss_probe -- --party=5 --comp=... --trials=40 --boss=boss_durgash --why`; bots matam ≥ 1 estandarte antes de 30 s na F2.
- **KAC-12 (campo)** Presa-de-Cinza: solo 60–100%, trio 90–100%. — `boss_probe -- --bands --boss=boss_dire_mother`.
- **KAC-13 (ascensão 45)** cada build com teia de ascensão cheia no 45: razão ≤ 1,215 (F5); `combat_probe -- --class=<id> --asc` 0 FLAG no 45; Prova 45 dá 0 ponto e 0 XP; Gêmeos (×1,078 sem nó 45) ganha o portão 45 **Fúria Gêmea** (`TWIN_FURY_ASPD`) e o Ciclone de Titã no `BOT_ORDER` (usuário 2026-11-13). — `boss_probe --asc`, `_check_ascensions`, `_check_twin_fury`.
- **KAC-14 (recompensas)** com K1, Ferreiro Anão aprimora lendário 40+ (e recusa < 40); montaria lobo atroz = velocidade do cavalo. — `_check_act2_stages`, `_check_kharzun_rewards`; evidência `--bag_shot=<png> --wins= --enhance`.
- **KAC-15 (fim)** `hx_warlord` + epílogo → festival no porto e no acampamento e tela "Fim do Ato II". — check do estágio + evidência `-- --autostart=<c> --act_end_shot=<png>`.
- **KAC-16 (desempenho)** `sim_probe -- --phases --map=field_kharzun` ≤ 10 ms/tick; `--perf --perf_at=<hub>` sem trecho < 25 FPS; kits < 200 malhas.
- **KAC-17 (DoD)** `--import` + suíte completa 0 failed + smokes das 8 classes (`-- --autostart=<c>` e com `--ascend --level=45`) 0 `SCRIPT ERROR`; export + smoke do .exe.

---

## 11. Riscos

| Risco | Prob. | Impacto | Mitigação |
|---|---|---|---|
| Slot único de Blender atrasa tudo (zona, 3 mapas, ~17 modelos) | alta | alto | stand-ins primeiro (deu certo nas Estepes); WP2 antes de WP4; cidadela gerada por laço |
| Tick > 10 ms com campo + cidadela + porto em investida | média | alto | censo cedo (WP5), `AWAY_MAP_EVERY`, teto de vivos; regra do autor: otimizar a sim, não cortar |
| Raide de 5 ruidosa/lenta de calibrar (40 lutas × 5 bots, sonda lenta em derrota) | alta | médio | 2 sementes, ≤ 2 Godot por agente, medir estandartes isolados antes; arena provisória |
| IA não lê estandarte/`ward` nem protege quem cura do Matador | média | alto | WP8 antes da calibragem final; `--why` (`PERDAS_COMO`) como métrica |
| Poder no 45 passa do orçamento (híbridos 45 + refinos 45 + talentos 45) | média | médio | KAC-13 antes de calibrar chefes; F5 e G_5n medidos primeiro |
| Furtividade do Matador frustra (morte "do nada") | média | médio | aviso de 0,5 s (fumaça + som), nunca no tanque, execução só < 30% |
| Texto/lore final ausente (Ecos, falas do Durgash) | alta | baixo | placeholders marcados; narrative-director antes do WP9 fechar |
| Fusões ainda com G_5n fora da faixa em 5/8 (pendência de orçamento) | já existe | médio | não bloqueia Kharzun; medir no 45 junto com KAC-13 |
| Save: subir `MAX_LEVEL` com personagem no 40 e XP acumulada | baixa | médio | mesmo caminho do 35→40 (AC-06); usar `TEST_SLOT` |

---

## 12. Perguntas abertas (além das decisões D1–D12)
1. Nomes finais dos chefes (Durgash, Shazka, Ulgra, Gorbash, Kragmar, Presa-de-Cinza) — narrative-director.
2. A Prova 45 deve dar algo visível (aura/insígnia no boneco) além do título? Hoje: só título + moedas.
3. Depois do Ato II: o Porto Esperança e o acampamento ficam como hubs de fim de jogo (caçadas ↻, chefes que voltam em 2 min)? Recomendo sim, sem regra nova.
