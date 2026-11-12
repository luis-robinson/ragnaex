class_name ElementalSystem
extends RefCounted
## Elemental que evolui e muda de forma (ascensão 35 do Elementalista; GDD ato2-horda R6.1 e F6).
## O elemental vira companheiro persistente (um por vez): ganha experiência com abates perto do mago, sobe de estágio
## (Básico → Maior → Ancestral, nunca cai), troca de forma (fogo/gelo/raio) mantendo estágio e % de vida, e segue um
## modo: atacar (alvo do mago), proteger (provoca quem bate no mago, mais defesa) ou apoiar (buff/escudo no grupo).
## Estado no mago: SimEntity.elem_xp/elem_stage/elem_form/elem_mode/elem_swap_at (salvo). Na invocação: elem_form/elem_stage.

## Mago com a ascensão (Elementalista nível 35 + missão).
static func ascended(e: SimEntity) -> bool:
	return e != null and e.is_character() and e.class_def != null and e.class_def.id == "elementalist" and ProgressionSystem.has_ascension(e)

## Skill da ascensão do Elementalista (Comando Elemental, Fusão Elemental). A regra geral (SkillDef.ascension) é do try_cast.
static func is_asc_skill(s: SkillDef) -> bool:
	return s != null and (s.effects.has("elem_command") or s.effects.has("elem_fusion"))

static func form_of_monster(mid: String) -> String:
	for f in SkillsCatalog.ELEM_FORM_MONSTER:
		if SkillsCatalog.ELEM_FORM_MONSTER[f] == mid:
			return f
	return ""

## A invocação de elemental desta skill vira o companheiro que evolui (mago ascendido).
static func takes_over(e: SimEntity, sm: Dictionary) -> bool:
	return form_of_monster(str(sm.get("monster_id", ""))) != "" and ascended(e)

## Estágio pela experiência e pelo nível (ELEM_STAGE_XP / ELEM_STAGE_LEVEL); guarda o maior (nunca cai).
static func stage_of(e: SimEntity) -> int:
	var st := e.elem_stage
	for i in range(Balance.ELEM_STAGE_XP.size() - 1, 0, -1):
		var gate: String = Balance.ELEM_STAGE_FLAG[i]          # Ancestral: nó da teia de ascensão (Chamado Ancestral)
		if e.elem_xp >= int(Balance.ELEM_STAGE_XP[i]) and e.level >= int(Balance.ELEM_STAGE_LEVEL[i]) and (gate == "" or ProgressionSystem.asc_flag(e, gate)):
			st = maxi(st, i)
			break
	e.elem_stage = st
	return st

## Experiência que falta para o próximo estágio ([atual, alvo]; alvo 0 = último estágio).
static func xp_progress(e: SimEntity) -> Array:
	var st := stage_of(e)
	if st + 1 >= Balance.ELEM_STAGE_XP.size():
		return [e.elem_xp, 0]
	return [e.elem_xp, int(Balance.ELEM_STAGE_XP[st + 1])]

## Forma que o mago usa (a última escolhida; sem escolha: o elemento da build, senão fogo).
static func default_form(e: SimEntity) -> String:
	if e.elem_form in SkillsCatalog.ELEM_FORMS:
		return e.elem_form
	if e.class_def:
		var els: Array = e.class_def.build_by_id(e.build_id).get("element", [])
		if not els.is_empty() and str(els[0]) in SkillsCatalog.ELEM_FORMS:
			return str(els[0])
	for f in SkillsCatalog.ELEM_FORM_SKILL:
		if e.learned.has(SkillsCatalog.ELEM_FORM_SKILL[f]):
			return f
	return "fire"

## O elemental persistente vivo do mago (ou null).
static func elemental_of(sim: WorldSim, e: SimEntity) -> SimEntity:
	if not sim.maps.has(e.map_id):
		return null
	for o: SimEntity in sim.maps[e.map_id]["entities"]:
		if o.kind == SimEntity.Kind.SUMMON and o.owner_id == e.id and o.elem_form != "" and o.is_alive():
			return o
	return null

## Multiplicador do estágio do mago (`key`: hp, atk, area).
static func stage_mult(owner: SimEntity, key: String) -> float:
	return float(Balance.ELEM_STAGE_MULT[stage_of(owner)][key])

