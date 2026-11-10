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
const COMMON_TIER_NAMES := ["de Bronze", "de Ferro", "de Mitril", "de Obsidiana"]

## armaduras: peso da peça + [def, mdef] da peça de corpo no nível de referência
const PIECES := ["head", "body", "legs", "gloves", "boots"]     # peças de armadura do conjunto lendário (contam nos bônus 2-5)
const PIECE_SLOT := {"head": S.HEAD, "body": S.BODY, "gloves": S.GLOVES, "boots": S.BOOTS, "legs": S.LEGS, "cape": S.CAPE, "amulet": S.AMULET, "ring": S.RING}
const PIECE_WEIGHT := {"head": 0.5, "body": 1.0, "gloves": 0.35, "boots": 0.4, "weapon": 1.3, "offhand": 0.8,
	"legs": 0.4, "cape": 0.15, "amulet": 0.25, "ring": 0.15}
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
## epíteto por nível lendário (5..30)
const TIER_EPITHETS := ["da Alvorada", "do Juramento", "da Vanguarda", "da Glória", "da Lenda", "da Eternidade"]
const LEGENDARY_COLOR := Color(1.0, 0.6, 0.15)
## Conjuntos lendários com visual próprio (kit: tools/blender/chibi_kit.py SET_STYLES; ícones: assets/icons/<icon>_<peça>.png).
## Referência de arte em reference/<classe>/set_N. Peças sem slot próprio no RagnaEx (polainas) vêm junto do corpo.
const SET_VISUALS := {
	"set_paladin_guardiao_5": {"style": "pal1", "icon": "pal1", "color": Color(0.58, 0.46, 0.84),
		"set_name": "Conjunto Cavaleiro da Fortaleza",
		"names": {"head": "Capacete de Cavaleiro da Fortaleza", "body": "Armadura de Cavaleiro da Fortaleza",
			"gloves": "Avambraço Cavaleiro do Forte", "boots": "Botas Cavaleiro do Forte",
			"weapon": "Espada Cavaleiro do Forte", "offhand": "Escudo Cavaleiro do Forte"}},
	"set_paladin_guardiao_10": {"style": "pal_g10", "icon": "pal_g10", "color": Color(0.6, 0.66, 0.78), "set_name": "Conjunto Bastião de Ferro",
		"names": {"head": "Elmo do Bastião", "body": "Couraça do Bastião", "gloves": "Manoplas do Bastião", "boots": "Grevas do Bastião",
			"weapon": "Espada do Bastião", "offhand": "Escudo do Bastião"}},
	"set_paladin_guardiao_15": {"style": "pal_g15", "icon": "pal_g15", "color": Color(0.26, 0.4, 0.78), "set_name": "Conjunto Muralha Azul",
		"names": {"head": "Elmo da Muralha Azul", "body": "Couraça da Muralha Azul", "gloves": "Manoplas da Muralha Azul", "boots": "Grevas da Muralha Azul",
			"weapon": "Espada da Muralha Azul", "offhand": "Escudo da Muralha Azul"}},
	"set_paladin_guardiao_20": {"style": "pal_g20", "icon": "pal_g20", "color": Color(0.95, 0.6, 0.26), "set_name": "Conjunto Guarda da Aurora",
		"names": {"head": "Elmo da Aurora", "body": "Couraça da Aurora", "gloves": "Manoplas da Aurora", "boots": "Grevas da Aurora",
			"weapon": "Espada da Aurora", "offhand": "Escudo da Aurora"}},
	"set_paladin_guardiao_25": {"style": "pal_g25", "icon": "pal_g25", "color": Color(0.36, 0.38, 0.43), "set_name": "Conjunto Sentinela de Basalto",
		"names": {"head": "Elmo da Sentinela", "body": "Couraça da Sentinela", "gloves": "Manoplas da Sentinela", "boots": "Grevas da Sentinela",
			"weapon": "Espada da Sentinela", "offhand": "Escudo da Sentinela"}},
	"set_paladin_guardiao_30": {"style": "pal_g30", "icon": "pal_g30", "color": Color(0.95, 0.9, 0.72), "set_name": "Conjunto Égide Eterna",
		"names": {"head": "Elmo da Égide", "body": "Couraça da Égide", "gloves": "Manoplas da Égide", "boots": "Grevas da Égide",
			"weapon": "Espada da Égide", "offhand": "Escudo da Égide"}},
	"set_paladin_cruzado_5": {"style": "pal_c5", "icon": "pal_c5", "color": Color(0.85, 0.86, 0.9), "set_name": "Conjunto Escudeiro da Chama",
		"names": {"head": "Elmo do Escudeiro", "body": "Couraça do Escudeiro", "gloves": "Manoplas do Escudeiro", "boots": "Grevas do Escudeiro",
			"weapon": "Espada do Escudeiro", "offhand": "Escudo do Escudeiro"}},
	"set_paladin_cruzado_10": {"style": "pal_c10", "icon": "pal_c10", "color": Color(0.72, 0.8, 0.95), "set_name": "Conjunto Cruzado de Prata",
		"names": {"head": "Elmo de Prata", "body": "Couraça de Prata", "gloves": "Manoplas de Prata", "boots": "Grevas de Prata",
			"weapon": "Espada de Prata", "offhand": "Escudo de Prata"}},
	"set_paladin_cruzado_15": {"style": "pal_c15", "icon": "pal_c15", "color": Color(0.35, 0.65, 0.7), "set_name": "Conjunto Lâmina da Fé",
		"names": {"head": "Elmo da Fé", "body": "Couraça da Fé", "gloves": "Manoplas da Fé", "boots": "Grevas da Fé",
			"weapon": "Espada da Fé", "offhand": "Escudo da Fé"}},
	"set_paladin_cruzado_20": {"style": "pal_c20", "icon": "pal_c20", "color": Color(0.98, 0.8, 0.35), "set_name": "Conjunto Vigília Solar",
		"names": {"head": "Elmo Solar", "body": "Couraça Solar", "gloves": "Manoplas Solar", "boots": "Grevas Solar",
			"weapon": "Espada Solar", "offhand": "Escudo Solar"}},
	"set_paladin_cruzado_25": {"style": "pal_c25", "icon": "pal_c25", "color": Color(0.72, 0.16, 0.2), "set_name": "Conjunto Juramento Rubro",
		"names": {"head": "Elmo Rubro", "body": "Couraça Rubro", "gloves": "Manoplas Rubro", "boots": "Grevas Rubro",
			"weapon": "Espada Rubro", "offhand": "Escudo Rubro"}},
	"set_paladin_cruzado_30": {"style": "pal_c30", "icon": "pal_c30", "color": Color(0.97, 0.96, 0.92), "set_name": "Conjunto Arauto Celestial",
		"names": {"head": "Elmo Celestial", "body": "Couraça Celestial", "gloves": "Manoplas Celestial", "boots": "Grevas Celestial",
			"weapon": "Espada Celestial", "offhand": "Escudo Celestial"}},
	"set_berserker_carniceiro_5": {"style": "ber_g5", "icon": "ber_g5", "color": Color(0.52, 0.4, 0.3), "set_name": "Conjunto Pele de Lobo",
		"names": {"head": "Elmo do Lobo", "body": "Couraça do Lobo", "gloves": "Braçais do Lobo", "boots": "Botas do Lobo", "weapon": "Machado do Lobo", "offhand": "Machado Gêmeo do Lobo"}},
	"set_berserker_carniceiro_10": {"style": "ber_g10", "icon": "ber_g10", "color": Color(0.7, 0.55, 0.36), "set_name": "Conjunto Saqueador do Norte",
		"names": {"head": "Elmo do Saqueador", "body": "Couraça do Saqueador", "gloves": "Braçais do Saqueador", "boots": "Botas do Saqueador", "weapon": "Machado do Saqueador", "offhand": "Machado Gêmeo do Saqueador"}},
	"set_berserker_carniceiro_15": {"style": "ber_g15", "icon": "ber_g15", "color": Color(0.62, 0.14, 0.14), "set_name": "Conjunto Presa Sangrenta",
		"names": {"head": "Elmo da Presa", "body": "Couraça da Presa", "gloves": "Braçais da Presa", "boots": "Botas da Presa", "weapon": "Machado da Presa", "offhand": "Machado Gêmeo da Presa"}},
	"set_berserker_carniceiro_20": {"style": "ber_g20", "icon": "ber_g20", "color": Color(0.22, 0.2, 0.24), "set_name": "Conjunto Ceifador Veloz",
		"names": {"head": "Elmo do Ceifador", "body": "Couraça do Ceifador", "gloves": "Braçais do Ceifador", "boots": "Botas do Ceifador", "weapon": "Machado do Ceifador", "offhand": "Machado Gêmeo do Ceifador"}},
	"set_berserker_carniceiro_25": {"style": "ber_g25", "icon": "ber_g25", "color": Color(0.9, 0.42, 0.14), "set_name": "Conjunto Fúria de Brasa",
		"names": {"head": "Elmo da Brasa", "body": "Couraça da Brasa", "gloves": "Braçais da Brasa", "boots": "Botas da Brasa", "weapon": "Machado da Brasa", "offhand": "Machado Gêmeo da Brasa"}},
	"set_berserker_carniceiro_30": {"style": "ber_g30", "icon": "ber_g30", "color": Color(0.55, 0.06, 0.1), "set_name": "Conjunto Senhor da Carnificina",
		"names": {"head": "Elmo da Carnificina", "body": "Couraça da Carnificina", "gloves": "Braçais da Carnificina", "boots": "Botas da Carnificina", "weapon": "Machado da Carnificina", "offhand": "Machado Gêmeo da Carnificina"}},
	"set_berserker_executor_5": {"style": "ber_e5", "icon": "ber_e5", "color": Color(0.5, 0.5, 0.54), "set_name": "Conjunto Carrasco de Ferro",
		"names": {"head": "Elmo do Carrasco", "body": "Couraça do Carrasco", "gloves": "Braçais do Carrasco", "boots": "Botas do Carrasco", "weapon": "Machado de Guerra do Carrasco"}},
	"set_berserker_executor_10": {"style": "ber_e10", "icon": "ber_e10", "color": Color(0.72, 0.5, 0.26), "set_name": "Conjunto Muralha de Bronze",
		"names": {"head": "Elmo de Bronze", "body": "Couraça de Bronze", "gloves": "Braçais de Bronze", "boots": "Botas de Bronze", "weapon": "Machado de Guerra de Bronze"}},
	"set_berserker_executor_15": {"style": "ber_e15", "icon": "ber_e15", "color": Color(0.3, 0.32, 0.38), "set_name": "Conjunto Quebra-Crânios",
		"names": {"head": "Elmo Quebra-Crânios", "body": "Couraça Quebra-Crânios", "gloves": "Braçais Quebra-Crânios", "boots": "Botas Quebra-Crânios", "weapon": "Machado de Guerra Quebra-Crânios"}},
	"set_berserker_executor_20": {"style": "ber_e20", "icon": "ber_e20", "color": Color(0.55, 0.72, 0.85), "set_name": "Conjunto Gigante do Inverno",
		"names": {"head": "Elmo do Inverno", "body": "Couraça do Inverno", "gloves": "Braçais do Inverno", "boots": "Botas do Inverno", "weapon": "Machado de Guerra do Inverno"}},
	"set_berserker_executor_25": {"style": "ber_e25", "icon": "ber_e25", "color": Color(0.16, 0.14, 0.18), "set_name": "Conjunto Tirano de Obsidiana",
		"names": {"head": "Elmo de Obsidiana", "body": "Couraça de Obsidiana", "gloves": "Braçais de Obsidiana", "boots": "Botas de Obsidiana", "weapon": "Machado de Guerra de Obsidiana"}},
	"set_berserker_executor_30": {"style": "ber_e30", "icon": "ber_e30", "color": Color(0.75, 0.16, 0.12), "set_name": "Conjunto Titã Escarlate",
		"names": {"head": "Elmo Escarlate", "body": "Couraça Escarlate", "gloves": "Braçais Escarlate", "boots": "Botas Escarlate", "weapon": "Machado de Guerra Escarlate"}},
	"set_berserker_punhos_5": {"style": "ber_m5", "icon": "ber_m5", "color": Color(0.62, 0.5, 0.34), "set_name": "Conjunto Noviço do Mosteiro",
		"names": {"head": "Faixa do Noviço", "body": "Gibão do Noviço", "gloves": "Faixas do Noviço", "boots": "Sandálias do Noviço", "weapon": "Garra do Noviço", "offhand": "Garra Gêmea do Noviço"}},
	"set_berserker_punhos_10": {"style": "ber_m10", "icon": "ber_m10", "color": Color(0.72, 0.42, 0.16), "set_name": "Conjunto Punho de Bronze",
		"names": {"head": "Tiara de Bronze", "body": "Gibão de Bronze", "gloves": "Faixas de Bronze", "boots": "Sandálias de Bronze", "weapon": "Garra de Bronze", "offhand": "Garra Gêmea de Bronze"}},
	"set_berserker_punhos_15": {"style": "ber_m15", "icon": "ber_m15", "color": Color(0.3, 0.42, 0.34), "set_name": "Conjunto Tigre da Montanha",
		"names": {"head": "Máscara do Tigre", "body": "Gibão do Tigre", "gloves": "Faixas do Tigre", "boots": "Sandálias do Tigre", "weapon": "Garra do Tigre", "offhand": "Garra Gêmea do Tigre"}},
	"set_berserker_punhos_20": {"style": "ber_m20", "icon": "ber_m20", "color": Color(0.55, 0.16, 0.12), "set_name": "Conjunto Lótus Rubra",
		"names": {"head": "Coroa de Contas da Lótus", "body": "Gibão da Lótus Rubra", "gloves": "Faixas da Lótus Rubra", "boots": "Sandálias da Lótus Rubra", "weapon": "Garra da Lótus Rubra", "offhand": "Garra Gêmea da Lótus Rubra"}},
	"set_berserker_punhos_25": {"style": "ber_m25", "icon": "ber_m25", "color": Color(0.18, 0.2, 0.3), "set_name": "Conjunto Dragão de Ferro",
		"names": {"head": "Elmo do Dragão de Ferro", "body": "Gibão do Dragão de Ferro", "gloves": "Faixas do Dragão de Ferro", "boots": "Sandálias do Dragão de Ferro", "weapon": "Garra do Dragão de Ferro", "offhand": "Garra Gêmea do Dragão de Ferro"}},
	"set_berserker_punhos_30": {"style": "ber_m30", "icon": "ber_m30", "color": Color(0.86, 0.66, 0.26), "set_name": "Conjunto Mestre dos Cem Punhos",
		"names": {"head": "Coroa dos Cem Punhos", "body": "Gibão dos Cem Punhos", "gloves": "Faixas dos Cem Punhos", "boots": "Sandálias dos Cem Punhos", "weapon": "Garra dos Cem Punhos", "offhand": "Garra Gêmea dos Cem Punhos"}},
	"set_bishop_sacerdote_5": {"style": "bis_s5", "icon": "bis_s5", "color": Color(0.92, 0.88, 0.78), "set_name": "Conjunto Vestes da Aurora",
		"names": {"head": "Véu da Aurora", "body": "Vestes da Aurora", "gloves": "Mangas da Aurora", "boots": "Sandálias da Aurora", "weapon": "Maça da Aurora", "offhand": "Escudo da Aurora"}},
	"set_bishop_sacerdote_10": {"style": "bis_s10", "icon": "bis_s10", "color": Color(0.55, 0.68, 0.9), "set_name": "Conjunto Vigília Serena",
		"names": {"head": "Véu da Vigília", "body": "Vestes da Vigília", "gloves": "Mangas da Vigília", "boots": "Sandálias da Vigília", "weapon": "Maça da Vigília", "offhand": "Escudo da Vigília"}},
	"set_bishop_sacerdote_15": {"style": "bis_s15", "icon": "bis_s15", "color": Color(0.4, 0.62, 0.66), "set_name": "Conjunto Guardiã do Claustro",
		"names": {"head": "Véu do Claustro", "body": "Vestes do Claustro", "gloves": "Mangas do Claustro", "boots": "Sandálias do Claustro", "weapon": "Maça do Claustro", "offhand": "Escudo do Claustro"}},
	"set_bishop_sacerdote_20": {"style": "bis_s20", "icon": "bis_s20", "color": Color(0.95, 0.78, 0.4), "set_name": "Conjunto Graça Dourada",
		"names": {"head": "Véu da Graça", "body": "Vestes da Graça", "gloves": "Mangas da Graça", "boots": "Sandálias da Graça", "weapon": "Maça da Graça", "offhand": "Escudo da Graça"}},
	"set_bishop_sacerdote_25": {"style": "bis_s25", "icon": "bis_s25", "color": Color(0.62, 0.72, 0.95), "set_name": "Conjunto Asa Serena",
		"names": {"head": "Véu da Asa Serena", "body": "Vestes da Asa Serena", "gloves": "Mangas da Asa Serena", "boots": "Sandálias da Asa Serena", "weapon": "Maça da Asa Serena", "offhand": "Escudo da Asa Serena"}},
	"set_bishop_sacerdote_30": {"style": "bis_s30", "icon": "bis_s30", "color": Color(0.98, 0.96, 0.9), "set_name": "Conjunto Coro Celeste",
		"names": {"head": "Véu do Coro Celeste", "body": "Vestes do Coro Celeste", "gloves": "Mangas do Coro Celeste", "boots": "Sandálias do Coro Celeste", "weapon": "Maça do Coro Celeste", "offhand": "Escudo do Coro Celeste"}},
	"set_bishop_inquisidor_5": {"style": "bis_i5", "icon": "bis_i5", "color": Color(0.85, 0.82, 0.95), "set_name": "Conjunto Lume Nascente",
		"names": {"head": "Mitra do Lume", "body": "Vestes do Lume", "gloves": "Mangas do Lume", "boots": "Sandálias do Lume", "weapon": "Cetro do Lume"}},
	"set_bishop_inquisidor_10": {"style": "bis_i10", "icon": "bis_i10", "color": Color(0.45, 0.55, 0.85), "set_name": "Conjunto Clarão Azul",
		"names": {"head": "Mitra do Clarão", "body": "Vestes do Clarão", "gloves": "Mangas do Clarão", "boots": "Sandálias do Clarão", "weapon": "Cetro do Clarão"}},
	"set_bishop_inquisidor_15": {"style": "bis_i15", "icon": "bis_i15", "color": Color(0.95, 0.66, 0.3), "set_name": "Conjunto Prisma Sagrado",
		"names": {"head": "Mitra do Prisma", "body": "Vestes do Prisma", "gloves": "Mangas do Prisma", "boots": "Sandálias do Prisma", "weapon": "Cetro do Prisma"}},
	"set_bishop_inquisidor_20": {"style": "bis_i20", "icon": "bis_i20", "color": Color(0.98, 0.9, 0.55), "set_name": "Conjunto Sol Interior",
		"names": {"head": "Mitra do Sol Interior", "body": "Vestes do Sol Interior", "gloves": "Mangas do Sol Interior", "boots": "Sandálias do Sol Interior", "weapon": "Cetro do Sol Interior"}},
	"set_bishop_inquisidor_25": {"style": "bis_i25", "icon": "bis_i25", "color": Color(0.3, 0.32, 0.6), "set_name": "Conjunto Estrela Noturna",
		"names": {"head": "Mitra da Estrela", "body": "Vestes da Estrela", "gloves": "Mangas da Estrela", "boots": "Sandálias da Estrela", "weapon": "Cetro da Estrela"}},
	"set_bishop_inquisidor_30": {"style": "bis_i30", "icon": "bis_i30", "color": Color(0.99, 0.97, 0.92), "set_name": "Conjunto Luz Primordial",
		"names": {"head": "Mitra da Luz Primordial", "body": "Vestes da Luz Primordial", "gloves": "Mangas da Luz Primordial", "boots": "Sandálias da Luz Primordial", "weapon": "Cetro da Luz Primordial"}},
	"set_paladin_templario_5": {"style": "pal_t5", "icon": "pal_t5", "color": Color(0.82, 0.36, 0.22), "set_name": "Conjunto Brasa do Noviço",
		"names": {"head": "Elmo da Brasa", "body": "Couraça da Brasa", "gloves": "Manoplas da Brasa", "boots": "Grevas da Brasa",
			"weapon": "Espada da Brasa", "offhand": "Escudo da Brasa"}},
	"set_paladin_templario_10": {"style": "pal_t10", "icon": "pal_t10", "color": Color(0.92, 0.9, 0.84), "set_name": "Conjunto Manto Branco",
		"names": {"head": "Elmo do Manto Branco", "body": "Couraça do Manto Branco", "gloves": "Manoplas do Manto Branco", "boots": "Grevas do Manto Branco",
			"weapon": "Espada do Manto Branco", "offhand": "Escudo do Manto Branco"}},
	"set_paladin_templario_15": {"style": "pal_t15", "icon": "pal_t15", "color": Color(0.62, 0.12, 0.14), "set_name": "Conjunto Cruz Vermelha",
		"names": {"head": "Elmo da Cruz Vermelha", "body": "Couraça da Cruz Vermelha", "gloves": "Manoplas da Cruz Vermelha", "boots": "Grevas da Cruz Vermelha",
			"weapon": "Espada da Cruz Vermelha", "offhand": "Escudo da Cruz Vermelha"}},
	"set_paladin_templario_20": {"style": "pal_t20", "icon": "pal_t20", "color": Color(0.95, 0.55, 0.18), "set_name": "Conjunto Chama Votiva",
		"names": {"head": "Elmo da Chama Votiva", "body": "Couraça da Chama Votiva", "gloves": "Manoplas da Chama Votiva", "boots": "Grevas da Chama Votiva",
			"weapon": "Espada da Chama Votiva", "offhand": "Escudo da Chama Votiva"}},
	"set_paladin_templario_25": {"style": "pal_t25", "icon": "pal_t25", "color": Color(0.24, 0.22, 0.3), "set_name": "Conjunto Penitente Negro",
		"names": {"head": "Elmo do Penitente", "body": "Couraça do Penitente", "gloves": "Manoplas do Penitente", "boots": "Grevas do Penitente",
			"weapon": "Espada do Penitente", "offhand": "Escudo do Penitente"}},
	"set_paladin_templario_30": {"style": "pal_t30", "icon": "pal_t30", "color": Color(1.0, 0.78, 0.3), "set_name": "Conjunto Sol Vingador",
		"names": {"head": "Elmo do Sol Vingador", "body": "Couraça do Sol Vingador", "gloves": "Manoplas do Sol Vingador", "boots": "Grevas do Sol Vingador",
			"weapon": "Espada do Sol Vingador", "offhand": "Escudo do Sol Vingador"}},
	"set_bishop_batalha_5": {"style": "bis_b5", "icon": "bis_b5", "color": Color(0.7, 0.66, 0.6), "set_name": "Conjunto Irmã de Armas",
		"names": {"head": "Elmo da Irmã de Armas", "body": "Couraça da Irmã de Armas", "gloves": "Manoplas da Irmã de Armas", "boots": "Grevas da Irmã de Armas", "weapon": "Maça da Irmã de Armas", "offhand": "Escudo da Irmã de Armas"}},
	"set_bishop_batalha_10": {"style": "bis_b10", "icon": "bis_b10", "color": Color(0.5, 0.62, 0.78), "set_name": "Conjunto Capelão de Aço",
		"names": {"head": "Elmo do Capelão", "body": "Couraça do Capelão", "gloves": "Manoplas do Capelão", "boots": "Grevas do Capelão", "weapon": "Maça do Capelão", "offhand": "Escudo do Capelão"}},
	"set_bishop_batalha_15": {"style": "bis_b15", "icon": "bis_b15", "color": Color(0.32, 0.52, 0.42), "set_name": "Conjunto Guarda do Mosteiro",
		"names": {"head": "Elmo do Mosteiro", "body": "Couraça do Mosteiro", "gloves": "Manoplas do Mosteiro", "boots": "Grevas do Mosteiro", "weapon": "Maça do Mosteiro", "offhand": "Escudo do Mosteiro"}},
	"set_bishop_batalha_20": {"style": "bis_b20", "icon": "bis_b20", "color": Color(0.9, 0.72, 0.36), "set_name": "Conjunto Martelo da Fé",
		"names": {"head": "Elmo do Martelo da Fé", "body": "Couraça do Martelo da Fé", "gloves": "Manoplas do Martelo da Fé", "boots": "Grevas do Martelo da Fé", "weapon": "Maça do Martelo da Fé", "offhand": "Escudo do Martelo da Fé"}},
	"set_bishop_batalha_25": {"style": "bis_b25", "icon": "bis_b25", "color": Color(0.55, 0.3, 0.62), "set_name": "Conjunto Vigília Púrpura",
		"names": {"head": "Elmo da Vigília Púrpura", "body": "Couraça da Vigília Púrpura", "gloves": "Manoplas da Vigília Púrpura", "boots": "Grevas da Vigília Púrpura", "weapon": "Maça da Vigília Púrpura", "offhand": "Escudo da Vigília Púrpura"}},
	"set_bishop_batalha_30": {"style": "bis_b30", "icon": "bis_b30", "color": Color(0.96, 0.94, 0.86), "set_name": "Conjunto Arcanjo Combatente",
		"names": {"head": "Elmo do Arcanjo", "body": "Couraça do Arcanjo", "gloves": "Manoplas do Arcanjo", "boots": "Grevas do Arcanjo", "weapon": "Maça do Arcanjo", "offhand": "Escudo do Arcanjo"}},
	"set_druid_xama_5": {"style": "dru_x5", "icon": "dru_x5", "color": Color(0.5, 0.7, 0.4), "set_name": "Conjunto Broto da Clareira",
		"names": {"head": "Coroa do Broto", "body": "Manto do Broto", "gloves": "Braçais do Broto", "boots": "Botas do Broto", "weapon": "Cajado do Broto"}},
	"set_druid_xama_10": {"style": "dru_x10", "icon": "dru_x10", "color": Color(0.45, 0.35, 0.22), "set_name": "Conjunto Galhada Antiga",
		"names": {"head": "Capuz da Galhada", "body": "Manto da Galhada", "gloves": "Braçais da Galhada", "boots": "Botas da Galhada", "weapon": "Cajado da Galhada"}},
	"set_druid_xama_15": {"style": "dru_x15", "icon": "dru_x15", "color": Color(0.85, 0.85, 0.75), "set_name": "Conjunto Lua do Bosque",
		"names": {"head": "Coroa da Lua do Bosque", "body": "Manto da Lua do Bosque", "gloves": "Braçais da Lua do Bosque", "boots": "Botas da Lua do Bosque", "weapon": "Cajado da Lua do Bosque"}},
	"set_druid_xama_20": {"style": "dru_x20", "icon": "dru_x20", "color": Color(0.3, 0.55, 0.45), "set_name": "Conjunto Seiva Viva",
		"names": {"head": "Capuz da Seiva", "body": "Manto da Seiva", "gloves": "Braçais da Seiva", "boots": "Botas da Seiva", "weapon": "Cajado da Seiva"}},
	"set_druid_xama_25": {"style": "dru_x25", "icon": "dru_x25", "color": Color(0.25, 0.28, 0.45), "set_name": "Conjunto Noite Selvagem",
		"names": {"head": "Capuz da Noite Selvagem", "body": "Manto da Noite Selvagem", "gloves": "Braçais da Noite Selvagem", "boots": "Botas da Noite Selvagem", "weapon": "Cajado da Noite Selvagem"}},
	"set_druid_xama_30": {"style": "dru_x30", "icon": "dru_x30", "color": Color(0.9, 0.8, 0.45), "set_name": "Conjunto Coração da Floresta",
		"names": {"head": "Coroa do Coração", "body": "Manto do Coração", "gloves": "Braçais do Coração", "boots": "Botas do Coração", "weapon": "Cajado do Coração"}},
	"set_druid_fera_5": {"style": "dru_w5", "icon": "dru_w5", "color": Color(0.5, 0.42, 0.32), "set_name": "Conjunto Pele Cinzenta",
		"names": {"head": "Capuz Cinzenta", "body": "Manto Cinzenta", "gloves": "Braçais Cinzenta", "boots": "Botas Cinzenta", "weapon": "Maça Cinzenta", "offhand": "Maça Gêmea Cinzenta"}},
	"set_druid_fera_10": {"style": "dru_w10", "icon": "dru_w10", "color": Color(0.82, 0.84, 0.86), "set_name": "Conjunto Lobo da Neve",
		"names": {"head": "Capuz da Neve", "body": "Manto da Neve", "gloves": "Braçais da Neve", "boots": "Botas da Neve", "weapon": "Maça da Neve", "offhand": "Maça Gêmea da Neve"}},
	"set_druid_fera_15": {"style": "dru_w15", "icon": "dru_w15", "color": Color(0.28, 0.42, 0.26), "set_name": "Conjunto Matilha Verde",
		"names": {"head": "Capuz da Matilha", "body": "Manto da Matilha", "gloves": "Braçais da Matilha", "boots": "Botas da Matilha", "weapon": "Maça da Matilha", "offhand": "Maça Gêmea da Matilha"}},
	"set_druid_fera_20": {"style": "dru_w20", "icon": "dru_w20", "color": Color(0.2, 0.22, 0.3), "set_name": "Conjunto Uivo Noturno",
		"names": {"head": "Capuz do Uivo", "body": "Manto do Uivo", "gloves": "Braçais do Uivo", "boots": "Botas do Uivo", "weapon": "Maça do Uivo", "offhand": "Maça Gêmea do Uivo"}},
	"set_druid_fera_25": {"style": "dru_w25", "icon": "dru_w25", "color": Color(0.75, 0.8, 0.9), "set_name": "Conjunto Presa de Gelo",
		"names": {"head": "Capuz da Presa de Gelo", "body": "Manto da Presa de Gelo", "gloves": "Braçais da Presa de Gelo", "boots": "Botas da Presa de Gelo", "weapon": "Maça da Presa de Gelo", "offhand": "Maça Gêmea da Presa de Gelo"}},
	"set_druid_fera_30": {"style": "dru_w30", "icon": "dru_w30", "color": Color(0.16, 0.18, 0.16), "set_name": "Conjunto Alfa Ancestral",
		"names": {"head": "Capuz do Alfa", "body": "Manto do Alfa", "gloves": "Braçais do Alfa", "boots": "Botas do Alfa", "weapon": "Maça do Alfa", "offhand": "Maça Gêmea do Alfa"}},
	"set_druid_guardiao_verde_5": {"style": "dru_b5", "icon": "dru_b5", "color": Color(0.45, 0.32, 0.2), "set_name": "Conjunto Casca de Carvalho",
		"names": {"head": "Crânio de Carvalho", "body": "Manto de Carvalho", "gloves": "Braçais de Carvalho", "boots": "Botas de Carvalho", "weapon": "Malho de Carvalho"}},
	"set_druid_guardiao_verde_10": {"style": "dru_b10", "icon": "dru_b10", "color": Color(0.4, 0.5, 0.3), "set_name": "Conjunto Raiz Profunda",
		"names": {"head": "Elmo da Raiz", "body": "Manto da Raiz", "gloves": "Braçais da Raiz", "boots": "Botas da Raiz", "weapon": "Malho da Raiz"}},
	"set_druid_guardiao_verde_15": {"style": "dru_b15", "icon": "dru_b15", "color": Color(0.3, 0.24, 0.18), "set_name": "Conjunto Urso das Cavernas",
		"names": {"head": "Crânio das Cavernas", "body": "Manto das Cavernas", "gloves": "Braçais das Cavernas", "boots": "Botas das Cavernas", "weapon": "Malho das Cavernas"}},
	"set_druid_guardiao_verde_20": {"style": "dru_b20", "icon": "dru_b20", "color": Color(0.75, 0.72, 0.62), "set_name": "Conjunto Montanha Musgosa",
		"names": {"head": "Elmo da Montanha", "body": "Manto da Montanha", "gloves": "Braçais da Montanha", "boots": "Botas da Montanha", "weapon": "Malho da Montanha"}},
	"set_druid_guardiao_verde_25": {"style": "dru_b25", "icon": "dru_b25", "color": Color(0.45, 0.18, 0.12), "set_name": "Conjunto Fúria da Terra",
		"names": {"head": "Crânio da Terra", "body": "Manto da Terra", "gloves": "Braçais da Terra", "boots": "Botas da Terra", "weapon": "Malho da Terra"}},
	"set_druid_guardiao_verde_30": {"style": "dru_b30", "icon": "dru_b30", "color": Color(0.85, 0.82, 0.7), "set_name": "Conjunto Urso Primordial",
		"names": {"head": "Crânio Primordial", "body": "Manto Primordial", "gloves": "Braçais Primordial", "boots": "Botas Primordial", "weapon": "Malho Primordial"}},
	"set_ranger_cacador_5": {"style": "ran_c5", "icon": "ran_c5", "color": Color(0.42, 0.6, 0.32), "set_name": "Conjunto Batedor da Clareira",
		"names": {"head": "Gorro do Batedor", "body": "Colete do Batedor", "gloves": "Braçadeira do Batedor", "boots": "Botas do Batedor", "weapon": "Arco do Batedor"}},
	"set_ranger_cacador_10": {"style": "ran_c10", "icon": "ran_c10", "color": Color(0.35, 0.42, 0.3), "set_name": "Conjunto Sombra do Bosque",
		"names": {"head": "Capuz da Sombra", "body": "Colete da Sombra", "gloves": "Braçadeira da Sombra", "boots": "Botas da Sombra", "weapon": "Arco da Sombra"}},
	"set_ranger_cacador_15": {"style": "ran_c15", "icon": "ran_c15", "color": Color(0.72, 0.5, 0.3), "set_name": "Conjunto Pena de Falcão",
		"names": {"head": "Gorro do Falcão", "body": "Colete do Falcão", "gloves": "Braçadeira do Falcão", "boots": "Botas do Falcão", "weapon": "Arco do Falcão"}},
	"set_ranger_cacador_20": {"style": "ran_c20", "icon": "ran_c20", "color": Color(0.3, 0.62, 0.55), "set_name": "Conjunto Vento Verde",
		"names": {"head": "Diadema do Vento", "body": "Colete do Vento", "gloves": "Braçadeira do Vento", "boots": "Botas do Vento", "weapon": "Arco do Vento"}},
	"set_ranger_cacador_25": {"style": "ran_c25", "icon": "ran_c25", "color": Color(0.4, 0.45, 0.7), "set_name": "Conjunto Lua Caçadora",
		"names": {"head": "Capuz da Lua", "body": "Colete da Lua", "gloves": "Braçadeira da Lua", "boots": "Botas da Lua", "weapon": "Arco da Lua"}},
	"set_ranger_cacador_30": {"style": "ran_c30", "icon": "ran_c30", "color": Color(0.95, 0.88, 0.6), "set_name": "Conjunto Asa Dourada",
		"names": {"head": "Diadema da Asa Dourada", "body": "Colete da Asa Dourada", "gloves": "Braçadeira da Asa Dourada", "boots": "Botas da Asa Dourada", "weapon": "Arco da Asa Dourada"}},
	"set_ranger_atirador_5": {"style": "ran_a5", "icon": "ran_a5", "color": Color(0.55, 0.4, 0.28), "set_name": "Conjunto Pólvora Nova",
		"names": {"head": "Chapéu da Pólvora", "body": "Colete da Pólvora", "gloves": "Braçadeira da Pólvora", "boots": "Botas da Pólvora", "weapon": "Mosquete da Pólvora"}},
	"set_ranger_atirador_10": {"style": "ran_a10", "icon": "ran_a10", "color": Color(0.45, 0.48, 0.52), "set_name": "Conjunto Engenhoqueiro",
		"names": {"head": "Boné do Engenhoqueiro", "body": "Colete do Engenhoqueiro", "gloves": "Braçadeira do Engenhoqueiro", "boots": "Botas do Engenhoqueiro", "weapon": "Mosquete do Engenhoqueiro"}},
	"set_ranger_atirador_15": {"style": "ran_a15", "icon": "ran_a15", "color": Color(0.6, 0.18, 0.18), "set_name": "Conjunto Casaca Rubra",
		"names": {"head": "Chapéu Rubro", "body": "Colete Rubro", "gloves": "Braçadeira Rubro", "boots": "Botas Rubro", "weapon": "Mosquete Rubro"}},
	"set_ranger_atirador_20": {"style": "ran_a20", "icon": "ran_a20", "color": Color(0.3, 0.3, 0.34), "set_name": "Conjunto Mira de Ferro",
		"names": {"head": "Boné da Mira", "body": "Colete da Mira", "gloves": "Braçadeira da Mira", "boots": "Botas da Mira", "weapon": "Mosquete da Mira"}},
	"set_ranger_atirador_25": {"style": "ran_a25", "icon": "ran_a25", "color": Color(0.2, 0.32, 0.55), "set_name": "Conjunto Trovão Azul",
		"names": {"head": "Chapéu do Trovão", "body": "Colete do Trovão", "gloves": "Braçadeira do Trovão", "boots": "Botas do Trovão", "weapon": "Mosquete do Trovão"}},
	"set_ranger_atirador_30": {"style": "ran_a30", "icon": "ran_a30", "color": Color(0.82, 0.62, 0.3), "set_name": "Conjunto Canhão Dourado",
		"names": {"head": "Chapéu Dourado", "body": "Colete Dourado", "gloves": "Braçadeira Dourado", "boots": "Botas Dourado", "weapon": "Mosquete Dourado"}},
	"set_ranger_lanceiro_5": {"style": "ran_l5", "icon": "ran_l5", "color": Color(0.55, 0.42, 0.28), "set_name": "Conjunto Pele de Javali",
		"names": {"head": "Capuz do Javali", "body": "Gibão do Javali", "gloves": "Braçadeiras do Javali", "boots": "Botas do Javali", "weapon": "Lança do Javali"}},
	"set_ranger_lanceiro_10": {"style": "ran_l10", "icon": "ran_l10", "color": Color(0.62, 0.6, 0.56), "set_name": "Conjunto Crânio de Lobo",
		"names": {"head": "Crânio do Lobo Cinzento", "body": "Gibão do Lobo Cinzento", "gloves": "Braçadeiras do Lobo Cinzento", "boots": "Botas do Lobo Cinzento", "weapon": "Lança do Lobo Cinzento"}},
	"set_ranger_lanceiro_15": {"style": "ran_l15", "icon": "ran_l15", "color": Color(0.72, 0.4, 0.18), "set_name": "Conjunto Juba de Leão",
		"names": {"head": "Juba do Leão", "body": "Gibão do Leão", "gloves": "Braçadeiras do Leão", "boots": "Botas do Leão", "weapon": "Lança do Leão"}},
	"set_ranger_lanceiro_20": {"style": "ran_l20", "icon": "ran_l20", "color": Color(0.3, 0.5, 0.42), "set_name": "Conjunto Escama de Serpe",
		"names": {"head": "Elmo da Serpe", "body": "Cota de Escamas da Serpe", "gloves": "Braçadeiras da Serpe", "boots": "Botas da Serpe", "weapon": "Lança da Serpe"}},
	"set_ranger_lanceiro_25": {"style": "ran_l25", "icon": "ran_l25", "color": Color(0.36, 0.3, 0.42), "set_name": "Conjunto Pena de Corvo",
		"names": {"head": "Máscara do Corvo", "body": "Gibão do Corvo", "gloves": "Braçadeiras do Corvo", "boots": "Botas do Corvo", "weapon": "Lança do Corvo"}},
	"set_ranger_lanceiro_30": {"style": "ran_l30", "icon": "ran_l30", "color": Color(0.8, 0.7, 0.5), "set_name": "Conjunto Rei das Feras",
		"names": {"head": "Crânio do Rei das Feras", "body": "Gibão do Rei das Feras", "gloves": "Braçadeiras do Rei das Feras", "boots": "Botas do Rei das Feras", "weapon": "Lança do Rei das Feras"}},
	"set_assassin_laminas_5": {"style": "ass_l5", "icon": "ass_l5", "color": Color(0.32, 0.3, 0.38), "set_name": "Conjunto Passo Silencioso",
		"names": {"head": "Capuz Silenciosa", "body": "Gibão Silenciosa", "gloves": "Faixas Silenciosa", "boots": "Botas Silenciosa", "weapon": "Adaga Silenciosa", "offhand": "Adaga Gêmea Silenciosa"}},
	"set_assassin_laminas_10": {"style": "ass_l10", "icon": "ass_l10", "color": Color(0.55, 0.22, 0.25), "set_name": "Conjunto Faixa Rubra",
		"names": {"head": "Máscara da Faixa Rubra", "body": "Gibão da Faixa Rubra", "gloves": "Faixas da Faixa Rubra", "boots": "Botas da Faixa Rubra", "weapon": "Adaga da Faixa Rubra", "offhand": "Adaga Gêmea da Faixa Rubra"}},
	"set_assassin_laminas_15": {"style": "ass_l15", "icon": "ass_l15", "color": Color(0.3, 0.45, 0.3), "set_name": "Conjunto Erva-Moura",
		"names": {"head": "Capuz da Erva-Moura", "body": "Gibão da Erva-Moura", "gloves": "Faixas da Erva-Moura", "boots": "Botas da Erva-Moura", "weapon": "Adaga da Erva-Moura", "offhand": "Adaga Gêmea da Erva-Moura"}},
	"set_assassin_laminas_20": {"style": "ass_l20", "icon": "ass_l20", "color": Color(0.4, 0.28, 0.55), "set_name": "Conjunto Víbora Violeta",
		"names": {"head": "Capuz da Víbora", "body": "Gibão da Víbora", "gloves": "Faixas da Víbora", "boots": "Botas da Víbora", "weapon": "Adaga da Víbora", "offhand": "Adaga Gêmea da Víbora"}},
	"set_assassin_laminas_25": {"style": "ass_l25", "icon": "ass_l25", "color": Color(0.2, 0.36, 0.38), "set_name": "Conjunto Escama Tóxica",
		"names": {"head": "Capuz da Escama", "body": "Gibão da Escama", "gloves": "Faixas da Escama", "boots": "Botas da Escama", "weapon": "Adaga da Escama", "offhand": "Adaga Gêmea da Escama"}},
	"set_assassin_laminas_30": {"style": "ass_l30", "icon": "ass_l30", "color": Color(0.22, 0.18, 0.3), "set_name": "Conjunto Mariposa da Meia-Noite",
		"names": {"head": "Capuz da Meia-Noite", "body": "Gibão da Meia-Noite", "gloves": "Faixas da Meia-Noite", "boots": "Botas da Meia-Noite", "weapon": "Adaga da Meia-Noite", "offhand": "Adaga Gêmea da Meia-Noite"}},
	"set_assassin_duelista_5": {"style": "ass_d5", "icon": "ass_d5", "color": Color(0.6, 0.45, 0.3), "set_name": "Conjunto Aprendiz de Esgrima",
		"names": {"head": "Bandana do Aprendiz", "body": "Casaca do Aprendiz", "gloves": "Luvas do Aprendiz", "boots": "Botas do Aprendiz", "weapon": "Espada do Aprendiz", "offhand": "Espada Gêmea do Aprendiz"}},
	"set_assassin_duelista_10": {"style": "ass_d10", "icon": "ass_d10", "color": Color(0.3, 0.42, 0.62), "set_name": "Conjunto Florete Azul",
		"names": {"head": "Chapéu do Florete", "body": "Casaca do Florete", "gloves": "Luvas do Florete", "boots": "Botas do Florete", "weapon": "Espada do Florete", "offhand": "Espada Gêmea do Florete"}},
	"set_assassin_duelista_15": {"style": "ass_d15", "icon": "ass_d15", "color": Color(0.2, 0.2, 0.24), "set_name": "Conjunto Baile de Máscaras",
		"names": {"head": "Máscara do Baile", "body": "Casaca do Baile", "gloves": "Luvas do Baile", "boots": "Botas do Baile", "weapon": "Espada do Baile", "offhand": "Espada Gêmea do Baile"}},
	"set_assassin_duelista_20": {"style": "ass_d20", "icon": "ass_d20", "color": Color(0.65, 0.18, 0.22), "set_name": "Conjunto Rosa Escarlate",
		"names": {"head": "Chapéu da Rosa", "body": "Casaca da Rosa", "gloves": "Luvas da Rosa", "boots": "Botas da Rosa", "weapon": "Espada da Rosa", "offhand": "Espada Gêmea da Rosa"}},
	"set_assassin_duelista_25": {"style": "ass_d25", "icon": "ass_d25", "color": Color(0.85, 0.85, 0.9), "set_name": "Conjunto Lua Prateada",
		"names": {"head": "Diadema da Lua Prateada", "body": "Casaca da Lua Prateada", "gloves": "Luvas da Lua Prateada", "boots": "Botas da Lua Prateada", "weapon": "Espada da Lua Prateada", "offhand": "Espada Gêmea da Lua Prateada"}},
	"set_assassin_duelista_30": {"style": "ass_d30", "icon": "ass_d30", "color": Color(0.3, 0.15, 0.4), "set_name": "Conjunto Mestre das Lâminas",
		"names": {"head": "Chapéu do Mestre", "body": "Casaca do Mestre", "gloves": "Luvas do Mestre", "boots": "Botas do Mestre", "weapon": "Espada do Mestre", "offhand": "Espada Gêmea do Mestre"}},
	"set_assassin_corsario_5": {"style": "ass_c5", "icon": "ass_c5", "color": Color(0.62, 0.3, 0.22), "set_name": "Conjunto Grumete",
		"names": {"head": "Bandana do Grumete", "body": "Casaca do Grumete", "gloves": "Luvas do Grumete", "boots": "Botas do Grumete", "weapon": "Sabre do Grumete", "offhand": "Pistola do Grumete"}},
	"set_assassin_corsario_10": {"style": "ass_c10", "icon": "ass_c10", "color": Color(0.22, 0.38, 0.6), "set_name": "Conjunto Maré Alta",
		"names": {"head": "Tricórnio da Maré Alta", "body": "Casaca da Maré Alta", "gloves": "Luvas da Maré Alta", "boots": "Botas da Maré Alta", "weapon": "Sabre da Maré Alta", "offhand": "Pistola da Maré Alta"}},
	"set_assassin_corsario_15": {"style": "ass_c15", "icon": "ass_c15", "color": Color(0.2, 0.42, 0.36), "set_name": "Conjunto Contrabandista de Coral",
		"names": {"head": "Lenço do Coral", "body": "Casaca do Coral", "gloves": "Luvas do Coral", "boots": "Botas do Coral", "weapon": "Sabre do Coral", "offhand": "Pistola do Coral"}},
	"set_assassin_corsario_20": {"style": "ass_c20", "icon": "ass_c20", "color": Color(0.66, 0.16, 0.2), "set_name": "Conjunto Bandeira Rubra",
		"names": {"head": "Bicorne da Bandeira Rubra", "body": "Casaca da Bandeira Rubra", "gloves": "Luvas da Bandeira Rubra", "boots": "Botas da Bandeira Rubra", "weapon": "Sabre da Bandeira Rubra", "offhand": "Pistola da Bandeira Rubra"}},
	"set_assassin_corsario_25": {"style": "ass_c25", "icon": "ass_c25", "color": Color(0.16, 0.18, 0.26), "set_name": "Conjunto Navio Fantasma",
		"names": {"head": "Tricórnio do Navio Fantasma", "body": "Casaca do Navio Fantasma", "gloves": "Luvas do Navio Fantasma", "boots": "Botas do Navio Fantasma", "weapon": "Sabre do Navio Fantasma", "offhand": "Pistola do Navio Fantasma"}},
	"set_assassin_corsario_30": {"style": "ass_c30", "icon": "ass_c30", "color": Color(0.42, 0.18, 0.46), "set_name": "Conjunto Almirante dos Sete Mares",
		"names": {"head": "Chapéu do Almirante", "body": "Casaca do Almirante", "gloves": "Luvas do Almirante", "boots": "Botas do Almirante", "weapon": "Sabre do Almirante", "offhand": "Pistola do Almirante"}},
	"set_elementalist_fogo_5": {"style": "ele_f5", "icon": "ele_f5", "color": Color(0.82, 0.32, 0.18), "set_name": "Conjunto Brasa Nova",
		"names": {"head": "Chapéu da Brasa", "body": "Túnica da Brasa", "gloves": "Mangas da Brasa", "boots": "Sapatilhas da Brasa", "weapon": "Cajado da Brasa"}},
	"set_elementalist_fogo_10": {"style": "ele_f10", "icon": "ele_f10", "color": Color(0.72, 0.34, 0.37), "set_name": "Conjunto Tempestade Rubra", "favor": "storm",
		"names": {"head": "Diadema da Tempestade Rubra", "body": "Túnica da Tempestade Rubra", "gloves": "Mangas da Tempestade Rubra", "boots": "Sapatilhas da Tempestade Rubra", "weapon": "Cajado da Tempestade Rubra"}},
	"set_elementalist_fogo_15": {"style": "ele_f15", "icon": "ele_f15", "color": Color(0.71, 0.43, 0.4), "set_name": "Conjunto Vapor Escarlate", "favor": "frost",
		"names": {"head": "Chapéu do Vapor", "body": "Túnica do Vapor", "gloves": "Mangas do Vapor", "boots": "Sapatilhas do Vapor", "weapon": "Cajado do Vapor"}},
	"set_elementalist_fogo_20": {"style": "ele_f20", "icon": "ele_f20", "color": Color(0.82, 0.32, 0.18), "set_name": "Conjunto Coração de Fogo",
		"names": {"head": "Diadema do Coração de Fogo", "body": "Túnica do Coração de Fogo", "gloves": "Mangas do Coração de Fogo", "boots": "Sapatilhas do Coração de Fogo", "weapon": "Cajado do Coração de Fogo"}},
	"set_elementalist_fogo_25": {"style": "ele_f25", "icon": "ele_f25", "color": Color(0.72, 0.34, 0.37), "set_name": "Conjunto Céu em Chamas", "favor": "storm",
		"names": {"head": "Chapéu do Céu em Chamas", "body": "Túnica do Céu em Chamas", "gloves": "Mangas do Céu em Chamas", "boots": "Sapatilhas do Céu em Chamas", "weapon": "Cajado do Céu em Chamas"}},
	"set_elementalist_fogo_30": {"style": "ele_f30", "icon": "ele_f30", "color": Color(0.71, 0.43, 0.4), "set_name": "Conjunto Equinócio Ardente", "favor": "frost",
		"names": {"head": "Chapéu do Equinócio", "body": "Túnica do Equinócio", "gloves": "Mangas do Equinócio", "boots": "Sapatilhas do Equinócio", "weapon": "Cajado do Equinócio"}},
	"set_elementalist_gelo_5": {"style": "ele_g5", "icon": "ele_g5", "color": Color(0.45, 0.68, 0.92), "set_name": "Conjunto Geada Leve",
		"names": {"head": "Coroa da Geada", "body": "Túnica da Geada", "gloves": "Mangas da Geada", "boots": "Sapatilhas da Geada", "weapon": "Cajado da Geada"}},
	"set_elementalist_gelo_10": {"style": "ele_g10", "icon": "ele_g10", "color": Color(0.56, 0.57, 0.7), "set_name": "Conjunto Fogo Gélido", "favor": "fire",
		"names": {"head": "Capuz do Fogo Gélido", "body": "Túnica do Fogo Gélido", "gloves": "Mangas do Fogo Gélido", "boots": "Sapatilhas do Fogo Gélido", "weapon": "Cajado do Fogo Gélido"}},
	"set_elementalist_gelo_15": {"style": "ele_g15", "icon": "ele_g15", "color": Color(0.46, 0.6, 0.89), "set_name": "Conjunto Granizo Azul", "favor": "storm",
		"names": {"head": "Coroa do Granizo", "body": "Túnica do Granizo", "gloves": "Mangas do Granizo", "boots": "Sapatilhas do Granizo", "weapon": "Cajado do Granizo"}},
	"set_elementalist_gelo_20": {"style": "ele_g20", "icon": "ele_g20", "color": Color(0.45, 0.68, 0.92), "set_name": "Conjunto Inverno Eterno",
		"names": {"head": "Capuz do Inverno", "body": "Túnica do Inverno", "gloves": "Mangas do Inverno", "boots": "Sapatilhas do Inverno", "weapon": "Cajado do Inverno"}},
	"set_elementalist_gelo_25": {"style": "ele_g25", "icon": "ele_g25", "color": Color(0.56, 0.57, 0.7), "set_name": "Conjunto Aurora Boreal", "favor": "fire",
		"names": {"head": "Coroa da Aurora", "body": "Túnica da Aurora", "gloves": "Mangas da Aurora", "boots": "Sapatilhas da Aurora", "weapon": "Cajado da Aurora"}},
	"set_elementalist_gelo_30": {"style": "ele_g30", "icon": "ele_g30", "color": Color(0.46, 0.6, 0.89), "set_name": "Conjunto Nevasca Trovejante", "favor": "storm",
		"names": {"head": "Coroa da Nevasca", "body": "Túnica da Nevasca", "gloves": "Mangas da Nevasca", "boots": "Sapatilhas da Nevasca", "weapon": "Cajado da Nevasca"}},
	"set_elementalist_raio_5": {"style": "ele_r5", "icon": "ele_r5", "color": Color(0.48, 0.4, 0.82), "set_name": "Conjunto Centelha",
		"names": {"head": "Chapéu da Centelha", "body": "Túnica da Centelha", "gloves": "Mangas da Centelha", "boots": "Sapatilhas da Centelha", "weapon": "Cajado da Centelha"}},
	"set_elementalist_raio_10": {"style": "ele_r10", "icon": "ele_r10", "color": Color(0.58, 0.38, 0.63), "set_name": "Conjunto Relâmpago Rubro", "favor": "fire",
		"names": {"head": "Faixa do Relâmpago", "body": "Túnica do Relâmpago", "gloves": "Mangas do Relâmpago", "boots": "Sapatilhas do Relâmpago", "weapon": "Cajado do Relâmpago"}},
	"set_elementalist_raio_15": {"style": "ele_r15", "icon": "ele_r15", "color": Color(0.47, 0.48, 0.85), "set_name": "Conjunto Raio Glacial", "favor": "frost",
		"names": {"head": "Chapéu do Raio Glacial", "body": "Túnica do Raio Glacial", "gloves": "Mangas do Raio Glacial", "boots": "Sapatilhas do Raio Glacial", "weapon": "Cajado do Raio Glacial"}},
	"set_elementalist_raio_20": {"style": "ele_r20", "icon": "ele_r20", "color": Color(0.48, 0.4, 0.82), "set_name": "Conjunto Coroa do Trovão",
		"names": {"head": "Faixa do Trovão", "body": "Túnica do Trovão", "gloves": "Mangas do Trovão", "boots": "Sapatilhas do Trovão", "weapon": "Cajado do Trovão"}},
	"set_elementalist_raio_25": {"style": "ele_r25", "icon": "ele_r25", "color": Color(0.58, 0.38, 0.63), "set_name": "Conjunto Tormenta de Fogo", "favor": "fire",
		"names": {"head": "Chapéu da Tormenta", "body": "Túnica da Tormenta", "gloves": "Mangas da Tormenta", "boots": "Sapatilhas da Tormenta", "weapon": "Cajado da Tormenta"}},
	"set_elementalist_raio_30": {"style": "ele_r30", "icon": "ele_r30", "color": Color(0.47, 0.48, 0.85), "set_name": "Conjunto Tempestade Cristalina", "favor": "frost",
		"names": {"head": "Chapéu Cristalina", "body": "Túnica Cristalina", "gloves": "Mangas Cristalina", "boots": "Sapatilhas Cristalina", "weapon": "Cajado Cristalina"}},
	"set_necromancer_invocador_5": {"style": "nec_i5", "icon": "nec_i5", "color": Color(0.3, 0.5, 0.42), "set_name": "Conjunto Ossário",
		"names": {"head": "Capuz do Ossário", "body": "Túnica do Ossário", "gloves": "Mangas do Ossário", "boots": "Botas do Ossário", "weapon": "Foice do Ossário"}},
	"set_necromancer_invocador_10": {"style": "nec_i10", "icon": "nec_i10", "color": Color(0.55, 0.52, 0.45), "set_name": "Conjunto Coroa de Ossos",
		"names": {"head": "Coroa dos Ossos", "body": "Túnica dos Ossos", "gloves": "Mangas dos Ossos", "boots": "Botas dos Ossos", "weapon": "Foice dos Ossos"}},
	"set_necromancer_invocador_15": {"style": "nec_i15", "icon": "nec_i15", "color": Color(0.25, 0.55, 0.35), "set_name": "Conjunto Cripta Verde",
		"names": {"head": "Capuz da Cripta", "body": "Túnica da Cripta", "gloves": "Mangas da Cripta", "boots": "Botas da Cripta", "weapon": "Foice da Cripta"}},
	"set_necromancer_invocador_20": {"style": "nec_i20", "icon": "nec_i20", "color": Color(0.72, 0.7, 0.62), "set_name": "Conjunto Legião Pálida",
		"names": {"head": "Coroa da Legião", "body": "Túnica da Legião", "gloves": "Mangas da Legião", "boots": "Botas da Legião", "weapon": "Foice da Legião"}},
	"set_necromancer_invocador_25": {"style": "nec_i25", "icon": "nec_i25", "color": Color(0.2, 0.35, 0.3), "set_name": "Conjunto Senhor dos Túmulos",
		"names": {"head": "Capuz dos Túmulos", "body": "Túnica dos Túmulos", "gloves": "Mangas dos Túmulos", "boots": "Botas dos Túmulos", "weapon": "Foice dos Túmulos"}},
	"set_necromancer_invocador_30": {"style": "nec_i30", "icon": "nec_i30", "color": Color(0.35, 0.3, 0.4), "set_name": "Conjunto Rei dos Mortos",
		"names": {"head": "Coroa do Rei dos Mortos", "body": "Túnica do Rei dos Mortos", "gloves": "Mangas do Rei dos Mortos", "boots": "Botas do Rei dos Mortos", "weapon": "Foice do Rei dos Mortos"}},
	"set_necromancer_ceifador_5": {"style": "nec_c5", "icon": "nec_c5", "color": Color(0.4, 0.4, 0.42), "set_name": "Conjunto Ceifa Cinzenta",
		"names": {"head": "Capuz da Ceifa", "body": "Manto da Ceifa", "gloves": "Braçais da Ceifa", "boots": "Botas da Ceifa", "weapon": "Foice da Ceifa"}},
	"set_necromancer_ceifador_10": {"style": "nec_c10", "icon": "nec_c10", "color": Color(0.55, 0.15, 0.18), "set_name": "Conjunto Mortalha Rubra",
		"names": {"head": "Capuz da Mortalha", "body": "Manto da Mortalha", "gloves": "Braçais da Mortalha", "boots": "Botas da Mortalha", "weapon": "Foice da Mortalha"}},
	"set_necromancer_ceifador_15": {"style": "nec_c15", "icon": "nec_c15", "color": Color(0.18, 0.16, 0.2), "set_name": "Conjunto Chifre Negro",
		"names": {"head": "Capuz do Chifre Negro", "body": "Manto do Chifre Negro", "gloves": "Braçais do Chifre Negro", "boots": "Botas do Chifre Negro", "weapon": "Foice do Chifre Negro"}},
	"set_necromancer_ceifador_20": {"style": "nec_c20", "icon": "nec_c20", "color": Color(0.35, 0.42, 0.5), "set_name": "Conjunto Corrente Fria",
		"names": {"head": "Capuz da Corrente", "body": "Manto da Corrente", "gloves": "Braçais da Corrente", "boots": "Botas da Corrente", "weapon": "Foice da Corrente"}},
	"set_necromancer_ceifador_25": {"style": "nec_c25", "icon": "nec_c25", "color": Color(0.5, 0.12, 0.08), "set_name": "Conjunto Pacto Infernal",
		"names": {"head": "Capuz do Pacto", "body": "Manto do Pacto", "gloves": "Braçais do Pacto", "boots": "Botas do Pacto", "weapon": "Foice do Pacto"}},
	"set_necromancer_ceifador_30": {"style": "nec_c30", "icon": "nec_c30", "color": Color(0.12, 0.1, 0.12), "set_name": "Conjunto Arauto do Fim",
		"names": {"head": "Capuz do Arauto", "body": "Manto do Arauto", "gloves": "Braçais do Arauto", "boots": "Botas do Arauto", "weapon": "Foice do Arauto"}},
	"set_necromancer_pestilento_5": {"style": "nec_s5", "icon": "nec_s5", "color": Color(0.35, 0.28, 0.5), "set_name": "Conjunto Sussurro",
		"names": {"head": "Capuz do Sussurro", "body": "Túnica do Sussurro", "gloves": "Mangas do Sussurro", "boots": "Botas do Sussurro", "weapon": "Foice do Sussurro"}},
	"set_necromancer_pestilento_10": {"style": "nec_s10", "icon": "nec_s10", "color": Color(0.45, 0.3, 0.55), "set_name": "Conjunto Olho Aberto",
		"names": {"head": "Diadema do Olho", "body": "Túnica do Olho", "gloves": "Mangas do Olho", "boots": "Botas do Olho", "weapon": "Foice do Olho"}},
	"set_necromancer_pestilento_15": {"style": "nec_s15", "icon": "nec_s15", "color": Color(0.2, 0.15, 0.35), "set_name": "Conjunto Véu do Vazio",
		"names": {"head": "Capuz do Vazio", "body": "Túnica do Vazio", "gloves": "Mangas do Vazio", "boots": "Botas do Vazio", "weapon": "Foice do Vazio"}},
	"set_necromancer_pestilento_20": {"style": "nec_s20", "icon": "nec_s20", "color": Color(0.5, 0.25, 0.45), "set_name": "Conjunto Mente Partida",
		"names": {"head": "Diadema da Mente", "body": "Túnica da Mente", "gloves": "Mangas da Mente", "boots": "Botas da Mente", "weapon": "Foice da Mente"}},
	"set_necromancer_pestilento_25": {"style": "nec_s25", "icon": "nec_s25", "color": Color(0.15, 0.12, 0.25), "set_name": "Conjunto Eclipse",
		"names": {"head": "Capuz do Eclipse", "body": "Túnica do Eclipse", "gloves": "Mangas do Eclipse", "boots": "Botas do Eclipse", "weapon": "Foice do Eclipse"}},
	"set_necromancer_pestilento_30": {"style": "nec_s30", "icon": "nec_s30", "color": Color(0.3, 0.1, 0.4), "set_name": "Conjunto Abismo",
		"names": {"head": "Capuz do Abismo", "body": "Túnica do Abismo", "gloves": "Mangas do Abismo", "boots": "Botas do Abismo", "weapon": "Foice do Abismo"}},
}
const DAMAGE_KINDS := [SkillDef.Kind.PHYSICAL, SkillDef.Kind.MAGICAL, SkillDef.Kind.HEAL]


