class_name MapsCatalog
extends RefCounted
## Zonas estilo Erenshor (Blender → data/zones/*.json): Vale de Aldara (cidade murada + Campina 1-10),
## Floresta (10-20) e Ruínas (20-30). Aqui ficam nomes, falas, cores e população; o layout vem do JSON.
## Paleta inspirada em Tree of Savior: pastel quente, pedra creme, verdes suaves.

const C_STONE := Color(0.86, 0.80, 0.68)
const C_ROOF := Color(0.80, 0.42, 0.34)
const C_ROOF2 := Color(0.45, 0.55, 0.72)
const C_WOOD := Color(0.55, 0.40, 0.27)
const C_TREE := Color(0.40, 0.66, 0.38)
const C_TREE_DARK := Color(0.30, 0.52, 0.34)
const C_ROCK := Color(0.62, 0.60, 0.58)
const C_RUIN := Color(0.70, 0.68, 0.62)

static func _mk(d: Dictionary) -> MapDef:
	var m := MapDef.new()
	for k in d:
		m.set(k, d[k])
	return m

static func _ob(kind: String, x: float, z: float, sx: float, sy: float, sz: float, color: Color, rot: float = 0.0, solid: bool = true) -> Dictionary:
	return {"kind": kind, "pos": Vector3(x, 0, z), "size": Vector3(sx, sy, sz), "rot": rot, "color": color, "solid": solid}

static func _house(x: float, z: float, w: float, d: float, rot: float = 0.0, roof: Color = C_ROOF) -> Dictionary:
	var o := _ob("house", x, z, w, 3.2, d, C_STONE, rot)
	o["roof"] = roof
	return o

static func _tree(x: float, z: float, s: float = 1.0, dark: bool = false) -> Dictionary:
	return _ob("tree", x, z, 1.6 * s, 3.5 * s, 1.6 * s, C_TREE_DARK if dark else C_TREE)

static func _rock(x: float, z: float, s: float = 1.0) -> Dictionary:
	return _ob("rock", x, z, 1.4 * s, 0.9 * s, 1.2 * s, C_ROCK)

static func _npc(id: String, name: String, x: float, z: float, role: String, color: Color, dialog: Array, facing: float = 180.0, shop: Array = []) -> Dictionary:
	return {"id": id, "name": name, "pos": Vector3(x, 0, z), "role": role, "color": color, "dialog": dialog, "facing": facing, "shop": shop}

static func _portal(id: String, x: float, z: float, target: String, tx: float, tz: float, label: String) -> Dictionary:
	return {"id": id, "pos": Vector3(x, 0, z), "radius": 1.8, "target_map": target, "target_pos": Vector3(tx, 0, tz), "label": label}

static func _sp(monster: String, x: float, z: float, radius: float, count: int, respawn: float = 14.0) -> Dictionary:
	return {"monster_id": monster, "pos": Vector3(x, 0, z), "radius": radius, "count": count, "respawn": respawn}

static func build() -> Array:
	var out: Array = [_aldara(), _forest(), _ruins(), _elf_city()]
	for did in DUNGEON_DEFS:
		out.append(_dungeon(did))
	var doors := _interior_doors(load_zone("city_aldara"))
	for iid in INTERIORS:
		out.append(_interior(iid, doors))
	for md in out:
		md.gather = gather_rules(md.id)
	return out

## Cristais de retorno (role "crystal", modelo prop_crystal): vincular = G e renascer ali. Posição (x, z) na praça.
const CRYSTALS := {"city_aldara": [-7.5, 0.0], "field_forest": [-5.5, -5.5], "field_ruins": [25.6, 4.6]}
const CRYSTAL_LINES := ["Uma pedra azul que zumbe baixinho. Toque para lembrar deste lugar.", "Os viajantes juram que o cristal os puxa de volta para casa."]

static func crystal_npc(map_id: String) -> Array:
	if not CRYSTALS.has(map_id):
		return []
	var p: Array = CRYSTALS[map_id]
	var d := _npc("crystal_" + map_id, "Cristal de Retorno", float(p[0]), float(p[1]), "crystal", Color(0.45, 0.75, 1.0), CRYSTAL_LINES)
	d["model"] = "prop_crystal"
	return [d]

## Bastião da Aurora (terceiro andar): serviços na praça da catedral; posições do JSON.
const DAWN_NPCS := {
	"dawn_commander": ["Marechal Aldric", "quest", Color(0.4, 0.5, 0.8), ["Três portões, três fortalezas, uma cidade. Seguramos o que dá e retomamos o resto.", "O pântano a oeste é o mais fraco deles. Começamos por lá."]],
	"high_priest": ["Alta Sacerdotisa Lyria", "quest", Color(0.97, 0.92, 0.7), ["A Luz não some. Ela só espera alguém acender de novo.", "Cada fortaleza retomada vira um posto da Aurora. É assim que a noite encolhe."]],
	"dawn_smith": ["Doran, o Ferreiro da Aurora", "smith", Color(0.7, 0.55, 0.4), ["Prata consagrada leva uma peça lendária onde o ferro não chega.", "Do +6 em diante, só um Fragmento da Aurora segura o encanto."]],
	"dawn_merchant": ["Mercador Tobias", "merchant", Color(0.8, 0.7, 0.5), ["Água benta, ataduras e poções. Na guerra, tudo vende."]],
	"dawn_alchemist": ["Irmã Celes", "alchemy", Color(0.6, 0.8, 0.7), ["Bile pútrida queima limpo num caldeirão consagrado. Traga que eu cuido."]],
}
## Guarnição: marcadores `dawn_g_<lado>_<papel>_<n>` do JSON viram NPCs lutadores (guard_<papel>) com o modelo deles,
## renascendo em DAWN_RESPAWN s (a luta é constante). Os do posto avançado só ficam enquanto o front não caiu? Ficam sempre.
const DAWN_ROLE_NAMES := {"knight": ["Sir Gareth", "Sir Edwin", "Dama Rowena", "Sir Alaric", "Dama Isolde", "Sir Cedric"],
	"spearman": ["Lanceiro Tomás", "Lanceira Bia", "Lanceiro Hugo", "Lanceira Nell", "Lanceiro Pim", "Lanceiro Joca", "Lanceira Mar", "Lanceiro Davi", "Lanceira Clô", "Lanceiro Rui", "Lanceira Ada", "Lanceiro Teo"],
	"paladin": ["Paladino Benedito", "Paladina Aurélia"], "priest": ["Irmã Clara", "Irmã Inês", "Irmã Lúcia"],
	"crossbow": ["Besteiro Fábio", "Besteira Lia", "Besteiro Caio", "Besteira Bel", "Besteiro Nico", "Besteira Su", "Besteiro Gil", "Besteira Ana", "Besteiro Leo"]}
const DAWN_ROLE_LINES := {"knight": ["Portão firme. Nenhum osso passa por aqui.", "Escudos à frente quando a trompa soar."],
	"spearman": ["A lança mantém o morto longe. É o que basta.", "Dizem que o Carniçal come os que caem. Não caia."],
	"paladin": ["Que a Luz guarde quem guarda os portões.", "Ferido? Fique perto de mim."], "priest": ["Fique na luz e eu fecho suas feridas.", "Rezo pelos vivos. Os mortos já tiveram a vez deles."],
	"crossbow": ["Do muro eu acerto o que você não alcança.", "Morcegos são os piores. Rápidos e baixos."]}
const DAWN_RESPAWN := 12.0

static func dawn_garrison(npc_pos: Dictionary) -> Array:
	var out: Array = []
	var count := {}
	var seed := 401
	var ids: Array = npc_pos.keys()
	ids.sort()
	for nid in ids:
		if not str(nid).begins_with("dawn_g_"):
			continue
		var parts := str(nid).split("_")
		var role := ""
		for r in DAWN_ROLE_NAMES:
			if parts.has(r):
				role = r
		var mdef: MonsterDef = GameData.monsters.get("guard_" + role)
		if role == "" or mdef == null:
			continue
		var k: int = count.get(role, 0)
		count[role] = k + 1
		var names: Array = DAWN_ROLE_NAMES[role]
		var p: Array = npc_pos[nid]
		var d := _npc(nid, names[k % names.size()], float(p[0]), float(p[1]), "guard", Color(0.85, 0.85, 0.9), DAWN_ROLE_LINES[role], float(p[2]))
		d["fighter"] = "guard_" + role
		d["model"] = mdef.model
		d["respawn"] = DAWN_RESPAWN
		d["look_seed"] = seed
		seed += 13
		if role == "paladin":                 # paladinos rondam o anel da praça
			var a0 := atan2(float(p[1]), float(p[0]))
			d["route"] = [0, 1, 2, 3, 4, 5].map(func(i): return [cos(a0 + i * TAU / 6.0) * 30.0, sin(a0 + i * TAU / 6.0) * 30.0])
		out.append(d)
	return out

static func dawn_services(npc_pos: Dictionary) -> Array:
	var out: Array = []
	for nid in DAWN_NPCS:
		var n: Array = DAWN_NPCS[nid]
		var p: Array = npc_pos.get(nid, [0.0, 0.0, 180.0])
		var d := _npc(nid, n[0], float(p[0]), float(p[1]), n[1], n[2], n[3], float(p[2]),
			MERCHANT_SHOP + GearCatalog.shop_ids() + GearCatalog.starter_weapon_ids(GameData.items) if n[1] == "merchant" else [])
		if n.size() > 4:
			d["model"] = n[4]
		out.append(d)
	return out

