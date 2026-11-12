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
	CatalogUtil.fill(m, d)
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
	var out: Array = [_aldara(), _forest(), _ruins(), _elf_city(), _port(), _coast(), _steppe()]
	for fid in FORT_DEFS:
		out.append(_fort(fid))
	for did in DUNGEON_DEFS:
		out.append(_dungeon(did))
	var doors := {}
	for host in interior_hosts():
		doors.merge(_interior_doors(load_zone(host), host))
	for iid in INTERIORS:
		out.append(_interior(iid, doors))
	for md in out:
		md.gather = gather_rules(md.id)
		_apply_barks(md.npcs)
	return out

## Cristais de retorno (role "crystal", modelo prop_crystal): vincular = G e renascer ali. Posição (x, z) na praça.
const CRYSTALS := {"city_aldara": [-7.5, 0.0], "field_forest": [-5.5, -5.5], "field_ruins": [25.6, 4.6], "city_port": [6.5, 13.0], "field_steppe": [-6.9, 4.0]}
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
	"high_priest": ["Alta Sacerdotisa Lyria", "quest", Color(0.97, 0.92, 0.7), ["A Luz não some. Ela só espera alguém acender de novo. Se quiser recomeçar seu caminho, eu desfaço o que aprendeu.", "Cada fortaleza retomada vira um posto da Aurora. É assim que a noite encolhe."]],
	"dawn_smith": ["Doran, o Ferreiro da Aurora", "smith", Color(0.7, 0.55, 0.4), ["Prata consagrada leva uma peça lendária onde o ferro não chega.", "Do +6 em diante, só um Fragmento da Aurora segura o encanto."]],
	"dawn_merchant": ["Mercador Tobias", "merchant", Color(0.8, 0.7, 0.5), ["Água benta, ataduras e poções. Na guerra, tudo vende."]],
	"dawn_relic": ["Irmão Anselmo, o Relicário", "relic", Color(0.95, 0.7, 0.3), ["Moedas lendárias viram armas e armaduras de lenda. Escolha a peça.", "Também troco ouro por moedas, se a guerra apertar."]],
	"dawn_storage": ["Guarda-volumes Berta", "storage", Color(0.5, 0.6, 0.75), ["O cofre da catedral guarda o que não cabe na bolsa.", "É o mesmo depósito de Aldara: o que deixar lá aparece aqui."]],
	"dawn_alchemist": ["Irmã Celes", "alchemy", Color(0.6, 0.8, 0.7), ["Bile pútrida queima limpo num caldeirão consagrado. Traga que eu cuido."]],
}
## Fronts que se limpam com a conquista: peças do map_field_ruins.glb pelo nome (`tag`), mostradas com `if`/`unless`.
const DAWN_CONQUEST_VIS := [
	{"tag": "chao_front_ghoul", "unless": "dw_ghoul_boss"}, {"tag": "ninho_putrido", "unless": "dw_ghoul_boss"}, {"tag": "limpo_ghoul", "if": "dw_ghoul_boss"},
	{"tag": "chao_front_bones", "unless": "dw_bones_boss"}, {"tag": "limpo_bones", "if": "dw_bones_boss"},
	{"tag": "chao_front_frost", "unless": "dw_frost_boss"}, {"tag": "limpo_frost", "if": "dw_frost_boss"},
]

## Guarnição: marcadores `dawn_g_<lado>_<papel>_<n>` do JSON viram NPCs lutadores (guard_<papel>) com o modelo deles,
## renascendo em DAWN_RESPAWN s (a luta é constante). Os do posto avançado só ficam enquanto o front não caiu? Ficam sempre.
const DAWN_ROLE_NAMES := {"wall": ["Besteiro da Torre"], "knight": ["Sir Gareth", "Sir Edwin", "Dama Rowena", "Sir Alaric", "Dama Isolde", "Sir Cedric"],
	"spearman": ["Lanceiro Tomás", "Lanceira Bia", "Lanceiro Hugo", "Lanceira Nell", "Lanceiro Pim", "Lanceiro Joca", "Lanceira Mar", "Lanceiro Davi", "Lanceira Clô", "Lanceiro Rui", "Lanceira Ada", "Lanceiro Teo"],
	"paladin": ["Paladino Benedito", "Paladina Aurélia"], "priest": ["Irmã Clara", "Irmã Inês", "Irmã Lúcia"],
	"crossbow": ["Besteiro Fábio", "Besteira Lia", "Besteiro Caio", "Besteira Bel", "Besteiro Nico", "Besteira Su", "Besteiro Gil", "Besteira Ana", "Besteiro Leo"]}
const DAWN_ROLE_LINES := {"wall": ["Daqui de cima eu vejo todos chegando.", "Um virote não mata, mas atrasa."], "knight": ["Portão firme. Nenhum osso passa por aqui.", "Escudos à frente quando a trompa soar."],
	"spearman": ["A lança mantém o morto longe. É o que basta.", "Dizem que o Carniçal come os que caem. Não caia."],
	"paladin": ["Que a Luz guarde quem guarda os portões.", "Ferido? Fique perto de mim."], "priest": ["Fique na luz e eu fecho suas feridas.", "Rezo pelos vivos. Os mortos já tiveram a vez deles."],
	"crossbow": ["Do muro eu acerto o que você não alcança.", "Morcegos são os piores. Rápidos e baixos."]}
const DAWN_RESPAWN := 12.0

## Festa da vitória (fim do Ato I): quem só aparece depois que o Lich cai (`if` = quest do Lich; WorldState faz nascer).
## mapa -> id -> [nome, papel, cor, falas, x, z, passeio m].
const VICTORY_QUEST := "dw_lich"
const ACT_END_QUEST := "dw_epilogue"      # entregar ao Ancião Ravi = fim do Ato I (tela de encerramento do HUD)
const FESTIVAL := {
	"city_aldara": {
		"fest_bard": ["Bardo Fennel, o Moço", "villager", Color(0.55, 0.8, 0.45), ["♪ E o Lich caiu, caiu, caiu... e Aldara cantou! ♪", "Estou compondo a sua canção. Rima com \"Azhar\"? Só \"jantar\"."], -7.0, -2.0, 3.0],
		"fest_dancer_a": ["Dançarina Mel", "villager", Color(0.95, 0.55, 0.6), ["Dança comigo! Hoje ninguém fica parado na praça!", "Três dias de festa, foi o que o Ancião prometeu."], 7.0, -2.0, 4.0],
		"fest_dancer_b": ["Tico Saltitante", "villager", Color(0.95, 0.8, 0.35), ["A noite acabou! A NOITE ACABOU!", "Eu sempre soube que você ia voltar."], -3.0, 8.0, 4.0],
		"fest_brewer": ["Mestre Cervejeiro Duda", "villager", Color(0.7, 0.5, 0.3), ["Cerveja por conta da casa para o herói da Aurora!", "Barril novo, aberto em sua honra."], 3.0, 8.0, 2.0],
	},
	"field_ruins": {
		"fest_soldier_a": ["Soldado Bruno", "guard", Color(0.85, 0.85, 0.9), ["Vencemos! Vou dormir uma semana inteira.", "Nenhum osso se mexe mais na garganta."], 10.0, 6.0, 3.0],
		"fest_soldier_b": ["Arqueira Tainá", "guard", Color(0.8, 0.9, 0.8), ["Os fogos são ideia do Comandante. Bonitos, não?", "Guardei a última flecha. De lembrança."], 10.0, -6.0, 3.0],
		"fest_cleric": ["Irmã Alba", "villager", Color(0.95, 0.9, 0.75), ["Que a luz da Aurora fique com você, sempre.", "Rezamos pelos que não voltaram da Cidadela."], 6.0, 15.0, 2.0],
	},
}

static func festival(map_id: String) -> Array:
	var out: Array = []
	var t: Dictionary = FESTIVAL.get(map_id, {})
	for nid in t:
		var v: Array = t[nid]
		var d := _npc(nid, v[0], float(v[4]), float(v[5]), v[1], v[2], v[3], 180.0)
		d["wander"] = float(v[6])
		d["if"] = VICTORY_QUEST
		out.append(d)
	return out

static func dawn_garrison(npc_pos: Dictionary, prefix: String = "dawn_g_") -> Array:
	var out: Array = []
	var count := {}
	var seed := 401
	var ids: Array = npc_pos.keys()
	ids.sort()
	for nid in ids:
		if not str(nid).begins_with(prefix):
			continue
		var parts := str(nid).split("_")
		var role := ""
		for r in DAWN_ROLE_NAMES:
			if parts.has(r):
				role = r
		var mdef: MonsterDef = GameData.monsters.get("guard_wall_crossbow" if role == "wall" else "guard_" + role)
		if role == "" or mdef == null:
			continue
		var k: int = count.get(role, 0)
		count[role] = k + 1
		var names: Array = DAWN_ROLE_NAMES[role]
		var p: Array = npc_pos[nid]
		var d := _npc(nid, names[k % names.size()], float(p[0]), float(p[1]), "guard", Color(0.85, 0.85, 0.9), DAWN_ROLE_LINES[role], float(p[2]))
		d["fighter"] = "guard_wall_crossbow" if role == "wall" else "guard_" + role
		if role == "wall":
			d["perch"] = 8.4                    # no alto da torre (visual); a sim fica no chão
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

## Fortalezas dos mortos-vivos e a Cidadela (tools/blender/zones/build_dawn_forts.py): cada uma tem a quest do chefe
## (`quest`) que a retoma: mortos somem, nasce o assentamento (NPCs `settler`, guarnição `g`) e o assalto da seguinte sobe.
const FORT_DEFS := {
	"fort_ghoul": {"name": "Covil do Carniçal", "levels": Vector2i(20, 23), "quest": "dw_ghoul_boss", "posts": "dw_ghoul_posts",
		"ground": Color(0.4, 0.38, 0.24), "ambient": Color(0.72, 0.78, 0.62), "sun": 0.75},
	"fort_bones": {"name": "Fortaleza dos Ossos", "levels": Vector2i(23, 26), "quest": "dw_bones_boss", "posts": "dw_bones_posts",
		"ground": Color(0.56, 0.54, 0.5), "ambient": Color(0.72, 0.72, 0.8), "sun": 0.75},
	"fort_frost": {"name": "Torre do Mago Gélido", "levels": Vector2i(26, 29), "quest": "dw_frost_boss", "posts": "dw_frost_posts",
		"ground": Color(0.74, 0.82, 0.9), "ambient": Color(0.75, 0.85, 1.0), "sun": 0.85},
	"lich_citadel": {"name": "Cidadela do Lich", "levels": Vector2i(29, 30), "quest": "dw_lich", "posts": "dw_lich",
		"ground": Color(0.32, 0.28, 0.36), "ambient": Color(0.62, 0.55, 0.78), "sun": 0.6},
	# Ato II, Estepes de Cinza (tools/blender/zones/build_steppe_forts.py): acampamentos de guerra da Horda, em qualquer ordem.
	# Sem missão de postos: os postos avançados viram guarda aliada junto com o acampamento. `horde` = estandartes do GLB trocam.
	"fort_trolls": {"name": "Toca do Rei-da-Rocha", "levels": Vector2i(35, 38), "quest": Q_FORT_TROLLS, "posts": Q_FORT_TROLLS, "boss": "boss_troll_king",
		"ground": Color(0.6, 0.55, 0.46), "ambient": Color(0.95, 0.9, 0.82), "sun": 1.1, "horde": true},
	"fort_fire": {"name": "Paliçada das Flechas de Fogo", "levels": Vector2i(36, 39), "quest": Q_FORT_FIRE, "posts": Q_FORT_FIRE, "boss": "boss_crossbow_master",
		"ground": Color(0.44, 0.39, 0.34), "ambient": Color(0.98, 0.86, 0.76), "sun": 1.05, "horde": true},
	"fort_war": {"name": "Arraial de Ghar", "levels": Vector2i(37, 40), "quest": Q_FORT_WAR, "posts": Q_FORT_WAR, "boss": "boss_ghar",
		"ground": Color(0.66, 0.52, 0.36), "ambient": Color(0.98, 0.9, 0.8), "sun": 1.15, "horde": true},
}
## Missões que retomam os acampamentos das Estepes (estágios E1-E3 do GDD do Ato II; E4 = escolha dos Desertores).
const Q_FORT_TROLLS := "hx_fort_trolls"
const Q_FORT_FIRE := "hx_fort_fire"
const Q_FORT_WAR := "hx_fort_war"
const Q_STEPPE_FORTS := [Q_FORT_TROLLS, Q_FORT_FIRE, Q_FORT_WAR]      # os três = E5 (caminho da montanha)
const Q_DESERTERS_HELP := "hx_deserters_help"
const Q_DESERTERS_TURN := "hx_deserters_turn"

## Estandartes do acampamento: vermelho da Horda antes, branco-dourado da Aurora depois. A regra mais específica vem
## por último (o nome "tenda_ghar_aurora" também contém "tenda_ghar"; vale a última que casar).
static func horde_fort_vis(quest: String, command_tent: bool) -> Array:
	var out: Array = [{"tag": "estandarte_horda", "unless": quest}, {"tag": "estandarte_aurora", "if": quest}]
	if command_tent:                     # Arraial de Ghar: a tenda de comando também troca de dono
		out.append_array([{"tag": "tenda_ghar", "unless": quest}, {"tag": "tenda_ghar_aurora", "if": quest}])
	return out
