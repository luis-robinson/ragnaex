class_name EntityView
extends Node3D
## Visual de uma SimEntity. Lê o estado da simulação a cada frame e anima.
## Usa assets/models/<model>.glb quando existir; senão monta um placeholder low-poly "chibi".

var entity: SimEntity
var model_root: Node3D
var anim: AnimationPlayer = null
var mat: ShaderMaterial = null          # material único (hit flash) dos placeholders
var _mats: Array = []                   # todos os materiais toon do GLB (hit flash)
var shade_mat: ShaderMaterial = null    # silhueta no vidro do Reflexo Vaidoso (`*_shade`): pega o tom de quem ele mira
var _shade_idle := Color()              # azul-cinza do modelo (sem alvo)
var _shade_seen := -2                   # aggro_target da última pintura da silhueta
var kit: KitModel = null                # personagens/NPCs: kit modular com as peças do equipamento
var form_view: FormModel = null
var horse: FormModel = null              # montado: o cavalo (o boneco senta na sela)
var _horse_kept: FormModel = null        # o mesmo cavalo volta a cada montada (criar um é caro)
var _horse_kind := ""                     # tipo|cor|armadura do bicho guardado (_mount_key)
var _shown_mount := false
var _ride_legs: RideLegs = null           # pernas presas na sela enquanto golpeia montado (Combate Montado)
const HORSE_SCALE := 1.75
const SADDLE_Y := 1.06                   # quanto o boneco sobe (sela do cavalo escalado − quadril do boneco)
const HORSE_COATS := [Color(0.55, 0.38, 0.24), Color(0.25, 0.18, 0.14), Color(0.9, 0.88, 0.84), Color(0.7, 0.45, 0.25), Color(0.5, 0.5, 0.52), Color(0.85, 0.7, 0.45)]         # Druida transformado: o bicho (o kit fica escondido)
## Lobo atroz (Kharzun, hx_ov_hatch): pelagens cinzentas (cinza-chumbo, cinza-cinza, quase preto, prata, cinza-pardo)
const WOLF_COATS := [Color(0.56, 0.56, 0.6), Color(0.68, 0.67, 0.66), Color(0.36, 0.36, 0.4), Color(0.82, 0.83, 0.86), Color(0.6, 0.57, 0.53)]
## Modelo e pelagens por tipo de montaria (SimEntity.mount_kind, Balance.MOUNT_KINDS)
const MOUNT_LOOKS := {"horse": ["mob_horse", HORSE_COATS], "dire_wolf": ["mob_dire_wolf_mount", WOLF_COATS],
	# Chefes de Mundo (mvp-premios.md; modelo/cor/armadura de verdade em MountLook, que cai no cavalo sem o GLB)
	"war_boar": ["mob_mount_war_boar", []], "forest_elk": ["mob_mount_forest_elk", []], "ruins_lizard": ["mob_mount_ruins_lizard", []],
	"armored_rhino": ["mob_mount_armored_rhino", []], "iron_wolf": ["mob_mount_iron_wolf", []], "porcelain_stag": ["mob_mount_porcelain_stag", []]}
const FORM_SCALE := {"wolf": 1.15, "bear": 1.4, "demon": 1.3, "lich": 1.2,     # o bicho do druida é maior que o lobo comum
	"ent": 1.2, "alpha": 1.4, "bird": 1.3}                         # formas ancestrais (ascensão do Druida)
var _fly := 0.0                      # Pássaro Arcano: altura do voo no desenho (a sim é plana)
var _shown_form := ""
var _shown_def: MonsterDef = null   # metamorfose de monstro (ShiftSystem): o MonsterDef do modelo mostrado
var _stealth_shown := false
var _alpha_shown := 0.0              # transparência aplicada (furtivo 0.7, forma fantasma 0.45)
var _last_flash := 0.0
var _last_tint := Color(0, 0, 0, 0)       # cor do hit flash já enviada ao toon (alfa 0 = nenhuma; HitTint)
var _was_hit := false                   # hit flash do quadro anterior (o tranco do monstro não depende da escala do clarão)
var _flinch := 0.0
var _hit_flinch: HitFlinch = null   # golpe forte em personagem: tronco inclina por cima do clipe (HitReact)
var _root_fx: Node3D = null           # raízes nos pés (preso; CcLook.roots)
var _drag_fx: CPUParticles3D = null   # poeira fria nos pés (lento sem gelo; CcLook.drag)
var _stop_left := 0.0                # hit-stop local (WeaponArcs): s com a animação parada
var _push := Vector3.ZERO            # empurrão de desenho do golpe (WeaponArcs); a sim não se mexe
var _push_t := 1.0
const PUSH_IN := 0.035               # s até o empurrão chegar no máximo
const PUSH_OUT := 0.16               # s para voltar
var _gather_shown := ""                  # forma do ponto que está colhendo (mostrado no boneco)                       # monstro apanhou: encolhe no clipe "hit" por um instante
var _fade_meshes: Array = []             # corpo some: malhas guardadas na hora da morte
var _last_status := Color(0, 0, 0, 0)
var _stun_fx: Node3D = null           # estrelas girando na cabeça
var _burn_fx: CPUParticles3D = null   # brasas subindo
var _chill_fx: MeshInstance3D = null  # anel de gelo nos pés (retardado/preso)
var _poison_fx: CPUParticles3D = null # bolhas verdes subindo (veneno)
var _curse_fx: CPUParticles3D = null  # fiapos roxos sobre a cabeça (maldição/definhar)
var falcon_view: FalconView = null    # falcão do Caçador ascendido voando sobre o boneco (SimEntity.falcon)
var _prey_fx: Node3D = null           # Presa do falcão: mira âmbar girando sobre a cabeça
var _amp_fx: Node3D = null            # Toxina Real / Eclipse (debuff dot_amp): garras verdes girando ao contrário, maiores
var buff_aura: BuffAura = null        # buffs ativos no boneco (criado no primeiro buff)
var _rim_shown := Color(0, 0, 0, 0)
var _rim_style_shown := 0
var nameplate: Label3D
var quest_mark: Label3D = null       # NPC: "!" quest nova, "?" entregar
var service_icon: Sprite3D = null    # NPC de serviço (NpcServices): ícone sobre a cabeça; some quando há "!"/"?"
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
## Teleporte (2026-11-23): a sim move o corpo de uma vez (dash); estas somem e reaparecem em vez do arco de pulo.
## Estilo = forma do efeito em TeleportFx (shadow / arcane / lightning).
const TELEPORTS := {"ass_shadowstep": "shadow", "ele_blink": "arcane", "ele_bolt_step": "lightning", "mob_shazka_step": "shadow"}
const ARC_MIN_JUMP := 2.5             # m: salto de posição durante a skill que vira arco de desenho
const TP_VANISH_MIN := 0.05           # s: o sumiço dura pelo menos isto (Piscar tem 0,02 de preparo)
const TP_APPEAR := 0.16               # s: reaparecer no destino
const TP_GLOW := 0.5                  # brilho do corpo no reaparecer (× AccessSettings.flash)
var _tp_t := 1.0
var _tp_style := ""
var _tp_on := false
var _last_state := -1
var _is_player := false
var _base_scale := 1.0
var _ult_scale := 1.0              # boneco maior por buff de Suprema (Avatar da Fé, Colosso Primevo): escala do nó inteiro

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
	_shown_def = e.monster_def
	_build_model()
	if e.monster_def and e.monster_def.decoy:
		_decoy_look()
	_build_ui()
	if e.monster_def and e.monster_def.elite_of != "":
		_add_crown()
	if e.elem_stage > 0 and e.monster_def:           # elemental que evoluiu (Maior/Ancestral): brilho na pele do tema (o tamanho vem de e.scale)
		var gc: Color = e.monster_def.color.lightened(0.25)
		set_buff_rim(Color(gc.r, gc.g, gc.b, 0.45 * e.elem_stage), 3)

# ---------------------------------------------------------------------------
var _perch := 0.0                  # altura do boneco no alto da torre (npc_data.perch); a sim fica no chão

func _build_model() -> void:
	model_root = Node3D.new()
	model_root.name = "Model"
	if entity.kind == SimEntity.Kind.NPC and float(entity.npc_data.get("perch", 0.0)) > 0.0:
		_perch = float(entity.npc_data["perch"])                         # besteiro no alto da torre
		model_root.position.y = _perch
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
		_attach_carry()
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
			for a in ["idle", "run", "block", "block_shield", "guard_wall"]:
				if anim.has_animation(a):
					anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		_apply_toon_recursive(inst)
		_find_stance_weapons(inst)
		if RigidMerge.merge(inst, model_name) == null and (entity.kind != SimEntity.Kind.NPC or entity.guard):  # peças rígidas -> 1 malha (draw calls); guarnição da Aurora também
			RigidMerge.merge_skinned(inst, model_name)     # humanoide do kit (elfos, bandidos): peças com pele -> 1 malha por material
		_model_top = model_top(inst, model_name, model_root)
		model_root.scale = Vector3.ONE * _base_scale
		return
	_build_placeholder()

## Topo do modelo .glb (m, sem a escala da entidade): o nome e a barra sobem acima dele (Ulgra, chefes altos). 0 = kit/placeholder.
var _model_top := 0.0
## Folga entre o topo do modelo e a barra de vida (m, já na escala do mundo).
const PLATE_MARGIN := 0.15
static var _model_tops: Dictionary = {}      # model id -> topo na pose de descanso (as malhas não mudam por instância)

## Topo (y máximo) das malhas visíveis de `inst` no espaço de `stop`, na pose de descanso: peças presas a osso
## (BoneAttachment3D) usam o descanso do osso; a malha fundida (RigidMerge) já está no espaço do esqueleto. Cache por modelo.
static func model_top(inst: Node3D, model_name: String, stop: Node) -> float:
	if _model_tops.has(model_name):
		return _model_tops[model_name]
	var top := 0.0
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var p: Node = mi
		var shown := true
		while p != null and p != stop:
			if p is Node3D and not (p as Node3D).visible:
				shown = false
				break
			if p is BoneAttachment3D and p.get_parent() is Skeleton3D:
				var sk := p.get_parent() as Skeleton3D
				var bone := sk.find_bone((p as BoneAttachment3D).bone_name)
				if bone >= 0:
					xf = sk.get_bone_global_rest(bone) * xf
					p = sk
					continue
			if p is Node3D:
				xf = (p as Node3D).transform * xf
			p = p.get_parent()
		if shown:
			top = maxf(top, (xf * mi.mesh.get_aabb()).end.y)
	_model_tops[model_name] = top
	return top

## Altura da barra de vida (base do nome): o valor de sempre (1,95 × escala; 1,4 nas formas baixas) é o mínimo,
## e um modelo mais alto empurra para o topo dele + folga. Personagens (kit) ficam como estavam.
static func plate_top(base_scale: float, low_shape: bool, top_of_model: float) -> float:
	var top := (1.4 if low_shape else 1.95) * base_scale
	if top_of_model > 0.0:
		top = maxf(top, top_of_model * base_scale + PLATE_MARGIN)
	return top

## Cópia do Shazka (Sombras Gêmeas, R-F): clone de sombra de propósito, não falha de desenho: pele puxada para roxo
## escuro (uniform `status` do toon, que fica de base quando não há estado), borda roxa (buff_rim estilo 0),
## sólida (com transparência virava silhueta preta) e sem sombra projetada; a fumaça embaixo vem da BossSigView. O verdadeiro é o único com sombra no chão.
# cópia do Shazka: cor, borda, mistura e brilho em Balance.SHAZKA_DECOY_*
var _decoy := false

## Cor de estado da cópia: roxo médio (TINT + borda), força do TINT.
static func decoy_status() -> Color:
	var c: Color = Balance.SHAZKA_DECOY_TINT.lerp(Balance.SHAZKA_DECOY_RIM, Balance.SHAZKA_DECOY_RIM_MIX)
	return Color(c.r, c.g, c.b, Balance.SHAZKA_DECOY_TINT.a)

func _decoy_look() -> void:
	_decoy = true
	_last_status = Color(-1, -1, -1, -1)                 # o laço de estados aplica SHAZKA_DECOY_TINT no próximo quadro
	for n in model_root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF      # sólida: com `transparency` o toon ia para a passada
		# transparente e a cópia virava silhueta preta; quem diz "cópia" é a pele roxa
	set_buff_rim(Balance.SHAZKA_DECOY_RIM, 0)
	for m in (_mats if not _mats.is_empty() else ([mat] if mat else [])):
		(m as ShaderMaterial).set_shader_parameter("emission_amount", maxf(Balance.SHAZKA_DECOY_GLOW, float((m as ShaderMaterial).get_shader_parameter("emission_amount"))))

