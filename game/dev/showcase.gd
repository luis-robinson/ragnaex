class_name Showcase
extends Node
## Bancada de skills (revisão em loop). Roda dentro do jogo, com as views/efeitos/câmera de verdade:
##   godot --path . -- --showcase=<classe> [--skill=<id>] --out=<pasta>      folha de 8 quadros por skill
##   godot --headless --path . -- --showcase=all --check                     lança todas as skills, sem fotos
## Para cada skill: veste as armas da build dela, põe 3 bonecos de treino na frente, lança via Sim.try_cast mirando
## certo, e fotografa 8 quadros do começo da preparação até o fim da recuperação (quadro do impacto anotado no índice).

const FRAMES := 8
const SHEET_COLS := 4
const CELL := 360

var main
var classes: Array = []
var only_skill := ""
var out_dir := ""
var check := false
var _queue: Array = []               # [[classe, skill]]
var _i := -1
var _t := 0.0
var _phase := ""                     # setup | cast | wait
var _frames: Array = []
var _times: Array = []
var _dummies: Array = []
var _total := 0.0
var _index_lines: Dictionary = {}    # classe -> [linhas]
var _errors := 0
var _cast := 0
var _clip := ""
var _pages: Dictionary = {}          # classe -> [[Image x4]] para as páginas-resumo
const PAGE_ROWS := 6
const THUMB := 220
const SPOT := Vector3(0, 0, -50)     # estrada norte de Aldara: campo aberto, longe da vila

func setup(m, cls_arg: String, skill_arg: String, out_arg: String, check_arg: bool) -> void:
	main = m
	only_skill = skill_arg
	out_dir = out_arg
	check = check_arg
	if cls_arg == "all":
		for c in GameData.classes:
			classes.append(c)
	else:
		classes.append(cls_arg)
	for cid in classes:
		var cls: ClassDef = GameData.classes[cid]
		var list: Array = []
		for sid in cls.skill_ids:
			if only_skill == "" or sid == only_skill:
				list.append(sid)
		list.sort_custom(func(a, b): return _order(cls, a) < _order(cls, b))
		for sid in list:
			_queue.append([cid, sid])
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)

func _order(cls: ClassDef, sid: String) -> String:
	var s: SkillDef = GameData.skills[sid]
	var bi := 0
	for i in range(cls.builds.size()):
		if cls.builds[i]["id"] == s.build:
			bi = i + 1
	return "%d_%02d_%s" % [bi, s.unlock_level, sid]

func _process(delta: float) -> void:
	var p: SimEntity = Sim.player
	if p == null:
		return
	if main.hud and main.hud.root:
		main.hud.root.visible = false
	if main.fx:
		main.fx.show_reticle = false
	_t += delta
	_clear_intruders(p)
	match _phase:
		"":
			_next(p)
		"setup":
			if _t > 0.5:
				_fire(p)
		"cast":
			if not check and _frames.size() < FRAMES and _t >= _times[_frames.size()]:
				_frames.append(_grab(p))
			if _t > _total + 0.25 and (check or _frames.size() >= FRAMES):
				_finish(p)
		"wait":
			if _t > 0.3:
				_phase = ""

func _next(p: SimEntity) -> void:
	_i += 1
	if _i >= _queue.size():
		_write_index()
		print("SHOWCASE %s: %d skills, %d errors" % ["OK" if _errors == 0 else "FAIL", _cast, _errors])
		get_tree().quit(1 if _errors > 0 else 0)
		return
	var cid: String = _queue[_i][0]
	var sid: String = _queue[_i][1]
	var s: SkillDef = GameData.skills[sid]
	if p.class_def.id != cid:
		# troca de classe (modo --check com todas): o mesmo jogador vira a outra classe
		p.class_def = GameData.classes[cid]
		p.learned.clear()
		p.mastery.clear()
		p.basic_skill = GameData.basic_skill_for_class(p.class_def)
	_gear(p, s)
	p.level = maxi(1, s.unlock_level)
	p.learned[sid] = true
	p.skills[0] = s
	p.cooldowns.clear()
	p.recompute_stats()
	p.heal_full()
	p.position = SPOT
	p.set_state(SimEntity.State.IDLE)
	# bonecos: 3 em leque na frente, à distância que a skill alcança
	var d := 2.4
	if s.target in [SkillDef.Target.DIRECTION, SkillDef.Target.GROUND, SkillDef.Target.TARGET]:
		d = clampf(minf(s.range, 7.0) * 0.6, 2.4, 5.5)
	if s.target == SkillDef.Target.CONE:
		d = clampf(s.radius * 0.6, 1.6, 3.5)
	var mdef: MonsterDef = GameData.monsters["slime"]
	var fwd := Vector3(0.6, 0, -0.8)
	var side := Vector3(0.8, 0, 0.6)
	for off in [fwd * d, fwd * (d + 0.8) - side * 1.4, fwd * (d + 0.8) + side * 1.4]:
		var m := Sim.spawn_monster(mdef, p.map_id, SPOT + off)
		m.brain = null
		m.stats.max_hp = 1.0e7
		m.hp = 1.0e7
		_dummies.append(m)
	_phase = "setup"
	_t = 0.0

