class_name GearCatalog
extends RefCounted
## Equipamento gerado por loops (sem itens escritos à mão):
##  1) armas comuns dos tipos novos (montante, maça, martelo, machadinha, orbe) nos 4 tiers comuns;
##  2) um conjunto LENDÁRIO por BUILD de cada classe a cada 5 níveis (Balance.LEGENDARY_LEVELS):
##     elmo + corpo + luvas + botas + arma (+ mão secundária se a build usa), bônus de 2/3/4/5 peças;
##  3) calças, capas, amuletos e anéis comuns nos 4 tiers (sem restrição de classe).
## Escala: atributo/ATK/DEF crescem com o nível (Balance.GEAR_*); lendário = comum x LEGENDARY_MULT.

const EQ := ItemDef.Type.EQUIPMENT
const S := ItemDef.Slot

## valores-base no nível Balance.GEAR_REF_LEVEL: [atk, matk, def, mdef, atributo principal, secundário]
const WEAPONS := {
	"sword": [44, 0, 0, 0, "FOR", "VIT"],
	"sword2h": [64, 0, 0, 0, "FOR", "AGI"],
	"mace": [38, 14, 0, 0, "FOR", "WILL"],
	"mace2h": [58, 20, 0, 0, "FOR", "WILL"],
	"axe": [48, 0, 0, 0, "FOR", "AGI"],
	"axe2h": [64, 0, 0, 0, "FOR", "VIT"],
	"dagger": [34, 0, 0, 0, "AGI", "FOR"],
	"claw": [42, 0, 0, 0, "AGI", "FOR"],              # soqueira com garras (Berserker Punhos de Fúria): uma em cada mão
	"bow": [46, 0, 0, 0, "AGI", "FOR"],
	"staff": [8, 62, 0, 0, "INT", "WILL"],
	"scepter": [10, 60, 0, 6, "INT", "WILL"],
	"rifle": [72, 0, 0, 0, "AGI", "FOR"],             # rifle de duas mãos (Ranger Atirador): tiro lento e pesado
	"spear": [56, 0, 0, 0, "AGI", "FOR"],             # lança de duas mãos (Ranger Lanceiro): estocada longa
	"wand": [4, 46, 0, 0, "INT", "WILL"],
	"scythe": [20, 56, 0, 0, "INT", "WILL"],
	"shield": [0, 0, 18, 8, "VIT", "FOR"],
	"orb": [0, 16, 0, 4, "INT", "WILL"],
	"pistol": [20, 0, 0, 0, "AGI", "FOR"],            # pistola de pederneira (mão secundária do Corsário): soma o ATK inteiro (menos que a 2ª arma), os tiros saem das skills
}
const WEAPON_NAMES := {
	"sword": "Espada", "sword2h": "Montante", "mace": "Maça", "mace2h": "Martelo de Guerra",
	"axe": "Machadinha", "axe2h": "Machado de Guerra", "dagger": "Adaga", "bow": "Arco",
	"staff": "Cajado", "wand": "Varinha", "scythe": "Foice", "shield": "Escudo", "orb": "Orbe", "scepter": "Cetro", "rifle": "Mosquete", "spear": "Lança",
	"pistol": "Pistola", "claw": "Garra",
}
## tipos que ganham versão comum gerada (os outros já existem em items_catalog)
const NEW_COMMON_TYPES := ["sword2h", "mace", "mace2h", "axe", "orb", "scepter", "rifle", "spear", "pistol", "claw"]
const COMMON_TIER_NAMES := ["de Bronze", "de Ferro", "de Mitril", "de Obsidiana", "de Adamante", "de Oricalco"]
## Cor própria de um tier comum (sem entrada = a mistura de sempre): o 32 e o 40 dividem a raridade épica e a mistura
## para no tier 3, então o tier do 40 (Oricalco) ganha o dourado-cobre dele para não sair igual ao de Adamante.
const COMMON_TIER_TINT := {5: Color(0.93, 0.7, 0.42)}
## Tiers comuns sem armas/armaduras escritas à mão (items_catalog só vai até o tier 3): ganham TODAS as armas
## (WEAPONS) e cabeça/peito/luvas/botas por tipo de armadura geradas aqui (Ato II: tiers do 32 e do 40).
const HAND_WRITTEN_TIERS := 4
const FULL_PIECES := ["head", "body", "gloves", "boots"]

## Raridade de um item comum do tier: o tier, no máximo épico (raridade 4 = lendário, ItemDef.RARITY_LEGENDARY).
static func common_rarity(tier: int) -> int:
	return mini(tier, ItemDef.RARITY_LEGENDARY - 1)

## armaduras: peso da peça + [def, mdef] da peça de corpo no nível de referência
const PIECES := ["head", "body", "legs", "gloves", "boots"]     # peças de armadura do conjunto lendário (contam nos bônus 2-5)
const PIECE_SLOT := {"head": S.HEAD, "body": S.BODY, "gloves": S.GLOVES, "boots": S.BOOTS, "legs": S.LEGS, "cape": S.CAPE, "amulet": S.AMULET, "ring": S.RING}
const PIECE_WEIGHT := {"head": 0.5, "body": 1.0, "gloves": 0.35, "boots": 0.4, "weapon": 1.3, "offhand": 0.8,
	"legs": 0.4, "cape": 0.3, "amulet": 0.35, "ring": 0.3}     # capa/anel/amuleto: o de nível 24 passa os drops de chefe do 8
## calça: uma por tipo de armadura [nome, atributo, secundário]
const LEGS := {"plate": ["Perneiras", "VIT", "FOR"], "leather": ["Calças de Couro", "AGI", "VIT"], "cloth": ["Calças de Tecido", "INT", "WILL"]}
## capa/amuleto/anel: um por tema [sufixo, atributo, secundário, cor]
const THEMES := {
	"guerreiro": ["do Guerreiro", "FOR", "VIT", Color(0.75, 0.3, 0.25)],
	"cacador": ["do Caçador", "AGI", "FOR", Color(0.3, 0.62, 0.4)],
	"sabio": ["do Sábio", "INT", "WILL", Color(0.36, 0.42, 0.85)],
}
const THEME_PIECES := {"cape": "Capa", "amulet": "Amuleto", "ring": "Anel"}
const ARMOR := {"plate": [30, 10], "leather": [20, 14], "cloth": [10, 30]}
const ARMOR_NAMES := {
	"plate": {"head": "Elmo", "body": "Couraça", "legs": "Perneiras", "gloves": "Manoplas", "boots": "Grevas"},
	"leather": {"head": "Capuz", "body": "Gibão", "legs": "Calças", "gloves": "Luvas", "boots": "Botas"},
	"cloth": {"head": "Tiara", "body": "Manto", "legs": "Calças", "gloves": "Luvas", "boots": "Sandálias"},
}
## Escudos nomeados (referência em reference/shields): [id, nome, nível, silhueta, cor, reação ao bloquear, texto]
const SHIELDS := [
	["defensor_antigo", "Escudo Defensor Antigo", 5, "coluna", Color(0.22, 0.25, 0.42), {"theme": "physical", "reflect_pct": 12}, "Bloquear devolve 12% do golpe."],
	["lamento_gaia", "Lamento de Gaia", 10, "gaia", Color(0.2, 0.42, 0.22), {"theme": "nature", "root": {"duration": 1.0}, "heal_pct": 1}, "Bloquear enraíza o atacante e cura 1%."],
	["defensor_castelo", "Defensor do Castelo", 10, "bastiao", Color(0.64, 0.62, 0.6), {"theme": "earth", "block_bonus": 12, "slow": {"pct": 25, "duration": 2}}, "+12% de bloqueio; bloquear atrasa o atacante."],
	["abraco_criador", "Abraço do Criador", 15, "relicario", Color(0.42, 0.48, 0.95), {"theme": "holy", "barrier_pct": 6}, "Bloquear cria barreira de 6% da vida."],
	["osso_besta", "Escudo Osso da Besta", 15, "presa", Color(0.88, 0.85, 0.72), {"theme": "bone", "slow": {"pct": 45, "duration": 3}}, "Bloquear reduz 45% da velocidade do atacante."],
	["luz_cristal", "Luz Cristal", 15, "prisma", Color(0.45, 0.72, 1.0), {"theme": "ice", "slow": {"pct": 35, "duration": 2}, "mana_pct": 2}, "Bloquear congela o atacante e devolve 2% de MP."],
	["perdao_alice", "Escudo Perdão de Alice", 20, "perdao", Color(0.86, 0.89, 0.96), {"theme": "lunar", "mana_pct": 5}, "Bloquear devolve 5% de MP."],
	["palavra_deus", "Escudo Palavra de Deus", 20, "veredito", Color(0.24, 0.16, 0.36), {"theme": "lightning", "stun_chance": 25}, "25% de chance de atordoar ao bloquear."],
	["dragao_pantano", "Escudo Dragão do Pântano Sombrio", 20, "serpente", Color(0.2, 0.36, 0.3), {"theme": "poison", "dot": {"dps": 14, "duration": 4}}, "Bloquear envenena o atacante."],
	["asa_angelical", "Escudo Asa Angelical de Alice", 25, "asa", Color(0.9, 0.95, 1.0), {"theme": "heal", "heal_pct": 3}, "Bloquear cura 3% da vida."],
	["senhor_crueldade", "Senhor da Crueldade", 25, "cruel", Color(0.34, 0.31, 0.38), {"theme": "shadow", "reflect_pct": 30}, "Bloquear devolve 30% do golpe."],
	["deus_guerra", "Semblante Deus da Guerra", 25, "sol", Color(0.55, 0.2, 0.12), {"theme": "fire", "dot": {"dps": 26, "duration": 3}}, "Bloquear queima o atacante."],
	["alado_negro", "Escudo Alado Negro de Alice", 30, "asa_negra", Color(0.2, 0.26, 0.34), {"theme": "shadow", "heal_pct": 2, "reflect_pct": 15}, "Bloquear cura 2% e devolve 15% do golpe."],
	["muro_suspiros", "Muro dos Suspiros", 30, "suspiros", Color(0.3, 0.18, 0.12), {"theme": "holy", "barrier_pct": 10}, "Bloquear cria barreira de 10% da vida."],
]
## Afinidade do modelo: a classe ganha Juramento (paladin) ou Graça (bishop) ao bloquear com ela.
const SHIELD_AFFINITY := {"bastiao": "paladin", "juramento": "paladin", "sol": "paladin", "presa": "paladin", "tabuas": "paladin", "ossario": "paladin",
	"escama": "paladin", "coluna": "paladin", "veredito": "paladin", "serpente": "paladin", "cruel": "paladin", "suspiros": "paladin",
	"relicario": "bishop", "prisma": "bishop", "gaia": "bishop", "perdao": "bishop", "asa": "both", "asa_negra": "both", "ferro": "both",
	"bis_s5": "bishop", "bis_s10": "bishop", "bis_s15": "bishop", "bis_s20": "bishop", "bis_s25": "bishop", "bis_s30": "bishop",
	"pal1": "paladin", "pal_g10": "paladin", "pal_g15": "paladin", "pal_g20": "paladin", "pal_g25": "paladin", "pal_g30": "paladin",
	"pal_t5": "paladin", "pal_t10": "paladin", "pal_t15": "paladin", "pal_t20": "paladin", "pal_t25": "paladin", "pal_t30": "paladin",
	"bis_b5": "bishop", "bis_b10": "bishop", "bis_b15": "bishop", "bis_b20": "bishop", "bis_b25": "bishop", "bis_b30": "bishop"}     # escudos de conjunto
