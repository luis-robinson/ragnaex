class_name GuildBankSystem
extends RefCounted
## Banco da Guilda (design/gdd/banco-da-guilda.md; decisões §9): baú compartilhado que os bots da guilda enchem (pulso de
## depósito a cada GBANK_TICK min do relógio social), retiradas por hora pela patente, Contribuição e patentes, encomendas
## (bots saem do mundo e voltam com o resultado reservado para o jogador) e o quadro de pedidos dos bots.
## Estado em `sim.gbank` (WorldSim); números em Balance.GBANK_*; falas em BotsCatalog.GBANK_LINES.
## Relógio = `sim.social["clock"]` (RosterSystem: só anda com o jogo aberto). Passada: RosterSystem.update -> update().
##
## Item do banco: {uid, id, count, by (nome de quem pôs), player (o jogador pôs), contrib (Contribuição que deu, por
## unidade), at (relógio), res (id da encomenda que o reservou para o jogador; 0 = livre)}.
## Encomenda: {id, kind ("card"|"material"), target (id), rids, names, hours, fee, start, ends, map, state ("out"|"back"),
## result: {items: [[id, n]], gold, text, rid, name, class}}. Pedido: {id, rid, name, kind ("material"|"card"|"kill"),
## target, count, state ("open"|"accepted"), gold, item, item_n, contrib}.

const TABS := ["gear", "card", "material", "consumable"]

# ---------------------------------------------------------------------------
# ESTADO

static func _defaults(sim: WorldSim) -> Dictionary:
	var b := sim.gbank
	b.get_or_add("items", [])
	b.get_or_add("gold", 0)
	b.get_or_add("log", [])
	b.get_or_add("contrib", 0)
	b.get_or_add("takes", -1.0)            # -1 = ainda não começou (enche uma hora na 1ª passada)
	b.get_or_add("gold_left", -1.0)
	b.get_or_add("missions", [])
	b.get_or_add("requests", [])
	b.get_or_add("next_pulse", -1.0)
	b.get_or_add("next_req", -1.0)
	b.get_or_add("seq", 0)
	b.get_or_add("welcomed", false)
	b.get_or_add("rank", 0)
	b.get_or_add("gift_at", {})            # rid -> relógio do último presente (lembrança "presente")
	return b

static func _clock(sim: WorldSim) -> float:
	return float(sim.social.get("clock", 0.0))

static func _next_id(sim: WorldSim) -> int:
	sim.gbank["seq"] = int(sim.gbank.get("seq", 0)) + 1
	return int(sim.gbank["seq"])

## Guilda do jogador (dicionário vivo em sim.guilds) ou {}.
static func guild(sim: WorldSim) -> Dictionary:
	if not sim.roster_on or sim.player == null:
		return {}
	var gid: String = sim.social.get("player_guild", "")
	return sim.guilds.get(gid, {}) if gid != "" else {}

## Bots do elenco na guilda do jogador (entradas do elenco).
static func members(sim: WorldSim) -> Array:
	var g := guild(sim)
	if g.is_empty():
		return []
	var out: Array = []
	for m in g["members"]:
		var r := RosterSystem.entry(sim, int(m["rid"])) if int(m["rid"]) >= 0 else {}
		if not r.is_empty():
			out.append(r)
	return out

# ---------------------------------------------------------------------------
# PATENTE

## Índice da patente para a Contribuição `c` (Balance.GBANK_RANKS).
static func rank_for(c: int) -> int:
	var i := 0
	for k in Balance.GBANK_RANKS.size():
		if c >= int(Balance.GBANK_RANKS[k]["contrib"]):
			i = k
	return i

static func rank(sim: WorldSim) -> int:
	return rank_for(int(sim.gbank.get("contrib", 0)))

static func rank_info(sim: WorldSim) -> Dictionary:
	return Balance.GBANK_RANKS[rank(sim)]

static func _rank_index(id: String) -> int:
	for k in Balance.GBANK_RANKS.size():
		if Balance.GBANK_RANKS[k]["id"] == id:
			return k
	return 0

## Contribuição mudou: patente refeita (a etiqueta da guilda acompanha; "lider" fica no fundador) e os bots comentam a subida.
static func _contrib_changed(sim: WorldSim) -> void:
	var b := sim.gbank
	var now := rank(sim)
	var before := int(b.get("rank", 0))
	b["rank"] = now
	var g := guild(sim)
	if not g.is_empty():
		g["contribution"] = int(b["contrib"])
		if str(g.get("player_rank", "")) != "lider":
			g["player_rank"] = Balance.GBANK_RANKS[now]["id"]
	if now > before:
		var nm: String = Balance.GBANK_RANKS[now]["name"]
		Events.post(&"notification", "Patente nova na guilda: %s" % nm)
		_log(sim, "%s subiu para %s." % [sim.player.name, nm])
		_mate_says(sim, "rank_up", {"rank": nm})
		Events.post(&"guild_changed", str(g.get("id", "")))

# ---------------------------------------------------------------------------
# PASSADA

## Relógio social andou `step` s (RosterSystem.update): retiradas, pulso de depósito, encomendas, pedidos.
static func update(sim: WorldSim, step: float) -> void:
	if guild(sim).is_empty():
		_missions_update(sim)                  # quem saiu numa encomenda volta mesmo sem guilda
		return
	var b := _defaults(sim)
	var clock := _clock(sim)
	var ri := rank_info(sim)
	var cap_h: float = Balance.GBANK_TAKE_CAP_H
	if float(b["takes"]) < 0.0:
		b["takes"] = float(ri["takes"])
		b["gold_left"] = float(ri["gold"])
	b["takes"] = minf(float(ri["takes"]) * cap_h, float(b["takes"]) + float(ri["takes"]) * step / 3600.0)
	b["gold_left"] = minf(float(ri["gold"]) * cap_h, float(b["gold_left"]) + float(ri["gold"]) * step / 3600.0)
	if float(b["next_pulse"]) < 0.0:
		b["next_pulse"] = clock + Balance.GBANK_FIRST_PULSE
	if clock >= float(b["next_pulse"]):
		b["next_pulse"] = clock + Balance.GBANK_TICK * 60.0
		pulse(sim)
	_missions_update(sim)
	if float(b["next_req"]) < 0.0 or clock >= float(b["next_req"]):
		b["next_req"] = clock + Balance.GBANK_REQUEST_REFRESH * 60.0
		refresh_requests(sim)

## Força da guilda F = média dos níveis dos bots; R = max(F, nível do jogador) - 2 (§4).
static func strength(sim: WorldSim) -> float:
	var ms := members(sim)
	if ms.is_empty():
		return float(sim.player.level)
	var s := 0.0
	for r: Dictionary in ms:
		var e := RosterSystem.entity_of(sim, r)
		s += float(e.level if e else int(r["level"]))
	return s / ms.size()

static func ref_level(sim: WorldSim) -> int:
	return clampi(int(round(maxf(strength(sim), float(sim.player.level)))) - Balance.GBANK_REF_DROP, 1, Balance.MAX_LEVEL)

