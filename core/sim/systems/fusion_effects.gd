class_name FusionEffects
extends RefCounted
## Efeito de 5 peças dos conjuntos híbridos (Fusões, GDD Ato II R7.1; fichas em design/gdd/ato2-proposals-2026-11-11.md §1.3)
## e dos conjuntos Ápice (design/gdd/apice-sets.md §3). Stats.fusion = números do tier + "face".
## Fusão: a face é a build cuja arma está na mão; arma de nenhum dos dois lados = apagada (face "").
## Ápice (id "apice_<build>"): uma face só, a da build, com a arma (e a mão secundária) dela.
## Ficaram 8 Fusões: P3 (templario+guardiao), Bi3 (batalha+sacerdote), Elementalista e Necromante; as outras 16 viraram Ápices.
## Números em Balance.FUSION_NUMBERS / APEX_NUMBERS / FUSION_* / APEX_*. Ganchos NOVOS na sim (os outros reaproveitam
## gatilhos que já existem): aura em objeto colocado (tick: torreta do Atirador) e golpe de invocação (summon_on_hit).
const NEW_HOOKS := ["post_regen", "summon_on_hit"]
const APEX_PREFIX := "apice_"
## Magias sagradas (Ápice Iluminado): as de HOLY_SPELLS e toda magia do Bispo com dano.
const HOLY_SPELLS := ["bis_smite", "bis_hammer", "bis_divine_hammer"]
## Buff do Ápice Iluminado (Aurora): visual em BuffLooks, ícone no HUD.
const AURORA_BUFF := "fus_aurora"
const TEMPEST_BUFF := "apex_tempest"
const CADENCE_BUFF := "apex_cadence"
const JUDGED := "apex_judged"
## Skills de pistola (Corsário): as que exigem a pistola.
const PISTOL_REQ := "pistol"
## Skills com papel no Ápice (ids de conteúdo).
const THROW_SKILL := "ber_throw_axe"                         # Carniceiro: gasta o Frenesi da Tormenta
const EXEC_SKILLS := ["ber_execute", "ber_decapitate"]       # Executor (bot): só abaixo do limiar
const BELLOW_SKILL := "dru_bellow"                            # Urso: zera a recarga da Casca
const OAK_SKILL := "dru_oak_skin"
const MOON_SKILL := "dru_moonfire"                            # Xamã
const FROST_ARROW := "ran_frost_arrow"                        # Caçador (bot): abre retardando
const JAVELIN := "ran_javelin"                                # Lanceiro (bot): abre retardando
const EYES_SHOT := "ass_between_eyes"                         # Corsário (bot): segura até a salva
const FOCUS_SKILL := "ass_focus"                              # Duelista: Foco do Duelista
const PET_ID := "companion"                                   # Caçador: o lince (o falcão não conta)

# ----------------------------------------------------------------------------
# estado
# ----------------------------------------------------------------------------

## Fusão/Ápice ligado de `e` ({} = nenhum). Invocações usam o do dono (summon_on_hit).
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

## Dono vivo de uma invocação com Fusão/Ápice (ou null).
static func summon_owner(sim: WorldSim, e: SimEntity) -> SimEntity:
	if e == null or e.kind != SimEntity.Kind.SUMMON or e.owner_id < 0:
		return null
	var o: SimEntity = sim.entities.get(e.owner_id)
	return o if o != null and o.is_alive() and not of(o).is_empty() else null

## Build cuja arma está na mão (fits exato primeiro, depois só a arma principal); "" = nenhuma.
## Ápice: só a build dele, e só com a arma E a mão secundária dela (Duelista e Corsário dividem a espada).
static func pick_face(cls: ClassDef, fusion_id: String, wt: String, ot: String) -> String:
	if cls == null:
		return ""
	var apex := fusion_id.begins_with(APEX_PREFIX)
	var pair: PackedStringArray = PackedStringArray([fusion_id.trim_prefix(APEX_PREFIX)]) if apex else fusion_id.split("+")
	for strict in ([true] if apex else [true, false]):
		for bid in pair:
			var b: Dictionary = cls.build_by_id(bid)
			if b.is_empty() or not (wt in b.get("main", [])):
				continue
			var off: Array = b.get("off", [])
			if not strict or (off.is_empty() and (ot == "" or ot in Balance.TITAN_WEAPONS)) or ot in off:
				return bid
	return ""

