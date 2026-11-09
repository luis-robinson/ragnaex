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
	if attacker.is_perched():
		return                              # flecha da torre não puxa o monstro (ele não sobe)
	mob.aggro_timer = Balance.AGGRO_LOSE_TIME
	if mob.aggro_target < 0:
		mob.aggro_target = attacker.id
		pack_call(sim, mob, attacker)
	elif mob.taunt_left <= 0.0 and float(mob.threat.get(attacker.id, 0.0)) > float(mob.threat.get(mob.aggro_target, 0.0)) * Balance.THREAT_SWITCH:
		mob.aggro_target = attacker.id

## Bando: o primeiro golpe num monstro chama os iguais que estão parados por perto (chefes e lacaios não).
## Escolta: quem bate no líder ou num da escolta chama o grupo inteiro (líder + seguidores).
static func pack_call(sim: WorldSim, mob: SimEntity, attacker: SimEntity) -> void:
	if mob.monster_def == null or not sim.maps.has(mob.map_id):
		return
	var lid: int = mob.leader_id if mob.leader_id >= 0 else (mob.id if not mob.monster_def.escort.is_empty() else -1)
	if lid >= 0:
		for o in sim.maps[mob.map_id]["entities"]:
			if o != mob and o.is_alive() and o.aggro_target < 0 and (o.id == lid or o.leader_id == lid):
				o.aggro_target = attacker.id
				o.aggro_timer = Balance.AGGRO_LOSE_TIME
	if mob.monster_def.is_boss:
		return
	var r2 := Balance.PACK_AGGRO_RADIUS * Balance.PACK_AGGRO_RADIUS
	for o in sim.maps[mob.map_id]["entities"]:
		if o == mob or o.kind != SimEntity.Kind.MONSTER or o.monster_def != mob.monster_def or not o.is_alive() or o.aggro_target >= 0:
			continue
		if o.position.distance_squared_to(mob.position) <= r2:
			o.aggro_target = attacker.id
			o.aggro_timer = Balance.AGGRO_LOSE_TIME

## Escolta do líder (MonsterDef.escort): nasce em volta dele, cada um numa vaga do anel. Monstros normais (XP, loot).
static func spawn_escort(sim: WorldSim, leader: SimEntity, sp: Dictionary) -> void:
	var es: Dictionary = leader.monster_def.escort
	var mdef: MonsterDef = GameData.monsters.get(str(es.get("id", "")))
	if mdef == null or not sim.maps.has(leader.map_id):
		return
	var m: Dictionary = sim.maps[leader.map_id]
	var have := {}
	for id in sp.get("escort", []):
		var o: SimEntity = sim.entities.get(id)
		if o and o.is_alive() and o.leader_id == leader.id:
			have[o.escort_slot] = true
	var out: Array = (sp.get("escort", []) as Array).filter(func(id): return sim.entities.has(id) and sim.entities[id].leader_id == leader.id)
	for i in range(int(es.get("count", 0))):
		if have.has(i):
			continue
		var p := MapGeometry.random_walkable(sim, m["def"], leader.position + escort_offset(i, int(es.get("count", 1))), 1.5)
		var f := sim.spawn_monster(mdef, leader.map_id, p)
		f.leader_id = leader.id
		f.escort_slot = i
		out.append(f.id)
	sp["escort"] = out

## Vaga i de n no anel em volta do líder.
static func escort_offset(i: int, n: int) -> Vector3:
	var a := TAU * float(i) / maxf(1.0, float(n)) + 0.4
	return Vector3(cos(a), 0, sin(a)) * Balance.ESCORT_RING

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
		if sm.has("pick"):                     # lacaio que corre atrás de quem está longe (curandeiro, atirador)
			var v := pick_victim(sim, boss, str(sm["pick"]))
			if v:
				add.aggro_target = v.id
		add.aggro_timer = Balance.AGGRO_LOSE_TIME
		if boss.raid_id >= 0:                  # invocado por invasor: marcha com a leva e a leva só acaba com ele morto
			add.raid_id = boss.raid_id
			add.raid_leg = boss.raid_leg
			add.raid_route = boss.raid_route
			(RaidSystem.state(m, boss.raid_route)["ids"] as Array).append(add.id)
		alive += 1

