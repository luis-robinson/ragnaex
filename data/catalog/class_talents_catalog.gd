class_name ClassTalentsCatalog
extends RefCounted
## Talentos de classe (aba "Talentos" da janela K): a cada 5 níveis (5..30) uma linha com 3 escolhas que mudam o
## jeito de jogar a classe. Escolhe-se UMA por linha, é grátis (liberada pelo nível) e trocar é na cidade.
## A sim lê só os ganchos abaixo (ClassTalentSystem); o resto é texto. Números iniciais, calibrados pelos probes.
##
## Ganchos genéricos:
##   permanent: [skill]  + strength     o buff da skill fica sempre ativo em você (só os bônus positivos × strength)
##   aura: [skill] + strength + radius  o mesmo, em você e nos aliados do grupo/invocações perto
##   summon_permanent: [skill]          as invocações da skill não expiram
##   summon_extra: {skill: n}           +n no máximo de invocações da skill
##   skill_mods: {skill: {set, mult, effects}}   como as evoluções (TalentsCatalog)
##   stats: {...}                       bônus fixo (formato de buff: atk_pct, crit, attr_FOR...)
##   form_mult                          multiplica os bônus das formas (lobo, urso, demônio, fantasma)
## Ganchos especiais (cada um no seu ponto da sim):
##   cheat_death {cd, dur, stealth?}    golpe fatal: fica com 1 HP e imortal por `dur` s (uma vez a cada `cd` s)
##   ally_save {cd, radius}             o mesmo, num aliado do grupo perto (o primeiro que cairia)
##   ambush_mult                        dano do golpe saindo da furtividade (padrão Balance.AMBUSH_MULT)
##   on_kill {heal_pct, mp_pct, stealth, buff}   ao matar: cura % do HP, devolve % do MP, some por N s, renova o buff de uma skill
##   low_hp {below, dmg_pct}            abaixo de `below` do HP: +dmg_pct% de dano
##   execute {below, dmg_pct}           +dmg_pct% de dano em alvo abaixo de `below` do HP
##   regen {pct, form?}                 cura pct% do HP por segundo (só na forma, se `form`)
##   mana_shield {pct}                  pct% do dano recebido sai do MP
##   trap_max, oath_max                 limites de armadilhas e de cargas de Juramento
##   form_time {forma: x}               duração das formas com tempo (Fantasma)
## (o teto da Radiância sobe com stats.radiance_cap)

const ROW_LEVELS := [5, 10, 15, 20, 25, 30]
const AURA_RADIUS := 15.0
## Selo do cartão (cor) pelo gancho principal
const KINDS := ["permanente", "aura", "invocação", "sobrevivência", "dano", "utilidade"]

static func _o(id: String, name: String, text: String, kind: String, hooks: Dictionary) -> Dictionary:
	var d := hooks.duplicate(true)
	d["id"] = id
	d["name"] = name
	d["text"] = text
	d["kind"] = kind
	if d.has("aura") and not d.has("radius"):
		d["radius"] = AURA_RADIUS
	return d

