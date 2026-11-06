extends Node
## Invocações em combate (calibrar a IA dos pets): para cada monstro invocável das skills, o dono fica parado
## e a invocação tem que achar os alvos sozinha, defender o dono e (se atira) manter distância.
##   godot --headless --path . tools/tests/pet_probe.tscn -- [--only=fire_elemental,...] [--verbose]
## Saída: "PET <id> 1o_golpe=Ss sem_alvo=P% dist=Dm defende=sim|NAO" e FLAG quando passa do limite.

const DT := 1.0 / 20.0
const MAP := "field_forest"
const SPOT := Vector3(-90, 0, 9)      # entrada oeste da floresta: chão aberto
const FIRST_HIT_MAX := 3.0
const IDLE_MAX := 0.15
const RANGED_MIN := 3.0

func _ready() -> void:
	await get_tree().process_frame
	var only: Array = []
	var verbose := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="): only = Array(a.get_slice("=", 1).split(","))
		if a == "--verbose": verbose = true
	var flags := 0
	for pair in _summons():
		var mid: String = pair[0]
		if not only.is_empty() and not (mid in only):
			continue
		flags += _run(mid, pair[1], verbose)
	print("PET_END flags=%d" % flags)
	get_tree().quit()

## [monster_id, classe] de cada skill com efeito summon (sem repetir o monstro).
func _summons() -> Array:
	var seen := {}
	var out: Array = []
	for sid in GameData.skills:
		var s: SkillDef = GameData.skills[sid]
		var sm: Dictionary = s.effects.get("summon", {})
		var mid: String = sm.get("monster_id", "")
		if mid == "" or seen.has(mid) or s.class_id == "":
			continue
		seen[mid] = true
		out.append([mid, s.class_id])
	return out

func _clear(m: Dictionary) -> void:
	m["spawners"].clear()
	for e in m["entities"].duplicate():
		if e.kind != SimEntity.Kind.NPC:
			Sim.despawn(e)

## Boneco parado com muita vida (sem cérebro), no ponto dado.
func _dummy(at: Vector3) -> SimEntity:
	var d: SimEntity = Sim.spawn_monster(GameData.monsters["wolf"], MAP, at)
	d.brain = null
	d.stats.max_hp = 50000.0
	d.hp = 50000.0
	return d

func _run(mid: String, cid: String, verbose: bool) -> int:
	var mdef: MonsterDef = GameData.monsters[mid]
	var m: Dictionary = Sim.load_map(GameData.maps[MAP])
	_clear(m)
	var owner: SimEntity = Sim.spawn_bot(GameData.classes[cid], "Dono", MAP, SPOT, 20)
	owner.brain = null
	owner.stats.max_hp = 50000.0
	owner.hp = 50000.0
	var pet: SimEntity = Sim.spawn_summon(owner, mdef, SPOT + Vector3(1, 0, 0), 0.0, mid == "companion")
	# 1) sozinho: três bonecos a 8 m do dono
	var dummies: Array = []
	for i in range(3):
		dummies.append(_dummy(SPOT + Vector3(8, 0, -3 + 3 * i)))
	var t := 0.0
	var first := INF
	var idle := 0
	var ticks := 0
	var dist_sum := 0.0
	var dist_n := 0
	while t < 15.0:
		Sim.tick(DT)
		t += DT
		ticks += 1
		var hit := false
		for d in dummies:
			if d.hp < d.stats.max_hp - 0.5:      # o crédito do dano vai para o dono; mede pela vida do boneco
				hit = true
		if hit and first == INF:
			first = t
		if pet.aggro_target < 0:
			idle += 1
		else:
			var tg: SimEntity = Sim.entities.get(pet.aggro_target)
			if tg:
				dist_sum += pet.position.distance_to(tg.position) - tg.radius
				dist_n += 1
	var idle_pct := float(idle) / maxf(1.0, ticks)
	var dist := dist_sum / maxf(1.0, dist_n)
	# 2) defende: um lobo de verdade aparece atrás do dono e o ataca
	for d in dummies:
		Sim.despawn(d)
	var wolf: SimEntity = Sim.spawn_monster(GameData.monsters["wolf"], MAP, SPOT + Vector3(-5, 0, 0))
	wolf.aggro_target = owner.id
	wolf.aggro_timer = 10.0
	var defends := false
	t = 0.0
	while t < 4.0 and wolf.is_alive():
		Sim.tick(DT)
		t += DT
		if pet.aggro_target == wolf.id:
			defends = true
	var flag := first > FIRST_HIT_MAX or idle_pct > IDLE_MAX or not defends or (mdef.ranged and dist < RANGED_MIN)
	print("PET %-16s %-12s 1o_golpe=%.1fs sem_alvo=%.0f%% dist=%.1fm defende=%s skills=%d%s" % [mid, cid, first, idle_pct * 100.0, dist,
		"sim" if defends else "NAO", pet.skills.size(), "  FLAG" if flag else ""])
	if verbose:
		print("   pet hp=%.0f patk=%.0f matk=%.0f ranged=%s" % [pet.hp, pet.stats.patk, pet.stats.matk, str(mdef.ranged)])
	_clear(m)
	Sim.despawn(owner)
	return 1 if flag else 0
