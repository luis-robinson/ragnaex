class_name EntityView
extends Node3D
## Visual de uma SimEntity. Lê o estado da simulação a cada frame e anima.
## Usa assets/models/<model>.glb quando existir; senão monta um placeholder low-poly "chibi".

var entity: SimEntity
var model_root: Node3D
var anim: AnimationPlayer = null
var mat: ShaderMaterial = null          # material único (hit flash) dos placeholders
var _mats: Array = []                   # todos os materiais toon do GLB (hit flash)
var kit: KitModel = null                # personagens/NPCs: kit modular com as peças do equipamento
var form_view: FormModel = null
var horse: FormModel = null              # montado: o cavalo (o boneco senta na sela)
var _horse_kept: FormModel = null        # o mesmo cavalo volta a cada montada (criar um é caro)
var _shown_mount := false
const HORSE_SCALE := 1.75
const SADDLE_Y := 1.06                   # quanto o boneco sobe (sela do cavalo escalado − quadril do boneco)
const HORSE_COATS := [Color(0.55, 0.38, 0.24), Color(0.25, 0.18, 0.14), Color(0.9, 0.88, 0.84), Color(0.7, 0.45, 0.25), Color(0.5, 0.5, 0.52), Color(0.85, 0.7, 0.45)]         # Druida transformado: o bicho (o kit fica escondido)
const FORM_SCALE := {"wolf": 1.15, "bear": 1.4, "demon": 1.3}     # o bicho do druida é maior que o lobo comum
var _shown_form := ""
var _stealth_shown := false
var _alpha_shown := 0.0              # transparência aplicada (furtivo 0.7, forma fantasma 0.45)
var _last_flash := 0.0
var _flinch := 0.0
var _gather_shown := ""                  # forma do ponto que está colhendo (mostrado no boneco)                       # monstro apanhou: encolhe no clipe "hit" por um instante
var _fade_meshes: Array = []             # corpo some: malhas guardadas na hora da morte
var _last_status := Color(0, 0, 0, 0)
var _stun_fx: Node3D = null           # estrelas girando na cabeça
var _burn_fx: CPUParticles3D = null   # brasas subindo
var _chill_fx: MeshInstance3D = null  # anel de gelo nos pés (retardado/preso)
var nameplate: Label3D
var quest_mark: Label3D = null       # NPC: "!" quest nova, "?" entregar
var _mark_timer := 0.0
var _mark_y := 0.0
var hp_bar: Node3D
var hp_fill: MeshInstance3D
var shield_fill: MeshInstance3D
var cast_bar: Node3D
var cast_fill: MeshInstance3D
var block_shield: MeshInstance3D = null
var _kick := Vector3.ZERO            # deslocamento do golpe na guarda
var _guard_arc: MeshInstance3D = null    # arco no chão: o que a guarda cobre (só o jogador)
var weapon: Node3D = null
var _bob := 0.0
var _land_t := 0.0                    # pouso do pulo: tempo restante do clip "land"
var _was_air := false
var _smooth_pos: Vector3
var _arc_from := Vector3.ZERO          # salto/teleporte de skill: arco visual de _arc_from até a posição da sim
var _arc_t := 1.0
const ARC_TIME := 0.28
var _last_state := -1
var _is_player := false
var _base_scale := 1.0

## Golpe na guarda empurra o corpo para trás; aparar empurra mais.
func _on_shield_block(target_id: int, _attacker_id: int, _theme: String, parried: bool, _from: Vector3) -> void:
	if entity and target_id == entity.id:
		_kick = -entity.forward() * (0.3 if parried else 0.15)

## Sem escudo também sente o golpe na guarda, mais leve.
func _on_blocked(target_id: int) -> void:
	if entity and target_id == entity.id and not entity.stats.has_shield:
		_kick = -entity.forward() * 0.1

func setup(e: SimEntity, is_player: bool) -> void:
	Events.shield_block.connect(_on_shield_block)
	Events.blocked_hit.connect(_on_blocked)
	entity = e
	_is_player = is_player
	name = "E%d_%s" % [e.id, e.name]
	position = e.position
	_smooth_pos = e.position
	_base_scale = e.scale
	_build_model()
	_build_ui()
	if e.monster_def and e.monster_def.elite_of != "":
		_add_crown()

# ---------------------------------------------------------------------------
func _build_model() -> void:
	model_root = Node3D.new()
	model_root.name = "Model"
	add_child(model_root)
	# personagens e NPCs: kit modular com as peças do equipamento
	var body := ""
	if entity.class_def:
		body = str(entity.look.get("sex", entity.class_def.body_type))
	elif entity.kind == SimEntity.Kind.NPC and not entity.npc_data.has("model"):
		body = str(entity.look.get("sex", "male"))
	if KitModel.exists(body):
		var hair := entity.class_def.hair_color if entity.class_def else Color(entity.npc_data.get("color", Color(0.5, 0.36, 0.22))).darkened(0.4)
		kit = KitModel.create(body, hair, 0.025, entity.class_def.id if entity.class_def else "")
		model_root.add_child(kit)
		kit.apply_look(entity.look if not entity.look.is_empty() else {"hair": "long" if body == "female" else "short", "hair_color": hair.to_html(false)})
		anim = kit.anim
		_mats = kit.mats
		model_root.scale = Vector3.ONE * _base_scale
		kit.apply_equipment(entity.equipment, Color(entity.npc_data.get("color", Color(0.55, 0.42, 0.3))) if entity.kind == SimEntity.Kind.NPC else Color(0.55, 0.42, 0.3))
		return
	var model_name := ""
	if entity.class_def and entity.class_def.model != "":
		model_name = entity.class_def.model
	elif entity.monster_def and entity.monster_def.model != "":
		model_name = entity.monster_def.model
	elif entity.kind == SimEntity.Kind.NPC:
		model_name = entity.npc_data.get("model", "npc_villager")
	var path := "res://assets/models/%s.glb" % model_name
	if model_name != "" and ResourceLoader.exists(path):
		var scene: PackedScene = load(path)
		var inst := scene.instantiate()
		model_root.add_child(inst)
		anim = _find_anim(inst)
		if anim:
			# glTF chega sem loop; ciclos contínuos precisam de LOOP_LINEAR (recurso compartilhado, basta 1x)
			for a in ["idle", "run", "block", "block_shield"]:
				if anim.has_animation(a):
					anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		_apply_toon_recursive(inst)
		RigidMerge.merge(inst, model_name)  # peças rígidas -> 1 malha (draw calls); malha guardada por modelo
		model_root.scale = Vector3.ONE * _base_scale
		return
	_build_placeholder()

func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r:
			return r
	return null

## Monstro que usa o modelo de outro (Slime Azul em mob_slime, Presa-Rachada em mob_boar): o corpo puxa para a cor dele,
## medida contra a cor do monstro dono do modelo; olhos, brilho e chifre/presa não mudam. O dono do modelo fica como está.
const FIXED_MATS := ["m_eye", "m_white", "m_horn"]

static func monster_tint(mdef: MonsterDef, col: Color, mat_name: String) -> Color:
	if mdef == null or mdef.model == "" or mat_name in FIXED_MATS:
		return col
	var base: MonsterDef = GameData.monsters.get(mdef.model.trim_prefix("mob_"))
	if base == null or base == mdef or base.color.is_equal_approx(mdef.color):
		return col
	var v := clampf(col.v * (mdef.color.v / maxf(0.05, base.color.v)), 0.0, 1.0)
	return Color.from_hsv(mdef.color.h, lerpf(col.s, mdef.color.s, 0.75), v, col.a)

