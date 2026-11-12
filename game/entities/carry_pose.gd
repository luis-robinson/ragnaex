class_name CarryPose
extends SkeletonModifier3D
## NPC que trabalha (vida dos mapas): leva carga no ombro ou puxa a carroça. O modelo da carga é um prop em tamanho real
## (tools/blender/life_props.py) preso ao boneco; este modificador segura os braços na pose por cima do idle/corrida.
## Só apresentação: `carry` vem de MapsCatalog.LIVING_NPCS e a sim não sabe que existe.

## carga -> pose (graus por osso, eixos locais do Blender como em RidePose.POSE)
const POSES := {
	"shoulder": {"upper_arm.R": Vector3(0, 0, 152), "forearm.R": Vector3(-38, 0, 0)},
	"cart": {"upper_arm.R": Vector3(24, 0, 6), "forearm.R": Vector3(-14, 0, 0), "upper_arm.L": Vector3(24, 0, -6), "forearm.L": Vector3(-14, 0, 0)},
}

var _bones: Array = []          # [índice do osso, rotação da pose]

static func pose_of(carry: String) -> String:
	return "cart" if carry == "cart" else "shoulder"

static func model_path(carry: String) -> String:
	return "res://assets/models/prop_%s.glb" % carry

func setup(sk: Skeleton3D, carry: String) -> void:
	var pose: Dictionary = POSES[pose_of(carry)]
	for bname in pose:
		var idx := sk.find_bone(bname)
		if idx < 0:
			continue
		var e: Vector3 = pose[bname]
		var q: Quaternion = sk.get_bone_rest(idx).basis.get_rotation_quaternion() * Quaternion.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z)))
		_bones.append([idx, q])

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for b in _bones:
		sk.set_bone_pose_rotation(b[0], b[1])
