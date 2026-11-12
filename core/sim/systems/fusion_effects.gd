class_name FusionEffects
extends RefCounted
## Fusões dos conjuntos híbridos (GDD Ato II R7.1; fichas em design/gdd/ato2-proposals-2026-11-11.md §1.3).
## A Fusão é o bônus de 5 peças do híbrido A+B (SetDef.fusion; Stats.fusion = números do tier + "face"). A face é a build
## cuja arma está na mão: cada face funciona sozinha; arma de nenhum dos dois lados = Fusão apagada (face "").
## Números em Balance.FUSION_NUMBERS / FUSION_*. Ganchos NOVOS na sim (os outros reaproveitam gatilhos que já existem):
## sobrecura (on_overheal), aura em objeto colocado (tick: torreta/estaca da R2) e golpe de invocação (summon_on_hit).
const NEW_HOOKS := ["on_overheal", "post_regen", "summon_on_hit"]
## Magias sagradas que gastam a Fé (Bi2).
const HOLY_SPELLS := ["bis_smite", "bis_hammer", "bis_divine_hammer"]
## Buff da Bi2 (Aurora): visual em BuffLooks, ícone no HUD.
const AURORA_BUFF := "fus_aurora"
## Skills de pistola (A3): as do Corsário que exigem a pistola.
const PISTOL_REQ := "pistol"

# ----------------------------------------------------------------------------
# estado
# ----------------------------------------------------------------------------

## Fusão ligada de `e` ({} = nenhuma). Invocações usam a do dono (summon_on_hit).
static func of(e: SimEntity) -> Dictionary:
	if e == null or not e.is_character() or e.stats == null:
		return {}
	return e.stats.fusion

static func fid(e: SimEntity) -> String:
	return str(of(e).get("id", ""))

static func face(e: SimEntity) -> String:
	return str(of(e).get("face", ""))

static func num(e: SimEntity, k: String) -> float:
	return float(of(e).get(k, 0.0))

## Dono vivo de uma invocação com Fusão (ou null).
static func summon_owner(sim: WorldSim, e: SimEntity) -> SimEntity:
	if e == null or e.kind != SimEntity.Kind.SUMMON or e.owner_id < 0:
		return null
	var o: SimEntity = sim.entities.get(e.owner_id)
	return o if o != null and o.is_alive() and not of(o).is_empty() else null

## Build cuja arma está na mão (fits exato primeiro, depois só a arma principal); "" = nenhuma das duas.
static func pick_face(cls: ClassDef, fusion_id: String, wt: String, ot: String) -> String:
	if cls == null:
		return ""
	var pair := fusion_id.split("+")
	for strict in [true, false]:
		for bid in pair:
			var b: Dictionary = cls.build_by_id(bid)
			if b.is_empty() or not (wt in b.get("main", [])):
				continue
			var off: Array = b.get("off", [])
			if not strict or (off.is_empty() and (ot == "" or ot in Balance.TITAN_WEAPONS)) or ot in off:
				return bid
	return ""

## Stats: liga a Fusão (face pela arma) e os stats que ela dá (esquiva da B2, torreta da R1).
static func apply_stats(s: Stats, cls: ClassDef, f: Dictionary) -> void:
	if f.is_empty():
		return
	var out := f.duplicate()
	out["face"] = pick_face(cls, str(f["id"]), s.weapon_type, s.offhand_type)
	s.fusion = out
	if out["face"] == "":
		return
	match str(f["id"]):
		"executor+punhos":
			if out["face"] == "executor":
				s.evasion += float(f.get("eva", 0.0))
		"cacador+atirador":
			if out["face"] == "atirador":
				s.turret_max += 1.0

static func active(e: SimEntity, id: String) -> bool:
	return fid(e) == id and face(e) != ""

static func _stack(e: SimEntity, bid: String) -> int:
	return e.buff_stacks(bid)

static func _single(s: SkillDef) -> bool:
	return s != null and (s.id.begins_with("basic_") or s.max_targets <= 2)

static func _own_dot(e: SimEntity, t: SimEntity, flag: String) -> Dictionary:
	for d in t.debuffs:
		if d.get("kind") == "dot" and int(d.get("src", -1)) == e.id and bool(d.get(flag, false)):
			return d
	return {}

## Maldições de `e` no alvo (a Praga Menor da N2 conta uma por carga), até FUSION_CURSE_MAX.
static func _curses(e: SimEntity, t: SimEntity) -> int:
	var n := 0
	var tail := "_%d" % e.id
	for d in t.debuffs:
		if d.get("kind") == "curse" and str(d.get("id", "")).ends_with(tail):
			n += maxi(1, int(d.get("stacks", 1)))
	return mini(n, Balance.FUSION_CURSE_MAX)

## Cargas de Penitência de `e` no alvo (arma do Templário ou P2).
static func _penance(e: SimEntity, t: SimEntity) -> int:
	var did := "legend_penance_%d" % e.id
	for d in t.debuffs:
		if d.get("id") == did:
			return int(d.get("stacks", 0))
	return 0

## Alvo com Fogo Lunar de `e` (marca da D2, dura o tempo da queimadura lunar).
static func _moonlit(e: SimEntity, t: SimEntity) -> bool:
	var did := "fus_moon_%d" % e.id
	for d in t.debuffs:
		if d.get("id") == did:
			return true
	return false

