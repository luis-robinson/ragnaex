class_name Hud
extends CanvasLayer
## HUD do jogo: barras, hotbar 1-6, poções F1-F3, chat, notificações, quest tracker,
## janelas (I/C/K/L), diálogo de NPC, loja/craft, seleção de classe e tela de morte.

var main
var root: Control
# topo-esquerda
var name_label: Label
var hp_bar: ProgressBar
var mp_bar: ProgressBar
var hp_text: Label
var hp_shield: ShieldOverlay       # barreira (vida temporária) por cima da barra de HP
var mp_text: Label
var gold_label: Label
var map_label: Label
# hotbar
var skill_slots: Array = []     # [{box, cd, key, name, lv}]
var potion_slots: Array = []
var util_slots: Array = []       # montaria (H), volta à cidade (G)
var cast_panel: PanelContainer   # barra de conjuração do jogador (volta à cidade)
var cast_fill: ProgressBar
var cast_label: Label
var _cast_flash := 0.0           # >0 = mostrando "Interrompido" na barra
# chat / notificações
var chat_log: RichTextLabel
var chat_input: LineEdit
var notif_box: VBoxContainer
var loot_box: VBoxContainer        # "pegou" com ícone, acima da barra de skills
var _loot_rows: Dictionary = {}    # item_id -> {row, count, tween}
var _loot_from_ms := 0             # ignora os itens iniciais do personagem
var quest_tracker: RichTextLabel
## Fundo do chat e do painel de quests: quase opaco (nomes e placas do mundo apareciam através; arte R2 #16 e novo #5).
const PANEL_BG_A := 0.9
var hint_label: Label
var buffs_box: HBoxContainer
var game_menu: Control = null       # menu do Esc (salvar, voltar ao menu, sair)
var player_frame: PanelContainer      # quadro do personagem (janelas da esquerda abrem logo abaixo dele)
var _status_chips: Dictionary = {}   # chave -> {root, time, stacks}: ícones de buff/debuff, criados uma vez e atualizados
var _buff_src: Dictionary = {}       # id do buff -> {tex, name, desc} (skill ou item que dá)
# grupo: quadros dos membros (abaixo do seu) e convite pendente
var party_box: VBoxContainer
var elem_frame: PanelContainer      # quadro do elemental (Elementalista ascendido)
var elem_label: Label
var elem_xp_bar: ProgressBar
var elem_buttons: Dictionary = {}   # "form:fire" / "mode:attack" -> Button
var _elem_t := 0.0
var party_frames: Array = []    # [{id, name, hp, mp, info}]
var invite_panel: Control = null
var invite_from := -1
# janelas
var windows: Dictionary = {}    # nome -> Control
var windows_script
var npc_ui
var death_panel: Control = null
var act_end_panel: Control = null
var tips: Tips = null
var _chat_focus := false

# layout (em px da resolução base 1280x720; a janela 1920x1080 escala 1.5x)
## Base 1600×900 (project.godot: viewport); tudo escala junto com a janela (1440p = 1,6×).
const MARGIN := 22
const GAP := 12          # espaço entre blocos do HUD
const SIDE_W := 300      # colunas laterais (chat / dicas e quests): iguais para o hotbar ficar no centro
const BOTTOM_H := 190    # altura da faixa de baixo (chat)
var minimap: Minimap
var tracked_quest_id := ""            # quest rastreada (seta amarela no minimapa); só apresentação
var fps_label: Label                 # contador de FPS (canto direito, embaixo do nome do mapa)
var gather_label: Label              # "[F] Colher ..." perto de um ponto; "Colhendo..." durante
var lock_tag: PanelContainer        # Tab: "Travado: <chefe>" no topo enquanto a trava no chefe vale (BossLock)
var lock_label: Label
var boss_bar: BossBar                 # barra do chefe no topo central (vida, fases, conjuração; C4 2026-11-23)
var raid_banner: PanelContainer      # faixa no topo durante uma investida no mapa do jogador (Sim.raid_status)
var raid_label: Label
## Fala de chefe (abertura/fase/queda): faixa própria, opaca, abaixo da investida; não divide a linha das notificações
## nem fica solta por cima do nome do chefe no mundo (R2: grito sobre o nome). Nomes do mundo sob a faixa somem (label_blockers).
var boss_banner: PanelContainer
var boss_label: Label
var _boss_left := 0.0
const BOSS_LINE_TIME := 4.0
const BOSS_LANE_TOP := 84.0
const NOTIF_TOP := 132.0                # notificações começam abaixo da faixa do chefe
const RAID_TOP := 42.0                  # faixa da investida (desce para baixo da barra do chefe: _stack_top_lane)
const RAID_H := 36.0
const LANE_GAP := 4.0
var _raid_t := 0.0
var _fps_t := 0.0

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_top_left()
	_build_top_right()
	_build_notifications()
	_build_bottom_row()
	_build_cast_bar()
	tips = Tips.new()                       # dicas contextuais do começo (uma vez cada; Esc liga/desliga)
	tips.hud = self
	root.add_child(tips)
	windows_script = load("res://game/ui/windows.gd").new()
	windows_script.hud = self
	root.add_child(windows_script)
	npc_ui = load("res://game/ui/npc_ui.gd").new()
	npc_ui.hud = self
	root.add_child(npc_ui)
	root.visible = false
	Events.notification.connect(_notify)
	Events.item_gained.connect(_on_item_gained)
	Events.chat_message.connect(_on_chat)
	Events.quest_accepted.connect(_on_quest_accepted)
	Events.quest_progress.connect(func(_e, _q, _c, _n): refresh_quest_tracker())
	Events.quest_completed.connect(func(_e, _q): refresh_quest_tracker())
	Events.quest_abandoned.connect(func(_e, _q): refresh_quest_tracker())
	Events.entity_died.connect(_on_died)
	Events.entity_respawned.connect(_on_respawned)
	Events.dialog_requested.connect(_on_dialog)
	Events.level_up.connect(_on_level_up)
	Events.mastery_changed.connect(_on_mastery)
	Events.party_changed.connect(func(_p): refresh_party())
	Events.party_invited.connect(_on_party_invited)
	Events.recall_cast.connect(_on_recall_cast)
	Events.quest_completed.connect(_on_act_quest)

func _on_level_up(id: int, _lv: int) -> void:
	if Sim.player and id == Sim.player.id:
		_refresh_hotbar_names()

func _on_mastery(id: int, _s: String, _l: int) -> void:
	if Sim.player and id == Sim.player.id:
		_refresh_hotbar_names()

## Trava no chefe (PlayerController.lock_changed): mostra/esconde a etiqueta dourada do topo.
func set_lock(target_id: int) -> void:
	if lock_tag == null:
		return
	var e: SimEntity = Sim.get_entity(target_id) if target_id >= 0 else null
	lock_tag.visible = e != null and not boss_bar.visible
	boss_bar.lock_id = e.id if e else -1
	if e and e.monster_def:
		lock_label.text = "◆ Travado: %s   (Tab solta)" % e.monster_def.name

func on_game_started() -> void:
	root.visible = true
	minimap.camera = main.camera
	_refresh_hotbar_names()
	refresh_quest_tracker()
	refresh_party()

func on_map_changed(def: MapDef) -> void:
	if world_map != null:
		toggle_world_map()                  # trocou de mapa: o mapa grande fecha (abre de novo no novo mapa com M)
	if minimap:
		minimap.set_map(def)
	if map_label:
		map_label.text = "%s  (Lv %d-%d)" % [def.name, def.level_range.x, def.level_range.y]

# ---------------------------------------------------------------------------
func _build_top_left() -> void:
	# coluna: quadro do personagem + nome do mapa logo abaixo (acompanha a altura do quadro)
	var col := VBoxContainer.new()
	col.position = Vector2(MARGIN, MARGIN)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", GAP)
	root.add_child(col)
	var p := UiKit.panel()
	player_frame = p
	p.custom_minimum_size = Vector2(SIDE_W, 0)
	col.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	p.add_child(v)
	name_label = UiKit.label("", 16, UiKit.GOLD)
	v.add_child(name_label)
	hp_bar = UiKit.bar(Color(0.85, 0.25, 0.3), 18)
	hp_text = UiKit.label("", 12)
	hp_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_bar.add_child(hp_text)
	hp_shield = ShieldOverlay.attach(hp_bar)
	v.add_child(hp_bar)
	mp_bar = UiKit.bar(Color(0.3, 0.45, 0.95), 14)
	mp_text = UiKit.label("", 11)
	mp_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	mp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_bar.add_child(mp_text)
	v.add_child(mp_bar)
	gold_label = UiKit.label("", 12, UiKit.GOLD)          # XP fica na barra de ações, embaixo
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(gold_label)
	buffs_box = HBoxContainer.new()
	buffs_box.add_theme_constant_override("separation", 5)
	v.add_child(buffs_box)
	_build_elem_frame(col)
	party_box = VBoxContainer.new()
	party_box.add_theme_constant_override("separation", 4)
	party_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(party_box)

