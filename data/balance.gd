extends Node
## Todas as constantes de balanceamento num lugar só (autoload `Balance`).

const MAX_LEVEL := 50                # Ato III parte 1 (design/gdd/ato3-excesso-45-50.md §8; Lumeria 45-50). Era 45 (Ato II)
const ASC_LEVEL := 35                # ascensão de classe libera neste nível (com a missão hx_asc_<classe>)
const ATTRS := ["FOR", "AGI", "VIT", "WILL", "INT"]
## Escala dos atributos: cada ponto vale 1/ATTR_SCALE do antigo (a teia dá +1 na estrada e +5..+10 nos círculos).
## Os catálogos de equipamento e conjuntos seguem na escala antiga e são multiplicados ao carregar (GameData.load_all).
const ATTR_SCALE := 10
## Poder das skills de cada build (setor da teia) x isto, aplicado ao carregar (GameData.load_all). Calibrado com
## dps_probe (dano no boneco) e boss_probe --lead=<classe>:<build> (vitórias solo): ver docs/DESIGN.md "Equilíbrio entre builds".
const BUILD_POWER := {"inquisidor": 0.6, "ceifador": 0.85, "invocador": 0.85, "carniceiro": 0.88, "batalha": 0.88,
	"laminas": 2.3, "duelista": 1.7, "fera": 1.6, "raio": 1.35, "guardiao": 1.5}

## Peso da magia-assinatura por build (x SIGNATURE_POWER; sem entrada = 1.0), calibrado com dps_probe.
const SIGNATURE_BUILD_POWER := {
	"punhos": 0.8, "fera": 0.8, "xama": 0.85, "lanceiro": 0.8, "laminas": 0.8, "duelista": 0.55, "corsario": 0.7,
	"gelo": 0.9, "ceifador": 0.8, "pestilento": 0.7,
	"guardiao_verde": 0.85,     # Urso: assinatura = Esmagar (cone do malho), não mais o Fogo Lunar do Xamã (2026-11-19)
}
## Números do efeito da arma lendária de cada build ([base, por tier] ou fixo); kind/name/skill ficam na build
## (classes_catalog `legend`). Tipos e regras em LegendEffects. Toda build tem entrada (há check).
## Passivos da teia por build (um por nó do braço, em ciclo; Stats.STAT_KEYS) e bônus extra do conjunto (peças -> stat:
## [base, por tier]). Antes no classes_catalog; mesmos números. Sem entrada = sem passivo próprio.
const BUILD_PASSIVES := {
	"templario": [{"atk_pct": 3}, {"crit": 1.5}],
	"carniceiro": [{"aspd_pct": 3}, {"lifesteal": 1}],     # velocidade de ataque e roubo de vida (árvore e conjunto)
	"executor": [{"atk_pct": 3}, {"hp_pct": 4}, {"def_pct": 3}],     # tanque de apoio: vida e defesa na árvore e no conjunto, sem perder o dano
	"punhos": [{"evasion": 4}, {"aspd_pct": 3}],     # esquiva e velocidade (árvore e conjunto); a arma dá Punho Vingativo (contra-ataque mais forte)
	"sacerdote": [{"heal_pct": 4}, {"buff_pct": 6}],     # suporte: cura mais forte e bênçãos que duram mais (árvore e conjunto)
	"inquisidor": [{"matk_pct": 3}, {"radiance": 2}],     # luz: dano mágico e Radiância (parte do dano cura o aliado mais ferido por perto)
	"batalha": [{"atk_pct": 3}, {"heal_pct": 4}],
	"guardiao_verde": [{"hp_pct": 4}, {"def_pct": 3}],
	"fera": [{"aspd_pct": 3}, {"crit": 1.5}],
	"xama": [{"matk_pct": 3}, {"buff_pct": 6}],     # natureza: magia, invocações e bênçãos que duram mais
	"cacador": [{"atk_pct": 3}, {"pet_pct": 5}],     # companheiro mais forte (árvore e conjunto)
	"atirador": [{"atk_pct": 3}, {"crit": 1.5}],
	"lanceiro": [{"atk_pct": 3}, {"hp_pct": 3}],     # linha de frente leve: ataque e vida (árvore), vida no conjunto de 3
	"laminas": [{"aspd_pct": 3}, {"evasion": 3}, {"backstab": 6}, {"hp_pct": 4}],     # velocidade, esquiva e pelas costas (árvore e conjunto)
	"duelista": [{"atk_pct": 3}, {"def_pct": 3}, {"crit": 1.5}],     # equilibrado: ataque, defesa e um pouco de crítico
	"corsario": [{"atk_pct": 3}, {"crit": 1.5}, {"def_pct": 3}],     # crítico e defesa (árvore e conjunto: casaca grossa de abordagem); a arma dá Bala na Agulha (golpe às vezes dispara a pistola de graça)
	"fogo": [{"matk_pct": 3}, {"fire_pct": 4}],
	"gelo": [{"matk_pct": 3}, {"frost_pct": 4}, {"hp_pct": 3}],
	"raio": [{"matk_pct": 3}, {"storm_pct": 4}],
	"invocador": [{"matk_pct": 3}, {"pet_pct": 5}],
	"ceifador": [{"matk_pct": 3}, {"lifesteal": 1}, {"hp_pct": 3}],
	"pestilento": [{"matk_pct": 3}, {"mp_pct": 4}],
}
const BUILD_SET_EXTRA := {
	"templario": {3: {"crit": [3.0, 0.8]}},
	"carniceiro": {3: {"lifesteal": [2.0, 0.5]}},
	"executor": {3: {"hp_pct": [5.0, 1.5], "def_pct": [5.0, 1.5]}},
	"punhos": {3: {"evasion": [6.0, 1.0], "crit": [3.0, 0.6]}},
	"sacerdote": {3: {"buff_pct": [10.0, 3.0]}},
	"inquisidor": {3: {"radiance": [6.0, 1.5]}},
	"batalha": {3: {"def_pct": [5.0, 1.5]}},
	"guardiao_verde": {3: {"hp_pct": [5.0, 1.5]}},
	"fera": {3: {"aspd_pct": [6.0, 2.0]}},
	"xama": {3: {"buff_pct": [10.0, 3.0]}},
	"cacador": {3: {"pet_pct": [10.0, 3.0]}},
	"atirador": {3: {"crit": [4.0, 1.0]}},
	"lanceiro": {3: {"hp_pct": [5.0, 1.5]}},
	"laminas": {3: {"evasion": [6.0, 1.5], "backstab": [10.0, 3.0]}},
	"duelista": {3: {"def_pct": [5.0, 1.5], "crit": [3.0, 0.5]}},
	"corsario": {3: {"crit": [3.0, 0.8], "def_pct": [5.0, 1.5]}},
	"fogo": {3: {"fire_pct": [6.0, 2.0]}},
	"gelo": {3: {"frost_pct": [6.0, 2.0]}},
	"raio": {3: {"storm_pct": [6.0, 2.0]}},
	"invocador": {3: {"pet_pct": [10.0, 3.0]}},
	"ceifador": {3: {"lifesteal": [1.0, 0.3]}},
}
const LEGEND_NUMBERS := {
	"guardiao": {"chance": [15, 2], "pct": [35, 5]},          # Lâmina Justa (espada): chance de +pct% do ATK em dano sagrado (conta ameaça)
	"cruzado": {"chance": [12, 2], "dur": [0.8, 0.1], "icd": 6.0},
	"templario": {"pct": [120, 24], "stacks": 5, "radius": 2.5},
	"carniceiro": {"pct": [4, 0.6], "max": 5},
	"executor": {"pct": [30, 6], "below": 0.3},
	"punhos": {"pct": [30, 6]},
	"sacerdote": {"pct": [15, 3]},
	"inquisidor": {"chance": [18, 3]},
	"batalha": {"pct": [8, 2]},
	"guardiao_verde": {"icd": 20.0},
	"fera": {"chance": [30, 4], "pct": [12, 2]},
	"xama": {"chance": [18, 3]},
	"atirador": {"pct": [40, 6], "radius": 2.5},
	"cacador": {"pct": [8, 2]},
	"lanceiro": {"pct": [2.4, 0.48], "max": 5, "bleed": [8, 1.6]},
	"laminas": {"chance": [35, 4], "pct": [10, 2]},
	"duelista": {"pct": [80, 10]},
	"corsario": {"chance": [25, 3], "pct": [45, 6]},
	"fogo": {"chance": [20, 4]},
	"gelo": {"icd": 20.0},
	"raio": {"targets": [1, 0.34], "pct": [60, 6]},
	"invocador": {"icd": 12.0, "time": [15, 2]},
	"ceifador": {"pct": [6, 1.2]},
	"pestilento": {"chance": [12, 2]},
}

# --- atributos -> stats derivados (por ponto da escala antiga = ATTR_SCALE pontos de hoje) ---
const HP_PER_VIT := 12.0
const MP_PER_WILL := 8.0
const PATK_PER_FOR := 2.0
const PATK_PER_AGI_RANGED := 2.2      # arco: AGI substitui FOR
const PATK_PER_AGI_DAGGER := 1.0      # adaga: AGI complementa FOR
const PATK_PER_AGI_OTHER := 0.25
const PATK_PER_AGI_SPEAR := 1.6       # lança (Ranger Lanceiro): AGI manda, FOR ajuda (arma de caçador, meio arco, meio corpo a corpo)
const PATK_PER_FOR_SPEAR := 1.0
const MATK_PER_INT := 2.5
const PDEF_PER_VIT := 1.5
const MDEF_PER_WILL := 1.5
const CRIT_BASE := 5.0
const CRIT_PER_AGI := 0.4             # % por ponto
const MCRIT_PER_INT := 0.4
const CRIT_MULT := 1.5
const HEAL_PER_WILL := 0.03           # +3% de cura por ponto
const BLOCK_BASE_SHIELD := 12.0       # % chance base com escudo
const BLOCK_PER_FOR_SHIELD := 0.6     # % chance por FOR com escudo
const BLOCK_REDUCTION_BASE := 30.0    # % de redução ao bloquear
const BLOCK_REDUCTION_PER_FOR := 0.5  # com arma física
const BLOCK_REDUCTION_CAP := 60.0
const BLOCK_REDUCTION_MAGIC_WEAPON := 15.0
const BLOCK_MP_PER_SEC := 2.0
const BLOCK_ARC_DEG := 140.0           # guarda e chance passiva só valem para golpes dentro deste arco à frente
const BLOCK_MIN_MP := 5.0              # guarda quebrada (MP zerado) só volta soltando o botão e com este MP
const PARRY_WINDOW := 0.22             # s: erguer o escudo logo antes do golpe = aparar
const PARRY_COOLDOWN := 0.9            # s entre tentativas (segurar ou martelar não apara)
const PARRY_REDUCTION := 90.0          # % do dano
const PARRY_EFFECT_MULT := 2.0         # a reação do escudo vale o dobro
const PARRY_STUN := 0.6                # s de atordoamento em quem bateu de perto
const PARRY_MELEE_RANGE := 4.0
const SHIELD_OATH_MAX := 5             # Juramento (paladino): cargas por bloqueio; aparar vale 2
const SHIELD_OATH_TIME := 10.0         # s até as cargas sumirem
const SHIELD_OATH_POWER := 0.08        # +8% por carga na próxima skill sagrada ou de escudo
const CT_OATH_MAX := 8                 # Voto do Escudo (talento de classe nv 5): teto do Juramento
## Martelos do Paladino (Templário: Martelo da Ira, Martelos Abençoados; Cruzado: Martelo da Justiça)
const PAL_WRATH_STUN := 0.4            # s: Martelo da Ira atordoa de leve (abertura barata)
const PAL_JUSTICE_STUN := 1.0          # s: Martelo da Justiça (arremessado, volta para a mão)
const PAL_HAMMERS_POWER := 0.25        # power de cada batida dos Martelos Abençoados (a do lançamento e cada pulso)
const PAL_HAMMERS_TIME := 6.0          # s que os martelos giram (efeito "orbit")
const PAL_HAMMERS_EVERY := 0.5         # s entre batidas (múltiplo de AURA_TICK: o pulso anda no relógio das auras)
const PAL_HAMMERS_RADIUS := 2.8        # m em volta de quem lança
const SHIELD_DEF_POWER := 0.003        # skill de escudo: +0,3% por DEF do escudo
const SHIELD_DEF_POWER_MAX := 0.3
## VIT do Paladino (decisão do usuário 2026-11-18, opção "Forte": o Guardião quase de dano). VIT na escala de HOJE (a da janela,
## ATTR_SCALE pontos = 1 da antiga): "+1% a cada 2 VIT" da proposta = 2 VIT antigos = 20 de hoje. VIT medida (2026-11-18, teia de bot):
## Guardião nv 30 ~580 com equipamento comum (+29%) e ~1280 com o lendário do 30 (teto); nv 45 ~1000 comum (teto).
## Cruzado ~195 (nv 30) / ~305 (nv 45) = +10% / +15%; Templário ~330 / ~500 (escudo +16% / +25%). Tabela em docs/DESIGN.md.
const SHIELD_VIT_PER_PCT := 20.0       # skill de escudo do Paladino: +1% de poder a cada 20 VIT (ShieldSystem.vit_power), soma com a DEF
const SHIELD_VIT_MAX := 0.25           # teto +25% (era 45%: o Guardião passava o Cruzado em dano, decisão 2026-11-18)
const VIT_SWORD_CLASSES := ["paladin"]           # classes cuja espada converte VIT em dano
const VIT_SWORD_WEAPONS := ["sword", "sword2h"]  # espada de 1 ou 2 mãos na mão principal
const VIT_SWORD_PER_PCT := 20.0        # +1% de dano a cada 20 VIT com espada (Stats.vit_sword_pct; Combat.calc_damage)
const VIT_SWORD_PER_PCT_2H := 10.0     # espada de 2 mãos (Cruzado, pouca VIT): rende o dobro, +1% a cada 10 VIT
const VIT_SWORD_CAP := 40.0            # teto +40%
const SHIELD_GRACE_PCT := 5.0          # Graça (bispo): bloquear cura 5% do HP do aliado mais ferido...
const SHIELD_GRACE_CD := 4.0           # ...no máximo a cada 4 s: reforço, não imortalidade de graça
const SHIELD_GRACE_RANGE := 12.0
const SHIELD_WARD_PCT := 8.0           # aparar dá escudo de 8% do HP aos aliados por perto
const SHIELD_WARD_TIME := 4.0
const SHIELD_WARD_RANGE := 6.0
const SHIELD_BARRIER_TIME := 5.0        # barreira de escudo (Abraço, Muro) some depois disso
const SHIELD_REACT_CD := 0.4           # s entre reações do mesmo escudo
const SHIELD_LEGENDARY_SHARE := 0.3    # chance do lendário de quem usa escudo ser um escudo nomeado
const GUARD_HOLD_REDUCTION_BONUS := 25.0  # segurando RMB: redução extra (bloqueio "ativo")
const DEF_FACTOR := 0.5               # dano -= def * DEF_FACTOR
const DMG_VARIANCE := 0.1

# --- progressão (lenta: ~15 kills/nível no início, ~500 perto do 30; ~3800 kills até o máximo) ---
## XP por nível sai do tempo de jogo: minutos no nível (XP_MIN_BASE + XP_MIN_PER_LEVEL × (lv-1)) × abates por minuto ×
## XP de um monstro do nível (XP_MOB_BASE + XP_MOB_PER_LEVEL × lv) ÷ parte que vem de abates. Dá ~2h (1-10), ~5h (10-20), ~8h (20-30).
const XP_MIN_BASE := 6.5
const XP_MIN_PER_LEVEL := 1.75
const XP_KILLS_PER_MIN := 3.0            # solo, contando o caminho entre um e outro
const XP_MOB_BASE := 6.0
const XP_MOB_PER_LEVEL := 4.5
const XP_QUEST_SHARE := 0.45             # quests (não repetíveis) dão ~45% da faixa; abates, caçadas e quadros o resto
## 1-10: mais quests no 6-7; 10-20: quests pedem mais abates e pagam mais; 20-30: a guarnição e o grupo matam muito,
## então a guerra paga mais por quest; 30-35, 35-40 e 40-45 (Ato II, (H) do GDD F1); 45-50 (Ato III §6.1) igual ao 40-45
const XP_QUEST_SHARE_BAND := {1: 0.5, 10: 0.55, 20: 0.65, 30: 0.55, 35: 0.55, 40: 0.5, 45: 0.5}
## Ato II (GDD F1, "achatar"): do nível XP_ACT2_FROM em diante o tempo por nível cresce XP_MIN_PER_LEVEL_ACT2 por nível
const XP_ACT2_FROM := 30
const XP_MIN_PER_LEVEL_ACT2 := 0.75

## Parte da XP da faixa que começa em `band_start` que vem de quests.
static func quest_share(band_start: int) -> float:
	return float(XP_QUEST_SHARE_BAND.get(band_start, XP_QUEST_SHARE))
const XP_BANDS := [[1, 10], [10, 20], [20, 30], [30, 35], [35, 40], [40, 45], [45, 50]]
const DEATH_XP_PENALTY := 0.03
# pontos da teia (estilo Path of Exile): aprimoramentos das skills, evoluções, atributos e notáveis. 7 por nível (+1 no 10/20/30/40)
# = 206 no 30, 241 no 35, 277 no 40, 312 no 45 e 348 no 50, numa teia de ~250-360 nós: muita liberdade, mas não dá para pegar tudo.
# 8 -> 7 (2026-11-18): a maestria saiu da teia (rank no Mestre de Skills), os ~45-65 pontos dela no 30 iam para atributos
# (web_probe no 30 com 8: ATK x1,38 HP x1,39 > faixa); por círculo de skill o jogador gasta <= 2 (Aprimorada + Ágil).
const MASTERY_POINTS_PER_LEVEL := 7
const MASTERY_BONUS_LEVELS := [10, 20, 30, 40, 50]  # +1 ponto extra (40: Ato II, GDD R7; 50: Ato III §6.5)
const MASTERY_MAX := 5
const MASTERY_BONUS_PCT := 0.1     # cada nível de maestria: +10% nos bônus de buff e forma (só os positivos; tempo não muda)
const SKILL_LEARN_COST := 1               # custo do nó "<Skill> Aprimorada" (o antigo nó da skill; skills vêm pelo nível desde 2026-11-18)
## Skills por nível + ranks no Mestre de Skills (2026-11-18, plano tidy-painting-biscuit): toda skill da classe (fora ascensão)
## chega sozinha no nível dela; o rank 1-5 (e.mastery, efeitos da maestria de sempre) sobe com ouro + materiais da faixa.
const SKILL_UP_POWER := 0.15               # nó "<Skill> Aprimorada" (<classe>_s_<id>): +15% de poder (dano/cura) da skill
const SKILL_QUICK_PCT := 0.12              # nó "<Skill> Ágil" (<classe>_m_<id>): -12% de recarga e de MP da skill
const SKILL_QUICK_COST := 1
## Cargas de skill (2026-11-21): nó da teia "<Skill> em Cargas" (<classe>_k_<id>, kind skill_charge) nas skills de dano/controle
## com recarga base >= SKILL_CHARGE_MIN_CD (fora buffs longos, auras, formas, invocações, Supremas, ascensão; TreeCatalog.charge_ok).
## Com o nó a skill guarda até SKILL_CHARGE_MAX usos; as cargas voltam uma de cada vez (fila), cada uma em
## recarga (já com Ágil/redução) x SKILL_CHARGE_RECHARGE_MULT. MP por uso. Regra em ChargeSystem. Ocupa o 2º passivo do círculo.
const SKILL_CHARGE_MIN_CD := 8.0
const SKILL_CHARGE_MAX := 3
const SKILL_CHARGE_RECHARGE_MULT := 1.3
const SKILL_CHARGE_COST := 1
const SKILL_TRAINER_ROLES := ["trainer"]   # papel do NPC que sobe o rank (MapDef.npcs[].role; Mestre de Skills)
const SKILL_RANK_LEVEL_STEP := 3           # rank r pede nível >= nível da skill + STEP × (r-1) (teto MAX_LEVEL)
const SKILL_RANK_GOLD_BASE := 40           # ouro = base × (tier da skill + 1) × rank^1.5 (tier por COMMON_TIER_LEVELS)
## Materiais por tier da skill (COMMON_TIER_LEVELS: 1, 8, 16, 24, 32, 40, 48), os mesmos das joias (RecipesCatalog.JEWEL_MATS):
## [comum, raro]. Rank r pede r + 1 do comum; do rank SKILL_RANK_RARE_FROM em diante, (r - FROM + 1) do raro.
const SKILL_RANK_MATS := [["iron_ore", "crab_shell"], ["spider_silk", "grave_dust"], ["bone_shard", "bandit_badge"],
	["star_ore", "ancient_relic"], ["orc_tusk", "goblin_fang"], ["orc_steel", "troll_tusk"],
	["dwarf_steel", "basalt_ore"]]     # 48: PROVISÓRIO (materiais de Kharzun) até existirem Fita do Festim/Porcelana Chorosa (Ato III §8, WP11)
const SKILL_RANK_RARE_FROM := 4
## Bots não pagam rank: rank = nível / BOT_SKILL_RANK_PER_LEVELS (o antigo nível/6 da maestria), até o que o nível
## liberaria para um jogador (SKILL_RANK_LEVEL_STEP), nas skills da build. Começo rápido usa a mesma conta.
const BOT_SKILL_RANK_PER_LEVELS := 6
## Quanto a teia rende no 30 (bot da build, com e sem tree_bonus; web_probe e _check_web_strength).
## Média das builds de ATK e HP dentro da faixa; cada build com ATK×HP dentro de WEB_GAIN_BUILD (tanque troca ATK por HP).
const WEB_GAIN_ATK := [1.25, 1.5]          # 1,3 -> 1,25 (2026-11-10): anel/capa/amuleto mais fortes, a teia rende um pouco menos em proporção
const WEB_GAIN_HP := [1.1, 1.42]           # 1,35 -> 1,42 (2026-11-21): anel de base (CORE_NOTABLES) soma ~+5% de HP em todas as classes, de propósito (média medida x1,39-1,40)
const WEB_GAIN_BUILD := [1.2, 2.3]
const WEB_GAIN_LEVEL := 30                 # nível em que as faixas acima foram calibradas (Ato I); o Ato II mede à parte (web_probe --level=35 / --level=40)
## Faixas do Ato II (Fronteira da teia), mesmas regras do 30 nos níveis 40 e 45: crescem pouco (o equipamento do tier novo
## também cresce, e a razão é teia sobre o resto). F5 (ato2-horda): a ascensão (+14,5% no 40, +21,5% no 45) fica abaixo de
## um terço do ganho da teia medido em ATK×HP (média >= x1,45 no 40 e >= x1,65 no 45).
const WEB_GAIN_LATE := {
	40: {"atk": [1.3, 1.6], "hp": [1.12, 1.42], "build": [1.25, 2.5]},     # hp 1,35 -> 1,42: anel de base (2026-11-21)
	45: {"atk": [1.35, 1.7], "hp": [1.12, 1.4], "build": [1.3, 2.8]},
	50: {"atk": [1.4, 1.75], "hp": [1.12, 1.42], "build": [1.35, 3.0]},     # Ato III §6.5 (Orla)
}
## Teto próprio de ATK×HP por classe e nível (no lugar do "build" acima): o Elementalista tem a vida base mais baixa e o anel
## de base dele é todo sobrevivência (Mana em Carne + HP), então a razão de HP sobe mais (medido 2,4-2,8 no 30; 2026-11-21).
const WEB_GAIN_BUILD_CLASS := {"elementalist": {30: [1.2, 2.9], 40: [1.25, 3.0], 45: [1.3, 3.1], 50: [1.35, 3.2]}}
## Fronteira (data/catalog/tree_catalog.gd `_outer_web`): casas livres até WEB_OUTER_GRID_K (a teia do 30 vai até 5), tudo do 31 em diante.
const WEB_OUTER_GRID_K := 7
const WEB_OUTER_CELLS := 6                 # casas por setor de build: 2 notáveis da build, 1 de elo, 1 de elo/papel, pedra-angular, Ápice
const WEB_OUTER_GERAL_CELLS := 3           # Geral (VIT): 2 notáveis + pedra-angular (o Geral já é o depósito de VIT)
const WEB_OUTER_LEVEL := [31, 38]          # nível exigido: borda de dentro -> fundo
const WEB_OUTER_EDGE_KEEP := 0.5           # estradas além da árvore mínima (rotas)
const WEB_OUTER_RING_ATTR := 4             # 2 dos 5 nós do anel de cada círculo da Fronteira dão o atributo da build (2 outros: +1); os do 30 dão +5..+10
const WEB_OUTER_RING_ATTR2 := 3            # e 1 nó dá o 2º atributo da build (VIT no 2º não vira tanque de graça)
const WEB_OUTER_NOTABLE_ATTR := 8         # atributo principal nos notáveis da Fronteira (os do 30 dão +6..+12)
const WEB_OUTER_PASSIVE_MULT := 0.5        # notável da build = passivo da build x isto
const WEB_OUTER_ARM_SCALE := 0.3           # notável de papel "Maior" = ARM_NOTABLES x isto (os do 30: x0,2)
const WEB_HYBRID_ATTR := 6                 # notável de elo: +6 de cada atributo principal das duas builds
const WEB_HYBRID_EDGE := 0.35              # 4ª casa a mais disto da meia-largura do setor = divisa (elo com a vizinha; a 3ª é sempre elo)
const WEB_KEYSTONE_LEVEL := 40
const WEB_KEYSTONE_ATTR := 6
const WEB_KEYSTONE_SCALE := 1.0
const WEB_APEX_LEVEL := 45
const WEB_APEX_ATTR := 12
const WEB_APEX_MULT := 1.0                 # Ápice = todos os passivos da build x isto
## Orla (Ato III §6.5, níveis 46-50; data/catalog/tree_catalog.gd `_rim_web`): anel de casas depois da Fronteira, sorteio próprio.
## Por setor de build: 1 notável da build, 1 de elo (vizinha) e 1 pedra-angular menor (2 opções que se excluem); o Geral: 1 notável + 1 pedra menor.
const WEB_RIM_GRID_K := 10                 # casas livres até isto (a Fronteira vai até WEB_OUTER_GRID_K)
const WEB_RIM_MIN_K := 6.0                 # ... e a partir disto (em casas do centro): a Orla fica por fora, não tapa buraco de dentro
const WEB_RIM_CELLS := 3
const WEB_RIM_GERAL_CELLS := 2
const WEB_RIM_LEVEL := [46, 49]            # nível exigido: borda de dentro -> fundo
const WEB_RIM_KEYSTONE_LEVEL := 48
const WEB_RIM_KEYSTONE_SCALE := 0.5        # pedra-angular menor = KEYSTONES x isto
const WEB_RIM_KEYSTONE_ATTR := 4
const WEB_RIM_NOTABLE_ATTR := 10           # atributo principal nos notáveis da Orla
const WEB_RIM_PASSIVE_MULT := 0.6          # notável da build da Orla = passivo da build x isto (2 passivos)
const BOT_WEB_SPEND_GUARD := 500           # compras de passivo por chamada do bot_spend (era 200: no 45 sobravam pontos)
const SKILL_SLOTS := 6
const LOADOUT_TOWN_ONLY := false            # true = trocar skills da barra só na cidade (2026-11-16: liberado em qualquer lugar)

# --- combate / game feel ---
const INPUT_BUFFER_TICKS := 15              # 0,25 s: apertar durante o golpe não se perde
# Trava no chefe (Tab, só apresentação: game/player/boss_lock.gd; decisão 2026-11-18)
const BOSS_LOCK_RANGE := 30.0               # m: Tab só trava chefe de verdade até aqui
const BOSS_LOCK_RELEASE := 40.0             # m: passou disto, a trava solta sozinha
const BOSS_LOCK_CURSOR_PAD := 2.0           # m além do raio do chefe: o que está sob o cursor vence o mais perto
const BOSS_LOCK_ORBIT_AHEAD := 1.2          # m de arco à frente que A/D persegue no círculo (não espirala para fora)
const BOSS_LOCK_MIN_GAP := 0.5              # m entre os raios: W não empurra mais para dentro do chefe
const CAST_MOVE_MULT := 0.6                 # anda a 60% durante golpes e magias rápidas
const CAST_MOVE_MULT_HEAVY := 0.25          # magias longas (preparo >= CAST_HEAVY_STARTUP) quase param
const CAST_HEAVY_STARTUP := 0.45
const CANCEL_AFTER_MAX := 0.08              # teto da espera entre o fim do golpe e poder cancelar
const BIG_SWING_WEAPONS := ["sword2h", "mace2h", "axe2h"]     # armas corpo a corpo de duas mãos: golpe básico largo
const BIG_SWING_REACH_MULT := 1.4          # alcance do golpe básico x1,4
const BIG_SWING_ARC_DEG := 150.0           # e arco mais aberto (o normal é 110°)
const BIG_SWING_MAX_TARGETS := 4           # acerta até 4 (o normal é 2)
const BUFF_DURATION_CAP := 80.0            # % máximo de duração extra das bênçãos
## Buffs de "ligar e esquecer" (armaduras, bênçãos, hinos, Pacto Sombrio, Matilha, Lâmina Pestilenta; decisão 2026-11-19):
## duram isto. Os de explosão curta (Fúria, Ira Vingadora, Muralha, Reflexos...) e os escudos absorventes continuam curtos.
const BUFF_KEEP_S := 60.0
## Armadura de Gelo (decisão 2026-11-19): em vez de +DEF, corta o dano recebido em BASE% + 1% a cada PER_INT de INT, até CAP%
## (buff com "dr_int"; soma no Stats.dr_pct, que tem o teto geral DR_CAP). Bater o teto cedo é escolha de build.
const FROST_ARMOR_DR_BASE := 15.0
const FROST_ARMOR_DR_PER_INT := 10.0
const FROST_ARMOR_DR_CAP := 40.0
const RADIANCE_CAP := 40.0                 # % máximo de Radiância
const RADIANCE_RANGE := 10.0               # m: alcance da cura da Radiância
## Postura de tanque: ameaça a mais gerada pelo dano na forma de Urso (o mesmo papel da Aura do Bastião do Guardião, +150%);
## o Ent soma +30. Sem isto o grupo do Urso passava 32-40% do tempo segurando skills pela ameaça (boss_probe "freio").
const BEAR_THREAT_PCT := 150
## Druida: formas de animal (buff enquanto transformado) e a arma que cada forma exige
## Urso/Ent: hp_pct 25/35 -> 21/31 (2026-11-18): o HP base por nível do Druida subiu (não tanques), o tanque na forma fica igual.
const FORM_STATS := {"wolf": {"aspd_pct": 25, "speed_pct": 20, "atk_pct": 10, "crit": 5}, "bear": {"def_pct": 40, "hp_pct": 21, "atk_pct": 10, "speed_pct": -10, "threat_pct": BEAR_THREAT_PCT},
	"phantom": {"speed_pct": 25, "evasion": 20, "matk_pct": 10},          # Necromancer: forma fantasma (rápida, difícil de acertar)
	"demon": {"matk_pct": 20, "hp_pct": 25, "def_pct": 20, "lifesteal": 6},   # Necromancer: demônio (grande, aguenta e drena)
	"lich": {"matk_pct": LORD_LICH_MATK_PCT},                             # Necromante ascendido (45): Forma de Lich
	# Druida ascendido (Forma Ancestral, DruidAscension): a 3ª forma de cada build (H; F5)
	"ent": {"def_pct": 55, "hp_pct": 31, "atk_pct": 10, "speed_pct": -12, "threat_pct": BEAR_THREAT_PCT + 30, "dr_pct": 2},     # Urso -> Ent: aguenta mais e segura o aggro
	"alpha": {"aspd_pct": 28, "speed_pct": 22, "atk_pct": 12, "crit": 6},                       # Lobo -> Lobo Alfa
	"bird": {"speed_pct": 25, "matk_pct": 3}}                                                   # Xamã -> Pássaro Arcano (voa: só desenho)
