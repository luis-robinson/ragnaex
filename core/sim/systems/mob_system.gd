class_name MobSystem
extends RefCounted
## Monstros: provocação/troca de alvo, chamar a matilha, fases de chefe (lacaios, enrage, reset) e spawners.

## Provocar: quem provoca vira o topo da ameaça com folga (TAUNT_THREAT_LEAD) e o monstro fica preso nele por um tempo.
static func taunt(sim: WorldSim, mob: SimEntity, src: SimEntity, duration: float) -> void:
	var top := 0.0
	for id in mob.threat:
		top = maxf(top, float(mob.threat[id]))
	mob.threat[src.id] = top * Balance.TAUNT_THREAT_LEAD + 1.0
	mob.aggro_target = src.id
	mob.aggro_timer = Balance.AGGRO_LOSE_TIME
	mob.taunt_left = duration * (0.5 if mob.monster_def.resists_cc() else 1.0)

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
		for o: SimEntity in sim.maps[mob.map_id]["entities"]:
			if o != mob and o.is_alive() and o.aggro_target < 0 and (o.id == lid or o.leader_id == lid):
				o.aggro_target = attacker.id
				o.aggro_timer = Balance.AGGRO_LOSE_TIME
	if mob.monster_def.is_boss:
		return
	var r2 := Balance.PACK_AGGRO_RADIUS * Balance.PACK_AGGRO_RADIUS
	for o: SimEntity in sim.maps[mob.map_id]["entities"]:
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
	# a lista é do spawner inteiro (vários líderes): guarda a escolta viva de TODOS, senão a dos outros era reposta de novo
	var out: Array = (sp.get("escort", []) as Array).filter(func(id): return sim.entities.has(id) and sim.entities[id].is_alive())
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
	for o: SimEntity in m["entities"]:
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
	if not e.eggs_ready and e.aggro_target < 0 and not e.monster_def.eggs.is_empty():
		ensure_eggs(sim, e)
	var phases: Array = e.monster_def.phases
	while e.phase < phases.size() and e.hp / e.stats.max_hp <= float(phases[e.phase]["hp"]):
		var ph: Dictionary = phases[e.phase]
		e.phase += 1
		if ph.has("say"):
			boss_say(sim, e, str(ph["say"]))
		sim._add_skills(e, ph.get("skills", []))
		BossSignatures.arm(e, ph.get("skills", []), Balance.BOSS_SIG_PHASE_DELAY)     # assinatura que chega com a fase
		if ph.has("ward"):
			e.ward_base = float(ph["ward"])
			e.ward_t = 0.0
		if ph.has("summon"):
			spawn_adds(sim, e, ph["summon"])
		if ph.has("hatch"):
			hatch(sim, e, float(ph["hatch"]))
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
	e.crowd_t -= dt
	if e.crowd_t <= 0.0 and e.aggro_target >= 0:
		e.crowd_t = Balance.BOSS_CROWD_CHECK
		var n := crowd_of(sim, e)
		if n != e.crowd:
			e.crowd = n
			e.crowd_mult = crowd_mult(n, e.monster_def.id)
			_apply_fury(e)
			if n > e.crowd_peak and e.crowd_mult > 1.0:
				boss_say(sim, e, "Tantos contra mim? Fico mais forte contra o grupo!")
				print_verbose("crowd %s: %d lutando, dano x%s" % [e.monster_def.id, n, String.num(e.crowd_mult, 1)])   # número só no log (--verbose)
			e.crowd_peak = maxi(e.crowd_peak, n)
			_crowd_skills(sim, e)
	if e.ward_base > 0.0:
		e.ward_t -= dt
		if e.ward_t <= 0.0:
			e.ward_t = Balance.BOSS_WARD_CHECK
			e.ward = e.ward_base if adds_alive(sim, e) > 0 else 0.0
		if e.ward > 0.0:
			e.put_buff({"id": "boss_ward", "remaining": Balance.BOSS_WARD_CHECK + 0.2})
		else:
			e.drop_buff("boss_ward")
	BossSignatures.update(sim, e, dt)

