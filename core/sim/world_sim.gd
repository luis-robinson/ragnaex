extends Node
## WorldSim (autoload `Sim`): dona de TODAS as entidades de TODOS os mapas.
## Roda em tick fixo (physics). Não conhece nós 3D. Recebe InputCommands e emite Events.
## Este é o "servidor" — quando virar online, roda headless e recebe comandos por RPC.

const TICK_RATE := 60.0
const AI_EVERY := 3
var tick_usec := 0.0                 # custo médio de um tick (µs)
var away_every: int = Balance.AWAY_MAP_EVERY     # mapas sem o jogador: 1 = ritmo cheio (--no_away, para medir)

var running: bool = false
var tick_count: int = 0
var time: float = 0.0
var rng := RandomNumberGenerator.new()

var maps: Dictionary = {}          # map_id -> MapState (Dictionary)
var entities: Dictionary = {}      # id -> SimEntity
var _next_id: int = 1
var _next_proj_id: int = 1
var player: SimEntity = null
var player_cmd: InputCommand = InputCommand.new()
var _pending_map_changes: Array = []
var parties: Dictionary = {}       # party_id -> {"id", "leader": entity_id, "members": Array[int]}
var invites: Dictionary = {}       # entity_id convidado -> {"from", "expires", "decide_at"}
var _next_party_id: int = 1
var party_seek: Dictionary = {}    # /party: entity_id -> {"queue": [ids de bots], "next_at", "until"}

func _ready() -> void:
	rng.seed = 1337
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if running:
		tick(delta)

## Zera o mundo (voltar ao menu): mapas, entidades, grupos e o jogador. A cena principal recarrega e monta tudo de novo.
func reset_world() -> void:
	running = false
	maps.clear()
	entities.clear()
	parties.clear()
	invites.clear()
	party_seek.clear()
	_pending_map_changes.clear()
	player = null
	player_cmd = InputCommand.new()
	_next_id = 1
	_next_proj_id = 1
	_next_party_id = 1
	_next_trap_id = 1
	tick_count = 0
	time = 0.0

# ----------------------------------------------------------------------------
# MAPAS
# ----------------------------------------------------------------------------
func load_map(def: MapDef) -> Dictionary:
	if maps.has(def.id):
		return maps[def.id]
	var m := {"def": def, "entities": [], "projectiles": [], "loot": [], "spawners": [], "grid": {}, "colliders": [], "traps": [],
		"kills": {}, "elites": {}}         # abates por monstro e o Rei vivo de cada um (Balance.ELITE_*)
	maps[def.id] = m
	_build_collider_grid(m)
	m["gather"] = _spread_gather(def)          # pontos de colheita (depois da colisão: só em chão livre)
	for sp in def.spawners:
		m["spawners"].append({"def": sp, "alive": [], "timer": 0.0, "primed": false})     # primed: já encheu a 1ª vez
	for n in def.npcs:
		_spawn_npc(n, def.id)
	return m

func map_entities(map_id: String) -> Array:
	return maps[map_id]["entities"] if maps.has(map_id) else []

func map_def(map_id: String) -> MapDef:
	return maps[map_id]["def"] if maps.has(map_id) else null

func get_entity(id: int) -> SimEntity:
	return entities.get(id)

# ----------------------------------------------------------------------------
# SPAWN
# ----------------------------------------------------------------------------
func _register(e: SimEntity, map_id: String) -> SimEntity:
	e.id = _next_id
	_next_id += 1
	e.map_id = map_id
	entities[e.id] = e
	maps[map_id]["entities"].append(e)
	Events.entity_spawned.emit(e)
	return e

func spawn_character(kind: SimEntity.Kind, cls: ClassDef, char_name: String, map_id: String, pos: Vector3, level: int = 1) -> SimEntity:
	var e := SimEntity.new()
	e.kind = kind
	e.name = char_name
	e.class_def = cls
	e.look = LooksCatalog.default_look(cls)
	e.level = level
	e.position = pos
	e.home_position = pos
	e.radius = Balance.ENTITY_RADIUS
	e.ensure_slots()
	# skills iniciais: aprendidas de graça e postas nos primeiros slots
	for sid in cls.starting_skills:
		var s: SkillDef = GameData.skills.get(sid)
		if s:
			e.learned[sid] = true
			e.mastery[sid] = 0
			var free := _first_free_slot(e)
			if free >= 0:
				e.skills[free] = s
	var tr: Dictionary = GameData.trees.get(cls.id, {})
	if not tr.is_empty():
		e.tree[tr["start"]] = true
		for sid in cls.starting_skills:
			var nid := "%s_s_%s" % [cls.id, sid]
			if tr["nodes"].has(nid):
				e.tree[nid] = true
	for item_id in cls.starting_equipment:
		var item: ItemDef = GameData.items.get(item_id)
		if item:
			e.equipment[item.slot] = item
	e.basic_skill = GameData.basic_skill_for_class(cls)
	e.potion_slots = ["potion_hp_s", "potion_mp_s", ""]
	e.add_item("potion_hp_s", 5)
	e.add_item("potion_mp_s", 3)
	for item_id in cls.starting_bag:
		if GameData.items.has(item_id):
			e.add_item(item_id, 1)
	e.gold = 50
	e.recompute_stats()
	e.heal_full()
	return _register(e, map_id)

func spawn_monster(mdef: MonsterDef, map_id: String, pos: Vector3, spawner = null) -> SimEntity:
	var e := SimEntity.new()
	e.kind = SimEntity.Kind.MONSTER
	e.name = mdef.name
	e.monster_def = mdef
	e.level = mdef.level
	e.position = pos
	e.home_position = pos
	e.radius = mdef.radius
	e.scale = mdef.scale
	e.basic_skill = GameData.basic_skill_for_monster(mdef)
	_add_skills(e, mdef.skill_ids)
	e.brain = MonsterBrain.new()
	e.recompute_stats()
	e.heal_full()
	_register(e, map_id)
	if spawner != null:
		spawner["alive"].append(e.id)
	return e

func _add_skills(e: SimEntity, ids: Array) -> void:
	for sid in ids:
		var s: SkillDef = GameData.skills.get(sid)
		if s and not (s in e.skills):
			e.skills.append(s)

func spawn_summon(owner: SimEntity, mdef: MonsterDef, pos: Vector3, duration: float, owner_stats: bool = false) -> SimEntity:
	var e := SimEntity.new()
	e.kind = SimEntity.Kind.SUMMON
	e.name = mdef.name
	e.monster_def = mdef
	e.level = owner.level
	e.owner_id = owner.id
	e.party_id = owner.party_id
	e.position = pos
	e.home_position = pos
	e.radius = mdef.radius
	e.scale = mdef.scale
	e.summon_expires = time + duration if duration > 0.0 else INF       # duração 0 = permanente (companheiro)
	e.basic_skill = GameData.basic_skill_for_monster(mdef)
	e.brain = MonsterBrain.new()
	var pk := 1.0 + owner.stats.pet_power / 100.0 if owner.is_character() and owner.stats else 1.0
	if owner_stats:            # companheiro: parte da vida/ataque/defesa do dono, mais o bônus de companheiro
		var k := 1.0 + owner.stats.pet_power / 100.0
		e.summon_hp = owner.stats.max_hp * Balance.PET_HP_SHARE * k
		e.summon_patk = owner.stats.patk * Balance.PET_ATK_SHARE * k
	else:
		e.summon_patk = owner.stats.matk * 0.6 * clampf(mdef.atk / 12.0, 0.6, 2.5) * pk     # monstro mais forte (rei esqueleto) bate mais
	e.recompute_stats()
	if owner_stats:
		e.stats.pdef = owner.stats.pdef * Balance.PET_DEF_SHARE
	e.stats.patk = e.summon_patk
	e.heal_full()
	return _register(e, owner.map_id)

func _spawn_npc(n: Dictionary, map_id: String) -> SimEntity:
	var e := SimEntity.new()
	e.kind = SimEntity.Kind.NPC
	e.name = n.get("name", "NPC")
	e.position = n.get("pos", Vector3.ZERO)
	e.facing = deg_to_rad(float(n.get("facing", 180.0)))
	e.npc_data = n
	if n.has("look_seed"):                  # morador: visual sorteado, sempre o mesmo
		var lr := RandomNumberGenerator.new()
		lr.seed = int(n["look_seed"])
		e.look = LooksCatalog.random_look(lr)
	e.radius = 0.45
	e.hp = 1.0
	return _register(e, map_id)

func spawn_player(cls: ClassDef, char_name: String, map_id: String, look: Dictionary = {}) -> SimEntity:
	var def := map_def(map_id)
	player = spawn_character(SimEntity.Kind.PLAYER, cls, char_name, map_id, def.spawn_point)
	player.look = LooksCatalog.normalized(look, cls)
	return player

func spawn_bot(cls: ClassDef, bot_name: String, map_id: String, pos: Vector3, level: int) -> SimEntity:
	var b := spawn_character(SimEntity.Kind.BOT, cls, bot_name, map_id, pos, level)
	b.look = LooksCatalog.random_look(rng)       # cada bot com um visual
	b.brain = BotBrain.new()
	b.brain.setup(b, rng)
	# bot escolhe uma build: equipamento com as armas dela e skills dela até o nível atual
	if cls.builds.size() > 0:
		b.build_id = cls.builds[rng.randi() % cls.builds.size()]["id"]
	_gear_bot(b)
	_skill_bot(b)
	return b

## Equipamento de bot: tier comum pelo nível; armas da build (principal + secundária).
func _gear_bot(b: SimEntity) -> void:
	var tier := clampi(b.level / 8, 0, 3)
	var build := b.class_def.build_by_id(b.build_id)
	var main_types: Array = build.get("main", b.class_def.weapon_types)
	var off_types: Array = build.get("off", [])
	if "shield" in off_types and off_types.size() > 1:
		off_types = [off_types[rng.randi() % off_types.size()]]     # orbe ou escudo: cada bot escolhe
	b.equipment.clear()
	for item_id in GameData.items:
		var it: ItemDef = GameData.items[item_id]
		if not it.is_equipment() or it.rarity != tier:
			continue
		if it.class_restriction.size() > 0 and not (b.class_def.id in it.class_restriction):
			continue
		if it.slot == ItemDef.Slot.WEAPON:
			if it.weapon_type == main_types[0] or (not b.equipment.has(ItemDef.Slot.WEAPON) and it.weapon_type in main_types):
				b.equipment[ItemDef.Slot.WEAPON] = it
			if off_types.size() > 0 and it.weapon_type == off_types[0]:
				b.equipment[ItemDef.Slot.OFFHAND] = it   # segunda arma (empunhando duas)
		elif it.slot == ItemDef.Slot.OFFHAND:
			if off_types.size() > 0 and it.weapon_type == off_types[0]:
				b.equipment[ItemDef.Slot.OFFHAND] = it
		elif it.slot == ItemDef.Slot.LEGS:
			if it.armor_style == build.get("armor", it.armor_style):
				b.equipment[it.slot] = it
		elif it.slot in [ItemDef.Slot.CAPE, ItemDef.Slot.AMULET, ItemDef.Slot.RING]:
			if it.attr(build.get("attr", "")) > 0:
				if it.slot == ItemDef.Slot.RING and b.equipment.has(ItemDef.Slot.RING):
					b.equipment[ItemDef.Slot.RING2] = it
				else:
					b.equipment[it.slot] = it
		else:
			b.equipment[it.slot] = it
	if b.equipment.has(ItemDef.Slot.RING) and not b.equipment.has(ItemDef.Slot.RING2):
		b.equipment[ItemDef.Slot.RING2] = b.equipment[ItemDef.Slot.RING]
	var w: ItemDef = b.equipment.get(ItemDef.Slot.WEAPON)
	if w and w.is_two_handed():
		b.equipment.erase(ItemDef.Slot.OFFHAND)
	b.recompute_stats()
	b.heal_full()
	Events.equipment_changed.emit(b.id)   # a view já existe (spawn emite antes)

## Skills de bot: aprende as da build até o nível, equipa as 6 primeiras que a arma permite,
## maestria proporcional ao nível.
func _skill_bot(b: SimEntity) -> void:
	var build := b.class_def.build_by_id(b.build_id)
	var ids: Array = build.get("skills", b.class_def.skill_ids)
	for i in range(b.skills.size()):
		b.skills[i] = null
	var slot := 0
	for sid in ids:
		var s: SkillDef = GameData.skills.get(sid)
		if s == null or s.unlock_level > b.level:
			continue
		b.learned[sid] = true
		b.mastery[sid] = clampi(b.level / 6, 0, Balance.MASTERY_MAX)
		if slot < Balance.SKILL_SLOTS and b.stats.meets(s.requires):
			b.skills[slot] = s
			slot += 1
	for t in GameData.talents_for_class(b.class_def.id):
		if t.unlock_level <= b.level and rng.randf() < 0.5:
			b.talents[t.id] = true

func despawn(e: SimEntity) -> void:
	if e == null or not entities.has(e.id):
		return
	if e.party_id >= 0 and e.kind != SimEntity.Kind.SUMMON:
		party_leave(e)
	invites.erase(e.id)
	entities.erase(e.id)
	if maps.has(e.map_id):
		maps[e.map_id]["entities"].erase(e)
		if maps[e.map_id].has("chars"):
			maps[e.map_id]["chars"].erase(e)       # a lista do tick não pode guardar quem saiu
	Events.entity_despawned.emit(e.id)

# ----------------------------------------------------------------------------
# TICK
# ----------------------------------------------------------------------------
func set_player_command(cmd: InputCommand) -> void:
	player_cmd = cmd

var profile := false                 # --perf: soma o tempo de cada fase do tick
var prof: Dictionary = {}

func _prof(key: String, since: int) -> void:
	prof[key] = float(prof.get(key, 0.0)) + float(Time.get_ticks_usec() - since)

func tick(dt: float) -> void:
	var t_start := Time.get_ticks_usec()
	tick_count += 1
	time += dt
	# mapa sem o jogador roda a cada AWAY_MAP_EVERY ticks com o passo somado (bots e monstros seguem vivos, mais baratos);
	# sem jogador (testes, servidor) todos rodam cheios
	var focus: String = player.map_id if player != null else ""
	var mi := -1
	for map_id in maps:
		mi += 1
		var mdt := dt
		if focus != "" and map_id != focus and away_every > 1:
			if (tick_count + mi) % away_every != 0:
				continue
			mdt = dt * away_every
		var m: Dictionary = maps[map_id]
		var ents: Array = m["entities"]
		_index_map(m)                       # grade de vizinhos + lista de personagens (separação e alvo dos monstros)
		var pt := Time.get_ticks_usec() if profile else 0
		var map_t := pt
		# 1) comandos (jogador + cérebros)
		for e in ents:
			if not e.is_alive():
				continue
			var cmd: InputCommand = null
			if e == player:
				cmd = player_cmd
			elif e.brain != null:
				if e.kind == SimEntity.Kind.MONSTER and _dormant(e, m):
					continue
				# cérebros pensam a 20 Hz (escalonados por id); entre pensamentos repetem o movimento
				if (tick_count + e.id) % AI_EVERY == 0 or e.brain_cmd == null:
					var bt := Time.get_ticks_usec() if profile else 0
					cmd = e.brain.think(e, self, m, mdt * AI_EVERY)
					if profile:
						_prof("think_" + ("bot" if e.kind == SimEntity.Kind.BOT else "mob"), bt)
					e.brain_cmd = cmd
				else:
					cmd = e.brain_cmd.duplicate_cmd()
					cmd.attack = false; cmd.skill_slot = -1; cmd.potion_slot = -1; cmd.dash = false; cmd.interact = false; cmd.jump = false
					cmd.mount = false; cmd.recall = false          # ações de 1 vez: repetir trocaria a montaria a cada tick
			if cmd != null:
				var at := Time.get_ticks_usec() if profile else 0
				_apply_command(e, cmd, m, mdt)
				if profile:
					_prof("apply_" + SimEntity.Kind.keys()[e.kind], at)
		if profile:
			_prof("commands", pt)
			pt = Time.get_ticks_usec()
		# 2) estados, cooldowns, movimento
		for e in ents.duplicate():
			if e.dormant and e.state == SimEntity.State.IDLE and e.debuffs.is_empty():
				continue                        # dormindo: nada muda até alguém chegar perto
			var ut := Time.get_ticks_usec() if profile else 0
			_update_entity(e, m, mdt)
			if profile:
				_prof("upd_" + SimEntity.Kind.keys()[e.kind], ut)
		if profile:
			_prof("entities", pt)
			pt = Time.get_ticks_usec()
		_update_projectiles(m, mdt)
		if profile:
			_prof("r_projectiles", pt); pt = Time.get_ticks_usec()
		_update_spawners(m, mdt)
		if profile:
			_prof("r_spawners", pt); pt = Time.get_ticks_usec()
		_update_traps(m)
		_update_loot(m, mdt)
		if profile:
			_prof("r_loot", pt); pt = Time.get_ticks_usec()
		if profile:
			_prof("rest", pt)
			_prof("map_" + map_id, map_t)
	# descarta inputs de 1 tick do jogador
	player_cmd = player_cmd.duplicate_cmd()
	player_cmd.attack = false; player_cmd.skill_slot = -1; player_cmd.potion_slot = -1
	player_cmd.interact = false; player_cmd.dash = false; player_cmd.jump = false
	player_cmd.mount = false; player_cmd.recall = false
	_process_map_changes()
	_party_catchup(dt)
	if not invites.is_empty():
		_update_invites()
	tick_usec = tick_usec * 0.95 + float(Time.get_ticks_usec() - t_start) * 0.05     # média móvel (overlay/medição)

