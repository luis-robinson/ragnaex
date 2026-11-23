extends Node
## DPS de cada build contra um boneco (calibrar o efeito-assinatura): mesmo bot, mesma luta, com e sem a assinatura
## (sem = sem o proc e com o básico de antes, sem SIGNATURE_BASIC_TRIM).
##   godot --headless --path . tools/tests/dps_probe.tscn -- [--levels=10,20,30] [--secs=30] [--trials=3] [--class=fogo,...]
## Saída: "DPS <classe>/<build> nv=N sem=X com=Y (+Z%)" e FLAG fora de -5%..+10%.
## --on_only: só a luta "com" (a do jogo); imprime "DPSON" e a mediana/espalhamento por nível (C5: ±25%).
## --by_skill: com --on_only, imprime "SRC" = % do dano por fonte (skill em curso no golpe, "dot:<tipo>", "pet" = invocação).
## --full_rot: a rotação usa também buffs e invocações (fora forma/aura, que ficam ligadas desde o início) e a 1ª forma da barra
##   já começa ligada (Lobo, Urso...), como o bot joga. Sem isto: só skills de dano (a conta antiga, sem invocador/buffs).
## --real_mp: não enche a mana a cada tick (o bot gasta e regenera como no jogo; começa cheio).
## --l50: no lugar da assinatura compara o conjunto do 50 (5 peças + armas do papel) sem e com os efeitos de peça
##   (PieceEffects, --l50_off=all no "sem"); FLAG = ganho acima de Balance.LEG50_GAIN_MAX.

const DT := 1.0 / 20.0
const MAP := "field_forest"
const SPOT := Vector3(-90, 0, 9)
var _l50 := false
var _real_mp := false
var _full_rot := false
var _by_skill := false
var _src := {}
var _pid := -1

func _ready() -> void:
	await get_tree().process_frame
	var levels := [10, 20, 30]
	var secs := 30.0
	var trials := 3
	var only: Array = []
	_l50 = OS.get_cmdline_user_args().has("--l50")
	_real_mp = OS.get_cmdline_user_args().has("--real_mp")
	_full_rot = OS.get_cmdline_user_args().has("--full_rot")
	WorldSim.bot_gear_legacy = OS.get_cmdline_user_args().has("--old_gear")     # A/B: equipamento de bot de antes (C5)
	_by_skill = OS.get_cmdline_user_args().has("--by_skill")
	if _by_skill:
		Events.damage_dealt.connect(_on_damage)
	var on_only := OS.get_cmdline_user_args().has("--on_only")
	var by_lv := {}
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
					if not on_only:
						off += _fight(cid, bid, lv, secs, false, t)
					on += _fight(cid, bid, lv, secs, true, t)
				off /= trials
				on /= trials
				if on_only:
					if not by_lv.has(lv):
						by_lv[lv] = []
					by_lv[lv].append([cid + "/" + bid, on])
					print("DPSON %-13s/%-15s nv=%2d dps=%7.1f" % [cid, bid, lv, on])
					if _by_skill:
						var tot := 0.0
						for k in _src:
							tot += float(_src[k])
						var keys: Array = _src.keys()
						keys.sort_custom(func(a, b): return float(_src[a]) > float(_src[b]))
						var parts: Array = []
						for k in keys.slice(0, 8):
							parts.append("%s %.0f%%" % [k, 100.0 * float(_src[k]) / maxf(1.0, tot)])
						print("SRC %s/%s nv=%d %s" % [cid, bid, lv, ", ".join(parts)])
						_src.clear()
					continue
				sum_off += off
				sum_on += on
				var d := (on / maxf(1.0, off) - 1.0) * 100.0
				var flag := (d > Balance.LEG50_GAIN_MAX * 100.0) if _l50 else (d < -5.0 or d > 10.0)
				flags += 1 if flag else 0
				print("DPS %-13s/%-15s nv=%2d sem=%6.1f com=%6.1f (%+.0f%%)%s" % [cid, bid, lv, off, on, d, "  FLAG" if flag else ""])
	for lv in by_lv:                    # espalhamento: % da mediana do nível (o check _check_dps_spread usa a mesma conta)
		var vals: Array = by_lv[lv].map(func(x): return float(x[1]))
		vals.sort()
		var med: float = vals[vals.size() / 2]
		for row in by_lv[lv]:
			print("SPREAD nv=%2d %-30s %+5.0f%%" % [lv, row[0], (float(row[1]) / med - 1.0) * 100.0])
		print("MEDIAN nv=%2d %.1f" % [lv, med])
	print("DPS_END total=%+.1f%% flags=%d" % [(sum_on / maxf(1.0, sum_off) - 1.0) * 100.0, flags])
	get_tree().quit()

