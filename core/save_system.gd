extends Node
## SaveSystem (autoload): salva/carrega o jogador em espaços de personagem (user://save_<n>.json, SLOTS espaços).
## `slot` = espaço do personagem em jogo (-1 = não salva: testes, --autostart). O save.json antigo vira o espaço 0.

const PATH := "user://save.json"          # save antigo (um só); migra para o espaço 0
const SLOTS := 5
## Retrato do card do espaço (`PORTRAIT_PATH % n`): grava o game/menu/portrait.gd (Portrait.path), apaga o delete_slot.
const PORTRAIT_PATH := "user://portrait_%d.png"
var slot := 0
const VERSION := 5      # 2 = portões de progressão e chefes abatidos; 3 = Rei Élfico guarda as Ruínas; 4 = teia de passivos (reembolso); 5 = Ato II: elemental que evolui, teia de ascensão (asc_tree) e barra de 10 (loadout 7-0)

## Itens de build que saiu do jogo (save antigo): prefixo antigo -> [prefixo novo da peça, prefixo novo da arma]; o resto
## do id (nível, peça e o "+N" do aprimoramento) segue junto. Único lugar das migrações de id de item.
## Trapaceiro (espada + adaga) virou Corsário (sabre + pistola): a adaga de aparar do conjunto vira a pistola do mesmo nível.
## Arremessador (duas machadinhas) virou Punhos de Fúria (duas garras): cada peça vira a do mesmo nível.
## Patrulheiro (arco) virou Lanceiro (lança): a armadura de couro vai para o conjunto do Lanceiro e o arco vira o do Caçador.
const ITEM_ID_MIGRATIONS := {
	"leg_assassin_trapaceiro_": ["leg_assassin_corsario_", "leg_assassin_corsario_"],
	"leg_berserker_arremessador_": ["leg_berserker_punhos_", "leg_berserker_punhos_"],
	"leg_ranger_patrulheiro_": ["leg_ranger_lanceiro_", "leg_ranger_cacador_"],
}

static func migrate_item_id(id: String) -> String:
	for old in ITEM_ID_MIGRATIONS:
		if id.begins_with(old):
			var weapon := id.get_slice("+", 0).ends_with("_weapon")
			return str(ITEM_ID_MIGRATIONS[old][1 if weapon else 0]) + id.substr(old.length())
	return id

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
		Events.post(&"notification", "Sua classe mudou de arma: a antiga foi para a bolsa.")

static func points_for_level(level: int) -> int:
	return ProgressionSystem.points_for_level(level)

func _ready() -> void:
	if FileAccess.file_exists(PATH) and not FileAccess.file_exists(path_of(0)):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(path_of(0)))
	for i in range(SLOTS):
		_settle_tmp(i)

func path_of(i: int) -> String:
	return "user://save_%d.json" % i

## Arquivo da gravação em andamento (save_<n>.json.tmp); só vira o save depois de inteiro.
func tmp_of(i: int) -> String:
	return path_of(i) + ".tmp"

## Estado do espaço (UX start-flow §5): "empty" (sem arquivo), "ok" ou "corrupt" (o arquivo existe, mas o JSON
## não lê, é `{}`, não é dicionário ou não tem `class`). Um .tmp solto é resolvido antes (ver `_settle_tmp`).
## Ex.: `if SaveSystem.slot_state(i) == "corrupt": card "Save danificado" só com Excluir`.
func slot_state(i: int) -> String:
	if i < 0:
		return "empty"
	_settle_tmp(i)
	if not FileAccess.file_exists(path_of(i)):
		return "empty"
	return "ok" if _is_valid(_read_json(path_of(i))) else "corrupt"

## Espaço ocupado (ok OU danificado): não é livre, aparece na lista e pode ser excluído.
func has_slot(i: int) -> bool:
	return slot_state(i) != "empty"

## Algum personagem salvo (ok ou danificado: o danificado também aparece, para ser excluído)?
func has_save() -> bool:
	for i in range(SLOTS):
		if has_slot(i):
			return true
	return false

## Primeiro espaço vazio (danificado não é livre: só sai pelo Excluir). `from`/`count` só para os testes (90+).
func first_free_slot(from: int = 0, count: int = SLOTS) -> int:
	for i in range(from, from + count):
		if slot_state(i) == "empty":
			return i
	return -1