## D2 face Lobo: a Mordida do lobo (dano no tempo do próprio druida, sem fogo) conta como sangramento.
static func _bitten(e: SimEntity, t: SimEntity) -> bool:
	for d in t.debuffs:
		if d.get("kind") == "dot" and int(d.get("src", -1)) == e.id and not d.get("fire", false):
			return true
	return false

## Magia sagrada (Bi2): magia do Bispo com dano, ou as de HOLY_SPELLS.
static func _holy(s: SkillDef) -> bool:
	return s != null and (s.id in HOLY_SPELLS or (s.id.begins_with("bis_") and s.kind == SkillDef.Kind.MAGICAL and s.power > 0.0))

static func _poisons(e: SimEntity, t: SimEntity) -> int:
	var n := 0
	for d in t.debuffs:
		if d.get("kind") == "dot" and int(d.get("src", -1)) == e.id and not d.get("fire", false) and not d.get("bleed", false):
			n += 1
	return mini(n, Balance.FUSION_POISON_MAX)

static func _shocked(e: SimEntity, t: SimEntity) -> bool:
	var did := "fus_shock_%d" % e.id
	for d in t.debuffs:
		if d.get("id") == did:
			return true
	return false

static func _has_bleed(t: SimEntity) -> bool:
	for d in t.debuffs:
		if d.get("kind") == "dot" and d.get("bleed", false):
			return true
	return false

static func _is_storm(s: SkillDef) -> bool:
	return s != null and (s.elements.has("storm") or s.vfx == "lightning")

static func _is_frost(s: SkillDef) -> bool:
	return s != null and (s.elements.has("frost") or s.vfx == "ice")

static func _is_fire(s: SkillDef) -> bool:
	return s != null and (s.elements.has("fire") or s.vfx == "fire")

static func _frenzy(sim: WorldSim, e: SimEntity, add: int, pct: float, eva: float) -> void:
	var n: int = mini(Balance.FUSION_FRENZY_MAX, _stack(e, "fus_frenzy") + add)
	var aspd := 0.0 if str(e.stats.legend.get("kind", "")) == "frenzy" else pct * n     # arma dos Gêmeos: vale o maior, não soma
	var b := {"id": "fus_frenzy", "remaining": Balance.LEG_FRENZY_TIME, "stacks": n, "aspd_pct": aspd}
	if eva > 0.0 and n >= Balance.FUSION_FRENZY_MAX:
		b["evasion"] = eva
	e.put_buff(b)
	e.recompute_stats()
	count(e, "frenzy")

static func _counter(sim: WorldSim, e: SimEntity, attacker: SimEntity, pct: float) -> void:
	if sim.time < float(e.fus.get("counter_at", 0.0)) or not attacker.is_alive() or attacker.position.distance_to(e.position) > Balance.LEG_RIPOSTE_RANGE:
		return
	e.fus["counter_at"] = sim.time + Balance.FUSION_COUNTER_ICD
	sim._deal_damage(e, attacker, maxi(1, int(e.stats.patk * pct / 100.0)), false, false, "riposte")
	count(e, "counter")

## Recargas por alvo ("pen_<id>", "agony_<id>") vencidas saem do estado (luta longa não acumula chaves).
static func _prune(sim: WorldSim, e: SimEntity) -> void:
	if e.fus.size() < Balance.FUSION_STATE_MAX:
		return
	for k in e.fus.keys():
		if (str(k).begins_with("pen_") or str(k).begins_with("agony_")) and float(e.fus[k]) < sim.time:
			e.fus.erase(k)

## Contador por Fusão (sondas: a Fusão disparou?).
static func count(e: SimEntity, what: String) -> void:
	e.fus["n_" + what] = int(e.fus.get("n_" + what, 0)) + 1
	e.fus["fired"] = int(e.fus.get("fired", 0)) + 1

# ----------------------------------------------------------------------------
# poder (multiplicadores)
# ----------------------------------------------------------------------------

## Ao lançar (poder da skill): Juramento da face 2 mãos (P1), Peso (B2), golpe "furtivo" (A1).
static func skill_mult(sim: WorldSim, e: SimEntity, s: SkillDef) -> float:
	if of(e).is_empty() or face(e) == "" or sim.signature_casting or not (s.kind in [SkillDef.Kind.PHYSICAL, SkillDef.Kind.MAGICAL]) or s.power <= 0.0:
		return 1.0
	var mult := 1.0
	match fid(e):
		"guardiao+cruzado":
			if face(e) == "cruzado" and s.vfx == "holy" and not e.stats.has_shield:
				var st := ShieldSystem.oath_stacks(sim, e)
				if st > 0:
					mult += st * Balance.SHIELD_OATH_POWER
					e.drop_buff("juramento")
					if st >= Balance.FUSION_OATH_TAUNT_STACKS:
						e.fus["taunt_skill"] = s.id
						e.fus["taunt_until"] = sim.time + Balance.FUSION_TAUNT_WINDOW
					count(e, "oath_spend")
		"executor+punhos":
			var w := _stack(e, "fus_weight")
			if w > 0 and not s.id.begins_with("basic_"):
				mult *= 1.0 + num(e, "weight") * w / 100.0
				e.drop_buff("fus_weight")
				count(e, "weight")
		"laminas+duelista":
			if sim.time < float(e.fus.get("ghost_until", -1.0)):
				e.fus["ghost_until"] = -1.0
				mult *= minf(ClassTalentSystem.ambush_mult(e), Balance.FUSION_AMBUSH_MAX)
				count(e, "ghost")
	return mult

