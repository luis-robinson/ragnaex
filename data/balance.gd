extends Node
## Todas as constantes de balanceamento num lugar só (autoload `Balance`).

const MAX_LEVEL := 30
const ATTRS := ["FOR", "AGI", "VIT", "WILL", "INT"]
## Escala dos atributos: cada ponto vale 1/ATTR_SCALE do antigo (a teia dá +1 na estrada e +5..+10 nos círculos).
## Os catálogos de equipamento e conjuntos seguem na escala antiga e são multiplicados ao carregar (GameData.load_all).
const ATTR_SCALE := 10
## Poder das skills de cada build (setor da teia) x isto, aplicado ao carregar (GameData.load_all). Calibrado com
## dps_probe (dano no boneco) e boss_probe --lead=<classe>:<build> (vitórias solo): ver docs/DESIGN.md "Equilíbrio entre builds".
const BUILD_POWER := {"inquisidor": 0.6, "ceifador": 0.85, "invocador": 0.85, "carniceiro": 0.88, "batalha": 0.88,
	"laminas": 2.3, "duelista": 1.7, "fera": 1.6, "raio": 1.35, "guardiao": 1.5}

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
const SHIELD_DEF_POWER := 0.003        # skill de escudo: +0,3% por DEF do escudo
const SHIELD_DEF_POWER_MAX := 0.3
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
const XP_QUEST_SHARE_BAND := {1: 0.5, 10: 0.55, 20: 0.65}   # 20-30: a guarnição e o grupo matam muito, então a guerra paga mais por quest   # 1-10: mais quests no 6-7; faixa do meio (10-20): quests pedem mais abates e pagam mais

## Parte da XP da faixa que começa em `band_start` que vem de quests.
static func quest_share(band_start: int) -> float:
	return float(XP_QUEST_SHARE_BAND.get(band_start, XP_QUEST_SHARE))
const XP_BANDS := [[1, 10], [10, 20], [20, 30]]
const DEATH_XP_PENALTY := 0.03
# pontos da teia (estilo Path of Exile): skills, maestria, evoluções, atributos e notáveis. 8 por nível (+1 no 10/20/30)
# = 235 no 30, numa teia de ~250-360 nós (+ maestrias): muita liberdade, mas não dá para pegar tudo.
const MASTERY_POINTS_PER_LEVEL := 8
const MASTERY_BONUS_LEVELS := [10, 20, 30]  # +1 ponto extra
const MASTERY_MAX := 5
const MASTERY_BONUS_PCT := 0.1     # cada nível de maestria: +10% nos bônus de buff e forma (só os positivos; tempo não muda)
const SKILL_LEARN_COST := 1
## Quanto a teia rende no 30 (bot da build, com e sem tree_bonus; web_probe e _check_web_strength).
## Média das builds de ATK e HP dentro da faixa; cada build com ATK×HP dentro de WEB_GAIN_BUILD (tanque troca ATK por HP).
const WEB_GAIN_ATK := [1.3, 1.5]
const WEB_GAIN_HP := [1.1, 1.3]
const WEB_GAIN_BUILD := [1.2, 2.3]
const SKILL_SLOTS := 6
const LOADOUT_TOWN_ONLY := true             # trocar skills da barra só na cidade

# --- combate / game feel ---
const INPUT_BUFFER_TICKS := 15              # 0,25 s: apertar durante o golpe não se perde
const CAST_MOVE_MULT := 0.6                 # anda a 60% durante golpes e magias rápidas
const CAST_MOVE_MULT_HEAVY := 0.25          # magias longas (preparo >= CAST_HEAVY_STARTUP) quase param
const CAST_HEAVY_STARTUP := 0.45
const CANCEL_AFTER_MAX := 0.08              # teto da espera entre o fim do golpe e poder cancelar
const BIG_SWING_WEAPONS := ["sword2h", "mace2h", "axe2h"]     # armas corpo a corpo de duas mãos: golpe básico largo
const BIG_SWING_REACH_MULT := 1.4          # alcance do golpe básico x1,4
const BIG_SWING_ARC_DEG := 150.0           # e arco mais aberto (o normal é 110°)
const BIG_SWING_MAX_TARGETS := 4           # acerta até 4 (o normal é 2)
const BUFF_DURATION_CAP := 80.0            # % máximo de duração extra das bênçãos
const RADIANCE_CAP := 40.0                 # % máximo de Radiância
const RADIANCE_RANGE := 10.0               # m: alcance da cura da Radiância
## Druida: formas de animal (buff enquanto transformado) e a arma que cada forma exige
const FORM_STATS := {"wolf": {"aspd_pct": 25, "speed_pct": 20, "atk_pct": 10, "crit": 5}, "bear": {"def_pct": 40, "hp_pct": 25, "atk_pct": 10, "speed_pct": -10},
	"phantom": {"speed_pct": 25, "evasion": 20, "matk_pct": 10},          # Necromancer: forma fantasma (rápida, difícil de acertar)
	"demon": {"matk_pct": 20, "hp_pct": 25, "def_pct": 20, "lifesteal": 6}}   # Necromancer: demônio (grande, aguenta e drena)
