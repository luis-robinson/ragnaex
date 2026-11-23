class_name AccessSettings
extends RefCounted
## Acessibilidade (Configurações → aba Acessibilidade), salva em user://settings.cfg na seção "access" (vale para todos os
## personagens). Os padrões são o comportamento de antes: tremor 100%, avisos sem padrão, todos os efeitos, clarões 100%.
## Quem desenha lê daqui: CameraRig (tremor), BossSigView/FxManager (avisos), FxManager (efeitos dos aliados),
## EntityView/SkillFx (clarões). Doc: production/qa/combat-best-practices-2026-11-23.md §8 (A1-A4) e critério 15.

enum Contrast {OFF, HIGH, COLORBLIND}
enum Density {ALL, REDUCED, MINIMAL}
## Tipo de mecânica de um aviso: cada um tem borda/padrão próprio nos modos de contraste (nunca só a cor).
enum Mech {DAMAGE, SAFE, SOAK, SPREAD, CONTROL}

const SECTION := "access"
const CONTRAST_NAMES := ["Desligado", "Alto contraste", "Daltônico"]
const DENSITY_NAMES := ["Tudo", "Reduzido", "Mínimo"]
const DEFAULT_SHAKE := 1.0
const DEFAULT_FLASH := 1.0
const DEFAULT_CONTRAST := Contrast.OFF
const DEFAULT_DENSITY := Density.ALL

## Padrão por mecânica: `edge` = desenho da borda (solid grossa / dash tracejada / rings anéis de dentro /
## segment segmentada / wave ondulada), `hatch` = listras diagonais na área.
const PATTERNS := {
	Mech.DAMAGE: {"edge": "solid", "hatch": true},
	Mech.SAFE: {"edge": "dash", "hatch": false},
	Mech.SOAK: {"edge": "rings", "hatch": false},
	Mech.SPREAD: {"edge": "segment", "hatch": false},
	Mech.CONTROL: {"edge": "wave", "hatch": false},
}
## Paleta segura para deuteranopia/protanopia (família Okabe-Ito): laranja / azul / amarelo / roxo. Espalhar é dano
## (laranja avermelhado); a forma da borda separa os dois.
const COLORBLIND := {
	Mech.DAMAGE: Color(0.95, 0.45, 0.0),
	Mech.SAFE: Color(0.2, 0.6, 1.0),
	Mech.SOAK: Color(0.98, 0.9, 0.2),
	Mech.SPREAD: Color(0.85, 0.3, 0.0),
	Mech.CONTROL: Color(0.7, 0.4, 0.95),
}
const HIGH_ALPHA_MULT := 1.35          # alto contraste: área um pouco mais cheia (teto HIGH_ALPHA_MAX)
const HIGH_ALPHA_MAX := 0.6
const GREY_SAT := 0.25                 # abaixo disto a cor é "neutra" (borda creme, espuma): fica como está no daltônico

static var cfg_path := "user://settings.cfg"      # testes trocam por um arquivo próprio
static var shake := DEFAULT_SHAKE                  # 0..1: escala do tremor da câmera (0 = nenhum)
static var flash := DEFAULT_FLASH                  # 0..1: escala do hit flash e dos clarões
static var contrast: int = DEFAULT_CONTRAST
static var ally_fx: int = DEFAULT_DENSITY
static var _ally_n := 0                            # contador do "Reduzido" (um sim, um não: sem sorteio)

## Lê o salvo (sem arquivo/chave = padrão).
static func load_settings() -> void:
	reset_defaults()
	var cfg := ConfigFile.new()
	if cfg.load(cfg_path) != OK:
		return
	shake = clampf(float(cfg.get_value(SECTION, "shake", DEFAULT_SHAKE)), 0.0, 1.0)
	flash = clampf(float(cfg.get_value(SECTION, "flash", DEFAULT_FLASH)), 0.0, 1.0)
	contrast = clampi(int(cfg.get_value(SECTION, "contrast", DEFAULT_CONTRAST)), 0, CONTRAST_NAMES.size() - 1)
	ally_fx = clampi(int(cfg.get_value(SECTION, "ally_fx", DEFAULT_DENSITY)), 0, DENSITY_NAMES.size() - 1)

static func reset_defaults() -> void:
	shake = DEFAULT_SHAKE
	flash = DEFAULT_FLASH
	contrast = DEFAULT_CONTRAST
	ally_fx = DEFAULT_DENSITY
	_ally_n = 0

## Grava as quatro chaves (mantém as outras seções do arquivo).
static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(cfg_path)
	cfg.set_value(SECTION, "shake", shake)
	cfg.set_value(SECTION, "flash", flash)
	cfg.set_value(SECTION, "contrast", contrast)
	cfg.set_value(SECTION, "ally_fx", ally_fx)
	cfg.save(cfg_path)

static func set_shake(v: float, persist := true) -> void:
	shake = clampf(v, 0.0, 1.0)
	if persist:
		save()

static func set_flash(v: float, persist := true) -> void:
	flash = clampf(v, 0.0, 1.0)
	if persist:
		save()

## Próximo modo de contraste (salva). Devolve o nome novo.
static func cycle_contrast() -> String:
	contrast = (contrast + 1) % CONTRAST_NAMES.size()
	save()
	return contrast_name()

static func cycle_ally_fx() -> String:
	ally_fx = (ally_fx + 1) % DENSITY_NAMES.size()
	_ally_n = 0
	save()
	return ally_fx_name()

static func contrast_name() -> String:
	return CONTRAST_NAMES[contrast]

static func ally_fx_name() -> String:
	return DENSITY_NAMES[ally_fx]

# ------------------------------------------------------------------ efeitos dos aliados
## Um efeito de OUTRO personagem (aliado, bot) pode sair agora? Tudo = sim; Reduzido = um sim, um não; Mínimo = não.
## Quem chama nunca pergunta pelo efeito do próprio jogador nem por avisos.
static func ally_pass() -> bool:
	match ally_fx:
		Density.ALL:
			return true
		Density.REDUCED:
			_ally_n += 1
			return _ally_n % 2 == 1
	return false

# ------------------------------------------------------------------ avisos
## Avisos com padrão (borda/listras) por mecânica?
static func patterns_on() -> bool:
	return contrast != Contrast.OFF

## Padrão da mecânica no modo atual ({} = desligado).
static func pattern_of(mech: int) -> Dictionary:
	return PATTERNS[mech] if patterns_on() else {}

## Cor do aviso no modo atual. Desligado = a mesma; alto contraste = área mais cheia; daltônico = matiz da paleta segura
## com o brilho da original (vaga apagada continua apagada), cores neutras (creme, espuma) ficam.
static func tele_color(mech: int, base: Color) -> Color:
	match contrast:
		Contrast.HIGH:
			return Color(base.r, base.g, base.b, minf(base.a * HIGH_ALPHA_MULT, maxf(base.a, HIGH_ALPHA_MAX)))
		Contrast.COLORBLIND:
			if base.s < GREY_SAT:
				return base
			var p: Color = COLORBLIND[mech]
			var k := maxf(base.r, maxf(base.g, base.b)) / maxf(0.001, maxf(p.r, maxf(p.g, p.b)))
			return Color(minf(1.0, p.r * k), minf(1.0, p.g * k), minf(1.0, p.b * k), base.a)
	return base