## Chamado por WorldSim.spawn_summon antes de registrar: vida do estágio, nome, tamanho, skills e defesa do modo.
## (O ATK do estágio já entrou depois do limite SUMMON_ATK_MAX.)
static func prepare(owner: SimEntity, sm: SimEntity, form: String) -> void:
	var st := stage_of(owner)
	sm.elem_form = form
	sm.elem_stage = st
	sm.summon_expires = INF                              # companheiro persistente
	sm.name = str(SkillsCatalog.ELEM_STAGE_NAMES[form][st])
	sm.scale = sm.monster_def.scale * float(Balance.ELEM_STAGE_SCALE[st])
	for sid in SkillsCatalog.elem_stage_skills(form, st):
		var s: SkillDef = GameData.skills.get(sid)
		if s and not (s in sm.skills):
			sm.skills.append(s)
	sm.summon_hp = sm.stats.max_hp * float(Balance.ELEM_STAGE_MULT[st]["hp"])
	if form_refined(owner, form):            # Salamandra / Golem de Gelo / Silfo: a forma daquele elemento mais forte
		sm.summon_hp *= 1.0 + float(Balance.ELEM_FORM_REFINE["hp"])
		sm.summon_patk *= 1.0 + float(Balance.ELEM_FORM_REFINE["atk"])
	refresh_stats(sm, owner)

## Refino do 40 da forma `form` comprado (portão elem_refine_<forma> da teia de ascensão)?
static func form_refined(owner: SimEntity, form: String) -> bool:
	return owner.is_character() and not owner.asc_tree.is_empty() and ProgressionSystem.asc_flag(owner, Balance.ELEM_FORM_REFINE_FLAG + form)

## Atributos do elemental (estágio + defesa do modo proteger), mantendo a % de vida.
static func refresh_stats(sm: SimEntity, owner: SimEntity) -> void:
	var frac := sm.hp / sm.stats.max_hp if sm.stats.max_hp > 0.0 else 1.0
	sm.recompute_stats()
	sm.stats.patk = sm.summon_patk
	sm.stats.matk = sm.summon_patk
	if owner.elem_mode == "protect":
		var k := 1.0 + Balance.ELEM_PROTECT_DEF_PCT / 100.0
		sm.stats.pdef *= k
		sm.stats.mdef *= k
	sm.hp = clampf(sm.stats.max_hp * frac, 1.0, sm.stats.max_hp)

## Põe o elemental da forma `form` (some o que estiver vivo); `hp_frac` = % de vida que ele herda.
static func summon(sim: WorldSim, e: SimEntity, form: String, hp_frac: float = 1.0, at: Variant = null) -> SimEntity:
	var m: Dictionary = sim.maps[e.map_id]
	for o: SimEntity in m["entities"].duplicate():
		if o.kind == SimEntity.Kind.SUMMON and o.owner_id == e.id and o.monster_def and form_of_monster(o.monster_def.id) != "":
			sim.despawn(o)
	var mdef: MonsterDef = GameData.monsters[SkillsCatalog.ELEM_FORM_MONSTER[form]]
	var pos: Vector3 = at if at is Vector3 else e.position + e.forward() * 1.2
	e.elem_form = form
	var sm := sim.spawn_summon(e, mdef, pos, 0.0, false, form)
	sm.hp = clampf(sm.stats.max_hp * hp_frac, 1.0, sm.stats.max_hp)
	e.elem_uses += 1
	Events.post(&"skill_effect", SkillsCatalog.ELEM_FORM_SKILL[form], e.position, pos, 0.0)
	return sm

## Por que não dá para lançar esta skill agora ("" = pode). Ascensão; troca de forma em recarga.
static func cast_block(sim: WorldSim, e: SimEntity, s: SkillDef) -> String:
	if is_asc_skill(s) and not ascended(e):
		return "%s: requer a ascensão (missão O Núcleo Elemental)" % s.name
	if s.effects.get("summon") is Dictionary and takes_over(e, s.effects["summon"]):
		var cur := elemental_of(sim, e)
		var form := form_of_monster(str(s.effects["summon"].get("monster_id", "")))
		if cur and cur.elem_form != form and sim.time < e.elem_swap_at:
			return "Troca de forma em %ds" % ceili(e.elem_swap_at - sim.time)
	return ""