## Armas da build da skill (comuns, tier 0): principal + secundária; skills gerais usam a 1ª build.
func _gear(p: SimEntity, s: SkillDef) -> void:
	var build := p.class_def.build_by_id(s.build)
	if build.is_empty():
		build = p.class_def.builds[0]
	var main_t: String = build["main"][0]
	var off_t: String = build["off"][0] if build["off"].size() > 0 else ""
	if not _fits(s.requires, main_t, off_t):          # skill geral que exige algo (ex.: escudo): acha a build que serve
		for b in p.class_def.builds:
			var bo: String = b["off"][0] if b["off"].size() > 0 else ""
			if _fits(s.requires, b["main"][0], bo):
				main_t = b["main"][0]
				off_t = bo
				break
	p.equipment.erase(ItemDef.Slot.WEAPON)
	p.equipment.erase(ItemDef.Slot.OFFHAND)
	var w := _item_of(main_t, p.class_def.id)
	if w:
		p.equipment[ItemDef.Slot.WEAPON] = w
	if off_t != "":
		var o := _item_of(off_t, p.class_def.id)
		if o:
			p.equipment[ItemDef.Slot.OFFHAND] = o
	p.recompute_stats()
	Events.equipment_changed.emit(p.id)

## Mesmas fichas de SkillDef.requires (alternativas: basta uma).
func _fits(req: Array, main_t: String, off_t: String) -> bool:
	if req.is_empty():
		return true
	for need in req:
		match need:
			"shield", "orb": if off_t == need: return true
			"two_handed": if main_t in ItemDef.TWO_HANDED: return true
			"dual": if off_t in ItemDef.ONE_HANDED_MELEE: return true
			_:
				if need.begins_with("dual_"):
					if main_t == need.substr(5) and off_t == need.substr(5): return true
				elif main_t == need:
					return true
	return false

func _item_of(wtype: String, cid: String) -> ItemDef:
	var best: ItemDef = null
	for iid in GameData.items:
		var it: ItemDef = GameData.items[iid]
		if it.weapon_type != wtype or it.is_legendary():
			continue
		if it.class_restriction.size() > 0 and not (cid in it.class_restriction):
			continue
		if best == null or it.level_req < best.level_req:
			best = it
	return best

func _aim(p: SimEntity, s: SkillDef) -> Vector3:
	if s.target == SkillDef.Target.SELF:
		return p.position + Vector3(0, 0, 1)
	return _dummies[0].position if _dummies.size() > 0 else p.position + Vector3(0, 0, 3)

func _fire(p: SimEntity) -> void:
	var s: SkillDef = p.skills[0]
	p.face_towards(_aim(p, s))
	p.mp = p.stats.max_mp
	if not Sim.try_cast(p, 0, _aim(p, s), Sim.maps[p.map_id]):
		printerr("SHOWCASE: %s não saiu (%s)" % [s.id, Sim.requires_text(s.requires)])
		_errors += 1
		_finish(p)
		return
	_cast += 1
	var view = main.views.get(p.id)
	_clip = view._action_clip(s) if view else ""
	if view and view.anim and view._clip(_clip) == "":
		printerr("SHOWCASE: %s sem clipe '%s'" % [s.id, _clip])
		_errors += 1
	_total = s.startup + s.active + s.recovery + (0.35 if s.projectile_speed > 0.0 else 0.0)
	_times.clear()
	for k in range(FRAMES):
		_times.append(_total * float(k) / float(FRAMES - 1))
	_frames.clear()
	_phase = "cast"
	_t = 0.0

func _grab(p: SimEntity) -> Image:
	var img := get_viewport().get_texture().get_image()
	var cam: Camera3D = main.camera.cam
	# a câmera projeta em coordenadas da tela-base (stretch canvas_items); a foto é na resolução da janela
	var focus := p.position + Vector3(0, 0.8, 0)
	if _dummies.size() > 0 and p.skills[0] and p.skills[0].target != SkillDef.Target.SELF:
		focus = focus.lerp(_dummies[0].position, 0.45)      # entre quem lança e o alvo: o impacto entra no quadro
	var c := cam.unproject_position(focus) * (Vector2(img.get_size()) / get_viewport().get_visible_rect().size)
	var side := int(img.get_height() * 0.9)
	var x := clampi(int(c.x) - side / 2, 0, img.get_width() - side)
	var y := clampi(int(c.y) - side / 2, 0, img.get_height() - side)
	var crop := img.get_region(Rect2i(x, y, side, side))
	crop.resize(CELL, CELL, Image.INTERPOLATE_BILINEAR)
	return crop

