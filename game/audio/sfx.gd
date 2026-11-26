class_name Sfx
extends Node
## Efeitos sonoros lidos do EventBus (como o FxManager; nunca muda a sim).
## Banco: res://assets/audio/sfx/<nome>_<n>.<ogg|wav>, gerado por tools/audio/build_sfx.py (CC0 + sintetizado);
## cada toque sorteia uma variação e um tom levemente diferente.
## Som do mundo sai de um AudioStreamPlayer3D no ponto do evento (o fone/caixa dá a direção), mas o volume
## é pela distância ao JOGADOR (a câmera fica a ~24 m de tudo): cheio até NEAR, some em FAR.
## Briga dos outros sai mais baixa; cada nome tem intervalo mínimo e teto de vozes (batalha grande não vira chiado).

const DIR := "res://assets/audio/sfx/"
const POOL := 28                 # vozes no mundo
const UI_POOL := 6
const NEAR := 8.0
const FAR := 40.0
const OTHERS_DB := -5.0          # golpes de quem não é você nem do seu grupo
const MIN_GAP := 0.035           # s entre dois toques do mesmo nome
const MAX_VOICES := 3            # do mesmo nome ao mesmo tempo
## Volume base por nome (dB). O que não está aqui toca em 0 dB.
const VOL := {
	"swing": -9.0, "hit": -6.0, "crit": -3.0, "hurt": -4.0, "block": -6.0, "parry": -2.0, "dodge": -8.0,
	"cast": -10.0, "bow": -6.0, "gun": -5.0, "arcane": -6.0, "fire": -5.0, "ice": -6.0, "lightning": -6.0,
	"holy": -6.0, "shadow": -5.0, "poison": -7.0, "nature": -6.0, "wind": -7.0, "earth": -4.0, "blood": -6.0,
	"lunar": -6.0, "summon": -6.0, "heal": -8.0, "bone": -6.0, "die_monster": -7.0, "die_boss": -2.0,
	"pickup": -8.0, "coins": -8.0, "gem": -4.0, "potion": -6.0, "equip": -8.0, "craft": -6.0, "gather": -6.0, "enhance_ok": -6.0,
	"door": -8.0, "click": -10.0, "page": -8.0, "ui_open": -14.0, "ui_close": -16.0, "level_up": -3.0, "ult_ready": -5.0, "dash_ready": -17.0,
	"quest_accept": -5.0, "quest_done": -3.0, "recall": -6.0, "recall_done": -5.0, "death": -3.0, "firework": -7.0,
	# Ato II (A Horda)
	"war_drum": -3.0, "drum_beat": -11.0, "net": -6.0, "wolf_howl": -7.0, "wolf_snarl": -8.0, "orc": -7.0,
	"goblin": -9.0, "goblin_shriek": -9.0, "naga": -8.0, "tide": -5.0,
	"troll_growl": -6.0, "troll_grunt": -7.0, "troll_die": -4.0, "troll_slam": -3.0, "troll_regen": -12.0,
	# Monte Kharzun (40-45)
	"lava_bubble": -12.0, "forge_hammer": -12.0, "chain_break": -4.0, "smoke_vanish": -6.0, "dire_howl": -6.0,
	"salamander_hiss": -8.0, "salamander_die": -7.0, "golem_rumble": -5.0, "golem_crumble": -3.0, "boulder": -4.0, "banner_plant": -4.0,
	# assinaturas dos chefes
	"sig_warn": -4.0, "drum_tear": -3.0,
	# Mata dos Zumbidos (4-8)
	"wasp_buzz": -10.0, "wasp_die": -9.0, "bear_growl": -7.0, "bear_roar": -4.0, "hive_crack": -5.0,
	# impactos por alvo (plano de combate 2026-11-23, C3d): golpe físico por família de arma, magia por tema
	"hit_blunt": -7.0, "hit_chop": -7.0, "hit_pierce": -8.0, "impact_fire": -11.0, "impact_ice": -11.0, "impact_lightning": -12.0,
	"impact_holy": -12.0, "impact_shadow": -11.0, "impact_nature": -11.0, "impact_arcane": -12.0,
	# vento antes do impacto das skills rápidas (pacote V2, 2026-11-23)
	"whoosh": -9.0, "whoosh_magic": -13.0,
	# Ato III parte 1 (O Excesso, WP12): sinos, guizos, leques, coro, espelhos, fumo, taças e as 7 assinaturas
	"bells": -6.0, "festim_bell": -12.0, "hound_bells": -9.0, "fan_open": -7.0, "shrill_note": -9.0, "mirror_crack": -4.0,
	"mirror_hum": -7.0, "mirror_flash": -7.0, "smoke_hiss": -14.0, "goblet_break": -7.0, "thirst_sigh": -12.0, "thirst_drain": -6.0,
	"press_creak": -5.0, "press_slam": -3.0, "gulp": -5.0, "toast_clink": -6.0, "aria": -6.0, "canon": -7.0,
	"cortege_horn": -5.0, "cortege_march": -4.0,
}
## Tema visual (FxManager.theme_of) -> som da skill. Físico não tem: quem soa é o golpe (swing/hit).
const THEME_SOUND := {
	"fire": "fire", "ice": "ice", "lightning": "lightning", "holy": "holy", "lunar": "lunar", "shadow": "shadow",
	"poison": "poison", "bone": "bone", "nature": "nature", "earth": "earth", "blood": "blood", "wind": "wind",
	"heal": "heal", "summon": "summon",
}
const RANGED_SOUND := {"bow": "bow", "rifle": "gun", "pistol": "gun"}
## Golpe físico no alvo pela família da arma de quem bateu ("hit" = lâmina, o som de sempre; sem arma = "hit").
const HIT_SOUND := {"sword": "hit", "sword2h": "hit", "dagger": "hit", "scythe": "hit",
	"mace": "hit_blunt", "mace2h": "hit_blunt", "scepter": "hit_blunt", "staff": "hit_blunt", "wand": "hit_blunt", "claw": "hit_blunt",
	"axe": "hit_chop", "axe2h": "hit_chop", "bow": "hit_pierce", "rifle": "hit_pierce", "pistol": "hit_pierce", "spear": "hit_pierce"}
