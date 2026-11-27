extends Node
## Arte das Cartas de Monstro (design/gdd/cartas.md §9.4): foto do modelo do monstro (o mesmo .glb e o mesmo toon do jogo)
## numa moldura de carta. Saída: assets/icons/card_<monster_id>.png (192x256, carta em pé 3:4).
##   godot --path . tools/icons/card_icons.tscn -- [--band=1-30] [--only=<id>,...] [--core=<id>,...] [--slots=<id>:<encaixe>,...]
##        [--sheet=<png>] [--no_write]                                                 (com janela; depois rode --import)
## --band = todos os monstros com carta na faixa de nível (as cartas de GameData.cards; sem catálogo, a regra de card_eligible, §3.1);
## --only = só estes ids (com --band, filtra).
## Moldura: prata na carta comum, ouro com enfeites na de núcleo. Núcleo = o catálogo diz (CardsCatalog), senão --core, senão chefe.
## Encaixe (canto de cima): o do catálogo, senão --slots; sem nenhum, soquete vazio (refaça a arte quando o catálogo chegar).
## Faixa de baixo = cor e emblema da família do monstro (family_of: palavra no id/modelo).
## --no_write = só a folha (--sheet), sem gravar os PNGs (para iterar no visual).

const W := 192
const H := 256
const K := 3                                   # superamostragem: tudo é desenhado a 3x e reduzido no fim
const WIN := Rect2(48, 54, 480, 528)           # janela da foto (em px da carta a 3x)
const BAND := Rect2(48, 600, 480, 120)         # faixa da família
const INK := Color(0.08, 0.06, 0.1)
const IDLE_T := 0.35                           # instante do idle da foto (s)
const VIEW_DIR := Vector3(0.62, 0.42, 1.0)     # de onde a câmera olha: 3/4 de frente, um pouco de cima (+Z = frente do monstro)
const FILL_W := 0.86                           # quanto da janela o monstro ocupa (largura/altura)
const FILL_H := 0.84
const FILL_H_TALL := 0.93
const FOOT_Y := 0.55                           # centro do monstro um pouco abaixo do meio da janela (sobra cabeça, chão perto da borda)

## [claro, médio, escuro] dos metais da moldura
const METAL := {
	"silver": [Color(0.95, 0.96, 0.99), Color(0.68, 0.71, 0.78), Color(0.34, 0.36, 0.44)],
	"gold": [Color(1.0, 0.94, 0.6), Color(0.94, 0.7, 0.24), Color(0.55, 0.32, 0.1)],
}
const PARCH := [Color(0.97, 0.92, 0.78), Color(0.87, 0.78, 0.58)]
## família -> cor da faixa (e do fundo da foto, bem clara)
const FAMILY_COLOR := {
	"beast": Color(0.72, 0.46, 0.25), "insect": Color(0.76, 0.64, 0.16), "undead": Color(0.5, 0.4, 0.64),
	"spirit": Color(0.3, 0.62, 0.74), "humanoid": Color(0.68, 0.24, 0.24), "elf": Color(0.2, 0.58, 0.42),
	"plant": Color(0.45, 0.6, 0.2), "construct": Color(0.44, 0.5, 0.6), "slime": Color(0.3, 0.52, 0.86),
	"dragon": Color(0.88, 0.38, 0.14), "horde": Color(0.42, 0.44, 0.28),
}
## palavra no id ou no modelo -> família (em ordem: a 1ª que bate vence; "rot_wolf" é morto-vivo antes de ser lobo)
const FAMILY_WORDS := [
	["slime", "slime"], ["dragon", "dragon"], ["drake", "dragon"],
	["ghost", "spirit"], ["wraith", "spirit"], ["shade", "spirit"], ["wisp", "spirit"], ["soul", "spirit"], ["widow", "spirit"], ["echo", "spirit"],
	["rot_", "undead"], ["rest_", "undead"], ["zombie", "undead"], ["ghoul", "undead"], ["skel", "undead"], ["bone", "undead"],
	["lich", "undead"], ["death_knight", "undead"], ["crypt", "undead"], ["oath", "undead"], ["grave", "undead"], ["fallen", "undead"],
	["citadel_knight", "undead"], ["archive_warden", "undead"], ["horror", "undead"],
	["elf_", "elf"],
	["golem", "construct"], ["crystal", "construct"], ["quarry", "construct"],
	["ent", "plant"], ["trent", "plant"], ["sap_", "plant"], ["sap", "plant"], ["vine", "plant"],
	["wasp", "insect"], ["hive", "insect"], ["spider", "insect"], ["larva", "insect"], ["web", "insect"], ["leech", "insect"],
	["wolf", "beast"], ["boar", "beast"], ["bear", "beast"], ["crab", "beast"], ["lynx", "beast"], ["toad", "beast"], ["bog_mother", "beast"],
	["griffin", "beast"], ["bat", "beast"], ["crow", "beast"], ["hawk", "beast"], ["deer", "beast"], ["rabbit", "beast"],
]
const SLOTS := ["weapon", "offhand", "head", "chest", "boots", "accessory"]

var _vp3: SubViewport
var _cam: Camera3D
var _sun: DirectionalLight3D
var _vp2: SubViewport
var _cv: Node2D
var _job: Dictionary = {}
var _sheet: Array = []

# --- quem tem carta ------------------------------------------------------------------------------------------

