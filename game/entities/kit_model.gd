class_name KitModel
extends Node3D
## Personagem do kit modular (assets/models/kit_<corpo>.glb): corpo + TODAS as peças de equipamento.
## Liga só as peças do equipamento atual e pinta cada uma com a cor do item.
## Usado pela EntityView (mundo) e pela prévia da janela de personagem (C).
##  - armadura: arm_<estilo>_<slot>_*  (sem peça de corpo = roupa de couro simples)
##  - armas:    wpn_main_<tipo> / wpn_off_<tipo>
##  - material "tint" = cor do item · "hair" = cor do cabelo · elmo/capuz escondem o cabelo

const LOOPS := ["idle", "idle_bow", "idle_staff", "run", "block", "block_shield", "fall"]

const TRAIL_TIME := 0.2             # duração do rastro do golpe (s)

var anim: AnimationPlayer = null
var skeleton: Skeleton3D = null
var mats: Array = []                 # todos os materiais toon (hit flash)
## rastro das armas: ligado pela EntityView durante o golpe (fita que segue a lâmina e some)
var trail_on := false
var _trails: Array = []              # [{bone, base, tip (no espaço do osso), color, samples: [[base_w, tip_w, t]]}]
var _trail_mesh: ImmediateMesh
var _trail_mat: StandardMaterial3D
var _trail_drawn := false
var _time := 0.0
var _nodes: Dictionary = {}          # nome do nó -> MeshInstance3D
var _tints: Dictionary = {}          # nome do nó -> [ShaderMaterial] com material "tint"
var _hair: Array = []                # materiais "hair"
var _beard: Array = []               # materiais "beard"
var _iris: Array = []                # materiais "iris" (olhos)
var _skin: Array = []                # materiais "m_skin" (pele)
var _mark: Array = []                # materiais "mark" (pintura/tatuagem do rosto)
var _look := {"hair": "", "beard": "none", "eyes": "round", "brows": "none", "mouth": "none", "marks": "none"}     # estilos ligados; hair "" = padrão do kit
## prefixo da malha -> campo do look (uma variante ligada por campo; "none" = nenhuma)
const LOOK_PARTS := {"base_beard_": "beard", "base_eyes_": "eyes", "base_brows_": "brows", "base_mouth_": "mouth", "base_marks_": "marks"}
var _hide_hair := false
## Otimização: peça que não aparece sai da árvore (não desenha, não processa) e só ganha material toon quando aparece a 1ª vez.
static var prune := true             # --no_prune: comportamento antigo (tudo na árvore, materiais na criação), para medir
var _parent_of: Dictionary = {}      # nome -> nó pai (para religar)
var _prepared: Dictionary = {}       # nome -> true quando os materiais toon já foram criados
var _outline := 0.025
var _cols := {}                      # cores do visual guardadas para peças que aparecem depois (hair, beard, iris, m_skin, mark)
var legs: LegOverlay = null          # pernas correndo por cima do golpe
var fade: PoseFade = null            # troca de clipe sem tranco (desliza da pose da tela)
var _accents: Dictionary = {}        # nome do nó -> [ShaderMaterial] com material "tint2" (capa, manto, faixa)
var _plus_of: Dictionary = {}        # slot -> aprimoramento da peça (brilho)
var _glow_of: Dictionary = {}        # prefixo/nó -> aprimoramento
## Otimização de draw calls: as peças ligadas viram UMA malha (uma superfície por material igual: mesma cor, brilho e contorno).
## As peças continuam na árvore, invisíveis (rastro e escudo leem a malha delas); refaz quando o equipamento/visual muda.
static var merge := true             # --no_merge: desliga (medir)
var _merged: MeshInstance3D = null
var _merge_queued := false
var _vis: Dictionary = {}            # nome -> visível (lógico, antes da fusão)

