class_name LootChest
extends Node3D
## Item no chão: baú de tesouro chibi (madeira, aros dourados, fechadura com a gema da cor do item, brilho da raridade).
## Ouro: montinho de moedas. As malhas e os materiais base são criados uma vez e compartilhados por todos os drops.

static var _meshes: Dictionary = {}
static var _mats: Dictionary = {}

static func _mesh(key: String) -> Mesh:
	if _meshes.has(key):
		return _meshes[key]
	var m: Mesh
	match key:
		"body":
			var b := BoxMesh.new()
			b.size = Vector3(0.5, 0.3, 0.34)
			m = b
		"lid":                       # tampa arredondada: meio cilindro deitado
			var c := CylinderMesh.new()
			c.top_radius = 0.17; c.bottom_radius = 0.17; c.height = 0.5; c.radial_segments = 12
			m = c
		"band":
			var b := BoxMesh.new()
			b.size = Vector3(0.06, 0.33, 0.36)
			m = b
		"lock":
			var b := BoxMesh.new()
			b.size = Vector3(0.1, 0.12, 0.04)
			m = b
		"gem":
			var s := SphereMesh.new()
			s.radius = 0.035; s.height = 0.07; s.radial_segments = 8; s.rings = 4
			m = s
		"coin":
			var c := CylinderMesh.new()
			c.top_radius = 0.1; c.bottom_radius = 0.1; c.height = 0.03; c.radial_segments = 10
			m = c
	_meshes[key] = m
	return m

static func _mat(key: String, col: Color) -> Material:
	if not _mats.has(key):
		_mats[key] = Materials.toon(col)
	return _mats[key]

static func make(item_id: String) -> LootChest:
	var n := LootChest.new()
	n.scale = Vector3.ONE * 1.35       # lido de longe pela câmera alta
	var gold := item_id == "gold" or item_id == "legend_coin"      # moedas: montinho (a lendária é laranja e brilha forte)
	var relic := item_id == "legend_coin"
	var it: ItemDef = GameData.items.get(item_id) if relic or not gold else null
	var rar_col: Color = UiKit.rarity_color(4) if relic else (Color(1.0, 0.85, 0.3) if gold or it == null else UiKit.rarity_color(it.rarity))
	if gold:
		for i in range(4):           # montinho de moedas
			var c := MeshInstance3D.new()
			c.mesh = _mesh("coin")
			c.material_override = _mat("relic", Color(1.0, 0.5, 0.12)) if relic else _mat("gold", Color(1.0, 0.8, 0.25))
			c.position = Vector3(0.06 * sin(i * 2.1), 0.02 + i * 0.03, 0.06 * cos(i * 2.1))
			c.rotation.z = 0.15 * (i % 2)
			n.add_child(c)
	else:
		var wood := _mat("wood", Color(0.52, 0.33, 0.18))
		var trim := _mat("gold", Color(1.0, 0.8, 0.25))
		var body := MeshInstance3D.new()
		body.mesh = _mesh("body")
		body.material_override = wood
		body.position.y = 0.15
		n.add_child(body)
		var lid := MeshInstance3D.new()
		lid.mesh = _mesh("lid")
		lid.material_override = wood
		lid.rotation.z = PI * 0.5
		lid.position.y = 0.3
		lid.scale = Vector3(1.0, 1.0, 1.0)
		n.add_child(lid)
		for sx in [-0.17, 0.17]:     # aros dourados
			var b := MeshInstance3D.new()
			b.mesh = _mesh("band")
			b.material_override = trim
			b.position = Vector3(sx, 0.16, 0)
			n.add_child(b)
		var lock := MeshInstance3D.new()
		lock.mesh = _mesh("lock")
		lock.material_override = trim
		lock.position = Vector3(0, 0.27, 0.18)
		n.add_child(lock)
		var gem := MeshInstance3D.new()
		gem.mesh = _mesh("gem")
		gem.material_override = Materials.glow(it.icon_color if it else rar_col, 1.4)
		gem.position = Vector3(0, 0.27, 0.205)
		n.add_child(gem)
	# a arte do item (ou das moedas) flutuando em cima: dá para ver o que caiu antes de pegar
	var tex: Texture2D = UiKit.item_texture(it) if relic else (UiKit.icon_texture("art_gold") if gold else UiKit.item_texture(it))
	if tex != null:
		var spr := Sprite3D.new()
		spr.texture = tex
		spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		spr.shaded = false
		spr.double_sided = true
		spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		spr.pixel_size = 0.0046
		spr.position.y = 1.05
		spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spr.name = "Icon"
		n.add_child(spr)
	# brilho da raridade (comum quase nada; lendário forte)
	var r: int = 4 if relic else (it.rarity if it else 1)
	var l := OmniLight3D.new()
	l.light_color = rar_col
	l.light_energy = 0.35 + 0.25 * r
	l.omni_range = 1.6 + 0.25 * r
	l.position.y = 0.6
	l.name = "Glow"
	n.add_child(l)
	if r >= 3:                       # épico/lendário: facho de luz para cima
		var beam := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.02; cm.bottom_radius = 0.16; cm.height = 2.2; cm.radial_segments = 8
		beam.mesh = cm
		beam.material_override = Materials.flat(Color(rar_col, 0.3), true)
		beam.position.y = 1.2
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(beam)
	return n
