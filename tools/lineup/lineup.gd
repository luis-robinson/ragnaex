extends Node3D
## Fila de revisão dos personagens (loop de modelos): cada classe com o equipamento inicial (fila da frente)
## e com o conjunto lendário de cada build (filas de trás), na luz/toon do jogo.
##   godot --path . tools/lineup/lineup.tscn -- --shot=<png> [--anim=idle|run|atk_1h_a|cast...] [--level=30] [--t=0.6]
##   --block_film: a guarda como o jogo toca: erguer, soltar e andar bloqueando, quadro a quadro
##   --shields: as 8 famílias de escudo vistas da câmera do jogo, com paladino (fila de trás) e bispo (fila da frente)
##   --strip=<classe>: filme de um clipe — 8 cópias da classe, cada uma num instante do clipe, vistas de lado
## Salva a screenshot e sai.

var _shot := ""
var _anim := "idle"
var _level := 30
var _t := 0.6
var _kits: Array = []
var _time := 0.0
var _strip := ""
var _side := false
var _front := false
var _mobs := ""               # --mobs=<modelo>,<modelo>: modelos de monstro lado a lado (de 3/4) no --anim
var _tiers := false
var _looks := ""
var _mounted := false            # --mounted: bonecos a cavalo (revisar sela, pose e escala), de lado e de 3/4               # --looks=<male|female>[:<classe>]: uma cabeça por estilo de cabelo/barba/olhos (revisar a criação)             # --tiers (--strip=<classe> --set=<build>): um boneco por nível lendário, de 3/4
var _trail := false
var _shields := false
var _film := false
var _film_items: Array = []
const FILM_SHOT := 1.6          # s até a foto: cada boneco recebe o comando `t` antes dela
var _form := ""                 # --form=wolf|bear (--strip=druid --set=<build>): o bicho com a armadura de animal de cada tier
var _set := ""                  # rastro das armas ligado (revisar o efeito com --anim=<golpe>)                  # filme visto de frente (padrão: de perfil)

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="): _shot = a.get_slice("=", 1)
		if a.begins_with("--anim="): _anim = a.get_slice("=", 1)
		if a.begins_with("--level="): _level = int(a.get_slice("=", 1))
		if a.begins_with("--t="): _t = float(a.get_slice("=", 1))
		if a.begins_with("--strip="): _strip = a.get_slice("=", 1)
		if a == "--front": _front = true
		if a == "--tiers": _tiers = true
		if a.begins_with("--looks="): _looks = a.get_slice("=", 1)
		if a == "--mounted": _mounted = true
		if a.begins_with("--mobs="): _mobs = a.get_slice("=", 1)
		if a == "--trail": _trail = true
		if a.begins_with("--set="): _set = a.get_slice("=", 1)
		if a == "--shields": _shields = true
		if a == "--block_film": _film = true
		if a.begins_with("--form="): _form = a.get_slice("=", 1)
	var def := MapDef.new()
	def.id = "lineup"
	def.size = Vector2(40, 40)
	def.ground_color = Color(0.48, 0.68, 0.38)
	def.ground_color_alt = Color(0.44, 0.63, 0.35)
	def.ambient = Color(0.97, 0.94, 0.86)
	def.sun_energy = 1.28
	var map := MapBuilder.build(def)
	add_child(map)
	if _strip != "":
		var g := map.get_node_or_null("Grass")
		if g:
			g.queue_free()                    # filme: pernas à mostra
	if "--plus_demo" in OS.get_cmdline_user_args():      # mesmo equipamento em +0, +5 e +9 (brilho do aprimoramento)
		_build_plus_demo()
		return
	if _form != "":
		_build_forms()
		return
	if _mounted:
		_build_mounted()
		return
	if _looks != "":
		_build_looks()
		return
	if DevArgs.flag("--mob_strip"):
		_build_mob_strip(DevArgs.value("--mob_strip"))
		return
	if _mobs != "":
		_build_mobs()
		return
	if _strip != "" and _tiers:
		_build_tiers()
		return
	if _strip != "":
		_build_strip()
		return
	if _film:
		_build_block_film()
		return
	if _shields:
		_build_shields()
		return
	var classes: Array = GameData.class_list()
	var x0 := -float(classes.size() - 1) * 1.1
	for i in range(classes.size()):
		var cls: ClassDef = classes[i]
		var eq := {}
		for iid in cls.starting_equipment:
			var it: ItemDef = GameData.items[iid]
			eq[it.slot] = it
		_spawn(cls, eq, Vector3(x0 + i * 2.2, 0, 2.2), i)
		for b in range(cls.builds.size()):
			var leq := {}
			for iid in GameData.legendary_pool(cls, _level, cls.builds[b]["id"]):
				var it: ItemDef = GameData.items[iid]
				if not leq.has(it.slot):
					leq[it.slot] = it
			_spawn(cls, leq, Vector3(x0 + i * 2.2, 0, -b * 2.6), i * 10 + b)
	var cam := Camera3D.new()
	cam.fov = 34.0
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 9.5, 17.0), Vector3(0, 0.6, -1.6), Vector3.UP)

