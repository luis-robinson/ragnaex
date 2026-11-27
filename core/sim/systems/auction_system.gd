class_name AuctionSystem
extends RefCounted
## Casa de Leilões (design/gdd/casa-de-leiloes.md; decisões §0/§9/§10): um mercado só, compra direta a preço fixo (D1),
## bots simulados (D2: anúncios gerados pelas tabelas de saque da faixa, assinados com nomes de bots reais; nada sai nem
## entra no inventário ou no ouro de bot nenhum), lendários fora (D3), Leiloeiros em Aldara, Porto Esperança e Lumeria (D4).
## Estado em `sim.auction` (salvo no campo `market`); sorteios só no `sim.auction_rng` (o mercado não gasta o `sim.rng`).
## Liga com `start` (WorldSim.roster_start); o relógio só anda no `update` (tick), o trabalho é no pulso de AUCTION_TICK_S.
## Contrato da UI: production/session-state/auction-contract.md.
##
## sim.auction: clock, next_pulse, next_id, next_mail, budget, paid, listings [anúncio], mail [entrada], history {item: [preços]},
##   flood {item: vendas recentes para bot}.
## Anúncio: {id, item, count, unit, seller, rid (elenco, -1), eid (bot vivo, -1), mood, mine, ends (relógio), band, ref}.
## Entrada da caixa: {id, kind "gold"|"item", item, count, gold, text}.

const LEGEND_TEXT := "Lendários não vão a leilão: só saem de saque."
const GONE_TEXT := "Este anúncio não está mais lá"
const NEAR_TEXT := "Fale com um Leiloeiro"
const KINDS := ["material", "equipment", "card", "potion"]

# ---------------------------------------------------------------------------
# LIGAR, RELÓGIO E PULSO

## Liga o mercado (mercado do save ou novo). Repetir não faz nada.
static func start(sim: WorldSim) -> void:
	if sim.auction_on:
		return
	sim.auction_on = true
	_defaults(sim)
	Events.post(&"auction_changed")

static func _defaults(sim: WorldSim) -> void:
	var a := sim.auction
	a.get_or_add("clock", 0.0)
	a.get_or_add("next_pulse", 0.0)          # mercado novo: os bots enchem no 1º pulso
	a.get_or_add("next_id", 1)
	a.get_or_add("next_mail", 1)
	a.get_or_add("budget", -1.0)              # -1 = balde cheio no 1º pulso
	a.get_or_add("paid", 0)                   # ouro pago pelos bots ao jogador (sondas)
	a.get_or_add("listings", [])
	a.get_or_add("mail", [])
	a.get_or_add("history", {})
	a.get_or_add("flood", {})

## Soma o tempo e roda os pulsos que venceram (cada um no tempo dele).
static func update(sim: WorldSim, dt: float) -> void:
	if not sim.auction_on or sim.player == null:
		return
	var a := sim.auction
	var target: float = float(a["clock"]) + dt
	while float(a["next_pulse"]) <= target:
		a["clock"] = float(a["next_pulse"])
		a["next_pulse"] = float(a["next_pulse"]) + Balance.AUCTION_TICK_S
		pulse(sim)
	a["clock"] = target

## Um pulso: balde dos bots, enxurrada, vencidos, bots negociando entre si, bots comprando do jogador, vitrine nova.
static func pulse(sim: WorldSim) -> void:
	var a := sim.auction
	var rng := sim.auction_rng
	var bmax := float(budget_max(sim))
	var b: float = float(a["budget"])
	a["budget"] = bmax if b < 0.0 else minf(bmax, b + bmax * Balance.AUCTION_TICK_S / 3600.0)
	var fl: Dictionary = a["flood"]
	for k in fl.keys():
		fl[k] = float(fl[k]) * pow(0.5, Balance.AUCTION_TICK_S / Balance.AUCTION_FLOOD_HALF_S)
		if float(fl[k]) < 0.05:
			fl.erase(k)
	var clock: float = a["clock"]
	var keep: Array = []
	for l: Dictionary in a["listings"]:
		if float(l["ends"]) > clock:
			keep.append(l)
		elif l["mine"]:
			var it: ItemDef = GameData.items.get(l["item"])
			_mail_item(sim, str(l["item"]), int(l["count"]), "Não vendeu: %s voltou" % (it.name if it else str(l["item"])))
			Events.post(&"auction_expired", int(l["id"]), str(l["item"]), int(l["count"]))
			Events.post(&"notification", "Leilão: %s não vendeu e voltou para a caixa" % (it.name if it else str(l["item"])))
	a["listings"] = keep
	# bots negociando entre si: a média anda
	keep = []
	for l: Dictionary in a["listings"]:
		if not l["mine"] and rng.randf() < Balance.AUCTION_BOT_CHURN:
			_record(sim, str(l["item"]), int(l["unit"]))
			_chat(sim, l, "sold")
		else:
			keep.append(l)
	a["listings"] = keep
	# bots comprando do jogador
	for l: Dictionary in (a["listings"] as Array).duplicate():
		if l["mine"] and rng.randf() < Balance.AUCTION_BOT_BUY_CHANCE:
			var mood := rng.randf_range(float(Balance.AUCTION_BUY_MOOD[0]), float(Balance.AUCTION_BUY_MOOD[1]))
			_bot_buy(sim, l, mood)
	# vitrine nova
	var n := rng.randi_range(int(Balance.AUCTION_BOT_LISTINGS[0]), int(Balance.AUCTION_BOT_LISTINGS[1]))
	var live := _live_bots(sim)
	for i in range(n):
		_bot_listing(sim, live)
	Events.post(&"auction_changed")

