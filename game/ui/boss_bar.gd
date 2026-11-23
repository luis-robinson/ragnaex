class_name BossBar
extends PanelContainer
## Barra do chefe no topo central do HUD (plano de combate 2026-11-23, C4; decisão do usuário: estilo MMO).
## Só apresentação: lê o estado da sim (vida, fase, ward, assinatura, skill em preparação) e nunca muda nada.
## Aparece com um chefe de verdade (a mesma regra da trava, BossLock.is_lockable) a até Balance.BOSS_LOCK_RELEASE m
## que está brigando com você ou com o seu grupo (ameaça/aggro/dano), ou o travado no Tab. Some quando ele morre,
## reseta (reset_boss limpa a ameaça) ou você se afasta.
## Linhas: nome + fases (◆ = já começou) + "Protegido" (ward dos lacaios) · vida com as marcas das fases e o % ·
## conjuração (assinatura, canal ou golpe com preparação longa) na cor da gramática de perigo do FxManager.

const REPICK_S := 0.25            # s entre duas buscas do chefe (o resto atualiza a cada quadro pelo chefe guardado)
const CAST_MIN_S := 0.5           # preparação/canal mais curto que isto não ganha barra (pisca e some: só ruído)
const WIDTH := 520.0
const HP_H := 22.0
const CAST_H := 16.0
const HP_FILL := Color(0.78, 0.16, 0.12)
const HP_FURY := Color(1.0, 0.42, 0.1)          # fúria da fase / enlouquecido
const HP_BACK := Color(0.05, 0.04, 0.06, 0.92)
const PHASE_MARK := Color(1.0, 0.86, 0.5, 0.9)
const PHASE_DONE := Color(1.0, 0.82, 0.3)
const PHASE_LEFT := Color(0.45, 0.4, 0.35)
const WARD_COL := Color(0.65, 0.8, 1.0)
const BORDER := Color(0.85, 0.55, 0.3)
const BORDER_LOCK := Color(1.0, 0.85, 0.4)      # travado no Tab: borda dourada (a etiqueta "Travado" some enquanto a barra mostra)

var boss_id := -1
var lock_id := -1                 # trava do Tab (hud.set_lock)
var _repick := 0.0
var _name: Label
var _phases: Label
var _ward: Label
var _hp: Strip
var _cast: Strip
var _style: StyleBoxFlat

## Faixa desenhada (vida ou conjuração): fundo, preenchimento, marcas e texto no meio. Redesenha só quando muda.
class Strip extends Control:
	var frac := 1.0
	var fill := Color.WHITE
	var marks: Array = []          # frações (0-1) com marca vertical (limiares de fase)
	var text := ""
	var font_size := 13
	func set_values(f: float, c: Color, t: String, m: Array = []) -> void:
		f = clampf(f, 0.0, 1.0)
		if is_equal_approx(f, frac) and c == fill and t == text and m == marks:
			return
		frac = f
		fill = c
		text = t
		marks = m
		queue_redraw()
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, BossBar.HP_BACK)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * frac, size.y)), fill)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * frac, size.y * 0.35)), Color(1, 1, 1, 0.12))     # brilho de cima
		for m in marks:
			var x: float = size.x * float(m)
			draw_line(Vector2(x, 0), Vector2(x, size.y), BossBar.PHASE_MARK, 2.0)
		draw_rect(r, Color(0, 0, 0, 0.7), false, 1.0)
		if text != "":
			var f := get_theme_default_font()
			var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var at := Vector2((size.x - w) * 0.5, (size.y + font_size * 0.72) * 0.5)
			draw_string_outline(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color(0, 0, 0, 0.85))
			draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UiKit.TEXT)

func _init() -> void:
	_style = UiKit.panel_style(Color(0.08, 0.05, 0.05, 0.9), BORDER, 6, 2)
	_style.set_content_margin_all(6)
	_style.content_margin_left = 10
	_style.content_margin_right = 10
	add_theme_stylebox_override("panel", _style)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -WIDTH * 0.5
	offset_right = WIDTH * 0.5
	offset_top = 6
	visible = false
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)
	_name = UiKit.label("", 15, Color(1.0, 0.88, 0.62))
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.clip_text = true
	top.add_child(_name)
	_ward = UiKit.label("", 12, WARD_COL)
	top.add_child(_ward)
	_phases = UiKit.label("", 13, PHASE_DONE)
	top.add_child(_phases)
	_hp = Strip.new()
	_hp.custom_minimum_size = Vector2(0, HP_H)
	_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_hp)
	_cast = Strip.new()
	_cast.custom_minimum_size = Vector2(0, CAST_H)
	_cast.font_size = 12
	_cast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cast.visible = false
	col.add_child(_cast)

