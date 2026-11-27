extends Node
## Sonda da Casa de Leilões (design/gdd/casa-de-leiloes.md §8; AuctionSystem). Só mede, não julga. Sem tela.
##   godot --headless --path . tools/tests/auction_probe.tscn -- [--hours=4] [--level=20] [--exploit] [--hunt[=<mapa>]] [--minutes=20]
## SELL   = minutos até um bot comprar uma carta comum anunciada no preço de referência (mediana de 50; alvo 10-30).
## SHOW   = anúncios novos na faixa do jogador entre duas visitas de 10 min (alvo >= 5) e % assinados pelo elenco.
## BUDGET = ouro/h pago pelos bots a um jogador que mantém 12 anúncios na sugestão, contra o orçamento (e a caça, com --hunt).
## --exploit: os 5 laços da §5 por 1 h (ouro/h; mercador↔bot, fabricar e aprimorar <= 0; arbitragem <= orçamento).
## --hunt[=<mapa>]: ouro/h de caça (ouro + venda ao mercador do que juntou) de 4 bots do nível num mapa da faixa.

const HUNT_MAPS := {0: "field_crab_beach", 1: "field_forest", 2: "field_ruins", 3: "field_steppe", 4: "field_kharzun", 5: "field_kharzun", 6: "field_perfume"}
const DT := 1.0 / 20.0
var level := 20
var hours := 4.0

func _ready() -> void:
	await get_tree().process_frame
	Sim.running = false
	HuntPotionSystem.bots_drink = false
	level = int(DevArgs.value("--level")) if DevArgs.flag("--level") else 20
	hours = float(DevArgs.value("--hours")) if DevArgs.flag("--hours") else 4.0
	var hunt_gph := -1.0
	if DevArgs.has("--hunt") or DevArgs.flag("--hunt"):
		hunt_gph = _hunt()
		Sim.reset_world()
		if DevArgs.has("--hunt_only"):
			get_tree().quit()
			return
	_world()
	_sell()
	_show()
	_budget(hunt_gph)
	if DevArgs.has("--exploit"):
		_exploit()
	get_tree().quit()

## O mundo do jogo (todos os mapas, bots como o main, elenco ligado) e o jogador no Leiloeiro de Aldara.
func _world() -> void:
	seed(7)
	for mid in GameData.maps:
		Sim.load_map(GameData.maps[mid])
	var names: Array = GameData.bot_names.duplicate()
	names.shuffle()
	var classes: Array = GameData.class_list()
	var k := 0
	for mid in GameData.maps:
		var md: MapDef = GameData.maps[mid]
		for i in range(md.bot_population):
			var band := BotBandSystem.spawn_levels(md)
			Sim.spawn_bot(classes[randi() % classes.size()], names[k % names.size()], mid, Sim.random_walkable(md, md.spawn_point, 10.0), randi_range(band.x, band.y))
			k += 1
	var p: SimEntity = Sim.spawn_player(GameData.classes["paladin"], "Sonda", "city_aldara")
	p.level = level
	p.recompute_stats()
	Sim.roster_start()
	_at_npc()
	print("WORLD bots=%d roster=%d nivel=%d orcamento/h=%d" % [k, Sim.roster.size(), level, AuctionSystem.budget_max(Sim)])

func _at_npc() -> void:
	var t: Array = MapsCatalog.AUCTIONEERS["city_aldara"]
	Sim.player.position = Vector3(float(t[1]) + 1.0, 0, float(t[2]))

func _fresh(seed_v: int) -> void:
	Sim.auction_on = false
	Sim.auction.clear()
	Sim.auction_rng.seed = seed_v
	AuctionSystem.start(Sim)
	AuctionSystem.update(Sim, 0.0)           # vitrine inicial (1º pulso)
	Sim.player.gold = 10000000

func _card() -> String:
	var b := AuctionSystem.band_of(level)
	var cs: Array = (AuctionSystem.band_pool(Sim, b)["card"] as Array).filter(func(c): return not GameData.cards[c].core)
	return cs[0] if not cs.is_empty() else ""