## NPCs dos lugares da zona `id` (cabanas e santuários).
static func _place_npcs(id: String, npc_pos: Dictionary) -> Array:
	var out: Array = []
	var table: Dictionary = PLACE_NPCS.get(id, {})
	for nid in table:
		var n: Array = table[nid]
		var p: Array = npc_pos.get(nid, [0.0, 0.0, 180.0])
		var d := _npc(nid, n[0], float(p[0]), float(p[1]), n[1], n[2], n[3], float(p[2]))
		if n.size() > 4:
			d["model"] = n[4]          # pedra/marco que "fala": prop no lugar do boneco
		out.append(d)
	return out

## Moradores que passeiam (VILLAGERS) prontos para o MapDef.
static func villagers(table: Dictionary = VILLAGERS) -> Array:
	var out: Array = []
	var seed := 11 if table == VILLAGERS else 29
	for vid in table:
		var v: Array = table[vid]
		var d := _npc(vid, v[0], float(v[3][0]), float(v[3][1]), "villager", v[1], v[2], float((seed * 47) % 360))
		if v[4] is Array:
			d["route"] = v[4]
		else:
			d["wander"] = float(v[4])
		d["look_seed"] = seed
		if v.size() > 5:                  # modelo próprio (cidadão élfico): sem o kit humano
			d["model"] = v[5]
		seed += 7
		out.append(d)
	return out

# ---------------------------------------------------------------------------
## Casas de Aldara que abrem: porta na frente da casa (a mais perto de `house` no JSON) = portal só do jogador.
## Sala centrada em (0, 0), largura x fundo em `size`; a porta de saída fica no meio da parede da frente (+z, lado da câmera).
## Móveis: [tipo, x, z, largura, altura, fundo, giro°, cor, sólido]. NPCs: id -> [nome, papel, cor, falas, x, z, virado°, passeio m].
const C_FLOOR := Color(0.62, 0.46, 0.32)
const INTERIORS := {
	"in_tavern": {"name": "Taverna do Javali Dourado", "label": "Taverna", "house": [20.5, 14.3], "size": [18.0, 14.0], "floor": Color(0.6, 0.43, 0.3),
		"light": Color(1.0, 0.78, 0.5),
		"furniture": [["counter", 0.0, -4.6, 5.0, 1.1, 0.9, 0.0, C_WOOD, true], ["shelf", -2.6, -6.5, 2.2, 2.2, 0.5, 0.0, Color(0.7, 0.35, 0.3), true],
			["shelf", 2.6, -6.5, 2.2, 2.2, 0.5, 0.0, Color(0.35, 0.5, 0.7), true], ["fireplace", -7.0, -6.3, 2.2, 2.6, 0.9, 0.0, C_STONE, true],
			["barrel", 7.6, -6.2, 0.8, 1.0, 0.8, 0.0, C_WOOD, true], ["barrel", 6.6, -6.3, 0.8, 1.0, 0.8, 0.0, C_WOOD, true], ["barrel", 7.6, -5.2, 0.8, 1.0, 0.8, 0.0, C_WOOD, true],
			["rug", 0.0, 4.2, 4.0, 0.05, 2.4, 0.0, Color(0.7, 0.25, 0.22), false]],
		"tables": [[-5.0, 0.0], [0.0, 0.4], [5.0, 0.0], [-5.0, 3.6], [5.0, 3.6]],
		"npcs": {"tav_barkeep": ["Taberneiro Gus", "villager", Color(0.75, 0.55, 0.35), ["Bem-vindo ao Javali Dourado! Hidromel, cerveja preta ou suco de amora?", "Quem volta vivo da Campina sempre tem uma história. E sede."], 0.0, -5.7, 0.0, 0.0],
			"tav_bard": ["Bardo Lírio", "villager", Color(0.45, 0.7, 0.55), ["♪ O Caranguejo-Rei saiu do lago... e o herói correu pro lado errado! ♪", "Pague uma rodada e eu canto a sua história."], -6.0, -3.6, 30.0, 2.5],
			"tav_patron_a": ["Velho Bento", "villager", Color(0.55, 0.5, 0.45), ["No meu tempo a gente caçava javali de pau e pedra.", "Mais uma, Gus!"], -5.0, 1.2, 180.0, 0.0],
			"tav_patron_b": ["Caçadora Ivy", "villager", Color(0.4, 0.6, 0.4), ["Os lobos das colinas andam em bando agora. Cuidado.", "Ouvi dizer que o Rei Javali odeia fogo."], 5.0, -1.1, 0.0, 0.0]}},
	"in_elder": {"name": "Casa do Ancião", "label": "Casa do Ancião", "house": [-9.9, -9.9], "size": [14.0, 11.0], "floor": Color(0.55, 0.42, 0.34),
		"light": Color(1.0, 0.85, 0.65),
		"furniture": [["shelf", -3.5, -5.0, 2.2, 2.2, 0.5, 0.0, Color(0.45, 0.35, 0.6), true], ["shelf", -1.0, -5.0, 2.2, 2.2, 0.5, 0.0, Color(0.6, 0.3, 0.3), true],
			["fireplace", 4.0, -4.8, 2.2, 2.6, 0.9, 0.0, C_STONE, true], ["bed", -5.4, -1.6, 2.0, 0.8, 1.0, 90.0, Color(0.45, 0.4, 0.65), true],
			["table", 1.5, 0.6, 2.0, 0.85, 1.0, 0.0, C_WOOD, true], ["rug", 1.5, 0.6, 4.0, 0.05, 2.8, 0.0, Color(0.42, 0.36, 0.6), false],
			["crate", 5.8, 1.5, 0.9, 0.9, 0.9, 15.0, C_WOOD, true]],
		"tables": [],
		"npcs": {"eld_scribe": ["Escriba Tomé", "villager", Color(0.6, 0.55, 0.75), ["O Ancião me ditou a história de Aldara inteira. Trezentos anos... e três tinteiros.", "Os mapas antigos falam de uma cripta sob as Ruínas."], 1.5, -0.4, 0.0, 0.0],
			"eld_wife": ["Dona Iolanda", "villager", Color(0.8, 0.6, 0.7), ["O Ravi passa o dia na praça. Eu cuido da casa e dos livros dele.", "Leve um chá para a viagem. Faz bem para o peito."], 3.0, -2.6, 200.0, 2.0]}},
	"in_smithy": {"name": "Oficina do Ferreiro", "label": "Oficina", "house": [-24.0, 6.9], "size": [14.0, 11.0], "floor": Color(0.5, 0.46, 0.42),
		"light": Color(1.0, 0.65, 0.4),
		"furniture": [["fireplace", -4.0, -4.8, 2.6, 2.8, 1.0, 0.0, C_STONE, true], ["anvil", -1.0, -2.0, 1.0, 1.0, 0.6, 0.0, C_ROCK, true],
			["anvil", 2.5, -2.4, 1.0, 1.0, 0.6, 20.0, C_ROCK, true], ["shelf", 3.5, -5.0, 2.2, 2.2, 0.5, 0.0, Color(0.5, 0.5, 0.55), true],
			["barrel", 5.6, -4.6, 0.8, 1.0, 0.8, 0.0, C_WOOD, true], ["crate", 5.8, 0.5, 1.0, 1.0, 1.0, 10.0, C_WOOD, true], ["crate", 5.6, 1.7, 0.9, 0.9, 0.9, -12.0, C_WOOD, true],
			["table", -4.5, 1.2, 2.0, 0.85, 1.0, 90.0, C_WOOD, true]],
		"tables": [],
		"npcs": {"smi_apprentice": ["Aprendiz Duda", "villager", Color(0.75, 0.45, 0.3), ["Mestre Brom atende lá fora; aqui é onde o ferro apanha.", "Um dia vou forjar uma lâmina lendária. Hoje eu varro o chão."], 0.6, -2.0, 270.0, 0.0],
			"smi_miner": ["Mineiro Ruy", "villager", Color(0.55, 0.5, 0.5), ["Trouxe minério das colinas. Os lobos quase me pegaram.", "Pedra boa mesmo só nas Ruínas, mas lá ninguém vai."], -3.2, 2.6, 120.0, 2.5]}},
	"in_apothecary": {"name": "Botica da Alquimista", "label": "Botica", "house": [9.9, 9.9], "size": [14.0, 11.0], "floor": Color(0.5, 0.55, 0.45),
		"light": Color(0.75, 1.0, 0.75),
		"furniture": [["cauldron", 0.0, -2.0, 1.2, 1.0, 1.2, 0.0, Color(0.35, 0.85, 0.45), true], ["shelf", -3.6, -5.0, 2.2, 2.2, 0.5, 0.0, Color(0.4, 0.7, 0.5), true],
			["shelf", -1.2, -5.0, 2.2, 2.2, 0.5, 0.0, Color(0.6, 0.4, 0.7), true], ["shelf", 1.2, -5.0, 2.2, 2.2, 0.5, 0.0, Color(0.85, 0.6, 0.3), true],
			["counter", 4.2, -1.0, 3.0, 1.1, 0.9, 90.0, C_WOOD, true], ["barrel", 5.8, -4.6, 0.8, 1.0, 0.8, 0.0, C_WOOD, true],
			["table", -4.5, 1.2, 2.0, 0.85, 1.0, 0.0, C_WOOD, true], ["rug", 0.0, 2.6, 3.4, 0.05, 2.0, 0.0, Color(0.3, 0.55, 0.4), false]],
		"tables": [],
		"npcs": {"apo_assistant": ["Assistente Mel", "villager", Color(0.55, 0.8, 0.55), ["Não encoste no caldeirão! Da última vez o gato ficou verde.", "Gel de slime azul dá poção de mana. A Lyra jura."], 1.4, -2.2, 250.0, 2.0],
			"apo_patient": ["Lenhador Tico", "villager", Color(0.6, 0.45, 0.3), ["Um javali me pegou de jeito. Estou esperando o unguento.", "Ai, ai... nunca mais corto lenha perto do bosque."], -4.5, 2.4, 180.0, 0.0]}},
	"in_home": {"name": "Casa da Família Sol", "label": "Casa", "house": [-20.5, 14.3], "size": [14.0, 11.0], "floor": Color(0.64, 0.5, 0.36),
		"light": Color(1.0, 0.85, 0.6),
		"furniture": [["bed", -5.2, -3.8, 2.0, 0.8, 1.0, 90.0, Color(0.75, 0.4, 0.35), true], ["bed", -3.4, -3.8, 2.0, 0.8, 1.0, 90.0, Color(0.4, 0.55, 0.75), true],
			["fireplace", 3.5, -4.8, 2.2, 2.6, 0.9, 0.0, C_STONE, true], ["table", 2.0, 0.6, 2.0, 0.85, 1.0, 0.0, C_WOOD, true],
			["shelf", 0.0, -5.0, 2.2, 2.2, 0.5, 0.0, Color(0.8, 0.6, 0.35), true], ["rug", -2.0, 1.4, 3.0, 0.05, 2.0, 0.0, Color(0.85, 0.6, 0.3), false],
			["barrel", 5.8, -4.6, 0.8, 1.0, 0.8, 0.0, C_WOOD, true]],
		"tables": [],
		"npcs": {"home_mother": ["Dona Marta", "villager", Color(0.85, 0.55, 0.45), ["Limpe os pés! Acabei de varrer.", "Meu marido está na fazenda. Se o vir, diga que a sopa esfria."], 2.0, -1.0, 0.0, 3.0],
			"home_kid": ["Nino", "villager", Color(0.95, 0.7, 0.4), ["Você é aventureiro de verdade? Me mostra a espada!", "Quando crescer quero ser Paladino. Ou padeiro."], -2.0, 1.2, 0.0, 3.5]}},
}