const FORM_REQUIRES := {"wolf": "dual_mace", "bear": "mace2h", "phantom": "scythe", "demon": "scythe", "lich": "scythe",
	"ent": "mace2h", "alpha": "dual_mace", "bird": "staff"}
const FORM_DURATION := {"phantom": 10.0, "lich": LORD_LICH_TIME}     # s; forma fora daqui fica até desligar (lobo, urso, demônio)
const AMBUSH_MULT := 1.6                  # golpe que sai da furtividade
## Metamorfose de monstro (ShiftSystem; MonsterDef.shift_forms): xamã que vira bicho ao entrar em combate
const ACT3_CONVERT_SHIFT_CAST := 0.25     # s: Convertido (Ato III) troca de forma rápido (WP9: com 1 s a conjuração comia a luta, 7% de vida perdida)
const SHIFT_CAST_S := 1.0                 # s de conjuração antes de trocar de forma (MonsterDef.shift_cast > 0 vence)
const SHIFT_REVERT_S := 6.0               # s fora de combate (sem alvo, combat_timer zerado) até voltar à forma base
const SHIFT_AMBUSH_MULT := 1.8            # forma furtiva (lobo): o 1º golpe saindo da furtividade
const SHIFT_STEALTH_S := 8.0              # s de furtividade ao virar a forma com shift_stealth
const SHIFT_STEALTH_MIN_S := 1.5          # s mínimos espreitando (sem golpe nem skill) antes do bote furtivo
const SHIFT_KITE_DIST := 6.0              # forma com kite (gavião): recua entre os tiros se o alvo chegar mais perto que isto (m)
## Ranger Atirador: o mosquete atira mais devagar e bate muito mais forte que o arco
const RIFLE_COOLDOWN_MULT := 1.8
const RIFLE_POWER_MULT := 1.9
const RIFLE_RANGE_MULT := 1.2
## Ranger Lanceiro: a lança estoca em linha, mais longe que espada e machado e bem mais perto que o arco
const SPEAR_REACH := 3.3                 # m (espada ~1,9; montante ~2,7; arco 13)
const SPEAR_ARC_DEG := 40.0              # estocada estreita: o que está na frente da ponta
const SPEAR_MAX_TARGETS := 4             # atravessa a fila (era 3 num cone de 40°; agora faixa reta, 2026-11-16)
## Saltos (GROUND com dash: Salto do Predador, Salto Selvagem, Salto da Fé, Passo das Sombras): pousam no cursor, no máximo
## o `dash`; com o cursor em cima de quem salta, um pulinho mínimo
const LEAP_MIN_HOP := 1.0
## Bola de Fogo: explosão no impacto (raio m, fração do poder em quem está em volta; o alvo leva o golpe cheio)
const FIREBALL_EXPLODE_RADIUS := 1.5
const FIREBALL_EXPLODE_PCT := 0.45            # com a explosão o poder caiu 1,8 -> 1,7 (alvo único -5,5%)
## Muralha de Fogo: faixa no chão (largura m, s acesa, s entre pulsos que reacendem a queimadura)
const FIRE_WALL_WIDTH := 1.4
const FIRE_WALL_TIME := 5.0
const FIRE_WALL_PULSE := 0.5
## Tiro de Dispersão: empurrão (m)
const SCATTER_PUSH := 2.5
## Tiro Fantasma (talento): meia-largura da fila atrás do alvo e alvos no total
const PIERCE_SHOT_HALF := 0.6
const GHOST_SHOT_TARGETS := 3
const SPEAR_LINE_WIDTH := 1.0            # m: largura da faixa da estocada (básico e Estocada Dupla); SkillDef.line_width
const SPEAR_POWER_MULT := 1.15
const SPEAR_COOLDOWN_MULT := 1.1
const BLEED_TIME_DEFAULT := 4.0          # s do sangramento das skills de lança (dot com atk_pct)
## Dano no tempo (veneno, queimadura, sangramento) bate em pulsos: o acumulado sai a cada DOT_PULSE_S s (1º pulso
## 0,5 s depois de aplicar; o resto sai quando acaba, mesmo total). Antes saía quase todo tick (60/s).
const DOT_PULSE_S := 0.5
## Dano no tempo de monstro (chefe, lacaio, invocação de monstro; veneno e fogo) dura x0,7 (mesmo dps: total x0,7). 2026-11-17.
const MONSTER_DOT_TIME_MULT := 0.7
## Dano no tempo mágico do jogador: no máximo 3 cópias por (quem lançou, skill) no alvo; a 4ª substitui a mais antiga.
const PLAYER_DOT_MAX_STACKS := 3
const ARCHER_RANGE_MULT := 1.35          # skills de arco/mosquete alcançam mais (o arqueiro luta de longe)
## armadilhas: arma em 0,6 s, no máximo 3 por ranger (a mais antiga some)
const TRAP_ARM_TIME := 0.6
const TRAP_MAX := 3
## companheiro do Caçador: parte da vida/ataque/defesa do dono
const PET_HP_SHARE := 0.7
const PET_ATK_SHARE := 0.5
const PET_DEF_SHARE := 0.8
## invocação com status do dono: ataque = MATK x share x (ATK do monstro / ref), limitado
const SUMMON_MATK_SHARE := 0.45
# efeito-assinatura da build (LegendEffects.signature_on_hit): magia de graça ao acertar, sem depender de arma
const ESCORT_RING := 2.6               # m do líder até a vaga da escolta
const ESCORT_RESPAWN := 25.0           # s para repor um da escolta que caiu (com o líder vivo)

# --- Ato II, a Horda (design/gdd/ato2-horda.md F2/F4) ---
## F2: atributos dos monstros 30-45 por papel. stat(papel, L) = ANCHOR30 × (1 + k × (L − 30)) × mod_unidade;
## DEF/MDEF somam d × (L − 30) (comum: HORDE_D_DEF_COMMON). mdef é hipótese (H): o GDD só fixa HP/ATK/DEF.
const HORDE_ANCHOR30 := {
	"comum": {"hp": 720.0, "atk": 60.0, "def": 12.0, "mdef": 10.0},
	"bruto": {"hp": 1200.0, "atk": 88.0, "def": 38.0, "mdef": 16.0},
	"elite": {"hp": 3600.0, "atk": 75.0, "def": 42.0, "mdef": 28.0},
	"chefe": {"hp": 90000.0, "atk": 100.0, "def": 34.0, "mdef": 32.0},
}
const HORDE_K_HP := 0.065              # HP × 1,975 no 45
const HORDE_K_ATK := 0.04              # ATK × 1,6 no 45
const HORDE_D_DEF := 1.8               # DEF por nível (bruto/elite/chefe)
const HORDE_D_DEF_COMMON := 0.8        # DEF por nível do comum
## Decisão do autor (2026-11-12): os comuns/brutos 35+ batiam 0-10% da vida do bot do nível (band_probe "trivial");
## o ATK deles ganha este fator por papel (a vida fica: o TTK já estava no alvo). Chefes/elites não mudam (calibrados no
## boss_probe). O bruto (corpo a corpo, físico) bate na DEF do bot 35+ quase no piso: precisa de fator maior que o comum.
const HORDE_ATK_35_LEVEL := 35
## Medido 2026-11-12 (band_probe --hits/duelo, boss_probe, raid_probe): com {comum 1,3, bruto 1,6} o golpe dos brutos 35+ vai a
## 16-21% da vida, mas o duelo continua "trivial" (o bot mata em 1,3-2,5 s antes do golpe: 0% de vida perdida no guerreiro/troll)
## e o que estava calibrado cai: porto C1 sozinho 17 -> 12/20, Mestre Besteiro sorteado 70% -> 55%. Em 1,0 até o autor decidir.
const HORDE_ATK_35 := {"comum": 1.0, "bruto": 1.0}
## Decisão do autor (2026-11-12, 2ª): o ATK fica 1,0; os 35+ ganham vida e golpe mais rápido. Medido (band_probe --trace): o bruto
## ABRIA com a skill lenta (grito 0,6 s, de que o bot foge; pancada 0,8 s) e o bot esquiva o golpe básico de 0,4-0,5 s
## (`BotBrain._danger_escape`); a luta acabava em ~1,5 s com 0-0,1 golpe por monstro. A partir de HORDE_ATK_35_LEVEL o papel ganha:
## `hp` × vida, `startup`/`cooldown` × preparação/intervalo do golpe BÁSICO (skills não mudam) e `skill_delay` = s antes da 1ª skill
## especial (MonsterDef.skill_delay: abre no básico). Chefes/elites fora (calibrados no boss_probe).
const HORDE_LATE_35 := {
	"bruto": {"hp": 1.3, "startup": 0.5, "cooldown": 0.75, "skill_delay": 2.0},
	"comum": {"startup": 0.75, "cooldown": 0.85, "skill_delay": 2.0},
}
## F4: aura de facção de monstro (MonsterDef.aura = chave daqui). Receptores = monstros da mesma MonsterDef.faction
## a `radius` m; o buff renova pelo id (não soma) a cada AURA_TICK e some AURA_KEEP s depois. Morto o dono, quem está a
## `demoralize.radius` m recebe o desânimo por `duration` s.
const MOB_AURAS := {
	"agitator": {"id": "horde_fury", "radius": 10.0, "ally": {"atk_pct": 20.0, "aspd_pct": 10.0, "speed_pct": 10.0},
		"demoralize": {"id": "horde_dismay", "atk_pct": -15.0, "speed_pct": -10.0, "duration": 8.0, "radius": 12.0}},
	"agitator_boss": {"id": "horde_fury", "radius": 14.0, "ally": {"atk_pct": 30.0, "aspd_pct": 10.0, "speed_pct": 10.0},
		"demoralize": {"id": "horde_dismay", "atk_pct": -15.0, "speed_pct": -10.0, "duration": 8.0, "radius": 12.0}},
	# Estandarte do Clã do Lobo (Durgash F2, kharzun-fase3-plan §4): a Horda em volta corre e golpeia mais rápido
	"clan_wolf": {"id": "clan_wolf", "radius": 30.0, "ally": {"atk_pct": 0.0, "aspd_pct": 20.0, "speed_pct": 25.0}},
	# Ato III (ato3-excesso-45-50 §9): Mestre de Cerimônias. Ids de buff do Ato II como visual provisório (TODO(WP12): "festim"/"festim_dismay")
	"festim": {"id": "horde_fury", "radius": 12.0, "ally": {"atk_pct": 0.0, "aspd_pct": 15.0, "speed_pct": 15.0},
		"demoralize": {"id": "horde_dismay", "atk_pct": -15.0, "speed_pct": -10.0, "duration": 8.0, "radius": 12.0}},
	# Matriarca da Sede (§3.1): o bando corre mais (+15% de velocidade); sem desânimo. Buff do Ato II como visual provisório (WP12)
	"sede": {"id": "horde_fury", "radius": 12.0, "ally": {"atk_pct": 0.0, "aspd_pct": 0.0, "speed_pct": 15.0}},
	# Pedestal da Visão (Eco de Sylvaré F2): o Eco e os outros pedestais em volta golpeiam mais forte. Sem esquiva de monstro (D4 = b):
	# no lugar do "+esquiva" do GDD §4.1. Buff do Ato II como visual provisório (WP12)
	"sense_sight": {"id": "horde_fury", "radius": 30.0, "ally": {"atk_pct": 15.0, "aspd_pct": 0.0, "speed_pct": 0.0}},
}

## F3: regeneração do troll (MonsterDef.regen × isto × vida máxima por segundo; MobSystem.update_regen). Zero enquanto queima
## ou está envenenado (qualquer dano no tempo que não seja sangramento) e por TROLL_REGEN_LINGER s depois do último efeito.
const TROLL_REGEN_PCT := 0.015         # fração da vida por segundo
const TROLL_REGEN_LINGER := 2.0        # s sem regenerar depois do fogo/veneno
const BOT_REGEN_CUT_SCORE := 1.6       # bot: peso da skill de fogo/veneno contra troll que está regenerando (BotBrain._best_skill)
const BOT_FUSION_SCORE := 2.5           # bot: peso da skill que dispara a Fusão na hora certa (E1 Vapor: gelo em alvo que queima; FusionEffects.bot_skill_mult)
const TROLL_REGEN_BUFF := "troll_regen"   # brilho verde enquanto regenera (BuffLooks); some quando queima

## Boneco de treino (MonsterDef.dummy; MobSystem.update_dummy): nunca cai de 1 HP; sem levar golpe por DUMMY_REGEN_DELAY s
## volta à vida cheia em ~1/DUMMY_REGEN_PCT s e ao lugar dele. Só o jogador (e as invocações dele) o acertam.
const DUMMY_REGEN_DELAY := 4.0         # s sem dano até começar a se recompor
const DUMMY_REGEN_PCT := 0.5           # fração da vida por segundo depois disso (2 s do zero ao cheio)

## Foco dos bots num bando (GDD ato2-horda AC-20, pergunta 7; BotBrain._focus): quem emite aura de facção (Agitador), quem
## dá grito de guerra (rally) e, para quem tem fogo/veneno, o troll que regenera. Vale só fora de luta de chefe; o tanque
## do grupo não troca (segura o bando). Candidato: monstro em luta (ou a até BOT_FOCUS_PACK m do alvo atual) a até
## BOT_FOCUS_RANGE m do bot. Peso maior ganha; troca só se o candidato vale mais que o alvo atual.
const BOT_FOCUS_EVERY := 0.5           # s entre reavaliações (custo: 1 varredura do mapa por bot em luta)
const BOT_FOCUS_RANGE := 11.0          # m do bot até o candidato
const BOT_FOCUS_PACK := 7.0            # m do alvo atual: mesmo bando, mesmo se ainda não entrou na luta
const BOT_FOCUS_REGEN := 3.0           # troll que regenera, para quem tem fogo/veneno
const BOT_FOCUS_AURA := 2.0            # emissor de aura (Agitador)
const BOT_FOCUS_RALLY := 1.0           # quem tem grito de guerra (Guerreiro Orc)

## F3: tempo efetivo para matar um troll que regenera, dado T = vida ÷ DPS (s). INF = o DPS não vence a regeneração.
static func troll_ttk(t_no_regen: float, regen_mult: float = 1.0) -> float:
	var rt := TROLL_REGEN_PCT * regen_mult * t_no_regen
	return INF if rt >= 1.0 else t_no_regen / (1.0 - rt)

## Decisão (2026-11-12, Kharzun WP3, mesma linha da 2ª decisão dos 35+): no 40+ os bots matam o comum em ~1 s mesmo com
## mod_unidade no teto (band_probe 40-45: vida perdida 7-9%); a vida do papel ganha este fator por cima do HORDE_LATE_35
## (luta mais longa, golpe normal). Chefes/elites fora (boss_probe / caçada única).
## `atk` (decisão do usuário 2026-11-23): os bots ficaram mais fortes (acessórios, lendários, cargas) e o 40-44 voltou a 3-10% de
## vida perdida (trivial em 7 de 10; alvo R8 do kharzun-fase3-plan: 14-20%). O ATK do papel ganha este fator (horde_stat "atk");
## elite entra (só ATK); chefe NUNCA; lacaios de chefe não têm stat_role. Vale também no 45+ (ACT3_LATE_45.atk compensa).
const HORDE_LATE_40_LEVEL := 40
const HORDE_LATE_40 := {"comum": {"hp": 4.4, "cooldown": 0.8, "atk": 1.8}, "bruto": {"hp": 1.3, "cooldown": 0.8, "atk": 2.0}, "elite": {"atk": 2.0}}

## Fator dos 35+ (HORDE_LATE_35) do papel: `key` = hp | startup | cooldown; 1.0 abaixo de HORDE_ATK_35_LEVEL ou sem entrada.
## No 40+ a mesma chave multiplica também HORDE_LATE_40 (vida e ritmo do golpe).
static func horde_late(role: String, key: String, level: int, fallback: float = 1.0) -> float:
	if level < HORDE_ATK_35_LEVEL:
		return fallback
	var v := float((HORDE_LATE_35.get(role, {}) as Dictionary).get(key, fallback))
	if level >= HORDE_LATE_40_LEVEL:
		v *= float((HORDE_LATE_40.get(role, {}) as Dictionary).get(key, 1.0))
	if level >= ACT3_LATE_45_LEVEL:          # Ato III (45+): vida de comum/bruto × ACT3_LATE_45 (fim do arquivo)
		v *= float((ACT3_LATE_45.get(role, {}) as Dictionary).get(key, 1.0))
	return v

## F2: um atributo de monstro da Horda. `stat` = hp | atk | def | mdef; `mods` = mod_unidade (só hp/atk; 1.0 se faltar).
static func horde_stat(role: String, stat: String, level: int, mods: Dictionary = {}) -> float:
	var base: float = float(HORDE_ANCHOR30[role][stat])
	var dl := float(level - 30)
	match stat:
		"hp":
			return base * (1.0 + HORDE_K_HP * dl) * float(mods.get("hp", 1.0)) * horde_late(role, "hp", level)
		"atk":
			var late: float = float(HORDE_ATK_35.get(role, 1.0)) if level >= HORDE_ATK_35_LEVEL else 1.0
			return base * (1.0 + HORDE_K_ATK * dl) * float(mods.get("atk", 1.0)) * late * horde_late(role, "atk", level)   # 45+: ACT3_LATE_45.atk
		_:
			return base + (HORDE_D_DEF_COMMON if role == "comum" else HORDE_D_DEF) * dl
