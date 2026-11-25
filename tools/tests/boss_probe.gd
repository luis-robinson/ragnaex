extends Node
## Luta de bots contra chefes (calibrar números): para cada chefe, N lutas com um grupo de bots do nível do chefe.
##   godot --headless --path . tools/tests/boss_probe.tscn -- [--party=1,3] [--trials=12] [--boss=slime_king,...]
##     [--class=berserker] [--build=carniceiro]   (grupo só dessa classe/build; sem isso as classes se revezam)
##     [--lead=paladin:guardiao]   (o 1º do grupo é dessa classe/build, os outros se revezam; imprime aggro=% do tempo em que
##                                  o chefe mirou nele: tanque segurando o chefe no grupo)
##     [--kite[=ranger:cacador]]   (luta solo de um atirador que fica a 9,5 m+ do chefe: o chefe tem resposta de longe?)
##     [--comp=paladin:guardiao,bishop:sacerdote,...]   (grupo fixo, um classe:build por membro; o 1º é o líder; as métricas de
##                                  grupo contam como tanque o 1º com papel "tank" — líder dps = o jogador liderando, tanque bot seguindo)
##     [--dmg=X]                   (ATK/MATK do chefe × X; lacaios iguais: grupo sob pressão, mede cura e tanque)
##     [--under=N]                 (bots N níveis abaixo do chefe, com equipamento e skills do nível deles: luta de grupo apertada)
##     [--lvl=N]                   (bots no nível N, acima do MAX_LEVEL se preciso: ascensões 35+ antes da faixa existir)
##     [--asc_level]               (= --lvl=Balance.ASC_LEVEL: base para comparar com --asc)
##     [--asc[=classe,...]]        (bots dessas classes — todas sem valor — com a missão hx_asc_<classe> feita; equipamento e teias
##                                  de novo (normal e de ascensão). Nível mínimo ASC_LEVEL: compare com/sem no mesmo --lvl, razão F5)
##     [--asc_base=classe,...]     (bots dessas classes no nível ASC_LEVEL sem a missão: a base justa do F5 para --asc)
##     [--elem_stage=S]            (Elementalista ascendido começa com o elemental neste estágio: 1 = Maior)
##     [--tank_lock]               (a ameaça do tanque fica sempre TANK_LOCK × a do 2º: o chefe não vira e nenhum bot segura as skills
##                                  por ameaça (BOT_THREAT_HOLD). Mede a força da build sem o teto do tanque — sem isto, build que já
##                                  bate no teto não responde a +dano nenhum: a razão F5 dela sai ~1,00 por causa do tanque, não dela)
##     [--no_opener]               (desliga a abertura dos bots, BotBrain._opener: A/B)
##     [--no_unstuck]              (desliga largar alvo travado / teste de linha / dt no avanço dos bots: A/B)
##     [--hp=X]                    (vida do chefe × X: luta mais longa. Build que derruba o chefe em 20-30 s mede a abertura,
##                                  não o ritmo — recarga de 40 s usada uma vez pesa o dobro)
##     [--set=b4|b5|h4|h5|h5n|a4|a5] [--set_who=2,3] [--set_lv=40] [--pair=<build>]   (conjunto lendário nos membros --set_who (padrão:
##                                  todos): b = o da build, h = o híbrido (com --pair, o par com essa build; sem, o que o bot
##                                  escolhe, Sim.bot_legendary_set); 4/5 = peças; h5n = híbrido com o 5 peças normal da build no lugar
##                                  da Fusão. Orçamento F-FUS2: G_5n = T(b4)/T(b5) − 1, G_fus = T(h4)/T(h5) − 1, ref. T(h4)/T(h5n) − 1.
##                                  a4/a5 = Ápice da build (F-AP2: G_ap = T(a4)/T(a5) − 1; a4 = b4).
##                                  Imprime "FUS <membro> disparos/luta" (a Fusão disparou?))
##     [--set_weapon]              (com --set: veste também a arma do conjunto pelo papel da build e o escudo, Sim.bot_set_weapons;
##                                  "dano_tq" na linha PROBE = dano do chefe/lacaios no tanque por luta)
##     [--acc=leg] [--acc_who=2,3] (acessórios lendários da build nos membros --acc_who (padrão: todos), Sim.bot_legendary_accessories;
##                                  sem a flag = as joias comuns do bot, a referência. F-LA1: G_acc = T(sem)/T(leg) − 1)
##     [--dot_stats]               (linha DOT: % do dano no tanque que veio de dano no tempo, acúmulos máx. no tanque e no chefe por build)
##     [--seed=N]                  (semente da sim; padrão 1337. Rodadas com sementes diferentes somam lutas independentes)
##                                  Cada luta sorteia o grupo (classes distintas + build) e ressemeia a sim por (chefe, luta, semente)
##                                  (random_comp/fight_seed): o mesmo chefe dá o mesmo grupo e a mesma luta sozinho ou no meio de outros.
##     [--old_gear]                (equipamento de bot de antes de 2026-11-23: WorldSim.bot_gear_legacy, A/B do C5)
##     [--rotation]                (classes pelo rodízio antigo, build do mesmo jeito: A/B do sorteio)
##     [--comp_stats]              (não luta: imprime COMPSTAT baralho/livre/rodízio — vezes por classe, lutas com tanque/cura)
##     [--show_comp]               (imprime o grupo de cada luta: COMP <chefe> #<luta> classe:build,...)
##     [--bands]                   (solo + trio + kite por chefe e compara com BANDS; imprime BAND/OUT e OUT_OF_BAND no fim)
## "perdas" (com --lead/--comp) = vezes por luta em que o chefe largou o tanque vivo por outro membro; "freio" também sai no fim da linha PROBE.
## "freio" (na linha TIME) = parte do tempo dos membros que não são o tanque acima de BOT_THREAT_HOLD × a ameaça dele (só básico).
## Com --asc / --lvl sai também "TIME <chefe> grupo=N n=V med=Ss media=Ss dp=Ss ep=Ss todas=Ss freio=F%": mediana, média, desvio-padrão e
##   erro-padrão do tempo das vitórias, e a média de TODAS as lutas (derrota conta o tempo que durou, até LIMIT). A razão F5 é
##   tempo sem ÷ com a ascensão; o ruído dela ≈ raiz(ep_sem² + ep_com²) ÷ média.
##   "DPS" soma em "<membro>+inv" o dano das invocações de cada membro no chefe (matilha, torreta, elemental);
##   com --why, "INV" conta quantas invocações de bot morreram por luta antes do prazo.
##   com --why, cada "PERDA" (chefe largou o tanque) traz o golpe [tipo estado skill] e "decisao": o último lance do membro
##   (skill/fase, t, distância alvo-chefe, aggro/ameaça do tanque, a minha, a prevista, abertura). Assim achou-se o dash da fuga.
##     [--no_sig]                  (sem a assinatura do chefe: base para comparar; GDD act2-boss-signatures)
##     [--sig_tune=<skill>:power=X,cooldown=Y,radius=Z,time=T]   (botões da assinatura só nesta rodada: varrer sem editar o Balance)
## "SIG <chefe>": assinaturas por uso (maré atingidos, marca em aliados, canal quebrado/completo, avalanche atingidos, fúria
##   média da Muralha, contragolpe, botes cortados, dividir_n = quantos dentro do Machado do Trono, dividir_mortes) — métricas do AC-S5.
## Saída: "PROBE <chefe> grupo=N vitorias=V/T tempo_medio=Ss mortes=M cast/min=C act=A% adds=N off=O% longe/min=F"
##   cast/min = skills do chefe por minuto; act = parte da luta golpeando/lançando (o resto é andando);
##   adds = lacaios por luta; off = dano do chefe e dos lacaios fora do alvo do chefe; longe/min = skills do chefe miradas
##   a 9 m+ dele (gancho, investida, chuva, tiro; o bot pode desviar: mede a pressão em quem luta de longe).
##   Com --lead/--comp, métricas de grupo: area = parte do dano do chefe que dava para desviar (golpe de área, círculo,
##   poça, projétil no ar); cura_tq = parte da cura do grupo que foi no líder (tanque); baixa = s por luta em que alguém
##   que não é o líder ficou abaixo de 35% de vida; frente = parte do dano que veio de golpe do chefe SEM mira de
##   propósito (mob_pick vazio) em quem não é o líder: quem estava no lugar errado (a IA de grupo tenta zerar);
##   baixa_tq = o mesmo para o tanque; pocoes = poções de vida bebidas por luta (grupo todo);
##   ritmo = parte da luta em que os outros membros estavam golpeando/lançando (o resto é andando ou parado).

