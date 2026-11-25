# Viveiro de Seiva (dg_viveiro) — mini-masmorra élfica 17-19

> Status: **ESPECIFICAÇÃO + DADOS** (world-builder, 2026-11-25, pacote VIVEIRO). Decisão do usuário (2026-11-24, D1/D2):
> 1 mini-masmorra élfica com 1 chefe + 1 sala de quebra-cabeça leve; recompensa = material de tier do Gunnar (+6).
> Contrato de ids/salas: `production/session-state/viveiro-contract.md`. Mapa/modelos = agente Fable
> (`production/session-state/agent-viveiro-blender.md`); notas de dados: `production/session-state/agent-viveiro-data.md`.
> Parte de: `design/gdd/brejo-das-teias.md` §3.8 (entrada) e §3.9 (lore oculto); proposta `elf-band-refactor-proposal.md` §3 opção B.
> Falas são **provisórias** (passe do writer/narrative-director).

| Campo | Valor |
|---|---|
| Id do mapa | `dg_viveiro` "Viveiro de Seiva" (`DUNGEON_DEFS`, parent `field_marsh`, `levels` 17-19) |
| Entrada | Brejo das Teias, portão de raiz (78, 2), boca a 190°; portal `to_dg_viveiro` (chegada (0, 44)) |
| Portão | `PORTAL_GATES["to_dg_viveiro"] = {"level": 17}` — só nível, sem quest (o Brejo é opcional e o Viveiro também) |
| Visual | `assets/models/map_dg_viveiro.glb` + `data/zones/dg_viveiro.json` (`build_dungeons.py`, `places.DUNGEONS["dg_viveiro"]`) |
| Canon | Provisional · Visível: Sim (masmorra) · Descobrível: tanques e tratadores · Oculto→revelado: a verdade da seiva (quest `v4`) |

---

## 1. Overview

Debaixo da raiz que fecha o leste do Brejo existe um berçário élfico: o **Viveiro de Seiva**, onde mudas da Árvore-Mãe
crescem dentro de tanques de vidro cheios de seiva. Os tanques racharam; a seiva escorre pelo Córrego Âmbar e engorda
tudo o que vive no Brejo. O jogador desce por quatro salas — **Raízes Encharcadas**, **Estufa das Mudas** (lateral),
**Sala dos Tanques** e **O Berço** — e enfrenta **A Muda-Mãe**, a muda mais velha, que cresceu dentro de um tanque
partido e se alimenta dos tanques que ainda estão inteiros em volta dela. O quebra-cabeça leve é esse: **quebrar os
tanques do Berço antes (ou durante) a luta** decide quantas mudas despertam com ela. A recompensa garantida é
**Seiva da Árvore-Mãe** (`mother_sap`), o material com que o Gunnar leva a Glória (lendários do 20) do +6 ao +9.

## 2. Player Fantasy

"Achei a fonte." Depois do córrego âmbar, das teias douradas e do livro dos contrabandistas, o jogador entra no lugar de
onde tudo desce — um porão vivo, morno, com cheiro de casca e mel, e vidro rachado por todo lado. A fantasia é de
**descoberta com consequência**: o que o jogador quebra muda a luta (competência, SDT), e a última quest explica a seiva
sem mentir: ela não enlouquece ninguém, ela **amplifica** o que já existe. Bartle: Explorador (lore, sala lateral) e
Conquistador (chefe de grupo que recompensa preparo). Pilares: exploração recompensada; mecânica legível de cima (círculos
âmbar no chão, tanques que brilham); grupo primeiro (a luta é para 3-5).

---

## 3. Detailed Rules

### 3.1 Acesso
- Portal `to_dg_viveiro` no Brejo (promovido de `future_portals` pelo Fable ao refazer o `field_marsh`); volta pelo portal
  de saída da masmorra (`return`/chegada do `build_dungeons`) para a frente do portão de raiz.
- `PORTAL_GATES["to_dg_viveiro"] = {"level": 17, "text": "A raiz se fecha como um punho. A seiva lá dentro queima quem
  ainda é fraco: volte no nível 17."}`. Sem quest (o GDD do Brejo perguntava `m11_report?`; ficou opcional: quem chegar
  no 17 por outro caminho entra).
- O mapa só entra na sim com o JSON (`MapsCatalog.viveiro_ready()`); antes disso `dg_viveiro` fica fora de `build()` e as
  quests do Viveiro não carregam (mesma regra do `marsh_ready`).
- Masmorra compartilhada (`parent_map`), `bot_population` 0: bots não caçam lá sozinhos; entram seguindo o grupo do jogador.