## Bot tenta comprar o anúncio `l` do jogador com o humor `mood`. Devolve se vendeu.
static func _bot_buy(sim: WorldSim, l: Dictionary, mood: float) -> bool:
	var a := sim.auction
	var it: ItemDef = GameData.items.get(l["item"])
	if it == null or float(l["unit"]) > teto_bot(sim, it, mood):
		return false
	var total: int = int(l["unit"]) * int(l["count"])
	if float(total) > float(a["budget"]):
		return false
	a["budget"] = float(a["budget"]) - total
	a["paid"] = int(a["paid"]) + total
	(a["listings"] as Array).erase(l)
	var net := total - int(round(total * Balance.AUCTION_CUT))
	_mail_gold(sim, net, "Vendeu %s x%d (comissão %d)" % [it.name, int(l["count"]), total - net])
	_record(sim, it.id, int(l["unit"]))
	var fl: Dictionary = a["flood"]
	fl[it.id] = float(fl.get(it.id, 0.0)) + 1.0
	Events.post(&"auction_sold", int(l["id"]), it.id, int(l["count"]), net)
	Events.post(&"notification", "Leilão: vendeu %s x%d (+%d ouro na caixa)" % [it.name, int(l["count"]), net])
	var buyer := _pick_seller(sim, _live_bots(sim), band_of(it.level_req))
	if not buyer.is_empty():
		buyer["item"] = it.id
		_chat(sim, buyer, "bought")
	return true

# ---------------------------------------------------------------------------
# PREÇOS (§3.6 / §7)

## O que o mercador paga por uma unidade.
static func shop_sell(it: ItemDef) -> int:
	return CraftSystem.sell_price(it)

## Menor preço de um anúncio de bot.
static func floor_bot(it: ItemDef) -> int:
	var s := shop_sell(it)
	return maxi(ceili(s * Balance.AUCTION_FLOOR_OVER_SELL), s + 1)

## Preço de referência por unidade (procura das cartas inclusa).
static func ref(sim: WorldSim, it: ItemDef) -> int:
	if it == null:
		return 0
	var base := _base_ref(sim, it)
	if GameData.cards.has(it.id):
		return maxi(1, roundi(base * (1.0 + card_demand(sim, it.id))))
	return maxi(1, roundi(base))

## procura = clamp((vendidas − anunciadas) / DIV, MIN, MAX) (vendidas = negócios guardados do item; anunciadas = de bots).
static func card_demand(sim: WorldSim, item_id: String) -> float:
	var sold: int = (sim.auction.get("history", {}).get(item_id, []) as Array).size()
	var listed := 0
	for l: Dictionary in sim.auction.get("listings", []):
		if l["item"] == item_id and not l["mine"]:          # o anúncio do jogador não derruba o próprio preço
			listed += 1
	return clampf((sold - listed) / Balance.AUCTION_CARD_DEMAND_DIV, float(Balance.AUCTION_CARD_DEMAND[0]), float(Balance.AUCTION_CARD_DEMAND[1]))

## Ouro gasto para aprimorar `base` de +0 até +n.
static func plus_gold(sim: WorldSim, base: ItemDef, n: int) -> int:
	var g := 0
	for k in range(n):
		g += int(ItemSystem.enhance_cost(sim, base, k)["gold"])
	return g

## ref sem a procura: loja / custo de fabricar / base + parte do aprimoramento (guardado em sim._auction_cache).
static func _base_ref(sim: WorldSim, it: ItemDef) -> float:
	var cache: Dictionary = sim._auction_cache.get_or_add("ref", {})
	if cache.has(it.id):
		return float(cache[it.id])
	cache[it.id] = float(it.price)          # guarda contra receita em ciclo
	var v := float(it.price)
	if it.base_id != "" and GameData.items.has(it.base_id):
		var base: ItemDef = GameData.items[it.base_id]
		v = _base_ref(sim, base) + Balance.AUCTION_PLUS_RECOVER * plus_gold(sim, base, it.plus)
	else:
		var best := INF
		for r: RecipeDef in _recipes_of(sim, it.id):
			var c := float(r.gold_cost)
			for ing in r.ingredients:
				var ii: ItemDef = GameData.items.get(ing)
				c += float(r.ingredients[ing]) * (_base_ref(sim, ii) if ii else 0.0)
			best = minf(best, c / maxf(1.0, float(r.result_count)))
		if best < INF:
			v = best
	cache[it.id] = v
	return v

static func _recipes_of(sim: WorldSim, item_id: String) -> Array:
	var by: Dictionary = sim._auction_cache.get("recipes", {})
	if by.is_empty():
		for rid in GameData.recipes:
			var r: RecipeDef = GameData.recipes[rid]
			(by.get_or_add(r.result_item, []) as Array).append(r)
		sim._auction_cache["recipes"] = by
	return by.get(item_id, [])

