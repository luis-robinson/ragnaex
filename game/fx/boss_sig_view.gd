class_name BossSigView
extends MeshInstance3D
## Avisos das assinaturas de chefe (GDD design/gdd/act2-boss-signatures.md) desenhados a cada quadro a partir do estado
## da sim (m["hazards"], m["covers"], SimEntity.sig): faixas, anéis, ilhas da maré, chão que fica, marcas que seguem,
## anel do canal, cunha da Muralha com a fúria, sombras seguras atrás dos pedregulhos. Uma malha só (cor no vértice).
## O círculo comum da chuva continua no FxManager (_on_hazard_placed); a investida em linha também (_telegraph).
## Cores (mesma gramática do FxManager.DANGER*): dano = carmim (área fraca + miolo que enche) com borda CREME que pulsa
## enquanto carrega (lava é laranja com crosta escura e nunca tem borda: os dois não se confundem),
## lugar seguro = frio/areia (ilhas da maré, sombra do pedregulho), dividir = SÓ dourado (miolo + borda + vagas; o único
## positivo: nada de verde/branco), sombra/controle = roxo.
## A identidade de cada chefe vem da FORMA (anéis com lascas, faixas com divisas, retícula, machado), nunca de cor contrária.

const RED := Color(0.9, 0.08, 0.16, 0.40)          # carmim (FxManager.DANGER)
const RED_SOLID := Color(0.95, 0.1, 0.16, 0.9)     # traços cheios em carmim (retícula, anel que fecha)
const RED_EDGE := Color(1.0, 0.95, 0.8, 0.95)      # borda creme (FxManager.DANGER_RIM); desenhe com _rim (pulsa)
const GOLD_RIM := Color(1.0, 0.78, 0.22, 0.95)     # dividir: borda e anel que fecha
const GOLD_LIT := Color(1.0, 0.84, 0.3, 0.95)      # dividir: vaga ocupada
const GOLD_DIM := Color(0.42, 0.3, 0.1, 0.7)       # dividir: vaga vazia
const SAND := Color(0.98, 0.92, 0.7, 0.95)
const FOAM := Color(1.0, 1.0, 1.0, 0.95)
const WATER := Color(0.15, 0.45, 0.95, 0.6)
const POOL := Color(1.0, 0.5, 0.12, 0.38)
const GOLD := Color(1.0, 0.78, 0.22, 0.18)          # dividir: miolo (fraco: o grupo dentro continua visível)
const AMBER := Color(1.0, 0.68, 0.2, 0.30)
const SAFE := Color(0.8, 1.0, 0.92, 0.62)
const DUST := Color(0.62, 0.42, 0.22, 0.42)
const DUST_HOT := Color(1.0, 0.62, 0.25, 0.75)
const VENOM := Color(0.5, 0.26, 0.72, 0.34)       # nuvem das cópias do Shazka: roxo de sombra (a borda quente diz que machuca)
const SHARD_GLOW := Color(1.0, 0.45, 0.15)         # runas das lascas do Gorbash (o .glb traz verde)
const SEG := 40
const MIRROR_SCALE := 1.3                 # Espelho de Pé (~1,9 m no GLB): legível de cima; a área segura de verdade é o setor SAFE no chão

var fx                                   # FxManager (main e mapa atual)
var _am := ArrayMesh.new()
var _mat: StandardMaterial3D
var _rock_mat: StandardMaterial3D
var _stones: Dictionary = {}             # id do pedregulho -> MeshInstance3D
var _mirror_ap: Dictionary = {}          # id da cobertura com modelo (Espelho de Pé) -> AnimationPlayer (null = sem clipes)
var _mirror_cracked: Dictionary = {}     # id -> já tocou o `crack`
var _pools: Dictionary = {}              # id do hazard -> poça de lava do Kragmar (prop_kragmar_lavapool)
var _pool_seen: Dictionary = {}
var _props: Dictionary = {}              # chave -> modelo de assinatura (tambor, ilhas, marca, faixas, muralha, fumaça)
var _props_seen: Dictionary = {}
var _shard_mesh: Mesh = null             # lasca do Gorbash (MultiMesh ao longo do anel aceso)
var _tint_hot: Material = null
var _tint_cold: Material = null
var _v := PackedVector3Array()
var _next := {}                          # dono -> hora da próxima faixa/anel a cair (a próxima fica acesa)
var _c := PackedColorArray()
var _rim := RED_EDGE                     # borda creme do quadro (alfa pulsa)