## {class_id: [[nível, [opção, opção, opção]], ...]}
static func build() -> Dictionary:
	return {
		"paladin": [
			[5, [_o("pal_c_oath", "Voto do Escudo", "Juramento acumula até 8 cargas (eram 5).", "dano", {"oath_max": 8}),
				_o("pal_c_holy_mend", "Golpe Restaurador", "Golpe Sagrado cura 12% do dano causado.", "sobrevivência", {"skill_mods": {"pal_holy_strike": {"effects": {"heal_pct_of_dmg": 0.12}}}}),
				_o("pal_c_resolve", "Determinação", "+8% de HP e +60 de VIT.", "sobrevivência", {"stats": {"hp_pct": 8, "attr_VIT": 60}})]],
			[10, [_o("pal_c_bulwark", "Baluarte", "Armadura Abençoada e Muralha de Escudo ficam sempre ativas em você (60% da força, sem a lentidão).", "permanente",
					{"permanent": ["pal_blessed_armor", "pal_shield_wall"], "strength": 0.6}),
				_o("pal_c_aura_prot", "Aura de Proteção", "Armadura Abençoada e Muralha de Escudo viram aura: você e o grupo a 15 m (40% da força).", "aura",
					{"aura": ["pal_blessed_armor", "pal_shield_wall"], "strength": 0.4}),
				_o("pal_c_zeal", "Lâmina da Fé", "Zelo fica sempre ativo em você (50% da força).", "permanente", {"permanent": ["pal_zeal"], "strength": 0.5})]],
			[15, [_o("pal_c_aegis", "Égide", "Escudo Divino cobre o grupo a 8 m.", "aura", {"skill_mods": {"pal_divine_shield": {"set": {"radius": 8.0}}}}),
				_o("pal_c_hands", "Mãos Rápidas", "Imposição de Mãos recarrega 40% mais rápido.", "sobrevivência", {"skill_mods": {"pal_lay_hands": {"mult": {"cooldown": 0.6}}}}),
				_o("pal_c_taunt_heal", "Desafio Sagrado", "Provocar cura 8% do seu HP.", "sobrevivência", {"skill_mods": {"pal_taunt": {"effects": {"heal_pct": 8}}}})]],
			[20, [_o("pal_c_aura_crusade", "Aura de Cruzada", "Zelo vira aura: você e o grupo a 15 m (35% da força).", "aura", {"aura": ["pal_zeal"], "strength": 0.35}),
				_o("pal_c_valor", "Valor Eterno", "Valor fica sempre ativo em você (40% da força).", "permanente", {"permanent": ["pal_valor"], "strength": 0.4}),
				_o("pal_c_judge", "Juiz", "+30% de dano em alvos abaixo de 30% do HP.", "dano", {"execute": {"below": 0.3, "dmg_pct": 30}})]],
			[25, [_o("pal_c_retri", "Retribuição Plena", "Retribuição +40% de dano e cura 50% do dano causado.", "dano", {"skill_mods": {"pal_retribution": {"mult": {"power": 1.4}, "effects": {"heal_pct_of_dmg": 0.5}}}}),
				_o("pal_c_wall_cd", "Muralha Rápida", "Muralha de Escudo e Escudo Divino recarregam 35% mais rápido.", "sobrevivência",
					{"skill_mods": {"pal_shield_wall": {"mult": {"cooldown": 0.65}}, "pal_divine_shield": {"mult": {"cooldown": 0.65}}}}),
				_o("pal_c_consecrate", "Solo Sagrado", "Consagração e Fogo Purificador 40% maiores; Consagração retarda inimigos.", "dano",
					{"skill_mods": {"pal_consecrate": {"mult": {"radius": 1.4}, "effects": {"slow": {"pct": 30, "duration": 1.5}}}, "pal_cleansing_fire": {"mult": {"radius": 1.4}}}})]],
			[30, [_o("pal_c_last", "Último Bastião", "Golpe fatal: fica com 1 HP e imortal por 5 s (uma vez a cada 90 s).", "sobrevivência", {"cheat_death": {"cd": 90.0, "dur": 5.0}}),
				_o("pal_c_light", "Luz Final", "Aura: você e o grupo a 15 m regeneram 1% do HP por segundo.", "aura", {"regen": {"pct": 1.0, "aura": true}}),
				_o("pal_c_avatar", "Avatar", "+12% de ATK e MATK e +60 de FOR.", "dano", {"stats": {"atk_pct": 12, "matk_pct": 12, "attr_FOR": 60}})]],
		],
		"berserker": [
			[5, [_o("ber_c_undying", "Recusa a Morrer", "Golpe fatal: fica com 1 HP e imortal por 6 s (uma vez a cada 60 s).", "sobrevivência", {"cheat_death": {"cd": 60.0, "dur": 6.0}}),
				_o("ber_c_bloodlust", "Sede Eterna", "Sede de Sangue fica sempre ativa em você.", "permanente", {"permanent": ["ber_bloodlust"], "strength": 1.0}),
				_o("ber_c_wounded", "Fera Ferida", "Abaixo de 50% do HP: +18% de dano.", "dano", {"low_hp": {"below": 0.5, "dmg_pct": 18}})]],
			[10, [_o("ber_c_fury_long", "Fúria sem Fim", "Fúria dura o dobro e recarrega 30% mais rápido.", "dano", {"skill_mods": {"ber_fury": {"mult": {"cooldown": 0.7, "duration": 2.0}}}}),
				_o("ber_c_warcry", "Grito de Guerra", "Sede de Sangue vira aura: você e o grupo a 15 m (60% da força).", "aura", {"aura": ["ber_bloodlust"], "strength": 0.6}),
				_o("ber_c_twin", "Machado Gêmeo", "Talho Duplo, Presas Gêmeas e Machadinha Voadora +20% de dano.", "dano", {"skill_mods": {"ber_hack": {"mult": {"power": 1.2}}, "ber_twin_fang": {"mult": {"power": 1.2}}, "ber_hatchet": {"mult": {"power": 1.2}}}})]],
			[15, [_o("ber_c_cleave", "Rachar Amplo", "Rachar e Redemoinho 25% maiores.", "dano", {"skill_mods": {"ber_cleave": {"mult": {"radius": 1.25}}, "ber_whirlwind": {"mult": {"radius": 1.25}}}}),
				_o("ber_c_massacre", "Massacre", "Matar renova a Sede de Sangue.", "dano", {"on_kill": {"buff": "ber_bloodlust"}}),
				_o("ber_c_titan", "Pele de Titã", "Pegada de Titã fica sempre ativa (50% da força, sem perder DEF).", "permanente", {"permanent": ["ber_titan_grip"], "strength": 0.5})]],
			[20, [_o("ber_c_leech", "Carnificina", "+5% de roubo de vida.", "sobrevivência", {"stats": {"lifesteal": 5}}),
				_o("ber_c_hot", "Sangue Quente", "+10% de velocidade de ataque.", "dano", {"stats": {"aspd_pct": 10}}),
				_o("ber_c_exec", "Executor", "+30% de dano em alvos abaixo de 30% do HP.", "dano", {"execute": {"below": 0.3, "dmg_pct": 30}})]],
			[25, [_o("ber_c_whirl", "Redemoinho Sedento", "Redemoinho e Turbilhão de Aço curam 20% do dano.", "sobrevivência",
					{"skill_mods": {"ber_whirlwind": {"effects": {"heal_pct_of_dmg": 0.2}}, "ber_steel_whirl": {"effects": {"heal_pct_of_dmg": 0.2}}}}),
				_o("ber_c_leap", "Salto Atordoante", "Salto atordoa 1 s onde cai.", "utilidade", {"skill_mods": {"ber_leap": {"effects": {"stun": {"duration": 1.0}}}}}),
				_o("ber_c_fury_aura", "Sangue Fervente", "Fúria vira aura: você e o grupo a 15 m (40% da força).", "aura", {"aura": ["ber_fury"], "strength": 0.4})]],
			[30, [_o("ber_c_ancient", "Ira Ancestral", "Fúria fica sempre ativa em você (40% da força).", "permanente", {"permanent": ["ber_fury"], "strength": 0.4}),
				_o("ber_c_bloodbath", "Banho de Sangue", "Cada abate cura 6% do HP.", "sobrevivência", {"on_kill": {"heal_pct": 6}}),
				_o("ber_c_giant", "Gigante", "+10% de HP, +80 de FOR e +80 de VIT.", "sobrevivência", {"stats": {"hp_pct": 10, "attr_FOR": 80, "attr_VIT": 80}})]],
		],
		"bishop": [
			[5, [_o("bis_c_blessing", "Bênção Eterna", "Bênção vira aura: você e o grupo a 15 m (50% da força).", "aura", {"aura": ["bis_blessing"], "strength": 0.5}),
				_o("bis_c_ward", "Proteção Eterna", "Égide Divina vira aura: você e o grupo a 15 m (50% da força).", "aura", {"aura": ["bis_ward"], "strength": 0.5}),
				_o("bis_c_radiant", "Radiante", "+10% de Radiância.", "sobrevivência", {"stats": {"radiance": 10}})]],
			[10, [_o("bis_c_angel", "Anjo Guardião", "Asas Angelicais duram o dobro e recarregam 40% mais rápido.", "sobrevivência", {"skill_mods": {"bis_angel": {"mult": {"cooldown": 0.6, "duration": 2.0}}}}),
				_o("bis_c_zealot", "Fervor Eterno", "Fervor fica sempre ativo em você (60% da força).", "permanente", {"permanent": ["bis_zealot"], "strength": 0.6}),
				_o("bis_c_heal", "Cura Ampla", "Curar atinge 2 alvos a mais.", "sobrevivência", {"skill_mods": {"bis_heal": {"set": {"radius": 6.0}}}})]],
			[15, [_o("bis_c_martyr", "Martírio Partilhado", "Mártir cobre o grupo a 8 m.", "aura", {"skill_mods": {"bis_martyr": {"set": {"radius": 8.0}}}}),
				_o("bis_c_sanct", "Santuário Maior", "Santuário 50% maior.", "sobrevivência", {"skill_mods": {"bis_sanctuary": {"mult": {"radius": 1.5}}}}),
				_o("bis_c_renew", "Renovação", "Aura: você e o grupo a 15 m regeneram 0,8% do HP por segundo.", "aura", {"regen": {"pct": 0.8, "aura": true}})]],
			[20, [_o("bis_c_full_rad", "Radiância Plena", "Radiância pode chegar a 60% (o limite era 40%) e +8% de Radiância.", "sobrevivência", {"stats": {"radiance": 8, "radiance_cap": 20}}),
				_o("bis_c_miracle", "Milagre Frequente", "Milagre recarrega 40% mais rápido.", "sobrevivência", {"skill_mods": {"bis_miracle": {"mult": {"cooldown": 0.6}}}}),
				_o("bis_c_light", "Mão Firme", "Luz Sagrada atravessa inimigos; Luz Sagrada e Martelada da Fé +15% de dano.", "dano",
					{"skill_mods": {"bis_light": {"set": {"projectile_pierce": true}, "mult": {"power": 1.15}}, "bis_holy_blow": {"mult": {"power": 1.15}}}})]],
			[25, [_o("bis_c_smite", "Castigo", "Castigar e Martelo de Luz atordoam 0,6 s.", "utilidade",
					{"skill_mods": {"bis_smite": {"effects": {"stun": {"duration": 0.6}}}, "bis_hammer": {"effects": {"stun": {"duration": 0.6}}}}}),
				_o("bis_c_prayer", "Coro", "Prece 40% maior.", "sobrevivência", {"skill_mods": {"bis_prayer": {"mult": {"radius": 1.4}}}}),
				_o("bis_c_mind", "Mente Clara", "+15% de MP e −10% de recarga.", "utilidade", {"stats": {"mp_pct": 15, "cdr": 10}})]],
			[30, [_o("bis_c_intercede", "Intercessão", "Um aliado do grupo a 15 m que cairia fica com 1 HP e imortal por 4 s (uma vez a cada 120 s).", "sobrevivência",
					{"ally_save": {"cd": 120.0, "dur": 4.0, "radius": 15.0}}),
				_o("bis_c_ascend", "Ascensão", "+20% de cura e +10% de MATK.", "sobrevivência", {"stats": {"heal_pct": 20, "matk_pct": 10}}),
				_o("bis_c_wrath", "Juízo", "Ira Divina, Condenar e Martelo Divino +30% de dano.", "dano",
					{"skill_mods": {"bis_wrath": {"mult": {"power": 1.3}}, "bis_condemn": {"mult": {"power": 1.3}}, "bis_divine_hammer": {"mult": {"power": 1.3}}}})]],
		],
		"druid": [
			[5, [_o("dru_c_pack", "Matilha Fiel", "Os Lobos Espirituais ficam para sempre.", "invocação", {"summon_permanent": ["dru_spirit_wolves"]}),
				_o("dru_c_grove_guard", "Guardião do Bosque", "O Ent fica para sempre.", "invocação", {"summon_permanent": ["dru_treant"]}),
				_o("dru_c_bark", "Pele Eterna", "Pele de Casca fica sempre ativa em você.", "permanente", {"permanent": ["dru_bark"], "strength": 1.0})]],
			[10, [_o("dru_c_forms", "Instinto", "As formas dão 40% a mais de bônus.", "dano", {"form_mult": 1.4}),
				_o("dru_c_grove", "Bosque Vivo", "Bênção do Bosque vira aura: você e o grupo a 15 m (50% da força).", "aura", {"aura": ["dru_grove"], "strength": 0.5}),
				_o("dru_c_regrowth", "Rebrotar Amplo", "Rebrotar alcança 60% mais longe.", "sobrevivência", {"skill_mods": {"dru_regrowth": {"mult": {"radius": 1.6}}}})]],
			[15, [_o("dru_c_bellow", "Rugido do Bosque", "Urro da Mata cura 8% do HP e +20% de área.", "sobrevivência", {"skill_mods": {"dru_bellow": {"mult": {"radius": 1.2}, "effects": {"heal_pct": 8}}}}),
				_o("dru_c_frenzy", "Uivo Eterno", "Frenesi fica sempre ativo em você (40% da força).", "permanente", {"permanent": ["dru_frenzy"], "strength": 0.4}),
				_o("dru_c_thorns", "Espinhos Fundos", "Espinhos atravessam inimigos e +20% de dano.", "dano", {"skill_mods": {"dru_thorns": {"set": {"projectile_pierce": true}, "mult": {"power": 1.2}}}})]],
			[20, [_o("dru_c_primal", "Fera Primordial", "As formas dão 60% a mais de bônus.", "dano", {"form_mult": 1.6}),
				_o("dru_c_roots", "Raízes Fundas", "Enredar prende por 2 s a mais.", "utilidade", {"skill_mods": {"dru_entangle": {"mult": {"duration": 2.0}}}}),
				_o("dru_c_wolves", "Alcateia", "+1 Lobo Espiritual no máximo.", "invocação", {"summon_extra": {"dru_spirit_wolves": 1}})]],
			[25, [_o("dru_c_prowl", "Caçador Noturno", "Espreitar dura o dobro e o bote saindo dele dá 2,0× de dano.", "dano", {"skill_mods": {"dru_prowl": {"mult": {"duration": 2.0}}}, "ambush_mult": 2.0}),
				_o("dru_c_ent", "Raiz Profunda", "O Ent tem +60% de força.", "invocação", {"stats": {"pet_pct": 60}}),
				_o("dru_c_regen", "Sangue Selvagem", "Na forma: regenera 1,5% do HP por segundo.", "sobrevivência", {"regen": {"pct": 1.5, "form": true}})]],
			[30, [_o("dru_c_avatar", "Avatar da Natureza", "+10% de ATK e MATK, +8% de HP e +60 de VIT.", "dano", {"stats": {"atk_pct": 10, "matk_pct": 10, "hp_pct": 8, "attr_VIT": 60}}),
				_o("dru_c_cycle", "Ciclo", "Cada abate cura 4% do HP e devolve 4% do MP.", "sobrevivência", {"on_kill": {"heal_pct": 4, "mp_pct": 4}}),
				_o("dru_c_forest", "Floresta Eterna", "Bênção do Bosque fica sempre ativa em você.", "permanente", {"permanent": ["dru_grove"], "strength": 1.0})]],
		],
		"ranger": [
			[5, [_o("ran_c_bond", "Laço de Sangue", "O lince tem +40% de força.", "invocação", {"stats": {"pet_pct": 40}}),
				_o("ran_c_trapper", "Armadilheiro", "Até 5 armadilhas (eram 3), que recarregam 30% mais rápido.", "utilidade",
					{"trap_max": 5, "skill_mods": {"ran_trap": {"mult": {"cooldown": 0.7}}, "ran_mine": {"mult": {"cooldown": 0.7}}, "ran_frost_trap": {"mult": {"cooldown": 0.7}}}}),
				_o("ran_c_eye", "Olho Treinado", "+6% de crítico e +60 de AGI.", "dano", {"stats": {"crit": 6.0, "attr_AGI": 60}})]],
			[10, [_o("ran_c_pack", "Matilha", "Instinto da Matilha fica sempre ativo em você e no lince (60% da força).", "permanente", {"permanent": ["ran_pack"], "strength": 0.6}),
				_o("ran_c_deadeye", "Mira Certeira", "Olho de Águia fica sempre ativo em você (50% da força).", "permanente", {"permanent": ["ran_deadeye"], "strength": 0.5}),
				_o("ran_c_mark", "Marca do Bando", "Marca do Caçador vira aura: você e o grupo a 15 m (40% da força).", "aura", {"aura": ["ran_mark"], "strength": 0.4})]],
			[15, [_o("ran_c_twin", "Segundo Lince", "Pode ter 2 linces.", "invocação", {"summon_extra": {"ran_companion": 1}}),
				_o("ran_c_pierce", "Flecha Longa", "Tiro Certeiro, Flecha Perfurante e Flecha do Vendaval +20% de dano e alcance.", "dano",
					{"skill_mods": {"ran_snipe": {"mult": {"power": 1.2, "range": 1.2}}, "ran_piercing": {"mult": {"power": 1.2, "range": 1.2}}, "ran_gale": {"mult": {"power": 1.2, "range": 1.2}}}}),
				_o("ran_c_disengage", "Recuo Armado", "Recuar recarrega 40% mais rápido.", "utilidade", {"skill_mods": {"ran_disengage": {"mult": {"cooldown": 0.6}}}})]],
			[20, [_o("ran_c_hunt", "Caçador", "+30% de dano em alvos abaixo de 30% do HP.", "dano", {"execute": {"below": 0.3, "dmg_pct": 30}}),
				_o("ran_c_sic", "Bote Brutal", "Ataque da Fera atordoa 1,5 s.", "utilidade", {"skill_mods": {"ran_sic": {"effects": {"stun": {"duration": 1.5}}}}}),
				_o("ran_c_mines", "Minas Grandes", "Mina Explosiva e Estrepes 50% maiores e +25% de dano.", "dano", {"skill_mods": {"ran_mine": {"mult": {"radius": 1.5, "power": 1.25}}, "ran_caltrops": {"mult": {"radius": 1.5, "power": 1.25}}}})]],
			[25, [_o("ran_c_lynx_heal", "Laço Vital", "Aura: você e o lince regeneram 1% do HP por segundo.", "sobrevivência", {"regen": {"pct": 1.0, "aura": true}}),
				_o("ran_c_cdr", "Fôlego", "−15% de recarga em todas as skills.", "utilidade", {"stats": {"cdr": 15}}),
				_o("ran_c_volley", "Chuva de Flechas", "Saraivada e Barragem +25% de dano.", "dano", {"skill_mods": {"ran_volley": {"mult": {"power": 1.25}}, "ran_barrage": {"mult": {"power": 1.25}}}})]],
			[30, [_o("ran_c_alpha", "Alfa", "O lince tem +100% de força.", "invocação", {"stats": {"pet_pct": 100}}),
				_o("ran_c_ghost", "Tiro Fantasma", "Tiro na Cabeça atravessa e +30% de dano.", "dano", {"skill_mods": {"ran_headshot": {"set": {"projectile_pierce": true}, "mult": {"power": 1.3}}}}),
				_o("ran_c_survivor", "Sobrevivente", "Golpe fatal: fica com 1 HP e imortal por 4 s (uma vez a cada 90 s).", "sobrevivência", {"cheat_death": {"cd": 90.0, "dur": 4.0}})]],
		],
		"assassin": [
			[5, [_o("ass_c_venom", "Lâmina Envenenada", "Lâmina Pestilenta fica sempre ativa em você (veneno em todo golpe).", "permanente", {"permanent": ["ass_plague_blade"], "strength": 0.8}),
				_o("ass_c_reflex", "Reflexos Natos", "Reflexos ficam sempre ativos em você (40% da força).", "permanente", {"permanent": ["ass_reflexes"], "strength": 0.4}),
				_o("ass_c_ambush", "Emboscada", "O golpe saindo da furtividade dá 2,0× de dano (era 1,6×).", "dano", {"ambush_mult": 2.0})]],
			[10, [_o("ass_c_vanish", "Sombra Rápida", "Sumir recarrega 40% mais rápido e dura 50% a mais.", "utilidade", {"skill_mods": {"ass_vanish": {"mult": {"cooldown": 0.6, "duration": 1.5}}}}),
				_o("ass_c_focus", "Foco Absoluto", "Foco do Duelista fica sempre ativo em você (50% da força).", "permanente", {"permanent": ["ass_focus"], "strength": 0.5}),
				_o("ass_c_evade", "Bailarino", "+6% de esquiva e +60 de AGI.", "sobrevivência", {"stats": {"evasion": 6.0, "attr_AGI": 60}})]],
			[15, [_o("ass_c_guard", "Duelista", "Guarda do Duelista fica sempre ativa em você (50% da força).", "permanente", {"permanent": ["ass_guard"], "strength": 0.5}),
				_o("ass_c_backstab", "Pelas Costas", "+20% de dano pelas costas.", "dano", {"stats": {"backstab": 20}}),
				_o("ass_c_toxin", "Toxina Forte", "Dardo Venenoso, Nuvem Tóxica e Abrolhos +30% de dano.", "dano", {"skill_mods": {"ass_venom_dart": {"mult": {"power": 1.3}}, "ass_toxic_cloud": {"mult": {"power": 1.3}}, "ass_caltrops": {"mult": {"power": 1.3}}}})]],
			[20, [_o("ass_c_shadow", "Sombra", "Cada abate: some por 2 s (furtividade).", "utilidade", {"on_kill": {"stealth": 2.0}}),
				_o("ass_c_dance", "Dança de Lâminas", "+10% de velocidade de ataque.", "dano", {"stats": {"aspd_pct": 10}}),
				_o("ass_c_crit", "Olho Frio", "+6% de crítico.", "dano", {"stats": {"crit": 6.0}})]],
			[25, [_o("ass_c_escape", "Fuga", "Sumir cura 15% do HP.", "sobrevivência", {"skill_mods": {"ass_vanish": {"effects": {"heal_pct": 15}}}}),
				_o("ass_c_eviscerate", "Eviscerar", "Eviscerar, Golpe de Mestre e Golpe Baixo +25% de dano.", "dano", {"skill_mods": {"ass_eviscerate": {"mult": {"power": 1.25}}, "ass_master": {"mult": {"power": 1.25}}, "ass_cheap_shot": {"mult": {"power": 1.25}}}}),
				_o("ass_c_leech", "Lâmina Sedenta", "+4% de roubo de vida.", "sobrevivência", {"stats": {"lifesteal": 4}})]],
			[30, [_o("ass_c_death", "Morte Certa", "+50% de dano em alvos abaixo de 25% do HP.", "dano", {"execute": {"below": 0.25, "dmg_pct": 50}}),
				_o("ass_c_phantom", "Fantasma", "Golpe fatal: fica com 1 HP, imortal e invisível por 4 s (uma vez a cada 90 s).", "sobrevivência", {"cheat_death": {"cd": 90.0, "dur": 4.0, "stealth": true}}),
				_o("ass_c_thousand", "Mil Cortes", "Mil Cortes e Rajada de Lâminas +30% de dano.", "dano", {"skill_mods": {"ass_thousand": {"mult": {"power": 1.3}}, "ass_blade_flurry": {"mult": {"power": 1.3}}}})]],
		],
		"elementalist": [
			[5, [_o("ele_c_bound", "Elemental Vinculado", "O elemental fica para sempre (invocar outro troca de elemento).", "invocação",
					{"summon_permanent": ["ele_summon_fire", "ele_summon_ice", "ele_summon_storm"]}),
				_o("ele_c_overload", "Sobrecarga Contínua", "Sobrecarga fica sempre ativa em você (50% da força).", "permanente", {"permanent": ["ele_overload"], "strength": 0.5}),
				_o("ele_c_armor", "Armadura Gélida", "Armadura de Gelo fica sempre ativa em você (DEF, 60% da força; o escudo segue só ao lançar).", "permanente", {"permanent": ["ele_frost_armor"], "strength": 0.6})]],
			[10, [_o("ele_c_fire", "Coração de Fogo", "+10% de dano de fogo.", "dano", {"stats": {"fire_pct": 10}}),
				_o("ele_c_frost", "Coração de Gelo", "+10% de dano de gelo.", "dano", {"stats": {"frost_pct": 10}}),
				_o("ele_c_storm", "Coração de Raio", "+10% de dano de raio.", "dano", {"stats": {"storm_pct": 10}})]],
			[15, [_o("ele_c_elemental", "Elemental Forte", "O elemental tem +50% de força.", "invocação", {"stats": {"pet_pct": 50}}),
				_o("ele_c_combo", "Fusão", "Combos (Brasas, Choque Térmico, Granizo, Prisma) +25% de dano.", "dano",
					{"skill_mods": {"ele_firestorm": {"mult": {"power": 1.25}}, "ele_frost_flare": {"mult": {"power": 1.25}}, "ele_hailstorm": {"mult": {"power": 1.25}}, "ele_prism": {"mult": {"power": 1.25}}}}),
				_o("ele_c_blink", "Piscar Rápido", "Piscar recarrega 40% mais rápido.", "utilidade", {"skill_mods": {"ele_blink": {"mult": {"cooldown": 0.6}}}})]],
			[20, [_o("ele_c_shatter", "Estilhaço", "Estilhaçar e Lança de Gelo +30% de dano.", "dano", {"skill_mods": {"ele_shatter": {"mult": {"power": 1.3}}, "ele_ice_lance": {"mult": {"power": 1.3}}}}),
				_o("ele_c_burn", "Brasa Viva", "Bola de Fogo e Combustão +25% de área.", "dano", {"skill_mods": {"ele_fireball": {"mult": {"radius": 1.25}}, "ele_combustion": {"mult": {"radius": 1.25}}}}),
				_o("ele_c_chain", "Corrente Longa", "Corrente Elétrica acerta 2 alvos a mais.", "dano", {"skill_mods": {"ele_chain": {"set": {"max_targets": 6}}}})]],
			[25, [_o("ele_c_mana", "Fonte de Mana", "Cada abate devolve 5% do MP.", "utilidade", {"on_kill": {"mp_pct": 5}}),
				_o("ele_c_shield", "Escudo de Mana", "20% do dano recebido sai do MP.", "sobrevivência", {"mana_shield": {"pct": 20}}),
				_o("ele_c_mind", "Mente Arcana", "+15% de MP, +80 de INT.", "utilidade", {"stats": {"mp_pct": 15, "attr_INT": 80}})]],
			[30, [_o("ele_c_archmage", "Arquimago", "−20% de recarga em todas as skills.", "utilidade", {"stats": {"cdr": 20}}),
				_o("ele_c_avatar", "Avatar Elemental", "+15% de MATK e +6% de crítico.", "dano", {"stats": {"matk_pct": 15, "crit": 6.0}}),
				_o("ele_c_cataclysm", "Cataclismo", "Meteoro, Inferno e Zero Absoluto recarregam 40% mais rápido.", "dano",
					{"skill_mods": {"ele_meteor": {"mult": {"cooldown": 0.6}}, "ele_inferno": {"mult": {"cooldown": 0.6}}, "ele_absolute_zero": {"mult": {"cooldown": 0.6}}}})]],
		],
		"necromancer": [
			[5, [_o("nec_c_army", "Exército Eterno", "Os esqueletos do Erguer Mortos ficam para sempre.", "invocação", {"summon_permanent": ["nec_raise"]}),
				_o("nec_c_hounds", "Cão Fiel", "Os Cães de Ossos ficam para sempre.", "invocação", {"summon_permanent": ["nec_bone_hound"]}),
				_o("nec_c_pact", "Pacto Eterno", "Pacto Sombrio fica sempre ativo em você (60% da força).", "permanente", {"permanent": ["nec_dark_pact"], "strength": 0.6})]],
			[10, [_o("nec_c_more", "Legião", "+1 esqueleto no máximo do Erguer Mortos.", "invocação", {"summon_extra": {"nec_raise": 1}}),
				_o("nec_c_curses", "Maldições Amplas", "Maldições 40% maiores.", "utilidade",
					{"skill_mods": {"nec_curse_weakness": {"mult": {"radius": 1.4}}, "nec_curse_doom": {"mult": {"radius": 1.4}}, "nec_curse_agony": {"mult": {"radius": 1.4}}}}),
				_o("nec_c_bones", "Ossos Vivos", "Armadura de Ossos fica sempre ativa em você (DEF, 50% da força).", "permanente", {"permanent": ["nec_bone_armor"], "strength": 0.5})]],
			[15, [_o("nec_c_king", "Rei Eterno", "O Rei Esqueleto fica para sempre.", "invocação", {"summon_permanent": ["nec_skeleton_king"]}),
				_o("nec_c_lich", "Lich Eterno", "O Lich fica para sempre.", "invocação", {"summon_permanent": ["nec_lich"]}),
				_o("nec_c_drain", "Sede de Almas", "Sugar Alma +30% de dano e cura.", "sobrevivência", {"skill_mods": {"nec_drain_soul": {"mult": {"power": 1.3}}}})]],
			[20, [_o("nec_c_demon", "Demônio Desperto", "As formas (Demoníaca e Fantasma) dão 50% a mais de bônus.", "dano", {"form_mult": 1.5}),
				_o("nec_c_phantom", "Fantasma Longo", "Forma Fantasma dura o dobro.", "utilidade", {"form_time": {"phantom": 2.0}}),
				_o("nec_c_reap", "Ceifador", "Ceifar e Giro da Morte recarregam 30% mais rápido.", "dano", {"skill_mods": {"nec_reap": {"mult": {"cooldown": 0.7}}, "nec_death_spin": {"mult": {"cooldown": 0.7}}}})]],
			[25, [_o("nec_c_harvest", "Colheita", "Cada abate (seu ou dos servos) cura 3% do HP.", "sobrevivência", {"on_kill": {"heal_pct": 3, "minions": true}}),
				_o("nec_c_corpse", "Cadáveres", "Explosão de Cadáver 40% maior e +25% de dano.", "dano", {"skill_mods": {"nec_corpse_explosion": {"mult": {"radius": 1.4, "power": 1.25}}}}),
				_o("nec_c_doom", "Maldição Longa", "Maldições duram o dobro.", "utilidade",
					{"skill_mods": {"nec_curse_weakness": {"mult": {"duration": 2.0}}, "nec_curse_doom": {"mult": {"duration": 2.0}}, "nec_curse_agony": {"mult": {"duration": 2.0}}}})]],
			[30, [_o("nec_c_lord", "Senhor dos Mortos", "Servos com +60% de força.", "invocação", {"stats": {"pet_pct": 60}}),
				_o("nec_c_phylactery", "Filactério", "Golpe fatal: fica com 1 HP e imortal por 5 s (uma vez a cada 120 s).", "sobrevivência", {"cheat_death": {"cd": 120.0, "dur": 5.0}}),
				_o("nec_c_plague", "Praga", "Podridão, Enxame e Pandemia +30% de dano.", "dano",
					{"skill_mods": {"nec_rot": {"mult": {"power": 1.3}}, "nec_swarm": {"mult": {"power": 1.3}}, "nec_pandemic": {"mult": {"power": 1.3}}}})]],
		],
	}
