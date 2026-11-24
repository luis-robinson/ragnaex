# Brejo das Teias (field_marsh) — campo opcional 12-16

> Status: **ESPECIFICAÇÃO** (world-builder, 2026-11-24, pacote BREJO). Decisão do usuário (2026-11-24): 1 campo opcional
> "Brejo das Teias" (12-16, ao sul do Posto, entrada pela Floresta Sombria) + depois 1 mini-masmorra "Viveiro de Seiva"
> (outro pacote; aqui só a entrada fica reservada). Origem: `design/gdd/elf-band-refactor-proposal.md` §3 (opção B) e §6 D1/D2.
> Blender (zona, lado da Floresta, modelos) = agente Fable, a partir do BLENDER REQUEST em
> `production/session-state/agent-elf-brejo.md`. Textos de fala aqui são **provisórios** (passe do writer/narrative-director).

| Campo | Valor |
|---|---|
| Id do mapa | `field_marsh` (nome no jogo "Brejo das Teias") |
| Faixa | 12-16 (`level_range` 12-16; bots até 16 + `BOT_BAND_SLACK`) |
| Script da zona | `tools/blender/zones/build_field_marsh.py` (convenção `build_<zona>.py`; o pedido falava em `build_brejo.py`) |
| Visual | `assets/models/map_field_marsh.glb` + `data/zones/field_marsh.json` |
| Entrada | garganta sul da Floresta Sombria (rumo ~100°, entre o pântano da Floresta e o rio), portão só por nível (12) |
| Canon | Provisional · Visível ao jogador: Sim (zona), Descobrível (pistas da seiva), Oculto (verdade do Viveiro, §3.9) |

---

## 1. Overview

O Brejo das Teias é um vale alagado e fechado (~220 m) ao sul da Floresta Sombria, aonde escorre a água do pântano da
Floresta e um córrego cor de âmbar que desce das raízes de uma construção élfica afogada (o Viveiro de Seiva, fechado
por ora). No centro, as **Palafitas do Brejo**: um pouso de barqueiros e catadores sobre estacas, sem muro e sem cristal,
com guia, benzedeira, mascate e uma estaca de pedidos. Em volta, quatro POIs com cara própria: **Charco dos Sapos**
(oeste), **Mata das Teias** (nordeste, árvores mortas forradas de seda brilhante), **Cais dos Contrabandistas** (sudoeste,
acampamento hostil no canal de saída) e **Ponta da Bocarra** (sudeste, arena da Sapa-Mãe, mini-chefe do campo). É
**opcional**: nada da linha principal (el1-el6) passa por aqui; o que ele dá é XP de quest no meio da faixa (12-16, hoje o
trecho mais vazio fora da Pedreira), três materiais próprios, uma peça de equipamento garantida e a primeira pista
concreta do que é a seiva — e de onde ela vem.

## 2. Player Fantasy

"Saí da trilha e achei um lugar que ninguém do Posto conhece direito." O jogador desce por uma garganta úmida e chega a
um mundo mais baixo, mais lento e mais estranho que a Floresta: água parada, passarelas de tábua, sapos do tamanho de um
boi, teias que brilham à noite com a mesma cor dourada da seiva élfica. O pouso das palafitas é pequeno e acolhedor (fogo
baixo, redes, barcos virados), e cada morador tem um pedido que leva a um canto diferente do vale. A recompensa da volta
é tripla: **progresso** (XP e uma peça), **descoberta** (o córrego âmbar, o livro dos contrabandistas e a porta selada
do Viveiro) e **história** (Bento, o marido da Refugiada Dalva, está vivo aqui e manda notícia).

Pilares: exploração recompensada, identidade visual forte por POI, desafio de campo médio (Bartle: Explorador +
Conquistador). Em SDT: autonomia (ordem livre entre os ramos da cadeia), competência (mecânicas legíveis: puxão de língua,
teia, área de veneno), pertencimento (moradores que lembram de você).

---

## 3. Detailed Rules

### 3.1 Lugar no mundo e acesso

- Portal **`to_field_marsh`** na Floresta Sombria, garganta sul (rumo 100°: portal ~(-19.6, 111.3), chegada ~(-18.2, 103.5)),
  aberto como a garganta leste do Bosque (entra no FIM do build, `late_gorges`, trilha estreita de 3 m saindo do
  `arco_sul` em ~(-4, 80)). Rótulo: "Brejo das Teias (Lv 12-16)".