## Itens que algum mercador vende (lojas de todos os mapas).
static func shop_sold(sim: WorldSim, item_id: String) -> bool:
	var s: Dictionary = sim._auction_cache.get("shop", {})
	if s.is_empty():
		for mid in GameData.maps:
			for n in (GameData.maps[mid] as MapDef).npcs:
				var sh: Variant = n.get("shop", [])
				if sh is Array:
					for iid in sh:
						s[str(iid)] = true
		s["_"] = true
		sim._auction_cache["shop"] = s
	return s.has(item_id)

## Custo mínimo de fabricar uma unidade (ingredientes no menor entre loja com Feira, piso dos bots e fabricar). INF = não se fabrica.
static func min_craft_cost(sim: WorldSim, it: ItemDef) -> float:
	var cache: Dictionary = sim._auction_cache.get_or_add("craft", {})
	if cache.has(it.id):
		return float(cache[it.id])
	cache[it.id] = INF                       # ciclo: não conta
	var best := INF
	for r: RecipeDef in _recipes_of(sim, it.id):
		var c := float(r.gold_cost)
		for ing in r.ingredients:
			var ii: ItemDef = GameData.items.get(ing)
			c += float(r.ingredients[ing]) * (_cheapest(sim, ii) if ii else 0.0)
		best = minf(best, c / maxf(1.0, float(r.result_count)))
	cache[it.id] = best
	return best

static func _cheapest(sim: WorldSim, it: ItemDef) -> float:
	var c := float(floor_bot(it))
	if shop_sold(sim, it.id) and it.price > 0:
		c = minf(c, it.price * (1.0 - Balance.CHAIN_FAIR_DISCOUNT))
	return minf(c, min_craft_cost(sim, it))

## Teto da fonte (§7): loja × SHOP_PAY_MAX, fabricar × CRAFT_PAY_MAX; INF se só cai de monstro.
static func source_cap(sim: WorldSim, it: ItemDef) -> float:
	var cap := INF
	if shop_sold(sim, it.id) and it.price > 0:
		cap = it.price * Balance.AUCTION_SHOP_PAY_MAX
	var cc := min_craft_cost(sim, it)
	if cc < INF:
		cap = minf(cap, cc * Balance.AUCTION_CRAFT_PAY_MAX)
	return cap

## Queda por enxurrada do item (1 = nenhuma).
static func flood_mult(sim: WorldSim, item_id: String) -> float:
	var n := minf(float(sim.auction.get("flood", {}).get(item_id, 0.0)), float(Balance.AUCTION_FLOOD_MAX))
	return 1.0 - Balance.AUCTION_FLOOD_STEP * n

## O máximo que um bot com humor `mood` paga por unidade.
static func teto_bot(sim: WorldSim, it: ItemDef, mood: float) -> float:
	var fm := flood_mult(sim, it.id)
	if it.base_id != "" and GameData.items.has(it.base_id):
		var base: ItemDef = GameData.items[it.base_id]
		var extra := Balance.AUCTION_PLUS_RECOVER * plus_gold(sim, base, it.plus) * (1.0 + mood)
		return minf(float(ref(sim, it)) * (1.0 + mood) * fm, teto_bot(sim, base, mood) + extra * fm)
	return minf(float(ref(sim, it)) * (1.0 + mood) * fm, source_cap(sim, it))

## Faixa de preço por unidade que o jogador pode pedir: (mínimo, máximo).
static func price_range(sim: WorldSim, it: ItemDef) -> Vector2i:
	return Vector2i(maxi(1, shop_sell(it)), maxi(1, int(ref(sim, it) * Balance.AUCTION_PLAYER_PRICE_MAX)))

## Média dos últimos negócios (ou ref), dentro da faixa.
static func suggest(sim: WorldSim, it: ItemDef) -> int:
	var h: Array = sim.auction.get("history", {}).get(it.id, [])
	var v := ref(sim, it)
	if not h.is_empty():
		var s := 0.0
		for x in h:
			s += float(x)
		v = roundi(s / h.size())
	var r := price_range(sim, it)
	return clampi(v, r.x, r.y)

## Setinha: +1 alta, -1 baixa, 0 parada (média dos 3 últimos contra a média).
static func trend(sim: WorldSim, item_id: String) -> int:
	var h: Array = sim.auction.get("history", {}).get(item_id, [])
	if h.size() < 4:
		return 0
	var s := 0.0
	for x in h:
		s += float(x)
	var avg := s / h.size()
	var s3 := (float(h[-1]) + float(h[-2]) + float(h[-3])) / 3.0
	if s3 > avg * (1.0 + Balance.AUCTION_TREND_PCT):
		return 1
	if s3 < avg * (1.0 - Balance.AUCTION_TREND_PCT):
		return -1
	return 0

static func fee(hours: int, total: int) -> int:
	return maxi(1, int(total * Balance.AUCTION_LIST_FEE * hours / 24.0))

static func _record(sim: WorldSim, item_id: String, unit: int) -> void:
	var h: Array = (sim.auction["history"] as Dictionary).get_or_add(item_id, [])
	h.append(unit)
	while h.size() > Balance.AUCTION_HISTORY_N:
		h.pop_front()

# ---------------------------------------------------------------------------
# REGRAS DO JOGADOR (§5)