# ----------------------------------------------------------------------------
# COMANDOS
# ----------------------------------------------------------------------------
func _apply_command(e: SimEntity, cmd: InputCommand, m: Dictionary, dt: float) -> void:
	e.last_cmd = cmd
	if e.state == SimEntity.State.STUNNED or e.state == SimEntity.State.DEAD:
		return

	# --- input buffer: guarda a ação se não pode agir agora ---
	var action_cmd := cmd
	# segurar o ataque manda ação todo tick: não pode apagar a skill/dash que está esperando no buffer
	var held_only: bool = cmd.attack and cmd.skill_slot < 0 and not cmd.dash and not cmd.jump and cmd.potion_slot < 0
	if cmd.has_action() and not cmd.interact and not (held_only and e.buffered_cmd != null):
		if (e.can_act() and not e.airborne()) or _in_cancel_window(e) or _can_chain(e, cmd) or _dash_cancels(e, cmd):
			e.buffered_cmd = null
		else:
			e.buffered_cmd = cmd.duplicate_cmd()
			e.buffered_ticks = Balance.INPUT_BUFFER_TICKS
	elif e.buffered_cmd != null:
		# durante a própria skill o comando espera o impacto sem vencer: apertar no começo de um golpe longo não se perde
		if not (e.state == SimEntity.State.CASTING and not _can_chain(e, e.buffered_cmd)):
			e.buffered_ticks -= 1
		if e.buffered_ticks <= 0:
			e.buffered_cmd = null
		elif (e.can_act() and not e.airborne()) or _in_cancel_window(e) or _can_chain(e, e.buffered_cmd):
			action_cmd = e.buffered_cmd
			action_cmd.move = cmd.move
			action_cmd.aim = cmd.aim
			e.buffered_cmd = null

	# --- encarar o cursor (personagens) ---
	var can_turn := e.can_act()
	if e.state == SimEntity.State.CASTING and e.current_skill:
		can_turn = e.skill_applied or not e.current_skill.lock_facing      # depois do impacto volta a seguir o cursor
		if e.is_character() and not e.skill_applied and not e.current_skill.lock_facing:
			e.skill_aim = cmd.aim
	if can_turn:
		e.face_towards(cmd.aim)

	# --- montaria (H) ---
	if cmd.mount and e.is_character():
		if e.mounted:
			dismount(e)
		elif e.combat_timer > 0.0 or e.state == SimEntity.State.CASTING or e.airborne() or e.form != "":
			if e == player:
				Events.notification.emit("Não dá para montar agora (em combate)" if e.combat_timer > 0.0 else "Não dá para montar agora")
		else:
			e.mounted = true
			e.is_blocking = false
			Events.mount_changed.emit(e.id, true)
	_update_recall(e, cmd, action_cmd, dt)
	_update_gather(e, cmd, action_cmd, dt)
	# atacar, usar skill, dash ou bloquear: desce do cavalo e a ação acontece
	if e.mounted and (action_cmd.attack or action_cmd.skill_slot >= 0 or action_cmd.dash or cmd.block):
		dismount(e)

	# --- poções: a qualquer momento vivo ---
	if action_cmd.potion_slot >= 0:
		use_potion(e, action_cmd.potion_slot)

	# --- pulo (Espaço): no ar anda e dá dash; golpes e skills ficam no buffer até o pouso ---
	if cmd.jump and e.can_act() and not e.airborne() and not e.has_debuff("root"):
		e.jump_v = Balance.JUMP_VELOCITY
		e.jump_h = 0.001
		e.is_blocking = false
		Events.skill_cast.emit(e.id, "jump", "active")

	# --- dash ---
	if action_cmd.dash and e.dash_cd <= 0.0 and (e.can_act() or _in_cancel_window(e) or _dash_cancels(e, action_cmd)) and not e.has_debuff("root"):
		if e.state == SimEntity.State.CASTING:
			_cancel_cast(e)
		var d := Vector3(cmd.move.x, 0, cmd.move.y)
		if d.length_squared() < 0.01:
			d = e.forward()
		var dp := dash_params(e)
		e.dash_params = dp
		e.dash_dir = d.normalized()
		# cargas: com 2+, o próximo dash sai logo; a recarga cheia só quando gasta todas
		e.dash_charges_used += 1
		if e.dash_charges_used >= int(dp["charges"]):
			e.dash_charges_used = 0
			e.dash_cd = Balance.DASH_COOLDOWN * float(dp["cooldown_mult"])
		else:
			e.dash_cd = Balance.DASH_CHARGE_WINDOW * 0.25
		e.is_blocking = false
		e.set_state(SimEntity.State.DASHING, Balance.DASH_TIME)
		Events.skill_cast.emit(e.id, "dash", "active")
		return

	# --- skills ---
	if action_cmd.skill_slot >= 0 and not e.airborne() and (e.can_act() or _in_cancel_window(e) or _can_chain(e, action_cmd)):
		if try_cast(e, action_cmd.skill_slot, action_cmd.aim, m):
			return
	# --- ataque básico ---
	if action_cmd.attack and not e.airborne() and (e.can_act() or _in_cancel_window(e) or _can_chain(e, action_cmd)) and e.basic_cd <= 0.0 and e.basic_skill:
		_start_skill(e, e.basic_skill, -1, action_cmd.aim)
		e.basic_cd = e.stats.basic_cooldown(e.basic_skill.cooldown)
		return
	# --- interagir ---
	if action_cmd.interact and e == player:
		_interact(e, m)

	# --- bloqueio ---
	if e.is_character():
		if e.guard_broken and not cmd.block and e.mp >= Balance.BLOCK_MIN_MP:
			e.guard_broken = false
		var want_block := cmd.block and e.can_act() and not e.airborne() and e.mp > 0.0 and not e.guard_broken
		if want_block and not e.is_blocking and e.stats.has_shield and e.parry_cd <= 0.0:
			e.parry_left = Balance.PARRY_WINDOW
			e.parry_cd = Balance.PARRY_COOLDOWN
		e.is_blocking = want_block
		if want_block:
			e.mp = maxf(0.0, e.mp - Balance.BLOCK_MP_PER_SEC * dt)
			e.guard_broken = e.mp <= 0.0

	# --- movimento ---
	if e.can_act():
		var mv := Vector3(cmd.move.x, 0.0, cmd.move.y)
		if mv.length() > 1.0:
			mv = mv.normalized()
		if e.has_debuff("root"):
			mv = Vector3.ZERO
		if mv.length_squared() > 0.001:
			var spd := e.stats.move_speed * e.slow_factor() * (0.5 if e.is_blocking else 1.0) * (Balance.MOUNT_SPEED_MULT if e.mounted else 1.0)
			e.velocity = mv * spd
			_move(e, e.velocity * dt, m)
			e.set_state(SimEntity.State.BLOCKING if e.is_blocking else SimEntity.State.MOVING)
			if not e.is_character():
				e.face_towards(e.position + mv)
		else:
			e.velocity = Vector3.ZERO
			e.set_state(SimEntity.State.BLOCKING if e.is_blocking else SimEntity.State.IDLE)
	elif e.state == SimEntity.State.CASTING:
		var mv := Vector3(cmd.move.x, 0.0, cmd.move.y)
		var moving := mv.length_squared() > 0.01
		if moving and _in_cancel_window(e):
			# cancel de recovery por movimento
			_end_skill(e)
			e.velocity = mv.normalized() * e.stats.move_speed * e.slow_factor()
			_move(e, e.velocity * dt, m)
			e.set_state(SimEntity.State.MOVING)
		elif e.is_character():
			var k: float = cast_move_mult(e.current_skill) if moving and not e.has_debuff("root") else 0.0
			e.velocity = mv.normalized() * e.stats.move_speed * e.slow_factor() * k if k > 0.0 else Vector3.ZERO
			if k > 0.0:
				_move(e, e.velocity * dt, m)

## Desce do cavalo (golpe, dano, troca de mapa, morte ou H).
func dismount(e: SimEntity) -> void:
	if not e.mounted:
		return
	e.mounted = false
	Events.mount_changed.emit(e.id, false)

func _in_cancel_window(e: SimEntity) -> bool:
	if e.state != SimEntity.State.CASTING or e.current_skill == null:
		return false
	var s := e.current_skill
	return e.skill_applied and e.state_time >= s.startup + s.active + minf(s.cancel_after, Balance.CANCEL_AFTER_MAX)

## Companheiro vivo do dono (invocação permanente), ou null.
func pet_of(e: SimEntity) -> SimEntity:
	for o in maps[e.map_id]["entities"] if maps.has(e.map_id) else []:
		if o.kind == SimEntity.Kind.SUMMON and o.owner_id == e.id and o.is_alive() and o.summon_expires == INF:
			return o
	return null

func _pet_command(e: SimEntity, s: SkillDef, aim: Vector3, power: float, effects: Dictionary, m: Dictionary) -> void:
	var pet := pet_of(e)
	var target: SimEntity = null
	var best := s.range + 1.0
	for o in m["entities"]:
		if o.is_alive() and e.is_hostile_to(o):
			var d: float = o.position.distance_to(aim)
			if d < best and d < 2.5:
				best = d
				target = o
	if pet == null or target == null:
		return
	var dir := (pet.position - target.position)
	dir.y = 0.0
	pet.position = target.position + (dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD) * (target.radius + pet.radius + 0.2)
	pet.face_towards(target.position)
	pet.aggro_target = target.id
	var r := Combat.calc_damage(pet, target, power, SkillDef.Kind.PHYSICAL, rng, pet.position)
	_deal_damage(pet, target, r["amount"], r["crit"], r["blocked"], "physical", pet.position)
	if effects["pet_command"].has("stun"):
		_apply_effects(e, target, {"stun": {"duration": float(effects["pet_command"]["stun"])}}, power)
	Events.skill_effect.emit(s.id, pet.position, target.position, 1.0)

# ----------------------------------------------------------------------------
# ARMADILHAS (Ranger Atirador): ficam no mapa, armam, disparam quando um inimigo pisa, somem com o tempo
# ----------------------------------------------------------------------------
var _next_trap_id := 1

func _place_trap(e: SimEntity, s: SkillDef, aim: Vector3, power: float, effects: Dictionary) -> void:
	var m: Dictionary = maps[e.map_id]
	var traps: Array = m["traps"]
	var mine: Array = traps.filter(func(t): return t["owner"] == e.id)
	while mine.size() >= Balance.TRAP_MAX:        # a mais antiga some
		var old: Dictionary = mine.pop_front()
		traps.erase(old)
		Events.trap_removed.emit(old["id"], false)
	var td: Dictionary = effects["trap"]
	var fx := {}
	for k in ["root", "slow", "stun", "dot"]:
		if effects.has(k):
			fx[k] = effects[k]
	var pos := Vector3(aim.x, 0.0, aim.z)
	var t := {"id": _next_trap_id, "owner": e.id, "kind": td.get("kind", "jaw"), "pos": pos, "hit_radius": float(td.get("hit_radius", 1.3)),
		"radius": maxf(s.radius, float(td.get("hit_radius", 1.3))), "power": power, "effects": fx, "skill": s.id,
		"armed_at": time + Balance.TRAP_ARM_TIME, "expires": time + float(td.get("duration", 30.0))}
	_next_trap_id += 1
	traps.append(t)
	Events.trap_placed.emit(t["id"], t["kind"], pos, t["radius"], e.map_id)

func _update_traps(m: Dictionary) -> void:
	var traps: Array = m["traps"]
	for t in traps.duplicate():
		var owner: SimEntity = entities.get(t["owner"])
		if time >= float(t["expires"]) or owner == null or owner.map_id != m["def"].id:
			traps.erase(t)
			Events.trap_removed.emit(t["id"], false)
			continue
		if time < float(t["armed_at"]):
			continue
		var pos: Vector3 = t["pos"]
		var stepped := false
		for o in m["entities"]:
			if o.is_alive() and owner.is_hostile_to(o) and Vector3(o.position.x, 0, o.position.z).distance_to(pos) <= float(t["hit_radius"]) + o.radius:
				stepped = true
				break
		if not stepped:
			continue
		traps.erase(t)
		for o in m["entities"]:        # dispara: dano e efeito em quem estiver na área
			if o.is_alive() and owner.is_hostile_to(o) and Vector3(o.position.x, 0, o.position.z).distance_to(pos) <= float(t["radius"]) + o.radius:
				var r := Combat.calc_damage(owner, o, float(t["power"]), SkillDef.Kind.PHYSICAL, rng, pos)
				_deal_damage(owner, o, r["amount"], r["crit"], false, "physical", pos)
				_apply_effects(owner, o, t["effects"], float(t["power"]))
		Events.trap_removed.emit(t["id"], true)
		Events.skill_effect.emit(t["skill"], pos, pos, float(t["radius"]))

## Radiância (Bispo da luz): parte do dano mágico cura o aliado mais ferido por perto (você incluso).
func _radiance(e: SimEntity, amount: int) -> void:
	var best: SimEntity = e
	for o in maps[e.map_id]["entities"]:
		if o.is_character() and o.is_alive() and e.is_friend(o) and o.position.distance_to(e.position) <= Balance.RADIANCE_RANGE:
			if o.hp / o.stats.max_hp < best.hp / best.stats.max_hp:
				best = o
	if best.hp < best.stats.max_hp:
		_heal(e, best, maxi(1, int(round(amount * e.stats.radiance / 100.0))))

## Encadear (estilo Diablo): depois do impacto, outra skill ou o ataque básico já pode sair, sem esperar a recuperação.
## O golpe atual sempre acontece (tudo dele é aplicado no impacto). Só personagens: monstros mantêm o ritmo deles.
func _can_chain(e: SimEntity, cmd: InputCommand) -> bool:
	if not e.is_character() or e.state != SimEntity.State.CASTING or e.current_skill == null or not e.skill_applied:
		return false
	if cmd == null or not (cmd.skill_slot >= 0 or cmd.attack):
		return false
	if cmd.skill_slot < 0 and e.current_skill == e.basic_skill:
		return false            # básico atrás de básico mantém o ritmo dele (senão a velocidade de ataque sobe)
	return e.state_time >= e.current_skill.startup + Balance.CHAIN_AFTER_IMPACT

## Quanto da velocidade sobra durante a skill: investidas não andam, magias longas quase param.
func cast_move_mult(s: SkillDef) -> float:
	if s == null or s.effects.has("dash"):
		return 0.0
	return Balance.CAST_MOVE_MULT_HEAVY if s.startup >= Balance.CAST_HEAVY_STARTUP else Balance.CAST_MOVE_MULT

## Dash interrompe qualquer skill: é a saída de emergência do jogador.
func _dash_cancels(e: SimEntity, cmd: InputCommand) -> bool:
	return cmd.dash and e.is_character() and e.state == SimEntity.State.CASTING and e.dash_cd <= 0.0

## Fim antecipado por dash: antes do impacto nada aconteceu, então devolve MP e recarga.
func _cancel_cast(e: SimEntity) -> void:
	var s := e.current_skill
	if s and not e.skill_applied and e.current_skill_slot >= 0:
		e.mp = minf(e.stats.max_mp, e.mp + s.mp_cost_at(e.mastery_of(s.id)))
		e.cooldowns.erase(s.id)
	_end_skill(e)

func _interact(e: SimEntity, m: Dictionary) -> void:
	var best: SimEntity = null
	var best_d := 2.6
	for o in m["entities"]:
		if o.kind == SimEntity.Kind.NPC:
			var d: float = o.position.distance_to(e.position)
			if d < best_d:
				best_d = d
				best = o
	if best == null:
		_start_gather(e, m)
		return
	if best:
		e.face_towards(best.position)
		best.npc_hold = Balance.NPC_TALK_HOLD
		best.face_towards(e.position)
		_npc_stop(best)
		Events.dialog_requested.emit(best.npc_data.get("id", ""))

# ----------------------------------------------------------------------------
# COLHEITA: pontos espalhados pelo mapa (ervas, minério, conchas...), F perto para colher, voltam depois
# ----------------------------------------------------------------------------
## Espalha os pontos de `def.gather` em chão livre (semente do mapa: sempre nos mesmos lugares).
func _spread_gather(def: MapDef) -> Array:
	var out: Array = []
	var gr := RandomNumberGenerator.new()
	gr.seed = absi(def.id.hash())
	for rule in def.gather:
		var at: Vector3 = rule["at"]
		var r: float = float(rule.get("radius", 8.0))
		for i in range(int(rule.get("count", 4))):
			var p := at
			for tries in range(30):
				var a := gr.randf() * TAU
				var d := sqrt(gr.randf()) * r
				p = at + Vector3(cos(a) * d, 0, sin(a) * d)
				if is_walkable(p, def, 0.6):
					break
			out.append({"item": rule["item"], "kind": rule.get("kind", "herb"), "pos": p, "ready_at": 0.0, "min": int(rule.get("min", 1)), "max": int(rule.get("max", 2))})
	return out

## Ponto pronto mais perto de `e` dentro do alcance (ou {}).
func nearest_gather(e: SimEntity) -> Dictionary:
	if e == null or not maps.has(e.map_id):
		return {}
	var best: Dictionary = {}
	var bd := Balance.GATHER_RANGE
	for node in maps[e.map_id].get("gather", []):
		if float(node["ready_at"]) > time:
			continue
		var d: float = Vector2(node["pos"].x - e.position.x, node["pos"].z - e.position.z).length()
		if d < bd:
			bd = d
			best = node
	return best

func _start_gather(e: SimEntity, m: Dictionary) -> void:
	if not e.is_character() or e.gather_left > 0.0 or e.mounted:
		return
	var node := nearest_gather(e)
	if node.is_empty():
		return
	if e.combat_timer > 0.0:
		if e == player:
			Events.notification.emit("Não dá para colher em combate")
		return
	if e.bag_full_for(node["item"]):
		if e == player:
			Events.notification.emit("Bolsa cheia (%d/%d)" % [e.inventory.size(), e.bag_capacity()])
		return
	e.face_towards(node["pos"])
	e.gather_left = Balance.GATHER_TIME
	e.gather_node = node
	e.gather_hp = e.hp

func _update_gather(e: SimEntity, cmd: InputCommand, action_cmd: InputCommand, dt: float) -> void:
	if e.gather_left <= 0.0:
		return
	var node := e.gather_node
	if not e.is_alive() or cmd.move.length_squared() > 0.04 or action_cmd.attack or action_cmd.skill_slot >= 0 or action_cmd.dash \
			or action_cmd.jump or cmd.block or e.hp < e.gather_hp - 0.5 or e.combat_timer > 0.0 or float(node.get("ready_at", 0.0)) > time:
		e.gather_left = 0.0                  # andou, atacou, apanhou ou alguém colheu antes
		e.gather_node = {}
		return
	e.gather_left -= dt
	if e.gather_left > 0.0:
		return
	e.gather_left = 0.0
	e.gather_node = {}
	var n := rng.randi_range(int(node["min"]), int(node["max"]))
	e.add_item(node["item"], n)
	node["ready_at"] = time + Balance.GATHER_RESPAWN
	var idx: int = (maps[e.map_id]["gather"] as Array).find(node)
	Events.gathered.emit(e.map_id, idx, e.id)
	if e == player:
		Events.notification.emit("Colheu %d %s" % [n, GameData.items[node["item"]].name])

## A janela de conversa aberta segura o NPC (a apresentação chama a cada quadro).
func hold_npc(npc_id: String) -> void:
	if player == null or not maps.has(player.map_id):
		return
	for o in maps[player.map_id]["entities"]:
		if o.kind == SimEntity.Kind.NPC and o.npc_data.get("id", "") == npc_id:
			if o.npc_hold <= 0.0:
				o.face_towards(player.position)
			o.npc_hold = Balance.NPC_TALK_HOLD
			_npc_stop(o)

## Morador que passeia: `wander` = raio em volta de casa, `route` = ronda por pontos [[x, z], ...].
## Sem nenhum dos dois o NPC fica no posto (serviços).
func _update_npc(e: SimEntity, m: Dictionary, dt: float) -> void:
	var nd := e.npc_data
	if not nd.has("wander") and not nd.has("route"):
		return
	if e.npc_hold > 0.0:
		e.npc_hold -= dt
		return
	if e.npc_wait > 0.0:
		e.npc_wait -= dt
		if e.npc_wait <= 0.0:
			e.npc_goal = _npc_next_goal(e, m["def"])
			e.npc_stuck = 0.0
		return
	if e.npc_goal == Vector3.ZERO:
		e.npc_goal = _npc_next_goal(e, m["def"])
	var to := e.npc_goal - e.position
	to.y = 0.0
	if to.length() < 0.35:
		_npc_stop(e)
		e.npc_wait = rng.randf_range(Balance.NPC_WAIT_MIN, Balance.NPC_WAIT_MAX)
		if nd.has("route"):
			e.npc_wait *= 0.4                  # ronda: para pouco
		return
	var step := to.normalized() * minf(to.length(), Balance.NPC_WALK_SPEED * dt)
	var before := e.position
	_move(e, step, m)
	var moved := e.position - before
	moved.y = 0.0
	e.velocity = moved / maxf(dt, 0.0001)
	e.face_towards(e.position + step)
	if e.state != SimEntity.State.MOVING:
		e.set_state(SimEntity.State.MOVING)
	if moved.length() < step.length() * 0.3:   # travou num canto: desiste deste ponto
		e.npc_stuck += dt
		if e.npc_stuck > 1.2:
			_npc_stop(e)
			e.npc_wait = 1.0
	else:
		e.npc_stuck = 0.0

func _npc_stop(e: SimEntity) -> void:
	e.velocity = Vector3.ZERO
	if e.state != SimEntity.State.IDLE:
		e.set_state(SimEntity.State.IDLE)

func _npc_next_goal(e: SimEntity, def: MapDef) -> Vector3:
	var nd := e.npc_data
	var home: Vector3 = nd.get("pos", e.position)
	if nd.has("route"):
		var pts: Array = nd["route"]
		var p: Array = pts[e.npc_leg % pts.size()]
		e.npc_leg += 1
		return Vector3(float(p[0]), 0.0, float(p[1]))
	return random_walkable(def, home, float(nd["wander"]))

# ----------------------------------------------------------------------------
# SKILLS
# ----------------------------------------------------------------------------
func try_cast(e: SimEntity, slot: int, aim: Vector3, m: Dictionary) -> bool:
	if slot < 0 or slot >= e.skills.size() or e.skills[slot] == null:
		return false
	var s: SkillDef = e.skills[slot]
	if e.level < s.unlock_level or (e.is_character() and not e.knows(s.id)):
		return false
	if e.is_character() and not e.stats.meets(s.requires):
		if e == player:
			Events.notification.emit("%s exige: %s" % [s.name, requires_text(s.requires)])
		return false
	var lv := e.mastery_of(s.id)
	if e.cooldowns.get(s.id, 0.0) > 0.0:
		return false
	var cost := s.mp_cost_at(lv)
	if e.mp < cost:
		if e == player:
			Events.notification.emit("MP insuficiente")
		return false
	var form_fx: String = s.effects.get("form", "")
	if form_fx != "" and e.form == form_fx and e != player:
		return false               # bot já transformado não desfaz a forma
	if s.effects.has("summon") and float(s.effects["summon"].get("duration", 20)) <= 0.0 and pet_of(e) != null:
		if e == player:
			Events.notification.emit("Seu companheiro já está com você")
		return false
	if (s.effects.has("pet_command") or s.effects.get("pet_buff", false)) and pet_of(e) == null:
		if e == player:
			Events.notification.emit("%s: chame o companheiro primeiro" % s.name)
		return false
	if s.effects.has("stealth") and s.class_id == "druid" and e.form != "wolf":
		if e == player:
			Events.notification.emit("%s: só na forma de lobo" % s.name)
		return false
	s = resolve_skill(e, s)
	e.mp -= cost
	e.cooldowns[s.id] = s.cooldown_at(lv) * e.stats.skill_cooldown_mult(s.id)
	_start_skill(e, s, slot, aim)
	return true