func _ready() -> void:
	mesh = _am
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.vertex_color_use_as_albedo = true
	_mat.vertex_color_is_srgb = true
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.disable_fog = true
	_rock_mat = StandardMaterial3D.new()
	_rock_mat.albedo_color = Color(0.52, 0.5, 0.48)
	_rock_mat.roughness = 1.0

func _process(_delta: float) -> void:
	_v.clear()
	_c.clear()
	_rim.a = lerpf(FxManager.DANGER_RIM_LOW_A, RED_EDGE.a, 0.5 + 0.5 * cos(Sim.time * PI / FxManager.DANGER_RIM_PULSE))
	var map_id: String = fx.main.current_map_id if fx and fx.main else ""
	var m: Dictionary = Sim.maps.get(map_id, {})
	var seen := {}
	_pool_seen.clear()
	_props_seen.clear()
	if not m.is_empty():
		var now: float = Sim.time
		_next.clear()
		for h in m.get("hazards", []):
			if (h.get("sig_line", false) or h.get("sig_ring", false)) and not h.get("landed", false):
				var k := int(h["owner"])
				_next[k] = minf(float(_next.get(k, INF)), float(h["at"]))
		for h in m.get("hazards", []):
			_hazard(h, now, m)
		for c in m.get("covers", []):
			seen[int(c["id"])] = true
			_stone(c)
		for e: SimEntity in m["entities"]:
			if e.kind != SimEntity.Kind.MONSTER or not e.is_alive():
				continue
			if e.monster_def.is_boss:
				_boss(e, m, now)
			elif e.monster_def.decoy:                 # Sombras Gêmeas: fumaça girando sob cada cópia
				var sm := _prop("dc_%d" % e.id, "shazka_decoy_smoke", false, Balance.SHAZKA_SMOKE_ALPHA)
				if sm:
					sm.position = Vector3(e.position.x, 0.0, e.position.z)
					sm.rotation.y = now * 0.9 + float(e.id)
	for id in _stones.keys():
		if not seen.has(id):
			(_stones[id] as Node).queue_free()
			_stones.erase(id)
			_mirror_ap.erase(id)
			_mirror_cracked.erase(id)
	for id in _pools.keys():
		if not _pool_seen.has(id):
			if _pools[id] != null:
				(_pools[id] as Node).queue_free()
			_pools.erase(id)
	for k in _props.keys():
		if not _props_seen.has(k):
			if _props[k] != null:
				(_props[k] as Node).queue_free()
			_props.erase(k)
	_am.clear_surfaces()
	if _v.is_empty():
		return
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = _v
	arr[Mesh.ARRAY_COLOR] = _c
	_am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_am.surface_set_material(0, _mat)

# --- formas (triângulos com cor no vértice) ---

func _tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	_v.append(a); _v.append(b); _v.append(c)
	_c.append(col); _c.append(col); _c.append(col)

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	_tri(a, b, c, col)
	_tri(a, c, d, col)

## Anel (ou arco de a0 a a1) entre r0 e r1 em volta de p, na altura y.
func _ring(p: Vector3, r0: float, r1: float, col: Color, y: float, a0: float = 0.0, a1: float = TAU) -> void:
	var n := maxi(6, int(SEG * absf(a1 - a0) / TAU))
	for i in range(n):
		var t0 := a0 + (a1 - a0) * i / n
		var t1 := a0 + (a1 - a0) * (i + 1) / n
		var d0 := Vector3(sin(t0), 0, cos(t0))
		var d1 := Vector3(sin(t1), 0, cos(t1))
		var b := Vector3(p.x, y, p.z)
		_quad(b + d0 * r0, b + d0 * r1, b + d1 * r1, b + d1 * r0, col)