func _apply_toon_recursive(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in range(mi.get_surface_override_material_count()):
			var base := mi.get_active_material(i)
			var col := Color(0.8, 0.8, 0.8)
			if base is BaseMaterial3D:
				col = base.albedo_color
			if entity and entity.monster_def:
				col = monster_tint(entity.monster_def, col, base.resource_name if base else "")
			var tm := Materials.toon_unique(col)
			if base is BaseMaterial3D and base.albedo_texture:
				tm.set_shader_parameter("albedo_tex", base.albedo_texture)
			mi.set_surface_override_material(i, tm)
			_mats.append(tm)
			if mat == null:
				mat = tm
	for c in n.get_children():
		_apply_toon_recursive(c)

func _mesh(m: Mesh, color: Color, unique_mat: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	if unique_mat:
		if mat == null:
			mat = Materials.toon_unique(color)
		mi.material_override = mat
	else:
		mi.material_override = Materials.toon(color)
	return mi

func _build_placeholder() -> void:
	var color := Color(0.7, 0.7, 0.7)
	if entity.class_def:
		color = entity.class_def.color
	elif entity.monster_def:
		color = entity.monster_def.color
	elif entity.kind == SimEntity.Kind.NPC:
		color = entity.npc_data.get("color", Color(0.8, 0.75, 0.6))
	var s := _base_scale
	model_root.scale = Vector3.ONE * s

	if entity.monster_def:
		_build_monster(color)
		return
	# --- humanoide chibi (ToS): cabeça grande, corpo curto ---
	var body := CapsuleMesh.new()
	body.radius = 0.28
	body.height = 0.9
	var b := _mesh(body, color, true)
	b.position.y = 0.55
	model_root.add_child(b)
	var head := SphereMesh.new()
	head.radius = 0.34
	head.height = 0.68
	head.radial_segments = 10
	head.rings = 6
	var skin := Color(0.98, 0.85, 0.72)
	if entity.kind == SimEntity.Kind.SUMMON:
		skin = color
	var h := _mesh(head, skin)
	h.position.y = 1.3
	model_root.add_child(h)
	# cabelo/chapéu com a cor da classe
	var hair := SphereMesh.new()
	hair.radius = 0.36
	hair.height = 0.5
	hair.radial_segments = 10
	hair.rings = 5
	var hr := _mesh(hair, color.darkened(0.25))
	hr.position.y = 1.42
	model_root.add_child(hr)
	# olhos
	for sx in [-1.0, 1.0]:
		var eye := BoxMesh.new()
		eye.size = Vector3(0.07, 0.1, 0.03)
		var ey := MeshInstance3D.new()
		ey.mesh = eye
		ey.material_override = Materials.flat(Color(0.12, 0.1, 0.16))
		ey.position = Vector3(sx * 0.12, 1.3, 0.31)
		model_root.add_child(ey)
	# pés
	for sx in [-1.0, 1.0]:
		var foot := BoxMesh.new()
		foot.size = Vector3(0.18, 0.12, 0.3)
		var f := _mesh(foot, color.darkened(0.45))
		f.position = Vector3(sx * 0.14, 0.06, 0.05)
		f.name = "FootL" if sx < 0 else "FootR"
		model_root.add_child(f)
	_build_weapon(color)

func _build_weapon(color: Color) -> void:
	var wtype := ""
	if entity.class_def:
		var w = entity.equipment.get(ItemDef.Slot.WEAPON)
		if w:
			wtype = w.weapon_type
		elif entity.class_def.weapon_types.size() > 0:
			wtype = entity.class_def.weapon_types[0]
	if weapon:
		weapon.queue_free()
		weapon = null
	if block_shield:
		block_shield.queue_free()
		block_shield = null
	if wtype == "":
		return
	weapon = Node3D.new()
	weapon.name = "Weapon"
	weapon.position = Vector3(0.36, 0.7, 0.15)
	model_root.add_child(weapon)
	var metal := Color(0.8, 0.82, 0.88)
	var wood := Color(0.5, 0.35, 0.22)
	match wtype:
		"sword":
			var blade := _mesh(_box(0.08, 0.9, 0.03), metal); blade.position.y = 0.45; weapon.add_child(blade)
			var guard := _mesh(_box(0.3, 0.06, 0.06), Color(0.8, 0.65, 0.3)); weapon.add_child(guard)
			var grip := _mesh(_box(0.06, 0.25, 0.06), wood); grip.position.y = -0.14; weapon.add_child(grip)
		"mace":
			var shaft := _mesh(_box(0.06, 0.8, 0.06), wood); shaft.position.y = 0.3; weapon.add_child(shaft)
			var headm := SphereMesh.new(); headm.radius = 0.16; headm.height = 0.32; headm.radial_segments = 6; headm.rings = 3
			var hm := _mesh(headm, metal); hm.position.y = 0.75; weapon.add_child(hm)
		"axe2h":
			var shaft := _mesh(_box(0.07, 1.4, 0.07), wood); shaft.position.y = 0.4; weapon.add_child(shaft)
			var bl := _mesh(_box(0.5, 0.45, 0.05), metal); bl.position = Vector3(0.2, 0.95, 0); weapon.add_child(bl)
			weapon.position = Vector3(0.4, 0.5, 0.1)
		"staff":
			var shaft := _mesh(_box(0.06, 1.6, 0.06), wood); shaft.position.y = 0.5; weapon.add_child(shaft)
			var orb := SphereMesh.new(); orb.radius = 0.14; orb.height = 0.28; orb.radial_segments = 8; orb.rings = 4
			var o := MeshInstance3D.new(); o.mesh = orb; o.material_override = Materials.glow(color.lightened(0.3), 1.5); o.position.y = 1.35; weapon.add_child(o)
		"wand":
			var shaft := _mesh(_box(0.04, 0.6, 0.04), wood); shaft.position.y = 0.3; weapon.add_child(shaft)
			var orb := SphereMesh.new(); orb.radius = 0.1; orb.height = 0.2; orb.radial_segments = 8; orb.rings = 4
			var o := MeshInstance3D.new(); o.mesh = orb; o.material_override = Materials.glow(color.lightened(0.3), 1.5); o.position.y = 0.65; weapon.add_child(o)
		"bow":
			var limb := TorusMesh.new(); limb.inner_radius = 0.5; limb.outer_radius = 0.56; limb.rings = 12; limb.ring_segments = 4
			var l := _mesh(limb, wood); l.rotation.y = PI * 0.5; l.scale = Vector3(1, 1, 0.5); weapon.add_child(l)
			var str := _mesh(_box(0.01, 1.05, 0.01), Color(0.9, 0.9, 0.9)); str.position.z = -0.15; weapon.add_child(str)
			weapon.position = Vector3(-0.3, 0.75, 0.25)
		"dagger":
			var blade := _mesh(_box(0.05, 0.45, 0.02), metal); blade.position.y = 0.25; weapon.add_child(blade)
			var grip := _mesh(_box(0.05, 0.18, 0.05), wood); grip.position.y = -0.06; weapon.add_child(grip)
			var w2 := Node3D.new(); w2.position = Vector3(-0.72, 0, 0); weapon.add_child(w2)
			var blade2 := _mesh(_box(0.05, 0.45, 0.02), metal); blade2.position.y = 0.25; w2.add_child(blade2)
		"scythe":
			var shaft := _mesh(_box(0.06, 1.7, 0.06), Color(0.3, 0.25, 0.3)); shaft.position.y = 0.5; weapon.add_child(shaft)
			var bl := _mesh(_box(0.7, 0.14, 0.03), metal); bl.position = Vector3(0.3, 1.35, 0); bl.rotation.z = -0.25; weapon.add_child(bl)
	# escudo
	var off = entity.equipment.get(ItemDef.Slot.OFFHAND)
	if off and off.weapon_type == "shield":
		var sh := BoxMesh.new()
		sh.size = Vector3(0.45, 0.6, 0.08)
		block_shield = _mesh(sh, off.icon_color)
		block_shield.position = Vector3(-0.38, 0.75, 0.1)
		model_root.add_child(block_shield)

func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b

func _build_monster(color: Color) -> void:
	var md := entity.monster_def
	match md.shape:
		"sphere":
			var sm := SphereMesh.new(); sm.radius = 0.5; sm.height = 0.8; sm.radial_segments = 10; sm.rings = 6
			var m := _mesh(sm, color, true); m.position.y = 0.4; model_root.add_child(m)
			for sx in [-1.0, 1.0]:
				var eye := SphereMesh.new(); eye.radius = 0.08; eye.height = 0.16; eye.radial_segments = 6; eye.rings = 3
				var ey := MeshInstance3D.new(); ey.mesh = eye; ey.material_override = Materials.flat(Color(0.1, 0.1, 0.15))
				ey.position = Vector3(sx * 0.18, 0.5, 0.42); model_root.add_child(ey)
		"box":
			var body := BoxMesh.new(); body.size = Vector3(0.9, 0.6, 1.3)
			var b := _mesh(body, color, true); b.position.y = 0.55; model_root.add_child(b)
			var head := BoxMesh.new(); head.size = Vector3(0.6, 0.5, 0.6)
			var h := _mesh(head, color.lightened(0.1)); h.position = Vector3(0, 0.7, 0.85); model_root.add_child(h)
			for sx in [-1.0, 1.0]:
				for sz in [-0.4, 0.4]:
					var leg := BoxMesh.new(); leg.size = Vector3(0.2, 0.45, 0.2)
					var l := _mesh(leg, color.darkened(0.3)); l.position = Vector3(sx * 0.3, 0.22, sz); model_root.add_child(l)
			for sx in [-1.0, 1.0]:
				var eye := BoxMesh.new(); eye.size = Vector3(0.08, 0.08, 0.04)
				var ey := MeshInstance3D.new(); ey.mesh = eye; ey.material_override = Materials.flat(Color(1, 0.3, 0.2))
				ey.position = Vector3(sx * 0.18, 0.78, 1.16); model_root.add_child(ey)
		"cone":
			var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 0.5; cm.height = 1.4; cm.radial_segments = 8
			var c := _mesh(cm, color, true); c.position.y = 1.0; c.rotation.x = PI; model_root.add_child(c)
			var head := SphereMesh.new(); head.radius = 0.35; head.height = 0.7; head.radial_segments = 8; head.rings = 4
			var h := _mesh(head, color.lightened(0.2)); h.position.y = 1.75; model_root.add_child(h)
			for sx in [-1.0, 1.0]:
				var eye := BoxMesh.new(); eye.size = Vector3(0.08, 0.12, 0.04)
				var ey := MeshInstance3D.new(); ey.mesh = eye; ey.material_override = Materials.flat(Color(0.2, 0.1, 0.3))
				ey.position = Vector3(sx * 0.12, 1.78, 0.33); model_root.add_child(ey)
		_:  # capsule (bandidos, esqueletos)
			var body := CapsuleMesh.new(); body.radius = 0.3; body.height = 1.0
			var b := _mesh(body, color, true); b.position.y = 0.6; model_root.add_child(b)
			var head := SphereMesh.new(); head.radius = 0.3; head.height = 0.6; head.radial_segments = 8; head.rings = 4
			var h := _mesh(head, color.lightened(0.15)); h.position.y = 1.35; model_root.add_child(h)
			for sx in [-1.0, 1.0]:
				var eye := BoxMesh.new(); eye.size = Vector3(0.07, 0.09, 0.03)
				var ey := MeshInstance3D.new(); ey.mesh = eye; ey.material_override = Materials.flat(Color(0.9, 0.2, 0.2))
				ey.position = Vector3(sx * 0.11, 1.37, 0.28); model_root.add_child(ey)
			var wpn := _mesh(_box(0.07, 0.8, 0.04), Color(0.75, 0.75, 0.8)); wpn.position = Vector3(0.38, 0.9, 0.1); model_root.add_child(wpn)
	if md.is_boss:
		var crown := CylinderMesh.new(); crown.top_radius = 0.3; crown.bottom_radius = 0.22; crown.height = 0.25; crown.radial_segments = 5
		var c := MeshInstance3D.new(); c.mesh = crown; c.material_override = Materials.glow(Color(1, 0.85, 0.3), 1.2)
		c.position.y = 1.0 if md.shape == "box" else 1.75
		model_root.add_child(c)

# ---------------------------------------------------------------------------
func _build_ui() -> void:
	var top := 1.95 * _base_scale
	if entity.monster_def and entity.monster_def.shape in ["sphere", "box"]:
		top = 1.4 * _base_scale
	nameplate = Label3D.new()
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.no_depth_test = true
	nameplate.font_size = 52
	nameplate.pixel_size = 0.003
	nameplate.outline_size = 14
	nameplate.position.y = top + 0.45
	nameplate.fixed_size = false
	add_child(nameplate)
	_refresh_nameplate()
	if entity.kind == SimEntity.Kind.NPC:
		_mark_y = top + 1.25
		quest_mark = Label3D.new()
		quest_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		quest_mark.no_depth_test = true
		quest_mark.font_size = 150
		quest_mark.font = UiKit.mark_font()
		quest_mark.pixel_size = 0.0065
		quest_mark.outline_size = 34
		quest_mark.outline_modulate = Color(0.16, 0.1, 0.04)
		quest_mark.position.y = _mark_y
		quest_mark.visible = false
		add_child(quest_mark)

	if entity.kind != SimEntity.Kind.NPC:
		hp_bar = Node3D.new()
		hp_bar.position.y = top + 0.2
		add_child(hp_bar)
		var bg := _quad(1.0, 0.09, Color(0.1, 0.08, 0.12, 0.85))
		hp_bar.add_child(bg)
		var fill_col := Color(0.35, 0.85, 0.4)
		if entity.kind == SimEntity.Kind.MONSTER:
			fill_col = Color(0.9, 0.3, 0.3)
		elif entity.kind == SimEntity.Kind.BOT:
			fill_col = Color(0.4, 0.75, 0.95)
		hp_fill = _quad(1.0, 0.07, fill_col, 1)
		hp_fill.position.z = 0.001
		hp_bar.add_child(hp_fill)
		shield_fill = _quad(1.0, 0.03, Color(0.95, 0.9, 0.5), 2)
		shield_fill.position = Vector3(0, 0.05, 0.002)
		hp_bar.add_child(shield_fill)
		cast_bar = Node3D.new()
		cast_bar.position.y = top + 0.08
		cast_bar.visible = false
		add_child(cast_bar)
		cast_bar.add_child(_quad(0.8, 0.05, Color(0.1, 0.08, 0.12, 0.85)))
		cast_fill = _quad(0.8, 0.035, Color(1, 0.85, 0.4), 1)
		cast_fill.position.z = 0.001
		cast_bar.add_child(cast_fill)

## Quad de barra (billboard, sem profundidade). `layer`: ordem de desenho — fundo 0, preenchimento 1, escudo 2.
## (fundo e preenchimento ficam a 1 mm um do outro: sem prioridade explícita a ordenação por distância
## às vezes desenhava o fundo por cima e a barra parecia vazia, "morto")
func _quad(w: float, h: float, color: Color, layer: int = 0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.render_priority = 2 + layer
	m.disable_fog = true
	mi.material_override = m
	return mi

func _refresh_nameplate() -> void:
	var txt := entity.name
	var col := Color.WHITE
	match entity.kind:
		SimEntity.Kind.PLAYER:
			col = Color(1, 0.95, 0.6)
			txt = "%s\n%s" % [entity.name, entity.display_title()]
		SimEntity.Kind.BOT:
			col = Color(0.55, 1.0, 0.6) if _is_party_mate() else Color(0.75, 0.9, 1.0)
			txt = "%s\n%s" % [entity.name, entity.display_title()]
		SimEntity.Kind.MONSTER:
			col = level_color(entity.level, Sim.player.level if Sim.player else entity.level) if not entity.monster_def.is_boss else Color(1, 0.8, 0.3)
			txt = "%s %s" % [entity.name, entity.display_title()]
		SimEntity.Kind.NPC:
			col = Color(0.7, 1.0, 0.75)
			txt = "[%s]\n%s" % [_npc_role_label(), entity.name]
		SimEntity.Kind.SUMMON:
			col = Color(0.7, 0.95, 0.85)
	nameplate.text = txt
	nameplate.modulate = col

## Cor do nome do monstro pelo nível comparado ao do jogador: cinza (fácil demais), verde, branco, amarelo, laranja, vermelho.
static func level_color(mob_lv: int, player_lv: int) -> Color:
	var d := mob_lv - player_lv
	if d <= -6:
		return Color(0.62, 0.62, 0.62)
	if d <= -3:
		return Color(0.55, 0.95, 0.5)
	if d <= 1:
		return Color(0.98, 0.95, 0.9)
	if d <= 3:
		return Color(1.0, 0.88, 0.35)
	if d <= 5:
		return Color(1.0, 0.6, 0.25)
	return Color(1.0, 0.3, 0.25)

## Corpo de monstro afunda e some no último segundo antes de sair do mundo.
func _corpse_fade() -> void:
	if entity.is_alive():
		return
	var left := Balance.CORPSE_TIME - entity.dead_time
	if left > 0.9:
		return
	if _fade_meshes.is_empty():
		_fade_meshes = model_root.find_children("*", "GeometryInstance3D", true, false)
	var k := clampf(1.0 - left / 0.9, 0.0, 1.0)
	for g in _fade_meshes:
		if is_instance_valid(g):
			(g as GeometryInstance3D).transparency = k
	model_root.position.y = -0.5 * k

## Do grupo do jogador (nome verde, como nos MMOs).
func _is_party_mate() -> bool:
	return entity.kind != SimEntity.Kind.PLAYER and Sim.player != null and Sim.same_party(entity, Sim.player)

func _npc_role_label() -> String:
	match entity.npc_data.get("role", ""):
		"quest": return "Quest"
		"smith": return "Ferreiro"
		"alchemy": return "Alquimista"
		"merchant": return "Mercador"
		"storage": return "Depósito"
		"relic": return "Relicária"
		"board": return "Quadro"
		"guard": return "Guarda"
		"villager": return "Morador"
	return "NPC"

## Monta/desmonta: cavalo embaixo, boneco sobe para a sela com a pose de cavalgar.
func _swap_mount() -> void:
	_shown_mount = entity.mounted
	if horse:                      # desce: o cavalo fica guardado (escondido, parado) para a próxima montada
		horse.visible = false
		horse.process_mode = Node.PROCESS_MODE_DISABLED
		horse = null
	kit.transform = Transform3D.IDENTITY
	if not _shown_mount:
		return
	if _horse_kept == null:
		_horse_kept = FormModel.create_from("res://assets/models/mob_horse.glb")
		if _horse_kept == null:
			return
		_horse_kept.scale = Vector3.ONE * HORSE_SCALE / maxf(_base_scale, 0.01)
		# o bicho já olha para +Z (frente do boneco)
		_horse_kept.paint(HORSE_COATS[entity.id % HORSE_COATS.size()])
		RigidMerge.merge(_horse_kept, "mob_horse")
		model_root.add_child(_horse_kept)
	horse = _horse_kept
	horse.visible = true
	horse.process_mode = Node.PROCESS_MODE_INHERIT
	kit.position.y = SADDLE_Y / maxf(_base_scale, 0.01)
	RidePose.ensure_clip(kit.anim, kit.skeleton)

## O boneco acompanha o lombo do cavalo (sobe/desce e balança no galope).
func _ride_saddle() -> void:
	var base := Transform3D(Basis.IDENTITY, Vector3(0, SADDLE_Y / maxf(_base_scale, 0.01), 0))
	kit.global_transform = horse.bone_delta("body") * model_root.global_transform * base
	kit.scale = Vector3.ONE

## Druida: entra/sai da forma de animal (esconde o kit e anima o bicho, com a armadura de animal do conjunto).
func _swap_form() -> void:
	_shown_form = entity.form
	if form_view:
		form_view.queue_free()
		form_view = null
	_act_skill = null
	if _shown_form == "" or not FormModel.exists(_shown_form):
		kit.visible = true
		anim = kit.anim
		_mats = kit.mats
		return
	form_view = FormModel.create(_shown_form)
	form_view.scale = Vector3.ONE * float(FORM_SCALE.get(_shown_form, 1.0))
	model_root.add_child(form_view)
	form_view.apply_equipment(entity.equipment)
	kit.visible = false
	kit.trail_on = false
	anim = form_view.anim
	_mats = form_view.mats
	_stealth_shown = not (entity.stealth_left > 0.0)     # reaplica a transparência nas malhas novas
	_alpha_shown = -1.0

func refresh_equipment() -> void:
	_alpha_shown = -1.0            # peças novas do kit entram na árvore agora: reaplica a transparência (furtivo/fantasma)
	if form_view:
		form_view.apply_equipment(entity.equipment)
	if kit:
		var bare := Color(entity.npc_data.get("color", Color(0.55, 0.42, 0.3))) if entity.kind == SimEntity.Kind.NPC else Color(0.55, 0.42, 0.3)
		kit.apply_equipment(entity.equipment, bare)
	elif anim == null and entity.class_def:
		_build_weapon(entity.class_def.color)
	_refresh_nameplate()

# ---------------------------------------------------------------------------
## Marcador de quest: reconsulta 4x por segundo (cobre nível, itens, aceitar, entregar e save carregado) e flutua.
func _update_quest_mark(delta: float) -> void:
	_mark_timer -= delta
	if _mark_timer <= 0.0:
		_mark_timer = 0.25
		var mark: String = QuestSystem.npc_marker(Sim.player, entity.npc_data.get("id", "")) if Sim.player else ""
		quest_mark.text = UiKit.quest_mark_text(mark)
		quest_mark.modulate = UiKit.quest_mark_color(mark)
		quest_mark.visible = mark != ""
	quest_mark.position.y = _mark_y + sin(Time.get_ticks_msec() * 0.004) * 0.12

static var prof_us := 0.0
static var anim_lod := true
static var anim_test := false      # --anim_test: todo mundo a 1/3 (medir o custo da animação)        # --no_anim_lod desliga (medir)
var _anim_acc := 0.0
var _anim_frame := 0
var _lod_anim: AnimationMixer = null

## LOD de animação: perto da câmera o esqueleto anda todo quadro; mais longe, a cada 2 ou 3 quadros
## (o mixer em modo manual recebe o tempo somado). Jogador e golpes (estado não parado/andando) sempre cheios.
func _anim_lod(delta: float) -> void:
	if anim == null:
		return
	if _lod_anim != anim:
		if _lod_anim and is_instance_valid(_lod_anim):
			_lod_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
		_lod_anim = anim
		_anim_acc = 0.0
	var every := 1
	if anim_lod and entity.kind != SimEntity.Kind.PLAYER and entity.state in [SimEntity.State.IDLE, SimEntity.State.MOVING]:
		var cam := get_viewport().get_camera_3d()
		if cam:
			var d2 := cam.global_position.distance_squared_to(global_position)
			every = 1 if d2 < 26.0 * 26.0 else (2 if d2 < 40.0 * 40.0 else 3)
			if anim_test:
				every = 3
	if every == 1:
		if anim.callback_mode_process != AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE:
			anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
			if _anim_acc > 0.0:
				anim.advance(_anim_acc)
			_anim_acc = 0.0
		return
	if anim.callback_mode_process != AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL:
		anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_anim_acc += delta
	_anim_frame += 1
	if (_anim_frame + entity.id) % every == 0:
		anim.advance(_anim_acc)
		_anim_acc = 0.0          # --perf: soma do tempo de _process de todos os bonecos

func _process(delta: float) -> void:
	if entity == null:
		return
	var _t0 := Time.get_ticks_usec()
	_process_view(delta)
	prof_us += Time.get_ticks_usec() - _t0

func _process_view(delta: float) -> void:
	if quest_mark:
		_update_quest_mark(delta)
	# posição suavizada (a sim roda a 60Hz; interpola um pouco)
	# salto de skill (a sim teleporta): mostra um arco em vez de piscar no destino
	if entity.state == SimEntity.State.CASTING and _smooth_pos.distance_to(entity.position) > 2.5 and _arc_t >= 1.0:
		_arc_from = _smooth_pos
		_arc_t = 0.0
	var lift := 0.0
	if _arc_t < 1.0:
		_arc_t = minf(1.0, _arc_t + delta / ARC_TIME)
		_smooth_pos = _arc_from.lerp(entity.position, _arc_t)
		lift = sin(_arc_t * PI) * minf(2.2, _arc_from.distance_to(entity.position) * 0.35)
	else:
		_smooth_pos = _smooth_pos.lerp(entity.position, minf(1.0, delta * 28.0))
	position = _smooth_pos + Vector3(0, entity.jump_h + lift, 0)   # pulo: a sim guarda só a altura
	var target_rot := entity.facing
	if entity.kind != SimEntity.Kind.PLAYER and entity.kind != SimEntity.Kind.BOT:
		target_rot = entity.facing
	model_root.rotation.y = lerp_angle(model_root.rotation.y, target_rot, minf(1.0, delta * 18.0))
	if kit and entity.form != _shown_form:
		_swap_form()
	if kit and entity.mounted != _shown_mount:
		_swap_mount()
	var want_alpha := 0.7 if entity.stealth_left > 0.0 else (0.45 if entity.form == "phantom" else 0.0)     # furtivo quase some; fantasma translúcido
	if (entity.stealth_left > 0.0) != _stealth_shown or not is_equal_approx(want_alpha, _alpha_shown):
		_stealth_shown = entity.stealth_left > 0.0
		_alpha_shown = want_alpha
		for mi in model_root.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).transparency = want_alpha
	_animate(delta)
	_anim_lod(delta)
	_update_bars()
	var flash := 1.0 if entity.hit_flash > 0.0 else 0.0
	if entity.kind == SimEntity.Kind.MONSTER:
		if flash > 0.0 and _last_flash == 0.0 and entity.is_alive():
			_flinch = 0.22
		_flinch = maxf(0.0, _flinch - delta)
		_corpse_fade()
	if not _mats.is_empty():
		if flash != _last_flash:
			_last_flash = flash
			for m in _mats:
				m.set_shader_parameter("flash", flash)
	elif mat:
		mat.set_shader_parameter("flash", flash)
	_update_status()
	var ally := _is_party_mate()
	var plv: int = Sim.player.level if Sim.player else 0
	if entity.level != int(nameplate.get_meta("lv", -1)) or ally != bool(nameplate.get_meta("ally", false)) or plv != int(nameplate.get_meta("plv", -1)):
		nameplate.set_meta("plv", plv)
		nameplate.set_meta("lv", entity.level)
		nameplate.set_meta("ally", ally)
		_refresh_nameplate()

## Estados que o jogador precisa ler de longe: atordoado (estrelas), queimando (brasas + laranja), retardado/preso (anel de gelo + azul).
func _update_status() -> void:
	var stunned := entity.state == SimEntity.State.STUNNED and entity.is_alive()
	var burning := false
	var chill := 0                       # 0 nada, 1 retardado, 2 preso
	if entity.is_alive():
		for d in entity.debuffs:
			match d.get("kind"):
				"dot":
					burning = burning or bool(d.get("fire", false))
				"slow":
					chill = maxi(chill, 1)
				"root":
					chill = 2
	if stunned and _stun_fx == null:
		_stun_fx = _make_stars()
	if _stun_fx:
		_stun_fx.visible = stunned
		if stunned:
			_stun_fx.rotation.y += get_process_delta_time() * 5.0
	if burning and _burn_fx == null:
		_burn_fx = _make_embers()
	if _burn_fx:
		_burn_fx.emitting = burning
	if chill > 0 and _chill_fx == null:
		_chill_fx = _make_frost_ring()
	if _chill_fx:
		_chill_fx.visible = chill > 0
		if chill > 0:
			(_chill_fx.material_override as StandardMaterial3D).albedo_color.a = 0.4 if chill == 1 else 0.75
	var st := Color(0, 0, 0, 0)
	if chill > 0:
		st = Color(0.55, 0.85, 1.0, 0.35 if chill == 1 else 0.55)
	elif burning:
		st = Color(1.0, 0.45, 0.12, 0.22 + 0.12 * sin(Time.get_ticks_msec() * 0.018))
	if st != _last_status:
		_last_status = st
		if not _mats.is_empty():
			for m in _mats:
				m.set_shader_parameter("status", st)
		elif mat:
			mat.set_shader_parameter("status", st)

## Rei (surge depois de muitos abates): coroa dourada flutuando sobre a cabeça, lida de longe pela câmera alta.
func _add_crown() -> void:
	var crown := Node3D.new()
	crown.name = "Crown"
	crown.position.y = _status_head() - 0.1
	var gold := Materials.toon(Color(1.0, 0.8, 0.25))
	var band := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.3; cm.bottom_radius = 0.26; cm.height = 0.14; cm.radial_segments = 16
	band.mesh = cm
	band.material_override = gold
	crown.add_child(band)
	for i in range(5):
		var spike := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.0; sm.bottom_radius = 0.07; sm.height = 0.2; sm.radial_segments = 6
		spike.mesh = sm
		spike.material_override = gold
		spike.position = Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 5.0) * 0.26 + Vector3(0, 0.16, 0)
		crown.add_child(spike)
		var gem := MeshInstance3D.new()
		var gs := SphereMesh.new()
		gs.radius = 0.045; gs.height = 0.09
		gem.mesh = gs
		gem.material_override = Materials.glow(Color(0.9, 0.2, 0.3), 1.2)
		gem.position = Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 5.0) * 0.29
		crown.add_child(gem)
	add_child(crown)

