class_name GvgBrain
extends RefCounted
## Guerra de Guildas: inteligência dos bots (design/gdd/guerra-de-guildas.md §3.6; contrato wave6 §3).
## Por cima do BotBrain: escolhe papel, objetivo, alvo e lugar; a luta (skills, poções, kiting, cura) é a do BotBrain
## (`_fight`, `_heal_party`, `_steer`). Entradas:
##   `think(sim, e, brain, m, cmd, dt)` — chamado pelo BotBrain._think de todo bot da guerra (in_war), 20 Hz;
##   `commander_tick(sim, side)` — 1 Hz por lado (GvgSystem chama; o think também, com trava de 1 s): plano do começo
##   pela personalidade da guilda, gatilhos de troca, falas no chat (lado do jogador = "guild"; o outro vaza em "war").
## Estado: `sim.gvg["ai"]` (criado aqui; some com a guerra) e `brain.war` por bot (papel, vaga, canhão, recuo).
## Ordens do jogador (`sides[S].order` = {id, target, from_id, until}) valem por cima do plano até `until`.
## Números só em Balance.GVG_AI_* (e os GVG_* da sim, lidos por `_bal`). Sem alocação por tick nos laços quentes.

const SIDES := ["N", "S"]
const GVG_SYSTEM_PATH := "res://core/sim/systems/gvg_system.gd"

static var _gs: Script = null
static var _gs_methods: Dictionary = {}
static var _gs_tried := false

# ---------------------------------------------------------------------------
# ENTRADA

## O bot `e` está numa guerra em andamento (preparo ou luta) no mapa dela?
static func in_war(sim, e: SimEntity) -> bool:
	var g: Variant = sim.get("gvg")
	if not (g is Dictionary) or (g as Dictionary).is_empty():
		return false
	var gd: Dictionary = g
	if str(gd.get("map_id", e.map_id)) != e.map_id:
		return false
	var ph := str(gd.get("phase", ""))
	if ph != "prep" and ph != "fight":
		return false
	return side_of(sim, e) != ""

## Lado ("N" | "S") de `e` na guerra; "" = fora dela.
static func side_of(sim, e: SimEntity) -> String:
	var g: Dictionary = sim.gvg
	var ai := _ai(sim, g)
	return str((ai["side_of"] as Dictionary).get(e.id, ""))

## Papel ("muro" | "cura" | "artilharia" | "ponta" | "batedores") de `e` na guerra.
static func role_of(sim, e: SimEntity) -> String:
	var ai := _ai(sim, sim.gvg)
	return str((ai["role_of"] as Dictionary).get(e.id, ""))

static func think(sim, e: SimEntity, brain: BotBrain, m: Dictionary, cmd: InputCommand, dt: float) -> InputCommand:
	var g: Dictionary = sim.gvg
	var ai := _ai(sim, g)
	var w := brain.war
	if not is_same(w.get("ai"), ai):
		w.clear()
		w["ai"] = ai
		w["side"] = str((ai["side_of"] as Dictionary).get(e.id, ""))
		w["role"] = str((ai["role_of"] as Dictionary).get(e.id, "ponta"))
		w["slot"] = int((ai["slot_of"] as Dictionary).get(e.id, 0))
		w["cannon"] = -1
		w["low"] = false
		w["goal"] = ""
	var side: String = w["side"]
	commander_tick(sim, side)
	brain.cur_def = m["def"]
	brain.cur_sim = sim
	var attack: bool = side == str(g.get("attacker", "S"))
	cmd.aim = e.position + e.forward() * 2.0
	if str(g.get("phase", "")) != "fight":
		cmd.move = Vector2.ZERO           # preparo: o GvgSystem segura cada um perto do renascer
		return cmd
	# pouca vida sem poção pronta: recua para a cura (ou o renascer) até GVG_AI_BACK_HP
	if bool(w["low"]):
		if e.hp >= e.stats.max_hp * Balance.GVG_AI_BACK_HP:
			w["low"] = false
	elif e.hp < e.stats.max_hp * Balance.GVG_AI_LOW_HP and e.potion_cds[0] > 0.0 and str(w["role"]) != "cura":
		w["low"] = true
		_leave_cannon(sim, e, w)
	if bool(w["low"]):
		var heal := _nearest_role(sim, ai, side, "cura", e.position, e)
		var to: Vector3 = heal.position if heal != null else _point(sim, ai, "spawn", side)
		_walk(e, brain, to, cmd, dt)
		return cmd
	var goal := goal_of(sim, e, w)
	w["goal"] = str(goal.get("goal", ""))
	return _pursue(sim, e, brain, m, ai, g, w, side, attack, goal, cmd, dt, 0)

# ---------------------------------------------------------------------------
# OBJETIVO

## Objetivo de agora do bot: ordem do lado (se valendo) ou o do papel no plano. {"goal", "alt"?, "at"?}.
static func goal_of(sim, e: SimEntity, w: Dictionary) -> Dictionary:
	var g: Dictionary = sim.gvg
	var sd: Dictionary = (g.get("sides", {}) as Dictionary).get(str(w["side"]), {})
	var od: Dictionary = sd.get("order", {}) if sd.get("order") is Dictionary else {}
	if not od.is_empty() and float(od.get("until", 0.0)) > sim.time:
		var og := GvgCatalog.order_goal(str(od.get("id", "")), str(w["role"]))
		if not og.is_empty():
			return og
	var plan := str(sd.get("plan", ""))
	var pg := GvgCatalog.role_goal(plan, str(w["role"]))
	if pg.is_empty():
		pg = GvgCatalog.role_goal("martelo" if str(w["side"]) == str(g.get("attacker", "S")) else "muralha", str(w["role"]))
	# castelo aberto: quem ataca larga o morro/canhão do plano e corre ao Cristal (os planos lentos não olham o portão caído)
	if str(w["side"]) == str(g.get("attacker", "S")) and str(pg.get("goal", "")) in GvgCatalog.OPEN_GATE_GOALS:
		var ai: Dictionary = w["ai"]
		var foe := _other(str(w["side"]))
		if _gate_ent(sim, ai, foe, "main") == null or _gate_ent(sim, ai, foe, "side") == null:
			return {"goal": "crystal"}
	return pg

