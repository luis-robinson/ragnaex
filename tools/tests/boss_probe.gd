extends Node
## Luta de bots contra chefes (calibrar números): para cada chefe, N lutas com um grupo de bots do nível do chefe.
##   godot --headless --path . tools/tests/boss_probe.tscn -- [--party=1,3] [--trials=12] [--boss=slime_king,...]
##     [--class=berserker] [--build=carniceiro]   (grupo só dessa classe/build; sem isso as classes se revezam)
## Saída: "PROBE <chefe> grupo=N vitorias=V/T tempo_medio=Ss mortes=M" (mortes = bots mortos por luta, média).

const BOSSES := {"bandit_chief": "field_forest", "crab_king": "city_aldara", "slime_king": "dg_gruta", "spider_queen": "dg_ninho", "crypt_lord": "dg_cripta",
	"bone_captain": "dg_catacumbas", "wailing_widow": "dg_catacumbas", "count_vargo": "dg_catacumbas_trono",
	"boar_brute": "city_aldara", "boar_king": "city_aldara", "elf_king": "dg_coracao", "elf_warden": "elf_city", "trent": "elf_city"}
const LIMIT := 240.0          # s por luta
const DT := 1.0 / 20.0
var _force_class := ""
var _force_build := ""

func _ready() -> void:
	await get_tree().process_frame
	Sim.load_map(GameData.maps[GameData.town_map_id()])      # bot que morre renasce na cidade
	var parties := [1, 3]
	var trials := 12
	var only: Array = []
	var force_class := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--party="): parties = Array(a.get_slice("=", 1).split(",")).map(func(x): return int(x))
		if a.begins_with("--trials="): trials = int(a.get_slice("=", 1))
		if a.begins_with("--boss="): only = Array(a.get_slice("=", 1).split(","))
		if a.begins_with("--class="): force_class = a.get_slice("=", 1)
		if a.begins_with("--build="): _force_build = a.get_slice("=", 1)
	_force_class = force_class
	for n in parties:
		for bid in BOSSES:
			if only.is_empty() or bid in only:
				var r := _run(bid, BOSSES[bid], n, trials)
				print("PROBE %-14s grupo=%d vitorias=%d/%d tempo_medio=%.0fs mortes=%.1f" % [bid, n, r[0], trials, r[1], r[2]])
	print("PROBE_END")
	get_tree().quit()

func _run(bid: String, mid: String, party: int, trials: int) -> Array:
	var base: MonsterDef = GameData.monsters[bid]
	var m: Dictionary = Sim.load_map(GameData.maps[mid])
	m["spawners"].clear()
	var at := Vector3.ZERO
	for sp in m["def"].spawners:
		if sp["monster_id"] == bid:
			at = sp["pos"]
	var wins := 0
	var t_sum := 0.0
	var deaths := 0
	var classes: Array = GameData.classes.keys()
	for trial in range(trials):
		for e in m["entities"].duplicate():
			Sim.despawn(e)
		var boss = Sim.spawn_monster(base, mid, at)
		var bots: Array = []
		for i in range(party):
			var cid: String = _force_class if _force_class != "" else classes[(trial * 3 + i * 5) % classes.size()]
			var bot = Sim.spawn_bot(GameData.classes[cid], "P%d" % i, mid, at + Vector3(3 + i, 0, 3), base.level)
			if _force_build != "" and bot.build_id != _force_build:
				bot.build_id = _force_build          # mesma build para todos: equipamento e skills dela
				Sim._gear_bot(bot)
				Sim._skill_bot(bot)
			bots.append(bot)
		for i in range(1, party):
			Sim.party_invite(bots[0], bots[i])
			Sim.party_accept(bots[i])
		boss.aggro_target = bots[0].id
		boss.aggro_timer = 5.0
		var t := 0.0
		var dead := {}
		while t < LIMIT and boss.is_alive():
			Sim.tick(DT)
			t += DT
			for b in bots:
				if not b.is_alive() or b.map_id != mid:
					dead[b.id] = true
			if dead.size() == party:
				break
		deaths += dead.size()
		if not boss.is_alive():
			wins += 1
			t_sum += t
		for b in bots:
			Sim.despawn(b)
	return [wins, t_sum / maxf(1, wins), float(deaths) / trials]
