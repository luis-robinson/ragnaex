class_name GatherPose
extends RefCounted
## Colheita: dois clipes gerados em tempo de execução a partir do "idle" (como o RidePose), com chaves no tempo:
##   gather_herb — agacha, estica as mãos ao chão e puxa (ervas, conchas, cogumelos, relíquias, caixotes);
##   gather_mine — picareta acima da cabeça, golpe no chão e volta (minério).
## Ângulos em graus por osso (eixos locais do Blender, como em chibi_kit._pose_action; braço: X negativo = para a frente/cima;
## tronco: X positivo = inclina para a frente). `hips_drop` desce o quadril (m).

const HERB_LEN := 1.2
const HERB := [
	[0.0, 0.26, {"thigh.L": Vector3(-78, 0, 10), "thigh.R": Vector3(-78, 0, -10), "shin.L": Vector3(105, 0, 0), "shin.R": Vector3(105, 0, 0),
		"foot.L": Vector3(-28, 0, 0), "foot.R": Vector3(-28, 0, 0), "spine": Vector3(26, 0, 0), "chest": Vector3(14, 0, 0), "head": Vector3(14, 0, 0),
		"upper_arm.L": Vector3(-62, 0, 8), "upper_arm.R": Vector3(-62, 0, -8), "forearm.L": Vector3(-18, 0, 0), "forearm.R": Vector3(-18, 0, 0)}],
	[0.6, 0.24, {"thigh.L": Vector3(-74, 0, 10), "thigh.R": Vector3(-74, 0, -10), "shin.L": Vector3(100, 0, 0), "shin.R": Vector3(100, 0, 0),
		"foot.L": Vector3(-26, 0, 0), "foot.R": Vector3(-26, 0, 0), "spine": Vector3(16, 0, 0), "chest": Vector3(8, 0, 0), "head": Vector3(6, 0, 0),
		"upper_arm.L": Vector3(-38, 0, 8), "upper_arm.R": Vector3(-38, 0, -8), "forearm.L": Vector3(-72, 0, 0), "forearm.R": Vector3(-72, 0, 0)}],
]
const MINE_LEN := 0.9
const MINE := [
	[0.0, 0.0, {"thigh.L": Vector3(-14, 0, 12), "thigh.R": Vector3(8, 0, -12), "shin.L": Vector3(18, 0, 0), "shin.R": Vector3(10, 0, 0),
		"spine": Vector3(-10, 0, 0), "chest": Vector3(-8, 0, 0), "head": Vector3(-6, 0, 0),
		"upper_arm.L": Vector3(-160, 0, 10), "upper_arm.R": Vector3(-160, 0, -10), "forearm.L": Vector3(-35, 0, 0), "forearm.R": Vector3(-35, 0, 0)}],
	[0.32, 0.08, {"thigh.L": Vector3(-22, 0, 12), "thigh.R": Vector3(10, 0, -12), "shin.L": Vector3(30, 0, 0), "shin.R": Vector3(16, 0, 0),
		"spine": Vector3(24, 0, 0), "chest": Vector3(14, 0, 0), "head": Vector3(10, 0, 0),
		"upper_arm.L": Vector3(-38, 0, 6), "upper_arm.R": Vector3(-38, 0, -6), "forearm.L": Vector3(-8, 0, 0), "forearm.R": Vector3(-8, 0, 0)}],
	[0.6, 0.04, {"thigh.L": Vector3(-18, 0, 12), "thigh.R": Vector3(9, 0, -12), "shin.L": Vector3(24, 0, 0), "shin.R": Vector3(12, 0, 0),
		"spine": Vector3(10, 0, 0), "chest": Vector3(4, 0, 0), "head": Vector3(2, 0, 0),
		"upper_arm.L": Vector3(-80, 0, 8), "upper_arm.R": Vector3(-80, 0, -8), "forearm.L": Vector3(-50, 0, 0), "forearm.R": Vector3(-50, 0, 0)}],
]
const MINE_KINDS := ["ore", "star"]

## Nome do clipe para a forma do ponto de colheita.
static func clip_for(kind: String) -> String:
	return "gather_mine" if kind in MINE_KINDS else "gather_herb"

