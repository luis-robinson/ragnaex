# Ato III — Adendo: Lendários do 50 (visual próprio + efeito em TODA peça) — PLANO

> **Status**: **Aprovado pelo usuário em 2026-11-21** — (1) arma **desperta** (mantém `legend.kind`, ganha `legend.wake`);
> (2) **pode misturar peças de builds diferentes** ("a ideia é diversidade"): cada peça vale sozinha, o efeito que cita uma skill
> só age se o personagem tem a skill; os bônus de 2-5 peças continuam por conjunto; (3) onda 1 = Guardião, Executor, Sacerdote, Lobo,
> Caçador, Lâminas, Fogo, Invocador. Antes: Adendo a [`ato3-excesso-45-50.md`](ato3-excesso-45-50.md) §8 (Lendários 50).
> **Author**: game-designer (Claude) · **Data**: 2026-11-21 · **Base**: master `9cf9077` (+ árvore de trabalho com WP1: `LEGENDARY_LEVELS` já tem 50).
> **Decisões do usuário (2026-11-21, vinculantes)**: atos finais GRANDES, com chefes e mecânicas ÚTEIS; conjuntos 50 no tema do Ato III
> (Lumeria: porcelana com lágrima pintada, máscaras, fitas de seda, espelhos/vidro, lanternas, ouro velho; **desenhos e nomes nossos**,
> nada de Warhammer) com **visual NOVO por build** (não recolorido), feitos em **ondas**; **toda peça lendária do 50 tem efeito próprio**
> ligado à identidade da build (exemplo do usuário: mago → barreira de mana mais forte, mais redução indo para o MP). Não só stat chapado.
> **Substitui** no GDD pai: §8 "visual = malhas do Ato II numa 4ª cor" (vira só o *fallback* enquanto a onda da build não chega) e §11
> "Kits: 0 malha nova de conjunto" (vira: 0 malha nova **no kit principal**; as novas vão no addon `_a3`). D6 (só conjunto de build no 50) continua.
> **Fontes lidas**: `classes_catalog.gd` (24 `_b(...)`, `legend`, `signature`), `gear_catalog.gd` (`build`, `legend_effect`, `set_bonuses`,
> `WEAPON_ROLES`, `DETERMINATION_SHIELDS`, `ACT2_VISUALS` estilos `<pre>_<b>35`), `legend_effects.gd`, `fusion_effects.gd` (ganchos
> `on_hit/on_cast/on_block/on_dodge/on_hit_taken/on_kill/tick`), `stats.gd` (`STAT_KEYS` com as chaves de notável novas), `charge_system.gd`,
> `class_talent_system.gd` (`apply_mods`, `form_stats/form_mult`, `oath_max`, `dot_boost`, `summon_time`), `item_system.gd`
> (`bot_legendary_set`, `bot_set_weapons`), `balance.gd` (`LEGEND_NUMBERS`, `SET_*`, `APEX_*`, caps `MANA_GUARD_CAP` etc.), `apice-sets.md` (F-AP2).

---

## 1. Visão geral

Os 24 conjuntos de build do nível 50 (`set_<classe>_<build>_50`, já gerados pelo laço de `GearCatalog.build` desde o WP1) ganham:
1. **Um visual novo por build** no tema de Lumeria, em malhas próprias num **kit addon por classe** (`kit_<classe>_<sexo>_a3.glb`), lidas pelo
   mesmo caminho do addon `_a2` do Paladino — o kit principal não ganha malha.
2. **Um efeito por peça** (cabeça, peito, calça, luvas, botas, arma, e mão secundária/escudo onde a build tem) que mexe numa mecânica da
   build. Cada peça vale sozinha (não precisa do conjunto inteiro); os bônus de 2/3/4/5 peças continuam os da F10 (§4.3).
3. A **arma do 50 não troca o `legend`**: ela o **desperta** (mesmo efeito, números do tier 9, + uma cláusula nova) — §3.3.

Regra de leitura para o jogador (e para quem implementa): **cada slot tem um papel fixo**, igual nas 24 builds.

| Slot | Papel do efeito | Família de efeito (§3.1) |
|---|---|---|
| Cabeça | **Assinatura**: o teto/limiar/número central da mecânica da build (cargas máx., limiar, barreira) | `cap_up`, `legend_up`, `stat` |
| Peito | **Papel**: sobrevivência ou função de grupo da build | `stat` (chaves de notável) |
| Calça | **Ritmo**: stat de papel ou duração | `stat`, `dot_up`, `skill_mods` |
| Luvas | **Cargas**: uma skill-chave da build ganha cargas (`ChargeSystem`) | `charges` |
| Botas | **Movimento/gatilho**: liga duas skills da build ou um evento (esquiva, abate, bloqueio) | `on_*`, `zone_on_cast`, `skill_mods` |
| Arma | **Despertar** do `legend` da build | `legend_wake` |
| Mão sec./escudo | 2ª cláusula (Determinação, pistola, 2ª arma) | `legend_up`, `stat`, `on_*` |

---

## 2. Fantasia do jogador (MDA)

Estética-alvo: **Expression** (o conjunto muda COMO a build joga, não só quanto bate) e **Challenge/Competence** (cada peça premia
executar a mecânica da build: aparar, gastar Bravata, encher Feridas). Secundária: **Fantasy** — o herói que venceu a Festa Eterna
veste o que tirou dela: a porcelana chorosa, as máscaras, as lanternas que nunca se apagam, agora **a seu favor**.
- **SDT / Autonomia**: cada peça vale sozinha → misturar 4 do 50 com 1 peça favorita é escolha real (§6, degenerados).
- **SDT / Competência**: o efeito está escrito com números na dica da peça e na ficha (J); luvas mostram as cargas na barra (já existe).
- **Bartle**: Achievers (24 visuais para colecionar, 7 efeitos por build), Explorers (combinações de peças entre builds da mesma classe).
- **Leitura de cima (52°)**: cabeça e ombros carregam o elemento-assinatura de cada build (regra de `modelos.md`).

---

## 3. Regras detalhadas

### 3.1 Famílias de efeito (biblioteca: ~11 tipos, não 170 regras soltas)

Toda peça tem `ItemDef.piece_fx: Dictionary` = `{"kind": <família>, ...parâmetros, números do tier}`. **[N]** = gancho novo; **[R]** = reuso puro.

| Família | O que faz | Reuso / onde mora |
|---|---|---|
| `stat` | soma chaves de `Stats.STAT_KEYS` (incl. `mana_guard`, `mp_to_hp`, `summon_guard`, `summon_frenzy`, `leech_shield`, `ally_guard`, `low_dr`, `low_hp_atk`, `overheal_share`) | **[R]** `Stats.compute` (mesmo caminho dos bônus de item) |
| `charges` | a skill `skill` ganha cargas como se tivesse o nó `<classe>_k_<skill>`; com o nó já comprado: +`LEG50_CHARGE_BONUS` (1) carga, teto `LEG50_CHARGE_CAP` (4) | **[N pequeno]** `ChargeSystem.max_of` lê `e.stats.piece_charges[skill]` |
| `legend_up` | soma ao número `key` do `legend` da arma equipada **se** o `kind` bate (chance, pct, max, stacks, icd, targets, dur) | **[N pequeno]** `Stats.compute`: depois de ler `legend` da arma, aplica os `legend_up` |
| `cap_up` | sobe um teto de mecânica de classe: Juramento, Bravata, Ímpeto, `MANA_GUARD_CAP`, tempo da torreta, aparos por janela | **[N]** `PieceEffects.cap(e, key)` lido onde o `Balance.X_MAX` é lido hoje (`ShieldSystem`, `RiposteSystem`, `WorldSim.gain_bravado`, `Stats`, `RangerAscension`) |
| `skill_mods` | mesmo formato dos talentos de classe (`{"<skill>": {campo: +n}}`) | **[R]** `ClassTalentSystem.apply_mods` passa a juntar os mods das peças |
| `form_up` | `form_stats` / `form_mult` de uma forma (lobo, urso, fantasma, demônio) | **[R]** `ClassTalentSystem.form_stats/form_mult` somam as peças |
| `dot_up` | duração/dps do dano no tempo de um tipo (fogo, veneno, maldição, sangramento) | **[R]** `ClassTalentSystem.dot_boost` |
| `zone_on_cast` | lançar `skill` deixa um chão (`zone`) pequeno: cura/dano/lentidão | **[R]** `TrapSystem.place_zone` chamado de `PieceEffects.on_cast` |
| `on_trigger` | evento → ação: `dodge`, `block`, `kill`, `cast:<skill>`, `hit_taken`, `shield_break` → `cd_cut`, `cd_reset`, `gain` (Bravata/Juramento/Frenesi), `cast` (via `LegendEffects.legend_cast` com `power_scale`), `heal`, `barrier` | **[N]** `core/sim/systems/piece_effects.gd` (`PieceEffects`, estático, chamado nos mesmos pontos que `FusionEffects.on_*`) |
| `mana_guard_eff` | 1 MP da Barreira de Mana absorve `1 + x` de dano | **[N]** `Combat.role_mana_guard` lê `e.stats.mana_guard_eff` (chave nova em `STAT_KEYS`) |
| `legend_wake` | a cláusula nova da arma (§3.3) | **[N]** ramo `wake` em `LegendEffects.legend_on_hit/legend_weapon/legend_on_kill` |

