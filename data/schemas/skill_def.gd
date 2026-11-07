class_name SkillDef
extends Resource
## Definição de uma skill. Os números por maestria vêm de `mastery` (6 entradas, nível 0..5).

enum Target { SELF, DIRECTION, GROUND, CONE, TARGET }
enum Kind { PHYSICAL, MAGICAL, HEAL, BUFF, SUMMON, MOVEMENT }

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
##     quem estava preparando um golpe; depois volta para a mão de quem lançou.
## "aura": {"radius": 12, "ally": {"dr_pct": 8, "def_pct": 10}}  → liga/desliga: lançar põe o `buff` (sem fim)
##     em você; enquanto ele durar, o grupo a `radius` m recebe `ally` com o mesmo id (AuraSystem). Lançar de novo desliga.
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
	return {"power_mult": 1.0 + 0.12 * lv, "mp_mult": 1.0 - 0.04 * lv, "cd_mult": 1.0 - 0.05 * lv, "extra": {}}

func power_at(level: int) -> float:
	return power * float(mastery_entry(level).get("power_mult", 1.0))

func mp_cost_at(level: int) -> float:
	return mp_cost * float(mastery_entry(level).get("mp_mult", 1.0))

func cooldown_at(level: int) -> float:
	return cooldown * float(mastery_entry(level).get("cd_mult", 1.0))
