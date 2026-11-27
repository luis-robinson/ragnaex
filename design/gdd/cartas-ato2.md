# Cartas de Monstro — Ato II (níveis 30-45), 2ª leva

> Apêndice de `design/gdd/cartas.md` (mesmo formato de `cartas-ato1.md`). Status: **IMPLEMENTADA** (2026-11-27; `CARD_ELITE_ROLE_MULT` ×10 por decisão do usuário depois do `card_probe`, medir em grupo antes de subir). Antes: **APROVADA pelo usuário** (2026-11-27, as 4 recomendações de "Perguntas para o usuário" aceitas: 2 faixas T4/T5, ganchos H1-H3 com chefe no H3, multiplicador ~5 nos núcleos de elite + medir com card_probe, família `horde`); antes: aguarda o usuário
> (perguntas no fim). Pedido do usuário: começar o Ato II (decisão 3 de §9 dizia "depois do teste de jogo").
> Números: SÓ em `data/balance.gd` (`CARD_COMMON`, `CARD_CORE`, `CARD_GROUP_BONUS`, `CARD_TIER_LEVELS`); esta tabela mostra os
> valores propostos. Dados das cartas: `data/catalog/cards_catalog.gd` (`COMMONS`, `CORES`, `FAMILY`). Nada implementado.

## Resumo

| | Quantas |
|---|---|
| Cartas comuns | 18 (6 grupos de 3, G26-G31) |
| Cartas de núcleo de monstro comum | 6 (4 elites da Horda + Guerreiro Orc + Brutamontes) |
| Cartas de núcleo de chefe | 13 (11 chefes de campo/masmorra/fortaleza/cidadela/raide + 2 chefes de mundo) |
| **Total** | **37** |

Quem tem carta (§3.1): todo monstro com XP > 0 que tem spawner (ou patrulha/investida) em `field_coast`, `city_port`, `dg_goblin`,
`field_steppe`, `fort_trolls`, `fort_fire`, `fort_war`, `field_kharzun`, `dg_slayers`, `kharzun_citadel`, mais os chefes de mundo
da faixa (`WORLD_BOSSES`: `war_rhino` 30-40, `iron_wolf_king` 40-45). Ficam de fora (0 XP ou objeto): `naga_spawn`, `goblin_rabble`,
`troll_runt`, `orc_marksman`, `orc_vanguard`, `dire_pup`, `shadow_apprentice`, `ulgra_rider`, `stone_shaman`, `forge_golemling`,
`throne_guard`, `banner_wolf/stone/forge`, `shazka_decoy`, `wb_platform_warrior`, `wb_iron_wolf`, monstros de evento de estrada
(`wolf_runner`, `wolf_racer`...) e os objetos do GvG. O Ato II não tem Ecos de chefe. Reis (`elite_of`) dão a carta da base × `CARD_ELITE_MULT`, como no Ato I.

São 24 monstros comuns elegíveis. Seis grupos de 3 usam 18; os outros 6 viram núcleo (no Ato I foram 81 → 75 + 6, a mesma regra).

## Faixas e regra de escala (Ato I → Ato II)

**Faixas novas**: `CARD_TIER_LEVELS = [10, 20, 30, 37]` → T1 ≤ 10, T2 11-20, T3 21-30, **T4 31-37**, **T5 38-45**. Toda tabela
`CARD_COMMON`/`CARD_CORE` passa a ter 5 valores (o `CardsCatalog.tier_of` já conta quantos limites o nível passa; só as listas crescem).
Nenhuma carta do Ato I muda (T1-T3 iguais). O Ato III ganha T6 depois.

O Lanceiro Goblin (nível 30) fica em T3: a faixa sai do nível do monstro, sem exceção (o Ato I também mistura faixas num grupo).

**Regra de escala** (uma só, para todo efeito): o Ato I sobe cada efeito em passos iguais (`[a, a+s, a+2s]`). O Ato II continua a
mesma progressão aritmética:

```
v(e, T4) = v(e, T3) + k(e) × s(e)
v(e, T5) = v(e, T3) + 2 × k(e) × s(e)
s(e) = v(e, T3) − v(e, T2)                      (o passo do Ato I)
k(e) = 1    efeito sem teto (dano, vida, cura, ouro, XP, dash, procs de dano)
     = 0,5  efeito com teto ou de controle (dr_pct, low_dr, cdr, cc_resist_pct, evasion, block, family_def,
            ranged_def, speed_pct, mp_cost_pct, proc_stun)
```

| Símbolo | Tipo | Faixa | Descrição |
|---|---|---|---|
| `v(e, T3)` | float | 0,2-30 | valor do efeito `e` na faixa T3 (hoje no `balance.gd`) |
| `v(e, T2)` | float | 0,3-25 | valor na faixa T2 |
| `s(e)` | float | 0,1-5 | passo do Ato I entre faixas |
| `k(e)` | float | {0,5; 1} | 1 = passo cheio; 0,5 = meio passo (efeito que bate em teto ou é controle) |
| `v(e, T4)`, `v(e, T5)` | float | 0,5-35 | valores novos (resultado) |

**Por que meio passo nos efeitos com teto**: eles batem em `DR_CAP` (40), `CDR_CAP` (25), `CC_RESIST_CAP` (50), `EVASION_CAP` (45),
`MP_COST_CAP` (30) e `CARD_FAMILY_DEF_CAP` (25), e no Ato II as ascensões e os Ápices já empurram vários deles para perto do teto.
Passo cheio faria duas cartas de núcleo (`CARD_CORE_MAX` = 2) chegarem a ~1/3 do teto sozinhas.

**Faixa de saída**: valores sempre positivos e limitados (a progressão é finita: 2 faixas a mais). Maior valor de toda a tabela:
`gold_pct` núcleo T5 = 35; maior defensivo: `low_dr` núcleo T5 = 25 (abaixo do `DR_CAP` 40). Pior caso com 2 núcleos defensivos:
`dr_pct` 12 + `low_dr` 25 só com pouca vida, 12 o resto do tempo.

**Exemplo**: `dr_pct` (núcleo) = [6, 8, 10]: s = 2, k = 0,5 → T4 = 10 + 1 = 11, T5 = 10 + 2 = 12. `family_dmg` (comum) = [6, 8, 10]:
s = 2, k = 1 → T4 = 12, T5 = 14. `crit_dmg_pct` (núcleo) = [10, 15, 20]: s = 5 → T4 = 25, T5 = 30.

**O que não se repete do Ato II** (pedido: não duplicar ascensões nem Ápices): nenhuma carta usa efeito de skill ou de build
(cargas, Juramento, Radiância, montado, evolução do elemental, Empunhadura de Titã, Coro, Ímpeto, aparar, Execução, fusões, regras de 5
peças do Ápice) nem os stats de talento que só existem por uma build (`def_atk_pct`, `block_reflect`, `guard_crit`, `taunt_dmg_pct`,
`phys_mend`, `summon_guard`, `ally_guard`, `overheal_share`, `mana_guard`, `crit_leech`, `low_hp_atk`, `execute_pct`, `titan_relief`,
`turret_max`, `shadow_*`, `radiance*`, `trap_max`). Também fica de fora `drop_pct` (é da Poção da Fortuna e aumentaria as próprias cartas).
As cartas continuam stats gerais e ganchos de carta; a única chave de stat nova na tabela é `storm_pct` (o trio de elementos: o Ato I já tem fogo e gelo).

## Efeitos comuns (pequenos) — `Balance.CARD_COMMON[efeito] = [T1, T2, T3, T4, T5]`