Contrato: `PieceEffects` é **sem estado** (`f(sim, e, ...)`), recargas em `e.leg50_ready[<piece>]` (dicionário na entidade, fora do save),
números SÓ em `Balance.LEG50_NUMBERS`. Laço sem alocação por tick (só eventos; nada em `tick` exceto quem for `aura`, nenhuma no plano).

### 3.2 Dados
- `GearCatalog.LEG50[<build>] = {"name", "of", "style", "pieces": {<piece>: {"kind", ...parâmetros sem número, "text"}}}`.
- Números: `Balance.LEG50_NUMBERS[<build>][<piece>] = {<chave>: [v50] ou fixo}` — no texto deste GDD escrito como **`LEG50_<BUILD>_<PEÇA>`**
  (ex.: `LEG50_FOGO_HEAD` = `LEG50_NUMBERS["fogo"]["head"]`). Um só tier (50), então sem [base, passo].
- `GearCatalog.build`: no tier 50 (`Balance.LEG50_LEVEL`), cada peça recebe `piece_fx` de `LEG50` + números; texto da dica lê os números
  (padrão Supremas: "o texto lê de lá"). Ids não mudam (`leg_<c>_<b>_50_<peça>`) → **sem migração de save**.
- Peças 2ª arma (`alt_pieces`, Paladino) têm efeito próprio (linha "arma 2" nas fichas).

### 3.3 Arma do 50: **desperta**, não troca o `legend` (decisão proposta)
A arma 50 mantém `legend.kind/name/skill` da build com os números de `LEGEND_NUMBERS` no tier 9 e ganha `legend.wake = {...}` (nome
"<Nome> Desperta", ex. "Lâmina Justa Desperta"). **Por quê**: (1) `FusionEffects`/Ápice, `BotBrain` e talentos leem `legend.kind`
(`exec_up`, `stun_bonus`, `on_penance_burst`, `signature_chance` com `cast_on_basic`): trocar quebraria ganchos e checks já calibrados;
(2) identidade: o jogador reconhece o efeito que carrega desde o 5; (3) orçamento: a cláusula nova é pequena e medível isolada
(`--l50_off=weapon`). Armas de papel (`WEAPON_ROLES`): Baluarte e Determinação também despertam (linha própria).

### 3.4 Onde cai, troca, bots
- Queda/Relicária/moedas/aprimoramento: iguais ao §8 do GDD pai (tier 9, 10 moedas, Ferreiro Anão). Híbrido/Ápice 50: não (D6).
- **Bots**: `ItemSystem.bot_legendary_set(…, 50)` já cai no conjunto da build (sem Ápice/híbrido no 50); `bot_set_weapons` escolhe a arma
  pelo papel. Bot veste **as 5 peças da própria build** (nunca mistura). Efeitos são da sim → valem para bot sem código. Cargas: o bot
  já respeita `cooldowns` (0 enquanto há carga). Só 5 gatilhos pedem viés no `BotBrain` (Sumir, Recuar, Gancho, Piscar, Oferenda):
  peso `LEG50_BOT_TRIGGER_BIAS` em `_best_skill` quando a peça está vestida (mesmo padrão de `FusionEffects.bot_skill_mult`).
- Bots de cidade 47+ nascem com o conjunto 50 por `_gear_bot` (regra atual de nível); começo rápido 45 não muda.

### 3.5 Visual (todas as builds)
- Estilo `<pre>_<b>50` (prefixos de `chibi_kit.CLASS_PREFIX`; letras da build iguais às do Ato II: `pal_g/c/t`, `ber_g/e/m`, `bis_s/i/b`,
  `dru_x/w/b`, `ran_c/a/l`, `ass_l/d/c`, `ele_f/g/r`, `nec_i/c/s`). Linha em `GearCatalog.ACT2_VISUALS` com nível 50 (ou tabela irmã
  `ACT3_VISUALS`, ver P2) com `colors/accents/glows` de um só nível.
- **Paleta-base do Ato III**: marfim-porcelana `#EDE6D8`, ouro velho `#B08A3E`, rosa-pó `tint_glow` `#E8B4B8`; cada build troca o
  **destaque** (`tint2` = fita/seda) e o brilho; a lágrima pintada usa `tint_glow`. Nada saturado no chão (regra de cor de `zonas.md`).
- Cada build: **silhueta** + **3 motivos** + **peça-assinatura** (sempre cabeça ou ombro). Fitas de seda: no máx. 2 tiras rígidas por
  peça (sem física; animadas pelo osso), saindo dos ombros/elmo para ler de cima.

---

## 4. Fórmulas

### 4.1 F-L50a. Ganho por peça (o que se mede)
`G_p = T_off(p) ÷ T_on − 1`, com `T_on` = tempo médio de luta do grupo de 4 com a build vestindo as 7 (ou 6) peças 50 e `T_off(p)` =
mesmo grupo com o efeito da peça `p` desligado (flag nova `boss_probe -- --l50_off=<peça>|all`).

| Símbolo | Tipo | Faixa | Descrição |
|---|---|---|---|
| T_on, T_off | float (s) | 60–180 | luta de 4 contra chefe 49–50 (`--boss=` do GDD pai, `--hp=2`, 80+ lutas por braço) |
| G_p (armadura) | float | **0,01–0,03** | ganho de uma peça de armadura |
| G_p (arma) | float | **0,02–0,04** | só a cláusula `wake` (o `legend` base já está no `T_off`) |
| G_p (mão sec.) | float | **0,01–0,02** | |
| ΣG | float | **≤ `LEG50_GAIN_MAX` = 0,12** | soma das peças (= `T_off(all) ÷ T_on − 1`) |

Tanque/curandeiro (Guardião, Urso, Executor no papel de apoio, Sacerdote, Batalha): ganho = queda relativa de mortes do grupo a
`--dmg=6` (método do Ápice do Urso, `apice-sets.md` F-AP2) — **1–3% por peça, 6–10% no total**.

**Exemplo**: Fogo no chefe da Fenda, T_on = 96 s, T_off(all) = 105 s → ΣG = 0,094 ≤ 0,12 ✔; T_off(gloves) = 98,4 s → G = 0,025 ✔.

### 4.2 F-L50b. Por que 0,12 (orçamento)
No 45 o melhor 5 peças é o **Ápice** (`G_ap ≤ APEX_GAIN_MAX` 0,12 sobre o 4 peças). O Ápice **não vai ao 50** (D6): sem os efeitos de peça,
o jogador que troca Ápice 45 por conjunto 50 ganharia só `gear_factor` 1,929/1,857 = **+3,9%** de atributos e trocaria a identidade
do Ápice por stat% + recarga. Com `ΣG ≤ 0,12` o conjunto 50 inteiro fica **≥ Ápice 45** (identidade preservada) e **≤ Ápice 45 + 4%
+ 12%**. A dificuldade do GDD pai (§6.2 "relativa plana") é preservada calibrando os chefes 47–50 com `--l50_off=all` (bots vestem
o 50 sem efeitos) e conferindo que, ligados, a vitória do grupo-alvo não passa do teto da faixa (`--bands`, sem `OUT_OF_BAND` alto).