const PATROL_PACE := 0.45              # líder em ronda anda devagar (a escolta acompanha)
const START_PRESET_COINS := 999        # começo rápido (modo debug da criação): Moedas Lendárias para comprar o conjunto lendário
const LEGEND_COIN_PRICE := 500         # Relicária vende uma Moeda Lendária por isto em ouro
const SKILL_RESET_NPCS := ["elder", "high_priest"]   # quem reseta a árvore (Ancião Ravi; Alta Sacerdotisa no Bastião)
const SKILL_RESET_NPC := "elder"       # quem reseta a árvore de skills (Ancião Ravi, praça de Aldara)
const LEG_CAST_ICD := 1.0              # arma lendária que lança magia ao acertar: no máximo uma a cada isto (habilidade em área não dispara 10)
const SIGNATURE_BASIC_PCT := 10.0      # % no acerto do básico...
const SIGNATURE_BASIC_PER5 := 1.0      # ... +isto a cada 5 níveis
const SIGNATURE_SKILL_PCT := 6.0       # % por acerto de skill
const SIGNATURE_ICD := 1.5             # s entre disparos do mesmo personagem
const SIGNATURE_POWER := 0.6           # poder da magia disparada (x o da skill)
const SIGNATURE_BASIC_TRIM := 0.94     # o básico perde isto para o DPS total ficar parecido
const RAID_POWER := 1.5                 # invasores: HP/ATK/MATK x isto (centro do 2º mapa)
## Força da investida só neste mapa (vida/ATK/MATK dos invasores x isto, sobre RAID_POWER); comuns do campo não mudam.
## Kharzun (usuário 2026-11-13): o elenco 40+ ficou mais forte; a leva sem bots voltou a ~9/10 repelidas.
const RAID_MAP_POWER := {"field_kharzun": 0.85, "city_port": 1.2}
## Vida a mais só (x, sobre RAID_MAP_POWER): invasor que aguenta aventureiro de nível 30+ sem bater mais na guarnição.
const RAID_MAP_HP := {"city_port": 1.4}
const RAID_SMART := 1.5                 # invasores: alcance de aggro x isto e skills isto vezes mais seguidas
const RAID_FLEE_HP := 0.25              # invasor sozinho abaixo disto recua para se juntar à leva
const CRYSTAL_ARRIVE := 2.4             # m na frente do cristal onde o G/renascer deixa você
const RECALL_NEAR := 12.0               # já está a isto do ponto de retorno: G não faz nada
const SUMMON_ASSIST_RANGE := 13.0       # invocação ajuda contra monstros a até isto do dono
const SUMMON_LEASH := 18.0              # m do dono: mais longe larga a briga e volta
const SUMMON_TELEPORT := 36.0           # m do dono: invocação mais longe que isto (presa, perdida) aparece ao lado dele
const SUMMON_RETHINK := 0.4             # s entre reescolhas de alvo da invocação
const PET_COMMAND_FOCUS := 4.0          # s que o companheiro segura o alvo mandado pelo dono
const SUMMON_ATK_REF := 12.0
const SUMMON_ATK_MIN := 0.6
const SUMMON_ATK_MAX := 2.5
## Ascensões (Ato II, GDD ato2-horda R6): nível mínimo; a missão `hx_asc_<classe>` libera (ProgressionSystem.has_ascension).
const ASC_MAX_LEVEL := 45                # teto do Ato II (pontos de ascensão até aqui)
## Teia e barra de ascensão (R6, decisão do autor 2026-11-11): pontos próprios por nível do ASC_LEVEL ao ASC_MAX_LEVEL
## (inclusive) + bônus da missão hx_asc_<classe>; a barra ganha ASC_SLOTS vagas (7, 8, 9, 0) só para skills de ascensão.
## Orçamento no 35: 3 + 3 = 6 pontos (uma skill com entrada e 4 de maestria); no 45: 33 + 3 = 36.
const ASC_POINTS_PER_LEVEL := 3
const ASC_QUEST_POINTS := 3
const ASC_SLOTS := 4
const ASC_WEB_ENTRY_ATTR := 8             # atributo da build no nó de entrada de cada skill da teia de ascensão
## Supremas do nível 40 (GDD design/gdd/ultimates-lv40.md; UltimateSystem). Libera no ULT_LEVEL com a ascensão; a Carga
## Suprema (0..ULT_MAX) enche lutando e a Suprema da build principal sai na tecla R com ela cheia.
## 2026-11-19 (usuário: "diminua pela metade os requisitos"): ganhos, gotejar, teto de ritmo e teto por golpe x2, intervalo
## depois de soltar e espera do bot pela metade: a carga enche em ~25-30 s de luta de chefe em grupo (era ~53 s).
const ULT_LEVEL := 40
const ULT_MAX := 100.0
const ULT_GAIN_PER_POWER := 2.8          # pts por 1,0 de poder causado (antes de DEF/crítico)
const ULT_GAIN_HEAL := 2.0               # pts por "cura de poder 1,0" efetiva (régua: ATK mágico × cura do próprio lançador)
const ULT_GAIN_TAKEN := 0.8              # pts por 1% da vida máx. recebido (depois da DEF, antes de bloqueio/escudo/cúpula)
const ULT_TAKEN_HIT_CAP := 8.0           # teto por golpe recebido (antes do peso do papel)
const ULT_TRICKLE := 1.0               # pts/s enquanto em combate
const ULT_DOT_MULT := 0.6                # pulso de dano no tempo × isto
const ULT_SUMMON_MULT := 0.8             # dano das suas invocações × isto
const ULT_AOE_TARGETS := 3               # alvos que contam por ação (golpe/lançamento)
## Teto de ritmo (calibragem 2026-11-19, boss_probe --ult): dano/cura/apanhar enchem no máximo ULT_RATE_CAP pts/s, com
## um estoque de ULT_RATE_BURST para picos (abertura, golpe grande). Sem o teto, poder/s variava 1,5-10 pts/s entre as
## 24 builds (Raio 10, Sacerdote 1,5): com ele quem faz o papel enche em ~(ULT_MAX - BURST)/(CAP + TRICKLE) s.
const ULT_RATE_CAP := 2.6
const ULT_RATE_BURST := 20.0
## papel (ProgressionSystem.role_of) -> [dano, cura, apanhar]
const ULT_ROLE_WEIGHTS := {"tank": [0.6, 0.5, 1.6], "healer": [0.9, 1.7, 0.6], "dps": [1.0, 0.5, 0.5], "caster": [1.0, 0.5, 0.5], "ranged": [1.0, 0.5, 0.5]}
const ULT_COMBAT_WINDOW := 3.0           # s depois do último golpe/cura em que ainda está "em combate" (gotejar)
const ULT_DECAY_DELAY := 6.0             # s fora de combate antes de esvaziar
const ULT_DECAY_RATE := 8.0              # pts/s esvaziando
const ULT_MIN_GAP := 10.0                # s depois de soltar em que nada enche
const ULT_REFRESH_S := 1.0               # s entre reconferir liberação/papel (cache por entidade)
const ULT_CAST_SLOT := 100               # current_skill_slot de uma Suprema em andamento (não é vaga da barra)
## Bots (ramo da Suprema no BotBrain; UltimateSystem.bot_release)
const BOT_ULT_PACK := 3                  # inimigos na área para soltar "boss" sem chefe
const BOT_ULT_SAVE_ALLIES := 2           # aliados feridos na área para soltar "save"
const BOT_ULT_SAVE_HP := 55.0            # % de vida que conta como ferido
const BOT_ULT_TANK_HP := 35.0            # tanque do grupo abaixo disto: "save" solta
const BOT_ULT_SELF_HP := 40.0            # "self": a própria vida abaixo disto
const BOT_ULT_HOLD := 10.0               # bot do grupo do jogador segura a carga cheia esperando chefe
const BOT_ULT_STAGGER := 3.0             # dois bots do mesmo grupo não soltam "boss" a menos disto
const BOT_ULT_AREA := 8.0                # m: área que o bot considera para bando/aliados quando a skill não diz
const BOT_ULT_KEEP_HP := 35.0            # % de vida: acima disto o bot não dá dash na própria Suprema em andamento (mira, canal, saltos; o dash a cortaria)
## Mecânicas das Supremas (seção 9 do GDD). Números por Suprema: ULT_NUMBERS[<id>] (texto e catálogo leem daqui).
const STORM_WALK_TRIES := 3              # meteoro em ponto não andável: sorteia de novo até isto, senão pula
const HOP_GAP := 0.3                     # m entre quem salta (hop_strikes) e o alvo ao reaparecer
const INTERCEPT_BUFF := "intercept"      # buff da Proteção no paladino
const DOT_AMP_KIND := "dot_amp"          # debuff que multiplica os danos no tempo de um lançador no alvo
const ULT_SCALE_TIME := 0.3             # s da transição do boneco maior (Avatar da Fé, Colosso Primevo; EntityView)
const WOUND_HOLD_RANGE := 30.0           # m: o Festim de Sangue segura as feridas do berserker nos inimigos até esta distância
## Força-alvo das Supremas de dano em alvo único (poder somado na duração ÷ golpe de poder 1,0; decisão do usuário 2026-11-19:
## +60% sobre o orçamento antigo de 10-14, ~1 por luta de chefe). Medida por _check_ultimate_b2_power (SimEntity.ult_dealt).
const ULT_POWER_BAND := [16.0, 22.0]
## Supremas de dano + utilidade: só a parte de dano, com faixa própria (giro, implosão, árvore que também cura)
const ULT_POWER_PART := {"nec_ult_soul_reaping": [7.0, 14.0], "nec_ult_void_eclipse": [7.0, 16.0]}
## Recalibragem +60% (decisão do usuário 2026-11-19; medido por _check_ultimate_b2_power, ef = poder em alvo único): Chuva 0,8/6->0,8/6,8
## (15->~20; a queimadura agora conta), Juízo 12->15,5 (~19), Martelos 0,42->0,73 (~20), Festim aspd 35->45, sangria 30->100, fecho 3->7 (~20),
## Veredito 5->11,5 (~18), Sete Ventos 1,3->2,7 (~19), Sol 2,5/0,55->4,0/1,4 (~19), Lua Rubra 1,3/4->0,8/2,5 (o lobo já dava ~25: CORTADA, ~18),
## Coração 1,5/0,9->2,0/1,2 (~17), Disparo 10->17 (~19), Lança 0,6/3,0/20->0,84/4,2/28 (~18), Toxina 3/2->6,5/3,8 (~18), Duelo fecho 1,25->0,9 x
## contador do Duelo (~21), Frota 1,6->2,0 (~19), Inverno 1,1->1,7 (~18), Olho 0,36->0,55 (~19), Ceifa 6,5->10,4 (giro ~10), Eclipse 4->7 (~9).
const ULT_NUMBERS := {
	# Elementalista Fogo: Chuva de Meteoros (presa no ponto do lançamento; decisão do usuário 2026-11-19)
	"ele_ult_meteor_rain": {"duration": 10.0, "every": 0.5, "radius": 8.0, "strike_radius": 2.0, "power": 0.8, "bias": 0.7,
		"warn": 0.3, "burn_dps": 6.8, "burn_time": 3.0},
	# --- onda B1: Paladino, Berserker, Bispo, Druida (GDD §3.5 1-12) ---
	# Paladino Guardião: Bastião da Aurora (provoca, escudo, Juramento cheio + Proteção)
	"pal_ult_dawn_bastion": {"radius": 8.0, "taunt": 4.0, "shield_pct": 35.0, "duration": 8.0, "pct": 30.0, "stop_below": 25.0},
	# Paladino Cruzado: Juízo da Alvorada (salto + 3 golpes 3,0/3,0/6,0; o último crítico e atordoa)
	"pal_ult_dawn_judgement": {"range": 8.0, "radius": 3.5, "power": 15.5, "weights": [0.25, 0.25, 0.5], "stun": 1.0, "iframe": 0.3},
	# Paladino Templário: Céu de Martelos (orbit no relógio de AURA_TICK 0,5 s: 0,73 x 20 passadas ~ 14,6 + Penitência num alvo parado)
	"pal_ult_hammer_sky": {"duration": 10.0, "radius": 4.0, "count": 8, "power": 0.73, "every": 0.5, "penance_pct": 15.0, "penance_time": 6.0},
	# Berserker Carniceiro: Festim de Sangue (fecha com a Sangria gigante, skill ber_ult_blood_feast_end)
	"ber_ult_blood_feast": {"duration": 10.0, "aspd_pct": 45.0, "lifesteal": 10.0, "bleed_dps": 100.0, "end_radius": 4.5, "end_power": 7.0,
		"end_heal_pct": 6.0, "end_heal_max": 5},
	# Berserker Executor: Veredito do Carrasco (rachadura cheia em volta, golpe que consome; execução abaixo de 30%)
	"ber_ult_headsman_verdict": {"range": 7.0, "radius": 3.5, "stacks": 5, "power": 11.5, "below": 0.3, "exec_mult": 1.5, "boss_mult": 1.25},
	# Berserker Punhos: Sete Ventos (hop_strikes intocável, Fúria cheia no fim)
	"ber_ult_seven_winds": {"range": 8.0, "count": 7, "every": 0.2, "radius": 8.0, "power": 2.7, "fury": 5},
	# Bispo Sacerdote: Cúpula da Graça (cúpula parada; não soma com a Barreira Sagrada: vale a maior)
	"bis_ult_grace_dome": {"range": 9.0, "radius": 7.0, "duration": 8.0, "dr": 50.0, "heal": 1.5},
	# Bispo Iluminado: Sol do Julgamento (impacto + chão aceso; 30% do dano cura o aliado mais ferido)
	"bis_ult_judgement_sun": {"range": 10.0, "radius": 4.5, "power": 4.0, "stun": 1.0, "duration": 7.0, "pulse": 0.5, "pulse_power": 1.4, "mend": 0.3},
	# Bispo Clérigo de Batalha: Avatar da Fé (martelo + cura do grupo + 12 s de Avatar, boneco x1,25)
	"bis_ult_faith_avatar": {"radius": 3.5, "power": 3.0, "heal_radius": 8.0, "heal": 1.0, "duration": 12.0, "atk_pct": 30.0, "def_pct": 25.0,
		"cc_resist_pct": 50.0, "mend_pct": 40.0, "scale": 1.25},
	# Druida Urso: Colosso Primevo (vira urso; urso x1,5; +50% HP que entra cheio; ao acabar mantém a % de vida)
	"dru_ult_primal_colossus": {"radius": 8.0, "taunt": 4.0, "duration": 15.0, "hp_pct": 50.0, "def_pct": 40.0, "atk_pct": 30.0, "threat_pct": 100.0,
		"cc_resist_pct": 50.0, "scale": 1.5},
	# Druida Lobo: Garras da Lua Rubra (hop_strikes a cada 0,8 s; prefere quem não sangra)
	"dru_ult_blood_moon": {"count": 10, "every": 0.8, "radius": 10.0, "power": 0.8, "iframe": 0.15, "bleed_dps": 2.5, "bleed_time": 4.0},
	# Druida Xamã: Coração do Bosque Ancião (zona parada e intocável: Fogo Lunar em até 3 a 10 m + cura a 6 m)
	"dru_ult_elder_heart": {"range": 9.0, "radius": 6.0, "power": 2.0, "root": 2.0, "duration": 12.0, "pulse": 1.5, "foe_radius": 10.0, "foe_max": 3,
		"foe_power": 1.2, "heal": 0.35, "dot_dps": 5.0, "dot_time": 4.0},
	# --- Onda B2 (GDD ultimates-lv40 §3.5 13-24): Ranger, Assassino, Elementalista Gelo/Raio, Necromante ---
	# Calibragem 2026-11-19 (_check_ultimate_b2_power, poder efetivo em alvo único; régua Chuva de Meteoros = 15): Lança 0,7/3,5 -> 0,6/3,0
	# (15,8), Toxina 2,0/1,5 -> 3,0/2,0 (8,4), Inverno 0,9 -> 1,1 (8,8), Olho 0,5 -> 0,36 (19,9), Ceifa 4,5 -> 6,5 (o giro saía 3,7: o Ceifador tem BUILD_POWER baixo) e Eclipse 3,0 -> 4,0 (o giro/a
	# implosão; o resto delas é buff/utilidade).
	# Ranger Caçador: Laço Selvagem (revive o lince; 2º lince espiritual com spirit_mult da força)
	"ran_ult_wild_bond": {"duration": 12.0, "atk_pct": 35.0, "pet_cc_resist": 50.0, "pet_grow": 1.4, "spirit_mult": 0.7},
	# Ranger Atirador: Disparo do Fim (mira longa: exceção ao teto de 0,3 s; 1º alvo power, os outros power × rest)
	"ran_ult_end_shot": {"aim": 1.2, "range": 30.0, "power": 17.0, "rest": 0.6, "push": 2.0, "speed": 60.0, "width": 0.7},
	# Ranger Lanceiro: Lança Incansável (canal de estocadas em linha; no fim arremessa a lança)
	"ran_ult_endless_lance": {"channel": 2.4, "ticks": 12, "power": 0.84, "length": 6.0, "width": 1.5, "bleed_atk_pct": 28.0,
		"bleed_time": 4.0, "throw_power": 4.2, "throw_range": 12.0, "throw_root": 1.5, "throw_speed": 32.0},
	# Assassino Lâminas: Toxina Real (dot_amp: seus venenos ×mult; no fim detonam e se espalham)
	"ass_ult_royal_toxin": {"power": 6.5, "range": 3.0, "duration": 8.0, "mult": 2.0, "detonate": 3.8, "spread": 4.0},
	# Assassino Duelista: Duelo Supremo (guarda longa; fim = Golpe de Mestre com Ímpeto cheio × end_power × (1 + duel_per × contador do
	# Duelo); aparo +gain, golpe seu +hit_gain até hit_cap golpes, teto duel_cap: decisão do usuário 2026-11-19)
	"ass_ult_grand_duel": {"duration": 6.0, "arc": 140.0, "gain": 2, "gap": 0.5, "crit": 20.0, "end_power": 0.9,
		"hit_gain": 1, "hit_cap": 8, "duel_cap": 10, "duel_per": 0.06},
	# Assassino Corsário: Chamado da Frota (balas avisadas em areia; Bravata cheia)
	"ass_ult_fleet_call": {"duration": 6.0, "shots": 14, "radius": 6.0, "strike_radius": 2.0, "bias": 0.6, "warn": 0.4,
		"power": 2.0, "push": 1.0, "range": 12.0},
	# Elementalista Gelo: Inverno Eterno (pulsos ancorados; lentidão que acumula; congela no 3º pulso, uma vez por alvo)
	"ele_ult_eternal_winter": {"duration": 8.0, "every": 1.0, "radius": 6.0, "power": 1.7, "slow_step": 15.0, "slow_max": 45.0,
		"slow_time": 1.5, "freeze_hits": 3, "freeze": 2.0, "range": 9.0},
	# Elementalista Raio: Olho da Tempestade (segue o mago; raio em cadeia; +velocidade; zera o Passo Relampejante)
	"ele_ult_storm_eye": {"duration": 10.0, "every": 0.4, "radius": 9.0, "strike_radius": 1.2, "power": 0.55, "fresh": 0.8,
		"chain": 2, "chain_radius": 4.0, "falloff": 0.6, "stun_pct": 10.0, "stun": 0.4, "speed_pct": 25.0},
	# Necromante Invocador: Maré dos Mortos (esqueletos fora do limite que explodem ao sumir)
	"nec_ult_tide_of_dead": {"count": 6, "duration": 20.0, "buff_time": 15.0, "matk_pct": 40.0, "summon_aspd": 25.0,
		"blast_radius": 3.0, "blast_power": 1.0},
	# Necromante Ceifador: Ceifa das Almas (giro + cura por atingido + buff; Demoníaca ×demon, Fantasma avança)
	"nec_ult_soul_reaping": {"radius": 6.0, "power": 10.4, "heal_pct": 6.0, "heal_max": 5, "buff_time": 8.0, "atk_pct": 25.0,
		"matk_pct": 25.0, "lifesteal": 20.0, "demon": 1.2, "phantom_dash": 3.0},
	# Necromante Sombras: Eclipse do Vazio (disco: lentidão, cópia das maldições, dots ×amp; implosão no fim)
	"nec_ult_void_eclipse": {"duration": 8.0, "every": 0.5, "radius": 5.0, "slow": 40.0, "amp": 1.5, "power": 7.0, "range": 10.0,
		"curse_radius": 10.0},
}
## Elemental que evolui (Elementalista ascendido; GDD ato2-horda F6). ElementalSystem.
const ELEM_XP_RADIUS := 13.0             # m do mago: abate que dá XP aqui dentro alimenta o elemental (= SUMMON_ASSIST_RANGE)
const ELEM_XP_MAX := 400                 # teto do elem_xp
const ELEM_STAGE_XP := [0, 120, 400]     # Básico, Maior, Ancestral (acumulado)
const ELEM_STAGE_LEVEL := [0, 35, 40]    # nível do mago para o estágio (Ancestral só aos 40)
const ELEM_STAGE_FLAG := ["", "", "elem_ancestral"]     # portão da teia de ascensão por estágio (AscensionCatalog.NODES)
## HP/ATK/área por estágio; o ATK do estágio vale DEPOIS do limite SUMMON_ATK_MAX (senão some no 35+)
const ELEM_STAGE_MULT := [{"hp": 1.0, "atk": 1.0, "area": 1.0}, {"hp": 1.6, "atk": 1.2, "area": 1.15}, {"hp": 2.4, "atk": 2.0, "area": 1.3}]
const ELEM_STAGE_SCALE := [1.0, 1.25, 1.5]   # tamanho do corpo por estágio (só visual)
const ELEM_SWAP_CD := 20.0               # s: troca de forma (mantém estágio e % de vida); também a volta depois de morrer
const ELEM_DEATH_LOSS := 0.10            # parte do elem_xp perdida quando o elemental morre (o estágio nunca cai) (H)
const ELEM_SUMMON_MP := 30.0             # MP para chamar o elemental sem skill de invocação (Comando Elemental, quadro do HUD)
const ELEM_THINK := 0.25                # s entre pulsos do modo do elemental (por mapa)
const ELEM_FOCUS_HOLD := 1.0             # s que o elemental (modo atacar) segura o alvo do mago
const ELEM_PROTECT_TAUNT := 2.0          # s de provocação no que bate no mago (modo proteger)
const ELEM_PROTECT_DEF_PCT := 50.0       # +% DEF/MDEF do elemental no modo proteger
const ELEM_SUPPORT_EVERY := 3.0          # s entre pulsos do modo apoiar
const ELEM_SUPPORT_RANGE := 12.0         # m do elemental: o grupo que recebe o apoio
## apoio por forma (x ELEM_SUPPORT_STAGE do estágio): fogo = ataque, gelo = escudo (% do HP), raio = velocidade
const ELEM_SUPPORT := {"fire": {"atk_pct": 6.0, "matk_pct": 6.0}, "frost": {"shield_pct_hp": 4.0}, "storm": {"speed_pct": 8.0, "aspd_pct": 6.0}}
const ELEM_SUPPORT_STAGE := [1.0, 1.4, 2.0]
## Fusão (8 s): MATK do mago e o bônus do elemento da forma do elemental (x ELEM_SUPPORT_STAGE do estágio) (H)
const ELEM_FUSION_MATK_PCT := 8.0
const ELEM_FUSION_ELEMENT_PCT := 8.0
const ELEM_FUSION_TIME := 8.0
## Efeito que o golpe da Fusão leva, pela forma do elemental
const ELEM_FUSION_HIT := {"fire": {"dot": {"dps": 10, "duration": 4, "fire": true}}, "frost": {"slow": {"pct": 45, "duration": 3}}, "storm": {"stun": {"duration": 0.5}}}
## Peso F5 da Fusão por forma do elemental (golpe e buff): a mesma Fusão rende mais no raio (magia rápida, lutas curtas) que
## no gelo. boss_probe --tank_lock 2026-11-11 com peso 1,0 nas três: gelo x1,09, fogo x1,11, raio x1,19-1,20.
const ELEM_FUSION_FORM := {"fire": 0.85, "frost": 1.0, "storm": 0.4}
## Refino do 40 por elemento (Salamandra / Golem de Gelo / Silfo; portões elem_refine_<forma> da teia): o elemental NAQUELA forma
const ELEM_FORM_REFINE := {"atk": 0.15, "hp": 0.15}
const ELEM_FORM_REFINE_FLAG := "elem_refine_"        # + forma (fire, frost, storm)
## Ifrit (Ancestral de fogo) explode ao morrer: raio e poder (x MATK do elemental)
const ELEM_IFRIT_BLAST_RADIUS := 4.0
const ELEM_IFRIT_BLAST_POWER := 2.0
## Montaria (H): só fora de combate; atacar, usar skill, dash, bloquear ou levar dano desmonta
const MOUNT_SPEED_MULT := 1.7
const MOUNT_COMBAT_LOCK := 3.0            # s de "em combate" depois do último golpe/dano (bots não montam nisso; o jogador pode)
const MOUNT_CAST_TIME := 1.5              # s de conjuração para montar (H); dá para andar; agir ou levar golpe interrompe
const BOT_MOUNT_CHANCE := 0.04            # por pensamento, bot andando fora de combate monta
## Tipos de montaria (por personagem, `SimEntity.mount_kind`, salvo). Todas com a MESMA velocidade (Kharzun D5:
## o lobo atroz é visual, não poder). `quest` = missão que libera ("" = desde o começo); quem a entrega já sai montando
## o bicho novo e troca no tratador (MOUNT_KEEPER_NPCS). Modelo e pelagem: EntityView.MOUNT_LOOKS.
const MOUNT_KINDS := {"horse": {"name": "Cavalo", "quest": ""}, "dire_wolf": {"name": "Lobo Atroz", "quest": "hx_ov_hatch"}}
const MOUNT_DEFAULT := "horse"
const MOUNT_KEEPER_NPCS := ["kharzun_wolf_keeper"]     # quem troca a montaria (Tratadora de Lobos, acampamento de Kharzun)
## Combate Montado (ascensão do Paladino, GDD ato2-horda F8): montado ele bate e usa skills `mountable`
const MOUNT_FIGHT_CLASSES := ["paladin"]
const ARCANE_SKILL := "pal_arcane_mode"
const ARCANE_BUFF := "arcane_wings"
const MOUNT_FIGHT_SPEED_MULT := 1.3      # velocidade montado em combate (fora de combate MOUNT_SPEED_MULT)
const MOUNT_REACH_BONUS := 0.8            # m a mais no alcance do básico montado
const MOUNT_CHARGE_DIST := 11.2           # m da Carga Montada (DASH_DISTANCE × 3,5); para em parede/água
const MOUNT_CHARGE_POWER := 1.6           # (H) × ATK, atropela todos na linha
const MOUNT_CHARGE_CD := 14.0             # (H) s
const MOUNT_LANCE_MULT := 1.3             # Lança Pesada (Cruzado 40, portão pal_long_lance): alcance da Carga Montada
const MOUNT_LANCE_FLAG := "pal_long_lance"
const MOUNT_TRAMPLE := {"radius": 3.5, "power": 0.9, "cd": 8.0, "slow_pct": 30, "slow_time": 2.0}     # Pisotear (H)
const MOUNT_CC_IMMUNE := 2.0              # (H) s imune a controle depois de cair do cavalo (atordoar/prender/gancho)
## Modo Arcano (asas de luz, F9b): liga/desliga; gasta MP por segundo e desliga com MP 0
const ARCANE_MP_PER_S := 3.0              # (H) MP/s ligado
const ARCANE_REGEN_MULT := 0.5            # (H) regeneração de MP com as asas (a MP acaba de verdade quando as skills gastam)
## (H) bônus das asas (def_pct vale DEF e MDEF). GDD F9b propõe +12% de dano; com +12% a ascensão saía no zero ou abaixo
## (o Modo Arcano ocupa 1 das 6 vagas: sem bônus, -13% de tempo no Cavaleiro da Morte); +20% só devolve o empate. Ver relatório.
const ARCANE_WINGS := {"atk_pct": 24, "matk_pct": 24, "def_pct": 15}
const ARCANE_CD := 20.0                   # s de recarga ao desligar (ou quando a MP acaba)
const ARCANE_BURST := {"radius": 4.0, "power": 0.8, "push": 2.0}         # rajada de penas ao ligar (m, × ATK, m de empurrão)
const ARCANE_TOGGLE_CD := 1.0             # s mínimos entre ligar e poder desligar
## bots (BotBrain): Carga a esta distância do alvo (linha livre); Modo Arcano em chefe, desligam abaixo disto de MP
const BOT_CHARGE_MIN := 6.0
const BOT_CHARGE_MAX := 11.0
const BOT_ARCANE_OFF_MP := 0.2
const BOT_ARCANE_ON_MP := 0.5             # bot só liga as asas com pelo menos isto de MP
const MOUNT_CHARGE_SKILL := "pal_mounted_charge"
const MOUNT_TRAMPLE_SKILL := "pal_trample"
const BOT_MOUNT_FIGHT_RANGE := 14.0       # bot ascendido monta ao ver o alvo a até isto (campo aberto)
## Refinos do Paladino (portões da teia de ascensão, AscensionCatalog.NODES["paladin"]; GDD R6.1)
const ARCANE_GUARD_FLAG := "pal_wing_guard"       # Guardião 40, Asas com Bloqueio: as asas dão +bloqueio (só com escudo)
const ARCANE_GUARD_BLOCK := 10.0                  # +% de chance de bloqueio nas asas
const ARCANE_WARD_FLAG := "pal_wing_ward"         # Templário 40, Asas Protetoras
const ARCANE_WARD_MP_MULT := 0.5                  # o Modo Arcano gasta metade da MP por segundo
const ARCANE_WARD := {"id": "arcane_ward", "radius": 6.0, "dr_pct": 10}     # redução de dano no grupo a 6 m (aura, renova a cada AURA_TICK)
const MOUNT_WALL_FLAG := "pal_mounted_wall"       # Guardião 45, Muralha a Cavalo: provoca e bloqueia montado
const MOUNT_WALL_SKILLS := ["pal_taunt"]          # skills que passam a sair montadas com a Muralha a Cavalo
const MOUNT_BANNER_FLAG := "pal_banner"           # Templário 45, Estandarte
const MOUNT_BANNER_MULT := 1.5                    # montado: raio das auras de grupo × isto
## Otimização: mapa sem o jogador simula a cada N ticks (passo N vezes maior)
const AWAY_MAP_EVERY := 4
## Densidade de monstros (multiplica os spawners exportados do Blender, sem mexer nas zonas)
const SPAWN_COUNT_MULT := 1.6            # campos e vale da cidade
const SPAWN_COUNT_MULT_DUNGEON := 2.0    # dungeons: salões cheios para grupo (laço em MapsCatalog sobre os spawners do JSON)
const SPAWN_RESPAWN_MULT := 0.75         # renasce mais rápido
## Caçadas repetíveis geradas (QuestsCatalog.hunts)
const HUNT_COUNT := 10
const HUNT_XP_MULT := 1.6                # XP da quest = XP do monstro × quantidade × isto
const HUNT_GOLD_PER_LEVEL := 6.0
## Necromancer: maldições e canalização
const CURSE_WEAKEN_CAP := 50.0            # % máximo de dano a menos causado por maldições somadas
## Elementalista: bônus de dano por elemento (fogo/gelo/raio), teto por elemento
const ELEMENT_CAP := 60.0
const SET_FAVOR_BASE := 5.0               # conjunto que favorece uma combinação: % do 2º elemento com 4 peças
const SET_FAVOR_PER_TIER := 1.5
## Assassino: esquiva, veneno na lâmina e golpe pelas costas
const EVASION_CAP := 45.0                 # % máximo de esquiva
## Esquiva passiva da AGI (decisão do autor, 2026-11-12): esquiva = REF_PCT × (AGI / REF)^EXP, AGI na escala antiga (atributo / ATTR_SCALE).
## Build toda em AGI aos 45 (~140) ~10%; força com AGI de passagem (~25-40) ~1-2%; Carniceiro (~78) ~4,7%. Linear (expoente 1) dava 5,5% ao
## Carniceiro com o mesmo topo: a curva leve segura quem só tem AGI de passagem. Soma com a do Assassino/fusão sob EVASION_CAP.
const EVASION_AGI_REF := 140.0            # AGI (escala antiga) de uma build toda em AGI no 45
const EVASION_AGI_REF_PCT := 10.0         # % de esquiva nessa AGI
const EVASION_AGI_EXP := 1.25             # curva: > 1 = pouca esquiva com pouca AGI
## Lanceiro (decisão do autor, 2026-11-16, opção B): esquiva própria da build, ganha na teia (não de graça no nível 1).
## A curva da AGI acima não muda; só o Lanceiro ganha isto, somado sob EVASION_CAP.
const LANCEIRO_EVASION_PCT := 5.0
## Notável-assinatura da build: o 1º notável do setor da build na teia (TreeCatalog._class_tree) troca o bônus sorteado por
## este (mantém o atributo do círculo e o sorteio da teia). {build: [nome, {stats}]}; stats só de Stats.STAT_KEYS.
const BUILD_WEB_NOTABLES := {
	"lanceiro": ["Passo do Caçador", {"evasion": LANCEIRO_EVASION_PCT}],
}
## Notáveis de papel da classe (playtest 2026-11-18: "o assassino tinha 500 de vida e o paladino 4k"). Classes que não
## são tanque ganham notáveis de SOBREVIVÊNCIA; tanques (Guardião, Urso) ganham notáveis de DANO. Cada grupo troca os
## notáveis da teia do 30 mais perto do início no(s) ramo(s) `branch` ("*" = qualquer, "" = Geral, lista = um deles) pelos da lista (mantém o atributo do círculo
## e o sorteio da teia; TreeCatalog._role_notables). `bots` = builds cujo bot vai buscá-los (ProgressionSystem.bot_spend,
## caminho até BOT_ROLE_NOTE_PATH nós). Alvo do usuário: rota completa de sobrevivência = +25-35% de HP efetivo (com o HP
## base maior das classes) contra antes; tools/tests/hp_probe.tscn mede. Stats só de Stats.STAT_KEYS.
const ROLE_NOTABLES := {
	"assassin": [{"kind": "survival", "branch": "*", "bots": ["laminas", "duelista", "corsario"], "list": [
		["Véu de Sombras", {"evasion": 3.0, "hp_pct": 3}], ["Sangue no Fio", {"crit_leech": 8, "hp_pct": 2}],
		["Couro Curtido", {"dr_pct": 3, "hp_pct": 3}], ["Instinto de Fuga", {"hp_pct": 4, "cc_resist_pct": 10}]]}],
	"ranger": [{"kind": "survival", "branch": "*", "bots": ["cacador", "atirador", "lanceiro"], "list": [
		["Pele de Mateiro", {"hp_pct": 4, "dr_pct": 2}], ["Flecha Pesada", {"hit_slow": 20, "hp_pct": 2}],
		["Distância Segura", {"evasion": 2.5, "hp_pct": 3}], ["Vigor da Trilha", {"hp_pct": 3, "dr_pct": 2}]]}],
	"elementalist": [{"kind": "survival", "branch": "*", "bots": ["fogo", "gelo", "raio"], "list": [
		["Barreira de Mana", {"mana_guard": 15, "hp_pct": 2}], ["Escudo Arcano", {"dr_pct": 4, "hp_pct": 3}],
		["Corpo Elemental", {"hp_pct": 5}], ["Mente Blindada", {"cc_resist_pct": 15, "hp_pct": 2, "mp_pct": 5}]]}],
	"necromancer": [{"kind": "survival", "branch": "*", "bots": ["invocador", "ceifador", "pestilento"], "list": [
		["Armadura de Ossos", {"dr_pct": 4, "hp_pct": 2}], ["Dreno Sombrio", {"lifesteal": 3, "hp_pct": 2}],
		["Carne Morta", {"hp_pct": 5}], ["Pacto de Sangue", {"hp_pct": 3, "heal_taken_pct": 10}]]}],
	"berserker": [{"kind": "survival", "branch": "*", "bots": ["carniceiro", "executor", "punhos"], "list": [
		["Sede na Beira", {"low_leech": 6, "hp_pct": 3}], ["Couro de Batalha", {"dr_pct": 3, "hp_pct": 3}],
		["Sangue Quente", {"hp_pct": 4}], ["Teimosia", {"hp_pct": 3, "cc_resist_pct": 15}]]}],
	"bishop": [{"kind": "survival", "branch": "*", "bots": ["sacerdote", "inquisidor", "batalha"], "list": [
		["Cura de Si", {"heal_taken_pct": 15, "hp_pct": 2}], ["Égide da Fé", {"dr_pct": 3, "hp_pct": 3}],
		["Corpo Consagrado", {"hp_pct": 5}], ["Graça Protetora", {"dr_pct": 2, "hp_pct": 3}]]}],
	"druid": [{"kind": "survival", "branch": ["", "fera", "xama"], "bots": ["fera", "xama"], "list": [
		["Casca Viva", {"dr_pct": 3, "hp_pct": 3}], ["Seiva", {"heal_taken_pct": 15, "hp_pct": 2}],
		["Raízes do Corpo", {"hp_pct": 5}], ["Pelagem Densa", {"hp_pct": 3, "evasion": 2.0}]]},
		{"kind": "damage", "branch": "guardiao_verde", "bots": ["guardiao_verde"], "list": [
		["Casca Afiada", {"def_atk_pct": 10}], ["Espinhos de Carvalho", {"thorns": 15}],
		["Fúria do Urso", {"taunt_dmg_pct": 12}], ["Ira da Mata", {"crit": 4.0, "atk_pct": 3}]]}],
	"paladin": [{"kind": "damage", "branch": "guardiao", "bots": ["guardiao"], "list": [
		["Peso da Fé", {"def_atk_pct": 10}], ["Escudo Vingador", {"block_reflect": 40}],
		["Contra-Ataque", {"guard_crit": 15}], ["Julgamento", {"taunt_dmg_pct": 12}]]}],
}
const BOT_ROLE_NOTE_PATH := 14           # nós no máximo que o bot anda até um notável de papel (mais longe: deixa)
const LOW_LEECH_HP := 0.35               # "low_leech" (Sede na Beira): roubo de vida a mais abaixo desta fração da vida
const HIT_SLOW_TIME := 2.0               # s de lentidão do "hit_slow" (Flecha Pesada), renova a cada golpe físico direto
const GUARD_CRIT_BUFF := "guard_crit"    # Contra-Ataque: bloqueou -> +"guard_crit"% de crítico por GUARD_CRIT_TIME
const GUARD_CRIT_TIME := 4.0
const MANA_GUARD_CAP := 30.0             # % máx do dano recebido que sai da mana ("mana_guard", Barreira de Mana)
const ROLE_LEECH_CAP := 20.0             # % máx de "crit_leech"/"low_leech" (cada um)
## Notáveis de base (2026-11-21, pedido do usuário): anel de 5 nós em volta do Início da teia, nível 1, 1 ponto cada,
## todos compráveis (TreeCatalog._core_ring; bots compram em ProgressionSystem.bot_spend). {classe: [[nome, {stats}]]};
## stats só de Stats.STAT_KEYS. Regras das chaves novas em Combat.core_* / WorldSim._deal_damage / _heal.
const CORE_NOTABLES := {
	"elementalist": [["Barreira de Mana", {"mana_guard": 10}], ["Mana em Carne", {"mp_to_hp": 8}],
		["Pele Arcana", {"hp_pct": 4, "dr_pct": 2}], ["Fluxo Vital", {"hp_pct": 5, "mp_pct": 5}], ["Reflexo Elemental", {"cc_resist_pct": 15}]],
	"necromancer": [["Escudo de Carne", {"summon_guard": 15}], ["Fúria dos Mortos", {"summon_frenzy": 25}],
		["Sangue em Ossos", {"leech_shield": 15}], ["Dreno Sombrio", {"lifesteal": 3}], ["Legião Robusta", {"pet_pct": 10}]],
	"ranger": [["Olho de Águia", {"crit": 3.0}], ["Corda Rápida", {"aspd_pct": 6}], ["Esquiva do Mateiro", {"evasion": 3.0}],
		["Couro de Trilha", {"hp_pct": 4, "dr_pct": 2}], ["Passo Leve", {"speed_pct": 4, "evasion": 1.5}]],
	"assassin": [["Ponto Fraco", {"crit": 3.0}], ["Mãos Rápidas", {"aspd_pct": 6}], ["Sombra Fugidia", {"evasion": 3.0}],
		["Pelas Costas", {"backstab": 10}], ["Sangue no Fio", {"crit_leech": 5}]],
	"paladin": [["Peso da Fé", {"def_atk_pct": 10}], ["Escudo dos Irmãos", {"ally_guard": 15}], ["Firme na Queda", {"low_dr": 15}],
		["Corpo Abençoado", {"hp_pct": 5}], ["Couraça Benta", {"def_pct": 5}]],
	"berserker": [["Fúria da Beira", {"low_hp_atk": 30}], ["Sangue que Sobra", {"leech_shield": 15}], ["Sede", {"lifesteal": 3}],
		["Ritmo de Guerra", {"aspd_pct": 5}], ["Couro Grosso", {"hp_pct": 4}]],
	"bishop": [["Graça Transbordante", {"overheal_share": 50}], ["Barreira da Fé", {"mana_guard": 10}], ["Mãos Santas", {"heal_pct": 6}],
		["Égide Leve", {"dr_pct": 3}], ["Corpo Consagrado", {"hp_pct": 4}]],
	"druid": [["Casca Viva", {"dr_pct": 3, "hp_pct": 3}], ["Seiva", {"heal_taken_pct": 15}], ["Laço da Mata", {"pet_pct": 10}],
		["Espinhos", {"thorns": 10}], ["Pelagem", {"evasion": 2.0}]],
}
const CORE_RING_R := 1.15                 # raio do anel em volta do Início (unidades da teia; folga: _check_tree_spacing)
const MP_TO_HP_CAP := 20.0                # "mp_to_hp" (Mana em Carne): +HP máximo = % do MP máximo (teto)
const SUMMON_GUARD_CAP := 30.0            # "summon_guard" (Escudo de Carne): % do dano recebido que vai para a invocação mais perto
const SUMMON_GUARD_RANGE := 12.0          # m até a invocação
const SUMMON_GUARD_STOP := 0.2            # invocação abaixo disto da vida não recebe mais (não some só por proteger)
const SUMMON_FRENZY_HP := 0.5             # "summon_frenzy" (Fúria dos Mortos): invocação abaixo disto da vida bate +% do stat
const LEECH_SHIELD_CAP := 30.0            # "leech_shield": roubo de vida que passa do máximo vira barreira até % da vida máxima
const LEECH_SHIELD_TIME := 8.0            # s que a barreira do roubo dura (renova a cada golpe que sobra)
const ALLY_GUARD_CAP := 30.0              # "ally_guard" (Escudo dos Irmãos): % do dano dos aliados do grupo que vai para você
const ALLY_GUARD_RANGE := 8.0             # m até o aliado
const ALLY_GUARD_STOP := 0.3              # abaixo disto da sua vida você para de receber o dano dos aliados
const LOW_DR_HP := 0.5                    # "low_dr" (Firme na Queda): abaixo disto da vida, -% do dano recebido
const LOW_DR_CAP := 30.0
const LOW_HP_ATK_FLOOR := 0.1             # "low_hp_atk" (Fúria da Beira): bônus cheio com a vida nisto; zero com a vida cheia (linear)
const LOW_HP_ATK_CAP := 50.0
const OVERHEAL_SHARE_CAP := 100.0         # "overheal_share" (Graça Transbordante): % da cura que passa do máximo que vai a outro aliado
const OVERHEAL_SHARE_RANGE := 10.0        # m até o aliado mais ferido
## Punhos de Fúria (Berserker de duas garras, FistSystem): esquivar dá Fúria do Punho e contra-ataca
const FIST_FURY_BUFF := "fist_fury"
const FIST_FURY_MAX := 5
const FIST_FURY_TIME := 8.0               # s sem esquivar até as cargas sumirem (renova a cada carga)
const FIST_FURY_ATK_PCT := 6.0            # +% ATK por carga
const FIST_FURY_ASPD_PCT := 5.0           # +% velocidade de ataque por carga
const FIST_COUNTER_PCT := 60.0            # contra-ataque ao esquivar: % do ATK (a arma lendária soma)
const FIST_COUNTER_RANGE := 3.2           # m: só devolve em quem está perto
## Berserker — Empunhadura de Titã (F7, TitanSystem): machado de 2 mãos também na mão secundária (Executor e Gêmeos);
## golpe duplo = a 2ª arma bate junto com TITAN_OFFHAND_MULT do dano; o básico fica (PEN − RELIEF × nós) mais lento.
## razão_dps = (1 + MULT) × (1 − (PEN − RELIEF × n)): 1,0875 (n = 0) .. 1,218 (n = 3)
const TITAN_OFFHAND_MULT := 0.45          # (H) dano da 2ª arma de 2 mãos (× ATK dela ÷ ATK da principal, no máx. 1)
const TITAN_ASPD_PEN := 0.25              # perda de velocidade do básico com as duas armas
const TITAN_WEB_RELIEF := 0.03            # quanto cada nó "titan_relief" da teia devolve
const TITAN_RELIEF_NODES := 3             # nós de alívio na teia (o 4º não conta)
const TITAN_OFFHAND_ATTR_MULT := 0.0      # (H) atributos da 2ª arma de 2 mãos que contam (o peso dela vai no golpe duplo)
const TITAN_WEAPONS := ["axe2h"]          # o que vai na mão secundária com a Empunhadura de Titã
const TITAN_BUILDS := ["executor"]       # bots desta build empunham dois machados de 2 mãos ascendidos (os Gêmeos ficam com
                                          # as machadinhas: trocar o par de 1 mão pelo de 2 mãos não compensa sem a teia de Titã)