## Fator de poder por nível (1.0 no nível de referência).
static func level_factor(level: int) -> float:
	return (float(level) + Balance.GEAR_LEVEL_OFFSET) / (Balance.GEAR_REF_LEVEL + Balance.GEAR_LEVEL_OFFSET)

static func _attrs(primary: String, secondary: String, level: int, weight: float, mult: float) -> Dictionary:
	var a := {}
	a[primary] = maxi(1, int(round(Balance.GEAR_ATTR_PRIMARY_PER_LEVEL * level * weight * mult)))
	if secondary != primary:
		a[secondary] = maxi(1, int(round(Balance.GEAR_ATTR_SECONDARY_PER_LEVEL * level * weight * mult)))
	return a

static func _price(level: int, weight: float, mult: float) -> int:
	return int(round((20.0 + level * level * 2.5) * weight * mult))

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
		var col := Color(0.42, 0.36, 0.3).lerp(Color(0.72, 0.72, 0.8), tier / 3.0)
		out.append(armor_item("legs_%s_t%d" % [armor, tier], "%s %s" % [l[0], COMMON_TIER_NAMES[tier]], "legs", armor, l[1], l[2], lv, tier, 1.0, col))
	for piece in THEME_PIECES:
		for theme in THEMES:
			var t: Array = THEMES[theme]
			var col: Color = (t[3] as Color).lightened(tier * 0.08)
			var it := armor_item("%s_%s_t%d" % [piece, theme, tier], "%s %s %s" % [THEME_PIECES[piece], t[0], COMMON_TIER_NAMES[tier]], piece, "leather", t[1], t[2], lv, tier, 1.0, col)
			it.armor_style = "cape" if piece == "cape" else ""
			if piece != "cape":
				it.def = 0.0
				it.mdef = 0.0
			out.append(it)
	return out

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
	b[2] = {"attrs": {build["attr2"]: Balance.SET_2PC_ATTR_BASE + Balance.SET_2PC_ATTR_PER_TIER * tier}}
	b[3] = {"attrs": {build["attr"]: Balance.SET_3PC_ATTR_BASE + Balance.SET_3PC_ATTR_PER_TIER * tier}}
	b[4] = {"skill_dmg": {dmg_skill: Balance.SET_4PC_SKILL_DMG_BASE + Balance.SET_4PC_SKILL_DMG_PER_TIER * tier}}
	b[5] = {build["stat"]: Balance.SET_5PC_STAT_PCT_BASE + Balance.SET_5PC_STAT_PCT_PER_TIER * tier,
		"skill_cdr": {cdr_skill: Balance.SET_5PC_CDR_BASE + Balance.SET_5PC_CDR_PER_TIER * tier}}
	# extra da build (ex.: roubo de vida, vida/defesa): {peças: {stat: [base, por tier]}}
	var extra: Dictionary = build.get("set_extra", {})
	for n in extra:
		for k in extra[n]:
			b[int(n)][k] = round((float(extra[n][k][0]) + float(extra[n][k][1]) * tier) * 10.0) / 10.0
	return b


