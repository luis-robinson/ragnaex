class_name LegOverlay
extends SkeletonModifier3D
## Pernas correndo por cima do clipe de golpe: quem ataca andando mexe os pés em vez de deslizar.
## Amostra as trilhas de perna do clipe "run" depois da animação; só trabalha enquanto `_weight` > 0.

const LEG_BONES := ["thigh", "shin", "foot", "leg_"]     # leg_* = patas dos bichos (formas do Druida)

var _run: Animation = null
var _tracks: Array = []         # [índice da trilha, índice do osso]
var _time := 0.0
var _weight := 0.0

func setup(run: Animation, sk: Skeleton3D) -> void:
	_run = run
	for t in range(run.get_track_count()):
		if run.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var bone_name := String(run.track_get_path(t).get_subname(0))
		if LEG_BONES.any(func(b): return bone_name.begins_with(b)):
			var idx := sk.find_bone(bone_name)
			if idx >= 0:
				_tracks.append([t, idx])
	active = false

func drive(delta: float, moving: bool, speed: float, ref_speed: float) -> void:
	_weight = move_toward(_weight, 1.0 if moving else 0.0, delta * 9.0)
	active = _weight > 0.0
	if moving and _run:
		_time = fposmod(_time + delta * clampf(speed / ref_speed, 0.45, 1.7), _run.length)

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _run == null:
		return
	for tr in _tracks:
		var q: Quaternion = _run.rotation_track_interpolate(tr[0], _time)
		sk.set_bone_pose_rotation(tr[1], sk.get_bone_pose_rotation(tr[1]).slerp(q, _weight))
