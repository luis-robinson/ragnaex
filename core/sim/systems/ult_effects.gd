class_name UltEffects
extends RefCounted
## Chaves pequenas das Supremas (GDD ultimates-lv40 §9): "dot_amp", "curse_spread", "pet_revive", buffs com "end_cast"
## e "oath_lock", invocação com "ignore_max" (esta mora no WorldSim._apply_skill). Funções estáticas, sem estado.

# --- dot_amp: os SEUS danos no tempo no alvo valem × mult; no fim detonam e se espalham ---

## Põe (ou renova) a marca de `src` em `t`. d = {"mult", "duration", "detonate", "spread_radius"}.
static func apply_amp(src: SimEntity, t: SimEntity, d: Dictionary) -> void:
	t.put_debuff({"kind": Balance.DOT_AMP_KIND, "id": "dot_amp_%d" % src.id, "src": src.id, "mult": float(d.get("mult", 2.0)),
		"remaining": float(d.get("duration", 8.0)), "detonate": float(d.get("detonate", 0.0)), "spread_radius": float(d.get("spread_radius", 0.0))})

## Pulso de dano no tempo de `src` em `t`: × a marca dele (só a dele).
static func amp(t: SimEntity, src: SimEntity, dmg: int) -> int:
	for d in t.debuffs:
		if d.get("kind") == Balance.DOT_AMP_KIND and int(d.get("src", -1)) == src.id:
			return int(round(float(dmg) * float(d["mult"])))
	return dmg

## A marca acabou (tempo) ou o alvo morreu: os danos no tempo de quem marcou são copiados para inimigos a spread_radius m
## e o resto deles explode de uma vez × detonate (alvo vivo).
static func amp_end(sim: WorldSim, t: SimEntity, d: Dictionary) -> void:
	var src: SimEntity = sim.entities.get(int(d.get("src", -1)))
	if src == null or not sim.maps.has(t.map_id):
		return
	var mine: Array = []
	for x in t.debuffs:
		if x.get("kind") == "dot" and int(x.get("src", -1)) == src.id and float(x.get("remaining", 0.0)) > 0.0:
			mine.append(x)
	if mine.is_empty():
		return
	var sr := float(d.get("spread_radius", 0.0))
	if sr > 0.0:
		for o: SimEntity in sim.maps[t.map_id]["entities"]:
			if o == t or not o.is_alive() or not src.is_hostile_to(o) or o.position.distance_to(t.position) > sr + o.radius:
				continue
			for x in mine:
				var c: Dictionary = x.duplicate()
				c["acc"] = 0.0
				c.erase("pulse")
				if c.get("bleed", false):
					o.put_debuff(c)
				else:
					sim._put_dot(o, c)
	var det := float(d.get("detonate", 0.0))
	if det > 0.0 and t.is_alive():
		var left := 0.0
		for x in mine:
			left += float(x.get("dps", 0.0)) * maxf(0.0, float(x.get("remaining", 0.0))) + float(x.get("acc", 0.0))
			t.debuffs.erase(x)
		if left >= 1.0:
			sim.ult_tag += 1
			sim._deal_damage(src, t, int(left * det), false, false, "detonate")
			sim.ult_tag -= 1

## Morte com marcas: espalham antes de os debuffs sumirem (WorldSim._kill).
static func on_death(sim: WorldSim, e: SimEntity) -> void:
	for d in e.debuffs.duplicate():
		if d.get("kind") == Balance.DOT_AMP_KIND:
			amp_end(sim, e, d)

# --- curse_spread: cópia das SUAS maldições que estão em inimigos perto ---

## `t` recebe cópia de cada maldição de `src` presente em inimigos a `radius` m dele (a que ele já tem fica).
static func curse_spread(sim: WorldSim, src: SimEntity, t: SimEntity, d: Dictionary) -> void:
	if not sim.maps.has(t.map_id):
		return
	var r := float(d.get("radius", 6.0))
	var tail := "_%d" % src.id
	var have := {}
	for x in t.debuffs:
		if x.get("kind") == "curse":
			have[x.get("id")] = true
	for o: SimEntity in sim.maps[t.map_id]["entities"]:
		if o == t or not o.is_alive() or o.debuffs.is_empty() or o.position.distance_to(t.position) > r + o.radius:
			continue
		for x in o.debuffs:
			var cid := str(x.get("id", ""))
			if x.get("kind") == "curse" and cid.ends_with(tail) and not have.has(cid):
				t.put_debuff(x.duplicate())          # renova pelo id, nunca acumula
				have[cid] = true

