class_name GuildFake
extends RefCounted
## Fonte falsa do lado social (formatos do wave3-contract §1) para testes e --guild_shot, enquanto/quando a sim
## não monta o cenário sozinha. Guarda as chamadas de ação em `calls` (os testes conferem o que a UI chamou).

var calls: Array = []
var offer := {"state": "pending", "guild_id": "g_lanternas", "from": "Rook"}
var guild := {}
var roster: Array = []
var requests: Array = []
var clock := 3600.0
var tags := {}                         # entity_id -> tag
var rival_eid := -1

func _init() -> void:
	var names := [["Rook", "paladin", "guardiao", "heroico", 72], ["Sable", "berserker", "executor", "competitivo", 12],
		["Lina", "bishop", "sacerdote", "calmo", 45], ["Tork", "druid", "lobo", "brincalhao", 33], ["Vey", "ranger", "cacador", "timido", 20],
		["Mira", "elementalist", "fogo", "calmo", 5], ["Dax", "assassin", "laminas", "competitivo", -8], ["Ona", "necromancer", "invocador", "timido", -35],
		["Brum", "paladin", "templario", "brincalhao", 0], ["Kael", "ranger", "atirador", "heroico", 61]]
	for i in names.size():
		var n: Array = names[i]
		roster.append({"rid": i + 1, "name": n[0], "class": n[1], "build": n[2], "personality": n[3], "level": 15 + (i % 3) - 1,
			"affinity": n[4], "rival": n[0] == "Sable", "guild": "g_lanternas" if int(n[4]) >= 20 else "", "entity_id": -1, "map": "",
			"memories": [{"kind": "grupo", "at": 600.0, "map": "city_aldara"}, {"kind": "salvou", "at": 3300.0, "map": "field_vale"}] if int(n[4]) > 30 else
				([{"kind": "abandonou", "at": 2000.0, "map": "dg_crypt"}] if int(n[4]) < 0 else [])})
	guild = {"id": "g_lanternas", "name": "Lanternas de Aldara", "tag": "LAN", "personality": "equilibrada", "crest": 0, "bot_guild": false,
		"player_member": false, "founded_by_player": false, "leader": "Rook", "members": [], "power": 16, "player_rank": "recruta",
		"contribution": 0, "created_at": 3000.0}
	for r in roster:
		if r["guild"] == "g_lanternas":
			guild["members"].append({"name": r["name"], "class": r["class"], "build": r["build"], "level": r["level"], "personality": r["personality"],
				"rid": r["rid"], "entity_id": r["entity_id"]})

## Põe bots vivos do mundo no lugar dos nomes (plaquinhas e "online" de verdade na foto).
func bind_entities(bots: Array) -> void:
	for i in mini(bots.size(), roster.size()):
		var e: SimEntity = bots[i]
		var r: Dictionary = roster[i]
		r["entity_id"] = e.id
		r["map"] = e.map_id
		e.name = r["name"]
		if r["guild"] != "":
			tags[e.id] = "LAN"
		if r["rival"]:
			rival_eid = e.id
		for m in guild["members"]:
			if m["rid"] == r["rid"]:
				m["entity_id"] = e.id

# --- leitura -----------------------------------------------------------------
func roster_list() -> Array: return roster
func roster_entry(rid: int) -> Dictionary:
	for r in roster:
		if r["rid"] == rid:
			return r
	return {}
func roster_of(entity_id: int) -> Dictionary:
	for r in roster:
		if r["entity_id"] == entity_id and entity_id >= 0:
			return r
	return {}
func rival_info() -> Dictionary:
	var r: Dictionary = roster[1]
	return {"rid": r["rid"], "name": r["name"], "class": r["class"], "level": r["level"], "wins": 2, "losses": 1,
		"race": {"boss": "crypt_lord", "boss_name": "Conde da Cripta", "until": clock + 1500.0, "suspended": false}}
func social_clock() -> float: return clock
func player_guild() -> Dictionary: return guild if guild["player_member"] else {}
func guild_info(id: String) -> Dictionary: return guild if id == guild["id"] else {}
func guild_list() -> Array: return [guild]
func guild_tag_of(entity_id: int) -> String:
	if Sim.player and entity_id == Sim.player.id:
		return guild["tag"] if guild["player_member"] else ""
	return str(tags.get(entity_id, ""))
func guild_offer() -> Dictionary: return offer
func guild_found_error(n: String) -> String: return "" if n.length() >= 3 else "O nome precisa de 3 a 24 letras."
func help_requests() -> Array: return requests.filter(func(q): return q["state"] == "open")
func player_titles() -> Array: return ["Vencedor de Sable"]
func personality_label(id: String) -> String:
	return {"calmo": "Calmo", "brincalhao": "Brincalhão", "competitivo": "Competitivo", "timido": "Tímido", "heroico": "Heroico"}.get(id, id)
func memory_label(kind: String) -> String:
	return {"salvou": "Você me salvou", "grupo": "Matamos um chefe juntos", "abandonou": "Você me deixou na masmorra",
		"ajudou_pedido": "Veio quando pedi ajuda", "perdeu_saque": "Ficou com o meu lendário"}.get(kind, kind)
func affinity_label(v: int) -> String:
	return "Hostil" if v < -30 else ("Frio" if v < 0 else ("Conhecido" if v < 30 else ("Amigo" if v < 60 else "Leal")))

# --- ações (só registram) -------------------------------------------------------
func guild_respond(accept: bool) -> void:
	calls.append(["guild_respond", accept])
	offer["state"] = "accepted" if accept else "refused"
	guild["player_member"] = accept
func guild_found(n: String) -> String:
	calls.append(["guild_found", n])
	return guild_found_error(n)
func guild_leave() -> void: calls.append(["guild_leave"])
func guild_say(t: String) -> void: calls.append(["guild_say", t])
func rival_challenge(b: String) -> String:
	calls.append(["rival_challenge", b])
	return ""
func rival_challenge_cancel() -> void: calls.append(["rival_challenge_cancel"])

## Pedido de socorro aberto (formato 1.9).
func add_request(id: int, name: String, map: String, pos: Vector3) -> Dictionary:
	var q := {"id": id, "rid": 1, "name": name, "map": map, "pos": pos, "reason": "surrounded", "expires": clock + 90.0, "left": 90.0, "state": "open"}
	requests.append(q)
	return q

func end_request(id: int) -> void:
	for q in requests:
		if q["id"] == id:
			q["state"] = "helped"
