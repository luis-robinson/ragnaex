class_name MonsterDef
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var level: int = 1
@export var hp: float = 40.0
@export var atk: float = 8.0
@export var matk: float = 0.0
@export var def: float = 2.0
@export var mdef: float = 2.0
@export var move_speed: float = 3.5
@export var attack_range: float = 1.6
@export var attack_cooldown: float = 1.4
@export var attack_startup: float = 0.35
@export var aggro_range: float = 7.0
@export var leash_range: float = 18.0
@export var xp: int = 12
@export var radius: float = 0.5           ## raio de colisão/alvo
@export var scale: float = 1.0
@export var color: Color = Color(0.6, 0.3, 0.3)
@export var shape: String = "box"         ## placeholder: box | sphere | capsule | cone
@export var model: String = ""            ## GLB em assets/models
@export var is_boss: bool = false
@export var elite_of: String = ""         ## Rei que surge depois de muitos abates: id do monstro comum (quests contam por ele)
@export var ranged: bool = false          ## ataca à distância (projétil)
@export var loot_table: String = ""
@export var gold_min: int = 1
@export var gold_max: int = 5
@export var skill_ids: Array[String] = [] ## skills especiais opcionais (usam SkillDef)
@export var coin_chance: float = 0.0       ## > 0: chance própria de Moedas Lendárias (no lugar da regra comum/chefe)
@export var coin_min: int = 0
@export var coin_max: int = 0
@export var intro: String = ""             ## chefe: fala ao entrar em combate (uma vez por luta)
@export var last_words: String = ""        ## chefe: fala ao cair
@export var escort: Dictionary = {}         ## líder com escolta: {id, count} nascem junto e o seguem (capitão e bestas)
@export var swap: Dictionary = {}           ## troca de arma com pouca vida: {hp (0-1), as: id do monstro cujo ataque/alcance passa a usar, stance}
@export var front_guard: float = 0.0         ## escudo de frente (Guardião de Ossos): corta esta fração do golpe físico que vem da frente; costas e magia passam
## Troll Rei (R-E, GDD act2-boss-signatures 3.3): as skills listadas deixam um pedregulho (cobertura) no chão.
## {"radius": 1.2, "time": 40, "skills": ["mob_boulder_barrage"]}; máximo Balance.TROLL_COVER_MAX.
@export var cover: Dictionary = {}
## Shazka (R-F, GDD act2-boss-signatures 3.7): cópia de chefe. Morre com 1 golpe, não projeta sombra, não conta como chefe;
## morrendo solta a nuvem de veneno do dono (BossSignatures.on_death).
@export var decoy: bool = false
## Boneco de treino: não anda, não bate, não morre (segura em 1 HP), se recompõe parado (Balance.DUMMY_*),
## sem XP/saque/quest; só o jogador e as invocações dele o miram (SimEntity.is_hostile_to). Bots e sentinelas ignoram.
@export var dummy: bool = false
@export var berserk_after: float = 0.0     ## chefe: s de luta até enlouquecer (dano × Balance.BOSS_BERSERK_MULT); 0 = nunca
@export var berserk_mult: float = 0.0      ## chefe: dano × isto depois de berserk_after; 0 = Balance.BOSS_BERSERK_MULT (Durgash: a raide pede 5)
@export var crowd_skills: Array[String] = []  ## chefe: skills que entram quando a luta chega a Balance.BOSS_CROWD_EXTRA_FROM pessoas (pico; valem até o reset)
@export var crowd_say: String = ""          ## chefe: fala quando as crowd_skills entram
@export var faction: String = ""            ## facção (ex.: "horde"): quem recebe a aura de outro monstro da mesma facção
@export var aura: String = ""               ## aura de facção que este monstro emite: chave de Balance.MOB_AURAS (Agitador)
@export var stat_role: String = ""          ## Ato II: papel da fórmula F2 (comum/bruto/elite/chefe; Balance.horde_stat); "" = números à mão
@export var unit_mods: Dictionary = {}      ## Ato II: mod_unidade da F2 ({hp, atk}) sobre o papel
@export var skill_delay: float = 0.0       ## s depois de entrar na briga antes da 1ª skill especial (abre no golpe básico); Ato II 35+: Balance.HORDE_LATE_35
@export var regen: float = 0.0            ## Ato II (F3): regeneração de troll = isto × Balance.TROLL_REGEN_PCT × vida máxima por s; fogo/veneno param
@export var burn_immune: bool = false ## Ato II (Kharzun): queimadura (dot de fogo) não pega (Salamandra de Lava); o golpe de fogo ainda dói
@export var phases: Array = []            ## chefe, em ordem de HP: {hp (0-1), say, skills, summon: {id, count, max, pick}, enrage, ward (0-1: corte de dano com lacaio vivo)}
## Metamorfose (ShiftSystem): ao entrar em combate o monstro conjura shift_cast s (0 = Balance.SHIFT_CAST_S) e vira UMA forma
## sorteada por peso (rng da sim): [{"form": <id de outro MonsterDef>, "weight": n}]. A forma é um MonsterDef completo (modelo, vida,
## ataque, skills, velocidade, alcance, ranged, aggro/leash valem enquanto transformado); a vida guarda o %. Volta à base no leash/reset
## ou depois de Balance.SHIFT_REVERT_S s fora de combate. Morre como a forma, mas XP/saque/quest/elite contam pela BASE.
## Nome na placa: "<nome da base> (<nome da forma>)" (a forma tem nome curto: "Urso").
@export var shift_forms: Array = []
@export var shift_cast: float = 0.0
@export var shift_stealth: bool = false    ## forma: entra furtiva (Balance.SHIFT_STEALTH_S); o 1º golpe é emboscada × Balance.SHIFT_AMBUSH_MULT
@export var kite: bool = false             ## atirador que recua entre os tiros se o alvo chegar a menos de Balance.SHIFT_KITE_DIST m (gavião)

## Chefe de verdade resiste a controle (atordoa 40%, provocar 50%, não é puxado/empurrado). O Rei (elite, `elite_of`)
## é `is_boss` para loot/barra/IA, mas leva o controle cheio (decisão 2026-11-17).
func resists_cc() -> bool:
	return is_boss and elite_of == ""
