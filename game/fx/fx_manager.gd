class_name FxManager
extends Node3D
## Efeitos visuais lidos do EventBus: dano flutuante, hit-stop, anéis de skill, projéteis, loot, retículo.

var camera: CameraRig
var main                          # Main (para saber o mapa atual)
var _projectiles: Dictionary = {}   # id -> Node3D
var _loot_nodes: Array = []
var _hit_stop_left := 0.0
var reticle: MeshInstance3D
var dir_reticle: MeshInstance3D
var cone_reticle: MeshInstance3D
var _reticle_shader: Shader

var show_reticle := true      # bancada de skills desliga (o cursor do mouse não interessa nas fotos)

func _ready() -> void:
	_reticle_shader = load("res://shaders/ground_reticle.gdshader")
	reticle = _make_reticle(0)
	dir_reticle = _make_reticle(1)
	cone_reticle = _make_reticle(2)
	Events.damage_dealt.connect(_on_damage)
	Events.healed.connect(_on_heal)
	Events.hit_stop.connect(_on_hit_stop)
	Events.skill_effect.connect(_on_skill_effect)
	Events.projectile_spawned.connect(_on_projectile)
	Events.projectile_removed.connect(_on_projectile_removed)
	Events.loot_dropped.connect(_on_loot)
	Events.monster_emerged.connect(_on_emerged)
	Events.trap_placed.connect(_on_trap_placed)
	Events.dodged.connect(_on_dodged)
	Events.trap_removed.connect(_on_trap_removed)
	Events.level_up.connect(_on_level_up)
	Events.blocked_hit.connect(_on_block)
	Events.shield_block.connect(_on_shield_block)
	Events.guard_flanked.connect(_on_guard_flanked)
	Events.skill_cast.connect(_on_skill_cast)
	Events.entity_died.connect(_on_died)
	Events.buff_applied.connect(_on_buff)

