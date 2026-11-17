# Retrabalho dos acessórios (capa, amuleto, 2 anéis) — spec

Data: 2026-11-17 (rev. 2, com as decisões do autor sobre a rev. 1) · Autor: systems-designer · Estado: IMPLEMENTADO 2026-11-17 (class-designer; ver "Implementação" no fim)
Base lida: `data/catalog/items_catalog.gd` (225-233), `data/catalog/gear_catalog.gd` (`PIECE_WEIGHT`, `_attrs`, `armor_item`,
`wearables`, `kharzun_jewels`, `mana_bonus`), `data/balance.gd` (`GEAR_*`, `MANA_*`, `KHARZUN_JEWEL_*`, `REGEN_MP_*`),
`core/sim/stats.gd` (`STAT_KEYS`, `compute`), `core/sim/world_sim.gd` (`_gear_scan`, regen de MP), `tools/tests/run_tests.gd`
(`_check_mana_accessories`, `_check_equipment_slots`, linha 2452).

## 0. Problema e decisões do autor

Problema: o Anel do Capitão (nv 8, FOR 30 + VIT 30 = 60) é melhor que os anéis de forja do nível 16 (44). Os 9 acessórios únicos
escritos à mão ficaram grandes demais depois do x10 dos atributos: estão 1,5x a 2,8x acima da comum do mesmo nível, e o Amuleto do
Golem (nv 24, 160) passa até a comum do nv 40 de hoje (129).

Decisões (fixas):
1. Único = min(1,25x a comum do mesmo slot e nível; 0,9x a comum do tier seguinte), sobre a curva nova.
2. Curva das comuns ancorada no **t2 (nv 16)**: o t2 fica como hoje (anel/capa 44, amuleto 52) e cada tier soma ~+50% a partir
   dali. **Nenhum tier perde atributo em relação a hoje**; t0/t1 ficam iguais ou maiores.
3. Papel por peça: **anel** = ATK (temas guerreiro/caçador) ou MATK (sábio), plano e pequeno; **amuleto** = mana (já existe) +
   vida em **% (`hp_pct`)**; **capa** = DEF/MDEF (já existe; sobe com a curva).
4. Tema sábio ganha mana própria = regeneração de MP (chave existente `mp_regen_combat`).
5. Piso do atributo continua 1,0. Manto do Conde (`cape_vargo`) com DEF/MDEF **4/4**.

Consequência aceita: a curva ancorada no 16 deixa os acessórios mais fortes do 32 em diante; o orçamento de poder passa de
+5% no 40-45 (números reais na seção 4).

---

## 1. Fórmulas

### F1. Atributo de acessório (curva exponencial ancorada no nível 16)

```
f(L) = G^((L − L_ref) / S)
acc_attr(rate, w, L, mult) = max(1,0, snap(rate × L_ref × w × mult × f(L), 0,1))
```
Na escala antiga com uma casa (como `_attrs` hoje); `GameData._scale_attrs` faz x10 depois.

| Símbolo | Tipo | Faixa | Descrição |
|---|---|---|---|
| `rate` | float | 0,62 / 0,30 | `GEAR_ATTR_PRIMARY_PER_LEVEL` (principal) ou `GEAR_ATTR_SECONDARY_PER_LEVEL` (secundário), sem mudança |
| `w` | float | 0,30–0,35 | `PIECE_WEIGHT`: capa 0,30, amuleto 0,35, anel 0,30, sem mudança |
| `L` | int | 1–45 | nível da peça (`COMMON_TIER_LEVELS` ou 45 do Kharzun) |
| `mult` | float | 1,0–1,2 | 1,0 comum; `KHARZUN_JEWEL_MULT` 1,1; `LEGENDARY_MULT` 1,2 (acessório lendário, depois) |
| `L_ref` | float | 16 | **novo** `Balance.ACC_CURVE_REF_LEVEL`: nível em que a curva nova = a linear de hoje (t2) |
| `G` | float | 1,5 | **novo** `Balance.ACC_CURVE_GROWTH`: multiplicador a cada `S` níveis |
| `S` | float | 8 | **novo** `Balance.ACC_CURVE_STEP`: níveis por passo (= distância entre tiers) |
| piso | float | 1,0 | o de hoje (10 na escala nova), mantido |
| resultado | float | 1,0–16,6 | atributo na escala antiga (x10 no jogo: 10–166) |

Faixa: por baixo o piso 1,0; por cima 16,6 (amuleto principal, k45). Nada negativo, sem divisão.
`f(L)`: nv1 0,4675 · nv8 0,6667 · nv16 1,0 · nv24 1,5 · nv32 2,25 · nv40 3,375 · nv45 4,3487 (x1,1 do Kharzun = 4,7836).

