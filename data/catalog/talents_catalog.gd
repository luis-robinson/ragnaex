class_name TalentsCatalog
extends RefCounted
## Evoluções compradas com pontos de skill (ver TalentDef). Toda classe evolui o dash (Shift)
## e algumas skills. mods de skill: "set" (substitui campo), "mult" (multiplica campo numérico),
## "effects" (soma/substitui efeitos). mods de dash: ver TalentDef.

static func _t(id: String, cls: String, skill: String, lvl: int, cost: int, name: String, desc: String, mods: Dictionary, req: Array = []) -> TalentDef:
	var t := TalentDef.new()
	t.id = id
	t.class_id = cls
	t.skill_id = skill
	t.unlock_level = lvl
	t.cost = cost
	t.name = name
	t.description = desc
	t.mods = mods
	for r in req:
		t.requires.append(r)
	return t

static func build() -> Array:
	var D := TalentDef.DASH
	return [
		# --- Paladino ---
		_t("pal_t_shield_charge", "paladin", D, 5, 2, "Investida de Escudo", "O dash atordoa por 1s e fere quem estiver no ponto de chegada. Exige escudo.",
			{"stun": 1.0, "power": 0.6, "radius": 1.6}, ["shield"]),
		_t("pal_t_holy_strike", "paladin", "pal_holy_strike", 8, 2, "Golpe Sagrado Amplo", "Golpe Sagrado 30% mais largo e retarda 30%.",
			{"mult": {"radius": 1.3}, "effects": {"slow": {"pct": 30, "duration": 1.5}}}),
		_t("pal_t_lay_hands", "paladin", "pal_lay_hands", 14, 3, "Mãos da Comunhão", "Imposição de Mãos também cura aliados num raio de 6m.",
			{"set": {"radius": 6.0}}),
		_t("pal_t_twin_slash", "paladin", "pal_twin_slash", 12, 2, "Arco Sangrento", "Arco Radiante recarrega 30% mais rápido e faz sangrar.",
			{"mult": {"cooldown": 0.7}, "effects": {"dot": {"dps": 4, "duration": 3}}}, ["two_handed"]),
		# --- Berserker ---
		_t("ber_t_crash", "berserker", D, 5, 2, "Avanço Brutal", "O dash fere inimigos ao redor do ponto de chegada.",
			{"power": 0.8, "radius": 1.8}),
		_t("ber_t_cleave", "berserker", "ber_cleave", 8, 2, "Rachar Amplo", "Rachar 25% maior e acerta até 8 inimigos.",
			{"mult": {"radius": 1.25}, "set": {"max_targets": 8}}),
		_t("ber_t_fury", "berserker", "ber_fury", 14, 3, "Fúria Contagiante", "Fúria também fortalece aliados num raio de 6m.",
			{"set": {"radius": 6.0}}),
		_t("ber_t_hack", "berserker", "ber_hack", 7, 2, "Talho Profundo", "Talho Duplo causa +20% de dano e sangra mais forte.",
			{"mult": {"power": 1.2}, "effects": {"dot": {"dps": 7, "duration": 5}}}),
		_t("ber_t_whirlwind", "berserker", "ber_whirlwind", 16, 2, "Redemoinho Sedento", "Redemoinho cura 15% do dano causado.",
			{"effects": {"heal_pct_of_dmg": 0.15}}, ["two_handed"]),
		# --- Bispo ---
		_t("bis_t_holy_step", "bishop", D, 5, 2, "Passo Sagrado", "O dash cura 6% do seu HP máximo.",
			{"heal_pct": 6}),
		_t("bis_t_heal_party", "bishop", "bis_heal", 6, 3, "Cura em Grupo", "Curar também cura aliados num raio de 6m.",
			{"set": {"radius": 6.0}}),
		_t("bis_t_mend", "bishop", "bis_mend", 18, 2, "Remendo Generoso", "Remendo Sagrado cobre área 35% maior.",
			{"mult": {"radius": 1.35}}),
		_t("bis_t_smite", "bishop", "bis_smite", 10, 2, "Castigo Atordoante", "Castigar atordoa por 0.5s.",
			{"effects": {"stun": {"duration": 0.5}}}),
		_t("bis_t_light", "bishop", "bis_light", 12, 2, "Luz Penetrante", "Luz Sagrada atravessa inimigos e causa +20% de dano.",
			{"set": {"projectile_pierce": true}, "mult": {"power": 1.2}}),
		# --- Druida ---
		_t("dru_t_stampede_step", "druid", D, 5, 2, "Disparada", "Após o dash, +30% de velocidade por 3s.",
			{"buff": {"id": "wild_run", "duration": 3, "speed_pct": 30}}),
		_t("dru_t_thorns", "druid", "dru_thorns", 8, 2, "Espinhos Perfurantes", "Espinhos atravessam inimigos.",
			{"set": {"projectile_pierce": true}}),
		_t("dru_t_maul", "druid", "dru_maul", 10, 2, "Esmagar Atordoante", "Esmagar atordoa por 0.5s.",
			{"effects": {"stun": {"duration": 0.5}}}, ["mace2h"]),
		_t("dru_t_claw", "druid", "dru_claw", 7, 2, "Garras Afiadas", "Garras causam +20% de dano e recarregam 20% mais rápido.",
			{"mult": {"power": 1.2, "cooldown": 0.8}}),
		_t("dru_t_moonfire", "druid", "dru_moonfire", 9, 2, "Lua Cheia", "Fogo Lunar recarrega 25% mais rápido e queima por mais tempo.",
			{"mult": {"cooldown": 0.75}, "effects": {"dot": {"dps": 7, "duration": 6}}}),
		_t("dru_t_regrowth", "druid", "dru_regrowth", 12, 3, "Bosque Curativo", "Rebrotar cura 20% mais e alcança 60% mais longe.",
			{"mult": {"radius": 1.6, "power": 1.2}}),
		# --- Ranger ---
		_t("ran_t_roll", "ranger", D, 5, 2, "Rolamento", "O dash vira um rolamento 60% mais longo.",
			{"distance_mult": 1.6}),
		_t("ran_t_power_shot", "ranger", "ran_power_shot", 8, 2, "Tiro de Longo Alcance", "Tiro Poderoso +30% alcance e +15% dano.",
			{"mult": {"range": 1.3, "power": 1.15}}, ["bow"]),
		_t("ran_t_multishot", "ranger", "ran_multishot", 12, 2, "Leque Aberto", "Tiro Múltiplo alcança 40% mais longe.",
			{"mult": {"radius": 1.4}}, ["bow"]),
		_t("ran_t_trap", "ranger", "ran_trap", 14, 2, "Armadilha Grande", "Armadilha com área 40% maior.",
			{"mult": {"radius": 1.4}}),
		# --- Assassino ---
		_t("ass_t_double_step", "assassin", D, 5, 2, "Passo Duplo", "Duas cargas de dash: use duas vezes seguidas.",
			{"charges": 2}),
		_t("ass_t_backstab", "assassin", "ass_backstab", 8, 2, "Apunhalar Sangrento", "Apunhalar faz sangrar por 4s.",
			{"effects": {"dot": {"dps": 5, "duration": 4}}}),
		_t("ass_t_poison", "assassin", "ass_poison", 12, 2, "Veneno Paralisante", "Lâmina Venenosa 30% maior e retarda 30%.",
			{"mult": {"radius": 1.3}, "effects": {"slow": {"pct": 30, "duration": 2}}}),
		_t("ass_t_twin_strike", "assassin", "ass_twin_strike", 7, 2, "Golpe Certeiro", "Golpe Gêmeo causa +25% de dano.",
			{"mult": {"power": 1.25}}),
		_t("ass_t_cross_slash", "assassin", "ass_cross_slash", 9, 2, "Corte em X", "Corte Cruzado 25% maior e faz sangrar por 4s.",
			{"mult": {"radius": 1.25}, "effects": {"dot": {"dps": 5, "duration": 4}}}),
		_t("ass_t_shadowstep", "assassin", "ass_shadowstep", 16, 2, "Sombra Inquieta", "Passo das Sombras recarrega 30% mais rápido.",
			{"mult": {"cooldown": 0.7}}),
		# --- Elementalista ---
		_t("ele_t_phase", "elementalist", D, 5, 2, "Translocação", "O dash atravessa objetos e vai 25% mais longe.",
			{"ghost": true, "distance_mult": 1.25}),
		_t("ele_t_fireball", "elementalist", "ele_fireball", 8, 2, "Bola de Fogo Maior", "Bola de Fogo explode 60% maior e queima mais.",
			{"mult": {"radius": 1.6}, "effects": {"dot": {"dps": 6, "duration": 4}}}),
		_t("ele_t_meteor", "elementalist", "ele_meteor", 12, 2, "Chuva de Brasas", "Meteoro 25% maior e deixa o chão queimando.",
			{"mult": {"radius": 1.25}, "effects": {"dot": {"dps": 8, "duration": 4}}}),
		_t("ele_t_frost_nova", "elementalist", "ele_frost_nova", 12, 2, "Nova Congelante", "Nova de Gelo também prende por 1s.",
			{"effects": {"root": {"duration": 1.0}}}, ["staff"]),
		_t("ele_t_lightning", "elementalist", "ele_lightning", 12, 2, "Relâmpago em Cadeia", "Relâmpago +30% alcance e atinge até 6 inimigos.",
			{"mult": {"range": 1.3}, "set": {"max_targets": 6}}, ["staff"]),
		# --- Necromancer ---
		_t("nec_t_shadow_step", "necromancer", D, 5, 2, "Passo Sombrio", "O dash explode em sombras: fere e retarda 40% ao redor da chegada.",
			{"power": 0.5, "radius": 2.0, "slow": {"pct": 40, "duration": 2}}),
		_t("nec_t_drain", "necromancer", "nec_drain", 8, 2, "Dreno Voraz", "Drenar Vida cura 60% do dano.",
			{"effects": {"heal_pct_of_dmg": 0.6}}),
		_t("nec_t_raise", "necromancer", "nec_raise", 10, 3, "Legião", "Erguer Mortos invoca 3 esqueletos por 30s (máx 4).",
			{"effects": {"summon": {"monster_id": "skeleton_minion", "count": 3, "duration": 30, "max": 4}}}, ["staff"]),
		_t("nec_t_harvest", "necromancer", "nec_harvest", 22, 3, "Colheita Farta", "Colheita Sombria com área 25% maior.",
			{"mult": {"radius": 1.25}}),
		_t("nec_t_plague", "necromancer", "nec_plague", 14, 2, "Praga Alastrante", "Praga com área 35% maior.",
			{"mult": {"radius": 1.35}}),
	]
