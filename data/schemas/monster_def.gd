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
@export var berserk_after: float = 0.0     ## chefe: s de luta até enlouquecer (dano × Balance.BOSS_BERSERK_MULT); 0 = nunca
@export var faction: String = ""            ## facção (ex.: "horde"): quem recebe a aura de outro monstro da mesma facção
@export var aura: String = ""               ## aura de facção que este monstro emite: chave de Balance.MOB_AURAS (Agitador)
@export var stat_role: String = ""          ## Ato II: papel da fórmula F2 (comum/bruto/elite/chefe; Balance.horde_stat); "" = números à mão
@export var unit_mods: Dictionary = {}      ## Ato II: mod_unidade da F2 ({hp, atk}) sobre o papel
@export var skill_delay: float = 0.0       ## s depois de entrar na briga antes da 1ª skill especial (abre no golpe básico); Ato II 35+: Balance.HORDE_LATE_35
@export var regen: float = 0.0            ## Ato II (F3): regeneração de troll = isto × Balance.TROLL_REGEN_PCT × vida máxima por s; fogo/veneno param
@export var phases: Array = []            ## chefe, em ordem de HP: {hp (0-1), say, skills, summon: {id, count, max, pick}, enrage, ward (0-1: corte de dano com lacaio vivo)}
