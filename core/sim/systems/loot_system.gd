class_name LootSystem
extends RefCounted
## Abate de monstro: XP/ouro/loot dividido, quem saqueia, elites, sorteio de equipamento por tier, coleta do baú no chão.

static func on_monster_killed(sim: WorldSim, mob: SimEntity, killer: SimEntity) -> void:
	var m: Dictionary = sim.maps[mob.map_id]
	if mob.monster_def.last_words != "":
		MobSystem.boss_say(sim, mob, mob.monster_def.last_words)
	# XP para quem mais bateu (grupo soma) + dono da invocação
	var credit := top_damager(sim, mob, killer)
	if credit and credit.is_character():
		# XP dividida com o grupo por perto (+bônus por membro); cada um ganha conforme o próprio nível
		var sharers := PartySystem.kill_sharers(sim, credit, mob)
		var each := mob.monster_def.xp * (1.0 + Balance.PARTY_XP_BONUS * (sharers.size() - 1)) / sharers.size()
		for c in sharers:
			var mult := clampf(1.0 + (mob.level - c.level) * 0.08, 0.3, 1.6)
			ProgressionSystem.gain_xp(sim, c, int(each * mult))
			QuestSystem.on_kill(c, mob.monster_def.elite_of if mob.monster_def.elite_of != "" else mob.monster_def.id)
			if mob.monster_def.is_boss:
				c.bosses_killed[mob.monster_def.id] = true
				if c == sim.player:
					BotChat.party_event(sim, c, "boss_kill", {"boss": mob.monster_def.name})
		# loot
		var lt: LootTable = GameData.loot_tables.get(mob.monster_def.loot_table)
		var gold := sim.rng.randi_range(mob.monster_def.gold_min, mob.monster_def.gold_max) * (3 if mob.monster_def.is_boss else 1)
		var drops := {}
		if lt:
			drops = lt.roll(sim.rng)
		if gold > 0 and sharers.size() > 1:
			split_gold(sim, sharers, gold)
		elif gold > 0:
			drops["gold"] = gold
		# jogador no grupo: o saque dele é pessoal (rola a tabela só para ele a cada abate dividido, mesmo sem ter batido:
		# suporte também ganha); o saque comum gira entre os bots. Sem jogador no grupo, gira entre todos.
		var with_player: bool = sim.player != null and sim.player in sharers and sharers.size() > 1
		var bots_share: Array = sharers.filter(func(c): return c.kind != SimEntity.Kind.PLAYER)
		var mine := {}
		if with_player and mob.boss_id < 0:
			if lt:
				mine = lt.roll(sim.rng)
			var my_worn := roll_gear(sim, sim.player, mob)
			if my_worn != "":
				mine[my_worn] = 1
		var looter := next_looter(sim, credit, bots_share if with_player and not bots_share.is_empty() else sharers)
		if with_player and looter == sim.player:
			drops.clear()                       # o jogador já recebeu o seu
		var worn := roll_gear(sim, looter, mob) if mob.boss_id < 0 and looter != sim.player else ""      # lacaio de chefe não é fonte de saque
		if worn != "":
			drops[worn] = 1
		var personal: Array = []                 # lendário é pessoal: cada um rola o seu (o grupo não divide a chance)
		if mob.boss_id < 0:
			for c in sharers:
				var leg := ItemSystem.roll_legendary(sim, c, mob)
				if leg == "":
					continue
				var coins: int = Balance.LEGENDARY_COINS_BOSS if mob.monster_def.is_boss else 1
				if mob.monster_def.coin_max > 0:           # Rei Élfico / Guardião: punhado de moedas (uma peça da Glória)
					coins = sim.rng.randi_range(mob.monster_def.coin_min, mob.monster_def.coin_max)
				personal.append([leg, c, coins])
				if c == sim.player:
					Events.post(&"notification", "✦ %d Moeda%s Lendária%s! Troque com a Relicária em Aldara" % [coins, "s" if coins > 1 else "", "s" if coins > 1 else ""])
					BotChat.party_event(sim, c, "loot_legend")
				elif c.kind == SimEntity.Kind.BOT:
					Events.post(&"chat_message", c.name, "DROPOU MOEDA LENDÁRIA!!!", "global")
		var i := 0
		for item_id in drops:
			drop(m, mob, i, 0.5, item_id, int(drops[item_id]), 45.0, looter.id, sim.time + Balance.LOOT_LOCK_TIME)
			i += 1
		for item_id in mine:                   # saque pessoal do jogador no grupo
			drop(m, mob, i, 0.6, item_id, int(mine[item_id]), 60.0, sim.player.id, sim.time + Balance.LOOT_LOCK_TIME * 2.0)
			i += 1
		for pl in personal:                     # lendário fica preso ao dono por mais tempo (ninguém pega o seu)
			drop(m, mob, i, 0.6, pl[0], int(pl[2]), 120.0, pl[1].id, sim.time + 110.0)
			i += 1
	# remove do spawner
	for sp in m["spawners"]:
		sp["alive"].erase(mob.id)
	if credit and credit.is_character():
		count_kill(sim, m, mob)
		LegendEffects.legend_on_kill(sim, credit, mob)

