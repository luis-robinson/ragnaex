extends Node
## Auditoria dos buffs no boneco: cada buff que o jogo pode pôr (BuffLooks.sources) e o visual dele (BuffLooks.look).
## Uso: --headless --path . tools/tests/buff_audit.tscn  -> linhas em markdown (docs/buffs_visual.md) e o total.

const WHAT := {
	"armor": "borda + padrão na pele do tema", "shield": "bolha translúcida (some com o escudo)", "power": "chama do tema em volta + borda tremendo",
	"holy": "auréola + brilho dourado", "speed": "rastros de vento nos pés", "smoke": "fumaça nos pés", "poison": "gotas verdes da arma + borda verde",
	"dark": "sombra subindo pelo corpo + fumaça roxa", "aura": "anel no chão + borda (grupo: borda fraca)", "form": "o boneco muda (forma/transparência)",
}
const SHELL := ["", "bolha", "cristal", "chama"]

func _ready() -> void:
	var by_id := {}
	for src in BuffLooks.sources():
		var id: String = src["id"]
		if not by_id.has(id):
			by_id[id] = []
		if not by_id[id].has(src["source"]):
			by_id[id].append(src["source"])
	var ids := by_id.keys()
	ids.sort()
	var had := 0
	var now := 0
	print("| buff | fontes | família | tema | antes | agora |")
	print("|---|---|---|---|---|---|")
	for id in ids:
		var lk: Dictionary = BuffLooks.look(id)
		var fam: String = lk.get("family", "")
		var before := "sim (corpo muda)" if fam == "form" else ("anel no chão (aura ligada)" if fam == "aura" else "não (só anel no pé no início)")
		if fam in ["form", "aura"]:
			had += 1
		var shown := "**SEM VISUAL**"
		if not lk.is_empty():
			now += 1
			shown = WHAT.get(fam, fam)
			if lk["parts"] != "":
				shown += "; partículas `%s`" % lk["parts"]
			if int(lk["shell"]) > 0:
				shown += "; casca `%s`" % SHELL[int(lk["shell"])]
		var srcs: Array = by_id[id]
		var stxt := ", ".join(srcs.slice(0, 3)) + (" +%d" % (srcs.size() - 3) if srcs.size() > 3 else "")
		print("| `%s` | %s | %s | %s | %s | %s |" % [id, stxt, fam, lk.get("theme", ""), before, shown])
	print("BUFF_AUDIT total=%d tinham=%d agora=%d" % [ids.size(), had, now])
	get_tree().quit()