func _make_reticle(shape: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(2, 2)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = _reticle_shader
	m.set_shader_parameter("shape", shape)
	mi.material_override = m
	mi.visible = false
	mi.position.y = 0.03
	add_child(mi)
	return mi

# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if _hit_stop_left > 0.0:
		_hit_stop_left -= delta / maxf(Engine.time_scale, 0.01)
		if _hit_stop_left <= 0.0:
			Engine.time_scale = 1.0
	_update_projectiles(delta)
	if show_reticle:
		_update_reticle()
	else:
		reticle.visible = false; dir_reticle.visible = false; cone_reticle.visible = false
	_update_loot(delta)

## Retículo de mira estilo MOBA: mostra alcance/forma da skill cujo número está sendo segurado,
## senão um pequeno cursor no chão.
func _update_reticle() -> void:
	var p: SimEntity = Sim.player
	if p == null or main == null or main.controller == null:
		return
	var aim: Vector3 = main.controller.aim_point
	var held: SkillDef = null
	for i in range(6):
		if Input.is_action_pressed("skill_%d" % (i + 1)) and i < p.skills.size():
			held = p.skills[i]
	if held == null and p.state == SimEntity.State.CASTING and p.current_skill and p.current_skill_slot >= 0:
		held = p.current_skill
	reticle.visible = false
	dir_reticle.visible = false
	cone_reticle.visible = false
	if held == null:
		reticle.visible = true
		reticle.position = Vector3(aim.x, 0.03, aim.z)
		reticle.scale = Vector3(0.35, 1, 0.35)
		reticle.material_override.set_shader_parameter("color", Color(1, 1, 1, 0.5))
		return
	var col := held.icon_color
	col.a = 0.85
	match held.target:
		SkillDef.Target.GROUND:
			var c := Combat.clamp_aim(p, aim, held.range)
			reticle.visible = true
			reticle.position = Vector3(c.x, 0.03, c.z)
			reticle.scale = Vector3(held.radius, 1, held.radius)
			reticle.material_override.set_shader_parameter("color", col)
		SkillDef.Target.DIRECTION:
			dir_reticle.visible = true
			var f := p.forward()
			dir_reticle.position = p.position + f * held.range * 0.5 + Vector3(0, 0.03, 0)
			dir_reticle.rotation.y = p.facing
			dir_reticle.scale = Vector3(maxf(held.radius, 0.35), 1, held.range * 0.5)
			dir_reticle.material_override.set_shader_parameter("color", col)
		SkillDef.Target.CONE:
			cone_reticle.visible = true
			cone_reticle.position = p.position + Vector3(0, 0.03, 0)
			cone_reticle.rotation.y = p.facing + PI
			cone_reticle.scale = Vector3(held.radius, 1, held.radius)
			cone_reticle.material_override.set_shader_parameter("color", col)
		SkillDef.Target.SELF:
			reticle.visible = true
			reticle.position = p.position + Vector3(0, 0.03, 0)
			reticle.scale = Vector3(maxf(held.radius, 1.0), 1, maxf(held.radius, 1.0))
			reticle.material_override.set_shader_parameter("color", col)
		SkillDef.Target.TARGET:
			reticle.visible = true
			reticle.position = Vector3(aim.x, 0.03, aim.z)
			reticle.scale = Vector3(0.9, 1, 0.9)
			reticle.material_override.set_shader_parameter("color", col)

# ---------------------------------------------------------------------------
func _on_damage(attacker_id: int, target_id: int, amount: int, crit: bool, blocked: bool, kind: String) -> void:
	var t: SimEntity = Sim.get_entity(target_id)
	if t == null or t.map_id != main.current_map_id:
		return
	var col := Color(1, 0.95, 0.85)
	if kind == "magical":
		col = Color(0.7, 0.8, 1)
	if kind == "dot":
		col = Color(0.6, 0.95, 0.5)
	if kind == "dot_fire":                 # queimadura
		col = Color(1.0, 0.62, 0.25)
	if t == Sim.player:
		col = Color(1, 0.4, 0.4)
	var txt := str(amount)
	var size := 1.0
	if kind == "echo":                     # arma lendária: golpe que ecoa
		col = Color(1.0, 0.72, 0.3)
		txt = "✦" + txt
	if kind in ["thorns", "riposte"]:      # arma lendária: dano devolvido / contra-ataque
		col = Color(0.95, 0.55, 0.4)
	if kind == "chain":                    # Arco Voltaico
		col = Color(0.75, 0.75, 1.0)
		txt = "⚡" + txt
	if kind == "splash":                   # Pólvora
		col = Color(1.0, 0.6, 0.3)
	if kind == "shatter":                  # gelo em alvo retardado/preso: estilhaço
		col = Color(0.55, 0.95, 1.0)
		txt = "❄" + txt
		size = 1.3
	if crit:
		txt += "!"
		size = 1.6
		col = Color(1, 0.75, 0.2) if t != Sim.player else Color(1, 0.3, 0.3)
	if blocked:
		txt = "⛨ " + txt
		col = Color(0.75, 0.8, 1)
	_float_text(t.position + Vector3(randf_range(-0.3, 0.3), 1.6 * t.scale, 0), txt, col, size)
	# flash na câmera quando o jogador leva dano forte
	if t == Sim.player and amount > t.stats.max_hp * 0.12:
		camera.add_shake(0.12)

func _on_heal(_src: int, target_id: int, amount: int) -> void:
	var t: SimEntity = Sim.get_entity(target_id)
	if t and t.map_id == main.current_map_id and amount > 0:
		_float_text(t.position + Vector3(0, 1.7 * t.scale, 0), "+%d" % amount, Color(0.5, 1, 0.5), 1.1)
		SkillFx.burst(self, t.position + Vector3(0, 0.3, 0), "heal", 14, Vector3.UP, 0.35)

func _on_block(target_id: int) -> void:
	var t: SimEntity = Sim.get_entity(target_id)
	if t and t.map_id == main.current_map_id:
		_ring(t.position + Vector3(0, 0.8, 0), 0.6, Color(0.7, 0.8, 1), 0.25, true)

## Golpe por fora do arco: o jogador precisa saber por que a guarda não segurou.
func _on_guard_flanked(target_id: int) -> void:
	var t: SimEntity = Sim.get_entity(target_id)
	if t and t.map_id == main.current_map_id and t == Sim.player:
		_float_text(t.position + Vector3(0, 2.6 * t.scale, 0), "FLANQUEADO!", Color(1.0, 0.45, 0.3), 1.2)

## Impacto no escudo: leque na direção do golpe e faíscas na cor do escudo; aparar acende em dourado e congela um instante.
func _on_shield_block(target_id: int, attacker_id: int, theme: String, parried: bool, from: Vector3) -> void:
	var t: SimEntity = Sim.get_entity(target_id)
	var a: SimEntity = Sim.get_entity(attacker_id)
	if t == null or t.map_id != main.current_map_id:
		return
	var d := from - t.position     # origem do golpe (projétil, área, investida), não onde o atacante está agora
	d.y = 0.0
	var dir: Vector3 = d.normalized() if d.length() > 0.01 else t.forward()
	var at := t.position + dir * 0.75 + Vector3(0, 0.85, 0)
	var th := "holy" if parried else theme
	SkillFx.sector(self, t.position + Vector3(0, 0.1, 0), dir, 3.0 if parried else 2.1, 160.0 if parried else 120.0, th, 0.34)
	SkillFx.burst(self, at, th, 70 if parried else 34, dir + Vector3.UP * 0.5, 0.35)
	SkillFx.flash(self, at, th, 6.0 if parried else 3.0, 8.0 if parried else 5.0)
	_ring(t.position + Vector3(0, 0.15, 0), 2.6 if parried else 1.6, SkillFx.col(th), 0.35)
	if parried:
		_ring(at, 1.5, Color(1.0, 0.9, 0.5), 0.35, true)
		SkillFx.slash_x(self, at, "holy", 2.0)
		_float_text(t.position + Vector3(0, 3.0 * t.scale, 0), "APARADO!", Color(1.0, 0.86, 0.3), 1.6)
		if t == Sim.player or a == Sim.player:
			_on_hit_stop(5)

func _on_hit_stop(frames: int) -> void:
	Engine.time_scale = 0.05
	_hit_stop_left = frames / 60.0
	camera.add_shake(0.03 * frames)

## Efeito da skill pelo TEMA (SkillDef.vfx) e na FORMA real da hitbox (SkillFx).
func _on_skill_effect(skill_id: String, origin: Vector3, aim: Vector3, radius: float) -> void:
	var s: SkillDef = GameData.skills.get(skill_id)
	if s == null:
		return
	var th := s.vfx if s.vfx != "" else "physical"
	var dir := aim - origin
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	match s.target:
		SkillDef.Target.GROUND:
			_ground_impact(s, th, aim, radius)
		SkillDef.Target.SELF:
			if s.kind == SkillDef.Kind.BUFF or s.kind == SkillDef.Kind.HEAL or s.effects.has("shield"):
				SkillFx.burst(self, origin + Vector3(0, 0.8, 0), th, 18, Vector3.UP, 0.4)
				if s.kind == SkillDef.Kind.HEAL and radius > 2.0:
					SkillFx.circle(self, origin, radius, th, 0.6)
			else:
				# golpe em volta de si (giro, nova, provocar): aro que abre até o raio real + partículas em anel
				SkillFx.circle(self, origin, maxf(radius, 1.0), th, 0.5)
				SkillFx.burst(self, origin + Vector3(0, 0.5, 0), th, 30, Vector3.UP, maxf(radius, 1.0) * 0.6)
				if s.kind == SkillDef.Kind.PHYSICAL:
					SkillFx.sector(self, origin, dir, maxf(radius, 1.0) * 0.9, 360.0, th, 0.3)
				else:
					SkillFx.flash(self, origin + Vector3(0, 1, 0), th, 1.8, maxf(radius, 1.0) * 1.6)
		SkillDef.Target.CONE:
			SkillFx.sector(self, origin, dir, radius, s.cone_angle_deg, th, 0.32)
			SkillFx.burst(self, origin + dir * radius * 0.7 + Vector3(0, 0.6, 0), th, 18, dir + Vector3.UP * 0.4, 0.4)
		SkillDef.Target.DIRECTION:
			if s.effects.has("dash"):
				var path := Vector2(aim.x - origin.x, aim.z - origin.z).length()    # investida barrada desenha só o que andou
				SkillFx.streak(self, origin, dir, minf(path, float(s.effects["dash"])), th)
				SkillFx.decal_line(self, origin, dir, path, s.radius * 2.0, th, 0.45)
			elif s.projectile_speed <= 0.0:
				SkillFx.wave(self, origin, dir, s.range, maxf(s.radius * 2.0, 0.6), th, 0.35)
		SkillDef.Target.TARGET:
			if s.kind == SkillDef.Kind.HEAL or s.kind == SkillDef.Kind.BUFF:
				SkillFx.column(self, aim, 0.7, th, 0.55)
				SkillFx.burst(self, aim + Vector3(0, 0.4, 0), th, 18, Vector3.UP, 0.4)
			else:
				if s.kind == SkillDef.Kind.PHYSICAL:
					SkillFx.slash_x(self, aim, th, 1.5)
				SkillFx.burst(self, aim + Vector3(0, 0.8, 0), th, 22, Vector3.UP, 0.3)
				if th == "lightning":
					# raio sai da mão até o alvo e, se a skill acerta vários, pula pros vizinhos
					var hand := origin + Vector3(0, 1.0, 0) + dir * 0.4
					var prev := aim + Vector3(0, 0.8, 0)
					SkillFx.arc_bolt(self, hand, prev)
					SkillFx.flash(self, prev, th, 2.0)
					if s.max_targets > 1:
						var hops := 0
						for o in Sim.map_entities(main.current_map_id):
							if hops >= mini(s.max_targets - 1, 4) or not o.is_alive() or o.kind != SimEntity.Kind.MONSTER:
								continue
							var op: Vector3 = o.position + Vector3(0, 0.8, 0)
							if op.distance_to(prev) > 0.6 and op.distance_to(aim) < maxf(s.radius, 5.0):
								SkillFx.arc_bolt(self, prev, op)
								prev = op
								hops += 1
				elif th in ["holy", "lunar"] and s.kind != SkillDef.Kind.PHYSICAL:
					SkillFx.column(self, aim, 0.6, th, 0.45)
				if s.radius > 1.0:
					SkillFx.circle(self, aim, s.radius, th, 0.45)

## Impacto no chão por tema (o círculo sempre tem o raio real).
func _ground_impact(s: SkillDef, th: String, at: Vector3, radius: float) -> void:
	SkillFx.circle(self, at, radius, th, 0.6)
	match th:
		"fire":
			if "meteor" in s.id or "phoenix" in s.id:
				pass     # a queda começou na preparação (_on_skill_cast) e explode exatamente agora
			else:
				SkillFx.explosion(self, at, radius, th)
		"lightning":
			SkillFx.bolt(self, at)
			SkillFx.burst(self, at + Vector3(0, 0.2, 0), th, 24, Vector3.UP, radius * 0.4)
		"holy", "lunar":
			SkillFx.column(self, at, radius * 0.55, th, 0.6)
			SkillFx.burst(self, at + Vector3(0, 0.3, 0), th, 26, Vector3.UP, radius * 0.4)
		"ice":
			SkillFx.burst(self, at + Vector3(0, 2.5, 0), th, 30, Vector3.DOWN, radius * 0.5, 1.2)
			SkillFx.burst(self, at + Vector3(0, 0.2, 0), th, 18, Vector3.UP, radius * 0.4)
		"earth":
			SkillFx.burst(self, at + Vector3(0, 0.1, 0), th, 30, Vector3.UP, radius * 0.45, 1.3)
			camera.add_shake(0.12)
		_:
			SkillFx.burst(self, at + Vector3(0, 0.3, 0), th, 30, Vector3.UP, radius * 0.45)

func _on_skill_cast(entity_id: int, skill_id: String, phase: String) -> void:
	if phase != "startup":
		return
	var e: SimEntity = Sim.get_entity(entity_id)
	if e == null or e.map_id != main.current_map_id or skill_id == "dash" or skill_id == "jump":
		return
	var s: SkillDef = GameData.skills.get(skill_id)
	# meteoro: começa a cair já na preparação, pra chegar no chão no instante do dano
	if s and s.target == SkillDef.Target.GROUND and s.vfx == "fire" and ("meteor" in s.id or "phoenix" in s.id):
		SkillFx.meteor(self, e.skill_aim, s.radius, s.vfx, maxf(0.15, s.startup))
	# preparação: magia junta energia do tema nas mãos; golpe lento mostra o aro de aviso
	if s and s.kind != SkillDef.Kind.PHYSICAL and s.startup >= 0.2:
		SkillFx.gather(self, e.position + Vector3(0, 1.0, 0) + e.forward() * 0.35, s.vfx, s.startup)
	elif s and s.startup >= 0.3 and e.kind != SimEntity.Kind.MONSTER:
		_ring(e.position, 0.7, SkillFx.col(s.vfx), s.startup, false, true)
	if s and e.kind == SimEntity.Kind.MONSTER and s.startup >= 0.25 and s.kind != SkillDef.Kind.BUFF:
		_telegraph(e, s)

## Aviso de golpe de monstro: a área de verdade (círculo no chão, cone na frente, faixa da investida) em vermelho,
## enchendo do centro para a borda até o instante do impacto. Chefe: borda mais grossa.
func _telegraph(e: SimEntity, s: SkillDef) -> void:
	var col := Color(1.0, 0.25, 0.18, 0.32)
	var dur := maxf(0.2, s.startup)
	var root := Node3D.new()
	add_child(root)
	var outline: MeshInstance3D
	var fill: MeshInstance3D
	match s.target:
		SkillDef.Target.CONE:
			root.position = e.position + Vector3(0, 0.05, 0)
			root.rotation.y = e.facing
			outline = _fan(s.radius, deg_to_rad(s.cone_angle_deg), col)
			fill = _fan(s.radius, deg_to_rad(s.cone_angle_deg), Color(col.r, col.g, col.b, 0.42))
		SkillDef.Target.DIRECTION:
			var length := float(s.effects.get("dash", s.range))
			var w := maxf(1.2, s.radius * 2.0)
			root.position = e.position + Vector3(0, 0.05, 0)
			root.rotation.y = e.facing
			outline = _strip(length, w, col)
			fill = _strip(length, w, Color(col.r, col.g, col.b, 0.42))
		_:
			var r := s.radius if s.radius > 0.0 else 1.6
			root.position = (e.skill_aim if s.target == SkillDef.Target.GROUND else e.position) + Vector3(0, 0.05, 0)
			outline = _disc(r, col)
			fill = _disc(r, Color(col.r, col.g, col.b, 0.42))
	root.add_child(outline)
	root.add_child(fill)
	fill.position.y = 0.01
	fill.scale = Vector3(0.05, 1, 0.05) if s.target != SkillDef.Target.DIRECTION else Vector3(1, 1, 0.05)
	if e.monster_def and e.monster_def.is_boss:
		outline.scale = Vector3.ONE * 1.04
	var tw := create_tween()
	tw.tween_property(fill, "scale", Vector3.ONE, dur)
	tw.tween_callback(root.queue_free)

func _flat_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_fog = true
	return m

func _disc(r: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.02
	cm.radial_segments = 32
	mi.mesh = cm
	mi.material_override = _flat_mat(col)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## Leque no chão apontando para +z local (frente do monstro).
func _fan(r: float, angle: float, col: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 20
	for i in range(n):
		var a0 := -angle * 0.5 + angle * i / n
		var a1 := -angle * 0.5 + angle * (i + 1) / n
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(sin(a0) * r, 0, cos(a0) * r))
		st.add_vertex(Vector3(sin(a1) * r, 0, cos(a1) * r))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _flat_mat(col)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## Faixa da investida: começa no monstro e vai `length` para a frente.
func _strip(length: float, w: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, 0.02, length)
	mi.mesh = bm
	mi.material_override = _flat_mat(col)
	mi.position.z = length * 0.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var holder := MeshInstance3D.new()
	holder.add_child(mi)
	return holder

## Buff/escudo: aura no pé de quem recebe, pelo tempo do buff (tema da skill que deu o buff, se houver).
func _on_buff(entity_id: int, buff_id: String, duration: float) -> void:
	var e: SimEntity = Sim.get_entity(entity_id)
	if e == null or e.map_id != main.current_map_id or not main.views.has(entity_id):
		return
	if buff_id.begins_with("form_"):
		_transform_fx(e, buff_id.substr(5))
		return
	var th := "holy"
	for sid in GameData.skills:
		var s: SkillDef = GameData.skills[sid]
		if s.effects.get("buff", {}).get("id", "") == buff_id or sid == buff_id:
			th = s.vfx
			break
	if buff_id == "shield":
		th = "holy" if e.class_def == null or e.class_def.id != "necromancer" else "bone"
	if buff_id != "juramento":         # acumula a cada bloqueio: o HUD já mostra as cargas
		SkillFx.aura(self, main.views[entity_id], th, duration, 0.75 * e.scale)

## Transformação (liga ou desliga uma forma): estouro de partículas, coluna de luz e clarão no tema da forma
## (fantasma = névoa lunar, demônio = fogo, lobo/urso = natureza). O aperto/estouro do boneco é da EntityView._morph.
const FORM_FX_THEME := {"phantom": "lunar", "demon": "fire", "wolf": "nature", "bear": "nature"}

var _last_form: Dictionary = {}       # id -> forma de onde está saindo (o desligar usa o tema dela)

func _transform_fx(e: SimEntity, form: String) -> void:
	var leaving := form == "human"
	var was: String = _last_form.get(e.id, "")
	_last_form[e.id] = "" if leaving else form
	var th: String = FORM_FX_THEME.get(was if leaving else form, "lunar")
	var s := e.scale
	var mid := e.position + Vector3(0, 0.9 * s, 0)
	SkillFx.burst(self, mid, th, 20 if leaving else 34, Vector3.UP, 0.35 * s, s)
	if not leaving and form != "phantom":         # troca de modelo (bicho/demônio): a coluna esconde o estalo
		SkillFx.column(self, e.position, 0.55 * s, th, 0.35)
	SkillFx.flash(self, mid, th, 1.6, 4.0)
	_ring(e.position, 1.1 * s, SkillFx.col(th, 0), 0.45, false, false)

func _on_died(entity_id: int, _killer: int) -> void:
	var e: SimEntity = Sim.get_entity(entity_id)
	if e and e.map_id == main.current_map_id:
		_ring(e.position, 0.8 * e.scale, Color(0.3, 0.25, 0.35), 0.6)

func _on_level_up(entity_id: int, new_level: int) -> void:
	var e: SimEntity = Sim.get_entity(entity_id)
	if e and e.map_id == main.current_map_id:
		_float_text(e.position + Vector3(0, 2.2, 0), "LEVEL %d!" % new_level, Color(1, 0.9, 0.3), 1.8)
		_pillar(e.position, 0.8, Color(1, 0.9, 0.3), 1.2)

# ---------------------------------------------------------------------------
func _float_text(pos: Vector3, text: String, color: Color, size: float = 1.0) -> void:
	var l := Label3D.new()
	l.text = text
	l.modulate = color
	l.outline_size = 14
	l.font_size = int(44 * size)
	l.pixel_size = 0.012
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos
	add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position", pos + Vector3(randf_range(-0.4, 0.4), 1.4, 0), 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tw.tween_property(l, "scale", Vector3.ONE * 0.6, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)

func _ring(pos: Vector3, radius: float, color: Color, duration: float, raised: bool = false, shrink: bool = false) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.8
	tm.outer_radius = 1.0
	tm.rings = 20
	tm.ring_segments = 5
	mi.mesh = tm
	mi.material_override = Materials.glow(color, 2.0)
	mi.position = pos + Vector3(0, 0.08 if not raised else 0.0, 0)
	mi.scale = Vector3.ONE * (0.2 if not shrink else radius * 2.0)
	add_child(mi)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 0.4, radius) if not shrink else Vector3.ONE * 0.3, duration).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi.material_override, "albedo_color:a", 0.0, duration)
	tw.chain().tween_callback(mi.queue_free)

