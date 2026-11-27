class_name BotsCatalog
extends RefCounted
## Nomes e falas dos bots ("jogadores" simulados).

const NAMES := [
	"Kael", "Mirah", "Dorn", "Lysa", "Thorne", "Ysolde", "Brakk", "Nessa", "Varun", "Ilse",
	"Rook", "Tamsin", "Oberon", "Fjola", "Gideon", "Wren", "Sable", "Petra", "Lucan", "Ivy",
	"xXDarkSlayerXx", "potato_mage", "healz4u", "NotABot", "Zé do Machado", "Luna_br", "Cavaleiro77",
	"Mago Preguiçoso", "Fran", "Biel", "Nyx", "Odara", "Caio_hunter", "Tulio", "Mel", "Rafa_sin",
]

const LINES := {
	"town": [
		"alguém vende poção de mana?", "oi gente", "quem quer fazer party pra campina?", "afk 5 min",
		"onde fica o ferreiro?", "finalmente lv 10 kkk", "esse jogo é melhor que o outro", "alguém viu o rei javali hoje?",
		"vendo pele de lobo barato", "compro minério de ferro", "bom dia pessoal", "voltei", "gg", "ta chovendo aí?",
		"preciso de 3 seda de aranha, alguém?", "o ancião tem quest nova", "lag?", "alguém quer duo?", "brb",
		"como upa o rank da skill?", "resp: mestre de skills na praça, ouro + material da caçada", "skill nova vem sozinha no nível, só treinar", "o elixir da força é muito bom",
	],
	"hunt": [
		"esse lobo é rápido demais", "ajuda aqui!!", "quase morri kkkk", "dropou o anel!!!", "cadê os javalis",
		"alguém pra matar o chefe?", "ks :(", "vou voltar pra cidade, bolsa cheia", "+1 lvl", "esse boss bate forte",
		"não aggra o rei javali agora pfv", "lootei 4 minério", "bloqueia quando ele avançar", "pull de 5 slime ez",
	],
	# caçando num mapa específico (BotBrain: "hunt_<mapa>" ou "town_<mapa>" quando existe, senão o genérico)
	"hunt_field_crab_beach": ["caranguejo de monte, nem dá tempo de respirar", "o eremita fecha na concha, espera abrir e bate", "o da areia pula longe, cuidado",
		"dropou casco! o Joca compra", "alguém pro Caranguejo-Rei? ponta sul", "farm de praia, melhor coisa", "pisei numa poça e saiu um eremita kkk"],
	"hunt_field_hollow": ["vespa vem em bando, puxa devagar", "alguém viu a Colmeia? quero acabar com ela", "urso pardo bate forte na frente, sai pelo lado",
		"filhote aqui, cuidado com a mãe", "ninguém sobe na toca da Ursa-Mãe sozinho", "dropou favo de mel!", "essa mata zumbe até de noite"],
	"hunt_field_grove": ["xamã girando folha, bate antes de virar", "o lobo some no mato, guarda alta", "gavião foge, deixa ele pro arqueiro", "mata o Chamador primeiro, os bichos somem",
		"alguém pro Arquidruida? sozinho não dá", "chão roxo é raiz, sai de cima", "dropou pena espiritual!"],
	"hunt_field_forest": ["paliçada dos bandidos tá lotada hoje", "cuidado com os clandestinos, o laço prende o pé", "trombadinha atira pedra e corre", "gatuno bate forte, mata ele primeiro", "alguém viu o Chefe dos Bandidos?",
		"essas aranhas grudam a gente no chão", "ent bate devagar mas bate", "cadê a trompa? quero xp de elfo", "o pântano sul tá cheio de aranha"],
	"town_field_forest": ["portão norte segura mais uma?", "o Gunnar aprimora com aço élfico", "alguém pra Cidade Élfica?", "a Comandante Hela tá de mau humor",
		"compro aço élfico", "o ensopado da Bia é bom demais", "quem segurou a última investida?"],
	"hunt_dg_pedreira": ["golem de cristal atira de longe, chega perto", "núcleo de pedra pro Tadeu", "o Ancestral joga pedra, sai da sombra no chão",
		"a Guardiã prende no cristal, dash!", "alguém pro Coração da Pedreira?", "golem é lento, kita ele"],
	"hunt_dg_ninho": ["teia em todo canto aqui", "a Rainha pula, sai da frente!!", "poça verde = sai dela", "filhote de aranha por todo lado",
		"alguém tem antídoto?", "não pisa no veneno kkk"],
	"hunt_elf_city": ["arqueiro élfico prende o pé, dash pro lado", "os guardiões batem MUITO", "grifo no céu, corre", "trent devagar mas o cipó puxa",
		"essa cidade é linda pra quem não tá apanhando", "pena de grifo vale bem", "esses elfos nunca dormem?", "a Sylvara corre mais que eu de cavalo", "sargento com três guerreiros, puxa um de cada vez", "a Ilwen cura os trents, mata os espíritos antes"],
	"hunt_dg_coracao": ["o Rei chama a guarda com 70%", "chuva de flechas: espalha!", "sai de perto quando ele brilhar verde", "segura os grifos, tank!",
		"seiva da árvore pra glória +6", "quase pegamos o rei"],
	"hunt_dg_catacumbas": ["o capitão levanta os mortos", "a viúva grita em cone, sai da frente", "carniçal corre rápido demais", "pó de cova pro Bento"],
	"hunt_dg_catacumbas_trono": ["o Conde drena vida, não fica parado na frente", "marca de sangue: alguém cura?", "morcegos!! sai da nuvem",
		"no fim ele perde a compostura, segura"],
	"death": ["morri", "F", "respawn...", "esse golem não é brincadeira", "ok vou tankar menos"],
	"levelup": ["LV %d!!", "upei pro %d", "lv %d finalmente", "%d, bora pro próximo"],
	# {pra} = "pro Vale de Aldara"/"pras Estepes de Cinza", {em} = "no Vale"/"nas Grutas" (place_words)
	"leaving": ["indo {pra}, alguém vem?", "partiu {nome}", "vou caçar {em}"],
}

## 1ª palavra de lugar masculino (o resto é feminino; terminada em "s" é plural): "no Vale", "na Floresta", "nas Estepes".
const MASC_PLACE_WORDS := ["Vale", "Bastião", "Porto", "Arraial", "Covil", "Ninho", "Coração", "Trono", "Armazém", "Posto",
	"Acampamento", "Santuário", "Farol", "Passo", "Forte", "Templo", "Pântano", "Mangue", "Monte", "Salão"]

## Artigo do nome de um lugar: "o", "a", "os" ou "as".
static func place_article(place: String) -> String:
	var first := place.get_slice(" ", 0)
	var art := "o" if first in MASC_PLACE_WORDS else "a"
	return art + "s" if first.ends_with("s") else art

