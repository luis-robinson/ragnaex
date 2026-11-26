extends Node
## Sonda de farm (só mede, não julga): bots caçando sozinhos num mapa de campo por alguns minutos de sim, com os spawners
## de verdade. Serve para ajustar quantidade/raio/respawn das matilhas de uma área de farm (ex.: Praia dos Caranguejos).
##   godot --headless --path . tools/tests/farm_probe.tscn -- [--map=field_crab_beach] [--bots=1] [--level=5] [--minutes=6] [--class=<id>,...]
## FARM <mapa> bots=N nv=L min=M: abates/min por bot (só abates NESTE mapa, por minuto de bot dentro dele), por tipo, mortes
##   dos bots (em qualquer mapa), XP/min por bot (tempo todo, qualquer mapa), fora_do_mapa = % do tempo em que o bot saiu;
## PACKS: por matilha, % médio de bichos vivos (100% = o respawn ganha do farm; perto de 0% = praia seca), vezes que zerou e o
##   tempo médio para limpar (do 1º abate dela até zerar); ROTA: m andados por bot por minuto (anda muito = bicho longe demais).
## Os números dependem da IA dos bots (param para descansar, voltam para vender): compare mapas/ajustes entre si.

const DT := 1.0 / 20.0

func _ready() -> void:
	await get_tree().process_frame
	HuntPotionSystem.bots_drink = false        # calibragem sem Poção de Caça (design/gdd/pocoes-de-caca.md §3.5)
	var map_id := "field_crab_beach"
	var n_bots := 1
	var level := 5
	var minutes := 6.0
	var classes: Array = ["paladin", "berserker", "ranger", "elementalist", "assassin", "bishop", "druid", "necromancer"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="): map_id = a.get_slice("=", 1)
		if a.begins_with("--bots="): n_bots = int(a.get_slice("=", 1))
		if a.begins_with("--level="): level = int(a.get_slice("=", 1))
		if a.begins_with("--minutes="): minutes = float(a.get_slice("=", 1))
		if a.begins_with("--class="): classes = Array(a.get_slice("=", 1).split(","))
	if not GameData.maps.has(map_id):
		print("FARM mapa desconhecido: %s (NAO MEDIDO)" % map_id)
		get_tree().quit()
		return
	var md: MapDef = GameData.maps[map_id]
	Sim.load_map(GameData.maps[GameData.town_map_id()])
	var m: Dictionary = Sim.load_map(md)
	for i in range(200):                       # enche os spawners antes de soltar os bots
		Sim.tick(DT)
	var bots: Array = []
	for i in range(n_bots):
		var cid: String = classes[i % classes.size()]
		if not GameData.classes.has(cid):
			print("FARM classe desconhecida: %s (NAO MEDIDO)" % cid)
			get_tree().quit()
			return
		var b: SimEntity = Sim.spawn_bot(GameData.classes[cid], "Farm%d" % i, map_id, Sim.random_walkable(md, md.spawn_point, 3.0), level)
		b.brain.state = BotBrain.S.HUNT
		b.brain.timer = 99999.0             # caça o tempo todo (só sai com a bolsa cheia ou a vida baixa)
		bots.append(b)
	var ids := {}
	for b in bots:
		ids[b.id] = true
	var kills := {}
	var deaths := [0]
	var owner_of := {}                         # id do monstro -> índice do spawner (para o tempo de limpar)
	Events.entity_died.connect(func(eid: int, killer: int) -> void:
		if ids.has(eid):
			deaths[0] += 1
			return
		var e: SimEntity = Sim.entities.get(eid)
		if e == null or e.kind != SimEntity.Kind.MONSTER or e.monster_def == null or e.map_id != map_id:      # só o que morre NESTE mapa
			return
		var k: SimEntity = Sim.entities.get(killer)
		if k != null and (ids.has(k.id) or ids.has(k.owner_id)):
			kills[e.monster_def.id] = int(kills.get(e.monster_def.id, 0)) + 1)
	var sps: Array = m["spawners"]
	var alive_sum: Array = []
	var wipes: Array = []
	var first_kill: Array = []
	var clear_sum: Array = []
	var last_alive: Array = []
	for sp in sps:
		alive_sum.append(0.0)
		wipes.append(0)
		first_kill.append(-1.0)
		clear_sum.append(0.0)
		last_alive.append(int(sp["alive"].size()))
	var walked := 0.0
	var last_pos: Array = bots.map(func(b): return b.position)
	var xp0: Array = bots.map(func(b): return _xp_total(b))
	var away := 0.0                             # s de bot fora do mapa (voltou para vender / morreu e renasceu longe)
	var t := 0.0
	var samples := 0
	var total := minutes * 60.0
	while t < total:
		Sim.tick(DT)
		t += DT
		for i in range(bots.size()):
			var b: SimEntity = bots[i]
			if b.map_id != map_id:
				away += DT
				last_pos[i] = b.position
				continue
			var step: float = b.position.distance_to(last_pos[i])
			if step < 3.0:                       # teleporte (renascer, portal) não é caminhada
				walked += step
			last_pos[i] = b.position
		for i in range(sps.size()):
			var n: int = sps[i]["alive"].size()
			var cap: int = int(sps[i]["def"].get("count", 1)) if sps[i].has("def") else maxi(1, last_alive[i])
			if n < last_alive[i] and first_kill[i] < 0.0:
				first_kill[i] = t
			if n == 0 and last_alive[i] > 0:
				wipes[i] += 1
				if first_kill[i] >= 0.0:
					clear_sum[i] += t - first_kill[i]
			if n >= cap:
				first_kill[i] = -1.0
			last_alive[i] = n
		if int(t / DT) % 20 == 0:
			samples += 1
			for i in range(sps.size()):
				var cap2: int = maxi(1, int(_sp_def(sps[i]).get("count", 1)))
				alive_sum[i] += float(sps[i]["alive"].size()) / cap2
	var all_kills := 0
	for k in kills:
		all_kills += int(kills[k])
	var xp := 0.0
	for i in range(bots.size()):
		xp += _xp_total(bots[i]) - float(xp0[i])
	# o bot solto sai do mapa (vende, viaja): abates e caminhada valem por minuto DENTRO do mapa; XP é do tempo todo
	var per := float(maxi(1, n_bots)) * minutes
	var here: float = maxf(0.05, (total * n_bots - away) / 60.0)
	print("FARM %s bots=%d nv=%d min=%.0f abates/min/bot=%.1f por_tipo=%s mortes=%d xp/min/bot=%.0f fora_do_mapa=%.0f%%" % [map_id, n_bots, level, minutes,
		all_kills / here, str(kills), deaths[0], xp / per, 100.0 * away / maxf(1.0, total * n_bots)])
	print("ROTA m/min/bot=%.0f (min de bot no mapa: %.1f)" % [walked / here, here])
	for i in range(sps.size()):
		var d: Dictionary = _sp_def(sps[i])
		print("PACKS %-12s (%.0f, %.0f) x%d vivos_medio=%.0f%% zerou=%d limpar=%s" % [str(d.get("monster_id", "?")), d["pos"].x, d["pos"].z, int(d.get("count", 1)),
			100.0 * alive_sum[i] / maxf(1, samples), wipes[i], ("%.0fs" % (clear_sum[i] / wipes[i])) if wipes[i] > 0 else "-"])
	get_tree().quit()

## Definição do spawner (posição, quantos): no estado da sim ela fica em "def"; se o formato mudar, cai no próprio dicionário.
func _sp_def(sp: Dictionary) -> Dictionary:
	return sp["def"] if sp.has("def") else sp

## XP acumulada do bot (nível + barra): soma simples para comparar antes/depois.
func _xp_total(b: SimEntity) -> float:
	var s := 0.0
	for lv in range(1, b.level):
		s += float(Balance.xp_for_level(lv))
	return s + float(b.xp)
