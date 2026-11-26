class_name MvpSystem
extends RefCounted
## Prêmios de MVP (design/gdd/mvp-premios.md; contrato production/session-state/wave5-contract.md A/B).
## O Chefe de Mundo morre -> WorldBossSystem chama `award(sim, boss_id, participants)` (só quem passou do mínimo).
## Cada participante: Insígnias de Caçada (SimEntity.mvp_coins), Baú do MVP (item, abre com escolha 1 de 3 pacotes),
## sorteios independentes de Pergaminho de Refino / Superior / cosmético de montaria / Carta de MVP. Bolsa cheia = correio
## do Intendente (SimEntity.mvp_mail). Loja do Intendente (shop_rows/buy), pergaminho no ferreiro (scroll_error/use_scroll).
## Sem estado próprio; sorteios só no rng da sim; números em Balance.MVP_*.

const CHEST_PREFIX := "mvp_chest_"

# --- faixa e mesa -------------------------------------------------------------

## Índice da faixa do chefe (Balance.MVP_BAND_STARTS) ou -1 se não é Chefe de Mundo.
static func band_of(boss_id: String) -> int:
	var wb: Dictionary = MonstersCatalog.WORLD_BOSSES.get(boss_id, {})
	if wb.is_empty():
		return -1
	var lo := int(wb["band"][0])
	var out := 0
	for i in range(Balance.MVP_BAND_STARTS.size()):
		if lo >= int(Balance.MVP_BAND_STARTS[i]):
			out = i
	return out

static func chest_id(band: int) -> String:
	return CHEST_PREFIX + str(band)

## Pacotes de um Baú (item) ou de uma faixa: [{"items": {id: n}, "gold": n}] x3.
static func chest_packs(item_id: String) -> Array:
	var it: ItemDef = GameData.items.get(item_id)
	if it == null or not it.consume.has("mvp_chest"):
		return []
	var b := clampi(int(it.consume["mvp_chest"]), 0, Balance.MVP_CHEST.size() - 1)
	return Balance.MVP_CHEST[b]

## Texto de um pacote ("5 Minério de Ferro + 300 ouro").
static func pack_text(pack: Dictionary) -> String:
	var parts: Array = []
	for iid in pack.get("items", {}):
		var ii: ItemDef = GameData.items.get(iid)
		parts.append("%d %s" % [int(pack["items"][iid]), ii.name if ii else str(iid)])
	if int(pack.get("gold", 0)) > 0:
		parts.append("%d ouro" % int(pack["gold"]))
	return " + ".join(parts)

## Tipo de montaria do chefe ("" = nenhum).
static func kind_of_boss(boss_id: String) -> String:
	for k in Balance.MOUNT_KINDS:
		if str(Balance.MOUNT_KINDS[k].get("mvp", "")) == boss_id:
			return k
	return ""

## Cosméticos que o chefe dá (chaves da coleção): tipo, cores 1.., barda temática e a genérica (MVP_GENERIC_BARDING).
static func cosmetics_of(boss_id: String) -> Array:
	var out: Array = []
	var k := kind_of_boss(boss_id)
	if k != "":
		out.append("kind:" + k)
		for i in range(1, MountSystem.dyes_of(k).size()):
			out.append("dye:%s:%d" % [k, i])
		if Balance.MOUNT_BARDINGS.has("barding_" + k):
			out.append("barding:barding_" + k)
	for st in Balance.MVP_GENERIC_BARDING:
		if boss_id in Balance.MVP_GENERIC_BARDING[st]:
			out.append("barding:" + st)
	return out

## Chefe que dá o cosmético ("" = nenhum / livre).
static func boss_of_cosmetic(key: String) -> String:
	for wb in MonstersCatalog.WORLD_BOSSES:
		if key in cosmetics_of(wb):
			return wb
	return ""

static func owns(e: SimEntity, key: String) -> bool:
	var p := key.split(":")
	match p[0]:
		"kind": return MountSystem.unlocked(e, p[1])
		"dye": return p.size() == 3 and MountSystem.dye_owned(e, p[1], int(p[2]))
		"barding": return MountSystem.barding_owned(e, p[1])
	return false

