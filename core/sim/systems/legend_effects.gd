class_name LegendEffects
extends RefCounted
## Efeitos das armas lendárias (`legend` de cada build + Balance.LEGEND_NUMBERS): ao acertar, ao bater com a arma, ao abater.

## Multiplicador de dano da arma lendária no alvo (Carrasco: pouca vida; Presa Acuada: lento/preso/atordoado;
## Ferida Aberta: feridas que você abriu nele).
static func legend_power(sim: WorldSim, e: SimEntity, t: SimEntity) -> float:
	var le: Dictionary = e.stats.legend if e.is_character() else {}
	match str(le.get("kind", "")):
		"execute":
			if t.hp < t.stats.max_hp * (float(le.get("below", 0.3)) + FusionEffects.exec_up(e)):      # Ápice do Cadafalso sobe o limiar
				return 1.0 + float(le["pct"]) / 100.0
		"prey":
			if Combat.is_chilled(t):
				return 1.0 + float(le["pct"]) / 100.0
		"open_wound":                 # Lanceiro: cada Ferida Aberta que você abriu no alvo = +pct% do seu dano nele
			var n := wounds(e, t)
			if n > 0:
				return 1.0 + float(le["pct"]) * n / 100.0
	return 1.0

## Feridas Abertas (arma do Lanceiro) que `e` abriu em `t`.
static func wounds(e: SimEntity, t: SimEntity) -> int:
	var did := "legend_wound_%d" % e.id
	for d in t.debuffs:
		if d.get("id") == did:
			return int(d.get("stacks", 0))
	return 0

## Ferida Aberta: o golpe abre mais uma (até `max`, somem juntas em LEG_WOUND_TIME s sem golpe); com todas abertas o
## alvo sangra `bleed`% do ATK por segundo (renova a cada golpe).
static func wound_hit(sim: WorldSim, e: SimEntity, t: SimEntity, le: Dictionary) -> void:
	var n := mini(int(le.get("max", 5)), wounds(e, t) + 1)
	t.put_debuff({"kind": "wound", "id": "legend_wound_%d" % e.id, "remaining": Balance.LEG_WOUND_TIME, "stacks": n})
	if n >= int(le.get("max", 5)):
		var bid := "legend_wound_bleed_%d" % e.id
		var bdps: float = maxf(1.0, e.stats.patk * float(le.get("bleed", 8.0)) / 100.0) * e.stats.dot_mult()
		t.put_debuff({"kind": "dot", "id": bid, "remaining": Balance.LEG_WOUND_TIME, "dps": bdps, "src": e.id, "bleed": true})
		var wj := PieceEffects.wake(e, "jump")          # Ferida Aberta Desperta: o sangramento salta para um vizinho
		if not wj.is_empty():
			var o := PieceEffects.nearest_foe(sim, e, t, Balance.LEG50_FOE_RANGE)
			if o != null:
				o.put_debuff({"kind": "dot", "id": bid, "remaining": Balance.LEG_WOUND_TIME, "dps": bdps * float(wj["pct"]) / 100.0, "src": e.id, "bleed": true})

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
	if e.build_id != "" and e.class_def.build_by_id(e.build_id).has("signature"):
		return e.build_id
	var wt: String = e.stats.weapon_type if e.stats else ""
	var best := ""
	var best_n := -1
	for b in e.class_def.builds:
		var bid: String = b.get("id", "")
		if not b.has("signature"):
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
	if e.class_def == null:
		return ""
	return str(e.class_def.build_by_id(signature_build(e)).get("signature", {}).get("skill", ""))

## Chance (%) de o golpe (básico ou skill) lançar a magia-assinatura `sid` (a arma lendária com a mesma magia soma).
static func signature_chance(e: SimEntity, basic: bool, sid: String) -> float:
	var chance: float = Balance.SIGNATURE_BASIC_PCT + floorf(e.level / 5.0) * Balance.SIGNATURE_BASIC_PER5 if basic else Balance.SIGNATURE_SKILL_PCT
	var le: Dictionary = e.stats.legend if e.stats else {}
	if str(le.get("kind", "")) == "cast_on_basic" and str(le.get("skill", "")) == sid:
		chance += float(le.get("chance", 0.0))       # arma lendária com a mesma magia: soma no ataque e nas habilidades
	return chance

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
	var chance := signature_chance(e, s.id.begins_with("basic_"), sid)
	if not sim.signature_force and sim.rng.randf() * 100.0 >= chance:
		return
	e.sig_ready_at = sim.time + Balance.SIGNATURE_ICD
	sim.signature_casting = true
	sim.power_scale = Balance.SIGNATURE_POWER * float(Balance.SIGNATURE_BUILD_POWER.get(signature_build(e), 1.0))     # peso por build (dps_probe)
	legend_cast(sim, e, sid, t.position)
	PieceEffects.after_signature(sim, e, t, sid)        # Brasa Viva / Lua Cheia Despertas
	sim.power_scale = 1.0
	sim.signature_casting = false