## No golpe direto em `t` (com as condições do alvo). Vale também para golpes de invocação (dono com a Fusão).
static func hit_mult(sim: WorldSim, e: SimEntity, t: SimEntity, s: SkillDef) -> float:
	var owner := summon_owner(sim, e)
	if owner != null:
		return _summon_mult(sim, owner, e, t)
	if of(e).is_empty() or face(e) == "" or t == null:
		return 1.0
	var m := 1.0
	match fid(e):
		"carniceiro+executor":
			var st := maxi(_stack(e, "fus_frenzy"), _stack(e, "legend_frenzy"))
			var thr := Balance.FUSION_EXEC_BASE + Balance.FUSION_EXEC_STEP * st
			if t.hp < t.stats.max_hp * thr / 100.0:
				m *= 1.0 + num(e, "exec_dmg") / 100.0
		"fera+xama":
			if face(e) == "xama" and s != null and s.kind == SkillDef.Kind.MAGICAL and _has_bleed(t):
				m *= 1.0 + num(e, "hunt") / 100.0
		"xama+guardiao_verde":
			if face(e) == "xama" and s != null and s.kind == SkillDef.Kind.MAGICAL and (t.has_debuff("root") or _in_ent(sim, e, t)):
				m *= 1.0 + num(e, "root_dmg") / 100.0
		"lanceiro+cacador":
			if face(e) == "lanceiro" and str(e.stats.legend.get("kind", "")) != "open_wound":
				m *= 1.0 + num(e, "pct") * LegendEffects.wounds(e, t) / 100.0
		"corsario+laminas":
			if face(e) == "corsario" and s != null and PISTOL_REQ in s.requires:
				m *= 1.0 + num(e, "per") * _poisons(e, t) / 100.0
		"gelo+raio":
			if _is_frost(s) and _shocked(e, t):
				m *= 1.0 + num(e, "super") / 100.0
		"raio+fogo":
			if _is_fire(s) and _shocked(e, t):
				m *= 1.0 + num(e, "plasma") / 100.0
		"ceifador+pestilento":
			m *= 1.0 + num(e, "curse_dmg") * _curses(e, t) / 100.0
	return m

## Todo o dano de `a` em `t` (golpe, área, dano no tempo; não o das invocações), chamado em WorldSim._deal_damage:
## P2 (+pen_dmg% por Penitência no alvo) e D2 face duas maças (+hunt% em alvo sangrando ou com Fogo Lunar).
static func damage_mult(a: SimEntity, t: SimEntity) -> float:
	if a == t or not a.is_character() or a.stats == null or a.stats.fusion.is_empty() or face(a) == "":
		return 1.0
	match fid(a):
		"cruzado+templario":
			var n := mini(_penance(a, t), Balance.FUSION_PEN_MAX)
			if n > 0:
				return 1.0 + num(a, "pen_dmg") * n / 100.0
		"fera+xama":
			if face(a) == "fera" and (_has_bleed(t) or _moonlit(a, t) or _bitten(a, t)):
				return 1.0 + num(a, "hunt") / 100.0
	return 1.0

## Golpe de invocação (R1 face arco, R3 face arco, N3): o dono tem a Fusão.
static func _summon_mult(sim: WorldSim, owner: SimEntity, pet: SimEntity, t: SimEntity) -> float:
	if t == null or face(owner) == "":
		return 1.0
	match fid(owner):
		"cacador+atirador":
			if face(owner) == "cacador" and Combat.is_chilled(t):
				return 1.0 + num(owner, "trap_taken") / 100.0
		"lanceiro+cacador":
			if face(owner) == "cacador":
				return 1.0 + num(owner, "pack") * LegendEffects.wounds(owner, t) / 100.0
		"pestilento+invocador":
			return 1.0 + num(owner, "minion_curse") * _curses(owner, t) / 100.0
	return 1.0

static func _in_ent(sim: WorldSim, e: SimEntity, t: SimEntity) -> bool:
	for o: SimEntity in sim.maps[e.map_id]["entities"]:
		if o.kind == SimEntity.Kind.SUMMON and o.owner_id == e.id and o.is_alive() and o.monster_def != null \
				and o.monster_def.id.contains("treant") and o.position.distance_to(t.position) <= Balance.FUSION_ENT_RADIUS:
			return true
	return false

# ----------------------------------------------------------------------------
# gatilhos
# ----------------------------------------------------------------------------

