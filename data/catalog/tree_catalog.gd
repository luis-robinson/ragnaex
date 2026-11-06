class_name TreeCatalog
extends RefCounted
## Teia de pontos de skill (estilo Path of Exile) — uma por classe, gerada por loops a partir das skills
## (SkillsCatalog), builds (ClassDef.builds) e evoluções (TalentsCatalog). Nada escrito nó a nó.
##
## Forma: um PAINEL por ramo, lado a lado: "Geral" (skills sem build) e um por build. Em cada painel o caminho desce
## por nível: skill → passivo pequeno → skill... (skills na coluna do meio, passivos na linha entre elas). Em cada skill:
## a MAESTRIA (+1) à esquerda e a EVOLUÇÃO à direita. O nó INICIAL fica em cima, ligado ao topo de cada painel;
## as evoluções do dash ficam ao lado dele.
##
## Nó: {id, kind: start|skill|stat|mastery|talent, ref, name, desc, level, cost, pos: Vector2, links: [ids], stats: {}, branch}
## Árvore: {start, nodes, panes: [{id, name, role, x}]}
## Regra (WorldSim.tree_allocate): só se compra nó ligado a um já comprado, com nível e pontos suficientes.

## raio de desenho de cada tipo de nó (unidades da teia; espelha windows.NODE_PX / WEB_UNIT): o passo no braço
## é a soma dos dois raios + folga, então nó grande ganha mais espaço
const NODE_R := {"start": 0.42, "skill": 0.35, "notable": 0.27, "stat": 0.15}
const GAP := 0.24
const R0 := 1.45                  # primeiro nó de cada braço
const SIDE := 0.86                # maestria / evolução ao lado da skill (perpendicular ao braço)
const RINGS := [3.4, 7.4]         # anéis que ligam braços vizinhos (raio)
const RING_LEVEL := [1, 12]       # nível mínimo dos nós de cada anel
const RING_SPACING := 0.95        # distância entre nós de um anel
const DASH_R := [0.85, 1.55, 2.25]  # evoluções do dash: espora curta entre o 1º e o 2º braço
## Notáveis gerais dos anéis (os antigos talentos de escolha), em laço por classe; "power" = ATK ou MATK.
const RING_NOTABLES := [
	["Olho Treinado", {"crit": 3.0, "attr_AGI": 2}], ["Ritmo de Batalha", {"aspd_pct": 6}], ["Mente Serena", {"cdr": 5, "attr_WILL": 2}],
	["Sangue Forte", {"hp_pct": 6, "attr_VIT": 2}], ["Passo Leve", {"speed_pct": 5, "evasion": 1.5}], ["Couraça", {"def_pct": 7}],
	["Sede", {"lifesteal": 2}], ["Poço Arcano", {"mp_pct": 10, "attr_INT": 2}], ["Golpe Firme", {"power": 5, "attr_FOR": 2}],
	["Mãos Curadoras", {"heal_pct": 7}], ["Vigília", {"buff_pct": 10}], ["Instinto", {"crit": 2.0, "power": 3}],
]
## Notáveis de braço por papel (nome, bônus); o laço anda pela lista e soma o atributo principal da build.
const ARM_NOTABLES := {
	"tank": [["Pele de Ferro", {"def_pct": 6, "hp_pct": 4}], ["Inabalável", {"hp_pct": 7}], ["Bastião", {"def_pct": 8}], ["Muralha Viva", {"def_pct": 5, "hp_pct": 5}]],
	"dps": [["Golpe Brutal", {"atk_pct": 6}], ["Lâmina Faminta", {"atk_pct": 4, "lifesteal": 1}], ["Fúria Fria", {"crit": 3.0, "atk_pct": 3}], ["Carnificina", {"aspd_pct": 5, "atk_pct": 3}]],
	"ranged": [["Mira Firme", {"atk_pct": 5, "crit": 1.5}], ["Olho de Águia", {"crit": 3.5}], ["Disparo Rápido", {"aspd_pct": 6}], ["Caçador", {"atk_pct": 6}]],
	"caster": [["Arcano Profundo", {"matk_pct": 6}], ["Fluxo", {"mp_pct": 8, "cdr": 3}], ["Foco Arcano", {"matk_pct": 4, "crit": 1.5}], ["Eco", {"matk_pct": 5, "mp_pct": 4}]],
	"healer": [["Graça", {"heal_pct": 7}], ["Fé Viva", {"heal_pct": 4, "buff_pct": 6}], ["Coro", {"buff_pct": 10}], ["Luz Serena", {"heal_pct": 5, "mp_pct": 5}]],
	"": [["Vigor", {"hp_pct": 5}], ["Agilidade", {"speed_pct": 4}], ["Treino", {"power": 4}], ["Resistência", {"def_pct": 5}]],
}
const SMALL_ATTR := 1             # atributo de um nó pequeno (FOR +1 ...; calibrado pelo boss_probe: a teia inteira não pode dobrar a força)
const NOTABLE_ATTR := 2           # atributo principal num notável de braço
const NOTABLE_SCALE := 0.45        # bônus % dos notáveis (braço e anel) x isto