## Fúria = fúria da fase × enlouquecer por tempo × gente lutando contra (um não apaga o outro).
static func _apply_fury(e: SimEntity) -> void:
	e.dmg_mult = e.enrage_mult * (berserk_mult(e.monster_def) if e.berserk else 1.0) * e.crowd_mult * BossSignatures.fury_mult(e)
	e.recompute_stats()

## Dano a mais do chefe enlouquecido: MonsterDef.berserk_mult do chefe, senão Balance.BOSS_BERSERK_MULT.
static func berserk_mult(d: MonsterDef) -> float:
	return d.berserk_mult if d != null and d.berserk_mult > 0.0 else Balance.BOSS_BERSERK_MULT

## Quantos lutam contra o chefe: personagens vivos a até BOSS_CROWD_RANGE m que já o atingiram (ameaça) e os
## companheiros de grupo deles (quem só cura conta; quem só passa perto, não). Máximo PARTY_MAX.
static func crowd_of(sim: WorldSim, boss: SimEntity) -> int:
	if not sim.maps.has(boss.map_id):
		return 0
	var parties := {}
	var hit := {}
	for id in boss.threat:
		var o: SimEntity = sim.entities.get(id)
		if o and o.is_character():
			hit[id] = true
			if o.party_id >= 0:
				parties[o.party_id] = true
	var n := 0
	var r2 := Balance.BOSS_CROWD_RANGE * Balance.BOSS_CROWD_RANGE
	for o: SimEntity in sim.maps[boss.map_id]["entities"]:          # 1×/s por chefe: a lista completa (a "chars" é do tick)
		if o.kind == SimEntity.Kind.MONSTER or o.position.distance_squared_to(boss.position) > r2 or not o.is_character() or not o.is_alive():
			continue
		if hit.has(o.id) or (o.party_id >= 0 and parties.has(o.party_id)):
			n += 1
	return mini(n, Balance.PARTY_MAX)

## Dano do chefe por quem luta contra ele (Balance.BOSS_CROWD_MULT por número de pessoas). Chefe em BOSS_CROWD_EXTRA
## ganha mais × a partir de BOSS_CROWD_EXTRA_FROM pessoas (solo e trio intactos).
static func crowd_mult(n: int, boss_id: String = "") -> float:
	if Balance.BOSS_CROWD_RAID.has(boss_id):         # chefe de raide: tabela própria
		var raid: Array = Balance.BOSS_CROWD_RAID[boss_id]
		return float(raid[clampi(n, 0, raid.size() - 1)])
	var k := float(Balance.BOSS_CROWD_MULT[clampi(n, 0, Balance.BOSS_CROWD_MULT.size() - 1)])
	if n >= Balance.BOSS_CROWD_EXTRA_FROM and Balance.BOSS_CROWD_EXTRA.has(boss_id):
		k *= float(Balance.BOSS_CROWD_EXTRA[boss_id])
	return k

## Lacaios vivos deste chefe.
static func adds_alive(sim: WorldSim, boss: SimEntity) -> int:
	if not sim.maps.has(boss.map_id):
		return 0
	var n := 0
	for o: SimEntity in sim.maps[boss.map_id]["entities"]:
		if o.boss_id == boss.id and o.is_alive() and not o.monster_def.egg:     # ovo não segura o escudo da fase
			n += 1
	return n