const FORM_REQUIRES := {"wolf": "dual_mace", "bear": "mace2h", "phantom": "scythe", "demon": "scythe"}
const FORM_DURATION := {"phantom": 10.0}     # s; forma fora daqui fica até desligar (lobo, urso, demônio)
const AMBUSH_MULT := 1.6                  # golpe que sai da furtividade
## Ranger Atirador: o mosquete atira mais devagar e bate muito mais forte que o arco
const RIFLE_COOLDOWN_MULT := 1.8
const RIFLE_POWER_MULT := 1.9
const RIFLE_RANGE_MULT := 1.2
## Ranger Lanceiro: a lança estoca em linha, mais longe que espada e machado e bem mais perto que o arco
const SPEAR_REACH := 3.3                 # m (espada ~1,9; montante ~2,7; arco 13)
const SPEAR_ARC_DEG := 40.0              # estocada estreita: o que está na frente da ponta
const SPEAR_MAX_TARGETS := 3             # atravessa a fila
const SPEAR_POWER_MULT := 1.15
const SPEAR_COOLDOWN_MULT := 1.1
const BLEED_TIME_DEFAULT := 4.0          # s do sangramento das skills de lança (dot com atk_pct)
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
const PATROL_PACE := 0.45              # líder em ronda anda devagar (a escolta acompanha)
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
## Montaria (H): só fora de combate; atacar, usar skill, dash, bloquear ou levar dano desmonta
const MOUNT_SPEED_MULT := 1.7
const MOUNT_COMBAT_LOCK := 3.0            # s de "em combate" depois do último golpe/dano (bots não montam nisso; o jogador pode)
const MOUNT_CAST_TIME := 1.5              # s de conjuração para montar (H); dá para andar; agir ou levar golpe interrompe
const BOT_MOUNT_CHANCE := 0.04            # por pensamento, bot andando fora de combate monta
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
## Punhos de Fúria (Berserker de duas garras, FistSystem): esquivar dá Fúria do Punho e contra-ataca
const FIST_FURY_BUFF := "fist_fury"
const FIST_FURY_MAX := 5
const FIST_FURY_TIME := 8.0               # s sem esquivar até as cargas sumirem (renova a cada carga)
const FIST_FURY_ATK_PCT := 6.0            # +% ATK por carga
const FIST_FURY_ASPD_PCT := 5.0           # +% velocidade de ataque por carga
const FIST_COUNTER_PCT := 60.0            # contra-ataque ao esquivar: % do ATK (a arma lendária soma)
const FIST_COUNTER_RANGE := 3.2           # m: só devolve em quem está perto
const STORM_STUN_CHANCE := 15.0            # % de chance de skill de raio atordoar no golpe direto (a que já atordoa não rola)
const STORM_STUN_TIME := 0.5              # s (chefes: 40%, como todo atordoar)
const FROST_SHATTER_MULT := 1.3            # skill de gelo em alvo retardado/preso/atordoado: +30% de dano ("estilhaço")
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
## IA dos bots no combate
const BOT_POTION_HP_MELEE := 0.45          # corpo a corpo bebe poção de vida abaixo disto (os outros: 0.35)
const BOT_FLEE_HP := 0.2                   # sem poção, abaixo disto recua por BOT_FLEE_TIME s
const BOT_FLEE_TIME := 2.5
const BOT_STICKY_RANGE := 16.0             # mantém o alvo atual enquanto ele estiver vivo e a até esta distância
# chefes (MobSystem): mira, chuva de golpes, gancho, fúria por tempo, escudo dos lacaios
const BOSS_PICK_RANGE := 16.0               # m: quem o chefe escolhe como vítima de skill com mob_pick
const BOSS_HAZARD_DELAY := 1.3              # s do aviso no chão até o golpe da chuva (barrage sem delay)
const BOSS_BERSERK_MULT := 1.6              # dano do chefe que passou de berserk_after
const BOSS_WARD_CHECK := 0.5                # s entre conferências dos lacaios vivos (ward)
const BOSS_FOLLOW := 5.0                    # m: skill de alvo de chefe (mob_pick) segue a vítima que andou até isto na preparação
const BOSS_PULL_GAP := 0.6                  # m entre o chefe e quem ele puxa
const BOT_DODGE_MIN_RADIUS := 1.2          # telegrafia menor que isto (golpe curto) não dá para fugir: bloqueia ou aguenta
const PARTY_SEEK_MAX := 3                  # /party: quantos bots do mapa oferecem grupo (um convite por vez)
const PARTY_SEEK_COOLDOWN := 20.0          # s entre dois /party
const STORAGE_SLOTS := 48                  # tipos de item no depósito (cada um empilha)
const NPC_WALK_SPEED := 1.9                # m/s dos moradores que passeiam
const NPC_WAIT_MIN := 3.0                  # s parado entre um passeio e outro
const NPC_WAIT_MAX := 10.0
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
## Bolsa: tipos de item diferentes que cabem (pilhas). Bolsa Ampliada I-IV soma BAG_STEP cada.
const BAG_BASE := 40
const BAG_STEP := 8
const BAG_UPGRADES := 4
const GATHER_RANGE := 2.4                  # m até o ponto de colheita (F)
const GATHER_TIME := 1.1                   # s colhendo (andar, atacar ou levar dano cancela)
const GATHER_RESPAWN := 75.0               # s até o ponto voltar
const STATION_RANGE := 6.0                 # m até o NPC de serviço (depósito) para usar
const CDR_CAP := 25.0                       # % máximo de recarga a menos em todas as skills (talentos de escolha)
const PICK_SWAP_TOWN_ONLY := true           # trocar a escolha de uma linha de talentos: só na cidade (de graça)
const ATTACK_SPEED_CAP := 60.0              # % máximo de velocidade de ataque
const CHAIN_AFTER_IMPACT := 0.05            # depois do impacto, outra skill/ataque já pode sair (o quadro do golpe ainda aparece)
const HIT_STOP_FRAMES_BASIC := 2
const DASH_DISTANCE := 3.2
const DASH_TIME := 0.18
const DASH_IFRAMES := 0.18              # s invulnerável a golpe direto depois de sair o dash (o dash inteiro; dano no tempo continua)
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
const RAID_WAVE_CAP := 50                   # teto de invasores por leva (FPS)
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
const HIT_FLASH_TIME := 0.12               # piscada branca de quem apanha
const NOTICE_CD := 3.0                     # aviso repetido (bolsa cheia ao pisar no baú) espera isto
const ENTITY_RADIUS := 0.45