func _on_damage(attacker_id: int, _target_id: int, amount: int, _crit: bool, _blocked: bool, kind: String) -> void:
	var a: SimEntity = Sim.get_entity(attacker_id)
	var key := "?"
	if kind.begins_with("dot"):
		key = kind
	elif attacker_id != _pid:
		key = "pet"
	elif a and a.current_skill:
		key = a.current_skill.id.trim_prefix("basic_").get_slice("_", 0) if a.current_skill.id.begins_with("basic_") else a.current_skill.id
		if a.current_skill.id.begins_with("basic_"):
			key = "basic"
	else:
		key = "proc/proj"
	_src[key] = float(_src.get(key, 0.0)) + amount

func _fight(cid: String, bid: String, lv: int, secs: float, sig: bool, trial: int) -> float:
	var m: Dictionary = Sim.load_map(GameData.maps[MAP])
	m["spawners"].clear()
	for e in m["entities"].duplicate():
		if e.kind != SimEntity.Kind.NPC:
			Sim.despawn(e)
	if Sim.player:
		Sim.despawn(Sim.player)
	Sim.rng.seed = 1000 + trial * 31 + lv
	Sim.signatures_on = sig or _l50
	PieceEffects.set_off("" if sig or not _l50 else "all")
	var p: SimEntity = Sim.spawn_bot(GameData.classes[cid], "DPS", MAP, SPOT, lv)
	p.build_id = bid
	Sim._gear_bot(p)
	if _l50:                          # conjunto da build no nível (o do 50 tem efeito em cada peça)
		var sd: SetDef = GameData.sets.get(Sim.bot_legendary_set(p, lv))
		if sd:
			for iid in sd.armor:
				p.equipment[(GameData.items[iid] as ItemDef).slot] = GameData.items[iid]
			for iid in Sim.bot_set_weapons(p, sd):
				var w: ItemDef = GameData.items[iid]
				p.equipment[ItemDef.Slot.OFFHAND if w.slot == ItemDef.Slot.OFFHAND or iid.ends_with("_offhand") else ItemDef.Slot.WEAPON] = w
		p.recompute_stats()
	Sim._skill_bot(p)
	_pid = p.id
	p.brain = null
	p.kind = SimEntity.Kind.PLAYER
	Sim.player = p
	p.recompute_stats()
	if not sig and not _l50:         # básico de antes: sem o corte da assinatura
		var bs: SkillDef = p.basic_skill.duplicate()
		bs.power = p.basic_skill.power / Balance.SIGNATURE_BASIC_TRIM
		p.basic_skill = bs
	for sk in p.skills:                  # aura de liga/desliga (Aura do Bastião): fica ligada a luta toda, como no jogo
		if sk and sk.effects.has("aura") and not AuraSystem.aura_on(p, sk):
			Sim._apply_skill(p, sk, m)
	var kinds: Array = [SkillDef.Kind.PHYSICAL, SkillDef.Kind.MAGICAL]
	if _full_rot:
		kinds.append_array([SkillDef.Kind.BUFF, SkillDef.Kind.SUMMON])
		for sk in p.skills:               # forma da build ligada desde o início (o bot entra nela)
			if sk and sk.effects.has("form") and not sk.ascension:
				Sim._apply_skill(p, sk, m)
				break
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
				if sk and float(p.cooldowns.get(sk.id, 0.0)) <= 0.0 and sk.kind in kinds and not sk.effects.has("form") and not sk.effects.has("aura"):
					c.skill_slot = (k / 6 + i) % p.skills.size()
					break
		Sim.set_player_command(c)
		Sim.tick(DT)
		t += DT
		if not _real_mp:
			p.mp = p.stats.max_mp
		p.hp = p.stats.max_hp
		mob.position = SPOT + Vector3(1.8, 0, 0)
	var dmg: float = 1.0e7 - mob.hp
	Sim.signatures_on = true
	PieceEffects.set_off("")
	Sim.despawn(mob)
	Sim.player = null
	Sim.despawn(p)
	return dmg / secs