# --- pet_revive ---

## Companheiro morto volta com a vida cheia; vivo: vida cheia. d = {"skill": "<id da skill que chama o companheiro>",
## "buff": {buff do companheiro (Laço Selvagem)}, "spirit": {"mult", "duration", "buff"} = 2º companheiro espiritual}.
static func pet_revive(sim: WorldSim, e: SimEntity, d: Dictionary) -> SimEntity:
	var pet := _revive(sim, e, d)
	if pet != null and d.get("buff") is Dictionary:
		pet_buff(pet, d["buff"])
	if pet != null and d.get("spirit") is Dictionary:
		spirit_pet(sim, e, pet, d)
	return pet

static func _revive(sim: WorldSim, e: SimEntity, d: Dictionary) -> SimEntity:
	var pet := sim.pet_of(e)
	if pet != null:
		pet.heal_full()
		return pet
	var sk: SkillDef = GameData.skills.get(str(d.get("skill", "")))
	if sk == null or not (sk.effects.get("summon") is Dictionary):
		return null
	var sm: Dictionary = sk.effects["summon"]
	var mdef: MonsterDef = GameData.monsters.get(str(sm.get("monster_id", "")))
	if mdef == null:
		return null
	return sim.spawn_summon(e, mdef, e.position + e.forward() * 1.2, float(sm.get("duration", 0.0)), bool(sm.get("owner_stats", false)))

# --- buffs com fim ---

## Buff com "end_cast" acabou: a skill sai sozinha, grátis, à frente do dono, × "end_power" (WorldSim.power_scale).
## Duelo Supremo: também × (1 + "duel_per" × contador do Duelo), que os aparos e os seus golpes encheram (RiposteSystem).
static func end_cast(sim: WorldSim, e: SimEntity, b: Dictionary) -> void:
	var s: SkillDef = GameData.skills.get(str(b.get("end_cast", "")))
	if s == null or not e.is_alive() or not sim.maps.has(e.map_id):
		return
	if b.get("momentum_fill", false):
		RiposteSystem.gain(e, Balance.RIPOSTE_MOMENTUM_MAX)     # Duelo Supremo: o Golpe de Mestre sai com o Ímpeto cheio
	var keep_aim := e.skill_aim
	var keep_scale := sim.power_scale
	e.skill_aim = e.position + e.forward() * 2.0
	sim.power_scale *= float(b.get("end_power", 1.0)) * (1.0 + float(b.get("duel_per", 0.0)) * int(b.get("duel", 0)))
	Events.post(&"skill_cast", e.id, s.id, "active")
	sim.ult_tag += 1                       # o fecho é parte da Suprema (medição)
	sim._apply_skill(e, s, sim.maps[e.map_id])
	sim.ult_tag -= 1
	sim.power_scale = keep_scale
	e.skill_aim = keep_aim

## Buff com "oath_lock": o Juramento fica cheio e não esfria enquanto ele dura (por tique).
static func oath_lock(e: SimEntity) -> void:
	var mx := ClassTalentSystem.oath_max(e)
	for b in e.buffs:
		if b.get("id") == "juramento":
			b["stacks"] = mx
			b["remaining"] = Balance.SHIELD_OATH_TIME
			return
	e.put_buff({"id": "juramento", "remaining": Balance.SHIELD_OATH_TIME, "stacks": mx})

# --- onda B1 (Paladino, Berserker, Bispo, Druida) ---

## Colosso Primevo: em forma humana vira `form` na hora (a Suprema já recusou as outras formas em UltimateSystem.cast_block).
static func force_form(sim: WorldSim, e: SimEntity, form: String) -> void:
	if e.form == "":
		sim._apply_effects(e, e, {"form": form}, 0.0)

## A forma que pede `force_form` recusa a Suprema? (qualquer outra forma, até a ancestral: Ent não vira Colosso; humano pode)
static func form_refused(e: SimEntity, form: String) -> bool:
	return e.form != "" and e.form != form

