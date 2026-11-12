class_name RangerAscension
extends RefCounted
## Ascensão do Ranger (Ato II, 35): Torreta de campo (Atirador), Salto Dracônico e Brados Elementais (Lanceiro).
## Regras sem estado próprio; números em Balance.TURRET_* / DRAGON_JUMP_* / SHOUT_*.

## Buffs de Brado (um por vez no lanceiro) e o que cada um dá ao grupo.
const SHOUT_BUFFS := {"fire": "shout_flame", "frost": "shout_frost", "storm": "shout_thunder"}
const SHOUT_ALLY := {"fire": "shout_flame_ally", "storm": "shout_thunder_ally"}
const SHOUT_BUILD := "lanceiro"          # build dos Brados (peso F5)

# ---------------------------------------------------------------------------
# Torreta
# ---------------------------------------------------------------------------
## Peso F5 da ascensão da build (Balance.ASC_BUILD_POWER; padrão 1,0). A build vem da skill (jogador não tem build_id).
static func asc_power(build: String) -> float:
	return float(Balance.ASC_BUILD_POWER.get(build, 1.0))

static func is_turret(e: SimEntity) -> bool:
	return e != null and e.kind == SimEntity.Kind.SUMMON and e.monster_def != null and e.monster_def.id == Balance.TURRET_MONSTER

## Refinos da torreta comprados (0-2): Torreta Firme (40) e Torreta Veterana (45), portões da teia de ascensão.
static func turret_refines(e: SimEntity) -> int:
	if not e.is_character() or e.asc_tree.is_empty():
		return 0
	var n := 0
	for flag in Balance.TURRET_REFINE_FLAGS:
		if ProgressionSystem.asc_flag(e, flag):
			n += 1
	return n

## Skill resolvida (ProgressionSystem.resolve_skill): cada refino tira TURRET_REFINE_CD_PCT da recarga da torreta.
static func resolve(e: SimEntity, s: SkillDef) -> SkillDef:
	if not s.effects.has("turret"):
		return s
	var n := turret_refines(e)
	if n <= 0:
		return s
	var te: Dictionary = s.talent_effects          # duplicate() não leva variável sem @export
	var out: SkillDef = s.duplicate()
	out.talent_effects = te.duplicate()
	out.cooldown = s.cooldown * (1.0 - Balance.TURRET_REFINE_CD_PCT / 100.0 * n)
	return out

## Torretas que o ranger pode ter vivas (Balance.TURRET_MAX + stat `turret_max` de buff/conjunto).
static func turret_max(e: SimEntity) -> int:
	return Balance.TURRET_MAX + int(e.stats.turret_max if e.stats else 0.0)

## Torretas vivas do dono no mapa dele, da mais antiga para a mais nova.
static func turrets_of(sim: WorldSim, owner: SimEntity) -> Array:
	var out: Array = []
	if not sim.maps.has(owner.map_id):
		return out
	for o: SimEntity in sim.maps[owner.map_id]["entities"]:
		if o.owner_id == owner.id and o.is_alive() and is_turret(o):
			out.append(o)
	out.sort_custom(func(a, b): return a.id < b.id)
	return out

## Torreta aliada a até Balance.TURRET_AREA m de `e` (ou null). Gancho para conjuntos futuros (curar quem está perto...).
static func near_turret(sim: WorldSim, e: SimEntity) -> SimEntity:
	if not sim.maps.has(e.map_id):
		return null
	for o: SimEntity in sim.maps[e.map_id]["entities"]:
		if is_turret(o) and o.is_alive() and e.is_friend(o) and o.position.distance_to(e.position) <= Balance.TURRET_AREA:
			return o
	return null

