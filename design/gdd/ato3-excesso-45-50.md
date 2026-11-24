# Ato III — Parte 1: O Excesso (45–50) — PLANO

> **Status**: **Rascunho para aprovação** — decisões D1–D14 marcadas "Recomendado"; nada implementado.
> **Author**: game-designer (Claude) · **Data**: 2026-11-21 · **Base**: master `9cf9077`
> **Decisões do usuário (2026-11-21, vinculantes)**: Ato III em 3 partes, só 45–50 agora; tema = demônios do excesso, do
> prazer e da perfeição (inspiração temática apenas: **nomes, lore e desenhos nossos**, regra "nomes e arte nossos" do 3º andar);
> cidade humana corrompida em festa eterna (hub com cristal) a leste de Kharzun + campos tomados por cultos + Fenda para o reino
> dos demônios com o chefe 50; entrada = portal a leste do `field_kharzun` (nível 45 + `hx_act2_epilogue`); opcionais: 2–3
> masmorras, 2 chefes de mundo, raide de 5 mais difícil que o chefe principal, eventos "Festim Sem Fim" no `RoadEventSystem`;
> **sem** missões de escolha-tentação; teto 50, teia 46–50, tier comum 48, lendários/acessórios 50 (malhas do Ato II, paleta nova),
> começo rápido 45; combate = **demônios rápidos e esquivos, sem mecânica nova de encanto/vício**.
> **GDDs pai/irmãos**: [`ato2-horda.md`](ato2-horda.md) (F1, F2, F10, R5, R6), [`kharzun-fase3-plan.md`](kharzun-fase3-plan.md) (formato),
> [`act2-boss-signatures.md`](act2-boss-signatures.md) (assinaturas, regras R-A..R-G), `living-towns` (eventos de estrada).
> **Fontes lidas**: os três GDDs acima; `data/balance.gd` (`MAX_LEVEL`, F1/F2, `LEG_ACC_*`, `WEB_GAIN_LATE`, `EVENT_*`,
> `BOSS_CROWD_*`); `data/schemas/skill_def.gd` (`EFFECT_KEYS`), `monster_def.gd`; `core/sim/systems/road_event_system.gd`,
> `world_sim.gd` (esquiva l.1971, `strikes` l.1083); `quests_catalog.gd` (`hx_ec_vision` "A Noite que Anda"); `maps_catalog.gd`
> (ganchos "do leste"); `start_catalog.gd` (`PRESETS`).

---

## 0. Decisões (para o usuário)

> **Decididas pelo usuário em 2026-11-21:** D2 **(a)** chegada direto em Lumeria; D4 **(b)** sem campo de esquiva de
> monstro: "esquivo" = bote, recuo, furtividade e atiradores que mantêm distância (nada de `MonsterDef.evasion`);
> D5 **(a)** ascensão parada no 45; D6 **(b)** só conjuntos de build no 50 (híbridos e Ápice do 50 ficam para a parte 2).
> As demais seguem a recomendação da tabela (Festim só nos campos, sem montaria nova, raide com título + visual).

| # | Decisão | Opções | Recomendado | Por quê (uma linha) |
|---|---|---|---|---|
| D1 | Nomes de trabalho | (a) **Amarante, a Que Nunca Murcha** (deusa, nunca aparece em pessoa na parte 1) · **Lumeria, a Festa Eterna** · **Vinhas do Perfume** · **Avenida do Cortejo** · **o Jardim Sem Fim** atrás do **Véu Rasgado** · (b) outros do narrative-director | **(a)** como placeholder | Originais, pronunciáveis em pt-BR; nada lembra nome de Warhammer. Texto final = narrative-director. **2026-11-24 (usuário):** Sylvaré → Amarante; Demônias da Sede → as Veladas (Matriarca Velada; assinatura Brinde Dividido). Demais trocas da proposta (`production/narrative/act3-names-proposal.md` §1-§5) ainda sem decisão. |
| D2 | Onde o portal do Kharzun chega | (a) **direto no hub**: portão oeste de Lumeria, Bairro dos Lúcidos · (b) no `field_perfume`, com a cidade a ~100 m | **(a)** | Padrão do Ato II (o navio chega no Porto); o 1º passo de terra nova é um lugar seguro com cristal. |
| D3 | Quantos mapas | (a) **`city_lumeria` + `field_perfume` + `field_parade` + `rift_garden` + 2 masmorras + 1 opcional + sala da raide (`rift_heart`)** · (b) sem a 3ª masmorra | **(a)** com a 3ª masmorra (Conservatório) em **onda 4** (cortável) | O usuário pediu 2–3; a 3ª entra se o tick e o slot de Blender deixarem. |
| D4 | "Esquivos" — esquiva de monstro | (a) **campo novo `MonsterDef.evasion`** (0–25%) lido na rolagem de esquiva que já existe (hoje só personagem esquiva: `target.is_character()`, `world_sim.gd` l.1971); chefes sempre 0 · (b) sem esquiva de monstro: "esquivo" = saltos, `dash`, furtividade do `ShiftSystem`, `kite`, golpe rápido | **(a)** | É a palavra que o usuário usou e é a mesma regra do jogador (não é mecânica nova de encanto); 1 campo + 1 condição + check. **Muda esquema (`automation_always_ask`)**. Chefe 0 para não deixar a sonda ruidosa. |
| D5 | Ascensão depois do 45 | (a) **congelada**: `ASC_MAX_LEVEL` fica 45, nada de ponto/refino 50 · (b) +3 pontos/nível até 50 e refinos 50 | **(a)** | O orçamento F5 (+21,5% no 45) já está medido e a parte 1 não tem onde gastar 15 pontos sem conteúdo novo de ascensão (8 classes × 3 builds). Partes 2–3 decidem. |
| D6 | Híbridos e Ápice no 50 | (a) **conjunto de build 50 + híbrido 50** (mesmas regras do 45, tier 9); **Ápice fica no 45** · (b) só conjunto de build · (c) tudo, com Ápice 50 | **(a)** | O híbrido sai de laço (`GearCatalog`) quase de graça; o Ápice tem regra própria por build (`FusionEffects`) = trabalho de 24 regras. |
| D7 | Escala dos monstros 45–50 | (a) **F2 continua** (`Balance.horde_stat`, linear até 50) com `mod_unidade` "demônio" (vida ×0,8, ATK ×1,15, golpe mais rápido) · (b) âncora nova `ACT3_ANCHOR45` | **(a)** | A F2 é linear e já calibrada no 45 (KAC-09); uma âncora nova obriga a recalibrar tudo. |
| D8 | Chefe principal 50 | (a) **grupo de 4** (como os chefes de clã; `BOSS_CROWD_MULT` normal) · (b) raide de 5 | **(a)** | O usuário quer a raide "mais difícil que o chefe principal"; o principal fecha a história para quem joga com 4. |
| D9 | Raide opcional | (a) **"O Eco de Amarante"**, sala própria `rift_heart` (`BOSS_CROWD_RAID`, berserk ×20) aberta depois do chefe 50; 5 completo ~80% em ~120 s, 4 completo ≤ 10% · (b) raide = versão "difícil" do chefe principal | **(a)** | Luta própria, recompensa própria (título + moedas + troféu), sem desvalorizar a luta da história. |
| D10 | Os foliões da cidade | (a) **hostis só nos bairros de fora**; o Bairro dos Lúcidos (hub) é murado e seguro; bairros viram seguros por estágio (L1–L4) · (b) foliões neutros que só atacam quem chega perto | **(a)** | Regra de `zonas.md` (hub seguro, 10+ bots) com o mundo que cresce (R4 do Ato II); (b) pede regra nova de aggro. |
| D11 | Chefes de mundo | (a) **2 chefes de campo** (Vindima, Prima-Donna), afinados para **trio**, renascem em `WORLD_BOSS_RESPAWN_S` (600 s) · (b) afinados para 5 | **(a)** | Faixa "grupo" da Mãe-Loba (trio 75–100%) já existe no `boss_probe --bands`; 5 já é a raide. |
| D12 | Montaria/visual por estágio | (a) **sem montaria nova**; a Fenda **aceita montaria** (`mounts_ok`), masmorras não · (b) montaria nova (Galgo de Seda) | **(a)** | Escopo; lobo atroz acabou de sair. Fica como pergunta aberta. |
| D13 | Aprimoramento de lendário 50 | (a) **Ferreiro Anão continua** (`PLUS_KHARZUN_LEVEL` 40 cobre 50; ele vai para o Bairro dos Lúcidos em L1) · (b) ferreiro e materiais novos `PLUS_LUMERIA_*` | **(a)** | Zero regra nova; o anão dá continuidade de personagem. |
| D14 | Fim da parte 1 | (a) **tela "Fim do Ato III — Parte 1"** + epílogo "Manhã em Lumeria" (estágio L4) · (b) só missão | **(a)** | Mesmo padrão de "Fim do Ato II" (KAC-15); marca o corte para as partes 2–3. |

---

## 1. Objetivos e fantasia (45–50)

**Objetivo de produto**: levar `MAX_LEVEL` de 45 a **50**, abrir o Ato III com um inimigo de identidade oposta à Horda
(a Horda era peso, aço e clã; o Excesso é **velocidade, beleza e cansaço**), e entregar a primeira raide **opcional**.
Nenhuma regra nova de sim se uma ferramenta existente resolve: fases, `ward`, `summon`, `barrage` + Hazard v2 (R-A), marca
(R-B), canal (R-C), sequência `repeat` (R-D), cobertura (R-E), cópias `decoys` (R-F), `mob_pick`, `strikes`, `dash`,
`stealth`, `ShiftSystem` (`shift_forms`, `shift_stealth`, `kite`), auras de facção (F4), `RaidSystem`, `WorldState`,
`RoadEventSystem`. Única exceção proposta: D4 (`MonsterDef.evasion`).

