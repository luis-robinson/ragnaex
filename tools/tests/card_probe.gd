extends Node
## Sonda das cartas (só mede, não julga). GDD design/gdd/cartas.md §4.
##   godot --headless --path . tools/tests/card_probe.tscn -- --dump            (monstros: nível, xp, chefe, mapas)
##   godot --headless --path . tools/tests/card_probe.tscn -- [--maps=a,b] [--minutes=20] [--class=<id>] [--level=N] [--per_mob]
## --level = nível do bot (sem ele: meio da faixa do mapa); --per_mob = linha CARDMOB por monstro (abates/h, cartas/h da carta
## dele, horas esperadas para 1 carta); Ato II: --maps=field_coast --level=32, field_steppe 38, field_kharzun 43 (cartas-ato2.md).
## CARD <mapa> nv=L abates/h=K cartas/h esperadas=E (soma das chances de cada abate) sorteadas=S; meta D3: 2-3/h.
## Um bot caçando sozinho no mapa (como farm_probe): o número depende do ritmo de caça do bot.

const DT := 1.0 / 20.0
var _level := 0
var _per_mob := false
const MAPS := ["field_crab_beach", "field_hollow", "city_aldara", "dg_catacumbas", "field_forest", "field_marsh", "field_grove",
	"elf_city", "field_ruins", "field_oaths"]

func _ready() -> void:
	await get_tree().process_frame
	var args := OS.get_cmdline_user_args()
	if "--dump" in args:
		_dump()
		get_tree().quit()
		return
	var maps: Array = MAPS.duplicate()
	var minutes := 20.0
	var cls := "berserker"
	for a in args:
		if a.begins_with("--level="): _level = int(a.get_slice("=", 1))
		if a == "--per_mob": _per_mob = true
		if a.begins_with("--maps="): maps = Array(a.get_slice("=", 1).split(","))
		if a.begins_with("--minutes="): minutes = float(a.get_slice("=", 1))
		if a.begins_with("--class="): cls = a.get_slice("=", 1)
	Sim.rng.seed = 7
	var tot := [0, 0.0, 0, 0.0]              # abates, esperadas, sorteadas, horas
	for mid in maps:
		var r := _run_map(str(mid), cls, minutes)
		if r.is_empty():
			continue
		tot[0] += r[0]; tot[1] += r[1]; tot[2] += r[2]; tot[3] += minutes / 60.0
	if tot[3] > 0.0:
		print("CARD TOTAL abates/h=%.0f cartas/h esperadas=%.2f sorteadas=%.2f (meta 2-3)" % [tot[0] / tot[3], tot[1] / tot[3], tot[2] / tot[3]])
	get_tree().quit()

func _run_map(map_id: String, cls: String, minutes: float) -> Array:
	if not GameData.maps.has(map_id):
		print("CARD mapa desconhecido %s (NAO MEDIDO)" % map_id)
		return []
	Sim.reset_world()
	var md: MapDef = GameData.maps[map_id]
	Sim.load_map(GameData.maps[GameData.town_map_id()])
	Sim.load_map(md)
	for i in range(200):
		Sim.tick(DT)
	var level: int = _level if _level > 0 else clampi(int(round((md.level_range.x + md.level_range.y) * 0.5)), 1, 50)
	var b: SimEntity = Sim.spawn_bot(GameData.classes[cls], "Cartas", map_id, Sim.random_walkable(md, md.spawn_point, 3.0), level)
	b.brain.state = BotBrain.S.HUNT
	b.brain.timer = 99999.0
	var st := [0, 0.0, 0]
	var per := {}                            # monstro (base) -> [abates, cartas esperadas]
	var on_died := func(eid: int, killer: int) -> void:
		var e: SimEntity = Sim.entities.get(eid)
		var k: SimEntity = Sim.entities.get(killer)
		if e == null or e.kind != SimEntity.Kind.MONSTER or e.map_id != map_id or k == null or (k != b and k.owner_id != b.id):
			return
		st[0] += 1
		var cid := CardSystem.card_for_mob(e)
		var key: String = cid if cid != "" else "-" + e.monster_def.id
		if not per.has(key):
			per[key] = [0, 0.0]
		per[key][0] += 1
		if cid != "":
			var pc := CardSystem.drop_chance(Sim, b, e, cid)
			st[1] += pc
			per[key][1] += pc
	var on_loot := func(m_id: String, _p: Vector3, item_id: String, _c: int) -> void:
		if m_id == map_id and item_id.begins_with("card_"):
			st[2] += 1
	Events.entity_died.connect(on_died)
	Events.loot_dropped.connect(on_loot)
	var t := 0.0
	while t < minutes * 60.0:
		Sim.tick(DT)
		t += DT
	Events.entity_died.disconnect(on_died)
	Events.loot_dropped.disconnect(on_loot)
	var h := minutes / 60.0
	print("CARD %s nv=%d abates/h=%.0f cartas/h esperadas=%.2f sorteadas=%.1f " % [map_id, level, st[0] / h, st[1] / h, st[2] / h])
	if _per_mob:
		var keys := per.keys()
		keys.sort_custom(func(x, y): return per[x][0] > per[y][0])
		for k in keys:
			var rate: float = per[k][1] / h
			var cd: CardDef = GameData.cards.get(k)
			print("CARDMOB %s %s%s abates/h=%.0f cartas/h=%.3f horas_por_carta=%s" % [map_id, k, (" (núcleo)" if cd and cd.core else ""),
				per[k][0] / h, rate, ("%.1f" % (1.0 / rate)) if rate > 0.0 else "-"])
	return st

func _dump() -> void:
	var where := {}
	for mid in GameData.maps:
		var md: MapDef = GameData.maps[mid]
		for sp in md.spawners:
			var k := str(sp.get("monster_id", ""))
			if not where.has(k):
				where[k] = []
			if not (mid in where[k]):
				where[k].append("%s[%d-%d]" % [mid, md.level_range.x, md.level_range.y])
	var ids := GameData.monsters.keys()
	ids.sort_custom(func(a, b): return GameData.monsters[a].level < GameData.monsters[b].level or (GameData.monsters[a].level == GameData.monsters[b].level and str(a) < str(b)))
	for mid in ids:
		var m: MonsterDef = GameData.monsters[mid]
		print("MOB %s|%s|lv%d|xp%d|boss=%s|elite=%s|shift=%d|dummy=%s|decoy=%s|egg=%s|role=%s|escort=%s|ranged=%s|regen=%.1f|%s" % [mid, m.name, m.level, m.xp, m.is_boss, m.elite_of, m.shift_forms.size(), m.dummy, m.decoy, m.egg, m.stat_role, not m.escort.is_empty(), m.ranged, m.regen, ",".join(where.get(mid, []))])
