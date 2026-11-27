class_name GvgWorld
extends Node3D
## Mundo da Guerra de Guildas no mapa `gvg_field` (só apresentação; contrato wave6 §1-§3):
## - portões: troca `Z_gvg_field_gate_<main|side>_<S>` (inteiro) por `..._broken` quando o portão cai
##   (`Events.gvg_gate_broken` e, de reserva, a vida 0 no `gvg_status`);
## - estandartes: em cada vazio `BANNER_<S>_NN` põe o `prop_gvg_banner` pintado com o pano (tint) e o brasão (tint2) da
##   guilda daquele lado (só se o GLB existir);
## - canhões: o cano (osso ou nó `barrel`) gira para onde o operador mira (o jogador: o cursor; bot: `aim` do objeto
##   ou a direção do corpo).
## Fora do mapa da guerra o nó não faz nada.

const BANNER_PATH := "res://assets/models/prop_gvg_banner.glb"
const POLL := 0.25
const BARREL_TURN := 10.0        # quão rápido o cano segue a mira

var map_id := ""
var main                         # game/main.gd (views, controller)
var gates: Dictionary = {}       # "main_N" -> {"closed": [Node3D], "broken": [Node3D], "down": bool}
var banners: Array = []          # [{node: Node3D, side: String, painted: String}]
var _t := 0.0
var _barrels: Dictionary = {}    # entity id -> GvgBarrel
var _shots: Dictionary = {}      # cannon id -> último ponto do tiro (Events.gvg_cannon_fired)

static func create(id: String, main_ref = null) -> GvgWorld:
	var w := GvgWorld.new()
	w.map_id = id
	w.main = main_ref
	w.name = "GvgWorld"
	return w

func _ready() -> void:
	if not GvgUi.is_war_map(map_id):
		set_process(false)
		return
	var root := get_parent()
	if root:
		_collect(root)
	if Events.has_signal(&"gvg_gate_broken"):
		Events.connect(&"gvg_gate_broken", _on_gate_broken)
	if Events.has_signal(&"gvg_cannon_fired"):
		Events.connect(&"gvg_cannon_fired", func(cid: int, at: Vector3): _shots[cid] = at)
	_refresh()

## Acha os nós do GLB do mapa pelos nomes do contrato.
func _collect(root: Node) -> void:
	var pre := "Z_%s_gate_" % map_id
	for n in root.find_children(pre + "*", "Node3D", true, false):
		var rest := str(n.name).trim_prefix(pre)             # main_N | main_N_broken (Godot pode sufixar números)
		var broken := rest.contains("_broken")
		var key := rest.replace("_broken", "")
		key = key.get_slice("_", 0) + "_" + key.get_slice("_", 1)
		if not gates.has(key):
			gates[key] = {"closed": [], "broken": [], "down": false}
		(gates[key]["broken" if broken else "closed"] as Array).append(n)
		if broken:
			(n as Node3D).visible = false
	for n in root.find_children("BANNER_*", "Node3D", true, false):
		var side := str(n.name).get_slice("_", 1)
		if side in GvgUi.SIDES:
			banners.append({"node": n, "side": side, "painted": ""})

## Derruba (ou levanta, `down` = false) o portão no visual.
func set_gate(key: String, down: bool) -> void:
	var g: Dictionary = gates.get(key, {})
	if g.is_empty() or bool(g["down"]) == down:
		return
	g["down"] = down
	for n in g["closed"]:
		(n as Node3D).visible = not down
	for n in g["broken"]:
		(n as Node3D).visible = down

func _on_gate_broken(gate_id: String) -> void:
	set_gate(gate_id.trim_prefix("gate_"), true)

func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = POLL
		_refresh()
	_turn_barrels(delta)

func _refresh() -> void:
	var st := GvgUi.status()
	var gs: Dictionary = st.get("gates", {})
	for key in gates:
		if gs.has(key):
			set_gate(key, GvgUi.frac(gs[key]) <= 0.0)
	_paint_banners(st)

func _paint_banners(st: Dictionary) -> void:
	if banners.is_empty() or not ResourceLoader.exists(BANNER_PATH):
		return
	for b in banners:
		var side := str(b["side"])
		var sig := "%s|%s" % [GvgUi.side_color(st, side).to_html(), GvgUi.side_color(st, side, true).to_html()]
		if b["painted"] == sig:
			continue
		b["painted"] = sig
		var holder: Node3D = b["node"]
		for c in holder.get_children():
			if c.name == "GvgBanner":
				c.queue_free()
		holder.add_child(banner(GvgUi.side_color(st, side), GvgUi.side_color(st, side, true)))

## Estandarte pintado: `tint` = pano da guilda, `tint2` = brasão. Null sem o GLB.
static func banner(cloth: Color, crest: Color) -> Node3D:
	if not ResourceLoader.exists(BANNER_PATH):
		return null
	var scene: PackedScene = load(BANNER_PATH)
	var inst: Node3D = scene.instantiate()
	inst.name = "GvgBanner"
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in range(m.get_surface_override_material_count()):
			var base := m.get_active_material(i)
			var col: Color = base.albedo_color if base is BaseMaterial3D else Color(0.8, 0.8, 0.8)
			var mname := base.resource_name if base else ""
			if mname.begins_with("tint2"):
				col = crest
			elif mname.begins_with("tint"):
				col = cloth
			m.set_surface_override_material(i, Materials.toon(col))
	return inst

# --- cano dos canhões ----------------------------------------------------------------
## Ponto mirado pelo operador do canhão `o` (Vector3.INF = sem operador).
func aim_of(o: Dictionary) -> Vector3:
	var op := int(o.get("operator_id", -1))
	if op < 0:
		return Vector3.INF
	if Sim.player and op == Sim.player.id and main and main.controller:
		return main.controller.aim_point
	if o.get("aim") is Vector3:
		return o["aim"]
	if _shots.has(int(o.get("id", -1))):
		return _shots[int(o.get("id", -1))]
	var e: SimEntity = Sim.entities.get(op)
	if e == null:
		return Vector3.INF
	var pos: Vector3 = o.get("pos", e.position)
	return pos + Vector3(sin(e.facing), 0.0, cos(e.facing)) * 10.0

func _turn_barrels(delta: float) -> void:
	if main == null:
		return
	for o in GvgUi.objects():
		if str(o.get("type", "")) != "cannon":
			continue
		var id := int(o.get("id", -1))
		if not main.views.has(id):
			continue
		var view: Node3D = main.views[id]
		var aim := aim_of(o)
		if aim == Vector3.INF:
			continue
		var b: GvgBarrel = _barrels.get(id)
		if b == null or not is_instance_valid(b):
			b = GvgBarrel.attach(view)
			_barrels[id] = b
		if b:
			var to := view.global_transform.affine_inverse() * aim
			b.target_yaw = atan2(to.x, to.z)
			b.turn(minf(1.0, delta * BARREL_TURN))