## Pontos de colheita (F): item, forma, centro [x, z], raio e quantos. A sim espalha em chão livre (sempre igual por mapa).
const GATHER := {
	"city_aldara": [["herb_green", "herb", [-30.0, 42.0], 14.0, 6], ["herb_green", "herb", [42.0, 46.0], 12.0, 5], ["herb_blue", "herb_blue", [6.7, 88.8], 23.0, 7],
		["iron_ore", "ore", [-6.7, -93.6], 18.0, 6], ["crab_shell", "shell", [6.7, 111.0], 9.0, 4]],
	"field_forest": [["forest_mushroom", "mushroom", [-44.0, 30.0], 18.0, 7], ["forest_mushroom", "mushroom", [74.0, 45.0], 15.0, 4],
		["herb_blue", "herb_blue", [-28.0, -90.0], 14.0, 4], ["stolen_goods", "crate", [50.0, -36.0], 13.0, 6]],
	"field_ruins": [["ancient_relic", "relic", [66.0, 84.0], 16.0, 7], ["ancient_relic", "relic", [20.0, -88.0], 12.0, 3],
		["star_ore", "star", [-57.0, 53.0], 14.0, 5], ["iron_ore", "ore", [-80.0, -42.0], 14.0, 4]],
	# Cidade Élfica: ervas na margem do lago, cogumelos sob o bosque dos trents, pedra-estrela no Altar da Lua
	# e caixotes de Aço Élfico no acampamento da patrulha (guardados pelos guerreiros)
	"elf_city": [["herb_blue", "herb_blue", [-70.0, 30.0], 12.0, 5], ["forest_mushroom", "mushroom", [58.0, -40.0], 14.0, 5],
		["star_ore", "star", [-40.0, -92.0], 12.0, 5], ["elf_steel", "crate", [70.0, 64.0], 10.0, 4]],
}

static func gather_rules(map_id: String) -> Array:
	var out: Array = []
	for g in GATHER.get(map_id, []):
		out.append({"item": g[0], "kind": g[1], "at": Vector3(g[2][0], 0, g[2][1]), "radius": g[3], "count": g[4]})
	return out

## Porta de cada casa que abre: centro da casa no JSON (a mais perto de `house`), direção da frente e ponto da porta.
static func _interior_doors(z: Dictionary) -> Dictionary:
	var out := {}
	for iid in INTERIORS:
		var want := Vector3(INTERIORS[iid]["house"][0], 0, INTERIORS[iid]["house"][1])
		var best: Dictionary = {}
		var bd := 1e9
		for o in z["obstacles"]:
			if o.get("kind", "") != "house":
				continue
			var d: float = (o["pos"] as Vector3).distance_to(want)
			if d < bd:
				bd = d
				best = o
		if best.is_empty():
			continue
		var rot := deg_to_rad(float(best.get("rot", 0.0)))
		var front := Vector3(sin(rot), 0, cos(rot))             # o modelo da casa tem a porta em +z local
		var depth: float = (best["size"] as Vector3).z
		out[iid] = {"door": (best["pos"] as Vector3) + front * (depth * 0.5 + 0.9), "front": front}
	return out

static func _interior(id: String, doors: Dictionary) -> MapDef:
	var d: Dictionary = INTERIORS[id]
	var w: float = d["size"][0]
	var h: float = d["size"][1]
	var obs: Array = []
	# paredes: fundo e lados altos; frente baixa (lado da câmera) com o vão da porta
	var nx := ceili(w / 4.0)
	var nz := ceili(h / 4.0)
	for i in range(nx):
		var x := -w * 0.5 + (i + 0.5) * w / nx
		obs.append(_ob("iwall", x, -h * 0.5 - 0.15, w / nx, 3.0, 0.3, C_STONE))
	var side_len := w * 0.5 - 1.0           # frente: um pedaço de cada lado do vão da porta (2 m)
	for sx in [-1.0, 1.0]:
		obs.append(_ob("iwall", sx * (1.0 + side_len * 0.5), h * 0.5 + 0.15, side_len, 0.9, 0.3, C_STONE))
	for i in range(nz):
		var zz := -h * 0.5 + (i + 0.5) * h / nz
		for sx in [-1.0, 1.0]:
			obs.append(_ob("iwall", sx * (w * 0.5 + 0.15), zz, 0.3, 3.0, h / nz, C_STONE))
	var door := _ob("door", 0.0, h * 0.5 + 0.15, 1.6, 2.3, 0.3, C_WOOD)
	door["solid"] = false
	obs.append(door)
	for f in d["furniture"]:
		var o := _ob(f[0], float(f[1]), float(f[2]), float(f[3]), float(f[4]), float(f[5]), f[7], float(f[6]), bool(f[8]))
		obs.append(o)
	for t in d["tables"]:                   # mesa + 2 banquinhos (taverna cheia)
		obs.append(_ob("table", float(t[0]), float(t[1]), 2.0, 0.85, 1.0, C_WOOD))
		for sx in [-1.0, 1.0]:
			obs.append(_ob("stool", float(t[0]) + sx * 0.0, float(t[1]) + sx * 0.95, 0.5, 0.5, 0.5, C_WOOD, 0.0, false))
	var npcs: Array = []
	for nid in d["npcs"]:
		var n: Array = d["npcs"][nid]
		var nd := _npc(nid, n[0], float(n[4]), float(n[5]), n[1], n[2], n[3], float(n[6]))
		if float(n[7]) > 0.0:
			nd["wander"] = float(n[7])
		nd["look_seed"] = absi(nid.hash()) % 100000
		npcs.append(nd)
	var back: Dictionary = doors.get(id, {"door": Vector3.ZERO, "front": Vector3(0, 0, 1)})
	var out_pos: Vector3 = back["door"] + back["front"] * 1.9
	var exit := _portal("exit_" + id, 0.0, h * 0.5 - 0.45, "city_aldara", out_pos.x, out_pos.z, "Sair")
	exit["radius"] = 0.9
	exit["door"] = true
	return _mk({"id": id, "name": d["name"], "is_town": true, "interior": true, "level_range": Vector2i(1, 30), "parent_map": "city_aldara",
		"size": Vector2(w, h), "ground_color": d["floor"], "ground_color_alt": (d["floor"] as Color).darkened(0.1), "ambient": d["light"],
		"sun_energy": 0.9, "spawn_point": Vector3(0, 0, h * 0.5 - 2.6), "obstacles": obs, "portals": [exit], "npcs": npcs, "bot_population": 0})