func _sell() -> void:
	var cc := _card()
	var mins: Array = []
	var unsold := 0
	for trial in 50:
		_fresh(1000 + trial)
		var p: SimEntity = Sim.player
		p.add_item(cc, 1)
		var unit := AuctionSystem.ref(Sim, GameData.items[cc])
		if Sim.auction_list(p, cc, 1, unit, 24) != "":
			unsold += 1
			continue
		var t := 0.0
		while AuctionSystem.mine_count(Sim) > 0 and t < 24.0 * 3600.0:
			AuctionSystem.update(Sim, Balance.AUCTION_TICK_S)
			t += Balance.AUCTION_TICK_S
		if (Sim.auction["mail"] as Array).any(func(m): return m["kind"] == "gold"):
			mins.append(t / 60.0)
		else:
			unsold += 1
	mins.sort()
	print("SELL carta=%s ref=%d mediana=%.1f min p25=%.1f p75=%.1f nao_vendeu=%d/50 (alvo 10-30)" % [cc, AuctionSystem.ref(Sim, GameData.items[cc]),
		_pct(mins, 0.5), _pct(mins, 0.25), _pct(mins, 0.75), unsold])

func _pct(xs: Array, q: float) -> float:
	return float(xs[clampi(int(xs.size() * q), 0, xs.size() - 1)]) if not xs.is_empty() else -1.0

func _show() -> void:
	_fresh(77)
	var b := AuctionSystem.band_of(level)
	var rnames := {}
	for r in Sim.roster:
		rnames[str(r["name"])] = true
	var seen := {}
	for l in Sim.auction["listings"]:
		seen[l["id"]] = true
	var visits: Array = []
	var signed := 0
	var total := 0
	var steps := int(hours * 3600.0 / 600.0)
	for v in steps:
		for i in int(600.0 / Balance.AUCTION_TICK_S):
			AuctionSystem.update(Sim, Balance.AUCTION_TICK_S)
		var n := 0
		for l in Sim.auction["listings"]:
			if seen.has(l["id"]):
				continue
			seen[l["id"]] = true
			total += 1
			if rnames.has(str(l["seller"])):
				signed += 1
			if int(l["band"]) == b:
				n += 1
		visits.append(n)
	visits.sort()
	var counts := AuctionSystem.band_counts(Sim)
	print("SHOW faixa=%d novos_por_visita mediana=%d min=%d (alvo >= 5) elenco=%.0f%% vitrine_total=%d por_faixa=%s" % [b, int(_pct(visits, 0.5)),
		int(visits[0]) if not visits.is_empty() else -1, 100.0 * signed / maxf(1.0, total), (Sim.auction["listings"] as Array).size(), counts])

## Jogador que mantém 12 anúncios (cartas e materiais da faixa, na sugestão, 8 h) e pega o ouro.
func _budget(hunt_gph: float) -> void:
	_fresh(99)
	var p: SimEntity = Sim.player
	var pool := AuctionSystem.band_pool(Sim, AuctionSystem.band_of(level))
	var stock: Array = (pool["card"] as Array).slice(0, 4) + (pool["material"] as Array).slice(0, 8)
	var fees := 0
	var pulses := int(hours * 3600.0 / Balance.AUCTION_TICK_S)
	var paid0 := int(Sim.auction["paid"])
	for i in pulses:
		var k := 0
		while AuctionSystem.mine_count(Sim) < Balance.AUCTION_PLAYER_LISTINGS and k < 30:
			var iid: String = stock[(i + k) % stock.size()]
			var it: ItemDef = GameData.items[iid]
			var cnt := 1 if it.type == ItemDef.Type.CARD else 5
			p.add_item(iid, cnt)
			var unit := Sim.auction_suggest(iid)
			var g := p.gold
			if Sim.auction_list(p, iid, cnt, unit, 8) == "":
				fees += g - p.gold
			else:
				p.remove_item(iid, cnt)
			k += 1
		AuctionSystem.update(Sim, Balance.AUCTION_TICK_S)
		Sim.auction["mail"] = []
	var paid := int(Sim.auction["paid"]) - paid0
	var gph := paid / hours
	print("BUDGET pago_por_bots=%.0f ouro/h orcamento=%d/h (%.0f%%) taxas=%.0f/h caca=%s%s" % [gph, AuctionSystem.budget_max(Sim),
		100.0 * gph / maxf(1.0, AuctionSystem.budget_max(Sim)), fees / hours, ("%.0f ouro/h" % hunt_gph) if hunt_gph >= 0.0 else "(use --hunt)",
		(" leilao/caca=%.0f%% (alvo ~30%%)" % (100.0 * gph / maxf(1.0, hunt_gph))) if hunt_gph > 0.0 else ""])