## Dano mágico no alvo pelo tema (FxManager.theme_of da skill/básico de quem bateu); tema fora da lista = arcano.
const IMPACT_SOUND := {"fire": "impact_fire", "ice": "impact_ice", "lightning": "impact_lightning", "holy": "impact_holy",
	"lunar": "impact_holy", "shadow": "impact_shadow", "bone": "impact_shadow", "blood": "impact_shadow", "nature": "impact_nature",
	"poison": "impact_nature", "earth": "impact_nature", "wind": "impact_nature"}
## Voz de monstro pelo id (ou prefixo dele): [ao entrar em luta, ao lançar skill, ao morrer]; "" = nada.
## Ginete = lobo + goblin: uiva ao ver você, rosna no bote e o goblin guincha ao cair.
const MOB_VOICE := {
	"boss_tide_mother": ["tide", "naga", "tide"], "boss_agitator_lord": ["war_drum", "goblin", "goblin_shriek"],
	"goblin_": ["goblin", "goblin", "goblin_shriek"], "wolf_": ["wolf_howl", "wolf_snarl", "goblin_shriek"],
	"orc_": ["orc", "orc", ""], "naga_": ["naga", "naga", ""],
	"troll": ["troll_growl", "troll_grunt", "troll_die"], "boss_troll_king": ["troll_growl", "troll_grunt", "troll_die"],
	"boss_crossbow_master": ["orc", "orc", ""], "boss_ghar": ["orc", "orc", ""],
	# Monte Kharzun (40-45): goblin_/orc_/troll cobrem os da Horda pelo prefixo; nativos com voz própria
	"dire_wolf_rider": ["dire_howl", "wolf_snarl", "goblin_shriek"], "dire_": ["dire_howl", "wolf_snarl", ""],
	"lava_salamander": ["salamander_hiss", "salamander_hiss", "salamander_die"], "basalt_golem": ["golem_rumble", "golem_rumble", "golem_crumble"],
	"clan_guard": ["orc", "orc", ""],
	# Chefes de Kharzun (WP7): vozes de lobo atroz do WP11 onde há; o resto reaproveita as da Horda
	"boss_dire_mother": ["dire_howl", "wolf_snarl", "dire_howl"],
	"boss_shazka": ["goblin", "goblin", "goblin_shriek"], "shadow_apprentice": ["goblin", "goblin", "goblin_shriek"], "shazka_decoy": ["goblin", "goblin", "smoke_vanish"],
	"boss_ulgra": ["dire_howl", "orc", ""], "ulgra_rider": ["dire_howl", "wolf_snarl", "goblin_shriek"],
	"boss_gorbash": ["troll_growl", "troll_grunt", "troll_die"], "stone_shaman": ["troll_growl", "troll_grunt", "troll_die"],
	"boss_kragmar": ["orc", "orc", ""], "forge_golemling": ["orc", "", ""], "boss_durgash": ["orc", "orc", ""], "throne_guard": ["orc", "orc", ""],
	"banner_": ["", "", ""],
	# Mata dos Zumbidos (4-8): "wasp_" pega a vespa-soldado; hive_wasp = vespa da colmeia
	"wasp": ["wasp_buzz", "wasp_buzz", "wasp_die"], "wasp_": ["wasp_buzz", "wasp_buzz", "wasp_die"], "hive_wasp": ["", "wasp_buzz", "wasp_die"],
"shaman_shifter": ["nature", "summon", ""], "shaman_bear": ["bear_growl", "bear_roar", ""], "shaman_wolf": ["wolf_snarl", "wolf_snarl", ""],
	"shaman_hawk": ["wind", "wind", ""], "shaman_caller": ["drum_beat", "summon", ""], "grove_wolf": ["wolf_howl", "wolf_snarl", ""], "grove_bear": ["bear_growl", "bear_growl", ""],
	"grove_boar": ["earth", "", ""], "grove_rabbit": ["nature", "", ""], "grove_deer": ["nature", "", ""], "boss_archdruid": ["nature", "summon", "die_boss"],
	"archdruid_wolf": ["wolf_howl", "wolf_snarl", ""], "archdruid_bear": ["bear_growl", "bear_roar", ""], "archdruid_treant": ["golem_rumble", "earth", ""],
		"bear_cub": ["bear_growl", "bear_growl", ""], "bear_cub_den": ["", "bear_growl", ""], "bear": ["bear_growl", "bear_growl", ""],
	"bear_mother": ["bear_roar", "bear_growl", "bear_roar"], "hive": ["wasp_buzz", "", "hive_crack"],
	# Ato III (WP12): guizos dos Galgos de Seda (e do Galgo do Convertido), Reflexo que racha ao cair, Incensário que chia
	"silk_hound": ["hound_bells", "hound_bells", "die_monster"], "parade_alpha": ["hound_bells", "dire_howl", "die_monster"],
	"convert_hound": ["hound_bells", "hound_bells", "die_monster"], "vain_reflection": ["mirror_hum", "", "mirror_crack"],
	"living_censer": ["smoke_hiss", "", "golem_crumble"], "chorister": ["", "", "die_monster"],
	# Veladas (Ato III §3.1): sem banco próprio ainda; reaproveitam lua/sombra/fumaça (a Matriarca suspira)
	"seductress": ["lunar", "smoke_vanish", "die_monster"], "flayer": ["shadow", "swing", "die_monster"], "veil_singer": ["lunar", "lunar", "die_monster"], "thirst_matriarch": ["thirst_sigh", "smoke_vanish", "die_boss"],
	# Ato III, chefes (WP12): a prensa range na Vindima, a ária na Prima-Donna, o gole no Varo, o vidro na Condessa
	"boss_vindima": ["press_creak", "nature", "golem_crumble"], "boss_prima_donna": ["aria", "shrill_note", "die_boss"],
	"boss_varo": ["gulp", "", "die_boss"], "boss_countess": ["mirror_hum", "", "mirror_crack"], "boss_ressoa": ["canon", "", "die_boss"],
	# Chefes de Mundo (momentos-do-mundo §10): bancos que já existem (javali/alce sem voz própria ainda)
	"ancestral_boar": ["bear_growl", "earth", "die_boss"], "ancient_elk": ["nature", "nature", "golem_crumble"],
	"ruins_basilisk": ["salamander_hiss", "salamander_hiss", "golem_crumble"], "war_rhino": ["war_drum", "troll_grunt", "troll_die"],
	"iron_wolf_king": ["dire_howl", "wolf_snarl", "dire_howl"], "porcelain_stag": ["bells", "bells", "mirror_crack"],
	"wb_iron_wolf": ["dire_howl", "wolf_snarl", ""], "wb_platform_warrior": ["orc", "orc", ""], "wb_ruin_statue": ["golem_rumble", "", "golem_crumble"],
}
## Skill com som próprio na fase ativa (no lugar do vento da arma) e no impacto (no lugar do som do tema).
const CAST_SOUND := {"mob_drum_beat": "war_drum", "mob_war_drum": "war_drum", "mob_net_throw": "net",
	# Kharzun: a fumaça avisa o Assassino/Matador antes do bote (aviso curto do plano, §7)
	"mob_shadow_step": "smoke_vanish", "mob_slayer_vanish": "smoke_vanish", "mob_slayer_execute": "smoke_vanish",
	# Estandartes de Clã (Pedra e Forja): o pé do mastro batendo na pedra ao pulsar
	"mob_stone_mend": "banner_plant", "mob_forge_embers": "banner_plant",
	# Mata dos Zumbidos: o rugido da Ursa-Mãe e a colmeia soltando o enxame
	"mob_bear_roar": "bear_roar", "mob_hive_swarm": "wasp_buzz", "mob_entangle": "nature", "mob_call_pack": "wolf_howl", "mob_call_boar": "drum_beat", "mob_call_rabbits": "drum_beat", "mob_call_deer": "drum_beat",
	# Ato III (WP12): o leque-lâmina abre no salto; o Incensário sopra o Fumo Doce
	"mob_fan_leap": "fan_open", "mob_first_fan_leap": "fan_open", "mob_sweet_smoke": "smoke_hiss",
	"mob_wb_rhino_drum": "war_drum"}
