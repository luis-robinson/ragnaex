class_name BossSignatures
extends RefCounted
## Assinaturas dos chefes (GDD design/gdd/act2-boss-signatures.md). Regras compartilhadas: R-A hazard v2 (formas
## circle/line/ring, invertido, chão que fica, fortalecer), R-B marca que segue a vítima (spread/soak), R-C canal
## interrompível, R-D sequência; únicas: R-E cobertura (Troll Rei), R-F cópias (Shazka), R-G Muralha (Ghar).
## Sem estado próprio: tudo mora em m["hazards"], m["covers"], SimEntity.sig e sim.sig_stats (contagem das sondas).

const CHANNEL_BUFF := "boss_channel"
const WALL_BUFF := "ghar_wall"
const TEMPER_BUFF := "boss_temper"
const FRENZY_BUFF := "mob_frenzy"
const TORN_DEBUFF := "drum_torn"
## Ids de skill_effect que não são skills (som/efeito leem): canal quebrado, contragolpe da Muralha, pedra que rachou.
const CHANNEL_BREAK_FX := "boss_channel_break"
const COUNTER_FX := "mob_ghar_counter"
const COVER_BREAK_FX := "boss_cover_break"
const DECOY_FX := "boss_decoy_pop"               # cópias aparecem / somem (fumaça)
## Olhar Que Julga (Condessa, R-E com Espelhos de Pé): espelhos sobem / um espelho racha depois de proteger.
const MIRROR_RISE_FX := "boss_mirror_rise"
const MIRROR_CRACK_FX := "boss_mirror_crack"

## Rascunho do laço de update_hazards (não é estado: esvaziado no fim de cada laço). Reaproveitado para não alocar
## um Array por tique (revisão m5); um tique roda por vez, então não há reentrada.
static var _hz_scan: Array = []

# ---------------------------------------------------------------------------
# Comum
# ---------------------------------------------------------------------------

static func has_buff(e: SimEntity, id: String) -> bool:
	for b in e.buffs:
		if b.get("id") == id:
			return true
	return false

## Soma um número da sonda (boss_probe): sim.sig_stats[key] += n.
static func stat(sim: WorldSim, key: String, n: float = 1.0) -> void:
	sim.sig_stats[key] = float(sim.sig_stats.get(key, 0.0)) + n

## Arma as assinaturas: recarga inicial (a luta começou / chegaram com a fase). `ids` vazio = todas as que ele tem.
static func arm(e: SimEntity, ids: Array, delay: float) -> void:
	for s: SkillDef in e.skills:
		if s != null and s.boss_signature and (ids.is_empty() or s.id in ids):
			e.cooldowns[s.id] = maxf(float(e.cooldowns.get(s.id, 0.0)), delay)

## Põe um hazard no mapa com id próprio (a apresentação e os bots seguem pelo id).
static func add_hazard(m: Dictionary, h: Dictionary, now: float = 0.0) -> Dictionary:
	h["t0"] = now                                    # quando foi posto (o aviso enche de t0 até at)
	if not m.has("hazards"):
		m["hazards"] = []
	m["hazard_seq"] = int(m.get("hazard_seq", 0)) + 1
	h["id"] = m["hazard_seq"]
	if not h.has("shape"):
		h["shape"] = "circle"
	m["hazards"].append(h)
	return h

## Ponto `p` (com folga `pad`) dentro da forma do hazard?
static func inside(h: Dictionary, p: Vector3, pad: float = 0.0) -> bool:
	var c: Vector3 = h["pos"]
	var d := Vector2(p.x - c.x, p.z - c.z)
	match str(h.get("shape", "circle")):
		"line":
			var dir: Vector3 = h["dir"]
			var f := Vector2(dir.x, dir.z)
			var along := d.dot(f)
			return along >= -pad and along <= float(h["length"]) + pad and absf(f.cross(d)) <= float(h["width"]) * 0.5 + pad
		"ring":
			var l := d.length()
			return l + pad >= float(h["inner"]) and l - pad <= float(h["radius"])
		_:
			return d.length() <= float(h["radius"]) + pad

## Para onde sair do hazard (Vector2.ZERO = fora): faixa = de lado; anel = pelo lado mais perto; círculo = para longe do centro.
static func escape(h: Dictionary, p: Vector3, pad: float) -> Vector2:
	if not inside(h, p, pad):
		return Vector2.ZERO
	var c: Vector3 = h["pos"]
	var d := Vector2(p.x - c.x, p.z - c.z)
	match str(h.get("shape", "circle")):
		"line":
			var dir: Vector3 = h["dir"]
			var f := Vector2(dir.x, dir.z)
			return Vector2(-f.y, f.x) if f.cross(d) >= 0.0 else Vector2(f.y, -f.x)
		"ring":
			var l := d.length()
			if l < 0.05:
				return Vector2.RIGHT
			return -d.normalized() if l - float(h["inner"]) < float(h["radius"]) - l and float(h["inner"]) > 0.5 else d.normalized()
		_:
			return d.normalized() if d.length() > 0.05 else Vector2.RIGHT

## Ainda vai cair um golpe de chão do chefe (só uma mecânica de chão por vez: a chuva espera as ilhas).
static func ground_busy(m: Dictionary, e: SimEntity) -> bool:
	for h in m.get("hazards", []):
		if int(h["owner"]) == e.id and h.get("invert", false):
			return true
	return false

## Multiplicador de dano da Têmpera (F-S3), entra no MobSystem._apply_fury.
static func fury_mult(e: SimEntity) -> float:
	return 1.0 + Balance.KRAGMAR_TEMPER_STEP * e.buff_stacks(TEMPER_BUFF)

static func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, 0.0, p.z)

# ---------------------------------------------------------------------------
# R-A: chuva com forma (circle/line/ring) e chão que fica — chamada por MobSystem.place_barrage
# ---------------------------------------------------------------------------

## Campos extra do hazard pela "barrage" da skill (linger, tique, fortalecer).
static func barrage_extra(bd: Dictionary) -> Dictionary:
	var x := {}
	if float(bd.get("linger", 0.0)) > 0.0:
		x["linger"] = float(bd["linger"])
		x["tick_power"] = float(bd.get("tick_power", 0.2))
	if bd.get("empower") is Dictionary:
		x["empower"] = bd["empower"]
	if bd.get("pull") is Dictionary:
		x["press"] = true                            # sonda: quem a Prensa esmagou (press_hits)
	return x

## Prensa (Dona Vindima): antes do círculo em volta dela, puxa para junto todo personagem a até `radius` m
## (gancho de chefe, `pull` de _apply_effects; quem resiste a controle fica). Chamada por MobSystem.place_barrage (`barrage.pull`).
static func pull_in(sim: WorldSim, e: SimEntity, d: Dictionary) -> void:
	var gap := float(d.get("gap", Balance.BOSS_PULL_GAP))
	var n := 0
	for o in MobSystem.victims(sim, e, float(d.get("radius", Balance.ACT3_PRESS_PULL_R))):
		sim._apply_effects(e, o, {"pull": {"gap": gap}}, 0.0)
		n += 1
	stat(sim, "press_pulled", n)
	stat(sim, "presses")

