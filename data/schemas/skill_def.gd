class_name SkillDef
extends Resource
## Definição de uma skill. Os números por maestria vêm de `mastery` (6 entradas, nível 0..5).

enum Target { SELF, DIRECTION, GROUND, CONE, TARGET }
enum Kind { PHYSICAL, MAGICAL, HEAL, BUFF, SUMMON, MOVEMENT }

## Chaves de `effects` que a sim conhece (WorldSim._apply_effects e sistemas). Fonte única: `SkillsCatalog._s` manda
## estas para `effects` (o resto vira campo da skill) e há check de que toda skill usa só estas.
const EFFECT_KEYS := ["dot", "slow", "stun", "root", "buff", "shield", "dash", "summon", "heal_pct_of_dmg", "taunt",
	"boss_summon", "wither", "form", "stealth", "trap", "pet_command", "pet_buff", "curse", "channel", "mend_pct_of_dmg",
	"combust", "bounce", "aura", "barrage", "pull", "combo_gain", "combo_spend", "dice", "dash_to_aim", "shot", "fury_gain",
	"fury_spend", "heal_pct", "mana_pct", "arcane", "glory_gain", "glory_spend", "glory_scale", "titan_hit", "chain",
	"elem_command", "elem_fusion", "cocoon",
	"turret", "dragon_jump", "shout",
	"summon_pact", "miasma", "grave_mark", "shadow_clone", "execute", "knockback",
	"choir_angel", "choir_barrier", "choir_return",
	"provoke", "area_heal", "pack",
	"falcon_call", "falcon_dive", "falcon_eyes", "rally",
	"islands", "mark", "boss_channel", "repeat", "avalanche", "wall", "decoys",
	"explode", "fire_wall", "strikes", "orbit",
	"zone", "sunder", "sunder_consume", "seed", "sacrifice",
	"wound_heal", "wound_extend", "riposte", "momentum_spend"]

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var class_id: String = ""
@export var unlock_level: int = 1      ## nível mínimo para aprender
@export var build: String = ""          ## id da build (ClassDef.builds) ou "" = geral da classe
## arma exigida (alternativas; vazio = qualquer). Fichas: tipo da mão principal ("bow", "mace2h"...),
## "shield"/"orb" (mão secundária), "dual" (duas armas de 1 mão), "dual_sword" (duas espadas),
## "two_handed" (qualquer arma de 2 mãos). Ver Stats.meets().
@export var requires: Array[String] = []
@export var target: Target = Target.DIRECTION
@export var kind: Kind = Kind.PHYSICAL
@export var icon_color: Color = Color.WHITE
@export var vfx: String = ""
@export var look: String = ""         ## só aparência (básico da build): o FX usa quando `vfx` é vazio; não muda regra de combate
@export var clip: String = ""         ## clipe próprio do golpe (EntityView._action_clip usa antes das regras por palavra/forma/arma)
## elementos da skill (Elementalista): "fire" | "frost" | "storm"; combinações têm dois ou três. Dano × média dos bônus.
@export var elements: Array[String] = []             ## tema do efeito visual (SkillsCatalog.VFX_RULES): fire, ice, holy, shadow...

## multiplicador do ATK/MATK (1.0 = 100%)
@export var power: float = 1.0
@export var mp_cost: float = 10.0
@export var cooldown: float = 4.0
@export var range: float = 6.0         ## alcance máximo (DIRECTION = comprimento, GROUND = distância máx do retículo)
@export var radius: float = 1.5        ## GROUND/TARGET: raio do AoE. DIRECTION: meia-largura. CONE: raio
@export var cone_angle_deg: float = 90.0
## CONE com line_width > 0: a área vira uma faixa reta à frente (`radius` de comprimento, esta largura em m),
## que atravessa a fila do mais perto ao mais longe até `max_targets` (estocada de lança; Combat.select_targets).
@export var line_width: float = 0.0
@export var max_targets: int = 99

## timing em segundos (movimento por código, não root motion)
@export var startup: float = 0.15
@export var active: float = 0.05
@export var recovery: float = 0.35
@export var cancel_after: float = 0.2   ## a partir de quando (dentro da recovery) pode cancelar com movimento/dash
@export var lock_facing: bool = true    ## trava a direção durante a skill
@export var hit_stop_frames: int = 3