## Marcas de lugar para as falas de viagem: {nome}, {pra} ("pro Vale de Aldara") e {em} ("no Vale de Aldara").
static func place_words(place: String) -> Dictionary:
	var art := place_article(place)
	return {"nome": place, "pra": "pr%s %s" % [art, place], "em": "n%s %s" % [art, place]}

# ---------------------------------------------------------------------------
# CONVERSA POR CONTEXTO (BotChat): onde o bot está, classe/build e se está no grupo do jogador.
# Marcas nas falas: {p} jogador · {pcls} classe do jogador · {map} mapa · {lv} nível · {boss} chefe · {item} item · {me} o bot.
# `pools()` monta tudo (laços de modelos × peças) num dicionário "<tipo>:<chave>" -> Array[String] (GameData.bot_chat).

## Mapa -> tipo de lugar; quem não está aqui cai em interior/dungeon/aldara/field pelos dados (BotChat.place_kind).
## Tipos com "_town" usam a variante dentro da muralha do povoado (town_radius).
const MAP_KIND := {
	"city_aldara": "aldara", "field_hollow": "hollow", "field_crab_beach": "beach", "field_grove": "grove", "field_forest": "forest", "elf_city": "elf_city", "field_ruins": "dawn",
	"fort_ghoul": "fort", "fort_bones": "fort", "fort_frost": "fort", "lich_citadel": "citadel",
	"field_kharzun": "kharzun", "dg_slayers": "slayers", "kharzun_citadel": "kharzun_citadel",
	"city_lumeria": "lumeria",
}
const WALLED := ["aldara", "forest", "dawn", "kharzun", "lumeria"]     # tipos com vila/povoado murado (variante <tipo>_town)

## Depois que o Lich cai (MapsCatalog.VICTORY_QUEST feita): a cidade e o Bastião comemoram no chat.
const VICTORY_LINES := ["O LICH CAIU!!! festa na praça", "{p} matou o Azhar, alguém viu?? lendário", "GG {p}, a noite acabou de vez",
	"cerveja de graça na taverna, é o que dizem", "olha os fogos em cima da balança", "três dias de festa, nem vou caçar hoje",
	"alguém tira print dos fogos", "o bardo já fez música pro {p}", "valeu {p}, Aldara te deve uma", "a Aurora venceu \\o/",
	"saudade do medo que dava a Cidadela kkk", "e agora? farmar lendário até o próximo ato"]

## Depois que Durgash cai (MapsCatalog.Q_KH_WARLORD, fim do Ato II): o acampamento e o porto comemoram no chat.
const KHARZUN_VICTORY_LINES := ["DURGASH CAIU!!! a montanha é nossa", "{p} derrubou o Senhor da Guerra, alguém viu??", "GG {p}, fim do Ato II",
	"orc desarmado carregando caixa, nunca pensei que ia ver isso", "festa no acampamento e no porto, bora", "olha os fogos em cima do braseiro",
	"a Horda se rendeu, mas a Shagra disse que tem fogo a leste...", "valeu {p}, a Aurora chegou no pico", "três clãs e um Senhor da Guerra, que campanha",
	"agora é farmar lendário 45 em paz kkk"]
const KHARZUN_VICTORY_KINDS := ["kharzun_town", "kharzun", "slayers"]     # e o Porto (city_port), pelo id do mapa

const PLACE_LINES := {
	"grove": ["esse bosque tem tambor de noite", "o posto da Guardiã é logo na entrada", "xamã virou urso na minha frente!", "cheiro de resina por toda parte"],
	"beach": ["que praia bonita, pena as pinças", "o rancho do Joca é logo na chegada", "olha o casco encalhado no meio da baía", "areia até no elmo"],
	"hollow": ["que mata fechada", "fica na trilha senão o urso te acha", "o acampamento da Brena é logo ali", "cheiro de mel por toda parte"],
	"aldara_town": ["a balança da praça é o melhor ponto de afk", "a taverna do Gus tá lotada hoje", "a Relicária troca moeda lendária, só lembrando",
		"alguém pra Gruta Gotejante?", "o Brom aprimora até +9 e nunca quebra, confia", "quem vende bolsa ampliada?", "vou passar no ferreiro e já volto",
		"o Ancião Ravi fala demais mas a quest paga bem", "vendo couro, preço de amigo", "a Capitã Mira já liberou o desfiladeiro pra alguém?",
		"Aldara de manhã é outra coisa", "alguém sabe se a botica tem poção grande?", "quem vai pras Catacumbas hoje?"],
	"aldara_field": ["a campina tá cheia de slime hoje", "javali corre torto, espera ele parar e bate", "erva da beira do rio vale a pena colher (F)",
		"cuidado que lobo nunca anda sozinho", "atravessa pela ponte, nadar não dá kkk", "a boca da Gruta é logo ali, quem vem?",
		"campina é tranquila até aparecer o Rei Javali", "matei tanto slime que já sonho com gosma", "alguém viu um baú dourado por aqui?"],
	"forest_town": ["o cristal do Posto salva vida, vincula com G", "a muralha do Posto aguenta mais uma investida?", "Posto cheio hoje, bom sinal",
		"descansando no Posto antes da próxima", "quem tá indo pra Pedreira?", "alguém pro Ninho Profundo? só com grupo"],
	"forest": ["essa floresta é escura até de dia", "não sai da estrada que as aranhas te acham", "a Pedreira dos Golens é por ali, né?",
		"o Ninho Profundo é pra grupo, nem tenta solo", "ouvi uma trompa, investida vindo?", "cada árvore dessas parece um ent dormindo"],
	"elf_city": ["essa cidade é linda e tudo nela quer me matar", "o Coração da Árvore é o próximo passo", "elfo não erra flecha, impressionante",
		"tô me escondendo atrás dessa raiz faz 5 minutos", "alguém tem mapa dessa cidade? me perdi"],
	"dawn_town": ["o Bastião regenera, descansa aqui dentro", "o Marechal Aldric gritou comigo de novo", "sentinela do muro salva a pátria",
		"alguém pra surtida?", "o portão segurou de novo, gg", "a luz do Bastião aparece de longe, ainda bem"],
	"dawn": ["morto-vivo pra todo lado aqui fora", "quem tá ajudando o Marechal Aldric?", "o Covil do Carniçal já caiu? alguém sabe?",
		"ruína velha, cheiro de osso", "a Cripta de Vel'Thar só com grupo bom", "a escuridão daqui gruda na armadura"],
	"fort": ["{map} fede a osso", "retomar fortaleza é coisa de grupo", "a guarnição vem em bando, cuidado", "cada fortaleza que cai, a Aurora sobe mais um degrau",
		"não puxa o pátio inteiro de uma vez pfv"],
	"citadel": ["Cidadela do Lich... chegamos longe", "o Lich congela, guarda o dash", "se eu cair aqui eu desinstalo kkk", "fim da linha, bora",
		"até o ar aqui dentro é frio"],
	"dungeon": ["{map} de novo kkk", "sem mapa aqui dentro eu me perco", "alguém lembra pra que lado é o chefe?", "não puxa dois grupos de uma vez",
		"poção na barra, gente", "eco aqui dentro dá medo", "quem apagou a tocha?"],
	"interior": ["lugar aconchegante esse", "entrei só pra fugir da chuva", "o dono nem cobra pra ficar aqui kkk", "afk aqui dentro, ninguém me acha",
		"cheiro de pão nessa casa"],
	"field": ["xp boa nesse mapa", "alguém de grupo por aqui?", "bolsa quase cheia", "esse mapa é maior do que parece"],
	"boss": ["{boss} tá de pé, quem vem?", "não puxa sem tank, {boss} bate muito", "olha {boss} ali, cuidado", "guarda poção, {boss} não perdoa",
		"alguém já decorou o padrão de {boss}?"],
	# Monte Kharzun (40-45)
	"kharzun_town": ["o braseiro da praça esquenta mais que poção", "vincula o cristal do acampamento com G, a descida é longa", "o Thrain aprimora lendário 40, corre lá",
		"alguém pras Minas? sozinho não dá", "a carroça das Estepes chegou, poção barata", "o sargento tá treinando recruta de novo kkk",
		"quem tem antídoto? veneno de goblin é chato", "contra-ataque vem pelo portão leste ou norte, fica esperto", "a Comandante Isolda não dorme, juro",
		"bora fechar grupo pro Salão dos Matadores?"],
	"kharzun": ["essa lava não perdoa, só passa pela ponte", "lobo atroz em matilha de três, puxa um de cada vez", "viu fumaça? protege o healer",
		"salamandra não queima, nem tenta fogo nela", "golem de basalto é lento, kita ele", "o Canil uiva a noite toda", "Forja Negra do outro lado da lava, quem vem?",
		"pedregulho do troll vem no mais longe, cuidado atirador", "cinza até na bota", "Senhor da Guerra grita e a matilha fica forte, mata ele primeiro"],
	"slayers": ["Salão dos Matadores... fica junto do healer", "assassino aparece pelas costas de quem cura", "fumaça = vira e bate", "boneco de treino aqui dentro tem sangue",
		"não corre na frente, tem Matador escondido"],
	"kharzun_citadel": ["a Cidadela de Durgash, chegamos", "três clãs e depois o trono", "estandarte no chão? quebra primeiro", "se cair aqui eu choro kkk",
		"guarda de clã bloqueia de frente, vai pelo lado"],
	# Lumeria (Ato III, WP12): "lumeria_town" = dentro do Bairro dos Lúcidos; "lumeria" = a festa lá fora
	"lumeria_town": ["Bairro dos Lúcidos, enfim um lugar quieto", "o sino abafado da praça é o único que não toca", "alguém viu a Irmã Clara dormir alguma vez?",
		"não aceita taça de ninguém lá fora, sério", "a barricada é de armário, mas segura", "vincula o cristal antes de sair pra festa",
		"alguém pra Ópera? Galeria dos Espelhos só com grupo", "a Leonor treina skill aqui atrás das barricadas"],
	"lumeria": ["essa música não para nunca", "folião de máscara joga taça, cuidado", "não olha muito pras lanternas", "confete até dentro da bota",
		"o Mestre de Cerimônias tem sineta, mata ele primeiro", "galgo de seda tem guizo, dá pra ouvir chegando", "o campanário desafinou de novo",
		"tô dançando sem querer, alguém me tira daqui kkk", "corista grita e o chão marca, sai do anel"],
	"raid": ["INVESTIDA! todo mundo pro portão", "eles tão vindo, segura a muralha", "defende o portão, não persegue longe", "mais uma leva, aguenta!",
		"quem tem área, solta agora", "a sentinela não segura sozinha, ajuda aí"],
}