## Ninho (MonsterDef.eggs): põe os ovos que faltam num anel em volta do ponto de nascer do chefe, fora de luta. Os ovos são
## lacaios dele (somem quando ele morre ou reseta; voltam inteiros com ele).
static func ensure_eggs(sim: WorldSim, boss: SimEntity) -> void:
	var ed: Dictionary = boss.monster_def.eggs
	var mdef: MonsterDef = GameData.monsters.get(str(ed.get("id", "")))
	boss.eggs_ready = true
	if mdef == null or not sim.maps.has(boss.map_id):
		return
	var have := eggs_of(sim, boss).size()
	var n := int(ed.get("count", 0))
	var r := float(ed.get("r", 6.0))
	for i in range(have, n):
		var a := TAU * float(i) / maxf(1.0, float(n)) + 0.3
		var egg := sim.spawn_monster(mdef, boss.map_id, boss.home_position + Vector3(cos(a), 0, sin(a)) * r)
		egg.boss_id = boss.id
		egg.adds_epoch = boss.adds_epoch

## Ovos inteiros deste chefe.
static func eggs_of(sim: WorldSim, boss: SimEntity) -> Array:
	var out: Array = []
	for o: SimEntity in sim.maps[boss.map_id]["entities"]:
		if o.boss_id == boss.id and o.adds_epoch == boss.adds_epoch and o.is_alive() and o.monster_def.egg:
			out.append(o)
	return out

## Fase com "hatch": a fração `frac` dos ovos inteiros (arredonda para cima) choca: o ovo some e um filhote
## (MonsterDef.eggs["hatch"], padrão dragon_whelp) nasce no lugar, já na luta.
static func hatch(sim: WorldSim, boss: SimEntity, frac: float) -> void:
	var eggs := eggs_of(sim, boss)
	var into: MonsterDef = GameData.monsters.get(str(boss.monster_def.eggs.get("hatch", "dragon_whelp")))
	if eggs.is_empty() or into == null:
		return
	var n := mini(eggs.size(), int(ceil(eggs.size() * clampf(frac, 0.0, 1.0))))
	for i in range(n):
		var egg: SimEntity = eggs[i]
		var pos := egg.position
		sim.despawn(egg)
		var w := sim.spawn_monster(into, boss.map_id, pos)
		w.boss_id = boss.id
		w.adds_epoch = boss.adds_epoch
		w.aggro_target = boss.aggro_target
		w.aggro_timer = Balance.AGGRO_LOSE_TIME
	Events.post(&"boss_hatch", boss.id, n)
	if sim.player and sim.player.map_id == boss.map_id:
		Events.post(&"notification", "%d ovo%s chocou!" % [n, "" if n == 1 else "s"])

## Chefe volta ao estado inicial depois de um wipe ou de ser puxado longe demais.
static func reset_boss(sim: WorldSim, e: SimEntity) -> void:
	ShiftSystem.revert(sim, e)
	e.phase = 0
	e.boss_spoke = false
	e.dmg_mult = 1.0
	e.enrage_mult = 1.0
	e.berserk = false
	e.fight_time = 0.0
	e.ward_base = 0.0
	e.ward = 0.0
	e.ward_t = 0.0
	e.crowd = 0
	e.crowd_mult = 1.0
	e.crowd_t = 0.0
	e.crowd_peak = 0
	e.adds_epoch += 1
	e.eggs_ready = false                         # ovos de antes somem com a época; o ninho volta inteiro
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
	BossSignatures.reset(sim, e)                 # marcas, canal, sequência, Muralha, Têmpera, pedregulhos (AC-S4)
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
	for o: SimEntity in m.get("chars", m["entities"]):
		if o == boss or not o.is_alive() or o.map_id != boss.map_id or o.position.distance_squared_to(boss.position) > d2:
			continue
		if o.kind == SimEntity.Kind.MONSTER or not boss.is_hostile_to(o) or o.stealth_left > 0.0 or o.sky_left > 0.0 or o.is_perched():
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
	match str(bd.get("shape", "circle")):         # R-A: faixas e anéis (BossSignatures)
		"line":
			BossSignatures.place_lines(sim, e, s, aim, power, bd, fx)
			return
		"ring":
			BossSignatures.place_rings(sim, e, s, power, bd, fx)
			return
	var spots: Array = [Vector3(aim.x, 0, aim.z)]
	if bd.get("on_self", false):                    # Têmpera na Lava: o 1º círculo (poça) cai embaixo do chefe
		spots = [Vector3(e.position.x, 0, e.position.z)]
	if bd.has("say"):
		boss_say(sim, e, str(bd["say"]))
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
	var cover: bool = not e.monster_def.cover.is_empty() and s.id in e.monster_def.cover.get("skills", [])
	var extra := BossSignatures.barrage_extra(bd)
	if extra.has("empower"):
		BossSignatures.stat(sim, "temper_uses")         # sonda: Têmpera na Lava lançada
	for i in range(spots.size()):
		var p: Vector3 = spots[i]
		var h := {"owner": e.id, "pos": p, "radius": r, "at": sim.time + delay, "power": power, "kind": s.kind, "effects": fx, "skill": s.id}
		h.merge(extra)
		if cover and i == spots.size() - 1:
			h["cover"] = true                         # Troll Rei: o último círculo (em volta dele) deixa um pedregulho (R-E)
		BossSignatures.add_hazard(m, h, sim.time)
		Events.post(&"hazard_placed", e.map_id, p, r, delay, s.id)

