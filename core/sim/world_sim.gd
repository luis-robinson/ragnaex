class_name WorldSim
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
var power_scale := 1.0              # efeitos de graça (assinatura) lançam com menos poder
var signatures_on := true
var signature_force := false      # revisão visual: a assinatura dispara sempre (com a recarga)          # sondas: desliga a assinatura para comparar
var signature_casting := false     # assinatura em andamento: o que ela acertar não dispara outra
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
	MapGeometry.build_collider_grid(self, m)
	m["gather"] = GatherSystem.spread_gather(self, def)          # pontos de colheita (depois da colisão: só em chão livre)
	for sp in def.spawners:
		m["spawners"].append({"def": sp, "alive": [], "timer": 0.0, "primed": false})     # primed: já encheu a 1ª vez
	for n in def.npcs:
		if not (n.has("if") or n.has("unless")):
			_spawn_npc(n, def.id)
	WorldState.sync_npcs(self, m)              # NPC de conquista (if/unless): só se valer agora
	return m

func map_entities(map_id: String) -> Array:
	return maps[map_id]["entities"] if maps.has(map_id) else []

func map_def(map_id: String) -> MapDef:
	return maps[map_id]["def"] if maps.has(map_id) else null

## Personagem carregado do save: vai para o mapa/posição salvos (troca de mapa se for outro).
func place_loaded(e: SimEntity, map_id: String, pos: Vector3) -> void:
	if map_id != e.map_id:
		PortalSystem.change_map(self, e, map_id, pos)
	else:
		e.position = pos

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
			var free := ItemSystem.first_free_slot(self, e)
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
	if kind == SimEntity.Kind.BOT and level >= Balance.BOT_MED_POTION_LEVEL:    # bot do meio do jogo já anda com as (M)
		e.potion_slots = ["potion_hp_m", "potion_mp_m", ""]
		e.add_item("potion_hp_m", 5)
		e.add_item("potion_mp_m", 3)
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
	_add_skills(e, mdef.skill_ids)
	e.brain = MonsterBrain.new()
	var pk := 1.0 + owner.stats.pet_power / 100.0 if owner.is_character() and owner.stats else 1.0
	if owner_stats:            # companheiro: parte da vida/ataque/defesa do dono, mais o bônus de companheiro
		var k := 1.0 + owner.stats.pet_power / 100.0
		e.summon_hp = owner.stats.max_hp * Balance.PET_HP_SHARE * k
		e.summon_patk = owner.stats.patk * Balance.PET_ATK_SHARE * k
	else:
		e.summon_patk = owner.stats.matk * Balance.SUMMON_MATK_SHARE * clampf(mdef.atk / Balance.SUMMON_ATK_REF, Balance.SUMMON_ATK_MIN, Balance.SUMMON_ATK_MAX) * pk     # monstro mais forte (rei esqueleto) bate mais
	e.recompute_stats()
	if owner_stats:
		e.stats.pdef = owner.stats.pdef * Balance.PET_DEF_SHARE
	e.stats.patk = e.summon_patk
	e.stats.matk = e.summon_patk
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
	if n.has("fighter"):                    # sentinela: luta com o monstro de `fighter` (atributos, ataque, alcance)
		_arm_guard(e, n)
	return _register(e, map_id)