## Resumo para a tela inicial: {name, class, level, map}; vazio = espaço livre OU danificado (ver `slot_state`).
func slot_summary(i: int) -> Dictionary:
	var d := load_data(i)
	if d.is_empty():
		return {}
	return {"name": d.get("name", "?"), "class": d.get("class", "paladin"), "level": int(d.get("level", 1)), "map": d.get("map", "")}

## Apaga o espaço em qualquer estado (inclusive danificado), um .tmp que tenha ficado e o retrato do card.
func delete_slot(i: int) -> void:
	if i < 0:
		return
	for pth in [path_of(i), tmp_of(i), PORTRAIT_PATH % i]:
		if FileAccess.file_exists(pth):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(pth))

## Save que dá para carregar: dicionário não vazio com `class` (classe que saiu do jogo ainda conta: vira a padrão).
static func _is_valid(d: Variant) -> bool:
	return d is Dictionary and not (d as Dictionary).is_empty() and str((d as Dictionary).get("class", "")) != ""

## JSON do arquivo (null se não abre/não lê).
static func _read_json(pth: String) -> Variant:
	if not FileAccess.file_exists(pth):
		return null
	var json := JSON.new()          # sem o JSON.parse_string: ele loga erro a cada leitura do espaço danificado
	return json.data if json.parse(FileAccess.get_file_as_string(pth)) == OK else null

## .tmp solto = gravação interrompida. Regra: o principal bom sempre vence (o .tmp é apagado). Sem principal, ou com o
## principal danificado, um .tmp válido entra no lugar (a queda foi entre terminar o .tmp e renomear); .tmp inválido é apagado.
func _settle_tmp(i: int) -> void:
	var tmp := tmp_of(i)
	if not FileAccess.file_exists(tmp):
		return
	var main_ok := _is_valid(_read_json(path_of(i)))
	if not main_ok and _is_valid(_read_json(tmp)):
		if _replace(tmp, path_of(i)) == OK:
			push_warning("SaveSystem: espaço %d recuperado do .tmp de uma gravação interrompida" % i)
			return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))

