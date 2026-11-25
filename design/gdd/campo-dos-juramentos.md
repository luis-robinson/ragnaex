# Campo dos Juramentos (field_oaths) — campo opcional 24-28

> Status: **ESPECIFICAÇÃO** (world-builder, 2026-11-25, WP7 da `design/gdd/dawn-band-refactor-proposal.md`).
> Decisões do usuário (2026-11-25): todas as recomendadas da proposta (D1 = B: 1 campo "Campo dos Juramentos" 24-28 pela
> escavação + depois 1 mini-masmorra "Arquivo de Vel'Thar" 27-29, WP8, aqui só a entrada fica reservada; D2 = Azhar foi o
> último rei-sacerdote de Vel'Thar, **Provisória**; D7 = campo novo + Restos da Noite, alvo 44-48% de XP de quest na faixa).
> Molde: `design/gdd/brejo-das-teias.md` (mesma estrutura, mesmo encanamento). Blender (zona, garganta do Bastião, modelos)
> = agente Fable, a partir do BLENDER REQUEST (§9). Falas aqui são **provisórias** (passe do writer/narrative-director).
> Nada foi alterado em `data/`, `core/`, `game/`, `tools/` nesta rodada (só este documento).

| Campo | Valor |
|---|---|
| Id do mapa | `field_oaths` (nome no jogo "Campo dos Juramentos") |
| Faixa | 24-28 (`level_range` 24-28; bots até 28 + `BOT_BAND_SLACK`) |
| Script da zona | `tools/blender/zones/build_field_oaths.py` (convenção `build_<zona>.py`) |
| Visual | `assets/models/map_field_oaths.glb` + `data/zones/field_oaths.json` |
| Entrada | garganta SE do Bastião da Aurora, atrás da Escavação da Vera (rumo ~66°), portão só por nível (24) |
| Canon | Provisional · Visível ao jogador: Sim (zona, Juramentados, Sir Malcom livre), Descobrível (túmulo vazio de Vorhag, Ordens de Escavação, a voz sob o zigurate), Oculto (o Escrivão de Azhar e a verdade de Vel'Thar, §3.9) |

---

## 1. Overview

O Campo dos Juramentos é um vale fechado (~220 m) logo depois da Escavação da Vera, a sudeste do Bastião da Aurora: o
velho campo de batalha onde, numa geração passada, a Ordem da Aurora se partiu — metade dos cavaleiros jurou à noite
com Vorhag, metade morreu tentando impedir. O chão é de capim seco e cinza, com estandartes caídos, lápides de cavaleiros
e, por baixo de tudo, as ruas afundadas de Vel'Thar, a cidade antiga sobre a qual o Bastião foi erguido. No centro, o
**Acampamento da Vigília**: um pouso pequeno da Aurora (tendas, um sino rachado pendurado num cavalete, fogueira), sem muro
e sem cristal, com batedora-guia, vivandeira e — depois que a Fortaleza dos Ossos cai — **Sir Malcom**, livre, procurando o
túmulo do irmão de armas. Em volta, cinco pontos: **Cemitério dos Cavaleiros** (oeste, Juramentados), **Ruas Afundadas**
(nordeste, Sombras de Vel'Thar e corvos), **Vala dos Cavadores** (sudoeste, acampamento hostil do Culto da Noite que abre
covas), **Colina do Estandarte** (sudeste, arena do mini-chefe **Sir Edran, o Porta-Estandarte Caído**) e o **Zigurate**
(leste, boca do Arquivo de Vel'Thar, fechada por ora). É **opcional**: nada da linha principal (`q12_ruins`, `dw_*`) passa
por aqui. Ele preenche o buraco de conteúdo 25-28 da faixa, mantém um lugar com monstros depois que os fronts calam
(problema 2 da proposta), dá quatro materiais próprios, uma peça garantida e responde à pergunta plantada por Sir Malcom:
**por que cavaleiros da Aurora juraram à noite**.

## 2. Player Fantasy

"Atravessei a vala da escavação e achei o lugar de onde a guerra começou." O jogador sai do Bastião vitorioso (Ossos e,
quase sempre, a Torre já caíram) e entra num campo silencioso onde a guerra **ainda não acabou para os mortos**: fileiras
de cavaleiros-espectro guardam posições de uma batalha perdida, corvos enormes comem o que o Culto desenterra, e à noite um
sino rachado responde sozinho. O pouso da Vigília é pequeno e cansado; Sir Malcom, que o jogador viu preso na Fortaleza dos
Ossos, agora é um homem livre com uma pergunta só. A recompensa da volta é tripla: **progresso** (XP de quest de 24 a 28,
uma peça tier 3, material para a Prata/Fragmento), **descoberta** (o túmulo vazio, as Ordens de Escavação, a voz que lê
nomes sob o zigurate) e **história** (Malcom enterra o que sobrou do irmão; o jogador leva a pergunta à Erudita Senna).

Pilares: exploração recompensada, identidade visual por POI, mistério em camadas (Bartle: Explorador + Conquistador).
SDT: autonomia (três ramos em ordem livre: Vigília, Corveira, Sineiro; o ramo de Malcom espera o Vorhag cair),
competência (mecânicas legíveis: guarda frontal dos Juramentados, estandarte fincado avisado no chão), pertencimento
(Malcom, que o jogador libertou, volta a ter nome e propósito).

---

## 3. Detailed Rules

### 3.1 Lugar no mundo e acesso

Verificado no código (2026-11-25, `data/zones/field_ruins.json` e `tools/blender/zones/build_field_ruins.py`):
- Bastião: `size` 260, anel padrão do `Zone` (`rim` (116, 7, 4, 2.5)); ângulos do build = `cos` em x, `sin` em z (90° = sul).
  Gargantas em uso: Aldara -3°, cais -15°, Cidadela -48°, Ossos -90°, Torre (front sul) 90°, Carniçal 180°.
- Escavação da Vera: place `cabin` `escavacao` em (60, 92), face 200, NPC `digger_vera`; trilha `(66, 42) → (54, 80)` e
  largo em (60, 92). Rochedo do Covil do Dragonete em ~(84, 62) r 7.
- Varredura de colisores sólidos (r < 6 m) no setor 30-80°: 54-62° é a própria escavação (casa, cerca, lampião) e
  30-50° é o rochedo e pedras; **66-74° com raio 96-112 está livre** (só arbusto/árvore morta solta, que a trilha tira).
  O front sul (Torre) tem spawners em `H(88..96, 72..108°)`; o mais perto, `cultist` em ~(27, 84) r 8, fica a ~20 m da
  chegada e some com `dw_frost_boss`. A rota de investida do sul sai de 90° e não cruza 66°.

Regras:
- Portal **`to_field_oaths`** no Bastião, garganta SE **rumo 66°** (`polar(z, 66, 7)` ≈ (46, 104); chegada no Bastião
  `polar(z, 66, 15)` ≈ (43, 96)), aberto como as gargantas tardias da Floresta (`late_gorges` + `LATE_*`): portal, trilha
  e largo entram no FIM do build, o resto do `field_ruins.json` sai byte a byte igual (fora a decoração tirada do caminho).
  Trilha de 3 m: `(54, 80) → (50, 88) → chegada`, continuando a trilha da escavação (o jogador "atravessa a vala da Vera").
  Rótulo: "Campo dos Juramentos (Lv 24-28)". `z.data["arrive_from_field_oaths"]` = a chegada no Bastião.
- Portal de volta **`to_field_ruins`** na garganta NO do Campo (rumo -130°: portal `polar(-130, 7)`, chegada
  `polar(-130, 15)` ≈ (-54, -64)). Chegada no Campo = `target_pos` do portal do Bastião.
- **Portão de progressão** (só por nível; opcional): `OATHS_GATES["to_field_oaths"] = {"level": 24, "text": "Vera segura
  a lanterna na boca da vala: \"Do outro lado tem cavaleiro morto que ainda marcha em fila. Volte no nível 24.\""}`,
  lido no `load_zone` ao lado de `PORTAL_GATES` (como `MARSH_GATES`).
- **Prontidão** (padrão do Brejo): `MapsCatalog.oaths_ready()` = `data/zones/field_oaths.json` existe **e** o
  `field_ruins.json` contém `arrive_from_field_oaths`. Sem isso nada do Campo entra (mapa, NPCs, quests).
- Lore do acesso: Vera já diz "Vim atrás de ouro e achei uma cripta sob o zigurate" — a vala dela é a porta do Campo;
  o zigurate fica do outro lado (§3.9 resolve a "cripta").

### 3.2 Layout (Erenshor: vale fechado, hub no centro, POIs a 60-120 m, estradas curvas, água com pontes, landmark)

Coordenadas do jogo (x, z), norte = -z, 1 u = 1 m. Vale `SIZE` 220, `RIM` (99, 4, 2.5, 1.5) como o Brejo = raio útil
~91-107 m. Borda: penhascos baixos de pedra cinza com faixa de árvores mortas (mesma paleta `DEAD_TREES` do Bastião),
nunca reta. Um só portal na borda (NO) + a boca reservada do Arquivo (L, encosta).

| Peça | Centro | Raio | Distância do hub | Notas |
|---|---|---|---|---|
| Hub: Acampamento da Vigília | (0, 0) | 12 (chão batido + tendas) + clareira 20 | — | sem muro/cristal; 4 saídas (NO, O, NE, S/SE); sino rachado num cavalete (marco do hub, 4 m); 8 `SPAWN_hangout` |
| Garganta NO (Bastião) | portal `polar(-130, 7)`, chegada `polar(-130, 15)` ≈ (-54, -64) | — | ~84 | largo de chegada `z.arrival` r 6 |
| P1 Cemitério dos Cavaleiros | (-76, 6) | 18 | 76 | fileiras de lápides (sólidas baixas, corredores ≥ 3 m), elmos em estacas, **Túmulo de Vorhag** (mausoléu pequeno, porta arrombada) em (-84, -4) |
| P2 Ruas Afundadas | (54, -52) | 18 | 75 | calçamento de Vel'Thar meio enterrado, colunas quebradas (`pillar`), arcos caídos, cacos; chão pedra-areia |
| P3 Vala dos Cavadores (place `camp`) | (-44, 62) | 12 | 76 | covas abertas, montes de terra, pás, tenda negra do Culto, carroça de ossos |
| P4 Colina do Estandarte (arena do mini-chefe) | (50, 64) | 15 livre | 81 | morrote plano, chão de terra queimada; estandartes caídos por FORA do círculo (sem colisão dentro) |
| Zigurate do Arquivo (place `dungeon`, **reservado**) | portão (84, 6), boca a 180° (para oeste) | morro 6 | 84 | zigurate baixo de degraus (≤ 8 m), porta com selo; portal em `future_portals` (§3.8) |
| Cabana do Sineiro (place `cabin`) | (-62, -38) | — | 73 | NPC `oaths_bellringer`; capela em ruína com a torre do sino caída |
| Choupana da Corveira (place `cabin`) | (20, -80) | — | 82 | NPC `oaths_crowkeeper`; poleiros, penas penduradas |
| Pedra dos Nomes (place `shrine`) | (-16, -60) | — | 62 | NPC `oaths_stone` (board, caçadas; prop de lápide grande com nomes riscados) |
| Landmark: o Estandarte Partido | (-34, -14) | morro sólido 6, mastro 18 m | 37 | mastro da Aurora partido ao meio, pano dourado rasgado (`horde.cloth`/`Dress.flag`), inclinado; ≥ 14 m de toda estrada |
| Córrego das Cinzas (rio) | (104, 40) → (70, 42) → (44, 48) → (12, 58) → (-10, 72) → (-30, 104) | w 4,5 | — | nasce na encosta leste atrás do zigurate, sai na borda SO; água escura `water_dark` |

Estradas (catmull-rom, nunca reta; 4 m as principais, 3 m as trilhas):

| Id | Pontos | Largura |
|---|---|---|
| `NO` (chegada → hub) | chegada → (-40, -46) → (-22, -26) → (-10, -10) → borda da Vigília | 4 |
| `O` (hub → Cemitério) | (-12, 2) → (-34, 8) → (-56, 4) → (-66, 6) | 4 |
| `NE` (hub → Ruas) | (10, -8) → (24, -26) → (40, -42) → (50, -48) | 4 |
| `S` (hub → Vala) | (-6, 12) → (-20, 32) → (-34, 50) → (-40, 58) | 4 |
| `SE` (hub → Colina) | (10, 10) → (28, 24) → (44, 40) → (48, 56) | 4; cruza o córrego ~(45, 47) = **Ponte 1** |
| `arco_leste` (Ruas → Zigurate) | (60, -40) → (76, -22) → (80, -4) → frente do portão | 3 |
| `arco_sul` (Vala → Colina) | (-36, 64) → (-16, 80) → (12, 84) → (36, 78) → (46, 70) | 3; cruza o córrego ~(-18, 84) = **Ponte 2** |
| `arco_oeste` (Cemitério → Vala) | (-74, 22) → (-66, 42) → (-52, 58) | 3 |

Sem becos acidentais: os arcos fecham dois anéis (O-S-arco_oeste e S-SE-arco_sul); `arco_leste` liga as Ruas ao Zigurate
(o Zigurate é ponta de propósito: é a porta da masmorra). Trilhas das cabanas/santuário saem sozinhas (`places._trail`);
pontes só onde estrada cruza água (`z.bridges()`); `nature.clear_banks` depois da dispersão.

Leitura de cima: hub = disco de terra batida com tendas brancas e o sino; manchas por região: Cemitério = capim cinza-verde
com lápides claras em fileira, Ruas = pedra-areia em retalhos (`Zone.patch`), Vala = terra marrom-escura com covas
(discos escuros), Colina = terra queimada clara com anel de estandartes, Zigurate = pedra clara em degraus. Nada alto
(> 6 m) a menos de 14 m das estradas perto do hub; o Estandarte Partido fica fora das rotas.

### 3.3 Monstros (24-28)

Regra: 4 comuns de campo + 2 de acampamento + 1 mini-chefe com skill própria + lacaio. Modelos existentes recoloridos pela
cor do `MonsterDef`; modelos **novos** pedidos ao Fable marcados (padrão `MARSH_MODELS`: `OATHS_MODELS = {id: [novo,
reserva]}`, o catálogo usa a reserva enquanto o GLB não existe). **Nenhum spawner do Campo tem `if`/`unless`**: o Campo
fica povoado depois da conquista (complementa os Restos da Noite, WP4).

| Id | Nome | Nv | Papel | Modelo (reserva → novo) | Skill | Onde |
|---|---|---|---|---|---|---|
| `carrion_crow` | Corvo de Carniça | 24 | corpo a corpo rápido, frágil, em bando de 3 | `mob_shaman_hawk` (preto-azulado) → opcional **`mob_carrion_crow`** | — | Ruas, beira do Cemitério, Choupana |
| `oath_sworn` | Juramentado | 25 | corpo a corpo, `front_guard` 0,5 (bata pelas costas) | `mob_loyal_knight` (cinza-pálido translúcido) → **`mob_oath_sworn`** | `mob_charge` | Cemitério, beira da estrada O |
| `oath_archer` | Besteiro Juramentado | 26 | atirador (`ranged`) | `mob_loyal_crossbow` (cinza-pálido) | `mob_volley` | fundo do Cemitério, Colina (fora da arena) |
| `vel_shade` | Sombra de Vel'Thar | 27 | atiradora mágica, lenta | `mob_ghost` (sépia/âmbar, não azul: é morto da cidade, não do Lich) | `mob_soul_drain` | Ruas Afundadas, frente do Zigurate |
| `night_digger` | Cavador da Noite | 27 | atirador mágico de acampamento | `mob_cultist` (marrom-terra) | (as do `cultist`) | Vala (place `camp` + ronda) |
| `grave_hauler` | Carregador de Covas | 28 | corpo a corpo pesado, lento | `mob_bandit_thug` (encapuzado escuro) → **`mob_grave_hauler`** | `mob_bone_cleave` | Vala, 2 vigiando o Túmulo de Vorhag |
| `fallen_bearer` | Sir Edran, o Porta-Estandarte Caído | 28 | **mini-chefe de campo** (`is_boss`) | `mob_death_knight` ×1,4 (cinza-dourado) → **`mob_fallen_bearer`** | `mob_banner_plant`, `mob_banner_sweep` (NOVAS), `mob_charge` | Colina do Estandarte |
| `oath_risen` | Juramentado Erguido | 28 | lacaio (0 XP, sem saque) | `mob_loyal_knight` (mais escuro) | — | só invocado |

Nome do acampamento: a proposta dizia "Penitentes"; trocado para **Cavador da Noite** porque "Penitente/Penitência" já é
do Paladino (Conjunto Penitente Negro, Marca da Penitência) — o mesmo nome em monstro confundiria a leitura do combate.

Rei de campo: o sistema de elite (`Balance.ELITE_KILLS`) já faz o "Rei" de qualquer comum; nada a desenhar.

Skills novas do mini-chefe (`skills_catalog.gd`, prefixo `mob_`; números iniciais, calibrar com `boss_probe`):
- `mob_banner_plant` "Estandarte Fincado": GROUND, `mob_pick: far`, círculo avisado r 5 no ponto (cor dano da gramática
  `FxManager.DANGER*`; não esquivável, regra de chão de chefe 2026-11-13), impacto 1,4 s depois com power 1,2 + lento 30% 2 s,
  e `boss_summon` 2 `oath_risen` (máx 4), recarga 20 s, preparo 0,6 s (exceção C8: chão com raio ≥ 2 m), clipe
  `cast_ground`, vfx `shadow`. **Implicação de jogo**: hoje `boss_summon` nasce em volta do chefe; se o sistema não puser
  os lacaios no ponto do estandarte, aceitar "em volta do chefe" (nenhuma regra nova). Pedido ao `game-designer` antes de
  pedir código.
- `mob_banner_sweep` "Varredura do Mastro": CONE 120° r 4,5, power 1,6 + atordoa 0,5 s, recarga 10 s, preparo 0,5 s,
  clipe `atk_2h_slash`/`attack`, tema `blood` (golpe físico de monstro).
Fases (kit de chefe de grupo, `_check_boss_mechanics`): 70% "Levantem as fileiras! A linha não se rompe!" 2 `oath_risen`
(máx 4); 40% `ward` 0,4 enquanto há erguido vivo + recarga do Estandarte −25%; 15% `enrage` 1,25. `berserk_after` 160 s.
`leash_range` 25 (a arena tem 15 livres; o córrego fica a ≥ 18 m). Falas provisórias: `intro` "Eu carreguei a Aurora
até aqui. Depois carreguei outra coisa." / `last_words` "Diga ao Malcom... que o pano... ainda é dourado...".

Números iniciais (analogia de faixa; F2):

| Monstro | Nv | HP | ATK/MATK | DEF/MDEF | XP | Vizinho de referência |
|---|---|---|---|---|---|---|
| carrion_crow | 24 | 420 | 60 | 8/10 | 115 | tower_bat 26 (260/66), skel_archer 24 |
| oath_sworn | 25 | 920 | 80 | 30/14 | 170 | skel_guard 25 (880/80, front_guard 0,6) |
| oath_archer | 26 | 480 | 62 | 14/12 | 150 | skel_archer 24 (360/58) |
| vel_shade | 27 | 440 | 30/76 | 10/26 | 160 | ghost 27 (420/74) |
| night_digger | 27 | 520 | 22/74 | 10/24 | 170 | cultist 26 (380/72) |
| grave_hauler | 28 | 1150 | 92 | 26/12 | 230 | citadel_horror 29 (1100/74), skeleton 24 |
| fallen_bearer | 28 | 66.000 | 104/70 | 30/24 | 1600 | Vorhag 26 (70.000/101), Morvath 29 (70.000) |
| oath_risen | 28 | 340 | 44 | 16/8 | 0 | bone_raised 25 (300/40) |

### 3.4 NPCs

| Id | Nome | Papel | Onde | Falas-guia (provisórias) |
|---|---|---|---|---|
| `oaths_guide` | Batedora Cândida | quest (guia do campo) | hub, junto da fogueira | rota dos POIs; "Os mortos ficam nas fileiras deles. Os vivos cavam. Desconfie dos vivos." |
| `oaths_merchant` | Vivandeira Rosália | merchant (poções M, ataduras; compra tudo) | hub, carroça-banca | "Água benta acabou. Tenho poção e pão duro." |
| `oaths_malcom` | Sir Malcom | quest (cadeia principal do Campo) | hub, de pé diante do sino | **`if: dw_bones_boss`** (livre da Fortaleza dos Ossos); "Enterramos o Vorhag aqui. Um caixão leve demais." |
| `oaths_bellringer` | Velho Sineiro Abel | quest | Cabana do Sineiro (place) | "O sino tocou a retirada naquela noite. Toca sozinho desde então." |
| `oaths_crowkeeper` | Corveira Matilde | quest (coletas) | Choupana da Corveira (place) | penas, selos; "Corvo come de tudo. Menos dos Juramentados. Corvo sabe." |
| `oaths_stone` | Pedra dos Nomes | board (caçadas repetíveis; entra em `QuestsCatalog.HUNT_GIVERS["field_oaths"]`) | santuário | "Nomes riscados a ponta de espada. Uns riscados duas vezes." |

Sem cristal e sem Mestre de Skills (campo opcional, como Brejo e Bosque). Mercador sim (vender o saque e repor poção).
Nomes conferidos (2026-11-25, grep nos catálogos): nenhum já em uso; evitados Tobias, Iolanda e Nádia (já existem).
Sir Malcom: hoje é só `prisoner` em `FORT_NPCS["fort_bones"]` (some na retomada); `oaths_malcom` é o mesmo personagem,
id novo, só existe com `dw_bones_boss` (nunca dois Malcons ao mesmo tempo).

### 3.5 Quests (13, todas laterais; nenhuma é `prereq` da linha principal)

Prefixo `oj` (livre). Ordem livre entre os ramos depois de `oj0`; o ramo de Malcom espera `dw_bones_boss` (`prereq_all`).
Pesos de XP = número escrito (o total da faixa 20-30 é escalado por `QuestsCatalog.scale_xp`, §4 F1).

| Id | Título | Tipo | Giver → turnin | Alvo | Nv | Pré | Peso XP | Ouro | Itens |
|---|---|---|---|---|---|---|---|---|---|
| `oj0_vala` | Do Outro Lado da Vala | REACH | `digger_vera` → `oaths_guide` | `field_oaths` | 24 | — | 1200 | 150 | potion_hp_m ×3 |
| `oj1_crows` | Bico e Garra | KILL | `oaths_guide` | `carrion_crow` ×12 | 24 | oj0 | 2600 | 220 | potion_hp_m ×2 |
| `oj2_ranks` | Fileiras Mortas | KILL | `oaths_guide` | `oath_sworn` ×10 | 25 | oj1 | 3000 | 240 | potion_mp_m ×2 |
| `oj3_feathers` | Penas para a Corveira | COLLECT | `oaths_crowkeeper` | `carrion_feather` ×8 | 25 | oj0 | 2800 | 230 | elixir_stone ×1 |
| `oj4_malcom` | O Prisioneiro dos Ossos | TALK | `oaths_guide` → `oaths_malcom` | `oaths_malcom` | 25 | oj0, `prereq_all` [dw_bones_boss] | 1200 | 120 | — |
| `oj5_seals` | Selos de Juramento | COLLECT | `oaths_malcom` | `oath_seal` ×6 | 26 | oj4 | 3200 | 260 | potion_hp_m ×2 |
| `oj6_diggers` | Quem Abre as Covas | KILL | `oaths_malcom` | `night_digger` ×10 | 26 | oj4 | 3200 | 260 | potion_mp_m ×2 |
| `oj7_tomb` | O Túmulo Vazio | KILL | `oaths_malcom` | `grave_hauler` ×6 | 27 | oj6 | 3400 | 280 | potion_hp_m ×2 |
| `oj8_orders` | Ordens de Escavação | COLLECT | `oaths_guide` | `digger_orders` ×3 | 27 | oj6 | 3000 | 250 | — |
| `oj9_shades` | O Sino que Toca Sozinho | KILL | `oaths_bellringer` | `vel_shade` ×10 | 27 | oj0 | 3000 | 250 | potion_mp_m ×2 |
| `oj10_bearer` | O Porta-Estandarte | KILL | `oaths_malcom` | `fallen_bearer` ×1 | 28 | oj5, `prereq_all` [oj7] | 7000 | 600 | `reward_gear_tier` 3, elixir_might ×1 |
| `oj11_senna` | O Que os Mortos Ouvem | TALK | `oaths_malcom` → `ruins_scholar` | `ruins_scholar` | 28 | oj10, `prereq_all` [oj8, oj9] | 2500 | 200 | potion_hp_m ×2 |
| `oj12_osric` | Um Nome para o Osric | COLLECT (entrega, `give_items` `bearer_banner_scrap`) | `oaths_malcom` → `gravedigger_osric` | `bearer_banner_scrap` ×1 | 28 | oj10 | 1800 | 150 | — |

Soma dos pesos: **37.900**. Por nível: 24: 2 · 25: 3 · 26: 2 · 27: 3 · 28: 3 (cobre os buracos 25-26 e 28 da §1.1 da proposta).
Cada `dialog_progress` diz a tecla/estratégia (regra do manual), ex.: oj2 "O Juramentado segura o escudo na frente: dê a
volta ou espere a investida dele passar e bata nas costas"; oj9 "A Sombra drena de longe: feche a distância com dash
(Shift) e não lute no meio das colunas"; oj10 "Quando o chão marcar o círculo do estandarte, saia: ele cai 1 s depois e
ergue dois Juramentados. Com o chefe protegido (40%), mate os erguidos primeiro; o leque do mastro na frente dele atordoa:
fique de lado ou bloqueie (botão direito)".
Ganchos de texto (para o writer): oj7 abre o Túmulo de Vorhag e ele está **vazio desde o começo** (sem marca de
violação de dentro; os Cavadores só arrombaram a porta); oj8 = as Ordens listam **nomes** de mortos, não ossos; oj11
leva a pergunta à Senna e planta o Arquivo.

### 3.6 Saque e economia

Materiais novos (`items_catalog.gd`, `_mat`; preço de venda = 50%):

| Id | Nome | Preço | Fonte | Uso |
|---|---|---|---|---|
| `carrion_feather` | Pena de Carniça | 18 | `carrion_crow` 0,55 | quest oj3; material de faixa (rank de skill) |
| `oath_seal` | Selo de Juramento | 26 | `oath_sworn` 0,45, `oath_archer` 0,35 | quest oj5; material de faixa; pista (nomes gravados) |
| `fallen_standard` | Estandarte da Aurora Caído | 120 | `fallen_bearer` 1,0 (garantido) | material de tier do campo (boss garante) |
| `digger_orders` | Ordem de Escavação | 0 | `night_digger` 0,35 (quest) | quest oj8 |
| `bearer_banner_scrap` | Retalho do Estandarte | 0 | `give_items` do oj12 | entrega |

Tabelas (`_lt`):
- `lt_carrion_crow`: `carrion_feather` 0,55 · `bone_shard` 0,3 · `potion_hp_m` 0,05.
- `lt_oath_sworn`: `oath_seal` 0,45 · `bone_shard` 0,4 · `holy_silver` 0,1 · `ring_spectral` 0,03.
- `lt_oath_archer`: `oath_seal` 0,35 · `bone_shard` 0,5 · `star_ore` 0,2.
- `lt_vel_shade`: `ghost_essence` 0,55 · `ancient_relic` 0,3 · `potion_mp_m` 0,1 · `crown_spectral` 0,03.
- `lt_night_digger`: `digger_orders` 0,35 · `ancient_relic` 0,4 · `iron_ore` 0,3 · `potion_hp_m` 0,1.
- `lt_grave_hauler`: `bone_shard` 0,6 (1-2) · `holy_silver` 0,14 · `star_ore` 0,3 · `ring_spectral` 0,04.
- `lt_fallen_bearer`: `fallen_standard` 1,0 · `oath_seal` 1,0 (3-5) · `holy_silver` 1,0 (2-3) · `dawn_shard` 0,15 · `crown_spectral` 0,3 · `elixir_might` 0,5.

Regras: materiais 0,3-0,7 (abaixo de 0,3 = extras); equipamento raro ≤ 0,05; chefe garante material de tier. `holy_silver`
em 0,10-0,14 = mesma taxa do `lt_bones` (a Prata não fica mais fácil aqui). `dawn_shard` (90) fica raro no mini-chefe
(0,15); o Arquivo (WP8) é a fonte garantida. Ouro por monstro no padrão da faixa (14-40). Mercador só vende consumíveis:
nenhuma fonte nova de ouro infinito.

### 3.7 Colheita (`MapsCatalog.GATHER["field_oaths"]`)

| Item | Forma | Centro | Raio | Quantos |
|---|---|---|---|---|
| `ancient_relic` | `relic` | (54, -60) Ruas Afundadas | 10 | 4 |
| `star_ore` | `ore` | (70, -14) pé do Zigurate (lado norte) | 8 | 3 |
| `herb_blue` | `herb_blue` | (-60, 24) entre o Cemitério e o arco oeste (chão livre, longe do rio) | 10 | 4 |

(Os centros ficam a ≥ 8 m de estrada e de água; o Fable confere `z.free` no build.)

### 3.8 Arquivo de Vel'Thar — entrada reservada (WP8)

- Place `dungeon` id `arquivo`, dungeon **`dg_archive`** (nome "Arquivo de Vel'Thar"; id livre, conferido), entrada em
  `places.DUNGEONS["dg_archive"]` com `"zone": "field_oaths"`, `"gate": (84.0, 6.0)`, `"face": 180.0`, `"level": 27`,
  **`"reserved": True`** (padrão do `dg_viveiro`: `places.dungeon()` põe só a boca, fecha com colisor e grava a passagem em
  `data["future_portals"]`; o `build_dungeons` pula a entrada) e `"arch": "ziggurat"` (boca nova: porta de pedra no pé de
  um zigurate de 3 degraus; se o Fable preferir, `arch` padrão de pedra + o zigurate como morro do build).
- Sim: sem portal até o mapa existir; `future_portals` com `level` 27 e `arrive` (0, 44). Antes disso o jogador vê a porta
  selada e não entra; bots não tentam ir.
- Quando o WP8 entrar: `dg_archive` em `DUNGEON_DEFS` (`parent_map: field_oaths`, faixa 27-29), `archive_ready()` como o
  `viveiro_ready()`, promover o portal, `PORTAL_GATES["to_dg_archive"]` (nível 27 + `oj11_senna` recomendado: é a quest que
  "manda" ao Arquivo), música, `loading_art.BOSSES`. O chefe (Escrivão de Azhar) e o "eco do nomeado" são do GDD do WP8
  (`game-designer` antes da mecânica).

### 3.9 Lore (canon provisório; cruzado com o existente)

- **O que o jogador vê**: um campo de batalha antigo com cavaleiros-espectro da Aurora ainda em fileira; um sino que toca
  sozinho; o Culto da Noite abrindo covas e carregando **papéis**, não ossos; um zigurate com porta selada; Sir Malcom livre.
- **Descobrível**: o Túmulo de Vorhag foi enterrado vazio (a Aurora achou que ele morreu no campo; ele tinha ido a
  Azhar); os Selos de Juramento têm nomes gravados (cada Juramentado jurou "proteger esta terra" — a mesma fala do Vorhag,
  `death_knight` `intro`: "Eu jurei proteger esta terra. Ainda protejo. Dela."); as Ordens de Escavação listam nomes de
  mortos "para o Escrivão"; Sir Edran carregou o estandarte da Aurora e o fincou para a noite.
- **Oculto (verdade, para o WP8 e o narrative-director)**: Vel'Thar foi a cidade antiga sob o Bastião; **Azhar foi o último
  rei-sacerdote de Vel'Thar** (D2, Provisória). Para não perder os mortos de uma peste, prendeu as almas da cidade no trono
  e virou Lich. A promessa que ele vende aos vivos é **falar com os mortos de novo**. O **Escrivão de Azhar**, no Arquivo,
  guarda o registro de nomes da cidade; quem é nomeado por ele "volta" como eco. O Culto cava para dar nomes novos ao
  Escrivão. Vorhag e Edran juraram à noite para ouvir de novo os seus mortos (a família de Vorhag morreu na mesma peste
  que Azhar quis vencer — detalhe para o writer, Provisório).
- **Mistério plantado (narradora não confiável)**: Vera diz "achei uma cripta sob o zigurate" e "O Senhor da Cripta ainda
  dá ordens. Ouvi." Ela **acha** que a voz é do Senhor da Cripta (de quem a Senna fala); a verdade é que é o Escrivão lendo
  nomes no Arquivo. A Cripta de Vel'Thar (`dg_cripta`, front norte) e o Arquivo são partes da mesma cidade enterrada; nada
  na fala dela muda.

Contradictions check (2026-11-25):
- Sir Malcom ("Jurei à Aurora antes de Vorhag jurar à noite. Fomos irmãos.") = coerente: ele procura o túmulo do irmão;
  só aparece livre depois de `dw_bones_boss`, quando os presos da Fortaleza dos Ossos somem (`FORT_NPCS`).
- Vorhag (`intro`/`last_words` sobre juramento) = coerente com Juramentados e Selos.
- Mago Aurélio (Morvath congelou o coração), Alma Presa ("almas da cidade antiga no trono"), Velha Sacerdotisa ("a noite
  tem um coração") = coerentes; o Campo não responde sobre Morvath (fica para outro WP).
- `ancient_relic` "Caco de cerâmica com runas de Vel'Thar" e o nome antigo do mapa ("Ruínas de Vel'Thar") = coerentes
  com as Ruas Afundadas.
- **Mudança em relação à proposta**: a proposta punha o Arquivo "sob o zigurate da escavação"; aqui o zigurate fica no
  Campo, do outro lado da vala da Vera. Coerente com a fala dela (a vala é a passagem) e não toca o JSON do Bastião além da
  garganta. "Penitentes" → "Cavadores da Noite" (§3.3, colisão de nome com o Paladino).
- Nenhum fato estabelecido muda. A origem de Azhar continua **Provisória** até o `narrative-director`.

### 3.10 Bots

- `bot_population` 3 (mesmo do Brejo/Bosque). Bots nascem/caçam pela regra de faixa (`BotBandSystem`, `level_range` 24-28 +
  `BOT_BAND_SLACK`); sem cristal, o bot volta a renascer no Bastião (`home_map` = povoado com cristal da faixa).
- 8 pontos `SPAWN_hangout_NN` na Vigília. Corredores ≥ 3 m entre sólidos (lápides em fileira com vãos de 3,5 m);
  estandartes caídos e covas são visuais sem colisão onde houver passagem.
- Rever o `bot_population` do Bastião (3) só se o `sim_probe --census` mostrar o Bastião vazio de bots na faixa.

### 3.11 Música e arte de carregamento

- `Music.MAP_THEME["field_oaths"] = "trevas"` (tema já usado pelos `fort_*` do Ato I); tema próprio ("campo de batalha
  silencioso", CC0) é pedido aberto ao sound-designer. `_check_music` exige a entrada.
- `loading_art.ZONES["field_oaths"]`: nome "Campo dos Juramentos", chão = `ground_color` do MapDef (proposta: (0,52, 0,52, 0,44)
  capim seco cinza), mood do Bastião (`dawn`), câmera do hub para o Estandarte Partido e a Colina (`at` (10, 10), az 160,
  dist 100, elev 26, pitch 18, fov 50). `.jpg` refeito depois do GLB (Fable).

---

## 4. Formulas

**F1 — XP de quest da faixa** (`QuestsCatalog.scale_xp`): `k = s × B / Σ` e cada quest recebe `round(peso × k / 10) × 10`.
Variáveis: `s` = `Balance.quest_share(20)` (`XP_QUEST_SHARE_BAND[20]` = **0,65** hoje); `B` = `Balance.band_xp_base(20, 30)`
(curva BASE, ≈ 305.500); `Σ` = soma dos pesos das quests não repetíveis com `level_req` em [20, 30).
Consequência importante (verificada no código): **o total de XP de quest da faixa é fixo** (`s × B` ≈ 198.600). Quests novas
**não** sobem o total, só redistribuem: as do Campo levam `37.900 / (Σ_atual + 37.900)` dele e as existentes encolhem na
mesma proporção. O `band_probe --only=audit` mede contra a XP EXIGIDA (`XP_LEVEL_MULT` 2,0 → 611.000) e inclui as quests de
nível 30 (≈ 37.100, fora do `scale_xp` da faixa): `audit% = (s × B + L30) / (2 × B)` = (198.600 + 37.100) / 611.000 = **39%**.
Para chegar ao alvo D7 (44-48%) o botão é `s`, não o número de quests:

| `s` | Total escalado | Audit | Efeito nas quests antigas (com Σ_atual = 150.000, exemplo) |
|---|---|---|---|
| 0,65 (hoje) | 198.600 | 39% | −20% (o Campo dilui) |
| 0,76 | 232.200 | 44,1% | −6% |
| **0,78 (recomendado)** | 238.300 | **45,1%** | −4% (quase iguais; o Campo é "a mais") |
| 0,84 | 256.600 | 48,1% | +4% |

Exemplo (s = 0,78, Σ_atual = 150.000): k = 238.300 / 187.900 = 1,268 → `oj10` (peso 7.000) dá 8.880 XP; `oj0` (1.200) dá 1.520.
`Σ_atual` real sai do `catalog_dump`/audit no WP9 (o exemplo só ilustra a proporção). Os Restos da Noite (caçadas
`repeatable`) **não** entram no audit. Ver Edge Cases e a pergunta ao usuário.

**F2 — Tempo por abate (alvo `band_probe --only=duel`: na faixa dos vizinhos)**: `t ≈ hp / (dps_bot × (1 − mitigação))`.
Os HP/ATK da tabela do §3.3 seguem a relação hp/nível dos vizinhos citados (ex.: `oath_sworn` 920 ≈ `skel_guard` 880 +1
nível; `grave_hauler` 1150 ≈ `citadel_horror` 1100 −1 nível de XP mas +1 de corpo). Exemplo: bot nv 26 com ~420 de dps
efetivo contra `oath_sworn` (DEF 30 ≈ 12% de mitigação) → 920 / (420 × 0,88) ≈ 2,5 s; o `skeleton` na mesma conta ≈ 2,4 s.

**F3 — XP por abate**: mesma curva dos vizinhos (24: 115-130, 25: 170, 26: 150, 27: 150-160, 28: 230; chefe 1.600 entre
Carniçal 1.400 e Vorhag 1.700).

## 5. Edge Cases

- **Mapa sem JSON** (antes do Blender): `oaths_ready()` falso → nada do Campo entra (mapa, NPCs, quests, gate). Monstros e
  itens existem sempre (sem spawner não aparecem; as caçadas geradas só olham monstros em mapas).
- **Garganta do Bastião antes do mapa**: a mudança do `build_field_ruins.py` só pode ser exportada junto com o
  `field_oaths.json` (mesma leva do Fable); sozinha, `_check_portal_arrivals` falha — não comitar separado. O WP3
  (rotas `cerco_*` no mesmo build) e este pacote mexem no mesmo arquivo: exportar em série, nunca em paralelo.
- **Jogador abaixo do 24** na vala: o portão recusa com o texto do §3.1; bots não passam por portões de jogador.
- **Vorhag vivo no nível 24+** (jogador pulou a linha principal): `oaths_malcom` não existe; `oj4`+ ficam fechadas
  (`prereq_all dw_bones_boss`); seguem abertas oj0-oj3 e oj9 (guia, Corveira, Sineiro); oj8 espera o oj6 (Malcom).
  O `oj11` só abre depois do `oj10`, que é do Malcom: o Arquivo (WP8) espera o Vorhag, de propósito.
- **`front_sul` vivo** (Torre ainda de pé): o `cultist` do front fica a ~20 m da chegada no Bastião; aceito (o nível 24
  limpa); some com `dw_frost_boss`.
- **Juramentados erguidos vivos quando Sir Edran reseta**: somem no `reset_boss` (regra dos lacaios de chefe).
- **Estandarte Fincado no rio/fora da arena**: `mob_pick: far` pode mirar alguém longe; o círculo é só aviso no chão e o
  `leash_range` 25 segura o chefe; se a mira cair na água, os lacaios nascem em volta do chefe (fallback do `boss_summon`).
- **Quest oj12 sem o Osric** (se o WP5 mover/renomear `gravedigger_osric`): o check de referência falha; WP5 mantém o id.
- **oj11 com a Senna**: `ruins_scholar` é NPC de `_ruins()` (sempre existe); ok.
- **Morte no Campo**: sem cristal, renasce no cristal vinculado (Bastião) — ~40 s de volta a pé (a garganta fica a ~110 m
  da praça); aceito.
- **Arquivo**: boca fechada por colisor invisível; `future_portals` não é portal da sim.
- **Save antigo**: nada a migrar (mapa, quests e itens novos; sem campo novo no save).

## 6. Dependencies

| Depende de | Como | Doc/arquivo |
|---|---|---|
| Bastião da Aurora (`field_ruins`) | garganta SE nova (`late_gorges`, `arrive_from_field_oaths`), trilha da escavação; Vera, Senna, Osric | `build_field_ruins.py`, este §3.1 |
| Proposta da faixa 20-30 | D1/D2/D7; §3 opção B; WP7 → este doc; WP8 lê §3.8/§3.9 | `design/gdd/dawn-band-refactor-proposal.md` (adicionar link para este doc no WP7) |
| WP2/WP3 (Cerco Vivo no Bastião) | mesmo `build_field_ruins.py`; rota `cerco_frost` não pode passar pela trilha de 66° | proposta §4 |
| WP4 (Restos da Noite) | o Campo é a caça "sem `unless`" da faixa 24-28; números de XP do audit juntos | proposta §5 |
| WP5 (Bastião vivo) | ids `digger_vera`, `gravedigger_osric`, `ruins_scholar` usados como giver/turnin; E2 "Desertor da Noite" liga com os Juramentados | proposta §6 |
| WP8 (Arquivo) | entrada reservada, lore oculto, `oj11` como portão | futuro `design/gdd/arquivo-de-velthar.md` |
| Sistemas | `QuestSystem`, `LootSystem` (elite), `MobSystem.update_boss` (fases), `GatherSystem`, `BotBandSystem`, `PortalSystem` (gates), `scale_xp` | código existente, sem mudança (exceto a decisão sobre `XP_QUEST_SHARE_BAND[20]`) |
| Arte | zona + 3 modelos (+1 opcional) pelo Fable; ícones `item_icons` dos 5 itens novos | §9 |

## 7. Tuning Knobs

| Knob | Onde | Valor | Faixa segura | Afeta |
|---|---|---|---|---|
| `XP_QUEST_SHARE_BAND[20]` | `data/balance.gd` | 0,65 → **0,78 (a decidir)** | 0,76-0,84 | audit 44-48% (F1); toda quest 20-29 |
| Pesos de XP das quests | `quests_catalog.gd` | 37.900 total | 30.000-45.000 | fatia do Campo na faixa |
| HP/ATK dos 6 comuns | `monsters_catalog.gd` | §3.3 | ±20% | tempo por abate |
| HP/ATK de Sir Edran | idem | 66.000 / 104 | 60-72k / 96-112 | solo 50-65%, trio ≥ 90% em 30-60 s |
| `berserk_after` | idem | 160 s | 130-190 | punição de grupo fraco |
| Recarga/raio do Estandarte Fincado | `skills_catalog.gd` | 20 s / r 5 | 16-26 s / 4-6 | pressão de lacaios |
| Contagem/respawn dos spawners | build (JSON) | §9 | ±30% | densidade; ≤ 60 vivos |
| Chance do `digger_orders` | `lt_night_digger` | 0,35 | 0,3-0,5 | duração do oj8 (~9 abates) |
| `bot_population` | `MapDef` | 3 | 2-5 | vida no campo |
| Nível do portão | `OATHS_GATES` | 24 | 23-25 | quando o Campo abre |

## 8. Acceptance Criteria

1. Testes: `_check_oaths_content` passa (todo monstro/item/NPC citado pelas quests e tabelas do Campo existe; quests
   completáveis; giver/turnin em `MapDef.npcs` quando o mapa existe; `oaths_malcom` com `if: dw_bones_boss`; skills
   `mob_banner_plant`/`mob_banner_sweep` existem e o preparo segue C8; chefe garante material; raro ≤ 0,05).
2. Com o JSON: `field_oaths` passa `_check_zone_layout` e `_check_places` (4 tipos, 2 cabanas, tudo alcançável a pé,
   lugares 40-112 m do centro e > 25 m entre si); portais com chegada válida nos dois lados; ponte nas duas travessias;
   `field_ruins.json` igual ao anterior fora a garganta/trilha (diff conferido).
3. `band_probe -- --from=24 --to=28 --only=duel --mob=carrion_crow,oath_sworn,oath_archer,vel_shade,night_digger,grave_hauler`:
   tempo por abate na faixa dos vizinhos (`skeleton`, `skel_guard`, `ghost`, `cultist` na mesma rodada, ±30%), 0 `travou`.
4. `boss_probe -- --boss=fallen_bearer --party=1,3 --trials=20`: solo 50-65%, trio ≥ 90% em 30-60 s (Vorhag na mesma sonda como referência).
5. `band_probe -- --from=20 --to=30 --only=audit`: XP de quest 44-48% **se** o usuário aprovar o `s` (F1); quests por nível
   25-28 ≥ 3 cada; 0 FLAG nas quests `oj*`.
6. Smoke sem `SCRIPT ERROR`; `sim_probe --map=field_oaths` < 5 ms/tick.
7. Tour com janela: 3 fotos (`CAM_top`, Vigília, Colina) com nota de layout ≥ 8 (`/layout-check`), em
   `production/qa/evidence/campo-juramentos/`.
8. Nenhuma quest da linha principal (`q12_ruins`, `dw_*`) tem `oj*` como pré-requisito (check).

---

## 9. BLENDER REQUEST (Fable)

**Script**: `tools/blender/zones/build_field_oaths.py` (molde `build_field_marsh.py`: `Zone("field_oaths", size=220,
rim=(99, 4, 2.5, 1.5))`, `places.build`, `nature.*`, `z.finish(export, poi=...)`). Exporta `assets/models/map_field_oaths.glb`
+ `data/zones/field_oaths.json`. Sem janela: `blender -b --factory-startup --python <script>` com `build(export=True)`.

**Bastião** (`build_field_ruins.py`, mesma leva): `OATHS_ANG = 66.0`, portal `polar(z, 66, 7)`, chegada `polar(z, 66, 15)`
(`z.late_gorges.append(...)` antes de `z.cliffs`), `LATE_TRAIL_SE = [(54, 80), (50, 88), <chegada>]` w 3,
`z.portal("to_field_oaths", ..., "field_oaths", OATHS_ARRIVE_IN, "Campo dos Juramentos (Lv 24-28)")`,
`z.data["arrive_from_field_oaths"]`. Tirar só a decoração no caminho (log "garganta sudeste"); resto do JSON byte a byte igual.
Conferir: nada sólido sobre a trilha, ≥ 1,8 m de folga; casa/cerca da escavação intactas.

**Zona**:
- Hub Acampamento da Vigília (0, 0): 5 tendas brancas em arco, fogueira, cavalete com **sino rachado** (marco do hub),
  carroça-banca da Vivandeira, 8 `SPAWN_hangout`, NPCs `SPAWN_npc_oaths_guide`, `_merchant`, `_malcom`.
- Garganta NO (-130°): portal `TRIG_portal_field_ruins` + `SPAWN_chegada_field_ruins`, `z.arrival` r 6.
- `PLACES`: `cabin` `sineiro` (-62, -38) NPC `oaths_bellringer` (capela em ruína, torre do sino caída ao lado);
  `cabin` `corveira` (20, -80) NPC `oaths_crowkeeper` (poleiros, penas); `shrine` `pedra_nomes` (-16, -60) NPC `oaths_stone`;
  `camp` `vala` (-44, 62) mob `night_digger` count 3 (covas, montes de terra, tenda negra, carroça de ossos);
  `dungeon` `arquivo` → `places.DUNGEONS["dg_archive"]` reservado (§3.8; `arch` "ziggurat" novo ou padrão + morro).
- Estradas e pontes: tabela do §3.2 (`z.road`, `z.river` "Córrego das Cinzas" `water_dark` w 4,5, `z.bridges()`).
- Patches (`Zone.patch`): Cemitério capim cinza-verde (0,46, 0,5, 0,42); Ruas pedra-areia (0,7, 0,66, 0,56); Vala
  terra escura (0,36, 0,3, 0,24); Colina terra queimada clara (0,58, 0,52, 0,42); chão geral capim seco (0,52, 0,52, 0,44).
- Props por POI: Cemitério = lápides em fileiras (sólidas, `OB_box`, vãos ≥ 3,5 m), elmos em estacas, mausoléu do Túmulo de
  Vorhag (-84, -4) com porta arrombada; Ruas = colunas (`pillar`), arcos caídos, calçamento em retalho; Colina = anel de
  estandartes caídos por fora (sem colisão dentro do r 15); Zigurate = 3 degraus de pedra clara, ≤ 8 m, sólido.
- **Landmark** o Estandarte Partido (-34, -14): morro sólido r 6 + mastro 18 m partido e inclinado + pano dourado rasgado
  (`horde.cloth`/`Dress.flag`, nunca placa); ≥ 14 m de toda estrada.
- Borda: `z.cliffs()` + `rim_belt` com `DEAD_TREES`; dispersão: árvores mortas, pedras, ruínas baixas (como o Bastião,
  menos densas), `nature.clear_banks`.
- **Spawners** (sem `when`): Cemitério `oath_sworn` 2×(4, 20 s), `oath_archer` (3, 22 s); Ruas `vel_shade` 2×(3, 22 s),
  `carrion_crow` (4, 16 s); beira do Cemitério/Choupana `carrion_crow` (3, 16 s); Vala `night_digger` (place) + `grave_hauler`
  (2, 26 s) + 2 `grave_hauler` no Túmulo (2, 30 s); Colina `oath_archer` (2, 22 s) fora da arena; **`fallen_bearer`** (1,
  respawn de chefe de campo, centro da Colina (50, 64), r 2). Total vivo ≈ 40.
- `GATHER` só nos dados (§3.7); `CAM_game` com variantes (`OATHS_CAM=vigilia|cemiterio|ruas|vala|colina|zigurate|chegada|estandarte`).

**Modelos novos** (`mob_kit`/módulo próprio, ex. `tools/blender/dawn_mobs.py` com `BUILDERS`):
1. `mob_oath_sworn` — cavaleiro-espectro da Aurora: armadura de placas lascada, tabardo dourado rasgado, escudo, corpo
   translúcido cinza-azulado com olhos `glow_*` frios; clipes de humanoide do kit (`idle run attack hit die` + `atk_charge`).
2. `mob_fallen_bearer` — Sir Edran: maior (escala 1,4), elmo fechado com crista partida, **estandarte enorme** na mão
   (mastro = arma; pano dourado escurecido nas pontas, dobrado), meia-capa; clipes de chefe (`MOB_BOSS_KEEP` + `cast_ground`
   para fincar o estandarte e `atk_2h_slash` para a varredura). Conferir chão (`--ground`): o mastro não fura o chão.
3. `mob_grave_hauler` — Carregador de Covas: corpanzil encurvado, capuz, pá grande nas costas/mãos, saco de terra;
   clipes de humanoide pesado (`attack` = golpe de pá de cima).
4. (opcional) `mob_carrion_crow` — corvo grande quadrúpede/ave de peças rígidas (`idle run attack hit die`), preto-azulado;
   sem ele fica o `mob_shaman_hawk` recolorido.

**Depois do GLB**: `loading_art.ZONES["field_oaths"]` (§3.11) e o `.jpg`; ícones dos 5 itens (`item_icons.tscn -- --only=...`).
Evidência: `production/qa/evidence/campo-juramentos/` (CAM_top, CAM_game da Vigília e da Colina, nota de layout).