## Crossfade real do jogo: cada boneco avança até um instante depois do comando (mesmo tempo de mistura da EntityView).
func _build_block_film() -> void:
	var cls: ClassDef = GameData.classes["paladin"]
	var eq := {}
	for iid in cls.starting_equipment:
		eq[GameData.items[iid].slot] = GameData.items[iid]
	eq[ItemDef.Slot.OFFHAND] = GameData.items["shield_abraco_criador"]
	var times := [0.0, 0.03, 0.06, 0.09, 0.14, 0.22, 0.4]
	for row in range(3):
		for i in range(times.size()):
			var k := KitModel.create(cls.body_type, cls.hair_color, 0.025, cls.id)
			add_child(k)
			k.position = Vector3((i - 3) * 1.9, 0, row * 2.2 - 2.2)
			k.apply_equipment(eq)
			k.anim.play(k.resolve("idle") if row != 1 else k.resolve("block_shield"))
			_film_items.append({"k": k, "row": row, "at": FILM_SHOT - times[i], "done": false})
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 6.6
	add_child(cam)
	cam.look_at_from_position(Vector3(0.3, 13.0, 10.2), Vector3(0.3, 0.6, 0.0), Vector3.UP)
	_side = true

## Folha de escudos: páginas de 6 no ângulo do jogo, de perto (--page=0..3). Sem página, todos juntos de longe.
func _build_shields() -> void:
	var all := ["shield_wood", "shield_iron", "shield_bone", "shield_dragon"]
	for d in GearCatalog.SHIELDS:
		all.append("shield_" + d[0])
	var page := -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--page="): page = int(a.get_slice("=", 1))
	var list: Array = all if page < 0 else all.slice(page * 6, page * 6 + 6)
	var cols := 9 if page < 0 else 6
	var dx := 1.5 if page < 0 else 1.9
	var cls: ClassDef = GameData.classes["paladin"]
	for i in range(list.size()):
		var eq := {}
		for iid in cls.starting_equipment:
			eq[GameData.items[iid].slot] = GameData.items[iid]
		eq[ItemDef.Slot.WEAPON] = GameData.items["sword_rusty"]
		eq[ItemDef.Slot.OFFHAND] = GameData.items[list[i]]
		var k := KitModel.create(cls.body_type, cls.hair_color, 0.025, cls.id)
		add_child(k)
		k.position = Vector3((i % cols - (cols - 1) * 0.5) * dx - 0.2, 0, (i / cols) * 2.2 - 1.1)
		k.apply_equipment(eq)
		var clip := k.resolve(_anim)
		if clip != "":
			k.anim.play(clip)
		_kits.append(k)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL     # todas as colunas no mesmo ângulo, como quem está no centro da tela
	cam.size = 5.4 if page < 0 else 4.7
	add_child(cam)
	cam.look_at_from_position(Vector3(0.3, 13.0, 10.2 - (1.1 if page >= 0 else 0.0)), Vector3(0.3, 0.6, 0.0 - (1.1 if page >= 0 else 0.0)), Vector3.UP)