## Sentinela do povoado: NPC com atributos de monstro (MonstersCatalog, `guard_*`), armas do kit e GuardBrain.
func _arm_guard(e: SimEntity, n: Dictionary) -> void:
	var mdef: MonsterDef = GameData.monsters.get(str(n["fighter"]))
	if mdef == null:
		return
	e.guard = true
	e.monster_def = mdef
	e.level = mdef.level
	e.home_position = e.position
	e.basic_skill = GameData.basic_skill_for_monster(mdef)
	_add_skills(e, mdef.skill_ids)
	for item_id in n.get("gear", []):
		var it: ItemDef = GameData.items.get(item_id)
		if it:
			e.equipment[it.slot if not (it.slot == ItemDef.Slot.WEAPON and e.equipment.has(ItemDef.Slot.WEAPON)) else ItemDef.Slot.OFFHAND] = it
	e.brain = GuardBrain.new()
	e.recompute_stats()
	e.heal_full()

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
		PartySystem.party_leave(self, e)
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
		WorldState.update(self, m, mdt)
		MobSystem.update_spawners(self, m, mdt)
		RaidSystem.update_raids(self, m, mdt)
		if profile:
			_prof("r_spawners", pt); pt = Time.get_ticks_usec()
		TrapSystem.update_traps(self, m)
		LootSystem.update_loot(self, m, mdt)
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
	PortalSystem.process_map_changes(self)
	PartySystem.party_catchup(self, dt)
	if not invites.is_empty():
		PartySystem.update_invites(self)
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
	PortalSystem.update_recall(self, e, cmd, action_cmd, dt)
	GatherSystem.update_gather(self, e, cmd, action_cmd, dt)
	# atacar, usar skill, dash ou bloquear: desce do cavalo e a ação acontece
	if e.mounted and (action_cmd.attack or action_cmd.skill_slot >= 0 or action_cmd.dash or cmd.block):
		dismount(e)

	# --- poções: a qualquer momento vivo ---
	if action_cmd.potion_slot >= 0:
		ItemSystem.use_potion(self, e, action_cmd.potion_slot)

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
	if pet.brain is MonsterBrain:
		pet.brain.skill_rethink = Balance.PET_COMMAND_FOCUS     # ordem do dono: segura este alvo um tempo
	var r := Combat.calc_damage(pet, target, power, SkillDef.Kind.PHYSICAL, rng, pet.position)
	_deal_damage(pet, target, r["amount"], r["crit"], r["blocked"], "physical", pet.position)
	if effects["pet_command"].has("stun"):
		_apply_effects(e, target, {"stun": {"duration": float(effects["pet_command"]["stun"])}}, power)
	Events.skill_effect.emit(s.id, pet.position, target.position, 1.0)

# ----------------------------------------------------------------------------
# ARMADILHAS (Ranger Atirador): ficam no mapa, armam, disparam quando um inimigo pisa, somem com o tempo
# ----------------------------------------------------------------------------
var _next_trap_id := 1

## Radiância (Bispo da luz): parte do dano mágico cura o aliado mais ferido por perto (você incluso).
func _radiance(e: SimEntity, amount: int) -> void:
	var best := most_hurt_friend(e, Balance.RADIANCE_RANGE)
	if best.hp < best.stats.max_hp:
		_heal(e, best, maxi(1, int(round(amount * e.stats.radiance / 100.0))))

