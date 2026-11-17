# Acessórios lendários por build (35/40/45) — spec

> **Status**: spec, sem código (decisões do autor 2026-11-16). Autor: systems-designer.
> Base: trabalho de mana em andamento (`ItemDef.bonus`, `Stats.mp_on_kill` / `mp_regen_combat`,
> `production/session-state/agent-mana-acc.md`) e Ápice (`design/gdd/apice-sets.md`, outro agente editando `gear_catalog.gd`).

## 1. Regras

**Decisões do autor (fixas):** uma peça de acessório lendário por build e por slot (capa, amuleto e 2 anéis); só nos níveis 35/40/45
(= `Balance.HYBRID_LEVELS`, junto do Ápice e dos híbridos); **não é conjunto** (cada peça tem o próprio bônus, `set_id = ""`,
não conta nas peças de armadura); mesmas fontes dos lendários de hoje; bots usam as peças da própria build.

### R-LA1. Peças e slots
Slots que já existem (`ItemDef.Slot`): `CAPE`, `AMULET`, `RING` e `RING2` (o 2º anel usa o mesmo `item.slot = RING`;
`ItemSystem.equip` preenche o vazio). Por build e nível saem **4 itens**:

| peça (`piece`) | slot | nome pt-BR | peso (`PIECE_WEIGHT`) | papel do bônus |
|---|---|---|---|---|
| `cape` | CAPE | Manto | 0,30 (cape) | defesa / sustento |
| `amulet` | AMULET | Medalhão | 0,35 (amulet) | identidade da build |
| `ring` | RING (ou RING2) | Anel | 0,30 (ring) | ataque |
| `signet` | RING (ou RING2) | Sinete | 0,30 (ring) | utilidade |

Anel e Sinete são itens diferentes: os dois vão juntos nos 2 slots de anel.
**Peça repetida não soma:** a mesma id (ou a versão `+N` dela, pelo `base_id`) nos dois slots de anel dá o bônus uma vez só
(`Stats.compute` deduplica `ItemDef.bonus` por `base_id`/id). Os atributos continuam somando (como o anel comum de hoje).

### R-LA2. Ids, nomes, textos
- Id: `leg_acc_<classe>_<build>_<nível>_<peça>` (ex.: `leg_acc_paladin_guardiao_45_signet`). A peça fica **por último** e sem `_`
  (o catálogo extrai a peça pelo último pedaço do id: `ring_a` quebraria isso).
- O prefixo `leg_acc_` não colide com `leg_<classe>_` dos conjuntos; conferir laços que filtram por `begins_with("leg_")` (seção 6).
- Nome: `"<Manto|Medalhão|Anel|Sinete> <of> <epíteto>"`, `of` da build (`classes_catalog`) e `TIER_EPITHETS[legend_tier(nível)]`
  (35 = "da Ascensão", 40 = "do Triunfo", 45 = "do Apogeu"). Ex.: "Sinete do Guardião do Apogeu", "Manto das Lâminas do Triunfo".
- Descrição: `"Acessório lendário (<Classe>, <Build>): não conta nas peças do conjunto."` + linha do bônus por `UiKit.item_bonus_text`
  (já existe no trabalho de mana; os stats novos ganham rótulo pt-BR lá).

### R-LA3. Status base (mesma fórmula das peças de hoje, `GearCatalog.armor_item`)
`armor_item(id, nome, peça, "leather", build.attr, build.attr2, nível, RARITY_LEGENDARY, Balance.LEGENDARY_MULT, cor)`; o Sinete usa
o peso do anel. Anel/Sinete/Medalhão zeram DEF/MDEF (como as joias comuns); a capa fica com `armor_style = "cape"`.
Atributos **da build** (attr/attr2), não do tema: é isso que o bot já usa para escolher (`it.attr(build.attr) > 0`).

Comparação (atributo principal na escala antiga, x10 no jogo; DEF da capa):

| peça | comum t4 (32) | comum t5 (40) | Kharzun k45 (x1,1) | **lend. 35** | **lend. 40** | **lend. 45** |
|---|---|---|---|---|---|---|
| Anel / Sinete (0,30) | 6,0 | 7,4 | 9,2 | 7,8 | 8,9 | 10,0 |
| Medalhão (0,35) | 6,9 | 8,7 | 10,7 | 9,1 | 10,4 | 11,7 |
| Manto (0,30), atributo | 6,0 | 7,4 | 9,2 | 7,8 | 8,9 | 10,0 |
| Manto, DEF (couro 20) | 9 | 9 | 12 | 10 | 12 | 13 |