## Resolve o objetivo e age. `depth` evita laço no reserva (alt).
static func _pursue(sim, e: SimEntity, brain: BotBrain, m: Dictionary, ai: Dictionary, g: Dictionary, w: Dictionary, side: String,
		attack: bool, goal: Dictionary, cmd: InputCommand, dt: float, depth: int) -> InputCommand:
	var gid := str(goal.get("goal", "gate_main"))
	var foe := _other(side)
	var def_side := foe if attack else side           # castelo em jogo
	var point := Vector3.INF
	var objective: SimEntity = null
	var leash := Balance.GVG_AI_LEASH
	var hunt := false
	var anchor := Vector3.INF
	var fail := false
	if not gid.begins_with("cannon"):
		_leave_cannon(sim, e, w)
	match gid:
		"ram":
			var ram := _ram_for(sim, ai, side, w) if attack else null
			if ram == null:
				if not attack:
					return _pursue(sim, e, brain, m, ai, g, w, side, attack, {"goal": "sally"}, cmd, dt, depth + 1)
				fail = true
			else:
				var gate := _gate_pos(sim, ai, def_side, "main")
				var ahead := Vector3(gate.x - ram.position.x, 0.0, gate.z - ram.position.z)
				var dirv := ahead.normalized() if ahead.length() > 0.5 else Vector3.FORWARD
				var a := float(int(w["slot"]) % 6) * 1.05 + 0.5
				point = ram.position + dirv.rotated(Vector3.UP, PI * 0.5 + a) * (ram.radius + Balance.GVG_AI_RAM_SLOT)
				anchor = ram.position
				leash = Balance.GVG_AI_RAM_LEASH
				if ram.position.distance_to(gate) < ram.radius + 4.0:
					objective = _gate_ent(sim, ai, def_side, "main")
		"gate_main", "gate_side":
			var which := "main" if gid == "gate_main" else "side"
			var gate_e := _gate_ent(sim, ai, def_side, which)
			if attack:
				if gate_e != null:
					objective = gate_e
					point = _gate_pos(sim, ai, def_side, which)
				else:
					objective = _crystal_ent(sim, ai, def_side)
					point = _point(sim, ai, "crystal", def_side)
			else:
				if gate_e == null:
					return _pursue(sim, e, brain, m, ai, g, w, side, attack, {"goal": "stair"}, cmd, dt, depth + 1)
				point = _inside(sim, ai, side, which, 4.0)
		"crystal", "stair":
			if attack:
				objective = _crystal_ent(sim, ai, def_side)
				point = _point(sim, ai, "crystal", def_side)
				if _gate_ent(sim, ai, def_side, "main") != null and _gate_ent(sim, ai, def_side, "side") != null:
					objective = _gate_ent(sim, ai, def_side, "main")     # ainda fechado: abre primeiro
					point = _gate_pos(sim, ai, def_side, "main")
			else:
				point = _point(sim, ai, gid, side)
				leash = 9.0 if gid == "stair" else Balance.GVG_AI_LEASH
		"wall":
			if attack:
				return _pursue(sim, e, brain, m, ai, g, w, side, attack, {"goal": "gate_main"}, cmd, dt, depth + 1)
			point = _inside(sim, ai, side, "main", 6.0)
		"sally":
			var er := _nearest_obj(sim, (ai["rams"] as Dictionary).get(foe, []), _gate_pos(sim, ai, side, "main"))
			if er == null or attack:
				return _pursue(sim, e, brain, m, ai, g, w, side, attack, {"goal": "wall" if not attack else "gate_main"}, cmd, dt, depth + 1)
			objective = er
			point = er.position
			leash = Balance.GVG_AI_LEASH + 6.0
		"hill":
			point = GvgCatalog.HILL
		"hunt":
			var at := str(goal.get("at", "gate_main"))
			var hram := _ram_for(sim, ai, side, w) if attack and at == "ram" else null
			if hram != null:
				anchor = hram.position          # caça perto do aríete e anda com ele (conta como quem empurra)
				if hram.position.distance_to(_gate_pos(sim, ai, def_side, "main")) < hram.radius + 4.0:
					objective = _gate_ent(sim, ai, def_side, "main")
				point = hram.position + Vector3(cos(float(int(w["slot"])) * 2.1), 0.0, sin(float(int(w["slot"])) * 2.1)) * (hram.radius + Balance.GVG_AI_RAM_SLOT)
			elif at == "hill":
				anchor = GvgCatalog.HILL
			elif attack:
				anchor = _gate_pos(sim, ai, def_side, "main") if _gate_ent(sim, ai, def_side, "main") != null else _point(sim, ai, "crystal", def_side)
			else:
				anchor = _inside(sim, ai, side, "main", -6.0)
			if point == Vector3.INF:
				point = anchor
			hunt = true
			leash = Balance.GVG_AI_HUNT
		"escort":
			var mur := _nearest_role(sim, ai, side, "muro", e.position, e)
			if mur == null:
				mur = _nearest_ally(sim, ai, side, e)
			if mur == null:
				point = _front(sim, g, ai, side, attack)
			else:
				var back := _point(sim, ai, "spawn", side) - mur.position
				back.y = 0.0
				point = mur.position + (back.normalized() if back.length() > 0.1 else Vector3.BACK) * 3.5
				anchor = mur.position
			if brain._heal_party(e, sim, (ai["allies"] as Dictionary)[side], cmd, dt):
				return cmd
		"leader":
			var sd: Dictionary = (g.get("sides", {}) as Dictionary).get(side, {})
			var od: Dictionary = sd.get("order", {}) if sd.get("order") is Dictionary else {}
			var who: SimEntity = sim.entities.get(int(od.get("from_id", -1)))
			if who == null or not who.is_alive():
				fail = true
			else:
				point = who.position
				anchor = who.position
				leash = 10.0
		"retreat":
			point = _point(sim, ai, "spawn" if attack else "stair", side)
		"cannon", "cannon_wall", "cannon_hill":
			var r := _cannon(sim, e, brain, m, ai, w, side, gid, cmd, dt)
			if r != null:
				return r
			fail = true
		_:
			fail = true
	if fail:
		var alt := str(goal.get("alt", ""))
		if depth < 3 and alt != "":
			return _pursue(sim, e, brain, m, ai, g, w, side, attack, {"goal": alt}, cmd, dt, depth + 1)
		if depth < 3 and gid != "gate_main":
			return _pursue(sim, e, brain, m, ai, g, w, side, attack, {"goal": "gate_main"}, cmd, dt, depth + 1)
		return cmd
	if anchor == Vector3.INF:
		anchor = point
	# briga: inimigo perto (e, na caça, canhoneiro/cura perto do ponto) que não puxa o bot para longe do ponto
	var foe_e := _pick_enemy(sim, e, ai, side, attack, anchor, leash, hunt)
	if foe_e != null and not _blocked(sim, e, foe_e):
		return brain._fight(e, sim, m, foe_e, cmd)
	if objective != null and objective.is_alive():
		if not _blocked(sim, e, objective):
			return brain._fight(e, sim, m, objective, cmd)
		point = objective.position
	# perto do aríete o ponto já é a vaga (a GVG_AI_RAM_SLOT do casco): espalhar mais tira o bot do raio de empurrar
	var near_ram := gid == "ram" or (gid == "hunt" and str(goal.get("at", "")) == "ram" and attack and _ram_for(sim, ai, side, w) != null)
	_walk(e, brain, _slot_point(point, w, Balance.GVG_AI_RAM_SPREAD if near_ram else Balance.GVG_AI_HOLD_R), cmd, dt)
	return cmd