func _finish(p: SimEntity) -> void:
	var cid: String = _queue[_i][0]
	var s: SkillDef = GameData.skills[_queue[_i][1]]
	if not check and _frames.size() > 0:
		var rows := int(ceil(float(_frames.size()) / SHEET_COLS))
		var sheet := Image.create(CELL * SHEET_COLS, CELL * rows, false, Image.FORMAT_RGBA8)
		var impact := 0
		for k in range(_frames.size()):
			var f: Image = _frames[k]
			f.convert(Image.FORMAT_RGBA8)
			if absf(_times[k] - s.startup) < absf(_times[impact] - s.startup):
				impact = k
			sheet.blit_rect(f, Rect2i(0, 0, CELL, CELL), Vector2i((k % SHEET_COLS) * CELL, (k / SHEET_COLS) * CELL))
		# moldura amarela no quadro do impacto
		var ix := (impact % SHEET_COLS) * CELL
		var iy := (impact / SHEET_COLS) * CELL
		for b in range(4):
			sheet.fill_rect(Rect2i(ix, iy + b, CELL, 1), Color(1, 0.85, 0.2))
			sheet.fill_rect(Rect2i(ix, iy + CELL - 1 - b, CELL, 1), Color(1, 0.85, 0.2))
			sheet.fill_rect(Rect2i(ix + b, iy, 1, CELL), Color(1, 0.85, 0.2))
			sheet.fill_rect(Rect2i(ix + CELL - 1 - b, iy, 1, CELL), Color(1, 0.85, 0.2))
		var n := _i
		sheet.save_png("%s/%s_%03d_%s.png" % [out_dir, cid, n, s.id])
		var picks: Array = []
		for k in [0, impact, mini(impact + 2, _frames.size() - 1), _frames.size() - 1]:
			var t: Image = _frames[k].duplicate()
			t.resize(THUMB, THUMB, Image.INTERPOLATE_BILINEAR)
			if k == impact:
				for b in range(3):
					t.fill_rect(Rect2i(0, b, THUMB, 1), Color(1, 0.85, 0.2))
					t.fill_rect(Rect2i(0, THUMB - 1 - b, THUMB, 1), Color(1, 0.85, 0.2))
			picks.append(t)
		if not _pages.has(cid):
			_pages[cid] = []
		_pages[cid].append(picks)
		if not _index_lines.has(cid):
			_index_lines[cid] = []
		_index_lines[cid].append("%03d  %-22s %-24s %-9s %-8s build=%-10s clip=%-11s vfx=%-8s start=%.2f act=%.2f rec=%.2f impacto=quadro %d" % [
			n, s.id, s.name, ["SELF", "DIR", "GROUND", "CONE", "TARGET"][s.target], ["FIS", "MAG", "CURA", "BUFF", "INVOC", "MOV"][s.kind] if s.kind < 6 else str(s.kind),
			s.build, _clip, s.get("vfx") if s.get("vfx") != null else "", s.startup, s.active, s.recovery, impact])
	for m in _dummies:
		if is_instance_valid(m) or m != null:
			Sim.despawn(m)
	_dummies.clear()
	for e in Sim.map_entities(p.map_id).duplicate():       # invocações e auras da skill anterior escondiam a próxima
		if e.kind == SimEntity.Kind.SUMMON and e.owner_id == p.id and e != Sim.pet_of(p):     # o lince fica (Matilha e Atacar precisam dele)
			Sim.despawn(e)
	p.buffs.clear()
	p.recompute_stats()
	_phase = "wait"
	_t = 0.0

func _clear_intruders(p: SimEntity) -> void:
	for e in Sim.map_entities(p.map_id).duplicate():
		if e == p or e in _dummies or e.kind == SimEntity.Kind.NPC or e.kind == SimEntity.Kind.SUMMON:
			continue
		if e.position.distance_to(SPOT) < 30.0:
			Sim.despawn(e)

func _write_index() -> void:
	if check or out_dir == "":
		return
	# páginas-resumo: cada linha = uma skill (na ordem do índice), 4 quadros (o do impacto com faixa amarela)
	for cid in _pages:
		var rows: Array = _pages[cid]
		var page := 0
		var r := 0
		while r < rows.size():
			var n := mini(PAGE_ROWS, rows.size() - r)
			var img := Image.create(THUMB * 4 + 12, THUMB * n + 6 * (n - 1), false, Image.FORMAT_RGBA8)
			img.fill(Color(0.08, 0.07, 0.1))
			for i in range(n):
				for k in range(4):
					img.blit_rect(rows[r + i][k], Rect2i(0, 0, THUMB, THUMB), Vector2i(k * (THUMB + 4), i * (THUMB + 6)))
			img.save_png("%s/%s_pagina_%d.png" % [out_dir, cid, page])
			page += 1
			r += n
	for cid in _index_lines:
		var f := FileAccess.open("%s/%s_index.txt" % [out_dir, cid], FileAccess.WRITE)
		f.store_string("\n".join(_index_lines[cid]) + "\n")
