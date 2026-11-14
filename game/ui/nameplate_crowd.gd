class_name NameplateCrowd
extends RefCounted
## Matilha densa (canil: 15 nomes um em cima do outro): monstro comum no meio de muitos esconde o NOME (a barra de
## vida fica). Volta o nome: mouse em cima, alvo do jogador, ou um dos AGGRO_NAMES agressores mais perto do jogador.
## Chefe, elite, NPC, bot e jogador sempre mostram. Passada única a cada 0,2 s (main._cull_views), não por boneco.

const RADIUS := 4.0             # m: vizinhos que contam como a mesma matilha
const CROWD_N := 4              # comuns dentro do raio (contando ele) para esconder o nome
const AGGRO_NAMES := 2          # agressores do jogador na matilha que mantêm o nome (os mais perto)
const HOVER_DIST := 1.4         # m do ponto do mouse no chão para contar como "em cima"

## Comum = monstro sem papel de destaque (chefe, rei de elite, papel elite/chefe da F2 mostram sempre).
static func is_trash(e: SimEntity) -> bool:
	if e.kind != SimEntity.Kind.MONSTER or e.monster_def == null:
		return false
	var md := e.monster_def
	return not md.is_boss and md.elite_of == "" and not (md.stat_role in ["elite", "chefe"])

## Quem esconde o nome. `pts` = posições dos comuns; `keep` = força mostrar (mouse/alvo/agressor escolhido).
## Devolve um bool por entrada: true = nome escondido.
static func hidden_names(pts: Array[Vector3], keep: Array[bool], radius: float = RADIUS, crowd_n: int = CROWD_N) -> Array[bool]:
	var out: Array[bool] = []
	out.resize(pts.size())
	var r2 := radius * radius
	for i in pts.size():
		if keep[i]:
			continue
		var n := 0
		for j in pts.size():
			var dx := pts[i].x - pts[j].x
			var dz := pts[i].z - pts[j].z
			if dx * dx + dz * dz <= r2:
				n += 1
				if n >= crowd_n:
					break
		out[i] = n >= crowd_n
	return out

## Os `n` índices mais perto de `at` entre `idx` (agressores do jogador).
static func nearest(pts: Array[Vector3], idx: Array[int], at: Vector3, n: int) -> Array[int]:
	var s := idx.duplicate()
	s.sort_custom(func(a: int, b: int) -> bool: return pts[a].distance_squared_to(at) < pts[b].distance_squared_to(at))
	return s.slice(0, n)

## Passada do main: marca EntityView.set_crowd_hidden nos comuns visíveis do mapa atual.
static func update(views: Dictionary, player: SimEntity, aim: Vector3) -> void:
	if player == null:
		return
	var vs: Array[EntityView] = []
	var pts: Array[Vector3] = []
	var keep: Array[bool] = []
	var aggro: Array[int] = []
	var hover := -1
	var best := HOVER_DIST * HOVER_DIST
	for id in views:
		var v: EntityView = views[id]
		var e: SimEntity = v.entity
		if not v.visible or e == null or e.map_id != player.map_id or not is_trash(e) or not e.is_alive():
			if v.visible:
				v.set_crowd_hidden(false)
			continue
		var i := vs.size()
		vs.append(v)
		pts.append(e.position)
		keep.append(e.id == player.last_target_id)
		if e.aggro_target == player.id:
			aggro.append(i)
		var dx := e.position.x - aim.x
		var dz := e.position.z - aim.z
		if dx * dx + dz * dz < best:
			best = dx * dx + dz * dz
			hover = i
	if hover >= 0:
		keep[hover] = true
	for i in nearest(pts, aggro, player.position, AGGRO_NAMES):
		keep[i] = true
	var hid := hidden_names(pts, keep)
	for i in vs.size():
		vs[i].set_crowd_hidden(hid[i])