## Renomeia `src` por cima de `dst`. Se o renomear não substitui o destino, apaga o destino e tenta de novo
## (se cair entre os dois, só o .tmp inteiro fica e `_settle_tmp` o recupera).
static func _replace(src: String, dst: String) -> Error:
	var s := ProjectSettings.globalize_path(src)
	var d := ProjectSettings.globalize_path(dst)
	var err := DirAccess.rename_absolute(s, d)
	if err != OK and FileAccess.file_exists(dst):
		DirAccess.remove_absolute(d)
		err = DirAccess.rename_absolute(s, d)
	return err

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
		"inventory": p.inventory, "storage": p.storage, "equipment": eq, "mastery": p.mastery, "mastery_points": p.mastery_points, "tree": p.tree.keys(), "asc_tree": p.asc_tree.keys(),
		"potion_slots": p.potion_slots,
		"learned": p.learned.keys(), "talents": p.talents.keys(),
		"loadout": p.skills.map(func(s): return s.id if s else ""),
		"quests_active": p.quests_active, "quests_completed": p.quests_completed,
		"bind": [p.bind_map, p.bind_pos.x, p.bind_pos.z],
		"save_version": VERSION, "bosses_killed": p.bosses_killed.keys(), "gates_open": p.gates_open.keys(), "bag_bonus": p.bag_bonus, "mount": p.mount_kind,
		"elemental": ElementalSystem.to_save(p),
	}
	# gravação atômica: escreve o .tmp inteiro, fecha e só então renomeia por cima do save (fechar no meio não trunca o save bom)
	var tmp := tmp_of(slot)
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("SaveSystem: não abriu %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return
	var wrote := f.store_string(JSON.stringify(data, "  "))
	f.flush()
	wrote = wrote and f.get_error() == OK
	f.close()
	if not wrote:
		push_error("SaveSystem: falha ao gravar %s; o save anterior ficou" % tmp)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return
	var err := _replace(tmp, path_of(slot))
	if err != OK:
		push_error("SaveSystem: falha ao renomear %s (%s)" % [tmp, error_string(err)])
		return
	Events.post(&"notification", "Jogo salvo")

## Save do espaço `i` (padrão: o em jogo); `{}` se vazio ou danificado (`slot_state`).
func load_data(i: int = -2) -> Dictionary:
	if i == -2:
		i = slot
	if slot_state(i) != "ok":
		return {}
	return _read_json(path_of(i)) as Dictionary

## Aplica o save numa entidade recém-criada (depois do spawn).
func apply_to(p: SimEntity, d: Dictionary) -> void:
	p.look = LooksCatalog.normalized(d.get("look", {}), p.class_def)     # save antigo: visual padrão da classe
	p.level = int(d.get("level", 1))
	p.xp = int(d.get("xp", 0))
	p.storage = {}
	var st: Dictionary = d.get("storage", {})
	for iid in st:
		var sid := migrate_item_id(str(iid))          # peça de build que saiu do jogo vira a equivalente
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
		var iid := migrate_item_id(str(k))
		if GameData.resolve_item(iid):
			p.inventory[iid] = int(p.inventory.get(iid, 0)) + int(d["inventory"][k])
	p.equipment = {}
	for k in d.get("equipment", {}):
		var eid := migrate_item_id(str(d["equipment"][k]))
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
			Events.post(&"notification", "A teia de skills mudou: seus %d pontos foram devolvidos (tecla K)." % p.mastery_points)
	Sim.recompute_tree_bonus(p)
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
	p.mount_kind = MountSystem.from_save(p, str(d.get("mount", Balance.MOUNT_DEFAULT)))     # save antigo: cavalo
	ElementalSystem.from_save(p, d)            # save antigo (< 5): experiência 0, forma = a do último elemental
	# teia de ascensão (save < 5: vazia). Nó que não existe mais: a teia volta ao início (os pontos são calculados)
	p.asc_tree = {}
	var atr: Dictionary = GameData.asc_trees.get(p.class_def.id, {})
	var asc_saved: Array = d.get("asc_tree", [])
	if not atr.is_empty() and asc_saved.all(func(nid): return atr["nodes"].has(str(nid))):
		for nid in asc_saved:
			p.asc_tree[str(nid)] = true
	elif not asc_saved.is_empty():
		Events.post(&"notification", "A teia de ascensão mudou: seus pontos de ascensão foram devolvidos (tecla K).")
	for sid in ProgressionSystem.ascension_skills(p):          # skill de ascensão só vem da teia dela
		if not p.asc_tree.has("%s_a_s_%s" % [p.class_def.id, sid]):
			p.learned.erase(sid)
			p.mastery.erase(sid)
	Sim.recompute_tree_bonus(p)
	# barra: 1-6 (teia comum) e, com a ascensão (missões já lidas), 7-0 só com skills de ascensão
	var loadout: Array = d.get("loadout", p.learned.keys())
	p.skills.clear()
	p.ensure_slots()
	for i in range(mini(loadout.size(), p.skills.size())):
		var s: SkillDef = GameData.skills.get(str(loadout[i]))
		if s and p.learned.has(s.id) and s.ascension == (i >= Balance.SKILL_SLOTS):
			p.skills[i] = s
	for b in d.get("bosses_killed", []):
		p.bosses_killed[str(b)] = true
	for g in d.get("gates_open", []):
		p.gates_open[str(g)] = true
	if not d.has("save_version"):
		Sim.grandfather_gates(p, str(d.get("map", "")))
	if int(d.get("save_version", 0)) < 3 and "q11_chief" in p.quests_completed:
		p.gates_open["to_ruins"] = true          # já liberou as Ruínas pelo Chefe dos Bandidos (antes do cerco élfico)
	if p.bind_map == "":                         # save de antes do retorno automático: já chegou ao porto, renasce lá
		for qid in MapsCatalog.QUEST_BIND:
			if qid in p.quests_completed:
				PortalSystem.quest_bind(Sim, p, qid, false)
	p.recompute_stats()
	p.hp = clampf(float(d.get("hp", p.stats.max_hp)), 1.0, p.stats.max_hp)
	p.mp = clampf(float(d.get("mp", p.stats.max_mp)), 0.0, p.stats.max_mp)
	Events.post(&"equipment_changed", p.id)


## Save antigo: o slot único de acessório vira amuleto ou anel, conforme o item.
func saved_slot(slot: int, it: ItemDef) -> int:
	return it.slot if slot == ItemDef.Slot.ACCESSORY else slot