func _status_head() -> float:
	return (hp_bar.position.y - 0.25) if hp_bar else 2.0 * _base_scale

func _make_stars() -> Node3D:
	var n := Node3D.new()
	n.position.y = _status_head()
	for i in range(3):
		var l := Label3D.new()
		l.text = "★"
		l.font_size = 56
		l.pixel_size = 0.006
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.modulate = Color(1.0, 0.9, 0.3)
		l.outline_size = 10
		l.outline_modulate = Color(0.25, 0.15, 0.0)
		l.position = Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 3.0) * 0.38
		n.add_child(l)
	add_child(n)
	return n

func _make_embers() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 0.7
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.35 * _base_scale
	p.position.y = 0.8 * _base_scale
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0, 1.5, 0)
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.4
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.3, 1.0))
	g.set_color(1, Color(0.9, 0.2, 0.05, 0.0))
	p.color_ramp = g
	add_child(p)
	return p

func _make_frost_ring() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	var r := maxf(0.45, entity.radius + 0.15)
	t.inner_radius = r
	t.outer_radius = r + 0.14
	t.rings = 24
	t.ring_segments = 6
	mi.mesh = t
	mi.scale = Vector3(1.0, 0.25, 1.0)
	mi.position.y = 0.05
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.6, 0.9, 1.0, 0.5)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _update_bars() -> void:
	if hp_bar == null:
		return
	var ratio := clampf(entity.hp / maxf(1.0, entity.stats.max_hp), 0.0, 1.0)
	_set_bar(hp_fill, ratio, 1.0)
	var sr := clampf(entity.shield_hp / maxf(1.0, entity.stats.max_hp), 0.0, 1.0)
	shield_fill.visible = sr > 0.0
	_set_bar(shield_fill, sr, 1.0)
	hp_bar.visible = entity.is_alive() and (entity.kind != SimEntity.Kind.MONSTER or ratio < 1.0 or entity.aggro_target >= 0)
	var casting := entity.state == SimEntity.State.CASTING and entity.current_skill != null and entity.current_skill.startup > 0.2
	cast_bar.visible = casting and entity.skill_phase == "startup"
	if cast_bar.visible:
		var r := clampf(entity.state_time / entity.current_skill.startup, 0.0, 1.0)
		_set_bar(cast_fill, r, 0.8)