### 4.3 Bônus de 2/3/4/5 peças: **não mudam**
F10 do GDD pai §6.3: `i_ef = min(9,5) + 0,5 × (9 − 5) = 7,0` → 2 peças +atributo 2º (`SET_2PC_*`: 1 + 9 = **10**), 3 peças +atributo
principal (**11**), 4 peças **+48%** na skill de `set_skills` (20 + 4 × 7), 5 peças **+20%** stat da build + **24%** de recarga
(6 + 2 × 7; 10 + 2 × 7), `BUILD_SET_EXTRA` no 3. **Por quê**: o poder novo está nas peças (medido por F-L50a); mexer na série
quebraria a escada 42/44/46/48 e o `web_probe`. Efeito de peça vale com 1 peça; o bônus de conjunto continua premiando fechar o conjunto.

### 4.4 Tetos que as peças podem subir (somados com tudo, teto final)
| Chave | Teto hoje | Peças podem levar até | Constante |
|---|---|---|---|
| `mana_guard` | 30 | **40** | `LEG50_MANA_GUARD_CAP_ADD` 10 (só via `cap_up` da cabeça de mago) |
| cargas de skill | 3 | **4** | `LEG50_CHARGE_CAP` |
| `mana_guard_eff` | — | **0,5** (1 MP = 1,5 de dano) | `LEG50_MANA_EFF_CAP` |
| `low_dr`, `ally_guard`, `summon_guard`, `leech_shield` | 30 | 30 (sem mudança) | caps atuais |

---

## 5. Fichas das 24 builds

Formato: **Conjunto** (nome pt-BR, placeholder do narrative-director) · estilo · visual · tabela. Números = `LEG50_<BUILD>_<PEÇA>`
(chaves dentro: `x`, `y`). **[R]** reuso puro · **[P]** reuso com parâmetro novo · **[N]** gancho novo (sistema indicado).
⭐ = **onda 1**.

### 5.1 Paladino (`pal`)

**⭐ Guardião — "Vigília da Lágrima Dourada"** · `pal_g50` · Silhueta: torre larga, elmo fechado. Motivos: viseira de porcelana com
UMA lágrima de ouro; ombreiras-pires empilhadas com fitas azul-noite; lanterna presa à ombreira esquerda. Paleta marfim/ouro/azul-noite.
Assinatura: **ombreira-lanterna** (peito).
| Peça | Efeito | Tipo |
|---|---|---|
| Cabeça | Juramento +`x` carga máx. e dura +`y` s | [P] `cap_up` oath → `ShieldSystem` (soma a `ClassTalentSystem.oath_max`) |
| Peito | `ally_guard` +`x` (Escudo dos Irmãos) | [R] `stat` |
| Calça | `low_dr` +`x` | [R] `stat` |
| Luvas | Pancada de Escudo (`pal_shield_bash`) em Cargas | [N pequeno] `charges` |
| Botas | bloquear de frente: −`x` s na recarga de Provocar (`pal_taunt`), 1×/`y` s | [N] `on_trigger` block→`cd_cut` (`PieceEffects.on_block`) |
| Arma (espada) | Lâmina Justa Desperta: o golpe sagrado extra dá +1 Juramento | [N] `legend_wake` (`LegendEffects.holy_edge`) |
| Arma 2 (maça) | Baluarte Desperto: a barreira também cobre o aliado mais ferido a ≤ `LEG50_ALLY_RANGE` m com `x`% | [N] `legend_wake` (`LegendEffects.bulwark`) |
| Escudo | Determinação cheia (5): +`x`% DEF aos aliados a 8 m | [N] `on_trigger` → buff de grupo (`PieceEffects`) |

**Cruzado — "Cortejo do Juízo Claro"** · `pal_c50` · Silhueta: capa longa em tiras de seda, ombros altos. Motivos: meia-máscara de
porcelana partida em diagonal; espelho redondo no peito; fitas cruzadas nas costas. Paleta marfim/ouro/vermelho-vinho. Assinatura: **elmo de meia-máscara**.
| Peça | Efeito | Tipo |
|---|---|---|
| Cabeça | Julgamento: +`x`% de chance de atordoar | [P] `legend_up` stun.chance |
| Peito | `cc_resist_pct` +`x` | [R] `stat` |
| Calça | Golpe do Cruzado: +`x`% no último golpe da sequência | [R] `skill_mods` (`strikes.weights`) |
| Luvas | Estocada Sagrada (`pal_lunge`) em Cargas | [N pequeno] `charges` |
| Botas | alvo atordoado pelo Julgamento fica Julgado (`apex_judged`) por `x` s mesmo sem o Ápice | [P] `on_trigger` → `FusionEffects.JUDGED` |
| Arma (montante) | Julgamento Desperto: atordoa também até 2 inimigos comuns a 3 m do alvo (chefe nunca) | [N] `legend_wake` |
| Arma 2 (malho) | Baluarte Desperto: quando a barreira quebra, onda sagrada de `x`% ATK a 3 m | [N] `on_trigger` shield_break |

**Templário — "Sentença de Ouro Velho"** · `pal_t50` · Silhueta: elmo com auréola de 5 lanterninhas, tabardo pesado. Motivos: lanternas
de vidro; espelhinhos no tabardo; véu de seda atrás do elmo. Paleta marfim/ouro/âmbar-chama. Assinatura: **auréola de lanternas**.
| Peça | Efeito | Tipo |
|---|---|---|
| Cabeça | Penitência explode com 1 carga a menos (`stacks` −`x`, mín. 3) | [P] `legend_up` penance.stacks |
| Peito | Martelos Abençoados: +`x` martelo em órbita | [P] `skill_mods` (`orbit.count`, `AuraSystem.start_orbit`) |
| Calça | `def_atk_pct` +`x` | [R] `stat` |
| Luvas | Marca da Penitência (`pal_brand`) em Cargas | [N pequeno] `charges` |
| Botas | explosão da Penitência dá `x` de Juramento | [P] `FusionEffects.on_penance_burst` (mesma regra do P3, sem o híbrido) |
| Arma (martelo) | Penitência Desperta: a explosão deixa Chão Sagrado pequeno (`zone`) por `x` s | [P] `TrapSystem.place_zone` |
| Arma 2 (espada) | Baluarte Desperto: ao ganhar a barreira, +1 Determinação | [N] `legend_wake` |
| Escudo | cada carga de Determinação: +`x`% no dano da explosão de Penitência | [N] `PieceEffects.hit_mult` |

### 5.2 Berserker (`ber`)

**Carniceiro (Machados Gêmeos) — "Banquete das Fitas Rubras"** · `ber_g50` · Silhueta: ombros nus, fitas vermelhas voando dos punhos.
Motivos: máscara de festa com sorriso rasgado (meia-face); cinto de taças de vidro; fitas presas aos cabos. Assinatura: **máscara**.
| Peça | Efeito | Tipo |
|---|---|---|
| Cabeça | Frenesi +`x` carga máx. | [P] `legend_up` frenzy.max |
| Peito | `leech_shield` +`x` | [R] `stat` |
| Calça | `low_hp_atk` +`x` | [R] `stat` |
| Luvas | Arremesso Brutal (`ber_throw_axe`) em Cargas | [N pequeno] `charges` |
| Botas | Investida de Lâminas que acerta enche o Frenesi | [N] `on_trigger` cast:`ber_blade_rush`→`gain` |
| Arma | Frenesi Desperto: com Frenesi cheio, `x`% de chance de o golpe bater de novo com `y`% | [N] `legend_wake` (eco condicional) |
| Mão sec. (machado) | `crit_leech` +`x` | [R] `stat` |

