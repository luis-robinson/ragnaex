class_name UltimateSystem
extends RefCounted
## Supremas do nível 40 (GDD design/gdd/ultimates-lv40.md): liberação, Carga Suprema (medidor por combate) e o
## lançamento pela tecla R (InputCommand.ultimate). Números em Balance.ULT_* / BOT_ULT_*.
## Estado no SimEntity (não vai no save): ult_charge, ult_combat_t, ult_gap_until, ult_full_at (+ caches ult_ok/ult_role).
## Enche com: dano causado (poder do golpe, sem ATK/DEF/crítico), cura efetiva, dano recebido (% da vida) e um gotejar em
## combate; esvazia fora de combate, zera ao morrer, trocar de mapa e soltar (e não enche por ULT_MIN_GAP s).

# --- liberação e a Suprema da build ---

## Liberada: personagem com nível >= ULT_LEVEL e a ascensão da classe (missão hx_asc_<classe>).
## Ex.: `UltimateSystem.has_ultimate(Sim.player)`.
static func has_ultimate(e: SimEntity) -> bool:
	return e != null and e.is_character() and e.class_def != null and e.level >= Balance.ULT_LEVEL and ProgressionSystem.has_ascension(e)

## A Suprema da build principal (SkillDef com `ultimate`), sem olhar a arma; null se a build não tem.
static func skill_of(sim: WorldSim, e: SimEntity) -> SkillDef:
	if e == null or e.class_def == null:
		return null
	var by_build: Dictionary = GameData.ultimates.get(e.class_def.id, {})
	if by_build.is_empty():
		return null
	var sid: String = by_build.get(ProgressionSystem.main_build(sim, e), "")
	return GameData.skills.get(sid) if sid != "" else null

## A Suprema que sai agora: da build principal e com a arma da build na mão (null = nenhuma).
## Ex.: `UltimateSystem.ultimate_of(Sim, Sim.player)`.
static func ultimate_of(sim: WorldSim, e: SimEntity) -> SkillDef:
	var s := skill_of(sim, e)
	if s == null or not e.stats.meets(s.requires):
		return null
	return s

## Por que a moldura do R está travada ("" = liberada e com Suprema). Texto do jogador (HUD).
static func lock_reason(sim: WorldSim, e: SimEntity) -> String:
	if not has_ultimate(e):
		return "Nível %d e Ascensão" % Balance.ULT_LEVEL
	var s := skill_of(sim, e)
	if s == null:
		return "Sua build ainda não tem Suprema"
	if not e.stats.meets(s.requires):
		return "Arma da build necessária"
	return ""

## Reconfere a liberação e o papel (cache por entidade; o medidor é chamado a cada golpe).
static func refresh(sim: WorldSim, e: SimEntity) -> void:
	e.ult_check_at = sim.time
	e.ult_ok = has_ultimate(e)
	if e.ult_ok:
		e.ult_role = ProgressionSystem.role_of(sim, e)

static func _ok(sim: WorldSim, e: SimEntity) -> bool:
	if e.level < Balance.ULT_LEVEL:
		return false
	if sim.time - e.ult_check_at >= Balance.ULT_REFRESH_S or sim.time < e.ult_check_at:
		refresh(sim, e)
	return e.ult_ok

## Peso do papel: 0 = dano, 1 = cura, 2 = apanhar (Balance.ULT_ROLE_WEIGHTS).
static func weight(e: SimEntity, what: int) -> float:
	var w: Array = Balance.ULT_ROLE_WEIGHTS.get(e.ult_role, Balance.ULT_ROLE_WEIGHTS["dps"])
	return float(w[what])

# --- o medidor ---

## Soma `pts` na carga (nada durante ULT_MIN_GAP). Ao encher avisa (HUD: brilho e som `ult_ready`).
## `capped` = passa pelo teto de ritmo (dano/cura/apanhar gastam o estoque ult_budget; o gotejar não).
static func gain(sim: WorldSim, e: SimEntity, pts: float, capped: bool = true) -> void:
	if pts <= 0.0 or sim.time < e.ult_gap_until or e.ult_charge >= Balance.ULT_MAX:
		return
	if capped:
		pts = minf(pts, e.ult_budget)
		e.ult_budget -= pts
		if pts <= 0.0:
			return
	e.ult_charge = minf(Balance.ULT_MAX, e.ult_charge + pts)
	if e.ult_charge >= Balance.ULT_MAX:
		e.ult_full_at = sim.time
		Events.post(&"ultimate_ready", e.id)