# --- equipamento gerado (data/catalog/gear_catalog.gd) ---
# poder de item escala com o nível: fator = (nível + OFFSET) / (REF + OFFSET); nível REF = valores-base da tabela
const GEAR_REF_LEVEL := 24.0
const GEAR_LEVEL_OFFSET := 4.0
const GEAR_ATTR_PRIMARY_PER_LEVEL := 0.62     # pontos do atributo principal por nível (peça de peso 1)
const GEAR_ATTR_SECONDARY_PER_LEVEL := 0.3
const COMMON_TIER_LEVELS := [1, 8, 16, 24]
const OFFHAND_WEAPON_ATK_MULT := 0.6          # empunhando duas: a 2ª arma soma 60% do ATK (atributos inteiros)

# --- lendários: um conjunto por classe a cada 5 níveis ---
const GEAR_DROP_CHANCE := 0.02                # calça/capa/amuleto/anel comum, por monstro morto
const GEAR_DROP_CHANCE_BOSS := 0.5
const GEAR_SHOP_TIERS := 2                    # mercador vende esses tiers; os de cima só caem de monstro
const LEGENDARY_LEVELS := [5, 10, 15, 20, 25, 30]
const LEGENDARY_MULT := 1.2                   # ATK/DEF/atributos vs. item comum do mesmo nível
const LEGENDARY_DROP_CHANCE := 0.01           # por monstro morto (1 em 100); cada membro do grupo rola o seu
const LEGENDARY_DROP_CHANCE_BOSS := 0.4
## Arma lendária: efeito próprio da build (GearCatalog.LEGEND_EFFECTS); aqui só os limites comuns
const LEG_THORNS_RANGE := 4.0
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
const PLUS_ELF_LEVEL := 20                  # lendário deste nível (Glória) aprimora com materiais élficos
const PLUS_ELF_GOLD_MULT := 0.6
const PLUS_DAWN_LEVEL := 25                 # lendário 25+ (Bastião da Aurora) aprimora com Prata Consagrada e Fragmento da Aurora
const PLUS_DAWN_GOLD_MULT := 0.6
const LEGENDARY_COINS_BOSS := 2              # chefe (e Rei) solta 2 moedas lendárias; monstro comum, 1
## O lendário cai como Moeda Lendária; a Relicária troca: peça do tier i (LEGENDARY_LEVELS) custa i+1 moedas
const LEGENDARY_START_MAP := "city_aldara"     # primeiro mapa: o 1º conjunto (tier de LEGENDARY_LEVELS[0]) cai mais
const LEGENDARY_START_MAP_CHANCE := 0.04       # por monstro comum (1 em 25) no primeiro mapa, só no 1º tier
const LEGENDARY_LEVEL_SLACK := 2              # monstro nível N dropa o tier mais alto <= N + slack
# bônus de conjunto (tier = índice em LEGENDARY_LEVELS, 0..5)
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