## Família de arte do monstro (cor da faixa + emblema). Lê o catálogo de cartas se ele disser "family".
## A família do jogo (CardsCatalog.FAMILY, alvo de family_dmg/def) vence; a palavra no id é o resto (Atos II/III).
## (CardDef.family NÃO é a do monstro: é a família alvo do efeito da carta.)
static func family_of(mdef: MonsterDef) -> String:
	var script := _catalog_script()
	if script:
		var fam: Variant = script.get_script_constant_map().get("FAMILY")
		if fam is Dictionary:
			for f in fam:
				if FAMILY_COLOR.has(str(f)) and (fam[f] as Array).has(mdef.id):
					return str(f)
	for pair in FAMILY_WORDS:
		if mdef.id.contains(pair[0]) or mdef.model.contains(pair[0]):
			return pair[1]
	return "humanoid"

## Regra do §3.1: XP > 0, não é forma de metamorfose, lacaio de chefe (invocado por fase/skill), boneco, isca, ovo nem Rei (elite:
## dá a carta da base). Faixa por MonsterDef.level. Só monstros com modelo .glb (a arte é a foto do modelo).
static func card_eligible(lo: int, hi: int) -> Array[String]:
	var forms := {}
	var minions := {}
	for mid in GameData.monsters:
		var m: MonsterDef = GameData.monsters[mid]
		for f in m.shift_forms:
			forms[str(f.get("form", ""))] = true
		for ph in m.phases:
			if ph is Dictionary and ph.has("summon"):
				minions[str(ph["summon"].get("id", ""))] = true
		for sid in m.skill_ids:
			var sd: SkillDef = GameData.skills.get(sid)
			if sd and sd.effects.has("boss_summon"):
				minions[str(sd.effects["boss_summon"].get("id", ""))] = true
	var out: Array[String] = []
	for mid in GameData.monsters:
		var m: MonsterDef = GameData.monsters[mid]
		if m.level < lo or m.level > hi or m.xp <= 0 or m.dummy or m.decoy or m.egg or m.elite_of != "":
			continue
		if forms.has(mid) or minions.has(mid) or m.model == "":
			continue
		if not ResourceLoader.exists("res://assets/models/%s.glb" % m.model):
			continue
		out.append(str(mid))
	out.sort()
	return out

## Monstros que precisam de arte na faixa: os das cartas do catálogo (GameData.cards) se ele existe, senão a regra do §3.1.
static func card_monsters(lo: int, hi: int) -> Array[String]:
	var cards: Variant = GameData.get("cards")
	if not (cards is Dictionary) or (cards as Dictionary).is_empty():
		return card_eligible(lo, hi)
	var out: Array[String] = []
	for cid in cards:
		var mid := str(_field(cards[cid], "monster_id", ""))
		var m: MonsterDef = GameData.monsters.get(mid)
		if m and m.level >= lo and m.level <= hi and not out.has(mid):
			out.append(mid)
	out.sort()
	return out

## O que o catálogo de cartas diz deste monstro: {found, core, slot} (vazio se ainda não há catálogo ou carta).
## Contrato tolerante (o catálogo está sendo escrito em paralelo): GameData.cards (id -> Resource/Dictionary com monster_id),
## CardsCatalog.card_of(monster_id) ou a constante CardsCatalog.CARDS (monster_id -> Dictionary).
static func card_info(monster_id: String) -> Dictionary:
	var cards: Variant = GameData.get("cards")
	if cards is Dictionary:
		for cid in cards:
			var c: Variant = cards[cid]
			var mid := str(_field(c, "monster_id", _field(c, "monster", "")))
			if mid == monster_id:
				return _norm(c)
	var script := _catalog_script()
	if script == null:
		return {}
	if script.has_method("card_of"):
		var r: Variant = script.call("card_of", monster_id)
		return _norm(r) if r != null else {}
	var consts := script.get_script_constant_map()
	if consts.has("CARDS") and consts["CARDS"] is Dictionary and consts["CARDS"].has(monster_id):
		return _norm(consts["CARDS"][monster_id])
	return {}

static var _cat_script: Script = null
static var _cat_looked := false

static func _catalog_script() -> Script:
	if not _cat_looked:
		_cat_looked = true
		for g in ProjectSettings.get_global_class_list():
			if str(g.get("class", "")) == "CardsCatalog":
				_cat_script = load(str(g["path"]))
	return _cat_script

static func _field(c: Variant, key: String, dflt: Variant) -> Variant:
	if c is Dictionary:
		return c.get(key, dflt)
	if c is Object and key in c:
		return c.get(key)
	return dflt

static func _norm(c: Variant) -> Dictionary:
	if c == null:
		return {}
	var out := {"found": true}
	var core: Variant = _field(c, "core", null)
	if core == null:
		var sp := str(_field(c, "species", _field(c, "kind", ""))).to_lower()
		core = sp.begins_with("core") or sp.begins_with("nucl") or sp.begins_with("núcl")
	out["core"] = bool(core)
	out["slot"] = slot_key(_field(c, "slot", ""))
	return out