## Círculos de chefe: caem na hora marcada (dano + efeito em quem ficou dentro); somem se o dono morreu ou saiu.
## Formas, ilhas, marcas e chão que fica: BossSignatures.update_hazards.
static func update_hazards(sim: WorldSim, m: Dictionary) -> void:
	BossSignatures.update_hazards(sim, m)

## Queimando ou envenenado (F3): qualquer dano no tempo que não seja sangramento.
static func regen_blocked(e: SimEntity) -> bool:
	for d in e.debuffs:
		if d.get("kind") == "dot" and not d.get("bleed", false):
			return true
	return false

## Regeneração do troll (F3): MonsterDef.regen × TROLL_REGEN_PCT × vida máxima por segundo, em luta ou não. Fogo/veneno
## param (uma vez só, mesmo juntos) e ela volta TROLL_REGEN_LINGER s depois do último efeito acabar. Enquanto cura, o
## troll leva o buff TROLL_REGEN_BUFF (brilho verde); ele some quando a regeneração para.
static func update_regen(sim: WorldSim, e: SimEntity, dt: float) -> void:
	var t := dt                          # parte do passo em que ele regenera
	if regen_blocked(e):
		e.regen_hold = Balance.TROLL_REGEN_LINGER
		t = 0.0
	elif e.regen_hold > 0.0:
		var used := minf(e.regen_hold, dt)
		e.regen_hold -= used
		t = dt - used
	var healing: bool = t > 0.0 and e.hp < e.stats.max_hp
	if healing:
		e.hp = minf(e.stats.max_hp, e.hp + e.stats.max_hp * Balance.TROLL_REGEN_PCT * e.monster_def.regen * t)
	var lit: bool = e.buff_stacks(Balance.TROLL_REGEN_BUFF) > 0
	if healing and not lit:
		e.put_buff({"id": Balance.TROLL_REGEN_BUFF, "remaining": 1.0e9, "stacks": 1})
		Events.post(&"buff_applied", e.id, Balance.TROLL_REGEN_BUFF, 0.0)
	elif lit and not healing:
		e.drop_buff(Balance.TROLL_REGEN_BUFF)