## epíteto por nível lendário (5..30; Ato II: 35 e 40)
const TIER_EPITHETS := ["da Alvorada", "do Juramento", "da Vanguarda", "da Glória", "da Lenda", "da Eternidade", "da Ascensão", "do Triunfo", "do Apogeu"]
## Último nível lendário com visual próprio por build (SET_VISUALS). Acima (Ato II, fatia 1) o conjunto reaproveita o
## visual do último nível com visual (visual_of), com o nome genérico da regra; modelos próprios vêm no polimento.
const OWN_VISUALS_UNTIL := 30
const LEGENDARY_COLOR := Color(1.0, 0.6, 0.15)
## Conjuntos lendários com visual próprio (kit: tools/blender/chibi_kit.py SET_STYLES; ícones: assets/icons/<icon>_<peça>.png).
## Referência de arte em reference/<classe>/set_N. Peças sem slot próprio no RagnaEx (polainas) vêm junto do corpo.
## Nomes das peças de conjunto (set_piece_name): substantivo da build + complemento do conjunto ("suffix" = "do X";
## "adj" = adjetivo que concorda com o substantivo: ADJ_FORMS[adj][NOUN_FORM]). "nouns" no conjunto troca o substantivo de
## uma peça (capuz, máscara...); "names" = conjunto todo escrito à mão. Calça: ARMOR_NAMES[armadura]["legs"] com o mesmo complemento.
const PIECE_NOUNS := {
	"paladin_guardiao": {"body": "Couraça", "boots": "Grevas", "gloves": "Manoplas", "head": "Elmo", "offhand": "Escudo", "weapon": "Espada"},
	"paladin_cruzado": {"body": "Couraça", "boots": "Grevas", "gloves": "Manoplas", "head": "Elmo", "offhand": "Escudo", "weapon": "Espada"},
	"berserker_carniceiro": {"body": "Couraça", "boots": "Botas", "gloves": "Braçais", "head": "Elmo", "offhand": "Machado Gêmeo", "weapon": "Machado"},
	"berserker_executor": {"body": "Couraça", "boots": "Botas", "gloves": "Braçais", "head": "Elmo", "weapon": "Machado de Guerra"},
	"berserker_punhos": {"body": "Gibão", "boots": "Sandálias", "gloves": "Faixas", "head": "Faixa", "offhand": "Garra Gêmea", "weapon": "Garra"},
	"bishop_sacerdote": {"body": "Vestes", "boots": "Sandálias", "gloves": "Mangas", "head": "Véu", "offhand": "Escudo", "weapon": "Maça"},
	"bishop_inquisidor": {"body": "Vestes", "boots": "Sandálias", "gloves": "Mangas", "head": "Mitra", "weapon": "Cetro"},
	"paladin_templario": {"body": "Couraça", "boots": "Grevas", "gloves": "Manoplas", "head": "Elmo", "offhand": "Escudo", "weapon": "Espada"},
	"bishop_batalha": {"body": "Couraça", "boots": "Grevas", "gloves": "Manoplas", "head": "Elmo", "offhand": "Escudo", "weapon": "Maça"},
	"druid_xama": {"body": "Manto", "boots": "Botas", "gloves": "Braçais", "head": "Coroa", "weapon": "Cajado"},
	"druid_fera": {"body": "Manto", "boots": "Botas", "gloves": "Braçais", "head": "Capuz", "offhand": "Maça Gêmea", "weapon": "Maça"},
	"druid_guardiao_verde": {"body": "Manto", "boots": "Botas", "gloves": "Braçais", "head": "Crânio", "weapon": "Malho"},
	"ranger_cacador": {"body": "Colete", "boots": "Botas", "gloves": "Braçadeira", "head": "Gorro", "weapon": "Arco"},
	"ranger_atirador": {"body": "Colete", "boots": "Botas", "gloves": "Braçadeira", "head": "Chapéu", "weapon": "Mosquete"},
	"ranger_lanceiro": {"body": "Gibão", "boots": "Botas", "gloves": "Braçadeiras", "head": "Crânio", "weapon": "Lança"},
	"assassin_laminas": {"body": "Gibão", "boots": "Botas", "gloves": "Faixas", "head": "Capuz", "offhand": "Adaga Gêmea", "weapon": "Adaga"},
	"assassin_duelista": {"body": "Casaca", "boots": "Botas", "gloves": "Luvas", "head": "Chapéu", "offhand": "Espada Gêmea", "weapon": "Espada"},
	"assassin_corsario": {"body": "Casaca", "boots": "Botas", "gloves": "Luvas", "head": "Tricórnio", "offhand": "Pistola", "weapon": "Sabre"},
	"elementalist_fogo": {"body": "Túnica", "boots": "Sapatilhas", "gloves": "Mangas", "head": "Chapéu", "weapon": "Cajado"},
	"elementalist_gelo": {"body": "Túnica", "boots": "Sapatilhas", "gloves": "Mangas", "head": "Coroa", "weapon": "Cajado"},
	"elementalist_raio": {"body": "Túnica", "boots": "Sapatilhas", "gloves": "Mangas", "head": "Chapéu", "weapon": "Cajado"},
	"necromancer_invocador": {"body": "Túnica", "boots": "Botas", "gloves": "Mangas", "head": "Capuz", "weapon": "Foice"},
	"necromancer_ceifador": {"body": "Manto", "boots": "Botas", "gloves": "Braçais", "head": "Capuz", "weapon": "Foice"},
	"necromancer_pestilento": {"body": "Túnica", "boots": "Botas", "gloves": "Mangas", "head": "Capuz", "weapon": "Foice"},
}
## gênero e número: ms, fs, mp, fp (índice em ADJ_FORMS)
const NOUN_FORM := {
	"Adaga": "fs",
	"Machadinha": "fs",
	"Martelo de Guerra": "ms",
	"Montante": "ms",
	"Orbe": "ms",
	"Varinha": "fs",
	"Adaga Gêmea": "fs",
	"Arco": "ms",
	"Bandana": "fs",
	"Bicorne": "ms",
	"Boné": "ms",
	"Botas": "fp",
	"Braçadeira": "fs",
	"Braçadeiras": "fp",
	"Braçais": "mp",
	"Cajado": "ms",
	"Calças": "fp",
	"Capuz": "ms",
	"Casaca": "fs",
	"Cetro": "ms",
	"Chapéu": "ms",
	"Colete": "ms",
	"Coroa": "fs",
	"Cota de Escamas": "fs",
	"Couraça": "fs",
	"Crânio": "ms",
	"Diadema": "ms",
	"Elmo": "ms",
	"Escudo": "ms",
	"Espada": "fs",
	"Espada Gêmea": "fs",
	"Faixa": "fs",
	"Faixas": "fp",
	"Foice": "fs",
	"Garra": "fs",
	"Garra Gêmea": "fs",
	"Gibão": "ms",
	"Gorro": "ms",
	"Grevas": "fp",
	"Juba": "fs",
	"Lança": "fs",
	"Lenço": "ms",
	"Luvas": "fp",
	"Machado": "ms",
	"Machado Gêmeo": "ms",
	"Machado de Guerra": "ms",
	"Malho": "ms",
	"Mangas": "fp",
	"Manoplas": "fp",
	"Manto": "ms",
	"Maça": "fs",
	"Maça Gêmea": "fs",
	"Mitra": "fs",
	"Mosquete": "ms",
	"Máscara": "fs",
	"Perneiras": "fp",
	"Pistola": "fs",
	"Sabre": "ms",
	"Sandálias": "fp",
	"Sapatilhas": "fp",
	"Tiara": "fs",
	"Tricórnio": "ms",
	"Túnica": "fs",
	"Vestes": "fp",
	"Véu": "ms",
}
const ADJ_FORMS := {
	"Celestial": ["Celestial", "Celestial", "Celestiais", "Celestiais"],
	"Cinzenta": ["Cinzento", "Cinzenta", "Cinzentos", "Cinzentas"],
	"Cristalina": ["Cristalino", "Cristalina", "Cristalinos", "Cristalinas"],
	"Dourado": ["Dourado", "Dourada", "Dourados", "Douradas"],
	"Escarlate": ["Escarlate", "Escarlate", "Escarlates", "Escarlates"],
	"Primordial": ["Primordial", "Primordial", "Primordiais", "Primordiais"],
	"Rubro": ["Rubro", "Rubra", "Rubros", "Rubras"],
	"Silenciosa": ["Silencioso", "Silenciosa", "Silenciosos", "Silenciosas"],
	"Solar": ["Solar", "Solar", "Solares", "Solares"],
}
const FORM_INDEX := {"ms": 0, "fs": 1, "mp": 2, "fp": 3}

## Nome de uma peça de conjunto pela regra acima (piece: head, body, legs, gloves, boots, weapon, offhand).
## "set_<classe>_<build>_<nível>" -> "<classe>_<build>" (chave de PIECE_NOUNS)
static func bid_of_set(sid: String) -> String:
	return sid.trim_prefix("set_").rsplit("_", true, 1)[0]

static func set_piece_name(vis: Dictionary, bid: String, piece: String, armor: String) -> String:
	var noun: String = ARMOR_NAMES[armor]["legs"] if piece == "legs" else str(vis.get("nouns", {}).get(piece, PIECE_NOUNS[bid].get(piece, "")))
	return noun_with(vis, noun)

## Visual de um conjunto: o próprio (SET_VISUALS) ou, acima de OWN_VISUALS_UNTIL, o do maior nível da build que tem
## visual, marcado com "reuse" (estilo, ícones, cor e "favor" iguais; nomes ficam os genéricos). {} = sem visual.
static func visual_of(sid: String) -> Dictionary:
	if SET_VISUALS.has(sid):
		return SET_VISUALS[sid]
	var lv := int(sid.get_slice("_", sid.get_slice_count("_") - 1))
	if lv <= OWN_VISUALS_UNTIL:
		return {}
	var base := "set_%s_" % bid_of_set(sid)
	for i in range(Balance.LEGENDARY_LEVELS.size() - 1, -1, -1):
		var olv: int = Balance.LEGENDARY_LEVELS[i]
		if olv < lv and SET_VISUALS.has(base + str(olv)):
			var v: Dictionary = (SET_VISUALS[base + str(olv)] as Dictionary).duplicate()
			for k in ["names", "suffix", "adj", "nouns", "set_name"]:
				v.erase(k)
			v["reuse"] = base + str(olv)
			return v
	return {}

## Substantivo + complemento do conjunto (o adjetivo concorda com ele). "" = "".
static func noun_with(vis: Dictionary, noun: String) -> String:
	if noun == "":
		return ""
	if vis.has("adj"):
		return "%s %s" % [noun, ADJ_FORMS[vis["adj"]][FORM_INDEX[NOUN_FORM.get(noun, "ms")]]]
	return "%s %s" % [noun, vis.get("suffix", "")]

