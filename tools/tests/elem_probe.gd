extends Node
## Dano do Elementalista com e sem a ascensão (GDD ato2-horda F5): personagem nível 35 de cada build contra um chefe parado que
## não revida (o chefe fica num "tanque" de fora; só o dano conta), LIMIT s por luta, N lutas. Rotação fixa (como um jogador:
## as skills de ascensão assim que prontas, depois a primeira pronta da barra, senão o básico); --bots usa o BotBrain (anda e escolhe sozinho: ruidoso).
## O dano das invocações conta para o dono (damage_by).
##   godot --headless --path . tools/tests/elem_probe.tscn -- [--trials=4] [--build=fogo,...] [--limit=90] [--stage=0,1]
##     [--bots] [--nofusion] [--nospit] [--verbose]   (sem a Fusão / sem as skills de estágio / casts e dano por skill)
## Saída: "ELEM <build> <modo> dps=D (xN)" — modo sem = sem ascensão; asc<S> = ascendido com o elemental no estágio S;
## a razão é dps ÷ dps sem (o alvo do F5 aos 35 é 1,06–1,10).

const DT := 1.0 / 20.0
const MAP := "field_forest"
const SPOT := Vector3(-90, 0, 9)
const TANK_ID := -77
var verbose := false
var _pet_dmg: Array = [0.0]
var _casts: Dictionary = {}
var _last_pet := 0.0
var _nofusion := false
var _nospit := false
var _bots := false

class StayBrain extends BotBrain:
	func _plan_trip(_e: SimEntity, _sim) -> void:
		state = S.HUNT
		timer = 5.0
	func _go_home(_e: SimEntity, _sim) -> void:
		state = S.HUNT
		timer = 5.0

func _ready() -> void:
	await get_tree().process_frame
	var trials := 4
	var limit := 90.0
	var builds: Array = ["fogo", "gelo", "raio"]
	var stages: Array = [0, 1]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--trials="): trials = int(a.get_slice("=", 1))
		if a.begins_with("--limit="): limit = float(a.get_slice("=", 1))
		if a.begins_with("--build="): builds = Array(a.get_slice("=", 1).split(","))
		if a == "--verbose": verbose = true
		if a == "--nofusion": _nofusion = true
		if a == "--nospit": _nospit = true
		if a == "--bots": _bots = true          # bot de verdade (BotBrain) em vez da rotação fixa
		if a.begins_with("--stage="): stages = Array(a.get_slice("=", 1).split(",")).map(func(x): return int(x))
	Sim.load_map(GameData.maps[GameData.town_map_id()])
	for b in builds:
		var base := _run(b, -1, trials, limit)
		var base_pet := _last_pet
		print("ELEM %s sem dps=%.0f (elemental %.0f)" % [b, base, base_pet])
		for st in stages:
			var d := _run(b, int(st), trials, limit)
			print("ELEM %s asc%d dps=%.0f (x%.3f) elemental %.0f mago x%.3f" % [b, st, d, d / maxf(1.0, base), _last_pet, (d - _last_pet) / maxf(1.0, base - base_pet)])
	print("ELEM_END")
	get_tree().quit()

## Comando de rotação: a primeira skill pronta da barra (com MP) no chefe; senão o básico.
func _rotation(bot: SimEntity, boss: SimEntity) -> InputCommand:
	var c := InputCommand.new()
	c.aim = boss.position
	var order: Array = []                  # ascensão assim que pronta, depois a barra na ordem
	for i in range(bot.skills.size()):
		if bot.skills[i] != null and bot.skills[i].ascension:
			order.append(i)
	for i in range(bot.skills.size()):
		if not (i in order):
			order.append(i)
	for i in order:
		var sk: SkillDef = bot.skills[i]
		if sk == null or float(bot.cooldowns.get(sk.id, 0.0)) > 0.0 or bot.mp < sk.mp_cost_at(bot.mastery_of(sk.id)) or not bot.stats.meets(sk.requires):
			continue
		if sk.kind in [SkillDef.Kind.MOVEMENT, SkillDef.Kind.HEAL] or sk.effects.has("elem_command") or sk.effects.has("form"):
			continue
		if sk.effects.get("summon") is Dictionary and Sim._summons_full(bot, sk):
			continue
		if sk.kind == SkillDef.Kind.BUFF and sk.effects.get("buff") is Dictionary and bot.buffs.any(func(x): return x.get("id") == sk.effects["buff"].get("id")):
			continue
		c.skill_slot = i
		return c
	c.attack = true
	return c