## Golpe direto que acertou (depois da arma lendária). `crit` = foi crítico.
static func on_hit(sim: WorldSim, e: SimEntity, t: SimEntity, s: SkillDef, amount: int, crit: bool) -> void:
	if amount <= 0 or t == null or not e.is_hostile_to(t):
		return
	var owner := summon_owner(sim, e)
	if owner != null:
		summon_on_hit(sim, owner, e, t)
		return
	if of(e).is_empty() or face(e) == "" or s == null:
		return
	var own_cast := sim.signature_casting
	match fid(e):
		"guardiao+cruzado":
			if face(e) == "cruzado":
				if _single(s) and not own_cast and sim.time >= float(e.fus.get("oath_at", 0.0)):
					e.fus["oath_at"] = sim.time + num(e, "oath_icd")
					var st := mini(ShieldSystem.oath_stacks(sim, e) + 1, ClassTalentSystem.oath_max(e))
					e.put_buff({"id": "juramento", "remaining": Balance.SHIELD_OATH_TIME, "stacks": st})
				if s.id == str(e.fus.get("taunt_skill", "")) and sim.time < float(e.fus.get("taunt_until", 0.0)) and t.is_alive():
					MobSystem.taunt(sim, t, e, num(e, "taunt"))
					count(e, "taunt")
		"cruzado+templario":
			# golpe direto põe 1 Penitência (a arma do Templário já põe: vale ela, não soma); na 5ª explode e volta a 2
			if t.is_alive() and not own_cast and str(e.stats.legend.get("kind", "")) != "penance" and sim.time >= float(e.fus.get("pen_%d" % t.id, 0.0)):
				_prune(sim, e)
				e.fus["pen_%d" % t.id] = sim.time + Balance.FUSION_PEN_ICD
				LegendEffects.penance_hit(sim, e, t, {"pct": num(e, "pen_pct"), "stacks": Balance.FUSION_PEN_MAX, "radius": Balance.FUSION_BURST_RADIUS})
				count(e, "penance")
		"carniceiro+executor":
			if _single(s) or s.id.begins_with("basic_"):
				_frenzy(sim, e, 1, num(e, "frenzy"), 0.0)
		"executor+punhos":
			if crit:
				_weight(sim, e)
		"punhos+carniceiro":
			if crit:
				_frenzy(sim, e, 2, num(e, "frenzy"), num(e, "eva2"))
		"inquisidor+batalha":
			# golpe de arma (básico ou skill física) cura o aliado mais ferido; a Mão que Cura lendária já cura: vale ela
			if (s.id.begins_with("basic_") or s.kind == SkillDef.Kind.PHYSICAL) and str(e.stats.legend.get("kind", "")) != "mend":
				sim.mend(e, amount, num(e, "heal") / 100.0)
				count(e, "dawn_heal")
		"batalha+sacerdote":
			if e.stats.weapon_type == "mace":
				e.fus["grace_hits"] = int(e.fus.get("grace_hits", 0)) + 1
				if int(e.fus["grace_hits"]) >= Balance.FUSION_GRACE_HITS and e.grace_cd <= 0.0:
					e.fus["grace_hits"] = 0
					e.grace_cd = Balance.SHIELD_GRACE_CD
					var hurt := sim.most_hurt_friend(e, Balance.SHIELD_GRACE_RANGE)
					sim._heal(e, hurt, int(hurt.stats.max_hp * Balance.SHIELD_GRACE_PCT / 100.0))
					sim._apply_effects(e, hurt, {"shield": {"amount_pct_hp": num(e, "ward"), "duration": Balance.FUSION_WARD_TIME}}, 1.0)
					count(e, "grace")
		"fera+xama":
			if s.id == "dru_moonfire" and t.is_alive():
				t.put_debuff({"kind": "fusion", "id": "fus_moon_%d" % e.id, "remaining": Balance.FUSION_MOON_TIME})
				if face(e) == "xama":           # face cajado: o Fogo Lunar também faz sangrar (sangramento: não corta a regeneração do troll)
					t.put_debuff({"kind": "dot", "id": "fus_moon_bleed_%d" % e.id, "remaining": Balance.FUSION_MOON_TIME,
						"dps": maxf(1.0, e.stats.matk * num(e, "bleed") / 100.0), "src": e.id, "bleed": true})
				count(e, "moon")
		"lanceiro+cacador":
			if face(e) == "lanceiro" and t.is_alive() and not own_cast:
				var le := _wound_numbers(e)
				var legend_did := str(e.stats.legend.get("kind", "")) == "open_wound"
				if not legend_did:
					LegendEffects.wound_hit(sim, e, t, le)
				if Combat.is_chilled(t):
					LegendEffects.wound_hit(sim, e, t, le)
					count(e, "wound2")
		"duelista+corsario":
			if crit and e.stats.weapon_type == "sword" and sim.time >= float(e.fus.get("brav_at", 0.0)):
				e.fus["brav_at"] = sim.time + Balance.FUSION_BRAVADO_ICD
				sim.gain_bravado(e, 1)
			if e.buff_stacks(Balance.BRAVADO_BUFF) >= Balance.BRAVADO_MAX and e.stats.weapon_type == "sword" and t.is_alive():
				e.drop_buff(Balance.BRAVADO_BUFF)
				if face(e) == "corsario":
					LegendEffects.spare_shot(sim, e, t, num(e, "shot"))
					e.drop_buff(Balance.BRAVADO_BUFF)            # o tiro de graça dá +1: a Fusão gasta tudo
				else:
					var fb: Dictionary = (GameData.skills["ass_focus"].effects["buff"] as Dictionary)
					var b := SimEntity.scaled_bonus(fb, num(e, "focus") / 100.0)
					b["remaining"] = Balance.FUSION_FOCUS_TIME
					e.put_buff(b)
					e.recompute_stats()
				count(e, "bravado")
		"corsario+laminas":
			if face(e) == "corsario" and PISTOL_REQ in s.requires and t.is_alive():
				t.put_debuff({"kind": "dot", "id": "fus_poison_%d" % e.id, "remaining": Balance.LEG_DOT_TIME, "dps": maxf(1.0, e.stats.patk * num(e, "poison") / 100.0), "src": e.id})
				count(e, "poison")
			elif face(e) == "laminas" and s.id in ["ass_venom_dart", "ass_fan"] and _poisons(e, t) > 0:
				if float(e.fus.get("a3_t", -1.0)) != sim.time:
					e.fus["a3_t"] = sim.time
					e.fus["a3_n"] = 0
				if int(e.fus["a3_n"]) < 2:
					e.fus["a3_n"] = int(e.fus["a3_n"]) + 1
					sim.gain_bravado(e, 1)
		"fogo+gelo":
			if _is_frost(s) and t.is_alive() and not _own_dot(e, t, "fire").is_empty():
				var left := sim.consume_burns(e, t)
				_burst(sim, e, t.position, int(left * num(e, "quench") / 100.0), Balance.FUSION_VAPOR_RADIUS)
				sim._apply_effects(e, t, {"slow": {"pct": Balance.FUSION_VAPOR_SLOW, "duration": Balance.FUSION_VAPOR_TIME}}, 0.0)
				count(e, "vapor")
		"gelo+raio":
			if _is_storm(s):
				if Combat.is_chilled(t) and float(e.fus.get("e2_t", -1.0)) != sim.time:
					e.fus["e2_t"] = sim.time
					var o := _nearest_foe(sim, e, t, Balance.FUSION_JUMP_RANGE)
					if o != null:
						sim._deal_damage(e, o, amount, false, false, "chain")
						count(e, "super_jump")
				_shock(e, t)
		"raio+fogo":
			if _is_storm(s):
				var burn := _own_dot(e, t, "fire")
				if not burn.is_empty() and float(e.fus.get("e3_t", -1.0)) != sim.time:
					e.fus["e3_t"] = sim.time
					_spread(sim, e, t, burn)
				_shock(e, t)
		"invocador+ceifador":
			var best: SimEntity = null
			for o: SimEntity in sim.maps[e.map_id]["entities"]:
				if o.kind == SimEntity.Kind.SUMMON and o.owner_id == e.id and o.is_alive() and o.hp < o.stats.max_hp \
						and o.position.distance_to(e.position) <= Balance.FUSION_MINION_MEND_RANGE and (best == null or o.hp / o.stats.max_hp < best.hp / best.stats.max_hp):
					best = o
			if best != null:
				sim._heal(e, best, maxi(1, int(amount * num(e, "mend") / 100.0)))
		"ceifador+pestilento":
			# golpe de foice: Praga Menor (maldição, até FUSION_PLAGUE_MAX cargas, renova)
			if t.is_alive() and not own_cast and e.stats.weapon_type == "scythe":
				var pid := "curse_fus_plague_%d" % e.id
				var st := 0
				for d in t.debuffs:
					if d.get("id") == pid:
						st = int(d.get("stacks", 0))
				t.put_debuff({"kind": "curse", "id": pid, "remaining": Balance.FUSION_PLAGUE_TIME, "stacks": mini(Balance.FUSION_PLAGUE_MAX, st + 1)})
				count(e, "plague")
			var n := _curses(e, t)
			if n > 0 and e.is_alive():
				e.hp = minf(e.stats.max_hp, e.hp + amount * num(e, "curse_ls") * n / 100.0)

