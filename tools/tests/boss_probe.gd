extends Node
## Luta de bots contra chefes (calibrar números): para cada chefe, N lutas com um grupo de bots do nível do chefe.
##   godot --headless --path . tools/tests/boss_probe.tscn -- [--party=1,3] [--trials=12] [--boss=slime_king,...]
##     [--class=berserker] [--build=carniceiro]   (grupo só dessa classe/build; sem isso as classes se revezam)
##     [--lead=paladin:guardiao]   (o 1º do grupo é dessa classe/build, os outros se revezam; imprime aggro=% do tempo em que
##                                  o chefe mirou nele: tanque segurando o chefe no grupo)
##     [--kite[=ranger:cacador]]   (luta solo de um atirador que fica a 9,5 m+ do chefe: o chefe tem resposta de longe?)
##     [--comp=paladin:guardiao,bishop:sacerdote,...]   (grupo fixo, um classe:build por membro; o 1º é o líder; as métricas de
##                                  grupo contam como tanque o 1º com papel "tank" — líder dps = o jogador liderando, tanque bot seguindo)
##     [--bands]                   (solo + trio + kite por chefe e compara com BANDS; imprime BAND/OUT e OUT_OF_BAND no fim)
## Saída: "PROBE <chefe> grupo=N vitorias=V/T tempo_medio=Ss mortes=M cast/min=C act=A% adds=N off=O% longe/min=F"
##   cast/min = skills do chefe por minuto; act = parte da luta golpeando/lançando (o resto é andando);
##   adds = lacaios por luta; off = dano do chefe e dos lacaios fora do alvo do chefe; longe/min = skills do chefe miradas
##   a 9 m+ dele (gancho, investida, chuva, tiro; o bot pode desviar: mede a pressão em quem luta de longe).
##   Com --lead/--comp, métricas de grupo: area = parte do dano do chefe que dava para desviar (golpe de área, círculo,
##   poça, projétil no ar); cura_tq = parte da cura do grupo que foi no líder (tanque); baixa = s por luta em que alguém
##   que não é o líder ficou abaixo de 35% de vida; frente = parte do dano que veio de golpe do chefe SEM mira de
##   propósito (mob_pick vazio) em quem não é o líder: quem estava no lugar errado (a IA de grupo tenta zerar);
##   ritmo = parte da luta em que os outros membros estavam golpeando/lançando (o resto é andando ou parado).

const BOSSES := {"bandit_chief": "field_forest", "crab_king": "city_aldara", "slime_king": "dg_gruta", "spider_queen": "dg_ninho", "crypt_lord": "dg_cripta",
	"bone_captain": "dg_catacumbas", "wailing_widow": "dg_catacumbas", "count_vargo": "dg_catacumbas_trono",
	"boar_brute": "city_aldara", "boar_king": "city_aldara", "elf_king": "dg_coracao", "elf_warden": "elf_city", "trent": "elf_city",
	"golem_ancient": "dg_pedreira", "crystal_warden": "dg_pedreira", "quarry_heart": "dg_pedreira_coracao",
	"elf_captain_hunter": "elf_city", "elf_captain_sky": "elf_city", "elf_captain_sap": "elf_city",
	"ghoul_giant": "fort_ghoul", "death_knight": "fort_bones", "frost_mage": "fort_frost", "lich_king": "lich_citadel",
	"dragonling": "field_ruins"}
## field = chefe de campo (dá para solar); elite = monstro forte de missão (sem fases); group = conteúdo de grupo.
const GROUPS := {"crab_king": "field", "boar_brute": "field", "boar_king": "field", "slime_king": "field",
	"trent": "elite", "elf_warden": "elite"}          # o resto: group