### 3.2 Salas (do contrato; o Fable monta `places.DUNGEONS["dg_viveiro"]["layout"]`)
| Sala | Raio | Conteúdo (spawners do JSON) | Papel |
|---|---|---|---|
| `chegada` | — | nada | largo de chegada |
| `raizes` Raízes Encharcadas | ~11 | `sap_sprout` ×4 + `sap_spider` ×1 | aquecimento |
| `estufa` Estufa das Mudas (lateral) | ~10 | `elf_tender` ×2 + `sap_sprout` ×2 | ala opcional, tratadores que curam |
| `tanques` Sala dos Tanques | ~12 | `sap_tank` ×3 (parados) | **ensina** o tanque: quebra, solta âmbar, não revida |
| `berco` O Berço | ~16 | `boss_sap_mother` ×1 (+ 4 tanques dela, nascem sozinhos) | chefe |
| ligações | — | `raizes>estufa` `sap_spider` 2 · `raizes>tanques` `sap_sprout` 2 · `tanques>berco` `elf_tender` 1 | |

### 3.3 O quebra-cabeça leve (só mecânica existente: ninho de ovos do Dragonete)
Escolha: **os tanques do Berço são os "ovos" da Muda-Mãe** (`MonsterDef.eggs` + fase `hatch`, `MobSystem.ensure_eggs/hatch`),
não um selo de portal. Motivo: um selo por chefe (`PORTAL_GATES.bosses`) só funciona entre dois mapas, e o Viveiro é um
mapa só; o ninho já existe, já é testado no Covil do Dragonete, a sim e os bots já o entendem, e a leitura é clara
(objeto parado brilhando em volta do chefe = "quebre isto").
- Fora de luta a Muda-Mãe repõe **4 `sap_tank`** num anel de raio **7 m** em volta do ponto de nascer dela (refaz depois
  de um wipe/reset). Tanque não ataca, não se mexe, tem pouca vida e 0 XP; quebrar dá âmbar.
- **70%**: metade dos tanques inteiros (arredonda para cima) **desperta**: o tanque some e nasce uma `sap_hatchling`
  "Muda Desperta" (lacaio, 0 XP, sem saque) já na luta.
- **40%**: todos os tanques que sobraram despertam + **ward 0,5** (a Muda-Mãe toma metade do dano enquanto houver muda
  desperta viva; tanque inteiro não segura o ward, regra do ovo) + entra o **Pulso do Berço**.
- **15%**: fúria ×1,3.
- Resultado: grupo que quebra os 4 tanques antes de puxar (ou nos primeiros 30%) luta sem lacaios e sem ward; grupo que
  ignora enfrenta até 4 mudas + ward. A Sala dos Tanques, antes, ensina que tanque quebra fácil e não revida.

### 3.4 Monstros (17-19)
Modelos novos do Fable com reserva até o GLB existir (`MonstersCatalog.VIVEIRO_MODELS`, mesmo padrão do `MARSH_MODELS`).
| Id | Nome | Nv | HP | ATK/MATK | DEF/MDEF | XP | Papel | Skill | Modelo (novo → reserva) |
|---|---|---|---|---|---|---|---|---|---|
| `sap_sprout` | Muda de Seiva | 17 | 540 | 52 | 11/8 | 112 | corpo a corpo | `mob_sap_lash_small` (cone curto, lento) | `mob_sap_sprout` → `mob_trent` (×0,8) |
| `sap_spider` | Aranha de Seiva | 18 | 420 | 18/46 | 8/12 | 120 | atiradora (`ranged`) | `mob_venom_pool` | `mob_spider` (âmbar) |
| `elf_tender` | Tratador do Viveiro | 18 | 480 | 20/44 | 9/14 | 124 | atirador que **cura** os vizinhos | `mob_tender_mend` | `mob_elf_mage` (âmbar/verde) |
| `sap_tank` | Tanque de Seiva | 18 | 650 | 1 | 14/14 | 0 | parado (`egg`), quebrável | — | `mob_sap_tank` → `mob_dragon_egg` |
| `sap_hatchling` | Muda Desperta | 19 | 900 | 46 | 12/10 | 0 | lacaio (chocado do tanque) | — | `mob_sap_sprout` → `mob_trent` (×0,75) |
| `boss_sap_mother` | A Muda-Mãe | 19 | 86.000 | 98/80 | 15/16 | 1.100 | chefe de grupo (`is_boss`) | ver 3.5 | `mob_sap_mother` → `mob_trent` (×2,0) |

