# Conjuntos Ápice (35/40/45) — monofoco no lugar dos híbridos de armas diferentes

> **Status**: spec para implementar (decisão do autor 2026-11-16: "Ápice"). Sem código ainda.
> **Substitui em parte**: `ato2-horda.md` R7.1 (híbridos) e `ato2-proposals-2026-11-11.md` §1 (16 das 24 Fusões).
> **Orçamento**: o mesmo das Fusões (F-FUS2 / F5). Equilíbrio geral não muda.

## 1. Visão geral

Nas classes em que as 3 builds usam armas diferentes, o híbrido A+B obrigava a Fusão a ter duas faces e a misturar mecânicas
de builds que nunca lutam com a mesma arma. O **Ápice** troca esse híbrido por **um conjunto por build**, que aprofunda a
mecânica da própria build (assinatura, efeito lendário, skills-chave). O conjunto da build (normal) dos tiers 35/40/45 continua
existindo; o Ápice é a alternativa com o 5 peças "de identidade" no lugar do 5 peças de stat% + recarga.

| Classe | Antes (por tier) | Depois (por tier) |
|---|---|---|
| Berserker, Ranger, Druida, Assassino | 3 híbridos | 3 Ápices (1 por build) |
| Paladino | 3 híbridos | híbrido Templário+Guardião (P3) + **Ápice Cruzado** |
| Bispo | 3 híbridos | híbrido Batalha+Sacerdote (Bi3) + **Ápice Iluminado** |
| Elementalista, Necromante | 3 híbridos | sem mudança |

Total 35/40/45: 72 da build + **42 Ápices** (14 builds × 3) + **24 híbridos** (2 + 2 + ... = 8 pares × 3) = **138** (antes 144).

## 2. Regras

**R-AP1. Ids e nomes**
- Set: `set_<classe>_apex_<build>_<nível>` (ex.: `set_berserker_apex_executor_40`).
- Peças: `leg_<classe>_apex_<build>_<nível>_<head|body|legs|gloves|boots>`; armas `..._weapon`, `..._offhand`, 2ª arma
  principal `..._<tipo>` (mesma regra do conjunto da build, ex.: Cruzado `_mace2h`).
- Nome do set: `"Conjunto <of> Ápice <I|II|III>"` (ex.: "Conjunto do Cadafalso Ápice II"). Peças: `"<substantivo da build> <of> Ápice <N>"`
  (substantivos de `PIECE_NOUNS["<classe>_<build>"]`, calça = `ARMOR_NAMES`). Numerais = `HYBRID_NUMERALS` (I = 35, II = 40, III = 45).
- Dados: `GearCatalog.APEX = {<build>: {"name", "of", "text"}}` (como `FUSIONS`); números em `Balance.APEX_NUMBERS[<build>]`.

**R-AP2. Peças e atributos**
- 5 de armadura (contam para os bônus) com armadura, `attr` e `attr2` **da build** (igual ao conjunto da build).
- Armas da build como `alt_pieces` (não contam): `main[0]`, `main[1]` se houver, `off[0]` se houver; cada uma com
  `legend_effect = legend_effect(build, tier)` (o efeito lendário próprio, sem número novo).
- `class_restriction = [classe]`. Raridade lendária, `LEGENDARY_MULT`, preço em moedas `tier + 1` = 7/8/9 (F10, sem mudança).

**R-AP3. Bônus**
- 2, 3 e 4 peças = **iguais** aos do conjunto da build no mesmo tier (`set_bonuses(build, set_skills(...))[2..4]`, incl. `set_extra`).
- 5 peças = **efeito Ápice** (fichas da seção 3): `bonuses[5] = {"fusion": {"id": "apice_<build>", ...números do tier}}`.
  Reusa a infraestrutura das Fusões (`Stats.fusion`, `FusionEffects`), sem plumbing novo na sim.
- **Face**: o efeito só liga com a arma da build na mão (`pick_face` com `pair = [build]`); outra arma = apagado (ícone cinza na janela C).
- Misturar conjuntos segue igual (cada conjunto conta as próprias peças; 2+3 com o da build não liga o 5 peças de nenhum).

**R-AP4. Onde cai / troca**: igual aos híbridos hoje — níveis `HYBRID_LEVELS` (35/40/45), `legendary_pool(cls, lv, build)`
inclui o Ápice da build (`GameData.apex_set_for(cls, build, lv)`), Relicária: o Ápice aparece **só** na aba da própria build.
Moedas, aprimoramento +1..+9 (Aço Anão/Brasa no 40+) iguais.

