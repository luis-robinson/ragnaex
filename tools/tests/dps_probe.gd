extends Node
## DPS de cada build contra um boneco (calibrar o efeito-assinatura): mesmo bot, mesma luta, com e sem a assinatura
## (sem = sem o proc e com o básico de antes, sem SIGNATURE_BASIC_TRIM).
##   godot --headless --path . tools/tests/dps_probe.tscn -- [--levels=10,20,30] [--secs=30] [--trials=3] [--class=fogo,...]
## Saída: "DPS <classe>/<build> nv=N sem=X com=Y (+Z%)" e FLAG fora de -5%..+10%.

const DT := 1.0 / 20.0
const MAP := "field_forest"
const SPOT := Vector3(-90, 0, 9)

func _ready() -> void:
	await get_tree().process_frame
	var levels := [10, 20, 30]
	var secs := 30.0
	var trials := 3
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--levels="): levels = Array(a.get_slice("=", 1).split(",")).map(func(x): return int(x))
		if a.begins_with("--secs="): secs = float(a.get_slice("=", 1))
		if a.begins_with("--trials="): trials = int(a.get_slice("=", 1))
		if a.begins_with("--class="): only = Array(a.get_slice("=", 1).split(","))
	Sim.load_map(GameData.maps[GameData.town_map_id()])
	var flags := 0
	var sum_off := 0.0
	var sum_on := 0.0
	for cid in GameData.classes:
		for b in GameData.classes[cid].builds:
			var bid: String = b["id"]
			if not only.is_empty() and not (bid in only) and not (cid in only):
				continue
			for lv in levels:
				var off := 0.0
				var on := 0.0
				for t in range(trials):
					off += _fight(cid, bid, lv, secs, false, t)
					on += _fight(cid, bid, lv, secs, true, t)
				off /= trials
				on /= trials
				sum_off += off
				sum_on += on
				var d := (on / maxf(1.0, off) - 1.0) * 100.0
				var flag := d < -5.0 or d > 10.0
				flags += 1 if flag else 0
				print("DPS %-13s/%-15s nv=%2d sem=%6.1f com=%6.1f (%+.0f%%)%s" % [cid, bid, lv, off, on, d, "  FLAG" if flag else ""])
	print("DPS_END total=%+.1f%% flags=%d" % [(sum_on / maxf(1.0, sum_off) - 1.0) * 100.0, flags])
	get_tree().quit()

func _fight(cid: String, bid: String, lv: int, secs: float, sig: bool, trial: int) -> float:
	var m: Dictionary = Sim.load_map(GameData.maps[MAP])
	m["spawners"].clear()
	for e in m["entities"].duplicate():
		if e.kind != SimEntity.Kind.NPC:
			Sim.despawn(e)
	if Sim.player:
		Sim.despawn(Sim.player)
	Sim.rng.seed = 1000 + trial * 31 + lv
	Sim.signatures_on = sig
	var p: SimEntity = Sim.spawn_bot(GameData.classes[cid], "DPS", MAP, SPOT, lv)
	p.build_id = bid
	Sim._gear_bot(p)
	Sim._skill_bot(p)
	p.brain = null
	p.kind = SimEntity.Kind.PLAYER
	Sim.player = p
	p.recompute_stats()
	if not sig:                      # básico de antes: sem o corte da assinatura
		var bs: SkillDef = p.basic_skill.duplicate()
		bs.power = p.basic_skill.power / Balance.SIGNATURE_BASIC_TRIM
		p.basic_skill = bs
	var mob: SimEntity = Sim.spawn_monster(GameData.monsters["spider"], MAP, SPOT + Vector3(1.8, 0, 0))
	mob.brain = null
	mob.stats.max_hp = 1.0e7
	mob.hp = 1.0e7
	var t := 0.0
	var k := 0
	while t < secs:
		var c := InputCommand.new()
		c.aim = mob.position
		c.attack = true
		k += 1
		if k % 6 == 0:                 # rotação fixa: a próxima skill pronta, na ordem da barra
			for i in range(p.skills.size()):
				var sk: SkillDef = p.skills[(k / 6 + i) % p.skills.size()]
				if sk and float(p.cooldowns.get(sk.id, 0.0)) <= 0.0 and sk.kind in [SkillDef.Kind.PHYSICAL, SkillDef.Kind.MAGICAL]:
					c.skill_slot = (k / 6 + i) % p.skills.size()
					break
		Sim.set_player_command(c)
		Sim.tick(DT)
		t += DT
		p.mp = p.stats.max_mp
		p.hp = p.stats.max_hp
		mob.position = SPOT + Vector3(1.8, 0, 0)
	var dmg: float = 1.0e7 - mob.hp
	Sim.signatures_on = true
	Sim.despawn(mob)
	Sim.player = null
	Sim.despawn(p)
	return dmg / secs