func _pillar(pos: Vector3, radius: float, color: Color, duration: float) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 4.0
	cm.radial_segments = 10
	mi.mesh = cm
	var m := Materials.glow(color, 1.5)
	m.albedo_color.a = 0.55
	mi.material_override = m
	mi.position = pos + Vector3(0, 2.0, 0)
	add_child(mi)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(0.1, 1.3, 0.1), duration).set_ease(Tween.EASE_IN)
	tw.tween_property(m, "albedo_color:a", 0.0, duration)
	tw.chain().tween_callback(mi.queue_free)

func _arc(pos: Vector3, radius: float, color: Color, duration: float) -> void:
	var p: SimEntity = Sim.player
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.08
	cm.radial_segments = 14
	mi.mesh = cm
	var m := Materials.glow(color, 1.5)
	m.albedo_color.a = 0.35
	mi.material_override = m
	mi.position = pos + Vector3(0, 0.3, 0)
	mi.scale = Vector3(0.3, 1, 0.3)
	add_child(mi)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(1, 1, 1), duration).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, duration)
	tw.chain().tween_callback(mi.queue_free)

func _beam(origin: Vector3, aim: Vector3, length: float, color: Color, duration: float) -> void:
	var d := aim - origin
	d.y = 0.0
	if d.length() < 0.01:
		return
	var dir := d.normalized()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.35, 0.35, length)
	mi.mesh = bm
	var m := Materials.glow(color, 2.5)
	m.albedo_color.a = 0.8
	mi.material_override = m
	mi.position = origin + dir * length * 0.5 + Vector3(0, 0.9, 0)
	mi.rotation.y = atan2(dir.x, dir.z)
	add_child(mi)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(0.1, 0.1, 1.0), duration)
	tw.tween_property(m, "albedo_color:a", 0.0, duration)
	tw.chain().tween_callback(mi.queue_free)