static func tier_of(level: int) -> int:
	var t := 0
	for i in Balance.COMMON_TIER_LEVELS.size():
		if level >= int(Balance.COMMON_TIER_LEVELS[i]):
			t = i
	return t

## Pesos [comum, raro, lendário] pela força F (interpolação de GBANK_RARITY_BY_F).
static func rarity_weights(f: float) -> Array:
	var tab: Array = Balance.GBANK_RARITY_BY_F
	if f <= float(tab[0][0]):
		return (tab[0][1] as Array).duplicate()
	for i in range(1, tab.size()):
		if f <= float(tab[i][0]):
			var t := (f - float(tab[i - 1][0])) / (float(tab[i][0]) - float(tab[i - 1][0]))
			var out: Array = []
			for k in 3:
				out.append(lerpf(float(tab[i - 1][1][k]), float(tab[i][1][k]), t))
			return out
	return (tab.back()[1] as Array).duplicate()

## Um pulso de depósito: cada bot da guilda que está no mundo põe 0-2 coisas úteis aos outros + ouro; alguns tiram o
## que serve à build deles. A 1ª vez (guilda nova / save antigo) entram GBANK_WELCOME itens de boas-vindas.
static func pulse(sim: WorldSim) -> void:
	var b := _defaults(sim)
	var ms := members(sim).filter(func(r: Dictionary): return RosterSystem.entity_of(sim, r) != null)
	if ms.is_empty():
		return
	if not bool(b["welcomed"]):
		b["welcomed"] = true
		var n := sim.rng.randi_range(Balance.GBANK_WELCOME.x, Balance.GBANK_WELCOME.y)
		for i in n:
			_bot_deposit(sim, ms[i % ms.size()], false)
	for r: Dictionary in ms:
		var w: Array = Balance.GBANK_DEPOSIT_WEIGHTS
		var roll := sim.rng.randf() * (float(w[0]) + float(w[1]) + float(w[2]))
		var n := 0 if roll < float(w[0]) else (1 if roll < float(w[0]) + float(w[1]) else 2)
		for i in n:
			_bot_deposit(sim, r, true)
		var gold := Balance.GBANK_GOLD_PER_BOT * int(r["level"])
		b["gold"] = int(b["gold"]) + gold
	for r: Dictionary in ms:
		if sim.rng.randf() < Balance.GBANK_BOT_TAKE_CHANCE:
			_bot_take(sim, r)
	_trim(sim)
	Events.post(&"guild_bank_changed")

## Escolhe e põe um item pelo bot `r`.
static func _bot_deposit(sim: WorldSim, r: Dictionary, chat: bool) -> void:
	var pick := roll_item(sim, r)
	if pick.is_empty():
		return
	var it: ItemDef = GameData.items[pick["id"]]
	_add(sim, pick["id"], int(pick["count"]), str(r["name"]), false, 0, 0)
	_log(sim, "%s depositou: %s%s" % [r["name"], it.name, (" x%d" % int(pick["count"])) if int(pick["count"]) > 1 else ""])
	if chat and sim.rng.randf() < Balance.GBANK_CHAT_CHANCE:
		_say(sim, r, "deposit", {"item": it.name})

## Sorteio do que o bot `r` deposita: {id, count} ({} = nada). Tipo por GBANK_KIND_WEIGHTS; pergaminho sem item = material.
static func roll_item(sim: WorldSim, r: Dictionary) -> Dictionary:
	var R := ref_level(sim)
	var tier := tier_of(R)
	var kinds: Dictionary = Balance.GBANK_KIND_WEIGHTS
	var total := 0.0
	for k in kinds:
		total += float(kinds[k])
	var x := sim.rng.randf() * total
	var kind := "material"
	for k in kinds:
		x -= float(kinds[k])
		if x < 0.0:
			kind = k
			break
	match kind:
		"gear":
			var id := _roll_gear(sim, r, R, tier)
			if id != "":
				return {"id": id, "count": 1}
		"card":
			var id := _roll_card(sim, R)
			if id != "":
				return {"id": id, "count": 1}
		"consumable":
			var opts: Array = Balance.GBANK_CONSUMABLES.filter(func(c): return int(c[0]) <= R and GameData.items.has(str(c[1])))
			if not opts.is_empty():
				var c: Array = opts[sim.rng.randi() % opts.size()]
				return {"id": str(c[1]), "count": sim.rng.randi_range(Balance.GBANK_CONS_COUNT.x, Balance.GBANK_CONS_COUNT.y)}
		"scroll":
			var sc: Array = Balance.GBANK_SCROLLS.filter(func(s): return GameData.items.has(str(s)))     # pergaminho ainda não existe: pula
			if not sc.is_empty():
				return {"id": str(sc[sim.rng.randi() % sc.size()]), "count": 1}
	var mats := band_materials(tier)
	if mats.is_empty():
		return {}
	return {"id": mats[sim.rng.randi() % mats.size()], "count": sim.rng.randi_range(Balance.GBANK_MAT_COUNT.x, Balance.GBANK_MAT_COUNT.y)}

## Materiais de refino/receita do tier (joias + capas).
static func band_materials(tier: int) -> Array:
	var out: Array = []
	for lst in [RecipesCatalog.JEWEL_MATS, RecipesCatalog.CAPE_MATS]:
		if tier < (lst as Array).size():
			for id in lst[tier]:
				if GameData.items.has(id) and not (id in out):
					out.append(id)
	return out

## Classe usa o item (sem SimEntity: o mesmo teste de LootSystem.fits_class).
static func class_fits(cls: ClassDef, it: ItemDef) -> bool:
	if cls == null:
		return false
	if it.class_restriction.size() > 0 and not (cls.id in it.class_restriction):
		return false
	if it.slot == ItemDef.Slot.WEAPON:
		return it.weapon_type in cls.weapon_types
	if it.slot == ItemDef.Slot.OFFHAND:
		return it.weapon_type in cls.offhand_types
	return true

## Equipamento para OUTRO membro (o jogador conta), do tier de R; raridade pela força (lendário só com patente GBANK_LEGEND_RANK).
static func _roll_gear(sim: WorldSim, giver: Dictionary, R: int, tier: int) -> String:
	var who: Array = [[sim.player.class_def, sim.player.build_id]]
	for r: Dictionary in members(sim):
		if r["rid"] != giver["rid"]:
			who.append([GameData.classes.get(r["class"]), str(r["build"])])
	var target: Array = who[sim.rng.randi() % who.size()]
	var cls: ClassDef = target[0]
	var w := rarity_weights(strength(sim))
	if rank(sim) < _rank_index(Balance.GBANK_LEGEND_RANK):
		w[1] = float(w[1]) + float(w[2])
		w[2] = 0.0
	var x := sim.rng.randf() * (float(w[0]) + float(w[1]) + float(w[2]))
	if x >= float(w[0]) + float(w[1]):
		var legs: Array = []
		for lv in Balance.LEGENDARY_LEVELS:
			if int(lv) <= R and int(lv) < Balance.GBANK_LEGEND_MAX_LEVEL:
				legs = []
				var sd: SetDef = GameData.sets.get(GameData.set_id_for(cls.id, str(target[1]), int(lv)))
				if sd:
					legs.append_array(sd.pieces)
		if not legs.is_empty():
			return str(legs[sim.rng.randi() % legs.size()])
		x = 0.0
	var pool: Array
	if x >= float(w[0]):            # raro: capa/amuleto/anel do tier (feitos na forja; aqui de presente)
		var lo: int = Balance.COMMON_TIER_LEVELS[tier]
		var hi: int = Balance.COMMON_TIER_LEVELS[tier + 1] if tier + 1 < Balance.COMMON_TIER_LEVELS.size() else 99
		pool = []
		for iid in GameData.items:
			var it: ItemDef = GameData.items[iid]
			if it.is_equipment() and not it.is_legendary() and it.set_id == "" and it.base_id == "" and it.price > 0 \
					and it.slot in [ItemDef.Slot.CAPE, ItemDef.Slot.AMULET, ItemDef.Slot.RING] and it.level_req >= lo and it.level_req < hi:
				pool.append(it)
		if pool.is_empty():
			pool = LootSystem.gear_pool(sim, tier)
	else:
		pool = LootSystem.gear_pool(sim, tier)
	pool = pool.filter(func(it: ItemDef): return class_fits(cls, it))
	if pool.is_empty():
		return ""
	return (pool[sim.rng.randi() % pool.size()] as ItemDef).id