const EFFECT_SOUND := {"mob_tide_pull": "tide", "mob_tide_wave": "tide", "mob_tide_geysers": "tide",
	"mob_troll_slam": "troll_slam", "mob_rock_quake": "troll_slam",
	"mob_boulder_toss": "boulder", "mob_basalt_stomp": "troll_slam", "mob_brute_quake": "troll_slam",
	# Ato III (WP12): a nota aguda do Coro estoura no chão; a taça do Folião/Varo quebra no alvo
	"mob_shrill_note": "shrill_note", "mob_goblet_throw": "goblet_break", "mob_varo_goblet": "goblet_break"}
## Aura de monstro (MonsterDef.aura) que soa em laço enquanto o dono vive: o tambor do Agitador.
## Assinaturas dos chefes (design/gdd/act2-boss-signatures.md): aviso quando o desenho aparece no chão.
## skill -> [fase do skill_cast em que o desenho aparece, sons...]. Toca cheio: o aviso é para o grupo todo.
## Três Botes avisa só no 1º bote (os outros já têm o rosnado da voz).
const SIG_WARN := {
	"mob_tide_flood": ["active", "sig_warn", "tide"],              # ilhas aparecem
	"mob_drum_frenzy": ["active", "sig_warn", "war_drum"],         # o canal começa
	"mob_troll_avalanche": ["startup", "sig_warn", "golem_rumble"],   # 2,5 s de preparo: a montanha ronca
	"mob_marksman_brand": ["active", "sig_warn"],                  # marcas nas vítimas
	"mob_ghar_wall": ["active", "sig_warn", "block"],              # os escudos travam
	"mob_dire_pounce": ["startup", "sig_warn"],                    # faixa do 1º bote
	"mob_shazka_twins": ["active", "sig_warn", "smoke_vanish"],    # some na fumaça (as cópias saem dela)
	"mob_ulgra_stampede": ["active", "sig_warn", "wolf_howl"],     # faixas do estouro no chão
	"mob_gorbash_waves": ["active", "sig_warn", "golem_rumble"],   # anéis das pisadas no chão
	"mob_kragmar_temper": ["active", "sig_warn", "forge_hammer"],  # círculos das poças no chão (o martelo bate na lava)
	"mob_durgash_throneaxe": ["active", "sig_warn", "war_drum"],   # círculo dourado na vítima (o trono chama o machado)
	"mob_vindima_press": ["active", "sig_warn", "press_creak"],     # o puxão das vinhas e o círculo da prensa: o fuso range
	"mob_prima_aria": ["active", "sig_warn", "aria"],              # os três anéis da ária no chão: três notas que sobem
	"mob_vess_cortege": ["active", "sig_warn", "cortege_horn"],    # as 4 faixas do cortejo: a fanfarra desafinada
	"mob_echo_thirst": ["active", "sig_warn", "thirst_sigh"],      # marca dourada (dividir) ou roxa (espalhar): o suspiro da Velada
	"mob_varo_banquet": ["active", "sig_warn", "gulp"],            # o canal do Banquete começa (ele bebe do barril)
	"mob_countess_gaze": ["startup", "sig_warn", "mirror_hum"],    # 3 s de preparo: os Espelhos de Pé sobem (vidro cantando)
	"mob_ressoa_canon": ["active", "sig_warn", "canon"],           # as marcas do Cânone nas vítimas: a frase em três vozes
	"mob_read_name": ["active", "sig_warn", "smoke_vanish"],       # Escrivão de Azhar: a leitura começa (interrompa!)
	"mob_roll_call": ["startup", "sig_warn", "mirror_hum"],        # 3 s de preparo da Chamada: as estantes se erguem
	# Chefes de Mundo: o desenho aparece no chão (faixas, anéis, marcas, ilhas)
	"mob_wb_boar_trail": ["active", "sig_warn", "earth"], "mob_wb_elk_eruption": ["active", "sig_warn", "golem_rumble"],
	"mob_wb_bas_gaze": ["active", "sig_warn", "salamander_hiss"], "mob_wb_rhino_trample": ["active", "sig_warn", "war_drum"],
	"mob_wb_wolf_hunt": ["active", "sig_warn", "dire_howl"], "mob_wb_stag_flare": ["active", "sig_warn", "bells"],
}
## Impacto/quebra das assinaturas (id do skill_effect, inclusive os que não são skill: BossSignatures.*_FX).
const SIG_EFFECT := {
	"mob_tide_flood": "tide", "mob_troll_avalanche": "troll_slam",
	BossSignatures.COVER_BREAK_FX: "golem_crumble", BossSignatures.CHANNEL_BREAK_FX: "drum_tear",
	BossSignatures.COUNTER_FX: "troll_slam",
	"mob_ulgra_stampede": "earth", "mob_gorbash_waves": "troll_slam", BossSignatures.DECOY_FX: "smoke_vanish",
	"mob_kragmar_temper": "lava_bubble",
	"mob_durgash_throneaxe": "troll_slam",
	"mob_vindima_press": "press_slam", "mob_prima_aria": "shrill_note",
	"mob_vess_cortege": "cortege_march", "mob_echo_thirst": "thirst_drain",
	"mob_varo_banquet": "toast_clink", "mob_countess_gaze": "mirror_flash", "mob_ressoa_canon": "shrill_note",
	"mob_read_name": "smoke_vanish", "mob_roll_call": "mirror_flash",
	"mob_wb_boar_trail": "earth", "mob_wb_elk_eruption": "golem_crumble", "mob_wb_bas_gaze": "golem_crumble",
	"mob_wb_rhino_trample": "troll_slam", "mob_wb_wolf_hunt": "troll_slam", "mob_wb_stag_flare": "mirror_flash",
	BossSignatures.MIRROR_RISE_FX: "mirror_hum", BossSignatures.MIRROR_CRACK_FX: "mirror_crack",
}
const AURA_SOUND := {"agitator": "drum_beat", "agitator_boss": "drum_beat", "clan_wolf": "drum_beat", "festim": "festim_bell", "sede": "thirst_sigh", "sense_sight": "drum_beat"}
const AURA_BEAT := 0.6           # s entre batidas do laço da aura
## Monstro sem aura que soa em laço enquanto vive (id -> som): o Incensário chiando o Fumo Doce.
const MOB_LOOP := {"living_censer": "smoke_hiss"}
## Som de laço mais longo que a batida do tambor: s entre dois toques do MESMO monstro (o resto segue AURA_BEAT).
const LOOP_EVERY := {"festim_bell": 1.8, "thirst_sigh": 2.6, "smoke_hiss": 2.2}
## Sinos do lugar (mapa -> ponto do campanário, missão que os cala, s entre peais, m até onde o som "chega perto"):
## Lumeria toca até os Sinos Mudos (L1, hx3_bells); longe do campanário o peal soa do ponto a `near` m (fraco, mas sempre).
const PLACE_BELLS := {"city_lumeria": {"pos": Vector2(0.0, -6.0), "until": "hx3_bells", "every": 6.0, "near": 32.0},
	"elf_city": {"pos": Vector2(0.0, -10.0), "since": "el6_king", "every": 14.0, "near": 30.0}}     # faixa élfica viva: sino de luto pelo Rei