## Efeitos da arma lendária ao acertar (golpe direto de quem a usa). `s` = skill do golpe (o básico começa com "basic_").
static func legend_on_hit(sim: WorldSim, e: SimEntity, t: SimEntity, s: SkillDef, amount: int) -> void:
	if amount > 0 and e.is_character() and not e.stats.shield_passive.is_empty() and e.is_hostile_to(t):
		determination_attack(sim, e)            # escudo lendário: atacar junta Determinação (com recarga)
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
				var keep := sim.power_scale
				var wp := PieceEffects.wake(e, "power")        # Castigo Sagrado Desperto
				if not wp.is_empty():
					sim.power_scale = keep * (1.0 + float(wp["pct"]) / 100.0)
				legend_cast(sim, e, str(le["skill"]), t.position)
				sim.power_scale = keep
				sim.signature_casting = false
		"chain":
			if single and not own_cast:
				var left: int = int(le.get("targets", 1))
				for o: SimEntity in sim.maps[e.map_id]["entities"]:
					if left <= 0:
						break
					if o != t and o.is_alive() and e.is_hostile_to(o) and o.position.distance_to(t.position) <= Balance.LEG_CHAIN_RANGE:
						sim._deal_damage(e, o, maxi(1, int(amount * float(le["pct"]) / 100.0)), false, false, "chain")
						left -= 1
		"splash":
			if single and not own_cast:
				var sk: float = float(le["pct"]) / 100.0
				var scrit := false
				if not PieceEffects.wake(e, "chill").is_empty() and (Combat.is_chilled(t) or t.debuffs.any(func(d): return d.get("kind") == "root")):
					sk *= e.stats.crit_mult()        # Pólvora Desperta: em alvo retardado/preso a explosão é crítica
					scrit = true
				for o: SimEntity in sim.maps[e.map_id]["entities"]:
					if o != t and o.is_alive() and e.is_hostile_to(o) and o.position.distance_to(t.position) <= float(le.get("radius", 2.5)):
						sim._deal_damage(e, o, maxi(1, int(amount * sk)), scrit, false, "splash")
		"stun":
			if t.is_alive() and sim.time >= e.legend_ready_at and sim.rng.randf() * 100.0 < float(le["chance"]) + FusionEffects.stun_bonus(e):
				e.legend_ready_at = sim.time + float(le.get("icd", 6.0))
				sim._apply_effects(e, t, {"stun": {"duration": float(le["dur"])}}, 0.0)
				FusionEffects.judge(sim, e, t)          # Ápice do Veredito: a rolagem que passa julga (mesmo se o chefe resistir)
				PieceEffects.on_event(sim, e, "stun_proc", t)     # botas do Cruzado 50 (Julgado)
				var ws := PieceEffects.wake(e, "splash")          # Julgamento Desperto: comuns em volta (chefe nunca)
				if not ws.is_empty():
					var left := Balance.LEG50_STUN_SPLASH_MAX
					for o: SimEntity in sim.maps[e.map_id]["entities"]:
						if left <= 0:
							break
						if o != t and o.is_alive() and e.is_hostile_to(o) and not (o.monster_def != null and o.monster_def.is_boss) \
								and o.position.distance_to(t.position) <= Balance.LEG50_STUN_SPLASH + o.radius:
							sim._apply_effects(e, o, {"stun": {"duration": float(ws["dur"])}}, 0.0)
							left -= 1
		"frenzy":
			var n: int = mini(int(le.get("max", 5)), e.buff_stacks("legend_frenzy") + 1)
			e.put_buff({"id": "legend_frenzy", "remaining": Balance.LEG_FRENZY_TIME, "stacks": n, "aspd_pct": float(le["pct"]) * n})
			e.recompute_stats()
			var we := PieceEffects.wake(e, "echo")          # Frenesi Desperto: cheio, às vezes bate de novo
			if not we.is_empty() and n >= int(le.get("max", 5)) and t.is_alive() and sim.rng.randf() * 100.0 < float(we["chance"]):
				sim._deal_damage(e, t, maxi(1, int(amount * float(we["pct"]) / 100.0)), false, false, "echo")
		"bleed", "poison":
			if t.is_alive() and sim.rng.randf() * 100.0 < float(le["chance"]):
				legend_dot(sim, e, t, le)
		"spare_shot":                       # Bala na Agulha (Corsário): o golpe às vezes dispara a pistola de graça no alvo
			if single and not own_cast and t.is_alive() and e.is_hostile_to(t) and e.stats.offhand_type == "pistol" \
					and sim.time >= e.shot_ready_at and sim.rng.randf() * 100.0 < float(le["chance"]):
				e.shot_ready_at = sim.time + maxf(0.2, Balance.LEG_SHOT_ICD - float(PieceEffects.wake(e, "quick").get("icd_cut", 0.0)))
				spare_shot(sim, e, t, float(le["pct"]))
		"mark":
			if t.is_alive():
				sim._apply_effects(e, t, {"curse": {"id": "legend_mark", "duration": 4.0, "taken_pct": float(le["pct"])}}, 0.0)
		"mend":                             # Mão que Cura (Clérigo de Batalha): o golpe cura o aliado mais ferido
			if e.is_hostile_to(t):
				var wm := PieceEffects.wake(e, "overflow")       # Mão que Cura Desperta: o que passa do máximo vira barreira
				var mf: SimEntity = sim.most_hurt_friend(e, Balance.RADIANCE_RANGE) if not wm.is_empty() else null
				var miss: float = mf.stats.max_hp - mf.hp if mf != null else 0.0
				sim.mend(e, amount, float(le["pct"]) / 100.0)
				if mf != null:
					var over: float = amount * float(le["pct"]) / 100.0 * (Balance.MEND_SELF_MULT if mf == e else 1.0) - miss
					if over > 0.0:
						PieceEffects.overflow_barrier(mf, over, float(wm["pct"]))
		"penance":                          # Penitência (Templário): cargas no alvo; na última explode em fogo sagrado
			if t.is_alive() and not own_cast and e.is_hostile_to(t):
				penance_hit(sim, e, t, le)
		"open_wound":                       # Ferida Aberta (Lanceiro): golpes direto abrem feridas; a assinatura não conta
			if t.is_alive() and not own_cast and e.is_hostile_to(t):
				wound_hit(sim, e, t, le)
		"holy_edge":                        # Lâmina Justa (espada do Guardião): chance de dano sagrado a mais (conta ameaça)
			if t.is_alive() and not own_cast and e.is_hostile_to(t) and (sim.signature_force or sim.rng.randf() * 100.0 < float(le["chance"])):
				holy_edge(sim, e, t, float(le["pct"]))
				var wo := PieceEffects.wake(e, "oath")          # Lâmina Justa Desperta: +Juramento
				if not wo.is_empty():
					PieceEffects.gain(sim, e, "oath", int(wo["n"]))
		"bulwark":                          # Baluarte (maça/martelo do Paladino): golpe dá barreira, com recarga
			if e.is_hostile_to(t) and sim.time >= e.legend_ready_at:
				e.legend_ready_at = sim.time + float(le.get("icd", 4.0))
				bulwark(sim, e, le)

