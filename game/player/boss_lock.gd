class_name BossLock
extends RefCounted
## Trava no chefe (Tab; decisão 2026-11-18). Só apresentação: o PlayerController troca o vetor de movimento e a mira
## do InputCommand pelo chefe travado; a sim não sabe da trava (bots não mudam).
## W = para o chefe, S = para longe, A/D = gira em volta mantendo a distância; toda mira (básico, DIRECTION/CONE/TARGET e
## GROUND, que a sim já limita ao alcance) vai no chefe. Solta: chefe morreu/sumiu/resetou, troca de mapa, passou de
## Balance.BOSS_LOCK_RELEASE, jogador morreu, ou Tab de novo. Montar NÃO solta (Combate Montado luta a cavalo).

var target_id: int = -1
var map_id: String = ""
var epoch: int = 0           # adds_epoch do chefe na hora da trava: muda quando ele reseta
var orbit_r: float = 0.0     # raio que A/D mantém (atualiza enquanto W/S mexem a distância)

func active() -> bool:
	return target_id >= 0

func lock(boss: SimEntity) -> void:
	target_id = boss.id
	map_id = boss.map_id
	epoch = boss.adds_epoch
	orbit_r = 0.0

func release() -> void:
	target_id = -1
	map_id = ""
	orbit_r = 0.0

## Chefe de verdade (não o elite "Rei", não a cópia da Shazka), vivo.
static func is_lockable(e: SimEntity) -> bool:
	if e == null or e.kind != SimEntity.Kind.MONSTER or e.monster_def == null or not e.is_alive():
		return false
	var md := e.monster_def
	return md.is_boss and md.elite_of == "" and not md.decoy

## Chefe a travar: o que está sob o cursor (raio + `pad`) vence; senão o mais perto até `reach`. null = nenhum.
static func pick(entities: Array, from: Vector3, cursor: Vector3, reach: float, pad: float) -> SimEntity:
	var best: SimEntity = null
	var best_d := INF
	var under: SimEntity = null
	var under_d := INF
	for e: SimEntity in entities:
		if not is_lockable(e):
			continue
		var d := _flat(e.position - from).length()
		if d > reach:
			continue
		if d < best_d:
			best_d = d
			best = e
		var dc := _flat(e.position - cursor).length()
		if dc <= e.radius + pad and dc < under_d:
			under_d = dc
			under = e
	return under if under else best

## Motivo para soltar ("" = segue travado).
static func release_reason(player: SimEntity, boss: SimEntity, lock_map: String, lock_epoch: int, release_range: float) -> String:
	if player == null or not player.is_alive():
		return "player_dead"
	if boss == null or not boss.is_alive():
		return "boss_gone"
	if not is_lockable(boss):
		return "not_boss"
	if player.map_id != lock_map or boss.map_id != lock_map:
		return "map"
	if boss.adds_epoch != lock_epoch:
		return "reset"
	if _flat(boss.position - player.position).length() > release_range:
		return "range"
	return ""

## Vetor de movimento (XZ) com a trava. `iv` = (direita, frente) das teclas (-1..1). W/S no raio; A/D persegue um ponto
## `ahead` m à frente no círculo de raio `orbit_r` (corrige a deriva: A/D puro orbita sem espiralar). Abaixo de `min_dist`
## W não puxa mais para dentro. Comprimento <= 1.
static func move_vector(player: Vector3, boss: Vector3, iv: Vector2, orbit_r: float, min_dist: float, ahead: float) -> Vector2:
	var rel := Vector2(player.x - boss.x, player.z - boss.z)
	var r := rel.length()
	if r < 0.01 or iv.length_squared() < 0.0001:
		return Vector2.ZERO
	var u := rel / r                      # do chefe para o jogador
	var toward := -u
	var fwd := iv.y
	if fwd > 0.0 and r <= min_dist:
		fwd = 0.0
	var out := toward * fwd
	if absf(iv.x) > 0.001:
		var want := orbit_r if orbit_r > 0.01 else r
		var right := Vector2(u.y, -u.x)  # direita de quem olha o chefe
		var ang := minf(ahead / maxf(want, 0.01), PI * 0.5) * signf(iv.x)
		var p := u * (want * cos(ang)) + right * (want * sin(ang))   # ponto no círculo, relativo ao chefe
		var d := p - rel
		if d.length() > 0.001:
			out += d.normalized() * absf(iv.x)
	if out.length() > 1.0:
		out = out.normalized()
	return out

## Mira travada: o chefe (o pé dele, como o cursor no chão).
static func aim_point(boss: SimEntity) -> Vector3:
	return Vector3(boss.position.x, 0.0, boss.position.z)

static func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)