## Buff de monstro que pulsa enquanto dura: a carne do troll se fechando (MobSystem.update_regen). Um pulso por
## vez no mapa (o mais perto), a cada BUFF_BEAT s.
const BUFF_SOUND := {"troll_regen": "troll_regen"}
const BUFF_BEAT := 1.6
## Laços do lugar (Kharzun): lava borbulhando no ponto de lava mais perto e martelo na bigorna dos ferreiros/fundidores.
const LAVA_RANGE := 16.0         # m da borda da lava ao jogador
const LAVA_BEAT := 1.7
const HAMMER_NPCS := {"dwarf_smith": true, "kharzun_smith": true, "forge_dwarf_a": true, "forge_dwarf_b": true,
	"elf_smith": true}      # faixa élfica viva: forja da Thalindra
const HAMMER_RANGE := 18.0
const HAMMER_BEAT := 2.6
## Missão concluída que soa no mundo (a corrente das Minas parte quando os escravos são soltos).
const QUEST_SOUND := {"hx_mines": "chain_break"}
const SCAN_EVERY := 0.2          # s entre varreduras dos monstros do mapa (quem entrou em luta, auras)
const VOICE_GAP := 0.5           # s entre duas vozes iguais (bando que acorda junto não vira coro)

static var _inst: Sfx = null

var main                                   # Main (mapa atual)
var bank: Dictionary = {}                  # nome -> Array[AudioStream]
var _players: Array[AudioStreamPlayer3D] = []
var _ui_players: Array[AudioStreamPlayer] = []
var _next := 0
var _ui_next := 0
var _last_at: Dictionary = {}              # nome -> tempo (s) do último toque
var _quiet_until := 0.0                    # equipar/itens do carregamento não soam
var _gold := -1
var played: Dictionary = {}                # nome -> vezes que tocou (o smoke imprime)
var _scan := 0.0
var _beat := 0.0
var _buff_beat := 0.0
var _lava_beat := 0.0
var _hammer_beat := 0.0
var _bell_beat := 0.0
var _loop_at: Dictionary = {}              # id do monstro -> tempo (s) do último toque do laço (LOOP_EVERY)
var _angry: Dictionary = {}                # id do monstro -> true (já em luta na última varredura)
var _voice_at: Dictionary = {}             # voz -> tempo (s) da última

