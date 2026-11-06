class_name ItemSystem
extends RefCounted
## Itens do personagem: equipar/desequipar, poções, aprimoramento no ferreiro, bolsa ampliada, relíquias, baú (storage).

## Tier da peça pelo nível dela (0..3).
static func item_tier(sim: WorldSim, it: ItemDef) -> int:
	var t := 0
	for i in range(Balance.COMMON_TIER_LEVELS.size()):
		if it.level_req >= Balance.COMMON_TIER_LEVELS[i]:
			t = i
	return t

## Custo para levar a peça ao próximo nível: {"gold", "item", "count"}.
static func enhance_cost(sim: WorldSim, it: ItemDef, current: int) -> Dictionary:
	var nxt := current + 1
	var tier := item_tier(sim, it) + (1 if it.is_legendary() else 0)
	if it.is_legendary() and it.level_req == Balance.PLUS_ELF_LEVEL:
		# conjunto da Glória (nível 20): Aço Élfico e, do +6 em diante, Seiva da Árvore-Mãe (Cidade Élfica); ouro mais barato
		var elf_mat := "mother_sap" if nxt >= Balance.PLUS_STAR_FROM else "elf_steel"
		var elf_n := (nxt - Balance.PLUS_STAR_FROM + 1) if nxt >= Balance.PLUS_STAR_FROM else int((nxt + 1) / 2.0) + 1
		return {"gold": int(Balance.PLUS_GOLD_BASE * (tier + 1) * pow(nxt, 1.5) * Balance.PLUS_ELF_GOLD_MULT), "item": elf_mat, "count": elf_n}
	var mat := "star_ore" if nxt >= Balance.PLUS_STAR_FROM else "iron_ore"
	var n := (nxt - Balance.PLUS_STAR_FROM + 1) + tier if nxt >= Balance.PLUS_STAR_FROM else nxt + 1 + tier
	return {"gold": int(Balance.PLUS_GOLD_BASE * (tier + 1) * pow(nxt, 1.5)), "item": mat, "count": n}

## Por que não dá para aprimorar ("" = dá). slot >= 0: a peça vestida nesse slot; senão uma cópia da bolsa.
static func enhance_error(sim: WorldSim, e: SimEntity, item_id: String, slot: int = -1) -> String:
	var it: ItemDef = GameData.items.get(item_id)
	if it == null or not it.is_equipment():
		return "Só equipamento pode ser aprimorado"
	var owned: bool = (e.equipment.get(slot) != null and e.equipment[slot].id == item_id) if slot >= 0 else e.has_item(item_id)
	if not owned:
		return "Você não tem esse item"
	var cur := it.plus
	if cur >= Balance.PLUS_MAX:
		return "Já está no máximo (+%d)" % Balance.PLUS_MAX
	var c := enhance_cost(sim, it, cur)
	if e.gold < int(c["gold"]):
		return "Ouro insuficiente (%d)" % int(c["gold"])
	if not e.has_item(c["item"], int(c["count"])):
		return "Faltam %d %s" % [int(c["count"]) - int(e.inventory.get(c["item"], 0)), GameData.items[c["item"]].name]
	return ""

## Aprimora UMA cópia em +1 (nunca quebra): ela vira a versão "+N" (as outras cópias não mudam).
## slot >= 0: a peça vestida nesse slot; senão uma cópia da bolsa. Devolve a versão nova (ou null).
static func enhance(sim: WorldSim, e: SimEntity, item_id: String, slot: int = -1) -> ItemDef:
	if enhance_error(sim, e, item_id, slot) != "":
		return null
	var it: ItemDef = GameData.items[item_id]
	var base: ItemDef = GameData.items.get(it.base_id, it) if it.base_id != "" else it
	var c := enhance_cost(sim, it, it.plus)
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
	if e == sim.player:
		Events.notification.emit("%s pronto!" % nxt.name)
	return nxt

## Bolsa Ampliada: na ordem (I antes da II...), até Balance.BAG_UPGRADES.
static func use_bag_upgrade(sim: WorldSim, e: SimEntity, item_id: String) -> bool:
	var it: ItemDef = GameData.items.get(item_id)
	if it == null or not it.consume.has("bag") or not e.has_item(item_id):
		return false
	var want := int(it.consume["bag"])
	if want != e.bag_bonus:
		if e == sim.player:
			Events.notification.emit("Use antes a Bolsa Ampliada %s" % ["I", "II", "III", "IV"][mini(e.bag_bonus, 3)] if want > e.bag_bonus else "Sua bolsa já é maior que esta")
		return false
	e.remove_item(item_id, 1)
	e.bag_bonus += 1
	if e == sim.player:
		Events.notification.emit("Bolsa ampliada: %d espaços" % e.bag_capacity())
	return true