## Punhos de Fúria ascendidos: Garras de Titã (perfil de arma pesada nas duas garras)
const TITAN_CLAW_POWER := 1.35             # +135% no básico das garras (F5 no 45, alvo ~1,30 do usuário 2026-11-14: 1,2 x1,28, 1,35 x1,36±0,05; 2026-11-13: 0,9 dava x1,221 contra Kragmar). F5 2026-11-12 (--tank_lock, 80 lutas/braço): com 0,45 x0,978 (no Modo Gladiador a Fúria vira Glória: o Punhos perde a Fúria); com 0,9 x1,091±0,03
const TITAN_CLAW_ASPD_PEN := 0.10         # −10% de velocidade do básico (com 0,20 o boneco parava 0,18 s entre golpes e com 0,15 0,12 s: FLAG do combat_probe)
const TITAN_CLAW_PUSH := 0.7              # m de empurrão no golpe básico (chefe não é empurrado)
## Berserker — Modo Gladiador (F9b, GladiatorSystem): postura liga/desliga; Glória = cargas
const GLADIATOR_BUFF := "gladiator"
const GLORY_BUFF := "glory"
const GLORY_MAX := 5
const GLORY_STEP := 0.2                   # +power das Lâminas Elementais por Glória que você tem
const GLORY_TIME := 12.0                  # s sem ganhar Glória até ela esfriar (renova a cada ganho)
const GLORY_KEEP_FISTS := 6.0             # Punhos: ao sair da postura a Glória fica por isto (os outros zeram)
const GLORY_SHOUT_MAX := 3                # Brado da Arena: +1 Glória por inimigo provocado, até isto
const GLADIATOR_STANCE := {"atk_pct": 7, "def_pct": -5}     # a postura: +7% de dano, −5% de defesa (F5 2026-11-11: com +5% Executor x1,052 e Gêmeos x1,050, na beira de baixo) (GDD: +10/−10; boss_probe F5: a defesa a menos fazia o bot fugir e morrer)
const GLADIATOR_BLADE_POWER := 1.3        # (H) Lâminas Elementais
const GLADIATOR_FINALE_POWER := 3.5       # (H) Golpe Final com 5 de Glória
## Refinos do Berserker (portões da teia de ascensão, AscensionCatalog.NODES["berserker"]; GDD R6.1)
const TITAN_CYCLONE_SKILL := "ber_titan_cyclone"
const CYCLONE_LONG_FLAG := "ber_cyclone_long"     # Gêmeos 40, Giro dos Dois Machados
const TWIN_FURY_FLAG := "ber_twin_fury"         # Gêmeos 45, Fúria Gêmea (portão da teia de ascensão: o bot da build compra antes das maestrias)
const TWIN_FURY_ATK := 28                         # +% de dano da Fúria Gêmea (F5 no 45, alvo ~1,30 2026-11-14: 19 x1,23, 25 x1,28, 28 x1,30; era velocidade, mas o Gêmeos já bate no ATTACK_SPEED_CAP)
const CYCLONE_LONG_MULT := 1.5                   # Ciclone de Titã: giros e duração × isto (4 → 6 giros, 2 → 3 s)
const SECOND_AXE_FLAG := "ber_second_axe"         # Executor 40, Segundo Machado
const SECOND_AXE_BELOW := 0.2                     # alvo abaixo disto da vida: toda skill bate com as duas armas (golpe duplo)
const FURY_LIT_FLAG := "ber_fury_lit"             # Punhos 40, Fúria Acesa
const FURY_LIT_TIME := 6.0                        # s a mais no tempo da Fúria (e da Glória, na postura) ao lançar o Ciclone
const ARENA_FINALE_FLAG := "ber_arena_finale"     # Executor 45, Golpe Final da Arena
const ARENA_FINALE := {"power": 1.1, "stun": 1.0} # Golpe Final: poder × 1,1 e atordoa 1 s (chefe: 40%, como todo atordoar)
const ARENA_FINALE_ATK := 16                # Golpe Final da Arena (Executor 45): +% de dano do nó (F5 no 45, usuário 2026-11-14: build abaixo de 1,30 sobe; 12 x1,26, 16 x1,31, 20 x1,36)
const GLORY_KEEP_FLAG := "ber_glory_keep"         # Punhos 45, Glória que Não Esfria
const GLORY_KEEP_TIME := 6.0                      # s a mais até a Glória esfriar (e ao sair da postura)
const STORM_STUN_CHANCE := 15.0            # % de chance de skill de raio atordoar no golpe direto (a que já atordoa não rola)
const STORM_STUN_TIME := 0.5              # s (chefes: 40%, como todo atordoar)
const FROST_SHATTER_MULT := 1.3            # skill de gelo em alvo retardado/preso/atordoado: +30% de dano ("estilhaço")
const FROST_ASPD_SLOW := 25.0              # % de velocidade de ataque a menos sob lentidão de gelo (decisão 2026-11-19; Combat.frost_attack_mult)
const HIT_POISON_TIME := 4.0              # s do veneno que o golpe aplica (renova a cada golpe)
const BACKSTAB_ARC := -0.35               # cos do ângulo: atrás do alvo = dot(frente do alvo, alvo->atacante) abaixo disso
const BACKSTAB_CRIT := 25.0               # +crítico pelas costas
const LIFESTEAL_CAP := 20.0                 # % máximo de roubo de vida
const PARTY_PORTAL_FOLLOW := 60.0          # m: bots do grupo até esta distância do líder passam pelo portal com ele
const PARTY_CATCHUP_TIME := 15.0           # s em outro mapa que o líder (preso, ficou para trás): o bot reaparece ao lado dele
const ELITE_KILLS := 40                    # abates do mesmo monstro num mapa até surgir o Rei dele
const ELITE_HP_MULT := 5.0
const ELITE_ATK_MULT := 2.0
const ELITE_DEF_MULT := 1.5
const ELITE_SCALE := 1.6
const ELITE_XP_MULT := 6
const ELITE_GOLD_MULT := 5
const ELITE_RADIUS_MULT := 1.3
const ELITE_LEASH_MIN := 25.0
const RECALL_TIME := 3.5                   # s de conjuração (G) para voltar à cidade; vale em combate; andar, agir ou levar dano interrompe
const BOT_RECALL_RETRY := 8.0              # bot com a volta interrompida anda para o portal e tenta de novo depois disto
const BOT_TRAVEL_LEG_S := 60.0             # bot viajando: prazo para chegar ao próximo portal; recomeça a cada mapa do caminho (era 60 s para a viagem toda)
## Faixa dos bots (playtest 2026-11-18: lv 40 na praça de Aldara). Medir: sim_probe -- --census (linhas BAND).
const BOT_BAND_SLACK := 2                  # níveis acima do teto da faixa do mapa que ainda contam "da faixa" (censo e checks)
const BOT_SQUARE_RADIUS := 12.0            # m do centro da vila: a praça (censo; hangout com gente demais aqui é evitado)
const BOT_HOME_STEP_UP := 2                # bot muda de povoado-casa (cristal) quando passa o piso da faixa do próximo por isto (lv 12 Posto, 22 Bastião, 32 Porto...)
const BOT_SQUARE_CAP := 4                  # bots à toa na praça: com isto ou mais lá, quem escolhe um ponto de encontro vai para um de fora
const BOT_HANGOUT_PICKS := 3               # pontos de encontro sorteados por escolha; fica o com menos gente a BOT_HANGOUT_CROWD_R
const BOT_HANGOUT_CROWD_R := 3.0           # m em volta do ponto de encontro que contam como "gente lá"
## IA dos bots no combate
const BOT_POTION_HP_MELEE := 0.45          # corpo a corpo bebe poção de vida abaixo disto (os outros: 0.35)
const BOT_FLEE_HP := 0.2                   # sem poção, abaixo disto recua por BOT_FLEE_TIME s
const BOT_FLEE_TIME := 2.5
const BOT_STICKY_RANGE := 16.0             # mantém o alvo atual enquanto ele estiver vivo e a até esta distância
## Bots presos (production/qa/bot-stuck-diagnosis-2026-11-17.md). Povoado murado = town_radius + portões no JSON (vila,
## fortes, cidade élfica, postos): sai/entra pelo portão; fora, linha que cortaria o muro contorna pelo anel.
const BOT_GATE_CROSS_PAD := 2.0            # m além do muro: linha que passa mais perto que isto do centro "corta" o povoado
const BOT_GATE_CROSS_HYST := 2.0           # m a mais para largar o contorno (sem isto ia e voltava entre anel e linha reta)
const BOT_GATE_RING_PAD := 6.0             # m além do muro: anel por onde o bot contorna o povoado
const BOT_GATE_RING_STEP := 30.0           # graus por ponto do anel (do ângulo do bot para o do destino)
const BOT_GATE_CLEAR := 3.5                # m além (ou aquém) do muro: até aqui o portão escolhido vale (sem ida e volta no vão)
const BOT_RING_FLIP_DEG := 40.0            # graus: contornando, só vira de sentido se o outro lado ficar isto mais curto (que ao escolher)
const BOT_RING_BLOCK_S := 2.5              # s sem avançar BOT_RING_PROGRESS_DEG no sentido escolhido até poder tentar o outro
const BOT_RING_PROGRESS_DEG := 3.0         # graus de anel que contam como avanço no contorno
const BOT_RING_HOLD_S := 0.3               # s: sem ponto livre, segura o ponto anterior e olha de novo
const BOT_CHASE_PROGRESS := 1.0            # m: chegar isto mais perto do alvo conta como progresso
const BOT_CHASE_STALL := 4.0               # s sem progresso indo ao alvo (ou ao ponto de caça): larga
const BOT_UNREACHABLE_IGNORE := 20.0       # s ignorando o monstro largado por inalcançável
const BOT_ROUTED_STALL_MULT := 3.0         # andando por rota (portão, anel, ponte) o prazo sem progresso é BOT_CHASE_STALL × isto
const BOT_ESCAPE_TIME := 2.5               # s andando para trás (±30°) ao desistir de um ponto: sai do bolsão (ruína em U, canto de muro)
const BOT_LINE_STEP := 1.0                 # m entre amostras do teste de linha (_pick_monster: monstro calmo atrás de muro/rio)
const BOT_LINE_RECHECK := 3.0              # s: monstro com a linha bloqueada fica fora da escolha por isto
const BOT_DOOR_WAIT := 3.0                 # m da porta só do jogador: seguidor espera aqui enquanto o líder está na casa
# chefes (MobSystem): mira, chuva de golpes, gancho, fúria por tempo, escudo dos lacaios
const BOSS_PICK_RANGE := 16.0               # m: quem o chefe escolhe como vítima de skill com mob_pick
const BOSS_HAZARD_DELAY := 1.3              # s do aviso no chão até o golpe da chuva (barrage sem delay)
const BOSS_BERSERK_MULT := 1.6              # dano do chefe que passou de berserk_after
## Chefe escala com quem luta contra ele (MobSystem.crowd_of: quem o atingiu a até BOSS_CROWD_RANGE m + o grupo dessas
## pessoas): dano × BOSS_CROWD_MULT[pessoas] (índice 0..PARTY_MAX). Grupo cheio com tanque e cura sente a luta (antes nem a
## 4× ninguém ficava abaixo de 35% de vida); solo e dupla não mudam. Medido com boss_probe (8 chefes de grupo × 6).
const BOSS_CROWD_MULT := [1.0, 1.0, 1.0, 2.0, 3.5, 5.0]
## Chefe que o grupo de 4+ sorteado vence demais (alvo 65-85%) com o contrato solo 20-40% / trio 75-100% certo: × a mais no
## dano a partir de BOSS_CROWD_EXTRA_FROM pessoas (MobSystem.crowd_mult). Calibrado com boss_probe --party=4 sorteado.
const BOSS_CROWD_EXTRA_FROM := 4
const BOSS_CROWD_EXTRA := {"spider_queen": 1.8, "elf_king": 1.3, "vessaline": 1.3}     # Vessaline (Ato III, D8): o grupo de 4 de 50 ascendido
## Chefe de raide (feito para 5): tabela própria no lugar de BOSS_CROWD_MULT (BOSS_CROWD_EXTRA não vale). O Durgash é medido
## para 5: com 4 bate MAIS (4,9) que com 5 (3,25), o grupo de 4 sofre e não vence antes do berserk (90 s × 20, MonsterDef); o de 5
## fica folgado. Calibrado com boss_probe --boss=boss_durgash --lvl=45 (completo de 5 >= 90%, 5 sorteados 60-80%, completo de 4
## <= ~20%; tabela em DESIGN.md, Chefes). Até o trio vale o comum.
const BOSS_CROWD_RAID := {"boss_durgash": [1.0, 1.0, 1.0, 2.0, 4.9, 3.25], "boss_sylvare_echo": [1.0, 1.0, 1.0, 2.0, 8.5, 4.55]}     # Eco (Ato III D9): 5 completo 8/10 em 95 s; com 4 bate mais (alvo <= 10%); trio = comum (GDD §4.2)
## Casulo de Seda (Rainha Aranha com 4+, MonsterDef.crowd_skills; efeito "cocoon", MobSystem.cocoon): a vítima fica presa até o casulo
## cair ou COCOON_TIME s; esgotado o tempo, o casulo aperta COCOON_BURST × a vida máxima. GDD design/gdd/spider-queen-4p.md.
const COCOON_TIME := 7.0
const COCOON_BURST := 0.45
## Bot (não tanque, não curandeiro) quebra o casulo de um aliado a até isto (m).
const BOT_COCOON_RANGE := 16.0
const BOSS_CROWD_RANGE := 20.0
const BOSS_CROWD_CHECK := 1.0               # s entre recontagens
const BOSS_WARD_CHECK := 0.5                # s entre conferências dos lacaios vivos (ward)
const BOSS_FOLLOW := 5.0                    # m: skill de alvo de chefe (mob_pick) segue a vítima que andou até isto na preparação
const BOSS_PULL_GAP := 0.6                  # m entre o chefe e quem ele puxa
## Assinaturas dos chefes (GDD design/gdd/act2-boss-signatures.md; regras em BossSignatures). Intervalo, power e raio de
## cada uma ficam no dicionário de efeito da skill (catálogo); aqui os números globais (§7).
const BOSS_SIG_WARN_MIN := 1.5              # s: aviso mínimo de qualquer assinatura (check _check_boss_signatures)
const BOSS_SIG_REPEAT_WARN_MIN := 0.8       # s: aviso de cada golpe de uma sequência (repeat; GDD 3.6 pede 0,8 por bote)
const BOSS_SIG_OPEN_DELAY := 6.0            # s do começo da luta até a 1ª assinatura de quem a tem desde 100%
const BOSS_SIG_PHASE_DELAY := 4.0           # s da entrada na fase até a 1ª assinatura que chega com ela
const BOSS_MARK_TIME := 4.0                 # s da marca (segue a vítima) até cair (mark sem "time")
const BOSS_SOAK_MIN := 1                    # divisor mínimo da marca de dividir (soak)
const BOSS_CHANNEL_BREAK_PCT := 0.06        # dano aplicado no canal (× vida máxima) que quebra o canal
const BOSS_CHANNEL_STAGGER := 3.0           # s atordoado quando o canal quebra (não passa pelo corte de chefe)
const BOSS_CHANNEL_VULN := 25.0             # % de dano a mais que ele recebe depois da quebra
const BOSS_CHANNEL_VULN_TIME := 6.0
const BOSS_LINGER_TICK := 1.0               # s entre os tiques do chão que fica (linger)
const BOSS_INVERT_RANGE := 22.0             # m do chefe: quem está a até isto e fora das ilhas leva o golpe invertido
const KRAGMAR_TEMPER_STEP := 0.08           # dano × (1 + passo × acúmulos) do chefe dentro da poça (empower)
const KRAGMAR_TEMPER_MAX := 6
const KRAGMAR_TEMPER_EVERY := 2.0           # s dentro da poça por acúmulo de Têmpera (GDD 3.10)
const KRAGMAR_TEMPER_DECAY := 3.0           # s fora da poça para perder 1 acúmulo
const KRAGMAR_TEMPER_HEAL := 0.005          # vida máxima por segundo que ele cura dentro da poça (uma vez, mesmo com poças sobrepostas)
const GHAR_WALL_CUT := 0.9                  # corte do golpe vindo da frente com a Muralha de Escudos
const GHAR_WALL_ARC_DEG := 120.0            # arco frontal da Muralha
const GHAR_COUNTER_DELAY := 0.375          # s do fim da Muralha ao golpe do contragolpe (quadro 10 do clipe wall_counter do mob_ghar)
# modelos das assinaturas (só apresentação, game/fx/boss_sig_view.gd)
const GHAR_SIDE_SHIELDS := true             # Muralha: prop_ghar_shieldwall em volta do Ghar (o escudo da frente é o do modelo)
const GHAR_SHIELDWALL_SCALE := 1.0
const GRUKK_DRUM_GAP := 1.0                 # m do corpo do Grukk ao tambor plantado
const ULGRA_LANE_SINK := 0.0                # y do prop_ulgra_stampede (negativo afunda o pó para o aviso aparecer)
const SHAZKA_SMOKE_ALPHA := 0.55            # opacidade da fumaça sob as cópias
const TIDE_ISLAND_MIN := 2                  # ilhas mínimas da Maré Cheia (N = max(isto, ceil(crowd/2)))
const TROLL_COVER_MAX := 3                  # pedregulhos do Troll Rei ao mesmo tempo
const SHAZKA_DECOY_DMG := 0.3               # dano das cópias do Shazka (× o dele; Sombras Gêmeas, R-F)
const SHAZKA_DECOY_TINT := Color(0.2, 0.08, 0.32, 0.68)   # apresentação: roxo escuro + força da mistura na pele da cópia
const SHAZKA_DECOY_RIM := Color(0.68, 0.42, 1.0, 0.6)     # apresentação: borda da cópia (cor + força)
const SHAZKA_DECOY_RIM_MIX := 0.5           # apresentação: pele da cópia = TINT puxado para a cor da borda (o TINT puro, em sRGB, virava preto no toon)
const SHAZKA_DECOY_GLOW := 0.6             # apresentação: brilho próprio da pele da cópia (emission_amount); sem ele fica preta fora da luz. Sólida e sem sombra
## Revisão 2026-11-13 (m1/m2): padrões das assinaturas quando a skill não diz (o catálogo sempre diz; isto evita número
## solto no core) e números das manobras dos bots nas assinaturas.
const BOSS_CHANNEL_BREAK_RADIUS := 2.5       # m do efeito da quebra do canal (effects.boss_channel.break_radius)
const BOSS_SIG_DEFAULTS := {
	"avalanche": {"guarantee": 2, "near_min": 5.0, "near_max": 9.0, "radius": 18.0},
	"channel_done": {"radius": 20.0, "duration": 12.0, "atk_pct": 40.0, "heal_pct": 0.3},
	"wall": {"time": 6.0},
	"counter": {"base": 1.0, "step": 0.15, "cap": 2.5, "cone": 150.0, "range": 5.5},
	"decoys": {"count": 2, "spread": 2.6, "time": 10.0},
}
const BOT_SIG_DASH_DIST := 5.0               # m: longe disto do lugar da mecânica (ou da saída da faixa), o bot usa o dash
const BOT_SIG_WALL_MELEE := 1.2              # m atrás do Ghar (além dos raios) para quem bate de perto na Muralha
const BOT_SIG_WALL_RANGED := 6.0             # m máx. atrás do Ghar para quem atira (menor que BOT_RANGED_DIST)
const BOT_SIG_SPREAD_SCAN := 25.0            # m: aliados até isto contam para escolher o lado ao espalhar
const BOT_FRONT_ARC_MAX := 100.0             # graus: teto do meio-arco da frente do monstro que o bot evita
const BOT_GROUP_CENTROID := 16.0             # m do monstro: aliados até isto entram no centro do grupo
const BOT_SOFT_AIM := 2.0                    # m: mira de skill a até isto de quem é frágil conta como perigo para ele
## Revisão 2026-11-13 (m3): nós de ascensão retunados (F5 no 45), número aqui e `%d` na descrição (padrão TWIN_FURY_ATK)
const ASC_FIRE_LORD_PCT := 9                 # Senhor das Chamas (Elementalista fogo 45): +% de dano de fogo (era 6)
const ASC_FROST_LORD_PCT := 9                # Senhora do Inverno (Elementalista gelo 45): +% de dano de gelo (era 6)
const ASC_FROST_LORD_MATK := 15              # Senhora do Inverno: +% de MATK (F5 no 45, usuário 2026-11-14: o gelo já bate no ELEMENT_CAP, +% de gelo não movia a luta; 15 -> x1,30 com --elem_stage=2)
const ASC_CRU_WRATH_ATK := 5.5               # Ira Sagrada (Paladino Cruzado 45): +% de ATK (era 5)
const ASC_TEM_RUNE_INT := 10                 # Runa do Templo (Paladino Templário 40): +INT (era 16)
const ASC_TEM_DAWN_MATK := 3                 # Aurora do Templo (Paladino Templário 45): +% de MATK (era 5 + 2 ATK)
## F5 no 45 (usuário 2026-11-14, build abaixo de 1,30 sobe): o MATK não move o Templário (3 -> 12 deu a mesma luta, dígito a dígito); a subida vai no ATK
const ASC_TEM_DAWN_ATK := 26                # Aurora do Templo: +% de ATK (10 x1,27, 18 x1,27, 26 x1,32; 80/braço, tanque druida)
## Portões só para o bot comprar (como TWIN_FURY_FLAG): sem eles o nó de 5 pontos do 45 sobrava fora da teia gasta pelo bot
## (o F5 do Templário não mexia com o MATK/ATK do nó). Usuário 2026-11-14.
const TEM_DAWN_FLAG := "pal_tem_dawn"
const FROST_LORD_FLAG := "ele_frost_lord"
## Durgash — Machado do Trono (GDD act2-boss-signatures 3.11, F-S1): marca de dividir (mark soak) numa vítima que não é o tanque
const DURGASH_AXE_POWER := 2.0              # power TOTAL (× ATK do chefe, × fúria/berserk/reforço de raide), dividido por quem está dentro.
## Calibrado 2026-11-13 (boss_probe 40 lutas, 5 sorteados): 6,0/26 s/3,5 m -> 15%; 3,0/30/4 -> 35%; 2,5/34/4 -> 35%; 2,0/34/4 -> 60%
## (sem assinatura 65%); 1 morte pelo machado a cada ~16 usos. O degrau 2,0 -> 2,5 é íngreme: o golpe não mata, mas deixa o grupo baixo.
const DURGASH_AXE_RADIUS := 4.0             # m do círculo que segue a vítima
const DURGASH_AXE_TIME := 5.0               # s do círculo até o machado cair (aviso)
const DURGASH_AXE_EVERY := 34.0             # s entre machados (recarga da skill; o 1º sai BOSS_SIG_OPEN_DELAY depois do começo)
const DURGASH_AXE_HOVER := 3.2              # apresentação: altura (m) do prop_durgash_throneaxe sobre o círculo antes de cair
## Bots nas assinaturas (sempre perfeitos, decisão do usuário 2026-11-13)
const BOT_SIG_COVER_GAP := 0.8              # m atrás da pedra (além do raio dela) na Avalanche
const BOT_SIG_SPREAD_DIST := 8.0            # m: até onde o marcado anda para espalhar (16 direções, a isto e à metade)
const BOT_SIG_SPREAD_GAP := 1.0             # m de folga entre marcas (além do touch do Cânone / soma dos raios) e da marca aos aliados
const BOT_SIG_SPREAD_REPLAN := 0.4          # s: o marcado revê o ponto se outro marcado planejou perto dele (no máx. a cada isto)
const BOT_SIG_SOAK_RANGE := 15.0            # m: bot não tanque a até isto vai dividir a marca
const BOT_SIG_SOAK_MARGIN := 1.2            # s de folga: o bot parte para a marca de dividir quando o que falta mal dá para chegar + isto
const BOT_SIG_SOAK_PAD := 0.8               # m para dentro da borda do círculo de dividir (chegou = fica)
const BOT_SIG_SOAK_HELPERS := 2            # quantos (os mais perto, fora a vítima e o tanque) vão dividir; os outros seguem no estandarte/cura
const BOT_SIG_SOAK_VICTIM_HOLD := 2.5       # s: o marcado pelo Machado do Trono só para nos últimos isto (antes cura/bate normal)
const BOT_SIG_STUN_SAVE := 0.5              # guarda o atordoar quando o canal do chefe está a menos desta fração da recarga
const BOT_SIG_ISLAND_AVOID := 6.0           # m: quem não é tanque evita a ilha a menos disto do chefe (golpe em volta dele)
const BOT_SIG_HOLD := 0.5                   # m: chegou no lugar da mecânica (para de andar e luta dali)
const BOT_SIG_PAD := 0.3                    # m de folga ao sair de faixa/anel de assinatura (vãos de 3 m: a folga dos círculos fecharia o vão)
const BOT_SIG_REACT := 1.0                  # s: bot só sai de faixa/anel que cai até isto (antes, segue lutando)
const BOT_SIG_DRAG_DIST := 4.0             # m: Têmpera na Lava, quem o Kragmar mira leva ele ao ponto livre de poça a pelo menos isto
const BOT_SIG_LOOKAHEAD := 1.5              # s: faixa/anel que cai até isto depois do perigo atual conta para escolher o lado da fuga
const BOT_DODGE_MIN_RADIUS := 1.2          # telegrafia menor que isto (golpe curto) não dá para fugir: bloqueia ou aguenta (investida: sempre foge da linha)
const PARTY_SEEK_MAX := 3                  # /party: quantos bots do mapa oferecem grupo (um convite por vez)
const PARTY_SEEK_COOLDOWN := 20.0          # s entre dois /party
const STORAGE_SLOTS := 48                  # tipos de item no depósito (cada um empilha)
const NPC_WALK_SPEED := 1.9                # m/s dos moradores que passeiam
const NPC_WAIT_MIN := 3.0                  # s parado entre um passeio e outro
const NPC_WAIT_MAX := 10.0
## Barks (game/world/ambient_life.gd): fala curta sobre a cabeça do NPC quando o jogador passa perto (só apresentação)
const BARK_RANGE := 9.0                    # m do jogador
const BARK_SCAN := 0.25                    # s entre procuras
const BARK_CHANCE := 0.35                  # chance por procura de um NPC perto falar
const BARK_TIME := 3.4                     # s na tela
const BARK_COOLDOWN_MIN := 14.0            # s até o mesmo NPC falar de novo
const BARK_COOLDOWN_MAX := 30.0
const BARK_MAX_ACTIVE := 2                 # falas ao mesmo tempo
const AMBIENT_CULL := 70.0                 # m além do raio do bando: bichos de ambiente somem e param de animar
const NPC_TALK_HOLD := 1.5                 # s que o NPC fica parado depois da conversa
## Aprimoramento (ferreiro): +1 a +9, sem quebrar. Armadura: % de DEF/MDEF e dos atributos; arma: % de ATK/MATK e dos atributos.
const PLUS_MAX := 9
const PLUS_ARMOR_PCT := 0.05               # por nível: +5% DEF e MDEF da peça (+9 = +45%)
const PLUS_WEAPON_PCT := 0.06              # por nível: +6% ATK e MATK da arma (+9 = +54%)
const PLUS_ATTR_PCT := 0.06                # por nível: +6% dos atributos da peça (arredonda; mínimo +1 a cada 3 níveis)
const PLUS_GLOW_LOW := 5                   # +5: brilho leve
const PLUS_GLOW_HIGH := 9                  # +9: brilho forte
const PLUS_GOLD_BASE := 30                 # ouro = base × (tier+1) × nível^1.5
const PLUS_STAR_FROM := 6                  # +6 em diante pede Minério Estelar (Ruínas); antes, Minério de Ferro
## Bolsa: tipos de item diferentes que cabem (pilhas). Até BAG_SLOTS bolsas vestidas ao mesmo tempo (estilo WoW, repetidas
## valem), cada uma soma BAG_SIZES[tier] (Bolsa Ampliada I-IV = bag_t0..3, `consume.bag` = tier). 2026-11-21: era consumível
## em ordem (+8 cada, máx. 72); agora 4x IV = 40 + 48 = 88.
const BAG_BASE := 40
const BAG_SLOTS := 4
const BAG_SIZES := [6, 8, 10, 12]
const GATHER_RANGE := 2.4                  # m até o ponto de colheita (F)
const GATHER_TIME := 1.1                   # s colhendo (andar, atacar ou levar dano cancela)
const GATHER_RESPAWN := 75.0               # s até o ponto voltar
const STATION_RANGE := 6.0                 # m até o NPC de serviço (depósito) para usar
const CDR_CAP := 25.0                       # % máximo de recarga a menos em todas as skills (talentos de escolha)
const PICK_SWAP_TOWN_ONLY := true           # trocar a escolha de uma linha de talentos: só na cidade (de graça)
## Necromante nv 5 (pedido do jogador 2026-11-16): "Mortos sem Pressa" e "Podridão Lenta"
const NEC_TALENT_SUMMON_TIME := 2.0         # invocações com tempo duram x2 (as permanentes seguem permanentes)
const NEC_TALENT_DOT_TIME := 1.25           # dano no tempo (mágico) do necromante dura x1,25
const NEC_TALENT_DOT_DPS := 1.15            # ... e bate x1,15 por segundo (x1,44 no total por aplicação)
## Talentos de classe, auditoria aplicada 2026-11-16 (design/balance/class-talents-audit-2026-11-16.md): trocas das linhas 5-30
const CT_SKILL_POWER := 1.2                 # "+20% de dano" das trocas por skill de nível baixo (Golpe Ardente, Arco da Fé, Garras, Lança Leve...)
const CT_OPENER_POWER := 1.25               # Faísca Viva e Tiro de Abertura (skill de nível 1-2, a linha 5 inteira dela)
const CT_PIERCE_POWER := 1.15               # Lança Fria (o atravessar já vale muito em bando)
const CT_OPENER_CD := 0.8                   # Tiro de Abertura: recarga x0,8
const CT_LUNGE_CD := 0.75                   # Investida Firme (15): Estocada x0,75 (a linha 40 dá x0,7: juntas x0,525)
const CT_AREA_MULT := 1.3                   # Bastião Vivo (raio da aura e do pulso), Nova Radiante, Brasa Viva
const CT_SPLIT_RADIUS := 1.25               # Terra Partida: Racha-Terra mais largo
const CT_SPLIT_STUN := 0.5                  # ... e atordoa (s)
const CT_SPARK_TARGETS := 3                 # Faísca Viva: atravessa até 3
const CT_ANCHOR_ROOT := 2.5                 # Âncora Pesada: Flecha Âncora prende 2,5 s (era 1,5)
const CT_PREY_TIME := 1.5                   # Presa Escolhida: Marca do Predador dura x1,5
const CT_PREY_CD := 0.8                     # ... e recarrega x0,8
const CT_DOT_EXTRA_S := 2.0                 # Garras Afiadas / Lua Crescente / Bola Ardente: dano no tempo dura +2 s (CT_DOTS)
const CT_CURSE_EXTRA_S := 2.0               # Maldição Contagiosa: +2 s (CT_CURSES)
const CT_CURSE_MULT := 1.3                  # ... e 30% mais forte
## Dano no tempo trocado pelo talento (dicionário inteiro: o efeito do talento substitui o da skill).
## Talentos que SOMAM ao que a skill já tem (base + maestria + evolução; skill_mods "add", decisão 2026-11-17)
const CT_HOLY_MEND_ADD := 0.12              # Golpe Restaurador: +12% do dano vira cura (Golpe Sagrado já cura 15-35%)
const CT_WRATH_HAMMER_ADD_S := 3.0          # Golpe Ardente: a queimadura do Martelo da Ira dura +3 s (dobra)
const CT_HAMMERS_TIME_MULT := 1.5           # Martelos Incansáveis (templário 35): os Martelos Abençoados giram 50% mais tempo
const CT_SMITE_HAMMER_ADD_S := 0.4          # Castigo: o Martelo de Luz (já atordoa 0,6 s) atordoa +0,4 s
const CT_DOTS := {
	"dru_claw": {"dps": 4, "duration": 4 + CT_DOT_EXTRA_S},          # Garras Afiadas
	"dru_moonfire": {"dps": 5, "duration": 4 + CT_DOT_EXTRA_S},      # Lua Crescente
	"ele_fireball": {"dps": 5, "duration": 3 + CT_DOT_EXTRA_S},      # Bola Ardente
	"ass_cross_slash": {"atk_pct": 12, "duration": 4.0},           # Corte em X: sangra 12% do ATK/s (como a Estocada Dupla do lanceiro)
}
const CT_CURSES := {   # Maldição Contagiosa: curse da skill x CT_CURSE_MULT e + CT_CURSE_EXTRA_S
	"nec_curse_doom": {"id": "doom", "duration": 10.0 + CT_CURSE_EXTRA_S, "taken_pct": 20 * CT_CURSE_MULT},
	"nec_curse_weakness": {"id": "weakness", "duration": 8.0 + CT_CURSE_EXTRA_S, "weaken_pct": 25 * CT_CURSE_MULT},
}
const CT_SCYTHE_HEAL := {"nec_reap": 0.3, "nec_death_spin": 0.2}    # Foice Sedenta: cura do dano em dobro (0,15 / 0,10)
const CT_FORM_HOWL := {"aspd_pct": 15}      # Uivo da Lua (form_stats): só na forma
const CT_CRUSADE_AURA := 0.6                # Aura de Cruzada (Paladino 20): força do Zelo em aura (era 0,35). Sobe porque o Cruzado perdeu
                                            # Lâmina da Fé (Zelo 50%) e Valor Eterno (Valor 40%), mortos até 18/22: death_knight solo 40/60 -> 7/40