## Por fortaleza: [prisioneiros (somem na retomada)], [assentamento (aparece na retomada)]: nome, papel, cor, falas.
const FORT_NPCS := {
	"fort_ghoul": {
		"prisoner": [["Soldado Breno", ["Eles comem os que caem. Eu fingi estar morto três dias.", "O Gigante dorme no monte de carne, no fundo do pátio."]],
			["Irmã Vânia", ["A Luz ainda me ouve, mesmo aqui.", "As larvas saem da barriga dele. Mate as pequenas antes."]],
			["Caçador Ezequiel", ["Os lobos podres correm mais que você. Não fuja deles em campo aberto."]]],
		"settler": [["Capitã Rena", "quest", ["O Covil é nosso. Daqui a Aurora marcha para o norte, contra a Fortaleza dos Ossos.", "Meus soldados sobem a estrada a cada pouco. Vá com eles."]],
			["Ferreiro de Campo Otto", "smith", ["Ferro bento conserta o que a bile corroeu."]],
			["Mercadora Lúcia", "merchant", ["Trouxe o que deu da cidade. Na linha de frente, tudo acaba rápido."]]],
	},
	"fort_bones": {
		"prisoner": [["Sir Malcom", ["Jurei à Aurora antes de Vorhag jurar à noite. Fomos irmãos.", "O escudo deles não para golpe pelas costas."]],
			["Escriba Tereza", ["Ele comanda pelo medo. Sem ele, os ossos se desmancham."]],
			["Arqueiro Davi", ["Os arqueiros de osso miram em quem está parado. Mexa-se."]]],
		"settler": [["Comandante Viana", "quest", ["A Fortaleza dos Ossos caiu. Resta a Torre ao sul, e depois o próprio Lich.", "Os adeptos usam gelo e morcegos. Fogo e luz funcionam."]],
			["Armeira Glória", "smith", ["Osso negro derretido dá um aço que não enferruja. Quer ver?"]],
			["Mercador Pietro", "merchant", ["Ataduras, poções e água benta. Na Torre vai precisar."]]],
	},
	"fort_frost": {
		"prisoner": [["Mago Aurélio", ["Morvath foi meu mestre. Ele congelou o próprio coração para não sentir.", "A nevasca dele cobre o chão: saia do círculo azul."]],
			["Irmã Lis", ["Os espectros somem quando ele cai. Não perca tempo com eles."]],
			["Guarda Nuno", ["Não fique perto da torre quando o gelo começar a cantar."]]],
		"settler": [["Paladina Sofia", "quest", ["A Torre é nossa. Agora a Cidadela: o Lich-Rei espera no trono, atrás de três portões.", "Leve um grupo. A Aurora inteira vai com você."]],
			["Ferreira Inês", "smith", ["O frio da Torre tempera bem uma lâmina. Que ironia."]],
			["Mercador Aldo", "merchant", ["Poções quentes, cobertores e flechas. O de sempre."]]],
	},
	"lich_citadel": {
		"prisoner": [["Alma Presa", ["Ele guarda as almas da cidade antiga no trono. Liberte-nos."]], ["Cavaleiro Esquecido", ["Três portões. Cada um com a guarda de uma fortaleza."]],
			["Velha Sacerdotisa", ["A noite tem um coração. Está no peito dele."]]],
		"settler": [["Arauto da Aurora", "quest", ["A Cidadela caiu. A noite recua, mas não morre. Volte quando quiser caçar o que sobrou."]],
			["Ferreiro Real Bento", "smith", ["Fragmentos da Aurora: só aqui eu consigo trabalhar o +9."]],
			["Intendente Clara", "merchant", ["A guerra acabou para uns. Para nós, a cidade começa agora."]]],
	},
	# Estepes de Cinza: os presos são colonos da caravana; retomado, o acampamento vira posto aliado com ferreiro de campo
	"fort_trolls": {
		"prisoner": [["Carroceiro Elói", ["Eles não nos comeram ainda porque o Rei-da-Rocha gosta de guardar para depois.", "Troll machucado se fecha sozinho. Fogo e veneno seguram a ferida aberta."]],
			["Colona Marta", ["A ponte da fenda é o único caminho. Eles sabem disso melhor que nós."]],
			["Batedora Íris", ["O grandão dorme na boca da caverna. Os pequenos jogam pedra de longe."]]],
		"settler": [["Capataz Elói", "quest", ["A Toca é nossa. A pedra daqui vai virar muro no Posto da Caravana.", "Os trolls que sobraram foram para o Cemitério dos Mamutes. Lá eles sempre voltam."]],
			["Ferreira de Campo Dalva", "smith", ["Pedra de troll amola qualquer lâmina. Só não pergunte de onde tirei."]],
			["Mercadora Marta", "merchant", ["Da jaula para o balcão. Kharzun tem dessas."]]],
	},
	"fort_fire": {
		"prisoner": [["Arqueiro Simão", ["Eles acendem a flecha no braseiro antes de puxar. Círculo vermelho no chão: saia. Sempre saia."]],
			["Colono Bento", ["Queimaram três carroças só para treinar a mira."]],
			["Irmã Glória", ["O Mestre Besteiro não erra parado. Não deixe ele ficar parado."]]],
		"settler": [["Sargento Simão", "quest", ["A Paliçada caiu. Daqui as nossas flechas cobrem a estrada do sudeste.", "Sem as torres deles, a caravana volta a andar de dia."]],
			["Ferreiro de Campo Juca", "smith", ["Ponta de flecha, fivela, ferradura. Carvão é o que não falta aqui."]],
			["Mercador Bento", "merchant", ["O que não queimou, eu vendo."]]],
	},
	"fort_war": {
		"prisoner": [["Sir Otávio", ["Ghar luta na arena com quem ele respeita. Não é um elogio que eu queira de novo.", "Quando ele grita, o bando inteiro bate mais forte."]],
			["Colona Rute", ["Os Agitadores ficam atrás, batendo tambor. Sem eles a tropa murcha."]],
			["Escudeiro Téo", ["A tenda vermelha no fundo é a dele. Ninguém entra sem ser chamado."]]],
		"settler": [["Capitão Otávio", "quest", ["O Arraial é da Aurora. Com os três acampamentos nas nossas mãos, o passo da montanha fica sem guarda.", "A Horda recuou para Kharzun. Ela não foge: ela junta força."]],
			["Ferreira de Campo Zélia", "smith", ["Aço de orc é pesado e honesto. Dá para trabalhar."]],
			["Mercadora Rute", "merchant", ["Tambor de guerra dá um bom barril, sabia?"]]],
	},
}
const FORT_RESPAWN := 12.0

static func fort_npcs(fid: String, npc_pos: Dictionary) -> Array:
	var fd: Dictionary = FORT_DEFS[fid]
	var tab: Dictionary = FORT_NPCS[fid]
	var out: Array = []
	for k in range(tab["prisoner"].size()):
		var nid := "%s_prisoner_%d" % [fid, k]
		var p: Array = npc_pos.get(nid, [0.0, 0.0, 180.0])
		var d := _npc(nid, tab["prisoner"][k][0], float(p[0]), float(p[1]), "villager", Color(0.6, 0.55, 0.5), tab["prisoner"][k][1], float(p[2]))
		d["unless"] = fd["quest"]
		d["look_seed"] = 700 + k * 17 + fid.length()
		out.append(d)
	for k in range(tab["settler"].size()):
		var nid := "%s_settler_%d" % [fid, k]
		var p: Array = npc_pos.get(nid, [0.0, 0.0, 180.0])
		var row: Array = tab["settler"][k]
		var d := _npc(nid, row[0], float(p[0]), float(p[1]), row[1], Color(0.9, 0.85, 0.7), row[2], float(p[2]),
			MERCHANT_SHOP + GearCatalog.shop_ids() + GearCatalog.starter_weapon_ids(GameData.items) if row[1] == "merchant" else [])
		d["if"] = fd["quest"]
		out.append(d)
	# guarnição do assentamento (depois da retomada) e dos postos avançados (depois dos postos)
	for d in dawn_garrison(npc_pos, fid + "_g_"):
		d["if"] = fd["quest"]
		d["respawn"] = FORT_RESPAWN
		out.append(d)
	for d in dawn_garrison(npc_pos, fid + "_post_"):
		d["if"] = fd["posts"]
		d["respawn"] = FORT_RESPAWN
		out.append(d)
	return out

static func _fort(fid: String) -> MapDef:
	var fd: Dictionary = FORT_DEFS[fid]
	var z := load_zone(fid)
	var extra := fort_npcs(fid, z["npc_pos"])
	z.erase("npc_pos")
	z.merge({"id": fid, "name": fd["name"], "is_town": false, "level_range": fd["levels"], "ground_color": fd["ground"], "ground_color_alt": (fd["ground"] as Color).darkened(0.08),
		"ambient": fd["ambient"], "sun_energy": float(fd["sun"]), "bot_population": 0, "npcs": extra})
	if fd.get("horde", false):           # acampamentos da Horda: estandartes trocam de cor na retomada
		z["conquest_vis"] = horde_fort_vis(fd["quest"], fid == "fort_war")
	if FORT_LIFE.has(fid):               # cativos que carregam antes; vida da Aurora depois da retomada
		extra.append_array(living_npcs(FORT_LIFE[fid]["pre"], fid + "_", {"unless": fd["quest"]}))
		extra.append_array(living_npcs(FORT_LIFE[fid]["post"], fid + "_", {"if": fd["quest"]}))
	return _mk(z)

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
## `map` = mapa onde fica a casa (sem a chave: Aldara).
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
	# Porto Esperança (Ato II): a taverna dos colonos, marinheiros e caçadores de recompensa
	"in_port_tavern": {"map": "city_port", "name": "Taverna da Âncora", "label": "Taverna", "house": [-29.0, 16.0], "size": [18.0, 14.0], "floor": Color(0.55, 0.42, 0.3),
		"light": Color(1.0, 0.8, 0.55),
		"furniture": [["counter", 0.0, -4.6, 5.0, 1.1, 0.9, 0.0, C_WOOD, true], ["shelf", -2.6, -6.5, 2.2, 2.2, 0.5, 0.0, Color(0.35, 0.5, 0.7), true],
			["fireplace", -7.0, -6.3, 2.2, 2.6, 0.9, 0.0, C_STONE, true], ["barrel", 7.6, -6.2, 0.8, 1.0, 0.8, 0.0, C_WOOD, true],
			["barrel", 6.6, -6.3, 0.8, 1.0, 0.8, 0.0, C_WOOD, true], ["crate", 7.4, -4.8, 0.9, 0.9, 0.9, 15.0, C_WOOD, true],
			["rug", 0.0, 4.2, 4.0, 0.05, 2.4, 0.0, Color(0.25, 0.4, 0.62), false]],
		"tables": [[-5.0, 0.0], [0.0, 0.4], [5.0, 0.0], [-5.0, 3.6], [5.0, 3.6]],
		"npcs": {"ptav_keeper": ["Taberneira Marisa", "villager", Color(0.7, 0.45, 0.35), ["Rum de Kharzun, ensopado de peixe e notícia fresca. Escolha.", "Os ginetes não entram aqui. Ainda."], 0.0, -5.7, 0.0, 0.0],
			"ptav_sailor": ["Marujo Lino", "villager", Color(0.4, 0.55, 0.75), ["Trinta dias de mar e a primeira coisa que vejo em terra é um goblin com lança.", "O Capitão Bren jura que volta ao Bastião toda semana. Eu fico."], 5.0, -1.1, 0.0, 0.0],
			"ptav_hunter": ["Caçadora Vesna", "villager", Color(0.45, 0.6, 0.4), ["O quadro de caçadas fica cheio de lobo e goblin. Pagam bem.", "Lobo de ginete morde mais que o goblin em cima dele."], -5.0, 1.2, 180.0, 0.0],
			"ptav_bard": ["Bardo Tavio", "villager", Color(0.6, 0.5, 0.8), ["♪ Atravessamos o mar atrás de esperança... e achamos orcs! ♪", "Uma moeda e eu canto o naufrágio do Gaivota."], -6.0, -3.6, 30.0, 2.5],
			"ptav_board": ["Quadro de Caçadas", "board", Color(0.6, 0.45, 0.3), ["Pedidos pregados com faca: lobo, goblin, naga, orc. O porto paga.", "Rabiscado embaixo: 'Quem trouxer o tambor do Agitador bebe de graça.'"], -8.2, -2.0, 90.0, 0.0, "prop_shelf"]}},
	# Armazém da Colônia: tudo que o navio traz passa por aqui antes de ir para o mercado ou para o muro
	"in_port_warehouse": {"map": "city_port", "name": "Armazém da Colônia", "label": "Armazém", "house": [21.9, -13.9], "size": [16.0, 12.0], "floor": Color(0.5, 0.42, 0.34),
		"light": Color(1.0, 0.86, 0.62),
		"furniture": [["crate", -6.2, -4.6, 1.2, 1.2, 1.2, 10.0, C_WOOD, true], ["crate", -4.8, -4.8, 1.0, 1.0, 1.0, -8.0, C_WOOD, true], ["crate", -6.0, -3.2, 1.0, 1.0, 1.0, 25.0, C_WOOD, true],
			["barrel", 5.6, -4.8, 0.8, 1.0, 0.8, 0.0, C_WOOD, true], ["barrel", 6.6, -4.8, 0.8, 1.0, 0.8, 0.0, C_WOOD, true], ["barrel", 6.1, -3.8, 0.8, 1.0, 0.8, 0.0, C_WOOD, true],
			["shelf", -1.4, -5.2, 2.2, 2.2, 0.5, 0.0, Color(0.55, 0.45, 0.35), true], ["shelf", 1.4, -5.2, 2.2, 2.2, 0.5, 0.0, Color(0.45, 0.5, 0.6), true],
			["table", 4.6, 1.6, 2.0, 0.85, 1.0, 90.0, C_WOOD, true], ["crate", -6.2, 2.2, 1.1, 1.1, 1.1, 40.0, C_WOOD, true], ["rug", 0.0, 2.6, 3.0, 0.05, 2.0, 0.0, Color(0.45, 0.5, 0.42), false]],
		"tables": [],
		"npcs": {"pwh_quartermaster": ["Intendente Moura", "villager", Color(0.6, 0.55, 0.7), ["Cada prego que chega, eu anoto. Cada prego que some, eu descubro quem levou.", "Pólvora no canto seco, farinha no alto, rum trancado. Regra do armazém."], 4.6, -0.8, 270.0, 0.0],
			"pwh_stevedore": ["Estivador Bóris", "villager", Color(0.62, 0.48, 0.36), ["Empilho caixa desde o primeiro navio. Já sei o que tem dentro pelo peso.", "Essa aqui chacoalha. Não é para chacoalhar."], -3.4, -1.6, 120.0, 2.5],
			"pwh_stowaway": ["Tinoco", "villager", Color(0.95, 0.72, 0.4), ["Shhh! Eu vim escondido no navio. A Intendente acha que eu sou caixa.", "Se perguntarem, você não me viu atrás dos barris."], 6.2, -2.4, 200.0, 0.0]}},
}

## Pontos de colheita (F): item, forma, centro [x, z], raio e quantos. A sim espalha em chão livre (sempre igual por mapa).
const GATHER := {
	"city_aldara": [["herb_green", "herb", [-30.0, 42.0], 14.0, 6], ["herb_green", "herb", [42.0, 46.0], 12.0, 5], ["herb_blue", "herb_blue", [6.7, 88.8], 23.0, 7],
		["iron_ore", "ore", [-6.7, -93.6], 18.0, 6], ["crab_shell", "shell", [6.7, 111.0], 9.0, 4]],
	"field_forest": [["forest_mushroom", "mushroom", [-44.0, 30.0], 18.0, 7], ["forest_mushroom", "mushroom", [74.0, 45.0], 15.0, 4],
		["herb_blue", "herb_blue", [-28.0, -90.0], 14.0, 4], ["stolen_goods", "crate", [50.0, -36.0], 13.0, 6]],
	"field_ruins": [["ancient_relic", "relic", [60.0, 80.0], 14.0, 7], ["ancient_relic", "relic", [24.0, -86.0], 10.0, 3],
		["star_ore", "star", [-57.0, 53.0], 14.0, 5], ["iron_ore", "ore", [-80.0, -42.0], 14.0, 4]],
	# Cidade Élfica: ervas na margem do lago, cogumelos sob o bosque dos trents, pedra-estrela no Altar da Lua
	# e caixotes de Aço Élfico no acampamento da patrulha (guardados pelos guerreiros)
	# Porto Esperança: conchas na areia ao lado do cais
	"city_port": [["crab_shell", "shell", [16.0, 60.0], 5.0, 3]],
	# Costa Partida: conchas na praia, erva azul no mangue, ferro nas falésias
	"field_coast": [["crab_shell", "shell", [-4.0, 64.0], 10.0, 5], ["herb_blue", "herb_blue", [-78.0, 2.0], 10.0, 4], ["iron_ore", "ore", [-10.0, -70.0], 10.0, 4]],
	# Estepes de Cinza: ferro nas duas pontas do norte, erva azul no capim e as presas do Cemitério dos Mamutes (entre os trolls do sudoeste)
	"field_steppe": [["iron_ore", "ore", [-70.0, -34.0], 9.0, 4], ["herb_blue", "herb_blue", [-38.0, 40.0], 8.0, 4], ["iron_ore", "ore", [54.0, -78.0], 9.0, 4],
		["mammoth_tusk", "relic", [-78.0, 63.0], 9.0, 5]],
	"elf_city": [["herb_blue", "herb_blue", [-70.0, 30.0], 12.0, 5], ["forest_mushroom", "mushroom", [58.0, -40.0], 14.0, 5],
		["star_ore", "star", [-40.0, -92.0], 12.0, 5], ["elf_steel", "crate", [70.0, 64.0], 10.0, 4]],
}

