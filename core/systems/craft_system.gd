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

static func craft(e: SimEntity, r: RecipeDef) -> bool:
	if not can_craft(e, r):
		return false
	for item_id in r.ingredients:
		e.remove_item(item_id, int(r.ingredients[item_id]))
	e.gold -= r.gold_cost
	e.add_item(r.result_item, r.result_count)
	QuestSystem.on_craft(e, r.result_item, r.result_count)
	QuestSystem.on_item_changed(e, r.result_item)
	Events.crafted.emit(e.id, r.result_item, r.result_count)
	var it: ItemDef = GameData.items.get(r.result_item)
	Events.notification.emit("Criou %s x%d" % [it.name if it else r.result_item, r.result_count])
	return true

# --- loja ---
static func buy(e: SimEntity, item_id: String, count: int = 1) -> bool:
	var it: ItemDef = GameData.items.get(item_id)
	if it == null:
		return false
	var cost := it.price * count
	if e.gold < cost:
		Events.notification.emit("Ouro insuficiente")
		return false
	e.gold -= cost
	e.add_item(item_id, count)
	QuestSystem.on_item_changed(e, item_id)
	return true

static func sell(e: SimEntity, item_id: String, count: int = 1) -> bool:
	var it: ItemDef = GameData.items.get(item_id)
	if it == null or count <= 0 or not e.has_item(item_id, count) or it.type == ItemDef.Type.QUEST or it.price <= 0:
		return false
	e.remove_item(item_id, count)
	e.gold += int(it.price * 0.5) * count
	QuestSystem.on_item_changed(e, item_id)
	return true
