extends Node
## Filme do arco de golpe (game/fx/weapon_arcs.gd): uma faixa de 18 quadros seguidos (60 Hz, a partir do 3º quadro do
## disparo) por golpe, com a câmera do jogo, e o quadro inteiro logo depois do tick do dano. Roda a bancada de skills
## (Showcase, em --check: ela não grava nada) e troca a arma de cada tomada antes do disparo.
##   godot --path . --fixed-fps 60 --audio-driver Dummy tools/lineup/arc_film.tscn -- --class=<c> [--build=<b>]
##     [--main=<item|tipo>] [--off=<item|tipo|none>] [--skill=<id|basic|basic_phys>] [--name=<rótulo>]
##     [--cams=24] [--map=<id> [--at=x,z]] --out=<pasta>
##   Uma câmera por processo (o 2º passe herdava o lince, números e restos de efeito do 1º):
##   várias câmeras = tools/lineup/arc_film.sh <mesmos argumentos> --cams=9,24
##   --take=<rótulo>:<skill>:<main>:<off>[:<build>[:<forma>]] (repetível; campo vazio = padrão): várias tomadas na mesma
##     rodada, na ordem dada. Sem --take, uma tomada com --skill/--main/--off/--name.
##   --form=<wolf|bear|alpha|ent> (ou 6º campo do --take): o Druida bate transformado (garras no chão, onda 6).
##   basic = básico com o `look` da assinatura da build; basic_phys = básico físico (sem look).
##   --main/--off: id de item ou tipo de arma (o comum de menor nível da classe). Sem --off = o da build; none = sem.
##   O golpe A/B (atk_1h_a/b, atk_dual_a/b) alterna na ordem das tomadas, começando em A.
## Saída (rótulo padrão <tipo da arma>_<basic|basicPhys|id sem o prefixo da classe>, com <mapa>_ na frente se --map):
##   <out>/strip_cam<C>_<rótulo>.png (6×3 de 300 px, impacto em amarelo) + .txt (st/clipe por quadro, impact_cell)
##   <out>/full_cam<C>_<rótulo>_imp.png (tela inteira, 1º quadro depois do tick do dano)
## Outros argumentos passam para o jogo (ex.: --gfx=<n>). Depende do miolo da Showcase (_queue/_i/_phase/_dummies).

const BENCH := "res://game/main.tscn"
const FIRST := 3                     # quadros do disparo antes da 1ª célula
const CELLS := 18
const COLS := 6
const CELL := 300
const OWN := ["--class", "--build", "--main", "--off", "--skill", "--name", "--cams", "--map", "--at", "--out", "--take", "--form", "--stride"]

var runner := false
var cls_id := ""
var out_dir := ""
var map_id := ""
var at := ""
var cams: Array = []
var stride := 1                      # --stride=N: 1 quadro a cada N (golpe longo, ex. sequência de 3 golpes)
var takes: Array = []                # [{name, skill, main, off, build}]

var sc: Showcase = null
var _plan: Array = []                # por entrada da fila: {take, cam}
var _cur := -1                       # entrada sendo filmada
var _n := -1
var _last_i := -99
var _shift_i := -99
var _map_done := false
var _spot := Vector3.ZERO
var _frames: Array = []
var _st: Array = []
var _clips: Array = []
var _full_left := 0
var _cam := 24.0
var _dt_bad := 0
var _dt_seen := 0

func _ready() -> void:
	if runner:
		process_priority = -100      # antes da bancada e do jogo, como o -s antigo
		return
	if not _parse():
		get_tree().quit(2)
		return
	var keep: Array = []
	for a in OS.get_cmdline_user_args():
		if not (a.split("=")[0] in OWN):
			keep.append(a)
	var first_real := ""
	for t in takes:
		if not str(t["skill"]).begins_with("basic"):
			first_real = t["skill"]
			break
	if first_real == "":
		first_real = (GameData.classes[cls_id] as ClassDef).skill_ids[0]
	keep.append_array(["--showcase=" + cls_id, "--skill=" + first_real, "--check"])
	DevArgs._args = PackedStringArray(keep)
	DevArgs._read = true
	var r = (get_script() as GDScript).new()
	r.runner = true
	r.cls_id = cls_id
	r.out_dir = out_dir
	r.map_id = map_id
	r.at = at
	r.cams = cams
	r.stride = maxi(1, int(_val("--stride", "1")))
	r.takes = takes
	get_tree().root.add_child.call_deferred(r)
	get_tree().change_scene_to_file.call_deferred(BENCH)