## Gera tudo. Retorna {"items": [ItemDef], "sets": [SetDef]}.
static func build(classes: Dictionary, skills: Dictionary) -> Dictionary:
	var items: Array = []
	var sets: Array = []
	# 1) armas comuns dos tipos novos (tiers 0..3)
	for wtype in NEW_COMMON_TYPES:
		for tier in range(Balance.COMMON_TIER_LEVELS.size()):
			var lv: int = Balance.COMMON_TIER_LEVELS[tier]
			var nm := "%s %s" % [WEAPON_NAMES[wtype], COMMON_TIER_NAMES[tier]]
			var col := Color(0.6, 0.55, 0.45).lerp(Color(0.85, 0.85, 0.95), tier / 3.0)
			items.append(weapon_item("%s_t%d" % [wtype, tier], nm, wtype, lv, tier, 1.0, col))
	for tier in range(Balance.COMMON_TIER_LEVELS.size()):
		items.append_array(wearables(tier))
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
					wpn.matk = maxf(wpn.matk, round(wpn.atk * 0.9))
				wpn.legend_effect = legend_effect(build, tier)
				made.append(wpn)
				var alts := {}
				# conjunto com visual próprio e build de duas armas (espada ou maça): a outra também vira peça do conjunto
				if SET_VISUALS.has(sd.id) and build["main"].size() > 1:
					var alt_t: String = build["main"][1]
					var alt := weapon_item("leg_%s_%s_%d_%s" % [cid, bid, lv, alt_t], "%s %s" % [WEAPON_NAMES[alt_t], tail], alt_t, lv, ItemDef.RARITY_LEGENDARY, mult, col)
					alt.attributes = wpn.attributes.duplicate()
					alt.legend_effect = wpn.legend_effect.duplicate()
					if build["stat"] == "matk_pct":
						alt.matk = maxf(alt.matk, round(alt.atk * 0.9))
					made.append(alt)
					alts[alt.id] = true
				if build["off"].size() > 0:
					var off_t: String = build["off"][0]
					var off_name: String = WEAPON_NAMES[off_t] + ("" if off_t in ItemDef.OFFHAND_ONLY else " Gêmea")
					var off := weapon_item("leg_%s_%s_%d_offhand" % [cid, bid, lv], "%s %s" % [off_name, tail], off_t, lv, ItemDef.RARITY_LEGENDARY, mult, col, PIECE_WEIGHT["offhand"])
					off.attributes = _attrs(build["attr"], build["attr2"], lv, PIECE_WEIGHT["offhand"], mult)     # serve à build (escudo do Sacerdote dá WILL, não FOR)
					made.append(off)
				var vis: Dictionary = SET_VISUALS.get(sd.id, {})
				if not vis.is_empty():
					sd.name = vis["set_name"]
				for it in made:
					if not vis.is_empty():
						var piece: String = it.id.get_slice("_", it.id.get_slice_count("_") - 1)
						it.name = vis["names"].get(piece, it.name)
						if piece == "legs" and not vis["names"].has("legs"):      # calça do conjunto: nome tirado do peito (mesmo "do X")
							var bn: String = vis["names"].get("body", "")
							if bn.find(" ") > 0:
								it.name = ARMOR_NAMES[build["armor"]]["legs"] + bn.substr(bn.find(" "))
						if alts.has(it.id):         # maça do conjunto: mesmo nome da espada, trocando a arma
							it.name = (vis["names"].get("weapon", it.name) as String).replace("Espada", WEAPON_NAMES[it.weapon_type])
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
				var favor: String = SET_VISUALS.get(sd.id, {}).get("favor", "")
				if favor != "":         # conjunto de combinação (Elementalista): 4 peças dão o segundo elemento
					sd.bonuses[4][favor + "_pct"] = round((Balance.SET_FAVOR_BASE + Balance.SET_FAVOR_PER_TIER * tier) * 10.0) / 10.0
				sets.append(sd)
	return {"items": items, "sets": sets}