func _start_skill(e: SimEntity, s: SkillDef, slot: int, aim: Vector3) -> void:
	if e.state == SimEntity.State.CASTING:
		_end_skill(e)
	if e.stealth_left > 0.0 and not s.effects.has("stealth"):
		e.stealth_left = 0.0
		e.ambush = s.kind in [SkillDef.Kind.PHYSICAL, SkillDef.Kind.MAGICAL]     # sai da sombra golpeando
	e.current_skill = s
	e.current_skill_slot = slot
	e.skill_aim = aim
	e.skill_applied = false
	e.skill_phase = "startup"
	e.is_blocking = false
	e.velocity = Vector3.ZERO
	e.face_towards(aim)
	e.set_state(SimEntity.State.CASTING, s.startup + s.active + s.recovery)
	Events.skill_cast.emit(e.id, s.id, "startup")

func _end_skill(e: SimEntity) -> void:
	e.current_skill = null
	e.skill_phase = ""
	e.current_skill_slot = -1
	e.set_state(SimEntity.State.IDLE)

func _update_skill(e: SimEntity, m: Dictionary, dt: float) -> void:
	var s := e.current_skill
	if s == null:
		e.set_state(SimEntity.State.IDLE)
		return
	var t := e.state_time
	if not e.skill_applied and t >= s.startup:
		e.skill_applied = true
		e.skill_phase = "active"
		e.channel_done = 1
		Events.skill_cast.emit(e.id, s.id, "active")
		_apply_skill(e, s, m)
	elif e.skill_applied and e.skill_phase == "active" and s.effects.has("channel"):
		# canalização (estilo sacerdote das sombras): um pulso a cada active/ticks, mirando onde o cursor está
		var n := int(s.effects["channel"].get("ticks", 3))
		while e.channel_done < n and t >= s.startup + s.active * float(e.channel_done) / float(n):
			e.channel_done += 1
			_apply_skill(e, s, m)
	elif e.skill_applied and e.skill_phase == "active" and t >= s.startup + s.active:
		e.skill_phase = "recovery"
		Events.skill_cast.emit(e.id, s.id, "recovery")
	if t >= e.state_duration:
		_end_skill(e)

func _apply_skill(e: SimEntity, s: SkillDef, m: Dictionary) -> void:
	var lv := e.mastery_of(s.id) if s.id in e.mastery else 0
	var power := s.power_at(lv) * e.stats.skill_power_mult(s.id) * e.stats.element_mult(s.elements) * _shield_power(e, s)
	if e.ambush:
		power *= Balance.AMBUSH_MULT
		e.ambush = false
	var extra: Dictionary = s.mastery_entry(lv).get("extra", {})
	var effects := s.effects.duplicate(true)
	for k in extra:
		effects[k] = extra[k]
	for k in s.talent_effects:     # evoluções vencem a maestria
		effects[k] = s.talent_effects[k]
	e.combat_timer = Balance.AGGRO_LOSE_TIME
	var aim := Combat.clamp_aim(e, e.skill_aim, s.range)
	var any_hit := false

	# movimento (dash de skill)
	var origin := e.position                # investida atravessa o alvo: a guarda olha de onde ela partiu
	var charge := s.is_charge()
	var reach := -1.0
	if effects.has("dash"):
		var d := e.forward() * float(effects["dash"])
		if charge:
			var stopped := _charge(e, d, m)
			reach = maxf(0.0, (e.position - origin).dot(e.forward()))
			if not stopped:
				reach += maxf(0.0, s.range - float(effects["dash"]))     # barrada, a sobra do golpe não fura a parede
		else:
			_move(e, d, m)

	# invocações
	if effects.has("summon"):
		var sm: Dictionary = effects["summon"]
		var mdef: MonsterDef = GameData.monsters.get(sm.get("monster_id", ""))
		if mdef:
			# grupo exclusivo (elementais): o novo dispensa os que já estão vivos
			var group: Array = sm.get("replaces", [])
			if not group.is_empty():
				for o in m["entities"].duplicate():
					if o.kind == SimEntity.Kind.SUMMON and o.owner_id == e.id and o.is_alive() and o.monster_def and o.monster_def.id in group:
						despawn(o)
			# limita invocações vivas por dono
			var alive := 0             # limite por tipo de invocação (esqueletos, cão, lich, rei... cada um conta o seu)
			for o in m["entities"]:
				if o.kind == SimEntity.Kind.SUMMON and o.owner_id == e.id and o.is_alive() and o.monster_def == mdef:
					alive += 1
			var n := int(sm.get("count", 1))
			for i in range(n):
				if alive >= int(sm.get("max", 3)):
					break
				var off := Vector3(rng.randf_range(-1.2, 1.2), 0, rng.randf_range(-1.2, 1.2))
				spawn_summon(e, mdef, e.position + e.forward() * 1.2 + off, float(sm.get("duration", 20)), bool(sm.get("owner_stats", false)))
				alive += 1

	if effects.has("trap"):         # armadilha: fica no chão; o efeito sai quando alguém pisa
		_place_trap(e, s, aim, power, effects)
		Events.skill_effect.emit(s.id, e.position, aim, 0.0)
		return
	if effects.has("pet_command"):  # companheiro salta no alvo e morde
		_pet_command(e, s, aim, power, effects, m)
		return
	if effects.get("pet_buff", false) and effects.get("buff") != null:
		var pet := pet_of(e)
		if pet:
			_apply_effects(e, pet, {"buff": effects["buff"]}, power)
	if effects.has("boss_summon"):
		_spawn_adds(e, effects["boss_summon"])
	if effects.get("taunt") != null:
		for o in m["entities"]:
			if o.kind == SimEntity.Kind.MONSTER and o.is_alive() and o.position.distance_to(e.position) <= s.radius + o.radius:
				_taunt(o, e, float(effects["taunt"].get("duration", Balance.TAUNT_DURATION)))

	# projétil (DIRECTION com velocidade)
	if s.projectile_speed > 0.0 and s.target == SkillDef.Target.DIRECTION:
		_spawn_projectile(e, s, power, m, false, effects)
		Events.skill_effect.emit(s.id, e.position, aim, s.radius)
		return

	if s.target == SkillDef.Target.SELF and s.radius <= 0.0 and s.kind != SkillDef.Kind.HEAL and s.kind != SkillDef.Kind.BUFF and not effects.has("shield"):
		Events.skill_effect.emit(s.id, e.position, e.position, s.radius)
		return

	var targets := Combat.select_targets(e, s, aim, m["entities"], origin if charge else null, reach)
	if effects.has("taunt"):
		targets = [e]        # o raio é de quem é provocado; o buff é só de quem provoca
	if charge:
		Events.skill_effect.emit(s.id, origin, origin + e.forward() * reach, s.radius)
	else:
		Events.skill_effect.emit(s.id, e.position, aim, s.radius)
	var on_foes := effects.duplicate()    # buff e escudo são de quem lança, nunca do inimigo atingido
	on_foes.erase("buff")
	on_foes.erase("shield")
	for t in targets:
		match s.kind:
			SkillDef.Kind.HEAL:
				var amount := Combat.calc_heal(e, power, rng)
				_heal(e, t, amount)
			SkillDef.Kind.BUFF:
				pass
			_:
				var from: Vector3 = aim if s.target == SkillDef.Target.GROUND else origin     # área no chão vem do ponto de impacto
				var fm := Combat.frost_mult(s, t) * _legend_power(e, t)          # gelo em alvo retardado/preso: estilhaço
				var r := Combat.calc_damage(e, t, power * fm, s.kind if s.kind != SkillDef.Kind.SUMMON else SkillDef.Kind.MAGICAL, rng, from)
				var dk := "magical" if s.kind == SkillDef.Kind.MAGICAL else "physical"
				_deal_damage(e, t, r["amount"], r["crit"], r["blocked"], "shatter" if Combat.frost_mult(s, t) > 1.0 and dk == "magical" else dk, from)
				_legend_on_hit(e, t, s, int(r["amount"]))
				any_hit = true
				if effects.has("heal_pct_of_dmg"):
					_heal(e, e, int(r["amount"] * float(effects["heal_pct_of_dmg"])))
				_storm_proc(e, s, t)
		_apply_effects(e, t, effects if e.is_friend(t) else on_foes, power)
	if effects.has("buff") or effects.has("shield"):
		_apply_effects(e, e, {"buff": effects.get("buff", null), "shield": effects.get("shield", null)}, power)
	if any_hit and s.hit_stop_frames > 0 and (e == player or targets.has(player)):
		Events.hit_stop.emit(s.hit_stop_frames)

## Raio: chance de atordoar no golpe direto (Balance.STORM_STUN_*).
func _storm_proc(src: SimEntity, s: SkillDef, t: SimEntity) -> void:
	if t.is_alive() and src.is_hostile_to(t) and Combat.storm_can_stun(s) and rng.randf() * 100.0 < Balance.STORM_STUN_CHANCE:
		_apply_effects(src, t, {"stun": {"duration": Balance.STORM_STUN_TIME}}, 0.0)

func _apply_effects(src: SimEntity, t: SimEntity, effects: Dictionary, power: float) -> void:
	if not t.is_alive():
		return
	if effects.get("dot") != null:
		var d: Dictionary = effects["dot"]
		t.debuffs.append({"kind": "dot", "id": "dot_%d" % src.id, "remaining": float(d.get("duration", 4)), "dps": float(d.get("dps", 5)) * (src.stats.matk / 20.0), "src": src.id, "fire": bool(d.get("fire", false))})
	if effects.get("slow") != null:
		var d: Dictionary = effects["slow"]
		t.debuffs.append({"kind": "slow", "remaining": float(d.get("duration", 2)), "pct": float(d.get("pct", 30))})
	if effects.get("root") != null:
		t.debuffs.append({"kind": "root", "remaining": float(effects["root"].get("duration", 2))})
	if effects.get("stun") != null and t.kind != SimEntity.Kind.NPC:
		var dur := float(effects["stun"].get("duration", 1))
		if t.monster_def and t.monster_def.is_boss:
			dur *= 0.4
		t.is_blocking = false
		t.current_skill = null
		t.set_state(SimEntity.State.STUNNED, dur)
	if effects.get("curse") != null:          # maldição (Necromancer): recebe mais dano e/ou causa menos; a mesma maldição renova
		var cu: Dictionary = effects["curse"]
		var cid: String = "curse_%s_%d" % [cu.get("id", "curse"), src.id]
		t.debuffs = t.debuffs.filter(func(dd): return dd.get("id") != cid)
		t.debuffs.append({"kind": "curse", "id": cid, "remaining": float(cu.get("duration", 8)), "taken_pct": float(cu.get("taken_pct", 0)), "weaken_pct": float(cu.get("weaken_pct", 0))})
	if effects.get("wither") != null:
		var w: Dictionary = effects["wither"]
		t.debuffs.append({"kind": "wither", "remaining": float(w.get("duration", 5)), "pct": float(w.get("pct", 50))})
	var longer: float = 1.0 + (src.stats.buff_duration / 100.0 if src.is_character() and src.stats else 0.0)     # bênçãos do Sacerdote duram mais
	if effects.get("form") != null and t == src:
		t.form = "" if t.form == effects["form"] else effects["form"]     # forma de animal liga/desliga
		t.recompute_stats()
		Events.buff_applied.emit(t.id, "form_" + (t.form if t.form != "" else "human"), 0.0)
	if effects.get("stealth") != null and t == src:
		t.stealth_left = float(effects["stealth"])
		t.ambush = false
		for o in maps[t.map_id]["entities"]:        # quem estava atrás dele perde o rastro
			if o.kind == SimEntity.Kind.MONSTER and o.aggro_target == t.id and o.taunt_left <= 0.0:
				o.aggro_target = -1
		Events.buff_applied.emit(t.id, "stealth", t.stealth_left)
	if effects.get("buff") != null:
		var b: Dictionary = effects["buff"].duplicate()
		b["remaining"] = float(b.get("duration", 10)) * longer
		t.buffs = t.buffs.filter(func(x): return x.get("id") != b.get("id"))
		t.buffs.append(b)
		t.recompute_stats()
		Events.buff_applied.emit(t.id, b.get("id", "buff"), b["remaining"])
	if effects.get("shield") != null:
		var sh: Dictionary = effects["shield"]
		t.shield_hp = maxf(t.shield_hp, t.stats.max_hp * float(sh.get("amount_pct_hp", 20)) / 100.0)
		var left := float(sh.get("duration", 5)) * longer
		for x in t.buffs:
			if x.get("id") == "shield":
				left = maxf(left, float(x.get("remaining", 0.0)))     # escudo novo não encurta o que já existe
		t.buffs = t.buffs.filter(func(x): return x.get("id") != "shield")
		t.buffs.append({"id": "shield", "remaining": left})
		Events.buff_applied.emit(t.id, "shield", left)

## Provocar: quem provoca vira o topo da ameaça e o monstro fica preso nele por um tempo.
func _taunt(mob: SimEntity, src: SimEntity, duration: float) -> void:
	var top := 0.0
	for id in mob.threat:
		top = maxf(top, float(mob.threat[id]))
	mob.threat[src.id] = top * Balance.THREAT_SWITCH + 1.0
	mob.aggro_target = src.id
	mob.aggro_timer = Balance.AGGRO_LOSE_TIME
	mob.taunt_left = duration * (0.5 if mob.monster_def.is_boss else 1.0)

## Troca de alvo por ameaça: o primeiro golpe puxa; depois só quem passa o alvo atual com folga.
func _retarget(mob: SimEntity, attacker: SimEntity) -> void:
	mob.aggro_timer = Balance.AGGRO_LOSE_TIME
	if mob.aggro_target < 0:
		mob.aggro_target = attacker.id
		_pack_call(mob, attacker)
	elif mob.taunt_left <= 0.0 and float(mob.threat.get(attacker.id, 0.0)) > float(mob.threat.get(mob.aggro_target, 0.0)) * Balance.THREAT_SWITCH:
		mob.aggro_target = attacker.id

## Bando: o primeiro golpe num monstro chama os iguais que estão parados por perto (chefes e lacaios não).
func _pack_call(mob: SimEntity, attacker: SimEntity) -> void:
	if mob.monster_def == null or mob.monster_def.is_boss or not maps.has(mob.map_id):
		return
	var r2 := Balance.PACK_AGGRO_RADIUS * Balance.PACK_AGGRO_RADIUS
	for o in maps[mob.map_id]["entities"]:
		if o == mob or o.kind != SimEntity.Kind.MONSTER or o.monster_def != mob.monster_def or not o.is_alive() or o.aggro_target >= 0:
			continue
		if o.position.distance_squared_to(mob.position) <= r2:
			o.aggro_target = attacker.id
			o.aggro_timer = Balance.AGGRO_LOSE_TIME

## Lacaios de chefe: monstros de verdade sem spawner; somem quando o chefe morre ou reseta.
func _spawn_adds(boss: SimEntity, sm: Dictionary) -> void:
	var mdef: MonsterDef = GameData.monsters.get(sm.get("id", ""))
	if mdef == null:
		return
	var m: Dictionary = maps[boss.map_id]
	var alive := 0
	for o in m["entities"]:
		if o.boss_id == boss.id and o.is_alive():
			alive += 1
	for i in range(int(sm.get("count", 1))):
		if alive >= int(sm.get("max", 6)):
			break
		var add := spawn_monster(mdef, boss.map_id, random_walkable(m["def"], boss.position, 5.0))
		add.boss_id = boss.id
		add.adds_epoch = boss.adds_epoch
		add.aggro_target = boss.aggro_target
		add.aggro_timer = Balance.AGGRO_LOSE_TIME
		alive += 1

## Avança as fases pelo HP; uma queda grande de HP pode entrar em mais de uma de uma vez.
func _update_boss(e: SimEntity) -> void:
	var phases: Array = e.monster_def.phases
	while e.phase < phases.size() and e.hp / e.stats.max_hp <= float(phases[e.phase]["hp"]):
		var ph: Dictionary = phases[e.phase]
		e.phase += 1
		if ph.has("say") and player and player.map_id == e.map_id:
			Events.notification.emit("%s: %s" % [e.name, ph["say"]])
		_add_skills(e, ph.get("skills", []))
		if ph.has("summon"):
			_spawn_adds(e, ph["summon"])
		if ph.has("enrage"):
			e.dmg_mult = float(ph["enrage"])
			e.recompute_stats()

## Chefe volta ao estado inicial depois de um wipe ou de ser puxado longe demais.
func reset_boss(e: SimEntity) -> void:
	e.phase = 0
	e.dmg_mult = 1.0
	e.adds_epoch += 1
	e.skills.clear()
	_add_skills(e, e.monster_def.skill_ids)
	e.cooldowns.clear()
	e.mastery.clear()
	e.debuffs.clear()
	e.threat.clear()
	e.damage_by.clear()
	e.taunt_left = 0.0
	e.recompute_stats()
	e.heal_full()

## O escudo responde ao bloqueio: cada escudo nomeado tem a sua reação; aparar dobra e atordoa quem bateu de perto.
func _shield_reaction(target: SimEntity, attacker: SimEntity, amount: int, parried: bool, from: Variant = null) -> void:
	var origin: Vector3 = attacker.position if from == null else from
	var off: ItemDef = target.equipment.get(ItemDef.Slot.OFFHAND)
	var fx: Dictionary = off.shield_effect if off else {}
	var theme: String = fx.get("theme", "physical")
	if parried and attacker.is_alive() and attacker.position.distance_to(target.position) <= Balance.PARRY_MELEE_RANGE:
		_apply_effects(target, attacker, {"stun": {"duration": Balance.PARRY_STUN}}, 1.0)
	if target.shield_react_cd > 0.0 and not parried:
		Events.shield_block.emit(target.id, attacker.id, theme, parried, origin)
		return
	target.shield_react_cd = Balance.SHIELD_REACT_CD
	_shield_class_bonus(target, off, parried)
	var k: float = Balance.PARRY_EFFECT_MULT if parried else 1.0
	var max_hp: float = target.stats.max_hp
	if fx.has("heal_pct"):
		target.hp = minf(max_hp, target.hp + max_hp * float(fx["heal_pct"]) * k / 100.0)
	if fx.has("mana_pct"):
		target.mp = minf(target.stats.max_mp, target.mp + target.stats.max_mp * float(fx["mana_pct"]) * k / 100.0)
	if fx.has("barrier_pct"):
		_apply_effects(target, target, {"shield": {"amount_pct_hp": float(fx["barrier_pct"]) * k, "duration": Balance.SHIELD_BARRIER_TIME}}, 1.0)
	if attacker.is_alive():
		var hits := {}
		for key in ["dot", "slow", "root"]:
			if fx.has(key):
				hits[key] = fx[key]
		if not hits.is_empty():
			_apply_effects(target, attacker, hits, 1.0)
		if fx.has("stun_chance") and rng.randf() * 100.0 < float(fx["stun_chance"]) * k:
			_apply_effects(target, attacker, {"stun": {"duration": 0.8}}, 1.0)
		if fx.has("reflect_pct"):
			_deal_damage(target, attacker, maxi(1, int(round(amount * float(fx["reflect_pct"]) * k / 100.0))), false, false, "physical")
	Events.shield_block.emit(target.id, attacker.id, theme, parried, origin)