## Sangue da Matilha / Veneno Letal: dano no tempo da arma no alvo (renova). Desperto (Lobo 50, "copies"): até n cópias,
## a nova entra no lugar da mais antiga.
static func legend_dot(sim: WorldSim, e: SimEntity, t: SimEntity, le: Dictionary) -> void:
	var did := "legend_%s_%d" % [le["kind"], e.id]
	var w := PieceEffects.wake(e, "copies")
	if not w.is_empty():
		var i := int(e.leg50_ready.get("dot_i", 0))
		e.leg50_ready["dot_i"] = (i + 1) % maxi(1, int(w["n"]))
		if i > 0:
			did += "_%d" % i
	t.put_debuff({"kind": "dot", "id": did, "remaining": Balance.LEG_DOT_TIME, "dps": maxf(1.0, e.stats.patk * float(le["pct"]) / 100.0) * e.stats.dot_mult(), "src": e.id})

## Lâmina Justa: `pct`% do ATK em dano sagrado no alvo. Passa por _deal_damage: soma ameaça como qualquer golpe.
static func holy_edge(sim: WorldSim, e: SimEntity, t: SimEntity, pct: float) -> void:
	var r := Combat.calc_damage(e, t, pct / 100.0, SkillDef.Kind.PHYSICAL, sim.rng, e.position)
	sim._deal_damage(e, t, r["amount"], r["crit"], false, "holy_edge", e.position)