- Portal de volta **`to_forest`** na garganta norte do Brejo (rumo -95°). Chegada no Brejo = `target_pos` do portal da Floresta.
- **Portão de progressão**: `PORTAL_GATES["to_field_marsh"] = {"level": 12, "text": "A Soldada Meri barra a trilha do sul: 'Lá embaixo é sapo do tamanho de boi. Volte no nível 12.'"}`. Sem quest exigida (opcional; o
  `m0_brejo` só aponta o caminho).
- Lore do acesso: a Soldada Meri (portão sul do Posto) já diz "Do pântano só vem mosquito e aranha" — o portão sul olha
  para o Brejo; a trilha nova é a continuação da estrada sul.

### 3.2 Layout (Erenshor: vale fechado, hub no centro, POIs a 60-120 m, estradas curvas, água com pontes, landmark)

Coordenadas do jogo (x, z), norte = -z, 1 u = 1 m. Vale `SIZE` 220, `RIM` (99, 4, 2.5, 1.5) = raio útil ~91-107 m.

| Peça | Centro | Raio | Distância do hub | Notas |
|---|---|---|---|---|
| Hub: Palafitas do Brejo | (0, 0) | 12 (plataforma de tábua) + clareira 20 | — | sem muro/cristal; 4 saídas (N, O, L, S); 10+ bots cabem (pontos `SPAWN_hangout`) |
| Garganta norte (Floresta) | portal `polar(-95, 7)`, chegada `polar(-95, 15)` | — | ~84 | largo de chegada `z.arrival` r 6 |
| P1 Charco dos Sapos | (-70, -14) | 16 (charco `lake` r 9) | 71 | juncos, ninfeias, troncos podres, chão musgo-escuro |
| P2 Mata das Teias | (56, -46) | 18 | 73 | árvores mortas com copa de seda, casulos (enfeite), brilho âmbar fraco |
| P3 Cais dos Contrabandistas (place `camp`) | (-40, 66) | 12 | 77 | trapiche no canal, barris de seiva, caixotes, 2 canoas |
| P4 Ponta da Bocarra (arena do mini-chefe) | (44, 72) | 15 livre | 85 | chão de lama clara, ovos de sapo, anel de juncos altos por fora (sem colisão dentro) |
| Viveiro de Seiva (place `dungeon`, **reservado**) | portão (78, 2), boca virada a 190° | morro 5,5 | 78 | arco de raiz élfica com seiva; portal em `future_portals` (ver 3.8) |
| Cabana da Benzedeira (place `cabin`) | (-60, 24) | — | 65 | NPC `marsh_healer` |
| Cabana do Bento (place `cabin`) | (24, -70) | — | 74 | NPC `marsh_bento` (escondido entre a garganta e as teias) |
| Altar Afogado (place `shrine`) | (-22, -56) | — | 60 | NPC `marsh_altar` (board, prop_ruin): pedra élfica meio enterrada, veio âmbar |
| Landmark: Cipreste Enforcado | (-34, -36) | tronco 3,0, altura 22 | 49 | `giant_tree` morto com copa de teia; ≥ 14 m de qualquer estrada |
| Lagoa Turva | (8, 48) | 16 | 48 (centro) | água escura; nada a atravessar a nado |
| Córrego Âmbar (entra) | (100, 24) → (72, 22) → (46, 30) → (24, 44) | w 4,5 | — | nasce atrás do Viveiro, cai na lagoa; cor da água mais quente |
| Canal de saída | (−2, 62) → (−14, 68) → (−26, 84) → (−38, 106) | w 4,5 | — | sai da lagoa para a borda SO |

Estradas (catmull-rom, nunca reta; 4 m as principais, 3 m as trilhas):

| Id | Pontos | Largura |
|---|---|---|
| `N` (chegada → hub) | chegada → (-14, -64) → (-6, -40) → (-4, -14) → borda norte da plataforma | 4 |
| `O` (hub → Charco) | (-12, 0) → (-30, -6) → (-50, -16) → (-58, -14) | 4 |
| `L` (hub → Mata das Teias) | (12, -2) → (30, -14) → (44, -30) → (52, -40) | 4 |
| `S` (hub → Cais) | (-4, 12) → (-16, 30) → (-26, 48) → (-36, 62) | 4 |
| `SE` (hub → Ponta) | (10, 10) → (30, 20) → (52, 40) → (50, 60) → (44, 70) | 4; cruza o Córrego Âmbar ~(40, 29) = **Ponte 1** |
| `arco_oeste` (Charco → Cais) | (-66, 4) → (-62, 30) → (-48, 52) | 3 |
| `arco_sul` (Cais → Ponta) | (-36, 62) → (-24, 80) → (0, 84) → (24, 82) → (44, 74) | 3; cruza o canal ~(-26, 82) = **Ponte 2** |
| `arco_leste` (Mata → Viveiro) | (62, -30) → (74, -14) → frente do portão | 3 |

