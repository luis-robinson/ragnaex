class_name LegendEffects
extends RefCounted
## Efeitos das armas lendárias (GearCatalog.LEGEND_EFFECTS): ao acertar, ao bater com a arma, ao abater.

## Multiplicador de dano da arma lendária no alvo (Carrasco: pouca vida; Presa Acuada e Truque Sujo: lento/preso/atordoado;
## Hemorragia: sangrando).
static func legend_power(sim: WorldSim, e: SimEntity, t: SimEntity) -> float:
	var le: Dictionary = e.stats.legend if e.is_character() else {}
	match str(le.get("kind", "")):
		"execute":
			if t.hp < t.stats.max_hp * float(le.get("below", 0.3)):
				return 1.0 + float(le["pct"]) / 100.0
		"prey":
			if Combat.is_chilled(t):
				return 1.0 + float(le["pct"]) / 100.0
		"hemorrhage":                 # Arremessador: alvo sangrando (ou com qualquer dano no tempo) apanha mais
			if t.has_debuff("dot"):
				return 1.0 + float(le["pct"]) / 100.0
		"dirty_trick":                # Trapaceiro: alvo lento, preso ou atordoado apanha mais
			if t.has_debuff("slow") or t.has_debuff("root") or t.state == SimEntity.State.STUNNED:
				return 1.0 + float(le["pct"]) / 100.0
	return 1.0

## Lança uma skill de graça (sem mana nem recarga) a partir de `e`, mirando em `aim`: os efeitos que "lançam" algo.
static func legend_cast(sim: WorldSim, e: SimEntity, skill_id: String, aim: Vector3) -> void:
	var s: SkillDef = GameData.skills.get(skill_id)
	if s == null or not sim.maps.has(e.map_id):
		return
	var keep := e.skill_aim
	e.skill_aim = aim
	sim._apply_skill(e, s, sim.maps[e.map_id])
	e.skill_aim = keep

## Build do personagem para a assinatura: a dos bots (build_id), ou a que mais combina com a arma e as skills aprendidas.
static func signature_build(e: SimEntity) -> String:
	if e.class_def == null:
		return ""
	if e.build_id != "" and ClassesCatalog.SIGNATURES.has(e.build_id):
		return e.build_id
	var wt: String = e.stats.weapon_type if e.stats else ""
	var best := ""
	var best_n := -1
	for b in e.class_def.builds:
		var bid: String = b.get("id", "")
		if not ClassesCatalog.SIGNATURES.has(bid):
			continue
		var n := 0
		if wt != "" and wt in b.get("main", []):
			n += 100                              # a arma decide primeiro (machado duplo x de duas mãos...)
		for sid in e.learned:
			var sk: SkillDef = GameData.skills.get(sid)
			if sk and sk.build == bid:
				n += 1                            # mesma arma (cajado do elementalista): as skills aprendidas desempatam
		if n > best_n:
			best_n = n
			best = bid
	return best

static func signature_skill(e: SimEntity) -> String:
	return str(ClassesCatalog.SIGNATURES.get(signature_build(e), {}).get("skill", ""))

## Efeito-assinatura: ao acertar com o básico (ou, menos, com skills), chance de lançar de graça a magia da build,
## com poder reduzido (SIGNATURE_POWER) e recarga própria. Arma lendária com a mesma magia (Brasa Viva) soma chance.
## O que a assinatura acerta não dispara outra (nem a própria magia, quando lançada pelo jogador, dispara a si mesma).
static func signature_on_hit(sim: WorldSim, e: SimEntity, t: SimEntity, s: SkillDef, amount: int) -> void:
	if not sim.signatures_on or sim.signature_casting or amount <= 0 or not e.is_character() or e.class_def == null or t == null or not t.is_alive() or s == null:
		return
	if sim.time < e.sig_ready_at or not e.is_hostile_to(t):
		return
	var sid := signature_skill(e)
	if sid == "" or s.id == sid:
		return
	var basic := s.id.begins_with("basic_")
	var chance: float = Balance.SIGNATURE_BASIC_PCT + floorf(e.level / 5.0) * Balance.SIGNATURE_BASIC_PER5 if basic else Balance.SIGNATURE_SKILL_PCT
	var le: Dictionary = e.stats.legend if e.stats else {}
	if str(le.get("kind", "")) == "cast_on_basic" and str(le.get("skill", "")) == sid:
		chance += float(le.get("chance", 0.0))       # arma lendária com a mesma magia: soma no ataque e nas habilidades
	if not sim.signature_force and sim.rng.randf() * 100.0 >= chance:
		return
	e.sig_ready_at = sim.time + Balance.SIGNATURE_ICD
	sim.signature_casting = true
	sim.power_scale = Balance.SIGNATURE_POWER * float(ClassesCatalog.SIGNATURES.get(signature_build(e), {}).get("power", 1.0))     # peso por build (dps_probe)
	legend_cast(sim, e, sid, t.position)
	sim.power_scale = 1.0
	sim.signature_casting = false