| Efeito | Encaixe típico | T1 | T2 | T3 | **T4** | **T5** | k | Gancho |
|---|---|---|---|---|---|---|---|---|
| `family_dmg` | arma | 6 | 8 | 10 | 12 | 14 | 1 | existente |
| `family_def` | mão sec. | 5 | 7 | 9 | 10 | 11 | 0,5 | existente |
| `ranged_def` −% dano recebido de monstro à distância | mão sec. | 5 | 7 | 9 | 10 | 11 | 0,5 | **NOVO** (H2) |
| `proc_poison` | arma | 6 | 8 | 10 | 12 | 14 | 1 | existente |
| `proc_slow` | arma | 8 | 10 | 12 | 14 | 16 | 1 | existente |
| `regen_cut` golpe direto corta a regeneração do alvo por N s | arma | 1 | 1,5 | 2 | 2,5 | 3 | 1 | **NOVO** (H1) |
| `crit` | arma | 1 | 1,5 | 2 | 2,5 | 3 | 1 | stat |
| `thorns` | mão sec. | 4 | 6 | 8 | 10 | 12 | 1 | stat |
| `block` | mão sec. | 2 | 3 | 4 | 4,5 | 5 | 0,5 | stat |
| `cc_resist_pct` | cabeça | 8 | 10 | 12 | 13 | 14 | 0,5 | stat |
| `mp_regen_combat` | cabeça | 0,2 | 0,3 | 0,4 | 0,5 | 0,6 | 1 | stat |
| `xp_pct` | cabeça/acess. | 3 | 4 | 5 | 6 | 7 | 1 | stat |
| `hp_pct` | peito | 2 | 3 | 4 | 5 | 6 | 1 | stat |
| `def_pct` | peito | 3 | 4 | 5 | 6 | 7 | 1 | stat |
| `heal_taken_pct` | peito | 4 | 5 | 6 | 7 | 8 | 1 | stat |
| `speed_pct` | botas | 3 | 4 | 5 | 5,5 | 6 | 0,5 | stat |
| `dash_pct` | botas | 8 | 10 | 12 | 14 | 16 | 1 | existente |
| `evasion` | botas | 1 | 1,5 | 2 | 2,25 | 2,5 | 0,5 | stat |
| `gold_pct` | acessório | 6 | 8 | 10 | 12 | 14 | 1 | existente |
| `mp_on_kill` | acessório | 2 | 3 | 4 | 5 | 6 | 1 | stat |
| `lifesteal` | acessório | 0,5 | 0,75 | 1 | 1,25 | 1,5 | 1 | stat |

(`ranged_def` e `regen_cut` têm T1-T3 preenchidos só para a tabela ficar completa; nenhuma carta do Ato I os usa.)

## Efeitos de núcleo (fortes) — `Balance.CARD_CORE[efeito] = [T1, T2, T3, T4, T5]`

| Efeito | T1 | T2 | T3 | **T4** | **T5** | k | Gancho |
|---|---|---|---|---|---|---|---|
| `dr_pct` | 6 | 8 | 10 | 11 | 12 | 0,5 | stat (dentro do `DR_CAP`) |
| `kill_heal` | 2 | 3 | 4 | 5 | 6 | 1 | existente |
| `proc_stun` | 3 | 4 | 5 | 5,5 | 6 | 0,5 | existente |
| `hp_pct` | 5 | 7 | 9 | 11 | 13 | 1 | stat |
| `def_pct` | 8 | 10 | 12 | 14 | 16 | 1 | stat |
| `atk_pct` / `matk_pct` | 4 | 5 | 6 | 7 | 8 | 1 | stat |
| `lifesteal` | 2 | 3 | 4 | 5 | 6 | 1 | stat |
| `cdr` | 4 | 6 | 8 | 9 | 10 | 0,5 | stat |
| `crit` | 3 | 4 | 5 | 6 | 7 | 1 | stat |
| `crit_dmg_pct` | 10 | 15 | 20 | 25 | 30 | 1 | stat |
| `aspd_pct` | 5 | 7 | 9 | 11 | 13 | 1 | stat |
| `dot_pct` | 8 | 12 | 16 | 20 | 24 | 1 | stat |
| `low_dr` | 10 | 15 | 20 | 22,5 | 25 | 0,5 | stat |
| `low_leech` | 4 | 5 | 6 | 7 | 8 | 1 | stat |
| `cc_resist_pct` | 20 | 25 | 30 | 32,5 | 35 | 0,5 | stat |
| `heal_pct` / `heal_taken_pct` | 5 / 8 | 7 / 10 | 9 / 12 | 11 / 14 | 13 / 16 | 1 | stat |
| `buff_pct` | 10 | 15 | 20 | 25 | 30 | 1 | stat |
| `summon_time_pct` / `pet_pct` | 10 / 8 | 15 / 12 | 20 / 16 | 25 / 20 | 30 / 24 | 1 | stat |
| `mp_cost_pct` / `mp_regen_combat` | 6 / 0,6 | 9 / 0,8 | 12 / 1,0 | 13,5 / 1,2 | 15 / 1,4 | 0,5 / 1 | stat |
| `frost_pct` / `fire_pct` / **`storm_pct`** | 6 | 8 | 10 | 12 | 14 | 1 | stat (`storm_pct` entra na tabela; já é stat, teto `ELEMENT_CAP`) |
| `thorns` / `block` | 10 / 4 | 15 / 6 | 20 / 8 | 25 / 9 | 30 / 10 | 1 / 0,5 | stat |
| `speed_pct` / `evasion` | 6 / 3 | 8 / 4 | 10 / 5 | 11 / 5,5 | 12 / 6 | 0,5 | stat |
| `threat_pct` / `backstab` | 15 / 8 | 20 / 10 | 25 / 12 | 30 / 14 | 35 / 16 | 1 | stat |
| `gold_pct` | 15 | 20 | 25 | 30 | 35 | 1 | existente |
| `leader_dmg` +% dano em líder, elite e chefe | 8 | 10 | 12 | 14 | 16 | 1 | **NOVO** (H3) |