**Nunca abaixo de hoje:** a curva linear de hoje vale `L/16` do t2; a nova vale `f(L)`. Nos tiers: nv1 0,0625 vs 0,4675,
nv8 0,5 vs 0,667, nv24 1,5 vs 1,5 (igual), nv32 2,0 vs 2,25, nv40 2,5 vs 3,375. A nova é sempre >= a de hoje nos níveis de tier
(só fica um pouco abaixo entre 17 e 23, onde não existe peça).

Exemplo: anel do Guerreiro nv 32, FOR = 0,62 × 16 × 0,30 × 1,0 × 2,25 = 6,696 → 6,7 → **FOR 67**; VIT = 0,30 × 16 × 0,30 × 2,25 = 3,24 → 3,2 → **VIT 32**.

Implementação: `GearCatalog.acc_attrs(primary, secondary, L, piece, mult)` (nova) chamada por `armor_item` quando
`piece in ["cape", "amulet", "ring"]`. Armas, armaduras e calças **não mudam** (`_attrs` linear de sempre).

### F2. DEF/MDEF da capa (mesma curva, sem constante nova)
```
cape_def(L, mult)  = round(ARMOR["leather"][0] × level_factor(L_ref) × w_cape × mult × f(L))
cape_mdef(L, mult) = round(ARMOR["leather"][1] × level_factor(L_ref) × w_cape × mult × f(L))
```
| Símbolo | Tipo | Faixa | Descrição |
|---|---|---|---|
| `ARMOR["leather"]` | [int, int] | [20, 14] | DEF/MDEF de referência do couro (`GearCatalog.ARMOR`), sem mudança |
| `level_factor(L_ref)` | float | 0,714 | (16 + 4) / (24 + 4): a capa do t2 fica como hoje (4/3) |
| `w_cape` | float | 0,30 | `PIECE_WEIGHT["cape"]` |
| resultado | int | 1–21 | DEF/MDEF plano |

Exemplo: capa nv 40 = round(20 × 0,714 × 0,3 × 3,375) = round(14,46) = **14** DEF; round(14 × 0,714 × 0,3 × 3,375) = round(10,13) = **10** MDEF.
Anel e amuleto continuam com DEF = MDEF = 0.

### F3. ATK/MATK plano do anel (tabela por tier)
```
ring.atk  = ACC_RING_ATK[tier]   (tema guerreiro / caçador; k45 = ACC_RING_ATK_K45)
ring.matk = ACC_RING_ATK[tier]   (tema sábio)
```
| Símbolo | Tipo | Faixa | Descrição |
|---|---|---|---|
| `ACC_RING_ATK` | int[6] | 0–5 | **novo** `[0, 1, 2, 3, 4, 5]` por `COMMON_TIER_LEVELS` |
| `ACC_RING_ATK_K45` | int | 6 | **novo** |
| resultado | float | 0–6 (x1,54 no +9) | vai no `ItemDef.atk`/`matk` (somado em `Stats.compute` passo 2, como a arma) |

Campo do item, não `bonus`: soma nos 2 anéis, sobe com `+N` (`PLUS_WEAPON_PCT`, +6%/nível), o tooltip já mostra ATK/MATK.
t0 = 0: +1 ATK no nível 1 sozinho seria ~+3% (ATK total ~36).

### F4. Vida do amuleto (todos os temas), em %
```
amulet.bonus["hp_pct"] = ACC_AMULET_HP_PCT[tier]   (k45 = ACC_AMULET_HP_PCT_K45)
```
| Símbolo | Tipo | Faixa | Descrição |
|---|---|---|---|
| `ACC_AMULET_HP_PCT` | float[6] | 1,0–3,0 | **novo** `[1.0, 1.5, 2.0, 2.5, 3.0, 3.0]` |
| `ACC_AMULET_HP_PCT_K45` | float | 3,0 | **novo** |
| resultado | float | % | `hp_pct` já está em `Stats.STAT_KEYS` e em `compute` (multiplica a vida): nada novo na sim |

Por que %: no nv 40 a vida vai de ~400 (Elementalista) a ~1500 (Paladino); com % o amuleto pesa igual para os dois.
Exemplo: Paladino nv 40 com 1513 de vida e amuleto t5 → 1513 × 1,03 = **1558** (+45).