## Barra sobre a cabeça: o material é billboard (sempre de frente para a câmera), e billboard ignora a escala do nó —
## por isso a barra muda a largura da própria malha e desloca o centro: esvazia da direita para a esquerda.
func _set_bar(mi: MeshInstance3D, ratio: float, width: float) -> void:
	var q := mi.mesh as QuadMesh
	var w := maxf(0.001, ratio) * width
	if is_equal_approx(q.size.x, w):
		return
	q.size.x = w
	q.center_offset.x = -(width - w) * 0.5

## Leque plano à frente, do tamanho de Balance.BLOCK_ARC_DEG.
func _build_guard_arc() -> void:
	var half := deg_to_rad(Balance.BLOCK_ARC_DEG * 0.5)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 24
	for i in range(steps):
		var a0 := lerpf(-half, half, float(i) / steps)
		var a1 := lerpf(-half, half, float(i + 1) / steps)
		for p in [Vector2(0.45, a0), Vector2(1.9, a0), Vector2(1.9, a1), Vector2(0.45, a0), Vector2(1.9, a1), Vector2(0.45, a1)]:
			st.add_vertex(Vector3(sin(p.y) * p.x, 0.07, cos(p.y) * p.x))
	_guard_arc = MeshInstance3D.new()
	_guard_arc.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.62, 0.1, 0.5)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_guard_arc.material_override = m
	_guard_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_guard_arc.top_level = true
	add_child(_guard_arc)