## Stats: liga o efeito (face pela arma) e os stats que ele dá (esquiva do Punho Implacável; torreta e armadilha do Posto).
static func apply_stats(s: Stats, cls: ClassDef, f: Dictionary) -> void:
	if f.is_empty():
		return
	var out := f.duplicate()
	out["face"] = pick_face(cls, str(f["id"]), s.weapon_type, s.offhand_type)
	s.fusion = out
	if out["face"] == "":
		return
	match str(f["id"]):
		"apice_punhos":
			s.evasion += float(f.get("eva", 0.0))
		"apice_atirador":
			s.turret_max += 1.0
			s.trap_max += float(f.get("trap", 0.0))

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

## Alvo com Fogo Lunar de `e` (marca do Ápice da Maré Lunar).
static func _moonlit(e: SimEntity, t: SimEntity) -> bool:
	return _has_id(t, "fus_moon_%d" % e.id)

static func _has_id(t: SimEntity, did: String) -> bool:
	for d in t.debuffs:
		if d.get("id") == did:
			return true
	return false

## A Mordida/Garras do druida (dano no tempo dele, sem fogo) conta como sangramento.
static func _bitten(e: SimEntity, t: SimEntity) -> bool:
	for d in t.debuffs:
		if d.get("kind") == "dot" and int(d.get("src", -1)) == e.id and not d.get("fire", false):
			return true
	return false

## Magia sagrada: magia do Bispo com dano, ou as de HOLY_SPELLS.
static func _holy(s: SkillDef) -> bool:
	return s != null and (s.id in HOLY_SPELLS or (s.id.begins_with("bis_") and s.kind == SkillDef.Kind.MAGICAL and s.power > 0.0))

static func _shocked(e: SimEntity, t: SimEntity) -> bool:
	return _has_id(t, "fus_shock_%d" % e.id)

static func _has_bleed(t: SimEntity) -> bool:
	for d in t.debuffs:
		if d.get("kind") == "dot" and d.get("bleed", false):
			return true
	return false

## Alvo com uma marca (Marca do Caçador, Predador, Presa do falcão): Combat.taken_pct soma estas até MARK_TAKEN_CAP.
static func _marked(t: SimEntity) -> bool:
	for d in t.debuffs:
		if d.get("kind") == "curse" and d.get("mark", false):
			return true
	return false

static func _is_storm(s: SkillDef) -> bool:
	return s != null and (s.elements.has("storm") or s.vfx == "lightning")

static func _is_frost(s: SkillDef) -> bool:
	return s != null and (s.elements.has("frost") or s.vfx == "ice")

static func _is_fire(s: SkillDef) -> bool:
	return s != null and (s.elements.has("fire") or s.vfx == "fire")

static func _counter(sim: WorldSim, e: SimEntity, attacker: SimEntity, pct: float) -> void:
	if sim.time < float(e.fus.get("counter_at", 0.0)) or not attacker.is_alive() or attacker.position.distance_to(e.position) > Balance.LEG_RIPOSTE_RANGE:
		return
	e.fus["counter_at"] = sim.time + Balance.FUSION_COUNTER_ICD
	sim._deal_damage(e, attacker, maxi(1, int(e.stats.patk * pct / 100.0)), false, false, "riposte")
	count(e, "counter")

## Recargas por alvo ("agony_<id>") vencidas saem do estado (luta longa não acumula chaves).
static func _prune(sim: WorldSim, e: SimEntity) -> void:
	if e.fus.size() < Balance.FUSION_STATE_MAX:
		return
	for k in e.fus.keys():
		if str(k).begins_with("agony_") and float(e.fus[k]) < sim.time:
			e.fus.erase(k)

