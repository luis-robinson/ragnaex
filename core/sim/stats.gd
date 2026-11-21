class_name Stats
extends RefCounted
## Stats derivados de atributos (FOR/AGI/VIT/WILL/INT) + equipamento + classe + nível.
## Pura função: `compute()` gera um Stats novo. Nunca toca nós.

## Chaves de stat que `compute()` soma dos buffs e bônus de conjunto (passivos, set_extra, nós da teia, buffs de skill).
## Fonte única: há check de que todo passivo/bônus/buff do catálogo usa só estas (erro de digitação somava 0 em silêncio).
## Chave nova = ler aqui embaixo em `compute()` E acrescentar na lista.
const STAT_KEYS := ["atk_pct", "matk_pct", "def_pct", "speed_pct", "heal_pct", "hp_pct", "mp_pct", "crit", "lifesteal",
	"aspd_pct", "buff_pct", "radiance", "radiance_cap", "pet_pct", "evasion", "hit_poison", "backstab", "cdr", "threat_pct",
	"dr_pct", "dr_int", "fire_pct", "frost_pct", "storm_pct", "titan_relief", "turret_max", "shadow_time", "shadow_share", "execute_pct",
	"prey_crit", "falcon_pct", "block", "mp_on_kill", "mp_regen_combat", "trap_max",
	"crit_dmg_pct", "dot_pct", "cc_resist_pct", "mp_cost_pct", "summon_time_pct",
	"crit_leech", "low_leech", "mana_guard", "hit_slow", "heal_taken_pct", "def_atk_pct", "block_reflect", "guard_crit", "taunt_dmg_pct", "thorns", "phys_mend",
	"mp_to_hp", "summon_guard", "summon_frenzy", "leech_shield", "ally_guard", "low_dr", "low_hp_atk", "overheal_share"]
## Chaves de buff que não são stat: id (renova, não acumula), duração e aura de ligar/desligar.
const BUFF_META := ["id", "duration", "toggle", "end_cast", "end_power", "oath_lock",
	"scale", "wound_hold", "keep_hp", "form_bound",
	"riposte_arc", "riposte_gain", "riposte_gap", "momentum_fill", "mob_stat",
	"duel_cap", "hit_gain", "hit_cap", "duel_per"]     # Duelo Supremo: contador do Duelo (RiposteSystem.duel_hit). onda B1: escala do boneco, feridas presas, % de vida mantida, some com a forma