**Fantasia (MDA)** — estética-alvo: **Challenge** (ler monstros rápidos) e **Fellowship** (o grupo protege quem cura de saltos),
com **Discovery/Narrative** (a cidade bonita demais que esconde a fome). "A noite que anda do leste não é escura: é uma festa que
não deixa ninguém ir para casa."
- **45–47 — Lumeria**: a cidade toca música há 40 anos; o grupo entra num bairro murado de sobreviventes (os **Lúcidos**), cala os
  sinos e limpa os vinhedos. Os inimigos são **humanos** (foliões, convertidos) e o perfume que deixa tudo lento.
- **47–49 — o Cortejo**: o desfile que nunca termina leva para o palco onde o Véu foi rasgado; aparecem os **demônios** de verdade
  (bailarinos, galgos, coros, reflexos). O grupo aprende que **quem fica parado leva a dança**.
- **49–50 — o Jardim Sem Fim**: o reino de Amarante começa no palco. A Anfitriã fecha a parte 1; o Eco de Amarante é o teste de 5.
- **SDT**: Autonomia (masmorras e chefes de mundo opcionais, ordem livre entre Adegas e Galeria após L1) · Competência (cada chefe
  ensina um verbo de movimento: sair, interromper, usar cobertura, ritmo, ler a sequência) · Relação (os Lúcidos, o vinhateiro, a
  cidade que acorda em L4, o Ferreiro Anão que veio junto).