const SET_VISUALS := {
	"set_paladin_guardiao_5": {"style": "pal1", "icon": "pal1", "color": Color(0.58, 0.46, 0.84),
		"set_name": "Conjunto Cavaleiro da Fortaleza",
		"names": {"head": "Capacete de Cavaleiro da Fortaleza", "body": "Armadura de Cavaleiro da Fortaleza",
			"gloves": "Avambraço Cavaleiro do Forte", "boots": "Botas Cavaleiro do Forte",
			"weapon": "Espada Cavaleiro do Forte", "offhand": "Escudo Cavaleiro do Forte"}},
	"set_paladin_guardiao_10": {"style": "pal_g10", "icon": "pal_g10", "color": Color(0.6, 0.66, 0.78), "set_name": "Conjunto Bastião de Ferro",
		"suffix": "do Bastião"},
	"set_paladin_guardiao_15": {"style": "pal_g15", "icon": "pal_g15", "color": Color(0.26, 0.4, 0.78), "set_name": "Conjunto Muralha Azul",
		"suffix": "da Muralha Azul"},
	"set_paladin_guardiao_20": {"style": "pal_g20", "icon": "pal_g20", "color": Color(0.95, 0.6, 0.26), "set_name": "Conjunto Guarda da Aurora",
		"suffix": "da Aurora"},
	"set_paladin_guardiao_25": {"style": "pal_g25", "icon": "pal_g25", "color": Color(0.36, 0.38, 0.43), "set_name": "Conjunto Sentinela de Basalto",
		"suffix": "da Sentinela"},
	"set_paladin_guardiao_30": {"style": "pal_g30", "icon": "pal_g30", "color": Color(0.95, 0.9, 0.72), "set_name": "Conjunto Égide Eterna",
		"suffix": "da Égide"},
	"set_paladin_cruzado_5": {"style": "pal_c5", "icon": "pal_c5", "color": Color(0.85, 0.86, 0.9), "set_name": "Conjunto Escudeiro da Chama",
		"suffix": "do Escudeiro"},
	"set_paladin_cruzado_10": {"style": "pal_c10", "icon": "pal_c10", "color": Color(0.72, 0.8, 0.95), "set_name": "Conjunto Cruzado de Prata",
		"suffix": "de Prata"},
	"set_paladin_cruzado_15": {"style": "pal_c15", "icon": "pal_c15", "color": Color(0.35, 0.65, 0.7), "set_name": "Conjunto Lâmina da Fé",
		"suffix": "da Fé"},
	"set_paladin_cruzado_20": {"style": "pal_c20", "icon": "pal_c20", "color": Color(0.98, 0.8, 0.35), "set_name": "Conjunto Vigília Solar",
		"adj": "Solar"},
	"set_paladin_cruzado_25": {"style": "pal_c25", "icon": "pal_c25", "color": Color(0.72, 0.16, 0.2), "set_name": "Conjunto Juramento Rubro",
		"adj": "Rubro"},
	"set_paladin_cruzado_30": {"style": "pal_c30", "icon": "pal_c30", "color": Color(0.97, 0.96, 0.92), "set_name": "Conjunto Arauto Celestial",
		"adj": "Celestial"},
	"set_berserker_carniceiro_5": {"style": "ber_g5", "icon": "ber_g5", "color": Color(0.52, 0.4, 0.3), "set_name": "Conjunto Pele de Lobo",
		"suffix": "do Lobo"},
	"set_berserker_carniceiro_10": {"style": "ber_g10", "icon": "ber_g10", "color": Color(0.7, 0.55, 0.36), "set_name": "Conjunto Saqueador do Norte",
		"suffix": "do Saqueador"},
	"set_berserker_carniceiro_15": {"style": "ber_g15", "icon": "ber_g15", "color": Color(0.62, 0.14, 0.14), "set_name": "Conjunto Presa Sangrenta",
		"suffix": "da Presa"},
	"set_berserker_carniceiro_20": {"style": "ber_g20", "icon": "ber_g20", "color": Color(0.22, 0.2, 0.24), "set_name": "Conjunto Ceifador Veloz",
		"suffix": "do Ceifador"},
	"set_berserker_carniceiro_25": {"style": "ber_g25", "icon": "ber_g25", "color": Color(0.9, 0.42, 0.14), "set_name": "Conjunto Fúria de Brasa",
		"suffix": "da Brasa"},
	"set_berserker_carniceiro_30": {"style": "ber_g30", "icon": "ber_g30", "color": Color(0.55, 0.06, 0.1), "set_name": "Conjunto Senhor da Carnificina",
		"suffix": "da Carnificina"},
	"set_berserker_executor_5": {"style": "ber_e5", "icon": "ber_e5", "color": Color(0.5, 0.5, 0.54), "set_name": "Conjunto Carrasco de Ferro",
		"suffix": "do Carrasco"},
	"set_berserker_executor_10": {"style": "ber_e10", "icon": "ber_e10", "color": Color(0.72, 0.5, 0.26), "set_name": "Conjunto Muralha de Bronze",
		"suffix": "de Bronze"},
	"set_berserker_executor_15": {"style": "ber_e15", "icon": "ber_e15", "color": Color(0.3, 0.32, 0.38), "set_name": "Conjunto Quebra-Crânios",
		"suffix": "Quebra-Crânios"},
	"set_berserker_executor_20": {"style": "ber_e20", "icon": "ber_e20", "color": Color(0.55, 0.72, 0.85), "set_name": "Conjunto Gigante do Inverno",
		"suffix": "do Inverno"},
	"set_berserker_executor_25": {"style": "ber_e25", "icon": "ber_e25", "color": Color(0.16, 0.14, 0.18), "set_name": "Conjunto Tirano de Obsidiana",
		"suffix": "de Obsidiana"},
	"set_berserker_executor_30": {"style": "ber_e30", "icon": "ber_e30", "color": Color(0.75, 0.16, 0.12), "set_name": "Conjunto Titã Escarlate",
		"adj": "Escarlate"},
	"set_berserker_punhos_5": {"style": "ber_m5", "icon": "ber_m5", "color": Color(0.62, 0.5, 0.34), "set_name": "Conjunto Noviço do Mosteiro",
		"suffix": "do Noviço"},
	"set_berserker_punhos_10": {"style": "ber_m10", "icon": "ber_m10", "color": Color(0.72, 0.42, 0.16), "set_name": "Conjunto Punho de Bronze",
		"suffix": "de Bronze", "nouns": {"head": "Tiara"}},
	"set_berserker_punhos_15": {"style": "ber_m15", "icon": "ber_m15", "color": Color(0.3, 0.42, 0.34), "set_name": "Conjunto Tigre da Montanha",
		"suffix": "do Tigre", "nouns": {"head": "Máscara"}},
	"set_berserker_punhos_20": {"style": "ber_m20", "icon": "ber_m20", "color": Color(0.55, 0.16, 0.12), "set_name": "Conjunto Lótus Rubra",
		"names": {"head": "Coroa de Contas da Lótus", "body": "Gibão da Lótus Rubra", "gloves": "Faixas da Lótus Rubra", "boots": "Sandálias da Lótus Rubra", "weapon": "Garra da Lótus Rubra", "offhand": "Garra Gêmea da Lótus Rubra"}},
	"set_berserker_punhos_25": {"style": "ber_m25", "icon": "ber_m25", "color": Color(0.18, 0.2, 0.3), "set_name": "Conjunto Dragão de Ferro",
		"suffix": "do Dragão de Ferro", "nouns": {"head": "Elmo"}},
	"set_berserker_punhos_30": {"style": "ber_m30", "icon": "ber_m30", "color": Color(0.86, 0.66, 0.26), "set_name": "Conjunto Mestre dos Cem Punhos",
		"suffix": "dos Cem Punhos", "nouns": {"head": "Coroa"}},
	"set_bishop_sacerdote_5": {"style": "bis_s5", "icon": "bis_s5", "color": Color(0.92, 0.88, 0.78), "set_name": "Conjunto Vestes da Aurora",
		"suffix": "da Aurora"},
	"set_bishop_sacerdote_10": {"style": "bis_s10", "icon": "bis_s10", "color": Color(0.55, 0.68, 0.9), "set_name": "Conjunto Vigília Serena",
		"suffix": "da Vigília"},
	"set_bishop_sacerdote_15": {"style": "bis_s15", "icon": "bis_s15", "color": Color(0.4, 0.62, 0.66), "set_name": "Conjunto Guardiã do Claustro",
		"suffix": "do Claustro"},
	"set_bishop_sacerdote_20": {"style": "bis_s20", "icon": "bis_s20", "color": Color(0.95, 0.78, 0.4), "set_name": "Conjunto Graça Dourada",
		"suffix": "da Graça"},
	"set_bishop_sacerdote_25": {"style": "bis_s25", "icon": "bis_s25", "color": Color(0.62, 0.72, 0.95), "set_name": "Conjunto Asa Serena",
		"suffix": "da Asa Serena"},
	"set_bishop_sacerdote_30": {"style": "bis_s30", "icon": "bis_s30", "color": Color(0.98, 0.96, 0.9), "set_name": "Conjunto Coro Celeste",
		"suffix": "do Coro Celeste"},
	"set_bishop_inquisidor_5": {"style": "bis_i5", "icon": "bis_i5", "color": Color(0.85, 0.82, 0.95), "set_name": "Conjunto Lume Nascente",
		"suffix": "do Lume"},
	"set_bishop_inquisidor_10": {"style": "bis_i10", "icon": "bis_i10", "color": Color(0.45, 0.55, 0.85), "set_name": "Conjunto Clarão Azul",
		"suffix": "do Clarão"},
	"set_bishop_inquisidor_15": {"style": "bis_i15", "icon": "bis_i15", "color": Color(0.95, 0.66, 0.3), "set_name": "Conjunto Prisma Sagrado",
		"suffix": "do Prisma"},
	"set_bishop_inquisidor_20": {"style": "bis_i20", "icon": "bis_i20", "color": Color(0.98, 0.9, 0.55), "set_name": "Conjunto Sol Interior",
		"suffix": "do Sol Interior"},
	"set_bishop_inquisidor_25": {"style": "bis_i25", "icon": "bis_i25", "color": Color(0.3, 0.32, 0.6), "set_name": "Conjunto Estrela Noturna",
		"suffix": "da Estrela"},
	"set_bishop_inquisidor_30": {"style": "bis_i30", "icon": "bis_i30", "color": Color(0.99, 0.97, 0.92), "set_name": "Conjunto Luz Primordial",
		"suffix": "da Luz Primordial"},
	"set_paladin_templario_5": {"style": "pal_t5", "icon": "pal_t5", "color": Color(0.82, 0.36, 0.22), "set_name": "Conjunto Brasa do Noviço",
		"suffix": "da Brasa"},
	"set_paladin_templario_10": {"style": "pal_t10", "icon": "pal_t10", "color": Color(0.92, 0.9, 0.84), "set_name": "Conjunto Manto Branco",
		"suffix": "do Manto Branco"},
	"set_paladin_templario_15": {"style": "pal_t15", "icon": "pal_t15", "color": Color(0.62, 0.12, 0.14), "set_name": "Conjunto Cruz Vermelha",
		"suffix": "da Cruz Vermelha"},
	"set_paladin_templario_20": {"style": "pal_t20", "icon": "pal_t20", "color": Color(0.95, 0.55, 0.18), "set_name": "Conjunto Chama Votiva",
		"suffix": "da Chama Votiva"},
	"set_paladin_templario_25": {"style": "pal_t25", "icon": "pal_t25", "color": Color(0.24, 0.22, 0.3), "set_name": "Conjunto Penitente Negro",
		"suffix": "do Penitente"},
	"set_paladin_templario_30": {"style": "pal_t30", "icon": "pal_t30", "color": Color(1.0, 0.78, 0.3), "set_name": "Conjunto Sol Vingador",
		"suffix": "do Sol Vingador"},
	"set_bishop_batalha_5": {"style": "bis_b5", "icon": "bis_b5", "color": Color(0.7, 0.66, 0.6), "set_name": "Conjunto Irmã de Armas",
		"suffix": "da Irmã de Armas"},
	"set_bishop_batalha_10": {"style": "bis_b10", "icon": "bis_b10", "color": Color(0.5, 0.62, 0.78), "set_name": "Conjunto Capelão de Aço",
		"suffix": "do Capelão"},
	"set_bishop_batalha_15": {"style": "bis_b15", "icon": "bis_b15", "color": Color(0.32, 0.52, 0.42), "set_name": "Conjunto Guarda do Mosteiro",
		"suffix": "do Mosteiro"},
	"set_bishop_batalha_20": {"style": "bis_b20", "icon": "bis_b20", "color": Color(0.9, 0.72, 0.36), "set_name": "Conjunto Martelo da Fé",
		"suffix": "do Martelo da Fé"},
	"set_bishop_batalha_25": {"style": "bis_b25", "icon": "bis_b25", "color": Color(0.55, 0.3, 0.62), "set_name": "Conjunto Vigília Púrpura",
		"suffix": "da Vigília Púrpura"},
	"set_bishop_batalha_30": {"style": "bis_b30", "icon": "bis_b30", "color": Color(0.96, 0.94, 0.86), "set_name": "Conjunto Arcanjo Combatente",
		"suffix": "do Arcanjo"},
	"set_druid_xama_5": {"style": "dru_x5", "icon": "dru_x5", "color": Color(0.5, 0.7, 0.4), "set_name": "Conjunto Broto da Clareira",
		"suffix": "do Broto"},
	"set_druid_xama_10": {"style": "dru_x10", "icon": "dru_x10", "color": Color(0.45, 0.35, 0.22), "set_name": "Conjunto Galhada Antiga",
		"suffix": "da Galhada", "nouns": {"head": "Capuz"}},
	"set_druid_xama_15": {"style": "dru_x15", "icon": "dru_x15", "color": Color(0.85, 0.85, 0.75), "set_name": "Conjunto Lua do Bosque",
		"suffix": "da Lua do Bosque"},
	"set_druid_xama_20": {"style": "dru_x20", "icon": "dru_x20", "color": Color(0.3, 0.55, 0.45), "set_name": "Conjunto Seiva Viva",
		"suffix": "da Seiva", "nouns": {"head": "Capuz"}},
	"set_druid_xama_25": {"style": "dru_x25", "icon": "dru_x25", "color": Color(0.25, 0.28, 0.45), "set_name": "Conjunto Noite Selvagem",
		"suffix": "da Noite Selvagem", "nouns": {"head": "Capuz"}},
	"set_druid_xama_30": {"style": "dru_x30", "icon": "dru_x30", "color": Color(0.9, 0.8, 0.45), "set_name": "Conjunto Coração da Floresta",
		"suffix": "do Coração"},
	"set_druid_fera_5": {"style": "dru_w5", "icon": "dru_w5", "color": Color(0.5, 0.42, 0.32), "set_name": "Conjunto Pele Cinzenta",
		"adj": "Cinzenta"},
	"set_druid_fera_10": {"style": "dru_w10", "icon": "dru_w10", "color": Color(0.82, 0.84, 0.86), "set_name": "Conjunto Lobo da Neve",
		"suffix": "da Neve"},
	"set_druid_fera_15": {"style": "dru_w15", "icon": "dru_w15", "color": Color(0.28, 0.42, 0.26), "set_name": "Conjunto Matilha Verde",
		"suffix": "da Matilha"},
	"set_druid_fera_20": {"style": "dru_w20", "icon": "dru_w20", "color": Color(0.2, 0.22, 0.3), "set_name": "Conjunto Uivo Noturno",
		"suffix": "do Uivo"},
	"set_druid_fera_25": {"style": "dru_w25", "icon": "dru_w25", "color": Color(0.75, 0.8, 0.9), "set_name": "Conjunto Presa de Gelo",
		"suffix": "da Presa de Gelo"},
	"set_druid_fera_30": {"style": "dru_w30", "icon": "dru_w30", "color": Color(0.16, 0.18, 0.16), "set_name": "Conjunto Alfa Ancestral",
		"suffix": "do Alfa"},
	"set_druid_guardiao_verde_5": {"style": "dru_b5", "icon": "dru_b5", "color": Color(0.45, 0.32, 0.2), "set_name": "Conjunto Casca de Carvalho",
		"suffix": "de Carvalho"},
	"set_druid_guardiao_verde_10": {"style": "dru_b10", "icon": "dru_b10", "color": Color(0.4, 0.5, 0.3), "set_name": "Conjunto Raiz Profunda",
		"suffix": "da Raiz", "nouns": {"head": "Elmo"}},
	"set_druid_guardiao_verde_15": {"style": "dru_b15", "icon": "dru_b15", "color": Color(0.3, 0.24, 0.18), "set_name": "Conjunto Urso das Cavernas",
		"suffix": "das Cavernas"},
	"set_druid_guardiao_verde_20": {"style": "dru_b20", "icon": "dru_b20", "color": Color(0.75, 0.72, 0.62), "set_name": "Conjunto Montanha Musgosa",
		"suffix": "da Montanha", "nouns": {"head": "Elmo"}},
	"set_druid_guardiao_verde_25": {"style": "dru_b25", "icon": "dru_b25", "color": Color(0.45, 0.18, 0.12), "set_name": "Conjunto Fúria da Terra",
		"suffix": "da Terra"},
	"set_druid_guardiao_verde_30": {"style": "dru_b30", "icon": "dru_b30", "color": Color(0.85, 0.82, 0.7), "set_name": "Conjunto Urso Primordial",
		"adj": "Primordial"},
	"set_ranger_cacador_5": {"style": "ran_c5", "icon": "ran_c5", "color": Color(0.42, 0.6, 0.32), "set_name": "Conjunto Batedor da Clareira",
		"suffix": "do Batedor"},
	"set_ranger_cacador_10": {"style": "ran_c10", "icon": "ran_c10", "color": Color(0.35, 0.42, 0.3), "set_name": "Conjunto Sombra do Bosque",
		"suffix": "da Sombra", "nouns": {"head": "Capuz"}},
	"set_ranger_cacador_15": {"style": "ran_c15", "icon": "ran_c15", "color": Color(0.72, 0.5, 0.3), "set_name": "Conjunto Pena de Falcão",
		"suffix": "do Falcão"},
	"set_ranger_cacador_20": {"style": "ran_c20", "icon": "ran_c20", "color": Color(0.3, 0.62, 0.55), "set_name": "Conjunto Vento Verde",
		"suffix": "do Vento", "nouns": {"head": "Diadema"}},
	"set_ranger_cacador_25": {"style": "ran_c25", "icon": "ran_c25", "color": Color(0.4, 0.45, 0.7), "set_name": "Conjunto Lua Caçadora",
		"suffix": "da Lua", "nouns": {"head": "Capuz"}},
	"set_ranger_cacador_30": {"style": "ran_c30", "icon": "ran_c30", "color": Color(0.95, 0.88, 0.6), "set_name": "Conjunto Asa Dourada",
		"suffix": "da Asa Dourada", "nouns": {"head": "Diadema"}},
	"set_ranger_atirador_5": {"style": "ran_a5", "icon": "ran_a5", "color": Color(0.55, 0.4, 0.28), "set_name": "Conjunto Pólvora Nova",
		"suffix": "da Pólvora"},
	"set_ranger_atirador_10": {"style": "ran_a10", "icon": "ran_a10", "color": Color(0.45, 0.48, 0.52), "set_name": "Conjunto Engenhoqueiro",
		"suffix": "do Engenhoqueiro", "nouns": {"head": "Boné"}},
	"set_ranger_atirador_15": {"style": "ran_a15", "icon": "ran_a15", "color": Color(0.6, 0.18, 0.18), "set_name": "Conjunto Casaca Rubra",
		"adj": "Rubro"},
	"set_ranger_atirador_20": {"style": "ran_a20", "icon": "ran_a20", "color": Color(0.3, 0.3, 0.34), "set_name": "Conjunto Mira de Ferro",
		"suffix": "da Mira", "nouns": {"head": "Boné"}},
	"set_ranger_atirador_25": {"style": "ran_a25", "icon": "ran_a25", "color": Color(0.2, 0.32, 0.55), "set_name": "Conjunto Trovão Azul",
		"suffix": "do Trovão"},
	"set_ranger_atirador_30": {"style": "ran_a30", "icon": "ran_a30", "color": Color(0.82, 0.62, 0.3), "set_name": "Conjunto Canhão Dourado",
		"adj": "Dourado"},
	"set_ranger_lanceiro_5": {"style": "ran_l5", "icon": "ran_l5", "color": Color(0.55, 0.42, 0.28), "set_name": "Conjunto Pele de Javali",
		"suffix": "do Javali", "nouns": {"head": "Capuz"}},
	"set_ranger_lanceiro_10": {"style": "ran_l10", "icon": "ran_l10", "color": Color(0.62, 0.6, 0.56), "set_name": "Conjunto Crânio de Lobo",
		"suffix": "do Lobo Cinzento"},
	"set_ranger_lanceiro_15": {"style": "ran_l15", "icon": "ran_l15", "color": Color(0.72, 0.4, 0.18), "set_name": "Conjunto Juba de Leão",
		"suffix": "do Leão", "nouns": {"head": "Juba"}},
	"set_ranger_lanceiro_20": {"style": "ran_l20", "icon": "ran_l20", "color": Color(0.3, 0.5, 0.42), "set_name": "Conjunto Escama de Serpe",
		"suffix": "da Serpe", "nouns": {"body": "Cota de Escamas", "head": "Elmo"}},
	"set_ranger_lanceiro_25": {"style": "ran_l25", "icon": "ran_l25", "color": Color(0.36, 0.3, 0.42), "set_name": "Conjunto Pena de Corvo",
		"suffix": "do Corvo", "nouns": {"head": "Máscara"}},
	"set_ranger_lanceiro_30": {"style": "ran_l30", "icon": "ran_l30", "color": Color(0.8, 0.7, 0.5), "set_name": "Conjunto Rei das Feras",
		"suffix": "do Rei das Feras"},
	"set_assassin_laminas_5": {"style": "ass_l5", "icon": "ass_l5", "color": Color(0.32, 0.3, 0.38), "set_name": "Conjunto Passo Silencioso",
		"adj": "Silenciosa"},
	"set_assassin_laminas_10": {"style": "ass_l10", "icon": "ass_l10", "color": Color(0.55, 0.22, 0.25), "set_name": "Conjunto Faixa Rubra",
		"suffix": "da Faixa Rubra", "nouns": {"head": "Máscara"}},
	"set_assassin_laminas_15": {"style": "ass_l15", "icon": "ass_l15", "color": Color(0.3, 0.45, 0.3), "set_name": "Conjunto Erva-Moura",
		"suffix": "da Erva-Moura"},
	"set_assassin_laminas_20": {"style": "ass_l20", "icon": "ass_l20", "color": Color(0.4, 0.28, 0.55), "set_name": "Conjunto Víbora Violeta",
		"suffix": "da Víbora"},
	"set_assassin_laminas_25": {"style": "ass_l25", "icon": "ass_l25", "color": Color(0.2, 0.36, 0.38), "set_name": "Conjunto Escama Tóxica",
		"suffix": "da Escama"},
	"set_assassin_laminas_30": {"style": "ass_l30", "icon": "ass_l30", "color": Color(0.22, 0.18, 0.3), "set_name": "Conjunto Mariposa da Meia-Noite",
		"suffix": "da Meia-Noite"},
	"set_assassin_duelista_5": {"style": "ass_d5", "icon": "ass_d5", "color": Color(0.6, 0.45, 0.3), "set_name": "Conjunto Aprendiz de Esgrima",
		"suffix": "do Aprendiz", "nouns": {"head": "Bandana"}},
	"set_assassin_duelista_10": {"style": "ass_d10", "icon": "ass_d10", "color": Color(0.3, 0.42, 0.62), "set_name": "Conjunto Florete Azul",
		"suffix": "do Florete"},
	"set_assassin_duelista_15": {"style": "ass_d15", "icon": "ass_d15", "color": Color(0.2, 0.2, 0.24), "set_name": "Conjunto Baile de Máscaras",
		"suffix": "do Baile", "nouns": {"head": "Máscara"}},
	"set_assassin_duelista_20": {"style": "ass_d20", "icon": "ass_d20", "color": Color(0.65, 0.18, 0.22), "set_name": "Conjunto Rosa Escarlate",
		"suffix": "da Rosa"},
	"set_assassin_duelista_25": {"style": "ass_d25", "icon": "ass_d25", "color": Color(0.85, 0.85, 0.9), "set_name": "Conjunto Lua Prateada",
		"suffix": "da Lua Prateada", "nouns": {"head": "Diadema"}},
	"set_assassin_duelista_30": {"style": "ass_d30", "icon": "ass_d30", "color": Color(0.3, 0.15, 0.4), "set_name": "Conjunto Mestre das Lâminas",
		"suffix": "do Mestre"},
	"set_assassin_corsario_5": {"style": "ass_c5", "icon": "ass_c5", "color": Color(0.62, 0.3, 0.22), "set_name": "Conjunto Grumete",
		"suffix": "do Grumete", "nouns": {"head": "Bandana"}},
	"set_assassin_corsario_10": {"style": "ass_c10", "icon": "ass_c10", "color": Color(0.22, 0.38, 0.6), "set_name": "Conjunto Maré Alta",
		"suffix": "da Maré Alta"},
	"set_assassin_corsario_15": {"style": "ass_c15", "icon": "ass_c15", "color": Color(0.2, 0.42, 0.36), "set_name": "Conjunto Contrabandista de Coral",
		"suffix": "do Coral", "nouns": {"head": "Lenço"}},
	"set_assassin_corsario_20": {"style": "ass_c20", "icon": "ass_c20", "color": Color(0.66, 0.16, 0.2), "set_name": "Conjunto Bandeira Rubra",
		"suffix": "da Bandeira Rubra", "nouns": {"head": "Bicorne"}},
	"set_assassin_corsario_25": {"style": "ass_c25", "icon": "ass_c25", "color": Color(0.16, 0.18, 0.26), "set_name": "Conjunto Navio Fantasma",
		"suffix": "do Navio Fantasma"},
	"set_assassin_corsario_30": {"style": "ass_c30", "icon": "ass_c30", "color": Color(0.42, 0.18, 0.46), "set_name": "Conjunto Almirante dos Sete Mares",
		"suffix": "do Almirante", "nouns": {"head": "Chapéu"}},
	"set_elementalist_fogo_5": {"style": "ele_f5", "icon": "ele_f5", "color": Color(0.82, 0.32, 0.18), "set_name": "Conjunto Brasa Nova",
		"suffix": "da Brasa"},
	"set_elementalist_fogo_10": {"style": "ele_f10", "icon": "ele_f10", "color": Color(0.72, 0.34, 0.37), "set_name": "Conjunto Tempestade Rubra", "favor": "storm",
		"suffix": "da Tempestade Rubra", "nouns": {"head": "Diadema"}},
	"set_elementalist_fogo_15": {"style": "ele_f15", "icon": "ele_f15", "color": Color(0.71, 0.43, 0.4), "set_name": "Conjunto Vapor Escarlate", "favor": "frost",
		"suffix": "do Vapor"},
	"set_elementalist_fogo_20": {"style": "ele_f20", "icon": "ele_f20", "color": Color(0.82, 0.32, 0.18), "set_name": "Conjunto Coração de Fogo",
		"suffix": "do Coração de Fogo", "nouns": {"head": "Diadema"}},
	"set_elementalist_fogo_25": {"style": "ele_f25", "icon": "ele_f25", "color": Color(0.72, 0.34, 0.37), "set_name": "Conjunto Céu em Chamas", "favor": "storm",
		"suffix": "do Céu em Chamas"},
	"set_elementalist_fogo_30": {"style": "ele_f30", "icon": "ele_f30", "color": Color(0.71, 0.43, 0.4), "set_name": "Conjunto Equinócio Ardente", "favor": "frost",
		"suffix": "do Equinócio"},
	"set_elementalist_gelo_5": {"style": "ele_g5", "icon": "ele_g5", "color": Color(0.45, 0.68, 0.92), "set_name": "Conjunto Geada Leve",
		"suffix": "da Geada"},
	"set_elementalist_gelo_10": {"style": "ele_g10", "icon": "ele_g10", "color": Color(0.56, 0.57, 0.7), "set_name": "Conjunto Fogo Gélido", "favor": "fire",
		"suffix": "do Fogo Gélido", "nouns": {"head": "Capuz"}},
	"set_elementalist_gelo_15": {"style": "ele_g15", "icon": "ele_g15", "color": Color(0.46, 0.6, 0.89), "set_name": "Conjunto Granizo Azul", "favor": "storm",
		"suffix": "do Granizo"},
	"set_elementalist_gelo_20": {"style": "ele_g20", "icon": "ele_g20", "color": Color(0.45, 0.68, 0.92), "set_name": "Conjunto Inverno Eterno",
		"suffix": "do Inverno", "nouns": {"head": "Capuz"}},
	"set_elementalist_gelo_25": {"style": "ele_g25", "icon": "ele_g25", "color": Color(0.56, 0.57, 0.7), "set_name": "Conjunto Aurora Boreal", "favor": "fire",
		"suffix": "da Aurora"},
	"set_elementalist_gelo_30": {"style": "ele_g30", "icon": "ele_g30", "color": Color(0.46, 0.6, 0.89), "set_name": "Conjunto Nevasca Trovejante", "favor": "storm",
		"suffix": "da Nevasca"},
	"set_elementalist_raio_5": {"style": "ele_r5", "icon": "ele_r5", "color": Color(0.48, 0.4, 0.82), "set_name": "Conjunto Centelha",
		"suffix": "da Centelha"},
	"set_elementalist_raio_10": {"style": "ele_r10", "icon": "ele_r10", "color": Color(0.58, 0.38, 0.63), "set_name": "Conjunto Relâmpago Rubro", "favor": "fire",
		"suffix": "do Relâmpago", "nouns": {"head": "Faixa"}},
	"set_elementalist_raio_15": {"style": "ele_r15", "icon": "ele_r15", "color": Color(0.47, 0.48, 0.85), "set_name": "Conjunto Raio Glacial", "favor": "frost",
		"suffix": "do Raio Glacial"},
	"set_elementalist_raio_20": {"style": "ele_r20", "icon": "ele_r20", "color": Color(0.48, 0.4, 0.82), "set_name": "Conjunto Coroa do Trovão",
		"suffix": "do Trovão", "nouns": {"head": "Faixa"}},
	"set_elementalist_raio_25": {"style": "ele_r25", "icon": "ele_r25", "color": Color(0.58, 0.38, 0.63), "set_name": "Conjunto Tormenta de Fogo", "favor": "fire",
		"suffix": "da Tormenta"},
	"set_elementalist_raio_30": {"style": "ele_r30", "icon": "ele_r30", "color": Color(0.47, 0.48, 0.85), "set_name": "Conjunto Tempestade Cristalina", "favor": "frost",
		"adj": "Cristalina"},
	"set_necromancer_invocador_5": {"style": "nec_i5", "icon": "nec_i5", "color": Color(0.3, 0.5, 0.42), "set_name": "Conjunto Ossário",
		"suffix": "do Ossário"},
	"set_necromancer_invocador_10": {"style": "nec_i10", "icon": "nec_i10", "color": Color(0.55, 0.52, 0.45), "set_name": "Conjunto Coroa de Ossos",
		"suffix": "dos Ossos", "nouns": {"head": "Coroa"}},
	"set_necromancer_invocador_15": {"style": "nec_i15", "icon": "nec_i15", "color": Color(0.25, 0.55, 0.35), "set_name": "Conjunto Cripta Verde",
		"suffix": "da Cripta"},
	"set_necromancer_invocador_20": {"style": "nec_i20", "icon": "nec_i20", "color": Color(0.72, 0.7, 0.62), "set_name": "Conjunto Legião Pálida",
		"suffix": "da Legião", "nouns": {"head": "Coroa"}},
	"set_necromancer_invocador_25": {"style": "nec_i25", "icon": "nec_i25", "color": Color(0.2, 0.35, 0.3), "set_name": "Conjunto Senhor dos Túmulos",
		"suffix": "dos Túmulos"},
	"set_necromancer_invocador_30": {"style": "nec_i30", "icon": "nec_i30", "color": Color(0.35, 0.3, 0.4), "set_name": "Conjunto Rei dos Mortos",
		"suffix": "do Rei dos Mortos", "nouns": {"head": "Coroa"}},
	"set_necromancer_ceifador_5": {"style": "nec_c5", "icon": "nec_c5", "color": Color(0.4, 0.4, 0.42), "set_name": "Conjunto Ceifa Cinzenta",
		"suffix": "da Ceifa"},
	"set_necromancer_ceifador_10": {"style": "nec_c10", "icon": "nec_c10", "color": Color(0.55, 0.15, 0.18), "set_name": "Conjunto Mortalha Rubra",
		"suffix": "da Mortalha"},
	"set_necromancer_ceifador_15": {"style": "nec_c15", "icon": "nec_c15", "color": Color(0.18, 0.16, 0.2), "set_name": "Conjunto Chifre Negro",
		"suffix": "do Chifre Negro"},
	"set_necromancer_ceifador_20": {"style": "nec_c20", "icon": "nec_c20", "color": Color(0.35, 0.42, 0.5), "set_name": "Conjunto Corrente Fria",
		"suffix": "da Corrente"},
	"set_necromancer_ceifador_25": {"style": "nec_c25", "icon": "nec_c25", "color": Color(0.5, 0.12, 0.08), "set_name": "Conjunto Pacto Infernal",
		"suffix": "do Pacto"},
	"set_necromancer_ceifador_30": {"style": "nec_c30", "icon": "nec_c30", "color": Color(0.12, 0.1, 0.12), "set_name": "Conjunto Arauto do Fim",
		"suffix": "do Arauto"},
	"set_necromancer_pestilento_5": {"style": "nec_s5", "icon": "nec_s5", "color": Color(0.35, 0.28, 0.5), "set_name": "Conjunto Sussurro",
		"suffix": "do Sussurro"},
	"set_necromancer_pestilento_10": {"style": "nec_s10", "icon": "nec_s10", "color": Color(0.45, 0.3, 0.55), "set_name": "Conjunto Olho Aberto",
		"suffix": "do Olho", "nouns": {"head": "Diadema"}},
	"set_necromancer_pestilento_15": {"style": "nec_s15", "icon": "nec_s15", "color": Color(0.2, 0.15, 0.35), "set_name": "Conjunto Véu do Vazio",
		"suffix": "do Vazio"},
	"set_necromancer_pestilento_20": {"style": "nec_s20", "icon": "nec_s20", "color": Color(0.5, 0.25, 0.45), "set_name": "Conjunto Mente Partida",
		"suffix": "da Mente", "nouns": {"head": "Diadema"}},
	"set_necromancer_pestilento_25": {"style": "nec_s25", "icon": "nec_s25", "color": Color(0.15, 0.12, 0.25), "set_name": "Conjunto Eclipse",
		"suffix": "do Eclipse"},
	"set_necromancer_pestilento_30": {"style": "nec_s30", "icon": "nec_s30", "color": Color(0.3, 0.1, 0.4), "set_name": "Conjunto Abismo",
		"suffix": "do Abismo"},
}
const DAMAGE_KINDS := [SkillDef.Kind.PHYSICAL, SkillDef.Kind.MAGICAL, SkillDef.Kind.HEAL]