static func _is_caster(cls: ClassDef) -> bool:
	return cls.builds.any(func(b): return b["role"] in ["caster", "healer"])

## "power" (genérico) vira o ataque da classe
static func _power(st: Dictionary, cls: ClassDef) -> Dictionary:
	var out := {}
	for k in st:
		out[("matk_pct" if _is_caster(cls) else "atk_pct") if k == "power" else k] = st[k]
	return out

## passivo pequeno por papel da build (formato de buff: Stats.compute soma)
const ROLE_STATS := {
	"tank": [{"def_pct": 4}, {"hp_pct": 4}],
	"dps": [{"atk_pct": 3}, {"crit": 1.5}],
	"ranged": [{"atk_pct": 3}, {"crit": 1.5}],
	"caster": [{"matk_pct": 3}, {"mp_pct": 4}],
	"healer": [{"heal_pct": 4}, {"mp_pct": 4}],
	"": [{"hp_pct": 3}, {"speed_pct": 2}],
}
const STAT_NAMES := {"def_pct": "%+d%% DEF", "hp_pct": "%+d%% HP máximo", "atk_pct": "%+d%% ATK", "crit": "%+.1f%% crítico",
	"matk_pct": "%+d%% MATK", "mp_pct": "%+d%% MP máximo", "heal_pct": "%+d%% cura", "speed_pct": "%+d%% velocidade",
	"lifesteal": "%+d%% roubo de vida", "aspd_pct": "%+d%% velocidade de ataque", "buff_pct": "%+d%% duração das bênçãos", "radiance": "%+d%% Radiância",
	"pet_pct": "%+d%% força do companheiro", "evasion": "%+.1f%% esquiva", "backstab": "%+d%% dano pelas costas",
	"fire_pct": "%+d%% dano de fogo", "frost_pct": "%+d%% dano de gelo", "storm_pct": "%+d%% dano de raio", "cdr": "-%d%% recarga das skills",
	"attr_FOR": "%+d FOR", "attr_AGI": "%+d AGI", "attr_VIT": "%+d VIT", "attr_WILL": "%+d WILL", "attr_INT": "%+d INT"}

## Rótulo curto embaixo do losango da evolução: o que ela muda na skill (ou no dash), lido dos mods. Até 2 partes.
const EFFECT_TAGS := {"stun": "atordoa", "slow": "lentidão", "dot": "+DoT", "root": "prende", "heal_pct_of_dmg": "dreno",
	"summon": "invoca", "taunt": "provoca", "shield": "escudo", "buff": "bônus"}

static func talent_tags(t: TalentDef) -> Array:
	var out: Array = []
	var m: Dictionary = t.mods
	if t.skill_id == TalentDef.DASH:
		if m.has("power"): out.append("dano")
		if m.has("stun"): out.append("atordoa")
		if m.has("slow"): out.append("lentidão")
		if m.has("heal_pct"): out.append("cura %d%%" % int(m["heal_pct"]))
		if m.has("buff") and (m["buff"] as Dictionary).has("speed_pct"): out.append("+%d%% veloc." % int(m["buff"]["speed_pct"]))
		if m.has("distance_mult"): out.append("+%d%% dist." % roundi((float(m["distance_mult"]) - 1.0) * 100.0))
		if m.has("charges"): out.append("%d cargas" % int(m["charges"]))
		if m.has("ghost"): out.append("atravessa")
		if m.has("cooldown_mult"): out.append("-%d%% recarga" % roundi((1.0 - float(m["cooldown_mult"])) * 100.0))
	else:
		var mult: Dictionary = m.get("mult", {})
		var st: Dictionary = m.get("set", {})
		if mult.has("power"): out.append("+%d%% dano" % roundi((float(mult["power"]) - 1.0) * 100.0))
		if mult.has("radius"): out.append("+%d%% área" % roundi((float(mult["radius"]) - 1.0) * 100.0))
		if mult.has("cooldown"): out.append("-%d%% recarga" % roundi((1.0 - float(mult["cooldown"])) * 100.0))
		if mult.has("range"): out.append("+%d%% alcance" % roundi((float(mult["range"]) - 1.0) * 100.0))
		if st.has("radius"): out.append("aliados %dm" % int(st["radius"]))
		if st.has("max_targets"): out.append("%d alvos" % int(st["max_targets"]))
		if st.has("projectile_pierce"): out.append("atravessa")
		for e in m.get("effects", {}):
			out.append(EFFECT_TAGS.get(e, e))
	return out.slice(0, 2)

