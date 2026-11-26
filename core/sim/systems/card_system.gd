class_name CardSystem
extends RefCounted
## Cartas de Monstro (GDD design/gdd/cartas.md): sorteio no abate, encaixes do personagem, combos, ganchos de efeito e
## bestiário. Sem estado próprio: tudo em SimEntity.cards / bestiary / card_fx. Números em Balance.CARD_*.

const SEEN := 1        # bits de SimEntity.bestiary
const FOUND := 2
## Ganchos que não são stat (o resto vai para card_fx["stats"], somado no Stats.compute)
const HOOKS := ["family_dmg", "family_def", "proc_poison", "proc_slow", "proc_stun", "kill_heal", "gold_pct", "dash_pct"]     # xp_pct é stat (Poções de Caça)

## --- Sorteio ---

## Carta que este monstro dá ("" = nenhuma): base da metamorfose, base do Rei, Eco = a do chefe.
static func card_for_mob(mob: SimEntity) -> String:
	if mob.kind != SimEntity.Kind.MONSTER or mob.road_event or mob.boss_id >= 0:
		return ""
	var md: MonsterDef = mob.shift_base if mob.shift_base != null else mob.monster_def
	if md == null:
		return ""
	var mid := md.elite_of if md.elite_of != "" else md.id
	return str(GameData.card_of.get(mid, ""))

## Chance de `c` achar a carta `card_id` neste abate.
static func drop_chance(sim: WorldSim, c: SimEntity, mob: SimEntity, card_id: String) -> float:
	var cd: CardDef = GameData.cards.get(card_id)
	if cd == null:
		return 0.0
	var md: MonsterDef = mob.shift_base if mob.shift_base != null else mob.monster_def
	var p: float
	if CardsCatalog.ECHOES.has(md.id):
		p = Balance.CARD_CHANCE_ECHO
	elif cd.boss:
		p = Balance.CARD_CHANCE_BOSS
	elif cd.core:
		p = Balance.CARD_CHANCE_CORE
	else:
		p = Balance.CARD_CHANCE_COMMON
	if md.elite_of != "":
		p *= Balance.CARD_ELITE_MULT
	return minf(p * LootSystem.drop_mult(c), 1.0)     # Elixir da Fortuna

## Abate: marca visto no bestiário de quem divide e sorteia a carta de cada um (regra do lendário: pessoal).
## `force` (testes): -1 = sorteio normal, 0 = nunca, 1 = sempre.
static func on_kill(sim: WorldSim, sharers: Array, mob: SimEntity, force: int = -1) -> void:
	var md: MonsterDef = mob.shift_base if mob.shift_base != null else mob.monster_def
	var card_id := card_for_mob(mob)
	for c: SimEntity in sharers:
		if c == sim.player and md != null:
			var mid := md.elite_of if md.elite_of != "" else (str(CardsCatalog.ECHOES.get(md.id, md.id)))
			c.bestiary[mid] = int(c.bestiary.get(mid, 0)) | SEEN
		if not c.card_fx.is_empty() and float(c.card_fx.get("kill_heal", 0.0)) > 0.0 and c.is_alive():
			c.hp = minf(c.stats.max_hp, c.hp + c.stats.max_hp * float(c.card_fx["kill_heal"]) / 100.0)
		if card_id == "":
			continue
		var hit: bool = (sim.rng.randf() < drop_chance(sim, c, mob, card_id)) if force < 0 else force > 0
		if hit:
			_drop_card(sim, c, mob, card_id)

static func _drop_card(sim: WorldSim, c: SimEntity, mob: SimEntity, card_id: String) -> void:
	var m: Dictionary = sim.maps[mob.map_id]
	var off := Vector3(0.0, 0.0, 0.7)
	m["loot"].append({"pos": mob.position + off, "item": card_id, "count": 1, "timer": Balance.CARD_LOOT_TIME,
		"owner": c.id, "free_at": sim.time + Balance.CARD_LOCK_TIME, "card": true})
	Events.post(&"loot_dropped", mob.map_id, mob.position + off, card_id, 1)
	var cd: CardDef = GameData.cards[card_id]
	if sim.player != null and sim.player.map_id == mob.map_id:          # aviso no chat do mapa
		Events.post(&"chat_message", "Cartas", "%s achou a %s!" % [c.name, cd.name], "system")
		Events.post(&"card_found", c.id, card_id)
	if c.kind == SimEntity.Kind.BOT and sim.player != null and sim.player.map_id == c.map_id and not CardsCatalog.BOT_LINES.is_empty():
		var line: String = CardsCatalog.BOT_LINES[sim.rng.randi() % CardsCatalog.BOT_LINES.size()]
		Events.post(&"chat_message", c.name, line % cd.name, "global")