## Portas das casas em Aldara (entram no MapDef do vale).
static func _door_portals(doors: Dictionary) -> Array:
	var out: Array = []
	for iid in doors:
		var p: Vector3 = doors[iid]["door"]
		var d: Dictionary = INTERIORS[iid]
		var pt := _portal("door_" + iid, p.x, p.z, iid, 0.0, float(d["size"][1]) * 0.5 - 2.6, d["label"])
		pt["radius"] = 0.8
		pt["player_only"] = true             # bots e moradores passam na frente sem entrar
		pt["door"] = true
		out.append(pt)
	return out

static func _dungeon(id: String) -> MapDef:
	var d: Dictionary = DUNGEON_DEFS[id]
	var z := load_zone(id)
	var npcs := _place_npcs(id, z["npc_pos"])
	z.erase("npc_pos")
	var col: Color = d["ground"]
	z.merge({"id": id, "name": d["name"], "is_town": false, "level_range": d["levels"], "parent_map": d["parent"],
		"ground_color": col, "ground_color_alt": col.darkened(0.08), "ambient": d["ambient"], "sun_energy": d["sun"], "bot_population": 0, "npcs": npcs})
	return _mk(z)

# ---------------------------------------------------------------------------
## Vale de Aldara: zona estilo Erenshor gerada no Blender (tools/blender/zones/build_city_aldara.py).
## O JSON traz colisão, props, spawners, posições de NPC, portais, estradas e água; aqui ficam nomes e falas.
const ALDARA_NPCS := {
	"elder": ["Ancião Ravi", "quest", Color(0.75, 0.65, 0.9), ["Aldara resiste há 300 anos. Com gente como você, resiste mais 300.", "Fale com a Capitã Mira se procura trabalho."]],
	"captain": ["Capitã Mira", "quest", Color(0.85, 0.7, 0.4), ["A guarda está sem braços. Monstros na Campina, bandidos na Floresta...", "WASD para mover, botão esquerdo ataca, direito bloqueia. 1-6 são skills."]],
	"smith": ["Brom, o Ferreiro", "smith", Color(0.8, 0.5, 0.3), ["Anéis e amuletos eu forjo com o que você trouxer. E aprimoro sua arma e armadura: +1 até +9, sem quebrar.", "No +5 a peça começa a brilhar. No +9... você vai ver de longe."]],
	"alchemist": ["Lyra, a Alquimista", "alchemy", Color(0.5, 0.8, 0.6), ["Gel de slime, erva verde... poção de vida. Simples assim.", "Poções vão em F1, F2 e F3. Configure na bolsa (tecla I)."]],
	"merchant": ["Mercador Tobias", "merchant", Color(0.9, 0.8, 0.5), ["Poções, elixires e um bom preço pelo que você trouxe das caçadas."]],
	"relic": ["Iara, a Relicária", "relic", Color(0.95, 0.6, 0.25), ["Moedas lendárias? Eu forjo a peça que você escolher.", "Nível 5 custa 1 moeda, nível 10 custa 2, e assim por diante."]],
	"storage": ["Guarda-volumes Nilo", "storage", Color(0.45, 0.6, 0.75), ["Deixe aqui o que não cabe na bolsa. Fica tudo guardado, até você voltar.", "Cada personagem tem o seu depósito. Ninguém mexe."]],
	"board": ["Quadro de Avisos", "board", Color(0.6, 0.45, 0.3), ["Procura-se: aventureiros para a Campina (1-10), Floresta (10-20) e Ruínas (20-30).", "Dica: maestria sobe gastando pontos na árvore (tecla K)."]],
	"guard_s": ["Guarda", "guard", Color(0.6, 0.6, 0.75), ["O portão sul leva ao lago dos slimes. Monstros fracos, bons para começar."]],
	"guard_e": ["Guarda", "guard", Color(0.6, 0.6, 0.75), ["Estrada leste: bosque dos javalis e, no fim do vale, o desfiladeiro da Floresta (nível 10+)."]],
	"guard_w": ["Guarda", "guard", Color(0.6, 0.6, 0.75), ["Oeste: a ponte do rio, a clareira do Rei Javali e a passagem para as Ruínas (nível 20+)."]],
	"guard_n": ["Guarda", "guard", Color(0.6, 0.6, 0.75), ["Ao norte ficam as colinas dos lobos. O castelo na colina é do conde; ninguém sobe lá."]],
	"meadow_guard": ["Guarda da Estrada", "guard", Color(0.6, 0.6, 0.75), ["Slimes no lago, javalis no bosque a leste, lobos nas colinas ao norte. O Rei Javali fica na clareira a oeste."]],
}
## Moradores de Aldara que passeiam (a cidade não fica parada): nome, cor, falas, casa [x, z] e
## raio de passeio (`wander`) ou ronda por pontos (`route`). Cada um tem um visual sorteado pela semente.
const VILLAGERS := {
	"vil_farmer": ["Lavrador Beto", Color(0.62, 0.5, 0.3), ["O trigo vai bem este ano. Os slimes azuis é que comem as cenouras.", "Se for à fazenda, diga ao Ferdinando que eu mandei lembranças."], [-66.5, 67.0], 5.0],
	"vil_fisher": ["Pescadora Nalu", Color(0.4, 0.6, 0.75), ["Os caranguejos tomaram a praia sul do lago. Dizem que tem um enorme lá no fundo.", "Peixe bom aqui só no píer. O resto é pinça."], [8.5, 68.5], 2.5],
	"vil_kid_a": ["Pipo", Color(0.95, 0.75, 0.35), ["Quando eu crescer vou caçar o Rei Javali!", "Você já viu o castelo da colina por dentro? Eu não."], [-5.0, -4.0], 9.0],
	"vil_kid_b": ["Lia", Color(0.9, 0.5, 0.65), ["Pega-pega! Você tá com ele!", "Minha mãe disse para eu não passar do portão."], [5.0, 3.0], 9.0],
	"vil_couple_a": ["Dona Celeste", Color(0.75, 0.55, 0.8), ["Cinquenta anos de casados e ele ainda me traz flores do lago.", "Que dia bonito na praça."], [0.0, 6.0], 3.0],
	"vil_couple_b": ["Seu Augusto", Color(0.5, 0.45, 0.4), ["As flores do lago? Ah... eu compro do mercador. Não conte a ela.", "No meu tempo os slimes eram menores."], [1.5, 6.5], 3.0],
	"vil_baker": ["Padeira Rosa", Color(0.95, 0.85, 0.6), ["Pão quentinho para quem volta da caça!", "Farinha da fazenda, mel da floresta. Simples e bom."], [11.0, 6.0], 5.0],
	"vil_bard": ["Bardo Fennel", Color(0.55, 0.75, 0.45), ["♪ Lá na Campina o javali corria... ♪", "Toda canção precisa de um herói. Está procurando trabalho?"], [-11.0, 6.0], 6.0],
	"vil_monk": ["Irmão Odo", Color(0.85, 0.8, 0.7), ["Que a luz guie seus passos pela Campina.", "Os mortos das Ruínas não descansam. Reze por eles."], [7.0, -9.0], 5.0],
	"vil_porter": ["Carregador Juca", Color(0.6, 0.45, 0.35), ["Caixas para o mercador, caixas para o ferreiro... minhas costas!", "Se vir o Tobias, diga que a carga atrasou."], [3.0, 13.0], [[3.0, 13.0], [-8.0, 13.0], [-14.0, -12.0], [14.0, -14.0]]],
	"vil_patrol": ["Guarda de Ronda", Color(0.6, 0.6, 0.75), ["Ronda tranquila. Os monstros não passam do muro.", "Mantenha a arma na bainha dentro da vila."], [0.0, -19.0], [[0.0, -19.0], [19.0, 2.0], [2.0, 19.0], [-19.0, -2.0]]],
}
## Cidadãos da Cidade Élfica (neutros: não atacam nem são alvo): [nome, cor da roupa, falas, casa [x,z], passeio m | rota, modelo].
const ELF_CITIZENS := {
	"elf_vendor_a": ["Mercadora Lírien", Color(0.85, 0.6, 0.4), ["Mel de flor-da-lua, fresquinho. Humano paga o dobro.", "O cerco espanta os compradores. Os soldados não."], [35.2, 29.6], 3.0, "mob_elf_citizen_f"],
	"elf_vendor_b": ["Tecelão Faelar", Color(0.55, 0.65, 0.9), ["Seda de aranha tingida com seiva. Brilha no escuro.", "O rei nos mandou tecer capas para o exército. Só capas."], [29.6, 37.8], 3.0, "mob_elf_citizen"],
	"elf_vendor_c": ["Herbanária Nilya", Color(0.5, 0.8, 0.5), ["Folha de prata para febre, raiz-de-sombra para coragem.", "Você não devia estar aqui. Mas compra alguma coisa?"], [37.4, 36.1], 3.0, "mob_elf_citizen_f"],
	"elf_kid_a": ["Pequeno Thaeo", Color(0.95, 0.75, 0.4), ["Um humano! De verdade! Posso tocar na armadura?", "Meu pai é arqueiro no muro. Ele acerta uma folha a cem passos."], [-25.9, 33.1], 7.0, "mob_elf_citizen"],
	"elf_kid_b": ["Pequena Ilsa", Color(0.9, 0.55, 0.75), ["Os grifos do Capitão Aerion comem peixe do lago. Eu dou pra eles!", "Shhh, a guarda tá passando."], [-29.6, 37.8], 7.0, "mob_elf_citizen_f"],
	"elf_gardener": ["Jardineira Saelis", Color(0.6, 0.85, 0.55), ["Cada flor deste jardim foi plantada no dia em que um elfo nasceu.", "O rei mandou cortar as árvores de fora para os fortes. Chorei a semana inteira."], [-43.3, 33.9], 5.0, "mob_elf_citizen_f"],
	"elf_scribe": ["Escriba Orelien", Color(0.75, 0.7, 0.95), ["Registro cada investida contra os humanos. O livro está ficando grosso.", "A Árvore-Mãe tem três mil anéis. Eu contei duzentos."], [-24.4, -8.9], 4.0, "mob_elf_citizen"],
	"elf_priestess": ["Sacerdotisa Myrel", Color(0.92, 0.92, 0.98), ["A seiva escolheu o rei. Ou o rei escolheu a seiva? Já não sei.", "Reze baixo perto da porta do tronco: os guardiões não gostam de barulho."], [20.8, 12.0], 4.0, "mob_elf_citizen_f"],
	"elf_smith": ["Ferreira Thalindra", Color(0.75, 0.5, 0.35), ["Aço élfico se forja frio, com paciência e canção.", "Tudo que eu faço vai para o quartel. Tudo."], [40.5, -29.4], 4.0, "mob_elf_citizen_f"],
	"elf_recruit": ["Recruta Caelan", Color(0.5, 0.7, 0.55), ["Amanhã é meu primeiro turno no muro. Não conta pro sargento que eu tremo.", "Os capitães moram nos fortes lá fora. A Sylvara corre mais que os linces dela."], [43.2, -15.7], 4.0, "mob_elf_citizen"],
	"elf_elder": ["Ancião Vaeril", Color(0.85, 0.85, 0.8), ["No meu tempo, humanos e elfos dividiam a Floresta.", "Aelthar era um bom menino antes da seiva."], [-28.2, 10.3], 3.0, "mob_elf_citizen"],
	"elf_courier": ["Mensageira Aryn", Color(0.55, 0.75, 0.85), ["Recados para os fortes, todo dia, ida e volta.", "Não me atrase, humano."], [40.6, 10.9], [[40.6, 10.9], [21.0, 36.4], [-10.9, 40.6], [-36.4, 21.0], [-40.6, -10.9], [-21.0, -36.4], [10.9, -40.6], [36.4, -21.0]], "mob_elf_citizen_f"],
	"elf_walker_a": ["Bardo Elrion", Color(0.7, 0.55, 0.85), ["♪ A Árvore canta, o rei escuta, os humanos tremem... ♪", "Você daria um bom vilão para a minha canção."], [27.0, 0.0], [[27.0, 0.0], [19.1, 19.1], [0.0, 27.0], [-19.1, 19.1], [-27.0, 0.0], [-19.1, -19.1], [-0.0, -27.0], [19.1, -19.1]], "mob_elf_citizen"],
	"elf_walker_b": ["Patrulheira Lúthia", Color(0.4, 0.6, 0.45), ["Folga hoje. Mesmo assim, não tiro o arco das costas.", "Os sargentos fazem a ronda no anel de fora. Eu só passeio."], [-39.5, -14.4], [[-39.5, -14.4], [-17.7, -38.1], [14.4, -39.5], [38.1, -17.7], [39.5, 14.4], [17.7, 38.1], [-14.4, 39.5], [-38.1, 17.7]], "mob_elf_citizen_f"],
	"elf_baker": ["Padeiro Haldir", Color(0.95, 0.85, 0.6), ["Pão de nozes e mel. Lembas é coisa de outro povo.", "Leva um? É de graça para quem não está brigando."], [13.7, 37.6], 3.0, "mob_elf_citizen"],
	"elf_carpenter": ["Entalhadora Vanya", Color(0.65, 0.5, 0.35), ["As casas crescem das árvores; eu só convenço os galhos.", "Aquela casa ali levou três verões para ficar pronta."], [-38.1, -22.0], 5.0, "mob_elf_citizen_f"],
}
## Moradores do Posto dos Caçadores (refugiados da Floresta sob cerco), mesmo formato de VILLAGERS.
const POST_VILLAGERS := {
	"post_refugee_a": ["Refugiada Dalva", Color(0.7, 0.55, 0.5), ["Morávamos perto da Árvore-Mãe. Os elfos deram um dia para sairmos. Saímos em meio.", "Meu marido ficou para soltar as cabras. Ainda espero ele no portão norte."], [-14.0, 8.0], 4.0],
	"post_refugee_kid": ["Tito", Color(0.95, 0.7, 0.4), ["Eu vi um grifo de perto! Ele era maior que a casa!", "A Caçadora Lis prometeu me ensinar a atirar quando os elfos forem embora."], [-2.0, 10.0], 7.0],
	"post_trapper": ["Armadilheiro Joca", Color(0.55, 0.45, 0.3), ["Armadilha de urso não segura lince élfico. Já tentei. Perdi a armadilha.", "Os bandidos da paliçada pagam bem por pele. Eu não vendo pra bandido. Quase nunca."], [4.0, -4.0], 5.0],
	"post_wounded": ["Batedor Sílvio", Color(0.6, 0.6, 0.7), ["Flecha élfica no ombro. O Boticário diz que eu tive sorte: era das que só prendem.", "Se for ao Ninho, leve fogo. A Rainha odeia fogo. E leve gente."], [-12.0, -2.0], 2.0],
	"post_bard": ["Menestrel Aurélio", Color(0.75, 0.5, 0.75), ["♪ Ó Posto de madeira, que a trompa não derrube... ♪", "Estou compondo a balada do cerco. Falta um herói. E um final feliz."], [-4.0, -8.0], 5.0],
	"post_cook": ["Cozinheira Bia", Color(0.9, 0.75, 0.55), ["Ensopado de cogumelo da floresta! Os escuros não, esses dão sonho estranho.", "Quem segura o portão come primeiro. Regra da casa."], [2.0, 4.0], 3.0],
}