## Voz de cada classe: falas escritas + peças que os modelos combinam (want = infinitivo, doing = o que anda fazendo).
const CLASS_VOICE := {
	"paladin": {"want": ["segurar a linha", "tankar um chefe", "proteger alguém que precise", "bater de escudo em alguma coisa"],
		"doing": ["bloqueando pancada", "rezando pra Luz", "polindo a armadura", "segurando aggro"],
		"lines": ["a Luz me guia, a poção me sustenta", "escudo pra cima, gente", "tank livre, alguém?", "levei uma pancada que até a armadura sentiu",
			"placa é pesada mas é estilosa", "juramento cumprido, próxima quest"]},
	"berserker": {"want": ["bater em alguma coisa", "girar o machado", "ficar com pouca vida de propósito", "quebrar algo bem grande"],
		"doing": ["rachando monstro", "girando machado", "roubando vida de lobo", "gritando com slime"],
		"lines": ["menos conversa, mais machado", "vida baixa = dano alto, confia", "ARGH", "alguém lembra de me mandar beber poção",
			"fúria não tem recarga", "bloquear? nunca nem vi"]},
	"bishop": {"want": ["curar alguém", "abençoar o grupo inteiro", "ver uma barra de vida cheia", "não morrer pra variar"],
		"doing": ["curando gente que não agradece", "rezando", "economizando mana", "abençoando à toa"],
		"lines": ["healer disponível, tratar no privado", "parem de pisar no fogo pfv", "bênção de graça hoje", "minha mana não é infinita, gente",
			"quem morre com healer do lado é porque quis", "a Luz é paciente. eu nem tanto"]},
	"druid": {"want": ["virar urso", "virar lobo e sair correndo", "conversar com uma árvore", "colher erva em paz"],
		"doing": ["virando bicho", "abraçando árvore", "colhendo erva", "rosnando pros javalis"],
		"lines": ["urso ou lobo hoje? decisões", "a floresta tá estranha hoje", "não, eu não mordo. às vezes", "tem pelo de lobo na minha armadura de novo",
			"as árvores falam, vocês que não escutam", "druida é a classe mais injustiçada"]},
	"ranger": {"want": ["acertar de longe", "achar um bom ponto de tiro", "montar umas armadilhas", "caçar com meu lince"],
		"doing": ["mirando", "contando flecha", "armando armadilha", "passeando com o lince"],
		"lines": ["não pisa na armadilha que é minha kkk", "o lince é mais forte que eu às vezes", "distância é vida", "na mosca!",
			"alguém viu meu lince?", "quem chega perto de mim já errou"]},
	"assassin": {"want": ["pegar alguém pelas costas", "sumir um pouco", "envenenar umas lâminas", "matar sem ser visto"],
		"doing": ["escondido nas sombras", "afiando adaga", "passando veneno na lâmina", "esquivando de tudo"],
		"lines": ["você não me viu aqui", "esquivei. não acertou. nunca acerta", "crítico pelas costas é outra coisa",
			"por que todo mundo olha pra mim quando some alguma coisa?", "duas lâminas, zero paciência", "furtivo, menos quando eu tropeço"]},
	"elementalist": {"want": ["botar fogo em alguma coisa", "congelar um grupo inteiro", "soltar um raio em cadeia", "testar um combo novo"],
		"doing": ["queimando slime", "congelando lobo", "carregando raio", "estudando combo"],
		"lines": ["fogo + gelo = estilhaço, aprendam", "cuidado que meu cajado tá meio instável", "não fico na frente, sou de vidro", "mana acabou de novo",
			"cheiro de queimado? fui eu", "elemental invocado, pode puxar"]},
	"necromancer": {"want": ["levantar uns mortos", "amaldiçoar alguém", "colher umas almas", "passear com meus esqueletos"],
		"doing": ["conversando com caveira", "afiando a foice", "amaldiçoando slime", "contando osso"],
		"lines": ["meus esqueletos não reclamam, diferente de certas pessoas", "é só uma foice, gente, relaxa", "não, eu não vou levantar seu pet morto",
			"cemitério é praticamente minha casa", "alguém tem pó de cova sobrando?", "a morte é só o começo do meu dano"]},
}
const CLASS_WANT := ["só quero {want} hoje", "alguém aí pra {want} comigo?", "bora {want}?", "dia bom pra {want}", "hoje eu vou {want}, nada me para"]
const CLASS_DOING := ["passei a tarde {doing} kkk", "{doing} desde cedo e ninguém agradece", "se me procurarem eu tô {doing}"]