## Escudo da afinidade certa: paladino junta Juramento; bispo cura o aliado mais ferido e, ao aparar, protege o grupo.
func _shield_class_bonus(e: SimEntity, off: ItemDef, parried: bool) -> void:
	if off == null or e.class_def == null:
		return
	var aff: String = GearCatalog.SHIELD_AFFINITY.get(off.shield_style if off.shield_style != "" else "juramento", "")     # sem estilo = escudo de conjunto
	if not (e.class_def.id == aff or (aff == "both" and e.class_def.id in ["paladin", "bishop"])):
		return
	if e.class_def.id == "paladin":
		var stacks := mini(oath_stacks(e) + (2 if parried else 1), Balance.SHIELD_OATH_MAX)
		e.buffs = e.buffs.filter(func(x): return x.get("id") != "juramento")
		e.buffs.append({"id": "juramento", "remaining": Balance.SHIELD_OATH_TIME, "stacks": stacks})
		Events.buff_applied.emit(e.id, "juramento", Balance.SHIELD_OATH_TIME)
		return
	var hurt: SimEntity = e
	var ents: Array = maps[e.map_id]["entities"]
	for o in ents:
		if o.is_character() and o.is_alive() and e.is_friend(o) and o.position.distance_to(e.position) <= Balance.SHIELD_GRACE_RANGE:
			if o.hp / o.stats.max_hp < hurt.hp / hurt.stats.max_hp:
				hurt = o
	if e.grace_cd <= 0.0:
		e.grace_cd = Balance.SHIELD_GRACE_CD
		_heal(e, hurt, int(hurt.stats.max_hp * Balance.SHIELD_GRACE_PCT / 100.0))
	if parried:
		for o in ents:
			var ward: float = o.stats.max_hp * Balance.SHIELD_WARD_PCT / 100.0 if o.is_character() else 0.0
			if o.is_character() and o.is_alive() and e.is_friend(o) and o.shield_hp < ward and o.position.distance_to(e.position) <= Balance.SHIELD_WARD_RANGE:
				_apply_effects(e, o, {"shield": {"amount_pct_hp": Balance.SHIELD_WARD_PCT, "duration": Balance.SHIELD_WARD_TIME}}, 1.0)     # não encurta escudo maior

func oath_stacks(e: SimEntity) -> int:
	for b in e.buffs:
		if b.get("id") == "juramento":
			return int(b.get("stacks", 0))
	return 0

## Skill de escudo escala com a DEF do escudo; skill sagrada ou de escudo do paladino gasta o Juramento.
func _shield_power(e: SimEntity, s: SkillDef) -> float:
	var off: ItemDef = e.equipment.get(ItemDef.Slot.OFFHAND)
	if off == null or off.weapon_type != "shield" or e.class_def == null or s.kind == SkillDef.Kind.BUFF:
		return 1.0
	var mult := 1.0
	var shield_skill: bool = "shield" in s.requires and e.class_def.id == "paladin"
	if shield_skill:
		mult += minf(off.def * Balance.SHIELD_DEF_POWER, Balance.SHIELD_DEF_POWER_MAX)
	var stacks := oath_stacks(e)
	if stacks > 0 and (shield_skill or s.vfx == "holy"):
		mult += stacks * Balance.SHIELD_OATH_POWER
		e.buffs = e.buffs.filter(func(x): return x.get("id") != "juramento")
	return mult

func _spawn_projectile(e: SimEntity, s: SkillDef, power: float, m: Dictionary, is_basic: bool, effects: Dictionary = {}) -> void:
	var p := SimProjectile.new()
	p.id = _next_proj_id
	_next_proj_id += 1
	p.map_id = e.map_id
	p.owner_id = e.id
	p.skill = s
	p.effects = effects if not effects.is_empty() else s.effects    # já com maestria e evoluções
	p.power = power
	p.position = e.position + Vector3(0, 0.9, 0) + e.forward() * 0.6
	p.direction = e.forward()
	p.speed = s.projectile_speed
	p.max_distance = s.range
	p.radius = maxf(s.radius, 0.3)
	p.pierce = s.projectile_pierce
	p.color = s.icon_color
	p.is_basic = is_basic
	m["projectiles"].append(p)
	Events.projectile_spawned.emit(p)

func _update_projectiles(m: Dictionary, dt: float) -> void:
	var projs: Array = m["projectiles"]
	for p in projs.duplicate():
		var step: float = p.speed * dt
		p.position += p.direction * step
		p.traveled += step
		var owner: SimEntity = entities.get(p.owner_id)
		var remove: bool = p.traveled >= p.max_distance or owner == null
		if not remove:
			var def: MapDef = m["def"]
			var h := def.half()
			if absf(p.position.x) > h.x or absf(p.position.z) > h.y or _point_in_solid(p.position, m):
				remove = true
		if not remove:
			for t in m["entities"]:
				if not t.is_alive() or t.id in p.hit_ids or not owner.is_hostile_to(t):
					continue
				var d := Vector2(t.position.x, t.position.z).distance_to(Vector2(p.position.x, p.position.z))
				if d <= t.radius + p.radius:
					p.hit_ids.append(t.id)
					var from: Vector3 = t.position - p.direction        # projétil vem de onde voa, não de quem atirou
					var fm := Combat.frost_mult(p.skill, t) * _legend_power(owner, t)
					var r := Combat.calc_damage(owner, t, p.power * fm, p.skill.kind, rng, from)
					var dk := "magical" if p.skill.kind == SkillDef.Kind.MAGICAL else "physical"
					_deal_damage(owner, t, r["amount"], r["crit"], r["blocked"], "shatter" if Combat.frost_mult(p.skill, t) > 1.0 and dk == "magical" else dk, from)
					_legend_on_hit(owner, t, p.skill, int(r["amount"]))
					owner.combat_timer = Balance.AGGRO_LOSE_TIME
					_apply_effects(owner, t, p.effects, p.power)
					_storm_proc(owner, p.skill, t)
					if p.skill.hit_stop_frames > 0 and (owner == player or t == player):
						Events.hit_stop.emit(p.skill.hit_stop_frames)
					if not p.pierce:
						remove = true
						break
		if remove:
			projs.erase(p)
			Events.projectile_removed.emit(p.id)

# ----------------------------------------------------------------------------
# DANO / CURA / MORTE
# ----------------------------------------------------------------------------
func _deal_damage(attacker: SimEntity, target: SimEntity, amount: int, crit: bool, blocked: bool, kind: String, from: Variant = null) -> void:
	if not target.is_alive():
		return
	var in_arc := Combat.in_guard_arc(target, attacker.position if from == null else from)
	var parried: bool = target.parry_left > 0.0 and target.is_blocking and attacker != target and not kind.begins_with("dot") and in_arc
	if target.is_blocking and not in_arc and not kind.begins_with("dot") and attacker != target:
		Events.guard_flanked.emit(target.id)
	if parried:
		blocked = true
		amount = maxi(1, int(round(amount * (1.0 - Balance.PARRY_REDUCTION / 100.0))))
		target.parry_left = 0.0
	# levou um golpe (não dano no tempo): cai do cavalo
	if target.mounted and not kind.begins_with("dot") and attacker != target:
		dismount(target)
	if target.is_character():
		target.combat_timer = maxf(target.combat_timer, Balance.MOUNT_COMBAT_LOCK)
	# maldições: alvo amaldiçoado recebe mais, atacante enfraquecido causa menos
	var taken := Combat.curse_sum(target, "taken_pct")
	var weak := Combat.curse_sum(attacker, "weaken_pct")
	if taken > 0.0 or weak > 0.0:
		amount = maxi(1, int(round(amount * (1.0 + taken / 100.0) * (1.0 - minf(weak, Balance.CURSE_WEAKEN_CAP) / 100.0))))
	# esquiva (Assassino): o golpe direto não pega
	if not kind.begins_with("dot") and attacker != target and target.is_character() and target.stats.evasion > 0.0 and rng.randf() * 100.0 < target.stats.evasion:
		if kind != "riposte" and str(target.stats.legend.get("kind", "")) == "riposte" and attacker.is_alive() and attacker.position.distance_to(target.position) <= 4.0:
			_deal_damage(target, attacker, maxi(1, int(target.stats.patk * float(target.stats.legend["pct"]) / 100.0)), false, false, "riposte")     # Duelista: esquivou, contra-ataca
		Events.dodged.emit(target.id)
		return
	# veneno na lâmina: golpe físico direto envenena (renova, não acumula)
	if kind == "physical" and attacker != target and attacker.is_character() and attacker.stats.hit_poison > 0.0:
		var pid := "blade_poison_%d" % attacker.id
		target.debuffs = target.debuffs.filter(func(dd): return dd.get("id") != pid)
		target.debuffs.append({"kind": "dot", "id": pid, "remaining": Balance.HIT_POISON_TIME, "dps": attacker.stats.hit_poison, "src": attacker.id})
	if target.shield_hp > 0.0:
		var absorbed := minf(target.shield_hp, float(amount))
		target.shield_hp -= absorbed
		amount -= int(absorbed)
	target.hp -= amount
	if amount > 0 and not kind.begins_with("dot") and attacker != target and attacker.is_character() and attacker.is_alive() and attacker.stats.lifesteal > 0.0:
		attacker.hp = minf(attacker.stats.max_hp, attacker.hp + amount * attacker.stats.lifesteal / 100.0)     # roubo de vida
	if amount > 0 and kind in ["magical", "shatter"] and attacker != target and attacker.is_character() and attacker.is_alive() and attacker.stats.radiance > 0.0:
		_radiance(attacker, amount)
	target.hit_flash = 0.12
	target.combat_timer = Balance.AGGRO_LOSE_TIME
	target.last_damage_from = attacker.id
	target.threat[attacker.id] = float(target.threat.get(attacker.id, 0.0)) + amount
	if target.kind == SimEntity.Kind.MONSTER:
		var who: int = attacker.owner_id if attacker.kind == SimEntity.Kind.SUMMON else attacker.id   # invocação conta para o dono, mesmo depois de expirar
		target.damage_by[who] = float(target.damage_by.get(who, 0.0)) + amount
		_retarget(target, attacker)
	Events.damage_dealt.emit(attacker.id, target.id, amount, crit, blocked, kind)
	if blocked:
		Events.blocked_hit.emit(target.id)
	if target.hp <= 0.0:
		target.hp = 0.0
		_kill(target, attacker)
	elif blocked and target.stats.has_shield:
		_shield_reaction(target, attacker, amount, parried, from)
	_legend_weapon(attacker, target, amount, kind)

## Multiplicador de dano da arma lendária no alvo (Carrasco: alvo com pouca vida apanha mais).
func _legend_power(e: SimEntity, t: SimEntity) -> float:
	var le: Dictionary = e.stats.legend if e.is_character() else {}
	if str(le.get("kind", "")) == "execute" and t.hp < t.stats.max_hp * float(le.get("below", 0.3)):
		return 1.0 + float(le["pct"]) / 100.0
	return 1.0

## Lança uma skill de graça (sem mana nem recarga) a partir de `e`, mirando em `aim`: os efeitos que "lançam" algo.
func _legend_cast(e: SimEntity, skill_id: String, aim: Vector3) -> void:
	var s: SkillDef = GameData.skills.get(skill_id)
	if s == null or not maps.has(e.map_id):
		return
	var keep := e.skill_aim
	e.skill_aim = aim
	_apply_skill(e, s, maps[e.map_id])
	e.skill_aim = keep

## Efeitos da arma lendária ao acertar (golpe direto de quem a usa). `s` = skill do golpe (o básico começa com "basic_").
func _legend_on_hit(e: SimEntity, t: SimEntity, s: SkillDef, amount: int) -> void:
	if not e.is_character() or e.stats.legend.is_empty() or amount <= 0 or not t.is_alive() and str(e.stats.legend.get("kind", "")) != "splash":
		return
	var le: Dictionary = e.stats.legend
	var basic: bool = s != null and s.id.begins_with("basic_")
	match str(le.get("kind", "")):
		"cast_on_basic":
			if basic and t.is_alive() and rng.randf() * 100.0 < float(le["chance"]):
				_legend_cast(e, str(le["skill"]), t.position)
		"chain":
			if basic:
				var left: int = int(le.get("targets", 1))
				for o in maps[e.map_id]["entities"]:
					if left <= 0:
						break
					if o != t and o.is_alive() and e.is_hostile_to(o) and o.position.distance_to(t.position) <= 6.0:
						_deal_damage(e, o, maxi(1, int(amount * float(le["pct"]) / 100.0)), false, false, "chain")
						left -= 1
		"splash":
			if basic:
				for o in maps[e.map_id]["entities"]:
					if o != t and o.is_alive() and e.is_hostile_to(o) and o.position.distance_to(t.position) <= float(le.get("radius", 2.5)):
						_deal_damage(e, o, maxi(1, int(amount * float(le["pct"]) / 100.0)), false, false, "splash")
		"stun":
			if t.is_alive() and time >= e.legend_ready_at and rng.randf() * 100.0 < float(le["chance"]):
				e.legend_ready_at = time + float(le.get("icd", 6.0))
				_apply_effects(e, t, {"stun": {"duration": float(le["dur"])}}, 0.0)
		"frenzy":
			var fb: Array = e.buffs.filter(func(b): return b.get("id") == "legend_frenzy")
			var n: int = mini(int(le.get("max", 5)), (int(fb[0].get("stacks", 0)) if not fb.is_empty() else 0) + 1)
			e.buffs = e.buffs.filter(func(b): return b.get("id") != "legend_frenzy")
			e.buffs.append({"id": "legend_frenzy", "remaining": 4.0, "stacks": n, "aspd_pct": float(le["pct"]) * n})
			e.recompute_stats()
		"bleed", "poison":
			if t.is_alive() and rng.randf() * 100.0 < float(le["chance"]):
				var did := "legend_%s_%d" % [le["kind"], e.id]
				t.debuffs = t.debuffs.filter(func(d): return d.get("id") != did)       # renova, não acumula
				t.debuffs.append({"kind": "dot", "id": did, "remaining": 3.0, "dps": maxf(1.0, e.stats.patk * float(le["pct"]) / 100.0), "src": e.id})
		"mark":
			if t.is_alive():
				_apply_effects(e, t, {"curse": {"id": "legend_mark", "duration": 4.0, "taken_pct": float(le["pct"])}}, 0.0)

## Arma lendária: Eco (o golpe direto bate de novo), Retaliação (devolve parte do corpo a corpo recebido). Eco e
## retaliação não disparam a si mesmos.
func _legend_weapon(attacker: SimEntity, target: SimEntity, amount: int, kind: String) -> void:
	if amount <= 0 or attacker == target or not (kind in ["physical", "magical", "shatter"]):
		return
	if target.is_character() and target.is_alive() and str(target.stats.legend.get("kind", "")) == "cast_when_hit" and time >= target.legend_ready_at:
		target.legend_ready_at = time + float(target.stats.legend.get("icd", 20.0))      # Coração de Gelo / Casca Viva
		_legend_cast(target, str(target.stats.legend["skill"]), attacker.position)
	if attacker.is_character() and str(attacker.stats.legend.get("kind", "")) == "echo" and attacker.stats.echo_chance > 0.0 and target.is_alive() and rng.randf() * 100.0 < attacker.stats.echo_chance:
		_deal_damage(attacker, target, maxi(1, int(amount * attacker.stats.echo_pct / 100.0)), false, false, "echo")
	if kind == "physical" and target.is_character() and target.is_alive() and attacker.is_alive() and target.stats.thorns_pct > 0.0 \
			and attacker.position.distance_to(target.position) <= Balance.LEG_THORNS_RANGE:
		_deal_damage(target, attacker, maxi(1, int(amount * target.stats.thorns_pct / 100.0)), false, false, "thorns")

func _heal(src: SimEntity, target: SimEntity, amount: int) -> void:
	if not target.is_alive() or amount <= 0:
		return
	var before := target.hp
	target.hp = minf(target.stats.max_hp, target.hp + amount * target.heal_factor())
	Events.healed.emit(src.id, target.id, int(target.hp - before))
	if src.is_character() and src.stats.ward_pct > 0.0:      # arma lendária de cura: Égide (parte da cura vira barreira)
		target.shield_hp = minf(target.shield_hp + amount * src.stats.ward_pct / 100.0, target.stats.max_hp * 0.3)
		var sb: Array = target.buffs.filter(func(b): return b.get("id") == "shield")
		if sb.is_empty():
			target.buffs.append({"id": "shield", "remaining": Balance.LEG_WARD_TIME})
		else:
			sb[0]["remaining"] = maxf(float(sb[0]["remaining"]), Balance.LEG_WARD_TIME)

func _kill(e: SimEntity, killer: SimEntity) -> void:
	e.mounted = false
	e.is_blocking = false
	e.form = ""
	e.stealth_left = 0.0
	e.ambush = false
	e.current_skill = null
	e.buffs.clear()
	e.debuffs.clear()
	e.shield_hp = 0.0
	e.set_state(SimEntity.State.DEAD)
	e.dead_time = 0.0
	Events.entity_died.emit(e.id, killer.id if killer else -1)
	if e.kind == SimEntity.Kind.MONSTER:
		_on_monster_killed(e, killer)
	elif e.kind == SimEntity.Kind.PLAYER:
		Events.notification.emit("Você morreu. Renascendo em %s..." % map_def(GameData.town_map_id()).name)
		var loss := int(e.xp * Balance.DEATH_XP_PENALTY)
		e.xp = maxi(0, e.xp - loss)
	elif e.kind == SimEntity.Kind.BOT:
		if rng.randf() < 0.5:
			Events.chat_message.emit(e.name, GameData.random_bot_line("death"), "global")

func _on_monster_killed(mob: SimEntity, killer: SimEntity) -> void:
	var m: Dictionary = maps[mob.map_id]
	# XP para quem mais bateu (grupo soma) + dono da invocação
	var credit := top_damager(mob, killer)
	if credit and credit.is_character():
		# XP dividida com o grupo por perto (+bônus por membro); cada um ganha conforme o próprio nível
		var sharers := kill_sharers(credit, mob)
		var each := mob.monster_def.xp * (1.0 + Balance.PARTY_XP_BONUS * (sharers.size() - 1)) / sharers.size()
		for c in sharers:
			var mult := clampf(1.0 + (mob.level - c.level) * 0.08, 0.3, 1.6)
			gain_xp(c, int(each * mult))
			QuestSystem.on_kill(c, mob.monster_def.elite_of if mob.monster_def.elite_of != "" else mob.monster_def.id)
			if mob.monster_def.is_boss:
				c.bosses_killed[mob.monster_def.id] = true
		# loot
		var lt: LootTable = GameData.loot_tables.get(mob.monster_def.loot_table)
		var gold := rng.randi_range(mob.monster_def.gold_min, mob.monster_def.gold_max) * (3 if mob.monster_def.is_boss else 1)
		var drops := {}
		if lt:
			drops = lt.roll(rng)
		if gold > 0 and sharers.size() > 1:
			_split_gold(sharers, gold)
		elif gold > 0:
			drops["gold"] = gold
		# jogador no grupo: o saque dele é pessoal (rola a tabela só para ele a cada abate dividido, mesmo sem ter batido:
		# suporte também ganha); o saque comum gira entre os bots. Sem jogador no grupo, gira entre todos.
		var with_player: bool = player != null and player in sharers and sharers.size() > 1
		var bots_share: Array = sharers.filter(func(c): return c.kind != SimEntity.Kind.PLAYER)
		var mine := {}
		if with_player and mob.boss_id < 0:
			if lt:
				mine = lt.roll(rng)
			var my_worn := roll_gear(player, mob)
			if my_worn != "":
				mine[my_worn] = 1
		var looter := _next_looter(credit, bots_share if with_player and not bots_share.is_empty() else sharers)
		if with_player and looter == player:
			drops.clear()                       # o jogador já recebeu o seu
		var worn := roll_gear(looter, mob) if mob.boss_id < 0 and looter != player else ""      # lacaio de chefe não é fonte de saque
		if worn != "":
			drops[worn] = 1
		var personal: Array = []                 # lendário é pessoal: cada um rola o seu (o grupo não divide a chance)
		if mob.boss_id < 0:
			for c in sharers:
				var leg := roll_legendary(c, mob)
				if leg == "":
					continue
				var coins: int = Balance.LEGENDARY_COINS_BOSS if mob.monster_def.is_boss else 1
				personal.append([leg, c, coins])
				if c == player:
					Events.notification.emit("✦ %d Moeda%s Lendária%s! Troque com a Relicária em Aldara" % [coins, "s" if coins > 1 else "", "s" if coins > 1 else ""])
				elif c.kind == SimEntity.Kind.BOT:
					Events.chat_message.emit(c.name, "DROPOU MOEDA LENDÁRIA!!!", "global")
		var i := 0
		for item_id in drops:
			var off := Vector3(cos(i * 1.7) * 0.5, 0.0, sin(i * 1.7) * 0.5)
			m["loot"].append({"pos": mob.position + off, "item": item_id, "count": int(drops[item_id]), "timer": 45.0, "owner": looter.id, "free_at": time + Balance.LOOT_LOCK_TIME})
			Events.loot_dropped.emit(mob.map_id, mob.position + off, item_id, int(drops[item_id]))
			i += 1
		for item_id in mine:                   # saque pessoal do jogador no grupo
			var off := Vector3(cos(i * 1.7) * 0.6, 0.0, sin(i * 1.7) * 0.6)
			m["loot"].append({"pos": mob.position + off, "item": item_id, "count": int(mine[item_id]), "timer": 60.0, "owner": player.id, "free_at": time + Balance.LOOT_LOCK_TIME * 2.0})
			Events.loot_dropped.emit(mob.map_id, mob.position + off, item_id, int(mine[item_id]))
			i += 1
		for pl in personal:                     # lendário fica preso ao dono por mais tempo (ninguém pega o seu)
			var off := Vector3(cos(i * 1.7) * 0.6, 0.0, sin(i * 1.7) * 0.6)
			m["loot"].append({"pos": mob.position + off, "item": pl[0], "count": int(pl[2]), "timer": 120.0, "owner": pl[1].id, "free_at": time + 110.0})
			Events.loot_dropped.emit(mob.map_id, mob.position + off, pl[0], int(pl[2]))
			i += 1
	# remove do spawner
	for sp in m["spawners"]:
		sp["alive"].erase(mob.id)
	if credit and credit.is_character():
		_count_kill(m, mob)
		_legend_on_kill(credit, mob)

