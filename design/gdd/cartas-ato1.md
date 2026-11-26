# Cartas de Monstro — Ato I (níveis 1-30), 1ª leva

> Apêndice de `design/gdd/cartas.md`. Status: **APROVADA pelo usuário** (2026-11-26, lista como está; números ajustáveis no `balance.gd`).
> Números: SÓ em `data/balance.gd` (`CARD_COMMON`, `CARD_CORE`, `CARD_GROUP_BONUS`); esta tabela mostra os valores na data
> em que foi escrita. Dados das cartas: `data/catalog/cards_catalog.gd`.

## Resumo

| | Quantas |
|---|---|
| Cartas comuns | 75 (25 grupos de 3) |
| Cartas de núcleo de monstro comum | 6 |
| Cartas de núcleo de chefe | 28 (os Ecos de chefe dão a carta do chefe original) |
| **Total** | **109** |

São mais que as ~90 da estimativa porque §3.1 manda dar carta a **todo** monstro com XP > 0 do Ato I (81 comuns + 28 chefes).

**Faixa** (tier) de uma carta = nível do monstro: T1 ≤ 10, T2 11-20, T3 21-30 (`Balance.CARD_TIER_LEVELS` = [10, 20]).
O número de cada efeito vem da tabela da faixa, não da carta.

## Efeitos comuns (pequenos) — `Balance.CARD_COMMON[efeito] = [T1, T2, T3]`

| Efeito | Encaixe típico | T1 | T2 | T3 | Gancho |
|---|---|---|---|---|---|
| `family_dmg` +% dano contra a família | arma | 6 | 8 | 10 | **novo** (CardSystem.damage_mult) |
| `family_def` −% dano recebido da família | mão sec. | 5 | 7 | 9 | **novo** (CardSystem.damage_mult) |
| `proc_poison` % de chance de envenenar ao acertar (15% do ATK/s por 4 s) | arma | 6 | 8 | 10 | **novo** (CardSystem.on_hit) |
| `proc_slow` % de chance de lentidão 25% por 2 s | arma | 8 | 10 | 12 | **novo** (CardSystem.on_hit) |
| `crit` +% de crítico | arma | 1 | 1,5 | 2 | stat existente |
| `thorns` % do dano corpo a corpo devolvido | mão sec. | 4 | 6 | 8 | stat existente |
| `block` +% de bloqueio (só com escudo) | mão sec. | 2 | 3 | 4 | stat existente |
| `cc_resist_pct` −% duração de controle | cabeça | 8 | 10 | 12 | stat existente |
| `mp_regen_combat` % da mana/s em combate | cabeça | 0,2 | 0,3 | 0,4 | stat existente |
| `xp_pct` +% XP de abate | cabeça/acess. | 3 | 4 | 5 | **novo** (LootSystem, por quem divide) |
| `hp_pct` +% vida | peito | 2 | 3 | 4 | stat existente |
| `def_pct` +% DEF | peito | 3 | 4 | 5 | stat existente |
| `heal_taken_pct` +% cura recebida | peito | 4 | 5 | 6 | stat existente |
| `speed_pct` +% velocidade | botas | 3 | 4 | 5 | stat existente |
| `dash_pct` +% distância do dash | botas | 8 | 10 | 12 | **novo** (WorldSim.dash_params) |
| `evasion` +% esquiva | botas | 1 | 1,5 | 2 | stat existente |
| `gold_pct` +% ouro de monstro | acessório | 6 | 8 | 10 | **novo** (LootSystem pickup/split_gold) |
| `mp_on_kill` % da mana por abate | acessório | 2 | 3 | 4 | stat existente |
| `lifesteal` % roubo de vida | acessório | 0,5 | 0,75 | 1 | stat existente |

## Efeitos de núcleo (fortes) — `Balance.CARD_CORE[efeito] = [T1, T2, T3]`

