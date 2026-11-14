class_name AscensionCatalog
extends RefCounted
## Teia de ascensão (Ato II, GDD ato2-horda R6 "Barra e teia de ascensão"): uma por classe, separada da teia comum
## (ids `<classe>_a_*`, pontos próprios, ProgressionSystem.asc_*). As skills com `SkillDef.ascension` entram sozinhas
## (nó de skill + maestria 0-5, como na teia comum); os passivos e portões de cada classe ficam em NODES.
## Classe sem skill de ascensão nem nó aqui = sem teia (sem aba na janela K).
##
## NODES[<classe>]: {id, name, level, desc, branch ("" = Geral, ou id da build), stats (Stats.STAT_KEYS / attr_*),
##   flag (portão lido pela regra da classe: ProgressionSystem.asc_flag), cost (padrão 1)}. Na teia, cada ramo é uma
##   espinha que sai do início: entradas das skills e estes nós em ordem de nível.
const NODES := {
	"berserker": [
		{"id": "titan_grip", "name": "Empunhadura Firme", "level": 35, "stats": {"titan_relief": 1},
			"desc": "Empunhadura de Titã: o básico com dois machados de 2 mãos perde 3% a menos de velocidade."},
		{"id": "titan_pulse", "name": "Pulso de Titã", "level": 38, "stats": {"titan_relief": 1},
			"desc": "Empunhadura de Titã: mais 3% de velocidade do básico devolvida."},
		{"id": "titan_shoulders", "name": "Ombros de Titã", "level": 41, "stats": {"titan_relief": 1},
			"desc": "Empunhadura de Titã: mais 3% de velocidade do básico devolvida (o máximo da teia)."},
		# refinos 40/45 por build (GDD R6.1), portões lidos por TitanSystem/GladiatorSystem
		{"id": "twin_spin", "name": "Giro dos Dois Machados", "level": 40, "branch": "carniceiro", "cost": 3, "flag": Balance.CYCLONE_LONG_FLAG,
			"desc": "Ciclone de Titã: os dois machados giram juntos — 6 giros em 3 s (eram 4 em 2 s)."},
		# Gêmeos 45 (decisão do autor 2026-11-13: a build não tinha refino no 45 e dava F5 x1,078 contra Kragmar)
		{"id": "twin_fury", "name": "Fúria Gêmea", "level": 45, "branch": "carniceiro", "cost": 3, "flag": Balance.TWIN_FURY_FLAG, "stats": {"atk_pct": Balance.TWIN_FURY_ATK},
			"desc": "Os dois machados não param: +%d%% de dano." % Balance.TWIN_FURY_ATK},
		{"id": "second_axe", "name": "Segundo Machado", "level": 40, "branch": "executor", "cost": 3, "flag": Balance.SECOND_AXE_FLAG,
			"desc": "Com dois machados de 2 mãos: em alvo abaixo de 20% da vida toda skill bate também com o 2º machado (golpe duplo)."},
		{"id": "arena_finale", "name": "Golpe Final da Arena", "level": 45, "branch": "executor", "cost": 3, "flag": Balance.ARENA_FINALE_FLAG,
			"desc": "Golpe Final (gasta 5 de Glória): +%d%% de poder e atordoa 1 s quem atinge." % ((Balance.ARENA_FINALE["power"] - 1.0) * 100.0 + 0.5)},
		{"id": "fury_lit", "name": "Fúria Acesa", "level": 40, "branch": "punhos", "cost": 3, "flag": Balance.FURY_LIT_FLAG,
			"desc": "Ao lançar o Ciclone de Titã, a Fúria do Punho (e a Glória, na postura) demora 6 s a mais para esfriar."},
		{"id": "glory_keep", "name": "Glória que Não Esfria", "level": 45, "branch": "punhos", "cost": 3, "flag": Balance.GLORY_KEEP_FLAG,
			"desc": "A Glória demora 6 s a mais para esfriar (18 s), também depois de sair da postura."},
	],
	# Senhor dos Mortos (NecroAscension): refinos 40/45 do GDD R6.1 como nós com portão de nível (números em Balance.LORD_*)
	"necromancer": [
		{"id": "bond", "name": "Vínculo Sombrio", "level": 37, "flag": "nec_bond",
			"desc": "Pacto dos Mortos dura 3 s a mais."},
		{"id": "fog", "name": "Névoa Espessa", "level": 39, "flag": "nec_fog",
			"desc": "A nuvem de Miasma dura 2 s a mais."},
		{"id": "deep_grave", "name": "Cova Funda", "level": 42, "flag": "nec_deep_grave",
			"desc": "Os esqueletos erguidos pela Marca da Cova duram 5 s a mais."},
		{"id": "army", "name": "Exército", "level": 40, "branch": "invocador", "flag": "nec_army", "cost": 2,
			"desc": "+1 invocação de cada tipo; as invocações ganham 20% da sua vida máxima."},
		{"id": "blood_pact", "name": "Pacto de Sangue", "level": 45, "branch": "invocador", "flag": "nec_blood_pact",
			"desc": "O roubo de vida do Pacto dos Mortos dobra (20% do dano das invocações cura você)."},
		{"id": "command", "name": "Foice que Comanda", "level": 40, "branch": "ceifador", "flag": "nec_command", "cost": 2,
			"desc": "Cada golpe seu manda as invocações atacarem o mesmo alvo (elas o seguram por 4 s)."},
		{"id": "lich_reaper", "name": "Ceifa do Lich", "level": 45, "branch": "ceifador", "flag": "nec_lich_reaper",
			"desc": "A Forma de Lich dura 5 s a mais."},
		{"id": "wide", "name": "Miasma Largo", "level": 40, "branch": "pestilento", "flag": "nec_wide", "cost": 2,
			"desc": "Miasma e Marca da Cova com +50% de raio."},
		{"id": "lich_plague", "name": "Praga do Lich", "level": 45, "branch": "pestilento", "flag": "nec_lich_plague",
			"desc": "Na Forma de Lich as maldições espalham 50% mais longe (6 m)."},
	],
	# Assassino — Sombras Gêmeas (ShadowSystem). Geral: clone e Execução mais fortes; ramos: refinos 40 das builds
	# (Sombra Furtiva, Contra-Ataque em Cadeia; o Canhão de Mão do Corsário é skill, nível 40) e passivos da build.
	"assassin": [
		{"id": "long_shadow", "name": "Sombra Persistente", "level": 37, "stats": {"shadow_time": 1},
			"desc": "Sombra Gêmea: o clone dura 1 s a mais."},
		{"id": "sharp_shadow", "name": "Sombra Afiada", "level": 39, "stats": {"shadow_share": 1},
			"desc": "Sombra Gêmea: o clone repete os golpes com 55% do dano (era 50%)."},
		{"id": "mercy", "name": "Golpe de Misericórdia", "level": 41, "stats": {"execute_pct": 1},
			"desc": "Execução: +10% de dano em alvo abaixo de 25% da vida."},
		{"id": "twin_edge", "name": "Fio Gêmeo", "level": 43, "stats": {"shadow_share": 1, "execute_pct": 1},
			"desc": "Sombra Gêmea: mais 5% do dano no clone. Execução: mais 10% de dano."},
		{"id": "lam_fang", "name": "Presas da Sombra", "level": 36, "branch": "laminas", "stats": {"backstab": 6}},
		{"id": "lam_stealth", "name": "Sombra Furtiva", "level": 40, "branch": "laminas", "flag": "ass_shadow_stealth",
			"desc": "Sair da furtividade golpeando chama o clone da Sombra Gêmea por 3 s, sem gastar a recarga: ele sai da sombra junto com você."},
		{"id": "lam_venom", "name": "Veneno Paciente", "level": 42, "branch": "laminas", "stats": {"aspd_pct": 4}},
		{"id": "lam_night", "name": "Filha da Noite", "level": 45, "branch": "laminas", "stats": {"shadow_time": 1},
			"desc": "Sombra Gêmea: o clone dura mais 1 s."},
		{"id": "due_step", "name": "Passo de Esgrima", "level": 36, "branch": "duelista", "stats": {"evasion": 2.0}},
		{"id": "due_chain", "name": "Contra-Ataque em Cadeia", "level": 40, "branch": "duelista", "flag": "ass_chain_counter",
			"desc": "Cada esquiva prepara a próxima Execução: ela fica pronta na hora e sai sem recarga (1 carga, 8 s)."},
		{"id": "due_edge", "name": "Fio do Mestre", "level": 42, "branch": "duelista", "stats": {"crit": 3.0}},
		{"id": "due_final", "name": "Última Estocada", "level": 45, "branch": "duelista", "stats": {"execute_pct": 1},
			"desc": "Execução: mais 10% de dano em alvo abaixo de 25% da vida."},
		{"id": "cor_powder", "name": "Pólvora Seca", "level": 36, "branch": "corsario", "stats": {"crit": 2.0}},
		{"id": "cor_swagger", "name": "Fanfarrão", "level": 42, "branch": "corsario", "stats": {"aspd_pct": 4}},
		{"id": "cor_captain", "name": "Capitão das Sombras", "level": 45, "branch": "corsario", "stats": {"shadow_share": 1},
			"desc": "Sombra Gêmea: mais 5% do dano no clone."},
	],
	# Coro Celeste (ChoirSystem): refinos 40/45 por build + o "santuário" da Barreira aos 45 (GDD R6.1, F9)
	"bishop": [
		{"id": "choir_hold", "name": "Santuário da Barreira", "level": 45, "flag": "choir_hold",
			"desc": "Nos primeiros 3 s da Barreira Sagrada, ninguém do grupo dentro dela cai abaixo de 1 de vida."},
		{"id": "angel_strong", "name": "Anjo Forte", "level": 40, "branch": "sacerdote", "flag": "choir_angel_strong",
			"desc": "O Anjo Guardião cura 50% a mais (a Luz de Partida também)."},
		{"id": "two_angels", "name": "Dois Anjos", "level": 45, "branch": "sacerdote", "flag": "choir_two_angels",
			"desc": "Dois Anjos Guardiões ao mesmo tempo: chamar de novo não dispensa o primeiro."},
		{"id": "barrier_burn", "name": "Barreira que Fere", "level": 40, "branch": "inquisidor", "flag": "choir_barrier_burn",
			"desc": "A Barreira Sagrada queima os inimigos dentro dela (poder mágico 0,4 por segundo)."},
		{"id": "barrier_march", "name": "Barreira em Marcha", "level": 40, "branch": "batalha", "flag": "choir_barrier_march",
			"desc": "A Barreira Sagrada anda colada em você (até na investida) e dá um escudo de 10% da vida a quem está dentro ao lançar."},
		{"id": "res_shield", "name": "Retorno Blindado", "level": 45, "branch": "batalha", "flag": "choir_res_shield",
			"desc": "Quem volta pelo Retorno ganha um escudo de 20% da vida por 6 s."},
	],
	# Elementalista (ElementalSystem): Geral = o portão do estágio Ancestral (40, antes dos passivos: bot e jogador chegam nele com 1 ponto) + passivos 41+; por elemento, 1 passivo, o refino do 40
	# (a forma daquele elemento mais forte: Balance.ELEM_FORM_REFINE) e 2 passivos (43, 45). 36 pontos de conteúdo por build aos 45.
	"elementalist": [
		{"id": "ancestral", "name": "Chamado Ancestral", "level": 40, "flag": "elem_ancestral",
			"desc": "O elemental pode chegar ao estágio Ancestral (com a experiência cheia)."},
		{"id": "ele_well", "name": "Poço de Mana", "level": 41, "cost": 2, "stats": {"mp_pct": 6}},
		{"id": "ele_focus", "name": "Foco Arcano", "level": 42, "cost": 2, "stats": {"matk_pct": 3}},
		{"id": "ele_mind", "name": "Mente Clara", "level": 43, "cost": 2, "stats": {"attr_INT": 16}, "desc": "Notável: +16 INT."},
		{"id": "ele_ward", "name": "Manto de Éter", "level": 44, "cost": 2, "stats": {"hp_pct": 4}},
		{"id": "fire_ember", "name": "Brasa Viva", "level": 37, "branch": "fogo", "cost": 2, "stats": {"fire_pct": 4}},
		{"id": "fire_refine", "name": "Salamandra", "level": 40, "branch": "fogo", "cost": 3, "flag": "elem_refine_fire",
			"desc": "O elemental na forma de fogo ganha +15% de ataque e de vida."},
		{"id": "fire_heart", "name": "Coração de Brasa", "level": 43, "branch": "fogo", "cost": 3, "stats": {"crit": 2.0}},
		{"id": "fire_lord", "name": "Senhor das Chamas", "level": 45, "branch": "fogo", "cost": 5, "stats": {"fire_pct": Balance.ASC_FIRE_LORD_PCT}},
		{"id": "frost_rime", "name": "Geada Fina", "level": 37, "branch": "gelo", "cost": 2, "stats": {"frost_pct": 4}},
		{"id": "frost_refine", "name": "Golem de Gelo", "level": 40, "branch": "gelo", "cost": 3, "flag": "elem_refine_frost",
			"desc": "O elemental na forma de gelo ganha +15% de ataque e de vida."},
		{"id": "frost_shell", "name": "Casca de Gelo", "level": 43, "branch": "gelo", "cost": 3, "stats": {"def_pct": 4}},
		{"id": "frost_lord", "name": "Senhora do Inverno", "level": 45, "branch": "gelo", "cost": 5, "stats": {"frost_pct": Balance.ASC_FROST_LORD_PCT}},
		{"id": "storm_spark", "name": "Faísca Solta", "level": 37, "branch": "raio", "cost": 2, "stats": {"storm_pct": 4}},
		{"id": "storm_refine", "name": "Silfo", "level": 40, "branch": "raio", "cost": 3, "flag": "elem_refine_storm",
			"desc": "O elemental na forma de raio ganha +15% de ataque e de vida."},
		{"id": "storm_wind", "name": "Vento nas Mãos", "level": 43, "branch": "raio", "cost": 3, "stats": {"speed_pct": 4}},
		{"id": "storm_lord", "name": "Senhor da Tormenta", "level": 45, "branch": "raio", "cost": 5, "stats": {"storm_pct": 6}},
	],
	# Paladino (MountedCombat): as 3 skills são do ramo Geral (21 pontos); cada build tem 15 pontos de passivos e, no Cruzado,
	# o refino do 40 (Lança Pesada). Guardião e Templário têm dois refinos cada (40: asas; 45: montado), a mais que os 36 pontos:
	# 42 de conteúdo, a build escolhe o que deixa de fora.
	"paladin": [
		{"id": "gua_plate", "name": "Placas Juradas", "level": 36, "branch": "guardiao", "cost": 2, "stats": {"def_pct": 4}},
		{"id": "gua_heart", "name": "Coração de Muralha", "level": 38, "branch": "guardiao", "cost": 2, "stats": {"hp_pct": 4}},
		{"id": "gua_oath", "name": "Voto de Ferro", "level": 40, "branch": "guardiao", "cost": 3, "stats": {"attr_VIT": 16}, "desc": "Notável: +16 VIT."},
		{"id": "gua_wings", "name": "Asas com Bloqueio", "level": 40, "branch": "guardiao", "cost": 3, "flag": Balance.ARCANE_GUARD_FLAG,
			"desc": "Modo Arcano: com escudo, as asas dão também +10% de chance de bloqueio."},
		{"id": "gua_mounted", "name": "Muralha a Cavalo", "level": 45, "branch": "guardiao", "cost": 3, "flag": Balance.MOUNT_WALL_FLAG,
			"desc": "Montado, você provoca e ergue o escudo sem descer do cavalo."},
		{"id": "gua_wall", "name": "Parede Viva", "level": 43, "branch": "guardiao", "cost": 3, "stats": {"dr_pct": 3}},
		{"id": "gua_bastion", "name": "Bastião de Luz", "level": 45, "branch": "guardiao", "cost": 5, "stats": {"threat_pct": 10, "def_pct": 4}},
		{"id": "cru_edge", "name": "Fio Consagrado", "level": 36, "branch": "cruzado", "cost": 2, "stats": {"atk_pct": 3}},
		{"id": "cru_zeal", "name": "Fervor", "level": 38, "branch": "cruzado", "cost": 2, "stats": {"crit": 2.0}},
		{"id": "cru_lance", "name": "Lança Pesada", "level": 40, "branch": "cruzado", "cost": 3, "flag": "pal_long_lance",
			"desc": "Carga Montada vai 30% mais longe."},
		{"id": "cru_arm", "name": "Braço do Cruzado", "level": 43, "branch": "cruzado", "cost": 3, "stats": {"attr_FOR": 16}, "desc": "Notável: +16 FOR."},
		{"id": "cru_wrath", "name": "Ira Sagrada", "level": 45, "branch": "cruzado", "cost": 5, "stats": {"atk_pct": Balance.ASC_CRU_WRATH_ATK}},
		{"id": "tem_seal", "name": "Selo do Templo", "level": 36, "branch": "templario", "cost": 2, "stats": {"atk_pct": 3}},
		{"id": "tem_well", "name": "Fonte de Luz", "level": 38, "branch": "templario", "cost": 2, "stats": {"mp_pct": 6}},
		{"id": "tem_rune", "name": "Runa do Templo", "level": 40, "branch": "templario", "cost": 3, "stats": {"attr_INT": Balance.ASC_TEM_RUNE_INT}, "desc": "Notável: +%d INT." % Balance.ASC_TEM_RUNE_INT},
		{"id": "tem_wings", "name": "Asas Protetoras", "level": 40, "branch": "templario", "cost": 3, "flag": Balance.ARCANE_WARD_FLAG,
			"desc": "Modo Arcano gasta metade da MP; as asas dão 10% de redução de dano ao grupo a 6 m."},
		{"id": "tem_banner", "name": "Estandarte", "level": 45, "branch": "templario", "cost": 3, "flag": Balance.MOUNT_BANNER_FLAG,
			"desc": "Montado, as suas auras de grupo alcançam 50% mais longe."},
		{"id": "tem_guard", "name": "Guarda Erguida", "level": 43, "branch": "templario", "cost": 3, "stats": {"def_pct": 4}},
		{"id": "tem_dawn", "name": "Aurora do Templo", "level": 45, "branch": "templario", "cost": 5, "stats": {"matk_pct": Balance.ASC_TEM_DAWN_MATK}},
	],
	# Druida (Forma Ancestral, DruidAscension): por build, 2 passivos, o refino do 40, 1 passivo e o refino do 45
	# (Balance.ANC_REFINE_*: na forma ancestral, variantes e skills da forma com mais poder e duração por refino).
	"druid": [
		{"id": "ent_bark", "name": "Casca Grossa", "level": 36, "branch": "guardiao_verde", "cost": 2, "stats": {"def_pct": 4}},
		{"id": "ent_sap", "name": "Seiva Antiga", "level": 38, "branch": "guardiao_verde", "cost": 2, "stats": {"hp_pct": 4}},
		{"id": "ent_refine", "name": "Ent Ancestral", "level": 40, "branch": "guardiao_verde", "cost": 3, "flag": "anc_ent",
			"desc": "Como Ent: os golpes de galho e raiz e as skills da forma ganham +6% de poder; prender, atordoar, provocar e Bosque Protetor duram 20% mais."},
		{"id": "ent_heart", "name": "Coração do Bosque", "level": 43, "branch": "guardiao_verde", "cost": 3, "stats": {"dr_pct": 3}},
		{"id": "ent_elder", "name": "Ent Primordial", "level": 45, "branch": "guardiao_verde", "cost": 5, "flag": "anc_ent_2",
			"desc": "Como Ent: mais +6% de poder e +20% de duração (soma com Ent Ancestral)."},
		{"id": "alpha_fang", "name": "Presas do Alfa", "level": 36, "branch": "fera", "cost": 2, "stats": {"atk_pct": 3}},
		{"id": "alpha_eye", "name": "Olho do Caçador", "level": 38, "branch": "fera", "cost": 2, "stats": {"crit": 3}},
		{"id": "alpha_refine", "name": "Lobo Alfa", "level": 40, "branch": "fera", "cost": 3, "flag": "anc_alpha",
			"desc": "Como Lobo Alfa: os golpes do Alfa e as skills da forma ganham +6% de poder; lentidão, o Uivo e a matilha duram 20% mais."},
		{"id": "alpha_blood", "name": "Sangue da Matilha", "level": 43, "branch": "fera", "cost": 3, "stats": {"aspd_pct": 4}},
		{"id": "alpha_elder", "name": "Senhor da Matilha", "level": 45, "branch": "fera", "cost": 5, "flag": "anc_alpha_2",
			"desc": "Como Lobo Alfa: mais +6% de poder e +20% de duração (soma com Lobo Alfa)."},
		{"id": "bird_plume", "name": "Plumas de Luz", "level": 36, "branch": "xama", "cost": 2, "stats": {"matk_pct": 3}},
		{"id": "bird_song", "name": "Canto da Aurora", "level": 38, "branch": "xama", "cost": 2, "stats": {"heal_pct": 5}},
		{"id": "bird_refine", "name": "Pássaro Arcano", "level": 40, "branch": "xama", "cost": 3, "flag": "anc_bird",
			"desc": "Como Pássaro Arcano: as variantes das magias e as skills da forma ganham +6% de poder; prender, lentidão e a Revoada duram 20% mais."},
		{"id": "bird_wind", "name": "Vento Alto", "level": 43, "branch": "xama", "cost": 3, "stats": {"mp_pct": 6}},
		{"id": "bird_elder", "name": "Ave do Trovão", "level": 45, "branch": "xama", "cost": 5, "flag": "anc_bird_2",
			"desc": "Como Pássaro Arcano: mais +6% de poder e +20% de duração (soma com Pássaro Arcano)."},
	],
	# Caçador — Falcoeiro (FalconSystem): refinos 40/45 como portões, garras (dano do mergulho) e laço com o lince.
	# Atirador: os dois refinos da torreta (Balance.TURRET_REFINE_*, RangerAscension.turret_refines).
	"ranger": [
		{"id": "double_jump", "name": "Salto Duplo", "level": 40, "branch": "lanceiro", "cost": 3, "flag": Balance.DOUBLE_JUMP_FLAG,
			"desc": "Depois de pousar do Salto Dracônico, 1 s para saltar de novo sem recarga; a recarga só começa depois (o dobro se você saltou duas vezes)."},
		{"id": "shout_combo", "name": "Brado Combinado", "level": 45, "branch": "lanceiro", "cost": 3, "flag": Balance.SHOUT_COMBO_FLAG,
			"desc": "Gritar um Brado com outro ativo mantém os dois: o anterior fica até 8 s (recarga 40 s)."},
		{"id": "turret_firm", "name": "Torreta Firme", "level": 40, "branch": "atirador", "cost": 3, "flag": "ran_turret_firm",
			"desc": "A torreta dura +4 s e recarrega 20% mais rápido."},
		{"id": "turret_vet", "name": "Torreta Veterana", "level": 45, "branch": "atirador", "cost": 5, "flag": "ran_turret_vet",
			"desc": "De novo: a torreta dura +4 s e recarrega 20% mais rápido (soma com Torreta Firme)."},
		{"id": "falcon_glove", "name": "Luva de Falcoaria", "level": 35, "branch": "cacador", "cost": 2, "stats": {"attr_AGI": 16},
			"desc": "Notável: +16 AGI."},
		{"id": "falcon_talons_1", "name": "Garras Afiadas", "level": 36, "branch": "cacador", "stats": {"falcon_pct": Balance.FALCON_WEB_PCT},
			"desc": "O mergulho do falcão causa +15% de dano."},
		{"id": "falcon_bond", "name": "Caçada a Três", "level": 37, "branch": "cacador", "cost": 2, "stats": {"pet_pct": 15},
			"desc": "Notável: +15% de força do lince."},
		{"id": "falcon_talons_2", "name": "Garras de Aço", "level": 38, "branch": "cacador", "stats": {"falcon_pct": Balance.FALCON_WEB_PCT},
			"desc": "O mergulho do falcão causa mais +15% de dano."},
		{"id": "falcon_royal", "name": "Falcão Real", "level": 40, "branch": "cacador", "cost": 3, "flag": Balance.FALCON_FLAG_ROYAL,
			"desc": "Quando a Presa morre, ela passa para o inimigo mais perto a 8 m."},
		{"id": "falcon_sight", "name": "Vista Aguçada", "level": 42, "branch": "cacador", "cost": 2, "stats": {"crit": 2.0},
			"desc": "Notável: +2% de crítico."},
		{"id": "falcon_talons_3", "name": "Garras do Céu", "level": 43, "branch": "cacador", "stats": {"falcon_pct": Balance.FALCON_WEB_PCT},
			"desc": "O mergulho do falcão causa mais +15% de dano (o máximo da teia)."},
		{"id": "falcon_flock", "name": "Revoada", "level": 45, "branch": "cacador", "cost": 3, "flag": Balance.FALCON_FLAG_FLOCK,
			"desc": "Olhos do Céu solta 3 falcões que mergulham em 3 alvos diferentes (Presa em área, 1× por uso)."},
	],
}

