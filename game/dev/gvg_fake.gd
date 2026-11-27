class_name GvgFake
extends GuildFake
## Fonte falsa da Guerra de Guildas (formatos do wave6-contract §3) para os testes e o --gvg_shot enquanto a sim não tem
## o GvgSystem. Herda o lado social do GuildFake (já na guilda). Guarda as chamadas em `calls`.

var war := {}                    # gvg_status ({} = sem guerra)
var objs: Array = []             # gvg_objects
var can_start := true
var why := ""

func _init() -> void:
	super._init()
	guild["player_member"] = true
	offer["state"] = "accepted"

func guild_war() -> Dictionary:
	var gs: Array = []
	for i in BotsCatalog.BOT_GUILDS.size():
		var g: Dictionary = BotsCatalog.BOT_GUILDS[i]
		if g["tag"] == guild["tag"]:
			continue
		gs.append({"id": "g_%d" % i, "name": g["name"], "tag": g["tag"], "personality": g["personality"], "power": 14 + i * 3,
			"castle_owner": i == 1, "crest": int(g["crest"])})
	return {"guilds": gs, "record": {"wins": 3, "losses": 2}, "can_start": can_start, "why": why, "insignias": 140}

func gvg_status() -> Dictionary: return war
func gvg_objects() -> Array: return objs

func gvg_start(gid: String, attack: bool) -> String:
	calls.append(["gvg_start", gid, attack])
	return ""
func gvg_order(id: String, target: Variant = null) -> String:
	calls.append(["gvg_order", id, target])
	return ""
func gvg_plan(id: String) -> String:
	calls.append(["gvg_plan", id])
	return ""
func gvg_take_command(on: bool) -> String:
	calls.append(["gvg_take_command", on])
	if not war.is_empty():
		war["player_commands"] = on
	return ""
func gvg_pick_role(role: String) -> String:
	calls.append(["gvg_pick_role", role])
	if not war.is_empty():
		war["player_role"] = role
	return ""
func gvg_cannon_use(id: int) -> String:
	calls.append(["gvg_cannon_use", id])
	return ""
func gvg_cannon_leave() -> void: calls.append(["gvg_cannon_leave"])
func gvg_leave() -> void: calls.append(["gvg_leave"])

## Guerra montada: o jogador `player_id` no lado `side`, atacando ou não, na fase `phase`.
func setup_war(player_id: int, player_name: String, side: String, attack: bool, phase: String) -> void:
	var enemy := "S" if side == "N" else "N"
	var rs := {"N": [], "S": []}
	var classes := [["paladin", "muro"], ["paladin", "muro"], ["bishop", "cura"], ["druid", "cura"], ["elementalist", "artilharia"],
		["necromancer", "artilharia"], ["berserker", "ponta"], ["berserker", "ponta"], ["assassin", "batedor"], ["ranger", "batedor"], ["ranger", "artilharia"]]
	for s in ["N", "S"]:
		var mine: bool = s == side
		if mine:
			rs[s].append({"id": player_id, "name": player_name, "class": "paladin", "role": "muro", "level": 30, "is_player": true})
		for i in classes.size():
			var nm: String = roster_entry(i % roster.size() + 1).get("name", "Bot") if mine and i < 9 else "Recruta %d" % (i + 1)
			rs[s].append({"id": 1000 + i + (0 if mine else 100), "name": nm, "class": classes[i][0], "role": classes[i][1],
				"level": 29 + i % 3, "recruit": not mine or i >= 9})
	war = {"phase": phase, "time_left": 24.0 if phase == "prep" else 734.0, "attacker": side if attack else enemy, "player_side": side,
		"gates": {"main_N": 1.0, "side_N": 1.0, "main_S": 1.0, "side_S": 1.0}, "crystal_N": 1.0, "crystal_S": 1.0,
		"plan": {side: "pinca" if attack else "muralha", enemy: "muralha" if attack else "martelo"},
		"commander": {side: 1000, enemy: 1100}, "player_commands": false, "score": {}, "cannons": [],
		"roster": rs, "player_role": "", "respawn_in": 0.0,
		"guilds": {side: {"id": guild["id"], "name": guild["name"], "tag": guild["tag"], "crest": 0},
			enemy: {"id": "g_1", "name": "Lobos de Ferro", "tag": "LDF", "crest": 1}}}

## Canhão ao lado do jogador (dica "F para operar").
func add_cannon(id: int, pos: Vector3, side: String, operator_id: int = -1, cd: float = 0.0) -> void:
	objs.append({"id": id, "type": "cannon", "key": "cannon_%s_01" % side, "side": side, "pos": pos, "alive": true, "operator_id": operator_id, "cd": cd})