func _val(name: String, def: String = "") -> String:
	var out := def
	for a in OS.get_cmdline_user_args():
		if a.begins_with(name + "="):
			out = a.substr(name.length() + 1)
	return out

func _fail(msg: String) -> bool:
	printerr("ARC_FILM: " + msg)
	return false

## Lê e confere os argumentos; erro = mensagem e sai com 2 antes de abrir o jogo.
func _parse() -> bool:
	cls_id = _val("--class")
	if not GameData.classes.has(cls_id):
		return _fail("--class=<c> obrigatório (%s)" % ", ".join(GameData.classes.keys()))
	var cls: ClassDef = GameData.classes[cls_id]
	out_dir = _val("--out")
	if out_dir == "":
		return _fail("--out=<pasta> obrigatório")
	DirAccess.make_dir_recursive_absolute(out_dir)
	map_id = _val("--map")
	if map_id != "" and not GameData.maps.has(map_id):
		return _fail("mapa '%s' não existe" % map_id)
	at = _val("--at")
	if at != "" and at.split(",").size() != 2:
		return _fail("--at=x,z")
	for c in _val("--cams", "24").split(","):
		if not c.is_valid_float():
			return _fail("--cams=<m> (distância da câmera)")
		cams.append(float(c))
	if cams.size() != 1:
		return _fail("uma câmera por processo; várias: tools/lineup/arc_film.sh ... --cams=9,24")
	var build := _val("--build")
	var raw: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--take="):
			var f := a.substr(7).split(":")
			raw.append({"name": f[0], "skill": f[1] if f.size() > 1 else "", "main": f[2] if f.size() > 2 else "",
				"off": f[3] if f.size() > 3 else "", "build": f[4] if f.size() > 4 else "", "form": f[5] if f.size() > 5 else ""})
	if raw.is_empty():
		raw.append({"name": _val("--name"), "skill": _val("--skill", "basic"), "main": _val("--main"), "off": _val("--off"), "build": "", "form": ""})
	for t in raw:
		if t["skill"] == "":
			t["skill"] = "basic"
		if t["main"] == "":
			t["main"] = _val("--main")
		if t["off"] == "":
			t["off"] = _val("--off")
		if t["build"] == "":
			t["build"] = build
		if t["form"] == "":
			t["form"] = _val("--form")
		var is_basic: bool = t["skill"] in ["basic", "basic_phys"]
		if not is_basic and not GameData.skills.has(t["skill"]):
			return _fail("skill '%s' não existe (use basic, basic_phys ou um id)" % t["skill"])
		if t["build"] == "" and is_basic:
			t["build"] = cls.builds[0]["id"]
		if t["build"] != "" and cls.build_by_id(t["build"]).is_empty():
			return _fail("build '%s' não é de %s" % [t["build"], cls_id])
		for k in ["main", "off"]:
			if t[k] != "" and t[k] != "none" and _item(t[k]) == null:
				return _fail("--%s=%s: nem item nem tipo de arma de %s" % [k, t[k], cls_id])
		if t["main"] == "none":
			return _fail("--main=none não vale")
		takes.append(t)
	return true

## Id de item, ou tipo de arma -> o comum de menor nível da classe (como a bancada).
func _item(v: String) -> ItemDef:
	if GameData.items.has(v):
		return GameData.items[v]
	var best: ItemDef = null
	for iid in GameData.items:
		var it: ItemDef = GameData.items[iid]
		if it.weapon_type != v or it.is_legendary():
			continue
		if it.class_restriction.size() > 0 and not (cls_id in it.class_restriction):
			continue
		if best == null or it.level_req < best.level_req:
			best = it
	return best

## Armas pedidas da tomada: [principal (null = a da bancada), secundária (null = a da bancada), tirar a secundária?]
func _want(t: Dictionary) -> Array:
	var cls: ClassDef = GameData.classes[cls_id]
	var b := cls.build_by_id(t["build"]) if t["build"] != "" else {}
	var main_v: String = t["main"]
	if main_v == "" and not b.is_empty():
		main_v = b["main"][0]
	var off_v: String = t["off"]
	if off_v == "" and not b.is_empty() and t["main"] != "":
		off_v = b["off"][0] if b["off"].size() > 0 else "none"
	return [_item(main_v) if main_v != "" else null, _item(off_v) if off_v not in ["", "none"] else null, off_v == "none"]