## Vida dos mapas: NPC com `carry` (MapsCatalog.LIVING_NPCS) leva a carga no ombro ou puxa a carroça. O prop tem tamanho
## real e segue o boneco; CarryPose segura os braços. Só apresentação.
var carry_node: Node3D = null
var draft: FormModel = null              # animal de tiro da carroça (CarryPose.DRAFT): anda entre os varais, ao lado do boneco
var _draft_walk := 1.0                   # m/s que o clipe "walk" do animal cobre a 1x
var _cart: Node3D = null                 # nó `cart` do prop: a carroça atrás do animal (atrasa na curva)
var _wheels: Node3D = null               # nó `wheels` do prop: rodas e eixo (giram pela distância andada)
var _wheel_r := 0.5
var _cart_lag := 0.0                     # peso por segundo do atraso da carroça (0 = presa ao rumo do boneco)
var _cart_lag_max := 0.0                 # teto do ângulo entre a carroça e o animal (rad)
var _cart_yaw := 0.0                     # rumo da carroça no mundo (rad)

func _attach_carry() -> void:
	if entity.kind != SimEntity.Kind.NPC or kit == null or kit.skeleton == null:
		return
	var what := str(entity.npc_data.get("carry", ""))
	if what == "" or not ResourceLoader.exists(CarryPose.model_path(what)):
		return
	carry_node = (load(CarryPose.model_path(what)) as PackedScene).instantiate()
	carry_node.name = "Carry"
	carry_node.position = CarryPose.lift_of(what)
	model_root.add_child(carry_node)
	_apply_toon_recursive(carry_node)
	# rodas (nó `wheels`: direto no prop da carroça de mão, dentro de `cart` na de tiro) giram pela distância andada
	_wheels = carry_node.find_child("wheels", true, false) as Node3D
	_wheel_r = CarryPose.wheel_r_of(what)
	_attach_draft(CarryPose.draft_of(what))
	var pose := CarryPose.new()
	pose.setup(kit.skeleton, what)
	kit.skeleton.add_child(pose)

## Carroça de tiro: o cavalo nasce como o da montaria (FormModel + RigidMerge: 1 malha, geometria dividida com as montarias)
## e fica preso ao boneco junto com a carroça; o passo dele segue a velocidade do boneco (_animate_draft).
func _attach_draft(d: Dictionary) -> void:
	if d.is_empty():
		return
	draft = FormModel.create_from("res://assets/models/%s.glb" % d["model"])
	if draft == null:
		return
	draft.name = "Draft"
	draft.position = d["at"]
	draft.scale = Vector3.ONE * float(d["scale"])
	_draft_walk = float(d["walk"])
	draft.paint(HORSE_COATS[entity.id % HORSE_COATS.size()])
	# animal de tiro não leva sela: as peças saem antes da fusão (chave própria: a malha da montaria não é a mesma)
	for pat: String in d.get("strip", []):
		for n in draft.find_children(pat, "MeshInstance3D", true, false):
			n.get_parent().remove_child(n)
			n.free()
	RigidMerge.merge(draft, "%s#draft" % d["model"])
	model_root.add_child(draft)
	_cart = carry_node.get_node_or_null("cart") as Node3D
	_cart_lag = float(d.get("lag", 0.0))
	_cart_lag_max = deg_to_rad(float(d.get("lag_max", 0.0)))
	_cart_yaw = model_root.rotation.y

## Rodas da carroça (de mão ou de tiro): rolam para a frente (+Z) o ângulo da distância andada no quadro.
func _animate_wheels(delta: float) -> void:
	var v := entity.velocity.length()
	if v > 0.05:
		_wheels.rotation.x = wrapf(_wheels.rotation.x + v * delta / _wheel_r, -PI, PI)

func _animate_draft(delta: float = 0.0) -> void:
	var v := entity.velocity.length()
	if _cart and _cart_lag > 0.0 and delta > 0.0:
		# a carroça segue o rumo do animal com atraso (e nunca dobra mais que `lag_max` em relação a ele)
		var yaw := model_root.rotation.y
		_cart_yaw = lerp_angle(_cart_yaw, yaw, minf(1.0, delta * _cart_lag))
		var off := clampf(angle_difference(yaw, _cart_yaw), -_cart_lag_max, _cart_lag_max)
		_cart_yaw = yaw + off
		_cart.rotation.y = off
	if draft.anim == null:
		return
	var clip := "walk" if v > 0.2 else "idle"
	if draft.anim.has_animation(clip) and draft.anim.current_animation != clip:
		draft.anim.play(clip, 0.25)
	draft.anim.speed_scale = clampf(v / _draft_walk, 0.8, 2.4) if v > 0.2 else 1.0

## Armas de troca (MonsterDef.swap): "wpn_alt_*" só aparece na troca; a principal e a das costas somem nela.
var _stance_main: Array = []
var _stance_alt: Array = []
var _stance_seen := ""

func _find_stance_weapons(inst: Node) -> void:
	for n in inst.find_children("wpn_*", "Node3D", true, false):
		var nm := String(n.name)
		if nm.begins_with("wpn_alt_"):
			_stance_alt.append(n)
			(n as Node3D).visible = false
		elif nm.begins_with("wpn_main_") or nm.begins_with("wpn_back_"):
			_stance_main.append(n)

func _apply_stance() -> void:
	_stance_seen = entity.stance
	var alt := _stance_seen != ""
	for n in _stance_alt:
		if is_instance_valid(n):
			n.visible = alt
	for n in _stance_main:
		if is_instance_valid(n):
			n.visible = not alt

func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r:
			return r
	return null

## Reflexo Vaidoso (GDD ato3-excesso-45-50: "mostra a silhueta de quem olha"): a silhueta do vidro pega o tom do alvo
## atual (só lê a sim). Sem alvo, ou alvo que sumiu: o azul-cinza do modelo.
func update_shade() -> void:
	if shade_mat == null:
		return
	_shade_seen = entity.aggro_target
	var t: SimEntity = Sim.get_entity(entity.aggro_target) if entity.aggro_target >= 0 else null
	shade_mat.set_shader_parameter("albedo", reflection_tone(t) if t != null else _shade_idle)

## Cor de quem olha: a da classe (as armaduras de tier têm todas a mesma cor de ícone, não distinguem); sem classe
## (guarda, NPC com equipamento), a armadura do peito; monstro/NPC pela cor própria.
static func reflection_source(t: SimEntity) -> Color:
	if t.class_def != null:
		return t.class_def.color
	var body: ItemDef = t.equipment.get(ItemDef.Slot.BODY)
	if body != null:
		return body.icon_color
	if t.monster_def != null:
		return t.monster_def.color
	return Color(t.npc_data.get("color", REFLECTION_IDLE))

## Tom da silhueta: a cor de quem olha puxada para o vidro e escurecida (lê como reflexo, não como pintura).
const REFLECTION_IDLE := Color(0.42, 0.46, 0.55)     # só se o alvo não tiver cor nenhuma
const REFLECTION_GLASS := Color(0.45, 0.5, 0.6)      # azul do vidro misturado no tom
const REFLECTION_GLASS_MIX := 0.3
const REFLECTION_DARKEN := 0.35

static func reflection_tone(t: SimEntity) -> Color:
	var c := reflection_source(t).lerp(REFLECTION_GLASS, REFLECTION_GLASS_MIX).darkened(REFLECTION_DARKEN)
	c.a = 1.0
	return c

## Monstro que usa o modelo de outro (Slime Azul em mob_slime, Presa-Rachada em mob_boar): o corpo puxa para a cor dele,
## medida contra a cor do monstro dono do modelo; olhos, brilho e chifre/presa não mudam. O dono do modelo fica como está.
const FIXED_MATS := ["m_eye", "m_white", "m_horn"]

## Humanoide do kit (bandido, elfos): só a roupa muda de cor; pele, cabelo, orelha, metal, couro e madeira ficam.
const KIT_FIXED := ["m_leather", "m_metal", "m_wood", "m_string", "belt", "trim"]

static func monster_tint(mdef: MonsterDef, col: Color, mat_name: String) -> Color:
	if mdef == null or mdef.model == "" or mat_name in FIXED_MATS or mat_name in KIT_FIXED:
		return col
	if mat_name.begins_with("m_hair_") or (mat_name.begins_with("m_mob_") and not mat_name.ends_with("_cloth")):
		return col
	var base: MonsterDef = GameData.monsters.get(mdef.model.trim_prefix("mob_"))
	if base == null or base == mdef or base.color.is_equal_approx(mdef.color):
		return col
	var v := clampf(col.v * (mdef.color.v / maxf(0.05, base.color.v)), 0.0, 1.0)
	return Color.from_hsv(mdef.color.h, lerpf(col.s, mdef.color.s, 0.75), v, col.a)

## Brilho de peça de modelo (.glb): material com emissão de verdade (energia > GLOW_MIN_ENERGY, cor não preta) ou nome `glow_*`.
## O m_white e os corpos de elemental exportam emissão 1,0 só para clarear: ficam de fora. Devolve o emission_amount do toon
## (0 = sem brilho), em degraus de GLOW_STEP para peças parecidas dividirem a superfície na fusão (RigidMerge.mat_key).
const GLOW_MIN_ENERGY := 1.05
const GLOW_SCALE := 0.6         # energia do Blender (2,2-3,0) -> emission_amount do toon (1,25-1,75; o bloom começa em 1,0)
const GLOW_MAX := 1.75
const GLOW_STEP := 0.25
const GLOW_NAMED := 1.5         # `glow_*` sem emissão: como os props do mapa (Materials.glow 1,5)

static func mob_glow(base: Material) -> float:
	if not (base is BaseMaterial3D):
		return 0.0
	var bm := base as BaseMaterial3D
	var e := 0.0
	if bm.emission_enabled and bm.emission_energy_multiplier > GLOW_MIN_ENERGY and bm.emission.get_luminance() > 0.02:
		e = bm.emission_energy_multiplier * GLOW_SCALE
	elif bm.resource_name.begins_with("glow_"):
		e = GLOW_NAMED
	if e <= 0.0:
		return 0.0
	return clampf(snappedf(e, GLOW_STEP), GLOW_STEP, GLOW_MAX)

## Cor da peça que brilha: a da emissão (ou do albedo) de volta ao tom do Blender, como o MapBuilder faz com `glow_*`.
static func glow_color(base: Material) -> Color:
	var bm := base as BaseMaterial3D
	var c := bm.emission if bm.emission_enabled and bm.emission.get_luminance() > 0.02 else bm.albedo_color
	return c.srgb_to_linear()

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
			elif entity and entity.kind == SimEntity.Kind.NPC and base and base.resource_name.ends_with("_cloth"):
				col = Color(entity.npc_data.get("color", col))       # cidadão de modelo próprio: roupa na cor dele
			var war_tint := GvgUi.model_tint(entity, base.resource_name if base else "") if entity else Color(0, 0, 0, 0)
			if war_tint.a > 0.0:
				col = war_tint              # Guerra de Guildas: aríete/cristal/canhão na cor da guilda do lado
			var glow := mob_glow(base)
			if glow > 0.0:
				col = glow_color(base)      # brasa/runa/olho: o tom do Blender (o import clareia), sem tingir pela variante
			var tm := Materials.toon_unique(col)
			if RigidMerge.is_shade(base):
				tm.resource_name = base.resource_name     # a fusão separa a superfície pelo nome (RigidMerge.mat_key)
				shade_mat = tm
				_shade_idle = col
				_shade_seen = -2
			if glow > 0.0:
				tm.set_shader_parameter("emission_amount", glow)
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
		"turret":  # torreta de campo do Atirador: tripé, tambor e cano
			for i in range(3):
				var a := TAU * float(i) / 3.0
				var leg := _mesh(_box(0.08, 0.75, 0.08), color.darkened(0.35))
				leg.position = Vector3(sin(a) * 0.32, 0.3, cos(a) * 0.32)
				leg.rotation = Vector3(cos(a) * 0.45, 0.0, -sin(a) * 0.45)
				model_root.add_child(leg)
			var drum := CylinderMesh.new(); drum.top_radius = 0.26; drum.bottom_radius = 0.3; drum.height = 0.36; drum.radial_segments = 10
			var d := _mesh(drum, color, true); d.position.y = 0.78; model_root.add_child(d)
			var cap := SphereMesh.new(); cap.radius = 0.22; cap.height = 0.3; cap.radial_segments = 8; cap.rings = 4
			var c := _mesh(cap, color.lightened(0.2)); c.position.y = 0.98; model_root.add_child(c)
			var barrel := _mesh(_box(0.1, 0.1, 0.85), Color(0.3, 0.3, 0.34)); barrel.position = Vector3(0, 0.86, 0.45); model_root.add_child(barrel)
			var muzzle := MeshInstance3D.new(); muzzle.mesh = SphereMesh.new(); (muzzle.mesh as SphereMesh).radius = 0.07; (muzzle.mesh as SphereMesh).height = 0.14
			muzzle.material_override = Materials.glow(Color(1.0, 0.7, 0.3), 1.5); muzzle.position = Vector3(0, 0.86, 0.9); model_root.add_child(muzzle)
		"angel":  # Anjo Guardião do Bispo (Coro Celeste): túnica de luz, auréola e asas, pairando no ar
			var lift := Node3D.new(); lift.name = "AngelLift"; lift.position.y = Balance.ANGEL_HOVER - 0.9; model_root.add_child(lift)
			var light := Materials.glow(Color(color.r, color.g, color.b, 0.9), 1.1)
			var robe := CylinderMesh.new(); robe.top_radius = 0.16; robe.bottom_radius = 0.42; robe.height = 1.0; robe.radial_segments = 10
			var rb := MeshInstance3D.new(); rb.mesh = robe; rb.material_override = light; rb.position.y = 0.55; lift.add_child(rb)
			var head := SphereMesh.new(); head.radius = 0.24; head.height = 0.48; head.radial_segments = 10; head.rings = 5
			var hd := MeshInstance3D.new(); hd.mesh = head; hd.material_override = Materials.glow(Color(1.0, 0.97, 0.88, 0.95), 1.2); hd.position.y = 1.28; lift.add_child(hd)
			var halo := TorusMesh.new(); halo.inner_radius = 0.2; halo.outer_radius = 0.27; halo.rings = 16; halo.ring_segments = 5
			var hl := MeshInstance3D.new(); hl.mesh = halo; hl.material_override = Materials.glow(Color(1.0, 0.85, 0.35), 2.4); hl.position.y = 1.66; lift.add_child(hl)
			var wing_mat := Materials.glow(Color(1.0, 0.98, 0.9, 0.8), 1.4)
			for sx in [-1.0, 1.0]:
				var wing := Node3D.new(); wing.name = "Wing%s" % ("L" if sx < 0.0 else "R"); wing.position = Vector3(sx * 0.14, 1.0, -0.16); lift.add_child(wing)
				for k in range(3):          # três penas grandes em leque
					var fe := MeshInstance3D.new(); fe.mesh = _box(0.9 - 0.2 * k, 0.26, 0.04); fe.material_override = wing_mat
					fe.position = Vector3(sx * (0.5 - 0.08 * k), 0.12 - 0.26 * k, 0.0)
					fe.rotation.z = sx * (0.5 - 0.28 * k)
					wing.add_child(fe)
			var glow := OmniLight3D.new(); glow.light_color = Color(1.0, 0.9, 0.6); glow.light_energy = 0.8; glow.omni_range = 3.5; glow.position.y = 1.0; lift.add_child(glow)
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
	var top := plate_top(_base_scale, entity.monster_def != null and entity.monster_def.shape in ["sphere", "box"], _model_top)
	if entity.spirit:
		top += Balance.ANGEL_HOVER - 0.9          # o anjo paira: o nome sobe junto
	nameplate = Label3D.new()
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.no_depth_test = true
	nameplate.font_size = NAME_FONT
	nameplate.pixel_size = name_px
	nameplate.outline_size = 14
	nameplate.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM    # cresce para cima: 2 linhas não descem na barra
	nameplate.position.y = top + 0.32
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
		var tex := NpcServices.icon(NpcServices.service_of(entity.npc_data))
		if tex != null:
			service_icon = Sprite3D.new()
			service_icon.texture = tex
			service_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			service_icon.no_depth_test = true
			service_icon.render_priority = 1
			service_icon.pixel_size = NpcServices.HEAD_SIZE / float(tex.get_width())
			service_icon.position.y = top + NpcServices.HEAD_LIFT
			add_child(service_icon)

	if entity.kind != SimEntity.Kind.NPC or entity.guard:       # sentinela que luta mostra a vida
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
		shield_fill = _quad(1.0, 0.07, Color(0.8, 0.93, 1.0, 0.92), 2)     # barreira: azul-clara depois da vida (ShieldOverlay.span_of)
		shield_fill.position = Vector3(0, 0, 0.002)
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

