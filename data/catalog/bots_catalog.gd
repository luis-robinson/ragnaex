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
		"como upa maestria?", "resp: usa a skill 30 vezes que sobe sozinha", "o elixir da força é muito bom",
	],
	"hunt": [
		"esse lobo é rápido demais", "ajuda aqui!!", "quase morri kkkk", "dropou o anel!!!", "cadê os javalis",
		"alguém pra matar o chefe?", "ks :(", "vou voltar pra cidade, bolsa cheia", "+1 lvl", "esse boss bate forte",
		"não aggra o rei javali agora pfv", "lootei 4 minério", "bloqueia quando ele avançar", "pull de 5 slime ez",
	],
	# caçando num mapa específico (BotBrain: "hunt_<mapa>" ou "town_<mapa>" quando existe, senão o genérico)
	"hunt_field_forest": ["paliçada dos bandidos tá lotada hoje", "cuidado com os arqueiros na trilha leste", "alguém viu o Chefe dos Bandidos?",
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
	"leaving": ["indo pra %s, alguém vem?", "partiu %s", "vou caçar na %s"],
}
