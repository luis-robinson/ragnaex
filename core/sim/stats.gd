class_name Stats
extends RefCounted
## Stats derivados de atributos (FOR/AGI/VIT/WILL/INT) + equipamento + classe + nível.
## Pura função: `compute()` gera um Stats novo. Nunca toca nós.

var max_hp: float = 100.0
var max_mp: float = 50.0
var patk: float = 10.0
var matk: float = 10.0
var pdef: float = 0.0
var mdef: float = 0.0
var crit_phys: float = 5.0     # %
var crit_mag: float = 5.0      # %
var heal_power: float = 1.0
var block_chance: float = 0.0  # % (passivo, só com escudo)
var block_reduction: float = 0.0 # %
var move_speed: float = 5.5
var lifesteal: float = 0.0       # % do dano causado que volta como vida (golpes diretos; dano no tempo não conta)
var attack_speed: float = 0.0    # % a mais de velocidade do ataque básico (recarga menor)
var buff_duration: float = 0.0   # % a mais de duração nas bênçãos e escudos que você lança (em você e nos aliados)
var radiance: float = 0.0        # % do dano mágico direto que cura o aliado mais ferido por perto (você incluso)
var pet_power: float = 0.0       # % a mais de vida e ataque do companheiro (Ranger Caçador)
var evasion: float = 0.0         # % de chance de esquivar um golpe direto inteiro (Assassino)
var hit_poison: float = 0.0      # dano por segundo do veneno que cada golpe físico aplica (buff de veneno na lâmina)
var fire_pct: float = 0.0        # % de dano das skills de fogo (Elementalista)
var frost_pct: float = 0.0       # % de dano das skills de gelo
var storm_pct: float = 0.0       # % de dano das skills de raio
var backstab: float = 0.0        # % a mais de dano (e +crítico) golpeando pelas costas
var cdr: float = 0.0             # % de recarga a menos em todas as skills (talentos de escolha)
var echo_chance: float = 0.0     # arma lendária (dano): % de chance do golpe direto bater de novo...
var echo_pct: float = 0.0        # ... com esta % do dano
var thorns_pct: float = 0.0      # arma lendária (tanque): % do dano corpo a corpo recebido devolvido
var ward_pct: float = 0.0        # arma lendária (cura): % da cura que vira barreira
var legend: Dictionary = {}      # efeito da arma lendária equipada (GearCatalog.LEGEND_EFFECTS); vazio = nenhum
var attrs := {"FOR": 0, "AGI": 0, "VIT": 0, "WILL": 0, "INT": 0}
var has_shield: bool = false
var weapon_type: String = ""     # mão principal
var offhand_type: String = ""    # shield | orb | arma de 1 mão (empunhando duas) | ""
var is_ranged_weapon: bool = false
var is_magic_weapon: bool = false
var skill_dmg_pct: Dictionary = {}   # skill_id -> % de poder extra (conjuntos)
var skill_cdr_pct: Dictionary = {}   # skill_id -> % de recarga a menos (conjuntos)
var active_sets: Dictionary = {}     # set_id -> nº de peças equipadas


## Arma exigida por uma skill/evolução (alternativas; vazio = sempre). Ver SkillDef.requires.
func meets(req: Array) -> bool:
	if req.is_empty():
		return true
	for r in req:
		if _meets_one(r):
			return true
	return false

func _meets_one(r: String) -> bool:
	match r:
		"shield", "orb":
			return offhand_type == r
		"dual":
			return weapon_type in ItemDef.ONE_HANDED_MELEE and offhand_type in ItemDef.ONE_HANDED_MELEE
		"two_handed":
			return weapon_type in ItemDef.TWO_HANDED
	if r.begins_with("dual_"):
		var t := r.substr(5)
		return weapon_type == t and offhand_type == t
	return weapon_type == r


## Atributo a mais de uma peça +N: % do atributo dela, nunca menos de +1 a cada 3 níveis (peça com o atributo).
static func plus_attr(base: int, pl: int) -> int:
	if base <= 0 or pl <= 0:
		return 0
	return maxi(int(round(base * pl * Balance.PLUS_ATTR_PCT)), pl / 3)