# ---------------------------------------------------------------------------
func _on_projectile(p: SimProjectile) -> void:
	if p.map_id != main.current_map_id:
		return
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = maxf(p.radius * 0.6, 0.15)
	sm.height = sm.radius * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	mi.mesh = sm
	var th := p.skill.vfx if p.skill and p.skill.vfx != "" else ""
	var pcol: Color = SkillFx.col(th, 0) if th != "" else p.color
	mi.material_override = Materials.glow(pcol, 2.5)
	n.add_child(mi)
	# físico: flecha (dono com arco) ou lâmina girando (arremesso), em vez da bola de energia
	var owner: SimEntity = Sim.get_entity(p.owner_id)
	if th in ["physical", "blood", "earth", "bone"] or (owner and owner.stats and owner.stats.weapon_type == "bow" and th in ["", "physical"]):
		if owner and owner.stats and owner.stats.weapon_type == "bow":
			var shaft := BoxMesh.new()
			shaft.size = Vector3(0.06, 0.06, 0.9)
			mi.mesh = shaft
			mi.material_override = Materials.toon(Color(0.55, 0.4, 0.25), false)
			var tip := MeshInstance3D.new()
			var tipm := PrismMesh.new()
			tipm.size = Vector3(0.14, 0.2, 0.06)
			tip.mesh = tipm
			tip.rotation.x = PI * 0.5
			tip.position.z = 0.5
			tip.material_override = Materials.toon(Color(0.85, 0.85, 0.9), false)
			mi.add_child(tip)
		else:
			var disc := CylinderMesh.new()
			disc.top_radius = maxf(p.radius, 0.35)
			disc.bottom_radius = maxf(p.radius, 0.35)
			disc.height = 0.05
			disc.radial_segments = 10
			mi.mesh = disc
			mi.material_override = Materials.glow(SkillFx.col(th if th != "" else "physical", 1), 1.2)
			mi.rotation.z = 0.35
			mi.set_meta("spin", true)
	if th != "" and not p.is_basic:
		var trail_p := CPUParticles3D.new()
		trail_p.amount = 24
		trail_p.lifetime = 0.35
		trail_p.local_coords = false
		trail_p.gravity = Vector3(0, float(SkillFx.PARTS.get(th, {}).get("g", 0.0)) * 0.3, 0)
		trail_p.initial_velocity_min = 0.0
		trail_p.initial_velocity_max = 0.4
		trail_p.spread = 180.0
		var tq := QuadMesh.new()
		tq.size = Vector2(sm.radius * 1.2, sm.radius * 1.2)
		trail_p.mesh = tq
		var tg := Gradient.new()
		tg.set_color(0, SkillFx.col(th, 1))
		tg.set_color(1, Color(pcol, 0.0))
		trail_p.color_ramp = tg
		var tpm := SkillFx._mat(Color.WHITE)
		tpm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		tpm.albedo_texture = SkillFx.soft()
		trail_p.material_override = tpm
		n.add_child(trail_p)
	if th == "" or p.is_basic:
		var trail := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = sm.radius * 0.6
		tm.bottom_radius = 0.0
		tm.height = 1.2
		tm.radial_segments = 6
		trail.mesh = tm
		trail.rotation.x = PI * 0.5
		trail.position.z = -0.6         # atrás do projétil (ele anda pra +z local)
		var trm := Materials.glow(pcol, 1.5)
		trm.albedo_color.a = 0.5
		trail.material_override = trm
		n.add_child(trail)
	var light := OmniLight3D.new()
	light.light_color = pcol
	light.light_energy = 1.0
	light.omni_range = 3.0
	n.add_child(light)
	n.set_meta("vfx", th)
	n.set_meta("radius", p.skill.radius if p.skill else 0.5)
	n.position = p.position
	n.rotation.y = atan2(p.direction.x, p.direction.z)
	add_child(n)
	_projectiles[p.id] = n

