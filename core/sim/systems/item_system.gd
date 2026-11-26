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
	if kharzun_tier(it):
		# lendários 40/45 (Monte Kharzun, D11): Aço Anão e, do +6 em diante, Brasa de Kharzun; só no Ferreiro Anão
		var kh_mat: String = Balance.PLUS_KHARZUN_EMBER if nxt >= Balance.PLUS_STAR_FROM else Balance.PLUS_KHARZUN_STEEL
		var kh_n := (nxt - Balance.PLUS_STAR_FROM + 1) if nxt >= Balance.PLUS_STAR_FROM else int((nxt + 1) / 2.0) + 1
		return {"gold": int(Balance.PLUS_GOLD_BASE * (tier + 1) * pow(nxt, 1.5) * Balance.PLUS_KHARZUN_GOLD_MULT), "item": kh_mat, "count": kh_n}
	if it.is_legendary() and it.level_req >= Balance.PLUS_DAWN_LEVEL:
		# lendários 25/30 (terceiro andar): Prata Consagrada e, do +6 em diante, Fragmento da Aurora
		var dawn_mat := "dawn_shard" if nxt >= Balance.PLUS_STAR_FROM else "holy_silver"
		var dawn_n := (nxt - Balance.PLUS_STAR_FROM + 1) if nxt >= Balance.PLUS_STAR_FROM else int((nxt + 1) / 2.0) + 1
		return {"gold": int(Balance.PLUS_GOLD_BASE * (tier + 1) * pow(nxt, 1.5) * Balance.PLUS_DAWN_GOLD_MULT), "item": dawn_mat, "count": dawn_n}
	var mat := "star_ore" if nxt >= Balance.PLUS_STAR_FROM else "iron_ore"
	var n := (nxt - Balance.PLUS_STAR_FROM + 1) + tier if nxt >= Balance.PLUS_STAR_FROM else nxt + 1 + tier
	return {"gold": int(Balance.PLUS_GOLD_BASE * (tier + 1) * pow(nxt, 1.5)), "item": mat, "count": n}

## Lendário 40+ (Monte Kharzun): aprimora só no Ferreiro Anão, com Aço Anão e Brasa de Kharzun.
static func kharzun_tier(it: ItemDef) -> bool:
	return it != null and it.is_legendary() and it.level_req >= Balance.PLUS_KHARZUN_LEVEL

## Por que não dá para aprimorar ("" = dá). slot >= 0: a peça vestida nesse slot; senão uma cópia da bolsa.
## smith = id do NPC ferreiro (a janela passa o dela); lendário 40+ só em Balance.PLUS_KHARZUN_SMITHS.
static func enhance_error(sim: WorldSim, e: SimEntity, item_id: String, slot: int = -1, smith: String = "") -> String:
	var it: ItemDef = GameData.items.get(item_id)
	if it == null or not it.is_equipment():
		return "Só equipamento pode ser aprimorado"
	if kharzun_tier(it) and not smith in Balance.PLUS_KHARZUN_SMITHS:
		return "Só o Ferreiro Anão Thrain (Monte Kharzun) aprimora lendário de nível %d+" % Balance.PLUS_KHARZUN_LEVEL
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
static func enhance(sim: WorldSim, e: SimEntity, item_id: String, slot: int = -1, smith: String = "") -> ItemDef:
	if enhance_error(sim, e, item_id, slot, smith) != "":
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
	Events.post(&"equipment_changed", e.id)
	if e == sim.player:
		Events.post(&"notification", "%s pronto!" % nxt.name)
	return nxt

## Espaços que uma bolsa soma vestida (Balance.BAG_SIZES pelo tier em `consume.bag`); 0 = não é bolsa / vaga vazia.
static func bag_size(item_id: String) -> int:
	if item_id == "":
		return 0
	var it: ItemDef = GameData.items.get(item_id)
	if it == null or not it.consume.has("bag"):
		return 0
	return int(Balance.BAG_SIZES[clampi(int(it.consume["bag"]), 0, Balance.BAG_SIZES.size() - 1)])

