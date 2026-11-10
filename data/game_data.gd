extends Node
## GameData (autoload): catálogo de todas as definições, indexadas por id.
## Os dados são escritos em GDScript (data/catalog/*.gd) e viram Resources em memória;
## qualquer um pode ser salvo como .tres com ResourceSaver se quiser editar no inspetor.

var classes: Dictionary = {}     # id -> ClassDef
var skills: Dictionary = {}      # id -> SkillDef
var items: Dictionary = {}       # id -> ItemDef
var monsters: Dictionary = {}    # id -> MonsterDef
var quests: Dictionary = {}      # id -> QuestDef
var recipes: Dictionary = {}     # id -> RecipeDef
var maps: Dictionary = {}        # id -> MapDef
var loot_tables: Dictionary = {} # id -> LootTable
var sets: Dictionary = {}        # id -> SetDef (conjuntos lendários)
var talents: Dictionary = {}     # id -> TalentDef (evoluções de skills/dash)
var trees: Dictionary = {}       # class_id -> {"start", "nodes"} (teia de pontos de skill, TreeCatalog)
var class_talents: Dictionary = {}   # id da opção -> dicionário do ClassTalentsCatalog (aba Talentos)
var bot_names: Array = []
var bot_lines: Dictionary = {}
var bot_chat: Dictionary = {}    # "<tipo>:<chave>" -> falas (BotsCatalog.pools, escolhidas por BotChat)
var _basic_cache: Dictionary = {}
var basic_skills: Dictionary = {}   # id -> SkillDef dos básicos gerados (o FX acha o tema por aqui)

func _ready() -> void:
	load_all()

func load_all() -> void:
	for c in ClassesCatalog.build():
		classes[c.id] = c
	for s in SkillsCatalog.build(classes):
		s.power *= float(Balance.BUILD_POWER.get(s.build, 1.0))
		skills[s.id] = s
	# pool de skills de cada classe = todas as skills dela, por nível (a ordem da janela K)
	for cid in classes:
		var pool: Array = []
		for sid in skills:
			if skills[sid].class_id == cid:
				pool.append(skills[sid])
		pool.sort_custom(func(a, b): return a.unlock_level < b.unlock_level or (a.unlock_level == b.unlock_level and a.id < b.id))
		classes[cid].skill_ids.clear()
		for s in pool:
			classes[cid].skill_ids.append(s.id)
	for t in TalentsCatalog.build():
		talents[t.id] = t
	for cid in ClassTalentsCatalog.build().values():
		for row in cid:
			for o in row[1]:
				class_talents[o["id"]] = o
	trees = TreeCatalog.build(classes, skills, talents)
	for i in ItemsCatalog.build():
		items[i.id] = i
	var gear := GearCatalog.build(classes, skills)
	for i in gear["items"]:
		items[i.id] = i
	for sd in gear["sets"]:
		sets[sd.id] = sd
	_scale_attrs()
	for m in MonstersCatalog.build():
		monsters[m.id] = m
	for l in MonstersCatalog.build_loot():
		loot_tables[l.id] = l
	for q in QuestsCatalog.build():
		quests[q.id] = q
	for r in RecipesCatalog.build():
		recipes[r.id] = r
	for m in MapsCatalog.build():
		maps[m.id] = m
	for q in QuestsCatalog.hunts(monsters, maps, quests):     # caçadas repetíveis geradas
		quests[q.id] = q
	QuestsCatalog.scale_xp(quests)             # quests dão ~45% da XP de cada faixa (Balance.XP_QUEST_SHARE)
	bot_names = BotsCatalog.NAMES.duplicate()
	bot_lines = BotsCatalog.LINES
	bot_chat = BotsCatalog.pools()

## Catálogos escritos na escala antiga de atributos: itens e bônus de conjunto x Balance.ATTR_SCALE (cópia nova:
## nada de dicionário compartilhado escalado duas vezes).
func _scale_attrs() -> void:
	for id in items:
		var it: ItemDef = items[id]
		var out := {}
		for a in it.attributes:
			out[a] = int(it.attributes[a]) * Balance.ATTR_SCALE
		it.attributes = out
	for sid in sets:
		var sd: SetDef = sets[sid]
		for k in sd.bonuses:
			var b: Dictionary = sd.bonuses[k]
			if b.has("attrs"):
				var out := {}
				for a in b["attrs"]:
					out[a] = int(b["attrs"][a]) * Balance.ATTR_SCALE
				var nb := b.duplicate()
				nb["attrs"] = out
				sd.bonuses[k] = nb

