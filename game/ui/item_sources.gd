class_name ItemSources
extends RefCounted
## "De onde vem" um item (ⓘ da forja e do refino; GDD forja-e-refino-ui §3.3). Só lê catálogos; o índice é montado
## na 1ª chamada e guardado. Cada fonte: {"kind": gather|monster|shop|recipe|quest, "text": String, "level": int}.

const GATHER_NAMES := {"herb": "ervas", "herb_blue": "ervas azuis", "ore": "veio de minério", "star": "pedra-estrela",
	"shell": "conchas", "mushroom": "cogumelos", "relic": "relíquias", "crate": "caixas"}
const KIND_ORDER := ["gather", "monster", "shop", "recipe", "quest"]
const UNKNOWN := "Fonte desconhecida"

static var _index: Dictionary = {}       # item id -> Array de fontes (sem ordem por nível ainda)
static var _built := false

## Fontes do item na ordem do GDD (colheita, monstros, lojas, receita; missão só se não houver outra).
## `level` >= 0 põe primeiro os monstros de nível mais perto dele. `limit` <= 0 = todas.
static func of(item_id: String, level: int = -1, limit: int = 0) -> Array:
	if not _built:
		_build()
	var all: Array = (_index.get(item_id, []) as Array).duplicate()
	if all.any(func(s): return s["kind"] != "quest"):
		all = all.filter(func(s): return s["kind"] != "quest")
	all.sort_custom(func(a, b): return _before(a, b, level))
	return all.slice(0, limit) if limit > 0 else all

## Texto do ⓘ: até Balance.SOURCES_SHOWN linhas (BBCode), ou "Fonte desconhecida".
static func tip(item_id: String, level: int = -1) -> String:
	var it: ItemDef = GameData.items.get(item_id)
	var t := "[b]%s[/b] — de onde vem:" % (it.name if it else item_id)
	var list := of(item_id, level, Balance.SOURCES_SHOWN)
	if list.is_empty():
		return t + "\n[color=#aaa]%s[/color]" % UNKNOWN
	for s in list:
		t += "\n• " + str(s["text"])
	var more := of(item_id, level).size() - list.size()
	if more > 0:
		t += "\n[color=#aaa]... e mais %d[/color]" % more
	return t

## Esquece o índice (testes que mexem em catálogo).
static func clear_cache() -> void:
	_index.clear()
	_built = false

static func _before(a: Dictionary, b: Dictionary, level: int) -> bool:
	var ka := KIND_ORDER.find(a["kind"])
	var kb := KIND_ORDER.find(b["kind"])
	if ka != kb:
		return ka < kb
	if level >= 0 and a["kind"] == "monster":
		var da := absi(int(a["level"]) - level)
		var db := absi(int(b["level"]) - level)
		if da != db:
			return da < db
	return str(a["text"]) < str(b["text"])

static func _add(item_id: String, kind: String, text: String, level: int = 0) -> void:
	var list: Array = _index.get(item_id, [])
	for s in list:
		if s["text"] == text:
			return
	list.append({"kind": kind, "text": text, "level": level})
	_index[item_id] = list

static func _build() -> void:
	_index.clear()
	var mob_maps := {}         # monstro -> nome do 1º mapa onde nasce
	for mid in GameData.maps:
		var md: MapDef = GameData.maps[mid]
		for g in md.gather:
			_add(str(g["item"]), "gather", "Colheita: %s (%s)" % [md.name, GATHER_NAMES.get(str(g.get("kind", "herb")), "colheita")])
		for sp in md.spawners:
			var mon := str(sp.get("monster_id", ""))
			if mon != "" and not mob_maps.has(mon):
				mob_maps[mon] = md.name
		for n in md.npcs:
			var stock: Variant = n.get("shop", [])
			if stock is Array:
				for iid in stock:
					_add(str(iid), "shop", "Loja: %s (%s)" % [str(n.get("name", "?")), md.name])
	for mid in GameData.monsters:
		var m: MonsterDef = GameData.monsters[mid]
		var lt: LootTable = GameData.loot_tables.get(m.loot_table)
		if lt == null:
			continue
		var where: String = mob_maps.get(mid, "")
		for e in lt.entries:
			_add(str(e["item"]), "monster", "%s (Lv %d%s)" % [m.name, m.level, (", " + where) if where != "" else ""], m.level)
	for rid in GameData.recipes:
		var r: RecipeDef = GameData.recipes[rid]
		var st := "forja" if r.station == "smith" else "caldeirão"
		_add(r.result_item, "recipe", "Receita: %s (Lv %d)" % [st, r.level_req], r.level_req)
	for qid in GameData.quests:
		var q: QuestDef = GameData.quests[qid]
		for iid in q.reward_items:
			_add(str(iid), "quest", "Missão: %s" % q.title)
	_built = true