## Toca um som de interface (cliques, janelas). Sem Sfx na árvore (testes, ferramentas), não faz nada.
## Contagem do que tocou nesta partida (smoke/revisão).
static func played_summary() -> String:
	if not is_instance_valid(_inst):
		return "sem Sfx"
	var keys: Array = _inst.played.keys()
	keys.sort()
	return ", ".join(keys.map(func(k): return "%s=%d" % [k, _inst.played[k]]))

static func ui(sound: String) -> void:
	if is_instance_valid(_inst):
		_inst.play_ui(sound)

func _ready() -> void:
	_inst = self
	AudioSettings.load_and_apply()
	_load_bank()
	for i in POOL:
		var p := AudioStreamPlayer3D.new()
		p.bus = &"SFX"
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED     # volume vem da distância ao jogador
		p.panning_strength = 0.6
		add_child(p)
		_players.append(p)
	for i in UI_POOL:
		var u := AudioStreamPlayer.new()
		u.bus = &"UI"
		add_child(u)
		_ui_players.append(u)
	_quiet_until = _now() + 2.0
	get_tree().node_added.connect(_on_node_added)
	Events.skill_cast.connect(_on_skill_cast)
	Events.skill_effect.connect(_on_skill_effect)
	Events.projectile_spawned.connect(_on_projectile)
	Events.damage_dealt.connect(_on_damage)
	Events.blocked_hit.connect(_on_block)
	Events.monster_shift.connect(_on_monster_shift)
	Events.shield_block.connect(_on_shield_block)
	Events.dodged.connect(_on_dodged)
	Events.entity_died.connect(_on_died)
	Events.level_up.connect(_on_level_up)
	Events.ultimate_ready.connect(func(id: int): _player_sound(id, "ult_ready", true))     # Carga Suprema cheia (R)
	Events.item_gained.connect(_on_item_gained)
	Events.card_found.connect(func(_id: int, _c: String): play_ui("gem"); play_ui("coins"))     # Carta de Monstro caiu no seu mapa
	Events.potion_used.connect(func(id: int, _s: int): _player_sound(id, "potion"))
	Events.equipment_changed.connect(_on_equipment_changed)
	Events.quest_accepted.connect(func(id: int, _q: String): _player_sound(id, "quest_accept", true))
	Events.quest_completed.connect(_on_quest_completed)
	Events.crafted.connect(func(id: int, _i: String, _c: int): _player_sound(id, "craft"))
	Events.gathered.connect(func(_m: String, _n: int, id: int): _player_sound(id, "gather"))
	Events.recall_cast.connect(_on_recall)
	Events.entity_changed_map.connect(_on_changed_map)
	Events.monster_emerged.connect(_on_emerged)
	Events.road_event_started.connect(_on_road_event)

func _exit_tree() -> void:
	if _inst == self:
		_inst = null

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## Lê o banco pelo prefixo (funciona no jogo exportado: list_directory vê os recursos importados).
func _load_bank() -> void:
	for f in ResourceLoader.list_directory(DIR):
		var file := String(f)
		if not (file.ends_with(".ogg") or file.ends_with(".wav")):
			continue
		var key := file.get_basename()
		key = key.substr(0, key.rfind("_"))
		var s: AudioStream = load(DIR + file)
		if s:
			if not bank.has(key):
				bank[key] = []
			bank[key].append(s)

# ---------------------------------------------------------------- tocar
## Som no mundo, no ponto `pos`. `mine` = do jogador/grupo (volume cheio; os outros saem mais baixos).
func play_at(sound: String, pos: Vector3, mine: bool = true, extra_db: float = 0.0) -> void:
	if not bank.has(sound) or not _gap_ok(sound):
		return
	var p: SimEntity = Sim.player
	var d := 0.0 if p == null else pos.distance_to(p.position)
	if d >= FAR:
		return
	var g := 1.0 if d <= NEAR else 1.0 - (d - NEAR) / (FAR - NEAR)
	var db: float = float(VOL.get(sound, 0.0)) + linear_to_db(g) + extra_db + (0.0 if mine else OTHERS_DB)
	var pl := _voice(sound)
	if pl == null:
		return
	pl.stream = _pick(sound)
	pl.global_position = pos + Vector3(0, 1.0, 0)
	pl.volume_db = db
	pl.pitch_scale = randf_range(0.93, 1.07)
	pl.set_meta("sound", sound)
	pl.play()
	played[sound] = int(played.get(sound, 0)) + 1

func play_ui(sound: String) -> void:
	if not bank.has(sound) or not _gap_ok(sound):
		return
	var u := _ui_players[_ui_next]
	_ui_next = (_ui_next + 1) % _ui_players.size()
	u.stream = _pick(sound)
	u.volume_db = float(VOL.get(sound, 0.0))
	u.pitch_scale = randf_range(0.97, 1.03)
	u.play()
	played[sound] = int(played.get(sound, 0)) + 1

func _pick(sound: String) -> AudioStream:
	var arr: Array = bank[sound]
	return arr[randi() % arr.size()]

func _gap_ok(sound: String) -> bool:
	var t := _now()
	if t - float(_last_at.get(sound, -1.0)) < MIN_GAP:
		return false
	_last_at[sound] = t
	return true

## Voz livre; se o nome já tem MAX_VOICES tocando, não toca; senão rouba a mais antiga do rodízio.
func _voice(sound: String) -> AudioStreamPlayer3D:
	var same := 0
	for pl in _players:
		if pl.playing and pl.get_meta("sound", "") == sound:
			same += 1
	if same >= MAX_VOICES:
		return null
	for i in _players.size():
		var pl := _players[(_next + i) % _players.size()]
		if not pl.playing:
			_next = (_next + i + 1) % _players.size()
			return pl
	var steal := _players[_next]
	_next = (_next + 1) % _players.size()
	return steal

# ---------------------------------------------------------------- quem
func _here(e: SimEntity) -> bool:
	return e != null and main != null and e.map_id == main.current_map_id