### F5. Mana do amuleto do Sábio
```
amulet_sabio.bonus["mp_regen_combat"] = MANA_SAGE_REGEN[tier]   (k45 = MANA_SAGE_REGEN_K45)
```
| Símbolo | Tipo | Faixa | Descrição |
|---|---|---|---|
| `MANA_SAGE_REGEN` | float[6] | 0,15–0,40 | **novo** `[0.15, 0.2, 0.25, 0.3, 0.35, 0.4]`, % da mana máxima por s, só em combate |
| `MANA_SAGE_REGEN_K45` | float | 0,5 | **novo** |
| `REGEN_MP_PCT` | float | 1,5 %/s | regen base (sempre, `world_sim._update_entity`), referência |
| resultado | float | % | +10% (t0) a +33% (k45) sobre a regen base, em combate |

Chave existente (`mp_regen_combat`), mesma regra da capa de mana. Fica no **amuleto** (a peça de mana de todos os temas);
a capa do Sábio continua sem mana. Guerreiro/Caçador sem mudança: amuleto `mp_on_kill` (`MANA_KILL_PCT`), capa `mp_regen_combat`
(`MANA_COMBAT_REGEN`). `mana_bonus(piece, theme, tier)` passa a devolver as três regras.
Exemplo: Elementalista nv 40, 1000 de MP: base 15 + 1 = 16 MP/s; com amuleto t5 em combate +4 → **20 MP/s**.

### F6. Acessório único
```
C      = soma dos atributos (escala nova) da comum do mesmo slot e nível (F1; os 3 temas têm a mesma soma)
C_next = idem no tier seguinte
U      = min(ACC_UNIQUE_MULT × C, ACC_UNIQUE_NEXT_CAP × C_next)
attr_i = round(U × share_i / Σshare)        (share = os números escritos hoje no catálogo: a identidade)
```
| Símbolo | Tipo | Faixa | Descrição |
|---|---|---|---|
| `ACC_UNIQUE_MULT` | float | 1,25 | **novo** |
| `ACC_UNIQUE_NEXT_CAP` | float | 0,9 | **novo**: teto = 90% da comum do tier seguinte |
| `share_i` | int | 1–6 | proporção do item hoje (ex.: Capitão FOR 3 : VIT 3) |
| resultado | int | 27–96 | atributo na escala nova; o catálogo guarda `/10` com uma casa |

Exemplo: Anel do Capitão nv 8: C = 30, C_next = 44 → U = min(37,5; 39,6) = 37,5 → FOR round(18,75) = **19**, VIT **19**.
Único em que o teto manda: Anel de Gel (nv 1): min(30; 27) = 27.

Papel dos únicos: anel recebe ATK (par começa em FOR/AGI) ou MATK (começa em INT/WILL) igual à comum do tier; amuleto recebe o
`hp_pct` do tier e a mana pelo 1º atributo (FOR/AGI → `mp_on_kill`; INT/WILL → `MANA_SAGE_REGEN`); DEF/MDEF próprios de anel/amuleto
ficam como hoje. Implementação: `GearCatalog.unique_acc(item, piece)` aplicada a uma lista `ItemsCatalog.UNIQUE_ACCESSORIES`
(os 9 ids) no fim de `ItemsCatalog.build()`, com os números de hoje como `share`.

---

## 2. Tabelas antes/depois — comuns

Atributos na escala do jogo (x10). "P/S" = principal/secundário. Mesma soma para os 3 temas.

### Anel (peso 0,30)
| tier (nv) | antes P/S = soma | depois P/S = soma | razão p/ tier ant. | ATK/MATK novo |
|---|---|---|---|---|
| t0 (1) | 10/10 = 20 | 14/10 = 24 | — | 0 |
| t1 (8) | 15/10 = 25 | 20/10 = 30 | 1,25 | 1 |
| t2 (16) | 30/14 = 44 | 30/14 = **44** | 1,47 | 2 |
| t3 (24) | 45/22 = 67 | 45/22 = 67 | 1,52 | 3 |
| t4 (32) | 60/29 = 89 | 67/32 = 99 | 1,48 | 4 |
| t5 (40) | 74/36 = 110 | 100/49 = 149 | 1,51 | 5 |
| k45 (45, x1,1) | 92/45 = 137 | 142/69 = 211 | 1,42 | 6 |

### Amuleto (peso 0,35)
| tier (nv) | antes | depois | razão | HP % novo | mana guer./caç. (`mp_on_kill`, igual) | mana Sábio novo (`mp_regen_combat`) |
|---|---|---|---|---|---|---|
| t0 (1) | 10/10 = 20 | 16/10 = 26 | — | 1,0 | 4 | 0,15 |
| t1 (8) | 17/10 = 27 | 23/11 = 34 | 1,31 | 1,5 | 5 | 0,20 |
| t2 (16) | 35/17 = 52 | 35/17 = **52** | 1,53 | 2,0 | 6 | 0,25 |
| t3 (24) | 52/25 = 77 | 52/25 = 77 | 1,48 | 2,5 | 7 | 0,30 |
| t4 (32) | 69/34 = 103 | 78/38 = 116 | 1,51 | 3,0 | 8 | 0,35 |
| t5 (40) | 87/42 = 129 | 117/57 = 174 | 1,50 | 3,0 | 10 | 0,40 |
| k45 | 107/52 = 159 | 166/80 = 246 | 1,41 | 3,0 | 12 | 0,50 |

