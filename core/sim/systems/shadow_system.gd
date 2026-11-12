class_name ShadowSystem
extends RefCounted
## Ascensão do Assassino (Ato II, 35) — Sombras Gêmeas: clone de sombra que repete os golpes do dono e Execução.
## Regras sem estado próprio; números em Balance.SHADOW_* / EXECUTION_* / CHAIN_COUNTER_* / HAND_CANNON_*.
##
## O clone é uma invocação (Kind.SUMMON) com a classe, o visual e o equipamento do dono e `shade = true`: não é hostil
## a ninguém (monstros não o miram nem o acertam, SimEntity.is_hostile_to) e não ataca por conta própria. Cada golpe
## direto do dono (WorldSim._strike: skill, básico, projétil) entra na fila `echo` do clone; ele faz o mesmo gesto e,
## no impacto do gesto, causa SHADOW_SHARE% do dano em nome do dono (ameaça, abate e roubo de vida são do dono).

const FLAG_STEALTH := "ass_shadow_stealth"      # Lâminas 40: o clone sai da furtividade junto
const FLAG_CHAIN := "ass_chain_counter"         # Duelista 40: esquiva prepara a Execução

## Peso F5 da ascensão pela build do dono (bot: build_id; jogador: a build das armas).
static func asc_power(sim: WorldSim, e: SimEntity) -> float:
	var b: String = e.build_id if e.build_id != "" else sim.main_build(e)
	return float(Balance.ASC_BUILD_POWER.get(b, 1.0))

static func is_clone(e: SimEntity) -> bool:
	return e != null and e.shade

## Dono com a Sombra Gêmea ativa (buff; barato para o caminho do golpe).
static func has_shadow(e: SimEntity) -> bool:
	for b in e.buffs:
		if b.get("id") == Balance.SHADOW_BUFF:
			return true
	return false

## Clone vivo do dono no mapa dele (ou null).
static func clone_of(sim: WorldSim, owner: SimEntity) -> SimEntity:
	if owner == null or not sim.maps.has(owner.map_id):
		return null
	for o in sim.maps[owner.map_id]["entities"]:
		if o.shade and o.owner_id == owner.id and o.is_alive():
			return o
	return null

## Duração do clone da skill (nós "shadow_time" da teia de ascensão somam).
static func clone_time(e: SimEntity) -> float:
	return Balance.SHADOW_TIME + Balance.SHADOW_TIME_NODE * (e.stats.shadow_time if e.stats else 0.0)

## Fração do dano do golpe que o clone repete (nós "shadow_share" somam; peso F5 da build).
static func share(sim: WorldSim, owner: SimEntity) -> float:
	return (Balance.SHADOW_SHARE + Balance.SHADOW_SHARE_NODE * owner.stats.shadow_share) / 100.0 * asc_power(sim, owner)

## Lugar do clone: ao lado do dono (à direita de quem ele encara); sem chão andável ali, do outro lado; senão em cima dele.
static func side_spot(sim: WorldSim, owner: SimEntity) -> Vector3:
	var f := owner.forward()
	var right := Vector3(-f.z, 0.0, f.x)
	if not sim.maps.has(owner.map_id):
		return owner.position + right * Balance.SHADOW_SIDE
	var def: MapDef = sim.maps[owner.map_id]["def"]
	for k in [1.0, -1.0]:
		var p: Vector3 = owner.position + right * (Balance.SHADOW_SIDE * k)
		if MapGeometry.is_walkable(sim, p, def, owner.radius):
			return p
	return owner.position

## Chama o clone por `duration` s (já existe: renova o tempo). Devolve o clone.
static func summon_clone(sim: WorldSim, owner: SimEntity, duration: float) -> SimEntity:
	if not sim.maps.has(owner.map_id) or not owner.is_alive():
		return null
	var c := clone_of(sim, owner)
	if c == null:
		c = SimEntity.new()
		c.kind = SimEntity.Kind.SUMMON
		c.shade = true
		c.name = "Sombra de %s" % owner.name
		c.class_def = owner.class_def           # mesmo corpo, armas e gestos (a vista monta o kit do dono, escuro)
		c.look = owner.look.duplicate()
		c.equipment = owner.equipment.duplicate()
		c.level = owner.level
		c.owner_id = owner.id
		c.party_id = owner.party_id
		c.radius = owner.radius
		c.scale = owner.scale
		c.position = side_spot(sim, owner)
		c.home_position = c.position
		c.facing = owner.facing
		c.recompute_stats()
		c.heal_full()
		c.brain = CloneBrain.new()
		sim._register(c, owner.map_id)
	c.summon_expires = maxf(c.summon_expires if c.summon_expires != INF else 0.0, sim.time + duration)
	var left: float = c.summon_expires - sim.time
	owner.put_buff({"id": Balance.SHADOW_BUFF, "remaining": left})
	Events.post(&"buff_applied", owner.id, Balance.SHADOW_BUFF, left)
	return c