## "" = pode ir a leilão; senão o motivo.
static func sellable(it: ItemDef) -> String:
	if it == null:
		return "Item desconhecido."
	var base: ItemDef = GameData.items.get(it.base_id) if it.base_id != "" else null
	for x: ItemDef in [it, base]:
		if x != null and (x.is_legendary() or x.set_id != "" or not x.legend_effect.is_empty() or not x.piece_fx.is_empty()):
			return LEGEND_TEXT
	if it.type == ItemDef.Type.QUEST:
		return "Itens de missão não vão a leilão."
	if it.price <= 0:
		return "Este item não tem preço de mercado."
	return ""

## Está perto de um Leiloeiro (papel `auction`) no mapa atual?
static func near(sim: WorldSim, e: SimEntity) -> bool:
	if e == null or not sim.maps.has(e.map_id):
		return false
	for n in (sim.maps[e.map_id]["def"] as MapDef).npcs:
		if str(n.get("role", "")) == Balance.AUCTION_NPC_ROLE and \
				Vector2(n["pos"].x, n["pos"].z).distance_to(Vector2(e.position.x, e.position.z)) <= Balance.STATION_RANGE:
			return true
	return false

static func mine_count(sim: WorldSim) -> int:
	var n := 0
	for l: Dictionary in sim.auction.get("listings", []):
		if l["mine"]:
			n += 1
	return n

static func list_error(sim: WorldSim, e: SimEntity, item_id: String, count: int, unit: int, hours: int) -> String:
	if e == null or e != sim.player or not sim.auction_on:
		return "Indisponível agora."
	if not near(sim, e):
		return NEAR_TEXT
	var it: ItemDef = GameData.items.get(item_id)
	var why := sellable(it)
	if why != "":
		return why
	if not hours in Balance.AUCTION_DURATIONS_H:
		return "Prazo inválido."
	var have := int(e.inventory.get(item_id, 0))
	if have <= 0 and (e.equipment.values().any(func(x): return x != null and x.id == item_id) or item_id in e.cards.values()):
		return "Tire do encaixe/boneco primeiro"
	if count < 1 or count > it.stack_max:
		return "Quantidade inválida."
	if count > have:
		return "Você não tem tantos."
	if mine_count(sim) >= Balance.AUCTION_PLAYER_LISTINGS:
		return "Você já tem %d anúncios" % Balance.AUCTION_PLAYER_LISTINGS
	var r := price_range(sim, it)
	if unit < r.x:
		return "O mercador paga mais que isso"
	if unit > r.y:
		return "Preço alto demais"
	if e.gold < fee(hours, unit * count):
		return "Ouro insuficiente para a taxa"
	return ""

## Anuncia: o item sai da bolsa na hora e a taxa é cobrada. "" = anunciou.
static func list(sim: WorldSim, e: SimEntity, item_id: String, count: int, unit: int, hours: int) -> String:
	var err := list_error(sim, e, item_id, count, unit, hours)
	if err != "":
		return err
	var it: ItemDef = GameData.items[item_id]
	e.remove_item(item_id, count)
	e.gold -= fee(hours, unit * count)
	QuestSystem.on_item_changed(e, item_id)
	var a := sim.auction
	var l := {"id": int(a["next_id"]), "item": item_id, "count": count, "unit": unit, "seller": e.name, "rid": -1, "eid": -1, "mood": 0.0,
		"mine": true, "ends": float(a["clock"]) + hours * 3600.0, "band": band_of(it.level_req), "ref": ref(sim, it)}
	a["next_id"] = int(a["next_id"]) + 1
	(a["listings"] as Array).append(l)
	Events.post(&"auction_changed")
	return ""

static func find(sim: WorldSim, listing_id: int) -> Dictionary:
	for l: Dictionary in sim.auction.get("listings", []):
		if int(l["id"]) == listing_id:
			return l
	return {}

static func buy_error(sim: WorldSim, e: SimEntity, listing_id: int) -> String:
	if e == null or e != sim.player or not sim.auction_on:
		return "Indisponível agora."
	if not near(sim, e):
		return NEAR_TEXT
	var l := find(sim, listing_id)
	if l.is_empty():
		return GONE_TEXT
	if l["mine"]:
		return "Este anúncio é seu"
	if (sim.auction["mail"] as Array).size() >= Balance.AUCTION_MAIL_MAX:
		return "Esvazie a caixa do Leiloeiro"
	if e.gold < int(l["unit"]) * int(l["count"]):
		return "Ouro insuficiente"
	return ""

## Compra o anúncio inteiro; o item vai para a caixa. "" = comprou.
static func buy(sim: WorldSim, e: SimEntity, listing_id: int) -> String:
	var err := buy_error(sim, e, listing_id)
	if err != "":
		return err
	var l := find(sim, listing_id)
	var total: int = int(l["unit"]) * int(l["count"])
	e.gold -= total
	(sim.auction["listings"] as Array).erase(l)
	_record(sim, str(l["item"]), int(l["unit"]))
	var it: ItemDef = GameData.items.get(l["item"])
	_mail_item(sim, str(l["item"]), int(l["count"]), "Comprou %s de %s" % [it.name if it else str(l["item"]), str(l["seller"])])
	Events.post(&"auction_changed")
	return ""

