extends Node
## Auditoria de números das skills de classe (só dados, sem lutar): poder efetivo por recarga, comparado com as irmãs
## da mesma classe e faixa de nível. Uso: --headless --path . tools/tests/skill_audit.tscn -- [--class=paladin,...]
## Poder efetivo = power + dano no tempo (dps × duração / 20, a escala do MATK) + bônus de controle; área conta ×1,5.
## Saída: "AUDIT <classe> <skill> nv=N ef=X ef/cd=Y mediana=Z" e "WEAK ..." quando ef/cd < 60% da mediana da faixa (±6 níveis).

const WEAK_RATIO := 0.6

static func effective(s: SkillDef) -> float:
	var ef := s.power
	if s.effects.get("channel") is Dictionary:      # canalização: cada pulso bate o power inteiro
		ef *= float(s.effects["channel"].get("ticks", 3))
	var dot = s.effects.get("dot")
	if dot is Dictionary:
		ef += float(dot.get("dps", 0)) * float(dot.get("duration", 0)) / 20.0
	for cc in ["stun", "root"]:
		var c = s.effects.get(cc)
		if c is Dictionary:
			ef += 0.3 * float(c.get("duration", 0))
	if s.effects.get("slow") is Dictionary:
		ef += 0.1
	if s.effects.has("combust"):
		ef += 0.6                      # detonação: vale mais com queimaduras no alvo
	if s.effects.has("bounce"):
		ef *= 1.0 + 0.5 * maxf(0.0, float(s.effects["bounce"].get("count", 1)) - 1.0) * float(s.effects["bounce"].get("falloff", 0.8))
	var area: bool = (s.target == SkillDef.Target.SELF and s.radius > 0.0) or s.target == SkillDef.Target.CONE \
		or (s.target == SkillDef.Target.GROUND and s.radius >= 2.0) or (s.target == SkillDef.Target.TARGET and s.radius > 1.0) or s.projectile_pierce
	if area:
		ef *= 1.5
	return ef

static func damaging(s: SkillDef) -> bool:
	return s.kind in [SkillDef.Kind.PHYSICAL, SkillDef.Kind.MAGICAL] and s.power > 0.0 and not s.effects.has("trap") and not s.effects.has("pet_command")

func _ready() -> void:
	await get_tree().process_frame
	var only: Array = Array(DevArgs.value("--class").split(",")) if DevArgs.flag("--class") else []
	var weak := 0
	for cid in GameData.classes:
		if not only.is_empty() and not (cid in only):
			continue
		var list: Array = []
		for sid in GameData.classes[cid].skill_ids:
			var s: SkillDef = GameData.skills[sid]
			if damaging(s):
				list.append(s)
		for s in list:
			var rates: Array = []
			for o in list:
				if absi(o.unlock_level - s.unlock_level) <= 6:
					rates.append(effective(o) / maxf(1.0, o.cooldown))
			rates.sort()
			var med: float = rates[rates.size() / 2]
			var r := effective(s) / maxf(1.0, s.cooldown)
			var tag := "WEAK " if r < med * WEAK_RATIO else "AUDIT"
			if tag == "WEAK ":
				weak += 1
			print("%s %-12s %-22s nv=%2d alvo=%d ef=%.2f cd=%.1f ef/cd=%.3f mediana=%.3f (%.0f%%)" % [tag, cid, s.id, s.unlock_level, s.target, effective(s), s.cooldown, r, med, 100.0 * r / med])
	print("AUDIT_END weak=%d" % weak)
	get_tree().quit()