## Pegou uma carta do chão (LootSystem.pickup): bestiário do jogador.
static func on_pickup(sim: WorldSim, e: SimEntity, item_id: String) -> void:
	var cd: CardDef = GameData.cards.get(item_id)
	if cd == null or e != sim.player:
		return
	e.bestiary[cd.monster_id] = int(e.bestiary.get(cd.monster_id, 0)) | SEEN | FOUND

## --- Encaixes ---

## Por que não dá para encaixar ("" = dá). Ex.: socket_error(sim, p, "weapon", "card_wolf") -> "Carta de botas".
static func socket_error(sim: WorldSim, e: SimEntity, slot: String, card_id: String) -> String:
	if e != sim.player:
		return "Só o jogador encaixa cartas"
	var cd: CardDef = GameData.cards.get(card_id)
	if cd == null:
		return "Não é uma carta"
	if not (slot in Balance.CARD_SLOTS):
		return "Encaixe desconhecido"
	if cd.slot != slot:
		return "Esta carta vai no encaixe: %s" % CardsCatalog.SLOT_NAMES.get(cd.slot, cd.slot)
	if not e.has_item(card_id, 1):
		return "A carta não está na bolsa"
	if str(e.cards.get(slot, "")) == card_id:
		return "Já encaixada"
	if cd.core:
		var cores := 0
		for s in e.cards:
			var other: CardDef = GameData.cards.get(e.cards[s])
			if other and other.core and s != slot:
				cores += 1
		if cores >= Balance.CARD_CORE_MAX:
			return "No máximo %d núcleos encaixados" % Balance.CARD_CORE_MAX
	var old := str(e.cards.get(slot, ""))
	if old != "" and int(e.inventory.get(card_id, 0)) > 1 and e.bag_full_for(old):     # a antiga volta e não cabe
		return "Bolsa cheia"
	return ""

## Encaixa a carta da bolsa no encaixe dela; a que estava lá volta para a bolsa. "" = ok, senão o motivo.
static func socket(sim: WorldSim, e: SimEntity, slot: String, card_id: String) -> String:
	var err := socket_error(sim, e, slot, card_id)
	if err != "":
		return err
	var old := str(e.cards.get(slot, ""))
	e.remove_item(card_id, 1)
	if old != "":
		e.add_item(old, 1)
	e.cards[slot] = card_id
	refresh(e)
	Events.post(&"cards_changed", e.id)
	return ""

## Tira a carta do encaixe, de graça (D9). "" = ok.
static func unsocket(sim: WorldSim, e: SimEntity, slot: String) -> String:
	var old := str(e.cards.get(slot, ""))
	if old == "":
		return "Encaixe vazio"
	if e.bag_full_for(old):
		return "Bolsa cheia"
	e.cards.erase(slot)
	e.add_item(old, 1)
	refresh(e)
	Events.post(&"cards_changed", e.id)
	return ""

## Grupos com quantas cartas encaixadas: {grupo: n}.
static func group_counts(e: SimEntity) -> Dictionary:
	var out := {}
	for s in e.cards:
		var cd: CardDef = GameData.cards.get(e.cards[s])
		if cd and cd.group != "":
			out[cd.group] = int(out.get(cd.group, 0)) + 1
	return out

## Recalcula card_fx (stats somados + ganchos) e os stats. Chame depois de mexer em e.cards.
static func refresh(e: SimEntity) -> void:
	var fx := {"stats": {}, "family_dmg": {}, "family_def": {}}
	var any := false
	for s in e.cards:
		var cd: CardDef = GameData.cards.get(e.cards[s])
		if cd == null:
			continue
		any = true
		_add(fx, cd.effect, cd.value, cd.family)
	var gc := group_counts(e)
	for g in gc:
		var bon: Array = Balance.CARD_GROUP_BONUS.get(g, [])
		for i in range(mini(int(gc[g]) - 1, bon.size())):
			var b: Dictionary = bon[i]
			for k in b:
				if b[k] is Dictionary:
					for f in b[k]:
						_add(fx, k, float(b[k][f]), f)
				else:
					_add(fx, k, float(b[k]))
	e.card_fx = fx if any else {}
	e.recompute_stats()

static func _add(fx: Dictionary, effect: String, v: float, family: String = "") -> void:
	if effect == "family_dmg" or effect == "family_def":
		fx[effect][family] = float(fx[effect].get(family, 0.0)) + v
	elif effect in HOOKS:
		fx[effect] = float(fx.get(effect, 0.0)) + v
	else:
		fx["stats"][effect] = float(fx["stats"].get(effect, 0.0)) + v

## Tira do encaixe o que não é mais carta (save antigo/catálogo mudou) e recalcula.
static func sanitize(e: SimEntity) -> void:
	for s in e.cards.keys():
		var cd: CardDef = GameData.cards.get(str(e.cards[s]))
		if cd == null or cd.slot != s or not (s in Balance.CARD_SLOTS):
			e.cards.erase(s)
	refresh(e)

