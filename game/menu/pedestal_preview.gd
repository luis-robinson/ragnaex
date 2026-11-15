class_name PedestalPreview
extends Node
## Boneco do card selecionado no pedestal do cenário (design/ux/start-flow.md §3 "Personagens"): o `start.gd` liga
## `CharList.selection_changed(slot)` em `show_slot`. Card ok = kit da classe com o visual e o equipamento do save
## (resumo falso do `--menu_saves` = visual padrão + equipamento inicial da classe), ocioso no idle da arma;
## vazio/danificado = silhueta translúcida (`SILHOUETTE_PATH`) ou pedestal vazio se a malha não existir.
## Só apresentação: lê o arquivo do save (`SaveSystem.load_data`), nunca a sim.
##   var p := PedestalPreview.create(menu_set); add_child(p); list.selection_changed.connect(p.show_slot)

const SILHOUETTE_PATH := "res://assets/models/menu_silhouette.glb"
const SILHOUETTE_COLOR := Color(0.72, 0.84, 1.0, 0.28)        # vazio: vulto azulado
const SILHOUETTE_CORRUPT := Color(1.0, 0.45, 0.38, 0.22)      # danificado: vulto avermelhado
const SILHOUETTE_GLOW := 1.4
const MAX_MODELS := 3                    # bonecos montados guardados (trocar de card sem instanciar o kit de novo)
const OUTLINE := 0.025                   # = EntityView (o cenário usa a escala do mundo)

## Cenas dos kits por "classe_sexo" (referência viva = o `load` do KitModel.create acerta o cache). Por instância, não
## estático: um estático segura o kit até o fim do processo ("resources still in use at exit").
var _scenes: Dictionary = {}

var menu_set: MenuSet
var slot := -1                           # espaço mostrado (-1 = nada)
var kind := ""                           # "ok" | "empty" | "corrupt" | "" (limpo)
var _models: Dictionary = {}             # "classe_sexo" -> KitModel (fora da árvore quando não aparece)
var _order: Array[String] = []           # mais recente no fim
var _kit: KitModel = null
var _sil: Node3D = null
var _eq_count := 0

static func create(set_: MenuSet) -> PedestalPreview:
	var p := PedestalPreview.new()
	p.name = "PedestalPreview"
	p.menu_set = set_
	return p

## Mostra o personagem do espaço `slot` da fonte da lista (`CharList.slots()`).
func show_slot(slot_: int) -> void:
	var src := CharList.slots()
	var i := -1
	for j in range(src.count()):
		if src.slot_of(j) == slot_:
			i = j
	if i < 0:
		clear()
		return
	slot = slot_
	kind = src.state(i)
	if kind != CharList.KIND_OK:
		_show_kit(null)
		_show_silhouette(kind)
		return
	var d := src.summary(i)
	if src is CharList.SaveSlots:                # save de verdade: visual e equipamento do arquivo
		var full := SaveSystem.load_data(slot_)
		if not full.is_empty():
			d = full
	show_data(d)

## Mostra um personagem a partir dos dados do save (ou do resumo): `class`, `look`, `equipment`.
func show_data(d: Dictionary) -> void:
	var cls: ClassDef = GameData.classes.get(str(d.get("class", "")), GameData.classes["paladin"])
	var look := LooksCatalog.normalized(d.get("look", {}), cls)
	var key := "%s_%s" % [cls.id, str(look.get("sex", cls.body_type))]
	var k := _model(key, cls, str(look.get("sex", cls.body_type)))
	_show_silhouette("")
	_show_kit(k)
	if k == null:
		return
	k.apply_look(look)
	var eq := equipment_of(d, cls)
	_eq_count = eq.size()
	k.apply_equipment(eq)
	var main: ItemDef = eq.get(ItemDef.Slot.WEAPON)
	play_idle(k, main.weapon_type if main else "")

## Criação (CharCreate): kit da classe com o visual `look` e o equipamento `eq` (slot -> ItemDef) no pedestal, mesmo
## cache de kits da lista. Não mexe na animação (a Criação toca a demonstração/idle). null = classe sem kit.
func show_create(cls: ClassDef, look: Dictionary, eq: Dictionary) -> KitModel:
	var sex := str(look.get("sex", cls.body_type))
	var k := _model("%s_%s" % [cls.id, sex], cls, sex)
	slot = -1
	kind = CharList.KIND_OK if k else ""
	_show_silhouette("")
	_show_kit(k)
	if k == null:
		return null
	k.apply_look(LooksCatalog.normalized(look, cls))
	_eq_count = eq.size()
	k.apply_equipment(eq)
	return k

## Pedestal vazio (Título/Criação).
func clear() -> void:
	slot = -1
	kind = ""
	_show_kit(null)
	_show_silhouette("")

## Boneco no pedestal (null = nenhum: vazio, danificado ou limpo).
func kit() -> KitModel:
	return _kit