## Fala de chefe (abertura, fase, queda): aviso na tela só para quem está no mapa.
static func boss_say(sim: WorldSim, e: SimEntity, text: String) -> void:
	if sim.player and sim.player.map_id == e.map_id:
		Events.post(&"notification", "%s: %s" % [e.name, text])

## Avança as fases pelo HP; uma queda grande de HP pode entrar em mais de uma de uma vez.
## Com `dt`: conta o tempo da luta (berserk_after) e confere os lacaios vivos (escudo da fase com "ward").
static func update_boss(sim: WorldSim, e: SimEntity, dt: float = 0.0) -> void:
	if not e.boss_spoke and e.aggro_target >= 0 and e.monster_def.intro != "":
		e.boss_spoke = true
		boss_say(sim, e, e.monster_def.intro)
	var phases: Array = e.monster_def.phases
	while e.phase < phases.size() and e.hp / e.stats.max_hp <= float(phases[e.phase]["hp"]):
		var ph: Dictionary = phases[e.phase]
		e.phase += 1
		if ph.has("say"):
			boss_say(sim, e, str(ph["say"]))
		sim._add_skills(e, ph.get("skills", []))
		if ph.has("ward"):
			e.ward_base = float(ph["ward"])
			e.ward_t = 0.0
		if ph.has("summon"):
			spawn_adds(sim, e, ph["summon"])
		if ph.has("enrage"):
			e.enrage_mult = float(ph["enrage"])
			_apply_fury(e)
	if e.aggro_target >= 0:
		e.fight_time += dt
	var after := e.monster_def.berserk_after
	if after > 0.0 and not e.berserk and e.fight_time >= after:
		e.berserk = true
		boss_say(sim, e, "%s enlouquece de fúria!" % e.monster_def.name)
		_apply_fury(e)
	if e.berserk:
		e.put_buff({"id": "boss_berserk", "remaining": 1.0})
	if e.ward_base > 0.0:
		e.ward_t -= dt
		if e.ward_t <= 0.0:
			e.ward_t = Balance.BOSS_WARD_CHECK
			e.ward = e.ward_base if adds_alive(sim, e) > 0 else 0.0
		if e.ward > 0.0:
			e.put_buff({"id": "boss_ward", "remaining": Balance.BOSS_WARD_CHECK + 0.2})
		else:
			e.drop_buff("boss_ward")

## Fúria = fúria da fase × enlouquecer por tempo (um não apaga o outro).
static func _apply_fury(e: SimEntity) -> void:
	e.dmg_mult = e.enrage_mult * (Balance.BOSS_BERSERK_MULT if e.berserk else 1.0)
	e.recompute_stats()

## Lacaios vivos deste chefe.
static func adds_alive(sim: WorldSim, boss: SimEntity) -> int:
	if not sim.maps.has(boss.map_id):
		return 0
	var n := 0
	for o in sim.maps[boss.map_id]["entities"]:
		if o.boss_id == boss.id and o.is_alive():
			n += 1
	return n

## Chefe volta ao estado inicial depois de um wipe ou de ser puxado longe demais.
static func reset_boss(sim: WorldSim, e: SimEntity) -> void:
	e.phase = 0
	e.boss_spoke = false
	e.dmg_mult = 1.0
	e.enrage_mult = 1.0
	e.berserk = false
	e.fight_time = 0.0
	e.ward_base = 0.0
	e.ward = 0.0
	e.ward_t = 0.0
	e.adds_epoch += 1
	e.skills.clear()
	sim._add_skills(e, e.monster_def.skill_ids)
	e.cooldowns.clear()
	e.mastery.clear()
	e.debuffs.clear()
	e.drop_buff("boss_ward")
	e.drop_buff("boss_berserk")
	e.threat.clear()
	e.damage_by.clear()
	e.taunt_left = 0.0
	if sim.maps.has(e.map_id):
		var hz: Array = sim.maps[e.map_id].get("hazards", [])
		sim.maps[e.map_id]["hazards"] = hz.filter(func(h): return h["owner"] != e.id)
	e.recompute_stats()
	e.heal_full()

