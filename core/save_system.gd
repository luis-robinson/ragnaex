extends Node
## SaveSystem (autoload): salva/carrega o jogador em espaços de personagem (user://save_<n>.json, SLOTS espaços).
## `slot` = espaço do personagem em jogo (-1 = não salva: testes, --autostart). O save.json antigo vira o espaço 0.

const PATH := "user://save.json"          # save antigo (um só); migra para o espaço 0
const SLOTS := 5
var slot := 0
const VERSION := 4      # 2 = portões de progressão e chefes abatidos; 3 = Rei Élfico guarda as Ruínas; 4 = teia de passivos (reembolso)

## Pontos de skill ganhos até um nível (o que a árvore devolve quando é refeita).
## Arma que a classe não usa mais (ex.: Elementalista só de cajado): volta para a bolsa e a inicial da classe entra no lugar.
static func _fix_class_weapons(p: SimEntity) -> void:
	var moved := false
	for slot in [ItemDef.Slot.WEAPON, ItemDef.Slot.OFFHAND]:
		var it: ItemDef = p.equipment.get(slot)
		if it == null:
			continue
		var ok: bool = it.weapon_type in (p.class_def.weapon_types if slot == ItemDef.Slot.WEAPON else p.class_def.offhand_types)
		if not ok:
			p.inventory[it.id] = int(p.inventory.get(it.id, 0)) + 1
			p.equipment.erase(slot)
			moved = true
	if moved and p.equipment.get(ItemDef.Slot.WEAPON) == null:
		for iid in p.class_def.starting_equipment:
			var st: ItemDef = GameData.items[iid]
			if st.slot == ItemDef.Slot.WEAPON:
				p.equipment[ItemDef.Slot.WEAPON] = st
				break
		Events.notification.emit("Sua classe mudou de arma: a antiga foi para a bolsa.")

static func points_for_level(level: int) -> int:
	return ProgressionSystem.points_for_level(level)

func _ready() -> void:
	if FileAccess.file_exists(PATH) and not FileAccess.file_exists(path_of(0)):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(path_of(0)))

func path_of(i: int) -> String:
	return "user://save_%d.json" % i

func has_slot(i: int) -> bool:
	return i >= 0 and FileAccess.file_exists(path_of(i))

## Algum personagem salvo?
func has_save() -> bool:
	for i in range(SLOTS):
		if has_slot(i):
			return true
	return false

func first_free_slot() -> int:
	for i in range(SLOTS):
		if not has_slot(i):
			return i
	return -1

## Resumo para a tela inicial: {name, class, level, map} (vazio = espaço livre).
func slot_summary(i: int) -> Dictionary:
	var d := load_data(i)
	if d.is_empty():
		return {}
	return {"name": d.get("name", "?"), "class": d.get("class", "paladin"), "level": int(d.get("level", 1)), "map": d.get("map", "")}

func delete_slot(i: int) -> void:
	if has_slot(i):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path_of(i)))

func save_player(p: SimEntity) -> void:
	if p == null or slot < 0:
		return
	var eq := {}
	for slot in p.equipment:
		if p.equipment[slot] != null:
			eq[str(int(slot))] = p.equipment[slot].id
	var data := {
		"name": p.name, "class": p.class_def.id, "look": p.look, "level": p.level, "xp": p.xp, "gold": p.gold,
		"hp": p.hp, "mp": p.mp, "map": p.map_id, "pos": [p.position.x, p.position.z],
		"inventory": p.inventory, "storage": p.storage, "equipment": eq, "mastery": p.mastery, "mastery_points": p.mastery_points, "tree": p.tree.keys(),
		"potion_slots": p.potion_slots,
		"learned": p.learned.keys(), "talents": p.talents.keys(),
		"loadout": p.skills.map(func(s): return s.id if s else ""),
		"quests_active": p.quests_active, "quests_completed": p.quests_completed,
		"bind": [p.bind_map, p.bind_pos.x, p.bind_pos.z],
		"save_version": VERSION, "bosses_killed": p.bosses_killed.keys(), "gates_open": p.gates_open.keys(), "bag_bonus": p.bag_bonus,
	}
	var f := FileAccess.open(path_of(slot), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))
		f.close()
		Events.notification.emit("Jogo salvo")

func load_data(i: int = -2) -> Dictionary:
	if i == -2:
		i = slot
	if not has_slot(i):
		return {}
	var f := FileAccess.open(path_of(i), FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}