## Personagem aliado vivo mais ferido (em % de vida) a até `range_m` de `e` (o próprio `e` se ninguém estiver pior).
func most_hurt_friend(e: SimEntity, range_m: float) -> SimEntity:
	var best: SimEntity = e
	for o in maps[e.map_id]["entities"]:
		if o.is_character() and o.is_alive() and e.is_friend(o) and o.position.distance_to(e.position) <= range_m:
			if o.hp / o.stats.max_hp < best.hp / best.stats.max_hp:
				best = o
	return best

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
		GatherSystem.start_gather(self, e, m)
		return
	e.face_towards(best.position)
	best.npc_hold = Balance.NPC_TALK_HOLD
	best.face_towards(e.position)
	NpcSystem.npc_stop(self, best)
	Events.dialog_requested.emit(best.npc_data.get("id", ""))

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
			Events.notification.emit("%s exige: %s" % [s.name, ProgressionSystem.requires_text(s.requires)])
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
	s = ProgressionSystem.resolve_skill(self, e, s)
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
	var power := s.power_at(lv) * e.stats.skill_power_mult(s.id) * e.stats.element_mult(s.elements) * ShieldSystem.shield_power(self, e, s) * power_scale
	if e.ambush:
		power *= Balance.AMBUSH_MULT
		e.ambush = false
	var extra: Dictionary = s.mastery_entry(lv).get("extra", {})
	var effects := s.effects.duplicate(true)
	for k in extra:
		effects[k] = extra[k]
	for k in s.talent_effects:     # evoluções vencem a maestria
		effects[k] = s.talent_effects[k]
	if lv > 0:                     # maestria fortalece os bônus de buff e de forma
		var bm := 1.0 + Balance.MASTERY_BONUS_PCT * lv
		if effects.get("buff") is Dictionary:
			effects["buff"] = SimEntity.scaled_bonus(effects["buff"], bm)
		if effects.has("form"):
			effects["form_mult"] = bm
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
		TrapSystem.place_trap(self, e, s, aim, power, effects)
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
		MobSystem.spawn_adds(self, e, effects["boss_summon"])
	if effects.get("taunt") != null:
		for o in m["entities"]:
			if o.kind == SimEntity.Kind.MONSTER and o.is_alive() and o.position.distance_to(e.position) <= s.radius + o.radius:
				MobSystem.taunt(self, o, e, float(effects["taunt"].get("duration", Balance.TAUNT_DURATION)))

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
				var r := _strike(e, t, s, power, s.kind if s.kind != SkillDef.Kind.SUMMON else SkillDef.Kind.MAGICAL, from)
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
## Golpe direto (skill ou projétil) em um alvo: gelo estilhaça alvo retardado/preso, a arma lendária multiplica e reage.
## Devolve o resultado de Combat.calc_damage.
func _strike(e: SimEntity, t: SimEntity, s: SkillDef, power: float, kind: SkillDef.Kind, from: Vector3) -> Dictionary:
	var frost := Combat.frost_mult(s, t)
	var r := Combat.calc_damage(e, t, power * (frost * LegendEffects.legend_power(self, e, t)), kind, rng, from)
	var dk := "magical" if s.kind == SkillDef.Kind.MAGICAL else "physical"
	_deal_damage(e, t, r["amount"], r["crit"], r["blocked"], "shatter" if frost > 1.0 and dk == "magical" else dk, from)
	LegendEffects.legend_on_hit(self, e, t, s, int(r["amount"]))
	LegendEffects.signature_on_hit(self, e, t, s, int(r["amount"]))
	return r

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
	if effects.get("stun") != null and (t.kind != SimEntity.Kind.NPC or t.guard):
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
		t.form = "" if t.form == effects["form"] else effects["form"]     # forma liga/desliga (a fantasma também acaba sozinha)
		t.form_mult = float(effects.get("form_mult", 1.0)) if t.form != "" else 1.0
		t.form_left = float(Balance.FORM_DURATION.get(t.form, 0.0))
		t.recompute_stats()
		Events.buff_applied.emit(t.id, "form_" + (t.form if t.form != "" else "human"), t.form_left)
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
		t.put_buff(b)
		t.recompute_stats()
		Events.buff_applied.emit(t.id, b.get("id", "buff"), b["remaining"])
	if effects.get("shield") != null:
		var sh: Dictionary = effects["shield"]
		t.shield_hp = maxf(t.shield_hp, t.stats.max_hp * float(sh.get("amount_pct_hp", 20)) / 100.0)
		var left := float(sh.get("duration", 5)) * longer
		for x in t.buffs:
			if x.get("id") == "shield":
				left = maxf(left, float(x.get("remaining", 0.0)))     # escudo novo não encurta o que já existe
		t.put_buff({"id": "shield", "remaining": left})
		Events.buff_applied.emit(t.id, "shield", left)

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
			if absf(p.position.x) > h.x or absf(p.position.z) > h.y or (not owner.is_perched() and MapGeometry.point_in_solid(self, p.position, m)):     # virote da torre passa por cima do muro
				remove = true
		if not remove:
			for t in m["entities"]:
				if not t.is_alive() or t.id in p.hit_ids or not owner.is_hostile_to(t):
					continue
				var d := Vector2(t.position.x, t.position.z).distance_to(Vector2(p.position.x, p.position.z))
				if d <= t.radius + p.radius:
					p.hit_ids.append(t.id)
					var from: Vector3 = t.position - p.direction        # projétil vem de onde voa, não de quem atirou
					_strike(owner, t, p.skill, p.power, p.skill.kind, from)
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
	if not target.is_alive() or target.is_perched():
		return
	var in_arc := Combat.in_guard_arc(target, attacker.position if from == null else from)
	var parried: bool = target.parry_left > 0.0 and target.is_blocking and attacker != target and not kind.begins_with("dot") and in_arc
	if target.is_blocking and not in_arc and not kind.begins_with("dot") and attacker != target:
		Events.guard_flanked.emit(target.id)
	if parried:
		blocked = true
		amount = maxi(1, int(round(amount * (1.0 - Balance.PARRY_REDUCTION / 100.0))))
		target.parry_left = 0.0
	elif target.monster_def != null and target.monster_def.front_guard > 0.0 and kind == "physical" and attacker != target 			and Combat.in_guard_arc(target, attacker.position if from == null else from):
		blocked = true                          # escudo de frente: pelas costas (ou com magia) o golpe passa inteiro
		amount = maxi(1, int(round(amount * (1.0 - target.monster_def.front_guard))))
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
		if kind != "riposte" and str(target.stats.legend.get("kind", "")) == "riposte" and attacker.is_alive() and attacker.position.distance_to(target.position) <= Balance.LEG_RIPOSTE_RANGE:
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
	target.hit_flash = Balance.HIT_FLASH_TIME
	target.combat_timer = Balance.AGGRO_LOSE_TIME
	target.last_damage_from = attacker.id
	target.threat[attacker.id] = float(target.threat.get(attacker.id, 0.0)) + amount
	if target.kind == SimEntity.Kind.MONSTER:
		var who: int = attacker.owner_id if attacker.kind == SimEntity.Kind.SUMMON else attacker.id   # invocação conta para o dono, mesmo depois de expirar
		if not attacker.guard:              # sentinela não rouba o abate: XP e saque ficam com quem lutou junto
			target.damage_by[who] = float(target.damage_by.get(who, 0.0)) + amount
		MobSystem.retarget(self, target, attacker)
	Events.damage_dealt.emit(attacker.id, target.id, amount, crit, blocked, kind)
	if blocked:
		Events.blocked_hit.emit(target.id)
	if target.hp <= 0.0:
		target.hp = 0.0
		_kill(target, attacker)
	elif blocked and target.stats.has_shield:
		ShieldSystem.shield_reaction(self, target, attacker, amount, parried, from)
	LegendEffects.legend_weapon(self, attacker, target, amount, kind)

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