## Cancela um anúncio do jogador: o item volta para a caixa, a taxa não volta.
static func cancel(sim: WorldSim, e: SimEntity, listing_id: int) -> String:
	if e == null or e != sim.player or not sim.auction_on:
		return "Indisponível agora."
	if not near(sim, e):
		return NEAR_TEXT
	var l := find(sim, listing_id)
	if l.is_empty():
		return GONE_TEXT
	if not l["mine"]:
		return "Este anúncio não é seu"
	(sim.auction["listings"] as Array).erase(l)
	var it: ItemDef = GameData.items.get(l["item"])
	_mail_item(sim, str(l["item"]), int(l["count"]), "Cancelado: %s" % (it.name if it else str(l["item"])))
	Events.post(&"auction_changed")
	return ""

## Pega da caixa (`mail_id` -1 = tudo). Ouro sai inteiro; item só se cabe na bolsa. "" = tudo saiu.
static func collect(sim: WorldSim, e: SimEntity, mail_id: int = -1) -> String:
	if e == null or e != sim.player or not sim.auction_on:
		return "Indisponível agora."
	if not near(sim, e):
		return NEAR_TEXT
	var left := 0
	var found := false
	var keep: Array = []
	for m: Dictionary in sim.auction["mail"]:
		if mail_id >= 0 and int(m["id"]) != mail_id:
			keep.append(m)
			continue
		found = true
		if m["kind"] == "gold":
			e.gold += int(m["gold"])
			continue
		var iid := str(m["item"])
		if e.bag_full_for(iid):
			left += int(m["count"])
			keep.append(m)
			continue
		e.add_item(iid, int(m["count"]))
		QuestSystem.on_item_changed(e, iid)
		CardSystem.on_pickup(sim, e, iid)       # carta comprada entra no Bestiário como achada (§10, P3)
	sim.auction["mail"] = keep
	Events.post(&"auction_changed")
	if mail_id >= 0 and not found:
		return "Esta entrada não está mais na caixa"
	return "Bolsa cheia: %d ficaram na caixa" % left if left > 0 else ""

static func _mail_item(sim: WorldSim, item_id: String, count: int, text: String) -> void:
	var a := sim.auction
	(a["mail"] as Array).append({"id": int(a["next_mail"]), "kind": "item", "item": item_id, "count": count, "gold": 0, "text": text})
	a["next_mail"] = int(a["next_mail"]) + 1

static func _mail_gold(sim: WorldSim, gold: int, text: String) -> void:
	var a := sim.auction
	(a["mail"] as Array).append({"id": int(a["next_mail"]), "kind": "gold", "item": "", "count": 0, "gold": gold, "text": text})
	a["next_mail"] = int(a["next_mail"]) + 1

static func budget_max(sim: WorldSim) -> int:
	return Balance.AUCTION_BOT_BUDGET_PER_LV * (sim.player.level if sim.player else 1)

# ---------------------------------------------------------------------------
# LEITURA PARA A UI

static func row(sim: WorldSim, l: Dictionary) -> Dictionary:
	var it: ItemDef = GameData.items.get(l["item"])
	return {"id": int(l["id"]), "item": str(l["item"]), "name": it.name if it else str(l["item"]), "count": int(l["count"]),
		"unit": int(l["unit"]), "total": int(l["unit"]) * int(l["count"]), "seller": str(l["seller"]), "mine": bool(l["mine"]),
		"left": maxf(0.0, float(l["ends"]) - float(sim.auction["clock"])), "band": int(l["band"]),
		"ref": ref(sim, it) if it else 0, "trend": trend(sim, str(l["item"]))}

## Busca (filtros no contrato). Mais barato primeiro.
static func search(sim: WorldSim, filters: Dictionary = {}) -> Array:
	var out: Array = []
	var text := str(filters.get("text", "")).to_lower()
	var type := str(filters.get("type", ""))
	var cslot := str(filters.get("card_slot", ""))
	for l: Dictionary in sim.auction.get("listings", []):
		var it: ItemDef = GameData.items.get(l["item"])
		if it == null:
			continue
		if bool(filters.get("mine", false)) and not l["mine"]:
			continue
		if text != "" and not it.name.to_lower().contains(text):
			continue
		if type != "" and _type_of(it) != type:
			continue
		if cslot != "":
			var cd: CardDef = GameData.cards.get(it.id)
			if cd == null or cd.slot != cslot:
				continue
		if filters.has("level_min") and it.level_req < int(filters["level_min"]):
			continue
		if filters.has("level_max") and it.level_req > int(filters["level_max"]):
			continue
		if filters.has("price_max") and int(l["unit"]) > int(filters["price_max"]):
			continue
		out.append(row(sim, l))
	out.sort_custom(func(x, y): return int(x["unit"]) < int(y["unit"]) or (int(x["unit"]) == int(y["unit"]) and int(x["id"]) < int(y["id"])))
	return out

static func _type_of(it: ItemDef) -> String:
	match it.type:
		ItemDef.Type.EQUIPMENT: return "equipment"
		ItemDef.Type.CARD: return "card"
		ItemDef.Type.CONSUMABLE: return "consumable"
	return "material"