## Carta do tier de R (núcleo raro; chefe nunca).
static func _roll_card(sim: WorldSim, R: int) -> String:
	var ct := 0
	for lv in Balance.CARD_TIER_LEVELS:
		if R > int(lv):
			ct += 1
	var core := sim.rng.randf() < Balance.GBANK_CORE_CARD_CHANCE
	var ids: Array = []
	for cid in GameData.cards:
		var cd: CardDef = GameData.cards[cid]
		if cd.boss or cd.core != core or cd.tier > ct or cd.tier < ct - 1 or not GameData.items.has(cid):
			continue
		ids.append(cid)
	ids.sort()
	return str(ids[sim.rng.randi() % ids.size()]) if not ids.is_empty() else ""

## Bot tira um item que serve à build dele (nunca o reservado; nunca o que ele mesmo pôs).
static func _bot_take(sim: WorldSim, r: Dictionary) -> void:
	var cls: ClassDef = GameData.classes.get(r["class"])
	var items: Array = sim.gbank["items"]
	for i in items.size():
		var bi: Dictionary = items[i]
		if int(bi["res"]) != 0 or str(bi["by"]) == str(r["name"]):
			continue
		var it: ItemDef = GameData.items.get(bi["id"])
		if it == null or not it.is_equipment() or it.level_req > int(r["level"]) or it.level_req < int(r["level"]) - Balance.GBANK_BOT_TAKE_SPAN \
				or not class_fits(cls, it):
			continue
		items.remove_at(i)
		_log(sim, "%s pegou: %s" % [r["name"], it.name])
		return

# ---------------------------------------------------------------------------
# ITENS DO BANCO

## Põe no banco (empilha material/consumível dos bots com o mesmo id).
static func _add(sim: WorldSim, id: String, count: int, by: String, by_player: bool, contrib: int, res: int) -> Dictionary:
	var items: Array = sim.gbank["items"]
	var it: ItemDef = GameData.items[id]
	if not by_player and res == 0 and not it.is_equipment() and it.type != ItemDef.Type.CARD:
		for bi: Dictionary in items:
			if bi["id"] == id and not bool(bi["player"]) and int(bi["res"]) == 0:
				bi["count"] = int(bi["count"]) + count
				bi["at"] = _clock(sim)
				return bi
	var bi := {"uid": _next_id(sim), "id": id, "count": count, "by": by, "player": by_player, "contrib": contrib, "at": _clock(sim), "res": res}
	items.append(bi)
	return bi

## Teto GBANK_SLOTS (reservado não conta): sai o mais barato entre os GBANK_EVICT_WINDOW mais velhos.
static func _trim(sim: WorldSim) -> void:
	var items: Array = sim.gbank["items"]
	while true:
		var free: Array = items.filter(func(x: Dictionary): return int(x["res"]) == 0)
		if free.size() <= Balance.GBANK_SLOTS:
			return
		free.sort_custom(func(a: Dictionary, b2: Dictionary): return float(a["at"]) < float(b2["at"]) or (float(a["at"]) == float(b2["at"]) and int(a["uid"]) < int(b2["uid"])))
		var win := free.slice(0, Balance.GBANK_EVICT_WINDOW)
		var worst: Dictionary = win[0]
		for x: Dictionary in win:
			if _value(x) < _value(worst):
				worst = x
		items.erase(worst)

static func _value(bi: Dictionary) -> int:
	var it: ItemDef = GameData.items.get(bi["id"])
	return (it.price if it else 0) * int(bi["count"])

static func _find(sim: WorldSim, uid: int) -> Dictionary:
	for bi: Dictionary in sim.gbank.get("items", []):
		if int(bi["uid"]) == uid:
			return bi
	return {}

## Aba do banco de um item: gear | card | material | consumable.
static func tab_of(it: ItemDef) -> String:
	if it.is_equipment():
		return "gear"
	if it.type == ItemDef.Type.CARD:
		return "card"
	if it.type == ItemDef.Type.CONSUMABLE:
		return "consumable"
	return "material"

static func _log(sim: WorldSim, text: String) -> void:
	var lg: Array = sim.gbank["log"]
	lg.append({"at": _clock(sim), "text": text})
	while lg.size() > Balance.GBANK_LOG_MAX:
		lg.pop_front()

# ---------------------------------------------------------------------------
# JOGADOR: TIRAR, DEPOSITAR, OURO

## Por que o jogador não mexe no banco agora ("" = pode): guilda + cidade com cristal (§9.1).
static func where_error(sim: WorldSim) -> String:
	if guild(sim).is_empty():
		return "Você não está em uma guilda."
	var pl := sim.player
	if not pl.is_alive():
		return "Indisponível agora."
	if pl.map_id != GameData.town_map_id() and not MapsCatalog.CRYSTALS.has(pl.map_id):
		return "O banco abre em qualquer cidade com cristal de retorno."
	return ""

## Segundos até a próxima retirada (0 = tem retirada).
static func next_take_in(sim: WorldSim) -> float:
	var t := float(sim.gbank.get("takes", 0.0))
	if t >= 1.0:
		return 0.0
	var per_h := float(rank_info(sim)["takes"])
	return (1.0 - maxf(t, 0.0)) * 3600.0 / per_h

## Retiradas inteiras disponíveis.
static func takes_left(sim: WorldSim) -> int:
	return int(floor(maxf(0.0, float(sim.gbank.get("takes", 0.0)))))

static func _mmss(s: float) -> String:
	var m := int(ceil(s / 60.0))
	return "%d min" % m if m < 60 else "%d h %02d min" % [m / 60, m % 60]

## Unidades que uma retirada leva do item (pilha até GBANK_STACK_TAKE).
static func take_count(bi: Dictionary) -> int:
	var it: ItemDef = GameData.items.get(bi["id"])
	if it == null or it.is_equipment():
		return 1
	return mini(int(bi["count"]), Balance.GBANK_STACK_TAKE)