static func compute(cls: ClassDef, level: int, equipment: Dictionary, buffs: Array) -> Stats:
	var s := Stats.new()
	# 0) conjuntos: peças distintas equipadas por set_id -> bônus ativos (formato de buff)
	var set_pieces := {}
	for slot in equipment:
		var item: ItemDef = equipment[slot]
		if item and not item.legend_effect.is_empty():
			var le: Dictionary = item.legend_effect
			if s.legend.is_empty() or slot == ItemDef.Slot.WEAPON:
				s.legend = le
			match str(le.get("kind", "")):
				"echo":
					s.echo_chance = maxf(s.echo_chance, float(le.get("chance", 0)))
					s.echo_pct = maxf(s.echo_pct, float(le.get("pct", 0)))
				"thorns":
					s.thorns_pct = maxf(s.thorns_pct, float(le.get("pct", 0)))
				"ward":
					s.ward_pct = maxf(s.ward_pct, float(le.get("pct", 0)))
		if item and item.set_id != "" and not (slot in [ItemDef.Slot.WEAPON, ItemDef.Slot.OFFHAND]):     # arma não conta nas peças
			if not set_pieces.has(item.set_id):
				set_pieces[item.set_id] = {}
			set_pieces[item.set_id][item.id] = true
	var set_bonus: Array = []
	for sid in set_pieces:
		var n: int = set_pieces[sid].size()
		s.active_sets[sid] = n
		var sd: SetDef = GameData.sets.get(sid)
		if sd:
			set_bonus.append_array(sd.bonuses_for(n))
	# 1) atributos vêm SÓ de equipamento (+ buffs + conjuntos). A chave do dicionário é o slot
	#    ocupado (uma espada pode estar na mão secundária).
	for slot in equipment:
		var item: ItemDef = equipment[slot]
		if item == null:
			continue
		for a in Balance.ATTRS:
			s.attrs[a] += item.attr(a)
		if slot == ItemDef.Slot.WEAPON:
			s.weapon_type = item.weapon_type
		elif slot == ItemDef.Slot.OFFHAND:
			s.offhand_type = item.weapon_type
	s.has_shield = s.offhand_type == "shield"
	for b in buffs:
		for a in Balance.ATTRS:
			s.attrs[a] += int(b.get("attr_" + a, 0))
	for b in set_bonus:
		var ba: Dictionary = b.get("attrs", {})
		for a in ba:
			s.attrs[a] += int(ba[a])
		var sd_dmg: Dictionary = b.get("skill_dmg", {})
		for k in sd_dmg:
			s.skill_dmg_pct[k] = float(s.skill_dmg_pct.get(k, 0.0)) + float(sd_dmg[k])
		var sd_cdr: Dictionary = b.get("skill_cdr", {})
		for k in sd_cdr:
			s.skill_cdr_pct[k] = float(s.skill_cdr_pct.get(k, 0.0)) + float(sd_cdr[k])
	s.is_ranged_weapon = s.weapon_type in ["bow", "rifle"]
	s.is_magic_weapon = s.weapon_type in ["staff", "wand", "scythe", "scepter"]

	var FOR := float(s.attrs["FOR"]); var AGI := float(s.attrs["AGI"]); var VIT := float(s.attrs["VIT"])
	var WILL := float(s.attrs["WILL"]); var INT := float(s.attrs["INT"])

	# 2) equipamento: atk/def planos
	var eq_atk := 0.0; var eq_matk := 0.0; var eq_def := 0.0; var eq_mdef := 0.0
	for slot in equipment:
		var item: ItemDef = equipment[slot]
		if item == null:
			continue
		# segunda arma (empunhando duas) soma só parte do ATK
		var k := Balance.OFFHAND_WEAPON_ATK_MULT if (slot == ItemDef.Slot.OFFHAND and item.weapon_type in ItemDef.ONE_HANDED_MELEE) else 1.0
		eq_atk += item.atk * k; eq_matk += item.matk; eq_def += item.def; eq_mdef += item.mdef     # versão +N já vem com o bônus

	# 3) base por classe e nível
	var base_hp := cls.base_hp + cls.hp_per_level * (level - 1) if cls else 100.0 + 10.0 * (level - 1)
	var base_mp := cls.base_mp + cls.mp_per_level * (level - 1) if cls else 50.0 + 5.0 * (level - 1)
	s.move_speed = cls.move_speed if cls else 5.0

	s.max_hp = base_hp + VIT * Balance.HP_PER_VIT
	s.max_mp = base_mp + WILL * Balance.MP_PER_WILL
	# ataque físico: arco usa AGI; adaga mistura; resto FOR
	if s.is_ranged_weapon:
		s.patk = eq_atk + AGI * Balance.PATK_PER_AGI_RANGED + FOR * 0.3
	elif s.weapon_type == "dagger":
		s.patk = eq_atk + FOR * Balance.PATK_PER_FOR * 0.6 + AGI * Balance.PATK_PER_AGI_DAGGER
	else:
		s.patk = eq_atk + FOR * Balance.PATK_PER_FOR + AGI * Balance.PATK_PER_AGI_OTHER
	s.patk += 4.0 + level * 0.8
	s.matk = eq_matk + INT * Balance.MATK_PER_INT + 4.0 + level * 0.8
	s.pdef = eq_def + VIT * Balance.PDEF_PER_VIT
	s.mdef = eq_mdef + WILL * Balance.MDEF_PER_WILL
	s.crit_phys = Balance.CRIT_BASE + AGI * Balance.CRIT_PER_AGI
	s.crit_mag = Balance.CRIT_BASE + INT * Balance.MCRIT_PER_INT
	s.heal_power = 1.0 + WILL * Balance.HEAL_PER_WILL
	if s.has_shield:
		s.block_chance = Balance.BLOCK_BASE_SHIELD + maxf(FOR, WILL) * Balance.BLOCK_PER_FOR_SHIELD     # fé segura escudo tanto quanto força
		var off: ItemDef = equipment.get(ItemDef.Slot.OFFHAND)
		if off:
			s.block_chance += float(off.shield_effect.get("block_bonus", 0.0))
	if s.is_magic_weapon:
		s.block_reduction = Balance.BLOCK_REDUCTION_MAGIC_WEAPON
	else:
		s.block_reduction = minf(Balance.BLOCK_REDUCTION_BASE + FOR * Balance.BLOCK_REDUCTION_PER_FOR, Balance.BLOCK_REDUCTION_CAP)

	# 4) buffs e bônus de conjunto percentuais
	for b in buffs + set_bonus:
		s.patk *= 1.0 + float(b.get("atk_pct", 0)) / 100.0
		s.matk *= 1.0 + float(b.get("matk_pct", 0)) / 100.0
		s.pdef *= 1.0 + float(b.get("def_pct", 0)) / 100.0
		s.mdef *= 1.0 + float(b.get("def_pct", 0)) / 100.0
		s.move_speed *= 1.0 + float(b.get("speed_pct", 0)) / 100.0
		s.heal_power *= 1.0 + float(b.get("heal_pct", 0)) / 100.0
		s.max_hp *= 1.0 + float(b.get("hp_pct", 0)) / 100.0
		s.max_mp *= 1.0 + float(b.get("mp_pct", 0)) / 100.0
		s.crit_phys += float(b.get("crit", 0))
		s.crit_mag += float(b.get("crit", 0))
		s.lifesteal += float(b.get("lifesteal", 0))
		s.attack_speed += float(b.get("aspd_pct", 0))
		s.buff_duration += float(b.get("buff_pct", 0))
		s.radiance += float(b.get("radiance", 0))
		s.pet_power += float(b.get("pet_pct", 0))
		s.evasion += float(b.get("evasion", 0))
		s.hit_poison = maxf(s.hit_poison, float(b.get("hit_poison", 0)))
		s.backstab += float(b.get("backstab", 0))
		s.cdr += float(b.get("cdr", 0))
		s.fire_pct += float(b.get("fire_pct", 0))
		s.frost_pct += float(b.get("frost_pct", 0))
		s.storm_pct += float(b.get("storm_pct", 0))
	s.lifesteal = minf(s.lifesteal, Balance.LIFESTEAL_CAP)
	s.attack_speed = minf(s.attack_speed, Balance.ATTACK_SPEED_CAP)
	s.buff_duration = minf(s.buff_duration, Balance.BUFF_DURATION_CAP)
	s.radiance = minf(s.radiance, Balance.RADIANCE_CAP)
	s.evasion = minf(s.evasion, Balance.EVASION_CAP)
	s.cdr = minf(s.cdr, Balance.CDR_CAP)
	s.fire_pct = minf(s.fire_pct, Balance.ELEMENT_CAP)
	s.frost_pct = minf(s.frost_pct, Balance.ELEMENT_CAP)
	s.storm_pct = minf(s.storm_pct, Balance.ELEMENT_CAP)
	return s