## Cria (uma vez por biblioteca de animação) os dois clipes.
static func ensure_clips(anim: AnimationPlayer, sk: Skeleton3D) -> void:
	if anim == null or sk == null or not anim.has_animation("idle"):
		return
	if not anim.has_animation("gather_herb"):
		_add(anim, sk, "gather_herb", HERB, HERB_LEN)
	if not anim.has_animation("gather_mine"):
		_add(anim, sk, "gather_mine", MINE, MINE_LEN)

static func _add(anim: AnimationPlayer, sk: Skeleton3D, clip: String, keys: Array, length: float) -> void:
	var a: Animation = anim.get_animation("idle").duplicate(true)
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR
	var prefix := ""
	for t in range(a.get_track_count()):
		var path := String(a.track_get_path(t))
		if ":" in path:
			prefix = path.get_slice(":", 0)
			break
	# todos os ossos citados em alguma chave ganham trilha só com as chaves daqui (o resto respira como no idle)
	var bones := {}
	for k in keys:
		for b in k[2]:
			bones[b] = true
	for bname in bones:
		var idx := sk.find_bone(bname)
		if idx < 0:
			continue
		var tp := NodePath("%s:%s" % [prefix, bname])
		var tr := a.find_track(tp, Animation.TYPE_ROTATION_3D)
		if tr < 0:
			tr = a.add_track(Animation.TYPE_ROTATION_3D)
			a.track_set_path(tr, tp)
		while a.track_get_key_count(tr) > 0:
			a.track_remove_key(tr, 0)
		var rest := sk.get_bone_rest(idx).basis.get_rotation_quaternion()
		for k in keys + [[length, k_first(keys)[1], k_first(keys)[2]]]:       # fecha o laço na 1ª pose
			var e: Vector3 = (k[2] as Dictionary).get(bname, Vector3.ZERO)
			a.rotation_track_insert_key(tr, float(k[0]), rest * Quaternion.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z))))
	# quadril desce (agachar / firmar o golpe)
	var hidx := sk.find_bone("hips")
	if hidx >= 0:
		var hp := NodePath("%s:hips" % prefix)
		var ht := a.find_track(hp, Animation.TYPE_POSITION_3D)
		if ht < 0:
			ht = a.add_track(Animation.TYPE_POSITION_3D)
			a.track_set_path(ht, hp)
		while a.track_get_key_count(ht) > 0:
			a.track_remove_key(ht, 0)
		var rest_pos := sk.get_bone_rest(hidx).origin
		for k in keys + [[length, k_first(keys)[1], {}]]:
			a.position_track_insert_key(ht, float(k[0]), rest_pos - Vector3(0, float(k[1]), 0))
	var lib := anim.get_animation_library("")
	if lib == null:
		lib = AnimationLibrary.new()
		anim.add_animation_library("", lib)
	lib.add_animation(clip, a)

static func k_first(keys: Array) -> Array:
	return keys[0]

## Picareta simples (cabo + cabeça curva) presa na mão direita; criada uma vez por boneco.
static func make_pickaxe(sk: Skeleton3D) -> BoneAttachment3D:
	var ba := BoneAttachment3D.new()
	ba.name = "GatherTool"
	ba.bone_name = "hand.R"
	sk.add_child(ba)
	var tool := Node3D.new()
	tool.name = "Pickaxe"
	ba.add_child(tool)
	var handle := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.025
	cm.bottom_radius = 0.03
	cm.height = 0.85
	cm.radial_segments = 6
	handle.mesh = cm
	handle.material_override = Materials.toon(Color(0.5, 0.35, 0.22))
	handle.position = Vector3(0, 0.3, 0)
	tool.add_child(handle)
	var head := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.55, 0.12, 0.07)
	head.mesh = pm
	head.material_override = Materials.toon(Color(0.55, 0.56, 0.6))
	head.position = Vector3(0, 0.7, 0)
	head.rotation = Vector3(0, 0, PI)
	tool.add_child(head)
	ba.visible = false
	return ba