## Famílias (`CardsCatalog.FAMILY`)

Uma família **nova**, `horde` ("a Horda"): é só dado no catálogo (`FAMILY` + `FAMILY_NAMES`), não é gancho novo.

- `horde`: goblin_lancer, goblin_impaler, goblin_agitator, wolf_rider, wolf_raider, dire_wolf_rider, orc_recruit, orc_warrior,
  orc_warlord, troll_whelp, troll, troll_thrower, troll_brute, orc_archer, orc_crossbow, orc_fire_archer, goblin_assassin,
  goblin_slayer, clan_guard; chefes boss_agitator_lord, boss_troll_king, boss_crossbow_master, boss_ghar, boss_shazka, boss_ulgra,
  boss_gorbash, boss_kragmar, boss_durgash.
- `beast`: dire_wolf, lava_salamander, boss_dire_mother, war_rhino, iron_wolf_king (o rinoceronte é da Horda, mas é bicho: família = tipo de criatura, como o Dragonete no Ato I).
- `humanoid`: naga_tide, naga_warrior, boss_tide_mother.
- `construct`: basalt_golem.

Aviso de equilíbrio: ~80% dos abates do Ato II são `horde`, então `family_dmg horde` é quase um "+% de dano" no Ato II
(o mesmo que `family_dmg undead` foi na faixa 20-30 do Ato I). Por isso só **uma** carta comum dá `family_dmg horde` e **uma** dá `family_def horde`.

## Cartas comuns por grupo (G = grupo; bônus de 2 e de 3 somam)

