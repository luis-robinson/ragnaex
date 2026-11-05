class_name MonstersCatalog
extends RefCounted
## Monstros por área: Campina (1-10), Catacumbas (8-13), Floresta (10-20), Ruínas (20-30) + mini-bosses + invocação.

static func _mk(d: Dictionary) -> MonsterDef:
	var m := MonsterDef.new()
	for k in d:
		m.set(k, d[k])
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
		{"id": "boar", "name": "Javali", "level": 5, "hp": 95, "atk": 15, "def": 4, "mdef": 2, "move_speed": 4.2, "attack_range": 1.6, "attack_cooldown": 1.3, "attack_startup": 0.3, "xp": 24, "aggro_range": 6.0,
		 "radius": 0.55, "scale": 1.0, "color": Color(0.5, 0.35, 0.25), "shape": "box", "loot_table": "lt_boar", "gold_min": 3, "gold_max": 8, "model": "mob_boar"},
		{"id": "wolf", "name": "Lobo", "level": 7, "hp": 110, "atk": 19, "def": 5, "mdef": 3, "move_speed": 5.0, "attack_range": 1.7, "attack_cooldown": 1.1, "attack_startup": 0.25, "xp": 32, "aggro_range": 9.0,
		 "radius": 0.5, "scale": 1.0, "color": Color(0.5, 0.5, 0.55), "shape": "box", "loot_table": "lt_wolf", "gold_min": 4, "gold_max": 10, "model": "mob_wolf"},
		# Praia dos Caranguejos (margem sul do lago do Vale): casco duro, belisca; o Rei sai da água
		{"id": "crab", "name": "Caranguejo", "level": 4, "hp": 80, "atk": 12, "def": 7, "mdef": 2, "move_speed": 3.6, "attack_range": 1.6, "attack_cooldown": 1.3, "attack_startup": 0.3, "xp": 21, "aggro_range": 6.0,
		 "radius": 0.55, "scale": 0.95, "color": Color(0.86, 0.4, 0.28), "shape": "box", "loot_table": "lt_crab", "gold_min": 2, "gold_max": 6, "model": "mob_crab"},
		{"id": "crab_king", "name": "Caranguejo-Rei do Lago", "level": 8, "hp": 1700, "atk": 26, "def": 12, "mdef": 4, "move_speed": 3.4, "attack_range": 2.4, "attack_cooldown": 1.6, "attack_startup": 0.5, "xp": 190, "aggro_range": 9.0, "leash_range": 24.0,
		 "radius": 1.05, "scale": 2.0, "color": Color(0.72, 0.2, 0.22), "shape": "box", "is_boss": true, "loot_table": "lt_crab_king", "gold_min": 30, "gold_max": 60, "skill_ids": ["mob_whirl"] as Array[String], "model": "mob_crab",
		 "phases": [{"hp": 0.6, "say": "O Caranguejo-Rei estala as pinças: os filhotes saem do lago!", "summon": {"id": "crab_small", "count": 3, "max": 4}},
			{"hp": 0.3, "say": "KRRK-KRRK-KRRK!", "enrage": 1.3}]},
		# mini-chefe do bosque do Vale: nível 5 = sorteia o 1º conjunto lendário (25% como todo chefe)
		{"id": "boar_brute", "name": "Javali Presa-Rachada", "level": 5, "hp": 850, "atk": 20, "def": 6, "mdef": 3, "move_speed": 4.4, "attack_range": 2.0, "attack_cooldown": 1.4, "attack_startup": 0.4, "xp": 110, "aggro_range": 7.0, "leash_range": 22.0,
		 "radius": 0.75, "scale": 1.45, "color": Color(0.42, 0.24, 0.16), "shape": "box", "is_boss": true, "loot_table": "lt_boar_brute", "gold_min": 15, "gold_max": 35, "skill_ids": ["mob_charge"] as Array[String], "model": "mob_boar",
		 "phases": [{"hp": 0.5, "say": "O Presa-Rachada chama a vara!", "summon": {"id": "boar_piglet", "count": 2, "max": 3}},
			{"hp": 0.25, "say": "GRRRUUNF!", "enrage": 1.25}]},
		{"id": "boar_king", "name": "Rei Javali", "level": 10, "hp": 520, "atk": 26, "def": 8, "mdef": 5, "move_speed": 4.0, "attack_range": 2.2, "attack_cooldown": 1.5, "attack_startup": 0.45, "xp": 180, "aggro_range": 8.0, "leash_range": 25.0,
		 "radius": 0.9, "scale": 1.8, "color": Color(0.6, 0.3, 0.2), "shape": "box", "is_boss": true, "loot_table": "lt_boar_king", "gold_min": 30, "gold_max": 60, "skill_ids": ["mob_charge"] as Array[String], "model": "mob_boar"},
		# ---- Floresta (lv 10-20) ----
		{"id": "spider", "name": "Aranha Gigante", "level": 11, "hp": 180, "atk": 26, "def": 7, "mdef": 6, "move_speed": 4.6, "attack_range": 1.7, "attack_cooldown": 1.2, "xp": 48, "aggro_range": 8.0,
		 "radius": 0.55, "scale": 1.0, "color": Color(0.25, 0.2, 0.3), "shape": "box", "loot_table": "lt_spider", "gold_min": 6, "gold_max": 14, "model": "mob_spider"},
		{"id": "bandit", "name": "Bandido", "level": 13, "hp": 220, "atk": 30, "def": 9, "mdef": 7, "move_speed": 4.8, "attack_range": 1.8, "attack_cooldown": 1.0, "attack_startup": 0.25, "xp": 60, "aggro_range": 9.0,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.6, 0.25, 0.25), "shape": "capsule", "loot_table": "lt_bandit", "gold_min": 10, "gold_max": 24, "model": "mob_bandit"},
		{"id": "bandit_archer", "name": "Bandido Arqueiro", "level": 14, "hp": 170, "atk": 34, "def": 6, "mdef": 7, "move_speed": 4.6, "attack_range": 8.0, "attack_cooldown": 1.6, "attack_startup": 0.4, "xp": 62, "aggro_range": 10.0, "ranged": true,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.5, 0.35, 0.2), "shape": "capsule", "loot_table": "lt_bandit", "gold_min": 10, "gold_max": 24, "model": "mob_bandit"},
		{"id": "ent", "name": "Ent", "level": 17, "hp": 420, "atk": 40, "def": 16, "mdef": 8, "move_speed": 2.6, "attack_range": 2.4, "attack_cooldown": 1.8, "attack_startup": 0.5, "xp": 95, "aggro_range": 6.0,
		 "radius": 0.75, "scale": 1.5, "color": Color(0.35, 0.3, 0.2), "shape": "box", "loot_table": "lt_ent", "gold_min": 12, "gold_max": 28, "model": "mob_ent"},
		{"id": "bandit_chief", "name": "Chefe dos Bandidos", "level": 20, "hp": 1400, "atk": 52, "def": 18, "mdef": 14, "move_speed": 4.6, "attack_range": 2.2, "attack_cooldown": 1.1, "attack_startup": 0.3, "xp": 520, "aggro_range": 9.0, "leash_range": 25.0,
		 "radius": 0.6, "scale": 1.35, "color": Color(0.75, 0.15, 0.15), "shape": "capsule", "is_boss": true, "loot_table": "lt_bandit_chief", "gold_min": 80, "gold_max": 150, "skill_ids": ["mob_whirl"] as Array[String], "model": "mob_bandit"},
		# ---- Cerco élfico (lv 14-21): investidas na Floresta e a Cidade Élfica ----
		# investida (RaidSystem): rápidos, marcham do portal élfico até o Posto dos Caçadores
		{"id": "elf_raider", "name": "Batedor Élfico", "level": 15, "hp": 240, "atk": 34, "def": 9, "mdef": 9, "move_speed": 5.6, "attack_range": 1.8, "attack_cooldown": 1.0, "attack_startup": 0.25, "xp": 70, "aggro_range": 10.0, "leash_range": 20.0,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.45, 0.7, 0.4), "shape": "capsule", "loot_table": "lt_elf_raid", "gold_min": 10, "gold_max": 22, "model": "mob_elf_warrior", "skill_ids": ["mob_elf_lunge"] as Array[String]},
		{"id": "elf_raider_archer", "name": "Arqueiro Batedor", "level": 15, "hp": 180, "atk": 36, "def": 6, "mdef": 8, "move_speed": 5.4, "attack_range": 9.0, "attack_cooldown": 1.5, "attack_startup": 0.4, "xp": 70, "aggro_range": 11.0, "leash_range": 20.0, "ranged": true,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.55, 0.78, 0.45), "shape": "capsule", "loot_table": "lt_elf_raid", "gold_min": 10, "gold_max": 22, "model": "mob_elf_archer", "skill_ids": ["mob_root_arrow"] as Array[String]},
		{"id": "elf_lynx", "name": "Lince de Guerra", "level": 14, "hp": 170, "atk": 30, "def": 6, "mdef": 5, "move_speed": 6.2, "attack_range": 1.6, "attack_cooldown": 0.9, "attack_startup": 0.2, "xp": 55, "aggro_range": 9.0, "leash_range": 20.0,
		 "radius": 0.5, "scale": 1.05, "color": Color(0.7, 0.6, 0.35), "shape": "box", "loot_table": "lt_elf_lynx", "gold_min": 4, "gold_max": 10, "model": "mob_elf_lynx", "skill_ids": ["mob_pounce"] as Array[String]},
		# Cidade Élfica
		{"id": "elf_warrior", "name": "Guerreiro Élfico", "level": 18, "hp": 340, "atk": 44, "def": 13, "mdef": 11, "move_speed": 5.6, "attack_range": 1.9, "attack_cooldown": 1.0, "attack_startup": 0.25, "xp": 105, "aggro_range": 10.0,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.4, 0.62, 0.42), "shape": "capsule", "loot_table": "lt_elf", "gold_min": 14, "gold_max": 30, "model": "mob_elf_warrior", "skill_ids": ["mob_elf_lunge"] as Array[String]},
		{"id": "elf_archer", "name": "Arqueiro Élfico", "level": 18, "hp": 260, "atk": 46, "def": 9, "mdef": 10, "move_speed": 5.4, "attack_range": 9.0, "attack_cooldown": 1.5, "attack_startup": 0.4, "xp": 105, "aggro_range": 11.0, "ranged": true,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.5, 0.72, 0.42), "shape": "capsule", "loot_table": "lt_elf", "gold_min": 14, "gold_max": 30, "model": "mob_elf_archer", "skill_ids": ["mob_root_arrow"] as Array[String]},
		{"id": "griffin", "name": "Grifo", "level": 18, "hp": 520, "atk": 46, "def": 12, "mdef": 10, "move_speed": 6.0, "attack_range": 2.0, "attack_cooldown": 1.3, "attack_startup": 0.35, "xp": 130, "aggro_range": 11.0, "leash_range": 22.0,
		 "radius": 0.8, "scale": 1.4, "color": Color(0.85, 0.72, 0.45), "shape": "box", "loot_table": "lt_griffin", "gold_min": 12, "gold_max": 26, "model": "mob_griffin", "skill_ids": ["mob_dive"] as Array[String]},
		{"id": "trent", "name": "Trent Ancião", "level": 19, "hp": 2600, "atk": 48, "def": 26, "mdef": 12, "move_speed": 2.6, "attack_range": 2.6, "attack_cooldown": 2.0, "attack_startup": 0.6, "xp": 170, "aggro_range": 7.0,
		 "radius": 1.0, "scale": 2.0, "color": Color(0.32, 0.4, 0.22), "shape": "box", "loot_table": "lt_trent", "gold_min": 16, "gold_max": 34, "model": "mob_trent", "skill_ids": ["mob_root_grasp"] as Array[String]},
		{"id": "elf_warden", "name": "Guardião da Árvore", "level": 20, "hp": 3200, "atk": 60, "def": 20, "mdef": 16, "move_speed": 5.4, "attack_range": 2.0, "attack_cooldown": 1.0, "attack_startup": 0.3, "xp": 260, "aggro_range": 11.0, "leash_range": 24.0,
		 "radius": 0.55, "scale": 1.2, "color": Color(0.85, 0.75, 0.35), "shape": "capsule", "loot_table": "lt_elf_warden", "gold_min": 30, "gold_max": 60, "model": "mob_elf_warden",
		 "skill_ids": ["mob_elf_lunge", "mob_volley"] as Array[String], "coin_chance": 0.05, "coin_min": 4, "coin_max": 4},
		{"id": "elf_king", "name": "Rei Élfico Aelthar", "level": 21, "hp": 32000, "atk": 66, "def": 22, "mdef": 20, "move_speed": 5.0, "attack_range": 2.4, "attack_cooldown": 1.1, "attack_startup": 0.35, "xp": 900, "aggro_range": 11.0, "leash_range": 26.0,
		 "radius": 0.7, "scale": 1.6, "color": Color(0.95, 0.85, 0.4), "shape": "capsule", "is_boss": true, "loot_table": "lt_elf_king", "gold_min": 160, "gold_max": 300, "model": "mob_elf_king",
		 "skill_ids": ["mob_volley"] as Array[String], "coin_chance": 1.0, "coin_min": 4, "coin_max": 6,
		 "phases": [{"hp": 0.7, "say": "Guarda Real! Expulsem os invasores da Árvore-Mãe!", "summon": {"id": "king_guard", "count": 2, "max": 2}},
			{"hp": 0.45, "say": "A floresta inteira lutará por mim!", "skills": ["mob_king_roots"], "summon": {"id": "griffin_young", "count": 2, "max": 3}},
			{"hp": 0.2, "say": "Vocês jamais terão a Árvore-Mãe!", "enrage": 1.2}]},
		# ---- Ruínas (lv 20-30) ----
		{"id": "skeleton", "name": "Esqueleto", "level": 21, "hp": 380, "atk": 50, "def": 18, "mdef": 10, "move_speed": 4.0, "attack_range": 1.8, "attack_cooldown": 1.2, "xp": 120, "aggro_range": 8.0,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.9, 0.9, 0.8), "shape": "capsule", "loot_table": "lt_skeleton", "gold_min": 15, "gold_max": 35, "model": "mob_skeleton"},
		{"id": "ghost", "name": "Espectro", "level": 24, "hp": 320, "atk": 30, "matk": 62, "def": 10, "mdef": 26, "move_speed": 4.4, "attack_range": 7.0, "attack_cooldown": 1.7, "attack_startup": 0.45, "xp": 150, "aggro_range": 9.0, "ranged": true,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.6, 0.9, 1.0), "shape": "cone", "loot_table": "lt_ghost", "gold_min": 18, "gold_max": 40, "model": "mob_ghost"},
		{"id": "golem", "name": "Golem de Pedra", "level": 27, "hp": 1100, "atk": 70, "def": 34, "mdef": 18, "move_speed": 2.8, "attack_range": 2.6, "attack_cooldown": 2.0, "attack_startup": 0.6, "xp": 260, "aggro_range": 7.0,
		 "radius": 0.85, "scale": 1.7, "color": Color(0.5, 0.5, 0.45), "shape": "box", "loot_table": "lt_golem", "gold_min": 25, "gold_max": 60, "model": "mob_golem"},
		{"id": "dragonling", "name": "Dragonete Ancestral", "level": 30, "hp": 4200, "atk": 95, "matk": 90, "def": 36, "mdef": 30, "move_speed": 4.2, "attack_range": 2.8, "attack_cooldown": 1.3, "attack_startup": 0.4, "xp": 1600, "aggro_range": 10.0, "leash_range": 30.0,
		 "radius": 1.1, "scale": 2.2, "color": Color(0.8, 0.2, 0.3), "shape": "box", "is_boss": true, "loot_table": "lt_dragonling", "gold_min": 200, "gold_max": 400, "skill_ids": ["mob_firebreath"] as Array[String], "model": "mob_dragon"},
		# ---- chefes de dungeon (modelo de um monstro comum, maior) ----
		{"id": "slime_king", "name": "Rei Slime", "level": 11, "hp": 2800, "atk": 28, "def": 9, "mdef": 8, "move_speed": 3.4, "attack_range": 2.4, "attack_cooldown": 1.5, "attack_startup": 0.45, "xp": 240, "aggro_range": 9.0, "leash_range": 25.0,
		 "radius": 1.0, "scale": 2.0, "color": Color(0.3, 0.5, 0.95), "shape": "sphere", "is_boss": true, "loot_table": "lt_slime_king", "gold_min": 35, "gold_max": 70, "skill_ids": ["mob_charge"] as Array[String], "model": "mob_slime",
		 "phases": [{"hp": 0.6, "say": "Blub... o rei se divide!", "skills": ["mob_acid_spit"], "summon": {"id": "slimeling", "count": 3, "max": 4}},
			{"hp": 0.25, "say": "BLUUUB!", "summon": {"id": "slimeling", "count": 2, "max": 4}, "enrage": 1.3}]},
		{"id": "spider_queen", "name": "Rainha Aranha", "level": 20, "hp": 5000, "atk": 56, "def": 18, "mdef": 15, "move_speed": 4.6, "attack_range": 2.4, "attack_cooldown": 1.2, "attack_startup": 0.35, "xp": 640, "aggro_range": 10.0, "leash_range": 25.0,
		 "radius": 1.0, "scale": 1.9, "color": Color(0.45, 0.2, 0.55), "shape": "box", "is_boss": true, "loot_table": "lt_spider_queen", "gold_min": 90, "gold_max": 170, "skill_ids": ["mob_whirl"] as Array[String], "model": "mob_spider",
		 "phases": [{"hp": 0.65, "say": "Filhotes... o jantar chegou.", "skills": ["mob_web"], "summon": {"id": "spiderling", "count": 3, "max": 5}},
			{"hp": 0.3, "say": "Ninguém sai do meu ninho!", "summon": {"id": "spiderling", "count": 2, "max": 5}, "enrage": 1.3}]},
		{"id": "crypt_lord", "name": "Senhor da Cripta", "level": 29, "hp": 7000, "atk": 88, "matk": 80, "def": 32, "mdef": 28, "move_speed": 4.0, "attack_range": 2.6, "attack_cooldown": 1.3, "attack_startup": 0.4, "xp": 1300, "aggro_range": 10.0, "leash_range": 28.0,
		 "radius": 0.9, "scale": 1.8, "color": Color(0.6, 0.45, 0.85), "shape": "capsule", "is_boss": true, "loot_table": "lt_crypt_lord", "gold_min": 160, "gold_max": 320, "skill_ids": ["mob_firebreath"] as Array[String], "model": "mob_skeleton",
		 "phases": [{"hp": 0.7, "say": "Vel'Thar não dorme sozinho.", "summon": {"id": "crypt_thrall", "count": 2, "max": 4}},
			{"hp": 0.35, "say": "Seu fôlego agora é meu.", "skills": ["mob_soul_drain"]}]},
		# ---- Catacumbas do Conde (lv 8-13) ----
		{"id": "zombie", "name": "Morto Andante", "level": 8, "hp": 160, "atk": 20, "def": 6, "mdef": 3, "move_speed": 2.7, "attack_range": 1.6, "attack_cooldown": 1.5, "attack_startup": 0.4, "xp": 36, "aggro_range": 7.0,
		 "radius": 0.5, "scale": 1.0, "color": Color(0.5, 0.6, 0.4), "shape": "capsule", "loot_table": "lt_zombie", "gold_min": 4, "gold_max": 11, "model": "mob_zombie"},
		{"id": "bone_recruit", "name": "Recruta de Ossos", "level": 9, "hp": 140, "atk": 23, "def": 7, "mdef": 4, "move_speed": 4.0, "attack_range": 1.7, "attack_cooldown": 1.2, "xp": 40, "aggro_range": 8.0,
		 "radius": 0.45, "scale": 0.95, "color": Color(0.85, 0.85, 0.75), "shape": "capsule", "loot_table": "lt_bone_recruit", "gold_min": 5, "gold_max": 12, "model": "mob_skeleton"},
		{"id": "bone_archer", "name": "Arqueiro de Ossos", "level": 10, "hp": 110, "atk": 25, "def": 5, "mdef": 4, "move_speed": 3.8, "attack_range": 8.0, "attack_cooldown": 1.7, "attack_startup": 0.45, "xp": 44, "aggro_range": 10.0, "ranged": true,
		 "radius": 0.45, "scale": 0.95, "color": Color(0.8, 0.8, 0.65), "shape": "capsule", "loot_table": "lt_bone_recruit", "gold_min": 5, "gold_max": 12, "model": "mob_skeleton"},
		{"id": "ghoul", "name": "Carniçal", "level": 11, "hp": 190, "atk": 27, "def": 8, "mdef": 5, "move_speed": 4.8, "attack_range": 1.7, "attack_cooldown": 1.1, "attack_startup": 0.28, "xp": 50, "aggro_range": 9.0,
		 "radius": 0.5, "scale": 1.1, "color": Color(0.45, 0.5, 0.45), "shape": "capsule", "loot_table": "lt_zombie", "gold_min": 6, "gold_max": 14, "model": "mob_zombie"},
		{"id": "wraith", "name": "Aparição", "level": 12, "hp": 150, "atk": 18, "matk": 31, "def": 5, "mdef": 12, "move_speed": 4.2, "attack_range": 7.0, "attack_cooldown": 1.7, "attack_startup": 0.45, "xp": 56, "aggro_range": 9.0, "ranged": true,
		 "radius": 0.45, "scale": 0.9, "color": Color(0.55, 0.75, 0.95), "shape": "cone", "loot_table": "lt_wraith", "gold_min": 7, "gold_max": 15, "model": "mob_ghost"},
		{"id": "bone_servant", "name": "Ossada Erguida", "level": 9, "hp": 200, "atk": 20, "def": 3, "mdef": 3, "move_speed": 4.4, "attack_range": 1.6, "attack_cooldown": 1.3, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0,
		 "radius": 0.4, "scale": 0.8, "color": Color(0.8, 0.85, 0.7), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_skeleton"},
		{"id": "lost_soul", "name": "Alma Penada", "level": 10, "hp": 150, "atk": 10, "matk": 20, "def": 2, "mdef": 8, "move_speed": 4.0, "attack_range": 6.0, "attack_cooldown": 1.8, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0, "ranged": true,
		 "radius": 0.4, "scale": 0.7, "color": Color(0.6, 0.85, 1.0), "shape": "cone", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_ghost"},
		{"id": "bone_captain", "name": "Capitão de Ossos", "level": 10, "hp": 3800, "atk": 30, "def": 10, "mdef": 7, "move_speed": 4.0, "attack_range": 2.4, "attack_cooldown": 1.4, "attack_startup": 0.4, "xp": 300, "aggro_range": 10.0, "leash_range": 26.0,
		 "radius": 0.9, "scale": 1.7, "color": Color(0.9, 0.82, 0.6), "shape": "capsule", "is_boss": true, "loot_table": "lt_bone_captain", "gold_min": 40, "gold_max": 80, "skill_ids": ["mob_charge", "mob_whirl"] as Array[String], "model": "mob_skeleton",
		 "phases": [{"hp": 0.66, "say": "De pé, soldados!", "summon": {"id": "bone_servant", "count": 2, "max": 4}},
			{"hp": 0.33, "say": "A guarda do Conde não cai!", "summon": {"id": "bone_servant", "count": 3, "max": 4}}]},
		{"id": "wailing_widow", "name": "Viúva Lamentosa", "level": 11, "hp": 3300, "atk": 18, "matk": 28, "def": 7, "mdef": 14, "move_speed": 3.8, "attack_range": 7.0, "attack_cooldown": 1.6, "attack_startup": 0.45, "xp": 340, "aggro_range": 11.0, "leash_range": 26.0, "ranged": true,
		 "radius": 0.8, "scale": 1.6, "color": Color(0.7, 0.8, 1.0), "shape": "cone", "is_boss": true, "loot_table": "lt_wailing_widow", "gold_min": 45, "gold_max": 90, "skill_ids": ["mob_wail"] as Array[String], "model": "mob_ghost",
		 "phases": [{"hp": 0.5, "say": "Ele prometeu que voltaria...", "skills": ["mob_grave_touch"], "summon": {"id": "lost_soul", "count": 3, "max": 3}}]},
		{"id": "count_vargo", "name": "Conde Vargo", "level": 13, "hp": 26000, "atk": 54, "matk": 56, "def": 12, "mdef": 14, "move_speed": 4.0, "attack_range": 2.6, "attack_cooldown": 1.3, "attack_startup": 0.4, "xp": 800, "aggro_range": 12.0, "leash_range": 30.0,
		 "radius": 0.9, "scale": 1.8, "color": Color(0.5, 0.35, 0.75), "shape": "capsule", "is_boss": true, "loot_table": "lt_count_vargo", "gold_min": 80, "gold_max": 160, "skill_ids": ["mob_soul_drain", "mob_whirl"] as Array[String], "model": "mob_lich",
		 "phases": [{"hp": 0.7, "say": "Aldara ainda me deve 300 anos.", "skills": ["mob_raise_dead"], "summon": {"id": "bone_servant", "count": 2, "max": 4}},
			{"hp": 0.3, "say": "Basta. Ajoelhem-se!", "skills": ["mob_death_wave"], "summon": {"id": "lost_soul", "count": 2, "max": 2}, "enrage": 1.35}]},
		# ---- lacaios dos chefes antigos (0 XP) ----
		{"id": "crab_small", "name": "Caranguejinho", "level": 5, "hp": 50, "atk": 10, "def": 4, "mdef": 1, "move_speed": 4.2, "attack_range": 1.3, "attack_cooldown": 1.1, "xp": 0, "aggro_range": 14.0, "leash_range": 30.0,
		 "radius": 0.35, "scale": 0.55, "color": Color(0.95, 0.56, 0.36), "shape": "box", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_crab"},
		{"id": "boar_piglet", "name": "Leitão", "level": 4, "hp": 45, "atk": 9, "def": 2, "mdef": 1, "move_speed": 4.6, "attack_range": 1.3, "attack_cooldown": 1.2, "xp": 0, "aggro_range": 14.0, "leash_range": 30.0,
		 "radius": 0.35, "scale": 0.6, "color": Color(0.62, 0.42, 0.3), "shape": "box", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_boar"},
		{"id": "slimeling", "name": "Slimezinho", "level": 8, "hp": 110, "atk": 14, "def": 3, "mdef": 3, "move_speed": 4.2, "attack_range": 1.4, "attack_cooldown": 1.3, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0,
		 "radius": 0.4, "scale": 0.75, "color": Color(0.35, 0.6, 1.0), "shape": "sphere", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_slime"},
		{"id": "spiderling", "name": "Filhote de Aranha", "level": 17, "hp": 260, "atk": 34, "def": 9, "mdef": 7, "move_speed": 5.0, "attack_range": 1.5, "attack_cooldown": 1.1, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0,
		 "radius": 0.4, "scale": 0.7, "color": Color(0.5, 0.3, 0.6), "shape": "box", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_spider"},
		{"id": "crypt_thrall", "name": "Servo da Cripta", "level": 26, "hp": 260, "atk": 32, "def": 14, "mdef": 10, "move_speed": 4.2, "attack_range": 1.7, "attack_cooldown": 1.3, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0,
		 "radius": 0.45, "scale": 0.9, "color": Color(0.7, 0.6, 0.85), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_skeleton"},
		{"id": "king_guard", "name": "Guarda Real Élfico", "level": 20, "hp": 900, "atk": 40, "def": 16, "mdef": 12, "move_speed": 5.4, "attack_range": 1.9, "attack_cooldown": 1.1, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0,
		 "radius": 0.45, "scale": 1.1, "color": Color(0.8, 0.72, 0.4), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_elf_warrior", "skill_ids": ["mob_elf_lunge"] as Array[String]},
		{"id": "griffin_young", "name": "Grifo Jovem", "level": 19, "hp": 300, "atk": 36, "def": 9, "mdef": 8, "move_speed": 6.0, "attack_range": 1.8, "attack_cooldown": 1.2, "xp": 0, "aggro_range": 14.0, "leash_range": 40.0,
		 "radius": 0.6, "scale": 1.05, "color": Color(0.9, 0.8, 0.55), "shape": "box", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_griffin"},
		# ---- sentinelas do Posto dos Caçadores (NPC com `fighter`; atributos e alcance daqui, visual do kit) ----
		{"id": "guard_archer", "name": "Caçadora do Posto", "level": 18, "hp": 600, "atk": 31, "def": 14, "mdef": 12, "move_speed": 4.8, "attack_range": 10.0, "attack_cooldown": 1.5, "attack_startup": 0.4, "xp": 0, "ranged": true,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.45, 0.55, 0.35), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0},
		{"id": "guard_warrior", "name": "Soldado do Posto", "level": 18, "hp": 900, "atk": 29, "def": 20, "mdef": 14, "move_speed": 4.8, "attack_range": 1.9, "attack_cooldown": 1.2, "attack_startup": 0.3, "xp": 0,
		 "radius": 0.45, "scale": 1.0, "color": Color(0.5, 0.5, 0.58), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0},
		# ---- companheiro do Ranger Caçador (vida/ataque vêm do dono) ----
		{"id": "companion", "name": "Lince", "level": 1, "hp": 100, "atk": 10, "def": 5, "mdef": 5, "move_speed": 6.4, "attack_range": 1.6, "attack_cooldown": 0.9, "xp": 0,
		 "radius": 0.5, "scale": 1.0, "color": Color(0.82, 0.62, 0.36), "shape": "box", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_lynx"},
		# ---- invocações do Druida (Xamã) ----
		{"id": "spirit_wolf", "name": "Lobo Espiritual", "level": 1, "hp": 70, "atk": 13, "def": 3, "mdef": 3, "move_speed": 6.0, "attack_range": 1.6, "attack_cooldown": 0.9, "xp": 0,
		 "radius": 0.45, "scale": 0.85, "color": Color(0.5, 0.95, 0.65), "shape": "box", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_wolf"},
		{"id": "treant", "name": "Ent Guardião", "level": 1, "hp": 150, "atk": 15, "def": 10, "mdef": 6, "move_speed": 3.6, "attack_range": 2.0, "attack_cooldown": 1.4, "xp": 0,
		 "radius": 0.7, "scale": 0.8, "color": Color(0.45, 0.7, 0.35), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_ent",
		 "skill_ids": ["mob_whirl"] as Array[String]},
		# ---- elementais do Elementalista (ataque = parte do MATK do dono) ----
		{"id": "fire_elemental", "name": "Elemental de Fogo", "level": 1, "hp": 90, "atk": 12, "def": 4, "mdef": 8, "move_speed": 5.0, "attack_range": 5.0, "attack_cooldown": 1.2, "xp": 0,
		 "radius": 0.45, "scale": 0.9, "color": Color(1.0, 0.45, 0.15), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_elemental_fire",
		 "skill_ids": ["mob_firebreath"] as Array[String]},
		{"id": "frost_elemental", "name": "Elemental de Gelo", "level": 1, "hp": 120, "atk": 10, "def": 8, "mdef": 8, "move_speed": 4.6, "attack_range": 5.0, "attack_cooldown": 1.3, "xp": 0,
		 "radius": 0.5, "scale": 0.95, "color": Color(0.55, 0.85, 1.0), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_elemental_frost",
		 "skill_ids": ["mob_frost_shard"] as Array[String]},
		{"id": "storm_elemental", "name": "Elemental de Raio", "level": 1, "hp": 80, "atk": 13, "def": 3, "mdef": 8, "move_speed": 5.6, "attack_range": 5.0, "attack_cooldown": 1.0, "xp": 0,
		 "radius": 0.45, "scale": 0.9, "color": Color(0.75, 0.75, 1.0), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_elemental_storm",
		 "skill_ids": ["mob_static_bolt"] as Array[String]},
		# ---- invocações do Necromancer (cão, lich, rei) ----
		{"id": "bone_hound", "name": "Cão de Ossos", "level": 1, "hp": 70, "atk": 13, "def": 4, "mdef": 4, "move_speed": 6.6, "attack_range": 1.6, "attack_cooldown": 0.8, "xp": 0,
		 "radius": 0.45, "scale": 0.85, "color": Color(0.9, 0.88, 0.8), "shape": "box", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_bone_hound"},
		{"id": "lich_servant", "name": "Lich Servo", "level": 1, "hp": 110, "atk": 16, "def": 4, "mdef": 14, "move_speed": 4.6, "attack_range": 7.0, "attack_cooldown": 1.5, "xp": 0,
		 "radius": 0.45, "scale": 0.95, "color": Color(0.55, 0.8, 1.0), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_lich",
		 "skill_ids": ["mob_frost_shard", "mob_frost_ring"] as Array[String]},
		{"id": "skeleton_king", "name": "Rei Esqueleto", "level": 1, "hp": 260, "atk": 24, "def": 14, "mdef": 8, "move_speed": 4.4, "attack_range": 2.2, "attack_cooldown": 1.3, "xp": 0,
		 "radius": 0.7, "scale": 1.35, "color": Color(0.9, 0.85, 0.6), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_skeleton_king",
		 "skill_ids": ["mob_whirl"] as Array[String]},
		# ---- invocação do Necromancer ----
		{"id": "skeleton_minion", "name": "Esqueleto Servo", "level": 1, "hp": 60, "atk": 12, "def": 4, "mdef": 4, "move_speed": 5.2, "attack_range": 1.6, "attack_cooldown": 1.0, "xp": 0,
		 "radius": 0.4, "scale": 0.9, "color": Color(0.8, 0.95, 0.85), "shape": "capsule", "loot_table": "", "gold_min": 0, "gold_max": 0, "model": "mob_skeleton"},
	]
	var out: Array = []
	for d in L:
		out.append(_mk(d))
	return out

static func build_loot() -> Array:
	return [
		_lt("lt_slime", [{"item": "slime_gel", "chance": 0.7, "min": 1, "max": 2}, {"item": "herb_green", "chance": 0.25}, {"item": "ring_gel", "chance": 0.03}]),
		_lt("lt_slime_blue", [{"item": "slime_gel", "chance": 0.6}, {"item": "herb_blue", "chance": 0.45}, {"item": "potion_mp_s", "chance": 0.1}]),
		_lt("lt_boar", [{"item": "boar_tusk", "chance": 0.5}, {"item": "herb_green", "chance": 0.3}, {"item": "cap_leather", "chance": 0.05}, {"item": "boots_leather", "chance": 0.05}]),
		_lt("lt_wolf", [{"item": "wolf_pelt", "chance": 0.6}, {"item": "iron_ore", "chance": 0.35}, {"item": "potion_hp_s", "chance": 0.12}]),
		# chefes com tabela própria (antes dividiam a do Rei Javali / Chefe dos Bandidos)
		_lt("lt_slime_king", [{"item": "slime_gel", "chance": 1.0, "min": 6, "max": 10}, {"item": "ring_gel", "chance": 0.5}, {"item": "herb_blue", "chance": 1.0, "min": 3, "max": 5}, {"item": "potion_mp_m", "chance": 0.6}]),
		_lt("lt_spider_queen", [{"item": "spider_silk", "chance": 1.0, "min": 6, "max": 9}, {"item": "amulet_silk", "chance": 0.5}, {"item": "hood_silk", "chance": 0.4}, {"item": "elixir_stone", "chance": 0.5}]),
		_lt("lt_crypt_lord", [{"item": "ghost_essence", "chance": 1.0, "min": 4, "max": 6}, {"item": "bone_shard", "chance": 1.0, "min": 4, "max": 7}, {"item": "ring_spectral", "chance": 0.45}, {"item": "crown_spectral", "chance": 0.3}, {"item": "elixir_might", "chance": 1.0}]),
		_lt("lt_crab", [{"item": "crab_shell", "chance": 0.55}, {"item": "herb_blue", "chance": 0.15}, {"item": "slime_gel", "chance": 0.2}]),
		_lt("lt_crab_king", [{"item": "crab_shell", "chance": 1.0, "min": 3, "max": 5}, {"item": "elixir_stone", "chance": 0.45}, {"item": "amulet_tusk", "chance": 0.2}, {"item": "iron_ore", "chance": 0.8, "min": 2, "max": 3}]),
		_lt("lt_boar_brute", [{"item": "boar_tusk", "chance": 1.0, "min": 2, "max": 3}, {"item": "amulet_tusk", "chance": 0.25}, {"item": "elixir_might", "chance": 0.3}, {"item": "herb_green", "chance": 0.6, "min": 1, "max": 3}]),
		_lt("lt_boar_king", [{"item": "boar_tusk", "chance": 1.0, "min": 3, "max": 5}, {"item": "amulet_tusk", "chance": 0.5}, {"item": "iron_ore", "chance": 1.0, "min": 2, "max": 4}, {"item": "elixir_might", "chance": 0.4}]),
		_lt("lt_spider", [{"item": "spider_silk", "chance": 0.6, "min": 1, "max": 2}, {"item": "herb_blue", "chance": 0.3}, {"item": "hood_silk", "chance": 0.04}]),
		_lt("lt_bandit", [{"item": "bandit_badge", "chance": 0.55}, {"item": "iron_ore", "chance": 0.4}, {"item": "potion_hp_m", "chance": 0.1}, {"item": "helm_iron", "chance": 0.04}, {"item": "boots_wolf", "chance": 0.04}]),
		_lt("lt_ent", [{"item": "ent_bark", "chance": 0.7, "min": 1, "max": 2}, {"item": "herb_green", "chance": 0.5, "min": 1, "max": 3}, {"item": "elixir_stone", "chance": 0.08}]),
		_lt("lt_bandit_chief", [{"item": "bandit_badge", "chance": 1.0, "min": 3, "max": 5}, {"item": "ent_bark", "chance": 1.0, "min": 2, "max": 3}, {"item": "amulet_silk", "chance": 0.5}, {"item": "helm_bone", "chance": 0.3}, {"item": "elixir_might", "chance": 0.5}]),
		_lt("lt_elf_raid", [{"item": "elf_steel", "chance": 0.12}, {"item": "potion_hp_m", "chance": 0.12}, {"item": "herb_blue", "chance": 0.3}]),
		_lt("lt_elf_lynx", [{"item": "wolf_pelt", "chance": 0.5}, {"item": "potion_hp_s", "chance": 0.1}]),
		_lt("lt_elf", [{"item": "elf_steel", "chance": 0.45, "min": 1, "max": 2}, {"item": "potion_hp_m", "chance": 0.12}, {"item": "herb_blue", "chance": 0.3}]),
		_lt("lt_griffin", [{"item": "griffin_feather", "chance": 0.6, "min": 1, "max": 2}, {"item": "elf_steel", "chance": 0.2}]),
		_lt("lt_trent", [{"item": "heartwood", "chance": 0.65}, {"item": "ent_bark", "chance": 0.6, "min": 1, "max": 3}, {"item": "mother_sap", "chance": 0.05}]),
		_lt("lt_elf_warden", [{"item": "elf_steel", "chance": 1.0, "min": 2, "max": 3}, {"item": "mother_sap", "chance": 0.35}, {"item": "elixir_might", "chance": 0.25}]),
		_lt("lt_elf_king", [{"item": "mother_sap", "chance": 1.0, "min": 3, "max": 5}, {"item": "elf_steel", "chance": 1.0, "min": 4, "max": 6}, {"item": "heartwood", "chance": 1.0, "min": 2, "max": 3}, {"item": "elixir_might", "chance": 1.0}]),
		_lt("lt_skeleton", [{"item": "bone_shard", "chance": 0.65, "min": 1, "max": 2}, {"item": "iron_ore", "chance": 0.4}, {"item": "potion_hp_m", "chance": 0.12}]),
		_lt("lt_ghost", [{"item": "ghost_essence", "chance": 0.55}, {"item": "herb_blue", "chance": 0.4, "min": 1, "max": 2}, {"item": "potion_mp_m", "chance": 0.12}, {"item": "ring_spectral", "chance": 0.03}]),
		_lt("lt_golem", [{"item": "golem_core", "chance": 0.35}, {"item": "iron_ore", "chance": 1.0, "min": 2, "max": 4}, {"item": "bone_shard", "chance": 0.5}, {"item": "boots_ent", "chance": 0.05}]),
		_lt("lt_zombie", [{"item": "grave_dust", "chance": 0.55}, {"item": "bone_shard", "chance": 0.2}, {"item": "potion_hp_s", "chance": 0.12}]),
		_lt("lt_bone_recruit", [{"item": "bone_shard", "chance": 0.45}, {"item": "iron_ore", "chance": 0.35}, {"item": "potion_hp_s", "chance": 0.1}]),
		_lt("lt_wraith", [{"item": "grave_dust", "chance": 0.5}, {"item": "herb_blue", "chance": 0.4}, {"item": "potion_mp_s", "chance": 0.15}]),
		_lt("lt_bone_captain", [{"item": "bone_shard", "chance": 1.0, "min": 3, "max": 5}, {"item": "grave_dust", "chance": 1.0, "min": 2, "max": 3}, {"item": "ring_captain", "chance": 0.5}, {"item": "elixir_stone", "chance": 0.4}]),
		_lt("lt_wailing_widow", [{"item": "grave_dust", "chance": 1.0, "min": 3, "max": 5}, {"item": "herb_blue", "chance": 1.0, "min": 2, "max": 3}, {"item": "amulet_widow", "chance": 0.5}, {"item": "elixir_might", "chance": 0.4}]),
		_lt("lt_count_vargo", [{"item": "grave_dust", "chance": 1.0, "min": 4, "max": 6}, {"item": "cape_vargo", "chance": 0.6}, {"item": "ring_vargo", "chance": 0.4}, {"item": "elixir_might", "chance": 1.0}]),
		_lt("lt_dragonling", [{"item": "dragon_scale", "chance": 1.0, "min": 2, "max": 4}, {"item": "golem_core", "chance": 1.0, "min": 1, "max": 2}, {"item": "amulet_golem", "chance": 0.5}, {"item": "elixir_might", "chance": 1.0, "min": 1, "max": 2}, {"item": "crown_spectral", "chance": 0.4}]),
	]
