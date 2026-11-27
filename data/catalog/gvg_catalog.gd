class_name GvgCatalog
extends RefCounted
## Guerra de Guildas (design/gdd/guerra-de-guildas.md §3.6): papéis, planos, ordens, gatilhos e falas do GvgBrain.
## Plano = para cada papel um objetivo ("goal") e um reserva ("alt", vale quando o objetivo não existe mais: sem
## aríete, sem canhão livre). Objetivos que o GvgBrain sabe resolver (GvgBrain._resolve):
##   ram          anda com o aríete do lado (raio de empurrar) e briga só perto dele
##   gate_main    atacante: bate no portão principal inimigo (caiu = cristal); defensor: segura dentro do próprio portão
##   gate_side    o mesmo no portão lateral
##   crystal      atacante: bate no Cristal; defensor: guarda o próprio Cristal
##   cannon_wall  opera um canhão da própria muralha (só o defensor tem muralha a usar)
##   cannon_hill  opera um canhão do morro
##   cannon       qualquer canhão livre do lado (muralha ou morro, o mais perto)
##   hill         segura o morro (protege os canhões dele)
##   stair        defensor: segura a escada do salão; atacante: vai ao cristal
##   wall         defensor: atrás do portão, atirando de cima
##   sally        defensor: sai e queima os aríetes (sem aríete = wall)
##   hunt         caça canhoneiros e curas inimigos perto do ponto `at` (gate_main | hill | ram = anda com o aríete) e briga lá
##   escort       Cura: atrás do Muro mais perto (sem Muro = aliado mais perto), curando
##   leader       ordem "all_to_me": vai até quem deu a ordem
##   retreat      volta ao renascer (atacante) / à escada (defensor)
## Pesos de personalidade (BotsCatalog.BOT_GUILDS "personality") em Balance.GVG_AI_PLAN_WEIGHTS: plano do começo e de cada gatilho.

const ROLES := ["muro", "cura", "artilharia", "ponta", "batedores"]
const ROLE_NAMES := {"muro": "Muro", "cura": "Cura", "artilharia": "Artilharia", "ponta": "Ponta", "batedores": "Batedores"}

## Papel da build (ProgressionSystem.role_of) -> papel da guerra. Assassino e Lanceiro viram Batedores (até
## Balance.GVG_AI_SCOUTS_MAX por lado); de longe além de GVG_AI_ARTY_MAX viram Ponta de longe.
const ROLE_OF_BUILD_ROLE := {"tank": "muro", "healer": "cura", "ranged": "artilharia", "caster": "artilharia", "dps": "ponta"}
const SCOUT_CLASSES := ["assassin"]
const SCOUT_BUILDS := ["lanceiro"]

const PERSONALITIES := ["agressiva", "defensiva", "astuta", "equilibrada"]

## Objetivos do plano de ataque que viram "crystal" quando um portão do castelo inimigo caiu (GvgBrain.goal_of).
const OPEN_GATE_GOALS := ["hill", "cannon_hill", "cannon", "hunt", "gate_side", "ram"]

const ATTACK_PLANS := {
	"martelo": {"name": "Martelo",
		"roles": {"muro": {"goal": "ram", "alt": "gate_main"}, "cura": {"goal": "escort"},
			"artilharia": {"goal": "cannon_hill", "alt": "gate_main"}, "ponta": {"goal": "hunt", "at": "ram"},
			"batedores": {"goal": "gate_main"}}},
	"pinca": {"name": "Pinça",
		"roles": {"muro": {"goal": "ram", "alt": "gate_main"}, "cura": {"goal": "escort"},
			"artilharia": {"goal": "cannon_hill", "alt": "gate_main"}, "ponta": {"goal": "hunt", "at": "ram"},
			"batedores": {"goal": "gate_side"}}},
	"bateria": {"name": "Bateria",
		"roles": {"muro": {"goal": "hill"}, "cura": {"goal": "escort"}, "artilharia": {"goal": "cannon_hill", "alt": "hill"},
			"ponta": {"goal": "hunt", "at": "hill"}, "batedores": {"goal": "hunt", "at": "hill"}}},
	"cerco_lento": {"name": "Cerco Lento",
		"roles": {"muro": {"goal": "hill"}, "cura": {"goal": "escort"}, "artilharia": {"goal": "cannon_hill", "alt": "hill"},
			"ponta": {"goal": "hunt", "at": "hill"}, "batedores": {"goal": "hill"}}},
}