static func _weight(sim: WorldSim, e: SimEntity) -> void:
	if sim.time < float(e.fus.get("weight_at", 0.0)):
		return
	e.fus["weight_at"] = sim.time + Balance.FUSION_WEIGHT_ICD
	e.put_buff({"id": "fus_weight", "remaining": Balance.FUSION_WEIGHT_TIME, "stacks": mini(Balance.FUSION_WEIGHT_MAX, _stack(e, "fus_weight") + 1)})

static func _wound_numbers(e: SimEntity) -> Dictionary:
	var le: Dictionary = e.stats.legend
	if str(le.get("kind", "")) == "open_wound":
		return le                         # arma do Lanceiro: vale o maior (a da arma)
	return {"pct": num(e, "pct"), "max": int(num(e, "max")), "bleed": num(e, "bleed")}

static func _shock(e: SimEntity, t: SimEntity) -> void:
	t.put_debuff({"kind": "fusion", "id": "fus_shock_%d" % e.id, "remaining": Balance.FUSION_SHOCK_TIME})

static func _nearest_foe(sim: WorldSim, e: SimEntity, t: SimEntity, r: float) -> SimEntity:
	var best: SimEntity = null
	var bd := r
	for o: SimEntity in sim.maps[e.map_id]["entities"]:
		if o != t and o.is_alive() and e.is_hostile_to(o):
			var d: float = o.position.distance_to(t.position)
			if d <= bd:
				bd = d
				best = o
	return best