## Rótulo curto ao lado da bolinha do passivo na árvore (o nome completo fica na dica).
const STAT_SHORT := {"def_pct": "%+d%% DEF", "hp_pct": "%+d%% HP", "atk_pct": "%+d%% ATK", "crit": "%+.1f%% Crít",
	"matk_pct": "%+d%% MATK", "mp_pct": "%+d%% MP", "heal_pct": "%+d%% Cura", "speed_pct": "%+d%% Veloc.",
	"lifesteal": "%+d%% Roubo", "aspd_pct": "%+d%% Vel. atq", "buff_pct": "%+d%% Bênção", "radiance": "%+d%% Radiân.",
	"pet_pct": "%+d%% Pet", "evasion": "%+.1f%% Esquiva", "backstab": "%+d%% Costas",
	"fire_pct": "%+d%% Fogo", "frost_pct": "%+d%% Gelo", "storm_pct": "%+d%% Raio", "cdr": "-%d%% Recarga",
	"attr_FOR": "%+d FOR", "attr_AGI": "%+d AGI", "attr_VIT": "%+d VIT", "attr_WILL": "%+d WILL", "attr_INT": "%+d INT"}
## família do passivo (cor do rótulo): defesa, ataque, magia, cura, mobilidade
const STAT_FAMILY := {"def_pct": "def", "hp_pct": "def", "evasion": "def", "atk_pct": "atk", "crit": "atk", "lifesteal": "atk",
	"aspd_pct": "atk", "backstab": "atk", "pet_pct": "atk", "matk_pct": "mag", "mp_pct": "mag", "fire_pct": "mag", "frost_pct": "mag",
	"storm_pct": "mag", "heal_pct": "heal", "buff_pct": "heal", "radiance": "heal", "speed_pct": "move", "cdr": "move",
	"attr_FOR": "atk", "attr_AGI": "move", "attr_VIT": "def", "attr_WILL": "heal", "attr_INT": "mag"}

static func stat_short(stats: Dictionary) -> String:
	var out: Array = []
	for k in stats:
		out.append(STAT_SHORT.get(k, k + " %s") % stats[k])
	return " ".join(out)

static func stat_text(stats: Dictionary) -> String:
	var out: Array = []
	for k in stats:
		out.append(STAT_NAMES.get(k, k + " %s") % stats[k])
	return ", ".join(out)

## { class_id: {"start": id, "nodes": {id: node}} }
static func build(classes: Dictionary, skills: Dictionary, talents: Dictionary) -> Dictionary:
	var out := {}
	for cid in classes:
		out[cid] = _class_tree(classes[cid], skills, talents)
	return out