**⭐ Executor — "Lâmina do Último Brinde"** · `ber_e50` · Silhueta: capuz de carrasco alto e pontudo, machado de lâmina enorme. Motivos:
máscara branca de porcelana com lágrima de ouro sob o capuz de seda negra; lâmina com face de espelho; correntes de taças. Paleta
marfim/negro/ouro. Assinatura: **capuz pontudo + máscara**.
| Peça | Efeito | Tipo |
|---|---|---|
| Cabeça | limiar do Carrasco +`x` pontos de vida% | [P] `legend_up` execute.below (soma a `FusionEffects.exec_up`) |
| Peito | `low_dr` +`x` | [R] `stat` |
| Calça | Fender Armadura (`ber_sunder`) põe +1 carga de `sunder` | [P] `skill_mods` → `SunderSystem` |
| Luvas | Decapitar (`ber_decapitate`) em Cargas | [N pequeno] `charges` |
| Botas | abater alvo abaixo do limiar zera Executar (`ber_execute`), 1×/`x` s | [N] `on_trigger` kill→`cd_reset` |
| Arma | Carrasco Desperto: abaixo do limiar, o Golpe Avassalador (assinatura) é crítico garantido | [N] `legend_wake` |

**Punhos de Fúria — "Dança dos Mil Guizos"** · `ber_m50` · Silhueta: mangas longas de seda que caem dos ombros. Motivos: máscara de raposa
de porcelana; guizos dourados nas mangas; cinto de lanterninhas. Assinatura: **máscara de raposa + mangas**.
| Peça | Efeito | Tipo |
|---|---|---|
| Cabeça | esquivar devolve `x` MP e −`y` s na Postura do Contra-Golpe | [N] `on_trigger` dodge (`PieceEffects.on_dodge`) |
| Peito | `evasion` +`x` | [R] `stat` |
| Calça | `hit_slow` `x` | [R] `stat` |
| Luvas | Bote do Tigre (`ber_tiger_pounce`) em Cargas | [N pequeno] `charges` |
| Botas | Punho Vingativo também dispara ao esquivar (1×/`x` s) | [P] `legend_up` + `on_trigger` dodge |
| Arma | Punho Vingativo Desperto: o contra-ataque atinge também inimigos a 2 m com `x`% | [N] `legend_wake` |
| Mão sec. (garra) | `crit` +`x` | [R] `stat` |

### 5.3 Bispo (`bis`)

**⭐ Sacerdote — "Lanterna da Última Vigília"** · `bis_s50` · Silhueta: véu longo até o chão, coroa de lanternas. Motivos: coroa de 5
lanternas de vidro acesas; máscara de porcelana com lágrimas pintadas sob os olhos; asas curtas de vidro facetado. Paleta marfim/ouro/
azul-lavanda. Assinatura: **coroa de lanternas**.
| Peça | Efeito | Tipo |
|---|---|---|
| Cabeça | `overheal_share` +`x` | [R] `stat` |
| Peito | Égide cobre +1 aliado (o 2º mais ferido) | [P] `legend_up` ward.targets |
| Calça | `mp_regen_combat` +`x` | [R] `stat` |
| Luvas | Renovar (`bis_renew`) em Cargas | [N pequeno] `charges` |
| Botas | bloquear (Graça) também tira 1 debuff do aliado curado | [P] `on_trigger` block → `bis_purify` sem custo |
| Arma | Égide Desperta: ao romper, cura `x`% da vida máx. do protegido | [N] `legend_wake` |
| Escudo | Graça cura +`x` pontos de % (`SHIELD_GRACE_PCT`) | [P] `cap_up` grace |

**Iluminado — "Espelho do Meio-Dia"** · `bis_i50` · Silhueta: mitra alta e estreita. Motivos: mitra de vidro facetado (espelhos); dois
espelhos redondos nos ombros; fitas douradas no manto. Assinatura: **mitra-espelho**.
| Peça | Efeito | Tipo |
|---|---|---|
| Cabeça | `radiance` +`x` e `radiance_cap` +`y` | [R] `stat` |
| Peito | Martelo de Luz (`bis_hammer`) em Cargas | [N pequeno] `charges` |
| Calça | `mp_cost_pct` +`x` | [R] `stat` |
| Luvas | Castigo Sagrado (arma): +`x`% de chance | [P] `legend_up` cast_on_basic.chance |
| Botas | Exorcismo atinge +1 alvo | [R] `skill_mods` |
| Arma | Castigo Sagrado Desperto: a Radiância do Castigo lançado pela arma conta ×`x` | [N] `legend_wake` |

**Clérigo de Batalha — "Hino da Taça Partida"** · `bis_b50` · Silhueta: estandarte de seda nas costas. Motivos: máscara de porcelana
partida e remendada com ouro; sinos no estandarte; ombreiras de placa com lanternas. Assinatura: **estandarte + máscara**.
| Peça | Efeito | Tipo |
|---|---|---|
| Cabeça | Estandarte da Fé dura +`x` s | [R] `skill_mods` |
| Peito | `phys_mend` +`x` | [R] `stat` |
| Calça | `block` +`x` | [R] `stat` |
| Luvas | Martelada da Fé (`bis_holy_blow`) em Cargas | [N pequeno] `charges` |
| Botas | Salto da Fé deixa chão que cura `x`% por pulso | [P] `zone_on_cast` |
| Arma | Mão que Cura Desperta: cura que passa do máximo vira barreira até `x`% da vida | [N] `legend_wake` (`sim.mend`) |
| Escudo | Determinação cheia renova o Hino de Batalha | [N] `on_trigger` |

### 5.4 Druida (`dru`)

**Urso — "Guarda da Colheita Mascarada"** · `dru_b50` · Silhueta: ombros de casca envernizada, cabaças. Motivos: máscara de urso em
porcelana (também na forma, `frm_dru_b50_*`); fitas verdes-musgo; lanternas-cabaça na cintura. Assinatura: **máscara de urso** (nas duas formas).
| Peça | Efeito | Tipo |
|---|---|---|
| Cabeça | Casca Viva: recarga −`x` s | [P] `legend_up` cast_when_hit.icd |
| Peito | na forma de urso: `hp_pct` +`x` | [R] `form_up` |
| Calça | `threat_pct` +`x` | [R] `stat` |
| Luvas | Esmagar (`dru_maul`) em Cargas | [N pequeno] `charges` |
| Botas | Urro da Mata dá barreira de `x`% da vida aos aliados a 8 m | [N] `on_trigger` cast→`barrier` |
| Arma | Casca Viva Desperta: lança também Pele de Carvalho no aliado mais ferido a `FUSION_BARK_RANGE` m | [P] `legend_wake` (regra do Ápice do Urso) |

**⭐ Lobo (Fera) — "Galope do Desfile"** · `dru_w50` · Silhueta: fitas longas das braçadeiras. Motivos: máscara de lobo sorridente
(também no lobo, `frm_dru_w50_*`); guizos; colar de lanternas pequenas. Paleta marfim/ouro/verde-garrafa. Assinatura: **máscara de lobo**.
| Peça | Efeito | Tipo |
|---|---|---|
| Cabeça | Sangue da Matilha: +`x`% de chance | [P] `legend_up` bleed.chance |
| Peito | forma de lobo: `form_mult` +`x` | [R] `form_up` |
| Calça | `speed_pct` +`x` | [R] `stat` |
| Luvas | Bote (`dru_pounce`) em Cargas | [N pequeno] `charges` |
| Botas | Bote saindo de Espreitar aplica o sangramento com 100% de chance | [N] `on_trigger` cast:`dru_pounce` |
| Arma | Sangue da Matilha Desperto: até 2 cópias do sangramento no alvo | [N] `legend_wake` (id com índice, como `PLAYER_DOT_MAX_STACKS`) |
| Mão sec. (maça) | `crit` +`x` | [R] `stat` |