**R-AP5. Visual (fatia 1, até haver modelos)**: estilo, ícones e `armor_style`/`weapon_style`/`shield_style` do conjunto de nível 30
da build (`visual_of("set_<classe>_<build>_30")`, `OWN_VISUALS_UNTIL`). Cor = a do conjunto 30 **escurecida e dourada**:
`cor = vis.color.darkened(APEX_DARKEN).lerp(LEGENDARY_COLOR, APEX_GILD)` (`GearCatalog.APEX_DARKEN` 0,25, `APEX_GILD` 0,20;
constantes visuais, não de balanço). Modelos próprios no polimento.

**R-AP6. Bots**: `ItemSystem.bot_legendary_set` aos 35/40/45: Ápice da build se existir; senão o híbrido (regra atual da teia);
senão o conjunto da build. Guardião/Templário → P3, Sacerdote/Batalha → Bi3.

**R-AP7. Código que olha o set pelo id**: `SetDef.apex: String` (= build; vazio fora do Ápice) e `SetDef.is_apex()`. Quem tira a
build do id do set (`GearCatalog.bid_of_set`, `ProgressionSystem` ~l. 761, UI da Relicária/janela C) lê `sd.apex` primeiro.

## 3. Fichas (14)

Formato: **efeito** · números `[v35, passo]` → 35 / 40 / 45 (F-AP1) · G estimado (F-FUS3) · gancho · face(s) que substitui · bot.
"Maior, nunca soma" (regra 1.1.3 das Fusões) vale quando o Ápice traz número próprio para o mesmo efeito da arma lendária.

### Berserker

**B-A1. Carniceiro (Machados Gêmeos) — "da Tormenta Gêmea"**
- Golpe direto dá 1 **Frenesi da Tormenta** (máx. `FUSION_FRENZY_MAX` 5, 4 s, +`frenzy`% de velocidade de ataque por carga; pilha
  própria, soma com o Frenesi da arma). **Arremesso Brutal** gasta as cargas: +`throw`% de dano por carga gasta.
- `frenzy` [1,2, 0,15] → 1,2 / 1,35 / 1,5 %/carga · `throw` [8, 0,8] → 8 / 8,8 / 9,6 %/carga.
- G ≈ 6% aspd × 0,9 (≈0,05) + 40% × ~8% do dano (≈0,03) = **~0,08**.
- Gancho: reuso (`_frenzy` da B1/B3, `on_hit`, `skill_mult`). Substitui B1 (face única) e B3 (face única). Bot: passiva.

**B-A2. Executor — "do Cadafalso"**
- Skills de golpe de 1 alvo (TARGET) com arma de 2 mãos: +`heavy`% de dano. Limiar de execução = 30% + `exec_up` p.p.
  (vale para o bônus do Ápice **e** para o Carrasco da arma); abaixo dele, golpes +`exec_dmg`%.
- `heavy` [10, 1] → 10 / 11 / 12 % · `exec_up` [5, 1] → limiar 35 / 36 / 37 % · `exec_dmg` [20, 2] → 20 / 22 / 24 %.
- G ≈ 10% × 0,5 do dano (0,05) + janela de execução (~0,03) = **~0,08**.
- Gancho: reuso (`skill_mult`, execução da B1 em `hit_mult`, `below` do `legend_power`). Substitui B1 e B2 face machado 2 mãos.
- Bot: usa Executar/Decapitar abaixo do **limiar atual** (lê o limiar, não 30% fixo; regra da B1).

**B-A3. Punhos de Fúria — "do Punho Implacável"**
- **Crítico** com as garras também dispara o contra-ataque (como esquiva): `counter`% do ATK no alvo (ICD `FUSION_COUNTER_ICD` 1 s,
  não gera Fúria nem outro contra-ataque). +`eva`% de esquiva.
- `counter` [35, 3] → 35 / 38 / 41 % ATK · `eva` [4, 0,5] → 4 / 4,5 / 5 % (sob `EVASION_CAP`).
- G ≈ ~0,37 contra/s × 0,35 ATK ÷ ~2 ATK/s (≈0,065) + sobrevivência = **~0,07**. (Em grupo o DPS quase não apanha: por isso o crítico.)
- Gancho: reuso (`_counter` da B2/B3, `legend_on_hit` com crítico, `stats`). Substitui B2 face garras e B3. Bot: passiva.