### Capa (peso 0,30): atributos = anel
| tier (nv) | antes atrib. | depois atrib. | DEF/MDEF antes | DEF/MDEF depois | mana guer./caç. (igual) |
|---|---|---|---|---|---|
| t0 (1) | 20 | 24 | 1/1 | 2/1 | 0,3 |
| t1 (8) | 25 | 30 | 3/2 | 3/2 | 0,4 |
| t2 (16) | 44 | 44 | 4/3 | 4/3 | 0,5 |
| t3 (24) | 67 | 67 | 6/4 | 6/5 | 0,6 |
| t4 (32) | 89 | 99 | 8/5 | 10/7 | 0,7 |
| t5 (40) | 110 | 149 | 9/7 | 14/10 | 0,8 |
| k45 | 137 | 211 | 12/8 | 21/14 | 1,0 |

Curva: ~+50% por tier do t1 ao t5 (t0→t1 fica em 1,25-1,31 por causa do piso 1,0 do secundário; o k45 é 5 níveis + x1,1 = 1,42).
Nenhuma linha perde em relação a hoje (atributo, DEF, MDEF).

## 3. Tabela antes/depois — únicos

| id (nome) | slot, nv | antes | C (comum) | depois | razão vs C | < comum seguinte | papel novo | DEF/MDEF |
|---|---|---|---|---|---|---|---|---|
| `ring_gel` (Anel de Gel) | anel, 1 | WILL 20 | 24 | **WILL 27** | 1,13 (teto) | 27 < 30 | MATK 0 (t0) | 0/0 |
| `ring_captain` (Anel do Capitão) | anel, 8 | FOR 30 VIT 30 = 60 | 30 | **FOR 19 VIT 19 = 38** | 1,27 | 38 < 44 | ATK 1 | 2/0 (fica) |
| `ring_vargo` (Selo de Vargo) | anel, 8 | INT 40 AGI 30 = 70 | 30 | **INT 21 AGI 16 = 37** | 1,23 | 37 < 44 | MATK 1 | 0/2 (fica) |
| `amulet_widow` (Lágrima da Viúva) | amuleto, 8 | INT 40 WILL 30 = 70 | 34 | **INT 24 WILL 18 = 42** | 1,24 | 42 < 52 | HP 1,5%, regen MP 0,20 | 0/3 (fica) |
| `cape_vargo` (Manto do Conde) | capa, 8 | VIT 40 WILL 30 = 70 | 30 | **VIT 21 WILL 16 = 37** | 1,23 | 37 < 44 | — | 5/5 → **4/4** |
| `amulet_tusk` (Amuleto de Presa) | amuleto, 8 | FOR 30 AGI 20 = 50 | 34 | **FOR 26 AGI 17 = 43** | 1,26 | 43 < 52 | HP 1,5%, mana ao abater 5 | 0/0 |
| `amulet_silk` (Amuleto de Seda) | amuleto, 8 | INT 30 WILL 20 = 50 | 34 | **INT 26 WILL 17 = 43** | 1,26 | 43 < 52 | HP 1,5%, regen MP 0,20 | 0/0 |
| `ring_spectral` (Anel Espectral) | anel, 16 | INT 40 AGI 40 = 80 | 44 | **INT 28 AGI 28 = 56** | 1,27 | 56 < 67 | MATK 2 | 0/0 |
| `amulet_golem` (Amuleto do Golem) | amuleto, 24 | FOR 60 VIT 60 WILL 40 = 160 | 77 | **FOR 36 VIT 36 WILL 24 = 96** | 1,25 | 96 < 116 | HP 2,5%, mana ao abater 7 | 0/0 |

No catálogo (escala antiga, uma casa) os valores são os de cima /10 (ex.: Capitão `{"FOR": 1.9, "VIT": 1.9}`), calculados pela F6.
Ids, nomes, cor, raridade, `level_req`, preço e fontes ficam iguais. Itens já no save mudam de valor sozinhos (o save guarda o id).
Manto do Conde: DEF/MDEF 4/4 (decisão; soma 8 contra 7 da capa t2, aceito como identidade "defesa igual dos dois lados").
Problema relatado resolvido: anel de forja nv 16 = 44 + 2 ATK contra o Capitão 38 + 1 ATK + 2 DEF; o Espectral (56) fica entre a
comum do 16 (44) e a do 24 (67).