## Bots: ordem de compra das skills de ascensão (o resto da classe vem depois, por nível). Chave = classe ou
## "<classe>/<build>". As primeiras vão para a barra 7-0 (menos as de BOT_NO_SLOT).
const BOT_ORDER := {
	"paladin": ["pal_arcane_mode", "pal_mounted_charge", "pal_trample"],
	"berserker": ["ber_gladiator", "ber_glad_fire", "ber_glad_finale"],
	"berserker/carniceiro": ["ber_gladiator", "ber_glad_fire", "ber_glad_finale", "ber_titan_cyclone"],     # Gêmeos: o Ciclone de Titã na barra (F5 2026-11-13)
	"elementalist": ["ele_asc_fusion", "ele_asc_command"],
	"bishop": ["bis_choir_angel", "bis_choir_barrier", "bis_choir_return", "bis_choir_aegis", "bis_choir_wings"],     # Retorno só aos 45 (antes: as duas bênçãos)
	"ranger/atirador": ["ran_turret"],
	"necromancer/invocador": ["nec_asc_pact", "nec_asc_miasma", "nec_asc_grave_mark", "nec_asc_lich_form"],
	"necromancer": ["nec_asc_miasma", "nec_asc_grave_mark", "nec_asc_lich_form", "nec_asc_pact"],     # sem invocações de build: debuffs primeiro
	"assassin": ["ass_twin_shadow", "ass_execution"],               # o Canhão de Mão (40) entra depois, só no Corsário
	"druid/guardiao_verde": ["dru_ent_form", "dru_ent_roots", "dru_ent_grove"],      # a forma primeiro: as outras só saem nela
	"druid/fera": ["dru_alpha_form", "dru_alpha_pack", "dru_alpha_howl"],
	"druid/xama": ["dru_bird_form", "dru_bird_bolt", "dru_bird_flock"],
	"ranger/cacador": ["ran_falcon", "ran_dive", "ran_sky_eyes"],      # o falcão primeiro: Mergulho e Olhos do Céu pedem ele
	"ranger/lanceiro": ["ran_dragon_jump", "ran_shout_flame"],      # salto e Chamas primeiro; os outros Brados depois (um ativo por vez)
}
## Skills que o bot aprende mas não põe na barra (o Comando Elemental vai pelo InputCommand: forma/modo).
const BOT_NO_SLOT := ["ele_asc_command"]