## Faixas que o chefe precisa cumprir (`--bands`). win = fração de vitórias; time = s de luta do trio; o resto são pisos.
## kite_far: skills miradas a 9 m+ por minuto contra um atirador que kita; passa também se o atirador perde a maioria.
const BANDS := {
	"field": {"solo_win": [0.6, 1.0], "trio_win": [0.9, 1.0], "kite_far": 0.0},     # chefe inicial: kitar é tática válida
	"elite": {"solo_win": [0.6, 1.0], "trio_win": [0.9, 1.0], "kite_far": 2.0},
	"group": {"solo_win": [0.2, 0.4], "trio_win": [0.75, 1.0], "trio_time": [30.0, 150.0], "casts": 4.0, "act": 35.0, "adds": 4.0, "off": 10.0, "kite_far": 2.0},
}
const LIMIT := 300.0          # s por luta
const DT := 1.0 / 20.0
const KITE_MIN := 9.5
var _force_class := ""
var _force_build := ""
var _lead := ""
var _kite := ""
var _why := false
var _comp: Array = []

## Bot da sonda: veio pelo chefe. Não planeja viagem de caça nem volta à cidade no meio da luta (a sala do chefe não é mapa de caça, e o
## líder levava o grupo embora: contava como derrota).
class StayBrain extends BotBrain:
	var boss_id := -1
	## Chefe sem alvo (resetou) e o bot longe, sem nada para caçar: volta até o chefe (antes ficavam a 30 m, fora do aggro, até o fim).
	func think(e: SimEntity, sim, m: Dictionary, dt: float) -> InputCommand:
		var cmd: InputCommand = super.think(e, sim, m, dt)
		var b: SimEntity = sim.entities.get(boss_id)
		if b and b.is_alive() and b.aggro_target < 0 and hunt_target_id < 0 and e.can_act():
			var to := b.position - e.position
			to.y = 0.0
			if to.length() > 8.0:
				cmd.move = Vector2(to.x, to.z).normalized()
		return cmd
	func _plan_trip(_e: SimEntity, _sim) -> void:
		state = S.HUNT
		timer = 5.0
	func _go_home() -> void:               # nem volta à cidade para reabastecer com o chefe vivo
		state = S.HUNT
		timer = 5.0

## Atirador que não deixa o chefe chegar perto: pensa como bot e, com o chefe a menos de KITE_MIN, anda para longe.
class KiteBrain extends StayBrain:
	func think(e: SimEntity, sim, m: Dictionary, dt: float) -> InputCommand:
		var cmd: InputCommand = super.think(e, sim, m, dt)
		var b: SimEntity = sim.entities.get(boss_id)
		if b and b.is_alive() and e.can_act():
			var away := e.position - b.position
			away.y = 0.0
			if away.length() < KITE_MIN and away.length() > 0.01:
				cmd.move = Vector2(away.x, away.z).normalized()
		return cmd

func _ready() -> void:
	await get_tree().process_frame
	Sim.load_map(GameData.maps[GameData.town_map_id()])      # bot que morre renasce na cidade
	var parties := [1, 3]
	var trials := 12
	var only: Array = []
	var bands := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--party="): parties = Array(a.get_slice("=", 1).split(",")).map(func(x): return int(x))
		if a.begins_with("--trials="): trials = int(a.get_slice("=", 1))
		if a.begins_with("--boss="): only = Array(a.get_slice("=", 1).split(","))
		if a.begins_with("--class="): _force_class = a.get_slice("=", 1)
		if a.begins_with("--build="): _force_build = a.get_slice("=", 1)
		if a.begins_with("--lead="): _lead = a.get_slice("=", 1)
		if a == "--kite": _kite = "ranger:cacador"
		if a.begins_with("--kite="): _kite = a.get_slice("=", 1)
		if a == "--bands": bands = true
		if a.begins_with("--comp="): _comp = Array(a.get_slice("=", 1).split(","))
		if a == "--why": _why = true          # imprime de onde veio o dano que o grupo levou
	var out_of_band: Array = []
	for bid in BOSSES:
		if not (only.is_empty() or bid in only):
			continue
		if bands:
			var why := _band(bid, trials)
			if why.is_empty():
				print("BAND %-18s %s OK" % [bid, GROUPS.get(bid, "group")])
			else:
				print("OUT  %-18s %s %s" % [bid, GROUPS.get(bid, "group"), " ".join(why)])
				out_of_band.append(bid)
			continue
		for n in parties:
			var r := _run(bid, BOSSES[bid], n, trials, _kite)
			_print(bid, n, trials, r)
	if bands:
		print("OUT_OF_BAND: %s" % ",".join(out_of_band))
	print("PROBE_END")
	get_tree().quit()