## Há muro entre `e` e `t` (o caminho da sim desvia) e `t` está longe? Então anda pelo caminho em vez de brigar em linha reta.
static func _blocked(sim, e: SimEntity, t: SimEntity) -> bool:
	if e.position.distance_to(t.position) <= Balance.GVG_AI_BLOCKED_NEAR + t.radius:
		return false
	var wp: Vector3 = _gs_call("waypoint", [sim, e, t.position], t.position)
	return wp.distance_squared_to(t.position) > 0.25

## Inimigo para brigar agora: a até GVG_AI_ENGAGE m de mim e a até `leash` do `anchor`. Caça (`hunt`): canhoneiro e
## cura inimigos perto do `anchor` vêm antes de quem está perto. Quem está dentro do castelo inimigo fechado não conta.
static func _pick_enemy(sim, e: SimEntity, ai: Dictionary, side: String, attack: bool, anchor: Vector3, leash: float, hunt: bool) -> SimEntity:
	var foe := _other(side)
	var ids: Array = (ai["ids"] as Dictionary).get(foe, [])
	var ops: Dictionary = ai["operators"]
	var roles: Dictionary = ai["role_of"]
	var closed := attack and _gate_ent(sim, ai, foe, "main") != null and _gate_ent(sim, ai, foe, "side") != null
	var best: SimEntity = null
	var best_s := INF
	var eng2 := Balance.GVG_AI_ENGAGE * Balance.GVG_AI_ENGAGE
	var l2 := leash * leash
	for id in ids:
		var o: SimEntity = sim.entities.get(id)
		if o == null or not o.is_alive() or o.map_id != e.map_id or o.stealth_left > 0.0:
			continue
		var d2 := o.position.distance_squared_to(e.position)
		var a2 := o.position.distance_squared_to(anchor)
		var prio := ops.has(o.id) or str(roles.get(o.id, "")) == "cura"
		if a2 > l2 or (d2 > eng2 and not (hunt and prio)):
			continue
		if closed and _in_castle(o.position, foe):
			continue
		var s := sqrt(d2) - (12.0 if hunt and prio else 0.0) - (3.0 if o.id == e.last_damage_from else 0.0)
		if s < best_s:
			best_s = s
			best = o
	return best

# ---------------------------------------------------------------------------
# CANHÃO

## Vai até um canhão livre do tipo `gid` e opera: mira em aríete (à frente dele pelo aviso) > canhoneiro > portão
## (atacante) > bolo de inimigos. null = nenhum canhão serve (o chamador usa o reserva).
static func _cannon(sim, e: SimEntity, brain: BotBrain, m: Dictionary, ai: Dictionary, w: Dictionary, side: String, gid: String,
		cmd: InputCommand, dt: float) -> InputCommand:
	var c: Dictionary = _cannon_by_id(ai, int(w["cannon"]))
	if c.is_empty() or not _cannon_fits(c, side, gid) or not _cannon_free(sim, ai, c, e):
		_leave_cannon(sim, e, w)
		c = _pick_cannon(sim, ai, e, side, gid)
		if c.is_empty():
			return null
		w["cannon"] = int(c["id"])
		(ai["claims"] as Dictionary)[int(c["id"])] = e.id
	var ce: SimEntity = sim.entities.get(int(c["id"]))
	var cpos: Vector3 = ce.position if ce != null else c.get("pos", e.position)
	# alguém batendo em mim colado: larga e briga
	var hit_by: SimEntity = sim.entities.get(e.last_damage_from)
	if hit_by != null and hit_by.is_alive() and e.combat_timer > 0.0 and e.is_hostile_to(hit_by) and hit_by.position.distance_to(e.position) < Balance.GVG_AI_CANNON_PEEL:
		_leave_cannon(sim, e, w)
		return brain._fight(e, sim, m, hit_by, cmd)
	var use_r: float = _bal("GVG_CANNON_USE_R", Balance.GVG_AI_CANNON_USE_R)
	if not _operating(sim, c, e):
		if e.position.distance_to(cpos) > use_r * 0.8:
			_walk(e, brain, cpos, cmd, dt)
			return cmd
		var err := str(_gs_call("cannon_use", [sim, e, int(c["id"])], "x"))
		if err != "":
			(ai["claims"] as Dictionary).erase(int(c["id"]))
			w["cannon"] = -1
			return null if err != "x" else cmd
	var aim := cannon_aim(sim, side, cpos)
	cmd.move = Vector2.ZERO
	if aim != Vector3.INF:
		cmd.aim = aim
		cmd.attack = true
	return cmd

