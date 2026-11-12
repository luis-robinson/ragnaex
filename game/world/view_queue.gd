class_name ViewQueue
extends RefCounted
## Fila das entidades que ainda não têm EntityView (só apresentação; a sim não sabe dela).
## Criar um boneco (kit + fusão de malhas) custa ms na thread principal: o `main` cria poucos por quadro, num
## orçamento de tempo, os mais importantes primeiro. Quem está além do alcance espera na fila até chegar perto.
## Thread: só a thread principal (o main chama de `_process` e dos sinais do Events, que saem no `Sim.sync`).
##
## Exemplo:
##     var q := ViewQueue.new()
##     q.push(e)                                    # entity_spawned
##     q.erase(id)                                  # entity_despawned / trocou de mapa
##     for e in q.ready_list(player_pos, 66.0, {party_id: true}):
##         if over_budget: break
##         q.erase(e.id); create_view(e)

var _items: Dictionary = {}          # entity_id -> SimEntity
var _ready: Array = []               # reaproveitado por ready_list (não aloca a cada quadro)
var _prio: Dictionary = {}           # ids com prioridade na ordenação corrente
var _at := Vector3.ZERO

func push(e: SimEntity) -> void:
	_items[e.id] = e

func erase(id: int) -> void:
	_items.erase(id)

func clear() -> void:
	_items.clear()
	_ready.clear()

func has(id: int) -> bool:
	return _items.has(id)

func size() -> int:
	return _items.size()

## Entidades da fila que podem ganhar view agora: no mapa `map_id`, a até `reach` m de `at` (ids em `prio` e as
## invocações deles entram a qualquer distância). Ordem: `prio` primeiro, depois a mais perto de `at`.
## O Array devolvido é reaproveitado: use antes da próxima chamada.
func ready_list(map_id: String, at: Vector3, reach: float, prio: Dictionary) -> Array:
	_ready.clear()
	var lim2 := reach * reach
	for id in _items:
		var e: SimEntity = _items[id]
		if e.map_id != map_id:
			continue
		var dx: float = e.position.x - at.x
		var dz: float = e.position.z - at.z
		if dx * dx + dz * dz < lim2 or _is_prio(e, prio):
			_ready.append(e)
	_prio = prio
	_at = at
	_ready.sort_custom(_before)
	return _ready

static func _is_prio(e: SimEntity, prio: Dictionary) -> bool:
	return prio.has(e.id) or (e.owner_id >= 0 and prio.has(e.owner_id))

func _before(a: SimEntity, b: SimEntity) -> bool:
	var pa := _is_prio(a, _prio)
	if pa != _is_prio(b, _prio):
		return pa
	var da: float = Vector2(a.position.x - _at.x, a.position.z - _at.z).length_squared()
	var db: float = Vector2(b.position.x - _at.x, b.position.z - _at.z).length_squared()
	return da < db