| Efeito | T1 | T2 | T3 | Gancho |
|---|---|---|---|---|
| `dr_pct` −% todo dano recebido | 6 | 8 | 10 | stat (dentro do `DR_CAP`) |
| `kill_heal` abate cura % da vida máxima | 2 | 3 | 4 | **novo** (CardSystem.on_kill) |
| `proc_stun` % de chance de atordoar 0,8 s ao acertar | 3 | 4 | 5 | **novo** (CardSystem.on_hit) |
| `hp_pct` | 5 | 7 | 9 | stat |
| `def_pct` | 8 | 10 | 12 | stat |
| `atk_pct` / `matk_pct` | 4 | 5 | 6 | stat |
| `lifesteal` | 2 | 3 | 4 | stat |
| `cdr` | 4 | 6 | 8 | stat |
| `crit` | 3 | 4 | 5 | stat |
| `crit_dmg_pct` | 10 | 15 | 20 | stat |
| `aspd_pct` | 5 | 7 | 9 | stat |
| `dot_pct` | 8 | 12 | 16 | stat |
| `low_dr` | 10 | 15 | 20 | stat |
| `low_leech` | 4 | 5 | 6 | stat |
| `cc_resist_pct` | 20 | 25 | 30 | stat |
| `heal_pct` / `heal_taken_pct` | 5 / 8 | 7 / 10 | 9 / 12 | stat |
| `buff_pct` | 10 | 15 | 20 | stat |
| `summon_time_pct` / `pet_pct` | 10 / 8 | 15 / 12 | 20 / 16 | stat |
| `mp_cost_pct` / `mp_regen_combat` | 6 / 0,6 | 9 / 0,8 | 12 / 1,0 | stat |
| `frost_pct` / `fire_pct` | 6 | 8 | 10 | stat |
| `thorns` / `block` | 10 / 4 | 15 / 6 | 20 / 8 | stat |
| `speed_pct` / `evasion` | 6 / 3 | 8 / 4 | 10 / 5 | stat |
| `threat_pct` / `backstab` | 15 / 8 | 20 / 10 | 25 / 12 | stat |
| `gold_pct` | 15 | 20 | 25 | novo (o mesmo do comum) |

## Famílias (`CardsCatalog.FAMILY`, para `family_dmg`/`family_def`)

`beast` (lobos, ursos, javalis, caranguejos, linces, grifos, sapos, morcegos, corvos), `insect` (vespas, colmeia, aranhas,
sanguessuga, larva), `undead` (mortos, ossos, espectros, carniçais, Sem Senhor, Juramentados, Cidadela, Borrão de Tinta),
`humanoid` (bandidos, contrabandista, xamãs, adeptos, copista), `elf` (élficos, Tratador), `construct` (golens, slimes,
Guardião do Registro), `plant` (trents, ents, mudas). Chefes também têm família (contam como alvo).

## Cartas comuns por grupo (G = grupo; bônus de 2 e de 3 somam)

