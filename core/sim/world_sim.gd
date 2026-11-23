class_name WorldSim
extends Node
## WorldSim (autoload `Sim`): dona de TODAS as entidades de TODOS os mapas.
## Roda em tick fixo (physics). Não conhece nós 3D. Recebe InputCommands e emite Events.
## Este é o "servidor" — quando virar online, roda headless e recebe comandos por RPC.

const TICK_RATE := 60.0
const AI_EVERY := 3
const RNG_SEED := 1337
var tick_usec := 0.0                 # custo médio de um tick (µs)
var away_every: int = Balance.AWAY_MAP_EVERY     # mapas sem o jogador: 1 = ritmo cheio (--no_away, para medir)

var running: bool = false
var tick_count: int = 0
var time: float = 0.0
var rng := RandomNumberGenerator.new()

var maps: Dictionary = {}          # map_id -> MapState (Dictionary)
var entities: Dictionary = {}      # id -> SimEntity
var despawn_epoch: int = 0         # sobe a cada despawn: quem guarda ids (spawners) só refaz a lista quando muda
var _next_id: int = 1
var _next_proj_id: int = 1
var player: SimEntity = null
var player_cmd: InputCommand = InputCommand.new()
var _pending_map_changes: Array = []
var mounted_basics := {}           # SkillDef do básico -> cópia com o alcance montado (MountedCombat.mounted_basic)
var power_scale := 1.0              # efeitos de graça (assinatura) lançam com menos poder
var ult_tag := 0                    # > 0: o dano que sai agora é de Suprema (soma em SimEntity.ult_dealt; só medição: sondas/testes)
var signatures_on := true
var signature_force := false      # revisão visual: a assinatura dispara sempre (com a recarga)          # sondas: desliga a assinatura para comparar
var _ended: Array = []             # _update_entity: buffs "end_cast" e marcas dot_amp que acabaram (lista reaproveitada)
var ult_quiet := false            # cura que não enche a Carga Suprema (poção; UltimateSystem.on_heal)
var signature_casting := false     # assinatura em andamento: o que ela acertar não dispara outra
var sig_stats: Dictionary = {}       # assinaturas de chefe: contagens para as sondas (BossSignatures.stat; boss_probe zera)
var parties: Dictionary = {}       # party_id -> {"id", "leader": entity_id, "members": Array[int]}
var invites: Dictionary = {}       # entity_id convidado -> {"from", "expires", "decide_at"}
var _next_party_id: int = 1
var party_seek: Dictionary = {}    # /party: entity_id -> {"queue": [ids de bots], "next_at", "until"}

## Semente fixa já na criação: WorldSim.new() fora da árvore (testes, sondas) nunca roda _ready,
## e um RandomNumberGenerator novo nasce com semente aleatória (sorteios mudavam de uma execução para outra).
func _init() -> void:
	rng.seed = RNG_SEED

func _ready() -> void:
	rng.seed = RNG_SEED
	set_physics_process(true)
	process_priority = -1000
	process_physics_priority = -1000
	get_tree().physics_frame.connect(sync)
	get_tree().process_frame.connect(sync)

func _physics_process(delta: float) -> void:
	if not running:
		return
	if not threaded:
		tick(delta)
		return
	sync()
	_queued_cmds.append(player_cmd)                 # o comando deste passo (o tick roda depois, na thread)
	player_cmd = player_cmd.duplicate_cmd()          # como no fim do tick: o de 1 vez não repete no passo seguinte
	player_cmd.attack = false; player_cmd.skill_slot = -1; player_cmd.potion_slot = -1
	player_cmd.interact = false; player_cmd.dash = false; player_cmd.jump = false
	player_cmd.mount = false; player_cmd.recall = false; player_cmd.elem_form = ""; player_cmd.elem_mode = ""
	player_cmd.ultimate = false
	_queued_dt = delta
	if _queued_cmds.size() >= ASYNC_FALLBACK:       # ninguém desenhou (janela minimizada): roda aqui mesmo
		_run_queued()

# ----------------------------------------------------------------------------
# SIM NA THREAD (jogo): o physics só agenda os ticks (com o comando de cada passo); eles rodam numa WorkerThreadPool
# enquanto o quadro desenha (`start_async`, chamado no frame_pre_draw) e quem toca a sim antes espera (`sync`:
# input, physics_frame, process_frame). Events emitidos na thread saem na thread principal no sync, na ordem.
# Testes/sondas chamam tick() direto (threaded = false).
# ----------------------------------------------------------------------------
const ASYNC_FALLBACK := 4
var threaded := false
var _queued_cmds: Array = []
var _queued_dt := 1.0 / TICK_RATE
var _task := -1

## Começa os ticks agendados numa thread (o jogo chama logo antes de desenhar, quando ninguém mais lê a sim).
func start_async() -> void:
	if not threaded or _task >= 0 or _queued_cmds.is_empty():
		return
	Events.deferring_sim = self
	_task = WorkerThreadPool.add_task(_run_queued, true, "sim tick")

## Espera a thread terminar e entrega os eventos dela. Chame antes de ler ou mudar a sim fora do tick.
func sync() -> void:
	if _task < 0:
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	Events.deferring_sim = null
	Events.flush(self)

func _run_queued() -> void:
	var keep := player_cmd                         # o comando que o controle já mandou para o próximo passo
	var cmds := _queued_cmds
	_queued_cmds = []
	for c in cmds:
		player_cmd = c
		tick(_queued_dt)
	player_cmd = keep

## Zera o mundo (voltar ao menu): mapas, entidades, grupos e o jogador. A cena principal recarrega e monta tudo de novo.
func reset_world() -> void:
	sync()
	_queued_cmds.clear()
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
	choir_angels.clear()
	choir_returned.clear()
	tick_count = 0
	time = 0.0