const BOSSES := {"bandit_chief": "field_forest", "crab_king": "field_crab_beach", "bear_mother": "field_hollow", "boss_archdruid": "field_grove", "slime_king": "dg_gruta", "spider_queen": "dg_ninho", "crypt_lord": "dg_cripta",
	"bone_captain": "dg_catacumbas", "wailing_widow": "dg_catacumbas", "count_vargo": "dg_catacumbas_trono",
	"boar_brute": "city_aldara", "boar_king": "city_aldara", "elf_king": "dg_coracao", "elf_warden": "elf_city", "trent": "elf_city",
	"golem_ancient": "dg_pedreira", "crystal_warden": "dg_pedreira", "quarry_heart": "dg_pedreira_coracao",
	"elf_captain_hunter": "elf_city", "elf_captain_sky": "elf_city", "elf_captain_sap": "elf_city",
	"ghoul_giant": "fort_ghoul", "death_knight": "fort_bones", "frost_mage": "fort_frost", "lich_king": "lich_citadel",
	"dragonling": "dg_covil_dragao",
	# Ato II (30-35): a sala de verdade (field_coast, dg_goblin) vem do pacote das zonas; até lá lutam nas Ruínas
	"boss_tide_mother": "field_coast", "boss_agitator_lord": "dg_goblin",
	"boss_troll_king": "fort_trolls", "boss_crossbow_master": "fort_fire", "boss_ghar": "fort_war",
	# Kharzun (40-45): arenas de verdade (Canil no campo, Salão dos Matadores, alas e trono da cidadela). O spawner do Durgash
	# tem `if` (os três clãs): a sonda o põe direto no lugar do spawner, sem a condição.
	"boss_dire_mother": "field_kharzun", "boss_shazka": "dg_slayers", "boss_ulgra": "kharzun_citadel", "boss_gorbash": "kharzun_citadel",
	"boss_kragmar": "kharzun_citadel", "boss_durgash": "kharzun_citadel",
	# Ato III, chefes de mundo (afinados para trio: faixa "group")
	"boss_vindima": "field_perfume", "boss_prima_donna": "field_parade",
	# Ato III, chefes das masmorras (WP8b; grupo de 4)
	"boss_varo": "dg_cellars", "boss_countess": "dg_mirrors", "boss_ressoa": "dg_conservatory",
	# Ato III, chefe da história (grupo de 4) e raide (5)
	"vessaline": "rift_garden", "boss_sylvare_echo": "rift_heart",
	# Brejo das Teias (12-16): Ponta da Bocarra
	"bog_mother": "field_marsh",
	# Viveiro de Seiva (17-19): O Berço
	"boss_sap_mother": "dg_viveiro"}
## Chefe sem spawner no mapa da sonda luta no lugar deste (arena provisória). Vazio: todos têm a sala deles.
const ARENA_AT := {}
## field = chefe de campo (dá para solar); elite = monstro forte de missão (sem fases); group = conteúdo de grupo.
const GROUPS := {"crab_king": "field", "bear_mother": "field", "boar_brute": "field", "boar_king": "field", "slime_king": "field",
	"trent": "elite", "elf_warden": "elite"}          # o resto: group
## Faixas que o chefe precisa cumprir (`--bands`). win = fração de vitórias; time = s de luta do trio; o resto são pisos.
## kite_far: skills miradas a 9 m+ por minuto contra um atirador que kita; passa também se o atirador perde a maioria.
const BANDS := {
	"field": {"solo_win": [0.6, 1.0], "trio_win": [0.9, 1.0], "kite_far": 0.0},     # chefe inicial: kitar é tática válida
	"elite": {"solo_win": [0.6, 1.0], "trio_win": [0.9, 1.0], "kite_far": 2.0},
	"group": {"solo_win": [0.2, 0.4], "trio_win": [0.75, 1.0], "trio_time": [30.0, 150.0], "casts": 4.0, "act": 35.0, "adds": 4.0, "off": 10.0, "kite_far": 2.0},
}
const LIMIT := 300.0          # s por luta
const DT := 1.0 / 20.0
const KITE_MIN := 9.5
const TANK_LOCK := 3.0        # --tank_lock: ameaça do tanque ÷ a maior dos outros
var _force_class := ""
var _force_build := ""
var _lead := ""
var _kite := ""
var _why := false
var _dot_stats := false
var _comp: Array = []
var _under := 0
var _dmg := 1.0
var _lvl := 0
var _asc: Array = []
var _asc_on := false
var _ult_trace := false           # --ult_trace: carga de cada membro a cada 5 s
var _ult_off := false             # --ult_off: ninguém solta a Suprema (braço de controle da razão de força, GDD §4)
var _ult_who: Array = []          # --ult_who=2,3: só esses membros (índice no grupo, 0 = líder) soltam a Suprema; os outros travados (razão de UMA build)
var _ult := false                 # --ult: tempo até a 1ª Carga Suprema cheia por membro (GDD ultimates-lv40 §8; use com --lvl=40 --asc)
var _asc_base: Array = []
var _elem_stage := 0
var _tank_lock := false
var _hp := 1.0
var _berserk: Array = []
var _set := ""
var _set_who: Array = []
var _acc := ""
var _acc_who: Array = []
var _set_lv := 0
var _set_weapon := false
var _pair := ""
var _fus_fired := {}
var _seed := 1337             # --seed (a sim nasce com 1337)
var _show_comp := false
var _rotation := false         # --rotation: classes pelo rodízio antigo (A/B contra o baralho)

## Grupo sorteado de uma luta: `party` classes distintas (fora `exclude`) com uma build cada, ["classe:build", ...].
## Só depende de (chefe, luta, semente): rodar o chefe sozinho ou numa lista dá o mesmo grupo (antes as classes se revezavam
## pela ordem dos chefes e o build saía do rng da sim, que vinha das lutas anteriores: Rei Élfico 75% numa lista, 52,5% noutra).
## Baralho: as classes saem de baralhos embaralhados (um atrás do outro, `party` cartas por luta), então nas lutas 0..T-1 cada
## classe aparece T×party/n vezes ±1 (como o rodízio antigo); carta repetida na virada do baralho troca com uma mais adiante
## do mesmo baralho. A build de cada classe sai de um baralho próprio das builds dela (cada build na sua vez, ±1).
static func random_comp(bid: String, trial: int, run_seed: int, party: int, exclude: Array = []) -> Array:
	var pool: Array = GameData.classes.keys().filter(func(c): return not (c in exclude))
	pool.sort()                    # ordem fixa (não depende da ordem do dicionário)
	var n := pool.size()
	var hands: Array = []           # mãos das lutas 0..trial (refeitas do zero: só dependem de chefe/semente)
	var deck: Array = []
	var deck_i := 0
	var at := 0
	for t in range(trial + 1):
		var hand: Array = []
		while hand.size() < mini(party, n):
			if at >= deck.size():
				deck = _shuffled(pool, "deck|%s|%d|%d" % [bid, deck_i, run_seed])
				deck_i += 1
				at = 0
			if deck[at] in hand:       # virada do baralho: troca com a 1ª carta adiante que não está na mão
				for j in range(at + 1, deck.size()):
					if not (deck[j] in hand):
						var tmp: String = deck[at]
						deck[at] = deck[j]
						deck[j] = tmp
						break
			hand.append(deck[at])
			at += 1
		hands.append(hand)
	var seen := {}                  # vez de cada classe -> carta do baralho de builds dela
	var out: Array = []
	for t in range(hands.size()):
		for cid in hands[t]:
			var k: int = int(seen.get(cid, 0))
			seen[cid] = k + 1
			if t == trial:
				var ids: Array = GameData.classes[cid].builds.map(func(b): return str(b["id"]))
				var bd := ""
				if not ids.is_empty():
					bd = str(_shuffled(ids, "build|%s|%s|%d|%d" % [bid, cid, k / ids.size(), run_seed])[k % ids.size()])
				out.append("%s:%s" % [cid, bd])
	return out

## Cópia de `items` embaralhada só pela chave (Fisher-Yates com rng próprio).
static func _shuffled(items: Array, key: String) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = hash(key)
	var a: Array = items.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := r.randi() % (i + 1)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp
	return a

## Sorteio livre da versão anterior (classes e build ao acaso por luta). Só para comparar cobertura (--comp_stats).
static func free_comp(bid: String, trial: int, run_seed: int, party: int, exclude: Array = []) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = hash("comp|%s|%d|%d" % [bid, trial, run_seed])
	var pool: Array = GameData.classes.keys().filter(func(c): return not (c in exclude))
	pool.sort()
	var out: Array = []
	for i in range(party):
		if pool.is_empty():
			break
		var cid: String = pool.pop_at(r.randi() % pool.size())
		var builds: Array = GameData.classes[cid].builds
		out.append("%s:%s" % [cid, str(builds[r.randi() % builds.size()]["id"]) if builds.size() > 0 else ""])
	return out

## Rodízio antigo (até 2026-11-11) das classes: classes[(luta×3 + i×5) % n] na ordem do catálogo; a build vem do baralho de
## builds (o antigo a tirava do rng da sim). `--rotation` usa este na luta (A/B contra o baralho); --comp_stats compara.
static func rotation_comp(bid: String, trial: int, run_seed: int, party: int, exclude: Array = []) -> Array:
	var classes: Array = GameData.classes.keys()
	var out: Array = []
	for i in range(party + exclude.size()):
		if out.size() >= party:
			break
		var cid: String = classes[(trial * 3 + i * 5) % classes.size()]
		if cid in exclude or out.any(func(c): return str(c).begins_with(cid + ":")):
			continue
		var ids: Array = GameData.classes[cid].builds.map(func(b): return str(b["id"]))
		var r := RandomNumberGenerator.new()
		r.seed = hash("rot|%s|%s|%d|%d" % [bid, cid, trial, run_seed])
		out.append("%s:%s" % [cid, str(ids[r.randi() % ids.size()]) if not ids.is_empty() else ""])
	return out

## Cobertura de um sorteador nas lutas 0..trials-1: vezes por classe, % com tanque, com cura, com os dois (papel da build).
static func comp_stats(kind: String, bid: String, trials: int, run_seed: int, party: int, exclude: Array = []) -> Dictionary:
	var per := {}
	var tank := 0
	var heal := 0
	var both := 0
	for t in range(trials):
		var c: Array = random_comp(bid, t, run_seed, party, exclude) if kind == "deck" else (free_comp(bid, t, run_seed, party, exclude) if kind == "free" else rotation_comp(bid, t, run_seed, party, exclude))
		var roles := {}
		for s in c:
			var cid: String = str(s).get_slice(":", 0)
			per[cid] = int(per.get(cid, 0)) + 1
			roles[str(GameData.classes[cid].build_by_id(str(s).get_slice(":", 1)).get("role", "dps"))] = true
		tank += 1 if roles.has("tank") else 0
		heal += 1 if roles.has("healer") else 0
		both += 1 if roles.has("tank") and roles.has("healer") else 0
	return {"per": per, "tank": tank, "heal": heal, "both": both}