func _on_projectile_removed(id: int) -> void:
	if _projectiles.has(id):
		var n: Node3D = _projectiles[id]
		_projectiles.erase(id)
		var th: String = n.get_meta("vfx", "")
		if th == "":
			_ring(n.position - Vector3(0, 0.8, 0), 0.6, Color(1, 1, 1, 0.8), 0.25)
		elif th == "fire":
			SkillFx.explosion(self, n.position - Vector3(0, 0.8, 0), maxf(1.6, float(n.get_meta("radius", 0.5)) * 2.0), th)
		else:
			SkillFx.burst(self, n.position, th, 22, Vector3.UP, 0.3)
			SkillFx.flash(self, n.position, th, 1.5, 3.0)
		n.queue_free()

func _update_projectiles(_delta: float) -> void:
	if main == null or not Sim.maps.has(main.current_map_id):
		return
	for p in Sim.maps[main.current_map_id]["projectiles"]:
		if _projectiles.has(p.id):
			var pn: Node3D = _projectiles[p.id]
			pn.position = p.position
			var body := pn.get_child(0) as Node3D
			if body and body.has_meta("spin"):
				body.rotate_y(_delta * 22.0)          # lâmina arremessada gira

# ---------------------------------------------------------------------------
# Armadilhas do Ranger: marca no chão (anel da área + a peça), pulso enquanto arma, estouro quando disparam
var _traps := {}            # id -> Node3D
const TRAP_LOOK := {"jaw": [Color(0.85, 0.7, 0.45), "physical"], "mine": [Color(1.0, 0.45, 0.2), "fire"], "frost": [Color(0.55, 0.85, 1.0), "ice"]}

