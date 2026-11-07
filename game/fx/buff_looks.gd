class_name BuffLooks
extends RefCounted
## Como cada buff aparece NO BONECO enquanto dura (BuffAura). Só apresentação: lê ids que a sim põe em SimEntity.buffs.
##
## LOOKS: id do buff -> [família, tema]. Tema = paleta de SkillFx.PALETTE ("" = o tema (vfx) da skill que dá o buff).
## Famílias (o que aparece):
##   armor  defesa: borda + padrão na pele pelo tema (gelo cristal, pedra/osso placas, casca, brilho sagrado)
##          + partículas lentas do tema; gelo ganha casca de cristal facetada
##   shield escudo de HP (efeito "shield"): bolha translúcida que some junto com o escudo restante
##   power  ATK/crítico/velocidade de ataque: chama do tema em volta (línguas subindo) + borda tremendo + brasas (raio: faíscas)
##   holy   bênção: auréola sobre a cabeça + brilho dourado subindo + motas
##   speed  velocidade: rastros de vento no chão atrás dos pés
##   smoke  cortina de fumaça: fumaça nos pés
##   poison lâmina envenenada: gotas verdes pingando da arma
##   dark   pacto sombrio: sombra subindo pelo corpo + fumaça roxa
##   aura   aura de liga/desliga (anel no chão do FxManager) + borda; quem recebe vê só a borda, fraca
##   form   forma/furtividade: o próprio boneco muda (EntityView: bicho, fantasma, transparência)
## Buff novo sem linha aqui = falha no teste (_check_buff_visuals): nada de buff invisível.
const LOOKS := {
	# defesa
	"frost_armor": ["armor", "ice"], "crystal_ward": ["armor", "ice"],
	"stoneskin": ["armor", "earth"],
	"bark": ["armor", "nature"], "oak_skin": ["armor", "nature"], "bellow": ["armor", "nature"],
	"bone_armor": ["armor", "bone"], "bonewall": ["armor", "bone"],
	"blessed_armor": ["armor", "holy"], "ward": ["armor", "holy"], "bulwark": ["armor", "holy"],
	"shield_wall": ["armor", "holy"], "bastion": ["armor", "holy"], "juramento": ["armor", "holy"],
	"duel_guard": ["armor", "physical"],
	# escudo de HP
	"shield": ["shield", ""],
	# ataque
	"fury": ["power", "blood"], "warcry": ["power", "blood"], "bloodlust": ["power", "blood"], "titan_grip": ["power", "blood"],
	"frenzy": ["power", "blood"], "legend_frenzy": ["power", "blood"], "elixir": ["power", "fire"],
	"valor": ["power", "holy"], "zeal": ["power", "holy"], "fervor": ["power", "holy"], "battle_hymn": ["power", "holy"],
	"mark": ["power", "physical"], "deadeye": ["power", "physical"], "focus": ["power", "physical"], "duel_focus": ["power", "physical"],
	"pack": ["power", "nature"], "overload": ["power", "lightning"],
	# bênçãos
	"blessing": ["holy", "holy"], "angel": ["holy", "holy"], "avenging_wrath": ["holy", "holy"], "grove": ["holy", "nature"],
	# movimento
	"swift": ["speed", "wind"], "tumble": ["speed", "wind"], "reflexes": ["speed", "wind"], "wild_run": ["speed", "nature"],
	"smoke": ["smoke", "shadow"],
	# arma / sombra
	"plague_blade": ["poison", "poison"],
	"dark_pact": ["dark", "shadow"],
	# auras de liga/desliga
	"bastion_aura": ["aura", "holy"],
	# o boneco muda (EntityView)
	"stealth": ["form", "shadow"], "form_wolf": ["form", "nature"], "form_bear": ["form", "nature"],
	"form_phantom": ["form", "lunar"], "form_demon": ["form", "fire"],
}
const FAMILIES := ["armor", "shield", "power", "holy", "speed", "smoke", "poison", "dark", "aura", "form"]

## Buffs que a sim põe direto no código (sem catálogo): id -> onde.
const SYSTEM_BUFFS := {
	"legend_frenzy": "LegendEffects (arma lendária: frenesi)",
	"bastion": "RaidSystem (sentinela: reunir)",
	"juramento": "ShieldSystem (Juramento ao bloquear)",
	"shield": "WorldSim (efeito shield, Égide lendária)",
}

## Padrão na pele (uniform buff_style do toon) por tema.
const RIM_STYLE := {"ice": 1, "earth": 2, "bone": 2, "blood": 3, "fire": 3, "lightning": 3, "nature": 4, "holy": 5, "shadow": 6}
## Partículas da família armor por tema (as outras famílias têm uma só).
const ARMOR_PARTS := {"ice": "snow", "earth": "dust", "nature": "leaves", "bone": "bone", "holy": "motes"}
const FAMILY_PARTS := {"holy": "motes", "speed": "streaks", "smoke": "smoke", "poison": "drip", "dark": "shadow"}
## Escudo de HP: tema pela classe de quem tem (ossos do necro, gelo do mago...)
const SHIELD_THEME := {"necromancer": "bone", "elementalist": "ice", "druid": "nature"}

