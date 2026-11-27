class_name GvgBarrel
extends SkeletonModifier3D
## Cano do canhão da guerra virado para a mira (GvgWorld). O modelo `mob_siege_cannon` tem o osso `barrel` (contrato wave6
## §2): o giro vai por cima do clipe, em volta do "para cima" do esqueleto. Sem o osso, gira um nó `barrel*` do modelo.

const BONE := "barrel"

var target_yaw := 0.0            # rad, no espaço do boneco (0 = +Z, a frente do modelo)
var yaw := 0.0
var _bone := -1
var _node: Node3D = null
var _node_rest := Basis()

## Põe o modificador no esqueleto do boneco (ou guarda o nó do cano). Null se o modelo não tem cano.
static func attach(view: Node3D) -> GvgBarrel:
	for sk in view.find_children("*", "Skeleton3D", true, false):
		var i := (sk as Skeleton3D).find_bone(BONE)
		if i >= 0:
			var m := GvgBarrel.new()
			m.name = "GvgBarrel"
			m._bone = i
			sk.add_child(m)
			return m
	var nodes := view.find_children(BONE + "*", "Node3D", true, false)
	if nodes.is_empty():
		return null
	var b := GvgBarrel.new()
	b.name = "GvgBarrel"
	b.active = false
	b._node = nodes[0]
	b._node_rest = b._node.basis
	view.add_child(b)
	return b

## Aproxima o giro da mira (peso 0-1 do quadro).
func turn(w: float) -> void:
	yaw = lerp_angle(yaw, target_yaw, w)
	if _node:
		_node.basis = Basis(Vector3.UP, yaw) * _node_rest

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _bone < 0:
		return
	var pose := sk.get_bone_global_pose(_bone)
	sk.set_bone_global_pose(_bone, Transform3D(Basis(Vector3.UP, yaw) * pose.basis, pose.origin))