func _process(delta: float) -> void:
	if not runner:
		return
	var main = get_tree().current_scene
	if main == null or not ("camera" in main):
		return
	if sc == null:
		for c in main.get_children():
			if c is Showcase:
				sc = c
		if sc == null:
			return
		_setup_queue()
		return
	if _dt_seen < 240:
		_dt_seen += 1
		if absf(delta - 1.0 / 60.0) > 0.0005:
			_dt_bad += 1
			if _dt_bad == 1:
				push_warning("ARC_FILM: sem --fixed-fps 60 (delta %.4f): os quadros da faixa não são passos fixos" % delta)
	var p: SimEntity = Sim.player
	if p == null:
		return
	if map_id != "" and not _map_done:
		_map_done = true
		_spot = (GameData.maps[map_id] as MapDef).spawn_point
		if at != "":
			_spot = Vector3(float(at.get_slice(",", 0)), 0, float(at.get_slice(",", 1)))
		Sim._change_map(p, map_id, _spot)
		Sim._process_map_changes()
		print("ARC_FILM mapa ", map_id, " em ", _spot)
	var i: int = sc._i
	if i >= 0 and i < _plan.size():
		_cam = _plan[i]["cam"]
	if map_id != "" and sc._phase == "setup" and i != _shift_i:
		_shift_i = i
		var dlt: Vector3 = _spot - p.position
		p.position += dlt
		var moved := false
		for m in sc._dummies:
			if m.map_id != p.map_id:           # 1ª tomada: a bancada pôs os bonecos no mapa velho (antes da troca); vão junto
				Sim._change_map(m, p.map_id, _spot + (m.position - sc.SPOT))
				moved = true
			else:
				m.position += dlt
		if moved:
			Sim._process_map_changes()
	main.camera.distance = _cam
	main.controller.set_physics_process(false)
	if sc._dummies.size() > 0:
		Sim.player_cmd.aim = sc._dummies[0].position
	if sc._phase == "setup" and i >= 0 and i < _plan.size():
		_gear(p, _plan[i])
	if sc._phase == "cast" and i != _last_i:
		_last_i = i
		_cur = i
		_n = 0
		_frames.clear()
		_st.clear()
		_clips.clear()
		_full_left = 2
	if _n >= 0:
		_n += 1
		if _n >= FIRST and _n < FIRST + (CELLS + 6) * stride and (_n - FIRST) % stride == 0:
			_frames.append(_grab(main, p))
			_st.append(p.state_time if p.current_skill != null else -1.0)
			var v = main.views.get(p.id)
			_clips.append(v.anim.assigned_animation if v and v.anim else "")
		if _n == FIRST + (CELLS + 6) * stride:
			_write_strip(p)
			_n = -1

## Troca a fila da bancada pelas tomadas (antes do 1º passo dela: este nó processa primeiro).
func _setup_queue() -> void:
	if sc._i != -1:
		push_error("ARC_FILM: a bancada já começou (_i=%d); a ordem das tomadas pode sair errada" % sc._i)
	var cls: ClassDef = GameData.classes[cls_id]
	sc._queue.clear()
	var ids: Array = []
	for k in range(takes.size()):
		var t: Dictionary = takes[k]
		if not str(t["skill"]).begins_with("basic"):
			ids.append(t["skill"])
			continue
		var w: Array = _want(t)
		var mt: String = (w[0] as ItemDef).weapon_type if w[0] else ""
		var ot: String = (w[1] as ItemDef).weapon_type if w[1] else ""
		var base := GameData.basic_skill_for_class(cls, mt, ot, t["build"] if t["skill"] == "basic" else "")
		var s: SkillDef = base.duplicate()
		s.id = base.id + "__arc_%d" % k
		s.build = t["build"]
		GameData.skills[s.id] = s
		GameData.basic_skills[s.id] = s
		ids.append(s.id)
		print("ARC_FILM tomada ", k, " ", s.id, " r=", s.radius, " cone=", s.cone_angle_deg, " look=", s.look, " stop=", s.hit_stop_frames)
	for c in cams:
		for k in range(takes.size()):
			sc._queue.append([cls_id, ids[k]])
			_plan.append({"take": takes[k], "cam": c})