## Do jogador ou do grupo dele (e invocações): o mesmo critério dos números de dano.
func _mine(e: SimEntity) -> bool:
	var p: SimEntity = Sim.player
	if p == null or e == null:
		return false
	if e == p or e.owner_id == p.id:
		return true
	return p.party_id >= 0 and e.party_id == p.party_id

func _player_sound(id: int, sound: String, as_ui: bool = false) -> void:
	var p: SimEntity = Sim.player
	if p == null or id != p.id:
		return
	if as_ui:
		play_ui(sound)
	else:
		play_at(sound, p.position)

# ---------------------------------------------------------------- eventos
## Golpe físico: o vento da arma no começo da fase ativa. Magia demorada: o zumbido da preparação.
func _on_skill_cast(id: int, skill_id: String, phase: String) -> void:
	var e: SimEntity = Sim.get_entity(id)
	if not _here(e) or skill_id == "jump":
		return
	if skill_id == "dash":
		play_at("dodge", e.position, _mine(e), -2.0)
		return
	var s: SkillDef = GameData.skill_or_basic(skill_id)
	if s == null:
		return
	if e.kind == SimEntity.Kind.MONSTER:
		if phase == "startup" and GameData.skills.has(skill_id):      # skill de verdade, não o golpe básico
			_mob_voice(e, 1)
		if SIG_WARN.has(skill_id):
			_sig_warn(e, skill_id, phase)
		if CAST_SOUND.has(skill_id):
			if phase == "active":
				play_at(CAST_SOUND[skill_id], e.position)
			return
	var ranged := e.stats != null and RANGED_SOUND.has(e.stats.weapon_type)
	var whoosh := whoosh_of(e, s, ranged)
	if phase == "startup" and whoosh != "":
		_schedule_whoosh(e, s, whoosh)
	if phase == "startup" and s.kind != SkillDef.Kind.PHYSICAL and s.kind != SkillDef.Kind.HEAL and s.startup >= 0.2:
		play_at("cast", e.position, _mine(e))
	elif phase == "active" and s.kind == SkillDef.Kind.PHYSICAL and not ranged and whoosh == "":
		play_at("swing", e.position, _mine(e), -3.0 if e.kind == SimEntity.Kind.MONSTER else 0.0)

## Vento antes do impacto (pacote V2, 2026-11-23): skill de personagem (não o básico, não monstro) soa WHOOSH_LEAD s
## antes do tick do dano; golpe corpo a corpo = "whoosh" (no lugar do "swing" da fase ativa), magia rápida =
## "whoosh_magic" (a demorada já tem o "cast" da preparação). "" = sem vento.
const WHOOSH_LEAD := 0.08
const WHOOSH_MAGIC_MAX_STARTUP := 0.2
static func whoosh_of(e: SimEntity, s: SkillDef, ranged: bool) -> String:
	if e == null or s == null or e.kind == SimEntity.Kind.MONSTER or s.id.begins_with("basic_"):
		return ""
	if s.kind == SkillDef.Kind.PHYSICAL:
		return "" if ranged else "whoosh"
	if s.kind == SkillDef.Kind.MAGICAL and s.startup < WHOOSH_MAGIC_MAX_STARTUP:
		return "whoosh_magic"
	return ""

## Toca o vento WHOOSH_LEAD s antes do fim do preparo, se a skill ainda estiver no preparo (cancelada = nada).
func _schedule_whoosh(e: SimEntity, s: SkillDef, sound: String) -> void:
	var wait := s.startup - WHOOSH_LEAD
	if wait <= 0.01:
		play_at(sound, e.position, _mine(e))
		return
	var id := e.id
	get_tree().create_timer(wait).timeout.connect(_whoosh_now.bind(id, s, sound))

func _whoosh_now(id: int, s: SkillDef, sound: String) -> void:
	var e: SimEntity = Sim.get_entity(id)
	if _here(e) and e.state == SimEntity.State.CASTING and e.current_skill == s:
		play_at(sound, e.position, _mine(e))

## Impacto de skill (não do básico, que soa no golpe): som do tema no ponto mirado.
func _on_skill_effect(skill_id: String, origin: Vector3, aim: Vector3, _radius: float) -> void:
	if SIG_EFFECT.has(skill_id):
		if main != null and (Sim.ticking_map == "" or Sim.ticking_map == main.current_map_id):
			play_at(SIG_EFFECT[skill_id], origin)
		return
	if not GameData.skills.has(skill_id):
		return
	var s: SkillDef = GameData.skills[skill_id]
	var snd: String = EFFECT_SOUND.get(skill_id, THEME_SOUND.get(FxManager.theme_of(s), ""))
	if snd == "" and s.kind == SkillDef.Kind.MAGICAL:
		snd = "arcane"
	if snd == "":
		return
	var p: SimEntity = Sim.player
	var at := aim if s.target in [SkillDef.Target.GROUND, SkillDef.Target.TARGET] else origin
	var mine := p != null and origin.distance_to(p.position) < 1.5
	play_at(snd, at, mine or p == null)

## Aviso de assinatura de chefe (SIG_WARN) na fase em que o desenho aparece.
func _sig_warn(e: SimEntity, skill_id: String, phase: String) -> void:
	var row: Array = SIG_WARN[skill_id]
	if phase != str(row[0]):
		return
	if e.sig.has("seq") and str(e.sig["seq"].get("skill", "")) == skill_id:
		return                         # bote seguinte da sequência: só o 1º avisa
	for i in range(1, row.size()):
		play_at(str(row[i]), e.position)

func _on_projectile(pr: SimProjectile) -> void:
	var e: SimEntity = Sim.get_entity(pr.owner_id)
	if not _here(e) or e.stats == null:
		return
	var snd: String = RANGED_SOUND.get(e.stats.weapon_type, "")
	if snd != "" and (pr.skill == null or pr.skill.kind == SkillDef.Kind.PHYSICAL):
		play_at(snd, e.position, _mine(e))