static func status(sim: WorldSim, e: SimEntity) -> Dictionary:
	var mine: Array = []
	for l: Dictionary in sim.auction.get("listings", []):
		if l["mine"]:
			mine.append(row(sim, l))
	return {"near": near(sim, e), "gold": e.gold if e else 0, "listings": mine, "max_listings": Balance.AUCTION_PLAYER_LISTINGS,
		"mail": (sim.auction.get("mail", []) as Array).duplicate(true), "mail_max": Balance.AUCTION_MAIL_MAX,
		"budget": int(float(sim.auction.get("budget", 0.0))), "budget_max": budget_max(sim),
		"durations": Balance.AUCTION_DURATIONS_H.duplicate()}

# ---------------------------------------------------------------------------
# BOTS (D2: só nomes; nunca mexe em bolsa/ouro de bot)

## Faixa (índice de Balance.XP_BANDS) de um nível.
static func band_of(level: int) -> int:
	for i in range(Balance.XP_BANDS.size()):
		if level < int(Balance.XP_BANDS[i][1]):
			return i
	return Balance.XP_BANDS.size() - 1

static func _band_hi(b: int) -> int:
	var hi := int(Balance.XP_BANDS[b][1])
	return hi + 1 if b == Balance.XP_BANDS.size() - 1 else hi

static func _live_bots(sim: WorldSim) -> Array:
	var out: Array = []
	for id in sim.entities:
		var e: SimEntity = sim.entities[id]
		if e.kind == SimEntity.Kind.BOT and e.gvg_side == "":
			out.append(e)
	return out

## O que os bots da faixa `b` acham: {material, equipment, card, potion: [ids]} + monsters (ids com tabela de saque).
static func band_pool(sim: WorldSim, b: int) -> Dictionary:
	var pools: Dictionary = sim._auction_cache.get_or_add("bands", {})
	if pools.has(b):
		return pools[b]
	var lo := int(Balance.XP_BANDS[b][0])
	var hi := _band_hi(b)
	var spawned := {}
	for mid in GameData.maps:
		for sp in (GameData.maps[mid] as MapDef).spawners:
			spawned[str(sp.get("monster_id", ""))] = true
	var mobs: Array = []
	var mats := {}
	var cards: Array = []
	for mid in GameData.monsters:
		var md: MonsterDef = GameData.monsters[mid]
		if md.is_boss or md.dummy or not spawned.has(md.id) or md.level < lo or md.level >= hi:
			continue
		var lt: LootTable = GameData.loot_tables.get(md.loot_table)
		if lt != null:
			var any := false
			for en in lt.entries:
				var ii: ItemDef = GameData.items.get(str(en.get("item", "")))
				if ii and ii.type == ItemDef.Type.MATERIAL and sellable(ii) == "":
					mats[ii.id] = true
					any = true
			if any:
				mobs.append(md.id)
		var cid := str(GameData.card_of.get(md.id, ""))
		if cid != "" and not cid in cards and sellable(GameData.items.get(cid)) == "":
			cards.append(cid)
	var gear: Array = []
	for t in range(Balance.COMMON_TIER_LEVELS.size()):
		for it: ItemDef in LootSystem.gear_pool(sim, t):
			if it.level_req >= lo and it.level_req < hi and sellable(it) == "":
				gear.append(it.id)
	var pots: Array = []
	for iid in GameData.items:
		var it: ItemDef = GameData.items[iid]
		if it.type == ItemDef.Type.CONSUMABLE and not it.consume.is_empty() and it.level_req < hi and sellable(it) == "" \
				and (shop_sold(sim, it.id) or not _recipes_of(sim, it.id).is_empty()):
			if it.id.begins_with("hunt_") and HuntPotionSystem.grade_for(hi - 1) < it.id.right(1).to_int() - 1:
				continue
			pots.append(it.id)
	var m_ids := mats.keys()
	m_ids.sort()
	gear.sort()
	pots.sort()
	cards.sort()
	mobs.sort()
	var out := {"material": m_ids, "equipment": gear, "card": cards, "potion": pots, "monsters": mobs}
	pools[b] = out
	return out

static func band_counts(sim: WorldSim) -> Array:
	var c: Array = []
	c.resize(Balance.XP_BANDS.size())
	c.fill(0)
	for l: Dictionary in sim.auction.get("listings", []):
		if not l["mine"]:
			c[int(l["band"])] += 1
	return c

## Faixa sorteada pelo peso dos bots vivos (mínimo AUCTION_BAND_MIN_WEIGHT), sem faixa cheia (-1 = todas cheias).
static func _pick_band(sim: WorldSim, live: Array) -> int:
	var nb := Balance.XP_BANDS.size()
	var per: Array = []
	per.resize(nb)
	per.fill(0)
	for e: SimEntity in live:
		per[band_of(e.level)] += 1
	var counts := band_counts(sim)
	var w: Array = []
	var tot := 0.0
	for b in range(nb):
		var x := 0.0
		if int(counts[b]) < Balance.AUCTION_BAND_MAX:
			x = maxf(Balance.AUCTION_BAND_MIN_WEIGHT, float(per[b]) / maxf(1.0, float(live.size())))
		w.append(x)
		tot += x
	if tot <= 0.0:
		return -1
	var r := sim.auction_rng.randf() * tot
	for b in range(nb):
		r -= float(w[b])
		if r <= 0.0 and float(w[b]) > 0.0:
			return b
	for b in range(nb - 1, -1, -1):
		if float(w[b]) > 0.0:
			return b
	return -1

