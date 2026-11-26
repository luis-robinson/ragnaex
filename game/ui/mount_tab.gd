class_name MountTab
extends RefCounted
## Aba Montaria da janela do personagem (C) (mvp-premios.md §3.5): prévia 3D girando da montaria escolhida (tipo, cor,
## armadura), listas Tipo / Cor / Armadura com o travado em cinza e "de onde vem". Escolher = Sim.set_mount_look
## (só aparência; vale ao montar com H). O Tratador continua liberando o Lobo Atroz pela missão.

const PREVIEW := Vector2(284, 130)
const SWATCH := 26

static var preview_model: FormModel = null      # revisão/testes: a montaria da prévia aberta
static var buttons := {}                        # "kind:<k>" / "dye:<i>" / "barding:<s>" -> botão (testes/revisão)

# --- linhas (puras; testadas) ---

## De onde vem o tipo travado ("" = livre).
static func kind_source(kind: String) -> String:
	var d: Dictionary = Balance.MOUNT_KINDS.get(kind, {})
	if str(d.get("mvp", "")) != "":
		var md: MonsterDef = GameData.monsters.get(str(d["mvp"]))
		return "MVP: %s (sorteio no prêmio, ou a loja do Intendente das Caçadas depois de %d lutas)" % [md.name if md else str(d["mvp"]), Balance.MVP_MOUNT_FIGHTS]
	var q := str(d.get("quest", ""))
	if q != "":
		var qd: QuestDef = GameData.quests.get(q)
		return "Missão \"%s\" (Tratadora de Lobos, Kharzun)" % (qd.title if qd else q)
	return ""

## [{kind, name, owned, using, source}] na ordem de Balance.MOUNT_KINDS.
static func kind_rows(p: SimEntity) -> Array:
	var out: Array = []
	for k in Balance.MOUNT_KINDS:
		out.append({"kind": k, "name": Balance.MOUNT_KINDS[k]["name"], "owned": MountSystem.unlocked(p, k), "using": p.mount_kind == k,
			"source": kind_source(k)})
	return out

## Cores do tipo: [{i, color, owned, using, source}].
static func dye_rows(p: SimEntity, kind: String) -> Array:
	var out: Array = []
	var dyes := MountSystem.dyes_of(kind)
	for i in range(dyes.size()):
		var own := MountSystem.dye_owned(p, kind, i)
		out.append({"i": i, "color": dyes[i], "owned": own, "using": p.mount_kind == kind and maxi(p.mount_dye, 0) == i,
			"source": "" if own else MvpSystem.cosmetic_source("dye:%s:%d" % [kind, i])})
	return out

## Armaduras: "" (Nenhuma) + Balance.MOUNT_BARDINGS: [{style, name, owned, using, source}].
static func barding_rows(p: SimEntity) -> Array:
	var out: Array = [{"style": "", "name": "Nenhuma", "owned": true, "using": p.mount_barding == "", "source": ""}]
	for st in Balance.MOUNT_BARDINGS:
		var own := MountSystem.barding_owned(p, st)
		out.append({"style": st, "name": Balance.MOUNT_BARDINGS[st], "owned": own, "using": p.mount_barding == st,
			"source": "" if own else MvpSystem.cosmetic_source("barding:" + st)})
	return out

## Escolher um tipo: mantém a cor se ela existe no tipo novo, a armadura se você a tem.
static func pick_kind(p: SimEntity, kind: String) -> bool:
	var dye := maxi(p.mount_dye, 0)
	if not MountSystem.dye_owned(p, kind, dye):
		dye = 0
	return Sim.set_mount_look(p, kind, dye, p.mount_barding)

static func pick_dye(p: SimEntity, i: int) -> bool:
	return Sim.set_mount_look(p, p.mount_kind, i, p.mount_barding)

static func pick_barding(p: SimEntity, style: String) -> bool:
	return Sim.set_mount_look(p, p.mount_kind, maxi(p.mount_dye, 0), style)

# --- montagem ---