# ---------------------------------------------------------------------------
# LAÇOS (§5)

func _exploit() -> void:
	var cut := Balance.AUCTION_CUT
	var mood_hi := float(Balance.AUCTION_BUY_MOOD[1])
	# 1. mercador (Feira) -> bot: anuncia cada item de loja no teto máximo de bot e calcula o lucro/unidade
	_fresh(500)
	var best_shop := -INF
	var best_id := ""
	for iid in GameData.items:
		var it: ItemDef = GameData.items[iid]
		if AuctionSystem.sellable(it) != "" or not AuctionSystem.shop_sold(Sim, iid):
			continue
		var unit := floori(AuctionSystem.teto_bot(Sim, it, mood_hi))
		var profit := unit * (1.0 - cut) - it.price * (1.0 - Balance.CHAIN_FAIR_DISCOUNT) - AuctionSystem.fee(2, unit) / 1.0
		if profit > best_shop:
			best_shop = profit
			best_id = iid
	print("EXPLOIT mercador->bot melhor lucro/unidade=%.1f (%s) -> ouro/h <= %s" % [best_shop, best_id, "0" if best_shop <= 0.0 else "%.0f" % (best_shop * 999)])
	# 2. bot -> mercador: comprar o anúncio de bot mais barato e vender ao mercador
	var best_bm := -INF
	for h in int(3600.0 / Balance.AUCTION_TICK_S):
		AuctionSystem.update(Sim, Balance.AUCTION_TICK_S)
		for l in Sim.auction["listings"]:
			if not l["mine"]:
				best_bm = maxf(best_bm, CraftSystem.sell_price(GameData.items[l["item"]]) - int(l["unit"]))
	print("EXPLOIT bot->mercador melhor lucro/unidade=%.1f (<= 0 esperado)" % best_bm)
	# 3. fabricar com material comprado (no mais barato) e vender a bot no teto
	var best_craft := -INF
	var best_r := ""
	for rid in GameData.recipes:
		var r: RecipeDef = GameData.recipes[rid]
		var it: ItemDef = GameData.items.get(r.result_item)
		if it == null or AuctionSystem.sellable(it) != "":
			continue
		var mc := AuctionSystem.min_craft_cost(Sim, it)
		if mc >= INF:
			continue
		var unit := floori(AuctionSystem.teto_bot(Sim, it, mood_hi))
		var profit := unit * (1.0 - cut) - mc
		if profit > best_craft:
			best_craft = profit
			best_r = rid
	print("EXPLOIT fabricar->bot melhor lucro/unidade=%.1f (%s; <= 0 esperado)" % [best_craft, best_r])
	# 4. aprimorar para vender
	var best_plus := -INF
	for t in Balance.COMMON_TIER_LEVELS.size():
		for b: ItemDef in LootSystem.gear_pool(Sim, t).slice(0, 6):
			var tb := AuctionSystem.teto_bot(Sim, b, mood_hi)
			for n in range(1, Balance.PLUS_MAX + 1):
				var pi: ItemDef = GameData.plus_item(b, n)
				best_plus = maxf(best_plus, (AuctionSystem.teto_bot(Sim, pi, mood_hi) - tb) * (1.0 - cut) - AuctionSystem.plus_gold(Sim, b, n))
	print("EXPLOIT aprimorar->bot melhor lucro/peça=%.1f (<= 0 esperado)" % best_plus)
	# 5. arbitragem: 1 h comprando anúncio de bot abaixo do teto médio e revendendo para bot no teto (taxas e comissão pagas)
	_fresh(600)
	var p: SimEntity = Sim.player
	var gold0 := p.gold
	var held := {}
	for h in int(3600.0 / Balance.AUCTION_TICK_S):
		for l in (Sim.auction["listings"] as Array).duplicate():
			if l["mine"]:
				continue
			var it: ItemDef = GameData.items[l["item"]]
			if float(l["unit"]) < AuctionSystem.teto_bot(Sim, it, 0.0) * 0.85 and (Sim.auction["mail"] as Array).size() < Balance.AUCTION_MAIL_MAX - 1:
				Sim.auction_buy(p, int(l["id"]))
		Sim.auction_collect(p)
		for iid in p.inventory.keys():
			if AuctionSystem.mine_count(Sim) >= Balance.AUCTION_PLAYER_LISTINGS:
				break
			var it: ItemDef = GameData.items[iid]
			var n := mini(int(p.inventory[iid]), it.stack_max)
			var unit := clampi(floori(AuctionSystem.teto_bot(Sim, it, 0.0)), AuctionSystem.price_range(Sim, it).x, AuctionSystem.price_range(Sim, it).y)
			Sim.auction_list(p, iid, n, unit, 2)
		AuctionSystem.update(Sim, Balance.AUCTION_TICK_S)
		held = p.inventory.duplicate()
	Sim.auction_collect(p)
	var stock_val := 0
	for iid in p.inventory:
		stock_val += CraftSystem.sell_price(GameData.items[iid]) * int(p.inventory[iid])
	for l in Sim.auction["listings"]:
		if l["mine"]:
			stock_val += CraftSystem.sell_price(GameData.items[l["item"]]) * int(l["count"])
	var net := p.gold - gold0 + stock_val
	print("EXPLOIT arbitragem 1h lucro=%d (estoque ao preço do mercador %d) orcamento/h=%d -> %s" % [net, stock_val, AuctionSystem.budget_max(Sim),
		"ok" if net <= AuctionSystem.budget_max(Sim) else "ACIMA"])

