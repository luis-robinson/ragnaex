class_name SkillSheet
## Ficha de uma skill para a janela de Skills (J): os números de AGORA do personagem, com rank, teia, talentos e
## equipamento (ProgressionSystem.resolve_skill + Stats). Só lê a sim; nada muda o estado. Mesmas contas do
## WorldSim._apply_skill/_apply_effects e do Combat.calc_damage, sem o sorteio (média, faixa e crítico).

const STAT_NAMES := {"atk_pct": "ATK", "matk_pct": "MATK", "def_pct": "DEF", "mdef_pct": "MDEF", "crit": "crítico", "aspd_pct": "vel. de ataque",
	"speed_pct": "velocidade", "heal_pct": "cura", "lifesteal": "roubo de vida", "evasion": "esquiva", "hit_poison": "veneno por golpe",
	"hp_pct": "vida", "block_chance": "bloqueio", "dr_pct": "dano recebido"}
const PCT_FLAT := ["crit", "lifesteal", "evasion", "block_chance"]          # somam pontos, não %
const TARGETS := {SkillDef.Target.SELF: "em você", SkillDef.Target.DIRECTION: "na direção", SkillDef.Target.GROUND: "no chão",
	SkillDef.Target.CONE: "em cone", SkillDef.Target.TARGET: "no alvo"}

## A skill como ela sai agora (rank, teia, talentos de classe, ascensão).
static func resolved(p: SimEntity, s: SkillDef) -> SkillDef:
	return ProgressionSystem.resolve_skill(Sim, p, s)

## Poder final do golpe (sem sorteio): rank × bônus de skill/conjunto × elemento × escudo.
static func power_of(p: SimEntity, r: SkillDef) -> float:
	var lv := p.mastery_of(r.id)
	return r.power_at(lv) * p.stats.skill_power_mult(r.id) * p.stats.element_mult(r.elements) * ShieldSystem.shield_power(Sim, p, r)

## Dano médio por acerto contra alvo sem defesa (o boneco de treino): {avg, lo, hi, crit, crit_pct, hits}.
static func damage_of(p: SimEntity, r: SkillDef) -> Dictionary:
	var magical := r.kind == SkillDef.Kind.MAGICAL or r.kind == SkillDef.Kind.SUMMON
	var atk: float = p.stats.matk if magical else p.stats.patk
	var avg := atk * power_of(p, r) * (1.0 + p.stats.vit_dmg_pct / 100.0)
	var hits := 1
	if r.effects.get("strikes") is Dictionary:
		hits = Combat.strike_count(r.effects["strikes"])
	return {"avg": avg, "lo": avg * (1.0 - Balance.DMG_VARIANCE), "hi": avg * (1.0 + Balance.DMG_VARIANCE), "crit": avg * p.stats.crit_mult(),
		"crit_pct": p.stats.crit_mag if magical else p.stats.crit_phys, "hits": hits}

## Linhas [rótulo, valor] da ficha, na ordem da janela.
static func rows(p: SimEntity, s: SkillDef) -> Array:
	var r := resolved(p, s)
	var lv := p.mastery_of(r.id)
	var out: Array = []
	var longer: float = 1.0 + p.stats.buff_duration / 100.0
	if r.power > 0.0 and r.kind == SkillDef.Kind.HEAL:
		var heal := p.stats.matk * power_of(p, r) * p.stats.heal_power
		out.append(["Cura", "%d  (crítico %d)" % [roundi(heal), roundi(heal * p.stats.crit_mult())]])
	elif r.power > 0.0 and r.kind != SkillDef.Kind.BUFF:
		var d := damage_of(p, r)
		var txt := "%d  (%d-%d)" % [roundi(d["avg"]), roundi(d["lo"]), roundi(d["hi"])]
		if int(d["hits"]) > 1:
			txt += "  em %d golpes" % int(d["hits"])
		out.append(["Dano", txt])
		out.append(["Crítico", "%d  (%.0f%% de chance)" % [roundi(d["crit"]), float(d["crit_pct"])]])
	out.append(["Custo", "%d MP" % roundi(r.mp_cost_at(lv))])
	out.append(["Recarga", _secs(r.cooldown_at(lv))])
	if r.startup >= 0.25:
		out.append(["Preparo", _secs(r.startup)])
	var reach := _reach(r)
	if reach != "":
		out.append(["Alcance", reach])
	var area := _area(r)
	if area != "":
		out.append(["Área", area])
	if r.max_targets > 0 and r.max_targets < 99 and r.kind != SkillDef.Kind.BUFF:
		out.append(["Alvos", "até %d" % r.max_targets])
	out.append_array(_effect_rows(p, r, longer))
	return out

static func _secs(t: float) -> String:
	return ("%.1f s" % t).replace(".", ",") if t < 10.0 and not is_equal_approx(t, roundf(t)) else "%d s" % roundi(t)

static func _m(x: float) -> String:
	return ("%.1f m" % x).replace(".", ",")