static func take_error(sim: WorldSim, uid: int) -> String:
	_defaults(sim)
	var err := where_error(sim)
	if err != "":
		return err
	var bi := _find(sim, uid)
	if bi.is_empty():
		return "Esse item não está mais no banco."
	if int(bi["res"]) != 0:
		return "Reservado de encomenda: use \"Pôr na bolsa\" no aviso."
	if sim.player.bag_full_for(bi["id"]):
		return "Bolsa cheia."
	if takes_left(sim) < 1:
		return "Sem retiradas agora: a próxima em %s." % _mmss(next_take_in(sim))
	return ""

## Tira o item `uid` (1 retirada; pilha até GBANK_STACK_TAKE). Tirar de volta o que você pôs devolve a Contribuição.
static func take(sim: WorldSim, uid: int) -> String:
	var err := take_error(sim, uid)
	if err != "":
		return err
	var b := sim.gbank
	var bi := _find(sim, uid)
	var n := take_count(bi)
	b["takes"] = float(b["takes"]) - 1.0
	if bool(bi["player"]) and int(bi["contrib"]) > 0:
		b["contrib"] = maxi(0, int(b["contrib"]) - int(bi["contrib"]) * n)
		_contrib_changed(sim)
	bi["count"] = int(bi["count"]) - n
	if int(bi["count"]) <= 0:
		(b["items"] as Array).erase(bi)
	sim.player.add_item(bi["id"], n)
	var it: ItemDef = GameData.items[bi["id"]]
	_log(sim, "%s pegou: %s%s" % [sim.player.name, it.name, (" x%d" % n) if n > 1 else ""])
	Events.post(&"guild_bank_changed")
	return ""

## Contribuição de UMA unidade de `it` (§4): preço × taxa × multiplicador do lendário, com mínimos.
static func contrib_of(it: ItemDef) -> int:
	var v := float(it.price) * Balance.GBANK_CONTRIB_RATE * (Balance.GBANK_CONTRIB_LEGEND_MULT if it.is_legendary() else 1.0)
	var mins: Dictionary = Balance.GBANK_CONTRIB_MIN
	if it.is_legendary():
		v = maxf(v, float(mins["legend"]))
	elif it.type == ItemDef.Type.CARD:
		var cd: CardDef = GameData.cards.get(it.id)
		v = maxf(v, float(mins["core_card"] if cd and cd.core else mins["card"]))
	return maxi(1, int(round(v)))

## Bot da guilda que usaria o item (equipamento da classe e da faixa dele) ou {}.
static func user_of(sim: WorldSim, it: ItemDef) -> Dictionary:
	if not it.is_equipment():
		return {}
	for r: Dictionary in members(sim):
		if class_fits(GameData.classes.get(r["class"]), it) and it.level_req <= int(r["level"]) + Balance.GBANK_USER_SLACK:
			return r
	return {}

static func deposit_error(sim: WorldSim, item_id: String, count: int) -> String:
	_defaults(sim)
	var err := where_error(sim)
	if err != "":
		return err
	var it: ItemDef = GameData.items.get(item_id)
	if it == null or count <= 0 or not sim.player.has_item(item_id, count):
		return "Você não tem isso na bolsa."
	if it.type == ItemDef.Type.QUEST:
		return "Item de missão não vai para o banco."
	return ""

## Jogador deposita `count` de `item_id` da bolsa: Contribuição (+50% e afinidade se um bot da guilda usa).
static func deposit(sim: WorldSim, item_id: String, count: int = 1) -> String:
	var err := deposit_error(sim, item_id, count)
	if err != "":
		return err
	var it: ItemDef = GameData.items[item_id]
	var per := contrib_of(it)
	var user := user_of(sim, it)
	if not user.is_empty():
		per = int(round(per * Balance.GBANK_USER_BONUS))
	sim.player.remove_item(item_id, count)
	var b := sim.gbank
	if it.is_equipment() or it.type == ItemDef.Type.CARD:
		for i in count:
			_add(sim, item_id, 1, sim.player.name, true, per, 0)
	else:
		_add(sim, item_id, count, sim.player.name, true, per, 0)
	b["contrib"] = int(b["contrib"]) + per * count
	_log(sim, "%s depositou: %s%s (+%d)" % [sim.player.name, it.name, (" x%d" % count) if count > 1 else "", per * count])
	if not user.is_empty():
		var gift: Dictionary = b["gift_at"]
		var key := str(user["rid"])
		if _clock(sim) >= float(gift.get(key, -1.0e9)) + Balance.GBANK_GIFT_MEMORY_CD * 60.0:
			gift[key] = _clock(sim)
			RosterSystem.remember(sim, user, "presente", {"item": it.name})
	_trim(sim)
	_contrib_changed(sim)
	Events.post(&"guild_bank_changed")
	return ""

## Ouro que o jogador pode tirar agora (limite da patente por hora e o cofre).
static func gold_can_take(sim: WorldSim) -> int:
	return mini(int(sim.gbank.get("gold", 0)), int(floor(maxf(0.0, float(sim.gbank.get("gold_left", 0.0))))))

static func take_gold(sim: WorldSim, amount: int) -> String:
	_defaults(sim)
	var err := where_error(sim)
	if err != "":
		return err
	if amount <= 0:
		return "Quantia inválida."
	if amount > int(sim.gbank["gold"]):
		return "O cofre não tem isso."
	if amount > gold_can_take(sim):
		return "Limite de ouro da patente: %d agora." % gold_can_take(sim)
	sim.gbank["gold"] = int(sim.gbank["gold"]) - amount
	sim.gbank["gold_left"] = float(sim.gbank["gold_left"]) - amount
	sim.player.gold += amount
	_log(sim, "%s pegou %d de ouro." % [sim.player.name, amount])
	Events.post(&"guild_bank_changed")
	return ""

## Jogador põe ouro: Contribuição GBANK_CONTRIB_GOLD por moeda.
static func deposit_gold(sim: WorldSim, amount: int) -> String:
	_defaults(sim)
	var err := where_error(sim)
	if err != "":
		return err
	if amount <= 0 or amount > sim.player.gold:
		return "Você não tem esse ouro."
	sim.player.gold -= amount
	sim.gbank["gold"] = int(sim.gbank["gold"]) + amount
	var c := int(floor(amount * Balance.GBANK_CONTRIB_GOLD))
	sim.gbank["contrib"] = int(sim.gbank["contrib"]) + c
	_log(sim, "%s depositou %d de ouro (+%d)." % [sim.player.name, amount, c])
	_contrib_changed(sim)
	Events.post(&"guild_bank_changed")
	return ""

# ---------------------------------------------------------------------------
# ENCOMENDAS (§3.7, §9.3, §9.4)

static func missions_max(sim: WorldSim) -> int:
	return int(rank_info(sim)["missions"])

static func active_missions(sim: WorldSim) -> Array:
	return (sim.gbank.get("missions", []) as Array).filter(func(m: Dictionary): return m["state"] == "out")

