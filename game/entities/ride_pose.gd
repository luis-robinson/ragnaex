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

## Guarda montada (Muralha a Cavalo): a guarda de escudo a pé deixa o escudo na altura do peito, atrás do pescoço do
## cavalo. Na sela o braço do escudo sobe e vai à frente (giro somado no eixo do osso em repouso), o tronco fica ereto.
## Graus por osso, somados a cada chave do "block_shield"; vira o clipe GUARD_CLIP. A guarda do escudo alto
## ("block_shield_tall", só nos kits de quem empunha escudo) vira GUARD_CLIP_TALL do mesmo jeito.
const GUARD_CLIP := "block_ride"
const GUARD_CLIP_TALL := "block_ride_tall"
const GUARD_SOURCES := {"block_ride": "block_shield", "block_ride_tall": "block_shield_tall"}
const GUARD_DELTA := {
	"upper_arm.L": Vector3(-34, 0, -16), "forearm.L": Vector3(14, 0, 0),
	"spine": Vector3(-9, 0, 0),
}

## Cria (uma vez por AnimationPlayer) os clipes da guarda montada a partir do "block_shield" e, se o kit tiver, do
## "block_shield_tall". Devolve se a guarda montada comum existe.
static func ensure_guard_clip(anim: AnimationPlayer, sk: Skeleton3D) -> bool:
	if anim == null or sk == null:
		return false
	for clip in GUARD_SOURCES:
		_guard_from(anim, sk, clip, GUARD_SOURCES[clip])
	return anim.has_animation(GUARD_CLIP)

static func _guard_from(anim: AnimationPlayer, sk: Skeleton3D, clip: String, source: String) -> bool:
	if anim.has_animation(clip):
		return true
	if not anim.has_animation(source):
		return false
	var a: Animation = anim.get_animation(source).duplicate(true)
	a.loop_mode = Animation.LOOP_LINEAR
	for t in range(a.get_track_count()):
		if a.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var bname := String(a.track_get_path(t)).get_slice(":", 1)
		if not GUARD_DELTA.has(bname):
			continue
		var idx := sk.find_bone(bname)
		if idx < 0:
			continue
		var e: Vector3 = GUARD_DELTA[bname]
		var rest: Quaternion = sk.get_bone_rest(idx).basis.get_rotation_quaternion()
		var d := Quaternion(Basis.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z)), EULER_ORDER_ZYX))
		var turn: Quaternion = rest * d * rest.inverse()
		for k in range(a.track_get_key_count(t)):
			a.track_set_key_value(t, k, turn * (a.track_get_key_value(t, k) as Quaternion))
	anim.get_animation_library("").add_animation(clip, a)
	return true