## Contador por efeito (sondas: o efeito disparou?).
static func count(e: SimEntity, what: String) -> void:
	e.fus["n_" + what] = int(e.fus.get("n_" + what, 0)) + 1
	e.fus["fired"] = int(e.fus.get("fired", 0)) + 1

# ----------------------------------------------------------------------------
# Ápices: regras próprias
# ----------------------------------------------------------------------------

## Executor (Cadafalso): limiar de execução a mais, em fração da vida (0 sem o Ápice). Vale para o Carrasco da arma.
static func exec_up(e: SimEntity) -> float:
	if e == null or not e.is_character() or not active(e, "apice_executor"):
		return 0.0
	return num(e, "exec_up") / 100.0

## Limiar de execução do Executor com o Ápice (fração da vida): base + exec_up. Os bots leem este.
static func exec_line(e: SimEntity) -> float:
	return Balance.APEX_EXEC_BASE / 100.0 + exec_up(e)

## Cruzado (Veredito): chance a mais (p.p.) do Julgamento da arma.
static func stun_bonus(e: SimEntity) -> float:
	return num(e, "stun_ch") if e != null and e.is_character() and active(e, "apice_cruzado") else 0.0

## Cruzado: o alvo fica Julgado (todo o dano de `e` nele +judged%). Vale mesmo se o alvo resistir ao atordoar (chefe).
static func judge(sim: WorldSim, e: SimEntity, t: SimEntity) -> void:
	if not active(e, "apice_cruzado") or t == null or not t.is_alive():
		return
	t.put_debuff({"kind": "fusion", "id": "%s_%d" % [JUDGED, e.id], "remaining": Balance.APEX_JUDGED_TIME})
	count(e, "judged")

## Carniceiro: +`add` de Frenesi da Tormenta (pilha própria; soma com o Frenesi da arma).
static func _tempest(sim: WorldSim, e: SimEntity, add: int) -> void:
	var n: int = mini(Balance.FUSION_FRENZY_MAX, _stack(e, TEMPEST_BUFF) + add)
	e.put_buff({"id": "apex_tempest", "remaining": Balance.APEX_TEMPEST_TIME, "stacks": n, "aspd_pct": num(e, "frenzy") * n})
	e.recompute_stats()
	count(e, "tempest")

## Duelista: +`add` de Cadência; cheia vira Foco do Duelista (a `focus`% da força) e gasta as cargas.
static func _cadence(sim: WorldSim, e: SimEntity, add: int) -> void:
	var n: int = _stack(e, CADENCE_BUFF) + add
	if n < Balance.APEX_CADENCE_MAX:
		e.put_buff({"id": "apex_cadence", "remaining": Balance.APEX_CADENCE_TIME, "stacks": n})
		count(e, "cadence")
		return
	e.drop_buff(CADENCE_BUFF)
	var fb: Dictionary = (GameData.skills[FOCUS_SKILL].effects["buff"] as Dictionary)
	var b := SimEntity.scaled_bonus(fb, num(e, "focus") / 100.0)
	b["remaining"] = Balance.FUSION_FOCUS_TIME
	e.put_buff(b)
	e.recompute_stats()
	count(e, "focus")

## Lâminas: avançar (skill de avanço ou o dash) ou esquivar deixa a próxima facada "furtiva".
static func ghost(sim: WorldSim, e: SimEntity) -> void:
	if not active(e, "apice_laminas") or sim.time < float(e.fus.get("ghost_at", 0.0)):
		return
	e.fus["ghost_at"] = sim.time + num(e, "ghost_icd")
	e.fus["ghost_until"] = sim.time + Balance.FUSION_GHOST_TIME

## Lanceiro: números da Ferida (o maior entre o Ápice e a arma do Lanceiro).
static func _wound_numbers(e: SimEntity) -> Dictionary:
	var le: Dictionary = e.stats.legend
	var mine := {"pct": num(e, "pct"), "max": int(num(e, "max")), "bleed": num(e, "bleed")}
	if str(le.get("kind", "")) != "open_wound":
		return mine
	return {"pct": maxf(mine["pct"], float(le.get("pct", 0.0))), "max": maxi(mine["max"], int(le.get("max", 5))), "bleed": maxf(mine["bleed"], float(le.get("bleed", 0.0)))}