func _on_damage(attacker_id: int, target_id: int, amount: int, crit: bool, blocked: bool, kind: String) -> void:
	if blocked or amount <= 0 or kind in ["dot", "dot_fire", "aura", "interrupt"]:
		return
	var t: SimEntity = Sim.get_entity(target_id)
	if not _here(t):
		return
	var a: SimEntity = Sim.get_entity(attacker_id)
	if t == Sim.player:
		play_at("hurt", t.position)
		return
	var mine := _mine(a) or _mine(t)
	if kind == "magical":
		play_at(impact_sound(a), t.position, mine)
	else:
		play_at(hit_sound(a), t.position, mine)
	if crit and mine:
		play_at("crit", t.position, true)

## Som do golpe físico no alvo pela arma de quem bateu (HIT_SOUND).
static func hit_sound(a: SimEntity) -> String:
	if a == null or a.stats == null:
		return "hit"
	return str(HIT_SOUND.get(a.stats.weapon_type, "hit"))

## Som do impacto mágico no alvo pelo tema da skill em curso (ou do básico) de quem bateu (IMPACT_SOUND).
static func impact_sound(a: SimEntity) -> String:
	if a == null:
		return "impact_arcane"
	var s: SkillDef = a.current_skill if a.current_skill != null else a.basic_skill
	return str(IMPACT_SOUND.get(FxManager.theme_of(s), "impact_arcane"))

## Metamorfose de monstro (ShiftSystem): giro de folhas na conjuração, voz do bicho ao virar.
const SHIFT_SOUND := {"cast": "summon", "shaman_bear": "bear_roar", "shaman_wolf": "wolf_howl", "shaman_hawk": "wind", "revert": "nature"}

func _on_monster_shift(id: int, form_id: String, phase: String) -> void:
	var e: SimEntity = Sim.get_entity(id)
	if not _here(e):
		return
	var snd := ""
	match phase:
		"cast": snd = SHIFT_SOUND["cast"]
		"done": snd = str(SHIFT_SOUND.get(form_id, "nature"))
		"revert": snd = SHIFT_SOUND["revert"]
	if snd != "":
		play_at(snd, e.position, false)

func _on_block(id: int) -> void:
	var t: SimEntity = Sim.get_entity(id)
	if _here(t):
		play_at("block", t.position, _mine(t))

func _on_shield_block(id: int, _attacker: int, _theme: String, parried: bool, _from: Vector3) -> void:
	var t: SimEntity = Sim.get_entity(id)
	if _here(t):
		play_at("parry" if parried else "block", t.position, _mine(t))

func _on_dodged(id: int) -> void:
	var t: SimEntity = Sim.get_entity(id)
	if _here(t):
		play_at("dodge", t.position, _mine(t))

func _on_died(id: int, _killer: int) -> void:
	var e: SimEntity = Sim.get_entity(id)
	if not _here(e):
		return
	if e == Sim.player:
		play_ui("death")
	elif e.kind == SimEntity.Kind.MONSTER:
		var boss := e.monster_def != null and e.monster_def.is_boss
		play_at("die_boss" if boss else "die_monster", e.position, true)
		_mob_voice(e, 2)

## Evento de estrada no mapa do jogador (grito de socorro): toque curto de aviso.
func _on_road_event(map_id: String, _kind: String, _pos: Vector3) -> void:
	if Sim.player != null and Sim.player.map_id == map_id:
		_player_sound(Sim.player.id, "quest_accept", true)

func _on_level_up(id: int, _lv: int) -> void:
	_player_sound(id, "level_up", true)

func _on_item_gained(id: int, item_id: String, _count: int) -> void:
	if Sim.player == null or id != Sim.player.id or _now() < _quiet_until:
		return
	var it: ItemDef = GameData.items.get(item_id)
	play_ui("gem" if it != null and it.rarity >= 3 else "pickup")

func _on_equipment_changed(id: int) -> void:
	if _now() >= _quiet_until:
		_player_sound(id, "equip", true)

func _on_recall(id: int, phase: String) -> void:
	if phase == "start":
		_player_sound(id, "recall")
	elif phase == "done":
		_player_sound(id, "recall_done", true)

## Entrar/sair de casa: porta.
func _on_changed_map(id: int, map_id: String) -> void:
	var p: SimEntity = Sim.player
	if p == null or id != p.id:
		return
	var m: MapDef = GameData.maps.get(map_id)
	var prev: MapDef = GameData.maps.get(main.current_map_id) if main else null
	if (m and m.interior) or (prev and prev.interior):
		play_ui("door")

## Chefe que sai da água (MobSystem): respingo no lugar.
func _on_emerged(map_id: String, pos: Vector3) -> void:
	if main != null and map_id == main.current_map_id:
		play_at("tide", pos)

# ---------------------------------------------------------------- vozes de monstro
## Linha de MOB_VOICE do monstro: id exato, depois prefixo (a elite fala como o monstro de origem).
static func voice_of(def: MonsterDef) -> Array:
	if def == null:
		return []
	var id: String = def.elite_of if def.elite_of != "" else def.id
	if MOB_VOICE.has(id):
		return MOB_VOICE[id]
	for k in MOB_VOICE:
		if id.begins_with(k):
			return MOB_VOICE[k]
	return []

## `slot`: 0 = entrou em luta, 1 = lança skill, 2 = morreu.
func _mob_voice(e: SimEntity, slot: int) -> void:
	var v := voice_of(e.monster_def)
	if v.is_empty() or str(v[slot]) == "":
		return
	var snd := str(v[slot])
	var t := _now()
	if t - float(_voice_at.get(snd, -10.0)) < VOICE_GAP:
		return
	_voice_at[snd] = t
	play_at(snd, e.position)