## Toque de cada build (soma com a voz da classe).
const BUILD_LINES := {
	"guardiao": ["escudo de torre é amor", "guardião não morre, só fica cansado", "puxa tudo que eu seguro"],
	"cruzado": ["espada de duas mãos e fé", "cruzado é dps disfarçado de tank", "zelo no talo"],
	"punhos": ["esquivei, agora é minha vez", "quanto mais você erra, mais forte eu fico", "garra afiada, punho fechado", "chakra em dia, bora"],
	"corsario": ["sabre numa mão, pistola na outra", "bravata cheia, tiro entre os olhos", "rolei os dados e deu crítico, sorte de capitão", "gancho no mastro e lá vou eu", "a bala ricocheteia, a culpa não é minha"],
	"templario": ["escudo numa mão, martelo na outra", "marquei, agora o martelo cai", "templário é paladino que descobriu o martelo", "cinco marcas e bum"],
	"batalha": ["cada martelada cura alguém, confia", "clérigo de linha de frente, sem medo", "hino de batalha tocando", "quem tá ferido? vou bater em algo"],
	"lanceiro": ["lança na mão, presa na mira", "arco é pra quem tem medo de chegar perto", "marquei, agora sangra", "salto, estoco e já tô em cima"],
	"carniceiro": ["dois machados, o dobro de alegria", "roubo de vida tá rendendo", "velocidade de ataque é tudo"],
	"executor": ["deixa com 20% que eu executo", "machadão pesado, golpe certeiro", "execução é arte"],
	"sacerdote": ["cura em área pronta", "sacerdote raiz, só cura", "escudo sagrado em quem pedir"],
	"inquisidor": ["iluminado também bate, viu", "radiância no talo", "cura e dano, por que não os dois?"],
	"guardiao_verde": ["forma de urso é meu estado natural", "urso tanka mais que paladino, falei", "hibernar? só depois do chefe"],
	"fera": ["lobo corre e morde, simples", "forma de lobo é vida", "uivo pra chamar a matilha"],
	"xama": ["meus espíritos curam vocês, de nada", "xamã é suporte de luxo", "totem plantado, pode vir"],
	"cacador": ["eu e o lince contra o mundo", "arco longo, paciência curta", "flecha no joelho de alguém"],
	"atirador": ["rifle carregado", "armadilha no chão, bum", "pólvora seca é tudo que eu peço"],
	"laminas": ["veneno nas duas lâminas", "lâminas afiadas hoje", "picotar é minha especialidade"],
	"duelista": ["duelo justo? nunca ouvi falar", "a pluma do chapéu é pra estilo", "esgrima com classe"],
	"fogo": ["tudo queima se você insistir", "desculpa pela fumaça", "chamas no talo"],
	"gelo": ["gelo controla, gelo estilhaça", "deixa congelado que eu quebro", "frio é meu elemento"],
	"raio": ["raio em cadeia é lindo de ver", "o raio pula de um pro outro, junta eles", "cuidado que dá choque"],
	"invocador": ["exército de ossos pronto", "quanto mais esqueleto melhor", "meu rei esqueleto acordou de bom humor"],
	"ceifador": ["foice no pescoço", "ceifador colhe alma no atacado", "dreno de vida ligado"],
	"pestilento": ["sombras e maldições, meu combo", "praga espalhada", "a sombra faz o trabalho pesado"],
}