## Bichos de ambiente (só apresentação, game/world/ambient_life.gd): por mapa, [tipo, centro [x, z], raio, quantos].
const AMBIENT_LIFE := {
	"city_port": [["gull", [0.0, 58.0], 16.0, 6], ["gull", [0.0, 10.0], 24.0, 3], ["crab", [16.0, 62.0], 6.0, 4], ["crab", [-18.0, 60.0], 5.0, 3]],
	"field_coast": [["gull", [-10.0, 72.0], 24.0, 6], ["gull", [50.0, 62.0], 14.0, 4], ["gull", [-82.0, 30.0], 16.0, 3], ["crab", [16.0, 72.0], 10.0, 5],
		["crab", [-70.0, 52.0], 7.0, 3], ["crab", [-14.0, 76.0], 8.0, 4], ["crow", [70.0, -55.0], 10.0, 3]],
	"dg_goblin": [["bat", [0.0, 25.0], 9.0, 5], ["bat", [-38.0, -5.0], 8.0, 4], ["bat", [35.0, -20.0], 8.0, 4], ["bat", [0.0, -50.0], 7.0, 3]],
	"field_steppe": [["hawk", [0.0, 0.0], 30.0, 2], ["vulture", [-78.0, 63.0], 14.0, 4], ["hawk", [60.0, -35.0], 22.0, 2], ["vulture", [68.0, 48.0], 16.0, 3],
		["moth", [-34.0, 22.0], 8.0, 7], ["moth", [-40.0, 50.0], 8.0, 6]],
	"fort_trolls": [["vulture", [-30.0, 0.0], 16.0, 4], ["crow", [13.0, 0.0], 12.0, 3]],
	"fort_fire": [["crow", [24.6, 17.2], 15.0, 5], ["vulture", [-20.0, -40.0], 18.0, 2]],
	"fort_war": [["vulture", [26.0, -15.0], 16.0, 4], ["crow", [-21.0, 8.0], 12.0, 4]],
}

static func gather_rules(map_id: String) -> Array:
	var out: Array = []
	for g in GATHER.get(map_id, []):
		out.append({"item": g[0], "kind": g[1], "at": Vector3(g[2][0], 0, g[2][1]), "radius": g[3], "count": g[4]})
	return out

## Porta de cada casa que abre: centro da casa no JSON (a mais perto de `house`), direção da frente e ponto da porta.
static func _interior_doors(z: Dictionary, host: String = "city_aldara") -> Dictionary:
	var out := {}
	for iid in INTERIORS:
		if interior_map(iid) != host:
			continue
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

## Mapa onde fica a casa que abre (sem `map`: Aldara).
static func interior_map(id: String) -> String:
	return str(INTERIORS[id].get("map", "city_aldara"))

## Mapas que têm casa que abre.
static func interior_hosts() -> Array:
	var out: Array = []
	for iid in INTERIORS:
		if not out.has(interior_map(iid)):
			out.append(interior_map(iid))
	return out

static func _interior(id: String, doors: Dictionary) -> MapDef:
	var d: Dictionary = INTERIORS[id]
	var host := interior_map(id)
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
		if n.size() > 8:                    # quadro/objeto que "fala": prop no lugar do boneco
			nd["model"] = n[8]
		nd["look_seed"] = absi(nid.hash()) % 100000
		npcs.append(nd)
	var back: Dictionary = doors.get(id, {"door": Vector3.ZERO, "front": Vector3(0, 0, 1)})
	var out_pos: Vector3 = back["door"] + back["front"] * 1.9
	var exit := _portal("exit_" + id, 0.0, h * 0.5 - 0.45, host, out_pos.x, out_pos.z, "Sair")
	exit["radius"] = 0.9
	exit["door"] = true
	return _mk({"id": id, "name": d["name"], "is_town": true, "interior": true, "level_range": Vector2i(1, 30) if host == "city_aldara" else Vector2i(30, 45), "parent_map": host,
		"size": Vector2(w, h), "ground_color": d["floor"], "ground_color_alt": (d["floor"] as Color).darkened(0.1), "ambient": d["light"],
		"sun_energy": 0.9, "spawn_point": Vector3(0, 0, h * 0.5 - 2.6), "obstacles": obs, "portals": [exit], "npcs": npcs, "bot_population": 0})

## Portas das casas em Aldara (entram no MapDef do vale).
static func _door_portals(doors: Dictionary, host: String = "city_aldara") -> Array:
	var out: Array = []
	for iid in doors:
		if interior_map(iid) != host:
			continue
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
	var npcs := _place_npcs(id, z["npc_pos"]) + living_npcs(LIVING_NPCS.get(id, {}))
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
	"vil_porter": ["Carregador Juca", Color(0.6, 0.45, 0.35), ["Caixas para o mercador, caixas para o ferreiro... minhas costas!", "Se vir o Tobias, diga que a carga atrasou."], [2.5, 12.0], [[2.5, 12.0], [-8.0, 13.0], [-14.0, -12.0], [14.0, -14.0]]],
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
## Surtida da catedral: quando uma leva chega à muralha, estes saem pela porta até o portão atacado (recarga em Balance).
const SORTIES := {
	"field_ruins": {"from": Vector3(-16.0, 0.0, 0.0), "cooldown": 180.0,
		"fighters": {"guard_knight": 6, "guard_spearman": 6, "guard_paladin": 2, "guard_crossbow": 3, "guard_priest": 3},
		"say": "Os portões da catedral se abrem: vinte soldados da Aurora saem em socorro do portão!"},
}

const ASSAULTS := {
	# reforços: cada fortaleza retomada manda soldados ao Bastião de tempos em tempos (descem a estrada do front até a praça)
	"field_ruins": {
		"reforco_ghoul": {"fighters": {"guard_knight": 1, "guard_spearman": 1, "guard_priest": 1}, "every": 120.0, "max": Balance.REINFORCE_MAX, "first": 20.0,
			"if": "dw_ghoul_boss", "say": "Reforços do Covil chegam pela garganta oeste!"},
		"reforco_bones": {"fighters": {"guard_knight": 1, "guard_spearman": 1, "guard_crossbow": 1}, "every": 120.0, "max": Balance.REINFORCE_MAX, "first": 40.0,
			"if": "dw_bones_boss", "say": "Reforços da Fortaleza dos Ossos chegam pela garganta norte!"},
		"reforco_frost": {"fighters": {"guard_knight": 1, "guard_paladin": 1, "guard_crossbow": 1}, "every": 120.0, "max": Balance.REINFORCE_MAX, "first": 60.0,
			"if": "dw_frost_boss", "say": "Reforços da Torre chegam pela garganta sul!"},
	},
	"fort_bones": {"aurora": {"fighters": {"guard_knight": 1, "guard_spearman": 2, "guard_priest": 1}, "every": Balance.ASSAULT_FORT_EVERY, "max": Balance.ASSAULT_FORT_MAX, "first": 6.0,
		"power": Balance.ASSAULT_FORT_POWER,
		"if": "dw_ghoul_boss", "unless": "dw_bones_boss", "say": "Trompas da Aurora na estrada: os soldados do Covil sobem contra a Fortaleza dos Ossos!"}},
	"fort_frost": {"aurora": {"fighters": {"guard_knight": 1, "guard_paladin": 1, "guard_crossbow": 1, "guard_priest": 1}, "every": Balance.ASSAULT_FORT_EVERY, "max": Balance.ASSAULT_FORT_MAX, "first": 6.0,
		"power": Balance.ASSAULT_FORT_POWER,
		"if": "dw_bones_boss", "unless": "dw_frost_boss", "say": "A Aurora marcha sobre a Torre do Mago!"}},
	"lich_citadel": {"aurora": {"fighters": {"guard_knight": 3, "guard_paladin": 2, "guard_spearman": 2, "guard_priest": 2}, "every": 40.0, "max": 14, "first": 4.0,
		"if": "dw_frost_boss", "unless": "dw_lich", "say": "A Ofensiva da Aurora sobe a rampa da Cidadela!"}},
	# Estepes de Cinza: cada acampamento retomado manda reforço ao Posto da Caravana pela estrada do lado dele
	"field_steppe": {
		"reforco_trolls": {"fighters": {"guard_knight": 1, "guard_spearman": 1, "guard_priest": 1}, "every": 120.0, "max": Balance.REINFORCE_MAX, "first": 20.0,
			"power": Balance.STEPPE_GUARD_POWER, "if": Q_FORT_TROLLS, "say": "Reforços da Toca chegam pela ponte do oeste!"},
		"reforco_war": {"fighters": {"guard_knight": 1, "guard_paladin": 1, "guard_crossbow": 1}, "every": 120.0, "max": Balance.REINFORCE_MAX, "first": 40.0,
			"power": Balance.STEPPE_GUARD_POWER, "if": Q_FORT_WAR, "say": "Reforços do Arraial descem a estrada do nordeste!"},
		"reforco_fire": {"fighters": {"guard_knight": 1, "guard_spearman": 1, "guard_crossbow": 1}, "every": 120.0, "max": Balance.REINFORCE_MAX, "first": 60.0,
			"power": Balance.STEPPE_GUARD_POWER, "if": Q_FORT_FIRE, "say": "Reforços da Paliçada chegam pela estrada do sudeste!"},
	},
}

# ---------------------------------------------------------------------------
## Ato II (Costa Partida / Porto Esperança / Grutas Goblin). Monstros com id do contrato que ainda não existem no catálogo
## nascem como o substituto daqui (nível 25-30 parecido). INTEGRAÇÃO: quando o pacote de monstros entrar, esvazie STAND_INS.
## Fase 2 (Estepes de Cinza, 35-40): trolls, arqueiros, guerreiro orc e os três chefes já existem (sem substituto).
const STAND_INS := {
}
## NPCs de cabana cujas quests vêm do pacote de missões (ainda fora deste ramo). INTEGRAÇÃO: esvazie quando as quests chegarem.
const PENDING_GIVERS := []   # vazio: as cabanas das Estepes já têm missão (QuestsCatalog.act2_steppe)

## Id de monstro que existe no jogo: o do contrato ou, enquanto ele não chega, o substituto.
static func mob(id: String) -> String:
	if GameData.monsters.has(id) or not STAND_INS.has(id):
		return id
	return STAND_INS[id]

## Levas de investida com os ids trocados por `mob` (waves, scale_extra, reclaim_extra, leader).
static func _mob_raid(d: Dictionary) -> Dictionary:
	for w in d.get("waves", []):
		var mobs := {}
		for k in w["mobs"]:
			mobs[mob(k)] = int(mobs.get(mob(k), 0)) + int(w["mobs"][k])
		w["mobs"] = mobs
	if d.has("leader"):
		d["leader"] = mob(d["leader"])
	return d

## Missões que mudam o cenário da Costa/Porto (estágios C1-C4 do GDD do Ato II).
const Q_PALISADE := "hx_palisade"
const Q_LIGHTHOUSE := "hx_lighthouse"
const Q_RIDERS := "hx_riders_camp"
const Q_GOBLIN_BOSS := "hx_goblin_boss"