(principal = `0,62 × nível × peso × mult`; secundário `0,3 × ...`; DEF = `20 × level_factor × mult × peso`, arredondado.)
O ganho de atributo sozinho é pequeno (+~9% sobre o k45 nas 4 peças); o poder vem do bônus da seção 2.

### R-LA4. Mana herdada (não regredir o trabalho de mana)
Build de atributo principal FOR ou AGI (temas `guerreiro`/`cacador` em `Balance.MANA_ACC_THEMES`): o Medalhão leva também
`mp_on_kill` e o Manto `mp_regen_combat`, no valor do Kharzun (`MANA_KILL_PCT_K45` 12 / `MANA_COMBAT_REGEN_K45` 1,0) nos três níveis.
Sem isso o lendário seria pior que a joia comum para Berserker/Paladino/Ranger/Assassino (ver Q2). Builds INT/WILL/VIT de atributo
principal: sem mana herdada (como hoje). O bônus da build **soma** à mana herdada no mesmo `ItemDef.bonus`.

### R-LA5. Fontes, preço, restrição
- **Drop**: entram no `GameData.legendary_pool(cls, nível, build)` nos níveis 35/40/45 (mesma chance, mesma Moeda Lendária,
  `ItemSystem.pick_legendary` sem mudança). Peso no sorteio: o mesmo de qualquer peça do pool (ver Q3 se diluir demais).
- **Relicária**: `relic_offer` já percorre `legendary_pool` → aparece sozinha, na aba da build (igual ao Ápice). Preço =
  `relic_cost` de hoje: `legend_tier + 1` = **7 / 8 / 9 moedas** (35/40/45). `relic_exchange_set` **não** inclui acessórios
  (troca só `SetDef.armor`). Moeda por ouro: `LEGEND_COIN_PRICE` sem mudança.
- **Baú**: o baú lendário de chefe que hoje sai do pool sai do mesmo pool (nada a fazer).
- **Restrição**: `class_restriction = [classe]` (como os conjuntos; o jogador pode misturar builds da classe). Sem trava de build.
- **Aprimoramento**: segue a regra do lendário do nível (`PLUS_KHARZUN_*` a partir do 40, só o Thrain). O `+N` sobe atributos/DEF
  como hoje; o `bonus` **não** escala com `+N` (fica igual ao da base).

### R-LA6. Ícones e visual
- Pintados pelo laço de `tools/icons/item_icons.gd`: `art_key` devolve `cape` / `amulet` / `ring` pelo slot (sem forma nova).
  Sinete = forma própria `ring_signet` (`art_key`: id terminando em `_signet` → `_a_ring_signet` em `item_icons.gd`; há check de forma).
- `icon_color` = `cls.color.lerp(LEGENDARY_COLOR, 0,35)` (igual às peças de conjunto da build); moldura `slot_r<lendário>`.
  Acabamento/gema/brilho já saem da raridade. Rodar `item_icons.tscn -- --only=leg_acc_` + `--import`.
- Capa no boneco: `armor_style = "cape"` (peça `arm_cape_cape_cape` do kit, tinta = `icon_color`). Nada de Blender.

### R-LA7. Bots
- `ItemSystem.bot_legendary_accessories(e, nível) -> Array` (novo, ao lado de `bot_legendary_set`): os 4 ids da **build do bot**
  no maior nível de `HYBRID_LEVELS` ≤ nível; vazio abaixo do 35. Anel em `RING`, Sinete em `RING2`.
- Quem já veste lendário em bot (hoje só o `boss_probe --set`) passa a usar isso também. Bots do mundo continuam com joias
  comuns no `_gear_bot` (hoje não vestem lendário nenhum); mudar isso é a Q1.
- `_gear_scan` não muda: o filtro de raridade já deixa o lendário de fora.

## 2. Fichas por build (24)

Molde: **Manto** = defesa/sustento, **Medalhão** = identidade, **Anel** = ataque, **Sinete** = utilidade. Um stat por peça
(mais a mana herdada de R-LA4). Os números saem de uma tabela por stat (abaixo), não da build: dados em
`Balance.LEG_ACC_STEP` (stat → `[35, 40, 45]`) e `Balance.LEG_ACC_BUILDS` (build → `{cape, amulet, ring, signet}` = stat);
ajuste fino por build em `Balance.LEG_ACC_BUILD_MULT` (sem entrada = 1,0). **Novo** = stat da seção 3.

