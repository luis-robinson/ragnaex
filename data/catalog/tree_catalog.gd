class_name TreeCatalog
extends RefCounted
## Teia de pontos de skill (estilo Path of Exile) — uma por classe, gerada por loops a partir das skills
## (SkillsCatalog), builds (ClassDef.builds) e evoluções (TalentsCatalog). Nada escrito nó a nó.
##
## Forma (estilo PoE): MALHA de junções e estradas (grade irregular, sorteio fixo por classe) com CÍRCULOS nas casas:
## de skill (skill no centro; maestria, evoluções e passivos em volta) e de notável (anel com o notável no meio, duas
## entradas). Setores por ramo (Geral + builds) em volta do início; skill de nível alto mais longe. Ver _class_tree.
##
## Nó: {id, kind: start|skill_up|skill_quick|skill_charge|stat|notable|talent|pick, ref, name, desc, level, cost, pos: Vector2, links: [ids], stats: {}, branch}
## Skills vêm pelo nível (ProgressionSystem.grant_level_skills); no centro do círculo fica "<Skill> Aprimorada" (skill_up,
## id <classe>_s_<skill>) e do outro lado da entrada "<Skill> Ágil" (skill_quick, id <classe>_m_<skill>): ids, posições e
## ligações de sempre. O rank 1-5 da skill sobe no Mestre de Skills (ProgressionSystem.rank_up), fora da teia.
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
	"titan_relief": "Empunhadura de Titã: +%d nó de alívio (3%% de velocidade do básico)",
	"shadow_time": "Sombra Gêmea: +%d s de clone", "shadow_share": "Sombra Gêmea: +%d nó de força (5%% do dano)", "execute_pct": "Execução: +%d nó de dano (10%%)",
	"falcon_pct": "%+d%% dano do mergulho do falcão", "prey_crit": "%+d crítico contra a Presa",
	"threat_pct": "%+d%% ameaça gerada", "dr_pct": "%+d%% redução de todo dano recebido",
	"crit_leech": "crítico cura %d%% do dano causado", "low_leech": "%+d%% roubo de vida abaixo de 35%% da vida",
	"mana_guard": "%d%% do dano recebido sai da mana", "hit_slow": "golpe físico deixa o alvo %d%% mais lento (2 s)",
	"heal_taken_pct": "%+d%% cura recebida", "def_atk_pct": "%d%% da DEF somada ao ATK (a DEF fica)",
	"block_reflect": "bloqueio devolve %d%% do golpe", "guard_crit": "bloquear dá %+d%% de crítico por 4 s",
	"taunt_dmg_pct": "%+d%% de dano em quem tem você como alvo", "thorns": "devolve %d%% do dano corpo a corpo recebido",
	"cc_resist_pct": "-%d%% duração de atordoar/prender/lentidão",
	"mp_to_hp": "+HP máximo igual a %d%% do MP máximo", "summon_guard": "%d%% do dano recebido vai para a sua invocação mais perto",
	"summon_frenzy": "invocação abaixo de 50%% da vida causa %+d%% de dano", "leech_shield": "roubo de vida que passa do máximo vira barreira (até %d%% da vida)",
	"ally_guard": "%d%% do dano dos aliados do grupo a até 8 m vai para você", "low_dr": "-%d%% de dano recebido abaixo de 50%% da vida",
	"low_hp_atk": "até %+d%% de dano quanto menor a vida", "overheal_share": "%d%% da cura que passa do máximo vai para o aliado mais ferido",
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
		if m.has("charges_add"): out.append("+%d carga" % int(m["charges_add"]))
		if m.has("iframes"): out.append("+%.2f s invulnerável" % float(m["iframes"]))
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
	"titan_relief": "+%d Titã", "shadow_time": "+%d s Sombra", "shadow_share": "+%d Sombra", "execute_pct": "+%d Execução",
	"falcon_pct": "%+d%% Falcão", "prey_crit": "%+d Crít Presa",
	"threat_pct": "%+d%% Ameaça", "dr_pct": "%+d%% Redução",
	"crit_leech": "Crít cura %d%%", "low_leech": "%+d%% Roubo na beira", "mana_guard": "%d%% Mana-escudo", "hit_slow": "Lentidão %d%%",
	"heal_taken_pct": "%+d%% Cura recebida", "def_atk_pct": "+%d%% DEF em ATK", "block_reflect": "Reflete %d%%", "guard_crit": "%+d Crít bloqueio",
	"taunt_dmg_pct": "%+d%% Provocado", "thorns": "Espinhos %d%%", "cc_resist_pct": "-%d%% Controle",
	"mp_to_hp": "MP->HP %d%%", "summon_guard": "%d%% Escudo de carne", "summon_frenzy": "%+d%% Invocação ferida", "leech_shield": "Barreira %d%%",
	"ally_guard": "%d%% Protege aliados", "low_dr": "-%d%% Dano na beira", "low_hp_atk": "%+d%% Dano na beira", "overheal_share": "%d%% Cura transborda",
	"attr_FOR": "%+d FOR", "attr_AGI": "%+d AGI", "attr_VIT": "%+d VIT", "attr_WILL": "%+d WILL", "attr_INT": "%+d INT"}