## Dano causado por golpe direto (WorldSim._strike): `power` = poder do golpe antes de ATK/DEF/crítico. Invocação conta
## para o dono × ULT_SUMMON_MULT. Uma ação (mesmo tique, mesma skill) conta até ULT_AOE_TARGETS alvos.
## A própria Suprema (SkillDef.ultimate) nunca enche.
static func on_dealt(sim: WorldSim, a: SimEntity, t: SimEntity, s: SkillDef, power: float) -> void:
	if s == null or s.ultimate or not a.is_hostile_to(t):
		return
	var src := a
	var mult := 1.0
	if a.kind == SimEntity.Kind.SUMMON:
		src = sim.entities.get(a.owner_id)
		mult = Balance.ULT_SUMMON_MULT
		if src == null or not src.is_character():
			return
	elif not a.is_character():
		return
	if not _ok(sim, src):
		return
	src.ult_combat_t = sim.time
	if a.ult_act_tick != sim.tick_count or a.ult_act_skill != s.id:
		a.ult_act_tick = sim.tick_count
		a.ult_act_skill = s.id
		a.ult_act_n = 0
	if a.ult_act_n >= Balance.ULT_AOE_TARGETS:
		return
	a.ult_act_n += 1
	gain(sim, src, Balance.ULT_GAIN_PER_POWER * maxf(0.0, power) * weight(src, 0) * mult)

## Pulso de dano no tempo (`dmg` já aplicado): poder do pulso = dmg / ATK de quem pôs × ULT_DOT_MULT.
## O dano no tempo de uma Suprema (marcado "ult") não enche.
static func on_dot(sim: WorldSim, a: SimEntity, t: SimEntity, dmg: int, d: Dictionary) -> void:
	if dmg <= 0 or d.get("ult", false) or not a.is_hostile_to(t):
		return
	var src := a
	var mult := Balance.ULT_DOT_MULT
	if a.kind == SimEntity.Kind.SUMMON:
		src = sim.entities.get(a.owner_id)
		mult *= Balance.ULT_SUMMON_MULT
		if src == null or not src.is_character():
			return
	elif not a.is_character():
		return
	if not _ok(sim, src):
		return
	src.ult_combat_t = sim.time
	var atk: float = a.stats.patk if d.get("bleed", false) else a.stats.matk
	gain(sim, src, Balance.ULT_GAIN_PER_POWER * float(dmg) / maxf(1.0, atk) * weight(src, 0) * mult)

## Dano recebido de inimigo, depois da DEF e antes de bloqueio/escudo/aparar/cúpula: % da vida × ULT_GAIN_TAKEN, no
## máximo ULT_TAKEN_HIT_CAP por golpe, × peso de apanhar. Dano redirecionado (Proteção, kind "intercept") não conta.
static func on_taken(sim: WorldSim, a: SimEntity, t: SimEntity, amount: int, kind: String) -> void:
	if amount <= 0 or kind == "intercept" or a == t or t.level < Balance.ULT_LEVEL or not _ok(sim, t) or not a.is_hostile_to(t):
		return
	t.ult_combat_t = sim.time
	var pct := 100.0 * float(amount) / maxf(1.0, t.stats.max_hp)
	gain(sim, t, minf(Balance.ULT_TAKEN_HIT_CAP, Balance.ULT_GAIN_TAKEN * pct) * weight(t, 2))

## Cura efetiva (sem a sobrecura) em aliado em combate: efetiva / (cura de poder 1,0 do próprio lançador) × peso.
## `sim.ult_quiet` (poção) não conta.
static func on_heal(sim: WorldSim, src: SimEntity, t: SimEntity, effective: float) -> void:
	if effective <= 0.0 or sim.ult_quiet or src == null or not src.is_character() or not _ok(sim, src):
		return
	if t.combat_timer <= 0.0 and src.combat_timer <= 0.0:
		return                                    # cura fora de luta (encher a vida) não enche a carga
	src.ult_combat_t = sim.time
	var ref := maxf(1.0, src.stats.matk * src.stats.heal_power)
	gain(sim, src, Balance.ULT_GAIN_HEAL * effective / ref * weight(src, 1))