## Pilhas na bolsa depois de trocar a vaga `slot` de `old` para `new` ("" = vazia): a nova sai da bolsa, a velha entra.
static func _stacks_after(e: SimEntity, old: String, new: String) -> int:
	var n := e.inventory.size()
	if new != "" and int(e.inventory.get(new, 0)) == 1:
		n -= 1
	if old != "" and not (e.inventory.has(old) and (old != new or int(e.inventory[old]) > 1)):
		n += 1
	return n

## Veste a bolsa `item_id` (da bolsa) na vaga `slot` (-1 = primeira vazia). Vaga ocupada = troca (a velha volta para
## a bolsa). Recusa se a capacidade nova não comporta o que você carrega.
static func equip_bag(sim: WorldSim, e: SimEntity, item_id: String, slot: int = -1) -> bool:
	var size := bag_size(item_id)
	if size <= 0 or not e.has_item(item_id):
		return false
	if slot < 0:
		slot = e.bags.find("")
		if slot < 0:
			_bag_note(sim, e, "As %d vagas de bolsa estão ocupadas: arraste a bolsa sobre uma vaga para trocar" % Balance.BAG_SLOTS)
			return false
	if slot >= e.bags.size():
		return false
	var old := str(e.bags[slot])
	if old == item_id:
		return false
	if _stacks_after(e, old, item_id) > e.bag_capacity() - bag_size(old) + size:
		_bag_note(sim, e, "Libere espaço antes: os itens não caberiam")
		return false
	e.remove_item(item_id, 1)
	e.bags[slot] = item_id
	if old != "":
		e.add_item(old, 1)
	_bag_note(sim, e, "Bolsa: %d espaços" % e.bag_capacity())
	Events.post(&"equipment_changed", e.id)
	return true

## Tira a bolsa da vaga `slot` (volta para a bolsa). Recusa se o que você carrega não caberia sem ela.
static func unequip_bag(sim: WorldSim, e: SimEntity, slot: int) -> bool:
	if slot < 0 or slot >= e.bags.size() or str(e.bags[slot]) == "":
		return false
	var old := str(e.bags[slot])
	if _stacks_after(e, old, "") > e.bag_capacity() - bag_size(old):
		_bag_note(sim, e, "Libere espaço antes: os itens não caberiam sem esta bolsa")
		return false
	e.bags[slot] = ""
	e.add_item(old, 1)
	_bag_note(sim, e, "Bolsa: %d espaços" % e.bag_capacity())
	Events.post(&"equipment_changed", e.id)
	return true

static func _bag_note(sim: WorldSim, e: SimEntity, text: String) -> void:
	if e == sim.player:
		Events.post(&"notification", text)

## Sorteia se cai lendário para quem matou: cai como Moeda Lendária (chefe/Rei: LEGENDARY_COINS_BOSS moedas).
static func roll_legendary(sim: WorldSim, killer: SimEntity, mob: SimEntity) -> String:
	if killer == null or not killer.is_character():
		return ""
	if sim.rng.randf() >= minf(1.0, legendary_chance(sim, mob) * LootSystem.drop_mult(killer)):     # Elixir da Fortuna
		return ""
	return "legend_coin"            # o lendário vira Moeda Lendária (troca na Relicária: WorldSim.relic_exchange)

## Relicária: peças lendárias que a classe pode trocar (todos os conjuntos das builds, a maça do conjunto e os escudos nomeados).
static func relic_offer(sim: WorldSim, e: SimEntity) -> Array:
	var out: Array = []
	for lv in relic_levels():
		for iid in GameData.legendary_pool(e.class_def, lv):
			if not (iid in out):
				out.append(iid)
	if "shield" in e.class_def.offhand_types:
		for iid in GameData.items:
			var it: ItemDef = GameData.items[iid]
			if it.is_legendary() and it.weapon_type == "shield" and it.set_id == "" and (it.class_restriction.is_empty() or e.class_def.id in it.class_restriction) 					and GearCatalog.shield_fits(iid, e.class_def.id):
				out.append(iid)
	return out