const DEFENSE_PLANS := {
	"muralha": {"name": "Muralha",
		"roles": {"muro": {"goal": "gate_main"}, "cura": {"goal": "escort"}, "artilharia": {"goal": "cannon_wall", "alt": "wall"},
			"ponta": {"goal": "hunt", "at": "gate_main"}, "batedores": {"goal": "cannon_wall", "alt": "wall"}}},
	"surtida": {"name": "Surtida",
		"roles": {"muro": {"goal": "sally"}, "cura": {"goal": "escort"}, "artilharia": {"goal": "cannon_wall", "alt": "wall"},
			"ponta": {"goal": "sally"}, "batedores": {"goal": "hunt", "at": "hill"}}},
	"recuo": {"name": "Recuo",
		"roles": {"muro": {"goal": "stair"}, "cura": {"goal": "escort"}, "artilharia": {"goal": "cannon_wall", "alt": "stair"},
			"ponta": {"goal": "stair"}, "batedores": {"goal": "stair"}}},
}

## Ordem (Sim.gvg_order) -> objetivo por papel ("*" = todos). Vale até sides[S].order.until, depois volta ao plano.
## "cannons" = comando de chat /canhoes (fora da roda do contrato §3: Artilharia + Batedores em qualquer canhão).
const ORDERS := {
	"attack_gate_main": {"*": {"goal": "gate_main"}},
	"attack_gate_side": {"*": {"goal": "gate_side"}},
	"take_hill": {"*": {"goal": "hill"}, "artilharia": {"goal": "cannon_hill", "alt": "hill"}},
	"protect_ram": {"muro": {"goal": "ram", "alt": "gate_main"}, "cura": {"goal": "escort"}, "ponta": {"goal": "ram", "alt": "gate_main"},
		"batedores": {"goal": "ram", "alt": "gate_main"}},
	"hold_stair": {"*": {"goal": "stair"}},
	"sally": {"*": {"goal": "sally"}, "cura": {"goal": "escort"}},
	"retreat": {"*": {"goal": "retreat"}},
	"all_to_me": {"*": {"goal": "leader"}},
	"cannons": {"artilharia": {"goal": "cannon", "alt": "wall"}, "batedores": {"goal": "cannon", "alt": "wall"}},
}

## Gatilhos de troca de plano, na ordem em que são conferidos (um por segundo, cada um uma vez por guerra e lado).
## "attack"/"defense" = candidatos (peso de personalidade do plano); vazio = o lado não reage.
const TRIGGERS := [
	{"id": "gate_broken", "attack": ["martelo"], "defense": ["recuo"]},
	{"id": "rams_lost", "attack": ["cerco_lento", "bateria"], "defense": []},
	{"id": "gate_low", "attack": ["martelo"], "defense": ["recuo", "surtida"]},
	{"id": "half_dead", "attack": ["cerco_lento", "bateria"], "defense": ["recuo", "muralha"]},
	{"id": "hill_lost", "attack": ["bateria"], "defense": ["surtida"]},
	{"id": "hill_won", "attack": ["martelo", "pinca"], "defense": []},
	{"id": "five_min", "attack": ["martelo"], "defense": ["muralha"]},
]