## Sorteia se cai lendário para quem matou: cai como Moeda Lendária (chefe/Rei: LEGENDARY_COINS_BOSS moedas).
static func roll_legendary(sim: WorldSim, killer: SimEntity, mob: SimEntity) -> String:
	if killer == null or not killer.is_character():
		return ""
	if sim.rng.randf() >= legendary_chance(sim, mob):
		return ""
	return "legend_coin"            # o lendário vira Moeda Lendária (troca na Relicária: WorldSim.relic_exchange)

## Relicária: peças lendárias que a classe pode trocar (todos os conjuntos das builds, a maça do conjunto e os escudos nomeados).
static func relic_offer(sim: WorldSim, e: SimEntity) -> Array:
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
static func relic_cost(sim: WorldSim, it: ItemDef) -> int:
	var i := Balance.LEGENDARY_LEVELS.find(it.level_req)
	return (i if i >= 0 else Balance.LEGENDARY_LEVELS.size() - 1) + 1

## Por que não troca ("" = pode): perto da Relicária, peça da classe, nível e moedas.
static func relic_block_reason(sim: WorldSim, e: SimEntity, item_id: String) -> String:
	var it: ItemDef = GameData.items.get(item_id)
	if it == null or not (item_id in relic_offer(sim, e)):
		return "peça indisponível para sua classe"
	if not near_station(sim, e, "relic"):
		return "fale com a Relicária"
	if e.level < it.level_req:
		return "requer nível %d" % it.level_req
	var cost := relic_cost(sim, it)
	if int(e.inventory.get("legend_coin", 0)) < cost:
		return "faltam moedas (%d)" % cost
	return ""

## Relicária vende Moeda Lendária por ouro (Balance.LEGEND_COIN_PRICE).
static func buy_legend_coin(sim: WorldSim, e: SimEntity, count: int = 1) -> bool:
	var why := ""
	if not near_station(sim, e, "relic"):
		why = "fale com a Relicária"
	elif e.gold < Balance.LEGEND_COIN_PRICE * count:
		why = "faltam %d de ouro" % (Balance.LEGEND_COIN_PRICE * count - e.gold)
	if why != "":
		if e == sim.player:
			Events.notification.emit("Relicária: " + why)
		return false
	e.gold -= Balance.LEGEND_COIN_PRICE * count
	e.add_item("legend_coin", count)
	return true

static func relic_exchange(sim: WorldSim, e: SimEntity, item_id: String) -> bool:
	var why := relic_block_reason(sim, e, item_id)
	if why != "":
		if e == sim.player:
			Events.notification.emit("Relicária: " + why)
		return false
	e.remove_item("legend_coin", relic_cost(sim, GameData.items[item_id]))
	e.add_item(item_id, 1)
	if e == sim.player:
		Events.notification.emit("★ LENDÁRIO: %s!" % GameData.items[item_id].name)
	return true

## Chance de lendário por monstro: chefe 25%; no primeiro mapa o 1º conjunto cai mais (1 em 50); no resto 1 em 200.
static func legendary_chance(sim: WorldSim, mob: SimEntity) -> float:
	if mob.monster_def.elite_of != "":
		return 1.0
	if mob.monster_def.coin_chance > 0.0:
		return mob.monster_def.coin_chance
	if mob.monster_def.is_boss:
		return Balance.LEGENDARY_DROP_CHANCE_BOSS
	if mob.map_id == Balance.LEGENDARY_START_MAP and mob.level + Balance.LEGENDARY_LEVEL_SLACK < Balance.LEGENDARY_LEVELS[1]:
		return Balance.LEGENDARY_START_MAP_CHANCE
	return Balance.LEGENDARY_DROP_CHANCE

## Só oferece escudo a quem pode usar um com a arma atual (Inquisidor e Cruzado de duas mãos, não).
static func uses_shield(sim: WorldSim, e: SimEntity) -> bool:
	var w: ItemDef = e.equipment.get(ItemDef.Slot.WEAPON)
	if w == null or w.is_two_handed():
		return false
	return e.class_def.builds.any(func(b): return w.weapon_type in b["main"] and "shield" in b["off"])