## projétil: 0 = instantâneo (hitscan). >0 = velocidade m/s (DIRECTION)
@export var projectile_speed: float = 0.0
@export var projectile_pierce: bool = false
## monstro CHEFE: em quem mira esta skill (o aggro continua no tanque). "" = alvo atual; "far" = o mais longe;
## "random" = qualquer um por perto; "soft" = curandeiro/conjurador/atirador (senão o mais longe). MobSystem.pick_victim.
@export var mob_pick: String = ""
## assinatura de chefe (GDD act2-boss-signatures): a mecânica própria dele; 1 por chefe (check _check_boss_signatures).
## Recarga inicial ao entrar na luta/fase: Balance.BOSS_SIG_OPEN_DELAY / BOSS_SIG_PHASE_DELAY (BossSignatures.arm).
@export var boss_signature: bool = false
## só lança nesta forma ("wolf", "bear"...; "" = qualquer). Ex.: Espreitar do Druida só como lobo.
@export var requires_form: String = ""
## Combate Montado (ascensão do Paladino): `mountable` = sai montado (as outras ficam apagadas na barra a cavalo);
## `mount_only` = só montado (Carga Montada, Pisotear).
@export var mountable: bool = false
@export var mount_only: bool = false
## skill de ascensão (Ato II, 35+): fica fora da teia normal (vai para a teia de ascensão da classe, barra 7-0) e só sai
## com a ascensão (ProgressionSystem.has_ascension).
@export var ascension: bool = false
## nome da forma nos avisos ("só na forma de lobo")
const FORM_LABELS := {"wolf": "lobo", "bear": "urso", "phantom": "fantasma", "demon": "demônio", "lich": "lich",
	"ent": "Ent", "alpha": "Lobo Alfa", "bird": "Pássaro Arcano"}

