class_name CarryPose
extends SkeletonModifier3D
## NPC que trabalha (vida dos mapas): leva carga no ombro ou puxa a carroça. O modelo da carga é um prop em tamanho real
## (tools/blender/life_props.py) preso ao boneco; este modificador segura os braços na pose por cima do idle/corrida.
## Só apresentação: `carry` vem de MapsCatalog.LIVING_NPCS e a sim não sabe que existe.

## carga -> pose (graus por osso, eixos locais do Blender como em RidePose.POSE)
const POSES := {
	"shoulder": {"upper_arm.R": Vector3(0, 0, 152), "forearm.R": Vector3(-38, 0, 0)},
	"cart": {"upper_arm.R": Vector3(24, 0, 6), "forearm.R": Vector3(-14, 0, 0), "upper_arm.L": Vector3(24, 0, -6), "forearm.L": Vector3(-14, 0, 0)},
	"lead": {"upper_arm.L": Vector3(-34, 0, -30), "forearm.L": Vector3(-40, 0, 0)},      # mão esquerda segura o cabresto do animal
}

## carga puxada por animal de tiro -> o bicho entre os varais (espelha DRAFT_X/DRAFT_Y/DRAFT_SCALE de tools/blender/life_props.py):
## `at` = onde ele pisa no espaço do boneco (+X = esquerda, -Z = atrás), `scale` do modelo, `walk` = m/s que o clipe "walk"
## cobre a 1x (o passo acelera com a velocidade do boneco), `hoof_back` = casco de trás até o centro (m, na escala).
## `strip` = peças do modelo que o animal de tiro não usa (a sela de montaria: quem veste arreio não leva sela), tiradas
## antes da fusão; `wheel_r` = raio da roda (m; life_props.WHEEL_R): o nó `wheels` gira pela distância andada;
## `lag`/`lag_max` = a carroça (nó `cart`, origem onde o bicho pisa) segue o rumo com atraso (peso por segundo, graus de teto).
const DRAFT := {
	"cart_draft": {"model": "mob_horse", "at": Vector3(0.95, 0.0, -0.6), "scale": 1.5, "walk": 0.95, "hoof_back": 0.62,
		"strip": ["blanket", "saddle", "cantle", "horn", "stirrup*", "strap*"], "wheel_r": 0.52, "lag": 3.0, "lag_max": 16.0},
}

## carga de mão com rodas -> raio da roda (m; life_props.WHEEL_R): o nó `wheels` do prop, com a origem no eixo, gira ao andar
const WHEELS := {"cart": 0.52}

## carga -> ajuste do prop (m, espaço do boneco): o prop sai do Blender na linha do ombro, mas a cabeça chibi é grande e a mão
## erguida fica acima dela; a carga sobe um pouco para assentar na mão erguida (e sai um pouco para o lado da cabeça). A carroça não muda.
const LIFT := {
	"carry_crate": Vector3(-0.06, 0.17, 0.0),
	"carry_sack": Vector3(-0.04, 0.15, 0.0),
	"carry_log": Vector3(0.0, 0.12, 0.0),
	"carry_rock": Vector3(-0.04, 0.15, 0.0),
}

var _bones: Array = []          # [índice do osso, rotação da pose]

static func pose_of(carry: String) -> String:
	return "lead" if DRAFT.has(carry) else ("cart" if carry == "cart" else "shoulder")

## Animal de tiro da carga ({} = carga de mão).
static func draft_of(carry: String) -> Dictionary:
	return DRAFT.get(carry, {})

## Raio da roda da carga (m): o nó `wheels` do prop gira pela distância andada (0 = carga sem rodas).
static func wheel_r_of(carry: String) -> float:
	return float(DRAFT[carry]["wheel_r"]) if DRAFT.has(carry) else float(WHEELS.get(carry, 0.0))

static func lift_of(carry: String) -> Vector3:
	return LIFT.get(carry, Vector3.ZERO)

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
