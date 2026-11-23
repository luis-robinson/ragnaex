class_name HitTint
extends RefCounted
## Cor do hit flash por tipo de dano (decisão D5, plano production/qa/spell-attack-anim-research-2026-11-23.md, pacote V3).
## Só apresentação: ouve Events.damage_dealt e guarda, por alvo, a cor do último golpe e se foi crítico. A EntityView lê
## (color_of/crit_of) e manda para o toon (flash_color / flash_full): borda na cor do dano; corpo todo branco só no crítico.
## Tema do dano mágico = tema da última skill do atacante (Events.skill_cast "active"); o resto vem do `kind` do evento.

## Paleta D5 (borda de hit flash). Físico = aço pálido.
const COLORS := {
	"physical": Color(0.80, 0.88, 0.97),
	"fire": Color(1.0, 0.52, 0.12),
	"ice": Color(0.35, 0.90, 1.0),
	"lightning": Color(0.50, 0.52, 1.0),      # tempestade: violeta-azulado
	"holy": Color(1.0, 0.84, 0.28),
	"shadow": Color(0.62, 0.22, 0.95),
	"nature": Color(0.38, 0.95, 0.32),
	"poison": Color(0.72, 1.0, 0.18),
	"blood": Color(0.95, 0.12, 0.14),
	"earth": Color(0.78, 0.58, 0.32),
	"wind": Color(0.72, 1.0, 0.90),
	"lunar": Color(0.62, 0.55, 1.0),
	"bone": Color(0.92, 0.90, 0.78),
}
## `kind` do evento que já diz o elemento (vence o tema da skill).
const KIND_THEME := {
	"dot_fire": "fire", "detonate": "fire", "splash": "fire", "dot": "poison", "shatter": "ice", "shadow": "shadow",
	"chain": "lightning", "holy_edge": "holy", "penance": "holy", "aura": "holy",
}
## `kind` em que o tema da skill do atacante manda (o resto é físico: aço).
const THEME_KINDS := {"magical": true, "dot_magic": true}
const CRIT_COLOR := Color(1.0, 1.0, 1.0)

static var _hooked := false
static var _theme_of_caster: Dictionary = {}     # id do atacante -> tema da última skill (ativa)
static var _color: Dictionary = {}               # id do alvo -> Color do último golpe
static var _crit: Dictionary = {}                # id do alvo -> bool

## Liga os eventos (uma vez; a EntityView chama antes de ler).
static func ensure() -> void:
	if _hooked:
		return
	_hooked = true
	Events.damage_dealt.connect(_on_damage)
	Events.skill_cast.connect(_on_cast)
	Events.entity_despawned.connect(_on_gone)

static func _on_cast(entity_id: int, skill_id: String, phase: String) -> void:
	if phase != "active":
		return
	var s: SkillDef = GameData.skill_or_basic(skill_id)
	if s != null:
		_theme_of_caster[entity_id] = FxManager.theme_of(s)

static func _on_gone(id: int) -> void:
	_theme_of_caster.erase(id)
	_color.erase(id)
	_crit.erase(id)

static func _on_damage(attacker_id: int, target_id: int, amount: int, crit: bool, _blocked: bool, kind: String) -> void:
	if amount <= 0:
		return
	_color[target_id] = color_for(kind, str(_theme_of_caster.get(attacker_id, "")))
	_crit[target_id] = crit and not kind.begins_with("dot")

## Tema de dano a partir do `kind` do evento e do tema da skill do atacante. Puro (o teste chama sem cena).
static func theme_for(kind: String, caster_theme: String) -> String:
	if KIND_THEME.has(kind):
		return KIND_THEME[kind]
	if THEME_KINDS.has(kind) and COLORS.has(caster_theme):
		return caster_theme
	return "physical"

static func color_for(kind: String, caster_theme: String) -> Color:
	return COLORS[theme_for(kind, caster_theme)]

## Cor do hit flash do alvo (aço se ainda não apanhou por evento).
static func color_of(id: int) -> Color:
	return _color.get(id, COLORS["physical"])

static func crit_of(id: int) -> bool:
	return _crit.get(id, false)

## Cor e "corpo todo" que vão para o toon: crítico = branco cheio; senão a cor do dano só na borda.
static func flash_look(id: int) -> Array:
	if crit_of(id):
		return [CRIT_COLOR, 1.0]
	return [color_of(id), 0.0]

## Cor do número de dano CRÍTICO (decisão do usuário 2026-11-23: cor do elemento só no crítico). Golpe físico
## devolve a cor de crítico de sempre (`physical_crit`): o aço pálido não lê como crítico. Puro (o teste chama sem cena).
static func crit_number_color(kind: String, caster_theme: String, physical_crit: Color) -> Color:
	var th := theme_for(kind, caster_theme)
	if th == "physical":
		return physical_crit
	return COLORS[th]

## Tema da última skill ativa do atacante ("" se nenhuma).
static func caster_theme(attacker_id: int) -> String:
	return str(_theme_of_caster.get(attacker_id, ""))

## Teste: esquece tudo (sem desligar os eventos).
static func clear() -> void:
	_theme_of_caster.clear()
	_color.clear()
	_crit.clear()