## Preço em moedas: tier i de LEGENDARY_LEVELS custa i+1 (nível 5 = 1, nível 10 = 2, ...).
static func relic_cost(sim: WorldSim, it: ItemDef) -> int:
	return Balance.legend_tier(it.level_req) + 1

## Níveis que a Relicária troca: os lendários e os híbridos que o MAX_LEVEL alcança.
static func relic_levels() -> Array:
	var out: Array = Balance.LEGENDARY_LEVELS.duplicate()
	for lv in Balance.HYBRID_LEVELS:
		if lv <= Balance.MAX_LEVEL and not (lv in out):
			out.append(lv)
	return out

## Bot escolhendo lendário (R7.1, AC-32c): no nível dos híbridos, o par que inclui a build dele, com a outra build que
## a teia dele mais comprou (empate: a ordem dos pares). Abaixo do 35, ou sem híbrido, o conjunto da build. "" = nenhum.
static func bot_legendary_set(sim: WorldSim, e: SimEntity, level: int) -> String:
	if e.class_def == null or e.build_id == "":
		return ""
	var apex: SetDef = GameData.apex_set_for(e.class_def, e.build_id, level)
	if apex:                          # R-AP6: Ápice da build primeiro (Guardião/Templário -> P3, Sacerdote/Batalha -> Bi3 pela regra abaixo)
		return apex.id
	var hyb: Array = GameData.hybrid_sets_for(e.class_def, e.build_id, level)
	if hyb.is_empty():
		var sd: SetDef = GameData.sets.get(GameData.set_id_for(e.class_def.id, e.build_id, level))
		return sd.id if sd else ""
	var nodes: Dictionary = ProgressionSystem.tree_of(sim, e)["nodes"]
	var bought := {}
	for nid in e.tree:
		var br: String = str(nodes.get(nid, {}).get("branch", ""))
		bought[br] = int(bought.get(br, 0)) + 1
	var best: SetDef = null
	var best_n := -1
	for sd: SetDef in hyb:
		var other: String = sd.pair[1] if sd.pair[0] == e.build_id else sd.pair[0]
		var n := int(bought.get(other, 0))
		if n > best_n:
			best_n = n
			best = sd
	return best.id

## Armas do conjunto `sd` que o bot veste, pelo papel da build (GearCatalog.WEAPON_ROLES): tanque fica com a de defesa
## (maça/martelo, Baluarte), dps com a de ataque (espada/montante); sem papel, a arma principal da build. No híbrido, a da
## própria build vem antes. + o escudo/mão secundária da build no conjunto. Ex.: Guardião 30 -> [maça, escudo].
static func bot_set_weapons(sim: WorldSim, e: SimEntity, sd: SetDef) -> Array:
	var out: Array = []
	if e.class_def == null or e.build_id == "" or sd == null:
		return out
	var b: Dictionary = e.class_def.build_by_id(e.build_id)
	var want := "defense" if str(b.get("role", "")) == "tank" else "offense"
	var best := ""
	var best_n := -1
	var off := ""
	for iid in sd.pieces + sd.alt_pieces:
		var it: ItemDef = GameData.items.get(iid)
		if it == null or not (it.slot in [ItemDef.Slot.WEAPON, ItemDef.Slot.OFFHAND]):
			continue
		var own: bool = sd.pair.is_empty() or str(iid).ends_with("_%s_weapon" % e.build_id) or str(iid).ends_with("_%s_offhand" % e.build_id)
		if it.slot == ItemDef.Slot.OFFHAND or str(iid).ends_with("_offhand"):
			if b.get("off", []).has(it.weapon_type) and (off == "" or own):
				off = iid
			continue
		if not b.get("main", []).has(it.weapon_type):
			continue
		var n := 0
		var role_bid := e.build_id          # híbrido: a arma "_<build>_weapon" tem o papel da build dona (martelo do Templário ataca)
		for pb in sd.pair:
			if str(iid).ends_with("_%s_weapon" % pb):
				role_bid = pb
		var role := GearCatalog.weapon_role(role_bid, it.weapon_type)
		if role == want or (role != "" and want == "offense" and role == "battle"):
			n += 4
		elif role == "":
			n += 2 if it.weapon_type == str(b["main"][0]) else 1
		if own:
			n += 1
		if n > best_n:
			best_n = n
			best = iid
	if best != "":
		out.append(best)
	if off != "":
		out.append(off)
	return out

