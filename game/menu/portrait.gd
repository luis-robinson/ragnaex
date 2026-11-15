class_name Portrait
extends RefCounted
## Retrato do card da tela Personagens (design/ux/start-flow.md §3, §9; decisão Q2): cabeça e ombros do personagem,
## fotografados do próprio boneco em jogo e salvos em `user://portrait_<n>.png` (256x256, fundo transparente).
## Sem arquivo, o card usa o ícone da classe. O SaveSystem apaga o arquivo junto com o espaço (`delete_slot`).
##
## Como fotografa: um SubViewport que divide o World3D do jogo (mesmas luzes e toon), com câmera própria que só vê a
## camada 20 (`LAYER`); durante 2 quadros as malhas do boneco ganham essa camada a mais e depois voltam ao normal.
## Nada é instanciado de novo (sem custo de kit). A camada 20 não é usada por mais nada no jogo.

const SIZE := 256
const LAYER := 1 << 19                 # camada 20 do 3D: só a câmera do retrato a enxerga
const FOV := 26.0
const FRAME_H := 1.3                   # altura enquadrada (m, escala 1): cabeça chibi + ombros
const YAW := 0.32                      # câmera um pouco ao lado (rad): dá volume ao rosto

## Arquivo do retrato do espaço `slot` (`SaveSystem.PORTRAIT_PATH`, o mesmo que o `delete_slot` apaga).
static func path(slot: int) -> String:
	return SaveSystem.PORTRAIT_PATH % slot

## Retrato salvo do espaço (null se não houver ou não abrir). Lê do disco a cada chamada (a lista é refeita poucas vezes).
static func texture(slot: int) -> Texture2D:
	if slot < 0 or not FileAccess.file_exists(path(slot)):
		return null
	var img := Image.load_from_file(ProjectSettings.globalize_path(path(slot)))
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)

## Dá para fotografar? (sem tela, headless: não).
static func can_capture() -> bool:
	return DisplayServer.get_name() != "headless"

## Fotografa o boneco `view` e grava `path(slot)`. Não faz nada sem tela (headless), com `slot < 0` (testes, --autostart)
## ou sem boneco na árvore. É uma corrotina (2 quadros): antes de trocar de cena, use `await Portrait.capture(view, slot)`,
## senão o boneco é liberado antes da foto e nada é gravado.
static func capture(view: EntityView, slot: int) -> void:
	if slot < 0 or not can_capture() or view == null or not is_instance_valid(view) or not view.is_inside_tree() \
			or view.model_root == null:
		return
	var tree := view.get_tree()
	var meshes := _meshes(view)
	if meshes.is_empty():
		return
	var sv := SubViewport.new()
	sv.name = "PortraitCapture"
	sv.size = Vector2i(SIZE, SIZE)
	sv.transparent_bg = true
	sv.msaa_3d = Viewport.MSAA_4X
	sv.world_3d = view.get_world_3d()
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cam := Camera3D.new()
	cam.cull_mask = LAYER
	cam.fov = FOV
	cam.environment = _environment(view.get_world_3d())
	sv.add_child(cam)
	tree.root.add_child(sv)                 # na raiz: sobrevive se a cena trocar no meio
	cam.current = true
	_frame(cam, view, meshes)
	for m: MeshInstance3D in meshes:
		m.layers |= LAYER
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	for m: MeshInstance3D in meshes:
		if is_instance_valid(m):
			m.layers &= ~LAYER
	var img := sv.get_texture().get_image()
	if img and not img.is_empty() and _has_pixels(img):
		var err := img.save_png(path(slot))
		if err != OK:
			push_warning("Portrait: não gravou %s (%s)" % [path(slot), error_string(err)])
	sv.queue_free()

## Malhas do boneco (kit, forma, arma); placas de nome e barras ficam de fora (não são MeshInstance3D do modelo).
static func _meshes(view: EntityView) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n in view.model_root.find_children("*", "MeshInstance3D", true, false):
		var m := n as MeshInstance3D
		if m.is_visible_in_tree() and m.mesh != null:
			out.append(m)
	return out

## Enquadra cabeça e ombros, de frente para onde o boneco olha (+Z do modelo), um pouco de lado e de cima.
static func _frame(cam: Camera3D, view: EntityView, meshes: Array[MeshInstance3D]) -> void:
	var root := view.model_root
	var s: float = maxf(0.2, root.global_basis.get_scale().y)
	var head := _head_point(view)
	if head == Vector3.INF:                 # sem osso "head": topo do AABB, descendo meio quadro
		var top := -INF
		for m in meshes:
			var box: AABB = m.global_transform * m.get_aabb()
			top = maxf(top, box.end.y)
		head = Vector3(root.global_position.x, top - FRAME_H * 0.5 * s, root.global_position.z)
	var fwd := root.global_basis.z
	fwd.y = 0.0
	fwd = Vector3.BACK if fwd.length() < 0.01 else fwd.normalized()
	fwd = fwd.rotated(Vector3.UP, YAW)
	var dist := FRAME_H * 0.5 * s / tan(deg_to_rad(FOV * 0.5))
	var eye := head + fwd * dist + Vector3.UP * dist * 0.12
	cam.look_at_from_position(eye, head, Vector3.UP)

## Centro do quadro pelo osso da cabeça do kit (meio da cabeça chibi, um pouco abaixo para pegar os ombros).
static func _head_point(view: EntityView) -> Vector3:
	if view.kit == null or view.kit.skeleton == null:
		return Vector3.INF
	var sk := view.kit.skeleton
	var bi := sk.find_bone("head")
	if bi < 0:
		return Vector3.INF
	var s: float = maxf(0.2, view.model_root.global_basis.get_scale().y)
	return sk.global_transform * sk.get_bone_global_pose(bi).origin + Vector3.UP * 0.2 * s

## Ambiente do jogo (mesma luz ambiente do céu e tonemap) sem desenhar o céu, névoa e brilho: o fundo fica transparente.
static func _environment(world: World3D) -> Environment:
	var env: Environment = world.environment.duplicate() if world and world.environment else Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	env.glow_enabled = false
	env.ssr_enabled = false
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.sdfgi_enabled = false
	if env.ambient_light_source in [Environment.AMBIENT_SOURCE_SKY, Environment.AMBIENT_SOURCE_BG] and env.sky == null:     # o céu continua dando a luz ambiente
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.75, 0.72, 0.8)
		env.ambient_light_energy = 0.6
	return env

## A foto pegou alguma coisa? (quadro todo transparente = boneco fora da câmera: não grava por cima de um retrato bom)
static func _has_pixels(img: Image) -> bool:
	for y in range(0, img.get_height(), 8):
		for x in range(0, img.get_width(), 8):
			if img.get_pixel(x, y).a > 0.05:
				return true
	return false