static func _reach(r: SkillDef) -> String:
	match r.target:
		SkillDef.Target.SELF, SkillDef.Target.CONE:
			return ""
		SkillDef.Target.DIRECTION:
			return _m(r.range) + (" (projétil)" if r.projectile_speed > 0.0 else "")
	return _m(r.range)

static func _area(r: SkillDef) -> String:
	match r.target:
		SkillDef.Target.CONE:
			return "cone de %s, %d°" % [_m(r.radius), roundi(r.cone_angle_deg)]
		SkillDef.Target.SELF:
			return "%s ao redor" % _m(r.radius) if r.radius > 0.0 else ""
		SkillDef.Target.DIRECTION:
			return "faixa de %s" % _m(maxf(r.line_width, r.radius * 2.0)) if r.projectile_speed <= 0.0 or r.radius > 0.6 else ""
	return "raio de %s" % _m(r.radius) if r.radius > 0.0 else ""

## Efeitos com os números de agora (duração com a Bênção do Sacerdote, dano no tempo com MATK).
static func _effect_rows(p: SimEntity, r: SkillDef, longer: float) -> Array:
	var out: Array = []
	var fx: Dictionary = r.effects
	if fx.get("buff") is Dictionary:
		var b: Dictionary = fx["buff"]
		var parts: Array = []
		for k in b:
			if STAT_NAMES.has(k) and float(b[k]) != 0.0:
				var v := float(b[k])
				parts.append("%s%s%s %s" % ["+" if v > 0 else "", ("%.0f" % v), "" if k in PCT_FLAT else "%", STAT_NAMES[k]])
		var dur := "ligado até desligar" if b.get("toggle", false) else "por " + _secs(float(b.get("duration", 10)) * longer)
		out.append(["Buff", ", ".join(parts) + ("  " if parts.size() > 0 else "") + dur])
	if fx.get("shield") is Dictionary:
		var sh: Dictionary = fx["shield"]
		var amt := p.stats.max_hp * float(sh.get("amount_pct_hp", 20)) / 100.0
		out.append(["Escudo", "%d de vida (%d%%) por %s" % [roundi(amt), roundi(float(sh.get("amount_pct_hp", 20))), _secs(float(sh.get("duration", 5)) * longer)]])
	if fx.get("dot") is Dictionary:
		var d: Dictionary = fx["dot"]
		var db: Array = ClassTalentSystem.dot_boost(p)
		var dps := float(d.get("dps", 5)) * (p.stats.matk / 20.0) * float(db[1]) * p.stats.dot_mult()
		var t := float(d.get("duration", 4)) * float(db[0])
		var what := "queimadura" if d.get("fire", false) or r.elements.has("fire") or r.vfx == "fire" else "dano no tempo"
		out.append(["Efeito", "%s: %d por s por %s (%d no total)" % [what, roundi(dps), _secs(t), roundi(dps * t)]])
	if fx.get("slow") is Dictionary:
		var sl: Dictionary = fx["slow"]
		var extra := ", -%d%% vel. de ataque" % roundi(Balance.FROST_ASPD_SLOW) if sl.get("frost", false) else ""
		out.append(["Efeito", "lentidão de %d%%%s por %s" % [roundi(float(sl.get("pct", 30))), extra, _secs(float(sl.get("duration", 2)))]])
	for k in [["stun", "atordoa"], ["root", "prende"]]:
		if fx.get(k[0]) is Dictionary:
			out.append(["Efeito", "%s por %s" % [k[1], _secs(float(fx[k[0]].get("duration", 1)))]])
	if fx.get("summon") is Dictionary:
		var sm: Dictionary = fx["summon"]
		var md: MonsterDef = GameData.monsters.get(str(sm.get("monster_id", "")))
		var dur := float(sm.get("duration", 0.0))
		out.append(["Invoca", "%d× %s%s" % [int(sm.get("count", 1)), md.name if md else "?", (" por " + _secs(p.stats.summon_time_of(dur))) if dur > 0.0 else " (fica)"]])
	if fx.has("heal_pct_of_dmg"):
		out.append(["Efeito", "cura %d%% do dano causado" % roundi(float(fx["heal_pct_of_dmg"]) * 100.0)])
	if fx.has("mend_pct_of_dmg"):
		out.append(["Efeito", "%d%% do dano cura o aliado mais ferido" % roundi(float(fx["mend_pct_of_dmg"]) * 100.0)])
	if fx.has("heal_pct"):
		out.append(["Efeito", "cura %d%% da vida" % roundi(float(fx["heal_pct"]))])
	if fx.has("dash"):
		out.append(["Efeito", "avança %s" % _m(float(fx["dash"]))])
	if fx.has("stealth"):
		out.append(["Efeito", "furtivo por %s" % _secs(float(fx["stealth"]))])
	if fx.has("taunt"):
		out.append(["Efeito", "provoca os inimigos em volta"])
	if fx.get("knockback") != null:
		out.append(["Efeito", "empurra"])
	return out