## Faixas paralelas (shape "line"): `count` faixas na direção chefe→mira, uma sobre a mira, separadas por width + gap;
## caem em sequência (`stagger` s entre elas).
static func place_lines(sim: WorldSim, e: SimEntity, s: SkillDef, aim: Vector3, power: float, bd: Dictionary, fx: Dictionary) -> void:
	var m: Dictionary = sim.maps[e.map_id]
	var dir := _ground(aim - e.position)
	dir = dir.normalized() if dir.length() > 0.05 else e.forward()
	var side := Vector3(-dir.z, 0, dir.x)
	var n := int(bd.get("count", 3))
	var w := float(bd.get("width", 3.0))
	var gap := float(bd.get("gap", 3.0))
	var length := float(bd.get("length", 24.0))
	var delay := float(bd.get("delay", 2.0))
	var stagger := float(bd.get("stagger", 0.6))
	for i in range(n):
		var off := 0.0                                 # 0, +1, -1, +2...: a 1ª sobre a mira
		if i > 0:
			off = float((i + 1) / 2) * (w + gap) * (1.0 if i % 2 == 1 else -1.0)
		var start := _ground(aim) - dir * (length * 0.5) + side * off
		var h := {"owner": e.id, "pos": start, "dir": dir, "length": length, "width": w, "shape": "line", "radius": length,
			"at": sim.time + delay + stagger * i, "power": power, "kind": s.kind, "effects": fx, "skill": s.id, "sig_line": true}
		h.merge(barrage_extra(bd))
		add_hazard(m, h, sim.time)
	if bd.has("say"):
		MobSystem.boss_say(sim, e, str(bd["say"]))
	stat(sim, "stampedes")

## Cortejo de Lâminas (Vessaline, GDD ato3 §4.1): `count` faixas ENCADEADAS (a k+1 começa onde a k acaba), cada uma de
## `length` m na direção de uma vítima sorteada (nunca o tanque; nunca a mesma duas vezes seguidas). Aparecem todas juntas
## (lê-se a coreografia inteira); a 1ª cai em `delay` s e as outras a cada `stagger` s; quando uma cai o chefe investe até o
## fim dela (`dash_to`, update_hazards) e a cauda deixa a faixa `linger` s. Faixa encurta para não sair do chão andável nem
## de `arena` m da casa do chefe.
static func place_cortege(sim: WorldSim, e: SimEntity, s: SkillDef, power: float, bd: Dictionary, fx: Dictionary) -> void:
	var m: Dictionary = sim.maps[e.map_id]
	var pool: Array = MobSystem.victims(sim, e).filter(func(o): return o.is_character())
	if pool.size() > 1:
		pool = pool.filter(func(o): return o.id != e.aggro_target)
	if pool.is_empty():
		pool = MobSystem.victims(sim, e)
	if pool.is_empty():
		return
	var n := int(bd.get("count", 4))
	var length := float(bd.get("length", 10.0))
	var w := float(bd.get("width", 2.0))
	var delay := float(bd.get("delay", 1.5))
	var stagger := float(bd.get("stagger", 0.7))
	var arena := float(bd.get("arena", 0.0))
	var home := _ground(e.home_position)
	var at := _ground(e.position)
	var last: SimEntity = null
	for i in range(n):
		var cand: Array = pool.filter(func(o): return o != last) if pool.size() > 1 else pool
		var v: SimEntity = cand[sim.rng.randi() % cand.size()]
		last = v
		var dir := _ground(v.position) - at
		dir = dir.normalized() if dir.length() > 0.5 else e.forward().rotated(Vector3.UP, sim.rng.randf_range(0.6, 2.5))
		var len := length
		while len > 2.0 and (not MapGeometry.is_walkable(sim, at + dir * len, m["def"], e.radius * 0.6) or (arena > 0.0 and (at + dir * len).distance_to(home) > arena)):
			len -= 1.0
		var h := {"owner": e.id, "pos": at, "dir": dir, "length": len, "width": w, "shape": "line", "radius": len,
			"at": sim.time + delay + stagger * i, "power": power, "kind": s.kind, "effects": fx, "skill": s.id, "sig_line": true,
			"dash_to": at + dir * len, "cortege": i, "aim_at": v.id}
		h.merge(barrage_extra(bd))
		add_hazard(m, h, sim.time)
		at = at + dir * len
	if bd.has("say"):
		MobSystem.boss_say(sim, e, str(bd["say"]))
	stat(sim, "corteges")

## A faixa do Cortejo caiu: o chefe investe até o fim dela (com colisão; parado por controle ele fica).
static func _cortege_dash(sim: WorldSim, m: Dictionary, owner: SimEntity, h: Dictionary) -> void:
	if owner.state == SimEntity.State.STUNNED or owner.has_debuff("root"):
		return
	var to: Vector3 = h["dash_to"]
	var d := _ground(to - owner.position)
	if d.length() < 0.1:
		return
	owner.face_towards(to)
	sim._move(owner, d, m)

## Anéis (shape "ring"): `count` anéis em volta do chefe, cada um `width` m de largura, de dentro para fora (um a cada
## `spacing` m; sem spacing = colados), `stagger` s um do outro. `pulses` pisadas (Ondas da Montanha): a pisada k sai
## `pulse_gap` s depois da anterior e anda `pulse_shift` m para fora a cada pisada ímpar (o lugar seguro muda: ritmo).
static func place_rings(sim: WorldSim, e: SimEntity, s: SkillDef, power: float, bd: Dictionary, fx: Dictionary) -> void:
	var m: Dictionary = sim.maps[e.map_id]
	var n := int(bd.get("count", 3))
	var w := float(bd.get("width", 2.0))
	var step := float(bd.get("spacing", w))
	var start := float(bd.get("inner", 0.0))
	var delay := float(bd.get("delay", 1.5))
	var stagger := float(bd.get("stagger", 0.5))
	var pulses := int(bd.get("pulses", 1))
	var pgap := float(bd.get("pulse_gap", 1.2))
	var shift := float(bd.get("pulse_shift", 0.0))
	for k in range(pulses):
		var r0 := start + (shift if k % 2 == 1 else 0.0)
		for i in range(n):
			var h := {"owner": e.id, "pos": _ground(e.position), "shape": "ring", "inner": r0 + step * i, "radius": r0 + step * i + w,
				"at": sim.time + delay + pgap * k + stagger * i, "power": power, "kind": s.kind, "effects": fx, "skill": s.id, "sig_ring": true, "pulse": k, "core": e.radius}
			h.merge(barrage_extra(bd))
			add_hazard(m, h, sim.time)
	if bd.has("say"):
		MobSystem.boss_say(sim, e, str(bd["say"]))
	stat(sim, "ring_series")

# ---------------------------------------------------------------------------
# R-A invertido: ilhas (Maré Cheia)
# ---------------------------------------------------------------------------