## kit_<classe>_<sexo>.glb (corpo + conjuntos da classe); senão kit_<classe>.glb antigo; senão o genérico kit_<male|female> (NPCs).
static func path_for(body: String, class_id: String = "") -> String:
	if class_id != "":
		for own in ["res://assets/models/kit_%s_%s.glb" % [class_id, body], "res://assets/models/kit_%s.glb" % class_id]:
			if ResourceLoader.exists(own):
				return own
	return "res://assets/models/kit_%s.glb" % body

static func exists(body: String, class_id: String = "") -> bool:
	return body != "" and ResourceLoader.exists(path_for(body, class_id))

## Cria o modelo (ou null se o kit não existir). class_id: usa o kit da classe (com os conjuntos dela).
static func create(body: String, hair: Color, outline_width: float = 0.025, class_id: String = "") -> KitModel:
	if not exists(body, class_id):
		return null
	var k := KitModel.new()
	k.name = "Kit"
	var inst: Node = (load(path_for(body, class_id)) as PackedScene).instantiate()
	k.add_child(inst)
	k.anim = k._find_anim(inst)
	if k.anim:
		for a in LOOPS:
			if k.anim.has_animation(a):
				k.anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	k._outline = outline_width
	k._cols["hair"] = hair
	k._toon(inst, outline_width)
	for n in k._nodes:              # começa tudo fora da árvore: apply_equipment/apply_look ligam só o que aparece
		if prune:
			k._show(n, false)
		else:
			k._prepare(k._nodes[n])
	var sks := inst.find_children("*", "Skeleton3D", true, false)
	k.skeleton = sks[0] if sks.size() > 0 else null
	if k.skeleton:
		k.fade = PoseFade.new()
		k.skeleton.add_child(k.fade)                   # antes das pernas: o passo corre por cima do deslize
	if k.skeleton and k.anim and k.anim.has_animation("run"):
		k.legs = LegOverlay.new()
		k.legs.setup(k.anim.get_animation("run"), k.skeleton)
		k.skeleton.add_child(k.legs)
	k._make_trail_node()
	GatherPose.ensure_clips(k.anim, k.skeleton)       # colheita: agachar/puxar e picareta (gerados do idle)
	return k

## Colhendo: esconde as armas da mão e mostra a picareta se for minério ("" volta ao normal).
var _tool: BoneAttachment3D = null
var _hidden_wpns: Array = []

## Brilho do aprimoramento: nada até +4; +5..+8 azul-claro leve; +9 dourado forte.
static func plus_glow_color(pl: int) -> Color:
	if pl >= Balance.PLUS_GLOW_HIGH:
		return Color(1.0, 0.8, 0.35, 0.6)
	if pl >= Balance.PLUS_GLOW_LOW:
		return Color(0.6, 0.85, 1.0, 0.22 + 0.04 * (pl - Balance.PLUS_GLOW_LOW))
	return Color(0, 0, 0, 0)

func set_gathering(kind: String) -> void:
	if kind != "" and _hidden_wpns.is_empty():
		for n in _nodes:
			if String(n).begins_with("wpn_") and _vis.get(n, false):
				_hidden_wpns.append(n)
				_show(n, false)
	elif kind == "":
		for n in _hidden_wpns:
			_show(n, true)
		_hidden_wpns.clear()
	var mine := kind in GatherPose.MINE_KINDS
	if mine and _tool == null and skeleton:
		_tool = GatherPose.make_pickaxe(skeleton)
	if _tool:
		_tool.visible = mine

func _make_trail_node() -> void:
	_trail_mesh = ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.name = "WeaponTrail"
	mi.mesh = _trail_mesh
	mi.top_level = true                       # vértices em coordenada de mundo
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_trail_mat = StandardMaterial3D.new()
	_trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail_mat.vertex_color_use_as_albedo = true
	_trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trail_mat.disable_fog = true

## Nome real do clip ("" se o kit não tiver).
func resolve(clip: String) -> String:
	return clip if anim and anim.has_animation(clip) else ""

func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r:
			return r
	return null

func _toon(n: Node, outline_width: float) -> void:
	if n is MeshInstance3D:
		_nodes[n.name] = n
	for c in n.get_children():
		_toon(c, outline_width)

