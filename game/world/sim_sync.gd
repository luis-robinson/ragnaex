class_name SimSync
extends Node
## Liga a sim na thread (WorldSim.threaded): começa os ticks agendados logo antes de desenhar o quadro e espera a
## thread antes de qualquer input chegar aos nós (fica por último na raiz, então o _input dele vem primeiro).
## `--sim_sync` desliga (tick no physics, como antes) para comparar.

static func install(tree: SceneTree, on: bool) -> void:
	Sim.threaded = on
	if tree.root.has_node("SimSync"):
		return
	var s := SimSync.new()
	s.name = "SimSync"
	tree.root.add_child.call_deferred(s)

func _ready() -> void:
	RenderingServer.frame_pre_draw.connect(Sim.start_async)

func _input(_event: InputEvent) -> void:
	Sim.sync()

func _notification(_what: int) -> void:
	if is_inside_tree():
		Sim.sync()