func _disc(p: Vector3, r: float, col: Color, y: float) -> void:
	var b := Vector3(p.x, y, p.z)
	for i in range(SEG):
		var t0 := TAU * i / SEG
		var t1 := TAU * (i + 1) / SEG
		_tri(b, b + Vector3(sin(t0), 0, cos(t0)) * r, b + Vector3(sin(t1), 0, cos(t1)) * r, col)

## Faixa de `start` na direção `dir`, `length` de comprido (só o trecho 0..frac) e `w` de largura.
func _strip(start: Vector3, dir: Vector3, length: float, w: float, col: Color, y: float, frac: float = 1.0) -> void:
	var side := Vector3(-dir.z, 0, dir.x) * (w * 0.5)
	var a := Vector3(start.x, y, start.z)
	var b := a + dir * (length * clampf(frac, 0.0, 1.0))
	_quad(a - side, a + side, b + side, b - side, col)

# --- hazards ---

func _hazard(h: Dictionary, now: float, m: Dictionary) -> void:
	var p: Vector3 = h["pos"]
	var total: float = maxf(0.2, float(h["at"]) - float(h.get("t0", float(h["at"]) - 1.5)))
	var t := clampf(1.0 - (float(h["at"]) - now) / total, 0.0, 1.0)
	if h.get("landed", false):                     # chão que fica (poça, fogo)
		var r := float(h["radius"]) if str(h.get("shape", "circle")) != "line" else float(h["width"]) * 0.5
		if str(h.get("shape", "circle")) == "circle" and h.get("empower") is Dictionary and _lava_pool(h, now):
			return                                     # Têmpera na Lava: modelo da poça (some aos poucos no fim)
		if str(h.get("shape", "circle")) == "circle":
			var pc := VENOM if h.get("decoy_cloud", false) else POOL
			_disc(p, r, pc, 0.06)
			_ring(p, r - 0.12, r, _rim if h.get("decoy_cloud", false) else Color(pc.r, pc.g, pc.b, 0.8), 0.065)
		elif str(h.get("shape", "")) == "line":         # faixa que fica (cauda de fitas do Cortejo): a poça esticada
			_strip(p, h["dir"], float(h["length"]), float(h["width"]), POOL, 0.06)
		return
	if h.get("invert", false):                     # Maré Cheia: a água fecha da borda, as ilhas ficam secas
		var c: Vector3 = h.get("center", p)
		var rr := float(h.get("range", Balance.BOSS_INVERT_RANGE))
		if int(h["group"]) == int(h["id"]):
			_ring(c, rr * (1.0 - t * 0.98), rr, WATER, 0.05)
			_ring(c, rr - 0.25, rr, Color(0.6, 0.85, 1.0, 0.9), 0.055)
		_disc(p, float(h["radius"]), SAND, 0.08)
		_ring(p, float(h["radius"]) - 0.35, float(h["radius"]), FOAM, 0.085)
		var k := float(h["radius"]) / 2.5                # prop_tide_island: ilha de 2,5 m; prop_tide_floodring: espuma 2,6-3,4 m em volta
		for pair in [["is_%d", "tide_island"], ["fl_%d", "tide_floodring"]]:
			var n := _prop(str(pair[0]) % int(h["id"]), str(pair[1]))
			if n:
				n.position = Vector3(p.x, 0.0, p.z)
				n.scale = Vector3(k, 1.0, k)
				if str(pair[1]) == "tide_floodring":
					n.rotation.y = now * 0.25
		return
	if h.get("mark", false):
		var r := float(h["radius"])
		if str(h.get("mode", "")) == "soak":         # dividir: círculo dourado com vagas que acendem
			_disc(p, r, GOLD, 0.07)
			_ring(p, r - 0.2, r, GOLD_RIM, 0.075)
			var inside := 0
			for o: SimEntity in m.get("chars", m["entities"]):
				if o.is_alive() and o.is_character() and Vector2(o.position.x - p.x, o.position.z - p.z).length() <= r + o.radius:
					inside += 1
			for k in range(3):
				var a := TAU * k / 3.0 + now * 0.6
				_disc(p + Vector3(sin(a), 0, cos(a)) * (r * 0.62), 0.35, GOLD_LIT if k < inside else GOLD_DIM, 0.08)
			# Machado do Trono: prop_durgash_throneaxe (3,25 m, ponta da lâmina na origem) gira devagar sobre o círculo
			# e desce até cravar no chão quando a marca cai; o anel de dentro fecha com o tempo
			_ring(p, maxf(0.0, r * (1.0 - t) - 0.12), maxf(0.12, r * (1.0 - t)), GOLD_RIM, 0.078)
			if str(h.get("skill", "")) == "mob_durgash_throneaxe":
				var ax := _prop("ax_%d" % int(h["id"]), "durgash_throneaxe", true)
				if ax:
					ax.position = Vector3(p.x, Balance.DURGASH_AXE_HOVER * (1.0 - t * t), p.z)
					ax.rotation.y = now * 1.2
		else:                                         # espalhar: retícula vermelha + anel que encolhe até a explosão
			_ring(p, r - 0.18, r, _rim, 0.07)
			_ring(p, maxf(0.0, r * (1.0 - t) - 0.15), maxf(0.15, r * (1.0 - t)), RED_SOLID, 0.075)
			_disc(p, r, Color(RED, 0.16), 0.065)
			for k in range(4):
				var a := TAU * k / 4.0
				var d := Vector3(sin(a), 0, cos(a))
				_strip(p + d * (r * 0.55), d, r * 0.55, 0.16, RED_SOLID, 0.072)
			var br := _prop("br_%d" % int(h["id"]), "vorgul_brand")       # Marca do Atirador: retícula 1 m (escala pelo raio) + seta sobre a vítima
			if br:
				br.position = Vector3(p.x, 0.0, p.z)
				br.scale = Vector3(r, 1.0, r)
				br.rotation.y = now * 0.6
				var arrow := br.find_child("brand_arrow", true, false) as Node3D
				if arrow:
					arrow.scale = Vector3(1.0 / r, 1.0, 1.0 / r)
					arrow.position.y = 0.18 * sin(now * 5.0)
		return
	match str(h.get("shape", "circle")):
		"line":                                       # Estouro da Matilha: poeira marrom com setas do galope; a próxima acesa
			var dir: Vector3 = h["dir"]
			var hot: bool = is_equal_approx(float(_next.get(int(h["owner"]), -1.0)), float(h["at"]))
			var w := float(h["width"])
			var ln := float(h["length"])
			_stampede(h, p, dir, ln, w, hot)
			_strip(p, dir, ln, w, DUST if not hot else Color(0.8, 0.5, 0.22, 0.55), 0.06)
			_strip(p, dir, ln, w, Color(RED, 0.5 if hot else 0.3), 0.065, t)
			var side := Vector3(-dir.z, 0, dir.x)
			for k in [-1.0, 1.0]:
				_strip(p + side * (w * 0.5 - 0.1) * k, dir, ln, 0.18, DUST_HOT if hot else Color(0.85, 0.6, 0.35, 0.6), 0.07)
			var arrows := int(ln / 4.0)
			for i in range(arrows):                   # divisas (>) correndo no sentido do galope
				var c := p + dir * (ln * fmod(i + 0.5 + fmod(now * 1.5, 1.0), float(arrows)) / arrows)
				for k in [-1.0, 1.0]:
					var tip: Vector3 = c + dir * 0.6
					var back: Vector3 = c - dir * 0.5 + side * (w * 0.32) * k
					_quad(Vector3(back.x, 0.075, back.z), Vector3(tip.x, 0.075, tip.z), Vector3(tip.x, 0.075, tip.z) - dir * 0.35, Vector3(back.x, 0.075, back.z) - dir * 0.35,
						DUST_HOT if hot else Color(0.95, 0.75, 0.45, 0.7))
		"ring":                                       # Ondas da Montanha: rachadura; o próximo anel aceso
			var hot: bool = is_equal_approx(float(_next.get(int(h["owner"]), -1.0)), float(h["at"]))
			if hot:                                   # só o que cai agora é cheio; os outros, rachadura fina (não pinta a arena toda)
				_ring(p, float(h["inner"]), float(h["radius"]), Color(RED, 0.12), 0.07)          # área fraca
				var mid := (float(h["inner"]) + float(h["radius"])) * 0.5                                 # miolo enche do meio para as bordas
				var half := (float(h["radius"]) - float(h["inner"])) * 0.5 * t
				_ring(p, mid - half, mid + half, Color(RED, 0.28), 0.072)
				_shards(h, p, t)
			var edge := _rim if hot else Color(0.35, 0.22, 0.15, 0.55)
			_ring(p, float(h["radius"]) - 0.12, float(h["radius"]), edge, 0.065)
			_ring(p, float(h["inner"]), float(h["inner"]) + 0.12, edge, 0.065)