## N ilhas (uma no tanque, as outras a near_min..near_max m do chefe, sem cair sobre outro aviso). Depois de `delay` s
## quem estiver a BOSS_INVERT_RANGE m do chefe e fora de todas leva o golpe (update_hazards → _land_invert).
static func place_islands(sim: WorldSim, e: SimEntity, s: SkillDef, power: float, effects: Dictionary) -> void:
	var m: Dictionary = sim.maps[e.map_id]
	var d: Dictionary = effects["islands"]
	var n := maxi(int(d.get("count_min", Balance.TIDE_ISLAND_MIN)), ceili(float(e.crowd) / 2.0))
	var r := float(d.get("radius", 2.5))
	var delay := float(d.get("delay", 3.0))
	var lo := float(d.get("near_min", 6.0))
	var hi := float(d.get("near_max", 12.0))
	var fx := {}
	for k in ["slow", "stun", "root", "dot"]:
		if d.has(k):
			fx[k] = d[k]
	var pending: Array = (m.get("hazards", []) as Array).filter(func(h): return not h.get("landed", false))
	var spots: Array = []
	for off in d.get("at", []):                       # ilhas FIXAS da arena (offsets da casa do chefe: Palco Seguro, Eco)
		spots.append(_ground(e.home_position + Vector3(float(off[0]), 0, float(off[1]))))
	for q in d.get("spots", []):                      # ... ou pontos [x, z] do mapa (boss_hint.islands do JSON; o spawner sorteia a casa num raio)
		spots.append(Vector3(float(q[0]), 0, float(q[1])))
	if not spots.is_empty():
		n = spots.size()
	var tank: SimEntity = sim.entities.get(e.aggro_target)
	if spots.is_empty() and tank and tank.is_alive() and tank.map_id == e.map_id:
		spots.append(_ground(tank.position))
	var tries := 0
	while spots.size() < n and tries < n * 16:
		tries += 1
		var a := sim.rng.randf() * TAU
		var p := _ground(e.position + Vector3(cos(a), 0, sin(a)) * sim.rng.randf_range(lo, hi))
		if not MapGeometry.is_walkable(sim, p, m["def"], r * 0.6):
			continue
		if spots.any(func(q): return q.distance_to(p) < r * 2.4) or pending.any(func(h): return inside(h, p, r)):
			continue
		spots.append(p)
	var gid := -1
	for p in spots:
		var h := add_hazard(m, {"owner": e.id, "pos": p, "radius": r, "at": sim.time + delay, "power": power, "kind": s.kind,
			"effects": fx, "skill": s.id, "invert": true, "group": gid, "center": _ground(e.position), "range": Balance.BOSS_INVERT_RANGE}, sim.time)
		if gid < 0:
			gid = int(h["id"])
			h["group"] = gid
	if d.has("say"):
		MobSystem.boss_say(sim, e, str(d["say"]))
	stat(sim, "islands")

## Ilhas caíram: quem está perto do chefe e fora de todas leva o golpe; o grupo inteiro sai da lista.
static func _land_invert(sim: WorldSim, m: Dictionary, owner: SimEntity, h: Dictionary, hz: Array) -> void:
	var gid := int(h["group"])
	var isl: Array = hz.filter(func(x): return x.get("invert", false) and int(x.get("group", -2)) == gid)
	for x in isl:
		hz.erase(x)
	var c := _ground(owner.position)
	var rr: float = float(h.get("range", Balance.BOSS_INVERT_RANGE))
	for o: SimEntity in m["entities"].duplicate():
		if not o.is_alive() or not owner.is_hostile_to(o) or o.is_perched() or _ground(o.position).distance_to(c) > rr:
			continue
		if isl.any(func(x): return inside(x, o.position, 0.0)):
			continue
		if ChoirSystem.shelters(sim, owner, o):
			continue
		_hit(sim, owner, o, float(h["power"]), int(h["kind"]), h["effects"], c)
		if o.is_character():
			stat(sim, "islands_hit")
	Events.post(&"skill_effect", h["skill"], c, c, rr)

## Dano de assinatura/perigo: é zona avisada (ilhas, marca, chuva, anel, avalanche, contragolpe em cone), então a
## esquiva passiva (AGI) não salva; só sair da zona (decisão 2026-11-13). Esquiva continua valendo para golpe e projétil.
static func _hit(sim: WorldSim, owner: SimEntity, o: SimEntity, power: float, kind: int, fx: Dictionary, from: Vector3) -> void:
	var r := Combat.calc_damage(owner, o, power, kind, sim.rng, from)
	sim._deal_damage(owner, o, r["amount"], r["crit"], false, "magical" if kind == SkillDef.Kind.MAGICAL else "physical", from, false)
	if not fx.is_empty():
		sim._apply_effects(owner, o, fx, power)

# ---------------------------------------------------------------------------
# R-B: marca que segue a vítima (spread = cada um leva; soak = divide)
# ---------------------------------------------------------------------------

static func place_marks(sim: WorldSim, e: SimEntity, s: SkillDef, power: float, effects: Dictionary) -> void:
	var m: Dictionary = sim.maps[e.map_id]
	var d: Dictionary = effects["mark"]
	var pool: Array = MobSystem.victims(sim, e)
	var chars := pool.filter(func(o): return o.is_character())
	if not chars.is_empty():
		pool = chars
	if pool.is_empty():
		return
	var alt_mode := str(d.get("mode", "spread"))
	var both := false
	if alt_mode == "alternate":                       # Brinde Dividido (Eco): dividir e espalhar se revezam; na faixa both_hp, as duas
		var bh: Array = d.get("both_hp", [])
		var hp := e.hp / maxf(1.0, e.stats.max_hp)
		both = bh.size() == 2 and hp >= float(bh[0]) and hp <= float(bh[1])
		alt_mode = "soak" if int(e.sig.get("alt", 0)) % 2 == 0 else "spread"
		e.sig["alt"] = int(e.sig.get("alt", 0)) + 1
		d = d.duplicate()
		d["count"] = 1 + int(d.get("spread_count", 2)) if both else (1 if alt_mode == "soak" else int(d.get("spread_count", 2)))
	var count := int(d.get("count", 1)) if pool.size() > 1 else int(d.get("solo_count", 1))
	if bool(d.get("no_tank", true)) and pool.size() > 1:
		pool = pool.filter(func(o): return o.id != e.aggro_target)
	var fx := {}
	for k in ["slow", "stun", "root", "dot"]:
		if d.has(k):
			fx[k] = d[k]
	var mode := alt_mode
	var batch := int(m.get("hazard_seq", 0)) + 1      # Cânone: marcas da mesma leva que se encostam dobram (_touch)
	for i in range(mini(count, pool.size())):
		var v: SimEntity = pool.pop_at(sim.rng.randi() % pool.size())
		var vm := mode if not both else ("soak" if i == 0 else "spread")
		var h := {"owner": e.id, "pos": _ground(v.position), "radius": float(d.get("radius", 4.0)), "at": sim.time + float(d.get("time", Balance.BOSS_MARK_TIME)),
			"power": float(d.get(vm + "_power", power)), "kind": s.kind, "effects": fx, "skill": s.id, "follow": v.id, "victim": v.id, "mode": vm, "mark": true}
		if float(d.get("linger", 0.0)) > 0.0:
			h["linger"] = float(d["linger"])
			h["tick_power"] = float(d.get("tick_power", 0.2))
		if float(d.get("touch", 0.0)) > 0.0:
			h["touch"] = float(d["touch"])
			h["touch_mult"] = float(d.get("touch_mult", 2.0))
			h["batch"] = batch
		add_hazard(m, h, sim.time)
		stat(sim, "marks")
	if d.has("say"):
		MobSystem.boss_say(sim, e, str(d["say"]))