Sem becos acidentais: os arcos fecham dois anéis (O-S-arco_oeste e S-SE-arco_sul). As trilhas das cabanas/santuário saem
sozinhas da estrada mais perto (`places._trail`). Pontes só onde estrada cruza água (`z.bridges()`).
Passarelas de tábua (só visual, sobre chão andável) no Charco e na beira da lagoa: dão leitura de "brejo" sem mexer na sim.

Leitura de cima: o hub é um disco de tábua clara cercado de água escura e lama; as manchas por região separam os POIs
(Charco = verde-oliva escuro, Mata das Teias = cinza-musgo com fios claros, Cais = lama marrom-clara, Ponta = lama clara
com anel de junco). Nada alto (> 6 m) a menos de 14 m das estradas perto do hub; o Cipreste fica fora das rotas.

### 3.3 Monstros (12-16)

Regra: 4 comuns de campo + 1 de acampamento + 1 mini-chefe com skill própria + lacaio. Modelos existentes recoloridos
pela cor do `MonsterDef` (`EntityView` puxa a cor quando o modelo é de outro monstro). Modelos **novos** pedidos ao Fable
estão marcados (o catálogo já nasce com o modelo de reserva; trocar `model` quando o GLB existir).

| Id | Nome | Nv | Papel | Modelo (reserva → novo) | Skill | Onde |
|---|---|---|---|---|---|---|
| `marsh_leech` | Sanguessuga do Brejo | 12 | corpo a corpo rápido, frágil | `mob_larva` (verde-oliva) | — | Charco, beira oeste da lagoa |
| `bog_toad` | Sapo-Boi | 13 | corpo a corpo pesado + cuspe | `mob_slime` → **`mob_bog_toad`** | `mob_acid_spit` | Charco, Cabana da Benzedeira, margem sul |
| `marsh_spider` | Aranha do Brejo | 14 | corpo a corpo, prende | `mob_spider` (musgo + âmbar) | `mob_web` | Mata das Teias |
| `web_weaver` | Tecelã do Brejo | 15 | atiradora (`ranged`), poça de veneno | `mob_spider` (clara, menor) → opcional **`mob_web_weaver`** | `mob_venom_pool` | fundo da Mata das Teias |
| `marsh_smuggler` | Contrabandista | 15 | corpo a corpo + laço | `mob_bandit_thief` (azul-lodo) | `mob_snare_shot` | Cais (place `camp` + ronda) |
| `bog_mother` | Bocarra, a Sapa-Mãe | 16 | **mini-chefe de campo** (`is_boss`) | `mob_slime` ×2,2 → **`mob_bog_mother`** | `mob_toad_tongue`, `mob_bog_flop`, `mob_call_tadpoles` (NOVAS), `mob_acid_spit`; fases: girinos + ward | Ponta da Bocarra |
| `bog_tadpole` | Girino da Bocarra | 16 | lacaio (0 XP, sem saque) | `mob_larva` (pequena, escura) | — | só invocado |

Rei de campo: o sistema de elite (`Balance.ELITE_KILLS` 40) já faz o "Rei" de qualquer comum; nada a desenhar.

Skills novas do mini-chefe (em `skills_catalog.gd`, prefixo `mob_`; números iniciais, calibrar com `boss_probe`):
- `mob_toad_tongue` "Língua da Bocarra": TARGET, alcance 12, `mob_pick: far`, puxão (`pull` gap 0,6) + lento 35% 2 s, power 0,8,
  recarga 11 s, preparo 0,55 s, clipe `atk_throw`, vfx `poison`. Puxa o curador/atirador para perto (o tanque reage).