## Encaixe do catálogo (texto em inglês/pt ou ItemDef.Slot) -> chave do glifo ("" = desconhecido).
static func slot_key(v: Variant) -> String:
	if v is int:
		match v:
			ItemDef.Slot.WEAPON: return "weapon"
			ItemDef.Slot.OFFHAND: return "offhand"
			ItemDef.Slot.HEAD: return "head"
			ItemDef.Slot.BODY: return "chest"
			ItemDef.Slot.BOOTS: return "boots"
		return "accessory"
	var s := str(v).to_lower()
	for pair in [["off", "offhand"], ["secund", "offhand"], ["weapon", "weapon"], ["arma", "weapon"], ["head", "head"], ["cabe", "head"],
			["chest", "chest"], ["body", "chest"], ["peito", "chest"], ["boot", "boots"], ["bota", "boots"], ["feet", "boots"],
			["acc", "accessory"], ["acess", "accessory"], ["ring", "accessory"], ["anel", "accessory"]]:
		if s.contains(pair[0]):
			return pair[1]
	return ""

# --- laço -----------------------------------------------------------------------------------------------------

func _ready() -> void:
	await get_tree().process_frame
	var only := PackedStringArray()
	var core_ids := PackedStringArray()
	var slots := {}
	var band := ""
	var sheet_path := ""
	var write := true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="): only = a.get_slice("=", 1).split(",", false)
		elif a.begins_with("--core="): core_ids = a.get_slice("=", 1).split(",", false)
		elif a.begins_with("--band="): band = a.get_slice("=", 1)
		elif a.begins_with("--sheet="): sheet_path = a.get_slice("=", 1)
		elif a == "--no_write": write = false
		elif a.begins_with("--slots="):
			for p in a.get_slice("=", 1).split(",", false):
				slots[p.get_slice(":", 0)] = slot_key(p.get_slice(":", 1))
	var ids: Array[String] = []
	if band != "":
		ids = card_monsters(int(band.get_slice("-", 0)), int(band.get_slice("-", 1)))
		if not only.is_empty():
			ids = ids.filter(func(x: String) -> bool: return only.has(x))
	else:
		for x in only:
			ids.append(x)
	if ids.is_empty():
		push_error("card_icons: nada a fazer (use --band=1-30 ou --only=<id>,...)")
		get_tree().quit(1)
		return
	_setup()
	var made := 0
	for mid in ids:
		var mdef: MonsterDef = GameData.monsters.get(mid)
		if mdef == null:
			push_warning("card_icons: monstro desconhecido %s" % mid)
			continue
		var info := card_info(mid)
		var core: bool = info.get("core", core_ids.has(mid) or mdef.is_boss)
		var slot: String = info.get("slot", "")
		if slot == "":
			slot = slots.get(mid, "")
		var photo := await _photo(mdef)
		if photo == null:
			push_warning("card_icons: sem foto para %s (%s)" % [mid, mdef.model])
			continue
		_job = {"photo": ImageTexture.create_from_image(photo), "used": photo.get_used_rect(), "core": core, "slot": slot,
			"family": family_of(mdef), "seed": hash(mid)}
		_cv.queue_redraw()
		for i in range(3):
			await RenderingServer.frame_post_draw
		var img := _vp2.get_texture().get_image()
		img.resize(W, H, Image.INTERPOLATE_LANCZOS)
		if write:
			img.save_png("res://assets/icons/card_%s.png" % mid)
		_sheet.append(img)
		made += 1
		print("carta %s %s %s %s" % [mid, "nucleo" if core else "comum", _job["family"], slot if slot != "" else "-"])
	if sheet_path != "":
		_save_sheet(sheet_path)
	print("CARD_ICONS_OK ", made)
	get_tree().quit()

func _setup() -> void:
	_vp3 = SubViewport.new()
	_vp3.size = Vector2i(int(WIN.size.x), int(WIN.size.y))
	_vp3.transparent_bg = true
	_vp3.own_world_3d = true
	_vp3.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp3.msaa_3d = Viewport.MSAA_4X
	add_child(_vp3)
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.93, 0.9)
	env.ambient_light_energy = 0.7
	var world := WorldEnvironment.new()
	world.environment = env
	_vp3.add_child(world)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.far = 200.0
	_vp3.add_child(_cam)
	_sun = DirectionalLight3D.new()
	_sun.light_energy = 1.1
	_vp3.add_child(_sun)
	_vp2 = SubViewport.new()
	_vp2.size = Vector2i(W * K, H * K)
	_vp2.transparent_bg = true
	_vp2.msaa_2d = Viewport.MSAA_8X
	_vp2.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp2)
	_cv = Node2D.new()
	_cv.draw.connect(_paint)
	_vp2.add_child(_cv)

# --- foto -----------------------------------------------------------------------------------------------------

