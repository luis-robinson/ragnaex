class_name ShieldGround
extends SkeletonModifier3D
## Ponta do escudo que não fura o chão. O chibi tem o cotovelo a ~0,55 m do chão e os escudos têm de 0,7 m a 1,6 m:
## rente ao antebraço, a ponta passava do chão em quase todo clipe. Nos kits de quem empunha escudo a parte da placa
## abaixo do braço pesa em rampa no osso TIP_BONE (chibi_kit.skin_shield_tip); aqui, depois da animação, o osso sobe ao
## longo da placa só o que falta para o ponto mais baixo ficar em cima do chão. A parte de cima (alça, canto do
## cotovelo) não muda; com o osso no repouso o escudo é a malha de sempre. Só apresentação.

const TIP_BONE := "shield_tip.L"
const ARM_BONE := "forearm.L"
const MARGIN := 0.012           # folga da ponta sobre o chão (m, no mundo)
const MAX_SQUASH := 0.85        # a parte de baixo encolhe no máximo até sobrar 15% dela
const MIN_UP := 0.12            # placa quase deitada (morte, queda): não há para onde encolher
const DIRS := 48                # direções em que se guarda o vértice extremo da rampa (candidatos a ponto mais baixo)

static var _cache: Dictionary = {}       # id da malha -> dados do escudo ({} = sem rampa: kit antigo, escudo de monstro)

var floor_node: Node3D = null            # o chão é o y global deste nó (o pai do kit: o kit sobe na sela, o pai não)
var squash := 0.0                        # quanto o osso subiu no último quadro (m, espaço do osso)
var _data: Dictionary = {}
var _tip := -1
var _arm := -1
var _rest := Vector3.ZERO

## Dados da rampa de um escudo: pontos candidatos no espaço do antebraço (com o peso da ponta), direção em que a ponta
## sobe e comprimento da rampa. {} se a malha não pesa no osso da ponta.
static func data_for(mesh: Mesh, skin: Skin, sk: Skeleton3D, all_points: bool = false) -> Dictionary:
	if mesh == null or skin == null or sk == null:
		return {}
	var key := "%d%s" % [mesh.get_instance_id(), "a" if all_points else ""]
	if _cache.has(key):
		return _cache[key]
	var out := {}
	_cache[key] = out
	var arm := sk.find_bone(ARM_BONE)
	var bind := -1
	for i in range(skin.get_bind_count()):
		var bn := String(skin.get_bind_name(i))
		if bn == "" and skin.get_bind_bone(i) >= 0:
			bn = sk.get_bone_name(skin.get_bind_bone(i))
		if bn == TIP_BONE:
			bind = i
	if arm < 0 or bind < 0 or sk.find_bone(TIP_BONE) < 0:
		return out
	var inv := sk.get_bone_global_rest(arm).affine_inverse()
	var pts := PackedVector3Array()
	var ws := PackedFloat32Array()
	for si in range(mesh.get_surface_count()):
		var arr: Array = mesh.surface_get_arrays(si)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		if arr[Mesh.ARRAY_BONES] == null or arr[Mesh.ARRAY_WEIGHTS] == null:
			continue
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / maxi(1, vs.size())
		for i in range(vs.size()):
			var w := 0.0
			for j in range(per):
				if bones[i * per + j] == bind:
					w += weights[i * per + j]
			pts.append(inv * vs[i])
			ws.append(w)
	# direção e comprimento da rampa: o peso é linear na altura ao longo da placa (regressão nos vértices da rampa)
	var mean := Vector3.ZERO
	var wm := 0.0
	var n := 0
	for i in range(pts.size()):
		if ws[i] > 0.02 and ws[i] < 0.98:
			mean += pts[i]
			wm += ws[i]
			n += 1
	if n < 4:
		return out
	mean /= n
	wm /= n
	var cx := Vector3.ZERO
	var cy := Vector3.ZERO
	var cz := Vector3.ZERO
	var r := Vector3.ZERO
	for i in range(pts.size()):
		if ws[i] > 0.02 and ws[i] < 0.98:
			var d := pts[i] - mean
			cx += d * d.x
			cy += d * d.y
			cz += d * d.z
			r += d * (ws[i] - wm)
	var reg := (cx.x + cy.y + cz.z) * 1e-5
	var cov := Basis(cx + Vector3(reg, 0, 0), cy + Vector3(0, reg, 0), cz + Vector3(0, 0, reg))
	if absf(cov.determinant()) < 1e-18:
		return out
	var g := cov.inverse() * r
	if g.length() < 1e-4:
		return out
	out["dir"] = -g.normalized()                 # para onde a ponta sobe (espaço do antebraço)
	out["len"] = 1.0 / g.length()                # comprimento da rampa (m)
	if all_points:
		out["pts"] = pts
		out["ws"] = ws
		return out
	# candidatos: o vértice extremo em cada direção, só da parte que encolhe (o resto da placa não tem como subir)
	var keep := {}
	for k in range(DIRS):
		var y := 1.0 - 2.0 * (k + 0.5) / DIRS
		var rad := sqrt(maxf(0.0, 1.0 - y * y))
		var a := k * 2.399963
		var dv := Vector3(cos(a) * rad, y, sin(a) * rad)
		var best := -1
		var bd := -INF
		for i in range(pts.size()):
			if ws[i] > 0.0:
				var s := dv.dot(pts[i])
				if s > bd:
					bd = s
					best = i
		if best >= 0:
			keep[best] = true
	var kp := PackedVector3Array()
	var kw := PackedFloat32Array()
	for i in keep:
		kp.append(pts[i])
		kw.append(ws[i])
	out["pts"] = kp
	out["ws"] = kw
	return out