# ---------------------------------------------------------------------------
# Hazards: seguir, cair, chão que fica (substitui o laço antigo de MobSystem.update_hazards)
# ---------------------------------------------------------------------------

static func update_hazards(sim: WorldSim, m: Dictionary) -> void:
	if not (m.get("covers", []) as Array).is_empty():
		_update_covers(sim, m)
	var hz: Array = m.get("hazards", [])
	if hz.is_empty():
		return
	_hz_scan.assign(hz)                          # foto da lista (mesma ordem e mesmas regras de antes, sem alocar um Array novo)
	for h in _hz_scan:
		if not hz.has(h):
			continue                                 # grupo de ilhas já resolvido neste tique
		var owner: SimEntity = sim.entities.get(h["owner"])
		if owner == null or not owner.is_alive() or owner.map_id != m["def"].id:
			hz.erase(h)
			continue
		if h.get("landed", false):
			if sim.time >= float(h["until"]):
				hz.erase(h)
			elif sim.time >= float(h["next_tick"]):
				h["next_tick"] = float(h["next_tick"]) + Balance.BOSS_LINGER_TICK
				_tick_pool(sim, m, owner, h)
			continue
		if h.has("follow"):
			_follow(sim, owner, h)
		if sim.time < float(h["at"]):
			continue
		if h.get("invert", false):
			_land_invert(sim, m, owner, h, hz)
			continue
		if h.has("hp_pct"):                          # salva do assédio (Cerco Vivo): dano em % da vida, regras do SiegeSystem
			SiegeSystem.land(sim, m, owner, h)
			hz.erase(h)
			continue
		_land(sim, m, owner, h)
		if h.has("dash_to"):
			_cortege_dash(sim, m, owner, h)
		if h.get("cover", false):
			add_cover(sim, m, owner, h["pos"])
		if float(h.get("linger", 0.0)) > 0.0:
			h["landed"] = true
			h["until"] = sim.time + float(h["linger"])
			h["next_tick"] = sim.time + Balance.BOSS_LINGER_TICK
			h.erase("follow")
		else:
			hz.erase(h)
	_hz_scan.clear()                             # solta a foto (a lista do mapa não fica presa em cópia na escrita)

## Marca acompanha a vítima; vítima sumida (morta, outro mapa, furtiva) = a marca fica onde estava.
static func _follow(sim: WorldSim, owner: SimEntity, h: Dictionary) -> void:
	var v: SimEntity = sim.entities.get(int(h["follow"]))
	if v and v.is_alive() and v.map_id == owner.map_id and v.stealth_left <= 0.0:
		h["pos"] = _ground(v.position)
	else:
		h.erase("follow")

static func _land(sim: WorldSim, m: Dictionary, owner: SimEntity, h: Dictionary) -> void:
	var pos: Vector3 = h["pos"]
	var kind: int = h["kind"]
	var hit: Array = []
	for o: SimEntity in m["entities"]:
		if o.is_alive() and owner.is_hostile_to(o) and inside(h, o.position, o.radius):
			if ChoirSystem.shelters(sim, owner, o):
				continue                     # Barreira Sagrada: a chuva de fora não entra na cúpula
			hit.append(o)
	var power := float(h["power"])
	if h.has("touch"):
		_touch(sim, m, h)
		if h.get("doubled", false):
			power *= float(h.get("touch_mult", 2.0))
	if str(h.get("mode", "")) == "soak":
		var n := hit.filter(func(o): return o.is_character()).size()
		power /= float(maxi(Balance.BOSS_SOAK_MIN, n))         # F-S1: dividido por quem está dentro
		stat(sim, "soak_n", n)
	var soak: bool = str(h.get("mode", "")) == "soak"
	for o: SimEntity in hit:
		_hit(sim, owner, o, power, kind, h["effects"], pos)
		if soak and o.is_character() and not o.is_alive():
			stat(sim, "soak_kills")                  # sonda: mortes pelo golpe dividido (alvo Durgash: <= 0,2 por machado)
		if h.get("mark", false) and o.is_character() and o.id != int(h.get("victim", -1)):
			stat(sim, "mark_ally_hits")
		if h.get("sig_line", false) and o.is_character():
			stat(sim, "line_hits")
		if h.get("sig_ring", false) and o.is_character():
			stat(sim, "ring_hits")
		if h.get("press", false) and o.is_character():
			stat(sim, "press_hits")
	Events.post(&"skill_effect", h["skill"], pos, pos, float(h["radius"]) if str(h.get("shape", "circle")) != "line" else float(h["width"]))

## Cânone (Ressoa, R-B `touch`): na queda da 1ª marca da leva, cada marca cujo centro está a <= `touch` m de outra da
## mesma leva fica `doubled` (as duas batem × touch_mult). As da leva caem no mesmo tique, então todas ainda estão na lista.
static func _touch(sim: WorldSim, m: Dictionary, h: Dictionary) -> void:
	if h.has("touch_done"):
		return
	var same: Array = (m.get("hazards", []) as Array).filter(func(g): return int(g.get("batch", -1)) == int(h["batch"]) and int(g["owner"]) == int(h["owner"]))
	if not same.has(h):
		same.append(h)
	for g in same:
		g["touch_done"] = true
		for o in same:
			if o != g and (g["pos"] as Vector3).distance_to(o["pos"]) <= float(g["touch"]):
				g["doubled"] = true
				break
		if g.get("doubled", false):
			stat(sim, "canon_double")

## Chão que fica: tique em quem está dentro; o dono dentro da poça se fortalece (empower).
static func _tick_pool(sim: WorldSim, m: Dictionary, owner: SimEntity, h: Dictionary) -> void:
	var tp := float(h.get("tick_power", 0.0))
	if tp > 0.0:
		for o: SimEntity in m["entities"]:
			if o.is_alive() and owner.is_hostile_to(o) and inside(h, o.position, o.radius) and not ChoirSystem.shelters(sim, owner, o):
				var r := Combat.calc_damage(owner, o, tp, int(h["kind"]), sim.rng, h["pos"])
				sim._deal_damage(owner, o, r["amount"], false, false, "dot_pool", h["pos"])
				if o.is_character():
					stat(sim, "linger_line_ticks" if str(h.get("shape", "circle")) == "line" else "linger_ticks")     # sonda: tiques em personagem na faixa/poça que ficou
	if h.get("empower") is Dictionary and inside(h, owner.position, 0.0):
		_empower(sim, owner, h["empower"])

## Dono dentro de alguma poça que fortalece (empower) dele?
static func in_empower_pool(m: Dictionary, e: SimEntity) -> bool:
	for h in m.get("hazards", []):
		if h.get("landed", false) and h.get("empower") is Dictionary and int(h["owner"]) == e.id and inside(h, e.position, 0.0):
			return true
	return false