### Paladino

**P-A1. Cruzado — "do Veredito"**
- Quando você **tenta** atordoar (rolagem do Julgamento da arma que passa, ou skill sua com `stun` que acerta — mesmo que o alvo
  resista, ex.: chefe), o alvo fica **Julgado** por `APEX_JUDGED_TIME` 4 s: todo o seu dano nele +`judged`%. Chance do Julgamento
  da arma +`stun_ch` p.p. (sem a arma, o Ápice rola o próprio Julgamento com `stun_ch`% e 0,8 s, ICD 6 s da arma).
- `judged` [8, 0,8] → 8 / 8,8 / 9,6 % · `stun_ch` [6, 1] → +6 / +7 / +8 p.p.
- G ≈ uptime 0,9 × 8% × 1,0 = **~0,07–0,08**.
- Gancho: reuso (`legend_on_hit` stun, debuff no alvo, `damage_mult` no padrão P2/D2). Substitui P1 face 2 mãos e P2 face 2 mãos.
- Bot: passiva. Debuff novo `apex_judged` → entrada em `BuffLooks.LOOKS`.

### Bispo

**Bi-A1. Iluminado — "da Aurora Ardente"**
- Cada magia sagrada (`FusionEffects.HOLY_SPELLS`; o Castigo de graça da arma conta) dá **Aurora** por `FUSION_AURORA_TIME` 4 s:
  +`aurora`% de ATK e MATK (renova, não acumula). Sem a cura por golpe de arma da Bi2 (era o lado Batalha).
- `aurora` [14, 1,4] → 14 / 15,4 / 16,8 % (número já calibrado na Bi2, §1.9: ~0,12 no 40).
- G ≈ **~0,11–0,12** (alvo = teto, o G_5n do Iluminado passa de 0,12).
- Gancho: reuso (Bi2, buff `fus_aurora`, que já tem visual). Substitui Bi1 (face única) e Bi2 (face única).
- Bot: nada novo (a Bi2 já não pedia regra além da magia).

### Druida

**D-A1. Urso — "da Casca Ancestral"** (utilidade)
- Ao ser atingido, a **Casca Viva** (Pele de Carvalho) cobre você **e** o aliado mais ferido a `FUSION_BARK_RANGE` 12 m, ICD `bark_icd`.
  **Urro da Mata** zera essa ICD.
- `bark_icd` [16, −1] → 16 / 15 / 14 s.
- G: utilidade, alvo −6–10% de mortes a `--dmg=6` contra o 5 peças normal.
- Gancho: reuso (D3 face Urso em `on_hit_taken`, `on_cast` no padrão D1). Substitui D1 face Urso e D3 face Urso.
- Bot: Urro na abertura do chefe (regra D1 atual).

**D-A2. Lobo — "da Matilha Rubra"**
- Todo o seu dano em alvo **sangrando** (a Mordida/Garras conta; sangramento de qualquer fonte) +`hunt`%.
- `hunt` [10, 1] → 10 / 11 / 12 %.
- G ≈ **~0,12** (D2 face Lobo mediu +0,132 com a parte do Fogo Lunar; sem ela, esperado ~0,12 = teto).
- Gancho: reuso (`damage_mult` D2, `_has_bleed`). Substitui D1 face Lobo e D2 face Lobo. Bot: passiva.

**D-A3. Xamã — "da Maré Lunar"**
- Suas magias em alvo com **Fogo Lunar** (marca `FUSION_MOON_TIME` 4 s) +`moon`%. Fogo Lunar que acerta alvo **já marcado** lança
  um Fogo Lunar de graça a `jump`% no inimigo marcado-ou-não mais perto a `APEX_MOON_JUMP_RANGE` 6 m (o de graça não salta).
- `moon` [10, 1] → 10 / 11 / 12 % · `jump` [50, 5] → 50 / 55 / 60 %.
- G ≈ 10% × 0,85 uptime (0,085) + salto em bando (~0,02 contra chefe com lacaios) = **~0,09–0,10**.
- Gancho: reuso (`_moonlit`, `hit_mult`, `_free_cast`). Substitui D2 face cajado e D3 face cajado.
- Bot: Fogo Lunar no alvo marcado sobe na prioridade (`bot_skill_mult`, `BOT_FUSION_SCORE`).

### Ranger