## Nome do cosmético para o jogador.
static func cosmetic_name(key: String) -> String:
	var p := key.split(":")
	match p[0]:
		"kind": return "Montaria: %s" % Balance.MOUNT_KINDS.get(p[1], {}).get("name", p[1])
		"dye": return "Cor %d do %s" % [int(p[2]) + 1, Balance.MOUNT_KINDS.get(p[1], {}).get("name", p[1])]
		"barding": return str(Balance.MOUNT_BARDINGS.get(p[1], p[1]))
	return key

## "de onde vem" (aba Montaria e loja).
static func cosmetic_source(key: String) -> String:
	var b := boss_of_cosmetic(key)
	if b == "":
		return ""
	var md: MonsterDef = GameData.monsters.get(b)
	return "Chefe de Mundo: %s (ou a loja do Intendente das Caçadas)" % (md.name if md else b)

## Põe na coleção. false = já tinha.
static func grant_cosmetic(sim: WorldSim, e: SimEntity, key: String) -> bool:
	if owns(e, key):
		return false
	e.mount_cosmetics[key] = true
	Events.post(&"mvp_changed", e.id)
	return true

# --- prêmio --------------------------------------------------------------------

## Bolsa ou correio. Bots não usam correio (a bolsa deles não trava nada). true = foi para a bolsa.
static func give(e: SimEntity, item_id: String, n: int) -> bool:
	if e.kind == SimEntity.Kind.PLAYER and e.bag_full_for(item_id):
		e.mvp_mail[item_id] = int(e.mvp_mail.get(item_id, 0)) + n
		return false
	e.add_item(item_id, n)
	return true

## O Chefe de Mundo `boss_id` caiu: premia cada participante (ids acima de WORLD_BOSS_SHARE_MIN; quem chama filtra).
## Devolve {id: resumo} com resumo = {boss, band, coins, chest, scroll, super, cosmetic, dup, card, mail: [ids]}.
## `force` (testes/revisão): {"scroll"|"super"|"cosmetic"|"card": true/false} troca o sorteio por sim/não.
static func award(sim: WorldSim, boss_id: String, participants: Array, force: Dictionary = {}) -> Dictionary:
	var out := {}
	var band := band_of(boss_id)
	if band < 0:
		return out
	var md: MonsterDef = GameData.monsters.get(boss_id)
	var bname := md.name if md else boss_id
	for pid in participants:
		var e: SimEntity = sim.get_entity(int(pid))
		if e == null or not e.is_character():
			continue
		var s := {"boss": boss_id, "band": band, "coins": 0, "chest": chest_id(band), "scroll": false, "super": false,
			"cosmetic": "", "dup": 0, "card": "", "mail": []}
		e.mvp_fights[boss_id] = int(e.mvp_fights.get(boss_id, 0)) + 1
		var coins := int(Balance.MVP_COINS[band])
		if not give(e, chest_id(band), 1):
			s["mail"].append(chest_id(band))
		if _roll(sim, Balance.MVP_SCROLL_CHANCE, force, "scroll"):
			s["scroll"] = true
			if not give(e, Balance.MVP_SCROLL, 1):
				s["mail"].append(Balance.MVP_SCROLL)
		if band >= Balance.MVP_SUPER_MIN_BAND and _roll(sim, Balance.MVP_SUPER_SCROLL_CHANCE, force, "super"):
			s["super"] = true
			if not give(e, Balance.MVP_SUPER_SCROLL, 1):
				s["mail"].append(Balance.MVP_SUPER_SCROLL)
		if _roll(sim, Balance.MVP_COSMETIC_CHANCE, force, "cosmetic"):
			var missing: Array = cosmetics_of(boss_id).filter(func(k): return not owns(e, k))
			if missing.is_empty():
				s["dup"] = Balance.MVP_DUP_COINS          # já tem tudo do chefe: vira insígnias
				coins += Balance.MVP_DUP_COINS
			else:
				var key: String = missing[sim.rng.randi() % missing.size()]
				grant_cosmetic(sim, e, key)
				s["cosmetic"] = key
		var card := "card_" + boss_id
		if GameData.cards.has(card) and _roll(sim, Balance.MVP_CARD_CHANCE, force, "card"):     # Ato II/III sem carta ainda: pula
			s["card"] = card
			if not give(e, card, 1):
				s["mail"].append(card)
			CardSystem.on_pickup(sim, e, card)
		e.mvp_coins += coins
		s["coins"] = coins
		if sim.player != null and sim.player.map_id == e.map_id:          # prêmio raro aparece para todo o mapa
			for rare in [s["cosmetic"], s["card"]]:
				if rare != "":
					var what: String = cosmetic_name(rare) if rare == s["cosmetic"] else GameData.cards[rare].name
					Events.post(&"chat_message", "Caçadas", "%s ganhou %s do %s!" % [e.name, what, bname], "system")
		if e.kind == SimEntity.Kind.BOT:
			bot_spend(sim, e)
		Events.post(&"mvp_changed", e.id)
		Events.post(&"mvp_award", e.id, s)
		out[e.id] = s
	return out