## Têmpera (F-S3, GDD 3.10): dentro de uma poça dele, +1 acúmulo a cada `every` s (KRAGMAR_TEMPER_EVERY, até `max`) e cura
## `heal_pct` da vida por segundo; conta uma vez por segundo mesmo com poças sobrepostas. Fora perde 1 a cada
## KRAGMAR_TEMPER_DECAY s (update).
static func _empower(sim: WorldSim, e: SimEntity, d: Dictionary) -> void:
	var tk := Balance.BOSS_LINGER_TICK
	var last := float(e.sig.get("temper_t", -1.0e9))
	if sim.time - last < tk - 0.01:
		return                                       # outra poça já contou neste segundo
	var was_in := sim.time - last <= tk * 1.5 + 0.01
	e.sig["temper_t"] = sim.time
	e.sig["temper_out"] = 0.0
	e.sig["temper_in"] = (float(e.sig.get("temper_in", 0.0)) if was_in else 0.0) + tk
	var id := str(d.get("id", TEMPER_BUFF))
	if float(e.sig["temper_in"]) >= float(d.get("every", Balance.KRAGMAR_TEMPER_EVERY)) - 0.01:
		e.sig["temper_in"] = 0.0
		var mx := int(d.get("max", Balance.KRAGMAR_TEMPER_MAX))
		var n := mini(mx, e.buff_stacks(id) + 1)
		e.put_buff({"id": id, "remaining": 1.0e9, "stacks": n})
		stat(sim, "temper_gain")
	var heal := float(d.get("heal_pct", Balance.KRAGMAR_TEMPER_HEAL))
	if heal > 0.0:
		var before := e.hp
		e.hp = minf(e.stats.max_hp, e.hp + e.stats.max_hp * heal * tk)
		stat(sim, "temper_heal", float(e.hp - before))
	MobSystem._apply_fury(e)

# ---------------------------------------------------------------------------
# R-E: cobertura (pedregulhos do Troll Rei) e Avalanche
# ---------------------------------------------------------------------------

## Pedregulho no chão (intocável: não é entidade). Passou do máximo, o mais velho some.
static func add_cover(sim: WorldSim, m: Dictionary, owner: SimEntity, p: Vector3) -> void:
	var cd: Dictionary = owner.monster_def.cover
	if cd.is_empty():
		return
	if not m.has("covers"):
		m["covers"] = []
	var mine: Array = (m["covers"] as Array).filter(func(c): return int(c["owner"]) == owner.id)
	while mine.size() >= int(cd.get("max", Balance.TROLL_COVER_MAX)):
		m["covers"].erase(mine.pop_front())
	m["hazard_seq"] = int(m.get("hazard_seq", 0)) + 1
	var c := {"id": m["hazard_seq"], "owner": owner.id, "pos": _ground(p), "radius": float(cd.get("radius", 1.2)), "until": sim.time + float(cd.get("time", 40.0))}
	if cd.has("model"):
		c["model"] = str(cd["model"])                # Espelho de Pé: a apresentação desenha o modelo e o clipe de rachar
	m["covers"].append(c)
	Events.post(&"skill_effect", str(cd.get("fx", "mob_boulder_toss")), _ground(p), _ground(p), float(cd.get("radius", 1.2)))

## Coberturas que ainda protegem (espelho rachado fica no chão só como desenho).
static func covers_of(m: Dictionary, owner_id: int) -> Array:
	return (m.get("covers", []) as Array).filter(func(c): return int(c["owner"]) == owner_id and not c.get("cracked", false))

static func _update_covers(sim: WorldSim, m: Dictionary) -> void:
	var cv: Array = m["covers"]
	for c in cv.duplicate():
		var o: SimEntity = sim.entities.get(int(c["owner"]))
		if sim.time >= float(c["until"]) or o == null or not o.is_alive() or o.map_id != m["def"].id:
			cv.erase(c)

## Começo do preparo da Avalanche: sem pedra no chão, arremessa `guarantee` antes (a garantia do GDD 3.3).
static func avalanche_prep(sim: WorldSim, e: SimEntity, s: SkillDef) -> void:
	var m: Dictionary = sim.maps[e.map_id]
	stat(sim, "avalanches")
	var d: Dictionary = s.effects["avalanche"]
	if d.get("mirrors") is Array:                  # Olhar Que Julga: os espelhos velhos saem e sobem os novos nos pontos da sala
		raise_mirrors(sim, m, e, d["mirrors"])
		if d.has("say"):
			MobSystem.boss_say(sim, e, str(d["say"]))
		return
	if not covers_of(m, e.id).is_empty():
		return
	var n := int(d.get("guarantee", Balance.BOSS_SIG_DEFAULTS["avalanche"]["guarantee"]))
	var placed: Array = []
	var tries := 0
	while placed.size() < n and tries < n * 12:
		tries += 1
		var a := sim.rng.randf() * TAU
		var p := _ground(e.position + Vector3(cos(a), 0, sin(a)) * sim.rng.randf_range(float(d.get("near_min", Balance.BOSS_SIG_DEFAULTS["avalanche"]["near_min"])), float(d.get("near_max", Balance.BOSS_SIG_DEFAULTS["avalanche"]["near_max"]))))
		if MapGeometry.is_walkable(sim, p, m["def"], 1.0) and placed.all(func(q): return q.distance_to(p) > 4.0):
			placed.append(p)
			add_cover(sim, m, e, p)

## Condessa (GDD ato3 §4.1): um Espelho de Pé em cada ponto (`pts` = deslocamento [x, z] do ponto de nascer do chefe,
## espelho dos `cover` do boss_hint do JSON da sala); os dela que estavam no chão (inteiros ou rachados) somem antes.
static func raise_mirrors(sim: WorldSim, m: Dictionary, e: SimEntity, pts: Array) -> void:
	if m.has("covers"):
		m["covers"] = (m["covers"] as Array).filter(func(c): return int(c["owner"]) != e.id)
	for q in pts:
		add_cover(sim, m, e, e.home_position + Vector3(float(q[0]), 0, float(q[1])))
	stat(sim, "mirrors_raised", pts.size())

## Pedra entre o chefe e o alvo (o segmento chefe→alvo cruza o círculo da pedra)?
static func cover_between(m: Dictionary, boss: SimEntity, t: Vector3) -> Dictionary:
	var a := Vector2(boss.position.x, boss.position.z)
	var b := Vector2(t.x, t.z)
	for c in covers_of(m, boss.id):
		var p := Vector2(c["pos"].x, c["pos"].z)
		var ab := b - a
		var k := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		if (a + ab * k).distance_to(p) <= float(c["radius"]) and p.distance_to(a) < b.distance_to(a):
			return c
	return {}

static func avalanche(sim: WorldSim, e: SimEntity, s: SkillDef, power: float, effects: Dictionary) -> void:
	var m: Dictionary = sim.maps[e.map_id]
	var d: Dictionary = effects["avalanche"]
	var r := float(d.get("radius", Balance.BOSS_SIG_DEFAULTS["avalanche"]["radius"]))
	var used: Array = []
	var fx := {"stun": {"duration": float(d.get("stun", 1.0))}} if float(d.get("stun", 0.0)) > 0.0 else {}
	for o: SimEntity in m["entities"].duplicate():
		if not o.is_alive() or not e.is_hostile_to(o) or o.is_perched() or o.position.distance_to(e.position) > r + o.radius:
			continue
		var c := cover_between(m, e, o.position)
		if not c.is_empty():
			if not c in used:
				used.append(c)
			continue
		_hit(sim, e, o, power, s.kind, fx, e.position)
		if o.is_character():
			stat(sim, "avalanche_hits")
	for c in used:
		if c.has("model"):                    # espelho: racha e fica rachado no chão (não protege mais) até o próximo Olhar
			c["cracked"] = true
			c["until"] = minf(float(c["until"]), sim.time + Balance.ACT3_MIRROR_CRACKED_S)
			stat(sim, "mirrors_cracked")
			Events.post(&"skill_effect", MIRROR_CRACK_FX, c["pos"], c["pos"], float(c["radius"]))
			continue
		m["covers"].erase(c)                  # a pedra que protegeu racha e some
		Events.post(&"skill_effect", "mob_rock_quake", c["pos"], c["pos"], float(c["radius"]))
		Events.post(&"skill_effect", COVER_BREAK_FX, c["pos"], c["pos"], float(c["radius"]))
	Events.post(&"skill_effect", s.id, e.position, e.position, r)

