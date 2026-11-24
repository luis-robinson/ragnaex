class_name PieceEffects
extends RefCounted
## Lendários do 50 (design/gdd/ato3-lendarios-50.md): efeito próprio de cada peça do conjunto de build do 50.
## Sem estado: dados em `ItemDef.piece_fx` (GearCatalog.LEG50 + Balance.LEG50_NUMBERS), recargas em `e.leg50_ready`
## (fora do save). Famílias: stat / mana_guard_eff (somam como bônus de item), charges (ChargeSystem.max_of), cap_up
## (cap(e, chave)), skill_mods (ClassTalentSystem.apply_mods), legend_up / legend_wake (mexem no `legend` da arma se o
## kind bate), form_up (SimEntity.recompute_stats), dot_up (WorldSim._apply_effects), zone_on_cast e on_trigger
## (eventos: block, parry, dodge, kill, cast:<skill>, hit:<skill>, stun_proc, penance_burst, trap, det_full).
## Cada peça vale sozinha; skill citada só age se o personagem a tem (lançou/aprendeu). Sem laço por tick.

## Sondas: peças desligadas (--l50_off=<peça,...|all>; "head", "weapon"...). Vazio = todas ligadas.
static var off: Dictionary = {}

## Liga/desliga pelo argumento das sondas. Ex.: set_off("all"), set_off("gloves,boots").
static func set_off(arg: String) -> void:
	off = {}
	for p in arg.split(","):
		if p.strip_edges() != "":
			off[p.strip_edges()] = true

static func is_on(fx: Dictionary) -> bool:
	return not fx.is_empty() and not off.has("all") and not off.has(str(fx.get("piece", "")))

## Efeitos ligados das peças vestidas (a mesma peça em dois espaços vale uma vez).
static func active(equipment: Dictionary) -> Array:
	var out: Array = []
	var seen := {}
	for slot in equipment:
		var it: ItemDef = equipment[slot]
		if it == null or it.piece_fx.is_empty() or not is_on(it.piece_fx):
			continue
		var key: String = it.base_id if it.base_id != "" else it.id
		if seen.has(key):
			continue
		seen[key] = true
		out.append(it.piece_fx)
	return out

## Stats.compute: soma stats, tetos, cargas e mods; legend_up/legend_wake mexem numa cópia do `legend` da arma.
static func apply_stats(s: Stats, equipment: Dictionary, set_bonus: Array) -> void:
	for fx: Dictionary in active(equipment):
		if fx.has("stats"):
			set_bonus.append(fx["stats"])
		var caps: Dictionary = fx.get("caps", {})
		for k in caps:
			s.piece_caps[k] = float(s.piece_caps.get(k, 0.0)) + float(caps[k])
		match str(fx["kind"]):
			"charges":
				s.piece_charges[str(fx["skill"])] = true
			"skill_mods":
				var sid: String = fx["skill"]
				if not s.piece_mods.has(sid):
					s.piece_mods[sid] = []
				s.piece_mods[sid].append(fx["mod"])
			"legend_up", "legend_wake":
				if str(s.legend.get("kind", "")) == str(fx["legend"]):
					s.legend = _legend_add(s.legend, fx.get("adds", {}))
					if fx["kind"] == "legend_wake":
						s.legend["wake"] = fx
			"on_trigger", "zone_on_cast", "dot_up", "form_up":
				s.piece_fx.append(fx)

## Soma `adds` ao legend (cópia). below_pts = pontos de % no limiar (fração); stacks nunca abaixo de LEG50_PENANCE_MIN.
static func _legend_add(le: Dictionary, adds: Dictionary) -> Dictionary:
	var out := le.duplicate()
	for k in adds:
		var v := float(adds[k])
		match str(k):
			"below_pts":
				out["below"] = float(out.get("below", 0.3)) + v / 100.0
			"stacks":
				out["stacks"] = maxi(Balance.LEG50_PENANCE_MIN, int(out.get("stacks", 5)) + int(v))
			"targets", "max":
				out[k] = int(out.get(k, 0)) + int(v)
			"icd":
				out["icd"] = maxf(1.0, float(out.get("icd", 0.0)) + v)
			_:
				out[k] = float(out.get(k, 0.0)) + v
	return out