## Posto dos Caçadores (hub da Floresta): serviços e sentinelas. id -> [nome, papel, cor, falas, extras].
## Extras: `fighter` = monstro de onde vêm atributos/alcance (NPC que luta, GuardBrain), `gear` = peças do kit, `route` = ronda.
const FOREST_NPCS := {
	"forest_commander": ["Comandante Hela", "quest", Color(0.75, 0.55, 0.4), ["Os elfos descem pela garganta norte toda semana. Agora, todo dia.", "Segure o portão norte e eu te dou trabalho de verdade."], {}],
	"forest_smith": ["Gunnar, o Armeiro", "smith", Color(0.7, 0.45, 0.3), ["Aço élfico... leve feito pena e duro feito pedra. Com ele eu levo uma peça da Glória mais longe que qualquer minério.", "Do +6 em diante só a seiva da Árvore-Mãe segura o encanto."], {}],
	"forest_merchant": ["Mercadora Ilsa", "merchant", Color(0.85, 0.7, 0.45), ["Flechas, poções e ataduras. Com elfos na porta, o estoque vai rápido."], {"shop": "merchant"}],
	"forest_alchemist": ["Boticário Fen", "alchemy", Color(0.5, 0.75, 0.6), ["Seiva élfica fecha ferida em minutos. Pena que custa uma batalha pra conseguir."], {}],
	"guard_w_0_0": ["Soldado Bram", "guard", Color(0.55, 0.55, 0.65), ["Portão norte. Se ouvir a trompa élfica, corra pra cá."], {"fighter": "guard_warrior", "gear": ["sword_iron", "shield_iron", "helm_iron"]}],
	"guard_w_0_1": ["Soldada Kira", "guard", Color(0.55, 0.55, 0.65), ["Eles são rápidos. Não deixe os arqueiros ficarem atrás de você."], {"fighter": "guard_warrior", "gear": ["sword_iron", "shield_iron", "helm_iron"]}],
	"guard_w_1_0": ["Soldado Otto", "guard", Color(0.55, 0.55, 0.65), ["Portão oeste: a estrada de Aldara. Tranquilo, por enquanto."], {"fighter": "guard_warrior", "gear": ["sword_iron", "shield_iron"]}],
	"guard_w_2_0": ["Soldado Ivo", "guard", Color(0.55, 0.55, 0.65), ["Portão leste. A ponte é nossa; os bandidos que tentem."], {"fighter": "guard_warrior", "gear": ["sword_iron", "shield_iron"],
		"route": [[15.0, 0.0], [3.0, 0.0]]}],
	"guard_w_3_0": ["Soldada Meri", "guard", Color(0.55, 0.55, 0.65), ["Portão sul. Do pântano só vem mosquito e aranha."], {"fighter": "guard_warrior", "gear": ["sword_iron", "shield_iron"],
		"route": [[-5.0, 20.0], [-5.0, 8.0]]}],
	"guard_w_0_2": ["Soldado Davi", "guard", Color(0.55, 0.55, 0.65), ["Quatro no portão norte agora. A Comandante não quer surpresa."], {"fighter": "guard_warrior", "gear": ["sword_iron", "shield_iron", "helm_iron"]}],
	"guard_w_0_3": ["Soldada Yara", "guard", Color(0.55, 0.55, 0.65), ["Mago élfico? Derrube ele e os espíritos somem junto."], {"fighter": "guard_warrior", "gear": ["sword_iron", "shield_iron", "helm_iron"]}],
	"guard_w_1_1": ["Soldado Caio", "guard", Color(0.55, 0.55, 0.65), ["Se o norte cair, eles entram por aqui. Fico de olho."], {"fighter": "guard_warrior", "gear": ["sword_iron", "shield_iron"]}],
	"guard_w_2_1": ["Soldada Tânia", "guard", Color(0.55, 0.55, 0.65), ["Batedor ferido puxa o arco. Não pense que ele desistiu."], {"fighter": "guard_warrior", "gear": ["sword_iron", "shield_iron"]}],
	"guard_w_3_1": ["Soldado Juno", "guard", Color(0.55, 0.55, 0.65), ["O pântano é quieto. Quieto demais."], {"fighter": "guard_warrior", "gear": ["sword_iron", "shield_iron"]}],
	"guard_a_0": ["Caçadora Lis", "guard", Color(0.45, 0.6, 0.4), ["Da torre eu vejo a Árvore-Mãe. E os elfos que saem de baixo dela."], {"fighter": "guard_archer", "gear": ["bow_ent"]}],
	"guard_a_1": ["Caçador Rui", "guard", Color(0.45, 0.6, 0.4), ["Flecha élfica prende o pé no chão. Pule pro lado antes que ela chegue."], {"fighter": "guard_archer", "gear": ["bow_ent"]}],
	"guard_a_2": ["Caçadora Nea", "guard", Color(0.45, 0.6, 0.4), ["Os linces vêm na frente. Derrube eles e o resto perde o faro."], {"fighter": "guard_archer", "gear": ["bow_hunter"]}],
	"guard_a_3": ["Caçador Teodoro", "guard", Color(0.45, 0.6, 0.4), ["Grifo? Mire nas asas. Ou corra. Eu corro."], {"fighter": "guard_archer", "gear": ["bow_hunter"]}],
	"guard_a_4": ["Caçadora Mira", "guard", Color(0.45, 0.6, 0.4), ["O lince salta longe. Quando ele agachar, saia do lugar."], {"fighter": "guard_archer", "gear": ["bow_ent"]}],
	"guard_a_5": ["Caçador Breno", "guard", Color(0.45, 0.6, 0.4), ["Eles miram em quem cura. Protejam o Fen!"], {"fighter": "guard_archer", "gear": ["bow_ent"]}],
	"guard_a_6": ["Caçadora Sol", "guard", Color(0.45, 0.6, 0.4), ["Do muro leste eu cubro a ponte e o portão norte."], {"fighter": "guard_archer", "gear": ["bow_hunter"]}],
	"guard_a_7": ["Caçador Abel", "guard", Color(0.45, 0.6, 0.4), ["Três levas por dia. Minha aljava não aguenta."], {"fighter": "guard_archer", "gear": ["bow_hunter"]}],
}
## Levas aliadas que marcham, por mapa e id do assalto no JSON (WorldState.update_assaults):
##   fighters {guard_id: n}, every (s entre levas), max (vivos ao mesmo tempo), first, say, if/unless (quests).
const ASSAULTS := {}

