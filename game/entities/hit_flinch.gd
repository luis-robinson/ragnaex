class_name HitFlinch
extends SkeletonModifier3D
## Reação a golpe forte POR CIMA do clipe (plano de combate 2026-11-23, C3a): tronco, peito e pescoço inclinam para
## longe do golpe e voltam em ~0,3 s. Aditivo: soma uma rotação à pose que o clipe deu; não troca o clipe, não para o
## boneco e não mexe na sim (o controle nunca sai do jogador). Criado na 1ª vez pelo EntityView.react_hit.

const BONES := {"spine": 0.6, "chest": 0.3, "neck": 0.1}      # parte do ângulo por osso (mais embaixo: a cabeça grande do chibi anda mais)
const IN_S := 0.05            # s até o máximo (o golpe empurra rápido)
const OUT_S := 0.3            # s para voltar
const MAX_DEG := 34.0         # ângulo somado com força 1 (18° = 0,10 m de cabeça: não se via da câmera de 52°; filme 2026-11-23)

var _bones: Array = []        # [índice do osso, parte, eixo local]
var _t := 1.0e9               # s desde o golpe
var _amp := 0.0               # rad

func setup(sk: Skeleton3D) -> void:
	for b in BONES:
		var i := sk.find_bone(b)
		if i >= 0:
			_bones.append([i, float(BONES[b]), Vector3.RIGHT])
	active = false

## Golpe vindo na direção `dir_world` (do atacante para o alvo, plano XZ), força 0-1.
func kick(dir_world: Vector3, strength: float) -> void:
	var sk := get_skeleton()
	if sk == null or _bones.is_empty():
		return
	var d := sk.global_transform.basis.inverse() * Vector3(dir_world.x, 0.0, dir_world.z)
	d.y = 0.0
	if d.length() < 0.001:
		return
	var axis := Vector3.UP.cross(d.normalized()).normalized()     # gira o "para cima" do osso na direção do golpe
	for b in _bones:
		var rest := sk.get_bone_global_rest(int(b[0])).basis.orthonormalized()
		b[2] = (rest.inverse() * axis).normalized()
	var amp := deg_to_rad(MAX_DEG) * clampf(strength, 0.0, 1.0)
	_amp = maxf(amp, _amp * _weight())        # golpe em cima de golpe não diminui a reação em curso
	_t = 0.0
	active = true

## 0-1: sobe em IN_S, desce em OUT_S (suave).
func _weight() -> float:
	if _t < IN_S:
		return smoothstep(0.0, 1.0, _t / IN_S)
	return 1.0 - smoothstep(0.0, 1.0, (_t - IN_S) / OUT_S)

## Reação em curso (teste e foto).
func busy() -> bool:
	return _t < IN_S + OUT_S

func _process(delta: float) -> void:
	if not active:
		return
	_t += delta
	if not busy():
		active = false
		_amp = 0.0

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var w := _weight() * _amp
	if w <= 0.0001:
		return
	for b in _bones:
		var i: int = b[0]
		sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i) * Quaternion(b[2], w * float(b[1])))
