extends Node
## Clipes dos chefes: para cada chefe da sonda (boss_probe.BOSSES), monta o boneco de verdade (EntityView) e mostra,
## para cada skill do kit (base + fases), o clipe que o jogo pede e o que o modelo toca de fato.
##   godot --headless --path . tools/tests/boss_anim_probe.tscn [-- --boss=<id>,...]
## Saída: "ANIM <chefe> <skill> quer=<clipe> toca=<clipe> [FLAG]"; FLAG = nenhum clipe, ou golpe especial caindo no
## mesmo clipe do básico (o jogador não distingue o aviso do golpe comum).

func _ready() -> void:
	await get_tree().process_frame
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--boss="):
			only = Array(a.get_slice("=", 1).split(","))
	var probe = load("res://tools/tests/boss_probe.gd")
	var flags := 0
	for bid in probe.BOSSES:
		if not (only.is_empty() or bid in only):
			continue
		var r := check_boss(bid, self)
		for line in r["lines"]:
			print(line)
		flags += int(r["flags"])
	print("ANIM_FLAGS %d" % flags)
	print("ANIM_END")
	get_tree().quit()

## Monta o chefe (boneco de verdade, filho de `parent`) e confere o clipe de cada skill. Devolve {lines, flags}.
static func check_boss(bid: String, parent: Node) -> Dictionary:
	var md: MonsterDef = GameData.monsters[bid]
	var lines: Array = []
	var flags := 0
	var e := SimEntity.new()
	e.kind = SimEntity.Kind.MONSTER
	e.monster_def = md
	e.name = md.name
	e.level = md.level
	e.recompute_stats()
	var v := EntityView.new()
	parent.add_child(v)
	v.setup(e, false)
	if v.anim == null:
		v.queue_free()
		return {"lines": ["ANIM %-18s sem AnimationPlayer FLAG" % bid], "flags": 1}
	var basic := v._clip("attack")
	var kit: Array = Array(md.skill_ids)
	for ph in md.phases:
		for sid in ph.get("skills", []):
			if not kit.has(sid):
				kit.append(sid)
	for sid in kit:
		var s: SkillDef = GameData.skills.get(sid)
		if s == null:
			continue
		var want := v._action_clip(s)
		var clip := v._clip(want)
		if clip == "":
			clip = v._clip("cast" if s.kind != SkillDef.Kind.PHYSICAL else "attack")
		if clip == "":
			clip = v._clip("attack")
		var shot := md.ranged and s.kind == SkillDef.Kind.PHYSICAL and s.target == SkillDef.Target.TARGET     # tiro de arqueiro: o gesto do básico é o certo
		var bad := clip == "" or (clip == basic and anim_count(v) > 3 and not shot)
		if bad:
			flags += 1
		lines.append("ANIM %-18s %-22s quer=%-14s toca=%-14s%s" % [bid, sid, want, clip, (" FLAG" if bad else "")])
	v.queue_free()
	return {"lines": lines, "flags": flags}

static func anim_count(v: EntityView) -> int:
	return v.anim.get_animation_list().size() if v.anim else 0