## Escudo que absorveu: conta como cura de quem o pôs (SimEntity.shield_src).
static func on_shield_absorb(sim: WorldSim, t: SimEntity, absorbed: float) -> void:
	var src: SimEntity = sim.entities.get(t.shield_src)
	if src != null and src.is_alive():
		on_heal(sim, src, t, absorbed)

## Por tique (personagem de nível >= ULT_LEVEL): goteja em combate e esvazia depois de ULT_DECAY_DELAY s fora dele.
static func tick(sim: WorldSim, e: SimEntity, dt: float) -> void:
	if not _ok(sim, e):
		if e.ult_charge > 0.0:
			zero(e)
		return
	e.ult_budget = minf(Balance.ULT_RATE_BURST, e.ult_budget + Balance.ULT_RATE_CAP * dt)
	var since := sim.time - e.ult_combat_t
	if since <= Balance.ULT_COMBAT_WINDOW:
		gain(sim, e, Balance.ULT_TRICKLE * dt, false)
	elif since > Balance.ULT_DECAY_DELAY and e.ult_charge > 0.0:
		e.ult_charge = maxf(0.0, e.ult_charge - Balance.ULT_DECAY_RATE * dt)
		e.ult_full_at = -1.0

## Zera a carga (morte, troca de mapa).
static func zero(e: SimEntity) -> void:
	e.ult_charge = 0.0
	e.ult_full_at = -1.0

## Trocou de mapa (portal, volta, porta de casa): a carga zera.
static func on_map_change(_sim: WorldSim, e: SimEntity) -> void:
	if e.is_character():
		zero(e)

# --- lançar (tecla R) ---

## Por que a Suprema não sai agora ("" = pode). Texto do jogador.
static func cast_block(sim: WorldSim, e: SimEntity) -> String:
	var why := lock_reason(sim, e)
	if why != "":
		return "Suprema: " + why
	if sim.time < e.ult_gap_until:
		return "Suprema: aguarde %ds" % ceili(e.ult_gap_until - sim.time)
	if e.ult_charge < Balance.ULT_MAX:
		return "Carga Suprema incompleta (%d%%)" % int(e.ult_charge / Balance.ULT_MAX * 100.0)
	var s := ultimate_of(sim, e)
	if s.effects.has("force_form") and UltEffects.form_refused(e, str(s.effects["force_form"])):
		return "Só em forma de %s" % str(SkillDef.FORM_LABELS.get(s.effects["force_form"], s.effects["force_form"])).capitalize()
	if not DruidAscension.form_ok(e, s.requires_form):
		return "%s: só na forma de %s" % [s.name, SkillDef.FORM_LABELS.get(s.requires_form, s.requires_form)]
	if e.has_debuff("root") and (s.effects.has("dash") or s.effects.has("hop_strikes")):
		return "Preso: %s não sai" % s.name
	return ""

## R: começa a Suprema (mesmo pipeline de skill: startup/active/recovery). A carga só é gasta quando ela sai (on_fire).
## Ex.: `UltimateSystem.try_cast(Sim, Sim.player, aim, Sim.maps[Sim.player.map_id])`.
static func try_cast(sim: WorldSim, e: SimEntity, aim: Vector3, _m: Dictionary) -> bool:
	var why := cast_block(sim, e)
	if why != "":
		if e == sim.player:
			Events.post(&"notification", why)
		return false
	if e.mounted:
		sim.dismount(e)                         # a Suprema desmonta (como as skills que não saem a cavalo)
	var s := ultimate_of(sim, e)
	if e.form != "" and not DruidAscension.form_mods(s.id, e.form).is_empty():
		s = UltEffects.form_variant(e, s)     # variante da forma (Ceifa das Almas na Demoníaca/Fantasma)
	sim._start_skill(e, s, Balance.ULT_CAST_SLOT, aim)
	return true

## A Suprema saiu (passou do startup): zera, abre ULT_MIN_GAP e marca o grupo (bots não soltam juntos).
static func on_fire(sim: WorldSim, e: SimEntity, s: SkillDef) -> void:
	zero(e)
	e.ult_gap_until = sim.time + Balance.ULT_MIN_GAP
	if e.party_id >= 0 and sim.parties.has(e.party_id):
		sim.parties[e.party_id]["ult_at"] = sim.time
	Events.post(&"ultimate_cast", e.id, s.id)

