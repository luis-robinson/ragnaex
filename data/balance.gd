extends Node
## Todas as constantes de balanceamento num lugar só (autoload `Balance`).

const MAX_LEVEL := 30
const ATTRS := ["FOR", "AGI", "VIT", "WILL", "INT"]

# --- atributos -> stats derivados ---
const HP_PER_VIT := 12.0
const MP_PER_WILL := 8.0
const PATK_PER_FOR := 2.0
const PATK_PER_AGI_RANGED := 2.2      # arco: AGI substitui FOR
const PATK_PER_AGI_DAGGER := 1.0      # adaga: AGI complementa FOR
const PATK_PER_AGI_OTHER := 0.25
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
const XP_QUEST_SHARE_BAND := {10: 0.55}   # faixa do meio (10-20): quests pedem mais abates e pagam mais (parte maior da faixa)

## Parte da XP da faixa que começa em `band_start` que vem de quests.
static func quest_share(band_start: int) -> float:
	return float(XP_QUEST_SHARE_BAND.get(band_start, XP_QUEST_SHARE))
const XP_BANDS := [[1, 10], [10, 20], [20, 30]]
const DEATH_XP_PENALTY := 0.03
# pontos de skill: aprender skill, subir maestria e comprar evoluções. Não dá pra pegar tudo até o 30:
# ~61 pontos no total vs. 6 skills no máximo = 6 x (1 + 15) = 96 — escolher é a build.
const MASTERY_POINTS_PER_LEVEL := 2
const MASTERY_BONUS_LEVELS := [10, 20, 30]  # +1 ponto extra
const MASTERY_MAX := 5
const MASTERY_BONUS_PCT := 0.1     # cada nível de maestria: +10% nos bônus de buff e forma (só os positivos; tempo não muda)
const SKILL_LEARN_COST := 1
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
const ARCHER_RANGE_MULT := 1.35          # skills de arco/mosquete alcançam mais (o arqueiro luta de longe)
## armadilhas: arma em 0,6 s, no máximo 3 por ranger (a mais antiga some)
const TRAP_ARM_TIME := 0.6
const TRAP_MAX := 3
## companheiro do Caçador: parte da vida/ataque/defesa do dono
const PET_HP_SHARE := 0.7
const PET_ATK_SHARE := 0.5
const PET_DEF_SHARE := 0.8
## invocação com status do dono: ataque = MATK x share x (ATK do monstro / ref), limitado
const SUMMON_MATK_SHARE := 0.6
const SUMMON_ATK_REF := 12.0
const SUMMON_ATK_MIN := 0.6
const SUMMON_ATK_MAX := 2.5
## Montaria (H): só fora de combate; atacar, usar skill, dash, bloquear ou levar dano desmonta
const MOUNT_SPEED_MULT := 1.7
const MOUNT_COMBAT_LOCK := 3.0            # s depois do último golpe/dano antes de poder montar de novo
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
const RECALL_TIME := 3.0                   # s parado (fora de combate) para voltar à cidade com G
## IA dos bots no combate
const BOT_POTION_HP_MELEE := 0.45          # corpo a corpo bebe poção de vida abaixo disto (os outros: 0.35)
const BOT_FLEE_HP := 0.2                   # sem poção, abaixo disto recua por BOT_FLEE_TIME s
const BOT_FLEE_TIME := 2.5
const BOT_STICKY_RANGE := 16.0             # mantém o alvo atual enquanto ele estiver vivo e a até esta distância
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
const PLUS_ELF_LEVEL := 20                  # lendário deste nível (Glória) aprimora com materiais élficos
const PLUS_ELF_GOLD_MULT := 0.6
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

# --- grupo (party) ---
const THREAT_SWITCH := 1.1                 # monstro troca de alvo quando outro passa 110% da ameaça do alvo atual
const TAUNT_DURATION := 4.0                # s presos em quem provocou (chefes: metade)
const LOOT_LOCK_TIME := 20.0               # s em que só o dono pega o item; depois fica livre
const PORTAL_NOTICE_CD := 4.0              # s entre avisos de portal bloqueado
const PARTY_MAX := 5                       # membros por grupo
const PARTY_SHARE_RANGE := 45.0            # m: membros vivos no mesmo mapa e dentro disto dividem XP e quests de abate
const PARTY_XP_BONUS := 0.15               # +15% de XP total por membro extra que divide o abate
const PARTY_LEVEL_GAP := 15                # diferença máx. de nível para dividir XP (e para bots aceitarem convite)
const PARTY_INVITE_TIME := 30.0            # s até o convite expirar
const PARTY_FOLLOW_DIST := 3.5             # bots seguidores ficam a esta distância do líder
const PARTY_ASSIST_RANGE := 14.0           # bots atacam o que bate no grupo dentro deste raio do líder
const BOT_PARTY_ACCEPT := 0.8              # chance de um bot aceitar um convite válido
const BOT_PARTY_FORM_CHANCE := 0.35        # bot que sai para caçar chama outros bots da vila
const BOT_INVITE_PLAYER_CHANCE := 0.12     # ... ou chama o jogador, se ele estiver por perto e sem grupo

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