## Fator de poder por nível (1.0 no nível de referência).
static func level_factor(level: int) -> float:
	return (float(level) + Balance.GEAR_LEVEL_OFFSET) / (Balance.GEAR_REF_LEVEL + Balance.GEAR_LEVEL_OFFSET)

## Atributos na escala antiga com uma casa (= ponto inteiro na escala nova, GameData._scale_attrs arredonda depois do
## x ATTR_SCALE). Arredondar aqui para inteiro achatava as peças leves: anel/capa de Bronze, Ferro e Mitril davam o mesmo.
## Piso de 1 (10 na escala nova), como antes: as peças de nível 1 não mudam.
static func _attrs(primary: String, secondary: String, level: int, weight: float, mult: float) -> Dictionary:
	var step := 1.0 / Balance.ATTR_SCALE
	var a := {}
	a[primary] = maxf(1.0, snappedf(Balance.GEAR_ATTR_PRIMARY_PER_LEVEL * level * weight * mult, step))
	if secondary != primary:
		a[secondary] = maxf(1.0, snappedf(Balance.GEAR_ATTR_SECONDARY_PER_LEVEL * level * weight * mult, step))
	return a

static func _price(level: int, weight: float, mult: float) -> int:
	return int(round((Balance.GEAR_PRICE_BASE + level * level * Balance.GEAR_PRICE_PER_LV2) * weight * mult))