const LEG_ACC_PREFIX := "leg_acc_"

## Acessórios lendários da build do bot (sonda de chefe; bots do mundo não vestem lendário): os 4 do maior nível de
## Balance.ACT2_SET_LEVELS <= level (Anel em RING, Sinete em RING2). Vazio abaixo do 35 ou sem build.
## Ex.: bot_legendary_accessories(sim, executor, 44) = os 4 `leg_acc_berserker_executor_40_*`.
static func bot_legendary_accessories(sim: WorldSim, e: SimEntity, level: int) -> Array:
	if e.class_def == null or e.build_id == "":
		return []
	var lv := 0
	for h in Balance.ACT2_SET_LEVELS:
		if h <= level:
			lv = h
	if lv == 0:
		return []
	return GameData.legendary_accessory_pool(e.class_def, lv, e.build_id)

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
			Events.post(&"notification", "Relicária: " + why)
		return false
	e.gold -= Balance.LEGEND_COIN_PRICE * count
	e.add_item("legend_coin", count)
	return true

static func relic_exchange(sim: WorldSim, e: SimEntity, item_id: String) -> bool:
	var why := relic_block_reason(sim, e, item_id)
	if why != "":
		if e == sim.player:
			Events.post(&"notification", "Relicária: " + why)
		return false
	e.remove_item("legend_coin", relic_cost(sim, GameData.items[item_id]))
	e.add_item(item_id, 1)
	if e == sim.player:
		Events.post(&"notification", "★ LENDÁRIO: %s!" % GameData.items[item_id].name)
	return true

## Já tem a peça (vestida, na bolsa ou no depósito; a versão aprimorada +N conta).
static func owns_item(sim: WorldSim, e: SimEntity, item_id: String) -> bool:
	for sl in e.equipment:
		var it: ItemDef = e.equipment[sl]
		if it and (it.id == item_id or it.base_id == item_id):
			return true
	for bag in [e.inventory, e.storage]:
		for iid in bag:
			var it: ItemDef = GameData.items.get(iid)
			if iid == item_id or (it and it.base_id == item_id):
				return true
	return false

## Relicária: peças de ARMADURA do conjunto que ainda faltam (arma, maça e escudo trocam à parte).
static func relic_set_missing(sim: WorldSim, e: SimEntity, set_id: String) -> Array:
	var sd: SetDef = GameData.sets.get(set_id)
	if sd == null:
		return []
	return sd.armor.filter(func(pid): return not owns_item(sim, e, pid))

## Por que não troca o conjunto de uma vez ("" = pode): mesmas regras da peça, moedas para todas as que faltam.
static func relic_set_block_reason(sim: WorldSim, e: SimEntity, set_id: String) -> String:
	var missing := relic_set_missing(sim, e, set_id)
	if missing.is_empty():
		return "você já tem as peças do conjunto"
	var why := relic_block_reason(sim, e, missing[0])
	if why.begins_with("faltam moedas") or why == "":
		var cost := relic_cost(sim, GameData.items[missing[0]]) * missing.size()
		if int(e.inventory.get("legend_coin", 0)) < cost:
			return "faltam moedas (%d)" % cost
		return ""
	return why