## Chaves de bônus de conjunto que não são stat (SetDef: atributos e bônus por skill).
const SET_BONUS_META := ["attrs", "skill_dmg", "skill_cdr", "fusion"]

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
var mp_on_kill: float = 0.0      # % da mana máxima devolvida a cada abate (joias; WorldSim._mana_on_kill)
var mp_regen_combat: float = 0.0 # % da mana máxima por s a mais enquanto em combate (capas; regen do WorldSim._update_entity)
var crit_dmg_pct: float = 0.0    # % a mais no multiplicador do crítico (acessório lendário; teto Balance.CRIT_DMG_CAP)
var dot_pct: float = 0.0         # % a mais de dano no tempo aplicado por você (fixado na aplicação; teto DOT_PCT_CAP)
var phys_mend: float = 0.0      # % do dano físico que cura o aliado mais ferido (Avatar da Fé; WorldSim.mend)
var cc_resist_pct: float = 0.0   # % a menos de duração de atordoar/prender/lentidão em você (teto CC_RESIST_CAP)
var mp_cost_pct: float = 0.0     # % a menos de custo de mana das skills (mínimo 1; teto MP_COST_CAP)
var summon_time_pct: float = 0.0 # % a mais de duração das invocações com tempo (teto SUMMON_TIME_CAP)
## Notáveis de papel da teia (Balance.ROLE_NOTABLES; regras em Combat.role_*)
var crit_leech: float = 0.0      # % do dano de um crítico direto que volta como vida (Sangue no Fio)
var low_leech: float = 0.0       # roubo de vida a mais abaixo de Balance.LOW_LEECH_HP da vida (Sede na Beira)
var mana_guard: float = 0.0      # % do dano recebido que sai da mana (Barreira de Mana; teto MANA_GUARD_CAP)
var hit_slow: float = 0.0        # % de lentidão no alvo do golpe físico direto (Flecha Pesada; HIT_SLOW_TIME s)
var heal_taken_pct: float = 0.0  # % a mais de cura recebida (SimEntity.heal_factor)
var def_atk_pct: float = 0.0     # % da DEF física que vira ATK físico (Peso da Fé / Casca Afiada)
var block_reflect: float = 0.0   # % do golpe bloqueado devolvido ao atacante (Escudo Vingador)
var guard_crit: float = 0.0      # +% de crítico por Balance.GUARD_CRIT_TIME s depois de bloquear (Contra-Ataque)
var taunt_dmg_pct: float = 0.0   # % a mais de dano em monstro cujo alvo é você (Julgamento / Fúria do Urso)
## Notáveis de base (Balance.CORE_NOTABLES; regras em Combat.core_*, WorldSim._deal_damage/_heal)
var mp_to_hp: float = 0.0        # +HP máximo = % do MP máximo (Mana em Carne)
var summon_guard: float = 0.0    # % do dano recebido que vai para a sua invocação mais perto (Escudo de Carne)
var summon_frenzy: float = 0.0   # % a mais de dano da sua invocação abaixo de SUMMON_FRENZY_HP da vida (Fúria dos Mortos)
var leech_shield: float = 0.0    # roubo de vida que passa do máximo vira barreira até % da vida máxima
var ally_guard: float = 0.0      # % do dano dos aliados do grupo por perto que vai para você (Escudo dos Irmãos)
var low_dr: float = 0.0          # -% de dano recebido abaixo de LOW_DR_HP da vida (Firme na Queda)
var low_hp_atk: float = 0.0      # até +% de dano quanto menor a vida (Fúria da Beira)
var overheal_share: float = 0.0  # % da sua cura que passa do máximo que vai para o aliado mais ferido (Graça Transbordante)
var lifesteal: float = 0.0       # % do dano causado que volta como vida (golpes diretos; dano no tempo não conta)
var shadow_time: float = 0.0    # nós "shadow_time" da teia de ascensão (Assassino): cada um +Balance.SHADOW_TIME_NODE s de clone
var shadow_share: float = 0.0   # nós "shadow_share": cada um +Balance.SHADOW_SHARE_NODE pontos de % no dano do clone
var execute_pct: float = 0.0    # nós "execute_pct": cada um +Balance.EXECUTION_NODE_PCT% de dano da Execução
var prey_crit: float = 0.0      # crítico a mais contra alvo com Presa (Olhos do Céu, Falcoeiro)
var falcon_pct: float = 0.0     # % de dano a mais do mergulho do falcão (nós da teia de ascensão do Caçador)
var turret_max: float = 0.0     # torretas a mais (Atirador ascendido; conjuntos futuros) além de Balance.TURRET_MAX
var trap_max: float = 0.0       # armadilhas a mais além do limite (Balance.TRAP_MAX ou o do talento; Ápice do Atirador)
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
var threat_pct: float = 0.0      # % a mais de ameaça gerada pelo dano (Aura do Bastião: o tanque segura o monstro)
var dr_pct: float = 0.0          # % a menos de todo dano recebido (aura do tanque no grupo; teto Balance.DR_CAP)
var echo_chance: float = 0.0     # arma lendária (dano): % de chance do golpe direto bater de novo...
var echo_pct: float = 0.0        # ... com esta % do dano
var thorns_pct: float = 0.0      # arma lendária (tanque): % do dano corpo a corpo recebido devolvido
var ward_pct: float = 0.0        # arma lendária (cura): % da cura que vira barreira
var vit_dmg_pct: float = 0.0     # % a mais de dano dos golpes pela VIT (Paladino com espada; Stats.vit_sword_pct)
var legend: Dictionary = {}      # efeito da arma lendária equipada (GearCatalog.legend_effect); vazio = nenhum
var shield_passive: Dictionary = {}     # escudo lendário com papel (GearCatalog.apply_shield_role): Determinação; vazio = nenhum
var fusion: Dictionary = {}      # Fusão do híbrido com 5 peças (números do tier + "face" = build da arma na mão; FusionEffects)
var attrs := {"FOR": 0, "AGI": 0, "VIT": 0, "WILL": 0, "INT": 0}
var has_shield: bool = false
var weapon_type: String = ""     # mão principal
var offhand_type: String = ""    # shield | orb | arma de 1 mão (empunhando duas) | ""
var is_ranged_weapon: bool = false
var is_magic_weapon: bool = false
var skill_dmg_pct: Dictionary = {}   # skill_id -> % de poder extra (conjuntos)
var skill_cdr_pct: Dictionary = {}   # skill_id -> % de recarga a menos (conjuntos)
var active_sets: Dictionary = {}     # set_id -> nº de peças equipadas
## Berserker ascendido (TitanSystem / GladiatorSystem)
var titan_pair: bool = false     # Empunhadura de Titã: machado de 2 mãos nas duas mãos
var titan_claws: bool = false    # Garras de Titã (Punhos ascendido; TitanSystem.apply liga)
var titan_hit: float = 0.0       # fração a mais de dano no golpe duplo (2ª arma / garra pesada)
var titan_speed: float = 1.0     # multiplicador da velocidade do básico (F7: 1 − (PEN − RELIEF × n))
var titan_relief: int = 0        # nós "titan_relief" da teia comprados
var gladiator: bool = false      # Modo Gladiador ligado
var glory: int = 0               # cargas de Glória


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
		"shield", "orb", "pistol":
			return offhand_type == r
		"dual":
			return (weapon_type in ItemDef.ONE_HANDED_MELEE and offhand_type in ItemDef.ONE_HANDED_MELEE) or titan_pair
		"two_handed":
			return weapon_type in ItemDef.TWO_HANDED
		"titan":                       # duas armas de 2 mãos (Empunhadura de Titã)
			return titan_pair
		"gladiator":                   # só no Modo Gladiador
			return gladiator
		"glory_full":                  # Glória cheia (Golpe Final)
			return gladiator and glory >= Balance.GLORY_MAX
	if r.begins_with("dual_"):
		var t := r.substr(5)
		return weapon_type == t and offhand_type == t
	return weapon_type == r