## Monta o .glb como a EntityView (toon, tinta da variante, brilho), põe no idle e fotografa: 1ª foto larga, mede o
## retângulo usado e refaz justa (pega a pose de verdade, não a de descanso). Devolve a imagem (fundo transparente).
func _photo(mdef: MonsterDef) -> Image:
	var path := "res://assets/models/%s.glb" % mdef.model
	if not ResourceLoader.exists(path):
		return null
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	_vp3.add_child(inst)
	_toon(inst, mdef)
	for n in inst.find_children("wpn_alt_*", "Node3D", true, false):
		(n as Node3D).visible = false                # arma da troca (swap): só a principal, como no jogo
	var anim := _find_anim(inst)
	if anim:
		var clip := "idle" if anim.has_animation("idle") else ""
		if clip == "" and anim.get_animation_list().size() > 0:
			clip = anim.get_animation_list()[0]
		if clip != "":
			anim.play(clip)
			anim.seek(minf(IDLE_T, anim.current_animation_length), true)
			anim.pause()
	await get_tree().process_frame
	await get_tree().process_frame
	var dir := VIEW_DIR.normalized()
	var right := Vector3.UP.cross(dir).normalized()       # câmera olha para -dir
	var up := dir.cross(right).normalized()
	var box := _bounds(inst)
	var ctr := box.get_center()
	var size := maxf(box.size.length(), 0.5) * 1.3
	var img: Image = null
	for attempt in range(5):
		_aim(ctr, dir, up, size)
		img = await _grab()
		var r := img.get_used_rect()
		if r.size.x <= 0:
			size *= 2.0
			continue
		var edge := r.position.x <= 1 or r.position.y <= 1 or r.end.x >= img.get_width() - 1 or r.end.y >= img.get_height() - 1
		if edge:
			size *= 1.7                                 # cortado na foto larga: abre mais e tenta de novo
			continue
		var px := size / float(img.get_height())        # m por pixel (KEEP_HEIGHT)
		var c := Vector2(r.position) + Vector2(r.size) * 0.5
		var w_ctr := ctr + right * (c.x - img.get_width() * 0.5) * px - up * (c.y - img.get_height() * 0.5) * px
		var mw := float(r.size.x) * px
		var mh := float(r.size.y) * px
		var fill_h := FILL_H if mh < mw * 1.45 else FILL_H_TALL    # humanoide fino: mais alto na janela (lê melhor pequeno)
		size = maxf(mh / fill_h, mw / FILL_W * float(img.get_height()) / float(img.get_width()))
		ctr = w_ctr + up * (FOOT_Y - 0.5) * size         # o monstro desce um pouco na janela
		_aim(ctr, dir, up, size)
		img = await _grab()
		break
	inst.queue_free()
	await get_tree().process_frame
	return img

func _aim(ctr: Vector3, dir: Vector3, up: Vector3, size: float) -> void:
	_cam.size = size
	_cam.look_at_from_position(ctr + dir * 40.0, ctr, up)
	_sun.look_at_from_position(ctr + dir * 4.0 + Vector3(-2.0, 4.0, 0.5), ctr, Vector3.UP)   # luz de cima, da esquerda da câmera

func _grab() -> Image:
	for i in range(4):
		await RenderingServer.frame_post_draw
	var img := _vp3.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img