## Troca todas as peças de armadura que faltam do conjunto (moedas × peças). Devolve quantas trocou.
static func relic_exchange_set(sim: WorldSim, e: SimEntity, set_id: String) -> int:
	var why := relic_set_block_reason(sim, e, set_id)
	if why != "":
		if e == sim.player:
			Events.post(&"notification", "Relicária: " + why)
		return 0
	var missing := relic_set_missing(sim, e, set_id)
	e.remove_item("legend_coin", relic_cost(sim, GameData.items[missing[0]]) * missing.size())
	for pid in missing:
		e.add_item(pid, 1)
	if e == sim.player:
		Events.post(&"notification", "★ LENDÁRIO: %s (%d peça%s)!" % [GameData.sets[set_id].name, missing.size(), "s" if missing.size() > 1 else ""])
	return missing.size()

## Build da aba inicial da Relicária: a principal do personagem (ProgressionSystem.main_build).
static func relic_default_build(sim: WorldSim, e: SimEntity) -> String:
	return ProgressionSystem.main_build(sim, e)

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
	var accs := GameData.legendary_accessory_pool(killer.class_def, tier_level, build_id)
	if accs.size() > 0 and sim.rng.randf() < Balance.LEG_ACC_DROP_SHARE:     # acessório lendário: fatia própria (não dilui o conjunto)
		return accs[sim.rng.randi() % accs.size()]
	var pool := GameData.legendary_pool(killer.class_def, tier_level, build_id).filter(func(i): return not str(i).begins_with(LEG_ACC_PREFIX))
	if pool.is_empty():
		pool = GameData.legendary_pool(killer.class_def, tier_level).filter(func(i): return not str(i).begins_with(LEG_ACC_PREFIX))
	return pool[sim.rng.randi() % pool.size()] if pool.size() > 0 else ""

static func use_potion(sim: WorldSim, e: SimEntity, slot: int) -> bool:
	if slot < 0 or slot > 2 or e.potion_cds[slot] > 0.0:
		return false
	var item_id: String = e.potion_slots[slot]
	if item_id == "" or not e.has_item(item_id):
		if e == sim.player:
			Events.post(&"notification", "Sem poção nesse slot")
		return false
	var item: ItemDef = GameData.items[item_id]
	if item.consume.get("buff") is Dictionary and HuntPotionSystem.weaker(e, item.consume["buff"]):
		if e == sim.player:                 # Poção de Caça mais fraca que a ativa: recusa, não gasta (decisão 2026-11-26)
			Events.post(&"notification", "Você já está sob um efeito mais forte")
		return false
	e.remove_item(item_id, 1)
	e.potion_cds[slot] = item.consume_cooldown          # recarga só deste atalho (F1/F2/F3 são independentes)
	var c := item.consume
	if c.has("heal"):
		sim.ult_quiet = true                 # poção não enche a Carga Suprema
		sim._heal(e, e, int(c["heal"]))
		sim.ult_quiet = false
	if c.has("heal_pct"):
		sim.ult_quiet = true
		sim._heal(e, e, int(e.stats.max_hp * float(c["heal_pct"])))
		sim.ult_quiet = false
	if c.has("mana"):
		e.mp = minf(e.stats.max_mp, e.mp + float(c["mana"]))
	if c.has("mana_pct"):
		e.mp = minf(e.stats.max_mp, e.mp + e.stats.max_mp * float(c["mana_pct"]))
	if c.has("buff"):
		sim._apply_effects(e, e, {"buff": c["buff"]}, 1.0)
	Events.post(&"potion_used", e.id, slot)
	return true

# ------------------------------------------------------------------ auto-poção (GDD design/gdd/auto-pocao.md)
## Linhas da auto-poção: [chave do liga/desliga, chave da vaga, bit do aviso, nome no aviso].
const AUTO_LINES := [["hp_on", "hp_slot", 1, "vida"], ["mp_on", "mp_slot", 2, "mana"], ["elx_on", "elx_slot", 4, "elixir"]]