- **Arco narrativo (ganchos já no jogo)**: Cap. Odran ("Eles fogem do leste", `port_memorial`), Urzog ("Alguma coisa empurra ela do
  leste"), o Totem ("O que quebrou o grande veio do leste. Não dê nome"), Ushka e **`hx_ec_vision` "A Noite que Anda"** ("Uma noite
  que anda, a leste, sem lua"). A parte 1 **revela** a noite: são as lanternas de Lumeria que nunca se apagam — vistas de longe, um
  clarão sem lua. A Horda fugiu porque os clãs que desceram para a festa nunca voltaram. O nome de Amarante só é dito na Fenda.
- **Ritmo** (F1): ~68,5 min no 45 → ~71,5 no 49; faixa 45–50 ≈ **5,8 h** (missões 50% do XP).

---

## 2. Zonas

### 2.1 Mapa do mundo
```
 field_kharzun ──(garganta leste, NOVA; nível 45 + hx_act2_epilogue)──> city_lumeria (portão oeste = Bairro dos Lúcidos)
                                                                          │ portão norte          │ portão sul-leste
                                                                   field_perfume (45–47)    field_parade (47–49; nível 47 + hx3_bells)
                                                                     └ dg_cellars (46–47)      ├ dg_conservatory (48–49, opcional, onda 4)
                                       city_lumeria: dg_mirrors (48–49, Palácio, hx3_bells)    └ Palco Grande ─(nível 49 + hx3_mirrors + hx3_veil_open)─> rift_garden (49–50)
                                                                                                                         └ rift_heart (raide, 50; hx3_veil)
```
`field_kharzun.json` **não tem** `future_portals`: o WP2 abre uma garganta a leste no `build_kharzun.py` (sem mexer no resto:
JSON comparado antes/depois fora do portal novo + `SPAWN_chegada_city_lumeria`).

### 2.2 Tabela das zonas
| Mapa | Faixa | Hub / serviços | POIs (60–120 m do centro) | Marco | Leitura de cima |
|---|---|---|---|---|---|
| `city_lumeria` — Lumeria, a Festa Eterna (cidade ~240 × 240 m, muralha circular) | 45–47 (bairros de fora) | **Bairro dos Lúcidos** (W, murado, raio ~28 m, portas trancadas com barricadas de móveis): cristal, Irmã Celeste (líder), ferreiro, alquimista, mercador, Mestre de Skills, quadro de caçadas, Relicária, Ferreiro Anão (L1), Arauto (L1) | Praça dos Sinos (centro, campanário), Mercado das Taças (N), Ópera/Palácio do Duque (E, entrada `dg_mirrors`), Jardim das Fontes de Vinho (S), portões N e SE | **Campanário de vidro rosado** (torre de 18 m na praça, fora das estradas) | telhados claros em leque, ruas de pedra creme, **guirlandas e lanternas** em fileiras (leem de cima como linhas pontilhadas), confete no chão em tons do próprio chão (`floor_tones`); o Bairro dos Lúcidos é a mancha **cinza-azulada** sem enfeite |
| `field_perfume` — Vinhas do Perfume (vale) | 45–47 | Cabana do Vinhateiro (sem cristal) | Vinhedo em terraços (W), Lagar dos Pés Roxos (N, entrada `dg_cellars`), Santuário Profanado da Aurora (E), Acampamento dos Fugidos (S), Poço de Névoa (centro-N, chefe de mundo Vindima) | **Lagar gigante** com roda de pedra | fileiras curvas de videira roxa (faixas paralelas), névoa lilás baixa (fx), estradas de terra clara, manchas de uva pisada em tons do chão |
| `field_parade` — Avenida do Cortejo (vale) | 47–49 | Posto dos Lúcidos (acampamento pequeno, cristal em L2) | Arquibancadas (W), Carros Alegóricos Tombados (N), Conservatório (E, `dg_conservatory`), Palco Grande (centro-S, chefe de mundo Prima-Donna; em L3b abre o Véu) | **Arco do Triunfo de fitas** sobre a avenida (fora da rota, ao lado) | **uma avenida larga** (8 m) em S, ladeada por palcos baixos e bandeirolas dobradas (`Dress.flag`), chão de mosaico desbotado; o resto é campo de festa abandonado |
| `rift_garden` — o Jardim Sem Fim (mapa próprio, gerado por laço) | 49–50 | Posto da Aurora na boca do Véu (L3b; cristal em L4) | Alameda dos Espelhos, Lago de Perfume (colide como água), Labirinto de Sebes (POI, sem becos acidentais), **Pavilhão da Anfitriã** (N, arena do chefe 50), Porta do Coração (`rift_heart`, L4) | **Coroa de cristal flutuante** sobre o pavilhão (visual, sim plana) | sebes altas como **muros baixos** (≤ 3 m perto da estrada), céu rosa-pérola, flores gigantes, chão de mármore claro; a cor quente fica no céu e nas flores, **nunca** saturada no chão (§4.4) |
| `dg_cellars` — Adegas do Banquete (masmorra, `parent_map: field_perfume`) | 46–47 | — | `layout` 3 salões + 1 lateral: tonéis, mesa do banquete, câmara do lagar | — | pedra escura úmida, poças de vinho foscas (`pool_glow: False`) |
| `dg_mirrors` — Galeria dos Espelhos (masmorra, `parent_map: city_lumeria`) | 48–49 | — | `layout` em cruz: foyer, galeria longa, camarins, Salão Espelhado | — | piso xadrez em tons do chão, espelhos = lacaios parados (R-E) |
| `dg_conservatory` — Conservatório do Coro Ferido (opcional, `parent_map: field_parade`) | 48–49 | — | 3 salões em anel + sala de concerto | — | bancadas em semicírculo, tubos de órgão |
| `rift_heart` — o Coração do Jardim (raide) | 50 | — | uma arena redonda ~40 m, 4 pedestais | — | piso de espelho fosco, borda de pétalas |

Regras de `zonas.md` valem em tudo: vale ~240 m com borda natural (Lumeria = muralha + morros de vinhedo; Fenda = sebes e
penhascos de cristal), estradas catmull-rom de 4 m sem becos, 3–5 POIs, os **4 tipos de lugar** por zona de campo (`_check_places`):

| Zona | Cabana | Acampamento | Santuário | Entrada de masmorra |
|---|---|---|---|---|
| `city_lumeria` (como `city_port`) | Casa do Relojoeiro | Bairro dos Lúcidos | Capela Selada | Ópera (`dg_mirrors`) |
| `field_perfume` | Cabana do Vinhateiro | Acampamento dos Fugidos | Santuário Profanado da Aurora | Lagar (`dg_cellars`) |
| `field_parade` | Tenda do Ponto (ponto de teatro) | Posto dos Lúcidos | Altar da Máscara Partida | Conservatório |

### 2.3 Estágios (WorldState, `quests_completed`)
| Estágio | Gatilho | Muda |
|---|---|---|
| L0 Festa | chegada | Lúcidos trancados; bairros de fora cheios de foliões hostis; sinos tocam (laço de som); **Festim Sem Fim** na cidade e nos campos; portões N/SE da cidade abertos, Palácio fechado |
| L1 Silêncio | `hx3_bells` | sinos calam; Mercado das Taças vira seguro (foliões caem em sono: somem os spawners do N); Ferreiro Anão e Arauto chegam ao Bairro; portal para `field_parade` abre; Palácio abre |
| L2 Vindima | `hx3_cellars` | névoa do `field_perfume` cai pela metade (fx), vinhateiros libertos colhem (`LIVING_NPCS`, `CarryPose` caixas); cristal no Posto dos Lúcidos do Cortejo |
| L3 Reflexo | `hx3_mirrors` | metade das lanternas da cidade apaga (`if`/`unless` nos marcadores de fx); Duque libertado no Palácio (NPC, cadeia lateral); foliões do Jardim das Fontes somem |
| L3b Véu | `hx3_veil_open` | Palco Grande vira portal para `rift_garden`; Posto da Aurora na boca do Véu; Festim nas ruas da cidade para (os eventos ficam nos campos) |
| L4 Manhã | `hx3_veil` (+ epílogo) | **Manhã em Lumeria**: lanternas apagadas, gente varrendo confete, música do hub troca para tema calmo; cristal na Fenda; `rift_heart` abre; tela "Fim do Ato III — Parte 1" |

---

## 3. Monstros 45–50

Atributos **só pela F2** estendida (§6.2). Estágio de cima nasce com `escort` dos de baixo (regra do Ato II, AC-15). Facção
`"feast"` (aura de facção F4). Todos os desenhos são nossos: **nada de garra de caranguejo, chifres curvos em quatro braços,
língua longa de montaria bípede**. Silhueta-chave da facção: **máscara de porcelana lisa com uma única lágrima pintada**, fitas
e laços, membros longos, cores marfim + rosa-pó + ouro velho (demônios) e veludo vinho + creme (humanos).

| Família | Monstro | Nív. | Papel F2 | Mecânica (ferramenta existente) | Conceito de modelo |
|---|---|---|---|---|---|
| **Foliões** (humanos) | Folião Mascarado | 45 | comum | básico rápido (`attack_cooldown` ×0,8), Taça Arremessada (projétil com `slow` 25%) | humano do kit genérico, gibão listrado, máscara de meia-lua, taça |
| | **Convertido** | 47 | comum (base) | **`ShiftSystem`**: sorteia forma ao ganhar alvo — Bailarino (peso 2) ou Galgo (peso 1); morre como a forma, XP/saque pela base | humano com máscara rachada que brilha (`glow_rose`) |
| | Mestre de Cerimônias | 47 | elite | **aura** `festim` (F4: aliados +15% vel. de ataque, +15% de velocidade; morto = desânimo) + `rally`; escolta 3 Foliões | gordo alto, cartola de fitas, bastão com sinos |
| **Bailarinos do Véu** (demônios) | Bailarino | 46 | comum (hp ×0,8, atk ×1,15) | `strikes` 3 golpes (`weights` 0,3/0,3/0,4, `at` 0/0,15/0,3) + Salto Leque (clone de `mob_lynx_leap`, `dash` 8 m, `mob_pick: soft`); esquiva 15% (D4) | corpo fino de porcelana, sem braços humanos: **dois leques-lâmina** presos por fitas nos ombros, saia de fitas que gira |
| | Primeiro Bailarino | 48 | elite (hp ×0,7) | escolta 2 Bailarinos; `repeat` (R-D) de 3 saltos, cada um re-mirado e avisado em linha (R-A `line`); esquiva 20% | mais alto, coroa de fitas, quatro leques em leque nas costas (só visual) |
| **Galgos de Seda** (bestas) | Galgo de Seda | 46 | comum | matilha de 3; investida curta (`dash`) + mordida com `wound`/sangramento (`dot` físico); `speed` ×1,3 | `mob_kit.quadruped(kind="hound")` novo: galgo esguio, crina de seda longa, guizos no pescoço, sem olhos (máscara lisa) |
| | Galgo Alfa do Cortejo | 49 | bruto | puxa o carro alegórico vazio em ronda (`MOB_PATROLS`); `pull` (fita) no mais longe (`mob_pick: far`) | galgo maior com arreio dourado |
| **Coro Ferido** (sônicos) | Corista | 46 | comum (à distância) | `kite`; Nota Aguda: `barrage` 1 anel (R-A `ring`, `inner` 1,5) no alvo, avisado 1,2 s | figura de túnica com **boca costurada** e uma garganta de tubos de órgão no peito |
| | Maestro do Coro | 49 | elite | **canal** (R-C) "Uníssono" 3 s: se não quebrado, os Coristas a 12 m ganham buff de ATK +30% 10 s; quebra = `stun` 2 s nele; escolta 3 Coristas | regente com batuta-lança, fraque de penas |
| **Reflexos** (espelhos) | Reflexo Vaidoso | 48 | comum (hp ×0,6) | `decoys` (R-F) 2 cópias ao entrar em luta; furtividade curta (`stealth`) depois de levar golpe | figura plana de espelho com moldura dourada como "vestido"; mostra a silhueta de quem olha (tom do alvo) |
| **Incensários** (névoa) | Incensário Vivo | 47 | bruto (hp ×1,4) | lento; Fumo Doce: `barrage` R-A `linger` 4 s, `tick` 0,5 s (dano mágico pequeno + `slow` 30%); flutua (não pisa poça) | turíbulo de bronze do tamanho de um homem, correntes como pernas, fumaça lilás |
| **Vinhas** (nativas, `field_perfume`) | Vinha Sedenta | 46 | bruto (hp ×1,6, parada) | não anda; `root` 1,5 s + `pull` no mais longe; regeneração pequena (`regen` 0,5, F3 — fogo/veneno cortam) | cepa retorcida com cachos-bocas, folhas roxas |

### 3.1 Veladas (família principal dos demônios — aprovada pelo usuário em 2026-11-23)

Pedido do usuário (súcubos). Decisões: **família aprovada; chifres para TRÁS; SEM asas, só véus.** Viram a família demoníaca
principal da Avenida do Cortejo e da Fenda; **Vessaline** e a **Condessa Refletida** (chefe da Galeria) saem dela. Os Bailarinos
ficam como família secundária. Sem esquiva (D4): "esquiva" = furtividade, recuo, salto e distância. Mecânicas só com ferramentas
que já existem (rascunho do autor, ajustável no WP3/WP8).

| Monstro | Nív. | Papel F2 | Mecânica (ferramenta existente) | Conceito de modelo |
|---|---|---|---|---|
| **Sedutora** | 46 | comum demônio | entra em luta furtiva (`stealth`), 1º golpe é emboscada; garras rápidas (`strikes` 2); depois de bater, recua 5 m (`dash` para trás) | corpo esguio de porcelana marfim, chifres lisos para trás em ouro velho, véus rosa-pó em camadas, máscara com a lágrima |
| **Açoitadora** | 47 | comum demônio | chicote de fita-lâmina (cone longo 6 m) com sangramento (`wound`); `pull` no mais longe (`mob_pick: far`) | mais alta, chifres longos para trás, véu-capa, chicote de fitas na mão direita |
| **Cantora do Véu** | 48 | comum demônio (à distância) | `kite`; Lamento: projétil com `slow` 30% e `heal_pct_of_dmg` (cura a si); anel avisado (`barrage` R-A `ring`) a cada ~12 s | véu longo cobrindo o rosto até o peito, chifres curtos para trás, mãos abertas |
| **Matriarca Velada** | 49 | elite (hp ×0,8) | escolta 2 Sedutoras + 1 Açoitadora; `repeat` (R-D) de 2 saltos avisados em linha (R-A `line`); aura de facção `sede` (aliados +15% vel.) | maior, chifres grandes para trás com argolas de ouro, véus em cauda, coroa de fitas |

Modelos: uma base de corpo comum (`mob_kit`) com variantes por monstro; **nada de asa, cauda de demônio ou chifre curvo para
cima/frente**; a silhueta é chifre para trás + véus. Vessaline = a maior delas, com a cauda de fitas-lâmina (§4); a Condessa =
demônia de vestido espelhado e máscara dupla. Pacing: Avenida (47–48) Sedutora/Açoitadora/Cantora; Fenda (49–50) todas + Matriarca.
Bando: Matriarca + 2 Sedutoras + 1 Açoitadora.

**Esquiva** (D4): só comuns/elites demônios; teto `MOB_EVASION_CAP` 25; esquiva **não** pega dano no tempo, área avisada
(`dodgeable=false`) nem invocação/aura — atacante de área e de dano no tempo ganham papel natural contra o Excesso.

**Pacing por nível**: 45–46 Lúcidos/bairros + Vinhas (Folião, Vinha, Galgo, Corista) · 46–47 Adegas/Lagar (Incensário, Bailarino,
Mestre de Cerimônias) · 47–48 Cortejo (Convertido, Galgo, Reflexo, Primeiro Bailarino) · 48–49 Galeria/Conservatório (Reflexo,
Maestro, Primeiro Bailarino) · 49–50 Fenda (Galgo Alfa, todos os elites, bandos mistos).
**Bandos**: Mestre de Cerimônias + 3 Foliões · Primeiro Bailarino + 2 Bailarinos · Maestro + 3 Coristas · Galgo Alfa + 2 Galgos.
**Materiais** (comum / raro, também `SKILL_RANK_MATS` e joias do tier 48): **Fita do Festim** / **Porcelana Chorosa**; troféus de chefe
(Taça de Varo, Moldura da Condessa, Batuta Partida, Leque da Anfitriã, Coroa Vazia).

---

## 4. Chefes (grupo primeiro: calibrar em grupo de bots, nunca pela vitória solo)

Regras: vida/ATK pela F2 estendida (`chefe` 50 = **207 000 HP / 180 ATK**) × `unit_mods` **(H)**; 3–4 fases; lacaios 0 XP;
berserk 150–240 s; **uma assinatura** por chefe só com as regras compartilhadas R-A..R-G (`act2-boss-signatures.md`), medida
ligada; 40 lutas, `--seed` padrão e 7; `intro`/`last_words` placeholder até o narrative-director. Sem esquiva (D4).

### 4.1 Tabela
| Chefe | Onde / nível | Faixa | Fases (ferramentas existentes) | Assinatura · verbo |
|---|---|---|---|---|
| **Dona Vindima, a Vinha que Bebe** | `field_perfume`, Poço de Névoa, 47 — **mundo** | trio (D11) | F1: chicote de vinha (`pull`), cachos (`barrage` 3 círculos); F2 70%: `summon` 2 Vinhas Sedentas (`ward` 0,4); F3 35%: `enrage` + Fumo Doce em volta (R-A `linger`) | **Prensa** · *sair do centro*: a cada 28 s (K) puxa todos a ≤ 14 m (`pull`) e 1,5 s depois esmaga um círculo de 6 m em volta dela (R-A `circle`, `power` 2,2); quem correu fora leva 0 |
| **Varo Taça-Cheia, o Anfitrião** | `dg_cellars`, 47 | grupo de 4 | F1: talho com garrafão, Taça Arremessada no mais longe; F2 70%: `summon` 3 Foliões (escolta, não `ward`); F3 35%: Fumo Doce em linhas (R-A `line`) + `enrage` 15% | **O Banquete** · *interromper*: canal (R-C) 4 s a cada 35 s (K); `on_done` cura 6% e dá +25% ATK 12 s a ele e aos lacaios; quebra com `CHANNEL_BREAK_PCT` ou `stun` → `vuln` 15% 6 s |
| **A Prima-Donna do Palco** | `field_parade`, Palco Grande, 48 — **mundo** | trio (D11) | F1: Nota Aguda em 2 alvos, empurrão (`knockback`); F2 70%: `summon` 2 Coristas (`ward` 0,5); F3 30%: `enrage` | **Ária em Três Tempos** · *ritmo*: `repeat` (R-D) de 3 anéis em volta dela (R-A `ring`): perto (0–4 m), meio (4–8), longe (8–12) em sequência, 1,2 s cada; quem acompanha o ritmo dá um passo por tempo e leva 0 |
| **Mestra Ressoa, a Regente** (opcional, onda 4) | `dg_conservatory`, 49 | grupo de 4 | F1: batuta (estocada), Nota Aguda; F2 65%: 4 Tubos de Órgão (lacaios parados, `ward` 0,6, cada um um `barrage` rotativo); F3 30%: `enrage` + Uníssono | **Cânone** · *espalhar*: marca (R-B `spread`) em 3 vítimas `random`; cada marca que encosta noutra (≤ 4 m) dobra o dano das duas |
| **A Condessa Refletida** | `dg_mirrors`, 49 | grupo de 4 | F1: florete (`strikes` 4 golpes, `crit_last`), Salto Leque; F2 65%: `decoys` 3 cópias (R-F: sem sombra, 1 golpe); F3 30%: espelhos rachados + `enrage` | **Olhar Que Julga** · *usar cobertura*: a cada 30 s (K) ergue 3 **Espelhos de Pé** (lacaios parados `cover: 2,5`, R-E); 3 s depois, raio de toda a sala (`avalanche`-like, segmento chefe→alvo) em todos que **não** estão atrás de um espelho; cada espelho racha depois de proteger |
| **Vessaline, a Anfitriã do Véu** (**chefe principal**) | `rift_garden`, Pavilhão, 50 | **grupo de 4** (D8) | F1 100%: Cortejo (abaixo), leque (`cone`), Salto Leque `mob_pick: soft`; F2 70%: `summon` 2 Primeiros Bailarinos, `ward` 0,5; F3 40%: **Palco Seguro** = ilhas (R-A `invert`, como a Maré Cheia) + Fumo Doce; F4 15%: `enrage` + `say`; berserk 210 s | **Cortejo de Lâminas** · *ler a sequência*: `repeat` (R-D) de **4 investidas** (`dash` 10 m) em vítimas `random` (nunca o tanque), cada uma desenhada como faixa (R-A `line`, largura 2 m) **1,4 s antes** e todas as 4 faixas aparecem juntas na 1ª (lê-se a coreografia inteira); a cauda de fitas deixa a faixa com `linger` 3 s |
| **O Eco de Amarante** (**raide**, D9) | `rift_heart`, 50 | **raide de 5** | F1 100%: marca dupla que alterna `soak` (dourado) e `spread` (roxo) a cada 20 s (R-B); F2 70%: **Os Quatro Sentidos** — 4 pedestais (lacaios parados, vida ~3,5% do chefe cada, `ward` 0,6 com ≥ 1 vivo), cada um uma aura: Visão (aliados demônios +esquiva 10 → só cópias), Audição (Nota Aguda em todos a cada 6 s), Olfato (Fumo Doce em volta), Paladar (cura 1%/s do chefe); F3 40%: `decoys` 4 + ilhas `invert`; F4 15%: `enrage`; berserk ×20 (`berserk_mult`) aos ~120 s | **Brinde Dividido** · *ler juntar × espalhar*: a mesma marca R-B ora pede juntar (soak, `power` total 2,0 dividido), ora espalhar (spread); a cor e os pips dizem qual. Na F2 as duas vêm ao mesmo tempo em vítimas diferentes |

Modelos dos chefes: Dona Vindima = cepa gigante em forma de matrona com saia de folhas e tonel no ventre; Varo = humano obeso
de capa vinho, garrafão-maça, guardanapo no pescoço; Prima-Donna = cantora de vestido-gaiola com pássaros de porcelana; Ressoa =
regente com cabeça de tubos de órgão; Condessa = nobre de vestido espelhado e rosto de máscara dupla (frente/costas);
Vessaline = demônio alta, rosto liso com a lágrima dourada, **cauda de fitas-lâmina de 6 m** (a silhueta é a cauda); Eco de
Amarante = **vestido de espelhos sem corpo sob uma coroa vazia** e vapor perfumado onde seria o rosto (sem chifres, sem braços extras).

**Implementação WP8b (2026-11-23, aprovado pelo usuário):** os Espelhos de Pé da Condessa são **coberturas intocáveis** (`m["covers"]`, como os pedregulhos do Troll Rei), não entidades: bots não os matam por engano e reaproveitam a busca de cobertura. Sobem nos pontos `cover` do `boss_hint` (deslocamentos no `mirrors` da skill); o que protegeu racha (`crack` → `idle_cracked` no `BossSigView`) e deixa de proteger. F3 "espelhos rachados" = Chuva de Cacos + fúria. Cânone: marca R-B com `touch` (centros a ≤ 4 m dobram). Banquete: R-C com `on_done.self` e `on_break.vuln/vuln_time`. Números em `Balance.ACT3_BANQUET_*/GAZE_*/MIRROR_*/CANON_*`.

**Kit mínimo de chefe (`_check_boss_mechanics`, 2026-11-23):** as fases contam a F1 a 100% (2 limiares = 3 fases); cópias R-F relançadas na recarga contam como lacaios no ritmo (Condessa, Eco); Varo, Ressoa e Vessaline têm lacaios só na fase, em pontos fixos (`ACT3_PHASE_ADDS`); Varo (escolta) e Condessa (cópias) não têm `ward` (`ACT3_NO_WARD`); a marca R-B (Eco) e o Cortejo (faixas de 10 m rumo a quem não é o tanque, Vessaline) contam como resposta a quem luta de longe.

### 4.2 Alvos (R8 do Ato II, estendidos)
- **Chefes de grupo** (Varo, Ressoa, Condessa, Vessaline): completo de 4 (Guardião, Sacerdote, Executor, Fogo) ≥ 95% com 0,3–1 morte;
  4 sorteados 65–85%; Vessaline 90–150 s.
- **Mundo** (Vindima, Prima-Donna): solo 15–35%, trio 75–100% em 30–150 s (`boss_probe --bands`, faixa grupo); renascem em
  `WORLD_BOSS_RESPAWN_S`.
- **Raide** (Eco): 5 completo (Guardião, Sacerdote, Executor, Fogo + Bispo Batalha **ou** Druida Urso) **75–85%** com 0,5–2 mortes,
  ~**120 s**; 5 sorteados 45–65%; **4 completo ≤ 10%**. Ponto de partida **(H)**: `unit_mods` hp ×2,8 / atk ×1,6 (Durgash 2,4/1,5);
  `BOSS_CROWD_RAID["boss_sylvare_echo"] = [1, 1, 1, 2, 4,9, 3,25]` (tabela do Durgash). Calibrado (WP8b): `[1, 1, 1, 2, 8,5, 4,55]` — até o trio = o comum (regra de todo chefe de raide; o berserk ×20 aos 120 s segura grupos pequenos). Bots precisam: mirar pedestal (WP8 do
  Ato II já fez estandarte), soak/spread por cor (já fazem para Vorgul/Durgash).

### 4.3 Gramática de cor (FxManager.DANGER, regra de `conteudo.md`)
- **Dano** = vermelho-laranja (área fraca + borda + miolo que cresce): Prensa, faixas do Cortejo, Fumo Doce, anéis da Ária.
- **Seguro** = frio/areia: ilhas do Palco Seguro, sombra dos Espelhos de Pé (cobertura).
- **Dividir (soak)** = dourado com pips; **espalhar/controle** = roxo: marcas do Cânone e do Brinde Dividido, `pull`, `root`.
- Identidade pela **forma**, nunca pela cor contrária: o rosa/magenta da facção fica nos corpos, fitas e céu; **nenhum `glow_*`
  rosa no chão** (rosa saturado no chão confunde com dano e com roxo de controle). Golpe físico de demônio = tema `blood`.

### 4.4 Risco de paleta (para art-director)
A paleta do Excesso (rosa, lilás, ouro) cai em cima de **duas** cores de aviso (roxo = controle, dourado = soak). Regra proposta: chão
das 4 zonas só em tons do próprio chão (`floor_tones`, ±13% puxado para o cinza: creme, mármore, terra lilás muito dessaturada);
flores/fitas/céu podem ser saturados porque não são planos no chão. Check de chão: estender `_check_zone_dress`/revisão de cor.

---

## 5. Missões

XP por `QuestsCatalog.scale_xp` (40–50% da faixa, **10+ por faixa**). Ids `hx3_*`. **Sem** missão de escolha-tentação (decisão).

**Linha principal (13)**:
1. `hx3_arrival` *Música Atrás da Montanha* — REACH `city_lumeria` + TALK Irmã Celeste (L0). Dada pelo Comandante no Kharzun após o epílogo.
2. `hx3_masks` *Sem Máscara* — KILL 12 Foliões nos bairros de fora.
3. `hx3_bells` *Os Sinos Mudos* — KILL Mestre de Cerimônias do campanário + REACH o campanário → **L1**.
4. `hx3_vines` *Vinho que Não Acaba* — KILL 8 Vinhas Sedentas + COLLECT 6 Uvas Amargas (`field_perfume`).
5. `hx3_cellars_open` *A Porta do Lagar* — TALK Vinhateiro Bento (entrada; portão de missão da masmorra).
6. `hx3_cellars` *O Anfitrião das Adegas* — KILL Varo → **L2**.
7. `hx3_parade` *O Cortejo* — REACH `field_parade` + KILL 10 Galgos de Seda.
8. `hx3_converts` *Os Convertidos* — KILL 10 Convertidos (conta pela base, `ShiftSystem`).
9. `hx3_mirrors` *A Condessa Refletida* — KILL Condessa → **L3** (6 e 9 em **qualquer ordem** depois de 3: `prereq_all` no 10).
10. `hx3_veil_open` *O Véu Rasgado* — defender a procissão dos Lúcidos até o Palco Grande (leva aliada + `RaidSystem` sobre ela,
    mesmo molde de `hx_citadel_gate`) → **L3b**.
11. `hx3_garden` *O Jardim Sem Fim* — REACH `rift_garden` + KILL 4 Primeiros Bailarinos.
12. `hx3_veil` *A Anfitriã* — KILL Vessaline → **L4**.
13. `hx3_epilogue` *Manhã em Lumeria* — TALK Irmã Celeste → tela "Fim do Ato III — Parte 1" (D14).

**Paralelas que crescem** (toda cabana/acampamento abre cadeia — `_check_places`; nenhuma é escolha moral):
- *O Relojoeiro* (3, Casa do Relojoeiro, Lumeria): engrenagens no Mercado → COLLECT Porcelana Chorosa → o relógio da praça volta a
  andar (L1+: NPCs da cidade ganham rotina de dia/noite em `LIVING_NPCS`).
- *O Vinhateiro* (3, Cabana do Vinhateiro): Fumo Doce (KILL Incensários) → ferramentas no Lagar → CRAFT "Vinho Claro" (consumível:
  poção forte de MP; receita no alquimista).
- *Os Fugidos* (3, Acampamento dos Fugidos): achar 3 desaparecidos (REACH + TALK) → escoltar até o Bairro (NPCs novos no hub).
- *A Máscara Partida* (2, Altar do Cortejo): quebrar 5 máscaras (COLLECT de Convertidos) → **título** "Sem Máscara".
- *O Duque* (2, Palácio, L3+): libertar o Duque → abre o *Salão do Duque* (interior, `MapsCatalog.INTERIORS`), mercador de joias 48.
- *O Conservatório* (2, Tenda do Ponto, opcional): `hx3_choir_open` → Mestra Ressoa.
- **Raide** `hx3_echo` *O Eco* (Irmã Celeste, L4): KILL Eco de Amarante → moedas + título "Quem Não Dançou" + Coroa Vazia; 0 XP.
- **Repetíveis**: quadro dos Lúcidos (`repeatable`, caçadas geradas ↻: Galgo de Seda, Incensário, Reflexo, Vinha) + *Fitas do Festim*
  (COLLECT 10 Fitas → moedas e material raro).
**Contagem**: 13 principais + 15 paralelas (fora a raide) = **28 não repetíveis** na faixa 45–50 (≥ 10 ✓).

**Investidas**: o Festim **não** é investida. Em L0 os foliões fazem **Ronda do Festim** (`MOB_PATROLS`) nas ruas da cidade; sem
`RAIDS` em Lumeria (o hub é seguro por muro). A única investida é a da missão 10 (leva aliada).

---

## 6. Fórmulas

### 6.1 F1 estendida — XP para o próximo nível (45–49)
Sem mudança de fórmula (Ato II F1): `level_minutes(L) = 57,25 + XP_MIN_PER_LEVEL_ACT2 × (L − 30)`;
`xp_for_level(L) = round10(level_minutes(L) × XP_KILLS_PER_MIN × mob_xp(L) ÷ (1 − XP_QUEST_SHARE))`, 0 em `MAX_LEVEL` (50).

| L | minutos | mob_xp = 6 + 4,5 L | xp_for_level |
|---|---|---|---|
| 44 (confere) | 67,75 | 204 | 75 390 (= KAC-03 do Ato II ✓) |
| 45 | 68,50 | 208,5 | **77 900** |
| 46 | 69,25 | 213 | 80 460 |
| 47 | 70,00 | 217,5 | 83 050 |
| 48 | 70,75 | 222 | 85 670 |
| 49 | 71,50 | 226,5 | 88 340 (±10 por arredondamento) |

Faixa 45–50 = **350 min ≈ 5,8 h** (40–45 ≈ 5,6 h): crescimento suave, sem zona morta. `XP_BANDS += [45, 50]`,
`XP_QUEST_SHARE_BAND[45] = 0,5`. Exemplo: L = 47 → 70 × 3 × 217,5 ÷ 0,55 = 83 045 → **83 050**.

### 6.2 F2 estendida — atributos dos monstros 45–50
`stat(papel, L) = HORDE_ANCHOR30[papel][stat] × (1 + k × (L − 30)) × mod_unidade × horde_late(papel, L)` — a função atual, sem teto,
vale até 50 (D7). Fatores 50: HP × **2,30** (`HORDE_K_HP` 0,065), ATK × **1,80** (`HORDE_K_ATK` 0,04), DEF +36 (comum +16).

| Papel | HP 45 → 50 | ATK 45 → 50 | DEF 50 |
|---|---|---|---|
| comum (× `HORDE_LATE_40` hp 4,4) | 6 257 → 7 286 | 96 → 108 | 28 |
| bruto (× 1,3 × 1,3) | 4 006 → 4 664 | 141 → 158 | 74 |
| elite | 7 110 → 8 280 | 120 → 135 | 78 |
| chefe | 177 750 → **207 000** | 160 → **180** | 70 |

`mod_unidade` "demônio" (catálogo, D7) **(H)**: hp ×0,8, atk ×1,15, `attack_cooldown` ×0,8 → Bailarino 46: HP 720 × 2,04 × 4,4 × 0,8 =
**5 170**, ATK 60 × 1,64 × 1,15 = **113**. Poder do jogador 45 → 50 **(H)**: equipamento comum ×1,18 (tier 40 → 48), lendário ×1,10
(F10), teia +36 pontos; monstro HP ×1,165, ATK ×1,125 → a dificuldade relativa fica plana; o que sobe é a **leitura** (esquiva, saltos).

**Calibragem 45+ (`Balance.ACT3_LATE_45`, lido por `horde_late(papel, chave, L)` a partir do 45; chefe sem entrada):**
`stat(papel, L ≥ 45) = F2 × ACT3_LATE_45[papel][stat]`.

| Papel | vida (WP3, 2026-11-21) | ATK (usuário, 2026-11-23) | Motivo |
|---|---|---|---|
| comum | ×2,0 | ×1,6 | F2 pura: abate em 1,0–2,2 s, 3–8% de vida perdida ("trivial") → vida ×2 |
| bruto | ×2,0 | ×1,5 | idem |
| elite | — (mod_unidade) | ×2,1 | só ATK: a vida da elite já é do mod_unidade |
| chefe | — | — | calibrado no `boss_probe` (WP8); lacaios de chefe não têm papel F2 |

Com a vida ×2 a caçada ficou no tempo certo, mas `band_probe --from=45 --to=49 --trials=40` media **vida perdida 3–15%**
(média ~8%), abaixo do alvo **14–22%** (AC3-07). Decisão do usuário (2026-11-23): **subir o ATK**, não a vida (a luta não fica
mais longa). Exemplo: Bailarino 46 = 113 × 1,6 = 181 ATK. Faixa segura 1,0–2,5 (check `_check_act3_monsters`); efeito colateral: a única
elite F2 do Ato II no 45 (Golem de Basalto, Kharzun) também ganha o fator de elite.

**Teto do `mod_unidade` dos chefes (WP8b, 2026-11-23):** o check `_check_horde_stats` limita `unit_mods` a 0,6–2,0. Chefe `chefe` 47+ do Excesso (facção `feast`) vai a **vida 6,5** (bots de 50 ascendidos derrubam um chefe ×2 em ~35 s) e **ATK 2,5** (a Condessa foi calibrada em atk 2,3 no `boss_probe`, completo 40/40 e sorteado 32/40; a `countess_decoy` copia os números dela e entra na mesma exceção). Os chefes do Ato II continuam em 2,0.

Medido (`band_probe --from=45 --to=49 --only=duel --trials=40`, 2026-11-23; vida perdida % / abate s, antes → depois):
Folião 10/3,7 → 18/4,4 · Convertido 6/4,5 → 7/4,9 · Bailarino 6/3,2 → 13/3,0 · Galgo 10/4,7 → 20/5,2 · Corista 9/3,9 → 23/4,8 ·
Reflexo 11/3,4 → 19/4,4 · Sedutora 11/4,5 → 21/4,2 · Açoitadora 9/4,3 → 17/5,1 · Cantora 7/3,5 → 22/4,0 · Galgo Alfa (B) 15/2,6 → 21/1,9 ·
Incensário (B) 10/3,6 → 14/3,1 · Vinha (B) 12/5,4 → 16/4,2 · Mestre de Cerimônias (E) 5/3,3 → 18/3,6 · Primeiro Bailarino (E) 5/3,8 → 17/3,2 ·
Maestro (E) 3/2,7 → 8/3,1 · Matriarca (E) 7/4,0 → 19/4,0 · Golem de Basalto (E, Ato II) 7/4,1 → 12/4,6. Mortes 0 → 0-1 de 40.
**2º passe (2026-11-23):** o 40–44 também ganhou ATK (`HORDE_LATE_40.atk` comum 1,8 / bruto 2,0 / elite 2,0, ato2-horda F2), e
`horde_late` multiplica os dois no 45+. Para o 45–50 ficar igual, `ACT3_LATE_45.atk` passou a comum **0,89** / bruto **0,75** / elite
**1,05** (total 1,6 / 1,5 / 2,1, os números da tabela acima).
Fora da faixa por kit, não por ATK: **Convertido** (a conjuração da troca de forma come a luta) e **Maestro** (abre no canal Uníssono e
morre antes de golpear) — WP9 (IA). Referência 40–44 hoje (16 lutas): abate 1,2–3,0 s, vida perdida 3–10% (os bots ficaram mais
fortes desde a calibragem do Ato II): a faixa 40–45 também está abaixo do alvo, decisão à parte.

### 6.3 F10 estendida — equipamento 48 e 50
`gear_factor(L) = (L + 4) ÷ 28` → 48: **1,857** · 50: **1,929** (× `LEGENDARY_MULT` 1,2 = 2,314). Lendário 50 = índice **9** de
`LEGENDARY_LEVELS`, preço **10 moedas** (i + 1). Bônus de conjunto: `i_ef = min(i,5) + 0,5 × max(0, i − 5)` = **7,0** → 4 peças
**48%** de dano de skill, 5 peças **20%** + recarga **24%** (série 42/44/46 → 48). Híbrido 50 (D6): mesmas regras, 5 peças = Fusão tier 9.

### 6.4 F-LA estendida — acessórios lendários 50
`LEG_ACC_STEP[stat]` ganha um 4º valor por **passo constante**: `v50 = v45 + (v45 − v40)`, limitado pelos tetos existentes
(`CRIT_DMG_CAP` 40, `DOT_PCT_CAP` 60, `CC_RESIST_CAP` 50, `MP_COST_CAP` 30, `SUMMON_TIME_CAP` 60). Ex.: atk_pct 2,0/2,5 → **3,0**;
aspd_pct 3,0/4,0 → **5,0**; crit_dmg_pct 6,5/8,0 → **9,5**; threat_pct 15/20 → **25**; cc_resist_pct 15/20 → **25**. Conferir com a
F-LA1 (`G_acc ≤ 0,08`) no `web_probe --level=50`. `LEG_ACC_BUILDS` não muda (o stat de cada peça por build é o mesmo).

### 6.5 Teia 46–50
`MASTERY_POINTS_PER_LEVEL` 7 + `MASTERY_BONUS_LEVELS += 50` → 312 (45) + 35 + 1 = **348 no 50**. Destino dos 36 pontos: **Orla**
(anel novo depois da Fronteira, `tree_catalog._outer_web`): `WEB_RIM_CELLS` 3 casas por setor de build (1 notável da build,
1 notável de elo, 1 pedra-angular menor) + 2 no Geral, nível exigido `WEB_RIM_LEVEL` [46, 49]. Faixa nova
`WEB_GAIN_LATE[50] = {atk [1,4, 1,75], hp [1,12, 1,42], build [1,35, 3,0]}`; Elementalista `WEB_GAIN_BUILD_CLASS[...][50] = [1,35, 3,2]`.

### 6.6 Esquiva de monstro (D4)
`esquiva(alvo monstro) = min(MonsterDef.evasion, MOB_EVASION_CAP)`; mesma rolagem do personagem (`rng.randf() × 100 < esquiva`), só
em golpe direto `dodgeable`; nunca em chefe. TTK esperado: comum demônio com 15% → DPS efetivo do corpo a corpo ×0,85, compensado
pela vida ×0,8 (TTK ≈ ×0,94 do comum da Horda no mesmo nível); área e dano no tempo ×1,0 → TTK ×0,8 (bônus de papel para mago/necro).

---

## 7. Festim Sem Fim (eventos de estrada, `RoadEventSystem`)

Usa o sistema como está: 1 evento por mapa, só com o jogador no mapa, nunca durante investida, NPC não morre, prêmio único
pago uma vez, nada no save, números `Balance.EVENT_*` (um a cada 4–7 min; XP `EVENT_XP_FRAC` 0,04 do nível; moedas
`EVENT_COIN_BASE + EVENT_COIN_PER_LV × L` ≈ 95–105). Pontos = `EVENT_POINTS` no `build_<zona>.py` (`SPAWN_event_<tipo>_NN`).
Entradas em `MapsCatalog.ROAD_EVENTS[<mapa>][<tipo>]` só com as chaves que o sistema lê (`name`, `mob`, `mob_name`, `count`,
`victim`, `home`, `cry`, `thanks`, `flee`, `bot_chat`, `reward_item`, `reward_count`).

| Tipo | Mapas | Monstro (count) | Vítima | Prêmio |
|---|---|---|---|---|
| `forced_dance` *Dança Forçada* | `city_lumeria`, `field_parade` | Bailarino (2–3) | moradora presa num círculo de dança | 2 Vinho Claro |
| `banquet` *Banquete na Estrada* | `city_lumeria`, `field_perfume` | Folião Mascarado (3–4) | viajante obrigado a comer | 2 `potion_hp_l` |
| `choir_corner` *Coro na Esquina* | `city_lumeria`, `field_parade` | Corista (2–3) | guarda que não consegue parar de cantar | 3 Fitas do Festim |
| `sweet_smoke` *Fumo no Vinhedo* | `field_perfume` | Incensário Vivo (1–2) | vinhateiro desmaiado | 1 Porcelana Chorosa |
| `mirror_girl` *A Menina do Espelho* | `city_lumeria`, `rift_garden` | Reflexo Vaidoso (2) | menina olhando o espelho | 2 Vinho Claro + 1 Porcelana |

Estágios: em L3b o Festim para nas ruas de Lumeria (`ROAD_EVENTS` lido com `if/unless` de estágio = **pergunta aberta 6**: o
sistema hoje não filtra por estágio; alternativa sem regra nova = pontos só nos campos). Sem frequência própria por mapa
(`EVENT_EVERY_S` é global; não mexer).

---

## 8. Recompensas e progressão (nível 50)

> **Ver o adendo aprovado [`ato3-lendarios-50.md`](ato3-lendarios-50.md)**: visual novo por build (addon `_a3`) e efeito em toda peça;
> ele substitui aqui o "malha do Ato II numa 4ª cor" (vira só o *fallback*) e, na §11, o "0 malha nova de conjunto".

- `MAX_LEVEL` 45 → **50**; F1 §6.1; Relicária mostra 50 (10 moedas).
- **Tier comum 48** (`COMMON_TIER_LEVELS += 48`): armas/armaduras caem de monstro 47+ (`WorldSim.gear_pool`); joias e capas 48 por
  receita (`RecipesCatalog.gear_recipes`, tier novo com Fita/Porcelana); `SKILL_RANK_MATS` ganha `["festim_ribbon", "weeping_porcelain"]`.
- **Lendários 50** (D6): 24 conjuntos de build + 24 híbridos + **acessórios lendários 50** (Manto/Medalhão/Anel/Sinete por
  `LEG_ACC_BUILDS`), visual = malhas do Ato II (`ACT2_VISUALS`, mesma malha) numa **4ª cor da escada**: 35 ferro de Kharzun, 40 cor de
  guerra, 45 apogeu, **50 "porcelana e ouro velho"** (marfim + destaque ouro + brilho `tint_glow` rosa-pó). Nome com epíteto novo em
  `TIER_EPITHETS` ("da Aurora Clara" — aprovado pelo usuário em 2026-11-23, com a cor 50). Ícones `set_icons.tscn` na cor do 50; arte dos acessórios `item_icons.tscn -- --only=leg_acc_`.
- **Aprimoramento** (D13): Ferreiro Anão no Bairro dos Lúcidos (L1), regra `PLUS_KHARZUN_*` atual.
- **Começo rápido 45** (`StartCatalog.PRESETS[45]`): nível 45, ascensão feita (`hx_asc_<classe>`), teia e teia de ascensão gastas
  pelos bots (`bot_spend`/`bot_spend_asc`), `hx_act2_epilogue` concluída, conjunto lendário 45 via moedas (`START_PRESET_COINS`),
  ouro 20 000, grupo pronto de 4 (Guardião, Sacerdote, Executor, Fogo — trocando o da classe do jogador), mapa `field_kharzun` perto da
  garganta leste, `welcome` com a dica da garganta.
- Chefes: moedas lendárias (regra atual) + troféus para joias/capas 50; títulos da raide e da *Máscara Partida*.
- **Implementado (WP11, 2026-11-23)**: tier 48 de joias/capas e `SKILL_RANK_MATS` = Fita/Porcelana (tema: fita, Uvas Amargas,
  erva azul). Troféus (`RecipesCatalog.LUMERIA_TROPHIES`, 100% no saque do chefe): Taça de Varo, Moldura da Condessa, Batuta
  Partida, Leque da Anfitriã, Coroa Vazia. Joias/capas **50 "de Lumeria"** (`<peça>_<tema>_l50`, épicas, `GearCatalog.lumeria_jewels`,
  F10 com `LUMERIA_JEWEL_MULT` 1,1, papéis/mana do tier 48; acima da comum 48 e do k45, abaixo do acessório lendário 50): 10 Fitas
  + 6 Porcelanas + troféu do tema (Guerreiro Taça, Caçador Moldura, Sábio Batuta); capa + Leque, amuleto + Coroa. Títulos já
  saíam pelo `honor_title` (sem campo novo). Uvas Amargas (`hx3_grapes`, entre `hx3_vines` e `hx3_cellars_open`) e Vinho Claro
  (`hx3_vd_wine`, CRAFT, 60% do MP). Salão do Duque = `MapsCatalog.INTERIORS["in_duke_hall"]` (porta lateral leste do Palácio,
  portão `hx3_duke_hall`), Joalheira Celina vende as 9 peças do 48. Mudanças nos efeitos dos lendários 50 vs adendo: tabela no
  §13 de `ato3-lendarios-50.md`.

---

## 9. Constantes de balanceamento (só em `data/balance.gd`)

| Constante | Hoje | Proposta | Por quê |
|---|---|---|---|
| `MAX_LEVEL` | 45 | **50** | teto da parte 1 |
| `XP_BANDS` | … [40,45] | + **[45, 50]** | auditoria de missões por faixa |
| `XP_QUEST_SHARE_BAND` | … 40: 0,5 | + **45: 0,5** | igual ao 40–45 (28 missões cobrem) |
| `MASTERY_BONUS_LEVELS` | [10,20,30,40] | + **50** | +1 ponto como os outros marcos de 10 |
| `LEGENDARY_LEVELS` | …45 | + **50** | lendário 50 (tier 9, 10 moedas) |
| `HYBRID_LEVELS` | [35,40,45] | + **50** (D6) | híbridos e acessórios lendários 50 saem do laço |
| `LEG_ACC_STEP` | 3 valores | **4º valor** por passo constante (§6.4) | acessório 50 |
| `COMMON_TIER_LEVELS` | [1..40] | + **48** | tier comum novo (pedido) |
| `SKILL_RANK_MATS` | 6 tiers | + **1 tier** (Fita, Porcelana) | rank de skill de nível 48+ |
| `WEB_GAIN_LATE` | 40, 45 | + **50: atk [1,4, 1,75], hp [1,12, 1,42], build [1,35, 3,0]** | `web_probe --level=50` |
| `WEB_GAIN_BUILD_CLASS` | elementalist 30/40/45 | + **50: [1,35, 3,2]** | vida base baixa do Elementalista |
| `WEB_RIM_CELLS`, `WEB_RIM_GERAL_CELLS`, `WEB_RIM_LEVEL` | — | **3, 2, [46, 49]** | Orla da teia (§6.5) |
| `ASC_MAX_LEVEL` | 45 | **45** (sem mudança, D5) | orçamento F5 fechado |
| `MOB_EVASION_CAP` | — | **25** (D4) | teto da esquiva de monstro (jogador: `EVASION_CAP` 45) |
| `MOB_AURAS["festim"]` | — | aliado aspd +15, speed +15; desânimo atk −15, speed −10, 8 s, 12 m | Mestre de Cerimônias (F4) |
| `BOSS_CROWD_RAID` | durgash | + **`boss_sylvare_echo`: [1, 1, 1, 2, 4,9, 3,25]** | raide (D9) |
| `WORLD_BOSS_RESPAWN_S` | — (spawner) | **600** | chefes de mundo (D11) |
| `ACT3_*` assinaturas | — | Prensa, Banquete, Ária, Cânone, Olhar, Cortejo, Sede (intervalos/power **(K)** da §4.1) | números da assinatura só aqui |
| `EVENT_*` | atuais | **sem mudança** | o Festim usa o ritmo global |
| `XP_MIN_PER_LEVEL_ACT2` | 0,75 | **sem mudança** | §6.1 dá 5,8 h, dentro do padrão |

---

## 10. Música, som, vida e arte de carregamento

- **Música** (`build_music.py`, CC0 conferido, `Music.MAP_THEME`, `_check_music`): `lumeria` (valsa de caixinha de música levemente
  desafinada), `lumeria_morning` (L4, calma), `perfume` (cordas lentas), `parade` (fanfarra que se repete demais, de propósito),
  `rift` (coro etéreo, sem percussão), `rift_raid` (coro + órgão). "chefe" e "investida" por cima como hoje.
- **Sfx** (`build_sfx.py`, `Sfx.VOL`): sinos (laço até L1), guizos dos Galgos (`MOB_VOICE`), leque-lâmina abrindo (`CAST_SOUND` do Salto
  Leque), nota aguda (`EFFECT_SOUND`), espelho rachando, fumo sibilando (`AURA_SOUND` do Incensário), taça quebrando, `SIG_WARN`/
  `SIG_EFFECT` das 7 assinaturas (check exige).
- **Vida** (`VILLAGERS`/`LIVING_NPCS`, check `_check_living_routes`, `TOWN_LIVING += city_lumeria`): Lúcidos carregando móveis para as
  barricadas, vinhateiros (L2), varredores (L4), pombos/borboletas; falas de bots `place:lumeria`.
- **Arte de carregamento** (`loading_art.py`): `ZONES` + 1 linha por mapa (`city_lumeria`, `field_perfume`, `field_parade`,
  `rift_garden`, `rift_heart`, 3 masmorras) e `BOSSES` para as 3 masmorras + raide; refazer os `.jpg` (`_check_loading_art`).
- **Buffs novos** com visual (`BuffLooks.LOOKS`): `festim` (aura), Uníssono, Banquete, `vuln` do Banquete, Fumo Doce.

---

## 11. Orçamento de desempenho (AC-36 continua)

| Medida | Limite | Como medir |
|---|---|---|
| Tick médio com `city_lumeria` + campo vizinho + 10 bots | **≤ 10 ms** | `sim_probe.tscn -- --phases --map=city_lumeria` e `--census` |
| Vivos por mapa | cidade ≤ 110 (foliões em bando, não espalhados), campos ≤ 140, Fenda ≤ 100, raide ≤ 20 | `sim_probe --census` |
| Cópias/decoys e pedestais | contam no laço; teto 8 cópias por mapa | check + `--census` |
| FPS no Bairro com 10+ bots | nenhum trecho < 25 FPS (`PerfWatch`) | `--perf --perf_at=<hub>` |
| Draws | ≤ Porto Esperança (lanternas/guirlandas em lote por célula de 36 m, `Dress`) | `--perf` |
| GLB por mapa | ≤ ~6 MB | arquivo |
| Kits | < 200 malhas (malhas do Ato II reaproveitadas; 0 malha nova de conjunto) | check existente |
Laços de esquiva e de aura sem alocação por entidade por tick (`docs/otimizacao.md`).

---

## 12. Pacotes de trabalho

Regra do autor: até 5 agentes, ≥ 1 Fable quando há Blender (Fable só para Blender), ≤ 6 Godot no total; worktree semeado, merge
3-way por arquivo. P ≤ ½ dia, M ~1 dia, G 2+ dias. Todo WP de zona: `/layout-zone` com nota **≥ 8** em ≤ 6 iterações + tour.

| WP | O quê | Agente | Depende de | Tam. |
|---|---|---|---|---|
| WP0 | Aprovar D1–D14; ligar `ato2-horda.md`/`docs/DESIGN.md` | game-designer + autor | — | P |
| WP1 | Teto 50: `MAX_LEVEL`, F1, `XP_BANDS`, `LEGENDARY_LEVELS`/`HYBRID_LEVELS` 50, `LEG_ACC_STEP`, tier 48, Relicária, Orla da teia, `WEB_GAIN_LATE[50]`, preset 45 | class-designer | WP0 | G |
| WP2 | `build_lumeria.py` (cidade murada, Bairro, campanário, guirlandas em lote) + garganta leste no `build_kharzun.py` | blender-modeler (**Fable**) | WP0 | G |
| WP3 | Monstros 45–50 no catálogo com **stand-ins** (F2, `mod_unidade`, escoltas, skills, `ShiftSystem`, loot) + `MonsterDef.evasion` (D4) + `band_probe 45–50` | world-builder | WP0 (D4) | G |
| WP4 | `build_perfume.py` + `build_parade.py` (+ pontos do Festim) | blender-modeler (**Fable**) | WP2 | G |
| WP5 | Mapas na sim: `maps_catalog` (4 mapas, spawners, NPCs, GATHER, cristais), `PORTAL_GATES`, estágios L0–L4, `ROAD_EVENTS`, rondas | world-builder | WP2/WP4 (JSON), WP3 | G |
| WP6 | `rift_garden` (laço) + 2–3 masmorras (`build_dungeons`) + `rift_heart` | Fable + world-builder | WP4, WP5 | G |
| WP7 | Modelos: 7 famílias (`mob_kit`: `quadruped(kind="hound")`, bailarino, corista, reflexo, incensário, vinha) + 7 chefes | blender-modeler (**Fable**) | slot após WP4 | G |
| WP8 | 7 chefes: fases, assinaturas sobre R-A..R-G, falas placeholder; `boss_probe` (40 lutas, 2 sementes, `--bands`, raide) | world-builder + systems-designer | WP3; arena final WP6 | G |
| WP9 | IA: bots contra esquiva (preferir área/dot sem regra nova = peso em `_best_skill`), Cortejo (fugir das 4 faixas), espelhos (cobertura R-E já existe), raide (pedestais, soak×spread), viagem a Lumeria aos 45 | ai-programmer | WP3, WP8 | M |
| WP10 | Missões (13 + 15 + raide + repetíveis) + tela "Fim do Ato III — Parte 1" + `docs/roteiro_45_50.md` | world-builder (+ narrative-director) | WP5, WP8 | M |
| WP11 | Recompensas: 4ª cor dos conjuntos (`ACT2_VISUALS` colors/accents/glows), ícones, receitas 48/50, materiais, títulos | class-designer (+ Fable para ícones de conjunto) | WP1, WP10 | M |
| WP12 | Música, sfx, vida, arte de carregamento, `BuffLooks` | sound-designer + world-builder | WP5 | M |
| WP13 | Integração + QA: suíte, smokes 8 classes, tours, sondas, perf, export, DESIGN/README | qa-lead | todos | M |

**Ondas**: (1) WP1 · WP3 · WP2 (Fable) — (2) WP5 · WP8 em arena provisória · WP4 (Fable) — (3) WP6 · WP9 · WP10 · WP7 (Fable) —
(4) WP11 · WP12 · Conservatório (D3, cortável) · WP13 (sem commit até o autor mandar).
**Caminho crítico**: WP2 → WP4 → WP5 → WP6 → WP8 (arena final) → WP13. O slot de Blender é o gargalo: stand-ins seguram WP3/WP8/WP9.

---

## 13. Critérios de aceitação (testáveis)

Check = `check(...)` em `tools/tests/run_tests.gd` (nomes **propostos**). Evidência = PNG em `production/qa/evidence/ato3p1/`.

- **AC3-01 (portal)** GIVEN jogador 45 sem `hx_act2_epilogue`, WHEN entra na garganta leste, THEN não passa e vê o texto; com ela chega ao
  `SPAWN_chegada_field_kharzun` do Bairro dos Lúcidos; a volta não tem portão. — `_check_act3_gate`.
- **AC3-02 (teto)** `MAX_LEVEL` 50; `xp_for_level(49)` = 88 340 ±1%, `xp_for_level(50)` = 0; Relicária mostra 50 e cobra 10 moedas;
  4 peças do lendário 50 = 48%. — `_check_act3_progression`, `_check_act2_gear` estendido.
- **AC3-03 (zonas)** as 3 zonas de campo/cidade com os 4 tipos de lugar, tudo alcançável a pé, `level_range` certo, tema de música;
  `/layout-zone` ≥ 8 cada; tour `-- --tour=<pasta> --tour_map=<mapa>`. — `_check_places`, `_check_music`, `_check_town_identity`.
- **AC3-04 (estágios)** para cada gatilho L1–L4 o conteúdo é o do estágio e sem ele o anterior; o hub nunca tem monstro hostil
  em nenhum estágio. — `_check_act3_stages`.
- **AC3-05 (esquiva, D4)** monstro com `evasion` 20 esquiva ~20% de 2 000 golpes diretos (±3), 0% de dano no tempo e de área avisada;
  chefe com `evasion` > 0 = falha. — `_check_mob_evasion`.
- **AC3-06 (Excesso)** Convertido troca de forma e conta pela base na missão; Bailarino aplica 3 golpes de `strikes`; aura `festim` some
  com o dono morto; atributos = F2 ±2%. — `_check_act3_mobs`, `_check_monster_shift`.
- **AC3-07 (faixa)** `band_probe.tscn -- --from=45 --to=50 --trials=16 --why`: 0 `travou`, tempo por abate ±25% da faixa 40–45, vida perdida
  14–22% por caçada; `--only=audit`: XP de missão 40–50% e ≥ 10 missões.
- **AC3-08 (chefes de grupo)** Varo, Condessa, Vessaline (+ Ressoa): completo de 4 ≥ 95% (0,3–1 morte), 4 sorteados 65–85%. —
  `boss_probe.tscn -- --party=4 --comp=paladin:guardiao,bishop:sacerdote,berserker:executor,elementalist:fogo --trials=40 --boss=<id>` (+ `--seed=7`).
- **AC3-09 (mundo)** Vindima e Prima-Donna: solo 15–35%, trio 75–100% em 30–150 s. — `boss_probe -- --bands --boss=<id>`.
- **AC3-10 (raide)** Eco: 5 completo 75–85% (~120 s, 0,5–2 mortes); 5 sorteados 45–65%; 4 completo ≤ 10%; **decisão do usuário 2026-11-23: aceitos 5 completo ~58% (~100 s, ~2,8 mortes) e 4 completo ~20% — raide mais difícil que o alvo original;** bots matam ≥ 1 pedestal em 30 s
  na F2. — `boss_probe -- --party=5 --comp=...,bishop:batalha --trials=40 --boss=boss_sylvare_echo --why`.
- **AC3-11 (assinaturas)** cada uma: check do dano certo (dentro/fora, coberto/descoberto, dividido por N, canal quebrado); som de aviso
  existe; cor pela gramática. — `_check_act3_signatures`, `_check_boss_sig_rules`.
- **AC3-12 (Festim)** os 5 tipos nascem nos mapas certos, pagam 1×, não contam para quest/XP de tabela, nunca com investida no mapa. —
  `_check_road_events` estendido; foto `-- --autostart=<c> --event_shot=<png> --event_point=N`.
- **AC3-13 (teia)** `web_probe.tscn -- --level=50`: média e cada build dentro de `WEB_GAIN_LATE[50]`; F-LA1 `G_acc ≤ 0,08` no 50. — `_check_web_strength`.
- **AC3-14 (recompensas)** conjunto/híbrido/acessório 50 existem para as 24 builds com a 4ª cor; Ferreiro Anão aprimora lendário 50;
  preset 45 abre em `field_kharzun` com grupo de 4. — `_check_act2_visuals` estendido, `_check_legendary_accessories`, `_check_start_presets`.
- **AC3-15 (fim)** `hx3_veil` + epílogo → L4 e tela "Fim do Ato III — Parte 1". — check + `-- --autostart=<c> --act_end_shot=<png>`.
- **AC3-16 (desempenho)** `sim_probe.tscn -- --phases --map=city_lumeria` e `--map=rift_garden` ≤ 10 ms/tick; `--census` dentro dos tetos da
  §11; `--perf --perf_at=<Bairro>` sem trecho < 25 FPS.
- **AC3-17 (DoD)** `--import` + suíte 0 failed + smokes das 8 classes (`-- --autostart=<c>` e `--preset=45`) 0 `SCRIPT ERROR`; export + smoke do .exe.
- **AC3-18 (originalidade)** revisão de nomes/silhuetas contra a lista proibida (sem nomes de Warhammer; sem garra de caranguejo,
  chifres em quatro braços, montaria bípede de língua longa) — evidência: folha `lineup.tscn -- --mobs=...` aprovada pelo autor.

---

## 14. Riscos

| Risco | Prob. | Impacto | Mitigação |
|---|---|---|---|
| Esquiva de monstro deixa a sonda ruidosa e frustra corpo a corpo | média | médio | chefes 0; teto 25; área/dot passam; 40 lutas × 2 sementes |
| Paleta rosa/lilás/ouro briga com avisos roxo/dourado | alta | alto | §4.4: chão só em tons próprios; identidade pela forma; revisão de cor antes do WP8 fechar |
| Cidade com foliões estoura o tick (muitos humanos com kit) | média | alto | foliões em bandos com escolta, teto 110; `AWAY_MAP_EVERY`; cidade 1 mapa só |
| Slot de Blender: 4 mapas + 3 masmorras + ~13 modelos | alta | alto | stand-ins primeiro; Fenda e masmorras por laço; Conservatório cortável (D3) |
| Saltos/`repeat` em vítimas aleatórias = morte "do nada" | média | médio | toda investida avisada ≥ 1,4 s; Cortejo mostra as 4 faixas juntas; nunca no tanque |
| Raide de 5 lenta de calibrar | alta | médio | tabela do Durgash como base; pedestais medidos sozinhos antes |
| Semelhança com a inspiração | baixa | alto | AC3-18; narrative-director e autor revisam nomes e folha de silhuetas |
| `ROAD_EVENTS` sem filtro de estágio | média | baixo | pontos só nos campos (sem regra nova) ou 1 condição `unless` (pergunta 6) |
| Poder no 50 passa do orçamento (híbrido 50 + acessórios 50 + Orla) | média | médio | AC3-13 antes de calibrar chefes |

---

## 15. Perguntas abertas

1. **D4**: aprova o campo `MonsterDef.evasion` (mudança de esquema), ou "esquivo" só com saltos/furtividade/`kite`?
2. **D5**: ascensão congelada no 45 na parte 1 (recomendado) ou pontos/refinos até 50?
3. **D6**: híbridos 50 junto com os conjuntos de build? E Ápice 50 fica para a parte 2?
4. **D2**: o portal chega direto no Bairro dos Lúcidos (recomendado) ou no campo de vinhedos?
5. Nomes finais (Amarante e Veladas DECIDIDOS 2026-11-24; restam Irmã Celeste, Cantora do Véu, nomes duplicados de NPC; mantidos: Amarante, Lumeria, Vessaline, Varo, Condessa, Prima-Donna, Ressoa, Dona Vindima, Irmã Celeste, os Lúcidos) — narrative-director.
6. Festim nas ruas: aceitar 1 condição de estágio em `ROAD_EVENTS` (`unless`) para ele parar em L3b, ou deixar pontos só nos campos?
7. Montaria nova (Galgo de Seda) na parte 1, ou fica para a parte 2 (D12)?
8. A raide dá algo visível (aura/insígnia) além do título e da Coroa Vazia?
9. ~~A 4ª cor dos conjuntos~~ — **aprovada pelo usuário em 2026-11-23** ("porcelana e ouro velho" + epíteto "da Aurora Clara").