## Item de arma/mão secundária gerado a partir de WEAPONS. Armas de 1 mão vão no slot WEAPON e
## podem ser equipadas na mão secundária (WorldSim.equip com to_offhand).
static func weapon_item(id: String, name: String, wtype: String, level: int, rarity: int, mult: float, color: Color, weight: float = -1.0) -> ItemDef:
	var b: Array = WEAPONS[wtype]
	var w: float = PIECE_WEIGHT["weapon"] if weight < 0.0 else weight
	var f := level_factor(level) * mult
	var it := ItemDef.new()
	it.id = id
	it.name = name
	it.type = EQ
	it.slot = S.OFFHAND if wtype in ItemDef.OFFHAND_ONLY else S.WEAPON
	it.weapon_type = wtype
	it.level_req = level
	it.rarity = rarity
	it.atk = round(float(b[0]) * f)
	it.matk = round(float(b[1]) * f)
	it.def = round(float(b[2]) * f)
	it.mdef = round(float(b[3]) * f)
	it.attributes = _attrs(b[4], b[5], level, w, mult)
	it.price = _price(level, w, mult)
	it.stack_max = 1
	it.icon_color = color
	if it.is_two_handed():
		it.description = "Duas mãos."
	return it

static func armor_item(id: String, name: String, piece: String, armor: String, attr: String, attr2: String, level: int, rarity: int, mult: float, color: Color) -> ItemDef:
	var w: float = PIECE_WEIGHT[piece]
	var f := level_factor(level) * mult * w
	var it := ItemDef.new()
	it.id = id
	it.name = name
	it.type = EQ
	it.slot = PIECE_SLOT[piece]
	it.level_req = level
	it.rarity = rarity
	it.def = round(float(ARMOR[armor][0]) * f)
	it.mdef = round(float(ARMOR[armor][1]) * f)
	it.armor_style = armor
	it.attributes = _attrs(attr, attr2, level, w, mult)
	it.price = _price(level, w, mult)
	it.stack_max = 1
	it.icon_color = color
	return it