func _print(bid: String, n: int, trials: int, r: Dictionary) -> void:
	print("PROBE %-18s grupo=%d%s vitorias=%d/%d tempo_medio=%.0fs mortes=%.1f cast/min=%.1f act=%.0f%% adds=%.1f off=%.0f%% longe/min=%.1f%s" % [
		bid, n, (" kite" if r["kite"] else ""), r["wins"], trials, r["time"], r["deaths"], r["casts"], r["act"], r["adds"], r["off"], r["far"],
		("" if _lead == "" and _comp.is_empty() else " aggro=%.0f%% area=%.0f%% cura_tq=%.0f%% baixa=%.1fs frente=%.0f%% ritmo=%.0f%%" % [r["aggro"], r["area"], r["heal_tank"], r["low"], r["stray"], r["busy"]])])

## Solo, trio e kite contra as faixas do grupo do chefe. Devolve os motivos de estar fora (vazio = dentro).
func _band(bid: String, trials: int) -> Array:
	var b: Dictionary = BANDS[GROUPS.get(bid, "group")]
	var solo := _run(bid, BOSSES[bid], 1, trials, "")
	var trio := _run(bid, BOSSES[bid], 3, trials, "")
	var kite := _run(bid, BOSSES[bid], 1, maxi(4, trials / 3), "ranger:cacador")
	_print(bid, 1, trials, solo)
	_print(bid, 3, trials, trio)
	_print(bid, 1, maxi(4, trials / 3), kite)
	var why: Array = []
	var sw := float(solo["wins"]) / trials
	var tw := float(trio["wins"]) / trials
	if sw < b["solo_win"][0] or sw > b["solo_win"][1]:
		why.append("solo=%.0f%%(%.0f-%.0f)" % [sw * 100, b["solo_win"][0] * 100, b["solo_win"][1] * 100])
	if tw < b["trio_win"][0] or tw > b["trio_win"][1]:
		why.append("trio=%.0f%%(%.0f-%.0f)" % [tw * 100, b["trio_win"][0] * 100, b["trio_win"][1] * 100])
	if b.has("trio_time") and trio["wins"] > 0 and (trio["time"] < b["trio_time"][0] or trio["time"] > b["trio_time"][1]):
		why.append("tempo=%.0fs(%.0f-%.0f)" % [trio["time"], b["trio_time"][0], b["trio_time"][1]])
	for k in ["casts", "act", "adds", "off"]:
		if b.has(k) and trio[k] < float(b[k]):
			why.append("%s=%.1f(>=%s)" % [k, trio[k], b[k]])
	# ou o chefe mata quem kita, ou a luta é curta demais para medir (elite de 3 mil de vida cai em 8 s)
	if kite["far"] < float(b["kite_far"]) and float(kite["wins"]) / maxi(4, trials / 3) > 0.5 and kite["time"] >= 15.0:
		why.append("longe=%.1f(>=%s)" % [kite["far"], b["kite_far"]])
	return why