## Pedregulho do Troll Rei: o modelo prop_avalanche_stone (toon, MapBuilder.prop_model; raio 1,2 m no modelo), na escala da cobertura.
func _stone(c: Dictionary) -> void:
	var id := int(c["id"])
	if _stones.has(id):
		if c.get("cracked", false) and not _mirror_cracked.has(id):
			_mirror_cracked[id] = true
			var ap: AnimationPlayer = _mirror_ap.get(id)
			if ap and ap.has_animation("crack"):
				ap.play("crack")
				if ap.has_animation("idle_cracked"):
					ap.queue("idle_cracked")
		return
	if c.has("model"):
		var mn := _mirror(c)
		if mn:
			add_child(mn)
			_stones[id] = mn
			return
	var r := float(c["radius"])
	var k := r / 1.2
	var node: Node3D = MapBuilder.prop_model("avalanche_stone", Vector3(2.4, 2.56, 2.4) * k)
	var y := 0.0
	if node == null:                         # sem o modelo: esfera achatada cinza
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 1.4
		sm.radial_segments = 7
		sm.rings = 4
		mi.mesh = sm
		mi.material_override = _rock_mat
		node = mi
		y = r * 0.45
	var p: Vector3 = c["pos"]
	node.position = Vector3(p.x, y, p.z)
	node.rotation.y = float(id) * 1.7
	add_child(node)
	_stones[id] = node

