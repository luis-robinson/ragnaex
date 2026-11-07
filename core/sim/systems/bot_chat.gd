class_name BotChat
extends RefCounted
## Conversa dos bots por contexto: onde estão (tipo de lugar, chefe vivo perto, investida no mapa), classe e build,
## e se estão no grupo do jogador (falam COM ele, pelo nome, no canal do grupo, e reagem ao que acontece).
## Falas em `BotsCatalog` (montadas em `GameData.bot_chat`); ritmo em `Balance.BOT_CHAT_*`/`PARTY_CHAT_*`.
## Estado mínimo: falas recentes no `BotBrain.recent_lines` (não repete) e o ritmo do grupo no dicionário do grupo
## (`chat_next`, `idle_next`, `react`, `queue`, `scan_at`...). Sem estado próprio.

static func pool(key: String) -> Array:
	return GameData.bot_chat.get(key, [])

## Tipo de lugar de `pos`: aldara_town/aldara_field, forest(_town), elf_city, dawn(_town), fort, citadel, dungeon, interior, field.
static func place_kind(def: MapDef, pos: Vector3) -> String:
	if def.interior:
		return "interior"
	var kind: String = BotsCatalog.MAP_KIND.get(def.id, "")
	if kind == "":
		if def.parent_map != "":
			return "dungeon"
		kind = "aldara" if def.is_town else "field"
	if kind in BotsCatalog.WALLED:
		var walls := def.town_radius > 0.0 and Vector2(pos.x - def.town_center.x, pos.z - def.town_center.z).length() < def.town_radius
		var inside := walls or def.in_town(pos)
		if kind == "aldara":
			return "aldara_town" if inside else "aldara_field"
		return kind + ("_town" if inside else "")
	return kind

static func in_player_party(sim, e: SimEntity) -> bool:
	return sim.player != null and e.party_id >= 0 and e.party_id == sim.player.party_id and e != sim.player

## Chefe vivo perto de `e` (ou null).
static func near_boss(sim, e: SimEntity) -> SimEntity:
	var m: Dictionary = sim.maps.get(e.map_id, {})
	if m.is_empty():
		return null
	for o in m["entities"]:
		if o.kind == SimEntity.Kind.MONSTER and o.is_alive() and o.monster_def.is_boss and o.boss_id < 0 \
				and o.position.distance_to(e.position) < Balance.BOT_CHAT_BOSS_RANGE:
			return o
	return null

static func raid_active(sim, map_id: String) -> bool:
	return bool(sim.raid_status(map_id).get("active", false))

## Marcas que toda fala pode usar.
static func vars_for(sim, e: SimEntity, extra: Dictionary = {}) -> Dictionary:
	var pl: SimEntity = sim.player
	var md: MapDef = GameData.maps.get(e.map_id)
	var v := {"p": pl.name if pl else "galera", "pcls": pl.class_def.name.to_lower() if pl and pl.class_def else "aventureiro",
		"map": md.name if md else "aqui", "lv": str(e.level), "me": e.name, "boss": "o chefe", "item": "esse item"}
	v.merge(extra, true)
	return v

## Sorteia uma fala de `lines` que o bot não disse há pouco (nunca a mesma duas vezes seguidas se houver outra) e preenche as marcas.
static func pick(sim, e: SimEntity, lines: Array, vars: Dictionary) -> String:
	if lines.is_empty():
		return ""
	var recent: Array = e.brain.recent_lines if e.brain is BotBrain else []
	var line: String = lines[sim.rng.randi() % lines.size()]
	if recent.has(line):
		var fresh: Array = lines.filter(func(l): return not recent.has(l))
		if fresh.is_empty():
			fresh = lines.filter(func(l): return l != recent.back())
		if not fresh.is_empty():
			line = fresh[sim.rng.randi() % fresh.size()]
	recent.append(line)
	while recent.size() > Balance.BOT_CHAT_RECENT:
		recent.pop_front()
	return line.format(vars)

# ---------------------------------------------------------------------------
# CONVERSA SOLTA (canal global)