## Liga/desliga uma peça: escondida sai da árvore; ao aparecer volta ao mesmo pai (e cria os materiais na 1ª vez).
func _show(n: String, vis: bool) -> void:
	var mi: MeshInstance3D = _nodes[n]
	if vis:
		if not _prepared.has(n):
			_prepare(mi)
		if mi.get_parent() == null and _parent_of.has(n):
			_parent_of[n].add_child(mi)
	elif prune and mi.get_parent() != null:
		mi.owner = null                 # fora da cena importada: religar não avisa "owner inconsistente"
		_parent_of[n] = mi.get_parent()
		mi.get_parent().remove_child(mi)
	mi.visible = vis
	_vis[n] = vis
	if merge and not _merge_queued:
		_merge_queued = true
		_remerge.call_deferred()

## Chave do material: peças com a mesma chave dividem a superfície (e o material) na malha fundida.
func _mat_key(m: Material) -> String:
	if not (m is ShaderMaterial):
		return "o%d" % m.get_instance_id()
	var sm := m as ShaderMaterial
	var col: Color = sm.get_shader_parameter("albedo")
	return "%s|%s|%s|%s|%d|%s" % [col.to_html(), str(sm.get_shader_parameter("spec_strength")), str(sm.get_shader_parameter("emission_amount")),
		str(sm.get_shader_parameter("shadow_strength")), 1 if sm.next_pass else 0, str(sm.get_shader_parameter("plus_glow"))]

func _remerge() -> void:
	_merge_queued = false
	if not merge or skeleton == null or not is_instance_valid(skeleton):
		return
	var groups := {}           # chave -> [material, [[mesh, surface]]]
	var order: Array = []
	var alpha := 0.0
	for n in _nodes:
		var mi: MeshInstance3D = _nodes[n]
		if not _vis.get(n, false) or mi.get_parent() == null or mi.mesh == null:
			continue
		alpha = mi.transparency
		for si in range(mi.mesh.get_surface_count()):
			var m := mi.get_active_material(si)
			if m == null:
				continue
			var key := _mat_key(m)
			if not groups.has(key):
				groups[key] = [m, []]
				order.append(key)
			groups[key][1].append([mi.mesh, si])
		mi.visible = false
	var am := ArrayMesh.new()
	for key in order:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for p in groups[key][1]:
			st.append_from(p[0], p[1], Transform3D.IDENTITY)
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
		am.surface_set_material(am.get_surface_count() - 1, groups[key][0])
	if _merged == null:
		_merged = MeshInstance3D.new()
		_merged.name = "KitMerged"
		skeleton.add_child(_merged)
		_merged.skeleton = NodePath("..")
	var any_src: MeshInstance3D = _nodes[_nodes.keys()[0]]
	_merged.skin = any_src.skin
	_merged.mesh = am
	_merged.transparency = alpha

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for n in _nodes:                # peças fora da árvore não morrem com o kit
			var mi: MeshInstance3D = _nodes[n]
			if is_instance_valid(mi) and mi.get_parent() == null:
				mi.free()