## Porto Esperança: serviços (posição do JSON). id -> [nome, papel, cor, falas, extras {if, shop}].
const PORT_NPCS := {
	"port_governor": ["Governadora Alba Ventura", "quest", Color(0.55, 0.62, 0.85), ["Porto Esperança tem três semanas, uma paliçada pela metade e uma Horda inteira do outro lado do morro.", "Feche a paliçada primeiro. Depois a gente pensa em sonhar."], {}],
	"port_smith": ["Ferreiro Caetano", "smith", Color(0.72, 0.5, 0.36), ["Aço de Kharzun é escuro e teimoso. Eu sou mais.", "Anéis, amuletos e aprimoramento. O que vier da Horda eu derreto."], {}],
	"port_alchemist": ["Alquimista Odila", "alchemy", Color(0.5, 0.78, 0.62), ["Alga da maré e erva azul dão uma poção que segura mordida de lobo.", "Cuidado com a rede dos saqueadores: corte com a lâmina, não com a mão."], {}],
	"port_merchant": ["Mercador Jonas", "merchant", Color(0.86, 0.74, 0.48), ["Poções e ataduras chegaram no último navio. O resto é promessa."], {"shop": "merchant"}],
	"port_storage": ["Guarda-volumes Nair", "storage", Color(0.45, 0.6, 0.75), ["O baú da colônia é o mesmo depósito de Aldara. Cruzou o mar com a gente."], {}],
	"port_import_merchant": ["Dona Celina, a Importadora", "merchant", Color(0.92, 0.7, 0.5), ["Com o farol aceso, o segundo navio achou a baía. E trouxe minhas caixas!", "Elixires do continente, a preço de continente."], {"shop": "merchant", "if": Q_LIGHTHOUSE}],
	"port_sailor": ["Marinheira Dora", "villager", Color(0.4, 0.55, 0.78), ["O navio volta ao Bastião sempre que alguém pisa no cais. O Capitão não gosta de esperar.", "Daqui até o Bastião é um dia de vento bom."], {}],
}
## Mestres de ascensão (QuestsCatalog.ASC_MASTERS) e o memorial do Estrela (O Diário do Capitão), na praça do porto.
## id -> [nome, papel, cor, falas, x, z, facing, extras {if, model}].
const PORT_EXTRA_NPCS := {
	"master_paladin": ["Sir Aldwin", "quest", Color(0.95, 0.85, 0.5), ["Cavaleiro da Aurora. Vim com a frota e trouxe a sela; o cavalo ficou com a Horda.", "Aos 35, venha falar comigo. Um paladino montado vale por dez a pé."], 12.7, -4.7, -45.0, {}],
	"master_elementalist": ["Arquimaga Ysolde", "quest", Color(0.4, 0.6, 0.95), ["O mar de Kharzun tem magia na água. Os elementais sentem.", "Aos 35, traga o seu elemental. Ele pode crescer muito mais."], 15.6, 17.0, -120.0, {}],
	"master_berserker": ["Gorm Duas-Lâminas", "quest", Color(0.8, 0.35, 0.25), ["Mercenário. Pago por cabeça, mas aqui a cabeça é verde.", "Aos 35 eu te ensino a erguer dois machados de duas mãos. Se aguentar."], -12.7, -4.7, 45.0, {}],
	"master_bishop": ["Madre Celene", "quest", Color(0.95, 0.95, 0.88), ["Capelã da frota. A Luz atravessou o mar com a gente; o Coro ficou do outro lado.", "Aos 35, me ajude a reacender o Santuário Afogado e o Coro canta aqui também."], 9.0, 23.6, -150.0, {}],
	"master_druid": ["Ancião Bhoran", "quest", Color(0.45, 0.7, 0.35), ["Naufraguei aqui antes de vocês. O mangue me deu comida e conselho.", "Aos 35, tenho uma semente para você. Ela não pega em terra salgada sem ajuda."], -9.0, 23.6, 150.0, {}],
	"master_ranger": ["Kaya Olho-de-Falcão", "quest", Color(0.55, 0.7, 0.45), ["Batedora da colônia. Vi pegadas de tigre do tamanho da minha mão aberta.", "Aos 35, venha caçar comigo. Arco, mosquete ou lança, o rastro é o mesmo."], 18.2, -2.5, -60.0, {}],
	"master_assassin": ["Ninguém", "quest", Color(0.3, 0.28, 0.38), ["Você não me viu. Eu vi você.", "Aos 35, procure ninguém. Sou eu."], -15.6, 17.0, 120.0, {}],
	"master_necromancer": ["O Último Escriba de Azhar", "quest", Color(0.55, 0.8, 0.65), ["Eu escrevia os decretos do Lich. Agora escrevo o meu arrependimento.", "Aos 35, um necromante pode aprender o que Azhar sabia, e usar melhor."], -15.6, -1.0, 60.0, {}],
	"port_memorial": ["Memorial do Estrela", "board", Color(0.8, 0.82, 0.85), ["'Ao Estrela e ao Capitão Odran, que chegaram primeiro.'", "Embaixo, a última linha do diário: 'Eles fogem do leste.'"], -10.4, 14.0, 120.0, {"if": "hx_dc_diary", "model": "prop_statue"}],
}
## Colonos que passeiam no porto (formato de VILLAGERS).
const PORT_VILLAGERS := {
	"port_vil_builder": ["Carpinteiro Bruno", Color(0.6, 0.45, 0.3), ["Cada estaca dessa paliçada passou pela minha mão. Faltam trezentas.", "Se os ginetes derrubarem de novo, eu levanto de novo."], [-12.0, 2.0], 5.0],
	"port_vil_fisher": ["Pescadora Iara", Color(0.4, 0.6, 0.75), ["Peixe aqui é grande e bravo. Igual a tudo em Kharzun.", "As nagas roubam a rede. Eu roubo de volta."], [8.0, 46.0], 3.0],
	"port_vil_kid": ["Chico", Color(0.95, 0.75, 0.35), ["Eu vi um goblin! Ele era menor que eu!", "Minha mãe disse que lobo com goblin em cima é pior que lobo sozinho."], [3.0, 14.0], 6.0],
	"port_vil_nurse": ["Enfermeira Rute", Color(0.92, 0.88, 0.8), ["Mordida de lobo, flecha goblin, insolação. O porto inteiro passa por mim.", "Se for à praia, volte antes da maré."], [10.0, 2.0], 3.0],
	"port_vil_porter": ["Estivador Gil", Color(0.6, 0.45, 0.35), ["Caixa do navio pro mercado, do mercado pro muro, do muro pro navio...", "O segundo navio? Só quando acenderem o farol."], [0.0, 30.0], [[0.0, 30.0], [-2.0, 50.0], [0.0, 30.0], [8.0, 14.0]]],
	"port_vil_monk": ["Irmão Celso", Color(0.85, 0.8, 0.7), ["Trouxemos a Luz pelo mar. Ela não enjoa.", "Rezo pelos que ficaram no Gaivota."], [-8.0, 2.0], 3.0],
}
## Costa Partida: guia na encruzilhada, colonos da fazenda (C3) e a aldeia goblin mista (C4).
## id -> [nome, papel, cor, falas, x, z, passeio m, if] (posição do JSON quando houver marcador com o id).
const COAST_NPCS := {
	"coast_scout": ["Batedora Nádia", "guard", Color(0.5, 0.65, 0.5), ["Praia e nagas ao sul, goblins no mangue a oeste, ginetes no nordeste, orcs nas falésias ao norte.", "O farol no promontório se vê de qualquer canto. Perdeu o rumo, procure ele.", "As Grutas Goblin ficam ao norte da aldeia de palafitas. Leve grupo: o Agitador-Mor bate o tambor e o bando fica bravo."], 0.0, 0.0, 0.0, ""],
	"coast_farmer_a": ["Colona Fátima", "villager", Color(0.75, 0.6, 0.4), ["Onde os lobos dormiam agora tem nabo. Melhor troca não há.", "Os ginetes que sobraram passam de longe."], 64.0, -48.0, 4.0, Q_RIDERS],
	"coast_farmer_b": ["Colono Abel", "villager", Color(0.6, 0.5, 0.35), ["Terra boa, essa. Os ginetes adubaram bem.", "A Governadora prometeu sementes no próximo navio."], 80.0, -50.0, 4.0, Q_RIDERS],
	"goblin_nikki": ["Nikki, a Goblin Comerciante", "merchant", Color(0.55, 0.75, 0.4), ["Agitador caiu, Nikki vende! Tudo honesto. Quase tudo.", "Humano paga em ouro, goblin paga em coisa brilhante. Nikki aceita os dois."], -87.0, 22.0, 0.0, Q_GOBLIN_BOSS],
	"goblin_villager_a": ["Gobo, o Pescador", "villager", Color(0.5, 0.7, 0.4), ["Sem tambor, sem guerra. Gobo pesca agora.", "Humano grande. Gobo gosta de humano grande que não pisa em Gobo."], -90.0, 27.0, 2.0, Q_GOBLIN_BOSS],
	"goblin_villager_b": ["Ziza", "villager", Color(0.6, 0.7, 0.45), ["O Agitador gritava a noite toda. Agora dá pra dormir.", "Os orcs vão voltar. Os orcs sempre voltam."], -96.0, 22.0, 2.0, Q_GOBLIN_BOSS],
	# fins das paralelas da Costa (quests_catalog.act2): o lugar ganha gente nova
	"coast_survivor_lia": ["Lia, a Cozinheira", "villager", Color(0.85, 0.6, 0.45), ["Três semanas comendo peixe cru no recife. Hoje tem ensopado, e quem reclamar lava a panela.", "O Tomás chorou quando me viu. Não conte pra ninguém."], -71.0, 44.0, 2.0, "hx_nf_rescue"],
	"coast_pearl_diver": ["Naia, a Mergulhadora", "villager", Color(0.35, 0.65, 0.75), ["Sem a Mãe das Marés, o recife é só ostra e silêncio.", "Uma pérola por mergulho, se a maré deixar."], -4.0, 56.0, 3.0, "hx_pe_mother"],
	"goblin_drummer": ["Tum-Tum, o Tamborileiro", "villager", Color(0.5, 0.72, 0.38), ["Bum, bum! Tambor de feira! Ninguém briga, todo mundo compra!", "Antes Tum-Tum tocava para guerra. Agora toca para a Nikki."], -83.0, 22.0, 0.0, "hx_nk_drum"],
}
## Investida dos ginetes sobre o porto (rotas no JSON: cerco = C0, muralha = C1, patrulha = C3). Intervalo 240 s ±20%.
const PORT_RAIDS := {
	"cerco": {"every": 240.0, "first": 90.0, "jitter": 48.0, "lifetime": 200.0,
		"waves": [{"mobs": {"wolf_rider": 3, "goblin_lancer": 3}}, {"mobs": {"wolf_raider": 1}, "every_nth": 3}],
		"say_start": "Uivos na garganta nordeste: os ginetes descem contra Porto Esperança!",
		"say_arrived": "Os ginetes passaram pelos vãos da paliçada! Defendam a praça!",
		"say_repelled": "Os ginetes foram rechaçados. A colônia resiste!",
		"say_retreat": "Os ginetes que sobraram somem morro acima."},
	"muralha": {"every": 240.0, "first": 90.0, "jitter": 48.0, "lifetime": 200.0,
		"waves": [{"mobs": {"wolf_rider": 5, "goblin_lancer": 4, "wolf_raider": 1}}],
		"say_start": "Tambores e uivos: uma investida maior desce contra a paliçada nova!",
		"say_arrived": "Os ginetes batem no portão norte! A paliçada segura!",
		"say_repelled": "A investida quebrou no portão norte!",
		"say_retreat": "Os ginetes recuam da paliçada."},
	"patrulha": {"every": 240.0, "first": 120.0, "jitter": 48.0, "lifetime": 160.0,
		"waves": [{"mobs": {"wolf_rider": 3}}],
		"say_start": "Uma patrulha de ginetes ronda o portão norte.",
		"say_arrived": "A patrulha de ginetes chegou ao portão norte.",
		"say_repelled": "A patrulha de ginetes foi espantada.",
		"say_retreat": "A patrulha volta para o morro."},
}
## Peças do GLB que mudam com o estágio (MapBuilder.apply_conquest).
const PORT_CONQUEST_VIS := [{"tag": "palicada_nova", "if": Q_PALISADE}, {"tag": "andaime", "unless": Q_PALISADE},
	{"tag": "farolete_luz", "if": Q_LIGHTHOUSE}, {"tag": "farolete_apagado", "unless": Q_LIGHTHOUSE}, {"tag": "navio2_", "if": Q_LIGHTHOUSE}]
const COAST_CONQUEST_VIS := [{"tag": "farol_luz", "if": Q_LIGHTHOUSE}, {"tag": "farol_apagado", "unless": Q_LIGHTHOUSE},
	{"tag": "passo_estepes_fechado", "unless": Q_GOBLIN_BOSS}, {"tag": "passo_estepes_aberto", "if": Q_GOBLIN_BOSS}]     # C4: passagem das Estepes

# ---------------------------------------------------------------------------
## Estepes de Cinza (Ato II, fase 2, 35-40): tools/blender/zones/build_field_steppe.py. Posto da Caravana no centro.
## id -> [nome, papel, cor, falas, extras {shop, if, unless}] (posição do JSON).
const STEPPE_NPCS := {
	"caravan_master": ["Mestre da Caravana Horácio", "quest", Color(0.82, 0.66, 0.38), ["Três acampamentos de guerra, três estradas, e a minha caravana parada no meio. Escolha um lado e comece.", "Trolls a oeste depois da ponte, a tropa de Ghar a nordeste, as flechas de fogo a sudeste. O Totem Partido marca o norte.", "Cada acampamento que cair vira posto nosso. Os que sobrarem vão bater com mais raiva, então não demore entre um e outro."], {}],
	"steppe_smith": ["Ferreiro Baltazar", "smith", Color(0.7, 0.5, 0.36), ["Forja em cima de roda. Onde a caravana para, eu acendo.", "Aprimoro e faço joias. Presa de troll dá um cabo que não racha."], {}],
	"steppe_alchemist": ["Alquimista Jandira", "alchemy", Color(0.5, 0.76, 0.62), ["Troll se fecha sozinho. Fogo e veneno deixam a ferida aberta: leve os dois.", "O talho do Carniceiro sangra como veneno: troll cortado assim também não fecha.", "Capim de cinza dá um chá horrível e uma poção ótima."], {}],
	"steppe_merchant": ["Mercadora Noêmia", "merchant", Color(0.86, 0.72, 0.46), ["Poção, atadura e corda. O que a Horda não levou está na minha carroça."], {"shop": "merchant"}],
	"steppe_storage": ["Guarda-volumes Tibério", "storage", Color(0.45, 0.6, 0.75), ["O baú da caravana é o mesmo de Aldara e do porto. Ele viaja melhor que a gente."], {}],
	"deserter_chief": ["Urzog, Chefe dos Desertores", "quest", Color(0.5, 0.62, 0.42), ["Largamos o estandarte de Ghar. Quem larga o estandarte não tem para onde voltar.", "A Horda não desce a montanha por gosto. Alguma coisa empurra ela do leste."], {"unless": Q_DESERTERS_TURN}],
	"deserter_merchant": ["Brakka, a Mercadora Orc", "merchant", Color(0.56, 0.7, 0.4), ["Ouro humano compra igual. Brakka não pergunta de quem era.", "Você ficou do lado de Urzog. Brakka faz preço de amigo."], {"shop": "merchant", "if": Q_DESERTERS_HELP}],
	"deserter_wolf_keeper": ["Gruk, o Tratador de Lobos", "villager", Color(0.5, 0.56, 0.44), ["Lobo de montaria não morde quem dá comida. Quase nunca.", "Urzog disse que humano amigo pode montar. Gruk ainda está pensando no preço."], {"if": Q_DESERTERS_HELP}],
	# fins das paralelas das Estepes (QuestsCatalog.STEPPE_CHAINS): o lugar ganha gente nova. `pos` = [x, z, giro] (não vem do JSON).
	"caravan_trader": ["Lívia, da Segunda Caravana", "merchant", Color(0.8, 0.58, 0.42), ["A primeira carga chegou inteira ao porto. A segunda caravana sou eu.", "Sal do porto, pano de Aldara e notícia fresca. A notícia é de graça."], {"shop": "merchant", "if": "hx_cv_goods", "pos": [13.0, -1.0, -90.0]}],
	"ivory_carver": ["Tobias, o Entalhador", "villager", Color(0.9, 0.86, 0.72), ["Marfim de mamute não lasca. Dá pente, dá cabo, dá peça de jogo.", "A Sabá acha a presa, eu acho o que tem dentro dela."], {"if": "hx_mi_bulls", "pos": [-58.8, 76.4, -160.0]}],
	"wind_shaman": ["Morga, a Velha do Vento", "villager", Color(0.46, 0.58, 0.44), ["Morga entalhou os riscos do alto quando era menina. A mão tremia. Ainda treme.", "A Horda não foge de vocês, humano. Vocês só estão no caminho.", "Não pergunte o nome. Quem deu nome, ele ouviu."], {"if": "hx_tv_east", "pos": [24.2, -60.2, -140.0]}],
	"wolf_runner": ["Zuri, a Corredora", "villager", Color(0.7, 0.5, 0.36), ["Vi o filhote passar pela fumaça dos batedores. Quero um igual.", "Do canil ao Totem, ida e volta: o Dinho ainda ganha. Por enquanto."], {"if": "hx_cl_scouts", "pos": [35.6, 76.4, -145.0]}],
}

## Peças do map_field_steppe.glb que trocam com o estágio: por acampamento (E1-E3) e o passo de Kharzun (E5 = os três).
static func steppe_conquest_vis() -> Array:
	var out: Array = []
	for side in ["trolls", "fire", "war"]:
		var q: String = "hx_fort_" + side
		out.append_array([{"tag": "estandarte_horda_" + side, "unless": q}, {"tag": "estandarte_aurora_" + side, "if": q},
			{"tag": "chao_front_" + side, "unless": q}, {"tag": "limpo_" + side, "if": q},
			{"tag": "torre_horda_%s_teto" % side, "unless": q}, {"tag": "torre_aurora_" + side, "if": q}])
	out.append_array([{"tag": "passo_fechado", "unless": Q_STEPPE_FORTS}, {"tag": "passo_aberto", "if": Q_STEPPE_FORTS}])
	return out

