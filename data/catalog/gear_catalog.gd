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
const COMMON_TIER_NAMES := ["de Bronze", "de Ferro", "de Mitril", "de Obsidiana", "de Adamante", "de Oricalco", "de Astralita"]     # 48: Ato III
## Cor própria de um tier comum (sem entrada = a mistura de sempre): o 32 e o 40 dividem a raridade épica e a mistura
## para no tier 3, então o tier do 40 (Oricalco) ganha o dourado-cobre dele para não sair igual ao de Adamante.
const COMMON_TIER_TINT := {5: Color(0.93, 0.7, 0.42), 6: Color(0.74, 0.84, 1.0)}     # 6 (48, Astralita): azul-estrela claro
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
## epíteto por nível lendário (5..30; Ato II: 35, 40 e 45; Ato III: 50)
const TIER_EPITHETS := ["da Alvorada", "do Juramento", "da Vanguarda", "da Glória", "da Lenda", "da Eternidade", "da Ascensão", "do Triunfo", "do Apogeu",
	"da Aurora Clara"]     # 50: Ato III (§8; aprovado pelo usuário 2026-11-23)
## Último nível lendário com visual próprio por build (SET_VISUALS). Acima (Ato II, fatia 1) o conjunto reaproveita o
## visual do último nível com visual (visual_of), com o nome genérico da regra; modelos próprios vêm no polimento.
const OWN_VISUALS_UNTIL := 30
const LEGENDARY_COLOR := Color(1.0, 0.6, 0.15)
## Ato II (35/40/45): UM visual novo por build ("<classe>_<build>"), o mesmo nos três níveis e no Ápice da build (no híbrido,
## o da 1ª build do par). "style" = malhas arm_<style>_* do kit (tools/blender/<classe>_sets.py); "wpn" = estilo da arma
## (padrão = style) e "shield" = do escudo (padrão = o do conjunto 30). O nível muda só a cor: "colors" = cor do item
## (tint) e "glows" = cor das peças acesas (material tint_glow* do kit, KitModel), na ordem de Balance.ACT2_SET_LEVELS
## (35 ferro de Kharzun, 40 cor de guerra, 45 apogeu, 50 "porcelana e ouro velho" do Ato III: marfim, destaque ouro velho,
## brilho rosa-pó; aprovado pelo usuário em 2026-11-23, igual em todas as builds, GDD ato3 §8).
## Opcionais (sem a chave vale a regra antiga): "accents" = destaque (tint2: pano, crina, estandarte) escolhido por nível
## (set_accent; sem ela sai de ItemDef.accent(cor)); "name" + "suffix" (+ "nouns") = nome próprio da build: as peças viram
## "<substantivo> <suffix> <TIER_EPITHETS do nível>" e o conjunto "Conjunto <name> <epíteto>" (Ápice e híbrido mantêm os
## nomes deles); "icon" = prefixo dos ícones (assets/icons/<icon>_<peça>.png), UMA foto por build, tirada na cor do 40 por
## tools/icons/set_icons.tscn (vale nos três níveis, no Ápice e na armadura do híbrido). Build sem entrada continua
## reaproveitando o visual do 30 (visual_of).
const ACT2_VISUALS := {
	"berserker_carniceiro": {"style": "ber_g35",      # Montador de Warg: crânio de warg + crina, presas nos ombros, pele nas costas
		"name": "Montador de Warg", "suffix": "do Montador de Warg", "icon": "ber_g35",
		"colors": [Color(0.6, 0.36, 0.2), Color(0.34, 0.4, 0.5), Color(0.17, 0.14, 0.2), Color(0.94, 0.9, 0.82)],
		"accents": [Color(0.5, 0.13, 0.1), Color(0.84, 0.86, 0.9), Color(0.66, 0.08, 0.1), Color(0.7, 0.52, 0.2)],
		"glows": [Color(1.0, 0.5, 0.12), Color(0.45, 0.85, 1.0), Color(1.0, 0.14, 0.1), Color(1.0, 0.62, 0.72)]},
	"berserker_executor": {"style": "ber_e35",        # Quebra-Hordas: elmo de touro, gorjal, fornalha no peito, estandarte nas costas
		"name": "Quebra-Hordas", "suffix": "do Quebra-Hordas", "icon": "ber_e35",
		"colors": [Color(0.38, 0.4, 0.46), Color(0.72, 0.5, 0.22), Color(0.88, 0.84, 0.76), Color(0.94, 0.9, 0.82)],
		"accents": [Color(0.56, 0.14, 0.1), Color(0.68, 0.1, 0.12), Color(0.15, 0.13, 0.17), Color(0.7, 0.52, 0.2)],
		"glows": [Color(1.0, 0.55, 0.15), Color(1.0, 0.85, 0.4), Color(1.0, 0.2, 0.12), Color(1.0, 0.62, 0.72)]},
	"berserker_punhos": {"style": "ber_m35",          # Tambor do Trovão: diadema de chifres, aro de tambores nas costas, manoplas de ferro
		"name": "Tambor do Trovão", "suffix": "do Tambor do Trovão", "icon": "ber_m35", "nouns": {"head": "Diadema"},
		"colors": [Color(0.24, 0.3, 0.5), Color(0.2, 0.5, 0.4), Color(0.8, 0.22, 0.12), Color(0.94, 0.9, 0.82)],
		"accents": [Color(0.86, 0.88, 0.95), Color(0.88, 0.62, 0.16), Color(0.16, 0.13, 0.15), Color(0.7, 0.52, 0.2)],
		"glows": [Color(0.6, 0.9, 1.0), Color(1.0, 0.8, 0.3), Color(1.0, 0.92, 0.6), Color(1.0, 0.62, 0.72)]},
	"assassin_laminas": {"style": "ass_l35",          # Sombra da Horda: chapéu de guerra largo, meia-máscara de osso, turíbulo de veneno, lenço de duas pontas
		"name": "Sombra da Horda", "suffix": "da Sombra da Horda", "icon": "ass_l35", "nouns": {"head": "Chapéu"},
		"colors": [Color(0.48, 0.39, 0.31), Color(0.14, 0.36, 0.32), Color(0.12, 0.11, 0.15), Color(0.94, 0.9, 0.82)],
		"accents": [Color(0.6, 0.2, 0.12), Color(0.85, 0.78, 0.5), Color(0.86, 0.83, 0.8), Color(0.7, 0.52, 0.2)],
		"glows": [Color(0.75, 1.0, 0.3), Color(0.5, 1.0, 0.45), Color(0.95, 0.3, 1.0), Color(1.0, 0.62, 0.72)]},
	"assassin_duelista": {"style": "ass_d35",         # Lâmina de Gala: chapéu de cavaleiro com pena enorme, braço esquerdo blindado, lâminas cruzadas nas costas
		"name": "Lâmina de Gala", "suffix": "da Lâmina de Gala", "icon": "ass_d35",
		"colors": [Color(0.34, 0.38, 0.44), Color(0.66, 0.14, 0.16), Color(0.9, 0.88, 0.84), Color(0.94, 0.9, 0.82)],
		"accents": [Color(0.5, 0.12, 0.16), Color(0.92, 0.88, 0.78), Color(0.16, 0.24, 0.6), Color(0.7, 0.52, 0.2)],
		"glows": [Color(1.0, 0.7, 0.3), Color(1.0, 0.88, 0.5), Color(0.5, 0.85, 1.0), Color(1.0, 0.62, 0.72)]},
	"assassin_corsario": {"style": "ass_c35",         # Costa de Ferro: bicorne com caveira, sobretudo de gola de pele, corrente de âncora
		"name": "Costa de Ferro", "suffix": "da Costa de Ferro", "icon": "ass_c35", "nouns": {"head": "Bicorne", "body": "Sobretudo"},
		"colors": [Color(0.52, 0.39, 0.28), Color(0.14, 0.22, 0.42), Color(0.13, 0.13, 0.16), Color(0.94, 0.9, 0.82)],
		"accents": [Color(0.2, 0.26, 0.4), Color(0.7, 0.14, 0.12), Color(0.86, 0.84, 0.78), Color(0.7, 0.52, 0.2)],
		"glows": [Color(1.0, 0.6, 0.2), Color(1.0, 0.82, 0.35), Color(0.4, 1.0, 0.85), Color(1.0, 0.62, 0.72)]},
	# Ranger e Elementalista (onda 1B)
	"ranger_cacador": {"style": "ran_c35",            # Batedor da Estepe: gorro de pele com cabeça e asas de falcão, manto de penas, aljavas cruzadas, capa de capim
		"name": "Batedor da Estepe", "suffix": "do Batedor da Estepe", "icon": "ran_c35",
		"colors": [Color(0.62, 0.52, 0.3), Color(0.58, 0.3, 0.22), Color(0.15, 0.17, 0.3), Color(0.94, 0.9, 0.82)],
		"accents": [Color(0.3, 0.42, 0.25), Color(0.92, 0.86, 0.7), Color(0.75, 0.8, 0.9), Color(0.7, 0.52, 0.2)],
		"glows": [Color(1.0, 0.7, 0.25), Color(0.7, 1.0, 0.85), Color(0.6, 0.85, 1.0), Color(1.0, 0.62, 0.72)]},
	"ranger_atirador": {"style": "ran_a35",           # Artilheiro de Cerco: touca de piloto, óculos e luneta de latão, cartucheiras em X, barril de pólvora com pavio aceso
		"name": "Artilheiro de Cerco", "suffix": "do Artilheiro de Cerco", "icon": "ran_a35", "nouns": {"head": "Touca", "body": "Casaco"},
		"colors": [Color(0.44, 0.39, 0.33), Color(0.3, 0.45, 0.22), Color(0.9, 0.86, 0.76), Color(0.94, 0.9, 0.82)],
		"accents": [Color(0.75, 0.55, 0.25), Color(0.85, 0.75, 0.4), Color(0.6, 0.15, 0.15), Color(0.7, 0.52, 0.2)],
		"glows": [Color(1.0, 0.55, 0.15), Color(1.0, 0.85, 0.4), Color(1.0, 0.22, 0.15), Color(1.0, 0.62, 0.72)]},
	"ranger_lanceiro": {"style": "ran_l35",           # Caça-Trolls: elmo com presas de troll enormes, gola e manto de couro de troll com espinhos, leque de dardos acesos
		"name": "Caça-Trolls", "suffix": "do Caça-Trolls", "icon": "ran_l35", "nouns": {"head": "Elmo"},
		"colors": [Color(0.46, 0.33, 0.22), Color(0.8, 0.38, 0.12), Color(0.12, 0.2, 0.17), Color(0.94, 0.9, 0.82)],
		"accents": [Color(0.7, 0.3, 0.15), Color(0.25, 0.2, 0.18), Color(0.75, 0.7, 0.5), Color(0.7, 0.52, 0.2)],
		"glows": [Color(1.0, 0.75, 0.2), Color(1.0, 0.92, 0.6), Color(0.6, 1.0, 0.35), Color(1.0, 0.62, 0.72)]},
	# Elementalista: o brilho do nível fica na faixa do elemento (fogo: brasa/chama/branco quente; gelo: verde-água/branco frio/aurora;
	# raio: âmbar/ouro claro/ciano); o 2º elemento ("favor" do 30) continua em gemas fixas no kit (elementalist_sets.ACT2_SECOND)
	"elementalist_fogo": {"style": "ele_f35",         # Forja Viva: braseiro de ferro na cabeça com chifres de chama, ombreiras de rocha com veios de magma, anel de brasas
		"name": "Forja Viva", "suffix": "da Forja Viva", "icon": "ele_f35", "nouns": {"head": "Braseiro"},
		"colors": [Color(0.42, 0.26, 0.2), Color(0.78, 0.2, 0.14), Color(0.16, 0.13, 0.17), Color(0.94, 0.9, 0.82)],
		"accents": [Color(0.8, 0.45, 0.15), Color(0.95, 0.75, 0.3), Color(0.7, 0.15, 0.1), Color(0.7, 0.52, 0.2)],
		"glows": [Color(1.0, 0.42, 0.1), Color(1.0, 0.75, 0.2), Color(1.0, 0.95, 0.7), Color(1.0, 0.62, 0.72)]},
	"elementalist_gelo": {"style": "ele_g35",         # Geleira: coroa alta e torta de cristais, ombreiras de lascas, túnica em camadas, capa de lascas de gelo
		"name": "Geleira", "suffix": "da Geleira", "icon": "ele_g35",
		"colors": [Color(0.2, 0.3, 0.36), Color(0.2, 0.42, 0.85), Color(0.86, 0.92, 0.97), Color(0.94, 0.9, 0.82)],
		"accents": [Color(0.62, 0.78, 0.82), Color(0.9, 0.95, 1.0), Color(0.32, 0.3, 0.72), Color(0.7, 0.52, 0.2)],
		"glows": [Color(0.55, 0.9, 0.95), Color(0.8, 0.96, 1.0), Color(0.75, 0.6, 1.0), Color(1.0, 0.62, 0.72)]},
	"elementalist_raio": {"style": "ele_r35",         # Para-raios: chapéu com haste de anéis, hastes nos ombros, túnica de faixas, bobinas com arco aceso
		"name": "Para-raios", "suffix": "do Para-raios", "icon": "ele_r35",
		"colors": [Color(0.4, 0.36, 0.44), Color(0.5, 0.3, 0.85), Color(0.14, 0.13, 0.24), Color(0.94, 0.9, 0.82)],
		"accents": [Color(0.8, 0.65, 0.25), Color(0.95, 0.85, 0.4), Color(0.4, 0.6, 0.9), Color(0.7, 0.52, 0.2)],
		"glows": [Color(1.0, 0.75, 0.25), Color(1.0, 0.95, 0.55), Color(0.6, 0.95, 1.0), Color(1.0, 0.62, 0.72)]},
	# Druida (onda 3): Lobo e Urso têm também a armadura de animal do estilo (form_wolf/form_bear: frm_<estilo>_*, FormModel pinta cor/destaque/brilho do nível)
	"druid_xama": {"style": "dru_x35",                # Xamã da Estepe: crânio de carneiro com chifres enrolados, cocar de penas que desce pelas costas, talismãs de osso, túnica pintada
		"name": "Xamã da Estepe", "suffix": "do Xamã da Estepe", "icon": "dru_x35", "nouns": {"head": "Cocar"},
		"colors": [Color(0.55, 0.42, 0.28), Color(0.16, 0.42, 0.42), Color(0.22, 0.16, 0.34), Color(0.94, 0.9, 0.82)],
		"accents": [Color(0.62, 0.2, 0.12), Color(0.92, 0.6, 0.2), Color(0.56, 0.26, 0.82), Color(0.7, 0.52, 0.2)],
		"glows": [Color(1.0, 0.65, 0.2), Color(0.55, 1.0, 0.6), Color(0.72, 0.55, 1.0), Color(1.0, 0.62, 0.72)]},
	"druid_fera": {"style": "dru_w35",                # Matilha de Guerra: elmo de cabeça de lobo (rosto dentro da boca), crina em crista, ombreiras com garras, coleira de cravos, couro tachado
		"name": "Matilha de Guerra", "suffix": "da Matilha de Guerra", "icon": "dru_w35", "nouns": {"head": "Elmo", "body": "Couro"},
		"colors": [Color(0.36, 0.38, 0.44), Color(0.6, 0.14, 0.14), Color(0.13, 0.13, 0.17), Color(0.94, 0.9, 0.82)],
		"accents": [Color(0.56, 0.14, 0.1), Color(0.85, 0.83, 0.8), Color(0.8, 0.88, 0.95), Color(0.7, 0.52, 0.2)],
		"glows": [Color(1.0, 0.5, 0.15), Color(1.0, 0.85, 0.4), Color(0.5, 0.85, 1.0), Color(1.0, 0.62, 0.72)]},
	"druid_guardiao_verde": {"style": "dru_b35",      # Montanha Viva: elmo de pedra com crista de musgo, lajes nos ombros com cristais acesos, placas de casca e rocha, casco de pedra nas costas
		"name": "Montanha Viva", "suffix": "da Montanha Viva", "icon": "dru_b35", "nouns": {"head": "Elmo", "body": "Casco"},
		"colors": [Color(0.5, 0.46, 0.42), Color(0.25, 0.42, 0.5), Color(0.15, 0.14, 0.18), Color(0.94, 0.9, 0.82)],
		"accents": [Color(0.34, 0.48, 0.22), Color(0.82, 0.68, 0.25), Color(0.8, 0.82, 0.7), Color(0.7, 0.52, 0.2)],
		"glows": [Color(1.0, 0.7, 0.25), Color(0.5, 0.95, 1.0), Color(0.9, 0.4, 1.0), Color(1.0, 0.62, 0.72)]},
	# Paladino (onda 4): só a ARMADURA é nova; espadas, maças e escudos continuam os do nível 30 ("wpn"; o escudo já é o do 30 sem a
	# chave "shield"). As malhas arm_pal_*35_* NÃO estão no kit principal (teto de 200 malhas): ficam no kit extra
	# kit_paladin_<sexo>_a2.glb, que o KitModel só carrega quando uma peça dessas é vestida (chibi_kit.A2_STYLES / build_kit_a2).
	"paladin_guardiao": {"style": "pal_g35", "wpn": "pal_g30",      # Baluarte de Kharzun: elmo de cerco de topo chato, crista em leque atravessada, ombreiras de torre com ameias, gola de pele
		"name": "Baluarte de Kharzun", "suffix": "do Baluarte de Kharzun", "icon": "pal_g35",
		"colors": [Color(0.42, 0.43, 0.48), Color(0.2, 0.34, 0.7), Color(0.15, 0.14, 0.2), Color(0.94, 0.9, 0.82)],
		"accents": [Color(0.58, 0.15, 0.12), Color(0.93, 0.9, 0.82), Color(0.9, 0.7, 0.25), Color(0.7, 0.52, 0.2)],
		"glows": [Color(1.0, 0.6, 0.2), Color(1.0, 0.88, 0.45), Color(0.5, 0.85, 1.0), Color(1.0, 0.62, 0.72)]},
	"paladin_cruzado": {"style": "pal_c35", "wpn": "pal_c30",       # Lança da Aurora: celada de bico, crina longa pelas costas, UMA ombreira gigante com espigão, meia-capa com gola de pele, tabardo partido
		"name": "Lança da Aurora", "suffix": "da Lança da Aurora", "icon": "pal_c35",
		"colors": [Color(0.6, 0.56, 0.5), Color(0.72, 0.14, 0.16), Color(0.93, 0.92, 0.88), Color(0.94, 0.9, 0.82)],
		"accents": [Color(0.62, 0.22, 0.14), Color(0.94, 0.9, 0.8), Color(0.18, 0.28, 0.68), Color(0.7, 0.52, 0.2)],
		"glows": [Color(1.0, 0.65, 0.25), Color(1.0, 0.85, 0.4), Color(1.0, 0.8, 0.7), Color(1.0, 0.62, 0.72)]},
	"paladin_templario": {"style": "pal_t35", "wpn": "pal_t30",     # Chama de Guerra: elmo-balde coroado com braseiro aceso, viseira em cruz, correntes com turíbulos acesos, saiote de escamas
		"name": "Chama de Guerra", "suffix": "da Chama de Guerra", "icon": "pal_t35",
		"colors": [Color(0.5, 0.36, 0.24), Color(0.9, 0.55, 0.16), Color(0.16, 0.14, 0.17), Color(0.94, 0.9, 0.82)],
		"accents": [Color(0.16, 0.14, 0.16), Color(0.6, 0.1, 0.1), Color(0.88, 0.85, 0.78), Color(0.7, 0.52, 0.2)],
		"glows": [Color(1.0, 0.45, 0.1), Color(1.0, 0.82, 0.3), Color(1.0, 0.95, 0.75), Color(1.0, 0.62, 0.72)]},
	# Necromancer e Bispo (onda 2B; nomes e ícones na passada final)
	# Bispo: os ESCUDOS continuam os do nível 30 (sem a chave "shield", visual_of já deixa o estilo do 30): orçamento de malhas do kit.
	"necromancer_invocador": {"style": "nec_i35",     # Ossuário de Guerra: coroa de ossos de dedos, crânio de orc em cada ombro, couraça de costelas, armação de espinha e costelas nas costas
		"name": "Ossuário de Guerra", "suffix": "do Ossuário de Guerra", "icon": "nec_i35", "nouns": {"head": "Coroa", "body": "Couraça"},
		"colors": [Color(0.4, 0.34, 0.3), Color(0.16, 0.42, 0.36), Color(0.3, 0.06, 0.1), Color(0.94, 0.9, 0.82)],
		"accents": [Color(0.5, 0.16, 0.14), Color(0.86, 0.82, 0.7), Color(0.8, 0.7, 0.4), Color(0.7, 0.52, 0.2)],
		"glows": [Color(0.55, 1.0, 0.5), Color(0.4, 1.0, 0.8), Color(0.6, 0.9, 1.0), Color(1.0, 0.62, 0.72)]},
	"necromancer_ceifador": {"style": "nec_c35",      # Ceifeiro do Campo: capuz alto de carrasco, laço de corda, lanternas acesas em correntes, capa de tiras de estandartes caídos
		"name": "Ceifeiro do Campo", "suffix": "do Ceifeiro do Campo", "icon": "nec_c35",
		"colors": [Color(0.36, 0.33, 0.32), Color(0.6, 0.12, 0.14), Color(0.84, 0.82, 0.8), Color(0.94, 0.9, 0.82)],
		"accents": [Color(0.55, 0.2, 0.15), Color(0.85, 0.78, 0.55), Color(0.14, 0.13, 0.16), Color(0.7, 0.52, 0.2)],
		"glows": [Color(1.0, 0.6, 0.2), Color(1.0, 0.85, 0.45), Color(0.45, 1.0, 0.6), Color(1.0, 0.62, 0.72)]},
	"necromancer_pestilento": {"style": "nec_s35",    # Sol Negro (na folha de arte: "Eclipse"; já existe o Conjunto Eclipse do 25): capuz com véu no rosto e crescente, lascas flutuando nos ombros, túnica lisa, disco de sol negro com aro aceso atrás da cabeça
		"name": "Sol Negro", "suffix": "do Sol Negro", "icon": "nec_s35",
		"colors": [Color(0.32, 0.3, 0.4), Color(0.16, 0.2, 0.6), Color(0.1, 0.09, 0.14), Color(0.94, 0.9, 0.82)],
		"accents": [Color(0.62, 0.5, 0.28), Color(0.82, 0.84, 0.92), Color(0.55, 0.1, 0.2), Color(0.7, 0.52, 0.2)],
		"glows": [Color(1.0, 0.7, 0.3), Color(0.9, 0.92, 1.0), Color(1.0, 0.25, 0.45), Color(1.0, 0.62, 0.72)]},
	"bishop_sacerdote": {"style": "bis_s35",          # Capelã de Campanha: chapéu largo de peregrino com borlas, manta e ataduras, bolsa, oratório portátil nas costas com velas acesas
		"name": "Capelã de Campanha", "suffix": "da Capelã de Campanha", "icon": "bis_s35", "nouns": {"head": "Chapéu"},
		"colors": [Color(0.52, 0.48, 0.36), Color(0.2, 0.5, 0.4), Color(0.9, 0.87, 0.8), Color(0.94, 0.9, 0.82)],
		"accents": [Color(0.62, 0.2, 0.16), Color(0.93, 0.92, 0.88), Color(0.8, 0.58, 0.2), Color(0.7, 0.52, 0.2)],
		"glows": [Color(1.0, 0.75, 0.35), Color(1.0, 0.9, 0.55), Color(0.75, 0.9, 1.0), Color(1.0, 0.62, 0.72)]},
	"bishop_inquisidor": {"style": "bis_i35",         # Farol da Aurora: tiara em gaiola com orbe aceso flutuando, mangas longas em camadas, túnica alta, gola de raios de sol atrás dos ombros
		"name": "Farol da Aurora", "suffix": "do Farol da Aurora", "icon": "bis_i35", "nouns": {"head": "Tiara"},
		"colors": [Color(0.55, 0.4, 0.36), Color(0.9, 0.6, 0.2), Color(0.2, 0.1, 0.3), Color(0.94, 0.9, 0.82)],
		"accents": [Color(0.3, 0.34, 0.5), Color(0.64, 0.13, 0.15), Color(0.9, 0.75, 0.35), Color(0.7, 0.52, 0.2)],
		"glows": [Color(1.0, 0.6, 0.25), Color(1.0, 0.95, 0.7), Color(1.0, 0.75, 0.9), Color(1.0, 0.62, 0.72)]},
	"bishop_batalha": {"style": "bis_b35",            # Martelo da Vanguarda: bacinete de ponta com camal de malha e asas varridas, manto único de placa, saiote blindado, livro acorrentado
		"name": "Martelo da Vanguarda", "suffix": "do Martelo da Vanguarda", "icon": "bis_b35",
		"colors": [Color(0.4, 0.42, 0.46), Color(0.2, 0.34, 0.66), Color(0.14, 0.14, 0.17), Color(0.94, 0.9, 0.82)],
		"accents": [Color(0.58, 0.2, 0.14), Color(0.92, 0.9, 0.84), Color(0.68, 0.1, 0.12), Color(0.7, 0.52, 0.2)],
		"glows": [Color(1.0, 0.55, 0.18), Color(1.0, 0.85, 0.4), Color(1.0, 0.95, 0.85), Color(1.0, 0.62, 0.72)]},
}
## Conjuntos lendários com visual próprio (kit: tools/blender/chibi_kit.py SET_STYLES; ícones: assets/icons/<icon>_<peça>.png).
## Referência de arte em reference/<classe>/set_N. Peças sem slot próprio no RagnaEx (polainas) vêm junto do corpo.
## Nomes das peças de conjunto (set_piece_name): substantivo da build + complemento do conjunto ("suffix" = "do X";
## "adj" = adjetivo que concorda com o substantivo: ADJ_FORMS[adj][NOUN_FORM]). "nouns" no conjunto troca o substantivo de
## uma peça (capuz, máscara...); "names" = conjunto todo escrito à mão. Calça: ARMOR_NAMES[armadura]["legs"] com o mesmo complemento.
## Ato III (nível 50, GDD ato3-lendarios-50 §3.5/§8): visual PRÓPRIO da build no tema de Lumeria (porcelana com lágrima pintada,
## máscaras, fitas de seda, lanternas, ouro velho). "style" = malhas arm_<style>_* do kit extra kit_<classe>_<sexo>_a3.glb
## (tools/blender/<classe>_sets.py ACT3_SETS; KitModel.load_addon("_a3")); sem o arquivo o boneco veste o estilo do Ato II
## (act2_fallback_style). Um só nível: "color" (tint = marfim), "accent" (tint2 = seda/fitas), "glow" (tint_glow = lágrima e
## chama). Arma e escudo continuam os do Ato II/30 (onda 4). "icon" = prefixo dos ícones (set_icons.tscn, foto no 50).
## Build sem entrada continua no visual do Ato II na 4ª cor de ACT2_VISUALS. Ondas 1 e 2: duas builds por classe.
const ACT3_VISUALS := {
	"paladin_guardiao": {"style": "pal_g50", "icon": "pal_g50",          # Vigília da Lágrima Dourada: elmo fechado com viseira-máscara e UMA lágrima, pires empilhados, lanterna na ombreira esquerda
		"color": Color(0.94, 0.9, 0.82), "accent": Color(0.12, 0.16, 0.4), "glow": Color(1.0, 0.78, 0.3)},
	"berserker_executor": {"style": "ber_e50", "icon": "ber_e50",        # Lâmina do Último Brinde: capuz de carrasco pontudo de seda negra, máscara branca com lágrima, correntes de taças
		"color": Color(0.94, 0.9, 0.82), "accent": Color(0.1, 0.09, 0.13), "glow": Color(1.0, 0.8, 0.35)},
	"bishop_sacerdote": {"style": "bis_s50", "icon": "bis_s50",          # Lanterna da Última Vigília: véu até o chão, coroa de 5 lanternas, máscara com duas lágrimas, asas de vidro
		"color": Color(0.94, 0.9, 0.82), "accent": Color(0.6, 0.58, 0.9), "glow": Color(1.0, 0.88, 0.55)},
	"druid_fera": {"style": "dru_w50", "icon": "dru_w50",                # Galope do Desfile: máscara de lobo sorridente (também no lobo: frm_dru_w50_*), fitas longas, guizos, colar de lanternas
		"color": Color(0.94, 0.9, 0.82), "accent": Color(0.08, 0.34, 0.22), "glow": Color(1.0, 0.8, 0.4)},
	"ranger_cacador": {"style": "ran_c50", "icon": "ran_c50",            # Arco da Lanterna Errante: capuz curto, máscara de pássaro, aljava-lanterna alta, capa de fitas
		"color": Color(0.94, 0.9, 0.82), "accent": Color(0.46, 0.6, 0.42), "glow": Color(1.0, 0.85, 0.5)},
	"assassin_laminas": {"style": "ass_l50", "icon": "ass_l50",          # Lágrima de Veneno: capuz justo, máscara que chora duas lágrimas verde-ouro, frascos acesos, cauda de fitas
		"color": Color(0.94, 0.9, 0.82), "accent": Color(0.09, 0.27, 0.14), "glow": Color(0.75, 1.0, 0.3)},
	"elementalist_fogo": {"style": "ele_f50", "icon": "ele_f50",         # Lanterna do Fim da Festa: coroa-lanterna alta, meia-máscara com lágrima de brasa, manto em fitas
		"color": Color(0.94, 0.9, 0.82), "accent": Color(0.92, 0.42, 0.12), "glow": Color(1.0, 0.55, 0.15)},
	"necromancer_invocador": {"style": "nec_i50", "icon": "nec_i50",     # Cortejo de Porcelana: capuz alto com máscaras-troféu, máscaras cegas nos ombros, tiras de seda
		"color": Color(0.94, 0.9, 0.82), "accent": Color(0.4, 0.14, 0.38), "glow": Color(0.8, 0.45, 1.0)},
	# Onda 2: a 2ª build de cada classe
	"paladin_cruzado": {"style": "pal_c50", "icon": "pal_c50",           # Cortejo do Juízo Claro: elmo de meia-máscara partida em diagonal, penacho, ombreiras em barbatana, espelho no peito, capa em tiras
		"color": Color(0.94, 0.9, 0.82), "accent": Color(0.45, 0.08, 0.14), "glow": Color(1.0, 0.82, 0.45)},
	"berserker_carniceiro": {"style": "ber_g50", "icon": "ber_g50",      # Banquete das Fitas Rubras: ombros nus, meia-máscara de sorriso rasgado, cinto de taças de vidro, fitas rubras nos punhos
		"color": Color(0.94, 0.9, 0.82), "accent": Color(0.72, 0.1, 0.12), "glow": Color(1.0, 0.45, 0.35)},
	"bishop_inquisidor": {"style": "bis_i50", "icon": "bis_i50",         # Espelho do Meio-Dia: mitra alta de vidro facetado com espelho, espelhos de sol nos ombros, fitas douradas
		"color": Color(0.94, 0.9, 0.82), "accent": Color(0.85, 0.66, 0.25), "glow": Color(1.0, 0.95, 0.7)},
	"druid_guardiao_verde": {"style": "dru_b50", "icon": "dru_b50",      # Guarda da Colheita Mascarada: máscara de urso (também no urso: frm_dru_b50_*), ombros de casca envernizada, lanternas-cabaça
		"color": Color(0.94, 0.9, 0.82), "accent": Color(0.3, 0.4, 0.16), "glow": Color(1.0, 0.7, 0.3)},
	"ranger_atirador": {"style": "ran_a50", "icon": "ran_a50",           # Salva do Último Baile: cartola de seda, óculos espelhados, bandoleira de cartuchos dourados, dragonas, lanterna no cinto
		"color": Color(0.94, 0.9, 0.82), "accent": Color(0.08, 0.26, 0.32), "glow": Color(1.0, 0.85, 0.5)},
	"assassin_duelista": {"style": "ass_d50", "icon": "ass_d50",         # Florete do Espelho: chapéu de pluma, dominó espelhado, botões de vidro, meia-capa de fitas
		"color": Color(0.94, 0.9, 0.82), "accent": Color(0.2, 0.2, 0.55), "glow": Color(0.7, 0.9, 1.0)},
	"elementalist_gelo": {"style": "ele_g50", "icon": "ele_g50",         # Espelho da Geada: coroa de cristais-espelho em leque, ombreiras de cacos de vidro, manto branco-azulado
		"color": Color(0.94, 0.9, 0.82), "accent": Color(0.72, 0.86, 0.95), "glow": Color(0.6, 0.95, 1.0)},
	"necromancer_ceifador": {"style": "nec_c50", "icon": "nec_c50",      # Colheita do Último Brinde: capuz rasgado, máscara sem boca, gola alta de taças quebradas, taça derramando no ombro
		"color": Color(0.94, 0.9, 0.82), "accent": Color(0.35, 0.1, 0.16), "glow": Color(1.0, 0.35, 0.4)},     # vinho mais claro: 0,22 ficava preto no toon
}