## Investidas por zona: levas (`every_nth` = só a cada N levas), ritmo e falas. A rota vem do JSON (Blender).
const RAIDS := {
	"field_forest": {"every": 240.0, "first": 75.0, "jitter": 45.0, "lifetime": 210.0,
		"waves": [{"mobs": {"elf_raider": 9, "elf_raider_archer": 6, "elf_lynx": 3, "elf_raider_mage": 3}},
			{"mobs": {"elf_lynx": 3, "elf_raider_archer": 3}, "every_nth": 2}, {"mobs": {"griffin_raider": 3}, "every_nth": 3}],
		"say_start": "Trompas élficas na garganta norte! Uma investida desce rumo ao Posto dos Caçadores!",
		"say_arrived": "Os elfos chegaram ao portão norte do Posto!",
		"say_repelled": "A investida élfica foi repelida. O Posto resiste!",
		"say_retreat": "Os elfos sobreviventes recuam para a garganta.",
		# reforço por passo de força (nível do jogador, ver Balance.RAID_SCALE_*): somado a toda leva a partir do passo
		"scale_extra": {3: {"elf_raider": 3}, 5: {"elf_raider_archer": 3}},
		"say_strong": "As trompas soam mais graves: a investida veio reforçada!"},
	# Bastião da Aurora: três fronts, cada um com a leva do seu lado (a rota é calada pela quest do chefe da fortaleza)
	"field_ruins": {
		"ghoul": {"every": 200.0, "first": 70.0, "jitter": 40.0, "lifetime": 200.0,
			"waves": [{"mobs": {"larva": 8, "rot_zombie": 5, "rot_ghoul": 3}}, {"mobs": {"rot_wolf": 3}, "every_nth": 2}, {"mobs": {"rot_bear": 1}, "every_nth": 3}],
			"say_start": "O pântano do oeste se mexe: a ninhada do Carniçal marcha contra o Bastião!",
			"say_arrived": "Os mortos do Carniçal chegaram ao portão oeste!",
			"say_repelled": "A investida do Carniçal foi queimada no portão oeste!",
			"say_retreat": "A ninhada recua para o pântano."},
		"bones": {"every": 230.0, "first": 140.0, "jitter": 40.0, "lifetime": 210.0,
			"waves": [{"mobs": {"skeleton": 6, "skel_archer": 4, "skel_guard": 2}}, {"mobs": {"skel_guard": 2}, "every_nth": 2}],
			"say_start": "Tambores de osso ao norte: a legião da Fortaleza dos Ossos marcha!",
			"say_arrived": "Os esqueletos chegaram ao portão norte! Escudos à frente!",
			"say_repelled": "A legião dos ossos foi quebrada no portão norte!",
			"say_retreat": "Os esqueletos recuam em fileira para o norte."},
		"frost": {"every": 260.0, "first": 210.0, "jitter": 40.0, "lifetime": 210.0,
			"waves": [{"mobs": {"cultist": 4, "tower_bat": 6, "ghost": 3}}, {"mobs": {"ghost": 2}, "every_nth": 2}],
			"say_start": "Um vento gelado vem do sul: os adeptos da Torre marcham com morcegos e espectros!",
			"say_arrived": "Os adeptos chegaram ao portão sul!",
			"say_repelled": "O frio recua: o portão sul resistiu!",
			"say_retreat": "Os adeptos recuam para a Torre."},
	},
}

## NPCs do Posto dos Caçadores prontos para o MapDef (posições do JSON).
static func forest_npcs(npc_pos: Dictionary) -> Array:
	var out: Array = []
	var seed := 101
	for nid in FOREST_NPCS:
		var n: Array = FOREST_NPCS[nid]
		var p: Array = npc_pos.get(nid, [0.0, 0.0, 180.0])
		var ex: Dictionary = n[4]
		var d := _npc(nid, n[0], float(p[0]), float(p[1]), n[1], n[2], n[3], float(p[2]),
			MERCHANT_SHOP + GearCatalog.shop_ids() + GearCatalog.starter_weapon_ids(GameData.items) if ex.get("shop", "") == "merchant" else [])
		for k in ["fighter", "gear", "route"]:
			if ex.has(k):
				d[k] = ex[k]
		if ex.has("fighter"):
			d["look_seed"] = seed
			seed += 13
		out.append(d)
	return out