## Baluarte: barreira de `pct`% da vida máxima por `time` s. Uma só: renova (fica a maior), não soma com a que já existe.
## A marca `LEG_BULWARK_BUFF` mostra o ícone e o visual; sai quando a barreira acaba (legend_weapon / fim do buff).
static func bulwark(sim: WorldSim, e: SimEntity, le: Dictionary) -> void:
	var time := float(le.get("time", 5.0))
	sim._apply_effects(e, e, {"shield": {"amount_pct_hp": float(le["pct"]), "duration": time}}, 1.0)
	e.put_buff({"id": Balance.LEG_BULWARK_BUFF, "remaining": time})
	Events.post(&"buff_applied", e.id, Balance.LEG_BULWARK_BUFF, time)
	var wa := PieceEffects.wake(e, "ally")          # Baluarte Desperto (Guardião): cobre o aliado mais ferido
	if not wa.is_empty():
		var ally := PieceEffects.most_hurt_other(sim, e, e, Balance.LEG50_ALLY_RANGE)
		if ally != null:
			sim._apply_effects(e, ally, {"shield": {"amount_pct_hp": float(le["pct"]) * float(wa["pct"]) / 100.0, "duration": time}}, 1.0)
	var wd := PieceEffects.wake(e, "det")           # Baluarte Desperto (Templário): +Determinação
	if not wd.is_empty() and not e.stats.shield_passive.is_empty():
		for i in range(int(wd["n"])):
			determination_gain(sim, e, false)

## Determinação (escudo lendário): +1 carga até `max`; cada carga = +`dmg`% de ATK/MATK e +`heal`% de cura recebida.
## Atacar dá carga no máximo a cada `icd` s e não renova o tempo; levar golpe dá carga e renova (`time` s). Sem golpe recebido
## por `time` s, todas somem (o buff acaba).
static func determination_gain(sim: WorldSim, e: SimEntity, refresh: bool) -> void:
	var dp: Dictionary = e.stats.shield_passive
	var cur: Dictionary = {}
	for b in e.buffs:
		if b.get("id") == Balance.LEG_DETERMINATION_BUFF:
			cur = b
	var old_n := int(cur.get("stacks", 0))
	var n := mini(int(dp.get("max", 5)), old_n + 1)
	if not cur.is_empty() and n == old_n:           # no máximo: o golpe só renova, o ataque só marca a recarga
		if refresh:
			cur["remaining"] = float(dp.get("time", 6.0))
		else:
			cur["atk_at"] = sim.time
		return
	var left: float = float(dp.get("time", 6.0)) if refresh or cur.is_empty() else float(cur["remaining"])
	var atk_at: float = float(cur.get("atk_at", -INF)) if refresh else sim.time
	if n >= int(dp.get("max", 5)) and old_n < n:
		PieceEffects.on_event(sim, e, "det_full")          # escudo do Guardião/Batalha 50
	e.put_buff({"id": Balance.LEG_DETERMINATION_BUFF, "remaining": left, "stacks": n, "atk_at": atk_at,
		"atk_pct": float(dp.get("dmg", 0.0)) * n, "matk_pct": float(dp.get("dmg", 0.0)) * n, "heal_in_pct": float(dp.get("heal", 0.0)) * n})
	e.recompute_stats()
	Events.post(&"buff_applied", e.id, Balance.LEG_DETERMINATION_BUFF, left)

## Atacar com o escudo de Determinação: +1 carga se passou a recarga (`icd`) desde a última carga por ataque.
static func determination_attack(sim: WorldSim, e: SimEntity) -> void:
	var icd := float(e.stats.shield_passive.get("icd", 2.0))
	for b in e.buffs:
		if b.get("id") == Balance.LEG_DETERMINATION_BUFF and sim.time < float(b.get("atk_at", -INF)) + icd:
			return
	determination_gain(sim, e, false)

