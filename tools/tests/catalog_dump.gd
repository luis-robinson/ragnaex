extends Node
## Despejo dos catálogos (skills, itens, conjuntos, builds) em texto ordenado, para provar que uma refatoração não mudou
## nenhum dado: rode antes e depois e compare os arquivos (diff vazio = mesmos dados).
## Uso: --headless --path . tools/tests/catalog_dump.tscn -- --out=<arquivo>

func _ready() -> void:
	var lines: Array[String] = []
	_dump_all(lines, "skill", GameData.skills)
	_dump_all(lines, "item", GameData.items)
	_dump_all(lines, "set", GameData.sets)
	_dump_all(lines, "monster", GameData.monsters)
	_dump_all(lines, "quest", GameData.quests)
	_dump_all(lines, "recipe", GameData.recipes)
	_dump_all(lines, "map", GameData.maps)
	_dump_all(lines, "talent", GameData.talents)
	for cid in GameData.classes:
		var cls: ClassDef = GameData.classes[cid]
		lines.append("class %s %s" % [cid, _props(cls)])
	lines.sort()
	var out := DevArgs.value("--out", "user://catalog_dump.txt")
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("DUMP %d linhas -> %s" % [lines.size(), out])
	for k in CatalogUtil.unknown_keys:
		print("DUMP chave desconhecida: ", k)
	get_tree().quit()

func _dump_all(lines: Array[String], tag: String, table: Dictionary) -> void:
	for id in table:
		lines.append("%s %s %s" % [tag, id, _props(table[id])])

## Propriedades do script (as do Resource/Object ficam de fora), em ordem de nome.
func _props(o: Object) -> String:
	var parts: Array[String] = []
	for p in o.get_property_list():
		if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			parts.append("%s=%s" % [p["name"], _canon(o.get(p["name"]))])
	parts.sort()
	return " | ".join(parts)

## Texto estável: dicionário com as chaves em ordem (a ordem de inserção não é dado), recursivo.
func _canon(v: Variant) -> String:
	if v is Dictionary:
		var ks: Array = v.keys()
		ks.sort_custom(func(a, b): return str(a) < str(b))
		var parts: Array[String] = []
		for k in ks:
			parts.append("%s: %s" % [var_to_str(k), _canon(v[k])])
		return "{" + ", ".join(parts) + "}"
	if v is Array:
		var parts: Array[String] = []
		for x in v:
			parts.append(_canon(x))
		return "[" + ", ".join(parts) + "]"
	if v is Object:
		return "<%s>" % (v.get("id") if "id" in v else v.get_class())
	return var_to_str(v).replace("\n", " ")
