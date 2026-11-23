class_name CameraRig
extends Node3D
## Câmera estilo Ragnarok/ToS: pitch alto fixo, yaw travado em passos de 45° (Q/E), zoom no scroll.
## Segue o jogador com suavização. Expõe `cam` para raycast do mouse no plano do chão.

@export var pitch_deg := 52.0
@export var distance := 24.0
@export var min_distance := 14.0
@export var max_distance := 34.0
@export var fov := 35.0
@export var follow_speed := 9.0

var cam: Camera3D
var yaw_index := 0          # 0..7 → 0°, 45°, ...
var _yaw := 0.0
var _target_yaw := 0.0
var target: Node3D = null
var shake := 0.0            # m de tremor agora (cai SHAKE_DECAY por s); o desenho é × AccessSettings.shake
var _shake_dir := Vector3.ZERO      # direção do golpe (mundo, no chão): o tremor puxa um pouco para lá
var _shake_peak := 0.0
var _shake_t := 0.0
var _noise: FastNoiseLite = null

const SHAKE_DECAY := 2.0            # m/s
const SHAKE_FREQ := 18.0            # ruído suave: "voltas" por s (antes era um sorteio por quadro)
const SHAKE_BIAS := 0.6             # parte do tremor que empurra na direção do golpe

## Deslocamento do tremor (espaço do rig) para `amount` m, tempo `t`, direção local `dir_local` (x/z) e escala do
## jogador `scale`. 0 de escala ou de tremor = Vector3.ZERO exato.
static func shake_offset(noise: FastNoiseLite, amount: float, t: float, dir_local: Vector3, peak: float, scale: float) -> Vector3:
	var a := amount * scale
	if a <= 0.0:
		return Vector3.ZERO
	var off := Vector3(noise.get_noise_2d(t * SHAKE_FREQ, 0.0), noise.get_noise_2d(t * SHAKE_FREQ, 57.0), 0.0) * a
	if dir_local != Vector3.ZERO and peak > 0.0:
		off += Vector3(dir_local.x, 0.0, dir_local.z) * (a * SHAKE_BIAS * (amount / peak))
	return off

func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.5
	_noise.seed = 7
	cam = Camera3D.new()
	cam.fov = fov
	cam.near = 0.5
	cam.far = 190.0
	cam.current = true
	add_child(cam)
	_apply_cam()

func _apply_cam() -> void:
	var pitch := deg_to_rad(pitch_deg)
	var dir := Vector3(0, sin(pitch), cos(pitch)).normalized()
	var off := dir * distance
	var dl := Vector3.ZERO
	if _shake_dir != Vector3.ZERO:
		dl = basis.inverse() * _shake_dir
	cam.position = off + shake_offset(_noise, shake, _shake_t, dl, _shake_peak, AccessSettings.shake)
	if is_inside_tree():
		cam.look_at(global_position + Vector3(0, 0.8, 0), Vector3.UP)

func _process(delta: float) -> void:
	if target:
		var tp := target.global_position
		if target is EntityView and (target as EntityView).entity != null:
			tp.y -= EntityView.sky_lift((target as EntityView).entity)     # Salto Dracônico: a câmera fica no chão, ele some no alto
		global_position = global_position.lerp(tp, minf(1.0, delta * follow_speed))
	_yaw = lerp_angle(_yaw, _target_yaw, minf(1.0, delta * 8.0))
	rotation.y = _yaw
	shake = maxf(0.0, shake - delta * SHAKE_DECAY)
	_shake_t += delta
	if shake <= 0.0:
		_shake_dir = Vector3.ZERO
		_shake_peak = 0.0
	_apply_cam()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cam_rotate_left"):
		yaw_index = (yaw_index + 1) % 8
		_target_yaw += PI * 0.25
	elif event.is_action_pressed("cam_rotate_right"):
		yaw_index = (yaw_index + 7) % 8
		_target_yaw -= PI * 0.25
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance - 1.5, min_distance, max_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance + 1.5, min_distance, max_distance)

## Direção "frente" da câmera projetada no chão (para WASD relativo à câmera).
func forward_flat() -> Vector3:
	var f := -cam.global_transform.basis.z
	f.y = 0.0
	return f.normalized()

func right_flat() -> Vector3:
	var r := cam.global_transform.basis.x
	r.y = 0.0
	return r.normalized()

## Ponto do chão (y=0) sob a posição do mouse.
func mouse_ground_point(mouse_pos: Vector2) -> Vector3:
	var from := cam.project_ray_origin(mouse_pos)
	var dir := cam.project_ray_normal(mouse_pos)
	var plane := Plane(Vector3.UP, 0.0)
	var hit = plane.intersects_ray(from, dir)
	if hit == null:
		return target.global_position if target else Vector3.ZERO
	return hit

## Tremor de `amount` m (o maior vence). `from_dir` (opcional, mundo) = direção do golpe: a câmera dá um tranco para lá.
func add_shake(amount: float, from_dir: Vector3 = Vector3.ZERO) -> void:
	if amount >= shake:
		_shake_peak = amount
		var d := Vector3(from_dir.x, 0.0, from_dir.z)
		_shake_dir = d.normalized() if d.length() > 0.01 else Vector3.ZERO
	shake = maxf(shake, amount)