# --- bots ---
const BOT_CHAT_MIN := 25.0
const BOT_CHAT_MAX := 90.0
const BOT_CHAT_PLACE := 0.5                # conversa solta: chance de falar do lugar (senão da classe/build)
## Bot druida entra na forma (Lobo/Urso) quando há inimigo a BOT_FORM_RANGE m; antes nunca se transformava e lutava
## como humano com as skills da forma (Lobo e Urso 0/40 solo). Formas do Necromante seguem fora (têm hora certa).
const BOT_AUTO_FORMS := ["wolf", "bear"]
const BOT_FORM_RANGE := 12.0
const BOT_FORM_SCORE := 9.0                # acima de qualquer golpe: a forma vem primeiro
## Abertura furtiva do bot (Sumir): só fora de combate, com o alvo ainda sem mirá-lo e a até BOT_STEALTH_RANGE m (no meio
## da luta, um chefe solo perderia o alvo e resetaria). Na sombra contorna até as costas; sai golpeando com BOT_STEALTH_STRIKE_LEFT s restando.
const BOT_STEALTH_RANGE := 10.0
const BOT_STEALTH_SCORE := 8.0
const BOT_STEALTH_STRIKE_LEFT := 1.5
const BOT_STEALTH_BACK_GAP := 0.6           # m atrás do alvo (além dos raios)
## Fuga: com o alvo em cima e vida abaixo disto, some no meio da luta (o alvo perde o bot; ele volta golpeando pelas
## costas antes de o chefe sair de combate: AGGRO_LOSE_TIME > tempo na sombra até o golpe).
const BOT_STEALTH_ESCAPE_HP := 0.45
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
const DR_CAP := 40.0                       # % máx de redução de dano por buff/aura (Stats.dr_pct)
const AURA_TICK := 0.5                     # s entre renovações da aura do tanque nos aliados (AuraSystem)
const AURA_PULSE_EVERY := 1.0             # s entre pulsos de dano da aura do tanque (AuraSystem.pulse)
const AURA_KEEP := 1.3                     # s que o buff da aura dura no aliado sem renovar (saiu do raio = some logo)
const LOOT_LOCK_TIME := 20.0               # s em que só o dono pega o item; depois fica livre
const PORTAL_NOTICE_CD := 4.0              # s entre avisos de portal bloqueado
const PARTY_MAX := 5                       # membros por grupo
const PARTY_NEARBY_RANGE := 40.0          # m: janela P lista quem dá para convidar até esta distância
const PARTY_SHARE_RANGE := 45.0            # m: membros vivos no mesmo mapa e dentro disto dividem XP e quests de abate
const PARTY_XP_BONUS := 0.15               # +15% de XP total por membro extra que divide o abate
const PARTY_LEVEL_GAP := 15                # diferença máx. de nível para dividir XP (e para bots aceitarem convite)
const PARTY_INVITE_TIME := 30.0            # s até o convite expirar
const PARTY_FOLLOW_DIST := 3.5             # bots seguidores ficam a esta distância do líder
const PARTY_ASSIST_RANGE := 14.0           # bots atacam o que bate no grupo dentro deste raio do líder
const BOT_PARTY_ACCEPT := 0.8              # chance de um bot aceitar um convite válido
const BOT_PARTY_FORM_CHANCE := 0.35        # bot que sai para caçar chama outros bots da vila
const BOT_INVITE_PLAYER_CHANCE := 0.12     # ... ou chama o jogador, se ele estiver por perto e sem grupo

## Pontos da teia ganhos ao chegar no nível `level`.
static func points_at(level: int) -> int:
	return MASTERY_POINTS_PER_LEVEL + (1 if level in MASTERY_BONUS_LEVELS else 0)

static func xp_for_level(level: int) -> int:
	if level >= MAX_LEVEL:
		return 0
	var minutes := XP_MIN_BASE + XP_MIN_PER_LEVEL * (level - 1)
	var mob_xp := XP_MOB_BASE + XP_MOB_PER_LEVEL * level
	return int(round(minutes * XP_KILLS_PER_MIN * mob_xp / (1.0 - XP_QUEST_SHARE)) / 10.0) * 10

## Minutos de jogo planejados no nível (o teste do orçamento de XP usa).
static func level_minutes(level: int) -> float:
	return XP_MIN_BASE + XP_MIN_PER_LEVEL * (level - 1)

## XP total para atravessar a faixa [de, até).
static func band_xp(from_lv: int, to_lv: int) -> int:
	var t := 0
	for lv in range(from_lv, to_lv):
		t += xp_for_level(lv)
	return t

static func mastery_cost(current_level: int) -> int:
	return current_level + 1