func _run(bid: String, mid: String, party: int, trials: int, kite: String) -> Dictionary:
	var base: MonsterDef = GameData.monsters[bid]
	var m: Dictionary = Sim.load_map(GameData.maps[mid])
	m["spawners"].clear()
	for ri in RaidSystem.routes(m["def"]).size():
		RaidSystem.state(m, ri)["timer"] = INF       # investidas paradas (Bastião): os bots largavam o chefe para defender o portão
	var at := Vector3.ZERO
	for sp in m["def"].spawners:
		if sp["monster_id"] == bid:
			at = sp["pos"]
	var wins := 0
	var t_sum := 0.0
	var deaths := 0
	var agg_sum := 0.0
	var fight_sum := 0.0
	var act_sum := 0.0
	var adds_sum := 0
	var low_sum := 0.0
	var busy_sum := 0.0
	var acc := {"stray": 0.0, "area": 0.0, "heal": 0.0, "heal_tank": 0.0, "lead": -1, "casts": 0, "dmg": 0.0, "off": 0.0, "far": 0, "boss": -1, "bots": {}, "from": Vector3.ZERO, "why": {}, "why_t": {}, "states": {}}
	var on_cast := func(id: int, sid: String, ph: String):
		if id == acc["boss"] and ph == "startup":
			acc["from"] = Sim.entities[id].position if Sim.entities.has(id) else Vector3.ZERO     # de onde o golpe saiu
			if sid.begins_with("mob_"):
				acc["casts"] += 1
				var b: SimEntity = Sim.entities.get(id)
				var sk: SkillDef = GameData.skills.get(sid)
				if b and sk and sk.target != SkillDef.Target.SELF and Vector2(b.skill_aim.x - b.position.x, b.skill_aim.z - b.position.z).length() >= 9.0:
					acc["far"] += 1          # golpe mirado em quem está a 9 m+ (o bot pode desviar; conta a pressão)
	var on_dmg := func(src: int, tid: int, amount: int, _c: bool, _b: bool, _k: String):
		if not acc["bots"].has(tid):
			return
		var a: SimEntity = Sim.entities.get(src)
		var b: SimEntity = Sim.entities.get(acc["boss"])
		if a == null or b == null or not (a == b or a.boss_id == b.id):
			return
		acc["dmg"] += amount
		if not _k.begins_with("dot"):
			var sk: SkillDef = b.current_skill if a == b and b.state == SimEntity.State.CASTING else null
			if (a == b and sk == null) or (sk and sk.target != SkillDef.Target.TARGET and sk.radius >= Balance.BOT_DODGE_MIN_RADIUS):
				acc["area"] += amount          # círculo/poça/projétil no ar (chefe sem golpe em andamento) ou golpe de área
			if sk and sk.mob_pick == "" and tid != acc["lead"]:
				acc["stray"] += amount         # golpe do chefe sem mira de propósito pegando quem não é o tanque (posição)
		if _why:                     # de onde veio o dano no grupo (--why)
			var key := "lacaio:%s" % a.monster_def.id if a != b else ("golpe:%s" % b.current_skill.id if b.state == SimEntity.State.CASTING and b.current_skill else "chuva/outro")
			if not _comp.is_empty():
				key += ">%s" % ("tanque" if tid == acc["lead"] else str(Sim.role_of(Sim.entities[tid])) if Sim.entities.has(tid) else "?")
			acc["why"][key] = float(acc["why"].get(key, 0.0)) + amount
			acc["why_t"][key] = float(acc["why_t"].get(key, 0.0)) + amount
		if tid != b.aggro_target:
			acc["off"] += amount
		var t: SimEntity = Sim.entities.get(tid)
	var on_heal := func(_src: int, tid: int, amount: int):
		if acc["bots"].has(tid):
			acc["heal"] += amount
			if tid == acc["lead"]:
				acc["heal_tank"] += amount
	Events.skill_cast.connect(on_cast)
	Events.damage_dealt.connect(on_dmg)
	Events.healed.connect(on_heal)
	var classes: Array = GameData.classes.keys()
	for trial in range(trials):
		for e in m["entities"].duplicate():
			Sim.despawn(e)
		m["hazards"] = []
		var boss = Sim.spawn_monster(base, mid, at)
		acc["boss"] = boss.id
		if not base.escort.is_empty():
			MobSystem.spawn_escort(Sim, boss, {})          # capitão luta com a escolta, como no forte
		var bots: Array = []
		acc["bots"] = {}
		for i in range(party):
			var cid: String = _force_class if _force_class != "" else classes[(trial * 3 + i * 5) % classes.size()]
			var want_build := _force_build
			if i < _comp.size():
				cid = str(_comp[i]).get_slice(":", 0)
				want_build = str(_comp[i]).get_slice(":", 1)
			if kite != "" and i == 0:
				cid = kite.get_slice(":", 0)
				want_build = kite.get_slice(":", 1)
			elif not _comp.is_empty():
				pass
			elif _lead != "" and i == 0:
				cid = _lead.get_slice(":", 0)
				want_build = _lead.get_slice(":", 1)
			elif _lead != "" and _comp.is_empty():
				while cid == _lead.get_slice(":", 0):
					cid = classes[(classes.find(cid) + 1) % classes.size()]
			var bot = Sim.spawn_bot(GameData.classes[cid], "P%d" % i, mid, at + Vector3(3 + i, 0, 3), base.level)
			if want_build != "" and bot.build_id != want_build:
				bot.build_id = want_build          # mesma build para todos: equipamento e skills dela
				Sim._gear_bot(bot)
				Sim._skill_bot(bot)
			if kite != "" and i == 0:
				var kb := KiteBrain.new()
				kb.setup(bot, Sim.rng)
				kb.boss_id = boss.id
				kb.personality = 1.0
				bot.brain = kb
				bot.position = at + Vector3(KITE_MIN + 1.0, 0, 0)
			if not (kite != "" and i == 0):
				var sb := StayBrain.new()
				sb.setup(bot, Sim.rng)
				sb.boss_id = boss.id
				bot.brain = sb
			bot.brain.personality = 1.0          # veio pelo chefe: encara (o bot cauteloso ignora chefe)
			if _why and i == 0 and trial == 0:
				var st: Stats = bot.stats
				print("      LIDER %s/%s arma=%s+%s lv=%d hp=%d pdef=%d mdef=%d patk=%d matk=%d esq=%.0f%% skills=%s" % [cid, bot.build_id, st.weapon_type, st.offhand_type, bot.level, st.max_hp, st.pdef, st.mdef, st.patk, st.matk, st.evasion,
					",".join(bot.skills.filter(func(s): return s != null).map(func(s): return s.id))])
			bots.append(bot)
			acc["bots"][bot.id] = true
		for i in range(1, party):
			Sim.party_invite(bots[0], bots[i])
			Sim.party_accept(bots[i])
		var tank_bot: SimEntity = bots[0]          # tanque das métricas: o 1º com papel "tank" (o líder, se não houver)
		for b in bots:
			if Sim.role_of(b) == "tank":
				tank_bot = b
				break
		acc["lead"] = tank_bot.id
		boss.aggro_target = bots[0].id
		boss.aggro_timer = 5.0
		var t := 0.0
		var dead := {}
		var on_lead := 0.0
		var targeted := 0.0
		var acting := 0.0
		var adds := {}
		while t < LIMIT and boss.is_alive():
			Sim.tick(DT)
			t += DT
			if boss.state == SimEntity.State.ATTACKING or boss.state == SimEntity.State.CASTING:
				acting += DT
			if _why:
				var sk: String = SimEntity.State.keys()[boss.state]
				acc["states"][sk] = float(acc["states"].get(sk, 0.0)) + DT
			if boss.aggro_target >= 0:
				targeted += DT
				if boss.aggro_target == tank_bot.id:
					on_lead += DT
			for o in m["entities"]:
				if o.boss_id == boss.id:
					adds[o.id] = true
			for bi in range(bots.size()):
				if bots[bi] == tank_bot:
					continue
				if bots[bi].is_alive() and bots[bi].hp < bots[bi].stats.max_hp * 0.35:
					low_sum += DT
				if bots[bi].state == SimEntity.State.ATTACKING or bots[bi].state == SimEntity.State.CASTING:
					busy_sum += DT / maxf(1.0, bots.size() - 1)
			for b in bots:
				if _why and b.map_id == mid and b.brain is BotBrain:
					b.set_meta("probe_state", "%s t=%.0f hp=%.0f%% alvo=%d dest=%s forma=%s (teve: %s)" % [BotBrain.S.keys()[b.brain.state], t, 100.0 * b.hp / b.stats.max_hp, b.brain.target_id if "target_id" in b.brain else -1, b.brain.dest_map, b.form, b.get_meta("had_form", "nenhuma")])
				if _why and b.form != "":
					b.set_meta("had_form", b.form)
				if not b.is_alive() or b.map_id != mid:
					if _why and not dead.has(b.id) and b.has_meta("probe_state"):
						print("      saiu/morreu %s: antes = %s" % [b.class_def.id, b.get_meta("probe_state")])
					dead[b.id] = true
			if dead.size() == party:
				break
		deaths += dead.size()
		if _why:
			print("TRIAL %s #%d %s t=%.0fs hp_chefe=%.0f%% caidos=%s grupo=%s" % [bid, trial, ("WIN" if not boss.is_alive() else "LOSS"), t, 100.0 * maxf(0.0, boss.hp) / boss.stats.max_hp,
				",".join(bots.filter(func(b): return dead.has(b.id)).map(func(b): return "%s/%s:%s" % [b.class_def.id, b.build_id, ("morto" if not b.is_alive() else "saiu->" + b.map_id)])), ",".join(bots.map(func(b): return "%s/%s" % [b.class_def.id, b.build_id]))])
			if boss.is_alive() and boss.hp >= boss.stats.max_hp:          # luta que nem começou: onde estava cada um
				print("      chefe %s em %s alvo=%d" % [SimEntity.State.keys()[boss.state], boss.position.snapped(Vector3.ONE), boss.aggro_target])
				for b in bots:
					print("      %s/%s em %s d=%.1f %s" % [b.class_def.id, b.build_id, b.position.snapped(Vector3.ONE), b.position.distance_to(boss.position), b.get_meta("probe_state", "")])
			var wt: Dictionary = acc["why_t"]
			var ks: Array = wt.keys()
			ks.sort_custom(func(x, y): return wt[x] > wt[y])
			print("      dano: %s" % ", ".join(ks.slice(0, 5).map(func(k): return "%s=%.0f" % [k, wt[k]])))
		acc["why_t"] = {}
		agg_sum += on_lead / maxf(0.01, targeted)
		fight_sum += t
		act_sum += acting
		adds_sum += adds.size()
		if not boss.is_alive():
			wins += 1
			t_sum += t
		for b in bots:
			Sim.despawn(b)
	if _why:
		var keys: Array = acc["why"].keys()
		keys.sort_custom(func(x, y): return acc["why"][x] > acc["why"][y])
		var st: Dictionary = acc["states"]
		print("STATES %s grupo=%d %s" % [bid, party, ", ".join(st.keys().map(func(k): return "%s=%.0f%%" % [k, 100.0 * st[k] / maxf(0.01, fight_sum)]))])
		print("WHY %s grupo=%d %s" % [bid, party, ", ".join(keys.slice(0, 8).map(func(k): return "%s=%.0f%%" % [k, 100.0 * acc["why"][k] / maxf(1.0, acc["dmg"])]))])
	Events.skill_cast.disconnect(on_cast)
	Events.damage_dealt.disconnect(on_dmg)
	Events.healed.disconnect(on_heal)
	var mins := maxf(0.01, fight_sum / 60.0)
	return {"wins": wins, "time": t_sum / maxf(1, wins), "deaths": float(deaths) / trials, "aggro": 100.0 * agg_sum / trials,
		"casts": acc["casts"] / mins, "act": 100.0 * act_sum / maxf(0.01, fight_sum), "adds": float(adds_sum) / trials,
		"off": 100.0 * acc["off"] / maxf(1.0, acc["dmg"]), "far": acc["far"] / mins, "kite": kite != "",
		"area": 100.0 * acc["area"] / maxf(1.0, acc["dmg"]), "heal_tank": 100.0 * acc["heal_tank"] / maxf(1.0, acc["heal"]), "low": low_sum / trials,
		"stray": 100.0 * acc["stray"] / maxf(1.0, acc["dmg"]), "busy": 100.0 * busy_sum / maxf(0.01, fight_sum)}