## Caixa de mundo das malhas visíveis (pose de descanso para malhas com pele; só a 1ª estimativa).
func _bounds(inst: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not m.is_visible_in_tree() or m.mesh == null:
			continue
		var b := m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box if not first else AABB(Vector3(-0.5, 0, -0.5), Vector3(1, 1.5, 1))

## Mesmo caminho de EntityView._apply_toon_recursive: toon por superfície, cor da variante (monster_tint), brilho (mob_glow).
func _toon(n: Node, mdef: MonsterDef) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in range(mi.get_surface_override_material_count()):
			var base := mi.get_active_material(i)
			var col := Color(0.8, 0.8, 0.8)
			if base is BaseMaterial3D:
				col = (base as BaseMaterial3D).albedo_color
			col = EntityView.monster_tint(mdef, col, base.resource_name if base else "")
			var glow := EntityView.mob_glow(base)
			if glow > 0.0:
				col = EntityView.glow_color(base)
			var tm := Materials.toon_unique(col)
			if glow > 0.0:
				tm.set_shader_parameter("emission_amount", glow)
			if base is BaseMaterial3D and (base as BaseMaterial3D).albedo_texture:
				tm.set_shader_parameter("albedo_tex", (base as BaseMaterial3D).albedo_texture)
			mi.set_surface_override_material(i, tm)
	for c in n.get_children():
		_toon(c, mdef)

func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r:
			return r
	return null

# --- moldura --------------------------------------------------------------------------------------------------

func _paint() -> void:
	if _job.is_empty():
		return
	var core: bool = _job["core"]
	var metal: Array = METAL["gold" if core else "silver"]
	var fam: Color = FAMILY_COLOR.get(_job["family"], FAMILY_COLOR["humanoid"])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_job["seed"])
	var full := Rect2(0, 0, W * K, H * K)
	# moldura de metal (tinta por fora, gradiente na diagonal) e o pergaminho dentro
	_cv.draw_colored_polygon(_rounded(full.grow(-2), 40.0), INK)
	_metal_fill(_rounded(full.grow(-8), 34.0), metal, full)
	_cv.draw_polyline(_loop(_rounded(full.grow(-12), 30.0)), Color(metal[0], 0.7), 3.0, true)
	var parch := full.grow(-30)
	_cv.draw_colored_polygon(_rounded(parch.grow(4), 22.0), INK)
	_grad(_rounded(parch, 18.0), PARCH[0], PARCH[1], parch)
	for i in range(26):                                  # manchas do pergaminho
		var p := Vector2(rng.randf_range(parch.position.x, parch.end.x), rng.randf_range(parch.position.y, parch.end.y))
		_cv.draw_circle(p, rng.randf_range(10.0, 34.0), Color(0.55, 0.4, 0.2, rng.randf_range(0.02, 0.05)))
	# janela da foto: fundo claro da família, luz atrás do monstro, sombra no chão, contorno de tinta e a foto
	var win_pts := _rounded(WIN, 16.0)
	_cv.draw_colored_polygon(_rounded(WIN.grow(6), 20.0), INK)
	_metal_fill(_rounded(WIN.grow(3), 18.0), metal, WIN)
	var sky := fam.lerp(Color(0.97, 0.95, 0.88), 0.72)
	var floor_c := fam.lerp(Color(0.97, 0.95, 0.88), 0.38)
	_grad(win_pts, sky, floor_c, WIN)
	var used: Rect2i = _job["used"]
	var glow_c := WIN.position + Vector2(used.position) + Vector2(used.size) * Vector2(0.5, 0.45)
	if core:
		for k in range(16):                              # raios dourados atrás do núcleo
			var a := TAU * k / 16.0 + 0.1
			var r0 := 40.0
			var r1 := 420.0
			var tri := PackedVector2Array([glow_c + Vector2.from_angle(a - 0.07) * r0, glow_c + Vector2.from_angle(a) * r1, glow_c + Vector2.from_angle(a + 0.07) * r0])
			_cv.draw_colored_polygon(_clip_to(tri, WIN), Color(1.0, 0.92, 0.55, 0.22))
	for i in range(10):
		_cv.draw_circle(glow_c, 230.0 - i * 21.0, Color(1, 1, 0.95, 0.045))
	var foot := WIN.position + Vector2(used.position.x + used.size.x * 0.5, used.end.y - 6)
	var sw := clampf(used.size.x * 0.36, 60.0, 200.0)
	_cv.draw_set_transform(foot, 0.0, Vector2(1.0, 0.22))
	_cv.draw_circle(Vector2.ZERO, sw, Color(0.15, 0.1, 0.08, 0.22))
	_cv.draw_circle(Vector2.ZERO, sw * 0.7, Color(0.15, 0.1, 0.08, 0.2))
	_cv.draw_set_transform(Vector2.ZERO)
	var tex: Texture2D = _job["photo"]
	for k in range(12):                                  # contorno de tinta em volta da silhueta (lê em tamanho pequeno)
		_cv.draw_texture(tex, WIN.position + Vector2.from_angle(TAU * k / 12.0) * 5.0, INK)
	_cv.draw_texture(tex, WIN.position)
	for i in range(5):                                   # vinheta na borda da janela
		_cv.draw_polyline(_loop(_rounded(WIN.grow(-2.0 - i * 5.0), maxf(4.0, 14.0 - i * 4.0))), Color(fam.darkened(0.6), 0.09), 6.0, true)
	_cv.draw_polyline(_loop(win_pts), INK, 3.0, true)
	# faixa da família com o emblema
	_cv.draw_colored_polygon(_rounded(BAND.grow(5), 18.0), INK)
	_metal_fill(_rounded(BAND.grow(2), 16.0), metal, BAND)
	_grad(_rounded(BAND.grow(-6), 10.0), fam.lightened(0.18), fam.darkened(0.25), BAND.grow(-6))
	_cv.draw_line(BAND.position + Vector2(18, 12), Vector2(BAND.end.x - 18, BAND.position.y + 12), Color(1, 1, 1, 0.25), 4.0, true)
	var em := BAND.get_center()
	for s: float in [-1.0, 1.0]:                         # filetes dos lados do emblema
		var x0 := em.x + s * 70.0
		var x1 := em.x + s * 196.0
		_cv.draw_line(Vector2(x0, em.y), Vector2(x1, em.y), Color(INK, 0.55), 9.0, true)
		_cv.draw_line(Vector2(x0, em.y), Vector2(x1, em.y), Color(PARCH[0], 0.85), 4.0, true)
		_diamond(Vector2(x1 + s * 10.0, em.y), 12.0, metal)
	_cv.draw_circle(em, 52.0, INK)
	_cv.draw_circle(em, 47.0, fam.darkened(0.35))
	_cv.draw_circle(em, 47.0, Color(1, 1, 1, 0.0))
	_emblem(str(_job["family"]), em, 34.0, fam.darkened(0.35))
	# enfeites da moldura
	if core:
		for c in [Vector2(30, 30), Vector2(W * K - 30, 30), Vector2(30, H * K - 30), Vector2(W * K - 30, H * K - 30)]:
			_corner(c, metal)
		_gem(Vector2(W * K * 0.5, 22), 26.0, Color(0.85, 0.12, 0.16))
		_gem(Vector2(W * K * 0.5, H * K - 22), 18.0, Color(0.85, 0.12, 0.16))
	else:
		for c in [Vector2(19, 19), Vector2(W * K - 19, 19), Vector2(19, H * K - 19), Vector2(W * K - 19, H * K - 19)]:
			_cv.draw_circle(c, 9.0, INK)
			_cv.draw_circle(c, 6.5, metal[1])
			_cv.draw_circle(c + Vector2(-2, -2), 3.0, metal[0])
	# encaixe (canto de cima, à esquerda)
	_slot_badge(Vector2(74, 80), str(_job["slot"]), metal)

func _slot_badge(c: Vector2, slot: String, metal: Array) -> void:
	_cv.draw_circle(c, 46.0, INK)
	_cv.draw_circle(c, 42.0, metal[1])
	_cv.draw_arc(c, 39.0, PI * 1.05, PI * 1.75, 16, metal[0], 5.0, true)
	_cv.draw_circle(c, 32.0, INK)
	_cv.draw_circle(c, 29.0, Color(0.22, 0.17, 0.2))
	if slot == "":
		_diamond(c, 10.0, metal)                         # soquete vazio: encaixe ainda não definido
		return
	_glyph(slot, c, 22.0)

# --- desenho --------------------------------------------------------------------------------------------------