## Filme: 8 cópias lado a lado, cada uma parada num instante do clipe (0..fim).
func _build_strip() -> void:
	var cls: ClassDef = GameData.classes[_strip]
	var eq := {}
	for iid in cls.starting_equipment:
		eq[GameData.items[iid].slot] = GameData.items[iid]
	if _set != "":                         # --set=<build>: filme com o conjunto lendário dessa build no --level
		eq = {}
		for iid in GameData.legendary_pool(cls, _level, _set):
			var it: ItemDef = GameData.items[iid]
			if not eq.has(it.slot):
				eq[it.slot] = it
	for i in range(8):
		var k := KitModel.create(cls.body_type, cls.hair_color, 0.025, cls.id)
		add_child(k)
		k.position = Vector3(-7.0 + i * 2.0, 0, 0)
		k.rotation.y = 0.0 if _front else PI * 0.5            # de frente ou de perfil para a câmera
		k.apply_equipment(eq)
		var clip := k.resolve(_anim)
		if clip != "":
			k.anim.play(clip)
			k.anim.seek(k.anim.current_animation_length * float(i) / 8.0, true)
			k.anim.pause()
	var cam := Camera3D.new()
	cam.fov = 30.0
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.4, 15.0), Vector3(0, 0.7, 0), Vector3.UP)
	_side = true

func _build_mounted() -> void:
	var cls_ids := ["paladin", "ranger", "elementalist", "berserker"]
	for i in range(cls_ids.size()):
		var cls: ClassDef = GameData.classes[cls_ids[i]]
		var root := Node3D.new()
		add_child(root)
		root.position = Vector3(-4.5 + i * 3.0, 0, 0)
		root.rotation.y = (0.0 if _front else (PI * 0.5 if i % 2 == 0 else 0.6))
		var k := KitModel.create(cls.body_type, cls.hair_color, 0.025, cls.id)
		root.add_child(k)
		k.apply_look(LooksCatalog.default_look(cls))
		var eq := {}
		for iid in cls.starting_equipment:
			eq[GameData.items[iid].slot] = GameData.items[iid]
		k.apply_equipment(eq)
		var h := FormModel.create_from("res://assets/models/mob_horse.glb")
		h.scale = Vector3.ONE * EntityView.HORSE_SCALE

		h.paint(EntityView.HORSE_COATS[i])
		root.add_child(h)
		h.visible = not ("--nohorse" in OS.get_cmdline_user_args())     # só o boneco: conferir a pose
		k.position.y = EntityView.SADDLE_Y
		RidePose.ensure_clip(k.anim, k.skeleton)
		var clip := k.resolve("ride")
		if clip != "":
			k.anim.play(clip)
			k.anim.seek(0.2, true)
			k.anim.pause()
		if h.anim and h.anim.has_animation(_anim):     # cada cavalo numa fase do clipe (0, 1/4, 2/4, 3/4)
			h.anim.play(_anim)
			h.anim.seek(h.anim.get_animation(_anim).length * i / cls_ids.size(), true)
			h.anim.pause()
			k.global_transform = h.bone_delta("body") * root.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, EntityView.SADDLE_Y, 0))
	var cam := Camera3D.new()
	cam.fov = 30.0
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 3.0, 13.0), Vector3(0, 1.1, 0), Vector3.UP)
	_side = true