## "Mestre Paladino · " quando o personagem tem título de honra (SimEntity.honor_title).
func _honor_prefix() -> String:
	var t := entity.honor_title()
	return (t + " · ") if t != "" else ""

## Tamanho do nome na tela (R2 #21): pixel_size acompanha a distância da câmera (main._sync_name_size), então o nome
## fica com ~15 px de 20 a 34 m (zoom máximo, chefes) e cresce pouco no zoom mais perto (14 m: ~19 px).
const NAME_FONT := 52
const NAME_PX := 0.004              # pixel_size na câmera padrão (24 m)
const NAME_REF_DIST := 24.0
const NAME_SCALE_MIN := 0.75
const NAME_SCALE_MAX := 1.45
static var name_px := NAME_PX

## pixel_size do nome para a câmera a `cam_dist` m.
static func name_pixel_size(cam_dist: float) -> float:
	return NAME_PX * clampf(cam_dist / NAME_REF_DIST, NAME_SCALE_MIN, NAME_SCALE_MAX)

func apply_name_size() -> void:
	if nameplate:
		nameplate.pixel_size = name_px

## Nome por baixo da HUD (barra, quadro, chat, quests: main._hide_labels_under_hud, R2 #16) some até sair de lá.
var hud_hidden := false
func set_hud_hidden(h: bool) -> void:
	if h == hud_hidden or nameplate == null:
		return
	hud_hidden = h
	nameplate.visible = not h and not crowd_hidden and not dev_name_hidden

## Matilha densa (NameplateCrowd): esconde só o nome, a barra fica. Só escreve na troca (fotos de revisão escondem nomes por conta própria).
var crowd_hidden := false
func set_crowd_hidden(h: bool) -> void:
	if h == crowd_hidden or nameplate == null:
		return
	crowd_hidden = h
	nameplate.visible = not h and not dev_name_hidden and not hud_hidden

## Foto de revisão (dev_runner) escondeu o nome: a passada da matilha não o mostra de volta (revisão m8). Só dev.
var dev_name_hidden := false
func hide_name_dev() -> void:
	dev_name_hidden = true
	if nameplate:
		nameplate.visible = false

func _refresh_nameplate() -> void:
	var txt := entity.name
	var col := Color.WHITE
	match entity.kind:
		SimEntity.Kind.PLAYER:
			col = Color(1, 0.95, 0.6)
			txt = "%s\n%s" % [GuildUi.plate_for(entity), _honor_prefix() + entity.display_title()]
		SimEntity.Kind.BOT:
			col = Color(0.55, 1.0, 0.6) if _is_party_mate() else Color(0.75, 0.9, 1.0)
			txt = "%s\n%s" % [GuildUi.plate_for(entity), _honor_prefix() + entity.display_title()]
		SimEntity.Kind.MONSTER:
			col = level_color(entity.level, Sim.player.level if Sim.player else entity.level) if not entity.monster_def.is_boss else Color(1, 0.8, 0.3)
			txt = "%s %s" % [entity.name, entity.display_title()]
		SimEntity.Kind.NPC:
			col = NpcServices.NAME_COLOR if NpcServices.service_of(entity.npc_data) != "" else Color(0.7, 1.0, 0.75)
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
		"crystal": return "Cristal"
		"trainer": return "Mestre de Skills"
		"merchant": return "Mercador"
		"storage": return "Depósito"
		"relic": return "Relicária"
		"board": return "Quadro"
		"hunt": return "Intendente das Caçadas"
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
	var mkey := _mount_key()
	if _horse_kept != null and _horse_kind != mkey:      # trocou de bicho/cor/armadura: o guardado sai
		_horse_kept.queue_free()
		_horse_kept = null
	if _horse_kept == null:
		var forced := DevArgs.value("--mount_model", "")      # revisão: --mount_model=<modelo> força outro bicho
		_horse_kept = FormModel.create_from(MountLook.path_of(forced)) if forced != "" else MountLook.create(entity.mount_kind, entity.mount_dye, entity.mount_barding, entity.id)
		if _horse_kept == null:
			return
		_horse_kind = mkey
		_horse_kept.scale = Vector3.ONE * HORSE_SCALE / maxf(_base_scale, 0.01)
		# o bicho já olha para +Z (frente do boneco); cor e armadura: MountLook (mount_dye -1 = pelagem pelo id, bots)
		if forced != "":
			_horse_kept.paint(MountLook.coat(entity.mount_kind, entity.mount_dye, entity.id))
		RigidMerge.merge(_horse_kept, forced if forced != "" else MountLook.merge_key(entity.mount_kind, entity.mount_barding))
		model_root.add_child(_horse_kept)
	horse = _horse_kept
	horse.visible = true
	horse.process_mode = Node.PROCESS_MODE_INHERIT
	kit.position.y = SADDLE_Y / maxf(_base_scale, 0.01)
	RidePose.ensure_clip(kit.anim, kit.skeleton)
	RidePose.ensure_guard_clip(kit.anim, kit.skeleton)
	if _ride_legs == null and kit.skeleton:
		_ride_legs = RideLegs.new()
		_ride_legs.setup(kit.skeleton)
		kit.skeleton.add_child(_ride_legs)      # depois do LegOverlay: a sela vence a corrida

## Tipo + cor + armadura da montaria (troca = refaz o bicho guardado).
func _mount_key() -> String:
	return "%s|%d|%s" % [entity.mount_kind, entity.mount_dye, entity.mount_barding]

## O boneco acompanha o lombo do cavalo (sobe/desce e balança no galope).
func _ride_saddle() -> void:
	var base := Transform3D(Basis.IDENTITY, Vector3(0, SADDLE_Y / maxf(_base_scale, 0.01), 0))
	kit.global_transform = horse.bone_delta("body") * model_root.global_transform * base
	kit.scale = Vector3.ONE

## Druida: entra/sai da forma de animal (esconde o kit e anima o bicho, com a armadura de animal do conjunto).
## Transformação: o boneco encolhe, estoura um pouco maior e assenta (o modelo troca no meio do aperto, escondido
## pelo clarão); o fantasma se materializa (appear 0 -> 1). O estouro de partículas é do FxManager (form_*).
const MORPH_TIME := 0.45
var _morph_t := 1.0
var _ghost_on := false
var _ghost_mats: Dictionary = {}              # material toon da peça -> material fantasma com a cor dela

func _morph(delta: float) -> void:
	if _morph_t >= 1.0 or anim == null:
		return
	_morph_t = minf(1.0, _morph_t + delta / MORPH_TIME)
	var t := _morph_t
	# aperto (0-0,25), estouro (0,25-0,55), assenta com uma oscilação pequena
	var k: float
	if t < 0.25:
		k = lerpf(1.0, 0.72, t / 0.25)
	elif t < 0.55:
		k = lerpf(0.72, 1.14, ease((t - 0.25) / 0.3, 0.5))
	else:
		var u := (t - 0.55) / 0.45
		k = 1.0 + 0.14 * cos(u * PI * 1.5) * (1.0 - u)
	var wide := 1.0 + (1.0 - k) * 0.5                  # espreme na altura, abre na largura (e vice-versa)
	model_root.scale = Vector3(wide, k, wide) * _base_scale
	var glow := clampf(1.0 - absf(t - 0.25) / 0.25, 0.0, 1.0)
	for m in _mats:
		m.set_shader_parameter("flash", maxf(glow * 0.55, 1.0 if entity.hit_flash > 0.0 else 0.0) * AccessSettings.flash)
		m.set_shader_parameter("flash_full", 1.0)      # o brilho do aparecer é do corpo todo
		m.set_shader_parameter("flash_color", Color.WHITE)
		_last_tint = Color(0, 0, 0, 0)
	if _ghost_on:
		_ghost_set("appear", smoothstep(0.2, 0.75, t))
		_ghost_set("flash", glow * 0.6 * AccessSettings.flash)
	if _morph_t >= 1.0:
		model_root.scale = Vector3.ONE * _base_scale
		_last_flash = -1.0                            # o hit flash volta a mandar no próximo quadro

## Corpo no teleporte: vira fenda no preparo, reaparece no destino passando um pouco do tamanho e piscando na cor do
## estilo (TeleportFx faz o efeito em volta). Mesmo jeito do _morph: escala do model_root e flash do toon.
func _teleport_body(delta: float) -> void:
	var s := entity.current_skill
	var k := 0.0
	var glow := 0.0
	if entity.state == SimEntity.State.CASTING and not entity.skill_applied and teleport_style(s) != "":
		k = clampf(entity.state_time / maxf(s.startup, TP_VANISH_MIN), 0.0, 1.0)
		_tp_style = teleport_style(s)
		glow = k
	elif _tp_t < 1.0:
		_tp_t = minf(1.0, _tp_t + delta / TP_APPEAR)
		k = (1.0 - _tp_t) * (1.0 - _tp_t) - 0.1 * sin(_tp_t * PI) * _tp_t
		glow = 1.0 - _tp_t
	if k == 0.0 and glow <= 0.0:
		if _tp_on:
			_tp_on = false
			model_root.scale = Vector3.ONE * _base_scale
			_last_flash = -1.0                        # o hit flash volta a mandar no próximo quadro
		return
	_tp_on = true
	model_root.scale = teleport_shape(k) * _base_scale
	var c := SkillFx.ring(TeleportFx.theme_of(_tp_style))
	for m in _mats:
		m.set_shader_parameter("flash", glow * TP_GLOW * AccessSettings.flash)
		m.set_shader_parameter("flash_full", 1.0)
		m.set_shader_parameter("flash_color", c)
	_last_tint = Color(0, 0, 0, 0)

## Hit flash por tipo de dano (D5): borda na cor do dano; corpo todo branco só no crítico. Reenvia só quando a cor muda.
func _apply_flash_look(hit: bool) -> void:
	if not hit:
		_last_tint = Color(0, 0, 0, 0)
		return
	if _mats.is_empty():
		return
	HitTint.ensure()
	var crit := HitTint.crit_of(entity.id)
	var c: Color = HitTint.CRIT_COLOR if crit else HitTint.color_of(entity.id)
	if c == _last_tint:
		return
	_last_tint = c
	var full := 1.0 if crit else 0.0
	for m in _mats:
		m.set_shader_parameter("flash_color", c)
		m.set_shader_parameter("flash_full", full)