---

## 4. Orçamento de poder (estimativa; medir com as sondas da seção 6)

Referência: build FOR de Guerreiro com os 4 acessórios do tema guerreiro do tier do nível (2 anéis, amuleto, capa), machado de 2 mãos
comum do nível, armadura comum (FOR principal), sem atributos da teia (com eles o total cresce e o % real cai um pouco).
PATK pré-% = ATK da arma + 2 × FOR + 4 + 0,8 × nível. O % da teia multiplica tudo e não muda as razões. Vida: Paladino.

| nível | PATK total ref. (hoje) | Δ atrib. (2×ΔFOR) | Δ ATK anéis | Δ PATK | **% ATK** | HP total ref. (hoje) | Δ VIT×12 | HP % amuleto | **% HP** |
|---|---|---|---|---|---|---|---|---|---|
| 1 (t0) | ~36 | +3,6 | 0 | +3,6 | **+10,0%** | ~260 | 0 | 1,0 | **+1,0%** |
| 8 (t1) | ~89 | +4,2 | +2 | +6,2 | **+7,0%** | ~414 | +1 | 1,5 | **+1,7%** |
| 16 (t2) | ~166 | 0 | +4 | +4 | **+2,4%** | ~678 | 0 | 2,0 | **+2,0%** |
| 24 (t3) | ~242 | 0 | +6 | +6 | **+2,5%** | ~959 | 0 | 2,5 | **+2,5%** |
| 32 (t4) | ~318 | +6,0 | +8 | +14 | **+4,4%** | ~1236 | +16 | 3,0 | **+4,3%** |
| 40 (t5) | ~394 | +21,6 | +10 | +31,6 | **+8,0%** | ~1513 | +65 | 3,0 | **+7,4%** |
| 45 (k45), só comuns | ~449 | +41,8 | +12 | +53,8 | **+12,0%** | ~1709 | +120 | 3,0 | **+10,2%** |
| 45 (k45), lendário do 45 | ~515 | +41,8 | +12 | +53,8 | **+10,4%** | — | — | — | — |

- MATK (Sábio, INT x2,5 + MATK do anel): nv1 +11%, nv8 +7,2%, nv16 +2,1%, nv24 +2,2%, nv32 +4,2%, nv40 +8,1%, nv45 (lendário) +10,8%.
- Quem não usa o tema guerreiro (sem VIT nas joias) só ganha o % do amuleto: +1,0 a +3,0% de vida.
- nv 1 e 8: o % alto vem de totais pequenos (ATK ~36/~89); em número absoluto é +3,6/+6,2 de ATK. Afeta sobretudo bots do 1-15
  (jogador raramente tem os 4 acessórios t0/t1 nesses níveis).
- **Passa de +5% no 40-45** (+8% / +10-12% ATK, +7% / +10% vida), como esperado com a âncora no 16.
- Importância relativa (ref. lendária no 45): atributo principal vindo das 4 joias = 59 de 191 (31%), contra 89 da armadura e 44 da arma
  (+134 de ATK plano da arma). Armadura continua acima; as joias passam o atributo da arma, mas não a arma inteira.
- **Alavancas** se o playtest/sonda mostrar o topo forte demais, sem mexer na decisão da âncora: `ACC_RING_ATK` do t4/t5/k45 para 3/3/4
  (−4 a −6 ATK no 40-45), `ACC_AMULET_HP_PCT` parando em 2,0 (−1% de vida), ou `ACC_CURVE_GROWTH` 1,45 (k45 anel 211 → ~187).

### Efeito nos bots
`_gear_scan` põe no `RING` o **primeiro** anel do tier com o atributo da build (ordem do `GameData.items`: os únicos vêm antes dos gerados).
Hoje bots FOR no t1 vestem o Capitão (60) e INT/AGI o Vargo/Espectral (70/80); depois: 38/37/56. No resto os bots ganham (joias comuns
sobem do t4 em diante; t0/t1 sobem um pouco). Rodar `band_probe` e `boss_probe` (seção 6) antes de fechar.

---

## 5. Constantes (todas em `data/balance.gd`, perto de `MANA_*` / `GEAR_*`)