## Atributo a mais de uma peça +N: % do atributo dela, nunca menos de +1 (escala antiga) a cada 3 níveis (peça com o atributo).
static func plus_attr(base: int, pl: int) -> int:
	if base <= 0 or pl <= 0:
		return 0
	return maxi(int(round(base * pl * Balance.PLUS_ATTR_PCT)), pl / 3 * Balance.ATTR_SCALE)

static func compute(cls: ClassDef, level: int, equipment: Dictionary, buffs: Array) -> Stats:
	var s := Stats.new()
	# 0) conjuntos: peças distintas equipadas por set_id -> bônus ativos (formato de buff)
	var set_pieces := {}
	for slot in equipment:
		var item: ItemDef = equipment[slot]
		if item and not item.legend_effect.is_empty():
			var le: Dictionary = item.legend_effect
			if str(le.get("kind", "")) == "determination":     # escudo do conjunto (Determinação): não é a arma lendária
				s.shield_passive = le
				continue
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
	var bonus_seen := {}
	for slot in equipment:              # stats extras de item (ItemDef.bonus), somados como bônus de conjunto
		var bi: ItemDef = equipment[slot]
		if bi and not bi.bonus.is_empty():
			var bkey: String = bi.base_id if bi.base_id != "" else bi.id
			if bonus_seen.has(bkey):
				continue                # a mesma peça nos 2 anéis (ou ela e a +N): o bônus vale uma vez
			bonus_seen[bkey] = true
			set_bonus.append(bi.bonus)
	# 1) atributos vêm SÓ de equipamento (+ buffs + conjuntos). A chave do dicionário é o slot
	#    ocupado (uma espada pode estar na mão secundária).
	for slot in equipment:
		var item: ItemDef = equipment[slot]
		if item == null:
			continue
		var am := 1.0
		if slot == ItemDef.Slot.OFFHAND and item.weapon_type in ItemDef.TWO_HANDED:
			am = Balance.TITAN_OFFHAND_ATTR_MULT      # 2ª arma de 2 mãos: o peso dela vai no golpe duplo
		for a in Balance.ATTRS:
			s.attrs[a] += int(item.attr(a) * am)
		if slot == ItemDef.Slot.WEAPON:
			s.weapon_type = item.weapon_type
		elif slot == ItemDef.Slot.OFFHAND:
			s.offhand_type = item.weapon_type
	s.has_shield = s.offhand_type == "shield"
	s.titan_pair = s.weapon_type in Balance.TITAN_WEAPONS and s.offhand_type in Balance.TITAN_WEAPONS
	if s.titan_pair:
		var w_main: ItemDef = equipment[ItemDef.Slot.WEAPON]
		var w_off: ItemDef = equipment[ItemDef.Slot.OFFHAND]
		s.titan_hit = Balance.TITAN_OFFHAND_MULT * (clampf(w_off.atk / w_main.atk, 0.0, 1.0) if w_main.atk > 0.0 else 1.0)
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
	if cls and cls.id in Balance.VIT_SWORD_CLASSES and s.weapon_type in Balance.VIT_SWORD_WEAPONS:
		s.vit_dmg_pct = vit_sword_pct(s.attrs["VIT"], s.weapon_type == "sword2h")     # Paladino de espada: a VIT vira dano

	# escala nova: Balance.*_PER_* valem por ATTR_SCALE pontos
	var sc := float(Balance.ATTR_SCALE)
	var FOR: float = s.attrs["FOR"] / sc; var AGI: float = s.attrs["AGI"] / sc; var VIT: float = s.attrs["VIT"] / sc
	var WILL: float = s.attrs["WILL"] / sc; var INT: float = s.attrs["INT"] / sc

	# 2) equipamento: atk/def planos
	var eq_atk := 0.0; var eq_matk := 0.0; var eq_def := 0.0; var eq_mdef := 0.0
	for slot in equipment:
		var item: ItemDef = equipment[slot]
		if item == null:
			continue
		# segunda arma (empunhando duas) soma só parte do ATK
		var k := Balance.OFFHAND_WEAPON_ATK_MULT if (slot == ItemDef.Slot.OFFHAND and item.weapon_type in ItemDef.ONE_HANDED_MELEE) else 1.0
		if slot == ItemDef.Slot.OFFHAND and item.weapon_type in ItemDef.TWO_HANDED:
			k = 0.0                     # 2ª arma de 2 mãos: bate à parte (golpe duplo), não soma no ATK
		eq_atk += item.atk * k; eq_matk += item.matk; eq_def += item.def; eq_mdef += item.mdef     # versão +N já vem com o bônus

	# 3) base por classe e nível
	var base_hp := cls.base_hp + cls.hp_per_level * (level - 1) if cls else 100.0 + 10.0 * (level - 1)
	var base_mp := cls.base_mp + cls.mp_per_level * (level - 1) if cls else 50.0 + 5.0 * (level - 1)
	s.move_speed = cls.move_speed if cls else 5.0

	s.max_hp = base_hp + VIT * Balance.HP_PER_VIT
	s.max_mp = base_mp + WILL * Balance.MP_PER_WILL
	# ataque físico: arco usa AGI; lança AGI + FOR; adaga mistura; resto FOR
	if s.is_ranged_weapon:
		s.patk = eq_atk + AGI * Balance.PATK_PER_AGI_RANGED + FOR * Balance.PATK_PER_FOR_RANGED
	elif s.weapon_type == "spear":       # lança: AGI primeiro, FOR ajuda
		s.patk = eq_atk + AGI * Balance.PATK_PER_AGI_SPEAR + FOR * Balance.PATK_PER_FOR_SPEAR
	elif s.weapon_type in ["dagger", "claw"]:      # adaga e garra: AGI pesa mais
		s.patk = eq_atk + FOR * Balance.PATK_PER_FOR * Balance.PATK_FOR_DAGGER_SHARE + AGI * Balance.PATK_PER_AGI_DAGGER
	else:
		s.patk = eq_atk + FOR * Balance.PATK_PER_FOR + AGI * Balance.PATK_PER_AGI_OTHER
	s.patk += Balance.ATK_BASE + level * Balance.ATK_PER_LEVEL
	s.matk = eq_matk + INT * Balance.MATK_PER_INT + Balance.ATK_BASE + level * Balance.ATK_PER_LEVEL
	s.pdef = eq_def + VIT * Balance.PDEF_PER_VIT
	s.mdef = eq_mdef + WILL * Balance.MDEF_PER_WILL
	s.crit_phys = Balance.CRIT_BASE + AGI * Balance.CRIT_PER_AGI
	s.evasion = agi_evasion(AGI)          # esquiva passiva da AGI; buffs/passivos somam depois, teto no fim
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
	var rad_cap := 0.0                  # talento de classe pode subir o teto da Radiância
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
		s.mp_on_kill += float(b.get("mp_on_kill", 0))
		s.mp_regen_combat += float(b.get("mp_regen_combat", 0))
		s.attack_speed += float(b.get("aspd_pct", 0))
		s.buff_duration += float(b.get("buff_pct", 0))
		s.radiance += float(b.get("radiance", 0))
		rad_cap += float(b.get("radiance_cap", 0))
		s.pet_power += float(b.get("pet_pct", 0))
		s.evasion += float(b.get("evasion", 0))
		s.hit_poison = maxf(s.hit_poison, float(b.get("hit_poison", 0)))
		s.backstab += float(b.get("backstab", 0))
		s.cdr += float(b.get("cdr", 0))
		s.threat_pct += float(b.get("threat_pct", 0))
		s.dr_pct += float(b.get("dr_pct", 0))
		if b.get("dr_int", false):         # Armadura de Gelo: corte de dano pela INT
			s.dr_pct += frost_armor_dr(float(s.attrs["INT"]))
		s.fire_pct += float(b.get("fire_pct", 0))
		s.frost_pct += float(b.get("frost_pct", 0))
		s.storm_pct += float(b.get("storm_pct", 0))
		s.titan_relief += int(b.get("titan_relief", 0))
		if b.get("id") == Balance.GLADIATOR_BUFF:
			s.gladiator = true
		elif b.get("id") == Balance.GLORY_BUFF:
			s.glory = int(b.get("stacks", 0))
		s.turret_max += float(b.get("turret_max", 0))
		s.trap_max += float(b.get("trap_max", 0))
		s.shadow_time += float(b.get("shadow_time", 0))
		s.shadow_share += float(b.get("shadow_share", 0))
		s.execute_pct += float(b.get("execute_pct", 0))
		s.prey_crit = maxf(s.prey_crit, float(b.get("prey_crit", 0)))      # dois falcoeiros no grupo não somam
		s.falcon_pct += float(b.get("falcon_pct", 0))
		s.crit_dmg_pct += float(b.get("crit_dmg_pct", 0))
		s.dot_pct += float(b.get("dot_pct", 0))
		s.cc_resist_pct += float(b.get("cc_resist_pct", 0))
		s.phys_mend += float(b.get("phys_mend", 0))
		s.mp_cost_pct += float(b.get("mp_cost_pct", 0))
		s.summon_time_pct += float(b.get("summon_time_pct", 0))
		s.crit_leech += float(b.get("crit_leech", 0))
		s.low_leech += float(b.get("low_leech", 0))
		s.mana_guard += float(b.get("mana_guard", 0))
		s.hit_slow = maxf(s.hit_slow, float(b.get("hit_slow", 0)))
		s.heal_taken_pct += float(b.get("heal_taken_pct", 0))
		s.def_atk_pct += float(b.get("def_atk_pct", 0))
		s.block_reflect += float(b.get("block_reflect", 0))
		s.guard_crit += float(b.get("guard_crit", 0))
		s.taunt_dmg_pct += float(b.get("taunt_dmg_pct", 0))
		s.mp_to_hp += float(b.get("mp_to_hp", 0))
		s.summon_guard += float(b.get("summon_guard", 0))
		s.summon_frenzy += float(b.get("summon_frenzy", 0))
		s.leech_shield += float(b.get("leech_shield", 0))
		s.ally_guard += float(b.get("ally_guard", 0))
		s.low_dr += float(b.get("low_dr", 0))
		s.low_hp_atk += float(b.get("low_hp_atk", 0))
		s.overheal_share += float(b.get("overheal_share", 0))
		s.thorns_pct += float(b.get("thorns", 0))      # soma com a arma lendária de espinhos
		if s.has_shield:
			s.block_chance += float(b.get("block", 0))           # +% de bloqueio (Asas com Bloqueio); sem escudo não vale
	for b in set_bonus:
		if b.has("fusion"):
			FusionEffects.apply_stats(s, cls, b["fusion"])      # 5 peças do híbrido: liga a face da arma na mão
	s.lifesteal = minf(s.lifesteal, Balance.LIFESTEAL_CAP)
	s.attack_speed = minf(s.attack_speed, Balance.ATTACK_SPEED_CAP)
	s.buff_duration = minf(s.buff_duration, Balance.BUFF_DURATION_CAP)
	s.radiance = minf(s.radiance, Balance.RADIANCE_CAP + rad_cap)
	s.evasion = minf(s.evasion, Balance.EVASION_CAP)
	s.cdr = minf(s.cdr, Balance.CDR_CAP)
	s.fire_pct = minf(s.fire_pct, Balance.ELEMENT_CAP)
	s.frost_pct = minf(s.frost_pct, Balance.ELEMENT_CAP)
	s.storm_pct = minf(s.storm_pct, Balance.ELEMENT_CAP)
	s.crit_dmg_pct = minf(s.crit_dmg_pct, Balance.CRIT_DMG_CAP)
	s.dot_pct = minf(s.dot_pct, Balance.DOT_PCT_CAP)
	s.cc_resist_pct = minf(s.cc_resist_pct, Balance.CC_RESIST_CAP)
	s.mp_cost_pct = minf(s.mp_cost_pct, Balance.MP_COST_CAP)
	s.summon_time_pct = minf(s.summon_time_pct, Balance.SUMMON_TIME_CAP)
	s.mana_guard = minf(s.mana_guard, Balance.MANA_GUARD_CAP)
	s.crit_leech = minf(s.crit_leech, Balance.ROLE_LEECH_CAP)
	s.low_leech = minf(s.low_leech, Balance.ROLE_LEECH_CAP)
	s.summon_guard = minf(s.summon_guard, Balance.SUMMON_GUARD_CAP)
	s.leech_shield = minf(s.leech_shield, Balance.LEECH_SHIELD_CAP)
	s.ally_guard = minf(s.ally_guard, Balance.ALLY_GUARD_CAP)
	s.low_dr = minf(s.low_dr, Balance.LOW_DR_CAP)
	s.low_hp_atk = minf(s.low_hp_atk, Balance.LOW_HP_ATK_CAP)
	s.overheal_share = minf(s.overheal_share, Balance.OVERHEAL_SHARE_CAP)
	if s.mp_to_hp > 0.0:
		s.max_hp += s.max_mp * minf(s.mp_to_hp, Balance.MP_TO_HP_CAP) / 100.0     # Mana em Carne (depois dos % de HP e MP)
	if s.def_atk_pct > 0.0:
		s.patk += s.pdef * s.def_atk_pct / 100.0          # tanque: a DEF soma ao dano (a DEF fica igual) (depois dos % de DEF e de ATK)
	if s.titan_pair:
		s.titan_speed = titan_speed_mult(s.titan_relief)
	return s