## Soma de um teto/parâmetro das peças (0 sem peça). Ex.: cap(e, "oath") -> 2.
static func cap(e: SimEntity, key: String) -> float:
	return float(e.stats.piece_caps.get(key, 0.0)) if e != null and e.stats != null else 0.0

## Cláusula desperta da arma com o nome `name` ({} sem ela).
static func wake(e: SimEntity, name: String) -> Dictionary:
	if e == null or e.stats == null:
		return {}
	var w: Dictionary = e.stats.legend.get("wake", {})
	return w if str(w.get("wake", "")) == name else {}

## O personagem tem a skill (aprendida ou na barra).
static func knows(e: SimEntity, sid: String) -> bool:
	return e.learned.has(sid) or e.mastery.has(sid)

## Chave da conta de alvos (max_hits) em e.leg50_ready: { id do alvo: true }.
static func _hits_key(fx: Dictionary) -> String:
	return "%s_%s_hits" % [fx.get("build", ""), fx.get("piece", "")]

static func _ready(sim: WorldSim, e: SimEntity, fx: Dictionary) -> bool:
	var key := "%s_%s" % [fx.get("build", ""), fx.get("piece", "")]
	if sim.time < float(e.leg50_ready.get(key, -INF)):
		return false
	if float(fx.get("icd", 0.0)) > 0.0:
		e.leg50_ready[key] = sim.time + float(fx["icd"])
	return true

# --- eventos ------------------------------------------------------------------------------------------------------
## Dispara os on_trigger de `e` com o evento `ev` (alvo `t` quando há; `amount` = dano do golpe).
static func on_event(sim: WorldSim, e: SimEntity, ev: String, t: SimEntity = null, amount: int = 0) -> void:
	if e == null or not e.is_character() or e.stats == null or e.stats.piece_fx.is_empty() or not e.is_alive():
		return
	for fx: Dictionary in e.stats.piece_fx:
		if fx["kind"] != "on_trigger" or str(fx["on"]) != ev:
			continue
		var hits: Dictionary = {}
		if int(fx.get("max_hits", 0)) > 0 and t != null:     # teto de alvos distintos por lançamento (on_cast zera)
			hits = e.leg50_ready.get(_hits_key(fx), {})
			if hits.has(t.id) or hits.size() >= int(fx["max_hits"]):
				continue
		if _ready(sim, e, fx):
			if int(fx.get("max_hits", 0)) > 0 and t != null:
				hits[t.id] = true
				e.leg50_ready[_hits_key(fx)] = hits
			for a: Dictionary in fx["do"]:
				_act(sim, e, t, a, amount)

## Lançou `s` (no impacto, WorldSim._apply_skill_body): gatilho cast:<id> e chão de zone_on_cast.
static func on_cast(sim: WorldSim, e: SimEntity, s: SkillDef, aim: Vector3) -> void:
	if e.stats == null or e.stats.piece_fx.is_empty():
		return
	for fx: Dictionary in e.stats.piece_fx:      # lançou de novo: a conta de alvos do hit:<id> recomeça
		if fx["kind"] == "on_trigger" and int(fx.get("max_hits", 0)) > 0 and str(fx["on"]) == "hit:" + s.id:
			e.leg50_ready.erase(_hits_key(fx))
	if sim.signature_casting:
		return
	on_event(sim, e, "cast:" + s.id)
	for fx: Dictionary in e.stats.piece_fx:
		if fx["kind"] == "zone_on_cast" and str(fx["skill"]) == s.id:
			var zd: Dictionary = (fx["zone"] as Dictionary).duplicate()
			zd["id"] = "leg50_%s" % s.id
			TrapSystem.place_zone(sim, e, s, aim, s.power, {"zone": zd})

## Golpe direto de `e` em `t` com `s` (WorldSim._strike): gatilho hit:<id>.
static func on_hit(sim: WorldSim, e: SimEntity, t: SimEntity, s: SkillDef, amount: int) -> void:
	if amount > 0 and s != null and e.is_character() and not e.stats.piece_fx.is_empty() and e.is_hostile_to(t):
		on_event(sim, e, "hit:" + s.id, t, amount)