func _update_guard_arc() -> void:
	if not _is_player:
		return
	if _guard_arc == null:
		_build_guard_arc()
	_guard_arc.visible = entity.is_blocking
	if entity.is_blocking:
		_guard_arc.global_position = global_position
		_guard_arc.global_rotation = Vector3(0, entity.facing, 0)

func _animate(delta: float) -> void:
	var st := entity.state
	# empurrão do golpe na guarda: entra em dois quadros e some sozinho (vale para modelo e placeholder)
	model_root.position.x = lerpf(model_root.position.x, _kick.x, minf(1.0, delta * 30.0))
	model_root.position.z = lerpf(model_root.position.z, _kick.z, minf(1.0, delta * 30.0))
	_update_guard_arc()
	_kick = _kick.lerp(Vector3.ZERO, minf(1.0, delta * 12.0))
	if anim:
		_animate_glb(st)
		return
	# --- animação procedural do placeholder ---
	var speed := entity.velocity.length()
	var moving := speed > 0.1 and st in [SimEntity.State.MOVING, SimEntity.State.BLOCKING]
	if moving:
		_bob += delta * 14.0
	else:
		_bob = lerpf(_bob, round(_bob / PI) * PI, minf(1.0, delta * 10.0))
	var y := absf(sin(_bob)) * 0.08 if moving else 0.0
	var tilt := 0.0
	var lunge := 0.0
	var scale_y := 1.0
	match st:
		SimEntity.State.CASTING:
			var s := entity.current_skill
			if s:
				var t := entity.state_time
				if t < s.startup:
					tilt = -0.25 * (t / s.startup)                 # puxa pra trás
					scale_y = 1.0 + 0.06 * (t / s.startup)
				elif t < s.startup + s.active + 0.08:
					tilt = 0.45                                     # avança
					lunge = 0.25
				else:
					var r := (t - s.startup - s.active) / maxf(0.01, s.recovery)
					tilt = 0.45 * (1.0 - r)
					lunge = 0.25 * (1.0 - r)
				if s.kind == SkillDef.Kind.MAGICAL or s.kind == SkillDef.Kind.HEAL or s.kind == SkillDef.Kind.SUMMON:
					tilt *= 0.3
					y += 0.1 * sin(entity.state_time * 20.0)
		SimEntity.State.BLOCKING:
			tilt = 0.12
		SimEntity.State.DASHING:
			tilt = 0.5
			scale_y = 0.85
		SimEntity.State.STUNNED:
			tilt = 0.15 * sin(entity.state_time * 25.0)
		SimEntity.State.DEAD:
			var d := clampf(entity.dead_time / 0.5, 0.0, 1.0)
			model_root.rotation.x = lerpf(model_root.rotation.x, -PI * 0.5, minf(1.0, delta * 8.0))
			model_root.position.y = -d * 0.4
			model_root.scale = Vector3.ONE * _base_scale
			return
	model_root.rotation.x = lerpf(model_root.rotation.x, tilt, minf(1.0, delta * 22.0))
	model_root.position.y = lerpf(model_root.position.y, y, minf(1.0, delta * 20.0))
	model_root.scale = Vector3(1.0, scale_y, 1.0) * _base_scale
	if block_shield:
		block_shield.position.x = lerpf(block_shield.position.x, -0.05 if entity.is_blocking else -0.38, minf(1.0, delta * 15.0))
		block_shield.position.z = lerpf(block_shield.position.z, 0.45 if entity.is_blocking else 0.1, minf(1.0, delta * 15.0))
	if weapon:
		weapon.rotation.x = lerpf(weapon.rotation.x, -1.2 if lunge > 0.0 else 0.0, minf(1.0, delta * 25.0))
	var fl := model_root.get_node_or_null("FootL")
	var fr := model_root.get_node_or_null("FootR")
	if fl and fr:
		fl.position.z = sin(_bob) * 0.18 if moving else lerpf(fl.position.z, 0.05, minf(1.0, delta * 10.0))
		fr.position.z = -sin(_bob) * 0.18 if moving else lerpf(fr.position.z, 0.05, minf(1.0, delta * 10.0))