## Quadro do HUD: reescolhe o chefe a cada REPICK_S e atualiza as linhas. `sim` = a WorldSim (Sim).
func update(sim: WorldSim, p: SimEntity, delta: float) -> void:
	_repick -= delta
	if _repick <= 0.0:
		_repick = REPICK_S
		var b := pick(sim.map_entities(p.map_id), p, Balance.BOSS_LOCK_RELEASE, lock_id)
		boss_id = b.id if b else -1
	var e: SimEntity = sim.get_entity(boss_id) if boss_id >= 0 else null
	if e == null or not BossLock.is_lockable(e) or e.map_id != p.map_id:
		boss_id = -1
		visible = false
		return
	visible = true
	show_boss(sim, e)

## Preenche as linhas com o estado do chefe `e` (a foto e o teste chamam direto).
func show_boss(sim: WorldSim, e: SimEntity) -> void:
	var md := e.monster_def
	_name.text = md.name + ("   ◆ Travado" if e.id == lock_id else "")
	_style.border_color = BORDER_LOCK if e.id == lock_id else BORDER
	_phases.text = phase_text(md, e.phase)
	_ward.text = ("⛨ Protegido -%d%%" % roundi(e.ward * 100.0)) if e.ward > 0.0 else ""
	var pct := clampf(e.hp / maxf(1.0, e.stats.max_hp), 0.0, 1.0)
	var fury := e.berserk or e.enrage_mult > 1.0
	_hp.set_values(pct, HP_FURY if fury else HP_FILL, "%d%%%s" % [ceili(pct * 100.0 - 0.001), "  · Fúria" if fury else ""], phase_marks(md))
	var c := cast_info(sim, e)
	_cast.visible = not c.is_empty()
	if not c.is_empty():
		var txt := "%s  %.1f s" % [c["name"], maxf(0.0, float(c["left"]))]
		if c.get("break", false):
			txt += "  — interrompa!"
		_cast.set_values(float(c["frac"]), mech_color(int(c["mech"])), txt)

## Chefe a mostrar: o travado (`prefer_id`) se ainda vale; senão o mais perto que briga com o jogador ou o grupo dele.
## null = nenhum. Puro (o teste chama sem cena).
static func pick(entities: Array, player: SimEntity, reach: float, prefer_id: int = -1) -> SimEntity:
	if player == null or not player.is_alive():
		return null
	var ids := {}
	for o: SimEntity in entities:
		if o == player or o.owner_id == player.id or (player.party_id >= 0 and o.party_id == player.party_id):
			ids[o.id] = true
	var best: SimEntity = null
	var best_d := INF
	for e: SimEntity in entities:
		if not BossLock.is_lockable(e):
			continue
		var d := Vector2(e.position.x - player.position.x, e.position.z - player.position.z).length()
		if d > reach:
			continue
		if e.id == prefer_id:
			return e
		if not engaged(e, ids):
			continue
		if d < best_d:
			best_d = d
			best = e
	return best

## O chefe briga com alguém de `ids` (id -> true): ameaça, dano que levou, ou alvo dele numa luta em curso
## (fight_time > 0: reset_boss zera; o aggro_target sozinho não é limpo pelo reset).
static func engaged(e: SimEntity, ids: Dictionary) -> bool:
	if ids.has(e.aggro_target) and e.fight_time > 0.0:
		return true
	for k in e.threat:
		if ids.has(k):
			return true
	for k in e.damage_by:
		if ids.has(k):
			return true
	return false

## Limiares das fases (MonsterDef.phases[].hp, 0-1), na ordem do catálogo.
static func phase_marks(md: MonsterDef) -> Array:
	var out: Array = []
	for ph in md.phases:
		var h := float((ph as Dictionary).get("hp", 0.0))
		if h > 0.0 and h < 1.0:
			out.append(h)
	return out

