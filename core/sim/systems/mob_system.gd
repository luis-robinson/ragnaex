class_name MobSystem
extends RefCounted
## Monstros: provocação/troca de alvo, chamar a matilha, fases de chefe (lacaios, enrage, reset) e spawners.

## Provocar: quem provoca vira o topo da ameaça e o monstro fica preso nele por um tempo.
static func taunt(sim: WorldSim, mob: SimEntity, src: SimEntity, duration: float) -> void:
	var top := 0.0
	for id in mob.threat:
		top = maxf(top, float(mob.threat[id]))
	mob.threat[src.id] = top * Balance.THREAT_SWITCH + 1.0
	mob.aggro_target = src.id
	mob.aggro_timer = Balance.AGGRO_LOSE_TIME
	mob.taunt_left = duration * (0.5 if mob.monster_def.is_boss else 1.0)

## Troca de alvo por ameaça: o primeiro golpe puxa; depois só quem passa o alvo atual com folga.
static func retarget(sim: WorldSim, mob: SimEntity, attacker: SimEntity) -> void:
	mob.aggro_timer = Balance.AGGRO_LOSE_TIME
	if mob.aggro_target < 0:
		mob.aggro_target = attacker.id
		pack_call(sim, mob, attacker)
	elif mob.taunt_left <= 0.0 and float(mob.threat.get(attacker.id, 0.0)) > float(mob.threat.get(mob.aggro_target, 0.0)) * Balance.THREAT_SWITCH:
		mob.aggro_target = attacker.id

## Bando: o primeiro golpe num monstro chama os iguais que estão parados por perto (chefes e lacaios não).
static func pack_call(sim: WorldSim, mob: SimEntity, attacker: SimEntity) -> void:
	if mob.monster_def == null or mob.monster_def.is_boss or not sim.maps.has(mob.map_id):
		return
	var r2 := Balance.PACK_AGGRO_RADIUS * Balance.PACK_AGGRO_RADIUS
	for o in sim.maps[mob.map_id]["entities"]:
		if o == mob or o.kind != SimEntity.Kind.MONSTER or o.monster_def != mob.monster_def or not o.is_alive() or o.aggro_target >= 0:
			continue
		if o.position.distance_squared_to(mob.position) <= r2:
			o.aggro_target = attacker.id
			o.aggro_timer = Balance.AGGRO_LOSE_TIME

## Lacaios de chefe: monstros de verdade sem spawner; somem quando o chefe morre ou reseta.
static func spawn_adds(sim: WorldSim, boss: SimEntity, sm: Dictionary) -> void:
	var mdef: MonsterDef = GameData.monsters.get(sm.get("id", ""))
	if mdef == null:
		return
	var m: Dictionary = sim.maps[boss.map_id]
	var alive := 0
	for o in m["entities"]:
		if o.boss_id == boss.id and o.is_alive():
			alive += 1
	for i in range(int(sm.get("count", 1))):
		if alive >= int(sm.get("max", 6)):
			break
		var add := sim.spawn_monster(mdef, boss.map_id, MapGeometry.random_walkable(sim, m["def"], boss.position, 5.0))
		add.boss_id = boss.id
		add.adds_epoch = boss.adds_epoch
		add.aggro_target = boss.aggro_target
		add.aggro_timer = Balance.AGGRO_LOSE_TIME
		alive += 1

## Avança as fases pelo HP; uma queda grande de HP pode entrar em mais de uma de uma vez.
static func update_boss(sim: WorldSim, e: SimEntity) -> void:
	var phases: Array = e.monster_def.phases
	while e.phase < phases.size() and e.hp / e.stats.max_hp <= float(phases[e.phase]["hp"]):
		var ph: Dictionary = phases[e.phase]
		e.phase += 1
		if ph.has("say") and sim.player and sim.player.map_id == e.map_id:
			Events.notification.emit("%s: %s" % [e.name, ph["say"]])
		sim._add_skills(e, ph.get("skills", []))
		if ph.has("summon"):
			spawn_adds(sim, e, ph["summon"])
		if ph.has("enrage"):
			e.dmg_mult = float(ph["enrage"])
			e.recompute_stats()

## Chefe volta ao estado inicial depois de um wipe ou de ser puxado longe demais.
static func reset_boss(sim: WorldSim, e: SimEntity) -> void:
	e.phase = 0
	e.dmg_mult = 1.0
	e.adds_epoch += 1
	e.skills.clear()
	sim._add_skills(e, e.monster_def.skill_ids)
	e.cooldowns.clear()
	e.mastery.clear()
	e.debuffs.clear()
	e.threat.clear()
	e.damage_by.clear()
	e.taunt_left = 0.0
	e.recompute_stats()
	e.heal_full()

static func update_spawners(sim: WorldSim, m: Dictionary, dt: float) -> void:
	var def: MapDef = m["def"]
	for sp in m["spawners"]:
		var sdef: Dictionary = sp["def"]
		sp["alive"] = sp["alive"].filter(func(id): return sim.entities.has(id))
		if sp["alive"].size() < int(sdef.get("count", 1)):
			sp["timer"] -= dt
			if sp["timer"] <= 0.0:
				var mdef: MonsterDef = GameData.monsters.get(sdef["monster_id"])
				if mdef:
					var pos := MapGeometry.random_walkable(sim, def, sdef["pos"], float(sdef.get("radius", 6.0)))
					var em = sdef.get("emerge")
					if em is Array and em.size() >= 3:      # sai do lago: nasce na beira d'água e anda até o lugar dele
						var c := Vector3(float(em[0]), 0, float(em[1]))
						var dir := Vector3(sdef["pos"].x - c.x, 0, sdef["pos"].z - c.z).normalized()
						pos = c + dir * (float(em[2]) + mdef.radius + 0.6)
					var mob := sim.spawn_monster(mdef, def.id, pos, sp)
					if em is Array and em.size() >= 3:
						Events.monster_emerged.emit(def.id, pos)
						if sim.player and sim.player.map_id == def.id:
							Events.chat_message.emit("Sistema", "%s emerge do lago!" % mob.monster_def.name, "system")
				if sp["alive"].size() >= int(sdef.get("count", 1)):
					sp["primed"] = true
				# enche rápido na 1ª vez (mapa recém-carregado) e quando esvazia; depois, um por vez no tempo de respawn
				sp["timer"] = float(sdef.get("respawn", 10.0)) if sp["alive"].size() > 0 and sp["primed"] else 0.5