## Atirador (Posto Avançado): a torreta escolhe primeiro um alvo preso, retardado ou marcado no alcance (null = o mais perto).
static func turret_pick(sim: WorldSim, turret: SimEntity, m: Dictionary, r: float) -> SimEntity:
	var o := summon_owner(sim, turret)
	if o == null or not active(o, "apice_atirador"):
		return null
	var best: SimEntity = null
	var bd := r
	for x: SimEntity in m["entities"]:
		if x.is_alive() and turret.is_hostile_to(x):
			var d: float = x.position.distance_to(turret.position)
			if d <= bd and (Combat.is_chilled(x) or _marked(x)):
				bd = d
				best = x
	return best

## Atirador: poder da torreta nova (a que passa do limite normal TURRET_MAX sai a t2_pwr%).
static func turret_power(e: SimEntity, alive: int) -> float:
	if alive >= Balance.TURRET_MAX and active(e, "apice_atirador"):
		return num(e, "t2_pwr") / 100.0
	return 1.0

# ----------------------------------------------------------------------------
# poder (multiplicadores)
# ----------------------------------------------------------------------------

## Ao lançar (poder da skill): Arremesso Brutal (Carniceiro), golpe pesado (Executor), facada furtiva (Lâminas).
static func skill_mult(sim: WorldSim, e: SimEntity, s: SkillDef) -> float:
	if of(e).is_empty() or face(e) == "" or not (s.kind in [SkillDef.Kind.PHYSICAL, SkillDef.Kind.MAGICAL]) or s.power <= 0.0:
		return 1.0
	if sim.signature_casting and not (s.id == THROW_SKILL and fid(e) == "apice_carniceiro"):      # o Arremesso é a assinatura: gasta também quando sai sozinho
		return 1.0
	var mult := 1.0
	match fid(e):
		"apice_carniceiro":
			var n := _stack(e, TEMPEST_BUFF)
			if s.id == THROW_SKILL and n > 0:
				mult *= 1.0 + num(e, "throw") * n / 100.0
				e.drop_buff(TEMPEST_BUFF)
				e.recompute_stats()
				count(e, "throw")
		"apice_executor":
			if s.target == SkillDef.Target.TARGET and not s.id.begins_with("basic_"):
				mult *= 1.0 + num(e, "heavy") / 100.0
				count(e, "heavy")
		"apice_laminas":
			if sim.time < float(e.fus.get("ghost_until", -1.0)):
				e.fus["ghost_until"] = -1.0
				e.fus["ghost_skill"] = s.id
				e.fus["ghost_hit_until"] = sim.time + Balance.FUSION_GHOST_TIME
				mult *= minf(ClassTalentSystem.ambush_mult(e), Balance.FUSION_AMBUSH_MAX)
				count(e, "ghost")
	return mult

## No golpe direto em `t` (com as condições do alvo). Vale também para golpes de invocação (dono com o efeito).
static func hit_mult(sim: WorldSim, e: SimEntity, t: SimEntity, s: SkillDef) -> float:
	var owner := summon_owner(sim, e)
	if owner != null:
		return _summon_mult(sim, owner, e, t)
	if of(e).is_empty() or face(e) == "" or t == null:
		return 1.0
	var m := 1.0
	match fid(e):
		"apice_executor":
			if t.hp < t.stats.max_hp * exec_line(e):
				m *= 1.0 + num(e, "exec_dmg") / 100.0
		"apice_xama":
			if s != null and s.kind == SkillDef.Kind.MAGICAL and _moonlit(e, t):
				m *= 1.0 + num(e, "moon") / 100.0
		"apice_lanceiro":
			if str(e.stats.legend.get("kind", "")) != "open_wound":       # com a arma do Lanceiro vale a dela (legend_power)
				m *= 1.0 + num(e, "pct") * LegendEffects.wounds(e, t) / 100.0
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
## Julgado (Cruzado), alvo sangrando (Lobo).
static func damage_mult(a: SimEntity, t: SimEntity) -> float:
	if a == t or not a.is_character() or a.stats == null or a.stats.fusion.is_empty() or face(a) == "":
		return 1.0
	match fid(a):
		"apice_cruzado":
			if _has_id(t, "%s_%d" % [JUDGED, a.id]):
				return 1.0 + num(a, "judged") / 100.0
		"apice_fera":
			if _has_bleed(t) or _bitten(a, t):
				count(a, "hunt")                     # só contagem (boss_probe FUS)
				return 1.0 + num(a, "hunt") / 100.0
	return 1.0