func _on_trap_placed(id: int, kind: String, pos: Vector3, radius: float, map_id: String) -> void:
	if map_id != main.current_map_id:
		return
	var look: Array = TRAP_LOOK.get(kind, TRAP_LOOK["jaw"])
	var col: Color = look[0]
	var n := Node3D.new()
	n.position = pos
	n.set_meta("theme", look[1])
	add_child(n)
	_traps[id] = n
	var ring := MeshInstance3D.new()          # área de efeito, discreta
	var tm := TorusMesh.new()
	tm.inner_radius = 0.93
	tm.outer_radius = 1.0
	tm.rings = 24
	tm.ring_segments = 4
	ring.mesh = tm
	ring.material_override = Materials.glow(Color(col, 0.55), 1.2)
	ring.scale = Vector3(radius, 0.3, radius)
	ring.position.y = 0.04
	n.add_child(ring)
	match kind:
		"jaw":                                 # duas mandíbulas de ferro abertas
			for sx in [-1.0, 1.0]:
				var jaw := MeshInstance3D.new()
				var jm := TorusMesh.new()
				jm.inner_radius = 0.28
				jm.outer_radius = 0.36
				jaw.mesh = jm
				jaw.material_override = Materials.toon(Color(0.5, 0.5, 0.55))
				jaw.rotation = Vector3(0, 0, sx * 0.9)
				jaw.position = Vector3(sx * 0.12, 0.1, 0)
				n.add_child(jaw)
			var plate := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.16
			cm.bottom_radius = 0.18
			cm.height = 0.06
			plate.mesh = cm
			plate.material_override = Materials.toon(col)
			plate.position.y = 0.04
			n.add_child(plate)
		"mine":                                # disco escuro com luz vermelha piscando
			var body := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.26
			cm.bottom_radius = 0.3
			cm.height = 0.12
			body.mesh = cm
			body.material_override = Materials.toon(Color(0.22, 0.22, 0.26))
			body.position.y = 0.06
			n.add_child(body)
			var lamp := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.07
			sm.height = 0.14
			lamp.mesh = sm
			lamp.material_override = Materials.glow(Color(1, 0.2, 0.15), 2.5)
			lamp.position.y = 0.15
			n.add_child(lamp)
			var tw := create_tween().set_loops()
			tw.tween_property(lamp, "scale", Vector3.ONE * 1.5, 0.35)
			tw.tween_property(lamp, "scale", Vector3.ONE, 0.35)
			n.tree_exiting.connect(tw.kill)
		_:                                     # gelo: cristal de pé
			var crystal := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(0.3, 0.55, 0.3)
			crystal.mesh = pm
			crystal.material_override = Materials.glow(col, 1.4)
			crystal.position.y = 0.28
			n.add_child(crystal)
	_ring(pos, radius, col, 0.6, false, true)      # pulso enquanto arma