func _ghost_set(param: String, v: float) -> void:
	for gm in _ghost_mats.values():
		(gm as ShaderMaterial).set_shader_parameter(param, v)

## Forma Fantasma: cada superfície do kit (menos o rastro da arma) troca para o ghost.gdshader com a cor dela
## (o toon fica guardado no meta "toon" da superfície); desligar devolve o toon.
const GHOST_SHADER := preload("res://shaders/ghost.gdshader")
const SHADE_TINT := Color(0.07, 0.04, 0.13)
const SHADE_RIM := Color(0.55, 0.3, 0.95)

func _set_ghost(on: bool) -> void:
	_ghost_on = on
	if kit == null:
		return
	var appear := 1.0 if _morph_t >= 1.0 else 0.0
	for node in kit.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.name == "WeaponTrail" or mi.mesh == null:
			continue
		for i in range(mi.mesh.get_surface_count()):
			var key := "toon_%d" % i
			if on:
				var cur := mi.get_surface_override_material(i)
				if cur and cur.get_meta("ghost", false):
					continue
				mi.set_meta(key, cur)
				mi.set_surface_override_material(i, _ghost_for(cur if cur else mi.mesh.surface_get_material(i), appear))
			elif mi.has_meta(key):
				mi.set_surface_override_material(i, mi.get_meta(key) as Material)
				mi.remove_meta(key)

func _ghost_for(toon: Material, appear: float) -> ShaderMaterial:
	if _ghost_mats.has(toon):
		return _ghost_mats[toon]
	var gm := ShaderMaterial.new()
	gm.shader = GHOST_SHADER
	gm.set_meta("ghost", true)
	var col := Color(0.8, 0.8, 0.8)
	if toon is ShaderMaterial and (toon as ShaderMaterial).get_shader_parameter("albedo") != null:
		col = (toon as ShaderMaterial).get_shader_parameter("albedo")
		gm.set_shader_parameter("vcol_srgb", (toon as ShaderMaterial).get_shader_parameter("vcol_srgb") == true)
	elif toon is BaseMaterial3D:
		col = (toon as BaseMaterial3D).albedo_color
	gm.set_shader_parameter("base", col)
	gm.set_shader_parameter("appear", appear)
	if entity.shade:              # clone de sombra (Assassino): o mesmo boneco, escuro e translúcido, borda violeta
		gm.set_shader_parameter("tint", SHADE_TINT)
		gm.set_shader_parameter("rim_color", SHADE_RIM)
		gm.set_shader_parameter("own_mix", 0.12)
		gm.set_shader_parameter("body_alpha", 0.62)
	_ghost_mats[toon] = gm
	return gm

## View criada tarde (fila de views, chegada no mapa): já nasce no estado da entidade, sem a transição que o
## _process_view tocaria (forma trocada na hora, sem metamorfose). Montaria, furtivo e buffs no corpo o _process_view lê sozinho.
## Exemplo: `v.setup(e, false); views_root.add_child(v); v.snap_visual_state()`
func snap_visual_state() -> void:
	if kit and entity.form != _shown_form:
		_swap_form()
		_morph_t = 1.0

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
		_reapply_mats()
		return
	form_view = FormModel.create(_shown_form)
	form_view.scale = Vector3.ONE * float(FORM_SCALE.get(_shown_form, 1.0))
	form_view.merge_parts("form_" + _shown_form)     # Lich/demônio: peças rígidas -> 1 malha
	model_root.add_child(form_view)
	form_view.apply_equipment(entity.equipment)
	kit.visible = false
	kit.trail_on = false
	anim = form_view.anim
	_mats = form_view.mats
	_stealth_shown = not (entity.stealth_left > 0.0)     # reaplica a transparência nas malhas novas
	_alpha_shown = -1.0
	_reapply_mats()

## Metamorfose de monstro (ShiftSystem): troca o modelo inteiro pelo do MonsterDef atual, com o aperto/estouro do _morph;
## nome e barras sobem para o topo do modelo novo. O estouro de folhas é do FxManager (Events.monster_shift).
func _swap_monster_model() -> void:
	_shown_def = entity.monster_def
	var rot := model_root.rotation.y
	remove_child(model_root)
	model_root.queue_free()
	anim = null
	mat = null
	_mats = []
	_stance_main.clear()
	_stance_alt.clear()
	_stance_seen = ""
	shade_mat = null
	_prey_fx = null
	_model_top = 0.0
	_act_skill = null
	_last_state = -1
	_base_scale = entity.scale
	_build_model()
	model_root.rotation.y = rot
	var top := plate_top(_base_scale, entity.monster_def.shape in ["sphere", "box"], _model_top)
	nameplate.position.y = top + 0.32
	if hp_bar:
		hp_bar.position.y = top + 0.2
		cast_bar.position.y = top + 0.08
	_stealth_shown = not (entity.stealth_left > 0.0)     # transparência nas malhas novas
	_alpha_shown = -1.0
	_last_flash = -1.0
	_morph_t = 0.0
	_reapply_mats()
	_refresh_nameplate()

## Gesto da conjuração da metamorfose (o 1º clipe de conjurar que o modelo tiver).
func shift_gesture() -> void:
	if anim == null:
		return
	for c in ["cast", "cast_nature", "roar", "attack"]:
		if anim.has_animation(c):
			anim.play(c, 0.12)
			return

## Materiais trocados (forma, peças novas): estado e borda de buff voltam a valer nos novos.
func _reapply_mats() -> void:
	_last_status = Color(-1, -1, -1, -1)
	if _rim_shown.a > 0.0:
		set_buff_rim(_rim_shown, _rim_style_shown)

func refresh_equipment() -> void:
	_alpha_shown = -1.0            # peças novas do kit entram na árvore agora: reaplica a transparência (furtivo)
	if kit:
		_ghost_on = not _ghost_on  # ... e o material de fantasma (o próximo quadro reaplica nas peças novas)
	if form_view:
		form_view.apply_equipment(entity.equipment)
	if kit:
		var bare := Color(entity.npc_data.get("color", Color(0.55, 0.42, 0.3))) if entity.kind == SimEntity.Kind.NPC else Color(0.55, 0.42, 0.3)
		kit.apply_equipment(entity.equipment, bare)
		_reapply_mats()
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
		if service_icon:
			service_icon.visible = nameplate.visible                     # nome escondido (HUD/matilha) leva o ícone junto
			service_icon.offset.x = -service_icon.texture.get_width() * NpcServices.BESIDE_MARK if mark != "" else 0.0     # com "!"/"?": ao lado
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
	if _stop_left > 0.0 and not manual_anim:     # hit-stop local: o mixer fica parado (o tempo parado não volta)
		_stop_left -= delta
		if anim.callback_mode_process != AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL:
			anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		_anim_acc = 0.0
		return
	if manual_anim:                  # sonda: quem chama _process_view anda a animação no passo dela
		anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		anim.advance(delta)
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

var _np_q := -1                      # missões concluídas (título de honra)
var _np_lv := -1                     # o que a placa de nome mostra (refaz o texto só quando muda)
var _np_ally := false
var _np_plv := -1
var _np_guild := -1                  # GuildUi.revision já mostrada (etiqueta de guilda / rival)

## Escala pedida pelos buffs da entidade (chave "scale" do buff; a maior vence; 1 = normal). Só desenho.
static func buff_scale(e: SimEntity) -> float:
	var k := 1.0
	for b in e.buffs:
		if b.has("scale"):
			k = maxf(k, float(b["scale"]))
	return k

## Cresce/encolhe até a escala dos buffs em ~Balance.ULT_SCALE_TIME s (Avatar da Fé x1,25, Colosso Primevo x1,5).
func _update_ult_scale(delta: float) -> void:
	var want := buff_scale(entity) if not entity.buffs.is_empty() else 1.0
	if is_equal_approx(want, _ult_scale):
		return
	_ult_scale = move_toward(_ult_scale, want, delta * maxf(0.25, absf(want - 1.0)) / Balance.ULT_SCALE_TIME)
	scale = Vector3.ONE * _ult_scale

func _process(delta: float) -> void:
	if entity == null:
		return
	var _t0 := Time.get_ticks_usec()
	_process_view(delta)
	prof_us += Time.get_ticks_usec() - _t0

## Anjo Guardião: paira subindo e descendo devagar e bate as asas (só desenho).
func _angel_hover() -> void:
	var lift := model_root.get_node_or_null("AngelLift") as Node3D
	if lift == null:
		return
	var t := Time.get_ticks_msec() * 0.001 + float(entity.id) * 0.7
	lift.position.y = Balance.ANGEL_HOVER - 0.9 + sin(t * 2.2) * 0.12
	for side in [["WingL", -1.0], ["WingR", 1.0]]:
		var w := lift.get_node_or_null(side[0]) as Node3D
		if w:
			w.rotation.y = float(side[1]) * (-0.3 + sin(t * 5.0) * 0.32)

## Presa (Falcoeiro): quatro garras âmbar apontando para dentro, girando sobre a cabeça do alvo marcado.
func _make_prey_mark() -> Node3D:
	var root := Node3D.new()
	root.position.y = _status_head() / maxf(_base_scale, 0.01) + 0.15
	var r := maxf(0.42, entity.radius * 0.8) / maxf(_base_scale, 0.01)
	var claw := PrismMesh.new(); claw.size = Vector3(0.16, 0.26, 0.05)
	for i in range(4):
		var a := TAU * float(i) / 4.0
		var mi := MeshInstance3D.new()
		mi.mesh = claw
		mi.material_override = Materials.glow(Color(1.0, 0.72, 0.2, 0.95), 1.6)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(sin(a) * r, 0.0, cos(a) * r)
		mi.rotation = Vector3(-PI * 0.5, a, 0.0)          # deitada, a ponta para o centro
		root.add_child(mi)
	model_root.add_child(root)
	return root

## Falcoeiro: o falcão aparece/some com SimEntity.falcon (só desenho; na sim ele é estado do dono).
func _swap_falcon() -> void:
	if entity.falcon:
		falcon_view = FalconView.new()
		add_child(falcon_view)
	else:
		falcon_view.queue_free()
		falcon_view = null

## Salto Dracônico: altura do desenho no ar (sobe rápido, some no alto, cai de uma vez). A sim é plana.
static func sky_lift(e: SimEntity) -> float:
	if e.sky_left <= 0.0 or e.current_skill == null or not e.current_skill.effects.has("dragon_jump"):
		return 0.0
	var s := e.current_skill
	var k := clampf((e.state_time - s.startup) / maxf(s.active, 0.01), 0.0, 1.0)
	return Balance.DRAGON_JUMP_HEIGHT * (1.0 - pow(2.0 * k - 1.0, 4.0))

## Estilo de teleporte da skill ("" = não é teleporte).
static func teleport_style(s: SkillDef) -> String:
	return str(TELEPORTS.get(s.id, "")) if s != null else ""

## Pura: o salto de `jump` m durante a skill vira arco de pulo? Teleporte nunca (some e reaparece).
static func draws_arc(s: SkillDef, jump: float) -> bool:
	return jump > ARC_MIN_JUMP and teleport_style(s) == ""

## Escala do corpo no teleporte: k 0 = inteiro, 1 = sumido (fenda fina e alta); k < 0 = passa um pouco do tamanho.
static func teleport_shape(k: float) -> Vector3:
	var w := lerpf(1.0, 0.08, k)
	return Vector3(w, lerpf(1.0, 1.3, k), w)

