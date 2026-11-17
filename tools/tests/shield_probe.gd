class_name ShieldProbe
extends RefCounted
## Medidas dos escudos no motor (usadas por _check_tall_shields e por tools/tests/shield_probe.tscn):
##  - ponto mais baixo de cada escudo em cada clipe, antes e depois da ponta que encolhe (ShieldGround);
##  - arestas do escudo que atravessam a montaria na guarda montada.
## Tudo com a malha inteira do escudo (não os candidatos do ShieldGround): é a conferência dele.

## Escudos do kit: estilo -> MeshInstance3D (dentro ou fora da árvore).
static func shields_of(kit: KitModel) -> Dictionary:
	var out := {}
	for mi in kit.pieces("wpn_off_shield_*"):
		out[String(mi.name).trim_prefix("wpn_off_shield_")] = mi
	return out

## Põe o esqueleto do kit no instante `t` do clipe (o kit tem de estar na árvore).
static func pose(kit: KitModel, clip: String, t: float) -> void:
	kit.anim.play(clip)
	kit.anim.seek(t, true)
	kit.anim.pause()

## Ponto mais baixo (y do mundo, relativo ao chão `floor_y`) de cada escudo de `styles` em cada clipe de `clips`,
## amostrando `samples` instantes: {estilo: {clipe: [antes, depois, subida do osso]}} (o pior instante de cada clipe).
static func ground_lows(kit: KitModel, styles: Array, clips: Array, samples: int = 8, floor_y: float = 0.0) -> Dictionary:
	var sk := kit.skeleton
	var arm := sk.find_bone(ShieldGround.ARM_BONE)
	var meshes := shields_of(kit)
	var data := {}
	var quick := {}          # os candidatos que o jogo usa: a subida sai deles, a conferência é na malha inteira
	for st in styles:
		if meshes.has(st):
			var mi: MeshInstance3D = meshes[st]
			data[st] = ShieldGround.data_for(mi.mesh, mi.skin, sk, true)
			quick[st] = ShieldGround.data_for(mi.mesh, mi.skin, sk)
	var out := {}
	for clip in clips:
		if not kit.anim.has_animation(clip):
			continue
		var len := kit.anim.get_animation(clip).length
		for i in range(samples):
			pose(kit, clip, len * i / float(samples))
			for st in data:
				var d: Dictionary = data[st]
				var res: Array
				if d.is_empty():
					var lo := _low_rigid(kit, meshes[st], arm) - floor_y
					res = [lo, lo, 0.0]
				else:
					var up := ShieldGround.solve(sk, arm, quick[st], floor_y)
					res = [ShieldGround.low_with(sk, arm, d, 0.0) - floor_y, ShieldGround.low_with(sk, arm, d, up) - floor_y, up]
				if not out.has(st):
					out[st] = {}
				if not out[st].has(clip):
					out[st][clip] = res
				else:
					var cur: Array = out[st][clip]
					out[st][clip] = [minf(cur[0], res[0]), minf(cur[1], res[1]), maxf(cur[2], res[2])]
	return out

## Escudo sem rampa (kit antigo): ponto mais baixo com a malha presa só no antebraço.
static func _low_rigid(kit: KitModel, mi: MeshInstance3D, arm: int) -> float:
	var sk := kit.skeleton
	var g := sk.global_transform * sk.get_bone_global_pose(arm) * sk.get_bone_global_rest(arm).affine_inverse()
	var low := INF
	for si in range(mi.mesh.get_surface_count()):
		for v in mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
			low = minf(low, (g * (v as Vector3)).y)
	return low

## Triângulos (mundo) de um escudo com o antebraço na pose atual (ponta no repouso: na sela ela não encolhe).
static func shield_faces(kit: KitModel, mi: MeshInstance3D) -> PackedVector3Array:
	var sk := kit.skeleton
	var arm := sk.find_bone(ShieldGround.ARM_BONE)
	var g := sk.global_transform * sk.get_bone_global_pose(arm) * sk.get_bone_global_rest(arm).affine_inverse()
	var out := PackedVector3Array()
	for v in mi.mesh.get_faces():
		out.append(g * v)
	return out

## Triângulos (mundo) de um bicho de peças rígidas (cavalo, lobo de montaria) na pose atual do esqueleto dele.
static func rigid_faces(form: FormModel) -> PackedVector3Array:
	var out := PackedVector3Array()
	var sk := form.skeleton
	for n in form.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.skin != null:
			continue
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
		var g := sk.global_transform * sk.get_bone_global_pose(bone) * xf
		for v in mi.mesh.get_faces():
			out.append(g * v)
	return out

## Quantas arestas dos triângulos `faces` atravessam a malha `solid`.
static func crossings(faces: PackedVector3Array, solid: TriangleMesh) -> int:
	var n := 0
	for i in range(0, faces.size() - 2, 3):
		for k in range(3):
			if not solid.intersect_segment(faces[i + k], faces[i + (k + 1) % 3]).is_empty():
				n += 1
	return n

## Guarda montada: o kit na sela de `mount` (como EntityView._ride_saddle), a montaria em `phases` instantes do clipe
## `mount_clip` e o cavaleiro no clipe `clip`. Devolve {estilo: arestas do escudo que atravessam a montaria (soma)}.
static func mounted_crossings(kit: KitModel, mount: FormModel, styles: Array, clip: String, mount_clip: String = "run", phases: int = 4) -> Dictionary:
	var out := {}
	var meshes := shields_of(kit)
	var root := kit.get_parent_node_3d()
	for st in styles:
		out[st] = 0
	if not kit.anim.has_animation(clip) or mount.anim == null or not mount.anim.has_animation(mount_clip):
		return out
	for ph in range(phases):
		mount.anim.play(mount_clip)
		mount.anim.seek(mount.anim.get_animation(mount_clip).length * ph / float(phases), true)
		mount.anim.pause()
		kit.global_transform = mount.bone_delta("body") * root.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, EntityView.SADDLE_Y, 0))
		pose(kit, clip, kit.anim.get_animation(clip).length * ph / float(phases))
		var solid := TriangleMesh.new()
		solid.create_from_faces(rigid_faces(mount))
		for st in styles:
			if meshes.has(st):
				out[st] += crossings(shield_faces(kit, meshes[st]), solid)
	return out