## NPCs dos lugares (places.py), por zona: nome, papel, cor, falas. A posição vem do JSON.
const PLACE_NPCS := {
	"city_aldara": {
		"woodcutter_nils": ["Nils, o Lenhador", "quest", Color(0.7, 0.5, 0.35), ["Do outro lado do rio a mata é minha. Pelo menos era, antes dos lobos.", "A cidade fica pra lá da ponte. Daqui só se ouve o machado."]],
		"hermit_ines": ["Eremita Inês", "quest", Color(0.6, 0.75, 0.7), ["Vim pra cá atrás de silêncio. A gruta a nordeste não deixa: ela goteja e borbulha.", "Algo grande mora lá embaixo e não é um slime comum."]],
		"stone_marker": ["Marco de Aldara", "board", Color(0.72, 0.7, 0.66), ["Aqui os fundadores juraram defender o vale. Os nomes estão gastos, a promessa não.", "Dizem que quem descansa neste círculo sonha com o mapa do vale."], "prop_statue"],
	},
	"field_forest": {
		"herbalist_maren": ["Maren, a Herborista", "quest", Color(0.55, 0.75, 0.5), ["Seda de aranha fecha ferida melhor que linha. Pena que vem com a aranha.", "No sudoeste há um buraco na terra. As teias saem de lá."]],
		"hunter_dario": ["Dario, o Caçador", "quest", Color(0.6, 0.55, 0.4), ["Os ents andam. Devagar, mas andam. E o bosque deles cresce.", "Do meu posto vejo a paliçada dos bandidos e não gosto do que vejo."]],
		"stone_druid": ["Círculo Druídico", "board", Color(0.6, 0.75, 0.6), ["Pedras frias, musgo novo. Os druidas se foram; a Árvore-Mãe ainda escuta.", "Gravado: 'Quem corta a raiz perde o caminho'."], "prop_ruin"],
	},
	"elf_city": {
		"siege_scout": ["Batedora Yara", "quest", Color(0.6, 0.5, 0.38), ["O cerco começa aqui. Daqui eu conto cada elfo que sai daquele anel.", "A porta no tronco da Árvore-Mãe desce até o salão do rei. Ninguém voltou de lá ainda."]],
		"elf_deserter": ["Caelir, o Exilado", "quest", Color(0.55, 0.8, 0.65), ["Aelthar não era assim. A seiva da Árvore subiu à cabeça dele.", "Os trents obedecem a quem tem a seiva. Corte a raiz e eles dormem."]],
		"moon_altar": ["Altar da Lua", "board", Color(0.8, 0.85, 0.95), ["Pedra branca, fria como luar. Pedidos de caça presos com fios de prata.", "Gravado em élfico: 'A Árvore não pertence ao rei'."], "prop_statue"],
	},
	"field_ruins": {
		"dawn_board": ["Capela dos Pedidos", "board", Color(0.9, 0.85, 0.7), ["Pedidos da guarnição, pregados com cera da vela do altar.", "'Quem trouxer a cabeça de um morto ganha o pão de um vivo.'"], "prop_statue"],
		"gravedigger_osric": ["Osric, o Coveiro", "quest", Color(0.55, 0.55, 0.65), ["Enterro os mesmos mortos toda semana. Eles é que não colaboram.", "Os espectros vêm do norte. Os esqueletos, de qualquer lugar."]],
		"digger_vera": ["Vera, a Escavadora", "quest", Color(0.75, 0.6, 0.4), ["Vim atrás de ouro e achei uma cripta sob o zigurate.", "O Senhor da Cripta ainda dá ordens. Ouvi."]],
	},
	"dg_pedreira": {
		"miner_tadeu": ["Mestre Tadeu, o Mineiro", "quest", Color(0.7, 0.55, 0.35), ["Abrimos a pedreira atrás de ferro e acordamos a montanha.", "A oeste o musgo anda; a leste o cristal canta. O veio do fundo só abre quando os dois guardiões caírem."]],
		"miner_rosa": ["Rosa, a Cartógrafa", "quest", Color(0.6, 0.7, 0.8), ["Eu mapeio, eles quebram. Não é uma boa parceria.", "Golem de cristal atira de longe. Chegue perto ou procure cobertura."]],
	},
	"dg_catacumbas": {
		"sister_odete": ["Irmã Odete", "quest", Color(0.85, 0.85, 0.95), ["Rezo aqui embaixo porque lá em cima ninguém quis ouvir.", "A oeste marcha a guarda do Conde; a leste chora a viúva dele. O selo ao norte só cede quando os dois caírem."]],
		"gravedigger_bento": ["Bento, o Coveiro", "quest", Color(0.6, 0.55, 0.5), ["Meu avô cavou estas galerias. Meu pai fechou. Alguém abriu.", "Ela chora mais alto de noite. Aqui embaixo é sempre noite."]],
	},
}
## Dungeons (tools/blender/zones/build_dungeons.py): mapas compartilhados pequenos; a entrada fica em `parent`.
const DUNGEON_DEFS := {
	"dg_gruta": {"name": "Gruta Gotejante", "parent": "city_aldara", "levels": Vector2i(6, 10), "ground": Color(0.3, 0.34, 0.36), "ambient": Color(0.6, 0.72, 0.85), "sun": 0.7},
	"dg_catacumbas": {"name": "Catacumbas do Conde", "parent": "city_aldara", "levels": Vector2i(8, 13), "bosses": 2, "ground": Color(0.28, 0.27, 0.3), "ambient": Color(0.62, 0.6, 0.78), "sun": 0.6},
	"dg_catacumbas_trono": {"name": "Trono do Conde", "parent": "dg_catacumbas", "levels": Vector2i(11, 13), "ground": Color(0.26, 0.22, 0.3), "ambient": Color(0.68, 0.5, 0.8), "sun": 0.55},
	"dg_pedreira": {"name": "Pedreira dos Golens", "parent": "field_forest", "levels": Vector2i(11, 15), "bosses": 2, "ground": Color(0.42, 0.36, 0.28), "ambient": Color(0.82, 0.78, 0.72), "sun": 0.7},
	"dg_pedreira_coracao": {"name": "Coração da Pedreira", "parent": "dg_pedreira", "levels": Vector2i(14, 16), "ground": Color(0.4, 0.3, 0.24), "ambient": Color(0.9, 0.7, 0.6), "sun": 0.65},
	"dg_ninho": {"name": "Ninho Profundo", "parent": "field_forest", "levels": Vector2i(15, 20), "ground": Color(0.26, 0.3, 0.24), "ambient": Color(0.6, 0.78, 0.62), "sun": 0.65},
	"dg_coracao": {"name": "Coração da Árvore", "parent": "elf_city", "levels": Vector2i(19, 22), "ground": Color(0.4, 0.34, 0.26), "ambient": Color(0.7, 0.92, 0.7), "sun": 0.65},
	"dg_cripta": {"name": "Cripta de Vel'Thar", "parent": "field_ruins", "levels": Vector2i(25, 30), "ground": Color(0.3, 0.28, 0.32), "ambient": Color(0.66, 0.58, 0.82), "sun": 0.6},
}
## Portões de progressão por id de portal (só o jogador; ver WorldSim.portal_block_reason). `bosses` = selo: save antigo não abre.
const PORTAL_GATES := {
	"to_dg_catacumbas": {"level": 8, "quest": "c1_digging", "text": "Catacumbas: a entrada ainda está soterrada. Fale com o Ancião Ravi."},
	"to_dg_catacumbas_trono": {"bosses": ["bone_captain", "wailing_widow"], "text": "O selo só cede quando o Capitão de Ossos e a Viúva Lamentosa caírem."},
	"to_dg_pedreira_coracao": {"bosses": ["golem_ancient", "crystal_warden"], "text": "O veio está fechado: o Golem Ancestral e a Guardiã de Cristal ainda montam guarda."},
	"to_forest": {"level": 10, "quest": "c5_report", "text": "O desfiladeiro está fechado por ordem da Capitã Mira até resolverem as Catacumbas."},
	"to_ruins": {"level": 20, "quest": "el6_king", "text": "A passagem está vigiada: enquanto o Rei Élfico atacar a Floresta, a guarda não libera as Ruínas."},
	"to_elf_city": {"level": 16, "text": "A garganta élfica: a Comandante Hela só deixa passar quem tem nível 16."},
}
const MERCHANT_SHOP := ["potion_hp_s", "potion_mp_s", "potion_hp_m", "potion_mp_m", "elixir_might", "elixir_stone", "cap_leather", "boots_leather"]
const ZONE_PATH := "res://data/zones/%s.json"

static func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), 0, float(a[1]))