**R-A1. Caçador — "do Faro do Lince"**
- Golpes do **companheiro** (lince; falcão não) aplicam a **Marca do Caçador** com o maior entre `mark`% e a da arma lendária equipada
  (teto `MARK_TAKEN_CAP` 25% com Presa e Marca do Predador); o companheiro causa +`pet`% em alvo retardado.
- `mark` [5, 0,5] → 5 / 5,5 / 6 % · `pet` [15, 1,5] → 15 / 16,5 / 18 %.
- G ≈ 5% de dano de todo o grupo (0,05) + 15% × ~25% do dano do caçador (≈0,03) = **~0,08**.
- Gancho: reuso de `summon_on_hit` (gancho novo das Fusões, continua por causa da N3). Substitui R1 face arco e R3 face arco.
- Bot: abre com Flecha Gélida no chefe (retarda) antes de soltar o lince.

**R-A2. Atirador — "do Posto Avançado"** (ideia do autor: "um conjunto que permite uma segunda torreta")
- +1 torreta ativa (a 2ª com `t2_pwr`% do poder); torretas atiram primeiro em alvo preso, retardado ou marcado. **+1 armadilha** no
  limite (`TRAP_MAX` 3 → 4), vale sem a ascensão.
- `t2_pwr` [60, 5] → 60 / 65 / 70 % · armadilha +1 (fixo).
- G ≈ 2ª torreta 60% × ~11% do dano (≈0,07) + armadilha (~0,01) = **~0,08**.
- Gancho: reuso (`turret_max` da R1). **Stat novo** `trap_max` em `Stats.STAT_KEYS` (não é gancho: soma onde o talento `trap_max`
  já é lido). Substitui R1 face rifle e R2 face rifle. Bot: 2ª torreta quando a 1ª já está no chefe (regra R1).

**R-A3. Lanceiro — "da Presa Aberta"**
- Golpes abrem 1 **Ferida Aberta** (2 em alvo retardado ou preso); números do Ápice ou da arma lendária, o maior.
- `pct` [2,0, 0,4] → 2,0 / 2,4 / 2,8 %/Ferida · `max` 5 · `bleed` [6, 1] → 6 / 7 / 8 % ATK/s.
- G ≈ **~0,07** (Dardo, Varrida e Marca do Predador já deixam lento).
- Gancho: reuso (R3 face lança, `open_wound`). Substitui R2 face lança e R3 face lança. Bot: abre com Dardo de Caça (regra R3).

### Assassino

**A-A1. Lâminas — "da Sombra Peçonhenta"**
- Sair de skill de avanço (Passo das Sombras, dash) **ou esquivar** deixa a próxima facada **furtiva** por `FUSION_GHOST_TIME` 3 s
  (`ambush_mult` da pessoa, teto `FUSION_AMBUSH_MAX` 2,0; crítico de costas). A facada furtiva aplica **Veneno Letal** (`poison`% do
  ATK/s, 4 s; o da arma se for maior). ICD `ghost_icd`.
- `ghost_icd` [5, −0,25] → 5 / 4,75 / 4,5 s · `poison` [8, 0,8] → 8 / 8,8 / 9,6 %.
- G ≈ 0,07 (A1) + veneno ~0,01 = **~0,08**.
- Gancho: reuso (A1 `ghost`, tipo `poison`). Substitui A1 (face única) e A3 face adagas. Bot: avanço para as costas (regra A1).

**A-A2. Duelista — "da Cadência Perfeita"**
- Crítico com espada dá 1 **Cadência** (ICD 1 s, máx. 5, 12 s; pilha própria, **não** é Bravata); esquivar dá 2. Com 5: **Foco do
  Duelista** (`ass_focus`) a `focus`% da força por `FUSION_FOCUS_TIME` 6 s, e gasta as cargas.
- `focus` [60, 5] → 60 / 65 / 70 %.
- G ≈ **~0,07** (A2 face duas espadas).
- Gancho: reuso (A2, `buff`). Buff novo `apex_cadence` → `BuffLooks.LOOKS`. Substitui A1 e A2 face duas espadas. Bot: passiva.

**A-A3. Corsário — "da Salva Final"**
- Crítico com espada dá 1 **Bravata** (ICD `FUSION_BRAVADO_ICD` 1 s). Bravata cheia → o próximo golpe de espada **dispara a pistola de
  graça** a `shot`% do ATK (`spare_shot`) e gasta as Bravatas.