## "◆◆◇" = fases já começadas / as que faltam ("" sem fases).
static func phase_text(md: MonsterDef, started: int) -> String:
	var n := phase_marks(md).size()
	if n == 0:
		return ""
	var s := ""
	for i in n:
		s += "◆" if i < started else "◇"
	return s

## Conjuração que vale barra: {name, frac (0-1 da barra), left (s), mech (AccessSettings.Mech), break (canal que o dano
## corta)}; {} = nada. Ordem: canal de assinatura, contragolpe da Muralha, Muralha, skill com preparação/canal longo.
static func cast_info(sim: WorldSim, e: SimEntity) -> Dictionary:
	var now := sim.time
	if e.sig.has("channel"):
		var c: Dictionary = e.sig["channel"]
		var s: SkillDef = GameData.skills.get(str(c["skill"]))
		return {"name": s.name if s else "Canal", "frac": BossSignatures.channel_progress(sim, e),
			"left": float(c["until"]) - now, "mech": mech_of(s), "break": true}
	if e.sig.has("counter"):
		var q: Dictionary = e.sig["counter"]
		var span := maxf(0.01, float(q["at"]) - float(q["start"]))
		return {"name": "Contragolpe", "frac": (now - float(q["start"])) / span, "left": float(q["at"]) - now,
			"mech": AccessSettings.Mech.DAMAGE}
	if e.sig.has("wall"):
		var w: Dictionary = e.sig["wall"]
		var ws: SkillDef = GameData.skills.get(str(w["skill"]))
		var t := float(Balance.BOSS_SIG_DEFAULTS["wall"]["time"])
		if ws and ws.effects.get("wall") is Dictionary:
			t = float(ws.effects["wall"].get("time", t))
		var left := float(w["until"]) - now
		return {"name": ws.name if ws else "Muralha", "frac": left / maxf(0.01, t), "left": left, "mech": AccessSettings.Mech.DAMAGE}
	var sk := e.current_skill
	if e.state != SimEntity.State.CASTING or sk == null or sk == e.basic_skill:
		return {}
	if e.skill_phase == "startup" and sk.startup >= CAST_MIN_S:
		return {"name": sk.name, "frac": e.state_time / sk.startup, "left": sk.startup - e.state_time, "mech": mech_of(sk)}
	if e.skill_phase == "active" and sk.effects.has("channel") and sk.active >= CAST_MIN_S:
		var into := e.state_time - sk.startup
		return {"name": sk.name, "frac": 1.0 - into / sk.active, "left": sk.active - into, "mech": mech_of(sk)}
	return {}

## Classe de perigo da skill (gramática do FxManager.DANGER* / BossSigView): dividir = dourado, controle = roxo,
## lugar seguro (ilhas) = frio, o resto = dano (carmim).
static func mech_of(s: SkillDef) -> int:
	if s == null:
		return AccessSettings.Mech.DAMAGE
	var mk = s.effects.get("mark")
	if mk is Dictionary and str((mk as Dictionary).get("mode", "")) == "soak":
		return AccessSettings.Mech.SOAK
	if s.effects.has("islands"):
		return AccessSettings.Mech.SAFE
	if FxManager.CONTROL_TELEGRAPH.has(s.id):
		return AccessSettings.Mech.CONTROL
	if s.power <= 0.5 and (s.effects.has("stun") or s.effects.has("root") or s.effects.has("pull")):
		return AccessSettings.Mech.CONTROL
	return AccessSettings.Mech.DAMAGE

## Cor da barra de conjuração pela classe (segue o modo de contraste/daltônico de AccessSettings).
static func mech_color(mech: int) -> Color:
	var base: Color = FxManager.DANGER
	match mech:
		AccessSettings.Mech.SOAK:
			base = BossSigView.GOLD_RIM
		AccessSettings.Mech.CONTROL:
			base = FxManager.DANGER_CONTROL
		AccessSettings.Mech.SAFE:
			base = Color(BossSigView.SAFE, 1.0)
	return AccessSettings.tele_color(mech, Color(base, 1.0))