## Calças, capas, amuletos e anéis comuns de um tier. Sem restrição de classe: qualquer um usa.
static func wearables(tier: int) -> Array:
	var out: Array = []
	var lv: int = Balance.COMMON_TIER_LEVELS[tier]
	for armor in LEGS:
		var l: Array = LEGS[armor]
		var col := Color(0.42, 0.36, 0.3).lerp(Color(0.72, 0.72, 0.8), minf(1.0, tier / 3.0))
		if COMMON_TIER_TINT.has(tier):
			col = (COMMON_TIER_TINT[tier] as Color).darkened(0.15)
		out.append(armor_item("legs_%s_t%d" % [armor, tier], "%s %s" % [l[0], COMMON_TIER_NAMES[tier]], "legs", armor, l[1], l[2], lv, common_rarity(tier), 1.0, col))
	for piece in THEME_PIECES:
		for theme in THEMES:
			var t: Array = THEMES[theme]
			var col: Color = (t[3] as Color).lightened(tier * 0.08)
			var it := armor_item("%s_%s_t%d" % [piece, theme, tier], "%s %s %s" % [THEME_PIECES[piece], t[0], COMMON_TIER_NAMES[tier]], piece, "leather", t[1], t[2], lv, common_rarity(tier), 1.0, col)
			it.armor_style = "cape" if piece == "cape" else ""
			if piece != "cape":
				it.def = 0.0
				it.mdef = 0.0
			out.append(it)
	return out

## Joias e capas de Kharzun (nível 45, só por receita com troféu de chefe: RecipesCatalog.kharzun_recipes).
## Mesmo tema/atributos das comuns, no nível 45 e com Balance.KHARZUN_JEWEL_MULT; raridade épica. Ids `<peça>_<tema>_k45`.
static func kharzun_jewels() -> Array:
	var out: Array = []
	var lv: int = Balance.KHARZUN_JEWEL_LEVEL
	for piece in THEME_PIECES:
		for theme in THEMES:
			var t: Array = THEMES[theme]
			var col: Color = (t[3] as Color).lerp(Color(1.0, 0.45, 0.15), 0.3)        # brasa da montanha na cor do tema
			var it := armor_item("%s_%s_k45" % [piece, theme], "%s %s de Kharzun" % [THEME_PIECES[piece], t[0]], piece, "leather", t[1], t[2], lv,
				ItemDef.RARITY_LEGENDARY - 1, Balance.KHARZUN_JEWEL_MULT, col)
			it.armor_style = "cape" if piece == "cape" else ""
			if piece != "cape":
				it.def = 0.0
				it.mdef = 0.0
			out.append(it)
	return out

## Peça que só sai da forja (joias/capas 45 com troféu): bots não a recebem de graça ao nascer.
static func craft_only(it: ItemDef) -> bool:
	return it.id.ends_with("_k45")

## Escudos nomeados como itens lendários (peso da mão secundária).
## Para quem é o escudo nomeado: "paladin", "bishop" ou "both" (SHIELD_AFFINITY; sem entrada = ambos).
static func shield_affinity(shield_key: String) -> String:
	return SHIELD_AFFINITY.get(shield_key, "both")

static func shield_fits(shield_item_id: String, class_id: String) -> bool:
	var aff := shield_affinity(shield_item_id.trim_prefix("shield_"))
	return aff == "both" or aff == class_id

static func named_shields() -> Array:
	var out: Array = []
	for d in SHIELDS:
		var it := weapon_item("shield_" + d[0], d[1], "shield", d[2], ItemDef.RARITY_LEGENDARY, Balance.LEGENDARY_MULT, d[4], PIECE_WEIGHT["offhand"])
		it.shield_style = d[3]
		var aff: String = shield_affinity(d[0])     # atributos de quem usa: Paladino VIT/FOR, Bispo e ambos VIT/WILL
		it.attributes = _attrs("VIT", "FOR" if aff == "paladin" else "WILL", d[2], PIECE_WEIGHT["offhand"], Balance.LEGENDARY_MULT)
		it.shield_effect = d[5]
		it.description = d[6]
		it.icon = "shield_" + d[0]
		out.append(it)
	return out

## O que o mercador vende além das poções.
static func shop_ids() -> Array:
	var out: Array = []
	for tier in range(Balance.GEAR_SHOP_TIERS):
		for it in wearables(tier):
			if not (it.slot in [ItemDef.Slot.CAPE, ItemDef.Slot.AMULET, ItemDef.Slot.RING]):     # joias e capas: só na forja/alquimista
				out.append(it.id)
	return out

## Armas e mãos secundárias comuns de nível 1 de todos os tipos (toda build começa com a arma dela na loja).
static func starter_weapon_ids(items: Dictionary) -> Array:
	var out: Array = []
	for iid in items:
		var it: ItemDef = items[iid]
		if it.slot in [ItemDef.Slot.WEAPON, ItemDef.Slot.OFFHAND] and it.level_req <= 1 and not it.is_legendary() and it.set_id == "" and it.price > 0 \
				and it.shield_style == "":
			out.append(iid)
	out.sort()
	return out

## Skills que o conjunto (build, tier) fortalece: 4 peças = dano/cura de uma skill de ataque/cura da build;
## 5 peças = recarga de outra. Percorre as skills da build em prioridade, só as já liberadas no nível.
static func set_skills(build: Dictionary, skills: Dictionary, level: int, tier: int) -> Array:
	var avail: Array = []
	for sid in build["skills"]:
		var s: SkillDef = skills.get(sid)
		if s and s.unlock_level <= level:
			avail.append(s)
	var dmg: Array = avail.filter(func(s): return s.kind in DAMAGE_KINDS)
	var dmg_skill: SkillDef = dmg[mini(tier, dmg.size() - 1)]
	var rest: Array = avail.filter(func(s): return s != dmg_skill)
	var cdr_skill: SkillDef = rest[mini(tier, rest.size() - 1)] if rest.size() > 0 else dmg_skill
	return [dmg_skill.id, cdr_skill.id]

## Bônus de um conjunto (tier = 0..5). Números em Balance.SET_*.
## Efeito da arma lendária de cada build (a cara dela). Números: [base, por tier]. Tipos (WorldSim._legend_*):
## cast_on_basic (acertar com ataque ou habilidade lança a skill; Balance.LEG_CAST_ICD), cast_when_hit (ao levar golpe lança a skill; icd = s entre usos),
## chain (básico pula para +N alvos), stun, frenzy (cada golpe acumula vel. de ataque), execute (dano extra em alvo
## abaixo de `below`), prey (dano extra em alvo retardado, preso ou atordoado), bleed/poison (dano no tempo do ATK), mark (alvo recebe mais dano de todos), splash (básico
## explode em volta), riposte (esquivar contra-ataca), raise_on_kill (abate levanta um esqueleto), heal_on_kill,
## thorns (devolve corpo a corpo), ward (cura vira barreira), echo (golpe bate de novo; reserva),
## penance (cada golpe põe uma carga de Penitência no alvo; com `stacks` explode em fogo sagrado: `pct`% do ATK em `radius`),
## mend (parte do dano do golpe cura o aliado mais ferido por perto, você incluso), open_wound (cada golpe abre uma Ferida no alvo, até `max`: +`pct`% do seu dano nele por ferida; com todas
## abertas ele sangra `bleed`% do ATK por segundo), spare_shot (Corsário com pistola: golpe às vezes dispara um tiro de graça no alvo,
## `pct`% do ATK, +1 Bravata; Balance.LEG_SHOT_ICD).
## fist_counter (Punhos de Fúria com duas garras: o contra-ataque da esquiva causa +`pct`% do ATK; FistSystem).

## Efeito da arma lendária da build no tier: identidade em `build["legend"]` (classes_catalog), números em
## Balance.LEGEND_NUMBERS[<build>] ([base, por tier] viram números).
static func legend_effect(build: Dictionary, tier: int) -> Dictionary:
	var out: Dictionary = (build["legend"] as Dictionary).duplicate()
	var nums: Dictionary = Balance.LEGEND_NUMBERS[build["id"]]
	for k in nums:
		var v = nums[k]
		out[k] = round((float(v[0]) + float(v[1]) * tier) * 100.0) / 100.0 if v is Array else v
	if out.has("targets"):
		out["targets"] = int(out["targets"])
	return out

static func set_bonuses(build: Dictionary, dmg_skill: String, cdr_skill: String, tier: int) -> Dictionary:
	var b := {}
	var tf := Balance.set_pct_tier(tier)       # bônus percentuais: acima do tier 5 crescem pela metade (GDD Ato II F10)
	b[2] = {"attrs": {build["attr2"]: Balance.SET_2PC_ATTR_BASE + Balance.SET_2PC_ATTR_PER_TIER * tier}}
	b[3] = {"attrs": {build["attr"]: Balance.SET_3PC_ATTR_BASE + Balance.SET_3PC_ATTR_PER_TIER * tier}}
	b[4] = {"skill_dmg": {dmg_skill: Balance.SET_4PC_SKILL_DMG_BASE + Balance.SET_4PC_SKILL_DMG_PER_TIER * tf}}
	b[5] = {build["stat"]: Balance.SET_5PC_STAT_PCT_BASE + Balance.SET_5PC_STAT_PCT_PER_TIER * tf,
		"skill_cdr": {cdr_skill: Balance.SET_5PC_CDR_BASE + Balance.SET_5PC_CDR_PER_TIER * tf}}
	# extra da build (ex.: roubo de vida, vida/defesa): {peças: {stat: [base, por tier]}}
	var extra: Dictionary = build.get("set_extra", {})
	for n in extra:
		for k in extra[n]:
			b[int(n)][k] = round((float(extra[n][k][0]) + float(extra[n][k][1]) * tier) * 10.0) / 10.0
	return b