## Aplica o save numa entidade recém-criada (depois do spawn).
func apply_to(p: SimEntity, d: Dictionary) -> void:
	p.look = LooksCatalog.normalized(d.get("look", {}), p.class_def)     # save antigo: visual padrão da classe
	p.level = int(d.get("level", 1))
	p.xp = int(d.get("xp", 0))
	p.storage = {}
	var st: Dictionary = d.get("storage", {})
	for iid in st:
		var sid := GameData.migrate_item_id(str(iid))          # peça de build que saiu do jogo vira a equivalente
		if GameData.resolve_item(sid) and int(st[iid]) > 0:
			p.storage[sid] = int(p.storage.get(sid, 0)) + int(st[iid])
	p.gold = int(d.get("gold", 0))
	var bnd: Array = d.get("bind", [])          # save antigo: sem cristal, volta para a cidade
	if bnd.size() == 3 and GameData.maps.has(str(bnd[0])):
		p.bind_map = str(bnd[0])
		p.bind_pos = Vector3(float(bnd[1]), 0.0, float(bnd[2]))
	else:
		p.bind_map = ""
	p.bag_bonus = clampi(int(d.get("bag_bonus", 0)), 0, Balance.BAG_UPGRADES)
	p.inventory = {}
	for k in d.get("inventory", {}):
		var iid := GameData.migrate_item_id(str(k))
		if GameData.resolve_item(iid):
			p.inventory[iid] = int(p.inventory.get(iid, 0)) + int(d["inventory"][k])
	p.equipment = {}
	for k in d.get("equipment", {}):
		var eid := GameData.migrate_item_id(str(d["equipment"][k]))
		var it: ItemDef = GameData.items.get(eid) if GameData.resolve_item(eid) else null
		if it:
			p.equipment[saved_slot(int(k), it)] = it
	# save de antes (aprimoramento por tipo): a peça vestida, ou uma cópia da bolsa, vira a versão +N
	var old_plus: Dictionary = d.get("plus", {})
	for iid in old_plus:
		var n := clampi(int(old_plus[iid]), 0, Balance.PLUS_MAX)
		if n <= 0 or not GameData.items.has(str(iid)):
			continue
		var v := GameData.plus_item(GameData.items[str(iid)], n)
		var done := false
		for sl in p.equipment:
			if not done and p.equipment[sl] != null and p.equipment[sl].id == str(iid):
				p.equipment[sl] = v
				done = true
		if not done and p.remove_item(str(iid), 1):
			p.add_item(v.id, 1)
	_fix_class_weapons(p)
	p.mastery = {}
	for k in d.get("mastery", {}):
		p.mastery[k] = int(d["mastery"][k])
	p.mastery_points = int(d.get("mastery_points", 0))
	for nid in d.get("tree", []):
		p.tree[String(nid)] = true
	# skills aprendidas + barra. Save antigo (sem "learned"): as skills com maestria viram aprendidas.
	p.learned = {}
	for sid in d.get("learned", p.mastery.keys()):
		if GameData.skills.has(sid):
			p.learned[str(sid)] = true
	for sid in p.class_def.starting_skills:
		p.learned[sid] = true
	p.talents = {}
	for tid in d.get("talents", []):
		if GameData.talents.has(tid):
			p.talents[str(tid)] = true
	# save antigo (sem árvore): marca os nós do que já foi comprado
	if not d.has("tree"):
		for sid in p.learned:
			p.tree["%s_s_%s" % [p.class_def.id, sid]] = true
		for tid in p.talents:
			p.tree["%s_t_%s" % [p.class_def.id, tid]] = true
	var tr: Dictionary = GameData.trees.get(p.class_def.id, {})
	if not tr.is_empty():
		p.tree[tr["start"]] = true
		# nó que não existe mais (skill/build removida): a árvore volta ao início e os pontos voltam todos
		if int(d.get("save_version", 0)) < 4 or p.tree.keys().any(func(nid): return not tr["nodes"].has(nid)):
			p.tree = {tr["start"]: true}
			for sid in p.class_def.starting_skills:
				p.tree["%s_s_%s" % [p.class_def.id, sid]] = true
			p.learned = {}
			for sid in p.class_def.starting_skills:
				p.learned[sid] = true
			p.talents = {}
			p.mastery = {}
			p.mastery_points = points_for_level(p.level)
			Events.notification.emit("A teia de skills mudou: seus %d pontos foram devolvidos (tecla K)." % p.mastery_points)
	Sim.recompute_tree_bonus(p)
	var loadout: Array = d.get("loadout", p.learned.keys())
	p.skills.clear()
	p.ensure_slots()
	for i in range(mini(loadout.size(), Balance.SKILL_SLOTS)):
		var s: SkillDef = GameData.skills.get(str(loadout[i]))
		if s and p.learned.has(s.id):
			p.skills[i] = s
	var ps: Array[String] = []
	for s in d.get("potion_slots", ["", "", ""]):
		ps.append(str(s))
	while ps.size() < 3:
		ps.append("")
	p.potion_slots = ps
	p.quests_active = {}
	for k in d.get("quests_active", {}):
		p.quests_active[k] = int(d["quests_active"][k])
	p.quests_completed.clear()
	for q in d.get("quests_completed", []):
		p.quests_completed.append(str(q))
	for b in d.get("bosses_killed", []):
		p.bosses_killed[str(b)] = true
	for g in d.get("gates_open", []):
		p.gates_open[str(g)] = true
	if not d.has("save_version"):
		Sim.grandfather_gates(p, str(d.get("map", "")))
	if int(d.get("save_version", 0)) < 3 and "q11_chief" in p.quests_completed:
		p.gates_open["to_ruins"] = true          # já liberou as Ruínas pelo Chefe dos Bandidos (antes do cerco élfico)
	p.recompute_stats()
	p.hp = clampf(float(d.get("hp", p.stats.max_hp)), 1.0, p.stats.max_hp)
	p.mp = clampf(float(d.get("mp", p.stats.max_mp)), 0.0, p.stats.max_mp)
	Events.equipment_changed.emit(p.id)


## Save antigo: o slot único de acessório vira amuleto ou anel, conforme o item.
func saved_slot(slot: int, it: ItemDef) -> int:
	return it.slot if slot == ItemDef.Slot.ACCESSORY else slot