func _build_looks() -> void:
	var sex := _looks.get_slice(":", 0)
	var cid := _looks.get_slice(":", 1) if ":" in _looks else ""
	var hairs: Array = LooksCatalog.HAIR.keys()
	var off := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--page="):
			off = int(a.get_slice("=", 1)) * 6           # --page=1 mostra os próximos 6 cabelos
	hairs = hairs.slice(off) + hairs.slice(0, off)
	var beards: Array = LooksCatalog.BEARDS.keys()
	var eyes: Array = LooksCatalog.EYES.keys()
	for i in range(6):
		var k := KitModel.create(sex, Color.WHITE, 0.025, cid)
		if k == null:
			return
		add_child(k)
		k.position = Vector3(-5.0 + i * 2.0, 0, 0)
		k.apply_look({"hair": hairs[i % hairs.size()], "beard": beards[i % beards.size()] if sex == "male" else "none", "eyes": eyes[i % eyes.size()],
			"hair_color": LooksCatalog.HAIR_COLORS[(i * 3) % LooksCatalog.HAIR_COLORS.size()], "beard_color": LooksCatalog.HAIR_COLORS[(i * 3 + 2) % LooksCatalog.HAIR_COLORS.size()],
			"eye_color": LooksCatalog.EYE_COLORS[(i * 2 + 3) % LooksCatalog.EYE_COLORS.size()],
			"skin": LooksCatalog.SKIN_COLORS[i % LooksCatalog.SKIN_COLORS.size()], "brows": LooksCatalog.BROWS.keys()[i % LooksCatalog.BROWS.size()],
			"mouth": LooksCatalog.MOUTHS.keys()[i % LooksCatalog.MOUTHS.size()], "marks": LooksCatalog.MARKS.keys()[i % LooksCatalog.MARKS.size()],
			"mark_color": LooksCatalog.MARK_COLORS[i % LooksCatalog.MARK_COLORS.size()]})
		k.apply_equipment({})
		var idle := k.resolve("idle")
		if idle != "":
			k.anim.play(idle)
			k.anim.seek(0.2, true)
			k.anim.pause()
	var cam := Camera3D.new()
	cam.fov = 26.0
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.6, 9.0), Vector3(0, 1.1, 0), Vector3.UP)
	_side = true

func _build_mobs() -> void:
	var ids := _mobs.split(",")
	for i in range(ids.size()):
		var ps: PackedScene = load("res://assets/models/%s.glb" % ids[i])
		if ps == null:
			continue
		var n: Node3D = ps.instantiate()
		add_child(n)
		n.position = Vector3((i - (ids.size() - 1) * 0.5) * 2.2, 0, 0)
		n.rotation.y = 0.5
		var ap: AnimationPlayer = n.find_child("AnimationPlayer", true, false)
		if ap and ap.has_animation(_anim):
			ap.play(_anim)
			ap.seek(0.3, true)
			ap.pause()
	var cam := Camera3D.new()
	cam.fov = 30.0
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 3.0, 9.0), Vector3(0, 0.9, 0), Vector3.UP)
	_side = true

## --mob_strip=<modelo> --anim=<clipe>: filme de um clipe de monstro/forma — 8 cópias, cada uma num instante, de perfil.
func _build_mob_strip(model: String) -> void:
	var ps: PackedScene = load("res://assets/models/%s.glb" % model)
	if ps == null:
		printerr("mob_strip: sem modelo ", model)
		return
	for i in range(8):
		var n: Node3D = ps.instantiate()
		add_child(n)
		n.position = Vector3((i - 3.5) * 2.0, 0, 0)
		n.rotation.y = PI * 0.5
		var ap: AnimationPlayer = n.find_child("AnimationPlayer", true, false)
		if ap and ap.has_animation(_anim):
			ap.play(_anim)
			ap.seek(ap.current_animation_length * i / 7.0, true)
			ap.pause()
	var cam := Camera3D.new()
	cam.fov = 30.0
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 2.2, 16.0), Vector3(0, 0.6, 0), Vector3.UP)
	_side = true

## Aprimoramento: a classe (--strip, padrão paladino) com o equipamento inicial em +0, +5 e +9, de 3/4.
func _build_plus_demo() -> void:
	var cls: ClassDef = GameData.classes[_strip if _strip != "" else "paladin"]
	var eq := {}
	for iid in cls.starting_equipment:
		eq[GameData.items[iid].slot] = GameData.items[iid]
	for i in range(3):
		var veq := {}
		for sl in eq:
			veq[sl] = GameData.plus_item(eq[sl], [0, Balance.PLUS_GLOW_LOW, Balance.PLUS_GLOW_HIGH][i])
		var k := KitModel.create(cls.body_type, cls.hair_color, 0.025, cls.id)
		add_child(k)
		k.position = Vector3(-2.4 + i * 2.4, 0, 0)
		k.rotation.y = 0.5
		k.apply_equipment(veq)
		var clip := k.resolve(_anim)
		if clip != "":
			k.anim.play(clip)
	var cam := Camera3D.new()
	cam.fov = 30.0
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 3.0, 9.0), Vector3(0, 0.9, 0), Vector3.UP)
	_side = true