## `w` = windows.gd (rebuild e dicas).
static func build(w, p: SimEntity, side: VBoxContainer) -> void:
	buttons.clear()
	side.add_child(_preview(p))
	if not MountLook.has_model(p.mount_kind):
		side.add_child(UiKit.label("(modelo em produção: a prévia mostra o cavalo)", 10, UiKit.MUTED))
	# tipo
	side.add_child(UiKit.label("Tipo", 13, UiKit.GOLD))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 3)
	side.add_child(g)
	for r in kind_rows(p):
		var b := UiKit.button(("● " if r["using"] else "") + str(r["name"]), _on_kind.bind(w, str(r["kind"])), 138)
		b.icon = UiKit.icon_texture(ActionBar.mount_icon(str(r["kind"])))
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 18)
		b.add_theme_font_size_override("font_size", 11)
		b.disabled = not r["owned"] or r["using"]
		if not r["owned"]:
			b.modulate = Color(0.6, 0.6, 0.6)
		w._tip_on(b, str(r["name"]) + ("\n[color=#aaa]Travado. De onde vem: %s[/color]" % r["source"] if not r["owned"] else "\n[color=#9f9]Vale ao montar (%s)[/color]" % KeyBindings.label("mount")))
		buttons["kind:" + str(r["kind"])] = b
		g.add_child(b)
	# cor
	side.add_child(UiKit.label("Cor", 13, UiKit.GOLD))
	var cr := HBoxContainer.new()
	cr.add_theme_constant_override("separation", 4)
	side.add_child(cr)
	for r in dye_rows(p, p.mount_kind):
		var b := Button.new()
		b.custom_minimum_size = Vector2(SWATCH, SWATCH)
		var st := UiKit.panel_style(r["color"] if r["owned"] else Color(0.3, 0.3, 0.3), Color(1.0, 0.85, 0.4) if r["using"] else UiKit.BORDER, 4, 3 if r["using"] else 1)
		for nm in ["normal", "hover", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(nm, st)
		b.disabled = not r["owned"]
		b.pressed.connect(_on_dye.bind(w, int(r["i"])))
		w._tip_on(b, "Cor %d%s" % [int(r["i"]) + 1, "" if r["owned"] else "\n[color=#aaa]Travada. De onde vem: %s[/color]" % r["source"]])
		buttons["dye:%d" % int(r["i"])] = b
		cr.add_child(b)
	# armadura
	side.add_child(UiKit.label("Armadura (só aparência)", 13, UiKit.GOLD))
	var ag := GridContainer.new()
	ag.columns = 2
	ag.add_theme_constant_override("h_separation", 4)
	ag.add_theme_constant_override("v_separation", 3)
	side.add_child(ag)
	for r in barding_rows(p):
		var b := UiKit.button(("● " if r["using"] else "") + str(r["name"]), _on_barding.bind(w, str(r["style"])), 138)
		b.add_theme_font_size_override("font_size", 11)
		b.disabled = not r["owned"] or r["using"]
		if not r["owned"]:
			b.modulate = Color(0.6, 0.6, 0.6)
		w._tip_on(b, str(r["name"]) + ("" if r["owned"] else "\n[color=#aaa]Travada. De onde vem: %s[/color]" % r["source"]))
		buttons["barding:" + str(r["style"])] = b
		ag.add_child(b)

static func _on_kind(w, kind: String) -> void:
	pick_kind(Sim.player, kind)
	w._rebuild("character")

static func _on_dye(w, i: int) -> void:
	pick_dye(Sim.player, i)
	w._rebuild("character")

static func _on_barding(w, style: String) -> void:
	pick_barding(Sim.player, style)
	w._rebuild("character")

## Prévia: a montaria escolhida girando devagar num palco próprio.
static func _preview(p: SimEntity) -> Control:
	var cont := UiKit.preview_stage(PREVIEW, Vector3(2.3, 1.5, 2.3), Vector3(0, 0.85, 0), true)
	var vp: SubViewport = cont.get_child(0)
	var m := MountLook.create(p.mount_kind, maxi(p.mount_dye, 0), p.mount_barding, p.id)
	preview_model = m
	if m == null:
		return cont
	m.scale = Vector3.ONE * EntityView.HORSE_SCALE
	vp.add_child(m)
	if m.anim and m.anim.has_animation("idle"):
		m.anim.play("idle")
	m.tree_entered.connect(_spin.bind(m), CONNECT_ONE_SHOT)       # o tween só nasce dentro da árvore
	return cont

static func _spin(m: Node3D) -> void:
	var tw := m.create_tween().set_loops()
	tw.tween_property(m, "rotation:y", TAU, 9.0).from(0.0)