## Padrões de personagem novo / save antigo (§3.1): tudo desligado, % e vagas do Balance.
static func auto_potion_defaults() -> Dictionary:
	return {"hp_on": false, "hp_slot": Balance.AUTO_POTION_HP_SLOT, "hp_pct": Balance.AUTO_POTION_HP_DEFAULT,
		"mp_on": false, "mp_slot": Balance.AUTO_POTION_MP_SLOT, "mp_pct": Balance.AUTO_POTION_MP_DEFAULT,
		"elx_on": false, "elx_slot": Balance.AUTO_POTION_ELX_SLOT}

## Configuração completa de `e` (cópia; campo vazio = padrão). A interface e o save leem por aqui.
static func auto_potion_config(e: SimEntity) -> Dictionary:
	var cfg := auto_potion_defaults()
	for k in e.auto_potion:
		if cfg.has(k):
			cfg[k] = e.auto_potion[k]
	return cfg

## % saneado: entre AUTO_POTION_PCT_MIN/MAX, no passo AUTO_POTION_PCT_STEP.
static func auto_potion_pct(v: int) -> int:
	var st := Balance.AUTO_POTION_PCT_STEP
	return clampi(int(round(float(v) / st)) * st, Balance.AUTO_POTION_PCT_MIN, Balance.AUTO_POTION_PCT_MAX)

## Muda só as chaves dadas (as que não existem são ignoradas), saneia e zera os avisos. Devolve a configuração nova.
## Ex.: `Sim.set_auto_potion(p, {"hp_on": true, "hp_pct": 45})`.
static func set_auto_potion(e: SimEntity, changes: Dictionary) -> Dictionary:
	var cfg := auto_potion_config(e)
	for k in changes:
		if not cfg.has(k):
			continue
		var key: String = k
		if key.ends_with("_on"):
			cfg[key] = bool(changes[k])
		elif key.ends_with("_slot"):
			cfg[key] = clampi(int(changes[k]), 0, 2)
		else:
			cfg[key] = auto_potion_pct(int(changes[k]))
	e.auto_potion = cfg
	e.auto_potion_warned = 0
	return cfg

## A vaga `slot` tem alguma linha ligada (o "A" da barra)?
static func auto_potion_armed(e: SimEntity, slot: int) -> bool:
	var ap := e.auto_potion
	if ap.is_empty():
		return false
	for ln in AUTO_LINES:
		if bool(ap.get(ln[0], false)) and int(ap.get(ln[1], -1)) == slot:
			return true
	return false

## O item da vaga serve para a linha (bit 1 vida, 2 mana, 4 elixir)? Precisa existir na bolsa.
static func _auto_fits(e: SimEntity, slot: int, bit: int) -> bool:
	var item_id: String = e.potion_slots[slot]
	if item_id == "" or not e.has_item(item_id) or not GameData.items.has(item_id):
		return false
	var c: Dictionary = (GameData.items[item_id] as ItemDef).consume
	if bit == 1:
		return c.has("heal") or c.has("heal_pct")
	if bit == 2:
		return c.has("mana") or c.has("mana_pct")
	return c.get("buff") is Dictionary and str(c["buff"].get("id", "")) != ""

static func _has_buff_id(e: SimEntity, id: String) -> bool:
	for b in e.buffs:
		if b.get("id") == id:
			return true
	return false

## Linha com a condição verdadeira: bebe se a vaga serve e a recarga está zerada; vaga que não serve avisa uma vez.
static func _auto_line(sim: WorldSim, e: SimEntity, ln: Array, cfg: Dictionary) -> void:
	var slot: int = cfg[ln[1]]
	var bit: int = ln[2]
	if slot < 0 or slot > 2 or not _auto_fits(e, slot, bit):
		if (e.auto_potion_warned & bit) == 0:
			e.auto_potion_warned |= bit
			Events.post(&"notification", "Auto-poção: sem %s em F%d" % ["poção de " + str(ln[3]) if bit != 4 else "elixir", slot + 1])
		return
	e.auto_potion_warned &= ~bit
	if bit == 4:
		var item: ItemDef = GameData.items[e.potion_slots[slot]]
		if _has_buff_id(e, str(item.consume["buff"]["id"])):
			return                           # efeito ainda ativo (deste ou de outra fonte com o mesmo id)
	if e.potion_cds[slot] <= 0.0:
		use_potion(sim, e, slot)