## Muitos abates do mesmo monstro comum num mapa: surge o Rei dele (5x mais forte, lendário garantido).
## Baú no chão em volta do monstro (`i` = posição na roda; `free_at` = quando qualquer um pode pegar).
static func drop(m: Dictionary, mob: SimEntity, i: int, ring: float, item_id: String, count: int, timer: float, owner_id: int, free_at: float) -> void:
	var off := Vector3(cos(i * 1.7) * ring, 0.0, sin(i * 1.7) * ring)
	m["loot"].append({"pos": mob.position + off, "item": item_id, "count": count, "timer": timer, "owner": owner_id, "free_at": free_at})
	Events.post(&"loot_dropped", mob.map_id, mob.position + off, item_id, count)

static func count_kill(sim: WorldSim, m: Dictionary, mob: SimEntity) -> void:
	var md: MonsterDef = mob.monster_def
	if md.is_boss or md.elite_of != "" or md.xp <= 0 or mob.boss_id >= 0 or mob.kind != SimEntity.Kind.MONSTER:
		return
	var n: int = int(m["kills"].get(md.id, 0)) + 1
	var alive: SimEntity = sim.entities.get(int(m["elites"].get(md.id, -1)))
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
		pos = spots[sim.rng.randi() % spots.size()]["def"]["pos"]
	var king := sim.spawn_monster(elite_def(sim, md), mob.map_id, pos)
	m["elites"][md.id] = king.id
	var where: String = m["def"].name
	Events.post(&"chat_message", "Sistema", "%s surgiu em %s! (lendário garantido)" % [king.monster_def.name, where], "system")
	if sim.player and sim.player.map_id == mob.map_id:
		Events.post(&"notification", "👑 %s surgiu!" % king.monster_def.name)

## Rei de um monstro comum (criado uma vez por tipo): mais vida, ataque e tamanho; a coroa é da apresentação (EntityView).
static func elite_def(sim: WorldSim, base: MonsterDef) -> MonsterDef:
	if sim._elite_defs.has(base.id):
		return sim._elite_defs[base.id]
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
	d.radius = base.radius * Balance.ELITE_RADIUS_MULT
	d.xp = base.xp * Balance.ELITE_XP_MULT
	d.gold_min = base.gold_min * Balance.ELITE_GOLD_MULT
	d.gold_max = base.gold_max * Balance.ELITE_GOLD_MULT
	d.is_boss = true
	d.leash_range = maxf(base.leash_range, Balance.ELITE_LEASH_MIN)
	sim._elite_defs[base.id] = d
	return d

## Quem mais causou dano e segue vivo no mapa: invocações contam para o dono e o grupo soma, para ninguém
## de fora roubar o abate de um grupo. Dentro do grupo vencedor, o maior dano leva o crédito.
static func top_damager(sim: WorldSim, mob: SimEntity, killer: SimEntity) -> SimEntity:
	var by_group := {}
	var best_of := {}
	for id in mob.damage_by:
		var o: SimEntity = sim.entities.get(id)
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
	return sim.entities.get(killer.owner_id) if killer and killer.kind == SimEntity.Kind.SUMMON else killer

## Saque do grupo gira entre quem dividiu o abate; sozinho, fica com quem matou.
static func next_looter(sim: WorldSim, credit: SimEntity, sharers: Array) -> SimEntity:
	if sharers.size() < 2:
		return credit
	var p := PartySystem.party_of(sim, credit)
	var i := int(p.get("loot_next", 0))
	p["loot_next"] = i + 1
	var order: Array = PartySystem.party_members(sim, credit).filter(func(o): return o in sharers)    # ordem do grupo: não muda com quem levou o abate
	return order[i % order.size()]

## O que o jogador enxerga no chão: o que é dele, ou o que ficou livre (o dono não pegou a tempo).
static func loot_visible_to(sim: WorldSim, e: SimEntity, l: Dictionary) -> bool:
	return e == null or int(l.get("owner", -1)) == e.id or int(l.get("owner", -1)) < 0 or sim.time >= float(l.get("free_at", 0.0))