## Põe a torreta no ponto mirado (chão andável mais perto): vida/ataque/defesa vêm do dono; passou do limite, a mais antiga some.
static func place_turret(sim: WorldSim, e: SimEntity, s: SkillDef, aim: Vector3, effects: Dictionary) -> SimEntity:
	var mdef: MonsterDef = GameData.monsters.get(str((effects["turret"] as Dictionary).get("monster_id", Balance.TURRET_MONSTER)))
	if mdef == null or not sim.maps.has(e.map_id):
		return null
	var mine := turrets_of(sim, e)
	while mine.size() >= turret_max(e):
		sim.despawn(mine.pop_front())
	var pos := land_point(sim, e, Combat.clamp_aim(e, aim, s.range))
	var t := sim.spawn_summon(e, mdef, pos, Balance.TURRET_TIME + Balance.TURRET_REFINE_TIME * turret_refines(e), false)
	t.summon_hp = e.stats.max_hp * Balance.TURRET_HP_SHARE
	t.summon_patk = e.stats.patk * Balance.TURRET_ATK_SHARE * asc_power(s.build)
	t.recompute_stats()
	t.stats.pdef = e.stats.pdef * Balance.TURRET_DEF_SHARE
	t.stats.mdef = e.stats.mdef * Balance.TURRET_DEF_SHARE
	t.heal_full()
	t.brain = TurretBrain.new()
	t.facing = e.facing
	Events.post(&"skill_effect", s.id, e.position, pos, Balance.TURRET_AREA)
	return t

## Ponto de pouso/montagem: o mirado se for chão andável; senão recua na linha até achar (água, parede); senão onde está.
static func land_point(sim: WorldSim, e: SimEntity, aim: Vector3) -> Vector3:
	if not sim.maps.has(e.map_id):
		return aim
	var def: MapDef = sim.maps[e.map_id]["def"]
	var p := Vector3(aim.x, 0.0, aim.z)
	var back := Vector3(e.position.x, 0.0, e.position.z) - p
	var n := int(ceil(back.length() / 0.5))
	for i in range(n + 1):
		var q := p + back * (float(i) / maxf(1.0, float(n)))
		if MapGeometry.is_walkable(sim, q, def, e.radius):
			return q
	return e.position

## Cérebro da torreta: não anda; mira o inimigo mais perto no alcance e atira (ataque básico do MonsterDef).
class TurretBrain:
	extends RefCounted

	func think(e: SimEntity, sim, m: Dictionary, _dt: float) -> InputCommand:
		var cmd := InputCommand.new()
		cmd.aim = e.position + e.forward()
		var t := Combat.nearest_hostile(e, m["entities"], Balance.TURRET_RANGE)
		if t != null:
			cmd.aim = t.position
			cmd.attack = true
		return cmd

# ---------------------------------------------------------------------------
# Salto Dracônico
# ---------------------------------------------------------------------------
## Decolagem (no fim do preparo): some do chão por DRAGON_JUMP_AIR s; quem o mirava volta ao maior de ameaça.
static func take_off(sim: WorldSim, e: SimEntity, s: SkillDef, aim: Vector3, power: float, m: Dictionary) -> void:
	var to := land_point(sim, e, Combat.clamp_aim(e, aim, s.range))
	e.sky = {"from": e.position, "to": to, "power": power * asc_power(s.build)}
	e.sky_left = Balance.DRAGON_JUMP_AIR
	e.iframe_left = maxf(e.iframe_left, Balance.DRAGON_JUMP_AIR)        # golpe, projétil e chuva passam (sky_left: ninguém o escolhe)
	for o: SimEntity in m["entities"]:
		if o.kind == SimEntity.Kind.MONSTER and o.is_alive() and o.aggro_target == e.id:
			var other := top_threat_except(sim, o, e)
			if other >= 0:                     # sem outro na ameaça o monstro fica nele (o golpe passa) em vez de largar a luta
				o.taunt_left = 0.0
				o.aggro_target = other
	Events.post(&"skill_effect", s.id, e.position, e.position, 0.0)

## Maior ameaça do monstro fora `skip` (vivo, no mesmo mapa), ou -1.
static func top_threat_except(sim: WorldSim, mob: SimEntity, skip: SimEntity) -> int:
	var best := -1
	var best_v := -1.0
	for id in mob.threat:
		if int(id) == skip.id:
			continue
		var o: SimEntity = sim.entities.get(int(id))
		if o == null or not o.is_alive() or o.map_id != mob.map_id:
			continue
		if float(mob.threat[id]) > best_v:
			best_v = float(mob.threat[id])
			best = o.id
	return best