## Espelho de Pé (Olhar Que Julga, Condessa): o GLB de monstro `c["model"]` em toon (como os props), virado para o dono
## da cobertura; toca `idle` e, quando a sim marca `cracked`, `crack` e depois `idle_cracked` (_stone). null = sem o modelo.
func _mirror(c: Dictionary) -> Node3D:
	var path := "res://assets/models/%s.glb" % str(c["model"])
	if not ResourceLoader.exists(path):
		return null
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in range(m.get_surface_override_material_count()):
			var base := m.get_active_material(i)
			var col: Color = base.albedo_color if base is BaseMaterial3D else Color(0.85, 0.88, 0.95)
			var emission: float = base.emission_energy_multiplier if (base is BaseMaterial3D and base.emission_enabled) else 0.0
			m.set_surface_override_material(i, Materials.toon(col, true, minf(emission, 2.0)))
	var holder := Node3D.new()
	holder.add_child(inst)
	holder.scale = Vector3.ONE * MIRROR_SCALE
	var p: Vector3 = c["pos"]
	holder.position = Vector3(p.x, 0.0, p.z)
	var owner: SimEntity = Sim.entities.get(int(c["owner"]))
	if owner:
		holder.rotation.y = atan2(owner.position.x - p.x, owner.position.z - p.z)
	var aps := inst.find_children("*", "AnimationPlayer", true, false)
	var ap: AnimationPlayer = aps[0] if not aps.is_empty() else null
	if ap:
		for a in ["idle", "idle_cracked"]:
			if ap.has_animation(a):
				ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR     # glTF chega sem laço (recurso compartilhado)
		if ap.has_animation("idle"):
			ap.play("idle")
	_mirror_ap[int(c["id"])] = ap
	return holder