## Varre os monstros do mapa: quem acabou de ganhar alvo solta a voz; aura viva bate o tambor no ritmo.
func _scan_mobs(delta: float) -> void:
	_scan -= delta
	_beat -= delta
	_buff_beat -= delta
	if _scan > 0.0 or main == null:
		return
	_scan = SCAN_EVERY
	var p: SimEntity = Sim.player
	var beat := _beat <= 0.0
	if beat:
		_beat = AURA_BEAT
	var pulse := _buff_beat <= 0.0
	var pulse_at: SimEntity = null
	var pulse_d := FAR
	var pulse_snd := ""
	var angry := {}
	for e: SimEntity in Sim.map_entities(main.current_map_id):
		if e.kind != SimEntity.Kind.MONSTER or e.monster_def == null or e.dormant or not e.is_alive():
			continue
		if e.position.distance_to(p.position) >= FAR:
			continue
		var loop_snd := loop_sound(e.monster_def)
		if loop_snd != "":
			if LOOP_EVERY.has(loop_snd):
				var tn := _now()
				if tn - float(_loop_at.get(e.id, -100.0)) >= float(LOOP_EVERY[loop_snd]):
					_loop_at[e.id] = tn
					play_at(loop_snd, e.position)
			elif beat:
				play_at(loop_snd, e.position)
		if pulse and not e.buffs.is_empty():
			var d: float = e.position.distance_to(p.position)
			if d < pulse_d:
				for b in BUFF_SOUND:
					if e.buff_stacks(b) > 0:
						pulse_at = e
						pulse_d = d
						pulse_snd = BUFF_SOUND[b]
		if e.aggro_target >= 0:
			angry[e.id] = true
			if not _angry.has(e.id):
				_mob_voice(e, 0)
	_angry = angry
	if pulse_at != null:
		_buff_beat = BUFF_BEAT
		play_at(pulse_snd, pulse_at.position)

func _on_quest_completed(id: int, quest_id: String) -> void:
	_player_sound(id, "quest_done", true)
	var p: SimEntity = Sim.player
	if QUEST_SOUND.has(quest_id) and p != null and p.id == id:
		play_at(QUEST_SOUND[quest_id], p.position)

## Ponto de lava mais perto de `pos` no mapa (borda do rio/lago); Vector3.INF se não houver lava.
static func nearest_lava(def: MapDef, pos: Vector3) -> Vector3:
	var best := Vector3.INF
	var bd := INF
	var p2 := Vector2(pos.x, pos.z)
	for w in def.water:
		if not (bool(w.get("lava", false)) or str(w.get("material", "")) == "glow_lava"):
			continue
		var q := Vector2.INF
		var d := INF
		if w["kind"] == "lake":
			var c: Vector2 = w["pos"]
			var r := float(w["r"])
			q = c + (p2 - c).limit_length(r)
			d = maxf(0.0, p2.distance_to(c) - r)
		else:
			var pts: PackedVector2Array = w["pts"]
			for i in range(pts.size() - 1):
				var s := Geometry2D.get_closest_point_to_segment(p2, pts[i], pts[i + 1])
				var sd := maxf(0.0, s.distance_to(p2) - float(w["w"]) * 0.5)
				if sd < d:
					d = sd
					q = s
		if d < bd:
			bd = d
			best = Vector3(q.x, 0.0, q.y)
	return best

## Som em laço do monstro: a aura dele (AURA_SOUND) ou o laço próprio pelo id (MOB_LOOP); "" = nenhum.
static func loop_sound(def: MonsterDef) -> String:
	if def == null:
		return ""
	if AURA_SOUND.has(def.aura):
		return AURA_SOUND[def.aura]
	return str(MOB_LOOP.get(def.id, ""))

## Sinos do lugar ainda tocam? (só lê `done` = quests_completed do jogador). Ponto do campanário ou Vector3.INF.
static func place_bells_at(map_id: String, done: Array) -> Vector3:
	if not PLACE_BELLS.has(map_id):
		return Vector3.INF
	var b: Dictionary = PLACE_BELLS[map_id]
	if (b.has("until") and str(b["until"]) in done) or (b.has("since") and not str(b["since"]) in done):
		return Vector3.INF
	var v: Vector2 = b["pos"]
	return Vector3(v.x, 0.0, v.y)

## Laços do lugar: lava perto e martelo da forja (um de cada por vez, no mais perto) e os sinos da cidade.
func _place_loops(delta: float) -> void:
	_lava_beat -= delta
	_hammer_beat -= delta
	_bell_beat -= delta
	if main == null or not Sim.maps.has(main.current_map_id):
		return
	var p: SimEntity = Sim.player
	var m: Dictionary = Sim.maps[main.current_map_id]
	if _bell_beat <= 0.0:
		var bell := place_bells_at(main.current_map_id, p.quests_completed)
		if bell != Vector3.INF:
			var b: Dictionary = PLACE_BELLS[main.current_map_id]
			_bell_beat = float(b["every"])
			play_at("bells", p.position + (bell - p.position).limit_length(float(b["near"])))
		else:
			_bell_beat = 1.0
	if _lava_beat <= 0.0:
		_lava_beat = LAVA_BEAT
		var q := nearest_lava(m["def"], p.position)
		if q != Vector3.INF and q.distance_to(p.position) < LAVA_RANGE:
			play_at("lava_bubble", q)
	if _hammer_beat <= 0.0:
		_hammer_beat = HAMMER_BEAT
		var best: SimEntity = null
		var bd := HAMMER_RANGE
		for e: SimEntity in m["entities"]:
			if e.kind != SimEntity.Kind.NPC or not HAMMER_NPCS.has(str(e.npc_data.get("id", ""))):
				continue
			var d := e.position.distance_to(p.position)
			if d < bd:
				bd = d
				best = e
		if best != null:
			play_at("forge_hammer", best.position)

## Ouro só sobe por venda, quest ou saque: moedas.
func _process(delta: float) -> void:
	var p: SimEntity = Sim.player
	if p == null:
		return
	_scan_mobs(delta)
	_place_loops(delta)
	if _gold >= 0 and p.gold > _gold and _now() >= _quiet_until:
		play_ui("coins")
	_gold = p.gold

## Todo botão da interface clica (janelas são refeitas em código, então liga na criação).
func _on_node_added(n: Node) -> void:
	if n is BaseButton and not (n as BaseButton).pressed.is_connected(_click):
		(n as BaseButton).pressed.connect(_click)

func _click() -> void:
	play_ui("click")
