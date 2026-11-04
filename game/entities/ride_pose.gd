class_name RidePose
extends RefCounted
## Montado: pernas abertas e dobradas na sela e braços segurando as rédeas. Vira o clipe "ride" do kit,
## gerado em tempo de execução a partir do "idle" (tronco e cabeça respiram como no idle; pernas e braços ficam na pose).
## Ângulos em graus por osso (eixos locais do Blender, como em chibi_kit._pose_action).

const POSE := {
	"thigh.L": Vector3(-40, 0, 75), "thigh.R": Vector3(-40, 0, -75),
	"shin.L": Vector3(30, 0, -50), "shin.R": Vector3(30, 0, 50),
	"foot.L": Vector3(-10, 0, 0), "foot.R": Vector3(-10, 0, 0),
	"upper_arm.L": Vector3(-38, -8, 0), "upper_arm.R": Vector3(-38, 8, 0),
	"forearm.L": Vector3(-46, 0, 0), "forearm.R": Vector3(-46, 0, 0),
}

## Cria (uma vez por AnimationPlayer) o clipe "ride".
static func ensure_clip(anim: AnimationPlayer, sk: Skeleton3D) -> bool:
	if anim == null or sk == null:
		return false
	if anim.has_animation("ride"):
		return true
	if not anim.has_animation("idle"):
		return false
	var src: Animation = anim.get_animation("idle")
	var a: Animation = src.duplicate(true)
	a.loop_mode = Animation.LOOP_LINEAR
	var prefix := ""
	for t in range(a.get_track_count()):
		var path := String(a.track_get_path(t))
		if ":" in path:
			prefix = path.get_slice(":", 0)
			break
	for bname in POSE:
		var idx := sk.find_bone(bname)
		if idx < 0:
			continue
		var e: Vector3 = POSE[bname]
		var q: Quaternion = sk.get_bone_rest(idx).basis.get_rotation_quaternion() * Quaternion.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z)))
		var tp := NodePath("%s:%s" % [prefix, bname])
		var tr := a.find_track(tp, Animation.TYPE_ROTATION_3D)
		if tr < 0:
			tr = a.add_track(Animation.TYPE_ROTATION_3D)
			a.track_set_path(tr, tp)
		while a.track_get_key_count(tr) > 0:
			a.track_remove_key(tr, 0)
		a.rotation_track_insert_key(tr, 0.0, q)
	var lib := anim.get_animation_library("")
	if lib == null:
		lib = AnimationLibrary.new()
		anim.add_animation_library("", lib)
	lib.add_animation("ride", a)
	return true