## Pontos de reserva (contrato §1) para quando a sim ainda não expõe o objeto/marcador. "<S>" = lado; z do sul = -z do norte.
const POINTS_N := {"gate_main": Vector3(0, 0, -30), "gate_side": Vector3(-38, 0, -40), "crystal": Vector3(0, 0, -48),
	"stair": Vector3(0, 0, -41), "spawn": Vector3(0, 0, -54), "front": Vector3(0, 0, -18)}
const HILL := Vector3.ZERO
const CASTLE_Z := 28.0          # |z| além disto (no lado do castelo) e |x| < CASTLE_HALF_X = dentro das muralhas
const CASTLE_HALF_X := 42.0

# ---------------------------------------------------------------------------
# FALAS (pt-BR). {plan} nome do plano, {me} quem fala, {p} jogador.

const PLAN_LINES := {
	"martelo": ["Plano Martelo: Muro no aríete, todo mundo no portão principal!", "Martelo! Empurra o aríete, Ponta limpa os canhões!",
		"Vamos de Martelo. Tudo no portão da frente!"],
	"pinca": ["Plano Pinça: aríete na frente, Batedores pela lateral!", "Pinça! Metade no portão, Batedores no portão lateral!",
		"Pinça. Eles não vão saber para onde olhar."],
	"bateria": ["Plano Bateria: primeiro o morro dos canhões!", "Bateria! Muro segura o morro, Artilharia nos canhões!",
		"Morro primeiro. Com os canhões, o portão cai sozinho."],
	"cerco_lento": ["Cerco Lento: ninguém se expõe, os canhões derrubam o portão.", "Calma, Cerco Lento. Canhões no portão, o resto protege.",
		"Cerco Lento. Paciência, eles quebram antes."],
	"muralha": ["Plano Muralha: todos em cima, ninguém sai!", "Muralha! Artilharia nos canhões, Muro no portão!",
		"Muralha. Segura o portão e deixa os canhões trabalharem."],
	"surtida": ["Surtida! Sai e queima os aríetes!", "Plano Surtida: Muro e Ponta para fora, nos aríetes!",
		"Surtida! Antes que o aríete chegue!"],
	"recuo": ["Recuo! Deixa o portão, todo mundo na escada!", "Plano Recuo: segura a escada do salão!",
		"Recua para a escada. Ali eles não passam."],
}

const TRIGGER_LINES := {
	"gate_broken": ["O portão caiu! Todos no Cristal!", "Portão no chão! Corre pro salão!", "Caiu! Pátio, escada, Cristal!"],
	"gate_broken_def": ["Perdemos o portão! Todos na escada!", "Portão caiu! Recua pro salão!"],
	"rams_lost": ["Perdemos os aríetes! Canhões no portão!", "Sem aríete. Vamos de canhão!"],
	"gate_low": ["Portão em 30%! Muro no aríete, Ponta nos canhões!", "O portão está cedendo! Agora, todo mundo!"],
	"gate_low_def": ["Portão em 30%! Segura a escada!", "O portão não aguenta mais! Plano B!"],
	"half_dead": ["Metade de nós caiu! Reagrupa!", "Muita gente no chão. Segura e espera o renascer!"],
	"hill_lost": ["Eles tomaram o morro! Tira eles de lá!", "Os canhões do morro são deles! Batedores, lá!"],
	"hill_won": ["Morro nosso! Agora o portão!", "Canhões do morro são nossos. Avança!"],
	"five_min": ["Cinco minutos! Tudo ou nada!", "Faltam cinco minutos! Tudo no portão!"],
	"five_min_def": ["Cinco minutos! Segura firme!", "Só mais cinco minutos, ninguém sai!"],
}

const ACK_LINES := ["entendido!", "bora!", "tô indo", "certo, comandante", "deixa comigo", "vamos nessa", "ok!", "na escuta"]

## Ordem do jogador repetida pelos bots (alguém responde).
const ORDER_ACKS := {
	"attack_gate_main": ["no portão!", "indo pro portão principal"], "attack_gate_side": ["lateral, indo!"],
	"take_hill": ["morro, certo"], "protect_ram": ["cobrindo o aríete"], "hold_stair": ["segurando a escada"],
	"sally": ["saindo!"], "retreat": ["recuando!"], "all_to_me": ["indo até você!", "tô chegando"], "cannons": ["nos canhões!"],
}