### 2.1 Tabela de valores por peça (`LEG_ACC_STEP`)

| stat | 35 | 40 | 45 | teto já existente |
|---|---|---|---|---|
| `atk_pct` / `matk_pct` | 1,5 | 2 | 2,5 | — |
| `aspd_pct` | 2,5 | 3 | 4 | `ATTACK_SPEED_CAP` 60 |
| `crit` (p.p.) | 1,5 | 2 | 2,5 | — |
| `crit_dmg_pct` **novo** | 5 | 6,5 | 8 | novo `CRIT_DMG_CAP` 40 |
| `lifesteal` | 1 | 1,5 | 2 | `LIFESTEAL_CAP` 20 |
| `hp_pct` / `def_pct` | 3 | 4 | 5 | — |
| `dr_pct` | 2 | 2,5 | 3 | `DR_CAP` 40 |
| `block` (só com escudo) | 2 | 3 | 4 | — |
| `evasion` | 1,5 | 2 | 2,5 | `EVASION_CAP` 45 |
| `threat_pct` | 10 | 15 | 20 | — |
| `heal_pct` | 3 | 4 | 5 | — |
| `buff_pct` | 6 | 8 | 10 | `BUFF_DURATION_CAP` 80 |
| `radiance` | 2 | 3 | 4 | `RADIANCE_CAP` 40 |
| `pet_pct` (companheiro e invocações) | 5 | 6,5 | 8 | — |
| `fire_pct` / `frost_pct` / `storm_pct` | 2,5 | 3 | 4 | `ELEMENT_CAP` 60 |
| `backstab` | 4 | 5 | 6 | — |
| `cdr` | 1,5 | 2 | 2,5 | `CDR_CAP` 25 |
| `speed_pct` | 3 | 4 | 5 | — |
| `dot_pct` **novo** | 6 | 8 | 10 | novo `DOT_PCT_CAP` 60 |
| `cc_resist_pct` **novo** | 10 | 15 | 20 | novo `CC_RESIST_CAP` 50 |
| `mp_cost_pct` **novo** | 4 | 5 | 6 | novo `MP_COST_CAP` 30 |
| `summon_time_pct` **novo** | 10 | 15 | 20 | novo `SUMMON_TIME_CAP` 60 |

### 2.2 Fichas

| classe | build (papel) | Manto | Medalhão | Anel | Sinete | por quê |
|---|---|---|---|---|---|---|
| Paladino | Guardião (tanque) | `dr_pct` | `threat_pct` | `block` | `cc_resist_pct` | segura o chefe, não é travado |
| Paladino | Cruzado (2 mãos) | `cc_resist_pct` | `atk_pct` | `crit_dmg_pct` | `mp_cost_pct` | golpe pesado; fica sem mana (mana_probe) |
| Paladino | Templário | `block` | `atk_pct` | `crit` | `crit_dmg_pct` | segue o `set_extra` de crítico |
| Berserker | Machados Gêmeos | `lifesteal` | `aspd_pct` | `crit` | `mp_cost_pct` | ritmo + o problema de mana do Carniceiro |
| Berserker | Executor | `hp_pct` | `atk_pct` | `crit_dmg_pct` | `cc_resist_pct` | tanque de apoio que bate forte |
| Berserker | Punhos de Fúria | `evasion` | `aspd_pct` | `crit` | `lifesteal` | esquiva e contra-ataque |
| Bispo | Sacerdote (cura) | `mp_cost_pct` | `heal_pct` | `buff_pct` | `radiance` | cura, bênçãos longas |
| Bispo | Iluminado | `mp_cost_pct` | `matk_pct` | `radiance` | `crit_dmg_pct` | luz que cura batendo |
| Bispo | Clérigo de Batalha | `block` | `atk_pct` | `heal_pct` | `buff_pct` | golpe que cura (mend) |
| Druida | Urso (tanque) | `dr_pct` | `threat_pct` | `hp_pct` | `cc_resist_pct` | espelho do Guardião sem escudo |
| Druida | Lobo | `lifesteal` | `atk_pct` | `aspd_pct` | `dot_pct` | sangramento da arma (Fera) |
| Druida | Xamã | `mp_cost_pct` | `pet_pct` | `summon_time_pct` | `buff_pct` | invocações e bênçãos |
| Ranger | Caçador | `evasion` | `pet_pct` | `atk_pct` | `crit` | lince mais forte |
| Ranger | Atirador | `speed_pct` | `atk_pct` | `crit_dmg_pct` | `cdr` | tiro pesado, armadilha/torreta mais vezes |
| Ranger | Lanceiro | `hp_pct` | `atk_pct` | `dot_pct` | `evasion` | Ferida Aberta sangra; notável de esquiva |
| Assassino | Lâminas | `evasion` | `backstab` | `dot_pct` | `crit_dmg_pct` | veneno da lâmina, pelas costas |
| Assassino | Duelista | `def_pct` | `atk_pct` | `crit` | `crit_dmg_pct` | duelo de crítico |
| Assassino | Corsário | `def_pct` | `crit` | `crit_dmg_pct` | `cdr` | casaca grossa; pistola de graça |
| Elementalista | Fogo | `mp_cost_pct` | `fire_pct` | `dot_pct` | `crit_dmg_pct` | queimadura |
| Elementalista | Gelo | `hp_pct` | `frost_pct` | `matk_pct` | `mp_cost_pct` | mago de VIT, estilhaço |
| Elementalista | Raio | `mp_cost_pct` | `storm_pct` | `crit` | `crit_dmg_pct` | rajada |
| Necromante | Invocador | `mp_cost_pct` | `pet_pct` | `summon_time_pct` | `matk_pct` | exército que dura |
| Necromante | Ceifador (corpo a corpo) | `lifesteal` | `matk_pct` | `crit_dmg_pct` | `cc_resist_pct` | foice na linha de frente |
| Necromante | Sombras (maldições) | `mp_cost_pct` | `dot_pct` | `matk_pct` | `cdr` | maldição e dano no tempo |