## Conjuntos de uma build lado a lado (5..30), parados no --anim, de 3/4 (ou de costas com --front).
func _build_tiers() -> void:
	var cls: ClassDef = GameData.classes[_strip]
	var levels: Array = Balance.LEGENDARY_LEVELS
	for i in range(levels.size()):
		var eq := {}
		for iid in GameData.legendary_pool(cls, int(levels[i]), _set):
			var it: ItemDef = GameData.items[iid]
			if not eq.has(it.slot):
				eq[it.slot] = it
		var k := KitModel.create(cls.body_type, cls.hair_color, 0.025, cls.id)
		add_child(k)
		k.position = Vector3(-5.0 + i * 2.0, 0, 0)
		k.rotation.y = PI + 0.5 if _front else 0.5
		k.apply_equipment(eq)
		var clip := k.resolve(_anim)
		if clip != "":
			k.anim.play(clip)
			k.anim.seek(0.3, true)
			k.anim.pause()
	var cam := Camera3D.new()
	cam.fov = 30.0
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 4.0, 13.0), Vector3(0, 0.8, 0), Vector3.UP)
	_side = true

## Forma de animal do Druida: uma por tier lendário (5..30), cada uma com a armadura de animal do conjunto daquele nível.
func _build_forms() -> void:
	var cls: ClassDef = GameData.classes.get(_strip, GameData.classes["druid"])
	var levels: Array = Balance.LEGENDARY_LEVELS
	for i in range(levels.size()):
		var eq := {}
		for iid in GameData.legendary_pool(cls, int(levels[i]), _set):
			var it: ItemDef = GameData.items[iid]
			if not eq.has(it.slot):
				eq[it.slot] = it
		var f := FormModel.create(_form)
		if f == null:
			return
		add_child(f)
		f.scale = Vector3.ONE * EntityView.FORM_SCALE.get(_form, 1.0)
		f.position = Vector3(-6.25 + i * 2.5, 0, 0)
		f.rotation.y = 0.6 if _front else PI * 0.5
		f.apply_equipment(eq)
		if f.anim and f.anim.has_animation(_anim):
			f.anim.play(_anim)
	var cam := Camera3D.new()
	cam.fov = 30.0
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 6.0, 14.0), Vector3(0, 0.5, 0), Vector3.UP)

func _spawn(cls: ClassDef, eq: Dictionary, pos: Vector3, seed_i: int) -> void:
	var k := KitModel.create(cls.body_type, cls.hair_color, 0.025, cls.id)
	if k == null:
		return
	add_child(k)
	k.position = pos
	k.apply_equipment(eq)
	k.trail_on = _trail
	var clip := k.resolve(_anim)
	if clip != "":
		k.anim.play(clip)
	_kits.append(k)

func _process(delta: float) -> void:
	_time += delta
	if _film:
		for it in _film_items:
			if it["row"] == 2:
				it["k"].legs.drive(delta, true, 2.6, 5.5)
			if not it["done"] and _time >= it["at"]:
				it["done"] = true
				it["k"].anim.play(it["k"].resolve("idle" if it["row"] == 1 else "block_shield"), 0.12 if it["row"] == 1 else 0.07)
		if _time >= FILM_SHOT:
			get_viewport().get_texture().get_image().save_png(_shot)
			get_tree().quit()
		return
	if _trail:
		# rastro: foto no meio do golpe (--t = segundos), sem pausar
		if _time > _t and _shot != "":
			get_viewport().get_texture().get_image().save_png(_shot)
			get_tree().quit()
		return
	if _time > _t + 0.5 and _shot != "" and not _side:
		for k in _kits:
			k.anim.pause()
	if _time > _t + 0.7:
		if _shot != "":
			get_viewport().get_texture().get_image().save_png(_shot)
		get_tree().quit()