## Plasma (E3): a queimadura do alvo pega nos inimigos em volta (spread% do dano por segundo, tempo que falta).
static func _spread(sim: WorldSim, e: SimEntity, t: SimEntity, burn: Dictionary) -> void:
	var n := 0
	for o: SimEntity in sim.maps[e.map_id]["entities"]:
		if n >= Balance.FUSION_SPREAD_MAX:
			break
		if o != t and o.is_alive() and e.is_hostile_to(o) and o.position.distance_to(t.position) <= Balance.FUSION_SPREAD_RANGE:
			o.debuffs.append({"kind": "dot", "id": "fus_plasma_%d" % e.id, "remaining": float(burn.get("remaining", Balance.FUSION_SHOCK_TIME)),
				"dps": float(burn.get("dps", 1.0)) * num(e, "spread") / 100.0, "src": e.id, "fire": true})
			n += 1
	if n > 0:
		count(e, "spread")

## Dano da Fusão em área (não é "magical": não dispara Radiância nem estilhaço).
static func _burst(sim: WorldSim, e: SimEntity, at: Vector3, amount: int, r: float) -> void:
	if amount <= 0:
		return
	Events.post(&"skill_effect", "pal_sun_strike", at, at, r)
	for o: SimEntity in sim.maps[e.map_id]["entities"].duplicate():
		if o.is_alive() and e.is_hostile_to(o) and o.position.distance_to(at) <= r + o.radius:
			sim._deal_damage(e, o, amount, false, false, "fusion", at)

static func _free_cast(sim: WorldSim, e: SimEntity, skill_id: String, aim: Vector3, scale: float) -> void:
	sim.signature_casting = true
	var keep := sim.power_scale
	sim.power_scale = scale
	LegendEffects.legend_cast(sim, e, skill_id, aim)
	sim.power_scale = keep
	sim.signature_casting = false

## Gancho novo: golpe de invocação (R1 face arco usa só o multiplicador; R3 face arco; N3).
static func summon_on_hit(sim: WorldSim, owner: SimEntity, pet: SimEntity, t: SimEntity) -> void:
	if face(owner) == "" or not t.is_alive():
		return
	match fid(owner):
		"lanceiro+cacador":
			if face(owner) == "cacador" and sim.time >= float(owner.fus.get("pet_wound_at", 0.0)):
				owner.fus["pet_wound_at"] = sim.time + Balance.FUSION_WOUND_ICD
				LegendEffects.wound_hit(sim, owner, t, _wound_numbers(owner))
				count(owner, "pet_wound")
		"pestilento+invocador":
			var key := "agony_%d" % t.id
			if sim.time >= float(owner.fus.get(key, 0.0)):
				_prune(sim, owner)
				owner.fus[key] = sim.time + num(owner, "agony_icd")
				var ag: Dictionary = GameData.skills["nec_curse_agony"].effects
				var dot: Dictionary = (ag["dot"] as Dictionary).duplicate()
				dot["dps"] = float(dot.get("dps", 5)) * Balance.FUSION_AGONY_POWER
				var cu: Dictionary = (ag["curse"] as Dictionary).duplicate()
				cu["taken_pct"] = float(cu.get("taken_pct", 0)) * Balance.FUSION_AGONY_POWER
				sim._apply_effects(owner, t, {"dot": dot, "curse": cu}, 1.0)
				count(owner, "agony")

## Ao lançar uma skill (não a de graça): Urro/Frenesi (D1), Ataque da Fera (R1 arco), Dardo de Caça (R2 lança), avanço (A1).
static func on_cast(sim: WorldSim, e: SimEntity, s: SkillDef, aim: Vector3) -> void:
	if of(e).is_empty() or face(e) == "" or sim.signature_casting:
		return
	match fid(e):
		"inquisidor+batalha":
			if _holy(s):                         # magia sagrada: Aurora (+ATK e +MATK por alguns segundos, renova)
				var a := num(e, "aurora")
				e.put_buff({"id": AURORA_BUFF, "remaining": Balance.FUSION_AURORA_TIME, "atk_pct": a, "matk_pct": a})
				e.recompute_stats()
				count(e, "aurora")
		"guardiao_verde+fera":
			if face(e) == "guardiao_verde" and s.id == "dru_bellow":
				var wolf: MonsterDef = GameData.monsters.get("spirit_wolf")
				if wolf:
					for i in range(Balance.FUSION_WOLF_COUNT):
						sim.spawn_summon(e, wolf, e.position + Vector3(1.2 * (i * 2 - 1), 0, 1.0), num(e, "wolf_t"), true)
				var fb := SimEntity.scaled_bonus(GameData.skills["dru_frenzy"].effects["buff"], num(e, "fr_str") / 100.0)
				fb["id"] = "fus_pack_frenzy"
				for o: SimEntity in sim.maps[e.map_id]["entities"]:
					if o.is_character() and o.is_alive() and e.is_friend(o) and o.position.distance_to(e.position) <= Balance.FUSION_PACK_RANGE:
						var b := fb.duplicate()
						b["remaining"] = float(fb.get("duration", 8.0))
						o.put_buff(b)
						o.recompute_stats()
				count(e, "bellow")
			elif face(e) == "fera" and s.id == "dru_frenzy":
				for o: SimEntity in sim.maps[e.map_id]["entities"]:
					if o.kind == SimEntity.Kind.MONSTER and o.is_alive() and e.is_hostile_to(o) and o.position.distance_to(e.position) <= Balance.FUSION_TAUNT_RANGE:
						MobSystem.taunt(sim, o, e, Balance.FUSION_TAUNT_TIME)
				count(e, "howl")
		"cacador+atirador":
			if face(e) == "cacador" and s.id == "ran_sic":
				_free_cast(sim, e, "ran_frost_trap", aim, 1.0)
				count(e, "trap")
		"atirador+lanceiro":
			if face(e) == "lanceiro" and s.id == "ran_javelin":
				var to := aim - e.position
				to.y = 0.0
				e.fus["stake"] = e.position + to.limit_length(s.range)
				e.fus["stake_until"] = sim.time + Balance.FUSION_POST_TIME
				count(e, "stake")
		"laminas+duelista":
			if s.effects.has("dash"):
				ghost(sim, e)