static func _roll(sim: WorldSim, chance: float, force: Dictionary, key: String) -> bool:
	if force.has(key):
		return bool(force[key])
	return sim.rng.randf() < chance

## Abre um Baú do MVP e fica com o pacote `pick` (0-2); os outros somem. "" = deu certo.
static func open_chest_error(e: SimEntity, item_id: String, pick: int) -> String:
	var packs := chest_packs(item_id)
	if packs.is_empty():
		return "Não é um Baú do MVP"
	if not e.has_item(item_id):
		return "Você não tem esse baú"
	if pick < 0 or pick >= packs.size():
		return "Escolha um pacote"
	var room := e.bag_capacity() - e.inventory.size() + (1 if int(e.inventory[item_id]) == 1 else 0)
	for iid in packs[pick]["items"]:
		if not e.inventory.has(iid):
			room -= 1
	if room < 0:
		return "Bolsa cheia"
	return ""

static func open_chest(sim: WorldSim, e: SimEntity, item_id: String, pick: int) -> bool:
	if open_chest_error(e, item_id, pick) != "":
		return false
	var pack: Dictionary = chest_packs(item_id)[pick]
	e.remove_item(item_id, 1)
	for iid in pack["items"]:
		e.add_item(iid, int(pack["items"][iid]))
	e.gold += int(pack.get("gold", 0))
	if e == sim.player:
		Events.post(&"notification", "Baú do MVP: %s" % pack_text(pack))
	return true

## Correio do Intendente: passa para a bolsa o que couber. Devolve quantas pilhas passaram.
static func take_mail(sim: WorldSim, e: SimEntity) -> int:
	var n := 0
	for iid in e.mvp_mail.keys():
		if e.bag_full_for(iid):
			continue
		e.add_item(iid, int(e.mvp_mail[iid]))
		e.mvp_mail.erase(iid)
		n += 1
	if n > 0:
		Events.post(&"mvp_changed", e.id)
		if e == sim.player and not e.mvp_mail.is_empty():
			Events.post(&"notification", "Bolsa cheia: o resto fica no correio")
	return n

# --- loja do Intendente das Caçadas (§3.6) ---------------------------------------

## Linhas da loja: [{id, name, price, ok, why, source}]. id = item (pergaminho) ou chave da coleção.
## Cores/bardas: de chefe já enfrentado; tipo: depois de MVP_MOUNT_FIGHTS lutas. Nunca carta nem baú.
static func shop_rows(e: SimEntity) -> Array:
	var out: Array = []
	out.append(_row(e, Balance.MVP_SCROLL, GameData.items[Balance.MVP_SCROLL].name, Balance.MVP_SHOP_SCROLL, ""))
	var sup_why := "" if e.level >= Balance.MVP_SHOP_SUPER_LEVEL else "Só com nível %d+" % Balance.MVP_SHOP_SUPER_LEVEL
	out.append(_row(e, Balance.MVP_SUPER_SCROLL, GameData.items[Balance.MVP_SUPER_SCROLL].name, Balance.MVP_SHOP_SUPER, sup_why))
	for boss in MonstersCatalog.WORLD_BOSSES:
		var fights := int(e.mvp_fights.get(boss, 0))
		if fights <= 0:
			continue
		var md: MonsterDef = GameData.monsters.get(boss)
		for key in cosmetics_of(boss):
			if owns(e, key):
				continue
			var why := ""
			var price := Balance.MVP_SHOP_DYE
			if key.begins_with("kind:"):
				price = Balance.MVP_SHOP_MOUNT
				if fights < Balance.MVP_MOUNT_FIGHTS:
					why = "Enfrente %s %d/%d vezes" % [md.name if md else boss, fights, Balance.MVP_MOUNT_FIGHTS]
			elif key.begins_with("barding:"):
				price = Balance.MVP_SHOP_BARDING
			var r := _row(e, key, cosmetic_name(key), price, why)
			r["source"] = md.name if md else boss
			out.append(r)
	return out