## Teia de uma classe (estilo Path of Exile): início no centro, um BRAÇO por ramo (Geral + builds) saindo em
## volta, com as skills do ramo por nível e nós pequenos (atributo) e notáveis entre elas; maestria e evoluções ao lado
## de cada skill; dois ANÉIS ligam braços vizinhos (atributos mistos + notáveis gerais) para builds híbridas.
static func _class_tree(cls: ClassDef, skills: Dictionary, talents: Dictionary) -> Dictionary:
	var nodes := {}
	var geral_attr2: String = cls.builds[0].get("attr2", "FOR") if not cls.builds.is_empty() else "FOR"
	var branches: Array = [{"id": "", "role": "", "name": "Geral", "attr": "VIT", "attr2": geral_attr2, "stat": "hp_pct"}]
	for b in cls.builds:
		branches.append({"id": b["id"], "role": b["role"], "name": b["name"], "passives": b.get("passives", []),
			"attr": b.get("attr", "FOR"), "attr2": b.get("attr2", "VIT"), "stat": b.get("stat", "atk_pct")})
	var start := "%s_start" % cls.id
	nodes[start] = _node(start, "start", "", cls.name, "Início da teia.", 1, 0, Vector2.ZERO)
	nodes[start]["branch"] = "start"
	var by_skill := {}             # skill_id -> [talentos]
	var dash_talents: Array = []
	for tid in talents:
		var t: TalentDef = talents[tid]
		if t.class_id != cls.id:
			continue
		if t.skill_id == TalentDef.DASH:
			dash_talents.append(t)
		else:
			if not by_skill.has(t.skill_id):
				by_skill[t.skill_id] = []
			by_skill[t.skill_id].append(t)
	dash_talents.sort_custom(func(a, b): return a.unlock_level < b.unlock_level)
	var n_arms := branches.size()
	var panes: Array = []
	var spines: Array = []           # por braço: [{id, r}] dos nós no eixo (para ligar os anéis)
	var notable_i := 0
	for bi in range(n_arms):
		var br: Dictionary = branches[bi]
		var ang := -PI * 0.5 + TAU * bi / float(n_arms)
		var dir := Vector2(cos(ang), sin(ang))
		var side := Vector2(-dir.y, dir.x)
		panes.append({"id": br["id"], "name": br["name"], "role": br["role"], "angle": ang})
		var list: Array = []
		for sid in cls.skill_ids:
			var sk: SkillDef = skills[sid]
			if sk.build == br["id"]:
				list.append(sk)
		list.sort_custom(func(a, b): return _order(cls, a) < _order(cls, b))
		var smalls: Array = br["passives"] if not br.get("passives", []).is_empty() else ROLE_STATS.get(br["role"], ROLE_STATS[""])
		var arm_notes: Array = ARM_NOTABLES.get(br["role"], ARM_NOTABLES[""])
		var spine: Array = []
		var prev := start
		var r := R0
		var prev_kind := ""
		var filler := 0
		var small_i := 0
		var tag: String = br["id"] if br["id"] != "" else "geral"
		for i in range(list.size()):
			var sk: SkillDef = list[i]
			var lv_prev: int = list[i - 1].unlock_level if i > 0 else 1
			if i > 0 or not (sk.id in cls.starting_skills):
				# nós entre uma skill e a próxima: atributo da build, passivo da build e, a cada 3, um notável
				for k in range(2 if i > 0 else 1):
					filler += 1
					var fid := "%s_n_%s_%d" % [cls.id, tag, filler]
					var st: Dictionary
					var nm: String
					var kind := "stat"
					if filler % 3 == 0:
						var pick: Array = arm_notes[notable_i % arm_notes.size()]
						notable_i += 1
						st = _scaled(pick[1])
						st["attr_" + str(br["attr"])] = NOTABLE_ATTR
						nm = pick[0]
						kind = "notable"
					elif filler % 3 == 1:
						st = {"attr_" + str(br["attr"]): SMALL_ATTR}
					else:
						st = _scaled(smalls[small_i % smalls.size()], 0.5)       # passivo de papel: metade do de antes (há muitos na teia)
						small_i += 1
						st["attr_" + str(br["attr2"])] = SMALL_ATTR
					st = _power(st, cls)
					if kind == "stat":
						nm = stat_text(st)
					r += _gap(prev_kind, kind)
					prev_kind = kind
					nodes[fid] = _node(fid, kind, "", nm, ("Notável: %s." if kind == "notable" else "Passivo: %s.") % stat_text(st), lv_prev, 1, dir * r)
					nodes[fid]["stats"] = st
					nodes[fid]["branch"] = br["id"]
					_link(nodes, prev, fid)
					spine.append({"id": fid, "r": r})
					prev = fid
			r += _gap(prev_kind, "skill")
			prev_kind = "skill"
			var nid := "%s_s_%s" % [cls.id, sk.id]
			nodes[nid] = _node(nid, "skill", sk.id, sk.name, sk.description, sk.unlock_level, Balance.SKILL_LEARN_COST, dir * r)
			nodes[nid]["branch"] = br["id"]
			_link(nodes, prev, nid)
			spine.append({"id": nid, "r": r})
			var mid := "%s_m_%s" % [cls.id, sk.id]
			nodes[mid] = _node(mid, "mastery", sk.id, "Maestria: " + sk.name, mastery_desc(sk), sk.unlock_level, 1, dir * r - side * SIDE)
			nodes[mid]["branch"] = br["id"]
			_link(nodes, nid, mid)
			var k2 := 0
			for t in by_skill.get(sk.id, []):
				var tnid := "%s_t_%s" % [cls.id, t.id]
				nodes[tnid] = _node(tnid, "talent", t.id, t.name, t.description, t.unlock_level, t.cost, dir * (r + k2 * 0.58) + side * SIDE * (1.0 + k2 * 0.35))
				nodes[tnid]["branch"] = br["id"]
				_link(nodes, nid if k2 == 0 else "%s_t_%s" % [cls.id, by_skill[sk.id][k2 - 1].id], tnid)
				k2 += 1
			prev = nid
		spines.append(spine)
	# anéis: arcos entre braços vizinhos; as pontas ligam no nó do braço de raio mais perto
	var ring_note := cls.id.length() * 3
	for ri in range(RINGS.size()):
		var R: float = RINGS[ri]
		for bi in range(n_arms):
			var bj := (bi + 1) % n_arms
			var a0 := -PI * 0.5 + TAU * bi / float(n_arms)
			var a1 := a0 + TAU / float(n_arms)
			var margin := (SIDE + 0.75) / R
			var span := (a1 - a0) - margin * 2.0
			var count := maxi(3, int(span * R / RING_SPACING))
			if count % 2 == 0:
				count += 1                     # ímpar: o do meio é o notável
			var prev_r := _nearest(spines[bi], R)
			for k in range(count):
				var a := a0 + margin + span * (k + 0.5) / float(count)
				var rid := "%s_r_%d_%d_%d" % [cls.id, ri, bi, k]
				var st: Dictionary
				var nm: String
				var kind := "stat"
				var A: Dictionary = branches[bi] if k < count / 2 else branches[bj]
				if k == count / 2:
					var pick: Array = RING_NOTABLES[ring_note % RING_NOTABLES.size()]
					ring_note += 1
					st = _power(_scaled(pick[1]), cls)
					nm = pick[0]
					kind = "notable"
				else:
					st = {"attr_" + str(A["attr"] if k % 2 == 0 else A["attr2"]): SMALL_ATTR}
					nm = stat_text(st)
				nodes[rid] = _node(rid, kind, "", nm, ("Notável: %s." if kind == "notable" else "Passivo: %s.") % stat_text(st), RING_LEVEL[ri], 1, Vector2(cos(a), sin(a)) * R)
				nodes[rid]["stats"] = st
				nodes[rid]["branch"] = "ring"
				if prev_r != "":
					_link(nodes, prev_r, rid)
				prev_r = rid
			var end := _nearest(spines[bj], R)
			if end != "":
				_link(nodes, prev_r, end)
	# evoluções do dash: espora curta saindo do início, entre o 1º e o 2º braço
	var da := -PI * 0.5 + TAU * 0.5 / float(n_arms)
	for i in range(dash_talents.size()):
		var t: TalentDef = dash_talents[i]
		var tnid := "%s_t_%s" % [cls.id, t.id]
		var dr: float = DASH_R[mini(i, DASH_R.size() - 1)] + maxi(0, i - 2) * 0.7
		nodes[tnid] = _node(tnid, "talent", t.id, t.name, t.description, t.unlock_level, t.cost, Vector2(cos(da), sin(da)) * dr)
		nodes[tnid]["branch"] = "start"
		_link(nodes, start if i == 0 else "%s_t_%s" % [cls.id, dash_talents[i - 1].id], tnid)
	_class_picks(cls, nodes)
	return {"start": start, "nodes": nodes, "panes": panes}