| Grupo | Monstro (id) | Encaixe | Efeito | T | Valor |
|---|---|---|---|---|---|
| **G01 Campos de Aldara** — 2: +2% vida · 3: +5% mana | slime | acessório | mp_on_kill | 1 | 2 |
| | slime_blue | cabeça | mp_regen_combat | 1 | 0,2 |
| | boar | peito | hp_pct | 1 | 2 |
| **G02 Praia dos Caranguejos** — 2: +3% DEF · 3: espinhos 6% | crab | mão sec. | family_def beast | 1 | 5 |
| | crab_sand | botas | speed_pct | 1 | 3 |
| | crab_hermit | peito | def_pct | 1 | 3 |
| **G03 Enxame do Vale** — 2: +1% crítico · 3: +8% dano no tempo | wasp | arma | proc_poison | 1 | 6 |
| | wasp_soldier | cabeça | cc_resist_pct | 1 | 8 |
| | hive | acessório | gold_pct | 1 | 6 |
| **G04 Ursos da Mata** — 2: +3% vida · 3: −8% dano com pouca vida | bear_cub | botas | dash_pct | 1 | 8 |
| | bear | peito | hp_pct | 1 | 2 |
| | grove_bear | arma | family_dmg beast | 2 | 8 |
| **G05 Matilha** — 2: +3% velocidade · 3: +5% vel. de ataque | wolf | botas | speed_pct | 1 | 3 |
| | grove_wolf | arma | crit | 2 | 1,5 |
| | rot_wolf | acessório | xp_pct | 3 | 5 |
| **G06 Mortos da Catacumba** — 2: +4% dano em mortos-vivos · 3: −10% controle | zombie | peito | heal_taken_pct | 1 | 4 |
| | bone_recruit | mão sec. | family_def undead | 1 | 5 |
| | bone_archer | arma | family_dmg undead | 1 | 6 |
| **G07 Espectros** — 2: +1% esquiva · 3: −6% custo de mana | wraith | cabeça | mp_regen_combat | 2 | 0,3 |
| | ghost | botas | evasion | 3 | 2 |
| | rest_thaw_wraith | arma | proc_slow | 3 | 12 |
| **G08 Golens da Pedreira** — 2: +3% DEF · 3: −3% dano recebido | golem_moss | peito | def_pct | 2 | 4 |
| | golem_stone | mão sec. | thorns | 2 | 6 |
| | golem_shard | arma | family_dmg construct | 2 | 8 |
| **G09 Bando da Estrada** — 2: +5% ouro · 3: +8% dano pelas costas | bandit_footpad | botas | dash_pct | 2 | 10 |
| | bandit_thief | acessório | gold_pct | 2 | 8 |
| | bandit_archer | arma | crit | 2 | 1,5 |
| **G10 Fora da Lei** — 2: +2% ATK e MATK · 3: +8% dano crítico | bandit | arma | family_dmg humanoid | 2 | 8 |
| | bandit_outlaw | cabeça | cc_resist_pct | 2 | 10 |
| | marsh_smuggler | acessório | xp_pct | 2 | 4 |
| **G11 Aranhas** — 2: +5% dano no tempo · 3: golpe físico deixa 15% de lentidão | spider | arma | proc_poison | 2 | 8 |
| | marsh_spider | botas | evasion | 2 | 1,5 |
| | sap_spider | mão sec. | family_def insect | 2 | 7 |
| **G12 Bosque Desperto** — 2: +5% cura recebida · 3: +4% vida | trent_young | peito | hp_pct | 2 | 3 |
| | ent | mão sec. | thorns | 2 | 6 |
| | trent | cabeça | cc_resist_pct | 2 | 10 |
| **G13 Feras Élficas** — 2: +8% companheiro · 3: +10% dash | elf_lynx | botas | speed_pct | 2 | 4 |
| | griffin | arma | crit | 2 | 1,5 |
| | griffin_raider | acessório | mp_on_kill | 2 | 3 |
| **G14 Brejo** — 2: +0,5% roubo de vida · 3: +5% cura | marsh_leech | acessório | lifesteal | 2 | 0,75 |
| | bog_toad | peito | heal_taken_pct | 2 | 5 |
| | web_weaver | arma | proc_slow | 2 | 10 |
| **G15 Círculo do Bosque** — 2: +10% duração das invocações · 3: +5% cura | shaman_shifter | cabeça | mp_regen_combat | 2 | 0,3 |
| | shaman_caller | acessório | mp_on_kill | 2 | 3 |
| | elf_tender | peito | hp_pct | 2 | 3 |
| **G16 Batedores Élficos** — 2: −4% dano de elfos · 3: +3% ATK e MATK | elf_raider | arma | family_dmg elf | 2 | 8 |
| | elf_raider_archer | mão sec. | family_def elf | 2 | 7 |
| | elf_raider_mage | cabeça | cc_resist_pct | 2 | 10 |
| **G17 Guarda da Árvore** — 2: +1% crítico · 3: −3% dano recebido | elf_archer | arma | crit | 2 | 1,5 |
| | elf_warrior | peito | def_pct | 2 | 4 |
| | elf_sergeant | mão sec. | block | 2 | 3 |
| **G18 Carniçais** — 2: +0,5% roubo de vida · 3: +4% roubo com pouca vida | ghoul | arma | proc_slow | 2 | 10 |
| | rot_ghoul | acessório | lifesteal | 3 | 1 |
| | rest_ghoul | cabeça | cc_resist_pct | 3 | 12 |
| **G19 Podridão** — 2: +3% vida · 3: +10% dano no tempo | larva | acessório | xp_pct | 2 | 4 |
| | rot_zombie | peito | heal_taken_pct | 3 | 6 |
| | rot_bear | mão sec. | family_def undead | 3 | 9 |
| **G20 Legião de Ossos** — 2: +3% DEF · 3: +3% bloqueio | skel_archer | arma | family_dmg undead | 3 | 10 |
| | skeleton | peito | def_pct | 3 | 5 |
| | skel_guard | mão sec. | block | 3 | 4 |
| **G21 Desgarrados** — 2: −3% recarga · 3: +10% dano crítico | rest_bones | botas | dash_pct | 3 | 12 |
| | rest_bone_archer | arma | crit | 3 | 2 |
| | rest_lost_adept | cabeça | mp_regen_combat | 3 | 0,4 |
| **G22 Culto do Lich** — 2: +3% MATK · 3: −8% custo de mana | cultist | cabeça | cc_resist_pct | 3 | 12 |
| | citadel_adept | acessório | mp_on_kill | 3 | 4 |
| | citadel_horror | mão sec. | family_def undead | 3 | 9 |
| **G23 Coveiros** — 2: +8% ouro · 3: +5% XP | night_digger | botas | speed_pct | 3 | 5 |
| | grave_hauler | peito | hp_pct | 3 | 4 |
| | carrion_crow | acessório | gold_pct | 3 | 10 |
| **G24 Juramentados** — 2: +1,5% esquiva · 3: −3% dano recebido | oath_sworn | peito | def_pct | 3 | 5 |
| | oath_archer | arma | family_dmg undead | 3 | 10 |
| | vel_shade | botas | evasion | 3 | 2 |
| **G25 Arquivo de Vel'Thar** — 2: −3% recarga · 3: +3% ATK e MATK | archive_copyist | cabeça | xp_pct | 3 | 5 |
| | archive_warden | mão sec. | family_def construct | 3 | 9 |
| | ink_wraith | arma | proc_slow | 3 | 12 |