const STEP := 3.0            # distância entre nós da espinha (unidades da teia)
const START_R := 2.4         # primeira entrada a partir do início
const ARM_R := 1.25          # skill ao lado da entrada; a maestria do outro lado da skill
const WHEEL_R := 1.15        # círculo desenhado em volta da skill
const SPINE_MAX := 4         # itens por espinha; ramo com mais abre em leque
const SPINE_FAN := 0.75      # rad entre as espinhas do mesmo ramo

static func build(classes: Dictionary, skills: Dictionary) -> Dictionary:
	var out := {}
	for cid in classes:
		var tr := _class_web(classes[cid], skills)
		if not tr.is_empty():
			out[cid] = tr
	return out

## Ordem de compra do bot: as da lista da build/classe primeiro, depois as outras skills de ascensão por nível.
static func bot_order(cls: ClassDef, build_id: String, skills: Dictionary) -> Array:
	var out: Array = []
	for sid in BOT_ORDER.get("%s/%s" % [cls.id, build_id], BOT_ORDER.get(cls.id, [])):
		if skills.has(sid):
			out.append(sid)
	var rest: Array = []
	for sid in cls.skill_ids:
		var s: SkillDef = skills[sid]
		if s.ascension and not (sid in out) and (s.build == "" or s.build == build_id):
			rest.append(s)
	rest.sort_custom(func(a, b): return a.unlock_level < b.unlock_level)
	for s in rest:
		out.append(s.id)
	return out