# ---------------------------------------------------------------------------
# Mira do chefe e chuva de golpes no chão (barrage)
# ---------------------------------------------------------------------------

## Quem o chefe pode escolher: personagens/invocações inimigos vivos por perto, visíveis e no chão.
static func victims(sim: WorldSim, boss: SimEntity, max_d: float = Balance.BOSS_PICK_RANGE) -> Array:
	var out: Array = []
	if not sim.maps.has(boss.map_id):
		return out
	var m: Dictionary = sim.maps[boss.map_id]
	var d2 := max_d * max_d
	for o in m.get("chars", m["entities"]):
		if o == boss or not o.is_alive() or o.map_id != boss.map_id or o.position.distance_squared_to(boss.position) > d2:
			continue
		if o.kind == SimEntity.Kind.MONSTER or not boss.is_hostile_to(o) or o.stealth_left > 0.0 or o.is_perched():
			continue
		out.append(o)
	return out

## Vítima de uma skill com SkillDef.mob_pick: "far" (o mais longe), "random", "soft" (curandeiro/conjurador/atirador,
## senão o mais longe). Prefere personagens a invocações. null = ninguém por perto.
static func pick_victim(sim: WorldSim, boss: SimEntity, rule: String, max_d: float = Balance.BOSS_PICK_RANGE) -> SimEntity:
	var pool := victims(sim, boss, max_d)
	var chars := pool.filter(func(o): return o.is_character())
	if not chars.is_empty():
		pool = chars
	if pool.is_empty():
		return null
	if rule == "random":
		return pool[sim.rng.randi() % pool.size()]
	if rule == "soft":
		var soft := pool.filter(func(o): return role_of(o) in ["healer", "caster", "ranged"])
		if not soft.is_empty():
			pool = soft
	var best: SimEntity = null
	var best_d := -1.0
	for o in pool:
		var d: float = o.position.distance_squared_to(boss.position)
		if d > best_d:
			best_d = d
			best = o
	return best

## Skill de alvo com mob_pick: no impacto, mira o inimigo mais perto de onde o chefe mirou (até BOSS_FOLLOW m),
## porque a vítima andou durante a preparação. Fora do alcance a skill erra (Combat.select_targets).
static func follow_victim(sim: WorldSim, boss: SimEntity, s: SkillDef, aim: Vector3) -> Vector3:
	var best := aim
	var best_d := Balance.BOSS_FOLLOW
	for o in victims(sim, boss, s.range + 2.0):
		var d: float = Vector2(o.position.x - aim.x, o.position.z - aim.z).length()
		if d < best_d:
			best_d = d
			best = o.position
	return best

## Papel da build (tank/dps/healer/ranged/caster); sem build, o da classe.
static func role_of(o: SimEntity) -> String:
	if o.class_def == null:
		return ""
	for b in o.class_def.builds:
		if str(b.get("id", "")) == o.build_id:
			return str(b.get("role", o.class_def.role))
	return o.class_def.role

## Chuva de golpes: um círculo onde a skill mirou, um em cada outro inimigo por perto (até `count`), o resto em
## volta do chefe. Cada círculo avisa (Events.hazard_placed) e cai `delay` s depois (update_hazards).
static func place_barrage(sim: WorldSim, e: SimEntity, s: SkillDef, aim: Vector3, power: float, effects: Dictionary) -> void:
	var m: Dictionary = sim.maps[e.map_id]
	if not m.has("hazards"):
		m["hazards"] = []
	var bd: Dictionary = effects["barrage"]
	var count := int(bd.get("count", 3))
	var r := float(bd.get("radius", maxf(1.5, s.radius)))
	var delay := float(bd.get("delay", Balance.BOSS_HAZARD_DELAY))
	var spread := float(bd.get("spread", 8.0))
	var fx := {}
	for k in ["root", "slow", "stun", "dot", "wither"]:
		if effects.has(k):
			fx[k] = effects[k]
	var spots: Array = [Vector3(aim.x, 0, aim.z)]
	for o in victims(sim, e):
		if spots.size() >= count:
			break
		var p := Vector3(o.position.x, 0, o.position.z)
		if spots.all(func(q): return q.distance_to(p) > r):
			spots.append(p)
	var tries := 0
	while spots.size() < count and tries < count * 6:
		tries += 1
		var p := MapGeometry.random_walkable(sim, m["def"], e.position, spread)
		p.y = 0.0
		if spots.all(func(q): return q.distance_to(p) > r * 1.2):
			spots.append(p)
	for p in spots:
		m["hazards"].append({"owner": e.id, "pos": p, "radius": r, "at": sim.time + delay, "power": power, "kind": s.kind, "effects": fx, "skill": s.id})
		Events.post(&"hazard_placed", e.map_id, p, r, delay, s.id)