## Quem assina: elenco (AUCTION_ROSTER_SHARE), senão um bot vivo da faixa, senão o elenco, senão qualquer bot vivo.
## {seller, rid, eid, mood_key} ({} = ninguém).
static func _pick_seller(sim: WorldSim, live: Array, b: int) -> Dictionary:
	var rng := sim.auction_rng
	var roster: Array = sim.roster if sim.roster_on else []
	var use_roster := not roster.is_empty() and rng.randf() < Balance.AUCTION_ROSTER_SHARE
	if not use_roster:
		var band: Array = live.filter(func(e: SimEntity) -> bool: return e.roster_id < 0 and band_of(e.level) == b)
		if not band.is_empty():
			var e: SimEntity = band[rng.randi() % band.size()]
			return {"seller": e.name, "rid": -1, "eid": e.id, "mood_key": ""}
	if not roster.is_empty():
		var r: Dictionary = roster[rng.randi() % roster.size()]
		var re := RosterSystem.entity_of(sim, r)
		return {"seller": str(r["name"]), "rid": int(r["rid"]), "eid": re.id if re else -1, "mood_key": str(r["personality"])}
	if not live.is_empty():
		var e: SimEntity = live[rng.randi() % live.size()]
		return {"seller": e.name, "rid": -1, "eid": e.id, "mood_key": ""}
	return {}

## Um anúncio novo de bot (pode não sair: faixa cheia, sem vendedor, nada achado). Devolve o anúncio ou {}.
static func _bot_listing(sim: WorldSim, live: Array) -> Dictionary:
	var rng := sim.auction_rng
	var b := _pick_band(sim, live)
	if b < 0:
		return {}
	var pool := band_pool(sim, b)
	var kind := _pick_kind(rng)
	var item_id := ""
	var count := 1
	match kind:
		"material":
			var mobs: Array = pool["monsters"]
			for _try in range(4):
				if mobs.is_empty():
					break
				var md: MonsterDef = GameData.monsters[mobs[rng.randi() % mobs.size()]]
				var lt: LootTable = GameData.loot_tables[md.loot_table]
				var got := {}
				for _r in range(rng.randi_range(int(Balance.AUCTION_BOT_LOT[0]), int(Balance.AUCTION_BOT_LOT[1]))):
					var roll := lt.roll(rng)
					for iid in roll:
						if (pool["material"] as Array).has(iid):
							got[iid] = int(got.get(iid, 0)) + int(roll[iid])
				if not got.is_empty():
					var keys := got.keys()
					keys.sort()
					item_id = keys[rng.randi() % keys.size()]
					count = int(got[item_id])
					break
		"potion":
			var ps: Array = pool["potion"]
			if not ps.is_empty():
				item_id = ps[rng.randi() % ps.size()]
				count = rng.randi_range(int(Balance.AUCTION_BOT_POTION_LOT[0]), int(Balance.AUCTION_BOT_POTION_LOT[1]))
		_:
			var xs: Array = pool[kind]
			if not xs.is_empty():
				item_id = xs[rng.randi() % xs.size()]
	if item_id == "":
		return {}
	var it: ItemDef = GameData.items[item_id]
	count = clampi(count, 1, it.stack_max)
	var who := _pick_seller(sim, live, b)
	if who.is_empty():
		return {}
	var mr: Array = Balance.AUCTION_MOODS.get(who["mood_key"], Balance.AUCTION_MOODS[""])
	var mood := rng.randf_range(float(mr[0]), float(mr[1]))
	var rf := ref(sim, it)
	var lo := floor_bot(it)
	var hi := int(rf * Balance.AUCTION_BOT_ASK_MAX)
	if lo > hi:
		return {}                           # faixa vazia: o piso passa do teto (o bot não anuncia)
	var a := sim.auction
	var l := {"id": int(a["next_id"]), "item": item_id, "count": count, "unit": clampi(roundi(rf * (1.0 + mood)), lo, hi),
		"seller": who["seller"], "rid": who["rid"], "eid": who["eid"], "mood": mood, "mine": false,
		"ends": float(a["clock"]) + rng.randf_range(float(Balance.AUCTION_BOT_LISTING_S[0]), float(Balance.AUCTION_BOT_LISTING_S[1])),
		"band": b, "ref": rf}
	a["next_id"] = int(a["next_id"]) + 1
	(a["listings"] as Array).append(l)
	return l

static func _pick_kind(rng: RandomNumberGenerator) -> String:
	var tot := 0
	for k in KINDS:
		tot += int(Balance.AUCTION_BOT_KIND_WEIGHTS.get(k, 0))
	var r := rng.randi() % maxi(1, tot)
	for k in KINDS:
		r -= int(Balance.AUCTION_BOT_KIND_WEIGHTS.get(k, 0))
		if r < 0:
			return k
	return KINDS[0]