## frame (24 fps, base 1) do impacto de cada golpe do kit (tools/blender/chibi_kit.py: IMPACT)
const IMPACT_FRAME := {"maul": 7, "pounce": 9, "slam": 8, "roar": 7, "brace": 6, "atk_rifle": 6, "atk_1h_a": 7, "atk_1h_b": 7, "atk_2h": 10, "atk_dual_a": 5, "atk_dual_b": 5, "atk_dagger": 5,
	"atk_bow": 8, "atk_staff": 7, "atk_spin": 8, "atk_thrust": 6, "cast": 10, "cast_buff": 8, "attack": 5,
	"cast_ground": 10, "cast_channel": 14, "cast_target": 8, "atk_leap": 12, "atk_charge": 5, "atk_throw": 7,
	"atk_shoot_multi": 8, "summon": 11, "atk_sweep": 8, "atk_finisher": 10, "atk_flurry": 5, "atk_claw": 6, "shout": 7,
	"cast_fire": 8, "cast_ice": 8, "cast_bolt": 7, "cast_holy": 8, "cast_shadow": 8, "cast_nature": 9,
	"buff_power": 7, "buff_guard": 6, "buff_focus": 8}
const RUN_REF_SPEED := 5.2            # m/s em que o ciclo "run" do kit casa com o chão
const TWO_HANDED_MELEE := ["sword2h", "mace2h", "axe2h", "scythe"]
var _act_skill: SkillDef = null      # skill da ação atual (detecta golpe novo)
var _act_time := 0.0
var _combo := 0                       # alterna golpe A/B (combo de 2) e mão direita/esquerda
var _act_speed := 1.0                 # velocidade do clipe na preparação
var _retimed := false                 # depois do impacto o resto do clipe cabe no resto da skill