## Forma com tempo acabou: volta ao normal (mesmo aviso de quando desliga).
func end_form(e: SimEntity) -> void:
	e.form_left = 0.0
	if e.form == "":
		return
	e.form = ""
	e.recompute_stats()
	Events.buff_applied.emit(e.id, "form_human", 0.0)

func _kill(e: SimEntity, killer: SimEntity) -> void:
	e.mounted = false
	e.is_blocking = false
	e.form = ""
	e.form_left = 0.0
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
		LootSystem.on_monster_killed(self, e, killer)
	elif e.kind == SimEntity.Kind.PLAYER:
		Events.notification.emit("Você morreu. Renascendo em %s..." % map_def(PortalSystem.home_of(e)["map"]).name)
		var loss := int(e.xp * Balance.DEATH_XP_PENALTY)
		e.xp = maxi(0, e.xp - loss)
	elif e.kind == SimEntity.Kind.BOT:
		if rng.randf() < 0.5:
			Events.chat_message.emit(e.name, GameData.random_bot_line("death"), "global")

var _elite_defs: Dictionary = {}
var _raid_defs: Dictionary = {}      # "<id>@<passo>" -> MonsterDef da investida reforçada (RaidSystem.scaled_def)

var _gear_pools: Dictionary = {}

# ----------------------------------------------------------------------------
# UPDATE POR ENTIDADE
# ----------------------------------------------------------------------------
func _update_entity(e: SimEntity, m: Dictionary, dt: float) -> void:
	e.state_time += dt
	e.hit_flash = maxf(0.0, e.hit_flash - dt)
	if e.kind == SimEntity.Kind.NPC and not e.guard:
		NpcSystem.update_npc(self, e, m, dt)
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
	if e.form_left > 0.0:
		e.form_left -= dt
		if e.form_left <= 0.0:
			end_form(e)
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
		elif e.guard:
			var back := float(e.npc_data.get("respawn", Balance.GUARD_RESPAWN))
			if back < 0.0:                               # leva de assalto: quem cai não volta
				if e.dead_time >= Balance.CORPSE_TIME:
					despawn(e)
			elif e.dead_time >= back:                    # sentinela volta ao posto
				e.position = e.npc_data.get("pos", e.home_position) if e.npc_data.has("route") else e.home_position
				e.home_position = e.position
				e.set_state(SimEntity.State.IDLE)
				e.threat.clear()
				e.heal_full()
				Events.entity_respawned.emit(e.id)
		elif e.dead_time >= Balance.PLAYER_RESPAWN_TIME + (2.0 if e.kind == SimEntity.Kind.BOT else 0.0):
			ProgressionSystem.respawn_character(self, e)
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
	if e.combat_timer <= 0.0 and (e.is_character() or e.guard):
		e.hp = minf(e.stats.max_hp, e.hp + e.stats.max_hp * Balance.REGEN_HP_PCT * (Balance.GUARD_REGEN_MULT if e.guard else 1.0) * dt)
	if not e.is_blocking:
		e.mp = minf(e.stats.max_mp, e.mp + (e.stats.max_mp * Balance.REGEN_MP_PCT + Balance.REGEN_MP_FLAT) * dt)
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
		MobSystem.update_boss(self, e)
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
		PortalSystem.check_portals(self, e, m)
	if e.kind == SimEntity.Kind.PLAYER and (tick_count + e.id) % 10 == 0:
		QuestSystem.on_position(e)
	# separação entre entidades (empurrão suave), em ticks alternados
	if (tick_count + e.id) % 2 == 0:
		_separate(e, m)

