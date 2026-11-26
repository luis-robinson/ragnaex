class_name GuildHud
extends Control
## Lado social no HUD: convite da guilda (Aceitar/Recusar), aviso de pedido de socorro, aba Guilda do chat
## e revisão das plaquinhas. Ouve os sinais do contrato (wave3-contract §3) só se existirem em Events.

var hud                                  # game/ui/hud.gd
var invite_panel: Control = null
var invite_guild := ""
var _poll_t := 0.0
var _offer_seen := ""                    # estado do convite já tratado (save carregado com convite pendente)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hook(&"guild_invite", on_guild_invite)
	_hook(&"guild_changed", func(_g): on_guild_changed())
	_hook(&"roster_changed", func(): on_roster_changed())
	_hook(&"bot_help_request", on_help_request)
	_hook(&"bot_help_ended", on_help_ended)

func _hook(sig: StringName, f: Callable) -> void:
	if Events.has_signal(sig):
		Events.connect(sig, f)

func _process(delta: float) -> void:
	_poll_t -= delta
	if _poll_t > 0.0:
		return
	_poll_t = 1.0
	if hud and hud.has_method("refresh_chat_tabs"):
		hud.refresh_chat_tabs()
	var o := GuildUi.offer()                 # convite pendente que veio do save: mostra uma vez
	var st := str(o.get("state", "none"))
	if st == "pending" and _offer_seen != "pending" and invite_panel == null:
		on_guild_invite(str(o.get("guild_id", "")), str(o.get("from", "")))
	_offer_seen = st

func on_guild_changed() -> void:
	GuildUi.revision += 1
	_refresh_window()
	if hud and hud.has_method("refresh_chat_tabs"):
		hud.refresh_chat_tabs()

func on_roster_changed() -> void:
	GuildUi.revision += 1
	_refresh_window()

func _refresh_window() -> void:
	if hud and hud.windows_script and hud.windows_script.is_open("guild"):
		hud.windows_script.refresh_window("guild")

## Convite do nível da guilda: caixa no meio da tela.
func on_guild_invite(guild_id: String, from_name: String) -> void:
	close_invite()
	invite_guild = guild_id
	var gi := GuildUi._dict("guild_info", [guild_id])
	var p := UiKit.panel(Color(0.07, 0.06, 0.1, 0.97), UiKit.GOLD)
	p.name = "GuildInvite"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var t := UiKit.label(GuildUi.invite_text(str(gi.get("name", guild_id))), 17, UiKit.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var mem := (gi.get("members", []) as Array).size()
	var sub := UiKit.para("%s convidou você. São %d membros, etiqueta [%s]. Aceitar é opcional: recusando, você pode fundar a sua no quadro de avisos." % [from_name, mem, gi.get("tag", "")], 12, UiKit.TEXT)
	sub.custom_minimum_size = Vector2(380, 0)
	v.add_child(sub)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	var ok := UiKit.button("Aceitar", accept_invite, 120)
	ok.name = "Accept"
	h.add_child(ok)
	var no := UiKit.button("Recusar", refuse_invite, 120)
	no.name = "Refuse"
	h.add_child(no)
	add_child(p)
	p.reset_size()
	var vp := get_viewport_rect().size
	p.position = ((vp - p.size) * Vector2(0.5, 0.32)).floor()
	invite_panel = p
	Sfx.ui("ui_open")

func accept_invite() -> void:
	GuildUi.respond(true)
	close_invite()
	if hud:
		hud._notify("Você entrou na guilda. Abra com %s." % KeyBindings.label("ui_guild"))
	on_guild_changed()

## Recusou: a janela abre na aba Membros, que oferece fundar a própria guilda.
func refuse_invite() -> void:
	GuildUi.respond(false)
	close_invite()
	GuildUi.tab = "members"
	if hud and hud.windows_script and not hud.windows_script.is_open("guild"):
		hud.windows_script.toggle("guild")
	on_guild_changed()

func close_invite() -> void:
	if invite_panel:
		invite_panel.queue_free()
		invite_panel = null

## Pedido de socorro: aviso de uma linha + marca no minimapa.
func on_help_request(req: Dictionary) -> void:
	if hud:
		hud._notify(GuildUi.help_notice(req))
		if hud.minimap:
			hud.minimap.add_help(req)

func on_help_ended(req_id: int, _outcome: String) -> void:
	if hud and hud.minimap:
		hud.minimap.drop_help(req_id)
