class_name RigidMerge
extends RefCounted
## Monstros e cavalo do mob_kit são peças rígidas presas a ossos (BoneAttachment3D): dezenas de malhas = dezenas de
## draw calls por bicho (x2 com o contorno, mais as sombras). Aqui as peças viram UMA malha com pele: cada vértice preso
## ao osso da sua peça com peso 1, e peças de material igual (mesma cor/brilho/contorno) dividem a superfície.
## As peças originais saem da árvore junto com os BoneAttachment3D. Chamar depois de pintar os materiais.

static var enabled := true           # --no_merge desliga (medir)
## Malha fundida por modelo + agrupamento: cavalos e monstros iguais reaproveitam a malha; só os materiais mudam.
static var _cache: Dictionary = {}

static func merge(root: Node, cache_key: String = "") -> MeshInstance3D:
	if not enabled:
		return null
	var sks := root.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return null
	var sk: Skeleton3D = sks[0]
	var groups := {}                 # chave -> [material, [[mesh, surface, xform, bone, nº da peça]]]
	var order: Array = []
	var sources: Array = []
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.skin != null or not mi.visible:
			continue
		# sobe até o BoneAttachment3D somando os transforms locais
		var xf := Transform3D.IDENTITY
		var p: Node = mi
		while p != null and not (p is BoneAttachment3D) and p != sk:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		if not (p is BoneAttachment3D):
			continue
		var bone := sk.find_bone((p as BoneAttachment3D).bone_name)
		if bone < 0:
			continue
		var at_rest := sk.get_bone_global_rest(bone) * xf
		for si in range(mi.mesh.get_surface_count()):
			var m := mi.get_active_material(si)
			if m == null or mi.mesh.surface_get_primitive_type(si) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var key := mat_key(m, _plain_mesh(mi.mesh, si))
			if not groups.has(key):
				groups[key] = [m, []]
				order.append(key)
			groups[key][1].append([mi.mesh, si, at_rest, bone, sources.size(), _vcol_of(m) if key.begins_with("v|") else Color.WHITE])
		sources.append(mi)
	if sources.size() < 2:
		return null
	# assinaturas: forma (que peça/superfície cai em cada grupo) e forma + cores (a cor no vértice muda a malha)
	var shape_sig := ""
	var sig := ""
	if cache_key != "":
		var shape: Array = []
		var cols: Array = []
		for key in order:
			shape.append(",".join(groups[key][1].map(func(q): return "%d.%d" % [q[4], q[1]])))
			cols.append(",".join(groups[key][1].map(func(q): return (q[5] as Color).to_html())))
		shape_sig = cache_key + "#" + "|".join(shape)
		sig = shape_sig + "#" + "|".join(cols)
		if _cache.has(sig):
			var hit: Array = _cache[sig]
			_whiten_groups(groups, order)
			return _attach(sk, hit[0], hit[1], order.map(func(k): return groups[k][0]), sources)
	# geometria (SurfaceTool, o caro) por forma; bicho de outra cor só troca o array de cores
	var geo: Array = _geo_cache.get(shape_sig, []) if shape_sig != "" else []
	if geo.is_empty():
		geo = _build_geometry(sk, groups, order)
		if geo.is_empty():
			return null
		if shape_sig != "":
			_geo_cache[shape_sig] = geo
	var surfs: Array = geo[0]
	var am := ArrayMesh.new()
	for i in order.size():
		var arrs: Array = (surfs[i] as Array).duplicate()     # raso: os Packed*Array são cópia-na-escrita
		if str(order[i]).begins_with("v|"):
			var vc := _group_colors(groups[order[i]][1], (arrs[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
			if vc.is_empty():
				return null                     # contagem diferente (não deveria): não arrisca
			arrs[Mesh.ARRAY_COLOR] = vc
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
	var skin: Skin = geo[1]
	if sig != "":
		_cache[sig] = [am, skin]
	_whiten_groups(groups, order)
	return _attach(sk, am, skin, order.map(func(k): return groups[k][0]), sources)

static var _geo_cache: Dictionary = {}   # forma -> [[arrays por superfície (sem cor)], Skin]

## Junta as peças de cada grupo (SurfaceTool) com o osso de cada peça; [] se a contagem de vértices não bater.
static func _build_geometry(sk: Skeleton3D, groups: Dictionary, order: Array) -> Array:
	var surfs: Array = []
	for key in order:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var ranges: Array = []       # [nº de vértices, osso] por peça, na ordem do append
		for part in groups[key][1]:
			st.append_from(part[0], part[1], part[2])
			ranges.append([_vertex_count(part[0], part[1]), part[3]])
		var arrs := st.commit_to_arrays()
		var total: int = (arrs[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var bones := PackedInt32Array()
		for r in ranges:
			var b := PackedInt32Array()
			b.resize(int(r[0]) * 4)
			b.fill(int(r[1]))               # peso 0 nos outros 3: o índice não importa
			bones.append_array(b)
		if bones.size() != total * 4:
			return []                       # append_from mudou a contagem (não deveria): não arrisca
		arrs[Mesh.ARRAY_BONES] = bones
		arrs[Mesh.ARRAY_WEIGHTS] = _ones(total)
		surfs.append(arrs)
	var skin := Skin.new()
	for b in range(sk.get_bone_count()):
		skin.add_bind(b, sk.get_bone_global_rest(b).affine_inverse())
	return [surfs, skin]

## Vértices da superfície sem copiar os arrays (ArrayMesh); outro tipo de malha: conta pela cópia.
static func _vertex_count(mesh: Mesh, si: int) -> int:
	if mesh is ArrayMesh:
		return (mesh as ArrayMesh).surface_get_array_len(si)
	return (mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()

## Superfície sem cor própria no vértice (ArrayMesh): pode receber a cor da peça.
static func _plain_mesh(mesh: Mesh, si: int) -> bool:
	return mesh is ArrayMesh and (mesh.surface_get_format(si) & Mesh.ARRAY_FORMAT_COLOR) == 0

static func _whiten_groups(groups: Dictionary, order: Array) -> void:
	for k in order:
		if str(k).begins_with("v|"):
			_whiten(groups[k][0])

## Põe a malha fundida no esqueleto (material por instância: cada bicho com a sua cor) e tira as peças da árvore.
static func _attach(sk: Skeleton3D, am: ArrayMesh, skin: Skin, mats: Array, sources: Array) -> MeshInstance3D:
	var out := MeshInstance3D.new()
	out.name = "RigidMerged"
	out.mesh = am
	out.skin = skin
	for i in range(mini(mats.size(), am.get_surface_count())):
		out.set_surface_override_material(i, mats[i])
	sk.add_child(out)
	out.skeleton = NodePath("..")
	# os BoneAttachment3D seguem o osso todo quadro (e arrastam as peças): só com peças já fundidas, saem da árvore
	var merged_set := {}
	for mi in sources:
		merged_set[mi] = true
	for ba in sk.find_children("*", "BoneAttachment3D", true, false):
		var only_merged := true
		for d in ba.find_children("*", "", true, false):
			if d is MeshInstance3D and not merged_set.has(d):
				only_merged = false
			elif not (d is Node3D):
				only_merged = false
		if only_merged:
			ba.get_parent().remove_child(ba)
			ba.queue_free()
	for mi in sources:
		if is_instance_valid(mi) and mi.get_parent() != null:
			(mi as MeshInstance3D).visible = false
	return out

## Pesos [1, 0, 0, 0] repetidos para `n` vértices (dobrando o array: sem laço por vértice).
static func _ones(n: int) -> PackedFloat32Array:
	var w := PackedFloat32Array([1.0, 0.0, 0.0, 0.0])
	while w.size() < n * 4:
		w.append_array(w)
	w.resize(n * 4)
	return w

## Materiais iguais (mesma cor, brilho, sombra, contorno) dividem a superfície. Com a cor no vértice (toon sem textura),
## a cor e o brilho saem da chave: peças de cores diferentes dividem a superfície (ver KitModel._shared_key).
static func mat_key(m: Material, allow_vcol: bool = false) -> String:
	if not (m is ShaderMaterial):
		return "o%d" % m.get_instance_id()
	var sm := m as ShaderMaterial
	var col = sm.get_shader_parameter("albedo")
	var tex = sm.get_shader_parameter("albedo_tex")
	if allow_vcol and _vcol_ok(sm):
		return "v|%s|%s|%s|%d" % [str(sm.get_shader_parameter("emission_amount")), str(sm.get_shader_parameter("shadow_strength")),
			str(sm.get_shader_parameter("rim_strength")), 1 if sm.next_pass else 0]
	return "%s|%s|%s|%s|%s|%d|%d" % [str(col), str(sm.get_shader_parameter("spec_strength")), str(sm.get_shader_parameter("emission_amount")),
		str(sm.get_shader_parameter("shadow_strength")), str(sm.get_shader_parameter("rim_strength")), 1 if sm.next_pass else 0,
		tex.get_instance_id() if tex else 0]

## Toon sem textura: a cor pode ir para o vértice.
static func _vcol_ok(sm: ShaderMaterial) -> bool:
	return KitModel.vcol_merge and sm.shader == Materials.toon_shader() and sm.get_shader_parameter("albedo_tex") == null \
		and sm.get_shader_parameter("albedo") != null

## Cor do vértice da peça: albedo (sRGB) + força do brilho no alfa (como no kit).
static func _vcol_of(m: Material) -> Color:
	var sm := m as ShaderMaterial
	var c: Color = sm.get_shader_parameter("albedo")
	var spec = sm.get_shader_parameter("spec_strength")
	c.a = float(spec) if spec != null else 0.1
	return c

## Superfície de cor no vértice: o 1º material do grupo (próprio deste bicho, já nos _mats do hit flash) vira o branco da fusão.
static func _whiten(m: Material) -> void:
	var sm := m as ShaderMaterial
	sm.set_shader_parameter("albedo", Color.WHITE)
	sm.set_shader_parameter("vcol_srgb", true)

## Cores por vértice de um grupo: uma faixa por peça, na ordem do append ([] se a contagem não bater).
static func _group_colors(parts: Array, total: int) -> PackedColorArray:
	var out := PackedColorArray()
	for p in parts:
		var seg := PackedColorArray()
		seg.resize(_vertex_count(p[0], p[1]))
		seg.fill(p[5])
		out.append_array(seg)
	return out if out.size() == total else PackedColorArray()

## Humanoide de monstro do kit (bandido, elfos, esqueleto): peças com pele no mesmo esqueleto viram uma malha por
## material (como KitModel._remerge). Armas de troca ("wpn_*") ficam de fora: o EntityView liga/desliga elas.
## Só funde se todas as peles têm os mesmos ossos na mesma ordem (índices de osso valem para todas).
static var _skinned_cache: Dictionary = {}

static func merge_skinned(root: Node, cache_key: String = "") -> MeshInstance3D:
	if not enabled:
		return null
	var sks := root.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return null
	var sk: Skeleton3D = sks[0]
	var skin: Skin = null
	var groups := {}
	var order: Array = []
	var sources: Array = []
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.skin == null or not mi.visible or String(mi.name).begins_with("wpn_"):
			continue
		if skin == null:
			skin = mi.skin
		elif not _same_binds(skin, mi.skin):
			return null
		for si in range(mi.mesh.get_surface_count()):
			var m := mi.get_active_material(si)
			if m == null or mi.mesh.surface_get_primitive_type(si) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var key := mat_key(m, _plain_mesh(mi.mesh, si))
			if not groups.has(key):
				groups[key] = [m, []]
				order.append(key)
			groups[key][1].append([mi.mesh, si, null, null, sources.size(), _vcol_of(m) if key.begins_with("v|") else Color.WHITE])
		sources.append(mi)
	if sources.size() < 2:
		return null
	# assinatura: que peça/superfície (e cor, se vai no vértice) cai em cada grupo
	var parts: Array = []
	for key in order:
		parts.append(",".join(groups[key][1].map(func(q): return "%d.%d.%s" % [q[4], q[1], (q[5] as Color).to_html()])))
	var sig := cache_key + "#" + "|".join(parts)
	var am: ArrayMesh = _skinned_cache.get(sig) if cache_key != "" else null
	if am == null:
		am = ArrayMesh.new()
		for key in order:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for p in groups[key][1]:
				st.append_from(p[0], p[1], Transform3D.IDENTITY)
			var arrs := st.commit_to_arrays()
			if key.begins_with("v|"):
				var cols := _group_colors(groups[key][1], (arrs[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
				if cols.is_empty():
					return null                 # contagem diferente (não deveria): não arrisca
				arrs[Mesh.ARRAY_COLOR] = cols
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
		if cache_key != "":
			_skinned_cache[sig] = am
	_whiten_groups(groups, order)
	var out := MeshInstance3D.new()
	out.name = "SkinMerged"
	out.mesh = am
	out.skin = skin
	for i in range(mini(order.size(), am.get_surface_count())):
		out.set_surface_override_material(i, groups[order[i]][0])
	sk.add_child(out)
	out.skeleton = NodePath("..")
	for mi in sources:
		mi.get_parent().remove_child(mi)
		mi.queue_free()
	return out

static func _same_binds(a: Skin, b: Skin) -> bool:
	if a == b:
		return true
	if a.get_bind_count() != b.get_bind_count():
		return false
	for i in range(a.get_bind_count()):
		if a.get_bind_name(i) != b.get_bind_name(i) or a.get_bind_bone(i) != b.get_bind_bone(i) or not a.get_bind_pose(i).is_equal_approx(b.get_bind_pose(i)):
			return false
	return true
