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
			var key := mat_key(m)
			if not groups.has(key):
				groups[key] = [m, []]
				order.append(key)
			groups[key][1].append([mi.mesh, si, at_rest, bone, sources.size()])
		sources.append(mi)
	if sources.size() < 2:
		return null
	var sig := ""
	if cache_key != "":
		var parts: Array = []
		for key in order:
			parts.append(",".join(groups[key][1].map(func(q): return "%d.%d" % [q[4], q[1]])))
		sig = cache_key + "#" + "|".join(parts)
		if _cache.has(sig):
			var hit: Array = _cache[sig]
			return _attach(sk, hit[0], hit[1], order.map(func(k): return groups[k][0]), sources)
	var am := ArrayMesh.new()
	for key in order:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var ranges: Array = []       # [nº de vértices, osso] por peça, na ordem do append
		for part in groups[key][1]:
			st.append_from(part[0], part[1], part[2])
			var vn: int = (part[0] as Mesh).surface_get_arrays(part[1])[Mesh.ARRAY_VERTEX].size()
			ranges.append([vn, part[3]])
		var arrs := st.commit_to_arrays()
		var total: int = (arrs[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var bones := PackedInt32Array()
		for r in ranges:
			var b := PackedInt32Array()
			b.resize(int(r[0]) * 4)
			b.fill(int(r[1]))               # peso 0 nos outros 3: o índice não importa
			bones.append_array(b)
		if bones.size() != total * 4:
			return null                     # append_from mudou a contagem (não deveria): não arrisca
		arrs[Mesh.ARRAY_BONES] = bones
		arrs[Mesh.ARRAY_WEIGHTS] = _ones(total)
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
	var skin := Skin.new()
	for b in range(sk.get_bone_count()):
		skin.add_bind(b, sk.get_bone_global_rest(b).affine_inverse())
	if sig != "":
		_cache[sig] = [am, skin]
	return _attach(sk, am, skin, order.map(func(k): return groups[k][0]), sources)

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

## Materiais iguais (mesma cor, brilho, sombra, contorno) dividem a superfície.
static func mat_key(m: Material) -> String:
	if not (m is ShaderMaterial):
		return "o%d" % m.get_instance_id()
	var sm := m as ShaderMaterial
	var col = sm.get_shader_parameter("albedo")
	var tex = sm.get_shader_parameter("albedo_tex")
	return "%s|%s|%s|%s|%s|%d|%d" % [str(col), str(sm.get_shader_parameter("spec_strength")), str(sm.get_shader_parameter("emission_amount")),
		str(sm.get_shader_parameter("shadow_strength")), str(sm.get_shader_parameter("rim_strength")), 1 if sm.next_pass else 0,
		tex.get_instance_id() if tex else 0]