## Clip de golpe/magia para a skill: primeiro pela FORMA da skill (salto, investida, arremesso, magia no chão,
## canalizada, no alvo, invocação, leque de flechas), depois pela família da arma empunhada.
## Gestos de fase ativa longa (giro, canalização, pisão): repetem até a fase ativa acabar em vez de parar na pose final.
const ACTIVE_LOOP := ["atk_spin", "cast_channel", "cast_shadow", "slam"]
## Velocidade do clipe para o impacto do desenho cair no tick do dano (preparo longo = clipe mais lento).
const LOOP_MIN_ACTIVE := 0.5        # s de fase ativa para o gesto repetir (curta: acaba junto com a skill, como os outros)
const ANIM_MIN_SPEED := 0.4
const HELD_BASIC_MIN_SPEED := 0.35   # ataque segurado: a volta do golpe pode ir até 0,35x para emendar no próximo
const ANIM_MAX_SPEED := 3.2
const LEAP_IDS := ["leap", "pounce", "shadowstep", "stampede"]
const SHOUT_IDS := ["warcry", "taunt"]
const FINISHER_IDS := ["execute", "decapitate", "assassinate", "overhead", "butcher", "grim", "headshot"]
const FLURRY_IDS := ["flurry", "thousand", "twin", "hack", "dance", "backstab", "eviscerate"]
const CLAW_IDS := ["claw", "rend", "savage", "maul"]
const GUARD_IDS := ["shield", "armor", "skin", "ward", "bark", "wall", "aegis", "martyr"]
## gesto por elemento (magias e curas)
const CAST_BY_THEME := {"fire": "cast_fire", "ice": "cast_ice", "lightning": "cast_bolt", "holy": "cast_holy", "heal": "cast_holy", "shadow": "cast_shadow",
	"bone": "cast_shadow", "poison": "cast_shadow", "nature": "cast_nature", "lunar": "cast_nature", "earth": "cast_nature", "wind": "cast_ice", "summon": "summon"}

static func _has_token(id: String, tokens: Array) -> bool:
	return tokens.any(func(t): return t in id)

## Buff por intenção: guardar, sagrado, força ou foco.
func _buff_clip(s: SkillDef) -> String:
	if s.effects.has("shield") or _has_token(s.id, GUARD_IDS):
		return "buff_guard"
	if s.vfx == "holy":
		return "cast_holy"
	if s.vfx in ["blood", "earth"]:
		return "buff_power"
	if s.vfx == "nature":
		return "cast_nature"
	return "buff_focus"
const THROW_IDS := ["throw", "dart", "fan", "net", "trap"]
func _action_clip(s: SkillDef) -> String:
	if s == null:
		return "attack"
	var basic := s.id.begins_with("basic_")
	if basic and form_view and not anim.has_animation("atk_1h_a"):
		return "attack"                   # bicho: o básico é a mordida dele
	var w := entity.stats.weapon_type if entity.stats else ""
	var off := entity.stats.offhand_type if entity.stats else ""
	if not basic:
		if "disengage" in s.id:
			return "jump"                 # salto pra trás
		if _has_token(s.id, SHOUT_IDS):
			return "shout"
		if "kick" in s.id:
			return "atk_thrust"
		for k in LEAP_IDS:
			if k in s.id:
				return "atk_charge" if s.startup < 0.15 else "atk_leap"      # salto instantâneo (sombra): avanço curto
		if s.effects.has("channel"):
			return "cast_channel"
		for k in THROW_IDS:
			if k in s.id:
				return "atk_throw"
		if s.kind == SkillDef.Kind.SUMMON:
			return "summon"
		if s.kind == SkillDef.Kind.BUFF:
			return _buff_clip(s)
		if s.kind in [SkillDef.Kind.MAGICAL, SkillDef.Kind.HEAL] and CAST_BY_THEME.has(s.vfx) and not s.effects.has("dash"):
			return CAST_BY_THEME[s.vfx]
		if s.effects.has("dash") and s.kind == SkillDef.Kind.PHYSICAL:
			return "atk_charge"
		if s.kind == SkillDef.Kind.PHYSICAL and w not in ["bow", "rifle"]:
			if _has_token(s.id, FINISHER_IDS):
				return "atk_finisher"
			if _has_token(s.id, CLAW_IDS):
				return "atk_claw"
			if _has_token(s.id, FLURRY_IDS):
				return "atk_flurry"
			if s.target == SkillDef.Target.CONE:
				return "atk_sweep"
		if w == "bow" and s.target in [SkillDef.Target.CONE, SkillDef.Target.GROUND] and s.radius >= 3.0:
			return "atk_shoot_multi"
	match s.kind:
		SkillDef.Kind.BUFF:
			return "cast_target" if s.target == SkillDef.Target.TARGET else "cast_buff"
		SkillDef.Kind.HEAL:
			return "cast_target" if s.target == SkillDef.Target.TARGET else "cast_buff"
		SkillDef.Kind.MAGICAL, SkillDef.Kind.SUMMON:
			if basic:
				return "atk_staff" if w in ["staff", "wand", "scythe", "scepter", ""] or off == "orb" else ("atk_2h" if w in TWO_HANDED_MELEE else "atk_1h_a")
			if s.target == SkillDef.Target.GROUND:
				return "cast_channel" if s.startup >= 0.5 else "cast_ground"
			if s.startup >= 0.5:
				return "cast_channel"
			if s.target == SkillDef.Target.TARGET:
				return "cast_target"
			if s.target == SkillDef.Target.DIRECTION:
				return "atk_staff" if w in ["staff", "wand", "scythe", "scepter", ""] or off == "orb" else ("atk_2h" if w in TWO_HANDED_MELEE else "atk_1h_a")
			return "cast"
		SkillDef.Kind.MOVEMENT:
			return "cast_buff"
	# físico
	if not basic:
		if s.target == SkillDef.Target.SELF:
			return "atk_spin"
		if s.target == SkillDef.Target.GROUND and w not in ["bow", "rifle"]:
			return "atk_leap" if w in TWO_HANDED_MELEE else "cast_ground"
	if w == "bow":
		return "atk_bow"
	if w == "rifle":
		return "atk_rifle"
	if w == "axe2h":
		return "atk_sweep"             # machado de duas mãos: talho largo de lado a lado (o golpe básico pega 150°)
	if w in TWO_HANDED_MELEE:
		return "atk_2h"
	if off in ItemDef.ONE_HANDED_MELEE:
		return "atk_dual_a" if _combo % 2 == 0 else "atk_dual_b"
	if w == "dagger":
		return "atk_dagger"
	return "atk_1h_a" if _combo % 2 == 0 else "atk_1h_b"