## Save: encaixes e bestiário (campos opcionais; save antigo = vazio). Carta que saiu do catálogo some.
static func from_save(e: SimEntity, d: Dictionary) -> void:
	e.cards = {}
	var cs = d.get("cards")
	if cs is Dictionary:
		for s in cs:
			e.cards[str(s)] = str(cs[s])
	e.bestiary = {}
	var bs = d.get("bestiary")
	if bs is Dictionary:
		for k in bs:
			e.bestiary[str(k)] = int(bs[k])
	sanitize(e)

## --- Ganchos ---

static func fx_of(e: SimEntity, key: String) -> float:
	return 0.0 if e == null or e.card_fx.is_empty() else float(e.card_fx.get(key, 0.0))

## Família de um monstro ("" = nenhuma).
static func family_of(e: SimEntity) -> String:
	if e == null or e.monster_def == null:
		return ""
	var md: MonsterDef = e.shift_base if e.shift_base != null else e.monster_def
	var mid := md.elite_of if md.elite_of != "" else md.id
	return str(GameData.card_family.get(mid, ""))

## Multiplicador de dano pela família (quem bate com family_dmg, quem apanha com family_def).
static func damage_mult(attacker: SimEntity, target: SimEntity) -> float:
	var k := 1.0
	if not attacker.card_fx.is_empty() and target.monster_def != null:
		k *= 1.0 + float(attacker.card_fx["family_dmg"].get(family_of(target), 0.0)) / 100.0
	if not target.card_fx.is_empty() and attacker.monster_def != null:
		k *= 1.0 - minf(float(target.card_fx["family_def"].get(family_of(attacker), 0.0)), Balance.CARD_FAMILY_DEF_CAP) / 100.0
	return k

## Golpe direto que pegou: efeitos de chance (veneno, lentidão, atordoar).
static func on_hit(sim: WorldSim, attacker: SimEntity, target: SimEntity) -> void:
	var fx := attacker.card_fx
	if fx.is_empty() or not target.is_alive() or target.kind != SimEntity.Kind.MONSTER:     # sem carta (bots, monstros): sai já
		return
	if float(fx.get("proc_poison", 0.0)) > 0.0 and sim.rng.randf() * 100.0 < float(fx["proc_poison"]):
		var dps := maxf(attacker.stats.patk, attacker.stats.matk) * Balance.CARD_POISON_ATK_PCT / 100.0 * attacker.stats.dot_mult()
		target.put_debuff({"kind": "dot", "id": "card_poison_%d" % attacker.id, "remaining": Balance.CARD_POISON_S, "dps": dps, "src": attacker.id})
	if float(fx.get("proc_slow", 0.0)) > 0.0 and sim.rng.randf() * 100.0 < float(fx["proc_slow"]):
		target.put_debuff({"kind": "slow", "id": "card_slow_%d" % attacker.id, "remaining": Balance.CARD_SLOW_S * target.stats.cc_mult(), "pct": Balance.CARD_SLOW_PCT})
	if float(fx.get("proc_stun", 0.0)) > 0.0 and sim.rng.randf() * 100.0 < float(fx["proc_stun"]):
		sim._apply_effects(attacker, target, {"stun": {"duration": Balance.CARD_STUN_S}}, 0.0)

## Ouro de monstro × isto (gold_pct).
static func gold_mult(e: SimEntity) -> float:
	return 1.0 + fx_of(e, "gold_pct") / 100.0

## Distância do dash × isto (dash_pct).
static func dash_mult(e: SimEntity) -> float:
	return 1.0 + fx_of(e, "dash_pct") / 100.0

## --- Bestiário ---

## Mapas onde o monstro nasce (spawners): [map_id, ...].
static func maps_of(monster_id: String) -> Array:
	var out: Array = []
	for mid in GameData.maps:
		var md: MapDef = GameData.maps[mid]
		for sp in md.spawners:
			if str(sp.get("monster_id", "")) == monster_id and not (mid in out):
				out.append(mid)
	return out

## Cartas de um mapa (dos monstros que nascem nele).
static func cards_of_map(map_id: String) -> Array:
	var out: Array = []
	var md: MapDef = GameData.maps.get(map_id)
	if md == null:
		return out
	for sp in md.spawners:
		var cid := str(GameData.card_of.get(str(sp.get("monster_id", "")), ""))
		if cid != "" and not (cid in out):
			out.append(cid)
	return out

## Títulos ganhos: um por mapa com todas as cartas achadas (D4: só título). [{map, title}]
static func titles(e: SimEntity) -> Array:
	var out: Array = []
	var ids := GameData.maps.keys()
	ids.sort()
	for mid in ids:
		var cs := cards_of_map(mid)
		if cs.is_empty():
			continue
		var all := true
		for cid in cs:
			if int(e.bestiary.get(GameData.cards[cid].monster_id, 0)) & FOUND == 0:
				all = false
				break
		if all:
			out.append({"map": mid, "title": "Caçador de %s" % GameData.maps[mid].name})
	return out