## Saiu da forma `was`: buffs presos a ela ("form_bound") acabam. Devolve a % de vida a manter depois do recompute
## (buff com "keep_hp"), ou -1.
static func drop_form_bound(e: SimEntity, was: String) -> float:
	var pct := -1.0
	for b in e.buffs.duplicate():
		if str(b.get("form_bound", "")) != "" and (str(b["form_bound"]) == was or DruidAscension.base_of(was) == str(b["form_bound"])):
			if b.get("keep_hp", false):
				pct = e.hp / maxf(1.0, e.stats.max_hp)
			e.buffs.erase(b)
			Events.post(&"buff_applied", e.id, str(b.get("id", "")), 0.0)
	return pct

## Veredito do Carrasco: rachadura em `stacks` cargas nos inimigos a `radius` m do ponto mirado (o alvo incluso).
static func sunder_fill(sim: WorldSim, e: SimEntity, aim: Vector3, d: Dictionary, m: Dictionary) -> void:
	var r := float(d.get("radius", 3.5))
	var sd: Dictionary = Balance.SUNDER.duplicate()
	sd["add"] = int(d.get("stacks", 5))
	for o: SimEntity in m["entities"]:
		if o.is_alive() and e.is_hostile_to(o) and Vector2(o.position.x - aim.x, o.position.z - aim.z).length() <= r + o.radius:
			SunderSystem.apply(e, o, sd)

## Veredito do Carrasco: multiplicador no alvo abaixo do limiar (chefe: boss_mult).
static func execute_mult(t: SimEntity, d: Dictionary) -> float:
	if t.stats == null or t.hp >= t.stats.max_hp * float(d.get("below", 0.3)):
		return 1.0
	var boss: bool = t.monster_def != null and t.monster_def.is_boss
	return float(d.get("boss_mult", 1.25)) if boss else float(d.get("mult", 1.5))

## Avatar da Fé: cura `power` (x cura de quem lança) em você e nos aliados (personagens/guardas) a `radius` m.
static func ally_heal(sim: WorldSim, e: SimEntity, d: Dictionary, m: Dictionary) -> void:
	var r := float(d.get("radius", 8.0))
	for o: SimEntity in m["entities"]:
		if not o.is_alive() or o.position.distance_to(e.position) > r + o.radius:
			continue
		if o == e or (e.is_friend(o) and (o.is_character() or o.guard)):
			sim._heal(e, o, Combat.calc_heal(e, float(d.get("power", 1.0)), sim.rng))

# --- onda B2 (Ranger, Assassino, Elementalista Gelo/Raio, Necromante) ---

## Buff em invocação/companheiro: vale nos números do bicho (mob_stat: ATK, velocidade, resistência a controle) e
## "scale" faz o boneco crescer (EntityView.buff_scale). Ex.: Laço Selvagem.
static func pet_buff(pet: SimEntity, b: Dictionary) -> void:
	var x := b.duplicate()
	x["remaining"] = float(x.get("duration", 10.0))
	x["mob_stat"] = true
	if x.has("atk_pct"):
		x["pet_atk_pct"] = x["atk_pct"]       # o ataque da invocação vem do dono: o % entra depois (SimEntity.recompute_stats)
	pet.put_buff(x)
	pet.recompute_stats()                     # a defesa herdada do dono fica (SimEntity.summon_pdef)
	Events.post(&"buff_applied", pet.id, str(x.get("id", "buff")), float(x["remaining"]))

## 2º companheiro (espiritual) por um tempo: a mesma ficha do companheiro com `mult` da vida/ataque, fora do limite.
static func spirit_pet(sim: WorldSim, e: SimEntity, pet: SimEntity, d: Dictionary) -> SimEntity:
	var sp: Dictionary = d["spirit"]
	var k := float(sp.get("mult", 0.7))
	var made := sim.spawn_summon(e, pet.monster_def, e.position - e.forward() * 1.2 + Vector3(0.8, 0, 0), float(sp.get("duration", 12.0)), true)
	made.free_summon = true
	made.summon_hp *= k
	made.summon_patk *= k
	made.summon_pdef = pet.summon_pdef * k
	made.recompute_stats()
	made.heal_full()
	if d.get("buff") is Dictionary:
		var b: Dictionary = (d["buff"] as Dictionary).duplicate()
		b["id"] = str(sp.get("buff", "spirit_pet"))
		b.erase("scale")
		pet_buff(made, b)
	return made