## No ar: vai do ponto de partida ao de pouso (a altura é só desenho).
static func fly(e: SimEntity, s: SkillDef) -> void:
	if e.sky.is_empty():
		return
	var k := clampf((e.state_time - s.startup) / maxf(s.active, 0.01), 0.0, 1.0)
	e.position = (e.sky["from"] as Vector3).lerp(e.sky["to"], k)
	e.velocity = Vector3.ZERO

## Pouso: dano DRAGON_JUMP_POWER no centro (DRAGON_JUMP_INNER m) e DRAGON_JUMP_EDGE na borda (raio da skill);
## golpe direto (_strike), então o Brado ativo põe o elemento.
static func land(sim: WorldSim, e: SimEntity, s: SkillDef, m: Dictionary) -> void:
	if e.sky.is_empty():
		return
	var to: Vector3 = e.sky["to"]
	var power := float(e.sky["power"])
	e.position = to
	e.sky = {}
	e.sky_left = 0.0
	e.iframe_left = 0.0
	if e.jump_second:
		e.jump_second = false
	elif e.is_character() and not e.asc_tree.is_empty() and ProgressionSystem.asc_flag(e, Balance.DOUBLE_JUMP_FLAG):
		e.cooldowns[s.id] = 0.0                       # Salto Duplo: o 2º sai já (a recarga só entra quando a janela fecha)
		e.jump_window = Balance.DOUBLE_JUMP_WINDOW
	var edge := power * Balance.DRAGON_JUMP_EDGE / Balance.DRAGON_JUMP_POWER
	var any := false
	for o: SimEntity in m["entities"].duplicate():
		if not o.is_alive() or not e.is_hostile_to(o) or o.is_perched():
			continue
		var d: float = Vector2(o.position.x - to.x, o.position.z - to.z).length() - o.radius
		if d > s.radius:
			continue
		sim._strike(e, o, s, power if d <= Balance.DRAGON_JUMP_INNER else edge, SkillDef.Kind.PHYSICAL, to)
		any = true
	Events.post(&"skill_effect", s.id, to, to, s.radius)
	if any and s.hit_stop_frames > 0 and e == sim.player:
		Events.post(&"hit_stop", s.hit_stop_frames)

## Lançou (WorldSim.try_cast, depois da recarga posta): Salto Duplo. Com a janela aberta é o 2º salto (recarga cheia
## × DOUBLE_JUMP_CD_MULT, não abre outra janela); senão guarda a recarga cheia para quando a janela do pouso fechar sem uso.
static func on_cast(e: SimEntity, s: SkillDef) -> void:
	if not s.effects.has("dragon_jump"):
		return
	e.jump_second = e.jump_window > 0.0
	e.jump_window = 0.0
	if e.jump_second:
		e.cooldowns[s.id] = float(e.cooldowns.get(s.id, 0.0)) * Balance.DOUBLE_JUMP_CD_MULT     # o preço do 2º salto: recarga mais longa
	else:
		e.jump_window_cd = float(e.cooldowns.get(s.id, 0.0))

## 2º salto cancelado pelo dash antes do impacto: a recarga devolvida seria 0 (a da janela); vale a recarga cheia guardada.
static func on_cancel(e: SimEntity, s: SkillDef) -> void:
	if not s.effects.has("dragon_jump"):
		return
	e.jump_second = false
	e.cooldowns[s.id] = e.jump_window_cd

## Janela do Salto Duplo (por tick enquanto aberta): fechou sem o 2º salto = a recarga cheia começa agora.
static func tick_window(e: SimEntity, dt: float) -> void:
	e.jump_window -= dt
	if e.jump_window <= 0.0:
		e.jump_window = 0.0
		e.cooldowns[Balance.DRAGON_JUMP_SKILL] = maxf(float(e.cooldowns.get(Balance.DRAGON_JUMP_SKILL, 0.0)), e.jump_window_cd)