## Fala de leilão (`sold` | `bought`) de quem assina `l`, às vezes, no ritmo do elenco. Sorteio no auction_rng.
static func _chat(sim: WorldSim, l: Dictionary, key: String) -> void:
	var rng := sim.auction_rng
	if rng.randf() >= Balance.AUCTION_CHAT_CHANCE:
		return
	var a := sim.auction
	if float(a["clock"]) < float(a.get("chat_at", -1.0e9)) + Balance.AUCTION_CHAT_GAP:
		return
	var e: SimEntity = sim.entities.get(int(l.get("eid", -1)))
	if e == null or e.kind != SimEntity.Kind.BOT or not RosterSystem.can_speak(sim, e):
		return
	var pools: Dictionary = BotsCatalog.AUCTION_LINES.get(key, {})
	var pers := ""
	var r := RosterSystem.entry_of(sim, e) if sim.roster_on else {}
	if not r.is_empty():
		pers = str(r["personality"])
	var lines: Array = pools.get(pers, []) if pools.has(pers) and rng.randf() < 0.6 else pools.get("*", [])
	if lines.is_empty():
		return
	var it: ItemDef = GameData.items.get(str(l.get("item", "")))
	a["chat_at"] = float(a["clock"])
	Events.post(&"chat_message", e.name, str(lines[rng.randi() % lines.size()]).format({"item": it.name if it else "aquilo"}), "global")

# ---------------------------------------------------------------------------
# SAVE (campo opcional `market`; o tempo que falta de cada anúncio)

static func to_save(sim: WorldSim) -> Dictionary:
	if sim.auction.is_empty():
		return {}
	var a := sim.auction
	var clock: float = a["clock"]
	var ls: Array = []
	for l: Dictionary in a["listings"]:
		var o := l.duplicate()
		o.erase("ends")
		o.erase("eid")
		o["left"] = maxf(0.0, float(l["ends"]) - clock)
		ls.append(o)
	return {"v": 1, "clock": clock, "pulse_left": maxf(0.0, float(a["next_pulse"]) - clock), "next_id": int(a["next_id"]),
		"next_mail": int(a["next_mail"]), "budget": float(a["budget"]), "paid": int(a["paid"]), "listings": ls,
		"mail": (a["mail"] as Array).duplicate(true), "history": (a["history"] as Dictionary).duplicate(true),
		"flood": (a["flood"] as Dictionary).duplicate()}

## Save carregado: mercado do save (sem o campo = mercado novo). Item que saiu do catálogo some (aviso no log).
static func from_save(sim: WorldSim, d: Dictionary) -> void:
	sim.auction.clear()
	sim._auction_cache.erase("ref")
	var m: Variant = d.get("market")
	if not (m is Dictionary) or (m as Dictionary).is_empty():
		if sim.auction_on:
			_defaults(sim)
		return
	var md: Dictionary = m
	_defaults(sim)
	var a := sim.auction
	var clock := float(md.get("clock", 0.0))
	a["clock"] = clock
	a["next_pulse"] = clock + clampf(float(md.get("pulse_left", 0.0)), 0.0, Balance.AUCTION_TICK_S)
	a["next_id"] = maxi(1, int(md.get("next_id", 1)))
	a["next_mail"] = maxi(1, int(md.get("next_mail", 1)))
	a["budget"] = float(md.get("budget", -1.0))
	a["paid"] = int(md.get("paid", 0))
	for h in (md.get("history", {}) as Dictionary):
		if GameData.resolve_item(str(h)) and md["history"][h] is Array:
			var arr: Array = []
			for x in md["history"][h]:
				arr.append(int(x))
			a["history"][str(h)] = arr
	for f in (md.get("flood", {}) as Dictionary):
		a["flood"][str(f)] = float(md["flood"][f])
	for o in md.get("listings", []):
		if not (o is Dictionary) or not GameData.resolve_item(str(o.get("item", ""))):
			push_warning("AuctionSystem: anúncio de item que saiu do catálogo some (%s)" % str(o))
			continue
		var it: ItemDef = GameData.items[str(o["item"])]
		var l := {"id": int(o.get("id", 0)), "item": it.id, "count": clampi(int(o.get("count", 1)), 1, it.stack_max),
			"unit": maxi(1, int(o.get("unit", 1))), "seller": str(o.get("seller", "")), "rid": int(o.get("rid", -1)), "eid": -1,
			"mood": float(o.get("mood", 0.0)), "mine": bool(o.get("mine", false)), "ends": clock + maxf(0.0, float(o.get("left", 0.0))),
			"band": clampi(int(o.get("band", 0)), 0, Balance.XP_BANDS.size() - 1), "ref": int(o.get("ref", it.price))}
		a["next_id"] = maxi(int(a["next_id"]), int(l["id"]) + 1)
		(a["listings"] as Array).append(l)
	for l: Dictionary in a["listings"]:          # preço de bot preso de novo na faixa (o Balance pode ter mudado)
		if not l["mine"]:
			var it: ItemDef = GameData.items[l["item"]]
			l["unit"] = clampi(int(l["unit"]), floor_bot(it), maxi(floor_bot(it), int(ref(sim, it) * Balance.AUCTION_BOT_ASK_MAX)))
	for o in md.get("mail", []):
		if not (o is Dictionary):
			continue
		var kind := str(o.get("kind", "item"))
		if kind == "item" and not GameData.resolve_item(str(o.get("item", ""))):
			push_warning("AuctionSystem: item da caixa que saiu do catálogo some (%s)" % str(o))
			continue
		var e := {"id": int(o.get("id", 0)), "kind": kind, "item": str(o.get("item", "")), "count": int(o.get("count", 0)),
			"gold": int(o.get("gold", 0)), "text": str(o.get("text", ""))}
		a["next_mail"] = maxi(int(a["next_mail"]), int(e["id"]) + 1)
		(a["mail"] as Array).append(e)