# ---------------------------------------------------------------------------
# OURO/H DE CAÇA

## 4 bots do nível caçando num mapa da faixa; ouro + venda ao mercador do que juntaram, por bot por hora.
func _hunt() -> float:
	var map_id: String = DevArgs.value("--hunt") if DevArgs.value("--hunt") != "" else str(HUNT_MAPS.get(AuctionSystem.band_of(level), "field_ruins"))
	var minutes := float(DevArgs.value("--minutes")) if DevArgs.flag("--minutes") else 20.0
	var md: MapDef = GameData.maps[map_id]
	Sim.load_map(GameData.maps[GameData.town_map_id()])
	Sim.load_map(md)
	for i in range(200):
		Sim.tick(DT)
	var classes := ["paladin", "berserker", "ranger", "elementalist"]
	var bots: Array = []
	for i in 4:
		var b: SimEntity = Sim.spawn_bot(GameData.classes[classes[i]], "Caca%d" % i, map_id, Sim.random_walkable(md, md.spawn_point, 3.0), level)
		b.brain.state = BotBrain.S.HUNT
		b.brain.timer = 99999.0
		bots.append(b)
	var worth := func(b: SimEntity) -> int:
		var v := b.gold
		for iid in b.inventory:
			var it: ItemDef = GameData.items.get(iid)
			if it and it.type != ItemDef.Type.QUEST:
				v += CraftSystem.sell_price(it) * int(b.inventory[iid])
		return v
	var w0: Array = bots.map(func(b): return worth.call(b))
	var g0: Array = bots.map(func(b): return b.gold)
	for i in int(minutes * 60.0 / DT):
		Sim.tick(DT)
	var gain := 0
	for i in bots.size():
		gain += int(worth.call(bots[i])) - int(w0[i])
	var gold := 0
	for i in bots.size():
		gold += bots[i].gold - int(g0[i])
	var gph := gain / float(bots.size()) / (minutes / 60.0)
	print("HUNT mapa=%s nivel=%d bots=%d min=%.0f ouro/h por bot=%.0f (ouro + venda ao mercador; só ouro %.0f)" % [map_id, level, bots.size(), minutes, gph,
		gold / float(bots.size()) / (minutes / 60.0)])
	return gph