## Arma lendária no abate: Legião levanta um esqueleto (com recarga), Ceifa cura.
func _legend_on_kill(e: SimEntity, mob: SimEntity) -> void:
	var le: Dictionary = e.stats.legend
	match str(le.get("kind", "")):
		"raise_on_kill":
			if time >= e.legend_ready_at and GameData.monsters.has("skeleton_minion"):
				e.legend_ready_at = time + float(le.get("icd", 12.0))
				spawn_summon(e, GameData.monsters["skeleton_minion"], mob.position, float(le.get("time", 15.0)), true)
		"heal_on_kill":
			_heal(e, e, int(e.stats.max_hp * float(le["pct"]) / 100.0))

## Muitos abates do mesmo monstro comum num mapa: surge o Rei dele (5x mais forte, lendário garantido).
func _count_kill(m: Dictionary, mob: SimEntity) -> void:
	var md: MonsterDef = mob.monster_def
	if md.is_boss or md.elite_of != "" or md.xp <= 0 or mob.boss_id >= 0 or mob.kind != SimEntity.Kind.MONSTER:
		return
	var n: int = int(m["kills"].get(md.id, 0)) + 1
	var alive: SimEntity = entities.get(int(m["elites"].get(md.id, -1)))
	if alive and alive.is_alive():
		m["kills"][md.id] = 0                  # com o Rei vivo, não acumula outro
		return
	if n < Balance.ELITE_KILLS:
		m["kills"][md.id] = n
		return
	m["kills"][md.id] = 0
	var pos := mob.position
	var spots: Array = m["spawners"].filter(func(sp): return sp["def"]["monster_id"] == md.id)
	if not spots.is_empty():
		pos = spots[rng.randi() % spots.size()]["def"]["pos"]
	var king := spawn_monster(elite_def(md), mob.map_id, pos)
	m["elites"][md.id] = king.id
	var where: String = m["def"].name
	Events.chat_message.emit("Sistema", "%s surgiu em %s! (lendário garantido)" % [king.monster_def.name, where], "system")
	if player and player.map_id == mob.map_id:
		Events.notification.emit("👑 %s surgiu!" % king.monster_def.name)

var _elite_defs: Dictionary = {}

## Rei de um monstro comum (criado uma vez por tipo): mais vida, ataque e tamanho; a coroa é da apresentação (EntityView).
func elite_def(base: MonsterDef) -> MonsterDef:
	if _elite_defs.has(base.id):
		return _elite_defs[base.id]
	var d: MonsterDef = base.duplicate()
	d.id = base.id + "_rei"
	d.elite_of = base.id
	d.name = "Rei " + base.name
	d.level = base.level + 2
	d.hp = base.hp * Balance.ELITE_HP_MULT
	d.atk = base.atk * Balance.ELITE_ATK_MULT
	d.matk = base.matk * Balance.ELITE_ATK_MULT
	d.def = base.def * Balance.ELITE_DEF_MULT
	d.mdef = base.mdef * Balance.ELITE_DEF_MULT
	d.scale = base.scale * Balance.ELITE_SCALE
	d.radius = base.radius * 1.3
	d.xp = base.xp * Balance.ELITE_XP_MULT
	d.gold_min = base.gold_min * Balance.ELITE_GOLD_MULT
	d.gold_max = base.gold_max * Balance.ELITE_GOLD_MULT
	d.is_boss = true
	d.leash_range = maxf(base.leash_range, 25.0)
	_elite_defs[base.id] = d
	return d

## Quem mais causou dano e segue vivo no mapa: invocações contam para o dono e o grupo soma, para ninguém
## de fora roubar o abate de um grupo. Dentro do grupo vencedor, o maior dano leva o crédito.
func top_damager(mob: SimEntity, killer: SimEntity) -> SimEntity:
	var by_group := {}
	var best_of := {}
	for id in mob.damage_by:
		var o: SimEntity = entities.get(id)
		if o == null or not o.is_character() or not o.is_alive() or o.map_id != mob.map_id:
			continue
		var key := o.group_key()
		var dmg := float(mob.damage_by[id])
		by_group[key] = float(by_group.get(key, 0.0)) + dmg
		if not best_of.has(key) or dmg > float(mob.damage_by.get(best_of[key].id, 0.0)):
			best_of[key] = o
	var top := 0.0
	var out: SimEntity = null
	for key in by_group:
		if float(by_group[key]) > top:
			top = float(by_group[key])
			out = best_of[key]
	if out:
		return out
	return entities.get(killer.owner_id) if killer and killer.kind == SimEntity.Kind.SUMMON else killer

## Saque do grupo gira entre quem dividiu o abate; sozinho, fica com quem matou.
func _next_looter(credit: SimEntity, sharers: Array) -> SimEntity:
	if sharers.size() < 2:
		return credit
	var p := party_of(credit)
	var i := int(p.get("loot_next", 0))
	p["loot_next"] = i + 1
	var order: Array = party_members(credit).filter(func(o): return o in sharers)    # ordem do grupo: não muda com quem levou o abate
	return order[i % order.size()]

## O que o jogador enxerga no chão: o que é dele, ou o que ficou livre (o dono não pegou a tempo).
func loot_visible_to(e: SimEntity, l: Dictionary) -> bool:
	return e == null or int(l.get("owner", -1)) == e.id or int(l.get("owner", -1)) < 0 or time >= float(l.get("free_at", 0.0))

## Ouro do grupo vai direto para cada um, sem pilha no chão para disputar.
func _split_gold(sharers: Array, gold: int) -> void:
	var each := gold / sharers.size()
	var extra := gold % sharers.size()     # o resto vai um por um: nada some, nada é criado
	for i in range(sharers.size()):
		var share := each + (1 if i < extra else 0)
		sharers[i].gold += share
		if sharers[i] == player and share > 0:
			Events.notification.emit("+%d ouro (grupo)" % share)

## Calça/capa/amuleto/anel comum do maior tier que o nível do monstro alcança. Tiers baixos também estão na loja.
func roll_gear(killer: SimEntity, mob: SimEntity) -> String:
	if killer == null or not killer.is_character():
		return ""
	if rng.randf() >= (Balance.GEAR_DROP_CHANCE_BOSS if mob.monster_def.is_boss else Balance.GEAR_DROP_CHANCE):
		return ""
	var tier := 0
	for i in range(Balance.COMMON_TIER_LEVELS.size()):
		if Balance.COMMON_TIER_LEVELS[i] <= mob.level + Balance.LEGENDARY_LEVEL_SLACK:
			tier = i
	var pool: Array = gear_pool(tier).filter(func(it): return fits_class(killer, it))
	if pool.is_empty():
		pool = GearCatalog.wearables(tier)
	return pool[rng.randi() % pool.size()].id

var _gear_pools: Dictionary = {}

## Equipamento comum que cai de monstro no tier (armas, escudos, armaduras e calças; joias e capas são feitas na forja).
func gear_pool(tier: int) -> Array:
	if _gear_pools.has(tier):
		return _gear_pools[tier]
	var lo: int = Balance.COMMON_TIER_LEVELS[tier]
	var hi: int = Balance.COMMON_TIER_LEVELS[tier + 1] if tier + 1 < Balance.COMMON_TIER_LEVELS.size() else 99
	var out: Array = []
	for iid in GameData.items:
		var it: ItemDef = GameData.items[iid]
		if it.is_equipment() and not it.is_legendary() and it.set_id == "" and it.base_id == "" and it.price > 0 and it.level_req >= lo and it.level_req < hi \
				and not (it.slot in [ItemDef.Slot.CAPE, ItemDef.Slot.AMULET, ItemDef.Slot.RING]):
			out.append(it)
	_gear_pools[tier] = out
	return out

## A classe consegue usar (sem olhar o nível).
func fits_class(e: SimEntity, it: ItemDef) -> bool:
	if it.class_restriction.size() > 0 and not (e.class_def.id in it.class_restriction):
		return false
	if it.slot == ItemDef.Slot.WEAPON:
		return it.weapon_type in e.class_def.weapon_types
	if it.slot == ItemDef.Slot.OFFHAND:
		return it.weapon_type in e.class_def.offhand_types
	return true

# ----------------------------------------------------------------------------
# APRIMORAMENTO (ferreiro): +1..+9, sem chance de quebrar
# ----------------------------------------------------------------------------
## Tier da peça pelo nível dela (0..3).
func item_tier(it: ItemDef) -> int:
	var t := 0
	for i in range(Balance.COMMON_TIER_LEVELS.size()):
		if it.level_req >= Balance.COMMON_TIER_LEVELS[i]:
			t = i
	return t

## Custo para levar a peça ao próximo nível: {"gold", "item", "count"}.
func enhance_cost(it: ItemDef, current: int) -> Dictionary:
	var nxt := current + 1
	var tier := item_tier(it) + (1 if it.is_legendary() else 0)
	var mat := "star_ore" if nxt >= Balance.PLUS_STAR_FROM else "iron_ore"
	var n := (nxt - Balance.PLUS_STAR_FROM + 1) + tier if nxt >= Balance.PLUS_STAR_FROM else nxt + 1 + tier
	return {"gold": int(Balance.PLUS_GOLD_BASE * (tier + 1) * pow(nxt, 1.5)), "item": mat, "count": n}

## Por que não dá para aprimorar ("" = dá). slot >= 0: a peça vestida nesse slot; senão uma cópia da bolsa.
func enhance_error(e: SimEntity, item_id: String, slot: int = -1) -> String:
	var it: ItemDef = GameData.items.get(item_id)
	if it == null or not it.is_equipment():
		return "Só equipamento pode ser aprimorado"
	var owned: bool = (e.equipment.get(slot) != null and e.equipment[slot].id == item_id) if slot >= 0 else e.has_item(item_id)
	if not owned:
		return "Você não tem esse item"
	var cur := it.plus
	if cur >= Balance.PLUS_MAX:
		return "Já está no máximo (+%d)" % Balance.PLUS_MAX
	var c := enhance_cost(it, cur)
	if e.gold < int(c["gold"]):
		return "Ouro insuficiente (%d)" % int(c["gold"])
	if not e.has_item(c["item"], int(c["count"])):
		return "Faltam %d %s" % [int(c["count"]) - int(e.inventory.get(c["item"], 0)), GameData.items[c["item"]].name]
	return ""

## Aprimora UMA cópia em +1 (nunca quebra): ela vira a versão "+N" (as outras cópias não mudam).
## slot >= 0: a peça vestida nesse slot; senão uma cópia da bolsa. Devolve a versão nova (ou null).
func enhance(e: SimEntity, item_id: String, slot: int = -1) -> ItemDef:
	if enhance_error(e, item_id, slot) != "":
		return null
	var it: ItemDef = GameData.items[item_id]
	var base: ItemDef = GameData.items.get(it.base_id, it) if it.base_id != "" else it
	var c := enhance_cost(it, it.plus)
	e.gold -= int(c["gold"])
	e.remove_item(c["item"], int(c["count"]))
	var nxt := GameData.plus_item(base, it.plus + 1)
	if slot >= 0:
		e.equipment[slot] = nxt
	else:
		e.remove_item(item_id, 1)
		e.add_item(nxt.id, 1)
	e.recompute_stats()
	Events.equipment_changed.emit(e.id)
	if e == player:
		Events.notification.emit("%s pronto!" % nxt.name)
	return nxt

## Bolsa Ampliada: na ordem (I antes da II...), até Balance.BAG_UPGRADES.
func use_bag_upgrade(e: SimEntity, item_id: String) -> bool:
	var it: ItemDef = GameData.items.get(item_id)
	if it == null or not it.consume.has("bag") or not e.has_item(item_id):
		return false
	var want := int(it.consume["bag"])
	if want != e.bag_bonus:
		if e == player:
			Events.notification.emit("Use antes a Bolsa Ampliada %s" % ["I", "II", "III", "IV"][mini(e.bag_bonus, 3)] if want > e.bag_bonus else "Sua bolsa já é maior que esta")
		return false
	e.remove_item(item_id, 1)
	e.bag_bonus += 1
	if e == player:
		Events.notification.emit("Bolsa ampliada: %d espaços" % e.bag_capacity())
	return true

## Sorteia se cai lendário para quem matou: cai como Moeda Lendária (chefe/Rei: LEGENDARY_COINS_BOSS moedas).
func roll_legendary(killer: SimEntity, mob: SimEntity) -> String:
	if killer == null or not killer.is_character():
		return ""
	if rng.randf() >= legendary_chance(mob):
		return ""
	return "legend_coin"            # o lendário vira Moeda Lendária (troca na Relicária: WorldSim.relic_exchange)

## Relicária: peças lendárias que a classe pode trocar (todos os conjuntos das builds, a maça do conjunto e os escudos nomeados).
func relic_offer(e: SimEntity) -> Array:
	var out: Array = []
	for lv in Balance.LEGENDARY_LEVELS:
		out.append_array(GameData.legendary_pool(e.class_def, lv))
	if "shield" in e.class_def.offhand_types:
		for iid in GameData.items:
			var it: ItemDef = GameData.items[iid]
			if it.is_legendary() and it.weapon_type == "shield" and it.set_id == "" and (it.class_restriction.is_empty() or e.class_def.id in it.class_restriction) 					and GearCatalog.shield_fits(iid, e.class_def.id):
				out.append(iid)
	return out

## Preço em moedas: tier i de LEGENDARY_LEVELS custa i+1 (nível 5 = 1, nível 10 = 2, ...).
func relic_cost(it: ItemDef) -> int:
	var i := Balance.LEGENDARY_LEVELS.find(it.level_req)
	return (i if i >= 0 else Balance.LEGENDARY_LEVELS.size() - 1) + 1

## Por que não troca ("" = pode): perto da Relicária, peça da classe, nível e moedas.
func relic_block_reason(e: SimEntity, item_id: String) -> String:
	var it: ItemDef = GameData.items.get(item_id)
	if it == null or not (item_id in relic_offer(e)):
		return "peça indisponível para sua classe"
	if not near_station(e, "relic"):
		return "fale com a Relicária"
	if e.level < it.level_req:
		return "requer nível %d" % it.level_req
	var cost := relic_cost(it)
	if int(e.inventory.get("legend_coin", 0)) < cost:
		return "faltam moedas (%d)" % cost
	return ""

func relic_exchange(e: SimEntity, item_id: String) -> bool:
	var why := relic_block_reason(e, item_id)
	if why != "":
		if e == player:
			Events.notification.emit("Relicária: " + why)
		return false
	e.remove_item("legend_coin", relic_cost(GameData.items[item_id]))
	e.add_item(item_id, 1)
	if e == player:
		Events.notification.emit("★ LENDÁRIO: %s!" % GameData.items[item_id].name)
	return true

## Chance de lendário por monstro: chefe 25%; no primeiro mapa o 1º conjunto cai mais (1 em 50); no resto 1 em 200.
func legendary_chance(mob: SimEntity) -> float:
	if mob.monster_def.elite_of != "":
		return 1.0
	if mob.monster_def.is_boss:
		return Balance.LEGENDARY_DROP_CHANCE_BOSS
	if mob.map_id == Balance.LEGENDARY_START_MAP and mob.level + Balance.LEGENDARY_LEVEL_SLACK < Balance.LEGENDARY_LEVELS[1]:
		return Balance.LEGENDARY_START_MAP_CHANCE
	return Balance.LEGENDARY_DROP_CHANCE

## Só oferece escudo a quem pode usar um com a arma atual (Inquisidor e Cruzado de duas mãos, não).
func _uses_shield(e: SimEntity) -> bool:
	var w: ItemDef = e.equipment.get(ItemDef.Slot.WEAPON)
	if w == null or w.is_two_handed():
		return false
	return e.class_def.builds.any(func(b): return w.weapon_type in b["main"] and "shield" in b["off"])

func pick_legendary(killer: SimEntity, mob_level: int) -> String:
	var tier_level := 0
	for lv in Balance.LEGENDARY_LEVELS:
		if lv <= mob_level + Balance.LEGENDARY_LEVEL_SLACK:
			tier_level = lv
	if tier_level == 0:
		return ""
	if _uses_shield(killer) and rng.randf() < Balance.SHIELD_LEGENDARY_SHARE:
		var shields: Array = GearCatalog.SHIELDS.filter(func(d): return d[2] <= tier_level and GearCatalog.shield_fits("shield_" + d[0], killer.class_def.id))
		if shields.is_empty():
			shields = GearCatalog.SHIELDS.filter(func(d): return d[2] <= tier_level)
		return "shield_" + shields[rng.randi() % shields.size()][0]
	var build_id := ""
	if rng.randf() < 0.7:
		var fits: Array = killer.class_def.builds.filter(func(b): return killer.stats.weapon_type in b["main"])
		if fits.size() > 0:
			build_id = fits[rng.randi() % fits.size()]["id"]
	var pool := GameData.legendary_pool(killer.class_def, tier_level, build_id)
	if pool.is_empty():
		pool = GameData.legendary_pool(killer.class_def, tier_level)
	return pool[rng.randi() % pool.size()] if pool.size() > 0 else ""

func gain_xp(e: SimEntity, amount: int) -> void:
	if e.level >= Balance.MAX_LEVEL:
		return
	e.xp += amount
	Events.xp_gained.emit(e.id, amount)
	while e.level < Balance.MAX_LEVEL and e.xp >= Balance.xp_for_level(e.level):
		e.xp -= Balance.xp_for_level(e.level)
		e.level += 1
		e.mastery_points += Balance.MASTERY_POINTS_PER_LEVEL + (1 if e.level in Balance.MASTERY_BONUS_LEVELS else 0)
		e.recompute_stats()
		e.hp = minf(e.stats.max_hp, e.hp + e.stats.max_hp * 0.3)
		e.mp = minf(e.stats.max_mp, e.mp + e.stats.max_mp * 0.3)
		Events.level_up.emit(e.id, e.level)
		if e == player:
			Events.notification.emit("Nível %d! +%d ponto(s) de skill (tecla K)" % [e.level, Balance.MASTERY_POINTS_PER_LEVEL + (1 if e.level in Balance.MASTERY_BONUS_LEVELS else 0)])
		elif e.kind == SimEntity.Kind.BOT and rng.randf() < 0.35:
			Events.chat_message.emit(e.name, GameData.random_bot_line("levelup") % e.level, "global")
		if e.level == Balance.MAX_LEVEL:
			e.xp = 0

func respawn_character(e: SimEntity) -> void:
	var town := GameData.town_map_id()
	e.hp = e.stats.max_hp * 0.5
	e.mp = e.stats.max_mp * 0.5
	e.set_state(SimEntity.State.IDLE)
	e.threat.clear()
	var def := map_def(town)
	_change_map(e, town, def.spawn_point)
	Events.entity_respawned.emit(e.id)

