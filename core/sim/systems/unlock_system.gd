class_name UnlockSystem
extends RefCounted
## Introdução dos sistemas (GDD design/gdd/introducao-de-sistemas.md): cada sistema abre numa hora marcada
## (Balance.UNLOCK_LEVELS), quando o jogador aceita a tarefa curta do NPC dono dele (QuestsCatalog.INTRO).
## Pulou o NPC: abre sozinho Balance.UNLOCK_GRACE_LEVELS níveis depois. Sem estado próprio: vive em
## SimEntity.knows_game / SimEntity.unlocked. Bots e "Já conheço o jogo" têm tudo aberto.
## Ex.: `if UnlockSystem.window_open(p, "party"): ...`

## Janela/atalho -> sistema que a abre ("inventory", "character" e o menu sempre aparecem).
const WINDOW_SYSTEM := {"book": "web", "skills": "web", "quests": "basics", "party": "party", "@map": "basics"}
## Tarefas de introdução (QuestDef.Type.TASK, `target_id`): as de estado contam sozinhas; "sell" e "party_kill" contam por evento.
const TASKS := ["web_point", "talent", "rank2", "set2", "enhance", "bag", "evolution", "sell", "party_kill"]
## Tarefa -> NPC onde ela se faz (seta da quest; QuestSystem.objective). Sem entrada = o NPC que deu a quest.
const TASK_NPC := {"sell": "merchant", "enhance": "smith", "set2": "smith", "bag": "alchemist", "talent": "trainer_city_aldara",
	"rank2": "trainer_city_aldara", "evolution": "trainer_city_aldara", "party_kill": "captain"}

static func level_of(sys: String) -> int:
	return int(Balance.UNLOCK_LEVELS.get(sys, 1))

## Introdução ligada para `e` (só o jogador que não marcou "Já conheço o jogo").
static func intro_on(e: SimEntity) -> bool:
	return e != null and e.kind == SimEntity.Kind.PLAYER and not e.knows_game

## O sistema já abriu para `e`? Sistema sem tarefa de NPC (ascensão, Suprema) segue a trava própria dele.
static func is_unlocked(e: SimEntity, sys: String) -> bool:
	if not intro_on(e) or not Balance.UNLOCK_LEVELS.has(sys) or e.unlocked.has(sys):
		return true
	if not QuestsCatalog.INTRO.has(sys):
		return true
	return e.level >= level_of(sys) + Balance.UNLOCK_GRACE_LEVELS

## A janela `name` (windows.gd / ActionBar.MICRO) aparece para `e`?
static func window_open(e: SimEntity, name: String) -> bool:
	return is_unlocked(e, str(WINDOW_SYSTEM.get(name, "")))

## Abre o sistema (avisa a apresentação uma vez).
static func unlock(e: SimEntity, sys: String) -> void:
	if e.unlocked.has(sys):
		return
	e.unlocked[sys] = true
	if intro_on(e):
		Events.post(&"system_unlocked", e.id, sys)

## Tudo do calendário até o nível `level` (save antigo, começo rápido).
static func unlock_up_to(e: SimEntity, level: int) -> void:
	for sys in Balance.UNLOCK_LEVELS:
		if level_of(sys) <= level:
			e.unlocked[sys] = true

## Personagem novo: `knows` = caixa "Já conheço o jogo" da Criação. Começo rápido (nível > 1) abre tudo até o nível dele.
static func setup(e: SimEntity, knows: bool) -> void:
	e.knows_game = knows
	e.unlocked = {}
	if not knows and e.level > 1:
		unlock_up_to(e, e.level)

## Aceitou uma quest: qualquer uma abre o básico (quests e mapa); a de introdução abre o sistema dela.
static func on_quest_accepted(e: SimEntity, q: QuestDef) -> void:
	if not intro_on(e):
		return
	unlock(e, "basics")
	var sys := QuestsCatalog.intro_system(q.id)
	if sys != "":
		unlock(e, sys)
		var gift: Dictionary = QuestsCatalog.INTRO_GIFTS.get(q.id, {})
		for iid in gift:                      # presente da cena (ex.: a bolsa da Alquimista); fica com o jogador
			e.add_item(iid, int(gift[iid]))

## A quest de introdução `quest_id` pode ser oferecida a `e` (introdução ligada e sistema ainda fechado).
static func offers(e: SimEntity, quest_id: String) -> bool:
	var sys := QuestsCatalog.intro_system(quest_id)
	return sys != "" and intro_on(e) and not is_unlocked(e, sys)

## Sistemas cujo NPC chama agora: [[sistema, quest_id], ...] em ordem de nível (aviso do HUD).
static func pending(e: SimEntity) -> Array:
	var out: Array = []
	if not intro_on(e):
		return out
	for sys in QuestsCatalog.INTRO:
		var qid: String = QuestsCatalog.INTRO[sys]
		var q: QuestDef = GameData.quests.get(qid)
		if q and QuestSystem.can_accept(e, q):
			out.append([sys, qid])
	out.sort_custom(func(a, b): return level_of(a[0]) < level_of(b[0]))
	return out

## Progresso da tarefa pelo estado do personagem (0 = nada feito ainda). "sell"/"party_kill" contam por on_task.
static func task_state(e: SimEntity, task: String) -> int:
	match task:
		"web_point", "talent":
			var nodes: Dictionary = GameData.trees.get(e.class_def.id, {}).get("nodes", {}) if e.class_def else {}
			var n := 0
			for nid in e.tree:
				var k: String = nodes.get(nid, {}).get("kind", "start")
				if (k == "pick") == (task == "talent") and k != "start":
					n += 1
			return n
		"rank2":
			return e.mastery.values().filter(func(v): return int(v) >= 2).size()
		"set2":
			var by_set := {}
			var best := 0
			for sl in e.equipment:
				var it: ItemDef = e.equipment[sl]
				if it and it.set_id != "":
					by_set[it.set_id] = int(by_set.get(it.set_id, 0)) + 1
					best = maxi(best, by_set[it.set_id])
			return best
		"enhance":
			var n := 0
			for sl in e.equipment:
				var it: ItemDef = e.equipment[sl]
				if it and it.plus >= 1:
					n += 1
			return n
		"bag":
			return e.bags.filter(func(b): return str(b) != "").size()
		"evolution":
			return e.talents.size()
	return 0

## Conta uma vez a tarefa `task` nas quests de introdução ativas (venda, abate em grupo).
static func on_task(e: SimEntity, task: String, n: int = 1) -> void:
	for qid in e.quests_active.keys():
		var q: QuestDef = GameData.quests.get(qid)
		if q and q.type == QuestDef.Type.TASK and q.target_id == task:
			var cur := mini(int(e.quests_active[qid]) + n, q.count)
			e.quests_active[qid] = cur
			Events.post(&"quest_progress", e.id, qid, cur, q.count)

## Save: `knows_game` + `unlocked` (lista). Save antigo (sem as chaves): introdução ligada e tudo até o nível dele aberto.
static func from_save(e: SimEntity, d: Dictionary) -> void:
	e.unlocked = {}
	if not d.has("knows_game"):
		e.knows_game = false
		unlock_up_to(e, e.level)
		return
	e.knows_game = bool(d["knows_game"])
	var lst: Variant = d.get("unlocked", [])
	for sys in (lst if lst is Array else []):
		if Balance.UNLOCK_LEVELS.has(str(sys)):
			e.unlocked[str(sys)] = true
