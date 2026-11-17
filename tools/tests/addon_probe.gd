extends Node
## Kit extra (KitModel.load_addon): custo de vestir pela 1ª vez uma peça do kit_<classe>_<sexo>_a2.glb e das seguintes.
##   godot --path . tools/tests/addon_probe.tscn   (com janela: o custo real inclui subir as malhas para a GPU; imprime COST ...)
## Mede o custo de vestir pela 1ª vez uma peça do kit extra (ler o arquivo + anexar) e das vezes seguintes.

func _ready() -> void:
	_run.call_deferred()

func _eq(gd: Node, sid: String) -> Dictionary:
	var eq := {}
	for pid in gd.sets[sid].pieces:
		var it: ItemDef = gd.items[pid]
		eq[ItemDef.Slot.OFFHAND if String(pid).ends_with("_offhand") else it.slot] = it
	return eq

func _run() -> void:
	var gd: Node = GameData
	var root: Node = self
	for i in range(3):
		await get_tree().process_frame
	var e30 := _eq(gd, "set_paladin_guardiao_30")
	var e35 := _eq(gd, "set_paladin_guardiao_35")
	var t := Time.get_ticks_usec()
	var k := KitModel.create("male", Color.WHITE, 0.025, "paladin")
	root.add_child(k)
	print("COST create_main_kit_ms ", (Time.get_ticks_usec() - t) / 1000.0)
	t = Time.get_ticks_usec()
	k.apply_equipment(e30)
	print("COST apply_30_first_ms ", (Time.get_ticks_usec() - t) / 1000.0)
	for i in range(3):
		await get_tree().process_frame
	t = Time.get_ticks_usec()
	k.apply_equipment(e30)
	print("COST apply_30_again_ms ", (Time.get_ticks_usec() - t) / 1000.0)
	t = Time.get_ticks_usec()
	k.apply_equipment(e35)
	print("COST apply_35_first_ms ", (Time.get_ticks_usec() - t) / 1000.0, " (load_addon ", KitModel.addon_last_ms, " ms, loads ", KitModel.addon_loads, ")")
	t = Time.get_ticks_usec()
	await get_tree().process_frame
	await get_tree().process_frame
	print("COST two_frames_after_ms ", (Time.get_ticks_usec() - t) / 1000.0)
	t = Time.get_ticks_usec()
	k.apply_equipment(e35)
	print("COST apply_35_again_ms ", (Time.get_ticks_usec() - t) / 1000.0)
	var k2 := KitModel.create("male", Color.WHITE, 0.025, "paladin")
	root.add_child(k2)
	t = Time.get_ticks_usec()
	k2.apply_equipment(e35)
	print("COST second_kit_apply_35_ms ", (Time.get_ticks_usec() - t) / 1000.0, " (load_addon ", KitModel.addon_last_ms, " ms, loads ", KitModel.addon_loads, ")")
	var k3 := KitModel.create("female", Color.WHITE, 0.025, "paladin")
	root.add_child(k3)
	t = Time.get_ticks_usec()
	k3.apply_equipment(e35)
	print("COST female_first_apply_35_ms ", (Time.get_ticks_usec() - t) / 1000.0, " (load_addon ", KitModel.addon_last_ms, " ms, loads ", KitModel.addon_loads, ")")
	await get_tree().process_frame
	get_tree().quit()