static func _pts(a: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in a:
		out.append(Vector2(float(p[0]), float(p[1])))
	return out

static func _col(a: Variant, fallback: Color) -> Color:
	return Color(float(a[0]), float(a[1]), float(a[2])) if a is Array else fallback

## Lê data/zones/<id>.json (exportado pelo Blender) num dicionário pronto para _mk.
static func load_zone(id: String) -> Dictionary:
	var f := FileAccess.open(ZONE_PATH % id, FileAccess.READ)
	if f == null:
		push_error("zona sem JSON: " + id)
		return {}
	var z: Dictionary = JSON.parse_string(f.get_as_text())
	var obs: Array = []
	for o in z["obstacles"]:
		var kind: String = o["kind"]
		var d := _ob(kind, float(o["pos"][0]), float(o["pos"][1]), float(o["size"][0]), float(o["size"][1]), float(o["size"][2]),
			_col(o.get("color"), C_STONE if kind != "tree" else C_TREE), float(o.get("rot", 0.0)), bool(o.get("solid", true)))
		if o.has("y"):
			d["pos"].y = float(o["y"])          # só visual (árvore no patamar da montanha); a sim usa x/z
		if not bool(o.get("visible", true)):
			d["hidden"] = true                # só colisão: o visual vem do map_<zona>.glb
		if o.has("roof"):
			d["roof"] = _col(o["roof"], C_ROOF)
		obs.append(d)
	if CRYSTALS.has(id):                  # cristal de retorno: coluna sólida invisível (o visual é o prop do NPC)
		var cp: Array = CRYSTALS[id]
		var c := _ob("pillar", float(cp[0]), float(cp[1]), 1.1, 2.6, 1.1, C_STONE, 0.0, true)
		c["hidden"] = true
		obs.append(c)
	var portals: Array = []
	for p in z["portals"]:
		portals.append(_portal(p["id"], float(p["pos"][0]), float(p["pos"][1]), p["target_map"], float(p["target_pos"][0]), float(p["target_pos"][1]), p["label"]))
		if PORTAL_GATES.has(p["id"]):
			portals[-1]["gate"] = PORTAL_GATES[p["id"]]
	var spawners: Array = []
	var dense: float = Balance.SPAWN_COUNT_MULT_DUNGEON if id.begins_with("dg_") else Balance.SPAWN_COUNT_MULT
	for s in z["spawners"]:
		var n := int(s["count"])
		if n > 1:              # chefe único (count 1) continua único
			n = int(round(n * dense))
		spawners.append(_sp(s["monster_id"], float(s["pos"][0]), float(s["pos"][1]), float(s["radius"]), n, float(s["respawn"]) * Balance.SPAWN_RESPAWN_MULT))
		if s.has("emerge"):            # chefe que sai da água: [x, z, raio] do lago
			spawners[-1]["emerge"] = s["emerge"]
		if s.has("route"):             # ronda: o líder (e a escolta dele) percorre estes pontos
			spawners[-1]["route"] = (s["route"] as Array).map(func(q): return _v3(q))
		for k in ["if", "unless"]:     # conquista (WorldState): spawner que só vale antes/depois de uma quest
			if s.has(k):
				spawners[-1][k] = s[k]
	var hangouts: Array = []
	for h in z["hangouts"]:
		hangouts.append(_v3(h))
	var gates: Array = []
	for g in z["town"]["gates"]:
		gates.append(_v3(g))
	var roads: Array = []
	for r in z["roads"]:
		roads.append({"kind": r["kind"], "w": float(r["w"]), "pts": _pts(r["pts"]), "r": float(r.get("r", 0.0))})
	var places: Array = []
	for p in z.get("places", []):
		places.append({"id": p["id"], "type": p["type"], "pos": _v3(p["pos"]), "style": str(p.get("style", ""))})
	var water: Array = []
	for w in z["water"]:
		if w["kind"] == "lake":
			water.append({"kind": "lake", "pos": Vector2(float(w["pos"][0]), float(w["pos"][1])), "r": float(w["r"])})
		else:
			water.append({"kind": w["kind"], "w": float(w["w"]), "pts": _pts(w["pts"])})
	var raid := {}
	if z.has("raid"):                  # investida: rota do JSON (Blender) + levas e falas daqui (RAIDS)
		var r: Dictionary = z["raid"]
		raid = RAIDS.get(id, {}).duplicate(true)
		raid["from"] = _v3(r["from"])
		raid["target"] = _v3(r["target"])
		raid["radius"] = float(r["radius"])
		raid["route"] = (r["route"] as Array).map(func(q): return _v3(q))
	var raids: Array = []
	for r in z.get("raids", []):       # cidade atacada por vários lados: uma rota por lado, levas em RAIDS[<mapa>][<lado>]
		var d: Dictionary = (RAIDS.get(id, {}) as Dictionary).get(str(r["side"]), {}).duplicate(true)
		d["side"] = str(r["side"])
		d["from"] = _v3(r["from"])
		d["target"] = _v3(r["target"])
		d["radius"] = float(r["radius"])
		d["route"] = (r["route"] as Array).map(func(q): return _v3(q))
		for k in ["if", "unless"]:
			if r.has(k):
				d[k] = r[k]
		if raid.is_empty():
			raid = d
		else:
			raids.append(d)
	var assaults: Array = []
	for a in z.get("assaults", []):    # levas aliadas que marcham (WorldState): rota do JSON + tropa e ritmo de ASSAULTS
		var d: Dictionary = (ASSAULTS.get(id, {}) as Dictionary).get(str(a["id"]), {}).duplicate(true)
		d["id"] = str(a["id"])
		d["from"] = _v3(a["from"])
		d["target"] = _v3(a["target"])
		d["radius"] = float(a.get("radius", 10.0))
		d["route"] = (a["route"] as Array).map(func(q): return _v3(q))
		assaults.append(d)
	return {"size": Vector2(float(z["size"][0]), float(z["size"][1])), "spawn_point": _v3(z["spawn"]), "obstacles": obs, "raid": raid,
		"raids": raids, "assaults": assaults,
		"portals": portals, "spawners": spawners, "bot_hangouts": hangouts, "npc_pos": z["npcs"],
		"town_center": _v3(z["town"]["center"]), "town_radius": float(z["town"]["radius"]), "town_gates": gates,
		"roads": roads, "water": water, "model": "map_" + id, "places": places}

static func _aldara() -> MapDef:
	var z := load_zone("city_aldara")
	var npcs: Array = []
	var npc_pos: Dictionary = z.get("npc_pos", {})
	for nid in ALDARA_NPCS:
		var n: Array = ALDARA_NPCS[nid]
		var p: Array = npc_pos.get(nid, [0.0, 0.0, 180.0])
		npcs.append(_npc(nid, n[0], float(p[0]), float(p[1]), n[1], n[2], n[3], float(p[2]), MERCHANT_SHOP + GearCatalog.shop_ids() + GearCatalog.starter_weapon_ids(GameData.items) if nid == "merchant" else []))
	npcs.append_array(_place_npcs("city_aldara", npc_pos))
	npcs.append_array(crystal_npc("city_aldara"))
	npcs.append_array(villagers())
	z["portals"] = (z["portals"] as Array) + _door_portals(_interior_doors(z))
	z.erase("npc_pos")
	z.merge({
		"id": "city_aldara", "name": "Vale de Aldara", "is_town": true, "level_range": Vector2i(1, 10),
		"ground_color": Color(0.48, 0.68, 0.38), "ground_color_alt": Color(0.44, 0.63, 0.35), "ambient": Color(0.97, 0.94, 0.86), "sun_energy": 1.28,
		"bot_population": 22, "npcs": npcs,
	})
	return _mk(z)

# ---------------------------------------------------------------------------
## Floresta Sombria: tools/blender/zones/build_field_forest.py (Posto dos Caçadores murado no hub, sob cerco élfico).
static func _forest() -> MapDef:
	var z := load_zone("field_forest")
	var p: Array = z["npc_pos"].get("ranger_post", [0.0, 0.0, 180.0])
	var extra := _place_npcs("field_forest", z["npc_pos"]) + forest_npcs(z["npc_pos"]) + villagers(POST_VILLAGERS) + crystal_npc("field_forest")
	z.erase("npc_pos")
	z.merge({
		"id": "field_forest", "name": "Floresta Sombria", "is_town": false, "hub": true, "level_range": Vector2i(10, 20),
		"ground_color": Color(0.36, 0.52, 0.34), "ground_color_alt": Color(0.32, 0.48, 0.31), "ambient": Color(0.75, 0.85, 0.8), "sun_energy": 0.95,
		"bot_population": 6,
		"npcs": [_npc("ranger_post", "Ranger Teo", float(p[0]), float(p[1]), "quest", Color(0.5, 0.75, 0.55),
			["Ninhos de aranha a noroeste e no sudoeste, perto do pântano. Os bandidos se fecharam na paliçada a nordeste; ents no bosque a sudeste.",
			"A Árvore-Mãe ao norte se vê de qualquer lugar. Atrás dela, a garganta dos elfos: é de lá que vêm as investidas.", "Não lute com o Chefe sozinho abaixo do nível 17."], float(p[2]))] + extra,
	})
	return _mk(z)

# ---------------------------------------------------------------------------
## Cidade Élfica: tools/blender/zones/build_elf_city.py (anel élfico em volta da Árvore-Mãe Ancestral; cerco humano na entrada sul).
static func _elf_city() -> MapDef:
	var z := load_zone("elf_city")
	var extra := _place_npcs("elf_city", z["npc_pos"]) + villagers(ELF_CITIZENS)
	z.erase("npc_pos")
	z.merge({
		"id": "elf_city", "name": "Cidade Élfica", "is_town": false, "level_range": Vector2i(17, 21),
		"ground_color": Color(0.42, 0.6, 0.44), "ground_color_alt": Color(0.38, 0.56, 0.41), "ambient": Color(0.82, 0.95, 0.86), "sun_energy": 1.05,
		"bot_population": 5, "npcs": extra,
	})
	return _mk(z)

# ---------------------------------------------------------------------------
## Ruínas de Vel'Thar: tools/blender/zones/build_field_ruins.py (praça antiga da erudita no hub).
static func _ruins() -> MapDef:
	var z := load_zone("field_ruins")
	var p: Array = z["npc_pos"].get("ruins_scholar", [0.0, 0.0, 180.0])
	var extra := _place_npcs("field_ruins", z["npc_pos"]) + dawn_services(z["npc_pos"]) + dawn_garrison(z["npc_pos"]) + crystal_npc("field_ruins")
	z.erase("npc_pos")
	z.merge({
		"id": "field_ruins", "name": "Bastião da Aurora", "is_town": false, "hub": true, "level_range": Vector2i(20, 30),
		"ground_color": Color(0.55, 0.56, 0.46), "ground_color_alt": Color(0.5, 0.52, 0.43), "ambient": Color(0.78, 0.78, 0.86), "sun_energy": 0.9,
		"bot_population": 6,
		"npcs": [_npc("ruins_scholar", "Erudita Senna", float(p[0]), float(p[1]), "quest", Color(0.8, 0.75, 0.9),
			["Estudo os mortos para a Alta Sacerdotisa. Cada fortaleza tem um senhor, e cada senhor um ponto fraco.",
			"A cripta ao norte é mais velha que a cidade. O Senhor dela ainda dá ordens lá embaixo."], float(p[2]))] + extra,
	})
	return _mk(z)