func _process_view(delta: float) -> void:
	_dt = delta
	_update_ult_scale(delta)
	if entity.stance != _stance_seen:
		_apply_stance()
	if quest_mark:
		_update_quest_mark(delta)
	# posição suavizada (a sim roda a 60Hz; interpola um pouco)
	# salto de skill (a sim move de uma vez): arco de desenho; teleporte some na origem e reaparece no destino, sem arco
	if entity.state == SimEntity.State.CASTING and _arc_t >= 1.0 and _smooth_pos.distance_to(entity.position) > ARC_MIN_JUMP:
		if draws_arc(entity.current_skill, _smooth_pos.distance_to(entity.position)):
			_arc_from = _smooth_pos
			_arc_t = 0.0
		else:
			_tp_style = teleport_style(entity.current_skill)
			TeleportFx.play(entity, _tp_style, _smooth_pos, entity.position)
			_smooth_pos = entity.position     # a câmera (CameraRig) segue suave até lá
			_tp_t = 0.0
	var lift := 0.0
	if _arc_t < 1.0:
		_arc_t = minf(1.0, _arc_t + delta / ARC_TIME)
		_smooth_pos = _arc_from.lerp(entity.position, _arc_t)
		lift = sin(_arc_t * PI) * minf(2.2, _arc_from.distance_to(entity.position) * 0.35)
	else:
		_smooth_pos = _smooth_pos.lerp(entity.position, minf(1.0, delta * 28.0))
	if _form_land != "" and _arc_t >= 1.0:
		WeaponArcs.form_hook(entity, _form_land, true)     # pousou (ou avanço curto, sem arco): o derrape das patas
		_form_land = ""
	lift += sky_lift(entity)
	_fly = lerpf(_fly, Balance.ANC_BIRD_LIFT if entity.form == "bird" and entity.is_alive() else 0.0, minf(1.0, delta * 5.0))
	lift += _fly                     # Pássaro Arcano voa por cima do chão (só desenho)
	position = _smooth_pos + Vector3(0, entity.jump_h + lift, 0)   # pulo: a sim guarda só a altura
	if _push_t < PUSH_IN + PUSH_OUT:
		_push_t += delta
		var k := clampf(_push_t / PUSH_IN, 0.0, 1.0) * (1.0 - smoothstep(PUSH_IN, PUSH_IN + PUSH_OUT, _push_t))
		position += _push * k
	if shade_mat and entity.aggro_target != _shade_seen:
		update_shade()
	if entity.falcon != (falcon_view != null):
		_swap_falcon()
	if falcon_view:
		falcon_view.follow(entity, _smooth_pos, delta)
	var target_rot := entity.facing
	if entity.kind != SimEntity.Kind.PLAYER and entity.kind != SimEntity.Kind.BOT:
		target_rot = entity.facing
	model_root.rotation.y = lerp_angle(model_root.rotation.y, target_rot, minf(1.0, delta * 18.0))
	if entity.spirit:
		_angel_hover()
	if kit and entity.form != _shown_form:
		_morph_t = 0.0 if _shown_form != "" or entity.form != "" else 1.0
		_swap_form()
	if entity.kind == SimEntity.Kind.MONSTER and entity.monster_def != _shown_def and entity.is_alive():
		_swap_monster_model()          # metamorfose: morto fica com o corpo da forma
	if kit and (entity.mounted != _shown_mount or (_shown_mount and _horse_kind != _mount_key())):
		_swap_mount()                      # montou/desceu, ou trocou tipo/cor/armadura na aba Montaria
	var want_alpha := 0.7 if entity.stealth_left > 0.0 else 0.0     # furtivo quase some
	if (entity.stealth_left > 0.0) != _stealth_shown or not is_equal_approx(want_alpha, _alpha_shown):
		_stealth_shown = entity.stealth_left > 0.0
		_alpha_shown = want_alpha
		for mi in model_root.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).transparency = want_alpha
	var ghost := kit != null and (entity.form == "phantom" or entity.shade) and entity.is_alive()
	if ghost != _ghost_on:
		_set_ghost(ghost)
	_animate(delta)
	_morph(delta)
	_teleport_body(delta)
	_anim_lod(delta)
	_update_bars()
	var hit := entity.hit_flash > 0.0
	var flash := AccessSettings.flash if hit else 0.0     # hit flash × Acessibilidade → Clarões (0 = sem)
	if entity.kind == SimEntity.Kind.MONSTER:
		if hit and not _was_hit and entity.is_alive() and not HitReact.poised(entity):
			_flinch = 0.22          # chefe tem postura: só encolhe por HitReact (golpe grande ou interrompido)
		_flinch = maxf(0.0, _flinch - delta)
		_corpse_fade()
	_was_hit = hit
	_apply_flash_look(hit)
	if not _mats.is_empty():
		if flash != _last_flash:
			_last_flash = flash
			for m in _mats:
				m.set_shader_parameter("flash", flash)
			if _ghost_on:
				_ghost_set("flash", flash)
	elif mat:
		mat.set_shader_parameter("flash", flash)
	_update_status()
	var look_debuff := _has_look_debuff()
	if buff_aura == null and BuffAura.enabled and (not entity.buffs.is_empty() or entity.shield_hp > 0.0 or look_debuff):
		buff_aura = BuffAura.new()
		buff_aura.setup(self)
		add_child(buff_aura)
	if buff_aura and (buff_aura.active or not entity.buffs.is_empty() or look_debuff):
		buff_aura.update(delta)
	var ally := _is_party_mate()
	var plv: int = Sim.player.level if Sim.player else 0
	var nq: int = entity.quests_completed.size()          # missão nova pode dar título de honra
	if entity.level != _np_lv or ally != _np_ally or plv != _np_plv or nq != _np_q or GuildUi.revision != _np_guild:     # campos, não meta (3 buscas por boneco por quadro)
		_np_q = nq
		_np_guild = GuildUi.revision
		_np_plv = plv
		_np_lv = entity.level
		_np_ally = ally
		_refresh_nameplate()

## Estados que o jogador precisa ler de longe: atordoado (estrelas), queimando (brasas + laranja), retardado/preso (anel de gelo + azul).
func _update_status() -> void:
	var stunned := entity.state == SimEntity.State.STUNNED and entity.is_alive()
	var burning := false
	var poisoned := false
	var cursed := false
	var prey := false
	var amp := false
	var chill := 0                       # 0 nada, 1 retardado pelo gelo (o anel de gelo)
	var rooted := false                  # preso: raízes nos pés (BuffLooks.CC_LOOKS)
	var drag := false                    # lento sem gelo: poeira fria nos pés
	if entity.is_alive():
		for d in entity.debuffs:
			match d.get("kind"):
				"dot":
					if d.get("fire", false):
						burning = true
					else:
						poisoned = true
				"curse", "wither", "penance", "grave_mark":
					if d.get("prey", false):
						prey = true              # Presa: mira própria (não os fiapos roxos de maldição)
					else:
						cursed = true
				"slow":
					if d.get("frost", false):
						chill = maxi(chill, 1)
					else:
						drag = true
				Balance.DOT_AMP_KIND:
					amp = true
				"root":
					rooted = true
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
	if poisoned and _poison_fx == null:
		_poison_fx = _make_rising(Color(0.6, 1.0, 0.35), Color(0.25, 0.6, 0.1), 0.5, 0.6, "sphere")
	if _poison_fx:
		_poison_fx.emitting = poisoned
	if cursed and _curse_fx == null:
		_curse_fx = _make_rising(Color(0.75, 0.45, 1.0), Color(0.3, 0.1, 0.45), _status_head() / maxf(_base_scale, 0.01) - 0.25, 0.25, "quad")
	if _curse_fx:
		_curse_fx.emitting = cursed
	if prey and _prey_fx == null:
		_prey_fx = _make_prey_mark()
	if _prey_fx:
		_prey_fx.visible = prey
		if prey:
			_prey_fx.rotation.y += get_process_delta_time() * 2.2
	if amp and _amp_fx == null:
		_amp_fx = _make_prey_mark()
		_amp_fx.scale = Vector3.ONE * 1.3
		for c in _amp_fx.get_children():
			if c is MeshInstance3D:
				(c as MeshInstance3D).material_override = Materials.glow(Color(0.5, 1.0, 0.3, 0.95), 1.8)
	if _amp_fx:
		_amp_fx.visible = amp
		if amp:
			_amp_fx.rotation.y -= get_process_delta_time() * 3.0
	if rooted and _root_fx == null:
		_root_fx = CcLook.roots(entity.radius, _base_scale)
		add_child(_root_fx)
	if _root_fx:
		_root_fx.visible = rooted
	if drag and _drag_fx == null:
		_drag_fx = CcLook.drag(entity.radius, _base_scale)
		add_child(_drag_fx)
	if _drag_fx and _drag_fx.emitting != drag:
		_drag_fx.emitting = drag
	if chill > 0 and _chill_fx == null:
		_chill_fx = _make_frost_ring()
	if _chill_fx:
		_chill_fx.visible = chill > 0
		if chill > 0:
			(_chill_fx.material_override as StandardMaterial3D).albedo_color.a = 0.4 if chill == 1 else 0.75
	var st := Color(0, 0, 0, 0)
	if _decoy:
		st = decoy_status()          # a cópia é sempre roxa: veneno/fogo/gelo/maldição não trocam a pele dela
	elif chill > 0:
		st = Color(0.55, 0.85, 1.0, 0.35 if chill == 1 else 0.55)
	elif burning:
		st = Color(1.0, 0.45, 0.12, 0.22 + 0.12 * sin(Time.get_ticks_msec() * 0.018))
	elif poisoned:
		st = Color(0.45, 0.9, 0.25, 0.2 + 0.08 * sin(Time.get_ticks_msec() * 0.008))
	elif cursed:
		st = Color(0.5, 0.25, 0.75, 0.22)
	if st != _last_status:
		_last_status = st
		if not _mats.is_empty():
			for m in _mats:
				m.set_shader_parameter("status", st)
		elif mat:
			mat.set_shader_parameter("status", st)

## Algum debuff com visual próprio no corpo (BuffLooks.DEBUFF_LOOKS: Fumo Doce, Banquete quebrado)?
func _has_look_debuff() -> bool:
	for d in entity.debuffs:
		if BuffLooks.DEBUFF_LOOKS.has(str(d.get("id", ""))):
			return true
	return false

## Borda/padrão de buff na pele (BuffAura): uniform buff_rim do toon em todos os materiais do boneco.
func set_buff_rim(c: Color, style: int) -> void:
	if _decoy and c.a < Balance.SHAZKA_DECOY_RIM.a:      # buff que acaba (BuffAura manda 0) não apaga a borda roxa da cópia
		c = Balance.SHAZKA_DECOY_RIM
		style = 0
	_rim_shown = c
	_rim_style_shown = style
	if not _mats.is_empty():
		for m in _mats:
			m.set_shader_parameter("buff_rim", c)
			m.set_shader_parameter("buff_style", float(style))
	elif mat:
		mat.set_shader_parameter("buff_rim", c)
		mat.set_shader_parameter("buff_style", float(style))

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