## Abate: gatilho "kill" (monstro que dá XP) e a Praga Desperta (Agonia da arma passa a um vizinho).
static func on_kill(sim: WorldSim, dead: SimEntity, killer: SimEntity) -> void:
	if killer == null or dead.kind != SimEntity.Kind.MONSTER or not killer.is_character() or killer.stats == null:
		return
	if dead.monster_def != null and dead.monster_def.xp > 0:
		on_event(sim, killer, "kill", dead)
	var w := wake(killer, "spread")
	if not w.is_empty() and not sim.signature_casting:
		var sid := str(killer.stats.legend.get("skill", ""))
		var cursed := false
		for d in dead.debuffs:
			if int(d.get("src", -1)) == killer.id and str(d.get("id", "")).contains(sid):
				cursed = true
		var o := nearest_foe(sim, killer, dead, Balance.LEG50_FOE_RANGE)
		if cursed and o != null:
			sim.signature_casting = true
			LegendEffects.legend_cast(sim, killer, sid, o.position)
			sim.signature_casting = false

# --- ações --------------------------------------------------------------------------------------------------------
static func _act(sim: WorldSim, e: SimEntity, t: SimEntity, a: Dictionary, amount: int) -> void:
	match str(a["do"]):
		"cd_cut":
			var sid: String = a["skill"]
			if float(e.cooldowns.get(sid, 0.0)) > 0.0:
				e.cooldowns[sid] = maxf(0.0, float(e.cooldowns[sid]) - float(a["s"]))
			var st: Array = e.charges.get(sid, [])
			if not st.is_empty():
				st[1] = float(st[1]) - float(a["s"])
		"cd_reset":
			e.cooldowns[str(a["skill"])] = 0.0
			ChargeSystem.refill(e, str(a["skill"]))
		"gain":
			gain(sim, e, str(a["what"]), int(a["n"]))
		"cast":
			var sid: String = a["skill"]
			if sim.signature_casting or not knows(e, sid) or not GameData.skills.has(sid):
				return
			var at := e.position
			if str(a.get("at", "")) == "foe":
				var o := nearest_foe(sim, e, e, Balance.LEG50_CAST_RANGE)
				if o == null:
					return
				at = o.position
			sim.signature_casting = true
			var keep := sim.power_scale
			sim.power_scale = float(a["power"]) / 100.0
			LegendEffects.legend_cast(sim, e, sid, at)
			sim.power_scale = keep
			sim.signature_casting = false
		"heal":
			sim._heal(e, e, maxi(1, int(e.stats.max_hp * float(a["pct"]) / 100.0)))
		"mp":
			e.mp = minf(e.stats.max_mp, e.mp + e.stats.max_mp * float(a["pct"]) / 100.0)
		"barrier", "heal_allies":
			var who: Array = allies(sim, e, Balance.LEG50_ALLY_RANGE) if a.get("allies", true) else [e]
			for o: SimEntity in who:
				if a["do"] == "barrier":
					sim._apply_effects(e, o, {"shield": {"amount_pct_hp": float(a["pct"]), "duration": Balance.SHIELD_BARRIER_TIME}}, 1.0)
				else:
					sim._heal(e, o, maxi(1, int(o.stats.max_hp * float(a["pct"]) / 100.0)))
		"cleanse":
			var f := sim.most_hurt_friend(e, Balance.LEG50_ALLY_RANGE)
			for i in range(f.debuffs.size()):
				if str(f.debuffs[i].get("kind", "")) in ["dot", "slow", "curse", "root", "stun"]:
					f.debuffs.remove_at(i)
					break
		"curse":
			if t != null and t.is_alive() and e.is_hostile_to(t):
				sim._apply_effects(e, t, {"curse": {"id": "legend_mark", "duration": float(a["time"]), "taken_pct": float(a["pct"])}}, 0.0)
		"bleed":
			var le: Dictionary = e.stats.legend
			if t != null and t.is_alive() and str(le.get("kind", "")) == "bleed":
				LegendEffects.legend_dot(sim, e, t, le)
		"wound_renew":
			if t != null:
				for d in t.debuffs:
					if str(d.get("id", "")) in ["legend_wound_%d" % e.id, "legend_wound_bleed_%d" % e.id]:
						d["remaining"] = Balance.LEG_WOUND_TIME
		"ricochet":
			var o := nearest_foe(sim, e, t, Balance.LEG50_FOE_RANGE) if t != null else null
			if o != null and amount > 0:
				sim._deal_damage(e, o, maxi(1, int(amount * float(a["pct"]) / 100.0)), false, false, "chain", t.position)
		"raise":
			if GameData.monsters.has("skeleton_minion"):
				sim.spawn_summon(e, GameData.monsters["skeleton_minion"], e.skill_aim, float(a["time"]), true)