## Buff em todas as SUAS invocações vivas no mapa (Maré dos Mortos: velocidade de ataque).
static func buff_summons(sim: WorldSim, e: SimEntity, b: Dictionary) -> void:
	if not sim.maps.has(e.map_id):
		return
	for o: SimEntity in sim.maps[e.map_id]["entities"]:
		if o.kind == SimEntity.Kind.SUMMON and o.owner_id == e.id and o.is_alive():
			pet_buff(o, b)

## "cd_reset": [ids] = essas skills saem da recarga na hora (Olho da Tempestade: Passo Relampejante).
static func cd_reset(e: SimEntity, effects: Dictionary) -> void:
	for sid in effects.get("cd_reset", []):
		e.cooldowns.erase(str(sid))
		ChargeSystem.refill(e, str(sid))

## "hit_heal": {pct, max} = cura pct% da vida máxima por inimigo atingido, até `max` (Ceifa das Almas).
static func hit_heal(sim: WorldSim, e: SimEntity, targets: Array, d: Dictionary) -> void:
	var n := 0
	for t in targets:
		if t != e and e.is_hostile_to(t):
			n += 1
	n = mini(n, int(d.get("max", 5)))
	if n > 0:
		sim._heal(e, e, maxi(1, int(e.stats.max_hp * float(d.get("pct", 0.0)) / 100.0 * n)))

## Fim do canal com "channel_end" {power, range, speed, root}: arremessa a arma na direção do cursor (Lança Incansável).
## O poder segue o lançamento (maestria/bônus): power × (poder do pulso / poder da skill).
static func channel_end(sim: WorldSim, e: SimEntity, s: SkillDef, m: Dictionary) -> void:
	var ce: Dictionary = s.effects["channel_end"]
	var to := e.skill_aim - e.position
	to.y = 0.0
	if to.length() > 0.1:
		e.face_towards(e.skill_aim)
	var p := SimProjectile.new()
	p.id = sim._next_proj_id
	sim._next_proj_id += 1
	p.map_id = e.map_id
	p.owner_id = e.id
	p.skill = s
	p.effects = {"root": {"duration": float(ce.get("root", 1.5))}}
	var n: Dictionary = Balance.ULT_NUMBERS.get(s.id, {})
	var build_k := s.power / float(n["power"]) if float(n.get("power", 0.0)) > 0.0 else 1.0     # o peso da build (BUILD_POWER) vale no arremesso também
	p.power = float(ce.get("power", 3.0)) * build_k * e.stats.skill_power_mult(s.id) * sim.power_scale
	p.position = e.position + Vector3(0, 0.9, 0) + e.forward() * 0.6
	p.direction = e.forward()
	p.speed = float(ce.get("speed", 30.0))
	p.max_distance = float(ce.get("range", 12.0))
	p.radius = 0.5
	p.color = s.icon_color
	m["projectiles"].append(p)
	Events.post(&"projectile_spawned", p)

## Suprema na forma (SkillsCatalog.FORM_MODS): só a variante do bicho/forma, sem talentos nem teia (a Suprema não tem
## rank nem nós). Ex.: Ceifa das Almas na Forma Demoníaca bate × "demon"; na Fantasma avança.
static func form_variant(e: SimEntity, s: SkillDef) -> SkillDef:
	var fm: Dictionary = DruidAscension.form_mods(s.id, e.form) if e.form != "" else {}
	if fm.is_empty():
		return s
	var out: SkillDef = s.duplicate()
	out.talent_effects = s.talent_effects.duplicate()
	if fm.has("name"):
		out.name = fm["name"]
	for k in fm.get("set", {}):
		out.set(k, fm["set"][k])
	for k in fm.get("mult", {}):
		out.set(k, float(out.get(k)) * float(fm["mult"][k]))
	for k in fm.get("effects", {}):
		out.talent_effects[k] = fm["effects"][k]
	return out