## Ponto de mira do canhão do lado `side` em `cpos` (Vector3.INF = nada no alcance). Aríete inimigo mais perto do nosso
## portão, guiado pela velocidade × aviso do tiro; depois canhoneiro inimigo, portão inimigo (só quem ataca) e o maior
## bolo de inimigos (≥ 2 a GVG_AI_CANNON_CLUSTER m). Pura (lê a sim), sem alocar.
static func cannon_aim(sim, side: String, cpos: Vector3) -> Vector3:
	var g: Dictionary = sim.gvg
	var ai := _ai(sim, g)
	var foe := _other(side)
	var attack: bool = side == str(g.get("attacker", "S"))
	var rng_r: float = _bal("GVG_CANNON_RANGE", Balance.GVG_AI_CANNON_RANGE)
	var warn: float = _bal("GVG_CANNON_WARN", Balance.GVG_AI_CANNON_WARN)
	var r2 := rng_r * rng_r
	var home := _gate_pos(sim, ai, side, "main")
	var best := Vector3.INF
	var best_d := INF
	for id in (ai["rams"] as Dictionary).get(foe, []):
		var ram: SimEntity = sim.entities.get(id)
		if ram == null or not ram.is_alive():
			continue
		var lead := ram.position + Vector3(ram.velocity.x, 0.0, ram.velocity.z) * warn
		if lead.distance_squared_to(cpos) > r2:
			continue
		var d := lead.distance_squared_to(home)
		if d < best_d:
			best_d = d
			best = lead
	if best != Vector3.INF:
		return best
	for oid in ai["operators"]:
		var op: SimEntity = sim.entities.get(oid)
		if op == null or not op.is_alive() or str((ai["side_of"] as Dictionary).get(oid, "")) != foe:
			continue
		var d := op.position.distance_squared_to(cpos)
		if d <= r2 and d < best_d:
			best_d = d
			best = op.position
	if best != Vector3.INF:
		return best
	if attack:
		for which in ["main", "side"]:
			var ge := _gate_ent(sim, ai, foe, which)
			if ge != null and ge.position.distance_squared_to(cpos) <= r2:
				return ge.position
	var ids: Array = (ai["ids"] as Dictionary).get(foe, [])
	var c2 := Balance.GVG_AI_CANNON_CLUSTER * Balance.GVG_AI_CANNON_CLUSTER
	var best_n := 1
	for id in ids:
		var o: SimEntity = sim.entities.get(id)
		if o == null or not o.is_alive() or o.position.distance_squared_to(cpos) > r2:
			continue
		var n := 0
		for id2 in ids:
			var o2: SimEntity = sim.entities.get(id2)
			if o2 != null and o2.is_alive() and o2.position.distance_squared_to(o.position) <= c2:
				n += 1
		if n > best_n:
			best_n = n
			best = o.position
	return best

static func _cannon_fits(c: Dictionary, side: String, gid: String) -> bool:
	var hill: bool = c["hill"]
	if gid == "cannon_hill":
		return hill
	if gid == "cannon_wall":
		return not hill and str(c["side"]) == side
	return hill or str(c["side"]) == side

static func _cannon_free(sim, ai: Dictionary, c: Dictionary, e: SimEntity) -> bool:
	var ce: SimEntity = sim.entities.get(int(c["id"]))
	if ce == null or not ce.is_alive():
		return false
	var op := int(c.get("operator_id", -1))
	if op >= 0 and op != e.id:
		var oe: SimEntity = sim.entities.get(op)
		if oe != null and oe.is_alive():
			return false
	var cl := int((ai["claims"] as Dictionary).get(int(c["id"]), -1))
	if cl >= 0 and cl != e.id:
		var ce2: SimEntity = sim.entities.get(cl)
		var cb: Variant = ce2.brain if ce2 != null else null
		if ce2 != null and ce2.is_alive() and cb is BotBrain and int((cb as BotBrain).war.get("cannon", -1)) == int(c["id"]):
			return false
	return true

static func _pick_cannon(sim, ai: Dictionary, e: SimEntity, side: String, gid: String) -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	for c: Dictionary in ai["cannons"]:
		if not _cannon_fits(c, side, gid) or not _cannon_free(sim, ai, c, e):
			continue
		var ce: SimEntity = sim.entities.get(int(c["id"]))
		var d := ce.position.distance_squared_to(e.position)
		if d < best_d:
			best_d = d
			best = c
	return best

static func _cannon_by_id(ai: Dictionary, id: int) -> Dictionary:
	if id < 0:
		return {}
	for c: Dictionary in ai["cannons"]:
		if int(c["id"]) == id:
			return c
	return {}

static func _operating(sim, c: Dictionary, e: SimEntity) -> bool:
	return int(c.get("operator_id", -1)) == e.id