## Conjuntos híbridos (GDD Ato II R7.1): um por par de builds da classe (A+B, B+C, C+A) em Balance.HYBRID_LEVELS.
## Armadura, atributo principal e visual (estilo) de A, atributo secundário e cor de B; as armas das duas builds como
## peças alternativas (não contam). Bônus: 2 = o 2 de A, 3 = o 3 de B, 4 = metade do 4 de A e de B, 5 = a Fusão.
## Fusões: nome, complemento das peças e texto de cada face (chave = build cuja arma liga a face; "all" = uma face só).
const FUSIONS := {
	"guardiao+cruzado": {"name": "Juramento Rubro", "of": "do Juramento Rubro", "text": {
		"cruzado": "golpes diretos dão Juramento; skill sagrada que gasta 3+ cargas provoca quem acerta",
		"guardiao": "com Juramento cheio, bloquear pode atordoar quem bateu"}},
	"cruzado+templario": {"name": "Sentença Ardente", "of": "da Sentença Ardente", "text": {
		"cruzado": "golpes diretos põem Penitência; cada carga no alvo aumenta todo o seu dano nele; na 5ª explode e volta a 2",
		"templario": "golpes diretos põem Penitência (cada carga aumenta seu dano no alvo; na 5ª explode e volta a 2); a explosão atordoa"}},
	"templario+guardiao": {"name": "Égide Ardente", "of": "da Égide Ardente", "text": {
		"all": "bloquear põe Penitência no atacante; a explosão dá 2 de Juramento"}},
	"carniceiro+executor": {"name": "Carrasco Frenético", "of": "do Carrasco Frenético", "text": {
		"all": "golpes dão Frenesi; o limiar de execução sobe com o Frenesi"}},
	"executor+punhos": {"name": "Peso do Titã", "of": "do Peso do Titã", "text": {
		"executor": "crítico ou esquiva dá Peso (próxima skill mais forte); +esquiva e contra-ataque com o machado",
		"punhos": "crítico ou esquiva dá Peso: a próxima skill de golpe bate mais forte"}},
	"punhos+carniceiro": {"name": "Turbilhão Feroz", "of": "do Turbilhão Feroz", "text": {
		"all": "crítico ou esquiva dá 2 de Frenesi; com Frenesi cheio, +esquiva e contra-ataque"}},
	"sacerdote+inquisidor": {"name": "Luz que Julga", "of": "da Luz que Julga", "text": {
		"all": "a cura que passa do máximo vira dano sagrado no inimigo mais perto do aliado"}},
	"inquisidor+batalha": {"name": "Martelo da Aurora", "of": "do Martelo da Aurora", "text": {
		"all": "magia sagrada dá Aurora (+ATK e +MATK por 4 s); golpes de arma curam o aliado mais ferido"}},
	"batalha+sacerdote": {"name": "Graça em Combate", "of": "da Graça em Combate", "text": {
		"all": "a cada 3 golpes de maça a Graça dispara e o aliado curado ganha uma Égide"}},
	"guardiao_verde+fera": {"name": "Bramido da Matilha", "of": "do Bramido da Matilha", "text": {
		"guardiao_verde": "o Urro da Mata chama 2 lobos espirituais e dá Frenesi ao grupo",
		"fera": "o Frenesi provoca os inimigos perto de você"}},
	"fera+xama": {"name": "Lua Caçadora", "of": "da Lua Caçadora", "text": {
		"fera": "todo o seu dano em alvo sangrando (a Mordida conta) ou com Fogo Lunar é maior",
		"xama": "Fogo Lunar também faz sangrar; suas magias em alvo sangrando causam mais dano"}},
	"xama+guardiao_verde": {"name": "Casca Partilhada", "of": "da Casca Partilhada", "text": {
		"guardiao_verde": "ao ser atingido, a Pele de Carvalho também cobre o aliado mais ferido",
		"xama": "magias em alvo preso ou na área do Ent causam mais dano"}},
	"cacador+atirador": {"name": "Posto de Caça", "of": "do Posto de Caça", "text": {
		"atirador": "+1 torreta ativa",
		"cacador": "o Ataque da Fera arma uma Armadilha de Gelo; o companheiro bate mais em alvo retardado"}},
	"atirador+lanceiro": {"name": "Trincheira", "of": "da Trincheira", "text": {
		"atirador": "aliados perto da sua torreta regeneram vida",
		"lanceiro": "o Dardo de Caça crava uma Estaca: aliados perto dela regeneram vida"}},
	"lanceiro+cacador": {"name": "Caça em Dupla", "of": "da Caça em Dupla", "text": {
		"lanceiro": "golpes abrem Feridas (2 em alvo retardado ou preso)",
		"cacador": "o companheiro abre Feridas e bate mais por Ferida no alvo"}},
	"laminas+duelista": {"name": "Passo Fantasma", "of": "do Passo Fantasma", "text": {
		"all": "avançar ou esquivar deixa o próximo golpe furtivo"}},
	"duelista+corsario": {"name": "Duelo de Pólvora", "of": "do Duelo de Pólvora", "text": {
		"corsario": "crítico dá Bravata; Bravata cheia dispara a pistola de graça",
		"duelista": "crítico dá Bravata; Bravata cheia vira Foco do Duelista"}},
	"corsario+laminas": {"name": "Pólvora Envenenada", "of": "da Pólvora Envenenada", "text": {
		"corsario": "tiros envenenam; cada veneno seu no alvo fortalece o próximo tiro",
		"laminas": "Dardo Venenoso e Leque de Facas dão Bravata por alvo envenenado"}},
	"fogo+gelo": {"name": "Vapor", "of": "do Vapor", "text": {
		"all": "gelo em alvo queimando, ou fogo em alvo retardado, apaga a queimadura e causa o dano dela na hora"}},
	"gelo+raio": {"name": "Supercondutor", "of": "do Supercondutor", "text": {
		"all": "raio em alvo retardado salta para +1 alvo; gelo em alvo eletrificado bate mais"}},
	"raio+fogo": {"name": "Plasma", "of": "do Plasma", "text": {
		"all": "raio em alvo queimando espalha a queimadura; fogo em alvo eletrificado bate mais"}},
	"invocador+ceifador": {"name": "Ceifa Partilhada", "of": "da Ceifa Partilhada", "text": {
		"all": "abates das invocações curam você; golpes curam a invocação mais ferida"}},
	"ceifador+pestilento": {"name": "Colheita da Praga", "of": "da Colheita da Praga", "text": {
		"all": "golpes de foice põem Praga Menor (maldição, até 3); cada maldição sua no alvo dá dano e roubo de vida à foice; amaldiçoado que morre explode"}},
	"pestilento+invocador": {"name": "Pestilência Viva", "of": "da Pestilência Viva", "text": {
		"all": "invocações aplicam Agonia; cada maldição no alvo fortalece as invocações"}},
}
const HYBRID_NUMERALS := ["I", "II", "III", "IV", "V"]

## Pares de builds da classe: [A, B] na ordem A+B, B+C, C+A.
static func hybrid_pairs(cls: ClassDef) -> Array:
	var out: Array = []
	var n := cls.builds.size()
	if n < 2:
		return out
	for i in range(n if n > 2 else 1):
		out.append([str(cls.builds[i]["id"]), str(cls.builds[(i + 1) % n]["id"])])
	return out

static func hybrid_set_id(class_id: String, a: String, b: String, level: int) -> String:
	return "set_%s_mix_%s_%s_%d" % [class_id, a, b, level]

## Números da Fusão no tier (F-FUS1): v35 + passo × (i − 6).
static func fusion_numbers(fid: String, tier: int) -> Dictionary:
	var out := {}
	var nums: Dictionary = Balance.FUSION_NUMBERS.get(fid, {})
	for k in nums:
		var v = nums[k]
		out[k] = snappedf(float(v[0]) + float(v[1]) * (tier - 6), 0.01) if v is Array else v
	return out

## Bônus do híbrido A+B no tier (R7.1).
static func hybrid_bonuses(ba: Dictionary, bb: Dictionary, skills: Dictionary, lv: int, tier: int, fid: String) -> Dictionary:
	var pa := set_skills(ba, skills, lv, tier)
	var pb := set_skills(bb, skills, lv, tier)
	var na := set_bonuses(ba, pa[0], pa[1], tier)
	var nb := set_bonuses(bb, pb[0], pb[1], tier)
	var b := {}
	b[2] = (na[2] as Dictionary).duplicate(true)
	b[3] = (nb[3] as Dictionary).duplicate(true)
	var d4 := {}
	for src in [na[4], nb[4]]:
		var sd: Dictionary = src.get("skill_dmg", {})
		for sid in sd:
			d4[sid] = round((float(d4.get(sid, 0.0)) + float(sd[sid]) * Balance.HYBRID_4PC_SHARE) * 10.0) / 10.0
	b[4] = {"skill_dmg": d4}
	var f := fusion_numbers(fid, tier)
	f["id"] = fid
	b[5] = {"fusion": f}
	return b

## O 5 peças normal que a Fusão substitui (do lado A): referência de orçamento (F-FUS2, boss_probe --set=h5n).
static func hybrid_normal_five(sd: SetDef, classes: Dictionary, skills: Dictionary) -> Dictionary:
	var cls: ClassDef = classes[sd.class_id]
	var ba: Dictionary = cls.build_by_id(sd.pair[0])
	var tier := Balance.legend_tier(sd.level)
	var pa := set_skills(ba, skills, sd.level, tier)
	return set_bonuses(ba, pa[0], pa[1], tier)[5]