Mana herdada (R-LA4) entra no Manto/Medalhão das 13 builds de principal FOR/AGI: Cruzado, Templário, Gêmeos, Executor, Punhos,
Clérigo de Batalha, Lobo, Caçador, Atirador, Lanceiro, Lâminas, Duelista, Corsário. Guardião e Urso (VIT), Sacerdote (WILL) e
os casters (INT) não.

Notas:
- Stat que a build já tem no conjunto/teia (ex.: `aspd_pct` do Carniceiro) soma normalmente; os tetos acima seguram.
- Elementalista: o elemento do Medalhão é o da build; quem joga combinação usa o Medalhão da outra build da classe (mesma classe = pode).
- `block` sem escudo não vale (regra de `Stats`): só nas builds de escudo (Guardião, Templário, Clérigo de Batalha).

## 3. Stats novos (5; entram em `Stats.STAT_KEYS` e em `Stats.compute`)

Os outros 19 stats das fichas já existem. Os 5 novos somam no laço `buffs + set_bonus` de `Stats.compute` (o `ItemDef.bonus`
já entra em `set_bonus`), com teto em `Balance` aplicado no fim, como `cdr`/`evasion`.

| stat | builds que usam | onde é lido | gancho (uma linha) |
|---|---|---|---|
| `crit_dmg_pct` | 11 (Cruzado, Templário, Executor, Iluminado, Atirador, Lâminas, Duelista, Corsário, Fogo, Raio, Ceifador) | onde o dano crítico usa `Balance.CRIT_MULT` (pipeline de dano do `WorldSim`/`Combat`) | multiplicador do crítico = `CRIT_MULT + crit_dmg_pct/100` (1,5 → até 1,9) |
| `dot_pct` | 5 (Lobo, Lanceiro, Lâminas, Fogo, Sombras) | ao aplicar dano no tempo: efeito `dot`, queimadura, `hit_poison`, sangramento/veneno/Ferida das armas lendárias (`LegendEffects`) | dps do dano no tempo × `(1 + dot_pct/100)`, fixado na aplicação (não relê por tique) |
| `cc_resist_pct` | 5 (Guardião, Cruzado, Executor, Urso, Ceifador) | `SimEntity.put_debuff` para `stun`/`root`/`slow` (não `taunt`, não zona de chefe) | duração × `(1 − cc_resist_pct/100)` |
| `mp_cost_pct` | 10 (Cruzado, Gêmeos, Sacerdote, Iluminado, Xamã, Fogo, Gelo, Raio, Invocador, Sombras) | custo de mana da skill no lançamento (junto do `MASTERY_MP_PER_LV`) | custo × `(1 − mp_cost_pct/100)`, arredonda para cima, mínimo 1 |
| `summon_time_pct` | 2 (Xamã, Invocador) | `WorldSim` ao criar invocação com duração (`summon_expires`) | duração × `(1 + summon_time_pct/100)`; permanente (companheiro, `duration 0`) não muda |