## Grupo com o jogador: o bot fala COM ele. Cada fala vira 3 (sem nome, "{p}, ..." e "..., {p}") em `_address`.
const PARTY_LINES := {
	"join": ["oi! bora", "opa, valeu pelo convite", "partiu", "tô dentro", "bora upar", "cheguei, pode liderar", "vou te seguir"],
	"welcome": ["bem-vindo", "chegou reforço", "agora sim, grupo bom", "a gente segue você", "um {pcls} no grupo, que luxo"],
	"town": ["vou passar no mercador rapidinho", "já tô com poção, quando quiser sair", "pra onde vamos?", "reparei tudo, pronto",
		"te espero no portão", "bora caçar ou vai ficar de turismo?"],
	"hunt": ["tô logo atrás", "pode puxar que eu acompanho", "esse lugar rende xp boa", "bolsa enchendo, mas ainda dá", "vai na frente que eu cubro",
		"quantos faltam pra quest?", "pausa pra mana rapidinho", "tá rendendo hein", "esse grupo tá bom demais"],
	"dungeon": ["fica perto, aqui dentro é apertado", "não corre na frente, pode ter armadilha", "o chefe deve estar perto", "você lidera, eu sigo",
		"cuidado com as alas laterais"],
	"enter_dungeon": ["entrando! todo mundo junto", "lá vamos nós", "{map}... fica perto", "chegou a hora", "luz na mão, gente"],
	"enter_map": ["{map}, aqui vamos nós", "chegamos em {map}", "{map}! bom lugar pra upar", "mapa novo, xp nova"],
	"player_low": ["vida baixa! bebe poção", "sai daí!", "recua que eu seguro", "F1 na poção!", "cuidado, tá quase!", "bloqueia com o botão direito!"],
	"player_died": ["nãooo", "F", "eita, levanta aí", "foi mal, não deu pra segurar", "volta que a gente espera", "essa doeu", "rip"],
	"player_levelup": ["parabéns pelo {lv}!", "gz!", "upou! gz", "nível {lv}, tá voando", "grats!! gasta os pontos na K"],
	"boss_fight": ["{boss}! todo mundo atento", "chefe! foca nele", "{boss} na área, guarda o dash", "segura a poção pra metade da vida dele", "lá vem {boss}"],
	"boss_kill": ["GG!!", "caiu! gg", "{boss} no chão, gg wp", "foi lindo isso", "que luta, gg", "ez (mentira, quase morri)"],
	"loot": ["olha o drop, {item}!", "{item}! sorte hein", "gz, {item}!", "drop bom", "{item} caiu pra você, aproveita"],
	"loot_legend": ["LENDÁRIO?? mentira", "moeda lendária!! gz", "corre na Relicária", "que sorte absurda"],
	"healed_by_player": ["valeu pela cura!", "vlw, tava precisando", "salvou minha vida", "obrigado!", "cura chegou na hora"],
	"healed_player": ["te curei, segura aí", "cura em você", "fica perto que eu curo", "vida de volta!"],
	"bot_died": ["morri, me espera", "caí, foi mal", "renascendo, já volto", "me deixaram morrer kkk", "volto já"],
	"self_levelup": ["upei pro {lv}! valeu pelo grupo", "nível {lv}! esse grupo rende", "{lv}!! bora mais"],
	"gather": ["colhe aí que eu vigio", "pega pra mim também kkk", "isso vale bem no mercador", "colhendo? fico de olho"],
	"raid": ["investida! vamos pro portão", "eles tão vindo, segura comigo", "defende a muralha!", "leva chegando, prepara"],
	"reply": ["ok", "blz", "bora", "tô indo", "kk", "pode puxar", "vlw", "+1", "certo", "fechou"],
	"reply_thanks": ["nada", "tmj", "de boa", "disponha"],
	"reply_go": ["bora!", "partiu", "vamo", "já tô indo"],
	"reply_wait": ["espero", "de boa, tô aqui", "ok, sem pressa", "pode ir"],
	"reply_hi": ["oi!", "eae", "salve", "opa"],
	"reply_ask": ["boa pergunta", "acho que sim", "não sei, mas confia", "pergunta pro Ancião kkk", "hmm, talvez"],
}
## Bot líder do grupo do jogador conta o plano (BotLeaderSystem). Marcas: {role} papéis que faltam, {name}/{cls} convidado,
## {mob}/{em}/{dest} viagem, {boss}, {map}, {p} jogador.
## Bot tomou uma Poção de Caça ao chegar na caça (HuntPotionSystem.bot_drink); {pocao} = nome do item.
const HUNT_POTION_LINES := {
	"xp": ["tomei um {pocao}, bora caçar", "{pocao} no bucho, hoje eu upo", "fiz {pocao} na alquimista, meia hora de xp extra",
		"quem tá caçando aqui? tomei {pocao}, vamo aproveitar"],
	"drop": ["tomei {pocao}, hoje cai lendário", "{pocao} ativo, quero ver dropar carta", "gastei meus materiais no {pocao}, que caia algo bom",
		"sorte no copo: {pocao}. bora"],
}

const LEADER_LINES := {
	"fill": ["Vamos completar o grupo: falta {role}.", "Antes de sair, vou chamar {role}.", "Grupo incompleto: procurando {role}."],
	"lead_full": ["Deixa comigo, eu lidero. Grupo cheio, já vamos sair.", "Assumi a liderança. Grupo completo, preparem-se."],
	"invite": ["Convidei {name} ({cls}).", "Chamei {name}, {cls}: {role} pra gente.", "Convite mandado pra {name} ({cls})."],
	"recruit_walk": ["Ninguém livre aqui perto. Vou ao ponto de encontro chamar {role}.", "Vou até a praça procurar {role}."],
	"go_partial": ["Não achei mais ninguém. Vamos assim mesmo: indo caçar {mob} {em}.", "Cansei de esperar: saindo com quem temos, rumo a {dest}."],
	"trip": ["Indo caçar {mob} {em}.", "Próxima parada: {dest}, atrás de {mob}.", "Bora: caçada de {mob} {em}."],
	"trip_full": ["Grupo cheio! Indo caçar {mob} {em}.", "Grupo completo, partiu {dest}: {mob} na mira.", "Tudo pronto. Indo caçar {mob} {em}."],
	"hunt": ["Chegamos {em}. Fiquem perto, caçando {mob}.", "{dest}! Caçando {mob}, sigam comigo."],
	"boss": ["Indo para {boss}, preparem-se!", "{boss} à vista! Tanque na frente, cura atrás.", "Chefe: {boss}. Guardem as recargas."],
	"return": ["Voltando à cidade para reabastecer.", "Hora de reabastecer: voltando à cidade."],
	"return_hurt": ["Estou mal de vida, voltando à cidade para me recuperar.", "Muito dano por hoje: voltando à cidade."],
	"return_bag": ["Bolsa cheia: voltando à cidade para vender.", "Sem espaço na bolsa, voltando à cidade."],
	"wait": ["Esperando {p} alcançar o grupo.", "{p}, te espero aqui, vem com a gente.", "Parando para {p} chegar."],
	"wait_over": ["Vou na frente, {p}; alcança a gente.", "Seguindo, {p}. Te espero mais adiante."],
}

## Palavras na fala do jogador (/p) que escolhem o tipo de resposta.
const REPLY_KEYS := {
	"reply_thanks": ["vlw", "valeu", "obrigad", "brigad", "thx"], "reply_go": ["bora", "vamos", "partiu", "vamo"],
	"reply_wait": ["espera", "pera", "calma", "afk", "brb"], "reply_hi": ["oi", "olá", "ola", "eae", "salve"],
}
## Mesmos eventos com a voz da classe (já com {p} onde faz sentido; somam às gerais).
const PARTY_CLASS := {
	"paladin": {"join": ["escudo à disposição, {p}", "{p}, pode deixar que eu seguro os monstros"],
		"hunt": ["{p}, deixa eu puxar que eu tanko", "fica atrás do escudo, {p}", "aggro comigo"],
		"player_low": ["{p}, vem pra trás de mim!", "provocando, sai daí {p}!"], "boss_fight": ["eu seguro {boss}, vocês batem", "escudo levantado, pode vir"]},
	"berserker": {"join": ["machado afiado, bora {p}"], "hunt": ["{p}, deixa uns pra mim", "mais rápido, {p}, quero sangue", "puxa mais, tá pouco"],
		"player_low": ["{p}, sai que eu entro girando!"], "boss_fight": ["{boss}! FINALMENTE", "fúria ligada"]},
	"bishop": {"join": ["healer na área, {p}, pode ir sem medo"], "hunt": ["fica no meu alcance, {p}", "{p}, avisa antes de puxar que eu preparo a cura", "bênção renovada"],
		"player_low": ["curando, {p}! aguenta!", "segura que eu curo!"], "boss_fight": ["fiquem juntos que a cura em área pega", "mana cheia, pode começar"]},
	"druid": {"join": ["vou de bicho do seu lado, {p}"], "hunt": ["{p}, senti cheiro de javali ali", "virando urso, pode puxar", "a natureza tá do nosso lado"],
		"player_low": ["{p}, recua que a natureza cuida!"], "boss_fight": ["forma de urso! vem, {boss}"]},
	"ranger": {"join": ["eu e o lince, {p}, a seu dispor"], "hunt": ["{p}, puxa pra perto da armadilha", "cobrindo de longe", "o lince achou mais um"],
		"player_low": ["{p}, kita ele que eu atiro!", "recua que eu cubro de longe"], "boss_fight": ["armadilha no chão, traz {boss} pra cá"]},
	"assassin": {"join": ["{p}, vou estar por perto. você só não vai me ver"], "hunt": ["{p}, segura o aggro que eu vou pelas costas", "sumindo um pouco", "deixa o mais forte comigo"],
		"player_low": ["{p}, sai! eu distraio ele"], "boss_fight": ["pelas costas de {boss}, sempre"]},
	"elementalist": {"join": ["{p}, não fica na frente do meu cajado e tá tudo certo"], "hunt": ["{p}, junta eles que eu solto área", "congelei, pode quebrar", "fogo neles!"],
		"player_low": ["congelei ele, foge {p}!"], "boss_fight": ["elemental invocado, {boss} vai sentir"]},
	"necromancer": {"join": ["{p}, meus esqueletos te cumprimentam"], "hunt": ["{p}, deixa os mortos irem na frente", "mais corpo pro meu exército", "maldição lançada"],
		"player_low": ["{p}, meus ossos seguram, recua!"], "boss_fight": ["amaldiçoando {boss}, bate agora"]},
}

