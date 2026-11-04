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
	"death": ["morri", "F", "respawn...", "esse golem não é brincadeira", "ok vou tankar menos"],
	"levelup": ["LV %d!!", "upei pro %d", "lv %d finalmente", "%d, bora pro próximo"],
	"leaving": ["indo pra %s, alguém vem?", "partiu %s", "vou caçar na %s"],
}