## Nome real do clip ("" se o modelo não tiver).
## Forma de bicho (lobo/urso): o gesto humano pedido vira o do animal (tools/blender/druid_sets.form_clips).
const FORM_CLIP := {"atk_claw": "maul", "atk_flurry": "maul", "atk_finisher": "maul", "atk_sweep": "maul", "atk_dual_a": "maul",
	"atk_dual_b": "maul", "atk_1h_a": "maul", "atk_1h_b": "maul", "atk_2h": "maul", "atk_thrust": "maul",
	"atk_leap": "pounce", "atk_charge": "pounce", "atk_spin": "slam", "cast_ground": "slam",
	"shout": "roar", "cast": "roar", "cast_nature": "roar", "cast_buff": "roar", "cast_target": "roar", "cast_channel": "roar",
	"buff_power": "roar", "buff_focus": "roar", "summon": "roar", "buff_guard": "brace"}

func _clip(name: String) -> String:
	if kit and form_view == null:
		return kit.resolve(name)
	if anim.has_animation(name):
		return name
	var alt: String = FORM_CLIP.get(name, "")
	return alt if alt != "" and anim.has_animation(alt) else ""

## Rastro da arma só na parte "rápida" do golpe/magia (fim da preparação até logo depois do impacto).
func _update_trail(st: int) -> void:
	var s := entity.current_skill
	var on := false
	if st == SimEntity.State.CASTING and s != null:
		var t := entity.state_time
		on = t >= s.startup * 0.35 and t <= s.startup + s.active + 0.12
	kit.trail_on = on

func _animate_glb(st: int) -> void:
	if horse:                       # montado: boneco no clipe "ride", cavalo corre/para pela velocidade
		var moving := entity.velocity.length() > 0.2
		if anim.has_animation("ride") and anim.current_animation != "ride":
			anim.play("ride", 0.15)
		var hc := "run" if moving else "idle"
		if horse.anim and horse.anim.has_animation(hc) and horse.anim.current_animation != hc:
			horse.anim.play(hc, 0.15)
		if horse.anim:
			horse.anim.speed_scale = clampf(entity.velocity.length() / 6.0, 0.6, 1.8) if moving else 1.0
		_ride_saddle()
		return
	if kit and form_view == null:
		_update_trail(st)
	# golpe/magia: escolhe o clip pela arma, reinicia a cada ação e acelera o clip para o impacto
	# cair exatamente no momento do dano (fim do startup da skill)
	if kit and kit.legs and form_view == null:
		var going: bool = st in [SimEntity.State.CASTING, SimEntity.State.BLOCKING] and entity.velocity.length() > 0.2
		kit.legs.drive(get_process_delta_time(), going, entity.velocity.length(), RUN_REF_SPEED)
	if st == SimEntity.State.CASTING:
		var s := entity.current_skill
		var fresh := s != _act_skill or entity.state_time < _act_time
		_act_skill = s
		_act_time = entity.state_time
		var looping: bool = s != null and s.active >= LOOP_MIN_ACTIVE and anim.assigned_animation in ACTIVE_LOOP
		if s and not fresh and not _retimed and entity.state_time >= s.startup and anim.is_playing():
			# impacto: o que resta do clipe acaba junto com a skill (sem pose congelada nem corte);
			# giro/canalização acaba junto com a fase ativa (e repete enquanto ela durar)
			_retimed = true
			var left: float = anim.current_animation_length - anim.current_animation_position
			var end_t: float = minf(entity.state_duration, s.startup + s.active) if looping else entity.state_duration
			var time_left := maxf(end_t - entity.state_time, 0.05)
			var slowest := 0.5
			if s == entity.basic_skill and entity.last_cmd and entity.last_cmd.attack:
				time_left = maxf(time_left, entity.basic_cd)     # segurando o ataque: o golpe emenda no próximo, sem parar na guarda
				slowest = HELD_BASIC_MIN_SPEED                     # arma pesada: a volta do golpe fica mais lenta (peso)
			anim.speed_scale = clampf(left / time_left / maxf(_act_speed, 0.01), slowest, 2.5)
		elif s and not fresh and looping and not anim.is_playing() and entity.state_time < s.startup + s.active - 0.1:
			anim.play(anim.assigned_animation, 0.05, _act_speed)       # fase ativa longa: o gesto repete
			anim.seek(0.0, true)
		if fresh:
			var want_clip := _action_clip(s)
			var clip := _clip(want_clip)
			if clip == "":
				clip = _clip("cast" if (s and s.kind != SkillDef.Kind.PHYSICAL) else "attack")
			if clip == "":
				clip = _clip("attack")         # bicho (forma de animal): todo golpe é o ataque dele
			if clip != "":
				var impact := float(IMPACT_FRAME.get(clip, 5) - 1) / 24.0
				var startup := maxf(s.startup if s else 0.15, 0.06)
				var speed := clampf(impact / startup, ANIM_MIN_SPEED, ANIM_MAX_SPEED)
				anim.speed_scale = 1.0
				_act_speed = speed
				_retimed = false
				anim.play(clip, 0.06, speed)
				anim.seek(0.0, true)
				_combo += 1
		return
	_act_skill = null
	# colheita: agacha e puxa (planta, concha...) ou picareta (minério); armas somem enquanto colhe
	var gkind: String = str(entity.gather_node.get("kind", "")) if entity.gather_left > 0.0 else ""
	if kit and form_view == null and gkind != _gather_shown:
		_gather_shown = gkind
		kit.set_gathering(gkind)
	if gkind != "":
		var gc := _clip(GatherPose.clip_for(gkind))
		if gc != "" and anim.current_animation != gc:
			anim.play(gc, 0.15)
			anim.speed_scale = 1.0
		if gc != "":
			return
	# pulo: sobe / cai / pousa (clip curto e volta ao normal)
	var air := entity.airborne()
	if _was_air and not air:
		_land_t = 0.16
	_was_air = air
	_land_t = maxf(0.0, _land_t - get_process_delta_time())
	var base := "idle"
	if air and st in [SimEntity.State.IDLE, SimEntity.State.MOVING, SimEntity.State.DASHING]:
		base = "jump" if entity.jump_v > 0.0 else "fall"
		if _clip(base) == "":
			base = "run"
	elif _land_t > 0.0 and st in [SimEntity.State.IDLE, SimEntity.State.MOVING] and _clip("land") != "":
		base = "land"
	match st if base == "idle" else -1:
		SimEntity.State.MOVING: base = "run"
		SimEntity.State.BLOCKING: base = "block_shield" if entity.stats.has_shield and _clip("block_shield") != "" else "block"
		SimEntity.State.DASHING: base = "dash" if anim.has_animation("dash") else "run"
		SimEntity.State.STUNNED: base = "hit"
		SimEntity.State.IDLE, SimEntity.State.MOVING:
			if _flinch > 0.0 and _clip("hit") != "":
				base = "hit"
		SimEntity.State.DEAD: base = "die"
	var want := _clip(base)
	# idle próprio da arma: arco baixo na mão esquerda, cajado/varinha/foice em pé
	if base == "idle":
		var w := entity.stats.weapon_type if entity.stats else ""
		var fam := "bow" if w == "bow" else ("staff" if w in ["staff", "wand", "scythe", "scepter"] else "")
		if fam != "" and _clip("idle_" + fam) != "":
			want = _clip("idle_" + fam)
	if want == "":
		want = _clip("idle")
	if want != "" and anim.current_animation != want:
		anim.play(want, 0.07 if base.begins_with("block") else 0.12)      # erguer a guarda é rápido: é reação
	# corrida no ritmo da velocidade real (sem pé deslizando); o resto em velocidade normal
	anim.speed_scale = clampf(entity.velocity.length() / RUN_REF_SPEED, 0.38 if entity.kind == SimEntity.Kind.NPC else 0.6, 1.7) if base == "run" else 1.0
	if st == SimEntity.State.DEAD and base == "die" and anim.current_animation_position >= anim.current_animation_length - 0.01:
		anim.pause()