## +n de uma carga da classe: oath (Juramento), frenzy (Frenesi da arma), fury (Fúria do Punho).
static func gain(sim: WorldSim, e: SimEntity, what: String, n: int) -> void:
	match what:
		"oath":
			var st := mini(ShieldSystem.oath_stacks(sim, e) + n, ClassTalentSystem.oath_max(e))
			e.put_buff({"id": "juramento", "remaining": Balance.SHIELD_OATH_TIME, "stacks": st})
			Events.post(&"buff_applied", e.id, "juramento", Balance.SHIELD_OATH_TIME)
		"frenzy":
			var le: Dictionary = e.stats.legend
			if str(le.get("kind", "")) == "frenzy":
				var k: int = mini(int(le.get("max", 5)), e.buff_stacks("legend_frenzy") + n)
				e.put_buff({"id": "legend_frenzy", "remaining": Balance.LEG_FRENZY_TIME, "stacks": k, "aspd_pct": float(le["pct"]) * k})
				e.recompute_stats()
		"fury":
			FistSystem.gain_fury(sim, e, n)

# --- multiplicadores e consultas ----------------------------------------------------------------------------------
## Golpe direto: Estilhaçar (gelo em alvo retardado, cap "shatter") e Marca Desperta (lince no alvo marcado).
static func hit_mult(sim: WorldSim, e: SimEntity, t: SimEntity, frost: float) -> float:
	var m := 1.0
	if frost > 1.0 and e.is_character():
		m *= 1.0 + cap(e, "shatter") / 100.0
	if e.kind == SimEntity.Kind.SUMMON:
		var owner := FusionEffects.summon_owner(sim, e)
		var w := wake(owner, "pet")
		if not w.is_empty() and str(owner.stats.legend.get("kind", "")) == "mark":
			for d in t.debuffs:
				if d.get("id") == "legend_mark":
					m *= 1.0 + float(w["pct"]) / 100.0
					break
	return m

## Carrasco Desperto: a assinatura abaixo do limiar sai crítica.
static func force_crit(e: SimEntity, t: SimEntity, s: SkillDef) -> bool:
	if s == null or not e.is_character() or wake(e, "crit").is_empty():
		return false
	var le: Dictionary = e.stats.legend
	return s.id == LegendEffects.signature_skill(e) and t.hp < t.stats.max_hp * (float(le.get("below", 0.3)) + FusionEffects.exec_up(e))

## Dano no tempo aplicado por `src` (`d` = efeito dot): [× duração, × dps] das peças dot_up.
static func dot_mult(src: SimEntity, d: Dictionary) -> float:
	if src == null or not src.is_character() or src.stats == null or src.stats.piece_fx.is_empty():
		return 1.0
	var tm := 1.0
	for fx: Dictionary in src.stats.piece_fx:
		if fx["kind"] != "dot_up":
			continue
		if (fx["dot"] == "fire" and bool(d.get("fire", false))) or (fx["dot"] == "curse" and str(d.get("skill", "")).begins_with("nec_curse")):
			tm += float(fx["time"]) / 100.0
	return tm

## Bônus de forma das peças (form_up) para a forma `form` de `e` (antes do Stats.compute: lê o equipamento).
static func form_extra(e: SimEntity) -> Array:
	var out: Array = []
	if e.form == "":
		return out
	for fx: Dictionary in active(e.equipment):
		if fx["kind"] == "form_up" and str(fx["form"]) == e.form:
			if fx.has("mult") and Balance.FORM_STATS.has(e.form):
				out.append(SimEntity.scaled_bonus(Balance.FORM_STATS[e.form], float(fx["mult"]) / 100.0))
			if fx.has("stats"):
				out.append(fx["stats"])
	return out

## Explosão da Penitência: +penance_det% por carga de Determinação (escudo do Templário).
static func penance_mult(e: SimEntity) -> float:
	var c := cap(e, "penance_det")
	return 1.0 + c * e.buff_stacks(Balance.LEG_DETERMINATION_BUFF) / 100.0 if c > 0.0 else 1.0

## Eviscerar consumiu `n` venenos: Veneno Letal Desperto devolve MP.
static func on_poison_consume(e: SimEntity, n: int) -> void:
	var w := wake(e, "evis_mp")
	if not w.is_empty() and n > 0:
		e.mp = minf(e.stats.max_mp, e.mp + e.stats.max_mp * float(w["pct"]) * n / 100.0)

