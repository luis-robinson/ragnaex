class_name BotBandSystem
## Faixa de nível dos bots (playtest 2026-11-18: bots lv 40 em Aldara). Cada povoado com cristal (`MapsCatalog.CRYSTALS`)
## é a "casa" de uma faixa: o bot volta (G, renascer, vender) para o da faixa dele, não para a cidade inicial.
## Bot no grupo do jogador usa a casa do jogador (segue para onde ele for). Sem estado: funções estáticas.

## Níveis de quem nasce no mapa `def`: a faixa do mapa até BOT_BAND_SLACK acima do teto.
static func spawn_levels(def: MapDef) -> Vector2i:
	return Vector2i(def.level_range.x, mini(def.level_range.y + Balance.BOT_BAND_SLACK, Balance.MAX_LEVEL))      # nunca acima do teto (Cortejo 47-49: até 50)

## Povoado-casa da faixa de `level`: o de maior piso com piso + BOT_HOME_STEP_UP <= nível (Aldara abaixo disso).
## Com `sim`: cristal de estágio (`MapsCatalog.CRYSTAL_IF`) só conta depois da quest (Posto do Cortejo, Fenda).
static func home_map(level: int, sim: WorldSim = null) -> String:
	var best := GameData.town_map_id()
	var best_x := -1
	for mid in MapsCatalog.CRYSTALS:
		var def: MapDef = GameData.maps.get(mid)
		if def == null:
			continue
		if sim != null and MapsCatalog.CRYSTAL_IF.has(mid) and not WorldState.active(sim, {"if": MapsCatalog.CRYSTAL_IF[mid]}):
			continue
		var x := def.level_range.x
		if (mid == best or level >= x + Balance.BOT_HOME_STEP_UP) and x > best_x:
			best = mid
			best_x = x
	return best

## Ponto de retorno do bot sem cristal vinculado: frente do cristal do povoado da faixa.
static func home_of_bot(e: SimEntity, sim: WorldSim = null) -> Dictionary:
	var mid := home_map(e.level, sim)
	var def: MapDef = GameData.maps[mid]
	if mid == GameData.town_map_id() or not MapsCatalog.CRYSTALS.has(mid):     # cidade inicial: a entrada, como o jogador sem cristal
		return {"map": mid, "pos": def.spawn_point}
	var c: Array = MapsCatalog.CRYSTALS[mid]
	var crystal := Vector3(float(c[0]), 0.0, float(c[1]))
	var to_center := def.town_center - crystal
	to_center.y = 0.0
	var dir := to_center.normalized() if to_center.length() > 0.5 else Vector3(0, 0, 1)
	return {"map": mid, "pos": crystal + dir * Balance.CRYSTAL_ARRIVE}

## Mapa de lazer do bot está muito abaixo da faixa dele (não fica à toa lá: volta a caçar na faixa)?
static func below_band(e: SimEntity, def: MapDef) -> bool:
	return e.level > def.level_range.y + Balance.BOT_BAND_SLACK

## Pontos onde os bots da cidade nascem: todos os pontos de encontro fora da praça e no máximo BOT_SQUARE_CAP dentro
## (sem pontos de encontro: o centro).
static func spawn_spots(def: MapDef) -> Array:
	var out: Array = []
	var inside := 0
	for h: Vector3 in def.bot_hangouts:
		if h.distance_to(def.town_center) >= Balance.BOT_SQUARE_RADIUS:
			out.append(h)
		elif inside < Balance.BOT_SQUARE_CAP:
			out.append(h)
			inside += 1
	if out.is_empty():
		out.append(def.town_center)
	return out

## Ponto do i-ésimo bot da cidade: uma volta por todos os `spawn_spots`; daí em diante só os de fora da praça.
static func spawn_spot(def: MapDef, i: int) -> Vector3:
	var spots := spawn_spots(def)
	if i < spots.size():
		return spots[i]
	var out: Array = spots.filter(func(h): return (h as Vector3).distance_to(def.town_center) >= Balance.BOT_SQUARE_RADIUS)
	return spots[i % spots.size()] if out.is_empty() else out[i % out.size()]