## Investidas sobre o Posto da Caravana (E0): uma por lado, calada pela quest do acampamento (rota no JSON). As que
## sobram crescem a cada acampamento retomado (Balance.RAID_RECLAIM_MULT) e ganham `reclaim_extra`.
const STEPPE_RAIDS := {
	"trolls": {"every": 220.0, "first": 80.0, "jitter": 44.0, "lifetime": 200.0,
		"waves": [{"mobs": {"troll_whelp": 4, "wolf_raider": 1}}, {"mobs": {"troll": 1}, "every_nth": 2}],
		"say_start": "O chão treme a oeste: os trolls cruzam a ponte rumo ao Posto da Caravana!",
		"say_arrived": "Os trolls chegaram ao vão oeste das carroças!",
		"say_repelled": "Os trolls foram derrubados no vão oeste. As carroças aguentaram!",
		"say_retreat": "Os trolls que sobraram voltam para a ponte.",
		"reclaim_extra": {1: {"troll": 1}, 2: {"troll": 2}},
		"say_reclaim": "A Toca ruge pelos acampamentos perdidos: os trolls vêm em maior número!",
		"say_last": "Só a Toca resiste e joga tudo contra o Posto da Caravana: sozinho você não segura a última frente. Chame aliados (forme um grupo) antes de defender o vão oeste!"},
	"war": {"every": 240.0, "first": 150.0, "jitter": 48.0, "lifetime": 200.0,
		"waves": [{"mobs": {"orc_warrior": 6, "goblin_agitator": 1, "wolf_raider": 1}}],
		"say_start": "Tambores no nordeste: a tropa de Ghar marcha contra o Posto da Caravana!",
		"say_arrived": "Os guerreiros de Ghar bateram no vão leste!",
		"say_repelled": "A tropa de Ghar quebrou no vão leste!",
		"say_retreat": "Os guerreiros recuam para o Arraial.",
		"reclaim_extra": {1: {"orc_warrior": 2}, 2: {"goblin_agitator": 1, "orc_warrior": 2}},
		"say_reclaim": "Ghar manda mais guerreiros pelos acampamentos perdidos!",
		"say_last": "Só Ghar resiste e joga a tropa inteira contra o Posto da Caravana: sozinho você não segura a última frente. Chame aliados (forme um grupo) antes de defender o vão leste!"},
	"fire": {"every": 260.0, "first": 220.0, "jitter": 52.0, "lifetime": 200.0,
		"waves": [{"mobs": {"orc_archer": 6, "orc_crossbow": 2}}, {"mobs": {"wolf_raider": 1}, "every_nth": 2}],
		"say_start": "Fumaça no sudeste: os arqueiros de fogo avançam sobre o Posto da Caravana!",
		"say_arrived": "Flechas de fogo caem no vão leste! Saiam dos círculos!",
		"say_repelled": "Os arqueiros foram postos para correr. As lonas ainda estão inteiras!",
		"say_retreat": "Os arqueiros recuam para a Paliçada.",
		"reclaim_extra": {1: {"orc_crossbow": 1}, 2: {"orc_crossbow": 2}},
		"say_reclaim": "A Paliçada responde aos acampamentos perdidos com mais arcos!",
		"say_last": "Só a Paliçada resiste e despeja todos os arcos sobre o Posto da Caravana: sozinho você não segura a última frente. Chame aliados (forme um grupo) antes de defendê-lo!"},
}
# ---------------------------------------------------------------------------
## Vida dos mapas do Ato II (estivadores, pescadores, caravana, pastores, cativos, guarnição depois da retomada).
## mapa -> id -> [nome, cor, falas, barks, casa [x, z], passeio m | rota [[x, z]...] | {"ring": [cx, cz, raio, pontos, fase°]}, extras].
## Extras: `carry` (carga no ombro `carry_crate|carry_sack|carry_log|carry_rock` ou `cart` = puxa a carroça; só visual,
## CarryPose), `if`/`unless` (quest), `model` (monstro/cavalo no lugar do kit humano), `fighter` (sentinela que luta: atributos do
## monstro `guard_*`, GuardBrain), `power` (vida/ataque x), `role` (padrão "villager"). Barks = falas soltas sobre a cabeça
## quando o jogador passa perto (só apresentação, game/world/ambient_life.gd).
const LIVING_NPCS := {
	"city_port": {
		"port_vil_docker_a": ["Estivador Ramiro", Color(0.62, 0.46, 0.34), ["Do navio pro mercado, do mercado pro navio. O mar não descansa, eu também não.", "Caixa com furo é da Celina. Caixa inteira é do Jonas. Não troque."],
			["Olha a caixa!", "Abre caminho, abre caminho!", "Essa aqui é peixe. Ou era."], [-2.0, 54.0], [[-2.0, 54.0], [0.0, 44.0], [0.0, 32.0], [-8.0, 27.0], [0.0, 32.0], [0.0, 44.0]], {"carry": "carry_crate"}],
		"port_vil_docker_b": ["Estivadora Tânia", Color(0.55, 0.42, 0.36), ["Pólvora, prego e farinha vão pro armazém. O resto vai pra onde a Governadora mandar.", "Já carreguei um barril de rum morro acima com um goblin pendurado. Ganhei o barril."],
			["Mais uma pro armazém!", "Quem largou essa corda aqui?", "Costas de ferro, joelho de vidro."], [2.0, 52.0], [[2.0, 52.0], [0.0, 40.0], [3.0, 24.0], [13.0, 12.0], [18.0, -4.0], [13.0, 12.0], [3.0, 24.0], [0.0, 40.0]], {"carry": "carry_sack"}],
		"port_vil_docker_c": ["Carregador Bastos", Color(0.58, 0.5, 0.38), ["Estaca nova pro portão norte. Cada uma pesa um marujo.", "O Bruno conta as estacas. Eu conto as farpas."],
			["Estaca pro portão!", "Uf... falta pouco.", "Sai da frente que isso é madeira de lei!"], [-1.0, 48.0], [[-1.0, 48.0], [0.0, 38.0], [-3.0, 24.0], [-14.0, 10.0], [-2.0, -10.0], [2.0, -20.0], [-2.0, -10.0], [-14.0, 10.0], [-3.0, 24.0], [0.0, 38.0]], {"carry": "carry_log"}],
		"port_vil_fisher_b": ["Pescador Duarte", Color(0.4, 0.55, 0.7), ["Robalo de Kharzun tem dente. Robalo de casa não tinha.", "Se a linha puxar pra baixo, é peixe. Se puxar pra cima, é naga. Solte."],
			["Hoje tá dando...", "Shhh, espanta o peixe.", "Mais um! Pequeno, mas é um."], [11.0, 55.0], 1.5, {}],
		"port_vil_fisher_c": ["Velho Anselmo", Color(0.5, 0.55, 0.62), ["Pesco desde menino. Do outro lado do mar o peixe era mais educado.", "Gaivota esperta rouba da cesta. Gaivota burra rouba do anzol."],
			["Xô, gaivota!", "No meu tempo...", "A maré vira já, já."], [-12.0, 54.0], 1.0, {}],
		"port_vil_hawker_a": ["Peixeira Joana", Color(0.75, 0.5, 0.45), ["Peixe de manhã, ensopado de tarde, sopa de espinha de noite. Nada se perde.", "O porto come o que o mar dá. E o mar anda generoso."],
			["Peixe fresco! Fresquinho!", "Leva dois, paga um e meio!", "Olha o robalo, freguês!"], [9.0, 27.0], 2.0, {}],
		"port_vil_hawker_b": ["Vendedor Quim", Color(0.8, 0.68, 0.4), ["Corda, rede, anzol, vela de sebo. O que o navio trouxe, eu revendo.", "Pechinchar é permitido. Ganhar a pechincha, não."],
			["Corda boa, corda forte!", "Vela de sebo pra noite comprida!", "Anzol, rede, tudo aqui!"], [-9.0, 27.0], 2.0, {}],
		"port_vil_sailor_a": ["Marujo Pedrão", Color(0.38, 0.5, 0.72), ["Cruzei o mar sete vezes. Na oitava, fico.", "O Andorinha é bom barco. O Gaivota também era."],
			["Ê, terra firme!", "Alguém viu meu chapéu?", "Vento bom pro Bastião hoje."], [-2.0, 50.0], 4.0, {}],
		"port_vil_sailor_b": ["Grumete Leo", Color(0.45, 0.6, 0.8), ["O Capitão diz que grumete não faz pergunta. Eu faço baixinho.", "Já vi uma naga do mastro. Ela me viu também."],
			["Sim, senhor!", "Nó de marinheiro, nó de marinheiro...", "Esfrega, esfrega."], [-4.0, 52.0], [[-4.0, 52.0], [3.0, 51.0], [2.0, 56.0], [-3.0, 56.0]], {}],
		"port_vil_kid_b": ["Belinha", Color(0.92, 0.6, 0.7), ["Eu e o Chico vamos ser batedores igual a Kaya!", "Minha mãe costura vela. Eu costuro boneca de vela."],
			["Não me pega!", "Lá vem o lobo! Corre!", "Um, dois, três... pique!"], [-5.0, 13.0], 7.0, {}],
		"port_vil_kid_c": ["Zeca", Color(0.95, 0.7, 0.35), ["Achei uma concha que canta. Escuta! ...Tá, agora não tá cantando.", "Quando eu crescer vou ter um navio só meu."],
			["Achei uma concha!", "Tô com fome...", "Ei, aventureiro!"], [5.0, 21.0], 7.0, {}],
		"port_vil_washer": ["Lavadeira Dita", Color(0.85, 0.82, 0.7), ["Água doce só nesse poço. A do mar deixa a roupa dura feito couro.", "Sangue de goblin sai com cinza e paciência. Muita paciência."],
			["Ai, minhas costas.", "Mais um balde...", "Roupa de soldado, sempre suja."], [16.0, -4.0], 2.5, {}],
		"port_vil_apprentice": ["Aprendiz Davi", Color(0.65, 0.5, 0.36), ["O Bruno diz que eu martelo torto. Eu digo que a estaca é que é torta.", "Quando a paliçada fechar, vou dormir uma semana."],
			["Martelo, prego, martelo...", "Ai, meu dedo!", "Mais trezentas, ele disse..."], [-5.0, -17.0], 3.0, {"unless": Q_PALISADE}],
		"port_vil_widow": ["Dona Clotilde", Color(0.6, 0.5, 0.65), ["Meu filho veio no Estrela, antes de todos. Eu vim atrás.", "Sento aqui e olho o mar. Às vezes ele responde."],
			["Que vento frio...", "Ele chegou primeiro.", "O mar sempre devolve alguma coisa."], [-16.0, 21.0], 2.0, {}],
		# C1: a guarda ronda o anel de dentro da paliçada nova
		"port_vil_watch_a": ["Sentinela Abreu", Color(0.62, 0.62, 0.72), ["Ronda do anel. Do portão norte ao cais, e de volta.", "Desde que a paliçada fechou, a gente dorme por turnos. Antes, não dormia."],
			["Tudo calmo no anel.", "Atenção no portão norte!", "Ronda!"], [20.0, 8.0], {"ring": [0.0, 8.0, 20.0, 8, 0.0]}, {"fighter": "guard_spearman", "if": Q_PALISADE}],
		"port_vil_watch_b": ["Sentinela Faria", Color(0.62, 0.62, 0.72), ["Do lado oeste dá pra ver a estrada da Costa. Ginete vem sempre do morro.", "Besteiro no muro, lança no chão. Assim o porto aguenta."],
			["Nada no oeste.", "Olho no morro!", "Ronda!"], [-20.0, 8.0], {"ring": [0.0, 8.0, 20.0, 8, 180.0]}, {"fighter": "guard_spearman", "if": Q_PALISADE}],
	},
	"field_coast": {
		"coast_refugee_a": ["Refugiada Leonor", Color(0.7, 0.55, 0.5), ["Saímos da fazenda dos Prado quando os ginetes chegaram. Paramos aqui porque a Nádia tem fogo e arco.", "O porto está cheio. A encruzilhada, não."],
			["Tem lugar no fogo, viu?", "Cadê o Pedrinho?!", "Mais um dia."], [4.0, 4.0], 4.0, {}],
		"coast_refugee_kid": ["Pedrinho", Color(0.95, 0.72, 0.4), ["A Batedora Nádia disse que eu posso vigiar a estrada. Eu vigio!", "Vi um caranguejo do tamanho de um gato."],
			["Vigiando!", "Tem um caranguejo ali!", "Mãe, olha!"], [-4.0, 6.0], 6.0, {}],
		"coast_cook": ["Cozinheiro Valdo", Color(0.88, 0.78, 0.58), ["Sopa de alga, sopa de peixe, sopa de alga com peixe. Cardápio da encruzilhada.", "Quem passa pela estrada come. Quem fica, ajuda a mexer."],
			["Sopa quente!", "Mexe, mexe...", "Mais sal, menos areia."], [-6.0, -4.0], 2.0, {}],
		"coast_fisher_shore": ["Pescador Isaías", Color(0.42, 0.58, 0.72), ["A Ilda me deixa pescar perto do farol. Em troca, eu levo o óleo.", "Naga não gosta de luz. Desde que o farol acendeu, durmo melhor."],
			["Peixe no balde!", "Olha a onda...", "Hoje o mar tá manso."], [44.0, 52.0], 2.0, {}],
		"coast_shell_a": ["Catadora Rosa", Color(0.78, 0.6, 0.5), ["Concha de caranguejo vira prato, colher e botão. O Tomás me ensinou.", "Não pise na areia molhada perto das pedras: é onde elas dormem."],
			["Mais uma concha...", "Essa tá inteira!", "Ai, belisca!"], [-70.0, 40.0], 3.0, {}],
		"coast_shell_b": ["Catador Zé", Color(0.6, 0.52, 0.42), ["Sem a Mãe das Marés, a praia é de quem chega cedo.", "Pérola pequena eu vendo. Pérola grande eu escondo."],
			["Maré baixa, cesta cheia!", "Pérola não, só concha...", "Bom dia, praia!"], [-10.0, 60.0], 3.0, {"if": "hx_pe_mother"}],
		"coast_walkers": ["Família Prado", Color(0.66, 0.5, 0.38), ["Vamos pro porto. A Governadora prometeu teto pra quem trabalhar.", "Os ginetes queimaram o celeiro. A gente salvou a carroça e a avó."],
			["Falta muito?", "Olha o farol, ali!", "Anda, anda, antes de escurecer."], [12.0, 1.0], [[12.0, 1.0], [35.0, 6.0], [60.0, 2.0], [88.0, 4.0], [99.0, 13.0], [88.0, 4.0], [60.0, 2.0], [35.0, 6.0]], {}],
		"coast_patrol_a": ["Patrulheiro Hugo", Color(0.6, 0.62, 0.7), ["Ronda da estrada do porto. Ginete solto não passa daqui.", "A Governadora mandou dois. Mandou certo."],
			["Estrada limpa.", "Olho no nordeste!", "Ronda!"], [14.0, 2.0], [[14.0, 2.0], [35.0, 6.0], [60.0, 2.0], [88.0, 4.0], [60.0, 2.0], [35.0, 6.0]], {"fighter": "guard_spearman"}],
		"coast_patrol_b": ["Besteira Lídia", Color(0.6, 0.62, 0.7), ["Virote no ginete, nunca no lobo. Lobo sem dono volta pra casa.", "Da estrada eu vejo o farol. Ele me vê também."],
			["Nada à vista.", "Virote pronto!", "Ronda!"], [88.0, 4.0], [[88.0, 4.0], [60.0, 2.0], [35.0, 6.0], [14.0, 2.0], [35.0, 6.0], [60.0, 2.0]], {"fighter": "guard_crossbow"}],
		"coast_farm_plow": ["Colono Ezequias", Color(0.62, 0.5, 0.34), ["Arar terra de lobo dá trabalho. Sai osso de todo canto.", "Nabo, cebola, abóbora. A Fátima quer flores. Vai ter flores."],
			["Ôa, ôa...", "Mais um sulco.", "Terra boa, essa."], [62.0, -46.0], [[62.0, -46.0], [76.0, -46.0], [76.0, -50.0], [62.0, -50.0]], {"if": Q_RIDERS}],
		"goblin_fisher_a": ["Bibo, o Pescador de Palafita", Color(0.5, 0.7, 0.4), ["Bibo pesca de cima da casa. Peixe sobe, Bibo desce a lança.", "Humano quer peixe? Bibo troca por coisa brilhante."],
			["Peixe! Peixe!", "Bibo viu primeiro!", "Hehehe."], [-92.0, 18.0], 2.0, {"if": Q_GOBLIN_BOSS, "model": "mob_goblin_lancer"}],
		"goblin_kid": ["Nhac", Color(0.55, 0.72, 0.42), ["Nhac nunca viu humano tão perto. Humano tem cheiro de sabão.", "Tum-Tum ensina Nhac a bater tambor. Sem guerra."],
			["Humano! Humano!", "Nhac corre mais!", "Bum, bum!"], [-88.0, 26.0], 4.0, {"if": Q_GOBLIN_BOSS, "model": "mob_goblin_lancer"}],
	},
	"dg_goblin": {
		"dgg_captive_a": ["Cativo Tadeu", Color(0.58, 0.52, 0.46), ["Eles nos pegaram na praia do Gaivota. Cavamos dia e noite atrás de pedra brilhante.", "O Agitador-Mor bate o tambor e os pequenos ficam loucos. Derrube o tambor."],
			["Mais pedra... mais pedra...", "Socorro! Aqui!", "Não olhe pra eles."], [-8.0, 22.0], [[-8.0, 22.0], [-18.0, 18.0], [-26.0, 12.0], [-18.0, 18.0]], {"unless": Q_GOBLIN_BOSS, "carry": "carry_rock"}],
		"dgg_captive_b": ["Cativa Celsa", Color(0.62, 0.55, 0.5), ["Cozinho pra eles. Eles comem tudo cru, mas querem que eu cozinhe. Goblin é assim.", "A saída é pelo norte. Eu sei. Eles sabem que eu sei."],
			["Mexe a panela...", "Só mais um pouco.", "Leve-nos daqui!"], [-34.0, -2.0], 1.0, {"unless": Q_GOBLIN_BOSS}],
		"dgg_captive_c": ["Cativo Abílio", Color(0.6, 0.5, 0.42), ["Ferreiro do Gaivota. Agora afio lança de goblin. Afio mal, de propósito.", "O salão do leste é dos orcs. Eles não deixam goblin entrar lá."],
			["Afio mal, afio mal...", "Psst! Aqui!", "Corrente pesada..."], [30.0, -16.0], 1.0, {"unless": Q_GOBLIN_BOSS}],
	},
	"field_steppe": {
		"steppe_vil_wheel": ["Rodeiro Fabrício", Color(0.6, 0.46, 0.32), ["Roda quebrada não espera a guerra acabar. Eu também não.", "Cada carroça desse anel é uma muralha. Cada roda, um portão."],
			["Toc, toc, toc...", "Raio novo, roda nova.", "Segura essa, menino!"], [-8.0, -7.0], 2.0, {}],
		"steppe_vil_cook": ["Cozinheira Benedita", Color(0.9, 0.76, 0.56), ["Ensopado de cabrito e capim de cinza. O capim é pra dar cor.", "Quem defende o vão come primeiro. Regra da caravana."],
			["Panela no fogo!", "Quem quer caldo?", "Sem lenha, sem comida!"], [10.0, 10.0], 2.0, {}],
		"steppe_vil_kid": ["Juju", Color(0.95, 0.7, 0.45), ["O Dinho deixou eu dar comida pro lobo dele. Ele lambeu minha mão inteira!", "Quando os trolls vêm, eu me escondo embaixo da carroça da Noêmia."],
			["Pega-pega!", "Eu vi um troll!", "Lobinho, lobinho!"], [-2.0, -6.0], 6.0, {}],
		"steppe_vil_washer": ["Lavadeira Sônia", Color(0.82, 0.8, 0.7), ["Água aqui vem do poço ou do céu. O céu anda mesquinho.", "Pano de Aldara, poeira de Kharzun. Nunca fica limpo."],
			["Poeira, sempre poeira...", "Mais um balde.", "Vento seca rápido, ao menos."], [-7.0, 9.0], 3.0, {}],
		"steppe_vil_clerk": ["Contadora Hilda", Color(0.7, 0.66, 0.8), ["Sal, pano, ferro, flecha. Anoto tudo que entra e tudo que a Horda leva.", "O Horácio manda. Eu conto. Quem conta, manda um pouco também."],
			["Doze sacos, treze barris...", "Isso não bate.", "Quem mexeu no meu livro?"], [4.0, -10.0], 2.0, {}],
		"steppe_caravan_a": ["Carroceiro Alcides", Color(0.62, 0.5, 0.36), ["Do passo da Costa até o Posto: meio dia, se o lobo deixar.", "Sal pra cá, ferro pra lá. A estrada é o que segura essa terra junta."],
			["Eia! Eia!", "Estrada ruim, carga boa.", "Mais um morro..."], [-15.0, 88.0], [[-15.0, 88.0], [-9.0, 82.0], [3.0, 70.0], [6.0, 60.0], [4.0, 48.0], [2.0, 32.0], [0.0, 14.0], [2.0, 32.0], [4.0, 48.0], [6.0, 60.0], [3.0, 70.0], [-9.0, 82.0]], {"carry": "cart"}],
		"steppe_caravan_b": ["Carroceira Nena", Color(0.7, 0.52, 0.4), ["Meu pai puxava carroça em Aldara. Eu puxo em Kharzun. A carroça é a mesma.", "Ouviu tambor, para. Ouviu uivo, corre."],
			["Segura a carga!", "Falta pouco pro Posto.", "Ê, burro teimoso!"], [2.0, 30.0], [[2.0, 30.0], [4.0, 48.0], [6.0, 60.0], [3.0, 70.0], [-9.0, 82.0], [-15.0, 88.0], [-9.0, 82.0], [3.0, 70.0], [6.0, 60.0], [4.0, 48.0], [2.0, 32.0], [0.0, 14.0]], {"carry": "cart"}],
		"steppe_caravan_guard": ["Escolta Rui", Color(0.6, 0.62, 0.7), ["Escolto a caravana da Costa até o Posto. Ida e volta, todo dia.", "Saqueador ataca a última carroça. Eu ando atrás."],
			["Caravana passando!", "Olho no capim!", "Mantenham a fila!"], [-9.0, 82.0], [[-9.0, 82.0], [3.0, 70.0], [6.0, 60.0], [4.0, 48.0], [2.0, 32.0], [4.0, 48.0], [6.0, 60.0], [3.0, 70.0], [-9.0, 82.0], [-15.0, 88.0]],
			{"fighter": "guard_spearman", "power": Balance.STEPPE_GUARD_POWER}],
		"steppe_vil_herder": ["Pastor Damião", Color(0.66, 0.58, 0.4), ["Cavalo de carroça precisa de capim. Capim bom só aqui, entre o Posto e o rio.", "Se os cavalos correm, eu corro atrás. Se correm pro rio, rezo."],
			["Ê, ê, cavalinho!", "Fica junto!", "Assobio... fiu-fiu!"], [-28.0, 22.0], 6.0, {}],
		"steppe_horse_a": ["Cavalo da Caravana", Color(0.55, 0.4, 0.28), ["(O cavalo bufa e volta a pastar.)", "(Ele mastiga capim de cinza com cara de quem já comeu coisa melhor.)"],
			[], [-25.0, 25.0], 5.0, {"model": "mob_horse"}],
		"steppe_horse_b": ["Égua Malhada", Color(0.75, 0.7, 0.62), ["(A égua sacode a crina e encosta o focinho na sua mão.)", "(Ela não liga para a guerra. Liga para o capim.)"],
			[], [-32.0, 18.0], 5.0, {"model": "mob_horse"}],
		"steppe_horse_c": ["Potro", Color(0.45, 0.32, 0.22), ["(O potro corre em volta da égua e para, curioso, olhando você.)"],
			[], [-29.0, 27.0], 6.0, {"model": "mob_horse"}],
		# rebanho do pastor (mob_kit quadruped "sheep"/"goat"): pasta ao lado dos cavalos da caravana
		"steppe_sheep_a": ["Ovelha", Color(0.94, 0.92, 0.86), ["(A ovelha mastiga devagar e olha através de você.)", "(Lã cheia de poeira de cinza. Ela não parece se importar.)"],
			[], [-34.0, 26.0], 4.0, {"model": "mob_sheep"}],
		"steppe_sheep_b": ["Ovelha Velha", Color(0.9, 0.88, 0.82), ["(Ela bale uma vez, rouca, e volta ao capim.)"],
			[], [-37.0, 21.0], 4.0, {"model": "mob_sheep"}],
		"steppe_sheep_c": ["Ovelha", Color(0.94, 0.92, 0.86), ["(A ovelha se afasta dois passos e continua pastando, de olho em você.)"],
			[], [-31.0, 30.0], 4.0, {"model": "mob_sheep"}],
		"steppe_goat_a": ["Cabra da Benedita", Color(0.8, 0.74, 0.64), ["(A cabra tenta comer a ponta do seu cinto.)", "(Ela encara você com a calma de quem já fugiu de troll.)"],
			[], [-24.0, 19.0], 5.0, {"model": "mob_goat"}],
		"steppe_goat_b": ["Cabrito", Color(0.84, 0.78, 0.68), ["(O cabrito dá uma cabeçada de leve no seu joelho e sai pulando.)"],
			[], [-27.0, 16.0], 6.0, {"model": "mob_goat"}],
		"deserter_vil_a": ["Desertor Mug", Color(0.5, 0.6, 0.42), ["Mug carregou estandarte de Ghar dez invernos. Estandarte pesa menos que vergonha.", "Humano olha torto pra Mug. Justo. Mug olhava torto pra humano."],
			["Hmpf.", "Mug afia machado. Só por costume.", "Fogo bom hoje."], [-40.0, -84.0], 3.0, {"unless": Q_DESERTERS_TURN, "model": "mob_orc_recruit"}],
		"deserter_vil_b": ["Desertora Shara", Color(0.52, 0.62, 0.44), ["Shara cozinha para quem largou a Horda. Panela grande, poucos dentes.", "Do leste vem um frio que não é inverno. Os velhos sabem. Os velhos fugiram primeiro."],
			["Come, come.", "Carne seca de novo...", "Shara ouve tambor longe."], [-33.0, -86.0], 2.0, {"unless": Q_DESERTERS_TURN, "model": "mob_orc_recruit"}],
		"deserter_vil_c": ["Pip, o Goblin Fugido", Color(0.55, 0.72, 0.4), ["Pip fugiu do Agitador. Agitador grita, Pip não gosta de grito.", "Orc grande dá comida pra Pip. Orc grande é bom. Às vezes."],
			["Pip não fez nada!", "Hehe, brilhante!", "Pip vigia, Pip vigia."], [-38.0, -78.0], 4.0, {"unless": Q_DESERTERS_TURN, "model": "mob_goblin_lancer"}],
		"deserter_wolf_a": ["Lobo de Montaria", Color(0.45, 0.42, 0.4), ["(O lobo rosna baixinho, depois boceja e deita de novo.)"],
			[], [-42.0, -74.0], 3.0, {"if": Q_DESERTERS_HELP, "model": "mob_wolf"}],
		"deserter_wolf_b": ["Loba Cinzenta", Color(0.55, 0.52, 0.5), ["(A loba fareja seu cinto. Você tinha carne seca. Tinha.)"],
			[], [-44.0, -78.0], 3.0, {"if": Q_DESERTERS_HELP, "model": "mob_wolf"}],
	},
}