- `mob_bog_flop` "Barrigada": DIR (salto como o `mob_queen_leap`), raio 3,2 no pouso, `dash` 7 + atordoa 0,6 s, power 1,5, recarga 13 s, preparo 0,7 s
  (≥ 0,6 permitido para golpe no chão com raio ≥ 2 m — regra C8). Esquivável só saindo do círculo.
Fases (kit de chefe de grupo, check `_check_boss_mechanics`): 70% "Croooac! Filhotes, jantar!" 3 girinos (máx 5); 40% `ward` 0,4 enquanto
há girino vivo + `mob_venom_pool` + 3 girinos (máx 6); 15% `enrage` 1,25. Lacaios no ritmo: `mob_call_tadpoles` "Desova" (`boss_summon`
2 girinos, máx 4, recarga 24 s).
`berserk_after` 150 s. Falas `intro`/`last_words` provisórias: "Mais um que cai na lama..." / "Croo...ac...".

### 3.4 NPCs

| Id | Nome | Papel | Onde | Falas-guia (provisórias) |
|---|---|---|---|---|
| `marsh_guide` | Barqueira Ondina | quest (guia do campo) | hub, junto do fogo | rota dos POIs; "a água âmbar desce do leste" |
| `marsh_merchant` | Mascate Lino | merchant (poções M, ataduras; compra tudo) | hub, banca sobre a plataforma | "Aqui embaixo se paga em seda e pele de sapo." |
| `marsh_healer` | Benzedeira Zefa | quest (coletas) | Cabana da Benzedeira (place) | sapos, sanguessugas, âmbar |
| `marsh_bento` | Seu Bento, o Cabreiro | quest | Cabana do Bento (place) | marido da Refugiada Dalva (ver 3.9) |
| `marsh_altar` | Altar Afogado | board (caçadas repetíveis; `HUNT_GIVERS`) | santuário | runas élficas: "A seiva desce. Sempre desce." |

Sem cristal e sem Mestre de Skills (campo opcional, como o Bosque). Mercador sim: a volta precisa compensar (vender o saque
na hora e repor poção).

### 3.5 Quests (12, todas laterais; nenhuma é `prereq` da linha principal)

Ordem livre entre os ramos depois de `m0`. Pesos de XP abaixo são o número escrito (o total da faixa é escalado por
`QuestsCatalog.scale_xp`, §4).

| Id | Título | Tipo | Giver → turnin | Alvo | Nv | Pré | Peso XP | Ouro | Itens |
|---|---|---|---|---|---|---|---|---|---|
| `m0_brejo` | Mosquito e Aranha | REACH | `ranger_post` → `marsh_guide` | `field_marsh` | 12 | — | 120 | 50 | potion_hp_m ×2 |
| `m1_leeches` | Sangue no Junco | KILL | `marsh_guide` | `marsh_leech` ×10 | 12 | m0 | 220 | 70 | potion_hp_m ×2 |
| `m2_toad_skin` | Couro de Sapo-Boi | COLLECT | `marsh_healer` | `toad_skin` ×6 | 13 | m0 | 240 | 80 | potion_hp_m ×2, potion_mp_m ×1 |
| `m3_spiders` | Teia no Caminho | KILL | `marsh_guide` | `marsh_spider` ×10 | 13 | m1 | 260 | 85 | potion_hp_m ×2 |
| `m4_weavers` | As Tecelãs | KILL | `marsh_guide` | `web_weaver` ×6 | 14 | m3 | 280 | 90 | potion_mp_m ×2 |
| `m5_amber` | Água Cor de Mel | COLLECT | `marsh_healer` | `amber_sap` ×5 | 14 | m2 | 300 | 95 | elixir_stone ×1 |
| `m6_smugglers` | Barris sem Dono | KILL | `marsh_merchant`… ver nota | `marsh_smuggler` ×8 | 15 | m0 | 300 | 100 | potion_hp_m ×2 |
| `m7_ledger` | O Livro de Cargas | COLLECT | `marsh_guide` | `smuggler_ledger` ×3 | 15 | m6 | 260 | 90 | — |
| `m8_bento` | O Cabreiro Sumido | TALK | `marsh_guide` → `marsh_bento` | `marsh_bento` | 14 | m3 | 180 | 60 | potion_hp_m ×1 |
| `m9_letter` | Notícia para o Portão Norte | COLLECT (entrega, `give_items` `bento_letter`) | `marsh_bento` → `post_refugee_a` | `bento_letter` ×1 | 14 | m8 | 200 | 70 | — |
| `m10_bocarra` | A Sapa-Mãe | KILL | `marsh_guide` | `bog_mother` ×1 | 16 | m4, `prereq_all` [m5] | 650 | 200 | `reward_gear_tier` 2, elixir_might ×1 |
| `m11_report` | O Que Desce do Leste | TALK | `marsh_guide` → `ranger_post` | `ranger_post` | 16 | m10, `prereq_all` [m7] | 200 | 90 | potion_hp_m ×2 |