## O bot `rid` está fora numa encomenda: segundos que faltam (0 = não está).
static func away_left(sim: WorldSim, rid: int) -> float:
	for m: Dictionary in sim.gbank.get("missions", []):
		if m["state"] == "out" and rid in (m["rids"] as Array):
			return maxf(0.001, float(m["ends"]) - _clock(sim))
	return 0.0

static func is_away(sim: WorldSim, rid: int) -> bool:
	return away_left(sim, rid) > 0.0

## O que dá para encomendar: cartas de monstro que o jogador já viu e materiais da faixa dele.
static func mission_targets(sim: WorldSim) -> Dictionary:
	var cards: Array = []
	for mid in sim.player.bestiary:
		var cid := str(GameData.card_of.get(mid, ""))
		if cid != "" and GameData.cards.has(cid) and not (GameData.cards[cid] as CardDef).boss and not (cid in cards):
			cards.append(cid)
	cards.sort()
	return {"card": cards, "material": band_materials(tier_of(sim.player.level))}

static func fee(sim: WorldSim, hours: float, n_bots: int) -> int:
	return int(round(Balance.GBANK_MISSION_FEE * hours * n_bots * maxf(1.0, sim.player.level / 10.0)))

static func mission_error(sim: WorldSim, kind: String, target: String, rids: Array, time_i: int) -> String:
	_defaults(sim)
	if guild(sim).is_empty():
		return "Você não está em uma guilda."
	if rank(sim) < _rank_index(Balance.GBANK_MISSION_RANK):
		return "Encomendas a partir de %s." % Balance.GBANK_RANKS[_rank_index(Balance.GBANK_MISSION_RANK)]["name"]
	if active_missions(sim).size() >= missions_max(sim):
		return "Encomendas em andamento: %d de %d." % [active_missions(sim).size(), missions_max(sim)]
	if time_i < 0 or time_i >= Balance.GBANK_MISSION_TIMES.size():
		return "Escolha o tempo."
	var tg := mission_targets(sim)
	if not (kind in ["card", "material"]) or not (target in (tg[kind] as Array)):
		return "Escolha o que buscar."
	if rids.is_empty() or rids.size() > Balance.GBANK_MISSION_BOTS:
		return "Escolha de 1 a %d bots." % Balance.GBANK_MISSION_BOTS
	var mids: Array = members(sim).map(func(r: Dictionary): return int(r["rid"]))
	for rid in rids:
		var r := RosterSystem.entry(sim, int(rid))
		if not (int(rid) in mids) or r.is_empty():
			return "Só bots da guilda vão."
		if is_away(sim, int(rid)):
			return "%s já está fora numa encomenda." % r["name"]
		var e := RosterSystem.entity_of(sim, r)
		if e == null or not e.is_alive():
			return "%s não pode ir agora." % r["name"]
	var h := float(Balance.GBANK_MISSION_TIMES[time_i]) / 60.0
	if sim.player.gold < fee(sim, h, rids.size()):
		return "Ouro insuficiente para a taxa (%d)." % fee(sim, h, rids.size())
	return ""

## Manda os bots: paga a taxa, os bots saem do mundo (despawn) até a volta. Devolve "" ou o motivo.
static func mission_start(sim: WorldSim, kind: String, target: String, rids: Array, time_i: int) -> String:
	var err := mission_error(sim, kind, target, rids, time_i)
	if err != "":
		return err
	var mins := float(Balance.GBANK_MISSION_TIMES[time_i])
	var h := mins / 60.0
	var cost := fee(sim, h, rids.size())
	sim.player.gold -= cost
	var names: Array = []
	var lv := 0.0
	for rid in rids:
		var r := RosterSystem.entry(sim, int(rid))
		names.append(r["name"])
		lv += float(r["level"])
	var map_id := _mission_map(sim, kind, target, int(round(lv / rids.size())))
	var m := {"id": _next_id(sim), "kind": kind, "target": target, "rids": rids.map(func(x): return int(x)), "names": names, "hours": h,
		"fee": cost, "start": _clock(sim), "ends": _clock(sim) + mins * 60.0, "map": map_id, "level": lv / rids.size(), "state": "out", "result": {}}
	(sim.gbank["missions"] as Array).append(m)
	for rid in m["rids"]:
		var r := RosterSystem.entry(sim, rid)
		var e := RosterSystem.entity_of(sim, r)
		if e:
			sim.despawn(e)
		r["entity_id"] = -1
	var it: ItemDef = GameData.items.get(target)
	var md: MapDef = GameData.maps.get(map_id)
	var first := RosterSystem.entry(sim, int(m["rids"][0]))
	var text := "%s saiu para %s buscar %s." % [" e ".join(PackedStringArray(names)), md.name if md else "a caça", it.name if it else target]
	Events.post(&"chat_message", str(first.get("name", "Guilda")), text, "guild")
	_log(sim, text)
	Events.post(&"roster_changed")
	Events.post(&"guild_bank_changed")
	return ""

## Mapa para onde a encomenda vai: o do monstro da carta; material = zona de caça da faixa.
static func _mission_map(sim: WorldSim, kind: String, target: String, level: int) -> String:
	if kind == "card":
		var cd: CardDef = GameData.cards.get(target)
		var maps: Array = CardSystem.maps_of(cd.monster_id) if cd else []
		maps.sort()
		if not maps.is_empty():
			return str(maps[0])
	var ids: Array = GameData.maps.keys()
	ids.sort()
	for mid in ids:
		var md: MapDef = GameData.maps[mid]
		if not md.is_town and not md.interior and md.parent_map == "" and level >= md.level_range.x and level <= md.level_range.y:
			return str(mid)
	return GameData.town_map_id()

static func _missions_update(sim: WorldSim) -> void:
	var ms: Array = sim.gbank.get("missions", [])
	var back := false
	for m: Dictionary in ms:
		if m["state"] == "out" and _clock(sim) >= float(m["ends"]):
			_resolve(sim, m)
			back = true
	if back:
		RosterSystem.bind(sim)                     # os bots voltam ao mundo (povoado da faixa)
		Events.post(&"roster_changed")
		Events.post(&"guild_bank_changed")