## Acampamentos da Horda (fort_trolls/fire/war): cativos que carregam antes da retomada; a vida da Aurora depois.
## Mesmo formato de LIVING_NPCS; `pre` vale `unless` a quest do acampamento e `post` vale `if` (FORT_DEFS).
const FORT_LIFE := {
	"fort_trolls": {
		"pre": {"captive_a": ["Cativo Lauro", Color(0.6, 0.55, 0.48), ["Pedra pra cá, pedra pra lá. O Rei-da-Rocha quer um trono maior.", "Troll não dorme. Só fecha os olhos e escuta."], ["Mais pedra...", "Me tirem daqui!", "Calado, calado..."], [-16.0, 4.0], [[-16.0, 4.0], [-20.0, -2.0], [-28.0, -4.0], [-20.0, -2.0]], {"carry": "carry_rock"}],
			"captive_b": ["Cativa Odete", Color(0.66, 0.56, 0.5), ["Eles nos fazem rolar as pedras até a boca da caverna. O grandão empilha.", "O fogo das tochas espanta os pequenos. Pena que eles apagam."], ["Ai, minhas mãos.", "Ele está olhando...", "Mais uma, só mais uma."], [-14.0, 6.0], [[-14.0, 6.0], [-8.0, 2.0], [-14.0, -2.0], [-8.0, 2.0]], {}]},
		"post": {"sapper": ["Sapadora Joana", Color(0.7, 0.6, 0.45), ["Desmonto o trono de pedra do Rei. Vira muro no Posto, pedra por pedra.", "Cuidado onde pisa: troll esconde osso até debaixo da terra."], ["Martelo e cunha!", "Essa pedra é minha.", "Um trono a menos."], [-14.0, 4.0], [[-14.0, 4.0], [-26.0, 4.0], [-26.0, -6.0], [-14.0, -4.0]], {}],
			"cook": ["Cozinheiro Dimas", Color(0.88, 0.76, 0.56), ["Caldo de raiz e pão duro. Na Toca, é banquete.", "O primeiro prato é dos que ficaram presos aqui. Depois, os soldados."], ["Caldo quente!", "Fila, fila!", "Tem mais pão ali."], [-18.0, -4.0], 2.0, {}],
			"wounded": ["Soldado Ferido Neto", Color(0.6, 0.6, 0.7), ["Uma pedra de trollzinho na cabeça. Pequeno, mas mira bem.", "A Dalva amolou minha espada com pedra de troll. Agora ela corta até vergonha."], ["Ai, a cabeça...", "Tô bem, tô bem.", "Viva a Aurora!"], [-8.0, -12.0], 1.0, {}],
			"watch_a": ["Sentinela Barros", Color(0.62, 0.62, 0.72), ["Ronda da Toca. Troll que volta, encontra lança.", "Os do Cemitério dos Mamutes farejam a gente. Que farejem."], ["Toca segura!", "Olho na caverna!", "Ronda!"], [-6.0, 4.0], [[-6.0, 4.0], [-20.0, 4.0], [-34.0, 4.0], [-20.0, 4.0]], {"fighter": "guard_spearman"}],
			"watch_b": ["Sentinela Vilma", Color(0.62, 0.62, 0.72), ["Do alto da pedra se vê a ponte da fenda. Ninguém cruza sem eu ver.", "Fogo nas tochas, sempre. Troll odeia."], ["Nada na ponte.", "Tocha acesa!", "Ronda!"], [-8.0, -2.0], [[-8.0, -2.0], [-22.0, -2.0], [-34.0, -2.0], [-22.0, -2.0]], {"fighter": "guard_crossbow"}]},
	},
	"fort_fire": {
		"pre": {"captive_a": ["Cativo Hélio", Color(0.6, 0.55, 0.48), ["Eu carrego o carvão dos braseiros. Eles acendem as flechas no fogo que eu carrego.", "O Mestre Besteiro treina mira nas carroças. Às vezes, em nós."], ["Carvão, mais carvão...", "Queima! Queima a mão!", "Não atirem!"], [20.0, -4.0], [[20.0, -4.0], [14.0, 6.0], [10.0, 14.0], [14.0, 6.0]], {"carry": "carry_sack"}],
			"captive_b": ["Cativa Dora", Color(0.66, 0.56, 0.5), ["Emplumo flecha pra orc. Pena de corvo, cola de osso.", "Se eu emplumar torto, a flecha erra. Eu emplumo torto."], ["Pena, cola, pena...", "Torto, bem torto.", "Socorro..."], [24.0, -2.0], 1.5, {}]},
		"post": {"sapper": ["Sapador Ivo", Color(0.7, 0.6, 0.45), ["Apago braseiro por braseiro. Carvão bom vai pro ferreiro.", "Cinza da Paliçada vai adubar a horta do Posto."], ["Água no braseiro!", "Cinza pra todo lado...", "Um fogo a menos."], [6.0, 10.0], [[6.0, 10.0], [16.0, 14.0], [22.0, 6.0], [14.0, 8.0]], {}],
			"cook": ["Cozinheira Lena", Color(0.88, 0.76, 0.56), ["Assado no braseiro dos orcs. Ironia tem gosto bom.", "Coma antes que esfrie. Aqui nada esfria, na verdade."], ["Assado na brasa!", "Prato quente!", "Sobrou pra você."], [4.0, 14.0], 2.0, {}],
			"wounded": ["Arqueira Ferida Cida", Color(0.6, 0.6, 0.7), ["Flecha de fogo no braço. Queima duas vezes: quando entra e quando tira.", "O Simão disse que eu mirei melhor que ele. Ele mente bem."], ["Arde...", "Já, já eu volto.", "Saia do círculo!"], [8.0, 20.0], 1.0, {}],
			"watch_a": ["Sentinela Couto", Color(0.62, 0.62, 0.72), ["Ronda da Paliçada. Da torre deles a estrada do sudeste é nossa.", "As flechas de fogo que sobraram, eu guardo pra Horda."], ["Paliçada segura!", "Olho na estrada!", "Ronda!"], [8.0, 8.0], [[8.0, 8.0], [24.0, 6.0], [40.0, 10.0], [24.0, 6.0]], {"fighter": "guard_spearman"}],
			"watch_b": ["Sentinela Rosa", Color(0.62, 0.62, 0.72), ["Virote frio vale mais que flecha de fogo. Não espalha, mas acerta.", "Daqui eu vejo a fumaça das Estepes."], ["Nada à vista.", "Virote pronto!", "Ronda!"], [8.0, 14.0], [[8.0, 14.0], [12.0, 32.0], [28.0, 33.0], [12.0, 32.0]], {"fighter": "guard_crossbow"}]},
	},
	"fort_war": {
		"pre": {"captive_a": ["Cativo Mauro", Color(0.6, 0.55, 0.48), ["Ghar faz a gente varrer a arena antes da luta. Depois, a gente varre a gente.", "Os Agitadores batem o tambor e os orcs gritam. Ninguém dorme no Arraial."], ["Varre, varre...", "Não quero lutar!", "Shhh, o tambor."], [6.0, -20.0], [[6.0, -20.0], [4.0, -12.0], [12.0, -8.0], [4.0, -12.0]], {}],
			"captive_b": ["Cativa Inês", Color(0.66, 0.56, 0.5), ["Remendo couro de lobo pros ginetes. A agulha é de osso. De quem, eu não pergunto.", "A tenda vermelha tem cheiro de ferro. Ghar dorme de armadura."], ["Agulha, linha...", "Socorro!", "Ele vem aí."], [7.0, -25.0], 1.5, {}]},
		"post": {"sapper": ["Sapador Tonho", Color(0.7, 0.6, 0.45), ["Desmonto a arena do Ghar. Madeira boa, sangue velho.", "A tenda vermelha virou enfermaria. Ghar odiaria. Por isso ficou bonito."], ["Tábua solta!", "Mais um poste...", "Arena fechada!"], [16.0, -10.0], [[16.0, -10.0], [30.0, -10.0], [34.0, -18.0], [20.0, -18.0]], {}],
			"cook": ["Cozinheiro Gaspar", Color(0.88, 0.76, 0.56), ["Os orcs deixaram um caldeirão do tamanho de um barco. Cabe o Arraial inteiro.", "Carne de javali da estepe. Ou de algo parecido."], ["Caldeirão cheio!", "Venha, venha!", "Ninguém fica com fome."], [20.0, 2.0], 2.0, {}],
			"wounded": ["Escudeiro Ferido Téo", Color(0.6, 0.6, 0.7), ["O Capitão Otávio me carregou nas costas na retomada. Agora eu carrego o escudo dele.", "Ghar bate como uma porta caindo. Eu sei. Fui a porta."], ["Ai...", "Já tô de pé!", "Pela Aurora!"], [14.0, 6.0], 1.0, {}],
			"watch_a": ["Sentinela Prates", Color(0.62, 0.62, 0.72), ["Ronda do Arraial. O passo da montanha está logo ali, e lá a Horda junta força.", "Tambor longe? É vento. Tambor perto? Grite."], ["Arraial seguro!", "Olho no passo!", "Ronda!"], [6.0, -4.0], [[6.0, -4.0], [16.0, -14.0], [36.0, -12.0], [16.0, -14.0]], {"fighter": "guard_knight"}],
			"watch_b": ["Sentinela Duda", Color(0.62, 0.62, 0.72), ["Do lado de cá a estrada desce pras Estepes. Os reforços vêm por ela.", "Ghar caiu, mas o Grão-Senhor não."], ["Nada no passo.", "Reforços na estrada!", "Ronda!"], [6.0, 0.0], [[6.0, 0.0], [22.0, 0.0], [40.0, 0.0], [22.0, 0.0]], {"fighter": "guard_spearman"}]},
	},
}