## F7: velocidade do básico com a Empunhadura de Titã e `n` nós de alívio da teia (até Balance.TITAN_RELIEF_NODES).
static func titan_speed_mult(n: int) -> float:
	return 1.0 - (Balance.TITAN_ASPD_PEN - Balance.TITAN_WEB_RELIEF * clampi(n, 0, Balance.TITAN_RELIEF_NODES))

## F7: razão de DPS do básico com as duas armas de 2 mãos iguais (1,0875 com n = 0 .. 1,218 com n = 3).
static func titan_dps_ratio(n: int) -> float:
	return (1.0 + Balance.TITAN_OFFHAND_MULT) * titan_speed_mult(n)

## Dano a mais (%) do Paladino com espada pela VIT (escala de hoje, a da janela): +1% a cada Balance.VIT_SWORD_PER_PCT, teto VIT_SWORD_CAP.
## Ex.: VIT_SWORD_PER_PCT 20, VIT 500 -> +25%.
static func vit_sword_pct(vit: float, two_handed: bool = false) -> float:     # 2 mãos: VIT_SWORD_PER_PCT_2H (rende o dobro)
	return clampf(vit / (Balance.VIT_SWORD_PER_PCT_2H if two_handed else Balance.VIT_SWORD_PER_PCT), 0.0, Balance.VIT_SWORD_CAP)