## Fim da encomenda: resultado reservado para o jogador (nunca falha; carta não achada = metade da taxa + materiais).
static func _resolve(sim: WorldSim, m: Dictionary) -> void:
	m["state"] = "back"
	var n := (m["rids"] as Array).size()
	var h := float(m["hours"])
	var avg := float(m["level"])
	var items: Array = []
	var gold := 0
	var key := "back_material"
	var it: ItemDef = GameData.items.get(m["target"])
	if m["kind"] == "material":
		var band_lv := float(Balance.COMMON_TIER_LEVELS[_mat_tier(str(m["target"]))])
		var ratio := minf(avg / maxf(1.0, band_lv), Balance.GBANK_MISSION_LEVEL_CAP)
		items.append([m["target"], maxi(1, int(round(Balance.GBANK_MAT_PER_BOT_H * h * n * ratio)))])
	else:
		var cd: CardDef = GameData.cards.get(m["target"])
		var md: MonsterDef = GameData.monsters.get(cd.monster_id) if cd else null
		var f := clampf(avg / maxf(1.0, float(md.level if md else avg)), Balance.GBANK_CARD_FACTOR.x, Balance.GBANK_CARD_FACTOR.y)
		var p := minf(Balance.GBANK_CARD_CHANCE_MAX, h * Balance.GBANK_CARD_CHANCE_PER_H * f)
		var found := false
		for i in n:
			if sim.rng.randf() < p:
				found = true
		if found:
			items.append([m["target"], 1])
			key = "back_card"
		else:
			key = "back_miss"
			gold = int(m["fee"]) / 2
			var mat := _monster_material(md)
			if mat == "":
				var bm := band_materials(tier_of(int(avg)))
				mat = str(bm[0]) if not bm.is_empty() else ""
			if mat != "":
				items.append([mat, maxi(1, int(round(Balance.GBANK_CARD_MISS_MATS * h)))])
	for pair in items:
		_add(sim, str(pair[0]), int(pair[1]), str(m["names"][0]), false, 0, int(m["id"]))
	var r := RosterSystem.entry(sim, int(m["rids"][0]))
	var md2: MapDef = GameData.maps.get(m["map"])
	var first_it: ItemDef = GameData.items.get(items[0][0]) if not items.is_empty() else null
	var extra := {"map": md2.name if md2 else "a caça", "item": it.name if it else "", "n": str(items[0][1]) if not items.is_empty() else "0",
		"got": first_it.name if first_it else "", "gold": str(gold)}
	var text := line(sim, r if not r.is_empty() else {"personality": "calmo", "name": m["names"][0]}, key, extra)
	m["result"] = {"items": items, "gold": gold, "text": text, "rid": int(m["rids"][0]), "name": str(m["names"][0]),
		"class": str(r.get("class", "")), "kind": key}
	_log(sim, "%s voltou da encomenda." % " e ".join(PackedStringArray(m["names"])))
	Events.post(&"guild_mission_back", notice_of(m))

static func _mat_tier(id: String) -> int:
	for t in RecipesCatalog.JEWEL_MATS.size():
		if id in RecipesCatalog.JEWEL_MATS[t] or (t < RecipesCatalog.CAPE_MATS.size() and id in RecipesCatalog.CAPE_MATS[t]):
			return t
	return 0

static func _monster_material(md: MonsterDef) -> String:
	if md == null or md.loot_table == "" or not GameData.loot_tables.has(md.loot_table):
		return ""
	for en in (GameData.loot_tables[md.loot_table] as LootTable).entries:
		var it: ItemDef = GameData.items.get(str(en.get("item", "")))
		if it and it.type == ItemDef.Type.MATERIAL:
			return it.id
	return ""

## Aviso de volta (cartão à esquerda do minimapa) no formato da UI.
static func notice_of(m: Dictionary) -> Dictionary:
	var res: Dictionary = m["result"]
	var items: Array = res.get("items", [])
	return {"id": int(m["id"]), "rid": int(res.get("rid", -1)), "name": str(res.get("name", "")), "class": str(res.get("class", "")),
		"item": str(items[0][0]) if not items.is_empty() else "", "count": int(items[0][1]) if not items.is_empty() else 0,
		"items": items.duplicate(true), "gold": int(res.get("gold", 0)), "text": str(res.get("text", "")), "kind": str(res.get("kind", ""))}

## Avisos de volta ainda não recolhidos (mais velho primeiro).
static func notices(sim: WorldSim) -> Array:
	var out: Array = []
	for m: Dictionary in sim.gbank.get("missions", []):
		if m["state"] == "back":
			out.append(notice_of(m))
	return out

## "Pôr na bolsa": tudo da encomenda vai para a bolsa (sem retirada). Bolsa cheia = continua reservado no banco.
static func mission_collect(sim: WorldSim, mission_id: int) -> String:
	var ms: Array = sim.gbank.get("missions", [])
	var m: Dictionary = {}
	for x: Dictionary in ms:
		if int(x["id"]) == mission_id and x["state"] == "back":
			m = x
	if m.is_empty():
		return "Nada para pegar."
	var res: Array = (sim.gbank["items"] as Array).filter(func(bi: Dictionary): return int(bi["res"]) == mission_id)
	var new_ids := {}
	for bi: Dictionary in res:
		if not sim.player.inventory.has(bi["id"]):
			new_ids[bi["id"]] = true
	if sim.player.inventory.size() + new_ids.size() > sim.player.bag_capacity():
		return "Bolsa cheia: o item continua reservado no banco."
	for bi: Dictionary in res:
		sim.player.add_item(bi["id"], int(bi["count"]))
		(sim.gbank["items"] as Array).erase(bi)
	var gold := int(m["result"].get("gold", 0))
	if gold > 0:
		sim.player.gold += gold
	ms.erase(m)
	Events.post(&"guild_bank_changed")
	return ""

# ---------------------------------------------------------------------------
# PEDIDOS DOS BOTS (§3.8)

## Quadro novo (a cada GBANK_REQUEST_REFRESH min): GBANK_REQUESTS pedidos dos bots da guilda. Aceito continua.
static func refresh_requests(sim: WorldSim) -> void:
	var b := _defaults(sim)
	var keep: Array = (b["requests"] as Array).filter(func(q: Dictionary): return q["state"] == "accepted")
	var ms := members(sim).filter(func(r: Dictionary): return not is_away(sim, int(r["rid"])))
	if ms.is_empty():
		b["requests"] = keep
		return
	var n := sim.rng.randi_range(Balance.GBANK_REQUESTS.x, Balance.GBANK_REQUESTS.y)
	var lv := sim.player.level
	var tier := tier_of(lv)
	var bosses: Array = []
	for mid in GameData.monsters:
		var md: MonsterDef = GameData.monsters[mid]
		if md.is_boss and not md.dummy and not md.decoy and md.elite_of == "" and absi(md.level - lv) <= Balance.GBANK_REQUEST_BOSS_BAND \
				and not CardSystem.maps_of(md.id).is_empty():
			bosses.append(md.id)
	bosses.sort()
	var cards := mission_targets(sim)["card"] as Array
	var mats := band_materials(tier)
	var out: Array = keep
	for i in n:
		if out.size() >= Balance.GBANK_REQUESTS.y:
			break
		var r: Dictionary = ms[sim.rng.randi() % ms.size()]
		var roll := sim.rng.randi() % 3
		var q := {"id": _next_id(sim), "rid": int(r["rid"]), "name": str(r["name"]), "state": "open", "count": 1}
		if roll == 2 and not bosses.is_empty():
			q["kind"] = "kill"
			q["target"] = str(bosses[sim.rng.randi() % bosses.size()])
		elif roll == 1 and not cards.is_empty():
			q["kind"] = "card"
			q["target"] = str(cards[sim.rng.randi() % cards.size()])
		elif not mats.is_empty():
			q["kind"] = "material"
			q["target"] = str(mats[sim.rng.randi() % mats.size()])
			q["count"] = sim.rng.randi_range(Balance.GBANK_REQUEST_MATS.x, Balance.GBANK_REQUEST_MATS.y)
		else:
			continue
		q["gold"] = Balance.GBANK_REQUEST_GOLD_PER_LV * lv
		q["contrib"] = int(Balance.GBANK_REQUEST_CONTRIB[q["kind"]])
		var cons: Array = Balance.GBANK_CONSUMABLES.filter(func(c): return int(c[0]) <= lv and GameData.items.has(str(c[1])))
		q["item"] = str(cons.back()[1]) if not cons.is_empty() else ""
		q["item_n"] = Balance.GBANK_REQUEST_ITEM_N
		out.append(q)
	b["requests"] = out
	Events.post(&"guild_bank_changed")