## Semente da sim para uma luta (mesma regra: só depende de chefe, luta e semente).
static func fight_seed(bid: String, trial: int, run_seed: int) -> int:
	return hash("fight|%s|%d|%d" % [bid, trial, run_seed])

## Bot da sonda: veio pelo chefe. Não planeja viagem de caça nem volta à cidade no meio da luta (a sala do chefe não é mapa de caça, e o
## líder levava o grupo embora: contava como derrota).
class StayBrain extends BotBrain:
	var boss_id := -1
	## Chefe sem alvo (resetou) e o bot longe, sem nada para caçar: volta até o chefe (antes ficavam a 30 m, fora do aggro, até o fim).
	func think(e: SimEntity, sim, m: Dictionary, dt: float) -> InputCommand:
		var cmd: InputCommand = super.think(e, sim, m, dt)
		var b: SimEntity = sim.entities.get(boss_id)
		if b and b.is_alive() and b.aggro_target < 0 and hunt_target_id < 0 and e.can_act():
			var to := b.position - e.position
			to.y = 0.0
			if to.length() > 8.0:
				cmd.move = Vector2(to.x, to.z).normalized()
		return cmd
	func _plan_trip(_e: SimEntity, _sim) -> void:
		state = S.HUNT
		timer = 5.0
	func _go_home(_e: SimEntity, _sim) -> void:               # nem volta à cidade para reabastecer com o chefe vivo
		state = S.HUNT
		timer = 5.0

## Atirador que não deixa o chefe chegar perto: pensa como bot e, com o chefe a menos de KITE_MIN, anda para longe.
class KiteBrain extends StayBrain:
	func think(e: SimEntity, sim, m: Dictionary, dt: float) -> InputCommand:
		var cmd: InputCommand = super.think(e, sim, m, dt)
		var b: SimEntity = sim.entities.get(boss_id)
		if b and b.is_alive() and e.can_act():
			var away := e.position - b.position
			away.y = 0.0
			if away.length() < KITE_MIN and away.length() > 0.01:
				cmd.move = Vector2(away.x, away.z).normalized()
		return cmd

func _ready() -> void:
	await get_tree().process_frame
	WorldSim.bot_gear_legacy = DevArgs.has("--old_gear")
	Sim.load_map(GameData.maps[GameData.town_map_id()])      # bot que morre renasce na cidade
	var parties := [1, 3]
	var trials := 12
	var only: Array = []
	var bands := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--party="): parties = Array(a.get_slice("=", 1).split(",")).map(func(x): return int(x))
		if a.begins_with("--trials="): trials = int(a.get_slice("=", 1))
		if a.begins_with("--seed="):       # a sim nasce com semente fixa: rodadas em pedaços precisam de sementes diferentes
			_seed = int(a.get_slice("=", 1))
			Sim.rng.seed = _seed
		if a == "--show_comp": _show_comp = true
		if a == "--rotation": _rotation = true
		if a == "--no_cc_dr": CcDrSystem.enabled = false      # C7: sem retorno decrescente de controle (comparar)
		if a.begins_with("--boss="): only = Array(a.get_slice("=", 1).split(","))
		if a.begins_with("--class="): _force_class = a.get_slice("=", 1)
		if a.begins_with("--build="): _force_build = a.get_slice("=", 1)
		if a.begins_with("--lead="): _lead = a.get_slice("=", 1)
		if a == "--kite": _kite = "ranger:cacador"
		if a.begins_with("--kite="): _kite = a.get_slice("=", 1)
		if a == "--bands": bands = true
		if a.begins_with("--comp="): _comp = Array(a.get_slice("=", 1).split(","))
		if a.begins_with("--under="): _under = int(a.get_slice("=", 1))
		if a.begins_with("--dmg="): _dmg = float(a.get_slice("=", 1))
		if a.begins_with("--lvl="): _lvl = int(a.get_slice("=", 1))
		if a == "--asc_level" and _lvl <= 0: _lvl = Balance.ASC_LEVEL
		if a == "--asc": _asc_on = true
		if a == "--ult": _ult = true
		if a == "--ult_off": _ult_off = true
		if a.begins_with("--ult_who="): _ult_who = Array(a.get_slice("=", 1).split(",")).map(func(x): return int(x))
		if a == "--ult_trace": _ult_trace = true
		if a.begins_with("--asc="):
			_asc_on = true
			_asc = Array(a.get_slice("=", 1).split(","))
		if a.begins_with("--asc_base="): _asc_base = Array(a.get_slice("=", 1).split(","))
		if a.begins_with("--elem_stage="): _elem_stage = int(a.get_slice("=", 1))
		if a == "--tank_lock": _tank_lock = true
		if a == "--no_opener": BotBrain.opener_enabled = false     # A/B da abertura (BotBrain._opener)
		if a == "--no_unstuck": BotBrain.unstuck_enabled = false   # A/B dos bots presos (BotBrain._stalled/_pick_monster)
		if a.begins_with("--hp="): _hp = float(a.get_slice("=", 1))
		if a.begins_with("--berserk="):     # --berserk=<s>,<mult>: berserk_after e berserk_mult do chefe (calibrar a raide)
			_berserk = Array(a.get_slice("=", 1).split(",")).map(func(x): return float(x))
		if a.begins_with("--set="): _set = a.get_slice("=", 1)
		if a.begins_with("--set_who="): _set_who = Array(a.get_slice("=", 1).split(",")).map(func(x): return int(x))
		if a.begins_with("--set_lv="): _set_lv = int(a.get_slice("=", 1))
		if a.begins_with("--l50_off="): PieceEffects.set_off(a.get_slice("=", 1))     # Lendários do 50: peças sem efeito (all | head,gloves,...)
		if a == "--set_weapon": _set_weapon = true
		if a.begins_with("--acc="): _acc = a.get_slice("=", 1)
		if a.begins_with("--acc_who="): _acc_who = Array(a.get_slice("=", 1).split(",")).map(func(x): return int(x))
		if a.begins_with("--pair="): _pair = a.get_slice("=", 1)
		if a == "--dot_stats": _dot_stats = true      # linha DOT: dano no tempo no tanque e acúmulos (tanque e chefe)
		if a == "--why": _why = true          # imprime de onde veio o dano que o grupo levou
		if a.begins_with("--sig_tune="):    # --sig_tune=<skill>:power=X,cooldown=Y,radius=Z,time=T (marca): varrer botões de assinatura sem editar o Balance
			var sk: SkillDef = GameData.skills[a.get_slice("=", 1).get_slice(":", 0)]
			for kv in a.substr(a.find(":") + 1).split(","):
				var k := kv.get_slice("=", 0)
				var val := float(kv.get_slice("=", 1))
				if k in ["power", "cooldown"]:
					sk.set(k, val)
				elif sk.effects.get("mark") is Dictionary:
					sk.effects["mark"][k] = val
			print("SIG_TUNE %s power=%.2f cooldown=%.0f mark=%s" % [sk.id, sk.power, sk.cooldown, str(sk.effects.get("mark", {}))])
	if OS.get_cmdline_user_args().has("--comp_stats"):      # só o sorteio, sem luta: cobertura de cada sorteador
		for bid in BOSSES:
			if only.is_empty() or bid in only:
				for kind in ["deck", "free", "rotation"]:
					var st := comp_stats(kind, bid, trials, _seed, parties[0])
					print("COMPSTAT %s %s s%d n=%d tanque=%d cura=%d ambos=%d classes=%s" % [kind, bid, _seed, trials, st["tank"], st["heal"], st["both"], str(st["per"])])
		print("PROBE_END")
		get_tree().quit()
		return
	var out_of_band: Array = []
	for bid in BOSSES:
		if not (only.is_empty() or bid in only):
			continue
		if bands:
			var why := _band(bid, trials)
			if why.is_empty():
				print("BAND %-18s %s OK" % [bid, GROUPS.get(bid, "group")])
			else:
				print("OUT  %-18s %s %s" % [bid, GROUPS.get(bid, "group"), " ".join(why)])
				out_of_band.append(bid)
			continue
		for n in parties:
			var r := _run(bid, BOSSES[bid], n, trials, _kite)
			_print(bid, n, trials, r)
	if bands:
		print("OUT_OF_BAND: %s" % ",".join(out_of_band))
	for k in _fus_fired:
		print("FUS %s %s" % [k, str(_fus_fired[k])])
	print("PROBE_END")
	get_tree().quit()

