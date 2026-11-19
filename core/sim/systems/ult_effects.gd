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
			sim._deal_damage(src, t, int(left * det), false, false, "detonate")

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

## Companheiro morto volta com a vida cheia; vivo: vida cheia. d = {"skill": "<id da skill que chama o companheiro>"}.
static func pet_revive(sim: WorldSim, e: SimEntity, d: Dictionary) -> SimEntity:
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
static func end_cast(sim: WorldSim, e: SimEntity, b: Dictionary) -> void:
	var s: SkillDef = GameData.skills.get(str(b.get("end_cast", "")))
	if s == null or not e.is_alive() or not sim.maps.has(e.map_id):
		return
	var keep_aim := e.skill_aim
	var keep_scale := sim.power_scale
	e.skill_aim = e.position + e.forward() * 2.0
	sim.power_scale *= float(b.get("end_power", 1.0))
	Events.post(&"skill_cast", e.id, s.id, "active")
	sim._apply_skill(e, s, sim.maps[e.map_id])
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