Fora (de propósito): `trap_pct` (só o Atirador usaria; ele leva `cdr`), `shield_pct` (2 builds; `buff_pct` já alonga escudos),
`fury_gain_pct` (o Berserker não tem recurso próprio na sim), `threat_pct` e `pet_pct` (já existem; `pet_pct` já vale para
invocações do Necromante/Xamã, `WorldSim` ~l. 262).

Tetos novos em `Balance`: `CRIT_DMG_CAP` 40, `DOT_PCT_CAP` 60, `CC_RESIST_CAP` 50, `MP_COST_CAP` 30, `SUMMON_TIME_CAP` 60.
Custo de tique: zero laço novo; os 5 são lidos onde o número já é calculado. A soma do `sim_probe` muda só com os itens vestidos.

## 4. Orçamento de poder e como medir

**Alvo:** as 4 peças lendárias juntas, no lugar das joias que substituem, dão **+4 a +6% de poder da build no 45**
(+3 a +5% no 35/40). Ganho modesto: o lendário de acessório é melhoria, não obrigação; o conjunto/Ápice continua sendo o salto.
Referência substituída: 35 → comuns t4 (nível 32); 40 → comuns t5 (40); 45 → Kharzun k45 (melhor joia que existe).

### F-LA1. Ganho medido

`G_acc = T_ref / T_leg − 1`

| símbolo | tipo | faixa | descrição |
|---|---|---|---|
| `T_ref` | float (s) | 60–240 | tempo médio de TODAS as lutas (derrota conta até o limite) do grupo com o bot medido usando as joias de referência |
| `T_leg` | float (s) | 60–240 | mesmo grupo, mesmas sementes, o bot com as 4 peças lendárias da build |
| `G_acc` | float | alvo 0,04–0,06 (45); 0,03–0,05 (35/40) | ganho do bot medido; tanques/cura: ver abaixo |

**Saída**: sem teto matemático (razão de tempos); `G_acc < 0` = peça pior que a joia (falha: geralmente mana perdida, ver R-LA4);
`G_acc > 0,08` = obrigatório demais → baixar `LEG_ACC_BUILD_MULT` da build. Tanque/cura (Guardião, Urso, Sacerdote): medir
por `baixa_tq` / `mortes` / `cura_tq` do `boss_probe --comp ... --dmg=6` (alvo: −15 a −25% em mortes, tempo ≤ +2%), não por tempo.

### F-LA2. Estimativa antes de medir (para escolher números)

`G_est = Π_i (1 + g_i) − 1`, com `g` de cada peça ofensiva:
- `atk_pct`/`matk_pct`/elemento: `g = v/100` (elemento só na fração do dano daquele elemento)
- `crit`: `g = (v/100)(M−1) / (1 + c(M−1))`; `crit_dmg_pct`: `g = c·(v/100) / (1 + c(M−1))`
- `aspd_pct`: `g ≈ v/100 × fração do dano vinda do básico`; `dot_pct`: `g = v/100 × fração do dano em dano no tempo`

| símbolo | tipo | faixa | descrição |
|---|---|---|---|
| `v` | float | tabela 2.1 | valor da peça no nível |
| `c` | float | 0,05–0,60 | chance de crítico da build no nível (bot, gear do nível) |
| `M` | float | 1,5–1,9 | multiplicador do crítico (`CRIT_MULT` + `crit_dmg_pct`/100) |
| `G_est` | float | 0–0,10 | ganho ofensivo estimado; defesa/utilidade ficam fora (medir) |

**Exemplo (Duelista, 45, c = 0,30, M = 1,5):** Medalhão `atk_pct` 2,5 → 0,025; Anel `crit` 2,5 → 0,025·0,5/1,15 = 0,011;
Sinete `crit_dmg_pct` 8 → 0,30·0,08/1,15 = 0,021; Manto `def_pct` 5 → 0 (defesa). `G_est = 1,025·1,011·1,021 − 1 ≈ 0,058`
→ no topo da faixa; a medição decide. Atributos a mais (+~9% sobre k45 nas joias) somam ~+0,5–1%.