# ----------------------------------------------------------------------------
# UPDATE POR ENTIDADE
# ----------------------------------------------------------------------------
func _update_entity(e: SimEntity, m: Dictionary, dt: float) -> void:
	e.state_time += dt
	e.hit_flash = maxf(0.0, e.hit_flash - dt)
	if e.kind == SimEntity.Kind.NPC:
		_update_npc(e, m, dt)
		return
	# cooldowns
	e.basic_cd = maxf(0.0, e.basic_cd - dt)
	e.parry_left = maxf(0.0, e.parry_left - dt)
	e.parry_cd = maxf(0.0, e.parry_cd - dt)
	e.shield_react_cd = maxf(0.0, e.shield_react_cd - dt)
	e.grace_cd = maxf(0.0, e.grace_cd - dt)
	e.potion_cd = maxf(0.0, e.potion_cd - dt)
	e.dash_cd = maxf(0.0, e.dash_cd - dt)
	e.combat_timer = maxf(0.0, e.combat_timer - dt)
	e.stealth_left = maxf(0.0, e.stealth_left - dt)
	# pulo: gravidade até voltar ao chão
	if e.airborne():
		e.jump_v -= Balance.JUMP_GRAVITY * dt
		e.jump_h += e.jump_v * dt
		if e.jump_h <= 0.0:
			e.jump_h = 0.0
			e.jump_v = 0.0
	for k in e.cooldowns.keys():
		e.cooldowns[k] = maxf(0.0, e.cooldowns[k] - dt)
	if e.state == SimEntity.State.DEAD:
		e.dead_time += dt
		if e.kind == SimEntity.Kind.MONSTER or e.kind == SimEntity.Kind.SUMMON:
			if e.dead_time >= Balance.CORPSE_TIME:
				despawn(e)
		elif e.dead_time >= Balance.PLAYER_RESPAWN_TIME + (2.0 if e.kind == SimEntity.Kind.BOT else 0.0):
			respawn_character(e)
		return
	# invocação expira
	if e.kind == SimEntity.Kind.SUMMON and time >= e.summon_expires:
		despawn(e)
		return
	# lacaio sem chefe (morto ou resetado) some
	if e.boss_id >= 0:
		var boss: SimEntity = entities.get(e.boss_id)
		if boss == null or not boss.is_alive() or boss.adds_epoch != e.adds_epoch:
			despawn(e)
			return
	# buffs / debuffs
	var recompute := false
	for b in e.buffs.duplicate():
		b["remaining"] = float(b.get("remaining", 0)) - dt
		if b["remaining"] <= 0.0:
			e.buffs.erase(b)
			if b.get("id") == "shield":
				e.shield_hp = 0.0
			recompute = true
	for d in e.debuffs.duplicate():
		d["remaining"] = float(d.get("remaining", 0)) - dt
		if d.get("kind") == "dot":
			d["acc"] = float(d.get("acc", 0.0)) + float(d["dps"]) * dt
			if d["acc"] >= 1.0:
				var dmg := int(d["acc"])
				d["acc"] -= dmg
				var src: SimEntity = entities.get(int(d.get("src", -1)))
				if src:
					_deal_damage(src, e, dmg, false, false, "dot_fire" if d.get("fire", false) else "dot")
					if not e.is_alive():
						return
		if d["remaining"] <= 0.0:
			e.debuffs.erase(d)
	if recompute:
		e.recompute_stats()
	# regen
	if e.combat_timer <= 0.0 and e.is_character():
		e.hp = minf(e.stats.max_hp, e.hp + e.stats.max_hp * 0.02 * dt)
	if not e.is_blocking:
		e.mp = minf(e.stats.max_mp, e.mp + (e.stats.max_mp * 0.015 + 1.0) * dt)
	# estados
	match e.state:
		SimEntity.State.CASTING:
			_update_skill(e, m, dt)
		SimEntity.State.DASHING:
			var dp: Dictionary = e.dash_params if not e.dash_params.is_empty() else dash_params(e)
			var step: Vector3 = e.dash_dir * (Balance.DASH_DISTANCE * float(dp["distance"]) / Balance.DASH_TIME) * dt
			if dp["ghost"]:
				_move_ghost(e, step, m)
			else:
				_move(e, step, m)
			if e.state_time >= e.state_duration:
				e.set_state(SimEntity.State.IDLE)
				_dash_arrive(e, dp, m)
		SimEntity.State.STUNNED:
			if e.state_time >= e.state_duration:
				e.set_state(SimEntity.State.IDLE)
		_:
			pass
	if e.kind == SimEntity.Kind.MONSTER and not e.monster_def.phases.is_empty():
		_update_boss(e)
	# aggro
	if e.kind == SimEntity.Kind.MONSTER and (e.aggro_target >= 0 or not e.damage_by.is_empty()):
		e.aggro_timer -= dt
		e.taunt_left = maxf(0.0, e.taunt_left - dt)
		var t: SimEntity = entities.get(e.aggro_target)
		if e.aggro_target >= 0 and (t == null or not t.is_alive() or t.map_id != e.map_id or e.aggro_timer <= 0.0):
			e.aggro_target = -1
			e.taunt_left = 0.0
			e.threat.clear()
		if e.aggro_timer <= 0.0:       # alvo morto não encerra a luta; o tempo sem levar golpe, sim
			e.damage_by.clear()
	# portais (personagens vivos)
	if e.is_character():
		_check_portals(e, m)
	if e.kind == SimEntity.Kind.PLAYER and (tick_count + e.id) % 10 == 0:
		QuestSystem.on_position(e)
	# separação entre entidades (empurrão suave), em ticks alternados
	if (tick_count + e.id) % 2 == 0:
		_separate(e, m)

func use_potion(e: SimEntity, slot: int) -> bool:
	if slot < 0 or slot > 2 or e.potion_cd > 0.0:
		return false
	var item_id: String = e.potion_slots[slot]
	if item_id == "" or not e.has_item(item_id):
		if e == player:
			Events.notification.emit("Sem poção nesse slot")
		return false
	var item: ItemDef = GameData.items[item_id]
	e.remove_item(item_id, 1)
	e.potion_cd = item.consume_cooldown
	var c := item.consume
	if c.has("heal"):
		_heal(e, e, int(c["heal"]))
	if c.has("heal_pct"):
		_heal(e, e, int(e.stats.max_hp * float(c["heal_pct"])))
	if c.has("mana"):
		e.mp = minf(e.stats.max_mp, e.mp + float(c["mana"]))
	if c.has("mana_pct"):
		e.mp = minf(e.stats.max_mp, e.mp + e.stats.max_mp * float(c["mana_pct"]))
	if c.has("buff"):
		_apply_effects(e, e, {"buff": c["buff"]}, 1.0)
	Events.potion_used.emit(e.id, slot)
	return true

# ----------------------------------------------------------------------------
# MOVIMENTO / COLISÃO (dados do MapDef)
# ----------------------------------------------------------------------------
func _move(e: SimEntity, delta: Vector3, m: Dictionary) -> void:
	var def: MapDef = m["def"]
	var p := e.position + delta
	p.y = 0.0
	p = def.clamp_inside(p, e.radius)
	p = _resolve_obstacles(p, e.radius, m)
	e.position = p

## Investida: anda reto em passos curtos e para no primeiro obstáculo, sem deslizar (a faixa do golpe é reta).
## Devolve true se foi barrada.
func _charge(e: SimEntity, delta: Vector3, m: Dictionary) -> bool:
	_move(e, Vector3.ZERO, m)               # empurrão de multidão pode deixar colado na parede: sai antes de medir
	var start := e.position
	var steps := maxi(1, ceili(delta.length() / Balance.DASH_SKILL_STEP))
	var step := delta / steps
	for i in range(steps):
		var before := e.position
		_move(e, step, m)
		if e.position.distance_squared_to(start + step * (i + 1)) > 0.0004:
			e.position = before
			return true
	return false

## A investida de `e` na direção de `t` chegaria nele? Para quem decide lançar (bots e monstros) não gastar à toa.
func charge_lands(e: SimEntity, s: SkillDef, t: SimEntity, m: Dictionary) -> bool:
	var saved := e.position
	var to := t.position - saved
	to.y = 0.0
	if to.length() < 0.01:
		return true
	var dir := to.normalized()
	var dash := float(s.effects["dash"])
	var stopped := _charge(e, dir * dash, m)
	var lane := maxf(0.0, (e.position - saved).dot(dir)) + (0.0 if stopped else maxf(0.0, s.range - dash))
	e.position = saved
	return to.length() <= lane + t.radius

## Movimento que atravessa obstáculos (dash "fantasma"); só resolve colisão se terminar dentro de um.
func _move_ghost(e: SimEntity, delta: Vector3, m: Dictionary) -> void:
	var def: MapDef = m["def"]
	var p := e.position + delta
	p.y = 0.0
	e.position = def.clamp_inside(p, e.radius)
	if e.state_time + 1.0 / 60.0 >= e.state_duration:
		e.position = _resolve_obstacles(e.position, e.radius, m)

# ----------------------------------------------------------------------------
# DASH + EVOLUÇÕES
# ----------------------------------------------------------------------------
## Parâmetros do dash do personagem com as evoluções compradas (e cuja arma exigida ele empunha).
func dash_params(e: SimEntity) -> Dictionary:
	var dp := {"distance": 1.0, "charges": 1, "ghost": false, "cooldown_mult": 1.0, "stun": 0.0,
		"power": 0.0, "radius": 0.0, "heal_pct": 0.0, "buff": null, "slow": null}
	if not e.is_character():
		return dp
	for tid in e.talents:
		var t: TalentDef = GameData.talents.get(tid)
		if t == null or t.skill_id != TalentDef.DASH or not e.stats.meets(t.requires):
			continue
		var md := t.mods
		dp["distance"] *= float(md.get("distance_mult", 1.0))
		dp["cooldown_mult"] *= float(md.get("cooldown_mult", 1.0))
		dp["charges"] = maxi(int(dp["charges"]), int(md.get("charges", 1)))
		dp["ghost"] = dp["ghost"] or bool(md.get("ghost", false))
		dp["stun"] = maxf(dp["stun"], float(md.get("stun", 0.0)))
		dp["power"] += float(md.get("power", 0.0))
		dp["radius"] = maxf(dp["radius"], float(md.get("radius", 0.0)))
		dp["heal_pct"] += float(md.get("heal_pct", 0.0))
		if md.has("buff"):
			dp["buff"] = md["buff"]
		if md.has("slow"):
			dp["slow"] = md["slow"]
	return dp

## Efeitos ao fim do dash: dano/atordoar/lentidão em volta, cura, buff.
func _dash_arrive(e: SimEntity, dp: Dictionary, m: Dictionary) -> void:
	e.dash_params = {}
	if float(dp["heal_pct"]) > 0.0:
		_heal(e, e, int(e.stats.max_hp * float(dp["heal_pct"]) / 100.0))
	if dp["buff"] != null:
		_apply_effects(e, e, {"buff": dp["buff"]}, 0.0)
	var r: float = dp["radius"] if float(dp["radius"]) > 0.0 else (1.4 if float(dp["stun"]) > 0.0 else 0.0)
	if r <= 0.0:
		return
	var effects := {}
	if float(dp["stun"]) > 0.0:
		effects["stun"] = {"duration": dp["stun"]}
	if dp["slow"] != null:
		effects["slow"] = dp["slow"]
	Events.skill_effect.emit("dash", e.position, e.position, r)
	for t in m["entities"]:
		if not e.is_hostile_to(t) or not t.is_alive() or t.position.distance_to(e.position) > r + t.radius:
			continue
		if float(dp["power"]) > 0.0:
			var res := Combat.calc_damage(e, t, float(dp["power"]), SkillDef.Kind.PHYSICAL, rng)
			_deal_damage(e, t, res["amount"], res["crit"], res["blocked"], "physical")
		_apply_effects(e, t, effects, float(dp["power"]))

## Cópia da skill com as evoluções do personagem aplicadas (só as cuja arma exigida ele empunha).
## Sem evolução ativa devolve a própria skill (sem alocação).
func resolve_skill(e: SimEntity, s: SkillDef) -> SkillDef:
	var out := _resolve_talents(e, s)
	var fm: Dictionary = SkillsCatalog.FORM_MODS.get(s.id, {}).get(e.form, {}) if e.form != "" else {}
	if fm.is_empty():
		return out
	out = out.duplicate()          # forma de animal: a skill vira o golpe do bicho
	out.talent_effects = out.talent_effects.duplicate()
	if fm.has("name"):
		out.name = fm["name"]
	for k in fm.get("set", {}):
		out.set(k, fm["set"][k])
	for k in fm.get("mult", {}):
		out.set(k, float(out.get(k)) * float(fm["mult"][k]))
	for k in fm.get("effects", {}):
		out.talent_effects[k] = fm["effects"][k]
	return out

func _resolve_talents(e: SimEntity, s: SkillDef) -> SkillDef:
	if not e.is_character() or e.talents.is_empty():
		return s
	var out: SkillDef = null
	for tid in e.talents:
		var t: TalentDef = GameData.talents.get(tid)
		if t == null or t.skill_id != s.id or not e.stats.meets(t.requires):
			continue
		if out == null:
			out = s.duplicate()
			out.talent_effects = {}
		var md := t.mods
		var sets: Dictionary = md.get("set", {})
		for k in sets:
			out.set(k, sets[k])
		var mults: Dictionary = md.get("mult", {})
		for k in mults:
			out.set(k, float(out.get(k)) * float(mults[k]))
		var fx: Dictionary = md.get("effects", {})
		for k in fx:
			out.talent_effects[k] = fx[k]
	return out if out else s

## Texto pt-BR de uma exigência de arma ("escudo", "duas espadas"...).
static func requires_text(req: Array) -> String:
	var names := {"shield": "escudo", "orb": "orbe", "dual": "duas armas de 1 mão", "two_handed": "arma de duas mãos",
		"sword": "espada", "sword2h": "montante", "mace": "maça", "mace2h": "martelo de duas mãos", "axe": "machadinha",
		"axe2h": "machado de duas mãos", "dagger": "adaga", "bow": "arco", "staff": "cajado", "wand": "varinha", "scythe": "foice", "scepter": "cetro", "rifle": "mosquete"}
	var plural := {"sword": "duas espadas", "mace": "duas maças", "axe": "dois machados", "dagger": "duas adagas"}
	var parts: Array = []
	for r in req:
		if r.begins_with("dual_"):
			parts.append(plural.get(r.substr(5), r))
		else:
			parts.append(names.get(r, r))
	return " ou ".join(parts)

const GRID_CELL := 12.0

## Pré-computa colisores (círculo ou caixa rotacionada) e os indexa numa grade espacial.
## Água também é sólida: rio vira uma corrente de caixas curtas (com vão onde uma estrada cruza = ponte)
## e lago vira círculo; nada disso é "alto" (projéteis passam por cima).
func _build_collider_grid(m: Dictionary) -> void:
	var def: MapDef = m["def"]
	var cols: Array = []
	var grid: Dictionary = {}
	for ob in def.obstacles:
		if not ob.get("solid", true):
			continue
		var kind: String = ob.get("kind", "house")
		if kind == "water":
			continue            # o lago vem de def.water (círculo, não o quadrado antigo)
		var pos: Vector3 = ob["pos"]
		var size: Vector3 = ob.get("size", Vector3.ONE)
		var circle: bool = kind in ["tree", "rock", "pillar", "well", "fountain", "lamp", "statue", "pine", "dead_tree", "stump", "hill"]
		_add_collider(cols, grid, {"circle": circle, "x": pos.x, "z": pos.z, "cr": maxf(size.x, size.z) * 0.5,
			"hx": size.x * 0.5, "hz": size.z * 0.5, "rot": deg_to_rad(float(ob.get("rot", 0.0))), "tall": size.y > 1.2})
	var bridges := water_crossings(def)
	m["bridges"] = bridges
	for w in def.water:
		if w["kind"] == "lake":
			var c: Vector2 = w["pos"]
			_add_collider(cols, grid, {"circle": true, "x": c.x, "z": c.y, "cr": float(w["r"]) - WATER_SHORE, "hx": 0.0, "hz": 0.0, "rot": 0.0, "tall": false})
			continue
		var pts: PackedVector2Array = w["pts"]
		var half_w: float = float(w["w"]) * 0.5 - WATER_SHORE
		for i in range(pts.size() - 1):
			var a := pts[i]
			var b := pts[i + 1]
			var seg_len := a.distance_to(b)
			var n := maxi(1, ceili(seg_len / RIVER_PIECE))
			var dir := (b - a) / seg_len if seg_len > 0.001 else Vector2.RIGHT
			for k in range(n):
				var c := a.lerp(b, (k + 0.5) / n)
				var on_bridge := false
				for br in bridges:
					if br["pos"].distance_to(c) < BRIDGE_HALF + seg_len / n * 0.5 + 0.35:
						on_bridge = true
						break
				if on_bridge:
					continue
				# caixa alinhada ao trecho (um pouco mais longa para não deixar fresta entre peças)
				_add_collider(cols, grid, {"circle": false, "x": c.x, "z": c.y, "cr": 0.0, "hx": seg_len / n * 0.5 + 0.35, "hz": half_w,
					"rot": -dir.angle(), "tall": false})
	m["colliders"] = cols
	m["grid"] = grid
	_build_water_graph(m)

const WATER_SHORE := 0.5      # m de água rasa andável na beirada
const RIVER_PIECE := 1.5      # comprimento de cada caixa do rio
const BRIDGE_HALF := 2.7      # meia-largura do vão da ponte (tabuleiro = estrada + 0,6 m)

func _add_collider(cols: Array, grid: Dictionary, c: Dictionary) -> void:
	var idx := cols.size()
	cols.append(c)
	var reach: float = c["cr"] if c["circle"] else Vector2(c["hx"], c["hz"]).length()
	reach += 1.0          # raio de quem colide (a busca só olha a célula da entidade)
	var cx0 := floori((c["x"] - reach) / GRID_CELL); var cx1 := floori((c["x"] + reach) / GRID_CELL)
	var cz0 := floori((c["z"] - reach) / GRID_CELL); var cz1 := floori((c["z"] + reach) / GRID_CELL)
	for cx in range(cx0, cx1 + 1):
		for cz in range(cz0, cz1 + 1):
			var key := Vector2i(cx, cz)
			if not grid.has(key):
				grid[key] = []
			grid[key].append(idx)

## Pontes: onde cada estrada cruza cada rio. {"pos": Vector2 (no eixo do rio), "dir": Vector2 (ao longo do rio)}.
static func water_crossings(def: MapDef) -> Array:
	var out: Array = []
	for w in def.water:
		if w["kind"] != "river":
			continue
		var rp: PackedVector2Array = w["pts"]
		for r in def.roads:
			if r["kind"] != "road":
				continue
			var qp: PackedVector2Array = r["pts"]
			for i in range(rp.size() - 1):
				for j in range(qp.size() - 1):
					var hit = Geometry2D.segment_intersects_segment(rp[i], rp[i + 1], qp[j], qp[j + 1])
					if hit != null:
						out.append({"pos": hit, "dir": (rp[i + 1] - rp[i]).normalized(), "w": float(w["w"])})
	return out

## Próximo ponto do caminho de `from` a `to` desviando dos rios pelas pontes (ou `to`, se a linha está livre).
func water_waypoint(map_id: String, from: Vector3, to: Vector3) -> Vector3:
	var path := water_path(map_id, from, to)
	if path.is_empty():
		return to
	var p: Vector2 = path[0]
	return Vector3(p.x, 0.0, p.y)