## família do passivo (cor do rótulo): defesa, ataque, magia, cura, mobilidade
const STAT_FAMILY := {"def_pct": "def", "hp_pct": "def", "evasion": "def", "atk_pct": "atk", "crit": "atk", "lifesteal": "atk",
	"aspd_pct": "atk", "backstab": "atk", "pet_pct": "atk", "matk_pct": "mag", "mp_pct": "mag", "fire_pct": "mag", "frost_pct": "mag",
	"storm_pct": "mag", "heal_pct": "heal", "buff_pct": "heal", "radiance": "heal", "speed_pct": "move", "cdr": "move", "titan_relief": "atk", "shadow_time": "atk", "shadow_share": "atk", "execute_pct": "atk",
	"falcon_pct": "atk", "prey_crit": "atk",
	"threat_pct": "def", "dr_pct": "def",
	"crit_leech": "def", "low_leech": "def", "mana_guard": "def", "hit_slow": "def", "heal_taken_pct": "def", "cc_resist_pct": "def",
	"def_atk_pct": "atk", "block_reflect": "atk", "guard_crit": "atk", "taunt_dmg_pct": "atk", "thorns": "atk",
	"mp_to_hp": "def", "summon_guard": "def", "summon_frenzy": "atk", "leech_shield": "def", "ally_guard": "def", "low_dr": "def",
	"low_hp_atk": "atk", "overheal_share": "heal",
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
			if sk.build == br["id"] and not sk.ascension:     # ascensão: teia própria (ascension_tree), fora desta
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
	keep.append_array(_early_shortcuts(cls, clusters, hubs, keep))     # não sorteia nada: o resto da teia sai igual
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
	var sig_done := {}                # ramos que já têm o notável-assinatura (Balance.BUILD_WEB_NOTABLES)
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
			nodes[nid] = _node(nid, "skill_up", sk.id, up_name(sk), up_desc(sk), sk.unlock_level, Balance.SKILL_LEARN_COST, c)
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
			if charge_ok(sk):
				for s in range(slots - 1, -1, -1):        # o último passivo vira "em Cargas"
					if str(roles[s]) == "p":
						roles[s] = "k"
						break
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
				elif str(roles[s]) == "k":            # "em Cargas" no lugar do último passivo (posição e ids dos outros ficam)
					sid = "%s_k_%s" % [cls.id, sk.id]
					nodes[sid] = _node(sid, "skill_charge", sk.id, charge_name(sk), charge_desc(sk), sk.unlock_level, Balance.SKILL_CHARGE_COST, at)
					small_i[bi] = int(small_i.get(bi, 0)) + 1          # o sorteio de passivos anda igual (os outros não mudam)
				elif str(roles[s]) == "m":            # "Ágil" do outro lado da entrada (era a maestria)
					sid = "%s_m_%s" % [cls.id, sk.id]
					nodes[sid] = _node(sid, "skill_quick", sk.id, quick_name(sk), quick_desc(sk), sk.unlock_level, Balance.SKILL_QUICK_COST, at)
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
			if Balance.BUILD_WEB_NOTABLES.has(br["id"]) and not sig_done.has(br["id"]):     # notável-assinatura da build (sorteio igual)
				sig_done[br["id"]] = true
				pick = Balance.BUILD_WEB_NOTABLES[br["id"]]
				nst = (pick[1] as Dictionary).duplicate()
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
		var chain: Array = dash_talents.filter(func(t): return not is_dash_node(t))
		var ring: Array = dash_talents.filter(func(t): return is_dash_node(t))
		for i in range(chain.size()):
			var t: TalentDef = chain[i]
			var tnid := "%s_t_%s" % [cls.id, t.id]
			nodes[tnid] = _node(tnid, "talent", t.id, t.name, t.description, t.unlock_level, t.cost, c * (0.55 + 0.3 * i))      # espora do início

			nodes[tnid]["branch"] = "start"
			_link(nodes, start if i == 0 else "%s_t_%s" % [cls.id, chain[i - 1].id], tnid)
		ring.sort_custom(func(a, b): return dash_node_index(a) < dash_node_index(b))
		if not ring.is_empty():
			_dash_ring(cls, nodes, c, ring, start if chain.is_empty() else "%s_t_%s" % [cls.id, chain[-1].id])
	_role_notables(cls, nodes)
	_outer_web(cls, nodes, branches, hubs, used_cells, sector_of, out_clusters, far)
	_rim_web(cls, nodes, branches, hubs, used_cells, sector_of, out_clusters)
	_core_ring(cls, nodes, start)
	_class_picks(cls, nodes)
	return {"start": start, "nodes": nodes, "panes": panes, "clusters": out_clusters}

## Atalhos das skills cedo (Balance.WEB_EARLY_LEVEL): para cada círculo de skill inicial/de nível baixo, o caminho mais curto
## na grade de junções do início (0,0) até o canto de entrada da casa; devolve as estradas desse caminho que a árvore
## sorteada não tem (formato de `keep`: [a, b, 0.0]). Busca em largura com vizinhos em ordem fixa (determinístico).
static func _early_shortcuts(cls: ClassDef, clusters: Array, hubs: Dictionary, keep: Array) -> Array:
	var have := {}
	for e in keep:
		have[[e[0], e[1]]] = true
	var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var prev := {Vector2i(0, 0): Vector2i(0, 0)}
	var queue: Array = [Vector2i(0, 0)]
	while not queue.is_empty():
		var h: Vector2i = queue.pop_front()
		for d: Vector2i in dirs:
			var n := h + d
			if hubs.has(n) and not prev.has(n):
				prev[n] = h
				queue.append(n)
	var out: Array = []
	for cl in clusters:
		if cl["kind"] != "skill":
			continue
		var sk: SkillDef = cl["skill"]
		if sk.unlock_level > Balance.WEB_EARLY_LEVEL and not (sk.id in cls.starting_skills):
			continue
		var cc: Vector2 = cl["cell"]["c"]
		var at := Vector2i(cl["cell"]["i"] + (1 if cc.x < 0 else 0), cl["cell"]["j"] + (1 if cc.y < 0 else 0))
		while prev.has(at) and at != Vector2i(0, 0):
			var p: Vector2i = prev[at]
			var key: Array = [p, at] if (p.x < at.x or p.y < at.y) else [at, p]     # mesma ordem das estradas (a -> a+1)
			if not have.has(key):
				have[key] = true
				out.append([key[0], key[1], 0.0])
			at = p
	return out

## Custo (pontos) e saltos do caminho mais barato do início até cada nó (Dijkstra pelo custo do nó em que se entra):
## nó -> [pontos, saltos]. Ex.: path_costs(GameData.trees["berserker"]["nodes"], start)[nid][0]. Usado por web_probe --reach e testes.
static func path_costs(nodes: Dictionary, start: String) -> Dictionary:
	var best := {start: [0, 0]}
	var open: Array = [start]
	while not open.is_empty():
		open.sort_custom(func(a, b): return int(best[a][0]) < int(best[b][0]))
		var cur: String = open.pop_front()
		for l in nodes[cur]["links"]:
			var c: int = int(best[cur][0]) + int(nodes[l]["cost"])
			if not best.has(l) or c < int(best[l][0]):
				best[l] = [c, int(best[cur][1]) + 1]
				if not (l in open):
					open.append(l)
	return best

const DASH_RING_GAP := 0.9       # unidades entre a evolução de dash da classe e o 1º nó do anel genérico
## Nó genérico de dash (Balance.DASH_NODES)? O id termina no id da linha (ex.: ass_t_dash_extra).
static func is_dash_node(t: TalentDef) -> bool:
	return dash_node_index(t) >= 0

## Posição da linha do nó genérico em Balance.DASH_NODES (-1 = não é).
static func dash_node_index(t: TalentDef) -> int:
	for i in range(Balance.DASH_NODES.size()):
		if t.id.ends_with("_t_" + str(Balance.DASH_NODES[i][0])):
			return i
	return -1

## Nós genéricos do dash em anel no centro da casa do dash (2026-11-24): o 1º (nível mais baixo) de frente para a
## evolução de dash da classe (`entry`), o último do outro lado; cada nó liga aos vizinhos do anel (losango, sem fechar
## pela frente: o do nível 30 só abre por um dos dois do 20).
static func _dash_ring(cls: ClassDef, nodes: Dictionary, c: Vector2, ring: Array, entry: String) -> void:
	var from: Vector2 = nodes[entry]["pos"]
	var gap := maxf(from.distance_to(c), WHEEL_R + DASH_RING_GAP)     # o nó da frente não encosta na evolução da classe
	c = from + (c - from).normalized() * gap
	var back: float = (from - c).angle()
	var ids: Array = []
	var n := ring.size()
	for i in range(n):
		var t: TalentDef = ring[i]
		var tnid := "%s_t_%s" % [cls.id, t.id]
		# 0 = frente (para a entrada); depois alterna lados e o último fica no fundo
		var slot: float = 0.0 if i == 0 else (PI if i == n - 1 and n > 2 else (PI * 0.5 if i % 2 == 1 else -PI * 0.5))
		var at := c + Vector2.from_angle(back + slot) * WHEEL_R
		nodes[tnid] = _node(tnid, "talent", t.id, t.name, t.description, t.unlock_level, t.cost, at)
		nodes[tnid]["branch"] = "start"
		ids.append(tnid)
	_link(nodes, entry, ids[0])
	for i in range(1, n):
		var last := i == n - 1 and n > 2
		if last:
			_link(nodes, ids[i], ids[1])
			if n > 3:
				_link(nodes, ids[i], ids[2])
		else:
			_link(nodes, ids[0], ids[i])

## --- Fronteira (Ato II, níveis 31-45; GDD ato2-horda R7) ---
## Região de fora da teia do 30: casas livres até Balance.WEB_OUTER_GRID_K, por setor, sempre encostadas na malha (sem ilha).
## Tudo exige nível >= 31, então a teia do 30 não muda (ids, posições, valores e o gasto dos bots). Sorteio próprio
## (`<classe>_teia_ato2`): nada do sorteio da teia antiga anda. Por setor de build: notáveis da build (nomes abaixo, bônus
## dos passivos da build), notáveis de elo na divisa com a build vizinha (as builds ficam híbridas, R7.1), um círculo de
## pedra-angular (duas opções que se excluem, nível 40) e o Ápice da build (nível 45) no fundo. O Geral ganha poucas casas.
## Nomes dos notáveis da Fronteira por build: [notável 1, notável 2, Ápice].
const OUTER_BUILD_NAMES := {
	"guardiao": ["Escudo de Aldara", "Voto de Ferro", "Égide Imortal"], "cruzado": ["Lâmina Sagrada", "Carga Santa", "Juízo Final"],
	"templario": ["Chama do Templo", "Selo Ardente", "Sol Inquebrável"], "carniceiro": ["Redemoinho Rubro", "Fio Duplo", "Tempestade de Machados"],
	"executor": ["Golpe do Carrasco", "Couro de Titã", "Sentença"], "punhos": ["Punho Sombrio", "Dança da Fúria", "Mil Punhos"],
	"sacerdote": ["Prece Longa", "Mão Santa", "Milagre"], "inquisidor": ["Luz Implacável", "Radiância Viva", "Aurora"],
	"batalha": ["Martelo da Fé", "Hino de Guerra", "Cruzada Viva"], "guardiao_verde": ["Casca de Carvalho", "Raiz Funda", "Ancião da Mata"],
	"fera": ["Presas Afiadas", "Uivo da Matilha", "Rei Lobo"], "xama": ["Canto da Chuva", "Espírito do Bosque", "Voz da Floresta"],
	"cacador": ["Laço do Lince", "Trilha Fresca", "Mestre da Caçada"], "atirador": ["Pólvora Fina", "Mira de Cano", "Último Tiro"],
	"lanceiro": ["Ponta de Osso", "Arremesso Selvagem", "Lança do Primeiro Caçador"], "laminas": ["Veneno Lento", "Sombra Rápida", "Mil Cortes"],
	"duelista": ["Esgrima Fina", "Parada e Resposta", "Mestre de Armas"], "corsario": ["Pólvora e Aço", "Lei do Convés", "Terror dos Mares"],
	"fogo": ["Brasa Viva", "Coração de Fogo", "Inferno"], "gelo": ["Geada Funda", "Coração de Gelo", "Inverno Eterno"],
	"raio": ["Faísca", "Céu Carregado", "Fúria dos Céus"], "invocador": ["Legião", "Ossos Fortes", "Senhor dos Mortos"],
	"ceifador": ["Colheita", "Fome da Foice", "Ceifa Final"], "pestilento": ["Miasma", "Sombra Densa", "Noite Sem Fim"],
}
## Pedras-angulares por papel: duas opções que se excluem (comprar uma tranca a outra até o reset). [nome, bônus, lado];
## lado "atk" = ofensiva (bots de dano), "def" = segura (bots de tanque e cura). "power" = ATK ou MATK da build.
const KEYSTONES := {
	"tank": [["Fúria do Protetor", {"power": 7, "threat_pct": 30, "def_pct": -6}, "atk"], ["Baluarte Eterno", {"hp_pct": 7, "dr_pct": 3, "speed_pct": -5}, "def"]],
	"dps": [["Sede de Sangue", {"power": 7, "lifesteal": 2, "hp_pct": -6}, "atk"], ["Guarda Alta", {"def_pct": 10, "hp_pct": 5, "aspd_pct": -4}, "def"]],
	"ranged": [["Tiro Paciente", {"crit": 4.0, "power": 5, "speed_pct": -6}, "atk"], ["Caçador Nômade", {"speed_pct": 8, "evasion": 3.0, "power": -3}, "def"]],
	"caster": [["Sobrecarga Arcana", {"power": 8, "mp_pct": -15}, "atk"], ["Mente Contínua", {"cdr": 6, "mp_pct": 12, "power": -3}, "def"]],
	"healer": [["Fé Militante", {"power": 7, "heal_pct": -5}, "atk"], ["Mártir", {"heal_pct": 10, "hp_pct": 5, "power": -6}, "def"]],
	"": [["Andarilho", {"speed_pct": 6, "cdr": 4, "hp_pct": -4}, "atk"], ["Colosso", {"hp_pct": 6, "def_pct": 5, "speed_pct": -5}, "def"]],
}
const KEYSTONE_R := 0.45          # pedras-angulares: dentro do anel, uma de cada lado do centro

## "power" vira o ataque da build (MATK para INT, magia e cura; ATK para o resto). No Geral vale _power (classe).
static func _build_power(st: Dictionary, br: Dictionary, cls: ClassDef) -> Dictionary:
	if br["id"] == "":
		return _power(st, cls)
	var key := "matk_pct" if (br["attr"] == "INT" or br["role"] in ["caster", "healer"]) else "atk_pct"
	var out := {}
	for k in st:
		var kk: String = key if k == "power" else k
		out[kk] = st[k]
	return out

## Passivos da build x mult (soma por stat), para os notáveis e o Ápice da Fronteira.
static func _build_stats(br: Dictionary, cls: ClassDef, picks: Array, mult: float) -> Dictionary:
	var smalls: Array = br["passives"] if not br.get("passives", []).is_empty() else ROLE_STATS.get(br["role"], ROLE_STATS[""])
	var acc := {}
	for i in picks:
		var st: Dictionary = _build_power(smalls[int(i) % smalls.size()], br, cls)
		for k in st:
			acc[k] = float(acc.get(k, 0.0)) + float(st[k]) * mult
	var out := {}
	for k in acc:
		out[k] = snappedf(acc[k], 0.5) if k in ["crit", "evasion"] else maxi(1, roundi(acc[k]))
	return out

static func _outer_web(cls: ClassDef, nodes: Dictionary, branches: Array, hubs: Dictionary, used_cells: Dictionary,
		sector_of: Callable, out_clusters: Array, far: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cls.id + "_teia_ato2")
	var k2: int = Balance.WEB_OUTER_GRID_K
	var r_out := k2 * CELL
	var lv_span: Array = Balance.WEB_OUTER_LEVEL
	var level_at := func(p: Vector2) -> int:
		return roundi(lerpf(lv_span[0], lv_span[1], clampf((p.length() - far) / maxf(1.0, r_out - far), 0.0, 1.0)))
	var plan := _grow(cls, nodes, branches, hubs, used_cells, sector_of, rng, k2, CELL * 2.0, Balance.WEB_OUTER_GERAL_CELLS, Balance.WEB_OUTER_CELLS, level_at, "Fronteira")
	_outer_circles(cls, nodes, branches, hubs, plan, rng, level_at, out_clusters)

## Escolhe as casas livres de uma região nova (Fronteira, Orla) por setor, sempre encostadas na malha (sem ilha), e liga as
## junções novas com estradas (árvore mínima + parte das outras). Devolve o plano [{cell, branch, slot}]. Usa o `rng` da
## região na ordem de sempre (a Fronteira não muda). `geral_cells`/`build_cells` = casas do Geral (ramo 0) / de cada build; `min_len` = distância mínima do centro.
static func _grow(cls: ClassDef, nodes: Dictionary, branches: Array, hubs: Dictionary, used_cells: Dictionary, sector_of: Callable,
		rng: RandomNumberGenerator, k2: int, min_len: float, geral_cells: int, build_cells: int, level_at: Callable, label: String,
		relax: bool = false) -> Array:
	var n_br := branches.size()
	var r_out := k2 * CELL
	# casas livres por setor, perto -> longe
	var cand: Array = []
	for bi in range(n_br):
		cand.append([])
	for i in range(-k2, k2):
		for j in range(-k2, k2):
			var key := Vector2i(i, j)
			var c := Vector2((i + 0.5) * CELL, (j + 0.5) * CELL)
			if used_cells.has(key) or c.length() > r_out or (c.length() < min_len and not relax):
				continue
			cand[sector_of.call(c)].append({"i": i, "j": j, "c": c, "d": c.length() + rng.randf() * CELL * 0.35, "inner": c.length() < min_len})
	for bi in range(n_br):
		cand[bi].sort_custom(func(a, b): return float(a["d"]) < float(b["d"]))
	# escolhe as casas: em rodízio, cada setor pega a mais perto que encosta na malha (sem ilha)
	var plan: Array = []              # {cell, branch, slot}
	var took: Array = []
	for bi in range(n_br):
		took.append(0)
	var new_hubs := {}
	var progress := true
	var loose := false               # `relax`: setor que não acha casa por fora de min_len aceita uma de dentro
	while progress:
		progress = false
		for bi in range(n_br):
			if took[bi] >= (geral_cells if bi == 0 else build_cells):
				continue
			for cell in cand[bi]:
				var key := Vector2i(cell["i"], cell["j"])
				if used_cells.has(key) or not _touches(hubs, key) or (cell["inner"] and not loose):
					continue
				used_cells[key] = true
				plan.append({"cell": cell, "branch": bi, "slot": took[bi]})
				took[bi] += 1
				progress = true
				for dx in [0, 1]:
					for dy in [0, 1]:
						var h := Vector2i(key.x + dx, key.y + dy)
						if hubs.has(h):
							continue
						var hp := Vector2(h.x, h.y) * CELL + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * JITTER_HUB
						var br: Dictionary = branches[sector_of.call(hp)]
						var hid := "%s_h_%d_%d" % [cls.id, h.x + 50, h.y + 50]
						var hst := {"attr_" + str(br["attr"]): ROAD_ATTR}
						nodes[hid] = _node(hid, "stat", "", "Junção", "Junção da %s: %s." % [label, stat_text(hst)],level_at.call(hp), 1, hp)
						nodes[hid]["stats"] = hst
						nodes[hid]["branch"] = "ring"
						hubs[h] = hid
						new_hubs[h] = true
				break
		if not progress and relax and not loose:
			loose = true
			progress = true
	# estradas novas: árvore mínima ligando as junções novas à malha (a antiga já é um bloco só) + parte das outras
	var hub_keys: Array = hubs.keys()
	hub_keys.sort()
	var edges: Array = []
	for h in hub_keys:
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			if hubs.has(h + d) and (new_hubs.has(h) or new_hubs.has(h + d)):
				edges.append([h, h + d, rng.randf()])
	edges.sort_custom(func(a, b): return float(a[2]) < float(b[2]))
	var parent := {}
	var root := Vector2i(0, 0)
	for h in hub_keys:
		parent[h] = h if new_hubs.has(h) else root
	parent[root] = root
	for e in edges:
		var ra: Vector2i = _find(parent, e[0])
		var rb: Vector2i = _find(parent, e[1])
		if ra != rb:
			parent[ra] = rb
		elif rng.randf() >= Balance.WEB_OUTER_EDGE_KEEP:
			continue
		var a: Vector2i = e[0]
		var b: Vector2i = e[1]
		var mid := ((nodes[hubs[a]]["pos"] as Vector2) + (nodes[hubs[b]]["pos"] as Vector2)) * 0.5
		var br: Dictionary = branches[sector_of.call(mid)]
		var tid := "%s_e_%d_%d_%d_%d" % [cls.id, a.x + 50, a.y + 50, b.x + 50, b.y + 50]
		var est := {"attr_" + str(br["attr"]): ROAD_ATTR}
		nodes[tid] = _node(tid, "stat", "", "Passagem", "Passagem da %s: %s." % [label, stat_text(est)], level_at.call(mid), 1, mid)
		nodes[tid]["stats"] = est
		nodes[tid]["branch"] = "ring"
		_link(nodes, hubs[a], tid)
		_link(nodes, tid, hubs[b])
	return plan

## Círculos da Fronteira: no setor de build o último é o Ápice e o penúltimo a pedra-angular; o Geral fecha com a pedra-angular.
static func _outer_circles(cls: ClassDef, nodes: Dictionary, branches: Array, hubs: Dictionary, plan: Array, rng: RandomNumberGenerator,
		level_at: Callable, out_clusters: Array) -> void:
	var arm_i := rng.randi() % 4
	var elo_done := {}                # Vector2i(ramo, vizinho) já com elo
	for pl in plan:
		var cell: Dictionary = pl["cell"]
		var bi: int = pl["branch"]
		var br: Dictionary = branches[bi]
		var slot: int = pl["slot"]
		var last := _outer_cells(bi) - 1
		var kind := "notable"
		if slot == last:
			kind = "keystone" if bi == 0 else "apex"
		elif bi > 0 and slot == last - 1:
			kind = "keystone"
		var c: Vector2 = cell["c"] + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * JITTER_CELL
		var tag: String = br["id"] if br["id"] != "" else "geral"
		var corner := Vector2i(cell["i"] + (1 if c.x < 0 else 0), cell["j"] + (1 if c.y < 0 else 0))
		var far_corner := Vector2i(cell["i"] + (0 if c.x < 0 else 1), cell["j"] + (0 if c.y < 0 else 1))
		var base_a := (Vector2(corner.x, corner.y) * CELL - c).normalized().angle()
		var cid := "%s_%d_%d" % [tag, cell["i"] + 50, cell["j"] + 50]
		var lv: int = level_at.call(c)
		var main := "attr_" + str(br["attr"])
		var ring := _wheel(cls, nodes, hubs, br, c, cid, corner, far_corner, base_a, lv, "Fronteira")
		if kind == "keystone":
			_keystone_pair(cls, nodes, br, c, cid, base_a, ring, Balance.WEB_KEYSTONE_LEVEL, Balance.WEB_KEYSTONE_SCALE, Balance.WEB_KEYSTONE_ATTR, "")
			out_clusters.append({"center": c, "r": WHEEL_R, "kind": "keystone", "branch": br["id"]})
			continue
		var nn := "%s_n_%s_x" % [cls.id, cid]
		var nname := ""
		var nst := {}
		var nlv := lv
		var names: Array = OUTER_BUILD_NAMES.get(br["id"], [])
		var other := -1                   # 3ª casa: sempre elo com a build vizinha; 4ª: só na divisa e com a outra vizinha
		if kind == "notable" and bi > 0 and slot >= 2:
			other = _neighbor_build(c, bi, branches, slot == 2)
			if other >= 0 and elo_done.has(Vector2i(bi, other)):
				other = -1
			elif other >= 0:
				elo_done[Vector2i(bi, other)] = true
		if kind == "apex":
			nname = "Ápice: " + (str(names[2]) if names.size() > 2 else str(br["name"]))
			nst = _build_stats(br, cls, range(maxi(1, (br.get("passives", []) as Array).size())), Balance.WEB_APEX_MULT)
			nst[main] = int(nst.get(main, 0)) + Balance.WEB_APEX_ATTR
			nlv = Balance.WEB_APEX_LEVEL
		elif bi > 0 and slot < 2 and names.size() > slot:
			nname = names[slot]
			nst = _build_stats(br, cls, [slot], Balance.WEB_OUTER_PASSIVE_MULT)
			nst[main] = int(nst.get(main, 0)) + Balance.WEB_OUTER_NOTABLE_ATTR
		elif other >= 0:
			var ob: Dictionary = branches[other]
			nname = "Elo: %s e %s" % [br["name"], ob["name"]]
			nst = _build_stats(ob, cls, [0], Balance.WEB_OUTER_PASSIVE_MULT)
			nst[main] = int(nst.get(main, 0)) + Balance.WEB_HYBRID_ATTR
			var om := "attr_" + str(ob["attr"])
			nst[om] = int(nst.get(om, 0)) + Balance.WEB_HYBRID_ATTR
		else:
			var arm: Array = ARM_NOTABLES.get(br["role"], ARM_NOTABLES[""])
			var pick: Array = arm[arm_i % arm.size()]
			arm_i += 1
			nname = str(pick[0]) + " Maior"
			nst = _build_power(_scaled(pick[1], Balance.WEB_OUTER_ARM_SCALE), br, cls)
			nst[main] = int(nst.get(main, 0)) + Balance.WEB_OUTER_NOTABLE_ATTR
		nodes[nn] = _node(nn, "notable", "", nname, "%s: %s." % ["Ápice" if kind == "apex" else "Notável da Fronteira", stat_text(nst)], nlv, 1, c)
		nodes[nn]["stats"] = nst
		nodes[nn]["branch"] = br["id"]
		if kind == "apex":
			nodes[nn]["apex"] = true
		_link(nodes, nn, ring[2])
		_link(nodes, nn, ring[3])
		out_clusters.append({"center": c, "r": WHEEL_R, "kind": kind, "branch": br["id"]})

## Quantas casas da Fronteira o ramo `bi` ganha (0 = Geral).
static func _outer_cells(bi: int) -> int:
	return Balance.WEB_OUTER_GERAL_CELLS if bi == 0 else Balance.WEB_OUTER_CELLS

## Anel de 5 passivos de um círculo da Fronteira/Orla, ligado ao canto perto (a casa encosta na malha: existe) e, se houver,
## ao canto de longe pelo nó virado para ele. Devolve os 5 ids. `label` vai na descrição ("Passivo da Orla: ...").
static func _wheel(cls: ClassDef, nodes: Dictionary, hubs: Dictionary, br: Dictionary, c: Vector2, cid: String, corner: Vector2i,
		far_corner: Vector2i, base_a: float, lv: int, label: String) -> Array:
	var ring: Array = []
	for s in range(5):
		var a := base_a + TAU * s / 5.0
		var sid := "%s_n_%s_%d" % [cls.id, cid, s]
		var ra := "attr_" + str(br["attr"] if s % 4 == 0 else br["attr2"])
		var st := {ra: (Balance.WEB_OUTER_RING_ATTR if s != 2 else Balance.WEB_OUTER_RING_ATTR2) if s % 2 == 0 else ROAD_ATTR}
		nodes[sid] = _node(sid, "stat", "", stat_text(st), "Passivo da %s: %s." % [label, stat_text(st)], lv, 1, c + Vector2(cos(a), sin(a)) * WHEEL_R)
		nodes[sid]["stats"] = st
		nodes[sid]["branch"] = br["id"]
		ring.append(sid)
	for s in range(5):
		_link(nodes, ring[s], ring[(s + 1) % 5])
	_link(nodes, ring[0], hubs[corner])
	if hubs.has(far_corner):
		var a_far := (Vector2(far_corner.x, far_corner.y) * CELL - c).angle()
		var best := 0
		var bd := INF
		for s in range(5):
			var d := absf(angle_difference(base_a + TAU * s / 5.0, a_far))
			if d < bd:
				bd = d
				best = s
		_link(nodes, ring[best], hubs[far_corner])
	return ring

## Pedra-angular: duas opções do papel (KEYSTONES x `scale`, + `attr` do atributo da build) que se excluem, dentro do anel.
## `suffix` vai no nome (" Menor" na Orla).
static func _keystone_pair(cls: ClassDef, nodes: Dictionary, br: Dictionary, c: Vector2, cid: String, base_a: float, ring: Array,
		level: int, scale: float, attr: int, suffix: String) -> void:
	var main := "attr_" + str(br["attr"])
	var opts: Array = KEYSTONES.get(br["role"], KEYSTONES[""])
	var ids: Array = ["%s_n_%s_k0" % [cls.id, cid], "%s_n_%s_k1" % [cls.id, cid]]
	for o in range(2):
		var ks: Array = opts[o]
		var st := _build_power(_mult(ks[1], scale), br, cls)
		st[main] = int(st.get(main, 0)) + attr
		var a := base_a + PI * 0.5 + PI * o          # de lado em relação à entrada, cada uma junto de 2 nós do anel
		var at := c + Vector2(cos(a), sin(a)) * KEYSTONE_R
		nodes[ids[o]] = _node(ids[o], "notable", "", str(ks[0]) + suffix, "Pedra-angular: %s.\nExclui %s (só o reset desfaz)." % [stat_text(st), str(opts[1 - o][0]) + suffix],
			level, 1, at)
		nodes[ids[o]]["stats"] = st
		nodes[ids[o]]["branch"] = br["id"]
		nodes[ids[o]]["keystone"] = ks[2]
		nodes[ids[o]]["excludes"] = [ids[1 - o]]
		var near: Array = range(5)
		near.sort_custom(func(x, y): return (nodes[ring[x]]["pos"] as Vector2).distance_to(at) < (nodes[ring[y]]["pos"] as Vector2).distance_to(at))
		_link(nodes, ids[o], ring[near[0]])
		_link(nodes, ids[o], ring[near[1]])

## --- Orla (Ato III parte 1, níveis 46-50; GDD ato3-excesso-45-50 §6.5) ---
## Anel de casas por fora da Fronteira (de Balance.WEB_RIM_MIN_K a WEB_RIM_GRID_K casas do centro), sorteio próprio
## (`<classe>_teia_ato3`): a teia do 45 não muda. Por setor de build: notável da build (nome abaixo, 2 passivos da build),
## notável de elo com a vizinha e uma pedra-angular menor (KEYSTONES x WEB_RIM_KEYSTONE_SCALE, duas opções que se excluem);
## o Geral: um notável de papel "Maior" e a pedra-angular menor. Tudo exige nível WEB_RIM_LEVEL (46 perto -> 49 longe).
const RIM_BUILD_NAMES := {
	"guardiao": "Muralha Sem Fim", "cruzado": "Fé Afiada", "templario": "Brasa Sagrada", "carniceiro": "Rodopio Sem Fim",
	"executor": "Mão do Carrasco", "punhos": "Ritmo de Ferro", "sacerdote": "Graça Serena", "inquisidor": "Olhar da Luz",
	"batalha": "Fé de Campanha", "guardiao_verde": "Tronco Velho", "fera": "Fome da Matilha", "xama": "Chuva Mansa",
	"cacador": "Olho do Falcão", "atirador": "Cano Quente", "lanceiro": "Ponta Certeira", "laminas": "Fio Silencioso",
	"duelista": "Passo de Esgrima", "corsario": "Sal e Pólvora", "fogo": "Chama Clara", "gelo": "Frio Sereno",
	"raio": "Trovão Longo", "invocador": "Exército Fiel", "ceifador": "Foice Faminta", "pestilento": "Névoa Doce",
}

static func _rim_cells(bi: int) -> int:
	return Balance.WEB_RIM_GERAL_CELLS if bi == 0 else Balance.WEB_RIM_CELLS

static func _rim_web(cls: ClassDef, nodes: Dictionary, branches: Array, hubs: Dictionary, used_cells: Dictionary,
		sector_of: Callable, out_clusters: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cls.id + "_teia_ato3")
	var k2: int = Balance.WEB_RIM_GRID_K
	var r_in: float = Balance.WEB_RIM_MIN_K * CELL
	var r_out := k2 * CELL
	var lv_span: Array = Balance.WEB_RIM_LEVEL
	var level_at := func(p: Vector2) -> int:
		return roundi(lerpf(lv_span[0], lv_span[1], clampf((p.length() - r_in) / maxf(1.0, r_out - r_in), 0.0, 1.0)))
	var plan := _grow(cls, nodes, branches, hubs, used_cells, sector_of, rng, k2, r_in, Balance.WEB_RIM_GERAL_CELLS, Balance.WEB_RIM_CELLS, level_at, "Orla", true)
	var arm_i := rng.randi() % 4
	var elo_done := {}
	for pl in plan:
		var cell: Dictionary = pl["cell"]
		var bi: int = pl["branch"]
		var br: Dictionary = branches[bi]
		var slot: int = pl["slot"]
		var c: Vector2 = cell["c"] + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * JITTER_CELL
		var tag: String = br["id"] if br["id"] != "" else "geral"
		var corner := Vector2i(cell["i"] + (1 if c.x < 0 else 0), cell["j"] + (1 if c.y < 0 else 0))
		var far_corner := Vector2i(cell["i"] + (0 if c.x < 0 else 1), cell["j"] + (0 if c.y < 0 else 1))
		var base_a := (Vector2(corner.x, corner.y) * CELL - c).normalized().angle()
		var cid := "%s_%d_%d" % [tag, cell["i"] + 50, cell["j"] + 50]
		var lv: int = level_at.call(c)
		var main := "attr_" + str(br["attr"])
		var ring := _wheel(cls, nodes, hubs, br, c, cid, corner, far_corner, base_a, lv, "Orla")
		if slot == _rim_cells(bi) - 1:           # última casa do ramo: pedra-angular menor
			_keystone_pair(cls, nodes, br, c, cid, base_a, ring, Balance.WEB_RIM_KEYSTONE_LEVEL, Balance.WEB_RIM_KEYSTONE_SCALE,
				Balance.WEB_RIM_KEYSTONE_ATTR, " Menor")
			out_clusters.append({"center": c, "r": WHEEL_R, "kind": "keystone", "branch": br["id"]})
			continue
		var nname := ""
		var nst := {}
		var other := _neighbor_build(c, bi, branches, true) if bi > 0 and slot == 1 else -1
		if other >= 0 and elo_done.has(Vector2i(bi, other)):
			other = -1
		if bi > 0 and slot == 0:
			nname = str(RIM_BUILD_NAMES.get(br["id"], br["name"]))
			nst = _build_stats(br, cls, [2, 3], Balance.WEB_RIM_PASSIVE_MULT)
			nst[main] = int(nst.get(main, 0)) + Balance.WEB_RIM_NOTABLE_ATTR
		elif other >= 0:
			elo_done[Vector2i(bi, other)] = true
			var ob: Dictionary = branches[other]
			nname = "Elo: %s e %s" % [br["name"], ob["name"]]
			nst = _build_stats(ob, cls, [1], Balance.WEB_RIM_PASSIVE_MULT)
			nst[main] = int(nst.get(main, 0)) + Balance.WEB_HYBRID_ATTR
			var om := "attr_" + str(ob["attr"])
			nst[om] = int(nst.get(om, 0)) + Balance.WEB_HYBRID_ATTR
		else:
			var arm: Array = ARM_NOTABLES.get(br["role"], ARM_NOTABLES[""])
			var pick: Array = arm[arm_i % arm.size()]
			arm_i += 1
			nname = str(pick[0]) + " Maior"
			nst = _build_power(_scaled(pick[1], Balance.WEB_OUTER_ARM_SCALE), br, cls)
			nst[main] = int(nst.get(main, 0)) + Balance.WEB_RIM_NOTABLE_ATTR
		var nn := "%s_n_%s_x" % [cls.id, cid]
		nodes[nn] = _node(nn, "notable", "", nname, "Notável da Orla: %s." % stat_text(nst), lv, 1, c)
		nodes[nn]["stats"] = nst
		nodes[nn]["branch"] = br["id"]
		nodes[nn]["rim"] = true
		_link(nodes, nn, ring[2])
		_link(nodes, nn, ring[3])
		out_clusters.append({"center": c, "r": WHEEL_R, "kind": "notable", "branch": br["id"]})

## A casa encosta na malha (algum canto já é junção)?
static func _touches(hubs: Dictionary, key: Vector2i) -> bool:
	for dx in [0, 1]:
		for dy in [0, 1]:
			if hubs.has(Vector2i(key.x + dx, key.y + dy)):
				return true
	return false

static func _find(parent: Dictionary, x: Vector2i) -> Vector2i:
	while parent[x] != x:
		x = parent[x]
	return x

## Build vizinha (índice do ramo) do lado para onde a casa pende; sem `always`, só perto da divisa do setor (senão -1).
static func _neighbor_build(c: Vector2, bi: int, branches: Array, always: bool) -> int:
	var n_br := branches.size()
	if bi == 0 or n_br < 3:
		return -1
	var w := TAU / float(n_br)
	var a := wrapf(c.angle() + PI * 0.5, 0.0, TAU)
	var off := angle_difference(bi * w, a)                 # quanto a casa sai do meio do setor (radianos, com sinal)
	if not always and absf(off) < w * 0.5 * Balance.WEB_HYBRID_EDGE:
		return -1
	var nb := posmod(bi + (1 if off > 0 else -1), n_br)
	if nb == 0:                                            # do lado do Geral: elo com a build do outro lado
		nb = posmod(bi + (-1 if off > 0 else 1), n_br)
	return nb if nb != 0 else -1

## Bônus x mult (atributo fica).
static func _mult(st: Dictionary, mult: float) -> Dictionary:
	var out := {}
	for k in st:
		out[k] = st[k] if str(k).begins_with("attr_") else (snappedf(float(st[k]) * mult, 0.5) if st[k] is float else roundi(float(st[k]) * mult))
	return out

## Notáveis de base (Balance.CORE_NOTABLES): anel de 5 em volta do Início, cada um ligado só a ele, nível 1, 1 ponto.
## O giro do anel é o que deixa mais folga para os nós que já existem (mesmo resultado sempre: sem sorteio).
## Ids <classe>_core_<i>; marca "core" (bots compram primeiro, ProgressionSystem.bot_spend).
static func _core_ring(cls: ClassDef, nodes: Dictionary, start: String) -> void:
	var list: Array = Balance.CORE_NOTABLES.get(cls.id, [])
	if list.is_empty():
		return
	var others: Array = []
	for nid in nodes:
		if nid != start and nodes[nid]["kind"] != "pick":
			others.append(nodes[nid]["pos"])
	var n := list.size()
	var best_a := 0.0
	var best_gap := -1.0
	for k in range(72):
		var a0 := TAU * k / 72.0 / n
		var gap := INF
		for i in range(n):
			var p := Vector2.from_angle(a0 + TAU * i / n) * Balance.CORE_RING_R
			for o in others:
				gap = minf(gap, p.distance_to(o))
		if gap > best_gap:
			best_gap = gap
			best_a = a0
	for i in range(n):
		var nid := "%s_core_%d" % [cls.id, i]
		var st: Dictionary = list[i][1]
		nodes[nid] = _node(nid, "notable", "", list[i][0], "Notável de base: %s." % stat_text(st), 1, 1,
			Vector2.from_angle(best_a + TAU * i / n) * Balance.CORE_RING_R)
		nodes[nid]["stats"] = st.duplicate()
		nodes[nid]["branch"] = "start"
		nodes[nid]["core"] = true
		_link(nodes, start, nid)

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

## Notáveis de papel (Balance.ROLE_NOTABLES): por grupo, os notáveis da teia do 30 do(s) ramo(s) do grupo mais perto do início
## (fora o notável-assinatura) trocam o bônus pelo da lista; o atributo do círculo fica. Marca "role_note" = survival|damage
## e "role_bots" = builds cujo bot vai buscá-lo. Não mexe em ids, posições nem ligações (só bônus, nome e texto).
static func _role_notables(cls: ClassDef, nodes: Dictionary) -> void:
	var sig_names := {}
	for b in Balance.BUILD_WEB_NOTABLES:
		sig_names[Balance.BUILD_WEB_NOTABLES[b][0]] = true
	for grp in Balance.ROLE_NOTABLES.get(cls.id, []):
		var cands: Array = []
		for nid in nodes:
			var n: Dictionary = nodes[nid]
			if n["kind"] == "notable" and int(n["level"]) <= Balance.WEB_GAIN_LEVEL and _in_branches(str(n.get("branch", "")), grp["branch"]) \
					and not n.has("role_note") and not sig_names.has(n["name"]):
				cands.append(nid)
		cands.sort_custom(func(a, b): return (nodes[a]["pos"] as Vector2).length() < (nodes[b]["pos"] as Vector2).length())
		var list: Array = grp["list"]
		for i in range(mini(list.size(), cands.size())):
			var n: Dictionary = nodes[cands[i]]
			var st := {}
			for k in n["stats"]:
				if str(k).begins_with("attr_"):
					st[k] = n["stats"][k]
			var add: Dictionary = list[i][1]
			for k in add:
				st[k] = add[k]
			n["name"] = list[i][0]
			n["stats"] = st
			n["desc"] = "Notável de %s: %s." % ["sobrevivência" if grp["kind"] == "survival" else "dano", stat_text(st)]
			n["role_note"] = grp["kind"]
			n["role_bots"] = grp["bots"]

## Ramo do nó vale para o grupo de notáveis de papel: "*" = qualquer, Array = um desses, String = só esse.
static func _in_branches(br: String, want: Variant) -> bool:
	if want is Array:
		return br in want
	return str(want) == "*" or br == str(want)

## Bônus de notável escalado (% x NOTABLE_SCALE, arredondado; atributo fica).
static func _scaled(st: Dictionary, k_mult: float = NOTABLE_SCALE) -> Dictionary:
	var out := {}
	for k in st:
		out[k] = st[k] if str(k).begins_with("attr_") else (snappedf(float(st[k]) * k_mult, 0.5) if st[k] is float else maxi(1, roundi(float(st[k]) * k_mult)))
	return out

## Nome/texto dos nós da skill na teia (pt-BR): "<Skill> Aprimorada" e "<Skill> Ágil".
static func up_name(s: SkillDef) -> String:
	return "%s Aprimorada" % s.name

static func up_desc(s: SkillDef) -> String:
	return "%s: +%d%% de %s." % [s.name, roundi(Balance.SKILL_UP_POWER * 100.0), "cura" if s.kind == SkillDef.Kind.HEAL else "poder (dano e efeitos pelo poder)"]

static func quick_name(s: SkillDef) -> String:
	return "%s Ágil" % s.name

static func quick_desc(s: SkillDef) -> String:
	return "%s: -%d%% de recarga e de MP." % [s.name, roundi(Balance.SKILL_QUICK_PCT * 100.0)]

## Efeitos que tiram a skill das cargas: ligar/desligar, forma, invocação, buff de hora certa, preparo de outra skill.
const NO_CHARGE_EFFECTS := ["form", "aura", "summon", "stealth", "arcane", "pet_buff", "pet_command", "falcon_call", "falcon_eyes",
	"elem_command", "elem_fusion", "choir_angel", "choir_barrier", "choir_return", "sacrifice", "cd_reset", "shadow_clone",
	"decoys", "turret", "riposte", "channel", "summon_pact", "orbit", "pack", "rally", "shout", "zone", "trap"]
const CHARGE_CONTROL := ["stun", "root", "slow", "taunt", "pull", "knockback"]

## Skill que ganha o nó "<Skill> em Cargas": dano ou controle (físico/mágico), recarga base >= Balance.SKILL_CHARGE_MIN_CD,
## sem buff longo/aura/forma/invocação, fora Suprema e ascensão. Ex.: `TreeCatalog.charge_ok(GameData.skills["ele_meteor"])`.
static func charge_ok(s: SkillDef) -> bool:
	if s.ultimate or s.ascension or s.cooldown < Balance.SKILL_CHARGE_MIN_CD:
		return false
	if not (s.kind in [SkillDef.Kind.PHYSICAL, SkillDef.Kind.MAGICAL]) or s.target == SkillDef.Target.SELF and s.effects.has("buff"):
		return false
	for k in NO_CHARGE_EFFECTS:
		if s.effects.has(k):
			return false
	if s.power > 0.0:
		return true
	for k in CHARGE_CONTROL:
		if s.effects.has(k):
			return true
	return false

static func charge_name(s: SkillDef) -> String:
	return "%s em Cargas" % s.name

static func charge_desc(s: SkillDef) -> String:
	return "%s: guarda até %d cargas; cada uma volta em %d%% da recarga, uma de cada vez. MP por uso." % [s.name,
		Balance.SKILL_CHARGE_MAX, roundi(Balance.SKILL_CHARGE_RECHARGE_MULT * 100.0)]

## Texto do rank (maestria) da skill: o que cada rank do Mestre de Skills dá.
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