## Círculos de chefe: caem na hora marcada (dano + efeito em quem ficou dentro); somem se o dono morreu ou saiu.
static func update_hazards(sim: WorldSim, m: Dictionary) -> void:
	var hz: Array = m.get("hazards", [])
	if hz.is_empty():
		return
	for h in hz.duplicate():
		var owner: SimEntity = sim.entities.get(h["owner"])
		if owner == null or not owner.is_alive() or owner.map_id != m["def"].id:
			hz.erase(h)
			continue
		if sim.time < float(h["at"]):
			continue
		hz.erase(h)
		var pos: Vector3 = h["pos"]
		var kind: int = h["kind"]
		for o in m["entities"].duplicate():
			if o.is_alive() and owner.is_hostile_to(o) and Vector3(o.position.x, 0, o.position.z).distance_to(pos) <= float(h["radius"]) + o.radius:
				var r := Combat.calc_damage(owner, o, float(h["power"]), kind, sim.rng, pos)
				sim._deal_damage(owner, o, r["amount"], r["crit"], false, "magical" if kind == SkillDef.Kind.MAGICAL else "physical", pos)
				sim._apply_effects(owner, o, h["effects"], float(h["power"]))
		Events.post(&"skill_effect", h["skill"], pos, pos, float(h["radius"]))

static func update_spawners(sim: WorldSim, m: Dictionary, dt: float) -> void:
	var def: MapDef = m["def"]
	for sp in m["spawners"]:
		var sdef: Dictionary = sp["def"]
		sp["alive"] = sp["alive"].filter(func(id): return sim.entities.has(id))
		if not WorldState.active(sim, sdef):    # fortaleza retomada (if/unless): o spawner fica calado
			continue
		if sp.has("escort"):                 # líder vivo e fora de combate: repõe quem caiu da escolta
			sp["escort_t"] = float(sp.get("escort_t", 0.0)) - dt
			if float(sp["escort_t"]) <= 0.0:
				sp["escort_t"] = Balance.ESCORT_RESPAWN
				for id in sp["alive"]:
					var ld: SimEntity = sim.entities.get(id)
					if ld and ld.is_alive() and not ld.monster_def.escort.is_empty() and ld.aggro_target < 0:
						spawn_escort(sim, ld, sp)
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
					if sdef.has("route"):
						mob.patrol_route = sdef["route"]
					if not mdef.escort.is_empty():         # líder novo: a escolta órfã do anterior some e nasce a dele
						for id in sp.get("escort", []):
							var old: SimEntity = sim.entities.get(id)
							if old and old.leader_id != mob.id and old.aggro_target < 0:
								sim.despawn(old)
						sp["escort"] = []
						spawn_escort(sim, mob, sp)
						sp["escort_t"] = Balance.ESCORT_RESPAWN
					if em is Array and em.size() >= 3:
						Events.post(&"monster_emerged", def.id, pos)
						if sim.player and sim.player.map_id == def.id:
							Events.post(&"chat_message", "Sistema", "%s emerge do lago!" % mob.monster_def.name, "system")
				if sp["alive"].size() >= int(sdef.get("count", 1)):
					sp["primed"] = true
				# enche rápido na 1ª vez (mapa recém-carregado) e quando esvazia; depois, um por vez no tempo de respawn
				sp["timer"] = float(sdef.get("respawn", 10.0)) if sp["alive"].size() > 0 and sp["primed"] else 0.5