static func pick_legendary(sim: WorldSim, killer: SimEntity, mob_level: int) -> String:
	var tier_level := 0
	for lv in Balance.LEGENDARY_LEVELS:
		if lv <= mob_level + Balance.LEGENDARY_LEVEL_SLACK:
			tier_level = lv
	if tier_level == 0:
		return ""
	if uses_shield(sim, killer) and sim.rng.randf() < Balance.SHIELD_LEGENDARY_SHARE:
		var shields: Array = GearCatalog.SHIELDS.filter(func(d): return d[2] <= tier_level and GearCatalog.shield_fits("shield_" + d[0], killer.class_def.id))
		if shields.is_empty():
			shields = GearCatalog.SHIELDS.filter(func(d): return d[2] <= tier_level)
		return "shield_" + shields[sim.rng.randi() % shields.size()][0]
	var build_id := ""
	if sim.rng.randf() < 0.7:
		var fits: Array = killer.class_def.builds.filter(func(b): return killer.stats.weapon_type in b["main"])
		if fits.size() > 0:
			build_id = fits[sim.rng.randi() % fits.size()]["id"]
	var pool := GameData.legendary_pool(killer.class_def, tier_level, build_id)
	if pool.is_empty():
		pool = GameData.legendary_pool(killer.class_def, tier_level)
	return pool[sim.rng.randi() % pool.size()] if pool.size() > 0 else ""

static func use_potion(sim: WorldSim, e: SimEntity, slot: int) -> bool:
	if slot < 0 or slot > 2 or e.potion_cd > 0.0:
		return false
	var item_id: String = e.potion_slots[slot]
	if item_id == "" or not e.has_item(item_id):
		if e == sim.player:
			Events.notification.emit("Sem poção nesse slot")
		return false
	var item: ItemDef = GameData.items[item_id]
	e.remove_item(item_id, 1)
	e.potion_cd = item.consume_cooldown
	var c := item.consume
	if c.has("heal"):
		sim._heal(e, e, int(c["heal"]))
	if c.has("heal_pct"):
		sim._heal(e, e, int(e.stats.max_hp * float(c["heal_pct"])))
	if c.has("mana"):
		e.mp = minf(e.stats.max_mp, e.mp + float(c["mana"]))
	if c.has("mana_pct"):
		e.mp = minf(e.stats.max_mp, e.mp + e.stats.max_mp * float(c["mana_pct"]))
	if c.has("buff"):
		sim._apply_effects(e, e, {"buff": c["buff"]}, 1.0)
	Events.potion_used.emit(e.id, slot)
	return true

## Por que `e` não pode equipar `item` (no slot dado); "" = pode.
static func equip_error(sim: WorldSim, e: SimEntity, item: ItemDef, to_offhand: bool = false) -> String:
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
static func equip(sim: WorldSim, e: SimEntity, item_id: String, to_offhand: bool = false, want_slot: int = -1) -> bool:
	var item: ItemDef = GameData.items.get(item_id)
	if item == null or not e.has_item(item_id):
		return false
	var err := equip_error(sim, e, item, to_offhand)
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
		if e == sim.player:
			Events.notification.emit("Arma de duas mãos: a outra mão foi liberada")
	e.recompute_stats()
	Events.equipment_changed.emit(e.id)
	return true

static func unequip(sim: WorldSim, e: SimEntity, slot: int) -> void:
	if e.equipment.has(slot) and e.equipment[slot] != null:
		e.add_item(e.equipment[slot].id, 1)
		e.equipment.erase(slot)
		e.recompute_stats()
		Events.equipment_changed.emit(e.id)

static func first_free_slot(sim: WorldSim, e: SimEntity) -> int:
	for i in range(e.skills.size()):
		if e.skills[i] == null:
			return i
	return -1

## Depósito: só perto de um NPC com o papel (Balance.STATION_RANGE).
static func near_station(sim: WorldSim, e: SimEntity, role: String) -> bool:
	if not sim.maps.has(e.map_id):
		return false
	for n in sim.maps[e.map_id]["def"].npcs:
		if n.get("role", "") == role and Vector2(n["pos"].x, n["pos"].z).distance_to(Vector2(e.position.x, e.position.z)) <= Balance.STATION_RANGE:
			return true
	return false

## Guarda `count` do item da bolsa no depósito (equipado não entra; tipos limitados a STORAGE_SLOTS).
static func storage_deposit(sim: WorldSim, e: SimEntity, item_id: String, count: int = 1) -> bool:
	if count <= 0 or not e.has_item(item_id, count) or not near_station(sim, e, "storage"):
		return false
	if not e.storage.has(item_id) and e.storage.size() >= Balance.STORAGE_SLOTS:
		if e == sim.player:
			Events.notification.emit("Depósito cheio (%d tipos de item)." % Balance.STORAGE_SLOTS)
		return false
	e.remove_item(item_id, count)
	e.storage[item_id] = int(e.storage.get(item_id, 0)) + count
	return true

static func storage_withdraw(sim: WorldSim, e: SimEntity, item_id: String, count: int = 1) -> bool:
	if count <= 0 or int(e.storage.get(item_id, 0)) < count or not near_station(sim, e, "storage"):
		return false
	e.storage[item_id] = int(e.storage[item_id]) - count
	if int(e.storage[item_id]) <= 0:
		e.storage.erase(item_id)
	e.add_item(item_id, count)
	return true