## Golpe de invocação (lince do Caçador, N3): o dono tem o efeito.
static func _summon_mult(sim: WorldSim, owner: SimEntity, pet: SimEntity, t: SimEntity) -> float:
	if t == null or face(owner) == "":
		return 1.0
	match fid(owner):
		"apice_cacador":
			if _is_pet(pet) and Combat.is_chilled(t):
				return 1.0 + num(owner, "pet") / 100.0
		"pestilento+invocador":
			return 1.0 + num(owner, "minion_curse") * _curses(owner, t) / 100.0
	return 1.0

static func _is_pet(pet: SimEntity) -> bool:
	return pet.monster_def != null and pet.monster_def.id == PET_ID

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
		"apice_carniceiro":
			if (_single(s) or s.id.begins_with("basic_")) and s.id != THROW_SKILL:
				_tempest(sim, e, 1)
		"apice_punhos":
			if crit and e.stats.weapon_type == "claw":
				_counter(sim, e, t, num(e, "counter"))
		"apice_cruzado":
			if s.effects.has("stun") and not own_cast:
				judge(sim, e, t)                 # skill sua que atordoa e acerta (mesmo que o chefe resista)
			elif str(e.stats.legend.get("kind", "")) != "stun" and t.is_alive() and sim.time >= e.legend_ready_at \
					and sim.rng.randf() * 100.0 < num(e, "stun_ch"):
				e.legend_ready_at = sim.time + Balance.APEX_JUDGE_ICD      # sem a arma: o Ápice rola o próprio Julgamento
				sim._apply_effects(e, t, {"stun": {"duration": Balance.APEX_JUDGE_STUN}}, 0.0)
				judge(sim, e, t)
		"apice_xama":
			if s.id == MOON_SKILL and t.is_alive():
				var was := _moonlit(e, t)
				t.put_debuff({"kind": "fusion", "id": "fus_moon_%d" % e.id, "remaining": Balance.FUSION_MOON_TIME})
				count(e, "moon")
				if was and not own_cast:
					_moon_jump(sim, e, t, s)
		"apice_lanceiro":
			if t.is_alive() and not own_cast:
				var le := _wound_numbers(e)
				if str(e.stats.legend.get("kind", "")) != "open_wound":      # a arma do Lanceiro já abre a 1ª
					LegendEffects.wound_hit(sim, e, t, le)
				if Combat.is_chilled(t):
					LegendEffects.wound_hit(sim, e, t, le)
					count(e, "wound2")
		"apice_laminas":
			if s.id == str(e.fus.get("ghost_skill", "")) and sim.time <= float(e.fus.get("ghost_hit_until", -1.0)) and t.is_alive():
				e.fus["ghost_hit_until"] = -1.0
				var pct := num(e, "poison")
				if str(e.stats.legend.get("kind", "")) == "poison":
					pct = maxf(pct, float(e.stats.legend.get("pct", 0.0)))
				t.put_debuff({"kind": "dot", "id": "apex_poison_%d" % e.id, "remaining": Balance.APEX_POISON_TIME, "dps": maxf(1.0, e.stats.patk * pct / 100.0), "src": e.id})
				count(e, "poison")
		"apice_duelista":
			if crit and e.stats.weapon_type == "sword" and sim.time >= float(e.fus.get("cad_at", 0.0)):
				e.fus["cad_at"] = sim.time + Balance.APEX_CADENCE_ICD
				_cadence(sim, e, 1)
		"apice_corsario":
			if e.stats.weapon_type == "sword" and not (PISTOL_REQ in s.requires):
				var full := e.buff_stacks(Balance.BRAVADO_BUFF) >= Balance.BRAVADO_MAX
				if full and t.is_alive() and not own_cast:
					LegendEffects.spare_shot(sim, e, t, num(e, "shot"))
					e.drop_buff(Balance.BRAVADO_BUFF)            # o tiro de graça dá +1: a salva gasta tudo
					count(e, "salvo")
				elif crit and sim.time >= float(e.fus.get("brav_at", 0.0)):
					e.fus["brav_at"] = sim.time + Balance.FUSION_BRAVADO_ICD
					sim.gain_bravado(e, 1)
					count(e, "bravado")
		"fogo+gelo":
			# gelo em alvo que queima com o seu fogo, ou fogo em alvo retardado/gelado (este com recarga: o vapor retarda e não pode se encadear)
			if t.is_alive() and not _own_dot(e, t, "fire").is_empty():
				var by_frost := _is_frost(s)
				var by_fire := not by_frost and _is_fire(s) and Combat.is_chilled(t) and sim.time >= float(e.fus.get("vapor_at", -1.0))
				if by_frost or by_fire:
					if by_fire:
						e.fus["vapor_at"] = sim.time + Balance.FUSION_VAPOR_ICD
					var left := sim.consume_burns(e, t)
					_burst(sim, e, t.position, int(left * num(e, "quench") / 100.0), Balance.FUSION_VAPOR_RADIUS)
					sim._apply_effects(e, t, {"slow": {"pct": Balance.FUSION_VAPOR_SLOW, "duration": Balance.FUSION_VAPOR_TIME, "frost": true}}, 0.0)
					count(e, "vapor")
					var sub := "n_vapor_fire" if by_fire else "n_vapor_frost"      # só para a sonda (não conta em "fired")
					e.fus[sub] = int(e.fus.get(sub, 0)) + 1
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