func _print(bid: String, n: int, trials: int, r: Dictionary) -> void:
	if _ult and r.has("ult"):
		var parts: Array = []
		for k in r["ult"]:
			var u: Dictionary = r["ult"][k]
			var ts: Array = u["t"]
			ts.sort()
			var med: float = float(ts[ts.size() / 2]) if not ts.is_empty() else -1.0
			var rs: Array = u["rate"]
			var rate := 0.0
			for x in rs:
				rate += float(x) / maxf(1.0, rs.size())
			var ls: Array = u["luta"]
			ls.sort()
			var lmed: float = float(ls[ls.size() / 2]) if not ls.is_empty() else -1.0
			parts.append("%s(%s%s)=%.1fs luta=%.1fs n=%d sem=%d pts/s=%.2f(=%.0fs)" % [k, u["role"], "" if u["ok"] else ",TRAVADA", med, lmed, ts.size(), int(u["miss"]), rate, Balance.ULT_MAX / maxf(0.01, rate)])
		print("ULT %s %s" % [bid, " ".join(parts)])
	if _asc_on or _lvl > 0:
		var dps: Array = []
		var dl: Dictionary = r.get("dealt", {})
		var keys: Array = dl.keys()
		keys.sort()
		for k in keys:
			dps.append("%s=%.1f" % [k, float(dl[k]) / maxf(1.0, float(r.get("fight_t", 1.0)))])
		print("DPS %s %s" % [bid, " ".join(dps)])
		# ULTDMG: parte do dano de cada build no chefe que veio da Suprema dela (SimEntity.ult_dealt) e quantas saíram por luta
		var ud: Dictionary = r.get("ult_dmg", {})
		var uc: Dictionary = r.get("ult_casts", {})
		var all_by: Dictionary = {}
		for k in keys:
			if not str(k).ends_with("+inv"):
				var k0: String = str(k).get_slice("#", 0)
				all_by[k0] = float(all_by.get(k0, 0.0)) + float(dl[k])
		var ups: Array = []
		for k0 in all_by:
			if uc.has(k0) or ud.has(k0):
				ups.append("%s=%.1f%%(%.0f/%.0f,suprema/luta=%.2f)" % [k0, 100.0 * float(ud.get(k0, 0.0)) / maxf(1.0, float(all_by[k0])), float(ud.get(k0, 0.0)), float(all_by[k0]), float(uc.get(k0, 0)) / maxf(1.0, trials)])
		if not ups.is_empty():
			print("ULTDMG %s %s" % [bid, " ".join(ups)])
	if _asc_on:
		var parts: Array = []
		for sid in r.get("asc", {}):
			parts.append("%s=%.1f" % [sid, float(r["asc"][sid]) / trials])
		print("ASC %s usos/luta: %s" % [bid, ", ".join(parts) if not parts.is_empty() else "nenhum"])
	if _asc_on or _lvl > 0:
		var ts: Array = r.get("times", [])
		var nt := ts.size()
		var mean := 0.0
		for x in ts:
			mean += float(x) / maxf(1.0, nt)
		var sd := 0.0
		for x in ts:
			sd += (float(x) - mean) * (float(x) - mean)
		sd = sqrt(sd / maxf(1.0, nt - 1))
		var sorted: Array = ts.duplicate()
		sorted.sort()
		var med: float = 0.0 if nt == 0 else (float(sorted[nt / 2]) if nt % 2 == 1 else (float(sorted[nt / 2 - 1]) + float(sorted[nt / 2])) * 0.5)
		print("TIME %s grupo=%d n=%d med=%.1fs media=%.1fs dp=%.1fs ep=%.2fs todas=%.1fs freio=%.0f%%" % [bid, n, nt, med, mean, sd, sd / sqrt(maxf(1.0, nt)), float(r.get("fight_t", 0.0)) / maxf(1.0, trials), float(r.get("hold", 0.0))])
	if _why and (_asc_on or _lvl > 0):
		print("INV %s invocacoes de bot mortas/luta=%.1f" % [bid, float(r.get("inv_dead", 0)) / maxf(1.0, trials)])
	var sg: Dictionary = r.get("sig", {})
	if not sg.is_empty():                       # assinaturas (AC-S5): por luta e por uso
		var per := func(k: String, by: String) -> String: return "%.2f" % (float(sg.get(k, 0.0)) / maxf(1.0, float(sg.get(by, 0.0))))
		print("SIG %s grupo=%d usos/luta=%s maré_atingidos/uso=%s marca_aliados/marca=%s canal_quebrado=%s canal_completo=%s avalanche_atingidos/uso=%s furia_med=%s contragolpe/uso=%s botes_cortados=%s faixas=%.1f faixas/estouro=%s aneis/serie=%s copias_s/uso=%s copias_mortas/uso=%s tempera_med=%s tempera_cura/luta=%.0f na_poca=%s dividir_n/marca=%s dividir_mortes/marca=%s bruto=%s" % [
			bid, n, "%.1f" % ((float(sg.get("islands", 0)) + float(sg.get("marks", 0)) + float(sg.get("channels", 0)) + float(sg.get("avalanches", 0)) + float(sg.get("walls", 0)) + float(sg.get("seqs", 0)) + float(sg.get("stampedes", 0)) + float(sg.get("ring_series", 0)) + float(sg.get("twins", 0)) + float(sg.get("temper_uses", 0))) / maxf(1.0, trials)),
			per.call("islands_hit", "islands"), per.call("mark_ally_hits", "marks"), per.call("channel_breaks", "channels"), per.call("channel_done", "channels"),
			per.call("avalanche_hits", "avalanches"), per.call("wall_fury", "walls"), per.call("counter_hits", "walls"), per.call("seq_cut", "seqs"),
			float(sg.get("line_hits", 0)) / maxf(1.0, trials), per.call("line_hits", "stampedes"), per.call("ring_hits", "ring_series"), per.call("decoy_life", "twins"), per.call("decoy_kills", "twins"),
			per.call("temper_sum", "temper_time"), float(sg.get("temper_heal", 0)) / maxf(1.0, trials), per.call("pool_time", "temper_time"), per.call("soak_n", "marks"), per.call("soak_kills", "marks"), str(sg)])
	print("PROBE %-18s grupo=%d%s vitorias=%d/%d tempo_medio=%.1fs mortes=%.1f cast/min=%.1f act=%.0f%% adds=%.1f off=%.0f%% longe/min=%.1f%s" % [
		bid, n, (" kite" if r["kite"] else ""), r["wins"], trials, r["time"], r["deaths"], r["casts"], r["act"], r["adds"], r["off"], r["far"],
		("" if _lead == "" and _comp.is_empty() else " aggro=%.0f%% area=%.0f%% cura_tq=%.0f%% baixa=%.1fs frente=%.0f%% ritmo=%.0f%% baixa_tq=%.1fs pocoes=%.1f perdas=%.2f freio=%.0f%% dano_tq=%.0f" % [r["aggro"], r["area"], r["heal_tank"], r["low"], r["stray"], r["busy"], r["low_tank"], r["pots"], r["drops"], r["hold"], r["tank_dmg"]])])

## Solo, trio e kite contra as faixas do grupo do chefe. Devolve os motivos de estar fora (vazio = dentro).
func _band(bid: String, trials: int) -> Array:
	var b: Dictionary = BANDS[GROUPS.get(bid, "group")]
	var solo := _run(bid, BOSSES[bid], 1, trials, "")
	var trio := _run(bid, BOSSES[bid], 3, trials, "")
	var kite := _run(bid, BOSSES[bid], 1, maxi(4, trials / 3), "ranger:cacador")
	_print(bid, 1, trials, solo)
	_print(bid, 3, trials, trio)
	_print(bid, 1, maxi(4, trials / 3), kite)
	var why: Array = []
	var sw := float(solo["wins"]) / trials
	var tw := float(trio["wins"]) / trials
	if sw < b["solo_win"][0] or sw > b["solo_win"][1]:
		why.append("solo=%.0f%%(%.0f-%.0f)" % [sw * 100, b["solo_win"][0] * 100, b["solo_win"][1] * 100])
	if tw < b["trio_win"][0] or tw > b["trio_win"][1]:
		why.append("trio=%.0f%%(%.0f-%.0f)" % [tw * 100, b["trio_win"][0] * 100, b["trio_win"][1] * 100])
	if b.has("trio_time") and trio["wins"] > 0 and (trio["time"] < b["trio_time"][0] or trio["time"] > b["trio_time"][1]):
		why.append("tempo=%.0fs(%.0f-%.0f)" % [trio["time"], b["trio_time"][0], b["trio_time"][1]])
	for k in ["casts", "act", "adds", "off"]:
		if b.has(k) and trio[k] < float(b[k]):
			why.append("%s=%.1f(>=%s)" % [k, trio[k], b[k]])
	# ou o chefe mata quem kita, ou a luta é curta demais para medir (elite de 3 mil de vida cai em 8 s)
	if kite["far"] < float(b["kite_far"]) and float(kite["wins"]) / maxi(4, trials / 3) > 0.5 and kite["time"] >= 15.0:
		why.append("longe=%.1f(>=%s)" % [kite["far"], b["kite_far"]])
	return why