## Caminho (pontos no chão) de `from` até `to` sem atravessar rio fora das pontes; vazio = linha reta serve.
## Grafo de visibilidade: cabeceiras das pontes + pontos nas duas margens (montado em _build_water_graph).
func water_path(map_id: String, from: Vector3, to: Vector3) -> Array:
	if not maps.has(map_id):
		return []
	var m: Dictionary = maps[map_id]
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	if m.get("bridges", []).is_empty() or not _crosses_river(m, a, b):
		return []
	var nodes: PackedVector2Array = m["water_nodes"]
	var adj: Array = m["water_adj"]
	var n := nodes.size()
	var dist := PackedFloat32Array()
	dist.resize(n)
	dist.fill(INF)
	var prev := PackedInt32Array()
	prev.resize(n)
	prev.fill(-1)
	var done := PackedByteArray()
	done.resize(n)
	for i in range(n):
		if not _crosses_river(m, a, nodes[i]):
			dist[i] = a.distance_to(nodes[i])
	var best_end := -1
	var best_total := INF
	for _k in range(n):
		var u := -1
		var du := INF
		for i in range(n):
			if done[i] == 0 and dist[i] < du:
				du = dist[i]
				u = i
		if u < 0 or du >= best_total:
			break
		done[u] = 1
		if not _crosses_river(m, nodes[u], b):
			var total := du + nodes[u].distance_to(b)
			if total < best_total:
				best_total = total
				best_end = u
		for edge in adj[u]:
			var v: int = edge[0]
			var nd: float = du + float(edge[1])
			if nd < dist[v]:
				dist[v] = nd
				prev[v] = u
	if best_end < 0:
		return []
	var out: Array = []
	var cur := best_end
	while cur >= 0:
		out.push_front(nodes[cur])
		cur = prev[cur]
	return out

## Nós do desvio: as duas cabeceiras de cada ponte (ligadas entre si) e pontos andáveis nas margens.
func _build_water_graph(m: Dictionary) -> void:
	var def: MapDef = m["def"]
	var nodes := PackedVector2Array()
	var pairs: Array = []
	for br in m["bridges"]:
		var ends := _bridge_ends(br)
		pairs.append([nodes.size(), nodes.size() + 1])
		nodes.append(ends[0])
		nodes.append(ends[1])
	if not m["bridges"].is_empty():
		for w in def.water:
			if w["kind"] != "river":
				continue
			var pts: PackedVector2Array = w["pts"]
			var off: float = float(w["w"]) * 0.5 + 2.5
			var acc := 0.0
			for i in range(1, pts.size() - 1):
				acc += pts[i].distance_to(pts[i - 1])
				if acc < 12.0:
					continue
				acc = 0.0
				var t := (pts[i + 1] - pts[i - 1]).normalized()
				var nrm := Vector2(-t.y, t.x)
				for sgn in [1.0, -1.0]:
					var q: Vector2 = pts[i] + nrm * off * sgn
					if is_walkable(Vector3(q.x, 0.0, q.y), def, 0.6):
						nodes.append(q)
		for w in def.water:            # anel em volta dos lagos (contornar)
			if w["kind"] != "lake":
				continue
			var c: Vector2 = w["pos"]
			for k in range(10):
				var q: Vector2 = c + Vector2.from_angle(TAU * k / 10.0) * (float(w["r"]) + 3.0)
				if is_walkable(Vector3(q.x, 0.0, q.y), def, 0.6):
					nodes.append(q)
	var adj: Array = []
	for i in range(nodes.size()):
		adj.append([])
	for i in range(nodes.size()):
		for j in range(i + 1, nodes.size()):
			var d := nodes[i].distance_to(nodes[j])
			if d > 90.0 or _crosses_river(m, nodes[i], nodes[j]):
				continue
			adj[i].append([j, d])
			adj[j].append([i, d])
	for pr in pairs:              # atravessar a ponte (a linha corta o rio no vão: _crosses_river já deixa)
		var d := nodes[pr[0]].distance_to(nodes[pr[1]])
		if not adj[pr[0]].any(func(e): return e[0] == pr[1]):
			adj[pr[0]].append([pr[1], d])
			adj[pr[1]].append([pr[0], d])
	m["water_nodes"] = nodes
	m["water_adj"] = adj

## Cabeceiras da ponte (um pouco além da margem, dos dois lados).
func _bridge_ends(br: Dictionary) -> Array:
	var across := Vector2(-br["dir"].y, br["dir"].x)
	var reach: float = br["w"] * 0.5 + 2.5
	return [br["pos"] + across * reach, br["pos"] - across * reach]

## A linha a→b corta água (rio fora do vão de uma ponte, ou lago)?
func _crosses_river(m: Dictionary, a: Vector2, b: Vector2) -> bool:
	for w in m["def"].water:
		if w["kind"] == "lake":
			var c: Vector2 = w["pos"]
			if c.distance_to(Geometry2D.get_closest_point_to_segment(c, a, b)) < float(w["r"]) - WATER_SHORE:
				return true
			continue
		var pts: PackedVector2Array = w["pts"]
		for i in range(pts.size() - 1):
			var hit = Geometry2D.segment_intersects_segment(a, b, pts[i], pts[i + 1])
			if hit == null:
				continue
			var at_bridge := false
			for br in m.get("bridges", []):
				if br["pos"].distance_to(hit) < BRIDGE_HALF - 0.6:
					at_bridge = true
					break
			if not at_bridge:
				return true
	return false

func _nearby_colliders(m: Dictionary, p: Vector3) -> Array:
	var key := Vector2i(floori(p.x / GRID_CELL), floori(p.z / GRID_CELL))
	return m["grid"].get(key, [])

func _resolve_obstacles(p: Vector3, r: float, m: Dictionary) -> Vector3:
	var cols: Array = m["colliders"]
	for idx in _nearby_colliders(m, p):
		var c: Dictionary = cols[idx]
		if c["circle"]:
			var cr: float = c["cr"]
			var rel := Vector2(p.x - c["x"], p.z - c["z"])
			var d := rel.length()
			if d < cr + r:
				rel = rel / d * (cr + r) if d > 0.0001 else Vector2(cr + r, 0.0)
				p.x = c["x"] + rel.x
				p.z = c["z"] + rel.y
		else:
			var rot: float = c["rot"]
			var rel := Vector2(p.x - c["x"], p.z - c["z"]).rotated(rot)
			var hx: float = c["hx"] + r
			var hz: float = c["hz"] + r
			if absf(rel.x) < hx and absf(rel.y) < hz:
				var dx := hx - absf(rel.x)
				var dz := hz - absf(rel.y)
				if dx < dz:
					rel.x = signf(rel.x) * hx if rel.x != 0.0 else hx
				else:
					rel.y = signf(rel.y) * hz if rel.y != 0.0 else hz
				rel = rel.rotated(-rot)
				p.x = c["x"] + rel.x
				p.z = c["z"] + rel.y
	return p

func _point_in_solid(p: Vector3, m: Dictionary) -> bool:
	var cols: Array = m["colliders"]
	for idx in _nearby_colliders(m, p):
		var c: Dictionary = cols[idx]
		if not c["tall"]:
			continue
		if c["circle"]:
			if Vector2(p.x - c["x"], p.z - c["z"]).length() < c["cr"]:
				return true
		else:
			var rel := Vector2(p.x - c["x"], p.z - c["z"]).rotated(c["rot"])
			if absf(rel.x) < c["hx"] and absf(rel.y) < c["hz"]:
				return true
	return false

func is_walkable(p: Vector3, def: MapDef, r: float = 0.45) -> bool:
	var h := def.half()
	if absf(p.x) > h.x - r or absf(p.z) > h.y - r:
		return false
	if not maps.has(def.id):
		return true
	return _resolve_obstacles(p, r, maps[def.id]).distance_to(p) < 0.01

func random_walkable(def: MapDef, center: Vector3, radius: float) -> Vector3:
	for i in range(12):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, radius)
		var p := center + Vector3(cos(a) * d, 0.0, sin(a) * d)
		if is_walkable(p, def):
			return p
	return def.clamp_inside(center, 1.0)

const SEP_CELL := 3.0

## Uma vez por tick do mapa: grade de 3 m com as entidades vivas (separação olha só as 9 células em volta)
## e a lista de quem um monstro pode querer atacar (jogador, bots, invocações).
## Monstro dorme sem alvo e sem personagem por perto (confere a cada 20 ticks); acorda ao ser atacado ou alguém chegar.
func _dormant(e: SimEntity, m: Dictionary) -> bool:
	if e.aggro_target >= 0 or e.hp < e.stats.max_hp or e.owner_id >= 0:
		e.dormant = false
		return false
	if (tick_count + e.id) % 20 == 0 or not e.has_meta("dorm_seen"):
		e.set_meta("dorm_seen", true)
		var r2 := Balance.DORMANT_RANGE * Balance.DORMANT_RANGE
		var near := false
		for c in m.get("chars", []):
			if c.position.distance_squared_to(e.position) < r2:
				near = true
				break
		e.dormant = not near
	return e.dormant

func _index_map(m: Dictionary) -> void:
	var grid := {}
	var chars: Array = []
	for o in m["entities"]:
		if not o.is_alive():
			continue
		var k := Vector2i(floori(o.position.x / SEP_CELL), floori(o.position.z / SEP_CELL))
		if grid.has(k):
			grid[k].append(o)
		else:
			grid[k] = [o]
		if o.kind == SimEntity.Kind.PLAYER or o.kind == SimEntity.Kind.BOT or o.kind == SimEntity.Kind.SUMMON:
			chars.append(o)
	m["sep_grid"] = grid
	m["chars"] = chars

func _separate(e: SimEntity, m: Dictionary) -> void:
	if e.state == SimEntity.State.DASHING:
		return
	var grid: Dictionary = m.get("sep_grid", {})
	var near: Array = []
	if grid.is_empty():
		near = m["entities"]
	else:
		var cx := floori(e.position.x / SEP_CELL)
		var cz := floori(e.position.z / SEP_CELL)
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var cell = grid.get(Vector2i(cx + dx, cz + dz))
				if cell != null:
					near.append_array(cell)
	for o in near:
		if o == e or not o.is_alive():
			continue
		var rel := Vector2(e.position.x - o.position.x, e.position.z - o.position.z)
		var min_d: float = e.radius + o.radius
		var d := rel.length()
		if d < min_d and d > 0.0001:
			var push := (min_d - d) * 0.5
			var dir := rel / d
			e.position.x += dir.x * push
			e.position.z += dir.y * push
		elif d <= 0.0001:
			e.position.x += 0.05

func _check_portals(e: SimEntity, m: Dictionary) -> void:
	var def: MapDef = m["def"]
	for pt in def.portals:
		if pt.get("player_only", false) and e != player:
			continue                      # porta de casa: só o jogador entra
		var pos: Vector3 = pt["pos"]
		if Vector2(e.position.x, e.position.z).distance_to(Vector2(pos.x, pos.z)) <= float(pt.get("radius", 2.0)):
			var blocked := portal_block_reason(e, pt)
			if blocked == "":
				_pending_map_changes.append({"e": e, "map": pt["target_map"], "pos": pt["target_pos"]})
			elif e == player and time >= e.portal_notice_at:
				e.portal_notice_at = time + Balance.PORTAL_NOTICE_CD
				Events.notification.emit(blocked)
			return

## Por que `e` não passa neste portal; "" = passa. Vale só para o jogador: bots não ficam presos em quest.
func portal_block_reason(e: SimEntity, pt: Dictionary) -> String:
	var g: Dictionary = pt.get("gate", {})
	if g.is_empty() or e.kind != SimEntity.Kind.PLAYER or e.gates_open.has(pt["id"]):
		return ""
	if e.level < int(g.get("level", 1)):
		return "%s: precisa de nível %d." % [pt["label"], int(g["level"])]
	var q: String = g.get("quest", "")
	if q != "" and not (q in e.quests_completed):
		return g.get("text", "%s: ainda fechado." % pt["label"])
	for boss in g.get("bosses", []):
		if not e.bosses_killed.has(boss):
			return g.get("text", "%s: ainda fechado." % pt["label"])
	e.gates_open[pt["id"]] = true
	return ""

## Save antigo não pode prender ninguém: abre os portões de história que o nível alcança e o mapa onde o
## personagem já está. Selos de chefe continuam valendo.
func grandfather_gates(e: SimEntity, map_id: String) -> void:
	for mid in GameData.maps:
		for pt in GameData.maps[mid].portals:
			var g: Dictionary = pt.get("gate", {})
			if g.is_empty() or g.has("bosses"):
				continue
			if e.level >= int(g.get("level", 1)) or _map_within(map_id, pt["target_map"]):
				e.gates_open[pt["id"]] = true

## `map_id` é `area` ou fica dentro dela (dungeon da zona).
func _map_within(map_id: String, area: String) -> bool:
	var cur := map_id
	while cur != "":
		if cur == area:
			return true
		var def: MapDef = GameData.maps.get(cur)
		cur = def.parent_map if def else ""
	return false

func _process_map_changes() -> void:
	var moving := {}
	for ch in _pending_map_changes:
		moving[ch["e"].id] = true
	var extra: Array = []
	for ch in _pending_map_changes:            # o líder passou pelo portal: os bots do grupo por perto vão junto
		var e: SimEntity = ch["e"]
		if e.party_id < 0 or party_leader(e) != e:
			continue
		var k := 0
		for o in party_members(e):
			if o == e or moving.has(o.id) or o.kind != SimEntity.Kind.BOT or not o.is_alive() or o.map_id != e.map_id:
				continue
			if o.position.distance_to(e.position) > Balance.PARTY_PORTAL_FOLLOW:
				continue
			k += 1
			moving[o.id] = true
			var pos: Vector3 = ch["pos"]
			extra.append({"e": o, "map": ch["map"], "pos": pos + Vector3(cos(k * 2.1), 0, sin(k * 2.1)) * 1.6})
	for ch in _pending_map_changes + extra:
		_change_map(ch["e"], ch["map"], ch["pos"])
	_pending_map_changes.clear()

## Voltar à cidade (G): RECALL_TIME s parado e fora de combate; andar, agir, levar dano ou apertar G de novo cancela.
## Chega no ponto de entrada da vila; os bots do grupo por perto vêm junto (mesma regra do portal).
func _update_recall(e: SimEntity, cmd: InputCommand, action_cmd: InputCommand, dt: float) -> void:
	if not e.is_character():
		return
	var town := GameData.town_map_id()
	if cmd.recall:
		if e.recall_left > 0.0:
			e.recall_left = 0.0
			if e == player:
				Events.notification.emit("Retorno à cidade cancelado")
			return
		var why := ""
		if not e.is_alive():
			why = "Não dá agora"
		elif e.combat_timer > 0.0:
			why = "Não dá para voltar à cidade em combate"
		elif e.map_id == town and maps[town]["def"].in_town(e.position):
			why = "Você já está na cidade"
		if why != "":
			if e == player:
				Events.notification.emit(why)
			return
		e.recall_left = Balance.RECALL_TIME
		if e == player:
			Events.notification.emit("Voltando para %s... fique parado" % GameData.maps[town].name)
		return
	if e.recall_left <= 0.0:
		return
	if not e.is_alive() or e.combat_timer > 0.0 or cmd.move.length_squared() > 0.04 or action_cmd.attack or action_cmd.skill_slot >= 0 \
			or action_cmd.dash or action_cmd.jump or cmd.block:
		e.recall_left = 0.0
		if e == player:
			Events.notification.emit("Retorno à cidade cancelado")
		return
	e.recall_left -= dt
	if e.recall_left <= 0.0:
		e.recall_left = 0.0
		e.mounted = false
		_pending_map_changes.append({"e": e, "map": town, "pos": GameData.maps[town].spawn_point})

## Bot do grupo em outro mapa que o líder por mais de PARTY_CATCHUP_TIME (preso no caminho, renasceu na vila):
## reaparece ao lado do líder. Assim o grupo segue o jogador para dentro das dungeons e ajuda lá.
func _party_catchup(dt: float) -> void:
	for p in parties.values():
		var leader: SimEntity = entities.get(p["leader"])
		if leader == null or not leader.is_alive():
			continue
		for id in p["members"]:
			var o: SimEntity = entities.get(id)
			if o == null or o == leader or o.kind != SimEntity.Kind.BOT:
				continue
			if not o.is_alive() or o.map_id == leader.map_id:
				o.lost_leader_t = 0.0
				continue
			o.lost_leader_t += dt
			if o.lost_leader_t >= Balance.PARTY_CATCHUP_TIME:
				o.lost_leader_t = 0.0
				_pending_map_changes.append({"e": o, "map": leader.map_id, "pos": leader.position - leader.forward() * 2.0})

func _change_map(e: SimEntity, map_id: String, pos: Vector3) -> void:
	if e.mounted and GameData.maps.has(map_id) and GameData.maps[map_id].parent_map != "":
		dismount(e)                    # dungeon: entra a pé
	if not maps.has(map_id):
		var def: MapDef = GameData.maps.get(map_id)
		if def == null:
			return
		load_map(def)
	if maps.has(e.map_id):
		maps[e.map_id]["entities"].erase(e)
		if maps[e.map_id].has("chars"):
			maps[e.map_id]["chars"].erase(e)
	# invocações seguem o dono
	e.map_id = map_id
	e.position = pos
	e.velocity = Vector3.ZERO
	e.aggro_target = -1
	maps[map_id]["entities"].append(e)
	Events.entity_changed_map.emit(e.id, map_id)
	for o in entities.values():
		if o.kind == SimEntity.Kind.SUMMON and o.owner_id == e.id and o.map_id != map_id:
			maps[o.map_id]["entities"].erase(o)
			o.map_id = map_id
			o.position = pos + Vector3(1, 0, 1)
			maps[map_id]["entities"].append(o)
			Events.entity_changed_map.emit(o.id, map_id)

# ----------------------------------------------------------------------------
# SPAWNERS / LOOT
# ----------------------------------------------------------------------------
func _update_spawners(m: Dictionary, dt: float) -> void:
	var def: MapDef = m["def"]
	for sp in m["spawners"]:
		var sdef: Dictionary = sp["def"]
		sp["alive"] = sp["alive"].filter(func(id): return entities.has(id))
		if sp["alive"].size() < int(sdef.get("count", 1)):
			sp["timer"] -= dt
			if sp["timer"] <= 0.0:
				var mdef: MonsterDef = GameData.monsters.get(sdef["monster_id"])
				if mdef:
					var pos := random_walkable(def, sdef["pos"], float(sdef.get("radius", 6.0)))
					var em = sdef.get("emerge")
					if em is Array and em.size() >= 3:      # sai do lago: nasce na beira d'água e anda até o lugar dele
						var c := Vector3(float(em[0]), 0, float(em[1]))
						var dir := Vector3(sdef["pos"].x - c.x, 0, sdef["pos"].z - c.z).normalized()
						pos = c + dir * (float(em[2]) + mdef.radius + 0.6)
					var mob := spawn_monster(mdef, def.id, pos, sp)
					if em is Array and em.size() >= 3:
						Events.monster_emerged.emit(def.id, pos)
						if player and player.map_id == def.id:
							Events.chat_message.emit("Sistema", "%s emerge do lago!" % mob.monster_def.name, "system")
				if sp["alive"].size() >= int(sdef.get("count", 1)):
					sp["primed"] = true
				# enche rápido na 1ª vez (mapa recém-carregado) e quando esvazia; depois, um por vez no tempo de respawn
				sp["timer"] = float(sdef.get("respawn", 10.0)) if sp["alive"].size() > 0 and sp["primed"] else 0.5

func _update_loot(m: Dictionary, dt: float) -> void:
	var loot: Array = m["loot"]
	for l in loot.duplicate():
		l["timer"] -= dt
		if l["timer"] <= 0.0:
			loot.erase(l)
			continue
		var lp: Vector3 = l["pos"]
		for e in m.get("chars", m["entities"]):       # só personagens pegam (lista do tick, não todas as entidades)
			var dx: float = e.position.x - lp.x
			var dz: float = e.position.z - lp.z
			if dx * dx + dz * dz > 0.81 or not e.is_character() or not e.is_alive() or not can_loot(e, l):
				continue
			if e == player and l["item"] != "gold" and e.bag_full_for(l["item"]):
				if time >= e.portal_notice_at:
					e.portal_notice_at = time + 3.0
					Events.notification.emit("Bolsa cheia (%d/%d): libere espaço ou amplie a bolsa" % [e.inventory.size(), e.bag_capacity()])
				continue
			if true:
				_pickup(e, l)
				loot.erase(l)
				break

func can_loot(e: SimEntity, l: Dictionary) -> bool:
	return e.id == int(l.get("owner", -1)) or time >= float(l.get("free_at", 0.0))

func _pickup(e: SimEntity, l: Dictionary) -> void:
	if l["item"] == "gold":
		e.gold += int(l["count"])
		if e == player:
			Events.notification.emit("+%d ouro" % int(l["count"]))
	else:
		e.add_item(l["item"], int(l["count"]))
		QuestSystem.on_item_changed(e, l["item"])
		if e == player:
			var it: ItemDef = GameData.items.get(l["item"])
			Events.notification.emit("+%d %s" % [int(l["count"]), it.name if it else l["item"]])