func _prepare(mi: MeshInstance3D) -> void:
	_prepared[mi.name] = true
	var outline_width := _outline
	for i in range(mi.get_surface_override_material_count()):
		var base := mi.get_active_material(i)
		var col: Color = base.albedo_color if base is BaseMaterial3D else Color(0.8, 0.8, 0.8)
		var mat_name := base.resource_name if base else ""
		if mat_name == "m_contorno":        # escudos trazem o contorno na malha (shield_kit.hull)
			mi.set_surface_override_material(i, Materials.flat(Color(0.12, 0.1, 0.16)))     # mesma cor do outline.gdshader
			continue
		var tm := Materials.toon_unique(col, outline_width)
		if mi.name.begins_with("wpn_off_shield") or mi.name == "wpn_off_grip" or DevArgs.has("--no_char_outline"):
			tm.next_pass = null
		tm.set_shader_parameter("paint", 1.0)
		tm.set_shader_parameter("shadow_strength", 0.58)
		tm.set_shader_parameter("rim_strength", 0.4)
		tm.set_shader_parameter("spec_strength", 0.9 if mat_name in ["m_metal", "trim"] else (0.6 if mat_name == "hair" else 0.2))
		if base is BaseMaterial3D and base.emission_enabled:
			tm.set_shader_parameter("emission_amount", minf(base.emission_energy_multiplier, 2.0))
		mi.set_surface_override_material(i, tm)
		mats.append(tm)
		var mname := base.resource_name if base else ""
		if mname == "tint":
			if not _tints.has(mi.name):
				_tints[mi.name] = []
			_tints[mi.name].append(tm)
		elif mname == "tint2":
			if not _accents.has(mi.name):
				_accents[mi.name] = []
			_accents[mi.name].append(tm)
		elif mname == "hair":
			_hair.append(tm)
		elif mname == "beard":
			_beard.append(tm)
		elif mname == "iris":
			_iris.append(tm)
		elif mname == "m_skin":
			_skin.append(tm)
		elif mname == "mark":
			_mark.append(tm)
		if _cols.has(mname):
			tm.set_shader_parameter("albedo", _cols[mname])

## Liga as peças do equipamento e pinta pela cor do item. `bare_body` = cor da roupa simples
## quando não há peça de corpo.
func apply_equipment(eq: Dictionary, bare_body: Color = Color(0.55, 0.42, 0.3), plus: Dictionary = {}) -> void:
	_plus_of.clear()
	_glow_of.clear()
	for sl in eq:
		var pit: ItemDef = eq[sl]
		if pit:
			_plus_of[sl] = maxi(pit.plus, int(plus.get(pit.id, 0)))
	var shown := {}          # prefixo -> cor
	var hide_hair := false
	var slots := {"head": ItemDef.Slot.HEAD, "body": ItemDef.Slot.BODY, "legs": ItemDef.Slot.LEGS, "gloves": ItemDef.Slot.GLOVES,
		"boots": ItemDef.Slot.BOOTS, "cape": ItemDef.Slot.CAPE}
	var body_style := ""
	for slot_name in slots:
		var it: ItemDef = eq.get(slots[slot_name])
		var style := it.armor_style if it else ""
		var col: Color = it.icon_color if it else Color.WHITE
		if it == null and slot_name == "body":
			style = "leather"
			col = bare_body
		if slot_name == "body":
			body_style = style
		if slot_name == "legs":
			if body_style not in ["plate", "leather", "cloth"]:
				continue                 # conjunto com visual próprio: as polainas vêm no corpo
			if it == null:
				style = "leather"        # sem calça: roupa de baixo simples
				col = Color(0.3, 0.27, 0.33)
		if style == "":
			continue
		shown["arm_%s_%s_" % [style, slot_name]] = col
		_glow_of["arm_%s_%s_" % [style, slot_name]] = _plus_of.get(slots[slot_name], 0)
		if slot_name == "head" and style not in ["cloth"]:
			hide_hair = true
	_hide_hair = hide_hair
	var weapons := {}
	var main: ItemDef = eq.get(ItemDef.Slot.WEAPON)
	var off: ItemDef = eq.get(ItemDef.Slot.OFFHAND)
	if main:
		weapons[main_node(main)] = main.icon_color
		_glow_of[main_node(main)] = _plus_of.get(ItemDef.Slot.WEAPON, 0)
	if off:
		var off_node := off_node_of(off)
		weapons[off_node] = off.icon_color
		_glow_of[off_node] = _plus_of.get(ItemDef.Slot.OFFHAND, 0)
		if off.weapon_type == "shield":
			weapons["wpn_off_grip"] = Color.WHITE       # suporte que prende o escudo ao braço
	_setup_trails(main, off)
	for n in _nodes:
		var vis := false
		var col := Color.WHITE
		var tinted := false
		if _is_look_node(n):
			vis = _look_shows(n, hide_hair)
		elif n.begins_with("base_"):
			vis = true
		elif n.begins_with("arm_"):
			for prefix in shown:
				if n.begins_with(prefix):
					vis = true
					col = shown[prefix]
					tinted = true
		elif weapons.has(n):
			vis = true
			col = weapons[n]
			tinted = true
		_show(n, vis)
		if tinted:
			var pl := 0
			for pre in _glow_of:
				if n.begins_with(pre):
					pl = maxi(pl, int(_glow_of[pre]))
			for m in _tints.get(n, []) + _accents.get(n, []):
				m.set_shader_parameter("plus_glow", plus_glow_color(pl))
			for m in _tints.get(n, []):
				m.set_shader_parameter("albedo", col)
			for m in _accents.get(n, []):
				# escudo: painel no tom escuro da própria cor (o contraste vem do aro e da gema)
				m.set_shader_parameter("albedo", col.darkened(0.4) if n.begins_with("wpn_off_shield") else ItemDef.accent(col))