# ----------------------------------------------------------------------------
# MOVIMENTO / COLISÃO (dados do MapDef)
# ----------------------------------------------------------------------------
func _move(e: SimEntity, delta: Vector3, m: Dictionary) -> void:
	var def: MapDef = m["def"]
	var p := e.position + delta
	p.y = 0.0
	p = def.clamp_inside(p, e.radius)
	p = MapGeometry.resolve_obstacles(self, p, e.radius, m)
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
		e.position = MapGeometry.resolve_obstacles(self, e.position, e.radius, m)

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

const SEP_CELL := 3.0

## Uma vez por tick do mapa: grade de 3 m com as entidades vivas (separação olha só as 9 células em volta)
## e a lista de quem um monstro pode querer atacar (jogador, bots, invocações).
## Monstro dorme sem alvo e sem personagem por perto (confere a cada 20 ticks); acorda ao ser atacado ou alguém chegar.
func _dormant(e: SimEntity, m: Dictionary) -> bool:
	if e.aggro_target >= 0 or e.hp < e.stats.max_hp or e.owner_id >= 0 or e.raid_id >= 0:     # investida marcha sozinha
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
		if o.kind == SimEntity.Kind.PLAYER or o.kind == SimEntity.Kind.BOT or o.kind == SimEntity.Kind.SUMMON or o.guard:
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