func _rounded(rc: Rect2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var corners := [rc.position + Vector2(rc.size.x - r, r), rc.end - Vector2(r, r), rc.position + Vector2(r, rc.size.y - r), rc.position + Vector2(r, r)]
	for i in range(4):
		for k in range(9):
			out.append(corners[i] + Vector2.from_angle(-PI * 0.5 + i * PI * 0.5 + k * PI / 16.0) * r)
	return out

func _loop(pts: PackedVector2Array) -> PackedVector2Array:
	var l := pts.duplicate()
	l.append(pts[0])
	return l

## Gradiente de cima para baixo.
func _grad(pts: PackedVector2Array, top: Color, bot: Color, rc: Rect2) -> void:
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bot, clampf((p.y - rc.position.y) / rc.size.y, 0.0, 1.0)))
	_cv.draw_polygon(pts, cols)

## Metal: claro no alto à esquerda, escuro embaixo à direita, com uma faixa de reflexo.
func _metal_fill(pts: PackedVector2Array, metal: Array, rc: Rect2) -> void:
	var cols := PackedColorArray()
	for p in pts:
		var t := clampf(((p.y - rc.position.y) / rc.size.y) * 0.75 + ((p.x - rc.position.x) / rc.size.x) * 0.25, 0.0, 1.0)
		var c: Color = (metal[0] as Color).lerp(metal[1], t / 0.45) if t < 0.45 else (metal[1] as Color).lerp(metal[2], (t - 0.45) / 0.55)
		cols.append(c)
	_cv.draw_polygon(pts, cols)

## Recorta um polígono convexo pequeno no retângulo (raios atrás do núcleo).
func _clip_to(pts: PackedVector2Array, rc: Rect2) -> PackedVector2Array:
	var box := PackedVector2Array([rc.position, Vector2(rc.end.x, rc.position.y), rc.end, Vector2(rc.position.x, rc.end.y)])
	var r := Geometry2D.intersect_polygons(pts, box)
	return r[0] if r.size() > 0 else PackedVector2Array()

func _diamond(c: Vector2, d: float, metal: Array) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)])
	_cv.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d - 4), c + Vector2(d + 4, 0), c + Vector2(0, d + 4), c + Vector2(-d - 4, 0)]), INK)
	_cv.draw_colored_polygon(pts, metal[1])
	_cv.draw_colored_polygon(PackedVector2Array([pts[0], pts[1], c, pts[3]]), metal[0])

func _gem(c: Vector2, r: float, col: Color) -> void:
	var gold: Array = METAL["gold"]
	_cv.draw_circle(c, r + 8.0, INK)
	_cv.draw_circle(c, r + 5.0, gold[1])
	_cv.draw_arc(c, r + 3.0, PI * 1.0, PI * 1.6, 10, gold[0], 3.0, true)
	_cv.draw_circle(c, r, INK)
	_cv.draw_circle(c, r - 3.0, col)
	_cv.draw_circle(c + Vector2(r * 0.15, r * 0.2), r * 0.55, col.darkened(0.35))
	_cv.draw_circle(c + Vector2(-r * 0.3, -r * 0.32), r * 0.28, Color(1, 1, 1, 0.8))

## Canto do núcleo: losango de ouro com volutas.
func _corner(c: Vector2, metal: Array) -> void:
	var inward := (Vector2(W * K, H * K) * 0.5 - c).normalized()
	for s in [-1.0, 1.0]:
		var side := inward.rotated(s * PI * 0.25)
		var a0 := side.angle()
		var cc := c + side * 34.0
		_cv.draw_arc(cc, 14.0, a0 + s * 0.6, a0 + s * 0.6 + s * 4.2, 18, INK, 9.0, true)
		_cv.draw_arc(cc, 14.0, a0 + s * 0.6, a0 + s * 0.6 + s * 4.2, 18, metal[1], 4.5, true)
	_diamond(c, 22.0, metal)
	_cv.draw_circle(c, 6.0, Color(0.85, 0.12, 0.16))

func _fill(pts: PackedVector2Array, col: Color, ow: float = 5.0) -> void:
	_cv.draw_polyline(_loop(pts), INK, ow * 2.0, true)
	_cv.draw_colored_polygon(pts, col)

func _P(c: Vector2, s: float, a: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, a.size(), 2):
		out.append(c + Vector2(a[i], a[i + 1]) * s)
	return out

func _ellipse(c: Vector2, rx: float, ry: float, rot: float = 0.0, n: int = 24) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(n):
		var a := TAU * i / float(n)
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return out