- `shot` [45, 4] → 45 / 49 / 53 %.
- G ≈ **~0,07** (A2 face pistola).
- Gancho: reuso (`gain_bravado`, `spare_shot`). Substitui A2 face pistola e A3 face pistola.
- Bot: com Bravata 4+, segura o Tiro Entre os Olhos (gasta tudo) até a salva sair — **regra nova pequena no `BotBrain`**.

**Ganchos novos na sim: 0.** Stat novo: `trap_max`. Debuff/buff novos: `apex_judged`, `apex_cadence`, `apex_tempest` (Frenesi da Tormenta).

## 4. Fórmulas

### F-AP1. Número do Ápice por tier
`valor(i) = v35 + passo × (i − 6)` (idêntica à F-FUS1).

| Símbolo | Tipo | Faixa | Descrição |
|---|---|---|---|
| i | int | 6–8 | índice do tier (`Balance.legend_tier`: 35 = 6, 40 = 7, 45 = 8) |
| v35 | float | por ficha | valor no 35 (`APEX_NUMBERS[build][chave][0]`) |
| passo | float | \|passo\| ≤ 10% de v35 | crescimento por tier (negativo em ICD) |
| valor | float | v35 … v35 + 2·passo | número usado pela sim |

**Saída**: limitada pelos 3 tiers; mínimo 80% de v35 (ICD com passo −10%), nunca ≤ 0. **Exemplo**: Cadafalso `exec_up` [5, 1] no 45 →
5 + 1 × 2 = **7** → limiar 37%.

### F-AP2. Orçamento (igual ao da Fusão substituída)
`G_ap = T4 ÷ T_ap − 1` · `G_5n = T4 ÷ T_5n − 1` · **critério**: `|G_ap − min(G_5n, APEX_GAIN_MAX)| ≤ APEX_TOL` e `G_ap ≤ APEX_GAIN_MAX`.

| Símbolo | Tipo | Faixa | Descrição |
|---|---|---|---|
| T4 | float (s) | 60–180 | grupo de 4, a build com 4 peças do Ápice (= 4 peças do conjunto da build) |
| T_ap | float (s) | < T4 | mesmo grupo, 5 peças do Ápice |
| T_5n | float (s) | < T4 | mesmo grupo, 5 peças do conjunto da build (stat% + recarga) |
| G_5n | float | 0,06–0,22 (medidos: 0,08–0,22) | ganho do 5 peças normal da build |
| G_ap | float | alvo `min(G_5n, 0,12)` ± 0,02 | ganho do Ápice |
| APEX_TOL / APEX_GAIN_MAX | float | 0,02 / 0,12 | = `FUSION_TOL` / `FUSION_GAIN_MAX` (aliás; mesmo número) |

**Saída**: G_ap ∈ [0; 0,12]; acima de 0,12 o Ápice vira obrigatório sobre o conjunto da build (as duas opções devem coexistir).
Utilidade (Urso): ganho = queda relativa de mortes a `--dmg=6`, alvo 6–10% contra `b5`.
**Exemplo**: Executor, Ghar 40: T4 = 100 s, T_5n = 92,6 s (G_5n 0,080), T_ap = 92,0 s (G_ap 0,087) → |0,007| ≤ 0,02, **dentro**.

**Como medir** (método F5 + §1.9): `boss_probe.tscn -- --comp=<grupo de 4 com a build> --tank_lock --set=a4|a5|b5 --set_who=<i>
--set_lv=40 --boss=ghar --hp=2 --trials=80+` (flags novas: `a4`/`a5` = Ápice da build do bot; `b5` = conjunto da build, já existe
como `b5`). 80+ lutas por braço (ruído ±0,05 com 30). Passo 0: medir `G_5n` das 14 builds no 40 antes de afinar. Conferência
cruzada: `G_ap` fica a ±0,02 do `G_fus` medido da(s) face(s) substituída(s) quando houver medida. `combat_probe` 0 FLAG.
Contador por efeito no probe: bot com o Ápice o dispara ≥ 1× por 60 s de luta.

## 5. O que acontece com as 16 Fusões removidas

Saem: **P1, P2, B1, B2, B3, Bi1, Bi2, D1, D2, D3, R1, R2, R3, A1, A2, A3**. Ficam: **P3, Bi3, E1–E3, N1–N3** (8).