func _run(bid: String, mid: String, party: int, trials: int, kite: String) -> Dictionary:
	var base: MonsterDef = GameData.monsters[bid]
	if _dmg != 1.0:                 # chefe batendo mais forte (só ele; lacaios iguais): testar cura/tanque sob pressão
		base = base.duplicate()
		base.atk *= _dmg
		base.matk *= _dmg
	if _hp != 1.0:                  # chefe com mais vida (só ele): luta mais longa
		if base == GameData.monsters[bid]:
			base = base.duplicate()
		base.hp *= _hp
	if not _berserk.is_empty():
		if base == GameData.monsters[bid]:
			base = base.duplicate()
		base.berserk_after = float(_berserk[0])
		if _berserk.size() > 1:
			base.berserk_mult = float(_berserk[1])
	if OS.get_cmdline_user_args().has("--no_sig"):     # sem a assinatura (GDD act2-boss-signatures): base para comparar
		base = base.duplicate()
		base.skill_ids = Array(base.skill_ids).filter(func(id): return not (GameData.skills.has(id) and GameData.skills[id].boss_signature)) as Array[String]
		var phs: Array = []
		for ph in base.phases:
			var c: Dictionary = (ph as Dictionary).duplicate(true)
			c["skills"] = (c.get("skills", []) as Array).filter(func(id): return not (GameData.skills.has(id) and GameData.skills[id].boss_signature))
			phs.append(c)
		base.phases = phs
		base.cover = {}
	Sim.sig_stats.clear()
	var m: Dictionary = Sim.load_map(GameData.maps[mid])
	m["spawners"].clear()
	for ri in RaidSystem.routes(m["def"]).size():
		RaidSystem.state(m, ri)["timer"] = INF       # investidas paradas (Bastião): os bots largavam o chefe para defender o portão
	RaidSystem.sync_state(m)["timer"] = INF          # Bastião: relógio único dos três lados
	var at := Vector3.ZERO
	for sp in m["def"].spawners:
		if sp["monster_id"] == bid or (sp["monster_id"] == ARENA_AT.get(bid, "") and at == Vector3.ZERO):
			at = sp["pos"]
	var wins := 0
	var times: Array = []
	var inv_dead := 0
	var buff_t := {}
	var hold_sum := 0.0
	var drops := 0                 # vezes em que o chefe largou o tanque vivo por outro membro (perdas de aggro)
	var t_sum := 0.0
	var deaths := 0
	var agg_sum := 0.0
	var fight_sum := 0.0
	var act_sum := 0.0
	var adds_sum := 0
	var low_sum := 0.0
	var busy_sum := 0.0
	var low_tank := 0.0
	var ward_n := 0                # lutas em que o ward ligou (lacaio de escudo vivo)
	var ward_sum := 0.0            # s do ward ligar até o 1º lacaio dele cair
	var ward_fast := 0             # ... em até 30 s (KAC-11: estandarte antes de 30 s)
	var acc := {"pots": 0, "stray": 0.0, "area": 0.0, "heal": 0.0, "heal_tank": 0.0, "lead": -1, "casts": 0, "dmg": 0.0, "off": 0.0, "far": 0, "boss": -1, "bots": {}, "from": Vector3.ZERO, "why": {}, "why_t": {}, "states": {}, "asc": {}, "dealt": {}, "ult_dmg": {}, "ult_seen": {}, "ult_casts": {}, "drop_by": {}, "last_hit": {}, "drop_how": {}, "decide": {}, "dot": {"tank": 0.0, "tank_dot": 0.0, "tank_dot_hits": 0, "tank_max": 0, "boss_by": {}, "boss_dot_by": {}, "boss_max": 0, "boss_max_by": {}}}
	var on_cast := func(id: int, sid: String, ph: String):
		if _why and acc["bots"].has(id) and Sim.entities.has(acc["boss"]):     # último lance de cada membro (PERDA: "decisao")
			var be: SimEntity = Sim.entities[id]
			if be.brain is BotBrain:
				var bb: SimEntity = Sim.entities[acc["boss"]]
				var br: BotBrain = be.brain
				var tg: SimEntity = Sim.entities.get(br.hunt_target_id)
				acc["decide"][id] = sid + "/" + ph + " t=%.2f alvo_chefe_d=%.1f aggro_tq=%s tq=%.0f eu=%.0f est=%.0f abre=%s visto=%.2f preso=%.2f d=%.2f" % [Sim.time - float(acc.get("t0", 0.0)),
					-1.0 if tg == null else tg.position.distance_to(bb.position), str(bb.aggro_target == acc["lead"]), float(bb.threat.get(acc["lead"], 0.0)),
					float(bb.threat.get(id, 0.0)), BotBrain._skill_threat(be, be.basic_skill, bb, true) + BotBrain._signature_threat(be, Sim, bb),
					str(br.opener_id == bb.id), br.opener_seen - float(acc.get("t0", 0.0)), br.opener_held - float(acc.get("t0", 0.0)), be.position.distance_to(bb.position)]
		if ph == "active" and acc["bots"].has(id) and GameData.skills.has(sid) and GameData.skills[sid].ultimate:
			var uk1: String = str(acc["bots"][id]).get_slice("#", 0)
			acc["ult_casts"][uk1] = int(acc["ult_casts"].get(uk1, 0)) + 1      # Supremas que saíram (ULTDMG)
		if ph == "startup" and acc["bots"].has(id) and GameData.skills.has(sid) and GameData.skills[sid].ascension:
			acc["asc"][sid] = int(acc["asc"].get(sid, 0)) + 1      # skill da ascensão usada por um bot (--asc)
		if id == acc["boss"] and ph == "startup":
			acc["from"] = Sim.entities[id].position if Sim.entities.has(id) else Vector3.ZERO     # de onde o golpe saiu
			if sid.begins_with("mob_"):
				acc["casts"] += 1
				var b: SimEntity = Sim.entities.get(id)
				var sk: SkillDef = GameData.skills.get(sid)
				if b and sk and sk.target != SkillDef.Target.SELF and Vector2(b.skill_aim.x - b.position.x, b.skill_aim.z - b.position.z).length() >= 9.0:
					acc["far"] += 1          # golpe mirado em quem está a 9 m+ (o bot pode desviar; conta a pressão)
	var on_dmg := func(src: int, tid: int, amount: int, _c: bool, _b: bool, _k: String):
		if acc["bots"].has(src):                  # parte da Suprema neste golpe: SimEntity.ult_dealt sobe antes do evento
			var ua: SimEntity = Sim.entities.get(src)
			if ua != null:
				var ud: float = ua.ult_dealt - float(acc["ult_seen"].get(src, 0.0))
				acc["ult_seen"][src] = ua.ult_dealt
				if tid == acc["boss"] and ud > 0.0:
					var uk0: String = str(acc["bots"][src]).get_slice("#", 0)
					acc["ult_dmg"][uk0] = float(acc["ult_dmg"].get(uk0, 0.0)) + ud
		if tid == acc["boss"] and acc["bots"].has(src):         # dano de cada membro no chefe (--asc_level: DPS por build)
			var key: String = acc["bots"][src]
			acc["dealt"][key] = float(acc["dealt"].get(key, 0.0)) + amount
			var bk0: String = key.get_slice("#", 0)          # --dot_stats: parte do dano do membro que veio de dano no tempo
			acc["dot"]["boss_by"][bk0] = float(acc["dot"]["boss_by"].get(bk0, 0.0)) + amount
			if _k.begins_with("dot"):
				acc["dot"]["boss_dot_by"][bk0] = float(acc["dot"]["boss_dot_by"].get(bk0, 0.0)) + amount
			if _why:                 # último golpe de cada membro no chefe (PERDAS_COMO: com o quê tirou o chefe do tanque)
				var a0: SimEntity = Sim.entities.get(src)
				var b0: SimEntity = Sim.entities.get(acc["boss"])
				var how: String = "dot" if _k.begins_with("dot") else (a0.current_skill.id if a0.state == SimEntity.State.CASTING and a0.current_skill and a0.current_skill != a0.basic_skill else "basico/proj")
				var tk0: float = float(b0.threat.get(acc["lead"], 0.0))
				var pre: float = (float(b0.threat.get(src, 0.0)) - amount * (1.0 + a0.stats.threat_pct / 100.0)) / maxf(1.0, tk0)
				acc["last_hit"][src] = [how + "[%s %s %s]" % [_k, SimEntity.State.keys()[a0.state], a0.current_skill.id if a0.current_skill else "-"], pre, amount / maxf(1.0, tk0), _c, a0.sig_ready_at > Sim.time + Balance.SIGNATURE_ICD - 0.05]
		elif tid == acc["boss"] and Sim.entities.has(src) and acc["bots"].has(Sim.entities[src].owner_id):      # invocação de um membro
			var key: String = acc["bots"][Sim.entities[src].owner_id] + "+inv"
			acc["dealt"][key] = float(acc["dealt"].get(key, 0.0)) + amount
		if not acc["bots"].has(tid):
			return
		var a: SimEntity = Sim.entities.get(src)
		var b: SimEntity = Sim.entities.get(acc["boss"])
		if a == null or b == null or not (a == b or a.boss_id == b.id):
			return
		acc["dmg"] += amount
		if tid == acc["lead"]:          # --dot_stats: dano do chefe/lacaios no tanque e quanto foi dano no tempo
			acc["dot"]["tank"] += amount
			if _k.begins_with("dot"):
				acc["dot"]["tank_dot"] += amount
				acc["dot"]["tank_dot_hits"] += 1
		if not _k.begins_with("dot"):
			var sk: SkillDef = b.current_skill if a == b and b.state == SimEntity.State.CASTING else null
			if (a == b and sk == null) or (sk and sk.target != SkillDef.Target.TARGET and sk.radius >= Balance.BOT_DODGE_MIN_RADIUS):
				acc["area"] += amount          # círculo/poça/projétil no ar (chefe sem golpe em andamento) ou golpe de área
			if sk and sk.mob_pick == "" and tid != acc["lead"]:
				acc["stray"] += amount         # golpe do chefe sem mira de propósito pegando quem não é o tanque (posição)
		if _why:                     # de onde veio o dano no grupo (--why)
			var key := "lacaio:%s" % a.monster_def.id if a != b else ("golpe:%s" % b.current_skill.id if b.state == SimEntity.State.CASTING and b.current_skill else "chuva/outro")
			if not _comp.is_empty():
				key += ">%s" % ("tanque" if tid == acc["lead"] else str(Sim.role_of(Sim.entities[tid])) if Sim.entities.has(tid) else "?")
			acc["why"][key] = float(acc["why"].get(key, 0.0)) + amount
			acc["why_t"][key] = float(acc["why_t"].get(key, 0.0)) + amount
		if tid != b.aggro_target:
			acc["off"] += amount
		var t: SimEntity = Sim.entities.get(tid)
	var on_heal := func(_src: int, tid: int, amount: int):
		if acc["bots"].has(tid):
			acc["heal"] += amount
			if tid == acc["lead"]:
				acc["heal_tank"] += amount
	Events.skill_cast.connect(on_cast)
	Events.damage_dealt.connect(on_dmg)
	Events.healed.connect(on_heal)
	var on_pot := func(id: int, slot: int):
		if slot == 0 and acc["bots"].has(id):
			acc["pots"] += 1
	Events.potion_used.connect(on_pot)
	for trial in range(trials):
		if OS.get_cmdline_user_args().has("--slow"):       # sonda lenta com o tempo? quanto custa cada luta e o que sobra na sim
			var per := {}
			for k in Sim.maps:
				per[k] = (Sim.maps[k]["entities"] as Array).size()
			print("  SLOW #%d ms=%d entidades=%d mapas=%s" % [trial, Time.get_ticks_msec() - int(acc.get("wall", Time.get_ticks_msec())), Sim.entities.size(), str(per)])
			acc["wall"] = Time.get_ticks_msec()
			for k in Sim.maps:
				if k != mid and (Sim.maps[k]["entities"] as Array).size() > 40:
					var kinds := {}
					for o in Sim.maps[k]["entities"]:
						var key: String = o.monster_def.id if o.monster_def else SimEntity.Kind.keys()[o.kind]
						kinds[key] = int(kinds.get(key, 0)) + 1
					print("    %s: %s" % [k, str(kinds)])
		for e in m["entities"].duplicate():
			Sim.despawn(e)
		m["hazards"] = []
		Sim.rng.seed = fight_seed(bid, trial, _seed)      # a luta não herda o rng das lutas/chefes anteriores
		var boss = Sim.spawn_monster(base, mid, at)
		acc["boss"] = boss.id
		if not base.escort.is_empty():
			MobSystem.spawn_escort(Sim, boss, {})          # capitão luta com a escolta, como no forte
		var bots: Array = []
		acc["bots"] = {}
		var lead_cls := _lead.get_slice(":", 0) if _lead != "" else ""
		var excl: Array = [lead_cls] if lead_cls != "" else []
		var drawn := rotation_comp(bid, trial, _seed, party, excl) if _rotation else random_comp(bid, trial, _seed, party, excl)
		if lead_cls != "" and drawn.size() >= party:       # o 1º é o líder: os sorteados ficam nas vagas 1..
			drawn.push_front("")
		if _show_comp:
			print("COMP %s #%d %s" % [bid, trial, ",".join(drawn)])
		for i in range(party):
			var cid: String = _force_class if _force_class != "" else str(drawn[i]).get_slice(":", 0)
			var want_build := _force_build if _force_class != "" else str(drawn[i]).get_slice(":", 1)
			if i < _comp.size():
				cid = str(_comp[i]).get_slice(":", 0)
				want_build = str(_comp[i]).get_slice(":", 1)
			if kite != "" and i == 0:
				cid = kite.get_slice(":", 0)
				want_build = kite.get_slice(":", 1)
			elif not _comp.is_empty():
				pass
			elif _lead != "" and i == 0:
				cid = _lead.get_slice(":", 0)
				want_build = _lead.get_slice(":", 1)
			var bot = Sim.spawn_bot(GameData.classes[cid], "P%d" % i, mid, at + Vector3(3 + i, 0, 3), _lvl if _lvl > 0 else maxi(1, base.level - _under))
			if want_build != "" and bot.build_id != want_build:
				bot.build_id = want_build          # mesma build para todos: equipamento e skills dela
				Sim._gear_bot(bot)
				Sim._skill_bot(bot)
			if _asc_on and (_asc.is_empty() or cid in _asc):
				if bot.level < Balance.ASC_LEVEL:
					bot.level = Balance.ASC_LEVEL
				bot.quests_completed.append("hx_asc_" + cid)        # ascensão forçada (sem a missão da fase)
				bot.elem_stage = _elem_stage
				Sim._gear_bot(bot)
				Sim._skill_bot(bot)
				bot.recompute_stats()
			elif cid in _asc_base:                  # F5: mesmo nível, sem a missão
				bot.level = maxi(bot.level, Balance.ASC_LEVEL)
				Sim._gear_bot(bot)
				Sim._skill_bot(bot)
				bot.recompute_stats()
				bot.heal_full()
			if kite != "" and i == 0:
				var kb := KiteBrain.new()
				kb.setup(bot, Sim.rng)
				kb.boss_id = boss.id
				kb.personality = 1.0
				bot.brain = kb
				bot.position = at + Vector3(KITE_MIN + 1.0, 0, 0)
			if not (kite != "" and i == 0):
				var sb := StayBrain.new()
				sb.setup(bot, Sim.rng)
				sb.boss_id = boss.id
				bot.brain = sb
			bot.brain.personality = 1.0          # veio pelo chefe: encara (o bot cauteloso ignora chefe)
			if _set != "" and (_set_who.is_empty() or i in _set_who):
				_wear_set(bot)
			if _acc == "leg" and (_acc_who.is_empty() or i in _acc_who):
				_wear_acc(bot, trial == 0)
			if _why and trial == 0:
				var st: Stats = bot.stats
				print("      MEMBRO %s/%s arma=%s+%s lv=%d hp=%d pdef=%d mdef=%d patk=%d matk=%d esq=%.0f%% skills=%s" % [cid, bot.build_id, st.weapon_type, st.offhand_type, bot.level, st.max_hp, st.pdef, st.mdef, st.patk, st.matk, st.evasion,
					",".join(bot.skills.filter(func(s): return s != null).map(func(s): return s.id))])
			bots.append(bot)
			acc["bots"][bot.id] = "%s:%s#%d" % [cid, bot.build_id, i]
			acc["ult_seen"][bot.id] = bot.ult_dealt
		for i in range(1, party):
			Sim.party_invite(bots[0], bots[i])
			Sim.party_accept(bots[i])
		var tank_bot: SimEntity = bots[0]          # tanque das métricas: o 1º com papel "tank" (o líder, se não houver)
		for b in bots:
			if Sim.role_of(b) == "tank":
				tank_bot = b
				break
		acc["lead"] = tank_bot.id
		boss.aggro_target = bots[0].id
		boss.aggro_timer = 5.0
		var t := 0.0
		acc["t0"] = Sim.time
		var ult_first := {}
		var ult_last := {}                 # último (carga, t) com o membro vivo: ritmo de quem não encheu
		if _ult:
			for b in bots:
				UltimateSystem.zero(b)
				b.ult_gap_until = 0.0
				UltimateSystem.refresh(Sim, b)
		acc["decide"] = {}
		var dead := {}
		var on_lead := 0.0
		var targeted := 0.0
		var acting := 0.0
		var adds := {}
		var inv := {}
		var prev_tgt: int = boss.aggro_target
		var ward_at := -1.0
		var ward_kill := -1.0
		var temper_boss: bool = boss.skills.any(func(s): return s != null and s.effects.get("barrage") is Dictionary and (s.effects["barrage"] as Dictionary).has("empower"))
		while t < LIMIT and boss.is_alive():
			Sim.tick(DT)
			t += DT
			if _ult_off:
				for b in bots:
					b.ult_gap_until = Sim.time + 1.0      # trava: nada enche e nada sai
			elif not _ult_who.is_empty():
				for bi in range(bots.size()):
					if not (bi in _ult_who):
						bots[bi].ult_gap_until = Sim.time + 1.0     # só os de --ult_who soltam
			if _ult:
				for b in bots:
					var uk: String = str(acc["bots"][b.id]).get_slice("#", 0)
					if b.ult_full_at >= 0.0 and not ult_first.has(uk):
						ult_first[uk] = b.ult_full_at - float(acc["t0"])
						ult_first[uk + "@luta"] = b.ult_full_at - float(acc["t0"]) - float(ult_last.get(uk + "@0", 0.0))
					elif not ult_first.has(uk) and (b.ult_charge <= 0.0 or not b.is_alive()):
						ult_last[uk + "@0"] = t            # luta de verdade começa quando a carga sai do zero (morreu: recomeça)
					if _ult_trace and int(t / DT) % int(5.0 / DT) == 0:
						print("    ULT_TRACE t=%.0f %s carga=%.1f estoque=%.1f vivo=%s combate=%.1f lv=%d ok=%s" % [t, uk, b.ult_charge, b.ult_budget, b.is_alive(), Sim.time - b.ult_combat_t, b.level, b.ult_ok])
					# ULTCUT: Supremas começadas e quantas o próprio dash cortou (canal/mira ou sequência de saltos)
					var uc: Dictionary = acc.get_or_add("ultcut", {"cast": 0, "cut_cast": 0, "cut_hop": 0, "hop_left": 0})
					var now_ult: bool = b.state == SimEntity.State.CASTING and b.current_skill != null and b.current_skill.ultimate and b.skill_phase != "recovery"
					var was_ult: bool = b.get_meta("pu_cast", false)
					var was_hop: int = b.get_meta("pu_hop", 0)
					var was_dash: bool = b.get_meta("pu_dash", false)
					if now_ult and not was_ult:
						uc["cast"] += 1
					if b.state == SimEntity.State.DASHING and not was_dash:
						if was_ult:
							uc["cut_cast"] += 1
						if was_hop > 0:
							uc["cut_hop"] += 1
							uc["hop_left"] += was_hop
					b.set_meta("pu_cast", now_ult)
					b.set_meta("pu_hop", int(b.hop.get("left", 0)))
					b.set_meta("pu_dash", b.state == SimEntity.State.DASHING)
					if not b.is_alive():
						ult_last[uk + "!"] = true          # morreu: a carga zerou, o ritmo para de contar aqui
					elif not ult_last.has(uk + "!"):
						ult_last[uk] = [b.ult_charge, t]
			if _dot_stats:               # acúmulos de dano no tempo: no tanque (do lado do chefe) e no chefe (por build do membro)
				var tn := 0
				for dd in tank_bot.debuffs:
					if dd.get("kind") == "dot":
						tn += 1
				acc["dot"]["tank_max"] = maxi(int(acc["dot"]["tank_max"]), tn)
				var per_src := {}
				var bn := 0
				for dd in boss.debuffs:
					if dd.get("kind") == "dot":
						bn += 1
						var sid0: int = int(dd.get("src", -1))
						var se: SimEntity = Sim.entities.get(sid0)
						if se and se.kind == SimEntity.Kind.SUMMON:
							sid0 = se.owner_id
						if acc["bots"].has(sid0):
							var bk1: String = str(acc["bots"][sid0]).get_slice("#", 0)
							per_src[bk1] = int(per_src.get(bk1, 0)) + 1
				acc["dot"]["boss_max"] = maxi(int(acc["dot"]["boss_max"]), bn)
				for k in per_src:
					acc["dot"]["boss_max_by"][k] = maxi(int(acc["dot"]["boss_max_by"].get(k, 0)), int(per_src[k]))
			if temper_boss:              # Têmpera do Kragmar (AC-S5 tempera_med): acúmulos médios no tempo de luta
				BossSignatures.stat(Sim, "temper_time", DT)
				BossSignatures.stat(Sim, "temper_sum", boss.buff_stacks(BossSignatures.TEMPER_BUFF) * DT)
				if BossSignatures.in_empower_pool(m, boss):
					BossSignatures.stat(Sim, "pool_time", DT)          # chefe dentro da poça (o tanque devia tirá-lo)
			if _why:                     # tempo de cada buff nos bots (BUFFS: % do tempo de luta, por membro) e de montaria/MP
				for b in bots:
					if not b.is_alive():
						continue
					var bk: String = acc["bots"][b.id]
					for bf in b.buffs:
						var k2 := "%s %s" % [bk, str(bf.get("id", "?"))]
						buff_t[k2] = float(buff_t.get(k2, 0.0)) + DT
					if b.mounted:
						buff_t[bk + " (montado)"] = float(buff_t.get(bk + " (montado)", 0.0)) + DT
					if b.mp < b.stats.max_mp * 0.2:
						buff_t[bk + " (mp<20%)"] = float(buff_t.get(bk + " (mp<20%)", 0.0)) + DT
			if _why:                     # invocações dos bots: quantas caem antes do prazo
				for o in m["entities"]:
					if o.kind == SimEntity.Kind.SUMMON and acc["bots"].has(o.owner_id) and not inv.has(o.id):
						inv[o.id] = o
				for oid in inv.keys():
					var o: SimEntity = inv[oid]
					if o != null and (not o.is_alive() or not Sim.entities.has(oid)):
						if Sim.time < o.summon_expires - 0.3 and Sim.entities.has(o.owner_id) and Sim.entities[o.owner_id].is_alive():
							inv_dead += 1
						inv[oid] = null              # contada (o corpo fica um tempo na lista do mapa)
			if boss.state == SimEntity.State.ATTACKING or boss.state == SimEntity.State.CASTING:
				acting += DT
			if _why:
				var sk: String = SimEntity.State.keys()[boss.state]
				acc["states"][sk] = float(acc["states"].get(sk, 0.0)) + DT
			var tank_thr: float = float(boss.threat.get(tank_bot.id, 0.0))
			if _tank_lock and tank_bot.is_alive():
				var top := 0.0
				for k in boss.threat:
					if k != tank_bot.id:
						top = maxf(top, float(boss.threat[k]))
				tank_thr = maxf(tank_thr, top * TANK_LOCK)
				boss.threat[tank_bot.id] = tank_thr
			if boss.aggro_target == tank_bot.id and bots.size() > 1:
				for b in bots:
					if b != tank_bot and b.is_alive() and float(boss.threat.get(b.id, 0.0)) >= tank_thr * Balance.BOT_THREAT_HOLD:
						hold_sum += DT / (bots.size() - 1)
			if prev_tgt == tank_bot.id and boss.aggro_target != tank_bot.id and boss.aggro_target >= 0 and tank_bot.is_alive():
				drops += 1
				if _why:                 # quem tirou o chefe do tanque (membro, invocação de quem) e quanto da luta já tinha passado
					var tk: SimEntity = Sim.entities.get(boss.aggro_target)
					var who: String = "?" if tk == null else (str(acc["bots"].get(tk.id, "")) if acc["bots"].has(tk.id) else ("inv:" + str(acc["bots"].get(tk.owner_id, "?")) if tk.kind == SimEntity.Kind.SUMMON else SimEntity.Kind.keys()[tk.kind]))
					var key2 := "%s %s" % [who, "abertura" if t < 5.0 else "luta"]
					acc["drop_by"][key2] = int(acc["drop_by"].get(key2, 0)) + 1
					if tk != null and acc["last_hit"].has(tk.id):
						var lh: Array = acc["last_hit"][tk.id]
						var band: String = "pre<0.85" if float(lh[1]) < Balance.BOT_THREAT_HOLD else ("pre<1.0" if float(lh[1]) < 1.0 else "pre>=1.0")
						var key3 := "%s %s %s golpe=%s" % [who, lh[0], band, "grande" if float(lh[2]) > 0.25 else "pequeno"]
						acc["drop_how"][key3] = int(acc["drop_how"].get(key3, 0)) + 1
						var hb = tk.brain
						var ht: SimEntity = Sim.entities.get(hb.hunt_target_id) if hb is BotBrain else null
						print("      PERDA t=%.1f %s %s pre=%.2f golpe=%.2f crit=%s assinatura=%s alvo=%s abertura=%s d=%.1f tanque_d=%.1f" % [t, who, lh[0], lh[1], lh[2], lh[3], lh[4],
							"chefe" if ht == boss else ("-" if ht == null else str(ht.monster_def.id if ht.monster_def else ht.id)), str(hb.opener_id == boss.id) if hb is BotBrain else "?",
							tk.position.distance_to(boss.position), tank_bot.position.distance_to(boss.position)])
						print("        decisao %s" % str(acc["decide"].get(tk.id, "-")))
			prev_tgt = boss.aggro_target
			if boss.aggro_target >= 0:
				targeted += DT
				if boss.aggro_target == tank_bot.id:
					on_lead += DT
			for o in m["entities"]:
				if o.boss_id == boss.id:
					adds[o.id] = true
			if ward_at < 0.0 and boss.ward > 0.0:
				ward_at = t
			if ward_at >= 0.0 and ward_kill < 0.0:
				for aid in adds:
					var ao: SimEntity = Sim.entities.get(aid)
					if ao == null or not ao.is_alive():
						ward_kill = t - ward_at
						break
			for bi in range(bots.size()):
				if bots[bi] == tank_bot:
					if tank_bot.is_alive() and tank_bot.hp < tank_bot.stats.max_hp * 0.35:
						low_tank += DT
					continue
				if bots[bi].is_alive() and bots[bi].hp < bots[bi].stats.max_hp * 0.35:
					low_sum += DT
				if bots[bi].state == SimEntity.State.ATTACKING or bots[bi].state == SimEntity.State.CASTING:
					busy_sum += DT / maxf(1.0, bots.size() - 1)
			for b in bots:
				if _why and b.map_id == mid and b.brain is BotBrain:
					b.set_meta("probe_state", "%s t=%.0f hp=%.0f%% alvo=%d dest=%s forma=%s (teve: %s)" % [BotBrain.S.keys()[b.brain.state], t, 100.0 * b.hp / b.stats.max_hp, b.brain.target_id if "target_id" in b.brain else -1, b.brain.dest_map, b.form, b.get_meta("had_form", "nenhuma")])
				if _why and b.form != "":
					b.set_meta("had_form", b.form)
				if not b.is_alive() or b.map_id != mid:
					if _why and not dead.has(b.id) and b.has_meta("probe_state"):
						print("      saiu/morreu %s: antes = %s" % [b.class_def.id, b.get_meta("probe_state")])
					dead[b.id] = true
			if dead.size() == party:
				break
		deaths += dead.size()
		if ward_at >= 0.0:
			ward_n += 1
			var wk: float = ward_kill if ward_kill >= 0.0 else t - ward_at
			ward_sum += wk
			ward_fast += 1 if ward_kill >= 0.0 and ward_kill <= 30.0 else 0
		if _why:
			print("TRIAL %s #%d %s t=%.0fs hp_chefe=%.0f%% caidos=%s grupo=%s" % [bid, trial, ("WIN" if not boss.is_alive() else "LOSS"), t, 100.0 * maxf(0.0, boss.hp) / boss.stats.max_hp,
				",".join(bots.filter(func(b): return dead.has(b.id)).map(func(b): return "%s/%s:%s" % [b.class_def.id, b.build_id, ("morto" if not b.is_alive() else "saiu->" + b.map_id)])), ",".join(bots.map(func(b): return "%s/%s" % [b.class_def.id, b.build_id]))])
			if boss.is_alive() and boss.hp >= boss.stats.max_hp:          # luta que nem começou: onde estava cada um
				print("      chefe %s em %s alvo=%d" % [SimEntity.State.keys()[boss.state], boss.position.snapped(Vector3.ONE), boss.aggro_target])
				for b in bots:
					print("      %s/%s em %s d=%.1f %s" % [b.class_def.id, b.build_id, b.position.snapped(Vector3.ONE), b.position.distance_to(boss.position), b.get_meta("probe_state", "")])
			var wt: Dictionary = acc["why_t"]
			var ks: Array = wt.keys()
			ks.sort_custom(func(x, y): return wt[x] > wt[y])
			print("      dano: %s" % ", ".join(ks.slice(0, 5).map(func(k): return "%s=%.0f" % [k, wt[k]])))
		acc["why_t"] = {}
		agg_sum += on_lead / maxf(0.01, targeted)
		fight_sum += t
		acc["fight_t"] = float(acc.get("fight_t", 0.0)) + t
		if _ult:
			if not acc.has("ult"):
				acc["ult"] = {}
			for b in bots:
				var uk2: String = str(acc["bots"][b.id]).get_slice("#", 0)
				if not acc["ult"].has(uk2):
					acc["ult"][uk2] = {"t": [], "miss": 0, "role": Sim.role_of(b), "ok": UltimateSystem.has_ultimate(b), "rate": [], "luta": []}
				var last: Array = ult_last.get(uk2, [0.0, t])
				acc["ult"][uk2]["rate"].append(Balance.ULT_MAX / maxf(1.0, float(ult_first[uk2])) if ult_first.has(uk2) else float(last[0]) / maxf(1.0, float(last[1])))
				if ult_first.has(uk2):
					acc["ult"][uk2]["t"].append(ult_first[uk2])
					acc["ult"][uk2]["luta"].append(ult_first[uk2 + "@luta"])
				else:
					acc["ult"][uk2]["miss"] += 1       # a luta acabou antes de encher
		act_sum += acting
		adds_sum += adds.size()
		if not boss.is_alive():
			wins += 1
			t_sum += t
			times.append(t)
		_count_fusion(bots, acc)
		for b in bots:
			Sim.despawn(b)
	if _why:
		var keys: Array = acc["why"].keys()
		keys.sort_custom(func(x, y): return acc["why"][x] > acc["why"][y])
		var st: Dictionary = acc["states"]
		print("STATES %s grupo=%d %s" % [bid, party, ", ".join(st.keys().map(func(k): return "%s=%.0f%%" % [k, 100.0 * st[k] / maxf(0.01, fight_sum)]))])
		var bks: Array = buff_t.keys()
		bks.sort()
		print("BUFFS %s %s" % [bid, ", ".join(bks.map(func(k): return "%s=%.0f%%" % [k, 100.0 * buff_t[k] / maxf(0.01, fight_sum)]))])
		print("PERDAS %s %s" % [bid, str(acc["drop_by"])])
		print("PERDAS_COMO %s %s" % [bid, str(acc["drop_how"])])
		print("WHY %s grupo=%d %s" % [bid, party, ", ".join(keys.slice(0, 8).map(func(k): return "%s=%.0f%%" % [k, 100.0 * acc["why"][k] / maxf(1.0, acc["dmg"])]))])
	if _dot_stats:
		var dd: Dictionary = acc["dot"]
		print("DOT %s grupo=%d tanque_dot=%.1f%% tanque_dot_hits/s=%.1f tanque_max_acumulos=%d chefe_max_acumulos=%d" % [bid, party,
			100.0 * float(dd["tank_dot"]) / maxf(1.0, float(dd["tank"])), float(dd["tank_dot_hits"]) / maxf(0.01, fight_sum), int(dd["tank_max"]), int(dd["boss_max"])])
		var bks2: Array = (dd["boss_by"] as Dictionary).keys()
		bks2.sort()
		print("DOT_BUILDS %s %s" % [bid, ", ".join(bks2.map(func(k): return "%s=%.0f%%/max%d" % [k, 100.0 * float(dd["boss_dot_by"].get(k, 0.0)) / maxf(1.0, float(dd["boss_by"][k])), int(dd["boss_max_by"].get(k, 0))]))])
	if acc.has("ultcut"):
		var uc: Dictionary = acc["ultcut"]
		print("ULTCUT %s lancadas=%d dash_cortou_canal=%d dash_cortou_saltos=%d saltos_perdidos=%d" % [bid, uc["cast"], uc["cut_cast"], uc["cut_hop"], uc["hop_left"]])
	if ward_n > 0:
		print("WARD %s grupo=%d lutas_com_ward=%d 1o_lacaio_caiu_em=%.1fs ate_30s=%d/%d" % [bid, party, ward_n, ward_sum / ward_n, ward_fast, ward_n])
	Events.skill_cast.disconnect(on_cast)
	Events.damage_dealt.disconnect(on_dmg)
	Events.healed.disconnect(on_heal)
	Events.potion_used.disconnect(on_pot)
	var mins := maxf(0.01, fight_sum / 60.0)
	return {"sig": Sim.sig_stats.duplicate(), "wins": wins, "time": t_sum / maxf(1, wins), "deaths": float(deaths) / trials, "aggro": 100.0 * agg_sum / trials,
		"casts": acc["casts"] / mins, "act": 100.0 * act_sum / maxf(0.01, fight_sum), "adds": float(adds_sum) / trials,
		"off": 100.0 * acc["off"] / maxf(1.0, acc["dmg"]), "far": acc["far"] / mins, "kite": kite != "",
		"area": 100.0 * acc["area"] / maxf(1.0, acc["dmg"]), "heal_tank": 100.0 * acc["heal_tank"] / maxf(1.0, acc["heal"]), "low": low_sum / trials,
		"stray": 100.0 * acc["stray"] / maxf(1.0, acc["dmg"]), "busy": 100.0 * busy_sum / maxf(0.01, fight_sum),
		"low_tank": low_tank / trials, "pots": float(acc["pots"]) / trials, "asc": acc["asc"], "ult": acc.get("ult", {}), "dealt": acc["dealt"], "ult_dmg": acc["ult_dmg"], "ult_casts": acc["ult_casts"], "fight_t": acc.get("fight_t", 1.0),
		"times": times, "inv_dead": inv_dead, "hold": 100.0 * hold_sum / maxf(0.01, fight_sum), "drops": float(drops) / trials,
		"tank_dmg": float(acc["dot"]["tank"]) / trials}


