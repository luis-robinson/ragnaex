class_name PoseFade
extends SkeletonModifier3D
## Troca de clipe sem tranco: guarda a pose que está NA TELA na hora da troca e desliza dela para o clipe novo
## (slerp direto entre as duas poses). A mistura do AnimationPlayer passa pelo repouso do osso e, com a mão girada
## perto de 180° (golpes, magias), vira para o outro lado num quadro. Quem troca o clipe chama `start` ANTES do play
## e toca o clipe novo sem mistura; `tick` anda o tempo (EntityView), o modificador só aplica.

var _from_rot: Array = []       # Quaternion por osso (pose congelada)
var _from_pos: Array = []       # Vector3 por osso
var _t := 1.0
var _dur := 0.0

## Congela a pose mostrada agora (se já estava deslizando, a pose misturada) e desliza por `dur` s.
func start(dur: float) -> void:
	var sk := get_skeleton()
	if sk == null or dur <= 0.0:
		return
	var n := sk.get_bone_count()
	var mid := active and _from_rot.size() == n
	var rots: Array = []
	var poss: Array = []
	rots.resize(n)
	poss.resize(n)
	for i in range(n):
		rots[i] = shown_rotation(sk, i) if mid else sk.get_bone_pose_rotation(i)
		poss[i] = shown_position(sk, i) if mid else sk.get_bone_pose_position(i)
	_from_rot = rots
	_from_pos = poss
	_t = 0.0
	_dur = dur
	active = true

func tick(delta: float) -> void:
	if not active:
		return
	_t = minf(1.0, _t + delta / maxf(_dur, 0.001))
	if _t >= 1.0:
		active = false

func _w() -> float:
	return smoothstep(0.0, 1.0, _t)

## Pose que a tela mostra para o osso (a do clipe se não está deslizando).
func shown_rotation(sk: Skeleton3D, i: int) -> Quaternion:
	var q := sk.get_bone_pose_rotation(i)
	if not active or i >= _from_rot.size():
		return q
	return (_from_rot[i] as Quaternion).slerp(q, _w())

func shown_position(sk: Skeleton3D, i: int) -> Vector3:
	var p := sk.get_bone_pose_position(i)
	if not active or i >= _from_pos.size():
		return p
	return (_from_pos[i] as Vector3).lerp(p, _w())

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _from_rot.size() != sk.get_bone_count():
		return
	var w := _w()
	for i in range(_from_rot.size()):
		sk.set_bone_pose_rotation(i, (_from_rot[i] as Quaternion).slerp(sk.get_bone_pose_rotation(i), w))
		sk.set_bone_pose_position(i, (_from_pos[i] as Vector3).lerp(sk.get_bone_pose_position(i), w))