**Recomendação: apagar, não deixar dormente.**
- Remover as 16 entradas de `GearCatalog.FUSIONS` e `Balance.FUSION_NUMBERS`, e os `match` delas em `FusionEffects`.
- O código que um Ápice reaproveita **muda de chave** (`"carniceiro+executor"` → `"apice_executor"` etc.), não fica duplicado.
- Ganchos novos sem consumidor saem: `on_overheal` (só Bi1) e `post_regen` (só R2) — tirar de `NEW_HOOKS` e as chamadas em
  `world_sim.gd` (sobrecura ~l. 1763) / `FusionEffects.tick`. `summon_on_hit` fica (N3 + Ápice Caçador).
- Constantes `FUSION_*` sem leitor saem (ex.: `FUSION_OVH_RANGE`, `FUSION_POST_*`, `FUSION_WEIGHT_*`, `FUSION_OATH_TAUNT_STACKS`,
  `FUSION_WOLF_COUNT`, `FUSION_PACK_RANGE`, `FUSION_TAUNT_*`, `FUSION_ENT_RADIUS`, `FUSION_WOUND_ICD`); o check de "chave lida existe"
  pega as órfãs.
- Por quê: dormente não cai, não é medido e apodrece; o git guarda as fichas e o `ato2-proposals` §1 vira histórico (nota no topo:
  "16 de 24 substituídas pelo Ápice, 2026-11-16").

## 6. Migração de save (`SaveSystem.VERSION` 5 → 6)

Regra aplicada em `migrate_item_id` (inventário, depósito, equipado; mantém `+N`). Idempotente: os ids velhos não existem mais.

| Peça velha (`leg_<c>_mix_<A>_<B>_<lv>_…`) | Vira |
|---|---|
| Armadura (`_head/_body/_legs/_gloves/_boots`) | Ápice de **A** (armadura e atributo principal do híbrido já eram de A). Se A não tem Ápice → Ápice de B |
| Arma/mão secundária `_<bid>_weapon` / `_<bid>_offhand` | Se `bid` tem Ápice: `leg_<c>_apex_<bid>_<lv>_weapon/_offhand`. Senão: a mesma arma no híbrido que ficou (`leg_<c>_mix_<P3/Bi3>_<lv>_<bid>_weapon/_offhand`) |

Nas 4 classes monofoco cada build é A de exatamente um par → a armadura vai 1:1. Casos concretos das parciais:
Paladino `guardiao_cruzado` armadura → Ápice Cruzado; arma Guardião → `mix_templario_guardiao_<lv>_guardiao_*`; `cruzado_templario`
armadura → Ápice Cruzado; arma Templário → `mix_templario_guardiao_<lv>_templario_weapon`. Bispo `sacerdote_inquisidor` armadura →
Ápice Iluminado (A sem Ápice); arma Sacerdote → `mix_batalha_sacerdote_<lv>_sacerdote_*`; `inquisidor_batalha` armadura → Ápice
Iluminado; arma Batalha → `mix_batalha_sacerdote_<lv>_batalha_*`.

Casos-limite:
- **Duas peças velhas viram a mesma** (ex.: arma do Carniceiro em `carniceiro_executor` e em `punhos_carniceiro`): soma no inventário.
- **Equipado**: troca no mesmo slot; `_fix_class_weapons` continua valendo.
- **Aprimorada** `…+N`: vira `<novo id>+N` (`resolve_item` cria a versão); nada se perde.
- **Moedas**: não há reembolso (a peça equivalente já é a troca justa; mesmo nível e preço).
- **Atributo muda** (o 2º atributo do híbrido vinha de B; o do Ápice é o `attr2` da build; armadura do Guardião/Sacerdote vira a do
  Cruzado/Iluminado): aceito; o jogador ganha a peça do mesmo nível.
- Elementalista, Necromante, P3 e Bi3: ids iguais, nada muda. Bots não são salvos (gear refeito no spawn).

## 7. Checks (`tools/tests/run_tests.gd`)

1. `_check_apex_sets`: 42 sets (14 builds × 35/40/45); ids e nomes da R-AP1 ("Ápice I/II/III", únicos); 5 de armadura com armadura/
   `attr`/`attr2` da build; armas da build em `alt_pieces` com `legend_effect(build, tier)`; `class_restriction`; bônus 2–4 == os do
   conjunto da build no tier; 5 = `apice_<build>` com números F-AP1.
