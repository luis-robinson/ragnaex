extends Node
## Revisão numérica dos clipes (laço sobre todos os modelos): para cada clipe de cada GLB mede
##   seam   = costura do loop (maior diferença de giro de osso entre o 1º e o último quadro, graus)
##   peak   = maior giro de osso num quadro de 60 Hz (graus) e o osso
##   travel = giro total somado dos ossos do tronco/braços/pernas (quanto o boneco se mexe; clipe "duro" = pouco)
##   hand   = pico de velocidade da mão da arma (m/s) e em que quadro de 24 fps ele cai (perto do IMPACT = golpe com estalo)
##   hold   = quadros quase parados (< 2°/quadro em tudo) no clipe — pose "morta"
##   sink   = quanto a cabeça desce abaixo da altura de repouso (m; afundar no chão = cabeça < 0,45 m)
##   --headless --path . tools/tests/anim_probe.tscn -- [--models=kit_paladin_male,mob_wolf] [--clips=idle,run] [--csv=<arquivo>]
## Sem --models: kit do paladino (macho e fêmea), formas e todos os mob_*.

const STEP := 1.0 / 60.0
var _rows: Array = []

func _ready() -> void:
	var models: Array = []
	var only_clips: Array = []
	var csv := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--models="):
			models = a.get_slice("=", 1).split(",")
		if a.begins_with("--clips="):
			only_clips = a.get_slice("=", 1).split(",")
		if a.begins_with("--csv="):
			csv = a.get_slice("=", 1)
	if models.is_empty():
		models = ["kit_paladin_male", "kit_bishop_female", "form_wolf", "form_bear", "form_demon"]
		for f in DirAccess.get_files_at("res://assets/models"):
			if f.begins_with("mob_") and f.ends_with(".glb"):
				models.append(f.get_basename())
	print("model;clip;len;loop;seam;peak;peak_bone;travel;hand_peak;hand_frame;hold;head_min;head_rest")
	for m in models:
		_probe(m, only_clips)
	if csv != "":
		var fa := FileAccess.open(csv, FileAccess.WRITE)
		for r in _rows:
			fa.store_line(r)
	get_tree().quit()

func _probe(model: String, only_clips: Array) -> void:
	var ps: PackedScene = load("res://assets/models/%s.glb" % model)
	if ps == null:
		printerr("sem modelo ", model)
		return
	var inst: Node3D = ps.instantiate()
	add_child(inst)
	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	var sk: Skeleton3D = inst.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null:
		var l := inst.find_children("*", "Skeleton3D", true, false)
		sk = l[0] if l.size() > 0 else null
	if ap == null or sk == null:
		inst.queue_free()
		return
	var head := sk.find_bone("head")
	var hand := sk.find_bone("hand.R")
	if hand < 0:
		hand = sk.find_bone("arm_r")
	var head_rest := sk.get_bone_global_rest(head).origin.y if head >= 0 else 0.0
	for clip in ap.get_animation_list():
		if not only_clips.is_empty() and not (clip in only_clips):
			continue
		var an := ap.get_animation(clip)
		var loop: bool = clip in ["idle", "idle_bow", "idle_staff", "run", "block", "block_shield", "fall"]
		ap.play(clip)
		var prev: Array = []
		var prev_hand := Vector3.ZERO
		var t := 0.0
		var peak := 0.0
		var peak_bone := ""
		var travel := 0.0
		var hand_peak := 0.0
		var hand_t := 0.0
		var hold := 0
		var head_min := 99.0
		var first: Array = []
		var last: Array = []
		while t <= an.length + 0.0001:
			ap.seek(t, true)
			sk.force_update_all_bone_transforms() if sk.has_method("force_update_all_bone_transforms") else null
			var cur: Array = []
			for b in sk.get_bone_count():
				cur.append(sk.get_bone_pose_rotation(b))
			var hp := sk.get_bone_global_pose(hand).origin if hand >= 0 else Vector3.ZERO
			if head >= 0:
				head_min = minf(head_min, sk.get_bone_global_pose(head).origin.y)
			if not prev.is_empty():
				var fmax := 0.0
				for b in cur.size():
					var d := rad_to_deg((prev[b] as Quaternion).angle_to(cur[b]))
					travel += d
					if d > fmax:
						fmax = d
					if d > peak:
						peak = d
						peak_bone = sk.get_bone_name(b)
				if fmax < 0.5:
					hold += 1
				var hs := hp.distance_to(prev_hand) / STEP
				if hs > hand_peak:
					hand_peak = hs
					hand_t = t
			else:
				first = cur
			prev = cur
			prev_hand = hp
			last = cur
			t += STEP
		var seam := 0.0
		for b in first.size():
			seam = maxf(seam, rad_to_deg((first[b] as Quaternion).angle_to(last[b])))
		var row := "%s;%s;%.2f;%s;%.1f;%.0f;%s;%.0f;%.2f;%d;%.2f;%.2f;%.2f" % [model, clip, an.length, "L" if loop else "-", seam, peak, peak_bone,
			travel, hand_peak, int(round(hand_t * 24.0)) + 1, hold * STEP, head_min, head_rest]
		print(row)
		_rows.append(row)
	inst.queue_free()