func _on_trap_removed(id: int, triggered: bool) -> void:
	var n: Node3D = _traps.get(id)
	if n == null:
		return
	_traps.erase(id)
	if triggered:
		var theme: String = n.get_meta("theme", "physical")
		SkillFx.burst(self, n.position + Vector3(0, 0.3, 0), theme, 40, Vector3.UP, 0.4)
		SkillFx.flash(self, n.position + Vector3(0, 0.5, 0), theme, 3.0, 4.0)
	n.queue_free()

func _on_dodged(id: int) -> void:
	var t: SimEntity = Sim.get_entity(id)
	if t and t.map_id == main.current_map_id:
		_float_text(t.position + Vector3(0, 2.4 * t.scale, 0), "Esquiva!", Color(0.75, 0.9, 1.0), 1.0)

func sync_traps_for_map() -> void:
	for id in _traps:
		_traps[id].queue_free()
	_traps.clear()
	if not Sim.maps.has(main.current_map_id):
		return
	for t in Sim.maps[main.current_map_id].get("traps", []):
		_on_trap_placed(t["id"], t["kind"], t["pos"], t["radius"], main.current_map_id)

func clear_map_fx() -> void:
	for id in _projectiles:
		_projectiles[id].queue_free()
	_projectiles.clear()
	for l in _loot_nodes:
		l.queue_free()
	_loot_nodes.clear()