## Esquiva passiva (% de evitar um golpe direto inteiro) pela AGI na escala antiga (atributo / ATTR_SCALE); curva em Balance.EVASION_AGI_*.
## Só personagens usam: monstro não passa por compute e a sim só testa esquiva em is_character().
static func agi_evasion(agi: float) -> float:
	return Balance.EVASION_AGI_REF_PCT * pow(maxf(0.0, agi) / Balance.EVASION_AGI_REF, Balance.EVASION_AGI_EXP)

## Recarga do ataque básico com a velocidade de ataque.
func basic_cooldown(base_cd: float) -> float:
	return base_cd / ((1.0 + attack_speed / 100.0) * titan_speed)

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

## Multiplicador do crítico: Balance.CRIT_MULT + crit_dmg_pct/100. Ex.: crit_dmg_pct 8 -> 1,58.
func crit_mult() -> float:
	return Balance.CRIT_MULT + crit_dmg_pct / 100.0

## Multiplicador do dano no tempo que esta entidade aplica (fixado na aplicação). Ex.: dot_pct 10 -> 1,1.
func dot_mult() -> float:
	return 1.0 + dot_pct / 100.0

## Multiplicador da duração de atordoar/prender/lentidão recebidos. Ex.: cc_resist_pct 20 -> 0,8.
func cc_mult() -> float:
	return 1.0 - cc_resist_pct / 100.0