## Troca a forma do elemental vivo (mantém estágio e % de vida) ou chama um novo. `paid`: a skill já pagou e respeitou a recarga.
static func set_form(sim: WorldSim, e: SimEntity, form: String, paid: bool = false) -> bool:
	if not (form in SkillsCatalog.ELEM_FORMS) or not ascended(e):
		return false
	var cur := elemental_of(sim, e)
	if cur and cur.elem_form == form:
		return false
	if not paid:
		if sim.time < e.elem_swap_at:
			_say(sim, e, "Elemental: volta em %ds" % ceili(e.elem_swap_at - sim.time))
			return false
		if cur == null:
			if e.mp < Balance.ELEM_SUMMON_MP:
				_say(sim, e, "MP insuficiente")
				return false
			e.mp -= Balance.ELEM_SUMMON_MP
	var frac := cur.hp / cur.stats.max_hp if cur else 1.0
	var sm := summon(sim, e, form, frac, cur.position if cur else null)
	if cur:
		e.elem_swap_at = sim.time + Balance.ELEM_SWAP_CD
		_say(sim, e, "Elemental: forma de %s (%s)" % [SkillsCatalog.ELEM_FORM_LABELS[form], sm.name])
	return true

static func set_mode(sim: WorldSim, e: SimEntity, mode: String) -> bool:
	if not (mode in SkillsCatalog.ELEM_MODES) or mode == e.elem_mode or not ascended(e):
		return false
	e.elem_mode = mode
	e.elem_uses += 1
	var cur := elemental_of(sim, e)
	if cur:
		refresh_stats(cur, e)
	_say(sim, e, "Elemental: modo %s" % SkillsCatalog.ELEM_MODE_LABELS[mode])
	return true

## Comando do jogador/bot (InputCommand.elem_form/elem_mode, quadro do HUD).
static func command(sim: WorldSim, e: SimEntity, form: String, mode: String) -> void:
	if form != "":
		set_form(sim, e, form)
	if mode != "":
		set_mode(sim, e, mode)

## Skill de invocação de elemental lançada pelo mago ascendido: troca/chama o persistente (a skill pagou o MP).
static func on_summon_skill(sim: WorldSim, e: SimEntity, form: String) -> void:
	set_form(sim, e, form, true)

## Comando Elemental: sem elemental chama o seu; com ele, passa para o próximo modo.
static func on_command_skill(sim: WorldSim, e: SimEntity) -> void:
	if elemental_of(sim, e) == null:
		set_form(sim, e, default_form(e))
		return
	var i := SkillsCatalog.ELEM_MODES.find(e.elem_mode)
	set_mode(sim, e, SkillsCatalog.ELEM_MODES[(i + 1) % SkillsCatalog.ELEM_MODES.size()])

## Fusão Elemental: o golpe leva o efeito da forma e o mago ganha o buff (MATK + elemento, x apoio do estágio).
static func fusion(sim: WorldSim, e: SimEntity, effects: Dictionary) -> void:
	var form := default_form(e)
	var k := float(Balance.ELEM_SUPPORT_STAGE[stage_of(e)]) * fusion_weight(form)
	var hit: Dictionary = Balance.ELEM_FUSION_HIT.get(form, {})
	for key in hit:
		effects[key] = (hit[key] as Dictionary).duplicate()
	var b := {"id": "elem_fusion", "duration": Balance.ELEM_FUSION_TIME, "matk_pct": Balance.ELEM_FUSION_MATK_PCT * k}
	b[form + "_pct"] = Balance.ELEM_FUSION_ELEMENT_PCT * k
	sim._apply_effects(e, e, {"buff": b}, 0.0)
	e.elem_uses += 1

## Peso F5 da Fusão pela forma do elemental (Balance.ELEM_FUSION_FORM; padrão 1,0): vale no golpe e no buff.
static func fusion_weight(form: String) -> float:
	return float(Balance.ELEM_FUSION_FORM.get(form, 1.0))

## Fusão: o poder usa o bônus do elemento da forma (no lugar da média dos três elementos da skill), x o peso F5 da forma.
static func fusion_power_mult(e: SimEntity, s: SkillDef) -> float:
	var form: String = default_form(e)
	var one: Array[String] = [form]
	return e.stats.element_mult(one) / maxf(0.01, e.stats.element_mult(s.elements)) * fusion_weight(form)

