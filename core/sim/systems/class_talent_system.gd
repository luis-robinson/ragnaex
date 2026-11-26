class_name ClassTalentSystem
extends RefCounted
## Talentos de classe (ClassTalentsCatalog): escolhas da aba Talentos, guardadas como nós "pick" da teia
## (`<classe>_c_<opção>`, um por linha). Aqui só as regras; o estado fica na entidade:
##   e.ct (ganchos das escolhas, refeito em `refresh`), e.ct_ready_at (próximo "recusa a morrer"), e.immortal_left.
## Os `stats` das escolhas já entram pelo tree_bonus (recompute_tree_bonus soma os nós comprados).

static var bot_picks := true      # testes desligam: bots de teste sem talentos sorteados (comportamento padrão)
const TICK := 0.5                 # permanentes, auras e regeneração: a cada meio segundo
const KEEP := 1.3                 # buff permanente/aura dura isto e é renovado no tick (some logo se a escolha sair)

## Escolhas da entidade (dicionários do catálogo), na ordem das linhas.
static func picked(e: SimEntity) -> Array:
	var out: Array = []
	if e.class_def == null:
		return out
	var tr: Dictionary = GameData.trees.get(e.class_def.id, {})
	if tr.is_empty():
		return out
	for nid in e.tree:
		var n: Dictionary = tr["nodes"].get(nid, {})
		if n.get("kind", "") == "pick" and GameData.class_talents.has(n["ref"]):
			out.append([int(n.get("level", 0)), GameData.class_talents[n["ref"]]])
	out.sort_custom(func(a, b): return a[0] < b[0])         # na ordem das linhas (a ordem de compra não muda nada)
	return out.map(func(x): return x[1])

## Escolhas que não cabem mais (talento mudou de linha): acima do nível ou a 2ª da mesma linha saem. Devolve quantas saíram.
## Chamado ao carregar o save (SaveSystem). Escolha custa 0: nada a devolver.
static func sanitize_picks(e: SimEntity) -> int:
	if e.class_def == null:
		return 0
	var nodes: Dictionary = GameData.trees.get(e.class_def.id, {}).get("nodes", {})
	var seen := {}
	var drop: Array = []
	for nid in e.tree:
		var n: Dictionary = nodes.get(nid, {})
		if n.get("kind", "") != "pick":
			continue
		var g: String = n.get("group", "")
		if int(n.get("level", 0)) > e.level or seen.has(g):
			drop.append(nid)
		else:
			seen[g] = true
	for nid in drop:
		e.tree.erase(nid)
	return drop.size()

## Junta os ganchos das escolhas em e.ct (chamado sempre que a teia muda: compra, troca, reset, carregar).
static func refresh(e: SimEntity) -> void:
	var ct := {}
	for o in picked(e):
		for skill_id in o.get("permanent", []):
			ct["permanent"] = ct.get("permanent", []) + [[skill_id, float(o.get("strength", 1.0)), 0.0]]
		for skill_id in o.get("aura", []):
			ct["permanent"] = ct.get("permanent", []) + [[skill_id, float(o.get("strength", 1.0)), float(o.get("radius", ClassTalentsCatalog.AURA_RADIUS))]]
		for skill_id in o.get("summon_permanent", []):
			var sp: Dictionary = ct.get("summon_permanent", {})
			sp[skill_id] = true
			ct["summon_permanent"] = sp
		for skill_id in o.get("summon_extra", {}):
			var se: Dictionary = ct.get("summon_extra", {})
			se[skill_id] = int(se.get(skill_id, 0)) + int(o["summon_extra"][skill_id])
			ct["summon_extra"] = se
		for skill_id in o.get("skill_mods", {}):
			var sm: Dictionary = ct.get("skill_mods", {})
			sm[skill_id] = sm.get(skill_id, []) + [o["skill_mods"][skill_id]]
			ct["skill_mods"] = sm
		if o.has("form_mult"):
			ct["form_mult"] = float(ct.get("form_mult", 1.0)) * float(o["form_mult"])
		for k in o.get("form_stats", {}):
			var fs: Dictionary = ct.get("form_stats", {})
			fs[k] = float(fs.get(k, 0.0)) + float(o["form_stats"][k])
			ct["form_stats"] = fs
		for f in o.get("form_time", {}):
			var ft: Dictionary = ct.get("form_time", {})
			ft[f] = float(o["form_time"][f])
			ct["form_time"] = ft
		for k in ["cheat_death", "ally_save", "regen", "mana_shield", "low_hp", "execute"]:
			if o.has(k):
				ct[k] = o[k]
		if o.has("on_kill"):
			ct["on_kill"] = ct.get("on_kill", []) + [o["on_kill"]]
		if o.has("summon_time"):
			ct["summon_time"] = float(ct.get("summon_time", 1.0)) * float(o["summon_time"])
		for k in ["ambush_mult", "trap_max", "oath_max", "dot_boost"]:
			if o.has(k):
				ct[k] = o[k]
	e.ct = ct