# ---------------------------------------------------------------------------
# R-C: canal interrompível (Rufar da Turba)
# ---------------------------------------------------------------------------

static func channel_start(sim: WorldSim, e: SimEntity, s: SkillDef, effects: Dictionary) -> void:
	e.sig["channel"] = {"skill": s.id, "until": sim.time + s.active, "start": sim.time, "dmg": 0.0,
		"need": e.stats.max_hp * Balance.BOSS_CHANNEL_BREAK_PCT, "cfg": effects["boss_channel"]}
	e.put_buff({"id": CHANNEL_BUFF, "remaining": s.active + 0.2})
	Events.post(&"buff_applied", e.id, CHANNEL_BUFF, s.active)
	var d: Dictionary = effects["boss_channel"]
	if d.has("say"):
		MobSystem.boss_say(sim, e, str(d["say"]))
	if d.has("warn") and sim.player and sim.player.map_id == e.map_id:
		Events.post(&"notification", str(d["warn"]))
	stat(sim, "channels")

## Dano APLICADO no chefe (depois do ward) conta para quebrar o canal (WorldSim._deal_damage).
static func on_damage(e: SimEntity, amount: int) -> void:
	var c: Dictionary = e.sig["channel"]
	c["dmg"] = float(c["dmg"]) + amount

## Progresso do canal 0..1 (apresentação lê).
static func channel_progress(sim: WorldSim, e: SimEntity) -> float:
	if not e.sig.has("channel"):
		return -1.0
	var c: Dictionary = e.sig["channel"]
	return clampf((sim.time - float(c["start"])) / maxf(0.01, float(c["until"]) - float(c["start"])), 0.0, 1.0)

static func _update_channel(sim: WorldSim, e: SimEntity) -> void:
	var c: Dictionary = e.sig["channel"]
	var casting: bool = e.current_skill != null and e.current_skill.id == str(c["skill"]) and e.state == SimEntity.State.CASTING
	if float(c["dmg"]) >= float(c["need"]) or (not casting and sim.time < float(c["until"]) - 0.001):
		_channel_break(sim, e)
	elif sim.time >= float(c["until"]) - 0.001:
		_channel_done(sim, e, c["cfg"])

static func _channel_break(sim: WorldSim, e: SimEntity) -> void:
	var cfg: Dictionary = e.sig["channel"].get("cfg", {})          # effects["boss_channel"] da skill (fala e raio da quebra)
	e.sig.erase("channel")
	e.drop_buff(CHANNEL_BUFF)
	e.current_skill = null
	e.skill_phase = ""
	e.is_blocking = false
	e.set_state(SimEntity.State.STUNNED, Balance.BOSS_CHANNEL_STAGGER)
	var ob: Dictionary = cfg.get("on_break", {})      # Banquete (Varo): vuln/vuln_time próprios
	e.put_debuff({"kind": "curse", "id": str(ob.get("vuln_id", TORN_DEBUFF)), "remaining": float(ob.get("vuln_time", Balance.BOSS_CHANNEL_VULN_TIME)), "taken_pct": float(ob.get("vuln", Balance.BOSS_CHANNEL_VULN)), "weaken_pct": 0.0})
	if cfg.has("break_say"):
		MobSystem.boss_say(sim, e, str(cfg["break_say"]))
	Events.post(&"skill_effect", CHANNEL_BREAK_FX, e.position, e.position, float(cfg.get("break_radius", Balance.BOSS_CHANNEL_BREAK_RADIUS)))
	stat(sim, "channel_breaks")

static func _channel_done(sim: WorldSim, e: SimEntity, d: Dictionary) -> void:
	e.sig.erase("channel")
	e.drop_buff(CHANNEL_BUFF)
	var od: Dictionary = d.get("on_done", {})
	var r2: float = pow(float(od.get("radius", Balance.BOSS_SIG_DEFAULTS["channel_done"]["radius"])), 2)
	var bd: Dictionary = od.get("buff", {})
	if not bd.is_empty() and sim.maps.has(e.map_id):
		for o: SimEntity in sim.maps[e.map_id]["entities"]:
			if o.kind != SimEntity.Kind.MONSTER or not o.is_alive() or (o != e and o.boss_id != e.id and o.leader_id != e.id):
				continue
			if o == e and not od.get("self", false):  # Banquete (Varo): `self` = ele também bebe (cura + fúria)
				continue
			if o.position.distance_squared_to(e.position) > r2:
				continue
			var dur := float(bd.get("duration", Balance.BOSS_SIG_DEFAULTS["channel_done"]["duration"]))
			o.put_buff({"id": str(bd.get("id", FRENZY_BUFF)), "remaining": dur, "duration": dur, "atk_pct": float(bd.get("atk_pct", Balance.BOSS_SIG_DEFAULTS["channel_done"]["atk_pct"])), "mob_stat": true})
			o.recompute_stats()
			o.hp = minf(o.stats.max_hp, o.hp + o.stats.max_hp * float(od.get("heal_pct", Balance.BOSS_SIG_DEFAULTS["channel_done"]["heal_pct"])))
			Events.post(&"buff_applied", o.id, str(bd.get("id", FRENZY_BUFF)), dur)
	if od.get("summon") is Dictionary:
		MobSystem.spawn_adds(sim, e, od["summon"])
	if od.has("say"):
		MobSystem.boss_say(sim, e, str(od["say"]))
	Events.post(&"skill_effect", str(od.get("vfx", "mob_war_drum")), e.position, e.position, float(od.get("radius", Balance.BOSS_SIG_DEFAULTS["channel_done"]["radius"])))
	stat(sim, "channel_done")

# ---------------------------------------------------------------------------
# R-D: sequência (Três Botes)
# ---------------------------------------------------------------------------

## Golpe de skill com "repeat" aplicado: o 1º abre a sequência (vítima = quem está mais perto da mira); o último a fecha.
static func on_repeat_apply(sim: WorldSim, e: SimEntity, s: SkillDef, effects: Dictionary) -> void:
	if e.sig.has("seq"):
		if int(e.sig["seq"]["left"]) <= 0:
			e.sig.erase("seq")
		return
	var d: Dictionary = effects["repeat"]
	var times := int(d.get("times", 3))
	if times <= 1:
		return
	var v: SimEntity = null
	var best := INF
	for o in MobSystem.victims(sim, e, s.range + 4.0):
		var dd: float = o.position.distance_to(e.skill_aim)
		if dd < best:
			best = dd
			v = o
	e.sig["seq"] = {"skill": s.id, "left": times - 1, "victim": v.id if v else -1, "gap": float(d.get("gap", 0.6)),
		"next": sim.time + s.active + s.recovery + float(d.get("gap", 0.6))}
	stat(sim, "seqs")