static func _leave_cannon(sim, e: SimEntity, w: Dictionary) -> void:
	var cid := int(w.get("cannon", -1))
	if cid < 0:
		return
	var ai: Dictionary = w["ai"]
	if int((ai["claims"] as Dictionary).get(cid, -1)) == e.id:
		(ai["claims"] as Dictionary).erase(cid)
	var c := _cannon_by_id(ai, cid)
	if not c.is_empty() and int(c.get("operator_id", -1)) == e.id:
		_gs_call("cannon_leave", [sim, e], null)
	w["cannon"] = -1

# ---------------------------------------------------------------------------
# COMANDANTE

## Uma vez por segundo por lado (trava própria; `force` passa): plano do começo, gatilhos e falas.
static func commander_tick(sim, side: String, force: bool = false) -> void:
	var g: Variant = sim.get("gvg")
	if not (g is Dictionary) or (g as Dictionary).is_empty():
		return
	var gd: Dictionary = g
	var ai := _ai(sim, gd)
	var sa: Dictionary = (ai["sides"] as Dictionary).get(side, {})
	if sa.is_empty() or (not force and sim.time < float(sa["tick_at"])):
		return
	sa["tick_at"] = sim.time + 0.999
	_refresh(sim, gd, ai)
	var sd: Dictionary = (gd.get("sides", {}) as Dictionary).get(side, {})
	var attack: bool = side == str(gd.get("attacker", "S"))
	var pers := str(sd.get("personality", "equilibrada"))
	var phase := str(gd.get("phase", ""))
	if not GvgCatalog.plan_ok(attack, str(sd.get("plan", ""))):
		var plan := GvgCatalog.pick_start(attack, pers, sim.rng.randf())
		_set_plan(sim, gd, ai, side, plan, "start")
		_announce(sim, gd, ai, side, _line(sim, GvgCatalog.PLAN_LINES.get(plan, [])), plan, true)
	elif phase == "fight" and not bool(sd.get("player_commands", false)):
		_triggers(sim, gd, ai, side, attack, pers)
	_orders_seen(sim, gd, ai, side)
	_flush_chat(sim, gd, ai, side)

static func _triggers(sim, g: Dictionary, ai: Dictionary, side: String, attack: bool, pers: String) -> void:
	var sa: Dictionary = ai["sides"][side]
	var fired: Dictionary = sa["fired"]
	var def_side := _other(side) if attack else side
	var plan := str(((g.get("sides", {}) as Dictionary).get(side, {}) as Dictionary).get("plan", ""))
	for t: Dictionary in GvgCatalog.TRIGGERS:
		var tid := str(t["id"])
		if fired.has(tid):
			continue
		var cands: Array = t["attack"] if attack else t["defense"]
		if cands.is_empty():
			continue
		if tid != "gate_broken" and sim.time < float(sa["plan_at"]) + Balance.GVG_AI_PLAN_MIN_S:
			continue
		if not trigger_on(sim, g, ai, side, tid, def_side, plan):
			continue
		fired[tid] = sim.time
		var pool: Array = []
		for c in cands:
			if str(c) != plan:
				pool.append(c)
		var key := tid + ("_def" if not attack and GvgCatalog.TRIGGER_LINES.has(tid + "_def") else "")
		var text := _line(sim, GvgCatalog.TRIGGER_LINES.get(key, []))
		if pool.is_empty():
			_announce(sim, g, ai, side, text, plan, true)
			return
		var np := GvgCatalog.pick(pool, pers, sim.rng.randf())
		_set_plan(sim, g, ai, side, np, tid)
		_announce(sim, g, ai, side, "%s Plano %s!" % [text, GvgCatalog.plan_name(np)], np, true)
		return

## O gatilho `tid` vale agora para o lado `side` (castelo em jogo = `def_side`)? Pura sobre o estado.
static func trigger_on(sim, g: Dictionary, ai: Dictionary, side: String, tid: String, def_side: String, plan: String) -> bool:
	var attack := side != def_side
	match tid:
		"gate_broken":
			if attack:
				return _gate_ent(sim, ai, def_side, "main") == null or _gate_ent(sim, ai, def_side, "side") == null
			return _gate_ent(sim, ai, def_side, "main") == null
		"rams_lost":
			var rams: Array = (ai["rams"] as Dictionary).get(side, [])
			if rams.is_empty() or not bool(ai["rams_seen"].get(side, false)):
				return false
			for id in rams:
				var r: SimEntity = sim.entities.get(id)
				if r != null and r.is_alive():
					return false
			return true
		"gate_low":
			var ge := _gate_ent(sim, ai, def_side, "main")
			return ge != null and ge.hp < ge.stats.max_hp * Balance.GVG_AI_GATE_LOW
		"half_dead":
			var ids: Array = (ai["ids"] as Dictionary).get(side, [])
			var dead := 0
			for id in ids:
				var o: SimEntity = sim.entities.get(id)
				if o == null or not o.is_alive():
					dead += 1
			return not ids.is_empty() and float(dead) >= float(ids.size()) * Balance.GVG_AI_HALF_DEAD
		"hill_lost", "hill_won":
			if g.has("hill"):
				var holder := str(g["hill"])
				if tid == "hill_lost":
					return holder != "" and holder != side
				return plan == "bateria" and holder == side
			var mine := 0
			var theirs := 0
			var hills := 0
			for c: Dictionary in ai["cannons"]:
				if not bool(c["hill"]):
					continue
				hills += 1
				var op: SimEntity = sim.entities.get(int(c.get("operator_id", -1)))
				if op == null or not op.is_alive():
					continue
				if str((ai["side_of"] as Dictionary).get(op.id, "")) == side:
					mine += 1
				else:
					theirs += 1
			if tid == "hill_lost":
				return theirs > 0 and mine == 0
			return plan == "bateria" and hills > 0 and mine == hills
		"five_min":
			return float(g.get("time_left", 9999.0)) <= Balance.GVG_AI_FIVE_MIN
	return false