## Ouro do grupo vai direto para cada um, sem pilha no chão para disputar.
static func split_gold(sim: WorldSim, sharers: Array, gold: int) -> void:
	var each := gold / sharers.size()
	var extra := gold % sharers.size()     # o resto vai um por um: nada some, nada é criado
	for i in range(sharers.size()):
		var share := each + (1 if i < extra else 0)
		sharers[i].gold += share
		if sharers[i] == sim.player and share > 0:
			Events.post(&"notification", "+%d ouro (grupo)" % share)

## Calça/capa/amuleto/anel comum do maior tier que o nível do monstro alcança. Tiers baixos também estão na loja.
static func roll_gear(sim: WorldSim, killer: SimEntity, mob: SimEntity) -> String:
	if killer == null or not killer.is_character():
		return ""
	if sim.rng.randf() >= (Balance.GEAR_DROP_CHANCE_BOSS if mob.monster_def.is_boss else Balance.GEAR_DROP_CHANCE):
		return ""
	var tier := 0
	for i in range(Balance.COMMON_TIER_LEVELS.size()):
		if Balance.COMMON_TIER_LEVELS[i] <= mob.level + Balance.LEGENDARY_LEVEL_SLACK:
			tier = i
	var pool: Array = gear_pool(sim, tier).filter(func(it): return fits_class(sim, killer, it))
	if pool.is_empty():
		pool = GearCatalog.wearables(tier)
	return pool[sim.rng.randi() % pool.size()].id

## Equipamento comum que cai de monstro no tier (armas, escudos, armaduras e calças; joias e capas são feitas na forja).
static func gear_pool(sim: WorldSim, tier: int) -> Array:
	if sim._gear_pools.has(tier):
		return sim._gear_pools[tier]
	var lo: int = Balance.COMMON_TIER_LEVELS[tier]
	var hi: int = Balance.COMMON_TIER_LEVELS[tier + 1] if tier + 1 < Balance.COMMON_TIER_LEVELS.size() else 99
	var out: Array = []
	for iid in GameData.items:
		var it: ItemDef = GameData.items[iid]
		if it.is_equipment() and not it.is_legendary() and it.set_id == "" and it.base_id == "" and it.price > 0 and it.level_req >= lo and it.level_req < hi \
				and not (it.slot in [ItemDef.Slot.CAPE, ItemDef.Slot.AMULET, ItemDef.Slot.RING]):
			out.append(it)
	sim._gear_pools[tier] = out
	return out

## A classe consegue usar (sem olhar o nível).
static func fits_class(sim: WorldSim, e: SimEntity, it: ItemDef) -> bool:
	if it.class_restriction.size() > 0 and not (e.class_def.id in it.class_restriction):
		return false
	if it.slot == ItemDef.Slot.WEAPON:
		return it.weapon_type in e.class_def.weapon_types
	if it.slot == ItemDef.Slot.OFFHAND:
		return it.weapon_type in e.class_def.offhand_types
	return true

static func update_loot(sim: WorldSim, m: Dictionary, dt: float) -> void:
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
			if dx * dx + dz * dz > 0.81 or not e.is_character() or not e.is_alive() or not can_loot(sim, e, l):
				continue
			if e == sim.player and l["item"] != "gold" and e.bag_full_for(l["item"]):
				if sim.time >= e.portal_notice_at:
					e.portal_notice_at = sim.time + Balance.NOTICE_CD
					Events.post(&"notification", "Bolsa cheia (%d/%d): libere espaço ou amplie a bolsa" % [e.inventory.size(), e.bag_capacity()])
				continue
			pickup(sim, e, l)
			loot.erase(l)
			break

static func can_loot(sim: WorldSim, e: SimEntity, l: Dictionary) -> bool:
	return e.id == int(l.get("owner", -1)) or sim.time >= float(l.get("free_at", 0.0))

static func pickup(sim: WorldSim, e: SimEntity, l: Dictionary) -> void:
	if l["item"] == "gold":
		e.gold += int(l["count"])
		if e == sim.player:
			Events.post(&"notification", "+%d ouro" % int(l["count"]))
	else:
		e.add_item(l["item"], int(l["count"]))
		QuestSystem.on_item_changed(e, l["item"])
		if e == sim.player:
			var it: ItemDef = GameData.items.get(l["item"])
			Events.post(&"notification", "+%d %s" % [int(l["count"]), it.name if it else l["item"]])
			if it and it.rarity >= 2 and e.party_id >= 0:             # raro ou melhor: o grupo comenta
				BotChat.party_event(sim, e, "loot", {"item": it.name}, null, 0.6)