const PIECE_NOUNS := {
	"paladin_guardiao": {"body": "Couraça", "boots": "Grevas", "gloves": "Manoplas", "head": "Elmo", "offhand": "Escudo", "weapon": "Espada"},
	"paladin_cruzado": {"body": "Couraça", "boots": "Grevas", "gloves": "Manoplas", "head": "Elmo", "offhand": "Escudo", "weapon": "Espada"},
	"berserker_carniceiro": {"body": "Couraça", "boots": "Botas", "gloves": "Braçais", "head": "Elmo", "offhand": "Machado Gêmeo", "weapon": "Machado"},
	"berserker_executor": {"body": "Couraça", "boots": "Botas", "gloves": "Braçais", "head": "Elmo", "weapon": "Machado de Guerra"},
	"berserker_punhos": {"body": "Gibão", "boots": "Sandálias", "gloves": "Faixas", "head": "Faixa", "offhand": "Garra Gêmea", "weapon": "Garra"},
	"bishop_sacerdote": {"body": "Vestes", "boots": "Sandálias", "gloves": "Mangas", "head": "Véu", "offhand": "Escudo", "weapon": "Maça"},
	"bishop_inquisidor": {"body": "Vestes", "boots": "Sandálias", "gloves": "Mangas", "head": "Mitra", "weapon": "Cetro"},
	"paladin_templario": {"body": "Couraça", "boots": "Grevas", "gloves": "Manoplas", "head": "Elmo", "offhand": "Escudo", "weapon": "Martelo"},
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
	"Martelo": "ms",
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
			var a2: Dictionary = ACT2_VISUALS.get(bid_of_set(sid), {})
			var li := Balance.ACT2_SET_LEVELS.find(lv)
			if not a2.is_empty() and li >= 0:          # Ato II: malha nova da build, cor do nível (nomes e ícones seguem a regra do reaproveitado)
				v["shield"] = a2.get("shield", v["style"])
				v["style"] = a2["style"]
				v["wpn"] = a2.get("wpn", a2["style"])
				v["color"] = a2["colors"][li]
				v["glow"] = a2["glows"][li]
				v["act2"] = true
				if a2.has("accents"):
					v["accent"] = a2["accents"][li]
				if a2.has("icon"):
					v["icon"] = a2["icon"]
				if a2.has("suffix"):          # nome próprio da build + epíteto do nível ("Elmo do Quebra-Hordas do Triunfo")
					var ep: String = TIER_EPITHETS[Balance.LEGENDARY_LEVELS.find(lv)]
					v["suffix"] = "%s %s" % [a2["suffix"], ep]
					v["set_name"] = "Conjunto %s %s" % [a2.get("name", str(a2["suffix"])), ep]
					if a2.has("nouns"):
						v["nouns"] = a2["nouns"]
			var a3 := act3_of(sid)
			if not a3.is_empty():          # Ato III (50): malha própria da build (kit extra _a3), cor/destaque/brilho e ícones dela; arma e escudo seguem os de cima
				v["style"] = a3["style"]
				v["color"] = a3["color"]
				v["accent"] = a3["accent"]
				v["glow"] = a3["glow"]
				v["icon"] = a3["icon"]
				v["act3"] = true
			return v
	return {}

## Entrada de ACT2_VISUALS de um conjunto qualquer: da build, Ápice dela ou híbrido (1ª build do par). {} = build sem visual do Ato II.
static func act2_of(sid: String) -> Dictionary:
	var key := bid_of_set(sid).replace("_apex_", "_")
	var mix := key.find("_mix_")
	if mix > 0:
		var cid := key.substr(0, mix)
		var rest := key.substr(mix + 5)
		key = ""
		for k: String in ACT2_VISUALS:
			if k.begins_with(cid + "_") and rest.begins_with(k.trim_prefix(cid + "_") + "_"):
				key = k
	return ACT2_VISUALS.get(key, {})

## Entrada de ACT3_VISUALS do conjunto de build do nível 50 ({} = outro nível, Ápice/híbrido ou build ainda sem a onda dela).
static func act3_of(sid: String) -> Dictionary:
	if int(sid.get_slice("_", sid.get_slice_count("_") - 1)) != Balance.LEG50_LEVEL:
		return {}
	return ACT3_VISUALS.get(bid_of_set(sid), {})

## Cor das peças acesas (tint_glow*) de um conjunto do Ato II no nível dele; alfa 0 = o kit fica com a cor da malha.
static func set_glow(sid: String) -> Color:
	var a3 := act3_of(sid)
	if not a3.is_empty():
		return a3["glow"]
	var a2 := act2_of(sid)
	var li := Balance.ACT2_SET_LEVELS.find(int(sid.get_slice("_", sid.get_slice_count("_") - 1)))
	if a2.is_empty() or li < 0:
		return Color(0, 0, 0, 0)
	return a2["glows"][li]

## Destaque (tint2) escolhido de um conjunto do Ato II no nível dele ("accents"); alfa 0 = o derivado da cor (ItemDef.accent).
## Híbrido: a armadura veste a cor da 2ª build do par, então o destaque também é o dela.
static func set_accent(sid: String) -> Color:
	var a3 := act3_of(sid)
	if not a3.is_empty():
		return a3["accent"]
	var li := Balance.ACT2_SET_LEVELS.find(int(sid.get_slice("_", sid.get_slice_count("_") - 1)))
	if li < 0:
		return Color(0, 0, 0, 0)
	var key := bid_of_set(sid).replace("_apex_", "_")
	var mix := key.find("_mix_")
	if mix > 0:
		var cid := key.substr(0, mix)
		var rest := key.substr(mix + 5)
		key = ""
		for k: String in ACT2_VISUALS:
			if k.begins_with(cid + "_") and rest.ends_with("_" + k.trim_prefix(cid + "_")):
				key = k
	var a2: Dictionary = ACT2_VISUALS.get(key, {})
	if not a2.has("accents"):
		return Color(0, 0, 0, 0)
	return a2["accents"][li]

## Estilo do nível 30 da build dona de um estilo do Ato II ("" = não é estilo do Ato II). O KitModel veste este quando as
## malhas do estilo não existem (kit extra `_a2` ausente): o boneco fica com o visual do 30 na cor do nível.
static func act2_fallback_style(style: String) -> String:
	for k: String in ACT3_VISUALS:          # estilo do 50 sem o kit extra _a3: o do Ato II da build (que por sua vez cai no do 30)
		if ACT3_VISUALS[k]["style"] == style:
			return str(ACT2_VISUALS.get(k, {}).get("style", ""))
	for k: String in ACT2_VISUALS:
		if ACT2_VISUALS[k]["style"] == style:
			return str(SET_VISUALS.get("set_%s_%d" % [k, OWN_VISUALS_UNTIL], {}).get("style", ""))
	return ""

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

## Peças da curva dos acessórios (spec production/qa/accessory-rework-spec-2026-11-17.md).
const ACC_PIECES := ["cape", "amulet", "ring"]

## F1/F2: fator da curva dos acessórios, 1,0 no nível Balance.ACC_CURVE_REF_LEVEL (t2) e x ACC_CURVE_GROWTH a cada ACC_CURVE_STEP níveis.
## Ex.: acc_curve(16) = 1,0; acc_curve(40) = 3,375.
static func acc_curve(level: int) -> float:
	return pow(Balance.ACC_CURVE_GROWTH, (float(level) - Balance.ACC_CURVE_REF_LEVEL) / Balance.ACC_CURVE_STEP)

## F1: atributos de capa/amuleto/anel = a linear de hoje no nível de referência x acc_curve(level). Escala antiga com uma
## casa e piso 1,0, como _attrs. Ex.: acc_attrs("FOR", "VIT", 32, "ring", 1.0) = {FOR 6,7, VIT 3,2}.
static func acc_attrs(primary: String, secondary: String, level: int, piece: String, mult: float) -> Dictionary:
	var step := 1.0 / Balance.ATTR_SCALE
	var k: float = Balance.ACC_CURVE_REF_LEVEL * float(PIECE_WEIGHT[piece]) * mult * acc_curve(level)
	var a := {}
	a[primary] = maxf(1.0, snappedf(Balance.GEAR_ATTR_PRIMARY_PER_LEVEL * k, step))
	if secondary != primary:
		a[secondary] = maxf(1.0, snappedf(Balance.GEAR_ATTR_SECONDARY_PER_LEVEL * k, step))
	return a

## Índice do tier comum de um nível (-1 = fora da tabela, ex.: 45 de Kharzun).
static func acc_tier(level: int) -> int:
	return Balance.COMMON_TIER_LEVELS.find(level)

## Papéis dos acessórios (F3/F4/F5): anel = ATK plano (MATK no tema mágico), amuleto = vida % + a mana do tema, capa = a mana
## corpo a corpo. `tier` = índice em COMMON_TIER_LEVELS, -1 = Kharzun (k45). `magic` = tema/único INT/WILL.
## Ex.: acc_roles(anel, "ring", 3, false) -> it.atk = 3.
static func acc_roles(it: ItemDef, piece: String, tier: int, magic: bool) -> void:
	var k45 := tier < 0
	if piece == "ring":
		var v := float(Balance.ACC_RING_ATK_K45 if k45 else Balance.ACC_RING_ATK[tier])
		it.atk = 0.0 if magic else v
		it.matk = v if magic else 0.0
	elif piece == "amulet":
		it.bonus["hp_pct"] = Balance.ACC_AMULET_HP_PCT_K45 if k45 else float(Balance.ACC_AMULET_HP_PCT[tier])

## Soma dos atributos (escala nova, x ATTR_SCALE) da comum de um slot no tier (os 3 temas têm a mesma soma). F6.
static func acc_common_sum(piece: String, tier: int) -> int:
	var t: Array = THEMES["guerreiro"]
	var a := acc_attrs(t[1], t[2], Balance.COMMON_TIER_LEVELS[tier], piece, 1.0)
	var s := 0
	for k in a:
		s += int(round(float(a[k]) * Balance.ATTR_SCALE))
	return s

## F6: acessório único escrito à mão. Os atributos escritos no catálogo são a proporção; o total vira
## min(ACC_UNIQUE_MULT x comum do nível; ACC_UNIQUE_NEXT_CAP x comum do tier seguinte). Ganha o papel do slot no tier
## (anel: ATK ou MATK pelo 1º atributo; amuleto: vida % e mana pelo 1º atributo). DEF/MDEF escritos ficam.
static func unique_acc(it: ItemDef) -> void:
	var piece: String = {S.RING: "ring", S.AMULET: "amulet", S.CAPE: "cape"}[it.slot]
	var tier := acc_tier(it.level_req)
	var total: float = minf(Balance.ACC_UNIQUE_MULT * acc_common_sum(piece, tier), Balance.ACC_UNIQUE_NEXT_CAP * acc_common_sum(piece, mini(tier + 1, Balance.COMMON_TIER_LEVELS.size() - 1)))
	var share := 0.0
	for a in it.attributes:
		share += float(it.attributes[a])
	var out := {}
	for a in it.attributes:
		out[a] = round(total * float(it.attributes[a]) / share) / Balance.ATTR_SCALE     # escala antiga, uma casa
	var magic: bool = str(it.attributes.keys()[0]) in ["INT", "WILL"]
	it.attributes = out
	it.bonus = it.bonus.duplicate()
	acc_roles(it, piece, tier, magic)
	if piece == "amulet":
		it.bonus.merge(mana_bonus(piece, "sabio" if magic else "guerreiro", tier))

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
	if piece in ACC_PIECES:      # F1/F2: acessórios na curva ancorada no t2; DEF/MDEF da capa na mesma curva
		var fa := level_factor(int(Balance.ACC_CURVE_REF_LEVEL)) * mult * w * acc_curve(level)
		it.def = round(float(ARMOR[armor][0]) * fa)
		it.mdef = round(float(ARMOR[armor][1]) * fa)
		it.attributes = acc_attrs(attr, attr2, level, piece, mult)
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
			it.bonus = mana_bonus(piece, theme, tier)
			if piece != "cape":
				it.def = 0.0
				it.mdef = 0.0
			acc_roles(it, piece, tier, theme in Balance.MANA_SAGE_THEMES)
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
			it.bonus = mana_bonus(piece, theme, -1)
			if piece != "cape":
				it.def = 0.0
				it.mdef = 0.0
			acc_roles(it, piece, -1, theme in Balance.MANA_SAGE_THEMES)
			out.append(it)
	return out

## Joias e capas de Lumeria (nível 50, só por receita com troféu dos chefes do Excesso: RecipesCatalog.lumeria_recipes; GDD
## ato3 §8). Como as de Kharzun: tema/atributos das comuns no nível 50 com Balance.LUMERIA_JEWEL_MULT, papéis e mana do tier 48;
## raridade épica (abaixo dos acessórios lendários 50, que são x LEGENDARY_MULT). Ids `<peça>_<tema>_l50`.
static func lumeria_jewels() -> Array:
	var out: Array = []
	var lv: int = Balance.LUMERIA_JEWEL_LEVEL
	var top: int = Balance.COMMON_TIER_LEVELS.size() - 1
	for piece in THEME_PIECES:
		for theme in THEMES:
			var t: Array = THEMES[theme]
			var col: Color = (t[3] as Color).lerp(Color(0.95, 0.7, 0.78), 0.35)      # rosa-pó do Festim na cor do tema
			var it := armor_item("%s_%s_l50" % [piece, theme], "%s %s de Lumeria" % [THEME_PIECES[piece], t[0]], piece, "leather", t[1], t[2], lv,
				ItemDef.RARITY_LEGENDARY - 1, Balance.LUMERIA_JEWEL_MULT, col)
			it.armor_style = "cape" if piece == "cape" else ""
			it.bonus = mana_bonus(piece, theme, top)
			if piece != "cape":
				it.def = 0.0
				it.mdef = 0.0
			acc_roles(it, piece, top, theme in Balance.MANA_SAGE_THEMES)
			out.append(it)
	return out

## Joias de mana por tier (`tier` = índice em COMMON_TIER_LEVELS, -1 = k45). Corpo a corpo (Balance.MANA_ACC_THEMES): amuleto
## devolve mana ao abater, capa regenera mana em combate. Sábio (MANA_SAGE_THEMES): o amuleto regenera mana em combate. Anel nada.
## Ex.: mana_bonus("amulet", "sabio", 5) = {"mp_regen_combat": 0.4}.
static func mana_bonus(piece: String, theme: String, tier: int) -> Dictionary:
	var k45 := tier < 0
	if theme in Balance.MANA_ACC_THEMES:
		if piece == "amulet":
			return {"mp_on_kill": Balance.MANA_KILL_PCT_K45 if k45 else float(Balance.MANA_KILL_PCT[tier])}
		if piece == "cape":
			return {"mp_regen_combat": Balance.MANA_COMBAT_REGEN_K45 if k45 else float(Balance.MANA_COMBAT_REGEN[tier])}
	elif theme in Balance.MANA_SAGE_THEMES and piece == "amulet":
		return {"mp_regen_combat": Balance.MANA_SAGE_REGEN_K45 if k45 else float(Balance.MANA_SAGE_REGEN[tier])}
	return {}

## Peça que só sai da forja (joias/capas 45 com troféu): bots não a recebem de graça ao nascer.
static func craft_only(it: ItemDef) -> bool:
	return it.id.ends_with("_k45") or it.id.ends_with("_l50")

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

## Armas com papel no conjunto (build -> tipo de arma -> papel): "offense" = espada/montante (FOR + o outro atributo da build,
## sem MATK, ATK x LEG_SWORD_ATK_MULT, efeito da build); "defense" = maça/martelo (VIT + FOR, MATK 0, DEF, Baluarte);
## "battle" = maça do Clérigo de Batalha (FOR + VIT, MATK vira ATK e DEF, efeito da build). Escudo do conjunto das builds
## em DETERMINATION_SHIELDS ganha Determinação. Maças comuns (WEAPONS) não mudam: o Sacerdote precisa do MATK.
const WEAPON_ROLES := {
	"guardiao": {"sword": "offense", "mace": "defense"},
	"templario": {"mace": "offense", "sword": "defense"},     # martelo ataca (Penitência), espada defende (Baluarte)
	"cruzado": {"sword2h": "offense", "mace2h": "defense"},
	"batalha": {"mace": "battle"},
}
const DETERMINATION_SHIELDS := ["guardiao", "templario", "batalha"]
const ROLE_LEGENDS := {"bulwark": {"kind": "bulwark", "name": "Baluarte"}, "determination": {"kind": "determination", "name": "Determinação"}}

## Papel da arma `wtype` no conjunto da build ("" = arma sem papel: fica como sempre foi).
static func weapon_role(build_id: String, wtype: String) -> String:
	return str(WEAPON_ROLES.get(build_id, {}).get(wtype, ""))

## Efeito de papel (Baluarte, Determinação) no tier: Balance.LEG_ROLE_NUMBERS ([base, por tier] viram números).
static func role_legend(kind: String, tier: int) -> Dictionary:
	var out: Dictionary = (ROLE_LEGENDS[kind] as Dictionary).duplicate()
	var nums: Dictionary = Balance.LEG_ROLE_NUMBERS[kind]
	for k in nums:
		var v = nums[k]
		out[k] = round((float(v[0]) + float(v[1]) * tier) * 100.0) / 100.0 if v is Array else v
	return out

## Aplica o papel na arma do conjunto (atributos, ATK/MATK/DEF e efeito). Devolve false se a arma não tem papel.
## Ex.: maça do Guardião 30 -> VIT/FOR, MATK 0, DEF = ATK x LEG_MACE_DEF_PER_ATK, Baluarte.
static func apply_weapon_role(w: ItemDef, build: Dictionary, tier: int, lv: int, mult: float) -> bool:
	var role := weapon_role(str(build["id"]), w.weapon_type)
	if role == "":
		return false
	var other: String = build["attr2"] if build["attr"] == "FOR" else build["attr"]     # Guardião: VIT/FOR -> espada FOR/VIT
	match role:
		"offense":
			w.attributes = _attrs("FOR", other, lv, PIECE_WEIGHT["weapon"], mult)
			w.atk = round(w.atk * (Balance.LEG_HAMMER_ATK_MULT if w.weapon_type == "mace" else Balance.LEG_SWORD_ATK_MULT))     # martelo de ataque = ATK da espada
			w.matk = 0.0
			w.legend_effect = legend_effect(build, tier)
		"defense":
			w.attributes = _attrs("VIT", "FOR", lv, PIECE_WEIGHT["weapon"], mult)
			w.matk = 0.0
			w.def = round(w.atk * Balance.LEG_MACE_DEF_PER_ATK)
			w.legend_effect = role_legend("bulwark", tier)
		"battle":
			w.attributes = _attrs("FOR", "VIT", lv, PIECE_WEIGHT["weapon"], mult)
			w.atk = round(w.atk * Balance.LEG_BATTLE_MACE_ATK_MULT)
			w.matk = 0.0
			w.def = round(w.atk * Balance.LEG_MACE_DEF_PER_ATK)
			w.legend_effect = legend_effect(build, tier)
	return true

## Escudo do conjunto da build com Determinação (DETERMINATION_SHIELDS); outros escudos ficam como estão.
static func apply_shield_role(off: ItemDef, build: Dictionary, tier: int) -> void:
	if off.weapon_type == "shield" and str(build["id"]) in DETERMINATION_SHIELDS:
		off.legend_effect = role_legend("determination", tier)

## Descrição curta do papel da arma/escudo no conjunto (vai no fim da descrição do item; "" = sem papel).
## Ex.: maça do Guardião -> " Arma de defesa (Baluarte)."
static func role_note(it: ItemDef, build_id: String) -> String:
	var nm: String = str(it.legend_effect.get("name", ""))
	if str(it.legend_effect.get("kind", "")) == "determination":
		return " Escudo de utilidade (%s)." % nm
	match weapon_role(build_id, it.weapon_type):
		"offense":
			return " Arma de ataque (%s)." % nm
		"defense":
			return " Arma de defesa (%s)." % nm
		"battle":
			return " Arma da linha de frente (%s): ATK e DEF no lugar do MATK." % nm
	return ""

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
	"templario+guardiao": {"name": "Égide Ardente", "of": "da Égide Ardente", "text": {
		"all": "bloquear põe Penitência no atacante; a explosão dá 2 de Juramento"}},
	"batalha+sacerdote": {"name": "Graça em Combate", "of": "da Graça em Combate", "text": {
		"all": "a cada 3 golpes de maça a Graça dispara e o aliado curado ganha uma Égide"}},
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
## Conjuntos Ápice (design/gdd/apice-sets.md): um por build, aprofundando a mecânica dela (no lugar dos híbridos de
## armas diferentes). Nome do conjunto, complemento das peças ("do X") e texto do efeito de 5 peças. Uma build nova ganha um
## Ápice com uma linha aqui e números em Balance.APEX_NUMBERS.
const APEX := {
	"carniceiro": {"name": "da Tormenta Gêmea", "of": "da Tormenta Gêmea", "text":
		"golpe direto dá Frenesi da Tormenta (velocidade de ataque, até 5); o Arremesso Brutal gasta as cargas e bate mais por carga"},
	"executor": {"name": "do Cadafalso", "of": "do Cadafalso", "text":
		"skills de golpe em um alvo com machado de 2 mãos batem mais; o limiar de execução sobe (vale para o Carrasco) e golpes abaixo dele batem mais"},
	"punhos": {"name": "do Punho Implacável", "of": "do Punho Implacável", "text":
		"crítico com as garras também contra-ataca (como a esquiva); +esquiva"},
	"cruzado": {"name": "do Veredito", "of": "do Veredito", "text":
		"tentar atordoar (Julgamento da arma ou skill que atordoa, mesmo em chefe) deixa o alvo Julgado: todo o seu dano nele é maior; +chance de Julgamento"},
	"inquisidor": {"name": "da Aurora Ardente", "of": "da Aurora Ardente", "text":
		"magia sagrada dá Aurora (+ATK e +MATK por 4 s; renova, não acumula)"},
	"guardiao_verde": {"name": "da Casca Ancestral", "of": "da Casca Ancestral", "text":
		"ao ser atingido, a Pele de Carvalho cobre você e o aliado mais ferido (com recarga); o Urro da Mata zera a recarga"},
	"fera": {"name": "da Matilha Rubra", "of": "da Matilha Rubra", "text":
		"todo o seu dano em alvo sangrando (a Mordida conta) é maior"},
	"xama": {"name": "da Maré Lunar", "of": "da Maré Lunar", "text":
		"suas magias em alvo com Fogo Lunar batem mais; Fogo Lunar em alvo já marcado salta para o inimigo mais perto"},
	"cacador": {"name": "do Faro do Lince", "of": "do Faro do Lince", "text":
		"golpes do lince aplicam a Marca do Caçador; o lince bate mais em alvo retardado"},
	"atirador": {"name": "do Posto Avançado", "of": "do Posto Avançado", "text":
		"+1 torreta (a 2ª mais fraca) que atira primeiro em alvo preso, retardado ou marcado; +1 armadilha; aliados perto da torreta regeneram vida"},
	"lanceiro": {"name": "da Presa Aberta", "of": "da Presa Aberta", "text":
		"golpes abrem Feridas (2 em alvo retardado ou preso); com todas abertas o alvo sangra"},
	"laminas": {"name": "da Sombra Peçonhenta", "of": "da Sombra Peçonhenta", "text":
		"avançar ou esquivar deixa a próxima facada furtiva; a facada furtiva aplica Veneno Letal"},
	"duelista": {"name": "da Cadência Perfeita", "of": "da Cadência Perfeita", "text":
		"crítico com espada dá Cadência (esquivar dá 2); com 5 vira Foco do Duelista"},
	"corsario": {"name": "da Salva Final", "of": "da Salva Final", "text":
		"crítico com espada dá Bravata; Bravata cheia dispara a pistola de graça no próximo golpe de espada"},
}
## Cor do Ápice (R-AP5, constantes visuais): a do conjunto 30 da build escurecida e puxada para o dourado.
const APEX_DARKEN := 0.25
const APEX_GILD := 0.20
const HYBRID_NUMERALS := ["I", "II", "III", "IV", "V"]

## Pares de builds da classe que ainda têm híbrido (Fusão em FUSIONS): [A, B] na ordem A+B, B+C, C+A.
static func hybrid_pairs(cls: ClassDef) -> Array:
	var out: Array = []
	var n := cls.builds.size()
	if n < 2:
		return out
	for i in range(n if n > 2 else 1):
		var pair := [str(cls.builds[i]["id"]), str(cls.builds[(i + 1) % n]["id"])]
		if FUSIONS.has("%s+%s" % pair):          # os pares de armas diferentes viraram Ápices (apice-sets.md §5)
			out.append(pair)
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
				var va := visual_of("set_%s_%s_%d" % [cid, pair[0], lv])          # do nível: a build com visual do Ato II usa o novo
				var vb := visual_of("set_%s_%s_%d" % [cid, pair[1], lv])
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
				var role_of := {}          # id da arma -> build (descrição do papel)
				var has_def := false
				for bd in [ba, bb]:
					var bid: String = bd["id"]
					var other: String = bb["attr"] if bid == pair[0] else ba["attr"]
					var vw := visual_of("set_%s_%s_%d" % [cid, bid, lv])
					var wl: Array = []
					var main_t: String = bd["main"][0]
					var nouns: Dictionary = PIECE_NOUNS["%s_%s" % [cid, bid]]
					var wpn := weapon_item("%s_%s_weapon" % [base, bid], "%s %s" % [str(nouns.get("weapon", WEAPON_NAMES[main_t])), tail], main_t, lv, ItemDef.RARITY_LEGENDARY, mult, col)
					wpn.attributes = _attrs(bd["attr"], other, lv, PIECE_WEIGHT["weapon"], mult)
					if bd["stat"] == "matk_pct":
						wpn.matk = maxf(wpn.matk, round(wpn.atk * Balance.LEGEND_MATK_FROM_ATK))
					wpn.legend_effect = legend_effect(bd, tier)
					apply_weapon_role(wpn, bd, tier, lv, mult)
					wl.append(wpn)
					# a maça/martelo de defesa (Baluarte) entra uma vez no par (Égide Ardente: a do Guardião; a espada de defesa do
					# Templário fica só no conjunto dele)
					for alt_t: String in bd["main"]:
						if weapon_role(bid, alt_t) == "defense" and alt_t in ["mace", "mace2h"] and not has_def:
							has_def = true
							var alt := weapon_item("%s_%s" % [base, alt_t], "%s %s" % [WEAPON_NAMES[alt_t], tail], alt_t, lv, ItemDef.RARITY_LEGENDARY, mult, col)
							apply_weapon_role(alt, bd, tier, lv, mult)
							wl.append(alt)
					if bd["off"].size() > 0:
						var off_t: String = bd["off"][0]
						var off := weapon_item("%s_%s_offhand" % [base, bid], "%s %s" % [str(nouns.get("offhand", WEAPON_NAMES[off_t])), tail], off_t, lv, ItemDef.RARITY_LEGENDARY, mult, col, PIECE_WEIGHT["offhand"])
						off.attributes = _attrs(bd["attr"], other, lv, PIECE_WEIGHT["offhand"], mult)
						apply_shield_role(off, bd, tier)
						wl.append(off)
					for w in wl:
						var piece: String = "offhand" if w.id.ends_with("_offhand") else ("mace" if w.weapon_type in ["mace", "mace2h"] and weapon_role(str(bd["id"]), w.weapon_type) == "defense" else "weapon")
						if vw.has("style"):
							if w.weapon_type == "shield":
								w.shield_style = vw.get("shield", vw["style"])
							elif w.slot == S.WEAPON or w.weapon_type == "pistol":
								w.weapon_style = vw.get("wpn", vw["style"])
							if vw.has("icon"):
								w.icon = "%s_%s" % [vw["icon"], piece]
						if names.has(w.name):          # mesma arma nas duas builds: o nome leva o efeito lendário
							w.name = "%s (%s)" % [w.name, str(bd["legend"]["name"])]
						names[w.name] = true
						role_of[w.id] = bid
						sd.alt_pieces.append(w.id)
						made.append(w)
				for it in made:
					it.set_id = sd.id
					it.class_restriction = restrict
					var hands := "Duas mãos. " if it.is_two_handed() else ""
					if it.id.ends_with("_offhand") and it.slot == S.WEAPON:
						hands = "Mão secundária (Shift+clique na bolsa). "
					if it.slot in [S.WEAPON, S.OFFHAND]:
						it.description = "%sArma do %s (%s, híbrido %s + %s): não conta nas peças; %s" % [hands, sd.name, cls.name, ba["name"], bb["name"],
							"tem efeito lendário próprio." if not it.legend_effect.is_empty() else "acompanha o conjunto."] + role_note(it, str(role_of.get(it.id, "")))
					else:
						it.description = "Peça do %s (%s, híbrido %s + %s)." % [sd.name, cls.name, ba["name"], bb["name"]]
				items.append_array(made)
				sd.bonuses = hybrid_bonuses(ba, bb, skills, lv, tier, fid)
				sets.append(sd)
	return {"items": items, "sets": sets}

static func apex_set_id(class_id: String, build_id: String, level: int) -> String:
	return "set_%s_apex_%s_%d" % [class_id, build_id, level]

## Números do Ápice no tier (F-AP1, igual à F-FUS1).
static func apex_numbers(bid: String, tier: int) -> Dictionary:
	var out := {}
	var nums: Dictionary = Balance.APEX_NUMBERS.get(bid, {})
	for k in nums:
		var v = nums[k]
		out[k] = snappedf(float(v[0]) + float(v[1]) * (tier - 6), 0.01) if v is Array else v
	return out

## Cor do Ápice (R-AP5): a do conjunto 30 da build, escurecida e dourada.
static func apex_color(base: Color) -> Color:
	return base.darkened(APEX_DARKEN).lerp(LEGENDARY_COLOR, APEX_GILD)

## Conjuntos Ápice (R-AP1..R-AP5): por build em APEX, nos níveis HYBRID_LEVELS. 5 de armadura da build; as armas da build
## como peças alternativas (efeito lendário próprio); 2-4 peças = as do conjunto da build; 5 = efeito Ápice.
static func apex_sets(classes: Dictionary, skills: Dictionary) -> Dictionary:
	var items: Array = []
	var sets: Array = []
	var mult: float = Balance.LEGENDARY_MULT
	for cid in classes:
		var cls: ClassDef = classes[cid]
		var restrict: Array[String] = [cid]
		for build in cls.builds:
			var bid: String = build["id"]
			if not APEX.has(bid):
				continue
			var ap: Dictionary = APEX[bid]
			var nouns: Dictionary = PIECE_NOUNS.get("%s_%s" % [cid, bid], {})
			for hi in range(Balance.HYBRID_LEVELS.size()):
				var lv: int = Balance.HYBRID_LEVELS[hi]
				var vis := visual_of("set_%s_%s_%d" % [cid, bid, lv])          # o do nível: o Ápice divide o visual do Ato II da build
				var col := apex_color(vis.get("color", cls.color.lerp(LEGENDARY_COLOR, 0.35)))
				var tier := Balance.legend_tier(lv)
				var tail := "%s Ápice %s" % [ap["of"], HYBRID_NUMERALS[hi]]
				var sd := SetDef.new()
				sd.id = apex_set_id(cid, bid, lv)
				sd.name = "Conjunto %s Ápice %s" % [ap["name"], HYBRID_NUMERALS[hi]]
				sd.class_id = cid
				sd.level = lv
				sd.apex = bid
				sd.fusion = "apice_" + bid
				var base := "leg_%s_apex_%s_%d" % [cid, bid, lv]
				var made: Array = []
				for piece in PIECES:
					var noun: String = ARMOR_NAMES[build["armor"]]["legs"] if piece == "legs" else str(nouns.get(piece, ARMOR_NAMES[build["armor"]][piece]))
					var it := armor_item("%s_%s" % [base, piece], "%s %s" % [noun, tail], piece, build["armor"], build["attr"], build["attr2"], lv, ItemDef.RARITY_LEGENDARY, mult, col)
					if piece != "legs" and vis.has("style"):
						it.armor_style = vis["style"]
						it.icon = "%s_%s" % [vis["icon"], piece] if vis.has("icon") else ""
					sd.armor.append(it.id)
					sd.pieces.append(it.id)
					made.append(it)
				# armas da build: main[0], main[1] (se houver), off[0] (se houver), cada uma com o efeito lendário da build
				var le := legend_effect(build, tier)
				var wl: Array = []
				var main_t: String = build["main"][0]
				wl.append(weapon_item("%s_weapon" % base, "%s %s" % [str(nouns.get("weapon", WEAPON_NAMES[main_t])), tail], main_t, lv, ItemDef.RARITY_LEGENDARY, mult, col))
				if build["main"].size() > 1:
					var alt_t: String = build["main"][1]
					wl.append(weapon_item("%s_%s" % [base, alt_t], "%s %s" % [WEAPON_NAMES[alt_t], tail], alt_t, lv, ItemDef.RARITY_LEGENDARY, mult, col))
				if build["off"].size() > 0:
					var off_t: String = build["off"][0]
					var off_name: String = str(nouns.get("offhand", WEAPON_NAMES[off_t] + ("" if off_t in ItemDef.OFFHAND_ONLY else " Gêmea")))
					wl.append(weapon_item("%s_offhand" % base, "%s %s" % [off_name, tail], off_t, lv, ItemDef.RARITY_LEGENDARY, mult, col, PIECE_WEIGHT["offhand"]))
				for w: ItemDef in wl:
					var off_piece := w.id.ends_with("_offhand")
					w.attributes = _attrs(build["attr"], build["attr2"], lv, PIECE_WEIGHT["offhand" if off_piece else "weapon"], mult)
					if not off_piece:
						w.legend_effect = le.duplicate()
						if build["stat"] == "matk_pct":
							w.matk = maxf(w.matk, round(w.atk * Balance.LEGEND_MATK_FROM_ATK))
						apply_weapon_role(w, build, tier, lv, mult)          # Cruzado: montante ataca, martelo defende
					else:
						apply_shield_role(w, build, tier)
					if vis.has("style"):
						if w.weapon_type == "shield":
							w.shield_style = vis.get("shield", vis["style"])
						elif w.slot == S.WEAPON or w.weapon_type == "pistol":
							w.weapon_style = vis.get("wpn", vis["style"])
						if vis.has("icon"):
							w.icon = "%s_%s" % [vis["icon"], "offhand" if off_piece else "weapon"]
					sd.alt_pieces.append(w.id)
					made.append(w)
				for it in made:
					it.set_id = sd.id
					it.class_restriction = restrict
					var hands := "Duas mãos. " if it.is_two_handed() else ""
					if it.id.ends_with("_offhand") and it.slot == S.WEAPON:
						hands = "Mão secundária (Shift+clique na bolsa). "
					if it.slot in [S.WEAPON, S.OFFHAND]:
						it.description = "%sArma do %s (%s, Ápice %s): não conta nas peças; tem efeito lendário próprio." % [hands, sd.name, cls.name, build["name"]] + role_note(it, bid)
					else:
						it.description = "Peça do %s (%s, Ápice %s)." % [sd.name, cls.name, build["name"]]
				items.append_array(made)
				var picks := set_skills(build, skills, lv, tier)
				var nb := set_bonuses(build, picks[0], picks[1], tier)
				var f := apex_numbers(bid, tier)
				f["id"] = sd.fusion
				sd.bonuses = {2: (nb[2] as Dictionary).duplicate(true), 3: (nb[3] as Dictionary).duplicate(true), 4: (nb[4] as Dictionary).duplicate(true), 5: {"fusion": f}}
				sets.append(sd)
	return {"items": items, "sets": sets}

## Acessórios lendários (spec production/qa/legendary-accessories-spec-2026-11-16.md, re-base da rev2): por build e nível de
## Balance.ACT2_SET_LEVELS (35/40/45/50), Manto/Medalhão/Anel/Sinete. Não são conjunto (set_id ""). Atributos/DEF pela curva F1/F2 x
## LEGENDARY_MULT; papéis no valor k45 (anel ATK ou MATK, amuleto vida %); mana herdada do k45 (FOR/AGI: tema guerreiro,
## INT/WILL: sábio; VIT nada); bônus da build por Balance.LEG_ACC_BUILDS/LEG_ACC_STEP. Id `leg_acc_<classe>_<build>_<nível>_<peça>`.
const LEG_ACC_NAMES := {"cape": "Manto", "amulet": "Medalhão", "ring": "Anel", "signet": "Sinete"}

## Tema de mana herdada da build (R-LA4): "guerreiro" (FOR/AGI), "sabio" (INT/WILL) ou "" (VIT).
static func leg_acc_theme(build: Dictionary) -> String:
	if str(build["attr"]) in ["FOR", "AGI"]:
		return "guerreiro"
	if str(build["attr"]) in ["INT", "WILL"]:
		return "sabio"
	return ""

## Id do acessório lendário. Ex.: leg_acc_id("paladin", "guardiao", 45, "signet") = "leg_acc_paladin_guardiao_45_signet".
static func leg_acc_id(class_id: String, build_id: String, level: int, piece: String) -> String:
	return "leg_acc_%s_%s_%d_%s" % [class_id, build_id, level, piece]

static func legendary_accessories(classes: Dictionary) -> Array:
	var out: Array = []
	for cid in classes:
		var cls: ClassDef = classes[cid]
		var restrict: Array[String] = [cid]
		var col: Color = cls.color.lerp(LEGENDARY_COLOR, 0.35)
		for build in cls.builds:
			var bid: String = build["id"]
			var roles: Dictionary = Balance.LEG_ACC_BUILDS.get(bid, {})
			var magic: bool = str(build["attr"]) in ["INT", "WILL"] or build["stat"] == "matk_pct"
			var theme := leg_acc_theme(build)
			var bmult := float(Balance.LEG_ACC_BUILD_MULT.get(bid, 1.0))
			for hi in range(Balance.ACT2_SET_LEVELS.size()):
				var lv: int = Balance.ACT2_SET_LEVELS[hi]
				var tail := "%s %s" % [build["of"], TIER_EPITHETS[Balance.legend_tier(lv)]]
				for piece in Balance.LEG_ACC_PIECES:
					var base_piece: String = "ring" if piece == "signet" else piece
					var it := armor_item(leg_acc_id(cid, bid, lv, piece), "%s %s" % [LEG_ACC_NAMES[piece], tail], base_piece, "leather",
						build["attr"], build["attr2"], lv, ItemDef.RARITY_LEGENDARY, Balance.LEGENDARY_MULT, col)
					it.armor_style = "cape" if piece == "cape" else ""
					if piece != "cape":
						it.def = 0.0
						it.mdef = 0.0
					it.bonus = {}
					acc_roles(it, base_piece, -1, magic)
					if theme != "":
						var mb := mana_bonus(base_piece, theme, -1)
						for k in mb:
							it.bonus[k] = float(it.bonus.get(k, 0.0)) + float(mb[k])
					var stat: String = roles.get(piece, "")
					if stat != "":
						it.bonus[stat] = float(it.bonus.get(stat, 0.0)) + snappedf(float(Balance.LEG_ACC_STEP[stat][hi]) * bmult, 0.01)
					it.class_restriction = restrict
					it.description = "Acessório lendário (%s, %s): não conta nas peças do conjunto." % [cls.name, build["name"]]
					out.append(it)
	return out

## Gera tudo. Retorna {"items": [ItemDef], "sets": [SetDef]}.
## Lendários do 50 (design/gdd/ato3-lendarios-50.md, onda 0): efeito de cada peça do conjunto de build do 50 por família
## (PieceEffects). Sem números aqui: "x"/"y"/"icd" (e "-x") são lidos de Balance.LEG50_NUMBERS[<build>][<peça>]; o texto
## da dica usa {x}/{y}/{icd}. Peças: head body legs gloves boots weapon weapon2 (2ª arma do Paladino) offhand.
const LEG50 := {
	"guardiao": {
		"head": {"kind": "cap_up", "caps": {"oath": "x"}, "text": "Juramento: +{x} cargas no máximo."},
		"body": {"kind": "stat", "stats": {"ally_guard": "x"}, "text": "Escudo dos Irmãos +{x}%: parte do dano dos aliados por perto vem para você."},
		"legs": {"kind": "stat", "stats": {"low_dr": "x"}, "text": "Firme na Queda +{x}%: menos dano recebido com pouca vida."},
		"gloves": {"kind": "charges", "skill": "pal_shield_bash", "text": "Pancada de Escudo em Cargas."},
		"boots": {"kind": "on_trigger", "on": "block", "do": [{"do": "cd_cut", "skill": "pal_taunt", "s": "x"}], "text": "Bloquear tira {x} s da recarga de Provocar (1 vez a cada {icd} s)."},
		"weapon": {"kind": "legend_wake", "legend": "holy_edge", "wake": "oath", "n": "x", "text": "Lâmina Justa Desperta: o golpe sagrado extra dá +{x} Juramento."},
		"weapon2": {"kind": "legend_wake", "legend": "bulwark", "wake": "ally", "pct": "x", "text": "Baluarte Desperto: a barreira também cobre o aliado mais ferido por perto com {x}% dela."},
		"offhand": {"kind": "on_trigger", "on": "det_full", "do": [{"do": "barrier", "pct": "x", "allies": true}], "text": "Determinação cheia: barreira de {x}% da vida em você e nos aliados a 8 m (1 vez a cada {icd} s)."},
	},
	"cruzado": {
		"head": {"kind": "legend_up", "legend": "stun", "adds": {"chance": "x"}, "text": "Julgamento: +{x}% de chance de atordoar."},
		"body": {"kind": "stat", "stats": {"cc_resist_pct": "x"}, "text": "-{x}% de duração de atordoar, prender e lentidão em você."},
		"legs": {"kind": "stat", "stats": {"skill_dmg": {"pal_crusader_strike": "x"}}, "text": "Golpe do Cruzado: +{x}% de dano."},
		"gloves": {"kind": "charges", "skill": "pal_lunge", "text": "Estocada Sagrada em Cargas."},
		"boots": {"kind": "on_trigger", "on": "stun_proc", "do": [{"do": "curse", "pct": "x", "time": "y"}], "text": "Quem o Julgamento atordoa fica Julgado: +{x}% de dano recebido por {y} s."},
		"weapon": {"kind": "legend_wake", "legend": "stun", "wake": "splash", "dur": "x", "text": "Julgamento Desperto: atordoa também até 2 inimigos comuns a 3 m do alvo por {x} s (chefe nunca)."},
		"weapon2": {"kind": "legend_wake", "legend": "bulwark", "wake": "wave", "pct": "x", "text": "Baluarte Desperto: quando a barreira quebra, onda sagrada de {x}% do ATK a 3 m."},
	},
	"templario": {
		"head": {"kind": "legend_up", "legend": "penance", "adds": {"stacks": "-x"}, "text": "Penitência explode com {x} carga a menos (mínimo 3)."},
		"body": {"kind": "skill_mods", "skill": "pal_blessed_hammers", "mod": {"add": {"orbit": {"count": "x"}}}, "text": "Martelos Abençoados: +{x} martelo em órbita."},
		"legs": {"kind": "stat", "stats": {"def_atk_pct": "x"}, "text": "{x}% da DEF vira ATK."},
		"gloves": {"kind": "charges", "skill": "pal_brand", "text": "Marca da Penitência em Cargas."},
		"boots": {"kind": "on_trigger", "on": "penance_burst", "do": [{"do": "gain", "what": "oath", "n": "x"}], "text": "A explosão da Penitência dá +{x} Juramento."},
		"weapon": {"kind": "legend_wake", "legend": "penance", "wake": "zone", "time": "x", "text": "Penitência Desperta: a explosão deixa Chão Sagrado por {x} s."},
		"weapon2": {"kind": "legend_wake", "legend": "bulwark", "wake": "det", "n": "x", "text": "Baluarte Desperto: ganhar a barreira dá +{x} Determinação."},
		"offhand": {"kind": "cap_up", "caps": {"penance_det": "x"}, "text": "Cada carga de Determinação: +{x}% no dano da explosão da Penitência."},
	},
	"carniceiro": {
		"head": {"kind": "legend_up", "legend": "frenzy", "adds": {"max": "x"}, "text": "Frenesi: +{x} carga no máximo."},
		"body": {"kind": "stat", "stats": {"leech_shield": "x"}, "text": "Roubo de vida que passa do máximo vira barreira (até {x}% da vida)."},
		"legs": {"kind": "stat", "stats": {"low_hp_atk": "x"}, "text": "Fúria da Beira: até +{x}% de dano quanto menor a vida."},
		"gloves": {"kind": "charges", "skill": "ber_throw_axe", "text": "Arremesso Brutal em Cargas."},
		"boots": {"kind": "on_trigger", "on": "hit:ber_blade_rush", "do": [{"do": "gain", "what": "frenzy", "n": "x"}], "text": "Investida de Lâminas que acerta dá +{x} Frenesi (1 vez a cada {icd} s)."},
		"weapon": {"kind": "legend_wake", "legend": "frenzy", "wake": "echo", "chance": "x", "pct": "y", "text": "Frenesi Desperto: com o Frenesi cheio, {x}% de chance de o golpe bater de novo com {y}%."},
		"offhand": {"kind": "stat", "stats": {"crit_leech": "x"}, "text": "Sangue no Fio: {x}% do dano crítico volta como vida."},
	},
	"executor": {
		"head": {"kind": "legend_up", "legend": "execute", "adds": {"below_pts": "x"}, "text": "Carrasco: o limiar sobe {x} pontos de % da vida."},
		"body": {"kind": "stat", "stats": {"low_dr": "x"}, "text": "Firme na Queda +{x}%: menos dano recebido com pouca vida."},
		"legs": {"kind": "skill_mods", "skill": "ber_sunder", "mod": {"add": {"sunder": {"add": "x"}}}, "text": "Fender Armadura põe +{x} carga de rachadura."},
		"gloves": {"kind": "charges", "skill": "ber_decapitate", "text": "Decapitar em Cargas."},
		"boots": {"kind": "on_trigger", "on": "kill", "do": [{"do": "cd_reset", "skill": "ber_execute"}], "text": "Abater zera a recarga de Executar (1 vez a cada {icd} s)."},
		"weapon": {"kind": "legend_wake", "legend": "execute", "wake": "crit", "text": "Carrasco Desperto: abaixo do limiar, o Golpe Avassalador é crítico garantido."},
	},
	"punhos": {
		"head": {"kind": "on_trigger", "on": "dodge", "do": [{"do": "mp", "pct": "x"}, {"do": "cd_cut", "skill": "ber_counter_stance", "s": "y"}], "text": "Esquivar devolve {x}% de MP e tira {y} s da Postura do Contra-Golpe (1 vez a cada {icd} s)."},
		"body": {"kind": "stat", "stats": {"evasion": "x"}, "text": "+{x}% de esquiva."},
		"legs": {"kind": "stat", "stats": {"hit_slow": "x"}, "text": "Golpe físico retarda o alvo {x}%."},
		"gloves": {"kind": "charges", "skill": "ber_tiger_pounce", "text": "Bote do Tigre em Cargas."},
		"boots": {"kind": "on_trigger", "on": "dodge", "do": [{"do": "gain", "what": "fury", "n": "x"}], "text": "Esquivar dá +{x} Fúria do Punho a mais (1 vez a cada {icd} s)."},
		"weapon": {"kind": "legend_wake", "legend": "fist_counter", "wake": "splash", "pct": "x", "text": "Punho Vingativo Desperto: o contra-ataque atinge também os inimigos a 2 m com {x}%."},
		"offhand": {"kind": "stat", "stats": {"crit": "x"}, "text": "+{x}% de crítico."},
	},
	"sacerdote": {
		"head": {"kind": "stat", "stats": {"overheal_share": "x"}, "text": "Graça Transbordante: {x}% da cura que passa do máximo vai para o aliado mais ferido."},
		"body": {"kind": "legend_up", "legend": "ward", "adds": {"targets": "x"}, "text": "Égide cobre também +{x} aliado (o mais ferido por perto)."},
		"legs": {"kind": "stat", "stats": {"mp_regen_combat": "x"}, "text": "+{x}% da mana por segundo em combate."},
		"gloves": {"kind": "charges", "skill": "bis_renew", "text": "Renovar em Cargas."},
		"boots": {"kind": "on_trigger", "on": "block", "do": [{"do": "cleanse"}], "text": "Bloquear tira 1 efeito ruim do aliado mais ferido (1 vez a cada {icd} s)."},
		"weapon": {"kind": "legend_wake", "legend": "ward", "wake": "low", "pct": "x", "text": "Égide Desperta: em aliado abaixo de 35% da vida a Égide vale +{x}%."},
		"offhand": {"kind": "cap_up", "caps": {"grace": "x"}, "text": "Graça: o bloqueio cura +{x} pontos de % da vida."},
	},
	"inquisidor": {
		"head": {"kind": "stat", "stats": {"radiance": "x", "radiance_cap": "y"}, "text": "Radiância +{x}% e teto +{y}."},
		"body": {"kind": "charges", "skill": "bis_hammer", "text": "Martelo de Luz em Cargas."},
		"legs": {"kind": "stat", "stats": {"mp_cost_pct": "x"}, "text": "-{x}% de custo de mana."},
		"gloves": {"kind": "legend_up", "legend": "cast_on_basic", "adds": {"chance": "x"}, "text": "Castigo Sagrado: +{x}% de chance."},
		"boots": {"kind": "stat", "stats": {"skill_dmg": {"bis_exorcism": "x"}}, "text": "Exorcismo: +{x}% de dano."},
		"weapon": {"kind": "legend_wake", "legend": "cast_on_basic", "wake": "power", "pct": "x", "text": "Castigo Sagrado Desperto: o Castigo lançado pela arma bate +{x}%."},
	},
	"batalha": {
		"head": {"kind": "skill_mods", "skill": "bis_faith_banner", "mod": {"add": {"zone": {"duration": "x"}}}, "text": "Estandarte da Fé dura +{x} s."},
		"body": {"kind": "stat", "stats": {"phys_mend": "x"}, "text": "{x}% do dano físico cura o aliado mais ferido."},
		"legs": {"kind": "stat", "stats": {"block": "x"}, "text": "+{x}% de bloqueio."},
		"gloves": {"kind": "charges", "skill": "bis_holy_blow", "text": "Martelada da Fé em Cargas."},
		"boots": {"kind": "zone_on_cast", "skill": "bis_faith_leap", "zone": {"ally_heal": "x", "duration": "y"}, "text": "Salto da Fé deixa um chão que cura os aliados por {y} s."},
		"weapon": {"kind": "legend_wake", "legend": "mend", "wake": "overflow", "pct": "x", "text": "Mão que Cura Desperta: a cura que passa do máximo vira barreira (até {x}% da vida)."},
		"offhand": {"kind": "on_trigger", "on": "det_full", "do": [{"do": "heal_allies", "pct": "x"}], "text": "Determinação cheia: cura {x}% da vida de você e dos aliados a 8 m (1 vez a cada {icd} s)."},
	},
	"guardiao_verde": {
		"head": {"kind": "legend_up", "legend": "cast_when_hit", "adds": {"icd": "-x"}, "text": "Casca Viva: recarga -{x} s."},
		"body": {"kind": "form_up", "form": "bear", "stats": {"hp_pct": "x"}, "text": "Na forma de urso: +{x}% de vida."},
		"legs": {"kind": "stat", "stats": {"threat_pct": "x"}, "text": "+{x}% de ameaça."},
		"gloves": {"kind": "charges", "skill": "dru_maul", "text": "Esmagar em Cargas."},
		"boots": {"kind": "on_trigger", "on": "cast:dru_bellow", "do": [{"do": "barrier", "pct": "x", "allies": true}], "text": "Urro da Mata dá barreira de {x}% da vida a você e aos aliados a 8 m."},
		"weapon": {"kind": "legend_wake", "legend": "cast_when_hit", "wake": "ally", "text": "Casca Viva Desperta: a Pele de Carvalho cobre também o aliado mais ferido por perto."},
	},
	"fera": {
		"head": {"kind": "legend_up", "legend": "bleed", "adds": {"chance": "x"}, "text": "Sangue da Matilha: +{x}% de chance."},
		"body": {"kind": "form_up", "form": "wolf", "mult": "x", "text": "Na forma de lobo: o bônus da forma vale +{x}%."},
		"legs": {"kind": "stat", "stats": {"speed_pct": "x"}, "text": "+{x}% de velocidade."},
		"gloves": {"kind": "charges", "skill": "dru_pounce", "text": "Bote em Cargas."},
		"boots": {"kind": "on_trigger", "on": "hit:dru_pounce", "do": [{"do": "bleed"}], "text": "Bote aplica o Sangue da Matilha com 100% de chance (1 vez a cada {icd} s)."},
		"weapon": {"kind": "legend_wake", "legend": "bleed", "wake": "copies", "n": "x", "text": "Sangue da Matilha Desperto: até {x} sangramentos seus no alvo."},
		"offhand": {"kind": "stat", "stats": {"crit": "x"}, "text": "+{x}% de crítico."},
	},
	"xama": {
		"head": {"kind": "stat", "stats": {"mana_guard": "x"}, "text": "Barreira de Mana: +{x}% do dano recebido sai da mana."},
		"body": {"kind": "stat", "stats": {"summon_time_pct": "x"}, "text": "Invocações com tempo duram +{x}%."},
		"legs": {"kind": "stat", "stats": {"buff_pct": "x"}, "text": "Bênçãos e escudos duram +{x}%."},
		"gloves": {"kind": "charges", "skill": "dru_moonfire", "text": "Fogo Lunar em Cargas."},
		"boots": {"kind": "zone_on_cast", "skill": "dru_starfall", "zone": {"foe_power": "x", "duration": "y"}, "text": "Chuva Estelar deixa chão lunar que fere os inimigos por {y} s."},
		"weapon": {"kind": "legend_wake", "legend": "cast_on_basic", "wake": "jump", "pct": "x", "text": "Lua Cheia Desperta: o Fogo Lunar de graça salta para 1 inimigo perto com {x}%."},
	},
	"cacador": {
		"head": {"kind": "legend_up", "legend": "mark", "adds": {"pct": "x"}, "text": "Marca do Caçador: +{x} pontos de dano recebido."},
		"body": {"kind": "stat", "stats": {"summon_guard": "x"}, "text": "Escudo de Carne: {x}% do seu dano vai para o lince."},
		"legs": {"kind": "stat", "stats": {"hit_slow": "x"}, "text": "Golpe físico retarda o alvo {x}%."},
		"gloves": {"kind": "charges", "skill": "ran_frost_arrow", "text": "Flecha Gélida em Cargas."},
		"boots": {"kind": "on_trigger", "on": "cast:ran_disengage", "do": [{"do": "cast", "skill": "ran_sic", "power": "x", "at": "foe"}], "text": "Recuar manda o lince dar o Ataque da Fera com {x}% de poder (1 vez a cada {icd} s)."},
		"weapon": {"kind": "legend_wake", "legend": "mark", "wake": "pet", "pct": "x", "text": "Marca Desperta: o lince bate +{x}% no alvo marcado."},
	},
	"atirador": {
		"head": {"kind": "cap_up", "caps": {"turret_time": "x"}, "text": "Torreta dura +{x} s."},
		"body": {"kind": "stat", "stats": {"trap_max": "x"}, "text": "+{x} armadilha no limite."},
		"legs": {"kind": "stat", "stats": {"crit_dmg_pct": "x"}, "text": "+{x}% de dano crítico."},
		"gloves": {"kind": "charges", "skill": "ran_snipe", "text": "Tiro Certeiro em Cargas."},
		"boots": {"kind": "on_trigger", "on": "trap", "do": [{"do": "cd_cut", "skill": "ran_disengage", "s": "x"}], "text": "Armadilha que dispara tira {x} s da recarga de Recuar."},
		"weapon": {"kind": "legend_wake", "legend": "splash", "wake": "chill", "adds": {"radius": "x"}, "text": "Pólvora Desperta: raio +{x} m; em alvo retardado ou preso a explosão é crítica."},
	},
	"lanceiro": {
		"head": {"kind": "legend_up", "legend": "open_wound", "adds": {"max": "x"}, "text": "Ferida Aberta: +{x} no máximo."},
		"body": {"kind": "stat", "stats": {"lifesteal": "x"}, "text": "+{x}% de roubo de vida."},
		"legs": {"kind": "stat", "stats": {"cc_resist_pct": "x"}, "text": "-{x}% de duração de controle em você."},
		"gloves": {"kind": "charges", "skill": "ran_javelin", "text": "Dardo de Caça em Cargas."},
		"boots": {"kind": "on_trigger", "on": "hit:ran_spear_leap", "do": [{"do": "wound_renew"}], "text": "Salto do Predador renova as Feridas Abertas no alvo."},
		"weapon": {"kind": "legend_wake", "legend": "open_wound", "wake": "jump", "pct": "x", "text": "Ferida Aberta Desperta: com as feridas cheias, o sangramento salta para 1 inimigo a 4 m com {x}%."},
	},
	"laminas": {
		"head": {"kind": "legend_up", "legend": "poison", "adds": {"chance": "x"}, "text": "Veneno Letal: +{x}% de chance."},
		"body": {"kind": "stat", "stats": {"backstab": "x"}, "text": "+{x}% de dano pelas costas."},
		"legs": {"kind": "stat", "stats": {"evasion": "x"}, "text": "+{x}% de esquiva."},
		"gloves": {"kind": "charges", "skill": "ass_venom_dart", "text": "Dardo Venenoso em Cargas."},
		"boots": {"kind": "on_trigger", "on": "cast:ass_vanish", "do": [{"do": "mp", "pct": "x"}, {"do": "cd_reset", "skill": "ass_venom_dart"}], "text": "Sumir devolve {x}% de MP e zera o Dardo Venenoso."},
		"weapon": {"kind": "legend_wake", "legend": "poison", "wake": "evis_mp", "pct": "x", "text": "Veneno Letal Desperto: Eviscerar devolve {x}% de MP por veneno consumido."},
		"offhand": {"kind": "stat", "stats": {"hit_poison": "x"}, "text": "Golpe físico envenena ({x} de dano por segundo)."},
	},
	"duelista": {
		"head": {"kind": "cap_up", "caps": {"momentum": "x"}, "text": "Ímpeto: +{x} carga no máximo."},
		"body": {"kind": "stat", "stats": {"guard_crit": "x"}, "text": "+{x}% de crítico depois de bloquear."},
		"legs": {"kind": "skill_mods", "skill": "ass_guard", "mod": {"add": {"buff": {"duration": "x"}}}, "text": "Guarda do Duelista: janela de aparar +{x} s."},
		"gloves": {"kind": "charges", "skill": "ass_lunge", "text": "Avanço do Duelista em Cargas."},
		"boots": {"kind": "on_trigger", "on": "parry", "do": [{"do": "cd_cut", "skill": "ass_lunge", "s": "x"}], "text": "Aparar tira {x} s da recarga do Avanço."},
		"weapon": {"kind": "legend_wake", "legend": "riposte", "wake": "pct", "adds": {"pct": "x"}, "text": "Riposte Desperta: +{x}% no contra-ataque."},
		"offhand": {"kind": "cap_up", "caps": {"riposte_counters": "x"}, "text": "+{x} contra-ataque por janela de aparar."},
	},
	"corsario": {
		"head": {"kind": "cap_up", "caps": {"bravado": "x"}, "text": "Bravata: +{x} carga no máximo."},
		"body": {"kind": "stat", "stats": {"crit_leech": "x"}, "text": "Sangue no Fio: {x}% do dano crítico volta como vida."},
		"legs": {"kind": "stat", "stats": {"def_pct": "x"}, "text": "+{x}% de DEF."},
		"gloves": {"kind": "charges", "skill": "ass_pistol_shot", "text": "Tiro de Pistola em Cargas."},
		"boots": {"kind": "skill_mods", "skill": "ass_grapple", "mod": {"add": {"combo_gain": "x"}}, "text": "Gancho de Abordagem dá +{x} Bravata."},
		"weapon": {"kind": "legend_wake", "legend": "spare_shot", "wake": "quick", "adds": {"chance": "x"}, "icd_cut": "y", "text": "Bala na Agulha Desperta: +{x}% de chance e recarga -{y} s."},
		"offhand": {"kind": "on_trigger", "on": "hit:ass_between_eyes", "do": [{"do": "ricochet", "pct": "x"}], "text": "Tiro Entre os Olhos ricocheteia em 1 inimigo perto com {x}%."},
	},
	"fogo": {
		"head": {"kind": "stat", "stats": {"mana_guard": "x"}, "caps": {"mana_guard": "y"}, "text": "Barreira de Porcelana: +{x}% do dano sai da mana e o teto da Barreira sobe {y}."},
		"body": {"kind": "stat", "stats": {"mp_to_hp": "x"}, "text": "Mana em Carne: +{x}% do MP vira vida máxima."},
		"legs": {"kind": "dot_up", "dot": "fire", "time": "x", "text": "Queimaduras duram +{x}%."},
		"gloves": {"kind": "charges", "skill": "ele_fireball", "text": "Bola de Fogo em Cargas."},
		"boots": {"kind": "skill_mods", "skill": "ele_ember_seed", "mod": {"add": {"seed": {"max_targets": "x"}}}, "text": "Semente Ígnea espalha para +{x} alvo."},
		"weapon": {"kind": "legend_wake", "legend": "cast_on_basic", "wake": "burn_mp", "pct": "x", "text": "Brasa Viva Desperta: a Bola de Fogo de graça em alvo queimando devolve {x}% de MP."},
	},
	"gelo": {
		"head": {"kind": "mana_guard_eff", "stats": {"mana_guard_eff": "x"}, "text": "Barreira de Vidro: 1 MP da Barreira de Mana absorve 1 + {x} de dano."},
		"body": {"kind": "stat", "stats": {"low_dr": "x"}, "text": "Firme na Queda +{x}%."},
		"legs": {"kind": "cap_up", "caps": {"shatter": "x"}, "text": "Estilhaçar: +{x}% de dano em alvo retardado."},
		"gloves": {"kind": "charges", "skill": "ele_ice_lance", "text": "Lança de Gelo em Cargas."},
		"boots": {"kind": "on_trigger", "on": "cast:ele_blink", "do": [{"do": "cast", "skill": "ele_frost_nova", "power": "x", "at": "self"}], "text": "Piscar deixa uma Nova de Gelo com {x}% de poder."},
		"weapon": {"kind": "legend_wake", "legend": "cast_when_hit", "wake": "power", "adds": {"icd": "-x"}, "pct": "y", "text": "Coração de Gelo Desperto: recarga -{x} s e a Nova bate +{y}%."},
	},
	"raio": {
		"head": {"kind": "stat", "stats": {"mana_guard": "x", "mp_regen_combat": "y"}, "text": "Barreira de Mana +{x}% e +{y}% de mana por segundo em combate."},
		"body": {"kind": "skill_mods", "skill": "ele_overload", "mod": {"add": {"buff": {"duration": "x"}}}, "text": "Sobrecarga dura +{x} s."},
		"legs": {"kind": "stat", "stats": {"cdr": "x"}, "text": "-{x}% de recarga."},
		"gloves": {"kind": "charges", "skill": "ele_chain", "text": "Corrente Elétrica em Cargas."},
		"boots": {"kind": "on_trigger", "on": "hit:ele_bolt_step", "do": [{"do": "cd_cut", "skill": "ele_chain", "s": "x"}], "text": "Passo Relampejante que acerta tira {x} s da Corrente Elétrica."},
		"weapon": {"kind": "legend_wake", "legend": "chain", "wake": "arc", "adds": {"targets": "x"}, "text": "Arco Voltaico Desperto: +{x} alvo."},
	},
	"invocador": {
		"head": {"kind": "stat", "stats": {"summon_frenzy": "x"}, "text": "Fúria dos Mortos: invocações feridas batem +{x}%."},
		"body": {"kind": "stat", "stats": {"summon_guard": "x"}, "text": "Escudo de Carne: {x}% do seu dano vai para a invocação mais perto."},
		"legs": {"kind": "stat", "stats": {"summon_time_pct": "x"}, "text": "Invocações com tempo duram +{x}%."},
		"gloves": {"kind": "charges", "skill": "nec_bone_spear", "text": "Lança de Osso em Cargas."},
		"boots": {"kind": "on_trigger", "on": "cast:nec_dark_offering", "do": [{"do": "raise", "time": "x"}], "text": "Oferenda Sombria ergue 1 esqueleto da Legião por {x} s."},
		"weapon": {"kind": "legend_wake", "legend": "raise_on_kill", "wake": "pet", "adds": {"icd": "-x"}, "pct": "y", "text": "Legião Desperta: recarga -{x} s; o esqueleto erguido bate +{y}%."},
	},
	"ceifador": {
		"head": {"kind": "stat", "stats": {"leech_shield": "x"}, "text": "Roubo de vida que passa do máximo vira barreira (até {x}% da vida)."},
		"body": {"kind": "stat", "stats": {"low_dr": "x"}, "text": "Firme na Queda +{x}%."},
		"legs": {"kind": "stat", "stats": {"low_leech": "x"}, "text": "Sede na Beira: +{x}% de roubo de vida com pouca vida."},
		"gloves": {"kind": "charges", "skill": "nec_soul_rend", "text": "Rasgar Alma em Cargas."},
		"boots": {"kind": "on_trigger", "on": "hit:nec_death_spin", "max_hits": "n", "do": [{"do": "heal", "pct": "x"}], "text": "Giro da Morte cura {x}% da vida por inimigo atingido (até {n} inimigos)."},
		"weapon": {"kind": "legend_wake", "legend": "heal_on_kill", "wake": "ally", "pct": "x", "text": "Ceifa Desperta: o abate cura também o aliado mais ferido em {x}% da vida dele."},
	},
	"pestilento": {
		"head": {"kind": "stat", "stats": {"mana_guard": "x"}, "text": "Barreira de Mana: +{x}% do dano recebido sai da mana."},
		"body": {"kind": "skill_mods", "skill": "nec_pandemic", "mod": {"add": {"dot": {"duration": "x"}}}, "text": "Pandemia dura +{x} s."},
		"legs": {"kind": "stat", "stats": {"mp_to_hp": "x"}, "text": "Mana em Carne: +{x}% do MP vira vida máxima."},
		"gloves": {"kind": "charges", "skill": "nec_curse_agony", "text": "Agonia em Cargas."},
		"boots": {"kind": "dot_up", "dot": "curse", "time": "x", "text": "Maldições duram +{x}%."},
		"weapon": {"kind": "legend_wake", "legend": "cast_on_basic", "wake": "spread", "text": "Praga Desperta: alvo com a Agonia da arma que morre passa a Agonia a 1 inimigo a 4 m."},
	},
}
const LEG50_KINDS := ["stat", "charges", "legend_up", "legend_wake", "cap_up", "skill_mods", "form_up", "dot_up", "zone_on_cast", "on_trigger", "mana_guard_eff"]

## Troca "x"/"y"/"icd"/"-x" pelos números de `nums` em toda a árvore (dicionários e listas). Texto fica de fora.
static func leg50_resolve(v: Variant, nums: Dictionary) -> Variant:
	if v is Dictionary:
		var out := {}
		for k in v:
			if k != "text":
				out[k] = leg50_resolve(v[k], nums)
		return out
	if v is Array:
		var arr: Array = []
		for x in v:
			arr.append(leg50_resolve(x, nums))
		return arr
	if v is String and v in ["x", "y", "icd", "n", "-x", "-y"]:
		var key: String = (v as String).trim_prefix("-")
		return -float(nums.get(key, 0.0)) if (v as String).begins_with("-") else float(nums.get(key, 0.0))
	return v

## Efeito pronto da peça `piece` da build `bid` no 50 ({} se não há). Ex.: leg50_fx("fogo", "gloves") -> {"kind": "charges", "skill": "ele_fireball", ...}.
static func leg50_fx(bid: String, piece: String) -> Dictionary:
	var tpl: Dictionary = LEG50.get(bid, {}).get(piece, {})
	if tpl.is_empty():
		return {}
	var nums: Dictionary = Balance.LEG50_NUMBERS.get(bid, {}).get(piece, {})
	var out: Dictionary = leg50_resolve(tpl, nums)
	out["piece"] = piece
	out["build"] = bid
	if not out.has("icd"):
		out["icd"] = float(nums.get("icd", Balance.LEG50_TRIGGER_ICD))
	out["text"] = leg50_text(str(tpl.get("text", "")), nums)
	return out

## Texto da dica com os números ({x}, {y}, {icd}; inteiro sem casas).
static func leg50_text(text: String, nums: Dictionary) -> String:
	var icd := float(nums.get("icd", Balance.LEG50_TRIGGER_ICD))
	for k in ["x", "y", "n"]:
		text = text.replace("{%s}" % k, _num_txt(absf(float(nums.get(k, 0.0)))))
	return text.replace("{icd}", _num_txt(icd))

static func _num_txt(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else ("%.2f" % v).rstrip("0").replace(".", ",")

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
	items.append_array(lumeria_jewels())
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
				apply_weapon_role(wpn, build, tier, lv, mult)          # espada ataca / maça defende (WEAPON_ROLES)
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
					apply_weapon_role(alt, build, tier, lv, mult)          # maça/martelo do Paladino: defesa (Baluarte), não cópia da espada
					made.append(alt)
					alts[alt.id] = true
				if build["off"].size() > 0:
					var off_t: String = build["off"][0]
					var off_name: String = WEAPON_NAMES[off_t] + ("" if off_t in ItemDef.OFFHAND_ONLY else " Gêmea")
					var off := weapon_item("leg_%s_%s_%d_offhand" % [cid, bid, lv], "%s %s" % [off_name, tail], off_t, lv, ItemDef.RARITY_LEGENDARY, mult, col, PIECE_WEIGHT["offhand"])
					off.attributes = _attrs(build["attr"], build["attr2"], lv, PIECE_WEIGHT["offhand"], mult)     # serve à build (escudo do Sacerdote dá WILL, não FOR)
					apply_shield_role(off, build, tier)          # Guardião/Templário/Batalha: Determinação
					made.append(off)
				if vis.has("set_name"):
					sd.name = vis["set_name"]
				for it in made:
					if not vis.is_empty():
						var piece: String = it.id.get_slice("_", it.id.get_slice_count("_") - 1)
						if vis.has("reuse") and not vis.has("suffix"):          # visual reaproveitado sem nome próprio: nome genérico da regra
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
						if alts.has(it.id) and (not vis.has("reuse") or vis.has("suffix")):         # maça do conjunto: mesmo nome da espada, trocando a arma
							if vis.has("names"):
								it.name = (vis["names"].get("weapon", it.name) as String).replace("Espada", WEAPON_NAMES[it.weapon_type])
							else:
								it.name = noun_with(vis, WEAPON_NAMES[it.weapon_type])
						it.icon_color = vis["color"]
						it.icon = "%s_%s" % [vis["icon"], piece] if vis.has("icon") and piece != "legs" else ""     # calça: arte pintada
						if it.armor_style != "" and piece != "legs":     # calça: a do estilo da build (o kit tem), na cor do conjunto
							it.armor_style = vis["style"]
						elif it.slot == S.WEAPON:
							it.weapon_style = vis.get("wpn", vis["style"])          # arma própria do conjunto (paladin_sets / berserker_sets); vale na mão secundária
						elif it.weapon_type == "shield":
							it.shield_style = vis.get("shield", vis["style"])
						elif it.weapon_type == "pistol":
							it.weapon_style = vis.get("wpn", vis["style"])          # pistola própria do conjunto (assassin_sets.ASS_WEAPONS, wpn_off_pistol_<estilo>)          # escudo próprio do conjunto (paladin_sets.SET_SHIELDS)
					it.set_id = sd.id
					it.class_restriction = restrict
					var hands := "Duas mãos. " if it.is_two_handed() else ""
					if it.slot == S.WEAPON and it.id.ends_with("_offhand"):
						hands = "Mão secundária (Shift+clique na bolsa). "
					it.description = "%sPeça do %s (%s)." % [hands, sd.name, cls.name]
					if it.slot in [S.WEAPON, S.OFFHAND]:
						it.description = "%sArma do %s (%s): não conta nas peças; %s" % [hands, sd.name, cls.name, "tem efeito lendário próprio." if not it.legend_effect.is_empty() else "acompanha o conjunto."] + role_note(it, bid)
					elif not sd.armor.has(it.id):
						sd.armor.append(it.id)
					if lv == Balance.LEG50_LEVEL:          # Lendário do 50: efeito próprio da peça (GDD ato3-lendarios-50)
						var pk: String = "weapon2" if alts.has(it.id) else it.id.get_slice("_", it.id.get_slice_count("_") - 1)
						it.piece_fx = leg50_fx(bid, pk)
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
	var hyb := hybrid_sets(classes, skills)          # 3) conjuntos híbridos 35/40/45 (R7.1; os que ficaram)
	items.append_array(hyb["items"])
	sets.append_array(hyb["sets"])
	var apx := apex_sets(classes, skills)           # 4) conjuntos Ápice 35/40/45 (apice-sets.md)
	items.append_array(apx["items"])
	sets.append_array(apx["sets"])
	items.append_array(legendary_accessories(classes))          # 5) acessórios lendários 35/40/45 (fora de conjunto)
	return {"items": items, "sets": sets}