## Custo de mana de uma skill com o desconto (arredonda para cima, mínimo 1; custo 0 continua 0). Ex.: 30 com 6% -> 29.
func mp_cost_of(base: float) -> float:
	if base <= 0.0 or mp_cost_pct <= 0.0:
		return base
	return maxf(1.0, ceilf(base * (1.0 - mp_cost_pct / 100.0) - 0.0001))

## Duração de uma invocação com tempo (0 = permanente, não muda). Ex.: 10 s com 20% -> 12 s.
func summon_time_of(duration: float) -> float:
	return duration * (1.0 + summon_time_pct / 100.0) if duration > 0.0 else duration


static func from_monster(m: MonsterDef) -> Stats:
	var s := Stats.new()
	s.max_hp = m.hp; s.max_mp = 100.0
	s.patk = m.atk; s.matk = m.matk if m.matk > 0 else m.atk
	s.pdef = m.def; s.mdef = m.mdef
	s.move_speed = m.move_speed
	s.crit_phys = 3.0; s.crit_mag = 3.0
	return s

## Corte de dano da Armadura de Gelo (%) para `int_attr` pontos de INT: BASE + INT/PER_INT, até CAP.
static func frost_armor_dr(int_attr: float) -> float:
	return minf(Balance.FROST_ARMOR_DR_CAP, Balance.FROST_ARMOR_DR_BASE + int_attr / Balance.FROST_ARMOR_DR_PER_INT)