## Todos os conjuntos de falas por chave: "place:<tipo>", "map:<town|hunt>_<mapa>", "class:<id>", "build:<id>", "party:<evento>",
## "party:<evento>:<classe>", e os antigos ("death", "levelup", "leaving", "town", "hunt").
static func pools() -> Dictionary:
	var out := {}
	for k in LINES:
		var key: String = str(k)
		if key.begins_with("town_") or key.begins_with("hunt_"):
			out["map:" + key] = LINES[k]
		else:
			out[key] = LINES[k]
	for kind in PLACE_LINES:
		out["place:" + kind] = (PLACE_LINES[kind] as Array).duplicate()
	(out["place:aldara_town"] as Array).append_array(LINES["town"])     # papo de cidade antigo é de Aldara
	(out["place:aldara_field"] as Array).append_array(LINES["hunt"])
	out["place:victory"] = VICTORY_LINES.duplicate()
	out["place:kharzun_victory"] = KHARZUN_VICTORY_LINES.duplicate()
	for cid in CLASS_VOICE:
		var v: Dictionary = CLASS_VOICE[cid]
		var arr: Array = (v["lines"] as Array).duplicate()
		for t in CLASS_WANT:
			for w in v["want"]:
				arr.append(str(t).replace("{want}", w))
		for t in CLASS_DOING:
			for d in v["doing"]:
				arr.append(str(t).replace("{doing}", d))
		out["class:" + cid] = arr
	for bid in BUILD_LINES:
		out["build:" + bid] = BUILD_LINES[bid]
	for ev in PARTY_LINES:
		var arr: Array = []
		for line in PARTY_LINES[ev]:
			arr.append_array(_address(str(line)) if not str(ev).begins_with("reply") or ev == "reply_hi" else [str(line)])
		out["party:" + ev] = arr
	for cid in PARTY_CLASS:
		for ev in PARTY_CLASS[cid]:
			out["party:%s:%s" % [ev, cid]] = PARTY_CLASS[cid][ev]
	return out

## Uma fala vira até 3 jeitos de falar com o jogador: como está, "{p}, fala" e "fala, {p}" (pontuação final fica no fim;
## fala que já tem vírgula só ganha o nome na frente).
static func _address(line: String) -> Array:
	if line.contains("{p}"):
		return [line]
	var out: Array = [line]
	if line == line.to_upper() and line.to_lower() != line:
		return out                           # GRITO não ganha nome
	out.append("{p}, " + line)
	if line.ends_with(")") or line.contains(","):
		return out                           # "olha o drop, Anel, Fulano!" fica estranho: nome só na frente
	var tail := ""
	var body := line
	while body.length() > 0 and body[body.length() - 1] in ["!", "?", "."]:
		tail = body[body.length() - 1] + tail
		body = body.substr(0, body.length() - 1)
	out.append(body + ", {p}" + tail)
	return out

# ---------------------------------------------------------------------------
# BOTS COM MEMÓRIA (design/gdd/bots-com-memoria.md; RosterSystem/GuildSystem)

const PERSONALITIES := ["calmo", "brincalhao", "competitivo", "timido", "heroico"]
const PERSONALITY_LABELS := {"calmo": "Calmo", "brincalhao": "Brincalhão", "competitivo": "Competitivo", "timido": "Tímido", "heroico": "Heroico"}
const MEMORY_LABELS := {"salvou": "Você o salvou", "grupo": "Venceram um chefe juntos", "abandonou": "Você saiu do grupo na masmorra",
	"ajudou_pedido": "Você veio no pedido de socorro", "perdeu_saque": "Você ficou com o lendário", "corrida": "Você venceu a corrida de chefe",
	"presente": "Você deixou no banco algo para ele", "guerra": "Venceram uma Guerra de Guildas juntos"}