## Talentos de classe (ClassTalentsCatalog) como nós "pick" fora da teia: um grupo por linha, grátis, liberados
## pelo nível; os `stats` da opção entram pelo tree_bonus, o resto pelo ClassTalentSystem.
static func _class_picks(cls: ClassDef, nodes: Dictionary) -> void:
	var rows: Array = ClassTalentsCatalog.build().get(cls.id, [])
	for r in range(rows.size()):
		var opts: Array = rows[r][1]
		for k in range(opts.size()):
			var o: Dictionary = opts[k]
			var pid := "%s_c_%s" % [cls.id, o["id"]]
			nodes[pid] = _node(pid, "pick", o["id"], o["name"], o["text"], int(rows[r][0]), 0, Vector2(k, r))
			nodes[pid]["stats"] = _power(o.get("stats", {}), cls)
			nodes[pid]["branch"] = "talentos"
			nodes[pid]["group"] = "row_%d" % r

## Passo no braço entre dois nós seguidos ("" = o primeiro, a partir de R0).
static func _gap(a: String, b: String) -> float:
	if a == "":
		return 0.0
	return float(NODE_R.get(a, 0.15)) + float(NODE_R.get(b, 0.15)) + GAP

## Bônus de notável escalado (% x NOTABLE_SCALE, arredondado; atributo fica).
static func _scaled(st: Dictionary, k_mult: float = NOTABLE_SCALE) -> Dictionary:
	var out := {}
	for k in st:
		out[k] = st[k] if str(k).begins_with("attr_") else (snappedf(float(st[k]) * k_mult, 0.5) if st[k] is float else maxi(1, roundi(float(st[k]) * k_mult)))
	return out