## Pedidos do quadro com o texto pronto (UI).
static func requests(sim: WorldSim) -> Array:
	var out: Array = []
	for q: Dictionary in sim.gbank.get("requests", []):
		var o := q.duplicate()
		o["text"] = request_text(q)
		o["ready"] = q["kind"] != "kill" and sim.player.has_item(q["target"], int(q["count"]))
		out.append(o)
	return out

static func request_text(q: Dictionary) -> String:
	match q["kind"]:
		"kill":
			var md: MonsterDef = GameData.monsters.get(q["target"])
			return "%s pede ajuda: mate %s" % [q["name"], md.name if md else q["target"]]
		"card":
			var it: ItemDef = GameData.items.get(q["target"])
			return "%s quer a %s" % [q["name"], it.name if it else q["target"]]
	var it2: ItemDef = GameData.items.get(q["target"])
	return "%s precisa de %d %s" % [q["name"], int(q["count"]), it2.name if it2 else q["target"]]

static func _request(sim: WorldSim, id: int) -> Dictionary:
	for q: Dictionary in sim.gbank.get("requests", []):
		if int(q["id"]) == id:
			return q
	return {}

static func request_error(sim: WorldSim, id: int) -> String:
	_defaults(sim)
	if guild(sim).is_empty():
		return "Você não está em uma guilda."
	if rank(sim) < _rank_index(Balance.GBANK_REQUEST_RANK):
		return "Pedidos a partir de %s." % Balance.GBANK_RANKS[_rank_index(Balance.GBANK_REQUEST_RANK)]["name"]
	if _request(sim, id).is_empty():
		return "Esse pedido saiu do quadro."
	return ""

## Aceita o pedido (pedido de abate só conta depois de aceito).
static func request_accept(sim: WorldSim, id: int) -> String:
	var err := request_error(sim, id)
	if err != "":
		return err
	_request(sim, id)["state"] = "accepted"
	Events.post(&"guild_bank_changed")
	return ""

## Entrega (material/carta da bolsa). Abate se cumpre sozinho (on_boss_kill).
static func request_deliver(sim: WorldSim, id: int) -> String:
	var err := request_error(sim, id)
	if err != "":
		return err
	var q := _request(sim, id)
	if q["kind"] == "kill":
		return "Esse pedido se cumpre matando o chefe."
	if not sim.player.has_item(q["target"], int(q["count"])):
		return "Você não tem o que ele pediu."
	sim.player.remove_item(q["target"], int(q["count"]))
	_complete(sim, q)
	return ""

## Chefe morto com o jogador (RosterSystem.on_kill): cumpre os pedidos de abate aceitos dele.
static func on_boss_kill(sim: WorldSim, md: MonsterDef) -> void:
	if sim.gbank.is_empty():
		return
	for q: Dictionary in (sim.gbank.get("requests", []) as Array).duplicate():
		if q["kind"] == "kill" and q["state"] == "accepted" and q["target"] == md.id:
			_complete(sim, q)

## Prêmio: Contribuição, ouro + item do bot, lembrança "ajudou_pedido" (afinidade).
static func _complete(sim: WorldSim, q: Dictionary) -> void:
	var b := sim.gbank
	(b["requests"] as Array).erase(q)
	b["contrib"] = int(b["contrib"]) + int(q["contrib"])
	sim.player.gold += int(q["gold"])
	if str(q.get("item", "")) != "" and GameData.items.has(q["item"]):
		sim.player.add_item(q["item"], int(q["item_n"]))
	Events.post(&"notification", "Pedido de %s cumprido: +%d ouro, +%d Contribuição" % [q["name"], int(q["gold"]), int(q["contrib"])])
	_log(sim, "%s cumpriu o pedido de %s." % [sim.player.name, q["name"]])
	var r := RosterSystem.entry(sim, int(q["rid"]))
	if not r.is_empty():
		RosterSystem.remember(sim, r, "ajudou_pedido")
	_contrib_changed(sim)
	Events.post(&"guild_bank_changed")

# ---------------------------------------------------------------------------
# FALAS

## Fala `key` de BotsCatalog.GBANK_LINES na voz do bot.
static func line(sim: WorldSim, r: Dictionary, key: String, extra: Dictionary = {}) -> String:
	var pools: Dictionary = BotsCatalog.GBANK_LINES.get(key, {})
	var own: Array = pools.get(str(r.get("personality", "")), [])
	var gen: Array = pools.get("*", [])
	var lines := own if not own.is_empty() and (gen.is_empty() or sim.rng.randf() < 0.6) else gen
	if lines.is_empty():
		return ""
	var v := {"p": sim.player.name if sim.player else "", "me": str(r.get("name", "")), "map": "a caça", "item": "", "n": "", "got": "",
		"gold": "", "rank": ""}
	v.merge(extra, true)
	return str(lines[sim.rng.randi() % lines.size()]).format(v)

static func _say(sim: WorldSim, r: Dictionary, key: String, extra: Dictionary) -> void:
	var text := line(sim, r, key, extra)
	if text != "":
		Events.post(&"chat_message", str(r["name"]), text, "guild")

static func _mate_says(sim: WorldSim, key: String, extra: Dictionary) -> void:
	var ms := members(sim).filter(func(r: Dictionary): return RosterSystem.entity_of(sim, r) != null)
	if not ms.is_empty():
		_say(sim, ms[sim.rng.randi() % ms.size()], key, extra)

# ---------------------------------------------------------------------------
# LEITURA (UI; contrato: Sim.guild_bank())

## Estado do banco para a aba ({} = sem guilda).
static func view(sim: WorldSim) -> Dictionary:
	if guild(sim).is_empty():
		return {}
	var b := _defaults(sim)
	var ri := rank_info(sim)
	var k := rank(sim)
	var nxt: Dictionary = Balance.GBANK_RANKS[k + 1] if k + 1 < Balance.GBANK_RANKS.size() else {}
	var items: Array = []
	for bi: Dictionary in b["items"]:
		var it: ItemDef = GameData.items.get(bi["id"])
		if it == null:
			continue
		var o := bi.duplicate()
		o["tab"] = tab_of(it)
		o["name"] = it.name
		o["take_n"] = take_count(bi)
		items.append(o)
	var log_out: Array = (b["log"] as Array).duplicate(true)
	log_out.reverse()
	return {"items": items, "gold": int(b["gold"]), "log": log_out, "contrib": int(b["contrib"]), "rank": ri["id"], "rank_name": ri["name"],
		"rank_i": k, "next_rank": nxt.get("name", ""), "next_contrib": int(nxt.get("contrib", 0)), "rank_contrib": int(ri["contrib"]),
		"takes": takes_left(sim), "takes_per_h": int(ri["takes"]), "next_take_in": next_take_in(sim),
		"gold_can_take": gold_can_take(sim), "gold_per_h": int(ri["gold"]), "where_error": where_error(sim),
		"missions": active_missions(sim).map(func(m: Dictionary): return {"id": m["id"], "names": m["names"], "target": m["target"],
			"kind": m["kind"], "left": maxf(0.0, float(m["ends"]) - _clock(sim)), "map": m["map"]}),
		"missions_max": missions_max(sim), "mission_rank": Balance.GBANK_MISSION_RANK, "request_rank": Balance.GBANK_REQUEST_RANK,
		"can_missions": rank(sim) >= _rank_index(Balance.GBANK_MISSION_RANK), "can_requests": rank(sim) >= _rank_index(Balance.GBANK_REQUEST_RANK),
		"requests": requests(sim), "notices": notices(sim), "targets": mission_targets(sim),
		"next_requests_in": maxf(0.0, float(b["next_req"]) - _clock(sim))}