## Abate que dá XP: cada mago ascendido a ELEM_XP_RADIUS com elemental vivo ganha max(1, xp ÷ mob_xp(nível)).
static func on_monster_killed(sim: WorldSim, mob: SimEntity) -> void:
	if mob.monster_def == null or mob.monster_def.xp <= 0 or not sim.maps.has(mob.map_id):
		return
	var gain := maxi(1, int(float(mob.monster_def.xp) / Balance.mob_xp(mob.level)))
	for c: SimEntity in sim.maps[mob.map_id]["entities"]:
		if c.is_character() and c.is_alive() and c.position.distance_to(mob.position) <= Balance.ELEM_XP_RADIUS and ascended(c) \
				and elemental_of(sim, c) != null:
			add_xp(c, gain)

static func add_xp(e: SimEntity, amount: int) -> void:
	e.elem_xp = mini(Balance.ELEM_XP_MAX, e.elem_xp + amount)
	stage_of(e)

## Elemental morreu: o mago perde ELEM_DEATH_LOSS da experiência (o estágio fica); o Ifrit explode.
static func on_died(sim: WorldSim, sm: SimEntity) -> void:
	var owner: SimEntity = sim.entities.get(sm.owner_id)
	if owner:
		owner.elem_xp = maxi(0, owner.elem_xp - int(floor(owner.elem_xp * Balance.ELEM_DEATH_LOSS)))
		owner.elem_swap_at = maxf(owner.elem_swap_at, sim.time + Balance.ELEM_SWAP_CD)
		_say(sim, owner, "Seu elemental caiu (volta em %ds)" % int(Balance.ELEM_SWAP_CD))
	if sm.elem_form == "fire" and sm.elem_stage >= 2 and sim.maps.has(sm.map_id):
		for o: SimEntity in sim.maps[sm.map_id]["entities"]:
			if o.is_alive() and sm.is_hostile_to(o) and o.position.distance_to(sm.position) <= Balance.ELEM_IFRIT_BLAST_RADIUS + o.radius:
				var r := Combat.calc_damage(sm, o, Balance.ELEM_IFRIT_BLAST_POWER, SkillDef.Kind.MAGICAL, sim.rng, sm.position)
				sim._deal_damage(sm, o, r["amount"], r["crit"], false, "magical", sm.position)
		Events.post(&"skill_effect", "elem_ifrit_pyre", sm.position, sm.position, 1.0)

## Pulso do modo por mapa (Balance.ELEM_THINK): estágio novo, foco no alvo do mago, provocar, apoiar.
static func tick(sim: WorldSim, m: Dictionary, dt: float) -> void:
	m["elem_t"] = float(m.get("elem_t", 0.0)) + dt
	if float(m["elem_t"]) < Balance.ELEM_THINK:
		return
	m["elem_t"] = 0.0
	for sm: SimEntity in m["entities"]:
		if sm.kind != SimEntity.Kind.SUMMON or sm.elem_form == "" or not sm.is_alive():
			continue
		var owner: SimEntity = sim.entities.get(sm.owner_id)
		if owner == null or not owner.is_alive() or owner.map_id != sm.map_id:
			continue
		if stage_of(owner) > sm.elem_stage:             # evoluiu: renasce no estágio novo, no mesmo lugar e % de vida
			var frac: float = sm.hp / sm.stats.max_hp
			var nsm := summon(sim, owner, sm.elem_form, frac, sm.position)
			owner.elem_uses -= 1                         # evoluir não é uso da ascensão
			_say(sim, owner, "Seu elemental evoluiu: %s (%s)!" % [nsm.name, SkillsCatalog.ELEM_STAGE_LABELS[nsm.elem_stage]])
			return                                       # a lista do mapa mudou: o resto fica para o próximo pulso
		match owner.elem_mode:
			"attack": _focus(sim, sm, owner)
			"protect": _protect(sim, m, sm, owner)
			"support": _support(sim, m, sm, owner)

static func _focus(sim: WorldSim, sm: SimEntity, owner: SimEntity) -> void:
	var t: SimEntity = sim.entities.get(owner.last_target_id)
	if t == null or not t.is_alive() or t.map_id != sm.map_id or not sm.is_hostile_to(t) \
			or t.position.distance_to(owner.position) > Balance.SUMMON_ASSIST_RANGE:
		return
	sm.aggro_target = t.id
	sm.aggro_timer = Balance.AGGRO_LOSE_TIME
	if sm.brain is MonsterBrain:
		sm.brain.skill_rethink = Balance.ELEM_FOCUS_HOLD