## Aparência (LooksCatalog): liga o cabelo/barba/olhos escolhidos e pinta as cores.
func apply_look(look: Dictionary) -> void:
	_look = {"hair": str(look.get("hair", "")), "beard": str(look.get("beard", "none")), "eyes": str(look.get("eyes", "round")),
		"brows": str(look.get("brows", "none")), "mouth": str(look.get("mouth", "none")), "marks": str(look.get("marks", "none"))}
	if look.has("skin"):
		_cols["m_skin"] = Color.html(str(look["skin"]))
	_cols["mark"] = Color.html(str(look.get("mark_color", "3a66d8")))
	_cols["hair"] = Color.html(str(look.get("hair_color", "3b2a20")))
	_cols["beard"] = Color.html(str(look.get("beard_color", look.get("hair_color", "3b2a20"))))
	_cols["iris"] = Color.html(str(look.get("eye_color", "201828")))
	for pair in [[_skin, "m_skin"], [_mark, "mark"], [_hair, "hair"], [_beard, "beard"], [_iris, "iris"]]:
		if _cols.has(pair[1]):
			for m in pair[0]:
				m.set_shader_parameter("albedo", _cols[pair[1]])
	for n in _nodes:
		if _is_look_node(n):
			_show(n, _look_shows(n, _hide_hair))

## Peça de aparência visível? Kit antigo (só "base_hair") continua mostrando o cabelo único.
func _look_shows(n: String, hide_hair: bool) -> bool:
	if n.begins_with("base_hair"):
		if hide_hair:
			return false
		if not n.begins_with("base_hair_") or not _nodes.has("base_hair_short"):
			return true
		var h: String = _look["hair"]
		if h == "" or not _nodes.has("base_hair_" + h):
			h = "short"
		return n == "base_hair_" + h
	if n.begins_with("base_eyes_") and not _nodes.has("base_eyes_" + str(_look["eyes"])):
		return n == "base_eyes_round"
	for pre in LOOK_PARTS:
		if n.begins_with(pre):
			return n == pre + str(_look[LOOK_PARTS[pre]])
	return false

func _is_look_node(n: String) -> bool:
	if n.begins_with("base_hair"):
		return true
	for pre in LOOK_PARTS:
		if n.begins_with(pre):
			return true
	return false

## Alguma peça do kit usa o material de origem `mat_name` (antes de virar toon)?
func has_material(mat_name: String) -> bool:
	for n in _nodes:
		var mi: MeshInstance3D = _nodes[n]
		if mi.mesh == null:
			continue
		for i in range(mi.mesh.get_surface_count()):
			var m := mi.mesh.surface_get_material(i)
			if m and m.resource_name == mat_name:
				return true
	return false

## Todas as peças do kit que casam com o padrão (glob), dentro ou fora da árvore.
func pieces(pattern: String) -> Array:
	var out: Array = []
	for n in _nodes:
		if String(n).match(pattern):
			out.append(_nodes[n])
	return out