# ---------------------------------------------------------------------------
# SAVE (campos opcionais guild_bank, guild_contrib, guild_missions, guild_requests)

static func to_save(sim: WorldSim) -> Dictionary:
	if sim.gbank.is_empty():
		return {}
	var b := sim.gbank
	var bank := {"v": 1, "items": (b.get("items", []) as Array).duplicate(true), "gold": int(b.get("gold", 0)), "log": (b.get("log", []) as Array).duplicate(true),
		"takes": float(b.get("takes", -1.0)), "gold_left": float(b.get("gold_left", -1.0)), "next_pulse": float(b.get("next_pulse", -1.0)),
		"next_req": float(b.get("next_req", -1.0)), "seq": int(b.get("seq", 0)), "welcomed": bool(b.get("welcomed", false)),
		"rank": int(b.get("rank", 0)), "gift_at": (b.get("gift_at", {}) as Dictionary).duplicate()}
	return {"guild_bank": bank, "guild_contrib": int(b.get("contrib", 0)), "guild_missions": (b.get("missions", []) as Array).duplicate(true),
		"guild_requests": (b.get("requests", []) as Array).duplicate(true)}

static func from_save(sim: WorldSim, d: Dictionary) -> void:
	sim.gbank.clear()
	var bank: Dictionary = d.get("guild_bank", {}) if d.get("guild_bank") is Dictionary else {}
	if bank.is_empty() and d.get("guild_contrib") == null:
		return
	var b := _defaults(sim)
	for bi in bank.get("items", []):
		if bi is Dictionary and GameData.items.has(str(bi.get("id", ""))):
			(b["items"] as Array).append({"uid": int(bi.get("uid", 0)), "id": str(bi["id"]), "count": maxi(1, int(bi.get("count", 1))),
				"by": str(bi.get("by", "")), "player": bool(bi.get("player", false)), "contrib": int(bi.get("contrib", 0)),
				"at": float(bi.get("at", 0.0)), "res": int(bi.get("res", 0))})
	b["gold"] = int(bank.get("gold", 0))
	for x in bank.get("log", []):
		if x is Dictionary:
			(b["log"] as Array).append({"at": float(x.get("at", 0.0)), "text": str(x.get("text", ""))})
	for k in ["takes", "gold_left", "next_pulse", "next_req"]:
		b[k] = float(bank.get(k, -1.0))
	b["seq"] = int(bank.get("seq", 0))
	b["welcomed"] = bool(bank.get("welcomed", false))
	b["rank"] = int(bank.get("rank", 0))
	b["gift_at"] = bank.get("gift_at", {}) if bank.get("gift_at") is Dictionary else {}
	b["contrib"] = maxi(0, int(d.get("guild_contrib", 0)))
	for m in d.get("guild_missions", []):
		if m is Dictionary and str(m.get("state", "")) in ["out", "back"]:
			var mm: Dictionary = m.duplicate(true)
			mm["id"] = int(mm.get("id", 0))
			mm["rids"] = (mm.get("rids", []) as Array).map(func(x): return int(x))
			if mm["state"] == "back" and mm.get("result") is Dictionary:
				var its: Array = []
				for pair in mm["result"].get("items", []):
					its.append([str(pair[0]), int(pair[1])])
				mm["result"]["items"] = its
				mm["result"]["gold"] = int(mm["result"].get("gold", 0))
				mm["result"]["rid"] = int(mm["result"].get("rid", -1))
			(b["missions"] as Array).append(mm)
	for q in d.get("guild_requests", []):
		if q is Dictionary:
			var qq: Dictionary = q.duplicate(true)
			for k in ["id", "rid", "count", "gold", "contrib", "item_n"]:
				qq[k] = int(qq.get(k, 0))
			(b["requests"] as Array).append(qq)
	var mx := 0
	for bi: Dictionary in b["items"]:
		mx = maxi(mx, int(bi["uid"]))
	for m: Dictionary in b["missions"]:
		mx = maxi(mx, int(m["id"]))
	for q: Dictionary in b["requests"]:
		mx = maxi(mx, int(q["id"]))
	b["seq"] = maxi(int(b["seq"]), mx)

# ---------------------------------------------------------------------------
# REVISÃO (dev)

## Fotos (--gbank_shot): elenco + guilda aceita, patente `rank_id`, alguns pulsos, uma encomenda que já voltou e o quadro.
static func dev_demo(sim: WorldSim, level: int, rank_id: String) -> void:
	sim.dev_social_demo(level)
	if sim.social["offer"]["state"] == "pending":
		GuildSystem.respond(sim, true)
	for r: Dictionary in members(sim):            # guilda da faixa do jogador (o elenco do autostart nasce no nível 1)
		var e := RosterSystem.entity_of(sim, r)
		var lv := clampi(sim.player.level + sim.rng.randi_range(-Balance.ROSTER_LEVEL_SPREAD, Balance.ROSTER_LEVEL_SPREAD), 1, Balance.MAX_LEVEL)
		r["level"] = lv
		if e:
			RosterSystem.set_level(sim, e, lv, str(r["build"]))
	var b := _defaults(sim)
	b["contrib"] = maxi(int(b["contrib"]), int(Balance.GBANK_RANKS[_rank_index(rank_id)]["contrib"]) + 120)
	_contrib_changed(sim)
	update(sim, 1.0)
	for i in 4:
		pulse(sim)
	refresh_requests(sim)
	var ms := members(sim)
	var tg := mission_targets(sim)
	var mats: Array = tg["material"]
	if ms.size() >= 2 and not mats.is_empty() and missions_max(sim) > 0:
		sim.player.gold += 5000
		var rids := [int(ms[0]["rid"])]
		if mission_start(sim, "material", str(mats[0]), rids, 0) == "":
			var m: Dictionary = active_missions(sim).back()
			m["ends"] = _clock(sim)
			_missions_update(sim)
		var rids2 := [int(ms[1]["rid"])]
		var cards: Array = tg["card"]
		if missions_max(sim) > 1 and not cards.is_empty():
			mission_start(sim, "card", str(cards[0]), rids2, 1)
	Events.post(&"guild_bank_changed")