## Partículas de estado subindo devagar (veneno: bolhas verdes no corpo; maldição: fiapos roxos sobre a cabeça).
func _make_rising(c0: Color, c1: Color, y: float, r: float, shape: String) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 8
	p.lifetime = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = r * _base_scale
	p.position.y = y * _base_scale
	p.direction = Vector3.UP
	p.spread = 20.0
	p.gravity = Vector3(0, 0.6, 0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.7
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	var mesh: PrimitiveMesh
	if shape == "sphere":
		var sm := SphereMesh.new()
		sm.radius = 0.05; sm.height = 0.1; sm.radial_segments = 6; sm.rings = 3
		mesh = sm
	else:
		var q := QuadMesh.new()
		q.size = Vector2(0.16, 0.16)
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.albedo_texture = SkillFx.soft()
		mesh = q
	mesh.material = m
	p.mesh = mesh
	var g := Gradient.new()
	g.set_color(0, Color(c0, 0.95))
	g.set_color(1, Color(c1, 0.0))
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
	var sp := ShieldOverlay.span_of(entity.hp, entity.shield_hp, entity.stats.max_hp)
	shield_fill.visible = sp.y > sp.x
	if shield_fill.visible:
		_set_seg(shield_fill, sp.x, sp.y, 1.0)
	hp_bar.visible = not entity.shade and entity.is_alive() and ((entity.kind != SimEntity.Kind.MONSTER and not entity.guard) or ratio < 1.0 or entity.aggro_target >= 0)
	var casting := entity.state == SimEntity.State.CASTING and entity.current_skill != null and entity.current_skill.startup > 0.2
	var recall := Sim.recall_progress(entity)          # volta à cidade (G) e montaria (H) também mostram a conjuração
	if recall <= 0.0:
		recall = Sim.mount_progress(entity)
	cast_bar.visible = (casting and entity.skill_phase == "startup") or recall > 0.0
	if recall > 0.0:
		_set_bar(cast_fill, recall, 0.8)
	elif cast_bar.visible:
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

## Pedaço da barra de `from` a `to` (frações), mesma ideia do _set_bar (billboard: mexe na malha, não no nó).
func _set_seg(mi: MeshInstance3D, from: float, to: float, width: float) -> void:
	var q := mi.mesh as QuadMesh
	var w := maxf(0.001, to - from) * width
	var c := (-0.5 + (from + to) * 0.5) * width
	if is_equal_approx(q.size.x, w) and is_equal_approx(q.center_offset.x, c):
		return
	q.size.x = w
	q.center_offset.x = c

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
	if _wheels:
		_animate_wheels(delta)
	if draft:
		_animate_draft(delta)
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
			model_root.position.y = -d * 0.4 + _perch
			model_root.scale = Vector3.ONE * _base_scale
			return
	model_root.rotation.x = lerpf(model_root.rotation.x, tilt, minf(1.0, delta * 22.0))
	model_root.position.y = lerpf(model_root.position.y, y + _perch, minf(1.0, delta * 20.0))
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
const IMPACT_FRAME := {"cast_heal_nature": 8, "cast_curse": 8, "cast_wind": 9, "summon_rise": 11, "summon_call": 9, "atk_bow_charge": 12, "atk_pistol_pair": 6, "atk_pistol_fan": 6, "atk_scythe_reap": 8, "shout_rally": 7,
	"maul": 7, "pounce": 9, "slam": 8, "roar": 7, "brace": 6, "atk_rifle": 6, "atk_1h_a": 7, "atk_1h_b": 7, "atk_2h": 10, "atk_dual_a": 5, "atk_dual_b": 5, "atk_dagger": 5,
	"atk_bow": 8, "atk_staff": 7, "atk_spin": 8, "atk_thrust": 6, "cast": 10, "cast_buff": 8, "attack": 5,
	"cast_ground": 10, "cast_channel": 14, "cast_target": 8, "atk_leap": 12, "atk_charge": 5, "atk_throw": 7,
	"atk_shoot_multi": 8, "summon": 11, "atk_pistol": 6, "atk_slash_shot": 9, "atk_sweep": 8, "atk_finisher": 10, "atk_flurry": 5, "atk_claw": 6, "shout": 7,
	"cast_fire": 8, "cast_ice": 8, "cast_bolt": 7, "cast_holy": 8, "cast_shadow": 8, "cast_nature": 9,
	"buff_power": 7, "buff_guard": 6, "buff_focus": 8, "wall_counter": 10, "block": 8,     # block: skill de monstro com `clip: "block"` (Concha do Caranguejo-Eremita: recolhido aos 0,3 s)
	"atk_2h_chain_a": 5, "atk_2h_chain_b": 6, "atk_2h_chain_c": 7}     # sequência de duas mãos do Golpe do Cruzado (só no kit do Paladino)
## clipes só de modelo de monstro (não existem nos kits): wall_counter = contragolpe da Muralha (mob_ghar)
const MOB_ONLY_CLIPS := {"wall_counter": "mob_ghar"}
## clipes que só o kit de uma classe tem (chibi_kit.CHAIN_CLASSES): os kits genéricos e os das outras classes não levam
const CLASS_ONLY_CLIPS := {"atk_2h_chain_a": "paladin", "atk_2h_chain_b": "paladin", "atk_2h_chain_c": "paladin"}
const RUN_REF_SPEED := 5.2            # m/s em que o ciclo "run" do kit casa com o chão
const TWO_HANDED_MELEE := ["sword2h", "mace2h", "axe2h", "scythe"]
var manual_anim := false             # combat_probe: animação andada à mão, quadro a quadro
var _dt := 0.0                        # delta do _process_view atual
var _act_skill: SkillDef = null      # skill da ação atual (detecta golpe novo)
var _act_time := 0.0
var _combo := 0                       # alterna golpe A/B (combo de 2) e mão direita/esquerda
var _act_speed := 1.0                 # velocidade do clipe na preparação
var _retimed := false                 # depois do impacto o resto do clipe cabe no resto da skill
var _aim_hold := -1.0                 # Suprema de mira longa (Disparo do Fim): o clipe para no quadro do tiro até o fim da mira
var _slash_done := false              # Corte e Tiro: o arco do sabre já saiu nesta ação (WeaponArcs.slash_hook); true = ação sem corte
var _slash_clip := ""                 # Corte e Tiro: o clipe da ação, guardado quando ela começa (não procura o clipe por quadro)
var _ribbon_key: SkillDef = null      # WeaponArcs.ribbon_off guardado por ação: skill, forma e armas de quando foi calculado
var _ribbon_form := ""
var _ribbon_w := ""
var _ribbon_off_w := ""
var _ribbon_off := false
var _form_hook := 0                   # forma de bicho: quadro do clipe da 2ª garra que ainda vai sair (WeaponArcs.form_hook; 0 = nada)
var _form_land := ""                  # bote/investida de bicho: clipe cujas garras saem quando o salto de desenho pousa

## WeaponArcs: o bote saiu na sim (que teleporta); as garras esperam o boneco pousar no fim do arco de desenho.
func form_land_marks(clip: String) -> void:
	_form_land = clip
var _sig_hold := 0.0                  # s que o clipe de assinatura (contragolpe da Muralha) ainda segura antes de voltar ao idle

## Muralha de Escudos do Ghar (mob_ghar): enquanto ela dura, guard_wall no lugar de idle/corrida/guarda; no fim, o
## wall_counter uma vez, alinhado ao início do contragolpe da sim (o golpe cai no quadro IMPACT_FRAME, Balance.GHAR_COUNTER_DELAY).
func _sig_base(base: String) -> String:
	_sig_hold = maxf(0.0, _sig_hold - _dt)
	if not base in ["idle", "run", "block"] or entity.kind != SimEntity.Kind.MONSTER:
		_sig_hold = 0.0
		return base
	if not entity.sig.is_empty() and entity.sig.has("counter") and _clip("wall_counter") != "":
		if anim.current_animation != "wall_counter":
			_play("wall_counter", 0.06)
			anim.seek(clampf(Sim.time - float(entity.sig["counter"].get("start", Sim.time)), 0.0, 0.3), true)
			_sig_hold = anim.current_animation_length - anim.current_animation_position
		return "wall_counter"
	if _sig_hold > 0.0 and anim.current_animation == "wall_counter" and anim.is_playing() and base != "run":
		return "wall_counter"                 # resto do golpe (acomodação) antes do idle
	_sig_hold = 0.0
	if not entity.sig.is_empty() and entity.sig.has("wall") and _clip("guard_wall") != "":
		return "guard_wall"
	return base

## Clip de golpe/magia para a skill: primeiro pela FORMA da skill (salto, investida, arremesso, magia no chão,
## canalizada, no alvo, invocação, leque de flechas), depois pela família da arma empunhada.
## Gestos de fase ativa longa (giro, canalização, pisão): repetem até a fase ativa acabar em vez de parar na pose final.
const RECALL_ANIM_SPEED := 0.75      # conjuração da volta à cidade: gesto calmo, em laço
const ACTIVE_LOOP := ["atk_spin", "cast_channel", "cast_shadow", "slam", "atk_thrust", "atk_scythe_reap"]     # atk_thrust: Lança Incansável (estocadas em canal)
## Sequência de golpes (efeito "strikes", Golpe do Cruzado): um clipe por golpe (`strikes.clips`), cada impacto no tick
## do golpe dele. Os clipes atk_2h_chain_a/b/c (chibi_kit.animate_crusader) têm o impacto nos quadros 5/6/7 = os preparos
## que saem daqui (0,16 / 0,21 / 0,24 s), então tocam a ~1x; mudou `at` ou STRIKE_NEXT_AT: refaça os clipes. O próximo clipe entra depois desta fração do intervalo entre os golpes (o resto é a preparação dele).
const STRIKE_NEXT_AT := 0.25
var _strike_shown := 0                # golpe da sequência cujo clipe está tocando

## Suprema de um golpe só segurando a pose do impacto: do fim do preparo até + Balance.ULT_HOLD_S (V1/D2; sequência
## "strikes" tem a parada dela). Só desenho: o tempo da skill na sim não muda.
static func ult_holding(s: SkillDef, state_time: float) -> bool:
	return s != null and s.ultimate and not s.effects.has("strikes") and state_time >= s.startup and state_time < s.startup + Balance.ULT_HOLD_S

## Segundos depois do fim do preparo em que cai o último golpe da sequência (0 = skill de um golpe só).
static func strike_last_at(s: SkillDef) -> float:
	var st = s.effects.get("strikes") if s else null
	if not (st is Dictionary):
		return 0.0
	var at_s: Array = st.get("at", [])
	return float(at_s.back()) if not at_s.is_empty() else 0.0

## Troca para o clipe do próximo golpe da sequência na hora certa. true = a sequência ainda não acabou (sem reajuste
## do resto do clipe); false = último golpe já tocando (o reajuste normal leva o resto até o fim da skill).
func _strike_step(s: SkillDef) -> bool:
	var st = s.effects.get("strikes")
	if not (st is Dictionary):
		return false
	var clips: Array = st.get("clips", [])
	var at_s: Array = st.get("at", [])
	var n := mini(clips.size(), at_s.size())
	var nxt := _strike_shown + 1
	if nxt >= n:
		return false
	var hit_t := s.startup + float(at_s[nxt])
	var prev_t := s.startup + float(at_s[_strike_shown])
	if entity.state_time < prev_t + (hit_t - prev_t) * STRIKE_NEXT_AT:
		return true
	_strike_shown = nxt
	var clip := _clip(str(clips[nxt]))
	if clip != "":
		var wt := windup_timing(float(IMPACT_FRAME.get(clip, 5) - 1) / 24.0, maxf(hit_t - entity.state_time, 0.06))
		_act_speed = wt.y
		_retimed = false
		_play(clip, 0.06, wt.y)
		anim.seek(wt.x, true)
	return true

## Velocidade do clipe para o impacto do desenho cair no tick do dano (preparo longo = clipe mais lento).
const LOOP_MIN_ACTIVE := 0.5        # s de fase ativa para o gesto repetir (curta: acaba junto com a skill, como os outros)
const ANIM_MIN_SPEED := 0.4
const HELD_BASIC_MIN_SPEED := 0.28   # ataque segurado: a volta do golpe pode ir até 0,28x para emendar no próximo
const ANIM_MAX_SPEED := 3.2
const WINDUP_MAX_SPEED := 2.2        # preparo mais curto que isso: o clipe começa no meio da preparação em vez de correr 3x

## Onde começar o clipe e a que velocidade, para o impacto cair no fim do preparo da skill: Vector2(início_s, velocidade).
## `coil` (s, coil_for) = começar na pose armada quando o preparo ainda fica >= COIL_MIN_SPEED.
static func windup_timing(impact: float, startup: float, coil := 0.0) -> Vector2:
	var t0 := maxf(0.0, impact - startup * WINDUP_MAX_SPEED)
	if coil > 0.0 and coil < impact:
		t0 = maxf(t0, minf(coil, impact - startup * COIL_MIN_SPEED))
	return Vector2(t0, clampf((impact - t0) / startup, ANIM_MIN_SPEED, ANIM_MAX_SPEED))
const LEAP_IDS := ["leap", "pounce", "stampede"]     # Passo das Sombras saiu: é teleporte (TELEPORTS)
const SHOUT_IDS := ["warcry", "taunt"]
const FINISHER_IDS := ["execute", "decapitate", "assassinate", "overhead", "butcher", "grim", "headshot"]
const FLURRY_IDS := ["flurry", "thousand", "twin", "hack", "dance", "backstab", "eviscerate"]
const CLAW_IDS := ["claw", "rend", "savage", "maul"]
const GUARD_IDS := ["shield", "armor", "skin", "ward", "bark", "wall", "aegis", "martyr"]
## gesto por elemento (magias e curas)
const CAST_BY_THEME := {"fire": "cast_fire", "ice": "cast_ice", "lightning": "cast_bolt", "holy": "cast_holy", "heal": "cast_holy", "shadow": "cast_shadow",
	"bone": "cast_shadow", "poison": "cast_shadow", "nature": "cast_nature", "lunar": "cast_nature", "earth": "cast_nature", "wind": "cast_wind", "summon": "summon"}
## Roteamento por arquétipo (pacote C1, 2026-11-23; production/qa/spell-attack-anim-research-2026-11-23.md). Só skills de
## classe (`SkillDef.class_id`); monstros seguem as regras de sempre. `SkillDef.clip` escrito continua vencendo (exceto o
## refino de invocação/pistola em `refine_clip`).
## Cura pelo tema da classe: o Druida cura com a natureza, o Necromante drena, Bispo/Paladino com a luz.
const HEAL_BY_CLASS := {"druid": "cast_heal_nature", "necromancer": "cast_shadow", "bishop": "cast_holy", "paladin": "cast_holy"}
## Magia de classe em linha cujo tema não tem gesto próprio: o gesto da classe (nunca o golpe básico da arma).
const CAST_BY_CLASS := {"bishop": "cast_holy", "paladin": "cast_holy", "druid": "cast_nature", "necromancer": "cast_shadow", "assassin": "cast_shadow"}
## Maldição do Necromante (palavra no id ou tema veneno): puxa do chão, não o rasgo da sombra.
const CURSE_IDS := ["curse", "plague", "pandemic", "rot", "decay", "swarm", "agony", "doom", "weakness", "wither", "blight", "hex"]
## Invocação: o Necromante ergue do chão; Druida e Ranger chamam (assobio/braço).
const SUMMON_BY_CLASS := {"necromancer": "summon_rise", "druid": "summon_call", "ranger": "summon_call"}
## Brado de grupo (buff em área para os aliados) dessas classes: brado de ânimo, não o de ameaça.
const RALLY_CLASSES := ["berserker", "paladin", "assassin", "ranger", "druid"]
const RALLY_MIN_RADIUS := 3.0
## Arco: tiro com preparo a partir disto (s) segura a corda puxada (atk_bow_charge).
const BOW_CHARGE_STARTUP := 0.2
## Clipes novos (C2, chibi_kit) -> clipe de hoje que toca enquanto o kit/GLB não tiver o novo (`_clip`). Clipe novo que
## chegar: entra em IMPACT_FRAME (e COIL_FRAME) com o quadro do chibi_kit.IMPACT; há check (`_check_clip_routing`).
const CLIP_FALLBACK := {"cast_heal_nature": "cast_nature", "cast_curse": "cast_shadow", "cast_wind": "cast", "summon_rise": "summon",
	"summon_call": "summon", "atk_bow_charge": "atk_bow", "atk_pistol_pair": "atk_pistol", "atk_pistol_fan": "atk_pistol",
	"atk_scythe_reap": "cast_shadow", "shout_rally": "shout"}
## Antecipação sem atraso (pacote V2): quadro (24 fps, base 1) da 1ª pose de preparação de cada clipe = a primeira chave
## depois do repouso em chibi_kit (_pose_action). A skill começa o clipe ali (o 1º quadro já é a pose armada) em vez de
## correr os quadros neutros; o impacto continua no tick do dano (windup_timing). Clipe fora da tabela: sem salto.
const COIL_FRAME := {"cast_heal_nature": 3, "cast_curse": 3, "cast_wind": 4, "summon_rise": 4, "summon_call": 3, "atk_bow_charge": 3, "atk_pistol_pair": 3, "atk_pistol_fan": 3, "atk_scythe_reap": 3, "shout_rally": 4,
	"atk_1h_a": 4, "atk_1h_b": 4, "atk_2h": 7, "atk_dual_a": 3, "atk_dual_b": 3, "atk_dagger": 3, "atk_thrust": 3,
	"atk_bow": 3, "atk_staff": 3, "cast": 3, "cast_buff": 3, "cast_ground": 5, "cast_channel": 4, "cast_target": 5, "atk_leap": 4,
	"atk_charge": 3, "atk_throw": 4, "atk_shoot_multi": 4, "summon": 6, "atk_pistol": 3, "atk_slash_shot": 3, "atk_sweep": 5,
	"atk_finisher": 5, "atk_flurry": 3, "atk_claw": 4, "shout": 4, "cast_fire": 5, "cast_ice": 5, "cast_bolt": 5, "cast_holy": 4,
	"cast_shadow": 3, "cast_nature": 5, "buff_power": 4, "buff_guard": 3, "buff_focus": 5, "atk_rifle": 3}
const COIL_MIN_SPEED := 1.0         # pular para a pose armada nunca deixa o preparo abaixo de 1x (não vira câmera lenta)

## Segundos do clipe em que a skill começa (pose armada; 0 = do começo). Básico, Suprema, sequência de golpes e clipe sem
## linha em COIL_FRAME ficam como antes.
static func coil_for(s: SkillDef, clip: String) -> float:
	if s == null or s.id.begins_with("basic_") or s.ultimate or s.effects.get("strikes") is Dictionary or not COIL_FRAME.has(clip):
		return 0.0
	return float(int(COIL_FRAME[clip]) - 1) / 24.0

static func _has_token(id: String, tokens: Array) -> bool:
	return tokens.any(func(t): return t in id)

## Buff por intenção: guardar, sagrado, força ou foco.
static func _buff_clip(s: SkillDef) -> String:
	if s.effects.has("shield") or _has_token(s.id, GUARD_IDS):
		return "buff_guard"
	if s.class_id in RALLY_CLASSES and s.radius >= RALLY_MIN_RADIUS and s.effects.has("buff") and not (s.vfx in ["holy", "nature"]):
		return "shout_rally"            # buff de grupo: brado de ânimo
	if s.vfx == "holy":
		return "cast_holy"
	if s.vfx in ["blood", "earth"]:
		return "buff_power"
	if s.vfx == "nature":
		return "cast_nature"
	return "buff_focus"
## Gesto por arquétipo da classe ("" = segue as regras de tema/forma): cura por classe, maldição do Necromante,
## veneno do Assassino (arremesso), ceifa da foice.
static func _archetype_clip(s: SkillDef, w: String) -> String:
	if s.class_id == "" or s.effects.has("dash"):
		return ""
	if s.kind == SkillDef.Kind.HEAL and HEAL_BY_CLASS.has(s.class_id):
		return HEAL_BY_CLASS[s.class_id]
	if s.kind != SkillDef.Kind.MAGICAL:
		return ""
	match s.class_id:
		"necromancer":
			if s.vfx == "poison" or _has_token(s.id, CURSE_IDS):
				return "cast_curse"
			if w == "scythe" and s.target in [SkillDef.Target.CONE, SkillDef.Target.SELF] and s.vfx in ["shadow", "bone", "blood"]:
				return "atk_scythe_reap"
		"assassin":
			if s.vfx == "poison":
				return "atk_throw"          # bomba/frasco: lança, não conjura a sombra do Necromante
		"druid":
			if s.vfx in ["poison", "shadow"]:
				return "cast_nature"
	return ""

## Refino de um clipe já escolhido (também do `SkillDef.clip` escrito): invocação pela classe, pistola em leque/par.
static func refine_clip(s: SkillDef, clip: String) -> String:
	if clip == "summon" and SUMMON_BY_CLASS.has(s.class_id):
		return SUMMON_BY_CLASS[s.class_id]
	if clip == "atk_pistol":
		if s.target == SkillDef.Target.CONE:
			return "atk_pistol_fan"
		if s.effects.get("strikes") is Dictionary:
			return "atk_pistol_pair"
	return clip

const THROW_IDS := ["throw", "dart", "fan", "net", "trap"]
func _action_clip(s: SkillDef) -> String:
	var w := entity.stats.weapon_type if entity.stats else ""
	var off := entity.stats.offhand_type if entity.stats else ""
	var form := form_view != null
	return clip_for_skill(s, w, off, _combo, form, form and anim.has_animation("atk_1h_a"))

## Clipe (nome lógico, antes do `KitModel.resolve`) que um golpe/skill toca, sem entidade da sim: a mesma regra do jogo,
## usada também pela tela de Criação (skill-assinatura da classe). `weapon`/`offhand` = `Stats.weapon_type/offhand_type`;
## `combo` alterna os golpes A/B; `form` = forma de bicho (`form_humanoid` = a forma tem os golpes humanos).
static func clip_for_skill(s: SkillDef, weapon := "", offhand := "", combo := 0, form := false, form_humanoid := false) -> String:
	if s == null:
		return "attack"
	var basic := s.id.begins_with("basic_")
	if basic and form and not form_humanoid:
		return "attack"                   # bicho: o básico é a mordida dele
	var w := weapon
	var off := offhand
	if not basic and TELEPORTS.has(s.id):
		return "cast_buff" if s.class_id != "" else "buff_focus"    # teleporte: gesto curto de sumir (o corpo some no meio), nunca avanço/salto; chefe não tem cast_buff (MOB_BOSS_KEEP)
	if not basic and s.clip != "" and not form:
		return refine_clip(s, s.clip)     # clipe escrito na skill (a palavra do id enganava a regra)
	if not basic:
		if "disengage" in s.id:
			return "jump"                 # salto pra trás
		if _has_token(s.id, SHOUT_IDS) or (s.kind == SkillDef.Kind.BUFF and s.target == SkillDef.Target.SELF and s.effects.has("taunt")):
			return "shout"                # brado de ameaça (provoca)
		if "kick" in s.id:
			return "atk_thrust"
		for k in LEAP_IDS:
			if k in s.id:
				return "atk_charge" if s.startup < 0.15 else "atk_leap"      # salto instantâneo (sombra): avanço curto
		if s.effects.has("channel"):
			if s.kind == SkillDef.Kind.PHYSICAL and s.class_id != "":
				return "atk_spin"           # golpe canalizado de guerreiro (Ciclone): gira, não conjura
			return "cast_channel"
		for k in THROW_IDS:
			if k in s.id:
				return "atk_throw"
		if s.kind == SkillDef.Kind.SUMMON:
			return refine_clip(s, "summon")
		if s.kind == SkillDef.Kind.BUFF:
			return _buff_clip(s)
		var arch := _archetype_clip(s, w)
		if arch != "":
			return arch
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
		if w == "bow" and s.kind == SkillDef.Kind.PHYSICAL and s.class_id != "" and s.startup >= BOW_CHARGE_STARTUP \
				and s.target in [SkillDef.Target.DIRECTION, SkillDef.Target.TARGET]:
			return "atk_bow_charge"       # tiro carregado: segura a corda puxada
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
				if s.class_id != "":
					return str(CAST_BY_CLASS.get(s.class_id, "cast"))     # magia de classe em linha: gesto de magia, não o básico
				return "atk_staff" if w in ["staff", "wand", "scythe", "scepter", ""] or off == "orb" else ("atk_2h" if w in TWO_HANDED_MELEE else "atk_1h_a")
			return "cast"
		SkillDef.Kind.MOVEMENT:
			return "dash" if s.class_id != "" else "cast_buff"     # piscar/avanço de classe: o arranque do dash
	# físico
	if not basic:
		if s.target == SkillDef.Target.SELF:
			return "atk_spin"
		if s.target == SkillDef.Target.GROUND and w not in ["bow", "rifle"]:
			if w in TWO_HANDED_MELEE or w == "spear":
				return "atk_leap"
			if s.class_id == "":
				return "cast_ground"
			# golpe de chão de uma mão (C1): guerreiro não conjura. Avanço = salto; o que fica no chão (veneno, estrepes,
			# zona) = arremesso; o resto = golpe de cima no chão
			if s.effects.has("dash"):
				return "atk_leap"
			if s.effects.has("dot") or s.effects.has("zone") or s.effects.has("slow") or s.effects.has("trap"):
				return "atk_throw"
			return "atk_finisher"
	if w == "bow":
		return "atk_bow"
	if w == "rifle":
		return "atk_rifle"
	if w == "spear":
		return "atk_thrust"            # lança: estocada (o básico é uma linha longa e estreita)
	if w == "axe2h":
		return "atk_sweep"             # machado de duas mãos: talho largo de lado a lado (o golpe básico pega 150°); com a
		                               # Empunhadura de Titã também (o golpe é lento: o clipe de duas armas acabava antes e parava)
	if w in TWO_HANDED_MELEE:
		return "atk_2h"
	if off in ItemDef.ONE_HANDED_MELEE:
		return "atk_dual_a" if combo % 2 == 0 else "atk_dual_b"
	if w == "dagger":
		return "atk_dagger"
	return "atk_1h_a" if combo % 2 == 0 else "atk_1h_b"

## Nome real do clip ("" se o modelo não tiver).
## Forma de bicho (lobo/urso): o gesto humano pedido vira o do animal (tools/blender/druid_sets.form_clips).
const FORM_CLIP := {"atk_claw": "maul", "atk_flurry": "maul", "atk_finisher": "maul", "atk_sweep": "maul", "atk_dual_a": "maul",
	"atk_dual_b": "maul", "atk_1h_a": "maul", "atk_1h_b": "maul", "atk_2h": "maul", "atk_thrust": "maul",
	"atk_leap": "pounce", "atk_charge": "pounce", "atk_spin": "slam", "cast_ground": "slam",
	"shout": "roar", "cast": "roar", "cast_nature": "roar", "cast_buff": "roar", "cast_target": "roar", "cast_channel": "roar",
	"buff_power": "roar", "buff_focus": "roar", "summon": "roar", "buff_guard": "brace",
	"atk_throw": "maul", "cast_fire": "roar", "cast_ice": "roar", "cast_bolt": "roar", "cast_holy": "roar",
	"cast_shadow": "roar", "cast_heal_nature": "roar", "cast_curse": "roar", "cast_wind": "roar", "summon_rise": "roar",
	"summon_call": "roar", "shout_rally": "roar", "atk_scythe_reap": "maul"}

func _clip(name: String) -> String:
	var c := _clip_raw(name)
	if c == "" and CLIP_FALLBACK.has(name):
		c = _clip_raw(CLIP_FALLBACK[name])     # clipe novo (C2) que este kit/GLB ainda não tem: o gesto de antes
	return c

func _clip_raw(name: String) -> String:
	if kit and form_view == null:
		return kit.resolve(name)
	if anim.has_animation(name):
		return name
	var alt: String = FORM_CLIP.get(name, "")
	return alt if alt != "" and anim.has_animation(alt) else ""

## Clipe que toca quando o kit não tem `clip` (CLIP_FALLBACK; o próprio nome se não for clipe novo).
static func fallback_clip(clip: String) -> String:
	return str(CLIP_FALLBACK.get(clip, clip))

## Escudo arremessado (efeito "bounce") ainda no ar: a mão do escudo fica vazia até ele voltar.
func _shield_in_flight() -> bool:
	if not Sim.maps.has(entity.map_id):
		return false
	for p in Sim.maps[entity.map_id]["projectiles"]:
		if p.owner_id == entity.id and not p.bounce.is_empty():
			return true
	return false

## Golpe com arco (WeaponArcs): empurrão de desenho na direção `push` (m) e/ou animação parada por `stop` s.
func hit_react(push: Vector3, stop: float) -> void:
	if push != Vector3.ZERO:
		_push = push
		_push_t = 0.0
	_stop_left = maxf(_stop_left, stop)

## Rastro da arma só na parte "rápida" do golpe/magia (fim da preparação até logo depois do impacto).
func _update_trail(st: int) -> void:
	var s := entity.current_skill
	var on := false
	if st == SimEntity.State.CASTING and s != null:
		var t := entity.state_time
		on = t >= s.startup * 0.35 and t <= s.startup + s.active + 0.12
		if s.effects.get("shot", false) and s.range > 3.0:
			on = false                     # tiro de pistola: o sabre fica parado, sem rastro
		if teleport_style(s) != "":
			on = false                     # teleporte: a fita esticaria da origem até o destino
		if _arc_ribbon_off(s):
			on = false                     # família com arco (WeaponArcs.FAMILIES): o crescente substitui a fita
		var th := FxManager.theme_of(s)
		var magic := s.kind != SkillDef.Kind.PHYSICAL and th != "physical" and th != ""
		if magic and s.id.begins_with("basic_") and entity.stats and entity.stats.weapon_type in KitModel.THIN_TRAIL_WEAPONS:
			on = false                     # básico de cajado/foice: sem fita (ela é do gesto da skill, V5)
		kit.trail_tint = SkillFx.col(th, 0) if magic else Color(0, 0, 0, 0)     # magia: o rastro do cajado/cetro na cor do tema
	kit.trail_on = on

## WeaponArcs.ribbon_off da ação: recalcula só quando a skill, a forma ou as armas mudam (não a cada quadro).
func _arc_ribbon_off(s: SkillDef) -> bool:
	var w := entity.stats.weapon_type if entity.stats else ""
	var off := entity.stats.offhand_type if entity.stats else ""
	if s != _ribbon_key or entity.form != _ribbon_form or w != _ribbon_w or off != _ribbon_off_w:
		_ribbon_key = s
		_ribbon_form = entity.form
		_ribbon_w = w
		_ribbon_off_w = off
		_ribbon_off = WeaponArcs.ribbon_off(entity, s)
	return _ribbon_off

## Modificador de troca de clipe do modelo mostrado (kit ou bicho).
## Golpe forte (HitReact): personagem inclina o tronco por cima do clipe (HitFlinch, aditivo, sem tirar o controle);
## monstro/chefe encolhe no clipe "hit" como no clarão (o _flinch só desce no ramo de monstro). `dir` = do atacante para este boneco.
func react_hit(dir: Vector3, strength: float) -> void:
	if entity.kind == SimEntity.Kind.MONSTER:
		if entity.is_alive():
			_flinch = 0.22
		return
	if kit == null or form_view != null or kit.skeleton == null:
		return          # forma de bicho: sem osso de tronco do kit
		return
	if _hit_flinch == null:
		_hit_flinch = HitFlinch.new()
		kit.skeleton.add_child(_hit_flinch)
		_hit_flinch.setup(kit.skeleton)
	_hit_flinch.kick(dir, strength)

## Reação de golpe forte em curso (teste e filme).
func flinching() -> bool:
	return (_hit_flinch != null and _hit_flinch.busy()) or _flinch > 0.0

func pose_fade() -> PoseFade:
	if form_view:
		return form_view.fade
	return kit.fade if kit else null

## Troca de clipe: a pose da tela desliza para o clipe novo (PoseFade) em vez da mistura do AnimationPlayer,
## que passa pelo repouso do osso e vira a mão do avesso num quadro quando ela está girada perto de 180°.
func _play(clip: String, fade: float, speed: float = 1.0) -> void:
	var pf := pose_fade()
	if pf:
		pf.start(fade)
		anim.play(clip, 0.0, speed)
	else:
		anim.play(clip, fade, speed)

func _animate_glb(st: int) -> void:
	var pf := pose_fade()
	if pf:
		pf.tick(_dt)
	var ride_strike := false
	if horse:                       # montado: boneco no clipe "ride", cavalo corre/para pela velocidade
		var moving := entity.velocity.length() > 0.2
		ride_strike = (st == SimEntity.State.CASTING and entity.current_skill != null) or st == SimEntity.State.BLOCKING     # Combate Montado: golpeia (e bloqueia, Muralha a Cavalo) da sela
		var hc := "run" if moving or ride_strike else "idle"
		if horse.anim and horse.anim.has_animation(hc) and horse.anim.current_animation != hc:
			horse.anim.play(hc, 0.15)
		if horse.anim:
			horse.anim.speed_scale = clampf(entity.velocity.length() / 6.0, 0.6, 1.8) if moving else 1.0
		_ride_saddle()
		if _ride_legs:
			_ride_legs.active = ride_strike
		if not ride_strike:
			if anim.has_animation("ride") and anim.current_animation != "ride":
				anim.speed_scale = 1.0
				anim.play("ride", 0.15)
			_act_skill = null
			return
	elif _ride_legs and _ride_legs.active:
		_ride_legs.active = false
	if kit and form_view == null:
		_update_trail(st)
		if entity.stats and entity.stats.has_shield:
			kit.set_offhand_thrown(_shield_in_flight())
	# golpe/magia: escolhe o clip pela arma, reinicia a cada ação e acelera o clip para o impacto
	# cair exatamente no momento do dano (fim do startup da skill)
	var legs: LegOverlay = form_view.legs if form_view else (kit.legs if kit else null)
	if legs:
		var going: bool = st in [SimEntity.State.CASTING, SimEntity.State.BLOCKING] and entity.velocity.length() > 0.2
		legs.drive(_dt, going, entity.velocity.length(), RUN_REF_SPEED)
	if st == SimEntity.State.CASTING:
		var s := entity.current_skill
		var fresh := s != _act_skill or entity.state_time < _act_time
		_act_skill = s
		_act_time = entity.state_time
		var looping: bool = s != null and s.active >= LOOP_MIN_ACTIVE and anim.assigned_animation in ACTIVE_LOOP
		if s and not fresh and _aim_hold >= 0.0 and entity.state_time < s.startup:
			if anim.current_animation_position >= _aim_hold:
				anim.speed_scale = 0.0               # mirando: fica no quadro do disparo (o tiro sai no fim do startup)
			return
		if s and not fresh and _strike_step(s):
			return                             # sequência de golpes: o próximo clipe já entrou ou ainda vai entrar
		if s and not fresh and not _retimed and ult_holding(s, entity.state_time):
			anim.speed_scale = 0.0             # Suprema: segura a pose do impacto (V1/D2); o dano já saiu no tick, a sim não muda
			return
		if s and not fresh and not _retimed and entity.state_time >= s.startup + strike_last_at(s) and anim.is_playing():
			# impacto: o que resta do clipe acaba junto com a skill (sem pose congelada nem corte);
			# giro/canalização acaba junto com a fase ativa (e repete enquanto ela durar)
			_retimed = true
			var left: float = anim.current_animation_length - anim.current_animation_position
			var end_t: float = minf(entity.state_duration, s.startup + s.active) if looping else entity.state_duration
			var time_left := maxf(end_t - entity.state_time, 0.05)
			var slowest := 0.5
			if (s == entity.basic_skill or entity.current_skill_slot < 0) and entity.last_cmd and entity.last_cmd.attack:     # slot -1 = básico (montado: cópia)
				time_left = maxf(time_left, entity.basic_cd)     # segurando o ataque: o golpe emenda no próximo, sem parar na guarda
				slowest = HELD_BASIC_MIN_SPEED                     # arma pesada: a volta do golpe fica mais lenta (peso)
			anim.speed_scale = clampf(left / time_left / maxf(_act_speed, 0.01), slowest, 2.5)
		elif s and not fresh and looping and not anim.is_playing() and entity.state_time < s.startup + s.active - 0.1:
			_play(anim.assigned_animation, 0.05, _act_speed)          # fase ativa longa: o gesto repete
			anim.seek(0.0, true)
			if form_view and WeaponArcs.draws_arc(entity, s):
				_form_hook = -int(IMPACT_FRAME.get(anim.assigned_animation, 5))     # pisão que repete: as garras de novo no impacto
		if fresh:
			_slash_done = true                 # sem clipe de Corte e Tiro nesta ação: nada a soltar
			var want_clip := _action_clip(s)
			var clip := _clip(want_clip)
			if clip == "":
				clip = _clip("cast" if (s and s.kind != SkillDef.Kind.PHYSICAL) else "attack")
			if clip == "":
				clip = _clip("attack")         # bicho (forma de animal): todo golpe é o ataque dele
			if clip != "":
				var impact := float(IMPACT_FRAME.get(clip, 5) - 1) / 24.0
				var startup := maxf(s.startup if s else 0.15, 0.06)
				var coil := coil_for(s, clip) if kit and form_view == null and entity.kind != SimEntity.Kind.MONSTER else 0.0
				var wt := windup_timing(impact, startup, coil)
				_aim_hold = -1.0
				if s and s.ultimate and startup > 0.6:     # mira longa: sobe a arma no ritmo normal e segura (não arrasta o preparo)
					_aim_hold = maxf(0.0, impact - 0.05)
					wt = Vector2(maxf(0.0, impact - 0.3), 1.0)
				anim.speed_scale = 1.0
				_act_speed = wt.y
				_retimed = false
				_slash_clip = clip if clip == _clip("atk_slash_shot") else ""
				_slash_done = _slash_clip == ""
				_form_hook = WeaponArcs.form_hook_frame(clip, entity.form) if form_view and WeaponArcs.draws_arc(entity, s) else 0
				_play(clip, 0.06, wt.y)
				anim.seek(wt.x, true)
				_combo += 1
				_strike_shown = 0
		# Corte e Tiro: o golpe do sabre passa antes do tiro (o tick do dano) -> o arco sai no quadro do corte
		if not _slash_done and s and anim.assigned_animation == _slash_clip and anim.current_animation_position >= float(WeaponArcs.SLASH_FRAME - 1) / 24.0:
			_slash_done = true
			WeaponArcs.slash_hook(entity, s)
		# forma de bicho (onda 6): a 2ª garra do maul no quadro dela; < 0 = repetição do pisão (as do tick de novo)
		if _form_hook != 0 and form_view and anim.current_animation_position >= float(absi(_form_hook) - 1) / 24.0:
			WeaponArcs.form_hook(entity, anim.assigned_animation, _form_hook < 0)
			_form_hook = 0
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
			_play(gc, 0.15)
			anim.speed_scale = 1.0
		if gc != "":
			return
	# volta à cidade (G): gesto de conjuração repetindo até acabar ou ser interrompido
	if entity.recall_left > 0.0:
		var rc := _clip("cast_channel")
		if rc == "":
			rc = _clip("cast")
		if rc != "":
			if anim.current_animation != rc:
				_play(rc, 0.18)
			anim.speed_scale = RECALL_ANIM_SPEED
			return
	# metamorfose de monstro conjurando: gesto de conjurar até trocar (senão o idle do quadro seguinte apaga o shift_gesture)
	if entity.shift_left > 0.0 and entity.state != SimEntity.State.CASTING:
		var sc := _clip("cast_nature")
		for c in ["cast", "shout", "attack"]:
			if sc == "":
				sc = _clip(c)
		if sc != "":
			if anim.current_animation != sc:
				_play(sc, 0.12)
			anim.speed_scale = 1.0
			return
	# pulo: sobe / cai / pousa (clip curto e volta ao normal)
	var air := entity.airborne()
	if _was_air and not air:
		_land_t = 0.16
	_was_air = air
	_land_t = maxf(0.0, _land_t - _dt)
	var base := "idle"
	if air and st in [SimEntity.State.IDLE, SimEntity.State.MOVING, SimEntity.State.DASHING]:
		base = "jump" if entity.jump_v > 0.0 else "fall"
		if _clip(base) == "":
			base = "run"
	elif _land_t > 0.0 and st in [SimEntity.State.IDLE, SimEntity.State.MOVING] and _clip("land") != "":
		base = "land"
	match st if base == "idle" else -1:
		SimEntity.State.MOVING: base = "run"
		SimEntity.State.BLOCKING:
			base = "block_shield" if entity.stats.has_shield and _clip("block_shield") != "" else "block"
			if horse and base == "block_shield" and _clip(RidePose.GUARD_CLIP) != "":
				base = RidePose.GUARD_CLIP      # Muralha a Cavalo: escudo acima do pescoço do cavalo
		SimEntity.State.DASHING: base = "dash" if anim.has_animation("dash") else "run"
		SimEntity.State.STUNNED: base = "hit"
		SimEntity.State.IDLE, SimEntity.State.MOVING:
			if _flinch > 0.0 and _clip("hit") != "":
				base = "hit"
		SimEntity.State.DEAD: base = "die"
	base = _sig_base(base)
	var want := _clip(base)
	if kit and form_view == null and kit.tall_clip(base) != "":
		want = kit.tall_clip(base)           # escudo alto: corrida de braço quieto e guarda mais baixa (KitModel.TALL_CLIPS)
	# idle próprio da arma: arco baixo na mão esquerda, cajado/varinha/foice em pé
	if base == "idle":
		var w := entity.stats.weapon_type if entity.stats else ""
		var fam := "bow" if w == "bow" else ("staff" if w in ["staff", "wand", "scythe", "scepter"] else "")
		if fam != "" and _clip("idle_" + fam) != "":
			want = _clip("idle_" + fam)
	if want == "":
		want = _clip("idle")
	if want != "" and anim.current_animation != want:
		_play(want, 0.07 if base.begins_with("block") else 0.12)      # erguer a guarda é rápido: é reação
	# corrida no ritmo da velocidade real (sem pé deslizando); o resto em velocidade normal
	anim.speed_scale = clampf(entity.velocity.length() / RUN_REF_SPEED, 0.38 if entity.kind == SimEntity.Kind.NPC else 0.6, 1.7) if base == "run" else 1.0
	if st == SimEntity.State.DEAD and base == "die" and anim.current_animation_position >= anim.current_animation_length - 0.01:
		anim.pause()