## Conjunto de falas e marcas da conversa solta de `e` agora: investida/chefe, lugar ou classe+build.
static func ambient_choice(sim, e: SimEntity, situation: bool = true) -> Array:
	var def: MapDef = sim.maps[e.map_id]["def"]
	var kind := place_kind(def, e.position)
	if situation and kind != "interior" and sim.rng.randf() < Balance.BOT_CHAT_SITUATION:
		if raid_active(sim, e.map_id):
			return [pool("place:raid"), {}]
		var boss := near_boss(sim, e)
		if boss:
			return [pool("place:boss"), {"boss": boss.monster_def.name}]
	if e.class_def == null or sim.rng.randf() < Balance.BOT_CHAT_PLACE:
		var inside := kind.ends_with("_town")
		return [pool("place:" + kind) + pool("map:%s_%s" % ["town" if inside else "hunt", def.id]), {}]
	return [pool("class:" + e.class_def.id) + pool("build:" + e.build_id), {}]

static func ambient_line(sim, e: SimEntity, situation: bool = true) -> String:
	var c := ambient_choice(sim, e, situation)
	return pick(sim, e, c[0], vars_for(sim, e, c[1]))

## Relógio de conversa do bot (BotBrain) estourou: fala no global. Bot no grupo do jogador fala no grupo (BotChat.update).
static func ambient(sim, e: SimEntity) -> void:
	if in_player_party(sim, e):
		return
	var line := ambient_line(sim, e)
	if line != "":
		Events.chat_message.emit(e.name, line, "global")

# ---------------------------------------------------------------------------
# GRUPO COM O JOGADOR (canal do grupo)

## Fala de grupo do bot para o evento `kind` (geral + voz da classe).
static func party_line(sim, e: SimEntity, kind: String, extra: Dictionary = {}) -> String:
	var gen := pool("party:" + kind)
	var cls := pool("party:%s:%s" % [kind, e.class_def.id]) if e.class_def else []
	var lines := cls if not cls.is_empty() and (gen.is_empty() or sim.rng.randf() < 0.4) else gen
	return pick(sim, e, lines, vars_for(sim, e, extra))

## Algo aconteceu com `anchor` (jogador ou bot) no grupo do jogador: um bot reage (ou `speaker`, se dado).
## Ritmo: o mesmo evento só de `PARTY_REACT_CD` em `PARTY_REACT_CD` (por bot, quando é o bot que fala de si), fila com
## tempo de "digitação" e `PARTY_CHAT_GAP` entre falas. Devolve se a fala entrou na fila.
static func party_event(sim, anchor: SimEntity, kind: String, extra: Dictionary = {}, speaker: SimEntity = null, chance: float = 1.0) -> bool:
	if sim.player == null or anchor == null or anchor.party_id < 0 or anchor.party_id != sim.player.party_id:
		return false
	var p: Dictionary = PartySystem.party_of(sim, anchor)
	if p.is_empty():
		return false
	var react: Dictionary = p.get_or_add("react", {})
	var key := kind if speaker == null else "%s:%d" % [kind, speaker.id]
	if sim.time < float(react.get(key, -1.0e9)):
		return false
	if speaker == null:
		speaker = _any_bot(sim, p, anchor)
	if speaker == null or speaker.kind != SimEntity.Kind.BOT or sim.rng.randf() > chance:
		return false
	var line := party_line(sim, speaker, kind, extra)
	if line == "":
		return false
	react[key] = sim.time + Balance.PARTY_REACT_CD
	_queue(sim, p, speaker, line, sim.rng.randf_range(Balance.PARTY_REACT_DELAY.x, Balance.PARTY_REACT_DELAY.y))
	return true

## Jogador falou no grupo (/p): um bot responde conforme as palavras (obrigado, bora, espera, oi, pergunta).
static func party_reply(sim, text: String) -> bool:
	var pl: SimEntity = sim.player
	if pl == null or pl.party_id < 0 or sim.rng.randf() > 0.6:
		return false
	var p: Dictionary = PartySystem.party_of(sim, pl)
	var b := _any_bot(sim, p, pl)
	if b == null:
		return false
	var kind := reply_kind(text)
	_queue(sim, p, b, party_line(sim, b, kind), sim.rng.randf_range(1.0, 3.0))
	return true

static func reply_kind(text: String) -> String:
	var low := text.to_lower()
	for kind in BotsCatalog.REPLY_KEYS:
		for w in BotsCatalog.REPLY_KEYS[kind]:
			if low.contains(w):
				return kind
	return "reply_ask" if low.ends_with("?") else "reply"