**Xamã — "Céu de Lanternas"** · `dru_x50` · Silhueta: chapéu de abas largas com lanternas de papel penduradas. Motivos: lanternas na aba;
máscara de lua crescente; manto de seda estrelado. Assinatura: **chapéu de lanternas**.
| Peça | Efeito | Tipo |
|---|---|---|
| Cabeça | `mana_guard` +`x` | [R] `stat` |
| Peito | `summon_time_pct` +`x` (Lobos Espirituais, Ent) | [R] `stat` |
| Calça | `buff_pct` +`x` | [R] `stat` |
| Luvas | Fogo Lunar (`dru_moonfire`) em Cargas | [N pequeno] `charges` |
| Botas | Chuva Estelar deixa zona lunar que pulsa `x`% MATK | [P] `zone_on_cast` |
| Arma | Lua Cheia Desperta: o Fogo Lunar da arma salta para 1 inimigo a `APEX_MOON_JUMP_RANGE` m com `x`% | [P] `legend_wake` (`FusionEffects._moon_jump`) |

### 5.5 Ranger (`ran`)

**⭐ Caçador — "Arco da Lanterna Errante"** · `ran_c50` · Silhueta: capuz curto, aljava alta. Motivos: máscara de pássaro em porcelana;
aljava-lanterna de vidro; capa curta de fitas. Paleta marfim/ouro/verde-sálvia. Assinatura: **máscara de pássaro**.
| Peça | Efeito | Tipo |
|---|---|---|
| Cabeça | Marca do Caçador: +`x` pontos de dano recebido | [P] `legend_up` mark.pct |
| Peito | `summon_guard` +`x` (o lince segura parte do seu dano) | [R] `stat` |
| Calça | `hit_slow` `x` | [R] `stat` |
| Luvas | Flecha Gélida (`ran_frost_arrow`) em Cargas | [N pequeno] `charges` |
| Botas | Recuar manda o lince dar Ataque da Fera de graça (`ran_sic`, 1×/`x` s) | [N] `on_trigger` cast→`cast` |
| Arma | Marca Desperta: a marca também vale para o dano do lince (+`x`%) | [N] `legend_wake` (`_summon_mult`) |

**Atirador — "Salva do Último Baile"** · `ran_a50` · Silhueta: cartola de seda, óculos. Motivos: óculos de vidro espelhado; colete com
cartuchos dourados; lanterna no cinto. Assinatura: **cartola + óculos**.
| Peça | Efeito | Tipo |
|---|---|---|
| Cabeça | torreta dura +`x` s | [P] `cap_up` turret_time |
| Peito | `trap_max` +1 | [R] `stat` |
| Calça | `crit_dmg_pct` +`x` | [R] `stat` |
| Luvas | Tiro Certeiro (`ran_snipe`) em Cargas | [N pequeno] `charges` |
| Botas | armadilha que dispara: −`x` s em Recuar | [N] `on_trigger` (gancho em `TrapSystem`) |
| Arma | Pólvora Desperta: raio +`x` m; em alvo preso/retardado a explosão é crítica | [N] `legend_wake` |

**Lanceiro — "Lança do Cortejo"** · `ran_l50` · Silhueta: chifres dourados, flâmulas na lança. Motivos: máscara de cervo em porcelana
com chifres de ouro velho; flâmulas de seda; sinos no ombro. Assinatura: **chifres**.
| Peça | Efeito | Tipo |
|---|---|---|
| Cabeça | Ferida Aberta +1 máx. | [P] `legend_up` open_wound.max |
| Peito | `lifesteal` +`x` | [R] `stat` |
| Calça | `cc_resist_pct` +`x` | [R] `stat` |
| Luvas | Dardo de Caça (`ran_javelin`) em Cargas | [N pequeno] `charges` |
| Botas | Salto do Predador em alvo com feridas cheias renova as feridas | [N] `on_trigger` |
| Arma | Ferida Aberta Desperta: com feridas cheias, o sangramento salta para 1 inimigo a 4 m | [N] `legend_wake` |

### 5.6 Assassino (`ass`)

**⭐ Lâminas — "Lágrima de Veneno"** · `ass_l50` · Silhueta: capuz justo, cauda de fitas. Motivos: máscara que chora lágrimas verde-ouro;
frascos de vidro na cintura; fitas nas adagas. Paleta marfim/ouro/verde-veneno escuro. Assinatura: **máscara chorosa**.
| Peça | Efeito | Tipo |
|---|---|---|
| Cabeça | Veneno Letal: +`x`% de chance | [P] `legend_up` poison.chance |
| Peito | `backstab` +`x` | [R] `stat` |
| Calça | `evasion` +`x` | [R] `stat` |
| Luvas | Dardo Venenoso (`ass_venom_dart`) em Cargas | [N pequeno] `charges` |
| Botas | depois de Sumir, a 1ª facada é furtiva (`FusionEffects.ghost`) por `x` s | [P] `on_trigger` cast:`ass_vanish` |
| Arma | Veneno Letal Desperto: Eviscerar que consome venenos devolve `x` MP por veneno | [N] `legend_wake` (`WoundSystem`) |
| Mão sec. (adaga) | `hit_poison` +`x` | [R] `stat` |

**Duelista — "Florete do Espelho"** · `ass_d50` · Silhueta: chapéu de pluma, meia-capa. Motivos: máscara de baile **espelhada**; botões de
vidro na casaca; meia-capa de fitas. Assinatura: **chapéu + máscara espelho**.
| Peça | Efeito | Tipo |
|---|---|---|
| Cabeça | Ímpeto +1 máx. | [P] `cap_up` momentum |
| Peito | `guard_crit` +`x` | [R] `stat` |
| Calça | janela de aparar +`x` s | [P] `cap_up` riposte_window |
| Luvas | Avanço do Duelista (`ass_lunge`) em Cargas | [N pequeno] `charges` |
| Botas | aparar devolve −`x` s no Avanço | [N] `on_trigger` |
| Arma | Riposte Desperta: +`x`% no contra-ataque | [P] `legend_up` riposte.pct |
| Mão sec. (espada) | +1 contra-ataque por janela | [P] `cap_up` riposte_counters |

**Corsário — "Bandeira do Baile Afundado"** · `ass_c50` · Silhueta: bicorne largo. Motivos: lanterna de navio no bicorne; espelhos de
bronze na casaca; faixa de seda. Assinatura: **bicorne-lanterna**.
| Peça | Efeito | Tipo |
|---|---|---|
| Cabeça | Bravata +1 máx. | [P] `cap_up` bravado |
| Peito | `crit_leech` +`x` | [R] `stat` |
| Calça | `def_pct` +`x` | [R] `stat` |
| Luvas | Tiro de Pistola (`ass_pistol_shot`) em Cargas | [N pequeno] `charges` |
| Botas | Gancho de Abordagem dá +`x` Bravata | [R] `skill_mods` (`combo_gain`) |
| Arma | Bala na Agulha Desperta: +`x`% de chance e recarga −`y` s | [P] `legend_up` + `cap_up` |
| Mão sec. (pistola) | Tiro Entre os Olhos com Bravata cheia ricocheteia 1× | [N] `on_trigger` cast→`bounce` |

### 5.7 Elementalista (`ele`)

**⭐ Fogo — "Lanterna do Fim da Festa"** · `ele_f50` · Silhueta: coroa alta de lanternas, manto em fitas. Motivos: lanternas de vidro com
chama dentro; máscara com lágrima de brasa; manto de seda alaranjado. Paleta marfim/ouro/laranja-brasa. Assinatura: **coroa-lanterna**.
| Peça | Efeito | Tipo |
|---|---|---|
| Cabeça | **Barreira de Porcelana**: `mana_guard` +`x` e teto +`y` (até 40) | [R] `stat` + [P] `cap_up` (exemplo do usuário) |
| Peito | `mp_to_hp` +`x` | [R] `stat` |
| Calça | queimadura dura +`x`% | [R] `dot_up` fire |
| Luvas | Bola de Fogo (`ele_fireball`) em Cargas | [N pequeno] `charges` |
| Botas | Semente Ígnea espalha para +1 alvo | [P] `skill_mods` → `SeedSystem` |
| Arma | Brasa Viva Desperta: a Bola de Fogo da arma em alvo queimando devolve `x` MP | [N] `legend_wake` |