```
ACC_CURVE_REF_LEVEL := 16.0          # F1/F2: nível onde a curva nova = a linear de hoje (t2)
ACC_CURVE_GROWTH := 1.5              # F1/F2: x por passo
ACC_CURVE_STEP := 8.0                # F1/F2: níveis por passo
ACC_RING_ATK := [0, 1, 2, 3, 4, 5]   # F3: ATK (guerreiro/caçador) ou MATK (sábio) do anel por tier
ACC_RING_ATK_K45 := 6
ACC_AMULET_HP_PCT := [1.0, 1.5, 2.0, 2.5, 3.0, 3.0]   # F4
ACC_AMULET_HP_PCT_K45 := 3.0
MANA_SAGE_THEMES := ["sabio"]         # F5
MANA_SAGE_REGEN := [0.15, 0.2, 0.25, 0.3, 0.35, 0.4]
MANA_SAGE_REGEN_K45 := 0.5
ACC_UNIQUE_MULT := 1.25              # F6
ACC_UNIQUE_NEXT_CAP := 0.9
```
Faixas seguras: `ACC_CURVE_GROWTH` 1,4-1,6 (cada 0,05 muda o k45 em ~±8%); `ACC_CURVE_REF_LEVEL` fixo em 16 (decisão: abaixo disso
o t2 cai, acima o topo cresce mais); `ACC_RING_ATK[5]` 3-6; `ACC_AMULET_HP_PCT` <= 3,5; `MANA_SAGE_REGEN` <= 0,5 (acima de 1/3 da regen
base vira peça obrigatória do mago); `ACC_UNIQUE_MULT` 1,15-1,35.

## 6. Checks a adicionar (`tools/tests/run_tests.gd`)

Novo `_check_accessory_curve(gd)`:
1. **Monotonia**: para cada peça (`cape`, `amulet`, `ring`) e tema, soma de atributos estritamente crescente t0 < t1 < ... < t5 < k45;
   DEF/MDEF da capa, `ACC_RING_ATK`, `ACC_AMULET_HP_PCT` e `MANA_SAGE_REGEN` não decrescentes.
2. **Passo do tier**: razão soma(t)/soma(t−1) em [1,2; 1,6] para todo t >= 1.
3. **Âncora**: anel/capa t2 = 44 e amuleto t2 = 52; capa t2 DEF/MDEF 4/3.
4. **Nunca abaixo de hoje**: para toda peça comum, cada atributo >= o da fórmula antiga (`GearCatalog._attrs` linear recalculado no
   check) e DEF/MDEF da capa >= `round(ARMOR × level_factor × w)` antigo.
5. **Único < tier seguinte**: os 9 de `UNIQUE_ACCESSORIES` com soma < soma da comum do mesmo slot no tier seguinte (qualquer tema).
6. **Único segue a F6**: cada atributo = `round(U × share / Σshare)` ± 1, e a razão soma/C em [1,10; 1,30] (o Gel fica em 1,13 pelo teto).
7. **Identidade**: cada único com as mesmas chaves de atributo de hoje e a mesma ordem de tamanho (Capitão FOR = VIT; Vargo INT > AGI;
   Golem FOR = VIT > WILL...); Manto do Conde DEF = MDEF = 4.
8. **Papel**: a partir do t1 todo anel tem `atk > 0` xor `matk > 0` (MATK no sábio e nos únicos INT/WILL); todo amuleto tem `bonus.hp_pct`;
   amuleto sábio tem `mp_regen_combat == MANA_SAGE_REGEN[tier]` (e k45); anel/amuleto com DEF = MDEF = 0 fora os únicos que já tinham.
9. **Orçamento (sentinela)**: `Stats.compute` do Guerreiro de referência (berserker, nível = tier, equipamento comum do tier, 4 joias do
   tema guerreiro) contra o mesmo com as joias da fórmula antiga recalculada no check: ΔPATK e Δmax_hp dentro da tabela da seção 4 + 2 pontos
   (falha se alguém mexer na curva sem atualizar o spec).

Ajustes em checks existentes:
- `_check_mana_accessories` (linha ~16596): "anéis e Sábio sem mana de joia" passa a "anéis sem mana; amuleto Sábio com
  `mp_regen_combat` = `MANA_SAGE_REGEN[tier]`"; acrescentar k45 do Sábio.
- Linha 2452 (`ring_guerreiro_t3` > `ring_captain`): continua valendo (67 > 38).
- `_check_equipment_slots` "anéis não tiram vida": continua.
- Tooltip: `UiKit.item_tooltip(amulet_*_t*)` mostra a linha de vida % e o anel mostra ATK/MATK.

Medições antes de fechar: `band_probe` (`--from=1 --to=30`; o 1-15 ganha +7-10% de ATK nos bots), `boss_probe` (`--party=1,3 --trials=20`)
nos chefes 30-45 (é onde o ganho é maior; tabela calibrada em `docs/DESIGN.md`), `web_probe --level=30` e `--level=45` (média de ATK/HP
da build contra o alvo x1,3-1,5 / x1,1-1,3).