## Depois da magia-assinatura de graça em `t`: Brasa Viva Desperta (MP em alvo queimando) e Lua Cheia Desperta (salto).
static func after_signature(sim: WorldSim, e: SimEntity, t: SimEntity, sid: String) -> void:
	if str(e.stats.legend.get("skill", "")) != sid:
		return
	var w := wake(e, "burn_mp")
	if not w.is_empty() and t.debuffs.any(func(d): return bool(d.get("fire", false))):
		e.mp = minf(e.stats.max_mp, e.mp + e.stats.max_mp * float(w["pct"]) / 100.0)
	w = wake(e, "jump")
	var s: SkillDef = GameData.skills.get(sid)
	if not w.is_empty() and s != null:
		var o := nearest_foe(sim, e, t, Balance.APEX_MOON_JUMP_RANGE)
		if o != null:
			Events.post(&"skill_effect", sid, t.position, o.position, s.radius)
			var r := Combat.calc_damage(e, o, s.power * float(w["pct"]) / 100.0 * sim.power_scale, SkillDef.Kind.MAGICAL, sim.rng, t.position)
			sim._deal_damage(e, o, r["amount"], r["crit"], false, "chain", t.position)

## Mão que Cura Desperta: `over` de cura que passou do máximo vira barreira em `f` (teto `cap_pct`% da vida).
static func overflow_barrier(f: SimEntity, over: float, cap_pct: float) -> void:
	var cap_hp := f.stats.max_hp * cap_pct / 100.0
	if f.shield_hp >= cap_hp:
		return
	f.shield_hp = minf(f.shield_hp + over, cap_hp)
	var sb: Array = f.buffs.filter(func(b): return b.get("id") == "shield")
	if sb.is_empty():
		f.buffs.append({"id": "shield", "remaining": Balance.LEG_WARD_TIME})
	else:
		sb[0]["remaining"] = maxf(float(sb[0]["remaining"]), Balance.LEG_WARD_TIME)

## Bots: peso a mais da skill que dispara um efeito de peça vestida (1.0 = nada).
static func bot_skill_mult(e: SimEntity, s: SkillDef) -> float:
	if e == null or e.stats == null or e.stats.piece_fx.is_empty():
		return 1.0
	for fx: Dictionary in e.stats.piece_fx:
		if (fx["kind"] == "on_trigger" and str(fx["on"]) in ["cast:" + s.id, "hit:" + s.id]) or (fx["kind"] == "zone_on_cast" and str(fx["skill"]) == s.id):
			return Balance.LEG50_BOT_TRIGGER_BIAS
	return 1.0

# --- ajudantes ----------------------------------------------------------------------------------------------------
## Inimigo vivo de `e` mais perto de `t` a até `r` m (fora o próprio `t`).
static func nearest_foe(sim: WorldSim, e: SimEntity, t: SimEntity, r: float) -> SimEntity:
	var best: SimEntity = null
	var bd := r
	for o: SimEntity in sim.maps[e.map_id]["entities"]:
		if o == t or not o.is_alive() or not e.is_hostile_to(o):
			continue
		var d := o.position.distance_to(t.position)
		if d <= bd:
			bd = d
			best = o
	return best

## Personagem aliado mais ferido (em %) a até `r` m de `src`, fora `t` (null se ninguém está ferido).
static func most_hurt_other(sim: WorldSim, src: SimEntity, t: SimEntity, r: float) -> SimEntity:
	var best: SimEntity = null
	var bf := 1.0
	for o: SimEntity in sim.maps[src.map_id]["entities"]:
		if o == t or not o.is_character() or not o.is_alive() or not src.is_friend(o) or o.position.distance_to(src.position) > r:
			continue
		var f: float = o.hp / maxf(1.0, o.stats.max_hp)
		if f < bf:
			bf = f
			best = o
	return best

## Você e os personagens aliados vivos a até `r` m.
static func allies(sim: WorldSim, e: SimEntity, r: float) -> Array:
	var out: Array = [e]
	for o: SimEntity in sim.maps[e.map_id]["entities"]:
		if o != e and o.is_character() and o.is_alive() and e.is_friend(o) and o.position.distance_to(e.position) <= r:
			out.append(o)
	return out