| Grupo | Monstro (id) | Nível | Encaixe | Efeito | T | Valor |
|---|---|---|---|---|---|---|
| **G26 Grutas Goblin** — 2: +5% vel. de ataque · 3: +3% ATK e MATK | goblin_lancer | 30 | botas | speed_pct | 3 | 5 |
| | goblin_impaler | 33 | arma | family_dmg horde | 4 | 12 |
| | goblin_agitator | 36 | cabeça | cc_resist_pct | 4 | 13 |
| **G27 Ginetes** — 2: +4% velocidade · 3: +10% dash e −10% controle | wolf_rider | 31 | botas | dash_pct | 4 | 14 |
| | wolf_raider | 35 | acessório | gold_pct | 4 | 12 |
| | dire_wolf_rider | 41 | arma | proc_slow | 5 | 16 |
| **G28 Costa Partida** — 2: +6% cura recebida · 3: +4% vida e +6% mana | naga_tide | 31 | cabeça | mp_regen_combat | 4 | 0,5 |
| | naga_warrior | 34 | mão sec. | thorns | 4 | 10 |
| | orc_recruit | 32 | peito | hp_pct | 4 | 5 |
| **G29 Trolls** — 2: +5% vida · 3: abates curam 3% da vida | troll_whelp | 35 | peito | heal_taken_pct | 4 | 7 |
| | troll | 38 | arma | regen_cut (**H1**) | 5 | 3 s |
| | troll_thrower | 41 | mão sec. | family_def horde | 5 | 11 |
| **G30 Arqueiros da Horda** — 2: +2% crítico · 3: +14% dano crítico | orc_archer | 35 | arma | crit | 4 | 2,5 |
| | orc_crossbow | 38 | mão sec. | ranged_def (**H2**) | 5 | 11 |
| | orc_fire_archer | 42 | acessório | mp_on_kill | 5 | 6 |
| **G31 Encostas de Kharzun** — 2: +0,75% roubo de vida · 3: +14% dano no tempo | dire_wolf | 40 | botas | evasion | 5 | 2,5 |
| | goblin_assassin | 40 | arma | proc_poison | 5 | 14 |
| | lava_salamander | 43 | peito | def_pct | 5 | 7 |

`Balance.CARD_GROUP_BONUS` (chaves = stats ou ganchos de carta; `kill_heal` e `dash_pct` já são ganchos que o combo soma, `CardSystem.refresh`):

```
"goblin_caves": [{"aspd_pct": 5.0}, {"atk_pct": 3.0, "matk_pct": 3.0}],
"riders": [{"speed_pct": 4.0}, {"dash_pct": 10.0, "cc_resist_pct": 10.0}],
"broken_coast": [{"heal_taken_pct": 6.0}, {"hp_pct": 4.0, "mp_pct": 6.0}],
"trolls": [{"hp_pct": 5.0}, {"kill_heal": 3.0}],
"horde_archers": [{"crit": 2.0}, {"crit_dmg_pct": 14.0}],
"kharzun_slopes": [{"lifesteal": 0.75}, {"dot_pct": 14.0}],
```

Escala dos combos: no Ato I o bônus de 2 ≈ uma comum de T1-T3 e o de 3 ≈ duas; aqui o de 2 ≈ uma comum de T4-T5 (ex.: +5% vida = `hp_pct` T5 comum 6)
e o de 3 ≈ duas (ex.: +14% dano crítico ≈ metade do núcleo T5 30). Cada grupo tem 3 encaixes diferentes (check §8.2).

Para que serve cada grupo nas builds do Ato II (sem repetir ascensão/Ápice):
- **G26** corpo a corpo e mago de ataque (Berserker, Cruzado, Elementalista): ritmo e dano geral.
- **G27** quem vive se mexendo (Assassino, Lanceiro, Druida Lobo) e quem sofre com a rede do Saqueador.
- **G28** sustento no começo do ato (qualquer build, principalmente curandeiro e tanque).
- **G29** tanque e corpo a corpo contra trolls: H1 deixa qualquer build cortar a regeneração (hoje só fogo e veneno, F3).
- **G30** atiradores e críticos (Ranger Atirador, Duelista, Corsário).
- **G31** veneno e dano no tempo (Lâminas, Necromante de maldições, Druida).

## Cartas de núcleo