## Skill Sombra Gêmea.
static func cast(sim: WorldSim, e: SimEntity, s: SkillDef) -> void:
	var c := summon_clone(sim, e, clone_time(e))
	if c:
		Events.post(&"skill_effect", s.id, e.position, c.position, 0.0)

## Refino Lâminas (40): saiu da furtividade golpeando = o clone sai junto por SHADOW_STEALTH_TIME s (sem gastar a recarga).
static func on_ambush(sim: WorldSim, e: SimEntity) -> void:
	if e.is_character() and not e.asc_tree.is_empty() and ProgressionSystem.asc_flag(e, FLAG_STEALTH):
		summon_clone(sim, e, Balance.SHADOW_STEALTH_TIME)

## Golpe direto do dono que causou dano: o clone repete (entra na fila; o gesto começa agora).
static func on_strike(sim: WorldSim, e: SimEntity, t: SimEntity, s: SkillDef, amount: int, crit: bool) -> void:
	if amount <= 0 or e.buffs.is_empty() or not e.is_character() or not has_shadow(e) or not e.is_hostile_to(t):
		return
	var c := clone_of(sim, e)
	if c == null:
		return
	if c.current_skill != s or c.skill_applied:
		flush(sim, c)                       # golpe novo antes do anterior sair: o que estava na fila sai agora
		_mimic(c, s, t)
	c.echo.append({"target": t.id, "amount": maxi(1, int(round(amount * share(sim, e)))), "crit": crit})

## O clone começa o mesmo gesto, de frente para o alvo (só o gesto: quem aplica o dano é `flush`, no impacto).
static func _mimic(c: SimEntity, s: SkillDef, t: SimEntity) -> void:
	var lead := minf(s.startup, Balance.SHADOW_ECHO_MAX)
	c.current_skill = s
	c.current_skill_slot = -1
	c.skill_aim = t.position
	c.skill_applied = false
	c.skill_phase = "startup"
	c.velocity = Vector3.ZERO
	c.face_towards(t.position)
	c.set_state(SimEntity.State.CASTING, s.startup + s.active + s.recovery)
	c.state_time = s.startup - lead          # preparo longo: o clone entra no gesto já adiantado
	Events.post(&"skill_cast", c.id, s.id, "startup")

## Tick do gesto do clone (no lugar de WorldSim._update_skill): no impacto solta a fila.
static func update_skill(sim: WorldSim, c: SimEntity) -> void:
	var s := c.current_skill
	if s == null:
		c.set_state(SimEntity.State.IDLE)
		return
	if not c.skill_applied and c.state_time >= s.startup:
		c.skill_applied = true
		c.skill_phase = "active"
		Events.post(&"skill_cast", c.id, s.id, "active")
		flush(sim, c)
	elif c.skill_applied and c.skill_phase == "active" and c.state_time >= s.startup + s.active:
		c.skill_phase = "recovery"
	if c.state_time >= c.state_duration:
		sim._end_skill(c)

## Solta os golpes na fila: dano do DONO (tipo "shadow"), saindo de onde o clone está.
static func flush(sim: WorldSim, c: SimEntity) -> void:
	if c.echo.is_empty():
		return
	var owner: SimEntity = sim.entities.get(c.owner_id)
	var list := c.echo
	c.echo = []
	if owner == null or not owner.is_alive():
		return
	for h in list:
		var t: SimEntity = sim.entities.get(int(h["target"]))
		if t == null or not t.is_alive() or t.map_id != c.map_id:
			continue
		sim._deal_damage(owner, t, int(h["amount"]), bool(h["crit"]), false, "shadow", c.position)

