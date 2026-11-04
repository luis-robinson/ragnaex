class_name FormModel
extends Node3D
## Forma de animal do Druida (lobo/urso): assets/models/form_<forma>.glb com a armadura de animal de cada conjunto
## (malhas frm_<estilo>_<slot>_<osso>). Mostra as peças dos slots equipados, pintadas pela cor do item (como o KitModel).

const LOOPS := ["idle", "walk", "run"]
var anim: AnimationPlayer = null
var skeleton: Skeleton3D = null
var mats: Array = []                 # materiais toon (hit flash)
var _tints: Dictionary = {}          # nome do nó -> [ShaderMaterial "tint"]
var _accents: Dictionary = {}        # nome do nó -> [ShaderMaterial "tint2"]
var _pieces: Array = []              # MeshInstance3D frm_*

static func path_for(form: String) -> String:
	return "res://assets/models/form_%s.glb" % form

static func exists(form: String) -> bool:
	return form != "" and ResourceLoader.exists(path_for(form))

static func create(form: String) -> FormModel:
	if not exists(form):
		return null
	return create_from(path_for(form))

## Qualquer bicho animado com toon (forma do Druida, cavalo de montaria).
static func create_from(path: String) -> FormModel:
	if not ResourceLoader.exists(path):
		return null
	var f := FormModel.new()
	f.name = "Form"
	var inst: Node = (load(path) as PackedScene).instantiate()
	f.add_child(inst)
	f.anim = f._find_anim(inst)
	var sks := inst.find_children("*", "Skeleton3D", true, false)
	f.skeleton = sks[0] if sks.size() > 0 else null
	if f.anim:
		for a in LOOPS:
			if f.anim.has_animation(a):
				f.anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	f._toon(inst)
	return f

## Pinta todas as superfícies "tint" (pelagem do cavalo).
func paint(col: Color) -> void:
	for lst in _tints.values():
		for m in lst:
			m.set_shader_parameter("albedo", col)

## Quanto o osso saiu do repouso, em coordenadas globais (o cavaleiro acompanha o lombo do cavalo).
func bone_delta(bone: String) -> Transform3D:
	if skeleton == null:
		return Transform3D.IDENTITY
	var i := skeleton.find_bone(bone)
	if i < 0:
		return Transform3D.IDENTITY
	var d := skeleton.get_bone_global_pose(i) * skeleton.get_bone_global_rest(i).affine_inverse()
	var g := skeleton.global_transform
	return g * d * g.affine_inverse()

func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r:
			return r
	return null

func _toon(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.name.begins_with("frm_"):
			_pieces.append(mi)
		for i in range(mi.get_surface_override_material_count()):
			var base := mi.get_active_material(i)
			var col: Color = base.albedo_color if base is BaseMaterial3D else Color(0.8, 0.8, 0.8)
			var tm := Materials.toon_unique(col)
			tm.set_shader_parameter("paint", 1.0)
			if base is BaseMaterial3D and base.emission_enabled:
				tm.set_shader_parameter("emission_amount", minf(base.emission_energy_multiplier, 2.0))
			mi.set_surface_override_material(i, tm)
			mats.append(tm)
			var nm := base.resource_name if base else ""
			if nm == "tint":
				if not _tints.has(mi.name):
					_tints[mi.name] = []
				_tints[mi.name].append(tm)
			elif nm == "tint2":
				if not _accents.has(mi.name):
					_accents[mi.name] = []
				_accents[mi.name].append(tm)
	for c in n.get_children():
		_toon(c)

## Liga as peças de animal dos slots equipados (estilo de conjunto) e pinta pela cor do item.
func apply_equipment(eq: Dictionary) -> void:
	var shown := {}            # prefixo frm_<estilo>_<slot>_ -> cor
	for pair in [["head", ItemDef.Slot.HEAD], ["body", ItemDef.Slot.BODY], ["gloves", ItemDef.Slot.GLOVES], ["boots", ItemDef.Slot.BOOTS]]:
		var it: ItemDef = eq.get(pair[1])
		if it and it.armor_style != "":
			shown["frm_%s_%s_" % [it.armor_style, pair[0]]] = it.icon_color
	for mi in _pieces:
		var vis := false
		var col := Color.WHITE
		for prefix in shown:
			if String(mi.name).begins_with(prefix):
				vis = true
				col = shown[prefix]
		mi.visible = vis
		if vis:
			for m in _tints.get(mi.name, []):
				m.set_shader_parameter("albedo", col)
			for m in _accents.get(mi.name, []):
				m.set_shader_parameter("albedo", ItemDef.accent(col))

## Nomes das peças de animal de um estilo (testes).
func pieces_of(style: String) -> Array:
	return _pieces.filter(func(mi): return String(mi.name).begins_with("frm_%s_" % style))