static func _protect(sim: WorldSim, m: Dictionary, sm: SimEntity, owner: SimEntity) -> void:
	for o: SimEntity in m["entities"]:
		if o.kind == SimEntity.Kind.MONSTER and o.aggro_target == owner.id and o.is_alive() \
				and o.position.distance_to(owner.position) <= Balance.SUMMON_ASSIST_RANGE:
			MobSystem.taunt(sim, o, sm, Balance.ELEM_PROTECT_TAUNT)
			sm.aggro_target = o.id

static func _support(sim: WorldSim, m: Dictionary, sm: SimEntity, owner: SimEntity) -> void:
	if sim.time < sm.elem_support_at:
		return
	sm.elem_support_at = sim.time + Balance.ELEM_SUPPORT_EVERY
	var fx := support_effects(sm.elem_form, sm.elem_stage)
	for c: SimEntity in m["entities"]:
		if c.is_character() and c.is_alive() and owner.is_friend(c) and c.position.distance_to(sm.position) <= Balance.ELEM_SUPPORT_RANGE:
			sim._apply_effects(sm, c, fx, 0.0)

## Efeito do modo apoiar por forma e estágio (Balance.ELEM_SUPPORT x ELEM_SUPPORT_STAGE).
static func support_effects(form: String, stage: int) -> Dictionary:
	var k := float(Balance.ELEM_SUPPORT_STAGE[stage])
	var base: Dictionary = Balance.ELEM_SUPPORT[form]
	var keep := Balance.ELEM_SUPPORT_EVERY + 1.0
	if base.has("shield_pct_hp"):
		return {"shield": {"amount_pct_hp": float(base["shield_pct_hp"]) * k, "duration": keep}}
	var b := {"id": "elem_ember" if form == "fire" else "elem_gale", "duration": keep}
	for key in base:
		b[key] = float(base[key]) * k
	return {"buff": b}

## Bot ascendido (BotBrain._fight): só escreve no comando. Chama o elemental (forma do elemento da build), troca de volta
## para ela quando dá, e escolhe o modo: proteger se o chefe está nele, senão atacar (GDD R6.1).
static func bot_orders(e: SimEntity, sim: WorldSim, mob: SimEntity, cmd: InputCommand) -> void:
	if not ascended(e):
		return
	var want := default_form(e)
	var cur := elemental_of(sim, e)
	if sim.time >= e.elem_swap_at and (cur == null and e.mp >= Balance.ELEM_SUMMON_MP or (cur != null and cur.elem_form != want)):
		cmd.elem_form = want
	# proteger enquanto o chefe estiver nele ou, já protegendo, no elemental (senão alternava a cada pensamento)
	var boss_on_me: bool = mob != null and mob.monster_def != null and mob.monster_def.is_boss \
		and (mob.aggro_target == e.id or (e.elem_mode == "protect" and cur != null and mob.aggro_target == cur.id))
	var mode := "protect" if boss_on_me else "attack"
	if mode != e.elem_mode:
		cmd.elem_mode = mode

## Save: campo "elemental" (save_version 5).
static func to_save(e: SimEntity) -> Dictionary:
	return {"xp": e.elem_xp, "stage": e.elem_stage, "form": e.elem_form, "mode": e.elem_mode}

## Save antigo (sem o campo): experiência 0, forma = a do último elemental (a skill de invocação na barra), modo atacar.
static func from_save(e: SimEntity, d: Dictionary) -> void:
	var el: Dictionary = d.get("elemental", {}) if d.get("elemental") is Dictionary else {}
	e.elem_xp = clampi(int(el.get("xp", 0)), 0, Balance.ELEM_XP_MAX)
	e.elem_stage = clampi(int(el.get("stage", 0)), 0, Balance.ELEM_STAGE_XP.size() - 1)
	e.elem_form = str(el.get("form", ""))
	e.elem_mode = str(el.get("mode", "attack"))
	if not (e.elem_mode in SkillsCatalog.ELEM_MODES):
		e.elem_mode = "attack"
	if not (e.elem_form in SkillsCatalog.ELEM_FORMS):
		e.elem_form = ""
		var loadout: Array = d.get("loadout", [])
		for sid in loadout:
			for f in SkillsCatalog.ELEM_FORM_SKILL:
				if e.elem_form == "" and str(sid) == SkillsCatalog.ELEM_FORM_SKILL[f]:
					e.elem_form = f
		if e.elem_form == "" and e.class_def and e.class_def.id == "elementalist":
			e.elem_form = default_form(e)

static func _say(sim: WorldSim, e: SimEntity, text: String) -> void:
	if e == sim.player:
		Events.post(&"notification", text)