## Xamã: Fogo Lunar em alvo já marcado lança um de graça (jump% do poder) no inimigo mais perto; o de graça não salta.
static func _moon_jump(sim: WorldSim, e: SimEntity, t: SimEntity, s: SkillDef) -> void:
	var o := _nearest_foe(sim, e, t, Balance.APEX_MOON_JUMP_RANGE)
	if o == null:
		return
	Events.post(&"skill_effect", MOON_SKILL, t.position, o.position, s.radius)
	var r := Combat.calc_damage(e, o, s.power * num(e, "jump") / 100.0, SkillDef.Kind.MAGICAL, sim.rng, t.position)
	sim._deal_damage(e, o, r["amount"], r["crit"], false, "fusion", t.position)     # não é golpe: não salta de novo
	if o.is_alive():
		o.put_debuff({"kind": "fusion", "id": "fus_moon_%d" % e.id, "remaining": Balance.FUSION_MOON_TIME})
	count(e, "moon_jump")

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

## Gancho: golpe de invocação (lince do Caçador; N3).
static func summon_on_hit(sim: WorldSim, owner: SimEntity, pet: SimEntity, t: SimEntity) -> void:
	if face(owner) == "" or not t.is_alive():
		return
	match fid(owner):
		"apice_cacador":
			if _is_pet(pet):
				var pct := num(owner, "mark")
				if str(owner.stats.legend.get("kind", "")) == "mark":      # a da arma, se for maior (mesma marca: não soma)
					pct = maxf(pct, float(owner.stats.legend.get("pct", 0.0)))
				sim._apply_effects(owner, t, {"curse": {"id": "legend_mark", "duration": 4.0, "taken_pct": pct}}, 0.0)
				count(owner, "pet_mark")
		"pestilento+invocador":
			var key := "agony_%d" % t.id
			if sim.time >= float(owner.fus.get(key, 0.0)):
				_prune(sim, owner)
				owner.fus[key] = sim.time + num(owner, "agony_icd")
				var ag: Dictionary = GameData.skills["nec_curse_agony"].effects
				var dot: Dictionary = (ag["dot"] as Dictionary).duplicate()
				dot["dps"] = float(dot.get("dps", 5)) * Balance.FUSION_AGONY_POWER
				dot["skill"] = "fus_agony"          # teto de cópias próprio, separado da Agonia lançada
				var cu: Dictionary = (ag["curse"] as Dictionary).duplicate()
				cu["taken_pct"] = float(cu.get("taken_pct", 0)) * Balance.FUSION_AGONY_POWER
				sim._apply_effects(owner, t, {"dot": dot, "curse": cu}, 1.0)
				count(owner, "agony")