### Como medir (ferramentas que existem + 1 flag nova)
1. `boss_probe` flag nova `--acc=ref|leg [--acc_who=2,3]` (como `--set`/`--set_who`): `ref` = joias de referência do nível,
   `leg` = `bot_legendary_accessories`. Rodar com `--lvl=45 --set=b5 --tank_lock --hp=2 --trials=80` (método F5: `--tank_lock`
   para build que já bate no teto do tanque; `--hp=2` para medir ritmo, não abertura) e comparar `TIME ... todas=` de `ref` vs `leg`.
   Mesmo para 35 (`--set=h5` ou Ápice) e 40. 40+ lutas por lado; 80 se a diferença ficar < 3%.
2. Imprimir `ACC <membro> <stat>=<valor>` por peça e contadores dos stats novos (crítico com `crit_dmg`, tiques de `dot_pct`,
   CC encurtado, mana poupada) — stat que não dispara em 60 s de luta é FLAG.
3. `tools/tests/mana_probe.tscn` nas 13 builds com mana herdada: "boss empty" do lendário ≥ o do k45 (sem regressão).
4. `band_probe -- --from=35 --to=45 --only=duel`: a caçada não deve ficar trivial (tempo por monstro ≥ −10% do atual).
5. `sim_probe --suite`: ms/tick igual (±2%).

## 5. Save / compatibilidade

- Só itens **novos** (24 builds × 3 níveis × 4 peças = **288 ids**). Nenhum id existente muda; formato do save igual:
  **sem** subir `SaveSystem.VERSION` por causa disto (o Ápice já sobe 5 → 6; não juntar migração).
- `+N`: `GameData.plus_item` / `resolve_item` já cobrem (`leg_acc_..._45_signet+3`); o `bonus` é copiado da base.
- Save com o 2º anel em `RING2` já existe (`SaveSystem.saved_slot`); nada novo.
- Builds/ids de build renomeados no futuro quebram estes ids como quebrariam os conjuntos: mesma política.
- `catalog_dump` antes/depois: o diff deve ter só os 288 itens novos + os stats novos em `STAT_KEYS` (nenhum item antigo muda).

## 6. Checks a adicionar (`tools/tests/run_tests.gd`, `_check_legendary_accessories`)

1. Existem 288 itens `leg_acc_*`: toda build × `HYBRID_LEVELS` × {cape, amulet, ring, signet}; slot certo (signet = `RING`);
   raridade lendária; `set_id == ""`; `class_restriction == [classe]`; `level_req` = nível; nome com o `of` da build e o epíteto do tier.
2. Toda build tem entrada em `Balance.LEG_ACC_BUILDS` com as 4 peças; todo stat citado está em `Stats.STAT_KEYS` e em `LEG_ACC_STEP`
   (3 números crescentes); `bonus` de cada item = `LEG_ACC_STEP[stat][i] × LEG_ACC_BUILD_MULT` (+ mana herdada nas 13 builds FOR/AGI).
3. Não conta em conjunto: vestir conjunto de 4 peças + 4 acessórios → `active_sets[sid] == 4`.
4. Peça repetida não soma: Anel X em `RING` e `RING2` → bônus uma vez; Anel + Sinete → os dois.
5. Fontes: `legendary_pool(cls, 45, build)` contém os 4; `relic_offer` contém; `relic_cost` = 9 no 45 (7/8 no 35/40);
   `relic_set_missing` não inclui acessórios; nível 30 não oferece nenhum.
6. Bots: `bot_legendary_accessories(bot, 45)` = os 4 da build do bot; nível 34 = vazio; `_gear_bot` continua sem lendário.
7. Um check por stat novo (regra, com teto): crítico com `crit_dmg_pct` 8 = ×1,58; `dot_pct` 10 no dps do `dot`; `cc_resist_pct` 20
   num `stun` de 2 s = 1,6 s e `taunt` intacto; `mp_cost_pct` 6 no custo (mínimo 1); `summon_time_pct` 20 na invocação temporária e
   companheiro permanente intacto; teto de cada um. Ver cada check **falhar** antes da regra existir.
8. Ícones: todo `leg_acc_*` tem `art_<id>.png`; `art_key` do Sinete = `ring_signet` e existe `_a_ring_signet` (check de forma já existe).
9. `_check_catalog_keys` continua verde (`bonus` só com chaves de `STAT_KEYS`).
10. `UiKit.item_bonus_text` tem rótulo pt-BR para os 5 stats novos (nenhuma chave crua na dica).