## "Ouvido do campo" (canal "war"): o plano do INIMIGO vaza em pistas.
const OVERHEARD := {
	"martelo": ["(do outro lado) \"tudo no portão da frente!\"", "(gritos) \"empurra o aríete!\""],
	"pinca": ["(do outro lado) \"eles estão vindo pela lateral!\"", "(gritos) \"batedores, portão lateral!\""],
	"bateria": ["(do outro lado) \"pega o morro!\"", "(gritos) \"canhões do morro, agora!\""],
	"cerco_lento": ["(do outro lado) \"ninguém avança, deixa os canhões\"", "(gritos) \"paciência, canhão no portão\""],
	"muralha": ["(da muralha) \"ninguém sai, segura em cima!\"", "(da muralha) \"canhões prontos!\""],
	"surtida": ["(da muralha) \"abre e sai, queima o aríete!\"", "(da muralha) \"surtida, agora!\""],
	"recuo": ["(do castelo) \"larga o portão, pra escada!\"", "(do castelo) \"todo mundo no salão!\""],
}

# ---------------------------------------------------------------------------

static func plans_for(attack: bool) -> Dictionary:
	return ATTACK_PLANS if attack else DEFENSE_PLANS

static func plan_ok(attack: bool, plan_id: String) -> bool:
	return plans_for(attack).has(plan_id)

static func plan_name(plan_id: String) -> String:
	var d: Dictionary = ATTACK_PLANS.get(plan_id, DEFENSE_PLANS.get(plan_id, {}))
	return str(d.get("name", plan_id))

static func weight(plan_id: String, personality: String) -> float:
	var w: Dictionary = Balance.GVG_AI_PLAN_WEIGHTS.get(plan_id, {})
	return float(w.get(personality, w.get("equilibrada", 1.0)))

## Plano sorteado entre `ids` pelo peso da personalidade; `roll` em [0, 1). Pura (testes e GvgBrain).
## Ex.: `GvgCatalog.pick(["martelo", "pinca"], "agressiva", 0.3)`.
static func pick(ids: Array, personality: String, roll: float) -> String:
	var total := 0.0
	for id in ids:
		total += weight(str(id), personality)
	if ids.is_empty() or total <= 0.0:
		return "" if ids.is_empty() else str(ids[0])
	var acc := 0.0
	var at := roll * total
	for id in ids:
		acc += weight(str(id), personality)
		if at < acc:
			return str(id)
	return str(ids.back())

## Plano do começo para o lado (atacante / defensor).
static func pick_start(attack: bool, personality: String, roll: float) -> String:
	return pick(plans_for(attack).keys(), personality, roll)

## Objetivo do papel no plano ou na ordem: {"goal", "alt"?, "at"?}.
static func role_goal(plan_id: String, role: String) -> Dictionary:
	var d: Dictionary = ATTACK_PLANS.get(plan_id, DEFENSE_PLANS.get(plan_id, {}))
	return (d.get("roles", {}) as Dictionary).get(role, {})

static func order_goal(order_id: String, role: String) -> Dictionary:
	var o: Dictionary = ORDERS.get(order_id, {})
	return o.get(role, o.get("*", {}))

## Ponto de reserva `key` do castelo do lado `side` ("N" | "S").
static func point(key: String, side: String) -> Vector3:
	if key in ["gate_main", "gate_side", "crystal", "spawn"]:
		return MapsCatalog.gvg_point(key + "_" + side)       # marcadores do mapa (JSON) ou as constantes do catálogo de mapas
	var p: Vector3 = POINTS_N.get(key, Vector3.ZERO)
	return p if side == "N" else Vector3(-p.x, 0.0, -p.z)