## Ao lançar uma skill (não a de graça): Aurora (Iluminado), Urro zera a Casca (Urso), avanço furtivo (Lâminas).
static func on_cast(sim: WorldSim, e: SimEntity, s: SkillDef, aim: Vector3) -> void:
	if of(e).is_empty() or face(e) == "" or sim.signature_casting:
		return
	match fid(e):
		"apice_inquisidor":
			if _holy(s):                         # magia sagrada: Aurora (+ATK e +MATK por alguns segundos, renova)
				var a := num(e, "aurora")
				e.put_buff({"id": AURORA_BUFF, "remaining": Balance.FUSION_AURORA_TIME, "atk_pct": a, "matk_pct": a})
				e.recompute_stats()
				count(e, "aurora")
		"apice_guardiao_verde":
			if s.id == BELLOW_SKILL:
				e.fus["bark_at"] = 0.0
				count(e, "bellow")
		"apice_laminas":
			if s.effects.has("dash"):
				ghost(sim, e)

## Bloqueio (com escudo): P3 (Penitência no atacante).
static func on_block(sim: WorldSim, e: SimEntity, attacker: SimEntity) -> void:
	if not active(e, "templario+guardiao") or attacker == null or not attacker.is_alive() or not e.is_hostile_to(attacker):
		return
	if sim.time >= float(e.fus.get("block_pen_at", 0.0)):
		e.fus["block_pen_at"] = sim.time + Balance.FUSION_BLOCK_ICD
		var le: Dictionary = e.stats.legend if str(e.stats.legend.get("kind", "")) == "penance" else {"pct": num(e, "pen_pct"), "stacks": 5, "radius": Balance.FUSION_BURST_RADIUS}
		LegendEffects.penance_hit(sim, e, attacker, le)
		count(e, "block_pen")

## A Penitência de `e` explodiu em `t` (arma do Templário ou P3): P3 dá Juramento.
static func on_penance_burst(sim: WorldSim, e: SimEntity, t: SimEntity) -> void:
	if not active(e, "templario+guardiao"):
		return
	var st := mini(ShieldSystem.oath_stacks(sim, e) + Balance.FUSION_OATH_FROM_PEN, ClassTalentSystem.oath_max(e))
	e.put_buff({"id": "juramento", "remaining": Balance.SHIELD_OATH_TIME, "stacks": st})
	count(e, "pen_oath")

## Esquivou um golpe direto: furtivo (Lâminas), 2 de Cadência (Duelista).
static func on_dodge(sim: WorldSim, e: SimEntity, attacker: SimEntity) -> void:
	if of(e).is_empty() or face(e) == "":
		return
	match fid(e):
		"apice_laminas":
			ghost(sim, e)
		"apice_duelista":
			_cadence(sim, e, 2)

