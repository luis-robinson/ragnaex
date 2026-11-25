class_name KeyBindings
extends RefCounted
## Teclas do jogo (Configurações → aba Controles): troca a tecla/botão de cada ação do InputMap e grava em
## user://settings.cfg na seção "keys" (só o que difere do padrão do project.godot; vale para todos os personagens).
## Esc, F11 e Enter (chat) ficam fixos. Quem MOSTRA uma tecla lê daqui (`label`/`short`/`fill`) e redesenha quando
## `revision` muda (barra de ações, dica do HUD, dicas, janelas). Lido no boot por start.gd e main.gd.

const SECTION := "keys"

## [ação, nome, grupo]. Ordem = ordem da lista na aba Controles.
const ACTIONS := [
	["move_forward", "Andar para frente", "Movimento"],
	["move_back", "Andar para trás", "Movimento"],
	["move_left", "Andar para a esquerda", "Movimento"],
	["move_right", "Andar para a direita", "Movimento"],
	["jump", "Pular", "Movimento"],
	["dash", "Esquiva (dash)", "Movimento"],
	["attack", "Atacar", "Combate"],
	["block", "Bloquear", "Combate"],
	["skill_1", "Skill 1", "Combate"],
	["skill_2", "Skill 2", "Combate"],
	["skill_3", "Skill 3", "Combate"],
	["skill_4", "Skill 4", "Combate"],
	["skill_5", "Skill 5", "Combate"],
	["skill_6", "Skill 6", "Combate"],
	["skill_7", "Ascensão 1", "Combate"],
	["skill_8", "Ascensão 2", "Combate"],
	["skill_9", "Ascensão 3", "Combate"],
	["skill_10", "Ascensão 4", "Combate"],
	["ultimate", "Suprema", "Combate"],
	["potion_1", "Poção 1", "Combate"],
	["potion_2", "Poção 2", "Combate"],
	["potion_3", "Poção 3", "Combate"],
	["lock_target", "Travar no chefe", "Combate"],
	["interact", "Interagir / colher", "Mundo"],
	["mount", "Montar / desmontar", "Mundo"],
	["recall", "Voltar à cidade", "Mundo"],
	["cam_rotate_left", "Girar câmera (esquerda)", "Mundo"],
	["cam_rotate_right", "Girar câmera (direita)", "Mundo"],
	["ui_inventory", "Bolsa", "Janelas"],
	["ui_character", "Personagem", "Janelas"],
	["ui_book", "Skills", "Janelas"],
	["ui_skills", "Teia", "Janelas"],
	["ui_quests", "Quests", "Janelas"],
	["ui_party", "Grupo", "Janelas"],
	["ui_map", "Mapa", "Janelas"],
]
## Teclas que não se trocam (e não podem ser dadas a uma ação): menu, tela cheia, chat.
const FIXED_KEYS := [KEY_ESCAPE, KEY_F11, KEY_ENTER, KEY_KP_ENTER]
const FIXED_NOTE := "Fixas: Esc (menu / cancelar), F11 (tela cheia), Enter (chat)"
const MOUSE_LONG := {MOUSE_BUTTON_LEFT: "Botão esquerdo", MOUSE_BUTTON_RIGHT: "Botão direito", MOUSE_BUTTON_MIDDLE: "Botão do meio",
	MOUSE_BUTTON_XBUTTON1: "Mouse 4", MOUSE_BUTTON_XBUTTON2: "Mouse 5", MOUSE_BUTTON_WHEEL_UP: "Roda para cima", MOUSE_BUTTON_WHEEL_DOWN: "Roda para baixo"}
const MOUSE_SHORT := {MOUSE_BUTTON_LEFT: "M1", MOUSE_BUTTON_RIGHT: "M2", MOUSE_BUTTON_MIDDLE: "M3",
	MOUSE_BUTTON_XBUTTON1: "M4", MOUSE_BUTTON_XBUTTON2: "M5", MOUSE_BUTTON_WHEEL_UP: "R↑", MOUSE_BUTTON_WHEEL_DOWN: "R↓"}
