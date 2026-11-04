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
var shake := 0.0

func _ready() -> void:
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
	cam.position = off + Vector3(randf_range(-shake, shake), randf_range(-shake, shake), 0)
	if is_inside_tree():
		cam.look_at(global_position + Vector3(0, 0.8, 0), Vector3.UP)

func _process(delta: float) -> void:
	if target:
		global_position = global_position.lerp(target.global_position, minf(1.0, delta * follow_speed))
	_yaw = lerp_angle(_yaw, _target_yaw, minf(1.0, delta * 8.0))
	rotation.y = _yaw
	shake = maxf(0.0, shake - delta * 2.0)
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

func add_shake(amount: float) -> void:
	shake = maxf(shake, amount)
