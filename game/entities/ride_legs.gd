class_name RideLegs
extends SkeletonModifier3D
## Golpe a cavalo (Combate Montado do Paladino): o clipe de golpe mexe braços e tronco e este modificador prende as
## pernas na pose da sela (RidePose.POSE), por cima da animação. Só fica ligado enquanto o montado golpeia.

var _bones: Array = []          # [índice do osso, rotação da pose]

func setup(sk: Skeleton3D) -> void:
	for bname in RidePose.POSE:
		if not (bname.begins_with("thigh") or bname.begins_with("shin") or bname.begins_with("foot")):
			continue
		var idx := sk.find_bone(bname)
		if idx < 0:
			continue
		var e: Vector3 = RidePose.POSE[bname]
		var q: Quaternion = sk.get_bone_rest(idx).basis.get_rotation_quaternion() * Quaternion.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z)))
		_bones.append([idx, q])
	active = false

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for b in _bones:
		sk.set_bone_pose_rotation(b[0], b[1])
