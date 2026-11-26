class_name HuntPotionSystem
extends RefCounted
## Poções de Caça (design/gdd/pocoes-de-caca.md): Tônico do Saber (+% XP de abate) e Elixir da Fortuna (+% chance de saque).
## O efeito é um buff por tipo (`hunt_xp`, `hunt_drop`: outro do mesmo tipo renova, não soma) com `keep_death`
## (morrer não tira, `WorldSim._kill`) e duração fixa (não estica com `buff_duration`). Os stats `xp_pct`/`drop_pct`
## somam em `Stats.compute`; os multiplicadores com teto são `LootSystem.xp_mult`/`drop_mult`. Sem estado próprio.

const KINDS := ["xp", "drop"]
const BUFF_IDS := {"xp": "hunt_xp", "drop": "hunt_drop"}
const STAT_OF := {"xp": "xp_pct", "drop": "drop_pct"}

## false = bots não tomam (testes e sondas de calibragem: as contas foram feitas sem poção).
static var bots_drink := true

## Id do item: `hunt_<tipo>_<grau 1-3>`.
static func item_id(kind: String, grade: int) -> String:
	return "hunt_%s_%d" % [kind, grade + 1]

## Buff do grau (`consume.buff` do item).
static func buff_of(kind: String, grade: int) -> Dictionary:
	var g: Array = Balance.HUNT_POTION_GRADES[grade]
	return {"id": BUFF_IDS[kind], "duration": Balance.HUNT_POTION_TIME, "keep_death": true,
		STAT_OF[kind]: float(g[2] if kind == "xp" else g[3])}

## Poção de Caça `b` é mais FRACA que a do mesmo tipo já ativa em `e`? (recusada: não gasta; igual ou mais forte renova)
static func weaker(e: SimEntity, b: Dictionary) -> bool:
	if not is_hunt_buff(b):
		return false
	for x in e.buffs:
		if x.get("id") == b.get("id"):
			for k in STAT_OF.values():
				if float(b.get(k, 0.0)) < float(x.get(k, 0.0)):
					return true
	return false

## Buff de caça (fica na morte e vai no save)?
static func is_hunt_buff(b: Dictionary) -> bool:
	return bool(b.get("keep_death", false))

## Save: o que sobra de cada buff de caça (o relógio só anda com o jogo aberto).
static func to_save(e: SimEntity) -> Array:
	var out: Array = []
	for b in e.buffs:
		if is_hunt_buff(b) and float(b.get("remaining", 0.0)) > 0.0:
			out.append((b as Dictionary).duplicate())
	return out

## Load: devolve os buffs de caça do save (campo ausente/estranho = nada). Só ids conhecidos, tempo até a duração cheia.
static func from_save(e: SimEntity, d: Dictionary) -> void:
	var arr = d.get("hunt_buffs")
	if not (arr is Array):
		return
	var known: Array = BUFF_IDS.values()
	for b in arr:
		if not (b is Dictionary) or not (str(b.get("id", "")) in known):
			continue
		var nb: Dictionary = {"id": str(b["id"]), "duration": Balance.HUNT_POTION_TIME, "keep_death": true,
			"remaining": clampf(float(b.get("remaining", 0.0)), 0.0, Balance.HUNT_POTION_TIME)}
		for k in STAT_OF.values():
			if b.has(k):
				nb[k] = float(b[k])
		if float(nb["remaining"]) > 0.0:
			e.put_buff(nb)
	e.recompute_stats()

## Maior grau que `e` consegue fazer pelo nível (-1 = nenhum).
static func grade_for(level: int) -> int:
	var best := -1
	for gi in range(Balance.HUNT_POTION_GRADES.size()):
		if level >= int(Balance.HUNT_POTION_GRADES[gi][0]):
			best = gi
	return best

## Bot chegando na caça (BotBrain, S.TRAVEL -> S.HUNT): às vezes "fez" e toma uma (paga o ouro da receita, sem material)
## e conta no chat. Sem poção de caça ativa do mesmo tipo. Devolve o id do item tomado ("" = nada).
static func bot_drink(sim: WorldSim, e: SimEntity, rng: RandomNumberGenerator) -> String:
	if not bots_drink or rng.randf() >= Balance.BOT_HUNT_POTION_CHANCE:
		return ""
	var gi := grade_for(e.level)
	if gi < 0:
		return ""
	var kind: String = KINDS[rng.randi() % KINDS.size()]
	for b in e.buffs:
		if b.get("id") == BUFF_IDS[kind]:
			return ""
	var cost := int(Balance.HUNT_POTION_GRADES[gi][1])
	if e.gold < cost:
		return ""
	e.gold -= cost
	var iid := item_id(kind, gi)
	sim._apply_effects(e, e, {"buff": (GameData.items[iid] as ItemDef).consume["buff"]}, 1.0)
	if not BotChat.in_player_party(sim, e):
		var lines: Array = BotsCatalog.HUNT_POTION_LINES[kind]
		var line: String = str(lines[rng.randi() % lines.size()]).replace("{pocao}", (GameData.items[iid] as ItemDef).name)
		Events.post(&"chat_message", e.name, line, "global")
	return iid