static func _row(e: SimEntity, id: String, name: String, price: int, why: String) -> Dictionary:
	if why == "" and e.mvp_coins < price:
		why = "Faltam %d insígnias" % (price - e.mvp_coins)
	return {"id": id, "name": name, "price": price, "ok": why == "", "why": why, "source": ""}

## Compra a linha `id` da loja. "" = comprou; senão o motivo.
static func buy(sim: WorldSim, e: SimEntity, id: String) -> String:
	for r in shop_rows(e):
		if r["id"] != id:
			continue
		if not r["ok"]:
			return str(r["why"])
		if GameData.items.has(id):
			if e.bag_full_for(id):
				return "Bolsa cheia"
			e.add_item(id, 1)
		elif not grant_cosmetic(sim, e, id):
			return "Você já tem"
		e.mvp_coins -= int(r["price"])
		Events.post(&"mvp_changed", e.id)
		if e == sim.player:
			Events.post(&"notification", "Comprado: %s" % r["name"])
		return ""
	return "Fora da loja"

# --- Pergaminho de Refino (§3.3) ---------------------------------------------------

## Até onde o pergaminho leva (0 = não é pergaminho).
static func scroll_target(scroll_id: String) -> int:
	if scroll_id == Balance.MVP_SCROLL:
		return Balance.MVP_SCROLL_TARGET
	if scroll_id == Balance.MVP_SUPER_SCROLL:
		return Balance.MVP_SUPER_TARGET
	return 0

## Por que o pergaminho não vale nesta peça ("" = vale). Qualquer ferreiro (inclusive lendário 40+), sem ouro nem material.
static func scroll_error(e: SimEntity, item_id: String, slot: int, scroll_id: String) -> String:
	var target := scroll_target(scroll_id)
	if target <= 0:
		return "Pergaminho desconhecido"
	if not e.has_item(scroll_id):
		return "Você não tem %s" % GameData.items[scroll_id].name
	var it: ItemDef = GameData.items.get(item_id)
	if it == null or not it.is_equipment():
		return "Só equipamento pode ser refinado"
	var owned: bool = (e.equipment.get(slot) != null and e.equipment[slot].id == item_id) if slot >= 0 else e.has_item(item_id)
	if not owned:
		return "Você não tem esse item"
	if scroll_id == Balance.MVP_SCROLL and it.plus >= Balance.MVP_SCROLL_TARGET:
		return "A peça já está em +%d: este pergaminho leva só até +%d" % [it.plus, Balance.MVP_SCROLL_TARGET]
	if scroll_id == Balance.MVP_SUPER_SCROLL:
		if it.plus < Balance.MVP_SCROLL_TARGET:
			return "O Superior vale em peça +%d ou +%d" % [Balance.MVP_SCROLL_TARGET, Balance.MVP_SUPER_TARGET - 1]
		if it.plus >= Balance.MVP_SUPER_TARGET:
			return "A peça já está em +%d" % it.plus
	return ""

## Usa o pergaminho: a cópia vira a versão +5 (ou +7). Devolve a versão nova (ou null).
static func use_scroll(sim: WorldSim, e: SimEntity, item_id: String, slot: int, scroll_id: String) -> ItemDef:
	if scroll_error(e, item_id, slot, scroll_id) != "":
		return null
	var it: ItemDef = GameData.items[item_id]
	var base: ItemDef = GameData.items.get(it.base_id, it) if it.base_id != "" else it
	var nxt := GameData.plus_item(base, scroll_target(scroll_id))
	e.remove_item(scroll_id, 1)
	if slot >= 0:
		e.equipment[slot] = nxt
	else:
		e.remove_item(item_id, 1)
		e.add_item(nxt.id, 1)
	e.recompute_stats()
	Events.post(&"equipment_changed", e.id)
	if e == sim.player:
		Events.post(&"notification", "%s pronto!" % nxt.name)
	return nxt