## Emblema da família (cor de pergaminho, contorno de tinta), num disco de raio ~s.
func _emblem(fam: String, c: Vector2, s: float, bg: Color) -> void:
	var p: Color = PARCH[0]
	match fam:
		"horde":                                          # presas da Horda (Ato II) sobre a mandíbula
			_fill(_P(c, s, [-0.62, 0.5, 0.62, 0.5, 0.5, 0.86, -0.5, 0.86]), bg.lightened(0.45))
			for sx: float in [-1.0, 1.0]:
				_fill(_P(c, s, [sx * -0.52, 0.62, sx * -0.74, 0.12, sx * -0.6, -0.42, sx * -0.28, -0.88, sx * -0.36, -0.3, sx * -0.24, 0.24, sx * -0.18, 0.62]), p)
		"beast":                                          # pata
			_fill(_ellipse(c + Vector2(0, 0.32) * s, 0.46 * s, 0.38 * s), p)
			for t in [[-0.62, -0.18], [-0.24, -0.58], [0.24, -0.58], [0.62, -0.18]]:
				_fill(_ellipse(c + Vector2(t[0], t[1]) * s, 0.19 * s, 0.24 * s), p)
		"insect":                                         # asas e corpo
			for sx: float in [-1.0, 1.0]:
				_fill(_ellipse(c + Vector2(sx * 0.42, -0.28) * s, 0.42 * s, 0.24 * s, sx * -0.5), p)
				_fill(_ellipse(c + Vector2(sx * 0.36, 0.22) * s, 0.32 * s, 0.17 * s, sx * 0.45), p)
			_fill(_ellipse(c + Vector2(0, 0.05) * s, 0.13 * s, 0.62 * s), bg.lightened(0.5))
		"undead":                                         # caveira
			_fill(_ellipse(c + Vector2(0, -0.15) * s, 0.62 * s, 0.56 * s), p)
			_fill(_P(c, s, [-0.34, 0.25, 0.34, 0.25, 0.3, 0.72, -0.3, 0.72]), p)
			_cv.draw_colored_polygon(_ellipse(c + Vector2(-0.25, -0.1) * s, 0.15 * s, 0.17 * s), INK)
			_cv.draw_colored_polygon(_ellipse(c + Vector2(0.25, -0.1) * s, 0.15 * s, 0.17 * s), INK)
			_cv.draw_colored_polygon(_P(c, s, [0.0, 0.12, 0.08, 0.3, -0.08, 0.3]), INK)
			for x in [-0.12, 0.12]:
				_cv.draw_line(c + Vector2(x, 0.42) * s, c + Vector2(x, 0.72) * s, INK, 3.0)
		"spirit":                                         # chama-fantasma
			_fill(_P(c, s, [0.0, -0.85, 0.3, -0.35, 0.55, 0.15, 0.45, 0.6, 0.15, 0.78, -0.2, 0.75, -0.5, 0.5, -0.55, 0.05, -0.25, -0.3]), p)
			_cv.draw_colored_polygon(_ellipse(c + Vector2(-0.16, 0.18) * s, 0.09 * s, 0.13 * s), INK)
			_cv.draw_colored_polygon(_ellipse(c + Vector2(0.16, 0.18) * s, 0.09 * s, 0.13 * s), INK)
		"humanoid":                                       # espadas cruzadas
			for sx: float in [-1.0, 1.0]:
				var rot := sx * PI * 0.25
				var blade := PackedVector2Array([Vector2(-0.09, -0.85), Vector2(0.0, -1.0), Vector2(0.09, -0.85), Vector2(0.09, 0.35), Vector2(-0.09, 0.35)])
				var guard := PackedVector2Array([Vector2(-0.3, 0.35), Vector2(0.3, 0.35), Vector2(0.3, 0.47), Vector2(-0.3, 0.47)])
				var grip := PackedVector2Array([Vector2(-0.07, 0.47), Vector2(0.07, 0.47), Vector2(0.07, 0.8), Vector2(-0.07, 0.8)])
				for poly in [blade, guard, grip]:
					var t := PackedVector2Array()
					for v in poly:
						t.append(c + (v * s * 0.95).rotated(rot))
					_fill(t, p if poly != grip else bg.lightened(0.45), 4.0)
		"elf":                                            # folha pontuda com nervura
			_fill(_P(c, s, [0.0, -0.9, 0.35, -0.45, 0.42, 0.1, 0.22, 0.55, 0.0, 0.85, -0.22, 0.55, -0.42, 0.1, -0.35, -0.45]).duplicate(), p)
			_cv.draw_line(c + Vector2(0, -0.7) * s, c + Vector2(0, 0.85) * s, INK, 4.0, true)
			for y in [-0.3, 0.05, 0.38]:
				_cv.draw_line(c + Vector2(0, y) * s, c + Vector2(0.26, y - 0.2) * s, INK, 3.0, true)
				_cv.draw_line(c + Vector2(0, y) * s, c + Vector2(-0.26, y - 0.2) * s, INK, 3.0, true)
		"plant":                                          # broto
			_cv.draw_line(c + Vector2(0, 0.85) * s, c + Vector2(0, -0.15) * s, INK, 12.0, true)
			_cv.draw_line(c + Vector2(0, 0.85) * s, c + Vector2(0, -0.15) * s, p, 5.0, true)
			_fill(_ellipse(c + Vector2(-0.38, -0.3) * s, 0.4 * s, 0.2 * s, -0.5), p)
			_fill(_ellipse(c + Vector2(0.38, -0.42) * s, 0.42 * s, 0.22 * s, 0.6), p)
			_fill(_ellipse(c + Vector2(0, 0.82) * s, 0.45 * s, 0.1 * s), bg.lightened(0.4))
		"construct":                                      # pedra facetada
			var hexa := _P(c, s, [0.0, -0.85, 0.72, -0.42, 0.72, 0.42, 0.0, 0.85, -0.72, 0.42, -0.72, -0.42])
			_fill(hexa, p)
			_cv.draw_colored_polygon(_P(c, s, [0.0, 0.0, 0.72, 0.42, 0.0, 0.85, -0.72, 0.42]), PARCH[1])
			_cv.draw_polyline(_P(c, s, [0.0, -0.85, 0.0, 0.0, 0.72, 0.42]), INK, 3.0, true)
			_cv.draw_line(c, c + Vector2(-0.72, 0.42) * s, INK, 3.0, true)
		"slime":                                          # gota
			var drop := PackedVector2Array()
			for i in range(24):
				var a := TAU * i / 24.0
				var r := 0.58 + 0.32 * maxf(0.0, -sin(a)) * maxf(0.0, -sin(a)) * maxf(0.0, -sin(a))
				drop.append(c + Vector2(cos(a) * 0.58, sin(a) * r + 0.15) * s * Vector2(1.0, 1.0) + (Vector2(0, -0.0)))
			drop[18] = c + Vector2(0, -0.95) * s
			_fill(drop, p)
			_cv.draw_circle(c + Vector2(-0.2, 0.1) * s, 0.12 * s, Color(1, 1, 1, 0.9))
		"dragon":                                         # asa
			_fill(_P(c, s, [-0.8, 0.5, -0.5, -0.6, 0.0, -0.85, 0.85, -0.3, 0.55, -0.05, 0.75, 0.25, 0.35, 0.2, 0.42, 0.55, 0.0, 0.42, -0.1, 0.75]), p)
			_cv.draw_line(c + Vector2(-0.5, -0.6) * s, c + Vector2(0.0, 0.42) * s, INK, 3.0, true)
			_cv.draw_line(c + Vector2(-0.5, -0.6) * s, c + Vector2(0.35, 0.2) * s, INK, 3.0, true)
			_cv.draw_line(c + Vector2(-0.5, -0.6) * s, c + Vector2(0.55, -0.05) * s, INK, 3.0, true)