| Monstro (id) | Nível | Chefe? | Encaixe | Efeito | T | Valor |
|---|---|---|---|---|---|---|
| boss_tide_mother | 33 | campo | acessório | heal_pct | 4 | 11 |
| boss_agitator_lord | 36 | masmorra | arma | storm_pct ("tambor-trovão") | 4 | 12 |
| boss_troll_king | 38 | fortaleza | peito | hp_pct | 5 | 13 |
| boss_crossbow_master | 39 | fortaleza | arma | crit_dmg_pct | 5 | 30 |
| boss_ghar | 40 | fortaleza | mão sec. | thorns | 5 | 30 |
| boss_dire_mother | 41 | campo (grupo) | cabeça | pet_pct | 5 | 24 |
| boss_shazka | 43 | masmorra | acessório | dot_pct | 5 | 24 |
| boss_ulgra | 44 | cidadela | botas | speed_pct | 5 | 12 |
| boss_gorbash | 44 | cidadela | acessório | kill_heal | 5 | 6 |
| boss_kragmar | 44 | cidadela | arma | fire_pct | 5 | 14 |
| boss_durgash | 45 | raide | cabeça | cdr | 5 | 10 |
| war_rhino | 40 | mundo | peito | def_pct | 5 | 16 |
| iron_wolf_king | 45 | mundo | arma | aspd_pct | 5 | 13 |
| orc_warrior | 37 | — | cabeça | buff_pct (grito de guerra) | 4 | 25 |
| troll_brute | 44 | — | peito | low_dr | 5 | 25 |
| orc_warlord | 42 | — (elite) | arma | leader_dmg (**H3**) | 5 | 16 |
| goblin_slayer | 43 | — (elite) | arma | backstab | 5 | 16 |
| clan_guard | 44 | — (elite) | mão sec. | block | 5 | 10 |
| basalt_golem | 45 | — (elite) | peito | dr_pct | 5 | 12 |

Cobertura por papel: tanque (hp, thorns, def, low_dr, block, dr), corpo a corpo (crit_dmg, aspd, speed, backstab, leader_dmg),
magia (storm, fire, dot, cdr), cura/apoio (heal_pct, buff_pct), invocação (pet_pct), geral (kill_heal). Não há `atk_pct`/`matk_pct`
no Ato II: os do Ato I (Rei Javali, Azhar) continuam valendo, e `leader_dmg` faz o papel de "dano em quem importa".

## Taxa de queda (§4 de `cartas.md`; nenhum número de chance muda)

`cartas/h = K × Σ (fração de abates do monstro m × p(m))`, com `p` = `CARD_CHANCE_COMMON` 1/250 (comum), `CARD_CHANCE_CORE` 1/2000
(núcleo de monstro comum), `CARD_CHANCE_BOSS` 1/12 (chefe) e × `CARD_ELITE_MULT` no Rei. Chefes de mundo seguem a mesma regra do Javali, Alce e Basilisco no Ato I.

| Símbolo | Tipo | Faixa | Descrição |
|---|---|---|---|
| `K` | float | 300-800 | abates por hora no nível (medido no `card_probe`) |
| `p(m)` | float | 0,0005-0,083 | chance da carta do monstro `m` por abate (por personagem que divide) |
| cartas/h | float | 0-4 | resultado; alvo D3 = 2-3 |

**Exemplo** (H = hipótese, a medir: K do Ato II, fração de abates por monstro e abates/h do Golem): no Ato I o `card_probe` mediu ~700 abates/h. Os monstros do Ato II vêm em bandos com líder (escolta) e os
trolls regeneram, então o palpite é K ≈ 450-550 → `500 × 0,004 ≈ 2,0` cartas comuns/h (no limite de baixo do alvo). Grupo fechado:
nas Grutas Goblin, com ~1/3 dos abates em cada monstro do grupo, cada carta sai a ~0,67/h e as três a `(1 + 1/2 + 1/3) / 0,67 ≈ 2,7 h`.
Núcleo de elite: Golem de Basalto a ~15 abates/h dá `15 / 2000 = 0,0075/h` → ~130 h esperadas (longo demais; ver pergunta 3).

Medir antes de mexer: `card_probe.tscn` com bots nos níveis 32 (Costa), 38 (Estepes) e 43 (Kharzun).

## Ganchos novos (código) — 3 (teto pedido: 5)

1. **H1 `regen_cut`** — `CardSystem.on_hit`: golpe direto que pega põe no alvo o mesmo estado que a queimadura/veneno usam para cortar a
   regeneração do troll (F3 de `ato2-horda.md`) por `v` s (renova a cada golpe). Só afeta monstro com `regen` > 0. Entra em `CardSystem.HOOKS`.
2. **H2 `ranged_def`** — `CardSystem.damage_mult`: dano recebido de monstro com `MonsterDef.ranged` × (1 − min(v, `CARD_FAMILY_DEF_CAP`)/100),
   golpe básico e skill (inclusive a chuva de flechas avisada: a carta reduz, não esquiva; o caminho `dodgeable=false` continua). Mesmo teto da defesa de família.
