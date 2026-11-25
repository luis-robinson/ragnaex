class_name MonstersCatalog
extends RefCounted
## Monstros por área: Campina (1-10), Catacumbas (8-13), Floresta (10-20), Ruínas (20-30) + mini-bosses + invocação.

static func _mk(d: Dictionary) -> MonsterDef:
	var m := MonsterDef.new()
	CatalogUtil.fill(m, d)
	return m

static func _lt(id: String, entries: Array) -> LootTable:
	var l := LootTable.new()
	l.id = id
	l.entries = entries
	return l

static func build() -> Array:
	var L := [
		# ---- Campina (lv 1-10) ----
		{"id": "slime", "name": "Slime", "level": 1, "hp": 38, "atk": 7, "def": 1, "mdef": 1, "move_speed": 2.8, "attack_range": 1.4, "attack_cooldown": 1.6, "xp": 10,
		 "radius": 0.45, "scale": 0.8, "color": Color(0.45, 0.9, 0.5), "shape": "sphere", "loot_table": "lt_slime", "gold_min": 1, "gold_max": 4, "model": "mob_slime"},
		{"id": "slime_blue", "name": "Slime Azul", "level": 3, "hp": 60, "atk": 10, "matk": 12, "def": 2, "mdef": 4, "move_speed": 3.0, "attack_range": 5.0, "attack_cooldown": 1.9, "xp": 16, "ranged": true,
		 "radius": 0.45, "scale": 0.85, "color": Color(0.4, 0.6, 1.0), "shape": "sphere", "loot_table": "lt_slime_blue", "gold_min": 2, "gold_max": 6, "model": "mob_slime"},
		# boneco de treino (Aldara, Balance.DUMMY_SPOTS): alvo para testar skills; DEF/MDEF 0 = o número que aparece é o dano cru
		{"id": "training_dummy", "name": "Boneco de Treino", "level": 1, "hp": 99999, "atk": 0, "def": 0, "mdef": 0, "move_speed": 0.0, "attack_range": 0.0, "attack_cooldown": 60.0,
		 "xp": 0, "aggro_range": 0.0, "leash_range": 1000.0, "radius": 0.5, "scale": 1.0, "color": Color(0.78, 0.66, 0.42), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0,
		 "model": "mob_training_dummy", "dummy": true},
		{"id": "boar", "name": "Javali", "level": 5, "hp": 95, "atk": 15, "def": 4, "mdef": 2, "move_speed": 4.2, "attack_range": 1.6, "attack_cooldown": 1.3, "attack_startup": 0.3, "xp": 24, "aggro_range": 6.0,
		 "radius": 0.55, "scale": 1.0, "color": Color(0.5, 0.35, 0.25), "shape": "box", "loot_table": "lt_boar", "gold_min": 3, "gold_max": 8, "model": "mob_boar"},
		{"id": "wolf", "name": "Lobo", "level": 7, "hp": 110, "atk": 19, "def": 5, "mdef": 3, "move_speed": 5.0, "attack_range": 1.7, "attack_cooldown": 1.1, "attack_startup": 0.25, "xp": 32, "aggro_range": 9.0,
		 "radius": 0.5, "scale": 1.0, "color": Color(0.5, 0.5, 0.55), "shape": "box", "loot_table": "lt_wolf", "gold_min": 4, "gold_max": 10, "model": "mob_wolf"},
		# Praia dos Caranguejos (margem sul do lago do Vale): casco duro, belisca; o Rei sai da água
		{"id": "crab", "name": "Caranguejo", "level": 4, "hp": 80, "atk": 12, "def": 7, "mdef": 2, "move_speed": 3.6, "attack_range": 1.6, "attack_cooldown": 1.3, "attack_startup": 0.3, "xp": 21, "aggro_range": 6.0,
		 "radius": 0.55, "scale": 0.95, "color": Color(0.86, 0.4, 0.28), "shape": "box", "loot_table": "lt_crab", "gold_min": 2, "gold_max": 6, "model": "mob_crab"},
		# Praia dos Caranguejos (2026-11-21): dois tipos a mais, mesmo saque do comum (lt_crab), para a praia de farm
		{"id": "crab_hermit", "name": "Caranguejo-Eremita", "level": 5, "hp": 180, "atk": 11, "def": 16, "mdef": 4, "move_speed": 3.0, "attack_range": 1.6, "attack_cooldown": 1.4, "attack_startup": 0.35, "xp": 26, "aggro_range": 6.0,
		 "radius": 0.6, "scale": 1.0, "color": Color(0.72, 0.5, 0.36), "shape": "box", "loot_table": "lt_crab", "gold_min": 2, "gold_max": 6, "model": "mob_crab_hermit",
		 "skill_ids": ["mob_shell_hide"] as Array[String]},
		{"id": "crab_sand", "name": "Caranguejo da Areia", "level": 4, "hp": 70, "atk": 14, "def": 5, "mdef": 2, "move_speed": 4.2, "attack_range": 1.5, "attack_cooldown": 1.2, "attack_startup": 0.28, "xp": 22, "aggro_range": 7.0,
		 "radius": 0.5, "scale": 0.9, "color": Color(0.9, 0.78, 0.52), "shape": "box", "loot_table": "lt_crab", "gold_min": 2, "gold_max": 6, "model": "mob_crab_sand",
		 "skill_ids": ["mob_sand_leap"] as Array[String]},
		{"id": "crab_king", "name": "Caranguejo-Rei da Praia", "level": 8, "hp": 2200, "atk": 26, "def": 12, "mdef": 4, "move_speed": 3.4, "attack_range": 2.4, "attack_cooldown": 1.6, "attack_startup": 0.5, "xp": 190, "aggro_range": 9.0, "leash_range": 24.0,
		 "radius": 1.05, "scale": 2.0, "color": Color(0.72, 0.2, 0.22), "shape": "box", "is_boss": true, "loot_table": "lt_crab_king", "gold_min": 30, "gold_max": 60, "skill_ids": ["mob_whirl", "mob_crab_bubbles"] as Array[String], "model": "mob_crab",
		 "phases": [{"hp": 0.6, "say": "O Caranguejo-Rei estala as pinças: os filhotes saem do lago!", "summon": {"id": "crab_small", "count": 3, "max": 4}},
			{"hp": 0.3, "say": "KRRK-KRRK-KRRK!", "enrage": 1.3}]},
		# mini-chefe do bosque do Vale: nível 5 = sorteia o 1º conjunto lendário (25% como todo chefe)
		{"id": "boar_brute", "name": "Javali Presa-Rachada", "level": 5, "hp": 850, "atk": 20, "def": 6, "mdef": 3, "move_speed": 4.4, "attack_range": 2.0, "attack_cooldown": 1.4, "attack_startup": 0.4, "xp": 110, "aggro_range": 7.0, "leash_range": 22.0,
		 "radius": 0.75, "scale": 1.45, "color": Color(0.42, 0.24, 0.16), "shape": "box", "is_boss": true, "loot_table": "lt_boar_brute", "gold_min": 15, "gold_max": 35, "skill_ids": ["mob_charge", "mob_tusk_rush"] as Array[String], "model": "mob_boar",
		 "phases": [{"hp": 0.5, "say": "O Presa-Rachada chama a vara!", "summon": {"id": "boar_piglet", "count": 2, "max": 3}},
			{"hp": 0.25, "say": "GRRRUUNF!", "enrage": 1.25}]},
		{"id": "boar_king", "name": "Rei Javali", "level": 10, "hp": 2200, "atk": 26, "def": 8, "mdef": 5, "move_speed": 4.0, "attack_range": 2.2, "attack_cooldown": 1.5, "attack_startup": 0.45, "xp": 180, "aggro_range": 8.0, "leash_range": 25.0,
		 "radius": 0.9, "scale": 1.8, "color": Color(0.6, 0.3, 0.2), "shape": "box", "is_boss": true, "loot_table": "lt_boar_king", "gold_min": 30, "gold_max": 60, "skill_ids": ["mob_charge", "mob_tusk_rush"] as Array[String], "model": "mob_boar",
		 "phases": [{"hp": 0.5, "say": "O Rei Javali chama a vara!", "summon": {"id": "boar_piglet", "count": 3, "max": 4}},
			{"hp": 0.25, "say": "GRRROOOONF!", "enrage": 1.3}]},
		# Mata dos Zumbidos (4-8, ramo lateral ao sul de Aldara): vespas em bando, ursos lentos, a Colmeia que solta vespas e a Ursa-Mãe
		{"id": "wasp", "name": "Vespa", "level": 4, "hp": 58, "atk": 11, "def": 2, "mdef": 2, "move_speed": 5.2, "attack_range": 1.4, "attack_cooldown": 1.0, "attack_startup": 0.2, "xp": 18, "aggro_range": 8.0,
		 "radius": 0.4, "scale": 1.0, "color": Color(0.95, 0.8, 0.25), "shape": "sphere", "loot_table": "lt_wasp", "gold_min": 2, "gold_max": 5, "model": "mob_wasp"},
		{"id": "wasp_soldier", "name": "Vespa-Soldado", "level": 6, "hp": 96, "atk": 15, "def": 3, "mdef": 3, "move_speed": 5.0, "attack_range": 1.5, "attack_cooldown": 1.1, "attack_startup": 0.25, "xp": 28, "aggro_range": 9.0,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.85, 0.55, 0.15), "shape": "sphere", "loot_table": "lt_wasp_soldier", "gold_min": 3, "gold_max": 8, "model": "mob_wasp_soldier",
		 "skill_ids": ["mob_wasp_sting"] as Array[String]},
		{"id": "bear_cub", "name": "Filhote de Urso", "level": 5, "hp": 110, "atk": 13, "def": 5, "mdef": 2, "move_speed": 3.4, "attack_range": 1.5, "attack_cooldown": 1.4, "attack_startup": 0.35, "xp": 24, "aggro_range": 5.0,
		 "radius": 0.5, "scale": 0.7, "color": Color(0.55, 0.38, 0.24), "shape": "box", "loot_table": "lt_bear_cub", "gold_min": 3, "gold_max": 7, "model": "mob_bear_cub"},
		{"id": "bear", "name": "Urso Pardo", "level": 7, "hp": 190, "atk": 21, "def": 7, "mdef": 3, "move_speed": 3.8, "attack_range": 1.9, "attack_cooldown": 1.6, "attack_startup": 0.45, "xp": 38, "aggro_range": 7.0,
		 "radius": 0.75, "scale": 1.1, "color": Color(0.45, 0.3, 0.2), "shape": "box", "loot_table": "lt_bear", "gold_min": 4, "gold_max": 10, "model": "mob_bear",
		 "skill_ids": ["mob_bear_swipe"] as Array[String]},
		# Colmeia: parada e sem golpe; quem chega perto leva vespas (lacaios 0 XP no ritmo da recarga, no máximo 6 vivas).
		# 2026-11-25 (pedido do usuário: "mais resistente e solta vespas mais rápido"): vida 900 -> 1800, DEF 6 -> 9.
		{"id": "hive", "name": "Colmeia Gigante", "level": 7, "hp": 1800, "atk": 1, "def": 9, "mdef": 4, "move_speed": 0.0, "attack_range": 0.0, "attack_cooldown": 60.0, "xp": 60, "aggro_range": 12.0, "leash_range": 40.0,
		 "radius": 1.0, "scale": 1.0, "color": Color(0.8, 0.6, 0.25), "shape": "box", "loot_table": "lt_hive", "gold_min": 6, "gold_max": 14, "model": "mob_hive",
		 "skill_ids": ["mob_hive_swarm"] as Array[String]},
		{"id": "bear_mother", "name": "Ursa-Mãe", "level": 8, "hp": 2300, "atk": 27, "def": 10, "mdef": 4, "move_speed": 3.8, "attack_range": 2.4, "attack_cooldown": 1.6, "attack_startup": 0.5, "xp": 190, "aggro_range": 9.0, "leash_range": 24.0,
		 "radius": 1.1, "scale": 1.65, "color": Color(0.32, 0.22, 0.15), "shape": "box", "is_boss": true, "loot_table": "lt_bear_mother", "gold_min": 30, "gold_max": 60, "skill_ids": ["mob_charge", "mob_bear_roar", "mob_tusk_rush"] as Array[String], "model": "mob_bear_mother",
		 "intro": "GRRROOOAAARR! Ninguém chega perto da toca!", "last_words": "A Ursa-Mãe tomba... a mata fica em silêncio.",
		 "phases": [{"hp": 0.5, "say": "A Ursa-Mãe ruge: os filhotes saem da toca!", "summon": {"id": "bear_cub_den", "count": 2, "max": 3}},
			{"hp": 0.25, "say": "GRRRAAAUUURR!", "enrage": 1.3}]},
		# lacaios (0 XP): vespas da Colmeia e filhotes da Ursa-Mãe
		{"id": "hive_wasp", "name": "Vespa da Colmeia", "level": 4, "hp": 40, "atk": 9, "def": 1, "mdef": 1, "move_speed": 5.4, "attack_range": 1.3, "attack_cooldown": 1.0, "attack_startup": 0.2, "xp": 0, "aggro_range": 14.0, "leash_range": 30.0,
		 "radius": 0.35, "scale": 0.85, "color": Color(0.95, 0.8, 0.25), "shape": "sphere", "model": "mob_wasp"},
		{"id": "bear_cub_den", "name": "Filhote da Toca", "level": 5, "hp": 70, "atk": 11, "def": 4, "mdef": 1, "move_speed": 4.0, "attack_range": 1.4, "attack_cooldown": 1.3, "attack_startup": 0.3, "xp": 0, "aggro_range": 14.0, "leash_range": 30.0,
		 "radius": 0.45, "scale": 0.6, "color": Color(0.5, 0.35, 0.22), "shape": "box", "model": "mob_bear_cub"},
		# ---- Bosque dos Xamãs (14-18, ramo lateral a leste da Floresta): xamãs que viram bicho (ShiftSystem), chamadores, lobos/ursos do bosque e o Arquidruida ----
		{"id": "shaman_shifter", "name": "Xamã Metamorfo", "level": 15, "hp": 420, "atk": 22, "matk": 34, "def": 9, "mdef": 10, "move_speed": 4.6, "attack_range": 7.0, "attack_cooldown": 1.7, "attack_startup": 0.45, "xp": 88, "aggro_range": 9.0, "leash_range": 22.0, "ranged": true,
		 "radius": 0.5, "scale": 1.0, "color": Color(0.55, 0.45, 0.3), "shape": "capsule", "loot_table": "lt_shaman_shifter", "gold_min": 8, "gold_max": 18, "model": "mob_shaman_shifter",
		 "shift_forms": [{"form": "shaman_bear", "weight": 40}, {"form": "shaman_wolf", "weight": 35}, {"form": "shaman_hawk", "weight": 25}]},
		# formas do Metamorfo (MonsterDef completo; xp 0 e sem saque: abate conta pela base). aggro/leash iguais aos da base.
		{"id": "shaman_bear", "name": "Urso", "level": 15, "hp": 600, "atk": 46, "def": 14, "mdef": 8, "move_speed": 4.0, "attack_range": 2.0, "attack_cooldown": 1.45, "attack_startup": 0.45, "xp": 0, "aggro_range": 9.0, "leash_range": 22.0,
		 "radius": 0.75, "scale": 1.15, "color": Color(0.42, 0.3, 0.2), "shape": "box", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_shaman_bear",
		 "skill_ids": ["mob_bear_swipe"] as Array[String]},
		{"id": "shaman_wolf", "name": "Lobo", "level": 15, "hp": 380, "atk": 40, "def": 8, "mdef": 6, "move_speed": 5.8, "attack_range": 1.7, "attack_cooldown": 0.95, "attack_startup": 0.25, "xp": 0, "aggro_range": 9.0, "leash_range": 22.0,
		 "radius": 0.5, "scale": 1.05, "color": Color(0.5, 0.5, 0.55), "shape": "box", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_shaman_wolf", "shift_stealth": true,
		 "skill_ids": ["mob_pounce"] as Array[String]},
		{"id": "shaman_hawk", "name": "Gavião", "level": 15, "hp": 300, "atk": 16, "matk": 40, "def": 6, "mdef": 10, "move_speed": 5.4, "attack_range": 9.0, "attack_cooldown": 1.6, "attack_startup": 0.4, "xp": 0, "aggro_range": 9.0, "leash_range": 22.0, "ranged": true,
		 "radius": 0.5, "scale": 1.0, "color": Color(0.7, 0.55, 0.35), "shape": "sphere", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_shaman_hawk", "kite": true},
		# Chamador: invoca bichos fracos (0 XP; as três skills dividem o teto: no máximo 3 vivos por chamador) e atira um raio fraco
		{"id": "shaman_caller", "name": "Xamã Chamador", "level": 16, "hp": 360, "atk": 14, "matk": 30, "def": 7, "mdef": 12, "move_speed": 4.4, "attack_range": 8.0, "attack_cooldown": 1.8, "attack_startup": 0.45, "xp": 96, "aggro_range": 10.0, "leash_range": 22.0, "ranged": true,
		 "radius": 0.5, "scale": 1.0, "color": Color(0.45, 0.5, 0.35), "shape": "capsule", "loot_table": "lt_shaman_caller", "gold_min": 9, "gold_max": 20, "model": "mob_shaman_caller",
		 "skill_ids": ["mob_call_boar", "mob_call_rabbits", "mob_call_deer"] as Array[String]},
		{"id": "grove_wolf", "name": "Lobo do Bosque", "level": 15, "hp": 330, "atk": 40, "def": 8, "mdef": 5, "move_speed": 5.4, "attack_range": 1.7, "attack_cooldown": 1.0, "attack_startup": 0.25, "xp": 74, "aggro_range": 9.0, "leash_range": 22.0,
		 "radius": 0.5, "scale": 1.1, "color": Color(0.42, 0.42, 0.46), "shape": "box", "loot_table": "lt_grove_wolf", "gold_min": 7, "gold_max": 15, "model": "mob_wolf",
		 "skill_ids": ["mob_pounce"] as Array[String]},
		{"id": "grove_bear", "name": "Urso do Bosque", "level": 16, "hp": 620, "atk": 50, "def": 13, "mdef": 6, "move_speed": 4.0, "attack_range": 2.0, "attack_cooldown": 1.5, "attack_startup": 0.45, "xp": 100, "aggro_range": 8.0, "leash_range": 22.0,
		 "radius": 0.8, "scale": 1.25, "color": Color(0.38, 0.26, 0.17), "shape": "box", "loot_table": "lt_grove_bear", "gold_min": 9, "gold_max": 20, "model": "mob_bear",
		 "skill_ids": ["mob_bear_swipe"] as Array[String]},
		# Arquidruida (chefe de campo, 18): muita vida, invoca; Enlaçar = raiz num alvo aleatório com aviso roxo (controle) no chão
		{"id": "boss_archdruid", "name": "Arquidruida Ulmo", "level": 18, "hp": 58000, "atk": 76, "matk": 84, "def": 14, "mdef": 18, "move_speed": 3.8, "attack_range": 8.0, "attack_cooldown": 1.7, "attack_startup": 0.45, "xp": 1000, "aggro_range": 12.0, "leash_range": 30.0, "ranged": true,
		 "radius": 1.0, "scale": 1.4, "color": Color(0.4, 0.55, 0.3), "shape": "capsule", "is_boss": true, "berserk_after": 150, "loot_table": "lt_archdruid", "gold_min": 110, "gold_max": 220, "model": "mob_archdruid",
		 "skill_ids": ["mob_entangle", "mob_root_grasp", "mob_call_pack"] as Array[String],
		 "intro": "O bosque tem dentes, forasteiro. Eu sou a boca.", "last_words": "As raízes... lembram... de mim...",
		 "phases": [{"hp": 0.75, "say": "Irmãos lobos, a mim!", "summon": {"id": "archdruid_wolf", "count": 3, "max": 4}},
			{"hp": 0.5, "say": "Ursos da encosta, acordem!", "summon": {"id": "archdruid_bear", "count": 2, "max": 5}},
			{"hp": 0.25, "say": "Velhas árvores, andem!", "skills": ["mob_king_roots"], "ward": 0.4, "summon": {"id": "archdruid_treant", "count": 2, "max": 6}},
			{"hp": 0.1, "say": "Se eu cair, caio como a floresta: levando tudo junto!", "enrage": 1.3}]},
		# lacaios (0 XP): bichos dos Chamadores e do Arquidruida
		{"id": "grove_boar", "name": "Javali Chamado", "level": 15, "hp": 150, "atk": 14, "def": 5, "mdef": 2, "move_speed": 4.6, "attack_range": 1.5, "attack_cooldown": 1.3, "attack_startup": 0.3, "xp": 0, "aggro_range": 14.0, "leash_range": 30.0,
		 "radius": 0.5, "scale": 0.9, "color": Color(0.5, 0.36, 0.25), "shape": "box", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_boar"},
		{"id": "grove_rabbit", "name": "Coelho Chamado", "level": 15, "hp": 70, "atk": 8, "def": 2, "mdef": 2, "move_speed": 5.8, "attack_range": 1.2, "attack_cooldown": 1.0, "attack_startup": 0.2, "xp": 0, "aggro_range": 14.0, "leash_range": 30.0,
		 "radius": 0.3, "scale": 0.5, "color": Color(0.75, 0.68, 0.58), "shape": "box", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_rabbit"},
		{"id": "grove_deer", "name": "Cervo Chamado", "level": 15, "hp": 170, "atk": 12, "def": 4, "mdef": 3, "move_speed": 5.4, "attack_range": 1.6, "attack_cooldown": 1.3, "attack_startup": 0.3, "xp": 0, "aggro_range": 14.0, "leash_range": 30.0,
		 "radius": 0.55, "scale": 0.9, "color": Color(0.62, 0.45, 0.3), "shape": "box", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_deer"},
		{"id": "archdruid_wolf", "name": "Lobo do Arquidruida", "level": 18, "hp": 340, "atk": 38, "def": 7, "mdef": 5, "move_speed": 5.8, "attack_range": 1.6, "attack_cooldown": 1.0, "attack_startup": 0.25, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0,
		 "radius": 0.5, "scale": 1.05, "color": Color(0.4, 0.42, 0.45), "shape": "box", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_wolf"},
		{"id": "archdruid_bear", "name": "Urso do Arquidruida", "level": 18, "hp": 600, "atk": 46, "def": 12, "mdef": 6, "move_speed": 4.2, "attack_range": 2.0, "attack_cooldown": 1.5, "attack_startup": 0.45, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0,
		 "radius": 0.75, "scale": 1.15, "color": Color(0.36, 0.25, 0.16), "shape": "box", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_bear"},
		{"id": "archdruid_treant", "name": "Árvore Desperta", "level": 18, "hp": 800, "atk": 42, "def": 15, "mdef": 8, "move_speed": 3.4, "attack_range": 2.0, "attack_cooldown": 1.6, "attack_startup": 0.5, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0,
		 "radius": 0.7, "scale": 1.0, "color": Color(0.4, 0.5, 0.3), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_trent"},
		# ---- Floresta (lv 10-20) ----
		{"id": "spider", "name": "Aranha Gigante", "level": 13, "hp": 360, "atk": 42, "def": 7, "mdef": 6, "move_speed": 4.6, "attack_range": 1.7, "attack_cooldown": 1.2, "xp": 78, "aggro_range": 8.0,
		 "radius": 0.55, "scale": 1.0, "color": Color(0.25, 0.2, 0.3), "shape": "box", "loot_table": "lt_spider", "gold_min": 6, "gold_max": 14, "model": "mob_spider"},
		# ---- Terceiro andar (20-30): mortos-vivos das três fortalezas e a Cidadela do Lich ----
		{"id": "larva", "name": "Larva Pútrida", "level": 20, "hp": 190, "atk": 38, "def": 4, "mdef": 4, "move_speed": 4.4, "attack_range": 1.4, "attack_cooldown": 0.9, "attack_startup": 0.2, "xp": 32, "aggro_range": 8.0,
		 "radius": 0.35, "scale": 0.9, "color": Color(0.86, 0.84, 0.66), "shape": "capsule", "loot_table": "lt_larva", "gold_min": 3, "gold_max": 8, "model": "mob_larva"},
		{"id": "rot_zombie", "name": "Cadáver Ambulante", "level": 21, "hp": 820, "atk": 74, "def": 12, "mdef": 6, "move_speed": 3.6, "attack_range": 1.7, "attack_cooldown": 1.4, "attack_startup": 0.4, "xp": 75, "aggro_range": 7.0,
		 "radius": 0.45, "scale": 1.05, "color": Color(0.4, 0.5, 0.35), "shape": "capsule", "loot_table": "lt_rot", "gold_min": 8, "gold_max": 18, "model": "mob_zombie"},
		{"id": "rot_ghoul", "name": "Carniçal Pútrido", "level": 22, "hp": 560, "atk": 44, "def": 10, "mdef": 8, "move_speed": 5.0, "attack_range": 1.7, "attack_cooldown": 1.0, "attack_startup": 0.25, "xp": 105, "aggro_range": 9.0,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.5, 0.58, 0.4), "shape": "capsule", "loot_table": "lt_rot", "gold_min": 10, "gold_max": 22, "model": "mob_ghoul",
		 "skill_ids": ["mob_venom_claw"] as Array[String]},
		{"id": "rot_wolf", "name": "Lobo Pútrido", "level": 21, "hp": 480, "atk": 46, "def": 8, "mdef": 6, "move_speed": 6.0, "attack_range": 1.6, "attack_cooldown": 1.0, "attack_startup": 0.25, "xp": 95, "aggro_range": 10.0,
		 "radius": 0.5, "scale": 1.0, "color": Color(0.38, 0.4, 0.32), "shape": "box", "loot_table": "lt_rot", "gold_min": 8, "gold_max": 18, "model": "mob_rot_wolf",
		 "skill_ids": ["mob_pounce"] as Array[String]},
		{"id": "rot_bear", "name": "Urso Putrefato", "level": 23, "hp": 1050, "atk": 104, "def": 20, "mdef": 10, "move_speed": 4.2, "attack_range": 2.2, "attack_cooldown": 1.4, "attack_startup": 0.4, "xp": 175, "aggro_range": 8.0,
		 "radius": 0.8, "scale": 1.3, "color": Color(0.36, 0.38, 0.28), "shape": "box", "loot_table": "lt_rot", "gold_min": 14, "gold_max": 30, "model": "mob_rot_bear",
		 "skill_ids": ["mob_rot_maul"] as Array[String]},
		{"id": "ghoul_giant", "name": "Carniçal Gigante", "level": 23, "hp": 52000, "atk": 116, "matk": 64, "def": 24, "mdef": 20, "move_speed": 4.4, "attack_range": 3.3, "attack_cooldown": 1.2, "attack_startup": 0.45, "xp": 1400, "aggro_range": 11.0, "leash_range": 30.0,
		 "radius": 1.0, "scale": 2.0, "color": Color(0.52, 0.6, 0.42), "shape": "capsule", "is_boss": true, "berserk_after": 120, "loot_table": "lt_ghoul_giant", "gold_min": 120, "gold_max": 220, "model": "mob_ghoul_giant",
		 "skill_ids": ["mob_rot_maul", "mob_rot_bile", "mob_raise_brood", "mob_rot_hook"] as Array[String], "coin_chance": 1.0, "coin_min": 2, "coin_max": 4,
		 "intro": "Mais carne. A ninhada agradece.", "last_words": "A ninhada... vai... lembrar...",
		 "phases": [{"hp": 0.7, "say": "Filhos! Comam!", "summon": {"id": "larva_brood", "count": 3, "max": 5, "pick": "far"}},
			{"hp": 0.4, "say": "A ninhada me cobre!", "skills": ["mob_venom_barrage"], "ward": 0.5, "summon": {"id": "larva_brood", "count": 3, "max": 5}},
			{"hp": 0.15, "say": "Tudo apodrece no fim!", "skills": ["mob_venom_pool"], "enrage": 1.3}]},
		{"id": "larva_brood", "name": "Ninhada", "level": 20, "hp": 120, "atk": 20, "def": 3, "mdef": 3, "move_speed": 4.6, "attack_range": 1.4, "attack_cooldown": 0.9, "attack_startup": 0.2, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0,
		 "radius": 0.35, "scale": 0.8, "color": Color(0.86, 0.84, 0.66), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_larva"},
		{"id": "skel_archer", "name": "Arqueiro de Ossos", "level": 24, "hp": 360, "atk": 58, "def": 12, "mdef": 10, "move_speed": 4.2, "attack_range": 9.0, "attack_cooldown": 1.6, "attack_startup": 0.4, "xp": 130, "aggro_range": 10.0, "ranged": true,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.85, 0.82, 0.72), "shape": "capsule", "loot_table": "lt_bones", "gold_min": 14, "gold_max": 30, "model": "mob_skel_archer",
		 "skill_ids": ["mob_volley"] as Array[String]},
		{"id": "skel_guard", "name": "Guardião de Ossos", "level": 25, "hp": 880, "atk": 80, "def": 32, "mdef": 12, "move_speed": 3.8, "attack_range": 1.9, "attack_cooldown": 1.3, "attack_startup": 0.35, "xp": 170, "aggro_range": 8.0, "front_guard": 0.6,
		 "radius": 0.5, "scale": 1.05, "color": Color(0.3, 0.28, 0.3), "shape": "capsule", "loot_table": "lt_bones", "gold_min": 16, "gold_max": 34, "model": "mob_skel_guard"},
		{"id": "death_knight", "name": "Vorhag, o Cavaleiro da Morte", "level": 26, "hp": 70000, "atk": 101, "matk": 70, "def": 32, "mdef": 24, "move_speed": 4.6, "attack_range": 2.6, "attack_cooldown": 1.2, "attack_startup": 0.35, "xp": 1700, "aggro_range": 11.0, "leash_range": 30.0,
		 "radius": 0.7, "scale": 1.5, "color": Color(0.2, 0.18, 0.22), "shape": "capsule", "is_boss": true, "berserk_after": 180, "loot_table": "lt_death_knight", "gold_min": 140, "gold_max": 260, "model": "mob_death_knight",
		 "skill_ids": ["mob_raise_fallen", "mob_bone_cleave", "mob_charge", "mob_soul_drain", "mob_bone_hook"] as Array[String], "coin_chance": 1.0, "coin_min": 3, "coin_max": 4,
		 "intro": "Eu jurei proteger esta terra. Ainda protejo. Dela.", "last_words": "O juramento... enfim... cumprido...",
		 "phases": [{"hp": 0.7, "say": "Levantem-se, irmãos!", "summon": {"id": "bone_raised", "count": 3, "max": 5}},
			{"hp": 0.4, "say": "Meu juramento me guarda!", "skills": ["mob_soul_barrage"], "ward": 0.5, "summon": {"id": "bone_raised", "count": 2, "max": 5}},
			{"hp": 0.15, "say": "Não há aurora para os mortos!", "skills": ["mob_death_wave"], "enrage": 1.3}]},
		{"id": "bone_raised", "name": "Soldado Erguido", "level": 25, "hp": 300, "atk": 40, "def": 14, "mdef": 8, "move_speed": 4.2, "attack_range": 1.8, "attack_cooldown": 1.3, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.85, 0.82, 0.72), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_skel_blade"},
		{"id": "cultist", "name": "Adepto Sombrio", "level": 26, "hp": 380, "atk": 18, "matk": 72, "def": 8, "mdef": 22, "move_speed": 4.4, "attack_range": 8.0, "attack_cooldown": 1.6, "attack_startup": 0.45, "xp": 150, "aggro_range": 10.0, "ranged": true,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.42, 0.08, 0.1), "shape": "capsule", "loot_table": "lt_cult", "gold_min": 16, "gold_max": 34, "model": "mob_cultist",
		 "skill_ids": ["mob_shadow_bolt"] as Array[String]},
		{"id": "tower_bat", "name": "Morcego da Torre", "level": 26, "hp": 260, "atk": 66, "def": 6, "mdef": 10, "move_speed": 6.5, "attack_range": 1.6, "attack_cooldown": 0.9, "attack_startup": 0.2, "xp": 85, "aggro_range": 11.0,
		 "radius": 0.4, "scale": 1.0, "color": Color(0.3, 0.2, 0.35), "shape": "sphere", "loot_table": "lt_cult", "gold_min": 6, "gold_max": 14, "model": "mob_bat"},
		{"id": "frost_mage", "name": "Morvath, o Arquimago Gélido", "level": 29, "hp": 70000, "atk": 50, "matk": 94, "def": 22, "mdef": 34, "move_speed": 4.4, "attack_range": 9.0, "attack_cooldown": 1.5, "attack_startup": 0.45, "xp": 1900, "aggro_range": 12.0, "leash_range": 30.0, "ranged": true,
		 "radius": 0.6, "scale": 1.45, "color": Color(0.5, 0.7, 0.9), "shape": "capsule", "is_boss": true, "berserk_after": 180, "loot_table": "lt_frost_mage", "gold_min": 160, "gold_max": 280, "model": "mob_frost_mage",
		 "skill_ids": ["mob_raise_wraiths", "mob_frost_shard", "mob_frost_ring", "mob_crystal_prison", "mob_hail_barrage"] as Array[String], "coin_chance": 1.0, "coin_min": 3, "coin_max": 4,
		 "intro": "O frio conserva. Eu vou conservar você para sempre.", "last_words": "Derretendo... que vergonha...",
		 "phases": [{"hp": 0.7, "say": "Espectros, ao meu lado!", "summon": {"id": "frost_wraith", "count": 3, "max": 4}},
			{"hp": 0.4, "say": "O gelo me guarda!", "skills": ["mob_blizzard"], "ward": 0.5, "summon": {"id": "frost_wraith", "count": 2, "max": 4, "pick": "far"}},
			{"hp": 0.15, "say": "Que a nevasca enterre todos!", "enrage": 1.3}]},
		{"id": "frost_wraith", "name": "Espectro Gélido", "level": 27, "hp": 260, "atk": 20, "matk": 50, "def": 6, "mdef": 18, "move_speed": 4.6, "attack_range": 7.0, "attack_cooldown": 1.7, "attack_startup": 0.45, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0, "ranged": true,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.6, 0.9, 1.0), "shape": "cone", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_ghost"},
		{"id": "citadel_knight", "name": "Guarda da Cidadela", "level": 29, "hp": 1150, "atk": 84, "def": 36, "mdef": 18, "move_speed": 4.2, "attack_range": 2.0, "attack_cooldown": 1.2, "attack_startup": 0.35, "xp": 260, "aggro_range": 9.0, "front_guard": 0.5,
		 "radius": 0.55, "scale": 1.15, "color": Color(0.22, 0.2, 0.26), "shape": "capsule", "loot_table": "lt_citadel", "gold_min": 24, "gold_max": 50, "model": "mob_skel_guard",
		 "skill_ids": ["mob_bone_cleave"] as Array[String]},
		{"id": "citadel_adept", "name": "Adepto da Cidadela", "level": 29, "hp": 620, "atk": 24, "matk": 72, "def": 12, "mdef": 28, "move_speed": 4.4, "attack_range": 8.5, "attack_cooldown": 1.5, "attack_startup": 0.45, "xp": 240, "aggro_range": 10.0, "ranged": true,
		 "radius": 0.45, "scale": 1.1, "color": Color(0.3, 0.1, 0.35), "shape": "capsule", "loot_table": "lt_citadel", "gold_min": 22, "gold_max": 46, "model": "mob_cultist",
		 "skill_ids": ["mob_shadow_bolt", "mob_blizzard"] as Array[String]},
		{"id": "citadel_horror", "name": "Horror da Cidadela", "level": 29, "hp": 1100, "atk": 74, "def": 22, "mdef": 14, "move_speed": 5.0, "attack_range": 1.9, "attack_cooldown": 1.1, "attack_startup": 0.3, "xp": 250, "aggro_range": 9.0,
		 "radius": 0.55, "scale": 1.3, "color": Color(0.45, 0.52, 0.36), "shape": "capsule", "loot_table": "lt_citadel", "gold_min": 22, "gold_max": 46, "model": "mob_ghoul",
		 "skill_ids": ["mob_venom_claw", "mob_rot_maul"] as Array[String]},
		{"id": "lich_king", "name": "Azhar, o Lich-Rei", "level": 30, "hp": 88000, "atk": 70, "matk": 90, "def": 30, "mdef": 40, "move_speed": 4.4, "attack_range": 9.0, "attack_cooldown": 1.4, "attack_startup": 0.45, "xp": 3200, "aggro_range": 13.0, "leash_range": 32.0, "ranged": true,
		 "radius": 0.7, "scale": 1.7, "color": Color(0.3, 0.18, 0.4), "shape": "capsule", "is_boss": true, "berserk_after": 180, "loot_table": "lt_lich_king", "gold_min": 300, "gold_max": 500, "model": "mob_lich_king",
		 "skill_ids": ["mob_raise_fallen", "mob_frost_shard", "mob_soul_drain", "mob_shadow_bolt", "mob_death_wave", "mob_bone_hook"] as Array[String], "coin_chance": 1.0, "coin_min": 5, "coin_max": 8,
		 "intro": "A aurora é só uma noite que ainda não terminou.", "last_words": "Isto... não é... o fim... da noite...",
		 "phases": [{"hp": 0.75, "say": "Ossos da Fortaleza, ergam-se!", "skills": ["mob_soul_barrage"], "summon": {"id": "bone_raised", "count": 3, "max": 5}},
			{"hp": 0.5, "say": "Ninhada, espectros: devorem a luz!", "ward": 0.5, "summon": {"id": "frost_wraith", "count": 2, "max": 4, "pick": "far"}, "skills": ["mob_raise_brood", "mob_blizzard"]},
			{"hp": 0.25, "say": "EU SOU A NOITE!", "skills": ["mob_hail_barrage"], "enrage": 1.35}]},
		# guarnição da Aurora (Bastião, assentamentos e assaltos): NPC com `fighter`, renasce rápido
		{"id": "guard_spearman", "name": "Lanceiro da Aurora", "level": 26, "hp": 2400, "atk": 54, "def": 30, "mdef": 18, "move_speed": 4.8, "attack_range": 2.4, "attack_cooldown": 1.1, "attack_startup": 0.3, "xp": 0,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.32, 0.42, 0.72), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_loyal_spearman",
		 "skill_ids": ["mob_spear_lunge"] as Array[String]},
		{"id": "guard_knight", "name": "Cavaleiro da Aurora", "level": 27, "hp": 3200, "atk": 62, "def": 38, "mdef": 20, "move_speed": 4.6, "attack_range": 2.2, "attack_cooldown": 1.3, "attack_startup": 0.35, "xp": 0,
		 "radius": 0.5, "scale": 1.05, "color": Color(0.78, 0.8, 0.86), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_loyal_knight",
		 "skill_ids": ["mob_charge"] as Array[String]},
		{"id": "guard_paladin", "name": "Paladino da Aurora", "level": 27, "hp": 3000, "atk": 52, "matk": 50, "def": 40, "mdef": 30, "move_speed": 4.6, "attack_range": 2.0, "attack_cooldown": 1.2, "attack_startup": 0.3, "xp": 0,
		 "radius": 0.5, "scale": 1.05, "color": Color(0.95, 0.93, 0.85), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_loyal_paladin",
		 "skill_ids": ["mob_holy_light"] as Array[String]},
		{"id": "guard_priest", "name": "Sacerdotisa da Aurora", "level": 26, "hp": 1800, "atk": 18, "matk": 56, "def": 16, "mdef": 30, "move_speed": 4.6, "attack_range": 8.0, "attack_cooldown": 1.6, "attack_startup": 0.45, "xp": 0, "ranged": true,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.96, 0.95, 0.9), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_loyal_priest",
		 "skill_ids": ["mob_holy_light", "mob_light_beam"] as Array[String]},
		{"id": "guard_wall_crossbow", "name": "Besteiro da Muralha", "level": 26, "hp": 5000, "atk": 14, "def": 30, "mdef": 30, "move_speed": 0.1, "attack_range": 18.0, "attack_cooldown": 1.7, "attack_startup": 0.35, "xp": 0, "ranged": true,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.55, 0.45, 0.32), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_loyal_crossbow"},
		{"id": "guard_crossbow", "name": "Besteiro da Aurora", "level": 26, "hp": 1900, "atk": 56, "def": 20, "mdef": 16, "move_speed": 4.6, "attack_range": 11.0, "attack_cooldown": 1.6, "attack_startup": 0.4, "xp": 0, "ranged": true,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.55, 0.45, 0.32), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_loyal_crossbow"},
		# ---- Linha dos fora-da-lei (Floresta, 12-21): trombadinha, gatuno, clandestino, bandido, fora-da-lei, capanga, chefe ----
		{"id": "bandit_footpad", "name": "Trombadinha", "level": 12, "hp": 350, "atk": 28, "def": 6, "mdef": 6, "move_speed": 5.8, "attack_range": 1.7, "attack_cooldown": 0.85, "attack_startup": 0.2, "xp": 62, "aggro_range": 9.0,
		 "radius": 0.42, "scale": 0.95, "color": Color(0.62, 0.52, 0.3), "shape": "capsule", "loot_table": "lt_bandit_light", "gold_min": 6, "gold_max": 16, "model": "mob_bandit_footpad",
		 "skill_ids": ["mob_sling_stone"] as Array[String]},
		{"id": "bandit_thief", "name": "Gatuno", "level": 13, "hp": 280, "atk": 31, "def": 5, "mdef": 6, "move_speed": 5.4, "attack_range": 1.6, "attack_cooldown": 0.9, "attack_startup": 0.2, "xp": 70, "aggro_range": 8.0,
		 "radius": 0.42, "scale": 0.95, "color": Color(0.3, 0.28, 0.35), "shape": "capsule", "loot_table": "lt_bandit_light", "gold_min": 8, "gold_max": 20, "model": "mob_bandit_thief",
		 "skill_ids": ["mob_ambush_stab"] as Array[String]},
		{"id": "bandit_archer", "name": "Clandestino", "level": 14, "hp": 300, "atk": 37, "def": 6, "mdef": 7, "move_speed": 4.8, "attack_range": 8.5, "attack_cooldown": 1.5, "attack_startup": 0.4, "xp": 80, "aggro_range": 10.0, "ranged": true,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.45, 0.36, 0.22), "shape": "capsule", "loot_table": "lt_bandit", "gold_min": 10, "gold_max": 22, "model": "mob_bandit_poacher",
		 "skill_ids": ["mob_snare_shot"] as Array[String]},
		{"id": "bandit", "name": "Bandido", "level": 15, "hp": 480, "atk": 50, "def": 11, "mdef": 7, "move_speed": 4.6, "attack_range": 2.0, "attack_cooldown": 1.15, "attack_startup": 0.3, "xp": 95, "aggro_range": 9.0,
		 "radius": 0.5, "scale": 1.08, "color": Color(0.6, 0.25, 0.25), "shape": "capsule", "loot_table": "lt_bandit", "gold_min": 10, "gold_max": 24, "model": "mob_bandit",
		 "skill_ids": ["mob_club_slam"] as Array[String]},
		{"id": "bandit_outlaw", "name": "Fora-da-Lei", "level": 17, "hp": 720, "atk": 52, "def": 12, "mdef": 9, "move_speed": 4.8, "attack_range": 2.0, "attack_cooldown": 1.1, "attack_startup": 0.3, "xp": 160, "aggro_range": 10.0, "leash_range": 24.0,
		 "radius": 0.5, "scale": 1.12, "color": Color(0.42, 0.3, 0.22), "shape": "capsule", "loot_table": "lt_bandit_outlaw", "gold_min": 20, "gold_max": 40, "model": "mob_bandit_outlaw",
		 "skill_ids": ["mob_sling_stone", "mob_club_slam"] as Array[String], "escort": {"id": "bandit_footpad", "count": 2}},
		{"id": "ent", "name": "Ent", "level": 19, "hp": 640, "atk": 62, "def": 16, "mdef": 8, "move_speed": 3.0, "attack_range": 2.4, "attack_cooldown": 1.8, "attack_startup": 0.5, "xp": 125, "aggro_range": 6.0,
		 "radius": 0.75, "scale": 1.5, "color": Color(0.35, 0.3, 0.2), "shape": "box", "loot_table": "lt_ent", "gold_min": 12, "gold_max": 28, "model": "mob_ent", "skill_ids": ["mob_thorn_lash"] as Array[String]},
		{"id": "bandit_chief", "name": "Chefe dos Bandidos", "level": 21, "hp": 52000, "atk": 72, "def": 18, "mdef": 14, "move_speed": 4.6, "attack_range": 2.2, "attack_cooldown": 1.1, "attack_startup": 0.3, "xp": 760, "aggro_range": 9.0, "leash_range": 25.0,
		 "radius": 0.6, "scale": 1.35, "color": Color(0.75, 0.15, 0.15), "shape": "capsule", "is_boss": true, "berserk_after": 120, "loot_table": "lt_bandit_chief", "gold_min": 80, "gold_max": 150, "skill_ids": ["mob_call_thugs", "mob_whirl", "mob_venom_knives", "mob_smoke_bomb", "mob_club_slam", "mob_sling_stone", "mob_fire_kegs", "mob_grapple_hook"] as Array[String], "model": "mob_bandit_chief",
		 "intro": "Mais um caçador de recompensa? Você vai sair daqui sem as botas.", "last_words": "Era... só ouro...",
		 "phases": [{"hp": 0.7, "say": "Rapazes! Acabem com esse curioso!", "summon": {"id": "bandit_thug", "count": 2, "max": 3}},
			{"hp": 0.4, "say": "Pólvora neles!", "ward": 0.5, "summon": {"id": "bandit_thug", "count": 2, "max": 4}},
			{"hp": 0.15, "say": "Ninguém tira o que é meu!", "skills": ["mob_charge"], "enrage": 1.25}]},
		{"id": "bandit_thug", "name": "Capanga", "level": 18, "hp": 330, "atk": 34, "def": 10, "mdef": 6, "move_speed": 4.6, "attack_range": 1.7, "attack_cooldown": 1.2, "attack_startup": 0.3, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.6, 0.25, 0.2), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_bandit_thug"},
		# ---- Cerco élfico (lv 14-21): investidas na Floresta e a Cidade Élfica ----
		# investida (RaidSystem): rápidos, marcham do portal élfico até o Posto dos Caçadores
		{"id": "elf_raider", "name": "Batedor Élfico", "level": 16, "hp": 255, "atk": 36, "def": 9, "mdef": 9, "move_speed": 5.6, "attack_range": 1.8, "attack_cooldown": 1.0, "attack_startup": 0.25, "xp": 74, "aggro_range": 10.0, "leash_range": 20.0,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.45, 0.7, 0.4), "shape": "capsule", "loot_table": "lt_elf_raid", "gold_min": 10, "gold_max": 22, "model": "mob_elf_fighter", "skill_ids": ["mob_elf_lunge"] as Array[String],
		 "swap": {"hp": 0.4, "as": "elf_raider_archer", "stance": "bow"}},
		{"id": "elf_raider_archer", "name": "Arqueiro Batedor", "level": 16, "hp": 195, "atk": 39, "def": 6, "mdef": 8, "move_speed": 5.4, "attack_range": 9.0, "attack_cooldown": 1.5, "attack_startup": 0.4, "xp": 74, "aggro_range": 11.0, "leash_range": 20.0, "ranged": true,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.55, 0.78, 0.45), "shape": "capsule", "loot_table": "lt_elf_raid", "gold_min": 10, "gold_max": 22, "model": "mob_elf_bowman", "skill_ids": ["mob_root_arrow"] as Array[String]},
		{"id": "elf_lynx", "name": "Lince de Guerra", "level": 15, "hp": 180, "atk": 32, "def": 6, "mdef": 5, "move_speed": 6.2, "attack_range": 1.6, "attack_cooldown": 0.9, "attack_startup": 0.2, "xp": 59, "aggro_range": 9.0, "leash_range": 20.0,
		 "radius": 0.5, "scale": 1.05, "color": Color(0.7, 0.6, 0.35), "shape": "box", "loot_table": "lt_elf_lynx", "gold_min": 4, "gold_max": 10, "model": "mob_elf_lynx", "skill_ids": ["mob_pounce", "mob_lynx_leap"] as Array[String]},
		{"id": "elf_raider_mage", "name": "Mago Élfico", "level": 16, "hp": 210, "atk": 16, "matk": 42, "def": 5, "mdef": 12, "move_speed": 5.0, "attack_range": 8.5, "attack_cooldown": 1.7, "attack_startup": 0.45, "xp": 78, "aggro_range": 12.0, "leash_range": 20.0, "ranged": true,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.85, 0.9, 0.82), "shape": "capsule", "loot_table": "lt_elf_raid", "gold_min": 10, "gold_max": 24, "model": "mob_elf_mage",
		 "skill_ids": ["mob_light_beam", "mob_raise_wisps"] as Array[String]},
		{"id": "griffin_raider", "name": "Grifo de Guerra", "level": 17, "hp": 360, "atk": 38, "def": 9, "mdef": 8, "move_speed": 6.0, "attack_range": 1.8, "attack_cooldown": 1.2, "attack_startup": 0.3, "xp": 96, "aggro_range": 12.0, "leash_range": 22.0,
		 "radius": 0.6, "scale": 0.95, "color": Color(0.85, 0.66, 0.38), "shape": "box", "loot_table": "lt_elf_raid", "gold_min": 12, "gold_max": 26, "model": "mob_griffin",
		 "skill_ids": ["mob_dive"] as Array[String]},
		# invocação dos magos élficos (0 XP; some quando o mago cai)
		{"id": "elf_wisp", "name": "Espírito da Mata", "level": 15, "hp": 120, "atk": 12, "matk": 26, "def": 4, "mdef": 10, "move_speed": 5.4, "attack_range": 6.0, "attack_cooldown": 1.5, "xp": 0, "aggro_range": 14.0, "leash_range": 30.0, "ranged": true,
		 "radius": 0.4, "scale": 0.7, "color": Color(0.5, 1.0, 0.6), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_elemental_storm"},
		# Cidade Élfica
		{"id": "elf_warrior", "name": "Guerreiro Élfico", "level": 18, "hp": 635, "atk": 42, "def": 13, "mdef": 11, "move_speed": 5.6, "attack_range": 1.9, "attack_cooldown": 1.0, "attack_startup": 0.25, "xp": 153, "aggro_range": 10.0,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.4, 0.62, 0.42), "shape": "capsule", "loot_table": "lt_elf", "gold_min": 14, "gold_max": 30, "model": "mob_elf_warrior", "skill_ids": ["mob_elf_lunge"] as Array[String]},
		{"id": "elf_archer", "name": "Arqueiro Élfico", "level": 18, "hp": 360, "atk": 34, "def": 9, "mdef": 10, "move_speed": 5.4, "attack_range": 9.0, "attack_cooldown": 1.5, "attack_startup": 0.4, "xp": 128, "aggro_range": 11.0, "ranged": true,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.5, 0.72, 0.42), "shape": "capsule", "loot_table": "lt_elf", "gold_min": 14, "gold_max": 30, "model": "mob_elf_archer", "skill_ids": ["mob_root_arrow"] as Array[String]},
		{"id": "griffin", "name": "Grifo", "level": 18, "hp": 785, "atk": 58, "def": 12, "mdef": 10, "move_speed": 6.0, "attack_range": 2.0, "attack_cooldown": 1.3, "attack_startup": 0.35, "xp": 166, "aggro_range": 11.0, "leash_range": 22.0,
		 "radius": 0.8, "scale": 1.4, "color": Color(0.85, 0.72, 0.45), "shape": "box", "loot_table": "lt_griffin", "gold_min": 12, "gold_max": 26, "model": "mob_griffin", "skill_ids": ["mob_dive"] as Array[String]},
		{"id": "trent", "name": "Trent Ancião", "level": 19, "hp": 2300, "atk": 66, "def": 26, "mdef": 12, "move_speed": 2.6, "attack_range": 2.6, "attack_cooldown": 2.0, "attack_startup": 0.6, "xp": 170, "aggro_range": 7.0,
		 "radius": 1.0, "scale": 2.0, "color": Color(0.32, 0.4, 0.22), "shape": "box", "loot_table": "lt_trent", "gold_min": 16, "gold_max": 34, "model": "mob_trent", "skill_ids": ["mob_thorn_lash", "mob_root_grasp", "mob_thorn_hook"] as Array[String]},
		{"id": "elf_warden", "name": "Guardião da Árvore", "level": 20, "hp": 3200, "atk": 60, "def": 20, "mdef": 16, "move_speed": 5.4, "attack_range": 2.0, "attack_cooldown": 1.0, "attack_startup": 0.3, "xp": 260, "aggro_range": 11.0, "leash_range": 24.0,
		 "radius": 0.55, "scale": 1.2, "color": Color(0.85, 0.75, 0.35), "shape": "capsule", "loot_table": "lt_elf_warden", "gold_min": 30, "gold_max": 60, "model": "mob_elf_warden",
		 "skill_ids": ["mob_elf_lunge", "mob_volley", "mob_arrow_rain", "mob_thorn_hook"] as Array[String], "coin_chance": 0.05, "coin_min": 4, "coin_max": 4},
		# exército da Cidade Élfica: sargento com esquadrão (MonsterDef.escort) e os capitães dos fortes (chefes com escolta)
		{"id": "elf_sergeant", "name": "Sargento Élfico", "level": 19, "hp": 1400, "atk": 46, "def": 17, "mdef": 12, "move_speed": 5.4, "attack_range": 2.2, "attack_cooldown": 1.2, "attack_startup": 0.35, "xp": 170, "aggro_range": 11.0, "leash_range": 24.0,
		 "radius": 0.5, "scale": 1.12, "color": Color(0.7, 0.78, 0.6), "shape": "capsule", "loot_table": "lt_elf", "gold_min": 18, "gold_max": 40, "model": "mob_elf_warden",
		 "skill_ids": ["mob_elf_lunge", "mob_whirl"] as Array[String], "escort": {"id": "elf_warrior", "count": 3}},
		{"id": "elf_captain_hunter", "name": "Capitã Sylvara, a Caçadora Veloz", "level": 20, "hp": 34000, "atk": 52, "def": 12, "mdef": 12, "move_speed": 7.0, "attack_range": 10.0, "attack_cooldown": 1.0, "attack_startup": 0.3, "xp": 720, "aggro_range": 13.0, "leash_range": 28.0, "ranged": true,
		 "radius": 0.5, "scale": 1.25, "color": Color(0.35, 0.55, 0.4), "shape": "capsule", "is_boss": true, "berserk_after": 180, "loot_table": "lt_captain_hunter", "gold_min": 90, "gold_max": 180, "model": "mob_elf_captain_hunter",
		 "skill_ids": ["mob_call_lynx", "mob_volley", "mob_root_arrow", "mob_lynx_leap", "mob_arrow_rain"] as Array[String], "escort": {"id": "elf_lynx", "count": 5},
		 "intro": "Rápida demais pra você. E nunca caço sozinha.", "last_words": "A matilha... fica sem caçadora...",
		 "phases": [{"hp": 0.7, "say": "Matilha! Cerquem!", "summon": {"id": "pack_lynx", "count": 3, "max": 5, "pick": "soft"}},
			{"hp": 0.4, "say": "Chovam, flechas!", "skills": ["mob_thorn_barrage"], "ward": 0.4, "summon": {"id": "pack_lynx", "count": 2, "max": 5}},
			{"hp": 0.15, "say": "Ninguém escapa da Caçadora!", "enrage": 1.3}]},
		{"id": "elf_captain_sky", "name": "Capitão Aerion, Senhor dos Grifos", "level": 20, "hp": 41000, "atk": 88, "def": 20, "mdef": 12, "move_speed": 5.4, "attack_range": 3.0, "attack_cooldown": 0.8, "attack_startup": 0.35, "xp": 760, "aggro_range": 12.0, "leash_range": 28.0,
		 "radius": 0.55, "scale": 1.3, "color": Color(0.82, 0.86, 0.94), "shape": "capsule", "is_boss": true, "berserk_after": 100, "loot_table": "lt_captain_sky", "gold_min": 95, "gold_max": 190, "model": "mob_elf_captain_sky",
		 "skill_ids": ["mob_call_griffins", "mob_dive", "mob_crown_blade", "mob_whirl", "mob_sky_dive"] as Array[String], "escort": {"id": "griffin", "count": 2},
		 "intro": "Do céu eu vejo tudo. Inclusive o seu fim.", "last_words": "As asas... pesam...",
		 "phases": [{"hp": 0.7, "say": "Grifos, mergulhem!", "summon": {"id": "griffin_young", "count": 2, "max": 3, "pick": "far"}},
			{"hp": 0.4, "say": "Asas, me cubram!", "ward": 0.5, "summon": {"id": "griffin_young", "count": 2, "max": 3}},
			{"hp": 0.15, "say": "Eu mesmo desço!", "skills": ["mob_queen_leap"], "enrage": 1.35}]},
		{"id": "elf_captain_sap", "name": "Mestra Ilwen, Guardiã da Seiva", "level": 21, "hp": 46000, "atk": 26, "matk": 68, "def": 14, "mdef": 22, "move_speed": 5.0, "attack_range": 8.5, "attack_cooldown": 1.5, "attack_startup": 0.45, "xp": 800, "aggro_range": 13.0, "leash_range": 28.0, "ranged": true,
		 "radius": 0.5, "scale": 1.25, "color": Color(0.5, 0.75, 0.4), "shape": "capsule", "is_boss": true, "berserk_after": 130, "loot_table": "lt_captain_sap", "gold_min": 100, "gold_max": 200, "model": "mob_elf_captain_sap",
		 "skill_ids": ["mob_raise_wisps", "mob_light_beam", "mob_thorn_lash", "mob_thorn_hook"] as Array[String], "escort": {"id": "trent", "count": 2},
		 "intro": "A seiva lembra de cada machado. Inclusive o seu.", "last_words": "Volto... à raiz...",
		 "phases": [{"hp": 0.7, "say": "Raízes, prendam!", "skills": ["mob_king_roots"], "summon": {"id": "elf_wisp", "count": 3, "max": 4}},
			{"hp": 0.4, "say": "A seiva me protege!", "skills": ["mob_thorn_barrage"], "ward": 0.5, "summon": {"id": "elf_wisp", "count": 2, "max": 4}},
			{"hp": 0.15, "say": "A floresta inteira me escuta!", "enrage": 1.3}]},
		{"id": "elf_king", "name": "Rei Élfico Aelthar", "level": 21, "hp": 55000, "atk": 76, "def": 22, "mdef": 20, "move_speed": 5.0, "attack_range": 2.4, "attack_cooldown": 1.1, "attack_startup": 0.35, "xp": 900, "aggro_range": 11.0, "leash_range": 26.0,
		 "radius": 0.7, "scale": 1.6, "color": Color(0.95, 0.85, 0.4), "shape": "capsule", "is_boss": true, "berserk_after": 110, "loot_table": "lt_elf_king", "gold_min": 160, "gold_max": 300, "model": "mob_elf_king",
		 "skill_ids": ["mob_call_guard", "mob_volley", "mob_crown_blade", "mob_arrow_rain"] as Array[String], "coin_chance": 1.0, "coin_min": 4, "coin_max": 6,
		 "intro": "Humanos na raiz da Árvore-Mãe. Ajoelhem-se, ou virem adubo.", "last_words": "A Árvore... vai lembrar... de mim...",
		 "phases": [{"hp": 0.7, "say": "Guarda Real! Expulsem os invasores da Árvore-Mãe!", "ward": 0.5, "summon": {"id": "king_guard", "count": 2, "max": 2}},
			{"hp": 0.45, "say": "A floresta inteira lutará por mim!", "skills": ["mob_king_roots", "mob_thorn_barrage"], "summon": {"id": "griffin_young", "count": 2, "max": 3, "pick": "far"}},
			{"hp": 0.2, "say": "Vocês jamais terão a Árvore-Mãe!", "skills": ["mob_king_thorn_burst", "mob_thorn_hook"], "enrage": 1.2}]},
		# ---- Ruínas (lv 20-30) ----
		{"id": "skeleton", "name": "Esqueleto de Montante", "level": 24, "hp": 900, "atk": 84, "def": 20, "mdef": 10, "move_speed": 4.0, "attack_range": 1.8, "attack_cooldown": 1.2, "xp": 120, "aggro_range": 8.0,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.9, 0.9, 0.8), "shape": "capsule", "loot_table": "lt_bones", "gold_min": 15, "gold_max": 35, "model": "mob_skel_blade",
		 "skill_ids": ["mob_bone_cleave"] as Array[String]},
		{"id": "ghost", "name": "Espectro", "level": 27, "hp": 420, "atk": 30, "matk": 74, "def": 10, "mdef": 26, "move_speed": 4.4, "attack_range": 7.0, "attack_cooldown": 1.7, "attack_startup": 0.45, "xp": 150, "aggro_range": 9.0, "ranged": true,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.6, 0.9, 1.0), "shape": "cone", "loot_table": "lt_ghost", "gold_min": 18, "gold_max": 40, "model": "mob_ghost",
		 "skill_ids": ["mob_frost_shard"] as Array[String]},
		{"id": "golem", "name": "Golem de Pedra", "level": 27, "hp": 1100, "atk": 70, "def": 34, "mdef": 18, "move_speed": 2.8, "attack_range": 2.6, "attack_cooldown": 2.0, "attack_startup": 0.6, "xp": 260, "aggro_range": 7.0,
		 "radius": 0.85, "scale": 1.7, "color": Color(0.5, 0.5, 0.45), "shape": "box", "loot_table": "lt_golem", "gold_min": 25, "gold_max": 60, "model": "mob_golem"},
		# chefe opcional mais difícil do jogo (grupo de 4+): vida ~1,6x e dano ~1,3x o do Lich-Rei (2026-11-10; antes 4.200 de vida)
		{"id": "dragonling", "name": "Dragonete Ancestral", "level": 30, "hp": 140000, "atk": 120, "matk": 117, "def": 40, "mdef": 36, "move_speed": 4.4, "attack_range": 3.0, "attack_cooldown": 1.3, "attack_startup": 0.45, "xp": 4000, "aggro_range": 12.0, "leash_range": 34.0,
		 "radius": 1.1, "scale": 2.2, "color": Color(0.8, 0.2, 0.3), "shape": "box", "is_boss": true, "berserk_after": 200, "loot_table": "lt_dragonling", "gold_min": 400, "gold_max": 700, "model": "mob_dragon",
		 "skill_ids": ["mob_dragon_breath", "mob_dragon_tail", "mob_dragon_dive", "mob_dragon_roar"] as Array[String], "coin_chance": 1.0, "coin_min": 5, "coin_max": 8,
		 "intro": "Mil anos de sono... e vocês acordam o fogo?", "last_words": "As cinzas... lembram...",
		 # Covil do Dragonete (2026-11-21): 6 ovos no ninho; em 70% metade dos inteiros choca, em 40% o resto (quebrar antes = menos filhotes)
		 "eggs": {"id": "dragon_egg", "count": 6, "r": 6.0},
		 "phases": [{"hp": 0.7, "say": "O céu vai queimar com vocês! Ovos, despertem!", "skills": ["mob_dragon_meteor"], "hatch": 0.5},
			{"hp": 0.4, "say": "Ninhada, protejam o sangue antigo!", "ward": 0.5, "skills": ["mob_dragon_call"], "enrage": 1.2, "hatch": 1.0},
			{"hp": 0.15, "say": "QUEIMEM!", "enrage": 1.4}]},
		# ovo do ninho do Dragonete: parado, não ataca, quebra (choca em filhote nas fases do chefe)
		{"id": "dragon_egg", "name": "Ovo de Dragão", "level": 30, "hp": 1500, "atk": 1, "def": 20, "mdef": 20, "move_speed": 0.0, "attack_range": 0.0, "attack_cooldown": 60.0, "xp": 0, "aggro_range": 0.0, "leash_range": 40.0,
		 "radius": 0.55, "scale": 1.0, "color": Color(0.85, 0.4, 0.25), "shape": "sphere", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_dragon_egg", "egg": true},
		{"id": "dragon_whelp", "name": "Filhote de Dragão", "level": 30, "hp": 1800, "atk": 60, "matk": 60, "def": 18, "mdef": 18, "move_speed": 5.0, "attack_range": 2.2, "attack_cooldown": 1.3, "attack_startup": 0.4, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0,
		 "radius": 0.6, "scale": 0.9, "color": Color(0.9, 0.35, 0.3), "shape": "box", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_dragon"},
		# ---- chefes de dungeon (modelo de um monstro comum, maior) ----
		{"id": "slime_king", "name": "Rei Slime", "level": 11, "hp": 2800, "atk": 28, "def": 9, "mdef": 8, "move_speed": 3.4, "attack_range": 2.4, "attack_cooldown": 1.5, "attack_startup": 0.45, "xp": 240, "aggro_range": 9.0, "leash_range": 25.0,
		 "radius": 1.0, "scale": 2.0, "color": Color(0.3, 0.5, 0.95), "shape": "sphere", "is_boss": true, "loot_table": "lt_slime_king", "gold_min": 35, "gold_max": 70, "skill_ids": ["mob_charge", "mob_acid_spit"] as Array[String], "model": "mob_slime",
		 "phases": [{"hp": 0.6, "say": "Blub... o rei se divide!", "skills": ["mob_toxic_rain"], "summon": {"id": "slimeling", "count": 3, "max": 4}},
			{"hp": 0.25, "say": "BLUUUB!", "summon": {"id": "slimeling", "count": 2, "max": 4}, "enrage": 1.3}]},
		{"id": "spider_queen", "name": "Rainha Aranha", "level": 20, "hp": 46000, "atk": 66, "def": 18, "mdef": 15, "move_speed": 4.6, "attack_range": 2.4, "attack_cooldown": 1.2, "attack_startup": 0.35, "xp": 800, "aggro_range": 10.0, "leash_range": 25.0,
		 "radius": 1.0, "scale": 1.9, "color": Color(0.45, 0.2, 0.55), "shape": "box", "is_boss": true, "berserk_after": 180, "loot_table": "lt_spider_queen", "gold_min": 90, "gold_max": 170, "skill_ids": ["mob_raise_spiderlings", "mob_whirl", "mob_venom_pool", "mob_web_pull"] as Array[String], "model": "mob_spider",
		 "crowd_skills": ["mob_cocoon"] as Array[String], "crowd_say": "Tanta carne... vou guardar um pouco para depois.",
		 "intro": "Carne quente no meu ninho... que gentileza.", "last_words": "Meus... filhotes...",
		 "phases": [{"hp": 0.7, "say": "Filhotes... o jantar chegou.", "skills": ["mob_web", "mob_queen_leap"], "summon": {"id": "spiderling", "count": 3, "max": 5}},
			{"hp": 0.4, "say": "Protejam a mãe!", "skills": ["mob_venom_barrage"], "ward": 0.5, "summon": {"id": "spiderling", "count": 3, "max": 5, "pick": "far"}},
			{"hp": 0.15, "say": "Ninguém sai do meu ninho!", "enrage": 1.3}]},
		{"id": "crypt_lord", "name": "Senhor da Cripta", "level": 29, "hp": 88000, "atk": 124, "matk": 100, "def": 32, "mdef": 28, "move_speed": 4.0, "attack_range": 2.6, "attack_cooldown": 1.1, "attack_startup": 0.4, "xp": 1300, "aggro_range": 10.0, "leash_range": 28.0,
		 "radius": 0.9, "scale": 1.8, "color": Color(0.6, 0.45, 0.85), "shape": "capsule", "is_boss": true, "berserk_after": 100, "loot_table": "lt_crypt_lord", "gold_min": 160, "gold_max": 320, "skill_ids": ["mob_raise_thralls", "mob_firebreath", "mob_soul_drain", "mob_flame_barrage"] as Array[String], "model": "mob_skeleton",
		 "phases": [{"hp": 0.7, "say": "Vel'Thar não dorme sozinho.", "summon": {"id": "crypt_thrall", "count": 2, "max": 4}},
			{"hp": 0.4, "say": "Servos, de pé: protejam o mestre!", "skills": ["mob_bone_hook"], "ward": 0.5, "summon": {"id": "crypt_thrall", "count": 2, "max": 4}},
			{"hp": 0.15, "say": "Seu fôlego agora é meu.", "skills": ["mob_death_wave"], "enrage": 1.25}]},
		# ---- Catacumbas do Conde (lv 8-13) ----
		{"id": "zombie", "name": "Morto Andante", "level": 8, "hp": 160, "atk": 20, "def": 6, "mdef": 3, "move_speed": 2.7, "attack_range": 1.6, "attack_cooldown": 1.5, "attack_startup": 0.4, "xp": 36, "aggro_range": 7.0,
		 "radius": 0.5, "scale": 1.0, "color": Color(0.5, 0.6, 0.4), "shape": "capsule", "loot_table": "lt_zombie", "gold_min": 4, "gold_max": 11, "model": "mob_zombie"},
		{"id": "bone_recruit", "name": "Recruta de Ossos", "level": 9, "hp": 140, "atk": 23, "def": 7, "mdef": 4, "move_speed": 4.0, "attack_range": 1.7, "attack_cooldown": 1.2, "xp": 40, "aggro_range": 8.0,
		 "radius": 0.45, "scale": 0.95, "color": Color(0.85, 0.85, 0.75), "shape": "capsule", "loot_table": "lt_bone_recruit", "gold_min": 5, "gold_max": 12, "model": "mob_skeleton"},
		{"id": "bone_archer", "name": "Arqueiro de Ossos", "level": 10, "hp": 165, "atk": 26, "def": 5, "mdef": 4, "move_speed": 3.8, "attack_range": 8.0, "attack_cooldown": 1.7, "attack_startup": 0.45, "xp": 56, "aggro_range": 10.0, "ranged": true,
		 "radius": 0.45, "scale": 0.95, "color": Color(0.8, 0.8, 0.65), "shape": "capsule", "loot_table": "lt_bone_recruit", "gold_min": 5, "gold_max": 12, "model": "mob_skeleton"},
		{"id": "ghoul", "name": "Carniçal", "level": 11, "hp": 470, "atk": 35, "def": 8, "mdef": 5, "move_speed": 4.8, "attack_range": 1.7, "attack_cooldown": 1.1, "attack_startup": 0.28, "xp": 86, "aggro_range": 9.0,
		 "radius": 0.5, "scale": 1.1, "color": Color(0.45, 0.5, 0.45), "shape": "capsule", "loot_table": "lt_zombie", "gold_min": 6, "gold_max": 14, "model": "mob_zombie"},
		{"id": "wraith", "name": "Aparição", "level": 12, "hp": 335, "atk": 23, "matk": 31, "def": 5, "mdef": 12, "move_speed": 4.2, "attack_range": 7.0, "attack_cooldown": 1.7, "attack_startup": 0.45, "xp": 91, "aggro_range": 9.0, "ranged": true,
		 "radius": 0.45, "scale": 0.9, "color": Color(0.55, 0.75, 0.95), "shape": "cone", "loot_table": "lt_wraith", "gold_min": 7, "gold_max": 15, "model": "mob_ghost"},
		{"id": "bone_servant", "name": "Ossada Erguida", "level": 9, "hp": 200, "atk": 20, "def": 3, "mdef": 3, "move_speed": 4.4, "attack_range": 1.6, "attack_cooldown": 1.3, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0,
		 "radius": 0.4, "scale": 0.8, "color": Color(0.8, 0.85, 0.7), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_skeleton"},
		{"id": "lost_soul", "name": "Alma Penada", "level": 10, "hp": 150, "atk": 10, "matk": 20, "def": 2, "mdef": 8, "move_speed": 4.0, "attack_range": 6.0, "attack_cooldown": 1.8, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0, "ranged": true,
		 "radius": 0.4, "scale": 0.7, "color": Color(0.6, 0.85, 1.0), "shape": "cone", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_ghost"},
		{"id": "bone_captain", "name": "Capitão de Ossos", "level": 10, "hp": 17000, "atk": 45, "def": 10, "mdef": 7, "move_speed": 4.0, "attack_range": 2.4, "attack_cooldown": 1.4, "attack_startup": 0.4, "xp": 300, "aggro_range": 10.0, "leash_range": 26.0,
		 "radius": 0.9, "scale": 1.7, "color": Color(0.9, 0.82, 0.6), "shape": "capsule", "is_boss": true, "berserk_after": 130, "loot_table": "lt_bone_captain", "gold_min": 40, "gold_max": 80, "skill_ids": ["mob_raise_dead", "mob_charge", "mob_whirl", "mob_soul_barrage", "mob_bone_hook"] as Array[String], "model": "mob_skeleton",
		 "intro": "Formação! Intrusos na caserna do Conde!", "last_words": "A guarda... cai...",
		 "phases": [{"hp": 0.7, "say": "De pé, soldados!", "summon": {"id": "bone_servant", "count": 2, "max": 4}},
			{"hp": 0.4, "say": "Escudos! Formação!", "ward": 0.5, "summon": {"id": "bone_servant", "count": 3, "max": 4}},
			{"hp": 0.15, "say": "A guarda do Conde não cai!", "enrage": 1.3}]},
		{"id": "wailing_widow", "name": "Viúva Lamentosa", "level": 11, "hp": 17500, "atk": 18, "matk": 33, "def": 7, "mdef": 14, "move_speed": 3.8, "attack_range": 7.0, "attack_cooldown": 1.6, "attack_startup": 0.45, "xp": 340, "aggro_range": 11.0, "leash_range": 26.0, "ranged": true,
		 "radius": 0.8, "scale": 1.6, "color": Color(0.7, 0.8, 1.0), "shape": "cone", "is_boss": true, "berserk_after": 160, "loot_table": "lt_wailing_widow", "gold_min": 45, "gold_max": 90, "skill_ids": ["mob_call_souls", "mob_wail", "mob_grave_touch", "mob_soul_barrage"] as Array[String], "model": "mob_ghost",
		 "intro": "Você não é ele... Onde ele está?", "last_words": "Enfim... silêncio...",
		 "phases": [{"hp": 0.7, "say": "Ele prometeu que voltaria...", "summon": {"id": "lost_soul", "count": 3, "max": 3, "pick": "soft"}},
			{"hp": 0.4, "say": "Fiquem comigo... para sempre...", "skills": ["mob_death_wave"], "ward": 0.5, "summon": {"id": "lost_soul", "count": 2, "max": 3}},
			{"hp": 0.15, "say": "ONDE ELE ESTÁ?!", "enrage": 1.3}]},
		{"id": "count_vargo", "name": "Conde Vargo", "level": 13, "hp": 22000, "atk": 41, "matk": 46, "def": 12, "mdef": 14, "move_speed": 4.0, "attack_range": 2.6, "attack_cooldown": 1.3, "attack_startup": 0.4, "xp": 800, "aggro_range": 12.0, "leash_range": 30.0,
		 "radius": 0.9, "scale": 1.8, "color": Color(0.5, 0.35, 0.75), "shape": "capsule", "is_boss": true, "berserk_after": 200, "loot_table": "lt_count_vargo", "gold_min": 80, "gold_max": 160, "skill_ids": ["mob_soul_drain", "mob_whirl", "mob_blood_mark", "mob_bone_hook"] as Array[String], "model": "mob_lich",
		 "intro": "Visitas? Em trezentos anos ninguém desceu sem ser convidado.", "last_words": "Aldara... ainda... me deve...",
		 "phases": [{"hp": 0.7, "say": "Aldara ainda me deve 300 anos.", "skills": ["mob_raise_dead", "mob_shadow_bats"], "summon": {"id": "bone_servant", "count": 2, "max": 4}},
			{"hp": 0.45, "say": "Meu sangue não é seu para derramar.", "skills": ["mob_soul_barrage"], "ward": 0.5, "summon": {"id": "lost_soul", "count": 2, "max": 3, "pick": "soft"}},
			{"hp": 0.2, "say": "Basta. Ajoelhem-se!", "skills": ["mob_death_wave"], "summon": {"id": "lost_soul", "count": 2, "max": 3}, "enrage": 1.35}]},
		# ---- Pedreira dos Golens (Floresta, 11-15): golens de musgo, pedra e cristal; trent jovem no bosque ----
		{"id": "golem_moss", "name": "Golem de Musgo", "level": 11, "hp": 500, "atk": 56, "def": 13, "mdef": 6, "move_speed": 3.8, "attack_range": 2.0, "attack_cooldown": 1.3, "attack_startup": 0.5, "xp": 92, "aggro_range": 9.5,
		 "radius": 0.7, "scale": 1.15, "color": Color(0.42, 0.6, 0.34), "shape": "box", "loot_table": "lt_golem_moss", "gold_min": 8, "gold_max": 18, "model": "mob_golem"},
		{"id": "golem_stone", "name": "Golem da Pedreira", "level": 12, "hp": 520, "atk": 54, "def": 16, "mdef": 7, "move_speed": 3.4, "attack_range": 2.1, "attack_cooldown": 1.5, "attack_startup": 0.55, "xp": 104, "aggro_range": 9.5,
		 "radius": 0.75, "scale": 1.3, "color": Color(0.66, 0.56, 0.44), "shape": "box", "loot_table": "lt_golem_stone", "gold_min": 9, "gold_max": 20, "model": "mob_golem",
		 "skill_ids": ["mob_quarry_slam"] as Array[String]},
		{"id": "golem_shard", "name": "Golem de Cristal", "level": 13, "hp": 380, "atk": 26, "matk": 42, "def": 10, "mdef": 13, "move_speed": 3.6, "attack_range": 7.0, "attack_cooldown": 1.8, "attack_startup": 0.5, "xp": 98, "aggro_range": 11.0, "ranged": true,
		 "radius": 0.6, "scale": 1.05, "color": Color(0.42, 0.68, 0.98), "shape": "box", "loot_table": "lt_golem_shard", "gold_min": 9, "gold_max": 20, "model": "mob_golem"},
		{"id": "trent_young", "name": "Trent Jovem", "level": 14, "hp": 385, "atk": 38, "def": 9, "mdef": 6, "move_speed": 3.8, "attack_range": 2.0, "attack_cooldown": 1.4, "attack_startup": 0.45, "xp": 84, "aggro_range": 8.0,
		 "radius": 0.6, "scale": 0.82, "color": Color(0.44, 0.52, 0.3), "shape": "capsule", "loot_table": "lt_ent", "gold_min": 7, "gold_max": 16, "model": "mob_trent",
		 "skill_ids": ["mob_thorn_lash"] as Array[String]},
		# chefes da Pedreira (modelos próprios: tools/blender/mob_kit.golem_boss)
		{"id": "golem_ancient", "name": "Golem Ancestral", "level": 13, "hp": 27000, "atk": 62, "def": 18, "mdef": 8, "move_speed": 3.2, "attack_range": 2.8, "attack_cooldown": 1.6, "attack_startup": 0.55, "xp": 460, "aggro_range": 11.0, "leash_range": 28.0,
		 "radius": 1.2, "scale": 1.6, "color": Color(0.42, 0.56, 0.34), "shape": "box", "is_boss": true, "berserk_after": 130, "loot_table": "lt_golem_ancient", "gold_min": 60, "gold_max": 120, "model": "mob_golem_ancient",
		 "skill_ids": ["mob_raise_moss", "mob_quarry_slam", "mob_root_grasp", "mob_boulder_toss"] as Array[String],
		 "intro": "Mil anos... de musgo... e agora PASSOS.", "last_words": "Volto... a ser... pedra...",
		 "phases": [{"hp": 0.7, "say": "A pedreira acorda comigo!", "skills": ["mob_magnet_pull"], "summon": {"id": "golem_mossling", "count": 3, "max": 4}},
			{"hp": 0.45, "say": "Pedras, chovam!", "skills": ["mob_boulder_barrage"], "ward": 0.5, "summon": {"id": "golem_mossling", "count": 2, "max": 4}},
			{"hp": 0.2, "say": "ESMAGAR!", "skills": ["mob_rockfall"], "enrage": 1.3}]},
		{"id": "crystal_warden", "name": "Guardiã de Cristal", "level": 14, "hp": 24500, "atk": 28, "matk": 35, "def": 12, "mdef": 18, "move_speed": 3.8, "attack_range": 7.0, "attack_cooldown": 1.6, "attack_startup": 0.45, "xp": 520, "aggro_range": 12.0, "leash_range": 28.0, "ranged": true,
		 "radius": 0.95, "scale": 1.5, "color": Color(0.45, 0.72, 1.0), "shape": "box", "is_boss": true, "berserk_after": 150, "loot_table": "lt_crystal_warden", "gold_min": 65, "gold_max": 130, "model": "mob_crystal_warden",
		 "skill_ids": ["mob_raise_shards", "mob_shard_fan", "mob_crystal_prison", "mob_hail_barrage"] as Array[String],
		 "intro": "O veio azul é meu. Vocês são só reflexo.", "last_words": "Rachada... toda...",
		 "phases": [{"hp": 0.7, "say": "Estilhacem!", "skills": ["mob_crystal_ward"], "summon": {"id": "crystal_shardling", "count": 3, "max": 4}},
			{"hp": 0.4, "say": "O veio me protege!", "ward": 0.5, "summon": {"id": "crystal_shardling", "count": 2, "max": 4, "pick": "far"}},
			{"hp": 0.15, "say": "Brilho... TOTAL!", "skills": ["mob_rockfall"], "enrage": 1.3}]},
		{"id": "quarry_heart", "name": "Coração da Pedreira", "level": 15, "hp": 46000, "atk": 66, "matk": 66, "def": 20, "mdef": 16, "move_speed": 3.4, "attack_range": 3.0, "attack_cooldown": 1.5, "attack_startup": 0.5, "xp": 950, "aggro_range": 13.0, "leash_range": 30.0,
		 "radius": 1.4, "scale": 1.9, "color": Color(0.85, 0.45, 0.25), "shape": "box", "is_boss": true, "berserk_after": 150, "loot_table": "lt_quarry_heart", "gold_min": 110, "gold_max": 220, "model": "mob_quarry_heart",
		 "skill_ids": ["mob_raise_moss", "mob_quarry_slam", "mob_boulder_toss", "mob_rockfall", "mob_magnet_pull"] as Array[String],
		 "intro": "Vocês mataram meus filhos. Eu sou a montanha.", "last_words": "O veio... se cala...",
		 "phases": [{"hp": 0.7, "say": "Pedra e cristal, a mim!", "summon": {"id": "golem_mossling", "count": 2, "max": 4}},
			{"hp": 0.45, "say": "Brilhem, filhos!", "skills": ["mob_shard_fan", "mob_boulder_barrage"], "ward": 0.35, "summon": {"id": "crystal_shardling", "count": 3, "max": 4}},
			{"hp": 0.2, "say": "A MONTANHA CAI!", "enrage": 1.15}]},
		# lacaios dos chefes da Pedreira (0 XP)
		{"id": "golem_mossling", "name": "Golenzinho de Musgo", "level": 12, "hp": 240, "atk": 24, "def": 9, "mdef": 4, "move_speed": 4.0, "attack_range": 1.6, "attack_cooldown": 1.4, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0,
		 "radius": 0.5, "scale": 0.75, "color": Color(0.48, 0.66, 0.36), "shape": "box", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_golem"},
		{"id": "crystal_shardling", "name": "Lasca Viva", "level": 13, "hp": 160, "atk": 16, "matk": 26, "def": 6, "mdef": 10, "move_speed": 4.2, "attack_range": 6.0, "attack_cooldown": 1.6, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0, "ranged": true,
		 "radius": 0.4, "scale": 0.6, "color": Color(0.5, 0.78, 1.0), "shape": "box", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_golem"},
		# ---- lacaios dos chefes antigos (0 XP) ----
		{"id": "crab_small", "name": "Caranguejinho", "level": 5, "hp": 50, "atk": 10, "def": 4, "mdef": 1, "move_speed": 4.2, "attack_range": 1.3, "attack_cooldown": 1.1, "xp": 0, "aggro_range": 14.0, "leash_range": 30.0,
		 "radius": 0.35, "scale": 0.55, "color": Color(0.95, 0.56, 0.36), "shape": "box", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_crab"},
		{"id": "boar_piglet", "name": "Leitão", "level": 4, "hp": 45, "atk": 9, "def": 2, "mdef": 1, "move_speed": 4.6, "attack_range": 1.3, "attack_cooldown": 1.2, "xp": 0, "aggro_range": 14.0, "leash_range": 30.0,
		 "radius": 0.35, "scale": 0.6, "color": Color(0.62, 0.42, 0.3), "shape": "box", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_boar"},
		{"id": "slimeling", "name": "Slimezinho", "level": 8, "hp": 110, "atk": 14, "def": 3, "mdef": 3, "move_speed": 4.2, "attack_range": 1.4, "attack_cooldown": 1.3, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0,
		 "radius": 0.4, "scale": 0.75, "color": Color(0.35, 0.6, 1.0), "shape": "sphere", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_slime"},
		{"id": "spiderling", "name": "Filhote de Aranha", "level": 18, "hp": 280, "atk": 36, "def": 9, "mdef": 7, "move_speed": 5.0, "attack_range": 1.5, "attack_cooldown": 1.1, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0,
		 "radius": 0.4, "scale": 0.7, "color": Color(0.5, 0.3, 0.6), "shape": "box", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_spider"},
		# casulo da Rainha Aranha (MobSystem.cocoon): não anda nem bate; quebrar solta o aliado preso
		{"id": "web_cocoon", "name": "Casulo de Seda", "level": 18, "hp": 2200, "atk": 1, "def": 8, "mdef": 8, "move_speed": 0.0, "attack_range": 0.0, "attack_cooldown": 60.0, "xp": 0, "aggro_range": 0.0, "leash_range": 40.0,
		 "radius": 0.5, "scale": 1.1, "color": Color(0.93, 0.93, 0.9), "shape": "sphere", "loot_table": "", "gold_min": 0, "gold_max": 0},
		{"id": "crypt_thrall", "name": "Servo da Cripta", "level": 26, "hp": 260, "atk": 32, "def": 14, "mdef": 10, "move_speed": 4.2, "attack_range": 1.7, "attack_cooldown": 1.3, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0,
		 "radius": 0.45, "scale": 0.9, "color": Color(0.7, 0.6, 0.85), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_skeleton"},
		{"id": "pack_lynx", "name": "Filhote da Matilha", "level": 18, "hp": 240, "atk": 30, "def": 6, "mdef": 5, "move_speed": 6.4, "attack_range": 1.5, "attack_cooldown": 0.9, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0,
		 "radius": 0.4, "scale": 0.8, "color": Color(0.8, 0.65, 0.4), "shape": "box", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_elf_lynx", "skill_ids": ["mob_pounce"] as Array[String]},
		{"id": "king_guard", "name": "Guarda Real Élfico", "level": 20, "hp": 900, "atk": 40, "def": 16, "mdef": 12, "move_speed": 5.4, "attack_range": 1.9, "attack_cooldown": 1.1, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0,
		 "radius": 0.45, "scale": 1.1, "color": Color(0.8, 0.72, 0.4), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_elf_warrior", "skill_ids": ["mob_elf_lunge"] as Array[String]},
		{"id": "griffin_young", "name": "Grifo Jovem", "level": 19, "hp": 300, "atk": 36, "def": 9, "mdef": 8, "move_speed": 6.0, "attack_range": 1.8, "attack_cooldown": 1.2, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0,
		 "radius": 0.6, "scale": 1.05, "color": Color(0.9, 0.8, 0.55), "shape": "box", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_griffin"},
		# ---- sentinelas do Posto dos Caçadores (NPC com `fighter`; atributos e alcance daqui, visual do kit) ----
		{"id": "guard_archer", "name": "Caçadora do Posto", "level": 18, "hp": 1050, "atk": 40, "def": 18, "mdef": 12, "move_speed": 4.8, "attack_range": 10.0, "attack_cooldown": 1.5, "attack_startup": 0.4, "xp": 0, "ranged": true,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.45, 0.55, 0.35), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0},
		{"id": "guard_warrior", "name": "Soldado do Posto", "level": 18, "hp": 1700, "atk": 37, "def": 27, "mdef": 14, "move_speed": 4.8, "attack_range": 1.9, "attack_cooldown": 1.2, "attack_startup": 0.3, "xp": 0,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.5, 0.5, 0.58), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0},
		# ---- companheiro do Ranger Caçador (vida/ataque vêm do dono) ----
		{"id": "companion", "name": "Lince", "level": 1, "hp": 100, "atk": 10, "def": 5, "mdef": 5, "move_speed": 6.4, "attack_range": 1.6, "attack_cooldown": 0.9, "xp": 0,
		 "radius": 0.5, "scale": 1.0, "color": Color(0.82, 0.62, 0.36), "shape": "box", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_lynx"},
		# ---- torreta de campo do Ranger Atirador ascendido (RangerAscension; vida/ATK/DEF vêm do dono, não anda) ----
		{"id": "ranger_turret", "name": "Torreta de Campo", "level": 1, "hp": 100, "atk": 10, "def": 5, "mdef": 5, "move_speed": 0.0, "attack_range": Balance.TURRET_RANGE, "attack_cooldown": Balance.TURRET_SHOT_CD, "attack_startup": 0.15, "xp": 0,
		 "aggro_range": Balance.TURRET_RANGE, "ranged": true, "radius": 0.55, "scale": 1.0, "color": Color(0.55, 0.42, 0.28), "shape": "turret", "loot_table": "", "gold_min": 0, "gold_max": 0},
		# ---- Anjo Guardião do Bispo ascendido (ChoirSystem: espírito sem cérebro; cura pela WILL do Bispo, ninguém o mira) ----
		{"id": "choir_angel", "name": "Anjo Guardião", "level": 1, "hp": 100, "atk": 1, "def": 5, "mdef": 5, "move_speed": 0.0, "attack_range": 0.0, "attack_cooldown": 9.0, "xp": 0,
		 "aggro_range": 0.0, "radius": 0.05, "scale": 1.0, "color": Color(1.0, 0.93, 0.7), "shape": "angel", "loot_table": "", "gold_min": 0, "gold_max": 0},
		# ---- invocações do Druida (Xamã) ----
		{"id": "spirit_wolf", "name": "Lobo Espiritual", "level": 1, "hp": 70, "atk": 13, "def": 3, "mdef": 3, "move_speed": 6.0, "attack_range": 1.6, "attack_cooldown": 0.9, "xp": 0,
		 "radius": 0.45, "scale": 0.85, "color": Color(0.5, 0.95, 0.65), "shape": "box", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_wolf"},
		# lobo da matilha do Lobo Alfa (ascensão do Druida, DruidAscension.call_pack: vida/ATK/DEF vêm do dono)
		{"id": Balance.ANC_PACK_MONSTER, "name": "Lobo da Matilha", "level": 1, "hp": 90, "atk": 14, "def": 4, "mdef": 4, "move_speed": 6.4, "attack_range": 1.6, "attack_cooldown": 0.9, "xp": 0,
		 "radius": 0.45, "scale": 0.95, "color": Color(0.7, 0.72, 0.8), "shape": "box", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_wolf"},
		{"id": "treant", "name": "Ent Guardião", "level": 1, "hp": 150, "atk": 15, "def": 10, "mdef": 6, "move_speed": 3.6, "attack_range": 2.0, "attack_cooldown": 1.4, "xp": 0,
		 "radius": 0.7, "scale": 0.8, "color": Color(0.45, 0.7, 0.35), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_ent",
		 "skill_ids": ["mob_whirl"] as Array[String]},
		# ---- elementais do Elementalista (ataque = parte do MATK do dono) ----
		{"id": "fire_elemental", "name": "Elemental de Fogo", "level": 1, "hp": 90, "atk": 12, "def": 4, "mdef": 8, "move_speed": 5.0, "attack_range": 5.0, "attack_cooldown": 1.2, "xp": 0,
		 "radius": 0.45, "scale": 0.9, "color": Color(1.0, 0.45, 0.15), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_elemental_fire",
		 "skill_ids": ["mob_firebreath"] as Array[String]},
		{"id": "frost_elemental", "name": "Elemental de Gelo", "level": 1, "hp": 120, "atk": 10, "def": 8, "mdef": 8, "move_speed": 4.6, "ranged": true, "attack_range": 5.0, "attack_cooldown": 1.3, "xp": 0,
		 "radius": 0.5, "scale": 0.95, "color": Color(0.55, 0.85, 1.0), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_elemental_frost",
		 "skill_ids": ["mob_frost_shard"] as Array[String]},
		{"id": "storm_elemental", "name": "Elemental de Raio", "level": 1, "hp": 80, "atk": 13, "def": 3, "mdef": 8, "move_speed": 5.6, "ranged": true, "attack_range": 5.0, "attack_cooldown": 1.0, "xp": 0,
		 "radius": 0.45, "scale": 0.9, "color": Color(0.75, 0.75, 1.0), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_elemental_storm",
		 "skill_ids": ["mob_static_bolt"] as Array[String]},
		# ---- invocações do Necromancer (cão, lich, rei) ----
		{"id": "bone_hound", "name": "Cão de Ossos", "level": 1, "hp": 70, "atk": 13, "def": 4, "mdef": 4, "move_speed": 6.6, "attack_range": 1.6, "attack_cooldown": 0.8, "xp": 0,
		 "radius": 0.45, "scale": 0.85, "color": Color(0.9, 0.88, 0.8), "shape": "box", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_bone_hound"},
		{"id": "lich_servant", "name": "Lich Servo", "level": 1, "hp": 110, "atk": 16, "def": 4, "mdef": 14, "move_speed": 4.6, "ranged": true, "attack_range": 7.0, "attack_cooldown": 1.5, "xp": 0,
		 "radius": 0.45, "scale": 0.95, "color": Color(0.55, 0.8, 1.0), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_lich",
		 "skill_ids": ["mob_frost_shard", "mob_frost_ring"] as Array[String]},
		{"id": "skeleton_king", "name": "Rei Esqueleto", "level": 1, "hp": 260, "atk": 24, "def": 14, "mdef": 8, "move_speed": 4.4, "attack_range": 2.2, "attack_cooldown": 1.3, "xp": 0,
		 "radius": 0.7, "scale": 1.35, "color": Color(0.9, 0.85, 0.6), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_skeleton_king",
		 "skill_ids": ["mob_whirl"] as Array[String]},
		# ---- invocação do Necromancer ----
		{"id": "skeleton_minion", "name": "Esqueleto Servo", "level": 1, "hp": 60, "atk": 12, "def": 4, "mdef": 4, "move_speed": 5.2, "attack_range": 1.6, "attack_cooldown": 1.0, "xp": 0,
		 "radius": 0.4, "scale": 0.9, "color": Color(0.8, 0.95, 0.85), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_skeleton"},
	]
	L.append_array(_horde())
	L.append_array(_kharzun())
	L.append_array(_kharzun_bosses())
	L.append_array(_act3())
	L.append_array(_act3_adds())
	L.append_array(_act3_field_bosses())
	L.append_array(_act3_wp6_bosses())
	L.append_array(_marsh())
	L.append_array(_viveiro())
	L.append_array(_oaths())
	L.append_array(_dawn_rests())
	L.append_array(_dawn_echoes(L))
	var out: Array = []
	for d in L:
		out.append(_mk(_f2(d)))
	return out

## Ato II: HP/ATK/DEF/MDEF da fórmula F2 (Balance.horde_stat) para quem tem `stat_role`; o resto fica como está.
static func _f2(d: Dictionary) -> Dictionary:
	if not d.has("stat_role"):
		return d
	var role: String = d["stat_role"]
	var lv: int = int(d["level"])
	var mods: Dictionary = d.get("unit_mods", {})
	d["hp"] = roundf(Balance.horde_stat(role, "hp", lv, mods))
	d["atk"] = snappedf(Balance.horde_stat(role, "atk", lv, mods), 0.1)
	d["def"] = snappedf(Balance.horde_stat(role, "def", lv, mods), 0.1)
	d["mdef"] = snappedf(Balance.horde_stat(role, "mdef", lv, mods), 0.1)
	if Balance.horde_late(role, "startup", lv) != 1.0 or Balance.horde_late(role, "cooldown", lv) != 1.0:   # 35+: golpe básico mais rápido
		d["attack_startup"] = snappedf(float(d.get("attack_startup", 0.35)) * Balance.horde_late(role, "startup", lv), 0.01)
		d["attack_cooldown"] = snappedf(float(d.get("attack_cooldown", 1.4)) * Balance.horde_late(role, "cooldown", lv), 0.01)
	if Balance.horde_late(role, "skill_delay", lv, 0.0) > 0.0:
		d["skill_delay"] = Balance.horde_late(role, "skill_delay", lv, 0.0)
	if d.has("matk_mult"):                 # magia (naga) = parte do ATK da fórmula
		d["matk"] = snappedf(float(d["atk"]) * float(d["matk_mult"]), 0.1)
		d.erase("matk_mult")
	return d

## Ato II, faixa 30-35 (design/gdd/ato2-horda.md R3): linhas da Horda e nagas da Costa Partida. Estágio de cima lidera
## os de baixo (`escort`); números pela F2 (`stat_role` + `unit_mods`). Spawners ficam com o pacote das zonas.
static func _horde() -> Array:
	var H := "horde"
	return [
		# Goblins: Lanceiro (bando barato) → Empalador (estocada que atravessa) → Agitador (aura de fúria; morto, desanima)
		{"id": "goblin_lancer", "name": "Lanceiro Goblin", "level": 30, "stat_role": "comum", "unit_mods": {"hp": 1.05, "atk": 1.2}, "faction": H,
		 "move_speed": 5.0, "attack_range": 2.2, "attack_cooldown": 1.1, "attack_startup": 0.3, "xp": 230, "aggro_range": 9.0,
		 "radius": 0.4, "scale": 0.8, "color": Color(0.5, 0.62, 0.3), "shape": "capsule", "loot_table": "lt_goblin", "gold_min": 18, "gold_max": 36, "model": "mob_goblin_lancer"},
		{"id": "goblin_impaler", "name": "Empalador Goblin", "level": 33, "stat_role": "comum", "unit_mods": {"hp": 1.35, "atk": 1.15}, "faction": H,
		 "move_speed": 4.8, "attack_range": 2.4, "attack_cooldown": 1.2, "attack_startup": 0.35, "xp": 320, "aggro_range": 9.0, "leash_range": 22.0,
		 "radius": 0.42, "scale": 0.9, "color": Color(0.46, 0.56, 0.28), "shape": "capsule", "loot_table": "lt_goblin", "gold_min": 22, "gold_max": 44, "model": "mob_goblin_impaler",
		 "skill_ids": ["mob_impale"] as Array[String], "escort": {"id": "goblin_lancer", "count": 2}},
		{"id": "goblin_agitator", "name": "Agitador Goblin", "level": 36, "stat_role": "comum", "unit_mods": {"hp": 1.45, "atk": 1.4}, "faction": H, "aura": "agitator",
		 "move_speed": 4.6, "attack_range": 2.0, "attack_cooldown": 1.3, "attack_startup": 0.35, "xp": 560, "aggro_range": 10.0, "leash_range": 24.0,
		 "radius": 0.45, "scale": 0.95, "color": Color(0.62, 0.3, 0.22), "shape": "capsule", "loot_table": "lt_goblin_agitator", "gold_min": 40, "gold_max": 80, "model": "mob_goblin_agitator",
		 "skill_ids": ["mob_drum_beat"] as Array[String], "escort": {"id": "goblin_impaler", "count": 2}},
		# Ginetes: Ginete de Lobo (rápido, flanqueia) → Saqueador (rede que prende)
		{"id": "wolf_rider", "name": "Ginete de Lobo", "level": 31, "stat_role": "comum", "unit_mods": {"hp": 1.5}, "faction": H,
		 "move_speed": 6.2, "attack_range": 2.0, "attack_cooldown": 1.0, "attack_startup": 0.25, "xp": 300, "aggro_range": 11.0, "leash_range": 24.0,
		 "radius": 0.6, "scale": 1.0, "color": Color(0.5, 0.48, 0.45), "shape": "box", "loot_table": "lt_wolf_rider", "gold_min": 20, "gold_max": 40, "model": "mob_wolf_rider",
		 "skill_ids": ["mob_pounce"] as Array[String]},
		{"id": "wolf_raider", "name": "Saqueador Goblin", "level": 35, "stat_role": "comum", "unit_mods": {"hp": 1.95, "atk": 1.05}, "faction": H,
		 "move_speed": 6.0, "attack_range": 2.0, "attack_cooldown": 1.1, "attack_startup": 0.3, "xp": 440, "aggro_range": 11.0, "leash_range": 24.0,
		 "radius": 0.62, "scale": 1.05, "color": Color(0.42, 0.38, 0.34), "shape": "box", "loot_table": "lt_wolf_rider", "gold_min": 28, "gold_max": 56, "model": "mob_wolf_raider",
		 "skill_ids": ["mob_net_throw", "mob_pounce"] as Array[String], "escort": {"id": "wolf_rider", "count": 2}},
		# Orcs: Recruta (corpo a corpo pesado; Guerreiro e Senhor da Guerra entram aos 37/42)
		{"id": "orc_recruit", "name": "Recruta Orc", "level": 32, "stat_role": "bruto", "unit_mods": {"hp": 1.1, "atk": 1.4}, "faction": H,
		 "move_speed": 4.4, "attack_range": 2.0, "attack_cooldown": 1.3, "attack_startup": 0.4, "xp": 360, "aggro_range": 8.0,
		 "radius": 0.55, "scale": 1.15, "color": Color(0.45, 0.55, 0.38), "shape": "capsule", "loot_table": "lt_orc", "gold_min": 24, "gold_max": 48, "model": "mob_orc_recruit",
		 "skill_ids": ["mob_orc_chop"] as Array[String]},
		# Nagas (Costa): puxam para a beira d'água, golpe em linha
		{"id": "naga_tide", "name": "Naga das Marés", "level": 31, "stat_role": "comum", "unit_mods": {"hp": 1.35, "atk": 1.3}, "matk_mult": 1.0,
		 "move_speed": 4.6, "attack_range": 2.2, "attack_cooldown": 1.2, "attack_startup": 0.35, "xp": 300, "aggro_range": 10.0,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.3, 0.75, 0.7), "shape": "capsule", "loot_table": "lt_naga", "gold_min": 20, "gold_max": 40, "model": "mob_naga_tide",
		 "skill_ids": ["mob_tide_pull"] as Array[String]},
		{"id": "naga_warrior", "name": "Guerreira Naga", "level": 34, "stat_role": "bruto", "unit_mods": {"hp": 1.3, "atk": 0.9}, "matk_mult": 0.8,
		 "move_speed": 4.6, "attack_range": 2.4, "attack_cooldown": 1.2, "attack_startup": 0.35, "xp": 460, "aggro_range": 10.0, "leash_range": 22.0,
		 "radius": 0.55, "scale": 1.15, "color": Color(0.25, 0.65, 0.62), "shape": "capsule", "loot_table": "lt_naga", "gold_min": 28, "gold_max": 56, "model": "mob_naga_warrior",
		 "skill_ids": ["mob_tide_pull", "mob_tide_lance"] as Array[String], "escort": {"id": "naga_tide", "count": 2}},
		# ---- chefes da faixa 30-35 ----
		{"id": "boss_tide_mother", "name": "Mãe das Marés", "level": 33, "stat_role": "chefe", "unit_mods": {"hp": 1.65, "atk": 1.5}, "matk_mult": 0.9,
		 "move_speed": 4.4, "attack_range": 2.8, "attack_cooldown": 1.3, "attack_startup": 0.45, "xp": 3600, "aggro_range": 12.0, "leash_range": 30.0,
		 "radius": 0.9, "scale": 1.8, "color": Color(0.25, 0.7, 0.75), "shape": "capsule", "is_boss": true, "berserk_after": 180, "loot_table": "lt_tide_mother", "gold_min": 320, "gold_max": 520, "model": "mob_tide_mother",
		 "skill_ids": ["mob_call_brood", "mob_tide_lance", "mob_tide_pull", "mob_tide_wave", "mob_tide_flood"] as Array[String], "coin_chance": 1.0, "coin_min": 5, "coin_max": 7,
		 "intro": "A maré sempre volta. E sempre leva alguém.", "last_words": "O mar... me chama... de volta...",
		 "phases": [{"hp": 0.7, "say": "Filhos da espuma, subam!", "summon": {"id": "naga_spawn", "count": 3, "max": 4}},
			{"hp": 0.4, "say": "A maré me cobre!", "skills": ["mob_tide_geysers"], "ward": 0.5, "summon": {"id": "naga_spawn", "count": 2, "max": 4, "pick": "far"}},
			{"hp": 0.15, "say": "Afoguem-se todos!", "enrage": 1.3}]},
		{"id": "boss_agitator_lord", "name": "Agitador-Mor Grukk", "level": 36, "stat_role": "chefe", "unit_mods": {"hp": 1.8, "atk": 1.25}, "faction": H, "aura": "agitator_boss",
		 "move_speed": 4.6, "attack_range": 2.6, "attack_cooldown": 1.2, "attack_startup": 0.4, "xp": 4200, "aggro_range": 12.0, "leash_range": 30.0,
		 "radius": 0.8, "scale": 1.7, "color": Color(0.65, 0.28, 0.2), "shape": "capsule", "is_boss": true, "berserk_after": 180, "loot_table": "lt_agitator_lord", "gold_min": 380, "gold_max": 620, "model": "mob_agitator_lord",
		 "skill_ids": ["mob_call_rabble", "mob_impale", "mob_net_throw", "mob_war_drum"] as Array[String], "coin_chance": 1.0, "coin_min": 5, "coin_max": 8,
		 "escort": {"id": "goblin_impaler", "count": 2},
		 "intro": "Ouçam o tambor! Cada batida é um de vocês caindo!", "last_words": "O tambor... para...",
		 "phases": [{"hp": 0.7, "say": "Turba! Para cima deles!", "skills": ["mob_drum_frenzy"], "summon": {"id": "goblin_rabble", "count": 3, "max": 5}},
			{"hp": 0.4, "say": "Escudem o chefe, vermes!", "skills": ["mob_spear_rain"], "ward": 0.5, "summon": {"id": "goblin_rabble", "count": 2, "max": 5, "pick": "soft"}},
			{"hp": 0.15, "say": "MAIS FORTE! MAIS RÁPIDO!", "enrage": 1.3}]},
		# ---- Ato II, Estepes de Cinza (35-40; R3): trolls (regeneram: F3), arqueiros (chuva de flechas de fogo) e o Guerreiro Orc ----
		{"id": "troll_whelp", "name": "Trollzinho", "level": 35, "stat_role": "bruto", "unit_mods": {"hp": 1.3, "atk": 0.9}, "faction": H, "regen": 1.0,
		 "move_speed": 4.6, "attack_range": 2.1, "attack_cooldown": 1.3, "attack_startup": 0.4, "xp": 480, "aggro_range": 9.0,
		 "radius": 0.6, "scale": 1.25, "color": Color(0.5, 0.6, 0.72), "shape": "capsule", "loot_table": "lt_troll", "gold_min": 28, "gold_max": 56, "model": "mob_troll_whelp"},
		{"id": "troll", "name": "Troll", "level": 38, "stat_role": "bruto", "unit_mods": {"hp": 1.8}, "faction": H, "regen": 1.0,
		 "move_speed": 4.2, "attack_range": 2.5, "attack_cooldown": 1.5, "attack_startup": 0.5, "xp": 700, "aggro_range": 9.0, "leash_range": 22.0,
		 "radius": 0.8, "scale": 1.6, "color": Color(0.45, 0.55, 0.68), "shape": "capsule", "loot_table": "lt_troll_big", "gold_min": 40, "gold_max": 80, "model": "mob_troll",
		 "skill_ids": ["mob_troll_slam"] as Array[String], "escort": {"id": "troll_whelp", "count": 2}},
		{"id": "orc_archer", "name": "Arqueiro Orc", "level": 35, "stat_role": "comum", "unit_mods": {"hp": 1.1, "atk": 1.1}, "matk_mult": 0.5, "faction": H, "ranged": true,
		 "move_speed": 4.6, "attack_range": 9.0, "attack_cooldown": 1.6, "attack_startup": 0.4, "xp": 420, "aggro_range": 11.0,
		 "radius": 0.5, "scale": 1.1, "color": Color(0.5, 0.58, 0.36), "shape": "capsule", "loot_table": "lt_orc_archer", "gold_min": 26, "gold_max": 52, "model": "mob_orc_archer",
		 "skill_ids": ["mob_fire_arrows"] as Array[String]},
		{"id": "orc_crossbow", "name": "Besteiro Orc", "level": 38, "stat_role": "comum", "unit_mods": {"hp": 1.3, "atk": 1.35}, "matk_mult": 0.5, "faction": H, "ranged": true,
		 "move_speed": 4.4, "attack_range": 10.0, "attack_cooldown": 1.9, "attack_startup": 0.5, "xp": 560, "aggro_range": 12.0, "leash_range": 22.0,
		 "radius": 0.52, "scale": 1.15, "color": Color(0.46, 0.52, 0.34), "shape": "capsule", "loot_table": "lt_orc_archer", "gold_min": 34, "gold_max": 68, "model": "mob_orc_crossbow",
		 "skill_ids": ["mob_bolt_pierce", "mob_fire_arrows"] as Array[String], "escort": {"id": "orc_archer", "count": 2}},
		{"id": "orc_warrior", "name": "Guerreiro Orc", "level": 37, "stat_role": "bruto", "unit_mods": {"hp": 1.15}, "faction": H,
		 "move_speed": 4.5, "attack_range": 2.1, "attack_cooldown": 1.3, "attack_startup": 0.4, "xp": 600, "aggro_range": 9.0, "leash_range": 22.0,
		 "radius": 0.58, "scale": 1.25, "color": Color(0.42, 0.52, 0.36), "shape": "capsule", "loot_table": "lt_orc_warrior", "gold_min": 34, "gold_max": 68, "model": "mob_orc_warrior",
		 "skill_ids": ["mob_orc_chop", "mob_war_cry"] as Array[String], "escort": {"id": "orc_recruit", "count": 1}},
		# ---- chefes dos acampamentos das Estepes (35-40) ----
		{"id": "boss_troll_king", "name": "Troll Rei-da-Rocha", "level": 38, "stat_role": "chefe", "unit_mods": {"hp": 2.0, "atk": 1.35}, "faction": H, "regen": 0.3,
		 "move_speed": 4.2, "attack_range": 3.0, "attack_cooldown": 1.4, "attack_startup": 0.5, "xp": 4800, "aggro_range": 12.0, "leash_range": 30.0,
		 "radius": 1.0, "scale": 2.1, "color": Color(0.42, 0.5, 0.66), "shape": "capsule", "is_boss": true, "berserk_after": 180, "loot_table": "lt_troll_king", "gold_min": 420, "gold_max": 680, "model": "mob_troll_king",
		 "skill_ids": ["mob_call_trolls", "mob_troll_slam", "mob_boulder_barrage", "mob_boulder_toss", "mob_rock_quake"] as Array[String], "coin_chance": 1.0, "coin_min": 5, "coin_max": 8,
		 "escort": {"id": "troll_whelp", "count": 2},
		 "intro": "Pedra não sangra. Pedra não cansa. Pedra ESMAGA!", "last_words": "A rocha... racha...",
		 "cover": {"radius": 1.2, "time": 40.0, "skills": ["mob_boulder_barrage"]},
		 "phases": [{"hp": 0.7, "say": "Crias! Saiam da toca!", "skills": ["mob_troll_avalanche"], "summon": {"id": "troll_runt", "count": 2, "max": 3}},
			{"hp": 0.4, "say": "A carne fecha! A pedra cresce!", "skills": ["mob_rockfall"], "ward": 0.5, "summon": {"id": "troll_runt", "count": 2, "max": 3}},
			{"hp": 0.15, "say": "EU SOU A MONTANHA!", "enrage": 1.3}]},
		{"id": "boss_crossbow_master", "name": "Mestre Besteiro Vorgul", "level": 39, "stat_role": "chefe", "unit_mods": {"hp": 1.6, "atk": 0.9}, "matk_mult": 0.5, "faction": H,
		 "move_speed": 4.6, "attack_range": 2.8, "attack_cooldown": 1.3, "attack_startup": 0.45, "xp": 5000, "aggro_range": 13.0, "leash_range": 32.0,
		 "radius": 0.8, "scale": 1.7, "color": Color(0.5, 0.42, 0.3), "shape": "capsule", "is_boss": true, "berserk_after": 180, "loot_table": "lt_crossbow_master", "gold_min": 440, "gold_max": 700, "model": "mob_crossbow_master",
		 "skill_ids": ["mob_call_marksmen", "mob_fire_kegs", "mob_bolt_pierce", "mob_fire_rain", "mob_marksman_brand"] as Array[String], "coin_chance": 1.0, "coin_min": 5, "coin_max": 8,
		 "escort": {"id": "orc_archer", "count": 2},
		 "intro": "Fiquem bem aí. Parado queima melhor.", "last_words": "Errei... um só... tiro...",
		 "phases": [{"hp": 0.7, "say": "Atiradores, nos telhados!", "summon": {"id": "orc_marksman", "count": 2, "max": 3, "pick": "far"}},
			{"hp": 0.4, "say": "Acendam tudo! O céu é meu!", "skills": ["mob_fire_storm"], "ward": 0.5, "summon": {"id": "orc_marksman", "count": 2, "max": 3, "pick": "far"}},
			{"hp": 0.15, "say": "QUEIMEM COMIGO!", "enrage": 1.3}]},
		{"id": "boss_ghar", "name": "Senhor da Guerra Ghar", "level": 40, "stat_role": "chefe", "unit_mods": {"hp": 1.9, "atk": 1.3}, "faction": H,
		 "move_speed": 4.8, "attack_range": 2.9, "attack_cooldown": 1.3, "attack_startup": 0.45, "xp": 5600, "aggro_range": 12.0, "leash_range": 30.0,
		 "radius": 0.9, "scale": 1.85, "color": Color(0.4, 0.5, 0.32), "shape": "capsule", "is_boss": true, "berserk_after": 180, "loot_table": "lt_ghar", "gold_min": 480, "gold_max": 760, "model": "mob_ghar",
		 "skill_ids": ["mob_call_vanguard", "mob_charge", "mob_ghar_cleave", "mob_ghar_cry", "mob_ghar_wall"] as Array[String], "coin_chance": 1.0, "coin_min": 6, "coin_max": 9,
		 "escort": {"id": "orc_warrior", "count": 2},
		 "intro": "Três acampamentos, um só machado. Venham ver de quem é a estepe.", "last_words": "Kharzun... vai cobrar... por mim...",
		 "phases": [{"hp": 0.7, "say": "Vanguarda! Escudos à frente!", "summon": {"id": "orc_vanguard", "count": 2, "max": 4}},
			{"hp": 0.4, "say": "A Horda não recua!", "skills": ["mob_ghar_quake"], "ward": 0.5, "summon": {"id": "orc_vanguard", "count": 2, "max": 4, "pick": "soft"}},
			{"hp": 0.15, "say": "MORRAM DE PÉ!", "enrage": 1.35}]},
		# lacaios dos chefes das Estepes (0 XP)
		{"id": "troll_runt", "name": "Cria da Rocha", "level": 36, "hp": 1500, "atk": 62, "def": 30, "mdef": 14, "faction": H, "regen": 1.0, "move_speed": 4.8, "attack_range": 2.0, "attack_cooldown": 1.3, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0,
		 "radius": 0.5, "scale": 1.05, "color": Color(0.52, 0.62, 0.74), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_troll_whelp"},
		{"id": "orc_marksman", "name": "Atirador da Paliçada", "level": 37, "hp": 600, "atk": 36, "def": 14, "mdef": 12, "faction": H, "ranged": true, "move_speed": 4.6, "attack_range": 9.0, "attack_cooldown": 1.7, "attack_startup": 0.4, "xp": 0, "aggro_range": 16.0, "leash_range": 40.0,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.5, 0.58, 0.36), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_orc_archer"},
		{"id": "orc_vanguard", "name": "Vanguarda de Ghar", "level": 38, "hp": 1300, "atk": 72, "def": 34, "mdef": 14, "faction": H, "move_speed": 4.8, "attack_range": 2.0, "attack_cooldown": 1.2, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0,
		 "radius": 0.5, "scale": 1.1, "color": Color(0.42, 0.52, 0.36), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_orc_warrior"},
		# lacaios dos chefes (0 XP)
		{"id": "goblin_rabble", "name": "Turba Goblin", "level": 32, "hp": 520, "atk": 42, "def": 12, "mdef": 8, "faction": H, "move_speed": 5.2, "attack_range": 2.0, "attack_cooldown": 1.1, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0,
		 "radius": 0.38, "scale": 0.75, "color": Color(0.55, 0.62, 0.32), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_goblin_lancer"},
		{"id": "naga_spawn", "name": "Cria da Maré", "level": 31, "hp": 480, "atk": 40, "def": 10, "mdef": 10, "move_speed": 5.0, "attack_range": 1.8, "attack_cooldown": 1.1, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0,
		 "radius": 0.38, "scale": 0.75, "color": Color(0.35, 0.8, 0.75), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_naga_tide"},
	]

## Ato II, fase 3 — Monte Kharzun (40-45; design/gdd/kharzun-fase3-plan.md §3): estágios de cima das linhas da Horda
## (escolta dos de baixo), elites e os nativos da montanha. Números pela F2. Modelos próprios (WP4:
## tools/blender/kharzun_mobs.py), um por monstro, listados em KHARZUN_MODELS; `color` = a cor principal do modelo.
## Spawners ficam com o mapa (WP5); a band_probe duela os sem spawner numa arena de teste.
const KHARZUN_MODELS := {
	"goblin_assassin": "mob_goblin_assassin", "dire_wolf": "mob_dire_wolf", "dire_wolf_rider": "mob_dire_wolf_rider",
	"troll_thrower": "mob_troll_thrower", "orc_fire_archer": "mob_orc_fire_archer", "orc_warlord": "mob_orc_warlord",
	"goblin_slayer": "mob_goblin_slayer", "lava_salamander": "mob_lava_salamander", "troll_brute": "mob_troll_brute",
	"clan_guard": "mob_clan_guard", "basalt_golem": "mob_basalt_golem",
	# chefes, lacaios e estandartes (WP7)
	"boss_dire_mother": "mob_dire_mother", "boss_shazka": "mob_shazka", "boss_ulgra": "mob_ulgra",
	"boss_gorbash": "mob_gorbash", "boss_kragmar": "mob_kragmar", "boss_durgash": "mob_durgash",
	"banner_wolf": "mob_clan_banner_wolf", "banner_stone": "mob_clan_banner_stone", "banner_forge": "mob_clan_banner_forge",
	"dire_pup": "mob_dire_wolf", "shadow_apprentice": "mob_goblin_assassin", "ulgra_rider": "mob_dire_wolf_rider",
	"stone_shaman": "mob_stone_shaman", "forge_golemling": "mob_forge_golem", "throne_guard": "mob_clan_guard",
	"shazka_decoy": "mob_shazka"
}

static func _kharzun() -> Array:
	var H := "horde"
	return [
		# Assassinos: Assassino Goblin (aparece pelas costas, faca envenenada) → Matador (some na fumaça, executa quem cai)
		{"id": "goblin_assassin", "name": "Assassino Goblin", "level": 40, "stat_role": "comum", "unit_mods": {"hp": 1.15, "atk": 1.6}, "matk_mult": 0.5, "faction": H,
		 "move_speed": 5.6, "attack_range": 1.8, "attack_cooldown": 0.9, "attack_startup": 0.25, "xp": 820, "aggro_range": 10.0, "leash_range": 24.0,
		 "radius": 0.4, "scale": 0.85, "color": Color(0.25, 0.21, 0.32), "shape": "capsule", "loot_table": "lt_goblin_assassin", "gold_min": 44, "gold_max": 88, "model": "mob_goblin_assassin",
		 "skill_ids": ["mob_shadow_step", "mob_venom_knives"] as Array[String]},
		{"id": "goblin_slayer", "name": "Matador", "level": 43, "stat_role": "elite", "unit_mods": {"hp": 0.8, "atk": 2.0}, "matk_mult": 0.5, "faction": H,
		 "move_speed": 5.6, "attack_range": 2.0, "attack_cooldown": 0.95, "attack_startup": 0.3, "xp": 2400, "aggro_range": 11.0, "leash_range": 26.0,
		 "radius": 0.48, "scale": 1.15, "color": Color(0.16, 0.14, 0.18), "shape": "capsule", "loot_table": "lt_goblin_slayer", "gold_min": 110, "gold_max": 220, "model": "mob_goblin_slayer",
		 "skill_ids": ["mob_slayer_vanish", "mob_slayer_execute", "mob_shadow_step"] as Array[String], "escort": {"id": "goblin_assassin", "count": 2}},
		# Ginetes (topo): Ginete do Lobo Atroz — investida em linha + rede; lidera 2 Saqueadores
		{"id": "dire_wolf_rider", "name": "Ginete do Lobo Atroz", "level": 41, "stat_role": "bruto", "unit_mods": {"hp": 1.3, "atk": 1.0}, "faction": H,
		 "move_speed": 6.2, "attack_range": 2.2, "attack_cooldown": 1.2, "attack_startup": 0.4, "xp": 1000, "aggro_range": 12.0, "leash_range": 26.0,
		 "radius": 0.7, "scale": 1.15, "color": Color(0.3, 0.29, 0.31), "shape": "box", "loot_table": "lt_dire_wolf_rider", "gold_min": 52, "gold_max": 104, "model": "mob_dire_wolf_rider",
		 "skill_ids": ["mob_dire_charge", "mob_net_throw"] as Array[String], "escort": {"id": "wolf_raider", "count": 2}},
		# Trolls (topo A e B): Lança-Pedras (pedregulho de longe) e Brutamontes (armadura de ferro, abalo que atordoa)
		{"id": "troll_thrower", "name": "Lança-Pedras", "level": 41, "stat_role": "bruto", "unit_mods": {"hp": 1.15, "atk": 1.25}, "faction": H, "regen": 1.0, "ranged": true,
		 "move_speed": 4.2, "attack_range": 9.0, "attack_cooldown": 1.8, "attack_startup": 0.6, "xp": 1050, "aggro_range": 12.0, "leash_range": 24.0,
		 "radius": 0.75, "scale": 1.45, "color": Color(0.45, 0.55, 0.68), "shape": "capsule", "loot_table": "lt_troll_big", "gold_min": 52, "gold_max": 104, "model": "mob_troll_thrower",
		 "skill_ids": ["mob_boulder_toss", "mob_troll_slam"] as Array[String], "escort": {"id": "troll_whelp", "count": 2}},
		{"id": "troll_brute", "name": "Brutamontes", "level": 44, "stat_role": "bruto", "unit_mods": {"hp": 1.8, "atk": 1.05}, "faction": H, "regen": 1.0,
		 "move_speed": 4.0, "attack_range": 2.7, "attack_cooldown": 1.6, "attack_startup": 0.55, "xp": 1700, "aggro_range": 9.0, "leash_range": 24.0,
		 "radius": 0.9, "scale": 1.85, "color": Color(0.4, 0.48, 0.62), "shape": "capsule", "loot_table": "lt_troll_brute", "gold_min": 70, "gold_max": 140, "model": "mob_troll_brute",
		 "skill_ids": ["mob_troll_slam", "mob_brute_quake"] as Array[String], "escort": {"id": "troll", "count": 2}},
		# Arqueiros (topo): Arco de Fogo — três círculos de brasa; lidera 2 Besteiros
		{"id": "orc_fire_archer", "name": "Arco de Fogo", "level": 42, "stat_role": "comum", "unit_mods": {"hp": 1.4, "atk": 1.45}, "matk_mult": 0.5, "faction": H, "ranged": true,
		 "move_speed": 4.4, "attack_range": 10.0, "attack_cooldown": 1.8, "attack_startup": 0.5, "xp": 1150, "aggro_range": 12.0, "leash_range": 24.0,
		 "radius": 0.55, "scale": 1.2, "color": Color(0.36, 0.2, 0.14), "shape": "capsule", "loot_table": "lt_orc_fire_archer", "gold_min": 56, "gold_max": 112, "model": "mob_orc_fire_archer",
		 "skill_ids": ["mob_ember_volley", "mob_bolt_pierce"] as Array[String], "escort": {"id": "orc_crossbow", "count": 2}},
		# Orcs (topo): Senhor da Guerra — grito (rally) e talho largo; lidera 2 Guerreiros
		{"id": "orc_warlord", "name": "Senhor da Guerra", "level": 42, "stat_role": "elite", "unit_mods": {"hp": 1.3, "atk": 2.0}, "faction": H,
		 "move_speed": 4.6, "attack_range": 2.6, "attack_cooldown": 1.3, "attack_startup": 0.45, "xp": 2300, "aggro_range": 10.0, "leash_range": 26.0,
		 "radius": 0.7, "scale": 1.5, "color": Color(0.21, 0.2, 0.24), "shape": "capsule", "loot_table": "lt_orc_warlord", "gold_min": 110, "gold_max": 220, "model": "mob_orc_warlord",
		 "skill_ids": ["mob_war_cry", "mob_warlord_cleave"] as Array[String], "escort": {"id": "orc_warrior", "count": 2}},
		# cidadela: Guarda de Clã — escudo-torre (front_guard: golpe físico de frente perde metade)
		{"id": "clan_guard", "name": "Guarda de Clã", "level": 44, "stat_role": "elite", "unit_mods": {"hp": 0.85, "atk": 1.6}, "faction": H, "front_guard": 0.5,
		 "move_speed": 4.4, "attack_range": 2.3, "attack_cooldown": 1.3, "attack_startup": 0.45, "xp": 2500, "aggro_range": 9.0, "leash_range": 24.0,
		 "radius": 0.7, "scale": 1.4, "color": Color(0.5, 0.34, 0.2), "shape": "capsule", "loot_table": "lt_clan_guard", "gold_min": 120, "gold_max": 240, "model": "mob_clan_guard",
		 "skill_ids": ["mob_shield_bash", "mob_orc_chop"] as Array[String]},
		# nativos da montanha: Lobo Atroz (matilha de 3 pelo spawner), Salamandra de Lava (não queima), Golem de Basalto (elite rara)
		{"id": "dire_wolf", "name": "Lobo Atroz", "level": 40, "stat_role": "comum", "unit_mods": {"hp": 1.2, "atk": 1.3},
		 "move_speed": 6.0, "attack_range": 1.9, "attack_cooldown": 1.0, "attack_startup": 0.3, "xp": 820, "aggro_range": 11.0, "leash_range": 24.0,
		 "radius": 0.6, "scale": 1.3, "color": Color(0.44, 0.44, 0.48), "shape": "box", "loot_table": "lt_dire_wolf", "gold_min": 30, "gold_max": 60, "model": "mob_dire_wolf",
		 "skill_ids": ["mob_pounce", "mob_dire_charge"] as Array[String]},
		{"id": "lava_salamander", "name": "Salamandra de Lava", "level": 43, "stat_role": "comum", "unit_mods": {"hp": 1.45, "atk": 1.4}, "matk_mult": 1.0, "burn_immune": true,
		 "move_speed": 4.6, "attack_range": 2.0, "attack_cooldown": 1.2, "attack_startup": 0.35, "xp": 1250, "aggro_range": 10.0, "leash_range": 22.0,
		 "radius": 0.55, "scale": 1.1, "color": Color(1.0, 0.45, 0.15), "shape": "capsule", "loot_table": "lt_lava_salamander", "gold_min": 50, "gold_max": 100, "model": "mob_lava_salamander",
		 "skill_ids": ["mob_lava_spit"] as Array[String]},
		{"id": "basalt_golem", "name": "Golem de Basalto", "level": 45, "stat_role": "elite", "unit_mods": {"hp": 1.7, "atk": 2.0}, "matk_mult": 0.5,
		 "move_speed": 3.0, "attack_range": 2.8, "attack_cooldown": 1.9, "attack_startup": 0.6, "xp": 3000, "aggro_range": 8.0, "leash_range": 22.0,
		 "radius": 1.0, "scale": 1.6, "color": Color(0.23, 0.22, 0.26), "shape": "capsule", "loot_table": "lt_basalt_golem", "gold_min": 140, "gold_max": 280, "model": "mob_basalt_golem",
		 "skill_ids": ["mob_basalt_stomp", "mob_lava_crack"] as Array[String]},
	]

## Ato II fase 3, Monte Kharzun (40-45; design/gdd/kharzun-fase3-plan.md §4): seis chefes. Modelos próprios do WP4
## (tools/blender/kharzun_mobs.py), listados em KHARZUN_MODELS. Falas = placeholder
## até o narrative-director. Lacaios são do chefe (0 XP, sem loot), não do rol do WP3.
const KHARZUN_BOSSES := ["boss_dire_mother", "boss_shazka", "boss_ulgra", "boss_gorbash", "boss_kragmar", "boss_durgash"]
## Estandartes de Clã do Durgash (F2): lacaios parados; o ward vale enquanto um vive.
const KHARZUN_BANNERS := ["banner_wolf", "banner_stone", "banner_forge"]
## id -> modelo pretendido (WP4: act2_bosses.boss_extras / prop do estandarte). Hoje `model` aponta um substituto.

static func _kharzun_bosses() -> Array:
	var H := "horde"
	return [
		# ---- Presa-de-Cinza, a Mãe-Loba (Canil, 41; chefe de GRUPO desde 2026-11-17) ----
		# hp 0,6 -> 1,85 (2026-11-16): com 0,6 o grupo de 4-5 do 41 a derrubava em ~10 s (pares da faixa 30-50 s).
		# 2026-11-17 (decisão do autor): virou chefe de grupo como Ghar/Troll Rei: 3 fases, ward das Crias, berserk 120 s, prêmio do Ghar.
		# Faixa grupo (40 lutas): atk 0,7 -> 1,1 e golpe a cada 1,0 s (era 1,2; act 33 -> 43%): solo 38%, trio 80% em 49 s
		{"id": "boss_dire_mother", "name": "Presa-de-Cinza, a Mãe-Loba", "level": 41, "stat_role": "chefe", "unit_mods": {"hp": 1.85, "atk": 1.1},
		 "move_speed": 5.6, "attack_range": 2.6, "attack_cooldown": 1.0, "attack_startup": 0.35, "xp": 5800, "aggro_range": 12.0, "leash_range": 28.0,
		 "radius": 0.9, "scale": 1.7, "color": Color(0.42, 0.4, 0.4), "shape": "box", "is_boss": true, "berserk_after": 120, "loot_table": "lt_dire_mother", "gold_min": 480, "gold_max": 760, "model": "mob_dire_mother",
		 "skill_ids": ["mob_dire_leap", "mob_dire_bite"] as Array[String], "coin_chance": 1.0, "coin_min": 6, "coin_max": 9,
		 "intro": "(a loba cinzenta arreganha os dentes e o canil inteiro uiva junto)", "last_words": "(um último uivo, longo, para a montanha)",
		 "phases": [{"hp": 0.7, "say": "(Presa-de-Cinza uiva: a matilha responde!)", "skills": ["mob_dire_howl", "mob_dire_pounce"], "summon": {"id": "dire_pup", "count": 2, "max": 3}},
			{"hp": 0.4, "say": "(as Crias cercam a mãe, rosnando)", "ward": 0.5, "summon": {"id": "dire_pup", "count": 2, "max": 3, "pick": "soft"}},
			{"hp": 0.15, "say": "(a Mãe-Loba se eriça, os olhos em brasa)", "enrage": 1.3}]},
		# ---- Mestre Matador Shazka (dg_slayers, 43): protege quem cura ----
		{"id": "boss_shazka", "name": "Mestre Matador Shazka", "level": 43, "stat_role": "chefe", "unit_mods": {"hp": 1.8, "atk": 0.95}, "faction": H,
		 "move_speed": 5.4, "attack_range": 2.4, "attack_cooldown": 1.0, "attack_startup": 0.3, "xp": 6400, "aggro_range": 12.0, "leash_range": 30.0,
		 "radius": 0.7, "scale": 1.5, "color": Color(0.28, 0.24, 0.34), "shape": "capsule", "is_boss": true, "berserk_after": 210, "loot_table": "lt_shazka", "gold_min": 520, "gold_max": 820, "model": "mob_shazka",
		 "skill_ids": ["mob_shazka_knife"] as Array[String], "coin_chance": 1.0, "coin_min": 6, "coin_max": 9,
		 "intro": "Vocês protegem o curandeiro? Eu ensinei cem alunos a achar as costas dele.", "last_words": "Bom... aluno...",
		 "phases": [{"hp": 0.7, "say": "Aprendizes! Mostrem o que eu ensinei!", "skills": ["mob_call_apprentices", "mob_shazka_vanish", "mob_shazka_step", "mob_shazka_twins"], "ward": 0.5, "summon": {"id": "shadow_apprentice", "count": 2, "max": 2, "pick": "soft"}},
			{"hp": 0.35, "say": "Respirem fundo. É o último ar que vocês têm.", "skills": ["mob_shazka_venom_rain", "mob_shazka_mercy"]},
			{"hp": 0.15, "say": "SEM PRESSA. SEM PIEDADE.", "enrage": 1.3}]},
		# ---- três Chefes de Clã (cidadela, 44; qualquer ordem) ----
		{"id": "boss_ulgra", "name": "Ulgra Presa-Atroz", "level": 44, "stat_role": "chefe", "unit_mods": {"hp": 1.85, "atk": 1.15}, "faction": H,
		 "move_speed": 6.0, "attack_range": 2.8, "attack_cooldown": 1.2, "attack_startup": 0.4, "xp": 6800, "aggro_range": 12.0, "leash_range": 32.0,
		 "radius": 0.9, "scale": 1.35, "color": Color(0.5, 0.42, 0.36), "shape": "box", "is_boss": true, "berserk_after": 210, "loot_table": "lt_ulgra", "gold_min": 560, "gold_max": 860, "model": "mob_ulgra",
		 "skill_ids": ["mob_ulgra_charge", "mob_ulgra_chain"] as Array[String], "coin_chance": 1.0, "coin_min": 6, "coin_max": 9,
		 "intro": "O Clã do Lobo não espera. O Clã do Lobo CAÇA.", "last_words": "Corra... minha matilha... corra...",
		 "phases": [{"hp": 0.7, "say": "Ginetes! Cerquem a presa!", "skills": ["mob_call_riders", "mob_ulgra_stampede"], "summon": {"id": "ulgra_rider", "count": 2, "max": 3}},
			{"hp": 0.4, "say": "A matilha me cobre!", "ward": 0.5, "summon": {"id": "ulgra_rider", "count": 2, "max": 3, "pick": "far"}},
			{"hp": 0.15, "say": "LANÇAS! TODAS!", "skills": ["mob_ulgra_spears"], "enrage": 1.3}]},
		{"id": "boss_gorbash", "name": "Gorbash Pele-de-Rocha", "level": 44, "stat_role": "chefe", "unit_mods": {"hp": 1.85, "atk": 1.3}, "faction": H, "regen": 0.3,
		 "move_speed": 4.2, "attack_range": 3.0, "attack_cooldown": 1.4, "attack_startup": 0.5, "xp": 6800, "aggro_range": 12.0, "leash_range": 30.0,
		 "radius": 1.0, "scale": 2.2, "color": Color(0.38, 0.44, 0.52), "shape": "capsule", "is_boss": true, "berserk_after": 210, "loot_table": "lt_gorbash", "gold_min": 560, "gold_max": 860, "model": "mob_gorbash",
		 "skill_ids": ["mob_troll_slam", "mob_boulder_toss"] as Array[String], "coin_chance": 1.0, "coin_min": 6, "coin_max": 9,
		 "intro": "O Rei-da-Rocha era meu filho. Eu sou a pedra de onde ele saiu.", "last_words": "A montanha... fica... sem mim...",
		 "phases": [{"hp": 0.7, "say": "Xamãs! Cantem para a pedra!", "skills": ["mob_call_shamans", "mob_gorbash_waves"], "ward": 0.5, "summon": {"id": "stone_shaman", "count": 2, "max": 2}},
			{"hp": 0.4, "say": "O teto é meu também!", "skills": ["mob_rock_quake", "mob_rockfall"]},
			{"hp": 0.15, "say": "PEDRA NÃO MORRE!", "enrage": 1.3}]},
		{"id": "boss_kragmar", "name": "Kragmar Martelo-Negro", "level": 44, "stat_role": "chefe", "unit_mods": {"hp": 1.7, "atk": 1.25}, "faction": H,
		 "move_speed": 4.4, "attack_range": 3.0, "attack_cooldown": 1.4, "attack_startup": 0.5, "xp": 6800, "aggro_range": 12.0, "leash_range": 30.0,
		 "radius": 0.95, "scale": 1.85, "color": Color(0.3, 0.26, 0.24), "shape": "capsule", "is_boss": true, "berserk_after": 150, "loot_table": "lt_kragmar", "gold_min": 560, "gold_max": 860, "model": "mob_kragmar",
		 "skill_ids": ["mob_kragmar_hammer", "mob_lava_waves", "mob_kragmar_temper"] as Array[String], "coin_chance": 1.0, "coin_min": 6, "coin_max": 9,
		 "intro": "Esta forja fez cada machado da Horda. Hoje ela faz vocês em cinza.", "last_words": "O fogo... apaga...",
		 "phases": [{"hp": 0.7, "say": "Golens! Saiam do molde!", "skills": ["mob_call_forge_golems"], "summon": {"id": "forge_golemling", "count": 2, "max": 3}},
			{"hp": 0.4, "say": "Abram as comportas!", "ward": 0.4, "summon": {"id": "forge_golemling", "count": 2, "max": 3, "pick": "soft"}},
			{"hp": 0.15, "say": "A FORJA SUPERAQUECE!", "enrage": 1.35}]},
		# ---- Durgash, o Grão-Senhor da Guerra (trono, 45; RAIDE DE 5: afinado com --party=5) ----
		# F2: três fases no mesmo limiar fincam um estandarte cada (MobSystem entra em todas as fases abaixo do HP de uma vez).
		{"id": "boss_durgash", "name": "Durgash, o Grão-Senhor da Guerra", "level": 45, "stat_role": "chefe", "unit_mods": {"hp": 4.3, "atk": 1.0}, "faction": H,
		 "move_speed": 4.8, "attack_range": 3.0, "attack_cooldown": 1.3, "attack_startup": 0.45, "xp": 9000, "aggro_range": 12.0, "leash_range": 34.0,
		 "radius": 1.0, "scale": 2.1, "color": Color(0.34, 0.4, 0.28), "shape": "capsule", "is_boss": true, "berserk_after": 128, "berserk_mult": 20.0, "loot_table": "lt_durgash", "gold_min": 900, "gold_max": 1400, "model": "mob_durgash",
		 "skill_ids": ["mob_durgash_cleave", "mob_durgash_charge", "mob_durgash_axe", "mob_durgash_cry", "mob_durgash_throneaxe"] as Array[String], "coin_chance": 1.0, "coin_min": 8, "coin_max": 12,
		 "intro": "Ghar, Grukk, Vorgul... todos caíram para vocês chegarem aqui. Então venham. A montanha é o meu trono.", "last_words": "A Horda... se ajoelha... mas não esquece...",
		 "phases": [{"hp": 0.7, "say": "Clãs! Fincem os estandartes!", "ward": 0.6, "summon": {"id": "banner_wolf", "count": 1, "max": 1}},
			{"hp": 0.7, "summon": {"id": "banner_stone", "count": 1, "max": 2}},
			{"hp": 0.7, "summon": {"id": "banner_forge", "count": 1, "max": 3}},
			{"hp": 0.4, "say": "Guarda do Trono! A mim!", "skills": ["mob_durgash_chain", "mob_durgash_quake", "mob_call_throne_guard"], "ward": 0.3},
			{"hp": 0.15, "say": "EU SOU A HORDA!", "enrage": 1.35}]},
		# ---- lacaios dos chefes de Kharzun (0 XP, sem loot) ----
		# Cópia do Shazka (Sombras Gêmeas, R-F): mesmo nome, modelo e vida dele; morre com 1 golpe; dano = Balance.SHAZKA_DECOY_DMG
		{"id": "shazka_decoy", "name": "Mestre Matador Shazka", "level": 43, "stat_role": "chefe", "unit_mods": {"hp": 1.8, "atk": 0.95}, "faction": H, "decoy": true,
		 "move_speed": 5.4, "attack_range": 2.4, "attack_cooldown": 1.0, "attack_startup": 0.3, "xp": 0, "aggro_range": 16.0, "leash_range": 40.0,
		 "radius": 0.7, "scale": 1.5, "color": Color(0.28, 0.24, 0.34), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_shazka"},
		{"id": "dire_pup", "name": "Cria de Presa-de-Cinza", "level": 40, "hp": 2600, "atk": 82, "def": 28, "mdef": 16, "move_speed": 6.0, "attack_range": 1.9, "attack_cooldown": 1.0, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0,
		 "radius": 0.5, "scale": 0.95, "color": Color(0.5, 0.48, 0.47), "shape": "box", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_dire_wolf"},
		{"id": "shadow_apprentice", "name": "Sombra-Aprendiz", "level": 42, "hp": 3200, "atk": 80, "def": 22, "mdef": 18, "faction": H, "move_speed": 5.8, "attack_range": 2.0, "attack_cooldown": 1.0, "attack_startup": 0.3, "xp": 0, "aggro_range": 16.0, "leash_range": 40.0,
		 "radius": 0.42, "scale": 0.9, "color": Color(0.3, 0.26, 0.38), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_goblin_assassin"},
		{"id": "ulgra_rider", "name": "Ginete de Ulgra", "level": 43, "hp": 3800, "atk": 100, "def": 30, "mdef": 18, "faction": H, "move_speed": 6.2, "attack_range": 2.0, "attack_cooldown": 1.1, "attack_startup": 0.3, "xp": 0, "aggro_range": 16.0, "leash_range": 40.0,
		 "radius": 0.6, "scale": 1.05, "color": Color(0.46, 0.42, 0.38), "shape": "box", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_dire_wolf_rider",
		 "skill_ids": ["mob_pounce"] as Array[String]},
		{"id": "stone_shaman", "name": "Xamã-Pedra", "level": 43, "hp": 3400, "atk": 70, "matk": 50, "def": 24, "mdef": 30, "faction": H, "ranged": true, "move_speed": 4.4, "attack_range": 9.0, "attack_cooldown": 1.8, "attack_startup": 0.45, "xp": 0, "aggro_range": 16.0, "leash_range": 40.0,
		 "radius": 0.5, "scale": 1.1, "color": Color(0.5, 0.62, 0.6), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_stone_shaman",
		 "skill_ids": ["mob_stone_mend"] as Array[String]},
		{"id": "forge_golemling", "name": "Golem de Forja", "level": 43, "hp": 4400, "atk": 92, "def": 44, "mdef": 20, "faction": H, "move_speed": 4.4, "attack_range": 2.0, "attack_cooldown": 1.4, "attack_startup": 0.45, "xp": 0, "aggro_range": 16.0, "leash_range": 40.0,
		 "radius": 0.55, "scale": 0.85, "color": Color(0.85, 0.42, 0.18), "shape": "box", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_forge_golem"},
		{"id": "throne_guard", "name": "Guarda do Trono", "level": 44, "hp": 6400, "atk": 118, "def": 52, "mdef": 26, "faction": H, "front_guard": 0.4, "move_speed": 4.6, "attack_range": 2.2, "attack_cooldown": 1.3, "attack_startup": 0.4, "xp": 0, "aggro_range": 16.0, "leash_range": 40.0,
		 "radius": 0.6, "scale": 1.3, "color": Color(0.36, 0.42, 0.3), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_clan_guard"},
		# Estandartes de Clã (parados: velocidade 0, não golpeiam; a vida é ~4% da do Durgash)
		{"id": "banner_wolf", "name": "Estandarte do Clã do Lobo", "level": 45, "hp": 21300, "atk": 1, "def": 40, "mdef": 36, "faction": H, "aura": "clan_wolf", "move_speed": 0.0, "attack_range": 0.5, "attack_cooldown": 999.0, "xp": 0, "aggro_range": 30.0, "leash_range": 60.0,
		 "radius": 0.6, "scale": 1.6, "color": Color(0.55, 0.5, 0.45), "shape": "cone", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_clan_banner_wolf"},
		{"id": "banner_stone", "name": "Estandarte do Clã da Pedra", "level": 45, "hp": 21300, "atk": 1, "matk": 900, "def": 40, "mdef": 36, "faction": H, "move_speed": 0.0, "attack_range": 0.5, "attack_cooldown": 999.0, "xp": 0, "aggro_range": 30.0, "leash_range": 60.0,
		 "radius": 0.6, "scale": 1.6, "color": Color(0.45, 0.55, 0.62), "shape": "cone", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_clan_banner_stone",
		 "skill_ids": ["mob_stone_mend"] as Array[String]},
		{"id": "banner_forge", "name": "Estandarte do Clã da Forja", "level": 45, "hp": 21300, "atk": 1, "matk": 160, "def": 40, "mdef": 36, "faction": H, "move_speed": 0.0, "attack_range": 0.5, "attack_cooldown": 999.0, "xp": 0, "aggro_range": 30.0, "leash_range": 60.0,
		 "radius": 0.6, "scale": 1.6, "color": Color(0.9, 0.45, 0.15), "shape": "cone", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_clan_banner_forge",
		 "skill_ids": ["mob_forge_embers"] as Array[String]},
	]

## Ato III, parte 1 — o Excesso (45-50; design/gdd/ato3-excesso-45-50.md §3, WP3). Sete famílias: Foliões (humanos),
## Bailarinos do Véu, Galgos de Seda, Coro Ferido, Reflexos (demônios), Incensários e Vinhas (nativos do field_perfume).
## Números pela F2 (`stat_role` + `unit_mods`); os demônios (`"demon": true`, só no catálogo) ganham Balance.ACT3_DEMON_MODS
## por cima (`_act3_mods`). Sem esquiva de monstro (D4 = b): "esquivo" = bote/salto (dash), furtividade curta, golpes em
## sequência (strikes), atirador que recua (kite) e ritmo rápido. Spawners ficam com os mapas (WP5); a band_probe duela na arena.
## Modelos: `model` = substituto que existe hoje; ACT3_MODELS = modelo pretendido (WP7, tools/blender). Escoltas = bando do §3.
const ACT3_MODELS := {
	"masked_reveler": "mob_reveler", "convert": "mob_convert", "convert_dancer": "mob_veil_dancer", "convert_hound": "mob_silk_hound",
	"ceremony_master": "mob_ceremony_master", "veil_dancer": "mob_veil_dancer", "first_dancer": "mob_first_dancer",
	"silk_hound": "mob_silk_hound", "parade_alpha": "mob_parade_alpha", "chorister": "mob_chorister", "choir_maestro": "mob_choir_maestro",
	"vain_reflection": "mob_vain_reflection", "living_censer": "mob_living_censer", "thirsty_vine": "mob_thirsty_vine",
	"seductress": "mob_seductress", "flayer": "mob_flayer", "veil_singer": "mob_veil_singer", "thirst_matriarch": "mob_thirst_matriarch",
	# lacaios dos chefes (WP8 usa nas fases; 0 XP, sem saque)
	"vine_sprout": "mob_thirsty_vine", "reveler_guest": "mob_reveler", "chorister_echo": "mob_chorister", "dancer_escort": "mob_first_dancer",
	"organ_pipe": "mob_organ_pipe", "standing_mirror": "mob_standing_mirror",
	"sense_sight": "mob_sense_pedestal_sight", "sense_hearing": "mob_sense_pedestal_hearing", "sense_smell": "mob_sense_pedestal_smell", "sense_taste": "mob_sense_pedestal_taste",
}
## Monstros da faixa (com XP) e os lacaios dos chefes, para o check e a sonda.
const ACT3_MOBS := ["masked_reveler", "convert", "ceremony_master", "veil_dancer", "first_dancer", "silk_hound", "parade_alpha",
	"chorister", "choir_maestro", "vain_reflection", "living_censer", "thirsty_vine"]
const ACT3_DEMONS := ["veil_dancer", "first_dancer", "silk_hound", "parade_alpha", "chorister", "choir_maestro", "vain_reflection",
	"convert_dancer", "convert_hound", "seductress", "flayer", "veil_singer", "thirst_matriarch"]
const ACT3_ADDS := ["vine_sprout", "reveler_guest", "chorister_echo", "dancer_escort", "organ_pipe", "standing_mirror",
	"sense_sight", "sense_hearing", "sense_smell", "sense_taste"]
## Veladas (§3.1): monstro -> modelo final (feito pelo blender-modeler) e o substituto de hoje. `thirst_model` escolhe
## sozinho: com o GLB final em assets/models usa ele, senão o substituto (nada a trocar quando o modelo chegar).
const ACT3_THIRST := ["seductress", "flayer", "veil_singer", "thirst_matriarch"]
const THIRST_STANDIN := {"seductress": "mob_elf_fighter", "flayer": "mob_elf_warrior", "veil_singer": "mob_elf_mage", "thirst_matriarch": "mob_elf_warden"}

static func thirst_model(id: String) -> String:
	var want: String = ACT3_MODELS[id]
	return want if ResourceLoader.exists("res://assets/models/%s.glb" % want) else str(THIRST_STANDIN[id])

## mod_unidade final do Ato III: o do monstro × o de demônio (se for), com piso Balance.ACT3_MOD_FLOOR; ritmo do golpe
## básico do demônio × ACT3_DEMON_MODS.cooldown (o fator 40+ da F2 entra depois, no _f2).
static func _act3_mods(d: Dictionary) -> Dictionary:
	var mods: Dictionary = (d.get("unit_mods", {}) as Dictionary).duplicate()
	if d.get("demon", false):
		for k in ["hp", "atk"]:
			mods[k] = maxf(Balance.ACT3_MOD_FLOOR, snappedf(float(mods.get(k, 1.0)) * float(Balance.ACT3_DEMON_MODS[k]), 0.001))
		d["attack_cooldown"] = snappedf(float(d.get("attack_cooldown", 1.4)) * float(Balance.ACT3_DEMON_MODS["cooldown"]), 0.01)
	d.erase("demon")
	if not mods.is_empty():
		d["unit_mods"] = mods
	return d

static func _act3() -> Array:
	var F := Balance.ACT3_FACTION
	var L := [
		# ---- Foliões (humanos): Folião Mascarado (básico rápido + taça) → Convertido (vira demônio) → Mestre de Cerimônias (aura) ----
		{"id": "masked_reveler", "name": "Folião Mascarado", "level": 45, "stat_role": "comum", "unit_mods": {"hp": 1.0, "atk": 1.2}, "faction": F,
		 "move_speed": 5.0, "attack_range": 2.0, "attack_cooldown": 1.1 * Balance.ACT3_REVELER_COOLDOWN, "attack_startup": 0.3, "xp": 1300, "aggro_range": 10.0, "leash_range": 24.0,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.5, 0.12, 0.2), "shape": "capsule", "loot_table": "lt_reveler", "gold_min": 60, "gold_max": 120, "model": "mob_reveler",
		 "skill_ids": ["mob_goblet_throw"] as Array[String]},
		# Convertido: ao ganhar alvo vira Bailarino (peso 2) ou Galgo (peso 1); XP/saque/quest pela base (ShiftSystem)
		{"id": "convert", "name": "Convertido", "level": 47, "stat_role": "comum", "unit_mods": {"hp": 1.0, "atk": 1.15}, "faction": F,
		 "move_speed": 4.8, "attack_range": 2.0, "attack_cooldown": 1.2, "attack_startup": 0.35, "xp": 1450, "aggro_range": 10.0, "leash_range": 24.0,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.85, 0.7, 0.72), "shape": "capsule", "loot_table": "lt_convert", "gold_min": 66, "gold_max": 132, "model": "mob_convert",
		 "shift_forms": [{"form": "convert_dancer", "weight": 2}, {"form": "convert_hound", "weight": 1}], "shift_cast": Balance.ACT3_CONVERT_SHIFT_CAST},
		{"id": "convert_dancer", "name": "Bailarino", "level": 47, "stat_role": "comum", "unit_mods": {"hp": 1.0, "atk": 1.3}, "demon": true, "faction": F,
		 "move_speed": 5.6, "attack_range": 2.0, "attack_cooldown": 1.1, "attack_startup": 0.28, "xp": 0, "aggro_range": 10.0, "leash_range": 24.0,
		 "radius": 0.42, "scale": 1.05, "color": Color(0.94, 0.88, 0.84), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_veil_dancer",
		 "skill_ids": ["mob_fan_leap", "mob_fan_strikes"] as Array[String]},
		{"id": "convert_hound", "name": "Galgo", "level": 47, "stat_role": "comum", "unit_mods": {"hp": 0.95, "atk": 1.35}, "demon": true, "faction": F, "shift_stealth": true,
		 "move_speed": 6.5, "attack_range": 1.8, "attack_cooldown": 1.0, "attack_startup": 0.25, "xp": 0, "aggro_range": 10.0, "leash_range": 24.0,
		 "radius": 0.5, "scale": 1.0, "color": Color(0.92, 0.88, 0.8), "shape": "box", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_silk_hound",
		 "skill_ids": ["mob_silk_bite", "mob_silk_lunge"] as Array[String]},
		{"id": "ceremony_master", "name": "Mestre de Cerimônias", "level": 47, "stat_role": "elite", "unit_mods": {"hp": 1.6, "atk": 1.5}, "faction": F, "aura": "festim",
		 "move_speed": 4.4, "attack_range": 2.4, "attack_cooldown": 1.3, "attack_startup": 0.45, "xp": 3200, "aggro_range": 10.0, "leash_range": 26.0,
		 "radius": 0.7, "scale": 1.25, "color": Color(0.45, 0.1, 0.18), "shape": "capsule", "loot_table": "lt_ceremony_master", "gold_min": 150, "gold_max": 300, "model": "mob_ceremony_master",
		 "skill_ids": ["mob_bell_staff", "mob_toast_rally"] as Array[String], "escort": {"id": "masked_reveler", "count": 3}},
		# ---- Bailarinos do Véu (demônios): três talhos + Salto Leque; o Primeiro Bailarino lidera 2 ----
		{"id": "veil_dancer", "name": "Bailarino do Véu", "level": 46, "stat_role": "comum", "unit_mods": {"hp": 1.0, "atk": 1.0}, "demon": true, "faction": F,
		 "move_speed": 5.6, "attack_range": 2.0, "attack_cooldown": 1.1, "attack_startup": 0.28, "xp": 1350, "aggro_range": 10.0, "leash_range": 24.0,
		 "radius": 0.42, "scale": 1.05, "color": Color(0.94, 0.88, 0.84), "shape": "capsule", "loot_table": "lt_veil_dancer", "gold_min": 62, "gold_max": 124, "model": "mob_veil_dancer",
		 "skill_ids": ["mob_fan_leap", "mob_fan_strikes"] as Array[String]},
		{"id": "first_dancer", "name": "Primeiro Bailarino", "level": 48, "stat_role": "elite", "unit_mods": {"hp": 2.0, "atk": 1.6}, "demon": true, "faction": F,
		 "move_speed": 5.8, "attack_range": 2.2, "attack_cooldown": 1.1, "attack_startup": 0.3, "xp": 3400, "aggro_range": 11.0, "leash_range": 26.0,
		 "radius": 0.5, "scale": 1.2, "color": Color(0.96, 0.9, 0.78), "shape": "capsule", "loot_table": "lt_first_dancer", "gold_min": 160, "gold_max": 320, "model": "mob_first_dancer",
		 "skill_ids": ["mob_ribbon_vanish", "mob_first_fan_leap", "mob_first_fan_strikes"] as Array[String], "escort": {"id": "veil_dancer", "count": 2}},
		# ---- Galgos de Seda (bestas do Véu): matilha de 3 pelo spawner; o Alfa puxa o mais longe e lidera 2 ----
		{"id": "silk_hound", "name": "Galgo de Seda", "level": 46, "stat_role": "comum", "unit_mods": {"hp": 1.15, "atk": 1.1}, "demon": true, "faction": F,
		 "move_speed": 6.5, "attack_range": 1.8, "attack_cooldown": 1.0, "attack_startup": 0.25, "xp": 1250, "aggro_range": 11.0, "leash_range": 24.0,
		 "radius": 0.5, "scale": 1.0, "color": Color(0.92, 0.88, 0.8), "shape": "box", "loot_table": "lt_silk_hound", "gold_min": 56, "gold_max": 112, "model": "mob_silk_hound",
		 "skill_ids": ["mob_silk_bite", "mob_silk_lunge"] as Array[String]},
		{"id": "parade_alpha", "name": "Galgo Alfa do Cortejo", "level": 49, "stat_role": "bruto", "unit_mods": {"hp": 1.4, "atk": 1.1}, "demon": true, "faction": F,
		 "move_speed": 6.0, "attack_range": 2.2, "attack_cooldown": 1.2, "attack_startup": 0.35, "xp": 2000, "aggro_range": 12.0, "leash_range": 26.0,
		 "radius": 0.75, "scale": 1.3, "color": Color(0.9, 0.82, 0.6), "shape": "box", "loot_table": "lt_parade_alpha", "gold_min": 80, "gold_max": 160, "model": "mob_parade_alpha",
		 "skill_ids": ["mob_silk_lunge", "mob_ribbon_lash"] as Array[String], "escort": {"id": "silk_hound", "count": 2}},
		# ---- Coro Ferido (sônicos): Corista atira e recua (kite); Maestro canta o Uníssono e lidera 3 ----
		{"id": "chorister", "name": "Corista Ferida", "level": 46, "stat_role": "comum", "unit_mods": {"hp": 1.15, "atk": 1.2}, "matk_mult": 1.0, "demon": true, "faction": F, "ranged": true, "kite": true,
		 "move_speed": 4.8, "attack_range": 9.0, "attack_cooldown": 1.6, "attack_startup": 0.4, "xp": 1300, "aggro_range": 11.0, "leash_range": 24.0,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.82, 0.74, 0.9), "shape": "capsule", "loot_table": "lt_chorister", "gold_min": 60, "gold_max": 120, "model": "mob_chorister",
		 "skill_ids": ["mob_shrill_note"] as Array[String]},
		{"id": "choir_maestro", "name": "Maestro do Coro", "level": 49, "stat_role": "elite", "unit_mods": {"hp": 2.0, "atk": 1.6}, "matk_mult": 0.6, "demon": true, "faction": F,
		 "move_speed": 4.8, "attack_range": 2.6, "attack_cooldown": 1.3, "attack_startup": 0.4, "xp": 3600, "aggro_range": 11.0, "leash_range": 26.0,
		 "radius": 0.55, "scale": 1.25, "color": Color(0.3, 0.22, 0.38), "shape": "capsule", "loot_table": "lt_choir_maestro", "gold_min": 170, "gold_max": 340, "model": "mob_choir_maestro",
		 "skill_ids": ["mob_baton_thrust", "mob_unison", "mob_shrill_note"] as Array[String], "escort": {"id": "chorister", "count": 3}},     # a última da lista sai primeiro: nota, Uníssono, batuta (WP9: abria no canto e morria sem golpear; batuta primeiro = 44-47%)
		# ---- Reflexos (espelhos): vida de demônio (o ×0,6 do GDD deixava a luta trivial: band_probe 1,5 s), some no espelho e volta num lampejo ----
		{"id": "vain_reflection", "name": "Reflexo Vaidoso", "level": 48, "stat_role": "comum", "unit_mods": {"hp": 1.4, "atk": 1.35}, "demon": true, "faction": F,
		 "move_speed": 5.4, "attack_range": 2.0, "attack_cooldown": 1.1, "attack_startup": 0.28, "xp": 1400, "aggro_range": 10.0, "leash_range": 24.0,
		 "radius": 0.45, "scale": 1.05, "color": Color(0.82, 0.86, 0.92), "shape": "capsule", "loot_table": "lt_vain_reflection", "gold_min": 64, "gold_max": 128, "model": "mob_vain_reflection",
		 "skill_ids": ["mob_mirror_lunge", "mob_mirror_fade"] as Array[String]},
		# ---- Incensários (névoa): lento e grosso, Fumo Doce que fica no chão ----
		{"id": "living_censer", "name": "Incensário Vivo", "level": 47, "stat_role": "bruto", "unit_mods": {"hp": 1.4, "atk": 1.0}, "matk_mult": 0.8, "faction": F,
		 "move_speed": 3.2, "attack_range": 2.4, "attack_cooldown": 1.6, "attack_startup": 0.5, "xp": 1550, "aggro_range": 9.0, "leash_range": 22.0,
		 "radius": 0.75, "scale": 1.15, "color": Color(0.62, 0.48, 0.25), "shape": "capsule", "loot_table": "lt_living_censer", "gold_min": 66, "gold_max": 132, "model": "mob_living_censer",
		 "skill_ids": ["mob_censer_swing", "mob_sweet_smoke"] as Array[String]},
		# ---- Vinhas (nativas do field_perfume, fora da facção): parada, prende e puxa, regenera 0,3 (0,5 do GDD travou o Sacerdote: band_probe) (fogo/veneno cortam, F3) ----
		{"id": "thirsty_vine", "name": "Vinha Sedenta", "level": 46, "stat_role": "bruto", "unit_mods": {"hp": 1.6, "atk": 1.0}, "regen": 0.3,
		 "move_speed": 0.0, "attack_range": 3.0, "attack_cooldown": 1.5, "attack_startup": 0.45, "xp": 1500, "aggro_range": 9.0, "leash_range": 20.0,
		 "radius": 0.8, "scale": 1.3, "color": Color(0.42, 0.2, 0.4), "shape": "cone", "loot_table": "lt_thirsty_vine", "gold_min": 60, "gold_max": 120, "model": "mob_thirsty_vine",
		 "skill_ids": ["mob_vine_grasp"] as Array[String]},
		# ---- Veladas (§3.1, família principal dos demônios; aprovada 2026-11-23): chifres para trás, véus, sem asas ----
		# Sem esquiva (D4): some e embosca, recua, salta e atira de longe. `model` = thirst_model (final se o GLB existir).
		# band_probe 2026-11-23 (12 duelos): Sedutora 1,0/1,05 e Carpideira 1,1/1,2 davam 2,9-3,1 s com 4-7% de vida: subiram a vida.
		{"id": "seductress", "name": "Sedutora", "level": 46, "stat_role": "comum", "unit_mods": {"hp": 1.25, "atk": 1.1}, "demon": true, "faction": F,
		 "move_speed": 5.6, "attack_range": 2.0, "attack_cooldown": 1.1, "attack_startup": 0.28, "xp": 1350, "aggro_range": 10.0, "leash_range": 24.0,
		 "radius": 0.42, "scale": 1.0, "color": Color(0.95, 0.9, 0.86), "shape": "capsule", "loot_table": "lt_seductress", "gold_min": 62, "gold_max": 124, "model": thirst_model("seductress"),
		 "skill_ids": ["mob_thirst_recoil", "mob_thirst_claws", "mob_thirst_vanish"] as Array[String]},
		{"id": "flayer", "name": "Açoitadora", "level": 47, "stat_role": "comum", "unit_mods": {"hp": 1.15, "atk": 1.1}, "demon": true, "faction": F,
		 "move_speed": 5.2, "attack_range": 2.4, "attack_cooldown": 1.2, "attack_startup": 0.32, "xp": 1450, "aggro_range": 10.0, "leash_range": 24.0,
		 "radius": 0.45, "scale": 1.05, "color": Color(0.9, 0.82, 0.8), "shape": "capsule", "loot_table": "lt_flayer", "gold_min": 66, "gold_max": 132, "model": thirst_model("flayer"),
		 "skill_ids": ["mob_thirst_lash", "mob_thirst_whip"] as Array[String]},
		{"id": "veil_singer", "name": "Carpideira", "level": 48, "stat_role": "comum", "unit_mods": {"hp": 1.3, "atk": 1.25}, "matk_mult": 1.0, "demon": true, "faction": F, "ranged": true, "kite": true,
		 "move_speed": 4.8, "attack_range": 9.0, "attack_cooldown": 1.6, "attack_startup": 0.4, "xp": 1400, "aggro_range": 11.0, "leash_range": 24.0,
		 "radius": 0.42, "scale": 1.0, "color": Color(0.92, 0.86, 0.9), "shape": "capsule", "loot_table": "lt_veil_singer", "gold_min": 64, "gold_max": 128, "model": thirst_model("veil_singer"),
		 "skill_ids": ["mob_veil_lament", "mob_veil_ring"] as Array[String]},
		# Matriarca: elite do bando (2 Sedutoras + 1 Açoitadora: `escort.ids` por vaga) e aura `sede` (aliados +15% velocidade)
		{"id": "thirst_matriarch", "name": "Matriarca Velada", "level": 49, "stat_role": "elite", "unit_mods": {"hp": 2.0, "atk": 1.6}, "demon": true, "faction": F, "aura": "sede",
		 "move_speed": 5.6, "attack_range": 2.4, "attack_cooldown": 1.15, "attack_startup": 0.32, "xp": 3600, "aggro_range": 11.0, "leash_range": 26.0,
		 "radius": 0.55, "scale": 1.3, "color": Color(0.96, 0.88, 0.8), "shape": "capsule", "loot_table": "lt_thirst_matriarch", "gold_min": 170, "gold_max": 340, "model": thirst_model("thirst_matriarch"),
		 "skill_ids": ["mob_matriarch_trail", "mob_matriarch_leap", "mob_matriarch_claws"] as Array[String],
		 "escort": {"id": "seductress", "count": 3, "ids": ["seductress", "seductress", "flayer"]}},
	]
	var out: Array = []
	for d in L:
		out.append(_act3_mods(d))
	return out

## Lacaios dos chefes do Ato III (§4; 0 XP, sem saque, números à mão como os do Kharzun). As fases/assinaturas que os
## chamam são do WP8; pedestais (Eco de Amarante) com ~3,5% da vida da raide (F2 chefe 50 × 2,8), auras/skills no WP8.
static func _act3_adds() -> Array:
	var F := Balance.ACT3_FACTION
	var add := {"xp": 0, "loot_table": "", "gold_min": 0, "gold_max": 0, "faction": F, "aggro_range": 16.0, "leash_range": 40.0}
	var L := [
		{"id": "vine_sprout", "name": "Vinha Sedenta", "level": 47, "hp": 6000, "atk": 110, "def": 60, "mdef": 24, "move_speed": 0.0, "attack_range": 3.0, "attack_cooldown": 1.5, "attack_startup": 0.45,
		 "radius": 0.8, "scale": 1.0, "color": Color(0.42, 0.2, 0.4), "shape": "cone", "model": "mob_thirsty_vine", "skill_ids": ["mob_vine_grasp"] as Array[String]},
		{"id": "reveler_guest", "name": "Convidado do Banquete", "level": 47, "hp": 4200, "atk": 100, "def": 28, "mdef": 22, "move_speed": 5.0, "attack_range": 2.0, "attack_cooldown": 0.9, "attack_startup": 0.3,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.5, 0.12, 0.2), "shape": "capsule", "model": "mob_reveler", "skill_ids": ["mob_goblet_throw"] as Array[String]},
		{"id": "chorister_echo", "name": "Corista do Palco", "level": 48, "hp": 3600, "atk": 90, "matk": 90, "def": 24, "mdef": 30, "ranged": true, "kite": true, "move_speed": 4.8, "attack_range": 9.0, "attack_cooldown": 1.5, "attack_startup": 0.4,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.82, 0.74, 0.9), "shape": "capsule", "model": "mob_chorister", "skill_ids": ["mob_shrill_note"] as Array[String]},
		{"id": "dancer_escort", "name": "Primeiro Bailarino", "level": 50, "hp": 6400, "atk": 150, "def": 40, "mdef": 30, "move_speed": 5.8, "attack_range": 2.2, "attack_cooldown": 0.9, "attack_startup": 0.3,
		 "radius": 0.5, "scale": 1.2, "color": Color(0.96, 0.9, 0.78), "shape": "capsule", "model": "mob_first_dancer", "skill_ids": ["mob_first_fan_leap", "mob_first_fan_strikes"] as Array[String]},
		# Cópia da Condessa (Máscaras Refletidas, R-F): mesmo nome e modelo; morre com 1 golpe; dano = Balance.SHAZKA_DECOY_DMG
		{"id": "countess_decoy", "name": "A Condessa Refletida", "level": 49, "stat_role": "chefe", "unit_mods": {"hp": 4.0, "atk": 2.3}, "decoy": true,
		 "move_speed": 5.2, "attack_range": 2.4, "attack_cooldown": 1.0, "attack_startup": 0.35, "radius": 0.7, "scale": 1.5, "color": Color(0.86, 0.88, 0.96), "shape": "capsule",
		 "xp": 0, "loot_table": "", "gold_min": 0, "gold_max": 0,
		 "model": act3_boss_model("boss_countess")},
		# parados (velocidade 0, não golpeiam): Tubos de Órgão (Ressoa), Espelhos de Pé (Condessa, cobertura R-E), Pedestais dos Sentidos (Eco)
		{"id": "organ_pipe", "name": "Tubo de Órgão", "level": 49, "hp": 9000, "atk": 1, "matk": 120, "def": 50, "mdef": 40, "move_speed": 0.0, "attack_range": 0.5, "attack_cooldown": 999.0,
		 "radius": 0.6, "scale": 1.0, "color": Color(0.7, 0.6, 0.35), "shape": "cone", "model": "mob_organ_pipe",
		 "skill_ids": ["mob_pipe_note"] as Array[String], "aggro_range": 30.0},
		{"id": "standing_mirror", "name": "Espelho de Pé", "level": 49, "hp": 6000, "atk": 1, "def": 40, "mdef": 40, "move_speed": 0.0, "attack_range": 0.5, "attack_cooldown": 999.0,
		 "radius": 0.7, "scale": 1.0, "color": Color(0.85, 0.88, 0.95), "shape": "cone", "model": "mob_standing_mirror"},      # na luta da Condessa o espelho é cobertura (m["covers"], BossSigView desenha este modelo e toca crack/idle_cracked)
		{"id": "sense_sight", "name": "Pedestal da Visão", "level": 50, "hp": 32600, "atk": 1, "aura": "sense_sight", "def": 44, "mdef": 40, "move_speed": 0.0, "attack_range": 0.5, "attack_cooldown": 999.0,
		 "radius": 0.6, "scale": 1.0, "color": Color(0.9, 0.85, 0.95), "shape": "cone", "model": "mob_sense_pedestal_sight"},
		{"id": "sense_hearing", "name": "Pedestal da Audição", "level": 50, "hp": 32600, "atk": 1, "matk": 420, "def": 44, "mdef": 40, "move_speed": 0.0, "attack_range": 0.5, "attack_cooldown": 999.0,
		 "radius": 0.6, "scale": 1.0, "color": Color(0.82, 0.74, 0.9), "shape": "cone", "model": "mob_sense_pedestal_hearing", "skill_ids": ["mob_sense_note"] as Array[String]},
		{"id": "sense_smell", "name": "Pedestal do Olfato", "level": 50, "hp": 32600, "atk": 1, "matk": 420, "def": 44, "mdef": 40, "move_speed": 0.0, "attack_range": 0.5, "attack_cooldown": 999.0,
		 "radius": 0.6, "scale": 1.0, "color": Color(0.8, 0.65, 0.9), "shape": "cone", "model": "mob_sense_pedestal_smell", "skill_ids": ["mob_sense_smoke"] as Array[String]},
		{"id": "sense_taste", "name": "Pedestal do Paladar", "level": 50, "hp": 32600, "atk": 1, "matk": 14200, "def": 44, "mdef": 40, "move_speed": 0.0, "attack_range": 0.5, "attack_cooldown": 999.0,
		 "radius": 0.6, "scale": 1.0, "color": Color(0.75, 0.25, 0.35), "shape": "cone", "model": "mob_sense_pedestal_taste", "skill_ids": ["mob_sense_taste"] as Array[String]},     # matk = Balance.ACT3_TASTE_PCT da vida do Eco por s (check)
	]
	for d in L:
		d.merge(add)
	return L

## Ato III — chefes de mundo (WP8a; design/gdd/ato3-excesso-45-50.md §4, D11): afinados para TRIO (faixa "grupo" do
## boss_probe --bands), renascem a cada Balance.WORLD_BOSS_RESPAWN_S (spawner no mapa, MapsCatalog). Vida/ATK pela F2 de
## chefe × unit_mods; lacaios 0 XP (_act3_adds). Modelos próprios do WP7 (ACT3_BOSS_MODELS).
## Falas = placeholder até o narrative-director.
const ACT3_FIELD_BOSSES := ["boss_vindima", "boss_prima_donna"]
const ACT3_BOSS_MODELS := {"boss_vindima": "mob_vindima", "boss_prima_donna": "mob_prima_donna"}

static func _act3_field_bosses() -> Array:
	var F := Balance.ACT3_FACTION
	return [
		# ---- Dona Vindima, a Vinha que Bebe (field_perfume, Poço de Névoa, 47): sair do centro (Prensa) ----
		{"id": "boss_vindima", "name": "Dona Vindima, a Vinha que Bebe", "level": 47, "stat_role": "chefe", "unit_mods": {"hp": 2.0, "atk": 1.1}, "matk_mult": 0.8, "faction": F,
		 "move_speed": 4.2, "attack_range": 3.0, "attack_cooldown": 1.3, "attack_startup": 0.45, "xp": 6500, "aggro_range": 12.0, "leash_range": 26.0,
		 "radius": 1.0, "scale": 1.8, "color": Color(0.45, 0.22, 0.42), "shape": "cone", "is_boss": true, "berserk_after": 180, "loot_table": "lt_vindima", "gold_min": 600, "gold_max": 900, "model": "mob_vindima",
		 "skill_ids": ["mob_vindima_stomp", "mob_vindima_lash", "mob_vindima_grapes", "mob_vindima_press"] as Array[String], "coin_chance": 1.0, "coin_min": 3, "coin_max": 5,
		 "intro": "(as vinhas do poço se erguem numa saia de folhas; a matrona de cepa sorri com a boca do tonel) Visitas! Tão secas... Venham, a mamãe enche.",
		 "last_words": "(o tonel racha e o vinho escorre para a névoa) Só... mais um gole... para a mamãe...",
		 "phases": [{"hp": 0.7, "say": "Brotos! Bebam com a mamãe!", "skills": ["mob_vindima_sprouts"], "ward": 0.4, "summon": {"id": "vine_sprout", "count": 2, "max": 3}},
			{"hp": 0.35, "say": "(a névoa do poço engrossa, doce e lilás)", "skills": ["mob_vindima_smoke"], "enrage": 1.3}]},
		# ---- A Prima-Donna do Palco (field_parade, Palco Grande, 48): ritmo (Ária em Três Tempos) ----
		{"id": "boss_prima_donna", "name": "A Prima-Donna do Palco", "level": 48, "stat_role": "chefe", "unit_mods": {"hp": 2.0, "atk": 1.1}, "matk_mult": 1.0, "faction": F,
		 "move_speed": 4.8, "attack_range": 2.6, "attack_cooldown": 1.2, "attack_startup": 0.4, "xp": 6700, "aggro_range": 12.0, "leash_range": 26.0,
		 "radius": 0.8, "scale": 1.4, "color": Color(0.92, 0.84, 0.9), "shape": "capsule", "is_boss": true, "berserk_after": 180, "loot_table": "lt_prima_donna", "gold_min": 620, "gold_max": 920, "model": "mob_prima_donna",
		 "skill_ids": ["mob_prima_fan", "mob_prima_notes", "mob_prima_forte", "mob_prima_aria"] as Array[String], "coin_chance": 1.0, "coin_min": 3, "coin_max": 5,
		 "intro": "(os pássaros de porcelana da gaiola-vestido abrem o bico juntos) Silêncio na plateia. Quem perder o compasso... fica no palco para sempre.",
		 "last_words": "(a última nota racha a gaiola; os pássaros voam) E o bis...? Ninguém... pediu bis...",
		 "phases": [{"hp": 0.7, "say": "Coro! Para o palco!", "skills": ["mob_prima_chorus"], "ward": 0.5, "summon": {"id": "chorister_echo", "count": 2, "max": 3, "pick": "far"}},
			{"hp": 0.3, "say": "O GRANDE FINAL!", "enrage": 1.3}]},
	]

## Ato III — chefes das masmorras, da Fenda e da raide (WP6: só para os spawners dos mapas novos resolverem).
## TODO(WP8b): SUBSTITUTOS. Vida/ATK já pela F2 de chefe (GDD §6.2) × unit_mods (H), mas skills = as dos monstros da faixa,
## fases mínimas (lacaio 0 XP + fúria), sem assinatura, falas placeholder. A mecânica de verdade (Banquete, Olhar Que Julga,
## Cânone, Cortejo de Lâminas, Brinde Dividido; §4.1) e a calibração em grupo (boss_probe, §4.2) são do WP8b.
## Modelo: o pretendido (ACT3_WP6_BOSS_MODELS) se o GLB existe, senão o substituto (`act3_boss_model`).
const ACT3_WP6_BOSSES := ["boss_varo", "boss_countess", "boss_ressoa", "vessaline", "boss_sylvare_echo"]
const ACT3_WP6_BOSS_MODELS := {"boss_varo": "mob_varo", "boss_countess": "mob_countess", "boss_ressoa": "mob_ressoa", "vessaline": "mob_vessaline", "boss_sylvare_echo": "mob_sylvare_echo"}
const ACT3_WP6_STANDIN := {"boss_varo": "mob_bandit_chief", "boss_countess": "mob_elf_warden", "boss_ressoa": "mob_frost_mage", "vessaline": "mob_elf_warden", "boss_sylvare_echo": "mob_ghost"}

static func act3_boss_model(id: String) -> String:
	var want: String = ACT3_WP6_BOSS_MODELS[id]
	return want if ResourceLoader.exists("res://assets/models/%s.glb" % want) else str(ACT3_WP6_STANDIN[id])

static func _act3_wp6_bosses() -> Array:
	var F := Balance.ACT3_FACTION
	return [
		# Varo Taça-Cheia, o Anfitrião (dg_cellars, 47, grupo de 4; WP8b): O Banquete (canal R-C, verbo "interromper").
		# F2 70%: 3 Convidados nos pontos `adds` do boss_hint (escolta, sem ward); F3 35%: Fumo Doce em fileiras + fúria 15%
		{"id": "boss_varo", "name": "Varo Taça-Cheia, o Anfitrião", "level": 47, "stat_role": "chefe", "unit_mods": {"hp": 4.0, "atk": 1.95}, "faction": F,
		 "move_speed": 4.4, "attack_range": 2.6, "attack_cooldown": 1.2, "attack_startup": 0.4, "xp": 6600, "aggro_range": 12.0, "leash_range": 26.0,
		 "radius": 0.9, "scale": 1.7, "color": Color(0.5, 0.12, 0.22), "shape": "capsule", "is_boss": true, "berserk_after": 200, "loot_table": "lt_varo",
		 "gold_min": 620, "gold_max": 920, "model": act3_boss_model("boss_varo"),
		 "skill_ids": ["mob_varo_cleave", "mob_varo_goblet", "mob_varo_belly", "mob_varo_banquet"] as Array[String],
		 "coin_chance": 1.0, "coin_min": 3, "coin_max": 5,
		 "intro": "Mais convidados! Sentem, sentem. Ninguém se levanta da mesa antes do último brinde. E o último brinde nunca chega.",
		 "last_words": "(o garrafão rola e para) Ainda tinha... um gole...",
		 "phases": [{"hp": 0.7, "say": "Garçons! Mais cadeiras!", "summon": {"id": "reveler_guest", "count": 3, "max": 3, "at": [[-3.61, -9.32], [7.53, -6.59], [8.76, 4.82]]}},
			{"hp": 0.35, "say": "(o guardanapo cai) Agora é sério.", "skills": ["mob_varo_smoke_lines"], "enrage": 1.15}]},
		# A Condessa Refletida (dg_mirrors, 49, grupo de 4; WP8b): Olhar Que Julga (cobertura R-E, verbo "usar cobertura").
		# Espelhos de Pé = coberturas (m["covers"], intocáveis) nos pontos `cover` do boss_hint (deslocamentos no `mirrors` da skill).
		# F2 65%: Máscaras (3 cópias R-F); F3 30%: Chuva de Cacos + fúria
		{"id": "boss_countess", "name": "A Condessa Refletida", "level": 49, "stat_role": "chefe", "unit_mods": {"hp": 4.0, "atk": 2.3}, "faction": F,
		 "move_speed": 5.2, "attack_range": 2.4, "attack_cooldown": 1.0, "attack_startup": 0.35, "xp": 7000, "aggro_range": 12.0, "leash_range": 26.0,
		 "radius": 0.7, "scale": 1.5, "color": Color(0.86, 0.88, 0.96), "shape": "capsule", "is_boss": true, "berserk_after": 200, "loot_table": "lt_countess",
		 "gold_min": 660, "gold_max": 980, "model": act3_boss_model("boss_countess"),
		 "skill_ids": ["mob_countess_rapier", "mob_countess_leap", "mob_countess_gaze"] as Array[String],
		 "cover": {"radius": Balance.ACT3_MIRROR_R, "time": 40.0, "max": 3, "model": "mob_standing_mirror", "fx": "boss_mirror_rise", "skills": []},
		 "coin_chance": 1.0, "coin_min": 3, "coin_max": 5,
		 "intro": "Olhem bem para nós. É a última vez que vocês se veem de frente.",
		 "last_words": "(as duas máscaras racham juntas) Qual de nós... caiu?",
		 "phases": [{"hp": 0.65, "say": "Tantos rostos... escolham um.", "skills": ["mob_countess_masks"]},
			{"hp": 0.3, "say": "(os espelhos da sala racham)", "skills": ["mob_countess_shards"], "enrage": 1.3}]},
		# Mestra Ressoa, a Regente (dg_conservatory, 49, opcional; WP8b): Cânone (marca R-B spread, verbo "espalhar").
		# F2 65%: 4 Tubos de Órgão parados nos pontos `adds` do boss_hint (ward 0,6, cada um com a Nota do Tubo); F3 30%: Uníssono + fúria
		{"id": "boss_ressoa", "name": "Mestra Ressoa, a Regente", "level": 49, "stat_role": "chefe", "unit_mods": {"hp": 3.2, "atk": 1.6}, "matk_mult": 1.0, "faction": F,
		 "move_speed": 4.6, "attack_range": 2.6, "attack_cooldown": 1.2, "attack_startup": 0.4, "xp": 7000, "aggro_range": 12.0, "leash_range": 36.0,
		 "radius": 0.8, "scale": 1.45, "color": Color(0.7, 0.6, 0.4), "shape": "capsule", "is_boss": true, "berserk_after": 200, "loot_table": "lt_ressoa",
		 "gold_min": 660, "gold_max": 980, "model": act3_boss_model("boss_ressoa"),
		 "skill_ids": ["mob_ressoa_baton", "mob_ressoa_notes", "mob_ressoa_fermata", "mob_ressoa_canon"] as Array[String],
		 "coin_chance": 1.0, "coin_min": 3, "coin_max": 5,
		 "intro": "Afinem. O concerto começa quando eu baixar a batuta. E não termina.",
		 "last_words": "(os tubos soltam um acorde longo e calam) ...fermata.",
		 "phases": [{"hp": 0.65, "say": "Órgão, entre!", "ward": 0.6, "summon": {"id": "organ_pipe", "count": 4, "max": 4, "at": [[-7.78, 7.78], [-7.78, -7.78], [7.78, -7.78], [7.78, 7.78]]}},
			{"hp": 0.3, "say": "Todos juntos. Uníssono!", "skills": ["mob_ressoa_unison"], "enrage": 1.3}]},
		# Vessaline, a Anfitriã do Véu (rift_garden, Pavilhão, 50, CHEFE PRINCIPAL, grupo de 4, D8; WP8b): F1 Cortejo de Lâminas
		# (assinatura) + leques + Salto Leque (soft); F2 70% 2 Primeiros Bailarinos (ward 0,5); F3 40% Palco Seguro (ilhas fixas do
		# Pavilhão) + Fumo Doce; F4 15% fúria; berserk 210 s. Calibrado com boss_probe --party=4 (agent-act3-finale.md).
		{"id": "vessaline", "name": "Vessaline, a Anfitriã do Véu", "level": 50, "stat_role": "chefe", "unit_mods": {"hp": 6.5, "atk": 1.2}, "faction": F,
		 "move_speed": 5.6, "attack_range": 2.8, "attack_cooldown": 1.0, "attack_startup": 0.35, "xp": 9000, "aggro_range": 13.0, "leash_range": 34.0,
		 "radius": 0.9, "scale": 1.7, "color": Color(0.96, 0.9, 0.9), "shape": "capsule", "is_boss": true, "berserk_after": 210, "loot_table": "lt_vessaline",
		 "gold_min": 900, "gold_max": 1300, "model": act3_boss_model("vessaline"), "skill_ids": ["mob_first_fan_strikes", "mob_first_fan_leap", "mob_vess_cortege"] as Array[String],
		 "coin_chance": 1.0, "coin_min": 4, "coin_max": 6,
		 "intro": "(a cauda de fitas se abre devagar) Chegaram tarde, queridos. A festa já começou em vocês.",
		 "last_words": "(a lágrima dourada escorre) Ninguém... nunca quis ir embora... Ela vai sentir falta de vocês.",
		 "phases": [{"hp": 0.7, "say": "Primeiros Bailarinos, recebam os convidados!", "ward": 0.5, "summon": {"id": "dancer_escort", "count": 2, "max": 2}},
			{"hp": 0.4, "say": "(as fitas da cauda se abrem) O palco é pequeno para todos. Escolham bem o seu lugar.", "skills": ["mob_vess_stage", "mob_sweet_smoke"]},
			{"hp": 0.15, "say": "Fiquem. Fiquem e dancem até o fim!", "enrage": 1.3}]},
		# O Eco de Amarante (rift_heart, RAIDE de 5, 50, D9; WP8b): F1 Brinde Dividido (assinatura: marca que alterna dividir/espalhar);
		# F2 70% Os Quatro Sentidos = 4 pedestais nos pontos do JSON (4 fases no mesmo limiar, como os estandartes do Durgash; ward 0,6);
		# F3 40% 4 cópias + ilhas da sala; F4 15% fúria; berserk ×20 aos 120 s. Dano por gente em BOSS_CROWD_RAID (tabela do Durgash).
		{"id": "boss_sylvare_echo", "name": "O Eco de Amarante", "level": 50, "stat_role": "chefe", "unit_mods": {"hp": 4.5, "atk": 1.6}, "matk_mult": 1.0, "faction": F,
		 "move_speed": 4.4, "attack_range": 2.8, "attack_cooldown": 1.2, "attack_startup": 0.4, "xp": 9500, "aggro_range": 14.0, "leash_range": 40.0,
		 "radius": 1.0, "scale": 1.25, "color": Color(0.86, 0.84, 0.94), "shape": "capsule", "is_boss": true, "berserk_after": 120, "berserk_mult": 20.0, "loot_table": "lt_sylvare_echo",
		 "gold_min": 1000, "gold_max": 1500, "model": act3_boss_model("boss_sylvare_echo"), "skill_ids": ["mob_shrill_note", "mob_mirror_lunge", "mob_echo_thirst"] as Array[String],
		 "coin_chance": 1.0, "coin_min": 5, "coin_max": 8,
		 "intro": "(a coroa vazia gira devagar; o perfume fala) Vocês vieram provar. Todos vêm.",
		 "last_words": "(os espelhos do vestido caem um a um) Só um eco... A dona da coroa... ainda tem sede...",
		 "phases": [{"hp": 0.7, "say": "Vejam. Ouçam. Cheirem. PROVEM.", "ward": 0.6, "summon": {"id": "sense_sight", "count": 1, "max": 1, "abs": true, "at": [[8.49, -25.99]]}},
			{"hp": 0.7, "summon": {"id": "sense_hearing", "count": 1, "max": 2, "abs": true, "at": [[8.49, -9.01]]}},
			{"hp": 0.7, "summon": {"id": "sense_smell", "count": 1, "max": 3, "abs": true, "at": [[-8.49, -9.01]]}},
			{"hp": 0.7, "summon": {"id": "sense_taste", "count": 1, "max": 4, "abs": true, "at": [[-8.49, -25.99]]}},
			{"hp": 0.4, "say": "(os espelhos do vestido se soltam e flutuam) Qual reflexo tem sede?", "skills": ["mob_echo_decoys", "mob_echo_stage"]},
			{"hp": 0.15, "say": "(o vapor perfumado ferve)", "enrage": 1.3}]},
		# Cópia do Eco (Reflexos do Brinde, R-F): mesmo nome, modelo e vida; morre com 1 golpe; dano = Balance.SHAZKA_DECOY_DMG
		{"id": "echo_decoy", "name": "O Eco de Amarante", "level": 50, "stat_role": "chefe", "unit_mods": {"hp": 4.5, "atk": 1.6}, "faction": F, "decoy": true,
		 "move_speed": 4.4, "attack_range": 2.8, "attack_cooldown": 1.2, "attack_startup": 0.4, "xp": 0, "aggro_range": 16.0, "leash_range": 40.0,
		 "radius": 1.0, "scale": 1.25, "color": Color(0.86, 0.84, 0.94), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": act3_boss_model("boss_sylvare_echo")},
	]

static func build_loot() -> Array:
	return [
		_lt("lt_slime", [{"item": "slime_gel", "chance": 0.7, "min": 1, "max": 2}, {"item": "herb_green", "chance": 0.25}, {"item": "ring_gel", "chance": 0.03}]),
		_lt("lt_slime_blue", [{"item": "slime_gel", "chance": 0.6}, {"item": "herb_blue", "chance": 0.45}, {"item": "potion_mp_s", "chance": 0.1}]),
		_lt("lt_boar", [{"item": "boar_tusk", "chance": 0.5}, {"item": "iron_ore", "chance": 0.2}, {"item": "herb_green", "chance": 0.3}, {"item": "cap_leather", "chance": 0.05}, {"item": "boots_leather", "chance": 0.05}]),
		_lt("lt_wolf", [{"item": "wolf_pelt", "chance": 0.6}, {"item": "iron_ore", "chance": 0.5}, {"item": "potion_hp_s", "chance": 0.12}]),
		# chefes com tabela própria (antes dividiam a do Rei Javali / Chefe dos Bandidos)
		_lt("lt_slime_king", [{"item": "slime_gel", "chance": 1.0, "min": 6, "max": 10}, {"item": "ring_gel", "chance": 0.5}, {"item": "herb_blue", "chance": 1.0, "min": 3, "max": 5}, {"item": "potion_mp_m", "chance": 0.6}]),
		_lt("lt_spider_queen", [{"item": "spider_silk", "chance": 1.0, "min": 6, "max": 9}, {"item": "amulet_silk", "chance": 0.5}, {"item": "hood_silk", "chance": 0.4}, {"item": "elixir_stone", "chance": 0.5}]),
		_lt("lt_crypt_lord", [{"item": "ghost_essence", "chance": 1.0, "min": 4, "max": 6}, {"item": "bone_shard", "chance": 1.0, "min": 4, "max": 7}, {"item": "ring_spectral", "chance": 0.45}, {"item": "crown_spectral", "chance": 0.3}, {"item": "elixir_might", "chance": 1.0}]),
		_lt("lt_crab", [{"item": "crab_shell", "chance": 0.55}, {"item": "herb_blue", "chance": 0.15}, {"item": "slime_gel", "chance": 0.2}]),
		_lt("lt_crab_king", [{"item": "crab_shell", "chance": 1.0, "min": 3, "max": 5}, {"item": "elixir_stone", "chance": 0.45}, {"item": "amulet_tusk", "chance": 0.2}, {"item": "iron_ore", "chance": 0.8, "min": 2, "max": 3}]),
		_lt("lt_wasp", [{"item": "wasp_stinger", "chance": 0.5}, {"item": "herb_green", "chance": 0.25}, {"item": "potion_hp_s", "chance": 0.08}]),
		_lt("lt_wasp_soldier", [{"item": "wasp_stinger", "chance": 0.6, "min": 1, "max": 2}, {"item": "honey_comb", "chance": 0.3}, {"item": "ring_gel", "chance": 0.03}]),
		_lt("lt_bear_cub", [{"item": "bear_hide", "chance": 0.35}, {"item": "herb_green", "chance": 0.3}]),
		_lt("lt_bear", [{"item": "bear_hide", "chance": 0.6}, {"item": "honey_comb", "chance": 0.2}, {"item": "cap_leather", "chance": 0.04}, {"item": "boots_leather", "chance": 0.04}]),
		_lt("lt_hive", [{"item": "honey_comb", "chance": 1.0, "min": 3, "max": 5}, {"item": "wasp_stinger", "chance": 1.0, "min": 2, "max": 3}, {"item": "elixir_stone", "chance": 0.2}]),
		_lt("lt_bear_mother", [{"item": "bear_hide", "chance": 1.0, "min": 3, "max": 5}, {"item": "honey_comb", "chance": 1.0, "min": 2, "max": 3}, {"item": "amulet_tusk", "chance": 0.25}, {"item": "elixir_might", "chance": 0.4}]),
		_lt("lt_shaman_shifter", [{"item": "painted_hide", "chance": 0.5}, {"item": "spirit_feather", "chance": 0.35}, {"item": "potion_hp_m", "chance": 0.08}, {"item": "hood_silk", "chance": 0.04}]),
		_lt("lt_shaman_caller", [{"item": "totem_bark", "chance": 0.55}, {"item": "spirit_feather", "chance": 0.3}, {"item": "herb_blue", "chance": 0.3}, {"item": "amulet_silk", "chance": 0.03}]),
		_lt("lt_grove_wolf", [{"item": "wolf_pelt", "chance": 0.6}, {"item": "painted_hide", "chance": 0.3}]),
		_lt("lt_grove_bear", [{"item": "bear_hide", "chance": 0.6}, {"item": "painted_hide", "chance": 0.35}, {"item": "cap_leather", "chance": 0.03}]),
		_lt("lt_archdruid", [{"item": "totem_bark", "chance": 1.0, "min": 3, "max": 5}, {"item": "spirit_feather", "chance": 1.0, "min": 2, "max": 4}, {"item": "painted_hide", "chance": 1.0, "min": 2, "max": 3}, {"item": "amulet_silk", "chance": 0.3}, {"item": "elixir_might", "chance": 0.5}]),
		_lt("lt_boar_brute", [{"item": "boar_tusk", "chance": 1.0, "min": 2, "max": 3}, {"item": "amulet_tusk", "chance": 0.25}, {"item": "elixir_might", "chance": 0.3}, {"item": "herb_green", "chance": 0.6, "min": 1, "max": 3}]),
		_lt("lt_boar_king", [{"item": "boar_tusk", "chance": 1.0, "min": 3, "max": 5}, {"item": "amulet_tusk", "chance": 0.5}, {"item": "iron_ore", "chance": 1.0, "min": 2, "max": 4}, {"item": "elixir_might", "chance": 0.4}]),
		_lt("lt_spider", [{"item": "spider_silk", "chance": 0.6, "min": 1, "max": 2}, {"item": "herb_blue", "chance": 0.3}, {"item": "hood_silk", "chance": 0.04}]),
		_lt("lt_larva", [{"item": "rot_gel", "chance": 0.3}, {"item": "potion_hp_s", "chance": 0.08}]),
		_lt("lt_rot", [{"item": "rot_gel", "chance": 0.55}, {"item": "holy_silver", "chance": 0.1}, {"item": "potion_hp_m", "chance": 0.1}, {"item": "bone_shard", "chance": 0.3}]),
		_lt("lt_bones", [{"item": "bone_shard", "chance": 0.6, "min": 1, "max": 2}, {"item": "holy_silver", "chance": 0.14}, {"item": "star_ore", "chance": 0.2}, {"item": "potion_hp_m", "chance": 0.1}]),
		_lt("lt_cult", [{"item": "ghost_essence", "chance": 0.5}, {"item": "holy_silver", "chance": 0.16}, {"item": "ancient_relic", "chance": 0.2}, {"item": "potion_mp_m", "chance": 0.12}]),
		_lt("lt_citadel", [{"item": "holy_silver", "chance": 0.3}, {"item": "dawn_shard", "chance": 0.05}, {"item": "potion_hp_m", "chance": 0.15}]),
		_lt("lt_ghoul_giant", [{"item": "holy_silver", "chance": 1.0, "min": 3, "max": 5}, {"item": "dawn_shard", "chance": 0.5}, {"item": "rot_gel", "chance": 1.0, "min": 3, "max": 5}, {"item": "elixir_might", "chance": 0.4}]),
		_lt("lt_death_knight", [{"item": "holy_silver", "chance": 1.0, "min": 4, "max": 6}, {"item": "dawn_shard", "chance": 0.7}, {"item": "bone_shard", "chance": 1.0, "min": 3, "max": 5}, {"item": "elixir_might", "chance": 0.5}]),
		_lt("lt_frost_mage", [{"item": "holy_silver", "chance": 1.0, "min": 4, "max": 6}, {"item": "dawn_shard", "chance": 1.0}, {"item": "ghost_essence", "chance": 1.0, "min": 3, "max": 5}, {"item": "elixir_might", "chance": 0.5}]),
		_lt("lt_lich_king", [{"item": "dawn_shard", "chance": 1.0, "min": 2, "max": 3}, {"item": "holy_silver", "chance": 1.0, "min": 6, "max": 9}, {"item": "elixir_might", "chance": 1.0}]),
		_lt("lt_bandit_light", [{"item": "bandit_badge", "chance": 0.4}, {"item": "potion_hp_s", "chance": 0.12}, {"item": "boots_wolf", "chance": 0.03}]),
		_lt("lt_bandit_outlaw", [{"item": "bandit_badge", "chance": 1.0, "min": 2, "max": 3}, {"item": "iron_ore", "chance": 0.5, "min": 1, "max": 2}, {"item": "potion_hp_m", "chance": 0.25}, {"item": "helm_iron", "chance": 0.08}]),
		_lt("lt_bandit", [{"item": "bandit_badge", "chance": 0.55}, {"item": "iron_ore", "chance": 0.4}, {"item": "potion_hp_m", "chance": 0.1}, {"item": "helm_iron", "chance": 0.04}, {"item": "boots_wolf", "chance": 0.04}]),
		_lt("lt_ent", [{"item": "ent_bark", "chance": 0.7, "min": 1, "max": 2}, {"item": "herb_green", "chance": 0.5, "min": 1, "max": 3}, {"item": "elixir_stone", "chance": 0.08}]),
		_lt("lt_bandit_chief", [{"item": "bandit_badge", "chance": 1.0, "min": 3, "max": 5}, {"item": "ent_bark", "chance": 1.0, "min": 2, "max": 3}, {"item": "amulet_silk", "chance": 0.5}, {"item": "helm_bone", "chance": 0.3}, {"item": "elixir_might", "chance": 0.5}]),
		_lt("lt_elf_raid", [{"item": "elf_steel", "chance": 0.12}, {"item": "potion_hp_m", "chance": 0.12}, {"item": "herb_blue", "chance": 0.3}]),
		_lt("lt_elf_lynx", [{"item": "wolf_pelt", "chance": 0.5}, {"item": "potion_hp_s", "chance": 0.1}]),
		_lt("lt_elf", [{"item": "elf_steel", "chance": 0.45, "min": 1, "max": 2}, {"item": "potion_hp_m", "chance": 0.12}, {"item": "herb_blue", "chance": 0.3}]),
		_lt("lt_griffin", [{"item": "griffin_feather", "chance": 0.6, "min": 1, "max": 2}, {"item": "elf_steel", "chance": 0.2}]),
		_lt("lt_trent", [{"item": "heartwood", "chance": 0.65}, {"item": "ent_bark", "chance": 0.6, "min": 1, "max": 3}, {"item": "mother_sap", "chance": 0.05}]),
		_lt("lt_elf_warden", [{"item": "elf_steel", "chance": 1.0, "min": 2, "max": 3}, {"item": "mother_sap", "chance": 0.35}, {"item": "elixir_might", "chance": 0.25}]),
		_lt("lt_captain_hunter", [{"item": "elf_steel", "chance": 1.0, "min": 3, "max": 5}, {"item": "wolf_pelt", "chance": 1.0, "min": 3, "max": 5}, {"item": "elixir_might", "chance": 0.5}, {"item": "legend_coin", "chance": 0.4}]),
		_lt("lt_captain_sky", [{"item": "elf_steel", "chance": 1.0, "min": 3, "max": 5}, {"item": "griffin_feather", "chance": 1.0, "min": 2, "max": 4}, {"item": "elixir_stone", "chance": 0.5}, {"item": "legend_coin", "chance": 0.4}]),
		_lt("lt_captain_sap", [{"item": "mother_sap", "chance": 1.0, "min": 2, "max": 3}, {"item": "heartwood", "chance": 0.6}, {"item": "potion_mp_m", "chance": 1.0, "min": 2, "max": 3}, {"item": "legend_coin", "chance": 0.4}]),
		_lt("lt_elf_king", [{"item": "mother_sap", "chance": 1.0, "min": 3, "max": 5}, {"item": "elf_steel", "chance": 1.0, "min": 4, "max": 6}, {"item": "heartwood", "chance": 1.0, "min": 2, "max": 3}, {"item": "elixir_might", "chance": 1.0}]),
		_lt("lt_skeleton", [{"item": "bone_shard", "chance": 0.65, "min": 1, "max": 2}, {"item": "iron_ore", "chance": 0.4}, {"item": "potion_hp_m", "chance": 0.12}]),
		_lt("lt_ghost", [{"item": "ghost_essence", "chance": 0.55}, {"item": "herb_blue", "chance": 0.4, "min": 1, "max": 2}, {"item": "potion_mp_m", "chance": 0.12}, {"item": "ring_spectral", "chance": 0.03}]),
		_lt("lt_golem_moss", [{"item": "stone_core", "chance": 0.35}, {"item": "iron_ore", "chance": 0.5, "min": 1, "max": 2}, {"item": "herb_green", "chance": 0.35}, {"item": "potion_hp_m", "chance": 0.06}]),
		_lt("lt_golem_stone", [{"item": "stone_core", "chance": 0.45}, {"item": "iron_ore", "chance": 0.7, "min": 1, "max": 3}, {"item": "elixir_stone", "chance": 0.04}]),
		_lt("lt_golem_shard", [{"item": "stone_core", "chance": 0.4}, {"item": "herb_blue", "chance": 0.35}, {"item": "potion_mp_m", "chance": 0.1}]),
		_lt("lt_golem_ancient", [{"item": "stone_core", "chance": 1.0, "min": 3, "max": 5}, {"item": "iron_ore", "chance": 1.0, "min": 3, "max": 5}, {"item": "elixir_stone", "chance": 0.5}, {"item": "legend_coin", "chance": 0.3}]),
		_lt("lt_crystal_warden", [{"item": "stone_core", "chance": 1.0, "min": 3, "max": 5}, {"item": "potion_mp_m", "chance": 1.0, "min": 2, "max": 3}, {"item": "elixir_might", "chance": 0.5}, {"item": "legend_coin", "chance": 0.3}]),
		_lt("lt_quarry_heart", [{"item": "stone_core", "chance": 1.0, "min": 6, "max": 9}, {"item": "elixir_stone", "chance": 0.8}, {"item": "elixir_might", "chance": 0.6}, {"item": "legend_coin", "chance": 0.6}]),
		_lt("lt_golem", [{"item": "golem_core", "chance": 0.35}, {"item": "iron_ore", "chance": 1.0, "min": 2, "max": 4}, {"item": "bone_shard", "chance": 0.5}, {"item": "boots_ent", "chance": 0.05}]),
		_lt("lt_zombie", [{"item": "grave_dust", "chance": 0.55}, {"item": "bone_shard", "chance": 0.2}, {"item": "potion_hp_s", "chance": 0.12}]),
		_lt("lt_bone_recruit", [{"item": "bone_shard", "chance": 0.45}, {"item": "iron_ore", "chance": 0.35}, {"item": "potion_hp_s", "chance": 0.1}]),
		_lt("lt_wraith", [{"item": "grave_dust", "chance": 0.5}, {"item": "herb_blue", "chance": 0.4}, {"item": "potion_mp_s", "chance": 0.15}]),
		_lt("lt_bone_captain", [{"item": "bone_shard", "chance": 1.0, "min": 3, "max": 5}, {"item": "grave_dust", "chance": 1.0, "min": 2, "max": 3}, {"item": "ring_captain", "chance": 0.5}, {"item": "elixir_stone", "chance": 0.4}]),
		_lt("lt_wailing_widow", [{"item": "grave_dust", "chance": 1.0, "min": 3, "max": 5}, {"item": "herb_blue", "chance": 1.0, "min": 2, "max": 3}, {"item": "amulet_widow", "chance": 0.5}, {"item": "elixir_might", "chance": 0.4}]),
		_lt("lt_count_vargo", [{"item": "grave_dust", "chance": 1.0, "min": 4, "max": 6}, {"item": "cape_vargo", "chance": 0.6}, {"item": "ring_vargo", "chance": 0.4}, {"item": "elixir_might", "chance": 1.0}]),
		# Ato II, a Horda (30-35): materiais para as missões do porto
		_lt("lt_goblin", [{"item": "goblin_fang", "chance": 0.55, "min": 1, "max": 2}, {"item": "horde_badge", "chance": 0.3}, {"item": "potion_hp_m", "chance": 0.12}]),
		_lt("lt_goblin_agitator", [{"item": "horde_badge", "chance": 1.0, "min": 2, "max": 3}, {"item": "goblin_fang", "chance": 0.7, "min": 1, "max": 3}, {"item": "elixir_might", "chance": 0.05}]),
		_lt("lt_wolf_rider", [{"item": "rider_pelt", "chance": 0.55}, {"item": "goblin_fang", "chance": 0.35}, {"item": "potion_hp_m", "chance": 0.1}]),
		_lt("lt_orc", [{"item": "orc_tusk", "chance": 0.5}, {"item": "horde_badge", "chance": 0.35}, {"item": "iron_ore", "chance": 0.4, "min": 1, "max": 2}]),
		_lt("lt_naga", [{"item": "naga_scale", "chance": 0.6, "min": 1, "max": 2}, {"item": "herb_blue", "chance": 0.3}, {"item": "potion_mp_m", "chance": 0.12}]),
		_lt("lt_tide_mother", [{"item": "tide_essence", "chance": 1.0, "min": 2, "max": 3}, {"item": "naga_scale", "chance": 1.0, "min": 4, "max": 6}, {"item": "elixir_might", "chance": 1.0}]),
		_lt("lt_agitator_lord", [{"item": "war_drum_hide", "chance": 1.0, "min": 2, "max": 3}, {"item": "horde_badge", "chance": 1.0, "min": 4, "max": 6}, {"item": "elixir_might", "chance": 1.0}]),
		# Ato II, Estepes de Cinza (35-40): materiais para as missões do Posto da Caravana
		_lt("lt_troll", [{"item": "troll_hide", "chance": 0.5}, {"item": "troll_tusk", "chance": 0.3}, {"item": "potion_hp_m", "chance": 0.12}]),
		_lt("lt_troll_big", [{"item": "troll_tusk", "chance": 0.6, "min": 1, "max": 2}, {"item": "troll_hide", "chance": 0.6, "min": 1, "max": 2}, {"item": "elixir_stone", "chance": 0.05}]),
		_lt("lt_orc_archer", [{"item": "ember_feather", "chance": 0.55, "min": 1, "max": 2}, {"item": "horde_badge", "chance": 0.3}, {"item": "potion_hp_m", "chance": 0.1}]),
		_lt("lt_orc_warrior", [{"item": "orc_steel", "chance": 0.5}, {"item": "orc_tusk", "chance": 0.4}, {"item": "horde_badge", "chance": 0.35}, {"item": "elixir_might", "chance": 0.04}]),
		_lt("lt_troll_king", [{"item": "rock_core", "chance": 1.0, "min": 2, "max": 3}, {"item": "troll_tusk", "chance": 1.0, "min": 4, "max": 6}, {"item": "elixir_stone", "chance": 1.0}]),
		_lt("lt_crossbow_master", [{"item": "ember_essence", "chance": 1.0, "min": 2, "max": 3}, {"item": "ember_feather", "chance": 1.0, "min": 4, "max": 6}, {"item": "elixir_might", "chance": 1.0}]),
		_lt("lt_ghar", [{"item": "ghar_badge", "chance": 1.0, "min": 2, "max": 3}, {"item": "orc_steel", "chance": 1.0, "min": 4, "max": 6}, {"item": "elixir_might", "chance": 1.0}]),
		# Ato II, Monte Kharzun (40-45): Pele de Lobo Atroz, Escama de Salamandra, Basalto Rúnico, Aço Negro Orc, Aço Anão, Brasa de Kharzun
		_lt("lt_goblin_assassin", [{"item": "goblin_fang", "chance": 0.5, "min": 1, "max": 2}, {"item": "horde_badge", "chance": 0.35}, {"item": "potion_hp_m", "chance": 0.12}]),
		_lt("lt_goblin_slayer", [{"item": "horde_badge", "chance": 1.0, "min": 2, "max": 3}, {"item": "dwarf_steel", "chance": 0.4}, {"item": "elixir_might", "chance": 0.05}]),
		_lt("lt_dire_wolf", [{"item": "dire_pelt", "chance": 0.6, "min": 1, "max": 2}, {"item": "potion_hp_m", "chance": 0.12}]),
		_lt("lt_dire_wolf_rider", [{"item": "dire_pelt", "chance": 0.6, "min": 1, "max": 2}, {"item": "rider_pelt", "chance": 0.4}, {"item": "horde_badge", "chance": 0.3}]),
		_lt("lt_troll_brute", [{"item": "troll_hide", "chance": 0.7, "min": 1, "max": 2}, {"item": "dwarf_steel", "chance": 0.45}, {"item": "troll_tusk", "chance": 0.5}, {"item": "elixir_stone", "chance": 0.05}]),
		_lt("lt_orc_fire_archer", [{"item": "ember_feather", "chance": 0.6, "min": 1, "max": 2}, {"item": "orc_steel", "chance": 0.3}, {"item": "potion_hp_m", "chance": 0.1}]),
		_lt("lt_orc_warlord", [{"item": "orc_steel", "chance": 0.7, "min": 1, "max": 3}, {"item": "horde_badge", "chance": 1.0, "min": 2, "max": 3}, {"item": "elixir_might", "chance": 0.05}]),
		_lt("lt_clan_guard", [{"item": "orc_steel", "chance": 0.7, "min": 1, "max": 3}, {"item": "dwarf_steel", "chance": 0.5}, {"item": "elixir_stone", "chance": 0.05}]),
		_lt("lt_lava_salamander", [{"item": "salamander_scale", "chance": 0.6, "min": 1, "max": 2}, {"item": "kharzun_ember_core", "chance": 0.08}, {"item": "potion_mp_m", "chance": 0.12}]),
		_lt("lt_basalt_golem", [{"item": "basalt_ore", "chance": 0.7, "min": 2, "max": 3}, {"item": "kharzun_ember_core", "chance": 0.35}, {"item": "elixir_stone", "chance": 0.05}]),
		# Ato II fase 3, Kharzun (40-45): materiais da montanha (Pele de Lobo Atroz, Basalto Rúnico, Brasa de Kharzun) e o troféu de cada chefe (WP10)
		_lt("lt_dire_mother", [{"item": "dire_pelt", "chance": 1.0, "min": 3, "max": 5}, {"item": "goblin_fang", "chance": 1.0, "min": 2, "max": 3}, {"item": "elixir_might", "chance": 0.4}]),
		_lt("lt_shazka", [{"item": "horde_badge", "chance": 1.0, "min": 4, "max": 6}, {"item": "goblin_fang", "chance": 1.0, "min": 3, "max": 5}, {"item": "elixir_might", "chance": 1.0}, {"item": "legend_coin", "chance": 0.3}]),
		_lt("lt_ulgra", [{"item": "dire_pelt", "chance": 1.0, "min": 4, "max": 6}, {"item": "orc_steel", "chance": 1.0, "min": 2, "max": 4}, {"item": "elixir_might", "chance": 1.0}, {"item": "ulgra_fang", "chance": 1.0}, {"item": "legend_coin", "chance": 0.3}]),
		_lt("lt_gorbash", [{"item": "basalt_ore", "chance": 1.0, "min": 2, "max": 4}, {"item": "basalt_heart", "chance": 1.0}, {"item": "troll_tusk", "chance": 1.0, "min": 4, "max": 6}, {"item": "elixir_stone", "chance": 1.0}, {"item": "legend_coin", "chance": 0.3}]),
		_lt("lt_kragmar", [{"item": "kharzun_ember_core", "chance": 1.0, "min": 2, "max": 4}, {"item": "broken_hammer", "chance": 1.0}, {"item": "orc_steel", "chance": 1.0, "min": 4, "max": 6}, {"item": "elixir_might", "chance": 1.0}, {"item": "legend_coin", "chance": 0.3}]),
		_lt("lt_durgash", [{"item": "durgash_banner", "chance": 1.0}, {"item": "ghar_badge", "chance": 1.0, "min": 3, "max": 5}, {"item": "orc_steel", "chance": 1.0, "min": 6, "max": 9}, {"item": "elixir_might", "chance": 1.0, "min": 1, "max": 2}, {"item": "legend_coin", "chance": 1.0, "min": 1, "max": 2}]),
		# Ato III, o Excesso (45-50): Fita do Festim (comum) e Porcelana Chorosa (rara, elites); troféus dos chefes ficam com o WP8
		_lt("lt_reveler", [{"item": "festim_ribbon", "chance": 0.55, "min": 1, "max": 2}, {"item": "potion_hp_m", "chance": 0.12}, {"item": "elixir_might", "chance": 0.02}]),
		_lt("lt_convert", [{"item": "festim_ribbon", "chance": 0.5, "min": 1, "max": 2}, {"item": "weeping_porcelain", "chance": 0.12}, {"item": "potion_hp_m", "chance": 0.1}]),
		_lt("lt_ceremony_master", [{"item": "festim_ribbon", "chance": 1.0, "min": 2, "max": 3}, {"item": "weeping_porcelain", "chance": 0.45}, {"item": "elixir_might", "chance": 0.05}]),
		_lt("lt_veil_dancer", [{"item": "festim_ribbon", "chance": 0.45, "min": 1, "max": 2}, {"item": "weeping_porcelain", "chance": 0.15}, {"item": "potion_hp_m", "chance": 0.1}]),
		_lt("lt_first_dancer", [{"item": "weeping_porcelain", "chance": 0.7, "min": 1, "max": 2}, {"item": "festim_ribbon", "chance": 1.0, "min": 2, "max": 3}, {"item": "elixir_might", "chance": 0.05}]),
		_lt("lt_silk_hound", [{"item": "festim_ribbon", "chance": 0.45}, {"item": "potion_hp_m", "chance": 0.12}]),
		_lt("lt_parade_alpha", [{"item": "festim_ribbon", "chance": 0.7, "min": 1, "max": 3}, {"item": "weeping_porcelain", "chance": 0.25}, {"item": "elixir_stone", "chance": 0.05}]),
		_lt("lt_seductress", [{"item": "festim_ribbon", "chance": 0.45, "min": 1, "max": 2}, {"item": "weeping_porcelain", "chance": 0.15}, {"item": "potion_hp_m", "chance": 0.1}]),
		_lt("lt_flayer", [{"item": "festim_ribbon", "chance": 0.5, "min": 1, "max": 2}, {"item": "weeping_porcelain", "chance": 0.15}, {"item": "potion_hp_m", "chance": 0.1}]),
		_lt("lt_veil_singer", [{"item": "weeping_porcelain", "chance": 0.35}, {"item": "festim_ribbon", "chance": 0.4, "min": 1, "max": 2}, {"item": "potion_mp_m", "chance": 0.14}]),
		_lt("lt_thirst_matriarch", [{"item": "weeping_porcelain", "chance": 0.7, "min": 1, "max": 2}, {"item": "festim_ribbon", "chance": 1.0, "min": 2, "max": 3}, {"item": "elixir_might", "chance": 0.05}]),
		_lt("lt_chorister", [{"item": "festim_ribbon", "chance": 0.5, "min": 1, "max": 2}, {"item": "potion_mp_m", "chance": 0.14}]),
		_lt("lt_choir_maestro", [{"item": "weeping_porcelain", "chance": 0.7, "min": 1, "max": 2}, {"item": "festim_ribbon", "chance": 1.0, "min": 2, "max": 3}, {"item": "elixir_might", "chance": 0.05}]),
		_lt("lt_vain_reflection", [{"item": "weeping_porcelain", "chance": 0.35}, {"item": "festim_ribbon", "chance": 0.4}, {"item": "potion_mp_m", "chance": 0.1}]),
		_lt("lt_living_censer", [{"item": "festim_ribbon", "chance": 0.6, "min": 1, "max": 2}, {"item": "weeping_porcelain", "chance": 0.15}, {"item": "elixir_stone", "chance": 0.04}]),
		_lt("lt_thirsty_vine", [{"item": "festim_ribbon", "chance": 0.4}, {"item": "bitter_grapes", "chance": 0.6, "min": 1, "max": 2}, {"item": "herb_green", "chance": 0.5, "min": 1, "max": 3}, {"item": "potion_hp_m", "chance": 0.1}]),
		# Ato III, chefes de mundo (WP8a): material de tier garantido (Porcelana Chorosa + Fitas); troféu próprio = pendente (§3 não lista)
		_lt("lt_vindima", [{"item": "weeping_porcelain", "chance": 1.0, "min": 2, "max": 3}, {"item": "festim_ribbon", "chance": 1.0, "min": 4, "max": 6}, {"item": "elixir_might", "chance": 1.0}, {"item": "legend_coin", "chance": 0.3}]),
		_lt("lt_prima_donna", [{"item": "weeping_porcelain", "chance": 1.0, "min": 2, "max": 3}, {"item": "festim_ribbon", "chance": 1.0, "min": 4, "max": 6}, {"item": "elixir_stone", "chance": 1.0}, {"item": "legend_coin", "chance": 0.3}]),
		# Ato III WP6: troféu do chefe (joias/capas 50, RecipesCatalog.LUMERIA_TROPHIES; WP11) + material de tier garantido
		_lt("lt_varo", [{"item": "varo_goblet", "chance": 1.0}, {"item": "weeping_porcelain", "chance": 1.0, "min": 2, "max": 3}, {"item": "festim_ribbon", "chance": 1.0, "min": 4, "max": 6}, {"item": "elixir_might", "chance": 1.0}, {"item": "legend_coin", "chance": 0.35}]),
		_lt("lt_countess", [{"item": "countess_frame", "chance": 1.0}, {"item": "weeping_porcelain", "chance": 1.0, "min": 2, "max": 3}, {"item": "festim_ribbon", "chance": 1.0, "min": 4, "max": 6}, {"item": "elixir_stone", "chance": 1.0}, {"item": "legend_coin", "chance": 0.35}]),
		_lt("lt_ressoa", [{"item": "broken_baton", "chance": 1.0}, {"item": "weeping_porcelain", "chance": 1.0, "min": 2, "max": 3}, {"item": "festim_ribbon", "chance": 1.0, "min": 4, "max": 6}, {"item": "elixir_might", "chance": 1.0}, {"item": "legend_coin", "chance": 0.35}]),
		_lt("lt_vessaline", [{"item": "hostess_fan", "chance": 1.0}, {"item": "weeping_porcelain", "chance": 1.0, "min": 3, "max": 4}, {"item": "festim_ribbon", "chance": 1.0, "min": 5, "max": 8}, {"item": "elixir_might", "chance": 1.0}, {"item": "legend_coin", "chance": 0.6}]),
		_lt("lt_sylvare_echo", [{"item": "empty_crown", "chance": 1.0}, {"item": "weeping_porcelain", "chance": 1.0, "min": 4, "max": 5}, {"item": "festim_ribbon", "chance": 1.0, "min": 6, "max": 9}, {"item": "elixir_stone", "chance": 1.0}, {"item": "legend_coin", "chance": 1.0, "min": 1, "max": 2}]),
		_lt("lt_dragonling", [{"item": "dragon_scale", "chance": 1.0, "min": 2, "max": 4}, {"item": "golem_core", "chance": 1.0, "min": 1, "max": 2}, {"item": "amulet_golem", "chance": 0.5}, {"item": "elixir_might", "chance": 1.0, "min": 1, "max": 2}, {"item": "crown_spectral", "chance": 0.4}]),
	] + _marsh_loot() + _viveiro_loot() + _oaths_loot() + _dawn_echo_loot()

# ======== Brejo das Teias (field_marsh, 12-16, campo opcional ao sul da Floresta; GDD design/gdd/brejo-das-teias.md §3.3) ========
## Modelos novos pedidos ao Blender (BLENDER REQUEST C); até o GLB existir, o monstro usa o modelo de reserva recolorido.
const MARSH_MODELS := {"bog_toad": ["mob_bog_toad", "mob_slime"], "bog_mother": ["mob_bog_mother", "mob_slime"], "web_weaver": ["mob_web_weaver", "mob_spider"]}
const MARSH_MOBS := ["marsh_leech", "bog_toad", "marsh_spider", "web_weaver", "marsh_smuggler"]
const MARSH_BOSS := "bog_mother"

static func marsh_model(id: String) -> String:
	var m: Array = MARSH_MODELS[id]
	return str(m[0]) if ResourceLoader.exists("res://assets/models/%s.glb" % m[0]) else str(m[1])

static func _marsh() -> Array:
	return [
		{"id": "marsh_leech", "name": "Sanguessuga do Brejo", "level": 12, "hp": 240, "atk": 30, "def": 4, "mdef": 5, "move_speed": 5.0, "attack_range": 1.4, "attack_cooldown": 0.9, "attack_startup": 0.2, "xp": 64, "aggro_range": 7.0, "leash_range": 20.0,
		 "radius": 0.38, "scale": 0.95, "color": Color(0.3, 0.36, 0.2), "shape": "capsule", "loot_table": "lt_marsh_leech", "gold_min": 6, "gold_max": 13, "model": "mob_larva"},
		{"id": "bog_toad", "name": "Sapo-Boi", "level": 13, "hp": 400, "atk": 40, "def": 9, "mdef": 6, "move_speed": 4.2, "attack_range": 1.8, "attack_cooldown": 1.3, "attack_startup": 0.4, "xp": 80, "aggro_range": 8.0, "leash_range": 20.0,
		 "radius": 0.6, "scale": 1.1, "color": Color(0.42, 0.5, 0.26), "shape": "sphere", "loot_table": "lt_bog_toad", "gold_min": 7, "gold_max": 15, "model": marsh_model("bog_toad"),
		 "skill_ids": ["mob_acid_spit"] as Array[String]},
		{"id": "marsh_spider", "name": "Aranha do Brejo", "level": 14, "hp": 380, "atk": 42, "def": 8, "mdef": 6, "move_speed": 4.7, "attack_range": 1.7, "attack_cooldown": 1.2, "attack_startup": 0.3, "xp": 84, "aggro_range": 8.0, "leash_range": 20.0,
		 "radius": 0.55, "scale": 1.05, "color": Color(0.38, 0.44, 0.28), "shape": "box", "loot_table": "lt_marsh_spider", "gold_min": 7, "gold_max": 16, "model": "mob_spider",
		 "skill_ids": ["mob_web"] as Array[String]},
		# atiradora: fica longe e solta poça de veneno (mesma ideia do Chamador: mate primeiro)
		{"id": "web_weaver", "name": "Tecelã do Brejo", "level": 15, "hp": 300, "atk": 16, "matk": 34, "def": 6, "mdef": 10, "move_speed": 4.4, "attack_range": 8.0, "attack_cooldown": 1.7, "attack_startup": 0.45, "xp": 90, "aggro_range": 10.0, "leash_range": 22.0, "ranged": true,
		 "radius": 0.5, "scale": 0.9, "color": Color(0.78, 0.7, 0.45), "shape": "box", "loot_table": "lt_web_weaver", "gold_min": 8, "gold_max": 18, "model": marsh_model("web_weaver"),
		 "skill_ids": ["mob_venom_pool"] as Array[String]},
		{"id": "marsh_smuggler", "name": "Contrabandista", "level": 15, "hp": 460, "atk": 47, "def": 10, "mdef": 7, "move_speed": 4.8, "attack_range": 1.8, "attack_cooldown": 1.1, "attack_startup": 0.3, "xp": 94, "aggro_range": 9.0, "leash_range": 22.0,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.3, 0.4, 0.42), "shape": "capsule", "loot_table": "lt_marsh_smuggler", "gold_min": 10, "gold_max": 22, "model": "mob_bandit_thief",
		 "skill_ids": ["mob_snare_shot"] as Array[String]},
		# mini-chefe do campo (Ponta da Bocarra): puxa com a língua, salta na barriga (chão avisado), chama girinos
		{"id": "bog_mother", "name": "Bocarra, a Sapa-Mãe", "level": 16, "hp": 62000, "atk": 86, "def": 13, "mdef": 12, "move_speed": 3.8, "attack_range": 2.4, "attack_cooldown": 1.4, "attack_startup": 0.4, "xp": 800, "aggro_range": 11.0, "leash_range": 25.0,
		 "radius": 1.1, "scale": 2.2, "color": Color(0.4, 0.48, 0.24), "shape": "sphere", "is_boss": true, "berserk_after": 150, "loot_table": "lt_bog_mother", "gold_min": 90, "gold_max": 180, "model": marsh_model("bog_mother"),
		 "skill_ids": ["mob_toad_tongue", "mob_bog_flop", "mob_acid_spit", "mob_call_tadpoles"] as Array[String],
		 "intro": "Mais um que cai na lama...", "last_words": "Croo... ac...",
		 "phases": [{"hp": 0.7, "say": "Croooac! Filhotes, jantar!", "summon": {"id": "bog_tadpole", "count": 3, "max": 5}},
			{"hp": 0.4, "say": "A Bocarra se enterra na lama e os girinos a cercam!", "skills": ["mob_venom_pool"], "ward": 0.4, "summon": {"id": "bog_tadpole", "count": 3, "max": 6}},
			{"hp": 0.15, "say": "A Bocarra infla e a lama ferve!", "enrage": 1.25}]},
		{"id": "bog_tadpole", "name": "Girino da Bocarra", "level": 16, "hp": 260, "atk": 30, "def": 6, "mdef": 6, "move_speed": 5.0, "attack_range": 1.4, "attack_cooldown": 1.0, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0,
		 "radius": 0.35, "scale": 0.6, "color": Color(0.22, 0.26, 0.18), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_larva"},
	]

static func _marsh_loot() -> Array:
	return [
		_lt("lt_marsh_leech", [{"item": "herb_green", "chance": 0.4}, {"item": "toad_skin", "chance": 0.1}, {"item": "potion_hp_m", "chance": 0.05}]),
		_lt("lt_bog_toad", [{"item": "toad_skin", "chance": 0.55}, {"item": "herb_blue", "chance": 0.3}, {"item": "cap_leather", "chance": 0.03}]),
		_lt("lt_marsh_spider", [{"item": "spider_silk", "chance": 0.6, "min": 1, "max": 2}, {"item": "amber_sap", "chance": 0.15}, {"item": "hood_silk", "chance": 0.04}]),
		_lt("lt_web_weaver", [{"item": "amber_sap", "chance": 0.4}, {"item": "spider_silk", "chance": 0.5}, {"item": "amulet_silk", "chance": 0.03}]),
		_lt("lt_marsh_smuggler", [{"item": "smuggler_ledger", "chance": 0.35}, {"item": "bandit_badge", "chance": 0.45}, {"item": "iron_ore", "chance": 0.3}, {"item": "potion_hp_m", "chance": 0.1}, {"item": "boots_wolf", "chance": 0.04}]),
		_lt("lt_bog_mother", [{"item": "bog_heart", "chance": 1.0}, {"item": "toad_skin", "chance": 1.0, "min": 3, "max": 5}, {"item": "amber_sap", "chance": 1.0, "min": 2, "max": 3}, {"item": "amulet_silk", "chance": 0.3}, {"item": "elixir_might", "chance": 0.5}]),
	]

# ======== Campo dos Juramentos (field_oaths, 24-28, campo opcional atrás da Escavação da Vera; GDD design/gdd/campo-dos-juramentos.md §3.3) ========
## Modelos novos do Blender (oaths_mobs.py); até o GLB existir, o monstro usa o modelo de reserva recolorido.
const OATHS_MODELS := {"carrion_crow": ["mob_carrion_crow", "mob_shaman_hawk"], "oath_sworn": ["mob_oath_sworn", "mob_loyal_knight"],
	"grave_hauler": ["mob_grave_hauler", "mob_bandit_thug"], "fallen_bearer": ["mob_fallen_bearer", "mob_death_knight"]}
const OATHS_MOBS := ["carrion_crow", "oath_sworn", "oath_archer", "vel_shade", "night_digger", "grave_hauler"]
const OATHS_BOSS := "fallen_bearer"
const OATHS_ADD := "oath_risen"

static func oaths_model(id: String) -> String:
	var m: Array = OATHS_MODELS[id]
	return str(m[0]) if ResourceLoader.exists("res://assets/models/%s.glb" % m[0]) else str(m[1])

static func _oaths() -> Array:
	return [
		# bando rápido e frágil: vem em 3-4 (Ruas, beira do Cemitério)
		{"id": "carrion_crow", "name": "Corvo de Carniça", "level": 24, "hp": 420, "atk": 60, "def": 8, "mdef": 10, "move_speed": 5.8, "attack_range": 1.6, "attack_cooldown": 0.9, "attack_startup": 0.2, "xp": 115, "aggro_range": 10.0, "leash_range": 22.0,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.16, 0.18, 0.26), "shape": "sphere", "loot_table": "lt_carrion_crow", "gold_min": 12, "gold_max": 26, "model": oaths_model("carrion_crow")},
		# escudo de frente (como o Guardião de Ossos): dê a volta e bata pelas costas
		{"id": "oath_sworn", "name": "Juramentado", "level": 25, "hp": 920, "atk": 86, "def": 30, "mdef": 14, "move_speed": 4.3, "attack_range": 1.9, "attack_cooldown": 1.3, "attack_startup": 0.35, "xp": 170, "aggro_range": 8.0, "leash_range": 22.0, "front_guard": 0.5,
		 "radius": 0.5, "scale": 1.0, "color": Color(0.72, 0.74, 0.76), "shape": "capsule", "loot_table": "lt_oath_sworn", "gold_min": 16, "gold_max": 34, "model": oaths_model("oath_sworn"),
		 "skill_ids": ["mob_charge"] as Array[String]},
		{"id": "oath_archer", "name": "Besteiro Juramentado", "level": 26, "hp": 480, "atk": 70, "def": 14, "mdef": 12, "move_speed": 4.2, "attack_range": 9.0, "attack_cooldown": 1.4, "attack_startup": 0.4, "xp": 150, "aggro_range": 10.0, "leash_range": 22.0, "ranged": true,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.7, 0.72, 0.74), "shape": "capsule", "loot_table": "lt_oath_archer", "gold_min": 15, "gold_max": 32, "model": "mob_loyal_crossbow",
		 "skill_ids": ["mob_volley"] as Array[String]},
		# morto da cidade antiga (sépia, não o azul do Lich): drena de longe
		{"id": "vel_shade", "name": "Sombra de Vel'Thar", "level": 27, "hp": 440, "atk": 30, "matk": 76, "def": 10, "mdef": 26, "move_speed": 4.2, "attack_range": 7.0, "attack_cooldown": 1.7, "attack_startup": 0.45, "xp": 160, "aggro_range": 9.0, "leash_range": 22.0, "ranged": true,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.78, 0.62, 0.38), "shape": "cone", "loot_table": "lt_vel_shade", "gold_min": 18, "gold_max": 40, "model": "mob_ghost",
		 "skill_ids": ["mob_soul_drain"] as Array[String]},
		{"id": "night_digger", "name": "Cavador da Noite", "level": 27, "hp": 520, "atk": 22, "matk": 74, "def": 10, "mdef": 24, "move_speed": 4.4, "attack_range": 8.0, "attack_cooldown": 1.6, "attack_startup": 0.45, "xp": 170, "aggro_range": 10.0, "leash_range": 22.0, "ranged": true,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.42, 0.32, 0.22), "shape": "capsule", "loot_table": "lt_night_digger", "gold_min": 18, "gold_max": 38, "model": "mob_cultist",
		 "skill_ids": ["mob_shadow_bolt"] as Array[String]},
		{"id": "grave_hauler", "name": "Carregador de Covas", "level": 28, "hp": 1150, "atk": 96, "def": 30, "mdef": 12, "move_speed": 4.3, "attack_range": 2.2, "attack_cooldown": 1.3, "attack_startup": 0.35, "xp": 230, "aggro_range": 9.0, "leash_range": 22.0,
		 "radius": 0.6, "scale": 1.1, "color": Color(0.26, 0.24, 0.24), "shape": "capsule", "loot_table": "lt_grave_hauler", "gold_min": 22, "gold_max": 46, "model": oaths_model("grave_hauler"),
		 "skill_ids": ["mob_bone_cleave"] as Array[String]},
		# mini-chefe do campo (Colina do Estandarte): leque do mastro na frente, estandarte fincado em quem está longe (ergue Juramentados)
		{"id": "fallen_bearer", "name": "Sir Edran, o Porta-Estandarte Caído", "level": 28, "hp": 72000, "atk": 110, "matk": 70, "def": 30, "mdef": 24, "move_speed": 4.4, "attack_range": 2.6, "attack_cooldown": 1.3, "attack_startup": 0.4, "xp": 1600, "aggro_range": 11.0, "leash_range": 25.0,
		 "radius": 0.7, "scale": 1.4, "color": Color(0.62, 0.6, 0.5), "shape": "capsule", "is_boss": true, "berserk_after": 160, "loot_table": "lt_fallen_bearer", "gold_min": 120, "gold_max": 240, "model": oaths_model("fallen_bearer"),
		 "skill_ids": ["mob_banner_sweep", "mob_banner_plant", "mob_charge"] as Array[String],
		 "intro": "Eu carreguei a Aurora até aqui. Depois carreguei outra coisa.", "last_words": "Diga ao Malcom... que o pano... ainda é dourado...",
		 "phases": [{"hp": 0.7, "say": "Levantem as fileiras! A linha não se rompe!", "summon": {"id": "oath_risen", "count": 2, "max": 4}},
			{"hp": 0.4, "say": "Sir Edran crava o mastro e as fileiras fecham em volta dele!", "ward": 0.4, "summon": {"id": "oath_risen", "count": 2, "max": 4}},
			{"hp": 0.15, "say": "Pela Aurora... pela noite... tanto faz!", "enrage": 1.25}]},
		{"id": "oath_risen", "name": "Juramentado Erguido", "level": 28, "hp": 340, "atk": 44, "def": 16, "mdef": 8, "move_speed": 4.2, "attack_range": 1.8, "attack_cooldown": 1.3, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0,
		 "radius": 0.45, "scale": 0.95, "color": Color(0.42, 0.44, 0.48), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": oaths_model("oath_sworn")},
	]

static func _oaths_loot() -> Array:
	return [
		_lt("lt_carrion_crow", [{"item": "carrion_feather", "chance": 0.55}, {"item": "bone_shard", "chance": 0.3}, {"item": "potion_hp_m", "chance": 0.05}]),
		_lt("lt_oath_sworn", [{"item": "oath_seal", "chance": 0.45}, {"item": "bone_shard", "chance": 0.4}, {"item": "holy_silver", "chance": 0.1}, {"item": "ring_spectral", "chance": 0.03}]),
		_lt("lt_oath_archer", [{"item": "oath_seal", "chance": 0.35}, {"item": "bone_shard", "chance": 0.5}, {"item": "star_ore", "chance": 0.2}]),
		_lt("lt_vel_shade", [{"item": "ghost_essence", "chance": 0.55}, {"item": "ancient_relic", "chance": 0.3}, {"item": "potion_mp_m", "chance": 0.1}, {"item": "crown_spectral", "chance": 0.03}]),
		_lt("lt_night_digger", [{"item": "digger_orders", "chance": 0.35}, {"item": "ancient_relic", "chance": 0.4}, {"item": "iron_ore", "chance": 0.3}, {"item": "potion_hp_m", "chance": 0.1}]),
		_lt("lt_grave_hauler", [{"item": "bone_shard", "chance": 0.6, "min": 1, "max": 2}, {"item": "holy_silver", "chance": 0.14}, {"item": "star_ore", "chance": 0.3}, {"item": "ring_spectral", "chance": 0.04}]),
		# material de tier do Campo: Estandarte da Aurora Caído garantido
		_lt("lt_fallen_bearer", [{"item": "fallen_standard", "chance": 1.0}, {"item": "oath_seal", "chance": 1.0, "min": 3, "max": 5}, {"item": "holy_silver", "chance": 1.0, "min": 2, "max": 3},
			{"item": "dawn_shard", "chance": 0.15}, {"item": "crown_spectral", "chance": 0.3}, {"item": "elixir_might", "chance": 0.5}]),
	]

# ======== Viveiro de Seiva (dg_viveiro, 17-19, mini-masmorra élfica sob a raiz do Brejo; GDD design/gdd/viveiro-de-seiva.md) ========
## Modelos novos do Blender (contrato production/session-state/viveiro-contract.md); até o GLB existir, reserva recolorida.
const VIVEIRO_MODELS := {"sap_sprout": ["mob_sap_sprout", "mob_trent"], "sap_tank": ["mob_sap_tank", "mob_dragon_egg"], "boss_sap_mother": ["mob_sap_mother", "mob_trent"]}
const VIVEIRO_MOBS := ["sap_sprout", "sap_spider", "elf_tender", "sap_tank"]
const VIVEIRO_BOSS := "boss_sap_mother"
const VIVEIRO_ADD := "sap_hatchling"

static func viveiro_model(id: String) -> String:
	var m: Array = VIVEIRO_MODELS[id]
	return str(m[0]) if ResourceLoader.exists("res://assets/models/%s.glb" % m[0]) else str(m[1])

static func _viveiro() -> Array:
	return [
		{"id": "sap_sprout", "name": "Muda de Seiva", "level": 17, "hp": 540, "atk": 52, "def": 11, "mdef": 8, "move_speed": 4.2, "attack_range": 1.8, "attack_cooldown": 1.3, "attack_startup": 0.35, "xp": 112, "aggro_range": 8.0, "leash_range": 20.0,
		 "radius": 0.55, "scale": 0.8, "color": Color(0.62, 0.5, 0.26), "shape": "capsule", "loot_table": "lt_sap_sprout", "gold_min": 9, "gold_max": 20, "model": viveiro_model("sap_sprout"),
		 "skill_ids": ["mob_sap_lash_small"] as Array[String]},
		# atiradora: fica longe e solta poça (a mesma da Tecelã do Brejo)
		{"id": "sap_spider", "name": "Aranha de Seiva", "level": 18, "hp": 420, "atk": 18, "matk": 46, "def": 8, "mdef": 12, "move_speed": 4.4, "attack_range": 8.0, "attack_cooldown": 1.7, "attack_startup": 0.45, "xp": 120, "aggro_range": 10.0, "leash_range": 22.0, "ranged": true,
		 "radius": 0.5, "scale": 0.95, "color": Color(0.9, 0.68, 0.28), "shape": "box", "loot_table": "lt_sap_spider", "gold_min": 9, "gold_max": 21, "model": "mob_spider",
		 "skill_ids": ["mob_venom_pool"] as Array[String]},
		# tratador élfico: atira de longe e rega (cura) as mudas e a Muda-Mãe em volta: mate primeiro
		{"id": "elf_tender", "name": "Tratador do Viveiro", "level": 18, "hp": 480, "atk": 20, "matk": 44, "def": 9, "mdef": 14, "move_speed": 4.6, "attack_range": 8.0, "attack_cooldown": 1.8, "attack_startup": 0.45, "xp": 124, "aggro_range": 10.0, "leash_range": 22.0, "ranged": true,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.7, 0.72, 0.35), "shape": "capsule", "loot_table": "lt_elf_tender", "gold_min": 10, "gold_max": 22, "model": "mob_elf_mage",
		 "skill_ids": ["mob_tender_mend"] as Array[String]},
		# tanque de vidro com uma muda dentro: parado, não revida, quebra (no Berço é o "ovo" da Muda-Mãe: choca nas fases)
		{"id": "sap_tank", "name": "Tanque de Seiva", "level": 18, "hp": 650, "atk": 1, "def": 14, "mdef": 14, "move_speed": 0.0, "attack_range": 0.0, "attack_cooldown": 60.0, "xp": 0, "aggro_range": 0.0, "leash_range": 40.0,
		 "radius": 0.6, "scale": 1.0, "color": Color(0.95, 0.75, 0.32), "shape": "capsule", "loot_table": "lt_sap_tank", "gold_min": 0, "gold_max": 0, "model": viveiro_model("sap_tank"), "egg": true},
		# chefe (O Berço): enraizada no tanque partido; os 4 tanques em volta despertam em mudas (70%: metade, 40%: o resto + ward)
		{"id": "boss_sap_mother", "name": "A Muda-Mãe", "level": 19, "hp": 86000, "atk": 98, "matk": 80, "def": 15, "mdef": 16, "move_speed": 2.6, "attack_range": 3.0, "attack_cooldown": 1.5, "attack_startup": 0.45, "xp": 1100, "aggro_range": 11.0, "leash_range": 22.0,
		 "radius": 1.8, "scale": 2.0, "color": Color(0.62, 0.48, 0.24), "shape": "capsule", "is_boss": true, "berserk_after": 150, "loot_table": "lt_sap_mother", "gold_min": 110, "gold_max": 220, "model": viveiro_model("boss_sap_mother"),
		 "skill_ids": ["mob_sap_lash", "mob_sap_root_hook", "mob_sap_rain"] as Array[String],
		 "intro": "Mais mãos... a seiva sempre manda mais mãos.", "last_words": "A raiz... ainda... bebe...",
		 "eggs": {"id": "sap_tank", "count": 4, "r": 7.0, "hatch": "sap_hatchling"},
		 "phases": [{"hp": 0.7, "say": "Bebam, pequenas! Acordem!", "skills": ["mob_sap_sprout_call"], "hatch": 0.5},
			{"hp": 0.4, "say": "A Muda-Mãe se fecha em casca enquanto as mudas a protegem!", "skills": ["mob_sap_pulse"], "ward": 0.5, "hatch": 1.0},
			{"hp": 0.15, "say": "A seiva ferve no Berço!", "enrage": 1.3}]},
		{"id": "sap_hatchling", "name": "Muda Desperta", "level": 19, "hp": 900, "atk": 46, "def": 12, "mdef": 10, "move_speed": 4.4, "attack_range": 1.8, "attack_cooldown": 1.3, "attack_startup": 0.35, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0,
		 "radius": 0.5, "scale": 0.75, "color": Color(0.9, 0.7, 0.3), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": viveiro_model("sap_sprout")},
	]

static func _viveiro_loot() -> Array:
	return [
		_lt("lt_sap_sprout", [{"item": "amber_sap", "chance": 0.45}, {"item": "ent_bark", "chance": 0.3}, {"item": "potion_hp_m", "chance": 0.06}]),
		_lt("lt_sap_spider", [{"item": "spider_silk", "chance": 0.5, "min": 1, "max": 2}, {"item": "amber_sap", "chance": 0.35}, {"item": "amulet_silk", "chance": 0.03}]),
		_lt("lt_elf_tender", [{"item": "amber_sap", "chance": 0.45}, {"item": "elf_steel", "chance": 0.3}, {"item": "potion_mp_m", "chance": 0.1}]),
		_lt("lt_sap_tank", [{"item": "amber_sap", "chance": 0.6, "min": 1, "max": 2}]),
		# material de tier do Gunnar: Seiva da Árvore-Mãe (Glória +6..+9, ItemSystem.enhance_cost) garantida
		_lt("lt_sap_mother", [{"item": "mother_sap", "chance": 1.0, "min": 2, "max": 3}, {"item": "amber_sap", "chance": 1.0, "min": 3, "max": 5}, {"item": "elf_steel", "chance": 1.0, "min": 2, "max": 3},
			{"item": "heartwood", "chance": 0.5}, {"item": "elixir_might", "chance": 0.5}, {"item": "legend_coin", "chance": 0.3}]),
	]

# ======== Restos da Noite e ecos dos chefes (faixa da Aurora 20-30, conquista B; GDD dawn-band-refactor-proposal §5 B, D5) ========
## Restos: o front retomado e o fundo do forte retomado (MapsCatalog.CATALOG_SPAWNERS, `if` = chefe do forte) ficam com mortos
## sem senhor para a caçada de 24-29. Modelos e loot dos monstros do front (sem modelo novo).
static func _dawn_rests() -> Array:
	return [
		{"id": "rest_ghoul", "name": "Carniçal do Brejo Seco", "level": 25, "hp": 700, "atk": 56, "def": 13, "mdef": 10, "move_speed": 5.0, "attack_range": 1.7, "attack_cooldown": 1.0, "attack_startup": 0.25, "xp": 150, "aggro_range": 9.0,
		 "radius": 0.45, "scale": 1.05, "color": Color(0.55, 0.52, 0.36), "shape": "capsule", "loot_table": "lt_rot", "gold_min": 14, "gold_max": 28, "model": "mob_ghoul",
		 "skill_ids": ["mob_venom_claw"] as Array[String]},
		{"id": "rest_bear", "name": "Urso do Brejo Seco", "level": 26, "hp": 1300, "atk": 122, "def": 24, "mdef": 12, "move_speed": 4.2, "attack_range": 2.2, "attack_cooldown": 1.4, "attack_startup": 0.4, "xp": 215, "aggro_range": 8.0,
		 "radius": 0.8, "scale": 1.3, "color": Color(0.44, 0.42, 0.3), "shape": "box", "loot_table": "lt_rot", "gold_min": 18, "gold_max": 36, "model": "mob_rot_bear",
		 "skill_ids": ["mob_rot_maul"] as Array[String]},
		{"id": "rest_bones", "name": "Ossos Sem Senhor", "level": 26, "hp": 1000, "atk": 92, "def": 22, "mdef": 11, "move_speed": 4.0, "attack_range": 1.8, "attack_cooldown": 1.2, "xp": 165, "aggro_range": 8.0,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.8, 0.78, 0.7), "shape": "capsule", "loot_table": "lt_bones", "gold_min": 18, "gold_max": 38, "model": "mob_skel_blade",
		 "skill_ids": ["mob_bone_cleave"] as Array[String]},
		{"id": "rest_bone_archer", "name": "Arqueiro Sem Senhor", "level": 27, "hp": 440, "atk": 66, "def": 13, "mdef": 11, "move_speed": 4.2, "attack_range": 9.0, "attack_cooldown": 1.6, "attack_startup": 0.4, "xp": 170, "aggro_range": 10.0, "ranged": true,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.78, 0.76, 0.66), "shape": "capsule", "loot_table": "lt_bones", "gold_min": 16, "gold_max": 34, "model": "mob_skel_archer",
		 "skill_ids": ["mob_volley"] as Array[String]},
		{"id": "rest_thaw_wraith", "name": "Espectro em Degelo", "level": 28, "hp": 500, "atk": 32, "matk": 82, "def": 11, "mdef": 28, "move_speed": 4.4, "attack_range": 7.0, "attack_cooldown": 1.7, "attack_startup": 0.45, "xp": 190, "aggro_range": 9.0, "ranged": true,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.7, 0.88, 0.95), "shape": "cone", "loot_table": "lt_ghost", "gold_min": 20, "gold_max": 42, "model": "mob_ghost",
		 "skill_ids": ["mob_frost_shard"] as Array[String]},
		{"id": "rest_lost_adept", "name": "Adepto Desgarrado", "level": 28, "hp": 460, "atk": 20, "matk": 80, "def": 9, "mdef": 24, "move_speed": 4.4, "attack_range": 8.0, "attack_cooldown": 1.6, "attack_startup": 0.45, "xp": 185, "aggro_range": 10.0, "ranged": true,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.36, 0.12, 0.16), "shape": "capsule", "loot_table": "lt_cult", "gold_min": 18, "gold_max": 38, "model": "mob_cultist",
		 "skill_ids": ["mob_shadow_bolt"] as Array[String]},
	]

## Eco do chefe (repetível): cópia do chefe do forte com outro nome, nível, vida/ataque/XP x Balance.DAWN_ECHO_*, sem moeda
## lendária e loot próprio (garante Prata Consagrada). Nasce no fundo do forte retomado (spawner `if` no catálogo, recarga
## Balance.DAWN_ECHO_RESPAWN); quem dá a caçada é a Capela dos Pedidos (QuestsCatalog.dawn_rests). Nenhuma regra nova na sim.
## chefe -> [id do eco, nome, nível, intro, últimas palavras]
const DAWN_ECHOES := {
	"ghoul_giant": ["echo_ghoul_giant", "Eco do Carniçal Gigante", 25, "A ninhada... ainda... tem fome.", "De novo... a terra... me cospe..."],
	"death_knight": ["echo_death_knight", "Eco de Vorhag", 27, "Eu jurei. Ainda não sei a quem.", "Malcom... você... ainda reza por mim?"],
	"frost_mage": ["echo_frost_mage", "Eco de Morvath", 29, "O gelo lembra o que eu esqueci.", "Derretendo... outra vez..."],
}
static func _dawn_echoes(L: Array) -> Array:
	var out: Array = []
	for d in L:
		if not DAWN_ECHOES.has(d["id"]):
			continue
		var e: Array = DAWN_ECHOES[d["id"]]
		var c: Dictionary = (d as Dictionary).duplicate(true)
		c["id"] = e[0]
		c["name"] = e[1]
		c["level"] = e[2]
		c["hp"] = int(round(float(d["hp"]) * Balance.DAWN_ECHO_HP))
		c["atk"] = int(round(float(d["atk"]) * Balance.DAWN_ECHO_ATK))
		if d.has("matk"):
			c["matk"] = int(round(float(d["matk"]) * Balance.DAWN_ECHO_ATK))
		c["xp"] = int(round(float(d["xp"]) * Balance.DAWN_ECHO_XP))
		c["intro"] = e[3]
		c["last_words"] = e[4]
		c["loot_table"] = "lt_" + e[0]
		c["coin_chance"] = 0.0
		c["coin_min"] = 0
		c["coin_max"] = 0
		c["gold_min"] = int(float(d["gold_min"]) * 0.5)
		c["gold_max"] = int(float(d["gold_max"]) * 0.5)
		out.append(c)
	return out

static func _dawn_echo_loot() -> Array:
	return [
		_lt("lt_echo_ghoul_giant", [{"item": "holy_silver", "chance": 1.0, "min": 1, "max": 2}, {"item": "rot_gel", "chance": 1.0, "min": 2, "max": 3}, {"item": "dawn_shard", "chance": 0.1}, {"item": "elixir_might", "chance": 0.2}]),
		_lt("lt_echo_death_knight", [{"item": "holy_silver", "chance": 1.0, "min": 1, "max": 2}, {"item": "bone_shard", "chance": 1.0, "min": 2, "max": 3}, {"item": "dawn_shard", "chance": 0.12}, {"item": "elixir_might", "chance": 0.2}]),
		_lt("lt_echo_frost_mage", [{"item": "holy_silver", "chance": 1.0, "min": 2, "max": 3}, {"item": "ghost_essence", "chance": 1.0, "min": 2, "max": 3}, {"item": "dawn_shard", "chance": 0.15}, {"item": "elixir_might", "chance": 0.2}]),
	]