Revisão visual: `--bag_shot=<png> --wins= --relic` (aba da build no 45) e dica do Sinete; capa no boneco
`-- --autostart=<classe> --gear=<set_id> --screenshot=<png>` com o Manto.

## 7. Perguntas abertas (3)

1. **Bots do mundo** (nível 35+) devem vestir os acessórios lendários da build ao nascer, ou só onde já vestem lendário (probe /
   caminho futuro de lendário de bot)? Recomendo **não** por enquanto: hoje bot nenhum veste lendário e só os acessórios
   desequilibrariam bots × jogador.
2. **Mana herdada (R-LA4)**: o Manto/Medalhão lendário das 13 builds FOR/AGI levam também a mana do Kharzun (recomendado, senão
   o lendário perde para a joia comum no problema de mana do Berserker) — ou o jogador escolhe entre mana e o bônus da build?
3. **Diluição do drop**: com +4 peças no pool da build (que no 35+ já tem conjunto + Ápice/híbrido), a chance de cair uma peça
   de armadura cai ~30%. Peso igual (simples, recomendado) ou os acessórios com uma fração fixa do sorteio
   (ex.: `Balance.LEG_ACC_DROP_SHARE` 0,25, como `SHIELD_LEGENDARY_SHARE`)?

## Implementação (2026-11-17, class-designer)

Respostas do autor: (1) bots do mundo não vestem; (2) Manto + Medalhão levam a mana; (3) fatia própria no sorteio.
Re-base pela rev2 dos acessórios (`accessory-rework-spec-2026-11-17.md` §8): atributos/DEF pela curva F1/F2 x `LEGENDARY_MULT`
(anel principal 94/121/155, medalhão 109/141/181, manto DEF/MDEF 13/9, 17/12, 22/16; conferido no check), papéis no valor k45 (anel e
sinete +6 ATK ou MATK pela build: MATK se o atributo é INT/WILL ou a build é `matk_pct`; medalhão vida +3%) e mana herdada do k45:
FOR/AGI = tema guerreiro (medalhão `mp_on_kill` 12, manto `mp_regen_combat` 1,0), INT/WILL = sábio (medalhão `mp_regen_combat` 0,5),
VIT nada. O bônus da build soma por cima (tabelas 2.1/2.2 em `Balance.LEG_ACC_STEP`/`LEG_ACC_BUILDS`).
- Código: `GearCatalog.legendary_accessories` (+ `leg_acc_id`, `leg_acc_theme`, `LEG_ACC_NAMES`), `GameData.legendary_accessory_pool`
  (entra em `legendary_pool`, logo na Relicária), `ItemSystem.pick_legendary` (com acessórios no nível: `Balance.LEG_ACC_DROP_SHARE` 0,25
  = acessório, senão o pool sem eles), `ItemSystem.bot_legendary_accessories` + `Sim.` repasse; `Stats`: 5 stats novos, tetos,
  `crit_mult/dot_mult/cc_mult/mp_cost_of/summon_time_of`, bônus deduplicado por `base_id`/id; `Combat.calc_damage/calc_heal` usam
  `crit_mult`; `WorldSim._apply_effects` (dot/sangramento x `dot_mult`, atordoar/prender/lentidão x `cc_mult` do alvo), veneno da lâmina,
  `LegendEffects` (sangramento/veneno lendários), `try_cast`/`_cancel_cast` (custo), `spawn_summon` (duração).
- `cc_resist_pct` vale no caminho de efeitos de skill (`_apply_effects`): é por onde passam atordoar/prender/lentidão de skill e de chefe.
- UI: `UiKit.BONUS_LABELS` (rótulo pt-BR de todo stat de bônus), linha "Acessórios lendários" na aba da build da Relicária
  (`npc_ui._relic_acc_row`); arte: `ItemIcons._a_ring_signet` (Sinete), 288 `art_leg_acc_*.png`.
- Sonda: `boss_probe --acc=leg [--acc_who=...]` (sem a flag = as joias comuns, referência). `dev_runner --item_tip=<id>` (dica na foto).
- Check `_check_legendary_accessories` (itens 1-10 da seção 6; o 9 continua em `_check_mana_accessories`). Visto falhar antes (3 FAIL, 0/288).
- Fora: `mana_probe`/`band_probe --acc` (não pedidos nesta rodada).