# --- bots (o BotBrain só pergunta; nada muda aqui) ---

## Raio que a Suprema cobre (para contar bando/aliados): raio da skill, da tempestade ou BOT_ULT_AREA.
static func area_of(s: SkillDef) -> float:
	var r := s.radius
	for k in ["storm", "intercept", "hop_strikes"]:
		if s.effects.get(k) is Dictionary:
			r = maxf(r, float(s.effects[k].get("radius", 0.0)))
	return r if r > 0.0 else Balance.BOT_ULT_AREA

## O bot deve soltar a Suprema agora? (`mob` = alvo da luta). Regras de SkillDef.ult_bot (GDD §3.4).
static func bot_release(sim: WorldSim, e: SimEntity, mob: SimEntity) -> bool:
	if e.ult_charge < Balance.ULT_MAX or sim.time < e.ult_gap_until or not e.can_act() or not sim.maps.has(e.map_id):
		return false
	var s := ultimate_of(sim, e)
	if s == null or cast_block(sim, e) != "":
		return false
	var m: Dictionary = sim.maps[e.map_id]
	var r := area_of(s)
	match s.ult_bot:
		"save":
			return _save_needed(sim, e, m, r)
		"self":
			return _foes_near(e, m, e.position, r) >= Balance.BOT_ULT_PACK or e.hp < e.stats.max_hp * Balance.BOT_ULT_SELF_HP / 100.0
	if mob == null or not mob.is_alive():
		return false
	var big: bool = mob.monster_def != null and (mob.monster_def.is_boss or mob.monster_def.elite_of != "")     # chefe ou elite (Rei)
	var around := _anchor(s, e, mob)            # Suprema em volta de si (SELF/segue o lançador): conta em volta do lançador
	if around == e.position and mob.position.distance_to(e.position) > r + mob.radius:
		return false                              # o alvo está fora da área que sai em volta dele
	if s.target == SkillDef.Target.TARGET and s.range > 0.0 and mob.position.distance_to(e.position) > s.range + mob.radius:
		return false                              # golpe no alvo (Toxina Real, Sete Ventos): só com o alvo no alcance
	if not big and _foes_near(e, m, around, r) < Balance.BOT_ULT_PACK:
		return false
	if not big and sim.player != null and e.party_id >= 0 and e.party_id == sim.player.party_id and sim.time - e.ult_full_at < Balance.BOT_ULT_HOLD:
		return false                              # grupo do jogador: segura esperando o chefe
	if e.party_id >= 0 and sim.parties.has(e.party_id) and sim.time - float(sim.parties[e.party_id].get("ult_at", -1000.0)) < Balance.BOT_ULT_STAGGER:
		return false                              # outro do grupo acabou de soltar
	return true

## Onde a Suprema cai: em volta do lançador (SELF sem ponto, ou tempestade que o segue) ou no alvo (GROUND/TARGET/DIRECTION).
static func _anchor(s: SkillDef, e: SimEntity, mob: SimEntity) -> Vector3:
	var st: Dictionary = s.effects.get("storm", {}) if s.effects.get("storm") is Dictionary else {}
	if s.target == SkillDef.Target.SELF or str(st.get("anchor", "")) == "caster":
		return e.position
	return mob.position

static func _foes_near(e: SimEntity, m: Dictionary, at: Vector3, r: float) -> int:
	var n := 0
	for o: SimEntity in m["entities"]:
		if o.position.distance_squared_to(at) <= (r + o.radius) * (r + o.radius) and o.is_alive() and e.is_hostile_to(o):
			n += 1
	return n

static func _save_needed(sim: WorldSim, e: SimEntity, m: Dictionary, r: float) -> bool:
	var hurt := 0
	for o: SimEntity in m["entities"]:
		if not o.is_character() or not o.is_alive() or o.position.distance_squared_to(e.position) > r * r or not e.is_friend(o):
			continue
		var pct := o.hp / maxf(1.0, o.stats.max_hp) * 100.0
		if pct < Balance.BOT_ULT_SAVE_HP:
			hurt += 1
		if o != e and pct < Balance.BOT_ULT_TANK_HP and ProgressionSystem.role_of(sim, o) == "tank":
			return true
	return hurt >= Balance.BOT_ULT_SAVE_ALLIES