## Tempo de sobra: saiu do ar sem pousar (morte, troca de mapa) = limpa.
static func tick_sky(e: SimEntity, dt: float) -> void:
	if e.sky_left > 0.0:
		e.sky_left = maxf(0.0, e.sky_left - dt)
		if e.current_skill == null or not e.current_skill.effects.has("dragon_jump"):
			e.sky_left = 0.0
			e.sky = {}

# ---------------------------------------------------------------------------
# Brados Elementais
# ---------------------------------------------------------------------------
## Elemento do Brado ativo no lanceiro ("" = nenhum).
static func shout_element(e: SimEntity) -> String:
	if e.buffs.is_empty():
		return ""
	for b in e.buffs:
		var id: String = str(b.get("id", ""))
		if id.begins_with("shout_") and not id.ends_with("_ally"):
			for el in SHOUT_BUFFS:
				if SHOUT_BUFFS[el] == id:
					return el
	return ""

static func shouting(e: SimEntity) -> bool:
	return shout_element(e) != ""

## Grito: tira o outro Brado (um por vez), dá o efeito ao grupo/inimigos perto e provoca os monstros a SHOUT_TAUNT_RADIUS.
## O buff do próprio lanceiro sai pelo caminho normal do `buff` da skill.
static func shout(sim: WorldSim, e: SimEntity, effects: Dictionary, m: Dictionary) -> void:
	var el: String = str((effects["shout"] as Dictionary).get("element", "fire"))
	var combo := combo_ready(e, el)
	if combo:
		e.cooldowns[Balance.SHOUT_COMBO_KEY] = Balance.SHOUT_COMBO_CD
	for k in SHOUT_BUFFS:
		if k == el:
			continue
		if not combo:
			e.drop_buff(SHOUT_BUFFS[k])
			continue
		for b in e.buffs:                              # Brado Combinado: o anterior fica, até SHOUT_COMBO_TIME
			if b.get("id") == SHOUT_BUFFS[k]:
				b["remaining"] = minf(float(b.get("remaining", 0.0)), Balance.SHOUT_COMBO_TIME)
	for o: SimEntity in m["entities"]:
		if not o.is_alive() or o == e:
			continue
		var d: float = o.position.distance_to(e.position)
		if SHOUT_ALLY.has(el) and d <= Balance.SHOUT_ALLY_RADIUS and e.is_friend(o) and (o.kind != SimEntity.Kind.NPC or o.guard):
			var b := {"id": SHOUT_ALLY[el], "remaining": Balance.SHOUT_TIME}
			b["fire_pct" if el == "fire" else "speed_pct"] = Balance.SHOUT_BUFF
			o.put_buff(b)
			o.recompute_stats()
			Events.post(&"buff_applied", o.id, b["id"], b["remaining"])
		if not e.is_hostile_to(o) or o.iframe_left > 0.0:
			continue
		if el == "frost" and d <= Balance.SHOUT_FROST_RADIUS + o.radius:
			o.put_debuff({"kind": "curse", "id": "shout_frost_%d" % e.id, "remaining": Balance.SHOUT_TIME, "aspd_down": Balance.SHOUT_BUFF})
		if o.kind == SimEntity.Kind.MONSTER and not o.monster_def.is_boss and d <= Balance.SHOUT_TAUNT_RADIUS + o.radius:     # chefe: fica no tanque
			MobSystem.taunt(sim, o, e, Balance.SHOUT_TAUNT_TIME)

## Brado Combinado (45, portão Balance.SHOUT_COMBO_FLAG): gritar `el` com OUTRO Brado ativo mantém os dois (recarga
## própria SHOUT_COMBO_CD em cooldowns[SHOUT_COMBO_KEY]).
static func combo_ready(e: SimEntity, el: String) -> bool:
	if e.buffs.is_empty() or float(e.cooldowns.get(Balance.SHOUT_COMBO_KEY, 0.0)) > 0.0:
		return false
	var other := false
	for b in e.buffs:
		var id: String = str(b.get("id", ""))
		if id != SHOUT_BUFFS.get(el, "") and SHOUT_BUFFS.values().has(id):
			other = true
	return other and e.is_character() and not e.asc_tree.is_empty() and ProgressionSystem.asc_flag(e, Balance.SHOUT_COMBO_FLAG)

