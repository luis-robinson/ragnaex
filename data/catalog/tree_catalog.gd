class_name TreeCatalog
extends RefCounted
## Árvore de pontos de skill (estilo talentos do WoW) — uma por classe, gerada por loops a partir das skills
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

const ROW := 1.2                  # distância entre skills no painel (unidades da árvore; a UI escala)
const SIDE := 0.95                # maestria / evolução ao lado da skill
const PANE_W := 3.0               # largura de um painel
const PANE_GAP := 0.5
const ROOT_Y := -1.5              # nó inicial acima dos painéis
## Talentos de escolha (aba "Talentos" da janela K): uma linha por nível, 3 bônus pequenos, compra-se UM por linha
## (liberado pelo nível, não gasta pontos; trocar é na cidade). "power" = ATK ou MATK conforme a classe. Nó: kind "pick", group "row_N".
const PICK_ROWS := [
	[3, [["power", 4], ["hp_pct", 5], ["speed_pct", 4]]],
	[6, [["aspd_pct", 6], ["def_pct", 6], ["mp_pct", 8]]],
	[9, [["crit", 2.0], ["lifesteal", 2], ["heal_pct", 6]]],
	[12, [["power", 5], ["evasion", 2.0], ["cdr", 4]]],
	[15, [["aspd_pct", 8], ["hp_pct", 7], ["speed_pct", 5]]],
	[18, [["crit", 3.0], ["def_pct", 8], ["buff_pct", 10]]],
	[24, [["power", 7], ["lifesteal", 3], ["cdr", 6]]],
	[28, [["crit", 4.0], ["hp_pct", 10], ["aspd_pct", 10]]],
]
## sabor da classe: linha -> bônus que entra no lugar da 3ª opção (ou da 2ª, se repetir uma das outras)
const PICK_FLAVOR := {
	"paladin": {2: ["heal_pct", 8], 5: ["hp_pct", 8]},
	"berserker": {2: ["lifesteal", 3], 4: ["aspd_pct", 10]},
	"bishop": {2: ["radiance", 3], 5: ["buff_pct", 12]},
	"druid": {2: ["pet_pct", 10], 5: ["heal_pct", 8]},
	"ranger": {2: ["pet_pct", 12], 4: ["aspd_pct", 10]},
	"assassin": {2: ["backstab", 8], 5: ["evasion", 3.0]},
	"elementalist": {1: ["storm_pct", 6], 2: ["fire_pct", 6], 5: ["frost_pct", 6]},
	"necromancer": {2: ["pet_pct", 12], 5: ["lifesteal", 3]},
}

static func _is_caster(cls: ClassDef) -> bool:
	return cls.builds.any(func(b): return b["role"] in ["caster", "healer"])

## Linhas de escolha da classe, em laço: PICK_ROWS + PICK_FLAVOR; "power" vira o ataque da classe.
static func _picks(cls: ClassDef, nodes: Dictionary) -> void:
	var power := "matk_pct" if _is_caster(cls) else "atk_pct"
	var flavor: Dictionary = PICK_FLAVOR.get(cls.id, {})
	for r in range(PICK_ROWS.size()):
		var lv: int = PICK_ROWS[r][0]
		var opts: Array = (PICK_ROWS[r][1] as Array).duplicate(true)
		for o in opts:
			if o[0] == "power":
				o[0] = power
		if flavor.has(r):
			var keys: Array = opts.map(func(o): return o[0])
			var put: int = 2 if not (flavor[r][0] in [keys[0], keys[1]]) else (1 if flavor[r][0] != keys[0] else 0)
			opts[put] = flavor[r].duplicate()
		for k in range(opts.size()):
			var st := {opts[k][0]: opts[k][1]}
			var pid := "%s_k_%d_%d" % [cls.id, r, k]
			nodes[pid] = _node(pid, "pick", "", stat_text(st), "Talento: %s." % stat_text(st), lv, 0, Vector2(k, r))
			nodes[pid]["stats"] = st
			nodes[pid]["branch"] = "talentos"
			nodes[pid]["group"] = "row_%d" % r

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
	"fire_pct": "%+d%% dano de fogo", "frost_pct": "%+d%% dano de gelo", "storm_pct": "%+d%% dano de raio", "cdr": "-%d%% recarga das skills"}

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
	"fire_pct": "%+d%% Fogo", "frost_pct": "%+d%% Gelo", "storm_pct": "%+d%% Raio", "cdr": "-%d%% Recarga"}
