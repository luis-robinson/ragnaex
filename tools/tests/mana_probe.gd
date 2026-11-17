extends Node
## Economia de mana por build (Berserker sem mana? comparar com outras classes). Bot da build no nível, equipamento de bot,
## rotação fixa (a próxima skill de dano pronta, na ordem da barra, como a dps_probe), SEM repor a mana:
##   godot --headless --path . tools/tests/mana_probe.tscn -- [--levels=10,20,30,40] [--class=berserker,...] [--secs=60] [--no_acc] [--strip_bonus]
## "chefe": alvo de vida infinita por --secs; "caca": monstros com ~7 s de vida (pelo DPS medido) e 3 s de caminhada entre eles.
## Saída: "MANA <classe>/<build> nv=N <cena> mp=.. regen=../s gasto=../s vazio=..s fome=..% abates=.. custo=[skill:custo/recarga ...]"
## fome = % das tentativas de skill em que havia skill de dano pronta mas sem mana. --no_acc tira capa/amuleto/anéis; --strip_bonus mantém as peças e tira só ItemDef.bonus (A/B das joias).

const DT := 1.0 / 20.0
const MAP := "field_forest"
const SPOT := Vector3(-90, 0, 9)

func _ready() -> void:
	await get_tree().process_frame
	var levels := [10, 20, 30, 40]
	var secs := 60.0
	var only: Array = ["berserker", "cruzado", "laminas", "lanceiro"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--levels="): levels = Array(a.get_slice("=", 1).split(",")).map(func(x): return int(x))
		if a.begins_with("--secs="): secs = float(a.get_slice("=", 1))
		if a.begins_with("--class="): only = Array(a.get_slice("=", 1).split(","))
	Sim.load_map(GameData.maps[GameData.town_map_id()])
	for cid in GameData.classes:
		for b in GameData.classes[cid].builds:
			var bid: String = b["id"]
			if not (bid in only) and not (cid in only):
				continue
			for lv in levels:
				var dps: float = _run(cid, bid, lv, 10.0, false, true, 0.0)["dps"]
				_run(cid, bid, lv, secs, false, false, 0.0)
				_run(cid, bid, lv, secs * 2.0, true, false, dps * 7.0)
	print("MANA_END")
	get_tree().quit()

func _setup(cid: String, bid: String, lv: int) -> SimEntity:
	var m: Dictionary = Sim.load_map(GameData.maps[MAP])
	m["spawners"].clear()
	for e in m["entities"].duplicate():
		if e.kind != SimEntity.Kind.NPC:
			Sim.despawn(e)
	if Sim.player:
		Sim.despawn(Sim.player)
	Sim.rng.seed = 4242 + lv
	var p: SimEntity = Sim.spawn_bot(GameData.classes[cid], "Mana", MAP, SPOT, lv)
	p.build_id = bid
	Sim._gear_bot(p)
	Sim._skill_bot(p)
	if DevArgs.has("--no_acc"):
		for sl in [ItemDef.Slot.CAPE, ItemDef.Slot.AMULET, ItemDef.Slot.RING, ItemDef.Slot.RING2]:
			p.equipment.erase(sl)
	if DevArgs.has("--strip_bonus"):          # A/B das joias de mana: mesmas peças (atributos iguais), sem ItemDef.bonus
		for sl in p.equipment.keys():
			var it: ItemDef = p.equipment[sl]
			if it and not it.bonus.is_empty():
				var cp: ItemDef = it.duplicate()
				cp.bonus = {}
				p.equipment[sl] = cp
	p.brain = null
	p.kind = SimEntity.Kind.PLAYER
	Sim.player = p
	p.recompute_stats()
	p.mp = p.stats.max_mp
	return p

func _mob(hp: float) -> SimEntity:
	var mob: SimEntity = Sim.spawn_monster(GameData.monsters["spider"], MAP, SPOT + Vector3(1.8, 0, 0))
	mob.brain = null
	mob.stats.max_hp = hp
	mob.hp = hp
	return mob

func _run(cid: String, bid: String, lv: int, secs: float, hunt: bool, refill: bool, mob_hp: float) -> Dictionary:
	var p := _setup(cid, bid, lv)
	var mob := _mob(1.0e7 if not hunt else mob_hp)
	var t := 0.0
	var k := 0
	var spent := 0.0
	var gained := 0.0
	var tries := 0
	var starved := 0
	var empty_at := -1.0
	var kills := 0
	var walk := 0.0
	var dealt := 0.0
	var costs: Array = []
	for sk in p.skills:
		if sk and sk.kind in [SkillDef.Kind.PHYSICAL, SkillDef.Kind.MAGICAL]:
			costs.append("%s:%.0f/%.0fs" % [sk.id, sk.mp_cost_at(p.mastery_of(sk.id)), sk.cooldown])
	while t < secs:
		var c := InputCommand.new()
		if walk > 0.0:                  # entre um monstro e outro: anda (fora de combate só quando o relógio de combate zera)
			walk -= DT
			if walk <= 0.0:
				mob = _mob(mob_hp)
		else:
			c.aim = mob.position
			c.attack = true
			k += 1
			if k % 6 == 0:
				var ready := false
				var picked := false
				for i in range(p.skills.size()):
					var sk: SkillDef = p.skills[(k / 6 + i) % p.skills.size()]
					if sk and float(p.cooldowns.get(sk.id, 0.0)) <= 0.0 and sk.kind in [SkillDef.Kind.PHYSICAL, SkillDef.Kind.MAGICAL]:
						ready = true
						if p.mp >= sk.mp_cost_at(p.mastery_of(sk.id)):
							c.skill_slot = (k / 6 + i) % p.skills.size()
							picked = true
							break
				if ready:
					tries += 1
					if not picked:
						starved += 1
						if empty_at < 0.0:
							empty_at = t
		var before: float = p.mp
		var hp_before: float = mob.hp if mob and is_instance_valid(mob) else 0.0
		Sim.set_player_command(c)
		Sim.tick(DT)
		t += DT
		var d: float = p.mp - before
		if d < 0.0: spent -= d
		else: gained += d
		if refill:
			p.mp = p.stats.max_mp
		p.hp = p.stats.max_hp
		if walk <= 0.0 and mob:
			dealt += maxf(0.0, hp_before - mob.hp)
			if not mob.is_alive():
				kills += 1
				walk = 3.0
				Sim.despawn(mob)
			else:
				mob.position = SPOT + Vector3(1.8, 0, 0)
	if not refill:
		print("MANA %s/%s nv=%d %s mp=%.0f regen=%.1f/s gasto=%.1f/s vazio=%s fome=%.0f%% abates=%d dps=%.0f custo=[%s]" % [cid, bid, lv,
			"caca " if hunt else "chefe", p.stats.max_mp, gained / secs, spent / secs, ("%.0fs" % empty_at) if empty_at >= 0.0 else "nunca",
			100.0 * starved / maxf(1, tries), kills, dealt / secs, " ".join(costs)])
	if mob and walk <= 0.0:
		Sim.despawn(mob)
	Sim.player = null
	Sim.despawn(p)
	return {"dps": dealt / secs}