## Nó do eixo de um braço com raio mais perto de R ("" se o braço é vazio).
static func _nearest(spine: Array, R: float) -> String:
	var best := ""
	var bd := INF
	for q in spine:
		var d := absf(float(q["r"]) - R)
		if d < bd:
			bd = d
			best = q["id"]
	return best

## Texto da maestria tirado dos dados da skill: o que cada nível melhora (poder só se a skill tem poder; forma e
## bônus têm valores fixos) e os efeitos extras de certos níveis (SkillDef.mastery[n].extra).
static func mastery_desc(s: SkillDef) -> String:
	var e1 := s.mastery_entry(1)
	var pw := roundi((float(e1.get("power_mult", 1.0)) - 1.0) * 100.0)
	var mp := roundi((1.0 - float(e1.get("mp_mult", 1.0))) * 100.0)
	var cd := roundi((1.0 - float(e1.get("cd_mult", 1.0))) * 100.0)
	var parts: Array = []
	if s.power > 0.0 and pw != 0:
		parts.append("+%d%% de poder (%s)" % [pw, "cura" if s.kind == SkillDef.Kind.HEAL else "dano"])
	if mp != 0:
		parts.append("-%d%% de MP" % mp)
	if cd != 0:
		parts.append("-%d%% de recarga" % cd)
	var bonus := roundi(Balance.MASTERY_BONUS_PCT * 100.0)
	if s.effects.has("form"):
		parts.push_front("+%d%% nos bônus da forma" % bonus)
	elif s.effects.get("buff") is Dictionary:
		parts.push_front("+%d%% nos bônus do efeito" % bonus)
	var t := "Cada nível (até %d): %s." % [Balance.MASTERY_MAX, ", ".join(parts)]
	for lv in range(1, Balance.MASTERY_MAX + 1):
		var ex: Dictionary = s.mastery_entry(lv).get("extra", {})
		var lines: Array = []
		for k in ex:
			lines.append(_extra_text(k, ex[k]))
		if not lines.is_empty():
			t += "\nNível %d: %s." % [lv, ", ".join(lines)]
	return t

static func _extra_text(key: String, v: Variant) -> String:
	match key:
		"heal_pct_of_dmg":
			return "cura %d%% do dano causado" % roundi(float(v) * 100.0)
		"stun":
			return "atordoa por %.1f s" % float((v as Dictionary).get("duration", 0.0))
		"shield":
			return "escudo de %d%% do HP por %d s" % [int((v as Dictionary).get("amount_pct_hp", 0)), int((v as Dictionary).get("duration", 0))]
		"summon":
			var d: Dictionary = v
			return "invoca %d (até %d) por %d s" % [int(d.get("count", 1)), int(d.get("max", d.get("count", 1))), int(d.get("duration", 0))]
	return key

static func _order(cls: ClassDef, s: SkillDef) -> int:
	return (0 if s.id in cls.starting_skills else 1000) + s.unlock_level * 10

static func _node(id: String, kind: String, ref: String, name: String, desc: String, level: int, cost: int, pos: Vector2) -> Dictionary:
	return {"id": id, "kind": kind, "ref": ref, "name": name, "desc": desc, "level": level, "cost": cost, "pos": pos,
		"links": [], "stats": {}, "branch": ""}

static func _link(nodes: Dictionary, a: String, b: String) -> void:
	if not (b in nodes[a]["links"]):
		nodes[a]["links"].append(b)
	if not (a in nodes[b]["links"]):
		nodes[b]["links"].append(a)
