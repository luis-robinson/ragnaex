extends Node
## Sonda de resposta e fluidez do combate: um personagem nível 30 de cada build, comandado tick a tick (como o jogador),
## contra bonecos parados. Mede o que o jogador sente e o que a tela mostra:
##   godot --headless --path . tools/tests/combat_probe.tscn -- [--class=druid,...] [--verbose]
## Por skill: latência (apertar → golpe sai), trava (quanto tempo sem poder agir), encadear no básico depois do impacto,
## buffer (apertar o básico no meio da skill não se perde), dash cancela, e se o clipe acerta o impacto no tick do dano.
## Por build: cadência do básico segurando o botão (golpes/s, maior buraco parado entre golpes).
## Saída: "PROBE <classe>/<build> ..." e "FLAG <classe> <skill> <motivo>"; no fim "PROBE_END flags=N".

const DT := 1.0 / 60.0
const SPOT := Vector3(40, 0, 40)
const LOCK_SLOW := 1.4          # s sem poder agir depois de apertar (fora canalização): parece travado
const STARTUP_SLOW := 0.7       # s de preparo num golpe/magia comum: o golpe "demora a sair"
const POP_DEG := 140.0          # tranco: giro de osso num quadro (a mistura do AnimationPlayer dava 160-179° no dash; golpe rápido ~130°)
const POP_RATIO := 2.5          # ... e quantas vezes maior que os quadros vizinhos
var p: SimEntity
var view: EntityView
var dummies: Array = []
var flags := 0
var verbose := false

func _ready() -> void:
	await get_tree().process_frame
	Sim.running = false
	verbose = DevArgs.has("--verbose")
	var only: Array = Array(DevArgs.value("--class").split(",")) if DevArgs.flag("--class") else []
	var map_id := GameData.town_map_id()
	Sim.load_map(GameData.maps[map_id])
	for e in Sim.map_entities(map_id).duplicate():
		if e.kind != SimEntity.Kind.NPC:
			Sim.despawn(e)
	Sim.maps[map_id]["spawners"].clear()
	for cid in GameData.classes:
		if not only.is_empty() and not (cid in only):
			continue
		var cls: ClassDef = GameData.classes[cid]
		for b in cls.builds:
			_probe_build(cls, b["id"], map_id)
	print("PROBE_END flags=%d" % flags)
	get_tree().quit()

func _flag(what: String) -> void:
	flags += 1
	print("FLAG " + what)

# ---------------------------------------------------------------------------
func _probe_build(cls: ClassDef, build_id: String, map_id: String) -> void:
	p = Sim.spawn_bot(cls, "Probe", map_id, SPOT, 30)
	if p.build_id != build_id:
		p.build_id = build_id
		Sim._gear_bot(p)
	p.brain = null
	Sim.player = p
	for sid in cls.skill_ids:
		p.learned[sid] = true
	view = EntityView.new()
	view.setup(p, true)
	add_child(view)
	_spawn_dummies(map_id)
	var form := _form_of(cls, build_id)
	if form != "":
		Sim._apply_effects(p, p, {"form": form}, 1.0)
		p.recompute_stats()
	_sync_view()
	var cad := _basic_cadence()
	var tested := 0
	var lat_sum := 0.0
	for sid in cls.skill_ids:
		var s: SkillDef = GameData.skills[sid]
		if s.build != "" and s.build != build_id:
			continue
		if not p.stats.meets(s.requires) or s.effects.has("form"):
			continue
		var r := _probe_skill(s)
		if r.is_empty():
			continue
		tested += 1
		lat_sum += r["latency"]
	_pop_scan(cls, build_id)
	print("PROBE %s/%s%s skills=%d latencia_media=%.1f ticks basico=%.2f golpes/s buraco_max=%d ticks parado_na_tela=%.2fs" % [cls.id, build_id,
		(" (forma " + form + ")") if form != "" else "", tested, lat_sum / maxf(1, tested), cad[0], cad[1], cad[2]])
	if cad[2] > 0.12:
		_flag("%s/%s segurando o ataque, o boneco para %.2fs entre golpes" % [cls.id, build_id, cad[2]])
	view.queue_free()
	await get_tree().process_frame
	for d in dummies:
		Sim.despawn(d)
	dummies.clear()
	Sim.player = null
	Sim.despawn(p)

# ---------------------------------------------------------------------------
# Trancos: sim + desenho andados juntos a 60 Hz; em cada quadro, o maior giro (graus) de um osso desde o quadro anterior.
# Golpe rápido gira muito também; um tranco é um pico isolado na troca de clipe (o quadro de antes e o de depois giram pouco).
var _prev_rot: Array = []
var _hist: Array = []                 # [graus, rótulo] dos últimos quadros
var _pops: Array = []                 # [graus, pico/vizinhos, rótulo, cenário]
var _scene := ""