## Tiro de graça da pistola (Bala na Agulha): `pct`% do ATK no alvo, +1 Bravata. O FX é o do Tiro de Pistola.
static func spare_shot(sim: WorldSim, e: SimEntity, t: SimEntity, pct: float) -> void:
	Events.post(&"skill_effect", "ass_pistol_shot", e.position, t.position, 0.0)
	var r := Combat.calc_damage(e, t, pct / 100.0, SkillDef.Kind.PHYSICAL, sim.rng, e.position)
	sim._deal_damage(e, t, r["amount"], r["crit"], r["blocked"], "shot", e.position)
	sim.gain_bravado(e, 1)

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
	FusionEffects.on_penance_burst(sim, e, t)       # Sentença Ardente (atordoa) / Égide Ardente (Juramento)
	PieceEffects.on_event(sim, e, "penance_burst", t)     # botas do Templário 50
	Events.post(&"skill_effect", "pal_sun_strike", at, at, float(le.get("radius", 2.5)))
	var wz := PieceEffects.wake(e, "zone")          # Penitência Desperta: Chão Sagrado
	var zs: SkillDef = GameData.skills.get("pal_sun_strike")
	if not wz.is_empty() and zs != null:
		TrapSystem.place_zone(sim, e, zs, at, zs.power, {"zone": Balance.HALLOWED_ZONE.merged({"id": "leg50_penance", "duration": float(wz["time"])}, true)})
	var pm := PieceEffects.penance_mult(e)          # escudo do Templário 50: Determinação reforça a explosão
	for o: SimEntity in sim.maps[e.map_id]["entities"].duplicate():
		if o.is_alive() and e.is_hostile_to(o) and o.position.distance_to(at) <= float(le.get("radius", 2.5)) + o.radius:
			var r := Combat.calc_damage(e, o, float(le["pct"]) / 100.0 * pm, SkillDef.Kind.PHYSICAL, sim.rng, at)
			sim._deal_damage(e, o, r["amount"], r["crit"], false, "penance", at)

## Arma lendária: Eco (o golpe direto bate de novo), Retaliação (devolve parte do corpo a corpo recebido). Eco e
## retaliação não disparam a si mesmos.
static func legend_weapon(sim: WorldSim, attacker: SimEntity, target: SimEntity, amount: int, kind: String) -> void:
	if target.shield_hp <= 0.0 and target.is_character() and str(target.stats.legend.get("kind", "")) == "bulwark":
		for b in target.buffs:
			if b.get("id") == Balance.LEG_BULWARK_BUFF:
				target.drop_buff(Balance.LEG_BULWARK_BUFF)          # Baluarte: a barreira acabou, a marca sai junto
				var ww := PieceEffects.wake(target, "wave")      # Baluarte Desperto (Cruzado): onda sagrada ao quebrar
				if not ww.is_empty() and target.is_alive():
					Events.post(&"skill_effect", "pal_sun_strike", target.position, target.position, Balance.LEG50_WAVE_RADIUS)
					for o: SimEntity in sim.maps[target.map_id]["entities"].duplicate():
						if o.is_alive() and target.is_hostile_to(o) and o.position.distance_to(target.position) <= Balance.LEG50_WAVE_RADIUS + o.radius:
							var rw := Combat.calc_damage(target, o, float(ww["pct"]) / 100.0, SkillDef.Kind.PHYSICAL, sim.rng, target.position)
							sim._deal_damage(target, o, rw["amount"], rw["crit"], false, "holy_edge", target.position)
				break
	if amount <= 0 or attacker == target or not (kind in ["physical", "magical", "shatter"]):
		return
	if target.is_character() and target.is_alive() and not target.stats.shield_passive.is_empty() and attacker.is_hostile_to(target):
		determination_gain(sim, target, true)      # levou golpe: +1 Determinação e renova o tempo
	if target.is_character() and target.is_alive() and str(target.stats.legend.get("kind", "")) == "cast_when_hit" and sim.time >= target.legend_ready_at:
		target.legend_ready_at = sim.time + float(target.stats.legend.get("icd", 20.0))      # Coração de Gelo / Casca Viva
		var keep := sim.power_scale
		var wp := PieceEffects.wake(target, "power")         # Coração de Gelo Desperto: a Nova bate mais
		if not wp.is_empty():
			sim.power_scale = keep * (1.0 + float(wp["pct"]) / 100.0)
		legend_cast(sim, target, str(target.stats.legend["skill"]), attacker.position)
		sim.power_scale = keep
		var wa := PieceEffects.wake(target, "ally")          # Casca Viva Desperta: cobre o aliado mais ferido
		var cs: SkillDef = GameData.skills.get(str(target.stats.legend["skill"]))
		if not wa.is_empty() and cs != null:
			var ally := PieceEffects.most_hurt_other(sim, target, target, Balance.FUSION_BARK_RANGE)
			if ally != null:
				sim._apply_effects(target, ally, {"shield": cs.effects.get("shield"), "buff": cs.effects.get("buff")}, 1.0)
	if attacker.is_character() and str(attacker.stats.legend.get("kind", "")) == "echo" and attacker.stats.echo_chance > 0.0 and target.is_alive() and sim.rng.randf() * 100.0 < attacker.stats.echo_chance:
		sim._deal_damage(attacker, target, maxi(1, int(amount * attacker.stats.echo_pct / 100.0)), false, false, "echo")
	if kind == "physical" and target.is_character() and target.is_alive() and attacker.is_alive() and target.stats.thorns_pct > 0.0 \
			and attacker.position.distance_to(target.position) <= Balance.LEG_THORNS_RANGE:
		sim._deal_damage(target, attacker, maxi(1, int(amount * target.stats.thorns_pct / 100.0)), false, false, "thorns")