static func _class_web(cls: ClassDef, skills: Dictionary) -> Dictionary:
	var extra: Array = NODES.get(cls.id, [])
	var asc_skills: Array = []
	for sid in cls.skill_ids:
		if skills[sid].ascension:
			asc_skills.append(skills[sid])
	if asc_skills.is_empty() and extra.is_empty():
		return {}
	# ramos: Geral + builds que têm conteúdo (skill da build ou nó com branch)
	var branches: Array = [{"id": "", "role": "", "name": "Geral", "attr": "VIT"}]
	for b in cls.builds:
		var has: bool = asc_skills.any(func(s): return s.build == b["id"]) or extra.any(func(n): return str(n.get("branch", "")) == b["id"])
		if has:
			branches.append({"id": b["id"], "role": b["role"], "name": b["name"], "attr": b.get("attr", "FOR")})
	if not asc_skills.any(func(s): return s.build == "") and not extra.any(func(n): return str(n.get("branch", "")) == ""):
		branches.pop_front()
	var nodes := {}
	var start := "%s_a_start" % cls.id
	nodes[start] = TreeCatalog._node(start, "start", "", "Ascensão", "Início da teia de ascensão.", Balance.ASC_LEVEL, 0, Vector2.ZERO)
	nodes[start]["branch"] = "start"
	var panes: Array = []
	var clusters: Array = []
	var n_br := branches.size()
	for bi in range(n_br):
		var br: Dictionary = branches[bi]
		var ang := -PI * 0.5 + TAU * bi / float(n_br)
		panes.append({"id": br["id"], "name": br["name"], "role": br["role"], "angle": ang})
		# itens do ramo em ordem de nível: skills e nós do catálogo
		var items: Array = []
		for s in asc_skills:
			if s.build == br["id"]:
				items.append({"lv": s.unlock_level, "skill": s})
		for n in extra:
			if str(n.get("branch", "")) == br["id"]:
				items.append({"lv": int(n.get("level", Balance.ASC_LEVEL)), "node": n})
		items.sort_custom(func(a, b): return int(a["lv"]) < int(b["lv"]))
		# ramo comprido: várias espinhas em leque (SPINE_MAX itens cada), os itens alternando entre elas pela ordem
		var n_sp := maxi(1, ceili(items.size() / float(SPINE_MAX)))
		var prevs: Array = []
		prevs.resize(n_sp)
		prevs.fill(start)
		for k in range(items.size()):
			var it: Dictionary = items[k]
			var sp := k % n_sp
			var kk := k / n_sp
			# um ramo só: as espinhas em volta do início; vários: leque dentro do setor do ramo
			var a := ang + TAU * sp / float(n_sp) if n_br == 1 else ang + (sp - (n_sp - 1) * 0.5) * minf(SPINE_FAN, TAU / n_br / n_sp)
			var dir := Vector2(cos(a), sin(a))
			var side := Vector2(-dir.y, dir.x)
			var at := dir * (START_R + STEP * kk)
			var flip := 1.0 if kk % 2 == 0 else -1.0
			var prev: String = prevs[sp]
			if it.has("skill"):
				var s: SkillDef = it["skill"]
				var eid := "%s_a_in_%s" % [cls.id, s.id]
				var st := {"attr_" + str(br["attr"]): Balance.ASC_WEB_ENTRY_ATTR}
				nodes[eid] = TreeCatalog._node(eid, "stat", "", TreeCatalog.stat_text(st), "Passivo: %s." % TreeCatalog.stat_text(st), Balance.ASC_LEVEL, 1, at)
				nodes[eid]["stats"] = st
				nodes[eid]["branch"] = br["id"]
				TreeCatalog._link(nodes, prev, eid)
				var sc := at + side * ARM_R * flip
				var nid := "%s_a_s_%s" % [cls.id, s.id]
				nodes[nid] = TreeCatalog._node(nid, "skill", s.id, s.name, s.description, s.unlock_level, Balance.SKILL_LEARN_COST, sc)
				nodes[nid]["branch"] = br["id"]
				TreeCatalog._link(nodes, eid, nid)
				var mid := "%s_a_m_%s" % [cls.id, s.id]
				nodes[mid] = TreeCatalog._node(mid, "mastery", s.id, "Maestria: " + s.name, TreeCatalog.mastery_desc(s), s.unlock_level, 1, sc + side * ARM_R * flip)
				nodes[mid]["branch"] = br["id"]
				TreeCatalog._link(nodes, nid, mid)
				clusters.append({"center": sc + side * ARM_R * 0.5 * flip, "r": WHEEL_R, "kind": "skill", "branch": br["id"]})
				prevs[sp] = eid
			else:
				var n: Dictionary = it["node"]
				var xid := "%s_a_x_%s" % [cls.id, n["id"]]
				var st: Dictionary = n.get("stats", {})
				var desc: String = n.get("desc", "")
				if desc == "" and not st.is_empty():
					desc = "Notável: %s." % TreeCatalog.stat_text(st)
				nodes[xid] = TreeCatalog._node(xid, "notable", "", n["name"], desc, int(n.get("level", Balance.ASC_LEVEL)), int(n.get("cost", 1)), at)
				nodes[xid]["stats"] = st.duplicate()
				nodes[xid]["branch"] = br["id"]
				if n.has("flag"):
					nodes[xid]["flag"] = n["flag"]
				TreeCatalog._link(nodes, prev, xid)
				prevs[sp] = xid
	# a janela abre no centro (0, 0): centraliza o desenho da teia (o início sai do meio quando ela é de um lado só)
	var lo := Vector2(INF, INF)
	var hi := -lo
	for nid in nodes:
		lo = lo.min(nodes[nid]["pos"])
		hi = hi.max(nodes[nid]["pos"])
	var mid := (lo + hi) * 0.5
	for nid in nodes:
		nodes[nid]["pos"] -= mid
	for cl in clusters:
		cl["center"] -= mid
	return {"start": start, "nodes": nodes, "panes": panes, "clusters": clusters, "offset": -mid}