## A1: avançar (skill de avanço ou o dash) ou esquivar deixa a próxima facada "furtiva".
static func ghost(sim: WorldSim, e: SimEntity) -> void:
	if not active(e, "laminas+duelista") or sim.time < float(e.fus.get("ghost_at", 0.0)):
		return
	e.fus["ghost_at"] = sim.time + num(e, "ghost_icd")
	e.fus["ghost_until"] = sim.time + Balance.FUSION_GHOST_TIME

## Bloqueio (com escudo): P1 face escudo (Juramento cheio pode atordoar), P3 (Penitência no atacante).
static func on_block(sim: WorldSim, e: SimEntity, attacker: SimEntity) -> void:
	if of(e).is_empty() or face(e) == "" or attacker == null or not attacker.is_alive() or not e.is_hostile_to(attacker):
		return
	match fid(e):
		"guardiao+cruzado":
			if face(e) == "guardiao" and ShieldSystem.oath_stacks(sim, e) >= ClassTalentSystem.oath_max(e) and sim.time >= float(e.fus.get("stun_at", 0.0)) \
					and sim.rng.randf() * 100.0 < num(e, "stun_ch"):
				e.fus["stun_at"] = sim.time + Balance.FUSION_STUN_ICD
				sim._apply_effects(e, attacker, {"stun": {"duration": Balance.FUSION_BLOCK_STUN}}, 1.0)
				count(e, "block_stun")
		"templario+guardiao":
			if sim.time >= float(e.fus.get("block_pen_at", 0.0)):
				e.fus["block_pen_at"] = sim.time + Balance.FUSION_BLOCK_ICD
				var le: Dictionary = e.stats.legend if str(e.stats.legend.get("kind", "")) == "penance" else {"pct": num(e, "pen_pct"), "stacks": 5, "radius": Balance.FUSION_BURST_RADIUS}
				LegendEffects.penance_hit(sim, e, attacker, le)
				count(e, "block_pen")

## A Penitência de `e` explodiu em `t` (arma do Templário ou Fusão): P2 face escudo atordoa, P3 dá Juramento.
static func on_penance_burst(sim: WorldSim, e: SimEntity, t: SimEntity) -> void:
	if of(e).is_empty() or face(e) == "":
		return
	match fid(e):
		"cruzado+templario":
			if t.is_alive():                    # explodiu: volta a FUSION_PEN_KEEP cargas (o bônus de dano não zera)
				t.put_debuff({"kind": "penance", "id": "legend_penance_%d" % e.id, "remaining": Balance.LEG_PENANCE_TIME, "stacks": Balance.FUSION_PEN_KEEP})
			if face(e) == "templario" and t.is_alive() and sim.time >= float(e.fus.get("pen_stun_at", 0.0)):
				e.fus["pen_stun_at"] = sim.time + Balance.FUSION_PEN_STUN_ICD
				sim._apply_effects(e, t, {"stun": {"duration": num(e, "pen_stun")}}, 1.0)
				count(e, "pen_stun")
			count(e, "pen_burst")
		"templario+guardiao":
			var st := mini(ShieldSystem.oath_stacks(sim, e) + Balance.FUSION_OATH_FROM_PEN, ClassTalentSystem.oath_max(e))
			e.put_buff({"id": "juramento", "remaining": Balance.SHIELD_OATH_TIME, "stacks": st})
			count(e, "pen_oath")

## Esquivou um golpe direto: B2 (Peso; face machado contra-ataca), B3 (2 de Frenesi; cheio contra-ataca), A1.
static func on_dodge(sim: WorldSim, e: SimEntity, attacker: SimEntity) -> void:
	if of(e).is_empty() or face(e) == "":
		return
	match fid(e):
		"executor+punhos":
			_weight(sim, e)
			if face(e) == "executor":
				_counter(sim, e, attacker, num(e, "counter"))
		"punhos+carniceiro":
			_frenzy(sim, e, 2, num(e, "frenzy"), num(e, "eva2"))
			if _stack(e, "fus_frenzy") >= Balance.FUSION_FRENZY_MAX:
				_counter(sim, e, attacker, num(e, "counter"))
		"laminas+duelista":
			ghost(sim, e)