# ----------------------------------------------------------------------------
# API dos sistemas (core/sim/systems/): repasse para quem usa Sim.<x> fora da sim (jogo, testes, brains)
# ----------------------------------------------------------------------------
# MapGeometry
func water_path(map_id: String, from: Vector3, to: Vector3) -> Array:
	return MapGeometry.water_path(self, map_id, from, to)
func _resolve_obstacles(p: Vector3, r: float, m: Dictionary) -> Vector3:
	return MapGeometry.resolve_obstacles(self, p, r, m)
func _point_in_solid(p: Vector3, m: Dictionary) -> bool:
	return MapGeometry.point_in_solid(self, p, m)
func is_walkable(p: Vector3, def: MapDef, r: float = 0.45) -> bool:
	return MapGeometry.is_walkable(self, p, def, r)
func random_walkable(def: MapDef, center: Vector3, radius: float) -> Vector3:
	return MapGeometry.random_walkable(self, def, center, radius)
# PartySystem
func _party_catchup(dt: float) -> void:
	PartySystem.party_catchup(self, dt)
func party_members(e: SimEntity) -> Array:
	return PartySystem.party_members(self, e)
func party_leader(e: SimEntity) -> SimEntity:
	return PartySystem.party_leader(self, e)
func same_party(a: SimEntity, b: SimEntity) -> bool:
	return PartySystem.same_party(self, a, b)
func kill_sharers(killer: SimEntity, mob: SimEntity) -> Array:
	return PartySystem.kill_sharers(self, killer, mob)
func party_invite_error(from: SimEntity, to: SimEntity) -> String:
	return PartySystem.party_invite_error(self, from, to)
func party_invite(from: SimEntity, to: SimEntity) -> bool:
	return PartySystem.party_invite(self, from, to)
func party_accept(e: SimEntity) -> bool:
	return PartySystem.party_accept(self, e)
func party_decline(e: SimEntity) -> void:
	PartySystem.party_decline(self, e)
func party_leave(e: SimEntity) -> void:
	PartySystem.party_leave(self, e)
func party_kick(leader: SimEntity, target: SimEntity) -> bool:
	return PartySystem.party_kick(self, leader, target)
func party_promote(leader: SimEntity, target: SimEntity) -> bool:
	return PartySystem.party_promote(self, leader, target)
func party_seek_start(e: SimEntity) -> int:
	return PartySystem.party_seek_start(self, e)
func _update_invites() -> void:
	PartySystem.update_invites(self)
# LootSystem
func _on_monster_killed(mob: SimEntity, killer: SimEntity) -> void:
	LootSystem.on_monster_killed(self, mob, killer)
func elite_def(base: MonsterDef) -> MonsterDef:
	return LootSystem.elite_def(self, base)
func top_damager(mob: SimEntity, killer: SimEntity) -> SimEntity:
	return LootSystem.top_damager(self, mob, killer)
func _next_looter(credit: SimEntity, sharers: Array) -> SimEntity:
	return LootSystem.next_looter(self, credit, sharers)
func loot_visible_to(e: SimEntity, l: Dictionary) -> bool:
	return LootSystem.loot_visible_to(self, e, l)
func _split_gold(sharers: Array, gold: int) -> void:
	LootSystem.split_gold(self, sharers, gold)
func gear_pool(tier: int) -> Array:
	return LootSystem.gear_pool(self, tier)
func fits_class(e: SimEntity, it: ItemDef) -> bool:
	return LootSystem.fits_class(self, e, it)
func _update_loot(m: Dictionary, dt: float) -> void:
	LootSystem.update_loot(self, m, dt)
func can_loot(e: SimEntity, l: Dictionary) -> bool:
	return LootSystem.can_loot(self, e, l)