## família do passivo (cor do rótulo): defesa, ataque, magia, cura, mobilidade
const STAT_FAMILY := {"def_pct": "def", "hp_pct": "def", "evasion": "def", "atk_pct": "atk", "crit": "atk", "lifesteal": "atk",
	"aspd_pct": "atk", "backstab": "atk", "pet_pct": "atk", "matk_pct": "mag", "mp_pct": "mag", "fire_pct": "mag", "frost_pct": "mag",
	"storm_pct": "mag", "heal_pct": "heal", "buff_pct": "heal", "radiance": "heal", "speed_pct": "move", "cdr": "move"}

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

static func _class_tree(cls: ClassDef, skills: Dictionary, talents: Dictionary) -> Dictionary:
	var nodes := {}
	var branches: Array = [{"id": "", "role": "", "name": "Geral"}]
	for b in cls.builds:
		branches.append({"id": b["id"], "role": b["role"], "name": b["name"], "passives": b.get("passives", [])})
	var total_w := branches.size() * PANE_W + (branches.size() - 1) * PANE_GAP
	var start := "%s_start" % cls.id
	nodes[start] = _node(start, "start", "", cls.name, "Início da árvore.", 1, 0, Vector2(total_w * 0.5, ROOT_Y))
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
	var panes: Array = []
	for bi in range(branches.size()):
		var br: Dictionary = branches[bi]
		var cx := bi * (PANE_W + PANE_GAP) + PANE_W * 0.5
		panes.append({"id": br["id"], "name": br["name"], "role": br["role"], "x": cx})
		var list: Array = []
		for sid in cls.skill_ids:
			var s: SkillDef = skills[sid]
			if s.build == br["id"]:
				list.append(s)
		# iniciais primeiro (já vêm compradas), depois por nível
		list.sort_custom(func(a, b): return _order(cls, a) < _order(cls, b))
		var stats: Array = br["passives"] if not br.get("passives", []).is_empty() else ROLE_STATS.get(br["role"], ROLE_STATS[""])
		var prev := start
		var row := 0
		for i in range(list.size()):
			var s: SkillDef = list[i]
			var y := row * ROW
			if i > 0 and not (s.id in cls.starting_skills):
				# passivo pequeno na linha entre a skill anterior e esta
				var st: Dictionary = stats[i % stats.size()]
				var pid := "%s_p_%s_%d" % [cls.id, br["id"] if br["id"] != "" else "geral", i]
				nodes[pid] = _node(pid, "stat", "", stat_text(st), "Passivo: %s." % stat_text(st), list[i - 1].unlock_level, 1, Vector2(cx, y - ROW * 0.5))
				nodes[pid]["stats"] = st
				nodes[pid]["branch"] = br["id"]
				_link(nodes, prev, pid)
				prev = pid
			var nid := "%s_s_%s" % [cls.id, s.id]
			nodes[nid] = _node(nid, "skill", s.id, s.name, s.description, s.unlock_level, Balance.SKILL_LEARN_COST, Vector2(cx, y))
			nodes[nid]["branch"] = br["id"]
			_link(nodes, prev, nid)
			var mid := "%s_m_%s" % [cls.id, s.id]
			nodes[mid] = _node(mid, "mastery", s.id, "Maestria: " + s.name, "+1 nível de maestria em %s." % s.name, s.unlock_level, 1, Vector2(cx - SIDE, y))
			nodes[mid]["branch"] = br["id"]
			_link(nodes, nid, mid)
			var k := 0
			for t in by_skill.get(s.id, []):
				var tnid := "%s_t_%s" % [cls.id, t.id]
				nodes[tnid] = _node(tnid, "talent", t.id, t.name, t.description, t.unlock_level, t.cost, Vector2(cx + SIDE + k * 0.6, y + k * 0.35))
				nodes[tnid]["branch"] = br["id"]
				_link(nodes, nid if k == 0 else "%s_t_%s" % [cls.id, by_skill[s.id][k - 1].id], tnid)
				k += 1
			prev = nid
			row += 1
	# evoluções do dash: ao lado do nó inicial, em corrente
	for i in range(dash_talents.size()):
		var t: TalentDef = dash_talents[i]
		var tnid := "%s_t_%s" % [cls.id, t.id]
		nodes[tnid] = _node(tnid, "talent", t.id, t.name, t.description, t.unlock_level, t.cost, Vector2(total_w * 0.5 + SIDE * 1.4 * (i + 1), ROOT_Y))
		nodes[tnid]["branch"] = "start"
		_link(nodes, start if i == 0 else "%s_t_%s" % [cls.id, dash_talents[i - 1].id], tnid)
	_picks(cls, nodes)
	return {"start": start, "nodes": nodes, "panes": panes}

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