## Levou um golpe direto: Urso (a Pele de Carvalho cobre você e o aliado mais ferido; recarga bark_icd).
static func on_hit_taken(sim: WorldSim, attacker: SimEntity, e: SimEntity) -> void:
	if not active(e, "apice_guardiao_verde") or sim.time < float(e.fus.get("bark_at", 0.0)):
		return
	e.fus["bark_at"] = sim.time + num(e, "bark_icd")
	var oak: Dictionary = GameData.skills[OAK_SKILL].effects
	var fx := {"shield": oak.get("shield"), "buff": oak.get("buff")}
	sim._apply_effects(e, e, fx, 1.0)
	var ally := sim.most_hurt_friend(e, Balance.FUSION_BARK_RANGE)
	if ally != null and ally != e:
		sim._apply_effects(e, ally, fx, 1.0)
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
		sim.signature_casting = true
		var keep := sim.power_scale
		sim.power_scale = num(who, "ce") / 100.0
		LegendEffects.legend_cast(sim, who, "nec_corpse_explosion", dead.position)
		sim.power_scale = keep
		sim.signature_casting = false
		count(who, "corpse")

## Bots: peso extra de uma skill para disparar o efeito na hora certa (1.0 = nada; 0.0 = segura a skill).
## E1 Vapor (gelo no alvo que queima), Executor (execução só abaixo do limiar atual), Xamã (Fogo Lunar no alvo marcado),
## Caçador/Lanceiro (abrem retardando), Corsário (com Bravata quase cheia segura o Tiro Entre os Olhos até a salva sair).
static func bot_skill_mult(e: SimEntity, t: SimEntity, s: SkillDef) -> float:
	if t == null or face(e) == "":
		return 1.0
	match fid(e):
		"fogo+gelo":
			if _is_frost(s) and s.power > 0.0 and not _own_dot(e, t, "fire").is_empty():
				return Balance.BOT_FUSION_SCORE
		"apice_executor":
			if s.id in EXEC_SKILLS:
				return Balance.BOT_FUSION_SCORE if t.hp < t.stats.max_hp * exec_line(e) else 1.0
		"apice_xama":
			if s.id == MOON_SKILL and _moonlit(e, t):
				return Balance.BOT_FUSION_SCORE
		"apice_cacador":
			if s.id == FROST_ARROW and not Combat.is_chilled(t):
				return Balance.BOT_FUSION_SCORE
		"apice_lanceiro":
			if s.id == JAVELIN and not Combat.is_chilled(t):
				return Balance.BOT_FUSION_SCORE
		"apice_corsario":
			if s.id == EYES_SHOT and e.buff_stacks(Balance.BRAVADO_BUFF) >= Balance.APEX_BOT_HOLD_BRAVADO:
				return 0.0
	return 1.0

## Bots: skill que o efeito precisa na barra (E1 Vapor: a 1ª de gelo com dano que o bot aprendeu e a arma permite), ou null.
static func bot_slot_skill(e: SimEntity) -> SkillDef:
	if not active(e, "fogo+gelo"):
		return null
	var build := e.class_def.build_by_id(e.build_id)
	for sid in build.get("skills", []) + e.learned.keys():
		var s: SkillDef = GameData.skills.get(sid)
		if s != null and e.learned.has(sid) and _is_frost(s) and s.power > 0.0 and not s.ascension and e.stats.meets(s.requires):
			return s
	return null

## Gancho (por mapa, 1 vez por segundo): Posto Avançado (Atirador) — aliados perto de uma torreta sua regeneram
## regen%/s do HP; duas torretas não somam.
static func tick(sim: WorldSim, m: Dictionary) -> void:
	var sec := floorf(sim.time)
	if float(m.get("fus_tick", -1.0)) == sec:
		return
	m["fus_tick"] = sec
	var healed := {}
	for e: SimEntity in m["entities"]:
		if not e.is_character() or not active(e, "apice_atirador"):
			continue
		for tu in RangerAscension.turrets_of(sim, e):
			for o: SimEntity in m["entities"]:
				if o.is_character() and o.is_alive() and e.is_friend(o) and not healed.has(o.id) and o.position.distance_to(tu.position) <= Balance.FUSION_POST_RADIUS:
					healed[o.id] = true
					if o.hp < o.stats.max_hp:
						sim._heal(e, o, maxi(1, int(o.stats.max_hp * num(e, "regen") / 100.0)))
						count(e, "post")