Nota `m6`: o mercador não é `quest` (papel `merchant`); o giver do m6 é a **Barqueira Ondina** (o Mascate só comenta).
Soma dos pesos: 3.210 (para comparar com a faixa, §4).
Cada `dialog_progress` diz a tecla/estratégia (regra do manual): ex. m3 "A aranha cospe teia num leque na frente: saia
pelo lado ou bloqueie (botão direito)"; m4 "A Tecelã fica longe e solta poça verde: saia da poça e feche a distância com
dash (Shift)"; m10 "Quando a língua vier (risco no chão até você), bloqueie ou deixe o tanque na frente; o círculo da
barrigada é aviso: saia dele. Com 60% ela chama girinos: mate-os antes de voltar nela".

### 3.6 Saque e economia

Materiais novos (em `items_catalog.gd`, `_mat`; preço de venda = 50%):

| Id | Nome | Preço | Fonte | Uso |
|---|---|---|---|---|
| `toad_skin` | Couro de Sapo-Boi | 14 | `bog_toad` 0,55 | quest m2; material de faixa (rank de skill/receita futura) |
| `amber_sap` | Âmbar de Seiva | 24 | `web_weaver` 0,4, `marsh_spider` 0,15, colheita na Mata das Teias | quest m5; pista do Viveiro; material do Viveiro (pacote seguinte) |
| `bog_heart` | Coração da Bocarra | 90 | `bog_mother` 1,0 (garantido) | material de tier do campo (boss garante) |
| `smuggler_ledger` | Página do Livro de Cargas | 0 | `marsh_smuggler` 0,35 (quest) | quest m7 |
| `bento_letter` | Carta do Bento | 0 | `give_items` do m9 | entrega |

Tabelas (`_lt`):
- `lt_marsh_leech`: `herb_green` 0,4 · `toad_skin` 0,1 · `potion_hp_m` 0,05.
- `lt_bog_toad`: `toad_skin` 0,55 · `herb_blue` 0,3 · `cap_leather` 0,03.
- `lt_marsh_spider`: `spider_silk` 0,6 (1-2) · `amber_sap` 0,15 · `hood_silk` 0,04.
- `lt_web_weaver`: `amber_sap` 0,4 · `spider_silk` 0,5 · `amulet_silk` 0,03.
- `lt_marsh_smuggler`: `smuggler_ledger` 0,35 · `bandit_badge` 0,45 · `iron_ore` 0,3 · `potion_hp_m` 0,1 · `boots_wolf` 0,04.
- `lt_bog_mother`: `bog_heart` 1,0 · `toad_skin` 1,0 (3-5) · `amber_sap` 1,0 (2-3) · `amulet_silk` 0,3 · `elixir_might` 0,5.

Regras: materiais 0,3-0,7 (os secundários abaixo de 0,3 são extras); equipamento raro ≤ 0,05; o chefe garante material de
tier. Ouro por monstro no padrão da faixa (6-24). Sem fonte nova de ouro infinito: o mercador só vende consumíveis.

### 3.7 Colheita (`MapsCatalog.GATHER["field_marsh"]`)

| Item | Forma | Centro | Raio | Quantos |
|---|---|---|---|---|
| `herb_blue` | `herb_blue` | (-60, -32) Charco (chão livre; (-66, -24) caía na beira da água) | 10 | 4 |
| `amber_sap` | `star` | (48, -36) Mata das Teias (borda) | 9 | 3 |
| `forest_mushroom` | `mushroom` | (-30, 40) beira oeste da lagoa | 10 | 4 |

### 3.8 Viveiro de Seiva — entrada reservada

- Place `dungeon` id `viveiro`, dungeon `dg_viveiro`, portão (78, 2), face 190° (boca para oeste-sudoeste, vista da câmera).
- Visual: arco de raiz élfica (como o `style: tree`, mas na encosta: morro com raiz por cima) com veio âmbar aceso; o
  Córrego Âmbar nasce atrás dele.
