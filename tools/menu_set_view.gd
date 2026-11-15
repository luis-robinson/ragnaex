extends Node
## Revisão do cenário da tela inicial sem a cena de início (spec `design/ux/start-flow.md` §3, §11):
##   godot --path . tools/menu_set_view.tscn -- --menu_set_shot=<png abs> [--shot_cam=title|list|create] [--settings] [--class=<id>]
## create: boneco do kit (classe, equipamento inicial, idle) no pedestal. --settings: abre o painel de Configurações por cima.
## Sem --menu_set_shot fica aberto (olhar/girar a janela à mão); headless sai depois de montar.

const WAIT := 1.4                    # s até a foto (fagulhas no ar, tremor da luz)

var set3d: MenuSet
var _shot := ""

func _ready() -> void:
	GraphicsSettings.load_and_apply(get_viewport())
	AudioSettings.load_and_apply()
	_shot = DevArgs.value("--menu_set_shot")
	var cam := StringName(DevArgs.value("--shot_cam", "title"))
	set3d = MenuSet.new()
	add_child(set3d)
	add_child(MenuAudio.create())
	set3d.go_to(cam, true)
	var sd := DevArgs.value("--menu_sun")        # experimentar: de onde vem o sol (Godot, x,y,z)
	if sd != "":
		var v := Vector3(float(sd.get_slice(",", 0)), float(sd.get_slice(",", 1)), float(sd.get_slice(",", 2))).normalized()
		set3d.sun.basis = Basis.looking_at(-v, Vector3.UP)
	print("MENU_SET_VIEW sol -z=%s sombra=%s energia=%.2f" % [-set3d.sun.global_basis.z, set3d.sun.shadow_enabled, set3d.sun.light_energy])
	if cam == &"create" or cam == &"list":
		var cls: ClassDef = GameData.classes.get(DevArgs.value("--class", "paladin"), GameData.classes["paladin"])
		var k := KitModel.create(cls.body_type, cls.hair_color, 0.025, cls.id)
		if k:
			set3d.place_character(k)
			var eq := {}
			for iid in cls.starting_equipment:
				eq[GameData.items[iid].slot] = GameData.items[iid]
			k.apply_equipment(eq)
			if k.anim:
				k.anim.play(k.resolve("idle"))
	if DevArgs.has("--settings"):
		var ui := CanvasLayer.new()
		ui.layer = 20
		add_child(ui)
		var c := Control.new()
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		ui.add_child(c)
		SettingsPanel.overlay(c)
	print("MENU_SET_VIEW shot=%s cam=%s pos=%s char=%s" % [_shot, set3d.current_shot(), set3d.camera.global_position, set3d.character() != null])
	if DisplayServer.get_name() == "headless":
		get_tree().quit()
		return
	if _shot != "":
		await get_tree().create_timer(WAIT).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_shot)
		print("MENU_SET_VIEW salvo %s" % _shot)
		get_tree().quit()