## Falas do elenco: evento -> personalidade -> frases ("*" = qualquer personalidade, usado quando a dela falta).
## Marcas: {p} jogador, {me} o bot, {map}, {boss}, {lv}, {item}, {guild}.
const ROSTER_LINES := {
	"greet_hi": {
		"*": ["{p}! bom te ver", "olha quem chegou, {p}!", "{p}, meu parceiro!"],
		"brincalhao": ["{p}!!! achei que tinha largado o jogo kkk", "chegou o herói, {p}"],
		"timido": ["oi {p} :)", "...oi {p}"],
		"heroico": ["{p}! juntos ninguém segura a gente", "salve, {p}! pronto pra próxima?"],
		"competitivo": ["{p}, tô de olho no seu nível hein", "e aí {p}, ainda na minha frente?"]},
	"greet": {
		"*": ["oi {p}", "e aí {p}", "opa, {p}"],
		"calmo": ["bom te ver por aqui, {p}"],
		"timido": ["oi..."]},
	"greet_dry": {
		"*": ["{p}.", "hm. {p}.", "ah, é você."],
		"competitivo": ["nem vou falar nada, {p}"],
		"brincalhao": ["olha, o {p}. que surpresa (não)"]},
	"mem_salvou": {
		"*": ["valeu {p}, essa foi por pouco!", "{p} me salvou, devo uma", "ufa, obrigado {p}"],
		"heroico": ["{p}, te devo a vida. não esqueço", "valeu {p}! agora é minha vez de proteger"],
		"timido": ["o-obrigado {p}...", "valeu... de verdade"],
		"brincalhao": ["{p} salvando minha pele de novo kkkk", "quase virei estatística, valeu {p}"],
		"competitivo": ["eu tinha controle... mas valeu, {p}"]},
	"mem_grupo": {
		"*": ["que luta! {boss} já era", "gg {p}! grupo bom demais", "boa, {p}! de novo qualquer hora"],
		"competitivo": ["meu dano foi maior, mas gg {p}"],
		"calmo": ["bem jogado, {p}. sem pressa, sem erro"],
		"heroico": ["{boss} caiu! juntos somos fortes, {p}!"]},
	"mem_abandonou": {
		"*": ["sério, {p}? largou a gente no meio da masmorra", "valeu por nada, {p}", "{p} saiu do grupo... ok"],
		"timido": ["...tá bom, {p}"],
		"brincalhao": ["{p} deu rage quit kkk (não tem graça)"]},
	"mem_ajudou_pedido": {
		"*": ["{p} veio! valeu demais", "chegou na hora, {p}!", "eu sabia que podia contar com você, {p}"],
		"heroico": ["{p}! sabia que viria. lado a lado!"],
		"timido": ["v-você veio... obrigado {p}"]},
	"mem_perdeu_saque": {
		"*": ["esse lendário era meu sonho... parabéns {p}", "aff, de novo não veio pra mim", "ok {p}, esse fica com você"],
		"competitivo": ["próximo é meu, {p}. anota"],
		"calmo": ["tudo bem, tem mais de onde veio"]},
	"mem_corrida": {
		"*": ["você foi mais rápido, {p}. respeito", "ganhou essa, {p}. próxima é minha"],
		"competitivo": ["...dessa vez, {p}. só dessa vez"]},
	"ambient": {
		"calmo": ["sem pressa hoje", "o vento aqui é bom", "devagar e sempre"],
		"brincalhao": ["alguém viu minha dignidade? perdi no último boss kkk", "bora fazer party da zoeira", "lag de novo? culpa do druida"],
		"competitivo": ["quem chega no próximo nível primeiro?", "meu dps tá absurdo hoje", "ninguém me alcança"],
		"timido": ["...", "oi gente (baixinho)", "alguém quer duo? se não tiver problema..."],
		"heroico": ["se alguém precisar de ajuda, me chama!", "nenhum monstro vai passar por mim", "pela Aurora!"]},
	"celebrate_level": {
		"*": ["gz {p}! nível {lv}!", "parabéns pelo {lv}, {p}!", "{lv}! tá voando, {p}"],
		"competitivo": ["{lv}? tô logo atrás, {p}", "gz... vou te alcançar"],
		"brincalhao": ["{lv}!!! festa na praça kkk", "upou! paga a rodada, {p}"],
		"timido": ["gz {p} :)"]},
	"celebrate_legend": {
		"*": ["LENDÁRIO! gz {p}!", "olha o brilho disso, {p}!", "que drop, {p}!"],
		"competitivo": ["sortudo... gz {p}"],
		"brincalhao": ["me empresta? kkk gz {p}"]},
	"celebrate_card": {
		"*": ["carta nova! gz {p}", "{item}? boa, {p}!", "coleção crescendo, {p}"],
		"timido": ["que carta bonita..."]},
	"celebrate_boss": {
		"*": ["{boss} caiu! gz {p}", "boa {p}! {boss} já era", "mandou bem no {boss}, {p}"],
		"competitivo": ["{boss}? já matei faz tempo kkk gz", "boa, mas meu tempo foi melhor"],
		"heroico": ["{boss} derrotado! viva {p}!"]},
	"stranger_cheer": {
		"*": ["gz!", "parabéns!", "gg", "boa!"]},
	"help_low_hp": {
		"*": ["socorro! tô quase morrendo em {map}!", "alguém?? vida no fim em {map}!", "help!! {map}, rápido"],
		"timido": ["a-alguém pode vir em {map}? tô mal..."],
		"heroico": ["segurando aqui em {map}, mas preciso de reforço!"]},
	"help_surrounded": {
		"*": ["cercado em {map}! ajuda!", "pull deu errado em {map}, alguém vem?", "muito bicho em {map}, socorro"],
		"brincalhao": ["puxei metade de {map} kkkk me ajuda"],
		"competitivo": ["preciso de... ajuda. em {map}. rápido."]},
	"help_boss": {
		"*": ["tô no {boss} em {map}, alguém vem?", "{boss} me pegou em {map}! ajuda!", "falta gente pro {boss} em {map}!"],
		"heroico": ["enfrentando {boss} em {map}! quem vem comigo?"]},
	"help_thanks": {
		"*": ["{p} chegou! valeu, toma isso", "obrigado {p}! leva umas poções", "você veio! fica com isso, {p}"]},
	"rival_level": {
		"*": ["nível {lv}! tô na frente, {p}", "{lv}. sua vez, {p}"],
		"competitivo": ["{lv}! cadê você, {p}?", "nível {lv}. vou deixar você pra trás"],
		"brincalhao": ["{lv}!!! corre {p} kkk"],
		"calmo": ["cheguei no {lv}. com calma, {p}"],
		"timido": ["peguei o {lv}... sua vez, {p}?"],
		"heroico": ["{lv}! vamos ver quem chega primeiro, {p}"]},
	"rival_boss": {
		"*": ["{me} matou {boss}. Sua vez.", "{boss} já era. Sua vez, {p}."],
		"competitivo": ["{boss} caiu pra mim primeiro. de novo, {p}"],
		"brincalhao": ["{boss} foi fácil kkk sua vez {p}"]},
	"rival_race_start": {
		"*": ["corrida no {boss}? fechado, {p}!", "{boss}, quem matar primeiro. valendo!"],
		"competitivo": ["{boss}? já ganhei. valendo, {p}!"],
		"timido": ["t-tá bom... {boss}. valendo"]},
	"rival_race_won": {
		"*": ["você ganhou a corrida do {boss}, {p}. respeito", "{boss} foi seu... dessa vez"]},
	"rival_race_lost": {
		"*": ["{boss} caiu! ganhei a corrida, {p}", "cheguei antes no {boss}. sua vez de treinar"],
		"competitivo": ["{boss}: EU. corrida: MINHA. kkk"]},
	"rival_race_expired": {
		"*": ["{boss} venceu nós dois. empate, {p}", "tempo esgotado no {boss}. fica pra próxima"]},
	"guild_invite": {
		"*": ["{p}, a gente montou a guilda {guild}. quer entrar?", "fundamos a {guild}! falta você, {p}. topa?"],
		"timido": ["{p}... a gente fez uma guilda, a {guild}. você... quer vir?"],
		"heroico": ["{p}! a {guild} nasceu e tem um lugar pra você!"]},
	"guild_welcome": {
		"*": ["bem-vindo à {guild}, {p}!", "{p} entrou! agora sim", "a {guild} tá completa com você, {p}"],
		"brincalhao": ["{p} na guilda! alguém faz o bolo kkk"]},
	"guild_refused": {
		"*": ["tudo bem, {p}. a porta fica aberta", "beleza, {p}. se mudar de ideia..."],
		"competitivo": ["azar o seu, {p}"]},
	"guild_founded": {
		"*": ["{guild}? tô dentro, {p}!", "guilda nova! conta comigo, {p}"]},
	"guild_join": {
		"*": ["posso entrar na {guild}? valeu, {p}!", "{me} chegando na {guild}!"]},
	"guild_leave_low": {
		"*": ["não dá mais, {p}. tô saindo da {guild}", "cansei. saindo da guilda"],
		"timido": ["...acho melhor eu sair da {guild}"]},
	"guild_reply": {
		"*": ["haha verdade", "concordo", "bora!", "kkkk", "falou tudo", "eu topo", "agora não dá, tô caçando"],
		"heroico": ["conte comigo!"], "timido": ["s-sim"], "competitivo": ["eu faço melhor"]},
	"mem_presente": {
		"*": ["{p}, vi o {item} no banco. é meu número!", "valeu pelo {item}, {p}", "o {item} do banco foi você? obrigado!"]},
	"mem_guerra": {
		"*": ["que guerra, {p}! valeu por lutar do nosso lado", "lutei do seu lado, {p}. de novo quando quiser", "ainda ouço o portão caindo. valeu, {p}"],
		"heroico": ["pela guilda! foi uma honra, {p}"], "competitivo": ["quero a revanche só pra ganhar de novo"]},
	"party_dry": {
		"*": ["tá. entro.", "ok, {p}. mas sem largar no meio", "hm. vamos lá"]},
}