## --set: veste o conjunto lendário no bot (armadura; a arma continua a comum da build: a face da Fusão é a da build dele).
func _wear_set(bot: SimEntity) -> void:
	var lv := _set_lv
	if lv <= 0:
		for l in Balance.LEGENDARY_LEVELS + Balance.HYBRID_LEVELS:
			if l <= bot.level:
				lv = maxi(lv, l)
	var sid := ""
	if _set.begins_with("b"):
		sid = GameData.set_id_for(bot.class_def.id, bot.build_id, lv)
	elif _set.begins_with("a"):          # a4/a5: Ápice da build do bot (apice-sets.md F-AP2)
		sid = GearCatalog.apex_set_id(bot.class_def.id, bot.build_id, lv)
	else:
		for sd in GameData.hybrid_sets_for(bot.class_def, bot.build_id, lv):
			if _pair == "" or _pair in sd.pair:
				sid = sd.id
		if _pair == "":
			sid = Sim.bot_legendary_set(bot, lv)
	var sd: SetDef = GameData.sets.get(sid)
	if sd == null:
		push_error("--set: sem conjunto %s" % sid)
		return
	if _set == "h5n" and sd.bonuses[5].has("fusion"):       # referência: o 5 peças normal da build do bot no lugar da Fusão
		var b: Dictionary = bot.class_def.build_by_id(bot.build_id)
		var tier := Balance.legend_tier(lv)
		var pk := GearCatalog.set_skills(b, GameData.skills, lv, tier)
		sd.bonuses[5] = GearCatalog.set_bonuses(b, pk[0], pk[1], tier)[5]
	var n := 4 if _set.contains("4") else 5
	for i in range(n):
		var it: ItemDef = GameData.items[sd.armor[i]]
		bot.equipment[it.slot] = it
	if _set_weapon:                     # --set_weapon: arma (pelo papel da build) e escudo do conjunto, Sim.bot_set_weapons
		for iid in Sim.bot_set_weapons(bot, sd):
			var w: ItemDef = GameData.items[iid]
			bot.equipment[ItemDef.Slot.OFFHAND if w.slot == ItemDef.Slot.OFFHAND or iid.ends_with("_offhand") else ItemDef.Slot.WEAPON] = w
	bot.recompute_stats()
	bot.heal_full()
	Sim._slot_bot(bot)                  # barra refeita com o conjunto (como no jogo: equipamento antes das skills)
	bot.set_meta("fus_set", sid)