2. `_check_hybrid_sets` (atualizar): restam 24 híbridos (P3, Bi3, 3 Ele, 3 Necro × 3); nenhum `_mix_` de berserker/ranger/druid/assassin.
3. Chaves: `FUSIONS`/`FUSION_NUMBERS` = os 8 que ficam; `APEX`/`APEX_NUMBERS` = as 14 builds; toda chave lida por `FusionEffects` existe;
   `NEW_HOOKS` ≤ 6 e cada um com consumidor; `trap_max` em `Stats.STAT_KEYS` e lido.
4. Face: Ápice do Executor com garras = apagado; com machado 2 mãos (e Titã) = ligado.
5. Um check de regra por ficha (sim determinística, `--only=apex`): Frenesi da Tormenta máx 5 e Arremesso gasta; limiar 35/36/37;
   contra-ataque por crítico com ICD; Julgado na rolagem mesmo com chefe imune; Aurora renova sem acumular; Casca cobre aliado e o
   Urro zera a ICD; +`hunt` só em alvo sangrando; salto do Fogo Lunar não encadeia; lince aplica marca sob `MARK_TAKEN_CAP`;
   `turret_max` +1 e armadilha 4; 2 Feridas em alvo lento; facada furtiva envenena; Cadência ≠ Bravata; salva gasta a Bravata.
6. Visual: cor = fórmula R-AP5; estilo/ícone do conjunto 30 existem; `BuffLooks.LOOKS` tem `apex_judged`, `apex_cadence`, `apex_tempest`.
7. Drop/Relicária/bot: `legendary_pool` da build tem o Ápice e não tem híbrido removido; Relicária mostra o Ápice só na aba da build;
   `bot_legendary_set` = Ápice (monofoco, Cruzado, Iluminado), P3 (Guardião/Templário), Bi3 (Sacerdote/Batalha).
8. Save: fixture v5 com peças híbridas (armadura, arma, mão secundária, `+3`, equipada, depósito, duas que colidem) → ids da tabela 6;
   v6 ida e volta idêntica; Ele/Necro/P3/Bi3 intactos.
9. `catalog_dump` antes/depois: conjuntos da build e híbridos que ficam saem iguais (diff só nos removidos/novos).
10. Probes (não são check): `boss_probe` F-AP2 por Ápice, `combat_probe` 0 FLAG, `--smoke` sem `SCRIPT ERROR`.

Docs a atualizar junto: `ato2-horda.md` R7/R7.1/F10 (contagem 138, Ápice), nota no `ato2-proposals` §1, `docs/DESIGN.md`,
`.claude/docs/ragnaex/conteudo.md` (linha **Build**: "uma build nova ganha conjuntos lendários e um Ápice sozinha").

## 8. Botões (`Balance`)

| Botão | Faixa segura | Afeta |
|---|---|---|
| `APEX_NUMBERS[build][chave] = [v35, passo]` | v35 ±30% do proposto; \|passo\| ≤ 10% de v35 | força de cada Ápice (F-AP1) |
| `APEX_TOL` / `APEX_GAIN_MAX` | 0,01–0,03 / 0,10–0,12 | orçamento (F-AP2); hoje iguais aos `FUSION_*` |
| `APEX_JUDGED_TIME` | 3–5 s | uptime do Julgado (Cruzado) |
| `APEX_MOON_JUMP_RANGE` | 5–8 m | salto do Fogo Lunar (Xamã) |
| `APEX_CADENCE_MAX` / `APEX_CADENCE_TIME` | 4–6 / 8–12 s | ritmo do Foco (Duelista) |

## 9. Perguntas abertas (para o autor)

1. **4 peças do Ápice**: igual ao conjunto da build (recomendado, zero calibragem nova) ou +dano na skill-assinatura da build
   (mais identidade, mas o Urso tem Fogo Lunar como assinatura)?
2. **Armadura do Guardião+Cruzado e do Sacerdote+Iluminado** no save: virar Ápice Cruzado/Iluminado (recomendado, regra única) ou a
   armadura do híbrido que ficou (P3/Bi3, mais perto da build do Guardião/Sacerdote)?
3. **Fusões removidas**: apagar (recomendado) ou deixar dormentes no código?
4. **Ideia "regenerar perto da torreta"** (R2, do autor) sai junto com a R2. Levar para o Ápice do Atirador (troca a armadilha +1;
   utilidade em vez de dano) ou deixar para outro conteúdo?
5. **Bots aos 35+**: Ápice sempre (recomendado: exercita o conteúdo novo, mesmo orçamento) ou o conjunto da build normal?