**Gelo — "Espelho da Geada"** · `ele_g50` · Silhueta: coroa de cristais em leque. Motivos: coroa de espelhos gelados; ombreiras de vidro;
manto branco-azulado de seda. Assinatura: **coroa de espelhos**.
| Peça | Efeito | Tipo |
|---|---|---|
| Cabeça | **Barreira de Vidro**: 1 MP da Barreira absorve `1 + x` de dano | [N] `mana_guard_eff` (`Combat.role_mana_guard`) |
| Peito | `low_dr` +`x` | [R] `stat` |
| Calça | estilhaçar: +`x`% em alvo retardado | [N] `PieceEffects` → `Combat.frost_mult` |
| Luvas | Lança de Gelo (`ele_ice_lance`) em Cargas | [N pequeno] `charges` |
| Botas | Piscar deixa Nova de Gelo com `x`% de poder | [N] `on_trigger` cast→`cast` |
| Arma | Coração de Gelo Desperto: recarga −`x` s; a Nova deixa a lentidão +`y` s | [P] `legend_up` icd + `skill_mods` |

**Raio — "Sino do Trovão Claro"** · `ele_r50` · Silhueta: chapéu alto com para-raios dourado. Motivos: sinos de vidro; máscara com raio
pintado como lágrima; fitas eriçadas. Assinatura: **chapéu de sinos**.
| Peça | Efeito | Tipo |
|---|---|---|
| Cabeça | `mana_guard` +`x` e `mp_regen_combat` +`y` | [R] `stat` |
| Peito | Sobrecarga dura +`x` s | [R] `skill_mods` |
| Calça | `cdr` +`x` | [R] `stat` |
| Luvas | Corrente Elétrica (`ele_chain`) em Cargas | [N pequeno] `charges` |
| Botas | Passo Relampejante eletrifica (`FUSION_SHOCK_TIME`) quem cruzar | [P] `on_trigger` |
| Arma | Arco Voltaico Desperto: +1 alvo | [P] `legend_up` chain.targets |

### 5.8 Necromante (`nec`)

**⭐ Invocador — "Cortejo de Porcelana"** · `nec_i50` · Silhueta: capuz alto com máscaras penduradas como troféus. Motivos: máscaras de
porcelana sem olhos nos ombros; foice com lanterna roxa; manto de seda em fitas. Paleta marfim/ouro/ameixa. Assinatura: **ombros de máscaras**.
| Peça | Efeito | Tipo |
|---|---|---|
| Cabeça | `summon_frenzy` +`x` | [R] `stat` |
| Peito | `summon_guard` +`x` | [R] `stat` |
| Calça | `summon_time_pct` +`x` | [R] `stat` |
| Luvas | Lança de Osso (`nec_bone_spear`) em Cargas | [N pequeno] `charges` |
| Botas | Oferenda Sombria ergue 1 esqueleto da Legião de graça | [N] `on_trigger` cast→`spawn_summon` |
| Arma | Legião Desperta: recarga −`x` s; o esqueleto erguido bate +`y`% | [P] `legend_up` + [N] `legend_wake` |

**Ceifador — "Colheita do Último Brinde"** · `nec_c50` · Silhueta: capuz rasgado, gola alta. Motivos: máscara sem boca; gola de taças
quebradas; foice de lâmina de vidro escuro. Assinatura: **capuz + máscara**.
| Peça | Efeito | Tipo |
|---|---|---|
| Cabeça | `leech_shield` +`x` | [R] `stat` |
| Peito | `low_dr` +`x` | [R] `stat` |
| Calça | `low_leech` +`x` | [R] `stat` |
| Luvas | Rasgar Alma (`nec_soul_rend`) em Cargas | [N pequeno] `charges` |
| Botas | Giro da Morte cura `x`% da vida por inimigo atingido (teto 5) | [N] `on_trigger` |
| Arma | Ceifa Desperta: o abate cura também o aliado mais ferido com `x`% | [N] `legend_wake` |

**Sombras — "Véu do Espelho Negro"** · `nec_s50` · Silhueta: capuz alto com rosto-espelho. Motivos: espelho negro no lugar do rosto com
lágrima dourada; aletas de seda; lanternas apagadas. Assinatura: **rosto-espelho**.
| Peça | Efeito | Tipo |
|---|---|---|
| Cabeça | `mana_guard` +`x` | [R] `stat` |
| Peito | Pandemia espalha +1 maldição | [R] `skill_mods` |
| Calça | `mp_to_hp` +`x` | [R] `stat` |
| Luvas | Agonia (`nec_curse_agony`) em Cargas | [N pequeno] `charges` |
| Botas | maldições duram +`x`% | [R] `dot_up` curse |
| Arma | Praga Desperta: alvo com Agonia da arma que morre passa a Agonia a 1 inimigo a 4 m | [N] `legend_wake` |

---

## 6. Casos de borda

- **Peça sem a arma da build**: efeitos `legend_up`/`legend_wake` só valem se `legend.kind` da arma equipada bate; outros valem sempre.
  A dica mostra "(sem efeito com esta arma)" em cinza (como a face do Ápice).
- **Mistura entre builds da mesma classe** (ex.: cabeça do Fogo + luvas do Gelo): permitida (autonomia). Degenerado possível: juntar as
  5 melhores cabeças/peitos de `stat`. Mitigação: cada peça ≤ 0,03 (F-L50a) e o bônus de conjunto (4 peças 48%) só fecha com a build →
  misturar custa ~0,05–0,10 de G_4pc; checar no `dps_probe --mix` (P3).
- **Luvas de Cargas + nó da teia comprado**: +1 carga (teto 4). Sem a skill aprendida/equipada: nada. Cargas não vão no save (regra do `ChargeSystem`).
- **Teto da Barreira**: `mana_guard` > 40 é cortado; MP 0 = nada absorve (regra atual). Mago parado com regen alto não fica imortal:
  `mana_guard_eff ≤ 0,5` e `MANA_GUARD_CAP + add ≤ 40` → no máximo 40% do dano sai da mana a 1,5:1.
- **Gatilhos com recarga** (`cd_reset`, `cast`, `spawn`): recarga própria `LEG50_*_ICD`, nunca disparam a si mesmos (mesma trava `signature_casting`).
- **Chefe**: atordoar em área (Cruzado) nunca pega chefe; `cd_reset` no abate não conta lacaio de 0 XP (`summon` de chefe).
- **Invocações** não herdam `piece_fx` (só o dono). **Forma** (lobo/urso/demônio): efeitos valem; peças escondidas pelo `FormModel` mostram a armadura de forma `frm_*50` se existir.
- **Aprimoramento +N**: copia `piece_fx` da base (`GameData.plus_item`); números do efeito NÃO sobem com +N (só stats).
- **Builds sem a onda ainda**: peça tem efeito (dados são baratos), visual cai no fallback Ato II 45 na paleta 50 (`act2_fallback_style`).

---

## 7. Dependências

| Sistema | Direção | Contrato |
|---|---|---|
| `GearCatalog.build` / `LEG50` | dados → item | `piece_fx` nas peças do tier 50; textos |
| `Stats.compute` | lê item | `stat`, `legend_up`, `piece_charges`, `mana_guard_eff` (chave nova em `STAT_KEYS`), caps §4.4 |
| `PieceEffects` **(novo)** | sim | `on_hit/on_cast/on_block/on_dodge/on_hit_taken/on_kill/on_shield_break`, `cap(e,key)`, `hit_mult` — chamado ao lado de `FusionEffects` |
| `ChargeSystem.max_of` | lê stats | +cargas das luvas |
| `ClassTalentSystem.apply_mods/form_*/dot_boost/oath_max` | lê stats | somam `skill_mods`, `form_up`, `dot_up`, `cap_up` oath |
| `LegendEffects` | arma | ramo `wake` por kind |
| `ShieldSystem`, `RiposteSystem`, `WorldSim.gain_bravado`, `RangerAscension`, `SunderSystem`, `SeedSystem`, `TrapSystem` | lê `PieceEffects.cap` | tetos/parâmetros |
| `ItemSystem.bot_legendary_set/bot_set_weapons`, `BotBrain._best_skill` | bots | §3.4 |
| `KitModel.load_addon` / `chibi_kit.A3_STYLES` / `FormModel` | apresentação | §8 |
| `game/ui/windows.gd` (dica, janela C), `SkillSheet` (cargas, números) | apresentação | texto do efeito; cinza sem efeito |
| GDD pai `ato3-excesso-45-50.md` §8, §11, WP11 | doc | precisa de nota apontando para este adendo (não editado aqui) |