## Poça de lava do Kragmar: prop_kragmar_lavapool (lava ~2,2 m de raio na escala 1, borda 2,5 m), lava com o material de
## fogo (convenção glow_lava do MapBuilder). Nos 2 s finais afunda. false = sem o modelo (desenha o disco).
func _lava_pool(h: Dictionary, now: float) -> bool:
	var id := int(h["id"])
	_pool_seen[id] = true
	if not _pools.has(id):
		var holder: Node3D = MapBuilder.prop_model("kragmar_lavapool", Vector3.ONE)
		if holder != null and holder.get_child_count() == 0:
			holder.free()                    # modelo vazio: vale como sem modelo (desenha o disco, sem nó solto)
			holder = null
		if holder != null:
			var inst := holder.get_child(0) as Node3D
			inst.scale = Vector3.ONE * (float(h["radius"]) / 2.2)
			for mi in inst.find_children("*", "MeshInstance3D", true, false):
				var mm := mi as MeshInstance3D
				mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				for i in range(mm.mesh.get_surface_count()):
					var src := mm.mesh.surface_get_material(i)
					if src != null and src.resource_name.begins_with("glow_lava"):
						var col: Color = (src as BaseMaterial3D).albedo_color if src is BaseMaterial3D else Color(1.0, 0.45, 0.1)
						mm.set_surface_override_material(i, Materials.fire(col.srgb_to_linear()))
			var p: Vector3 = h["pos"]
			holder.position = Vector3(p.x, 0.0, p.z)
			holder.rotation.y = float(id) * 2.3
			add_child(holder)
		_pools[id] = holder
	var node: Node3D = _pools[id]
	if node == null:
		return false
	var left := float(h.get("until", now + 99.0)) - now
	node.position.y = -0.08 * (1.0 - clampf(left / 2.0, 0.0, 1.0))
	return true

# --- chefes: canal, Muralha, preparo da Avalanche, Têmpera ---

func _boss(e: SimEntity, m: Dictionary, now: float) -> void:
	var p := e.position
	if e.sig.has("decoys"):                          # Sombras Gêmeas: só o verdadeiro tem sombra (reforço para chão escuro de masmorra)
		_disc(p, e.radius * 1.5, Color(0.0, 0.0, 0.0, 0.6), 0.04)
		_disc(p, e.radius * 1.05, Color(0.0, 0.0, 0.0, 0.35), 0.045)
	var temper := e.buff_stacks(BossSignatures.TEMPER_BUFF)
	if temper > 0:                                   # Têmpera: anel em brasa nos pés que fecha com os acúmulos + brasas sobre a cabeça
		var r0 := e.radius + 0.5
		_ring(p, r0, r0 + 0.35, Color(0.2, 0.06, 0.02, 0.55), 0.07)
		_ring(p, r0, r0 + 0.35, Color(1.0, 0.45, 0.08, 0.95), 0.075, 0.0, TAU * float(temper) / float(Balance.KRAGMAR_TEMPER_MAX))
		var ty := 2.3 * e.monster_def.scale + 0.3
		for i in range(temper):
			var off := (float(i) - (temper - 1) * 0.5) * 0.45
			_disc(p + Vector3(off, 0, 0), 0.17, Color(1.0, 0.5 + 0.08 * i, 0.1, 1.0), ty)
	if e.sig.has("channel"):
		var dr := _prop("dr_%d" % e.id, "grukk_wardrum", true)       # Rufar da Turba: tambor plantado ao lado do Grukk enquanto o canal dura
		if dr and not dr.has_meta("planted"):
			dr.set_meta("planted", true)
			var f0 := e.forward()
			var side := Vector3(-f0.z, 0, f0.x)
			dr.position = Vector3(p.x, 0.0, p.z) + side * (e.radius + Balance.GRUKK_DRUM_GAP)
			dr.rotation.y = e.facing
		var k := BossSignatures.channel_progress(Sim, e)
		var r := e.radius + 1.6
		_ring(p, r, r + 0.45, Color(0.15, 0.08, 0.05, 0.6), 0.07)
		_ring(p, r, r + 0.45, Color(1.0, 0.35 + 0.4 * k, 0.1, 0.95), 0.075, 0.0, TAU * k)
	if e.sig.has("wall") and Balance.GHAR_SIDE_SHIELDS:              # Muralha: os escudos dos lados (o da frente é o do braço do modelo)
		var sw := _prop("sw_%d" % e.id, "ghar_shieldwall", true)
		if sw:
			sw.position = Vector3(p.x, 0.0, p.z)
			sw.rotation.y = e.facing
			sw.scale = Vector3.ONE * Balance.GHAR_SHIELDWALL_SCALE
	if e.sig.has("wall"):
		var f := e.forward()
		var half := deg_to_rad(Balance.GHAR_WALL_ARC_DEG * 0.5)
		var a := atan2(f.x, f.z)
		_ring(p, e.radius + 0.2, e.radius + 4.0, AMBER, 0.06, a - half, a + half)
		_ring(p, e.radius + 3.75, e.radius + 4.0, Color(1.0, 0.75, 0.25, 0.9), 0.065, a - half, a + half)
		var fury := int(e.sig["wall"]["fury"])
		var y := 2.3 * e.monster_def.scale + 0.3
		for i in range(mini(fury, 12)):
			var off := (float(i) - (mini(fury, 12) - 1) * 0.5) * 0.45
			_disc(p + Vector3(off, 0, 0), 0.17, Color(1.0, 0.45, 0.1, 1.0), y)
	if e.current_skill != null and e.skill_phase == "startup" and e.current_skill.effects.has("avalanche"):
		var rr := float((e.current_skill.effects["avalanche"] as Dictionary).get("radius", 18.0))
		_ring(p, rr - 0.3, rr, _rim, 0.06)
		_ring(p, 0.0, rr, Color(RED, 0.10), 0.05)
		for c in BossSignatures.covers_of(m, e.id):
			var cp: Vector3 = c["pos"]
			var d := Vector2(cp.x - p.x, cp.z - p.z)
			var dl := d.length()
			if dl <= float(c["radius"]) or dl >= rr:
				continue
			var mid := atan2(d.x, d.y)
			var half := asin(clampf(float(c["radius"]) / dl, 0.0, 1.0))
			_ring(p, dl, rr, SAFE, 0.065, mid - half, mid + half)

