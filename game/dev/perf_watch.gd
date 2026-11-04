class_name PerfWatch
extends RefCounted
## Vigia de desempenho: a cada 2 s mede o FPS; abaixo de 25 grava em user://perf_log.txt onde estava e o que pesou
## (a sim mede as fases nos 2 s seguintes). Para investigar lentidão que só aparece jogando.

const LOW_FPS := 25.0
const LOG_PATH := "user://perf_log.txt"
var _t := 0.0
var _frames := 0
var _worst := 0.0
var _profiling := false
var _ticks0 := 0

func tick(main: Node, delta: float) -> void:
	if Sim.player == null:
		return
	_t += delta
	_frames += 1
	_worst = maxf(_worst, delta)
	if _t < 2.0:
		return
	var fps := _frames / _t
	if _profiling:                          # 2 s medindo as fases: grava e desliga
		var nt := maxi(1, Sim.tick_count - _ticks0)
		var keys: Array = Sim.prof.keys()
		keys.sort_custom(func(a, b): return Sim.prof[a] > Sim.prof[b])
		var parts: Array = []
		for k in keys.slice(0, 8):
			parts.append("%s=%.2f" % [k, Sim.prof[k] / nt / 1000.0])
		_log("  fases (ms/tick): " + ", ".join(parts))
		Sim.profile = false
		_profiling = false
	elif fps < LOW_FPS:
		var p := Sim.player
		var awake := 0
		var mobs := 0
		for e in Sim.map_entities(p.map_id):
			if e.kind == SimEntity.Kind.MONSTER:
				mobs += 1
				if not e.dormant:
					awake += 1
		var rid := main.get_viewport().get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(rid, true)
		_log("%s fps=%.1f pior_quadro=%.0fms mapa=%s pos=(%.0f,%.0f) nv=%d classe=%s monstros=%d acordados=%d bonecos=%d nos=%d objetos=%d draws=%d tick=%.2fms gpu=%.1fms cpu_render=%.1fms mem=%.0fMB" % [
			Time.get_datetime_string_from_system(), fps, _worst * 1000.0, p.map_id, p.position.x, p.position.z, p.level, p.class_def.id, mobs, awake,
			main.views.values().filter(func(v): return v.visible).size(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Sim.tick_usec / 1000.0,
			RenderingServer.viewport_get_measured_render_time_gpu(rid), RenderingServer.viewport_get_measured_render_time_cpu(rid), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
		Sim.prof.clear()
		Sim.profile = true
		_profiling = true
		_ticks0 = Sim.tick_count
	_t = 0.0
	_frames = 0
	_worst = 0.0

func _log(line: String) -> void:
	var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(line)
	f.close()