## 7. Arquivos a mexer

| arquivo | o quê |
|---|---|
| `data/balance.gd` | constantes da seção 5 |
| `data/catalog/gear_catalog.gd` | `acc_attrs` (F1), ramo de acessório em `armor_item` (F1 + F2), `wearables`/`kharzun_jewels` (ATK/MATK do anel, `hp_pct` do amuleto), `mana_bonus` (Sábio), `unique_acc` (F6) |
| `data/catalog/items_catalog.gd` | `UNIQUE_ACCESSORIES` + passe no fim de `build()`; linhas 225-233 viram as proporções (números de hoje); `cape_vargo` DEF/MDEF 4/4 |
| `game/ui/ui_kit.gd` | `item_bonus_text`: linha "Vida +X%" (`hp_pct`) |
| `tools/tests/run_tests.gd` | seção 6 |
| `docs/DESIGN.md` | parágrafo de acessórios (curva, papéis, únicos) |
| `core/sim/stats.gd` | **nada** (`hp_pct`, `mp_regen_combat`, ATK/MATK de item já existem) |
| saves | **nada** (ids iguais; valores vêm do catálogo) |

Preço (`_price`), receitas e custos de forja não mudam.

## 8. O que o spec de acessórios lendários (2026-11-16) precisa re-basear

- **R-LA3**: trocar `armor_item` linear pela F1/F2 com `mult = LEGENDARY_MULT` (1,2). Com a curva linear o lendário ficaria **abaixo**
  das comuns novas (anel lend. 45 linear 10,0 contra k45 novo 14,2). Na F1 (escala antiga, principal):

  | peça | t4 (32) | **lend. 35** | t5 (40) | **lend. 40** | k45 | **lend. 45** |
  |---|---|---|---|---|---|---|
  | Anel / Sinete | 6,7 | **9,4** | 10,0 | **12,1** | 14,2 | **15,5** |
  | Medalhão | 7,8 | **10,9** | 11,7 | **14,1** | 16,6 | **18,1** |
  | Manto, atributo | 6,7 | **9,4** | 10,0 | **12,1** | 14,2 | **15,5** |
  | Manto, DEF/MDEF | 10/7 | **13/9** | 14/10 | **17/12** | 21/14 | **22/16** |

  (`f(35)` = 2,6195; ordem t4 < L35 < t5 < L40 < k45 < L45 em todas as linhas.)
- **R-LA4** (mana herdada): acrescentar a mana do Sábio (builds INT/WILL herdam `MANA_SAGE_REGEN_K45` no Medalhão) e herdar os papéis
  novos no valor do k45: Anel/Sinete com `ACC_RING_ATK_K45` (ATK ou MATK pela build), Medalhão com `ACC_AMULET_HP_PCT_K45`.
- **Seção 4 (F-LA1/F-LA2)**: a linha de base do ganho medido passa a ser as comuns novas (k45 com ATK/vida); como as comuns do 40-45 já
  sobem +8-12%, o teto `G_acc > 0,08` do lendário deve ser medido contra elas, não contra as de hoje.
- O papel "anel = ataque" do lendário soma ao ATK plano novo; conferir que o bônus de build do Anel não repete a mesma ideia em número pequeno.

## 9. Perguntas abertas

- **Q1. Topo do Ato II**: com a âncora no 16, as joias somam +8% ATK / +7% vida no 40 e +10-12% / +10% no 45. Aceitar e recalibrar os
  chefes 40-45 pelo `boss_probe`, ou usar uma das alavancas da seção 4 (anel 3/3/4 no t4/t5/k45, vida % parando em 2,0, crescimento 1,45)?
  Recomendo medir primeiro (`boss_probe` + `web_probe --level=45`) e só então decidir.

## Implementação (2026-11-17, class-designer)

Feito como na rev. 2, com estas diferenças:
- **Desfeito em 2026-11-17 (decisão do autor)**: o anel voltou aos valores do spec (`[0, 1, 2, 3, 4, 5]`, k45 6; sentinela 14/31,6/53,8);
  o autor aceitou os chefes 43-44 mais fáceis solo, sem recalibrar. Histórico:
- **1ª alavanca aplicada** (decisão "aplicar e medir"): `ACC_RING_ATK = [0, 1, 2, 3, 3, 3]`, `ACC_RING_ATK_K45 = 4` (spec: 4/5/6 no t4/t5/k45).
  Ganho de PATK das 4 joias do Guerreiro: +3,6/+6,2/+4/+6/+12/+27,6/+49,8 (t0..t5, k45; spec 14/31,6/53,8 no t4/t5/k45).