# ----------------------------------------------------------------------------
# EQUIPAMENTO / MAESTRIA (chamados pela UI)
# ----------------------------------------------------------------------------
## Por que `e` não pode equipar `item` (no slot dado); "" = pode.
func equip_error(e: SimEntity, item: ItemDef, to_offhand: bool = false) -> String:
	if item == null or not item.is_equipment():
		return "Não é equipamento"
	if e.level < item.level_req:
		return "Requer nível %d" % item.level_req
	if item.class_restriction.size() > 0 and not (e.class_def.id in item.class_restriction):
		return "Sua classe não pode usar isso"
	if to_offhand:
		if not (item.weapon_type in ItemDef.ONE_HANDED_MELEE) or not (item.weapon_type in e.class_def.offhand_types):
			return "Sua classe não usa isso na mão secundária"
	elif item.slot == ItemDef.Slot.WEAPON and not (item.weapon_type in e.class_def.weapon_types):
		return "Tipo de arma inválido para sua classe"
	elif item.slot == ItemDef.Slot.OFFHAND and not (item.weapon_type in e.class_def.offhand_types):
		return "Sua classe não usa %s" % ("escudo" if item.weapon_type == "shield" else "isso na mão secundária")
	return ""

## Equipa da bolsa. to_offhand: arma de 1 mão na mão secundária (empunhar duas).
## want_slot: anel arrastado para um slot de anel específico (senão preenche o vazio).
## Arma de duas mãos libera a secundária; secundária com arma de duas mãos devolve a arma pra bolsa.
func equip(e: SimEntity, item_id: String, to_offhand: bool = false, want_slot: int = -1) -> bool:
	var item: ItemDef = GameData.items.get(item_id)
	if item == null or not e.has_item(item_id):
		return false
	var err := equip_error(e, item, to_offhand)
	if err != "":
		Events.notification.emit(err)
		return false
	var slot: int = ItemDef.Slot.OFFHAND if to_offhand else item.slot
	if slot == ItemDef.Slot.RING and want_slot in [ItemDef.Slot.RING, ItemDef.Slot.RING2]:
		slot = want_slot
	elif slot == ItemDef.Slot.RING and e.equipment.get(ItemDef.Slot.RING) != null and e.equipment.get(ItemDef.Slot.RING2) == null:
		slot = ItemDef.Slot.RING2        # dois anéis: preenche o vazio; com os dois ocupados troca o primeiro
	e.remove_item(item_id, 1)
	if e.equipment.has(slot) and e.equipment[slot] != null:
		e.add_item(e.equipment[slot].id, 1)
	e.equipment[slot] = item
	var main: ItemDef = e.equipment.get(ItemDef.Slot.WEAPON)
	if main and main.is_two_handed() and e.equipment.get(ItemDef.Slot.OFFHAND) != null:
		var bump: int = ItemDef.Slot.WEAPON if slot == ItemDef.Slot.OFFHAND else ItemDef.Slot.OFFHAND
		e.add_item(e.equipment[bump].id, 1)
		e.equipment.erase(bump)
		if e == player:
			Events.notification.emit("Arma de duas mãos: a outra mão foi liberada")
	e.recompute_stats()
	Events.equipment_changed.emit(e.id)
	return true

func unequip(e: SimEntity, slot: int) -> void:
	if e.equipment.has(slot) and e.equipment[slot] != null:
		e.add_item(e.equipment[slot].id, 1)
		e.equipment.erase(slot)
		e.recompute_stats()
		Events.equipment_changed.emit(e.id)

func _first_free_slot(e: SimEntity) -> int:
	for i in range(e.skills.size()):
		if e.skills[i] == null:
			return i
	return -1

# ----------------------------------------------------------------------------
# ÁRVORE DE PONTOS DE SKILL (TreeCatalog): o único jeito de gastar pontos
# ----------------------------------------------------------------------------
func tree_of(e: SimEntity) -> Dictionary:
	return GameData.trees.get(e.class_def.id, {}) if e.class_def else {}

## "" se pode comprar o nó; senão o motivo.
func tree_block_reason(e: SimEntity, node_id: String) -> String:
	var tr := tree_of(e)
	if tr.is_empty() or not tr["nodes"].has(node_id):
		return "nó inexistente"
	var n: Dictionary = tr["nodes"][node_id]
	if e.tree.has(node_id) and n["kind"] != "mastery":      # maestria compra de novo até o máximo (1 ponto por nível)
		return "já comprado"
	if n["kind"] == "pick":                  # talento de escolha: sem vizinho; um por linha, troca na cidade
		if e.level < int(n["level"]):
			return "requer nível %d" % int(n["level"])
		var other := pick_sibling(e, node_id)
		if other != "":
			if Balance.PICK_SWAP_TOWN_ONLY and maps.has(e.map_id) and not maps[e.map_id]["def"].in_town(e.position):
				return "troque a escolha desta linha na cidade"
			return ""                          # troca: o ponto da escolha antiga volta
		if e.mastery_points < int(n["cost"]):
			return "pontos insuficientes (%d)" % int(n["cost"])
		return ""
	var linked := false
	for l in n["links"]:
		if e.tree.has(l):
			linked = true
			break
	if not linked:
		return "precisa de um nó vizinho comprado"
	if e.level < int(n["level"]):
		return "requer nível %d" % int(n["level"])
	if e.mastery_points < int(n["cost"]):
		return "pontos insuficientes (%d)" % int(n["cost"])
	if n["kind"] == "mastery" and e.mastery_of(n["ref"]) >= Balance.MASTERY_MAX:
		return "maestria já no máximo"
	return ""

## Talento de escolha já comprado na mesma linha (outra opção do mesmo grupo), ou "".
func pick_sibling(e: SimEntity, node_id: String) -> String:
	var nodes: Dictionary = tree_of(e)["nodes"]
	var g: String = nodes[node_id].get("group", "")
	for nid in e.tree:
		if nid != node_id and nodes.has(nid) and nodes[nid].get("group", "") == g and g != "":
			return nid
	return ""

## Compra um nó da árvore e aplica: skill nova (vai pro 1º slot livre), evolução, +1 maestria ou passivo.
func tree_allocate(e: SimEntity, node_id: String) -> bool:
	var why := tree_block_reason(e, node_id)
	if why != "":
		if e == player:
			Events.notification.emit("Árvore: " + why)
		return false
	var n: Dictionary = tree_of(e)["nodes"][node_id]
	if n["kind"] == "pick":
		var other := pick_sibling(e, node_id)
		if other != "":
			e.tree.erase(other)
			e.mastery_points += int(tree_of(e)["nodes"][other]["cost"])
	e.mastery_points -= int(n["cost"])
	e.tree[node_id] = true
	var ref: String = n["ref"]
	match n["kind"]:
		"skill":
			e.learned[ref] = true
			e.mastery[ref] = e.mastery_of(ref)
			var free := _first_free_slot(e)
			if free >= 0 and e.slot_of(ref) < 0:
				e.skills[free] = GameData.skills[ref]
		"talent":
			e.talents[ref] = true
		"mastery":
			e.mastery[ref] = mini(Balance.MASTERY_MAX, e.mastery_of(ref) + 1)
		"stat", "pick":
			recompute_tree_bonus(e)
	Events.mastery_changed.emit(e.id, ref, e.mastery_of(ref))
	return true

## Soma os passivos comprados (chamar ao carregar o save).
func recompute_tree_bonus(e: SimEntity) -> void:
	e.tree_bonus = {}
	var tr := tree_of(e)
	for nid in e.tree:
		var n: Dictionary = tr["nodes"].get(nid, {})
		for k in n.get("stats", {}):
			e.tree_bonus[k] = float(e.tree_bonus.get(k, 0.0)) + float(n["stats"][k])
	e.recompute_stats()

## Atalhos pela árvore (UI antiga, testes): aprender skill / comprar evolução = comprar o nó dela.
func learn_skill(e: SimEntity, skill_id: String) -> bool:
	if e.knows(skill_id) or e.class_def == null:
		return false
	return tree_allocate(e, "%s_s_%s" % [e.class_def.id, skill_id])

func learn_talent(e: SimEntity, talent_id: String) -> bool:
	if e.has_talent(talent_id) or e.class_def == null:
		return false
	return tree_allocate(e, "%s_t_%s" % [e.class_def.id, talent_id])

## Põe uma skill aprendida no slot (ou "" para esvaziar). Troca de lugar se já estiver na barra.
func set_skill_slot(e: SimEntity, slot: int, skill_id: String) -> bool:
	if slot < 0 or slot >= Balance.SKILL_SLOTS:
		return false
	if Balance.LOADOUT_TOWN_ONLY and maps.has(e.map_id) and not maps[e.map_id]["def"].in_town(e.position):
		Events.notification.emit("Troque skills da barra na cidade")
		return false
	e.ensure_slots()
	if skill_id == "":
		e.skills[slot] = null
		Events.mastery_changed.emit(e.id, "", 0)
		return true
	var s: SkillDef = GameData.skills.get(skill_id)
	if s == null or not e.knows(skill_id):
		return false
	var cur := e.slot_of(skill_id)
	if cur >= 0:
		e.skills[cur] = e.skills[slot]
	e.skills[slot] = s
	Events.mastery_changed.emit(e.id, skill_id, e.mastery_of(skill_id))
	return true

## +1 maestria com pontos = comprar a folha de maestria da skill na árvore (repete até Balance.MASTERY_MAX).
func upgrade_mastery(e: SimEntity, skill_id: String) -> bool:
	if e.class_def == null or not e.knows(skill_id):
		return false
	return tree_allocate(e, "%s_m_%s" % [e.class_def.id, skill_id])

func set_potion_slot(e: SimEntity, slot: int, item_id: String) -> void:
	e.potion_slots[slot] = item_id

# ----------------------------------------------------------------------------
# GRUPO (party). Convite → aceitar; líder convida/expulsa/promove; XP e quests de abate divididas por perto.
# ----------------------------------------------------------------------------
func party_of(e: SimEntity) -> Dictionary:
	return parties.get(e.party_id, {}) if e else {}

## Membros do grupo de `e` (ele incluso; sem grupo = só ele), na ordem de entrada.
func party_members(e: SimEntity) -> Array:
	var p := party_of(e)
	if p.is_empty():
		return [e]
	var out: Array = []
	for id in p["members"]:
		if entities.has(id):
			out.append(entities[id])
	return out

func party_leader(e: SimEntity) -> SimEntity:
	var p := party_of(e)
	return entities.get(p["leader"]) if not p.is_empty() else null

func same_party(a: SimEntity, b: SimEntity) -> bool:
	return a != null and b != null and a.party_id >= 0 and a.party_id == b.party_id

## Quem divide o abate com `killer`: grupo vivo, no mesmo mapa, perto e com nível próximo.
func kill_sharers(killer: SimEntity, mob: SimEntity) -> Array:
	var out: Array = [killer]
	if killer.party_id < 0:
		return out
	for o in party_members(killer):
		if o == killer or not o.is_alive() or o.map_id != mob.map_id:
			continue
		if o.position.distance_to(mob.position) > Balance.PARTY_SHARE_RANGE:
			continue
		if absi(o.level - killer.level) > Balance.PARTY_LEVEL_GAP:
			continue
		out.append(o)
	return out

## Por que `from` não pode convidar `to`; "" = pode.
func party_invite_error(from: SimEntity, to: SimEntity) -> String:
	if from == null or to == null or from == to or not to.is_character() or not entities.has(to.id):
		return "Alvo inválido."
	if to.party_id >= 0:
		return "%s já está em um grupo." % to.name
	if invites.has(to.id):
		return "%s já tem um convite pendente." % to.name
	if to.brain and absi(to.level - from.level) > Balance.PARTY_LEVEL_GAP:
		return "%s não entra em grupo com nível tão diferente (máx. %d)." % [to.name, Balance.PARTY_LEVEL_GAP]
	var p := party_of(from)
	if not p.is_empty():
		if p["leader"] != from.id:
			return "Só o líder pode convidar."
		if p["members"].size() >= Balance.PARTY_MAX:
			return "O grupo está cheio (%d)." % Balance.PARTY_MAX
	return ""

func party_invite(from: SimEntity, to: SimEntity) -> bool:
	var err := party_invite_error(from, to)
	if err != "":
		if from == player:
			Events.notification.emit(err)
		return false
	invites[to.id] = {"from": from.id, "expires": time + Balance.PARTY_INVITE_TIME, "decide_at": time + rng.randf_range(1.0, 3.0)}
	Events.party_invited.emit(from.id, to.id)
	if from == player:
		Events.notification.emit("Convite enviado para %s." % to.name)
	return true

func party_accept(e: SimEntity) -> bool:
	var inv: Dictionary = invites.get(e.id, {})
	invites.erase(e.id)
	if inv.is_empty() or e.party_id >= 0:
		return false
	var from: SimEntity = entities.get(inv["from"])
	if from == null:
		return false
	var p := party_of(from)
	if p.is_empty():
		p = {"id": _next_party_id, "leader": from.id, "members": [from.id]}
		_next_party_id += 1
		parties[p["id"]] = p
		_set_party(from, p["id"])
	if p["members"].size() >= Balance.PARTY_MAX:
		return false
	p["members"].append(e.id)
	_set_party(e, p["id"])
	_party_say(p, "%s entrou no grupo." % e.name)
	var lead: SimEntity = entities.get(p["leader"])
	if e.kind == SimEntity.Kind.PLAYER and lead and lead.kind == SimEntity.Kind.BOT:
		p["leader"] = e.id                       # grupo com o jogador: os bots seguem e ajudam o jogador
		_party_say(p, "%s agora lidera o grupo." % e.name)
	Events.party_changed.emit(p["id"])
	return true

func party_decline(e: SimEntity) -> void:
	var inv: Dictionary = invites.get(e.id, {})
	invites.erase(e.id)
	if not inv.is_empty() and player and inv["from"] == player.id:
		Events.notification.emit("%s recusou o convite." % e.name)

func party_leave(e: SimEntity) -> void:
	var p := party_of(e)
	if p.is_empty():
		return
	_party_say(p, "%s saiu do grupo." % e.name)
	p["members"].erase(e.id)
	_set_party(e, -1)
	if e == player:
		Events.notification.emit("Você saiu do grupo.")
	if p["members"].size() < 2:
		if player and p["members"].has(player.id):
			Events.notification.emit("O grupo foi desfeito.")
		for id in p["members"]:
			if entities.has(id):
				_set_party(entities[id], -1)
		parties.erase(p["id"])
	elif p["leader"] == e.id:
		p["leader"] = p["members"][0]
		_party_say(p, "%s agora é o líder." % entities[p["leader"]].name)
	Events.party_changed.emit(p["id"])

func party_kick(leader: SimEntity, target: SimEntity) -> bool:
	if not same_party(leader, target) or leader == target or party_of(leader)["leader"] != leader.id:
		return false
	if target == player:
		Events.notification.emit("Você foi removido do grupo.")
	party_leave(target)
	return true

func party_promote(leader: SimEntity, target: SimEntity) -> bool:
	if not same_party(leader, target) or leader == target or party_of(leader)["leader"] != leader.id:
		return false
	var p := party_of(leader)
	p["leader"] = target.id
	_party_say(p, "%s agora é o líder." % target.name)
	Events.party_changed.emit(p["id"])
	return true

func _set_party(e: SimEntity, party_id: int) -> void:
	e.party_id = party_id
	for o in entities.values():
		if o.kind == SimEntity.Kind.SUMMON and o.owner_id == e.id:
			o.party_id = party_id

## Mensagem de sistema no canal do grupo (só aparece se o jogador está nele).
func _party_say(p: Dictionary, text: String) -> void:
	if player and p["members"].has(player.id):
		Events.chat_message.emit("Grupo", text, "party")

## /party: bots do mesmo mapa, sozinhos ou líderes com vaga e de nível próximo, se oferecem (fala no chat) e
## convidam um por vez: recusou ou deixou passar → o próximo; entrou num grupo → acaba. Devolve quantos se ofereceram.
const SEEK_LINES := ["Bora, %s! Te chamo pro grupo.", "Opa, %s, cola com a gente!", "Tô indo caçar, %s, vem junto?", "Chamando, %s!"]

func party_seek_start(e: SimEntity) -> int:
	if e == null or e.party_id >= 0:
		return -1
	var cd: Dictionary = party_seek.get(e.id, {})
	if not cd.is_empty() and time < float(cd.get("until", 0.0)):
		return -2
	var cands: Array = []
	for o in maps[e.map_id]["entities"]:
		if o.kind != SimEntity.Kind.BOT or not o.is_alive() or invites.has(o.id):
			continue
		if absi(o.level - e.level) > Balance.PARTY_LEVEL_GAP:
			continue
		var p := party_of(o)
		if not p.is_empty() and (p["leader"] != o.id or p["members"].size() >= Balance.PARTY_MAX):
			continue
		cands.append(o)
	cands.sort_custom(func(a, b): return absi(a.level - e.level) * 30.0 + a.position.distance_to(e.position) < absi(b.level - e.level) * 30.0 + b.position.distance_to(e.position))
	cands = cands.slice(0, Balance.PARTY_SEEK_MAX)
	var q: Array = []
	for i in range(cands.size()):
		q.append(cands[i].id)
		Events.chat_message.emit(cands[i].name, SEEK_LINES[(i + e.id) % SEEK_LINES.size()] % e.name, "say")
	party_seek[e.id] = {"queue": q, "next_at": time + 1.0, "until": time + Balance.PARTY_SEEK_COOLDOWN}
	return q.size()

func _update_party_seek() -> void:
	for id in party_seek.keys():
		var s: Dictionary = party_seek[id]
		var e: SimEntity = entities.get(id)
		if e == null or e.party_id >= 0:
			s["queue"] = []                   # entrou num grupo: os outros desistem (o tempo de espera continua)
		if (s["queue"] as Array).is_empty() or invites.has(id) or time < float(s["next_at"]):
			continue
		var bot: SimEntity = entities.get(int(s["queue"].pop_front()))
		if bot and bot.is_alive() and bot.map_id == e.map_id and party_invite_error(bot, e) == "":
			party_invite(bot, e)
		s["next_at"] = time + 0.8

## Depósito: só perto de um NPC com o papel (Balance.STATION_RANGE).
func near_station(e: SimEntity, role: String) -> bool:
	if not maps.has(e.map_id):
		return false
	for n in maps[e.map_id]["def"].npcs:
		if n.get("role", "") == role and Vector2(n["pos"].x, n["pos"].z).distance_to(Vector2(e.position.x, e.position.z)) <= Balance.STATION_RANGE:
			return true
	return false

## Guarda `count` do item da bolsa no depósito (equipado não entra; tipos limitados a STORAGE_SLOTS).
func storage_deposit(e: SimEntity, item_id: String, count: int = 1) -> bool:
	if count <= 0 or not e.has_item(item_id, count) or not near_station(e, "storage"):
		return false
	if not e.storage.has(item_id) and e.storage.size() >= Balance.STORAGE_SLOTS:
		if e == player:
			Events.notification.emit("Depósito cheio (%d tipos de item)." % Balance.STORAGE_SLOTS)
		return false
	e.remove_item(item_id, count)
	e.storage[item_id] = int(e.storage.get(item_id, 0)) + count
	return true

func storage_withdraw(e: SimEntity, item_id: String, count: int = 1) -> bool:
	if count <= 0 or int(e.storage.get(item_id, 0)) < count or not near_station(e, "storage"):
		return false
	e.storage[item_id] = int(e.storage[item_id]) - count
	if int(e.storage[item_id]) <= 0:
		e.storage.erase(item_id)
	e.add_item(item_id, count)
	return true

## Convites: expiram; bots decidem depois de 1-3 s (o jogador decide pela UI).
func _update_invites() -> void:
	_update_party_seek()
	for to_id in invites.keys():
		var inv: Dictionary = invites[to_id]
		var to: SimEntity = entities.get(to_id)
		if to == null or time >= inv["expires"]:
			invites.erase(to_id)
			continue
		if to.kind == SimEntity.Kind.BOT and time >= inv["decide_at"]:
			var from: SimEntity = entities.get(inv["from"])
			if from and to.brain and to.brain.wants_party(to, from, self):
				party_accept(to)
			else:
				party_decline(to)