## Versão aprimorada de um item: id "<base>+N", stats da base com o bônus por nível. Cada cópia aprimorada
## vira um item próprio (a espada +3 e a espada +0 são pilhas diferentes). Criada uma vez e guardada em `items`.
func plus_item(base: ItemDef, n: int) -> ItemDef:
	if n <= 0:
		return base
	var id := "%s+%d" % [base.id, n]
	if items.has(id):
		return items[id]
	var it: ItemDef = base.duplicate(true)
	it.id = id
	it.base_id = base.id
	it.plus = n
	it.name = "+%d %s" % [n, base.name]
	var wk := 1.0 + n * Balance.PLUS_WEAPON_PCT
	var ak := 1.0 + n * Balance.PLUS_ARMOR_PCT
	it.atk = base.atk * wk
	it.matk = base.matk * wk
	it.def = base.def * ak
	it.mdef = base.mdef * ak
	var attrs := {}
	for a in base.attributes:
		attrs[a] = int(base.attributes[a]) + Stats.plus_attr(int(base.attributes[a]), n)
	it.attributes = attrs
	it.price = int(base.price * (1.0 + 0.25 * n))
	items[id] = it
	return it

## O id existe (ou é uma versão "+N" de um item que existe, criada agora). Para ler saves.
## Id antigo de item de build que saiu do jogo -> o equivalente de hoje (save antigo). O Patrulheiro (arco) virou o
## Lanceiro (lança): a armadura de couro passa para o conjunto do Lanceiro do mesmo nível e o arco vira o do Caçador.
const LEGACY_PREFIX := "leg_ranger_patrulheiro_"
func migrate_item_id(id: String) -> String:
	if id.begins_with(LEGACY_PREFIX):
		var weapon := id.get_slice("+", 0).ends_with("_weapon")
		return ("leg_ranger_cacador_" if weapon else "leg_ranger_lanceiro_") + id.substr(LEGACY_PREFIX.length())
	return id

func resolve_item(id: String) -> bool:
	if items.has(id):
		return true
	var cut := id.rfind("+")
	if cut <= 0:
		return false
	var base := id.substr(0, cut)
	var n := int(id.substr(cut + 1))
	if not items.has(base) or n <= 0 or n > Balance.PLUS_MAX:
		return false
	plus_item(items[base], n)
	return true

func town_map_id() -> String:
	for id in maps:
		if maps[id].is_town:
			return id
	return maps.keys()[0]

## Itens lendários que um personagem da classe pode ganhar no nível lendário `level`:
## peças do conjunto da classe + escudo/orbe lendário se a classe usa.
func legendary_pool(cls: ClassDef, level: int, build_id: String = "") -> Array:
	var out: Array = []
	for b in cls.builds:
		if build_id != "" and b["id"] != build_id:
			continue
		var sd: SetDef = sets.get(set_id_for(cls.id, b["id"], level))
		if sd:
			out.append_array(sd.pieces)
			out.append_array(sd.alt_pieces)       # a maça do conjunto também cai
	return out

static func set_id_for(class_id: String, build_id: String, level: int) -> String:
	return "set_%s_%s_%d" % [class_id, build_id, level]

## Evoluções de uma classe (ordem: nível).
func talents_for_class(class_id: String) -> Array:
	var out: Array = []
	for tid in talents:
		if talents[tid].class_id == class_id:
			out.append(talents[tid])
	out.sort_custom(func(a, b): return a.unlock_level < b.unlock_level)
	return out

func class_list() -> Array:
	var out := classes.values()
	out.sort_custom(func(a, b): return a.name < b.name)
	return out

func random_bot_line(ctx: String) -> String:
	var arr: Array = bot_lines.get(ctx, bot_lines.get("town", ["..."]))
	return arr[randi() % arr.size()]