## Rondas de monstro que não vêm do JSON (Blender): mapa -> [[monstro, x, z, raio, quantos, respawn, rota [[x, z]...], unless]].
## Bando pequeno que anda entre salões/postos: o lugar não fica parado esperando o jogador.
const MOB_PATROLS := {
	"dg_goblin": [["goblin_lancer", 0.0, 25.0, 3.0, 2, 30.0, [[0.0, 25.0], [-19.0, 18.0], [-36.0, -2.0], [-18.0, -2.0], [1.0, -2.0], [-18.0, -2.0], [-36.0, -2.0], [-19.0, 18.0]], ""]],
	"fort_trolls": [["troll_whelp", 26.0, 3.0, 3.0, 2, 30.0, [[26.0, 3.0], [36.0, -11.0], [53.0, -14.0], [64.0, -4.0], [53.0, -14.0], [36.0, -11.0]], Q_FORT_TROLLS]],
	"fort_fire": [["orc_archer", -36.0, -20.0, 3.0, 2, 30.0, [[-36.0, -20.0], [-31.0, -10.0], [-17.0, -11.0], [-5.0, -8.0], [-17.0, -11.0], [-31.0, -10.0]], Q_FORT_FIRE]],
	"fort_war": [["orc_warrior", -39.0, 20.0, 3.0, 2, 30.0, [[-39.0, 20.0], [-35.0, 8.0], [-21.0, 8.0], [-7.0, 7.0], [-21.0, 8.0], [-35.0, 8.0]], Q_FORT_WAR]],
}

## Falas soltas (barks) de NPCs que já existiam: id -> falas curtas que aparecem sobre a cabeça quando o jogador passa.
const BARKS := {
	"port_governor": ["Mais estacas no norte!", "Porto Esperança não cai.", "Alguém viu o Bruno?"],
	"port_sailor": ["O navio sai quando você pisar.", "Vento bom hoje!"],
	"port_merchant": ["Poção nova do último navio!", "Ataduras, ataduras!"],
	"port_vil_builder": ["Mais uma estaca!", "Segura firme aí!", "Faltam trezentas..."],
	"port_vil_fisher": ["Peixe bravo, esse!", "Devolve minha rede, naga!"],
	"port_vil_kid": ["Eu vi um goblin!", "Corre, Belinha!"],
	"port_vil_nurse": ["Próximo!", "Morde a tira e aguenta."],
	"port_vil_porter": ["Caixa pro mercado!", "Minhas costas..."],
	"port_vil_monk": ["A Luz atravessou o mar.", "Paz a quem chega."],
	"coast_scout": ["Estrada livre por ora.", "Olho no farol!"],
	"coast_farmer_a": ["Nabo novo!", "Sai, corvo!"],
	"coast_farmer_b": ["Terra boa!", "Mais um sulco."],
	"goblin_nikki": ["Nikki vende! Nikki vende!", "Coisa brilhante? Nikki compra!"],
	"goblin_villager_a": ["Gobo pesca!", "Peixe pra todo mundo!"],
	"goblin_villager_b": ["Silêncio bom...", "Orc volta. Sempre volta."],
	"goblin_drummer": ["Bum, bum, bum!", "Tambor de feira!"],
	"coast_survivor_lia": ["Ensopado!", "Quem reclamar lava a panela!"],
	"coast_pearl_diver": ["Lá vou eu!", "Maré boa pra mergulho."],
	"caravan_master": ["Caravana não para!", "Escolha um lado e vá!"],
	"steppe_merchant": ["Corda, poção, atadura!", "O que a Horda não levou!"],
	"deserter_chief": ["Urzog não volta.", "O leste empurra."],
	"deserter_wolf_keeper": ["Lobo come primeiro.", "Quieto, lobo."],
	"caravan_trader": ["Sal do porto!", "Notícia fresca, de graça!"],
	"wind_shaman": ["O vento fala...", "Não diga o nome."],
}
## Prisioneiros e colonos dos acampamentos (FORT_NPCS): barks por papel.
const FORT_BARKS := {"prisoner": ["Tirem a gente daqui!", "Ele está vindo...", "Por favor..."],
	"settler": ["Pela Aurora!", "O acampamento é nosso.", "Mais um posto pra caravana."]}

static func _route_of(r: Variant) -> Variant:
	if r is Dictionary and (r as Dictionary).has("ring"):
		var g: Array = r["ring"]
		var a0 := deg_to_rad(float(g[4]))
		var pts: Array = []
		for i in int(g[3]):
			var a := a0 + i * TAU / float(g[3])
			pts.append([snappedf(float(g[0]) + cos(a) * float(g[2]), 0.1), snappedf(float(g[1]) + sin(a) * float(g[2]), 0.1)])
		return pts
	return r

## Linhas de LIVING_NPCS/FORT_LIFE prontas para o MapDef (`prefix` no id; `cond` = {if/unless} herdado).
static func living_npcs(table: Dictionary, prefix: String = "", cond: Dictionary = {}) -> Array:
	var out: Array = []
	var seed := 900 + prefix.length() * 31
	for vid in table:
		var v: Array = table[vid]
		var ex: Dictionary = v[6]
		var fighter := str(ex.get("fighter", ""))
		var d := _npc(prefix + vid, v[0], float(v[4][0]), float(v[4][1]), "guard" if fighter != "" else str(ex.get("role", "villager")), v[1], v[2],
			float(ex.get("facing", (seed * 47) % 360)))
		var r: Variant = _route_of(v[5])
		if r is Array:
			d["route"] = r
		else:
			d["wander"] = float(r)
		if not (v[3] as Array).is_empty():
			d["barks"] = v[3]
		for k in ["if", "unless", "model", "power", "carry"]:
			if ex.has(k):
				d[k] = ex[k]
		for k in cond:
			d[k] = cond[k]
		if fighter != "":
			d["fighter"] = fighter
			d["respawn"] = FORT_RESPAWN
			var mdef: MonsterDef = GameData.monsters.get(fighter)
			if mdef != null and not d.has("model"):
				d["model"] = mdef.model
		d["look_seed"] = seed
		seed += 7
		out.append(d)
	return out

## Barks dos NPCs que já existiam (BARKS e, nos acampamentos, prisioneiros/colonos por papel).
static func _apply_barks(npcs: Array) -> void:
	for n in npcs:
		var nid: String = n.get("id", "")
		if BARKS.has(nid) and not n.has("barks"):
			n["barks"] = BARKS[nid]
		elif nid.begins_with("fort_") and not n.has("barks"):
			for role in FORT_BARKS:
				if nid.contains("_%s_" % role):
					n["barks"] = FORT_BARKS[role]

## Rondas de monstro de MOB_PATROLS como spawners (mesmo formato do JSON).
static func mob_patrols(id: String) -> Array:
	var out: Array = []
	for p in MOB_PATROLS.get(id, []):
		var sp := _sp(mob(p[0]), float(p[1]), float(p[2]), float(p[3]), int(p[4]), float(p[5]) * Balance.SPAWN_RESPAWN_MULT)
		sp["route"] = (p[6] as Array).map(func(q): return Vector3(float(q[0]), 0.0, float(q[1])))
		if str(p[7]) != "":
			sp["unless"] = p[7]
		out.append(sp)
	return out