## Levou um golpe direto: D3 face Urso (a Pele de Carvalho cobre também o aliado mais ferido).
static func on_hit_taken(sim: WorldSim, attacker: SimEntity, e: SimEntity) -> void:
	if not active(e, "xama+guardiao_verde") or face(e) != "guardiao_verde" or sim.time < float(e.fus.get("bark_at", 0.0)):
		return
	var ally := sim.most_hurt_friend(e, Balance.FUSION_BARK_RANGE)
	if ally == e:
		return
	e.fus["bark_at"] = sim.time + num(e, "bark_icd")
	var oak: Dictionary = GameData.skills["dru_oak_skin"].effects
	sim._apply_effects(e, ally, {"shield": oak.get("shield"), "buff": oak.get("buff")}, 1.0)
	count(e, "bark")

## Abate (antes de limpar os debuffs do morto): N1 (abate de invocação cura o dono), N2 (amaldiçoado explode).
static func on_kill(sim: WorldSim, dead: SimEntity, killer: SimEntity) -> void:
	if killer == null or dead.kind != SimEntity.Kind.MONSTER:
		return
	var owner := summon_owner(sim, killer)
	if owner != null and active(owner, "invocador+ceifador"):
		sim._heal(owner, owner, int(owner.stats.max_hp * num(owner, "reap") / 100.0))
		count(owner, "reap")
	var who: SimEntity = owner if owner != null else killer
	if active(who, "ceifador+pestilento") and _curses(who, dead) > 0 and not sim.signature_casting:
		_free_cast(sim, who, "nec_corpse_explosion", dead.position, num(who, "ce") / 100.0)
		count(who, "corpse")

## Bots: peso extra de uma skill para disparar a Fusão (E1 Vapor: gelo no alvo que queima com o seu fogo). 1.0 = nada.
static func bot_skill_mult(e: SimEntity, t: SimEntity, s: SkillDef) -> float:
	if t == null or face(e) == "":
		return 1.0
	if fid(e) == "fogo+gelo" and _is_frost(s) and s.power > 0.0 and not _own_dot(e, t, "fire").is_empty():
		return Balance.BOT_FUSION_SCORE
	return 1.0

## Bots: skill que a Fusão precisa na barra (E1 Vapor: a 1ª de gelo com dano que o bot aprendeu e a arma permite), ou null.
static func bot_slot_skill(e: SimEntity) -> SkillDef:
	if not active(e, "fogo+gelo"):
		return null
	var build := e.class_def.build_by_id(e.build_id)
	for sid in build.get("skills", []) + e.learned.keys():
		var s: SkillDef = GameData.skills.get(sid)
		if s != null and e.learned.has(sid) and _is_frost(s) and s.power > 0.0 and not s.ascension and e.stats.meets(s.requires):
			return s
	return null

## Gancho novo: a cura passou do máximo (Bi1). `excess` = o que sobrou acima do HP máximo.
static func on_overheal(sim: WorldSim, src: SimEntity, target: SimEntity, excess: float) -> void:
	if excess < 1.0 or not active(src, "sacerdote+inquisidor"):
		return
	var sec := floorf(sim.time)
	if float(src.fus.get("ovh_sec", -1.0)) != sec:
		src.fus["ovh_sec"] = sec
		src.fus["ovh_used"] = 0.0
	var room: float = num(src, "ovh_cap") * src.stats.matk - float(src.fus["ovh_used"])
	var dmg := minf(excess * num(src, "ovh") / 100.0, room)
	if dmg < 1.0:
		return
	var foe := _nearest_foe(sim, src, target, Balance.FUSION_OVH_RANGE)
	if foe == null:
		return
	src.fus["ovh_used"] = float(src.fus["ovh_used"]) + dmg
	Events.post(&"skill_effect", "bis_smite", target.position, foe.position, 0.5)
	sim._deal_damage(src, foe, int(dmg), false, false, "fusion")      # não é "magical": não gera Radiância (trava do laço)
	count(src, "overheal")

## Gancho novo (por mapa, 1 vez por segundo): posto da R2 — aliados perto da torreta (face rifle) ou da Estaca
## (face lança) regeneram regen%/s do HP; dois postos não somam.
static func tick(sim: WorldSim, m: Dictionary) -> void:
	var sec := floorf(sim.time)
	if float(m.get("fus_tick", -1.0)) == sec:
		return
	m["fus_tick"] = sec
	var healed := {}
	for e: SimEntity in m["entities"]:
		if not e.is_character() or not active(e, "atirador+lanceiro"):
			continue
		var posts: Array = []
		if face(e) == "atirador":
			for tu in RangerAscension.turrets_of(sim, e):
				posts.append(tu.position)
		elif sim.time < float(e.fus.get("stake_until", -1.0)):
			posts.append(e.fus["stake"])
		for at in posts:
			for o: SimEntity in m["entities"]:
				if o.is_character() and o.is_alive() and e.is_friend(o) and not healed.has(o.id) and o.position.distance_to(at) <= Balance.FUSION_POST_RADIUS:
					healed[o.id] = true
					if o.hp < o.stats.max_hp:
						sim._heal(e, o, maxi(1, int(o.stats.max_hp * num(e, "regen") / 100.0)))
						count(e, "post")