## Ataque básico como SkillDef gerado por classe (cadência, alcance e tipo vêm da ClassDef).
## Classe de ataque à distância empunhando arma corpo a corpo (druida de martelo, ranger de machados...)
## ataca corpo a corpo e físico.
func basic_skill_for_class(cls: ClassDef, weapon_type: String = "", offhand_type: String = "", build_id: String = "") -> SkillDef:
	var spear := weapon_type == "spear"         # lança: estocada longa e estreita (Ranger Lanceiro)
	var melee_override := cls.basic_attack_is_ranged and weapon_type in ItemDef.MELEE_TYPES and not spear
	# arma corpo a corpo de duas mãos (montante, malho, machado): golpe largo — também no bispo de malho (golpe corpo a corpo)
	var big := weapon_type in Balance.BIG_SWING_WEAPONS and (melee_override or not cls.basic_attack_is_ranged)
	var rifle := weapon_type == "rifle" and cls.basic_attack_is_ranged
	var look: String = str(cls.build_by_id(build_id).get("signature", {}).get("look", ""))
	var key := "basic_" + cls.id + ("_melee" if melee_override else "") + ("_big" if big else "") + ("_rifle" if rifle else "") + ("_spear" if spear else "") + ("_" + look if look != "" else "")
	if _basic_cache.has(key):
		return _basic_cache[key]
	var ranged := cls.basic_attack_is_ranged and not melee_override and not spear
	var cd := cls.basic_attack_cooldown
	var s := SkillDef.new()
	s.id = key
	s.name = "Ataque"
	s.class_id = cls.id
	s.kind = SkillDef.Kind.PHYSICAL if melee_override or spear else cls.basic_attack_kind
	s.power = (1.0 if melee_override else cls.basic_attack_power) * Balance.SIGNATURE_BASIC_TRIM
	s.look = look
	s.mp_cost = 0.0
	s.cooldown = cd
	s.startup = 0.12 if not ranged else 0.18
	s.active = 0.06
	s.recovery = maxf(0.12, cd * 0.45)
	s.cancel_after = 0.05
	s.lock_facing = false                  # segue o cursor até o impacto
	s.hit_stop_frames = Balance.HIT_STOP_FRAMES_BASIC
	s.max_targets = 1 if ranged else 2
	if ranged:
		s.target = SkillDef.Target.DIRECTION
		s.range = cls.basic_attack_range
		s.radius = 0.35
		s.projectile_speed = 22.0
		if rifle:              # mosquete: tiro lento, pesado, longo e rápido no ar
			s.cooldown = cd * Balance.RIFLE_COOLDOWN_MULT
			s.power *= Balance.RIFLE_POWER_MULT
			s.range *= Balance.RIFLE_RANGE_MULT
			s.projectile_speed = 40.0
			s.startup = 0.22
			s.recovery = maxf(0.12, s.cooldown * 0.45)
		s.icon_color = cls.color
	else:
		s.target = SkillDef.Target.CONE
		s.radius = 2.0 if melee_override else cls.basic_attack_range
		s.cone_angle_deg = 110.0
		if spear:              # estocada: alcance longo, cone estreito, atravessa a fila
			s.radius = Balance.SPEAR_REACH
			s.cone_angle_deg = Balance.SPEAR_ARC_DEG
			s.max_targets = Balance.SPEAR_MAX_TARGETS
			s.power *= Balance.SPEAR_POWER_MULT
			s.cooldown = cd * Balance.SPEAR_COOLDOWN_MULT
			s.recovery = maxf(0.12, s.cooldown * 0.45)
		if big:
			s.radius *= Balance.BIG_SWING_REACH_MULT
			s.cone_angle_deg = Balance.BIG_SWING_ARC_DEG
			s.max_targets = Balance.BIG_SWING_MAX_TARGETS
	_basic_cache[key] = s
	basic_skills[key] = s
	return s

## Skill do catálogo ou básico gerado (o FX recebe só o id).
func skill_or_basic(skill_id: String) -> SkillDef:
	return skills.get(skill_id, basic_skills.get(skill_id))

func basic_skill_for_monster(m: MonsterDef) -> SkillDef:
	var key := "basic_mob_" + m.id
	if _basic_cache.has(key):
		return _basic_cache[key]
	var s := SkillDef.new()
	s.id = key
	s.name = "Ataque"
	s.kind = SkillDef.Kind.MAGICAL if m.matk > m.atk else SkillDef.Kind.PHYSICAL
	s.power = 1.0
	s.mp_cost = 0.0
	s.cooldown = m.attack_cooldown
	s.startup = m.attack_startup
	s.active = 0.08
	s.recovery = 0.35
	s.cancel_after = 0.1
	s.hit_stop_frames = 2
	s.max_targets = 1
	s.icon_color = m.color
	if m.ranged:
		s.target = SkillDef.Target.DIRECTION
		s.range = m.attack_range
		s.radius = 0.35
		s.projectile_speed = 14.0
	else:
		s.target = SkillDef.Target.CONE
		s.radius = m.attack_range
		s.cone_angle_deg = 100.0
	_basic_cache[key] = s
	return s