static func _set_plan(sim, g: Dictionary, ai: Dictionary, side: String, plan: String, reason: String) -> void:
	ai["sides"][side]["plan_at"] = sim.time
	if _gs_has("set_plan"):
		_gs_call("set_plan", [sim, side, plan, reason], null)
		var sd0: Dictionary = (g.get("sides", {}) as Dictionary).get(side, {})
		if str(sd0.get("plan", "")) == plan:
			return
	var sides: Dictionary = g.get_or_add("sides", {})
	var sd: Dictionary = sides.get_or_add(side, {})
	sd["plan"] = plan
	Events.post(&"gvg_plan_changed", side, plan, reason)

# ---------------------------------------------------------------------------
# CHAT (lado do jogador = "guild"; o outro lado vaza no "war" às vezes)

static func _announce(sim, g: Dictionary, ai: Dictionary, side: String, text: String, plan: String, important: bool) -> void:
	var sa: Dictionary = ai["sides"][side]
	if side == str(g.get("player_side", "S")):
		_queue_line(sa, _commander_name(sim, g, ai, side), text, "guild", important)
		sa["acks_left"] = 1 + sim.rng.randi() % maxi(1, Balance.GVG_AI_ACKS)
		sa["ack_at"] = sim.time + 1.6
		sa["ack_pool"] = GvgCatalog.ACK_LINES
	elif sim.rng.randf() < Balance.GVG_AI_OVERHEAR:
		_queue_line(sa, _commander_name(sim, g, ai, side), _line(sim, GvgCatalog.OVERHEARD.get(plan, [])), "war", false)

## Ordem nova do jogador no lado dele: alguém responde.
static func _orders_seen(sim, g: Dictionary, ai: Dictionary, side: String) -> void:
	var sd: Dictionary = (g.get("sides", {}) as Dictionary).get(side, {})
	var od: Dictionary = sd.get("order", {}) if sd.get("order") is Dictionary else {}
	var sa: Dictionary = ai["sides"][side]
	if od.is_empty():
		return
	var sig := "%s@%.2f" % [str(od.get("id", "")), float(od.get("until", 0.0))]
	if sig == str(sa["order_seen"]):
		return
	sa["order_seen"] = sig
	if side == str(g.get("player_side", "S")):
		sa["acks_left"] = 1
		sa["ack_at"] = sim.time + 0.8
		sa["ack_pool"] = GvgCatalog.ORDER_ACKS.get(str(od.get("id", "")), GvgCatalog.ACK_LINES)

static func _queue_line(sa: Dictionary, who: String, text: String, channel: String, important: bool) -> void:
	if text == "":
		return
	var q: Array = sa["queue"]
	if not important:
		if q.size() < 2:
			q.append([who, text, channel, important])
		return
	var at := 0
	while at < q.size() and bool(q[at][3]):
		at += 1
	q.insert(at, [who, text, channel, important])      # plano/gatilho fura a fila das comuns

## Solta a próxima fala do lado se o ritmo deixa (GVG_AI_CHAT_MIN entre quaisquer; GVG_AI_CHAT_GAP para as comuns).
static func _flush_chat(sim, g: Dictionary, ai: Dictionary, side: String) -> void:
	var sa: Dictionary = ai["sides"][side]
	var q: Array = sa["queue"]
	if q.is_empty() and int(sa["acks_left"]) > 0 and sim.time >= float(sa["ack_at"]):
		var who := _random_ally_name(sim, ai, side)
		sa["acks_left"] = int(sa["acks_left"]) - 1
		sa["ack_at"] = sim.time + 2.0
		if who != "":
			q.append([who, _line(sim, sa["ack_pool"]), "guild", false])
	if q.is_empty():
		return
	var it: Array = q[0]
	if not can_say(sim, sa, bool(it[3])):
		return
	q.pop_front()
	_say(sim, ai, sa, str(it[0]), str(it[1]), str(it[2]))

## Ritmo do chat do lado: true = pode falar agora (e não marca nada).
static func can_say(sim, sa: Dictionary, important: bool) -> bool:
	if sim.time < float(sa["any_at"]) + Balance.GVG_AI_CHAT_MIN:
		return false
	return important or sim.time >= float(sa["line_at"]) + Balance.GVG_AI_CHAT_GAP

static func _say(sim, ai: Dictionary, sa: Dictionary, who: String, text: String, channel: String) -> void:
	sa["any_at"] = sim.time
	sa["line_at"] = sim.time
	var log: Array = ai["log"]
	if log.size() >= 64:
		log.pop_front()
	log.append([sim.time, who, text, channel])
	Events.post(&"chat_message", who, text, channel)

static func _commander_name(sim, g: Dictionary, ai: Dictionary, side: String) -> String:
	var sd: Dictionary = (g.get("sides", {}) as Dictionary).get(side, {})
	var c: SimEntity = sim.entities.get(int(sd.get("commander_id", -1)))
	if c != null:
		return c.name
	for id in (ai["ids"] as Dictionary).get(side, []):
		var o: SimEntity = sim.entities.get(id)
		if o != null and o.kind == SimEntity.Kind.BOT:
			return o.name
	return "Comandante"

static func _random_ally_name(sim, ai: Dictionary, side: String) -> String:
	var ids: Array = (ai["ids"] as Dictionary).get(side, [])
	if ids.is_empty():
		return ""
	var start: int = sim.rng.randi() % ids.size()
	for k in ids.size():
		var o: SimEntity = sim.entities.get(ids[(start + k) % ids.size()])
		if o != null and o.kind == SimEntity.Kind.BOT and o.is_alive():
			return o.name
	return ""

static func _line(sim, pool: Array) -> String:
	return "" if pool.is_empty() else str(pool[sim.rng.randi() % pool.size()])

# ---------------------------------------------------------------------------
# ESTADO (sim.gvg["ai"])