### 3.5 A Muda-Mãe (chefe)
- Parada no meio do Berço (`move_speed` baixo 2,6, enraizada no tanque partido), alcance 3,0, `leash_range` 22,
  `berserk_after` 150 s. `intro`: "Mais mãos... a seiva sempre manda mais mãos." `last_words`: "A raiz... ainda...
  bebe..." (provisórias).
- Skills:
  1. **Açoite de Raiz** `mob_sap_lash` — CONE 110°, raio 3,8, power 1,6, recarga 7 s, preparo 0,65 s. Golpe do tanque.
  2. **Raiz que Puxa** `mob_sap_root_hook` — TARGET, alcance 14, `mob_pick: far`, `pull` gap 0,6 + root 0,8 s, power 0,7,
     recarga 12 s, preparo 0,6 s. Traz o curador/atirador para o pé do chefe (o tanque reage).
  3. **Chuva de Seiva** `mob_sap_rain` (mecânica legível nova, de efeito existente `barrage`) — GROUND, `mob_pick: random`,
     5 círculos âmbar de 2,4 m que caem 1,5 s depois (spread 10), power 1,2 + lento 40% 2 s. Bots já fogem de `hazards`.
     Não esquivável pela AGI (regra de chão avisado de chefe): só sair do círculo salva.
  4. **Pulso do Berço** `mob_sap_pulse` (só a partir de 40%) — SELF, `barrage` `shape: ring`: 2 anéis de 2 m em volta
     dela (início a 2 m, espaçados 5 m) que caem 1,6 s depois, um após o outro (0,6 s); power 1,1. Leitura: "fique no vão
     entre os anéis ou longe". Fala do aviso: "O Berço pulsa!".
  5. **Brotar** `mob_sap_sprout_call` (a partir de 70%) — `boss_summon` 1 `sap_hatchling` a cada 30 s (máx 2 vivas). Lacaios
     no ritmo (kit de chefe de grupo, check `_check_boss_mechanics`); os tanques continuam sendo a fonte grande de adds.
- Tanques/ward/fases: §3.3. Com Brotar, o ward da fase 40% também se mantém com a muda brotada viva: tirar lacaio é
  trabalho de quem não tanqueia.

### 3.6 Saque e economia
| Tabela | Entradas |
|---|---|
| `lt_sap_sprout` | `amber_sap` 0,45 · `ent_bark` 0,3 · `potion_hp_m` 0,06 |
| `lt_sap_spider` | `spider_silk` 0,5 (1-2) · `amber_sap` 0,35 · `amulet_silk` 0,03 |
| `lt_elf_tender` | `amber_sap` 0,45 · `elf_steel` 0,3 · `potion_mp_m` 0,1 |
| `lt_sap_tank` | `amber_sap` 0,6 (1-2) |
| `lt_sap_mother` | **`mother_sap` 1,0 (2-3)** · `amber_sap` 1,0 (3-5) · `elf_steel` 1,0 (2-3) · `heartwood` 0,5 · `elixir_might` 0,5 · `legend_coin` 0,3 |
Material de tier do Gunnar: `ItemSystem.enhance_cost` — lendário de nível `PLUS_ELF_LEVEL` (20, Glória) usa `elf_steel` até
+5 e `mother_sap` do +6 ao +9 (`nxt - PLUS_STAR_FROM + 1` = 1, 2, 3, 4 seivas). Hoje a seiva sai da Ilwen (2-3), do Rei (3-5),
de quests (1+1) e raro de trent/guardião. O Viveiro é a 1ª fonte **repetível de grupo na faixa 17-19**: +2-3 por limpeza.
Sem ouro infinito: o chefe dá ouro na faixa dos vizinhos (110-220) e a seiva vende a 35 (50% de 70).

### 3.7 Quests (4 laterais; giver no Brejo; nenhuma é pré-requisito da linha principal)
| Id | Título | Tipo | Giver → turnin | Alvo | Nv | Pré | Peso XP | Ouro | Itens |
|---|---|---|---|---|---|---|---|---|---|
| `v1_root_door` | A Porta de Raiz | REACH | `marsh_guide` | `dg_viveiro` | 17 | `m0_brejo` | 150 | 60 | potion_hp_m ×2 |
| `v2_tanks` | Vidro e Seiva | KILL | `marsh_healer` | `sap_tank` ×4 | 17 | `v1_root_door` | 300 | 90 | potion_mp_m ×2 |
| `v3_sap_mother` | A Muda-Mãe | KILL | `marsh_guide` | `boss_sap_mother` ×1 | 19 | `v1_root_door`, `prereq_all` [`v2_tanks`] | 700 | 220 | `reward_gear_tier` 2, elixir_might ×1 |
| `v4_what_grows` | O Que Cresce Sob a Raiz | TALK | `marsh_healer` → `ranger_post` | `ranger_post` | 19 | `v3_sap_mother` | 250 | 100 | mother_sap ×1 |
Soma dos pesos 1.400. O `v4` revela o lore oculto (§3.8) pela Zefa (que já analisou o âmbar no m5) e leva a notícia ao
Teo (que já ouviu o m11). Dicas práticas em cada `dialog_progress` (tecla/estratégia).