# LegendEffects
func _legend_on_hit(e: SimEntity, t: SimEntity, s: SkillDef, amount: int) -> void:
	LegendEffects.legend_on_hit(self, e, t, s, amount)
func _legend_weapon(attacker: SimEntity, target: SimEntity, amount: int, kind: String) -> void:
	LegendEffects.legend_weapon(self, attacker, target, amount, kind)
# ShieldSystem
func _shield_reaction(target: SimEntity, attacker: SimEntity, amount: int, parried: bool, from: Variant = null) -> void:
	ShieldSystem.shield_reaction(self, target, attacker, amount, parried, from)
func _shield_class_bonus(e: SimEntity, off: ItemDef, parried: bool) -> void:
	ShieldSystem.shield_class_bonus(self, e, off, parried)
func oath_stacks(e: SimEntity) -> int:
	return ShieldSystem.oath_stacks(self, e)
func _shield_power(e: SimEntity, s: SkillDef) -> float:
	return ShieldSystem.shield_power(self, e, s)
# ItemSystem
func enhance_cost(it: ItemDef, current: int) -> Dictionary:
	return ItemSystem.enhance_cost(self, it, current)
func enhance_error(e: SimEntity, item_id: String, slot: int = -1) -> String:
	return ItemSystem.enhance_error(self, e, item_id, slot)
func enhance(e: SimEntity, item_id: String, slot: int = -1) -> ItemDef:
	return ItemSystem.enhance(self, e, item_id, slot)
func use_bag_upgrade(e: SimEntity, item_id: String) -> bool:
	return ItemSystem.use_bag_upgrade(self, e, item_id)
func roll_legendary(killer: SimEntity, mob: SimEntity) -> String:
	return ItemSystem.roll_legendary(self, killer, mob)
func buy_legend_coin(e: SimEntity, count: int = 1) -> bool:
	return ItemSystem.buy_legend_coin(self, e, count)
func reset_tree(e: SimEntity) -> bool:
	return ProgressionSystem.reset_tree(self, e)
func relic_offer(e: SimEntity) -> Array:
	return ItemSystem.relic_offer(self, e)
func relic_cost(it: ItemDef) -> int:
	return ItemSystem.relic_cost(self, it)
func relic_block_reason(e: SimEntity, item_id: String) -> String:
	return ItemSystem.relic_block_reason(self, e, item_id)
func relic_exchange(e: SimEntity, item_id: String) -> bool:
	return ItemSystem.relic_exchange(self, e, item_id)
func legendary_chance(mob: SimEntity) -> float:
	return ItemSystem.legendary_chance(self, mob)
func _uses_shield(e: SimEntity) -> bool:
	return ItemSystem.uses_shield(self, e)
func pick_legendary(killer: SimEntity, mob_level: int) -> String:
	return ItemSystem.pick_legendary(self, killer, mob_level)
func use_potion(e: SimEntity, slot: int) -> bool:
	return ItemSystem.use_potion(self, e, slot)
func equip_error(e: SimEntity, item: ItemDef, to_offhand: bool = false) -> String:
	return ItemSystem.equip_error(self, e, item, to_offhand)
func equip(e: SimEntity, item_id: String, to_offhand: bool = false, want_slot: int = -1) -> bool:
	return ItemSystem.equip(self, e, item_id, to_offhand, want_slot)
func unequip(e: SimEntity, slot: int) -> void:
	ItemSystem.unequip(self, e, slot)
func storage_deposit(e: SimEntity, item_id: String, count: int = 1) -> bool:
	return ItemSystem.storage_deposit(self, e, item_id, count)
func storage_withdraw(e: SimEntity, item_id: String, count: int = 1) -> bool:
	return ItemSystem.storage_withdraw(self, e, item_id, count)
# PortalSystem
func _check_portals(e: SimEntity, m: Dictionary) -> void:
	PortalSystem.check_portals(self, e, m)