---

## 8. Malhas, addon `_a3`, ícones

- **Addon por classe**: `kit_<classe>_<male|female>_a3.glb` = só as malhas `arm_<pre>_<b>50_<slot>_all` (4 por build via `join_slots`:
  cabeça, peito+ombros, calça, luvas+botas) × 3 builds = **12 malhas** + o MESMO esqueleto do kit. Armas novas (onda 4): +3–5 malhas
  `wpn_main_<tipo>_<pre>_<b>50` → **≤ 17 por addon**. Kit principal: **0 malha nova** (Paladino continua 195 < 200).
- **Código**: generalizar `KitModel.addon_path_for(style)` para uma lista de sufixos (`_a2`, `_a3`) via `chibi_kit.A3_STYLES`; `main_node`
  procura a arma também nas peças do addon (**[N]**, onda 4). `build_kits_a3(out, only=[...])` chamado no fim do `build_kits`.
- **Druida**: `frm_dru_w50_*` (lobo) e `frm_dru_b50_*` (urso) em `druid_sets.ACT3_FORM` (como `ACT2_FORM`); refazer `build_forms(only=["wolf","bear"])`.
- **Arquivos**: `tools/blender/<classe>_sets.py` ganha `ACT3_SETS` + função por build (ex. `build_lantern_crown`), peças com materiais
  `tint`/`tint2`/`tint_glow`; lágrima = decalque de geometria (faixa fina) em `tint_glow`. Fable faz o Blender (regra do autor).
- **Ícones**: `tools/icons/set_icons.tscn -- --only=<pre>_<b>50` (uma foto por build na cor do 50; carrega o addon como hoje faz com `_a2`)
  + `--import`; armas até a onda 4: `item_icons.tscn -- --only=leg_<c>_<b>_50_weapon`. Moldura lendária automática.
- **Revisão**: `lineup.tscn -- --strip=<classe> --set=<build> --levels=45,50 [--front] [--view=game]`; costas `--yaw=205 --frames=6`.

### 8.1 Plano de ondas
| Onda | Conteúdo | Por quê |
|---|---|---|
| **0** | `PieceEffects` + famílias §3.1 + `piece_fx` nas **24** builds (dados e efeitos todos); visual = fallback 45 na paleta 50 | efeitos são código barato e testável; o Blender é o gargalo |
| **1** ⭐ | 8 visuais: **Guardião, Executor, Sacerdote, Lobo, Caçador, Lâminas, Fogo, Invocador** + addon `_a3` das 8 classes | 1 por classe; cobre tanque/cura/dps/caster/pet; 4 deles são o grupo do começo rápido 45 (Guardião, Sacerdote, Executor, Fogo) → os bots mostram o visual cedo; Lâminas precisa de amor (balanço histórico) |
| **2** | Cruzado, Carniceiro, Iluminado, Urso, Atirador, Duelista, Gelo, Ceifador | 2ª build de cada classe |
| **3** | Templário, Punhos, Batalha, Xamã, Lanceiro, Corsário, Raio, Sombras | fecha as 24 |
| **4** | armas próprias (onde a arma é a assinatura: Templário martelo-lanterna, Executor lâmina-espelho, Lanceiro flâmulas) + formas do Druida restantes | polimento |

---

## 9. Botões (`data/balance.gd`)

| Constante | Proposta | Faixa segura | Categoria | Por quê |
|---|---|---|---|---|
| `LEG50_LEVEL` | 50 | — | gate | tier que recebe `piece_fx` |
| `LEG50_NUMBERS` | por build × peça (§5) | G_p §4.1 | curva | números só aqui |
| `LEG50_GAIN_MAX` | 0,12 | 0,08–0,14 | curva | = `APEX_GAIN_MAX` (§4.2) |
| `LEG50_CHARGE_BONUS` / `LEG50_CHARGE_CAP` | 1 / 4 | 1 / 3–4 | curva | luvas sobre o nó da teia |
| `LEG50_MANA_GUARD_CAP_ADD` | 10 | 5–10 | curva | teto 40 da Barreira |
| `LEG50_MANA_EFF_CAP` | 0,5 | 0,25–0,5 | curva | 1 MP = 1,5 de dano |
| `LEG50_ALLY_RANGE` | 8,0 m | 6–12 | feel | alcance dos efeitos de grupo |
| `LEG50_TRIGGER_ICD` | 6,0 s | 4–12 | gate | recarga padrão de `on_trigger` |
| `LEG50_BOT_TRIGGER_BIAS` | 1,25 | 1,0–1,5 | feel | viés do bot para skill-gatilho |
Valores iniciais sugeridos (a medir): cabeça `stat` 6–10 pontos de chave de notável; `legend_up` chance +6, pct +10%; `cap_up` +1; botas `cd_cut` 2 s.

---

## 10. Critérios de aceitação

Checks propostos em `tools/tests/run_tests.gd` (`--only=leg50`):
- **AC-L50-01** toda peça `leg_*_50_*` (24 builds × 6–8) tem `piece_fx` com `kind` da biblioteca §3.1 e entrada em `Balance.LEG50_NUMBERS`; nenhum número literal no catálogo (`_check_leg50_pieces`).
- **AC-L50-02** toda skill citada em `charges`/`skill_mods`/`on_trigger` existe, é da classe e da build (ou geral) (`_check_leg50_refs`).
- **AC-L50-03** por família, um teste de regra determinístico: luvas → `ChargeSystem.max_of` = 3 (sem nó) / 4 (com nó); cabeça Fogo → 40% do dano sai da mana com MP cheio; Executor botas → `cd_reset` de `ber_execute` 1× por ICD; Guardião espada → +1 Juramento no `holy_edge` (`_check_leg50_rules`).
- **AC-L50-04** `legend_wake` não dispara a si mesmo nem a assinatura em cadeia (`signature_casting`); arma de outra build = sem efeito (`_check_leg50_wake`).
- **AC-L50-05** bots 50 vestem o conjunto da própria build, 5 peças + armas do papel (`_check_leg50_bots`).
- **AC-L50-06** visual: cada estilo `<pre>_<b>50` da onda existe no addon `_a3`, kit principal < 200 malhas, addon ≤ 24; sem addon = fallback (`_check_kit_addon` estendido, `_check_leg50_visuals`).
- **AC-L50-07** save: ids iguais; save com peça 50 carrega com efeito (`TEST_SLOT`).
Sondas:
- **dps_probe** `--level=50 --set=l50` (boneco, cada build): mediana das 24 dentro de ±15% (regra atual do probe); nenhuma build com G das peças > 0,12.
- **boss_probe** grupo de 4 (`--comp` do papel, `--l50_off=<peça>|all`, 80+ lutas, 2 sementes): F-L50a dentro das faixas; contador por efeito ≥ 1 disparo por 60 s.
- **hp_probe** (Guardião, Urso, Executor, Sacerdote): vida efetiva com/sem peças; mortes a `--dmg=6` caem 6–10%.
- **combat_probe** 0 FLAG (cargas e gatilhos não travam); smoke das 8 classes sem `SCRIPT ERROR`.
Experiencial (playtest): o jogador diz o que cada peça faz depois de 10 min; a peça-assinatura lê de cima a 24 m (foto `CAM_game`).
Evidência: `production/qa/evidence/ato3p1/leg50/<build>_{front,back,game}.png`.

---

## 11. Riscos