## efeitos extra: {"dot": {"dps": 5, "duration": 4}, "slow": {"pct": 40, "duration": 2},
## "dot": {"atk_pct": 12, "duration": 4} → sangramento: % do ATK físico por segundo (o `dps` comum escala com o MATK);
##     o mesmo atacante renova, não acumula (Lanceiro),
## "stun": {"duration": 1}, "root": {"duration": 2}, "buff": {"id":"fury","duration":8,"atk_pct":30},
## "heal_pct_of_dmg": 0.3 (cura quem lança), "mend_pct_of_dmg": 0.3 (cura o aliado mais ferido a Balance.RADIANCE_RANGE), "dash": 4.0, "summon": {"monster_id":"skeleton","count":2,"duration":20},
## "shield": {"amount_pct_hp": 20, "duration": 5}}
## "combust": {"detonate": 1.25}  → antes do golpe, as queimaduras SUAS em cada atingido explodem na hora
##     (dano restante × detonate, número "detonate") e somem; o `dot` da skill reacende em todos (espalha).
## "bounce": {"count": 3, "radius": 6, "falloff": 0.85, "taunt": 3, "interrupt": 0.5}  → TARGET arremessado
##     (velocidade = projectile_speed): voa até o alvo, salta para o inimigo mais perto ainda não atingido (count
##     alvos no total, power × falloff a cada salto), provoca cada um (MobSystem.taunt) e atordoa `interrupt` s
##     quem estava preparando um golpe; depois volta para a mão de quem lançou. `stun` (s, opcional) atordoa cada
##     atingido (Martelo da Justiça: count 1, taunt 0 = martelo que vai e volta).
## "orbit": {"id": "blessed_hammers", "duration": 6, "every": 0.5, "count": 3}  → (SELF com raio) o golpe de lançar bate
##     em volta e põe o buff `id` em quem lançou; enquanto durar, a cada `every` s (relógio de AuraSystem.tick) bate de novo
##     em quem está a `radius` m com o MESMO power do lançamento (maestria, Juramento etc. já contados). `count` = quantos
##     martelos a apresentação desenha girando (Martelos Abençoados).
## "aura": {"radius": 12, "ally": {"dr_pct": 8, "def_pct": 10}}  → liga/desliga: lançar põe o `buff` (sem fim)
##     em você; enquanto ele durar, o grupo a `radius` m recebe `ally` com o mesmo id (AuraSystem). Lançar de novo desliga.
## "barrage": {"count": 4, "radius": 2.2, "delay": 1.3, "spread": 8}  → (chefe, GROUND) N círculos avisados no chão:
##     um em cada inimigo por perto, o resto em volta do chefe; caem depois de `delay` s (MobSystem.place_barrage).
## Assinaturas de chefe (BossSignatures; números globais em Balance.BOSS_SIG_*):
## "barrage" ganha formas e chão vivo (R-A): {"shape": "circle|line|ring", "width", "inner", "length", "linger": s,
##     "tick_power", "empower": {"id", "step", "max", "every"}} (line: do chefe até o ponto, `width` de largura; ring: entre
##     `inner` e `radius` em volta do chefe; linger: fica no chão depois de cair e bate tick_power a cada BOSS_LINGER_TICK s).
## "islands": {"count_min", "radius", "delay", "near_min", "near_max", "slow": {...}} → Maré Cheia (R-A invertido): N ilhas;
##     quem estiver a BOSS_INVERT_RANGE m do chefe e FORA de todas leva o golpe (power da skill).
## "mark": {"mode": "spread|soak", "count", "solo_count", "radius", "time", "linger", "tick_power", "no_tank"} → (R-B) mira que
##     segue a vítima e cai depois de `time` s; spread = power em cada um dentro; soak = power dividido por quantos dentro.
## "boss_channel": {"on_done": {"buff": {...}, "radius", "heal_pct", "summon": {...}}} → (R-C) canal interrompível (dura o
##     `active` da skill); quebra com atordoar ou dano ≥ BOSS_CHANNEL_BREAK_PCT × vida.
## "strikes": {"weights": [0.55, 0.55, 0.75], "at": [0.0, 0.28, 0.6], "crit_last": true, "last_stop": 6, "clips": [...]}
##     → sequência de golpes de personagem (Golpe do Cruzado): o golpe i sai em startup + at[i] (at[0] = 0; `active` ≥ o
##     último) com power × weights[i]/soma; `crit_last` = o último é crítico garantido (bloqueio ainda vence), `last_stop`
##     = quadros de parada dele. Encadear outra skill só depois do último (WorldSim._can_chain); dash corta o resto.
##     `clips` = só apresentação: clipe de cada golpe (EntityView toca um por golpe, impacto no tick dele).
## "repeat": {"times": 3, "gap": 0.6} → (R-D) a skill sai `times` vezes seguidas, re-mirando a mesma vítima; root/stun cortam.
## "avalanche": {"radius": 18, "stun": 1.0, "guarantee": 2} → (R-E) onda em volta; quem tem pedregulho (MonsterDef.cover)
##     entre si e o chefe não leva, e a pedra racha. Sem pedra no chão no começo, arremessa `guarantee` antes.
## "wall": {"time": 6, "counter": {"base", "step", "cap", "cone", "range"}} → (R-G) Muralha: golpe da frente perde
##     GHAR_WALL_CUT e soma fúria; no fim, contragolpe em cone com power base + step × fúria (teto cap).
## "rally": {"id": "war_cry", "radius": 9, "duration": 8, "atk_pct": 15, "speed_pct": 10}  → (monstro) grito de guerra: quem
##     lança e os monstros da mesma facção a `radius` m ganham o buff por `duration` s (renova pelo id; MobSystem.rally).
## "arcane": {}  → Modo Arcano (Paladino ascendido): liga/desliga o `buff` (toggle) das asas; ao ligar desmonta e solta a
##     rajada de penas (Balance.ARCANE_BURST); ligado gasta Balance.ARCANE_MP_PER_S e desliga com MP 0 (MountedCombat).
## "turret": {"monster_id": "ranger_turret"}  → (GROUND) põe uma torreta parada no ponto mirado que atira sozinha no
##     inimigo mais perto (RangerAscension.place_turret; números em Balance.TURRET_*; limite TURRET_MAX + stat turret_max).
## Falcoeiro (Caçador ascendido, FalconSystem; números em Balance.FALCON_*):
## "falcon_call": true  → chama o falcão (estado no dono, sem entidade); recusada se ele já está no ar.
## "falcon_dive": true  → depois do golpe no alvo: Presa nele, o falcão passa a segui-lo e os linces saltam nele. Pede o falcão.
## "falcon_eyes": true  → com o portão Revoada, FALCON_FLOCK falcões mergulham em alvos diferentes. Pede o falcão.
## "curse" com id em Balance.MARK_CURSES é MARCA: o "dano recebido" das marcas somadas para em MARK_TAKEN_CAP (Combat.taken_pct).
## "dragon_jump": {}  → (GROUND) Salto Dracônico: some do chão por Balance.DRAGON_JUMP_AIR s (intocável, quem o mirava volta
##     ao maior de ameaça) e cai no ponto mirado (chão andável mais perto): power no centro, DRAGON_JUMP_EDGE na borda.
## "shout": {"element": "fire|frost|storm"}  → Brado Elemental (SELF, com `buff`): um por vez; a lança ganha o elemento,
##     o grupo/inimigos perto recebem o efeito e os monstros a SHOUT_TAUNT_RADIUS são provocados (RangerAscension.shout).
## Necromante ascendido (NecroAscension): "summon_pact": {"dmg_pct", "speed_pct", "leech_pct"} → (SELF, com `buff`) as invocações
##     a Balance.LORD_PACT_RADIUS m ganham dano, velocidade e roubo de vida para o dono pela duração do buff;
##     "miasma": {"duration", "weaken_pct", "slow_pct"} → (GROUND) nuvem que fica no chão: inimigos dentro causam menos dano e
##     andam mais devagar (uma por necromante); "grave_mark": {"duration", "raise"} → (GROUND) marca os inimigos na área:
##     monstro comum que morrer marcado levanta como esqueleto aliado por `raise` s (até Balance.LORD_GRAVE_MAX).
##     "form": "lich" → Forma de Lich (Balance.FORM_STATS/FORM_DURATION): maldições espalham e cabe +1 invocação por tipo.
## "shadow_clone": {}  → (SELF) Sombra Gêmea (Assassino ascendido): clone de sombra por Balance.SHADOW_TIME s que repete os
##     golpes diretos do dono com SHADOW_SHARE% do dano; monstros o ignoram; some com o dono (ShadowSystem).
## "execute": {}  → Execução: poder cheio só em alvo abaixo de Balance.EXECUTION_BELOW da vida; acima, EXECUTION_WEAK.
## Bispo ascendido (ChoirSystem): "choir_angel": {} → chama o Anjo Guardião (espírito que cura o grupo, Balance.ANGEL_*);
##     "choir_barrier": {} → (GROUND) Barreira Sagrada: cúpula de `radius` m que anda com o Bispo (Balance.BARRIER_*);
##     "choir_return": {} → (GROUND) Retorno: no fim do preparo levanta o caído do grupo mais perto do ponto (Balance.RES_*).
## "explode": {"radius": 1.5, "power_pct": 0.5}  → projétil que explode no impacto: em volta do atingido, power × power_pct
##     e os efeitos (WorldSim._explode; Bola de Fogo, Balance.FIREBALL_EXPLODE_*).
## "fire_wall": {"width", "duration", "pulse"}  → (GROUND) faixa de 2 × radius m atravessada na mira que fica no chão:
##     o lançamento bate em quem está nela e cada pulso renova o `dot` em quem passar (TrapSystem.place_wall; Balance.FIRE_WALL_*).
## TARGET com projectile_pierce: o tiro segue depois do alvo e pega a fila atrás dele até o alcance (Balance.PIERCE_SHOT_HALF).
## "pull": {"gap": 0.6}  → puxa o atingido para o lado de quem lançou (gancho; chefe nunca é puxado).
## Druida ascendido (DruidAscension, Forma Ancestral):
## "provoke": {"duration": 4}  → cada monstro atingido fica preso em quem lançou (MobSystem.taunt; chefes: metade). Ao
##     contrário de "taunt" (grito: só o buff em você), a skill continua causando dano e efeitos nos atingidos.
## "knockback": {"dist": 4}  → empurra o atingido para longe do centro do golpe (ponto mirado no GROUND, senão de quem
##     lançou), parando em parede/água; chefe e quem está em torre não são empurrados (DruidAscension.knockback; o Canhão
##     de Mão do Corsário usa o mesmo efeito).
## "area_heal": {"power": 0.7}  → além do dano, cura (x MATK) os aliados dentro da área do golpe.
## "pack": {"monster_id": "pack_wolf", "count": 2}  → chama a matilha por Balance.ANC_PACK_TIME s: vida/ataque/defesa são
##     parte dos do dono (ANC_PACK_*); um chamado novo dispensa os lobos antigos.
## Berserker ascendido (TitanSystem/GladiatorSystem): "titan_hit": true → bate com as duas armas (× 1 + Stats.titan_hit);
##     "glory_scale": true → power + Balance.GLORY_STEP por Glória; "glory_spend": true → gasta toda a Glória (Golpe Final);
##     "glory_gain": true (com "taunt") → +1 Glória por inimigo provocado (até GLORY_SHOUT_MAX);
## "chain": {"count": 2, "radius": 4.5, "falloff": 0.6} → depois do golpe, o raio salta do 1º atingido para até `count`
##     inimigos a `radius` m com power × falloff (WorldSim._chain).
## "elem_command": true  → (ascensão do Elementalista) sem elemental chama o persistente; com ele, troca o modo (ElementalSystem).
## "elem_fusion": true   → (ascensão do Elementalista) o golpe ganha o efeito da forma do elemental e o mago o buff
##     `elem_fusion` (MATK + elemento da forma, x estágio). Skills com estes efeitos exigem a ascensão.
## Preenchimento de skills (GDD design/gdd/skills-fill-2026-11-19.md; números em Balance):
## "zone": {"id", "duration", "pulse", "foe_power", "ally_heal", "ally_buff": {...}, "foe_slow": pct}  → (GROUND) o golpe
##     bate normal e fica um círculo de `radius` m no ponto: a cada pulso, inimigos dentro levam foe_power x ATK/MATK (sem
##     crítico) e o `dot` renova; aliados dentro ganham ally_heal x cura e o ally_buff (TrapSystem.place_zone). Uma por
##     (lançador, skill); some com o dono morto/fora do mapa.
## "sunder": {"add", "taken_per", "max", "duration"}  → rachadura: cargas no debuff Balance.SUNDER_ID (+taken_per % de dano
##     recebido por carga, é marca); "sunder_consume": {"per"} → antes do golpe power x (1 + per x cargas) e zera (SunderSystem).
## "seed": {"delay", "radius", "power", "spread_dot", "max_targets"}  → semente no alvo que explode no fim do tempo ou na
##     morte dele, em volta, e espalha a queimadura da skill (SeedSystem; a explosão não planta outra).
## "sacrifice": {"pick_radius", "max", "blast_radius", "hp_weight"}  → (GROUND) suas invocações perto do ponto explodem
##     (power x vida) e morrem sem XP/saque; sem nenhuma, a skill é recusada (SummonRites).
## "combust": {"kind": "poison", "detonate", "per", "max"}  → Eviscerar: em vez das queimaduras, os VENENOS seus
##     (WoundSystem.is_wound) saem e explodem; o golpe ganha `per` de poder por veneno (até `max`).
## "wound_heal": {"pct", "max"}  → Sangria: cura pct% da vida máx. por atingido que sangrava (ferida sua), até max.
## "wound_extend": {"add", "cap"}  → Presas Gêmeas: +add s nas suas feridas em cada atingido (até cap s restantes).
## "riposte": true  → Guarda do Duelista: o buff da skill é a janela de aparar (RiposteSystem).
## "momentum_spend": {"power_pct"}  → Golpe de Mestre: gasta o Ímpeto, +power_pct% de poder por carga.
@export var effects: Dictionary = {}