## Um tique: solta as falas da fila e, a cada `PARTY_CHAT_SCAN`, olha o jogador (vida, chefe, colheita, investida) e a conversa solta.
static func update(sim) -> void:
	var pl: SimEntity = sim.player
	if pl == null or pl.party_id < 0:
		return
	var p: Dictionary = PartySystem.party_of(sim, pl)
	if p.is_empty():
		return
	_flush(sim, p)
	if sim.time < float(p.get("scan_at", 0.0)):
		return
	p["scan_at"] = sim.time + Balance.PARTY_CHAT_SCAN
	if not p.has("idle_next"):
		p["idle_next"] = sim.time + sim.rng.randf_range(Balance.PARTY_CHAT_MIN * 0.3, Balance.PARTY_CHAT_MAX * 0.5)
	if pl.is_alive():
		if pl.hp < pl.stats.max_hp * Balance.PARTY_CHAT_LOW_HP:
			party_event(sim, pl, "player_low")
		var boss := near_boss(sim, pl)
		if boss and boss.id != int(p.get("boss_seen", -1)) and (boss.aggro_target >= 0 or pl.combat_timer > 0.0):
			p["boss_seen"] = boss.id
			party_event(sim, pl, "boss_fight", {"boss": boss.monster_def.name})
		var gathering := pl.gather_left > 0.0
		if gathering and not p.get("gathering", false):
			party_event(sim, pl, "gather", {}, null, 0.5)
		p["gathering"] = gathering
		var rs: Dictionary = sim.raid_status(pl.map_id)
		if bool(rs.get("active", false)) and int(rs["wave"]) != int(p.get("raid_seen", -1)):
			p["raid_seen"] = int(rs["wave"])
			party_event(sim, pl, "raid")
	if sim.time >= float(p["idle_next"]) and (p.get("queue", []) as Array).is_empty():
		p["idle_next"] = sim.time + sim.rng.randf_range(Balance.PARTY_CHAT_MIN, Balance.PARTY_CHAT_MAX)
		var b := _any_bot(sim, p, pl, true)
		if b:
			_queue(sim, p, b, idle_line(sim, b), 0.0)

## Conversa solta no grupo: com o jogador (vila, caçada, dungeon), às vezes do lugar/classe.
static func idle_line(sim, b: SimEntity) -> String:
	var def: MapDef = sim.maps[b.map_id]["def"]
	if sim.rng.randf() < 0.3:
		return ambient_line(sim, b, false)
	var kind := "hunt"
	if def.in_hub(b.position) or def.interior:
		kind = "town"
	elif def.parent_map != "":
		kind = "dungeon"
	return party_line(sim, b, kind)

## Bot do grupo para falar: vivo, não `skip`; prefere quem está no mapa do jogador.
static func _any_bot(sim, p: Dictionary, skip: SimEntity, alive_only: bool = false) -> SimEntity:
	var near: Array = []
	var far: Array = []
	for id in p.get("members", []):
		var o: SimEntity = sim.entities.get(id)
		if o == null or o == skip or o.kind != SimEntity.Kind.BOT or (alive_only and not o.is_alive()):
			continue
		if sim.player and o.map_id == sim.player.map_id and o.is_alive():
			near.append(o)
		else:
			far.append(o)
	var arr := near if not near.is_empty() else far
	return arr[sim.rng.randi() % arr.size()] if not arr.is_empty() else null

static func _queue(sim, p: Dictionary, e: SimEntity, line: String, delay: float) -> void:
	if line == "":
		return
	var q: Array = p.get_or_add("queue", [])
	if q.size() >= 3:
		return                                  # muita coisa ao mesmo tempo: o grupo não vira spam
	q.append({"at": sim.time + delay, "id": e.id, "text": line})

static func _flush(sim, p: Dictionary) -> void:
	var q: Array = p.get("queue", [])
	if q.is_empty() or sim.time < float(p.get("chat_next", 0.0)):
		return
	var it: Dictionary = q[0]
	if sim.time < float(it["at"]):
		return
	q.pop_front()
	var e: SimEntity = sim.entities.get(int(it["id"]))
	if e == null or e.party_id != p["id"] or sim.time > float(it["at"]) + 10.0:
		return                                  # saiu do grupo ou a fala envelheceu
	p["chat_next"] = sim.time + Balance.PARTY_CHAT_GAP
	Events.chat_message.emit(e.name, str(it["text"]), "party")