static func _update_seq(sim: WorldSim, e: SimEntity) -> void:
	var q: Dictionary = e.sig["seq"]
	if e.state == SimEntity.State.STUNNED or e.has_debuff("root"):
		e.sig.erase("seq")                    # controle corta a sequência
		stat(sim, "seq_cut")
		return
	if int(q["left"]) <= 0 or sim.time < float(q["next"]) or not e.can_act():
		return
	var v: SimEntity = sim.entities.get(int(q["victim"]))
	var s: SkillDef = GameData.skills.get(str(q["skill"]))
	var slot := e.skills.find(s)
	if v == null or not v.is_alive() or v.map_id != e.map_id or v.stealth_left > 0.0 or slot < 0:
		e.sig.erase("seq")
		return
	q["left"] = int(q["left"]) - 1
	q["next"] = sim.time + s.startup + s.active + s.recovery + float(q["gap"])
	sim._start_skill(e, s, slot, v.position)

# ---------------------------------------------------------------------------
# R-G: Muralha de Escudos (Ghar)
# ---------------------------------------------------------------------------

static func wall_start(sim: WorldSim, e: SimEntity, s: SkillDef, effects: Dictionary) -> void:
	var d: Dictionary = effects["wall"]
	var t := float(d.get("time", Balance.BOSS_SIG_DEFAULTS["wall"]["time"]))
	e.sig["wall"] = {"until": sim.time + t, "fury": 0, "cfg": d.get("counter", {}), "skill": s.id, "kind": s.kind, "power": s.power}
	e.put_buff({"id": WALL_BUFF, "remaining": t})
	Events.post(&"buff_applied", e.id, WALL_BUFF, t)
	if d.has("say"):
		MobSystem.boss_say(sim, e, str(d["say"]))
	stat(sim, "walls")

## Golpe vindo de `from` bate na Muralha (arco frontal GHAR_WALL_ARC_DEG)?
static func wall_blocks(e: SimEntity, from: Vector3) -> bool:
	var d := Vector2(from.x - e.position.x, from.z - e.position.z)
	if d.length_squared() < 0.0025:
		return true
	var f := e.forward()
	return absf(Vector2(f.x, f.z).angle_to(d)) <= deg_to_rad(Balance.GHAR_WALL_ARC_DEG * 0.5)

## Corta o golpe da frente e soma fúria (WorldSim._deal_damage).
static func wall_cut(e: SimEntity, amount: int) -> int:
	e.sig["wall"]["fury"] = int(e.sig["wall"]["fury"]) + 1
	return maxi(1, int(round(amount * (1.0 - Balance.GHAR_WALL_CUT))))

## F-S5: power do contragolpe pela fúria contida.
static func counter_power(cfg: Dictionary, fury: int) -> float:
	var base := float(cfg.get("base", Balance.BOSS_SIG_DEFAULTS["counter"]["base"]))
	var step := float(cfg.get("step", Balance.BOSS_SIG_DEFAULTS["counter"]["step"]))
	var cap := float(cfg.get("cap", Balance.BOSS_SIG_DEFAULTS["counter"]["cap"]))
	return minf(cap, base + step * fury)

static func _update_wall(sim: WorldSim, e: SimEntity) -> void:
	var w: Dictionary = e.sig["wall"]
	if sim.time < float(w["until"]):
		return
	e.sig.erase("wall")
	e.drop_buff(WALL_BUFF)
	var cfg: Dictionary = w["cfg"]
	stat(sim, "wall_fury", int(w["fury"]))
	# o golpe sai GHAR_COUNTER_DELAY s depois (quadro de impacto do clipe wall_counter); nesse meio o chefe não age
	e.sig["counter"] = {"at": sim.time + Balance.GHAR_COUNTER_DELAY, "start": sim.time, "power": counter_power(cfg, int(w["fury"])),
		"cfg": cfg, "kind": int(w["kind"])}
	if Balance.GHAR_COUNTER_DELAY <= 0.0:
		_update_counter(sim, e)

## Contragolpe da Muralha (F-S5): cone na frente, `power` pela fúria guardada.
static func _update_counter(sim: WorldSim, e: SimEntity) -> void:
	var q: Dictionary = e.sig["counter"]
	if sim.time < float(q["at"]):
		return
	e.sig.erase("counter")
	var cfg: Dictionary = q["cfg"]
	var power := float(q["power"])
	var half := deg_to_rad(float(cfg.get("cone", Balance.BOSS_SIG_DEFAULTS["counter"]["cone"])) * 0.5)
	var rng_m := float(cfg.get("range", Balance.BOSS_SIG_DEFAULTS["counter"]["range"]))
	var f := Vector2(e.forward().x, e.forward().z)
	for o: SimEntity in sim.maps[e.map_id]["entities"].duplicate():
		if not o.is_alive() or not e.is_hostile_to(o) or o.position.distance_to(e.position) > rng_m + o.radius:
			continue
		var to := Vector2(o.position.x - e.position.x, o.position.z - e.position.z)
		if to.length() > 0.05 and absf(f.angle_to(to)) > half:
			continue
		_hit(sim, e, o, power, int(q["kind"]), {}, e.position)
		if o.is_character():
			stat(sim, "counter_hits")
	Events.post(&"skill_effect", COUNTER_FX, e.position, e.position + e.forward() * rng_m, rng_m)

# ---------------------------------------------------------------------------
# R-F: cópias (Sombras Gêmeas, Shazka)
# ---------------------------------------------------------------------------

## Lançou: a fumaça (efeito "stealth" da própria skill) esconde; as cópias saem quando ela acaba (update → _spawn_decoys).
static func decoys_start(sim: WorldSim, e: SimEntity, s: SkillDef, effects: Dictionary) -> void:
	dispel_decoys(sim, e)
	e.sig["twins"] = {"at": sim.time + float(effects.get("stealth", 0.0)), "cfg": effects["decoys"], "skill": s.id}
	stat(sim, "twins")

## Sai da fumaça: ele e `count` cópias em volta (lugares sorteados; ele fica num deles). Cópia = mesmo nome, modelo e vida.
static func _spawn_decoys(sim: WorldSim, e: SimEntity) -> void:
	var q: Dictionary = e.sig["twins"]
	e.sig.erase("twins")
	var d: Dictionary = q["cfg"]
	var mdef: MonsterDef = GameData.monsters.get(str(d.get("id", "")))
	if mdef == null or not sim.maps.has(e.map_id):
		return
	var m: Dictionary = sim.maps[e.map_id]
	var n := int(d.get("count", Balance.BOSS_SIG_DEFAULTS["decoys"]["count"]))
	var r := float(d.get("spread", Balance.BOSS_SIG_DEFAULTS["decoys"]["spread"]))
	var a0 := sim.rng.randf() * TAU
	var spots: Array = []
	for i in range(n + 1):
		var a := a0 + TAU * i / float(n + 1)
		var p := _ground(e.position + Vector3(cos(a), 0, sin(a)) * r)
		spots.append(p if MapGeometry.is_walkable(sim, p, m["def"], e.radius) else _ground(e.position))
	var real := sim.rng.randi() % spots.size()
	var ids: Array = []
	for i in range(spots.size()):
		if i == real:
			continue
		var c := sim.spawn_monster(mdef, e.map_id, spots[i])
		c.sig["decoy_of"] = e.id
		c.dmg_mult = Balance.SHAZKA_DECOY_DMG
		c.summon_hp = e.stats.max_hp           # sobrevive ao recompute_stats (buff/debuff): a barra nunca passa de 100%
		c.recompute_stats()
		c.hp = minf(e.hp, c.stats.max_hp)
		c.facing = e.facing
		c.aggro_target = e.aggro_target
		c.aggro_timer = Balance.AGGRO_LOSE_TIME
		ids.append(c.id)
	var to: Vector3 = spots[real]
	e.position = Vector3(to.x, e.position.y, to.z)
	e.stealth_left = 0.0
	e.sig["decoys"] = {"ids": ids, "until": sim.time + float(d.get("time", Balance.BOSS_SIG_DEFAULTS["decoys"]["time"])), "start": sim.time, "cloud": d.get("cloud", {}), "skill": q["skill"]}
	if d.has("say"):
		MobSystem.boss_say(sim, e, str(d["say"]))
	Events.post(&"skill_effect", DECOY_FX, e.position, e.position, r)