## Quanto o osso da ponta tem de subir (m, espaço do osso) para o escudo ficar em cima do chão `floor_y` (y do mundo),
## com o antebraço na pose atual do esqueleto.
static func solve(sk: Skeleton3D, arm: int, data: Dictionary, floor_y: float) -> float:
	var g := sk.global_transform * sk.get_bone_global_pose(arm)
	var row := Vector3(g.basis.x.y, g.basis.y.y, g.basis.z.y)       # y do mundo de um ponto do osso = row · p + oy
	var oy := g.origin.y
	var c := row.dot(data["dir"])                # quanto 1 m de subida do osso levanta no mundo
	if c <= MIN_UP * row.length():
		return 0.0
	var pts: PackedVector3Array = data["pts"]
	var ws: PackedFloat32Array = data["ws"]
	var need := 0.0
	var want := floor_y + MARGIN
	for i in range(pts.size()):
		var y := row.dot(pts[i]) + oy
		if y < want and ws[i] > 0.0:
			need = maxf(need, (want - y) / (ws[i] * c))
	return minf(need, float(data["len"]) * MAX_SQUASH)

## Ponto mais baixo (y do mundo) dos pontos de `data` com o osso da ponta subido `up` (conferência com a malha inteira).
static func low_with(sk: Skeleton3D, arm: int, data: Dictionary, up: float) -> float:
	var g := sk.global_transform * sk.get_bone_global_pose(arm)
	var row := Vector3(g.basis.x.y, g.basis.y.y, g.basis.z.y)
	var pts: PackedVector3Array = data["pts"]
	var ws: PackedFloat32Array = data["ws"]
	var c := row.dot(data["dir"]) * up
	var low := INF
	for i in range(pts.size()):
		low = minf(low, row.dot(pts[i]) + g.origin.y + ws[i] * c)
	return low

## Liga para o escudo `mesh` (null ou malha sem rampa = desligado).
func setup(sk: Skeleton3D, mesh: Mesh, skin: Skin) -> void:
	_data = data_for(mesh, skin, sk)
	_tip = sk.find_bone(TIP_BONE)
	_arm = sk.find_bone(ARM_BONE)
	active = not _data.is_empty() and _tip >= 0 and _arm >= 0
	if _tip >= 0:
		_rest = sk.get_bone_rest(_tip).origin
	squash = 0.0

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _data.is_empty() or not sk.is_inside_tree():
		return
	var fy: float = floor_node.global_position.y if floor_node != null and is_instance_valid(floor_node) else sk.global_position.y
	squash = solve(sk, _arm, _data, fy)
	if squash > 0.0:
		sk.set_bone_pose_position(_tip, _rest + (_data["dir"] as Vector3) * squash)