## stage < 0 = sem ascensão.
func _run(build: String, stage: int, trials: int, limit: float) -> float:
	var total := 0.0
	var pet_total := 0.0
	var m: Dictionary = Sim.load_map(GameData.maps[MAP])
	for t in range(trials):
		m["spawners"].clear()
		for e in m["entities"].duplicate():
			if e.kind != SimEntity.Kind.NPC:
				Sim.despawn(e)
		Sim.rng.seed = 1000 + t
		var boss: SimEntity = Sim.spawn_monster(GameData.monsters["ghoul_giant"], MAP, SPOT + Vector3(6, 0, 0))
		boss.brain = null
		boss.stats.max_hp = 1.0e9
		boss.hp = 1.0e9
		var bot: SimEntity = Sim.spawn_bot(GameData.classes["elementalist"], "E", MAP, SPOT, Balance.ASC_LEVEL)
		if bot.build_id != build:
			bot.build_id = build
			Sim._gear_bot(bot)
			Sim._skill_bot(bot)
		if stage >= 0:
			bot.quests_completed.append("hx_asc_elementalist")
			for sid in ([] if _nofusion else ["ele_asc_fusion"]) + ["ele_asc_command"]:
				bot.learned[sid] = true
			bot.elem_stage = stage
			Sim._slot_bot(bot)
		if _bots:
			var sb := StayBrain.new()
			sb.setup(bot, Sim.rng)
			sb.personality = 1.0
			bot.brain = sb
		else:
			bot.brain = null                        # rotação fixa (como um jogador): skill pronta na ordem da barra, senão básico
			bot.position = boss.position + Vector3(-7.0, 0, 0)
			if stage >= 0:
				Sim.elem_command(bot, ElementalSystem.default_form(bot), "")
		bot.heal_full()
		_pet_dmg[0] = 0.0
		var on_dmg := func(src: int, tid: int, amount: int, _c: bool, _b: bool, _k: String):
			var a: SimEntity = Sim.entities.get(src)
			if a and tid == boss.id and a.kind == SimEntity.Kind.SUMMON and a.owner_id == bot.id:
				_pet_dmg[0] += amount
			if src == bot.id and tid == boss.id:
				var cs: String = bot.current_skill.id if bot.current_skill else "-"
				_casts["dmg_" + cs] = int(_casts.get("dmg_" + cs, 0)) + amount
		Events.damage_dealt.connect(on_dmg)
		_casts.clear()
		var on_cast := func(id: int, sid: String, ph: String):
			if id == bot.id and ph == "active":
				_casts[sid] = int(_casts.get(sid, 0)) + 1
		Events.skill_cast.connect(on_cast)
		var t0 := Sim.time
		var t_cast := 0.0
		while Sim.time - t0 < limit:
			if bot.state == SimEntity.State.CASTING:
				t_cast += DT
			if bot.buffs.any(func(x): return x.get("id") == "elem_fusion"):
				_casts["fusion_ticks"] = int(_casts.get("fusion_ticks", 0)) + 1
				_casts["fusion_matk"] = bot.stats.matk
			else:
				_casts["plain_matk"] = bot.stats.matk
			var stk := "st_%d_mp%d" % [bot.state, int(bot.mp / maxf(1.0, bot.stats.max_mp) * 4.0)]
			_casts[stk] = int(_casts.get(stk, 0)) + 1
			boss.aggro_target = TANK_ID          # o chefe fica num "tanque" de fora: só o dano do mago e do elemental conta
			boss.taunt_left = 0.0
			if _nospit:
				var el := ElementalSystem.elemental_of(Sim, bot)
				if el:
					el.skills = el.skills.filter(func(x): return not x.id.begins_with("elem_"))
			if not _bots:
				Sim.set_player_command(_rotation(bot, boss))
				Sim.player = bot
			Sim.tick(DT)
		Sim.player = null
		Events.damage_dealt.disconnect(on_dmg)
		Events.skill_cast.disconnect(on_cast)
		total += float(boss.damage_by.get(bot.id, 0.0)) / limit
		pet_total += float(_pet_dmg[0]) / limit
		if verbose and t == 0:
			var el := ElementalSystem.elemental_of(Sim, bot)
			print("  %s st=%d usos=%d elemental=%s pet=%.0f/s skills=%s" % [build, stage, bot.elem_uses, el.name if el else "-", float(_pet_dmg[0]) / limit,
				str(_casts) + " casting=%.0fs" % t_cast])
	_last_pet = pet_total / trials
	return total / trials