## Bot: pode gritar `s` com um Brado já ativo (Brado Combinado pronto, outro elemento)?
static func can_combo(e: SimEntity, s: SkillDef) -> bool:
	return combo_ready(e, str((s.effects.get("shout", {}) as Dictionary).get("element", "")))

## Golpe direto do lanceiro com Brado: Chamas queima, Geada deixa lento, Trovão salta para 1 vizinho
## (com o Brado Combinado, os dois elementos ativos).
static func on_strike(sim: WorldSim, e: SimEntity, t: SimEntity, amount: int) -> void:
	if amount <= 0 or e.buffs.is_empty() or not e.is_character() or not e.is_hostile_to(t):
		return
	var els: Array = []
	for b in e.buffs:
		var id: String = str(b.get("id", ""))
		if id.begins_with("shout_") and not id.ends_with("_ally"):
			for k in SHOUT_BUFFS:
				if SHOUT_BUFFS[k] == id:
					els.append(k)
	for el in els:
		_strike_element(sim, e, t, amount, el)

static func _strike_element(sim: WorldSim, e: SimEntity, t: SimEntity, amount: int, el: String) -> void:
	match el:
		"fire":
			if t.is_alive():
				t.put_debuff({"kind": "dot", "id": "shout_burn_%d" % e.id, "remaining": Balance.SHOUT_BURN_TIME,
					"dps": maxf(1.0, e.stats.patk * Balance.SHOUT_BURN_PCT / 100.0 * asc_power(SHOUT_BUILD)), "src": e.id, "fire": true})
		"frost":
			if t.is_alive():
				t.put_debuff({"kind": "slow", "id": "shout_chill_%d" % e.id, "remaining": Balance.SHOUT_CHILL_TIME, "pct": Balance.SHOUT_CHILL_PCT})
		"storm":
			if not sim.maps.has(e.map_id):
				return
			for o: SimEntity in sim.maps[e.map_id]["entities"]:
				if o != t and o.is_alive() and e.is_hostile_to(o) and o.position.distance_to(t.position) <= Balance.SHOUT_ARC_RANGE:
					sim._deal_damage(e, o, maxi(1, int(amount * Balance.SHOUT_ARC_PCT / 100.0 * asc_power(SHOUT_BUILD))), false, false, "chain", t.position)
					break

## Recarga do ataque básico de quem está sob a Geada (curse com `aspd_down`).
static func attack_slow_mult(e: SimEntity) -> float:
	if e.debuffs.is_empty():
		return 1.0
	return 1.0 + Combat.curse_sum(e, "aspd_down") / 100.0

# ---------------------------------------------------------------------------
# Bots
# ---------------------------------------------------------------------------
## Onde o bot cai do Salto Dracônico: na borda do alvo, do lado em que já está (centro da queda pega o alvo).
static func jump_spot(e: SimEntity, mob: SimEntity) -> Vector3:
	var back := Vector3(e.position.x - mob.position.x, 0.0, e.position.z - mob.position.z)
	if back.length() < 0.1:
		return mob.position
	return mob.position + back.normalized() * (mob.radius + e.radius + Balance.BOT_JUMP_GAP)

## Onde o bot monta a torreta: do lado de cá do tanque (BOT_TURRET_GAP m), senão a meio caminho do alvo.
static func turret_spot(e: SimEntity, mob: SimEntity, tank: SimEntity) -> Vector3:
	if tank != null and tank != e:
		var back := Vector3(e.position.x - tank.position.x, 0.0, e.position.z - tank.position.z)
		if back.length() > 0.1:
			return tank.position + back.normalized() * Balance.BOT_TURRET_GAP
	var to := mob.position - e.position
	to.y = 0.0
	return e.position + to * 0.4