func _skel() -> Skeleton3D:
	if view.form_view:
		return view.form_view.skeleton
	return view.kit.skeleton if view.kit else null

func _step(c: InputCommand) -> void:
	var before: String = view.anim.current_animation if view.anim else ""
	_tick(c)
	view._process_view(DT)
	var sk := _skel()
	if sk == null:
		return
	var worst := 0.0
	var wb := ""
	var pf := view.pose_fade()
	for i in range(sk.get_bone_count()):
		var q := pf.shown_rotation(sk, i) if pf else sk.get_bone_pose_rotation(i)     # a pose da tela (com o deslize)
		if i < _prev_rot.size():
			var a := rad_to_deg((_prev_rot[i] as Quaternion).angle_to(q))
			if a > worst:
				worst = a
				wb = sk.get_bone_name(i)
			_prev_rot[i] = q
		else:
			_prev_rot.append(q)
	var now: String = view.anim.current_animation if view.anim else ""
	_hist.append([worst, "%s %s->%s" % [wb, before, now] if before != now else "%s %s" % [wb, now]])
	if _hist.size() >= 3:
		var mid: Array = _hist[_hist.size() - 2]
		var side := maxf(1.0, maxf(float(_hist[_hist.size() - 3][0]), float(_hist[_hist.size() - 1][0])))
		_pops.append([float(mid[0]), float(mid[0]) / side, str(mid[1]), _scene])

func _hold(c: InputCommand, secs: float) -> void:
	for i in range(int(secs / DT)):
		_step(c)

func _move_cmd(attack: bool = false, slot: int = -1) -> InputCommand:
	var c := _cmd(slot, attack)
	c.move = Vector2(1, 0)
	return c

func _pop_scan(cls: ClassDef, build_id: String) -> void:
	if view.anim == null or _skel() == null:
		return
	view.manual_anim = true
	view.set_process(false)
	_prev_rot.clear()
	_hist.clear()
	_pops.clear()
	_reset()
	_scene = "parado->basico segurado->solta"
	_hold(InputCommand.new(), 0.4)
	_hold(_cmd(-1, true), 1.6)
	_hold(InputCommand.new(), 0.8)
	_scene = "corre->basico correndo->corre->para"
	_hold(_move_cmd(), 0.6)
	_hold(_move_cmd(true), 1.0)
	_hold(_move_cmd(), 0.6)
	_hold(InputCommand.new(), 0.6)
	var n := 0
	for sid in cls.skill_ids:
		var s: SkillDef = GameData.skills[sid]
		if (s.build != "" and s.build != build_id) or not p.stats.meets(s.requires) or s.effects.has("form"):
			continue
		n += 1
		if n > 6:
			break
		p.skills[0] = s
		_reset()
		_scene = "%s: basico->skill->basico->parado" % s.id
		_hold(_cmd(-1, true), 0.3)
		_hold(_cmd(0, true), DT)
		_hold(_cmd(-1, true), 1.2)
		_hold(InputCommand.new(), 0.8)
		_reset()
		_scene = "%s: corre->skill->dash" % s.id
		_hold(_move_cmd(), 0.4)
		_step(_move_cmd(false, 0))
		_hold(_move_cmd(), maxf(DT, s.startup * 0.5))
		_step(_cmd(-1, false, true))
		_hold(InputCommand.new(), 0.6)
	view.manual_anim = false
	# piores trancos: pico alto E isolado (bem maior que os quadros vizinhos)
	_pops.sort_custom(func(a, b): return a[0] * minf(a[1], 4.0) > b[0] * minf(b[1], 4.0))
	var top: Array = _pops.slice(0, 3)
	if verbose or (not top.is_empty() and top[0][0] > POP_DEG and top[0][1] > POP_RATIO):
		for t in top:
			print("  tranco %.0f° (%.1fx os vizinhos) %s [%s]" % [t[0], t[1], t[2], t[3]])
	for t in top:
		if t[0] > POP_DEG and t[1] > POP_RATIO:
			_flag("%s/%s tranco de %.0f° num quadro: %s [%s]" % [cls.id, build_id, t[0], t[2], t[3]])
			break

## Build de forma de animal (Druida Lobo/Urso): as skills dela são usadas transformado.
func _form_of(cls: ClassDef, build_id: String) -> String:
	if cls.id != "druid":
		return ""
	for f in ["wolf", "bear"]:
		if p.stats.meets([Balance.FORM_REQUIRES[f]]):
			return f
	return ""