## Maestria: array de 6 dicionários {power_mult, mp_mult, cd_mult, extra:Dictionary}
@export var mastery: Array = []

## preenchido só na cópia "resolvida" por evoluções (WorldSim.resolve_skill); aplicado depois da maestria
var talent_effects: Dictionary = {}

## Investida: avança em linha reta e acerta o caminho (salto e teleporte são GROUND/SELF).
func is_charge() -> bool:
	return effects.has("dash") and target == Target.DIRECTION

func mastery_entry(level: int) -> Dictionary:
	var lv := clampi(level, 0, 5)
	if mastery.size() > lv:
		return mastery[lv]
	# fallback padrão: +12% poder, -4% custo, -5% cooldown por nível
	return {"power_mult": 1.0 + Balance.MASTERY_POWER_PER_LV * lv, "mp_mult": 1.0 - Balance.MASTERY_MP_PER_LV * lv, "cd_mult": 1.0 - Balance.MASTERY_CD_PER_LV * lv, "extra": {}}

func power_at(level: int) -> float:
	return power * float(mastery_entry(level).get("power_mult", 1.0))

func mp_cost_at(level: int) -> float:
	return mp_cost * float(mastery_entry(level).get("mp_mult", 1.0))

func cooldown_at(level: int) -> float:
	return cooldown * float(mastery_entry(level).get("cd_mult", 1.0))