## Tick do jogador (WorldSim.tick, só com `auto_potion` preenchido): vida, depois mana, depois elixir (§3.3-3.4).
## Sem alocar: só leituras do dicionário; cada linha desligada sai na primeira comparação.
static func auto_potion(sim: WorldSim, e: SimEntity) -> void:
	if not e.is_alive():
		return
	var ap := e.auto_potion
	if bool(ap.get("hp_on", false)) and e.hp < e.stats.max_hp * float(ap["hp_pct"]) / 100.0:
		_auto_line(sim, e, AUTO_LINES[0], ap)
	if bool(ap.get("mp_on", false)) and e.mp < e.stats.max_mp * float(ap["mp_pct"]) / 100.0:
		_auto_line(sim, e, AUTO_LINES[1], ap)
	if bool(ap.get("elx_on", false)) and sim.time - e.last_fight_t <= Balance.AUTO_POTION_COMBAT_S:
		_auto_line(sim, e, AUTO_LINES[2], ap)

## Por que `e` não pode equipar `item` (no slot dado); "" = pode.
static func equip_error(sim: WorldSim, e: SimEntity, item: ItemDef, to_offhand: bool = false) -> String:
	if item == null or not item.is_equipment():
		return "Não é equipamento"
	if e.level < item.level_req:
		return "Requer nível %d" % item.level_req
	if item.class_restriction.size() > 0 and not (e.class_def.id in item.class_restriction):
		return "Sua classe não pode usar isso"
	if to_offhand and item.weapon_type in ItemDef.TWO_HANDED:
		return TitanSystem.offhand_error(e, item)         # Empunhadura de Titã (ascensão do Berserker)
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
		Events.post(&"notification", err)
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
	if main and main.is_two_handed() and e.equipment.get(ItemDef.Slot.OFFHAND) != null and not TitanSystem.pair_ok(e):
		var bump: int = ItemDef.Slot.WEAPON if slot == ItemDef.Slot.OFFHAND else ItemDef.Slot.OFFHAND
		e.add_item(e.equipment[bump].id, 1)
		e.equipment.erase(bump)
		if e == sim.player:
			Events.post(&"notification", "Arma de duas mãos: a outra mão foi liberada")
	var off_now: ItemDef = e.equipment.get(ItemDef.Slot.OFFHAND)
	if off_now and off_now.weapon_type in ItemDef.TWO_HANDED and not TitanSystem.pair_ok(e):
		e.add_item(off_now.id, 1)                 # trocou a principal por uma de 1 mão: o machado de 2 mãos volta à bolsa
		e.equipment.erase(ItemDef.Slot.OFFHAND)
	e.recompute_stats()
	Events.post(&"equipment_changed", e.id)
	return true

static func unequip(sim: WorldSim, e: SimEntity, slot: int) -> void:
	if e.equipment.has(slot) and e.equipment[slot] != null:
		e.add_item(e.equipment[slot].id, 1)
		e.equipment.erase(slot)
		e.recompute_stats()
		Events.post(&"equipment_changed", e.id)

## 1º slot vazio da barra: 1-6 para skill comum, 7-0 para skill de ascensão (`asc`).
static func first_free_slot(sim: WorldSim, e: SimEntity, asc: bool = false) -> int:
	for i in range(Balance.SKILL_SLOTS if asc else 0, e.skills.size() if asc else mini(e.skills.size(), Balance.SKILL_SLOTS)):
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
			Events.post(&"notification", "Depósito cheio (%d tipos de item)." % Balance.STORAGE_SLOTS)
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