# ----------------------------------------------------------------------------
# MAPAS
# ----------------------------------------------------------------------------
func load_map(def: MapDef) -> Dictionary:
	if maps.has(def.id):
		return maps[def.id]
	var m := {"def": def, "entities": [], "projectiles": [], "loot": [], "spawners": [], "grid": {}, "colliders": [], "traps": [], "hazards": [],
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
	Events.post(&"entity_spawned", e)
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
	# skills iniciais: aprendidas de graça e postas nos primeiros slots (as do nível vêm no fim: grant_level_skills)
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
		e.tree[tr["start"]] = true          # só o início: "<Skill> Aprimorada" das iniciais se compra como as outras
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
	ProgressionSystem.grant_level_skills(self, e, kind != SimEntity.Kind.BOT)     # skills do nível (bot: barra no _slot_bot)
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

## `elem_form` != "": elemental persistente do mago ascendido (ElementalSystem: estágio, nome, tamanho, skills, modo).
func spawn_summon(owner: SimEntity, mdef: MonsterDef, pos: Vector3, duration: float, owner_stats: bool = false, elem_form: String = "") -> SimEntity:
	var e := SimEntity.new()
	e.kind = SimEntity.Kind.SUMMON
	e.name = mdef.name
	e.monster_def = mdef
	e.level = owner.level
	e.owner_id = owner.id
	e.party_id = owner.party_id
	e.player_owned = owner.kind == SimEntity.Kind.PLAYER or owner.player_owned     # boneco de treino aceita
	e.position = pos
	e.home_position = pos
	e.radius = mdef.radius
	e.scale = mdef.scale
	if owner.is_character() and owner.stats:
		duration = owner.stats.summon_time_of(duration)     # invocação com tempo dura mais (acessório lendário); 0 continua 0
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
	if elem_form != "":
		e.summon_patk *= ElementalSystem.stage_mult(owner, "atk")     # estágio do elemental: depois do limite SUMMON_ATK_MAX
	if owner_stats:
		e.summon_pdef = owner.stats.pdef * Balance.PET_DEF_SHARE     # sobrevive ao recompute (fim do Laço Selvagem)
	e.recompute_stats()
	e.stats.patk = e.summon_patk
	e.stats.matk = e.summon_patk
	if elem_form != "":
		ElementalSystem.prepare(owner, e, elem_form)
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
	if n.has("power") or n.has("hp_power"):   # guarnição de faixa alta (Estepes): mesmo soldado, vida e ataque x power (e vida x hp_power)
		mdef = WorldState.assault_def(self, mdef, float(n.get("power", 1.0)), float(n.get("hp_power", 1.0)))
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
	_skill_bot(b, true)               # atributos refeitos uma vez no fim (o heal_full abaixo acerta o HP)
	b.heal_full()                     # a teia mexe no HP máximo: nasce cheio
	return b

## Equipamento de bot pronto por "<classe>|<build>|<tier>|<raridade>|<secundária>|<titã>" -> [[slot, ItemDef], ...] na ordem
## em que a varredura de GameData.items os pôs. Refeito se GameData.items crescer (peças +N do aprimoramento).
var _bot_gear_cache: Dictionary = {}
## true = escolha de equipamento de bot de antes de 2026-11-23 (última peça da lista; só sondas A/B: boss_probe --old_gear).
static var bot_gear_legacy := false
var _bot_gear_items := -1

## Equipamento de bot: tier comum pelo nível; armas da build (principal + secundária).
func _gear_bot(b: SimEntity) -> void:
	var tier := 0                       # maior tier comum que o nível alcança (Balance.COMMON_TIER_LEVELS)
	for i in range(Balance.COMMON_TIER_LEVELS.size()):
		if b.level >= Balance.COMMON_TIER_LEVELS[i]:
			tier = i
	var rarity := GearCatalog.common_rarity(tier)   # do tier 4 em diante a raridade fica em épico: o tier vem do nível da peça
	var build := b.class_def.build_by_id(b.build_id)
	var main_types: Array = build.get("main", b.class_def.weapon_types)
	var off_types: Array = build.get("off", [])
	var titan := TitanSystem.bot_wants_pair(b)
	if titan:                                     # ascendido: machado de 2 mãos nas duas mãos (Empunhadura de Titã)
		main_types = Balance.TITAN_WEAPONS
		off_types = Balance.TITAN_WEAPONS
	if "shield" in off_types and off_types.size() > 1:
		off_types = [off_types[rng.randi() % off_types.size()]]     # orbe ou escudo: cada bot escolhe
	b.equipment.clear()
	var key := "%s|%s|%d|%d|%s|%s" % [b.class_def.id, b.build_id, tier, rarity, off_types[0] if off_types.size() > 0 else "", titan]
	if _bot_gear_items != GameData.items.size():
		_bot_gear_cache.clear()
		_bot_gear_items = GameData.items.size()
	if ProgressionSystem.bot_spawn_cache and _bot_gear_cache.has(key):
		for pair in _bot_gear_cache[key]:
			b.equipment[pair[0]] = pair[1]
	else:
		_gear_scan(b, build, tier, rarity, main_types, off_types)
		var picked: Array = []
		for slot in b.equipment:
			picked.append([slot, b.equipment[slot]])
		_bot_gear_cache[key] = picked
	var w: ItemDef = b.equipment.get(ItemDef.Slot.WEAPON)
	if w and w.is_two_handed() and not (titan and TitanSystem.pair_ok(b)):
		b.equipment.erase(ItemDef.Slot.OFFHAND)
	b.recompute_stats()
	b.heal_full()
	Events.post(&"equipment_changed", b.id)   # a view já existe (spawn emite antes)

## Varredura de GameData.items do _gear_bot (sem o corte da 2ª mão de arma de duas mãos).
func _gear_scan(b: SimEntity, build: Dictionary, tier: int, rarity: int, main_types: Array, off_types: Array) -> void:
	for item_id in GameData.items:
		var it: ItemDef = GameData.items[item_id]
		if not it.is_equipment() or it.rarity != rarity or GearCatalog.craft_only(it):     # joia/capa 45 de troféu: só por receita
			continue
		if it.plus > 0:          # cópia +N criada no ferreiro (GameData.plus_item): fica no fim da lista e venceria a peça base
			continue
		if rarity == ItemDef.RARITY_LEGENDARY - 1:          # épico: vários tiers dividem a raridade, separa pelo nível
			var it_tier := ItemSystem.item_tier(self, it)
			if it_tier > tier or (tier > rarity and it_tier < tier):
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
			# o de mais atributo principal da build (antes o último: FOR vestia capa/amuleto do Caçador, FOR só de 2º; C5)
			var at: String = build.get("attr", "")
			var acc: ItemDef = b.equipment.get(it.slot)
			if bot_gear_legacy and it.attr(at) > 0:
				b.equipment[ItemDef.Slot.RING2 if it.slot == ItemDef.Slot.RING and b.equipment.has(ItemDef.Slot.RING) else it.slot] = it
			elif it.attr(at) > 0 and (acc == null or it.attr(at) >= acc.attr(at)):
				b.equipment[it.slot] = it
				if it.slot == ItemDef.Slot.RING:
					b.equipment[ItemDef.Slot.RING2] = it     # os dois anéis: o melhor
		else:
			# cabeça/peito/luvas/botas: o tipo de armadura da build vence (antes a última da lista, pano, ficava
			# e o corpo a corpo do 40+ vestia INT; combat-plan C5). Sem peça do tipo, fica a que houver.
			var want: String = build.get("armor", "")
			var cur: ItemDef = b.equipment.get(it.slot)
			if bot_gear_legacy or want == "" or it.armor_style == want or cur == null or cur.armor_style != want:
				b.equipment[it.slot] = it
	if b.equipment.has(ItemDef.Slot.RING) and not b.equipment.has(ItemDef.Slot.RING2):
		b.equipment[ItemDef.Slot.RING2] = b.equipment[ItemDef.Slot.RING]

## Skills de bot: gasta os pontos do nível na teia como um jogador da build (ProgressionSystem.bot_spend) e
## equipa as 6 primeiras skills da build que aprendeu e que a arma permite.
## `batch` = atributos refeitos uma vez no fim (só quem dá heal_full depois: spawn_bot).
func _skill_bot(b: SimEntity, batch: bool = false) -> void:
	ProgressionSystem.bot_spend(self, b, true, batch and ProgressionSystem.bot_spawn_cache)
	ProgressionSystem.bot_spend_asc(self, b)      # teia de ascensão (só ascendido)
	_slot_bot(b)

func _slot_bot(b: SimEntity) -> void:
	var build := b.class_def.build_by_id(b.build_id)
	var ids: Array = build.get("skills", b.class_def.skill_ids)
	b.ensure_slots()
	for i in range(b.skills.size()):
		b.skills[i] = null
	var slot := 0
	for sid in ids + b.learned.keys():
		var s: SkillDef = GameData.skills.get(sid)
		if s == null or s.ascension or not b.learned.has(s.id) or b.slot_of(s.id) >= 0:
			continue                 # skill de ascensão: vagas extras (abaixo), nunca no lugar de uma da build
		if not (s.id in ids) and not (s.build in ["", b.build_id]) and not (s.id in b.class_def.starting_skills):
			continue                 # skill de outra build (o nível dá todas): o bot fica com as da build dele e as gerais
		if slot < Balance.SKILL_SLOTS and b.stats.meets(s.requires):
			b.skills[slot] = s
			slot += 1
	var fs: SkillDef = FusionEffects.bot_slot_skill(b)       # Fusão que pede uma skill na barra (E1 Vapor: uma de gelo)
	if fs != null and b.slot_of(fs.id) < 0:
		b.skills[mini(slot, Balance.SKILL_SLOTS - 1)] = fs
	# ascensão: vagas 7-0 com as skills aprendidas na teia de ascensão, na ordem da build (AscensionCatalog.bot_order).
	# As de BOT_NO_SLOT (Comando Elemental) ficam fora: o bot manda forma/modo pelo InputCommand.
	slot = Balance.SKILL_SLOTS
	for sid in AscensionCatalog.bot_order(b.class_def, b.build_id, GameData.skills):
		if slot < b.skills.size() and b.learned.has(sid) and not (sid in AscensionCatalog.BOT_NO_SLOT):
			b.skills[slot] = GameData.skills[sid]
			slot += 1

func despawn(e: SimEntity) -> void:
	if e == null or not entities.has(e.id):
		return
	if e.party_id >= 0 and e.kind != SimEntity.Kind.SUMMON:
		PartySystem.party_leave(self, e)
	invites.erase(e.id)
	entities.erase(e.id)
	despawn_epoch += 1
	if maps.has(e.map_id):
		maps[e.map_id]["entities"].erase(e)
		if maps[e.map_id].has("chars"):
			maps[e.map_id]["chars"].erase(e)       # a lista do tick não pode guardar quem saiu
	Events.post(&"entity_despawned", e.id)

# ----------------------------------------------------------------------------
# TICK
# ----------------------------------------------------------------------------
func set_player_command(cmd: InputCommand) -> void:
	player_cmd = cmd

var profile := false                 # --perf: soma o tempo de cada fase do tick
var prof: Dictionary = {}
const _APPLY_KEYS := ["apply_PLAYER", "apply_BOT", "apply_MONSTER", "apply_NPC", "apply_SUMMON"]     # por SimEntity.Kind (sem montar texto por entidade)
const _UPD_KEYS := ["upd_PLAYER", "upd_BOT", "upd_MONSTER", "upd_NPC", "upd_SUMMON"]

func _prof(key: String, since: int) -> void:
	prof[key] = float(prof.get(key, 0.0)) + float(Time.get_ticks_usec() - since)

## Mapa que está rodando agora no tick ("" fora do laço): eventos sem mapa (skill_effect...) saem daqui.
var ticking_map := ""

func tick(dt: float) -> void:
	var t_start := Time.get_ticks_usec()
	tick_count += 1
	time += dt
	ult_tag = 0                         # guarda: a marca de medição nunca vaza entre tiques
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
		ticking_map = map_id              # quem ouve os eventos (efeitos) sabe de que mapa vieram
		var ents: Array = m["entities"]
		var it := Time.get_ticks_usec() if profile else 0
		_index_map(m)                       # grade de vizinhos + lista de personagens (separação e alvo dos monstros)
		if profile:
			_prof("index_map", it)
		var pt := Time.get_ticks_usec() if profile else 0
		var map_t := pt
		# 1) comandos (jogador + cérebros)
		for e: SimEntity in ents:
			if not e.is_alive():
				continue
			var cmd: InputCommand = null
			if e == player:
				cmd = player_cmd
			elif e.brain != null:
				if e.kind == SimEntity.Kind.MONSTER:
					# dormindo e fora do tick de conferência: o mesmo que _dormant devolveria, sem a chamada
					if e.dormant and (tick_count + e.id) % 20 != 0 and e.aggro_target < 0 and e.owner_id < 0 and e.raid_id < 0 and e.hp >= e.stats.max_hp:
						continue
					if _dormant(e, m):
						continue
				# cérebros pensam a 20 Hz (escalonados por id); entre pensamentos repetem o movimento
				var every := AI_EVERY * 2 if (e.raid_id >= 0 or e.guard) else AI_EVERY      # horda e guarnição: 10 Hz (batalha grande)
				if (tick_count + e.id) % every == 0 or e.brain_cmd == null:
					var bt := Time.get_ticks_usec() if profile else 0
					cmd = e.brain.think(e, self, m, mdt * every)
					if profile:
						_prof("think_" + ("bot" if e.kind == SimEntity.Kind.BOT else "mob"), bt)
					e.brain_cmd = cmd
				else:
					if e.repeat_cmd == null:
						e.repeat_cmd = InputCommand.new()
					cmd = e.repeat_cmd                 # só movimento, mira e guarda se repetem
					cmd.move = e.brain_cmd.move; cmd.aim = e.brain_cmd.aim; cmd.block = e.brain_cmd.block
					cmd.attack = false; cmd.skill_slot = -1; cmd.potion_slot = -1; cmd.dash = false; cmd.interact = false; cmd.jump = false
					cmd.mount = false; cmd.recall = false; cmd.elem_form = ""; cmd.elem_mode = ""          # ações de 1 vez: repetir trocaria a montaria a cada tick
					cmd.ultimate = false
			if cmd != null:
				var at := Time.get_ticks_usec() if profile else 0
				_apply_command(e, cmd, m, mdt)
				if profile:
					_prof(_APPLY_KEYS[e.kind], at)
		if profile:
			_prof("commands", pt)
			pt = Time.get_ticks_usec()
		# 2) estados, cooldowns, movimento
		for e: SimEntity in ents.duplicate():
			if e.dormant and e.state == SimEntity.State.IDLE and e.debuffs.is_empty():
				continue                        # dormindo: nada muda até alguém chegar perto
			var ut := Time.get_ticks_usec() if profile else 0
			_update_entity(e, m, mdt)
			if profile:
				_prof(_UPD_KEYS[e.kind], ut)
		if profile:
			_prof("entities", pt)
			pt = Time.get_ticks_usec()
		_update_projectiles(m, mdt)
		if profile:
			_prof("r_projectiles", pt); pt = Time.get_ticks_usec()
		WorldState.update(self, m, mdt)
		MobSystem.update_spawners(self, m, mdt)
		RaidSystem.update_raids(self, m, mdt)
		SiegeSystem.update(self, m, mdt)
		RoadEventSystem.update(self, m, mdt)
		if profile:
			_prof("r_spawners", pt); pt = Time.get_ticks_usec()
		TrapSystem.update_traps(self, m)
		MobSystem.update_hazards(self, m)
		if m.has("storms") or m.has("ally_strikes"):
			StormSystem.tick(self, m)                # Supremas: tempestades e golpes avisados com dono jogador
		NecroAscension.tick(self, m)
		ClassTalentSystem.tick(self, m, mdt)
		AuraSystem.tick(self, m, mdt)
		FusionEffects.tick(self, m)                # Posto Avançado (Ápice do Atirador): regenera perto da torreta
		ElementalSystem.tick(self, m, mdt)
		ChoirSystem.tick(self, m, mdt)
		LootSystem.update_loot(self, m, mdt)
		if profile:
			_prof("r_loot", pt); pt = Time.get_ticks_usec()
		if profile:
			_prof("rest", pt)
			_prof("map_" + map_id, map_t)
	ticking_map = ""
	# descarta inputs de 1 tick do jogador
	player_cmd = player_cmd.duplicate_cmd()
	player_cmd.attack = false; player_cmd.skill_slot = -1; player_cmd.potion_slot = -1
	player_cmd.interact = false; player_cmd.dash = false; player_cmd.jump = false
	player_cmd.mount = false; player_cmd.recall = false; player_cmd.elem_form = ""; player_cmd.elem_mode = ""
	player_cmd.ultimate = false
	PortalSystem.process_map_changes(self)
	PartySystem.party_catchup(self, dt)
	BotChat.update(self)
	if not invites.is_empty():
		PartySystem.update_invites(self)
	tick_usec = tick_usec * 0.95 + float(Time.get_ticks_usec() - t_start) * 0.05     # média móvel (overlay/medição)

# ----------------------------------------------------------------------------
# COMANDOS
# ----------------------------------------------------------------------------
func _apply_command(e: SimEntity, cmd: InputCommand, m: Dictionary, dt: float) -> void:
	e.last_cmd = cmd
	if (cmd.elem_form != "" or cmd.elem_mode != "") and e.is_alive():
		ElementalSystem.command(self, e, cmd.elem_form, cmd.elem_mode)     # ascensão do Elementalista: forma/modo do elemental
	if e.state == SimEntity.State.STUNNED or e.state == SimEntity.State.DEAD:
		if e.recall_left > 0.0:
			PortalSystem.interrupt_recall(self, e)       # atordoado no meio da volta: interrompe
		if e.mount_left > 0.0:
			stop_mount(e, "Montaria interrompida")
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

	# --- montaria (H): conjuração de MOUNT_CAST_TIME (vale em combate e andando); agir ou levar golpe interrompe ---
	if cmd.mount and e.is_character():
		if e.mounted:
			dismount(e)
		elif e.mount_left > 0.0:
			stop_mount(e, "")                      # H de novo cancela
		elif e.state == SimEntity.State.CASTING or e.airborne() or e.form != "":
			if e == player:
				Events.post(&"notification", "Não dá para montar agora")
		elif m["def"].no_mount():
			if e == player:
				Events.post(&"notification", "Não dá para montar aqui")      # masmorra: só a pé
		else:
			MountedCombat.arcane_off(self, e, "Modo Arcano desligado (montaria)")     # montar desliga as asas
			e.mount_left = Balance.MOUNT_CAST_TIME
			e.is_blocking = false
	elif e.mount_left > 0.0:
		if action_cmd.attack or action_cmd.skill_slot >= 0 or action_cmd.ultimate or action_cmd.dash or action_cmd.jump or cmd.block or cmd.recall or e.recall_left > 0.0:
			stop_mount(e, "Montaria interrompida")
		else:
			e.mount_left -= dt
			if e.mount_left <= 0.0:
				e.mount_left = 0.0
				e.mounted = true
				e.is_blocking = false
				Events.post(&"mount_changed", e.id, true)
	if cmd.recall or e.recall_left > 0.0:           # sem volta pedida nem em curso não há o que fazer (nem montar o destino)
		PortalSystem.update_recall(self, e, cmd, action_cmd, dt)
	if e.gather_left > 0.0:
		GatherSystem.update_gather(self, e, cmd, action_cmd, dt)
	# atacar, usar skill, dash ou bloquear: desce do cavalo e a ação acontece (Combate Montado: só dash e bloqueio descem;
	# golpe e skill montável saem a cavalo, a não montável é recusada em try_cast)
	if e.mounted and (action_cmd.attack or action_cmd.skill_slot >= 0 or action_cmd.dash or cmd.block):
		if action_cmd.dash or (cmd.block and not MountedCombat.mounted_wall(e)) or not MountedCombat.fights_mounted(e):
			dismount(e)                     # Muralha a Cavalo (Guardião 45): bloqueia sem descer

	# --- poções: a qualquer momento vivo ---
	if action_cmd.potion_slot >= 0:
		ItemSystem.use_potion(self, e, action_cmd.potion_slot)

	# --- pulo (Espaço): no ar anda e dá dash; golpes e skills ficam no buffer até o pouso ---
	if cmd.jump and e.can_act() and not e.airborne() and not e.has_debuff("root"):
		e.jump_v = Balance.JUMP_VELOCITY
		e.jump_h = 0.001
		e.is_blocking = false
		Events.post(&"skill_cast", e.id, "jump", "active")

	# --- dash ---
	if action_cmd.dash and e.dash_cd <= 0.0 and (e.can_act() or _in_cancel_window(e) or _dash_cancels(e, action_cmd)) and not e.has_debuff("root"):
		if e.state == SimEntity.State.CASTING:
			_cancel_cast(e)
		if not e.hop.is_empty():
			HopSystem.cancel(e)                       # dash corta o resto dos saltos (Lua Rubra)
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
		e.iframe_left = Balance.DASH_IFRAMES
		FusionEffects.ghost(self, e)                 # Passo Fantasma (A1): o dash deixa o próximo golpe furtivo
		e.set_state(SimEntity.State.DASHING, Balance.DASH_TIME)
		Events.post(&"skill_cast", e.id, "dash", "active")
		return

	# --- Suprema (R): mesmo pipeline das skills; a carga só sai quando ela sai (UltimateSystem) ---
	if action_cmd.ultimate and not e.airborne() and e.is_character() and (e.can_act() or _in_cancel_window(e) or _can_chain(e, action_cmd)):
		if UltimateSystem.try_cast(self, e, action_cmd.aim, m):
			return
	# --- skills ---
	if action_cmd.skill_slot >= 0 and not e.airborne() and (e.can_act() or _in_cancel_window(e) or _can_chain(e, action_cmd)):
		if try_cast(e, action_cmd.skill_slot, action_cmd.aim, m):
			return
	# --- ataque básico ---
	if action_cmd.attack and not e.airborne() and (e.can_act() or _in_cancel_window(e) or _can_chain(e, action_cmd)) and e.basic_cd <= 0.0 and e.basic_skill:
		_start_skill(e, MountedCombat.mounted_basic(self, e.basic_skill) if e.mounted else e.basic_skill, -1, action_cmd.aim)
		e.basic_cd = e.stats.basic_cooldown(e.basic_skill.cooldown) * RangerAscension.attack_slow_mult(e) * Combat.frost_attack_mult(e)     # Geada / lentidão de gelo: ataca mais devagar
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
		var hurt := not e.debuffs.is_empty()          # sem debuff não há raiz nem lentidão (o caso comum)
		if hurt and e.has_debuff("root"):
			mv = Vector3.ZERO
		if mv.length_squared() > 0.001:
			var spd := e.stats.move_speed * (e.slow_factor() if hurt else 1.0) * (0.5 if e.is_blocking else 1.0) * (MountedCombat.move_mult(e) if e.mounted else 1.0)
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

## Para a conjuração do cavalo (agir, levar golpe, atordoado, H de novo). `why` vazio = sem aviso.
func stop_mount(e: SimEntity, why: String) -> void:
	e.mount_left = 0.0
	if e == player and why != "":
		Events.post(&"notification", why)

## Fração já conjurada do cavalo (0..1; 0 = não está montando). Barra de conjuração do HUD e da cabeça.
func mount_progress(e: SimEntity) -> float:
	if e.mount_left <= 0.0:
		return 0.0
	return clampf(1.0 - e.mount_left / Balance.MOUNT_CAST_TIME, 0.0, 1.0)

## Desce do cavalo (golpe, dano, troca de mapa, morte ou H).
func dismount(e: SimEntity) -> void:
	if not e.mounted:
		return
	e.mounted = false
	Events.post(&"mount_changed", e.id, false)

func _in_cancel_window(e: SimEntity) -> bool:
	if e.state != SimEntity.State.CASTING or e.current_skill == null:
		return false
	var s := e.current_skill
	return e.skill_applied and e.state_time >= s.startup + s.active + minf(s.cancel_after, Balance.CANCEL_AFTER_MAX)

## Companheiro vivo do dono (invocação permanente), ou null.
## Invocações vivas desta skill já no máximo (com o extra dos talentos)? Grupo exclusivo (elementais) troca, então
## só conta o mesmo monstro.
func _summons_full(e: SimEntity, s: SkillDef) -> bool:
	var sm: Dictionary = s.effects["summon"]
	if ElementalSystem.takes_over(e, sm):          # ascensão: o elemental é um só; bot troca de forma pelo comando, não pela skill
		var cur := ElementalSystem.elemental_of(self, e)
		return cur != null and (e != player or cur.elem_form == ElementalSystem.form_of_monster(str(sm.get("monster_id", ""))))
	var permanent: bool = float(sm.get("duration", 20)) <= 0.0 or ClassTalentSystem.summon_permanent(e, s.id)
	if not permanent or not maps.has(e.map_id):
		return false
	var alive := 0
	for o in maps[e.map_id]["entities"]:            # só conta quem está com o dono: a perdida (presa longe) se chama de novo
		if o.kind == SimEntity.Kind.SUMMON and o.owner_id == e.id and o.is_alive() and o.monster_def and o.monster_def.id == sm.get("monster_id", "") and not o.grave \
				and o.position.distance_to(e.position) <= Balance.SUMMON_LEASH:
			alive += 1
	return alive >= int(sm.get("max", 3)) + ClassTalentSystem.summon_extra(e, s.id) + NecroAscension.summon_extra(e)

func pet_of(e: SimEntity) -> SimEntity:
	for o in maps[e.map_id]["entities"] if maps.has(e.map_id) else []:
		if o.kind == SimEntity.Kind.SUMMON and o.owner_id == e.id and o.is_alive() and o.summon_expires == INF:
			return o
	return null

func _pet_command(e: SimEntity, s: SkillDef, aim: Vector3, power: float, effects: Dictionary, m: Dictionary) -> void:
	var pet := pet_of(e)
	var target: SimEntity = null
	var best := s.range + 1.0
	for o: SimEntity in m["entities"]:
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
	var stun := float(effects["pet_command"].get("stun", 0.0))
	if effects.get("stun") is Dictionary:          # talento (Bote Brutal): o atordoamento da skill vale na mordida
		stun = maxf(stun, float(effects["stun"].get("duration", 0.0)))
	if stun > 0.0:
		_apply_effects(e, target, {"stun": {"duration": stun}}, power)
	Events.post(&"skill_effect", s.id, pet.position, target.position, 1.0)

# ----------------------------------------------------------------------------
# ARMADILHAS (Ranger Atirador): ficam no mapa, armam, disparam quando um inimigo pisa, somem com o tempo
# ----------------------------------------------------------------------------
var _next_trap_id := 1
## Coro Celeste (ChoirSystem): ids dos anjos vivos, de quem já voltou pelo Retorno nesta luta e contador de cúpulas.
var choir_angels: Array = []
var choir_returned: Array = []
var choir_next_id := 0

## Radiância (Bispo da luz): parte do dano mágico cura o aliado mais ferido por perto (você incluso).
func _radiance(e: SimEntity, amount: int) -> void:
	var best := most_hurt_friend(e, Balance.RADIANCE_RANGE)
	if best.hp < best.stats.max_hp:
		_heal(e, best, maxi(1, int(round(amount * e.stats.radiance / 100.0))))

## Clérigo de Batalha: `pct` do dano cura o aliado mais ferido por perto; se for você mesmo, só Balance.MEND_SELF_MULT
## (é cura de grupo, não roubo de vida).
func mend(e: SimEntity, amount: int, pct: float) -> void:
	var f := most_hurt_friend(e, Balance.RADIANCE_RANGE)
	if f.hp >= f.stats.max_hp:
		return
	_heal(e, f, maxi(1, int(amount * pct * (Balance.MEND_SELF_MULT if f == e else 1.0))))

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
	if not e.is_character() or e.state != SimEntity.State.CASTING or e.current_skill == null or not e.skill_applied or e.sky_left > 0.0:
		return false            # no ar (Salto Dracônico): só depois do pouso
	if cmd == null or not (cmd.skill_slot >= 0 or cmd.attack or cmd.ultimate):
		return false
	if cmd.skill_slot < 0 and not cmd.ultimate and e.current_skill_slot < 0:      # slot -1 = básico (também a cópia montada)
		return false            # básico atrás de básico mantém o ritmo dele (senão a velocidade de ataque sobe)
	if cmd.skill_slot < 0 and not cmd.ultimate and e.skill_phase == "active" and e.current_skill.effects.get("channel") is Dictionary \
			and e.channel_done < int(e.current_skill.effects["channel"].get("ticks", 3)):
		return false            # canal: o básico (segurado) espera o último pulso; skill/dash apertados ainda cortam
	var last_hit := 0.0
	if e.current_skill.effects.get("strikes") is Dictionary:      # sequência de golpes: só depois do último
		var at_s: Array = e.current_skill.effects["strikes"].get("at", [0.0])
		last_hit = float(at_s.back()) if not at_s.is_empty() else 0.0
	return e.state_time >= e.current_skill.startup + last_hit + Balance.CHAIN_AFTER_IMPACT

## Quanto da velocidade sobra durante a skill: investidas não andam, magias longas quase param.
func cast_move_mult(s: SkillDef) -> float:
	if s == null or s.effects.has("dash") or s.effects.has("dragon_jump"):
		return 0.0
	return Balance.CAST_MOVE_MULT_HEAVY if s.startup >= Balance.CAST_HEAVY_STARTUP else Balance.CAST_MOVE_MULT

## Dash interrompe qualquer skill: é a saída de emergência do jogador.
func _dash_cancels(e: SimEntity, cmd: InputCommand) -> bool:
	return cmd.dash and e.is_character() and e.state == SimEntity.State.CASTING and e.dash_cd <= 0.0 and e.sky_left <= 0.0

## Fim antecipado por dash: antes do impacto nada aconteceu, então devolve MP e recarga.
func _cancel_cast(e: SimEntity) -> void:
	var s := e.current_skill
	if s and not e.skill_applied and e.current_skill_slot >= 0:
		e.mp = minf(e.stats.max_mp, e.mp + e.stats.mp_cost_of(s.mp_cost_at(e.mastery_of(s.id))))
		e.cooldowns.erase(s.id)
		ChargeSystem.refund(e, s.id)
		if e.jump_second:
			RangerAscension.on_cancel(e, s)      # Salto Duplo: o 2º salto cancelado gasta a janela (a recarga cheia volta)
	_end_skill(e)

func _interact(e: SimEntity, m: Dictionary) -> void:
	var best: SimEntity = null
	var best_d := 2.6
	for o: SimEntity in m["entities"]:
		if o.kind == SimEntity.Kind.NPC:
			var d: float = o.position.distance_to(e.position) - float(o.npc_data.get("reach", 0.0))     # `reach`: alcance a mais (pescador no cais)
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
	Events.post(&"dialog_requested", best.npc_data.get("id", ""))

# ----------------------------------------------------------------------------
# SKILLS
# ----------------------------------------------------------------------------
func try_cast(e: SimEntity, slot: int, aim: Vector3, m: Dictionary) -> bool:
	if slot < 0 or slot >= e.skills.size() or e.skills[slot] == null:
		return false
	var s: SkillDef = e.skills[slot]
	if e.level < s.unlock_level or (e.is_character() and not e.knows(s.id)):
		return false
	if e.is_character() and s.ascension != (slot >= Balance.SKILL_SLOTS):
		return false                  # barra 1-6 = teia comum, 7-0 = só skills de ascensão
	if e.is_character() and not e.stats.meets(s.requires):
		if e == player:
			Events.post(&"notification", "%s exige: %s" % [s.name, ProgressionSystem.requires_text(s.requires)])
		return false
	if s.ascension and e.is_character() and not ProgressionSystem.has_ascension(e):
		if e == player:
			Events.post(&"notification", "%s: requer a ascensão da classe" % s.name)
		return false
	var mount_why := MountedCombat.block_reason(e, s)
	if mount_why != "":
		if e == player:
			Events.post(&"notification", mount_why)
		return false
	var lv := e.mastery_of(s.id)
	if e.cooldowns.get(s.id, 0.0) > 0.0:
		return false
	var cost := e.stats.mp_cost_of(s.mp_cost_at(lv) * ProgressionSystem.web_mp_mult(e, s.id))     # nó "Ágil" e desconto de mana (acessório lendário)
	if s.effects.has("arcane") and MountedCombat.arcane_on(e):
		cost = 0.0                 # desligar as asas não custa MP (sem MP o bot ficava pedindo para desligar)
	if e.mp < cost:
		if e == player:
			Events.post(&"notification", "MP insuficiente")
		return false
	var form_fx: String = s.effects.get("form", "")
	if form_fx != "" and e.form == form_fx and e != player:
		return false               # bot já transformado não desfaz a forma
	if s.effects.has("aura") and e != player and AuraSystem.aura_on(e, s):
		return false               # bot com a aura ligada não a desliga
	var elem_block := ElementalSystem.cast_block(self, e, s)       # ascensão do Elementalista (exige; troca de forma em recarga)
	if elem_block != "":
		if e == player:
			Events.post(&"notification", elem_block)
		return false
	if s.effects.has("summon") and _summons_full(e, s):
		if e == player:
			Events.post(&"notification", "Seu companheiro já está com você" if float(s.effects["summon"].get("duration", 20)) <= 0.0 else "%s: já estão todos com você" % s.name)
		return false
	if (s.effects.has("pet_command") or s.effects.get("pet_buff", false) is bool and s.effects.get("pet_buff", false)) and pet_of(e) == null:     # "if_any" = no lince se houver
		if e == player:
			Events.post(&"notification", "%s: chame o companheiro primeiro" % s.name)
		return false
	var falcon_block := FalconSystem.cast_block(e, s)       # Falcoeiro: um falcão só; Mergulho/Olhos do Céu pedem o falcão
	if falcon_block != "":
		if e == player:
			Events.post(&"notification", falcon_block)
		return false
	if not DruidAscension.form_ok(e, s.requires_form):
		if e == player:
			Events.post(&"notification", "%s: só na forma de %s" % [s.name, SkillDef.FORM_LABELS.get(s.requires_form, s.requires_form)])
		return false
	if s.effects.get("sacrifice") is Dictionary:     # Oferenda Sombria: sem morto-vivo seu perto do ponto, nem gasta MP
		var sac_why := SummonRites.block_reason(self, e, s, aim)
		if sac_why != "":
			if e == player:
				Events.post(&"notification", "%s: %s" % [s.name, sac_why])
			return false
	if s.effects.has("choir_return"):          # Retorno: precisa de um caído do grupo que ainda não voltou nesta luta
		var res_why := ChoirSystem.return_block(self, e, aim)
		if res_why != "":
			if e == player:
				Events.post(&"notification", res_why)
			return false
	s = ProgressionSystem.resolve_skill(self, e, s)
	e.mp -= cost
	e.cooldowns[s.id] = ChargeSystem.on_cast(e, s, s.cooldown_at(lv) * e.stats.skill_cooldown_mult(s.id))     # nó "em Cargas": guarda usos
	ShadowSystem.on_cast(e, s)             # Contra-Ataque em Cadeia: a Execução preparada não entra em recarga
	if s.ascension:
		TitanSystem.on_cast(e, s)          # Fúria Acesa: o Ciclone de Titã segura a Fúria/Glória
		RangerAscension.on_cast(e, s)      # Salto Duplo: o 2º salto sai sem recarga
	_start_skill(e, s, slot, aim)
	if s.effects.has("choir_return"):
		ChoirSystem.begin_return(self, e, s, aim)     # o caído espera a conjuração em vez de renascer na cidade
	return true

func _start_skill(e: SimEntity, s: SkillDef, slot: int, aim: Vector3) -> void:
	if e.state == SimEntity.State.CASTING:
		_end_skill(e)
	if e.stealth_left > 0.0 and not s.effects.has("stealth"):
		e.stealth_left = 0.0
		e.ambush = s.kind in [SkillDef.Kind.PHYSICAL, SkillDef.Kind.MAGICAL]     # sai da sombra golpeando
		if e.ambush:
			ShadowSystem.on_ambush(self, e)       # refino Lâminas: o clone sai da furtividade junto
	e.current_skill = s
	e.current_skill_slot = slot
	e.skill_aim = aim
	e.skill_applied = false
	e.skill_phase = "startup"
	e.is_blocking = false
	e.velocity = Vector3.ZERO
	e.face_towards(aim)
	e.set_state(SimEntity.State.CASTING, s.startup + s.active + s.recovery)
	Events.post(&"skill_cast", e.id, s.id, "startup")
	if s.effects.has("avalanche") and maps.has(e.map_id):
		BossSignatures.avalanche_prep(self, e, s)     # Troll Rei: sem pedra no chão, arremessa as da garantia antes

func _end_skill(e: SimEntity) -> void:
	e.current_skill = null
	e.skill_phase = ""
	e.current_skill_slot = -1
	e.set_state(SimEntity.State.IDLE)

func _update_skill(e: SimEntity, m: Dictionary, dt: float) -> void:
	if e.shade:
		ShadowSystem.update_skill(self, e)       # clone de sombra: só o gesto; o dano é o da fila (golpes do dono)
		return
	var s := e.current_skill
	if s == null:
		e.set_state(SimEntity.State.IDLE)
		return
	var t := e.state_time
	if not e.skill_applied and t >= s.startup:
		e.skill_applied = true
		e.skill_phase = "active"
		e.channel_done = 1
		Events.post(&"skill_cast", e.id, s.id, "active")
		if s.ultimate:
			UltimateSystem.on_fire(self, e, s)       # a carga é gasta aqui (cancelada no preparo, fica)
		_apply_skill(e, s, m)
	elif e.skill_applied and e.skill_phase == "active" and not e.sky.is_empty():
		RangerAscension.fly(e, s)             # no ar: vai até o ponto de pouso
		if t >= s.startup + s.active:
			e.skill_phase = "recovery"
			RangerAscension.land(self, e, s, m)
	elif e.skill_applied and e.skill_phase == "active" and s.effects.has("channel"):
		# canalização (estilo sacerdote das sombras): um pulso a cada active/ticks, mirando onde o cursor está
		var n := int(s.effects["channel"].get("ticks", 3))
		while e.channel_done < n and t >= s.startup + s.active * float(e.channel_done) / float(n):
			e.channel_done += 1
			_apply_skill(e, s, m)
			if e.channel_done >= n and s.effects.get("channel_end") is Dictionary and e.is_alive() and e.current_skill == s:
				UltEffects.channel_end(self, e, s, m)     # Lança Incansável: fim do canal = arremessa a lança
	elif e.skill_applied and e.skill_phase == "active" and s.effects.get("strikes") is Dictionary:
		# sequência de golpes (Golpe do Cruzado): golpe i no startup + at[i]; o último pode ser crítico garantido
		var at_s: Array = s.effects["strikes"].get("at", [])
		while e.channel_done < at_s.size() and t >= s.startup + float(at_s[e.channel_done]):
			e.channel_done += 1
			_apply_skill(e, s, m)
		if t >= s.startup + s.active:
			e.skill_phase = "recovery"
			Events.post(&"skill_cast", e.id, s.id, "recovery")
	elif e.skill_applied and e.skill_phase == "active" and t >= s.startup + s.active:
		e.skill_phase = "recovery"
		if s.effects.has("dragon_jump"):
			RangerAscension.land(self, e, s, m)
		Events.post(&"skill_cast", e.id, s.id, "recovery")
	if t >= e.state_duration:
		_end_skill(e)

func _apply_skill(e: SimEntity, s: SkillDef, m: Dictionary) -> void:
	var ut := s.ultimate or is_ult_id(s.id)
	if ut:
		ult_tag += 1                       # tudo o que a Suprema faz aqui conta como dela (medição; dots marcados "ult")
	_apply_skill_body(e, s, m)
	if ut:
		ult_tag -= 1

func _apply_skill_body(e: SimEntity, s: SkillDef, m: Dictionary) -> void:
	var lv := e.mastery_of(s.id) if s.id in e.mastery else 0
	var power := s.power_at(lv) * e.stats.skill_power_mult(s.id) * e.stats.element_mult(s.elements) * ShieldSystem.shield_power(self, e, s) * power_scale
	power *= TitanSystem.power_mult(e, s)          # Empunhadura/Garras de Titã: golpe duplo
	if s.effects.has("elem_fusion"):
		power *= ElementalSystem.fusion_power_mult(e, s)     # Fusão bate com o elemento da forma do elemental
	if e.ambush:
		power *= ShiftSystem.ambush_mult(e)          # forma furtiva de monstro: Balance.SHIFT_AMBUSH_MULT
		e.ambush = false
	if e.is_character() and not e.stats.fusion.is_empty():
		power *= FusionEffects.skill_mult(self, e, s)          # Fusão do híbrido: Juramento (2 mãos), Peso, golpe furtivo
	var extra: Dictionary = s.mastery_entry(lv).get("extra", {})
	var effects := s.effects.duplicate(true)
	for k in extra:
		effects[k] = extra[k]
	for k in s.talent_effects:     # evoluções vencem a maestria
		if k != "add":
			effects[k] = s.talent_effects[k]
	if s.talent_effects.get("add") is Dictionary:     # talento de classe que soma (Golpe Restaurador, Golpe Ardente...)
		ClassTalentSystem.merge_add(effects, s.talent_effects["add"])
	if effects.get("dot") is Dictionary:     # dano no tempo leva o id da skill (teto de cópias por skill: _put_dot)
		effects["dot"] = (effects["dot"] as Dictionary).merged({"skill": s.id})
	if effects.get("dice") is Array and not (effects["dice"] as Array).is_empty():     # Dados da Sorte: sorteia UM dos buffs (rng da sim)
		var faces: Array = effects["dice"]
		effects["buff"] = (faces[rng.randi() % faces.size()] as Dictionary).duplicate()
	if lv > 0:                     # maestria fortalece os bônus de buff e de forma
		var bm := 1.0 + Balance.MASTERY_BONUS_PCT * lv
		if effects.get("buff") is Dictionary:
			effects["buff"] = SimEntity.scaled_bonus(effects["buff"], bm)
		if effects.has("form"):
			effects["form_mult"] = bm
	var strike_i := -1                 # golpe da sequência ("strikes"): channel_done já contou este (1 = o primeiro)
	if effects.get("strikes") is Dictionary:
		strike_i = clampi(e.channel_done - 1, 0, Combat.strike_count(effects["strikes"]) - 1)
		power *= Combat.strike_share(effects["strikes"], strike_i)
	var sure_crit := strike_i >= 0 and Combat.strike_crit(effects["strikes"], strike_i)
	if strike_i > 0:
		effects.erase("dash")                  # salto da sequência: só no 1º golpe (Juízo da Alvorada)
	if strike_i >= 0 and strike_i == Combat.strike_count(effects["strikes"]) - 1 and effects["strikes"].get("last_effects") is Dictionary:
		effects.merge(effects["strikes"]["last_effects"], true)     # o golpe final atordoa (Juízo da Alvorada)
	if effects.has("leap_iframe") and effects.has("dash"):
		e.iframe_left = maxf(e.iframe_left, float(effects["leap_iframe"]))     # intocável no salto
	e.combat_timer = Balance.AGGRO_LOSE_TIME
	var aim := Combat.clamp_aim(e, e.skill_aim, s.range)
	if e.is_character() and not e.stats.fusion.is_empty():
		FusionEffects.on_cast(self, e, s, aim)
	if e.is_character() and not e.stats.piece_fx.is_empty():
		PieceEffects.on_cast(self, e, s, aim)          # Lendários do 50: gatilho de lançar e chão
	var any_hit := false
	var wounded := 0                      # Sangria: atingidos que já sangravam (WoundSystem)
	if s.mob_pick != "" and s.target == SkillDef.Target.TARGET and e.kind == SimEntity.Kind.MONSTER:
		aim = MobSystem.follow_victim(self, e, s, aim)      # gancho de chefe: acompanha a vítima que andou (o alcance ainda vale)
	if effects.has("aura") and AuraSystem.aura_on(e, s):      # aura ligada: lançar de novo desliga
		AuraSystem.switch_off(self, e, s)
		if AuraSystem.aura_id(s) == Balance.GLADIATOR_BUFF:
			GladiatorSystem.on_stance_off(e)             # sair da postura: a Glória zera (Punhos guarda um pouco)
		return
	if effects.get("aura") is Dictionary and effects.get("buff") is Dictionary:
		effects["buff"]["aura"] = effects["aura"]              # o buff de quem liga carrega a aura (AuraSystem.tick)
	if effects.has("arcane"):                                  # Modo Arcano: liga (rajada + asas) / desliga
		MountedCombat.arcane_cast(self, e, s, effects, m)
		return

	# movimento (dash de skill)
	var origin := e.position                # investida atravessa o alvo: a guarda olha de onde ela partiu
	var charge := s.is_charge()
	var reach := -1.0
	if effects.has("dash"):
		var d := e.forward() * float(effects["dash"])
		if effects.get("dash_to_aim", false):     # gancho: puxa até o ponto mirado (no máximo `dash` m), parando na frente de quem estiver lá
			var to_aim := aim - e.position
			to_aim.y = 0.0
			d = e.forward() * clampf(to_aim.length() - 0.6, 0.0, float(effects["dash"]))
		elif s.target == SkillDef.Target.GROUND and float(effects["dash"]) > 0.0:     # salto: pousa no cursor (onde o dano cai), no máximo `dash` m
			var to_aim := aim - e.position
			to_aim.y = 0.0
			d = e.forward() * clampf(to_aim.length(), minf(Balance.LEAP_MIN_HOP, float(effects["dash"])), float(effects["dash"]))
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
		if mdef and ElementalSystem.takes_over(e, sm):
			ElementalSystem.on_summon_skill(self, e, ElementalSystem.form_of_monster(mdef.id))     # ascensão: o persistente
		elif mdef:
			# grupo exclusivo (elementais): o novo dispensa os que já estão vivos
			var group: Array = sm.get("replaces", [])
			if not group.is_empty():
				for o: SimEntity in m["entities"].duplicate():
					if o.kind == SimEntity.Kind.SUMMON and o.owner_id == e.id and o.is_alive() and o.monster_def and o.monster_def.id in group:
						despawn(o)
			# limita invocações vivas por dono
			var alive := 0             # limite por tipo de invocação (esqueletos, cão, lich, rei... cada um conta o seu)
			var free := bool(sm.get("ignore_max", false))     # Suprema: fora do limite (não conta nem é contada)
			for o: SimEntity in (m["entities"].duplicate() if not free else []):
				if o.kind == SimEntity.Kind.SUMMON and o.owner_id == e.id and o.is_alive() and o.monster_def == mdef and not o.grave and not o.free_summon:
					if o.position.distance_to(e.position) > Balance.SUMMON_LEASH:
						despawn(o)          # perdida longe do dono (presa atrás de muro/rio): a nova toma o lugar
					else:
						alive += 1
			var n := int(sm.get("count", 1))
			var cap := int(sm.get("max", 3)) + ClassTalentSystem.summon_extra(e, s.id) + NecroAscension.summon_extra(e)     # Senhor dos Mortos: +1 por tipo
			var dur := 0.0 if ClassTalentSystem.summon_permanent(e, s.id) else float(sm.get("duration", 20)) * NecroAscension.summon_time_mult(e) * ClassTalentSystem.summon_time(e)     # talento: fica para sempre / Mortos sem Pressa; Senhor dos Mortos: dura mais
			if sm.get("buff_first", false) and effects.get("buff") is Dictionary:     # Maré dos Mortos: o +MATK já vale para as que nascem agora
				_apply_effects(e, e, {"buff": effects["buff"]}, power)
				effects.erase("buff")
			for i in range(n):
				if alive >= cap and not free:
					break
				var off := Vector3(rng.randf_range(-1.2, 1.2), 0, rng.randf_range(-1.2, 1.2))
				var made := spawn_summon(e, mdef, e.position + e.forward() * 1.2 + off, dur, bool(sm.get("owner_stats", false)))
				made.free_summon = free
				if sm.get("expire_blast") is Dictionary:
					made.expire_blast = (sm["expire_blast"] as Dictionary).merged({"power": float(sm["expire_blast"].get("power", 1.0)) * power / maxf(0.01, s.power), "skill": s.id}, true)
				NecroAscension.on_summoned(e, made)
				alive += 1

		if sm.get("summon_buff") is Dictionary:      # Maré dos Mortos: as SUAS invocações ganham o buff (velocidade de ataque)
			UltEffects.buff_summons(self, e, sm["summon_buff"])
	if effects.get("pack") is Dictionary:       # Lobo Alfa: chama a matilha
		DruidAscension.call_pack(self, e, s, effects["pack"])
	if effects.has("elem_command"):  # Comando Elemental: chama o elemental ou troca o modo
		ElementalSystem.on_command_skill(self, e)
		return
	if effects.has("elem_fusion"):   # Fusão Elemental: o golpe leva o efeito da forma do elemental
		ElementalSystem.fusion(self, e, effects)

	if effects.has("shadow_clone"): # Sombra Gêmea (Assassino ascendido): clone que repete os golpes
		ShadowSystem.cast(self, e, s)
		return
	if effects.has("choir_angel"):  # Coro Celeste (Bispo ascendido): anjo, cúpula e Retorno
		ChoirSystem.summon_angel(self, e, s)
		return
	if effects.has("choir_barrier"):
		ChoirSystem.place_barrier(self, e, s, aim, m)
		return
	if effects.has("choir_return"):
		ChoirSystem.finish_return(self, e, s)
		return
	if effects.has("falcon_call"):  # Chamado do Falcão (Caçador ascendido): o falcão passa a voar sobre o dono
		FalconSystem.call_falcon(e, s)
		return
	if effects.has("falcon_eyes"):  # Olhos do Céu: o buff do grupo sai abaixo; a Revoada (refino 45) mergulha aqui
		FalconSystem.eyes(self, e, m)
	if effects.has("turret"):       # torreta (Atirador ascendido): fica parada no ponto mirado e atira sozinha
		RangerAscension.place_turret(self, e, s, aim, effects)
		return
	if effects.has("dragon_jump"):  # Salto Dracônico: decola agora, o dano é no pouso (fim da fase ativa)
		RangerAscension.take_off(self, e, s, aim, power, m)
		return
	if effects.get("shout") is Dictionary:      # Brado Elemental: um por vez, grupo/inimigos perto e provoca
		RangerAscension.shout(self, e, effects, m)
	if effects.has("summon_pact"):  # Pacto dos Mortos (Necromante ascendido): buff nas invocações por perto
		NecroAscension.pact(self, e, effects, m)
	if effects.has("miasma"):       # Miasma: nuvem que fica no chão e enfraquece quem está dentro
		NecroAscension.place_miasma(self, e, s, aim, effects, m)
		return
	if effects.has("grave_mark"):   # Marca da Cova: quem morrer marcado levanta como aliado
		NecroAscension.grave_mark(self, e, s, aim, effects, m)
		return
	if effects.get("sacrifice") is Dictionary:     # Oferenda Sombria: suas invocações perto do ponto explodem (SummonRites)
		var sac_hits := SummonRites.offer(self, e, s, aim, power, effects["sacrifice"])
		if sac_hits > 0 and s.hit_stop_frames > 0 and e == player:
			Events.post(&"hit_stop", Combat.hit_stop_frames(s, s.hit_stop_frames, false, false), e.id, [])
		return
	if effects.has("fire_wall"):    # Muralha de Fogo: faixa que fica no chão e queima quem passa (TrapSystem)
		TrapSystem.place_wall(self, e, s, aim, power, effects)
		return
	if effects.has("trap"):         # armadilha: fica no chão; o efeito sai quando alguém pisa
		TrapSystem.place_trap(self, e, s, aim, power, effects)
		Events.post(&"skill_effect", s.id, e.position, aim, 0.0)
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
	if effects.has("rally"):              # grito de guerra: buff no bando da mesma facção
		MobSystem.rally(self, e, effects["rally"])
	if effects.has("barrage"):            # chefe: círculos avisados no chão que caem depois (MobSystem.update_hazards)
		if e.is_character():
			StormSystem.place_barrage(self, e, s, aim, power, effects)     # do jogador/bot: lista própria (bots não fogem)
		else:
			MobSystem.place_barrage(self, e, s, aim, power, effects)
		return
	# Supremas (GDD ultimates-lv40 §9)
	if effects.has("force_form"):                  # Colosso Primevo: em forma humana vira urso na hora
		UltEffects.force_form(self, e, str(effects["force_form"]))
	if effects.get("oath_fill", false):            # Bastião da Aurora: Juramento cheio
		UltEffects.oath_lock(e)
	if effects.get("sunder_fill") is Dictionary:   # Veredito do Carrasco: rachadura cheia no alvo e em volta antes do golpe
		UltEffects.sunder_fill(self, e, aim, effects["sunder_fill"], m)
	if effects.get("grace_dome") is Dictionary:    # Cúpula da Graça: cúpula parada (a cura da skill segue abaixo)
		ChoirSystem.place_dome(self, e, s, aim, m, effects["grace_dome"])
	if effects.get("ally_heal") is Dictionary:     # Avatar da Fé: cura o grupo em volta
		UltEffects.ally_heal(self, e, effects["ally_heal"], m)
	if effects.get("intercept") is Dictionary:      # Proteção: parte do dano dos aliados perto vem para quem lançou
		InterceptSystem.start(self, e, effects["intercept"])
	if effects.get("pet_revive") is Dictionary:     # companheiro morto volta (vivo: vida cheia)
		UltEffects.pet_revive(self, e, effects["pet_revive"])
	if effects.get("storm") is Dictionary:          # tempestade: golpes no tempo em volta do lançador ou do ponto (StormSystem)
		StormSystem.start(self, e, s, aim, power, effects["storm"])
		if effects.get("buff") is Dictionary:         # Olho da Tempestade: +velocidade em quem lança
			_apply_effects(e, e, {"buff": effects["buff"]}, power)
		UltEffects.cd_reset(e, effects)                # ... e o Passo Relampejante volta
		gain_bravado(e, int(effects.get("combo_gain", 0)))     # Chamado da Frota: Bravata cheia
		Events.post(&"skill_effect", s.id, e.position, aim, 0.0)
		return
	if effects.get("hop_strikes") is Dictionary:    # salta entre inimigos batendo (HopSystem)
		HopSystem.start(self, e, s, power, effects["hop_strikes"])
		if not effects.has("buff"):
			return
	# assinaturas de chefe (BossSignatures; GDD act2-boss-signatures)
	if effects.has("islands"):
		BossSignatures.place_islands(self, e, s, power, effects)
		return
	if effects.has("mark"):
		BossSignatures.place_marks(self, e, s, power, effects)
		return
	if effects.has("boss_channel"):
		BossSignatures.channel_start(self, e, s, effects)
		return
	if effects.has("avalanche"):
		BossSignatures.avalanche(self, e, s, power, effects)
		return
	if effects.has("wall"):
		BossSignatures.wall_start(self, e, s, effects)
		return
	if effects.has("decoys") and e.kind == SimEntity.Kind.MONSTER:
		BossSignatures.decoys_start(self, e, s, effects)     # Sombras Gêmeas: a fumaça (stealth) segue normal; cópias no fim dela
	if effects.has("repeat") and e.kind == SimEntity.Kind.MONSTER:
		BossSignatures.on_repeat_apply(self, e, s, effects)     # Três Botes: abre/fecha a sequência; o golpe segue normal
	if effects.get("taunt") != null:
		var taunted := 0
		for o: SimEntity in m["entities"]:
			if o.kind == SimEntity.Kind.MONSTER and o.is_alive() and o.position.distance_to(e.position) <= s.radius + o.radius:
				MobSystem.taunt(self, o, e, float(effects["taunt"].get("duration", Balance.TAUNT_DURATION)))
				taunted += 1
		if effects.get("glory_gain", false):          # Brado da Arena: a plateia (+1 Glória por provocado)
			GladiatorSystem.gain_glory(self, e, mini(taunted, Balance.GLORY_SHOUT_MAX))

	# Bravata (Corsário): o finalizador gasta todas as cargas (mais dano e mais atordoamento por carga)
	if effects.get("combo_spend") is Dictionary:
		var spent := e.buff_stacks(Balance.BRAVADO_BUFF)
		var cs: Dictionary = effects["combo_spend"]
		power *= 1.0 + float(cs.get("power_pct", 0.0)) / 100.0 * spent
		if float(cs.get("stun_per", 0.0)) > 0.0:
			effects["stun"] = {"duration": float((effects.get("stun", {}) as Dictionary).get("duration", 0.0)) + float(cs["stun_per"]) * spent}
		e.drop_buff(Balance.BRAVADO_BUFF)
		e.combo_spent = spent

	# Punho Final (Punhos de Fúria): gasta toda a Fúria do Punho, mais dano por carga
	if effects.get("fury_spend") is Dictionary:
		power *= FistSystem.spend_fury(e, float((effects["fury_spend"] as Dictionary).get("power_pct", 0.0)))
	# Golpe de Mestre (Duelista): gasta o Ímpeto das aparadas
	if effects.get("momentum_spend") is Dictionary:
		power *= RiposteSystem.spend(e, float((effects["momentum_spend"] as Dictionary).get("power_pct", 0.0)))
	# Modo Gladiador: Lâminas Elementais crescem com a Glória; o Golpe Final gasta toda
	if effects.get("glory_scale", false):
		power *= GladiatorSystem.blade_mult(e, s.power)
	if effects.get("glory_spend", false):
		GladiatorSystem.spend(e)

	# escudo arremessado: persegue o alvo, ricocheteia e volta
	if effects.get("bounce") is Dictionary:
		var first: Array = Combat.select_targets(e, s, aim, m["entities"])
		_throw_bouncer(e, s, power, m, effects, first[0] if not first.is_empty() else null, aim)
		if effects.get("shot", false):          # bala: clarão na boca do cano já no disparo
			Events.post(&"skill_effect", s.id, e.position, first[0].position if not first.is_empty() else aim, 0.0)
		if not first.is_empty():
			gain_bravado(e, int(effects.get("combo_gain", 0)))
		return

	# projétil (DIRECTION com velocidade)
	if s.projectile_speed > 0.0 and s.target == SkillDef.Target.DIRECTION:
		_spawn_projectile(e, s, power, m, false, effects)
		Events.post(&"skill_effect", s.id, e.position, aim, s.radius)
		if effects.get("sure_crit", false) and s.projectile_pierce:     # Disparo do Fim: o rastro do tiro vai até o fim do alcance
			Events.post(&"skill_effect", s.id, e.position, e.position + e.forward() * s.range, -3.0)
		gain_bravado(e, int(effects.get("combo_gain", 0)))
		return

	if s.target == SkillDef.Target.SELF and s.radius <= 0.0 and s.kind != SkillDef.Kind.HEAL and s.kind != SkillDef.Kind.BUFF and not effects.has("shield"):
		Events.post(&"skill_effect", s.id, e.position, e.position, s.radius)
		return

	if effects.get("seed") is Dictionary:      # Semente Ígnea: a explosão leva o que multiplicou o lançamento (SeedSystem)
		effects["seed"] = (effects["seed"] as Dictionary).merged({"mult": power / maxf(0.01, s.power), "skill": s.id})
	var targets := Combat.select_targets(e, s, aim, m["entities"], origin if charge else null, reach)
	if effects.has("taunt"):
		targets = [e]        # o raio é de quem é provocado; o buff é só de quem provoca
	if charge:
		Events.post(&"skill_effect", s.id, origin, origin + e.forward() * reach, s.radius)
	elif s.target == SkillDef.Target.TARGET and not targets.is_empty():
		Events.post(&"skill_effect", s.id, e.position, targets[0].position, s.radius)     # efeito no alvo de verdade, não no cursor
		if s.projectile_pierce and targets.size() > 1:         # tiro que atravessou: rastro até o último da fila (FxManager.PIERCE_TRACE)
			Events.post(&"skill_effect", s.id, e.position, targets[targets.size() - 1].position, -3.0)
	elif effects.get("dash_to_aim", false):
		Events.post(&"skill_effect", s.id, origin, aim, s.radius)       # gancho: a corda sai de onde ele estava
	else:
		Events.post(&"skill_effect", s.id, e.position, aim, s.radius)
	var on_foes := effects.duplicate()    # buff e escudo são de quem lança, nunca do inimigo atingido
	on_foes.erase("buff")
	on_foes.erase("shield")
	if on_foes.get("knockback") is Dictionary:      # empurrão: para longe do centro do golpe
		on_foes["knockback"] = (on_foes["knockback"] as Dictionary).merged({"from": aim if s.target == SkillDef.Target.GROUND else e.position})
	for t in targets:
		match s.kind:
			SkillDef.Kind.HEAL:
				var amount := Combat.calc_heal(e, power, rng)
				_heal(e, t, amount)
			SkillDef.Kind.BUFF:
				pass
			_:
				var from: Vector3 = aim if s.target == SkillDef.Target.GROUND else origin     # área no chão vem do ponto de impacto
				var burn_left := 0.0
				var hit_power := power * ShadowSystem.execution_mult(self, e, t) if effects.has("execute") else power     # Execução: cheia só abaixo do limiar
				if effects.get("combust") is Dictionary and e.is_hostile_to(t):
					var cb: Dictionary = effects["combust"]
					if str(cb.get("kind", "fire")) == "poison":         # Eviscerar: os venenos saem e o golpe cresce por veneno
						var pz: Array = WoundSystem.consume(e, t)
						PieceEffects.on_poison_consume(e, int(pz[1]))     # Veneno Letal Desperto
						burn_left = pz[0]
						hit_power *= 1.0 + float(cb.get("per", 0.0)) * mini(int(pz[1]), int(cb.get("max", 5)))
					else:
						burn_left = consume_burns(e, t)
				if effects.has("wound_heal") and e.is_hostile_to(t) and WoundSystem.count(e, t) > 0:
					wounded += 1                                        # Sangria: conta quem sangrava antes do giro
				if effects.get("sunder_consume") is Dictionary and e.is_hostile_to(t):
					hit_power *= SunderSystem.consume(t, effects["sunder_consume"])     # finalizador do Executor: gasta a rachadura
				if effects.get("ult_execute") is Dictionary and e.is_hostile_to(t):
					hit_power *= UltEffects.execute_mult(t, effects["ult_execute"])      # Veredito: alvo abaixo do limiar
				var r := _strike(e, t, s, hit_power, s.kind if s.kind != SkillDef.Kind.SUMMON else SkillDef.Kind.MAGICAL, from, sure_crit)
				any_hit = true
				TitanSystem.on_hit(self, e, t, s)
				if burn_left >= 1.0 and t.is_alive():      # Combustão: a queimadura que faltava explode de uma vez
					_deal_damage(e, t, int(burn_left * float(effects["combust"].get("detonate", 1.0))), false, false, "detonate", from)
				if effects.get("wound_extend") is Dictionary and t.is_alive():
					WoundSystem.extend(e, t, effects["wound_extend"])     # Presas Gêmeas: as feridas ficam abertas
				if effects.has("heal_pct_of_dmg"):
					_heal(e, e, int(r["amount"] * float(effects["heal_pct_of_dmg"])))
				if effects.has("mend_pct_of_dmg") and r["amount"] > 0:      # Clérigo de Batalha: o golpe cura o aliado mais ferido por perto
					mend(e, int(r["amount"]), float(effects["mend_pct_of_dmg"]))
				_storm_proc(e, s, t)
		_apply_effects(e, t, effects if e.is_friend(t) else on_foes, power)
	if wounded > 0:
		WoundSystem.whirl_heal(self, e, wounded, effects["wound_heal"])     # Sangria: cura por alvo que sangrava
	if effects.get("hit_heal") is Dictionary and any_hit:
		UltEffects.hit_heal(self, e, targets, effects["hit_heal"])         # Ceifa das Almas: % da vida por inimigo atingido
	if effects.get("zone") is Dictionary:   # Chão Sagrado / Estandarte: o chão fica e pulsa (TrapSystem.place_zone)
		TrapSystem.place_zone(self, e, s, aim, power, effects)
	if effects.get("orbit") is Dictionary:  # Martelos Abençoados: martelos girando que batem de novo com o mesmo poder (AuraSystem.orbit_tick)
		AuraSystem.start_orbit(e, s, effects["orbit"], power)
	if effects.has("falcon_dive"):         # Mergulho: Presa no alvo e os linces saltam nele
		FalconSystem.stoop(self, e, targets, m)
	var friendly_target := s.target == SkillDef.Target.TARGET and s.kind in [SkillDef.Kind.HEAL, SkillDef.Kind.BUFF]
	if (effects.has("buff") or effects.has("shield")) and not friendly_target:     # Luz Protetora: o escudo é do aliado, não de quem lança
		var self_in := targets.has(e)          # já recebeu tudo no laço: cura/mana % não saem duas vezes
		_apply_effects(e, e, {"buff": effects.get("buff", null), "shield": effects.get("shield", null),
			"heal_pct": null if self_in else effects.get("heal_pct", null), "mana_pct": null if self_in else effects.get("mana_pct", null)}, power)
	if any_hit or s.kind == SkillDef.Kind.BUFF:
		gain_bravado(e, int(effects.get("combo_gain", 0)))
	if any_hit:
		FistSystem.gain_fury(self, e, int(effects.get("fury_gain", 0)))
	if any_hit and effects.get("chain") is Dictionary:
		_chain(e, s, targets, power, effects["chain"], on_foes, m)
	if effects.get("area_heal") is Dictionary:      # Chuva de Penas de Luz: cura os aliados embaixo
		DruidAscension.area_heal(self, e, s, aim, effects["area_heal"], m)
	var stop := s.hit_stop_frames
	if sure_crit:
		stop = int(effects["strikes"].get("last_stop", stop))     # o golpe final da sequência para mais
	if any_hit and stop > 0 and (e == player or targets.has(player)):
		Events.post(&"hit_stop", Combat.hit_stop_frames(s, stop, sure_crit, e.current_skill_slot < 0 and e.current_skill == s), e.id, _stop_ids(e, targets))

## Quem para junto no hit-stop local: os alvos do jogador, ou só o jogador quando é ele quem apanha.
func _stop_ids(e: SimEntity, targets: Array) -> Array:
	if e != player:
		return [player.id]
	var ids: Array = []
	for t in targets:
		ids.append((t as SimEntity).id)
	return ids

## Raio que salta ("chain"): do primeiro atingido para até `count` inimigos a `radius` m que a skill não pegou,
## com power × falloff (Lâmina Trovejante). Os saltos levam os efeitos da skill no inimigo, sem saltar de novo.
func _chain(e: SimEntity, s: SkillDef, hit: Array, power: float, ch: Dictionary, on_foes: Dictionary, m: Dictionary) -> void:
	var first: SimEntity = null
	for t in hit:
		if e.is_hostile_to(t):
			first = t
			break
	if first == null:
		return
	var R := float(ch.get("radius", 4.0))
	var near: Array = []
	for o: SimEntity in m["entities"]:
		if o.is_alive() and e.is_hostile_to(o) and not hit.has(o) and o.position.distance_to(first.position) <= R + o.radius:
			near.append(o)
	near.sort_custom(func(a, b): return a.position.distance_squared_to(first.position) < b.position.distance_squared_to(first.position))
	var fx := on_foes.duplicate()
	fx.erase("chain")
	for i in range(mini(int(ch.get("count", 2)), near.size())):
		var o: SimEntity = near[i]
		Events.post(&"skill_effect", s.id, first.position, o.position, 0.5)
		_strike(e, o, s, power * float(ch.get("falloff", 0.6)), s.kind, first.position)
		_apply_effects(e, o, fx, power)

## Bravata (Corsário): +n cargas em `e` (até Balance.BRAVADO_MAX; o tempo renova a cada ganho). O HUD mostra as cargas.
func gain_bravado(e: SimEntity, n: int) -> void:
	if n <= 0 or e == null or not e.is_alive():
		return
	var cur := e.buff_stacks(Balance.BRAVADO_BUFF)
	var now := mini(Balance.BRAVADO_MAX + int(PieceEffects.cap(e, "bravado")), cur + n)
	e.put_buff({"id": Balance.BRAVADO_BUFF, "remaining": Balance.BRAVADO_TIME, "stacks": now})
	if now != cur:
		Events.post(&"buff_applied", e.id, Balance.BRAVADO_BUFF, Balance.BRAVADO_TIME)

## Raio: chance de atordoar no golpe direto (Balance.STORM_STUN_*).
## Golpe direto (skill ou projétil) em um alvo: gelo estilhaça alvo retardado/preso, a arma lendária multiplica e reage.
## Devolve o resultado de Combat.calc_damage.
## Id de Suprema ou de skill de apoio dela ("<prefixo>_ult_<nome>[_end]"): o dano conta em SimEntity.ult_dealt (medição).
static func is_ult_id(id: String) -> bool:
	return id.contains("_ult_")

func _strike(e: SimEntity, t: SimEntity, s: SkillDef, power: float, kind: SkillDef.Kind, from: Vector3, force_crit := false) -> Dictionary:
	if t.iframe_left > 0.0 and e != t and e.is_hostile_to(t):        # dash: o golpe passa por ele
		Events.post(&"dodged", t.id)
		return {"amount": 0, "crit": false, "blocked": false}
	var frost := Combat.frost_mult(s, t)
	force_crit = force_crit or PieceEffects.force_crit(e, t, s)          # Carrasco Desperto
	var r := Combat.calc_damage(e, t, power * (frost * LegendEffects.legend_power(self, e, t) * TitanSystem.second_axe_mult(e, t, s) * FusionEffects.hit_mult(self, e, t, s) * PieceEffects.hit_mult(self, e, t, frost)), kind, rng, from, force_crit)
	var dk := "magical" if s.kind == SkillDef.Kind.MAGICAL else "physical"
	var ut := s.ultimate or is_ult_id(s.id)
	if ut:
		ult_tag += 1
	var landed := _deal_damage(e, t, r["amount"], r["crit"], r["blocked"], "shatter" if frost > 1.0 and dk == "magical" else dk, from)
	if ut:
		ult_tag -= 1
	if landed and e.kind != SimEntity.Kind.MONSTER:
		UltimateSystem.on_dealt(self, e, t, s, power)     # Carga Suprema: poder do golpe, sem ATK/DEF/crítico
		if not e.buffs.is_empty() and not ut and (s == e.basic_skill or s == e.current_skill):
			RiposteSystem.duel_hit(e)                      # Duelo Supremo: o golpe da própria ação enche o Duelo (proc/lançamento de graça não)
	LegendEffects.legend_on_hit(self, e, t, s, int(r["amount"]))
	FusionEffects.on_hit(self, e, t, s, int(r["amount"]), bool(r["crit"]))
	PieceEffects.on_hit(self, e, t, s, int(r["amount"]))          # Lendários do 50: gatilho hit:<skill>
	LegendEffects.signature_on_hit(self, e, t, s, int(r["amount"]))
	RangerAscension.on_strike(self, e, t, int(r["amount"]))      # Brado Elemental: a lança leva o elemento
	if not e.asc_tree.is_empty():
		NecroAscension.on_strike(self, e, t)                     # Foice que Comanda: as invocações vão no mesmo alvo
	ShadowSystem.on_strike(self, e, t, s, int(r["amount"]), bool(r["crit"]))     # Sombra Gêmea: o clone repete o golpe
	if e.falcon:
		FalconSystem.on_strike(e, t)                              # o falcão segue o alvo do caçador
	return r

func _storm_proc(src: SimEntity, s: SkillDef, t: SimEntity) -> void:
	if t.is_alive() and src.is_hostile_to(t) and Combat.storm_can_stun(s) and rng.randf() * 100.0 < Balance.STORM_STUN_CHANCE:
		_apply_effects(src, t, {"stun": {"duration": Balance.STORM_STUN_TIME}}, 0.0)

func _apply_effects(src: SimEntity, t: SimEntity, effects: Dictionary, power: float) -> void:
	if not t.is_alive():
		return
	if t.iframe_left > 0.0 and src != t and src.is_hostile_to(t):          # dash: nem atordoar, prender ou puxar
		return
	effects = MountedCombat.filter_cc(self, src, t, effects)              # controle derruba do cavalo (ascensão) / imune
	if effects.get("dot") != null:
		var d: Dictionary = effects["dot"]
		if d.has("atk_pct"):          # sangramento (Lanceiro): % do ATK por segundo; o mesmo atacante renova, não acumula
			var bid := "bleed_%d" % src.id
			var bd := {"kind": "dot", "id": bid, "remaining": float(d.get("duration", Balance.BLEED_TIME_DEFAULT)), "dps": maxf(1.0, src.stats.patk * float(d["atk_pct"]) / 100.0) * src.stats.dot_mult(), "src": src.id, "bleed": true}
			if ult_tag > 0 or d.get("ult", false):
				bd["ult"] = true                    # sangramento de Suprema (Lança Incansável): não enche a carga
			t.put_debuff(bd)
		elif not (bool(d.get("fire", false)) and t.monster_def != null and t.monster_def.burn_immune):   # Salamandra de Lava: não queima
			var db := ClassTalentSystem.dot_boost(src)          # Podridão Lenta (necromante nv 5): dura e bate mais
			var mob := _monster_side(src)
			var nd := {"kind": "dot", "id": dot_id(src, d, mob), "remaining": float(d.get("duration", 4)) * float(db[0]) * PieceEffects.dot_mult(src, d) * (Balance.MONSTER_DOT_TIME_MULT if mob else 1.0),
				"dps": float(d.get("dps", 5)) * (src.stats.matk / 20.0) * float(db[1]) * src.stats.dot_mult(), "src": src.id, "fire": bool(d.get("fire", false))}
			if d.get("ult", false) or ult_tag > 0 or is_ult_id(str(d.get("skill", ""))):
				nd["ult"] = true                    # dano no tempo de Suprema: não enche a Carga Suprema
			if not mob:
				_put_dot(t, nd)                 # jogador: até Balance.PLAYER_DOT_MAX_STACKS cópias por skill
			elif not _renew_dot(t, nd):         # monstro: renova
				t.debuffs.append(nd)
	if effects.get("slow") != null:
		var d: Dictionary = effects["slow"]
		var sdr := 1.0 if CcDrSystem.slow_exempt(src, d) else CcDrSystem.apply(self, t, "slow")       # monstro: retorno decrescente (C7; gelo e canal fora)
		if sdr > 0.0:
			t.debuffs.append({"kind": "slow", "remaining": float(d.get("duration", 2)) * t.stats.cc_mult() * sdr, "pct": float(d.get("pct", 30)), "frost": bool(d.get("frost", false))})
	if effects.get("pull") != null and t != src and src.is_hostile_to(t) and not (t.monster_def and t.monster_def.resists_cc()) and not t.is_perched() and maps.has(t.map_id):
		var gap := float((effects["pull"] as Dictionary).get("gap", Balance.BOSS_PULL_GAP))
		var to := src.position - t.position
		to.y = 0.0
		var want := to.length() - (src.radius + t.radius + gap)
		if want > 0.1:                         # gancho: arrasta reto até o lado de quem puxou, parando no primeiro obstáculo
			_charge(t, to.normalized() * want, maps[t.map_id])
	if effects.get("knockback") is Dictionary and t != src:
		DruidAscension.knockback(self, src, t, effects["knockback"])
	if effects.get("provoke") is Dictionary and t.kind == SimEntity.Kind.MONSTER and src.is_hostile_to(t) and DruidAscension.may_provoke(self, src):
		MobSystem.taunt(self, t, src, float(effects["provoke"].get("duration", Balance.TAUNT_DURATION)))
	if effects.get("root") != null:
		var rdr := CcDrSystem.apply(self, t, "root")
		if rdr > 0.0:
			t.debuffs.append({"kind": "root", "remaining": float(effects["root"].get("duration", 2)) * t.stats.cc_mult() * rdr})
	var stun_dr := CcDrSystem.apply(self, t, "stun") if effects.get("stun") != null and (t.kind != SimEntity.Kind.NPC or t.guard) else 0.0
	if stun_dr > 0.0:
		var dur := float(effects["stun"].get("duration", 1)) * t.stats.cc_mult() * stun_dr     # resistência a controle (acessório lendário) e retorno decrescente
		if t.monster_def and t.monster_def.resists_cc():     # chefe: 40%; o Rei (elite) leva cheio
			dur *= 0.4
		t.is_blocking = false
		t.current_skill = null
		t.set_state(SimEntity.State.STUNNED, dur)
	if effects.get("sunder") is Dictionary and t != src:
		SunderSystem.apply(src, t, effects["sunder"])          # Fender Armadura: +1 carga de rachadura
	if effects.get("seed") is Dictionary and t != src:
		SeedSystem.plant(src, t, effects["seed"], effects.get("dot"))     # Semente Ígnea
	if effects.get("cocoon") is Dictionary and t != src and src.is_hostile_to(t):
		MobSystem.cocoon(self, src, t, effects["cocoon"])
	if effects.get("curse") != null:          # maldição (Necromancer): recebe mais dano e/ou causa menos; a mesma maldição renova
		var cu: Dictionary = effects["curse"]
		var cid: String = "curse_%s_%d" % [cu.get("id", "curse"), src.id]
		t.debuffs = t.debuffs.filter(func(dd): return dd.get("id") != cid)
		t.debuffs.append({"kind": "curse", "id": cid, "remaining": float(cu.get("duration", 8)), "taken_pct": float(cu.get("taken_pct", 0)), "weaken_pct": float(cu.get("weaken_pct", 0)),
			"mark": str(cu.get("id", "")) in Balance.MARK_CURSES})       # marcas somam até MARK_TAKEN_CAP (Combat.taken_pct)
		if src.form != "":
			NecroAscension.spread_curse(self, src, t, t.debuffs[-1])     # Forma de Lich: a maldição passa para quem está perto
	if effects.get("dot_amp") is Dictionary and t != src and src.is_hostile_to(t):
		UltEffects.apply_amp(src, t, effects["dot_amp"])          # Toxina Real / Eclipse: seus danos no tempo nele × mult
	if effects.get("curse_spread") is Dictionary and t != src and src.is_hostile_to(t):
		UltEffects.curse_spread(self, src, t, effects["curse_spread"])
	if effects.get("wither") != null:
		var w: Dictionary = effects["wither"]
		t.debuffs.append({"kind": "wither", "remaining": float(w.get("duration", 5)), "pct": float(w.get("pct", 50))})
	var longer: float = 1.0 + (src.stats.buff_duration / 100.0 if src.is_character() and src.stats else 0.0)     # bênçãos do Sacerdote duram mais
	if effects.get("form") != null and t == src:
		var was_form: String = t.form
		t.form = "" if t.form == effects["form"] else effects["form"]     # forma liga/desliga (a fantasma também acaba sozinha)
		var bound_pct := UltEffects.drop_form_bound(t, was_form) if was_form != "" and t.form != was_form else -1.0     # Colosso: sair do urso acaba o Colosso
		t.form_mult = float(effects.get("form_mult", 1.0)) * ClassTalentSystem.form_mult(t) if t.form != "" else 1.0
		t.form_left = float(Balance.FORM_DURATION.get(t.form, 0.0)) * ClassTalentSystem.form_time(t, t.form)
		t.recompute_stats()
		if bound_pct >= 0.0:
			t.hp = maxf(1.0, bound_pct * t.stats.max_hp)      # a % de vida fica
		NecroAscension.form_changed(self, t, was_form)        # Forma de Lich: ao sair, o excesso de invocações some
		Events.post(&"buff_applied", t.id, "form_" + (t.form if t.form != "" else "human"), t.form_left)
	if effects.get("stealth") != null and t == src:
		t.stealth_left = float(effects["stealth"])
		t.ambush = false
		for o in maps[t.map_id]["entities"]:        # quem estava atrás dele perde o rastro
			if o.kind == SimEntity.Kind.MONSTER and o.aggro_target == t.id and o.taunt_left <= 0.0:
				o.aggro_target = -1
		Events.post(&"buff_applied", t.id, "stealth", t.stealth_left)
	if effects.get("heal_pct") != null and (t == src or src.is_friend(t)):       # cura % do HP (talentos: Provocar, Sumir...)
		_heal(src, t, maxi(1, int(t.stats.max_hp * float(effects["heal_pct"]) / 100.0)))
	if effects.get("mana_pct") != null and (t == src or src.is_friend(t)):       # devolve % da mana (Chakra)
		t.mp = minf(t.stats.max_mp, t.mp + t.stats.max_mp * float(effects["mana_pct"]) / 100.0)
	if effects.get("buff") != null:
		var b: Dictionary = effects["buff"].duplicate()
		b["remaining"] = INF if b.get("toggle", false) else float(b.get("duration", 10)) * longer     # aura: até desligar ou morrer
		var max0: float = t.stats.max_hp
		t.put_buff(b)
		t.recompute_stats()
		if b.get("keep_hp", false) and t.stats.max_hp > max0:
			t.hp = minf(t.stats.max_hp, t.hp + t.stats.max_hp - max0)     # Colosso: a vida ganha entra cheia
		Events.post(&"buff_applied", t.id, b.get("id", "buff"), b["remaining"])
	if effects.get("shield") != null:
		var sh: Dictionary = effects["shield"]
		t.shield_hp = maxf(t.shield_hp, t.stats.max_hp * float(sh.get("amount_pct_hp", 20)) / 100.0)
		t.shield_src = src.id                      # a absorção conta como cura de quem pôs (Carga Suprema)
		var left := float(sh.get("duration", 5)) * longer
		for x in t.buffs:
			if x.get("id") == "shield":
				left = maxf(left, float(x.get("remaining", 0.0)))     # escudo novo não encurta o que já existe
		t.put_buff({"id": "shield", "remaining": left})
		Events.post(&"buff_applied", t.id, "shield", left)

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
	Events.post(&"projectile_spawned", p)

func _update_projectiles(m: Dictionary, dt: float) -> void:
	var projs: Array = m["projectiles"]
	for p in projs.duplicate():
		if not p.bounce.is_empty():
			if _update_bouncer(p, m, dt):
				projs.erase(p)
				Events.post(&"projectile_removed", p.id)
			continue
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
		if not remove and ChoirSystem.stops_projectile(self, m, p, owner):
			remove = true                    # Barreira Sagrada: projétil de fora para na borda
		if not remove:
			for t: SimEntity in m["entities"]:
				if not t.is_alive() or t.id in p.hit_ids or not owner.is_hostile_to(t):
					continue
				var d := Vector2(t.position.x, t.position.z).distance_to(Vector2(p.position.x, p.position.z))
				if d <= t.radius + p.radius:
					p.hit_ids.append(t.id)
					var from: Vector3 = t.position - p.direction        # projétil vem de onde voa, não de quem atirou
					_strike(owner, t, p.skill, p.power, p.skill.kind, from, bool(p.effects.get("sure_crit", false)))     # Disparo do Fim: crítico garantido
					if p.effects.has("pierce_rest") and p.hit_ids.size() == 1:
						p.power *= float(p.effects["pierce_rest"])     # atravessou o 1º: os outros levam menos
					owner.combat_timer = Balance.AGGRO_LOSE_TIME
					_apply_effects(owner, t, p.effects, p.power)
					_storm_proc(owner, p.skill, t)
					if p.effects.get("explode") is Dictionary:      # Bola de Fogo: explode no impacto
						_explode(owner, p, t, m)
					if p.skill.hit_stop_frames > 0 and (owner == player or t == player):
						Events.post(&"hit_stop", Combat.hit_stop_frames(p.skill, p.skill.hit_stop_frames, false, false), owner.id, [t.id])
					if not p.pierce:
						remove = true
						break
		if remove:
			projs.erase(p)
			Events.post(&"projectile_removed", p.id)

## Explosão no impacto (efeito "explode": {"radius", "power_pct"}): quem estiver a `radius` m do atingido leva
## power × power_pct e os efeitos do projétil (o "explode" não se repete). Bola de Fogo (Balance.FIREBALL_EXPLODE_*).
func _explode(owner: SimEntity, p: SimProjectile, hit: SimEntity, m: Dictionary) -> void:
	var ex: Dictionary = p.effects["explode"]
	var r := float(ex.get("radius", Balance.FIREBALL_EXPLODE_RADIUS))
	var pw := p.power * float(ex.get("power_pct", Balance.FIREBALL_EXPLODE_PCT))
	var fx: Dictionary = p.effects.duplicate()
	fx.erase("explode")
	for o: SimEntity in m["entities"]:
		if o == hit or not o.is_alive() or not owner.is_hostile_to(o) or o.position.distance_to(hit.position) > r + o.radius:
			continue
		_strike(owner, o, p.skill, pw, p.skill.kind, hit.position)
		_apply_effects(owner, o, fx, pw)
	Events.post(&"skill_effect", p.skill.id, hit.position, hit.position, r)     # o FX desenha a explosão (origem = ponto)

## Escudo arremessado (efeito "bounce"): projétil que persegue `first` (ou voa até `aim` e volta, sem alvo).
func _throw_bouncer(e: SimEntity, s: SkillDef, power: float, m: Dictionary, effects: Dictionary, first: SimEntity, aim: Vector3) -> void:
	var p := SimProjectile.new()
	p.id = _next_proj_id
	_next_proj_id += 1
	p.map_id = e.map_id
	p.owner_id = e.id
	p.skill = s
	p.effects = effects
	p.power = power
	p.position = e.position + Vector3(0, 0.9, 0) + e.forward() * 0.6
	var goal: Vector3 = first.position if first else aim
	var d := goal - e.position
	d.y = 0.0
	p.direction = d.normalized() if d.length() > 0.05 else e.forward()
	p.speed = s.projectile_speed if s.projectile_speed > 0.0 else 22.0
	p.max_distance = s.range
	p.radius = 0.45
	p.color = s.icon_color
	p.bounce = effects["bounce"]
	p.bounces_left = int(p.bounce.get("count", 3)) - 1
	p.homing_id = first.id if first else -1
	m["projectiles"].append(p)
	Events.post(&"projectile_spawned", p)

## Um passo do escudo arremessado. Devolve true quando ele volta à mão (ou se perde).
func _update_bouncer(p: SimProjectile, m: Dictionary, dt: float) -> bool:
	var owner: SimEntity = entities.get(p.owner_id)
	if owner == null or not owner.is_alive() or owner.map_id != p.map_id or p.traveled > p.max_distance * 6.0:
		return true
	var step: float = p.speed * dt
	var tgt: SimEntity = owner if p.returning else entities.get(p.homing_id)
	if not p.returning and p.homing_id >= 0 and (tgt == null or not tgt.is_alive() or tgt.map_id != p.map_id):
		tgt = _next_bounce(p, owner, m, p.position)          # o alvo morreu no caminho: segue para o próximo
		if tgt == null:
			p.returning = true
			tgt = owner
		else:
			p.homing_id = tgt.id
	var goal: Vector3 = (tgt.position + Vector3(0, 0.9, 0)) if tgt else p.position + p.direction * step
	var to := goal - p.position
	var dist := to.length()
	if dist > 0.01:
		p.direction = to / dist
	p.position += p.direction * minf(step, dist)
	p.traveled += step
	if p.returning:
		return dist <= step + 0.6                             # pegou de volta
	var back := bool(p.bounce.get("back", true))             # bala (Corsário): não volta, some no último salto
	if tgt == null:                                           # lançado no vazio: vai até o alcance e volta
		if p.traveled >= p.max_distance:
			if not back:
				return true
			p.returning = true
		return false
	if dist > step + tgt.radius + p.radius:
		return false
	# acertou: dano, provocação, interrupção; depois salta ou volta
	p.hit_ids.append(tgt.id)
	var from: Vector3 = tgt.position - p.direction
	var r := _strike(owner, tgt, p.skill, p.power, p.skill.kind, from)
	owner.combat_timer = Balance.AGGRO_LOSE_TIME
	if tgt.is_alive() and tgt.kind == SimEntity.Kind.MONSTER and tgt.monster_def:
		var casting := tgt.state == SimEntity.State.CASTING and tgt.skill_phase == "startup"
		if float(p.bounce.get("taunt", Balance.TAUNT_DURATION)) > 0.0:
			MobSystem.taunt(self, tgt, owner, float(p.bounce.get("taunt", Balance.TAUNT_DURATION)))
		if casting and float(p.bounce.get("interrupt", 0.0)) > 0.0:
			_apply_effects(owner, tgt, {"stun": {"duration": float(p.bounce["interrupt"])}}, 0.0)
			Events.post(&"damage_dealt", owner.id, tgt.id, 0, false, false, "interrupt")
	if float(p.bounce.get("stun", 0.0)) > 0.0 and tgt.is_alive() and int(r["amount"]) > 0:     # Martelo da Justiça: atordoa quem leva
		_apply_effects(owner, tgt, {"stun": {"duration": float(p.bounce["stun"])}}, 0.0)
	Events.post(&"skill_effect", p.skill.id, p.position, tgt.position, -1.0)     # raio < 0 = salto do escudo (FX do ricochete)
	if int(r["amount"]) > 0 and p.skill.hit_stop_frames > 0 and (owner == player or tgt == player):
		Events.post(&"hit_stop", Combat.hit_stop_frames(p.skill, maxi(2, p.skill.hit_stop_frames - p.hit_ids.size() + 1), false, false), owner.id, [tgt.id])
	var nxt: SimEntity = _next_bounce(p, owner, m, tgt.position) if p.bounces_left > 0 else null
	if nxt:
		p.bounces_left -= 1
		p.homing_id = nxt.id
		p.power *= float(p.bounce.get("falloff", 0.85))
	elif not back:
		return true
	else:
		p.returning = true
	return false

## Próximo alvo do ricochete: o inimigo vivo mais perto de `at` (até `radius`) que o escudo ainda não acertou.
func _next_bounce(p: SimProjectile, owner: SimEntity, m: Dictionary, at: Vector3) -> SimEntity:
	var best: SimEntity = null
	var best_d := float(p.bounce.get("radius", 6.0))
	for o: SimEntity in m["entities"]:
		if not o.is_alive() or o.id in p.hit_ids or not owner.is_hostile_to(o) or o.is_perched():
			continue
		var d: float = Vector2(o.position.x - at.x, o.position.z - at.z).length() - o.radius
		if d < best_d:
			best_d = d
			best = o
	return best

## Monstro, chefe, lacaio ou invocação de monstro (dano no tempo deles renova em vez de acumular).
func _monster_side(src: SimEntity) -> bool:
	if src.kind == SimEntity.Kind.MONSTER:
		return true
	if src.kind == SimEntity.Kind.SUMMON and entities.has(src.owner_id):
		return (entities[src.owner_id] as SimEntity).kind == SimEntity.Kind.MONSTER
	return false

## Id do dano no tempo mágico: monstro = "dot_<src>" (um por tipo, renova); jogador = "dot_<src>_<skill>" (teto por skill;
## sem skill, ex. dano no tempo de efeito sem skill, fica "dot_<src>").
static func dot_id(src: SimEntity, d: Dictionary, monster_side: bool) -> String:
	var sk := str(d.get("skill", ""))
	return "dot_%d" % src.id if monster_side or sk == "" else "dot_%d_%s" % [src.id, sk]

## Dano no tempo do jogador: acumula até Balance.PLAYER_DOT_MAX_STACKS cópias do mesmo id; a próxima tira a mais antiga
## (o acumulado e o relógio do pulso dela passam para a nova, como no put_debuff).
func _put_dot(t: SimEntity, nd: Dictionary) -> void:
	var n := 0
	var oldest: Dictionary = {}
	for od in t.debuffs:
		if od.get("kind") == "dot" and od.get("id") == nd["id"]:
			if n == 0:
				oldest = od
			n += 1
	if n >= Balance.PLAYER_DOT_MAX_STACKS:
		nd["acc"] = float(oldest.get("acc", 0.0))
		if oldest.has("pulse"):
			nd["pulse"] = oldest["pulse"]
		t.debuffs.erase(oldest)
	t.debuffs.append(nd)

## Dano no tempo de monstro com o mesmo id (e o mesmo tipo, fogo ou não) renova: duração nova, maior dps; o acumulado e
## o relógio do pulso ficam (reaplicar sem parar não adia o pulso). Devolve false se não havia um para renovar.
func _renew_dot(t: SimEntity, nd: Dictionary) -> bool:
	for od in t.debuffs:
		if od.get("kind") == "dot" and od.get("id") == nd["id"] and bool(od.get("fire", false)) == bool(nd["fire"]):
			od["remaining"] = float(nd["remaining"])
			od["dps"] = maxf(float(od.get("dps", 0.0)), float(nd["dps"]))
			return true
	return false

## Combustão: tira as queimaduras de `src` em `t` e devolve quanto dano elas ainda iam causar.
func consume_burns(src: SimEntity, t: SimEntity) -> float:
	var left := 0.0
	var keep: Array = []
	for d in t.debuffs:
		if d.get("kind") == "dot" and d.get("fire", false) and int(d.get("src", -1)) == src.id:
			left += float(d.get("dps", 0.0)) * maxf(0.0, float(d.get("remaining", 0.0))) + float(d.get("acc", 0.0))
		else:
			keep.append(d)
	t.debuffs = keep
	return left

# ----------------------------------------------------------------------------
# DANO / CURA / MORTE
# ----------------------------------------------------------------------------
## `dodgeable` = false: zona avisada no chão (assinatura/perigo de chefe); a esquiva passiva (AGI) não salva, só sair dela.
## Devolve false quando o golpe não pegou (alvo morto/intocável, dash, aparado inteiro, esquiva): a Carga Suprema só
## conta golpe que pegou (UltimateSystem.on_dealt/on_taken).
func _deal_damage(attacker: SimEntity, target: SimEntity, amount: int, crit: bool, blocked: bool, kind: String, from: Variant = null, dodgeable := true) -> bool:
	if not target.is_alive() or target.is_perched() or target.shade:
		return false
	if target.iframe_left > 0.0 and attacker != target and not kind.begins_with("dot"):     # dash: invulnerável a golpe direto
		Events.post(&"dodged", target.id)
		return false
	var raw_amount := amount                       # Carga Suprema: dano depois da DEF, antes de aparar/bloqueio/escudo/cúpula
	if dodgeable and attacker != target and kind != "riposte" and not kind.begins_with("dot") and not target.buffs.is_empty():
		var rp := RiposteSystem.on_hit(self, target, attacker, amount, from)     # Guarda do Duelista: aparar e responder
		if rp == -1:
			return false
		if rp >= 0:
			amount = rp                       # chefe: passa parte (aparado não rola a esquiva de novo)
			blocked = true
			dodgeable = false
	var in_arc := Combat.in_guard_arc(target, attacker.position if from == null else from)
	var parried: bool = target.parry_left > 0.0 and target.is_blocking and attacker != target and not kind.begins_with("dot") and in_arc
	if target.is_blocking and not in_arc and not kind.begins_with("dot") and attacker != target:
		Events.post(&"guard_flanked", target.id)
	if parried:
		blocked = true
		amount = maxi(1, int(round(amount * (1.0 - Balance.PARRY_REDUCTION / 100.0))))
		target.parry_left = 0.0
	elif target.monster_def != null and target.monster_def.front_guard > 0.0 and kind == "physical" and attacker != target 			and Combat.in_guard_arc(target, attacker.position if from == null else from):
		blocked = true                          # escudo de frente: pelas costas (ou com magia) o golpe passa inteiro
		amount = maxi(1, int(round(amount * (1.0 - target.monster_def.front_guard))))
	elif not target.sig.is_empty() and target.sig.has("wall") and attacker != target and not kind.begins_with("dot") 			and BossSignatures.wall_blocks(target, attacker.position if from == null else from):
		blocked = true                          # Muralha de Escudos (Ghar): física e mágica da frente; soma fúria
		amount = BossSignatures.wall_cut(target, amount)
	# levou um golpe (não dano no tempo): cai do cavalo (Combate Montado: só controle derruba, MountedCombat.filter_cc)
	if target.mounted and not kind.begins_with("dot") and attacker != target and not MountedCombat.fights_mounted(target):
		dismount(target)
	if target.mount_left > 0.0 and not kind.begins_with("dot") and attacker != target:
		stop_mount(target, "Montaria interrompida")        # levou golpe no meio da conjuração
	if target.is_character():
		target.combat_timer = maxf(target.combat_timer, Balance.MOUNT_COMBAT_LOCK)
	if not attacker.ct.is_empty() and attacker != target and not kind.begins_with("dot"):
		amount = maxi(1, int(round(amount * ClassTalentSystem.damage_mult(attacker, target))))     # ferido / execução
	if attacker.is_character() and attacker != target and not attacker.stats.fusion.is_empty():
		amount = maxi(1, int(round(amount * FusionEffects.damage_mult(attacker, target))))     # Fusão: Sentença Ardente (P2), Lua Caçadora (D2)
	if attacker.is_character() and attacker != target and attacker.stats.taunt_dmg_pct > 0.0:
		amount = maxi(1, int(round(amount * Combat.role_damage_mult(attacker, target))))     # notável de tanque: quem bate em você apanha mais
	if attacker != target and not kind.begins_with("dot") and kind != "intercept" and (attacker.kind == SimEntity.Kind.SUMMON or (attacker.is_character() and attacker.stats.low_hp_atk > 0.0)):
		amount = maxi(1, int(round(amount * Combat.core_damage_mult(self, attacker))))     # Fúria da Beira / Fúria dos Mortos
	# maldições: alvo amaldiçoado recebe mais, atacante enfraquecido causa menos
	var taken := Combat.taken_pct(target) if not target.debuffs.is_empty() else 0.0     # marcas com teto (MARK_TAKEN_CAP)
	var weak := Combat.curse_sum(attacker, "weaken_pct")
	if taken > 0.0 or weak > 0.0:
		amount = maxi(1, int(round(amount * (1.0 + taken / 100.0) * (1.0 - minf(weak, Balance.CURSE_WEAKEN_CAP) / 100.0))))
	if attacker.kind == SimEntity.Kind.SUMMON and not attacker.buffs.is_empty():
		amount = NecroAscension.pact_damage(attacker, amount)       # Pacto dos Mortos: a invocação bate mais
	if target.ward > 0.0 and attacker != target:          # chefe com lacaios vivos: escudo da fase ("ward")
		amount = maxi(1, int(round(amount * (1.0 - target.ward))))
	if target.stats.dr_pct > 0.0 and attacker != target:      # aura do tanque: menos dano em quem está no grupo dele
		amount = maxi(1, int(round(amount * (1.0 - minf(target.stats.dr_pct, Balance.DR_CAP) / 100.0))))
	if target.is_character() and attacker != target and target.stats.low_dr > 0.0:
		amount = Combat.core_low_dr(target, amount)           # Firme na Queda (fora do DR_CAP, teto próprio)
	amount = ChoirSystem.damage_in(self, attacker, target, amount)      # Barreira Sagrada: menos dano dentro (45: segura em 1)
	# esquiva (Assassino): o golpe direto não pega (zona avisada no chão não: decisão 2026-11-13)
	if dodgeable and not kind.begins_with("dot") and attacker != target and target.is_character() and target.stats.evasion > 0.0 and rng.randf() * 100.0 < target.stats.evasion:
		RiposteSystem.legend_dodge(self, target, attacker, kind)     # Riposte lendária: esquivou, responde e ganha Ímpeto
		FistSystem.on_dodge(self, target, attacker, kind)          # Punhos de Fúria: esquiva vira Fúria e contra-ataque
		FusionEffects.on_dodge(self, target, attacker)
		PieceEffects.on_event(self, target, "dodge", attacker)          # Lendários do 50
		ShadowSystem.on_dodge(target)                              # Duelista ascendido: esquiva prepara a Execução
		Events.post(&"dodged", target.id)
		return false
	if target.is_character() and attacker != target:
		UltimateSystem.on_taken(self, attacker, target, raw_amount, kind)     # Carga Suprema: só golpe que pegou (depois da esquiva)
		if kind != "intercept":
			amount = InterceptSystem.damage_in(self, attacker, target, amount)     # Proteção (Suprema do Guardião): fora do DR_CAP
			if target.stats.summon_guard > 0.0 or target.party_id >= 0:
				amount = Combat.core_redirect(self, attacker, target, amount)     # Escudo de Carne / Escudo dos Irmãos
	# veneno na lâmina: golpe físico direto envenena (renova, não acumula)
	if kind == "physical" and attacker != target and attacker.is_character() and attacker.stats.hit_poison > 0.0:
		var pid := "blade_poison_%d" % attacker.id
		var pd := {"kind": "dot", "id": pid, "remaining": Balance.HIT_POISON_TIME, "dps": attacker.stats.hit_poison * attacker.stats.dot_mult(), "src": attacker.id}
		for b in attacker.buffs:
			if b.get("wound_hold", false):
				pd["ult"] = true                      # Festim de Sangue: a sangria dele é dano de Suprema (não enche a carga)
				break
		target.put_debuff(pd)
	if target.shield_hp > 0.0:
		var absorbed := minf(target.shield_hp, float(amount))
		target.shield_hp -= absorbed
		amount -= int(absorbed)
		if absorbed > 0.0 and target.shield_src >= 0:
			UltimateSystem.on_shield_absorb(self, target, absorbed)
	if not target.ct.is_empty():
		amount = ClassTalentSystem.mana_shield(target, amount)
	if target.is_character() and attacker != target and target.stats.mana_guard > 0.0:
		amount = Combat.role_mana_guard(target, amount)      # Barreira de Mana (notável)
	amount = ClassTalentSystem.before_hit(self, target, amount)       # imortal / recusa a morrer
	if amount > 0 and target.recall_left > 0.0:
		PortalSystem.interrupt_recall(self, target)                   # levou dano (o que a barreira segurou não conta)
	if amount > 0 and attacker != target and target.monster_def != null and target.monster_def.decoy:
		amount = maxi(amount, int(ceil(target.hp)))   # cópia do Shazka (R-F): morre com 1 golpe
	target.hp -= amount
	target.hurt_at = time
	if target.monster_def != null and target.monster_def.dummy:
		target.hp = maxf(target.hp, 1.0)          # boneco de treino: nunca cai
	if amount > 0 and not target.sig.is_empty() and attacker != target:
		if target.sig.has("channel"):
			BossSignatures.on_damage(target, amount)     # canal do chefe: dano aplicado (depois do ward) quebra
		if target.sig.has("decoys") and not kind.begins_with("dot"):
			BossSignatures.on_real_hit(self, target)     # golpe no Shazka verdadeiro: as cópias somem
	if amount > 0 and attacker.kind == SimEntity.Kind.SUMMON and not attacker.buffs.is_empty():
		NecroAscension.pact_leech(self, attacker, amount)           # Pacto dos Mortos: o que ela causa cura o necromante
	if amount > 0 and not kind.begins_with("dot") and attacker != target and attacker.is_character() and attacker.is_alive() and attacker.stats.lifesteal > 0.0:
		Combat.core_leech(attacker, amount * attacker.stats.lifesteal / 100.0)     # roubo de vida (o que sobra vira barreira com o nó)
	if amount > 0 and kind in ["magical", "shatter"] and attacker != target and attacker.is_character() and attacker.is_alive() and attacker.stats.radiance > 0.0:
		_radiance(attacker, amount)
	if amount > 0 and kind == "physical" and attacker != target and attacker.is_character() and attacker.is_alive() and attacker.stats.phys_mend > 0.0:
		mend(attacker, amount, attacker.stats.phys_mend / 100.0)      # Avatar da Fé
	if target.hp > 0.0 and attacker != target and not target.buffs.is_empty() and not kind.begins_with("dot"):
		ChoirSystem.on_hit_taken(self, target, amount)                # Égide Coral: cura por golpe recebido
	target.hit_flash = Balance.HIT_FLASH_TIME
	target.combat_timer = Balance.AGGRO_LOSE_TIME
	target.last_damage_from = attacker.id
	if attacker.is_character() and target.kind == SimEntity.Kind.MONSTER and not kind.begins_with("dot"):
		attacker.last_target_id = target.id      # o elemental (modo atacar) segue este alvo
	target.threat[attacker.id] = float(target.threat.get(attacker.id, 0.0)) + amount * (1.0 + (attacker.stats.threat_pct if attacker.form != "ent" else DruidAscension.threat_pct(self, attacker)) / 100.0)     # aura do tanque: mais ameaça (Ent só se for o tanque)
	if target.kind == SimEntity.Kind.MONSTER and not target.monster_def.dummy:     # boneco: sem aggro nem crédito de abate
		var who: int = attacker.owner_id if attacker.kind == SimEntity.Kind.SUMMON else attacker.id   # invocação conta para o dono, mesmo depois de expirar
		if not attacker.guard:              # sentinela não rouba o abate: XP e saque ficam com quem lutou junto
			target.damage_by[who] = float(target.damage_by.get(who, 0.0)) + amount
		MobSystem.retarget(self, target, attacker)
	if ult_tag > 0 and attacker.kind != SimEntity.Kind.MONSTER:
		attacker.ult_dealt += amount               # medição: dano de Suprema (antes do evento: a sonda lê no evento)
	Events.post(&"damage_dealt", attacker.id, target.id, amount, crit, blocked, kind)
	if blocked:
		Events.post(&"blocked_hit", target.id)
	if attacker != target and attacker.is_character() and target.kind == SimEntity.Kind.MONSTER and (target.hp <= 0.0 or (crit and not kind.begins_with("dot"))):
		GladiatorSystem.on_hit(self, attacker, crit and not kind.begins_with("dot"), target.hp <= 0.0)     # Glória: crítico e abate
	if target.hp <= 0.0:
		target.hp = 0.0
		_kill(target, attacker)
	elif blocked and target.stats.has_shield:
		ShieldSystem.shield_reaction(self, target, attacker, amount, parried, from)
	LegendEffects.legend_weapon(self, attacker, target, amount, kind)
	if attacker.is_character() or (blocked and target.is_character()):
		Combat.role_on_hit(self, attacker, target, amount, crit, blocked, kind)     # notáveis de papel (roubo, lentidão, bloqueio)
	if target.is_character() and not target.stats.fusion.is_empty() and attacker != target and not kind.begins_with("dot") and target.is_alive():
		FusionEffects.on_hit_taken(self, attacker, target)     # Casca Partilhada (D3)
	return true

func _heal(src: SimEntity, target: SimEntity, amount: int, share := true) -> void:
	if not target.is_alive() or amount <= 0:
		return
	var before := target.hp
	var raw := target.hp + amount * target.heal_factor()
	target.hp = minf(target.stats.max_hp, raw)
	if share and raw > target.stats.max_hp and src.is_character() and src.stats.overheal_share > 0.0:
		_overheal_share(src, target, raw - target.stats.max_hp)       # Graça Transbordante
	Events.post(&"healed", src.id, target.id, int(target.hp - before))
	if src.is_character() and target.hp > before:
		UltimateSystem.on_heal(self, src, target, target.hp - before)     # Carga Suprema: só a cura efetiva
	if src != target and src.party_id >= 0 and src.party_id == target.party_id and target.hp - before >= target.stats.max_hp * 0.15:
		if src == player and target.kind == SimEntity.Kind.BOT:
			BotChat.party_event(self, target, "healed_by_player", {}, target, 0.5)
		elif target == player and src.kind == SimEntity.Kind.BOT:
			BotChat.party_event(self, target, "healed_player", {}, src, 0.35)
	if src.is_character() and src.stats.ward_pct > 0.0:      # arma lendária de cura: Égide (parte da cura vira barreira)
		var wpct := src.stats.ward_pct
		var lw := PieceEffects.wake(src, "low")             # Égide Desperta: aliado com pouca vida ganha mais
		if not lw.is_empty() and before < target.stats.max_hp * Balance.LEG50_LOW_HP:
			wpct *= 1.0 + float(lw["pct"]) / 100.0
		_ward(target, amount * wpct / 100.0)
		if share and int(src.stats.legend.get("targets", 0)) > 0:      # peito do Sacerdote 50: a Égide cobre +1 aliado
			var other := PieceEffects.most_hurt_other(self, src, target, Balance.RADIANCE_RANGE)
			if other != null:
				_ward(other, amount * wpct / 100.0)

## Barreira da Égide em `target` (soma, teto de 30% da vida; o buff "shield" mostra e marca o tempo).
func _ward(target: SimEntity, add: float) -> void:
	target.shield_hp = minf(target.shield_hp + add, target.stats.max_hp * 0.3)
	var sb: Array = target.buffs.filter(func(b): return b.get("id") == "shield")
	if sb.is_empty():
		target.buffs.append({"id": "shield", "remaining": Balance.LEG_WARD_TIME})
	else:
		sb[0]["remaining"] = maxf(float(sb[0]["remaining"]), Balance.LEG_WARD_TIME)

## Graça Transbordante: overheal_share% da cura que passou do máximo de `target` vai para o personagem aliado mais
## ferido (em %) a até OVERHEAL_SHARE_RANGE m dele, fora ele mesmo (sem repassar de novo).
func _overheal_share(src: SimEntity, target: SimEntity, over: float) -> void:
	var best: SimEntity = null
	var bf := 1.0
	for o in maps[target.map_id]["entities"]:
		if o == target or not o.is_character() or not o.is_alive() or not src.is_friend(o):
			continue
		var f: float = o.hp / maxf(1.0, o.stats.max_hp)
		if f < bf and o.position.distance_to(target.position) <= Balance.OVERHEAL_SHARE_RANGE:
			bf = f
			best = o
	if best != null:
		_heal(src, best, maxi(1, int(over * src.stats.overheal_share / 100.0 / maxf(0.01, best.heal_factor()))), false)

## Forma com tempo acabou: volta ao normal (mesmo aviso de quando desliga).
func end_form(e: SimEntity) -> void:
	e.form_left = 0.0
	if e.form == "":
		return
	var was := e.form
	e.form = ""
	e.recompute_stats()
	NecroAscension.form_changed(self, e, was)
	Events.post(&"buff_applied", e.id, "form_human", 0.0)

## Amuleto de mana (Stats.mp_on_kill): quem abate (ou o dono da invocação que abateu) recupera % da mana máxima.
func _mana_on_kill(killer: SimEntity) -> void:
	var k := killer
	if k and k.kind == SimEntity.Kind.SUMMON:
		k = entities.get(k.owner_id)
	if k == null or not k.is_alive() or k.stats == null or k.stats.mp_on_kill <= 0.0:
		return
	k.mp = minf(k.stats.max_mp, k.mp + k.stats.max_mp * k.stats.mp_on_kill / 100.0)

func _kill(e: SimEntity, killer: SimEntity) -> void:
	if e.monster_def != null and e.monster_def.dummy:    # boneco de treino: execução/morte direta também não o derruba
		e.hp = maxf(e.hp, 1.0)
		return
	if e.shift_base != null or e.shift_left > 0.0:
		ShiftSystem.revert(self, e, true)          # morre como a forma, mas XP/saque/quest contam pela base
	if not e.sig.is_empty():
		BossSignatures.on_death(self, e)          # cópia solta veneno; chefe leva as cópias junto (R-F)
	NecroAscension.on_death(self, e)          # Marca da Cova (levanta) e fim da Forma de Lich; antes de limpar debuffs/forma
	FusionEffects.on_kill(self, e, killer)     # Fusões: Ceifa Partilhada, Colheita da Praga (lê as maldições do morto)
	PieceEffects.on_kill(self, e, killer)      # Lendários do 50: abate e Praga Desperta (antes de limpar os debuffs)
	e.mounted = false
	e.cc_immune_left = 0.0
	e.recall_left = 0.0
	e.mount_left = 0.0
	e.is_blocking = false
	e.form = ""
	e.form_left = 0.0
	e.stealth_left = 0.0
	e.ambush = false
	e.current_skill = null
	if e.is_character():
		UltimateSystem.zero(e)               # morrer zera a Carga Suprema
	if not e.hop.is_empty():
		HopSystem.cancel(e)
	if not e.debuffs.is_empty():
		UltEffects.on_death(self, e)         # Toxina Real/Eclipse: a marca espalha os danos no tempo antes de limpar
		FalconSystem.on_death(self, e)       # Falcão Real: a Presa passa para o vizinho (antes de limpar)
		SeedSystem.on_death(self, e)         # Semente Ígnea: o alvo morreu antes, estoura agora
	if e.falcon:
		FalconSystem.dismiss(e)
	e.buffs.clear()
	e.debuffs.clear()
	e.shield_hp = 0.0
	e.set_state(SimEntity.State.DEAD)
	e.dead_time = 0.0
	Events.post(&"entity_died", e.id, killer.id if killer else -1)
	if e.kind == SimEntity.Kind.MONSTER:
		AuraSystem.on_mob_death(self, e)
		LootSystem.on_monster_killed(self, e, killer)
		ClassTalentSystem.on_kill(self, killer, e)
		_mana_on_kill(killer)
		ElementalSystem.on_monster_killed(self, e)
	elif e.kind == SimEntity.Kind.SUMMON and e.elem_form != "":
		ElementalSystem.on_died(self, e)
	elif e.kind == SimEntity.Kind.PLAYER:
		Events.post(&"notification", "Você morreu. Renascendo %s..." % BotsCatalog.place_words(map_def(PortalSystem.home_of(e)["map"]).name)["em"])
		var loss := int(e.xp * Balance.DEATH_XP_PENALTY)
		e.xp = maxi(0, e.xp - loss)
		BotChat.party_event(self, e, "player_died")
	elif e.kind == SimEntity.Kind.BOT:
		if BotChat.in_player_party(self, e):
			BotChat.party_event(self, e, "bot_died", {}, e, 0.7)
		elif rng.randf() < 0.5:
			Events.post(&"chat_message", e.name, GameData.random_bot_line("death"), "global")

var _elite_defs: Dictionary = {}
var _raid_defs: Dictionary = {}      # "<id>@<passo>@<mapa>" -> MonsterDef da investida reforçada (RaidSystem.scaled_def)

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
	if not e.sig.is_empty() and e.sig.has("decoy_of") and BossSignatures.update_decoy(self, e):
		return                                       # cópia do Shazka desfeita (R-F)
	# cooldowns
	# (só o que está contando: quase tudo está em zero quase sempre)
	if e.basic_cd > 0.0:
		e.basic_cd = maxf(0.0, e.basic_cd - dt)
	if e.parry_left > 0.0:
		e.parry_left = maxf(0.0, e.parry_left - dt)
	if e.parry_cd > 0.0:
		e.parry_cd = maxf(0.0, e.parry_cd - dt)
	if e.shield_react_cd > 0.0:
		e.shield_react_cd = maxf(0.0, e.shield_react_cd - dt)
	if e.grace_cd > 0.0:
		e.grace_cd = maxf(0.0, e.grace_cd - dt)
	var pcd := e.potion_cds
	for ps in range(pcd.size()):
		if pcd[ps] > 0.0:
			pcd[ps] = maxf(0.0, pcd[ps] - dt)
	if e.dash_cd > 0.0:
		e.dash_cd = maxf(0.0, e.dash_cd - dt)
	if e.iframe_left > 0.0:
		e.iframe_left = maxf(0.0, e.iframe_left - dt)
	if e.sky_left > 0.0:
		RangerAscension.tick_sky(e, dt)
	if e.jump_window > 0.0:
		RangerAscension.tick_window(e, dt)     # Salto Duplo: a janela do 2º salto
	if e.falcon:
		FalconSystem.tick(self, e, dt)
	if e.combat_timer > 0.0:
		e.combat_timer = maxf(0.0, e.combat_timer - dt)
	if e.level >= Balance.ULT_LEVEL and e.is_character() and e.is_alive():
		UltimateSystem.tick(self, e, dt)         # Carga Suprema: gotejar em combate / esvaziar fora dele
	if not e.hop.is_empty():
		HopSystem.tick(self, e, m)
	if e.stealth_left > 0.0:
		e.stealth_left = maxf(0.0, e.stealth_left - dt)
	if e.cc_immune_left > 0.0 or (e.kind != SimEntity.Kind.MONSTER and not e.buffs.is_empty()):
		MountedCombat.tick(self, e, dt)         # imunidade depois de cair do cavalo e MP do Modo Arcano
	if e.form_left > 0.0:
		e.form_left -= dt
		if e.form_left <= 0.0:
			end_form(e)
	# pulo: gravidade até voltar ao chão
	if e.jump_h > 0.0 or e.jump_v > 0.0:
		e.jump_v -= Balance.JUMP_GRAVITY * dt
		e.jump_h += e.jump_v * dt
		if e.jump_h <= 0.0:
			e.jump_h = 0.0
			e.jump_v = 0.0
	if not e.cooldowns.is_empty():                # vazio: sem alocar a lista de chaves (por entidade, todo tick)
		for k in e.cooldowns.keys():
			e.cooldowns[k] = maxf(0.0, e.cooldowns[k] - dt)
	if not e.charges.is_empty():
		ChargeSystem.tick(e, dt)                  # cargas de skill: a da frente da fila volta
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
				Events.post(&"entity_respawned", e.id)
		elif e.res_hold > 0.0:
			e.res_hold -= dt                             # um Bispo conjura o Retorno: espera em vez de renascer
		elif e.dead_time >= Balance.PLAYER_RESPAWN_TIME + (2.0 if e.kind == SimEntity.Kind.BOT else 0.0):
			ProgressionSystem.respawn_character(self, e)
		return
	if e.shade and ShadowSystem.tick_clone(self, e):       # clone de sombra: some com o dono / no fim do tempo
		return
	# invocação expira
	if e.kind == SimEntity.Kind.SUMMON and time >= e.summon_expires:
		if not e.expire_blast.is_empty():
			SummonRites.expire_blast(self, e)     # Maré dos Mortos: o esqueleto explode ao se desfazer
		despawn(e)
		return
	# invocação perdida (presa longe, fora da tela) aparece ao lado do dono
	if e.kind == SimEntity.Kind.SUMMON and e.owner_id >= 0:
		var owner: SimEntity = entities.get(e.owner_id)
		if owner and owner.is_alive() and owner.map_id == e.map_id and e.position.distance_to(owner.position) > Balance.SUMMON_TELEPORT and not RangerAscension.is_turret(e) and not e.shade:
			e.position = owner.position + Vector3(0.8, 0, 0.8)
			e.velocity = Vector3.ZERO
			e.aggro_target = -1
	# lacaio sem chefe (morto ou resetado) some
	if e.boss_id >= 0:
		var boss: SimEntity = entities.get(e.boss_id)
		if boss == null or not boss.is_alive() or boss.adds_epoch != e.adds_epoch:
			despawn(e)
			return
	# buffs / debuffs
	var recompute := false
	var keep_pct := -1.0
	_ended.clear()                                  # buffs com fim / marcas que acabaram neste tique (sem alocar por entidade)
	for b in (e.buffs.duplicate() if not e.buffs.is_empty() else e.buffs):     # cópia só quando há o que remover
		b["remaining"] = float(b.get("remaining", 0)) - dt
		if b.get("oath_lock", false) and b["remaining"] > 0.0:
			UltEffects.oath_lock(e)                  # Céu de Martelos: Juramento cheio enquanto dura
		if b.get("wound_hold", false) and b["remaining"] > 0.0:
			WoundSystem.hold(self, e, dt)            # Festim de Sangue: suas feridas não fecham
		if b.get("keep_hp", false) and b["remaining"] <= 0.0:
			keep_pct = e.hp / maxf(1.0, e.stats.max_hp)     # Colosso: a % de vida fica quando a vida máx. volta
		if b["remaining"] <= 0.0:
			e.buffs.erase(b)
			if b.get("id") == "shield":
				e.shield_hp = 0.0
				e.shield_src = -1
			if b.has("end_cast"):
				_ended.append(b)
			recompute = true
	for d in (e.debuffs.duplicate() if not e.debuffs.is_empty() else e.debuffs):
		var rem: float = float(d.get("remaining", 0))
		d["remaining"] = rem - dt
		if d.get("kind") == "dot":
			# dano no tempo em pulsos (Balance.DOT_PULSE_S): acumula dps*dt (só até acabar) e solta a parte inteira no pulso;
			# no fim solta o resto arredondado (mesmo total de antes, sem 60 números por segundo)
			d["acc"] = float(d.get("acc", 0.0)) + float(d["dps"]) * clampf(rem, 0.0, dt)
			var pulse: float = float(d.get("pulse", Balance.DOT_PULSE_S)) - dt
			var ending: bool = d["remaining"] <= 0.0
			var pulse_now := false
			if pulse <= 0.0001:
				pulse += Balance.DOT_PULSE_S
				pulse_now = true
			d["pulse"] = pulse
			var dmg := roundi(float(d["acc"])) if ending else (int(d["acc"]) if pulse_now else 0)
			if dmg >= 1:
				d["acc"] -= dmg
				var src: SimEntity = entities.get(int(d.get("src", -1)))
				if src:
					var dot_ult: bool = d.get("ult", false)
					if e.debuffs.size() > 1 and src.kind != SimEntity.Kind.MONSTER:
						var base_dmg := dmg
						dmg = UltEffects.amp(e, src, dmg)      # Toxina Real / Eclipse
						if dmg > base_dmg and not dot_ult:
							src.ult_dealt += dmg - base_dmg      # medição: a parte que a marca acrescenta (dot de Suprema já conta inteiro)
					if dot_ult:
						ult_tag += 1
					var hit_ok := _deal_damage(src, e, dmg, false, false, "dot_fire" if d.get("fire", false) else "dot")
					if dot_ult:
						ult_tag -= 1
					if hit_ok and src.kind != SimEntity.Kind.MONSTER:
						UltimateSystem.on_dot(self, src, e, dmg, d)
					if not e.is_alive():
						return
		if d["remaining"] <= 0.0:
			e.debuffs.erase(d)
			if d.get("kind") == SeedSystem.KIND:
				SeedSystem.burst(self, e, d)          # Semente Ígnea: o tempo acabou, estoura em volta
				if not e.is_alive():
					return
			elif d.get("kind") == Balance.DOT_AMP_KIND:
				_ended.append(d)
	for x in (_ended.duplicate() if not _ended.is_empty() else _ended):
		if x.has("end_cast"):
			UltEffects.end_cast(self, e, x)         # Festim/Duelo: a skill de fechamento sai sozinha
		else:
			UltEffects.amp_end(self, e, x)          # Toxina Real: detona e espalha os danos no tempo
		if not e.is_alive():
			return
	if recompute:
		e.recompute_stats()
		if keep_pct >= 0.0:
			e.hp = maxf(1.0, keep_pct * e.stats.max_hp)
	# regen
	if e.combat_timer <= 0.0 and (e.is_character() or e.guard):
		e.hp = minf(e.stats.max_hp, e.hp + e.stats.max_hp * Balance.REGEN_HP_PCT * (Balance.GUARD_REGEN_MULT if e.guard else 1.0) * dt)
	if e.kind == SimEntity.Kind.MONSTER and e.monster_def.regen > 0.0:
		MobSystem.update_regen(self, e, dt)
	elif e.kind == SimEntity.Kind.MONSTER and e.monster_def.dummy:
		MobSystem.update_dummy(self, e, dt)
	if not e.is_blocking and e.mp != e.stats.max_mp:        # cheio: o teto devolveria o mesmo valor
		var mp_regen := (e.stats.max_mp * Balance.REGEN_MP_PCT + Balance.REGEN_MP_FLAT) * dt
		if e.combat_timer > 0.0 and e.stats.mp_regen_combat > 0.0:     # capa de mana: só em combate
			mp_regen += e.stats.max_mp * e.stats.mp_regen_combat / 100.0 * dt
		if not e.buffs.is_empty() and MountedCombat.arcane_on(e):
			mp_regen *= Balance.ARCANE_REGEN_MULT          # asas do Modo Arcano: regenera menos
		e.mp = minf(e.stats.max_mp, e.mp + mp_regen)
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
			if not e.debuffs.is_empty() and e.has_debuff("cocoon"):
				MobSystem.cocoon_tick(self, e)          # casulo da Rainha: solta quando quebra, aperta quando o tempo acaba
			if e.state == SimEntity.State.STUNNED and e.state_time >= e.state_duration:
				e.set_state(SimEntity.State.IDLE)
		_:
			pass
	if e.kind == SimEntity.Kind.MONSTER and (e.shift_base != null or e.shift_left > 0.0 or not e.monster_def.shift_forms.is_empty()):
		ShiftSystem.update(self, e, dt)          # metamorfose: conjura ao entrar em combate, volta fora dele
	if e.kind == SimEntity.Kind.MONSTER and (not e.monster_def.phases.is_empty() or e.monster_def.berserk_after > 0.0):
		MobSystem.update_boss(self, e, dt)
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
	var h := def.size * 0.5 - Vector2(e.radius, e.radius)        # MapDef.clamp_inside, sem as chamadas
	p = Vector3(clampf(p.x, -h.x, h.x), 0.0, clampf(p.z, -h.y, h.y))
	e.position = MapGeometry.resolve_obstacles(self, p, e.radius, m)

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
	Events.post(&"skill_effect", "dash", e.position, e.position, r)
	for t: SimEntity in m["entities"]:
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
	if (tick_count + e.id) % 20 == 0 or not e.has_meta(&"dorm_seen"):
		e.set_meta(&"dorm_seen", true)
		var r2 := Balance.DORMANT_RANGE * Balance.DORMANT_RANGE
		var near := false
		var at := e.position
		for c: SimEntity in m.get("chars", []):
			if c.position.distance_squared_to(at) < r2:
				near = true
				break
		e.dormant = not near
	return e.dormant

func _index_map(m: Dictionary) -> void:
	var grid := {}
	var chars: Array = []
	for o: SimEntity in m["entities"]:
		if o.state == SimEntity.State.DEAD:
			continue
		var op := o.position
		var k := Vector2i(floori(op.x / SEP_CELL), floori(op.z / SEP_CELL))
		var cell = grid.get(k)
		if cell != null:
			cell.append(o)
		else:
			grid[k] = [o]
		if o.kind != SimEntity.Kind.MONSTER and (o.kind != SimEntity.Kind.NPC or o.guard):      # jogador, bot, invocação, sentinela
			chars.append(o)
	m["sep_grid"] = grid
	m["chars"] = chars

func _separate(e: SimEntity, m: Dictionary) -> void:
	if e.state == SimEntity.State.DASHING or e.spirit:
		return
	var grid = m.get("sep_grid")                 # (sem padrão: `{}` criaria um dicionário por chamada)
	if grid == null or grid.is_empty():
		_separate_from(e, m["entities"])
		return
	var cx := floori(e.position.x / SEP_CELL)
	var cz := floori(e.position.z / SEP_CELL)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var cell = grid.get(Vector2i(cx + dx, cz + dz))
			if cell != null:
				_separate_from(e, cell)          # célula por célula, na mesma ordem (sem montar uma lista por entidade)

func _separate_from(e: SimEntity, near: Array) -> void:
	for o: SimEntity in near:
		var rx: float = e.position.x - o.position.x
		var rz: float = e.position.z - o.position.z
		var min_d: float = e.radius + o.radius
		if absf(rx) >= min_d or absf(rz) >= min_d:
			continue                             # longe (o caso comum): não empurra
		if o == e or not o.is_alive() or o.shade or e.shade or o.spirit:
			continue                             # clone de sombra não empurra nem é empurrado; espírito (anjo) não empurra
		var rel := Vector2(rx, rz)
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
func party_invitable_near(e: SimEntity) -> Array:
	return PartySystem.invitable_near(self, e)
func party_invite_blocked(e: SimEntity) -> String:
	return PartySystem.invite_blocked(self, e)
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
func party_chat_reply(text: String) -> bool:
	return BotChat.party_reply(self, text)
func party_seek_start(e: SimEntity) -> int:
	return PartySystem.party_seek_start(self, e)
func party_take_lead(e: SimEntity) -> bool:
	return PartySystem.party_take_lead(self, e)
func party_plan(e: SimEntity) -> String:
	return BotLeaderSystem.plan_of(self, e)
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
func enhance_error(e: SimEntity, item_id: String, slot: int = -1, smith: String = "") -> String:
	return ItemSystem.enhance_error(self, e, item_id, slot, smith)
func enhance(e: SimEntity, item_id: String, slot: int = -1, smith: String = "") -> ItemDef:
	return ItemSystem.enhance(self, e, item_id, slot, smith)
func equip_bag(e: SimEntity, item_id: String, slot: int = -1) -> bool:
	return ItemSystem.equip_bag(self, e, item_id, slot)

func unequip_bag(e: SimEntity, slot: int) -> bool:
	return ItemSystem.unequip_bag(self, e, slot)
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
func owns_item(e: SimEntity, item_id: String) -> bool:
	return ItemSystem.owns_item(self, e, item_id)
func relic_set_missing(e: SimEntity, set_id: String) -> Array:
	return ItemSystem.relic_set_missing(self, e, set_id)
func relic_set_block_reason(e: SimEntity, set_id: String) -> String:
	return ItemSystem.relic_set_block_reason(self, e, set_id)
func relic_exchange_set(e: SimEntity, set_id: String) -> int:
	return ItemSystem.relic_exchange_set(self, e, set_id)
func relic_default_build(e: SimEntity) -> String:
	return ItemSystem.relic_default_build(self, e)
func main_build(e: SimEntity) -> String:
	return ProgressionSystem.main_build(self, e)
func role_of(e: SimEntity) -> String:
	return ProgressionSystem.role_of(self, e)
func legendary_chance(mob: SimEntity) -> float:
	return ItemSystem.legendary_chance(self, mob)
func _uses_shield(e: SimEntity) -> bool:
	return ItemSystem.uses_shield(self, e)
func bot_legendary_set(e: SimEntity, level: int) -> String:
	return ItemSystem.bot_legendary_set(self, e, level)

func bot_set_weapons(e: SimEntity, sd: SetDef) -> Array:
	return ItemSystem.bot_set_weapons(self, e, sd)
func bot_legendary_accessories(e: SimEntity, level: int) -> Array:
	return ItemSystem.bot_legendary_accessories(self, e, level)
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
## Rank da skill no Mestre de Skills (ouro + materiais da faixa): custo do próximo rank, motivo de não poder ("" = pode), subir.
func skill_rank_cost(e: SimEntity, skill_id: String) -> Dictionary:
	return ProgressionSystem.rank_cost(e, skill_id)
func skill_rank_error(e: SimEntity, skill_id: String) -> String:
	return ProgressionSystem.rank_error(self, e, skill_id)
func skill_rank_up(e: SimEntity, skill_id: String) -> bool:
	return ProgressionSystem.rank_up(self, e, skill_id)
func grant_level_skills(e: SimEntity) -> Array:
	return ProgressionSystem.grant_level_skills(self, e)
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
func _update_boss(e: SimEntity, dt: float = 0.0) -> void:
	MobSystem.update_boss(self, e, dt)
func reset_boss(e: SimEntity) -> void:
	MobSystem.reset_boss(self, e)
# Cristal de retorno
func bind_crystal(e: SimEntity, npc_id: String) -> bool:
	return PortalSystem.bind_crystal(self, e, npc_id)
func home_of(e: SimEntity) -> Dictionary:
	return PortalSystem.home_of(e, self)
func recall_progress(e: SimEntity) -> float:
	return PortalSystem.recall_progress(e)
func recall_blocked(e: SimEntity) -> String:
	return PortalSystem.recall_blocked(self, e)
# RaidSystem
func raid_status(map_id: String) -> Dictionary:
	return RaidSystem.status(self, map_id)
# RoadEventSystem
func road_event_status(map_id: String) -> Dictionary:
	return RoadEventSystem.status(self, map_id)
func road_event_start(map_id: String, point: int = -1) -> Dictionary:
	return RoadEventSystem.start(self, maps[map_id], point) if maps.has(map_id) else {}
# Ascensão / Combate Montado (MountedCombat)
func has_ascension(e: SimEntity) -> bool:
	return ProgressionSystem.has_ascension(e)
## Pontos de ascensão livres (teia de ascensão, aba da janela K).
func asc_points(e: SimEntity) -> int:
	return ProgressionSystem.asc_points(e)
func asc_points_total(e: SimEntity) -> int:
	return ProgressionSystem.asc_points_total(e)
## Por que a skill não sai por causa do cavalo agora ("" = sai). A barra apaga a skill quando não é "".
func mount_block(e: SimEntity, s: SkillDef) -> String:
	return MountedCombat.block_reason(e, s)
func arcane_on(e: SimEntity) -> bool:
	return MountedCombat.arcane_on(e)
# ElementalSystem (ascensão do Elementalista)
## Quadro do elemental no HUD: trocar forma ("" = não muda) e/ou modo ("" = não muda).
func elem_command(e: SimEntity, form: String, mode: String) -> void:
	ElementalSystem.command(self, e, form, mode)
func elemental_of(e: SimEntity) -> SimEntity:
	return ElementalSystem.elemental_of(self, e)
# MountSystem
func mount_unlocked(e: SimEntity, kind: String) -> bool:
	return MountSystem.unlocked(e, kind)
func set_mount_kind(e: SimEntity, kind: String) -> bool:
	return MountSystem.set_kind(self, e, kind)
func gather_ready(node: Dictionary) -> bool:
	return GatherSystem.node_ready(self, node)
# UltimateSystem (Supremas do 40)
## Carga Suprema (0..Balance.ULT_MAX) de `e`.
func ultimate_charge(e: SimEntity) -> float:
	return e.ult_charge
## Suprema que sai agora (build principal + arma da build) ou null.
func ultimate_of(e: SimEntity) -> SkillDef:
	return UltimateSystem.ultimate_of(self, e)
## Suprema da build principal, mesmo sem a arma (moldura do R mostra o ícone apagado).
func ultimate_skill(e: SimEntity) -> SkillDef:
	return UltimateSystem.skill_of(self, e)
func has_ultimate(e: SimEntity) -> bool:
	return UltimateSystem.has_ultimate(e)
## Por que o R está travado ("" = liberado).
func ultimate_lock(e: SimEntity) -> String:
	return UltimateSystem.lock_reason(self, e)