# --- modelos das assinaturas (dressing: o aviso colorido continua sendo a leitura do perigo) ---

## Modelo prop_<kind> no tamanho do Blender (MapBuilder.prop_model: toon + contorno), brilho glow_* como no mapa
## (glow_lava/glow_brasa = fogo, outros glow_ = brilho), sem sombra salvo `shadow`; `alpha` > 0 = translúcido (fumaça).
## Superfícies `tint` ficam no meta "tint" ([MeshInstance3D, índice]) para a cor mudar depois.
func _sig_model(kind: String, shadow: bool = false, alpha: float = 0.0) -> Node3D:
	var holder: Node3D = MapBuilder.prop_model(kind, Vector3.ONE)
	if holder == null:
		return null
	if holder.get_child_count() > 0 and holder.get_child(0) is Node3D:
		(holder.get_child(0) as Node3D).scale = Vector3.ONE
	var tints: Array = []
	for mi in holder.find_children("*", "MeshInstance3D", true, false):
		var mm := mi as MeshInstance3D
		if not shadow:
			mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in range(mm.mesh.get_surface_count()):
			var src := mm.mesh.surface_get_material(i)
			var nm := src.resource_name if src else ""
			var col: Color = (src as BaseMaterial3D).albedo_color if src is BaseMaterial3D else Color(0.8, 0.8, 0.8)
			if nm.begins_with("glow_lava") or nm.begins_with("glow_brasa"):
				mm.set_surface_override_material(i, Materials.fire(col.srgb_to_linear()))
			elif nm.begins_with("glow_"):
				mm.set_surface_override_material(i, Materials.glow(col.srgb_to_linear(), 1.5))
			elif alpha > 0.0:
				var c := col.srgb_to_linear()
				mm.set_surface_override_material(i, Materials.flat(Color(c.r, c.g, c.b, alpha), true))
			elif nm == "tint":
				tints.append([mm, i])
	holder.set_meta("tint", tints)
	return holder

