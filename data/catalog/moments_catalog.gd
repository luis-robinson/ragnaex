class_name MomentsCatalog
extends RefCounted
## Momentos do Mundo (GDD design/gdd/momentos-do-mundo.md): falas dos Chefes de Mundo e as cadeias de eventos.
## Falas provisórias (o roteirista revisa). Números SÓ em Balance.WORLD_BOSS_* / CHAIN_*.

## Chefe de mundo -> falas. `warn` = aviso 2 min antes (chat de todos os mapas), `spawn` = nasceu, `farewell` = sumiu sem
## morrer (WORLD_BOSS_LIFE), `killed` = caiu, `place` = onde (para o HUD).
const WORLD_BOSS_LINES := {
	"ancestral_boar": {"place": "na Campina de Aldara",
		"warn": "Os chãos da Campina tremem... algo muito velho e muito grande desperta debaixo do Vale.",
		"spawn": "O Javali Ancestral saiu do mato na Campina! Todo mundo para lá!",
		"farewell": "O Javali Ancestral bufa uma última vez e volta a dormir debaixo do Vale. Até a próxima.",
		"killed": "O Javali Ancestral caiu na Campina! O Vale inteiro ouviu."},
	"ancient_elk": {"place": "na Floresta Sombria",
		"warn": "As árvores da Floresta Sombria se calam... cristais brotam no musgo, um a um.",
		"spawn": "O Alce Ancião de chifres de cristal apareceu na Floresta Sombria!",
		"farewell": "O Alce Ancião some entre as árvores; só ficam lascas de cristal no chão.",
		"killed": "O Alce Ancião caiu! Os cristais da Floresta se apagam devagar."},
	"ruins_basilisk": {"place": "nas Ruínas da Aurora",
		"warn": "As pedras das Ruínas da Aurora se mexem sozinhas... não olhem nos olhos das estátuas.",
		"spawn": "O Basilisco das Ruínas abriu os olhos! Cuidado com o olhar dele!",
		"farewell": "O Basilisco volta a ser pedra entre as ruínas. Ninguém sabe dizer qual delas.",
		"killed": "O Basilisco das Ruínas caiu! As estátuas das Ruínas ficam paradas de vez."},
	"war_rhino": {"place": "nas Estepes de Cinza",
		"warn": "Tambores de guerra nas Estepes de Cinza... a plataforma da Horda está vindo.",
		"spawn": "O Rinoceronte de Guerra da Horda entrou nas Estepes! Os tambores não param!",
		"farewell": "Os tambores se afastam: o Rinoceronte de Guerra some na poeira da estepe.",
		"killed": "O Rinoceronte de Guerra tombou! Os tambores da Horda rolam pela estepe."},
	"iron_wolf_king": {"place": "no Monte Kharzun",
		"warn": "Um uivo de ferro desce o Monte Kharzun... a matilha toda responde.",
		"spawn": "O Lobo-Rei de Ferro desceu a encosta de Kharzun! As runas da armadura estão acesas!",
		"farewell": "O Lobo-Rei sobe a montanha de volta; o eco do uivo dura um tempão.",
		"killed": "O Lobo-Rei de Ferro caiu! As runas se apagam no Monte Kharzun."},
	"porcelain_stag": {"place": "na Avenida do Cortejo",
		"warn": "As lanternas da Avenida do Cortejo se acendem sozinhas... a festa vai receber um convidado.",
		"spawn": "O Gamo de Porcelana da Festa entrou dançando na Avenida do Cortejo!",
		"farewell": "O Gamo de Porcelana faz uma reverência e sai do baile. As lanternas se apagam.",
		"killed": "O Gamo de Porcelana rachou em veios de ouro! As lanternas sobem para o céu da festa."},
}

## O que os bots gritam no chat ao saber do chefe (`{boss}` = nome) e depois da luta.
const WORLD_BOSS_BOT_GO := ["Bora, {boss}! Tô indo!", "{boss}?! Larguei tudo, me esperem!", "Alguém segura o {boss} aí que eu tô chegando!",
	"{boss} de novo! Desta vez eu pego.", "Corre, corre! {boss}!"]
const WORLD_BOSS_BOT_WON := ["Que luta! GG a todos.", "Derrubamos o {boss}! Valeu, galera.", "Bagunça boa. Até o próximo!", "GG! Quem viu aquele golpe?"]

## Cadeias (§3.2). Hoje só a piloto da Campina (§9.2). `step` = regra de evento de estrada (mesmo formato de
## MapsCatalog.ROAD_EVENTS; RoadEventSystem.start com a regra), `arrived`/`fell` = desfecho -> marca de mundo.
## arrived.npcs = feirantes que aparecem enquanto a marca vale ([id, nome, x, z, carga, falas]).
const CHAINS := {
	"campina": {"map": "city_aldara", "name": "Caravana do Tobias",
		"step": {"kind": "caravan", "name": "Caravana do Tobias", "mob": "bandit_footpad", "mob_name": "Salteador da Campina", "count": [3, 4],
			"victim": ["Caravana do Tobias", Color(0.7, 0.55, 0.35)], "home": [22.5, -9.4], "carry": "cart_draft",
			"cry": ["Salteadores na estrada! A carga do Tobias!", "Socorro! Querem levar a carroça da feira!", "Larguem os cavalos, seus ratos!"],
			"thanks": ["A carga está inteira! A feira vai abrir na praça. Leve estas poções.", "Obrigado! Diga pra todo mundo: hoje tem feira em Aldara!"],
			"flee": ["São muitos! Larguem tudo, corram pra vila!", "Levaram a carroça... e os bandidos vão acampar na estrada!"],
			"bot_chat": ["Escoltei a caravana do Tobias até a vila. Tem feira na praça!", "Salteadores em cima da caravana da feira. Resolvido.", "A carroça do Tobias chegou inteira. De nada, Aldara."],
			"reward_item": "potion_hp_s", "reward_count": 2},
		"announce": "A Caravana do Tobias está sendo atacada na estrada da Campina!",
		"arrived": {"mark": "campina_fair", "label": "Feira em Aldara: lojas com desconto",
			"announce": "A Caravana do Tobias chegou! Feira na praça de Aldara: as lojas do Vale estão com desconto.",
			"end": "A feira acabou: os feirantes recolhem as barracas da praça.",
			"npcs": [["fair_tobias", "Tobias da Caravana", 7.6, 8.6, "cart", ["Chegou tudo! Pano, tempero e poção boa. Hoje é dia de feira!", "Aproveita: o Mercador baixou os preços enquanto a feira durar."]],
				["fair_juggler", "Malabarista Pipa", -8.2, 8.4, "", ["Três bolas, quatro bolas... cinco! Ninguém aplaude?", "Na feira tudo é mais barato. Menos a minha arte."]],
				["fair_spice", "Temperista Nara", 9.4, -4.6, "carry_sack", ["Pimenta do sul, sal da costa. Cheire isso!", "A caravana quase não chegou. Ainda bem que alguém ajudou."]]]},
		"fell": {"mark": "campina_bandits", "label": "Acampamento Bandido na estrada",
			"announce": "A Caravana do Tobias caiu! Os bandidos montaram acampamento na estrada da Campina.",
			"cleared": "O Acampamento Bandido foi desfeito! A estrada da Campina está livre de novo.",
			"end": "Os bandidos levantam acampamento e somem com o que roubaram.",
			"boss": "camp_bandit_boss", "mob": "camp_bandit"},
	},
}