## Arma da tomada por cima do _gear da bancada (antes do disparo).
func _gear(p: SimEntity, plan: Dictionary) -> void:
	var w: Array = _want(plan["take"])
	var changed := false
	if w[0] and p.equipment.get(ItemDef.Slot.WEAPON) != w[0]:
		p.equipment[ItemDef.Slot.WEAPON] = w[0]
		changed = true
	if w[1] and p.equipment.get(ItemDef.Slot.OFFHAND) != w[1]:
		p.equipment[ItemDef.Slot.OFFHAND] = w[1]
		changed = true
	if w[2] and p.equipment.has(ItemDef.Slot.OFFHAND):
		p.equipment.erase(ItemDef.Slot.OFFHAND)
		changed = true
	var form: String = plan["take"].get("form", "")
	if p.form != form:
		p.form = form                      # forma da tomada (o boneco troca sozinho: EntityView._swap_form)
		changed = true
	if changed:
		p.recompute_stats()
		Events.equipment_changed.emit(p.id)
		print("ARC_FILM arma ", p.stats.weapon_type, " / ", p.stats.offhand_type)

func _grab(main, p: SimEntity) -> Image:
	var vp := get_viewport()
	var img := vp.get_texture().get_image()
	var cam: Camera3D = main.camera.cam
	var focus: Vector3 = p.position + Vector3(0, 0.8, 0)
	if sc._dummies.size() > 0:
		focus = focus.lerp(sc._dummies[0].position, 0.4)
	var c := cam.unproject_position(focus) * (Vector2(img.get_size()) / vp.get_visible_rect().size)
	var frac := 0.62 if _cam <= 10.0 else 0.36
	var side := int(img.get_height() * frac)
	var x := clampi(int(c.x) - side / 2, 0, img.get_width() - side)
	var y := clampi(int(c.y) - side / 2, 0, img.get_height() - side)
	var crop := img.get_region(Rect2i(x, y, side, side))
	crop.resize(CELL, CELL, Image.INTERPOLATE_BILINEAR)
	# tela inteira: o 2º quadro com state_time >= preparo = o logo depois do tick do dano (o efeito já saiu)
	var s: SkillDef = p.current_skill
	if _full_left > 0 and s != null and p.state_time >= s.startup - 0.001:
		if _full_left == 1:
			img.save_png("%s/full_%s_%s_imp.png" % [out_dir, _tag(), _name(p)])
		_full_left -= 1
	return crop

func _tag() -> String:
	return "cam%s" % str(_cam).trim_suffix(".0")

## Rótulo da tomada: --name/1º campo do --take, senão <tipo da arma>_<basic|basicPhys|id sem prefixo>.
func _name(p: SimEntity) -> String:
	var t: Dictionary = _plan[_cur]["take"]
	var nm: String = t["name"]
	if nm == "":
		var sk: String = t["skill"]
		var short := "basic" if sk == "basic" else ("basicPhys" if sk == "basic_phys" else sk.substr(sk.find("_") + 1))
		nm = p.stats.weapon_type + "_" + short
	return ((map_id + "_") if map_id != "" else "") + nm

func _write_strip(p: SimEntity) -> void:
	var rows := CELLS / COLS
	var sheet := Image.create(CELL * COLS, CELL * rows, false, Image.FORMAT_RGBA8)
	var sid: String = sc._queue[_cur][1]
	var s: SkillDef = GameData.skills.get(sid)
	var startup := s.startup if s else 0.12
	var imp := -1
	var lines: Array = []
	for k in range(mini(CELLS, _frames.size())):
		var f: Image = _frames[k]
		f.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(f, Rect2i(0, 0, CELL, CELL), Vector2i((k % COLS) * CELL, (k / COLS) * CELL))
		lines.append("%d st=%.3f clip=%s" % [k, _st[k], _clips[k]])
		if imp < 0 and float(_st[k]) >= startup - 0.001:
			imp = k
	if imp >= 0:
		var ix := (imp % COLS) * CELL
		var iy := (imp / COLS) * CELL
		for b in range(4):
			sheet.fill_rect(Rect2i(ix, iy + b, CELL, 1), Color(1, 0.85, 0.2))
			sheet.fill_rect(Rect2i(ix, iy + CELL - 1 - b, CELL, 1), Color(1, 0.85, 0.2))
	var nm := _name(p)
	sheet.save_png("%s/strip_%s_%s.png" % [out_dir, _tag(), nm])
	var f2 := FileAccess.open("%s/strip_%s_%s.txt" % [out_dir, _tag(), nm], FileAccess.WRITE)
	f2.store_string("\n".join(lines) + "\nimpact_cell=%d\nskill=%s startup=%.2f\n" % [imp, sid, startup])
	print("ARC_FILM faixa ", _tag(), " ", nm, " impact_cell=", imp)