- **Errata da tabela da seção 2**: capa k45 DEF = **20** (não 21). f(45) = 1,5^3,625 = 4,3484 (a tabela usou 4,3487):
  20 × 0,714 × 0,3 × 1,1 × 4,3484 = 20,4997 → 20. MDEF 14 confere. O resto das tabelas 2 e 3 bate com o jogo.
- Sentinela de orçamento (check 9) mede o ganho em **pontos de PATK** (coluna "Δ PATK", que bate exatamente) e vida em %; o "% ATK"
  da seção 4 depende da arma/armadura de referência (com machado 1 mão + placa comum o mesmo Δ dá +10,4% no t5 e +16,6% no k45).
- Código: `Balance.ACC_*` / `MANA_SAGE_*`; `GearCatalog.acc_curve`, `acc_attrs`, `acc_tier`, `acc_roles`, `acc_common_sum`, `unique_acc`,
  `mana_bonus(piece, theme, tier)` (tier -1 = k45; assinatura nova); ramo de acessório em `armor_item`; `ItemsCatalog.UNIQUE_ACCESSORIES`
  + passe em `build()`; `UiKit.item_bonus_text` mostra "Vida +X%". Checks `_check_accessory_curve` (+ `ACC_UNIQUE_SHARES`,
  `ACC_BUDGET_*`) e `_check_mana_accessories` (Sábio). Dump do catálogo: só acessórios mudam (69 ids: 60 comuns + 9 únicos; as capas t2 ficam iguais).

Sonda (`boss_probe`, semente padrão; solo = `--bands` + `--party=1 --seed=7`, 40 lutas):
| Chefe | solo antes → depois → alavanca (40) | trio antes → depois → alavanca (20) | 5 sorteados antes → depois (20) |
|---|---|---|---|
| Troll Rei (38) | 1/20 → 0/20 → — | 14 → 14 | 9 → 12 |
| Besteiro Vorgul (39) | 1/20 → 2/20 → — | 15 → 17 | 7 → 11 |
| Ghar (40) | 7/20 → 6/20 → — | 11 → 8 | 8 → 10 |
| Mãe-Loba (41) | 19 → 21 → 23* | 19 → 19 → 18 | 13 → 13 |
| Shazka (43) | 16 → 22 → 21 | 14 → 19 → 17 | 15 → 16 |
| Ulgra (44) | 17 → 22 → 19 | 17 → 17 → 18 | 9 → 12 |
| Gorbash (44) | 1/20 → 2/20 → — | 12 → 16 | 13 → 13 |
| Kragmar (44) | 14 → 18 → 17 | 16 → 13 → 18 | 14 → 12 |
| Durgash (45, `--lvl=45`) | — | — | 9 → 9 (73 → 63 s) |
(*) Mãe-Loba com alavanca: 12/20 na semente padrão + 11/20 (seed 7 sem alavanca; a alavanca não muda o solo com seed 7 nos outros três).
Faixa de grupo: solo 20-40%, trio 75-100%. Antes já estavam fora: Troll/Vorgul/Gorbash (solo baixo), Mãe-Loba (solo 45%), Shazka/Ghar/Gorbash (trio).
Depois: Ulgra (40% → 55%), Shazka (40% → 55%) e Kragmar (35% → 45%) passam do teto solo; com a alavanca ficam em 48%/52%/42%.
A alavanca do anel quase não muda o solo (na seed 7 deu as mesmas vitórias): o ganho vem dos atributos da curva. `band_probe` 8-16: tudo 16/16
fora o golem_moss 15 → 14 (flags triviais 2 → 3, ruído); `web_probe` média ATK x1,36 → 1,35 (40) e 1,44 → 1,42 (45), vida igual.
**Aberto (autor)**: chefes 41-45 ~+10 pontos acima do teto solo — recalibrar no `boss_probe` (vida/ATK dos chefes) ou usar outra alavanca
(`ACC_CURVE_GROWTH` 1,45, vida % parando em 2,0).

Para o spec dos acessórios lendários (R-LA3/R-LA4): `GearCatalog.armor_item(..., piece in ACC_PIECES, mult=Balance.LEGENDARY_MULT)` já
aplica F1/F2 com o `mult`; papéis por `GearCatalog.acc_roles(it, piece, -1, magic)` (tier -1 = valores k45) e mana por
`GearCatalog.mana_bonus(piece, theme, -1)` (para build INT/WILL use o tema "sabio"); `GearCatalog.acc_curve(level)` = f(L).