3. **H3 `leader_dmg`** — `CardSystem.damage_mult`: dano causado × (1 + v/100) em monstro que é líder (tem `escort`), elite
   (`stat_role` elite ou `elite_of`) ou chefe (`is_boss`). Lista feita uma vez no `GameData` (`card_leaders`), sem custo por golpe além de um `has`.

Sem gancho novo: a família `horde` (dado), `storm_pct` em `CARD_CORE` (já é stat) e as tabelas de 5 faixas. Textos novos em
`CardsCatalog.describe`: `storm_pct` ("+N% de dano de raio"), `regen_cut` ("Golpes cortam a regeneração por N s"),
`ranged_def` ("−N% de dano recebido de ataques à distância"), `leader_dmg` ("+N% de dano em líderes, elites e chefes").

## Critérios de aceite (estendem §8 de `cartas.md`)

1. `_check_cards`: o filtro de elegíveis passa de "nível ≤ 30 e mapas até o 30" para "nível ≤ 45 e mapas até o 45" (o Ato III continua fora);
   cada um dos 24 comuns + 13 chefes acima tem exatamente uma carta; nenhum lacaio/estandarte/decoy/`wb_*` tem.
2. Toda lista de `CARD_COMMON`/`CARD_CORE` tem `CARD_TIER_LEVELS.size() + 1` valores; `tier_of(30) = 2`, `tier_of(31) = 3`, `tier_of(38) = 4`, `tier_of(45) = 4`.
3. Os 6 grupos novos têm 3 encaixes diferentes; todo efeito existe na tabela; `horde` existe em `FAMILY` e `FAMILY_NAMES`.
4. H1: troll com `regen_cut` ativo não regenera por `v` s depois do golpe; sem a carta, regenera. H2: mesmo golpe de `orc_crossbow` tira (1 − v/100)
   da vida com a carta. H3: o mesmo golpe faz × (1 + v/100) em `orc_warlord`, `boss_ghar` e no Rei de um monstro, e × 1 num `troll_whelp` sem escolta.
5. `card_icons`: a ferramenta lista os monstros 31-45 e há `assets/icons/card_<monstro>.png` para os 37.
6. `card_probe` nos níveis 32/38/43: 2-3 cartas/h (ver pergunta 3).

## Perguntas para o usuário (decididas 2026-11-27: recomendações aceitas)

1. **Faixas do Ato II**: duas faixas novas, T4 31-37 e T5 38-45 (`CARD_TIER_LEVELS = [10, 20, 30, 37]`), ou uma faixa só para 31-45?
   **Recomendo duas**: a Costa (30-35) fica com cartas um pouco mais fracas que o Kharzun, e o jogador tem motivo para trocar cartas no meio do ato.
2. **Três ganchos novos** (H1 `regen_cut` nos Trolls, H2 `ranged_def` nos Arqueiros, H3 `leader_dmg` no Senhor da Guerra): aprovar os três?
   E o H3 vale também em chefe? **Recomendo os três, com chefe incluído** (é núcleo, compete com +8% de ATK universal; sem chefe fica fraco demais).
3. **Taxa de queda**: manter as chances de hoje e medir no `card_probe` (32/38/43) antes de mexer? Se der < 2 cartas/h, ou se o núcleo de elite
   passar de ~20 h esperadas (Golem de Basalto dá ~130 h na conta acima), criar um multiplicador por faixa (`CARD_TIER_CHANCE_MULT`) e um para núcleo
   de elite (`CARD_ELITE_ROLE_MULT`, proposta ×5). **Recomendo medir primeiro**; o multiplicador de elite eu já deixaria aprovado.
4. **Família nova `horde`** (goblins, orcs, trolls, ginetes) em vez de pôr todos em `humanoid`/`beast`? **Recomendo `horde`**: combina com a
   história do ato e com as cartas de dano/defesa contra a Horda; o risco (quase um "+% de dano" no Ato II) fica contido em uma carta de cada.