func set_flash(v: float) -> void:
	for m in mats:
		m.set_shader_parameter("flash", v)

# ---------------------------------------------------------------------------
# rastro das armas
# ---------------------------------------------------------------------------
## Uma fita por arma de golpe (principal; secundária se for arma de 1 mão). Arco não tem rastro.
## Malha da arma na mão: a própria do conjunto (wpn_main_<tipo>_<estilo>) se o kit tiver, senão a comum do tipo.
func main_node(main: ItemDef) -> String:
	var styled := "wpn_main_%s_%s" % [main.weapon_type, main.weapon_style]
	return styled if main.weapon_style != "" and _nodes.has(styled) else "wpn_main_" + main.weapon_type

## Malha da mão secundária: escudo nomeado/de conjunto, arma própria de conjunto (wpn_off_<tipo>_<estilo>) ou a comum do tipo.
func off_node_of(off: ItemDef) -> String:
	if off.shield_style != "":
		return "wpn_off_%s_%s" % [off.weapon_type, off.shield_style]
	var styled := "wpn_off_%s_%s" % [off.weapon_type, off.weapon_style]
	return styled if off.weapon_style != "" and _nodes.has(styled) else "wpn_off_" + off.weapon_type

func _setup_trails(main: ItemDef, off: ItemDef) -> void:
	_trails.clear()
	if skeleton == null:
		return
	if main and main.weapon_type != "bow":
		_add_trail(main_node(main), "hand.R", main.icon_color)
	if off and off.weapon_type in ItemDef.ONE_HANDED_MELEE:
		_add_trail(off_node_of(off), "hand.L", off.icon_color)

func _add_trail(node_name: String, bone: String, col: Color) -> void:
	var mi: MeshInstance3D = _nodes.get(node_name)
	var idx := skeleton.find_bone(bone)
	if mi == null or idx < 0:
		return
	# ponta = vértice mais longe da mão na pose de repouso (a malha está no espaço do esqueleto)
	var rest := skeleton.get_bone_global_rest(idx)
	var far := rest.origin
	var best := -1.0
	for si in range(mi.mesh.get_surface_count()):
		for v in mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
			var d: float = (v as Vector3).distance_squared_to(rest.origin)
			if d > best:
				best = d
				far = v
	var tip := rest.affine_inverse() * far
	_trails.append({"bone": idx, "tip": tip * 1.05, "base": tip * 0.18, "color": col.lerp(Color(0.85, 0.95, 1.0), 0.35) * 1.6, "samples": []})

func _process(delta: float) -> void:
	_time += delta
	if _trails.is_empty() or _trail_mesh == null:
		return
	var any := false
	for tr in _trails:
		var samples: Array = tr["samples"]
		if trail_on and is_visible_in_tree():
			var bx := skeleton.global_transform * skeleton.get_bone_global_pose(tr["bone"])
			samples.append([bx * (tr["base"] as Vector3), bx * (tr["tip"] as Vector3), _time])
		while samples.size() > 0 and _time - float(samples[0][2]) > TRAIL_TIME:
			samples.pop_front()
		any = any or samples.size() > 1
	if not any:
		if _trail_drawn:
			_trail_mesh.clear_surfaces()      # só limpa se desenhou (cada clear é uma atualização no render)
			_trail_drawn = false
		return
	_trail_mesh.clear_surfaces()
	_trail_drawn = true
	for tr in _trails:
		var samples: Array = tr["samples"]
		if samples.size() < 2:
			continue
		var col: Color = tr["color"]
		_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _trail_mat)
		for smp in samples:
			var k := 1.0 - (_time - float(smp[2])) / TRAIL_TIME     # mais velho = mais apagado
			_trail_mesh.surface_set_color(Color(col.r, col.g, col.b, 0.15 * k))
			_trail_mesh.surface_add_vertex(smp[0])
			_trail_mesh.surface_set_color(Color(col.r, col.g, col.b, 0.9 * k))
			_trail_mesh.surface_add_vertex(smp[1])
		_trail_mesh.surface_end()