## Cópias vivas do chefe `e`.
static func decoys_of(sim: WorldSim, e: SimEntity) -> Array:
	var out: Array = []
	if e.sig.has("decoys"):
		for id in e.sig["decoys"]["ids"]:
			var c: SimEntity = sim.entities.get(int(id))
			if c != null and c.is_alive():
				out.append(c)
	return out

## Alguma cópia do chefe `e` viva? Mesmo teste de decoys_of sem montar o Array (roda a cada tique do chefe; revisão m5).
static func has_decoys(sim: WorldSim, e: SimEntity) -> bool:
	if e.sig.has("decoys"):
		for id in e.sig["decoys"]["ids"]:
			var c: SimEntity = sim.entities.get(int(id))
			if c != null and c.is_alive():
				return true
	return false

## Desfaz as cópias (tempo acabou, golpe no verdadeiro, reset, morte). Cada cópia sai sozinha no próximo tique dela
## (update_decoy): o golpe que desfaz pode vir de dentro de um laço sobre as entidades do mapa.
static func dispel_decoys(sim: WorldSim, e: SimEntity) -> void:
	if not e.sig.has("decoys"):
		return
	stat(sim, "decoy_life", sim.time - float(e.sig["decoys"]["start"]))
	e.sig.erase("decoys")

## Tique da cópia (WorldSim._update_entity): dono morto/sumido ou cópias desfeitas → some na fumaça. true = saiu.
static func update_decoy(sim: WorldSim, c: SimEntity) -> bool:
	var owner: SimEntity = sim.entities.get(int(c.sig.get("decoy_of", -1)))
	if c.is_alive() and owner != null and owner.is_alive() and owner.sig.has("decoys") and c.id in owner.sig["decoys"]["ids"]:
		return false
	if c.is_alive():
		Events.post(&"skill_effect", DECOY_FX, c.position, c.position, 1.0)
		sim.despawn(c)
		return true
	return false

## Golpe direto no verdadeiro com cópias vivas: elas somem (WorldSim._deal_damage).
static func on_real_hit(sim: WorldSim, e: SimEntity) -> void:
	if has_decoys(sim, e):
		stat(sim, "decoy_found")
	dispel_decoys(sim, e)

## Morte (WorldSim._kill): cópia solta a nuvem de veneno do dono; chefe leva as cópias junto.
static func on_death(sim: WorldSim, e: SimEntity) -> void:
	if e.sig.has("decoys") or e.sig.has("twins"):
		e.sig.erase("twins")
		dispel_decoys(sim, e)
	if not e.sig.has("decoy_of"):
		return
	var owner: SimEntity = sim.entities.get(int(e.sig["decoy_of"]))
	if owner == null or not owner.is_alive() or not owner.sig.has("decoys") or not sim.maps.has(e.map_id):
		return
	var cd: Dictionary = owner.sig["decoys"]["cloud"]
	stat(sim, "decoy_kills")
	if cd.is_empty():
		return
	var fx := {}
	for k in ["slow", "dot"]:
		if cd.has(k):
			fx[k] = cd[k]
	var p := _ground(e.position)
	var r := float(cd.get("radius", 2.0))
	var delay := float(cd.get("delay", 0.4))
	var h := {"owner": owner.id, "pos": p, "radius": r, "at": sim.time + delay, "power": float(cd.get("power", 0.4)), "kind": SkillDef.Kind.MAGICAL,
		"effects": fx, "skill": "mob_shazka_venom_rain", "decoy_cloud": true}
	h.merge(barrage_extra(cd))
	add_hazard(sim.maps[e.map_id], h, sim.time)
	Events.post(&"hazard_placed", e.map_id, p, r, delay, "mob_shazka_venom_rain")

# ---------------------------------------------------------------------------
# Por tique do chefe (MobSystem.update_boss) e reset
# ---------------------------------------------------------------------------

static func update(sim: WorldSim, e: SimEntity, dt: float) -> void:
	if e.aggro_target >= 0 and not e.sig.has("open"):
		e.sig["open"] = true
		arm(e, [], Balance.BOSS_SIG_OPEN_DELAY)
	if not (e.sig.has("channel") or e.sig.has("seq") or e.sig.has("wall") or e.sig.has("counter") or e.sig.has("twins") or e.sig.has("decoys")) and e.buff_stacks(TEMPER_BUFF) <= 0:
		return
	if e.sig.has("twins") and (sim.time >= float(e.sig["twins"]["at"]) or e.stealth_left <= 0.0):
		_spawn_decoys(sim, e)
	if e.sig.has("decoys") and (sim.time >= float(e.sig["decoys"]["until"]) or not has_decoys(sim, e)):
		dispel_decoys(sim, e)
	if e.sig.has("channel"):
		_update_channel(sim, e)
	if e.sig.has("seq"):
		_update_seq(sim, e)
	if e.sig.has("wall"):
		_update_wall(sim, e)
	if e.sig.has("counter"):
		_update_counter(sim, e)
	if e.buff_stacks(TEMPER_BUFF) > 0:
		e.sig["temper_out"] = float(e.sig.get("temper_out", 0.0)) + dt
		if float(e.sig["temper_out"]) >= Balance.KRAGMAR_TEMPER_DECAY:
			e.sig["temper_out"] = 0.0
			var n := e.buff_stacks(TEMPER_BUFF) - 1
			if n <= 0:
				e.drop_buff(TEMPER_BUFF)
			else:
				e.put_buff({"id": TEMPER_BUFF, "remaining": 1.0e9, "stacks": n})
			MobSystem._apply_fury(e)

## reset_boss: marcas, canal, sequência, Muralha, Têmpera, pedregulhos e cópias somem (AC-S4).
static func reset(sim: WorldSim, e: SimEntity) -> void:
	dispel_decoys(sim, e)
	e.sig.clear()
	for id in [CHANNEL_BUFF, WALL_BUFF, TEMPER_BUFF]:
		e.drop_buff(id)
	if sim.maps.has(e.map_id) and sim.maps[e.map_id].has("covers"):
		var m: Dictionary = sim.maps[e.map_id]
		m["covers"] = (m["covers"] as Array).filter(func(c): return int(c["owner"]) != e.id)