const ATTACK_SPEED_CAP := 60.0              # % máximo de velocidade de ataque
const CHAIN_AFTER_IMPACT := 0.05            # depois do impacto, outra skill/ataque já pode sair (o quadro do golpe ainda aparece)
const HIT_STOP_FRAMES_BASIC := 2
const DASH_DISTANCE := 3.8             # 2026-11-18 playtest: era 3,2 m / 0,18 s (+19%, mesma velocidade)
const DASH_TIME := 0.2
const DASH_IFRAMES := 0.2             # s invulnerável a golpe direto depois de sair o dash (o dash inteiro; dano no tempo continua)
const DASH_SKILL_STEP := 0.25          # investida anda em passos: para em parede e rio, não salta por cima
const JUMP_VELOCITY := 6.2          # m/s para cima (Espaço): ~0,96 m de altura
const JUMP_GRAVITY := 20.0          # m/s²: ~0,62 s no ar
const DASH_COOLDOWN := 1.6
const DASH_CHARGE_WINDOW := 0.9       # com 2+ cargas: tempo entre um dash e o próximo
const POTION_COOLDOWN := 4.0
const AGGRO_LOSE_TIME := 6.0
const CORPSE_TIME := 1.6
const PACK_AGGRO_RADIUS := 6.0             # puxou um monstro: os iguais parados a até isto vêm junto (bando)
# ---- sentinelas do povoado e investidas (GuardBrain, RaidSystem) ----
const GUARD_AGGRO := 13.0                  # m: sentinela enxerga monstro
const GUARD_LEASH := 22.0                  # m: não se afasta mais que isto do posto (ou de onde a briga começou, na ronda)
const GUARD_RESPAWN := 65.0                # s até a sentinela caída voltar ao posto
const GUARD_REGEN_MULT := 3.0              # regenera mais rápido que personagem fora de combate
const GUARD_PATROL_PACE := 0.42            # fração da velocidade na ronda
const RAID_RECLAIM_MULT := 1.5           # cada fortaleza retomada (rota calada por `unless`) multiplica as levas dos fronts que sobram
const RAID_RECLAIM_EVERY := 0.8             # ... e as levas voltam 20% mais rápido
# ---- eventos de estrada (RoadEventSystem; GDD design/gdd/living-towns.md 4 e 7) ----
const EVENT_FIRST_S := 90.0               # s de presença no mapa até o 1º evento (+ sorteio de EVENT_JITTER_S)
const EVENT_EVERY_S := 240.0              # s entre eventos (+ sorteio): um a cada 4-7 min
const EVENT_JITTER_S := 180.0
const EVENT_RETRY_S := 30.0               # sem ponto válido: tenta de novo
const EVENT_NEAR_M := 35.0                # o ponto nasce a esta distância do jogador... (fora da tela, mas audível)
const EVENT_FAR_M := 70.0                 # ...até esta
const EVENT_POINT_CD_S := 600.0           # recarga do ponto
const EVENT_LIFETIME := 120.0             # s sem ninguém por perto até expirar
const EVENT_RESOLVE_S := 90.0             # s para resolver depois que alguém chega
const EVENT_ENGAGE_M := 30.0              # "chegou": personagem a esta distância do ponto
const EVENT_LEASH_M := 30.0               # monstro do evento não persegue além disto
const EVENT_MAX_MOBS := 4                 # teto de monstros por evento
const EVENT_MOB_SCALE := 0.8              # quanto a vida/ataque caem quando o nível do ponto é menor que o do monstro (0 = nada, 1 = proporcional)
const EVENT_XP_FRAC := 0.04               # XP do evento = fração do nível (acima de 0,06 vira farm)
const EVENT_COIN_BASE := 5
const EVENT_COIN_PER_LV := 2
const EVENT_BOT_GRACE := 25.0             # s em que o evento é só do jogador (bots esperam)
const EVENT_LEAVE_S := 12.0               # s que o NPC do evento leva indo embora antes de sumir
const RAID_WAVE_CAP := 50                   # teto de invasores por leva (FPS)
## Último front (as outras duas fortalezas retomadas): o cerco joga tudo nele. Leva x isto (além da fúria), teto
## próprio e um líder elite (RAIDS[..]["leader"]). Antes a Torre vinha com ~54 e era espalhada pelos reforços (2026-11-10).
const RAID_LAST_FRONT_MULT := 2.0
const RAID_WAVE_CAP_LAST := 80
## Reforços de cada fortaleza retomada no Bastião (WorldState): eram até 8 de 2.000-3.000 de vida por fortaleza.
const REINFORCE_MAX := 3
const RAID_SORTIE_COOLDOWN := 180.0         # s entre surtidas da catedral (MapDef.sortie)
const RAID_SORTIE_LINGER := 40.0            # s que a surtida leva para voltar e sumir depois da leva
const RAID_MUSTER := 12.0                  # s que a leva espera na garganta (trompas) antes de descer
const RAID_MARCH_PACE := 0.6               # fração da velocidade na marcha (na luta e no recuo, cheia)
# defesa do povoado (BotBrain._defend) e Bastião (RaidSystem._rally: aventureiros perto das muralhas na investida)
const RAID_DEFEND_RANGE := 90.0            # m do povoado: bot mais perto que isto pode largar a caça e defender
const RAID_DEFEND_CHANCE := 0.8            # por leva, cada bot no alcance decide uma vez
const RAID_DEFEND_LEASH := 20.0            # m além da muralha que o defensor persegue um invasor
const RAID_DEFEND_FALLBACK := 0.35         # vida: defensor recua para dentro, atrás das sentinelas...
const RAID_DEFEND_RETURN := 0.7            # ...e volta ao portão com esta vida
const RAID_RALLY_MARGIN := 8.0             # m além da muralha onde vale o Bastião
const RAID_RALLY_DEF_PCT := 40.0           # Bastião: +% defesa física e mágica
const RAID_RALLY_REGEN := 0.015            # Bastião: fração da vida máxima por segundo
# força da investida pelo nível do jogador no mapa: um passo por nível acima de RAID_SCALE_FROM, até RAID_SCALE_TO
# (cada passo: +1 nível e os % abaixo nos invasores; levas ganham reforço em MapsCatalog.RAIDS["scale_extra"])
const RAID_SCALE_FROM := 15
const RAID_SCALE_TO := 20
## Teto por mapa (no lugar de RAID_SCALE_TO): o Bastião (faixa 20-30) acompanha o jogador até o 30 (2026-11-21).
const RAID_SCALE_TO_MAP := {"field_ruins": 30}
## Mapas em que todas as rotas atacam juntas: relógio único (m["raid_sync"]) que só anda sem leva viva; ao zerar,
## todas as rotas que valem soltam a leva no mesmo tick (RaidSystem.update_raids). Intervalo x RAID_RECLAIM_EVERY^k.
const RAID_SYNC_MAPS := {"field_ruins": {"first": 90.0, "every": 240.0, "jitter": 30.0}}
## Teto de invasores por leva por mapa (no lugar de RAID_WAVE_CAP; o último front segue em RAID_WAVE_CAP_LAST).
const RAID_WAVE_CAP_MAP := {"field_ruins": 80}
const RAID_SCALE_HP_PCT := 8.0
const RAID_SCALE_ATK_PCT := 6.0
const RAID_SCALE_DEF_PCT := 6.0
const RAID_SCALE_XP_PCT := 8.0
const BOT_MED_POTION_LEVEL := 8            # bot daqui para cima usa e compra as poções (M) (35%)
const DORMANT_RANGE := 40.0                # monstro sem alvo e sem personagem a até isto dorme (não pensa/anda; custo da sim)
const PLAYER_RESPAWN_TIME := 3.0
const RESPAWN_SHARE := 0.5                 # renasce com metade da vida e da mana
const LEVEL_UP_RESTORE := 0.3              # subir de nível devolve 30% da vida e da mana
const REGEN_HP_PCT := 0.02                 # fora de combate: % da vida por segundo
const REGEN_MP_PCT := 0.015                # fora de combate: % da mana por segundo (+ REGEN_MP_FLAT)
const REGEN_MP_FLAT := 1.0
## Joias de mana (pedido do jogador 2026-11-16: "o Berserker fica sem mana"; tools/tests/mana_probe.tscn). Por tier de
## COMMON_TIER_LEVELS [1, 8, 16, 24, 32, 40, 48]; nos temas corpo a corpo (GearCatalog.THEMES). Amuleto: % da mana máxima a cada
## abate (Stats.mp_on_kill). Capa: % da mana máxima por s a mais só em combate (Stats.mp_regen_combat). Anéis ficam sem.
const MANA_ACC_THEMES := ["guerreiro", "cacador"]
const MANA_KILL_PCT := [4.0, 5.0, 6.0, 7.0, 8.0, 10.0, 12.0]     # 48 = k45
const MANA_KILL_PCT_K45 := 12.0
const MANA_COMBAT_REGEN := [0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 1.0]
const MANA_COMBAT_REGEN_K45 := 1.0
## Sábio: a mana do tema fica no amuleto, regen em combate (% da mana máxima por s; base REGEN_MP_PCT 1,5). Spec acessórios F5.
const MANA_SAGE_THEMES := ["sabio"]
const MANA_SAGE_REGEN := [0.15, 0.2, 0.25, 0.3, 0.35, 0.4, 0.5]
const MANA_SAGE_REGEN_K45 := 0.5
## Acessórios (capa, amuleto, anel; spec production/qa/accessory-rework-spec-2026-11-17.md). Atributo = linear de hoje no nível
## ACC_CURVE_REF_LEVEL (t2) x GROWTH^((nível - REF) / STEP): ~+50% por tier, nenhum tier abaixo da fórmula linear antiga.
const ACC_CURVE_REF_LEVEL := 16.0          # F1/F2: nível onde a curva nova = a linear antiga (fixo por decisão)
const ACC_CURVE_GROWTH := 1.5              # F1/F2: x por passo (faixa segura 1,4-1,6)
const ACC_CURVE_STEP := 8.0                # F1/F2: níveis por passo (= distância entre tiers)
const ACC_RING_ATK := [0, 1, 2, 3, 4, 5, 6]   # (48 = k45) F3: ATK plano (guerreiro/caçador) ou MATK (sábio) do anel por tier (spec; alavanca 3/3/4 desfeita 2026-11-17)
const ACC_RING_ATK_K45 := 6
const ACC_AMULET_HP_PCT := [1.0, 1.5, 2.0, 2.5, 3.0, 3.0, 3.0]   # F4: vida % do amuleto (todos os temas), por tier
const ACC_AMULET_HP_PCT_K45 := 3.0
const ACC_UNIQUE_MULT := 1.25              # F6: único = x a comum do mesmo slot e nível...
const ACC_UNIQUE_NEXT_CAP := 0.9           # ...limitado a x a comum do tier seguinte
## Acessórios lendários por build (spec production/qa/legendary-accessories-spec-2026-11-16.md, re-base da rev2 dos acessórios):
## Manto/Medalhão/Anel/Sinete nos níveis ACT2_SET_LEVELS; atributos/DEF pela curva F1/F2 x LEGENDARY_MULT; papéis e mana no valor k45.
## LEG_ACC_STEP = valor de cada stat por nível de ACT2_SET_LEVELS [35, 40, 45, 50] (50 = 45 + passo do 40->45, Ato III §6.4);
## LEG_ACC_BUILDS = stat de cada peça por build.
const LEG_ACC_PIECES := ["cape", "amulet", "ring", "signet"]
const LEG_ACC_STEP := {
	"atk_pct": [1.5, 2.0, 2.5, 3.0], "matk_pct": [1.5, 2.0, 2.5, 3.0], "aspd_pct": [2.5, 3.0, 4.0, 5.0], "crit": [1.5, 2.0, 2.5, 3.0],
	"crit_dmg_pct": [5.0, 6.5, 8.0, 9.5], "lifesteal": [1.0, 1.5, 2.0, 2.5], "hp_pct": [3.0, 4.0, 5.0, 6.0], "def_pct": [3.0, 4.0, 5.0, 6.0],
	"dr_pct": [2.0, 2.5, 3.0, 3.5], "block": [2.0, 3.0, 4.0, 5.0], "evasion": [1.5, 2.0, 2.5, 3.0], "threat_pct": [10.0, 15.0, 20.0, 25.0],
	"heal_pct": [3.0, 4.0, 5.0, 6.0], "buff_pct": [6.0, 8.0, 10.0, 12.0], "radiance": [2.0, 3.0, 4.0, 5.0], "pet_pct": [5.0, 6.5, 8.0, 9.5],
	"fire_pct": [2.5, 3.0, 4.0, 5.0], "frost_pct": [2.5, 3.0, 4.0, 5.0], "storm_pct": [2.5, 3.0, 4.0, 5.0], "backstab": [4.0, 5.0, 6.0, 7.0],
	"cdr": [1.5, 2.0, 2.5, 3.0], "speed_pct": [3.0, 4.0, 5.0, 6.0], "dot_pct": [6.0, 8.0, 10.0, 12.0], "cc_resist_pct": [10.0, 15.0, 20.0, 25.0],
	"mp_cost_pct": [4.0, 5.0, 6.0, 7.0], "summon_time_pct": [10.0, 15.0, 20.0, 25.0],
}
const LEG_ACC_BUILDS := {
	"guardiao": {"cape": "dr_pct", "amulet": "threat_pct", "ring": "block", "signet": "cc_resist_pct"},
	"cruzado": {"cape": "cc_resist_pct", "amulet": "atk_pct", "ring": "crit_dmg_pct", "signet": "mp_cost_pct"},
	"templario": {"cape": "block", "amulet": "atk_pct", "ring": "crit", "signet": "crit_dmg_pct"},
	"carniceiro": {"cape": "lifesteal", "amulet": "aspd_pct", "ring": "crit", "signet": "mp_cost_pct"},
	"executor": {"cape": "hp_pct", "amulet": "atk_pct", "ring": "crit_dmg_pct", "signet": "cc_resist_pct"},
	"punhos": {"cape": "evasion", "amulet": "aspd_pct", "ring": "crit", "signet": "lifesteal"},
	"sacerdote": {"cape": "mp_cost_pct", "amulet": "heal_pct", "ring": "buff_pct", "signet": "radiance"},
	"inquisidor": {"cape": "mp_cost_pct", "amulet": "matk_pct", "ring": "radiance", "signet": "crit_dmg_pct"},
	"batalha": {"cape": "block", "amulet": "atk_pct", "ring": "heal_pct", "signet": "buff_pct"},
	"guardiao_verde": {"cape": "dr_pct", "amulet": "threat_pct", "ring": "hp_pct", "signet": "cc_resist_pct"},
	"fera": {"cape": "lifesteal", "amulet": "atk_pct", "ring": "aspd_pct", "signet": "dot_pct"},
	"xama": {"cape": "mp_cost_pct", "amulet": "pet_pct", "ring": "summon_time_pct", "signet": "buff_pct"},
	"cacador": {"cape": "evasion", "amulet": "pet_pct", "ring": "atk_pct", "signet": "crit"},
	"atirador": {"cape": "speed_pct", "amulet": "atk_pct", "ring": "crit_dmg_pct", "signet": "cdr"},
	"lanceiro": {"cape": "hp_pct", "amulet": "atk_pct", "ring": "dot_pct", "signet": "evasion"},
	"laminas": {"cape": "evasion", "amulet": "backstab", "ring": "dot_pct", "signet": "crit_dmg_pct"},
	"duelista": {"cape": "def_pct", "amulet": "atk_pct", "ring": "crit", "signet": "crit_dmg_pct"},
	"corsario": {"cape": "def_pct", "amulet": "crit", "ring": "crit_dmg_pct", "signet": "cdr"},
	"fogo": {"cape": "mp_cost_pct", "amulet": "fire_pct", "ring": "dot_pct", "signet": "crit_dmg_pct"},
	"gelo": {"cape": "hp_pct", "amulet": "frost_pct", "ring": "matk_pct", "signet": "mp_cost_pct"},
	"raio": {"cape": "mp_cost_pct", "amulet": "storm_pct", "ring": "crit", "signet": "crit_dmg_pct"},
	"invocador": {"cape": "mp_cost_pct", "amulet": "pet_pct", "ring": "summon_time_pct", "signet": "matk_pct"},
	"ceifador": {"cape": "lifesteal", "amulet": "matk_pct", "ring": "crit_dmg_pct", "signet": "cc_resist_pct"},
	"pestilento": {"cape": "mp_cost_pct", "amulet": "dot_pct", "ring": "matk_pct", "signet": "cdr"},
}
const LEG_ACC_BUILD_MULT := {}            # ajuste fino por build (sem entrada = 1,0); F-LA1: G_acc > 0,08 = baixar
const LEG_ACC_DROP_SHARE := 0.25          # chance do lendário sorteado no 35/40/45/50 ser um acessório (como SHIELD_LEGENDARY_SHARE)
## Stats novos dos acessórios lendários (spec §3): tetos.
const CRIT_DMG_CAP := 40.0                # % a mais no multiplicador do crítico (CRIT_MULT 1,5 -> até 1,9)
const DOT_PCT_CAP := 60.0                 # % a mais de dano no tempo que você aplica
const CC_RESIST_CAP := 50.0               # % a menos de duração de atordoar/prender/lentidão em você
const MP_COST_CAP := 30.0                 # % a menos de custo de mana das skills
const SUMMON_TIME_CAP := 60.0             # % a mais de duração das invocações com tempo
const HIT_FLASH_TIME := 0.12               # piscada branca de quem apanha
const NOTICE_CD := 3.0                     # aviso repetido (bolsa cheia ao pisar no baú) espera isto
const ENTITY_RADIUS := 0.45

# --- equipamento gerado (data/catalog/gear_catalog.gd) ---
# poder de item escala com o nível: fator = (nível + OFFSET) / (REF + OFFSET); nível REF = valores-base da tabela
const GEAR_REF_LEVEL := 24.0
const GEAR_LEVEL_OFFSET := 4.0
const GEAR_ATTR_PRIMARY_PER_LEVEL := 0.62     # pontos do atributo principal por nível (peça de peso 1)
const GEAR_ATTR_SECONDARY_PER_LEVEL := 0.3
const COMMON_TIER_LEVELS := [1, 8, 16, 24, 32, 40, 48]     # 32 e 40: Ato II (GDD F10); 48: Ato III (§6.3)
## Preços e números dos catálogos (antes soltos em gear/items/skills_catalog, game_data e stats; mesmos valores)
const STARTER_WEAPON_PRICES := [40, 220, 700, 1800]     # armas comuns escritas à mão, por tier (COMMON_TIER_LEVELS)
const STARTER_ARMOR_PRICES := [30, 180, 600, 1500]
const GEAR_PRICE_BASE := 20.0                # equipamento gerado: (base + nível² x isto) x peso da peça x mult
const GEAR_PRICE_PER_LV2 := 2.5
const LEGEND_MATK_FROM_ATK := 0.9            # arma lendária de build mágica: MATK no mínimo isto x ATK
const PLUS_PRICE_PCT := 0.25                 # cada +N do aprimoramento: +25% no preço
const MASTERY_POWER_PER_LV := 0.12           # maestria padrão por nível: +12% poder, -4% MP, -5% recarga
const MASTERY_MP_PER_LV := 0.04
const MASTERY_CD_PER_LV := 0.05
const ATK_BASE := 4.0                        # ATK e MATK de todo personagem: base + nível x isto
const ATK_PER_LEVEL := 0.8
const PATK_PER_FOR_RANGED := 0.3             # arco/rifle: FOR ajuda o ATK físico só isto por ponto (antiga escala)
const PATK_FOR_DAGGER_SHARE := 0.6           # adaga e garra: a FOR vale isto do normal (a AGI pesa mais)
const LEG_FRENZY_TIME := 4.0                 # s das cargas do Frenesi (arma lendária dos Gêmeos)
const LEG_DOT_TIME := 3.0                    # s do sangramento/veneno das armas lendárias (Fera, Lâminas)
const OFFHAND_WEAPON_ATK_MULT := 0.6          # empunhando duas: a 2ª arma soma 60% do ATK (atributos inteiros)

