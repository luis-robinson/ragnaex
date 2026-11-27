class_name CraftSystem
extends RefCounted

## Receitas da estação; com classe, só as que ela pode usar (equipamento de outra classe não aparece).
static func recipes_for_station(station: String, cls: ClassDef = null) -> Array:
	var out: Array = []
	for rid in GameData.recipes:
		var r: RecipeDef = GameData.recipes[rid]
		if r.station == station and (cls == null or for_class(cls, r)):
			out.append(r)
	out.sort_custom(func(a, b): return a.level_req < b.level_req)
	return out

## A classe pode usar o resultado? Poção/material: todos. Arma: tipo da mão principal ou secundária da classe. Peça restrita: só a classe dela.
static func for_class(cls: ClassDef, r: RecipeDef) -> bool:
	var it: ItemDef = GameData.items.get(r.result_item)
	if it == null or not it.is_equipment():
		return true
	if it.class_restriction.size() > 0 and not (cls.id in it.class_restriction):
		return false
	if it.slot == ItemDef.Slot.WEAPON:
		return it.weapon_type in cls.weapon_types or it.weapon_type in cls.offhand_types
	if it.slot == ItemDef.Slot.OFFHAND:
		return it.weapon_type in cls.offhand_types
	return true

static func can_craft(e: SimEntity, r: RecipeDef) -> bool:
	if e.class_def and not for_class(e.class_def, r):
		return false
	if e.level < r.level_req or e.gold < r.gold_cost:
		return false
	for item_id in r.ingredients:
		if not e.has_item(item_id, int(r.ingredients[item_id])):
			return false
	return true

## Quantas vezes dá para fazer agora (puro): min(tem/precisa de cada material, ouro/custo); 0 se não pode, ou se o
## resultado é pilha nova numa bolsa cheia e nenhum material acaba (o lote empilha: cabe 1, cabem todos).
static func max_craftable(e: SimEntity, r: RecipeDef) -> int:
	if not can_craft(e, r):
		return 0
	var n := 1 << 30
	for item_id in r.ingredients:
		n = mini(n, int(e.inventory.get(item_id, 0)) / maxi(1, int(r.ingredients[item_id])))
	if r.gold_cost > 0:
		n = mini(n, e.gold / r.gold_cost)
	if e.bag_full_for(r.result_item):
		var frees := false
		for item_id in r.ingredients:
			frees = frees or int(e.inventory.get(item_id, 0)) == int(r.ingredients[item_id])
		if not frees:
			return 0
	return n

## notify = false: sem o aviso "Criou ..." (o lote da forja avisa uma vez só).
static func craft(e: SimEntity, r: RecipeDef, notify: bool = true) -> bool:
	if not can_craft(e, r):
		return false
	for item_id in r.ingredients:
		e.remove_item(item_id, int(r.ingredients[item_id]))
	e.gold -= r.gold_cost
	e.add_item(r.result_item, r.result_count)
	QuestSystem.on_craft(e, r.result_item, r.result_count)
	QuestSystem.on_item_changed(e, r.result_item)
	Events.post(&"crafted", e.id, r.result_item, r.result_count)
	if notify:
		var it: ItemDef = GameData.items.get(r.result_item)
		Events.post(&"notification", "Criou %s x%d" % [it.name if it else r.result_item, r.result_count])
	return true

# --- loja ---
## `mult` = preço de agora (Feira das cadeias: WorldSim.shop_buy); cada unidade arredonda como WorldSim.shop_price.
static func buy(e: SimEntity, item_id: String, count: int = 1, mult: float = 1.0) -> bool:
	var it: ItemDef = GameData.items.get(item_id)
	if it == null:
		return false
	var each := it.price if is_equal_approx(mult, 1.0) or it.price <= 0 else maxi(1, roundi(it.price * mult))
	var cost := each * count
	if e.gold < cost:
		Events.post(&"notification", "Ouro insuficiente")
		return false
	e.gold -= cost
	e.add_item(item_id, count)
	QuestSystem.on_item_changed(e, item_id)
	return true

## O que o mercador paga por uma unidade (Balance.MERCHANT_SELL_PCT; o piso do leilão lê daqui).
static func sell_price(it: ItemDef) -> int:
	return int(it.price * Balance.MERCHANT_SELL_PCT) if it != null and it.price > 0 else 0

static func sell(e: SimEntity, item_id: String, count: int = 1) -> bool:
	var it: ItemDef = GameData.items.get(item_id)
	if it == null or count <= 0 or not e.has_item(item_id, count) or it.type == ItemDef.Type.QUEST or it.price <= 0:
		return false
	e.remove_item(item_id, count)
	e.gold += sell_price(it) * count
	QuestSystem.on_item_changed(e, item_id)
	UnlockSystem.on_task(e, "sell")                 # introdução da loja
	return true
