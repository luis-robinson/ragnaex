class_name TeleportFx
extends RefCounted
## Teleporte (2026-11-23; EntityView.TELEPORTS): o corpo some na origem e reaparece no destino, sem arco de pulo.
## Só desenho: o dano/corte do pouso continua sendo o skill_effect da sim. Camada e tetos de SkillFx.TIERS, aro de
## SkillFx.RING, clarão × AccessSettings.flash (SkillFx.flash); grupo/bots passam por FxManager._ally_fx_skip.

## estilo -> tema do SkillFx (cor e partículas). Nada vermelho no chão.
const STYLES := {"shadow": "shadow", "arcane": "lunar", "lightning": "lightning"}
const CHEST := Vector3(0, 0.9, 0)
const RING_R := 0.9                 # m: aro de faíscas do Piscar (enfeite, não é hitbox)

## Tema do SkillFx do estilo (o corpo pisca na cor de aro dele).
static func theme_of(style: String) -> String:
	return str(STYLES.get(style, "lunar"))

## Sumiço em `from` e reaparecer em `to`; a EntityView chama no quadro em que o corpo chega.
## Ex.: TeleportFx.play(entity, "shadow", origem, entity.position)
static func play(e: SimEntity, style: String, from: Vector3, to: Vector3) -> void:
	var fx: FxManager = FxManager.live
	if fx == null or not is_instance_valid(fx) or e == null or fx.main == null:
		return
	if e.map_id != fx.main.current_map_id or fx._ally_fx_skip(e):
		return                 # outro mapa / efeito de aliado reduzido (AccessSettings.ally_fx)
	SkillFx.tier = SkillFx.tier_of(e.current_skill)
	var th := theme_of(style)
	match style:
		"shadow":
			_shadow(fx, from, to, th)
		"lightning":
			_lightning(fx, from, to, th)
		_:
			_arcane(fx, from, to, th)
	SkillFx.tier = "skill"

## Passo das Sombras: fumaça escura onde estava; estouro escuro no pouso, antes do corte.
static func _shadow(fx: Node, from: Vector3, to: Vector3, th: String) -> void:
	SkillFx.burst(fx, from + CHEST, th, 22, Vector3.UP, 0.35)
	SkillFx.burst(fx, from + Vector3(0, 0.2, 0), th, 10, Vector3.UP, 0.5, 0.6)
	SkillFx.burst(fx, to + CHEST * 0.7, th, 18, Vector3.UP, 0.3, 1.3)

## Piscar: anel de faíscas que fecha na origem e abre no destino, clarão pequeno.
static func _arcane(fx: Node, from: Vector3, to: Vector3, th: String) -> void:
	SkillFx.circle(fx, from, RING_R, th, 0.35)
	SkillFx.burst(fx, from + CHEST, th, 16, Vector3.UP, 0.3)
	SkillFx.circle(fx, to, RING_R, th, 0.4)
	SkillFx.burst(fx, to + CHEST, th, 16, Vector3.UP, 0.3)
	SkillFx.flash(fx, to + CHEST, th, 1.5, 3.0)

## Passo Relampejante: vira raio (risco da origem ao destino) e cai do céu no pouso.
static func _lightning(fx: Node, from: Vector3, to: Vector3, th: String) -> void:
	SkillFx.burst(fx, from + CHEST, th, 14, Vector3.UP, 0.3)
	SkillFx.arc_bolt(fx, from + CHEST, to + CHEST, th)
	SkillFx.bolt(fx, to, th)