## Recarga do ataque básico com a velocidade de ataque.
func basic_cooldown(base_cd: float) -> float:
	return base_cd / (1.0 + attack_speed / 100.0)

## Multiplicador de poder de uma skill vindo de conjuntos (1.0 = nada).
func skill_power_mult(skill_id: String) -> float:
	return 1.0 + float(skill_dmg_pct.get(skill_id, 0.0)) / 100.0

## Multiplicador de elemento: média dos bônus dos elementos da skill (combinação de fogo e raio usa os dois).
func element_mult(elements: Array[String]) -> float:
	if elements.is_empty():
		return 1.0
	var sum := 0.0
	for el in elements:
		sum += element_pct(el)
	return 1.0 + sum / elements.size() / 100.0

func element_pct(el: String) -> float:
	match el:
		"fire": return fire_pct
		"frost": return frost_pct
		"storm": return storm_pct
	return 0.0

func skill_cooldown_mult(skill_id: String) -> float:
	return maxf(0.2, 1.0 - (float(skill_cdr_pct.get(skill_id, 0.0)) + cdr) / 100.0)


static func from_monster(m: MonsterDef) -> Stats:
	var s := Stats.new()
	s.max_hp = m.hp; s.max_mp = 100.0
	s.patk = m.atk; s.matk = m.matk if m.matk > 0 else m.atk
	s.pdef = m.def; s.mdef = m.mdef
	s.move_speed = m.move_speed
	s.crit_phys = 3.0; s.crit_mag = 3.0
	return s