| Risco | Prob. | Mitigação |
|---|---|---|
| Inflação de poder (7 efeitos × 24) | alta | F-L50a por peça, teto 0,12; chefes calibrados com `--l50_off=all` |
| 170 regras soltas viram dívida | média | 11 famílias parametrizadas; regra nova só em `on_trigger`/`legend_wake` |
| Gargalo de Blender (24 visuais + formas) | alta | onda 0 sem arte; 1 Fable por onda; fallback 45 |
| Porcelana branca some no chão claro / colide com o branco do Bispo e Paladino | média | destaque por build; contorno toon; revisão `--view=game` com chão de Lumeria |
| Fitas de seda poluem a leitura a 52° | média | ≤ 2 tiras por peça, presas a ombro/elmo |
| Mago imortal pela Barreira | baixa | §4.4 (40%, 1,5:1); `hp_probe` no Elementalista |
| Cargas + recarga 5 peças (24%) = spam | média | `SKILL_CHARGE_RECHARGE_MULT` 1,3 continua; medir no `combat_probe` e `dps_probe` |

---

## 12. Perguntas abertas

1. **Arma: despertar (proposto) ou trocar o `legend` no 50?** Despertar preserva ganchos e identidade; trocar dá surpresa maior.
2. **Mistura entre builds**: permitir (proposto) ou exigir a arma da build para TODA peça (regra da face do Ápice)?
3. **5 peças "Ressonância"** (efeitos das peças +25% com o conjunto completo)? Proposto: **não** na parte 1 (já há 48%/20%/24%).
4. Tabela própria `ACT3_VISUALS` ou nível 50 dentro de `ACT2_VISUALS` (ordem de `ACT2_SET_LEVELS`)? Proposto: dentro (menos código), com estilo próprio.
5. Ordem da onda 1 — trocar Lobo por Urso (tanque) ou Lâminas por Duelista?
6. Nomes finais dos 24 conjuntos e das armas "Despertas": narrative-director.

---

## 13. Adendo x implementado (onda 0) — para revisão do usuário

Levantado no WP11 (2026-11-23) comparando as fichas do §5 com `GearCatalog.LEG50` + `Balance.LEG50_NUMBERS` + `PieceEffects`.
Ganho medido da onda 0: **0,118** (teto F-L50b 0,12, sem folga). O agente da onda 0 não deixou o motivo de cada troca: a coluna
"motivo" é o **provável** (lido do código e do orçamento), a confirmar. Decisão do usuário por linha: manter o implementado ou voltar ao adendo.

**Trocas de efeito (o jogador sente diferente):**

| # | Build · peça | Adendo (§5) | Implementado | Motivo provável |
|---|---|---|---|---|
| 1 | Guardião · cabeça | Juramento +`x` carga e dura +`y` s | Juramento +2 cargas (sem duração) | Juramento não tem teto de duração para o `cap_up`; só a carga entrou |
| 2 | Guardião · escudo | Determinação cheia: +`x`% DEF aos aliados a 8 m | Determinação cheia: barreira de 3% da vida em você e nos aliados a 8 m, 1×/12 s | reusa a ação `barrier` do `on_trigger` (sem buff de grupo novo); efeito de grupo visível |
| 3 | Cruzado · calça | +`x`% no **último** golpe da sequência (`strikes.weights`) | +5% no dano do Golpe do Cruzado inteiro (`skill_dmg`) | mexer em `weights` muda o ritmo/hit-stop calibrado da sequência; `skill_dmg` é a chave pronta |
| 4 | Cruzado · botas | alvo atordoado fica Julgado (`apex_judged`) por `x` s | atordoado pelo Julgamento leva +5% de dano por 3 s (`curse` próprio) | não ativar a regra do Ápice fora do Ápice (FusionEffects lê o conjunto) |
| 5 | Punhos · botas | Punho Vingativo também dispara ao esquivar (1×/`x` s) | esquivar dá +1 Fúria do Punho (1×/4 s) | disparar o contra-ataque na esquiva dobrava o dano da cauda AGI; a Fúria é o recurso que já existe |
| 6 | Sacerdote · arma | Égide ao romper cura `x`% da vida do protegido | Égide em aliado abaixo de 35% da vida vale +100% | "ao romper" pedia gancho novo no fim do escudo; o `low` usa o valor da Égide na hora de pôr |
| 7 | Inquisidor · botas | Exorcismo atinge +1 alvo | Exorcismo +12% de dano | +1 alvo em área de Inquisidor estourava o ganho em grupo de lixo; dano direto é medível no chefe |
| 8 | Inquisidor · arma | a Radiância do Castigo da arma conta ×`x` | o Castigo lançado pela arma bate +25% | Radiância já tem teto/cauda própria (`radiance_cap` na cabeça); multiplicador de dano é o caminho do `legend_wake` `power` |
| 9 | Batalha · escudo | Determinação cheia renova o Hino de Batalha | Determinação cheia: cura 4% da vida em você e nos aliados a 8 m, 1×/12 s | renovar um buff longo (60 s, `BUFF_KEEP_S`) não muda nada; cura de grupo tem efeito real |
| 10 | Lâminas · botas | depois de Sumir, a 1ª facada é furtiva (`FusionEffects.ghost`) | Sumir devolve 10% de MP e zera o Dardo Venenoso | `ghost` é regra do Ápice; MP + recarga é a dor real da build (falta de mana) |
| 11 | Corsário · mão sec. | Tiro Entre os Olhos **com Bravata cheia** ricocheteia 1× | Tiro Entre os Olhos sempre ricocheteia com 40% | o gatilho `hit:<skill>` não lê a Bravata; a condição saiu e o número caiu para 40% |
| 12 | Gelo · arma | Coração de Gelo: recarga −`x` s; a Nova deixa a lentidão +`y` s | recarga −4 s; a Nova bate +25% | lentidão de gelo está fora do retorno decrescente (decisão de 2026-11-23): +duração = controle grátis em chefe |
| 13 | Raio · botas | Passo Relampejante eletrifica quem cruzar (`FUSION_SHOCK_TIME`) | Passo Relampejante que acerta tira 1 s da Corrente Elétrica | eletrificar é regra do Ápice; corte de recarga usa `on_trigger` `cd_cut` |
| 14 | Pestilento · peito | Pandemia espalha +1 maldição | Pandemia dura +2 s | +1 maldição espalhada multiplicava em grupo de lixo (orçamento 0,12) |
| 15 | Guardião Verde, Ceifador, Invocador · botas | (sem número / teto 5 alvos / ergue esqueleto "de graça") | Urro: barreira 5% sem recarga; Giro da Morte cura 1% por inimigo **sem teto de 5**; Oferenda ergue esqueleto por 12 s | ajustes de número; ~~o teto de 5 do Ceifador não foi implementado~~ **CORRIGIDO 2026-11-23**: `max_hits` (= `LEG50_NUMBERS.ceifador.boots.n` 5) no `on_trigger` `hit:<skill>`, 5 inimigos distintos por lançamento, lançar de novo zera (`PieceEffects`; check `_check_leg50_spin_cap`). Usuário decidiu manter os demais efeitos implementados. |

**Ajustes menores (mesmo efeito, condição ou unidade diferente):**

| Build · peça | Adendo | Implementado |
|---|---|---|
| Carniceiro · botas | Investida que acerta **enche** o Frenesi | +5 Frenesi, 1×/6 s |
| Executor · botas | abater alvo **abaixo do limiar** zera Executar, 1×/`x` s | qualquer abate zera Executar, 1×/15 s |
| Sacerdote · botas | bloquear tira 1 debuff **do aliado curado** pela Graça | tira 1 debuff do aliado mais ferido, 1×/6 s |
| Fera · botas | Bote **saindo de Espreitar** sangra com 100% | qualquer Bote sangra com 100%, 1×/4 s |
| Lanceiro · botas | Salto em alvo **com feridas cheias** renova | qualquer acerto do Salto renova as feridas |
| Duelista · calça | `cap_up` riposte_window | `skill_mods` da Guarda do Duelista (+0,25 s de janela): mesmo efeito |
| Lâminas · arma, Fogo · arma | devolve `x` **MP** | devolve `x`**% do MP** (2%) — escala com o nível |

As demais peças seguem o §5 (números em `LEG50_NUMBERS`).