func _spawn_dummies(map_id: String) -> void:
	var mdef: MonsterDef = GameData.monsters["slime"]
	for off in [Vector3(0, 0, 2.2), Vector3(-1.4, 0, 3.0), Vector3(1.4, 0, 3.0)]:
		var m := Sim.spawn_monster(mdef, map_id, SPOT + off)
		m.brain = null
		m.stats.max_hp = 1.0e9
		m.hp = 1.0e9
		dummies.append(m)

func _sync_view() -> void:
	if p.form != view._shown_form:
		view._swap_form()

func _reset() -> void:
	p.set_state(SimEntity.State.IDLE)
	p.current_skill = null
	p.cooldowns.clear()
	p.mp = p.stats.max_mp
	p.hp = p.stats.max_hp
	p.basic_cd = 0.0
	p.dash_cd = 0.0
	p.dash_charges_used = 0
	p.buffered_cmd = null
	p.position = SPOT
	p.velocity = Vector3.ZERO
	p.debuffs.clear()
	for d in dummies:
		d.hp = 1.0e9
		d.debuffs.clear()
	_tick(InputCommand.new())

func _cmd(slot: int = -1, attack: bool = false, dash: bool = false) -> InputCommand:
	var c := InputCommand.new()
	c.aim = dummies[0].position
	c.skill_slot = slot
	c.attack = attack
	c.dash = dash
	return c

func _tick(c: InputCommand) -> void:
	Sim.set_player_command(c)
	Sim.tick(DT)

## Segura o ataque 4 s: golpes por segundo e o maior trecho parado (ticks) entre dois golpes.
func _basic_cadence() -> Array:
	_reset()
	var swings := 0
	var gap := 0
	var worst := 0
	var last: SkillDef = null
	var last_t := -1.0
	for i in range(240):
		_tick(_cmd(-1, true))
		var casting := p.state == SimEntity.State.CASTING and p.current_skill == p.basic_skill
		if casting and (p.current_skill != last or p.state_time < last_t):
			swings += 1
			worst = maxi(worst, gap) if swings > 1 else worst
			gap = 0
		elif not casting:
			gap += 1
		last = p.current_skill if casting else null
		last_t = p.state_time if casting else -1.0
	return [swings / 4.0, worst, _basic_anim_gap()]

## Segurando o ataque: quanto (s) o desenho do golpe fica parado na guarda antes do próximo (mesma conta da EntityView).
func _basic_anim_gap() -> float:
	var s := p.basic_skill
	var want := view._action_clip(s)
	var clip := view._clip(want)
	if clip == "":
		clip = view._clip("attack")
	if clip == "" or view.anim == null:
		return 0.0
	var length := view.anim.get_animation(clip).length
	var impact := float(EntityView.IMPACT_FRAME.get(clip, 5) - 1) / 24.0
	var startup := maxf(s.startup, 0.06)
	var wt := EntityView.windup_timing(impact, startup)
	var s1 := wt.y
	var cd := p.stats.basic_cooldown(s.cooldown)
	var time_left := maxf(s.active + s.recovery, cd - s.startup)
	var left := length - (wt.x + startup * s1)
	var s2 := clampf(left / time_left / s1, EntityView.HELD_BASIC_MIN_SPEED, 2.5)
	var anim_end := s.startup + left / (s1 * s2)
	if verbose:
		print("  basico %s: clipe %.2fs startup %.2f cd %.2f s1 %.2f s2 %.2f (pedia %.2f) fim do desenho %.2f" % [clip, length, s.startup, cd, s1, s2,
			left / time_left / s1, anim_end])
	return maxf(0.0, maxf(cd, s.startup + s.active + s.recovery) - anim_end)