## Grito de guerra (efeito "rally"): quem lança e os monstros vivos da mesma facção a `radius` m ganham o buff (renova
## pelo id, não soma com outro grito). Só buff marcado `mob_stat` mexe nos atributos do monstro.
static func rally(sim: WorldSim, e: SimEntity, d: Dictionary) -> void:
	if e.monster_def == null or not sim.maps.has(e.map_id):
		return
	var r2: float = float(d.get("radius", 9.0)) * float(d.get("radius", 9.0))
	var dur: float = float(d.get("duration", 8.0))
	var bid: String = str(d.get("id", "war_cry"))
	for t in sim.maps[e.map_id]["entities"]:
		if t.kind != SimEntity.Kind.MONSTER or not t.is_alive() or t.position.distance_squared_to(e.position) > r2:
			continue
		if t != e and (e.monster_def.faction == "" or t.monster_def.faction != e.monster_def.faction):
			continue
		t.put_buff({"id": bid, "remaining": dur, "duration": dur, "atk_pct": float(d.get("atk_pct", 0.0)), "aspd_pct": float(d.get("aspd_pct", 0.0)),
			"speed_pct": float(d.get("speed_pct", 0.0)), "mob_stat": true})
		t.recompute_stats()
		Events.post(&"buff_applied", t.id, bid, dur)

## Boneco de treino (MonsterDef.dummy): DUMMY_REGEN_DELAY s sem levar dano = recompõe a vida (DUMMY_REGEN_PCT da máxima
## por s), solta os debuffs e volta ao lugar (empurrão/puxão de skill o tira dali).
static func update_dummy(sim: WorldSim, e: SimEntity, dt: float) -> void:
	if sim.time - e.hurt_at < Balance.DUMMY_REGEN_DELAY:
		return
	if e.hp < e.stats.max_hp:
		e.hp = minf(e.stats.max_hp, e.hp + e.stats.max_hp * Balance.DUMMY_REGEN_PCT * dt)
	if not e.debuffs.is_empty() and e.hp >= e.stats.max_hp:
		e.debuffs.clear()
	e.aggro_target = -1
	e.threat.clear()
	if e.position.distance_squared_to(e.home_position) > 0.0001:
		e.position = e.home_position

static func update_spawners(sim: WorldSim, m: Dictionary, dt: float) -> void:
	var def: MapDef = m["def"]
	var epoch := sim.despawn_epoch
	for sp in m["spawners"]:
		var sdef: Dictionary = sp["def"]
		if int(sp.get("epoch", -1)) != epoch:          # só depois de alguém sumir do mundo (era uma lista nova por spawner por tick)
			sp["epoch"] = epoch
			sp["alive"] = sp["alive"].filter(func(id): return sim.entities.has(id))
		if not sp.has("escort") and sp["alive"].size() >= int(sdef.get("count", 1)):
			continue                             # cheio e sem escolta: nada a fazer (o caso comum)
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
					if not mdef.escort.is_empty():         # líder novo: a escolta órfã (líder morto) some e nasce a dele
						var keep: Array = []
						for id in sp.get("escort", []):
							var old: SimEntity = sim.entities.get(id)
							if old == null:
								continue
							var ld: SimEntity = sim.entities.get(old.leader_id)
							if (ld == null or not ld.is_alive()) and old.aggro_target < 0:
								sim.despawn(old)
							else:
								keep.append(id)            # escolta de outro líder vivo do mesmo spawner (ou órfã em luta)
						sp["escort"] = keep
						spawn_escort(sim, mob, sp)
						sp["escort_t"] = Balance.ESCORT_RESPAWN
					if em is Array and em.size() >= 3:
						Events.post(&"monster_emerged", def.id, pos)
						if sim.player and sim.player.map_id == def.id and sp.get("primed", false):     # 1º enchimento (mapa carregando, jogador ainda de passagem): sem aviso
							Events.post(&"chat_message", "Sistema", "%s emerge da água!" % mob.monster_def.name, "system")
				if sp["alive"].size() >= int(sdef.get("count", 1)):
					sp["primed"] = true
				# enche rápido na 1ª vez (mapa recém-carregado) e quando esvazia; depois, um por vez no tempo de respawn
				sp["timer"] = float(sdef.get("respawn", 10.0)) if sp["alive"].size() > 0 and sp["primed"] else 0.5