## Capitão Bren (cais leste do Bastião): fica ao lado do portal com portão `to_city_port`.
const BREN := ["Capitão Bren", "villager", Color(0.45, 0.5, 0.7), ["O Gaivota afundou, mas o Andorinha cruza. Kharzun fica a um dia de vento.", "Pise no cais e zarpamos. Só levo quem terminou o que começou em Aldara."]]

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
	# Porto Esperança (Ato II): os ginetes descem a garganta nordeste (rotas cerco/muralha/patrulha = C0/C1/C3)
	"city_port": PORT_RAIDS,
	# Estepes de Cinza (Ato II): três lados, regra do Bastião
	"field_steppe": STEPPE_RAIDS,
	# Bastião da Aurora: três fronts, cada um com a leva do seu lado (a rota é calada pela quest do chefe da fortaleza)
	"field_ruins": {
		"ghoul": {"every": 200.0, "first": 70.0, "jitter": 40.0, "lifetime": 200.0,
			"waves": [{"mobs": {"larva": 26, "rot_zombie": 12, "rot_ghoul": 8, "rot_wolf": 4}}, {"mobs": {"rot_bear": 2}, "every_nth": 2}],
			"say_start": "O pântano do oeste se mexe: a ninhada do Carniçal marcha contra o Bastião!",
			"say_arrived": "Os mortos do Carniçal chegaram ao portão oeste!",
			"say_repelled": "A investida do Carniçal foi queimada no portão oeste!",
			"say_retreat": "A ninhada recua para o pântano.",
			"reclaim_extra": {1: {"rot_bear": 2}, 2: {"citadel_horror": 2}},
			"say_reclaim": "O pântano ferve de raiva pelas fortalezas perdidas: a ninhada vem maior!",
			"leader": "citadel_horror", "say_leader": "Um Horror da Cidadela lidera a ninhada: o último front do Carniçal vem com tudo!"},
		"bones": {"every": 230.0, "first": 140.0, "jitter": 40.0, "lifetime": 210.0,
			"waves": [{"mobs": {"skeleton": 12, "skel_archer": 8, "skel_guard": 5}}],
			"say_start": "Tambores de osso ao norte: a legião da Fortaleza dos Ossos marcha!",
			"say_arrived": "Os esqueletos chegaram ao portão norte! Escudos à frente!",
			"say_repelled": "A legião dos ossos foi quebrada no portão norte!",
			"say_retreat": "Os esqueletos recuam em fileira para o norte.",
			"reclaim_extra": {1: {"skel_guard": 2}, 2: {"citadel_knight": 2}},
			"say_reclaim": "Os tambores de osso batem mais forte: a legião vem maior pelas fortalezas perdidas!",
			"leader": "citadel_knight", "say_leader": "Um Guarda da Cidadela comanda a legião: o último front dos Ossos vem com tudo!"},
		"frost": {"every": 260.0, "first": 210.0, "jitter": 40.0, "lifetime": 210.0,
			"waves": [{"mobs": {"cultist": 7, "tower_bat": 8, "ghost": 6, "citadel_adept": 4}}, {"mobs": {"citadel_knight": 2}, "every_nth": 2}],
			"say_start": "Um vento gelado vem do sul: os adeptos da Torre marcham com morcegos e espectros!",
			"say_arrived": "Os adeptos chegaram ao portão sul!",
			"say_repelled": "O frio recua: o portão sul resistiu!",
			"say_retreat": "Os adeptos recuam para a Torre.",
			"reclaim_extra": {1: {"citadel_adept": 2}, 2: {"citadel_knight": 2}},
			"say_reclaim": "O frio do sul fica cruel: a Torre manda mais adeptos pelas fortalezas perdidas!",
			"leader": "citadel_adept", "say_leader": "Um Adepto da Cidadela conduz a nevasca: a Torre joga tudo no último front!"},
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
	"field_coast": {
		"castaway_tomas": ["Tomás, o Náufrago", "quest", Color(0.62, 0.55, 0.42), ["O Gaivota afundou a meio dia do porto. Eu nadei. Os outros... ainda estão na praia, de um jeito ou de outro.", "As nagas sobem com a maré. Ataque quando a água recua."]],
		"keeper_ilda": ["Ilda, a Faroleira", "quest", Color(0.85, 0.82, 0.75), ["O farol está apagado desde que os goblins levaram o óleo. Sem luz, navio nenhum acha a baía.", "Do alto da torre eu via a Horda inteira descendo a montanha. Agora não vejo nada."]],
		"drowned_altar": ["Santuário Afogado", "board", Color(0.6, 0.72, 0.75), ["Pedra da Aurora, mais velha que o porto. A maré cobre o altar duas vezes por dia.", "Gravado em letra antiga: 'Quem chegou primeiro por mar não voltou'."], "prop_statue"],
	},
	"field_steppe": {
		"ivory_hunter": ["Sabá, a Caçadora de Marfim", "quest", Color(0.86, 0.8, 0.62), ["Os mamutes vinham morrer aqui muito antes da Horda. Os trolls só vieram roer o que sobrou.", "Presa inteira vale uma carroça. Presa roída vale um cabo de faca."]],
		"wolf_racer": ["Dinho, o Corredor de Lobos", "quest", Color(0.62, 0.56, 0.44), ["Peguei um filhote dos saqueadores. Agora ele corre para mim, não para eles.", "Daqui ao Totem e de volta antes do sol mexer: essa é a corrida."]],
		"wind_totem": ["Totem dos Ventos", "board", Color(0.6, 0.78, 0.78), ["Um toco entalhado ao pé do Totem Partido. O vento assobia pelos olhos dele.", "Riscado na madeira, em orc antigo: 'O que quebrou o grande veio do leste'."], "prop_statue"],
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
	"dg_goblin": {"name": "Grutas Goblin", "parent": "field_coast", "levels": Vector2i(32, 35), "ground": Color(0.34, 0.32, 0.24), "ambient": Color(0.85, 0.7, 0.6), "sun": 0.65},
}
## Portões de progressão por id de portal (só o jogador; ver WorldSim.portal_block_reason). `bosses` = selo: save antigo não abre.
const PORTAL_GATES := {
	"to_dg_catacumbas": {"level": 8, "quest": "c1_digging", "text": "Catacumbas: a entrada ainda está soterrada. Fale com o Ancião Ravi."},
	"to_dg_catacumbas_trono": {"bosses": ["bone_captain", "wailing_widow"], "text": "O selo só cede quando o Capitão de Ossos e a Viúva Lamentosa caírem."},
	"to_dg_pedreira_coracao": {"bosses": ["golem_ancient", "crystal_warden"], "text": "O veio está fechado: o Golem Ancestral e a Guardiã de Cristal ainda montam guarda."},
	"to_forest": {"level": 10, "quest": "c5_report", "text": "O desfiladeiro está fechado por ordem da Capitã Mira até resolverem as Catacumbas."},
	"to_ruins": {"level": 20, "quest": "el6_king", "text": "A passagem está vigiada: enquanto o Rei Élfico atacar a Floresta, a guarda não libera o caminho do Bastião."},
	"to_fort_ghoul": {"level": 20, "quest": "dw_gates", "text": "O Marechal Aldric só abre o portão oeste para quem já segurou os portões do Bastião."},
	"to_fort_bones": {"level": 21, "quest": "dw_ghoul_boss", "text": "A Fortaleza dos Ossos: só com o Covil do Carniçal retomado a Aurora tem soldados para subir."},
	"to_fort_frost": {"level": 23, "quest": "dw_bones_boss", "text": "A Torre do Mago: primeiro a Fortaleza dos Ossos tem de cair."},
	"to_lich_citadel": {"level": 27, "quest": "dw_frost_boss", "text": "O selo da Cidadela só cede quando as três fortalezas forem da Aurora."},
	"to_elf_city": {"level": 16, "text": "A garganta élfica: a Comandante Hela só deixa passar quem tem nível 16."},
	# Ato II: o navio do Capitão Bren só zarpa para Kharzun depois do epílogo do Ato I (a volta não tem portão)
	"to_city_port": {"level": 30, "quest": ACT_END_QUEST, "text": "Termine o que começou em Aldara. O Capitão Bren só zarpa com quem fechou a história do Lich."},
	# Estepes de Cinza: a passagem abre em C4 (Agitador-Mor). Os acampamentos valem em qualquer ordem: só nível.
	"to_field_steppe": {"level": 35, "quest": Q_GOBLIN_BOSS, "text": "A garganta das Estepes está fechada por estacas da Horda. Enquanto o Agitador-Mor bater o tambor nas Grutas, ninguém passa."},
	"to_fort_trolls": {"level": 35, "text": "A Toca do Rei-da-Rocha: o Mestre da Caravana só deixa subir quem tem nível 35."},
	"to_fort_fire": {"level": 36, "text": "A Paliçada das Flechas de Fogo: o Mestre da Caravana só deixa subir quem tem nível 36."},
	"to_fort_war": {"level": 37, "text": "O Arraial de Ghar: o Mestre da Caravana só deixa subir quem tem nível 37."},
	# E5 Caminho da montanha: os três acampamentos retomados (`quests` = todas, qualquer ordem). O portal `to_field_kharzun`
	# ainda não existe (data/zones/field_steppe.json, chave future_portals): ganha este portão quando field_kharzun existir.
	"to_field_kharzun": {"level": 40, "quests": Q_STEPPE_FORTS, "text": "O caminho da montanha segue fechado: a Horda ainda segura acampamentos na estepe. Retome os três antes de subir para Kharzun."},
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
		for k in ["if", "unless"]:          # conquista (WorldState): prop sem colisão que o jogo mostra/esconde, ou colisor do estágio (solid)
			if o.has(k):
				d[k] = o[k]
		obs.append(d)
	if CRYSTALS.has(id):                  # cristal de retorno: coluna sólida invisível (o visual é o prop do NPC)
		var cp: Array = CRYSTALS[id]
		var c := _ob("pillar", float(cp[0]), float(cp[1]), 1.1, 2.6, 1.1, C_STONE, 0.0, true)
		c["hidden"] = true
		obs.append(c)
	var portals: Array = []
	for p in z["portals"]:
		var label: String = p["label"]
		if p["target_map"] == "field_ruins" and label.begins_with("Ruínas"):
			label = "Bastião da Aurora (Lv 20-30)"     # as Ruínas viraram o Bastião (o JSON de Aldara guarda o nome antigo)
		portals.append(_portal(p["id"], float(p["pos"][0]), float(p["pos"][1]), p["target_map"], float(p["target_pos"][0]), float(p["target_pos"][1]), label))
		if PORTAL_GATES.has(p["id"]):
			portals[-1]["gate"] = PORTAL_GATES[p["id"]]
	var spawners: Array = []
	var dense: float = Balance.SPAWN_COUNT_MULT_DUNGEON if id.begins_with("dg_") else Balance.SPAWN_COUNT_MULT
	for s in z["spawners"]:
		var n := int(s["count"])
		if n > 1:              # chefe único (count 1) continua único
			n = int(round(n * dense))
		spawners.append(_sp(mob(s["monster_id"]), float(s["pos"][0]), float(s["pos"][1]), float(s["radius"]), n, float(s["respawn"]) * Balance.SPAWN_RESPAWN_MULT))
		if s.has("emerge"):            # chefe que sai da água: [x, z, raio] do lago
			spawners[-1]["emerge"] = s["emerge"]
		if s.has("route"):             # ronda: o líder (e a escolta dele) percorre estes pontos
			spawners[-1]["route"] = (s["route"] as Array).map(func(q): return _v3(q))
		for k in ["if", "unless"]:     # conquista (WorldState): spawner que só vale antes/depois de uma quest
			if s.has(k):
				spawners[-1][k] = s[k]
	spawners.append_array(mob_patrols(id))   # rondas de monstro do catálogo (MOB_PATROLS)
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
			if w.has("shore"):           # mar (Ato II): faixa de areia sem grama
				water[-1]["shore"] = float(w["shore"])
		else:
			water.append({"kind": w["kind"], "w": float(w["w"]), "pts": _pts(w["pts"])})
		if w.has("material"):
			water[-1]["material"] = str(w["material"])
	var water_tints := {}                  # água com cor própria da zona (mangue): material -> cor do Blender
	for k in z.get("water_tints", {}):
		water_tints[str(k)] = _col(z["water_tints"][k], Color.WHITE)
	var raid := {}
	if z.has("raid"):                  # investida: rota do JSON (Blender) + levas e falas daqui (RAIDS)
		var r: Dictionary = z["raid"]
		raid = _mob_raid(RAIDS.get(id, {}).duplicate(true))
		raid["from"] = _v3(r["from"])
		raid["target"] = _v3(r["target"])
		raid["radius"] = float(r["radius"])
		raid["route"] = (r["route"] as Array).map(func(q): return _v3(q))
	var raids: Array = []
	for r in z.get("raids", []):       # cidade atacada por vários lados: uma rota por lado, levas em RAIDS[<mapa>][<lado>]
		var d: Dictionary = _mob_raid((RAIDS.get(id, {}) as Dictionary).get(str(r["side"]), {}).duplicate(true))
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
		"roads": roads, "water": water, "water_tints": water_tints, "model": "map_" + id, "places": places}

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
	npcs.append_array(festival("city_aldara"))
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
	var extra := _place_npcs("field_ruins", z["npc_pos"]) + dawn_services(z["npc_pos"]) + dawn_garrison(z["npc_pos"]) + crystal_npc("field_ruins") + festival("field_ruins")
	var bp: Array = z["npc_pos"].get("port_captain_bren", [0.0, 0.0, 180.0])
	extra.append(_npc("port_captain_bren", BREN[0], float(bp[0]), float(bp[1]), BREN[1], BREN[2], BREN[3], float(bp[2])))
	z.erase("npc_pos")
	z.merge({
		"id": "field_ruins", "name": "Bastião da Aurora", "is_town": false, "hub": true, "level_range": Vector2i(20, 30), "sortie": SORTIES["field_ruins"],
		"conquest_vis": DAWN_CONQUEST_VIS,
		"ground_color": Color(0.55, 0.56, 0.46), "ground_color_alt": Color(0.5, 0.52, 0.43), "ambient": Color(0.78, 0.78, 0.86), "sun_energy": 0.9,
		"bot_population": 6,
		"npcs": [_npc("ruins_scholar", "Erudita Senna", float(p[0]), float(p[1]), "quest", Color(0.8, 0.75, 0.9),
			["Estudo os mortos para a Alta Sacerdotisa. Cada fortaleza tem um senhor, e cada senhor um ponto fraco.",
			"A cripta ao norte é mais velha que a cidade. O Senhor dela ainda dá ordens lá embaixo."], float(p[2]))] + extra,
	})
	return _mk(z)

# ---------------------------------------------------------------------------
## Porto Esperança (Ato II): tools/blender/zones/build_city_port.py. Hub da Costa: cristal, serviços, taverna que abre,
## navio de volta ao Bastião (portal sem portão), investida dos ginetes por estágio (C0 cerco, C1 muralha, C3 patrulha).
static func _port() -> MapDef:
	var z := load_zone("city_port")
	var npc_pos: Dictionary = z["npc_pos"]
	var npcs: Array = []
	for nid in PORT_NPCS:
		var n: Array = PORT_NPCS[nid]
		var ex: Dictionary = n[4]
		var p: Array = npc_pos.get(nid, [0.0, 0.0, 180.0])
		var d := _npc(nid, n[0], float(p[0]), float(p[1]), n[1], n[2], n[3], float(p[2]),
			MERCHANT_SHOP + GearCatalog.shop_ids() + GearCatalog.starter_weapon_ids(GameData.items) if ex.get("shop", "") == "merchant" else [])
		if ex.has("if"):
			d["if"] = ex["if"]
		npcs.append(d)
	for nid in PORT_EXTRA_NPCS:                           # mestres de ascensão e o memorial
		var n: Array = PORT_EXTRA_NPCS[nid]
		var ex: Dictionary = n[7]
		var d := _npc(nid, n[0], float(n[4]), float(n[5]), n[1], n[2], n[3], float(n[6]))
		if ex.has("if"):
			d["if"] = ex["if"]
		if ex.has("model"):
			d["model"] = ex["model"]
		d["look_seed"] = 500 + nid.length() * 11
		npcs.append(d)
	for d in dawn_garrison(npc_pos, "port_g_"):           # guarnição: Balance.PORT_GUARD_POWER
		if not is_equal_approx(Balance.PORT_GUARD_POWER, 1.0):
			d["power"] = Balance.PORT_GUARD_POWER
		npcs.append(d)
	for d in dawn_garrison(npc_pos, "port_w_"):           # C1: besteiros no muro novo
		d["if"] = Q_PALISADE
		if not is_equal_approx(Balance.PORT_GUARD_POWER, 1.0):
			d["power"] = Balance.PORT_GUARD_POWER
		npcs.append(d)
	npcs.append_array(villagers(PORT_VILLAGERS))
	npcs.append_array(living_npcs(LIVING_NPCS["city_port"]))
	npcs.append_array(crystal_npc("city_port"))
	z["portals"] = (z["portals"] as Array) + _door_portals(_interior_doors(z, "city_port"), "city_port")
	z.erase("npc_pos")
	z.merge({"id": "city_port", "name": "Porto Esperança", "is_town": false, "hub": true, "level_range": Vector2i(30, 35),
		"conquest_vis": PORT_CONQUEST_VIS,
		"ground_color": Color(0.5, 0.64, 0.4), "ground_color_alt": Color(0.46, 0.6, 0.37), "ambient": Color(0.92, 0.95, 0.98), "sun_energy": 1.2,
		"bot_population": 9, "npcs": npcs})
	return _mk(z)

## Costa Partida (Ato II, 30-35): tools/blender/zones/build_field_coast.py. Mar ao sul (lago gigante), mangue com pontes.
static func _coast() -> MapDef:
	var z := load_zone("field_coast")
	var npc_pos: Dictionary = z["npc_pos"]
	var npcs := _place_npcs("field_coast", npc_pos)
	for nid in COAST_NPCS:
		var n: Array = COAST_NPCS[nid]
		var p: Array = npc_pos.get(nid, [n[4], n[5], 180.0])
		var d := _npc(nid, n[0], float(p[0]), float(p[1]), n[1], n[2], n[3], float(p[2]) if p.size() > 2 else 180.0,
			MERCHANT_SHOP + GearCatalog.shop_ids() if n[1] == "merchant" else [])
		if float(n[6]) > 0.0:
			d["wander"] = float(n[6])
		if str(n[7]) != "":
			d["if"] = n[7]
		d["look_seed"] = 300 + nid.length() * 7
		if nid.begins_with("goblin_"):              # goblins da aldeia mista: modelo de goblin, não o kit humano
			d["model"] = "mob_goblin_lancer"
		npcs.append(d)
	npcs.append_array(living_npcs(LIVING_NPCS["field_coast"]))
	z.erase("npc_pos")
	z.merge({"id": "field_coast", "name": "Costa Partida", "is_town": false, "level_range": Vector2i(30, 35),
		"conquest_vis": COAST_CONQUEST_VIS,
		"ground_color": Color(0.5, 0.64, 0.4), "ground_color_alt": Color(0.46, 0.6, 0.37), "ambient": Color(0.95, 0.96, 0.95), "sun_energy": 1.25,
		"bot_population": 6, "npcs": npcs})
	return _mk(z)

## Estepes de Cinza (Ato II, 35-40): tools/blender/zones/build_field_steppe.py. Posto da Caravana (anel de carroças) no
## centro, três acampamentos de guerra com investida própria (E0-E3), Desertores (E4), passo de Kharzun fechado (E5).
static func _steppe() -> MapDef:
	var z := load_zone("field_steppe")
	var npc_pos: Dictionary = z["npc_pos"]
	var npcs := _place_npcs("field_steppe", npc_pos)
	for nid in STEPPE_NPCS:
		var n: Array = STEPPE_NPCS[nid]
		var ex: Dictionary = n[4]
		var p: Array = ex.get("pos", npc_pos.get(nid, [0.0, 0.0, 180.0]))
		var d := _npc(nid, n[0], float(p[0]), float(p[1]), n[1], n[2], n[3], float(p[2]),
			MERCHANT_SHOP + GearCatalog.shop_ids() + GearCatalog.starter_weapon_ids(GameData.items) if ex.get("shop", "") == "merchant" else [])
		for k in ["if", "unless"]:
			if ex.has(k):
				d[k] = ex[k]
		d["look_seed"] = 600 + nid.length() * 9
		if nid.begins_with("deserter_"):            # desertores orcs (Urzog, Brakka, Gruk): modelo de orc, não o kit humano
			d["model"] = "mob_orc_recruit"
		npcs.append(d)
	for d in dawn_garrison(npc_pos, "steppe_g_"):                       # sentinelas nos vãos do Posto (veteranos: Balance.STEPPE_GUARD_POWER)
		d["power"] = Balance.STEPPE_GUARD_POWER
		npcs.append(d)
	for side in ["trolls", "fire", "war"]:                             # posto aliado no lugar do acampamento retomado
		for d in dawn_garrison(npc_pos, "steppe_p_%s_" % side):
			d["if"] = "hx_fort_" + side
			npcs.append(d)
	npcs.append_array(living_npcs(LIVING_NPCS["field_steppe"]))
	npcs.append_array(crystal_npc("field_steppe"))
	z.erase("npc_pos")
	z.merge({"id": "field_steppe", "name": "Estepes de Cinza", "is_town": false, "hub": true, "level_range": Vector2i(35, 40),
		"conquest_vis": steppe_conquest_vis(),
		"ground_color": Color(0.74, 0.62, 0.34), "ground_color_alt": Color(0.68, 0.56, 0.31), "ambient": Color(0.98, 0.92, 0.82), "sun_energy": 1.2,
		"bot_population": 6, "npcs": npcs})
	return _mk(z)