## Uma skill no slot 0: mede e confere o clipe. {} = não saiu.
func _probe_skill(s: SkillDef) -> Dictionary:
	p.skills[0] = s
	var tag := "%s %s" % [p.class_def.id, s.id]
	# --- latência e trava ---
	_reset()
	var lat := -1
	for i in range(6):
		_tick(_cmd(0) if i == 0 else InputCommand.new())
		if p.state == SimEntity.State.CASTING and p.current_skill and p.current_skill.id == s.id:
			lat = i
			break
	if lat < 0:
		if verbose:
			print("  %s não saiu (%s)" % [tag, Sim.requires_text(s.requires)])
		return {}
	var cast: SkillDef = p.current_skill           # a versão resolvida (maestria, forma, evolução)
	var lock_ticks := 0
	var impact_tick := -1
	var chain_ticks := -1
	for i in range(int(6.0 / DT)):
		var hold_basic := impact_tick >= 0
		_tick(_cmd(-1, hold_basic))
		lock_ticks += 1
		if impact_tick < 0 and p.skill_applied:
			impact_tick = lock_ticks
		if hold_basic and p.state == SimEntity.State.CASTING and p.current_skill == p.basic_skill:
			chain_ticks = lock_ticks - impact_tick
			break
		if p.state != SimEntity.State.CASTING and not hold_basic:
			break
	var channel := cast.startup >= 0.5 and cast.kind != SkillDef.Kind.PHYSICAL
	var lock_s := (impact_tick if impact_tick >= 0 else lock_ticks) * DT + maxf(0, chain_ticks) * DT
	if lat > 1:
		_flag("%s latência %d ticks" % [tag, lat])
	if not channel and cast.startup > STARTUP_SLOW:
		_flag("%s preparo %.2fs (golpe demora a sair)" % [tag, cast.startup])
	if not channel and lock_s > LOCK_SLOW:
		_flag("%s trava %.2fs até poder agir" % [tag, lock_s])
	if impact_tick >= 0 and chain_ticks < 0 and cast.kind != SkillDef.Kind.BUFF:
		_flag("%s básico não encadeia depois do impacto" % tag)
	# --- buffer: básico apertado UMA vez no meio do preparo ---
	_reset()
	_tick(_cmd(0))
	var press_at := maxi(1, int(cast.startup * 0.5 / DT))
	var fired := false
	for i in range(int(4.0 / DT)):
		_tick(_cmd(-1, true) if i == press_at else InputCommand.new())
		if p.state == SimEntity.State.CASTING and p.current_skill == p.basic_skill:
			fired = true
			break
	if not fired:
		_flag("%s básico apertado no preparo se perdeu (buffer)" % tag)
	# --- dash cancela no preparo ---
	_reset()
	_tick(_cmd(0))
	_tick(InputCommand.new())
	_tick(_cmd(-1, false, true))
	var dashed := p.state == SimEntity.State.DASHING
	if not dashed and not cast.effects.has("dash"):
		_flag("%s dash não cancela o preparo" % tag)
	# --- clipe: impacto do desenho no tick do dano, sem congelar nem cortar ---
	_anim_check(tag, cast)
	return {"latency": float(lat)}

## Mesma conta de EntityView._animate_glb: velocidade até o impacto e depois o resto do clipe até o fim da skill.
func _anim_check(tag: String, s: SkillDef) -> void:
	if view.anim == null:
		return
	var want := view._action_clip(s)
	var clip := view._clip(want)
	if clip == "":
		clip = view._clip("cast" if s.kind != SkillDef.Kind.PHYSICAL else "attack")
	if clip == "":
		clip = view._clip("attack")
	if clip == "":
		_flag("%s sem clipe nenhum (%s)" % [tag, want])
		return
	if clip != want and verbose:
		print("  %s clipe %s -> %s" % [tag, want, clip])
	var length := view.anim.get_animation(clip).length
	var impact := float(EntityView.IMPACT_FRAME.get(clip, 5) - 1) / 24.0
	var startup := maxf(s.startup, 0.06)
	var wt := EntityView.windup_timing(impact, startup)
	var raw1 := (impact - wt.x) / startup
	var s1 := wt.y
	var off := (impact - wt.x) / s1 - startup
	if absf(off) > 0.08:
		# o desenho chega no golpe antes/depois do dano
		_flag("%s clipe '%s' bate %.2fs %s do dano (precisa %.1fx)" % [tag, clip, absf(off), "antes" if off < 0 else "depois", raw1])
	var looping: bool = clip in EntityView.ACTIVE_LOOP and s.active >= EntityView.LOOP_MIN_ACTIVE
	var left := length - (wt.x + startup * s1)
	var end_t := s.startup + s.active if looping else s.startup + s.active + s.recovery
	var time_left := maxf(end_t - s.startup, 0.05)
	var raw2 := left / time_left / maxf(s1, 0.01)
	var s2 := clampf(raw2, 0.5, 2.5)
	var clip_end := s.startup + left / maxf(s1 * s2, 0.01)
	if raw2 > 2.5 * 1.05:
		_flag("%s clipe '%s' corre demais depois do impacto (%.1fx)" % [tag, clip, raw2])
	elif not looping and clip_end < s.startup + s.active - 0.1:
		# acabou o desenho com a fase ativa ainda rolando (dano/giro/avanço sem movimento na tela)
		_flag("%s clipe '%s' para %.2fs antes do fim da fase ativa" % [tag, clip, s.startup + s.active - clip_end])