## Mecânica de grupo grande (MonsterDef.crowd_skills): entra quando o PICO da luta chega a BOSS_CROWD_EXTRA_FROM e fica até o reset
## (a 1ª morte do grupo não a desliga, ao contrário do reforço de dano, que segue quem está vivo).
static func _crowd_skills(sim: WorldSim, e: SimEntity) -> void:
	var ids: Array[String] = e.monster_def.crowd_skills
	if ids.is_empty() or e.crowd_peak < Balance.BOSS_CROWD_EXTRA_FROM:
		return
	var s: SkillDef = GameData.skills.get(ids[0])
	if s == null or s in e.skills:
		return
	sim._add_skills(e, ids)
	if e.monster_def.crowd_say != "":
		boss_say(sim, e, e.monster_def.crowd_say)

# ---------------------------------------------------------------------------
# Casulo de Seda (efeito "cocoon"): prende um inimigo num lacaio-casulo do chefe
# ---------------------------------------------------------------------------

## Envolve `t`: atordoado até o casulo (monstro `id`, lacaio de `src`) cair; esgotado o tempo, aperta (burst × vida máxima).
static func cocoon(sim: WorldSim, src: SimEntity, t: SimEntity, cd: Dictionary) -> void:
	if not t.is_character() or not t.is_alive() or t.has_debuff("cocoon") or not sim.maps.has(t.map_id):
		return
	var mdef: MonsterDef = GameData.monsters.get(str(cd.get("id", "web_cocoon")))
	if mdef == null:
		return
	var dur := float(cd.get("duration", Balance.COCOON_TIME))
	var add := sim.spawn_monster(mdef, t.map_id, t.position)
	add.boss_id = src.id if src.monster_def and src.monster_def.is_boss else -1
	add.adds_epoch = src.adds_epoch
	add.aggro_target = t.id
	add.aggro_timer = Balance.AGGRO_LOSE_TIME
	t.is_blocking = false
	t.current_skill = null
	t.velocity = Vector3.ZERO
	t.set_state(SimEntity.State.STUNNED, dur)
	t.debuffs.append({"kind": "cocoon", "remaining": dur + 1.0, "add": add.id, "src": src.id, "burst": float(cd.get("burst", Balance.COCOON_BURST))})
	if sim.player and sim.player.map_id == t.map_id:
		Events.post(&"notification", "%s foi envolvido num casulo! Quebrem o casulo." % t.name)

## Vítima presa (estado STUNNED com debuff "cocoon"): casulo quebrado solta; tempo esgotado com o casulo inteiro aperta e solta.
static func cocoon_tick(sim: WorldSim, t: SimEntity) -> void:
	var d: Dictionary = {}
	for x in t.debuffs:
		if x.get("kind") == "cocoon":
			d = x
			break
	if d.is_empty():
		return
	var add: SimEntity = sim.entities.get(int(d["add"]))
	var broken := add == null or not add.is_alive()
	if not broken and t.state_time < t.state_duration:
		return
	t.debuffs.erase(d)
	if not broken:
		var src: SimEntity = sim.entities.get(int(d["src"]))
		sim.despawn(add)
		var dmg := int(round(t.stats.max_hp * float(d["burst"])))
		sim._deal_damage(src if src else t, t, dmg, false, false, "dot_cocoon")
	t.set_state(SimEntity.State.IDLE)

## Casulo de um aliado (vivo, segurando alguém do grupo) a até `max_d` m de `e`.
static func cocoon_of(sim: WorldSim, e: SimEntity, members: Array, max_d: float) -> SimEntity:
	for o in members:
		if o == e or o.map_id != e.map_id or o.debuffs.is_empty():
			continue
		for d in o.debuffs:
			if d.get("kind") == "cocoon":
				var add: SimEntity = sim.entities.get(int(d["add"]))
				if add and add.is_alive() and add.position.distance_to(e.position) <= max_d:
					return add
	return null