# --- skills -----------------------------------------------------------------------------------------------------
## Skill com os mods das escolhas: primeiro `set`/`effects`/`add` de todas, depois os `mult` ("duration" multiplica as durações dos
## efeitos; "radius" numa skill de aura estica também o raio do grupo e do pulso). Assim a ordem das escolhas não importa.
static func apply_mods(e: SimEntity, s: SkillDef) -> SkillDef:
	var list: Array = e.ct.get("skill_mods", {}).get(s.id, [])
	if e.stats != null and e.stats.piece_mods.has(s.id):
		list = list + e.stats.piece_mods[s.id]          # peças do 50 (PieceEffects, "skill_mods")
	if list.is_empty():
		return s
	var out: SkillDef = s.duplicate()
	out.talent_effects = s.talent_effects.duplicate(true)
	for md in list:
		for k in md.get("set", {}):
			out.set(k, md["set"][k])
		for k in md.get("effects", {}):
			out.talent_effects[k] = (md["effects"][k] as Dictionary).duplicate(true) if md["effects"][k] is Dictionary else md["effects"][k]
		if md.get("add") is Dictionary:      # soma ao efeito final (base + maestria + evolução), no _apply_skill (merge_add)
			out.talent_effects["add"] = add_effects(out.talent_effects.get("add", {}), md["add"])
	for md in list:
		for k in md.get("mult", {}):
			if k == "duration":
				_scale_durations(out, float(md["mult"][k]))
			else:
				out.set(k, float(out.get(k)) * float(md["mult"][k]))
				if k == "radius" and s.effects.get("aura") is Dictionary:
					_scale_aura(out, float(md["mult"][k]))
	return out