## Quadro do elemental (Elementalista ascendido): nome e estágio, experiência até o próximo, forma e modo (botões).
func _build_elem_frame(col: VBoxContainer) -> void:
	elem_frame = UiKit.panel()
	elem_frame.custom_minimum_size = Vector2(SIDE_W, 0)
	elem_frame.visible = false
	col.add_child(elem_frame)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	elem_frame.add_child(v)
	elem_label = UiKit.label("", 13, UiKit.GOLD)
	v.add_child(elem_label)
	elem_xp_bar = UiKit.bar(Color(0.95, 0.6, 0.25), 10)
	v.add_child(elem_xp_bar)
	for row_kind in ["form", "mode"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		v.add_child(row)
		var keys: Array = SkillsCatalog.ELEM_FORMS if row_kind == "form" else SkillsCatalog.ELEM_MODES
		var labels: Dictionary = SkillsCatalog.ELEM_FORM_LABELS if row_kind == "form" else SkillsCatalog.ELEM_MODE_LABELS
		for k in keys:
			var b := UiKit.button(str(labels[k]).capitalize(), _elem_pick.bind(row_kind, str(k)), 58)
			b.focus_mode = Control.FOCUS_NONE
			row.add_child(b)
			elem_buttons[row_kind + ":" + str(k)] = b

func _elem_pick(row_kind: String, key: String) -> void:
	var p: SimEntity = Sim.player
	if p == null:
		return
	Sim.sync()
	Sim.elem_command(p, key if row_kind == "form" else "", key if row_kind == "mode" else "")

func _update_elem_frame(p: SimEntity) -> void:
	var on := ElementalSystem.ascended(p)
	if elem_frame.visible != on:
		elem_frame.visible = on
	if not on:
		return
	var st := ElementalSystem.stage_of(p)
	var form := ElementalSystem.default_form(p)
	var cur := Sim.elemental_of(p)
	var nm: String = SkillsCatalog.ELEM_STAGE_NAMES[form][st]
	var prog := ElementalSystem.xp_progress(p)
	var swap_left := maxf(0.0, p.elem_swap_at - Sim.time)
	var xp_txt := (" · %d/%d" % [prog[0], prog[1]]) if int(prog[1]) > 0 else ""
	elem_label.text = "%s (%s)%s%s" % [nm, SkillsCatalog.ELEM_STAGE_LABELS[st], xp_txt, "" if cur else (" · volta em %ds" % ceili(swap_left) if swap_left > 0.0 else " · chame-o")]
	elem_xp_bar.max_value = maxf(1.0, float(prog[1] if int(prog[1]) > 0 else prog[0]))
	elem_xp_bar.value = float(prog[0])
	elem_xp_bar.tooltip_text = ("Experiência do elemental: %d / %d" % [prog[0], prog[1]]) if int(prog[1]) > 0 else "Estágio máximo"
	if st + 1 < Balance.ELEM_STAGE_LEVEL.size() and p.level < int(Balance.ELEM_STAGE_LEVEL[st + 1]) and int(prog[0]) >= int(prog[1]):
		elem_xp_bar.tooltip_text += " (próximo estágio no nível %d)" % int(Balance.ELEM_STAGE_LEVEL[st + 1])
	for k in elem_buttons:
		var b: Button = elem_buttons[k]
		var parts: PackedStringArray = str(k).split(":")
		var lit: bool = (parts[1] == form) if parts[0] == "form" else (parts[1] == p.elem_mode)
		b.modulate = Color(1.0, 0.85, 0.4) if lit else Color(0.75, 0.75, 0.8)
		if parts[0] == "form":
			b.tooltip_text = "Forma de %s (troca: recarga %ds; mantém estágio e %% de vida)" % [SkillsCatalog.ELEM_FORM_LABELS[parts[1]], int(Balance.ELEM_SWAP_CD)]

## Faixa de baixo: [chat] [hotbar centralizado] [dicas]. Containers garantem que nada se sobrepõe.
func _build_bottom_row() -> void:
	var row := HBoxContainer.new()
	row.anchor_left = 0.0; row.anchor_right = 1.0; row.anchor_top = 1.0; row.anchor_bottom = 1.0
	row.offset_left = MARGIN; row.offset_right = -MARGIN
	row.offset_top = -(BOTTOM_H + MARGIN); row.offset_bottom = -MARGIN
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", GAP * 2)
	root.add_child(row)
	row.add_child(_build_chat())
	row.add_child(_build_hotbar())
	row.add_child(_build_hints())

var action_bar: ActionBar

## Barra de ações no centro de baixo (ActionBar): skills 1-6, poções F1-F3, atalhos e XP.
func _build_hotbar() -> Control:
	action_bar = ActionBar.new()
	action_bar.hud = self
	action_bar.build()
	skill_slots = action_bar.skill_slots
	potion_slots = action_bar.potion_slots
	util_slots = action_bar.util_slots
	for s in util_slots:
		s["root"].gui_input.connect(_util_click.bind(str(s["id"])))
	for i in range(skill_slots.size()):
		var s: Dictionary = skill_slots[i]
		# arrastar: da janela K (ou de outro slot) para cá; botão direito tira da barra
		s["root"].set_drag_forwarding(_drag_skill_slot.bind(i), _can_drop_skill_slot, _drop_skill_slot.bind(i))
		s["root"].gui_input.connect(_slot_right_click.bind("skill", i))
	for i in range(3):
		var s: Dictionary = potion_slots[i]
		# arrastar: poção da bolsa (ou de outro F) para cá; botão direito esvazia
		s["root"].set_drag_forwarding(_drag_potion_slot.bind(i), _can_drop_potion_slot, _drop_potion_slot.bind(i))
		s["root"].gui_input.connect(_slot_right_click.bind("potion", i))
	var wrap := CenterContainer.new()             # centraliza a moldura entre o chat e as dicas
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_vertical = Control.SIZE_SHRINK_END
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(action_bar)
	return wrap

## Ícone que segue o mouse no arrastar (skill ou item).
func _drag_icon(c: Control, at: Control) -> void:
	var wrap := Control.new()
	c.position = Vector2(-24, -24)
	c.modulate.a = 0.9
	wrap.add_child(c)
	at.set_drag_preview(wrap)

func _drag_skill_slot(_at: Vector2, i: int) -> Variant:
	var p: SimEntity = Sim.player
	var sk: SkillDef = p.skills[i] if p and i < p.skills.size() else null
	if sk == null:
		return null
	_drag_icon(UiKit.skill_icon(sk, 48), skill_slots[i]["root"])
	_skill_drag_from = i
	return {"rx_drag": "skill", "skill": sk.id, "from": i}

var _skill_drag_from := -1       # vaga do HUD de onde saiu o arrasto em curso (-1 = nenhum)

## Arrasto que começou numa vaga do HUD e não caiu em lugar que aceita: a skill sai da barra (soltar fora = tirar).
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _skill_drag_from >= 0:
		var from := _skill_drag_from
		_skill_drag_from = -1
		if Sim.player and drag_off(Sim.player, from, get_viewport().gui_is_drag_successful()):
			Events.notification.emit("Skill tirada da barra (%s)" % ActionBar.key_of(from))

## Fim do arrasto de uma vaga: sem um destino que aceitou, esvazia a vaga `from` (regra da cidade vale, Sim.set_skill_slot).
static func drag_off(p: SimEntity, from: int, dropped: bool) -> bool:
	if dropped or from < 0 or from >= p.skills.size() or p.skills[from] == null:
		return false
	return Sim.set_skill_slot(p, from, "")

func _can_drop_skill_slot(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("rx_drag") == "skill"

func _drop_skill_slot(_at: Vector2, data: Variant, i: int) -> void:
	if Sim.set_skill_slot(Sim.player, i, str(data["skill"])):     # já na barra: troca de lugar com o que estava aqui
		Events.notification.emit("%s → %s" % [GameData.skills[str(data["skill"])].name, ActionBar.key_of(i)])

func _drag_potion_slot(_at: Vector2, i: int) -> Variant:
	var item_id: String = Sim.player.potion_slots[i]
	var it: ItemDef = GameData.items.get(item_id) if item_id != "" else null
	if it == null:
		return null
	_drag_icon(UiKit.item_icon(it, 44), potion_slots[i]["root"])
	return {"rx_drag": "potion", "item": item_id, "from": i}

## Aceita consumível vindo da bolsa (`windows._drag_from_bag`) ou de outro F.
static func potion_drop_ok(data: Variant) -> bool:
	if not (data is Dictionary) or not data.get("rx_drag") in ["bag", "potion"]:
		return false
	var it: ItemDef = GameData.items.get(str(data.get("item", "")))
	return it != null and it.type == ItemDef.Type.CONSUMABLE and not it.consume.has("bag")

func _can_drop_potion_slot(_at: Vector2, data: Variant) -> bool:
	return potion_drop_ok(data)

func _drop_potion_slot(_at: Vector2, data: Variant, i: int) -> void:
	drop_potion(Sim.player, data, i)

## F1-F3 recebe o item; vindo de outro F, os dois trocam de lugar. Sem duplicar o mesmo item em dois F.
static func drop_potion(p: SimEntity, data: Dictionary, i: int) -> void:
	var item_id := str(data["item"])
	var old: String = p.potion_slots[i]
	if data.get("rx_drag") == "potion":
		Sim.set_potion_slot(p, int(data["from"]), old)
	else:
		for k in range(3):
			if k != i and p.potion_slots[k] == item_id:
				Sim.set_potion_slot(p, k, old)
	Sim.set_potion_slot(p, i, item_id)

## Clique no H/G da barra = apertar a tecla (vai pelo mesmo comando do teclado).
func _util_click(event: InputEvent, what: String) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if main and main.controller:
		if what == "mount":
			main.controller.queue_mount()
		else:
			main.controller.queue_recall()
	get_viewport().set_input_as_handled()

func _slot_right_click(event: InputEvent, kind: String, i: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		return
	if kind == "skill":
		Sim.set_skill_slot(Sim.player, i, "")
	else:
		Sim.set_potion_slot(Sim.player, i, "")
	get_viewport().set_input_as_handled()

func _build_chat() -> PanelContainer:
	var p := UiKit.panel(Color(0.05, 0.05, 0.08, PANEL_BG_A), Color(0.3, 0.28, 0.35))
	p.custom_minimum_size = Vector2(SIDE_W, BOTTOM_H)
	var v := VBoxContainer.new()
	p.add_child(v)
	chat_log = RichTextLabel.new()
	chat_log.bbcode_enabled = true
	chat_log.scroll_following = true
	chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_log.add_theme_font_size_override("normal_font_size", 13)
	chat_log.add_theme_font_size_override("bold_font_size", 13)
	chat_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(chat_log)
	chat_input = LineEdit.new()
	chat_input.placeholder_text = "Enter para falar..."
	chat_input.add_theme_font_size_override("font_size", 12)
	chat_input.text_submitted.connect(_on_chat_submit)
	chat_input.focus_entered.connect(func(): _chat_focus = true; _update_blocking())
	chat_input.focus_exited.connect(func(): _chat_focus = false; _update_blocking())
	v.add_child(chat_input)
	return p

func _build_notifications() -> void:
	loot_box = VBoxContainer.new()
	loot_box.anchor_left = 0.5; loot_box.anchor_right = 0.5; loot_box.anchor_top = 1.0; loot_box.anchor_bottom = 1.0
	loot_box.offset_left = 330; loot_box.offset_right = 640; loot_box.offset_top = -330; loot_box.offset_bottom = -110
	loot_box.alignment = BoxContainer.ALIGNMENT_END
	loot_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loot_box.add_theme_constant_override("separation", 4)
	root.add_child(loot_box)
	_loot_from_ms = Time.get_ticks_msec() + 1500
	gather_label = UiKit.label("", 16, Color(1.0, 0.92, 0.6))
	gather_label.anchor_left = 0.5; gather_label.anchor_right = 0.5; gather_label.anchor_top = 1.0; gather_label.anchor_bottom = 1.0
	gather_label.offset_left = -200; gather_label.offset_right = 200; gather_label.offset_top = -150; gather_label.offset_bottom = -126
	gather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gather_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(gather_label)
	raid_banner = UiKit.panel(Color(0.22, 0.07, 0.05, 0.88), Color(0.95, 0.5, 0.25))
	raid_banner.anchor_left = 0.5; raid_banner.anchor_right = 0.5
	raid_banner.offset_left = -230; raid_banner.offset_right = 230; raid_banner.offset_top = RAID_TOP; raid_banner.offset_bottom = RAID_TOP + RAID_H
	raid_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raid_banner.visible = false
	raid_label = UiKit.label("", 17, Color(1.0, 0.82, 0.55))
	raid_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	raid_banner.add_child(raid_label)
	root.add_child(raid_banner)
	notif_box = VBoxContainer.new()
	notif_box.anchor_left = 0.5; notif_box.anchor_right = 0.5
	notif_box.offset_left = -300; notif_box.offset_right = 300; notif_box.offset_top = NOTIF_TOP
	notif_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	notif_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(notif_box)
	boss_banner = UiKit.panel(Color(0.12, 0.06, 0.05, 0.92), Color(0.85, 0.55, 0.3))
	boss_banner.anchor_left = 0.5; boss_banner.anchor_right = 0.5
	boss_banner.offset_left = -360; boss_banner.offset_right = 360; boss_banner.offset_top = BOSS_LANE_TOP
	boss_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_banner.visible = false
	boss_label = UiKit.label("", 17, Color(1.0, 0.86, 0.6))
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boss_banner.add_child(boss_label)
	root.add_child(boss_banner)
	lock_tag = UiKit.panel(Color(0.1, 0.08, 0.04, 0.9), UiKit.GOLD)
	lock_tag.anchor_left = 0.5; lock_tag.anchor_right = 0.5
	lock_tag.offset_left = -170; lock_tag.offset_right = 170; lock_tag.offset_top = 8
	lock_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_tag.visible = false
	lock_label = UiKit.label("", 15, UiKit.GOLD)
	lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_tag.add_child(lock_label)
	root.add_child(lock_tag)
	boss_bar = BossBar.new()
	root.add_child(boss_bar)

## Coluna da direita: minimapa (com o nome do mapa embaixo) e o rastreador de quests.
func _build_top_right() -> void:
	var col := VBoxContainer.new()
	col.anchor_left = 1.0; col.anchor_right = 1.0
	col.offset_left = -(SIDE_W + MARGIN); col.offset_right = -MARGIN; col.offset_top = MARGIN
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", GAP)
	root.add_child(col)
	minimap = Minimap.new()
	minimap.size_flags_horizontal = Control.SIZE_SHRINK_END
	col.add_child(minimap)
	map_label = UiKit.label("", 14, Color(0.85, 0.95, 1.0))
	map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	map_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	col.add_child(map_label)
	fps_label = UiKit.label("", 13, Color(0.7, 0.95, 0.7))
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	col.add_child(fps_label)
	var p := UiKit.panel(Color(0.05, 0.05, 0.08, PANEL_BG_A), Color(0.3, 0.28, 0.35))      # quests: opaco (placas do mundo vazavam)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(p)
	quest_tracker = RichTextLabel.new()
	quest_tracker.bbcode_enabled = true
	quest_tracker.fit_content = true
	quest_tracker.custom_minimum_size = Vector2(SIDE_W - 20, 20)
	quest_tracker.add_theme_font_size_override("normal_font_size", 13)
	quest_tracker.add_theme_font_size_override("bold_font_size", 14)
	quest_tracker.mouse_filter = Control.MOUSE_FILTER_STOP        # clique no título = rastrear (seta no minimapa)
	quest_tracker.meta_underlined = false
	quest_tracker.add_theme_font_override("normal_font", UiKit.mark_font())     # "↻" das repetíveis
	quest_tracker.meta_clicked.connect(_on_track_clicked)
	p.add_child(quest_tracker)
	minimap.hud = self

func _build_hints() -> Label:
	hint_label = UiKit.label("WASD mover · LMB atacar · RMB bloquear · Shift dash\n1-6 skills · F1-F3 poções · Espaço pular · F interagir\nQ/E girar câmera · Enter chat · F11 tela cheia\nH montar · G voltar à cidade · Tab travar no chefe
arraste skills e poções para a barra", 12, UiKit.MUTED)
	hint_label.custom_minimum_size.x = SIDE_W
	hint_label.size_flags_vertical = Control.SIZE_SHRINK_END
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return hint_label

# ---------------------------------------------------------------------------
static var prof_us := 0.0           # --soak: tempo de script do HUD (sem o minimapa)
func _process(_delta: float) -> void:
	var _t0 := Time.get_ticks_usec()
	_hud_process(_delta)
	prof_us += Time.get_ticks_usec() - _t0

func _hud_process(_delta: float) -> void:
	_fps_t -= _delta
	if fps_label and _fps_t <= 0.0:
		_fps_t = 0.5
		var fps := Engine.get_frames_per_second()
		fps_label.text = "%d FPS" % fps
		fps_label.add_theme_color_override("font_color", Color(0.6, 0.95, 0.6) if fps >= 55 else (Color(1.0, 0.85, 0.4) if fps >= 35 else Color(1.0, 0.45, 0.4)))
	var p: SimEntity = Sim.player
	if p == null or not root.visible:
		return
	_update_gather_prompt(p)
	_raid_t -= _delta
	if _raid_t <= 0.0:
		_raid_t = 0.2
		_update_raid_banner(p)
	boss_bar.update(Sim, p, _delta)
	lock_tag.visible = boss_bar.lock_id >= 0 and not boss_bar.visible     # com a barra, o "Travado" vai nela
	_stack_top_lane()
	if _boss_left > 0.0:
		_boss_left -= _delta
		boss_banner.modulate.a = clampf(_boss_left / 0.6, 0.0, 1.0)
		if _boss_left <= 0.0:
			boss_banner.visible = false
	name_label.text = "%s — %s Lv.%d" % [p.name, p.class_def.name, p.level]
	hp_bar.max_value = p.stats.max_hp
	hp_bar.value = p.hp
	hp_text.text = ShieldOverlay.hp_text(p.hp, p.stats.max_hp, p.shield_hp)
	hp_shield.set_values(p.hp, p.shield_hp, p.stats.max_hp)
	mp_bar.max_value = p.stats.max_mp
	mp_bar.value = p.mp
	mp_text.text = "%d / %d" % [int(p.mp), int(p.stats.max_mp)]
	action_bar.set_xp(p.level, p.xp, Balance.xp_for_level(p.level))
	gold_label.text = "%d ouro" % p.gold
	# hotbar (7-0 aparecem com a ascensão)
	action_bar.set_slot_count(p.skills.size())
	action_bar.update_ult(p)
	for i in range(skill_slots.size()):
		var s: Dictionary = skill_slots[i]
		var sk: SkillDef = p.skills[i] if i < p.skills.size() else null
		if sk == null:
			s["icon"].color = Color(0.1, 0.1, 0.12)
			s["tex"].texture = null
			s["cd"].visible = false
			s["cdt"].text = ""
			s["sweep"].set_frac(0.0)
			s["bevel"].set_empty(true)
			continue
		s["bevel"].set_empty(false)
		# arma errada para a skill (ex.: Muralha de Escudo sem escudo) = cinza com ✖
		# a cavalo (Combate Montado): a não montável fica apagada; Carga/Pisotear a pé também
		var no_weapon := not p.stats.meets(sk.requires) or Sim.mount_block(p, sk) != ""
		var cd := float(p.cooldowns.get(sk.id, 0.0))
		var no_mp := p.mp < sk.mp_cost_at(p.mastery_of(sk.id))
		s["cd"].visible = no_weapon or (no_mp and cd <= 0.0)
		_set_charges(p, sk, s, cd)
		s["cdt"].text = "✖" if no_weapon else (_cd_text(cd) if cd > 0.0 else ("MP" if no_mp else ""))
		var aura_on: bool = (sk.effects.has("aura") and AuraSystem.aura_on(p, sk)) or (sk.effects.has("arcane") and Sim.arcane_on(p))
		if aura_on and cd <= 0.0 and not no_weapon:
			s["cdt"].text = "✓"                  # aura ligada (lançar de novo desliga)
		var cdt_col: Color = Color(1, 0.4, 0.4) if no_weapon else (Color(1.0, 0.85, 0.35) if aura_on else UiKit.TEXT)
		if s.get("cdt_col") != cdt_col:             # override de tema reavisa o Label (relayout): só quando a cor muda
			s["cdt_col"] = cdt_col
			s["cdt"].add_theme_color_override("font_color", cdt_col)
		s["icon"].color = sk.icon_color.darkened(0.6) if no_weapon else sk.icon_color
		s["tex"].texture = UiKit.icon_texture("skill_" + sk.id)
		s["tex"].modulate = Color(0.4, 0.4, 0.4) if no_weapon else Color.WHITE
	for i in range(3):
		var s: Dictionary = potion_slots[i]
		var item_id: String = p.potion_slots[i]
		var it: ItemDef = GameData.items.get(item_id) if item_id != "" else null
		var count := int(p.inventory.get(item_id, 0))
		s["icon"].color = it.icon_color.darkened(0.62) if it else Color(0.2, 0.2, 0.25)
		s["tex"].texture = UiKit.item_texture(it)
		s["tex"].modulate = Color.WHITE
		s["root"].tooltip_text = ("%s
Arraste outra poção da bolsa para cá · botão direito esvazia" % it.name) if it else "Arraste uma poção da bolsa (I) para cá"
		s["lv"].text = str(count) if it else ""
		s["cd"].visible = count == 0 and it != null
		var pcd: float = p.potion_cds[i]            # cada F tem a sua recarga
		s["sweep"].set_frac(_cd_frac(s, pcd) if it else 0.0)
		s["bevel"].set_empty(it == null)
		s["cdt"].text = _cd_text(pcd) if pcd > 0.0 and it else ""
	_update_util_slots(p, _delta)
	_elem_t -= _delta
	if _elem_t <= 0.0:
		_elem_t = 0.2
		_update_elem_frame(p)
	_update_party_frames()
	_update_status_bar(p)

## H (montaria) e G (volta à cidade) na barra: aro dourado quando ligados; os dois mostram a conjuração
## enchendo em leque claro.
func _update_util_slots(p: SimEntity, delta: float) -> void:
	for s in util_slots:
		if s["id"] == "mount":
			var mp := Sim.mount_progress(p)
			s["bevel"].set_active(p.mounted or mp > 0.0)
			s["sweep"].set_color(Color(1.0, 0.9, 0.55, 0.38))
			s["sweep"].set_frac(1.0 - mp if mp > 0.0 else 0.0)
			s["cdt"].text = _cd_text(p.mount_left) if mp > 0.0 else ""
			s["cd"].visible = not p.is_alive()
		else:
			var prog := Sim.recall_progress(p)
			s["bevel"].set_active(prog > 0.0)
			s["sweep"].set_color(Color(1.0, 0.9, 0.55, 0.38))
			s["sweep"].set_frac(1.0 - prog if prog > 0.0 else 0.0)
			s["cdt"].text = _cd_text(p.recall_left) if prog > 0.0 else ""
			s["cd"].visible = not p.is_alive()
	_update_cast_bar(p, delta)

## Barra de conjuração acima da barra de ações (volta à cidade); "Interrompido" em vermelho por um instante.
func _update_cast_bar(p: SimEntity, delta: float) -> void:
	if cast_panel == null:
		return
	_cast_flash = maxf(0.0, _cast_flash - delta)
	var prog := Sim.recall_progress(p)
	var mp := Sim.mount_progress(p)
	if prog > 0.0 or mp > 0.0:
		_cast_flash = 0.0
		cast_panel.visible = true
		cast_panel.modulate.a = 1.0
		cast_fill.value = prog if prog > 0.0 else mp
		cast_fill.get_theme_stylebox("fill").bg_color = Color(0.55, 0.78, 1.0) if prog > 0.0 else Color(0.95, 0.8, 0.45)
		if prog > 0.0:
			var home: String = Sim.home_of(p)["map"]
			cast_label.text = "Voltando para %s  %.1f s" % [GameData.maps[home].name, p.recall_left]
		else:
			cast_label.text = "Montando  %.1f s" % p.mount_left
		cast_label.add_theme_color_override("font_color", UiKit.TEXT)
	elif _cast_flash > 0.0:
		cast_panel.visible = true
		cast_panel.modulate.a = minf(1.0, _cast_flash / 0.4)
	else:
		cast_panel.visible = false

func _on_recall_cast(id: int, phase: String) -> void:
	if Sim.player == null or id != Sim.player.id or cast_panel == null:
		return
	if phase == "interrupted" or phase == "cancel":
		_cast_flash = 1.1
		cast_fill.get_theme_stylebox("fill").bg_color = Color(0.85, 0.25, 0.25)
		cast_label.text = "Interrompido" if phase == "interrupted" else "Cancelado"
		cast_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))

func _build_cast_bar() -> void:
	cast_panel = UiKit.panel(Color(0.05, 0.05, 0.08, 0.85), Color(0.55, 0.7, 0.95))
	cast_panel.anchor_left = 0.5; cast_panel.anchor_right = 0.5; cast_panel.anchor_top = 1.0; cast_panel.anchor_bottom = 1.0
	cast_panel.offset_left = -160; cast_panel.offset_right = 160; cast_panel.offset_top = -205; cast_panel.offset_bottom = -173
	cast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cast_panel.visible = false
	root.add_child(cast_panel)
	cast_fill = UiKit.bar(Color(0.55, 0.78, 1.0), 18)
	cast_fill.max_value = 1.0
	cast_fill.step = 0.0
	cast_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cast_panel.add_child(cast_fill)
	cast_label = UiKit.label("", 13)
	cast_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	cast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cast_fill.add_child(cast_label)

## Barra de buffs/debuffs: ícone (da skill/item que deu, ou do estado) com o tempo embaixo; borda verde = buff, vermelha = debuff.
const STATUS_NAMES := {"burn": ["Queimando", "Fogo: perde HP com o tempo."], "poison": ["Envenenado", "Perde HP com o tempo."],
	"slow": ["Lento", "Anda mais devagar. Gelo estilhaça: skills de gelo causam mais dano."], "root": ["Preso", "Não consegue andar."],
	"stun": ["Atordoado", "Não age até passar."], "curse": ["Amaldiçoado", "Recebe mais dano e/ou causa menos."],
	"wither": ["Definhando", "Cura recebida reduzida."], "shield": ["Barreira", "Absorve dano."],
	"juramento": ["Juramento", "Cargas do escudo: bloquear acumula."],
	"bastion": ["Bastião", "Defendendo as muralhas na investida: mais defesa e regenera vida."],
	"colonia_de_pe": ["Colônia de Pé", "Você ajudou a repelir uma investida: +10% de XP de abate neste mapa."]}

func _update_status_bar(p: SimEntity) -> void:
	var want: Array = []                  # [chave, buff?, tempo, cargas, ícone, nome, descrição]
	for b in p.buffs:
		var id: String = str(b.get("id", "buff"))
		var src := _buff_source(id)
		var tm: float = INF if (b.get("ct", false) or b.get("toggle", false) or b.has("aura_from")) else float(b.get("remaining", 0))      # talento de classe / aura: permanente
		if b.has("label"):              # Dados da Sorte: o que saiu (um ícone por resultado, com o nome dele)
			want.append(["b_%s_%s" % [id, b["label"]], true, tm, 0, src["tex"], "%s: %s" % [src["name"], b["label"]], src["desc"]])
			continue
		want.append(["b_" + id, true, tm, int(b.get("stacks", 0)), src["tex"], src["name"], src["desc"]])
	if p.form_left > 0.0 and p.form != "":           # forma com tempo (fantasma): ícone da skill que transformou
		var fs := _form_skill(p.form)
		if fs:
			want.append(["f_" + p.form, true, p.form_left, 0, UiKit.icon_texture("skill_" + fs.id), fs.name, fs.description])
	var deb := {}                          # debuffs do mesmo tipo viram um ícone só (maior tempo, quantos)
	for d in p.debuffs:
		var k: String = str(d.get("kind", ""))
		if k == "dot":
			k = "burn" if d.get("fire", false) else "poison"
		var cur: Array = deb.get(k, [0.0, 0])
		deb[k] = [maxf(cur[0], float(d.get("remaining", 0))), int(cur[1]) + 1]
	if p.state == SimEntity.State.STUNNED and p.is_alive():
		deb["stun"] = [maxf(0.0, p.state_duration - p.state_time), 1]
	for k in deb:
		var info: Array = STATUS_NAMES.get(k, [k, ""])
		want.append(["d_" + k, false, float(deb[k][0]), int(deb[k][1]) if int(deb[k][1]) > 1 else 0, UiKit.icon_texture("status_" + k), info[0], info[1]])
	var keep := {}
	for w in want:
		var key: String = w[0]
		keep[key] = true
		var c: Dictionary = _status_chips.get(key, {})
		if c.is_empty():
			c = _make_status_chip(w)
			_status_chips[key] = c
		var t: float = w[2]
		(c["time"] as Label).text = "∞" if t == INF else (("%dm" % ceili(t / 60.0)) if t >= 60.0 else ("%.0fs" % ceilf(t) if t >= 1.0 else "%.1f" % t))
		(c["stacks"] as Label).text = str(w[3]) if int(w[3]) > 1 else ""
	for key in _status_chips.keys():
		if not keep.has(key):
			(_status_chips[key]["root"] as Node).queue_free()
			_status_chips.erase(key)

func _make_status_chip(w: Array) -> Dictionary:
	var buff: bool = w[1]
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.tooltip_text = "%s\n%s" % [w[5], w[6]] if str(w[6]) != "" else str(w[5])
	var frame := PanelContainer.new()
	var sb := UiKit.panel_style(Color(0.05, 0.04, 0.07, 0.9), Color(0.4, 0.9, 0.45) if buff else Color(1.0, 0.35, 0.3), 4, 2)
	sb.set_content_margin_all(1)
	frame.add_theme_stylebox_override("panel", sb)
	frame.custom_minimum_size = Vector2(30, 30)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(holder)
	var tex: Texture2D = w[4]
	if tex == null:
		tex = UiKit.icon_texture("status_buff" if buff else "status_curse")
	var icon := TextureRect.new()
	icon.texture = tex
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(icon)
	var stacks := UiKit.label("", 11, Color(1, 1, 1))
	stacks.anchor_left = 1.0; stacks.anchor_right = 1.0; stacks.anchor_top = 1.0; stacks.anchor_bottom = 1.0
	stacks.offset_left = -16; stacks.offset_top = -15
	stacks.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stacks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(stacks)
	var time := UiKit.label("", 10, Color(0.85, 1, 0.85) if buff else Color(1, 0.75, 0.7))
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time.custom_minimum_size.x = 30
	time.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(time)
	buffs_box.add_child(root)
	return {"root": root, "time": time, "stacks": stacks}

## De onde vem o buff: a skill (ícone dela) ou o item (arte dele) que tem esse id; senão um estado conhecido ou o genérico.
func _form_skill(form: String) -> SkillDef:
	for sid in GameData.skills:
		var sk: SkillDef = GameData.skills[sid]
		if sk.effects.get("form", "") == form:
			return sk
	return null

## Dica do Juramento (Paladino, ShieldSystem): de onde vêm as cargas e o que elas fazem, com os números de Balance.
static func juramento_text() -> String:
	return "Cargas do Paladino: bloquear com escudo do Paladino dá 1 (aparar dá 2), até %d (%d com o talento Voto do Escudo); somem em %d s sem bloquear. A próxima skill de escudo ou sagrada que causa dano gasta todas: +%d%% de dano por carga." % [
		Balance.SHIELD_OATH_MAX, Balance.CT_OATH_MAX, int(Balance.SHIELD_OATH_TIME), roundi(Balance.SHIELD_OATH_POWER * 100.0)]

func _buff_source(id: String) -> Dictionary:
	if _buff_src.is_empty():
		for pair in [[Balance.LEG_BULWARK_BUFF, "leg_paladin_guardiao_30_mace", "Baluarte", "Maça/martelo lendário do Paladino: golpe dá uma barreira de parte da vida máxima (com recarga; renova, não acumula)."],
				[Balance.LEG_DETERMINATION_BUFF, "leg_paladin_guardiao_30_offhand", "Determinação", "Escudo lendário: atacar (com recarga) e levar golpes juntam cargas de dano causado e cura recebida; levar golpe renova, sem apanhar por um tempo some tudo."]]:
			if GameData.items.has(pair[1]):          # armas de papel (GearCatalog.WEAPON_ROLES): ícone = a arte da peça
				_buff_src[pair[0]] = {"tex": UiKit.item_texture(GameData.items[pair[1]]), "name": pair[2], "desc": pair[3]}
		_buff_src["juramento"] = {"tex": UiKit.icon_texture("status_juramento"), "name": "Juramento", "desc": juramento_text()}
		if GameData.skills.has("ass_between_eyes"):       # Bravata (Corsário): cargas que o Tiro Entre os Olhos gasta
			_buff_src[Balance.BRAVADO_BUFF] = {"tex": UiKit.icon_texture("skill_ass_between_eyes"), "name": "Bravata",
				"desc": "Cargas do Corsário (até %d): tiros e cortes juntam, o Tiro Entre os Olhos gasta todas." % Balance.BRAVADO_MAX}
		if GameData.skills.has(Balance.SHADOW_SKILL):     # Sombras Gêmeas (Assassino ascendido)
			_buff_src[Balance.SHADOW_BUFF] = {"tex": UiKit.icon_texture("skill_" + Balance.SHADOW_SKILL), "name": "Sombra Gêmea",
				"desc": "Seu clone de sombra repete cada golpe direto com parte do dano."}
			_buff_src[Balance.CHAIN_COUNTER_BUFF] = {"tex": UiKit.icon_texture("skill_" + Balance.EXECUTION_SKILL), "name": "Execução preparada",
				"desc": "Você esquivou: a próxima Execução sai sem recarga."}
		if GameData.skills.has("ass_master"):             # Ímpeto (Duelista): aparar junta, o Golpe de Mestre gasta
			_buff_src[Balance.RIPOSTE_MOMENTUM_BUFF] = {"tex": UiKit.icon_texture("skill_ass_master"), "name": "Ímpeto",
				"desc": "Cargas das aparadas da Guarda do Duelista (até %d): +%d de crítico por carga. O Golpe de Mestre gasta todas (+%d%% de dano por carga)." % [Balance.RIPOSTE_MOMENTUM_MAX, int(Balance.RIPOSTE_MOMENTUM_CRIT), int(Balance.RIPOSTE_SPEND_PCT)]}
		if GameData.skills.has("ber_final_fist"):         # Fúria do Punho (Punhos de Fúria): esquivar junta, o Punho Final gasta
			_buff_src[Balance.FIST_FURY_BUFF] = {"tex": UiKit.icon_texture("skill_ber_final_fist"), "name": "Fúria do Punho",
				"desc": "Cargas de quem luta com duas garras (até %d): cada golpe esquivado dá uma e contra-ataca; +ATK e velocidade por carga. O Punho Final gasta todas." % Balance.FIST_FURY_MAX}
		if GameData.skills.has("ber_glad_finale"):        # Glória (Modo Gladiador): crítico/abate/Brado juntam, o Golpe Final gasta
			_buff_src[Balance.GLORY_BUFF] = {"tex": UiKit.icon_texture("skill_ber_glad_finale"), "name": "Glória",
				"desc": "Cargas do Modo Gladiador (até %d): golpe crítico, abate e o Brado da Arena juntam; as Lâminas Elementais ficam mais fortes com ela e o Golpe Final gasta todas. Esfria %d s depois do último ganho." % [Balance.GLORY_MAX, int(Balance.GLORY_TIME)]}
		if GameData.skills.has(Balance.ARCANE_SKILL):     # Asas Protetoras (Templário): redução de dano no grupo perto das asas
			_buff_src[str(Balance.ARCANE_WARD["id"])] = {"tex": UiKit.icon_texture("skill_" + Balance.ARCANE_SKILL), "name": "Asas Protetoras",
				"desc": "As asas de um Templário perto protegem você: −%d%% de dano sofrido." % int(Balance.ARCANE_WARD["dr_pct"])}
		if GameData.skills.has("bis_hammer"):             # Aurora (Ápice Iluminado): magia sagrada dá +ATK e +MATK
			_buff_src[FusionEffects.AURORA_BUFF] = {"tex": UiKit.icon_texture("skill_bis_hammer"), "name": "Aurora",
				"desc": "Ápice da Aurora Ardente: sua magia sagrada deixa ATK e MATK mais altos por %d s." % int(Balance.FUSION_AURORA_TIME)}
		_buff_src["apex_tempest"] = {"tex": UiKit.icon_texture("skill_ber_throw_axe"), "name": "Frenesi da Tormenta",
			"desc": "Ápice da Tormenta Gêmea: cada golpe direto dá velocidade de ataque (até %d); o Arremesso Brutal gasta as cargas e bate mais." % Balance.FUSION_FRENZY_MAX}
		_buff_src["apex_cadence"] = {"tex": UiKit.icon_texture("skill_ass_focus"), "name": "Cadência",
			"desc": "Ápice da Cadência Perfeita: crítico com espada junta (esquivar dá 2); com %d vira Foco do Duelista." % Balance.APEX_CADENCE_MAX}
		for sid in GameData.skills:
			var sk: SkillDef = GameData.skills[sid]
			var faces = sk.effects.get("dice")
			if faces is Array and not faces.is_empty() and not _buff_src.has(faces[0].get("id", "")):
				_buff_src[faces[0]["id"]] = {"tex": UiKit.icon_texture("skill_" + sid), "name": sk.name, "desc": sk.description}
			var ob = sk.effects.get("orbit")             # Martelos Abençoados: o buff dos martelos girando
			if ob is Dictionary and ob.has("id") and not _buff_src.has(ob["id"]):
				_buff_src[ob["id"]] = {"tex": UiKit.icon_texture("skill_" + sid), "name": sk.name, "desc": sk.description}
			var b = sk.effects.get("buff")
			if b is Dictionary and b.has("id") and not _buff_src.has(b["id"]):
				_buff_src[b["id"]] = {"tex": UiKit.icon_texture("skill_" + sid), "name": sk.name, "desc": sk.description}
		for iid in GameData.items:
			var it: ItemDef = GameData.items[iid]
			var b = it.consume.get("buff")
			if b is Dictionary and b.has("id") and not _buff_src.has(b["id"]):
				_buff_src[b["id"]] = {"tex": UiKit.item_texture(it), "name": it.name, "desc": it.description}
	if _buff_src.has(id):
		return _buff_src[id]
	if STATUS_NAMES.has(id):
		return {"tex": UiKit.icon_texture("status_" + id), "name": STATUS_NAMES[id][0], "desc": STATUS_NAMES[id][1]}
	return {"tex": UiKit.icon_texture("status_buff"), "name": id.capitalize(), "desc": ""}

## Fração da recarga que falta: o maior valor visto desde que começou é o total (serve para skill e poção).
func _cd_frac(s: Dictionary, cd: float) -> float:
	if cd <= 0.0:
		s["cd_max"] = 0.0
		return 0.0
	if cd > float(s.get("cd_max", 0.0)):
		s["cd_max"] = cd
	return cd / maxf(float(s["cd_max"]), 0.01)

## Slot da barra com o nó "em Cargas": número de cargas prontas no canto e o leque da próxima carga
## (claro enquanto sobra carga; escuro, como a recarga normal, com todas gastas). Sem o nó: leque de sempre.
func _set_charges(p: SimEntity, sk: SkillDef, s: Dictionary, cd: float) -> void:
	var mx := ChargeSystem.max_of(p, sk.id)
	var chg: Label = s.get("chg")
	if mx <= 1:
		if chg and chg.text != "":
			chg.text = ""
		s["sweep"].set_color(CD_SWEEP_DARK)
		s["sweep"].set_frac(_cd_frac(s, cd))
		return
	var n := ChargeSystem.available(p, sk.id)
	var nx := ChargeSystem.next_charge(p, sk.id)
	var txt := str(n)
	if chg and chg.text != txt:
		chg.text = txt
	s["sweep"].set_color(CD_SWEEP_DARK if n <= 0 else CD_SWEEP_CHARGE)
	s["sweep"].set_frac(nx.x / maxf(nx.y, 0.01) if nx.x > 0.0 else 0.0)

const CD_SWEEP_DARK := Color(0, 0, 0, 0.62)
const CD_SWEEP_CHARGE := Color(0, 0, 0, 0.3)

func _cd_text(cd: float) -> String:
	return "%.1f" % cd if cd < 3.0 else str(ceili(cd))

func _refresh_hotbar_names() -> void:
	var p: SimEntity = Sim.player
	if p == null:
		return
	for i in range(skill_slots.size()):
		var s: Dictionary = skill_slots[i]
		var sk: SkillDef = p.skills[i] if i < p.skills.size() else null
		s["root"].tooltip_text = sk.name if sk else ""
		s["lv"].text = "M%d" % p.mastery_of(sk.id) if sk else ""

func _unhandled_input(event: InputEvent) -> void:
	if not root.visible or Sim.player == null:
		return
	if event.is_action_pressed("ui_chat") and not _chat_focus:
		chat_input.grab_focus()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and world_map != null:
		toggle_world_map()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if _chat_focus:
			chat_input.release_focus()
		elif game_menu:
			close_game_menu()
		elif npc_ui.is_open():
			npc_ui.close()
		elif windows_script.is_open():
			windows_script.close_all()
		else:
			open_game_menu()                 # nada aberto: Esc abre o menu
		_update_blocking()
		return
	if _chat_focus:
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_M:
		toggle_world_map()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_inventory"): windows_script.toggle("inventory")
	elif event.is_action_pressed("ui_character"): windows_script.toggle("character")
	elif event.is_action_pressed("ui_skills"): windows_script.toggle("skills")
	elif event.is_action_pressed("ui_book"): windows_script.toggle("book")
	elif event.is_action_pressed("ui_quests"): windows_script.toggle("quests")
	elif event.is_action_pressed("ui_party"): windows_script.toggle("party")
	_update_blocking()

## Mapa em tela cheia (M): o minimapa em modo grande, norte para cima, mapa inteiro, portais com nome. M ou Esc fecha.
var world_map: Control = null

func toggle_world_map() -> void:
	if world_map != null:
		world_map.queue_free()
		world_map = null
		return
	var vp := get_viewport().get_visible_rect().size
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.04, 0.78)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(box)
	var def: MapDef = GameData.maps.get(Sim.player.map_id)
	var title := UiKit.label("%s  (Lv %d-%d)" % [def.name, def.level_range.x, def.level_range.y] if def else "Mapa", 22, UiKit.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var mm := Minimap.new()
	mm.big = true
	mm.side = floorf(minf(vp.x, vp.y) * 0.84)
	mm.hud = self
	mm.camera = main.camera
	mm.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(mm)
	mm.set_map(def)
	var hint := UiKit.label("M ou Esc fecha · ➜ portais · ! ? quests · losango azul = cristal · vermelho = monstros · verde = seu grupo", 13, UiKit.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	world_map = shade

func _update_blocking() -> void:
	if main and main.controller:
		main.controller.ui_blocking = _chat_focus or npc_ui.is_open() or (death_panel != null) or (game_menu != null) or (act_end_panel != null)

# ---------------------------------------------------------------------------
func _notify(text: String) -> void:
	if _boss_line(text):
		return
	if text.begins_with(NEW_SKILL_PREFIX) and _new_skill_toast(text):
		return
	var l := UiKit.label(text, 16, Color(1, 0.95, 0.75))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif_box.add_child(l)
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)
	if notif_box.get_child_count() > 5:
		notif_box.get_child(0).queue_free()

const NEW_SKILL_PREFIX := "Nova skill: "     # aviso da sim no level-up (ProgressionSystem.gain_xp)

## Skill nova do nível: cartão com o ícone, o nome e onde ela ficou (tecla da barra, ou "arraste da janela K").
## Devolve false se o nome não bate com uma skill do jogador (aí vira o aviso de texto comum).
func _new_skill_toast(text: String) -> bool:
	var p: SimEntity = Sim.player
	if p == null or p.class_def == null:
		return false
	var nm := text.trim_prefix(NEW_SKILL_PREFIX).get_slice(" (", 0)
	var sk: SkillDef = null
	for sid in p.class_def.skill_ids:
		if GameData.skills.has(sid) and GameData.skills[sid].name == nm and p.knows(sid):
			sk = GameData.skills[sid]
	if sk == null:
		return false
	var card := UiKit.panel(Color(0.1, 0.08, 0.04, 0.92), UiKit.GOLD)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	h.add_child(UiKit.skill_icon(sk, 36))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	v.add_child(UiKit.label("Nova skill: %s" % sk.name, 16, UiKit.GOLD))
	var slot := p.slot_of(sk.id)
	var where := "Na barra: tecla %s" % ActionBar.key_of(slot) if slot >= 0 else ("Abra a janela K e arraste para a barra" if p.stats.meets(sk.requires) else "Pede outra arma · fica na janela K")
	v.add_child(UiKit.label(where + "  ·  rank no Mestre de Skills", 12, Color(0.85, 0.82, 0.75)))
	notif_box.add_child(card)
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(card, "modulate:a", 0.0, 0.6)
	tw.tween_callback(card.queue_free)
	if notif_box.get_child_count() > 5:
		notif_box.get_child(0).queue_free()
	return true

## Quem fala, se `text` é "<nome>: ..." de um chefe em `names` ("" se não é fala de chefe).
static func boss_speaker(text: String, names: Array) -> String:
	for n in names:
		if text.begins_with(str(n) + ": "):
			return str(n)
	return ""

## Fala de chefe no mapa do jogador vai para a faixa própria (substitui a anterior, some sozinha).
func _boss_line(text: String) -> bool:
	var p: SimEntity = Sim.player
	if p == null or boss_banner == null or not Sim.maps.has(p.map_id):
		return false
	var names: Array = []
	for e: SimEntity in Sim.maps[p.map_id]["entities"]:
		if e.kind == SimEntity.Kind.MONSTER and e.monster_def and e.monster_def.is_boss:
			names.append(e.name)
	var who := boss_speaker(text, names)
	if who == "":
		return false
	boss_label.text = text
	boss_banner.visible = true
	boss_banner.modulate.a = 1.0
	_boss_left = BOSS_LINE_TIME
	return true

## Topo central empilhado: barra do chefe → faixa da investida → fala do chefe → notificações. Investida no mapa
## de um chefe não cobre mais a barra (cada faixa desce para baixo da que está visível acima dela).
func _stack_top_lane() -> void:
	var y := 0.0
	if boss_bar.visible:
		y = boss_bar.offset_top + boss_bar.size.y + LANE_GAP
	var rt := maxf(RAID_TOP, y)
	if raid_banner.offset_top != rt:
		raid_banner.offset_top = rt
		raid_banner.offset_bottom = rt + RAID_H
	if raid_banner.visible:
		y = rt + maxf(RAID_H, raid_banner.size.y) + LANE_GAP     # o texto pode crescer a faixa
	boss_banner.offset_top = maxf(BOSS_LANE_TOP, y)
	if boss_banner.visible:
		y = boss_banner.offset_top + boss_banner.size.y + LANE_GAP
	notif_box.offset_top = maxf(NOTIF_TOP, y)

## Retângulos da HUD (tela) onde nome do mundo não aparece: quadro do personagem, barra, chat, minimapa, quests, faixas.
func label_blockers() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if root == null or not root.visible:
		return out
	var cs: Array[Control] = [player_frame, action_bar, minimap, boss_banner, raid_banner, boss_bar]
	if quest_tracker:
		cs.append(quest_tracker.get_parent() as Control)
	if chat_log:
		var up: Node = chat_log
		while up and not (up is PanelContainer):
			up = up.get_parent()
		cs.append(up as Control)
	for c in cs:
		if c and c.is_visible_in_tree():
			out.append(c.get_global_rect().grow(4.0))
	return out

## Ponto da tela por baixo de algum retângulo da HUD. O nome cresce para cima do ponto (alinhado embaixo):
## confere também `LABEL_UP` px acima.
const LABEL_UP := 22.0
static func covered(pt: Vector2, rects: Array[Rect2]) -> bool:
	var up := pt - Vector2(0, LABEL_UP)
	for r in rects:
		if r.has_point(pt) or r.has_point(up):
			return true
	return false

## Item novo na bolsa do jogador: linha com a arte, o nome na cor da raridade e a quantidade (o mesmo item soma).
func _on_item_gained(entity_id: int, item_id: String, count: int) -> void:
	if Sim.player == null or entity_id != Sim.player.id or Time.get_ticks_msec() < _loot_from_ms:
		return
	var it: ItemDef = GameData.items.get(item_id)
	if it == null:
		return
	var e: Dictionary = _loot_rows.get(item_id, {})
	if e.is_empty() or not is_instance_valid(e["row"]):
		var row := PanelContainer.new()
		var sb := UiKit.panel_style(Color(0.06, 0.05, 0.09, 0.82), UiKit.rarity_color(it.rarity).darkened(0.35), 6, 1)
		sb.set_content_margin_all(3)
		sb.content_margin_right = 10
		row.add_theme_stylebox_override("panel", sb)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(h)
		h.add_child(UiKit.item_icon(it, 34))
		var l := UiKit.label("", 14, UiKit.rarity_color(it.rarity))
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size_flags_vertical = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		loot_box.add_child(row)
		e = {"row": row, "label": l, "count": 0, "tween": null, "name": it.name}
		_loot_rows[item_id] = e
		row.modulate.a = 0.0
		create_tween().tween_property(row, "modulate:a", 1.0, 0.18)
		while loot_box.get_child_count() > 5:       # só as 5 últimas
			var old := loot_box.get_child(0)
			loot_box.remove_child(old)
			old.queue_free()
	e["count"] = int(e["count"]) + count
	(e["label"] as Label).text = "%s  ×%d" % [e["name"], e["count"]] if int(e["count"]) > 1 else str(e["name"])
	if e["tween"] != null and (e["tween"] as Tween).is_valid():
		(e["tween"] as Tween).kill()
	var row_n: Control = e["row"]
	row_n.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(3.2)
	tw.tween_property(row_n, "modulate:a", 0.0, 0.6)
	tw.tween_callback(_drop_loot_row.bind(item_id))
	e["tween"] = tw

func _drop_loot_row(item_id: String) -> void:
	var e: Dictionary = _loot_rows.get(item_id, {})
	_loot_rows.erase(item_id)
	if not e.is_empty() and is_instance_valid(e["row"]):
		(e["row"] as Node).queue_free()

func _on_chat(sender: String, text: String, channel: String) -> void:
	var col := "#9ad0ff"
	var tag := ""
	if channel == "system":
		col = "#ffd966"
	elif channel == "party":
		col = "#7dff9a"
		tag = "[Grupo] " if sender != "Grupo" else ""
	elif channel == "whisper":
		col = "#ff9de2"
		tag = "[Sussurro] "
	elif Sim.player and sender == Sim.player.name:
		col = "#ffe9a8"
	chat_log.append_text("[color=%s][b]%s%s:[/b][/color] %s\n" % [col, tag, sender, text.replace("[", "[lb]")])

func _on_chat_submit(text: String) -> void:
	chat_input.text = ""
	chat_input.release_focus()
	if text.strip_edges() == "" or Sim.player == null:
		return
	if text.begins_with("/"):
		_chat_command(text.strip_edges())
		return
	Events.chat_message.emit(Sim.player.name, text, "global")
	# bots "respondem" de vez em quando
	if randf() < 0.5:
		var bots: Array = []
		for e in Sim.entities.values():
			if e.kind == SimEntity.Kind.BOT:
				bots.append(e)
		if bots.size() > 0:
			var b: SimEntity = bots[randi() % bots.size()]
			var reply: String = ["oi %s" % Sim.player.name, "kkkk", "verdade", "bora?", "tb acho", "?", "gg", "qual seu lvl?", "to na campina se quiser vir"][randi() % 9]
			get_tree().create_timer(randf_range(1.5, 4.0)).timeout.connect(func(): Events.chat_message.emit(b.name, reply, "global"))

## Quest que a seta amarela do minimapa segue: a escolhida no rastreador, senão a aceita por último.
func tracked_quest() -> String:
	var p: SimEntity = Sim.player
	if p == null or p.quests_active.is_empty():
		return ""
	if p.quests_active.has(tracked_quest_id):
		return tracked_quest_id
	return p.quests_active.keys()[-1]

func _on_quest_accepted(id: int, qid: String) -> void:
	if Sim.player and id == Sim.player.id:
		tracked_quest_id = qid
		var q: QuestDef = GameData.quests.get(qid)
		if q and q.repeatable:
			_notify("Quest repetível aceita: %s" % q.title)
	refresh_quest_tracker()

func _on_track_clicked(meta: Variant) -> void:
	tracked_quest_id = str(meta)
	refresh_quest_tracker()

## Quests visíveis no painel; da 6ª em diante o painel rola (roda do mouse). A rastreada vem sempre primeiro.
const QUEST_ROWS := 5

func refresh_quest_tracker() -> void:
	var p: SimEntity = Sim.player
	if p == null:
		return
	var t := "[b][color=#ffd966]Quests[/color][/b]  [color=#888](clique = seta%s)[/color]\n" % (", role" if p.quests_active.size() > QUEST_ROWS else "")
	if p.quests_active.is_empty():
		t = "[b][color=#ffd966]Quests[/color][/b]\n[color=#888]Nenhuma. Fale com NPCs [Quest].[/color]"
	var tracked := tracked_quest()
	var order: Array = p.quests_active.keys()
	if order.has(tracked):
		order.erase(tracked)
		order.push_front(tracked)
	var para := 1                          # parágrafo (linha do texto) em que cada quest começa; 0 = cabeçalho
	var cut := -1                          # parágrafo da 1ª quest que fica escondida (rolar)
	var shown := 0
	for qid in order:
		if shown == QUEST_ROWS:
			cut = para
		shown += 1
		var q: QuestDef = GameData.quests[qid]
		var prog := QuestSystem.progress(p, q)
		var done := prog >= q.count
		var col := "#9f9" if done else ("#ffd966" if qid == tracked else "#eee")
		var rep := "  [color=#59bfff]↻ repetível[/color]" if q.repeatable else ""
		t += "[url=%s][color=%s]%s%s[/color][/url]  %d/%d%s%s\n" % [qid, col, "▶ " if qid == tracked else "", q.title, prog, q.count, rep, "  ✔ entregar" if done else ""]
		para += 1
		if not done:
			t += "   [color=#888]%s[/color]\n" % q.map_hint
			para += 1
	var keep: float = quest_tracker.get_v_scroll_bar().value      # progresso de quest refaz o texto: a rolagem fica onde estava
	quest_tracker.text = t
	quest_tracker.fit_content = cut < 0
	quest_tracker.scroll_active = cut >= 0
	if cut < 0:
		quest_tracker.custom_minimum_size.y = 20
	else:
		_size_quest_tracker.call_deferred(cut, keep)

## Altura do painel = até o começo da 6ª quest (parágrafo `cut`), depois do texto montado; devolve a rolagem.
func _size_quest_tracker(cut: int, keep: float) -> void:
	if quest_tracker == null or quest_tracker.fit_content:
		return
	var h: float = quest_tracker.get_paragraph_offset(cut) if cut < quest_tracker.get_paragraph_count() else quest_tracker.get_content_height()
	quest_tracker.custom_minimum_size.y = ceilf(h) + 2.0
	quest_tracker.size.y = quest_tracker.custom_minimum_size.y
	quest_tracker.get_v_scroll_bar().value = keep

# ---------------------------------------------------------------------------
## Perto de um ponto de colheita: mostra a tecla; colhendo: mostra o progresso.
## Faixa da investida: quantos ainda de pé e onde estão; antes dela, a contagem dos últimos RAID_WARN s.
const RAID_WARN := 30.0
const RAID_PHASE := {"march": "marchando para o povoado", "walls": "nas muralhas!", "retreat": "recuando"}

func _update_raid_banner(p: SimEntity) -> void:
	raid_banner.visible = false
	var rs: Dictionary = Sim.raid_status(p.map_id)
	if rs.is_empty():
		return
	if rs["active"]:
		var tag: String = (" nv %d" % int(rs["level"])) if int(rs["level"]) > 0 else ""
		raid_label.text = "Investida%s: %d de %d inimigos %s" % [tag, rs["alive"], rs["total"], RAID_PHASE.get(rs["phase"], "")]
		raid_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4) if rs["phase"] == "walls" else Color(1.0, 0.82, 0.55))
		raid_banner.visible = true
	elif float(rs["next_in"]) <= RAID_WARN:
		raid_label.text = "Trompas ao longe: investida em %d s" % ceili(float(rs["next_in"]))
		raid_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
		raid_banner.visible = true

func _update_gather_prompt(p: SimEntity) -> void:
	if gather_label == null:
		return
	if p.gather_left > 0.0:
		var k := 1.0 - p.gather_left / Balance.GATHER_TIME
		gather_label.text = "Colhendo %s %s" % ["▮".repeat(int(k * 10.0)), "▯".repeat(10 - int(k * 10.0))]
		return
	var node := Sim.nearest_gather(p)
	gather_label.text = "" if node.is_empty() else "[F] Colher %s" % GameData.items[node["item"]].name

func _on_dialog(npc_id: String) -> void:
	npc_ui.open(npc_id)
	_update_blocking()

func _on_died(id: int, _k: int) -> void:
	if Sim.player and id == Sim.player.id:
		death_panel = UiKit.panel(Color(0.2, 0.02, 0.04, 0.85), Color(0.8, 0.2, 0.2))
		death_panel.set_anchors_preset(Control.PRESET_CENTER)
		death_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		death_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
		var v := VBoxContainer.new()
		v.add_child(UiKit.label("Você morreu", 32, Color(1, 0.4, 0.4)))
		var home: String = GameData.maps[PortalSystem.home_of(Sim.player)["map"]].name      # cristal vinculado ou a cidade inicial
		v.add_child(UiKit.label("Renascendo %s... (-%d%% XP)" % [BotsCatalog.place_words(home)["em"], roundi(Balance.DEATH_XP_PENALTY * 100.0)], 14))
		death_panel.add_child(v)
		root.add_child(death_panel)
		_update_blocking()

## Entregou o epílogo ao Ancião Ravi: tela de fim do Ato I (e do MVP). O jogo continua depois.
func _on_act_quest(id: int, qid: String) -> void:
	if Sim.player and id == Sim.player.id and qid == MapsCatalog.ACT_END_QUEST:
		show_act_end()
	elif Sim.player and id == Sim.player.id and qid == MapsCatalog.ACT2_END_QUEST:
		show_act_end(2)
	elif Sim.player and id == Sim.player.id and qid == MapsCatalog.ACT3_END_QUEST:
		show_act_end(3)

## Texto da tela de fim de ato: [título, subtítulo, história (%s = nome), agradecimento, depois].
const ACT_END_TEXT := {
	1: ["FIM DO ATO I", "A Noite de Azhar",
		"Do portão de Aldara com uma arma de treino até o trono da Cidadela: a Floresta foi salva do cerco, as três fortalezas voltaram para a Aurora e Azhar, o Lich-Rei, virou pó. A praça canta o nome de %s.",
		"Você completou o MVP do RagnaEx. Obrigado por jogar!", "O mundo continua: caçadas repetíveis, lendários e os chefes esperam por você."],
	2: ["FIM DO ATO II", "A Horda",
		"Da praia da Costa Partida ao trono de Kharzun: o porto ganhou muralha, as Estepes voltaram a ter estrada, os escravos das Minas saíram livres e Durgash, o Grão-Senhor da Guerra, caiu. A Horda largou as armas. Mas ela não subiu a montanha para conquistar: fugia de algo a leste. Porto Esperança canta o nome de %s.",
		"Você completou o Ato II do RagnaEx. Obrigado por jogar!", "O mundo continua: caçadas, lendários de 45, a Prova dos Mestres e os chefes esperam por você."],
	3: ["FIM DO ATO III — PARTE 1", "Manhã em Lumeria",
		"Da garganta leste do Kharzun ao Pavilhão do Jardim Sem Fim: os sinos calaram, as Adegas secaram, a Condessa voltou para o espelho e Vessaline, a Anfitriã do Véu, caiu. Depois de quarenta anos de festa, Lumeria acordou com a vassoura na mão. Mas o Jardim não acaba no Pavilhão, e a dona da coroa vazia ainda tem sede. Hoje Lumeria dorme, e os Lúcidos repetem o nome de %s.",
		"Você completou a Parte 1 do Ato III do RagnaEx. Obrigado por jogar!", "O mundo continua: a raide do Eco de Amarante, lendários de 50, os chefes do Excesso e o Conservatório esperam por você."],
}

func show_act_end(act: int = 1) -> void:
	if act_end_panel or Sim.player == null:
		return
	if npc_ui.is_open():
		npc_ui.close()
	var p: SimEntity = Sim.player
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	act_end_panel = dim
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := UiKit.panel(Color(0.08, 0.07, 0.12, 0.96), UiKit.GOLD)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.custom_minimum_size.x = 560
	panel.add_child(v)
	var txt: Array = ACT_END_TEXT.get(act, ACT_END_TEXT[1])
	for row in [[txt[0], 38, UiKit.GOLD], [txt[1], 18, UiKit.TEXT]]:
		var l := UiKit.label(row[0], row[1], row[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	var story := UiKit.label(str(txt[2]) % p.name, 14, UiKit.TEXT)
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(story)
	var stats := UiKit.label("%s — %s Lv.%d   ·   %d quests concluídas   ·   %d de ouro" % [p.name, p.class_def.name if p.class_def else "", p.level, p.quests_completed.size(), p.gold], 13, UiKit.MUTED)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(stats)
	var thanks := UiKit.label(str(txt[3]), 15, UiKit.GOLD)
	thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(thanks)
	var after := UiKit.label(str(txt[4]), 12, UiKit.MUTED)
	after.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(after)
	var btn := UiKit.button("Continuar jogando", close_act_end, 220)
	var bc := CenterContainer.new()
	bc.add_child(btn)
	v.add_child(bc)
	Sfx.ui("level_up")
	_update_blocking()

func close_act_end() -> void:
	if act_end_panel:
		act_end_panel.queue_free()
		act_end_panel = null
	_update_blocking()

func _on_respawned(id: int) -> void:
	if Sim.player and id == Sim.player.id and death_panel:
		death_panel.queue_free()
		death_panel = null
		_update_blocking()

## Menu do Esc: continuar, salvar, salvar e voltar à tela inicial (personagens), salvar e sair.
func open_game_menu() -> void:
	if game_menu or Sim.player == null:
		return
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	game_menu = dim
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := UiKit.panel()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var t := UiKit.title("Menu")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var who := UiKit.label("%s — %s Lv.%d" % [Sim.player.name, Sim.player.class_def.name, Sim.player.level], 12, UiKit.MUTED)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(who)
	for b in [["Continuar", close_game_menu], ["Salvar", _menu_save], ["Salvar e voltar ao menu", _menu_to_title], ["Salvar e sair do jogo", _menu_quit]]:
		var btn := UiKit.button(b[0], b[1], 240)
		btn.add_theme_font_size_override("font_size", 15)
		v.add_child(btn)
	v.add_child(SettingsPanel.create(tips))     # Gráficos, volumes, Dicas (o mesmo painel da tela de título)
	var hint := UiKit.label("O jogo também salva sozinho a cada minuto e ao fechar a janela.", 10, UiKit.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	_update_blocking()

func close_game_menu() -> void:
	if game_menu:
		game_menu.queue_free()
		game_menu = null
	_update_blocking()

func _menu_save() -> void:
	main.save_game()
	close_game_menu()

func _menu_to_title() -> void:
	close_game_menu()
	main.return_to_menu()

func _menu_quit() -> void:
	main.save_game()
	var music: Node = main.get_node_or_null("Music")
	if music and music.has_method("release_streams"):
		music.call("release_streams")           # solta o tema antes de sair (sem "resources still in use")
		await get_tree().process_frame
		await get_tree().process_frame
	get_tree().quit()

# ---------------------------------------------------------------------------
# GRUPO
## Comandos: /party (bots do mapa te convidam) · /convidar <nome> · /sair · /expulsar <nome> · /lider <nome> · /p <texto> (canal do grupo)
func _chat_command(text: String) -> void:
	var p: SimEntity = Sim.player
	var cmd := text.get_slice(" ", 0).to_lower()
	var arg := text.substr(cmd.length()).strip_edges()
	match cmd:
		"/party", "/lfg", "/procurar":
			var n: int = Sim.party_seek_start(p)
			match n:
				-1: _notify("Você já está em um grupo (/sair para procurar outro).")
				-2: _notify("Espere um pouco antes de procurar grupo de novo.")
				0: _notify("Ninguém de nível próximo disponível neste mapa agora.")
				_: _notify("%d jogador(es) vão te convidar. Recuse para ver o próximo." % n)
		"/convidar", "/invite", "/c":
			var t := find_character(arg)
			if t == null:
				_notify("Ninguém chamado \"%s\" online." % arg)
			else:
				Sim.party_invite(p, t)
		"/sair", "/leave":
			if p.party_id < 0:
				_notify("Você não está em um grupo.")
			else:
				Sim.party_leave(p)
		"/expulsar", "/kick":
			var t := find_character(arg)
			if t == null or not Sim.party_kick(p, t):
				_notify("Não foi possível expulsar \"%s\" (só o líder expulsa)." % arg)
		"/lider", "/promote":
			var t := find_character(arg) if arg != "" else p
			if t == p:
				if not Sim.party_take_lead(p):
					_notify("Você já lidera (ou não está em um grupo com um bot líder).")
			elif t == null or not Sim.party_promote(p, t):
				_notify("Não foi possível passar a liderança para \"%s\"." % arg)
		"/p", "/g", "/grupo":
			if p.party_id < 0:
				_notify("Você não está em um grupo.")
			elif arg != "":
				Events.chat_message.emit(p.name, arg, "party")
				_party_reply(arg)
		_:
			_notify("Comandos: /party · /convidar nome · /sair · /expulsar nome · /lider nome · /p texto")

## Jogador ou bot online pelo nome (sem diferenciar maiúsculas).
func find_character(char_name: String) -> SimEntity:
	var want := char_name.to_lower()
	if want == "":
		return null
	for e in Sim.entities.values():
		if e.is_character() and e.name.to_lower() == want:
			return e
	return null

## Um bot do grupo responde no canal do grupo de vez em quando.
func _party_reply(text: String) -> void:
	Sim.party_chat_reply(text)

## Quadros do grupo (sem você): nome, nível, HP/MP; ♛ líder; mapa se estiver longe; cinza se morto.
func refresh_party() -> void:
	if party_box == null:
		return
	for c in party_box.get_children():
		c.queue_free()
	party_frames.clear()
	var p: SimEntity = Sim.player
	if p == null or p.party_id < 0:
		return
	var leader: SimEntity = Sim.party_leader(p)
	for m in Sim.party_members(p):
		if m == p:
			continue
		var fr := UiKit.panel(Color(0.05, 0.05, 0.08, 0.7), m.class_def.color.darkened(0.3) if m.class_def else UiKit.BORDER)
		fr.custom_minimum_size = Vector2(SIDE_W - 70, 0)
		fr.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		party_box.add_child(fr)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		fr.add_child(v)
		var h := HBoxContainer.new()
		v.add_child(h)
		if m.class_def:
			h.add_child(UiKit.class_icon(m.class_def, 18))
		var nm := UiKit.label(("♛ " if m == leader else "") + m.name, 12, Color(0.6, 1.0, 0.65))
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		var info := UiKit.label("", 10, UiKit.MUTED)
		h.add_child(info)
		var hp := UiKit.bar(Color(0.85, 0.25, 0.3), 9)
		var hsh := ShieldOverlay.attach(hp)
		v.add_child(hp)
		var mp := UiKit.bar(Color(0.3, 0.45, 0.95), 4)
		v.add_child(mp)
		party_frames.append({"id": m.id, "frame": fr, "hp": hp, "shield": hsh, "mp": mp, "info": info})
	if leader == p:
		party_box.add_child(UiKit.label("♛ Você lidera (P)", 10, UiKit.MUTED))

func _update_party_frames() -> void:
	for f in party_frames:
		var m: SimEntity = Sim.get_entity(f["id"])
		if m == null:
			continue
		f["hp"].max_value = m.stats.max_hp
		f["hp"].value = m.hp
		f["shield"].set_values(m.hp, m.shield_hp, m.stats.max_hp)
		f["hp"].tooltip_text = ShieldOverlay.hp_text(m.hp, m.stats.max_hp, m.shield_hp)
		f["mp"].max_value = m.stats.max_mp
		f["mp"].value = m.mp
		var where := ""
		if m.map_id != Sim.player.map_id and Sim.maps.has(m.map_id):
			where = "  · " + Sim.map_def(m.map_id).name
		f["info"].text = ("✝ " if not m.is_alive() else "") + "%s %d%s" % [m.class_def.name if m.class_def else "", m.level, where]
		f["frame"].modulate.a = 0.55 if not m.is_alive() or m.map_id != Sim.player.map_id else 1.0

func _on_party_invited(from_id: int, to_id: int) -> void:
	if Sim.player == null or to_id != Sim.player.id:
		return
	var from: SimEntity = Sim.get_entity(from_id)
	if from == null:
		return
	_close_invite()
	invite_from = from_id
	var pn := UiKit.panel(Color(0.08, 0.07, 0.12, 0.95), UiKit.GOLD)
	pn.anchor_left = 0.5; pn.anchor_right = 0.5
	pn.offset_left = -190; pn.offset_right = 190; pn.offset_top = 210
	root.add_child(pn)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pn.add_child(v)
	var t := UiKit.label("%s (%s Lv.%d) convida você para o grupo." % [from.name, from.class_def.name if from.class_def else "", from.level], 14, UiKit.TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	h.add_child(UiKit.button("Aceitar", answer_invite.bind(true), 110))
	h.add_child(UiKit.button("Recusar", answer_invite.bind(false), 110))
	invite_panel = pn
	get_tree().create_timer(Balance.PARTY_INVITE_TIME).timeout.connect(_invite_expired.bind(from_id))

func _invite_expired(from_id: int) -> void:
	if invite_from == from_id:
		_close_invite()

func answer_invite(yes: bool) -> void:
	if Sim.player == null:
		return
	if yes:
		if not Sim.party_accept(Sim.player):
			_notify("O convite expirou.")
	else:
		Sim.party_decline(Sim.player)
	_close_invite()

func _close_invite() -> void:
	if invite_panel and is_instance_valid(invite_panel):
		invite_panel.queue_free()
	invite_panel = null
	invite_from = -1