## Textos apertados (dica do canto do HUD): os nomes de sempre do mouse.
const MOUSE_COMPACT := {MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB"}
## Nomes pt-BR das teclas que o Godot chama em inglês.
const KEY_NAMES := {KEY_SPACE: "Espaço", KEY_SHIFT: "Shift", KEY_CTRL: "Ctrl", KEY_ALT: "Alt", KEY_TAB: "Tab",
	KEY_BACKSPACE: "Backspace", KEY_CAPSLOCK: "Caps Lock", KEY_UP: "↑", KEY_DOWN: "↓", KEY_LEFT: "←", KEY_RIGHT: "→",
	KEY_DELETE: "Delete", KEY_INSERT: "Insert", KEY_HOME: "Home", KEY_END: "End", KEY_PAGEUP: "PgUp", KEY_PAGEDOWN: "PgDn"}

static var cfg_path := "user://settings.cfg"     # testes trocam por um arquivo próprio
static var revision := 0                          # sobe a cada troca: quem mostra tecla redesenha quando muda

## Ações que se trocam (as de ACTIONS que existem no InputMap).
static func actions() -> Array[String]:
	var out: Array[String] = []
	for a in ACTIONS:
		out.append(str(a[0]))
	return out

static func action_name(action: String) -> String:
	for a in ACTIONS:
		if a[0] == action:
			return str(a[1])
	return action

static func is_remappable(action: String) -> bool:
	return actions().has(action)

## Evento padrão da ação (o 1º do project.godot), lido do ProjectSettings: não muda com as trocas.
static func default_event(action: String) -> InputEvent:
	var s: Variant = ProjectSettings.get_setting("input/" + action)
	if s is Dictionary and (s as Dictionary).has("events") and not (s["events"] as Array).is_empty():
		return s["events"][0]
	return null

## Evento de agora (o 1º do InputMap) ou null.
static func event_of(action: String) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	var evs := InputMap.action_get_events(action)
	return evs[0] if not evs.is_empty() else null

## Tecla/botão de um evento como texto curto e estável ("k:90", "m:1"); "" se não for tecla nem botão.
static func encode(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		return "k:%d" % int(k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)
	if ev is InputEventMouseButton:
		return "m:%d" % int((ev as InputEventMouseButton).button_index)
	return ""

## O inverso de `encode`: evento limpo (sem modificadores) que o InputMap aceita; null se o texto não serve.
static func decode(code: String) -> InputEvent:
	var parts := code.split(":")
	if parts.size() != 2 or not parts[1].is_valid_int():
		return null
	var n := int(parts[1])
	if parts[0] == "k" and n > 0:
		var k := InputEventKey.new()
		k.physical_keycode = n as Key
		return k
	if parts[0] == "m" and n > 0:
		var m := InputEventMouseButton.new()
		m.button_index = n as MouseButton
		return m
	return null

## Evento limpo a partir do que o jogador apertou (tecla física ou botão do mouse).
static func from_input(ev: InputEvent) -> InputEvent:
	return decode(encode(ev))

## Tecla fixa (Esc, F11, Enter): não pode ir para uma ação.
static func is_fixed(ev: InputEvent) -> bool:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var code: int = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		return FIXED_KEYS.has(code)
	return false

## Liga `ev` à ação. Se outra ação trocável já usa essa tecla, as duas trocam. Devolve a ação que trocou
## ("" = ninguém). Não grava (quem chama decide: `save()`).
static func rebind(action: String, ev: InputEvent) -> String:
	var clean := from_input(ev)
	if clean == null or not is_remappable(action) or is_fixed(clean):
		return ""
	var code := encode(clean)
	var mine := event_of(action)
	var other := ""
	for a in actions():
		if a != action and encode(event_of(a)) == code:
			other = a
			break
	if other != "":
		_set_event(other, from_input(mine) if mine else null)
	_set_event(action, clean)
	revision += 1
	return other

static func _set_event(action: String, ev: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	InputMap.action_erase_events(action)
	if ev:
		InputMap.action_add_event(action, ev)

## Evento a partir do nome da tecla ("Z", "F1", "Space") ou do mouse ("mouse4"); null se não reconhece.
static func event_from_text(key_name: String) -> InputEvent:
	var s := key_name.strip_edges()
	if s.to_lower().begins_with("mouse") and s.substr(5).is_valid_int():     # mouse1-3 = esq./dir./meio, mouse4/5 = laterais
		var idx := int(s.substr(5))
		var btn: int = [0, MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2][idx] if idx >= 1 and idx <= 5 else 0
		return decode("m:%d" % btn)
	var code := OS.find_keycode_from_string(s)
	return decode("k:%d" % int(code)) if code != KEY_NONE else null

## Revisão/dev: "--bind=potion_1:Z,mount:F4" troca só nesta partida (não grava). Devolve quantas valeram.
static func apply_spec(spec: String) -> int:
	var n := 0
	for part in spec.split(",", false):
		var kv := part.split(":")
		if kv.size() != 2:
			continue
		var ev := event_from_text(kv[1])
		if ev and is_remappable(kv[0]) and not is_fixed(ev):
			rebind(kv[0], ev)
			n += 1
	return n

## Todas de volta ao project.godot.
static func reset_defaults() -> void:
	for a in actions():
		var d := default_event(a)
		_set_event(a, from_input(d) if d else null)
	revision += 1

## Lê o salvo: padrões + o que estiver na seção "keys" (código inválido ou tecla fixa = fica o padrão).
static func load_settings() -> void:
	reset_defaults()
	var cfg := ConfigFile.new()
	if cfg.load(cfg_path) != OK or not cfg.has_section(SECTION):
		return
	for a in actions():
		var ev := decode(str(cfg.get_value(SECTION, a, "")))
		if ev and not is_fixed(ev):
			_set_event(a, ev)
	revision += 1

## Grava só as ações fora do padrão (mantém as outras seções do arquivo).
static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(cfg_path)
	if cfg.has_section(SECTION):
		cfg.erase_section(SECTION)
	for a in actions():
		var now := encode(event_of(a))
		if now != encode(default_event(a)):
			cfg.set_value(SECTION, a, now)
	cfg.save(cfg_path)

## Nome da tecla de um evento ("Z", "F1", "Espaço", "Botão esquerdo"); `short` = cabe no canto da vaga ("M1").
static func event_label(ev: InputEvent, short := false) -> String:
	if ev is InputEventMouseButton:
		var b := int((ev as InputEventMouseButton).button_index)
		var names: Dictionary = MOUSE_SHORT if short else MOUSE_LONG
		return str(names.get(b, "Mouse %d" % b))
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var code: int = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		if KEY_NAMES.has(code):
			return str(KEY_NAMES[code])
		var shown: int = code
		if k.physical_keycode != KEY_NONE and DisplayServer.get_name() != "headless":     # o que está escrito na tecla no teclado do jogador (ABNT2: Ç); headless não sabe
			var lay := int(DisplayServer.keyboard_get_keycode_from_physical(k.physical_keycode))
			if lay != KEY_NONE:
				shown = lay
		var s := OS.get_keycode_string(shown as Key)
		return s if s != "" else "?"
	return "—"

## Tecla de agora da ação, por extenso ("Z", "Botão esquerdo"); "—" se não tiver.
static func label(action: String) -> String:
	return event_label(event_of(action))

## Tecla de agora da ação, curta (canto das vagas da barra).
static func short(action: String) -> String:
	return event_label(event_of(action), true)

## Troca "{ação}" pela tecla de agora em textos para o jogador ("{potion_1}-{potion_3} bebem..." -> "Z-F3 bebem...");
## "{move}" = as quatro de andar.
## `compact` = botões do mouse como LMB/RMB (texto apertado).
static func fill(text: String, compact := false) -> String:
	if not text.contains("{"):
		return text
	var out := text
	if out.contains("{move}"):                    # atalho: as quatro de andar juntas ("WASD")
		out = out.replace("{move}", label("move_forward") + label("move_left") + label("move_back") + label("move_right"))
	for a in actions():
		var tok := "{%s}" % a
		if out.contains(tok):
			var ev := event_of(a)
			var mb := int((ev as InputEventMouseButton).button_index) if ev is InputEventMouseButton else -1
			out = out.replace(tok, str(MOUSE_COMPACT[mb]) if compact and MOUSE_COMPACT.has(mb) else label(a))
	return out