# --- bots (§3.7) ------------------------------------------------------------------

## Bot: abre os baús (pacote sorteado) e gasta as insígnias em pergaminhos para a peça vestida mais fraca.
static func bot_spend(sim: WorldSim, e: SimEntity) -> void:
	for b in range(Balance.MVP_CHEST.size()):
		while e.has_item(chest_id(b)) and open_chest(sim, e, chest_id(b), sim.rng.randi() % 3):
			pass
	for _guard in range(8):
		var used := false
		for sc in [Balance.MVP_SUPER_SCROLL, Balance.MVP_SCROLL]:
			var slot := _bot_scroll_slot(e, sc)
			if slot < 0:
				continue
			if not e.has_item(sc):
				if buy(sim, e, sc) != "":
					continue
			if use_scroll(sim, e, e.equipment[slot].id, slot, sc) != null:
				used = true
				break
		if not used:
			return

## Vaga vestida em que o pergaminho rende (menor +N que ele aceita) ou -1.
static func _bot_scroll_slot(e: SimEntity, scroll_id: String) -> int:
	var best := -1
	var best_plus := 99
	for sl in e.equipment:
		var it: ItemDef = e.equipment[sl]
		if it != null and it.plus < best_plus and scroll_error_free(e, it, scroll_id):
			best = int(sl)
			best_plus = it.plus
	return best

static func scroll_error_free(e: SimEntity, it: ItemDef, scroll_id: String) -> bool:
	if scroll_id == Balance.MVP_SCROLL:
		return it.plus < Balance.MVP_SCROLL_TARGET
	return it.plus >= Balance.MVP_SCROLL_TARGET and it.plus < Balance.MVP_SUPER_TARGET

## Vitrine (§3.7): parte dos bots já nasce com o bicho de um MVP da faixa deles. Sorteio fixo pelo id (não gasta o rng).
static func bot_showcase(e: SimEntity) -> void:
	if e.kind != SimEntity.Kind.BOT:
		return
	var h := (e.id * 2654435761) % 1000
	if h >= int(Balance.BOT_MVP_SHOWCASE * 1000.0):
		return
	var kinds: Array = []
	for boss in MonstersCatalog.WORLD_BOSSES:
		var k := kind_of_boss(boss)
		if k != "" and int(MonstersCatalog.WORLD_BOSSES[boss]["band"][0]) <= e.level:
			kinds.append(k)
	if kinds.is_empty():
		return
	var pick: String = kinds[(e.id * 40503) % kinds.size()]
	e.mount_cosmetics["kind:" + pick] = true
	e.mount_kind = pick

# --- save -------------------------------------------------------------------------

## Campos opcionais: mvp_coins, mvp_fights, mount_cosmetics, mvp_mail (o mount_look é do MountSystem).
static func to_save(e: SimEntity) -> Dictionary:
	return {"mvp_coins": e.mvp_coins, "mvp_fights": e.mvp_fights.duplicate(), "mount_cosmetics": e.mount_cosmetics.keys(),
		"mvp_mail": e.mvp_mail.duplicate(), "mount_look": MountSystem.look_to_save(e)}

## Save sem os campos = vazio (§5). Lê a coleção antes da montaria (o tipo de MVP só vale com ela).
static func from_save(e: SimEntity, d: Dictionary) -> void:
	e.mvp_coins = maxi(0, int(d.get("mvp_coins", 0)))
	e.mvp_fights = {}
	var f = d.get("mvp_fights", {})
	if f is Dictionary:
		for b in f:
			e.mvp_fights[str(b)] = int(f[b])
	e.mount_cosmetics = {}
	for k in d.get("mount_cosmetics", []):
		e.mount_cosmetics[str(k)] = true
	e.mvp_mail = {}
	var m = d.get("mvp_mail", {})
	if m is Dictionary:
		for iid in m:
			if GameData.items.has(str(iid)):
				e.mvp_mail[str(iid)] = int(m[iid])
	e.mount_kind = MountSystem.from_save(e, str(d.get("mount", Balance.MOUNT_DEFAULT)))
	MountSystem.look_from_save(e, d)