## --acc=leg: veste os 4 acessórios lendários da build (Anel em RING, Sinete em RING2) e imprime "ACC <membro> <stat>=<valor>".
func _wear_acc(bot: SimEntity, show: bool) -> void:
	var ids: Array = Sim.bot_legendary_accessories(bot, bot.level)
	if ids.is_empty():
		push_error("--acc: sem acessório lendário para %s/%s nv %d" % [bot.class_def.id, bot.build_id, bot.level])
		return
	for iid in ids:
		var it: ItemDef = GameData.items[iid]
		var sl: int = ItemDef.Slot.RING2 if iid.ends_with("_signet") else it.slot
		bot.equipment[sl] = it
		if show:
			print("      ACC %s/%s %s %s" % [bot.class_def.id, bot.build_id, iid.get_slice("_", iid.get_slice_count("_") - 1), it.bonus])
	bot.recompute_stats()
	bot.heal_full()

## Disparos da Fusão por luta (sonda): chamado no fim de cada luta.
func _count_fusion(bots: Array, acc: Dictionary) -> void:
	for b in bots:
		if b.fus.has("fired") or b.stats.fusion.size() > 0:
			var k := "%s face=%s" % [acc["bots"][b.id], str(b.stats.fusion.get("face", "-"))]
			if not _fus_fired.has(k):
				_fus_fired[k] = {"lutas": 0, "disparos": 0}
			_fus_fired[k]["lutas"] += 1
			_fus_fired[k]["disparos"] += int(b.fus.get("fired", 0))
			for kk in b.fus:
				if str(kk).begins_with("n_"):
					_fus_fired[k][kk] = int(_fus_fired[k].get(kk, 0)) + int(b.fus[kk])