# --- lendários: um conjunto por classe a cada 5 níveis ---
const GEAR_DROP_CHANCE := 0.02                # calça/capa/amuleto/anel comum, por monstro morto
const GEAR_DROP_CHANCE_BOSS := 0.5
const GEAR_SHOP_TIERS := 2                    # mercador vende esses tiers; os de cima só caem de monstro
const LEGENDARY_LEVELS := [5, 10, 15, 20, 25, 30, 35, 40, 45, 50]     # 35, 40 e 45: Ato II (GDD F10); 50: Ato III (§6.3, tier 9, 10 moedas)
const LEGENDARY_MULT := 1.2                   # ATK/DEF/atributos vs. item comum do mesmo nível
const LEGENDARY_DROP_CHANCE := 0.01           # por monstro morto (1 em 100); cada membro do grupo rola o seu
const LEGENDARY_DROP_CHANCE_BOSS := 0.4
## Arma lendária: efeito próprio da build (`legend` da build + LEGEND_NUMBERS acima); aqui só os limites comuns
const LEG_THORNS_RANGE := 4.0
## Armas lendárias com papel (Paladino e Clérigo de Batalha; GearCatalog.WEAPON_ROLES): espada/montante ataca, maça/martelo
## defende, escudo do conjunto dá utilidade. Números [base, por tier] como LEGEND_NUMBERS.
const LEG_SWORD_ATK_MULT := 1.08            # espada/montante do conjunto: ATK x isto (sem MATK)
const LEG_HAMMER_ATK_MULT := 1.25           # martelo de ataque do Templário (maça, papel "offense"): 38 x 1,25 = 47,5 = a espada de ataque (44 x 1,08)
const LEG_MACE_DEF_PER_ATK := 0.4           # maça/martelo do conjunto: DEF = ATK dela x isto (MATK 0)
const LEG_BATTLE_MACE_ATK_MULT := 1.1       # maça do Clérigo de Batalha: troca o MATK por ATK x isto (e DEF)
const LEG_ROLE_NUMBERS := {
	"bulwark": {"pct": [3, 0.6], "icd": 4.0, "time": 5.0},     # Baluarte (maça): golpe dá barreira de pct% da vida máx.; 1 a cada icd s; dura time s
	"determination": {"max": 5, "dmg": [2, 0.1], "heal": [3, 0.15], "icd": 2.0, "time": 6.0},   # Determinação (escudo): por carga +dmg% dano, +heal% cura recebida
}
const LEG_BULWARK_BUFF := "legend_bulwark"
const LEG_DETERMINATION_BUFF := "legend_determination"
const LEG_RIPOSTE_RANGE := 4.0             # contra-ataque só em quem bate de perto
const LEG_CHAIN_RANGE := 6.0               # salto do básico (corrente) até o próximo inimigo
const LEG_WARD_TIME := 6.0
const MEND_SELF_MULT := 0.4               # Clérigo de Batalha: golpe que cura (mend) rende só isto quando o mais ferido é você
const LEG_SHOT_ICD := 1.2                  # Bala na Agulha (Corsário): no máximo um tiro de graça a cada isto
## Bravata (Corsário): cargas em você ("combo_gain" das skills, até MAX, somem em TIME s sem ganhar outra);
## "combo_spend" (Tiro Entre os Olhos) gasta todas de uma vez
const BRAVADO_BUFF := "bravado"
const BRAVADO_MAX := 5
const BRAVADO_TIME := 12.0
const LEG_PENANCE_TIME := 5.0              # Penitência (Templário): cargas no alvo somem sem golpe por este tempo
const LEG_WOUND_TIME := 5.0                 # Ferida Aberta (Lanceiro): feridas no alvo somem juntas sem golpe por este tempo
## Lendários do 50 (design/gdd/ato3-lendarios-50.md, onda 0): toda peça do conjunto de build do 50 tem efeito próprio
## (ItemDef.piece_fx, de GearCatalog.LEG50 + LEG50_NUMBERS; regras em PieceEffects). Cada peça vale sozinha; efeito que cita
## skill só age se o personagem a tem. Números SÓ aqui: LEG50_NUMBERS[<build>][<peça>] = {x, y, icd} (no GDD "LEG50_<BUILD>_<PEÇA>").
## Orçamento F-L50a: armadura 0,01-0,03, arma 0,02-0,04, mão sec. 0,01-0,02, soma <= LEG50_GAIN_MAX (boss_probe --l50_off=all).
const LEG50_LEVEL := 50
const LEG50_GAIN_MAX := 0.12
const LEG50_CHARGE_BONUS := 1                 # luvas de Cargas com o nó da teia já comprado: +1 carga...
const LEG50_CHARGE_CAP := 4                   # ... até isto (sem o nó: SKILL_CHARGE_MAX)
const LEG50_MANA_GUARD_CAP_ADD := 10.0        # teto da Barreira de Mana sobe no máximo isto (30 -> 40)
const LEG50_MANA_EFF_CAP := 0.5               # 1 MP da Barreira absorve no máximo 1 + isto de dano
const LEG50_ALLY_RANGE := 8.0                 # alcance dos efeitos de grupo das peças
const LEG50_TRIGGER_ICD := 6.0                # recarga padrão de on_trigger sem "icd"
const LEG50_BOT_TRIGGER_BIAS := 1.25          # bot: peso a mais da skill que dispara um efeito de peça vestida
const LEG50_FOE_RANGE := 4.0                  # despertares que saltam para o inimigo mais perto (Lanceiro, Praga)
const LEG50_STUN_SPLASH := 3.0                # Julgamento Desperto: raio do atordoar em volta do alvo...
const LEG50_STUN_SPLASH_MAX := 2              # ... em até tantos inimigos comuns (chefe nunca)
const LEG50_WAVE_RADIUS := 3.0                # Baluarte Desperto (Cruzado): raio da onda quando a barreira quebra
const LEG50_FIST_SPLASH := 2.0                # Punho Vingativo Desperto: raio do contra-ataque em volta
const LEG50_LOW_HP := 0.35                    # Égide Desperta: aliado abaixo disto da vida ganha a Égide maior
const LEG50_PENANCE_MIN := 3                  # Penitência nunca explode com menos cargas que isto
const LEG50_ZONE_RADIUS := 2.5                # chão deixado por despertar/peça sem raio próprio
const LEG50_CAST_RANGE := 12.0                # gatilho que lança skill no inimigo mais perto: alcance da busca
const LEG50_NUMBERS := {
	"guardiao": {"head": {"x": 2}, "body": {"x": 6.0}, "legs": {"x": 5.0}, "boots": {"x": 2.0, "icd": 4.0},
		"weapon": {"x": 1}, "weapon2": {"x": 50.0}, "offhand": {"x": 3.0, "icd": 12.0}},
	"cruzado": {"head": {"x": 5.0}, "body": {"x": 10.0}, "legs": {"x": 5.0}, "boots": {"x": 5.0, "y": 3.0, "icd": 4.0},
		"weapon": {"x": 0.6}, "weapon2": {"x": 60.0}},
	"templario": {"head": {"x": 1}, "body": {"x": 1}, "legs": {"x": 4.0}, "boots": {"x": 1, "icd": 0.0},
		"weapon": {"x": 4.0}, "weapon2": {"x": 1}, "offhand": {"x": 2.0}},
	"carniceiro": {"head": {"x": 1}, "body": {"x": 6.0}, "legs": {"x": 6.0}, "boots": {"x": 5, "icd": 6.0},
		"weapon": {"x": 10.0, "y": 40.0}, "offhand": {"x": 3.0}},
	"executor": {"head": {"x": 3.0}, "body": {"x": 5.0}, "legs": {"x": 1}, "boots": {"icd": 15.0}, "weapon": {"x": 1}},
	"punhos": {"head": {"x": 2.0, "y": 1.0, "icd": 3.0}, "body": {"x": 3.0}, "legs": {"x": 15.0}, "boots": {"x": 1, "icd": 4.0},
		"weapon": {"x": 40.0}, "offhand": {"x": 3.0}},
	"sacerdote": {"head": {"x": 8.0}, "body": {"x": 1}, "legs": {"x": 0.4}, "boots": {"icd": 6.0}, "weapon": {"x": 100.0}, "offhand": {"x": 2.0}},
	"inquisidor": {"head": {"x": 4.0, "y": 4.0}, "legs": {"x": 8.0}, "gloves": {"x": 5.0}, "boots": {"x": 12.0}, "weapon": {"x": 25.0}},
	"batalha": {"head": {"x": 3.0}, "body": {"x": 3.0}, "legs": {"x": 4.0}, "boots": {"x": 0.25, "y": 4.0}, "weapon": {"x": 8.0},
		"offhand": {"x": 4.0, "icd": 12.0}},
	"guardiao_verde": {"head": {"x": 5.0}, "body": {"x": 6.0}, "legs": {"x": 15.0}, "boots": {"x": 5.0, "icd": 0.0}, "weapon": {"x": 1}},
	"fera": {"head": {"x": 6.0}, "body": {"x": 15.0}, "legs": {"x": 5.0}, "boots": {"icd": 4.0}, "weapon": {"x": 2}, "offhand": {"x": 3.0}},
	"xama": {"head": {"x": 6.0}, "body": {"x": 15.0}, "legs": {"x": 8.0}, "boots": {"x": 0.25, "y": 5.0}, "weapon": {"x": 40.0}},
	"cacador": {"head": {"x": 3.0}, "body": {"x": 6.0}, "legs": {"x": 10.0}, "boots": {"x": 60.0, "icd": 8.0}, "weapon": {"x": 15.0}},
	"atirador": {"head": {"x": 5.0}, "body": {"x": 1}, "legs": {"x": 8.0}, "boots": {"x": 2.0, "icd": 0.0}, "weapon": {"x": 1.0}},
	"lanceiro": {"head": {"x": 1}, "body": {"x": 2.0}, "legs": {"x": 10.0}, "boots": {"icd": 0.0}, "weapon": {"x": 50.0}},
	"laminas": {"head": {"x": 6.0}, "body": {"x": 6.0}, "legs": {"x": 3.0}, "boots": {"x": 10.0, "icd": 0.0}, "weapon": {"x": 2.0},
		"offhand": {"x": 4.0}},
	"duelista": {"head": {"x": 1}, "body": {"x": 4.0}, "legs": {"x": 0.25}, "boots": {"x": 1.5, "icd": 0.0}, "weapon": {"x": 20.0},
		"offhand": {"x": 1}},
	"corsario": {"head": {"x": 1}, "body": {"x": 4.0}, "legs": {"x": 6.0}, "boots": {"x": 1}, "weapon": {"x": 5.0, "y": 0.3},
		"offhand": {"x": 40.0, "icd": 0.0}},
	"fogo": {"head": {"x": 6.0, "y": 5.0}, "body": {"x": 4.0}, "legs": {"x": 15.0}, "boots": {"x": 1}, "weapon": {"x": 2.0}},
	"gelo": {"head": {"x": 0.25}, "body": {"x": 5.0}, "legs": {"x": 10.0}, "boots": {"x": 60.0, "icd": 0.0}, "weapon": {"x": 4.0, "y": 25.0}},
	"raio": {"head": {"x": 4.0, "y": 0.3}, "body": {"x": 3.0}, "legs": {"x": 4.0}, "boots": {"x": 1.0, "icd": 0.0}, "weapon": {"x": 1}},
	"invocador": {"head": {"x": 6.0}, "body": {"x": 5.0}, "legs": {"x": 12.0}, "boots": {"x": 12.0, "icd": 0.0}, "weapon": {"x": 3.0, "y": 25.0}},
	"ceifador": {"head": {"x": 5.0}, "body": {"x": 5.0}, "legs": {"x": 5.0}, "boots": {"x": 1.0, "icd": 0.0}, "weapon": {"x": 3.0}},
	"pestilento": {"head": {"x": 6.0}, "body": {"x": 2.0}, "legs": {"x": 5.0}, "boots": {"x": 20.0}, "weapon": {"icd": 0.0}},
}
const PLUS_ELF_LEVEL := 20                  # lendário deste nível (Glória) aprimora com materiais élficos
const PLUS_ELF_GOLD_MULT := 0.6
const PLUS_DAWN_LEVEL := 25                 # lendário 25+ (Bastião da Aurora) aprimora com Prata Consagrada e Fragmento da Aurora
const PLUS_DAWN_GOLD_MULT := 0.6
const PLUS_KHARZUN_LEVEL := 40              # lendário 40+ (Monte Kharzun, D11): Aço Anão até +5 e Brasa de Kharzun do +6 em diante
const PLUS_KHARZUN_GOLD_MULT := 0.6
const PLUS_KHARZUN_STEEL := "dwarf_steel"
const PLUS_KHARZUN_EMBER := "kharzun_ember_core"
const KHARZUN_JEWEL_LEVEL := 45              # joias/capas de Kharzun (receita com troféu de chefe)
const KHARZUN_JEWEL_MULT := 1.1               # sobre a peça comum do mesmo nível: o troféu pesa
const KHARZUN_JEWEL_GOLD := 1500              # ouro da receita (tier 40 cobra 720)
const PLUS_KHARZUN_SMITHS := ["dwarf_smith", "lumeria_dwarf_smith"]   # só os Ferreiros Anões (Thrain no Kharzun, Balin em Lumeria, D13) aprimoram o lendário 40+
const LEGENDARY_COINS_BOSS := 2              # chefe (e Rei) solta 2 moedas lendárias; monstro comum, 1
## O lendário cai como Moeda Lendária; a Relicária troca: peça do tier i (LEGENDARY_LEVELS) custa i+1 moedas
const LEGENDARY_START_MAP := "city_aldara"     # primeiro mapa: o 1º conjunto (tier de LEGENDARY_LEVELS[0]) cai mais
const LEGENDARY_START_MAP_CHANCE := 0.04       # por monstro comum (1 em 25) no primeiro mapa, só no 1º tier
const LEGENDARY_LEVEL_SLACK := 2              # monstro nível N dropa o tier mais alto <= N + slack
# bônus de conjunto (tier = índice em LEGENDARY_LEVELS). Atributos lineares no tier; os percentuais (4 e 5 peças,
# "favor") usam set_pct_tier: acima de SET_PCT_FULL_TIERS crescem SET_PCT_LATE_RATE por tier (GDD Ato II F10)
const SET_PCT_FULL_TIERS := 5
const SET_PCT_LATE_RATE := 0.5
const SET_2PC_ATTR_BASE := 1                  # 2 peças: +atributo secundário
const SET_2PC_ATTR_PER_TIER := 1
const SET_3PC_ATTR_BASE := 2                  # 3 peças: +atributo principal (ex.: INT +2)
const SET_3PC_ATTR_PER_TIER := 1
const SET_4PC_SKILL_DMG_BASE := 20.0          # 4 peças: skill assinatura +20% (ex.: Bola de Fogo)
const SET_4PC_SKILL_DMG_PER_TIER := 4.0
const SET_5PC_STAT_PCT_BASE := 6.0            # 5 peças: +% no stat da classe
const SET_5PC_STAT_PCT_PER_TIER := 2.0
const SET_5PC_CDR_BASE := 10.0                # 5 peças: -% de recarga de outra skill
const SET_5PC_CDR_PER_TIER := 2.0
## Conjuntos híbridos (GDD Ato II R7.1; Fusões: design/gdd/ato2-proposals-2026-11-11.md §1). Um por par de builds da
## classe (A+B, B+C, C+A) em cada nível abaixo; o índice do tier segue LEGENDARY_LEVELS (35 = 6, 40 = 7, 45 = 8: legend_tier).
## Nível acima do MAX_LEVEL fica nos dados mas não cai nem aparece na Relicária (ItemSystem.relic_levels).
const HYBRID_LEVELS := [35, 40, 45]          # Ato III D6: híbridos e Ápice NÃO vão ao 50 (parte 2 decide)
## Níveis com a malha do Ato II (GearCatalog.ACT2_VISUALS: "colors"/"accents"/"glows" na ordem desta lista) e com acessórios
## lendários (Manto/Medalhão/Anel/Sinete). 50 = Ato III parte 1 (D6: só conjunto da build e acessórios, sem híbrido/Ápice).
const ACT2_SET_LEVELS := [35, 40, 45, 50]
const HYBRID_4PC_SHARE := 0.5                 # 4 peças: a skill de A e a de B, cada uma com esta fração do bônus de 4 peças
## Fusão (5 peças do híbrido, no lugar do 5 peças normal). Números F-FUS1: valor(i) = v35 + passo × (i − 6).
## Orçamento F-FUS2: |G_fus − G_5n| ≤ FUSION_TOL e G_fus ≤ FUSION_GAIN_MAX (G medido com boss_probe --set).
const FUSION_TOL := 0.02
const FUSION_GAIN_MAX := 0.12
const FUSION_AMBUSH_MAX := 2.0                # Ápice das Lâminas: teto da facada "furtiva"
const FUSION_POST_RADIUS := 5.0               # Ápice do Atirador: aliados a isto da torreta regeneram
const FUSION_AURORA_TIME := 4.0               # Ápice Iluminado: s da Aurora depois de cada magia sagrada
const FUSION_FRENZY_MAX := 5                  # Ápice do Carniceiro: cargas do Frenesi da Tormenta
const FUSION_COUNTER_ICD := 1.0               # Ápice dos Punhos: recarga do contra-ataque por crítico
const FUSION_GHOST_TIME := 3.0                # Ápice das Lâminas: s que a próxima facada fica "furtiva"
const FUSION_BRAVADO_ICD := 1.0               # Ápice do Corsário: crítico com espada dá Bravata no máximo a cada isto
const FUSION_BLOCK_ICD := 1.0                 # P3: Penitência no atacante ao bloquear
const FUSION_OATH_FROM_PEN := 2               # P3: a Penitência que explode dá isto de Juramento
const FUSION_GRACE_HITS := 3                  # Bi3: a cada isto de golpes de maça a Graça dispara
const FUSION_WARD_TIME := 4.0
const FUSION_MOON_TIME := 4.0                 # Ápice do Xamã: s da marca do Fogo Lunar
const FUSION_BURST_RADIUS := 2.5              # P3: área da explosão da Penitência sem a arma do Templário
const FUSION_BARK_RANGE := 12.0               # Ápice do Urso: alcance da Casca no aliado mais ferido
const FUSION_AGONY_POWER := 0.5               # N3: Agonia das invocações a esta fração
const FUSION_CURSE_MAX := 3                   # N2/N3: maldições que contam
const FUSION_PLAGUE_TIME := 6.0               # N2: s da Praga Menor (golpe de foice)
const FUSION_PLAGUE_MAX := 3                  # N2: cargas da Praga Menor
const FUSION_SHOCK_TIME := 2.0                # E2/E3: alvo "eletrificado" por isto depois de um golpe de raio
const FUSION_SPREAD_RANGE := 4.0              # E3: queimadura espalha para inimigos a esta distância
const FUSION_SPREAD_MAX := 3
const FUSION_VAPOR_SLOW := 30.0               # E1: vapor deixa 30% mais lento por 2 s
const FUSION_MINION_MEND_RANGE := 13.0        # N1
const FUSION_FOCUS_TIME := 6.0                # Ápice do Duelista: s do Foco da Cadência cheia
const FUSION_JUMP_RANGE := 5.0                # E2: salto extra do raio
const FUSION_VAPOR_RADIUS := 2.0              # E1
const FUSION_VAPOR_TIME := 2.0
const FUSION_VAPOR_ICD := 2.0               # E1: s entre Vapores disparados por FOGO em alvo retardado (o de gelo não tem recarga)
const FUSION_STATE_MAX := 64                  # chaves de estado da Fusão por personagem antes de limpar as vencidas
## [v35, passo] por Fusão (id "<build A>+<build B>"; as 8 que ficaram: P3, Bi3, Elementalista, Necromante); número solto = fixo.
const FUSION_NUMBERS := {
	"templario+guardiao": {"pen_pct": [80.0, 6.0]},
	"batalha+sacerdote": {"ward": [6.0, 0.6]},
	"fogo+gelo": {"quench": [670.0, 30.0]},
	"gelo+raio": {"super": [10.0, 1.0]},
	"raio+fogo": {"spread": [60.0, 5.0], "plasma": [15.0, 1.5]},
	"invocador+ceifador": {"reap": [3.0, 0.3], "mend": [20.0, 2.0]},
	"ceifador+pestilento": {"curse_dmg": [3.2, 0.32], "curse_ls": [2.0, 0.2], "ce": [60.0, 5.0]},
	"pestilento+invocador": {"agony_icd": [8.0, -0.5], "minion_curse": [5.0, 0.5]},
}

## Conjuntos Ápice (design/gdd/apice-sets.md): um por build nas classes de armas diferentes (e Cruzado, Iluminado), 35/40/45.
## O 5 peças é o efeito Ápice (FusionEffects, id "apice_<build>"). Números F-AP1 = F-FUS1: valor(i) = v35 + passo × (i − 6).
## Orçamento F-AP2 = o das Fusões: |G_ap − min(G_5n, APEX_GAIN_MAX)| ≤ APEX_TOL (boss_probe --set=a4|a5|b5).
const APEX_TOL := FUSION_TOL
const APEX_GAIN_MAX := FUSION_GAIN_MAX
const APEX_JUDGED_TIME := 4.0                 # Cruzado: s do Julgado (alvo leva +judged% do seu dano)
const APEX_JUDGE_STUN := 0.8                  # Cruzado sem a arma do Julgamento: o Ápice rola o próprio (s de atordoar)
const APEX_JUDGE_ICD := 6.0                   # ... com a mesma recarga da arma
const APEX_MOON_JUMP_RANGE := 6.0             # Xamã: Fogo Lunar em alvo marcado salta para o inimigo mais perto a isto
const APEX_CADENCE_MAX := 5                   # Duelista: Cadência cheia vira Foco do Duelista
const APEX_CADENCE_TIME := 12.0
const APEX_CADENCE_ICD := 1.0                 # Duelista: crítico dá Cadência no máximo a cada isto
const APEX_TEMPEST_TIME := 4.0                # Carniceiro: s do Frenesi da Tormenta
const APEX_EXEC_BASE := 30.0                  # Executor: limiar de execução base (% da vida) + exec_up
const APEX_POISON_TIME := 4.0                 # Lâminas: s do Veneno Letal da facada furtiva
const APEX_BOT_HOLD_BRAVADO := 4              # Corsário (bot): com isto de Bravata segura o Tiro Entre os Olhos até a salva sair
## [v35, passo] por build; número solto = fixo. Chaves lidas em FusionEffects.
const APEX_NUMBERS := {
	"carniceiro": {"frenzy": [1.2, 0.15], "throw": [8.0, 0.8]},
	"executor": {"heavy": [11.0, 1.1], "exec_up": [5.0, 1.0], "exec_dmg": [20.0, 2.0]},
	"punhos": {"counter": [35.0, 3.0], "eva": [4.0, 0.5]},
	"cruzado": {"judged": [10.4, 1.0], "stun_ch": [7.8, 0.75]},
	"inquisidor": {"aurora": [16.0, 1.6]},
	"guardiao_verde": {"bark_icd": [16.0, -1.0]},
	"fera": {"hunt": [13.0, 1.3]},
	"xama": {"moon": [12.0, 1.2], "jump": [65.0, 6.5]},
	"cacador": {"mark": [5.0, 0.5], "pet": [15.0, 1.5]},
	"atirador": {"t2_pwr": [60.0, 5.0], "trap": 1, "regen": [0.5, 0.05]},
	"lanceiro": {"pct": [2.0, 0.4], "max": 5, "bleed": [6.0, 1.0]},
	"laminas": {"ghost_icd": [5.0, -0.25], "poison": [8.0, 0.8]},
	"duelista": {"focus": [60.0, 5.0]},
	"corsario": {"shot": [45.0, 4.0]},
}

## Índice do tier lendário de um nível (LEGENDARY_LEVELS; acima do último segue de 5 em 5: 45 = 8).
static func legend_tier(level: int) -> int:
	var i := LEGENDARY_LEVELS.find(level)
	if i >= 0:
		return i
	return LEGENDARY_LEVELS.size() - 1 + int(ceil(float(level - int(LEGENDARY_LEVELS[-1])) / 5.0))

# --- bots ---
const BOT_CHAT_MIN := 25.0
const BOT_CHAT_MAX := 90.0
const BOT_CHAT_PLACE := 0.5                # conversa solta: chance de falar do lugar (senão da classe/build)
## Bot druida entra na forma (Lobo/Urso) quando há inimigo a BOT_FORM_RANGE m; antes nunca se transformava e lutava
## como humano com as skills da forma (Lobo e Urso 0/40 solo). Formas do Necromante seguem fora (têm hora certa).
const BOT_AUTO_FORMS := ["wolf", "bear", "ent", "alpha", "bird"]     # as ancestrais (ascensão) entram pela mesma regra
const BOT_FORM_RANGE := 12.0
const BOT_FORM_SCORE := 9.0                # acima de qualquer golpe: a forma vem primeiro
## Abertura furtiva do bot (Sumir): só fora de combate, com o alvo ainda sem mirá-lo e a até BOT_STEALTH_RANGE m (no meio
## da luta, um chefe solo perderia o alvo e resetaria; testado e tirado: deixava o Rei Lich voltar a 100%). Na sombra
## contorna até as costas por até BOT_STEALTH_CIRCLE s (costas contra a parede = inalcançável) e depois golpeia de onde der.
const BOT_STEALTH_RANGE := 10.0
const BOT_STEALTH_SCORE := 8.0
const BOT_STEALTH_CIRCLE := 1.5
const BOT_STEALTH_BACK_GAP := 0.6           # m atrás do alvo (além dos raios)
const BOT_CHAT_VICTORY := 0.45            # depois do Lich, na cidade/Bastião: chance de a conversa ser comemoração
const BOT_CHAT_SITUATION := 0.6            # chefe vivo por perto ou investida no mapa: chance de falar disso
const BOT_CHAT_BOSS_RANGE := 30.0          # m: chefe vivo até aqui conta como "perto"
const BOT_CHAT_RECENT := 4                 # falas recentes que o bot evita repetir
# grupo com o jogador (BotChat.update): os bots falam com ele no canal do grupo
const PARTY_CHAT_MIN := 35.0               # s entre duas falas soltas do grupo (um bot por vez)
const PARTY_CHAT_MAX := 75.0
const PARTY_CHAT_GAP := 4.0                # s mínimos entre duas falas de bot no grupo
const PARTY_REACT_CD := 25.0               # s até o grupo reagir de novo ao mesmo tipo de evento
const PARTY_REACT_DELAY := Vector2(0.8, 2.2)   # s de "digitação" antes da reação
const PARTY_CHAT_LOW_HP := 0.3             # jogador abaixo disto: o grupo avisa
const PARTY_CHAT_SCAN := 1.0               # s entre olhadas do grupo (vida, chefe, colheita, investida)

# --- grupo (party) ---
const THREAT_SWITCH := 1.1                 # monstro troca de alvo quando outro passa 110% da ameaça do alvo atual
const TAUNT_DURATION := 4.0                # s presos em quem provocou (chefes: metade)
const TAUNT_THREAT_LEAD := 1.5             # provocar deixa a ameaça de quem provocou em × isto a maior da tabela (antes THREAT_SWITCH, 1.1:
                                           # o dps ficava a 91% do tanque, acima de BOT_THREAT_HOLD, e segurava as skills)
const DR_CAP := 40.0                       # % máx de redução de dano por buff/aura (Stats.dr_pct)
const AURA_TICK := 0.5                     # s entre renovações da aura do tanque nos aliados (AuraSystem)
const AURA_PULSE_EVERY := 1.0             # s entre pulsos de dano da aura do tanque (AuraSystem.pulse)
const AURA_KEEP := 1.3                     # s que o buff da aura dura no aliado sem renovar (saiu do raio = some logo)
const BOT_LOOT_SHOUT_GAP := 60.0           # s entre dois "DROPOU MOEDA LENDÁRIA" de bots no mesmo mapa
const LOOT_LOCK_TIME := 20.0               # s em que só o dono pega o item; depois fica livre
const PORTAL_NOTICE_CD := 4.0              # s entre avisos de portal bloqueado
const PORTAL_ARRIVE_GAP := 1.0             # m mínimos entre a chegada e a borda de qualquer portal do mapa (check)
const ASSAULT_ROUTE_STEP := 1.0            # m entre amostras ao conferir que a rota de uma leva é andável em linha reta (check)
## Leva da Aurora que sobe junto com o jogador às fortalezas (Ossos, Torre): apoio, não limpeza. Antes 10 soldados a cada
## 45 s com 1.800-3.200 de vida contra mortos de 260-420: limpavam os postos sozinhos (2026-11-10, "não tem nem graça").
const ASSAULT_FORT_MAX := 4
const ASSAULT_FORT_EVERY := 90.0
const ASSAULT_FORT_POWER := 0.5            # vida e ataque dos soldados dessas levas (WorldState.assault_def)
## Sentinelas do Posto da Caravana (Estepes 35-40): os soldados da Aurora (nv 26-27) com vida e ataque x isto (veteranos
## mais bem armados). Regra: o povoado segura as levas sozinho em >= 75% (raid_probe --map=field_steppe --bots=0).
const STEPPE_GUARD_POWER := 2.5
## Guarnição de Porto Esperança (Ato II, 30-35; muro e besteiros do C1): vida e ataque x isto. Regra: o porto segura o cerco (C0)
## e a muralha (C1) sozinho em >= 75% (raid_probe --map=city_port --bots=0 --level=32 --raid_level=32, 40 levas).
## Cerco Vivo (2026-11-17, cadência Intenso; reserva + lanceiros do portão correm para a brecha). Retune do playtest ("invasores fracos"):
## invasores x RAID_MAP_POWER["city_port"] 1,2 e leva de 7 com líder e arqueiro; guarnição 1,4 de vida/ataque e mais PORT_GUARD_HP só de vida.
## Medido: 19-20/20 por rota, luta mediana 34-55 s, 1-3 sentinelas mortas por leva; relógio de 30 min C0 83-92% (raid_probe --siege_run=1800).
const PORT_GUARD_POWER := 1.4
const PORT_GUARD_HP := 1.8               # vida a mais só (x, sobre PORT_GUARD_POWER): a guarnição aguenta a leva sem matá-la depressa