## Efeitos da arma lendária ao acertar (golpe direto de quem a usa). `s` = skill do golpe (o básico começa com "basic_").
static func legend_on_hit(sim: WorldSim, e: SimEntity, t: SimEntity, s: SkillDef, amount: int) -> void:
	if not e.is_character() or e.stats.legend.is_empty() or amount <= 0 or not t.is_alive() and not (str(e.stats.legend.get("kind", "")) in ["splash", "mend"]):
		return
	var le: Dictionary = e.stats.legend
	var basic: bool = s != null and s.id.begins_with("basic_")
	# vale para o básico e para habilidades; golpe de alvo único (ou quase) para os que espalham dano
	var single: bool = basic or (s != null and s.max_targets <= 2)
	var own_cast: bool = sim.signature_casting or (s != null and s.id == str(le.get("skill", "")))     # a magia lançada pela arma não lança outra
	match str(le.get("kind", "")):
		"cast_on_basic":                    # (nome antigo) lança magia ao acertar com ataque OU habilidade
			if str(le["skill"]) == signature_skill(e):
				pass                                # mesma magia da assinatura: soma chance lá (não dispara duas vezes)
			elif not own_cast and t.is_alive() and sim.time >= e.leg_cast_at and sim.rng.randf() * 100.0 < float(le["chance"]):
				e.leg_cast_at = sim.time + Balance.LEG_CAST_ICD
				sim.signature_casting = true
				legend_cast(sim, e, str(le["skill"]), t.position)
				sim.signature_casting = false
		"chain":
			if single and not own_cast:
				var left: int = int(le.get("targets", 1))
				for o in sim.maps[e.map_id]["entities"]:
					if left <= 0:
						break
					if o != t and o.is_alive() and e.is_hostile_to(o) and o.position.distance_to(t.position) <= Balance.LEG_CHAIN_RANGE:
						sim._deal_damage(e, o, maxi(1, int(amount * float(le["pct"]) / 100.0)), false, false, "chain")
						left -= 1
		"splash":
			if single and not own_cast:
				for o in sim.maps[e.map_id]["entities"]:
					if o != t and o.is_alive() and e.is_hostile_to(o) and o.position.distance_to(t.position) <= float(le.get("radius", 2.5)):
						sim._deal_damage(e, o, maxi(1, int(amount * float(le["pct"]) / 100.0)), false, false, "splash")
		"stun":
			if t.is_alive() and sim.time >= e.legend_ready_at and sim.rng.randf() * 100.0 < float(le["chance"]):
				e.legend_ready_at = sim.time + float(le.get("icd", 6.0))
				sim._apply_effects(e, t, {"stun": {"duration": float(le["dur"])}}, 0.0)
		"frenzy":
			var n: int = mini(int(le.get("max", 5)), e.buff_stacks("legend_frenzy") + 1)
			e.put_buff({"id": "legend_frenzy", "remaining": 4.0, "stacks": n, "aspd_pct": float(le["pct"]) * n})
			e.recompute_stats()
		"bleed", "poison":
			if t.is_alive() and sim.rng.randf() * 100.0 < float(le["chance"]):
				var did := "legend_%s_%d" % [le["kind"], e.id]
				t.put_debuff({"kind": "dot", "id": did, "remaining": 3.0, "dps": maxf(1.0, e.stats.patk * float(le["pct"]) / 100.0), "src": e.id})
		"dirty_trick":                      # golpe baixo: chance de retardar (e aí o próprio efeito bate mais forte)
			if t.is_alive() and sim.rng.randf() * 100.0 < float(le["chance"]):
				sim._apply_effects(e, t, {"slow": {"pct": 30, "duration": 2.0}}, 0.0)
		"mark":
			if t.is_alive():
				sim._apply_effects(e, t, {"curse": {"id": "legend_mark", "duration": 4.0, "taken_pct": float(le["pct"])}}, 0.0)
		"mend":                             # Mão que Cura (Clérigo de Batalha): o golpe cura o aliado mais ferido
			if e.is_hostile_to(t):
				sim.mend(e, amount, float(le["pct"]) / 100.0)
		"penance":                          # Penitência (Templário): cargas no alvo; na última explode em fogo sagrado
			if t.is_alive() and not own_cast and e.is_hostile_to(t):
				penance_hit(sim, e, t, le)

