class_name CatalogUtil
extends RefCounted
## Ajudantes dos catálogos (dicionário -> Resource).

## Chaves de catálogo que o Resource não tem ("Tipo.id.chave"): `Object.set` ignora em silêncio, então um erro de
## digitação sumia sem aviso. Há check de que fica vazio.
static var unknown_keys: Array[String] = []

## Copia `d` para os campos de `o`. Campo Array tipado recebe a lista com `assign` (set() com lista sem tipo falha em
## silêncio); chave que não é campo vai para `unknown_keys`.
static func fill(o: Object, d: Dictionary) -> void:
	for k in d:
		if not (k in o):
			unknown_keys.append("%s.%s.%s" % [o.get_script().get_global_name(), d.get("id", "?"), k])
			continue
		var cur = o.get(k)
		if cur is Array and d[k] is Array:
			(cur as Array).assign(d[k])
		else:
			o.set(k, d[k])