### 3.8 Lore (canon provisório)
- **Visível**: tanques de vidro com mudas dentro, piso de madeira viva, tratadores élficos que cuidam das mudas mesmo com o
  vidro rachado; o córrego âmbar nasce no Berço.
- **Descobrível**: os tratadores curam as mudas e o chefe (não atacam por raiva: protegem); a Muda-Mãe "bebe" os tanques.
- **Revelado no `v4`** (era Oculto no GDD do Brejo §3.9): o Viveiro é o berçário das mudas da Árvore-Mãe; a seiva vaza e
  engorda os bichos do Brejo; ela **amplifica o que já existe** (fome na aranha, ambição no rei). Isso deixa Myrel ("a seiva
  escolheu o rei, ou o rei escolheu a seiva?") e Vaeril ("era um bom menino antes da seiva") ambos parcialmente certos.
- **Contradictions check**: Árvore-Mãe e seiva (Cidade Élfica, `mother_sap` "Dourada e morna") = coerente; Gunnar
  ("Do +6 em diante só a seiva da Árvore-Mãe segura o encanto") = coerente, a recompensa é a mesma seiva; m11 (Ondina: "o
  córrego nasce numa porta de raiz a leste. Fechada.") = coerente (abre no 17); Rei Élfico continua vilão da linha principal
  (o Viveiro explica, não absolve). Nenhum fato estabelecido muda.

### 3.9 Música, arte, bots
- `Music.MAP_THEME["dg_viveiro"] = "elfos"` (raiz élfica; sem faixa nova).
- `loading_art.ZONES/BOSSES["dg_viveiro"]` (Fable): chefe `boss_sap_mother`, modelo `mob_sap_mother`, escala 2,0.
- Bots: só com o grupo do jogador; o ninho e o `hazards` já são tratados pelo `BotBrain` (fogem de círculo, batem no lacaio).

---

## 4. Formulas

**F1 — XP de quest da faixa** (`QuestsCatalog.scale_xp`): `k = quest_share × band_xp(10, 20) / Σpeso`; cada quest recebe
`round(peso × k / 10) × 10`. Σ hoje ≈ 79.900 (com o Brejo); com o Viveiro Σ ≈ 81.300 (+1,75%). As quests da faixa dão ~1,7%
menos; quem faz o Viveiro ganha 1.400/81.300 ≈ 1,7% a mais da XP de quest da faixa. O total (40-50% da faixa) não muda.

**F2 — Tempo por abate** `t ≈ hp / (dps_bot × (1 − mit))`, alvo do `band_probe` = vizinhos da faixa (1-3 s com bots
equipados). Comuns pela razão hp/nível dos vizinhos: `sap_sprout` 540 (17) vs `trent_young` 385 (14) e `bandit` 480 (15).

**F3 — Tanques e lacaios**: inteiros na fase 70% = `T` (0-4) → despertam `ceil(T/2)`; na fase 40% despertam os `T'`
restantes. Lacaios máximos = `T` (0-4). Ward ativo ⇔ `adds_alive > 0` (tanques não contam). Exemplo: o grupo quebra 2 antes
de puxar → T = 2 → 1 muda em 70%, 1 em 40% (ward até ela morrer).

**F4 — Chefe**: HP 86.000 (começou em 66.000 por analogia com Arquidruida 18 = 58.000 e Bocarra 16 = 62.000; a sonda a
66.000 deu trio em 28,9 s, rápido demais). Dano escala com quem luta (`BOSS_CROWD_MULT`). Medido 2026-11-25 (86.000/98 + Brotar,
nível 19, 20 lutas): solo 12/20 em 120 s, trio 20/20 em 41,2 s, grupo de 5 17/20 em 24,5 s. Alvo `boss_probe`: trio ≥ 90% em 35-65 s; solo 30-60% (é masmorra de grupo; group-first).

## 5. Edge Cases
- **Sem JSON** (`viveiro_ready()` falso): `dg_viveiro` não entra em `gd.maps`, as 4 quests não carregam; monstros/skills/
  saque existem (sem spawner não aparecem). O portal do Brejo continua em `future_portals` até o Fable promover.
- **Portal promovido sem o mapa**: só acontece se o JSON do Brejo sair sem o do Viveiro — `_check_portal_arrivals` falha;
  exportar os dois juntos (mesma leva do Fable).
- **Wipe/reset**: `reset_boss` some com as mudas despertas e o chefe repõe os 4 tanques fora de luta (`ensure_eggs`).
- **Tanques mortos e chefe vivo**: ficam mortos até o chefe resetar (sem respawn próprio); chocar com 0 tanques = nada.
- **Quest `v2_tanks`**: conta tanque da Sala dos Tanques (spawner, respawn normal) **e** do Berço — dá para fechar sem o chefe.
- **Raiz que Puxa** em parede/pilar: `pull` para a 0,6 m do chefe, que fica no miolo livre do Berço (contrato: sem
  estátua/pilares no miolo; anel dos tanques a 7 m precisa ficar andável).
- **Bots fora do grupo**: `bot_population` 0 e masmorra fora da caça solo; nenhum bot fica preso lá.
- **Abaixo do 17**: o portão recusa com o texto; o grupo de bots não passa (portão só do jogador; os bots seguem o jogador).
- **Save antigo**: nada a migrar (mapa e quests novos).

## 6. Dependencies
| Depende de | Como |
|---|---|
| Brejo das Teias (`field_marsh`) | portal, NPCs `marsh_guide`/`marsh_healer`, `m0_brejo`, `amber_sap`; o GDD do Brejo §3.8 aponta para cá |
| Posto (`ranger_post`) | turnin do `v4` |
| `ItemSystem.enhance_cost` (Gunnar) | `mother_sap` = material +6..+9 da Glória |
| `MobSystem` (ovos/`hatch`/`ward`), `BossSignatures.place_rings` | sem mudança de código |
| Fable (Blender) | `places.DUNGEONS["dg_viveiro"]`, JSON, GLBs `mob_sap_sprout`/`mob_sap_tank`/`mob_sap_mother`, `.jpg` de carregamento |

## 7. Tuning Knobs
| Knob | Onde | Valor | Faixa segura | Afeta |
|---|---|---|---|---|
| HP/ATK da Muda-Mãe | `monsters_catalog.gd` | 86.000 / 98 | 75-95k / 88-108 | tempo de luta do trio 35-65 s |
| Tanques (`eggs.count`, `r`) | idem | 4, 7 m | 3-6, 6-9 | quantos lacaios no pior caso |
| HP do tanque | idem | 650 | 400-1.000 | custo de "quebrar antes" (≈ 2-4 s de grupo) |
| `ward` da fase 40% | idem | 0,5 | 0,3-0,6 | punição por ignorar os tanques |
| `berserk_after` | idem | 150 s | 120-180 | grupo fraco |
| Pesos de XP das quests | `quests_catalog.gd` | 1.400 | 1.000-2.000 | diluição da faixa (F1) |
| `mother_sap` do chefe | `lt_sap_mother` | 2-3 | 1-3 | ritmo do +6..+9 da Glória |
| Portão | `PORTAL_GATES` | 17 | 16-18 | quando abre |
Constantes de sistema novas: nenhuma (`Balance` não muda).

## 8. Acceptance Criteria
1. `_check_viveiro` passa: monstros/skills/tabelas existem; `boss_sap_mother` é chefe com `eggs` = `sap_tank` (egg) e fases
   70% hatch / 40% hatch+ward / 15% enrage; garante `mother_sap` (chance 1,0); comuns com material principal 0,3-0,7; raro
   ≤ 0,05; lacaio `sap_hatchling` 0 XP sem saque; `PORTAL_GATES["to_dg_viveiro"]` nível 17 sem quest; quests ligadas
   (giver/turnin existem, prereqs, nenhuma quest fora do Brejo/Viveiro depende delas); música `elfos`.
2. Com o JSON: `dg_viveiro` registrado (17-19, parent `field_marsh`, `bot_population` 0), spawner do chefe e dos 4 comuns,
   portal do Brejo com portão 17 e chegada andável, anel dos tanques (r 7) andável; `_check_loading_art` e `_check_music` passam.
3. `boss_probe -- --boss=boss_sap_mother --party=1,3,5 --trials=20`: trio ≥ 90% em 35-65 s; solo registrado.
4. `band_probe -- --from=15 --to=20`: comuns do Viveiro no tempo dos vizinhos, 0 `travou`.
5. Suíte completa 0 falhas; smoke sem `SCRIPT ERROR`.