## Penitência: +1 carga no alvo (some em LEG_PENANCE_TIME s sem golpe); com `stacks` cargas, explode: dano mágico de
## `pct`% do ATK em todos os inimigos a `radius` m do alvo (a explosão não põe carga).
static func penance_hit(sim: WorldSim, e: SimEntity, t: SimEntity, le: Dictionary) -> void:
	var did := "legend_penance_%d" % e.id
	var n := 1
	for d in t.debuffs:
		if d.get("id") == did:
			n = int(d.get("stacks", 0)) + 1
	if n < int(le.get("stacks", 5)):
		t.put_debuff({"kind": "penance", "id": did, "remaining": Balance.LEG_PENANCE_TIME, "stacks": n})
		return
	t.debuffs = t.debuffs.filter(func(d): return d.get("id") != did)
	var at := t.position
	Events.skill_effect.emit("pal_sun_strike", at, at, float(le.get("radius", 2.5)))
	for o in sim.maps[e.map_id]["entities"].duplicate():
		if o.is_alive() and e.is_hostile_to(o) and o.position.distance_to(at) <= float(le.get("radius", 2.5)) + o.radius:
			var r := Combat.calc_damage(e, o, float(le["pct"]) / 100.0, SkillDef.Kind.PHYSICAL, sim.rng, at)
			sim._deal_damage(e, o, r["amount"], r["crit"], false, "penance", at)

## Arma lendária: Eco (o golpe direto bate de novo), Retaliação (devolve parte do corpo a corpo recebido). Eco e
## retaliação não disparam a si mesmos.
static func legend_weapon(sim: WorldSim, attacker: SimEntity, target: SimEntity, amount: int, kind: String) -> void:
	if amount <= 0 or attacker == target or not (kind in ["physical", "magical", "shatter"]):
		return
	if target.is_character() and target.is_alive() and str(target.stats.legend.get("kind", "")) == "cast_when_hit" and sim.time >= target.legend_ready_at:
		target.legend_ready_at = sim.time + float(target.stats.legend.get("icd", 20.0))      # Coração de Gelo / Casca Viva
		legend_cast(sim, target, str(target.stats.legend["skill"]), attacker.position)
	if attacker.is_character() and str(attacker.stats.legend.get("kind", "")) == "echo" and attacker.stats.echo_chance > 0.0 and target.is_alive() and sim.rng.randf() * 100.0 < attacker.stats.echo_chance:
		sim._deal_damage(attacker, target, maxi(1, int(amount * attacker.stats.echo_pct / 100.0)), false, false, "echo")
	if kind == "physical" and target.is_character() and target.is_alive() and attacker.is_alive() and target.stats.thorns_pct > 0.0 \
			and attacker.position.distance_to(target.position) <= Balance.LEG_THORNS_RANGE:
		sim._deal_damage(target, attacker, maxi(1, int(amount * target.stats.thorns_pct / 100.0)), false, false, "thorns")

## Arma lendária no abate: Legião levanta um esqueleto (com recarga), Ceifa cura.
static func legend_on_kill(sim: WorldSim, e: SimEntity, mob: SimEntity) -> void:
	var le: Dictionary = e.stats.legend
	match str(le.get("kind", "")):
		"raise_on_kill":
			if sim.time >= e.legend_ready_at and GameData.monsters.has("skeleton_minion"):
				e.legend_ready_at = sim.time + float(le.get("icd", 12.0))
				sim.spawn_summon(e, GameData.monsters["skeleton_minion"], mob.position, float(le.get("time", 15.0)), true)
		"heal_on_kill":
			sim._heal(e, e, int(e.stats.max_hp * float(le["pct"]) / 100.0))