static func _ai(sim, g: Dictionary) -> Dictionary:
	var ai: Dictionary = g.get("ai", {})
	if ai.is_empty():
		ai = {"refresh_at": -1.0, "side_of": {}, "role_of": {}, "slot_of": {}, "ids": {"N": [], "S": []}, "allies": {"N": [], "S": []},
			"gates": {}, "crystals": {}, "rams": {"N": [], "S": []}, "rams_seen": {}, "cannons": [], "operators": {}, "claims": {},
			"log": [], "sides": {}}
		for s in SIDES:
			ai["sides"][s] = {"tick_at": -1.0, "plan_at": -999.0, "fired": {}, "line_at": -999.0, "any_at": -999.0,
				"queue": [], "acks_left": 0, "ack_at": 0.0, "ack_pool": [], "order_seen": ""}
		g["ai"] = ai
		_assign(sim, g, ai)
		_refresh(sim, g, ai)
	return ai

## Lados e papéis (uma vez por guerra): papel da build -> papel da guerra, com teto de Batedores e de Artilharia.
static func _assign(sim, g: Dictionary, ai: Dictionary) -> void:
	var sides: Dictionary = g.get("sides", {})
	for s in SIDES:
		var sd: Dictionary = sides.get(s, {})
		var ids: Array = ai["ids"][s]
		ids.clear()
		var count := {}
		for id in sd.get("ids", []):
			var o: SimEntity = sim.entities.get(int(id))
			if o == null:
				continue
			ids.append(o.id)
			ai["side_of"][o.id] = s
			var r := war_role(sim, o)
			if r == "batedores" and int(count.get(r, 0)) >= Balance.GVG_AI_SCOUTS_MAX:
				r = "ponta"
			if r == "artilharia" and int(count.get(r, 0)) >= Balance.GVG_AI_ARTY_MAX:
				r = "ponta"
			ai["slot_of"][o.id] = int(count.get(r, 0))
			count[r] = int(count.get(r, 0)) + 1
			ai["role_of"][o.id] = r

## Papel da guerra pela build: tanque = Muro, cura = Cura, de longe = Artilharia, Assassino/Lanceiro = Batedores, resto Ponta.
static func war_role(sim, e: SimEntity) -> String:
	if e.class_def != null and (e.class_def.id in GvgCatalog.SCOUT_CLASSES or e.build_id in GvgCatalog.SCOUT_BUILDS):
		return "batedores"
	return str(GvgCatalog.ROLE_OF_BUILD_ROLE.get(sim.role_of(e), "ponta"))

## Objetos e aliados vivos (1 Hz): portões, cristais, aríetes, canhões e quem opera cada um.
static func _refresh(sim, g: Dictionary, ai: Dictionary) -> void:
	if sim.time < float(ai["refresh_at"]):
		return
	ai["refresh_at"] = sim.time + 0.999
	for s in SIDES:
		var al: Array = ai["allies"][s]
		al.clear()
		for id in ai["ids"][s]:
			var o: SimEntity = sim.entities.get(id)
			if o != null and o.is_alive():
				al.append(o)
	var objs: Array = _objects(sim, g)
	var gates: Dictionary = ai["gates"]
	var crystals: Dictionary = ai["crystals"]
	var cannons: Array = ai["cannons"]
	var ops: Dictionary = ai["operators"]
	ops.clear()
	if int(ai.get("obj_n", -1)) != objs.size():
		ai["obj_n"] = objs.size()
		gates.clear()
		crystals.clear()
		cannons.clear()
		(ai["rams"]["N"] as Array).clear()
		(ai["rams"]["S"] as Array).clear()
		for o: Dictionary in objs:
			var id := int(o.get("id", -1))
			var ent: SimEntity = sim.entities.get(id)
			var key := str(o.get("key", ""))
			var s := str(o.get("side", ""))
			if s == "" and ent != null and "gvg_side" in ent:
				s = str(ent.get("gvg_side"))
			match str(o.get("type", "")):
				"gate":
					gates[("side_" if key.contains("side") else "main_") + s] = id
				"crystal":
					crystals[s] = id
				"ram":
					(ai["rams"][s] as Array).append(id)
					ai["rams_seen"][s] = true
				"cannon":
					cannons.append({"id": id, "hill": key.contains("hill") or bool(o.get("hill", false)), "side": "" if key.contains("hill") else s,
						"operator_id": -1, "src": o})
	for c: Dictionary in cannons:
		var src: Dictionary = c["src"]
		var op := int(src.get("operator_id", -1))
		c["operator_id"] = op
		if op >= 0:
			ops[op] = int(c["id"])

## Lista de objetos da sim: `sim.gvg["objects"]` ou `GvgSystem.objects(sim)`.
static func _objects(sim, g: Dictionary) -> Array:
	if g.get("objects") is Array:
		return g["objects"]
	if _gs_has("objects"):
		var r: Variant = _gs_call("objects", [sim], [])
		if r is Array:
			return r
	return []

# ---------------------------------------------------------------------------
# LUGARES

static func _other(side: String) -> String:
	return "S" if side == "N" else "N"

static func _ent(sim, id: Variant) -> SimEntity:
	if id == null:
		return null
	var o: SimEntity = sim.entities.get(int(id))
	return o if o != null and o.is_alive() else null

static func _gate_ent(sim, ai: Dictionary, side: String, which: String) -> SimEntity:
	return _ent(sim, (ai["gates"] as Dictionary).get(which + "_" + side))

static func _crystal_ent(sim, ai: Dictionary, side: String) -> SimEntity:
	return _ent(sim, (ai["crystals"] as Dictionary).get(side))

static func _gate_pos(sim, ai: Dictionary, side: String, which: String) -> Vector3:
	var o: SimEntity = sim.entities.get(int((ai["gates"] as Dictionary).get(which + "_" + side, -1)))
	return o.position if o != null else GvgCatalog.point("gate_" + which, side)