# --- Cerco Vivo (SiegeSystem; design/gdd/act2-siege-life.md §7). Cadência "Intenso" (decisão do usuário 2026-11-17):
# leva a cada ~90 s (o `every` da rota no catálogo), assédio na mesma proporção (80 x 90/150 = 48 s). Chaves = pressão 0-3.
const SIEGE_EVERY_MULT := {3: 0.8, 2: 1.0, 1: 2.0}   # x o `every` da rota (F1)
const SIEGE_SIZE_MULT := {3: 1.2, 2: 1.0, 1: 0.6}    # x invasores por leva (F2): menores e mais frequentes
const SIEGE_BIG_NTH := {3: 2, 2: 3, 1: 99}           # leva grande (grupo com every_nth) a cada N levas do mapa
const SIEGE_QUIET_MIN := 30.0             # s de calmaria depois de uma leva repelida (assédio espera a metade)
const SIEGE_FIRST_WAVE := 45.0            # s até a 1ª leva ao entrar no mapa / carregar
const SIEGE_FIRST_HARASS := 25.0          # s até o 1º assédio
const SIEGE_HARASS_EVERY := 48.0          # s entre assédios em p = 2
const SIEGE_HARASS_JITTER := 10.0         # ± s
const SIEGE_HARASS_MULT := {3: 0.75, 2: 1.0}
const SIEGE_HARASS_SHOOTERS := 2          # atiradores por salva
const SIEGE_HARASS_CIRCLES := 3           # círculos avisados por salva
const SIEGE_HARASS_RADIUS := 3.0          # m
const SIEGE_HARASS_DMG_PCT := 12.0        # % da vida máxima por círculo (teto 2 círculos por alvo por salva)
const SIEGE_HARASS_WARN := 1.2            # s de aviso no chão
const SIEGE_HARASS_SPREAD := 10.0         # m em volta da brecha
const SIEGE_HARASS_WINDUP := 8.0          # s do atirador aparecer até a salva (janela para caçá-lo e cancelar)
const SIEGE_HARASS_LIFE := 25.0           # s até os atiradores recuarem
const SIEGE_SAFE_RADIUS := 8.0            # m sem círculo em volta de cristal, chegada, portal e NPC de serviço
const SIEGE_HORN_DELAY := 6.0             # s em luta até o batedor tocar a trompa
const SIEGE_HORN_HASTEN := 20.0           # s que cada trompa adianta a próxima leva
const SIEGE_HORN_MAX := 2                 # trompas que contam por leva
const SIEGE_MORALE_TIME := 180.0          # s do buff Colônia de Pé (renova, não acumula)
const SIEGE_MORALE_XP_PCT := 10.0         # +% de XP de abate no mapa defendido
const SIEGE_FIRE_SPOTS := 3               # focos de Chamas (apresentação)
const SIEGE_BOT_DEFENDERS := 1            # bots fora do grupo do jogador que largam o que fazem para defender cada leva (o resto fica: a guarnição segura, ajudar pesa)
const SIEGE_GUARD_REPEL := 0.75           # meta das sondas: guarnição sozinha repele esta fração (raid_probe --bots=0)
const SIEGE_XP_SHARE := 0.8               # meta das sondas: XP/min do cerco <= isto x a caça da faixa
## Guarnição do Acampamento Avançado (Kharzun 40-45): vida e ataque dos soldados da Aurora x isto. Regra: o acampamento segura
## o Contra-ataque (K0, Canil + Cidadela) sozinho em >= 75% (raid_probe --map=field_kharzun --bots=0).
const KHARZUN_GUARD_POWER := 3.6
## Procissão dos Lúcidos (Ato III, hx3_veil_open): soldados da leva aliada que sobe ao Palco Grande x isto. Abaixo da guarnição
## de propósito: a procissão é escoltada, não limpa a avenida sozinha (MapsCatalog.PROCESSION).
const ACT3_PROCESSION_POWER := 2.4
const PARTY_MAX := 5                       # membros por grupo
const PARTY_NEARBY_RANGE := 40.0          # m: janela P lista quem dá para convidar até esta distância
const PARTY_SHARE_RANGE := 45.0            # m: membros vivos no mesmo mapa e dentro disto dividem XP e quests de abate
const PARTY_XP_BONUS := 0.15               # +15% de XP total por membro extra que divide o abate
const PARTY_LEVEL_GAP := 15                # diferença máx. de nível para dividir XP (e para bots aceitarem convite)
const PARTY_INVITE_TIME := 30.0            # s até o convite expirar
const PARTY_FOLLOW_DIST := 3.5             # bots seguidores ficam a esta distância do líder
const PARTY_ASSIST_RANGE := 14.0           # bots atacam o que bate no grupo dentro deste raio do líder
## 2026-11-19 (usuário: o tanque precisa ser mais proativo): chefe/elite preso em alguém do grupo ou em que o líder bateu
## vale até este raio do líder (antes 14 m: o líder atirador ficava sozinho e o grupo esperava ele chegar perto)
const PARTY_BIG_ASSIST_RANGE := 22.0
const BOT_TANK_PULL_BOSS := 20.0           # tanque seguidor abre no chefe a até isto do líder (a pé, fora da vila)
const BOT_TANK_PULL_ELITE := 12.0          # ... e na elite a até isto (elite de campo: só a que está no caminho)
const BOT_TANK_PULL_HP := 0.6              # abaixo disto de vida o tanque não abre luta nova
const BOT_PARTY_ACCEPT := 0.8              # chance de um bot aceitar um convite válido
const BOT_PARTY_FORM_CHANCE := 0.35        # bot que sai para caçar chama outros bots da vila
const BOT_INVITE_PLAYER_CHANCE := 0.12     # ... ou chama o jogador, se ele estiver por perto e sem grupo
## Bot líder do grupo do jogador (BotLeaderSystem, 2026-11-23): completa o grupo e conta o plano no canal do grupo.
const BOT_LEADER_RECRUIT_RANGE := 45.0     # m: bots livres até aqui do líder entram na escolha
const BOT_LEADER_LEVEL_GAP := 5            # níveis de diferença máx. de quem o líder chama (faixa do grupo)
const BOT_LEADER_LEVEL_WEIGHT := 3.0       # nota do candidato: m de distância que cada nível de diferença vale
const BOT_LEADER_ROLE_BONUS := 60.0        # nota: papel que falta vale isto em m (o 1º que falta vale o dobro)
const BOT_LEADER_ROLE_PATIENCE := 25.0     # s recrutando na vila só com o papel que falta; depois chama qualquer um
const BOT_LEADER_INVITE_CD := 6.0          # s entre dois convites do líder (um por vez: espera a resposta)
const BOT_LEADER_DECLINE_MEMORY := 90.0    # s sem chamar de novo quem recusou
const BOT_LEADER_FILL_MAX_S := 75.0        # s segurando a saída na vila para encher; depois sai com quem tem
const BOT_LEADER_SCAN := 1.0               # s entre olhadas (ninguém para chamar, chefe à vista)
const BOT_LEADER_WAIT_DIST := 28.0         # m: jogador mais longe que isto no mesmo mapa = o líder espera
const BOT_LEADER_WAIT_RESUME := 12.0       # m: ... até ele chegar a isto
const BOT_LEADER_WAIT_MAX_S := 45.0        # s esperando; depois vai na frente
const BOT_LEADER_SAY_GAP := 5.0            # s mínimos entre duas falas do plano
const BOT_LEADER_SAY_REPEAT := 40.0        # s até repetir o mesmo tipo de fala (convite: por pessoa; chefe: por chefe)
const BOT_LEADER_SAY_STALE := 15.0         # s: fala que esperou a vez mais que isto some
const BOT_LEADER_SAY_QUEUE := 2            # falas esperando a vez (cheia: a mais velha sai)
## IA de grupo (BotBrain; papel = role da build: tank, healer, dps, caster, ranged). Contra chefe/elite preso no tanque:
## quem bate de perto vai para as costas/flancos (fora de ±BOT_FRONT_ARC_DEG da frente), quem luta de longe fica a
## BOT_RANGED_DIST m num flanco de trás; quem cura fica a até BOT_HEALER_LEASH m do tanque.
const BOT_FRONT_ARC_DEG := 70.0
const BOT_FRONT_RANGE := 9.0               # m (além dos raios): na frente do chefe e mais perto que isto = sai
const BOT_RANGED_DIST := 8.0
const BOT_RANGED_MIN := 4.0                # m: quem luta de longe e está mais perto que isto do chefe volta para o seu lugar
const BOT_BACK_SPREAD := 0.55              # rad: quem bate de perto se espalha nas costas (por id)
const BOT_RANGED_SPREAD := 1.0             # rad a partir das costas: flanco de quem luta de longe
const BOT_HEALER_LEASH := 10.0
const BOT_PLACE_GIVEUP := 2.5              # s tentando chegar ao lugar do papel sem conseguir: desiste ...
const BOT_PLACE_COOL := 4.0                # ... e luta de onde está por isto
## Ameaça: com o tanque segurando o chefe, quem passa BOT_THREAT_HOLD × a ameaça do tanque só usa o básico; acima
## de BOT_THREAT_STOP para de bater até o tanque abrir distância (troca de alvo = THREAT_SWITCH).
const BOT_THREAT_HOLD := 0.85
const BOT_THREAT_STOP := 1.0
## Tanque bot: provoca de novo o chefe/elite que segura quando alguém do grupo chega a isto × a ameaça dele (antes de
## BOT_THREAT_HOLD; a provocação o deixa em TAUNT_THREAT_LEAD × o maior).
const BOT_TANK_RETAUNT := 0.75
## Ameaça prevista (BotBrain._skill_threat × isto): com o chefe preso no tanque, a skill cujo golpe (+ dano no tempo) passaria
## BOT_THREAT_HOLD × a ameaça do tanque espera (as menores seguem). A estimativa não vê variação nem bônus de talento: folga.
## Antes o Meteoro/Executar saíam a 0,6-0,8 da ameaça do tanque e passavam dele de uma vez (maioria das perdas no meio da luta).
const BOT_THREAT_PREDICT := 1.2
## Básico previsto (BotBrain._skill_threat com crit_hit, BotBrain._signature_threat): evento do básico com chance a partir disto
## (%) conta como certo — o crítico (CRIT_MULT × (1 + DMG_VARIANCE) em vez do crítico médio) e a magia-assinatura que ele
## lança junto (fora da recarga dela): o básico sai muitas vezes e acaba saindo. Antes o básico do Executor (+ Golpe Avassalador
## de assinatura) passava o tanque na abertura do Besteiro (~6 em 40 lutas). 101 desliga.
const BOT_THREAT_CRIT_CHANCE := 5.0
## Abertura (BotBrain._opener): com tanque no grupo, o chefe/elite (ou o que está a BOT_OPENER_AOE_RANGE m do alvo) só leva
## skill depois de BOT_OPENER_TIME s preso no tanque (com ameaça dele); até lá o resto só usa o básico (e buff em si), e só abaixo
## de BOT_OPENER_RATIO × a ameaça do tanque. Tanque que não pega em BOT_OPENER_WAIT s: luta normal. O tanque NÃO abre com a
## provocação (12 s de recarga: gasta na abertura, faltava para tirar o chefe do dps que estoura logo depois).
## Antes o Fogo tirava o chefe do tanque nos 5 s de abertura em quase toda luta do Ato II (13-28 perdas em 20) e morria.
const BOT_OPENER_TIME := 3.0
const BOT_OPENER_RATIO := 0.5
const BOT_OPENER_AOE_RANGE := 6.0
const BOT_OPENER_WAIT := 6.0
## Cura: o tanque é curado abaixo de BOT_HEAL_TANK_HP, os outros abaixo de BOT_HEAL_HP; o tanque vem primeiro, menos quando
## alguém está quase morrendo (BOT_HEAL_CRIT_HP) e o tanque está fora de perigo (BOT_HEAL_TANK_SAFE).
const BOT_HEAL_TANK_HP := 0.75
const BOT_HEAL_HP := 0.6
const BOT_HEAL_CRIT_HP := 0.4             # alguém abaixo disto passa na frente do tanque ...
const BOT_HEAL_TANK_SAFE := 0.5            # ... se o tanque estiver acima disto
const BOT_HEAL_RANGE := 16.0               # m: membros mais longe que isto não entram na conta
## Lacaio batendo em quem cura/luta de longe a até BOT_PEEL_RANGE m dele: um dps de perto larga o chefe e vai nele.
const BOT_PEEL_RANGE := 10.0
## Raide (WP8, design/gdd/kharzun-fase3-plan.md §4): chefe com `ward` ligado por lacaio vivo (estandartes do Durgash, aprendizes
## do Shazka): quem não é tanque nem cura vai no lacaio dele a até BOT_WARD_RANGE m (estandarte primeiro, o mais perto).
const BOT_WARD_RANGE := 24.0
## Proteger quem cura: chefe a até BOT_GUARD_SOFT m de quem cura (ou mirando nele) = o tanque provoca de novo; quem cura
## sai para longe do chefe que não o tem por alvo até BOT_HEALER_EVADE m (fora do alcance do Golpe de Misericórdia).
const BOT_GUARD_SOFT := 5.0
const BOT_HEALER_EVADE := 5.0
## Frente do chefe: além de BOT_FRONT_ARC_DEG, metade do cone mais largo dele + isto (talho de 150° do Durgash = 87°).
const BOT_FRONT_ARC_PAD := 12.0
const BOT_RANGED_SPREAD_STEP := 0.35      # rad: 3º/4º de longe no mesmo flanco ficam mais para o lado (um círculo da chuva não pega dois)
## Tanque de raide (4+ no grupo): o grupo na frente do chefe = o tanque dá a volta para virar o chefe de costas para eles.
const BOT_TANK_TURN_MIN := 4
const BOT_DODGE_PAD := 1.0                 # m de folga ao sair de círculo/área telegrafada (antes 0.5)

## Ascensão do Ranger (RangerAscension). (H) = calibrado na fase 1 (boss_probe --comp, F5: razão 1,06-1,10).
## F5: peso da ascensão por build (padrão 1,0) — multiplica a força das mecânicas dela (torreta, salto, queimadura/arco do Brado)
const ASC_BUILD_POWER := {"lanceiro": 3.5, "atirador": 11.5, "laminas": 1.03, "duelista": 1.0, "corsario": 0.85,
	"guardiao_verde": 1.0, "fera": 1.6, "xama": 1.0, "cacador": 3.0}       # assassino, F5 2026-11-12 (--tank_lock, 80/braço): Lâminas 1,3 x1,144 / 1,0 x1,118 / 0,9 x1,084 / 0,8 x1,038; Duelista 0,7 x1,045 / 0,85 x1,059 / 0,92 x1,082 / 1,15 x1,155; Corsário 1,0 x1,076
## F5 no 45 na sala real do Kragmar (2026-11-13, 80/braço): Lanceiro 3,3->2,35 x1,172; Atirador 6,5->4,0 x1,197; Caçador 0,7->0,82 x1,175;
## Corsário 0,45->0,33 x1,201; Duelista 0,73->0,46 x1,222; Lâminas 0,9->0,51 x1,213; Fera 1,0->0,74 x1,218 (o fator do 35 abaixo compensa: o 35 não muda).
## Alvo novo do 45 = ~1,30 (usuário 2026-11-14: quem estava abaixo sobe, nada é cortado; tanque druida neutro, 80/braço, 2 sementes):
## Lanceiro 3,5 x1,37; Atirador 11,5 x1,33; Caçador 3,0 x1,32; Lâminas 1,03 x1,33; Duelista 1,0 x1,30; Corsário 0,85 x1,33; Fera 1,6 x1,32
## (Fera com tanque Guardião; o peso só mexe na matilha: 0,94-1,15 davam ~1,24). O produto peso × fator no 35 não mudou.
## F5 aos 35 (usuário 2026-11-13): o peso acima é o do 45; aos 35 ele vale × ASC_POWER_35_MULT[build], e o fator vai
## em linha reta até 1,0 no ASC_MAX_LEVEL (asc_level_mult). Build sem entrada = 1,0. "punhos" multiplica TITAN_CLAW_POWER.
## Medido 2026-11-13 (Agitador-Mor, nv 35, --tank_lock, 80/braço, razão base/asc): Lanceiro x1,078, Atirador x1,089, Caçador x1,097,
## Corsário x1,068, Duelista x1,077, Lâminas x1,099, Punhos x1,087 (sem o fator: 1,322 / 1,172 / 1,116 / 1,014 / 1,046 / 1,032 / 1,043).
const ASC_POWER_35_MULT := {"lanceiro": 0.0943, "atirador": 0.1696, "cacador": 0.1399, "laminas": 1.0497, "duelista": 1.0212, "corsario": 1.2175, "punhos": 0.9481, "fera": 0.6248}

## Fator de nível do peso F5 da build: ASC_POWER_35_MULT no ASC_LEVEL (e abaixo), 1,0 no ASC_MAX_LEVEL (e acima).
static func asc_level_mult(build: String, level: int) -> float:
	if level >= ASC_MAX_LEVEL:
		return 1.0                          # exato: o 45 fica como estava
	var t := clampf(float(level - ASC_LEVEL) / float(ASC_MAX_LEVEL - ASC_LEVEL), 0.0, 1.0)
	return lerpf(float(ASC_POWER_35_MULT.get(build, 1.0)), 1.0, t)

## Peso F5 da ascensão da build no nível do dono (ASC_BUILD_POWER × asc_level_mult). Único caminho das ascensões.
static func asc_power(build: String, level: int) -> float:
	return float(ASC_BUILD_POWER.get(build, 1.0)) * asc_level_mult(build, level)

## Ascensão do Assassino — Sombras Gêmeas (ShadowSystem; GDD R6.1). (H) = hipótese, calibrar com boss_probe --comp.
## O clone repete os golpes diretos do dono (skill, básico, projétil) com SHADOW_SHARE% do dano, um instante depois;
## monstros o ignoram (não é hostil a ninguém), o dano e a ameaça são do dono; some no fim do tempo ou se o dono morrer.
const SHADOW_SKILL := "ass_twin_shadow"
const SHADOW_BUFF := "twin_shadow"        # buff no dono enquanto o clone vive (HUD e visual)
const SHADOW_TIME := 6.0                  # s de clone (H)
const SHADOW_CD := 30.0                   # s de recarga (H)
const SHADOW_SHARE := 50.0                # % do dano do golpe que o clone repete (H; F5 × ASC_BUILD_POWER da build)
const SHADOW_ECHO_MAX := 0.3              # s no máximo entre o golpe do dono e o do clone (o preparo da skill, limitado)
const SHADOW_SIDE := 1.1                  # m ao lado do dono
const SHADOW_SNAP := 5.0                  # m: mais longe que isto do lugar dele, o clone aparece lá
const SHADOW_STEALTH_TIME := 3.0          # s do clone que sai da furtividade junto (refino Lâminas 40) (H)
const SHADOW_TIME_NODE := 1.0             # s a mais por nó "shadow_time" da teia de ascensão
const SHADOW_SHARE_NODE := 5.0            # pontos de % a mais por nó "shadow_share"
## Execução: dano enorme em alvo abaixo de EXECUTION_BELOW da vida; acima, golpe fraco. Chefe: vale igual (o dano dele já
## é cortado por ward/fase; a regra é o limiar, AC-31).
const EXECUTION_SKILL := "ass_execution"
const EXECUTION_BELOW := 0.25             # fração da vida do alvo
const EXECUTION_POWER := 3.0              # poder abaixo do limiar (H)
const EXECUTION_WEAK := 0.8               # poder acima do limiar
const EXECUTION_CD := 10.0
const EXECUTION_NODE_PCT := 10.0          # % a mais de dano da Execução por nó "execute_pct"
## Contra-Ataque em Cadeia (refino Duelista 40): cada esquiva prepara a próxima Execução sem recarga (1 carga).
const CHAIN_COUNTER_BUFF := "exec_ready"
const CHAIN_COUNTER_TIME := 8.0           # s que a carga espera (H)
## Canhão de Mão (refino Corsário 40): tiro pesado em linha que empurra (chefe não é empurrado).
const HAND_CANNON_POWER := 2.6            # (H)
const HAND_CANNON_CD := 12.0
const HAND_CANNON_RANGE := 9.0
const HAND_CANNON_PUSH := 3.0             # m de empurrão
## Bots: Sombra Gêmea ao abrir a luta (alvo a até BOT_SHADOW_RANGE m) e sempre que recarrega; Execução só abaixo do limiar.
const BOT_SHADOW_SCORE := 5.0
const BOT_SHADOW_RANGE := 4.0
const BOT_EXECUTION_SCORE := 6.0
## Torreta de campo (Atirador): fica parada onde foi posta e atira sozinha no inimigo mais perto.
const TURRET_MONSTER := "ranger_turret"   # MonsterDef da torreta (alcance/cadência do tiro)
const TURRET_MAX := 1                     # torretas vivas por ranger (stat `turret_max` soma; a mais antiga some)
const TURRET_TIME := 15.0                 # s de vida útil (H)
## Refino 40/45 da torreta (decisão do autor 2026-11-11; só dado, a linha de talento chega com o nível 40):
## +4 s de vida útil e -20% de recarga (não é torreta dupla; a 2ª torreta vem de conjunto híbrido via stat `turret_max`)
const TURRET_REFINE_TIME := 4.0
const TURRET_REFINE_CD_PCT := 20.0
const TURRET_REFINE_FLAGS := ["ran_turret_firm", "ran_turret_vet"]      # portões da teia de ascensão (40 e 45)
const TURRET_HP_SHARE := 0.45             # vida = vida máx. do dono x isto (H)
const TURRET_ATK_SHARE := 0.55            # ATK = ATK do dono x isto (H; F5)
const TURRET_SHOT_CD := 1.4               # s entre tiros (tiro pesado: a DEF do alvo não engole)
const TURRET_DEF_SHARE := 0.6             # DEF = DEF do dono x isto
const TURRET_RANGE := 11.0                # m: alcance do tiro (o inimigo mais perto dentro disto)
const TURRET_AREA := 4.0                  # m em volta da torreta que efeitos podem ler (RangerAscension.near_turret; conjuntos futuros)
const BOT_TURRET_SCORE := 4.0             # bot: nota da torreta (sem torreta viva, luta perto) — abre a luta com ela
const BOT_TURRET_REACH := 18.0            # m do alvo: o bot monta a torreta a até isto (o atirador luta longe)
const BOT_TURRET_GAP := 3.0               # m: o bot põe a torreta a isto do tanque, do lado de cá do chefe
const BOT_JUMP_MIN := 6.0                 # m: o bot só salta (fora da esquiva) para fechar distância a partir disto
const BOT_JUMP_GAP := 0.3                 # m: o bot cai do salto a isto da borda do alvo (no centro da queda)
## Lanceiro Dracônico: Salto Dracônico (F9b) e Brados Elementais
const DRAGON_JUMP_AIR := 1.2              # s fora do chão (intocável; o chefe perde o alvo)
const DRAGON_JUMP_POWER := 2.2            # poder no centro da queda (raio DRAGON_JUMP_INNER)
const DRAGON_JUMP_EDGE := 1.0             # poder na borda (até o raio da skill)
const DRAGON_JUMP_INNER := 1.5            # m do centro
const DRAGON_JUMP_HEIGHT := 9.0           # m de altura do salto (só desenho: a sim é plana)
const UNTOUCHABLE_MAX := 0.25             # combat_probe: dash + salto não deixam o lanceiro intocável mais que isto da luta
const SHOUT_TIME := 12.0                  # s do Brado
const SHOUT_CD := 20.0                    # s de recarga de cada Brado
const SHOUT_BUFF := 10.0                  # % do bônus do grupo (fogo, velocidade) e da perda de velocidade de ataque (geada)
const SHOUT_ALLY_RADIUS := 10.0           # m: grupo que recebe o Brado
const SHOUT_FROST_RADIUS := 6.0           # m: inimigos que a Geada deixa mais lentos para atacar
const SHOUT_TAUNT_RADIUS := 4.0           # m: o grito provoca os monstros perto
const SHOUT_TAUNT_TIME := 1.0             # s de provocação do grito
const SHOUT_BURN_PCT := 60.0              # Chamas: a lança queima (% do ATK por segundo)
const SHOUT_BURN_TIME := 3.0
const SHOUT_CHILL_PCT := 25.0             # Geada: a lança deixa lento (%)
const SHOUT_CHILL_TIME := 1.5
const SHOUT_ARC_PCT := 35.0               # Trovão: o golpe salta para 1 vizinho com isto do dano
const SHOUT_ARC_RANGE := 4.0              # m do alvo até o vizinho
## Refinos do Lanceiro (portões da teia de ascensão; GDD R6.1)
const DRAGON_JUMP_SKILL := "ran_dragon_jump"
const DOUBLE_JUMP_FLAG := "ran_double_jump"       # 40, Salto Duplo
const DOUBLE_JUMP_WINDOW := 1.0                   # s depois do pouso para o 2º salto (sem recarga); a recarga começa depois
const DOUBLE_JUMP_CD_MULT := 2.0                  # recarga depois do 2º salto × isto (combat_probe --asc --level=45: com 1,0 o lanceiro ficava intocável 30% da luta, com 1,5 24-26%; máx 25%)
const SHOUT_COMBO_FLAG := "ran_shout_combo"       # 45, Brado Combinado
const SHOUT_COMBO_TIME := 8.0                     # s com dois Brados ativos (o anterior fica até isto)
const SHOUT_COMBO_CD := 40.0                      # s de recarga do combinado
const SHOUT_COMBO_KEY := "shout_combo"            # chave da recarga em SimEntity.cooldowns (não é skill)

## Ascensão do Necromante: Senhor dos Mortos (NecroAscension; GDD ato2-horda R6.1, AC-30b). (H) = hipótese a calibrar.
## De graça com a ascensão: invocações temporárias duram mais e cabe +1 por tipo.
const LORD_SUMMON_TIME_MULT := 1.5        # duração das invocações temporárias (AC-30b)
const LORD_SUMMON_EXTRA := 1              # vagas a mais por tipo de invocação (AC-30b)
## Pacto dos Mortos (o "Pacto Sombrio" do GDD): buff nas invocações que estão perto ao lançar
const LORD_PACT_RADIUS := 15.0            # m do necromante (AC-30b)
const LORD_PACT_TIME := 12.0              # s
const LORD_PACT_CD := 20.0                # s de recarga
const LORD_PACT_DMG_PCT := 25.0           # dano das invocações (AC-30b)
const LORD_PACT_SPEED_PCT := 20.0         # velocidade de movimento das invocações
const LORD_PACT_LEECH_PCT := 10.0         # do dano delas cura o necromante
## Miasma: nuvem no chão; quem está dentro causa menos dano e anda mais devagar (soma com as maldições, teto CURSE_WEAKEN_CAP)
const LORD_MIASMA_RADIUS := 4.0           # m
const LORD_MIASMA_TIME := 8.0             # s de nuvem
const LORD_MIASMA_CD := 16.0
const LORD_MIASMA_WEAKEN_PCT := 20.0      # dano a menos de quem está dentro (AC-30b)
const LORD_MIASMA_SLOW_PCT := 15.0
const LORD_MIASMA_PULSE := 0.5            # s entre pulsos da nuvem (ritmo do AuraSystem)
const LORD_MIASMA_KEEP := 1.3             # s que o efeito dura em quem saiu da nuvem (= AURA_KEEP)
## Marca da Cova: monstro comum (não chefe/elite) que morre marcado levanta como esqueleto aliado
const LORD_GRAVE_RADIUS := 3.5
const LORD_GRAVE_MARK_TIME := 10.0        # s de marca
const LORD_GRAVE_RAISE_TIME := 15.0       # s do esqueleto erguido (AC-30b; não leva o x1,5)
const LORD_GRAVE_CD := 24.0
const LORD_GRAVE_MAX := 4                 # esqueletos da Marca vivos por necromante (H; segura o nº de entidades)
const LORD_GRAVE_MONSTER := "skeleton_minion"
const LORD_GRAVE_SKILL := "nec_asc_grave_mark"
## Forma de Lich (45): liga por LORD_LICH_TIME s
const LORD_LICH_TIME := 15.0
const LORD_LICH_CD := 60.0
const LORD_LICH_MATK_PCT := 30.0          # magias mais fortes na forma
const LORD_LICH_SPREAD := 4.0             # m do amaldiçoado: a maldição lançada na forma passa para quem está aqui
const LORD_LICH_SUMMON_EXTRA := 1         # vagas a mais por tipo enquanto dura (ao sair, o excesso some da mais antiga) (H)
## Refinos 40/45 (nós da teia de ascensão, AscensionCatalog.NODES; todos (H))
const LORD_ARMY_EXTRA := 1                # Exército (Invocador): +1 invocação por tipo
const LORD_ARMY_HP_SHARE := 0.2           # ... e as invocações ganham isto da vida do mago
const LORD_COMMAND_FOCUS := 4.0           # Foice que Comanda (Ceifador): s que as invocações seguram o alvo do golpe (= PET_COMMAND_FOCUS)
const LORD_COMMAND_EVERY := 0.5           # s entre ordens (golpe em área não manda uma ordem por atingido)
const LORD_WIDE_MULT := 1.5               # Miasma Largo (Sombras): raio do Miasma e da Marca da Cova
const LORD_BOND_TIME := 3.0               # Vínculo Sombrio: s a mais de Pacto
const LORD_FOG_TIME := 2.0                # Névoa Espessa: s a mais de Miasma
const LORD_DEEP_GRAVE_TIME := 5.0         # Cova Funda: s a mais do esqueleto erguido
const LORD_BLOOD_PACT_MULT := 2.0         # Pacto de Sangue (Invocador): roubo de vida do Pacto x isto
const LORD_LICH_REAPER_TIME := 5.0        # Ceifa do Lich (Ceifador): s a mais de Forma de Lich
const LORD_LICH_PLAGUE_MULT := 1.5        # Praga do Lich (Sombras): alcance do espalhar das maldições
## Bots (NecroAscension.bot_score)
const BOT_LORD_SCORE := 5.0               # nota do Pacto/Miasma/Marca na hora certa (acima dos golpes comuns)
const BOT_LORD_PACT_MIN := 2              # invocações vivas a LORD_PACT_RADIUS para valer o Pacto
const BOT_LORD_PACK := 3                  # inimigos juntos para Miasma / Forma de Lich fora de chefe
const BOT_LORD_GRAVE_PACK := 2            # monstros comuns na área para a Marca da Cova
const BOT_LORD_GRAVE_HP := 0.5            # ... e algum deles com a vida abaixo disto