## Soma dois dicionários de "add" ({efeito: número | {campo: número}}) sem mexer nos originais.
static func add_effects(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate(true)
	for k in b:
		if b[k] is Dictionary:
			var d: Dictionary = (out.get(k, {}) as Dictionary).duplicate()
			for f in b[k]:
				d[f] = float(d.get(f, 0.0)) + float(b[k][f])
			out[k] = d
		else:
			out[k] = float(out.get(k, 0.0)) + float(b[k])
	return out

## Aplica o "add" dos talentos em `effects` (já com maestria e evolução): número soma; dicionário soma campo a campo.
## Só reforça efeito que a skill tem. Ex.: merge_add({"dot": {"dps": 5, "duration": 4}}, {"dot": {"duration": 5}}) -> 9 s.
static func merge_add(effects: Dictionary, add: Dictionary) -> void:
	for k in add:
		if add[k] is Dictionary:
			if not (effects.get(k) is Dictionary):
				continue
			var d: Dictionary = (effects[k] as Dictionary).duplicate()
			for f in add[k]:
				d[f] = float(d.get(f, 0.0)) + float(add[k][f])
			effects[k] = d
		elif effects.has(k):
			effects[k] = float(effects[k]) + float(add[k])

static func _scale_aura(s: SkillDef, f: float) -> void:
	var au: Dictionary = (s.talent_effects.get("aura", s.effects["aura"]) as Dictionary).duplicate(true)
	au["radius"] = float(au.get("radius", 12.0)) * f
	if au.get("pulse") is Dictionary:
		au["pulse"]["radius"] = float(au["pulse"].get("radius", 3.5)) * f
	s.talent_effects["aura"] = au

static func _scale_durations(s: SkillDef, f: float) -> void:
	for k in s.effects:
		var v: Variant = s.talent_effects.get(k, s.effects[k])
		if v is Dictionary and (v as Dictionary).has("duration"):
			var d: Dictionary = (v as Dictionary).duplicate(true)
			d["duration"] = float(d["duration"]) * f
			s.talent_effects[k] = d
		elif k == "stealth":
			s.talent_effects[k] = float(v) * f

static func summon_permanent(e: SimEntity, skill_id: String) -> bool:
	return e.ct.get("summon_permanent", {}).has(skill_id)

static func summon_extra(e: SimEntity, skill_id: String) -> int:
	return int(e.ct.get("summon_extra", {}).get(skill_id, 0))

## Bônus que só vale na forma (Uivo da Lua); SimEntity.recompute_stats soma junto com o bônus da forma.
static func form_stats(e: SimEntity) -> Dictionary:
	return e.ct.get("form_stats", {})

static func form_mult(e: SimEntity) -> float:
	return float(e.ct.get("form_mult", 1.0))

static func form_time(e: SimEntity, form: String) -> float:
	return float(e.ct.get("form_time", {}).get(form, 1.0))

## Duração das invocações com tempo (Mortos sem Pressa). Ex.: `dur * ClassTalentSystem.summon_time(e)`.
static func summon_time(e: SimEntity) -> float:
	return float(e.ct.get("summon_time", 1.0))

## Dano no tempo mágico de quem lança (Podridão Lenta): [× duração, × dps]. Sem o talento, [1, 1].
static func dot_boost(e: SimEntity) -> Array:
	var b: Dictionary = e.ct.get("dot_boost", {})
	if b.is_empty():
		return [1.0, 1.0]
	return [float(b.get("time", 1.0)), float(b.get("dps", 1.0))]

static func ambush_mult(e: SimEntity) -> float:
	return float(e.ct.get("ambush_mult", Balance.AMBUSH_MULT))

static func trap_max(e: SimEntity) -> int:
	return int(e.ct.get("trap_max", Balance.TRAP_MAX)) + int(e.stats.trap_max if e.stats else 0.0)     # + stat trap_max (Ápice do Atirador)

static func oath_max(e: SimEntity) -> int:
	return int(e.ct.get("oath_max", Balance.SHIELD_OATH_MAX)) + int(PieceEffects.cap(e, "oath"))     # + cabeça do Guardião 50

## Bônus da skill que vira permanente/aura: só os números positivos × força (a lentidão da Muralha fica de fora).
static func passive_buff(skill_id: String, strength: float) -> Dictionary:
	var s: SkillDef = GameData.skills.get(skill_id)
	if s == null or not (s.effects.get("buff") is Dictionary):
		return {}
	var b: Dictionary = s.effects["buff"]
	var out := {"id": b.get("id", skill_id), "ct": true}
	for k in b:
		if k in ["id", "duration"]:
			continue
		if (b[k] is float or b[k] is int) and float(b[k]) > 0.0:
			out[k] = float(b[k]) * strength
	return out

# --- tick: permanentes, auras, regeneração, imortalidade ----------------------------------------------------------
static func tick(sim: WorldSim, m: Dictionary, dt: float) -> void:
	m["ct_t"] = float(m.get("ct_t", 0.0)) + dt
	if float(m["ct_t"]) < TICK:
		return
	var step: float = m["ct_t"]
	m["ct_t"] = 0.0
	for e: SimEntity in m["entities"]:
		if e.immortal_left > 0.0:
			e.immortal_left = maxf(0.0, e.immortal_left - step)
		if e.ct.is_empty() or not e.is_alive() or not e.is_character():
			continue
		for pb in e.ct.get("permanent", []):
			var b := passive_buff(pb[0], float(pb[1]))
			if b.size() <= 2:
				continue
			var R: float = pb[2]
			for t in _receivers(sim, e, m, R):
				_keep_buff(t, b)
			var sk: SkillDef = GameData.skills.get(pb[0])
			if R <= 0.0 and sk and sk.effects.get("pet_buff", false):      # Instinto da Matilha: no lince também
				var pet := sim.pet_of(e)
				if pet:
					_keep_buff(pet, b)
		var rg: Dictionary = e.ct.get("regen", {})
		if not rg.is_empty() and (not rg.get("form", false) or e.form != ""):
			for t in _receivers(sim, e, m, ClassTalentsCatalog.AURA_RADIUS if rg.get("aura", false) else 0.0):
				if t.hp < t.stats.max_hp:
					sim._heal(e, t, maxi(1, int(t.stats.max_hp * float(rg["pct"]) / 100.0 * step)))

## Quem recebe: só você (R = 0) ou você + grupo + suas invocações a até R metros.
static func _receivers(sim: WorldSim, e: SimEntity, m: Dictionary, R: float) -> Array:
	if R <= 0.0:
		return [e]
	R *= MountedCombat.banner_mult(e)            # Estandarte (Templário 45): montado, a aura alcança mais longe
	var out: Array = []
	for t: SimEntity in m["entities"]:
		if not t.is_alive() or t.position.distance_to(e.position) > R:
			continue
		if t == e or (t.is_character() and e.party_id >= 0 and t.party_id == e.party_id) or (t.kind == SimEntity.Kind.SUMMON and t.owner_id == e.id):
			out.append(t)
	return out

static func _keep_buff(t: SimEntity, b: Dictionary) -> void:
	for x in t.buffs:
		if x.get("id") == b["id"]:
			if not x.get("ct", false) and float(x.get("remaining", 0.0)) > KEEP:
				return                       # o lançado (mais forte) ainda está valendo
			if x.get("ct", false):
				x["remaining"] = KEEP
				return
	var nb := b.duplicate()
	nb["remaining"] = KEEP
	t.put_buff(nb)
	t.recompute_stats()

# --- dano e morte -------------------------------------------------------------------------------------------------
## Multiplicador de dano do atacante (ferido / execução).
static func damage_mult(attacker: SimEntity, target: SimEntity) -> float:
	var src := attacker
	if attacker.ct.is_empty():
		return 1.0
	var mult := 1.0
	var lo: Dictionary = src.ct.get("low_hp", {})
	if not lo.is_empty() and src.hp < src.stats.max_hp * float(lo["below"]):
		mult *= 1.0 + float(lo["dmg_pct"]) / 100.0
	var ex: Dictionary = src.ct.get("execute", {})
	if not ex.is_empty() and target.stats and target.hp < target.stats.max_hp * float(ex["below"]):
		mult *= 1.0 + float(ex["dmg_pct"]) / 100.0
	return mult

## Escudo de Mana: parte do dano sai do MP. Devolve o dano que sobra para o HP.
static func mana_shield(target: SimEntity, amount: int) -> int:
	var ms: Dictionary = target.ct.get("mana_shield", {})
	if ms.is_empty() or amount <= 0:
		return amount
	var take := minf(target.mp, amount * float(ms["pct"]) / 100.0)
	target.mp -= take
	return amount - int(take)

## Dano que vai ser aplicado: imortal não passa de 1 HP; golpe fatal pode acionar "recusa a morrer" (seu ou de um
## aliado com Intercessão). Devolve o dano ajustado.
static func before_hit(sim: WorldSim, target: SimEntity, amount: int) -> int:
	if amount <= 0:
		return amount
	if target.immortal_left > 0.0:
		return mini(amount, maxi(0, int(target.hp) - 1))
	if target.hp - amount > 0.0 or not target.is_character():
		return amount
	var cd: Dictionary = target.ct.get("cheat_death", {})
	if not cd.is_empty() and sim.time >= target.ct_ready_at:
		_save(sim, target, target, float(cd["cd"]), float(cd["dur"]), cd.get("stealth", false))
		return maxi(0, int(target.hp) - 1)
	for o: SimEntity in sim.maps[target.map_id]["entities"] if sim.maps.has(target.map_id) else []:
		if o == target or not o.is_alive() or o.ct.is_empty() or o.party_id < 0 or o.party_id != target.party_id:
			continue
		var al: Dictionary = o.ct.get("ally_save", {})
		if not al.is_empty() and sim.time >= o.ct_ready_at and o.position.distance_to(target.position) <= float(al["radius"]):
			_save(sim, o, target, float(al["cd"]), float(al["dur"]), false)
			return maxi(0, int(target.hp) - 1)
	return amount

static func _save(sim: WorldSim, owner: SimEntity, target: SimEntity, cd: float, dur: float, stealth: bool) -> void:
	owner.ct_ready_at = sim.time + cd
	target.immortal_left = dur
	if stealth:
		sim._apply_effects(target, target, {"stealth": dur}, 0.0)
	Events.post(&"buff_applied", target.id, "immortal", dur)
	if target == sim.player or owner == sim.player:
		Events.post(&"notification", "%s se recusa a cair! (%d s)" % [target.name, int(dur)])

## Abate: cura, MP, furtividade ou buff renovado (escolhas "on_kill"). Abate da invocação conta para o dono se `minions`.
static func on_kill(sim: WorldSim, killer: SimEntity, victim: SimEntity) -> void:
	if killer == null or victim == null or victim.kind != SimEntity.Kind.MONSTER:
		return
	var e := killer
	var by_minion := false
	if killer.kind == SimEntity.Kind.SUMMON:
		e = sim.entities.get(killer.owner_id)
		by_minion = true
	if e == null or e.ct.is_empty() or not e.is_alive():
		return
	for ok in e.ct.get("on_kill", []):
		if by_minion and not ok.get("minions", false):
			continue
		if ok.has("heal_pct"):
			sim._heal(e, e, maxi(1, int(e.stats.max_hp * float(ok["heal_pct"]) / 100.0)))
		if ok.has("mp_pct"):
			e.mp = minf(e.stats.max_mp, e.mp + e.stats.max_mp * float(ok["mp_pct"]) / 100.0)
		if ok.has("stealth"):
			sim._apply_effects(e, e, {"stealth": float(ok["stealth"])}, 0.0)
		if ok.has("buff"):
			var sk: SkillDef = GameData.skills.get(ok["buff"])
			if sk and sk.effects.get("buff") is Dictionary:
				sim._apply_effects(e, e, {"buff": sk.effects["buff"]}, 0.0)

## A skill tem o que o gancho genérico mexe? (summon_time: invocação com tempo; dot_boost: dano no tempo mágico;
## form_stats/form_mult: skill de forma; form_time: a forma citada; stats.pet_pct: invocação)
static func _hook_fits(o: Dictionary, skill_id: String) -> bool:
	var sk: SkillDef = GameData.skills.get(skill_id)
	if sk == null:
		return false
	if o.has("summon_time") and sk.effects.get("summon") is Dictionary and float(sk.effects["summon"].get("duration", 0)) > 0.0:
		return true
	if (o.has("form_stats") or o.has("form_mult")) and sk.effects.has("form"):
		return true
	if o.get("form_time") is Dictionary and (o["form_time"] as Dictionary).has(sk.effects.get("form", "")):
		return true
	if (o.get("stats", {}) as Dictionary).has("pet_pct") and sk.effects.get("summon") is Dictionary:
		return true
	return o.has("dot_boost") and sk.effects.get("dot") is Dictionary and not (sk.effects["dot"] as Dictionary).has("atk_pct")

## Gancho genérico que só serve a quem tem um tipo de skill (o bot e a regra dos talentos vivos olham `_hook_fits`).
static func _typed_hook(o: Dictionary) -> bool:
	return o.has("summon_time") or o.has("dot_boost") or o.has("form_stats") or o.has("form_mult") or o.has("form_time") or (o.get("stats", {}) as Dictionary).has("pet_pct")

# --- bots ---------------------------------------------------------------------------------------------------------
## Chaves da opção que não são gancho (o resto é efeito).
const _META_KEYS := ["id", "name", "text", "kind", "strength", "radius", "build"]
## Tipo de talento que cada papel de build prefere no desempate (`ClassDef.role`/`build.role`).
const _ROLE_KINDS := {"tank": ["sobrevivência", "aura", "utilidade"], "healer": ["aura", "sobrevivência", "utilidade"]}

## Skills que a opção cita pelo id (permanente, aura, invocação, skill_mods).
static func _skill_refs(o: Dictionary) -> Array:
	return o.get("permanent", []) + o.get("aura", []) + o.get("summon_permanent", []) + o.get("skill_mods", {}).keys() + o.get("summon_extra", {}).keys()

## Nota da opção para a build do bot (maior = melhor; decisão 2026-11-16, sem sorteio):
## marcada para a build (`build`, linhas 35+) 5000 > cita skill da build 4000 (+ quanto mais cedo na lista de prioridade
## `mine`) > gancho genérico que serve (tipado por `_hook_fits`: 3000; sem tipo, ex. cheat_death/execute: 2000)
## > só números (`stats`) 1000 (+500 se o número é do elemento da build) > de outra build / gancho sem uso 0.
## Sem uso: gancho tipado sem skill do tipo, Juramento sem escudo, armadilhas sem skill de armadilha, elemento de outra build.
## Desempate: tipo que o papel da build prefere (+0..2), depois a ordem do catálogo.
## `build` = entrada de `ClassDef.builds` (id, role, off, element); `mine` = skills da build em prioridade.
static func bot_score(o: Dictionary, build: Dictionary, mine: Array) -> int:
	var fit := _kind_fit(o, str(build.get("role", "dps")))
	if o.has("build"):
		return (5000 if o["build"] == build.get("id", "") else 0) + fit
	var refs := _skill_refs(o)
	if not refs.is_empty():
		var best := mine.size()
		for r in refs:
			var i := mine.find(r)
			if i >= 0:
				best = mini(best, i)
		return (4000 + (mine.size() - best) * 10 if best < mine.size() else 0) + fit
	if _typed_hook(o):
		return (3000 if mine.any(func(r): return _hook_fits(o, str(r))) else 0) + fit
	if o.has("oath_max") and not ("shield" in build.get("off", [])):
		return fit
	if o.has("trap_max") and not mine.any(func(r): return GameData.skills.has(r) and (GameData.skills[r] as SkillDef).effects.has("trap")):
		return fit
	var hooks: Array = o.keys().filter(func(k): return not (k in _META_KEYS))
	if hooks != ["stats"]:
		return 2000 + fit
	var els: Array = ["fire", "frost", "storm"].filter(func(el): return (o["stats"] as Dictionary).has(el + "_pct"))
	if els.is_empty():
		return 1000 + fit
	return (1500 if els.any(func(el): return el in build.get("element", [])) else 0) + fit

static func _kind_fit(o: Dictionary, role: String) -> int:
	var pref: Array = _ROLE_KINDS.get(role, ["dano", "aura", "permanente"])
	var i := pref.find(o.get("kind", ""))
	return 0 if i < 0 else 2 - mini(i, 2)

## A opção da linha `level` imposta para a build em `ClassTalentsCatalog.BOT_PREFER`, senão a de maior `bot_score`;
## empate = a primeira do catálogo (determinístico). `level` 0 = só a nota (sem exceção).
static func bot_choice(options: Array, build: Dictionary, mine: Array, level: int = 0) -> Dictionary:
	var want: String = ClassTalentsCatalog.BOT_PREFER.get(build.get("id", ""), {}).get(level, "")
	if want != "":
		for o in options:
			if o["id"] == want:
				return o
	var best: Dictionary = options[0]
	var best_s := -1
	for o in options:
		var sc := bot_score(o, build, mine)
		if sc > best_s:
			best_s = sc
			best = o
	return best

## Bot escolhe uma opção por linha liberada: a de maior `bot_score` para a build dele (sem sorteio: o rng da sim não anda).
## `batch` = sem refazer os atributos a cada escolha (ProgressionSystem.bot_spend refaz no fim). Devolve se comprou algo.
static func bot_pick(sim: WorldSim, e: SimEntity, batch: bool = false) -> bool:
	var bought := false
	if not bot_picks:
		return bought
	var rows: Array = ClassTalentsCatalog.rows_of(e.class_def.id)        # só leitura
	var build := e.class_def.build_by_id(e.build_id)
	if build.is_empty():
		build = {"id": e.build_id, "role": e.class_def.role}
	var mine: Array = build.get("skills", e.class_def.skill_ids)
	for row in rows:
		if int(row[0]) > e.level:
			continue
		var o: Dictionary = bot_choice(row[1], build, mine, int(row[0]))
		var nid := "%s_c_%s" % [e.class_def.id, o["id"]]
		if not e.tree.has(nid) and ProgressionSystem.pick_sibling(sim, e, nid) == "":
			if ProgressionSystem.tree_allocate(sim, e, nid, batch):
				bought = true
	return bought

## "Recomendado" dos talentos (GDD introducao-de-sistemas §3.4): por linha liberada e ainda sem escolha, o nó que o bot
## da build `build_id` ("" = ProgressionSystem.main_build) escolheria (bot_choice). Só lê; linha já escolhida fica como está.
static func recommend_picks(sim: WorldSim, e: SimEntity, build_id: String = "") -> Array:
	var out: Array = []
	if e.class_def == null:
		return out
	var bid := build_id if build_id != "" else ProgressionSystem.main_build(sim, e)
	var build := e.class_def.build_by_id(bid)
	if build.is_empty():
		build = {"id": bid, "role": e.class_def.role}
	var mine: Array = build.get("skills", e.class_def.skill_ids)
	for row in ClassTalentsCatalog.rows_of(e.class_def.id):
		if int(row[0]) > e.level:
			continue
		var o: Dictionary = bot_choice(row[1], build, mine, int(row[0]))
		var nid := "%s_c_%s" % [e.class_def.id, o["id"]]
		if not e.tree.has(nid) and ProgressionSystem.pick_sibling(sim, e, nid) == "":
			out.append(nid)
	return out