## Todo tick do clone: some com o dono (morto, outro mapa, sem o buff) — antes disso, não perde o que estava na fila.
## Devolve true se o clone saiu.
static func tick_clone(sim: WorldSim, c: SimEntity) -> bool:
	var owner: SimEntity = sim.entities.get(c.owner_id)
	if owner == null or not owner.is_alive() or owner.map_id != c.map_id:
		c.echo = []
		sim.despawn(c)
		return true
	if sim.time >= c.summon_expires:
		flush(sim, c)
		owner.drop_buff(Balance.SHADOW_BUFF)
		sim.despawn(c)
		return true
	if c.can_act():
		var spot := side_spot(sim, owner)
		if spot.distance_to(c.position) > Balance.SHADOW_SNAP:
			c.position = spot                  # o dono deu dash/teleporte: a sombra aparece do lado
		if c.velocity.length_squared() < 0.01:
			c.facing = owner.facing
	return false

## Execução: poder cheio abaixo do limiar; acima, EXECUTION_WEAK. Nós "execute_pct" e o peso F5 valem no golpe cheio.
static func execution_mult(sim: WorldSim, e: SimEntity, t: SimEntity) -> float:
	if t == null or t.stats == null or t.hp >= t.stats.max_hp * Balance.EXECUTION_BELOW:
		return Balance.EXECUTION_WEAK / Balance.EXECUTION_POWER
	return (1.0 + Balance.EXECUTION_NODE_PCT * e.stats.execute_pct / 100.0) * asc_power(sim, e)

## Alvo no ponto de execução?
static func executable(t: SimEntity) -> bool:
	return t != null and t.is_alive() and t.hp < t.stats.max_hp * Balance.EXECUTION_BELOW

## Refino Duelista (40): esquivou = a próxima Execução sai sem recarga (1 carga, CHAIN_COUNTER_TIME s).
static func on_dodge(e: SimEntity) -> void:
	if e.asc_tree.is_empty() or not ProgressionSystem.asc_flag(e, FLAG_CHAIN):
		return
	e.put_buff({"id": Balance.CHAIN_COUNTER_BUFF, "remaining": Balance.CHAIN_COUNTER_TIME, "stacks": 1})
	e.cooldowns[Balance.EXECUTION_SKILL] = 0.0           # a que estava recarregando fica pronta agora
	Events.post(&"buff_applied", e.id, Balance.CHAIN_COUNTER_BUFF, Balance.CHAIN_COUNTER_TIME)

## Depois de lançar (WorldSim.try_cast): a Execução preparada gasta a carga e não entra em recarga.
static func on_cast(e: SimEntity, s: SkillDef) -> void:
	if s.id == Balance.EXECUTION_SKILL and e.buff_stacks(Balance.CHAIN_COUNTER_BUFF) > 0:
		e.drop_buff(Balance.CHAIN_COUNTER_BUFF)
		e.cooldowns[s.id] = 0.0

## Empurrão ("knockback"): uma só implementação, a do Druida (para longe de quem bateu ou de `kb.from`; chefe não sai do lugar).
static func knockback(sim: WorldSim, src: SimEntity, t: SimEntity, kb: Dictionary) -> void:
	if t != src:
		DruidAscension.knockback(sim, src, t, kb)

## Bots: quer a Sombra Gêmea agora? (sem clone vivo e já colado no alvo: os 6 s têm de ser de golpes)
static func bot_wants_clone(sim: WorldSim, e: SimEntity, dist: float) -> bool:
	return dist <= Balance.BOT_SHADOW_RANGE and clone_of(sim, e) == null

## Cérebro do clone: fica ao lado do dono, olhando para onde ele olha. Não ataca (repete pelos golpes do dono).
class CloneBrain:
	extends RefCounted

	func think(e: SimEntity, sim, _m: Dictionary, _dt: float) -> InputCommand:
		var cmd := InputCommand.new()
		var owner: SimEntity = sim.entities.get(e.owner_id)
		if owner == null:
			cmd.aim = e.position + e.forward()
			return cmd
		var spot := ShadowSystem.side_spot(sim, owner)
		var to := spot - e.position
		to.y = 0.0
		var d := to.length()
		if d > 0.25:
			cmd.move = Vector2(to.x, to.z).normalized() * minf(1.0, d / 0.6)
		cmd.aim = e.position + owner.forward()
		return cmd
