extends Node
## Testes headless da simulação:
##   godot --headless --path . tools/tests/tests.tscn
## Cobre catálogo, fórmulas, bloqueio, XP, loot, quests, crafting, mira de skills e 3000 ticks de mundo com bots.
## Só uma parte (iterar rápido):  ... tools/tests/tests.tscn -- --only=party,shield
##   roda cada `_check_*` cujo nome contém um dos pedaços (com o que ele chama dentro); o run completo continua obrigatório.

var fails := 0
var passes := 0
var gd_ref
var save_ref

func check(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
	else:
		fails += 1
		push_error("FAIL: " + msg)
		print("FAIL: " + msg)

func _ready() -> void:
	Sim.running = false
	var only := DevArgs.value("--only")
	if only != "":
		run_only(Array(only.split(",")), GameData, Sim, SaveSystem)
	else:
		run_all(GameData, Sim, Balance, SaveSystem)
	print("\n=== %d passed, %d failed ===" % [passes, fails])
	get_tree().quit(1 if fails > 0 else 0)

## Formas de bicho: todo gesto que EntityView.FORM_CLIP manda para o animal existe no modelo (senão toda skill vira a mesma mordida);
## a forma demoníaca tem os clipes do kit (sombra, buffs, giro...).
func _check_form_clips() -> void:
	for form in ["wolf", "bear"]:
		var fm := FormModel.create(form)
		check(fm != null and fm.anim != null, "forma %s carrega" % form)
		if fm == null:
			continue
		for want in EntityView.FORM_CLIP.values():
			check(fm.anim.has_animation(want), "forma %s tem o clipe '%s'" % [form, want])
		for want in EntityView.IMPACT_FRAME.keys().filter(func(k): return k in EntityView.FORM_CLIP.values()):
			check(EntityView.IMPACT_FRAME[want] * 1.0 / 24.0 < fm.anim.get_animation(want).length, "forma %s: impacto de '%s' dentro do clipe" % [form, want])
		# golpe andando: as patas correm por cima do clipe (LegOverlay), senão o bicho desliza
		check(fm.legs != null and fm.legs._tracks.size() >= 4, "forma %s: patas correm por cima do golpe" % form)
		# rabo com osso próprio: balança no idle e ondula na corrida (mob_kit.quad_motion)
		check(fm.skeleton.find_bone("tail") >= 0, "forma %s tem osso de rabo" % form)
		for clip in ["idle", "run"]:
			var an := fm.anim.get_animation(clip)
			var tt := -1
			for t in range(an.get_track_count()):
				if an.track_get_type(t) == Animation.TYPE_ROTATION_3D and String(an.track_get_path(t).get_subname(0)) == "tail":
					tt = t
			var swing := 0.0
			if tt >= 0:
				var q0 := an.rotation_track_interpolate(tt, 0.0)
				for i in range(12):
					swing = maxf(swing, rad_to_deg(q0.angle_to(an.rotation_track_interpolate(tt, an.length * i / 12.0))))
			check(swing > 5.0, "forma %s: rabo mexe no '%s' (%.0f°)" % [form, clip, swing])
		fm.free()
	var dm := FormModel.create("demon")
	if dm:
		for want in ["cast_shadow", "atk_spin", "buff_power", "atk_sweep", "cast"]:
			check(dm.anim.has_animation(want), "forma demoníaca tem '%s'" % want)
		dm.free()

## Preparo curto: o clipe começa no meio da preparação (não corre mais que WINDUP_MAX_SPEED) e o impacto cai no fim do preparo.
func _check_windup_timing() -> void:
	for pair in [[0.375, 0.12], [0.29, 0.12], [0.33, 0.5], [0.2, 0.06]]:
		var wt := EntityView.windup_timing(pair[0], pair[1])
		check(wt.x >= 0.0 and wt.y <= EntityView.WINDUP_MAX_SPEED + 0.001, "preparo %.2f/%.2f: velocidade %.2f limitada" % [pair[0], pair[1], wt.y])
		if wt.y > EntityView.ANIM_MIN_SPEED + 0.001:
			check(absf((pair[0] - wt.x) / wt.y - pair[1]) < 0.01, "preparo %.2f/%.2f: impacto no fim do preparo" % pair)

## Troca de clipe: kit e bicho têm PoseFade; o deslize parte da pose congelada e chega no clipe novo pelo caminho curto
## (a mistura do AnimationPlayer passava pelo repouso e virava a mão do avesso num quadro).
func _check_pose_fade() -> void:
	var k := KitModel.create("male", Color.WHITE, 0.025, "paladin")
	add_child(k)                       # o modificador só acha o esqueleto na árvore
	check(k.fade != null and k.legs != null and k.fade.get_index() < k.legs.get_index(), "kit: PoseFade antes das pernas")
	var sk := k.skeleton
	var hand := sk.find_bone("hand.R")
	var q0 := Quaternion(Vector3.UP, deg_to_rad(10.0))
	var q1 := Quaternion(Vector3.UP, deg_to_rad(170.0))
	sk.set_bone_pose_rotation(hand, q0)
	k.fade.start(0.1)
	sk.set_bone_pose_rotation(hand, q1)
	check(k.fade.shown_rotation(sk, hand).angle_to(q0) < 0.01, "deslize começa na pose congelada")
	var prev := q0
	var worst := 0.0
	for i in range(8):
		k.fade.tick(1.0 / 60.0)
		var q := k.fade.shown_rotation(sk, hand)
		worst = maxf(worst, rad_to_deg(prev.angle_to(q)))
		prev = q
	check(prev.angle_to(q1) < 0.01 and not k.fade.active, "deslize chega no clipe novo e desliga")
	check(worst < 60.0, "deslize de 160° em 6 quadros sem salto (%.0f°/quadro)" % worst)
	k.free()
	var fm := FormModel.create("wolf")
	if fm:
		check(fm.fade != null, "forma de bicho tem PoseFade")
		fm.free()

## Mão sem voltas: chaves em quaternião com giro limitado (chibi_kit.QUAT_BONES/HAND_MAX_TURN). Em Euler a mão girava
## 600-1900° por clipe e virava a arma 155-176° em 1 quadro. Medido a 60 Hz, velocidade 1.
func _check_hand_twist() -> void:
	var inst: Node = (load("res://assets/models/kit_paladin_male.glb") as PackedScene).instantiate()
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	var worst := 0.0
	var where := ""
	var flurry := 0.0
	for clip in ap.get_animation_list():
		var an := ap.get_animation(clip)
		for t in range(an.get_track_count()):
			if an.track_get_type(t) != Animation.TYPE_ROTATION_3D or not String(an.track_get_path(t).get_subname(0)).begins_with("hand"):
				continue
			var prev := an.rotation_track_interpolate(t, 0.0)
			var tt := 1.0 / 60.0
			var total := 0.0
			while tt <= an.length + 0.0001:
				var q := an.rotation_track_interpolate(t, tt)
				var d := rad_to_deg(prev.angle_to(q))
				total += d
				if d > worst:
					worst = d
					where = "%s %s" % [clip, an.track_get_path(t).get_subname(0)]
				prev = q
				tt += 1.0 / 60.0
			if clip == "atk_flurry":
				flurry = maxf(flurry, total)
	check(worst < 45.0, "mão: no máximo 45°/quadro a 60 Hz (pior %.0f° em %s)" % [worst, where])
	check(flurry > 0.0 and flurry < 1000.0, "mão: atk_flurry não dá voltas (%.0f° no clipe)" % flurry)
	inst.free()

## Maestria: a descrição diz o que cada nível melhora naquela skill (tirada dos dados), não um "+1 nível" genérico.
func _check_mastery_desc() -> void:
	var bad: Array = []
	var extras := 0
	for sid in GameData.skills:
		var sk: SkillDef = GameData.skills[sid]
		var d := TreeCatalog.mastery_desc(sk)
		if not ("MP" in d and "recarga" in d) or (("poder" in d) != (sk.power > 0.0)):
			bad.append(sid)
		if sk.effects.has("form") and not ("bônus da forma" in d):
			bad.append(sid + "(forma)")
		if "Nível " in d:
			extras += 1
	check(bad.is_empty(), "maestria: descrição certa em todas as skills (%s)" % [bad.slice(0, 5)])
	check(extras >= 4, "maestria: efeitos extras por nível aparecem na descrição (%d)" % extras)
	if DevArgs.has("--verbose"):
		for sid in ["nec_phantom", "nec_reap", "dru_bear_form"]:
			if GameData.skills.has(sid):
				print("  MAESTRIA %s: %s" % [sid, TreeCatalog.mastery_desc(GameData.skills[sid])])

## Menu Esc → Gráficos: o 1º preset é o padrão de sempre (bilinear, escala automática); os FSR 2 renderizam abaixo de 100%.
func _check_graphics_settings() -> void:
	var ps: Array = GraphicsSettings.PRESETS
	check(ps.size() >= 2 and ps[0][1] == Viewport.SCALING_3D_MODE_BILINEAR and float(ps[0][2]) < 0.0, "gráficos: padrão = Nítido automático")
	for p in ps.slice(1):
		check(p[1] == Viewport.SCALING_3D_MODE_FSR2 and float(p[2]) > 0.3 and float(p[2]) < 1.0, "gráficos: %s renderiza abaixo da tela" % p[0])
	check(GraphicsSettings.preset == 0 or FileAccess.file_exists(GraphicsSettings.PATH), "gráficos: sem arquivo salvo começa no padrão")

## `--only`: chama direto os `_check_*` que batem com algum pedaço, montando os argumentos pelo nome (gd, sim, save).
func run_only(tokens: Array, gd, sim, save) -> void:
	gd_ref = gd
	save_ref = save
	save.slot = TEST_SLOT
	for mid in gd.maps:            # o mesmo mundo do run_all: todos os mapas e um jogador na cidade
		sim.load_map(gd.maps[mid])
	sim.spawn_player(gd.classes["berserker"], "Tester", "city_aldara")
	var by_name := {"gd": gd, "sim": sim, "save": save}
	var ran := 0
	for m in get_method_list():
		var mname: String = m["name"]
		if not mname.begins_with("_check_") or not tokens.any(func(t): return t != "" and mname.contains(t)):
			continue
		var args: Array = []
		var ok := true
		for a in m["args"]:
			if not by_name.has(a["name"]):
				ok = false          # pede algo que só o chamador sabe (ex.: um monstro): roda junto do pai
				break
			args.append(by_name[a["name"]])
		if not ok:
			continue
		print("--- %s" % mname)
		callv(mname, args)
		ran += 1
	save.delete_slot(TEST_SLOT)
	print("--only: %d grupos" % ran)

const HOSTILE_HUBS := ["elf_city"]      # zonas cujo hub é a cidade inimiga (sem serviços; spawners dentro do muro)
const TEST_SLOT := 90       # espaço só dos testes (fora dos SLOTS da tela inicial): nunca toca nos personagens do jogador

func run_all(gd, sim, balance, save) -> void:
	gd_ref = gd
	save_ref = save
	save.slot = TEST_SLOT
	# ---- catálogo ----
	check(gd.classes.size() == 8, "8 classes")
	check(gd.skills.size() >= 48, "48+ skills (tem %d)" % gd.skills.size())
	for cid in gd.classes:
		var c = gd.classes[cid]
		check(c.skill_ids.size() >= 20, "classe %s tem 20+ skills (%d)" % [cid, c.skill_ids.size()])
		for sid in c.skill_ids:
			check(gd.skills.has(sid), "skill %s existe" % sid)
		for eid in c.starting_equipment:
			check(gd.items.has(eid), "item inicial %s existe" % eid)
	_check_builds(gd)
	for mid in gd.monsters:
		var m = gd.monsters[mid]
		check(m.loot_table == "" or gd.loot_tables.has(m.loot_table), "loot table de %s" % mid)
		for sid in m.skill_ids:
			check(gd.skills.has(sid), "skill de monstro %s" % sid)
	for lid in gd.loot_tables:
		for e in gd.loot_tables[lid].entries:
			check(gd.items.has(e["item"]), "loot %s item %s" % [lid, e["item"]])
	for qid in gd.quests:
		var q = gd.quests[qid]
		if q.type == QuestDef.Type.KILL: check(gd.monsters.has(q.target_id), "quest %s alvo" % qid)
		if q.type == QuestDef.Type.COLLECT or q.type == QuestDef.Type.CRAFT: check(gd.items.has(q.target_id), "quest %s item" % qid)
		for iid in q.reward_items: check(gd.items.has(iid), "quest %s recompensa %s" % [qid, iid])
		if q.prereq_quest != "": check(gd.quests.has(q.prereq_quest), "quest %s prereq" % qid)
	for rid in gd.recipes:
		var r = gd.recipes[rid]
		check(gd.items.has(r.result_item), "receita %s resultado" % rid)
		for iid in r.ingredients: check(gd.items.has(iid), "receita %s ingrediente %s" % [rid, iid])
	for mid in gd.maps:
		var md = gd.maps[mid]
		for p in md.portals: check(gd.maps.has(p["target_map"]), "portal %s/%s" % [mid, p["id"]])
		for sp in md.spawners: check(gd.monsters.has(sp["monster_id"]), "spawner %s/%s" % [mid, sp["monster_id"]])
		for n in md.npcs:
			for iid in n.get("shop", []): check(gd.items.has(iid), "loja %s item %s" % [n["id"], iid])
	# NPCs referenciados por quests existem em algum mapa
	var npc_ids := {}
	for mid in gd.maps:
		for n in gd.maps[mid].npcs:
			npc_ids[n["id"]] = true
	for qid in gd.quests:
		var q = gd.quests[qid]
		check(npc_ids.has(q.giver_npc), "quest %s giver %s existe" % [qid, q.giver_npc])
		check(npc_ids.has(q.turnin()), "quest %s turnin existe" % qid)
		if q.type == QuestDef.Type.TALK: check(npc_ids.has(q.target_id), "quest %s talk npc" % qid)

	# ---- fórmulas ----
	var pal = gd.classes["paladin"]
	var eq := {}
	for iid in pal.starting_equipment:
		var it = gd.items[iid]
		eq[it.slot] = it
	var st = Stats.compute(pal, 1, eq, [])
	check(st.attrs["FOR"] == 5 and st.attrs["VIT"] == 5 and st.attrs["AGI"] == 0, "atributos do paladino vêm do equipamento (FOR=%d VIT=%d)" % [st.attrs["FOR"], st.attrs["VIT"]])
	check(st.has_shield and st.block_chance > 12.0, "escudo dá chance de bloqueio")
	check(st.max_hp == pal.base_hp + 5 * balance.HP_PER_VIT, "HP = base + VIT*12")
	var ran = gd.classes["ranger"]
	var eq2 := {}
	for iid in ran.starting_equipment:
		eq2[gd.items[iid].slot] = gd.items[iid]
	var st2 = Stats.compute(ran, 1, eq2, [])
	check(st2.is_ranged_weapon and st2.patk > 7.0, "arco usa AGI")
	check(balance.xp_for_level(1) > 0 and balance.xp_for_level(2) > balance.xp_for_level(1) and balance.xp_for_level(30) == 0, "curva de XP")
	check(balance.xp_for_level(29) > balance.xp_for_level(1) * 80, "progressão lenta (lv29 >> lv1)")

	# ---- mundo ----
	for mid in gd.maps:
		sim.load_map(gd.maps[mid])
	var p = sim.spawn_player(gd.classes["berserker"], "Tester", "city_aldara")
	check(p.skills.size() == 6 and p.basic_skill != null, "player criado com skills e ataque básico")
	check(p.skills[0] != null and p.skills[0].id == "ber_cleave" and p.knows("ber_bloodlust") and p.skills[2] == null, "começa com 2 skills de nível 1 e 4 slots vazios")
	var bot = sim.spawn_bot(gd.classes["bishop"], "Bot1", "city_aldara", Vector3(3, 0, 3), 5)
	check(bot.brain != null and bot.level == 5, "bot criado")
	# monstro de teste perto do player
	var slime = sim.spawn_monster(gd.monsters["slime"], "city_aldara", p.position + Vector3(0, 0, 1.5))
	var cmd := InputCommand.new()
	cmd.aim = slime.position
	cmd.attack = true
	sim.set_player_command(cmd)
	sim.running = true
	var hp0 = slime.hp
	for i in range(40):
		sim.tick(1.0 / 60.0)
		if i == 0:
			cmd = InputCommand.new(); cmd.aim = slime.position
			sim.set_player_command(cmd)
	check(slime.hp < hp0, "ataque básico causa dano (hp %d -> %d)" % [hp0, slime.hp])
	# skill em cone (ber_cleave) deve acertar
	var slime2 = sim.spawn_monster(gd.monsters["slime"], "city_aldara", p.position + Vector3(1.0, 0, 1.5))
	var hp2 = slime2.hp
	cmd = InputCommand.new(); cmd.aim = slime2.position; cmd.skill_slot = 0
	sim.set_player_command(cmd)
	for i in range(60):
		sim.tick(1.0 / 60.0)
		if i == 0:
			cmd = InputCommand.new(); cmd.aim = slime2.position; sim.set_player_command(cmd)
	check(slime2.hp < hp2, "skill 1 (cone) causa dano")
	check(p.cooldowns.get("ber_cleave", 0.0) > 0.0, "skill entrou em cooldown")
	# ground target fora do alcance é clampado
	var aim: Vector3 = p.position + Vector3(50, 0, 0)
	var c := Combat.clamp_aim(p, aim, 6.0)
	check(absf(c.distance_to(p.position) - 6.0) < 0.01, "clamp de mira no alcance")
	# bloqueio reduz dano
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	var wolf = sim.spawn_monster(gd.monsters["wolf"], "city_aldara", p.position + Vector3(0, 0, 8))
	p.is_blocking = false
	var d_open := 0; var d_block := 0
	for i in range(200):
		d_open += Combat.calc_damage(wolf, p, 1.0, 0, rng)["amount"]
	p.is_blocking = true
	for i in range(200):
		d_block += Combat.calc_damage(wolf, p, 1.0, 0, rng)["amount"]
	p.is_blocking = false
	check(d_block < d_open * 0.7, "bloqueio ativo reduz dano (%d vs %d)" % [d_block, d_open])
	# XP e level
	var lv0 = p.level
	sim.gain_xp(p, Balance.band_xp(p.level, 3) - p.xp)          # chega no nível 3
	check(p.level > lv0 and p.mastery_points > 0, "XP sobe nível e dá maestria (lv %d, pts %d)" % [p.level, p.mastery_points])
	check(sim.upgrade_mastery(p, "ber_cleave") and p.mastery["ber_cleave"] == 1, "maestria sobe com pontos")
	_check_skill_points(gd, sim, p)
	# loot/quests/craft
	var elder_quests = QuestSystem.available_from_npc(p, "elder")
	check(elder_quests.size() >= 1, "ancião oferece quest")
	QuestSystem.accept(p, gd.quests["q01_welcome"])
	QuestSystem.on_talk(p, "captain")
	check(QuestSystem.is_complete(p, gd.quests["q01_welcome"]), "quest TALK completa")
	QuestSystem.complete(p, gd.quests["q01_welcome"], sim)
	check("q01_welcome" in p.quests_completed, "quest entregue")
	QuestSystem.accept(p, gd.quests["q02_slimes"])
	for i in range(6):
		QuestSystem.on_kill(p, "slime")
	check(QuestSystem.is_complete(p, gd.quests["q02_slimes"]), "quest KILL completa")
	p.add_item("herb_green", 1); p.add_item("slime_gel", 1)
	check(CraftSystem.craft(p, gd.recipes["rec_potion_hp_s"]), "craft de poção")
	check(p.has_item("potion_hp_s", 7), "poção craftada no inventário")
	var g0 = p.gold
	check(CraftSystem.buy(p, "potion_mp_s", 1) and p.gold == g0 - 18, "compra na loja")
	# equipar
	p.add_item("axe_iron", 1)
	p.level = 8
	check(sim.equip(p, "axe_iron") and p.equipment[ItemDef.Slot.WEAPON].id == "axe_iron", "equipar arma")
	check(p.has_item("axe_old"), "arma antiga volta pra bolsa")
	# poção
	p.hp = 10
	check(sim.use_potion(p, 0) and p.hp > 10, "poção F1 cura")
	# invocação do necro
	var nec = sim.spawn_bot(gd.classes["necromancer"], "Necro", "city_aldara", Vector3(-5, 0, -5), 10)
	nec.brain = null
	sim._apply_skill(nec, gd.skills["nec_raise"], sim.maps["city_aldara"])
	var summons := 0
	for e in sim.map_entities("city_aldara"):
		if e.kind == SimEntity.Kind.SUMMON and e.owner_id == nec.id:
			summons += 1
	check(summons == 2, "necro invoca 2 esqueletos (%d)" % summons)
	# ---- simulação longa com bots em todos os mapas ----
	var names: Array = gd.bot_names.duplicate()
	var classes: Array = gd.class_list()
	var k := 0
	for mid in gd.maps:
		var md = gd.maps[mid]
		for i in range(md.bot_population):
			var cls = classes[k % classes.size()]
			var lv := rng.randi_range(md.level_range.x, md.level_range.y)
			sim.spawn_bot(cls, names[k % names.size()], mid, sim.random_walkable(md, md.spawn_point, 6.0), lv)
			k += 1
	var cmd0 := InputCommand.new(); cmd0.aim = p.position + Vector3(0, 0, 1)
	sim.set_player_command(cmd0)
	var t0 := Time.get_ticks_msec()
	for i in range(3000):
		sim.tick(1.0 / 60.0)
	var ms := Time.get_ticks_msec() - t0
	print("3000 ticks com %d entidades em %d ms (%.2f ms/tick)" % [sim.entities.size(), ms, ms / 3000.0])
	check(ms < 32000, "performance da simulação (%d ms; todos os mapas cheios e a todo vapor, sem o jogador)" % ms)
	var alive_bots := 0
	for e in sim.entities.values():
		if e.kind == SimEntity.Kind.BOT:
			alive_bots += 1
	check(alive_bots == k + 2, "bots sobrevivem/renascem (%d de %d)" % [alive_bots, k + 2])
	# NaN check
	for e in sim.entities.values():
		check(is_finite(e.position.x) and is_finite(e.position.z) and is_finite(e.hp), "posição/hp finitos em %s" % e.name)
	# save/load
	save.save_player(p)
	var d = save.load_data()
	check(d.get("class", "") == "berserker" and int(d.get("level", 0)) == 8, "save/load")
	check(d.get("learned", []).has("ber_leap") and d.get("loadout", []).size() == 6, "save guarda skills aprendidas e barra")
	# espaços de personagem: cada um num arquivo; o dos testes não aparece na tela inicial
	check(save.has_slot(TEST_SLOT) and save.slot_summary(TEST_SLOT).get("class") == "berserker", "espaço salvo tem resumo (classe/nível)")
	var listed := false
	for i in range(save.SLOTS):
		listed = listed or save.path_of(i) == save.path_of(TEST_SLOT)
	check(not listed and save.path_of(TEST_SLOT) != save.PATH, "espaço dos testes fora da lista e do save antigo")
	var keep_slot: int = save.slot
	save.slot = -1
	save.save_player(p)
	check(not save.has_slot(-1), "slot -1 (--autostart) não grava")
	save.slot = keep_slot
	save.delete_slot(TEST_SLOT)
	check(not save.has_slot(TEST_SLOT), "excluir espaço apaga só ele")
	_check_zone(gd, sim)
	_check_character_models(gd, sim)
	_check_jump(gd, sim)
	_check_tree(gd, sim, save)
	_check_skill_visuals(gd)
	_check_party(gd, sim)
	_check_threat_loot(gd, sim)
	_check_self_aoe(gd, sim)
	_check_review_fixes(gd, sim)
	_check_boss_kit(gd, sim)
	_check_tent_cloth()
	_check_item_icons(gd)
	_check_tree_spacing()
	_check_dungeon_mood(gd)
	_check_portal_gates()
	_check_progression(gd, sim)
	_check_arc(gd, sim, save_ref)
	_check_build_depth(gd, sim)
	_check_water(gd, sim)
	_check_outdoor(gd)
	_check_graphics_settings()
	_check_form_clips()
	_check_windup_timing()
	_check_pose_fade()
	_check_hand_twist()
	_check_mastery_desc()
	# builds: paladino = tanque (escudo) ou 2 mãos; berserker = 2 mãos ou duas armas de 1 mão (machado/espada misturados)
	var pb: Array = gd.classes["paladin"].builds.map(func(b): return b["id"])
	check(pb == ["guardiao", "cruzado"], "paladino tem só Guardião e Cruzado (%s)" % [pb])
	var bb: Array = gd.classes["berserker"].builds.map(func(b): return b["id"])
	check(bb.size() == 2 and "carniceiro" in bb and "executor" in bb, "berserker tem só Armas Gêmeas e Executor (%s)" % [bb])
	check(not ("sword" in gd.classes["paladin"].offhand_types), "paladino não usa espada na mão secundária")
	for sid in gd.skills:
		var sk = gd.skills[sid]
		if sid.begins_with("ber_") and sk.build == "carniceiro":
			check(sk.requires == ["dual"], "%s vale para qualquer par de armas de 1 mão" % sid)


# ---------------------------------------------------------------------------
# builds, skills, evoluções e conjuntos (loops sobre todo o catálogo)
# ---------------------------------------------------------------------------
const WEAPON_TOKENS := ["sword", "sword2h", "mace", "mace2h", "axe", "axe2h", "dagger", "bow", "staff", "wand", "scythe", "scepter", "rifle"]

func _token_ok(r: String) -> bool:
	if r in ["shield", "orb", "dual", "two_handed"] or r in WEAPON_TOKENS:
		return true
	return r.begins_with("dual_") and r.substr(5) in ItemDef.ONE_HANDED_MELEE

## Stats "de mentira" com as armas de uma build (para checar exigências).
func _build_stats(b: Dictionary) -> Stats:
	var st := Stats.new()
	st.weapon_type = b["main"][0]
	st.offhand_type = b["off"][0] if b["off"].size() > 0 else ""
	return st

func _check_builds(gd) -> void:
	var total_builds := 0
	for cid in gd.classes:
		var c: ClassDef = gd.classes[cid]
		check(c.starting_skills.size() == 2, "%s: 2 skills iniciais" % cid)
		var eq := {}
		for iid in c.starting_equipment:
			eq[gd.items[iid].slot] = gd.items[iid]
		var st0 := Stats.compute(c, 1, eq, [])
		for sid in c.starting_skills:
			var s: SkillDef = gd.skills.get(sid)
			check(s != null and s.unlock_level == 1 and s.class_id == cid and st0.meets(s.requires), "%s: skill inicial %s usável no lv1 com o equipamento inicial" % [cid, sid])
		check(c.builds.size() >= 2, "%s: 2+ builds" % cid)
		var build_ids := [""]
		for b in c.builds:
			total_builds += 1
			build_ids.append(b["id"])
			for t in b["main"]:
				check(t in c.weapon_types, "%s/%s: arma %s permitida" % [cid, b["id"], t])
			for t in b["off"]:
				check(t in c.offhand_types, "%s/%s: secundária %s permitida" % [cid, b["id"], t])
			var st := _build_stats(b)
			var usable := 0
			for sid in b["skills"]:
				var s: SkillDef = gd.skills.get(sid)
				check(s != null and s.class_id == cid, "%s/%s: skill %s da classe" % [cid, b["id"], sid])
				if s and st.meets(s.requires):
					usable += 1
			check(usable >= 6, "%s/%s: 6+ skills usáveis com as armas da build (%d)" % [cid, b["id"], usable])
		for sid in c.skill_ids:
			var s: SkillDef = gd.skills[sid]
			check(s.unlock_level >= 1 and s.unlock_level <= Balance.MAX_LEVEL, "%s: nível válido" % sid)
			check(s.build in build_ids, "%s: build '%s' existe" % [sid, s.build])
			for r in s.requires:
				check(_token_ok(r), "%s: exigência '%s' válida" % [sid, r])
			check(s.description != "", "%s: tem descrição" % sid)
		# evoluções
		var has_dash := false
		for t in gd.talents_for_class(cid):
			has_dash = has_dash or t.skill_id == TalentDef.DASH
			check(t.skill_id == TalentDef.DASH or (gd.skills.has(t.skill_id) and gd.skills[t.skill_id].class_id == cid), "%s: evolui skill da classe" % t.id)
			check(t.cost > 0 and t.unlock_level >= 1, "%s: custo/nível" % t.id)
			for r in t.requires:
				check(_token_ok(r), "%s: exigência '%s' válida" % [t.id, r])
		check(has_dash, "%s: tem evolução de dash" % cid)
	# conjuntos lendários: 1 por build a cada 5 níveis
	check(gd.sets.size() == total_builds * Balance.LEGENDARY_LEVELS.size(), "conjuntos = builds x níveis lendários (%d)" % gd.sets.size())
	for set_id in gd.sets:
		var sd: SetDef = gd.sets[set_id]
		check(sd.level in Balance.LEGENDARY_LEVELS, "%s: nível lendário" % set_id)
		check(sd.armor.size() == 5 and sd.pieces.size() >= 6 and sd.pieces.size() <= 7, "%s: 5 peças de armadura (+ armas: %d)" % [set_id, sd.pieces.size()])
		check(sd.armor.any(func(a): return gd.items[a].slot == ItemDef.Slot.LEGS), "%s: tem calça lendária" % set_id)
		for pid in sd.pieces:
			var it: ItemDef = gd.items.get(pid)
			check(it != null and it.is_legendary() and it.set_id == set_id and it.level_req == sd.level and it.class_restriction == [sd.class_id], "%s: peça %s coerente" % [set_id, pid])
		var ks := sd.bonuses.keys()
		ks.sort()
		check(ks == [2, 3, 4, 5], "%s: bônus de 2/3/4/5 peças" % set_id)
		var dmg: Dictionary = sd.bonuses[4].get("skill_dmg", {})
		var cdr: Dictionary = sd.bonuses[5].get("skill_cdr", {})
		for sid in dmg.keys() + cdr.keys():
			var s: SkillDef = gd.skills.get(sid)
			check(s != null and s.class_id == sd.class_id and s.unlock_level <= sd.level, "%s: skill do bônus %s liberada no nível" % [set_id, sid])
		for sid in dmg:
			check(gd.skills[sid].kind in GearCatalog.DAMAGE_KINDS, "%s: bônus de 4 peças em skill de dano/cura" % set_id)
	# exemplo pedido: elementalista de fogo nível 5 -> 3 peças INT +2, 4 peças Bola de Fogo +20%
	var fire: SetDef = gd.sets.get("set_elementalist_fogo_5")
	check(fire != null and fire.bonuses[3]["attrs"].get("INT", 0) == 2 and fire.bonuses[4]["skill_dmg"].get("ele_fireball", 0.0) == 20.0, "conjunto de fogo lv5: INT +2 (3) e Bola de Fogo +20% (4)")
	# todos os tipos de arma pedidos existem em itens comuns
	for t in ["sword", "sword2h", "mace", "mace2h", "axe", "axe2h", "shield", "bow", "wand", "orb"]:
		var n := 0
		for iid in gd.items:
			var it: ItemDef = gd.items[iid]
			if it.weapon_type == t and not it.is_legendary():
				n += 1
		check(n >= 4, "arma %s tem 4+ itens comuns (%d)" % [t, n])

func _check_skill_points(gd, sim, p) -> void:
	var m: Dictionary = sim.maps[p.map_id]
	check(not sim.learn_skill(p, "ber_execute"), "não aprende skill acima do nível")
	var pts: int = p.mastery_points
	check(not sim.learn_skill(p, "ber_leap"), "skill longe na árvore: precisa do caminho até ela")
	var cost := _buy_path(sim, p, "berserker_s_ber_leap")
	check(cost > 0 and p.knows("ber_leap") and p.mastery_points == pts - cost and p.slot_of("ber_leap") == 2, "aprende skill pelo caminho da árvore e vai pro slot livre (custo %d)" % cost)
	check(sim.set_skill_slot(p, 5, "ber_leap") and p.skills[5].id == "ber_leap" and p.skills[2] == null, "move skill na barra (cidade)")
	# arma define a build: Talho Duplo exige dois machados
	p.mastery_points += 5
	check(sim.learn_skill(p, "ber_hack"), "aprende skill de dois machados")
	var slot: int = p.slot_of("ber_hack")
	p.mp = p.stats.max_mp
	check(not sim.try_cast(p, slot, p.position + Vector3(0, 0, 1), m), "Talho Duplo não sai com machado de duas mãos")
	p.add_item("axe_t0", 2)
	check(sim.equip(p, "axe_t0") and sim.equip(p, "axe_t0", true), "empunha dois machados")
	check(p.stats.weapon_type == "axe" and p.stats.offhand_type == "axe" and p.stats.meets(["dual_axe"]), "stats reconhecem duas armas")
	p.mp = p.stats.max_mp
	check(sim.try_cast(p, slot, p.position + Vector3(0, 0, 1), m), "Talho Duplo sai com dois machados")
	sim._end_skill(p)
	check(sim.equip(p, "axe_old") and p.equipment.get(ItemDef.Slot.OFFHAND) == null and p.has_item("axe_t0", 2), "arma de duas mãos libera a mão secundária")
	p.add_item("shield_wood", 1)
	check(not sim.equip(p, "shield_wood"), "berserker não usa escudo")
	check(not sim.learn_talent(p, "ber_t_crash"), "evolução exige nível")
	# evoluções do dash
	var temps: Array = []
	var a = sim.spawn_character(SimEntity.Kind.BOT, gd.classes["assassin"], "TA", "city_aldara", Vector3(-8, 0, 8), 10)
	var e = sim.spawn_character(SimEntity.Kind.BOT, gd.classes["elementalist"], "TE", "city_aldara", Vector3(-9, 0, 8), 10)
	var r = sim.spawn_character(SimEntity.Kind.BOT, gd.classes["ranger"], "TR", "city_aldara", Vector3(-10, 0, 8), 10)
	var pal = sim.spawn_character(SimEntity.Kind.BOT, gd.classes["paladin"], "TP", "city_aldara", Vector3(-11, 0, 8), 10)
	var bis = sim.spawn_character(SimEntity.Kind.BOT, gd.classes["bishop"], "TB", "city_aldara", Vector3(-12, 0, 8), 10)
	var ally = sim.spawn_character(SimEntity.Kind.BOT, gd.classes["ranger"], "TAlly", "city_aldara", Vector3(-12, 0, 10), 10)
	temps = [a, e, r, pal, bis, ally]
	for t in temps:
		t.mastery_points = 10
	check(sim.dash_params(a)["charges"] == 1, "dash normal: 1 carga")
	check(sim.learn_talent(a, "ass_t_double_step") and sim.dash_params(a)["charges"] == 2, "assassino: dash duas vezes seguidas")
	check(sim.learn_talent(e, "ele_t_phase") and sim.dash_params(e)["ghost"], "mago: dash atravessa objetos")
	check(sim.learn_talent(r, "ran_t_roll") and sim.dash_params(r)["distance"] > 1.5, "ranger: rolamento mais longo")
	check(sim.learn_talent(pal, "pal_t_shield_charge") and sim.dash_params(pal)["stun"] > 0.0, "paladino com escudo: dash atordoa")
	sim.unequip(pal, ItemDef.Slot.OFFHAND)
	check(sim.dash_params(pal)["stun"] == 0.0, "sem escudo a evolução do paladino não vale")
	# cura em grupo
	ally.hp = ally.stats.max_hp * 0.3
	var heal: SkillDef = gd.skills["bis_heal"]
	var hp_before: float = ally.hp
	check(sim.party_invite(bis, ally) and sim.party_accept(ally), "bispo e aliado formam grupo")
	sim._apply_skill(bis, sim.resolve_skill(bis, heal), sim.maps["city_aldara"])
	check(ally.hp == hp_before, "Curar sem aliado sob o cursor: em si")
	bis.skill_aim = ally.position
	sim._apply_skill(bis, sim.resolve_skill(bis, heal), sim.maps["city_aldara"])
	check(ally.hp > hp_before, "Curar sob o cursor cura o aliado do grupo")
	bis.skill_aim = Vector3(500, 0, 500)
	hp_before = ally.hp
	check(sim.learn_talent(bis, "bis_t_heal_party"), "compra evolução Cura em Grupo")
	sim._apply_skill(bis, sim.resolve_skill(bis, heal), sim.maps["city_aldara"])
	check(ally.hp > hp_before, "Curar evoluída cura aliado do grupo (%d -> %d)" % [hp_before, ally.hp])
	sim.party_leave(ally)
	ally.hp = ally.stats.max_hp * 0.3
	hp_before = ally.hp
	sim._apply_skill(bis, sim.resolve_skill(bis, heal), sim.maps["city_aldara"])
	check(ally.hp == hp_before, "fora do grupo a cura em área não pega")
	check(gd.skills["bis_heal"].radius == 0.0, "evolução não altera a skill original")
	# conjunto: 3 peças INT +2, 4 peças Bola de Fogo +20%
	var cls: ClassDef = gd.classes["elementalist"]
	var fire: SetDef = gd.sets["set_elementalist_fogo_5"]
	var eq := {}
	var base_int := 0
	for i in range(3):
		var it: ItemDef = gd.items[fire.pieces[i]]
		eq[it.slot] = it
		base_int += it.attr("INT")
	var st3 := Stats.compute(cls, 5, eq, [])
	check(st3.attrs["INT"] == base_int + 2 and st3.skill_power_mult("ele_fireball") == 1.0, "3 peças: INT +2 (%d vs %d)" % [st3.attrs["INT"], base_int])
	var it4: ItemDef = gd.items[fire.pieces[3]]
	eq[it4.slot] = it4
	var st4 := Stats.compute(cls, 5, eq, [])
	check(is_equal_approx(st4.skill_power_mult("ele_fireball"), 1.2), "4 peças: Bola de Fogo +20%")
	# drop lendário
	check(sim.pick_legendary(e, 1) == "", "monstro nível 1 não dropa lendário")
	var leg: String = sim.pick_legendary(e, 30)
	check(leg != "" and gd.items[leg].level_req == 30 and gd.items[leg].class_restriction == ["elementalist"], "dragão (30) dropa lendário nível 30 da classe")
	for t in temps:
		sim.despawn(t)


# ---------------------------------------------------------------------------
# zona estilo Erenshor: Vale de Aldara (vila murada + Campina) vinda do Blender (data/zones/city_aldara.json)
# ---------------------------------------------------------------------------
func _check_zone(gd, sim) -> void:
	var md: MapDef = gd.maps["city_aldara"]
	check(not gd.maps.has("field_meadows"), "Campina agora faz parte do Vale de Aldara")
	check(md.is_town and md.town_radius >= 25.0 and md.town_gates.size() == 4, "vila murada com 4 portões")
	check(md.in_town(Vector3(0, 0, 5)) and not md.in_town(Vector3(0, 0, 60)), "in_town usa a região da vila")
	# muralha fecha a vila fora dos portões; portões abertos (colisão rotacionada = visual)
	var wall_ok := true
	for i in range(72):
		var a := TAU * (i + 0.5) / 72.0
		var q := Vector3(cos(a), 0, sin(a)) * md.town_radius
		var near_gate := false
		for g in md.town_gates:
			if q.distance_to(g) < 6.5:
				near_gate = true
		if not near_gate and sim.is_walkable(q, md, 0.4):
			wall_ok = false
	check(wall_ok, "muralha bloqueia todo o anel fora dos portões")
	for g in md.town_gates:
		check(sim.is_walkable(g, md, 0.45), "portão %s passável" % [g])
	for zid in ["city_aldara", "field_forest", "field_ruins", "elf_city"]:
		_check_zone_layout(gd, sim, gd.maps[zid])
		_check_places(gd, sim, gd.maps[zid])
	_check_dungeons(gd, sim)
	_check_catacombs(gd, sim)
	_check_melee_reach(gd, sim)
	_check_accents()
	_check_quest_marks(gd, sim)
	_check_quest_guide(gd, sim)
	_check_summon_ai(gd, sim)
	_check_bind_crystal(gd, sim, save_ref)
	_check_quarry(gd, sim)
	_check_map_models(gd)
	_check_raid_tactics(gd, sim)
	_check_equipment_slots(gd, sim, save_ref)
	_check_icons(gd)
	_check_combat_feel(gd, sim)
	_check_skill_clips()
	_check_shields(gd, sim)
	# bot sai da vila pelo portão e vai caçar no próprio vale
	var b = sim.spawn_bot(gd.classes["paladin"], "Rota", "city_aldara", Vector3(0, 0, 6), 3)
	b.brain.dest_map = "city_aldara"
	b.brain.state = BotBrain.S.TRAVEL
	b.brain.timer = 60.0
	var left := false
	for i in range(60 * 40):
		sim.tick(1.0 / 60.0)
		if not md.in_town(b.position) and b.position.length() > md.town_radius + 3.0:
			left = true
			break
	check(left, "bot sai da vila murada pelos portões para caçar (pos %s)" % [b.position])

## Ponto com 10 m livres para os dois lados no eixo x e 4 m no z (nada de colisor no caminho das investidas).
func _free_lane(sim, m: Dictionary) -> Vector3:
	for z in range(-60, 61, 3):
		for x in range(-60, 61, 3):
			var clear := true
			for dx in range(-10, 11):
				for dz in [-4, -2, 0, 2, 4]:
					var p := Vector3(x + dx, 0, z + dz)
					if sim._resolve_obstacles(p, 1.2, m).distance_to(p) > 0.001:
						clear = false
			if clear:
				return Vector3(x, 0, z)
	return Vector3.INF

## Investida acerta o caminho inteiro e para no primeiro obstáculo.
func _check_charge_path(gd, sim) -> void:
	var m: Dictionary = sim.maps["city_aldara"]
	var at := _free_lane(sim, m)
	check(at != Vector3.INF, "há faixa livre para o teste da investida")
	var hero: SimEntity = sim.spawn_bot(gd.classes["berserker"], "Ch", "city_aldara", at, 30)
	hero.brain = null
	var wolf = sim.spawn_monster(gd.monsters["wolf"], "city_aldara", at)
	var charge: SkillDef = gd.skills["mob_charge"]
	var hit_at := func(dist: float) -> bool:
		hero.hp = hero.stats.max_hp
		hero.state = SimEntity.State.IDLE
		hero.position = at
		wolf.position = at + Vector3(dist, 0, 0)
		wolf.face_towards(at)
		wolf.skill_aim = at
		sim._apply_skill(wolf, charge, m)
		return hero.hp < hero.stats.max_hp
	var missed := []
	for dist in [0.8, 2.0, 3.0, 4.0, 5.5, 6.5, 7.0]:
		if not hit_at.call(dist):
			missed.append(dist)
	check(missed.is_empty(), "investida acerta de perto até o alcance (errou em %s)" % [missed])
	check(not hit_at.call(9.0), "investida não acerta além do alcance")
	# vários no caminho, ninguém atrás ou longe da faixa
	var rush: SkillDef = gd.skills["ber_blade_rush"]
	var row := []
	for off in [Vector3(1, 0, 0), Vector3(3, 0, 0), Vector3(4.5, 0, 0.7), Vector3(-2, 0, 0), Vector3(3, 0, 3), Vector3(8, 0, 0)]:
		row.append(sim.spawn_monster(gd.monsters["wolf"], "city_aldara", at + off))
	hero.position = at
	hero.face_towards(at + Vector3(5, 0, 0))
	sim._apply_skill(hero, rush, m)
	var hurt := []
	for w in row:
		hurt.append(w.hp < w.stats.max_hp)
	check(hurt == [true, true, true, false, false, false], "investida corta quem está na faixa do caminho e só eles (%s)" % [hurt])
	check(absf(hero.position.x - at.x - 5.0) < 0.05, "investida livre anda a distância inteira (%.2f)" % (hero.position.x - at.x))
	for w in row:
		sim.despawn(w)
	# obstáculo no meio: para antes dele e não acerta quem está do outro lado
	var post := {}
	for c in m["colliders"]:
		if not c["circle"] or c["cr"] < 0.25 or c["cr"] > 0.6:
			continue
		var start := Vector3(c["x"], 0, c["z"] + c["cr"] + 2.5)
		if sim._resolve_obstacles(start, hero.radius, m).distance_to(start) < 0.001 and sim._resolve_obstacles(start - Vector3(0, 0, 1.5), hero.radius, m).distance_to(start - Vector3(0, 0, 1.5)) < 0.001:
			post = c
			hero.position = start
			break
	check(not post.is_empty(), "achou obstáculo para o teste da investida")
	if not post.is_empty():
		var behind = sim.spawn_monster(gd.monsters["wolf"], "city_aldara", Vector3(post["x"], 0, post["z"] - post["cr"] - 0.6))
		hero.face_towards(behind.position)
		sim._apply_skill(hero, rush, m)
		check(hero.position.z >= post["z"] + post["cr"] and behind.hp == behind.stats.max_hp, "investida para no obstáculo e não acerta atrás dele (z %.2f, poste %.2f)" % [hero.position.z, post["z"]])
		# de raspão não desliza: fica na faixa reta
		hero.position = Vector3(post["x"] + 0.2, 0, post["z"] + post["cr"] + 2.5)
		hero.face_towards(hero.position + Vector3(0, 0, -5))
		var lane_x: float = hero.position.x
		sim._apply_skill(hero, rush, m)
		check(absf(hero.position.x - lane_x) < 0.01 and hero.position.z > post["z"], "investida de raspão para sem deslizar (x %.2f, z %.2f)" % [hero.position.x - lane_x, hero.position.z - post["z"]])
		# golpe com alcance além do avanço não fura o obstáculo
		var bash: SkillDef = gd.skills["pal_shield_bash"]
		check(bash.range > float(bash.effects["dash"]), "pancada alcança além do avanço")
		behind.position = Vector3(post["x"], 0, post["z"] - post["cr"] - 0.1)
		behind.state = SimEntity.State.IDLE
		hero.position = Vector3(post["x"], 0, post["z"] + post["cr"] + hero.radius + 0.4)
		hero.face_towards(behind.position)
		sim._apply_skill(hero, bash, m)
		check(behind.hp == behind.stats.max_hp, "investida barrada perde a sobra de alcance")
		sim.despawn(behind)
	# alvo único: o da frente ganha de quem só encosta de lado
	var bash_one: SkillDef = gd.skills["pal_shield_bash"]
	for pair in [[Vector3(-0.3, 0, 0.7), Vector3(1.0, 0, 0)], [Vector3(0.1, 0, 1.2), Vector3(1.3, 0, 0)], [Vector3(-0.4, 0, 0.85), Vector3(2.5, 0, 0)], [Vector3(0.5, 0, 0.8), Vector3(3.0, 0, 0)], [Vector3(0.2, 0, 0.7), Vector3(2.5, 0, 0)], [Vector3(-0.1, 0, 0), Vector3(2.8, 0, 0.8)]]:
		var side_w = sim.spawn_monster(gd.monsters["wolf"], "city_aldara", at + pair[0])
		var ahead_w = sim.spawn_monster(gd.monsters["wolf"], "city_aldara", at + pair[1])
		hero.position = at
		hero.face_towards(at + Vector3(5, 0, 0))
		sim._apply_skill(hero, bash_one, m)
		check(ahead_w.hp < ahead_w.stats.max_hp and side_w.hp == side_w.stats.max_hp, "alvo único da investida é o da frente (%s)" % pair[0])
		sim.despawn(side_w)
		sim.despawn(ahead_w)
	# monstro e bot só lançam a investida que chega
	var runner = sim.spawn_monster(gd.monsters["wolf"], "city_aldara", at)
	runner.skills = [charge] as Array[SkillDef]
	runner.aggro_target = hero.id
	var fires := func(from: Vector3, to: Vector3) -> bool:
		runner.position = from
		hero.position = to
		runner.state = SimEntity.State.IDLE
		runner.aggro_timer = 5.0
		runner.cooldowns.clear()
		runner.brain.skill_timer = 0.0
		return runner.brain.think(runner, sim, m, 0.05).skill_slot >= 0
	check(fires.call(at, at + Vector3(6.5, 0, 0)), "monstro lança investida que chega")
	check(not fires.call(at, at + Vector3(8.5, 0, 0)), "monstro não lança investida curta")
	var rider: SimEntity = sim.spawn_bot(gd.classes["berserker"], "ChB", "city_aldara", at, 30)
	var prey = sim.spawn_monster(gd.monsters["wolf"], "city_aldara", at + Vector3(4, 0, 0))
	if not post.is_empty():
		var beyond := Vector3(post["x"], 0, post["z"] - post["cr"] - 1.0)
		var near := Vector3(post["x"], 0, post["z"] + post["cr"] + 1.5)
		check(not fires.call(near, beyond), "monstro não lança investida contra obstáculo")
		rider.position = near
		prey.position = beyond
		check(not sim.charge_lands(rider, rush, prey, m) and rider.position == near, "simular a investida barrada não move ninguém")
		# bot decide de verdade: sem o portão a investida sairia contra o obstáculo
		rider.skills.assign([charge])
		var bot_fires := func() -> int:
			var fired := 0
			for i in range(40):
				rider.state = SimEntity.State.IDLE
				rider.cooldowns.clear()
				rider.brain.block_timer = 0.0
				fired += 1 if rider.brain._fight(rider, sim, m, prey, InputCommand.new()).skill_slot == 0 else 0
			return fired
		check(bot_fires.call() == 0, "bot não lança investida contra obstáculo")
		rider.position = at
		prey.position = at + Vector3(4, 0, 0)
		check(bot_fires.call() > 0, "bot lança investida com caminho livre")
		# barrada, a sobra de alcance não conta (alvo dentro de range - dash)
		var stub: SkillDef = gd.skills["pal_shield_bash"]
		rider.position = Vector3(post["x"], 0, post["z"] + post["cr"] + rider.radius + 0.4)
		prey.position = Vector3(post["x"], 0, post["z"] - post["cr"] - 0.1)
		check(not sim.charge_lands(rider, stub, prey, m), "investida barrada não chega com a sobra de alcance")
	rider.position = at
	prey.position = at + Vector3(4, 0, 0)
	check(sim.charge_lands(rider, rush, prey, m), "investida livre chega")
	prey.position = at + Vector3(5.0 + prey.radius - 0.1, 0, 0)
	check(sim.charge_lands(rider, rush, prey, m), "investida chega até a borda do alvo")
	prey.position = at + Vector3(5.0 + prey.radius + 0.1, 0, 0)
	check(not sim.charge_lands(rider, rush, prey, m), "investida não chega além da faixa")
	# raspão longo em parede: o desvio não acumula de passo em passo
	var graze_done := false
	for c in m["colliders"]:
		if c["circle"] or c["hx"] < 3.5:
			continue
		var rot: float = c["rot"]
		var local := Vector2(-c["hx"] + 0.5, c["hz"] + hero.radius + 0.03)
		var world: Vector2 = local.rotated(-rot) + Vector2(c["x"], c["z"])
		var start := Vector3(world.x, 0, world.y)
		if sim._resolve_obstacles(start, hero.radius, m).distance_to(start) > 0.001:
			continue
		var d2: Vector2 = Vector2(cos(0.035), -sin(0.035)).rotated(-rot)
		var dir3 := Vector3(d2.x, 0, d2.y)
		hero.position = start
		sim._charge(hero, dir3 * 6.0, m)
		var off: Vector3 = hero.position - start
		var side: float = (off - dir3 * off.dot(dir3)).length()
		check(side < 0.03 and off.length() > 0.4, "raspão longo não acumula desvio (lado %.3f, andou %.2f)" % [side, off.length()])
		graze_done = true
		break
	check(graze_done, "achou parede para o raspão")
	sim.despawn(rider)
	sim.despawn(prey)
	sim.despawn(runner)
	# o efeito sai de onde a investida partiu
	var seen := []
	var on_fx := func(id, origin, aim, _r): seen.append([id, origin, aim])
	Events.skill_effect.connect(on_fx)
	hero.position = at
	hero.face_towards(at + Vector3(5, 0, 0))
	sim._apply_skill(hero, rush, m)
	Events.skill_effect.disconnect(on_fx)
	check(seen.size() == 1 and seen[0][1].distance_to(at) < 0.01 and seen[0][2].distance_to(at + Vector3(5, 0, 0)) < 0.05, "efeito da investida cobre o caminho")
	sim.despawn(wolf)
	sim.despawn(hero)

## Guarda direcional: bloqueio, chance passiva, aparo e reação só valem no arco da frente.
func _check_guard_arc(gd, sim) -> void:
	var m: Dictionary = sim.maps["city_aldara"]
	var rng := RandomNumberGenerator.new()
	var d: SimEntity = sim.spawn_bot(gd.classes["paladin"], "Arc", "city_aldara", Vector3(0, 0, 6), 30)
	var foe: SimEntity = sim.spawn_bot(gd.classes["berserker"], "ArcF", "city_aldara", Vector3(0, 0, 8), 30)
	d.brain = null
	foe.brain = null
	d.equipment[ItemDef.Slot.OFFHAND] = gd.items["shield_wood"]
	d.recompute_stats()
	d.face_towards(Vector3(0, 0, 8))
	var half := Balance.BLOCK_ARC_DEG * 0.5
	var at := func(deg: float) -> Vector3:
		var f: Vector3 = d.forward().rotated(Vector3.UP, deg_to_rad(deg))
		return d.position + f * 2.0
	check(Combat.in_guard_arc(d, at.call(0.0)) and Combat.in_guard_arc(d, at.call(half - 2.0)) and Combat.in_guard_arc(d, at.call(-half + 2.0)), "frente e lados do arco contam")
	check(not Combat.in_guard_arc(d, at.call(half + 2.0)) and not Combat.in_guard_arc(d, at.call(-half - 2.0)) and not Combat.in_guard_arc(d, at.call(180.0)), "fora do arco e costas não contam")
	check(Combat.in_guard_arc(d, d.position), "golpe em cima do alvo não fica sem direção")
	d.is_blocking = true
	var front := 0
	var back := 0
	for i in range(60):
		front += 1 if Combat.calc_damage(foe, d, 1.0, 0, rng, at.call(0.0))["blocked"] else 0
		back += 1 if Combat.calc_damage(foe, d, 1.0, 0, rng, at.call(180.0))["blocked"] else 0
	check(front == 60 and back == 0, "guarda segurada bloqueia a frente e nunca as costas (%d, %d)" % [front, back])
	d.is_blocking = false
	var passive := 0
	for i in range(200):
		passive += 1 if Combat.calc_damage(foe, d, 1.0, 0, rng, at.call(180.0))["blocked"] else 0
	check(d.stats.block_chance > 0.0 and passive == 0, "chance passiva não cobre as costas")
	d.is_blocking = true
	d.parry_left = 0.2
	var hp: float = d.hp
	sim._deal_damage(foe, d, 100, false, false, "physical", at.call(180.0))
	check(d.parry_left > 0.0 and hp - d.hp >= 99.0, "aparo não vale pelas costas")
	var flanked := [0]
	var on_flank := func(_id): flanked[0] += 1
	Events.guard_flanked.connect(on_flank)
	sim._deal_damage(foe, d, 5, false, false, "physical", at.call(180.0))
	sim._deal_damage(foe, d, 5, false, false, "physical", at.call(0.0))
	sim._deal_damage(foe, d, 5, false, false, "dot", at.call(180.0))
	Events.guard_flanked.disconnect(on_flank)
	check(flanked[0] == 1, "só golpe pelas costas avisa flanqueado (%d)" % flanked[0])
	d.parry_left = 0.0
	# projétil e área: vale de onde o golpe chega, não onde está quem lançou (lançador sempre à frente)
	d.is_blocking = true
	var wolf = sim.spawn_monster(gd.monsters["wolf"], "city_aldara", at.call(0.0))
	var blocks := {"n": 0}
	var on_block := func(id): blocks["n"] += 1 if id == d.id else 0
	Events.blocked_hit.connect(on_block)
	var shot := func(deg: float) -> Array:
		blocks["n"] = 0
		d.hp = d.stats.max_hp
		var st: SkillDef = null
		for k in gd.skills:
			if gd.skills[k].projectile_speed > 0.0 and gd.skills[k].kind == SkillDef.Kind.PHYSICAL:
				st = gd.skills[k]
				break
		sim._spawn_projectile(wolf, st, 1.0, m, false)
		var p: SimProjectile = m["projectiles"][-1]
		p.position = d.position + d.forward().rotated(Vector3.UP, deg_to_rad(deg)) * 0.3
		p.direction = (d.position - p.position).normalized()
		sim._update_projectiles(m, 0.001)
		m["projectiles"].erase(p)
		return [d.hp < d.stats.max_hp, blocks["n"]]
	var back_shot: Array = shot.call(180.0)
	var front_shot: Array = shot.call(0.0)
	check(back_shot[0] and back_shot[1] == 0 and front_shot[1] == 1, "projétil vale pelo lado de onde chega (%s, %s)" % [back_shot, front_shot])
	var meteor: SkillDef = gd.skills["ele_meteor"]
	check(meteor.target == SkillDef.Target.GROUND, "meteoro é área no chão")
	var fall := func(deg: float) -> Array:
		blocks["n"] = 0
		d.hp = d.stats.max_hp
		wolf.skill_aim = at.call(deg)
		sim._apply_skill(wolf, meteor, m)
		return [d.hp < d.stats.max_hp, blocks["n"]]
	var back_fall: Array = fall.call(180.0)
	var front_fall: Array = fall.call(0.0)
	check(back_fall[0] and back_fall[1] == 0 and front_fall[1] == 1, "área no chão vale pelo ponto de impacto (%s, %s)" % [back_fall, front_fall])
	# investida que atravessa o alvo vale pelo lado de onde partiu
	var lane := _free_lane(sim, m)
	var charge := func(side: float) -> Array:
		blocks["n"] = 0
		d.hp = d.stats.max_hp
		d.position = lane
		d.face_towards(lane + Vector3(5, 0, 0))
		d.state = SimEntity.State.IDLE          # o atordoamento da investida anterior derruba a guarda
		d.is_blocking = true
		wolf.position = d.position + Vector3(5.7 * side, 0, 0)
		wolf.face_towards(d.position)
		wolf.skill_aim = d.position
		sim._apply_skill(wolf, gd.skills["mob_charge"], m)
		return [d.hp < d.stats.max_hp or blocks["n"] > 0, blocks["n"], (wolf.position.x - d.position.x) * side < 0.0]
	var front_run: Array = charge.call(1.0)
	var back_run: Array = charge.call(-1.0)
	check(front_run[2] and back_run[2], "a investida do teste atravessa o alvo (%s, %s)" % [front_run, back_run])
	check(front_run[0] and front_run[1] == 1 and back_run[0] and back_run[1] == 0, "investida vale pelo lado de onde partiu (%s, %s)" % [front_run, back_run])
	Events.blocked_hit.disconnect(on_block)
	sim.despawn(wolf)
	sim.despawn(foe)
	sim.despawn(d)

## Guarda sem MP não pisca nem arma aparo de graça; dano no tempo não apara.
func _check_guard_rules(gd, sim) -> void:
	var m: Dictionary = sim.maps["city_aldara"]
	var e: SimEntity = sim.spawn_bot(gd.classes["paladin"], "Gu", "city_aldara", Vector3(0, 0, 6), 30)
	e.brain = null
	e.equipment[ItemDef.Slot.OFFHAND] = gd.items["shield_wood"]
	e.recompute_stats()
	var up := InputCommand.new()
	up.block = true
	up.aim = Vector3(2, 0, 6)
	var down := InputCommand.new()
	down.aim = up.aim
	e.mp = 0.01
	e.parry_cd = 0.0
	sim._apply_command(e, up, m, 1.0)
	check(e.guard_broken, "MP zerado quebra a guarda")
	var flips := 0
	var armed := 0
	for i in range(100):
		e.mp += 0.5
		e.parry_cd = 0.0
		var was: bool = e.is_blocking
		e.parry_left = 0.0
		sim._apply_command(e, up, m, 1.0 / 60.0)
		flips += 1 if e.is_blocking != was else 0
		armed += 1 if e.parry_left > 0.0 else 0
	check(flips <= 1 and armed == 0, "segurar sem MP não pisca nem arma aparo (%d, %d)" % [flips, armed])
	e.mp = Balance.BLOCK_MIN_MP + 1.0
	sim._apply_command(e, down, m, 1.0 / 60.0)
	sim._apply_command(e, up, m, 1.0 / 60.0)
	check(e.is_blocking and not e.guard_broken, "soltar com MP devolve a guarda")
	var foe: SimEntity = sim.spawn_bot(gd.classes["berserker"], "Gf", "city_aldara", Vector3(1, 0, 6), 30)
	foe.brain = null
	e.parry_left = 0.2
	sim._deal_damage(foe, e, 5, false, false, "dot")
	check(e.parry_left > 0.0 and foe.state != SimEntity.State.STUNNED, "dano no tempo não gasta o aparo")
	sim.despawn(foe)
	sim.despawn(e)

## Bônus de classe do escudo: Juramento, Graça, afinidade errada não vale, e o Bispo mantém as skills de Sacerdote.
func _check_shield_bonus(gd, sim, foe) -> void:
	for d in GearCatalog.SHIELDS:
		check(GearCatalog.SHIELD_AFFINITY.has(d[3]), "%s tem família com afinidade" % d[0])
	var styles := {}
	for iid in gd.items:
		var st: String = gd.items[iid].shield_style
		if st != "":
			styles[st] = int(styles.get(st, 0)) + 1
			check(GearCatalog.SHIELD_AFFINITY.has(st), "%s tem afinidade" % st)
	var set_shields := 0          # 18 = 14 nomeados + 4 de tier (ItemsCatalog.SHIELD_LOOK)
	for set_id in GearCatalog.SET_VISUALS:
		for iid in gd.sets[set_id].pieces:
			if gd.items[iid].weapon_type == "shield":
				set_shields += 1
				check(gd.items[iid].shield_style == GearCatalog.SET_VISUALS[set_id]["style"], "%s: escudo próprio do conjunto" % iid)
	check(set_shields == 12, "conjuntos com escudo têm escudo próprio: 6 do Guardião e 6 do Sacerdote (%d)" % set_shields)
	check(styles.size() == 18 + set_shields and styles.values().all(func(n): return n == 1), "cada escudo tem modelo próprio: %s" % str(styles))
	var mk := func(cls: String, shield: String) -> SimEntity:
		var e: SimEntity = sim.spawn_bot(gd.classes[cls], "EB", "city_aldara", Vector3(0, 0, 6), 30)
		e.brain = null
		e.equipment[ItemDef.Slot.WEAPON] = gd.items["leg_paladin_guardiao_30_weapon"]
		e.equipment[ItemDef.Slot.OFFHAND] = gd.items[shield]
		e.recompute_stats()
		e.heal_full()
		return e
	var pal: SimEntity = mk.call("paladin", "shield_palavra_deus")
	sim._shield_class_bonus(pal, pal.equipment[ItemDef.Slot.OFFHAND], false)
	check(sim.oath_stacks(pal) == 1, "bloquear dá Juramento")
	sim._shield_class_bonus(pal, pal.equipment[ItemDef.Slot.OFFHAND], true)
	check(sim.oath_stacks(pal) == 3, "aparar dá 2 cargas")
	for i in range(6):
		sim._shield_class_bonus(pal, pal.equipment[ItemDef.Slot.OFFHAND], false)
	check(sim.oath_stacks(pal) == Balance.SHIELD_OATH_MAX, "Juramento tem teto")
	var holy: SkillDef = gd.skills["pal_holy_strike"]
	var full: float = sim._shield_power(pal, holy)
	check(full > 1.3 and sim.oath_stacks(pal) == 0, "skill sagrada gasta o Juramento (x%.2f)" % full)
	check(sim._shield_power(pal, holy) == 1.0, "sem cargas não há bônus")
	var bash: SkillDef = gd.skills["pal_shield_bash"]
	check(sim._shield_power(pal, bash) > 1.0, "skill de escudo escala com a DEF do escudo")
	var wrong: SimEntity = mk.call("paladin", "shield_abraco_criador")
	sim._shield_class_bonus(wrong, wrong.equipment[ItemDef.Slot.OFFHAND], false)
	check(sim.oath_stacks(wrong) == 0, "escudo de bispo não dá Juramento ao paladino")
	var setp: SimEntity = mk.call("paladin", "shield_wood")
	setp.equipment[ItemDef.Slot.OFFHAND] = gd.items["leg_paladin_guardiao_30_offhand"]
	sim._shield_class_bonus(setp, setp.equipment[ItemDef.Slot.OFFHAND], false)
	check(sim.oath_stacks(setp) == 1, "escudo de conjunto do Guardião dá Juramento")
	sim.despawn(setp)
	var bis: SimEntity = mk.call("bishop", "shield_abraco_criador")
	var ally: SimEntity = mk.call("paladin", "shield_wood")
	ally.position = bis.position + Vector3(2, 0, 0)
	sim.party_invite(bis, ally)
	sim.party_accept(ally)
	ally.hp = ally.stats.max_hp * 0.3
	var hp: float = ally.hp
	sim._shield_class_bonus(bis, bis.equipment[ItemDef.Slot.OFFHAND], false)
	check(ally.hp > hp, "Graça cura o aliado mais ferido")
	var once: float = ally.hp
	for i in range(20):
		sim._shield_class_bonus(bis, bis.equipment[ItemDef.Slot.OFFHAND], false)
	check(ally.hp == once, "Graça tem recarga: bloquear sem parar não vira imortalidade")
	check(once - hp <= ally.stats.max_hp * 0.06, "Graça cura pouco de uma vez")
	ally.shield_hp = ally.stats.max_hp * 0.3
	ally.buffs.append({"id": "shield", "remaining": 6.0})
	sim._shield_class_bonus(bis, bis.equipment[ItemDef.Slot.OFFHAND], true)
	check(ally.buffs.filter(func(x): return x.get("id") == "shield")[0]["remaining"] == 6.0, "aparar não encurta escudo maior")
	ally.shield_hp = 0.0
	sim._shield_class_bonus(bis, bis.equipment[ItemDef.Slot.OFFHAND], true)
	check(ally.shield_hp > 0.0, "aparar protege o grupo por perto")
	var bwrong: SimEntity = mk.call("bishop", "shield_deus_guerra")
	bwrong.hp = 50.0
	sim._shield_class_bonus(bwrong, bwrong.equipment[ItemDef.Slot.OFFHAND], false)
	check(bwrong.hp == 50.0, "escudo de paladino não dá Graça")
	check(gd.classes["bishop"].can_use_shield, "bispo usa escudo")
	check(sim.equip_error(bis, gd.items["shield_abraco_criador"], false) == "", "bispo pode equipar escudo")
	check(bis.stats.meets(gd.skills["bis_sanctuary"].requires), "Sacerdote de escudo mantém suas skills")
	bis.shield_hp = 0.0
	bis.shield_react_cd = 0.0
	sim._shield_reaction(bis, foe, 10, false)
	var bar: Array = bis.buffs.filter(func(x): return x.get("id") == "shield")
	check(bis.shield_hp > 0.0 and bar.size() == 1 and float(bar[0]["remaining"]) <= Balance.SHIELD_BARRIER_TIME, "barreira do escudo tem duração")
	bar[0]["remaining"] = 0.01
	sim._update_entity(bis, sim.maps["city_aldara"], 1.0 / 60.0)
	check(bis.shield_hp == 0.0, "barreira do escudo expira")
	var inq: SimEntity = sim.spawn_bot(gd.classes["bishop"], "Inq", "city_aldara", Vector3(0, 0, 6), 30)
	inq.equipment[ItemDef.Slot.WEAPON] = gd.items["leg_bishop_inquisidor_30_weapon"]
	check(not sim._uses_shield(inq), "arma de duas mãos não recebe escudo lendário")
	bis.equipment[ItemDef.Slot.WEAPON] = gd.items["leg_bishop_sacerdote_30_weapon"]
	check(sim._uses_shield(bis), "Sacerdote de maça recebe escudo lendário")
	var with_shield := 0
	var with_orb := 0
	for i in range(40):
		var bot = sim.spawn_bot(gd.classes["bishop"], "Sac", "city_aldara", Vector3(0, 0, 6), 12)
		if bot.build_id == "sacerdote":
			with_shield += 1 if bot.stats.has_shield else 0
			var off: ItemDef = bot.equipment.get(ItemDef.Slot.OFFHAND)
			with_orb += 1 if off and off.weapon_type == "orb" else 0
			check(bot.skills.any(func(s): return s != null and s.build == "sacerdote"), "bot Sacerdote mantém skills com maça e escudo")
		sim.despawn(bot)
	check(with_shield > 0 and with_orb == 0, "bots Sacerdote usam maça e escudo, nunca orbe (%d/%d)" % [with_shield, with_orb])
	for x in [pal, wrong, bis, ally, bwrong, inq]:
		sim.despawn(x)

## Escudos: 14 nomeados com silhueta, ícone e reação; bloquear reage; aparar dobra, atordoa e tem janela curta.
func _check_shields(gd, sim) -> void:
	check(GearCatalog.SHIELDS.size() == 14, "14 escudos nomeados")
	var guard := KitModel.create("male", Color.WHITE)
	check(guard.resolve("block_shield") != "" and guard.resolve("block") != "", "guarda com escudo e guarda sem escudo são clipes separados")
	check(guard.anim.get_animation("block_shield").loop_mode == Animation.LOOP_LINEAR, "guarda de escudo fica em loop")
	_check_guard_rules(gd, sim)
	_check_guard_arc(gd, sim)
	_check_charge_path(gd, sim)
	guard.free()
	var hero: SimEntity = sim.spawn_bot(gd.classes["paladin"], "Rec", "city_aldara", Vector3(0, 0, 6), 30)
	hero.brain = null
	var view := EntityView.new()
	add_child(view)
	view.setup(hero, false)
	view.model_root.position = Vector3.ZERO
	var peak := func(parry: bool) -> float:
		Events.shield_block.emit(hero.id, -1, "physical", parry, hero.position + hero.forward())
		var top := 0.0
		for i in range(6):
			view._animate(1.0 / 60.0)
			top = maxf(top, view.model_root.position.length())
		return top
	var hit: float = peak.call(false)
	check(hit > 0.05 and view.model_root.position.dot(hero.forward()) < 0.0, "golpe na guarda empurra para trás")
	for i in range(240):
		view._animate(1.0 / 60.0)
	check(view.model_root.position.length() < 0.01, "o empurrão volta sozinho (%.3f)" % view.model_root.position.length())
	check(peak.call(true) > hit, "aparar empurra mais que bloquear")
	view.free()
	sim.despawn(hero)
	var kit := KitModel.create("male", Color.WHITE, 0.025, "paladin")     # escudos ficam no kit de quem os empunha
	var seen_effects := {}
	for d in GearCatalog.SHIELDS:
		var it: ItemDef = gd.items.get("shield_" + d[0])
		check(it != null and it.is_legendary(), "%s é item lendário" % d[0])
		if it == null:
			continue
		check(ResourceLoader.exists("res://assets/icons/%s.png" % it.icon), "%s tem ícone" % d[0])
		var img := (load("res://assets/icons/%s.png" % it.icon) as Texture2D).get_image()
		img.decompress()
		var edge := 0
		for k in range(img.get_width()):
			edge += 1 if img.get_pixel(k, 0).a > 0.1 or img.get_pixel(k, img.get_height() - 1).a > 0.1 or img.get_pixel(0, k).a > 0.1 or img.get_pixel(img.get_width() - 1, k).a > 0.1 else 0
		check(edge == 0, "ícone de %s não corta o escudo (%d)" % [d[0], edge])
		check(kit.pieces("wpn_off_shield_" + it.shield_style).size() > 0, "%s no kit" % it.shield_style)
		check(it.description != "" and it.shield_effect.size() >= 2, "%s tem reação descrita" % d[0])
		seen_effects[str(it.shield_effect)] = true
	check(seen_effects.size() == 14, "cada escudo reage diferente")
	kit.free()
	for iid in ["shield_wood", "shield_iron", "shield_bone", "shield_dragon"]:
		check(ResourceLoader.exists("res://assets/icons/%s.png" % gd.items[iid].icon), "%s tem ícone" % iid)
	var m: Dictionary = sim.maps["city_aldara"]
	var mk := func(shield: String) -> SimEntity:
		var e: SimEntity = sim.spawn_bot(gd.classes["paladin"], "Esc", "city_aldara", Vector3(0, 0, 6), 30)
		e.brain = null
		e.equipment[ItemDef.Slot.OFFHAND] = gd.items[shield]
		e.recompute_stats()
		e.heal_full()
		return e
	var foe: SimEntity = sim.spawn_bot(gd.classes["berserker"], "Bate", "city_aldara", Vector3(1.5, 0, 6), 30)
	foe.brain = null
	# bloqueio simples: cura, barreira, reflexo
	var a: SimEntity = mk.call("shield_asa_angelical")
	a.hp = 100.0
	sim._deal_damage(foe, a, 50, false, true, "physical")
	check(a.hp > 50.0, "Asa Angelical cura ao bloquear (%.0f)" % a.hp)
	var b: SimEntity = mk.call("shield_muro_suspiros")
	sim._deal_damage(foe, b, 50, false, true, "physical")
	check(b.shield_hp > 0.0, "Muro dos Suspiros cria barreira")
	var c: SimEntity = mk.call("shield_senhor_crueldade")
	var foe_hp: float = foe.hp
	sim._deal_damage(foe, c, 100, false, true, "physical")
	check(foe.hp < foe_hp and foe.is_alive(), "Senhor da Crueldade devolve dano")
	var d2: SimEntity = mk.call("shield_deus_guerra")
	sim._deal_damage(foe, d2, 50, false, true, "physical")
	check(foe.debuffs.any(func(x): return x.get("kind") == "dot"), "Deus da Guerra queima")
	foe.debuffs.clear()
	foe.recompute_stats()
	# sem bloqueio não reage
	var e2: SimEntity = mk.call("shield_asa_angelical")
	e2.hp = 100.0
	sim._deal_damage(foe, e2, 50, false, false, "physical")
	check(e2.hp == 50.0, "sem bloqueio não reage")
	# aparar: janela ao erguer, 90% de redução, atordoa, dobra
	var p: SimEntity = mk.call("shield_asa_angelical")
	p.hp = 1000.0
	var up := InputCommand.new()
	up.block = true
	up.aim = Vector3(2, 0, 6)
	sim._apply_command(p, up, m, 1.0 / 60.0)
	check(p.is_blocking and p.parry_left > 0.0, "erguer o escudo abre a janela de aparar")
	var before: float = p.hp
	sim._deal_damage(foe, p, 100, false, false, "physical")
	var heal := p.stats.max_hp * 0.06
	check(absf(p.hp - minf(p.stats.max_hp, before - 10.0 + heal)) < 2.0, "aparar tira 90%% e dobra a cura (%.1f)" % p.hp)
	check(foe.state == SimEntity.State.STUNNED, "aparar atordoa quem bateu de perto")
	check(p.parry_left == 0.0, "um aparo por erguida")
	foe.set_state(SimEntity.State.IDLE)
	# janela passa: segurar não apara; soltar e erguer de novo espera a recarga
	var q: SimEntity = mk.call("shield_wood")
	sim._apply_command(q, up, m, 1.0 / 60.0)
	q.parry_left = 0.0
	var hp_q: float = q.hp
	sim._deal_damage(foe, q, 100, false, true, "physical")
	check(hp_q - q.hp >= 99.0, "segurar depois da janela não apara")
	var down := InputCommand.new()
	sim._apply_command(q, down, m, 1.0 / 60.0)
	sim._apply_command(q, up, m, 1.0 / 60.0)
	check(q.parry_left == 0.0, "martelar o bloqueio não reabre a janela")
	_check_shield_bonus(gd, sim, foe)
	# sem escudo não apara
	var nb: SimEntity = sim.spawn_bot(gd.classes["berserker"], "Sem", "city_aldara", Vector3(0, 0, 6), 30)
	nb.brain = null
	sim._apply_command(nb, up, m, 1.0 / 60.0)
	check(nb.parry_left == 0.0, "sem escudo não apara")
	for e in [a, b, c, d2, e2, p, q, nb, foe]:
		sim.despawn(e)

## Clipes por família: existem nos dois corpos e o quadro de impacto casa com o do Blender.
func _check_skill_clips() -> void:
	for body in ["male", "female"]:
		var k := KitModel.create(body, Color.WHITE)
		for clip in EntityView.IMPACT_FRAME:
			if clip != "attack" and not (clip in EntityView.FORM_CLIP.values()):     # gestos de bicho ficam nas formas (_check_form_clips)
				check(k.resolve(clip) != "", "kit_%s: clipe %s" % [body, clip])
				if k.anim.has_animation(clip):
					check(float(EntityView.IMPACT_FRAME[clip] - 1) / 24.0 < k.anim.get_animation(clip).length, "%s: impacto dentro do clipe" % clip)
		check(k.legs != null and k.legs._tracks.size() >= 6, "kit_%s: pernas por cima do golpe" % body)
		k.free()

## Feel de combate: anda durante o golpe, dash interrompe, buffer sobrevive ao ataque segurado, reacerta a mira.
func _check_combat_feel(gd, sim) -> void:
	var m: Dictionary = sim.maps["city_aldara"]
	var dt := 1.0 / 60.0
	var mk := func(cid: String) -> SimEntity:
		var e: SimEntity = sim.spawn_bot(gd.classes[cid], "Feel", "city_aldara", Vector3(0, 0, 6), 30)
		e.brain = null
		return e
	var cmd_of := func(move: Vector2, aim: Vector3) -> InputCommand:
		var c := InputCommand.new()
		c.move = move
		c.aim = aim
		return c
	check(Balance.INPUT_BUFFER_TICKS / 60.0 >= 0.2, "buffer de pelo menos 0,2 s")
	# anda durante o ataque básico
	var a: SimEntity = mk.call("berserker")
	var c1: InputCommand = cmd_of.call(Vector2(1, 0), Vector3(5, 0, 6))
	c1.attack = true
	sim._apply_command(a, c1, m, dt)
	check(a.state == SimEntity.State.CASTING, "ataque básico começa")
	var x0: float = a.position.x
	for i in range(6):
		sim._apply_command(a, cmd_of.call(Vector2(1, 0), Vector3(5, 0, 6)), m, dt)
	check(a.position.x - x0 > 0.2, "anda durante o golpe (%.2f m em 0,1 s)" % (a.position.x - x0))
	check(a.position.x - x0 < a.stats.move_speed * 0.1, "andar atacando é mais lento que correr")
	# mira do básico segue o cursor até o impacto
	var aim2 := Vector3(-5, 0, 6)
	sim._apply_command(a, cmd_of.call(Vector2.ZERO, aim2), m, dt)
	check(a.skill_applied or a.skill_aim == aim2, "básico segue o cursor antes do impacto")
	sim._end_skill(a)
	# investida não anda; magia longa quase não anda
	check(sim.cast_move_mult(gd.skills["pal_lunge"]) == 0.0, "investida não anda com o direcional")
	check(sim.cast_move_mult(gd.skills["ele_meteor"]) == Balance.CAST_MOVE_MULT_HEAVY, "magia longa quase para")
	check(sim.cast_move_mult(gd.skills["ele_fireball"]) == Balance.CAST_MOVE_MULT, "magia rápida anda")
	# dash interrompe a preparação e devolve MP e recarga
	var b: SimEntity = mk.call("elementalist")
	b.skills[0] = gd.skills["ele_meteor"]
	b.tree.clear()
	b.mp = b.stats.max_mp
	b.level = 30
	var c2: InputCommand = cmd_of.call(Vector2.ZERO, Vector3(0, 0, 12))
	c2.skill_slot = 0
	b.mastery[gd.skills["ele_meteor"].id] = 0
	sim._start_skill(b, gd.skills["ele_meteor"], 0, Vector3(0, 0, 12))
	var mp0: float = b.mp
	b.mp -= 20.0
	b.cooldowns["ele_meteor"] = 9.0
	var c3: InputCommand = cmd_of.call(Vector2(1, 0), Vector3(0, 0, 12))
	c3.dash = true
	b.dash_cd = 0.0
	sim._apply_command(b, c3, m, dt)
	check(b.state == SimEntity.State.DASHING, "dash interrompe a preparação")
	check(not b.cooldowns.has("ele_meteor") and b.mp > mp0 - 20.0, "cancelar antes do impacto devolve recarga e MP")
	# depois do impacto o dash também sai, mas a skill conta
	sim._end_skill(b)
	b.set_state(SimEntity.State.IDLE)
	b.dash_cd = 0.0
	sim._start_skill(b, gd.skills["ele_meteor"], 0, Vector3(0, 0, 12))
	b.skill_applied = true
	b.cooldowns["ele_meteor"] = 9.0
	var c4: InputCommand = cmd_of.call(Vector2(1, 0), Vector3(0, 0, 12))
	c4.dash = true
	sim._apply_command(b, c4, m, dt)
	check(b.state == SimEntity.State.DASHING and b.cooldowns.has("ele_meteor"), "dash depois do impacto mantém a recarga")
	# ataque segurado não apaga a skill no buffer
	var c: SimEntity = mk.call("paladin")
	sim._start_skill(c, gd.skills["pal_holy_strike"], 0, Vector3(0, 0, 12))
	var c5: InputCommand = cmd_of.call(Vector2.ZERO, Vector3(0, 0, 12))
	c5.skill_slot = 1
	sim._apply_command(c, c5, m, dt)
	check(c.buffered_cmd != null and c.buffered_cmd.skill_slot == 1, "skill apertada durante o golpe entra no buffer")
	for i in range(5):
		var held: InputCommand = cmd_of.call(Vector2.ZERO, Vector3(0, 0, 12))
		held.attack = true
		sim._apply_command(c, held, m, dt)
	check(c.buffered_cmd != null and c.buffered_cmd.skill_slot == 1, "segurar ataque não apaga a skill do buffer")
	for e in [a, b, c]:
		sim.despawn(e)
	_check_skill_chain(gd, sim)
	_check_berserker_builds(gd, sim)
	_check_bishop_builds(gd, sim)
	_check_druid_builds(gd, sim)
	_check_ranger_builds(gd, sim)
	_check_assassin_builds(gd, sim)
	_check_elementalist_builds(gd, sim)
	_check_necromancer_builds(gd, sim)
	_check_elemental_debuffs(gd, sim)
	_check_layout_conflicts(gd, sim)
	_check_villagers(gd, sim)
	_check_raids(gd, sim)
	_check_elf_loot(gd, sim)
	_check_hunter_post(gd, sim)
	_check_start_presets(gd, sim)
	_check_start_party(gd, sim)
	_check_start_elf(gd, sim)
	_check_start_ruins(gd, sim)
	_check_raid_status(gd, sim)
	_check_raid_defense(gd, sim)
	_check_raid_scaling(gd, sim)
	_check_band_bosses(gd, sim)
	_check_monster_unstick(gd, sim)
	_check_post_life(gd, sim)
	_check_band_consistency(gd, sim)
	_check_interiors(gd, sim)
	_check_druid_start(gd, sim)
	_check_xp_budget(gd)
	_check_gather(gd, sim)
	_check_quest_variety(gd, sim)
	_check_monster_polish(gd, sim)
	_check_dungeon_density(gd, sim)
	_check_shop_rules(gd, sim)
	_check_forge(gd, sim)
	_check_legend_weapons_and_attrs(gd, sim)
	_check_item_descriptions(gd)
	_check_party_personal_loot(gd, sim)
	_check_recall_and_personal_loot(gd, sim)
	_check_party_follow_elite(gd, sim)
	_check_party_seek_storage(gd, sim, save_ref)
	_check_first_set_drops(gd, sim)
	_check_mastery_rebuy(gd, sim)
	_check_status_and_drag(gd, sim)
	_check_hunts(gd, sim)
	_check_looks(gd, sim)
	_check_craft_class(gd, sim)
	_check_away_maps(gd, sim)
	_check_mount(gd, sim)
	_check_loot_chest(gd)

## Ranger: Caçador (arco + lince companheiro permanente) e Atirador (mosquete lento e pesado + armadilhas no chão).
func _check_loot_chest(gd) -> void:
	# drop no chão é um baú (ou moedas), com brilho pela raridade; malhas compartilhadas entre drops
	var a := LootChest.make("sword_iron")
	var b := LootChest.make("dagger_golem")
	var g := LootChest.make("gold")
	check(a.get_node_or_null("Glow") != null and a.get_child_count() >= 6, "item vira baú com aros, fechadura e gema")
	check((a.get_child(0) as MeshInstance3D).mesh == (b.get_child(0) as MeshInstance3D).mesh, "baús compartilham a malha")
	check(g.get_child_count() >= 4 and (g.get_child(0) as MeshInstance3D).mesh is CylinderMesh, "ouro vira montinho de moedas")
	var leg: Array = gd.items.keys().filter(func(k): return gd.items[k].rarity >= ItemDef.RARITY_LEGENDARY)
	if not leg.is_empty():
		var l := LootChest.make(leg[0])
		check((l.get_node("Glow") as OmniLight3D).light_energy > (a.get_node("Glow") as OmniLight3D).light_energy, "lendário brilha mais que comum")
		l.free()
	a.free(); b.free(); g.free()

func _check_mount(gd, sim) -> void:
	var cls: ClassDef = gd.classes["paladin"]
	var m: Dictionary = sim.maps["city_aldara"]
	var e: SimEntity = sim.spawn_bot(cls, "Cavaleiro", "city_aldara", Vector3(-12, 0, -12), 10)
	e.brain = null
	e.combat_timer = 0.0
	var c := InputCommand.new()
	c.mount = true
	c.aim = e.position + Vector3(0, 0, 3)
	sim._apply_command(e, c, m, 1.0 / 60.0)
	check(e.mounted, "H monta fora de combate")
	# mais rápido montado
	var mv := InputCommand.new()
	mv.move = Vector2(1, 0)
	mv.aim = c.aim
	var x0: float = e.position.x
	sim._apply_command(e, mv, m, 0.1)
	var ride_d: float = e.position.x - x0
	check(ride_d > e.stats.move_speed * 0.1 * 1.4, "montado anda mais rápido (%.2f m)" % ride_d)
	# atacar desmonta e o ataque sai
	var atk := InputCommand.new()
	atk.attack = true
	atk.aim = c.aim
	e.basic_cd = 0.0
	sim._apply_command(e, atk, m, 1.0 / 60.0)
	check(not e.mounted and e.state == SimEntity.State.CASTING, "atacar desmonta e o golpe acontece")
	# levar golpe desmonta; em combate não monta
	sim._apply_command(e, c, m, 1.0 / 60.0)
	check(not e.mounted, "em combate (acabou de atacar) não monta")
	e.combat_timer = 0.0
	e.set_state(SimEntity.State.IDLE)
	e.current_skill = null
	sim._apply_command(e, c, m, 1.0 / 60.0)
	check(e.mounted, "fora de combate monta de novo")
	var mob: SimEntity = sim.spawn_monster(gd.monsters["wolf"], "city_aldara", e.position + Vector3(1, 0, 0))
	mob.brain = null
	sim._deal_damage(mob, e, 5, false, false, "physical")
	check(not e.mounted, "levar golpe derruba do cavalo")
	sim.despawn(mob)
	sim.despawn(e)
	_check_horse_model()

## Cavalo: rig próprio (joelho/jarrete), clipes em loop e o lombo que sobe/balança no galope (o cavaleiro acompanha).
func _check_horse_model() -> void:
	var h := FormModel.create_from("res://assets/models/mob_horse.glb")
	check(h != null and h.anim != null and h.skeleton != null, "cavalo: modelo com esqueleto e animações")
	if h == null or h.anim == null or h.skeleton == null:
		return
	add_child(h)
	for a in ["idle", "walk", "run"]:
		check(h.anim.has_animation(a) and h.anim.get_animation(a).loop_mode == Animation.LOOP_LINEAR, "cavalo: clipe %s em loop" % a)
	for b in ["leg_fr_lo", "leg_bl_lo", "neck", "tail2"]:
		check(h.skeleton.find_bone(b) >= 0, "cavalo: osso " + b)
	var ys: Array = []
	for i in range(4):
		h.anim.play("run")
		h.anim.seek(h.anim.get_animation("run").length * i / 4.0, true)
		ys.append(h.bone_delta("body").origin.y)
	check(absf(float(ys.max()) - float(ys.min())) > 0.02, "cavalo: o lombo sobe e desce no galope (%s)" % str(ys))
	h.queue_free()

func _check_away_maps(gd, sim) -> void:
	# mapa sem o jogador roda a cada AWAY_MAP_EVERY ticks com passo maior: o tempo de jogo lá anda igual
	var cls: ClassDef = gd.classes["paladin"]
	var keep = sim.player
	var p: SimEntity = sim.spawn_character(SimEntity.Kind.PLAYER, cls, "Foco", "city_aldara", Vector3(3, 0, 3))
	sim.player = p
	var far: SimEntity = sim.spawn_character(SimEntity.Kind.BOT, cls, "Longe", "field_forest", Vector3(0, 0, 0))
	far.cooldowns["teste"] = 10.0
	var near: SimEntity = sim.spawn_character(SimEntity.Kind.BOT, cls, "Perto", "city_aldara", Vector3(4, 0, 4))
	near.cooldowns["teste"] = 10.0
	for i in range(Balance.AWAY_MAP_EVERY * 20):
		sim.tick(1.0 / 60.0)
	var d_far: float = 10.0 - float(far.cooldowns.get("teste", 0.0))
	var d_near: float = 10.0 - float(near.cooldowns.get("teste", 0.0))
	check(absf(d_far - d_near) < 0.1 and d_near > 1.0, "mapa longe anda no mesmo tempo (%.2f s x %.2f s)" % [d_far, d_near])
	sim.despawn(far)
	sim.despawn(near)
	sim.despawn(p)
	sim.player = keep

func _check_craft_class(gd, sim) -> void:
	# cada classe só vê/cria o que pode usar; poções são de todos
	for cid in gd.classes:
		var cls: ClassDef = gd.classes[cid]
		var e: SimEntity = sim.spawn_bot(cls, "Craft", "city_aldara", Vector3(12, 0, 12), 30)
		e.brain = null
		e.gold = 99999
		for station in ["smith", "alchemy"]:
			for r in CraftSystem.recipes_for_station(station, cls):
				var it: ItemDef = gd.items[r.result_item]
				if it.is_equipment():
					check(sim.equip_error(e, it) == "" or sim.equip_error(e, it, true) == "", "%s: receita %s é de algo que a classe usa" % [cid, r.id])
		check(CraftSystem.recipes_for_station("alchemy", cls).any(func(r): return r.result_item == "potion_hp_s"), "%s: poções aparecem para todos" % cid)
		sim.despawn(e)
	var gear_r: Array = gd.recipes.values().filter(func(r): return gd.items[r.result_item].is_equipment() and not (gd.items[r.result_item].slot in [ItemDef.Slot.CAPE, ItemDef.Slot.AMULET, ItemDef.Slot.RING]))
	check(gear_r.is_empty(), "forja não faz armas nem armaduras (só joias, capas e bolsas): %s" % str(gear_r.map(func(r): return r.id).slice(0, 4)))

func _check_looks(gd, sim) -> void:
	var cls: ClassDef = gd.classes["paladin"]
	var d := LooksCatalog.default_look(cls)
	check(d["sex"] == cls.body_type and LooksCatalog.HAIR.has(d["hair"]) and d["beard"] == "none", "visual padrão da classe")
	var bad := LooksCatalog.normalized({"sex": "x", "hair": "nope", "eyes": "big", "eye_color": "3a6ab0"}, cls)
	check(bad["sex"] == cls.body_type and bad["hair"] == "short" and bad["eyes"] == "big" and bad["eye_color"] == "3a6ab0", "look inválido vira padrão, o válido fica")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var sexes := {}
	for i in range(40):
		var r := LooksCatalog.random_look(rng)
		sexes[r["sex"]] = true
		check(r["sex"] == "male" or r["beard"] == "none", "bot feminino sem barba")
	check(sexes.size() == 2, "bots dos dois sexos")
	# jogador: o visual escolhido vai para a entidade e volta do save
	var look := {"sex": "female", "hair": "ponytail", "hair_color": "b8322e", "beard": "none", "beard_color": "b8322e", "eyes": "sharp", "eye_color": "2e6a3a"}
	var p: SimEntity = sim.spawn_character(SimEntity.Kind.BOT, cls, "Look", "city_aldara", Vector3(5, 0, 5))
	p.look = LooksCatalog.normalized(look, cls)
	var back := LooksCatalog.normalized(JSON.parse_string(JSON.stringify({"look": p.look}))["look"], cls)
	check(back == p.look and back["hair"] == "ponytail", "visual sobrevive ao save (JSON)")
	sim.despawn(p)
	# kits: todas as variantes de cabelo/barba/olhos existem e o kit liga só a escolhida
	for kit_path in ["res://assets/models/kit_male.glb", "res://assets/models/kit_paladin_female.glb"]:
		if not ResourceLoader.exists(kit_path):
			check(false, "kit existe: %s" % kit_path)
			continue
		var k := KitModel.create("female" if kit_path.contains("female") else "male", Color.WHITE, 0.0, "paladin" if kit_path.contains("paladin") else "")
		for h in LooksCatalog.HAIR:
			check(k._nodes.has("base_hair_" + h), "%s: cabelo %s" % [kit_path.get_file(), h])
		for bd in LooksCatalog.BEARDS:
			check(bd == "none" or k._nodes.has("base_beard_" + bd), "%s: barba %s" % [kit_path.get_file(), bd])
		for ey in LooksCatalog.EYES:
			check(k._nodes.has("base_eyes_" + ey), "%s: olhos %s" % [kit_path.get_file(), ey])
		k.apply_look({"hair": "spiky", "beard": "goatee", "eyes": "big", "hair_color": "e8e4dc", "eye_color": "c03030"})
		k.apply_equipment({})
		var shown: Array = k._nodes.keys().filter(func(n): return (n.begins_with("base_hair_") or n.begins_with("base_beard_") or n.begins_with("base_eyes_")) and k._nodes[n].visible).map(func(n): return str(n))
		shown.sort()
		check(shown == ["base_beard_goatee", "base_eyes_big", "base_hair_spiky"], "%s: só o visual escolhido aparece (%s)" % [kit_path.get_file(), str(shown)])
		k.free()

func _check_hunts(gd, sim) -> void:
	var hunts: Array = gd.quests.values().filter(func(q): return q.id.begins_with("h_"))
	check(hunts.size() >= 6, "caçadas repetíveis geradas (%d)" % hunts.size())
	for q in hunts:
		check(q.repeatable and gd.monsters.has(q.target_id) and not gd.monsters[q.target_id].is_boss and q.reward_xp > 0 and q.map_hint != "", "caçada %s válida" % q.id)
	# NPC só com repetíveis mostra o marcador azul de repetível
	var cls: ClassDef = gd.classes["paladin"]
	var e: SimEntity = sim.spawn_bot(cls, "Rep", "city_aldara", Vector3(10, 0, -10), 40)
	e.brain = null
	for qid in gd.quests:
		if not gd.quests[qid].repeatable:
			e.quests_completed.append(qid)
	check(QuestSystem.npc_marker(e, "board") == QuestSystem.REPEAT, "quadro com só repetíveis mostra ↻")
	sim.despawn(e)
	# densidade: campos ganham mais monstros que o exportado
	var md: MapDef = gd.maps["field_forest"]
	var total := 0
	for sp in md.spawners:
		total += int(sp["count"])
	check(total >= 55, "Floresta com monstros suficientes (%d)" % total)

## Debuffs dos elementos: Trovão atordoa, fogo queima (dano no tempo marcado como queimadura), gelo estilhaça alvo retardado.
var _dmg_kinds: Array = []

func _note_damage(_a: int, _t: int, _amount: int, _crit: bool, _blocked: bool, kind: String) -> void:
	_dmg_kinds.append(kind)

## Barra de buffs: todo estado tem ícone; anel arrastado vai para o slot escolhido.
func _check_status_and_drag(gd, sim) -> void:
	for k in ["burn", "poison", "slow", "root", "stun", "curse", "wither", "shield", "juramento", "buff"]:
		check(ResourceLoader.exists("res://assets/icons/status_%s.png" % k), "ícone de estado %s (make_icons -- --only=status)" % k)
	var e: SimEntity = sim.spawn_bot(gd.classes["paladin"], "Anel", "city_aldara", Vector3(-40, 0, -40), 30)
	e.brain = null
	var rings: Array = gd.items.keys().filter(func(i): return gd.items[i].slot == ItemDef.Slot.RING and gd.items[i].level_req <= 30 and gd.items[i].class_restriction.is_empty())
	e.equipment.erase(ItemDef.Slot.RING)          # bot de nível 30 já nasce de anel
	e.equipment.erase(ItemDef.Slot.RING2)
	check(rings.size() >= 1, "há anel para testar o slot escolhido")
	if rings.size() >= 1:
		e.add_item(rings[0], 1)
		check(sim.equip(e, rings[0], false, ItemDef.Slot.RING2) and e.equipment.get(ItemDef.Slot.RING2) != null and e.equipment.get(ItemDef.Slot.RING) == null,
			"anel solto no 2º slot fica no 2º slot")
	sim.despawn(e)

## Maestria pela árvore: compra de novo até o máximo, 1 ponto por nível.
func _check_mastery_rebuy(gd, sim) -> void:
	var e: SimEntity = sim.spawn_bot(gd.classes["paladin"], "Mestre", "city_aldara", Vector3(-42, 0, -42), 30)
	e.brain = null
	var sid: String = e.class_def.starting_skills[0]
	e.mastery[sid] = 0
	e.mastery_points = 10
	var bought := 0
	for i in range(Balance.MASTERY_MAX + 2):
		if sim.upgrade_mastery(e, sid):
			bought += 1
	check(bought == Balance.MASTERY_MAX and e.mastery_of(sid) == Balance.MASTERY_MAX and e.mastery_points == 10 - Balance.MASTERY_MAX,
		"maestria pela árvore sobe até %d (comprou %d, M%d, sobraram %d pontos)" % [Balance.MASTERY_MAX, bought, e.mastery_of(sid), e.mastery_points])
	check(sim.tree_block_reason(e, "%s_m_%s" % [e.class_def.id, sid]) == "maestria já no máximo", "maestria no máximo não compra mais")
	sim.despawn(e)

## Mini-chefe nível 5 no Vale (1º conjunto lendário) e chance maior do 1º conjunto no primeiro mapa.
func _check_first_set_drops(gd, sim) -> void:
	var b: MonsterDef = gd.monsters.get("boar_brute")
	check(b != null and b.is_boss and b.level == 5, "Javali Presa-Rachada: chefe nível 5")
	check(gd.monsters.has("boar_piglet") and gd.monsters["boar_piglet"].xp == 0, "leitões do chefe não dão XP")
	var sps: Array = gd.maps["city_aldara"].spawners.filter(func(s): return s["monster_id"] == "boar_brute")
	check(sps.size() == 1 and int(sps[0]["count"]) == 1, "Vale de Aldara tem um Presa-Rachada")
	var m: Dictionary = sim.maps["city_aldara"]
	if sps.size() == 1:
		check(not sim._point_in_solid(sps[0]["pos"], m), "Presa-Rachada nasce em chão livre")
	var e: SimEntity = sim.spawn_bot(gd.classes["berserker"], "Caça", "city_aldara", Vector3(60, 0, 14), 6)
	e.brain = null
	var tiers := {}
	for i in range(40):
		var id: String = sim.pick_legendary(e, b.level)
		if id != "" and gd.items.has(id):
			tiers[gd.items[id].level_req] = true
	check(tiers.keys() == [Balance.LEGENDARY_LEVELS[0]], "Presa-Rachada dá o 1º conjunto (níveis %s)" % str(tiers.keys()))
	var boss: SimEntity = sim.spawn_monster(b, "city_aldara", Vector3(80, 0, 14))
	var boar: SimEntity = sim.spawn_monster(gd.monsters["boar"], "city_aldara", Vector3(72, 0, 6))
	var king: SimEntity = sim.spawn_monster(gd.monsters["boar_king"], "city_aldara", Vector3(-84, 0, 24))
	check(is_equal_approx(sim.legendary_chance(boss), Balance.LEGENDARY_DROP_CHANCE_BOSS), "chefe: chance de chefe")
	check(is_equal_approx(sim.legendary_chance(boar), Balance.LEGENDARY_START_MAP_CHANCE), "Javali no Vale: chance maior do 1º conjunto")
	check(is_equal_approx(sim.legendary_chance(king), Balance.LEGENDARY_DROP_CHANCE_BOSS), "Rei Javali segue chance de chefe")
	var wolf_far: SimEntity = sim.spawn_monster(gd.monsters["wolf"], "field_forest", Vector3(0, 0, 0)) if sim.maps.has("field_forest") else null
	if wolf_far:
		check(is_equal_approx(sim.legendary_chance(wolf_far), Balance.LEGENDARY_DROP_CHANCE), "fora do Vale: chance normal")
		sim.despawn(wolf_far)
	for x in [boss, boar, king, e]:
		sim.despawn(x)

## /party (bots do mapa convidam um por vez), depósito (guardar/tirar, perto do NPC, salva) e a cor do monstro de modelo emprestado.
func _check_party_seek_storage(gd, sim, save) -> void:
	var town: Vector3 = sim.maps["city_aldara"]["def"].town_center
	var me: SimEntity = sim.spawn_bot(gd.classes["ranger"], "Procura", "city_aldara", town + Vector3(2, 0, 2), 10)
	me.brain = null
	var helpers: Array = []
	for i in range(3):
		var b: SimEntity = sim.spawn_bot(gd.classes["paladin"], "Ajuda%d" % i, "city_aldara", town + Vector3(3 + i, 0, 3), 10)
		helpers.append(b)
	var n: int = sim.party_seek_start(me)
	check(n >= 2 and n <= Balance.PARTY_SEEK_MAX, "/party: bots do mapa se oferecem (%d)" % n)
	check(sim.party_seek_start(me) == -2, "/party tem tempo de espera")
	for i in range(30):
		sim._update_invites()
		sim.time += 0.1
		if sim.invites.has(me.id):
			sim.invites[me.id]["decide_at"] = sim.time + 100.0     # quem decide é o teste (aqui ele é um bot)
	check(sim.invites.has(me.id), "/party: chega um convite")
	var first: int = sim.invites[me.id]["from"]
	sim.party_decline(me)
	for i in range(15):
		sim._update_invites()
		sim.time += 0.1
		if sim.invites.has(me.id):
			sim.invites[me.id]["decide_at"] = sim.time + 100.0
	check(sim.invites.has(me.id) and sim.invites[me.id]["from"] != first, "/party: recusou → o próximo convida")
	sim.party_accept(me)
	check(me.party_id >= 0, "/party: aceitar entra no grupo")
	sim.party_leave(me)
	for b in helpers:
		if b.party_id >= 0:
			sim.party_leave(b)
		sim.despawn(b)
	# depósito
	var st: Dictionary = {}
	for npc in gd.maps["city_aldara"].npcs:
		if npc["role"] == "storage":
			st = npc
	check(not st.is_empty(), "Aldara tem o Guarda-volumes")
	if not st.is_empty():
		check(not sim._point_in_solid(st["pos"], sim.maps["city_aldara"]), "Guarda-volumes em chão livre")
		me.position = st["pos"] + Vector3(0, 0, 1.5)
	me.inventory = {"iron_ore": 5}
	me.storage = {}
	check(sim.storage_deposit(me, "iron_ore", 3) and int(me.inventory.get("iron_ore", 0)) == 2 and int(me.storage.get("iron_ore", 0)) == 3, "depósito guarda")
	check(not sim.storage_deposit(me, "iron_ore", 5), "não guarda mais do que tem")
	check(sim.storage_withdraw(me, "iron_ore", 3) and not me.storage.has("iron_ore") and int(me.inventory["iron_ore"]) == 5, "depósito devolve")
	me.position = town + Vector3(20, 0, 20)
	check(not sim.storage_deposit(me, "iron_ore", 1), "longe do NPC não guarda")
	me.storage = {"wolf_pelt": 4}
	save.save_player(me)
	var d: Dictionary = save.load_data()
	check(int(d.get("storage", {}).get("wolf_pelt", 0)) == 4, "save guarda o depósito")
	save.delete_slot(TEST_SLOT)
	sim.despawn(me)
	# cor: Slime Azul fica azul; o Slime (dono do modelo) não muda; olho não muda
	var green := Color("adf1b8")
	var blue := EntityView.monster_tint(gd.monsters["slime_blue"], green, "m_slime_mob_slime")
	check(blue.b > blue.g and blue.b > blue.r, "Slime Azul é azul (%s)" % blue.to_html(false))
	check(EntityView.monster_tint(gd.monsters["slime"], green, "m_slime_mob_slime").is_equal_approx(green), "Slime comum mantém a cor do modelo")
	check(EntityView.monster_tint(gd.monsters["slime_blue"], Color("504559"), "m_eye").is_equal_approx(Color("504559")), "olho não muda de cor")

## Grupo segue o líder pelo portal e reaparece ao lado dele se ficar preso; Rei surge após muitos abates com lendário garantido.
func _check_party_follow_elite(gd, sim) -> void:
	var lead: SimEntity = sim.spawn_bot(gd.classes["paladin"], "Lider", "city_aldara", Vector3(60, 0, 10), 8)
	lead.brain = null
	var mate: SimEntity = sim.spawn_bot(gd.classes["bishop"], "Ajudante", "city_aldara", Vector3(63, 0, 10), 8)
	var far: SimEntity = sim.spawn_bot(gd.classes["ranger"], "Longe", "field_forest" if sim.maps.has("field_forest") else "city_aldara", Vector3(0, 0, 0), 8)
	sim.party_invite(lead, mate)
	sim.party_accept(mate)
	sim.party_invite(lead, far)
	sim.party_accept(far)
	var dg := ""
	for mid in gd.maps:
		if gd.maps[mid].parent_map == "city_aldara":
			dg = mid
	check(dg != "", "há dungeon saindo do Vale")
	if dg != "":
		sim._pending_map_changes.append({"e": lead, "map": dg, "pos": Vector3.ZERO})
		sim._process_map_changes()
		check(lead.map_id == dg and mate.map_id == dg, "bot do grupo passa pelo portal com o líder")
		check(mate.position.distance_to(lead.position) < 4.0, "e chega ao lado dele")
		if far.map_id != dg:
			for i in range(int(Balance.PARTY_CATCHUP_TIME / 0.5) + 2):
				sim._party_catchup(0.5)
			sim._process_map_changes()
			check(far.map_id == dg, "bot preso em outro mapa reaparece ao lado do líder")
	for x in [mate, far]:
		sim.party_leave(x)
	for x in [lead, mate, far]:
		sim.despawn(x)
	# jogador que aceita convite de bot passa a liderar (os bots seguem o jogador)
	var pl: SimEntity = sim.player
	if pl and pl.party_id >= 0:
		sim.party_leave(pl)
	if pl:
		var host: SimEntity = sim.spawn_bot(gd.classes["paladin"], "Anfitriao", pl.map_id, pl.position + Vector3(2, 0, 0), pl.level)
		var other: SimEntity = sim.spawn_bot(gd.classes["bishop"], "Outro", pl.map_id, pl.position + Vector3(3, 0, 0), pl.level)
		sim.party_invite(host, other)
		sim.party_accept(other)
		sim.invites.erase(pl.id)
		sim.party_invite(host, pl)
		sim.party_accept(pl)
		check(sim.party_leader(other) == pl, "convite de bot aceito: o jogador lidera e os bots o seguem")
		for x in [other, host, pl]:
			if x.party_id >= 0:
				sim.party_leave(x)
		sim.despawn(host)
		sim.despawn(other)
	# Rei: 40 abates de slime no mesmo mapa
	var m: Dictionary = sim.maps["city_aldara"]
	var hunter: SimEntity = sim.spawn_bot(gd.classes["berserker"], "Cacador", "city_aldara", Vector3(10, 0, 60), 6)
	hunter.brain = null
	m["kills"].erase("slime")
	m["elites"].erase("slime")
	var king: SimEntity = null
	for i in range(Balance.ELITE_KILLS):
		var s: SimEntity = sim.spawn_monster(gd.monsters["slime"], "city_aldara", Vector3(10, 0, 62))
		s.brain = null
		s.damage_by = {hunter.id: 999.0}
		sim._on_monster_killed(s, hunter)
		sim.despawn(s)
	var kid: int = int(m["elites"].get("slime", -1))
	king = sim.entities.get(kid)
	check(king != null and king.monster_def.elite_of == "slime", "%d abates de slime fazem surgir o Rei Slime" % Balance.ELITE_KILLS)
	if king:
		var base: MonsterDef = gd.monsters["slime"]
		check(is_equal_approx(king.monster_def.hp, base.hp * Balance.ELITE_HP_MULT) and king.monster_def.scale > base.scale, "Rei: 5x vida e maior")
		check(is_equal_approx(sim.legendary_chance(king), 1.0), "Rei: lendário garantido")
		var got := ""
		for t in range(5):
			got = sim.roll_legendary(hunter, king)
			if got != "":
				break
		check(got == "legend_coin", "Rei Slime solta Moeda Lendária (%s)" % got)
		sim.despawn(king)
	sim.despawn(hunter)

## G volta à cidade: 3 s parado, fora de combate; andar cancela. Lendário é pessoal (cada membro do grupo rola o seu).
func _check_recall_and_personal_loot(gd, sim) -> void:
	var town: String = gd.town_map_id()
	var e: SimEntity = sim.spawn_bot(gd.classes["paladin"], "Volta", "city_aldara", Vector3(70, 0, 10), 8)
	e.brain = null
	var go := InputCommand.new()
	go.recall = true
	var idle := InputCommand.new()
	sim._update_recall(e, go, go, 0.1)
	check(e.recall_left > 0.0, "G começa a volta à cidade")
	var walk := InputCommand.new()
	walk.move = Vector2(1, 0)
	sim._update_recall(e, walk, walk, 0.1)
	check(is_equal_approx(e.recall_left, 0.0), "andar cancela a volta")
	sim._update_recall(e, go, go, 0.1)
	for i in range(int(Balance.RECALL_TIME / 0.1) + 2):
		sim._update_recall(e, idle, idle, 0.1)
	sim._process_map_changes()
	check(e.map_id == town and e.position.distance_to(gd.maps[town].spawn_point) < 0.5, "parado 3 s: chega na cidade")
	e.position = Vector3(70, 0, 10)
	e.combat_timer = 3.0
	sim._update_recall(e, go, go, 0.1)
	check(is_equal_approx(e.recall_left, 0.0), "em combate não volta")
	e.combat_timer = 0.0
	sim.despawn(e)
	# lendário pessoal: chefe com dois do grupo → cada um rola o seu
	var a: SimEntity = sim.spawn_bot(gd.classes["berserker"], "Um", "city_aldara", Vector3(80, 0, 14), 6)
	var b: SimEntity = sim.spawn_bot(gd.classes["bishop"], "Dois", "city_aldara", Vector3(81, 0, 14), 6)
	sim.party_invite(a, b)
	sim.party_accept(b)
	var king: SimEntity = sim.spawn_monster(sim.elite_def(gd.monsters["boar"]), "city_aldara", Vector3(82, 0, 14))
	king.brain = null
	king.damage_by = {a.id: 500.0, b.id: 400.0}
	var m: Dictionary = sim.maps["city_aldara"]
	var before: int = m["loot"].size()
	sim._on_monster_killed(king, a)
	var owners := {}
	for l in m["loot"].slice(before):
		if l["item"] == "legend_coin":
			owners[l["owner"]] = int(l["count"])
	check(owners.has(a.id) and owners.has(b.id), "Rei: cada membro do grupo ganha as suas moedas lendárias (%d donos)" % owners.size())
	check(int(owners.get(a.id, 0)) == Balance.LEGENDARY_COINS_BOSS, "chefe/Rei: %d moedas" % Balance.LEGENDARY_COINS_BOSS)
	# Relicária: troca moedas por peça da classe, preço pelo tier
	var npc: Dictionary = {}
	for n in gd.maps["city_aldara"].npcs:
		if n["role"] == "relic":
			npc = n
	check(not npc.is_empty() and not sim._point_in_solid(npc["pos"], m), "Aldara tem a Relicária em chão livre")
	var buyer: SimEntity = sim.spawn_bot(gd.classes["paladin"], "Compra", "city_aldara", npc.get("pos", Vector3.ZERO) + Vector3(0, 0, 1.5), 12)
	buyer.brain = null
	var offer: Array = sim.relic_offer(buyer)
	var t5: Array = offer.filter(func(i): return gd.items[i].level_req == 5)
	var t10: Array = offer.filter(func(i): return gd.items[i].level_req == 10)
	check(t5.size() >= 6 and t10.size() >= 6, "Relicária oferece peças da classe por nível (%d no 5, %d no 10)" % [t5.size(), t10.size()])
	check(offer.any(func(i): return gd.items[i].weapon_type == "shield"), "paladino também troca escudos nomeados")
	check(sim.relic_cost(gd.items[t5[0]]) == 1 and sim.relic_cost(gd.items[t10[0]]) == 2, "nível 5 = 1 moeda, nível 10 = 2")
	buyer.inventory = {"legend_coin": 2}
	check(sim.relic_exchange(buyer, t10[0]) and buyer.has_item(t10[0]) and not buyer.inventory.has("legend_coin"), "troca 2 moedas por peça nível 10")
	buyer.add_item("legend_coin", 5)
	var t15: Array = offer.filter(func(i): return gd.items[i].level_req == 15)
	check(sim.relic_block_reason(buyer, t15[0]).begins_with("requer nível"), "peça acima do nível: não troca")
	buyer.position += Vector3(30, 0, 0)
	check(sim.relic_block_reason(buyer, t5[0]) == "fale com a Relicária", "longe da Relicária: não troca")
	buyer.inventory = {"legend_coin": 3, "slime_gel": 2}
	BotBrain.new()._sell_materials(buyer)
	check(int(buyer.inventory.get("legend_coin", 0)) == 3 and not buyer.inventory.has("slime_gel"), "bot vende material mas guarda a moeda")
	sim.despawn(buyer)
	sim.party_leave(b)
	for x in [king, a, b]:
		sim.despawn(x)

## Grupo: o jogador recebe saque pessoal a cada abate dividido, mesmo sem bater; item dos outros só aparece quando fica livre.
func _check_party_personal_loot(gd, sim) -> void:
	var pl: SimEntity = sim.player
	if pl == null:
		return
	if pl.party_id >= 0:
		sim.party_leave(pl)
	var keep_pos := pl.position
	var bot: SimEntity = sim.spawn_bot(gd.classes["berserker"], "Batedor", pl.map_id, pl.position + Vector3(2, 0, 0), pl.level)
	bot.brain = null
	sim.party_invite(bot, pl)
	sim.party_accept(pl)
	var m: Dictionary = sim.maps[pl.map_id]
	var got := 0
	for i in range(20):
		var mob: SimEntity = sim.spawn_monster(gd.monsters["boar"], pl.map_id, pl.position + Vector3(3, 0, 0))
		mob.brain = null
		mob.damage_by = {bot.id: 999.0}            # só o bot bateu (o jogador é o suporte)
		var before: int = m["loot"].size()
		sim._on_monster_killed(mob, bot)
		for l in m["loot"].slice(before):
			if int(l["owner"]) == pl.id:
				got += 1
		sim.despawn(mob)
	check(got >= 10, "grupo: suporte (sem bater) recebe saque pessoal (%d itens em 20 abates)" % got)
	var other := {"owner": bot.id, "free_at": sim.time + 10.0}
	check(not sim.loot_visible_to(pl, other) and sim.loot_visible_to(pl, {"owner": pl.id, "free_at": sim.time + 10.0}), "item do bot fica escondido; o seu aparece")
	other["free_at"] = sim.time - 1.0
	check(sim.loot_visible_to(pl, other), "item do bot que ficou livre aparece")
	for l in m["loot"].duplicate():
		if int(l["owner"]) in [pl.id, bot.id]:
			m["loot"].erase(l)
	sim.party_leave(pl)
	sim.despawn(bot)
	pl.position = keep_pos

## Todo equipamento tem descrição na dica (a escrita ou a montada dos dados: peça, quem usa, o que favorece).
func _check_item_descriptions(gd) -> void:
	var empty: Array = []
	for iid in gd.items:
		var it: ItemDef = gd.items[iid]
		if it.is_equipment() and UiKit.item_summary(it).length() < 8:
			empty.append(iid)
	check(empty.is_empty(), "todo equipamento tem descrição (%d sem: %s)" % [empty.size(), str(empty.slice(0, 4))])
	check(UiKit.item_tooltip(gd.items["sword_rusty"]).contains("Favorece"), "dica do equipamento diz o que os atributos favorecem")

## Arma lendária: efeito próprio pelo papel (eco / retaliação / égide); atributos de toda build servem a ela.
func _check_legend_weapons_and_attrs(gd, sim) -> void:
	var useful := {}
	for cid in gd.classes:
		var cls: ClassDef = gd.classes[cid]
		var mine := {"VIT": true}          # VIT (vida) serve a qualquer um
		for b in cls.builds:
			mine[b["attr"]] = true
			mine[b["attr2"]] = true
			var caster: bool = b["role"] in ["caster", "healer"] or b["stat"] in ["matk_pct", "heal_pct"]
			check(not (caster and (b["attr"] == "AGI" or b["attr2"] == "AGI")), "%s/%s: build mágica sem AGI" % [cid, b["id"]])
			check(not (caster and (b["attr"] == "FOR" or b["attr2"] == "FOR")) or b["role"] == "tank", "%s/%s: build mágica sem FOR" % [cid, b["id"]])
		useful[cid] = mine
		for iid in ItemsCatalog.starter_ids(cid):
			if gd.items.has(iid):
				for a in gd.items[iid].attributes:
					check(mine.has(a), "%s: conjunto inicial só dá atributo que a classe usa (%s)" % [iid, a])
	var bad: Array = []
	for sid in gd.sets:
		var sd: SetDef = gd.sets[sid]
		for iid in sd.pieces + sd.alt_pieces:
			for a in gd.items[iid].attributes:
				if not useful[sd.class_id].has(a):
					bad.append("%s:%s" % [iid, a])
		for k in sd.bonuses:
			for a in sd.bonuses[k].get("attrs", {}):
				if not useful[sd.class_id].has(a):
					bad.append("%s bônus %s:%s" % [sid, k, a])
	check(bad.is_empty(), "conjuntos lendários só dão atributos que a classe usa (%s)" % str(bad.slice(0, 4)))
	for d in GearCatalog.SHIELDS:            # escudos nomeados: atributos de quem pode usar (pela afinidade)
		var sh: ItemDef = gd.items["shield_" + d[0]]
		for cid in ["paladin", "bishop"]:
			if GearCatalog.shield_fits(sh.id, cid):
				for a in sh.attributes:
					check(useful[cid].has(a), "%s serve ao %s: atributo %s" % [sh.id, cid, a])
	# efeitos por papel
	var role_of := {}
	for cid in gd.classes:
		for b in gd.classes[cid].builds:
			role_of["%s_%s" % [cid, b["id"]]] = b["role"]
	for sid in gd.sets:
		var sd: SetDef = gd.sets[sid]
		var w: ItemDef = gd.items.get(sd.pieces.filter(func(x): return x.ends_with("_weapon"))[0]) if sd.pieces.any(func(x): return x.ends_with("_weapon")) else null
		check(w != null and not w.legend_effect.is_empty(), "%s: arma lendária tem efeito próprio" % sid)
		if w:
			var bid: String = sd.id.trim_prefix("set_%s_" % sd.class_id).rsplit("_", true, 1)[0]
			check(GearCatalog.LEGEND_EFFECTS.has(bid) and w.legend_effect["kind"] == GearCatalog.LEGEND_EFFECTS[bid]["kind"], "%s: efeito próprio da build %s" % [sid, bid])
			check(UiKit.legend_effect_text(w.legend_effect).length() > 12, "%s: texto do efeito" % sid)
	var names := {}
	for bid in GearCatalog.LEGEND_EFFECTS:
		names[GearCatalog.LEGEND_EFFECTS[bid]["name"]] = true
		var sk: String = GearCatalog.LEGEND_EFFECTS[bid].get("skill", "")
		check(sk == "" or gd.skills.has(sk), "%s: skill do efeito existe (%s)" % [bid, sk])
	check(names.size() == GearCatalog.LEGEND_EFFECTS.size(), "cada build tem um efeito lendário com nome próprio (%d)" % names.size())
	# eco: golpe direto bate de novo (forçando a chance)
	var a: SimEntity = sim.spawn_bot(gd.classes["berserker"], "Eco", "city_aldara", Vector3(-46, 0, -46), 20)
	a.brain = null
	var mob: SimEntity = sim.spawn_monster(gd.monsters["golem"], "city_aldara", Vector3(-46, 0, -44.5))
	mob.brain = null
	a.stats.legend = {"kind": "echo"}
	a.stats.echo_chance = 100.0
	a.stats.echo_pct = 50.0
	_dmg_kinds.clear()
	Events.damage_dealt.connect(_note_damage)
	sim._deal_damage(a, mob, 100, false, false, "physical")
	check(_dmg_kinds.has("echo") and _dmg_kinds.count("echo") == 1, "Eco: o golpe bate de novo uma vez (%s)" % str(_dmg_kinds))
	# retaliação: tanque devolve parte do corpo a corpo
	a.stats.echo_chance = 0.0
	a.stats.thorns_pct = 20.0
	_dmg_kinds.clear()
	var mhp: float = mob.hp
	sim._deal_damage(mob, a, 100, false, false, "physical")
	check(_dmg_kinds.has("thorns") and mob.hp < mhp, "Retaliação: quem bate corpo a corpo leva parte de volta")
	Events.damage_dealt.disconnect(_note_damage)
	# Elementalista: fogo lança Bola de Fogo no básico; gelo lança Nova ao levar golpe (uma vez a cada 20 s); raio salta
	var el: SimEntity = sim.spawn_bot(gd.classes["elementalist"], "Ele2", "city_aldara", Vector3(-46, 0, -46), 20)
	el.brain = null
	var mob2: SimEntity = sim.spawn_monster(gd.monsters["golem"], "city_aldara", Vector3(-44.5, 0, -44.5))
	mob2.brain = null
	var basic: SkillDef = el.basic_skill
	var m: Dictionary = sim.maps["city_aldara"]
	el.stats.legend = {"kind": "cast_on_basic", "skill": "ele_fireball", "chance": 100.0}
	var before: int = m["projectiles"].size()
	sim._legend_on_hit(el, mob, basic, 50)
	check(m["projectiles"].size() > before, "Brasa Viva (fogo): o básico lança uma Bola de Fogo")
	el.stats.legend = {"kind": "cast_when_hit", "skill": "ele_frost_nova", "icd": 20.0}
	el.legend_ready_at = 0.0
	var nhp: float = mob.hp
	sim._legend_weapon(mob, el, 30, "physical")
	check(mob.hp < nhp and mob.debuffs.any(func(d): return d.get("kind") in ["slow", "root"]), "Coração de Gelo: apanhou, solta a Nova de Gelo em volta")
	nhp = mob.hp
	sim._legend_weapon(mob, el, 30, "physical")
	check(is_equal_approx(mob.hp, nhp), "Coração de Gelo: não repete antes de 20 s")
	el.stats.legend = {"kind": "chain", "targets": 1, "pct": 60.0}
	var hp2: float = mob2.hp
	sim._legend_on_hit(el, mob, basic, 100)
	check(mob2.hp < hp2, "Arco Voltaico (raio): o básico salta para outro alvo")
	sim.despawn(mob2)
	sim.despawn(el)
	# égide: a cura vira barreira
	a.stats.thorns_pct = 0.0
	a.stats.ward_pct = 20.0
	a.hp = a.stats.max_hp * 0.5
	a.shield_hp = 0.0
	sim._heal(a, a, 100)
	check(a.shield_hp > 0.0 and a.buffs.any(func(x): return x.get("id") == "shield"), "Égide: cura dá barreira")
	sim.despawn(mob)
	sim.despawn(a)

func _check_elemental_debuffs(gd, sim) -> void:
	var m: Dictionary = sim.maps["city_aldara"]
	var at := Vector3(-36, 0, -36)
	var el: SimEntity = sim.spawn_bot(gd.classes["elementalist"], "Ele", "city_aldara", at, 30)
	el.brain = null
	var mob: SimEntity = sim.spawn_monster(gd.monsters["golem"], "city_aldara", at + Vector3(0, 0, 1.6))
	mob.brain = null
	# Trovão atordoa
	sim._apply_effects(el, mob, gd.skills["ele_thunder"].effects, 1.0)
	check(mob.state == SimEntity.State.STUNNED, "Trovão atordoa o alvo")
	mob.set_state(SimEntity.State.IDLE)
	# fogo queima: todo dano no tempo de skill de fogo é queimadura
	for sid in gd.skills:
		var sk: SkillDef = gd.skills[sid]
		if sk.effects.has("dot") and (sk.vfx == "fire" or sk.elements.has("fire")):
			check(bool(sk.effects["dot"].get("fire", false)), "%s: dano no tempo de fogo é queimadura" % sid)
	check(gd.skills["ele_phoenix"].effects.has("dot"), "Fênix queima")
	_dmg_kinds.clear()
	Events.damage_dealt.connect(_note_damage)
	var hp0: float = mob.hp
	sim._apply_effects(el, mob, gd.skills["ele_fireball"].effects, 1.0)
	for i in range(25):
		sim._update_entity(mob, m, 0.1)
	check(mob.hp < hp0 and _dmg_kinds.has("dot_fire"), "Bola de Fogo queima com o tempo (%.0f de dano, %s)" % [hp0 - mob.hp, str(_dmg_kinds.slice(0, 3))])
	# gelo estilhaça: mais dano em alvo retardado, preso ou atordoado; fogo não ganha o bônus
	mob.debuffs.clear()
	mob.set_state(SimEntity.State.IDLE)
	var lance: SkillDef = gd.skills["ele_ice_lance"]
	check(is_equal_approx(Combat.frost_mult(lance, mob), 1.0), "gelo em alvo normal: sem bônus")
	mob.debuffs.append({"kind": "slow", "remaining": 2.0, "pct": 30.0})
	check(is_equal_approx(Combat.frost_mult(lance, mob), Balance.FROST_SHATTER_MULT), "gelo em alvo retardado: estilhaço")
	check(is_equal_approx(Combat.frost_mult(gd.skills["ele_fireball"], mob), 1.0), "fogo não estilhaça")
	check(is_equal_approx(Combat.frost_mult(gd.skills["ran_frost_arrow"], mob), Balance.FROST_SHATTER_MULT), "flecha de gelo do Ranger também estilhaça")
	# no lance de verdade: Nova de Gelo no alvo normal = mágico; de novo no alvo já retardado = estilhaço
	mob.debuffs.clear()
	mob.hp = mob.stats.max_hp
	_dmg_kinds.clear()
	sim._apply_skill(el, gd.skills["ele_frost_nova"], m)
	var first := _dmg_kinds.duplicate()
	_dmg_kinds.clear()
	sim._apply_skill(el, gd.skills["ele_frost_nova"], m)
	check(first.has("magical") and not first.has("shatter") and _dmg_kinds.has("shatter"), "Nova de Gelo estilhaça quem já está retardado (%s → %s)" % [str(first), str(_dmg_kinds)])
	Events.damage_dealt.disconnect(_note_damage)
	# raio: chance de atordoar no golpe; Trovão (que já atordoa) e skills sem dano não rolam
	check(Combat.storm_can_stun(gd.skills["ele_lightning"]) and Combat.storm_can_stun(gd.skills["ele_chain"]), "Relâmpago e Corrente rolam atordoar")
	check(not Combat.storm_can_stun(gd.skills["ele_thunder"]) and not Combat.storm_can_stun(gd.skills["ele_overload"]) and not Combat.storm_can_stun(gd.skills["ele_fireball"]),
		"Trovão, Sobrecarga e Bola de Fogo não rolam o atordoar do raio")
	var stuns := 0
	for i in range(400):
		mob.set_state(SimEntity.State.IDLE)
		sim._storm_proc(el, gd.skills["ele_lightning"], mob)
		if mob.state == SimEntity.State.STUNNED:
			stuns += 1
	var rate := stuns / 4.0
	check(absf(rate - Balance.STORM_STUN_CHANCE) < 6.0, "raio atordoa em ~%.0f%% dos golpes (%.1f%%)" % [Balance.STORM_STUN_CHANCE, rate])
	sim.despawn(mob)
	sim.despawn(el)

func _check_necromancer_builds(gd, sim) -> void:
	var cls: ClassDef = gd.classes["necromancer"]
	check(Array(cls.weapon_types) == ["scythe"] and cls.builds.size() == 3 and not cls.builds.any(func(b): return b["main"] != ["scythe"]),
		"Necromancer: só foice, três focos que se misturam")
	for sid in cls.skill_ids:
		check(gd.skills[sid].requires.is_empty() or Array(gd.skills[sid].requires) == ["scythe"], "%s usável com foice" % sid)
	for mid in ["bone_hound", "lich_servant", "skeleton_king", "skeleton_minion"]:
		check(gd.monsters.has(mid) and gd.monsters[mid].xp == 0, "invocação %s existe e não dá XP" % mid)
	var m: Dictionary = sim.maps["city_aldara"]
	var at := Vector3(-30, 0, -30)
	var n: SimEntity = sim.spawn_bot(cls, "Nec", "city_aldara", at, 30)
	n.brain = null
	n.equipment[ItemDef.Slot.WEAPON] = gd.items["scythe_bone"]
	n.recompute_stats()
	# invocações: limite por tipo (cães 2, lich 1, rei 1) e juntas
	for i in range(2):
		for sid in ["nec_bone_hound", "nec_lich", "nec_skeleton_king"]:
			sim._apply_skill(n, gd.skills[sid], m)
	var count := {}
	for o in m["entities"]:
		if o.kind == SimEntity.Kind.SUMMON and o.owner_id == n.id and o.is_alive():
			count[o.monster_def.id] = int(count.get(o.monster_def.id, 0)) + 1
	check(count.get("bone_hound", 0) == 2 and count.get("lich_servant", 0) == 1 and count.get("skeleton_king", 0) == 1, "limite de invocação por tipo (%s)" % str(count))
	var king: SimEntity = m["entities"].filter(func(o): return o.kind == SimEntity.Kind.SUMMON and o.owner_id == n.id and o.monster_def.id == "skeleton_king")[0]
	var dog: SimEntity = m["entities"].filter(func(o): return o.kind == SimEntity.Kind.SUMMON and o.owner_id == n.id and o.monster_def.id == "bone_hound")[0]
	check(king.stats.patk > dog.stats.patk * 1.5, "Rei Esqueleto bate bem mais que o cão")
	for o in m["entities"].duplicate():
		if o.kind == SimEntity.Kind.SUMMON and o.owner_id == n.id:
			sim.despawn(o)
	# maldições: Condenação faz o alvo receber mais; Fraqueza faz causar menos
	var mob: SimEntity = sim.spawn_monster(gd.monsters["golem"], "city_aldara", at + Vector3(0, 0, 3))
	mob.brain = null
	var hp0: float = mob.hp
	sim._deal_damage(n, mob, 100, false, false, "magical")
	var plain := hp0 - mob.hp
	sim._apply_effects(n, mob, gd.skills["nec_curse_doom"].effects, 1.0)
	sim._apply_effects(n, mob, gd.skills["nec_curse_doom"].effects, 1.0)
	check(mob.debuffs.filter(func(d): return d.get("kind") == "curse").size() == 1, "a mesma maldição renova, não acumula")
	hp0 = mob.hp
	sim._deal_damage(n, mob, 100, false, false, "magical")
	check(hp0 - mob.hp > plain * 1.15, "amaldiçoado recebe mais dano (%.0f x %.0f)" % [hp0 - mob.hp, plain])
	sim._apply_effects(n, mob, gd.skills["nec_curse_weakness"].effects, 1.0)
	var nhp: float = n.hp
	sim._deal_damage(mob, n, 100, false, false, "physical")
	var weak_hit := nhp - n.hp
	check(weak_hit > 0.0 and weak_hit <= 80.0, "enfraquecido causa menos dano (%.0f de 100)" % weak_hit)
	n.hp = n.stats.max_hp
	# canalização: Açoite Mental aplica 4 pulsos durante a fase ativa
	var flay: SkillDef = gd.skills["nec_mind_flay"]
	n.position = at
	mob.position = at + Vector3(0, 0, 3)
	mob.hp = mob.stats.max_hp
	sim._start_skill(n, flay, -1, mob.position)
	var steps := 0
	while n.current_skill != null and steps < 400:
		sim._update_skill(n, m, 0.02)
		n.state_time += 0.02
		steps += 1
	check(n.channel_done == 4, "canalização aplica %d pulsos (%d)" % [4, n.channel_done])
	# formas: fantasma e demônio exigem foice e se trocam
	sim._apply_effects(n, n, gd.skills["nec_phantom"].effects, 0.0)
	check(n.form == "phantom" and n.stats.evasion > 0.0, "Forma Fantasma: esquiva e velocidade")
	sim._apply_effects(n, n, gd.skills["nec_demon_form"].effects, 0.0)
	check(n.form == "demon" and n.stats.lifesteal > 0.0, "Forma Demoníaca troca a fantasma")
	check(sim.resolve_skill(n, gd.skills["nec_reap"]).name == "Garra Infernal", "golpe de foice muda na forma demoníaca")
	sim._apply_effects(n, n, gd.skills["nec_demon_form"].effects, 0.0)
	check(n.form == "", "Forma Demoníaca desliga")
	# fantasma acaba sozinha (Balance.FORM_DURATION); demônio fica até desligar; usar de novo desfaz e zera o tempo
	var fdur: float = Balance.FORM_DURATION.get("phantom", 0.0)
	check(fdur > 0.0 and not Balance.FORM_DURATION.has("demon") and not Balance.FORM_DURATION.has("wolf"), "só a fantasma tem tempo")
	sim._apply_effects(n, n, gd.skills["nec_phantom"].effects, 0.0)
	check(n.form == "phantom" and is_equal_approx(n.form_left, fdur), "fantasma começa com %.0f s" % fdur)
	var nm: Dictionary = sim.maps[n.map_id]
	for i in range(int((fdur - 0.5) / 0.1)):
		sim._update_entity(n, nm, 0.1)
	check(n.form == "phantom", "fantasma ainda ativa antes do fim")
	for i in range(10):
		sim._update_entity(n, nm, 0.1)
	check(n.form == "" and n.form_left == 0.0 and n.stats.evasion == 0.0, "fantasma acaba sozinha e devolve os atributos")
	sim._apply_effects(n, n, gd.skills["nec_phantom"].effects, 0.0)
	sim._apply_effects(n, n, gd.skills["nec_phantom"].effects, 0.0)
	check(n.form == "" and n.form_left == 0.0, "usar de novo desfaz a fantasma")
	sim._apply_effects(n, n, gd.skills["nec_demon_form"].effects, 0.0)
	for i in range(int((fdur + 2.0) / 0.1)):
		sim._update_entity(n, nm, 0.1)
	check(n.form == "demon", "forma demoníaca não acaba sozinha")
	sim._apply_effects(n, n, gd.skills["nec_demon_form"].effects, 0.0)
	# maestria fortalece os bônus: forma (x form_mult) e buff (valores positivos), sem mexer em penalidade
	var ph: SkillDef = gd.skills["nec_phantom"]
	n.mastery.erase(ph.id)
	sim._apply_skill(n, ph, nm)
	var ev0: float = n.stats.evasion
	sim.end_form(n)
	n.mastery[ph.id] = 3
	sim._apply_skill(n, ph, nm)
	check(n.form == "phantom" and is_equal_approx(n.form_mult, 1.0 + 3 * Balance.MASTERY_BONUS_PCT), "maestria 3 na fantasma: form_mult %.2f" % n.form_mult)
	check(n.stats.evasion > ev0 + 1.0, "maestria aumenta a esquiva da fantasma (%.1f -> %.1f)" % [ev0, n.stats.evasion])
	sim.end_form(n)
	check(n.form_mult == 1.0 or n.form == "", "forma desligada")
	var ba: SkillDef = gd.skills["nec_bone_armor"]
	n.mastery[ba.id] = 5
	sim._apply_skill(n, ba, nm)
	var got := 0.0
	for b in n.buffs:
		if b.get("id") == "bone_armor":
			got = float(b.get("def_pct", 0))
	var want: float = float(ba.effects["buff"]["def_pct"]) * (1.0 + 5 * Balance.MASTERY_BONUS_PCT)
	check(is_equal_approx(got, want), "maestria 5 na Armadura de Ossos: DEF +%.1f%% (esperado %.1f)" % [got, want])
	var pen := SimEntity.scaled_bonus({"speed_pct": -10, "def_pct": 40, "duration": 6}, 1.5)
	check(pen["speed_pct"] == -10 and is_equal_approx(float(pen["def_pct"]), 60.0) and pen["duration"] == 6, "maestria não piora penalidade nem tempo")
	sim.despawn(mob)
	sim.despawn(n)

func _check_elementalist_builds(gd, sim) -> void:
	var cls: ClassDef = gd.classes["elementalist"]
	check(Array(cls.weapon_types) == ["staff"] and cls.offhand_types.is_empty(), "Elementalista só usa cajado")
	check(cls.builds.size() == 3 and not cls.builds.any(func(b): return b["main"] != ["staff"]), "Elementalista: três focos, todos de cajado (dá para misturar ramos)")
	for sid in cls.skill_ids:
		var s: SkillDef = gd.skills[sid]
		check(s.requires.is_empty() or Array(s.requires) == ["staff"], "%s usável com cajado" % sid)
		if s.kind == SkillDef.Kind.MAGICAL:
			check(not s.elements.is_empty(), "%s tem elemento" % sid)
	check(Array(gd.skills["ele_firestorm"].elements) == ["fire", "storm"] and gd.skills["ele_prism"].elements.size() == 3, "combinações têm dois ou três elementos")
	check(Array(gd.skills["ele_meteor"].elements) == ["fire"] and Array(gd.skills["ele_blizzard"].elements) == ["frost"], "ramo dá o elemento")
	for el in ["fire", "frost", "storm"]:
		var mid: String = {"fire": "fire_elemental", "frost": "frost_elemental", "storm": "storm_elemental"}[el]
		check(gd.monsters.has(mid) and gd.monsters[mid].xp == 0, "elemental %s existe e não dá XP" % el)
	# bônus por elemento: combinação usa a média
	var st := Stats.new()
	st.fire_pct = 40.0
	st.storm_pct = 0.0
	check(is_equal_approx(st.element_mult(["fire"] as Array[String]), 1.4) and is_equal_approx(st.element_mult(["fire", "storm"] as Array[String]), 1.2)
		and st.element_mult([] as Array[String]) == 1.0, "bônus de elemento: puro inteiro, combinação pela média")
	var e: SimEntity = sim.spawn_bot(cls, "Ele", "city_aldara", Vector3(-30, 0, 30), 30)
	e.brain = null
	e.buffs.append({"id": "t_el", "duration": 99, "remaining": 99, "fire_pct": 500})
	e.recompute_stats()
	check(e.stats.fire_pct == Balance.ELEMENT_CAP, "bônus de elemento tem teto")
	# save antigo com varinha + orbe: voltam para a bolsa e o cajado inicial entra
	e.equipment[ItemDef.Slot.WEAPON] = gd.items["wand_apprentice"]
	e.equipment[ItemDef.Slot.OFFHAND] = gd.items[gd.items.keys().filter(func(k): return gd.items[k].weapon_type == "orb")[0]]
	SaveSystem._fix_class_weapons(e)
	check(e.equipment[ItemDef.Slot.WEAPON].weapon_type == "staff" and e.equipment.get(ItemDef.Slot.OFFHAND) == null and e.inventory.has("wand_apprentice"),
		"save antigo do Elementalista: varinha/orbe vão para a bolsa e o cajado entra")
	# invocar: um elemental por vez; o novo substitui o anterior
	var m: Dictionary = sim.maps["city_aldara"]
	for sid in ["ele_summon_fire", "ele_summon_ice", "ele_summon_storm"]:
		sim._apply_skill(e, gd.skills[sid], m)
	var mine: Array = m["entities"].filter(func(o): return o.kind == SimEntity.Kind.SUMMON and o.owner_id == e.id and o.is_alive())
	check(mine.size() == 1 and mine[0].monster_def.id == "storm_elemental", "um elemental por vez, o último substitui (%d)" % mine.size())
	for o in mine:
		sim.despawn(o)
	sim.despawn(e)
	# conjuntos: alguns favorecem uma combinação (2º elemento com 4 peças)
	var combos := 0
	for sid in gd.sets:
		var sd: SetDef = gd.sets[sid]
		if sd.class_id != "elementalist":
			continue
		for el in ["fire_pct", "frost_pct", "storm_pct"]:
			if sd.bonuses.get(4, {}).has(el):
				combos += 1
	check(combos >= 8, "conjuntos do Elementalista que favorecem uma combinação (%d)" % combos)

func _check_assassin_builds(gd, sim) -> void:
	var cls: ClassDef = gd.classes["assassin"]
	var lam: Dictionary = cls.build_by_id("laminas")
	var due: Dictionary = cls.build_by_id("duelista")
	check(cls.builds.size() == 2 and lam["main"] == ["dagger"] and lam["off"] == ["dagger"] and due["main"] == ["sword"] and due["off"] == ["sword"],
		"Assassino: Lâminas (duas adagas) e Duelista (duas espadas)")
	for sid in ["ass_plague_blade", "ass_vanish", "ass_reflexes"]:
		check(sid in lam["skills"], "Lâminas tem %s" % sid)
	for sid in ["ass_cross_slash", "ass_guard", "ass_lunge", "ass_master"]:
		check(sid in due["skills"], "Duelista tem %s" % sid)
	var m: Dictionary = sim.maps["city_aldara"]
	var at := Vector3(30, 0, 30)
	var a: SimEntity = sim.spawn_bot(cls, "Ass", "city_aldara", at, 30)
	a.brain = null
	a.equipment[ItemDef.Slot.WEAPON] = gd.items["dagger_golem"]
	a.equipment[ItemDef.Slot.OFFHAND] = gd.items["dagger_golem"]
	a.recompute_stats()
	var mob: SimEntity = sim.spawn_monster(gd.monsters["golem"], "city_aldara", at + Vector3(0, 0, 1.5))
	mob.brain = null
	# pelas costas: alvo de costas para o atacante
	mob.facing = 0.0          # olha para +Z, o assassino está em -Z (atrás)
	check(Combat.is_behind(a, mob), "atacante atrás do alvo é pelas costas")
	mob.facing = PI
	check(not Combat.is_behind(a, mob), "de frente não é pelas costas")
	var rng := RandomNumberGenerator.new()
	var front := 0.0
	var back := 0.0
	a.buffs.append({"id": "t_bs", "duration": 99, "remaining": 99, "backstab": 40})
	a.recompute_stats()
	for i in range(200):
		mob.facing = PI
		front += float(Combat.calc_damage(a, mob, 1.0, SkillDef.Kind.PHYSICAL, rng)["amount"])
		mob.facing = 0.0
		back += float(Combat.calc_damage(a, mob, 1.0, SkillDef.Kind.PHYSICAL, rng)["amount"])
	check(back > front * 1.3, "pelas costas bate bem mais forte (%.0f x %.0f)" % [back, front])
	# veneno na lâmina
	a.buffs.append({"id": "t_pb", "duration": 99, "remaining": 99, "hit_poison": 9})
	a.recompute_stats()
	check(a.stats.hit_poison == 9.0, "buff de veneno na lâmina vira stat")
	sim._deal_damage(a, mob, 10, false, false, "physical")
	sim._deal_damage(a, mob, 10, false, false, "physical")
	var pd: Array = mob.debuffs.filter(func(d): return str(d.get("id", "")).begins_with("blade_poison"))
	check(pd.size() == 1 and mob.has_debuff("dot"), "golpe físico envenena e renova (não acumula)")
	# esquiva: com 45% de esquiva, parte dos golpes não pega
	a.buffs.append({"id": "t_ev", "duration": 99, "remaining": 99, "evasion": 300})
	a.recompute_stats()
	check(a.stats.evasion == Balance.EVASION_CAP, "esquiva tem teto")
	var dodged := 0
	sim.rng.seed = 11
	for i in range(200):
		var hp0: float = a.hp
		sim._deal_damage(mob, a, 1, false, false, "physical")
		if a.hp == hp0:
			dodged += 1
		a.hp = a.stats.max_hp
	check(dodged > 60 and dodged < 120, "esquiva perto de %d%% (%d/200)" % [int(Balance.EVASION_CAP), dodged])
	# Sumir: furtividade sem forma de lobo
	a.buffs.clear()
	a.recompute_stats()
	sim._apply_effects(a, a, gd.skills["ass_vanish"].effects, 0.0)
	check(a.stealth_left > 0.0, "Sumir deixa o Assassino furtivo")
	sim.despawn(mob)
	sim.despawn(a)

func _check_ranger_builds(gd, sim) -> void:
	var cls: ClassDef = gd.classes["ranger"]
	check(cls.builds.size() == 2 and cls.build_by_id("cacador")["main"] == ["bow"] and cls.build_by_id("atirador")["main"] == ["rifle"], "Ranger: Caçador (arco) e Atirador (mosquete)")
	check(not cls.builds.any(func(b): return not b["off"].is_empty()), "Ranger sem build de duas armas (é do Assassino)")
	for sid in ["ran_twin_cut", "ran_hunter_dash", "ran_whirl", "ran_wild", "ran_cross_cut", "ran_maul"]:
		check(not gd.skills.has(sid), "skill de corpo a corpo removida: %s" % sid)
	check("rifle" in ItemDef.TWO_HANDED and gd.items.has("rifle_t0"), "mosquete é arma de duas mãos com itens comuns")
	var bow: SkillDef = gd.basic_skill_for_class(cls, "bow")
	var rif: SkillDef = gd.basic_skill_for_class(cls, "rifle")
	check(rif.cooldown > bow.cooldown * 1.5 and rif.power > bow.power * 1.5 and rif.range > bow.range, "mosquete: tiro mais lento, mais forte e mais longe que o arco")
	check(bow.range >= 12.0 and gd.skills["ran_power_shot"].range >= 15.0, "arqueiro atira de longe (básico %.1f m, Tiro Potente %.1f m)" % [bow.range, gd.skills["ran_power_shot"].range])
	var m: Dictionary = sim.maps["city_aldara"]
	var at := Vector3(0, 0, 6)
	# ---- armadilhas ----
	var gun: SimEntity = sim.spawn_bot(cls, "Gun", "city_aldara", at, 30)
	gun.brain = null
	gun.equipment[ItemDef.Slot.WEAPON] = gd.items["rifle_t3"]
	gun.recompute_stats()
	check(gun.stats.is_ranged_weapon, "mosquete é arma de distância")
	var trap: SkillDef = gd.skills["ran_trap"]
	var spot := at + Vector3(4, 0, 0)
	sim._apply_skill(gun, trap, m)
	gun.skill_aim = spot
	for i in range(4):
		gun.skill_aim = spot + Vector3(0, 0, i * 2.0)
		sim._apply_skill(gun, trap, m)
	var mine: Array = m["traps"].filter(func(t): return t["owner"] == gun.id)
	check(mine.size() == Balance.TRAP_MAX, "no máximo %d armadilhas por ranger (%d)" % [Balance.TRAP_MAX, mine.size()])
	var t0: Dictionary = mine[0]
	var mob: SimEntity = sim.spawn_monster(gd.monsters["golem"], "city_aldara", t0["pos"])
	mob.brain = null
	var hp0: float = mob.hp
	sim._update_traps(m)
	check(m["traps"].has(t0) and mob.hp == hp0, "armadilha só dispara depois de armar")
	sim.time += Balance.TRAP_ARM_TIME + 0.1
	sim.rng.seed = 7          # sem esquiva aleatória no teste
	sim._update_traps(m)
	check(not m["traps"].has(t0) and mob.hp < hp0 and mob.has_debuff("root"), "pisou: dano, prende e a armadilha some")
	sim.despawn(mob)
	sim.time += 40.0
	sim._update_traps(m)
	check(m["traps"].filter(func(t): return t["owner"] == gun.id).is_empty(), "armadilha some com o tempo")
	sim.despawn(gun)
	# ---- companheiro ----
	var hunter: SimEntity = sim.spawn_bot(cls, "Hunt", "city_aldara", at, 30)
	hunter.brain = null
	hunter.equipment[ItemDef.Slot.WEAPON] = gd.items["bow_dragon"]
	hunter.recompute_stats()
	sim._apply_skill(hunter, gd.skills["ran_companion"], m)
	var pet: SimEntity = sim.pet_of(hunter)
	check(pet != null and pet.summon_expires == INF, "companheiro é permanente")
	check(pet != null and is_equal_approx(pet.stats.max_hp, hunter.stats.max_hp * Balance.PET_HP_SHARE), "vida do companheiro vem do dono")
	hunter.skills[0] = gd.skills["ran_companion"]
	hunter.learned["ran_companion"] = true
	hunter.mp = hunter.stats.max_mp
	hunter.cooldowns.clear()
	check(not sim.try_cast(hunter, 0, at, m), "com o companheiro vivo, chamar de novo não faz nada")
	var prey: SimEntity = sim.spawn_monster(gd.monsters["golem"], "city_aldara", at + Vector3(8, 0, 0))
	prey.brain = null
	var hp1: float = prey.hp
	hunter.skill_aim = prey.position
	sim._apply_skill(hunter, gd.skills["ran_sic"], m)
	check(prey.hp < hp1 and pet.position.distance_to(prey.position) < 2.5 and pet.aggro_target == prey.id, "Ataque da Fera: o lince salta e morde o alvo")
	sim._apply_skill(hunter, gd.skills["ran_pack"], m)
	check(pet.buffs.any(func(b): return b.get("id") == "pack") and hunter.buffs.any(func(b): return b.get("id") == "pack"), "Instinto da Matilha: você e o companheiro")
	hunter.tree_bonus = {"pet_pct": 50.0}
	hunter.recompute_stats()
	sim.despawn(pet)
	sim._apply_skill(hunter, gd.skills["ran_companion"], m)
	var pet2: SimEntity = sim.pet_of(hunter)
	check(pet2 != null and pet2.stats.max_hp > hunter.stats.max_hp * Balance.PET_HP_SHARE * 1.4, "bônus de companheiro aumenta a vida dele")
	for e in [prey, pet2, hunter]:
		sim.despawn(e)
	# ---- save com skill que não existe mais: pontos voltam ----
	var old: SimEntity = sim.spawn_character(SimEntity.Kind.BOT, cls, "Old", "city_aldara", at, 20)
	SaveSystem.apply_to(old, {"level": 20, "mastery_points": 0, "tree": ["ranger_start", "ranger_s_ran_power_shot", "ranger_s_ran_twin_cut"],
		"learned": ["ran_power_shot", "ran_twin_cut"], "class": "ranger"})
	check(not old.tree.has("ranger_s_ran_twin_cut") and old.mastery_points == SaveSystem.points_for_level(old.level), "save antigo com skill removida: árvore refeita, %d pontos devolvidos" % old.mastery_points)
	sim.despawn(old)

## Druida: Xamã (cajado, invocações e bênçãos), Lobo (duas maças, forma de lobo, furtividade) e Urso (malho, forma de urso).
func _check_druid_builds(gd, sim) -> void:
	var cls: ClassDef = gd.classes["druid"]
	check(cls.build_by_id("xama")["main"] == ["staff"] and cls.build_by_id("xama")["off"].is_empty(), "Xamã: cajado de duas mãos")
	check(cls.build_by_id("fera")["main"] == ["mace"] and cls.build_by_id("fera")["off"] == ["mace"], "Lobo: duas maças")
	check(cls.build_by_id("guardiao_verde")["main"] == ["mace2h"], "Urso: malho de duas mãos")
	for sid in ["dru_spirit_wolves", "dru_treant", "dru_grove", "dru_wolf_form", "dru_prowl"]:
		check(gd.skills.has(sid), "skill nova %s" % sid)
	for sid in ["dru_wolf_form", "dru_bear_form"]:
		check(gd.skills[sid].unlock_level <= 3, "%s cedo (a build é a forma)" % sid)
	for mid in ["spirit_wolf", "treant"]:
		check(gd.monsters.has(mid) and gd.monsters[mid].xp == 0, "invocação %s" % mid)
	var m: Dictionary = sim.maps["city_aldara"]
	var dt := 1.0 / 60.0
	var at := Vector3(0, 0, 6)
	# ---- urso ----
	var bear: SimEntity = sim.spawn_bot(cls, "Bear", "city_aldara", at, 30)
	bear.brain = null
	bear.equipment[ItemDef.Slot.WEAPON] = gd.items["mace2h_t3"]
	bear.equipment.erase(ItemDef.Slot.OFFHAND)
	bear.recompute_stats()
	var def0: float = bear.stats.pdef
	var hp0: float = bear.stats.max_hp
	sim._apply_effects(bear, bear, {"form": "bear"}, 1.0)
	check(bear.form == "bear" and bear.stats.pdef > def0 * 1.3 and bear.stats.max_hp > hp0 * 1.2, "forma de urso: +DEF e +HP")
	var maul: SkillDef = sim.resolve_skill(bear, gd.skills["dru_maul"])
	check(maul.name == "Patada do Urso" and maul.radius > gd.skills["dru_maul"].radius * 1.2 and maul.id == "dru_maul", "em urso, Esmagar vira Patada do Urso (mesma recarga)")
	check(gd.skills["dru_maul"].name == "Esmagar", "a skill original não muda")
	sim._apply_effects(bear, bear, {"form": "bear"}, 1.0)
	check(bear.form == "" and sim.resolve_skill(bear, gd.skills["dru_maul"]).name == "Esmagar", "lançar de novo volta à forma humana")
	sim._apply_effects(bear, bear, {"form": "bear"}, 1.0)
	bear.equipment[ItemDef.Slot.WEAPON] = gd.items["staff_oak"]
	bear.recompute_stats()
	check(bear.form == "", "trocar para arma que a forma não aceita desfaz a forma")
	# bot transformado não desfaz a forma sozinho
	bear.equipment[ItemDef.Slot.WEAPON] = gd.items["mace2h_t3"]
	bear.recompute_stats()
	bear.skills[0] = gd.skills["dru_bear_form"]
	bear.learned["dru_bear_form"] = true
	bear.form = "bear"
	bear.recompute_stats()
	bear.mp = bear.stats.max_mp
	bear.cooldowns.clear()
	check(not sim.try_cast(bear, 0, at, m) and bear.form == "bear", "bot em forma de urso não desfaz a forma")
	# ---- lobo e furtividade ----
	var wolf: SimEntity = sim.spawn_bot(cls, "Wolf", "city_aldara", at + Vector3(4, 0, 0), 30)
	wolf.brain = null
	wolf.equipment[ItemDef.Slot.WEAPON] = gd.items["mace_t3"]
	wolf.equipment[ItemDef.Slot.OFFHAND] = gd.items["mace_t3"]
	wolf.recompute_stats()
	var as0: float = wolf.stats.attack_speed
	wolf.skills[1] = gd.skills["dru_prowl"]
	wolf.learned["dru_prowl"] = true
	wolf.mp = wolf.stats.max_mp
	check(not sim.try_cast(wolf, 1, at, m) and wolf.stealth_left == 0.0, "Espreitar só na forma de lobo")
	sim._apply_effects(wolf, wolf, {"form": "wolf"}, 1.0)
	check(wolf.form == "wolf" and wolf.stats.attack_speed >= as0 + 25.0, "forma de lobo: +velocidade de ataque")
	check(sim.resolve_skill(wolf, gd.skills["dru_claw"]).startup < gd.skills["dru_claw"].startup, "em lobo, Garras vira Mordida (mais rápida)")
	var mob: SimEntity = sim.spawn_monster(gd.monsters["wolf"], "city_aldara", wolf.position + Vector3(2, 0, 0))
	mob.aggro_target = wolf.id
	sim._apply_effects(wolf, wolf, {"stealth": 8.0}, 1.0)
	check(wolf.stealth_left > 0.0 and mob.aggro_target != wolf.id, "furtivo: o monstro perde o alvo")
	check(Combat.nearest_hostile(mob, m["entities"], 20.0) != wolf, "furtivo: monstro não acha o druida")
	sim._start_skill(wolf, gd.skills["dru_claw"], -1, mob.position)
	check(wolf.stealth_left == 0.0 and wolf.ambush, "golpe quebra a furtividade e vira emboscada")
	var hp_m: float = mob.hp
	wolf.ambush = true
	var claw: SkillDef = gd.skills["dru_claw"]
	sim._apply_skill(wolf, claw, m)
	check(not wolf.ambush and mob.hp < hp_m, "emboscada é gasta no golpe")
	sim.despawn(mob)
	# ---- Xamã: invoca ----
	var sh: SimEntity = sim.spawn_bot(cls, "Shaman", "city_aldara", at + Vector3(-4, 0, 0), 30)
	sh.brain = null
	sh.equipment[ItemDef.Slot.WEAPON] = gd.items["staff_oak"]
	sh.equipment.erase(ItemDef.Slot.OFFHAND)
	sh.recompute_stats()
	sim._apply_skill(sh, gd.skills["dru_spirit_wolves"], m)
	var pets: Array = m["entities"].filter(func(o): return o.kind == SimEntity.Kind.SUMMON and o.owner_id == sh.id)
	check(pets.size() == 2, "Lobos Espirituais invoca 2 lobos (%d)" % pets.size())
	for e in pets + [sh, wolf, bear]:
		sim.despawn(e)
	# formas: modelo do bicho com a armadura de animal de cada conjunto do Lobo/Urso
	for pair in [["wolf", "fera"], ["bear", "guardiao_verde"]]:
		var fm := FormModel.create(pair[0])
		check(fm != null and fm.anim != null and fm.anim.has_animation("attack") and fm.anim.has_animation("run"), "form_%s.glb com animações" % pair[0])
		if fm == null:
			continue
		for set_id in gd.sets:
			var fsd: SetDef = gd.sets[set_id]
			if fsd.class_id == "druid" and set_id.begins_with("set_druid_%s_" % pair[1]):
				var style: String = GearCatalog.SET_VISUALS[set_id]["style"]
				check(fm.pieces_of(style).size() >= 4, "%s: armadura de animal (%d peças)" % [style, fm.pieces_of(style).size()])
		var eq := {}
		for iid in gd.legendary_pool(cls, 30, pair[1]):
			eq[gd.items[iid].slot] = gd.items[iid]
		fm.apply_equipment(eq)
		var shown: Array = fm._pieces.filter(func(mi): return mi.visible)
		check(not shown.is_empty() and shown.all(func(mi): return String(mi.name).contains("_%s30_" % ("dru_w" if pair[0] == "wolf" else "dru_b").substr(4))), "%s: só a armadura do conjunto vestido aparece (%d)" % [pair[0], shown.size()])
		fm.free()

## Bispo: Sacerdote = maça + escudo (cura e bênçãos mais longas); Iluminado = cetro de duas mãos (luz mágica + Radiância).
func _check_bishop_builds(gd, sim) -> void:
	var cls: ClassDef = gd.classes["bishop"]
	var sac: Dictionary = cls.build_by_id("sacerdote")
	var ilu: Dictionary = cls.build_by_id("inquisidor")
	check(sac["main"] == ["mace"] and sac["off"] == ["shield"], "Sacerdote: maça e escudo")
	check(ilu["main"] == ["scepter"] and ilu["off"].is_empty() and ilu["armor"] == "cloth", "Iluminado: cetro de duas mãos e túnicas")
	check("scepter" in ItemDef.TWO_HANDED and gd.items["scepter_t0"].is_two_handed(), "cetro é arma de duas mãos")
	var st := Stats.compute(cls, 10, {ItemDef.Slot.WEAPON: gd.items["scepter_t0"]}, [])
	check(st.is_magic_weapon, "cetro é arma mágica")
	check(gd.basic_skill_for_class(cls, "scepter").target == SkillDef.Target.DIRECTION, "cetro: ataque básico de luz à distância")
	for sid in ["bis_hammer", "bis_condemn", "bis_wrath"]:
		check(Array(gd.skills[sid].requires) == ["scepter"], "%s exige o cetro" % sid)
	check(gd.skills["bis_hammer"].kind == SkillDef.Kind.MAGICAL, "Martelo de Luz é dano mágico")
	var se: SetDef = gd.sets["set_bishop_sacerdote_30"]
	var si: SetDef = gd.sets["set_bishop_inquisidor_30"]
	check(float(se.bonuses[3].get("buff_pct", 0)) > 0.0 and float(si.bonuses[3].get("radiance", 0)) > 0.0, "conjuntos: bênçãos longas (Sacerdote) e Radiância (Iluminado)")
	var sac_shield := false
	for pid in se.pieces:
		sac_shield = sac_shield or gd.items[pid].weapon_type == "shield"
	check(sac_shield, "conjunto do Sacerdote tem escudo")
	# bênçãos mais longas
	var m: Dictionary = sim.maps["city_aldara"]
	var b: SimEntity = sim.spawn_bot(cls, "Buff", "city_aldara", Vector3(0, 0, 6), 30)
	b.brain = null
	var ally: SimEntity = sim.spawn_bot(gd.classes["paladin"], "Ally", "city_aldara", Vector3(2, 0, 6), 30)
	ally.brain = null
	sim.party_invite(b, ally)
	sim.party_accept(ally)
	b.tree_bonus = {"buff_pct": 50.0}
	b.recompute_stats()
	sim._apply_effects(b, ally, {"buff": {"id": "ward", "duration": 10, "def_pct": 25}}, 1.0)
	var w: Array = ally.buffs.filter(func(x): return x.get("id") == "ward")
	check(w.size() == 1 and is_equal_approx(float(w[0]["remaining"]), 15.0), "bênção dura 50%% mais no aliado (%.1f s)" % (float(w[0]["remaining"]) if w.size() > 0 else 0.0))
	# Radiância: cura o aliado mais ferido, só com dano mágico direto
	b.tree_bonus = {"radiance": 20.0}
	b.recompute_stats()
	var foe: SimEntity = sim.spawn_monster(gd.monsters["golem"], "city_aldara", Vector3(0, 0, 9))
	foe.brain = null
	ally.hp = ally.stats.max_hp * 0.3
	b.hp = b.stats.max_hp * 0.9
	var a0: float = ally.hp
	var b0: float = b.hp
	sim._deal_damage(b, foe, 100, false, false, "magical")
	check(ally.hp > a0 and b.hp == b0, "Radiância cura o aliado mais ferido (+%.0f), não quem está melhor" % (ally.hp - a0))
	a0 = ally.hp
	sim._deal_damage(b, foe, 100, false, false, "physical")
	sim._deal_damage(b, foe, 100, false, false, "dot")
	check(ally.hp == a0, "Radiância só com dano mágico direto")
	ally.position = Vector3(40, 0, 6)
	sim._deal_damage(b, foe, 100, false, false, "magical")
	check(ally.hp == a0, "Radiância não alcança aliado longe")
	b.tree_bonus = {"radiance": 900.0, "buff_pct": 900.0}
	b.recompute_stats()
	check(b.stats.radiance == Balance.RADIANCE_CAP and b.stats.buff_duration == Balance.BUFF_DURATION_CAP, "Radiância e duração de bênçãos têm teto")
	for e in [foe, ally, b]:
		sim.despawn(e)

## Berserker: só machados; Machados Gêmeos = velocidade de ataque + roubo de vida, Executor = vida/defesa (tanque de apoio).
func _check_berserker_builds(gd, sim) -> void:
	var cls: ClassDef = gd.classes["berserker"]
	for b in cls.builds:
		for w in b["main"] + b["off"]:
			check(w in ["axe", "axe2h"], "berserker %s usa só machados (%s)" % [b["id"], w])
	var twin: Dictionary = cls.build_by_id("carniceiro")
	var exe: Dictionary = cls.build_by_id("executor")
	check(twin["main"] == ["axe"] and twin["off"] == ["axe"] and exe["main"] == ["axe2h"], "Gêmeos = 2 machados, Executor = machado de 2 mãos")
	# árvore: passivos da build
	var nodes: Dictionary = gd.trees["berserker"]["nodes"]
	var kinds := {}
	for nid in nodes:
		var n: Dictionary = nodes[nid]
		if n["kind"] == "stat":
			for k in n["stats"]:
				kinds["%s:%s" % [n["branch"], k]] = true
	check(kinds.has("carniceiro:aspd_pct") and kinds.has("carniceiro:lifesteal"), "árvore dos Gêmeos dá velocidade de ataque e roubo de vida")
	check(kinds.has("executor:hp_pct") and kinds.has("executor:def_pct"), "árvore do Executor dá vida e defesa")
	# conjunto
	var sg: SetDef = gd.sets["set_berserker_carniceiro_30"]
	var se: SetDef = gd.sets["set_berserker_executor_30"]
	check(float(sg.bonuses[3].get("lifesteal", 0)) > 0.0 and sg.bonuses[5].has("aspd_pct"), "conjunto dos Gêmeos: roubo de vida (3) e velocidade de ataque (5)")
	check(float(se.bonuses[3].get("hp_pct", 0)) > 0.0 and float(se.bonuses[3].get("def_pct", 0)) > 0.0, "conjunto do Executor: vida e defesa (3)")
	# mecânica
	var m: Dictionary = sim.maps["city_aldara"]
	var e: SimEntity = sim.spawn_bot(cls, "LS", "city_aldara", Vector3(0, 0, 6), 30)
	e.brain = null
	var foe: SimEntity = sim.spawn_monster(gd.monsters["golem"], "city_aldara", Vector3(0, 0, 8))
	foe.brain = null
	e.tree_bonus = {"lifesteal": 10.0, "aspd_pct": 50.0}
	e.recompute_stats()
	check(is_equal_approx(e.stats.lifesteal, 10.0) and is_equal_approx(e.stats.attack_speed, 50.0), "stats somam roubo de vida e velocidade de ataque")
	e.hp = e.stats.max_hp * 0.5
	var hp0: float = e.hp
	sim._deal_damage(e, foe, 100, false, false, "physical")
	check(is_equal_approx(e.hp - hp0, 10.0), "roubo de vida cura 10%% do dano (%.1f)" % (e.hp - hp0))
	hp0 = e.hp
	sim._deal_damage(e, foe, 100, false, false, "dot")
	check(e.hp == hp0, "dano no tempo não rouba vida")
	check(is_equal_approx(e.stats.basic_cooldown(0.9), 0.6), "50%% de velocidade de ataque: recarga do básico 0,9 -> 0,6")
	e.tree_bonus = {"lifesteal": 500.0, "aspd_pct": 500.0}
	e.recompute_stats()
	check(e.stats.lifesteal == Balance.LIFESTEAL_CAP and e.stats.attack_speed == Balance.ATTACK_SPEED_CAP, "roubo de vida e velocidade de ataque têm teto")
	sim.despawn(foe)
	# machado de duas mãos: golpe básico mais largo, mais longe e em mais alvos; um machado só continua normal
	var b2: SkillDef = gd.basic_skill_for_class(cls, "axe2h")
	var b1: SkillDef = gd.basic_skill_for_class(cls, "axe")
	check(b2.radius > b1.radius * 1.3 and b2.cone_angle_deg > b1.cone_angle_deg and b2.max_targets > b1.max_targets, "machado de duas mãos: golpe básico maior (%.1f m, %d°, %d alvos)" % [b2.radius, int(b2.cone_angle_deg), b2.max_targets])
	check(b2.radius >= 3.0 and b2.cone_angle_deg >= 150.0, "machado de duas mãos: botão esquerdo pega 3 m em 150°")
	e.equipment[ItemDef.Slot.WEAPON] = gd.items["axe_old"]
	e.equipment.erase(ItemDef.Slot.OFFHAND)
	e.recompute_stats()
	check(e.basic_skill == b2, "berserker de machado de duas mãos usa o golpe largo")
	var ring: Array = []
	for i in range(5):
		var a := deg_to_rad(-60.0 + i * 30.0)
		var mob: SimEntity = sim.spawn_monster(gd.monsters["golem"], "city_aldara", e.position + Vector3(sin(a), 0, cos(a)) * 2.7)
		mob.brain = null
		ring.append(mob)
	e.face_towards(e.position + Vector3(0, 0, 1))
	var hp_before: Array = ring.map(func(o): return o.hp)
	sim._start_skill(e, b2, -1, e.position + Vector3(0, 0, 3))
	sim._apply_skill(e, b2, m)
	var hit := 0
	for i in range(ring.size()):
		if ring[i].hp < hp_before[i]:
			hit += 1
	check(hit == Balance.BIG_SWING_MAX_TARGETS, "golpe largo acerta %d alvos a 2,7 m num arco de 120° (%d)" % [Balance.BIG_SWING_MAX_TARGETS, hit])
	# todas as armas corpo a corpo de duas mãos (Cruzado, Inquisidor), e não as de uma mão nem arco/cajado
	var pal: ClassDef = gd.classes["paladin"]
	var bis: ClassDef = gd.classes["bishop"]
	for pair in [[pal, "sword2h"], [pal, "mace2h"], [bis, "mace2h"]]:
		var big: SkillDef = gd.basic_skill_for_class(pair[0], pair[1])
		check(big.cone_angle_deg == Balance.BIG_SWING_ARC_DEG and big.max_targets == Balance.BIG_SWING_MAX_TARGETS, "%s com %s: golpe largo" % [pair[0].id, pair[1]])
	check(gd.basic_skill_for_class(pal, "sword").cone_angle_deg < Balance.BIG_SWING_ARC_DEG, "espada de uma mão: golpe normal")
	check(gd.basic_skill_for_class(bis, "staff").target == SkillDef.Target.DIRECTION, "cajado continua à distância")
	check(gd.basic_skill_for_class(gd.classes["ranger"], "bow").target == SkillDef.Target.DIRECTION, "arco continua à distância")
	for mob in ring:
		sim.despawn(mob)
	sim.despawn(e)

## Encadear skills (estilo Diablo): a segunda skill, apertada logo no começo da primeira, sai no impacto da primeira,
## sem esperar a recuperação; a primeira sempre acerta. Roda todos os pares de skills em sequência de cada classe.
func _check_skill_chain(gd, sim) -> void:
	var m: Dictionary = sim.maps["city_aldara"]
	var dt := 1.0 / 60.0
	var at := Vector3(0, 0, 6)
	var pairs := 0
	var late: Array = []
	var lost: Array = []
	var saved := 0.0
	for cid in gd.classes:
		var e: SimEntity = sim.spawn_bot(gd.classes[cid], "Chain", "city_aldara", at, 30)
		e.brain = null
		var slots: Array = []
		for i in range(e.skills.size()):
			if e.skills[i] != null:
				slots.append(i)
		for k in range(slots.size() - 1):
			var sa: int = slots[k]
			var sb: int = slots[k + 1]
			sim._end_skill(e)
			e.position = at
			e.cooldowns.clear()
			e.mp = e.stats.max_mp
			e.buffered_cmd = null
			var first := InputCommand.new()
			first.aim = at + Vector3(0, 0, 4)
			first.skill_slot = sa
			sim._apply_command(e, first, m, dt)
			var a_skill: SkillDef = e.current_skill
			if a_skill == null:
				continue
			pairs += 1
			var second := InputCommand.new()
			second.aim = first.aim
			second.skill_slot = sb
			var a_hit := -1.0
			var b_start := -1.0
			var b_hit := -1.0
			var b_skill: SkillDef = null
			var t := 0.0
			for tick in range(120):
				var c := second if tick == 0 else InputCommand.new()
				if tick > 0:
					c.aim = first.aim
				sim._apply_command(e, c, m, dt)
				if b_skill == null and e.current_skill != null and e.current_skill != a_skill:
					b_skill = e.current_skill
					b_start = t
				if a_hit < 0.0 and (e.current_skill == a_skill and e.skill_applied or b_skill != null):
					a_hit = t
				sim._update_entity(e, m, dt)
				t += dt
				if a_hit < 0.0 and e.current_skill == a_skill and e.skill_applied:
					a_hit = t
				if b_skill != null and e.current_skill == b_skill and e.skill_applied:
					b_hit = t
					break
			if b_skill == null or b_hit < 0.0 or a_hit < 0.0 or a_hit > b_start:
				lost.append("%s>%s" % [a_skill.id, e.skills[sb].id])
				continue
			if b_start > a_skill.startup + 0.1:          # absoluto: não depende da constante que está sendo testada
				late.append("%s>%s %.2fs" % [a_skill.id, b_skill.id, b_start])
			saved += (a_skill.startup + a_skill.active + a_skill.recovery) - b_start
		sim.despawn(e)
	check(pairs >= 30, "pares de skills testados no encadeamento (%d)" % pairs)
	check(lost.is_empty(), "skill apertada no começo de outra nunca se perde e a primeira sempre acerta (%d: %s)" % [lost.size(), str(lost.slice(0, 4))])
	check(late.is_empty(), "a segunda skill sai logo depois do impacto da primeira (%d atrasadas: %s)" % [late.size(), str(late.slice(0, 4))])
	check(pairs > 0 and saved / pairs > 0.26, "encadear economiza tempo de animação (%.2f s por par)" % (saved / maxf(pairs, 1)))
	# segurar o ataque durante uma skill: o básico sai depois do impacto, sem esperar a recuperação
	var h: SimEntity = sim.spawn_bot(gd.classes["berserker"], "Held", "city_aldara", at, 30)
	h.brain = null
	var slot := 0
	while h.skills[slot] == null:
		slot += 1
	var c1 := InputCommand.new()
	c1.aim = at + Vector3(0, 0, 4)
	c1.skill_slot = slot
	sim._apply_command(h, c1, m, dt)
	var sk: SkillDef = h.current_skill
	var basic_at := -1.0
	var t2 := 0.0
	for tick in range(90):
		var held := InputCommand.new()
		held.aim = c1.aim
		held.attack = true
		sim._apply_command(h, held, m, dt)
		if h.current_skill == h.basic_skill:
			basic_at = t2
			break
		sim._update_entity(h, m, dt)
		t2 += dt
	check(sk != null and basic_at >= sk.startup and basic_at < sk.startup + sk.active + sk.recovery, "ataque segurado sai no impacto da skill, antes do fim da animação (%.2f s)" % basic_at)
	# básico atrás de básico não fica mais rápido
	sim._end_skill(h)
	h.basic_cd = 0.0
	var starts := 0
	for tick in range(120):
		var held2 := InputCommand.new()
		held2.aim = c1.aim
		held2.attack = true
		var before: float = h.state_time if h.current_skill == h.basic_skill else 99.0
		sim._apply_command(h, held2, m, dt)
		if h.current_skill == h.basic_skill and h.state_time < before:
			starts += 1
		sim._update_entity(h, m, dt)
	var b0: SkillDef = h.basic_skill
	var period: float = maxf(b0.cooldown, b0.startup + b0.active + minf(b0.cancel_after, Balance.CANCEL_AFTER_MAX))
	check(starts <= int(2.0 / period) + 1, "ataque básico em sequência mantém o ritmo (%d em 2 s)" % starts)
	sim.despawn(h)
	# monstro não encadeia
	var mob: SimEntity = sim.spawn_monster(gd.monsters["bone_captain"], "city_aldara", at + Vector3(20, 0, 0))
	sim._start_skill(mob, gd.skills["mob_whirl"], 0, at)
	mob.skill_applied = true
	mob.state_time = gd.skills["mob_whirl"].startup + 0.06
	var mc := InputCommand.new()
	mc.skill_slot = 1
	check(not sim._can_chain(mob, mc), "monstro não encadeia skills")
	sim.despawn(mob)

## Toda skill de classe e toda classe têm ícone; ícones de uma classe não se repetem.
func _check_icons(gd) -> void:
	for cid in gd.classes:
		check(ResourceLoader.exists("res://assets/icons/class_%s.png" % cid), "ícone da classe %s" % cid)
	var by_class := {}
	for sid in gd.skills:
		var s: SkillDef = gd.skills[sid]
		if s.class_id == "":
			continue
		var path := "res://assets/icons/skill_%s.png" % sid
		check(ResourceLoader.exists(path), "ícone da skill %s (rode tools/icons/make_icons.tscn)" % sid)
		if not ResourceLoader.exists(path):
			continue
		var h: int = hash((load(path) as Texture2D).get_image().get_data())
		var seen: Dictionary = by_class.get_or_add(s.class_id, {})
		check(not seen.has(h), "%s tem o mesmo ícone de %s" % [sid, seen.get(h, "")])
		seen[h] = sid

## Toda classe: cabeça, peito, calça, luvas, botas, capa, amuleto e dois anéis.
func _check_equipment_slots(gd, sim, save) -> void:
	var worn := [ItemDef.Slot.HEAD, ItemDef.Slot.BODY, ItemDef.Slot.LEGS, ItemDef.Slot.GLOVES, ItemDef.Slot.BOOTS, ItemDef.Slot.CAPE]
	for tier in range(Balance.COMMON_TIER_LEVELS.size()):
		var pieces: Array = GearCatalog.wearables(tier)
		check(pieces.size() == 12, "tier %d: 3 calças, 3 capas, 3 amuletos, 3 anéis" % tier)
		for it in pieces:
			check(gd.items.has(it.id), "item %s no catálogo" % it.id)
			check(it.class_restriction.is_empty(), "%s serve para todas as classes" % it.id)
	for cid in gd.classes:
		var e = sim.spawn_character(SimEntity.Kind.BOT, gd.classes[cid], "Novo", "city_aldara", Vector3(0, 0, 6), 1)
		for slot in worn:
			check(e.equipment.get(slot) != null, "%s começa com %s" % [cid, UiKit.slot_name(slot)])
		e.level = 30
		for iid in ["legs_plate_t3", "legs_cloth_t3", "cape_sabio_t3", "amulet_guerreiro_t3", "ring_cacador_t3"]:
			check(sim.equip_error(e, gd.items[iid]) == "", "%s pode usar %s" % [cid, iid])
		for iid in ["ring_guerreiro_t0", "ring_sabio_t0", "ring_cacador_t0", "ring_cacador_t0"]:
			e.add_item(iid, 1)
		var total: int = e.stats.max_hp
		check(sim.equip(e, "ring_guerreiro_t0") and e.equipment[ItemDef.Slot.RING].id == "ring_guerreiro_t0", "%s: primeiro anel" % cid)
		check(sim.equip(e, "ring_sabio_t0") and e.equipment[ItemDef.Slot.RING2].id == "ring_sabio_t0", "%s: segundo anel vai no outro dedo" % cid)
		check(e.equipment[ItemDef.Slot.RING].id == "ring_guerreiro_t0", "%s: primeiro anel continua" % cid)
		check(sim.equip(e, "ring_cacador_t0") and e.equipment[ItemDef.Slot.RING].id == "ring_cacador_t0" and e.has_item("ring_guerreiro_t0"), "%s: terceiro troca o primeiro e devolve" % cid)
		sim.unequip(e, ItemDef.Slot.RING)
		check(sim.equip(e, "ring_cacador_t0") and e.equipment[ItemDef.Slot.RING].id == "ring_cacador_t0", "%s: anel igual nos dois não duplica slot" % cid)
		check(e.stats.max_hp >= total, "%s: anéis não tiram vida" % cid)
		sim.despawn(e)
	check(save.saved_slot(ItemDef.Slot.ACCESSORY, gd.items["ring_gel"]) == ItemDef.Slot.RING, "save antigo: acessório anel vira anel")
	check(save.saved_slot(ItemDef.Slot.ACCESSORY, gd.items["amulet_silk"]) == ItemDef.Slot.AMULET, "save antigo: acessório amuleto vira amuleto")
	check(save.saved_slot(ItemDef.Slot.RING2, gd.items["ring_gel"]) == ItemDef.Slot.RING2, "save novo mantém o segundo anel")
	var bot = sim.spawn_bot(gd.classes["elementalist"], "Joias", "city_aldara", Vector3(0, 0, 6), 25)
	check(bot.equipment.get(ItemDef.Slot.RING) != null and bot.equipment.get(ItemDef.Slot.RING2) != null, "bot alto usa dois anéis")
	check(bot.equipment.get(ItemDef.Slot.LEGS) != null and bot.equipment.get(ItemDef.Slot.CAPE) != null, "bot alto usa calça e capa")
	check(bot.equipment[ItemDef.Slot.RING].attr("INT") > 0, "bot escolhe joia do atributo da build")
	sim.despawn(bot)
	for tier in range(2):
		for it in GearCatalog.wearables(tier):
			var jewel: bool = it.slot in [ItemDef.Slot.CAPE, ItemDef.Slot.AMULET, ItemDef.Slot.RING]
			check(GearCatalog.shop_ids().has(it.id) != jewel, "%s: %s" % [it.id, "feito na forja/alquimista" if jewel else "mercador vende"])

## Marcador sobre o NPC: "!" com quest nova, "?" para entregar ou conversar, nada sem pendência.
func _check_quest_marks(gd, sim) -> void:
	var p = sim.spawn_bot(gd.classes["paladin"], "Marcas", "city_aldara", Vector3(0, 0, 6), 1)
	p.quests_active.clear()
	p.quests_completed.clear()
	check(QuestSystem.npc_marker(p, "elder") == "!", "ancião mostra ! com quest nova")
	check(QuestSystem.npc_marker(p, "captain") == QuestSystem.LOCKED, "capitã com quest ainda bloqueada mostra ! cinza")
	check(QuestSystem.npc_marker(p, "merchant") == "", "NPC sem quest nenhuma não tem marcador")
	QuestSystem.accept(p, gd.quests["q01_welcome"])
	check(QuestSystem.npc_marker(p, "elder") == QuestSystem.LOCKED, "! dourado some ao aceitar (fica o cinza das próximas)")
	check(QuestSystem.npc_marker(p, "captain") == "?", "alvo da conversa mostra ?")
	QuestSystem.on_talk(p, "captain")
	check(QuestSystem.npc_marker(p, "captain") == "?", "quem recebe mostra ? com a quest pronta")
	QuestSystem.complete(p, gd.quests["q01_welcome"], sim)
	check(QuestSystem.npc_marker(p, "elder") == QuestSystem.LOCKED, "? some ao entregar")
	check(QuestSystem.npc_marker(p, "captain") == "!", "próxima quest da cadeia mostra !")
	var q: QuestDef = gd.quests["s_wolf_den"]
	check(QuestSystem.npc_marker(p, q.giver_npc) == QuestSystem.LOCKED, "nível baixo mostra ! cinza")
	p.level = q.level_req
	check(QuestSystem.npc_marker(p, q.giver_npc) == "!", "! dourado aparece ao atingir o nível")
	p.quests_completed.append(q.id)
	check(QuestSystem.npc_marker(p, q.giver_npc) == "", "sem quests restantes não há marcador")
	sim.despawn(p)

## Cristal de retorno no Posto dos Caçadores: vincular muda o G e o renascer; dentro do Posto dá para trocar skills;
## o save guarda o vínculo e save antigo volta para a cidade.
func _check_bind_crystal(gd, sim, save) -> void:
	var fid := "field_forest"
	if not sim.maps.has(fid):
		sim.load_map(gd.maps[fid])
	var fdef: MapDef = gd.maps[fid]
	for mid in MapsCatalog.CRYSTALS:
		var cp: Array = MapsCatalog.CRYSTALS[mid]
		var crystal_at := Vector3(float(cp[0]), 0, float(cp[1]))
		var found: bool = gd.maps[mid].npcs.any(func(n): return n.get("role", "") == "crystal" and n["pos"].distance_to(crystal_at) < 0.1)
		check(found, "%s tem cristal de retorno" % mid)
		check(gd.maps[mid].in_hub(crystal_at), "cristal de %s fica dentro do povoado" % mid)
	check(fdef.hub and not fdef.is_town and gd.town_map_id() == "city_aldara", "Posto é hub sem virar a cidade inicial")
	var e: SimEntity = sim.spawn_bot(gd.classes["paladin"], "Vinculo", fid, fdef.town_center + Vector3(-3, 0, -8), 15)
	e.brain = null
	check(sim.home_of(e)["map"] == "city_aldara", "sem cristal: retorno é a cidade")
	check(not sim.bind_crystal(e, "forest_smith"), "só cristal vincula")
	check(sim.bind_crystal(e, "crystal_field_forest"), "vincula no cristal do Posto")
	check(e.bind_map == fid and sim.is_walkable(e.bind_pos, fdef, 0.5), "ponto de retorno é chão livre na frente do cristal")
	# G leva ao cristal
	e.position = Vector3(70, 0, -16)
	var go := InputCommand.new()
	go.recall = true
	var idle := InputCommand.new()
	sim._update_recall(e, go, go, 0.1)
	for i in range(int(Balance.RECALL_TIME / 0.1) + 2):
		sim._update_recall(e, idle, idle, 0.1)
	sim._process_map_changes()
	check(e.map_id == fid and e.position.distance_to(e.bind_pos) < 0.5, "G volta para o cristal do Posto")
	sim._update_recall(e, go, go, 0.1)
	check(is_equal_approx(e.recall_left, 0.0), "já no cristal: G não começa")
	# renascer no cristal
	sim._change_map(e, "city_aldara", Vector3(60, 0, 10))
	ProgressionSystem.respawn_character(sim, e)
	sim._process_map_changes()
	check(e.map_id == fid and e.position.distance_to(e.bind_pos) < 0.5, "morrer renasce no cristal vinculado")
	# troca de skills: dentro do Posto pode, fora do muro não
	var sid: String = e.learned.keys()[0] if not e.learned.is_empty() else ""
	if sid != "":
		e.position = fdef.town_center + Vector3(3, 0, 3)
		check(sim.set_skill_slot(e, 5, sid), "troca skill dentro do Posto")
		e.position = Vector3(70, 0, -16)
		check(not sim.set_skill_slot(e, 4, sid), "fora do muro não troca skill")
	# save
	sim.despawn(e)
	var me: SimEntity = sim.player
	if me:
		var keep_map := me.bind_map
		var keep_pos := me.bind_pos
		me.bind_map = fid
		me.bind_pos = Vector3(-4, 0, -3)
		save.save_player(me)
		var d: Dictionary = save.load_data()
		me.bind_map = ""
		save.apply_to(me, d)
		check(me.bind_map == fid and me.bind_pos.distance_to(Vector3(-4, 0, -3)) < 0.01, "save guarda o cristal vinculado")
		d.erase("bind")
		save.apply_to(me, d)
		check(me.bind_map == "", "save antigo volta para a cidade")
		me.bind_map = keep_map
		me.bind_pos = keep_pos
		save.delete_slot(TEST_SLOT)

## Investida élfica como evento central: levas 3x, 18 sentinelas, invasores x1,5; mago invoca espíritos que marcham
## e seguram a leva; batedor ferido troca a espada pelo arco; lince salta longe; invasor prefere quem cura.
func _check_raid_tactics(gd, sim) -> void:
	var fd: MapDef = gd.maps["field_forest"]
	var guards: Array = fd.npcs.filter(func(n): return n.has("fighter"))
	check(guards.size() >= 18, "Posto: 18 sentinelas (%d)" % guards.size())
	var base_n := 0
	for mid in fd.raid["waves"][0]["mobs"]:
		base_n += int(fd.raid["waves"][0]["mobs"][mid])
	check(base_n >= 18 and fd.raid["waves"][0]["mobs"].has("elf_raider_mage"), "investida: leva base 3x com magos (%d)" % base_n)
	check(gd.monsters["elf_lynx"].skill_ids.has("mob_lynx_leap") and gd.skills["mob_lynx_leap"].effects["dash"] >= 7.0, "lince de guerra salta longe")
	var ws := WorldSim.new()
	ws.rng.seed = 11
	ws.load_map(gd.maps[GameData.town_map_id()])
	var m: Dictionary = ws.load_map(fd)
	m["spawners"].clear()
	for o in m["entities"].duplicate():
		if o.kind == SimEntity.Kind.MONSTER:
			ws.despawn(o)
	var st := RaidSystem.state(m)
	# mago: espíritos marcham com a leva e seguram o fim da leva
	var mage: SimEntity = ws.spawn_monster(RaidSystem.scaled_def(ws, gd.monsters["elf_raider_mage"], 0), fd.id, fd.raid["from"])
	mage.raid_id = 0
	st["ids"] = [mage.id]
	MobSystem.spawn_adds(ws, mage, gd.skills["mob_raise_wisps"].effects["boss_summon"])
	var wisps: Array = m["entities"].filter(func(o): return o.boss_id == mage.id)
	check(wisps.size() == 2 and wisps.all(func(w): return w.raid_id == 0 and (st["ids"] as Array).has(w.id)), "espíritos do mago marcham e contam na leva")
	check(gd.monsters["elf_wisp"].xp == 0, "espírito não dá XP")
	# batedor ferido: guarda a espada e atira
	var raider: SimEntity = ws.spawn_monster(RaidSystem.scaled_def(ws, gd.monsters["elf_raider"], 0), fd.id, fd.raid["from"])
	raider.raid_id = 0
	var archer: MonsterDef = gd.monsters["elf_raider_archer"]
	raider.hp = raider.stats.max_hp * 0.3
	raider.brain.think(raider, ws, m, 0.05)
	check(raider.stance == "bow" and raider.basic_skill == GameData.basic_skill_for_monster(archer) and MonsterBrain._style_def(raider).ranged,
		"batedor com pouca vida troca a espada pelo arco")
	# foco: entre dois alvos iguais, o bispo vem primeiro
	var tank: SimEntity = ws.spawn_bot(gd.classes["paladin"], "Tanque", fd.id, raider.position + Vector3(3, 0, 0), 16)
	var healer: SimEntity = ws.spawn_bot(gd.classes["bishop"], "Cura", fd.id, raider.position + Vector3(-3.5, 0, 0), 16)
	tank.brain = null
	healer.brain = null
	var fresh: SimEntity = ws.spawn_monster(RaidSystem.scaled_def(ws, gd.monsters["elf_raider"], 0), fd.id, raider.position + Vector3(0, 0, 1))
	fresh.raid_id = 0
	m["chars"] = [tank, healer]
	fresh.brain.think(fresh, ws, m, 0.05)
	check(fresh.aggro_target == healer.id, "invasor mira em quem cura")
	# Segurar o Portão: qualquer elfo, em qualquer lugar, conta
	var hq: QuestDef = gd.quests["el2_defense"]
	healer.quests_active[hq.id] = 0
	QuestSystem.on_kill(healer, "elf_warrior")
	QuestSystem.on_kill(healer, "elf_raider_mage")
	QuestSystem.on_kill(healer, "elf_lynx")
	check(int(healer.quests_active[hq.id]) == 2, "Segurar o Portão: guerreiro e mago contam, lince não (%d)" % int(healer.quests_active[hq.id]))

## Todo mapa com modelo tem o GLB do Blender de verdade (uma exportação com a coleção escondida sai vazia, ~150 bytes,
## e o jogo mostra só o chão: o Posto ficou sem muralha assim).
func _check_map_models(gd) -> void:
	for mid in gd.maps:
		var md: MapDef = gd.maps[mid]
		if md.model == "":
			continue
		var path := "res://assets/models/%s.glb" % md.model
		var f := FileAccess.open(path, FileAccess.READ)
		check(f != null and f.get_length() > 100000, "%s: %s.glb tem conteúdo (%d bytes)" % [mid, md.model, f.get_length() if f else 0])

## Pedreira dos Golens (Floresta, 11-15): entrada na floresta, 2 guardiões no mapa e o Coração atrás do selo,
## golens comuns na faixa, chefes com modelo próprio, lacaios sem XP, material com fonte.
func _check_quarry(gd, sim) -> void:
	var fd: MapDef = gd.maps["field_forest"]
	check(fd.portals.any(func(p): return p["target_map"] == "dg_pedreira"), "Floresta tem a entrada da Pedreira")
	var pd: MapDef = gd.maps["dg_pedreira"]
	check(pd.parent_map == "field_forest" and pd.level_range == Vector2i(11, 15), "Pedreira é dungeon 11-15 da Floresta")
	var bosses := {}
	for mid in ["dg_pedreira", "dg_pedreira_coracao"]:
		for sp in gd.maps[mid].spawners:
			var m: MonsterDef = gd.monsters[sp["monster_id"]]
			if m.is_boss:
				bosses[m.id] = mid
			else:
				check(m.level >= 11 and m.level <= 15 and m.xp > 0, "%s: %s na faixa 11-15 com XP" % [mid, m.id])
	check(bosses.size() >= 3, "Pedreira tem 3+ chefes (%s)" % str(bosses.keys()))
	for bid in ["golem_ancient", "crystal_warden", "quarry_heart"]:
		var b: MonsterDef = gd.monsters[bid]
		check(b.model == "mob_" + bid or b.model.begins_with("mob_") and ResourceLoader.exists("res://assets/models/%s.glb" % b.model), "%s tem modelo próprio" % bid)
		for ph in b.phases:
			if ph.has("summon"):
				var add: MonsterDef = gd.monsters[ph["summon"]["id"]]
				check(add.xp == 0 and add.loot_table == "", "lacaio %s sem XP nem loot" % add.id)
	var gate: Dictionary = MapsCatalog.PORTAL_GATES.get("to_dg_pedreira_coracao", {})
	check(gate.get("bosses", []) == ["golem_ancient", "crystal_warden"], "Coração da Pedreira abre com os dois guardiões")
	var drops := false
	for mid in ["golem_moss", "golem_stone", "golem_shard"]:
		var lt: LootTable = gd.loot_tables[gd.monsters[mid].loot_table]
		drops = drops or lt.entries.any(func(en): return en["item"] == "stone_core")
	check(drops and gd.items.has("stone_core"), "golens dão Núcleo de Pedra")

## Invocações lutam sozinhas: acham alvo perto do dono, usam as skills do monstro, defendem o dono
## e as que atiram ficam longe (o Elemental de Fogo ficava parado). Sonda completa: tools/tests/pet_probe.tscn.
func _check_summon_ai(gd, sim) -> void:
	var mid := "field_forest"
	var m: Dictionary = sim.maps.get(mid, {})
	if m.is_empty():
		m = sim.load_map(gd.maps[mid])
	var at := Vector3(-90, 0, 9)
	var owner = sim.spawn_bot(gd.classes["elementalist"], "Dono", mid, at, 20)
	owner.brain = null
	for pid in ["fire_elemental", "frost_elemental"]:
		var pet = sim.spawn_summon(owner, gd.monsters[pid], at + Vector3(1, 0, 0), 0.0)
		check(pet.skills.size() >= 1 and pet.stats.matk == pet.stats.patk, "%s: carrega as skills e usa o ataque do dono na magia" % pid)
		var dummy = sim.spawn_monster(gd.monsters["wolf"], mid, at + Vector3(8, 0, 0))
		dummy.brain = null
		dummy.stats.max_hp = 50000.0
		dummy.hp = 50000.0
		var near := 0.0
		var nn := 0
		for i in range(60):
			sim.tick(0.05)
			if pet.aggro_target == dummy.id and i >= 30:      # depois de se posicionar: distância média
				near += pet.position.distance_to(dummy.position)
				nn += 1
		near /= maxf(1.0, nn)
		check(dummy.hp < dummy.stats.max_hp, "%s ataca sozinho um monstro perto do dono" % pid)
		if gd.monsters[pid].ranged:
			check(near > 3.0, "%s atira de longe (%.1f m)" % [pid, near])
		sim.despawn(dummy)
		var wolf = sim.spawn_monster(gd.monsters["wolf"], mid, at + Vector3(-5, 0, 0))
		wolf.aggro_target = owner.id
		var defends := false
		for i in range(40):
			sim.tick(0.05)
			defends = defends or pet.aggro_target == wolf.id
		check(defends, "%s defende o dono de quem o ataca" % pid)
		sim.despawn(wolf)
		owner.position = at + Vector3(-30, 0, 0)       # dono se afasta: larga a briga e volta
		var d2 = sim.spawn_monster(gd.monsters["wolf"], mid, at + Vector3(8, 0, 0))
		d2.brain = null
		pet.position = at + Vector3(6, 0, 0)
		pet.aggro_target = d2.id
		pet.brain.skill_rethink = 0.0
		pet.brain.think(pet, sim, sim.maps[mid], 0.05)
		check(pet.aggro_target != d2.id, "%s: coleira no dono (larga alvo longe)" % pid)
		sim.despawn(d2)
		owner.position = at
		sim.despawn(pet)
	sim.despawn(owner)

## Seta da quest no minimapa: toda quest do catálogo tem um objetivo num mapa real, a seta acha o caminho
## (portal) de onde a quest é dada, e a quest pronta aponta para quem recebe.
func _check_quest_guide(gd, sim) -> void:
	var p = sim.spawn_bot(gd.classes["paladin"], "Seta", "city_aldara", Vector3(0, 0, 6), 30)
	var giver_map := {}
	for mid in gd.maps:
		for n in gd.maps[mid].npcs:
			giver_map[n.get("id", "")] = mid
	for qid in gd.quests:
		var q: QuestDef = gd.quests[qid]
		p.quests_active.clear()
		p.inventory.clear()
		p.map_id = giver_map.get(q.giver_npc, "city_aldara")
		p.quests_active[qid] = 0
		var obj: Dictionary = QuestSystem.objective(p, q)
		check(not obj.is_empty() and gd.maps.has(obj["map"]), "quest %s tem objetivo no mapa (%s)" % [qid, obj])
		var g: Dictionary = QuestSystem.guide_point(p, q)
		check(not g.is_empty(), "seta da quest %s acha o rumo a partir de %s" % [qid, p.map_id])
		if not obj.is_empty() and obj["map"] != p.map_id and not g.is_empty():
			check(g["via_portal"], "quest %s noutro mapa aponta para um portal" % qid)
	# caminho de portais: Aldara → Cidade Élfica passa pela Floresta; dungeon da floresta também
	check(PortalSystem.portal_towards(gd.maps["city_aldara"], "elf_city").get("target_map", "") == "field_forest", "Aldara → cidade élfica: portal da floresta")
	check(PortalSystem.portal_towards(gd.maps["city_aldara"], "dg_ninho").get("target_map", "") == "field_forest", "Aldara → ninho: portal da floresta")
	check(PortalSystem.portal_towards(gd.maps["elf_city"], "dg_catacumbas_trono").get("target_map", "") == "field_forest", "cidade élfica → trono: volta pela floresta")
	# pronta → NPC de entrega
	var q1: QuestDef = gd.quests["q01_welcome"]
	p.map_id = "city_aldara"
	p.quests_active.clear()
	p.quests_active[q1.id] = q1.count
	var npc_pos = QuestSystem._npc_of(gd.maps["city_aldara"], q1.turnin())
	check(npc_pos != null and QuestSystem.guide_point(p, q1).get("pos") == npc_pos, "quest pronta aponta para quem recebe")
	p.quests_active.clear()
	sim.despawn(p)

## Cor de destaque da roupa contrasta com a principal e nunca cai em verde-oliva escuro.
func _check_accents() -> void:
	for i in range(40):
		for s in [0.1, 0.5, 0.9]:
			var c := Color.from_hsv(i / 40.0, s, 0.8)
			var a := ItemDef.accent(c)
			check(not (a.h > 0.12 and a.h < 0.26 and a.v < 0.7), "destaque de %s não é oliva (%s)" % [c, a])
			check(Vector3(a.r - c.r, a.g - c.g, a.b - c.b).length() > 0.3, "destaque de %s contrasta (%s)" % [c, a])

## Pontos alcançáveis a pé a partir de `from` (grade de 1,5 m), para provar que nada ficou isolado.
## `wall_r` > 0 fecha um círculo em `wall`: prova que uma passagem é a única ligação.
func _reach(sim, md: MapDef, from: Vector3, wall := Vector3.ZERO, wall_r := 0.0) -> Dictionary:
	var step := 1.5
	var seen := {}
	var open: Array[Vector2i] = [Vector2i(roundi(from.x / step), roundi(from.z / step))]
	seen[open[0]] = true
	while not open.is_empty():
		var c: Vector2i = open.pop_back()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			var p := Vector3(n.x * step, 0, n.y * step)
			if not seen.has(n) and sim.is_walkable(p, md, 0.45) and (wall_r <= 0.0 or p.distance_to(wall) > wall_r):
				seen[n] = true
				open.append(n)
	return seen

func _reached(seen: Dictionary, p: Vector3) -> bool:
	var c := Vector2i(roundi(p.x / 1.5), roundi(p.z / 1.5))
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			if seen.has(c + Vector2i(dx, dz)):
				return true
	return false

## Toda zona tem os quatro tipos de lugar, todos alcançáveis, com NPC/quest/monstro/portal ligados.
func _check_places(gd, sim, md: MapDef) -> void:
	var mid := md.id
	var count := {}
	var seen := _reach(sim, md, md.spawn_point)
	for pl in md.places:
		count[pl["type"]] = int(count.get(pl["type"], 0)) + 1
		var d: float = Vector2(pl["pos"].x, pl["pos"].z).length()
		var far: float = 112.0 * (1.2 if mid == "city_aldara" else 1.0)       # o Vale cresceu 20% (places.grow_aldara)
		check(d > 40.0 and d < far, "%s: lugar %s a %.0f m do hub" % [mid, pl["id"], d])
		for other in md.places:
			if other != pl:
				check(pl["pos"].distance_to(other["pos"]) > 25.0, "%s: %s longe de %s" % [mid, pl["id"], other["id"]])
	for t in ["cabin", "camp", "shrine", "dungeon"]:
		check(int(count.get(t, 0)) >= 1, "%s: tem lugar %s" % [mid, t])
	check(int(count.get("cabin", 0)) >= 2, "%s: 2+ cabanas" % mid)
	for n in md.npcs:
		check(_reached(seen, n["pos"]), "%s: NPC %s alcançável a pé" % [mid, n["id"]])
	for sp in md.spawners:
		check(_reached(seen, sp["pos"]), "%s: spawner %s alcançável a pé" % [mid, sp["monster_id"]])
	for pt in md.portals:
		check(_reached(seen, pt["pos"]), "%s: portal %s alcançável a pé" % [mid, pt["id"]])
	var quest_npcs := 0
	for n in md.npcs:
		if MapsCatalog.PLACE_NPCS[mid].has(n["id"]) and n["role"] == "quest":
			quest_npcs += 1
			var has_quest := false
			for qid in gd.quests:
				has_quest = has_quest or gd.quests[qid].giver_npc == n["id"]
			check(has_quest, "%s: %s dá quest" % [mid, n["id"]])
	check(quest_npcs >= 2, "%s: cabanas têm NPC de quest (%d)" % [mid, quest_npcs])
	for n in md.npcs:
		if n["role"] == "board" and MapsCatalog.PLACE_NPCS[mid].has(n["id"]):
			check(ResourceLoader.exists("res://assets/models/%s.glb" % n.get("model", "")), "%s: %s é uma pedra, não um boneco" % [mid, n["id"]])

## Dungeon: entrada e saída casam, chefe no fim, tudo alcançável, bots não entram sozinhos.
func _check_dungeons(gd, sim) -> void:
	for did in MapsCatalog.DUNGEON_DEFS:
		var md: MapDef = gd.maps[did]
		var zone: MapDef = gd.maps[md.parent_map]
		sim.load_map(md)
		var entry := {}
		for pt in zone.portals:
			if pt["target_map"] == did:
				entry = pt
		check(not entry.is_empty(), "%s: entrada em %s" % [did, zone.id])
		var exit := {}
		for pt in md.portals:
			if pt["target_map"] == zone.id:
				exit = pt
		check(not exit.is_empty(), "%s: saída volta para %s" % [did, zone.id])
		check(zone.portals[0]["target_map"] != did, "%s: entrada não é o portal principal da zona (fallback dos bots)" % did)
		if not entry.is_empty() and not exit.is_empty():
			check(sim.is_walkable(entry["target_pos"], md, 0.45), "%s: chegada andável" % did)
			check(sim.is_walkable(exit["target_pos"], zone, 0.45), "%s: retorno na zona andável" % did)
			check(exit["target_pos"].distance_to(entry["pos"]) > float(entry["radius"]) + 1.0, "%s: retorno fora do portal" % did)
		var seen := _reach(sim, md, md.spawn_point)
		var bosses := 0
		for sp in md.spawners:
			check(_reached(seen, sp["pos"]), "%s: spawner %s alcançável" % [did, sp["monster_id"]])
			bosses += 1 if gd.monsters[sp["monster_id"]].is_boss else 0
		var want: int = MapsCatalog.DUNGEON_DEFS[did].get("bosses", 1)
		check(bosses == want, "%s: %d chefe(s) (%d)" % [did, want, bosses])
		for pt in md.portals:
			check(_reached(seen, pt["pos"]), "%s: portal %s alcançável" % [did, pt["id"]])
		for n in md.npcs:
			check(_reached(seen, n["pos"]), "%s: NPC %s alcançável" % [did, n["id"]])
		check(FileAccess.file_exists("res://assets/models/map_%s.glb" % did), "%s: GLB existe" % did)
		var far = sim.spawn_bot(gd.classes["ranger"], "Turista", "city_aldara", Vector3(0, 0, 6), md.level_range.x)
		for i in range(40):
			far.brain._plan_trip(far, sim)
			check(far.brain.dest_map != did, "bot não planeja caçar em %s" % did)
		sim.despawn(far)

## Catacumbas: 3 chefes no total, alas separadas por rocha e NPCs de quest lá dentro.
func _check_catacombs(gd, sim) -> void:
	var md: MapDef = gd.maps["dg_catacumbas"]
	var bosses := {}
	for mid in ["dg_catacumbas", "dg_catacumbas_trono"]:
		for sp in gd.maps[mid].spawners:
			if gd.monsters[sp["monster_id"]].is_boss:
				bosses[sp["monster_id"]] = true
	check(bosses.size() == 3, "Catacumbas: 3 chefes (%d)" % bosses.size())
	for b in bosses:
		check(gd.monsters[b].phases.size() >= 1, "%s tem fases" % b)
		check(gd.loot_tables.has(gd.monsters[b].loot_table) and gd.monsters[b].loot_table != "lt_boar_king", "%s tem saque próprio" % b)
	check(gd.monsters["count_vargo"].phases.size() >= 2, "Conde tem 3 fases")
	# as alas só se ligam pelo vestíbulo: sem ele a ala oeste não alcança a leste
	var west: Vector3 = _spawner_pos(md, "bone_captain")
	var east: Vector3 = _spawner_pos(md, "wailing_widow")
	var vest := Vector3(0, 0, 20 * 1.25)               # vestíbulo (build_dungeons.SCALE = 1.25)
	var seen: Dictionary = _reach(sim, md, west, vest, 12.0 * 1.25 + 4.5)      # raio do salão + recortes da parede de rochas
	check(not _reached(seen, east), "alas oeste e leste só se ligam pelo vestíbulo")
	check(md.portals.size() == 2, "Catacumbas: saída + selo")
	for n in md.npcs:
		check(n["role"] == "quest", "%s dá quest" % n["id"])
	check(md.npcs.size() >= 2, "NPCs de quest dentro da dungeon")
	for mdef in gd.monsters.values():
		if mdef.model != "":
			check(FileAccess.file_exists("res://assets/models/%s.glb" % mdef.model), "modelo %s existe" % mdef.model)

func _spawner_pos(md: MapDef, monster_id: String) -> Vector3:
	for sp in md.spawners:
		if sp["monster_id"] == monster_id:
			return sp["pos"]
	return Vector3.ZERO

## Estradas limpas: nada sólido em cima de estrada/trilha, trilha não entra no lago nem em morro, estrada não termina
## solta, spawner não pega a estrada. Vale para toda zona exportada do Blender.
## Moradores passeiam perto de casa, nunca dentro de sólidos; conversa segura o NPC; serviços ficam no posto.
func _check_villagers(gd, sim) -> void:
	var def: MapDef = gd.maps["city_aldara"]
	check(MapsCatalog.VILLAGERS.size() >= 10 and MapsCatalog.VILLAGERS.size() <= 12, "Aldara: 10-12 moradores (%d)" % MapsCatalog.VILLAGERS.size())
	var m: Dictionary = sim.maps["city_aldara"]
	var vil: Array = m["entities"].filter(func(o): return o.kind == SimEntity.Kind.NPC and o.npc_data.get("role", "") == "villager")
	var smith: SimEntity = m["entities"].filter(func(o): return o.kind == SimEntity.Kind.NPC and o.npc_data.get("id", "") == "smith")[0]
	check(vil.size() == MapsCatalog.VILLAGERS.size(), "moradores nascem no mapa (%d)" % vil.size())
	for v in vil:
		check(sim.is_walkable(v.position, def, 0.4), "%s nasce em chão livre" % v.npc_data["id"])
		check(not v.look.is_empty(), "%s tem visual" % v.npc_data["id"])
	var start := {}
	for v in vil:
		start[v.id] = v.position
	var smith_at: Vector3 = smith.position
	var far := 0.0
	var moved := 0
	var bad: Array = []
	for i in range(60 * 40):
		for v in vil:
			sim._update_npc(v, m, 1.0 / 60.0)
		if i % 30 == 0:
			for v in vil:
				var home: Vector3 = v.npc_data["pos"]
				var lim: float = float(v.npc_data.get("wander", 0.0)) + 1.5 if v.npc_data.has("wander") else 40.0
				far = maxf(far, home.distance_to(v.position) - lim)
				if not sim.is_walkable(v.position, def, 0.3):
					bad.append(v.npc_data["id"])
	for v in vil:
		if v.position.distance_to(start[v.id]) > 1.0:
			moved += 1
	check(moved >= vil.size() - 2, "moradores andam (%d/%d se moveram em 40 s)" % [moved, vil.size()])
	check(far <= 0.0, "moradores ficam perto de casa (excesso %.1f m)" % far)
	check(bad.is_empty(), "moradores nunca entram em sólido (%s)" % str(bad.slice(0, 3)))
	check(smith.position == smith_at, "ferreiro fica no posto")
	# conversa: segura o NPC parado
	var v0: SimEntity = vil[0]
	v0.npc_wait = 0.0
	v0.npc_goal = v0.position + Vector3(3, 0, 0)
	v0.npc_hold = 0.0
	sim.player = sim.player if sim.player else null
	v0.npc_hold = Balance.NPC_TALK_HOLD
	var at := v0.position
	sim._update_npc(v0, m, 0.5)
	check(v0.position == at, "morador conversando fica parado")
	v0.npc_hold = 0.0

## Casas que abrem: porta em Aldara só para o jogador, sala com saída de volta para a frente da casa, NPCs dentro.
## Druida começa com as armas das formas na bolsa, e o ferreiro forja as armas comuns das builds.
func _check_druid_start(gd, sim) -> void:
	var cls: ClassDef = gd.classes["druid"]
	var d: SimEntity = sim.spawn_character(SimEntity.Kind.BOT, cls, "Dru", "city_aldara", Vector3(0, 0, 6), 1)
	check(d.has_item("mace_t0", 2) and d.has_item("mace2h_t0"), "druida começa com duas maças e um martelo na bolsa")
	check(sim.equip(d, "mace_t0") and sim.equip(d, "mace_t0", true) and d.stats.meets([Balance.FORM_REQUIRES["wolf"]]), "duas maças: libera a Forma de Lobo")
	var shop: Array = []
	for n in gd.maps["city_aldara"].npcs:
		if n["id"] == "merchant":
			shop = n["shop"]
	for iid in ["mace_t0", "mace2h_t0", "axe_t0", "rifle_t0", "staff_oak", "bow_short"]:
		check(not gd.items.has(iid) or shop.has(iid), "mercador vende a arma de nível 1 %s" % iid)
	sim.despawn(d)

## Ritmo: ~15 h até o 30 e as quests dando ~45% de cada faixa.
func _check_xp_budget(gd) -> void:
	var hours := 0.0
	for lv in range(1, 30):
		hours += Balance.level_minutes(lv) / 60.0
	check(hours > 13.0 and hours < 17.0, "ritmo planejado até o 30: %.1f h" % hours)
	for band in Balance.XP_BANDS:
		var need := Balance.band_xp(band[0], band[1])
		var qx := 0
		var n := 0
		for qid in gd.quests:
			var q: QuestDef = gd.quests[qid]
			if not q.repeatable and q.level_req >= band[0] and q.level_req < band[1]:
				qx += q.reward_xp
				n += 1
		var share := float(qx) / maxf(1.0, need)
		var want := Balance.quest_share(band[0])
		check(absf(share - want) < 0.05, "faixa %d-%d: quests dão %.0f%% da XP (alvo %.0f%%, %d quests)" % [band[0], band[1], share * 100.0, want * 100.0, n])
		check(n >= 10, "faixa %d-%d: pelo menos 10 quests (%d)" % [band[0], band[1], n])
	# nível a nível (faixas 1-10 e 10-20): nenhum nível fica só no grind (o 6-7 e o 11-13 já ficaram quase sem quest)
	for lv in range(2, 20):
		var qx_lv := 0
		for qid in gd.quests:
			var q: QuestDef = gd.quests[qid]
			if not q.repeatable and q.level_req == lv:
				qx_lv += q.reward_xp
		check(qx_lv >= Balance.xp_for_level(lv) * 0.35, "nível %d: quests dão %d de %d XP (>= 35%%)" % [lv, qx_lv, Balance.xp_for_level(lv)])
	var kills_l25: float = Balance.xp_for_level(25) * (1.0 - Balance.XP_QUEST_SHARE) / gd.monsters["skeleton"].xp
	check(kills_l25 > 100 and kills_l25 < 400, "nível 25: ~%d abates de esqueleto (não milhares)" % int(kills_l25))

## Colheita: pontos em chão livre, F colhe em ~1 s, andar cancela, volta depois; COLLECT conta.
func _check_gather(gd, sim) -> void:
	for mid in ["city_aldara", "field_forest", "field_ruins", "elf_city"]:
		var list: Array = sim.maps[mid].get("gather", [])
		check(list.size() >= 15, "%s: pontos de colheita (%d)" % [mid, list.size()])
		var bad := list.filter(func(g): return not sim.is_walkable(g["pos"], gd.maps[mid], 0.5))
		check(bad.is_empty(), "%s: pontos em chão livre (%d fora)" % [mid, bad.size()])
		for g in list:
			check(gd.items.has(g["item"]) and UiKit.item_texture(gd.items[g["item"]]) != null, "%s: item %s com ícone" % [mid, g["item"]])
	var m: Dictionary = sim.maps["city_aldara"]
	var node: Dictionary = m["gather"][0]
	var e: SimEntity = sim.spawn_bot(gd.classes["paladin"], "Colhe", "city_aldara", node["pos"] + Vector3(0.8, 0, 0), 5)
	e.brain = null
	var before := int(e.inventory.get(node["item"], 0))
	sim._interact(e, m)
	check(e.gather_left > 0.0, "F perto do ponto começa a colher")
	var idle := InputCommand.new()
	for i in range(int(Balance.GATHER_TIME * 60) + 5):
		sim._update_gather(e, idle, idle, 1.0 / 60.0)
	check(int(e.inventory.get(node["item"], 0)) > before, "colheu %s" % node["item"])
	check(float(node["ready_at"]) > sim.time and sim.nearest_gather(e).get("pos", Vector3.INF) != node["pos"], "ponto colhido some até voltar")
	# andar cancela
	var node2: Dictionary = m["gather"][1]
	e.position = node2["pos"] + Vector3(0.6, 0, 0)
	sim._interact(e, m)
	var walk := InputCommand.new()
	walk.move = Vector2(1, 0)
	sim._update_gather(e, walk, walk, 0.1)
	check(e.gather_left == 0.0 and float(node2["ready_at"]) <= sim.time, "andar cancela a colheita")
	node["ready_at"] = 0.0
	sim.despawn(e)
	# animação: o kit gera os clipes de colher; minério usa a picareta
	var kit := KitModel.create("male", Color.WHITE, 0.02, "paladin")
	if kit:
		check(kit.anim.has_animation("gather_herb") and kit.anim.has_animation("gather_mine"), "kit tem os clipes de colher (erva e picareta)")
		check(GatherPose.clip_for("ore") == "gather_mine" and GatherPose.clip_for("star") == "gather_mine" and GatherPose.clip_for("herb") == "gather_herb"
			and GatherPose.clip_for("shell") == "gather_herb", "minério usa picareta; erva, concha e cogumelo, agachar e puxar")
		kit.free()

## Entregas, cadeias, colheita nas quests; sem chefe repetido; caçada paga por quem está na zona do monstro.
func _check_quest_variety(gd, sim) -> void:
	var kinds := {}
	var boss_quests := {}
	var dup: Array = []
	for qid in gd.quests:
		var q: QuestDef = gd.quests[qid]
		if not q.give_items.is_empty():
			kinds["entrega"] = int(kinds.get("entrega", 0)) + 1
			check(q.type == QuestDef.Type.COLLECT and q.give_items.has(q.target_id) and q.turnin() != q.giver_npc, "%s: entrega leva o item a outro NPC" % qid)
		if q.type == QuestDef.Type.COLLECT and q.give_items.is_empty():
			for mid in MapsCatalog.GATHER:
				for g in MapsCatalog.GATHER[mid]:
					if g[0] == q.target_id:
						kinds["colheita"] = int(kinds.get("colheita", 0)) + 1
		if q.type == QuestDef.Type.KILL and gd.monsters.has(q.target_id) and gd.monsters[q.target_id].is_boss and not q.repeatable:
			if boss_quests.has(q.target_id):
				dup.append(q.target_id)
			boss_quests[q.target_id] = true
	check(int(kinds.get("entrega", 0)) >= 5, "quests de entrega (%d)" % int(kinds.get("entrega", 0)))
	check(int(kinds.get("colheita", 0)) >= 6, "quests de colheita (%d)" % int(kinds.get("colheita", 0)))
	check(dup.is_empty(), "nenhum chefe com duas quests de história (%s)" % str(dup))
	check(boss_quests.has("crab_king") and boss_quests.has("boar_brute"), "Caranguejo-Rei e Presa-Rachada têm quest")
	# cadeias longas: o Lago (6), os bandidos (6), a erudita (4+)
	for pair in [["l6_rei", 6], ["b6_limpeza", 6], ["r4_chave", 4]]:
		var depth := 0
		var cur: String = pair[0]
		while cur != "" and gd.quests.has(cur):
			depth += 1
			cur = gd.quests[cur].prereq_quest
		check(depth >= int(pair[1]), "cadeia até %s tem %d passos" % [pair[0], depth])
	# todo NPC de quest existe em algum mapa
	var npcs := {}
	for mid in gd.maps:
		for n in gd.maps[mid].npcs:
			npcs[n["id"]] = true
	var missing: Array = []
	for qid in gd.quests:
		var q: QuestDef = gd.quests[qid]
		for who in [q.giver_npc, q.turnin()]:
			if not npcs.has(who):
				missing.append("%s:%s" % [qid, who])
	check(missing.is_empty(), "NPCs das quests existem (%s)" % str(missing.slice(0, 4)))
	# entrega: aceitar dá o pacote, desistir tira
	var e: SimEntity = sim.spawn_bot(gd.classes["paladin"], "Entrega", "city_aldara", Vector3(0, 0, 6), 5)
	e.brain = null
	var dq: QuestDef = gd.quests["d1_carta"]
	QuestSystem.accept(e, dq)
	check(e.has_item("sealed_letter") and QuestSystem.is_complete(e, dq), "aceitar a entrega põe a carta na bolsa")
	QuestSystem.abandon(e, dq)
	check(not e.has_item("sealed_letter"), "desistir tira a carta")
	sim.despawn(e)
	# caçada: quem paga é da zona do monstro
	var zone_giver := {"slime": "board", "crab": "board", "spider": "stone_druid", "skeleton": "stone_obelisk", "zombie": "board"}
	for mon in zone_giver:
		if gd.quests.has("h_" + mon):
			check(gd.quests["h_" + mon].giver_npc == zone_giver[mon], "caçada de %s paga por %s" % [mon, zone_giver[mon]])

## Polimento dos monstros: chefes com loot próprio, bando vem junto, nome pela diferença de nível.
func _check_monster_polish(gd, sim) -> void:
	var tables := {}
	for mid in gd.monsters:
		var md: MonsterDef = gd.monsters[mid]
		if md.is_boss and md.loot_table != "" and md.xp > 0:
			check(not tables.has(md.loot_table), "%s: tabela de loot própria (%s já usada por %s)" % [mid, md.loot_table, tables.get(md.loot_table, "")])
			tables[md.loot_table] = mid
			check(gd.loot_tables.has(md.loot_table), "%s: tabela %s existe" % [mid, md.loot_table])
	var m: Dictionary = sim.maps["city_aldara"]
	var at := Vector3(-60, 0, -40)
	var a: SimEntity = sim.spawn_monster(gd.monsters["wolf"], "city_aldara", at)
	var b: SimEntity = sim.spawn_monster(gd.monsters["wolf"], "city_aldara", at + Vector3(3, 0, 0))
	var c: SimEntity = sim.spawn_monster(gd.monsters["wolf"], "city_aldara", at + Vector3(14, 0, 0))
	var other: SimEntity = sim.spawn_monster(gd.monsters["boar"], "city_aldara", at + Vector3(0, 0, 2))
	for x in [a, b, c, other]:
		x.brain = null
		x.aggro_target = -1
	var hunter: SimEntity = sim.spawn_bot(gd.classes["ranger"], "Puxa", "city_aldara", at + Vector3(0, 0, -8), 10)
	hunter.brain = null
	sim._retarget(a, hunter)
	check(a.aggro_target == hunter.id and b.aggro_target == hunter.id, "bando: o lobo do lado vem junto")
	check(c.aggro_target < 0 and other.aggro_target < 0, "longe ou de outra espécie: fica")
	for x in [a, b, c, other, hunter]:
		sim.despawn(x)
	check(EntityView.level_color(20, 10).r > 0.9 and EntityView.level_color(20, 10).g < 0.4, "monstro 10 níveis acima: nome vermelho")
	check(EntityView.level_color(3, 12).is_equal_approx(Color(0.62, 0.62, 0.62)), "monstro muito abaixo: nome cinza")

## Dungeons do Vale (maiores): bandos também nos corredores, mas a chegada fica livre.
func _check_dungeon_density(gd, sim) -> void:
	for pair in [["dg_gruta", 6, 40], ["dg_catacumbas", 12, 60], ["dg_ninho", 6, 40], ["dg_cripta", 6, 36], ["dg_pedreira", 12, 60]]:
		var def: MapDef = gd.maps[pair[0]]
		var mobs := 0
		for sp in def.spawners:
			mobs += int(sp["count"])
			check((sp["pos"] as Vector3).distance_to(def.spawn_point) > 14.0, "%s: %s longe da chegada" % [pair[0], sp["monster_id"]])
			check(sim.is_walkable(sp["pos"], def, 0.4) or float(sp["radius"]) >= 3.0, "%s: %s em chão livre" % [pair[0], sp["monster_id"]])
		check(def.spawners.size() >= int(pair[1]) and mobs >= int(pair[2]), "%s: %d pontos de caça, %d monstros" % [pair[0], def.spawners.size(), mobs])

## Loja: não vende o que não tem preço (moeda lendária, pacote de entrega); "vender materiais" poupa o que a quest pede.
func _check_shop_rules(gd, sim) -> void:
	var e: SimEntity = sim.spawn_bot(gd.classes["paladin"], "Loja", "city_aldara", Vector3(0, 0, 6), 5)
	e.brain = null
	e.add_item("legend_coin", 1)
	e.add_item("fish_basket", 1)
	e.add_item("slime_gel", 4)
	e.add_item("boar_tusk", 3)
	check(not CraftSystem.sell(e, "legend_coin", 1) and not CraftSystem.sell(e, "fish_basket", 1), "moeda lendária e pacote de entrega não se vendem")
	e.quests_active["q05_boars"] = 0          # quest ativa que pede presas de javali
	var junk: Array = load("res://game/ui/npc_ui.gd").junk_of(e)
	check(junk.has("slime_gel") and not junk.has("boar_tusk") and not junk.has("legend_coin"), "vender materiais poupa o que a quest ativa pede (%s)" % str(junk))
	var g0 := e.gold
	check(CraftSystem.sell(e, "slime_gel", 4) and e.gold == g0 + int(gd.items["slime_gel"].price * 0.5) * 4, "vende a pilha pela metade do preço")
	sim.despawn(e)

## Forja nova: joias e capas por tier e tema, bolsas ampliadas; aprimoramento +1..+9; bolsa com limite; colher para em combate.
func _check_forge(gd, sim) -> void:
	var n_jewel := 0
	for tier in range(4):
		for piece in GearCatalog.THEME_PIECES:
			for theme in GearCatalog.THEMES:
				var rid := "rec_%s_%s_t%d" % [piece, theme, tier]
				check(gd.recipes.has(rid), "receita %s" % rid)
				if gd.recipes.has(rid):
					n_jewel += 1
					check(gd.recipes[rid].station == ("alchemy" if piece == "cape" else "smith"), "%s: estação certa" % rid)
	check(n_jewel == 36, "36 receitas de anel/amuleto/capa (%d)" % n_jewel)
	for i in range(Balance.BAG_UPGRADES):
		check(gd.recipes.has("rec_bag_t%d" % i) and UiKit.item_texture(gd.items["bag_t%d" % i]) != null, "Bolsa Ampliada %d: receita e ícone" % (i + 1))
	var e: SimEntity = sim.spawn_bot(gd.classes["paladin"], "Forja", "city_aldara", Vector3(0, 0, 6), 25)
	e.brain = null
	# drop: equipamento comum do tier que a classe usa (sem joia/capa)
	for tier in range(4):
		var pool: Array = sim.gear_pool(tier)
		check(pool.size() > 0 and not pool.any(func(it): return it.slot in [ItemDef.Slot.AMULET, ItemDef.Slot.RING, ItemDef.Slot.CAPE]), "tier %d: drop de arma/armadura (%d itens)" % [tier, pool.size()])
		check(pool.filter(func(it): return sim.fits_class(e, it)).size() > 0, "tier %d: tem drop para paladino" % tier)
	# aprimoramento
	var sw: ItemDef = e.equipment[ItemDef.Slot.WEAPON]
	var body: ItemDef = null
	for sl in e.equipment:
		if e.equipment[sl] and e.equipment[sl].def > 0.0 and sl != ItemDef.Slot.OFFHAND:
			body = e.equipment[sl]
	var atk0: float = e.stats.patk
	var def0: float = e.stats.pdef
	e.gold = 1_000_000
	e.add_item("iron_ore", 400)
	e.add_item("star_ore", 400)
	for i in range(Balance.PLUS_MAX):
		check(sim.enhance(e, e.equipment[ItemDef.Slot.WEAPON].id, ItemDef.Slot.WEAPON) != null, "arma vestida sobe para +%d" % (i + 1))
	var w9: ItemDef = e.equipment[ItemDef.Slot.WEAPON]
	check(w9.plus == Balance.PLUS_MAX and w9.base_id == sw.id and w9.id == "%s+%d" % [sw.id, Balance.PLUS_MAX], "a arma vestida é a versão +%d" % Balance.PLUS_MAX)
	check(sim.enhance(e, w9.id, ItemDef.Slot.WEAPON) == null, "não passa de +%d" % Balance.PLUS_MAX)
	# por cópia: duas espadas iguais na bolsa, aprimora uma — a outra continua +0
	e.add_item(sw.id, 2)
	var v1: ItemDef = sim.enhance(e, sw.id)
	check(v1 != null and e.has_item(sw.id, 1) and not e.has_item(sw.id, 2) and e.has_item(v1.id, 1), "aprimorar uma cópia não muda as outras (%s x1 + %s x1)" % [sw.id, v1.id if v1 else "?"])
	check(GameData.resolve_item(sw.id + "+4") and GameData.items[sw.id + "+4"].plus == 4 and not GameData.resolve_item(sw.id + "+12"), "id +N do save volta a existir (até +%d)" % Balance.PLUS_MAX)
	check(UiKit.item_texture(v1) != null, "versão aprimorada usa a arte da base")
	# save: versão +N na bolsa e vestida volta igual; save antigo (por tipo) vira uma cópia +N
	var sv: SimEntity = sim.spawn_bot(gd.classes["paladin"], "Save", "city_aldara", Vector3(0, 0, 8), 10)
	sv.brain = null
	SaveSystem.apply_to(sv, {"level": 10, "inventory": {sw.id + "+3": 1, sw.id: 2}, "equipment": {str(ItemDef.Slot.WEAPON): sw.id + "+7"}})
	check(sv.has_item(sw.id + "+3") and sv.equipment[ItemDef.Slot.WEAPON].plus == 7, "save guarda cada cópia com o seu +N")
	SaveSystem.apply_to(sv, {"level": 10, "inventory": {sw.id: 2}, "equipment": {}, "plus": {sw.id: 4}})
	check(sv.has_item(sw.id, 1) and sv.has_item(sw.id + "+4", 1), "save antigo: uma cópia vira +4, a outra continua +0")
	sim.despawn(sv)
	check(e.stats.patk > atk0 * 1.2, "arma +9 bate mais (%.0f -> %.0f)" % [atk0, e.stats.patk])
	if body:
		var bslot := -1
		for sl in e.equipment:
			if e.equipment[sl] == body:
				bslot = sl
		for i in range(5):
			sim.enhance(e, e.equipment[bslot].id, bslot)
		check(e.stats.pdef > def0 and e.equipment[bslot].plus == 5, "armadura +5 protege mais (%.0f -> %.0f)" % [def0, e.stats.pdef])
	check(int(sim.enhance_cost(sw, 0)["count"]) < int(sim.enhance_cost(sw, 8)["count"]) + 1 and sim.enhance_cost(sw, 8)["item"] == "star_ore"
		and sim.enhance_cost(sw, 0)["item"] == "iron_ore", "custo: ferro até +5, estelar do +6 em diante")
	check(int(sim.enhance_cost(sw, 8)["gold"]) > int(sim.enhance_cost(sw, 0)["gold"]) * 10, "ouro cresce a cada nível")
	check(Stats.plus_attr(4, 9) >= 2 and Stats.plus_attr(0, 9) == 0, "atributo da peça cresce com o aprimoramento")
	# bolsa com limite + ampliação na ordem
	var cap0 := e.bag_capacity()
	check(cap0 == Balance.BAG_BASE, "bolsa começa com %d espaços" % Balance.BAG_BASE)
	e.add_item("bag_t1", 1)
	check(not sim.use_bag_upgrade(e, "bag_t1"), "Bolsa II exige a I antes")
	e.add_item("bag_t0", 1)
	check(sim.use_bag_upgrade(e, "bag_t0") and e.bag_capacity() == cap0 + Balance.BAG_STEP, "Bolsa I: +%d espaços" % Balance.BAG_STEP)
	check(sim.use_bag_upgrade(e, "bag_t1") and e.bag_capacity() == cap0 + 2 * Balance.BAG_STEP, "Bolsa II depois da I")
	var fill := 0
	for iid in gd.items:
		if e.inventory.size() >= e.bag_capacity():
			break
		if not e.inventory.has(iid):
			e.add_item(iid, 1)
			fill += 1
	var outside := ""
	for iid in gd.items:
		if not e.inventory.has(iid):
			outside = iid
			break
	check(e.bag_full_for(outside) and not e.bag_full_for("iron_ore"), "bolsa cheia não aceita item novo (o que já tem empilha)")
	# colher: não começa e para em combate
	var m: Dictionary = sim.maps["city_aldara"]
	var node: Dictionary = m["gather"][2]
	node["ready_at"] = 0.0
	e.inventory.clear()
	e.position = node["pos"] + Vector3(0.6, 0, 0)
	e.combat_timer = 3.0
	sim._interact(e, m)
	check(e.gather_left == 0.0, "em combate não começa a colher")
	e.combat_timer = 0.0
	sim._interact(e, m)
	check(e.gather_left > 0.0, "fora de combate começa a colher")
	var idle := InputCommand.new()
	e.combat_timer = 3.0                     # levou um golpe (até absorvido pelo escudo marca combate)
	sim._update_gather(e, idle, idle, 0.1)
	check(e.gather_left == 0.0, "levar dano para a colheita")
	sim.despawn(e)

func _check_interiors(gd, sim) -> void:
	check(MapsCatalog.INTERIORS.size() >= 4 and MapsCatalog.INTERIORS.size() <= 6, "Aldara: 4-6 casas que abrem (%d)" % MapsCatalog.INTERIORS.size())
	var town: MapDef = gd.maps["city_aldara"]
	var m: Dictionary = sim.maps["city_aldara"]
	var saved = sim.player
	for iid in MapsCatalog.INTERIORS:
		var idef: MapDef = gd.maps.get(iid)
		check(idef != null and idef.interior and idef.is_town and idef.parent_map == "city_aldara", "%s: mapa de interior da cidade" % iid)
		if idef == null:
			continue
		check(gd.town_map_id() == "city_aldara", "a cidade de respawn continua sendo Aldara")
		var door: Dictionary = {}
		for pt in town.portals:
			if pt["id"] == "door_" + iid:
				door = pt
		check(not door.is_empty() and door.get("player_only", false), "%s: porta em Aldara (só jogador)" % iid)
		if door.is_empty():
			continue
		var dpos: Vector3 = door["pos"]
		check(sim.is_walkable(dpos, town, 0.45), "%s: porta em chão livre" % iid)
		check(sim.is_walkable(door["target_pos"], idef, 0.45), "%s: chegada dentro da casa é andável" % iid)
		var exit: Dictionary = idef.portals[0] if idef.portals.size() > 0 else {}
		check(not exit.is_empty() and exit["target_map"] == "city_aldara" and (exit["target_pos"] as Vector3).distance_to(dpos) < 2.6
			and (exit["target_pos"] as Vector3).distance_to(dpos) > float(door["radius"]) + 0.3, "%s: saída volta para a frente da porta (sem cair nela de novo)" % iid)
		check(not exit.is_empty() and (door["target_pos"] as Vector3).distance_to(exit["pos"]) > float(exit["radius"]) + 0.5, "%s: entrar não cai na saída" % iid)
		check(idef.npcs.size() >= 2, "%s: tem gente dentro (%d)" % [iid, idef.npcs.size()])
		for n in idef.npcs:
			check(sim.is_walkable(n["pos"], idef, 0.4), "%s: %s em chão livre" % [iid, n["id"]])
		# entrar: o jogador pisa na porta e vai para dentro; um bot no mesmo lugar não entra
		var bot: SimEntity = sim.spawn_bot(gd.classes["paladin"], "Porta", "city_aldara", dpos, 5)
		bot.brain = null
		sim.player = null
		sim._check_portals(bot, m)
		check(sim._pending_map_changes.is_empty(), "%s: bot passa pela porta sem entrar" % iid)
		sim.player = bot
		sim._check_portals(bot, m)
		sim._process_map_changes()
		check(bot.map_id == iid, "%s: jogador entra pela porta" % iid)
		if bot.map_id == iid:
			bot.position = exit["pos"]
			sim._check_portals(bot, sim.maps[iid])
			sim._process_map_changes()
			check(bot.map_id == "city_aldara" and bot.position.distance_to(dpos) < 2.6, "%s: sai de volta na frente da casa" % iid)
		sim.player = saved
		sim.despawn(bot)
	sim.player = saved

func _check_layout_conflicts(gd, sim) -> void:
	for mid in ["city_aldara", "field_forest", "field_ruins", "elf_city"]:
		var z: Dictionary = MapsCatalog.load_zone(mid)
		var roads: Array = z["roads"].filter(func(r): return r["kind"] in ["road", "trail"])
		var bad: Array = []
		for o in z["obstacles"]:
			if not o.get("solid", true) or o.get("kind", "") in ["wall", "cliff", "water"]:
				continue
			var p := Vector2(o["pos"].x, o["pos"].z)
			var half: float = maxf(o["size"].x, o["size"].z) * 0.5 * (1.0 if o.get("kind", "") == "fence" else 0.85)
			for r in roads:
				if _poly_dist2(p, r["pts"]) < float(r["w"]) * 0.5 + half - 0.25:
					bad.append("%s@%.0f,%.0f" % [o.get("kind", "?"), p.x, p.y])
					break
		check(bad.is_empty() or mid != "city_aldara", "%s: nada sólido nas estradas (%d: %s)" % [mid, bad.size(), str(bad.slice(0, 4))])
		var wet: Array = []
		for r in roads:
			for w in z["water"]:
				if w["kind"] == "lake":
					for q in r["pts"]:
						if q.distance_to(w["pos"]) < float(w["r"]):
							wet.append(r["kind"])
							break
		check(wet.is_empty(), "%s: estrada/trilha não entra no lago (%s)" % [mid, str(wet)])
		if mid != "city_aldara":
			continue
		var crossed: Array = []
		for sp in z["spawners"]:
			if float(sp["radius"]) <= 2.0:
				continue
			for r in roads:
				if r["kind"] == "road" and _poly_dist2(Vector2(sp["pos"].x, sp["pos"].z), r["pts"]) < float(sp["radius"]) * 0.6:
					crossed.append(sp["monster_id"])
					break
		check(crossed.is_empty(), "city_aldara: spawner fora da estrada (%s)" % str(crossed))
	# a praia dos caranguejos e o rei que sai do lago
	var md: MapDef = gd.maps["city_aldara"]
	var crabs: Array = md.spawners.filter(func(s): return s["monster_id"] in ["crab", "crab_king"])
	check(crabs.size() >= 3, "Vale: praia dos caranguejos com o Rei (%d spawners)" % crabs.size())
	var m: Dictionary = sim.maps["city_aldara"]
	for s in crabs:
		check(not sim._point_in_solid(s["pos"], m), "%s nasce em chão livre" % s["monster_id"])
	var king: Array = crabs.filter(func(s): return s["monster_id"] == "crab_king")
	check(king.size() == 1 and king[0].has("emerge"), "Caranguejo-Rei sai do lago (emerge)")
	check(gd.monsters["crab_king"].phases.size() >= 2 and gd.monsters["crab_small"].xp == 0, "Caranguejo-Rei: fases e filhotes sem XP")

func _poly_dist2(p: Vector2, pts: Array) -> float:
	var best := INF
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best

## Regras de layout de toda zona do Blender: vale fechado, POIs a 40-120 m do hub, tudo alcançável.
func _check_zone_layout(gd, sim, md: MapDef) -> void:
	var mid := md.id
	check(md.model == "map_" + mid and FileAccess.file_exists("res://assets/models/map_%s.glb" % mid), "%s: GLB da zona existe" % mid)
	check(md.roads.size() >= 5 and md.water.size() >= 1, "%s: estradas e água" % mid)
	check(md.has_hunting() and md.spawners.size() >= 7, "%s: spawners" % mid)
	var cliffs := 0
	for ob in md.obstacles:
		if ob.get("kind", "") == "cliff":
			cliffs += 1
	check(cliffs >= 60, "%s: borda de penhascos fecha o vale (%d)" % [mid, cliffs])
	# raios do hub pra fora: todos batem na borda antes do fim do mapa (menos onde há portal)
	var open_rays := 0
	for i in range(24):
		var dir := Vector3(cos(TAU * i / 24.0), 0, sin(TAU * i / 24.0))
		var near_portal := false
		for pt in md.portals:
			if Vector3(pt["pos"].x, 0, pt["pos"].z).normalized().dot(dir) > 0.985:
				near_portal = true
		var hit := false
		var r := 60.0
		while r < md.size.x * 0.5 - 1.0:
			if not sim.is_walkable(dir * r, md, 0.45) and r > 95.0:
				hit = true
				break
			r += 0.5
		if not hit and not near_portal:
			open_rays += 1
	check(open_rays == 0, "%s: borda fecha o vale (%d raios escapam)" % [mid, open_rays])
	check(sim.is_walkable(md.spawn_point, md, 0.45), "%s: ponto de chegada andável" % mid)
	for sp in md.spawners:
		var d: float = Vector2(sp["pos"].x, sp["pos"].z).length()
		var hostile_hub: bool = mid in HOSTILE_HUBS and d < gd.maps[mid].town_radius         # cidade inimiga: a guarnição mora no hub
		check((d > 40.0 or hostile_hub) and d < 120.0 * (1.2 if mid == "city_aldara" else 1.0), "%s: spawner %s a %.0f m do hub" % [mid, sp["monster_id"], d])
		check(sim.is_walkable(sim.random_walkable(md, sp["pos"], float(sp["radius"])), md), "%s: spawner %s andável" % [mid, sp["monster_id"]])
	for n in md.npcs:
		if n.get("role", "") == "crystal":          # o cristal é a própria coluna sólida: confere a frente dele
			check(sim.is_walkable(n["pos"] + (md.town_center - n["pos"]).normalized() * Balance.CRYSTAL_ARRIVE, md, 0.5), "%s: frente do cristal livre" % mid)
			continue
		check(sim.is_walkable(n["pos"], md, 0.3), "%s: NPC %s em chão livre" % [mid, n["id"]])
	for pt in md.portals:
		check(sim.is_walkable(pt["pos"], md, 0.45), "%s: portal %s alcançável" % [mid, pt["id"]])
	for other in gd.maps:
		for pt in gd.maps[other].portals:
			if pt["target_map"] == mid:
				var arrive: Vector3 = pt["target_pos"]
				check(sim.is_walkable(arrive, md, 0.45), "%s: chegada de %s andável" % [mid, other])
				for own in md.portals:
					check(arrive.distance_to(own["pos"]) > float(own["radius"]) + 1.0, "%s: chegada de %s fora do portal de volta" % [mid, other])


# ---------------------------------------------------------------------------
# personagens: kit modular (kit_male/kit_female) tem os clipes que a EntityView pede
# ---------------------------------------------------------------------------
func _check_character_models(gd, sim) -> void:
	# kits genéricos (NPCs, sem conjuntos) e um por classe (com os conjuntos/armas/escudos só dela)
	var kits: Array = [["male", ""], ["female", ""]]
	for cid in gd.classes:                 # cada classe nos dois sexos (criação de personagem)
		kits.append(["male", cid])
		kits.append(["female", cid])
	for pair in kits:
		var body: String = pair[0]
		var own: String = pair[1]
		var kid: String = ("%s_%s" % [own, body]) if own != "" else body
		check(KitModel.exists(body, own) and KitModel.path_for(body, own).ends_with("kit_%s.glb" % kid), "kit_%s.glb existe" % kid)
		var k := KitModel.create(body, Color.WHITE, 0.025, own)
		var mine := func(set_id: String) -> bool: return gd.sets[set_id].class_id == own
		for clip in ["idle", "run", "atk_1h_a", "atk_2h", "atk_bow", "atk_staff", "cast", "cast_buff", "hit", "die", "block", "jump", "fall", "land", "dash", "idle_bow", "idle_staff"]:
			check(k.resolve(clip) != "", "kit_%s: clipe %s" % [kid, clip])
		for piece in ["arm_cape_cape_cape", "arm_plate_legs_legs", "arm_leather_legs_legs", "arm_cloth_legs_legs", "arm_plate_head_ridge", "arm_leather_body_mantle", "arm_leather_body_strap", "arm_cloth_body_sash"]:
			check(k.pieces(piece + "*").size() > 0, "kit_%s: detalhe %s" % [kid, piece])
		check(k.has_material("tint2"), "kit_%s: tem peças de cor de destaque" % kid)
		# cada boneco instancia o kit inteiro: malha demais estoura o limite de recursos da GPU com a cidade cheia
		var meshes := k.pieces("*").size()
		check(meshes < 200, "kit_%s: poucas malhas por boneco (%d; kit por classe, peças de conjunto juntas por slot)" % [kid, meshes])
		if own == "":
			check(k.pieces("arm_pal*").is_empty() and k.pieces("arm_ber*").is_empty(), "kit_%s: genérico não leva conjuntos" % kid)
		# espada própria de cada conjunto com visual (ItemDef.weapon_style -> wpn_main_<tipo>_<estilo>)
		for set_id in GearCatalog.SET_VISUALS.keys().filter(mine):
			for iid in gd.sets[set_id].pieces:
				var wit: ItemDef = gd.items[iid]
				if wit.slot == ItemDef.Slot.WEAPON and not iid.ends_with("_offhand"):
					check(wit.weapon_style != "" and k._nodes.has("wpn_main_%s_%s" % [wit.weapon_type, wit.weapon_style]), "kit_%s: espada própria de %s" % [kid, set_id])
					check(k.main_node(wit) == "wpn_main_%s_%s" % [wit.weapon_type, wit.weapon_style], "kit_%s: %s usa a espada própria" % [kid, iid])
		# maça do conjunto (variante da espada): modelo próprio no kit
		for set_id in GearCatalog.SET_VISUALS.keys().filter(mine):
			for aid in gd.sets[set_id].alt_pieces:
				var ait: ItemDef = gd.items[aid]
				check(k.main_node(ait) == "wpn_main_%s_%s" % [ait.weapon_type, ait.weapon_style], "kit_%s: %s usa a maça própria" % [kid, aid])
		# segundo machado dos Gêmeos: arma própria na mão esquerda
		for set_id in GearCatalog.SET_VISUALS.keys().filter(mine):
			for iid in gd.sets[set_id].pieces:
				var oit: ItemDef = gd.items[iid]
				if iid.ends_with("_offhand") and oit.weapon_type == "axe":
					check(k.off_node_of(oit) == "wpn_off_axe_%s" % oit.weapon_style and k._nodes.has(k.off_node_of(oit)), "kit_%s: %s com machado próprio na mão esquerda" % [kid, iid])
		var plain: ItemDef = gd.items["sword_iron"]
		check(k.main_node(plain) == "wpn_main_sword", "arma comum continua com o modelo do tipo")
		# todo conjunto com visual próprio (GearCatalog.SET_VISUALS) tem as 4 peças no kit
		for set_id in GearCatalog.SET_VISUALS.keys().filter(mine):
			var style: String = GearCatalog.SET_VISUALS[set_id]["style"]
			for slot in ["head", "body", "gloves", "boots"]:
				check(k.pieces("arm_%s_%s_*" % [style, slot]).size() > 0, "kit_%s: peças do conjunto %s (%s)" % [kid, style, slot])
		k.free()
	# todo conjunto lendário do paladino tem visual próprio, cada um diferente
	var pal_styles := {}
	for set_id in gd.sets:
		var psd: SetDef = gd.sets[set_id]
		if psd.class_id != "paladin":
			continue
		check(GearCatalog.SET_VISUALS.has(set_id), "%s tem visual próprio" % set_id)
		for iid in psd.pieces:
			var pit: ItemDef = gd.items[iid]
			if pit.armor_style != "" and pit.slot != ItemDef.Slot.LEGS:      # calça: estilo da build (o kit tem), na cor do conjunto
				pal_styles[pit.armor_style] = true
				check(pit.armor_style == GearCatalog.SET_VISUALS.get(set_id, {}).get("style", ""), "%s usa o visual do conjunto" % iid)
	check(pal_styles.size() == 12, "12 conjuntos do paladino, 12 visuais (%d)" % pal_styles.size())
	var ber := 0
	for set_id in gd.sets:
		if gd.sets[set_id].class_id == "berserker":
			ber += 1
			check(GearCatalog.SET_VISUALS.has(set_id), "%s tem visual próprio" % set_id)
	check(ber == 12, "12 conjuntos do berserker (%d)" % ber)
	var bis := 0
	for set_id in gd.sets:
		if gd.sets[set_id].class_id == "bishop":
			bis += 1
			check(GearCatalog.SET_VISUALS.has(set_id), "%s tem visual próprio" % set_id)
			for pid in gd.sets[set_id].pieces:
				var bit: ItemDef = gd.items[pid]
				if bit.weapon_type == "shield":
					check(bit.shield_style == GearCatalog.SET_VISUALS[set_id]["style"] and ResourceLoader.exists("res://assets/icons/%s.png" % bit.icon), "%s: escudo próprio com ícone" % pid)
	check(bis == 12, "12 conjuntos do bispo (%d)" % bis)
	# cada conjunto do paladino tem uma maça além da espada: cai junto, conta como a peça de arma, não muda o total
	var mace_sets := 0
	for set_id in gd.sets:
		var msd: SetDef = gd.sets[set_id]
		if msd.class_id != "paladin":
			continue
		check(msd.alt_pieces.size() == 1, "%s: tem maça alternativa" % set_id)
		if msd.alt_pieces.is_empty():
			continue
		mace_sets += 1
		var mace: ItemDef = gd.items[msd.alt_pieces[0]]
		check(mace.weapon_type in ["mace", "mace2h"] and mace.set_id == set_id and mace.weapon_style != "", "%s: maça do conjunto com visual" % mace.id)
		check(not (mace.id in msd.pieces) and not (mace.id in msd.armor), "%s: maça não soma no total de peças" % set_id)
		check(ResourceLoader.exists("res://assets/icons/%s.png" % mace.icon), "%s: ícone da maça" % mace.id)
		var pool: Array = gd.legendary_pool(gd.classes["paladin"], msd.level)
		check(mace.id in pool, "%s: maça cai como lendário" % mace.id)
		var sword: ItemDef = null
		for pid in msd.pieces:
			if gd.items[pid].slot == ItemDef.Slot.WEAPON and not pid.ends_with("_offhand"):
				sword = gd.items[pid]
		check(sword != null and mace.attributes == sword.attributes and mace.is_two_handed() == sword.is_two_handed(), "%s: maça com os atributos e as mãos da espada" % mace.id)
	check(mace_sets == 12, "12 maças de conjunto (%d)" % mace_sets)
	# bônus: maça + armadura conta igual a espada + armadura
	var ms: SetDef = gd.sets["set_paladin_guardiao_20"]
	var pa: SimEntity = sim.spawn_bot(gd.classes["paladin"], "SetMace", "city_aldara", Vector3(0, 0, 6), 30)
	pa.brain = null
	pa.equipment.clear()
	for pid in ms.pieces:
		var pit: ItemDef = gd.items[pid]
		if pit.slot != ItemDef.Slot.WEAPON or pid.ends_with("_offhand"):
			pa.equipment[pit.slot] = pit
	pa.equipment[ItemDef.Slot.WEAPON] = gd.items[ms.alt_pieces[0]]
	pa.recompute_stats()
	check(int(pa.stats.active_sets.get(ms.id, 0)) == ms.armor.size(), "armadura completa: %d/%d (arma não conta)" % [int(pa.stats.active_sets.get(ms.id, 0)), ms.armor.size()])
	check(pa.stats.thorns_pct > 0.0, "maça lendária do Guardião (tanque): Retaliação")
	sim.despawn(pa)
	for set_id in GearCatalog.SET_VISUALS:
		var vis: Dictionary = GearCatalog.SET_VISUALS[set_id]
		if vis.has("icon"):
			for iid in gd.sets[set_id].pieces:          # só as peças que o conjunto tem (Cruzado não tem mão secundária)
				var piece: String = iid.get_slice("_", iid.get_slice_count("_") - 1)
				if piece == "legs":
					check(UiKit.item_texture(gd.items[iid]) != null, "%s: calça com arte pintada" % set_id)
					continue
				check(ResourceLoader.exists("res://assets/icons/%s_%s.png" % [vis["icon"], piece]), "%s: ícone %s" % [set_id, piece])
	# primeiro lendário do paladino (Guardião lv5): visual próprio + ícones
	var sd: SetDef = gd.sets.get("set_paladin_guardiao_5")
	check(sd != null and sd.name == "Conjunto Cavaleiro da Fortaleza", "set do paladino lv5 com nome da referência")
	for iid in sd.pieces:
		var it: ItemDef = gd.items[iid]
		check(UiKit.item_texture(it) != null, "%s tem ícone" % iid)
		if it.armor_style != "" and it.slot != ItemDef.Slot.LEGS:
			check(it.armor_style == "pal1", "%s usa o visual pal1" % iid)


## Pulo (Espaço): sobe, volta ao chão; golpe apertado no ar espera o pouso (buffer).
func _check_jump(gd, sim) -> void:
	var j = sim.spawn_bot(gd.classes["berserker"], "Pulo", "city_aldara", Vector3(0, 0, 5), 5)
	j.brain = null
	var c := InputCommand.new()
	c.jump = true
	c.aim = j.position + Vector3(0, 0, 2)
	sim._apply_command(j, c, sim.maps["city_aldara"], 1.0 / 60.0)
	check(j.airborne() and j.jump_v > 0.0, "Espaço: pula")
	var peak := 0.0
	var a := InputCommand.new()
	a.attack = true
	a.aim = j.position + Vector3(0, 0, 2)
	sim._apply_command(j, a, sim.maps["city_aldara"], 1.0 / 60.0)
	check(j.state != SimEntity.State.CASTING, "no ar o golpe não sai")
	for i in range(90):
		sim._update_entity(j, sim.maps["city_aldara"], 1.0 / 60.0)
		peak = maxf(peak, j.jump_h)
	check(not j.airborne() and j.jump_h == 0.0, "volta ao chão")
	check(peak > 0.7 and peak < 1.3, "altura do pulo ~1 m (%.2f)" % peak)
	sim.despawn(j)


## Compra o caminho mais curto (BFS) dos nós já comprados até `target`, nó a nó pelas regras da sim.
## Devolve o custo total, ou -1 se algum nó do caminho for recusado.
func _buy_path(sim, e, target: String) -> int:
	var nodes: Dictionary = gd_ref.trees[e.class_def.id]["nodes"]
	var prev := {}
	var queue: Array = []
	for nid in e.tree:
		queue.append(nid)
		prev[nid] = ""
	while queue.size() > 0:
		var cur: String = queue.pop_front()
		if cur == target:
			break
		for l in nodes[cur]["links"]:
			if not prev.has(l):
				prev[l] = cur
				queue.append(l)
	if not prev.has(target):
		return -1
	var path: Array = []
	var cur := target
	while cur != "" and not e.tree.has(cur):
		path.push_front(cur)
		cur = prev[cur]
	var total := 0
	for nid in path:
		var c: int = int(nodes[nid]["cost"])
		if not sim.tree_allocate(e, nid):
			return -1
		total += c
	return total


# ---------------------------------------------------------------------------
# árvore de pontos de skill (TreeCatalog): forma, regras e um "jogador" por build do 1 ao 30 (loops)
# ---------------------------------------------------------------------------
## Talentos de escolha: linhas de 3 opções diferentes, todo bônus com rótulo, e a regra de um por linha (troca na cidade).
func _check_picks(cid: String, picks: Array, sim) -> void:
	var rows := {}
	for n in picks:
		if not rows.has(n["group"]):
			rows[n["group"]] = []
		rows[n["group"]].append(n)
	check(rows.size() == TreeCatalog.PICK_ROWS.size(), "%s: %d linhas de talento" % [cid, rows.size()])
	for g in rows:
		var keys := {}
		for n in rows[g]:
			for k in n["stats"]:
				keys[k] = true
				check(TreeCatalog.STAT_SHORT.has(k) and TreeCatalog.STAT_FAMILY.has(k), "%s: talento %s com rótulo" % [cid, k])
		check(rows[g].size() == 3 and keys.size() == 3, "%s/%s: 3 opções diferentes (%s)" % [cid, g, str(keys.keys())])
	if cid != "ranger":
		return
	# regra, com um ranger de verdade: compra uma, a irmã troca de graça na cidade e não fora dela
	var gd = gd_ref
	var e: SimEntity = sim.spawn_bot(gd.classes["ranger"], "Escolha", "city_aldara", sim.maps["city_aldara"]["def"].town_center, 30)
	e.brain = null
	e.mastery_points = 3
	var row0: Array = rows["row_0"]
	var a: String = row0[0]["id"]
	var b: String = row0[1]["id"]
	check(sim.tree_allocate(e, a) and e.mastery_points == 3, "talento de escolha não gasta pontos")
	e.mastery_points = 0
	check(sim.tree_block_reason(e, rows["row_1"][0]["id"]) == "", "talento de escolha sem pontos: liberado pelo nível")
	e.mastery_points = 2
	check(sim.tree_allocate(e, b) and not e.tree.has(a) and e.tree.has(b) and e.mastery_points == 2, "trocar a escolha na cidade é de graça e tira a outra")
	e.position = Vector3(80, 0, 14)
	check(sim.tree_block_reason(e, a) == "troque a escolha desta linha na cidade", "fora da cidade não troca")
	e.level = 1
	check(sim.tree_block_reason(e, rows["row_7"][0]["id"]).begins_with("requer nível"), "linha de nível alto bloqueada no nível baixo")
	sim.despawn(e)

func _check_tree(gd, sim, save) -> void:
	var total_points := 0
	for lv in range(2, Balance.MAX_LEVEL + 1):
		total_points += Balance.MASTERY_POINTS_PER_LEVEL + (1 if lv in Balance.MASTERY_BONUS_LEVELS else 0)
	for cid in gd.classes:
		var cls: ClassDef = gd.classes[cid]
		var tr: Dictionary = gd.trees.get(cid, {})
		check(not tr.is_empty(), "%s: tem árvore" % cid)
		var nodes: Dictionary = {}
		var picks: Array = []
		for nid in tr["nodes"]:                  # talentos de escolha (aba própria, sem ligações) contam à parte
			if tr["nodes"][nid]["kind"] == "pick":
				picks.append(tr["nodes"][nid])
			else:
				nodes[nid] = tr["nodes"][nid]
		_check_picks(cid, picks, sim)
		# --- forma ---
		check(nodes.size() >= 25 and nodes.size() <= 100, "%s: árvore compacta (%d nós)" % [cid, nodes.size()])
		var seen := {tr["start"]: true}
		var queue: Array = [tr["start"]]
		while queue.size() > 0:
			var cur: String = queue.pop_front()
			for l in nodes[cur]["links"]:
				check(cur in nodes[l]["links"], "%s: ligação %s-%s nos dois sentidos" % [cid, cur, l])
				if not seen.has(l):
					seen[l] = true
					queue.append(l)
		check(seen.size() == nodes.size(), "%s: todos os nós alcançáveis do início (%d/%d)" % [cid, seen.size(), nodes.size()])
		var skill_nodes := 0
		var cost_all := 0
		for nid in nodes:
			cost_all += int(nodes[nid]["cost"])
			if nodes[nid]["kind"] == "skill":
				skill_nodes += 1
		check(skill_nodes == cls.skill_ids.size(), "%s: cada skill da classe é um nó (%d/%d)" % [cid, skill_nodes, cls.skill_ids.size()])
		for sid in cls.skill_ids:
			check(nodes.has("%s_s_%s" % [cid, sid]) and nodes.has("%s_m_%s" % [cid, sid]), "%s: nó e maestria de %s" % [cid, sid])
		for t in gd.talents_for_class(cid):
			check(nodes.has("%s_t_%s" % [cid, t.id]), "%s: evolução %s na árvore" % [cid, t.id])
		var overlap: Array = []
		var ids := nodes.keys()
		for i in range(ids.size()):
			for k in range(i + 1, ids.size()):
				if (nodes[ids[i]]["pos"] as Vector2).distance_to(nodes[ids[k]]["pos"]) < 0.35:
					overlap.append("%s~%s" % [ids[i], ids[k]])
		check(overlap.is_empty(), "%s: nós não se sobrepõem no desenho %s" % [cid, overlap])
		check(cost_all > total_points, "%s: não dá pra comprar tudo — escolher é a build (%d > %d)" % [cid, cost_all, total_points])
		# --- regras ---
		var t0 = sim.spawn_character(SimEntity.Kind.BOT, cls, "Arv", "city_aldara", Vector3(-6, 0, 10), 1)
		for sid in cls.starting_skills:
			check(t0.tree.has("%s_s_%s" % [cid, sid]), "%s: skill inicial %s já comprada" % [cid, sid])
		var far := ""
		var lvl_gate := ""
		for nid in nodes:
			if t0.tree.has(nid):
				continue
			var adj := false
			for l in nodes[nid]["links"]:
				adj = adj or t0.tree.has(l)
			if not adj and far == "":
				far = nid
			if adj and int(nodes[nid]["level"]) > 1 and lvl_gate == "":
				lvl_gate = nid
		t0.mastery_points = 50
		check(far != "" and not sim.tree_allocate(t0, far), "%s: nó sem vizinho comprado é recusado" % cid)
		if lvl_gate != "":
			check(not sim.tree_allocate(t0, lvl_gate), "%s: nó acima do nível é recusado" % cid)
		t0.mastery_points = 0
		var cheap := ""
		for nid in nodes:
			if sim.tree_block_reason(t0, nid) == "pontos insuficientes (1)":
				cheap = nid
		check(cheap != "", "%s: sem pontos, nada é comprado" % cid)
		sim.despawn(t0)
		# --- um jogador por build, do nível 1 ao 30, sempre indo atrás das skills da build ---
		for b in cls.builds:
			var e = sim.spawn_character(SimEntity.Kind.BOT, cls, "Build", "city_aldara", Vector3(-6, 0, 10), 1)
			var want: Array = b["skills"]
			var refused := 0
			for lv in range(2, Balance.MAX_LEVEL + 1):
				e.level = lv
				e.mastery_points += Balance.MASTERY_POINTS_PER_LEVEL + (1 if lv in Balance.MASTERY_BONUS_LEVELS else 0)
				var guard := 0
				while e.mastery_points > 0 and guard < 30:
					guard += 1
					var target := ""
					for sid in want:
						if not e.knows(sid) and gd.skills[sid].unlock_level <= lv:
							target = "%s_s_%s" % [cid, sid]
							break
					if target != "":
						var before: int = e.mastery_points
						if _path_cost(gd, e, target) <= e.mastery_points:
							if _buy_path(sim, e, target) < 0:
								refused += 1
								break
							continue
						if before == e.mastery_points:
							break
					# sobra: maestria das skills da build, depois passivos
					var bought := false
					for kind in ["mastery", "stat", "talent"]:
						for nid in nodes:
							var n: Dictionary = nodes[nid]
							if n["kind"] == kind and (kind != "mastery" or n["ref"] in want) and sim.tree_block_reason(e, nid) == "":
								bought = sim.tree_allocate(e, nid)
								break
						if bought:
							break
					if not bought:
						break
			var missing: Array = []
			for sid in want:
				if not e.knows(sid):
					missing.append(sid)
			check(refused == 0 and missing.is_empty(), "%s/%s: do 1 ao 30 pela árvore pega todas as skills da build (faltam %s)" % [cid, b["id"], missing])
			check(not e.tree_bonus.is_empty(), "%s/%s: passivos da árvore ativos (%s)" % [cid, b["id"], e.tree_bonus])
			if cid == "paladin" and b["id"] == "guardiao":
				e.recompute_stats()
				var hp_with: float = e.stats.max_hp
				var bonus: Dictionary = e.tree_bonus.duplicate()
				e.tree_bonus = {}
				e.recompute_stats()
				check(bonus.has("hp_pct") == (hp_with > e.stats.max_hp + 0.5) or not bonus.has("hp_pct"), "passivo de HP muda o HP máximo")
				sim.recompute_tree_bonus(e)
			sim.despawn(e)
	# --- save/load guarda a árvore ---
	var pl = sim.player
	var had: Array = pl.tree.keys()
	var bonus_before: Dictionary = pl.tree_bonus.duplicate()
	save.save_player(pl)
	var data: Dictionary = save.load_data()
	check(data.get("tree", []).size() == had.size(), "save guarda os nós da árvore (%d)" % had.size())
	save.delete_slot(TEST_SLOT)

func _path_cost(gd, e, target: String) -> int:
	var nodes: Dictionary = gd.trees[e.class_def.id]["nodes"]
	var dist := {}
	var queue: Array = []
	for nid in e.tree:
		dist[nid] = 0
		queue.append(nid)
	while queue.size() > 0:
		var cur: String = queue.pop_front()
		for l in nodes[cur]["links"]:
			if not dist.has(l):
				dist[l] = int(dist[cur]) + int(nodes[l]["cost"])
				queue.append(l)
	return int(dist.get(target, 999))


# ---------------------------------------------------------------------------
# skills: tema visual válido, clipe certo nos dois kits, impacto dentro do clipe (bancada: game/dev/showcase.gd)
# ---------------------------------------------------------------------------
func _check_skill_visuals(gd) -> void:
	var view_script: GDScript = load("res://game/entities/entity_view.gd")
	var impacts: Dictionary = view_script.IMPACT_FRAME
	var kits := [KitModel.create("male", Color.WHITE), KitModel.create("female", Color.WHITE)]
	var bad_theme: Array = []
	var themes_used := {}
	for sid in gd.skills:
		var s: SkillDef = gd.skills[sid]
		if not (s.vfx in SkillsCatalog.VFX_THEMES):
			bad_theme.append(sid)
		themes_used[s.vfx] = true
		check(SkillFx.PALETTE.has(s.vfx) and SkillFx.PARTS.has(s.vfx), "tema %s (%s) tem cor e partículas" % [s.vfx, sid])
	check(bad_theme.is_empty(), "toda skill tem tema visual válido %s" % [bad_theme])
	check(themes_used.size() >= 10, "skills usam temas variados (%d)" % themes_used.size())
	# cada clipe que a EntityView pode escolher existe nos dois kits e o impacto cabe nele
	for clip in impacts:
		if clip in EntityView.FORM_CLIP.values():
			continue                     # gesto de bicho: só nas formas (_check_form_clips)
		for k in kits:
			var name: String = k.resolve(clip)
			check(name != "", "clipe %s existe no kit" % clip)
			if name != "":
				var frames: float = k.anim.get_animation(name).length * 24.0
				check(float(impacts[clip]) <= frames + 1.0, "impacto de %s (quadro %d) dentro do clipe (%d quadros)" % [clip, impacts[clip], int(frames)])
	for k in kits:
		k.free()


# ---------------------------------------------------------------------------
# grupo (party): convite, limite, XP dividida, curas só no grupo, liderança, bots seguindo o líder
# ---------------------------------------------------------------------------
func _check_party(gd, sim) -> void:
	var m: Dictionary = sim.maps["city_aldara"]
	var mk := func(cls: String, nm: String, pos: Vector3, lv: int):
		var b = sim.spawn_bot(gd.classes[cls], nm, "city_aldara", pos, lv)
		return b
	var a = mk.call("bishop", "PA", Vector3(0, 0, 8), 10)
	var b = mk.call("berserker", "PB", Vector3(1.5, 0, 8), 10)
	var c = mk.call("ranger", "PC", Vector3(-1.5, 0, 8), 10)
	var stranger = mk.call("paladin", "PX", Vector3(0, 0, 9.5), 10)
	var made: Array = [a, b, c, stranger]
	check(sim.party_invite_error(a, a) != "", "não convida a si mesmo")
	check(sim.party_invite(a, b), "convite enviado")
	check(sim.party_invite_error(a, b).contains("pendente"), "convite duplicado recusado")
	check(sim.party_accept(b) and a.party_id >= 0 and a.party_id == b.party_id, "aceitar cria o grupo")
	check(sim.party_leader(b) == a and sim.party_members(a).size() == 2, "quem convidou é o líder")
	check(not sim.party_accept(b), "aceitar sem convite não faz nada")
	check(sim.party_invite_error(b, c).contains("líder"), "só o líder convida")
	check(sim.party_invite(a, c) and sim.party_accept(c) and sim.party_members(a).size() == 3, "terceiro membro")
	# limite
	while sim.party_members(a).size() < Balance.PARTY_MAX:
		var x = mk.call("druid", "PF%d" % made.size(), Vector3(made.size(), 0, 12), 10)
		made.append(x)
		sim.party_invite(a, x)
		sim.party_accept(x)
	var extra = mk.call("druid", "PExtra", Vector3(4, 0, 12), 10)
	made.append(extra)
	check(sim.party_invite_error(a, extra).contains("cheio"), "grupo cheio em %d" % Balance.PARTY_MAX)
	for x in made.slice(4):
		sim.party_leave(x)
	check(sim.party_members(a).size() == 3, "membros extras saíram")
	# XP dividida
	var mdef: MonsterDef = null
	for mid in gd.monsters:
		if not gd.monsters[mid].is_boss and gd.monsters[mid].xp > 0:
			mdef = gd.monsters[mid]
			break
	var mob = sim.spawn_monster(mdef, "city_aldara", Vector3(0, 0, 10))
	mob.level = 10
	c.position = Vector3(0, 0, 10 + Balance.PARTY_SHARE_RANGE + 5)
	var sharers: Array = sim.kill_sharers(a, mob)
	check(sharers.size() == 2 and sharers.has(b) and not sharers.has(c), "XP só pra quem está perto (%d)" % sharers.size())
	var xa: int = a.xp
	var xb: int = b.xp
	sim._on_monster_killed(mob, a)
	var each := int(mdef.xp * (1.0 + Balance.PARTY_XP_BONUS) / 2.0)
	check(a.xp - xa == each and b.xp - xb == each, "XP dividida com bônus de grupo (%d e %d, esperado %d)" % [a.xp - xa, b.xp - xb, each])
	b.level = 10 + Balance.PARTY_LEVEL_GAP + 1
	check(not sim.kill_sharers(a, mob).has(b), "diferença de nível grande não divide XP")
	b.level = 10
	c.position = Vector3(-1.5, 0, 8)
	sim.despawn(mob)
	# curas em área: grupo sim, estranho não
	var prayer: SkillDef = sim.resolve_skill(a, gd.skills["bis_prayer"])
	for t in [b, stranger]:
		t.hp = t.stats.max_hp * 0.3
	sim._apply_skill(a, prayer, m)
	check(b.hp > b.stats.max_hp * 0.3, "Prece cura o grupo")
	check(stranger.hp == stranger.stats.max_hp * 0.3, "Prece não cura quem é de fora")
	check(a.is_friend(b) and not a.is_friend(stranger), "is_friend respeita o grupo")
	# invocação herda o grupo
	var sm = sim.spawn_summon(c, mdef, c.position + Vector3(1, 0, 0), 5.0)
	check(sm.party_id == a.party_id and a.is_friend(sm), "invocação é do grupo do dono")
	sim.despawn(sm)
	# bot seguidor: anda até o líder; com o líder em outro mapa, vai pro portal
	a.brain = null
	var f = b
	f.position = a.position + Vector3(12, 0, 0)
	var cmd: InputCommand = f.brain.think(f, sim, m, 0.05)
	var to_leader := Vector2(a.position.x - f.position.x, a.position.z - f.position.z).normalized()
	check(cmd.move.length() > 0.1 and cmd.move.normalized().dot(to_leader) > 0.5, "seguidor anda até o líder")
	var other: String = gd.maps["city_aldara"].portals[0]["target_map"]
	sim._change_map(a, other, gd.maps[other].spawn_point)
	cmd = f.brain.think(f, sim, m, 0.05)
	check(cmd.move.length() > 0.1, "líder em outro mapa: seguidor vai pro portal (%s)" % other)
	sim._change_map(a, "city_aldara", Vector3(0, 0, 8))
	f.position = Vector3(1.5, 0, 8)
	# seguidor cura o grupo
	c.brain = null
	var nb = mk.call("bishop", "PHealer", Vector3(2, 0, 8), 12)
	made.append(nb)
	sim.party_invite(a, nb)
	sim.party_accept(nb)
	nb.learned["bis_heal"] = true
	nb.talents["bis_t_heal_party"] = true          # Curar com raio de 6 m
	nb.ensure_slots()
	nb.skills[5] = gd.skills["bis_heal"]
	nb.cooldowns.clear()
	nb.mp = nb.stats.max_mp
	b.hp = b.stats.max_hp * 0.3
	cmd = nb.brain.think(nb, sim, m, 0.05)
	check(cmd.skill_slot >= 0 and nb.skills[cmd.skill_slot].kind == SkillDef.Kind.HEAL, "bot do grupo cura membro ferido")
	# liderança, expulsar, sair
	check(sim.party_promote(a, c) and sim.party_leader(a) == c, "líder passa a liderança")
	check(not sim.party_kick(a, b), "ex-líder não expulsa")
	check(sim.party_kick(c, nb) and nb.party_id == -1, "líder expulsa")
	sim.party_leave(c)
	check(sim.party_leader(a) != c and sim.party_leader(a) != null, "líder saiu: outro assume")
	var pid: int = a.party_id
	sim.despawn(b)
	check(a.party_id == -1 and not sim.parties.has(pid), "grupo de 1 se desfaz (membro desconectou)")
	# convite de bot: decide sozinho; diferença de nível grande recusa; convite expira
	var far = mk.call("druid", "PFar", Vector3(5, 0, 5), 10 + Balance.PARTY_LEVEL_GAP + 3)
	made.append(far)
	check(not far.brain.wants_party(far, a, sim), "bot recusa grupo com nível muito diferente")
	check(sim.party_invite_error(a, far).contains("nível"), "UI bloqueia convite a bot de nível muito diferente")
	check(not sim.party_invite(a, far) and not sim.invites.has(far.id), "convite fora da faixa de nível nem é enviado")
	far.level = 10
	sim.party_invite(a, far)
	sim.time += 5.0
	sim._update_invites()
	check(not sim.invites.has(far.id), "convite de bot resolvido sozinho")
	if far.party_id >= 0:
		sim.party_leave(far)
	far.level = 10 + Balance.PARTY_LEVEL_GAP + 3
	var pl = sim.player                           # o jogador decide pela UI: o convite só some ao expirar
	check(sim.party_invite(a, pl), "bot convida o jogador")
	sim._update_invites()
	check(sim.invites.has(pl.id), "convite ao jogador espera a resposta")
	sim.time += Balance.PARTY_INVITE_TIME + 1.0
	sim._update_invites()
	check(not sim.invites.has(pl.id) and not sim.party_accept(pl), "convite expira")
	var left := 0
	for x in made:
		if is_instance_valid(x) and x.party_id >= 0:
			left += 1
		sim.despawn(x)
	for pid2 in sim.parties:
		for id in sim.parties[pid2]["members"]:
			check(sim.entities.has(id), "grupo %d só tem membros online" % pid2)
	check(left == 0, "nenhum grupo de teste sobrando (%d)" % left)


# ---------------------------------------------------------------------------
# água: rio e lago bloqueiam, ponte passa, bot atravessa pela ponte
# ---------------------------------------------------------------------------
## Ameaça decide o alvo, dano decide o abate, saque tem dono e ouro de grupo é dividido.
func _check_threat_loot(gd, sim) -> void:
	var m: Dictionary = sim.maps["city_aldara"]
	var at := Vector3(70, 0, 40)
	var a = sim.spawn_bot(gd.classes["paladin"], "TA", "city_aldara", at, 10)
	var b = sim.spawn_bot(gd.classes["ranger"], "TB", "city_aldara", at + Vector3(2, 0, 0), 10)
	var o = sim.spawn_bot(gd.classes["ranger"], "TO", "city_aldara", at + Vector3(0, 0, 3), 10)
	var mob = sim.spawn_monster(gd.monsters["wolf"], "city_aldara", at + Vector3(1, 0, 1))
	mob.brain = null
	mob.stats.max_hp = 1000.0
	mob.hp = 1000.0
	sim._deal_damage(a, mob, 10, false, false, "physical")
	check(mob.aggro_target == a.id, "primeiro golpe puxa o monstro")
	sim._deal_damage(b, mob, 10, false, false, "physical")
	check(mob.aggro_target == a.id, "dano igual não troca de alvo")
	sim._deal_damage(b, mob, 30, false, false, "physical")
	check(mob.aggro_target == b.id, "quem passa 110%% da ameaça vira o alvo")
	a.level = 20
	a.recompute_stats()
	var taunt: SkillDef = gd.skills["pal_taunt"]
	check(taunt.unlock_level <= 8 and gd.skills["dru_bellow"].unlock_level <= 8, "tanques têm provocar na dungeon de nível 8")
	a.skill_aim = at
	sim._apply_skill(a, sim.resolve_skill(a, taunt), m)
	check(mob.aggro_target == a.id and mob.taunt_left > 0.0, "Provocar puxa o monstro de verdade")
	sim._deal_damage(b, mob, 500, false, false, "physical")
	check(mob.aggro_target == a.id, "preso na provocação ignora dano maior")
	check(sim.top_damager(mob, a) == b, "provocar não rouba o abate: conta o dano real")
	sim.party_invite(a, b)
	sim.party_accept(b)
	var mob2 = sim.spawn_monster(gd.monsters["wolf"], "city_aldara", at + Vector3(1, 0, 2))
	mob2.brain = null
	mob2.stats.max_hp = 1000.0
	mob2.hp = 1000.0
	sim._deal_damage(a, mob2, 300, false, false, "physical")
	sim._deal_damage(b, mob2, 300, false, false, "physical")
	sim._deal_damage(o, mob2, 400, false, false, "physical")
	check(sim.top_damager(mob2, o) in [a, b], "grupo soma dano contra quem está de fora (último golpe não rouba)")
	var gold_a: int = a.gold
	var gold_b: int = b.gold
	var loots: int = m["loot"].size()
	check(sim.kill_sharers(a, mob2).size() == 2, "dois dividem o abate")
	var owners := {}
	for i in range(4):
		var l := {"owner": sim._next_looter(a, [a, b]).id}
		owners[l["owner"]] = true
	check(owners.size() == 2, "saque do grupo gira entre os membros")
	sim._split_gold([a, b], 100)
	check(a.gold == gold_a + 50 and b.gold == gold_b + 50, "ouro do grupo é dividido")
	check(m["loot"].size() == loots, "ouro de grupo não vira pilha no chão")
	var pile := {"owner": a.id, "free_at": sim.time + 5.0}
	check(sim.can_loot(a, pile) and not sim.can_loot(o, pile), "item com dono: estranho não pega")
	pile["free_at"] = sim.time - 1.0
	check(sim.can_loot(o, pile), "depois do tempo o item fica livre")
	for x in [mob, mob2, a, b, o]:
		sim.despawn(x)

## Regressões da revisão: cada uma passou batida pelos testes antes.
func _check_review_fixes(gd, sim) -> void:
	var m: Dictionary = sim.maps["city_aldara"]
	var at := Vector3(70, 0, 40)
	# monstro encara o alvo ao lançar: ficar nas costas não anula cone nem projétil
	var boss = sim.spawn_monster(gd.monsters["dragonling"], "city_aldara", at)
	boss.brain = null
	boss.facing = 0.0
	var behind: Vector3 = at - boss.forward() * 3.0
	check(sim.try_cast(boss, 0, behind, m), "monstro lança a skill")
	check(boss.forward().dot((behind - at).normalized()) > 0.95, "monstro vira para o alvo ao lançar")
	sim.despawn(boss)
	# efeitos de evolução chegam no projétil
	var bis = sim.spawn_bot(gd.classes["bishop"], "RF", "city_aldara", at, 20)
	bis.talents["bis_t_smite"] = true
	var shots: int = m["projectiles"].size()
	sim._apply_skill(bis, sim.resolve_skill(bis, gd.skills["bis_smite"]), m)
	check(m["projectiles"].size() == shots + 1 and m["projectiles"][-1].effects.has("stun"), "evolução de efeito funciona em projétil")
	m["projectiles"].pop_back()
	# buff pessoal não vaza e provocar não fortalece o grupo
	var pal = sim.spawn_bot(gd.classes["paladin"], "RF2", "city_aldara", at + Vector3(1, 0, 0), 20)
	sim.party_invite(bis, pal)
	sim.party_accept(pal)
	pal.buffs.clear()
	var ber = sim.spawn_bot(gd.classes["berserker"], "RF3", "city_aldara", at + Vector3(0, 0, 1), 20)
	sim.party_invite(bis, ber)
	sim.party_accept(ber)
	sim._apply_skill(ber, gd.skills["ber_fury"], m)
	check(not ber.buffs.is_empty() and pal.buffs.is_empty(), "Fúria só em quem lança")
	ber.buffs.clear()
	sim._apply_skill(pal, gd.skills["pal_taunt"], m)
	check(not pal.buffs.is_empty() and ber.buffs.is_empty(), "buff de Provocar é só de quem provoca")
	for id in gd.skills:
		var s: SkillDef = gd.skills[id]
		if s.target == SkillDef.Target.SELF and s.kind == SkillDef.Kind.BUFF and s.radius > 0.0:
			check(s.description.contains("aliad") or s.effects.has("taunt") or s.effects.has("boss_summon") or s.effects.has("stun") or id.begins_with("mob_"), "%s: buff em área avisa que pega aliados" % id)
	# invocação: mantém o ataque depois de buff e o dano conta para o dono mesmo depois de expirar
	var nec = sim.spawn_bot(gd.classes["necromancer"], "RF4", "city_aldara", at + Vector3(0, 0, 4), 20)
	var sm = sim.spawn_summon(nec, gd.monsters["skeleton_minion"], at + Vector3(0, 0, 5), 20.0)
	var patk: float = sm.stats.patk
	sm.recompute_stats()
	check(sm.stats.patk == patk, "invocação mantém o ataque depois de recompute")
	var other = sim.spawn_bot(gd.classes["ranger"], "RF5", "city_aldara", at + Vector3(0, 0, 6), 20)
	var mob = sim.spawn_monster(gd.monsters["wolf"], "city_aldara", at + Vector3(0, 0, 7))
	mob.brain = null
	mob.stats.max_hp = 100000.0
	mob.hp = 100000.0
	sim._deal_damage(sm, mob, 1000, false, false, "physical")
	sim._deal_damage(other, mob, 5, false, false, "physical")
	sim.despawn(sm)
	check(sim.top_damager(mob, other) == nec, "dano de invocação expirada conta para o dono")
	# saque gira pela ordem do grupo, mesmo se o crédito alterna; ouro não some nem nasce
	var got := {}
	for i in range(4):
		var credit = bis if i % 2 == 0 else ber
		var who = sim._next_looter(credit, [credit, bis if credit == ber else ber])
		got[who.id] = int(got.get(who.id, 0)) + 1
	check(got.size() == 2 and got.values()[0] == 2, "saque alterna mesmo com crédito alternando")
	var g1: int = bis.gold
	var g2: int = ber.gold
	sim._split_gold([bis, ber], 5)
	check(bis.gold + ber.gold == g1 + g2 + 5, "dividir ouro não cria nem perde")
	sim._split_gold([bis, ber], 1)
	check(bis.gold + ber.gold == g1 + g2 + 6, "1 de ouro entre dois continua 1")
	# chefe: alcance de skill SELF é o raio dela; lacaio não rola saque; reset limpa maestria
	var mdef: MonsterDef = gd.monsters["bandit_chief"]
	var chief = sim.spawn_monster(mdef, "city_aldara", at + Vector3(30, 0, 0))
	var near = sim.spawn_bot(gd.classes["paladin"], "RF6", "city_aldara", at + Vector3(35.5, 0, 0), 20)
	chief.aggro_target = near.id
	chief.aggro_timer = 5.0
	var slot: int = chief.brain.think(chief, sim, m, 0.05).skill_slot
	check(slot < 0 or chief.skills[slot].target != SkillDef.Target.SELF, "skill em volta do chefe não sai fora do raio")
	chief.mastery["mob_whirl"] = 3
	sim.reset_boss(chief)
	check(chief.mastery.is_empty(), "reset limpa a maestria do chefe")
	for it in gd.items.values():
		if it.is_equipment() and it.slot == ItemDef.Slot.CAPE:
			check(it.armor_style == "cape", "%s aparece no personagem" % it.id)
	for mid in gd.maps:
		for pt in gd.maps[mid].portals:
			if pt.has("gate"):
				check(pt["id"].begins_with("to_") and gd.maps[pt["target_map"]].parent_map != "" and pt["target_map"] != gd.maps[mid].parent_map or pt["target_map"] in ["field_forest", "field_ruins", "elf_city"], "portão %s só na ida" % pt["id"])
	for x in [chief, near, mob, other, nec, ber, pal, bis]:
		sim.despawn(x)

## Regressão: melee parava fora do próprio cone e só acertava quem andava até ele. Sem alvo, monstro não vira para a origem.
func _check_melee_reach(gd, sim) -> void:
	var map_id := "dg_catacumbas_trono"
	var m: Dictionary = sim.maps[map_id]
	for mid in ["wolf", "boar", "bone_captain", "count_vargo", "dragonling", "golem"]:
		var mob = sim.spawn_monster(gd.monsters[mid], map_id, Vector3(0, 0, -20))
		mob.skills.clear()
		var t = sim.spawn_bot(gd.classes["paladin"], "Alvo", map_id, Vector3(5, 0, -20), 30)
		t.brain = null
		t.stats.max_hp = 1000000.0
		t.hp = 1000000.0
		mob.aggro_target = t.id
		for i in range(100):
			mob.aggro_timer = 5.0
			sim.tick(0.05)
		check(t.hp < 1000000.0, "%s acerta alvo parado" % mid)
		sim.despawn(mob)
		sim.despawn(t)
	# ranged recua entre os tiros
	var arch = sim.spawn_monster(gd.monsters["bandit_archer"], map_id, Vector3(0, 0, -20))
	var near = sim.spawn_bot(gd.classes["paladin"], "Perto", map_id, Vector3(1, 0, -20), 30)
	arch.aggro_target = near.id
	arch.aggro_timer = 5.0
	arch.basic_cd = 1.0
	check(arch.brain.think(arch, sim, m, 0.05).move.x < 0.0, "ranged recua de quem encosta")
	arch.home_position = arch.position + Vector3(arch.monster_def.leash_range * 0.8, 0, 0)
	check(arch.brain.think(arch, sim, m, 0.05).move == Vector2.ZERO, "ranged não recua perto do limite do leash")
	# fora do leash o monstro chega em casa, sem ir e vir; quem bateu antes não conta mais
	var wolf = sim.spawn_monster(gd.monsters["wolf"], map_id, Vector3(0, 0, -20))
	wolf.position = wolf.home_position + Vector3(wolf.monster_def.leash_range + 1.0, 0, 0)
	near.position = wolf.position + Vector3(2, 0, 0)
	wolf.aggro_target = near.id
	wolf.damage_by[near.id] = 10.0
	wolf.hp -= 20.0
	wolf.brain.think(wolf, sim, m, 0.05)
	wolf.position = wolf.home_position + Vector3(wolf.monster_def.leash_range - 1.0, 0, 0)
	wolf.brain.think(wolf, sim, m, 0.05)
	check(wolf.brain.state == MonsterBrain.S.RETURN and wolf.aggro_target == -1, "voltando para casa não retoma o alvo")
	wolf.position = wolf.home_position
	wolf.brain.think(wolf, sim, m, 0.05)
	check(wolf.brain.state == MonsterBrain.S.IDLE and wolf.damage_by.is_empty(), "chegou em casa: luta encerrada")
	wolf.position = wolf.home_position + Vector3(10, 0, 0)
	wolf.brain.state = MonsterBrain.S.RETURN
	wolf.brain.think(wolf, sim, m, MonsterBrain.RETURN_LIMIT + 1.0)
	check(wolf.position == wolf.home_position, "preso voltando reaparece em casa")
	# alvo que morre não apaga o dano de quem segue lutando
	var gol = sim.spawn_monster(gd.monsters["golem"], map_id, Vector3(0, 0, -20))
	var tank = sim.spawn_bot(gd.classes["paladin"], "T", map_id, Vector3(2, 0, -20), 30)
	var dps = sim.spawn_bot(gd.classes["ranger"], "D", map_id, Vector3(4, 0, -20), 30)
	gol.brain = null
	gol.stats.max_hp = 100000.0
	gol.hp = 100000.0
	sim._deal_damage(tank, gol, 40, false, false, "physical")
	sim._deal_damage(dps, gol, 490, false, false, "physical")
	gol.aggro_target = tank.id
	tank.hp = 0.0
	sim._kill(tank, gol)
	sim._update_entity(gol, m, 0.05)
	check(gol.damage_by.has(dps.id), "alvo morto não apaga o dano dos outros")
	sim._update_entity(gol, m, Balance.AGGRO_LOSE_TIME + 1.0)
	check(gol.damage_by.is_empty(), "sem levar golpe a luta expira e o crédito antigo some")
	for x in [arch, near, wolf, gol, tank, dps]:
		sim.despawn(x)
	var w = sim.spawn_monster(gd.monsters["spider"], map_id, Vector3(4, 0, -20))
	w.facing = 1.0
	w.brain.state = MonsterBrain.S.WANDER
	w.brain.timer = 0.0
	var before: Vector3 = w.forward()
	var cmd: InputCommand = w.brain.think(w, sim, m, 0.05)
	check(cmd.aim.is_equal_approx(w.position + before), "fim de passeio não vira para a origem do mundo")
	sim.despawn(w)

## Regressão: skills SELF de dano nunca acertavam ninguém (voltavam antes de escolher alvo).
func _check_self_aoe(gd, sim) -> void:
	var m: Dictionary = sim.maps["city_aldara"]
	var at := Vector3(70, 0, 40)
	var c = sim.spawn_bot(gd.classes["berserker"], "AoE", "city_aldara", at, 20)
	var near = sim.spawn_monster(gd.monsters["wolf"], "city_aldara", at + Vector3(1.5, 0, 0))
	var far = sim.spawn_monster(gd.monsters["wolf"], "city_aldara", at + Vector3(15, 0, 0))
	near.brain = null
	far.brain = null
	near.stats.max_hp = 100000.0     # o golpe não pode matar: o resto do teste ainda bate nele
	near.hp = near.stats.max_hp
	var hp: float = c.hp
	sim._apply_skill(c, gd.skills["ber_whirlwind"], m)
	check(near.hp < near.stats.max_hp, "Redemoinho acerta quem está em volta")
	check(far.hp == far.stats.max_hp and c.hp == hp, "e não acerta longe nem o próprio lançador")
	near.hp = near.stats.max_hp
	near.buffs.clear()
	var smoke: SkillDef = gd.skills["ass_smoke"]
	var a = sim.spawn_bot(gd.classes["assassin"], "AoE2", "city_aldara", at, 20)
	sim._apply_skill(a, smoke, m)
	check(near.has_debuff("slow") and near.buffs.is_empty(), "efeito de área vai no inimigo, buff não")
	check(not a.buffs.is_empty(), "buff da skill fica com quem lançou")
	# Murchar corta a cura
	a.debuffs.append({"kind": "wither", "remaining": 5.0, "pct": 50.0})
	a.hp = 10.0
	sim._heal(a, a, 100)
	check(a.hp == 60.0, "Murchar corta 50%% da cura (ficou %.0f)" % a.hp)
	for x in [c, a, near, far]:
		sim.despawn(x)

## Rotação de skills, fases, lacaios, fúria e reset depois de um wipe.
## Dungeon é subterrânea: sem céu, névoa densa; o mundo aberto continua com céu.
func _check_dungeon_mood(gd) -> void:
	for mid in MapsCatalog.DUNGEON_DEFS:
		check(MapBuilder.is_dungeon(gd.maps[mid]), "%s conta como dungeon" % mid)
	check(not MapBuilder.is_dungeon(gd.maps["city_aldara"]), "Aldara não é dungeon")
	var dg: WorldEnvironment = MapBuilder._environment(gd.maps["dg_gruta"])
	var out: WorldEnvironment = MapBuilder._environment(gd.maps["city_aldara"])
	check(dg.environment.background_mode == Environment.BG_COLOR and dg.environment.fog_density > out.environment.fog_density * 4.0, "dungeon sem céu e com névoa densa")
	check(out.environment.background_mode == Environment.BG_SKY, "zona aberta mantém o céu")
	dg.free()
	out.free()

## Árvore de skills: linhas com folga (o passivo entre duas skills não encosta nelas) e maestria longe da skill.
func _check_tree_spacing() -> void:
	var w = load("res://game/ui/windows.gd")
	var node_px: Dictionary = w.NODE_PX
	var row_px: float = TreeCatalog.ROW * float(w.TREE_ROW_PX)
	var gap := row_px * 0.5 - (float(node_px["skill"]) + float(node_px["stat"])) * 0.5
	check(gap >= 12.0, "árvore: passivo a %.0f px das skills (mínimo 12)" % gap)
	var kx := (float(w.TREE_PX.x) - 34.0) / (4 * TreeCatalog.PANE_W + 3 * TreeCatalog.PANE_GAP)      # pior caso: 4 painéis
	var side := TreeCatalog.SIDE * kx - (float(node_px["skill"]) + float(node_px["mastery"])) * 0.5
	check(side >= 12.0, "árvore: maestria a %.0f px da skill (mínimo 12)" % side)
	# todo passivo da árvore tem rótulo curto e cor (o que dá aparece ao lado da bolinha)
	var bad: Array = []
	for cid in GameData.trees:
		var nodes: Dictionary = GameData.trees[cid]["nodes"]
		for nid in nodes:
			if nodes[nid]["kind"] == "stat":
				for k in nodes[nid]["stats"]:
					if not TreeCatalog.STAT_SHORT.has(k) or not TreeCatalog.STAT_FAMILY.has(k):
						bad.append(k)
	check(bad.is_empty(), "árvore: passivos com rótulo e cor (%s)" % str(bad))
	# toda evolução diz o que muda embaixo do losango (rótulo lido dos mods)
	var mute: Array = []
	for tid in GameData.talents:
		if TreeCatalog.talent_tags(GameData.talents[tid]).is_empty():
			mute.append(tid)
	check(mute.is_empty(), "árvore: evoluções com rótulo (%s)" % str(mute))

## Todo item tem ícone: arte própria ou a pintada (art_<id>.png, gerada por tools/icons/item_icons.tscn), e as molduras por raridade.
func _check_item_icons(gd) -> void:
	var missing: Array = []
	for iid in gd.items:
		var it: ItemDef = gd.items[iid]
		if UiKit.item_texture(it) == null:
			missing.append(iid)
	check(missing.is_empty(), "todo item tem ícone (%d sem: %s; rode tools/icons/item_icons.tscn)" % [missing.size(), str(missing.slice(0, 5))])
	for r in range(5):
		check(ResourceLoader.exists("res://assets/icons/slot_r%d.png" % r), "moldura da raridade %d" % r)
	check(ResourceLoader.exists("res://assets/icons/art_gold.png"), "arte das moedas (baú de ouro)")
	var keys := {}
	for iid in gd.items:
		var it: ItemDef = gd.items[iid]
		if it.icon == "":
			var k: String = ItemIcons.art_key(it)
			keys[k] = true
	var painter := ItemIcons.new()
	for k in keys:
		check(painter.has_method("_a_" + k), "arte de item '%s' existe" % k)
	painter.free()
	var ic: Control = UiKit.item_icon(gd.items["potion_hp_s"], 32)
	check(ic is TextureRect and ic.get_child_count() == 1, "item sem arte própria: arte pintada sobre a moldura")
	ic.free()
	for iid in gd.items:                          # arte própria (foto do conjunto) também vai na moldura da raridade
		var own: ItemDef = gd.items[iid]
		if own.icon != "" and UiKit.icon_texture(own.icon) != null:
			var oc: Control = UiKit.item_icon(own, 32)
			check(oc is TextureRect and oc.get_child_count() == 1 and (oc as TextureRect).texture == UiKit.icon_texture("slot_r%d" % clampi(own.rarity, 0, 4)),
				"%s: foto do conjunto sobre a moldura da raridade" % iid)
			oc.free()
			break
	var chest := LootChest.make("potion_hp_s")
	check(chest.get_node_or_null("Icon") is Sprite3D, "baú no chão mostra a arte do item")
	chest.free()

## Barraca pinta a lona com a cor do acampamento (antes só o modelo de reserva recebia a cor).
func _check_tent_cloth() -> void:
	var c := Color(0.2, 0.4, 0.8)
	var inst: Node3D = MapBuilder._prop_model("tent", Vector3(3, 2.2, 3), {"color": c})
	var found := false
	if inst:
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			for i in range((mi as MeshInstance3D).get_surface_override_material_count()):
				var mat := (mi as MeshInstance3D).get_surface_override_material(i) as ShaderMaterial
				if mat and (mat.get_shader_parameter("albedo") as Color).is_equal_approx(MapBuilder.tent_cloth(c, false)):
					found = true
		inst.free()
	check(found, "barraca usa a cor da lona do acampamento")

func _check_boss_kit(gd, sim) -> void:
	var m: Dictionary = sim.maps["city_aldara"]
	var at := Vector3(70, 0, 40)
	var mdef: MonsterDef = gd.monsters["slime_king"].duplicate()
	mdef.skill_ids = ["mob_charge", "mob_whirl"] as Array[String]
	mdef.phases = [{"hp": 0.66, "skills": ["mob_firebreath"], "summon": {"id": "skeleton_minion", "count": 2, "max": 2}}, {"hp": 0.3, "enrage": 1.5}]
	var boss = sim.spawn_monster(mdef, "city_aldara", at)
	var atk: float = boss.stats.patk
	var p = sim.spawn_bot(gd.classes["paladin"], "BK", "city_aldara", at + Vector3(1.5, 0, 0), 10)
	boss.aggro_target = p.id
	boss.aggro_timer = 5.0
	var cmd: InputCommand = boss.brain.think(boss, sim, m, 0.05)
	check(cmd.skill_slot == 1, "monstro usa a skill mais nova pronta")
	boss.brain.skill_timer = 0.0
	boss.cooldowns["mob_whirl"] = 5.0
	cmd = boss.brain.think(boss, sim, m, 0.05)
	check(cmd.skill_slot == 0, "em recarga passa para a outra skill (saiu %d)" % cmd.skill_slot)
	boss.hp = boss.stats.max_hp * 0.6
	sim._update_boss(boss)
	var adds: Array = m["entities"].filter(func(o): return o.boss_id == boss.id)
	check(boss.phase == 1 and adds.size() == 2, "fase 2 chama lacaios (%d)" % adds.size())
	check(adds[0].kind == SimEntity.Kind.MONSTER and adds[0].is_hostile_to(p), "lacaio é inimigo do jogador")
	check(boss.skills.size() == 3, "fase ganha skill nova")
	sim._update_boss(boss)
	check(m["entities"].filter(func(o): return o.boss_id == boss.id).size() == 2, "fase não repete")
	boss.hp = boss.stats.max_hp * 0.2
	sim._update_boss(boss)
	check(boss.phase == 2 and is_equal_approx(boss.stats.patk, atk * 1.5), "fúria multiplica o ataque do monstro")
	sim.reset_boss(boss)
	check(boss.hp == boss.stats.max_hp and boss.phase == 0 and boss.skills.size() == 2 and boss.stats.patk == atk, "reset volta ao estado inicial")
	for a in adds:
		sim._update_entity(a, m, 0.05)
	check(m["entities"].filter(func(o): return o.boss_id == boss.id).is_empty(), "reset limpa os lacaios")
	# wipe: sem alvo por perto, chefe ferido volta e reseta sozinho
	boss.hp = boss.stats.max_hp * 0.5
	boss.phase = 1
	boss.aggro_target = -1
	mdef.aggro_range = 0.0        # bots do mundo passando por perto não podem virar alvo
	p.position = at + Vector3(40, 0, 0)
	boss.position = at
	boss.combat_timer = 3.0
	var hurt: float = boss.hp
	boss.brain.think(boss, sim, m, 0.05)
	check(boss.hp == hurt and boss.phase == 1, "em combate sem alvo por perto (tiro de longe) chefe não reseta")
	boss.combat_timer = 0.0
	boss.brain.think(boss, sim, m, 0.05)
	check(boss.hp == boss.stats.max_hp and boss.phase == 0, "wipe: chefe reseta sem depender de leash")
	sim._deal_damage(p, boss, int(boss.stats.max_hp), false, false, "physical")
	check(p.bosses_killed.has(mdef.id), "abate de chefe fica registrado")
	sim.despawn(boss)
	sim.despawn(p)
	# todo chefe de dungeon tem fases, e os lacaios delas não dão XP nem loot
	for bid in ["slime_king", "spider_queen", "crypt_lord", "bone_captain", "wailing_widow", "count_vargo", "elf_king"]:
		var bd: MonsterDef = gd.monsters[bid]
		check(bd.phases.size() >= 1, "%s tem fases" % bid)
		for ph in bd.phases:
			for sid in ph.get("skills", []):
				check(gd.skills.has(sid), "%s: skill de fase %s existe" % [bid, sid])
			if ph.has("summon"):
				var ad: MonsterDef = gd.monsters.get(ph["summon"]["id"])
				check(ad != null and ad.xp == 0 and ad.loot_table == "" and not ad.is_boss, "%s: lacaio %s sem XP/loot" % [bid, ph["summon"]["id"]])
				check(ad != null and absi(ad.level - bd.level) <= 4, "%s: lacaio do nível do chefe" % bid)

## Cadeia inteira alcançável, portões ligados a quests reais e recursos novos de quest.
func _check_progression(gd, sim) -> void:
	for qid in gd.quests:
		var q: QuestDef = gd.quests[qid]
		for pid in [q.prereq_quest] + Array(q.prereq_all):
			check(pid == "" or gd.quests.has(pid), "%s: pré-requisito %s existe" % [qid, pid])
		for item_id in q.reward_items:
			check(gd.items.has(item_id), "%s: recompensa %s existe" % [qid, item_id])
		if q.reward_gear_tier >= 0:
			check(q.level_req >= Balance.COMMON_TIER_LEVELS[q.reward_gear_tier], "%s: dá para vestir a peça da recompensa no nível da quest" % qid)
		if q.type == QuestDef.Type.TALK:
			check(q.turnin() == q.target_id, "%s: conversa e entrega no mesmo NPC" % qid)
	var done := {}
	var moved := true
	while moved:
		moved = false
		for qid in gd.quests:
			var q: QuestDef = gd.quests[qid]
			if not done.has(qid) and (q.prereq_quest == "" or done.has(q.prereq_quest)) and q.prereq_all.all(func(x): return done.has(x)):
				done[qid] = true
				moved = true
	check(done.size() == gd.quests.size(), "toda quest é alcançável (%d/%d)" % [done.size(), gd.quests.size()])
	check(gd.quests["q08_forest"].prereq_quest == "c5_report", "Catacumbas ligam Aldara à Floresta")
	check(gd.quests["q11_chief"].prereq_quest == "q10b_nest" and gd.quests["q14_dragon"].prereq_quest == "q13b_crypt", "Ninho e Cripta fazem parte da história")
	for pid in MapsCatalog.PORTAL_GATES:
		var g: Dictionary = MapsCatalog.PORTAL_GATES[pid]
		check(g.get("quest", "") == "" or gd.quests.has(g["quest"]), "portão %s: quest existe" % pid)
		for b in g.get("bosses", []):
			check(gd.monsters.has(b) and gd.monsters[b].is_boss, "portão %s: chefe %s existe" % [pid, b])
		var found := false
		for mid in gd.maps:
			for pt in gd.maps[mid].portals:
				if pt["id"] == pid:
					found = pt.has("gate")
		check(found, "portão %s está num portal de verdade" % pid)
	# o nível pedido pela quest que abre um portão nunca passa do nível do portão seguinte
	check(gd.quests["c5_report"].level_req <= 10, "dá para abrir a Floresta no nível 10")
	# recursos novos
	var e = sim.spawn_bot(gd.classes["ranger"], "QP", "city_aldara", Vector3(70, 0, 40), 12)
	e.quests_completed.clear()
	e.quests_active.clear()
	var reach := QuestDef.new()
	reach.id = "t_reach"
	reach.type = QuestDef.Type.REACH
	reach.target_id = "dg_catacumbas"
	reach.count = 1
	e.quests_active["t_reach"] = 0
	gd.quests["t_reach"] = reach
	QuestSystem.on_position(e)
	check(not QuestSystem.is_complete(e, reach), "REACH: ainda não chegou")
	sim._change_map(e, "dg_catacumbas", Vector3(0, 0, 44))
	QuestSystem.on_position(e)
	check(QuestSystem.is_complete(e, reach), "REACH: chegou ao mapa")
	reach.target_id = "covil"
	e.quests_active["t_reach"] = 0
	sim._change_map(e, "city_aldara", Vector3(-24, 0, -50))
	QuestSystem.on_position(e)
	check(QuestSystem.is_complete(e, reach), "REACH: chegou perto do lugar")
	e.quests_active.erase("t_reach")
	gd.quests.erase("t_reach")
	var bounty: QuestDef = gd.quests["b_wolves"]
	e.level = bounty.level_req - 1
	check(not QuestSystem.can_accept(e, bounty), "recompensa respeita o nível")
	e.level = 12
	QuestSystem.accept(e, bounty)
	e.quests_active["b_wolves"] = bounty.count
	QuestSystem.complete(e, bounty, sim)
	check(QuestSystem.can_accept(e, bounty), "recompensa repetível pode repetir")
	QuestSystem.accept(e, bounty)
	e.quests_active["b_wolves"] = bounty.count
	QuestSystem.complete(e, bounty, sim)
	check(e.quests_completed.count("b_wolves") == 1, "repetir não duplica a lista de concluídas")
	check(QuestSystem.npc_marker(e, "board") != "!", "repetível não acende o marcador do quadro")
	QuestSystem.accept(e, bounty)
	QuestSystem.abandon(e, bounty)
	check(not e.quests_active.has("b_wolves") and QuestSystem.can_accept(e, bounty), "desistir solta a quest")
	var inv_before: int = e.inventory.size()
	var geared: QuestDef = gd.quests["c5_report"]
	e.quests_active["c5_report"] = 1
	QuestSystem.complete(e, geared, sim)
	check(e.inventory.size() == inv_before + 1, "quest com peça entrega equipamento")
	for classid in gd.classes:
		var who = sim.spawn_bot(gd.classes[classid], "GR", "city_aldara", Vector3(70, 0, 40), 12)
		check(QuestSystem.gear_reward(who, geared, sim) != "", "%s recebe peça que pode vestir" % classid)
		sim.despawn(who)
	# save antigo não prende ninguém; selo de chefe continua fechado
	var old = sim.spawn_bot(gd.classes["ranger"], "Old", "city_aldara", Vector3(70, 0, 40), 12)
	sim.grandfather_gates(old, "city_aldara")
	check(old.gates_open.has("to_forest") and not old.gates_open.has("to_ruins"), "save antigo: abre o que o nível alcança")
	check(not old.gates_open.has("to_dg_catacumbas_trono"), "save antigo não pula o selo")
	old.gates_open.clear()
	old.level = 5
	sim.grandfather_gates(old, "dg_cripta")
	check(old.gates_open.has("to_ruins"), "save antigo dentro das Ruínas continua com acesso")
	sim.despawn(old)
	sim.despawn(e)

## Arco inteiro das Catacumbas como o jogador faz: cada portão abre na hora certa. Depois, um save antigo de verdade.
func _check_arc(gd, sim, save) -> void:
	var p = sim.spawn_character(SimEntity.Kind.PLAYER, gd.classes["paladin"], "Arc", "city_aldara", Vector3(70, 0, 40))
	p.level = 10
	var gate := func(pid: String) -> Dictionary:
		for mid in gd.maps:
			for pt in gd.maps[mid].portals:
				if pt["id"] == pid:
					return pt
		return {}
	var open := func(pid: String) -> bool: return sim.portal_block_reason(p, gate.call(pid)) == ""
	var step := func(qid: String) -> void:
		var q: QuestDef = gd.quests[qid]
		check(QuestSystem.can_accept(p, q), "arco: %s liberada" % qid)
		QuestSystem.accept(p, q)
		match q.type:
			QuestDef.Type.KILL:
				QuestSystem.on_kill(p, q.target_id)
			QuestDef.Type.TALK:
				QuestSystem.on_talk(p, q.target_id)
			QuestDef.Type.REACH:
				sim._change_map(p, q.target_id, Vector3(0, 0, 44))
				QuestSystem.on_position(p)
		check(QuestSystem.is_complete(p, q), "arco: %s completa" % qid)
		QuestSystem.complete(p, q, sim)
	check(not open.call("to_dg_catacumbas") and not open.call("to_forest"), "antes do arco: Catacumbas e Floresta fechadas")
	p.quests_completed.append("q07_king")
	step.call("c1_digging")
	check(open.call("to_dg_catacumbas"), "c1 abre as Catacumbas")
	step.call("c2_descent")
	step.call("c3_captain")
	p.bosses_killed["bone_captain"] = true
	check(not QuestSystem.can_accept(p, gd.quests["c5_report"]), "um guardião só não fecha o arco")
	check(not open.call("to_dg_catacumbas_trono"), "selo fechado com um guardião vivo")
	step.call("c4_widow")
	p.bosses_killed["wailing_widow"] = true
	check(open.call("to_dg_catacumbas_trono"), "os dois guardiões abrem o selo")
	check(not open.call("to_forest"), "Floresta espera o aviso à Capitã")
	step.call("c5_report")
	check(open.call("to_forest"), "c5 abre a Floresta")
	check(QuestSystem.can_accept(p, gd.quests["q08_forest"]), "arco continua na Floresta")
	p.level = 11
	step.call("c6_count")
	sim.despawn(p)
	var old = sim.spawn_character(SimEntity.Kind.PLAYER, gd.classes["ranger"], "Old", "city_aldara", Vector3(70, 0, 40))
	save.apply_to(old, {"level": 22, "map": "field_ruins", "quests_completed": ["q01_welcome"]})
	check(old.gates_open.has("to_forest") and old.gates_open.has("to_ruins"), "save sem versão: nível 22 não fica preso")
	check(not old.gates_open.has("to_dg_catacumbas_trono"), "save sem versão não pula o selo")
	var fresh = sim.spawn_character(SimEntity.Kind.PLAYER, gd.classes["ranger"], "New", "city_aldara", Vector3(70, 0, 40))
	save.apply_to(fresh, {"level": 5, "save_version": 2, "gates_open": ["to_forest"], "bosses_killed": ["bone_captain"]})
	check(fresh.gates_open.has("to_forest") and fresh.bosses_killed.has("bone_captain") and not fresh.gates_open.has("to_ruins"), "save novo guarda portões e chefes")
	sim.despawn(old)
	sim.despawn(fresh)

## Toda build tem identidade: evolução própria, 6+ skills próprias e arma lendária do atributo dela.
func _check_build_depth(gd, sim) -> void:
	for cid in gd.classes:
		var cls: ClassDef = gd.classes[cid]
		for b in cls.builds:
			var own := 0
			for sid in b["skills"]:
				own += 1 if gd.skills[sid].build == b["id"] else 0
			check(own >= 6, "%s/%s: 6+ skills próprias (%d)" % [cid, b["id"], own])
			var has_talent := false
			for t in gd.talents_for_class(cid):
				if t.skill_id != TalentDef.DASH and gd.skills.has(t.skill_id) and gd.skills[t.skill_id].build == b["id"]:
					has_talent = true
			check(has_talent or _dash_build(b), "%s/%s: evolução própria" % [cid, b["id"]])
			var wpn: ItemDef = gd.items["leg_%s_%s_%d_weapon" % [cid, b["id"], Balance.LEGENDARY_LEVELS[-1]]]
			check(wpn.attributes.has(b["attr"]), "%s/%s: arma lendária dá %s" % [cid, b["id"], b["attr"]])
			if b["stat"] == "matk_pct":
				check(wpn.matk > 0.0, "%s/%s: arma lendária tem MATK" % [cid, b["id"]])
	var e = sim.spawn_bot(gd.classes["ranger"], "Leg", "city_aldara", Vector3(70, 0, 40), 30)
	var seen := {}
	for i in range(200):
		var id: String = sim.pick_legendary(e, 30)
		seen[id.get_slice("_", 2)] = true
	check(seen.has("cacador") and seen.has("atirador"), "lendário favorece qualquer build da arma (%s)" % str(seen.keys()))
	sim.despawn(e)

## Paladino Guardião evolui o dash (exige escudo): é a evolução própria da build.
func _dash_build(b: Dictionary) -> bool:
	return b["id"] == "guardiao"

## Portões: bloqueiam só o jogador, pedem nível + quest + chefes e ficam abertos depois da primeira vez.
func _check_portal_gates() -> void:
	var sim = Sim
	var e := SimEntity.new()
	e.kind = SimEntity.Kind.PLAYER
	var pt := {"id": "t_gate", "label": "Teste", "gate": {"level": 10, "quest": "q_x", "bosses": ["b1", "b2"], "text": "fechado"}}
	check(sim.portal_block_reason(e, {"id": "livre", "label": "x"}) == "", "portal sem portão não bloqueia")
	check(sim.portal_block_reason(e, pt).contains("nível 10"), "portão pede nível")
	e.level = 10
	check(sim.portal_block_reason(e, pt) == "fechado", "portão pede a quest")
	e.quests_completed.append("q_x")
	e.bosses_killed["b1"] = true
	check(sim.portal_block_reason(e, pt) == "fechado", "selo pede todos os chefes")
	e.bosses_killed["b2"] = true
	check(sim.portal_block_reason(e, pt) == "", "tudo feito: abre")
	e.quests_completed.clear()
	e.level = 1
	check(sim.portal_block_reason(e, pt) == "", "portão aberto continua aberto")
	var bot := SimEntity.new()
	bot.kind = SimEntity.Kind.BOT
	check(sim.portal_block_reason(bot, pt) == "", "bot não fica preso em portão")

func _check_water(gd, sim) -> void:
	for mid in ["city_aldara", "field_forest", "field_ruins", "elf_city"]:
		var def: MapDef = gd.maps[mid]
		if not sim.maps.has(mid):
			sim.load_map(def)
		var m: Dictionary = sim.maps[mid]
		var bridges: Array = m["bridges"]
		check(bridges.size() >= 1, "%s: estrada cruza o rio por ponte (%d)" % [mid, bridges.size()])
		for br in bridges:
			check(sim.is_walkable(Vector3(br["pos"].x, 0, br["pos"].y), def, 0.45), "%s: ponte andável em %s" % [mid, br["pos"]])
		for w in def.water:
			if w["kind"] == "lake":
				var c: Vector2 = w["pos"]
				check(not sim.is_walkable(Vector3(c.x, 0, c.y), def), "%s: meio do lago bloqueia" % mid)
				check(not sim.is_walkable(Vector3(c.x + float(w["r"]) - 1.5, 0, c.y), def), "%s: borda do lago bloqueia" % mid)
				continue
			# trecho do rio longe das pontes: o meio bloqueia; o bot atravessa pela ponte
			var pts: PackedVector2Array = w["pts"]
			var blocked := 0
			var tested := 0
			var picks: Array = []
			for i in range(2, pts.size() - 2):
				var far := true
				for br in bridges:
					if br["pos"].distance_to(pts[i]) < 20.0:
						far = false
				if not far or pts[i].length() > 95.0:
					continue
				tested += 1
				if not sim.is_walkable(Vector3(pts[i].x, 0, pts[i].y), def):
					blocked += 1
				picks.append(i)
			check(tested > 0 and blocked == tested, "%s: rio bloqueia em todo trecho fora das pontes (%d/%d)" % [mid, blocked, tested])
			# sem bolsões: nada sólido fecha a margem dentro do vale (nature.clear_banks)
			for ob in def.obstacles:
				var opos := Vector2(ob["pos"].x, ob["pos"].z)
				if ob.get("kind", "") in ["tree", "pine", "dead_tree", "rock", "stump", "log"] and ob.get("solid", true) and opos.length() < 100.0:
					var gap: float = _dist_poly(opos, pts) - float(w["w"]) * 0.5 - maxf(ob["size"].x, ob["size"].z) * 0.5
					check(gap >= 1.9, "%s: %s em %s fecha a margem do rio (corredor de %.1f m)" % [mid, ob["kind"], opos, gap])
			# três pontos do rio (começo, meio, fim do trecho), nos dois sentidos
			var crossed := 0
			for n in range(3):
				if picks.is_empty():
					break
				var pick: int = picks[int((picks.size() - 1) * n / 2.0)]
				var t := (pts[pick + 1] - pts[pick - 1]).normalized()
				var nrm := Vector2(-t.y, t.x)
				var ends: Array = []
				for sgn in [1.0, -1.0]:
					var q := Vector3.INF
					for off in [5.0, 7.0, 9.0, 12.0, 15.0]:
						var c: Vector2 = pts[pick] + nrm * sgn * (float(w["w"]) * 0.5 + off)
						if sim.is_walkable(Vector3(c.x, 0, c.y), def, 0.6):
							q = Vector3(c.x, 0, c.y)
							break
					ends.append(q)
				if ends[0] == Vector3.INF or ends[1] == Vector3.INF:
					continue
				for dirn in range(2):
					_cross_river(gd, sim, mid, def, m, bridges, ends[dirn], ends[1 - dirn])
					crossed += 1
			check(crossed >= 2, "%s: teste de travessia achou margens andáveis (%d travessias)" % [mid, crossed])

func _cross_river(gd, sim, mid: String, def: MapDef, m: Dictionary, bridges: Array, a: Vector3, b: Vector3) -> void:
	var bot = sim.spawn_bot(gd.classes["ranger"], "Nadador", mid, a, 5)
	var brain = bot.brain
	brain.cur_sim = sim
	brain.cur_def = def
	var reached := false
	var wet := Vector3.INF
	for tick in range(60 * 120):
		var cmd := InputCommand.new()
		cmd.move = brain._steer(bot, b, 1.0 / 60.0)
		cmd.aim = b
		sim._apply_command(bot, cmd, m, 1.0 / 60.0)
		if wet == Vector3.INF:
			for w2 in def.water:
				if w2["kind"] == "river" and _dist_poly(Vector2(bot.position.x, bot.position.z), w2["pts"]) < float(w2["w"]) * 0.5 - 1.0:
					var on_br := false
					for br in bridges:
						var rel: Vector2 = Vector2(bot.position.x, bot.position.z) - br["pos"]
						if absf(rel.dot(br["dir"])) < 3.2 and rel.length() < float(br["w"]):
							on_br = true
					if not on_br:
						wet = bot.position
		if bot.position.distance_to(b) < 2.0:
			reached = true
			break
	check(reached, "%s: bot atravessa o rio pela ponte de %s até %s (parou em %s)" % [mid, a, b, bot.position])
	check(wet == Vector3.INF, "%s: bot nunca anda dentro do rio (entrou em %s, indo de %s a %s)" % [mid, wet, a, b])
	sim.despawn(bot)

func _dist_poly(p: Vector2, pts: PackedVector2Array) -> float:
	var best := INF
	for i in range(pts.size() - 1):
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])))
	return best


# ---------------------------------------------------------------------------
# natureza fora da vila: nada de "arvorezinha", toda prop tem modelo, montanha com patamares
# ---------------------------------------------------------------------------
func _check_outdoor(gd) -> void:
	for mid in ["city_aldara", "field_forest", "field_ruins", "elf_city"]:
		var def: MapDef = gd.maps[mid]
		var small := 0
		var kinds := {}
		var ledge := 0
		var low := 0
		for ob in def.obstacles:
			var k: String = ob["kind"]
			kinds[k] = int(kinds.get(k, 0)) + 1
			var sz: Vector3 = ob["size"]
			if k in ["tree", "pine", "dead_tree"] and sz.y < 3.6:
				small += 1
			if ob["pos"].y > 0.5:
				ledge += 1
			if ob["pos"].y < 0.0:
				low += 1
		check(small == 0, "%s: nenhuma árvore abaixo de 3,6 m (%d)" % [mid, small])
		check(ledge >= 60 and low == 0, "%s: árvores/pedras nos patamares da montanha (%d, %d abaixo do chão)" % [mid, ledge, low])
		for k in ["bush", "reeds", "stump"]:
			check(int(kinds.get(k, 0)) >= 5, "%s: tem %s (%d)" % [mid, k, int(kinds.get(k, 0))])
		for k in kinds:
			if k in ["cliff", "hill", "water"]:
				continue
			check(ResourceLoader.exists("res://assets/models/prop_%s.glb" % k), "%s: prop_%s.glb existe" % [mid, k])
	check(int(_count_kind(gd.maps["field_ruins"], "tree")) == 0, "ruínas: só árvores secas")
	check(int(_count_kind(gd.maps["field_forest"], "pine")) > 100, "floresta: pinheiros misturados")

func _count_kind(def: MapDef, kind: String) -> int:
	var n := 0
	for ob in def.obstacles:
		if ob["kind"] == kind:
			n += 1
	return n


## Sentinelas do povoado (NPC com `fighter`) e investidas (RaidSystem) num mundo só da Floresta, com rota de teste.
## Uma sim à parte (WorldSim.new): o relógio da investida e os ticks não mexem no mundo dos outros testes.
func _check_raids(gd, sim) -> void:
	var ws := WorldSim.new()
	ws.rng.seed = 7
	var def: MapDef = gd.maps["field_forest"].duplicate()
	var target: Vector3 = def.raid.get("target", def.town_center) if not def.raid.is_empty() else Vector3.ZERO
	var from: Vector3 = def.raid.get("from", Vector3(10, 0, -70)) if not def.raid.is_empty() else Vector3(10, 0, -70)
	var route: Array = def.raid.get("route", [Vector3(5, 0, -45), Vector3(2, 0, -25)]) if not def.raid.is_empty() else [Vector3(5, 0, -45), Vector3(2, 0, -25)]
	def.spawners = []                     # só a investida no mapa
	def.raid = {"from": from, "route": route, "target": target, "radius": float(def.raid.get("radius", 17.0)) if not def.raid.is_empty() else 17.0,
		"every": 999.0, "first": 1.0, "jitter": 0.0, "lifetime": 400.0, "waves": [{"mobs": {"elf_raider": 2, "elf_raider_archer": 2}}]}
	ws.load_map(gd.maps[GameData.town_map_id()])
	var m: Dictionary = ws.load_map(def)
	for o in m["entities"].duplicate():
		if o.guard:
			ws.despawn(o)                    # o teste põe as próprias sentinelas
	var plain: Array = m["entities"].filter(func(o): return o.kind == SimEntity.Kind.NPC)
	# relógio parado com o jogador em outro mapa
	ws.player = ws.spawn_player(gd.classes["berserker"], "RT", GameData.town_map_id())
	for i in 120:
		ws.tick(1.0 / 60.0)
	check(RaidSystem.state(m)["ids"].is_empty(), "investida: relógio parado sem o jogador no mapa")
	ws.despawn(ws.player)
	ws.player = null
	var started := []
	var on_raid := func(map_id: String, kind: String): started.append(kind)
	Events.raid_event.connect(on_raid)
	for i in 90:
		ws.tick(1.0 / 60.0)
	var ids: Array = RaidSystem.state(m)["ids"]
	check(ids.size() == 4 and "start" in started, "investida: leva nasce no relógio (%d)" % ids.size())
	var raiders: Array = ids.map(func(id): return ws.entities[id])
	check(raiders.all(func(r): return r.raid_id >= 0 and r.position.distance_to(from) < 6.0), "investida: nasce no portal élfico")
	# marcha até o povoado sem ninguém por perto (sem dormir)
	var t := 0.0
	while t < 90.0 and not "arrived" in started:
		ws.tick(1.0 / 20.0)
		t += 1.0 / 20.0
	check("arrived" in started, "investida: chega ao povoado (%.0f s)" % t)
	check(t >= 5.0, "investida: marcha leva tempo de verdade (%.0f s)" % t)
	# NPC comum nunca é alvo
	for r in raiders:
		check(r.aggro_target < 0 or not ws.entities.has(r.aggro_target) or ws.entities[r.aggro_target].kind != SimEntity.Kind.NPC, "investida: NPC comum não vira alvo")
	check(plain.all(func(o): return o.hp == 1.0 and not raiders[0].is_hostile_to(o)), "investida: NPC comum intocável")
	# sentinela: entra na lista de alvos, apanha e revida
	var gw: SimEntity = ws._spawn_npc({"id": "t_guard", "name": "Sentinela", "pos": target + Vector3(2, 0, 0), "role": "guard", "fighter": "guard_warrior",
		"gear": ["sword_iron"]}, def.id)
	check(gw.guard and gw.stats.max_hp > 100.0 and gw.brain is GuardBrain, "sentinela: NPC com atributos e cérebro de luta")
	check(raiders[0].is_hostile_to(gw) and gw.is_hostile_to(raiders[0]) and not gw.is_hostile_to(plain[0]) if not plain.is_empty() else true, "sentinela: hostil só a monstros")
	var hit_guard := false
	var guard_hit := false
	for i in 30 * 20:
		ws.tick(1.0 / 20.0)
		if gw.hp < gw.stats.max_hp:
			hit_guard = true
		if raiders.any(func(r): return not r.is_alive() or r.hp < r.stats.max_hp):
			guard_hit = true
		if hit_guard and guard_hit:
			break
	check(hit_guard, "sentinela: a investida ataca a sentinela")
	check(guard_hit, "sentinela: revida")
	check(raiders.all(func(r): return r.damage_by.is_empty() or not r.damage_by.has(gw.id)), "sentinela não conta para o abate (XP fica com jogadores)")
	# sentinela caída volta ao posto
	ws._deal_damage(raiders[0], gw, int(gw.hp + 99999), false, false, "physical")
	check(not gw.is_alive(), "sentinela morre")
	for i in int((Balance.GUARD_RESPAWN + 1.0) * 20.0):
		ws.tick(1.0 / 20.0)
	check(gw.is_alive() and gw.hp > gw.stats.max_hp * 0.5 and gw.position.distance_to(gw.home_position) < 20.0, "sentinela renasce no posto")
	ws.despawn(gw)
	for r in raiders:
		ws.despawn(r)
	ws.tick(1.0 / 20.0)
	check("repelled" in started and RaidSystem.state(m)["ids"].is_empty(), "investida: leva toda caída = repelida")
	# luta no caminho: personagem perto da rota puxa a briga; morto, a leva volta a marchar
	started.clear()
	var leva := RaidSystem.start_raid(ws, m)
	var mid_route: Vector3 = route[0]
	var bot: SimEntity = ws.spawn_bot(gd.classes["berserker"], "RTB", def.id, mid_route + Vector3(1.5, 0, 0), 15)
	bot.brain = null                     # parado: só isca
	var engaged := false
	for i in 40 * 20:
		ws.tick(1.0 / 20.0)
		if leva.any(func(id): return ws.entities.has(id) and ws.entities[id].aggro_target == bot.id):
			engaged = true
			break
	check(engaged, "investida: personagem perto da rota puxa a briga")
	ws.despawn(bot)
	t = 0.0
	while t < 90.0 and not "arrived" in started:
		ws.tick(1.0 / 20.0)
		t += 1.0 / 20.0
	check("arrived" in started, "investida: depois da briga retoma a marcha e chega (%.0f s)" % t)
	# recuo: passado o tempo de vida, volta ao portal e some
	def.raid["lifetime"] = 0.0
	t = 0.0
	while t < 120.0 and not RaidSystem.state(m)["ids"].is_empty():
		ws.tick(1.0 / 20.0)
		t += 1.0 / 20.0
	check("retreat" in started and RaidSystem.state(m)["ids"].is_empty() and "retreated" in started, "investida: recua ao portal e some (%.0f s)" % t)
	Events.raid_event.disconnect(on_raid)
	ws.free()

## Cerco élfico: materiais da Glória, moedas do Rei e do Guardião, dados dos monstros.
func _check_elf_loot(gd, sim) -> void:
	var cls: ClassDef = gd.classes["berserker"]
	var pool: Array = gd.legendary_pool(cls, 20)
	check(not pool.is_empty(), "elfos: há peça da Glória (nível 20)")
	var glory: ItemDef = gd.items[pool[0]]
	var c1: Dictionary = sim.enhance_cost(glory, 0)
	var c6: Dictionary = sim.enhance_cost(glory, Balance.PLUS_STAR_FROM - 1)
	check(c1["item"] == "elf_steel" and c6["item"] == "mother_sap", "elfos: Glória aprimora com Aço Élfico e Seiva (%s, %s)" % [c1["item"], c6["item"]])
	var other: ItemDef = gd.items[gd.legendary_pool(cls, 25)[0]]
	var co: Dictionary = sim.enhance_cost(other, 0)
	check(co["item"] == "iron_ore" and int(c1["gold"]) < int(co["gold"]), "elfos: só a Glória usa material élfico, e sai mais barato em ouro")
	for iid in ["elf_steel", "mother_sap", "heartwood", "griffin_feather"]:
		check(gd.items.has(iid), "elfos: item %s" % iid)
	var king: MonsterDef = gd.monsters["elf_king"]
	check(king.is_boss and king.coin_chance >= 1.0 and king.coin_min >= 4, "elfos: Rei solta 4+ moedas sempre")
	check(gd.monsters["elf_warden"].coin_min >= 4 and gd.monsters["elf_warden"].coin_chance > 0.0, "elfos: Guardião às vezes solta 4 moedas")
	check(gd.monsters["trent"].skill_ids.has("mob_root_grasp") and gd.monsters["trent"].hp >= gd.monsters["ent"].hp * 2.0, "elfos: Trent é tanque e enraíza")
	check(gd.monsters["elf_raider"].move_speed > gd.monsters["bandit"].move_speed, "elfos: batedores são rápidos")
	# abate do Rei: moedas no chão para quem matou
	var m: Dictionary = sim.maps["city_aldara"]
	var at := Vector3(70, 0, 40)
	var k: SimEntity = sim.spawn_monster(king, "city_aldara", at)
	var b: SimEntity = sim.spawn_bot(cls, "EK", "city_aldara", at + Vector3(1.5, 0, 0), 21)
	var before: int = m["loot"].size()
	sim._deal_damage(b, k, int(k.hp + 1), false, false, "physical")
	var coins: Array = m["loot"].slice(before).filter(func(l): return l["item"] == "legend_coin")
	check(coins.size() == 1 and int(coins[0]["count"]) >= 4, "elfos: Rei derrubado deixa 4-6 moedas (%s)" % str(coins.map(func(l): return l["count"])))
	m["loot"].resize(before)
	sim.despawn(k)
	sim.despawn(b)

## Posto dos Caçadores (hub da Floresta): sentinelas, serviços, rota das investidas andável e portões do cerco.
func _check_hunter_post(gd, sim) -> void:
	var def: MapDef = gd.maps["field_forest"]
	var npcs: Array = def.npcs
	var fighters: Array = npcs.filter(func(n): return n.has("fighter"))
	check(fighters.size() >= 8, "Posto: 8+ sentinelas (%d)" % fighters.size())
	check(fighters.any(func(n): return n["fighter"] == "guard_archer") and fighters.any(func(n): return n["fighter"] == "guard_warrior"), "Posto: caçadoras e soldados")
	for role in ["smith", "merchant", "alchemy", "quest"]:
		check(npcs.any(func(n): return n["role"] == role and def.town_center.distance_to(n["pos"]) < def.town_radius), "Posto: serviço %s dentro do muro" % role)
	for n in fighters:
		check(sim.is_walkable(n["pos"], def, 0.45), "Posto: %s nasce em chão livre" % n["id"])
		for q in n.get("route", []):
			check(sim.is_walkable(Vector3(float(q[0]), 0, float(q[1])), def, 0.45), "Posto: ronda de %s andável" % n["id"])
	var live: Array = sim.maps["field_forest"]["entities"].filter(func(e): return e.guard)
	check(live.size() == fighters.size() and live.all(func(e): return e.brain is GuardBrain and e.stats.max_hp > 300.0), "Posto: sentinelas nascem lutando")
	check(not def.raid.is_empty() and def.raid["waves"].size() >= 2, "Posto: investida configurada")
	if not def.raid.is_empty():
		check(sim.is_walkable(def.raid["from"], def, 0.45), "investida: nasce em chão livre")
		for q in def.raid["route"]:
			check(sim.is_walkable(q, def, 0.45), "investida: ponto %s da rota andável" % [q])
		check(def.raid["from"].distance_to(def.raid["target"]) > 80.0, "investida: garganta longe do Posto")
	var gates := {}
	for mid in gd.maps:
		for pt in gd.maps[mid].portals:
			gates[pt["id"]] = pt.get("gate", {})
	check(gates.get("to_ruins", {}).get("quest", "") == "el6_king", "Ruínas: abrem com o Rei Élfico")
	check(not gates.get("to_elf_city", {}).has("quest") and int(gates.get("to_elf_city", {}).get("level", 0)) == 16, "Cidade Élfica: só nível 16 (a defesa do portão não trava o avanço)")
	check(gd.quests["el3_scout"].prereq_quest != "el2_defense", "Além da Garganta não depende de segurar o portão")
	var hold: QuestDef = gd.quests["el2_defense"]
	check(hold.also_counts.has("elf_warrior") and hold.also_counts.has("elf_raider_archer"), "Segurar o Portão conta qualquer elfo")
	check(gd.quests["p6_coracao"].prereq_all.size() == 2, "Coração da Pedreira pede os dois guardiões")
	check(gd.quests["q12_ruins"].prereq_quest == "el6_king", "cadeia: Ruínas depois do Rei Élfico")

## Criação de personagem: começo rápido nível 10 (teste do MVP) chega pronto para a Floresta.
func _check_start_presets(gd, sim) -> void:
	check(StartCatalog.PRESETS.has(1) and StartCatalog.PRESETS.has(10), "começos: nível 1 e nível 10")
	var e: SimEntity = sim.spawn_character(SimEntity.Kind.PLAYER, gd.classes["ranger"], "Rapido", "city_aldara", Vector3(0, 0, 8))
	var pts0: int = e.mastery_points
	sim.apply_start_preset(e, 1)
	check(e.level == 1 and e.mastery_points == pts0, "começo nível 1 não muda nada")
	sim.apply_start_preset(e, 10)
	var want := pts0
	for lv in range(2, 11):
		want += Balance.MASTERY_POINTS_PER_LEVEL + (1 if lv in Balance.MASTERY_BONUS_LEVELS else 0)
	check(e.level == 10 and e.mastery_points == want, "começo 10: nível 10 com os pontos de skill de cada nível (%d/%d)" % [e.mastery_points, want])
	check(int(e.inventory.get("legend_coin", 0)) == 100, "começo 10: 100 Moedas Lendárias")
	check(e.quests_active.has("q08_forest") and "c5_report" in e.quests_completed and "q01_welcome" in e.quests_completed if gd.quests.has("q01_welcome") else e.quests_active.has("q08_forest"), "começo 10: quest da Floresta ativa, cadeia anterior concluída")
	for qid in gd.quests:
		var q: QuestDef = gd.quests[qid]
		if not q.repeatable and q.level_req < 10:
			check(qid in e.quests_completed, "começo 10: quest anterior %s concluída" % qid)
	var avail: Array = []
	for qid in gd.quests:
		var q: QuestDef = gd.quests[qid]
		if not q.repeatable and q.level_req <= 10 and QuestSystem.can_accept(e, q) and gd.maps["field_forest"].npcs.any(func(n): return n["id"] == q.giver_npc):
			avail.append(qid)
	check(avail.size() >= 2, "começo 10: Floresta já oferece laterais no nível 10 (%s)" % str(avail))
	var w: ItemDef = e.equipment.get(ItemDef.Slot.WEAPON)
	check(w != null and w.rarity >= 1 and e.class_def.weapon_types.has(w.weapon_type), "começo 10: arma de Ferro da classe")
	var to_forest := {}
	for pt in gd.maps["city_aldara"].portals:
		if pt["id"] == "to_forest":
			to_forest = pt
	check(not to_forest.is_empty() and sim.portal_block_reason(e, to_forest) == "", "começo 10: desfiladeiro da Floresta liberado")
	sim.despawn(e)

## Começo rápido nível 10: grupo pronto (caçadora, elementalista, druida, paladino) com o jogador de líder.
func _check_start_party(gd, sim) -> void:
	var e: SimEntity = sim.spawn_character(SimEntity.Kind.PLAYER, gd.classes["berserker"], "Lider", "city_aldara", Vector3(2, 0, 8))
	sim.apply_start_preset(e, 10)
	var members: Array = sim.party_members(e)
	check(members.size() == 5, "começo 10: grupo cheio (%d)" % members.size())
	check(sim.party_leader(e) == e, "começo 10: jogador lidera o grupo")
	var want := {"ranger": "cacador", "elementalist": "fogo", "druid": "xama", "paladin": "guardiao"}
	for m in members:
		if m == e:
			continue
		check(m.kind == SimEntity.Kind.BOT and m.level == 10 and want.get(m.class_def.id, "") == m.build_id, "começo 10: %s %s nível 10 (%s)" % [m.class_def.id, m.build_id, m.name])
		want.erase(m.class_def.id)
	check(want.is_empty(), "começo 10: as 4 classes pedidas (faltou %s)" % str(want.keys()))
	for m in members:
		if m != e:
			sim.despawn(m)
	sim.despawn(e)

## Começo rápido nível 20: Ruínas, Rei Élfico vencido (portão das Ruínas aberto), q12 ativa, material de aprimorar a Glória.
func _check_start_ruins(gd, sim) -> void:
	var e: SimEntity = sim.spawn_character(SimEntity.Kind.PLAYER, gd.classes["assassin"], "Ruinas", "city_aldara", Vector3(2, 0, 8))
	sim.apply_start_preset(e, 20)
	check(e.level == 20 and e.map_id == "field_ruins", "começo 20: nível 20 nas Ruínas (%d, %s)" % [e.level, e.map_id])
	check(sim.is_walkable(e.position, gd.maps["field_ruins"], 0.45), "começo 20: nasce em chão livre")
	check(e.quests_active.has("q12_ruins") and "el6_king" in e.quests_completed and "els_heart" in e.quests_completed, "começo 20: q12 ativa, cadeia élfica e laterais concluídas")
	var gate := {}
	for pt in gd.maps["city_aldara"].portals:
		if pt["id"] == "to_ruins":
			gate = pt
	check(not gate.is_empty() and sim.portal_block_reason(e, gate) == "", "começo 20: passagem das Ruínas liberada")
	check(int(e.inventory.get("elf_steel", 0)) >= 10 and int(e.inventory.get("mother_sap", 0)) >= 2, "começo 20: Aço Élfico e Seiva para a Glória")
	var members: Array = sim.party_members(e)
	check(members.size() == 5 and members.all(func(m): return m.map_id == "field_ruins" and m.level == 20), "começo 20: grupo de 5 nas Ruínas, nível 20")
	for m in members:
		if m != e:
			sim.despawn(m)
	sim.despawn(e)

## Investida: a leitura da apresentação (faixa do HUD e minimapa) acompanha a leva.
func _check_raid_status(gd, sim) -> void:
	check(sim.raid_status("city_aldara").is_empty(), "investida: mapa sem investida não tem estado")
	var m: Dictionary = sim.maps["field_forest"]
	var before: Dictionary = sim.raid_status("field_forest")
	check(not before.is_empty() and before.has("next_in") and before.has("target"), "investida: estado com contagem e alvo")
	if not (m.get("raid", {}).get("ids", []) as Array).is_empty():
		return                              # outro check deixou uma leva viva: não mexe
	var ids: Array = RaidSystem.start_raid(sim, m)
	var rs: Dictionary = sim.raid_status("field_forest")
	check(rs["active"] and rs["total"] == ids.size() and rs["alive"] == ids.size() and rs["phase"] == "march", "investida: leva ativa marchando (%d/%d)" % [rs["alive"], rs["total"]])
	var first: SimEntity = sim.entities.get(ids[0])
	first.hp = 0.0
	first.set_state(SimEntity.State.DEAD)
	check(sim.raid_status("field_forest")["alive"] == ids.size() - 1, "investida: abate desconta da faixa")
	for id in ids:
		var x: SimEntity = sim.entities.get(id)
		if x != null:
			sim.despawn(x)
	RaidSystem.update_raids(sim, m, 0.1)
	check(not sim.raid_status("field_forest")["active"], "investida: leva desfeita volta à contagem")

## Defesa do portão: bot perto do povoado larga a caça e vai ao portão atacado; Bastião (defesa + regeneração)
## só perto das muralhas; ferido recua para dentro; bot do meio do jogo anda com poções (M).
func _check_raid_defense(gd, sim) -> void:
	var ws := WorldSim.new()
	ws.rng.seed = 11
	var def: MapDef = gd.maps["field_forest"].duplicate()
	check(not def.raid.is_empty(), "defesa: Floresta tem investida")
	if def.raid.is_empty():
		return
	def.spawners = []
	def.raid = def.raid.duplicate(true)
	def.raid["first"] = 999.0
	def.raid["lifetime"] = 400.0
	def.raid["waves"] = [{"mobs": {"elf_raider": 2, "elf_raider_archer": 1}}]
	ws.load_map(gd.maps[GameData.town_map_id()])
	var m: Dictionary = ws.load_map(def)
	var target: Vector3 = def.raid["target"]
	var gate := RaidSystem.gate_point(def)
	check(gate.distance_to(target) > 5.0 and gate.distance_to(def.raid["route"][def.raid["route"].size() - 1]) < 8.0, "defesa: portão atacado é o do fim da rota (%s)" % str(gate))
	var b: SimEntity = ws.spawn_bot(gd.classes["paladin"], "Def", def.id, ws.random_walkable(def, target + Vector3(40, 0, 10), 4.0), 16)
	check(b.potion_slots[0] == "potion_hp_m" and b.has_item("potion_hp_m"), "defesa: bot nível 16 anda com Poção de Vida (M)")
	var low: SimEntity = ws.spawn_bot(gd.classes["ranger"], "Novato", "city_aldara", Vector3(0, 0, 8), 3)
	check(low.potion_slots[0] == "potion_hp_s", "defesa: bot de nível baixo continua com a (P)")
	ws.despawn(low)
	var far: SimEntity = ws.spawn_bot(gd.classes["ranger"], "Longe", def.id, ws.random_walkable(def, target + Vector3(0, 0, 0), 2.0), 16)
	far.position = ws.random_walkable(def, target + Vector3(80, 0, 62), 6.0)   # bem longe do povoado (e da rota)
	var ids: Array = RaidSystem.start_raid(ws, m)
	var wave: int = ws.raid_status(def.id)["wave"]
	b.brain.skip_wave = -1
	b.brain.rng.seed = 1
	var d0 := b.position.distance_to(gate)
	for i in 14 * 20:                         # leva ainda na garganta (trompas): o bot chega ao portão
		ws.tick(1.0 / 20.0)
	check(b.brain.defend_wave == wave or b.brain.skip_wave == wave, "defesa: bot decide uma vez por leva")
	if b.brain.skip_wave == wave:              # sorteio negou: força a decisão para conferir o resto
		b.brain.skip_wave = -1
		b.brain.defend_wave = wave
		for i in 14 * 20:
			ws.tick(1.0 / 20.0)
	check(b.position.distance_to(gate) < 8.0 and b.position.distance_to(gate) < d0, "defesa: bot vai ao portão atacado (%.1f m, antes %.1f)" % [b.position.distance_to(gate), d0])
	check(far.brain.defend_wave != wave, "defesa: bot longe do povoado não larga a caça")
	var bastion := b.buffs.filter(func(x): return x.get("id") == "bastion")
	check(bastion.size() == 1 and float(bastion[0]["def_pct"]) == Balance.RAID_RALLY_DEF_PCT, "defesa: Bastião no defensor junto da muralha")
	check(not far.buffs.any(func(x): return x.get("id") == "bastion"), "defesa: sem Bastião longe das muralhas")
	var pdef_with := b.stats.pdef
	b.hp = b.stats.max_hp * 0.5
	var hp0 := b.hp
	for i in 20:
		ws.tick(1.0 / 20.0)
	check(b.hp > hp0, "defesa: Bastião regenera vida (%.0f -> %.0f)" % [hp0, b.hp])
	# ferido: recua para dentro das muralhas
	b.hp = b.stats.max_hp * 0.2
	b.potion_cd = 99.0
	for i in 3 * 20:
		ws.tick(1.0 / 20.0)
	check(b.brain.falling_back and b.position.distance_to(target) < gate.distance_to(target) - 2.0, "defesa: ferido recua para dentro (%.1f m do centro)" % b.position.distance_to(target))
	b.potion_cd = 0.0
	# leva desfeita: Bastião some, bot solto
	for id in ids:
		var x: SimEntity = ws.entities.get(id)
		if x != null:
			ws.despawn(x)
	for i in 3 * 20:
		ws.tick(1.0 / 20.0)
	check(not b.buffs.any(func(x): return x.get("id") == "bastion") and b.stats.pdef < pdef_with, "defesa: Bastião some depois da leva")
	check(b.brain.defend_wave == -1, "defesa: bot volta à rotina")

## Força da investida pelo nível do jogador: passo 0 até RAID_SCALE_FROM, sobe por nível até RAID_SCALE_TO (teto);
## invasor reforçado tem o mesmo id (quest conta), mais nível/vida/ataque/XP; passos altos trazem reforço na leva.
func _check_raid_scaling(gd, sim) -> void:
	var ws := WorldSim.new()
	ws.rng.seed = 5
	var def: MapDef = gd.maps["field_forest"].duplicate()
	def.spawners = []
	ws.load_map(gd.maps[GameData.town_map_id()])
	var m: Dictionary = ws.load_map(def)
	for o in m["entities"].duplicate():
		if o.guard:
			ws.despawn(o)
	ws.player = ws.spawn_player(gd.classes["berserker"], "Escala", def.id)
	ws.player.position = ws.random_walkable(def, def.raid["target"] + Vector3(0, 0, 10), 3.0)
	var steps := {}
	for lv in [10, Balance.RAID_SCALE_FROM, Balance.RAID_SCALE_FROM + 2, Balance.RAID_SCALE_TO, 30]:
		ws.player.level = lv
		steps[lv] = RaidSystem.power_step(ws, m)
	check(steps[10] == 0 and steps[Balance.RAID_SCALE_FROM] == 0 and steps[Balance.RAID_SCALE_FROM + 2] == 2, "investida: força sobe com o nível do jogador (%s)" % str(steps))
	check(steps[Balance.RAID_SCALE_TO] == steps[30] and steps[30] == Balance.RAID_SCALE_TO - Balance.RAID_SCALE_FROM, "investida: força para no nível %d" % Balance.RAID_SCALE_TO)
	var base: MonsterDef = gd.monsters["elf_raider"]
	var top := RaidSystem.scaled_def(ws, base, steps[30])
	check(top.id == base.id and top.level == base.level + steps[30] and top.hp > base.hp * 1.3 and top.atk > base.atk * 1.2 and top.xp > base.xp, "investida: invasor reforçado (nv %d, %.0f HP, %.0f ATK)" % [top.level, top.hp, top.atk])
	var s0 := RaidSystem.scaled_def(ws, base, 0)
	check(s0.level == base.level and is_equal_approx(s0.hp, base.hp * Balance.RAID_POWER) and is_equal_approx(s0.atk, base.atk * Balance.RAID_POWER) and s0.aggro_range > base.aggro_range,
		"investida: força 0 = base x RAID_POWER (HP/ATK) e aggro maior")
	check(RaidSystem.scaled_def(ws, base, 3) == RaidSystem.scaled_def(ws, base, 3), "investida: reforço guardado por passo")
	check(base.level == 16 and base.hp == gd.monsters["elf_raider"].hp, "investida: monstro base não muda")
	ws.player.level = 10
	var weak: Array = RaidSystem.start_raid(ws, m)
	var n_weak := weak.size()
	var lv_weak: int = ws.raid_status(def.id)["level"]
	for id in weak:
		ws.despawn(ws.entities[id])
	RaidSystem.update_raids(ws, m, 0.1)
	RaidSystem.state(m)["n"] = 0                 # mesma leva de antes, agora com o jogador no nível máximo da força
	ws.player.level = 30
	var strong: Array = RaidSystem.start_raid(ws, m)
	var rs: Dictionary = ws.raid_status(def.id)
	check(strong.size() > n_weak and rs["step"] == steps[30] and rs["level"] > lv_weak, "investida: leva forte maior e de nível maior (%d -> %d, nv %d -> %d)" % [n_weak, strong.size(), lv_weak, rs["level"]])
	var r0: SimEntity = ws.entities[strong[0]]
	check(r0.level == r0.monster_def.level and r0.stats.max_hp == r0.monster_def.hp and r0.monster_def.level > gd.monsters[r0.monster_def.id].level, "investida: invasor nasce com os números reforçados")
	for id in strong:
		ws.despawn(ws.entities[id])
	ws.despawn(ws.player)
	ws.player = null

## Faixa 10-20: chefes com repertório (3+ golpes somando as fases), fala de abertura uma vez por luta e fala ao cair;
## capanga do Chefe dos Bandidos sem XP; skills novas existem e estão no tema certo.
func _check_band_bosses(gd, sim) -> void:
	for bid in ["bandit_chief", "spider_queen", "elf_king", "count_vargo", "bone_captain", "wailing_widow", "golem_ancient", "crystal_warden", "quarry_heart"]:
		var md: MonsterDef = gd.monsters[bid]
		var kit := {}
		for sid in md.skill_ids:
			kit[sid] = true
		for ph in md.phases:
			for sid in ph.get("skills", []):
				kit[sid] = true
		for sid in kit:
			check(gd.skills.has(sid), "%s: skill %s existe" % [bid, sid])
		if bid in ["bandit_chief", "spider_queen", "elf_king", "count_vargo"]:
			check(kit.size() >= 4 and md.phases.size() >= 2, "%s: repertório de chefe (%d golpes, %d fases)" % [bid, kit.size(), md.phases.size()])
		check(md.intro != "" and md.last_words != "", "%s: fala de abertura e de queda" % bid)
	check(gd.monsters["bandit_thug"].xp == 0 and gd.monsters["bandit_thug"].loot_table == "", "Capanga: lacaio sem XP nem saque")
	check(gd.skills["mob_venom_pool"].vfx == "poison" and gd.skills["mob_shadow_bats"].vfx == "shadow"
		and gd.skills["mob_thorn_lash"].vfx == "nature", "skills novas de monstro no tema certo")
	# falas: abertura uma vez por luta (volta no reset), queda ao morrer
	var said: Array = []
	var on_note := func(t: String): said.append(t)
	Events.notification.connect(on_note)
	var ws := WorldSim.new()
	ws.load_map(gd.maps[GameData.town_map_id()])
	var m: Dictionary = ws.load_map(gd.maps["dg_ninho"])
	m["spawners"].clear()
	ws.player = ws.spawn_player(gd.classes["berserker"], "Falas", "dg_ninho")
	var q: SimEntity = ws.spawn_monster(gd.monsters["spider_queen"], "dg_ninho", ws.player.position + Vector3(6, 0, 0))
	q.aggro_target = ws.player.id
	MobSystem.update_boss(ws, q)
	MobSystem.update_boss(ws, q)
	var intro := said.filter(func(t): return t.ends_with(gd.monsters["spider_queen"].intro))
	check(intro.size() == 1, "chefe diz a abertura uma vez (%d)" % intro.size())
	ws.reset_boss(q)
	q.aggro_target = ws.player.id
	MobSystem.update_boss(ws, q)
	check(said.filter(func(t): return t.ends_with(gd.monsters["spider_queen"].intro)).size() == 2, "reset: a abertura volta na próxima luta")
	LootSystem.on_monster_killed(ws, q, ws.player)
	check(said.any(func(t): return t.ends_with(gd.monsters["spider_queen"].last_words)), "chefe fala ao cair")
	Events.notification.disconnect(on_note)

## Monstro atirador cujo tiro não tira vida (obstáculo no meio) chega mais perto; corpo a corpo contorna obstáculo (MonsterBrain._steer).
func _check_monster_unstick(gd, sim) -> void:
	var ws := WorldSim.new()
	ws.load_map(gd.maps[GameData.town_map_id()])
	var m: Dictionary = ws.load_map(gd.maps["field_forest"])
	m["spawners"].clear()
	var a: SimEntity = ws.spawn_monster(gd.monsters["bandit_archer"], "field_forest", Vector3(40, 0, 40))
	var t: SimEntity = ws.spawn_bot(gd.classes["paladin"], "Alvo", "field_forest", Vector3(46, 0, 40), 15)
	var br: MonsterBrain = a.brain
	var blocked := false
	for i in range(int(MonsterBrain.NO_HIT_LIMIT * 20) + 2):
		blocked = br._shots_blocked(a, t, 0.05)
		if blocked:
			break
	check(blocked, "atirador sem acertar por %.0f s vai chegar mais perto" % MonsterBrain.NO_HIT_LIMIT)
	br.close_in = 0.0
	br.no_hit = 0.0
	t.hp -= 10.0
	check(not br._shots_blocked(a, t, 0.05), "tiro que acerta zera a espera")

## Posto dos Caçadores: moradores (refugiados) nascem em chão livre dentro das muralhas e passeiam;
## os bots falam do lugar onde estão (falas por mapa existem só para mapas que existem).
func _check_post_life(gd, sim) -> void:
	var def: MapDef = gd.maps["field_forest"]
	var vil: Array = def.npcs.filter(func(n): return n["id"] in MapsCatalog.POST_VILLAGERS)
	check(vil.size() == MapsCatalog.POST_VILLAGERS.size() and vil.size() >= 5, "Posto: moradores no mapa (%d)" % vil.size())
	for n in vil:
		var pos: Vector3 = n["pos"]
		check(sim.is_walkable(pos, def, 0.4), "Posto: %s em chão livre" % n["id"])
		check(Vector2(pos.x - def.town_center.x, pos.z - def.town_center.z).length() + float(n.get("wander", 0.0)) < def.town_radius - 1.0,
			"Posto: %s passeia dentro das muralhas" % n["id"])
	for ctx in BotsCatalog.LINES:
		for pre in ["hunt_", "town_"]:
			if str(ctx).begins_with(pre):
				check(gd.maps.has(str(ctx).trim_prefix(pre)), "falas de bot: mapa %s existe" % ctx)
	for mid in ["field_forest", "dg_ninho", "elf_city", "dg_coracao", "dg_pedreira"]:
		check(BotsCatalog.LINES.has("hunt_" + mid) and (BotsCatalog.LINES["hunt_" + mid] as Array).size() >= 5, "falas de bot na faixa 10-20: %s" % mid)

## Faixa 10-20: toda quest tem alvo que nasce (spawner ou investida), item com fonte; monstros comuns sobem de vida com o nível
## dentro de cada mapa (sem aranha nível 13 mais dura que bandido nível 15).
func _check_band_consistency(gd, sim) -> void:
	var spawns := {}
	for mid in gd.maps:
		for sp in gd.maps[mid].spawners:
			spawns[sp["monster_id"]] = true
	for mid in MapsCatalog.RAIDS:
		for w in MapsCatalog.RAIDS[mid]["waves"]:
			for mon in w["mobs"]:
				spawns[mon] = true
	var drops := {}
	for mon in spawns:
		var md: MonsterDef = gd.monsters.get(mon)
		if md and gd.loot_tables.has(md.loot_table):
			for en in gd.loot_tables[md.loot_table].entries:
				drops[en["item"]] = true
	var gather := {}
	for mid in MapsCatalog.GATHER:
		for g in MapsCatalog.GATHER[mid]:
			gather[g[0]] = true
	for qid in gd.quests:
		var q: QuestDef = gd.quests[qid]
		if q.level_req < 10 or q.level_req > 20:
			continue
		if q.type == QuestDef.Type.KILL:
			check(spawns.has(q.target_id), "%s: %s nasce em algum lugar" % [qid, q.target_id])
		elif q.type == QuestDef.Type.COLLECT:
			check(not q.give_items.is_empty() or gather.has(q.target_id) or drops.has(q.target_id), "%s: %s tem fonte" % [qid, q.target_id])
	for mid in ["field_forest", "elf_city"]:
		var mons: Array = []
		for sp in gd.maps[mid].spawners:
			var md: MonsterDef = gd.monsters[sp["monster_id"]]
			if not md.is_boss and md.hp < 1500 and not mons.has(md):
				mons.append(md)
		for x in mons:
			for y in mons:
				if x.level + 2 <= y.level:
					check(x.hp * (1.0 if x.ranged == y.ranged else 0.8) <= y.hp * 1.15, "%s: %s (nv %d) não mais duro que %s (nv %d)" % [mid, x.id, x.level, y.id, y.level])

## Começo rápido nível 16: Posto dos Caçadores, cadeia élfica até a garganta, garganta liberada, grupo do nível.
func _check_start_elf(gd, sim) -> void:
	var e: SimEntity = sim.spawn_character(SimEntity.Kind.PLAYER, gd.classes["paladin"], "Elfico", "city_aldara", Vector3(2, 0, 8))
	sim.apply_start_preset(e, 16)
	check(e.level == 16 and e.map_id == "field_forest", "começo 16: nível 16 na Floresta (%d, %s)" % [e.level, e.map_id])
	check(sim.is_walkable(e.position, gd.maps["field_forest"], 0.45), "começo 16: nasce em chão livre")
	check(e.quests_active.has("el3_scout") and "el2_defense" in e.quests_completed and "q09_spiders" in e.quests_completed, "começo 16: quest da Cidade Élfica ativa")
	var gate := {}
	for pt in gd.maps["field_forest"].portals:
		if pt["id"] == "to_elf_city":
			gate = pt
	check(not gate.is_empty() and sim.portal_block_reason(e, gate) == "", "começo 16: garganta élfica liberada")
	var w: ItemDef = e.equipment.get(ItemDef.Slot.WEAPON)
	check(w != null and w.rarity >= 2, "começo 16: arma de Mitril")
	var members: Array = sim.party_members(e)
	check(members.size() == 5 and members.all(func(m): return m.map_id == "field_forest" and m.level == 16), "começo 16: grupo de 5 no Posto, nível 16")
	for m in members:
		if m != e:
			sim.despawn(m)
	sim.despawn(e)