(T de cada carta = faixa do nível do monstro; ex.: Grifo Jovem não tem carta, é lacaio.)

## Cartas de núcleo

| Monstro (id) | Chefe? | Encaixe | Efeito | T | Valor |
|---|---|---|---|---|---|
| boar_brute | campo | peito | hp_pct | 1 | 5 |
| crab_king | campo | mão sec. | thorns | 1 | 10 |
| bear_mother | campo | peito | low_dr | 1 | 10 |
| boar_king | campo | arma | atk_pct | 1 | 4 |
| bone_captain | masmorra | cabeça | cc_resist_pct | 1 | 20 |
| slime_king | masmorra | acessório | kill_heal | 2 | 3 |
| wailing_widow | masmorra | arma | dot_pct | 2 | 12 |
| count_vargo | masmorra | arma | lifesteal | 2 | 3 |
| golem_ancient | masmorra | peito | dr_pct | 2 | 8 |
| crystal_warden | masmorra | cabeça | crit | 2 | 4 |
| quarry_heart | masmorra | mão sec. | block | 2 | 6 |
| bog_mother | campo | acessório | heal_taken_pct | 2 | 10 |
| boss_archdruid | campo | cabeça | summon_time_pct | 2 | 15 |
| boss_sap_mother | masmorra | acessório | heal_pct | 2 | 7 |
| spider_queen | masmorra | arma | proc_stun | 2 | 4 |
| elf_captain_hunter | campo | botas | speed_pct | 2 | 8 |
| elf_captain_sky | campo | mão sec. | pet_pct | 2 | 12 |
| elf_captain_sap | campo | cabeça | mp_cost_pct | 3 | 12 |
| elf_king | masmorra | arma | crit_dmg_pct | 3 | 20 |
| bandit_chief | campo | acessório | gold_pct | 3 | 25 |
| ghoul_giant (+ Eco) | fortaleza | peito | low_leech | 3 | 6 |
| death_knight (+ Eco) | fortaleza | mão sec. | threat_pct | 3 | 25 |
| fallen_bearer | campo | cabeça | buff_pct | 3 | 20 |
| frost_mage (+ Eco) | fortaleza | arma | frost_pct | 3 | 10 |
| crypt_lord | masmorra | acessório | mp_regen_combat | 3 | 1,0 |
| boss_azhar_scribe | masmorra | cabeça | cdr | 3 | 8 |
| lich_king | cidadela | arma | matk_pct | 3 | 6 |
| dragonling | masmorra | acessório | fire_pct | 3 | 10 |
| sap_sprout | — | botas | evasion | 2 | 4 |
| elf_warden | — | peito | aspd_pct | 2 | 7 |
| rest_bear | — | peito | hp_pct | 3 | 9 |
| tower_bat | — | arma | backstab | 3 | 12 |
| golem | — | peito | def_pct | 3 | 12 |
| citadel_knight | — | mão sec. | dr_pct | 3 | 10 |

## Ganchos novos (código)

1. `family_dmg` / `family_def` — `CardSystem.damage_mult(attacker, target)` em `WorldSim._deal_damage`.
2. `proc_poison` / `proc_slow` / `proc_stun` — `CardSystem.on_hit(sim, attacker, target, kind)` em `_deal_damage` (golpe direto).
3. `kill_heal` — `CardSystem.on_kill(sim, sharers, mob)` no abate.
4. `xp_pct` — multiplicador da XP de abate por quem divide (`LootSystem.on_monster_killed`).
5. `gold_pct` — ouro de monstro (`LootSystem.pickup` do ouro e `split_gold`).
6. `dash_pct` — `WorldSim.dash_params` (distância).

Todo o resto passa por `Stats.STAT_KEYS` como um bônus no formato de buff (`SimEntity.recompute_stats`).