# ---------------------------------------------------------------------------
## Chefe saindo da água: anéis de respingo na beira do lago.
func _on_emerged(map_id: String, position: Vector3) -> void:
	if main == null or map_id != main.current_map_id:
		return
	for k in range(3):
		_ring(position, 1.2 + k * 1.1, Color(0.7, 0.88, 1.0, 0.85 - k * 0.2), 0.7 + k * 0.25, true)

func _on_loot(map_id: String, position: Vector3, item_id: String, count: int) -> void:
	if map_id != main.current_map_id:
		return
	_spawn_loot_node(position, item_id)

func _spawn_loot_node(position: Vector3, item_id: String) -> void:
	var n := LootChest.make(item_id)       # baú de tesouro (ou moedas), malhas compartilhadas
	n.position = position
	n.rotation.y = fposmod(position.x * 7.3 + position.z * 3.1, TAU)     # cada baú virado para um lado
	n.set_meta("item", item_id)
	n.set_meta("origin", position)
	add_child(n)
	_loot_nodes.append(n)

func _update_loot(delta: float) -> void:
	if main == null or not Sim.maps.has(main.current_map_id):
		return
	var loot: Array = Sim.maps[main.current_map_id]["loot"]
	# remove nós cujo loot sumiu (pego ou expirou)
	for n in _loot_nodes.duplicate():
		var found := false
		var origin: Vector3 = n.get_meta("origin")
		var seen := true
		for l in loot:
			if l["pos"].distance_to(origin) < 0.01 and l["item"] == n.get_meta("item"):
				found = true
				seen = Sim.loot_visible_to(Sim.player, l)     # do outro: só aparece quando ficar livre
				break
		n.visible = seen
		if not found:
			_loot_nodes.erase(n)
			n.queue_free()
		else:
			var glow: OmniLight3D = n.get_node_or_null("Glow")
			if glow:                       # brilho pulsando devagar (o baú fica parado no chão)
				glow.light_energy = maxf(0.2, glow.light_energy + sin(Time.get_ticks_msec() / 250.0 + origin.x) * delta * 0.6)
			var icon: Node3D = n.get_node_or_null("Icon")
			if icon:                       # a arte do item boia em cima do baú
				icon.position.y = 1.05 + sin(Time.get_ticks_msec() / 420.0 + origin.x * 1.7) * 0.07

func sync_loot_for_map() -> void:
	clear_map_fx()
	if not Sim.maps.has(main.current_map_id):
		return
	for l in Sim.maps[main.current_map_id]["loot"]:
		_spawn_loot_node(l["pos"], l["item"])
	for p in Sim.maps[main.current_map_id]["projectiles"]:
		_on_projectile(p)
	sync_traps_for_map()