static func _point(sim, ai: Dictionary, key: String, side: String) -> Vector3:
	if key == "crystal":
		var c: SimEntity = sim.entities.get(int((ai["crystals"] as Dictionary).get(side, -1)))
		if c != null:
			return c.position
	return GvgCatalog.point(key, side)

## Ponto `depth` m para dentro do portão `which` do castelo `side` (negativo = para fora, no campo).
static func _inside(sim, ai: Dictionary, side: String, which: String, depth: float) -> Vector3:
	var gp := _gate_pos(sim, ai, side, which)
	var cr := _point(sim, ai, "crystal", side)
	var v := Vector3(cr.x - gp.x, 0.0, cr.z - gp.z)
	return gp + (v.normalized() if v.length() > 0.1 else Vector3(0, 0, -1 if side == "N" else 1)) * depth

## Onde o lado espera/forma (preparo; escolta sem Muro): atacante na frente dele, defensor no pátio.
static func _front(sim, g: Dictionary, ai: Dictionary, side: String, attack: bool) -> Vector3:
	if attack:
		return GvgCatalog.point("front", side)
	return _inside(sim, ai, side, "main", 5.0)

static func _in_castle(p: Vector3, side: String) -> bool:
	var sz := -1.0 if side == "N" else 1.0
	return p.z * sz > GvgCatalog.CASTLE_Z and absf(p.x) < GvgCatalog.CASTLE_HALF_X

static func _slot_point(p: Vector3, w: Dictionary, r: float) -> Vector3:
	var a := float(int(w["slot"])) * 2.399 + (1.3 if str(w["role"]) == "muro" else 0.0)
	return p + Vector3(cos(a), 0.0, sin(a)) * r

static func _walk(e: SimEntity, brain: BotBrain, p: Vector3, cmd: InputCommand, dt: float) -> void:
	if Vector2(p.x - e.position.x, p.z - e.position.z).length() <= 0.9:
		cmd.move = Vector2.ZERO
		return
	if brain.cur_sim != null:
		p = _gs_call("waypoint", [brain.cur_sim, e, p], p)     # muro do castelo: contorna pelo caminho da sim (portão/postigo)
	cmd.move = brain._steer(e, p, dt)
	cmd.aim = p

## Aríete do bot: todos escoltam o aríete da frente (o vivo com menos estrada até o portão; empate = ordem dos ids).
## Antes a escolta se dividia pela vaga (slot % vivos) e cada aríete ficava com 2 de GVG_RAM_PUSHERS: os dois paravam.
## null = nenhum vivo.
static func _ram_for(sim, ai: Dictionary, side: String, _w: Dictionary) -> SimEntity:
	var ids: Array = (ai["rams"] as Dictionary).get(side, [])
	var best: SimEntity = null
	var bd := INF
	for id in ids:
		var r: SimEntity = sim.entities.get(id)
		if r == null or not r.is_alive():
			continue
		var d := ram_road_left(sim, r)
		if d < bd - 0.01:
			bd = d
			best = r
	return best

## m de estrada que faltam ao aríete `r` (do ponto dele à perna atual e daí ao fim da rota). Pura, sem alocar.
static func ram_road_left(sim, r: SimEntity) -> float:
	var objs: Array = (sim.gvg as Dictionary).get("objects", [])
	for o: Dictionary in objs:
		if int(o["id"]) != r.id or str(o["type"]) != "ram":
			continue
		var route: Array = o.get("route", [])
		var leg := int(o.get("leg", 0))
		var p := r.position
		var total := 0.0
		for k in range(leg, route.size()):
			var q: Vector3 = route[k]
			total += Vector2(q.x - p.x, q.z - p.z).length()
			p = q
		return total
	return INF

static func _nearest_obj(sim, ids: Array, at: Vector3) -> SimEntity:
	var best: SimEntity = null
	var bd := INF
	for id in ids:
		var o: SimEntity = sim.entities.get(id)
		if o == null or not o.is_alive():
			continue
		var d := o.position.distance_squared_to(at)
		if d < bd:
			bd = d
			best = o
	return best

static func _nearest_role(sim, ai: Dictionary, side: String, role: String, at: Vector3, skip: SimEntity) -> SimEntity:
	var best: SimEntity = null
	var bd := INF
	var roles: Dictionary = ai["role_of"]
	for o: SimEntity in ai["allies"][side]:
		if o == skip or not o.is_alive() or str(roles.get(o.id, "")) != role:
			continue
		var d := o.position.distance_squared_to(at)
		if d < bd:
			bd = d
			best = o
	return best

static func _nearest_ally(sim, ai: Dictionary, side: String, e: SimEntity) -> SimEntity:
	var best: SimEntity = null
	var bd := INF
	for o: SimEntity in ai["allies"][side]:
		if o == e or not o.is_alive():
			continue
		var d := o.position.distance_squared_to(e.position)
		if d < bd:
			bd = d
			best = o
	return best

# ---------------------------------------------------------------------------
# PONTE PARA O GvgSystem (dono: agente da sim). Por `load` + `call`: este arquivo compila sem ele.

static func _gs_load() -> void:
	if _gs_tried:
		return
	_gs_tried = true
	if not ResourceLoader.exists(GVG_SYSTEM_PATH):
		return
	_gs = load(GVG_SYSTEM_PATH)
	if _gs != null:
		for md in _gs.get_script_method_list():
			_gs_methods[str(md["name"])] = true

static func _gs_has(fn: String) -> bool:
	_gs_load()
	return _gs != null and _gs_methods.has(fn)

static func _gs_call(fn: String, args: Array, fallback: Variant) -> Variant:
	if not _gs_has(fn):
		return fallback
	return _gs.callv(fn, args)

## Número da sim (Balance.<name>) com reserva do GvgBrain (a sim ainda pode não ter a constante).
static func _bal(name: String, fallback: float) -> float:
	var v: Variant = Balance.get(name)
	return float(v) if v != null else fallback
