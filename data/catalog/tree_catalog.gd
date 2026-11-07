class_name TreeCatalog
extends RefCounted
## Teia de pontos de skill (estilo Path of Exile) — uma por classe, gerada por loops a partir das skills
## (SkillsCatalog), builds (ClassDef.builds) e evoluções (TalentsCatalog). Nada escrito nó a nó.
##
## Forma (estilo PoE): MALHA de junções e estradas (grade irregular, sorteio fixo por classe) com CÍRCULOS nas casas:
## de skill (skill no centro; maestria, evoluções e passivos em volta) e de notável (anel com o notável no meio, duas
## entradas). Setores por ramo (Geral + builds) em volta do início; skill de nível alto mais longe. Ver _class_tree.
##
## Nó: {id, kind: start|skill|stat|notable|mastery|talent|pick, ref, name, desc, level, cost, pos: Vector2, links: [ids], stats: {}, branch}
## Teia: {start, nodes, panes: [{id, name, role, angle}], clusters: [{center, r, kind, branch}]}
## Regra (WorldSim.tree_allocate): só se compra nó ligado a um já comprado, com nível e pontos suficientes.

## Notáveis gerais (os antigos talentos de escolha), em laço por classe; "power" = ATK ou MATK.
const RING_NOTABLES := [
	["Olho Treinado", {"crit": 3.0, "attr_AGI": 5}], ["Ritmo de Batalha", {"aspd_pct": 6}], ["Mente Serena", {"cdr": 5, "attr_WILL": 5}],
	["Sangue Forte", {"hp_pct": 6, "attr_VIT": 5}], ["Passo Leve", {"speed_pct": 5, "evasion": 1.5}], ["Couraça", {"def_pct": 7}],
	["Sede", {"lifesteal": 2}], ["Poço Arcano", {"mp_pct": 10, "attr_INT": 5}], ["Golpe Firme", {"power": 5, "attr_FOR": 5}],
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
## Atributos na escala nova (Balance.ATTR_SCALE): estrada/junção +1 do setor; nó de círculo +5 perto do início até +10
## no fundo; notável +6..+12. Calibrado por tools/tests/web_probe (alvo ~x1,4 ATK e ~x1,2 HP no 30).
const ROAD_ATTR := 1                     # estrada, junção e os 2 nós do anel do notável sem atributo de círculo
const CLUSTER_ATTR := Vector2i(5, 10)    # entrada do círculo de skill; 3 de 5 do anel do notável (perto -> fundo)
const NOTABLE_ATTR := Vector2i(6, 12)    # atributo principal num notável

## Valor pela profundidade na teia: mínimo na casa mais perto do início, máximo na mais longe (`far` = raio dela).
static func _depth(c: Vector2, span: Vector2i, far: float) -> int:
	var t := clampf((c.length() - CELL) / maxf(1.0, far - CELL), 0.0, 1.0)
	return roundi(lerpf(span.x, span.y, t))
const NOTABLE_SCALE := 0.2        # bônus % dos notáveis (braço e anel) x isto

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

## Teia de uma classe (estilo Path of Exile): uma MALHA de junções (grade irregular, sorteio fixo por classe) com nós de
## passagem nas estradas; nas casas da grade ficam CÍRCULOS: o de skill (a skill no centro, maestria, evoluções e
## atributos em volta, uma entrada) e o de notável (anel de nós pequenos com o notável no meio, duas entradas = atalho).
## Regiões por ramo (Geral + builds) como as do PoE: setores em volta do início; skill de nível alto mais longe.
const CELL := 4.6                 # lado de uma casa da grade (unidades da teia)
const GRID_K := 5                 # casas de -K a K-1 em cada eixo
const WHEEL_R := 1.05             # raio dos círculos
const EDGE_KEEP := 0.55           # das estradas que não são da árvore mínima, quantas ficam (o resto sai: escolha de rota)
const NOTABLE_EVERY := 3          # a cada N casas de um setor, uma vira círculo de notável
const JITTER_HUB := 0.32          # junções e círculos fora da grade perfeita (cara orgânica do PoE)
const JITTER_CELL := 0.25

static func _class_tree(cls: ClassDef, skills: Dictionary, talents: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cls.id + "_teia")
	var nodes := {}
	var geral_attr2: String = cls.builds[0].get("attr2", "FOR") if not cls.builds.is_empty() else "FOR"
	var branches: Array = [{"id": "", "role": "", "name": "Geral", "attr": "VIT", "attr2": geral_attr2}]
	for b in cls.builds:
		branches.append({"id": b["id"], "role": b["role"], "name": b["name"], "passives": b.get("passives", []),
			"attr": b.get("attr", "FOR"), "attr2": b.get("attr2", "VIT")})
	var n_br := branches.size()
	var start := "%s_start" % cls.id
	nodes[start] = _node(start, "start", "", cls.name, "Início da teia.", 1, 0, Vector2.ZERO)
	nodes[start]["branch"] = "start"
	var by_skill := {}
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
	# setores: o ramo bi fica em volta do ângulo a(bi)
	var panes: Array = []
	for bi in range(n_br):
		var br: Dictionary = branches[bi]
		panes.append({"id": br["id"], "name": br["name"], "role": br["role"], "angle": -PI * 0.5 + TAU * bi / float(n_br)})
	var sector_of := func(p: Vector2) -> int:
		var a := wrapf(p.angle() + PI * 0.5, 0.0, TAU)
		return int(round(a / (TAU / float(n_br)))) % n_br
	# casas por setor, da mais perto para a mais longe
	var cells_by: Array = []
	for bi in range(n_br):
		cells_by.append([])
	for i in range(-GRID_K, GRID_K):
		for j in range(-GRID_K, GRID_K):
			var c := Vector2((i + 0.5) * CELL, (j + 0.5) * CELL)
			if c.length() > GRID_K * CELL:
				continue
			cells_by[sector_of.call(c)].append({"i": i, "j": j, "c": c, "d": c.length() + rng.randf() * CELL * 0.35})
	for bi in range(n_br):
		cells_by[bi].sort_custom(func(a, b): return float(a["d"]) < float(b["d"]))
	var clusters: Array = []          # {cell, kind, center, branch, ...} (a UI desenha o círculo)
	var used_cells := {}
	var dash_cell: Dictionary = {}
	for bi in range(n_br):
		var br: Dictionary = branches[bi]
		var list: Array = []
		for sid in cls.skill_ids:
			var sk: SkillDef = skills[sid]
			if sk.build == br["id"]:
				list.append(sk)
		list.sort_custom(func(a, b): return _order(cls, a) < _order(cls, b))
		var k := 0
		var placed := 0
		var n_cells: int = cells_by[bi].size()
		for cell in cells_by[bi]:
			if placed >= list.size() and k >= list.size() + list.size() / NOTABLE_EVERY:
				break
			k += 1
			var key := Vector2i(cell["i"], cell["j"])
			if bi == 0 and dash_cell.is_empty() and not dash_talents.is_empty():
				dash_cell = cell                  # a primeira casa do Geral é a das evoluções do dash
				used_cells[key] = true
				continue
			var tight: bool = n_cells - k + 1 <= list.size() - placed      # setor apertado (classe de 3 builds): sem notável, só skill
			if placed < list.size() and (k % NOTABLE_EVERY != 0 or list[placed].id in cls.starting_skills or tight):
				clusters.append({"cell": cell, "kind": "skill", "skill": list[placed], "branch": bi})
				placed += 1
			else:
				clusters.append({"cell": cell, "kind": "notable", "branch": bi})
			used_cells[key] = true
		while placed < list.size():           # sobrou skill (setor pequeno): casas mais longe do mesmo setor
			for cell in cells_by[bi]:
				var key := Vector2i(cell["i"], cell["j"])
				if not used_cells.has(key):
					clusters.append({"cell": cell, "kind": "skill", "skill": list[placed], "branch": bi})
					used_cells[key] = true
					placed += 1
					break
			if placed < list.size() and cells_by[bi].all(func(c): return used_cells.has(Vector2i(c["i"], c["j"]))):
				push_error("teia de %s: setor %s sem casas" % [cls.id, br["name"]])
				break
	# junções: cantos das casas usadas (o início é o canto 0,0)
	var hubs := {Vector2i(0, 0): start}
	var hub_list: Array = [Vector2i(0, 0)]
	for key in used_cells:
		for dx in [0, 1]:
			for dy in [0, 1]:
				var h := Vector2i(key.x + dx, key.y + dy)
				if not hubs.has(h):
					var hp := Vector2(h.x, h.y) * CELL + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * JITTER_HUB
					var br: Dictionary = branches[sector_of.call(hp)] if hp.length() > 0.1 else branches[0]
					var hid := "%s_h_%d_%d" % [cls.id, h.x + 50, h.y + 50]
					var hst := {"attr_" + str(br["attr"]): ROAD_ATTR}
					nodes[hid] = _node(hid, "stat", "", "Junção", "Junção: %s." % stat_text(hst), 1, 1, hp)
					nodes[hid]["stats"] = hst
					nodes[hid]["branch"] = "ring"
					hubs[h] = hid
					hub_list.append(h)
	# estradas: árvore mínima aleatória entre junções vizinhas (todas ligadas ao início) + parte das outras
	var edges: Array = []
	for h in hub_list:
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			if hubs.has(h + d):
				edges.append([h, h + d, rng.randf()])
	edges.sort_custom(func(a, b): return float(a[2]) < float(b[2]))
	var parent := {}
	for h in hub_list:
		parent[h] = h
	var find := func(x: Vector2i) -> Vector2i:
		while parent[x] != x:
			x = parent[x]
		return x
	var keep: Array = []
	for e in edges:
		var ra: Vector2i = find.call(e[0])
		var rb: Vector2i = find.call(e[1])
		if ra != rb:
			parent[ra] = rb
			keep.append(e)
		elif rng.randf() < EDGE_KEEP:
			keep.append(e)
	for e in keep:
		var a: Vector2i = e[0]
		var b: Vector2i = e[1]
		var mid := ((nodes[hubs[a]]["pos"] as Vector2) + (nodes[hubs[b]]["pos"] as Vector2)) * 0.5
		var br: Dictionary = branches[sector_of.call(mid)]
		var tid := "%s_e_%d_%d_%d_%d" % [cls.id, a.x + 50, a.y + 50, b.x + 50, b.y + 50]
		var est := {"attr_" + str(br["attr"]): ROAD_ATTR}
		nodes[tid] = _node(tid, "stat", "", "Passagem", "Passagem: %s." % stat_text(est), 1, 1, mid)
		nodes[tid]["stats"] = est
		nodes[tid]["branch"] = "ring"
		_link(nodes, hubs[a], tid)
		_link(nodes, tid, hubs[b])
	# círculos
	var far := 0.0                    # casa mais longe: o fundo da teia (+10)
	for cl in clusters:
		far = maxf(far, (cl["cell"]["c"] as Vector2).length())
	var notable_i := rng.randi() % 7
	var small_i := {}                 # por ramo: anda pela lista de passivos da build
	var out_clusters: Array = []
	for cl in clusters:
		var cell: Dictionary = cl["cell"]
		var c: Vector2 = cell["c"] + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * JITTER_CELL
		var bi: int = cl["branch"]
		var br: Dictionary = branches[bi]
		var tag: String = br["id"] if br["id"] != "" else "geral"
		# entrada: o canto da casa mais perto do início
		var corner := Vector2i(cell["i"] + (1 if c.x < 0 else 0), cell["j"] + (1 if c.y < 0 else 0))
		var far_corner := Vector2i(cell["i"] + (0 if c.x < 0 else 1), cell["j"] + (0 if c.y < 0 else 1))
		var to_hub := (Vector2(corner.x, corner.y) * CELL - c).normalized()
		var base_a := to_hub.angle()
		var cid := "%s_%d_%d" % [tag, cell["i"] + 50, cell["j"] + 50]
		if cl["kind"] == "skill":
			var sk: SkillDef = cl["skill"]
			var nid := "%s_s_%s" % [cls.id, sk.id]
			nodes[nid] = _node(nid, "skill", sk.id, sk.name, sk.description, sk.unlock_level, Balance.SKILL_LEARN_COST, c)
			nodes[nid]["branch"] = br["id"]
			var evs: Array = by_skill.get(sk.id, [])
			var slots := 4 + evs.size()
			var roles: Array = []                     # papel de cada posição: entrada, maestria (do outro lado), evoluções, passivos
			roles.resize(slots)
			roles[0] = "in"
			roles[slots / 2] = "m"
			var q: Array = evs.duplicate()
			for s in range(slots):
				if roles[s] == null:
					roles[s] = q.pop_front() if not q.is_empty() else "p"
			for s in range(slots):
				var a := base_a + TAU * s / float(slots)
				var at := c + Vector2(cos(a), sin(a)) * WHEEL_R
				var sid := ""
				if str(roles[s]) == "in":                 # entrada: atributo da build, liga na junção
					sid = "%s_n_%s_in" % [cls.id, cid]
					var st := {"attr_" + str(br["attr"]): _depth(c, CLUSTER_ATTR, far)}
					nodes[sid] = _node(sid, "stat", "", stat_text(st), "Passivo: %s." % stat_text(st), 1, 1, at)
					nodes[sid]["stats"] = st
					_link(nodes, sid, hubs[corner])
				elif str(roles[s]) == "m":            # maestria do outro lado da entrada
					sid = "%s_m_%s" % [cls.id, sk.id]
					nodes[sid] = _node(sid, "mastery", sk.id, "Maestria: " + sk.name, mastery_desc(sk), sk.unlock_level, 1, at)
				elif roles[s] is TalentDef:
					var t: TalentDef = roles[s]
					sid = "%s_t_%s" % [cls.id, t.id]
					nodes[sid] = _node(sid, "talent", t.id, t.name, t.description, t.unlock_level, t.cost, at)
				else:                                 # passivo da build
					sid = "%s_n_%s_%d" % [cls.id, cid, s]
					var smalls: Array = br["passives"] if not br.get("passives", []).is_empty() else ROLE_STATS.get(br["role"], ROLE_STATS[""])
					var si: int = small_i.get(bi, 0)
					small_i[bi] = si + 1
					var st := _power(_scaled(smalls[si % smalls.size()], 0.25), cls)
					nodes[sid] = _node(sid, "stat", "", stat_text(st), "Passivo: %s." % stat_text(st), sk.unlock_level, 1, at)
					nodes[sid]["stats"] = st
				nodes[sid]["branch"] = br["id"]
				_link(nodes, nid, sid)
			out_clusters.append({"center": c, "r": WHEEL_R, "kind": "skill", "branch": br["id"]})
		else:
			# notável: anel de 5 nós pequenos, notável no centro ligado a dois do anel; duas entradas (atalho)
			var pick: Array
			if rng.randf() < 0.5:
				var arm_notes: Array = ARM_NOTABLES.get(br["role"], ARM_NOTABLES[""])
				pick = arm_notes[notable_i % arm_notes.size()]
			else:
				pick = RING_NOTABLES[notable_i % RING_NOTABLES.size()]
			notable_i += 1
			var nn := "%s_n_%s_x" % [cls.id, cid]
			var nst := _power(_scaled(pick[1]), cls)
			var na := "attr_" + str(br["attr"])
			nst[na] = int(nst.get(na, 0)) + _depth(c, NOTABLE_ATTR, far)
			nodes[nn] = _node(nn, "notable", "", pick[0], "Notável: %s." % stat_text(nst), 1, 1, c)
			nodes[nn]["stats"] = nst
			nodes[nn]["branch"] = br["id"]
			var ring: Array = []
			for s in range(5):
				var a := base_a + TAU * s / 5.0
				var sid := "%s_n_%s_%d" % [cls.id, cid, s]
				var ra := "attr_" + str(br["attr"] if s % 4 == 0 else br["attr2"])
				var st := {ra: _depth(c, CLUSTER_ATTR, far) if s % 2 == 0 else ROAD_ATTR}     # 3 de 5 dão o atributo do círculo, 2 dão +1
				nodes[sid] = _node(sid, "stat", "", stat_text(st), "Passivo: %s." % stat_text(st), 1, 1, c + Vector2(cos(a), sin(a)) * WHEEL_R)
				nodes[sid]["stats"] = st
				nodes[sid]["branch"] = br["id"]
				ring.append(sid)
			for s in range(5):
				_link(nodes, ring[s], ring[(s + 1) % 5])
			_link(nodes, nn, ring[2])
			_link(nodes, nn, ring[3])
			_link(nodes, ring[0], hubs[corner])
			if hubs.has(far_corner):
				var a_far := (Vector2(far_corner.x, far_corner.y) * CELL - c).angle()
				var best := 0
				var bd := INF
				for s in range(5):                    # a 2ª entrada sai do nó do anel virado para o outro canto
					var d := absf(angle_difference(base_a + TAU * s / 5.0, a_far))
					if d < bd:
						bd = d
						best = s
				_link(nodes, ring[best], hubs[far_corner])
			out_clusters.append({"center": c, "r": WHEEL_R, "kind": "notable", "branch": br["id"]})
	# evoluções do dash: círculo pequeno na primeira casa do Geral, em corrente a partir do início
	if not dash_cell.is_empty():
		var c: Vector2 = dash_cell["c"]
		for i in range(dash_talents.size()):
			var t: TalentDef = dash_talents[i]
			var tnid := "%s_t_%s" % [cls.id, t.id]
			nodes[tnid] = _node(tnid, "talent", t.id, t.name, t.description, t.unlock_level, t.cost, c * (0.55 + 0.3 * i))      # espora do início

			nodes[tnid]["branch"] = "start"
			_link(nodes, start if i == 0 else "%s_t_%s" % [cls.id, dash_talents[i - 1].id], tnid)
	_class_picks(cls, nodes)
	return {"start": start, "nodes": nodes, "panes": panes, "clusters": out_clusters}

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

## Bônus de notável escalado (% x NOTABLE_SCALE, arredondado; atributo fica).
static func _scaled(st: Dictionary, k_mult: float = NOTABLE_SCALE) -> Dictionary:
	var out := {}
	for k in st:
		out[k] = st[k] if str(k).begins_with("attr_") else (snappedf(float(st[k]) * k_mult, 0.5) if st[k] is float else maxi(1, roundi(float(st[k]) * k_mult)))
	return out

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