- Sim: o portal vai para `future_portals` (padrão do Ato III, `act3_ready.promote`) com `level` 17 e `arrive` (0, 44); não há
  portal na sim até o mapa `dg_viveiro` existir. Antes disso, um colisor invisível fecha a boca (o jogador vê, não entra).
- Quando o pacote do Viveiro entrar: `dg_viveiro` em `DUNGEON_DEFS`, promover o portal, `PORTAL_GATES["to_dg_viveiro"]`
  (nível 17 + `m11_report`?), e ligar `field_marsh` no `_check_places`.

### 3.9 Lore (canon provisório; cruzado com o existente)

- **O que o jogador vê**: o córrego que desce do leste tem cor de mel e as teias da Mata brilham com essa cor; as aranhas
  daqui são maiores e mais calmas que as do Ninho; os contrabandistas enchem barris com "água de mel" e despacham pelo canal.
- **Descobrível**: o Livro de Cargas (m7) lista barris "para o Posto de Troca do Norte" pagos em aço élfico — alguém entre
  os humanos compra seiva dos elfos; o Altar Afogado tem runa élfica "A seiva desce. Sempre desce."; a porta do Viveiro.
- **Oculto (verdade, para o pacote do Viveiro)**: o Viveiro é um berçário élfico de seiva — mudas da Árvore-Mãe criadas
  em tanques sob a raiz; o vazamento dele engorda os bichos do Brejo. A seiva não "enlouquece" sozinha: amplifica o que já
  está lá (fome na aranha, ambição no rei). Isso deixa a dúvida da Sacerdotisa Myrel e a fala do Ancião Vaeril ("era um
  bom menino antes da seiva") ambas parcialmente certas.
- **Bento**: marido da Refugiada Dalva (`post_refugee_a`: "Meu marido ficou para soltar as cabras. Ainda espero ele no
  portão norte."). Ele fugiu dos elfos para o SUL pelas cabras, se perdeu no brejo e vive escondido; não volta ao Posto
  enquanto as investidas vierem pelo norte. O m9 entrega a carta (Dalva sabe que ele vive); o **reencontro** fica com o
  pacote LIVING (`design/gdd/elf-band-living.md`: `post_l_husband` "Seu Bento, marido da Dalva", aparece ao lado dela
  na trégua, depois do `el6_king` **e** do `m9_letter`: decisão do usuário 2026-11-24, "só depois da carta"). Para não haver dois Bentos ao mesmo tempo, `marsh_bento` tem `unless: ["el6_king", "m9_letter"]` (`MapsCatalog.BENTO_HOME`; lista = todas)
  (sai do Brejo quando ele volta ao Posto). O nome "Bento" vem do LIVING (estabelecido antes); o rascunho daqui dizia "Tomé".

Contradictions check: Soldada Meri ("do pântano só vem mosquito e aranha") = coerente; o pântano da Floresta (lago
`pantano` em (-30, 84)) escoa para a garganta sul = coerente com o Brejo abaixo; Rainha Aranha (Ninho, 20) é outra
ninhada (aranhas do Ninho = escuras e roxas, do Brejo = musgo e âmbar); Dalva espera no portão NORTE e o marido está ao
SUL: coerente (ele não sabe que ela está no Posto; a carta resolve). Nenhum fato estabelecido muda.

### 3.10 Bots

- `bot_population` 3 (mesmo do Bosque). Bots nascem/caçam pela regra de faixa (`BotBandSystem`, `level_range` 12-16 +
  `BOT_BAND_SLACK`); sem cristal, o bot volta a renascer no Posto (`home_map` = povoado com cristal da faixa).
- Pontos `SPAWN_hangout_NN` (8) na plataforma do hub. Corredores ≥ 3 m entre sólidos (bots sem navmesh); passarelas não
  colidem.

### 3.11 Música e arte de carregamento

- `Music.MAP_THEME["field_marsh"] = "campo"` agora; tema próprio "brejo" (CC0, `build_music.py`) é pedido aberto ao
  sound-designer.
- `loading_art.ZONES["field_marsh"]`: nome "Brejo das Teias", chão = `ground_color`, mood `forest`, câmera sobre a lagoa
  (`at` (10, 20), az -20, dist 100, elev 26, pitch 18, fov 50). `.jpg` refeito depois do GLB (Blender, Fable).

---

## 4. Formulas

**F1 — XP de quest da faixa** (`QuestsCatalog.scale_xp`): `k = quest_share(10) × band_xp(10, 20) / Σ peso` e cada quest
recebe `round(peso × k / 10) × 10`. Variáveis: `peso` = `reward_xp` escrito; `Σ peso` = soma das não repetíveis com
`level_req` em [10, 20). Hoje Σ ≈ 76.700 (48 quests). Com o Brejo: Σ ≈ 79.900 (+4,2%). Efeito: **as quests já existentes
da faixa dão ~4% menos XP**, o total da faixa não muda; o jogador que faz o Brejo ganha 3.210/79.900 ≈ 4,0% da XP de
quest da faixa a mais do que quem pula. Faixa aceitável (o Bosque dos Xamãs fez o mesmo). Teste: 40-50% da faixa via
quests (check existente) continua valendo porque o total é fixo.

**F2 — Tempo por abate (alvo do band_probe 3-5 s)**: `t ≈ hp / (dps_bot × (1 − mitigação))`. Comuns escolhidos por
analogia de faixa (mesma relação hp/nível que os vizinhos):

| Monstro | Nv | HP | ATK | DEF/MDEF | Vizinho de referência |
|---|---|---|---|---|---|
| marsh_leech | 12 | 240 | 30 | 4/5 | bandit_footpad 12 |
| bog_toad | 13 | 400 | 40 | 9/6 | trent_young 14 (385) / spider 13 (360) |
| marsh_spider | 14 | 380 | 42 | 8/6 | spider 13 (360) |
| web_weaver | 15 | 300 | 16 (matk 34) | 6/10 | shaman_caller 16 (360, ranged) |
| marsh_smuggler | 15 | 460 | 47 | 10/7 | bandit 15 (480) |
| bog_mother | 16 | 62.000 | 86 | 13/12 | calibrado no `boss_probe` contra o Arquidruida 18 (58.000): ver AC 4 |

XP por abate na mesma curva (leech 64, toad 80, spider 84, weaver 90, smuggler 94, boss 800).
Alvo de aceitação: `band_probe --from=12 --to=16 --only=duel` com 3-5 s por abate e `travou` 0.

## 5. Edge Cases

- **Mapa sem JSON** (antes do Blender): `MapsCatalog` só monta `field_marsh` se `data/zones/field_marsh.json` existir
  (`MapsCatalog.has_zone`); as quests do Brejo só entram se o mapa existe (o `m0` aponta para ele). Monstros, itens e
  saque existem sempre (sem spawner não aparecem; as caçadas geradas só olham monstros em mapas).
- **Portal da Floresta antes do mapa**: a mudança do `build_field_forest.py` só pode ser exportada junto com o
  `field_marsh.json` (mesma leva do Fable); se a Floresta sair antes, `_check_portal_arrivals` falha — não comitar separado.
- **Jogador abaixo do 12** na garganta: o portão recusa com o texto do 3.1; bots não passam por portões de jogador (regra
  existente: portão vale só para o jogador) mas não caçam fora da faixa.
- **Girinos vivos quando a Bocarra reseta**: lacaios com 0 XP somem no `reset_boss` (regra existente dos lacaios de chefe).
- **Língua puxando para dentro da água**: o `pull` para a `gap` 0,6 m do chefe; a arena tem 15 m livres e a Bocarra fica
  presa pelo `leash_range` 25 m à arena, longe da lagoa (≥ 20 m), então o puxado nunca cai em água.
- **Quest m9 sem a Dalva** (se o pacote LIVING mover/renomear `post_refugee_a`): o check de referência do Brejo falha no
  teste; o LIVING tem de manter o id ou avisar.
- **Morte no Brejo**: sem cristal, renasce no cristal vinculado (Posto da Floresta, normalmente) — ~90 s de volta a pé;
  aceito (mesmo do Bosque).
- **Viveiro**: boca fechada por colisor invisível; `future_portals` não é portal da sim, bots não tentam ir.
- **Save antigo**: nada a migrar (mapa novo, quests novas, sem campo novo no save).

## 6. Dependencies

| Depende de | Como | Doc/arquivo |
|---|---|---|
| Floresta Sombria (`field_forest`) | garganta sul nova, trilha do `arco_sul`; Soldada Meri | `build_field_forest.py`, este doc §3.1 |
| Proposta da faixa élfica | D1/D2; §3 opção B; §4.2 (Dalva reencontra o marido após `el6_king`) | `design/gdd/elf-band-refactor-proposal.md` |
| Pacote LIVING | id `post_refugee_a` (Dalva) é turnin do m9; o reencontro visual é dele | `production/session-state/agent-*living*` |
| Pacote do Viveiro (WP6) | place reservado, `amber_sap`, lore oculto §3.9 | futuro `design/gdd/viveiro-de-seiva.md` |
| Sistemas | `QuestSystem`, `LootSystem` (elite), `MobSystem.update_boss` (fases), `GatherSystem`, `BotBandSystem`, `PortalSystem` (gates) | código existente, sem mudança |
| Arte | zona + 2-3 modelos (Fable), ícones `item_icons` dos 5 itens novos | BLENDER REQUEST |

A proposta da faixa (§7 WP5) aponta para este doc; o doc do Viveiro deve citar o §3.8/§3.9 daqui.

## 7. Tuning Knobs

| Knob | Onde | Valor | Faixa segura | Afeta |
|---|---|---|---|---|
| HP/ATK dos 5 comuns | `monsters_catalog.gd` (conteúdo) | §4 F2 | ±20% | tempo por abate (3-5 s) |
| HP/ATK da Bocarra | idem | 62.000 / 86 | 55-70k / 78-92 | solo 50-65% e trio 100% em 30-60 s (o Arquidruida 18 dá 65%/100%/50 s) |
| `berserk_after` | idem | 150 s | 120-180 | punição de grupo fraco |
| Contagem/respawn dos spawners | build (JSON) | §BLENDER | ±30% | densidade; perf ≤ 60 monstros vivos |
| Pesos de XP das quests | `quests_catalog.gd` | 3.210 total | 2.500-4.000 | diluição da faixa (F1) |
| `bot_population` | `MapDef` | 3 | 2-5 | vida no campo vs. bots fora do caminho principal |
| Chance do `smuggler_ledger` | `lt_marsh_smuggler` | 0,35 | 0,3-0,5 | duração do m7 (3 páginas ≈ 9 abates) |
| Nível do portão | `PORTAL_GATES` | 12 | 11-13 | quando o Brejo abre |

Constantes de sistema novas: nenhuma (`Balance` não muda; números de monstro/quest são conteúdo).

## 8. Acceptance Criteria

1. Testes: `_check_marsh_content` passa (todo monstro/item/NPC citado pelas quests e tabelas do Brejo existe; quests
   completáveis; giver/turnin em `MapDef.npcs` quando o mapa existe; skills `mob_toad_tongue`/`mob_bog_flop` existem e o
   preparo segue a regra C8; boss garante material; raro ≤ 0,05).
2. Com o JSON: `field_marsh` passa `_check_zone_layout` e `_check_places` (os 4 tipos, 2 cabanas, tudo alcançável a pé,
   lugares 40-112 m do centro e > 25 m entre si); portais com chegada válida nos dois lados; ponte nas duas travessias.
3. `band_probe -- --from=12 --to=16 --only=duel --mob=marsh_leech,bog_toad,marsh_spider,web_weaver,marsh_smuggler`:
   tempo por abate na faixa dos vizinhos (medido 2026-11-24: 1,1-2,6 s; `spider` 1,3 s e `bandit` 1,8 s na mesma rodada —
   a sonda com bots equipados dá menos que os 3-5 s do pedido para TODA a faixa), 0 `travou`.
4. `boss_probe -- --boss=bog_mother --party=1,3 --trials=20`: solo 50-65%, trio ≥ 90% em 30-60 s (medido 2026-11-24 com
   62.000/86 + kit de grupo na arena do Arquidruida: solo 12/20, trio 20/20 em 38,8 s; o Arquidruida na mesma sonda: 13/20, 20/20, 50 s).
5. XP de quest da faixa 10-20 continua em 40-50% (check existente) e há 10+ quests na faixa.
6. Smoke sem `SCRIPT ERROR`; `sim_probe --map=field_marsh` < 5 ms/tick.
7. Tour com janela: 3 fotos (`CAM_top`, hub, Ponta) com nota de layout ≥ 8 (`/layout-check`), salvas em
   `production/qa/evidence/brejo/`.
8. Nenhuma quest da linha principal (`el*`, `c*`) tem `m*` como pré-requisito (check).