static func hybrid_sets(classes: Dictionary, skills: Dictionary) -> Dictionary:
	var items: Array = []
	var sets: Array = []
	var mult: float = Balance.LEGENDARY_MULT
	for cid in classes:
		var cls: ClassDef = classes[cid]
		var restrict: Array[String] = [cid]
		for pair in hybrid_pairs(cls):
			var ba: Dictionary = cls.build_by_id(pair[0])
			var bb: Dictionary = cls.build_by_id(pair[1])
			var fid := "%s+%s" % pair
			var fu: Dictionary = FUSIONS[fid]
			for hi in range(Balance.HYBRID_LEVELS.size()):
				var lv: int = Balance.HYBRID_LEVELS[hi]
				var tier := Balance.legend_tier(lv)
				var tail := "%s %s" % [fu["of"], HYBRID_NUMERALS[hi]]
				var sd := SetDef.new()
				sd.id = hybrid_set_id(cid, pair[0], pair[1], lv)
				sd.name = "Conjunto %s %s" % [fu["name"], HYBRID_NUMERALS[hi]]
				sd.class_id = cid
				sd.level = lv
				sd.pair.assign(pair)
				sd.fusion = fid
				var base := "leg_%s_mix_%s_%s_%d" % [cid, pair[0], pair[1], lv]
				# visual: o conjunto de A no maior nível com visual, na cor do conjunto de B (fatia 1; modelos no polimento)
				var va := visual_of("set_%s_%s_%d" % [cid, pair[0], OWN_VISUALS_UNTIL])
				var vb := visual_of("set_%s_%s_%d" % [cid, pair[1], OWN_VISUALS_UNTIL])
				var col: Color = vb.get("color", cls.color.lerp(LEGENDARY_COLOR, 0.35))
				var made: Array = []
				for piece in PIECES:
					var noun: String = ARMOR_NAMES[ba["armor"]]["legs"] if piece == "legs" else str(PIECE_NOUNS["%s_%s" % [cid, pair[0]]].get(piece, ARMOR_NAMES[ba["armor"]][piece]))
					var it := armor_item("%s_%s" % [base, piece], "%s %s" % [noun, tail], piece, ba["armor"], ba["attr"], bb["attr"], lv, ItemDef.RARITY_LEGENDARY, mult, col)
					if piece != "legs" and va.has("style"):
						it.armor_style = va["style"]
						it.icon = "%s_%s" % [va["icon"], piece] if va.has("icon") else ""
					sd.armor.append(it.id)
					sd.pieces.append(it.id)
					made.append(it)
				# armas: as das duas builds, cada uma com o efeito lendário da própria build
				var names := {}
				for bd in [ba, bb]:
					var bid: String = bd["id"]
					var other: String = bb["attr"] if bid == pair[0] else ba["attr"]
					var vw := visual_of("set_%s_%s_%d" % [cid, bid, OWN_VISUALS_UNTIL])
					var wl: Array = []
					var main_t: String = bd["main"][0]
					var nouns: Dictionary = PIECE_NOUNS["%s_%s" % [cid, bid]]
					var wpn := weapon_item("%s_%s_weapon" % [base, bid], "%s %s" % [str(nouns.get("weapon", WEAPON_NAMES[main_t])), tail], main_t, lv, ItemDef.RARITY_LEGENDARY, mult, col)
					wpn.attributes = _attrs(bd["attr"], other, lv, PIECE_WEIGHT["weapon"], mult)
					if bd["stat"] == "matk_pct":
						wpn.matk = maxf(wpn.matk, round(wpn.atk * Balance.LEGEND_MATK_FROM_ATK))
					wpn.legend_effect = legend_effect(bd, tier)
					wl.append(wpn)
					if bd["off"].size() > 0:
						var off_t: String = bd["off"][0]
						var off := weapon_item("%s_%s_offhand" % [base, bid], "%s %s" % [str(nouns.get("offhand", WEAPON_NAMES[off_t])), tail], off_t, lv, ItemDef.RARITY_LEGENDARY, mult, col, PIECE_WEIGHT["offhand"])
						off.attributes = _attrs(bd["attr"], other, lv, PIECE_WEIGHT["offhand"], mult)
						wl.append(off)
					for w in wl:
						var piece: String = "offhand" if w.id.ends_with("_offhand") else "weapon"
						if vw.has("style"):
							if w.weapon_type == "shield":
								w.shield_style = vw["style"]
							elif w.slot == S.WEAPON or w.weapon_type == "pistol":
								w.weapon_style = vw["style"]
							if vw.has("icon"):
								w.icon = "%s_%s" % [vw["icon"], piece]
						if names.has(w.name):          # mesma arma nas duas builds: o nome leva o efeito lendário
							w.name = "%s (%s)" % [w.name, str(bd["legend"]["name"])]
						names[w.name] = true
						sd.alt_pieces.append(w.id)
						made.append(w)
				for it in made:
					it.set_id = sd.id
					it.class_restriction = restrict
					var hands := "Duas mãos. " if it.is_two_handed() else ""
					if it.id.ends_with("_offhand") and it.slot == S.WEAPON:
						hands = "Mão secundária (Shift+clique na bolsa). "
					if it.slot in [S.WEAPON, S.OFFHAND]:
						it.description = "%sArma do %s (%s, híbrido %s + %s): não conta nas peças; tem efeito lendário próprio." % [hands, sd.name, cls.name, ba["name"], bb["name"]]
					else:
						it.description = "Peça do %s (%s, híbrido %s + %s)." % [sd.name, cls.name, ba["name"], bb["name"]]
				items.append_array(made)
				sd.bonuses = hybrid_bonuses(ba, bb, skills, lv, tier, fid)
				sets.append(sd)
	return {"items": items, "sets": sets}

## Gera tudo. Retorna {"items": [ItemDef], "sets": [SetDef]}.
static func build(classes: Dictionary, skills: Dictionary) -> Dictionary:
	var items: Array = []
	var sets: Array = []
	# 1) armas comuns dos tipos novos em todos os tiers; nos tiers sem itens à mão, todos os tipos e as armaduras
	for tier in range(Balance.COMMON_TIER_LEVELS.size()):
		var lv: int = Balance.COMMON_TIER_LEVELS[tier]
		var full := tier >= HAND_WRITTEN_TIERS
		var col := Color(0.6, 0.55, 0.45).lerp(Color(0.85, 0.85, 0.95), minf(1.0, tier / 3.0))
		if COMMON_TIER_TINT.has(tier):
			col = COMMON_TIER_TINT[tier]
		for wtype in (WEAPONS.keys() if full else NEW_COMMON_TYPES):
			var nm := "%s %s" % [WEAPON_NAMES[wtype], COMMON_TIER_NAMES[tier]]
			items.append(weapon_item("%s_t%d" % [wtype, tier], nm, wtype, lv, common_rarity(tier), 1.0, col,
				PIECE_WEIGHT["offhand"] if wtype in ItemDef.OFFHAND_ONLY else -1.0))
		if full:
			for armor in ARMOR:
				for piece in FULL_PIECES:
					items.append(armor_item("%s_%s_t%d" % [piece, armor, tier], "%s %s" % [ARMOR_NAMES[armor][piece], COMMON_TIER_NAMES[tier]],
						piece, armor, LEGS[armor][1], LEGS[armor][2], lv, common_rarity(tier), 1.0, col))
		items.append_array(wearables(tier))
	items.append_array(kharzun_jewels())
	items.append_array(named_shields())
	# 2) conjuntos lendários: classe × build × nível
	var mult: float = Balance.LEGENDARY_MULT
	for cid in classes:
		var cls: ClassDef = classes[cid]
		var restrict: Array[String] = [cid]
		for build in cls.builds:
			var bid: String = build["id"]
			var of: String = build["of"]
			var col: Color = cls.color.lerp(LEGENDARY_COLOR, 0.35)
			for tier in range(Balance.LEGENDARY_LEVELS.size()):
				var lv: int = Balance.LEGENDARY_LEVELS[tier]
				var tail := "%s %s" % [of, TIER_EPITHETS[tier]]
				var sd := SetDef.new()
				sd.id = "set_%s_%s_%d" % [cid, bid, lv]
				sd.name = "Conjunto %s %s" % [build["name"], TIER_EPITHETS[tier]]
				sd.class_id = cid
				sd.level = lv
				var made: Array = []
				for piece in PIECES:
					made.append(armor_item("leg_%s_%s_%d_%s" % [cid, bid, lv, piece], "%s %s" % [ARMOR_NAMES[build["armor"]][piece], tail],
						piece, build["armor"], build["attr"], build["attr2"], lv, ItemDef.RARITY_LEGENDARY, mult, col))
				var main_t: String = build["main"][0]
				var wpn := weapon_item("leg_%s_%s_%d_weapon" % [cid, bid, lv], "%s %s" % [WEAPON_NAMES[main_t], tail], main_t, lv, ItemDef.RARITY_LEGENDARY, mult, col)
				# a arma lendária serve à build: atributos dela, e MATK de verdade em build mágica de arma física
				wpn.attributes = _attrs(build["attr"], build["attr2"], lv, PIECE_WEIGHT["weapon"], mult)
				if build["stat"] == "matk_pct":
					wpn.matk = maxf(wpn.matk, round(wpn.atk * Balance.LEGEND_MATK_FROM_ATK))
				wpn.legend_effect = legend_effect(build, tier)
				made.append(wpn)
				var alts := {}
				# conjunto com visual próprio e build de duas armas (espada ou maça): a outra também vira peça do conjunto
				var vis: Dictionary = visual_of(sd.id)
				if not vis.is_empty() and build["main"].size() > 1:
					var alt_t: String = build["main"][1]
					var alt := weapon_item("leg_%s_%s_%d_%s" % [cid, bid, lv, alt_t], "%s %s" % [WEAPON_NAMES[alt_t], tail], alt_t, lv, ItemDef.RARITY_LEGENDARY, mult, col)
					alt.attributes = wpn.attributes.duplicate()
					alt.legend_effect = wpn.legend_effect.duplicate()
					if build["stat"] == "matk_pct":
						alt.matk = maxf(alt.matk, round(alt.atk * Balance.LEGEND_MATK_FROM_ATK))
					made.append(alt)
					alts[alt.id] = true
				if build["off"].size() > 0:
					var off_t: String = build["off"][0]
					var off_name: String = WEAPON_NAMES[off_t] + ("" if off_t in ItemDef.OFFHAND_ONLY else " Gêmea")
					var off := weapon_item("leg_%s_%s_%d_offhand" % [cid, bid, lv], "%s %s" % [off_name, tail], off_t, lv, ItemDef.RARITY_LEGENDARY, mult, col, PIECE_WEIGHT["offhand"])
					off.attributes = _attrs(build["attr"], build["attr2"], lv, PIECE_WEIGHT["offhand"], mult)     # serve à build (escudo do Sacerdote dá WILL, não FOR)
					made.append(off)
				if vis.has("set_name"):
					sd.name = vis["set_name"]
				for it in made:
					if not vis.is_empty():
						var piece: String = it.id.get_slice("_", it.id.get_slice_count("_") - 1)
						if vis.has("reuse"):          # visual reaproveitado (Ato II): nome genérico da regra
							pass
						elif vis.has("names"):          # conjunto escrito à mão
							it.name = vis["names"].get(piece, it.name)
							if piece == "legs" and not vis["names"].has("legs"):      # calça do conjunto: nome tirado do peito (mesmo "do X")
								var bn: String = vis["names"].get("body", "")
								if bn.find(" ") > 0:
									it.name = ARMOR_NAMES[build["armor"]]["legs"] + bn.substr(bn.find(" "))
						else:
							var nm := set_piece_name(vis, bid_of_set(sd.id), piece, build["armor"])
							if nm != "":
								it.name = nm
						if alts.has(it.id) and not vis.has("reuse"):         # maça do conjunto: mesmo nome da espada, trocando a arma
							if vis.has("names"):
								it.name = (vis["names"].get("weapon", it.name) as String).replace("Espada", WEAPON_NAMES[it.weapon_type])
							else:
								it.name = noun_with(vis, WEAPON_NAMES[it.weapon_type])
						it.icon_color = vis["color"]
						it.icon = "%s_%s" % [vis["icon"], piece] if vis.has("icon") and piece != "legs" else ""     # calça: arte pintada
						if it.armor_style != "" and piece != "legs":     # calça: a do estilo da build (o kit tem), na cor do conjunto
							it.armor_style = vis["style"]
						elif it.slot == S.WEAPON:
							it.weapon_style = vis["style"]          # arma própria do conjunto (paladin_sets / berserker_sets); vale na mão secundária
						elif it.weapon_type == "shield":
							it.shield_style = vis["style"]
						elif it.weapon_type == "pistol":
							it.weapon_style = vis["style"]          # pistola própria do conjunto (assassin_sets.ASS_WEAPONS, wpn_off_pistol_<estilo>)          # escudo próprio do conjunto (paladin_sets.SET_SHIELDS)
					it.set_id = sd.id
					it.class_restriction = restrict
					var hands := "Duas mãos. " if it.is_two_handed() else ""
					if it.slot == S.WEAPON and it.id.ends_with("_offhand"):
						hands = "Mão secundária (Shift+clique na bolsa). "
					it.description = "%sPeça do %s (%s)." % [hands, sd.name, cls.name]
					if it.slot in [S.WEAPON, S.OFFHAND]:
						it.description = "%sArma do %s (%s): não conta nas peças; %s" % [hands, sd.name, cls.name, "tem efeito lendário próprio." if not it.legend_effect.is_empty() else "acompanha o conjunto."]
					elif not sd.armor.has(it.id):
						sd.armor.append(it.id)
					items.append(it)
					if alts.has(it.id):
						sd.alt_pieces.append(it.id)
					else:
						sd.pieces.append(it.id)
				var picks := set_skills(build, skills, lv, tier)
				sd.bonuses = set_bonuses(build, picks[0], picks[1], tier)
				var favor: String = vis.get("favor", "")
				if favor != "":         # conjunto de combinação (Elementalista): 4 peças dão o segundo elemento
					sd.bonuses[4][favor + "_pct"] = round((Balance.SET_FAVOR_BASE + Balance.SET_FAVOR_PER_TIER * Balance.set_pct_tier(tier)) * 10.0) / 10.0
				sets.append(sd)
	var hyb := hybrid_sets(classes, skills)          # 3) conjuntos híbridos 35/40/45 (R7.1)
	items.append_array(hyb["items"])
	sets.append_array(hyb["sets"])
	return {"items": items, "sets": sets}