## Arma lendária no abate: Ceifa cura. (A Legião não depende do abate: legion_on_death.)
static func legend_on_kill(sim: WorldSim, e: SimEntity, mob: SimEntity) -> void:
	var le: Dictionary = e.stats.legend
	match str(le.get("kind", "")):
		"heal_on_kill":
			sim._heal(e, e, int(e.stats.max_hp * float(le["pct"]) / 100.0))
			var wa := PieceEffects.wake(e, "ally")          # Ceifa Desperta: cura o aliado mais ferido também
			if not wa.is_empty():
				var ally := PieceEffects.most_hurt_other(sim, e, e, Balance.LEG50_ALLY_RANGE)
				if ally != null:
					sim._heal(e, ally, maxi(1, int(ally.stats.max_hp * float(wa["pct"]) / 100.0)))

## Legião (arma do Invocador): inimigo dele ou morto-vivo dele que morre a até Balance.LEGION_RAISE_RADIUS m levanta um
## esqueleto no lugar (recarga `icd` da arma; vale o abate de qualquer um, não só o dele).
static func legion_on_death(sim: WorldSim, dead: SimEntity) -> void:
	if dead.kind != SimEntity.Kind.MONSTER and dead.kind != SimEntity.Kind.SUMMON:
		return
	if not sim.maps.has(dead.map_id) or not GameData.monsters.has("skeleton_minion"):
		return
	var r2 := Balance.LEGION_RAISE_RADIUS * Balance.LEGION_RAISE_RADIUS
	for c in sim.maps[dead.map_id]["entities"]:
		if not c.is_character() or not c.is_alive() or c.stats == null:
			continue
		if c.position.distance_squared_to(dead.position) > r2:
			continue
		if str(c.stats.legend.get("kind", "")) != "raise_on_kill" or sim.time < c.legend_ready_at:
			continue
		if dead.kind == SimEntity.Kind.SUMMON:
			if dead.owner_id != c.id:
				continue
		elif not c.is_hostile_to(dead):
			continue
		legion_raise(sim, c, dead.position)

static func legion_raise(sim: WorldSim, e: SimEntity, at: Vector3) -> void:
	var le: Dictionary = e.stats.legend
	e.legend_ready_at = sim.time + float(le.get("icd", 12.0))
	var sk := sim.spawn_summon(e, GameData.monsters["skeleton_minion"], at, float(le.get("time", 15.0)), true)
	var wp := PieceEffects.wake(e, "pet")          # Legião Desperta: o esqueleto bate mais
	if sk != null and not wp.is_empty():
		sk.buffs.append({"pet_atk_pct": float(wp["pct"]), "remaining": float(le.get("time", 15.0))})
		sk.recompute_stats()