static var _cache: Dictionary = {}
static var _skill_theme: Dictionary = {}
static var _shield_cache: Dictionary = {}

## Visual resolvido do buff `id` em `e` (cacheado; nada alocado depois do primeiro):
## {family, theme, color, accent, rim_style, parts, shell (0 nada, 1 bolha, 2 cristal, 3 chama), halo}
static func look(id: String, e: SimEntity = null) -> Dictionary:
	var key := id
	if id == "shield" and e != null and e.class_def != null:
		if _shield_cache.has(e.class_def.id):          # sem montar string a cada consulta (BuffAura pergunta 10x/s)
			return _shield_cache[e.class_def.id]
		key = "shield:" + e.class_def.id
	elif _cache.has(key):
		return _cache[key]
	var row: Array = LOOKS.get(id, [])
	if row.is_empty():
		_cache[key] = {}
		return _cache[key]
	var fam: String = row[0]
	var th: String = row[1]
	if id == "shield":
		th = SHIELD_THEME.get(e.class_def.id if e != null and e.class_def != null else "", "holy")
	if th == "":
		th = skill_theme(id)
	var parts := ""
	match fam:
		"armor":
			parts = ARMOR_PARTS.get(th, "")
		"power":
			parts = "sparks" if th in ["lightning", "physical"] else "embers"
		_:
			parts = FAMILY_PARTS.get(fam, "")
	var shell := 0
	if fam == "shield":
		shell = 1
	elif fam == "armor" and th == "ice":
		shell = 2
	elif fam == "power":
		shell = 3
	var d := {"family": fam, "theme": th, "color": SkillFx.col(th, 0), "accent": SkillFx.col(th, 1),
		"rim_style": int(RIM_STYLE.get(th, 0)), "parts": parts, "shell": shell, "halo": fam == "holy"}
	if fam == "dark":
		d["color"] = Color(0.62, 0.32, 0.95)      # o roxo escuro da paleta some na pele: borda mais clara
	if fam == "power" and th == "physical":
		d["color"] = Color(1.0, 0.78, 0.3)        # foco/crítico: brilho dourado (o branco do aço só desbota o boneco)
		d["accent"] = Color(1.0, 0.95, 0.7)
	if fam == "smoke":
		d["color"] = Color(0.7, 0.72, 0.78)
	_cache[key] = d
	if key.begins_with("shield:"):
		_shield_cache[e.class_def.id] = d
	return d

## Tema (vfx) da skill que dá o buff `id` ("holy" se nenhuma).
static func skill_theme(id: String) -> String:
	if _skill_theme.is_empty():
		for sid in GameData.skills:
			var s: SkillDef = GameData.skills[sid]
			var b = s.effects.get("buff")
			if b is Dictionary and not _skill_theme.has(str(b.get("id", ""))):
				_skill_theme[str(b.get("id", ""))] = s.vfx
	return _skill_theme.get(id, "holy")

## Todos os buffs que o jogo pode pôr: [{id, source}] — skills (buff/shield/form/stealth/aura), evoluções,
## mods de forma, talentos de classe, consumíveis e os buffs fixos dos sistemas. Usado pelo teste e pelo buff_audit.
static func sources() -> Array:
	var out: Array = []
	for sid in GameData.skills:
		var s: SkillDef = GameData.skills[sid]
		_from_effects(out, s.effects, "skill %s (%s)" % [sid, s.name])
	for tid in GameData.talents:
		var t: TalentDef = GameData.talents[tid]
		if t.mods.get("buff") is Dictionary:
			out.append({"id": str(t.mods["buff"].get("id", "")), "source": "evolução %s" % tid})
		if t.mods.get("effects") is Dictionary:
			_from_effects(out, t.mods["effects"], "evolução %s" % tid)
	for sid in SkillsCatalog.FORM_MODS:
		for f in SkillsCatalog.FORM_MODS[sid]:
			var fm: Dictionary = SkillsCatalog.FORM_MODS[sid][f]
			if fm.get("effects") is Dictionary:
				_from_effects(out, fm["effects"], "forma %s/%s" % [sid, f])
	for oid in GameData.class_talents:
		var o: Dictionary = GameData.class_talents[oid]
		for sk in o.get("skill_mods", {}):
			var m: Dictionary = o["skill_mods"][sk]
			if m.get("effects") is Dictionary:
				_from_effects(out, m["effects"], "talento %s" % oid)
	for iid in GameData.items:
		var it: ItemDef = GameData.items[iid]
		if it.consume.get("buff") is Dictionary:
			out.append({"id": str(it.consume["buff"].get("id", "")), "source": "item %s" % iid})
	for id in SYSTEM_BUFFS:
		out.append({"id": id, "source": SYSTEM_BUFFS[id]})
	return out

static func _from_effects(out: Array, fx: Dictionary, src: String) -> void:
	if fx.get("buff") is Dictionary:
		out.append({"id": str(fx["buff"].get("id", "")), "source": src})
	if fx.has("shield"):
		out.append({"id": "shield", "source": src})
	if fx.has("form"):
		out.append({"id": "form_" + str(fx["form"]), "source": src})
	if fx.has("stealth"):
		out.append({"id": "stealth", "source": src})