func silhouette() -> Node3D:
	return _sil

## Peças vestidas no boneco atual (testes).
func equipment_count() -> int:
	return _eq_count if _kit else 0

## Equipamento do save (`equipment`: "slot" -> id, como o `SaveSystem.apply_to`); sem nada = o inicial da classe.
static func equipment_of(d: Dictionary, cls: ClassDef) -> Dictionary:
	var eq := {}
	var saved: Dictionary = d.get("equipment", {}) if d.get("equipment", {}) is Dictionary else {}
	for k in saved:
		var eid := SaveSystem.migrate_item_id(str(saved[k]))
		if not GameData.resolve_item(eid):
			continue
		var it: ItemDef = GameData.items.get(eid)
		if it:
			eq[SaveSystem.saved_slot(int(k), it)] = it
	if eq.is_empty():
		for iid in cls.starting_equipment:
			var it: ItemDef = GameData.items.get(iid)
			if it:
				eq[it.slot] = it
	return eq

# ------------------------------------------------------------------ montagem
func _model(key: String, cls: ClassDef, sex: String) -> KitModel:
	if _models.has(key) and is_instance_valid(_models[key]):
		_order.erase(key)
		_order.append(key)
		return _models[key]
	if not KitModel.exists(sex, cls.id):
		return null
	var path := KitModel.path_for(sex, cls.id)
	if not _scenes.has(key):
		_scenes[key] = load(path)
	var k := KitModel.create(sex, cls.hair_color, OUTLINE, cls.id)
	if k == null:
		return null
	_models[key] = k
	_order.append(key)
	while _order.size() > MAX_MODELS:          # o mais antigo que não está no pedestal sai
		var old: String = _order.pop_front()
		var m: KitModel = _models.get(old)
		_models.erase(old)
		_scenes.erase(old)                     # a cena do kit sai junto (o boneco já instanciado não precisa dela)
		if m and is_instance_valid(m) and m != _kit:
			if m.get_parent():
				m.get_parent().remove_child(m)
			m.free()
	return k

func _show_kit(k: KitModel) -> void:
	if _kit and is_instance_valid(_kit) and _kit != k and _kit.get_parent():
		_kit.get_parent().remove_child(_kit)      # fica guardado em _models
	_kit = k
	if menu_set:
		menu_set.place_character(k)          # null só esquece; a silhueta (se houver) entra depois

## Idle da arma (arco baixo, cajado em pé), como o `EntityView`.
static func play_idle(k: KitModel, weapon_type: String, fade := -1.0) -> void:
	if k.anim == null:
		return
	var fam := "bow" if weapon_type == "bow" else ("staff" if weapon_type in ["staff", "wand", "scythe", "scepter"] else "")
	var clip := k.resolve("idle_" + fam) if fam != "" else ""
	if clip == "":
		clip = k.resolve("idle")
	if clip != "" and k.anim.current_animation != clip:
		k.anim.play(clip, fade)

## Vulto translúcido no pedestal ("" = some). Sem a malha (`SILHOUETTE_PATH`) o pedestal fica vazio.
func _show_silhouette(state: String) -> void:
	if state == "" or not ResourceLoader.exists(SILHOUETTE_PATH):
		if _sil and _sil.get_parent():
			_sil.get_parent().remove_child(_sil)
			if menu_set and menu_set.character() == _sil:
				menu_set.place_character(null)
		return
	if _sil == null:
		var scene := load(SILHOUETTE_PATH) as PackedScene
		if scene == null:
			return
		_sil = scene.instantiate() as Node3D
		_sil.name = "Silhouette"
		var aps := _sil.find_children("*", "AnimationPlayer", true, false)
		if not aps.is_empty():                     # o vulto respira no clipe `idle` do GLB (chega sem laço)
			var ap := aps[0] as AnimationPlayer
			if ap.has_animation("idle"):
				ap.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
				ap.play("idle")
	_tint_silhouette(_sil, SILHOUETTE_CORRUPT if state == CharList.KIND_CORRUPT else SILHOUETTE_COLOR)
	if menu_set:
		menu_set.place_character(_sil)

static func _tint_silhouette(n: Node, c: Color) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = Color(c.r, c.g, c.b)
		m.emission_energy_multiplier = SILHOUETTE_GLOW
		m.cull_mode = BaseMaterial3D.CULL_BACK
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS      # vulto inteiro, sem ver as costas por dentro
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for ch in n.get_children():
		_tint_silhouette(ch, c)

func _exit_tree() -> void:
	for key in _models:
		var m: KitModel = _models[key]
		if m and is_instance_valid(m) and m.get_parent() == null:
			m.free()
	_models.clear()
	_scenes.clear()
	if _sil and is_instance_valid(_sil) and _sil.get_parent() == null:
		_sil.free()