## Nomes que a guilda do elenco escolhe (§9.6). A etiqueta sai das iniciais (GuildSystem.make_tag).
const GUILD_NAMES := ["Coração de Aldara", "Os Sem Pressa", "Lâmina Partilhada", "Fogueira Eterna", "Ordem do Café",
	"Vigília da Aurora", "Bando do Javali", "Os Teimosos", "Estrela do Vale", "Pacto da Taverna"]

## Guildas de bots do mundo (adversárias da GvG, guerra-de-guildas.md §3.1): nome, etiqueta, personalidade, brasão.
const BOT_GUILDS := [
	{"name": "Lanternas de Aldara", "tag": "LAN", "personality": "defensiva", "crest": 0},
	{"name": "Lobos de Ferro", "tag": "LDF", "personality": "agressiva", "crest": 1},
	{"name": "Corvos do Brejo", "tag": "CDB", "personality": "astuta", "crest": 2},
	{"name": "Escudo de Kharzun", "tag": "EDK", "personality": "equilibrada", "crest": 3},
	{"name": "Filhos da Fenda", "tag": "FDF", "personality": "agressiva", "crest": 4},
	{"name": "Guarda do Porto", "tag": "GDP", "personality": "defensiva", "crest": 5},
]

## Banco da Guilda (design/gdd/banco-da-guilda.md; GuildBankSystem.line): {p} jogador, {me} bot, {item} item, {map} lugar,
## {n} quantidade, {got} o que trouxe, {gold} ouro devolvido, {rank} patente.
const GBANK_LINES := {
	"deposit": {
		"*": ["deixei {item} no banco, alguém usa?", "{item} no banco pra quem precisar", "achei {item}, tá no banco"],
		"brincalhao": ["{item} no banco! de nada kkk"], "timido": ["d-deixei {item} no banco..."], "heroico": ["{item} no banco! pela guilda!"]},
	"rank_up": {
		"*": ["parabéns pela patente de {rank}, {p}!", "{rank}! merecido, {p}", "olha o {p} virando {rank}"],
		"competitivo": ["{rank}? eu chego lá também"], "brincalhao": ["{rank}!!! paga uma rodada, {p}"]},
	"back_material": {
		"*": ["Voltei de {map}! Achei {n} {got}, tá reservado no banco pra você.", "Encomenda feita: {n} {got}. Deu trabalho em {map}!"],
		"brincalhao": ["Voltei de {map}! {n} {got} e só uma mordida no braço kkk"], "heroico": ["Missão cumprida em {map}: {n} {got} pra você, {p}!"],
		"timido": ["V-voltei de {map}... trouxe {n} {got}."], "calmo": ["Voltei de {map} com calma. {n} {got}, tá no banco."]},
	"back_card": {
		"*": ["Voltei de {map}! Achei a {got}, ela quase me pegou.", "Consegui a {got} em {map}! É sua, {p}."],
		"competitivo": ["{got}? Fácil. Tá no banco."], "heroico": ["A {got} é sua, {p}! {map} não foi páreo."]},
	"back_miss": {
		"*": ["Rodei {map} inteiro e nada da {item}... trouxe {n} {got} e metade da taxa ({gold} de ouro).",
			"A {item} não caiu. Desculpa, {p}: {gold} de ouro de volta e {n} {got}."],
		"timido": ["n-não achei a {item}... devolvi {gold} de ouro e trouxe {n} {got}."]},
}

## Campo de Caça da Guilda (ArenaSystem._chat): fim da corrida no chat da guilda. {wave}, {name} = outro bot do grupo.
const ARENA_LINES := {
	"record": ["LEVA {wave}! recorde novo da guilda, alguém tira print", "leva {wave}, ninguém da guilda chegou tão longe", "{wave}! e o {name} ainda queria sair na 10"],
	"wipe": ["leva {wave}... o {name} caiu primeiro, claro", "caímos na {wave}. semana que vem passa", "leva {wave}. precisamos de mais cura, só digo isso"],
	"leave": ["saímos na leva {wave}, bolso cheio", "leva {wave} e fora, sem morrer. gosto assim", "{wave} levas, bom treino"],
}

## Casa de Leilões (casa-de-leiloes.md §3.5; AuctionSystem._chat): fala de negócio de bot no leilão, por personalidade do elenco
## ("*" = qualquer bot). {item} = nome do item. Passa pelo ritmo do elenco (RosterSystem.can_speak) e por Balance.AUCTION_CHAT_GAP.
const AUCTION_LINES := {
	"sold": {
		"*": ["vendi {item} no leilão, finalmente", "alguém comprou meu {item}, valeu quem foi", "{item} vendido. ouro na caixa"],
		"competitivo": ["{item} vendido pelo MEU preço. aprendam", "pedi caro no {item} e venderam. mercado é isso"],
		"brincalhao": ["vendi {item} kkk quem comprou vai se arrepender", "{item} foi embora, adeus amigo"],
		"timido": ["...vendi {item}", "venderam meu {item} :)"],
		"heroico": ["{item} vendido, que sirva bem a quem levou!", "mais um {item} indo pra linha de frente"],
	},
	"bought": {
		"*": ["comprei {item} no leilão, finalmente", "achei {item} no leilão, sorte", "peguei {item} no leilão baratinho"],
		"competitivo": ["{item} no leilão por esse preço? levei antes de vocês", "comprei {item}. agora ninguém me alcança"],
		"brincalhao": ["comprei {item} sem ver o preço kkk", "{item} no leilão, impulso puro"],
		"timido": ["consegui {item} no leilão :)", "...comprei {item}"],
		"heroico": ["{item} comprado. bora pra caçada!", "com esse {item} a gente segura a próxima"],
	},
}