func portal_block_reason(e: SimEntity, pt: Dictionary) -> String:
	return PortalSystem.portal_block_reason(self, e, pt)
func grandfather_gates(e: SimEntity, map_id: String) -> void:
	PortalSystem.grandfather_gates(self, e, map_id)
func _process_map_changes() -> void:
	PortalSystem.process_map_changes(self)
func _update_recall(e: SimEntity, cmd: InputCommand, action_cmd: InputCommand, dt: float) -> void:
	PortalSystem.update_recall(self, e, cmd, action_cmd, dt)
func _change_map(e: SimEntity, map_id: String, pos: Vector3) -> void:
	PortalSystem.change_map(self, e, map_id, pos)
# ProgressionSystem
func apply_start_preset(e: SimEntity, preset_id: int) -> void:
	ProgressionSystem.apply_start_preset(self, e, preset_id)
func gain_xp(e: SimEntity, amount: int) -> void:
	ProgressionSystem.gain_xp(self, e, amount)
func resolve_skill(e: SimEntity, s: SkillDef) -> SkillDef:
	return ProgressionSystem.resolve_skill(self, e, s)
static func requires_text(req: Array) -> String:
	return ProgressionSystem.requires_text(req)
func tree_block_reason(e: SimEntity, node_id: String) -> String:
	return ProgressionSystem.tree_block_reason(self, e, node_id)
func pick_sibling(e: SimEntity, node_id: String) -> String:
	return ProgressionSystem.pick_sibling(self, e, node_id)
func tree_allocate(e: SimEntity, node_id: String) -> bool:
	return ProgressionSystem.tree_allocate(self, e, node_id)
func recompute_tree_bonus(e: SimEntity) -> void:
	ProgressionSystem.recompute_tree_bonus(self, e)
func learn_skill(e: SimEntity, skill_id: String) -> bool:
	return ProgressionSystem.learn_skill(self, e, skill_id)
func learn_talent(e: SimEntity, talent_id: String) -> bool:
	return ProgressionSystem.learn_talent(self, e, talent_id)
func set_skill_slot(e: SimEntity, slot: int, skill_id: String) -> bool:
	return ProgressionSystem.set_skill_slot(self, e, slot, skill_id)
func upgrade_mastery(e: SimEntity, skill_id: String) -> bool:
	return ProgressionSystem.upgrade_mastery(self, e, skill_id)
func set_potion_slot(e: SimEntity, slot: int, item_id: String) -> void:
	ProgressionSystem.set_potion_slot(self, e, slot, item_id)
# GatherSystem
func nearest_gather(e: SimEntity) -> Dictionary:
	return GatherSystem.nearest_gather(self, e)
func _update_gather(e: SimEntity, cmd: InputCommand, action_cmd: InputCommand, dt: float) -> void:
	GatherSystem.update_gather(self, e, cmd, action_cmd, dt)
# NpcSystem
func hold_npc(npc_id: String) -> void:
	NpcSystem.hold_npc(self, npc_id)
func _update_npc(e: SimEntity, m: Dictionary, dt: float) -> void:
	NpcSystem.update_npc(self, e, m, dt)
# TrapSystem
func _update_traps(m: Dictionary) -> void:
	TrapSystem.update_traps(self, m)
# MobSystem
func _retarget(mob: SimEntity, attacker: SimEntity) -> void:
	MobSystem.retarget(self, mob, attacker)
func _update_boss(e: SimEntity) -> void:
	MobSystem.update_boss(self, e)
func reset_boss(e: SimEntity) -> void:
	MobSystem.reset_boss(self, e)
# Cristal de retorno
func bind_crystal(e: SimEntity, npc_id: String) -> bool:
	return PortalSystem.bind_crystal(self, e, npc_id)
func home_of(e: SimEntity) -> Dictionary:
	return PortalSystem.home_of(e)
# RaidSystem
func raid_status(map_id: String) -> Dictionary:
	return RaidSystem.status(self, map_id)