## Ascensão do Bispo: Coro Celeste (ChoirSystem; GDD Ato II R6.1 + F9). (H) = hipótese calibrada na fase 1
## (ascensão de utilidade: F5 = queda relativa de mortes por luta sob `boss_probe --comp --dmg=6`, alvo 6-10% aos 35).
## Barreira Sagrada: cúpula que anda com o Bispo
const BARRIER_TIME := 8.0                 # s de cúpula
const BARRIER_RADIUS := 5.0               # m
const BARRIER_CD := 30.0                  # s de recarga
const BARRIER_RANGE := 6.0                # m: até onde o Bispo pode pôr o centro da cúpula
const BARRIER_DR := 30.0                  # % a menos de dano em aliado dentro (duas cúpulas não somam)
const BARRIER_LAG := 2.0                  # m/s: a cúpula anda isto mais devagar que o Bispo (Barreira em Marcha: 0)
const BARRIER_HOLD := 3.0                 # s depois de lançar em que ninguém dentro cai abaixo de 1 de vida (nó dos 45)
const BARRIER_BURN_POWER := 0.4           # Barreira que Fere (Iluminado): poder mágico por segundo em inimigo dentro
const BARRIER_BURN_EVERY := 1.0           # s entre as queimaduras da cúpula
const BARRIER_MARCH_SHIELD := 10.0        # Barreira em Marcha (Batalha): escudo (% do HP) em quem está dentro ao lançar
const BARRIER_MARCH_SHIELD_TIME := 6.0    # s desse escudo
## Anjo Guardião: voa atrás do Bispo e cura o grupo (tanque primeiro, como os bots)
const ANGEL_MONSTER := "choir_angel"      # MonsterDef do anjo (só nome/cor: vida e cura vêm do Bispo)
const ANGEL_TIME := 30.0                  # s
const ANGEL_CD := 40.0                    # s de recarga
const ANGEL_HEAL := 0.6                   # poder da cura (pela WILL do Bispo: Combat.calc_heal) (H)
const ANGEL_HEAL_EVERY := 1.5             # s entre as curas
const ANGEL_RANGE := 12.0                 # m do anjo: quem ele alcança
const ANGEL_HEAL_BELOW := 0.95            # só cura quem está abaixo disto da vida
const ANGEL_TANK_BELOW := 0.7             # tanque abaixo disto passa na frente do mais ferido (ordem dos bots)
const ANGEL_PARTING_HEAL := 1.5           # Luz de Partida: poder da cura em área quando o tempo do anjo acaba
const ANGEL_PARTING_RADIUS := 8.0         # m da Luz de Partida
const ANGEL_STRONG_PCT := 50.0            # Anjo Forte (Sacerdote 40): % a mais de cura
const ANGEL_MAX := 1                      # anjos vivos (Dois Anjos, Sacerdote 45: +1)
const ANGEL_FOLLOW_DIST := 1.6            # m atrás do Bispo
const ANGEL_FLY_SPEED := 9.0              # m/s (voa por cima de tudo; passou de SUMMON_LEASH, aparece ao lado)
const ANGEL_HOVER := 1.9                  # m de altura (só desenho)
## Bênçãos de grupo (renovam pelo id, não somam com elas mesmas) (H)
const BLESS_RADIUS := 12.0                # m
const BLESS_TIME := 20.0                  # s
const BLESS_CD := 25.0                    # s de recarga
const BLESS_WINGS := {"speed_pct": 15.0, "aspd_pct": 15.0}        # Asas da Aurora
const BLESS_AEGIS := {"def_pct": 12.0}                            # Égide Coral (DEF e MDEF)
const BLESS_AEGIS_HEAL := 4.0             # Égide Coral: % do HP máximo curado por golpe recebido
const BLESS_AEGIS_HEAL_ICD := 1.0         # s entre essas curas no mesmo aliado (chuva de golpes não vira cura infinita) (H)
## Retorno: ressurreição em combate (45), uma por aliado por luta (H)
const RES_LEVEL := 45
const RES_HP_PCT := 0.35                  # volta com isto da vida (e da mana)
const RES_CAST := 2.5                     # s de conjuração
const RES_RANGE := 15.0                   # m
const RES_CD := 120.0                     # s de recarga
const RES_PICK_RADIUS := 4.0              # m do ponto mirado: o caído mais perto dentro disto (senão o mais perto do Bispo)
const RES_HOLD_PAD := 1.0                 # s a mais que o caído espera o Retorno antes de renascer na cidade
const RES_BATTLE_SHIELD := 20.0           # Retorno Blindado (Batalha 45): escudo (% do HP) em quem volta
const RES_BATTLE_SHIELD_TIME := 6.0       # s desse escudo
## Bots do Coro (BotBrain)
const BOT_BARRIER_HURT := 0.5             # barreira: 2+ membros abaixo disto da vida...
const BOT_BARRIER_HURT_N := 2
const BOT_BARRIER_NEAR := 12.0            # ...ou chuva/golpe avisado de chefe a até isto de alguém do grupo
const BOT_BARRIER_STAY := 0.8             # bot do grupo fica a até isto do raio da cúpula (por dentro)
const BOT_ANGEL_HURT := 0.7               # fora de chefe: anjo só com alguém do grupo abaixo disto

## Ascensão do Druida (DruidAscension): Forma Ancestral — a 3ª forma de cada build. (H) = calibrado na fase 1
## (boss_probe --comp; F5: Lobo Alfa e Pássaro Arcano razão 1,06-1,10; Ent = queda de mortes a --dmg=6).
## Bônus de cada forma em FORM_STATS (ent, alpha, bird); arma exigida em FORM_REQUIRES.
const ANC_FORM_BASE := {"ent": "bear", "alpha": "wolf"}      # a ancestral vale pela forma de base (Espreitar como Lobo Alfa; variantes que ela não tem)
const ANC_FORM_BUILD := {"ent": "guardiao_verde", "alpha": "fera", "bird": "xama"}
const ANC_ROOTS_POWER := 1.3              # Raízes Ancestrais (Ent): dano em volta (H)
const ANC_ROOTS_RADIUS := 6.0             # m
const ANC_ROOTS_ROOT := 2.5               # s presos
const ANC_ROOTS_TAUNT := 4.0              # s provocados (chefes: metade, MobSystem.taunt)
const ANC_GROVE_DR := 9.0                 # Bosque Protetor (Ent): % a menos de dano no grupo (H; utilidade do F5; 2026-11-12: 15 -> 9, mortes -19,8% -> alvo -6 a -10%)
const ANC_GROVE_TIME := 8.0
const ANC_GROVE_RADIUS := 8.0
const ANC_PACK_MONSTER := "pack_wolf"     # MonsterDef do lobo da matilha (Lobo Alfa)
const ANC_PACK_COUNT := 2                 # lobos por chamado (também o máximo vivo)
const ANC_PACK_TIME := 20.0               # s (F5 2026-11-11: 15 -> 20; recarga da skill 30 s)
const ANC_PACK_HP_SHARE := 0.4            # vida = vida máx. do dono x isto
const ANC_PACK_ATK_SHARE := 0.9           # ATK = ATK do dono x isto (F5 2026-11-11: 0,4 dava x1,02-1,04 em grupo; 144 lutas por braço)
const ANC_PACK_DEF_SHARE := 0.6
const ANC_HOWL_SPEED := 15.0              # Uivo do Alfa: % de velocidade do grupo
const ANC_HOWL_ASPD := 10.0               # e % de velocidade de ataque
const ANC_HOWL_TIME := 8.0
const ANC_HOWL_RADIUS := 10.0
const ANC_BOLT_POWER := 2.6               # Relâmpago Arcano (Pássaro): raio no ponto mirado (H; F5)
const ANC_BOLT_CHAIN := {"count": 2, "radius": 5.0, "falloff": 0.5}
const ANC_FLOCK_POWER := 1.1              # Revoada de Luz: cura do grupo (x MATK, como as outras curas)
const ANC_FLOCK_SPEED := 10.0             # e % de velocidade
const ANC_FLOCK_TIME := 6.0
const ANC_FLOCK_RADIUS := 8.0
const ANC_FEATHER_HEAL := 0.7             # Chuva de Penas de Luz (variante da Chuva Estelar): cura quem está embaixo (x MATK)
const ANC_GUST_PUSH := 4.0                # m: Rajada de Vento (variante do Ciclone) empurra para longe do centro
const ANC_BIRD_LIFT := 1.1                # m: altura do voo do Pássaro Arcano (só desenho: a sim é plana)
## Refinos 40 e 45 (nós da teia de ascensão com portão de nível): na forma ancestral, as variantes e as skills da forma
## ganham força e duração por refino comprado (1 ou 2).
const ANC_REFINE_FLAGS := {"ent": ["anc_ent", "anc_ent_2"], "alpha": ["anc_alpha", "anc_alpha_2"], "bird": ["anc_bird", "anc_bird_2"]}
const ANC_REFINE_POWER := 0.06            # + poder por refino (F5: 0,06 por tier)
## Peso próprio de um refino (flag -> + poder), no lugar de ANC_REFINE_POWER. F5 no 45 (usuário 2026-11-14: build abaixo de 1,30 sobe):
## o 2º refino do Pássaro (Ave do Trovão, 45) carrega a subida do Xamã; o 35 e o 40 não mudam.
const ANC_BIRD_ELDER_POWER := 0.21        # Ave do Trovão (Xamã 45): + poder do 2º refino (0,06 x1,24, 0,30 x1,33, 0,21 x1,31)
const ANC_REFINE_POWER_NODE := {"anc_bird_2": ANC_BIRD_ELDER_POWER}
const ANC_REFINE_TIME := 0.2              # + duração (prender, atordoar, lentidão, provocar, buff, matilha) por refino

## Ascensão do Caçador — Falcoeiro: Olhos do Céu (FalconSystem; design/gdd/ato2-proposals-2026-11-11.md §2 opção A).
## O falcão é intocável (estado no dono, sem entidade): mergulha sozinho no alvo do caçador e marca a Presa.
const FALCON_DIVE_CD := 6.0               # s entre mergulhos automáticos
const FALCON_DIVE_POWER := 0.8            # poder do mergulho automático (ATK do caçador; peso ASC_BUILD_POWER["cacador"])
const FALCON_RANGE := 14.0                # m do caçador: até onde o falcão mergulha e alcance do Mergulho (x ARCHER_RANGE_MULT, como toda skill de arco)
const FALCON_PREY_ID := "falcon_prey"     # maldição Presa (marca: entra no teto MARK_TAKEN_CAP)
const FALCON_TAKEN := 3.0                 # % de dano a mais que a Presa recebe de todos (H; F5 ~1,06 no grupo)
const FALCON_PREY_TIME := 8.0             # s da Presa
const FALCON_STOOP_POWER := 1.6           # skill Mergulho: poder
const FALCON_STOOP_CD := 12.0             # skill Mergulho: recarga
const FALCON_STOOP_STUN := 0.6            # skill Mergulho: atordoa (em chefe vale a regra de controle: x0,4)
const FALCON_EYES_TIME := 10.0            # Olhos do Céu: duração
const FALCON_EYES_CD := 30.0              # Olhos do Céu: recarga
const FALCON_EYES_RADIUS := 15.0          # m: grupo que recebe
const FALCON_EYES_CRIT := 4.0             # crítico a mais contra alvo com Presa (stat `prey_crit`)
const FALCON_EYES_SPEED := 10.0           # % de velocidade de movimento
const FALCON_ROYAL_RANGE := 8.0           # refino 40 (Falcão Real): a Presa de quem morre passa ao inimigo mais perto a isto
const FALCON_FLOCK := 3                   # refino 45 (Revoada): falcões/alvos de Olhos do Céu
const FALCON_WEB_PCT := 15.0              # % de dano do mergulho por nó "falcon_pct" da teia de ascensão
const FALCON_FLAG_ROYAL := "falcon_royal" # portões da teia de ascensão (AscensionCatalog.NODES)
const FALCON_FLAG_FLOCK := "falcon_flock"
const FALCON_HOVER := 3.2                 # m acima do caçador (só desenho: a sim é plana)
const FALCON_DIVE_SHOW := 0.7             # s que o desenho leva no mergulho (ida e volta)
## Teto do "dano recebido" somado das MARCAS num alvo (várias fontes/caçadores): Marca do Predador (Lanceiro), Presa,
## arma lendária `mark` (Marca do Caçador). As outras maldições (Necromante, Assassino, Paladino) somam por fora, como antes.
const MARK_TAKEN_CAP := 25.0
const MARK_CURSES := ["predator", "legend_mark", "falcon_prey", "sunder"]

## --- Preenchimento de skills (GDD design/gdd/skills-fill-2026-11-19.md): as 4 mecânicas novas ---
## M1 "zone" (TrapSystem.place_zone): chão que fica `duration` s e pulsa a cada `pulse` s: inimigos dentro levam
## foe_power x ATK/MATK (sem crítico; a AGI esquiva) e o `dot` da skill renova; aliados dentro (você incluso) recebem
## ally_heal x a cura (Combat.calc_heal) e o ally_buff por pulse + ZONE_BUFF_LINGER s; foe_slow = % de lentidão no pulso.
## Uma zona por (lançador, skill): lançar de novo apaga a antiga; some com o dono morto ou fora do mapa.
const ZONE_BUFF_LINGER := 0.5
const HALLOWED_ZONE := {"id": "hallowed", "duration": 6.0, "pulse": 1.0, "foe_power": 0.25, "ally_heal": 0.0,
	"ally_buff": {"id": "hallowed", "def_pct": 10}}          # Chão Sagrado (Templário)
const FAITH_BANNER_ZONE := {"id": "faith_banner", "duration": 8.0, "pulse": 1.0, "foe_power": 0.2, "ally_heal": 0.25,
	"foe_slow": 20.0}                                        # Estandarte da Fé (Clérigo de Batalha)
## M2 "sunder" (SunderSystem): cada acerto põe/renova o debuff SUNDER_ID no alvo (um por alvo, de qualquer Executor):
## +taken_per % de dano recebido por carga até `max` (é MARCA: teto MARK_TAKEN_CAP). Skill com "sunder_consume": antes do
## golpe lê as cargas, power x (1 + per x cargas) e zera. Chefe acumula normal (não é controle).
const SUNDER_ID := "sunder"
const SUNDER := {"add": 1, "taken_per": 4.0, "max": 5, "duration": 8.0}     # Fender Armadura
const SUNDER_CONSUME := {"per": 0.10}                      # Golpe Avassalador, Executar, Decapitar
## M3 "seed" (SeedSystem): debuff "seed_<lançador>" no alvo; ao fim de `delay` s OU na morte do alvo explode em `radius` m:
## power x MATK em até max_targets inimigos (o alvo, se vivo, incluso) e, com spread_dot, a queimadura da skill neles
## (pelo teto de cópias por skill). A explosão não planta semente. Relançar renova; dono morto/fora do mapa: some sem explodir.
const EMBER_SEED := {"delay": 4.0, "radius": 3.0, "power": 1.4, "spread_dot": true, "max_targets": 6}     # Semente Ígnea
## M4 "sacrifice" (SummonRites): até `max` invocações SUAS a pick_radius m do ponto (as mais perto primeiro), fora as de
## SACRIFICE_EXCLUDE, explodem em blast_radius: power x (1 - hp_weight + hp_weight x % de vida dela) x MATK, e morrem sem
## XP/saque. Sem nenhuma elegível a skill é recusada antes de gastar MP.
const DARK_OFFERING := {"pick_radius": 6.0, "max": 4, "blast_radius": 3.0, "hp_weight": 0.5}     # Oferenda Sombria
const SACRIFICE_EXCLUDE := ["skeleton_king", "lich_servant", "companion", "spirit_wolf", "treant", "ranger_turret", "fire_elemental", "frost_elemental", "storm_elemental"]
## Onda 2 (GDD skills-fill §8). Ferida/veneno (WoundSystem.is_wound) = dano no tempo SEU que não é queimadura nem o
## sangramento por % do ATK do Lanceiro. Eviscerar ("combust" kind poison): os venenos saem, o que faltava explode
## x detonate e o golpe ganha `per` de poder por veneno consumido (até `max`).
const EVISCERATE_POISON := {"kind": "poison", "detonate": 1.25, "per": 0.10, "max": 5}
## Sangria (Carniceiro): cura `pct`% da vida máx. por inimigo atingido que sangrava (ferida sua), até `max` alvos.
const WOUND_WHIRL := {"pct": 5.0, "max": 4}
const WOUND_WHIRL_TALENT_PCT := 7.0       # talento Redemoinho Sedento (Berserker 25) na Sangria
## Presas Gêmeas: +add s nas feridas suas em cada atingido, sem passar de `cap` s restantes.
const WOUND_EXTEND := {"add": 2.0, "cap": 8.0}
## Aparar do Duelista (RiposteSystem, Guarda do Duelista): janela RIPOSTE_WINDOW s; golpe direto de quem está a até
## RIPOSTE_RANGE m, dentro do arco da guarda, sai 0 (chefe: -RIPOSTE_BOSS_CUT) e devolve RIPOSTE_COUNTER_PCT% do ATK
## (até RIPOSTE_MAX_COUNTERS por janela). Cada aparada dá 1 Ímpeto (+crítico por carga); o Golpe de Mestre gasta todos.
const RIPOSTE_BUFF := "duel_guard"
const RIPOSTE_WINDOW := 1.0
const RIPOSTE_CD := 8.0
const RIPOSTE_RANGE := 4.0
const RIPOSTE_BOSS_CUT := 0.6
const RIPOSTE_COUNTER_PCT := 80.0
const RIPOSTE_MAX_COUNTERS := 2
const RIPOSTE_MOMENTUM_BUFF := "impeto"
const RIPOSTE_MOMENTUM_MAX := 3
const RIPOSTE_MOMENTUM_CRIT := 5.0
const RIPOSTE_MOMENTUM_TIME := 10.0
const RIPOSTE_SPEND_PCT := 20.0           # Golpe de Mestre: +% de poder por carga de Ímpeto gasta
const BOT_RIPOSTE_SCORE := 6.0            # bot: Guarda quando o inimigo colado prepara um golpe nele
const BOT_RIPOSTE_CROWD := 2              # ... ou com tantos inimigos em cima dele
## Bots: finalizador que gasta a rachadura espera o Fender (pronto) até BOT_SUNDER_MIN cargas (ou alvo abaixo de
## BOT_SUNDER_LOW_HP); Oferenda só com BOT_SACRIFICE_MIN mortos-vivos perto do alvo; skills de "vida baixa" (fração da vida).
const BOT_SUNDER_MIN := 3
const BOT_SUNDER_LOW_HP := 0.25
const BOT_SACRIFICE_MIN := 3
const BOT_LOW_HP_SKILLS := {"ran_field_dressing": 0.45}
const BOT_LOW_HP_SCORE := 3.0
const BOT_FALCON_CALL_SCORE := 5.0        # bot: chama o falcão antes de tudo (uma vez; fica até o dono cair)
const BOT_FALCON_DIVE_SCORE := 3.6        # bot: Mergulho sempre que sai da recarga (no alvo do tanque)
const BOT_FALCON_EYES_SCORE := 3.2        # bot: Olhos do Céu em chefe (abertura e a cada recarga) e quando aparece barragem

## Pontos da teia ganhos ao chegar no nível `level`.
static func points_at(level: int) -> int:
	return MASTERY_POINTS_PER_LEVEL + (1 if level in MASTERY_BONUS_LEVELS else 0)

static func xp_for_level(level: int) -> int:
	if level >= MAX_LEVEL:
		return 0
	var mob_xp := XP_MOB_BASE + XP_MOB_PER_LEVEL * level
	return int(round(level_minutes(level) * XP_KILLS_PER_MIN * mob_xp / (1.0 - XP_QUEST_SHARE)) / 10.0) * 10

## XP de um monstro comum do nível (base da curva e da experiência do elemental, F6).
static func mob_xp(level: int) -> float:
	return XP_MOB_BASE + XP_MOB_PER_LEVEL * level

## Minutos de jogo planejados no nível (o teste do orçamento de XP usa). Do XP_ACT2_FROM em diante cresce
## XP_MIN_PER_LEVEL_ACT2 por nível a partir do valor do Ato I nesse nível (GDD Ato II F1).
static func level_minutes(level: int) -> float:
	if level < XP_ACT2_FROM:
		return XP_MIN_BASE + XP_MIN_PER_LEVEL * (level - 1)
	return XP_MIN_BASE + XP_MIN_PER_LEVEL * (XP_ACT2_FROM - 1) + XP_MIN_PER_LEVEL_ACT2 * (level - XP_ACT2_FROM)

## XP total para atravessar a faixa [de, até).
static func band_xp(from_lv: int, to_lv: int) -> int:
	var t := 0
	for lv in range(from_lv, to_lv):
		t += xp_for_level(lv)
	return t

## Tier efetivo dos bônus percentuais de conjunto: i_ef = min(i, 5) + 0,5 × max(0, i − 5) (GDD Ato II F10).
static func set_pct_tier(tier: int) -> float:
	return float(mini(tier, SET_PCT_FULL_TIERS)) + SET_PCT_LATE_RATE * float(maxi(0, tier - SET_PCT_FULL_TIERS))

static func mastery_cost(current_level: int) -> int:
	return current_level + 1

## Ato III — monstros (design/gdd/ato3-excesso-45-50.md §3/§6.2; WP3). Números pela F2 (horde_stat, sem teto até 50);
## o "demônio" (Bailarinos, Galgos, Coro, Reflexos) ganha este mod_unidade por cima do mod de cada monstro (D7):
## vida ×0,8, ATK ×1,15 e intervalo do golpe básico ×0,8. Sem esquiva de monstro (D4 = b): "esquivo" = bote, recuo, furtividade.
const ACT3_DEMON_MODS := {"hp": 0.8, "atk": 1.15, "cooldown": 0.8}
const ACT3_MOD_FLOOR := 0.6                # mod_unidade final nunca abaixo disto (faixa do check F2: 0,6-2,0)
const ACT3_REVELER_COOLDOWN := 0.8         # Folião Mascarado: básico rápido (intervalo × isto, além do fator 40+)
const ACT3_FACTION := "feast"              # facção do Excesso (aura festim)
## Decisão de calibragem (WP3, 2026-11-21; band_probe --from=45 --to=50 --trials=16): com a F2 pura os bots 45-49 matavam
## comum/bruto em 1,0-2,2 s com 3-8% de vida perdida ("trivial" em 10 de 12). Mesmo remédio do HORDE_LATE_40: a vida do papel
## ganha este fator do 45 em diante (elites pelo mod_unidade; chefes calibrados no boss_probe, WP8). Faixa segura 1,5-2,5.
## `atk` (decisão do usuário 2026-11-23; GDD §6.2): com a vida ×2 a caçada ficou lenta o bastante, mas o bot perdia 3-15% da vida
## (alvo AC3-07: 14-22%). O ATK do papel ganha este fator do 45 em diante (horde_stat "atk"); elite entra (só ATK, a vida dela é
## do mod_unidade); chefe NUNCA (boss_probe, WP8). Lacaios de chefe não têm stat_role: não mudam. Faixa segura 1,0-2,5 (check).
## O `atk` daqui multiplica o do HORDE_LATE_40 (horde_late): total 45+ = comum 1,8×0,89 ≈ 1,6, bruto 2,0×0,75 = 1,5, elite 2,0×1,05 = 2,1
## (os números medidos no 1º passe); por isso fica < 1 no comum/bruto. O check confere o total (1,0-2,5).
const ACT3_LATE_45_LEVEL := 45
const ACT3_LATE_45 := {"comum": {"hp": 2.0, "atk": 0.89}, "bruto": {"hp": 2.0, "atk": 0.75}, "elite": {"atk": 1.05}}

## Ato III — chefes de mundo (design/gdd/ato3-excesso-45-50.md §4, D11; WP8a): afinados para TRIO (faixa "grupo" do
## boss_probe --bands), renascem a cada WORLD_BOSS_RESPAWN_S (spawner do mapa). Números das assinaturas só aqui.
const WORLD_BOSS_RESPAWN_S := 600.0
## Dona Vindima — Prensa (sair do centro): puxa quem está a até PRESS_PULL_R m e, PRESS_DELAY s depois, esmaga um círculo
## de PRESS_RADIUS m em volta dela (R-A circle, on_self). Quem correu para fora leva 0.
const ACT3_PRESS_POWER := 2.2
const ACT3_PRESS_EVERY := 28.0
const ACT3_PRESS_RADIUS := 6.0
const ACT3_PRESS_DELAY := 1.5
const ACT3_PRESS_PULL_R := 14.0
## A Prima-Donna — Ária em Três Tempos (ritmo): 3 anéis em volta dela, perto (0-W), meio (W-2W), longe (2W-3W), um a cada
## ARIA_STAGGER s depois de ARIA_DELAY (R-A ring com stagger, o mesmo molde das Ondas da Montanha).
const ACT3_ARIA_POWER := 1.4
const ACT3_ARIA_EVERY := 26.0
const ACT3_ARIA_WIDTH := 4.0
const ACT3_ARIA_DELAY := 1.5
const ACT3_ARIA_STAGGER := 1.2

## Ato III — chefes da história e da raide (§4.1/§4.2, D8/D9; WP8b). Vessaline (rift_garden, Pavilhão, grupo de 4):
## Cortejo de Lâminas = CORTEGE_COUNT faixas encadeadas (BossSignatures.place_cortege), cada uma de CORTEGE_LEN m × CORTEGE_W m
## numa vítima sorteada (nunca o tanque); todas aparecem juntas, a 1ª cai em CORTEGE_DELAY s e as outras a cada
## CORTEGE_STAGGER s; ela investe pela faixa que caiu e a cauda deixa a faixa CORTEGE_LINGER s (tique CORTEGE_TICK).
## O GDD pede 1,4 s; 1,5 = o mínimo de aviso de assinatura (BOSS_SIG_WARN_MIN).
const ACT3_CORTEGE_POWER := 1.6
const ACT3_CORTEGE_EVERY := 24.0
const ACT3_CORTEGE_COUNT := 4
const ACT3_CORTEGE_LEN := 10.0
const ACT3_CORTEGE_W := 2.0
const ACT3_CORTEGE_DELAY := 1.5
const ACT3_CORTEGE_STAGGER := 0.7
const ACT3_CORTEGE_LINGER := 3.0
const ACT3_CORTEGE_TICK := 0.2               # power de cada tique (BOSS_LINGER_TICK s) na faixa que ficou
## Palco Seguro (F3) e as ilhas do Eco (F3): ilhas FIXAS na arena (offsets da casa do chefe, do boss_hint do JSON), raio
## STAGE_ISLAND_R; quem está fora de todas leva STAGE_POWER.
const ACT3_STAGE_POWER := 1.8
const ACT3_STAGE_EVERY := 30.0
const ACT3_STAGE_DELAY := 3.0
const ACT3_STAGE_ISLAND_R := 4.0
## O Eco de Sylvaré (rift_heart, raide de 5): Sede Dividida = marca que alterna dividir (soak, dourado) e espalhar (spread,
## roxo) a cada THIRST_EVERY s; entre BOTH_HP (vida) as duas juntas (F2). Pedestais dos Sentidos: Paladar cura
## TASTE_PCT da vida do Eco por segundo (o matk do pedestal sai disto em _act3_adds), Audição bate em todos a cada NOTE_EVERY s.
const ACT3_THIRST_EVERY := 20.0
const ACT3_THIRST_SOAK_POWER := 2.0
const ACT3_THIRST_SPREAD_POWER := 1.0
const ACT3_THIRST_RADIUS := 4.0
const ACT3_THIRST_TIME := 4.0
const ACT3_THIRST_BOTH_HP := [0.4, 0.7]
const ACT3_TASTE_PCT := 0.004               # GDD pedia 1%/s: igual ao dano da raide inteira (lutas de 250+ s na sonda); 0,4%/s = ~1/3
const ACT3_NOTE_EVERY := 6.0

## ---- Ato III, chefes das masmorras (WP8b; GDD ato3-excesso-45-50 §4.1/4.2; grupo de 4) ----
## Varo — O Banquete (R-C): canal BANQUET_TIME s a cada BANQUET_EVERY s; no fim cura BANQUET_HEAL da vida e +BANQUET_ATK % de
## ATK por BANQUET_BUFF_S s nele e nos lacaios; quebrado (BOSS_CHANNEL_BREAK_PCT ou atordoar) = +BANQUET_VULN % de dano por BANQUET_VULN_S s.
const ACT3_BANQUET_EVERY := 35.0
const ACT3_BANQUET_TIME := 4.0
const ACT3_BANQUET_HEAL := 0.06
const ACT3_BANQUET_ATK := 25.0
const ACT3_BANQUET_BUFF_S := 12.0
const ACT3_BANQUET_VULN := 15.0
const ACT3_BANQUET_VULN_S := 6.0
## Condessa — Olhar Que Julga (R-E): a cada GAZE_EVERY s sobem os Espelhos de Pé (cobertura de MIRROR_R m nos pontos do
## boss_hint) e GAZE_WARN s depois o raio bate GAZE_POWER em todos a até GAZE_RADIUS m sem espelho entre si e ela.
## Espelho que protegeu racha e fica MIRROR_CRACKED_S s no chão só como desenho.
const ACT3_GAZE_EVERY := 30.0
const ACT3_GAZE_WARN := 3.0
const ACT3_GAZE_POWER := 2.4
const ACT3_GAZE_RADIUS := 30.0
const ACT3_MIRROR_R := 2.5
const ACT3_MIRROR_CRACKED_S := 6.0
## Ressoa — Cânone (R-B spread): CANON_COUNT marcas em vítimas sorteadas, raio CANON_RADIUS, caem em CANON_TIME s; marcas
## com centros a <= CANON_TOUCH m dobram (× CANON_TOUCH_MULT) as duas.
const ACT3_CANON_EVERY := 24.0
const ACT3_CANON_POWER := 1.0
const ACT3_CANON_COUNT := 3
const ACT3_CANON_RADIUS := 2.0
const ACT3_CANON_TIME := 4.0
const ACT3_CANON_TOUCH := 4.0
const ACT3_CANON_TOUCH_MULT := 2.0