## Glifo do encaixe (branco-pergaminho), dentro do disco escuro.
func _glyph(slot: String, c: Vector2, s: float) -> void:
	var p: Color = PARCH[0]
	match slot:
		"weapon":
			var rot := PI * 0.25
			for poly in [[-0.12, -0.75, 0.0, -1.0, 0.12, -0.75, 0.12, 0.35, -0.12, 0.35], [-0.4, 0.35, 0.4, 0.35, 0.4, 0.5, -0.4, 0.5], [-0.09, 0.5, 0.09, 0.5, 0.09, 0.9, -0.09, 0.9]]:
				var t := PackedVector2Array()
				for i in range(0, poly.size(), 2):
					t.append(c + (Vector2(poly[i], poly[i + 1]) * s).rotated(rot))
				_fill(t, p, 3.0)
		"offhand":
			_fill(_P(c, s, [-0.75, -0.8, 0.75, -0.8, 0.75, 0.0, 0.4, 0.6, 0.0, 0.92, -0.4, 0.6, -0.75, 0.0]), p, 3.0)
			_cv.draw_line(c + Vector2(0, -0.7) * s, c + Vector2(0, 0.8) * s, INK, 3.0, true)
			_cv.draw_line(c + Vector2(-0.65, -0.2) * s, c + Vector2(0.65, -0.2) * s, INK, 3.0, true)
		"head":
			var dome := PackedVector2Array()
			for i in range(13):
				var a := PI + PI * i / 12.0
				dome.append(c + Vector2(cos(a) * 0.78, sin(a) * 0.8 + 0.25) * s)
			dome.append(c + Vector2(0.78, 0.85) * s)
			dome.append(c + Vector2(-0.78, 0.85) * s)
			_fill(dome, p, 3.0)
			_cv.draw_line(c + Vector2(-0.6, 0.3) * s, c + Vector2(0.6, 0.3) * s, INK, 5.0, true)
			_cv.draw_line(c + Vector2(0, 0.3) * s, c + Vector2(0, 0.85) * s, INK, 4.0, true)
		"chest":
			_fill(_P(c, s, [-0.85, -0.75, -0.3, -0.85, 0.0, -0.55, 0.3, -0.85, 0.85, -0.75, 0.65, -0.1, 0.55, 0.85, -0.55, 0.85, -0.65, -0.1]), p, 3.0)
			_cv.draw_line(c + Vector2(0, -0.5) * s, c + Vector2(0, 0.8) * s, INK, 3.0, true)
			_cv.draw_line(c + Vector2(-0.55, 0.25) * s, c + Vector2(0.55, 0.25) * s, INK, 3.0, true)
		"boots":
			_fill(_P(c, s, [-0.45, -0.9, 0.2, -0.9, 0.2, 0.25, 0.85, 0.45, 0.85, 0.85, -0.45, 0.85]), p, 3.0)
			_cv.draw_line(c + Vector2(-0.45, -0.55) * s, c + Vector2(0.2, -0.55) * s, INK, 3.0, true)
		"accessory":
			_cv.draw_arc(c + Vector2(0, 0.2) * s, 0.58 * s, 0.0, TAU, 28, INK, 0.38 * s, true)
			_cv.draw_arc(c + Vector2(0, 0.2) * s, 0.58 * s, 0.0, TAU, 28, p, 0.2 * s, true)
			_diamond(c + Vector2(0, -0.48) * s, 0.3 * s, METAL["gold"])

func _save_sheet(path: String) -> void:
	var cols := 8
	var cw := W + 10
	var ch := H + 10
	var rows := ceili(_sheet.size() / float(cols))
	var out := Image.create(cols * cw, rows * ch, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.12, 0.11, 0.14))
	for i in range(_sheet.size()):
		var im: Image = _sheet[i]
		im.convert(Image.FORMAT_RGBA8)
		out.blend_rect(im, Rect2i(0, 0, W, H), Vector2i(i % cols * cw + 5, i / cols * ch + 5))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	out.save_png(path)
	print("folha ", path)