## Modelo de assinatura por chave (criado na 1ª vez, solto quando a chave some do quadro). null = sem o .glb.
func _prop(key: String, kind: String, shadow: bool = false, alpha: float = 0.0) -> Node3D:
	_props_seen[key] = true
	if not _props.has(key):
		var n := _sig_model(kind, shadow, alpha)
		if n:
			add_child(n)
		_props[key] = n
	return _props[key]

## Estouro da Matilha: prop_ulgra_stampede (faixa 3 × 10 m, galope +Z) ladrilhado ao longo da faixa; divisas `tint`
## quentes na próxima faixa a cair (ordem), apagadas nas outras.
func _stampede(h: Dictionary, p: Vector3, dir: Vector3, ln: float, w: float, hot: bool) -> void:
	var n := maxi(1, roundi(ln / 10.0))
	var seg := ln / n
	if _tint_hot == null:
		_tint_hot = Materials.toon(Color(1.0, 0.38, 0.12), true, 1.2)
		_tint_cold = Materials.toon(Color(0.42, 0.36, 0.32))
	for i in range(n):
		var node := _prop("ln_%d_%d" % [int(h["id"]), i], "ulgra_stampede")
		if node == null:
			return
		var c := p + dir * (seg * (i + 0.5))
		node.position = Vector3(c.x, Balance.ULGRA_LANE_SINK, c.z)
		node.rotation.y = atan2(dir.x, dir.z)
		node.scale = Vector3(w / 3.12, 1.0, seg / 10.0)
		for t in node.get_meta("tint", []):
			(t[0] as MeshInstance3D).set_surface_override_material(int(t[1]), _tint_hot if hot else _tint_cold)

## Ondas da Montanha: lascas (prop_gorbash_shockshard, 1,2 m, para fora = +Z) em MultiMesh no meio do anel aceso,
## subindo do chão enquanto o aviso enche (t 0 -> 1).
func _shards(h: Dictionary, p: Vector3, t: float) -> void:
	var key := "rg_%d" % int(h["id"])
	_props_seen[key] = true
	if not _props.has(key):
		var node: MultiMeshInstance3D = null
		var mesh := _shard()
		if mesh != null:
			var mid := (float(h["inner"]) + float(h["radius"])) * 0.5
			var cnt := maxi(6, int(TAU * mid / 1.25))
			var k := clampf((float(h["radius"]) - float(h["inner"])) / 1.6, 0.8, 1.4)
			var mmesh := MultiMesh.new()
			mmesh.transform_format = MultiMesh.TRANSFORM_3D
			mmesh.mesh = mesh
			mmesh.instance_count = cnt
			for i in range(cnt):
				var a := TAU * (i + 0.5) / cnt
				var b := Basis(Vector3.UP, a).scaled(Vector3(k, k * (0.8 + 0.4 * float((i * 7) % 5) / 4.0), k))
				mmesh.set_instance_transform(i, Transform3D(b, Vector3(sin(a), 0, cos(a)) * mid))
			node = MultiMeshInstance3D.new()
			node.multimesh = mmesh
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.position = Vector3(p.x, 0.0, p.z)
			add_child(node)
		_props[key] = node
	var mm: Node3D = _props[key]
	if mm:
		mm.position.y = lerpf(-0.75, 0.0, clampf(t * 1.15, 0.0, 1.0))

func _shard() -> Mesh:
	if _shard_mesh == null:
		var holder := _sig_model("gorbash_shockshard")
		if holder == null:
			return null
		var src := holder.find_children("*", "MeshInstance3D", true, false)
		if not src.is_empty():
			var mi := src[0] as MeshInstance3D
			var mesh := mi.mesh.duplicate() as Mesh
			for i in range(mesh.get_surface_count()):
				var mat := mi.get_surface_override_material(i)
				var src_mat := mi.mesh.surface_get_material(i)
				if src_mat != null and src_mat.resource_name.begins_with("glow_"):     # runas verdes do .glb -> perigo (verde = seguro/cura)
					mat = Materials.glow(SHARD_GLOW.srgb_to_linear(), 1.5)
				if mat != null:
					mesh.surface_set_material(i, mat)
			_shard_mesh = mesh
		holder.free()
	return _shard_mesh
