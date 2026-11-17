class_name ClassTalentsCatalog
extends RefCounted
## Talentos de classe (aba "Talentos" da janela K): a cada 5 níveis (5..45) uma linha com 3 escolhas que mudam o
## jeito de jogar a classe. Escolhe-se UMA por linha, é grátis (liberada pelo nível) e trocar é na cidade.
## A sim lê só os ganchos abaixo (ClassTalentSystem); o resto é texto. Números iniciais, calibrados pelos probes.
##
## Ganchos genéricos:
##   permanent: [skill]  + strength     o buff da skill fica sempre ativo em você (só os bônus positivos × strength)
##   aura: [skill] + strength + radius  o mesmo, em você e nos aliados do grupo/invocações perto
##   summon_permanent: [skill]          as invocações da skill não expiram
##   summon_extra: {skill: n}           +n no máximo de invocações da skill
##   skill_mods: {skill: {set, mult, effects, add}}   como as evoluções (TalentsCatalog); `add` SOMA ao efeito final (base + maestria + evolução)
##   stats: {...}                       bônus fixo (formato de buff: atk_pct, crit, attr_FOR...)
##   form_mult                          multiplica os bônus das formas (lobo, urso, demônio, fantasma)
##   form_stats {...}                   bônus fixo (formato de buff) que só vale na forma (Uivo da Lua)
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
##   summon_time x                      invocações com tempo duram x vezes (as permanentes seguem permanentes)
##   dot_boost {time, dps}              seus danos no tempo mágicos (não sangramento) duram time× e batem dps× por segundo
## (o teto da Radiância sobe com stats.radiance_cap)
## Regra (check _check_talent_unlock_levels): toda opção da linha N cita skill aberta até N; gancho genérico
## (summon_time, dot_boost, form_*, stats.pet_pct) precisa de skill da classe do tipo aberta até N. Números das trocas de
## 2026-11-16 em Balance.CT_* (design/balance/class-talents-audit-2026-11-16.md).
## Ato II (design/gdd/ato2-horda.md R6/R7): linhas 35, 40 e 45, uma opção pensada para cada build (`build`, sem trava:
## só diz qual o bot da build escolhe). 35 = identidade da build nas lutas do Ato II (bandos com líder, trolls,
## assassinos, investidas), sem depender da ascensão. 40/45 = refinos sobre skills que já existem; os refinos de R6.1
## que precisavam da mecânica de ascensão viraram portões da teia de ascensão (AscensionCatalog.NODES); ASC_REFINES_PENDING ficou vazio.

const ROW_LEVELS := [5, 10, 15, 20, 25, 30, 35, 40, 45]
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

## Refinos de ascensão (R6.1) que AINDA NÃO SÃO TALENTOS: dependem de mecânica que não existe nesta fase.
## Hoje vazio: todos viraram portões da teia de ascensão (AscensionCatalog.NODES, `flag`).
## {classe: [{level, build, name, text, needs}]}; `needs` = a mecânica de ascensão que falta. Quando ela entrar, o refino
## vira opção da linha (troca ou soma com a opção da mesma build). Nada aqui é lido pela sim nem aparece na janela.
const ASC_REFINES_PENDING := {
	"paladin": [],          # viraram portões da teia de ascensão (AscensionCatalog.NODES: Asas com Bloqueio, Asas Protetoras, Muralha a Cavalo, Estandarte)
	"berserker": [],        # viraram portões da teia de ascensão (Giro dos Dois Machados, Segundo Machado, Fúria Acesa, Golpe Final da Arena, Glória que Não Esfria)
	"bishop": [],      # Coro Celeste feito: os refinos viraram nós da teia de ascensão (AscensionCatalog.NODES)
	"ranger": [],           # Salto Duplo e Brado Combinado (Lanceiro) e as torretas viraram portões da teia de ascensão
	"assassin": [],          # Sombras Gêmeas entrou: os 3 refinos viraram nós da teia de ascensão (AscensionCatalog.NODES / ass_hand_cannon)
	"druid": [],            # Forma Ancestral feita: os refinos são nós da teia de ascensão (AscensionCatalog.NODES)
	"elementalist": [],     # Salamandra, Golem de Gelo e Silfo viraram portões da teia de ascensão (AscensionCatalog.NODES: elem_refine_*)
	"necromancer": [],          # viraram nós da teia de ascensão (AscensionCatalog.NODES: Exército, Foice que Comanda, Miasma Largo)
}

## Escolha do bot imposta por build x linha (vence a nota de `ClassTalentSystem.bot_score`): onde a opção de
## sobrevivência carrega a build e a regra pegaria a de skill. {build_id: {nível: id da opção}}; o id tem de existir
## naquela linha da classe da build (check `_check_bot_talent_prefs`). Medição em design/balance/class-talents-audit-2026-11-16.md
## ("Bots: exceções por build").
const BOT_PREFER := {
	"cruzado": {5: "pal_c_resolve"},        # Determinação: solo x death_knight 3/40 -> 34/40; grupo igual
	"laminas": {25: "ass_c_leech"},         # Lâmina Sedenta (no lugar da Fuga): solo x death_knight 5/40 -> 40/40; grupo igual ou melhor
	"gelo": {25: "ele_c_shield"},           # Escudo de Mana (no lugar da Fonte de Mana): solo x death_knight 24/40 -> 36/40; grupo igual ou melhor
}

## Opção pensada para uma build (linhas 35+): igual a `_o`, mais `build` (o bot da build escolhe esta).
static func _b(build_id: String, id: String, name: String, text: String, kind: String, hooks: Dictionary) -> Dictionary:
	var d := _o(id, name, text, kind, hooks)
	d["build"] = build_id
	return d

## Catálogo montado uma vez (montar custa ~1,3 ms; bot_pick pedia a cada bot). Nunca entregue sem copiar.
static var _cache := {}

## {class_id: [[nível, [opção, opção, opção]], ...]}. Cópia funda: quem chama pode mexer à vontade.
## Ex.: `for row in ClassTalentsCatalog.build()["paladin"]: print(row[0])`.
## Monta o cache já no `GameData._ready` (thread principal): o `_built` preguiçoso não tem trava e a sim roda
## numa WorkerThreadPool (SimSync), onde dois bots montariam o catálogo ao mesmo tempo.
static func warm() -> void:
	_built()

static func build() -> Dictionary:
	return _built().duplicate(true)

## Linhas da classe SÓ PARA LEITURA (o mesmo array do cache: não altere). Ex.: `ClassTalentsCatalog.rows_of("bishop")`.
static func rows_of(class_id: String) -> Array:
	return _built().get(class_id, [])

static func _built() -> Dictionary:
	if _cache.is_empty():
		_cache = _make()
	return _cache

static func _make() -> Dictionary:
	return {
		"paladin": [
			[5, [_o("pal_c_oath", "Voto do Escudo", "Juramento acumula até 8 cargas (eram 5).", "dano", {"oath_max": 8}),
				_o("pal_c_holy_mend", "Golpe Restaurador", "Golpe Sagrado cura +12% do dano causado (soma à cura que ele já tem).", "sobrevivência", {"skill_mods": {"pal_holy_strike": {"add": {"heal_pct_of_dmg": Balance.CT_HOLY_MEND_ADD}}}}),
				_o("pal_c_resolve", "Determinação", "+8% de HP e +60 de VIT.", "sobrevivência", {"stats": {"hp_pct": 8, "attr_VIT": 60}})]],
			[10, [_o("pal_c_bulwark", "Baluarte", "Armadura Abençoada e Muralha de Escudo ficam sempre ativas em você (60% da força, sem a lentidão).", "permanente",
					{"permanent": ["pal_blessed_armor", "pal_shield_wall"], "strength": 0.6}),
				_o("pal_c_flame_strike", "Golpe Ardente", "Chama Sagrada +20% de dano e queima 5 s a mais.", "dano", {"skill_mods": {"pal_sacred_flame": {"mult": {"power": Balance.CT_SKILL_POWER}, "add": {"dot": {"duration": Balance.CT_FLAME_STRIKE_ADD_S}}}}}),
				_o("pal_c_faith_arc", "Arco da Fé", "Arco Radiante e Martelo de Luz +20% de dano.", "dano", {"skill_mods": {"pal_twin_slash": {"mult": {"power": Balance.CT_SKILL_POWER}}, "pal_hammer_light": {"mult": {"power": Balance.CT_SKILL_POWER}}}})]],
			[15, [_o("pal_c_steady_lunge", "Investida Firme", "Estocada Sagrada recarrega 25% mais rápido.", "dano", {"skill_mods": {"pal_lunge": {"mult": {"cooldown": Balance.CT_LUNGE_CD}}}}),
				_o("pal_c_hands", "Mãos Rápidas", "Imposição de Mãos recarrega 40% mais rápido.", "sobrevivência", {"skill_mods": {"pal_lay_hands": {"mult": {"cooldown": 0.6}}}}),
				_o("pal_c_taunt_heal", "Desafio Sagrado", "Provocar cura 8% do seu HP.", "sobrevivência", {"skill_mods": {"pal_taunt": {"effects": {"heal_pct": 8}}}})]],
			[20, [_o("pal_c_aura_crusade", "Aura de Cruzada", "Zelo vira aura: você e o grupo a 15 m (60% da força).", "aura", {"aura": ["pal_zeal"], "strength": Balance.CT_CRUSADE_AURA}),
				_o("pal_c_living_bastion", "Bastião Vivo", "Aura do Bastião alcança 30% mais longe (o grupo e a queimadura em volta).", "aura", {"skill_mods": {"pal_bastion_aura": {"mult": {"radius": Balance.CT_AREA_MULT}}}}),
				_o("pal_c_judge", "Juiz", "+30% de dano em alvos abaixo de 30% do HP.", "dano", {"execute": {"below": 0.3, "dmg_pct": 30}})]],
			[25, [_o("pal_c_retri", "Retribuição Plena", "Retribuição +40% de dano e cura 50% do dano causado.", "dano", {"skill_mods": {"pal_retribution": {"mult": {"power": 1.4}, "effects": {"heal_pct_of_dmg": 0.5}}}}),
				_o("pal_c_wall_cd", "Muralha Rápida", "Muralha de Escudo e Escudo Divino recarregam 35% mais rápido.", "sobrevivência",
					{"skill_mods": {"pal_shield_wall": {"mult": {"cooldown": 0.65}}, "pal_divine_shield": {"mult": {"cooldown": 0.65}}}}),
				_o("pal_c_consecrate", "Solo Sagrado", "Consagração e Fogo Purificador 40% maiores; Consagração retarda inimigos.", "dano",
					{"skill_mods": {"pal_consecrate": {"mult": {"radius": 1.4}, "effects": {"slow": {"pct": 30, "duration": 1.5}}}, "pal_cleansing_fire": {"mult": {"radius": 1.4}}}})]],
			[30, [_o("pal_c_last", "Último Bastião", "Golpe fatal: fica com 1 HP e imortal por 5 s (uma vez a cada 90 s).", "sobrevivência", {"cheat_death": {"cd": 90.0, "dur": 5.0}}),
				_o("pal_c_light", "Luz Final", "Aura: você e o grupo a 15 m regeneram 1% do HP por segundo.", "aura", {"regen": {"pct": 1.0, "aura": true}}),
				_o("pal_c_avatar", "Avatar", "+12% de ATK e MATK e +60 de FOR.", "dano", {"stats": {"atk_pct": 12, "matk_pct": 12, "attr_FOR": 60}})]],
			[35, [_b("guardiao", "pal_c_shield_line", "Linha de Escudos", "Provocar alcança 30% mais longe e recarrega 25% mais rápido.", "utilidade", {"skill_mods": {"pal_taunt": {"mult": {"radius": 1.3, "cooldown": 0.75}}}}),
				_b("cruzado", "pal_c_breaker", "Quebra-Fileiras", "Golpe do Cruzado e Giro do Cruzado +25% de dano.", "dano", {"skill_mods": {"pal_crusader_strike": {"mult": {"power": 1.25}}, "pal_blade_dance": {"mult": {"power": 1.25}}}}),
				_b("templario", "pal_c_ember", "Fogo que Não Apaga", "A queimadura da Chama Sagrada e da Pira Sagrada é 50% mais forte e dura 6 s (eram 4 s).", "dano", {"skill_mods": {"pal_sacred_flame": {"effects": {"dot": {"dps": 7.5, "duration": 6}}}, "pal_flame_pyre": {"effects": {"dot": {"dps": 10.5, "duration": 6}}}}})]],
			[40, [_b("guardiao", "pal_c_rebound", "Escudo que Volta", "Escudo Ricochete +25% de dano e recarrega 25% mais rápido.", "dano", {"skill_mods": {"pal_shield_throw": {"mult": {"power": 1.25, "cooldown": 0.75}}}}),
				_b("cruzado", "pal_c_charge", "Investida do Cruzado", "Estocada Sagrada +25% de dano e recarrega 30% mais rápido.", "dano", {"skill_mods": {"pal_lunge": {"mult": {"power": 1.25, "cooldown": 0.7}}}}),
				_b("templario", "pal_c_long_wrath", "Ira Prolongada", "Ira Vingadora dura 50% a mais e recarrega 15% mais rápido.", "dano", {"skill_mods": {"pal_avenging_wrath": {"mult": {"duration": 1.5, "cooldown": 0.85}}}})]],
			[45, [_b("guardiao", "pal_c_unbroken", "Guarda Inabalável", "−6% de dano sofrido e +20% de ameaça.", "sobrevivência", {"stats": {"dr_pct": 6, "threat_pct": 20}}),
				_b("cruzado", "pal_c_sentence", "Sentença Final", "Sentença e Lâmina do Juízo +30% de dano.", "dano", {"skill_mods": {"pal_flurry": {"mult": {"power": 1.3}}, "pal_judgement_blade": {"mult": {"power": 1.3}}}}),
				_b("templario", "pal_c_sunrise", "Sol Nascente", "Golpe Solar +30% de dano e cura 35% do dano causado (eram 20%).", "dano", {"skill_mods": {"pal_sun_strike": {"mult": {"power": 1.3}, "effects": {"heal_pct_of_dmg": 0.35}}}})]],
		],
		"berserker": [
			[5, [_o("ber_c_undying", "Recusa a Morrer", "Golpe fatal: fica com 1 HP e imortal por 6 s (uma vez a cada 60 s).", "sobrevivência", {"cheat_death": {"cd": 60.0, "dur": 6.0}}),
				_o("ber_c_bloodlust", "Sede Eterna", "Sede de Sangue fica sempre ativa em você.", "permanente", {"permanent": ["ber_bloodlust"], "strength": 1.0}),
				_o("ber_c_wounded", "Fera Ferida", "Abaixo de 50% do HP: +18% de dano.", "dano", {"low_hp": {"below": 0.5, "dmg_pct": 18}})]],
			[10, [_o("ber_c_fury_long", "Fúria sem Fim", "Fúria dura o dobro e recarrega 30% mais rápido.", "dano", {"skill_mods": {"ber_fury": {"mult": {"cooldown": 0.7, "duration": 2.0}}}}),
				_o("ber_c_warcry", "Grito de Guerra", "Sede de Sangue vira aura: você e o grupo a 15 m (60% da força).", "aura", {"aura": ["ber_bloodlust"], "strength": 0.6}),
				_o("ber_c_twin", "Machado Gêmeo", "Talho Duplo, Presas Gêmeas e Socos Repetidos +20% de dano.", "dano", {"skill_mods": {"ber_hack": {"mult": {"power": 1.2}}, "ber_twin_fang": {"mult": {"power": 1.2}}, "ber_fist_flurry": {"mult": {"power": 1.2}}}})]],
			[15, [_o("ber_c_cleave", "Rachar Amplo", "Rachar e Redemoinho 25% maiores.", "dano", {"skill_mods": {"ber_cleave": {"mult": {"radius": 1.25}}, "ber_whirlwind": {"mult": {"radius": 1.25}}}}),
				_o("ber_c_massacre", "Massacre", "Matar renova a Sede de Sangue.", "dano", {"on_kill": {"buff": "ber_bloodlust"}}),
				_o("ber_c_split", "Terra Partida", "Racha-Terra 25% mais largo e atordoa 0,5 s.", "utilidade", {"skill_mods": {"ber_earthsplitter": {"mult": {"radius": Balance.CT_SPLIT_RADIUS}, "effects": {"stun": {"duration": Balance.CT_SPLIT_STUN}}}}})]],
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
			[35, [_b("carniceiro", "ber_c_reaper", "Ceifa-Bando", "Tempestade de Aço e Tempestade de Lâminas 25% maiores e +15% de dano.", "dano", {"skill_mods": {"ber_axe_storm": {"mult": {"radius": 1.25, "power": 1.15}}, "ber_bladestorm": {"mult": {"radius": 1.25, "power": 1.15}}}}),
				_b("executor", "ber_c_breaker", "Quebra-Líder", "Golpe Avassalador atordoa 1 s (era 0,5 s) e +20% de dano.", "utilidade", {"skill_mods": {"ber_overhead": {"mult": {"power": 1.2}, "effects": {"stun": {"duration": 1.0}}}}}),
				_b("punhos", "ber_c_street", "Guarda Alta", "Postura do Contra-Golpe dura 50% a mais e recarrega 15% mais rápido.", "sobrevivência", {"skill_mods": {"ber_counter_stance": {"mult": {"duration": 1.5, "cooldown": 0.85}}}})]],
			[40, [_b("carniceiro", "ber_c_twin_spin", "Giro Gêmeo", "Turbilhão de Aço e Tempestade de Aço recarregam 30% mais rápido.", "dano", {"skill_mods": {"ber_steel_whirl": {"mult": {"cooldown": 0.7}}, "ber_axe_storm": {"mult": {"cooldown": 0.7}}}}),
				_b("executor", "ber_c_headsman", "Lâmina do Carrasco", "Executar +30% de dano e recarrega 15% mais rápido.", "dano", {"skill_mods": {"ber_execute": {"mult": {"power": 1.3, "cooldown": 0.85}}}}),
				_b("punhos", "ber_c_ki", "Ki Inesgotável", "Chakra recarrega 30% mais rápido e Punho Final +20% de dano.", "sobrevivência", {"skill_mods": {"ber_chakra": {"mult": {"cooldown": 0.7}}, "ber_final_fist": {"mult": {"power": 1.2}}}})]],
			[45, [_b("carniceiro", "ber_c_red_storm", "Tormenta Rubra", "Rajada Rubra e Carnificina +30% de dano.", "dano", {"skill_mods": {"ber_crimson_flurry": {"mult": {"power": 1.3}}, "ber_butcher": {"mult": {"power": 1.3}}}}),
				_b("executor", "ber_c_arena", "Golpe de Arena", "Decapitar +30% de dano e recarrega 20% mais rápido.", "dano", {"skill_mods": {"ber_decapitate": {"mult": {"power": 1.3, "cooldown": 0.8}}}}),
				_b("punhos", "ber_c_thousand", "Mil Punhos", "Cem Punhos +30% de dano e 20% maior.", "dano", {"skill_mods": {"ber_hundred_fists": {"mult": {"power": 1.3, "radius": 1.2}}}})]],
		],
		"bishop": [
			[5, [_o("bis_c_heal", "Cura Ampla", "Curar atinge 2 alvos a mais.", "sobrevivência", {"skill_mods": {"bis_heal": {"set": {"radius": 6.0}}}}),
				_o("bis_c_wound_light", "Luz que Fere", "Luz Sagrada atravessa inimigos e +20% de dano.", "dano", {"skill_mods": {"bis_light": {"set": {"projectile_pierce": true}, "mult": {"power": Balance.CT_SKILL_POWER}}}}),
				_o("bis_c_radiant", "Radiante", "+10% de Radiância.", "sobrevivência", {"stats": {"radiance": 10}})]],
			[10, [_o("bis_c_blessing", "Bênção Eterna", "Bênção vira aura: você e o grupo a 15 m (50% da força).", "aura", {"aura": ["bis_blessing"], "strength": 0.5}),
				_o("bis_c_prayer", "Coro", "Prece 40% maior.", "sobrevivência", {"skill_mods": {"bis_prayer": {"mult": {"radius": 1.4}}}}),
				_o("bis_c_inq_hand", "Mão do Inquisidor", "Castigar e Martelo de Luz +20% de dano.", "dano", {"skill_mods": {"bis_smite": {"mult": {"power": Balance.CT_SKILL_POWER}}, "bis_hammer": {"mult": {"power": Balance.CT_SKILL_POWER}}}})]],
			[15, [_o("bis_c_blessed_mace", "Martelo Abençoado", "Martelada da Fé e Castigo do Escudo +20% de dano.", "dano", {"skill_mods": {"bis_holy_blow": {"mult": {"power": Balance.CT_SKILL_POWER}}, "bis_shield_smite": {"mult": {"power": Balance.CT_SKILL_POWER}}}}),
				_o("bis_c_sanct", "Santuário Maior", "Santuário 50% maior.", "sobrevivência", {"skill_mods": {"bis_sanctuary": {"mult": {"radius": 1.5}}}}),
				_o("bis_c_zealot", "Fervor Eterno", "Fervor fica sempre ativo em você (60% da força).", "permanente", {"permanent": ["bis_zealot"], "strength": 0.6})]],
			[20, [_o("bis_c_full_rad", "Radiância Plena", "Radiância pode chegar a 60% (o limite era 40%) e +8% de Radiância.", "sobrevivência", {"stats": {"radiance": 8, "radiance_cap": 20}}),
				_o("bis_c_radiant_nova", "Nova Radiante", "Nova Sagrada 30% maior e +20% de dano.", "dano", {"skill_mods": {"bis_holy_nova": {"mult": {"radius": Balance.CT_AREA_MULT, "power": Balance.CT_SKILL_POWER}}}}),
				_o("bis_c_light", "Mão Firme", "Luz Sagrada e Martelada da Fé +15% de dano.", "dano",
					{"skill_mods": {"bis_light": {"mult": {"power": 1.15}}, "bis_holy_blow": {"mult": {"power": 1.15}}}})]],
			[25, [_o("bis_c_smite", "Castigo", "Castigar atordoa 0,6 s e o Martelo de Luz atordoa 0,4 s a mais.", "utilidade",
					{"skill_mods": {"bis_smite": {"effects": {"stun": {"duration": 0.6}}}, "bis_hammer": {"add": {"stun": {"duration": Balance.CT_SMITE_HAMMER_ADD_S}}}}}),
				_o("bis_c_angel", "Anjo Guardião", "Asas Angelicais duram o dobro e recarregam 40% mais rápido.", "sobrevivência", {"skill_mods": {"bis_angel": {"mult": {"cooldown": 0.6, "duration": 2.0}}}}),
				_o("bis_c_mind", "Mente Clara", "+15% de MP e −10% de recarga.", "utilidade", {"stats": {"mp_pct": 15, "cdr": 10}})]],
			[30, [_o("bis_c_intercede", "Intercessão", "Um aliado do grupo a 15 m que cairia fica com 1 HP e imortal por 4 s (uma vez a cada 120 s).", "sobrevivência",
					{"ally_save": {"cd": 120.0, "dur": 4.0, "radius": 15.0}}),
				_o("bis_c_miracle", "Milagre Frequente", "Milagre recarrega 40% mais rápido.", "sobrevivência", {"skill_mods": {"bis_miracle": {"mult": {"cooldown": 0.6}}}}),
				_o("bis_c_wrath", "Juízo", "Ira Divina, Condenar e Martelo Divino +30% de dano.", "dano",
					{"skill_mods": {"bis_wrath": {"mult": {"power": 1.3}}, "bis_condemn": {"mult": {"power": 1.3}}, "bis_divine_hammer": {"mult": {"power": 1.3}}}})]],
			[35, [_b("sacerdote", "bis_c_field_mend", "Hospital de Campo", "Remendo Sagrado 40% maior e +20% de cura.", "sobrevivência", {"skill_mods": {"bis_mend": {"mult": {"radius": 1.4, "power": 1.2}}}}),
				_b("inquisidor", "bis_c_cauterize", "Luz que Cauteriza", "Condenar 20% maior; o chão queima 50% mais forte por 7 s (eram 5 s).", "dano", {"skill_mods": {"bis_condemn": {"mult": {"radius": 1.2}, "effects": {"dot": {"dps": 10.5, "duration": 7}}}}}),
				_b("batalha", "bis_c_front", "Frente Unida", "Hino de Batalha vira aura: você e o grupo a 15 m (40% da força).", "aura", {"aura": ["bis_battle_hymn"], "strength": 0.4})]],
			[40, [_b("sacerdote", "bis_c_fervent", "Prece Fervorosa", "Prece +25% de cura e recarrega 20% mais rápido.", "sobrevivência", {"skill_mods": {"bis_prayer": {"mult": {"power": 1.25, "cooldown": 0.8}}}}),
				_b("inquisidor", "bis_c_scorch", "Chão Sagrado", "Cruzada e Julgamento +25% de dano.", "dano", {"skill_mods": {"bis_crusade": {"mult": {"power": 1.25}}, "bis_judgement": {"mult": {"power": 1.25}}}}),
				_b("batalha", "bis_c_charge", "Carga do Clérigo", "Castigo do Escudo +25% de dano e recarrega 25% mais rápido.", "dano", {"skill_mods": {"bis_shield_smite": {"mult": {"power": 1.25, "cooldown": 0.75}}}})]],
			[45, [_b("sacerdote", "bis_c_great_miracle", "Milagre Maior", "Milagre +30% de cura e 25% maior.", "sobrevivência", {"skill_mods": {"bis_miracle": {"mult": {"power": 1.3, "radius": 1.25}}}}),
				_b("inquisidor", "bis_c_exorcist", "Exorcista", "Exorcismo e Purificar +30% de dano.", "dano", {"skill_mods": {"bis_exorcism": {"mult": {"power": 1.3}}, "bis_purify": {"mult": {"power": 1.3}}}}),
				_b("batalha", "bis_c_heavy_hand", "Mão Pesada", "Tremor Sagrado e Salto da Fé +15% de dano e curam o aliado mais ferido em 35% do dano (eram 20%).", "sobrevivência", {"skill_mods": {"bis_holy_quake": {"mult": {"power": 1.15}, "effects": {"mend_pct_of_dmg": 0.35}}, "bis_faith_leap": {"mult": {"power": 1.15}, "effects": {"mend_pct_of_dmg": 0.35}}}})]],
		],
		"druid": [
			[5, [_o("dru_c_crescent", "Lua Crescente", "Fogo Lunar +20% de dano e queima 2 s a mais.", "dano", {"skill_mods": {"dru_moonfire": {"mult": {"power": Balance.CT_SKILL_POWER}, "effects": {"dot": Balance.CT_DOTS["dru_moonfire"]}}}}),
				_o("dru_c_sharp_claws", "Garras Afiadas", "Garras e Dilacerar +20% de dano; Garras sangram 2 s a mais.", "dano", {"skill_mods": {"dru_claw": {"mult": {"power": Balance.CT_SKILL_POWER}, "effects": {"dot": Balance.CT_DOTS["dru_claw"]}}, "dru_maim": {"mult": {"power": Balance.CT_SKILL_POWER}}}}),
				_o("dru_c_bark", "Pele Eterna", "Pele de Casca fica sempre ativa em você.", "permanente", {"permanent": ["dru_bark"], "strength": 1.0})]],
			[10, [_o("dru_c_forms", "Instinto", "As formas dão 40% a mais de bônus.", "dano", {"form_mult": 1.4}),
				_o("dru_c_grove", "Bosque Vivo", "Bênção do Bosque vira aura: você e o grupo a 15 m (50% da força).", "aura", {"aura": ["dru_grove"], "strength": 0.5}),
				_o("dru_c_pack", "Matilha Fiel", "Os Lobos Espirituais ficam para sempre.", "invocação", {"summon_permanent": ["dru_spirit_wolves"]})]],
			[15, [_o("dru_c_bellow", "Rugido do Bosque", "Urro da Mata cura 8% do HP e +20% de área.", "sobrevivência", {"skill_mods": {"dru_bellow": {"mult": {"radius": 1.2}, "effects": {"heal_pct": 8}}}}),
				_o("dru_c_frenzy", "Uivo Eterno", "Frenesi fica sempre ativo em você (40% da força).", "permanente", {"permanent": ["dru_frenzy"], "strength": 0.4}),
				_o("dru_c_thorns", "Espinhos Fundos", "Espinhos atravessam inimigos e +20% de dano.", "dano", {"skill_mods": {"dru_thorns": {"set": {"projectile_pierce": true}, "mult": {"power": 1.2}}}})]],
			[20, [_o("dru_c_moon_howl", "Uivo da Lua", "Na forma (Lobo ou Urso): +15% de velocidade de ataque.", "dano", {"form_stats": Balance.CT_FORM_HOWL}),
				_o("dru_c_roots", "Raízes Fundas", "Enredar prende por 2 s a mais.", "utilidade", {"skill_mods": {"dru_entangle": {"mult": {"duration": 2.0}}}}),
				_o("dru_c_wolves", "Alcateia", "+1 Lobo Espiritual no máximo.", "invocação", {"summon_extra": {"dru_spirit_wolves": 1}})]],
			[25, [_o("dru_c_prowl", "Caçador Noturno", "Espreitar dura o dobro e o bote saindo dele dá 2,0× de dano.", "dano", {"skill_mods": {"dru_prowl": {"mult": {"duration": 2.0}}}, "ambush_mult": 2.0}),
				_o("dru_c_ent", "Raiz Profunda", "Suas invocações (Ent e lobos) têm +60% de força.", "invocação", {"stats": {"pet_pct": 60}}),
				_o("dru_c_regen", "Sangue Selvagem", "Na forma: regenera 1,5% do HP por segundo.", "sobrevivência", {"regen": {"pct": 1.5, "form": true}})]],
			[30, [_o("dru_c_avatar", "Avatar da Natureza", "+10% de ATK e MATK, +8% de HP e +60 de VIT.", "dano", {"stats": {"atk_pct": 10, "matk_pct": 10, "hp_pct": 8, "attr_VIT": 60}}),
				_o("dru_c_cycle", "Ciclo", "Cada abate cura 4% do HP e devolve 4% do MP.", "sobrevivência", {"on_kill": {"heal_pct": 4, "mp_pct": 4}}),
				_o("dru_c_forest", "Floresta Eterna", "Bênção do Bosque fica sempre ativa em você.", "permanente", {"permanent": ["dru_grove"], "strength": 1.0})]],
			[35, [_b("guardiao_verde", "dru_c_thick_hide", "Couro Grosso", "Pele de Carvalho recarrega 30% mais rápido.", "sobrevivência", {"skill_mods": {"dru_oak_skin": {"mult": {"cooldown": 0.7}}}}),
				_b("fera", "dru_c_leader_hunt", "Caça ao Líder", "Dilacerar +25% de dano e recarrega 20% mais rápido.", "dano", {"skill_mods": {"dru_maim": {"mult": {"power": 1.25, "cooldown": 0.8}}}}),
				_b("xama", "dru_c_mangrove", "Raízes do Mangue", "Ciclone 30% maior e prende por 50% mais tempo.", "utilidade", {"skill_mods": {"dru_cyclone": {"mult": {"radius": 1.3, "duration": 1.5}}}})]],
			[40, [_b("guardiao_verde", "dru_c_living_mountain", "Montanha Viva", "Golpe da Terra e Estouro +25% de dano.", "dano", {"skill_mods": {"dru_earth_slam": {"mult": {"power": 1.25}}, "dru_stampede": {"mult": {"power": 1.25}}}}),
				_b("fera", "dru_c_lone_pack", "Matilha de Um", "Fúria Selvagem +25% de dano e recarrega 20% mais rápido.", "dano", {"skill_mods": {"dru_rampage": {"mult": {"power": 1.25, "cooldown": 0.8}}}}),
				_b("xama", "dru_c_high_moon", "Lua Alta", "Fogo Lunar e Chuva Estelar +20% de dano.", "dano", {"skill_mods": {"dru_moonfire": {"mult": {"power": 1.2}}, "dru_starfall": {"mult": {"power": 1.2}}}})]],
			[45, [_b("guardiao_verde", "dru_c_avalanche", "Avalanche", "Fúria da Montanha +30% de dano e recarrega 20% mais rápido.", "dano", {"skill_mods": {"dru_mountain": {"mult": {"power": 1.3, "cooldown": 0.8}}}}),
				_b("fera", "dru_c_final_fang", "Presa Final", "Golpe Feral +30% de dano e recarrega 20% mais rápido.", "dano", {"skill_mods": {"dru_savage": {"mult": {"power": 1.3, "cooldown": 0.8}}}}),
				_b("xama", "dru_c_storm_eye", "Olho da Tempestade", "Tempestade da Natureza e Crescimento Selvagem +25% de dano.", "dano", {"skill_mods": {"dru_storm": {"mult": {"power": 1.25}}, "dru_wild_growth": {"mult": {"power": 1.25}}}})]],
		],
		"ranger": [
			[5, [_o("ran_c_bond", "Laço de Sangue", "O lince tem +40% de força.", "invocação", {"stats": {"pet_pct": 40}}),
				_o("ran_c_trapper", "Armadilheiro", "Até 5 armadilhas (eram 3), que recarregam 30% mais rápido.", "utilidade",
					{"trap_max": 5, "skill_mods": {"ran_trap": {"mult": {"cooldown": 0.7}}, "ran_mine": {"mult": {"cooldown": 0.7}}, "ran_frost_trap": {"mult": {"cooldown": 0.7}}}}),
				_o("ran_c_eye", "Olho Treinado", "+6% de crítico e +60 de AGI.", "dano", {"stats": {"crit": 6.0, "attr_AGI": 60}})]],
			[10, [_o("ran_c_heavy_anchor", "Âncora Pesada", "Flecha Âncora +20% de dano e prende 1 s a mais.", "utilidade", {"skill_mods": {"ran_anchor": {"mult": {"power": Balance.CT_SKILL_POWER}, "effects": {"root": {"duration": Balance.CT_ANCHOR_ROOT}}}}}),
				_o("ran_c_fan_arrows", "Flechas em Leque", "Tiro Múltiplo e Flecha Explosiva +20% de dano.", "dano", {"skill_mods": {"ran_multishot": {"mult": {"power": Balance.CT_SKILL_POWER}}, "ran_explosive": {"mult": {"power": Balance.CT_SKILL_POWER}}}}),
				_o("ran_c_light_spear", "Lança Leve", "Estocada Dupla e Dardo de Caça +20% de dano.", "dano", {"skill_mods": {"ran_double_thrust": {"mult": {"power": Balance.CT_SKILL_POWER}}, "ran_javelin": {"mult": {"power": Balance.CT_SKILL_POWER}}}})]],
			[15, [_o("ran_c_twin", "Segundo Lince", "Pode ter 2 linces.", "invocação", {"summon_extra": {"ran_companion": 1}}),
				_o("ran_c_pierce", "Alcance Longo", "Tiro Certeiro, Flecha Perfurante e Empalar +20% de dano e alcance.", "dano",
					{"skill_mods": {"ran_snipe": {"mult": {"power": 1.2, "range": 1.2}}, "ran_piercing": {"mult": {"power": 1.2, "range": 1.2}}, "ran_impale": {"mult": {"power": 1.2, "range": 1.2}}}}),
				_o("ran_c_disengage", "Recuo Armado", "Recuar recarrega 40% mais rápido.", "utilidade", {"skill_mods": {"ran_disengage": {"mult": {"cooldown": 0.6}}}})]],
			[20, [_o("ran_c_hunt", "Caçador", "+30% de dano em alvos abaixo de 30% do HP.", "dano", {"execute": {"below": 0.3, "dmg_pct": 30}}),
				_o("ran_c_sic", "Bote Brutal", "Ataque da Fera atordoa 1,5 s.", "utilidade", {"skill_mods": {"ran_sic": {"effects": {"stun": {"duration": 1.5}}}}}),
				_o("ran_c_mines", "Minas Grandes", "Mina Explosiva e Armadilha Lançada 50% maiores e +25% de dano.", "dano", {"skill_mods": {"ran_mine": {"mult": {"radius": 1.5, "power": 1.25}}, "ran_snare_toss": {"mult": {"radius": 1.5, "power": 1.25}}}})]],
			[25, [_o("ran_c_lynx_heal", "Laço Vital", "Aura: você e o lince regeneram 1% do HP por segundo.", "sobrevivência", {"regen": {"pct": 1.0, "aura": true}}),
				_o("ran_c_cdr", "Fôlego", "−15% de recarga em todas as skills.", "utilidade", {"stats": {"cdr": 15}}),
				_o("ran_c_volley", "Chuva de Flechas", "Saraivada e Barragem +25% de dano.", "dano", {"skill_mods": {"ran_volley": {"mult": {"power": 1.25}}, "ran_barrage": {"mult": {"power": 1.25}}}})]],
			[30, [_o("ran_c_chosen_prey", "Presa Escolhida", "Marca do Predador dura 50% a mais e recarrega 20% mais rápido.", "utilidade", {"skill_mods": {"ran_predator": {"mult": {"duration": Balance.CT_PREY_TIME, "cooldown": Balance.CT_PREY_CD}}}}),
				_o("ran_c_ghost", "Tiro Fantasma", "Tiro na Cabeça atravessa: acerta também até 2 inimigos na linha atrás do alvo e +15% de dano.", "dano",
					{"skill_mods": {"ran_headshot": {"set": {"projectile_pierce": true, "max_targets": Balance.GHOST_SHOT_TARGETS}, "mult": {"power": 1.15}}}}),
				_o("ran_c_pack", "Matilha", "Instinto da Matilha fica sempre ativo em você e no lince (60% da força).", "permanente", {"permanent": ["ran_pack"], "strength": 0.6})]],
			[35, [_b("cacador", "ran_c_hunting_net", "Rede de Caça", "Rede 40% maior e recarrega 25% mais rápido.", "utilidade", {"skill_mods": {"ran_net": {"mult": {"radius": 1.4, "cooldown": 0.75}}}}),
				_b("atirador", "ran_c_leader_shot", "Tiro no Líder", "Tiro na Cabeça atordoa 1 s (era 0,5 s) e recarrega 20% mais rápido.", "utilidade", {"skill_mods": {"ran_headshot": {"mult": {"cooldown": 0.8}, "effects": {"stun": {"duration": 1.0}}}}}),
				_b("lanceiro", "ran_c_wide_sweep", "Giro Largo", "Lança Giratória 20% maior e +25% de dano.", "dano", {"skill_mods": {"ran_spear_sweep": {"mult": {"radius": 1.2, "power": 1.25}}}})]],
			[40, [_b("cacador", "ran_c_marked_prey", "Presa Marcada", "Ataque da Fera +20% de dano e recarrega 30% mais rápido.", "dano", {"skill_mods": {"ran_sic": {"mult": {"power": 1.2, "cooldown": 0.7}}}}),
				_b("atirador", "ran_c_quick_reload", "Recarga Rápida", "Tiro Certeiro e Tiro de Dispersão recarregam 25% mais rápido.", "dano", {"skill_mods": {"ran_snipe": {"mult": {"cooldown": 0.75}}, "ran_scatter": {"mult": {"cooldown": 0.75}}}}),
				_b("lanceiro", "ran_c_long_leap", "Salto Certeiro", "Salto do Predador recarrega 30% mais rápido e cai numa área 25% maior.", "utilidade", {"skill_mods": {"ran_spear_leap": {"mult": {"cooldown": 0.7, "radius": 1.25}}}})]],
			[45, [_b("cacador", "ran_c_endless_rain", "Chuva sem Fim", "Chuva de Flechas +30% de dano e recarrega 20% mais rápido.", "dano", {"skill_mods": {"ran_rain": {"mult": {"power": 1.3, "cooldown": 0.8}}}}),
				_b("atirador", "ran_c_steady_eye", "Olho Firme", "Olho de Águia dura 50% a mais e recarrega 15% mais rápido.", "dano", {"skill_mods": {"ran_deadeye": {"mult": {"duration": 1.5, "cooldown": 0.85}}}}),
				_b("lanceiro", "ran_c_long_instinct", "Instinto Duradouro", "Instinto do Predador dura 50% a mais e Empalar +20% de dano.", "dano", {"skill_mods": {"ran_blood_instinct": {"mult": {"duration": 1.5}}, "ran_impale": {"mult": {"power": 1.2}}}})]],
		],
		"assassin": [
			[5, [_o("ass_c_venom", "Lâmina Envenenada", "Lâmina Pestilenta fica sempre ativa em você (veneno em todo golpe).", "permanente", {"permanent": ["ass_plague_blade"], "strength": 0.8}),
				_o("ass_c_pistol_open", "Tiro de Abertura", "Tiro de Pistola +25% de dano e recarrega 20% mais rápido.", "dano", {"skill_mods": {"ass_pistol_shot": {"mult": {"power": Balance.CT_OPENER_POWER, "cooldown": Balance.CT_OPENER_CD}}}}),
				_o("ass_c_ambush", "Emboscada", "O golpe saindo da furtividade dá 2,0× de dano (era 1,6×).", "dano", {"ambush_mult": 2.0})]],
			[10, [_o("ass_c_vanish", "Sombra Rápida", "Sumir recarrega 40% mais rápido e dura 50% a mais.", "utilidade", {"skill_mods": {"ass_vanish": {"mult": {"cooldown": 0.6, "duration": 1.5}}}}),
				_o("ass_c_x_cut", "Corte em X", "Corte Cruzado +20% de dano e faz sangrar (12% do ATK por segundo, 4 s).", "dano", {"skill_mods": {"ass_cross_slash": {"mult": {"power": Balance.CT_SKILL_POWER}, "effects": {"dot": Balance.CT_DOTS["ass_cross_slash"]}}}}),
				_o("ass_c_evade", "Bailarino", "+6% de esquiva e +60 de AGI.", "sobrevivência", {"stats": {"evasion": 6.0, "attr_AGI": 60}})]],
			[15, [_o("ass_c_guard", "Duelista", "Guarda do Duelista fica sempre ativa em você (50% da força).", "permanente", {"permanent": ["ass_guard"], "strength": 0.5}),
				_o("ass_c_backstab", "Pelas Costas", "+20% de dano pelas costas.", "dano", {"stats": {"backstab": 20}}),
				_o("ass_c_toxin", "Toxina Forte", "Dardo Venenoso, Nuvem Tóxica e Abrolhos +30% de dano.", "dano", {"skill_mods": {"ass_venom_dart": {"mult": {"power": 1.3}}, "ass_toxic_cloud": {"mult": {"power": 1.3}}, "ass_caltrops": {"mult": {"power": 1.3}}}})]],
			[20, [_o("ass_c_shadow", "Sombra", "Cada abate: some por 2 s (furtividade).", "utilidade", {"on_kill": {"stealth": 2.0}}),
				_o("ass_c_dance", "Dança de Lâminas", "+10% de velocidade de ataque.", "dano", {"stats": {"aspd_pct": 10}}),
				_o("ass_c_crit", "Olho Frio", "+6% de crítico.", "dano", {"stats": {"crit": 6.0}})]],
			[25, [_o("ass_c_escape", "Fuga", "Sumir cura 15% do HP.", "sobrevivência", {"skill_mods": {"ass_vanish": {"effects": {"heal_pct": 15}}}}),
				_o("ass_c_eviscerate", "Golpe Final", "Eviscerar, Golpe de Mestre e Tiro Entre os Olhos +25% de dano.", "dano", {"skill_mods": {"ass_eviscerate": {"mult": {"power": 1.25}}, "ass_master": {"mult": {"power": 1.25}}, "ass_between_eyes": {"mult": {"power": 1.25}}}}),
				_o("ass_c_leech", "Lâmina Sedenta", "+4% de roubo de vida.", "sobrevivência", {"stats": {"lifesteal": 4}})]],
			[30, [_o("ass_c_death", "Morte Certa", "+50% de dano em alvos abaixo de 25% do HP.", "dano", {"execute": {"below": 0.25, "dmg_pct": 50}}),
				_o("ass_c_phantom", "Fantasma", "Golpe fatal: fica com 1 HP, imortal e invisível por 4 s (uma vez a cada 90 s).", "sobrevivência", {"cheat_death": {"cd": 90.0, "dur": 4.0, "stealth": true}}),
				_o("ass_c_thousand", "Mil Cortes", "Mil Cortes e Rajada de Lâminas +30% de dano.", "dano", {"skill_mods": {"ass_thousand": {"mult": {"power": 1.3}}, "ass_blade_flurry": {"mult": {"power": 1.3}}}})]],
			[35, [_b("laminas", "ass_c_epidemic", "Epidemia", "Virulência 20% maior e recarrega 30% mais rápido.", "dano", {"skill_mods": {"ass_virulence": {"mult": {"radius": 1.2, "cooldown": 0.7}}}}),
				_b("duelista", "ass_c_counter_ambush", "Contra-Emboscada", "Guarda do Duelista dura 50% a mais e recarrega 30% mais rápido.", "sobrevivência", {"skill_mods": {"ass_guard": {"mult": {"duration": 1.5, "cooldown": 0.7}}}}),
				_b("corsario", "ass_c_boarding", "Abordagem", "Gancho de Abordagem +25% de dano e recarrega 30% mais rápido.", "utilidade", {"skill_mods": {"ass_grapple": {"mult": {"power": 1.25, "cooldown": 0.7}}}})]],
			[40, [_b("laminas", "ass_c_shadow_dance", "Dança Sombria", "Dança da Morte +25% de dano e recarrega 20% mais rápido.", "dano", {"skill_mods": {"ass_dance": {"mult": {"power": 1.25, "cooldown": 0.8}}}}),
				_b("duelista", "ass_c_sharp_riposte", "Resposta Afiada", "Lâmina Carmesim +25% de dano e cura 40% do dano causado (eram 25%).", "sobrevivência", {"skill_mods": {"ass_crimson": {"mult": {"power": 1.25}, "effects": {"heal_pct_of_dmg": 0.4}}}}),
				_b("corsario", "ass_c_double_powder", "Pólvora Dobrada", "Bordada +25% de dano e leque 20% mais longo.", "dano", {"skill_mods": {"ass_broadside": {"mult": {"power": 1.25, "radius": 1.2}}}})]],
			[45, [_b("laminas", "ass_c_tireless", "Lâminas Incansáveis", "Golpe Gêmeo e Leque de Facas +25% de dano.", "dano", {"skill_mods": {"ass_twin_strike": {"mult": {"power": 1.25}}, "ass_fan": {"mult": {"power": 1.25}}}}),
				_b("duelista", "ass_c_weapon_master", "Mestre de Armas", "Avanço do Duelista e Turbilhão de Aço +25% de dano.", "dano", {"skill_mods": {"ass_lunge": {"mult": {"power": 1.25}}, "ass_steel_whirl": {"mult": {"power": 1.25}}}}),
				_b("corsario", "ass_c_flag", "Bandeira no Mastro", "Bandeira Negra dura 50% a mais e recarrega 15% mais rápido.", "utilidade", {"skill_mods": {"ass_black_flag": {"mult": {"duration": 1.5, "cooldown": 0.85}}}})]],
		],
		"elementalist": [
			[5, [_o("ele_c_blazing_ball", "Bola Ardente", "Bola de Fogo +20% de dano e queima 2 s a mais.", "dano", {"skill_mods": {"ele_fireball": {"mult": {"power": Balance.CT_SKILL_POWER}, "effects": {"dot": Balance.CT_DOTS["ele_fireball"]}}}}),
				_o("ele_c_live_spark", "Faísca Viva", "Faísca +25% de dano e atravessa (até 3 inimigos).", "dano", {"skill_mods": {"ele_spark": {"set": {"max_targets": Balance.CT_SPARK_TARGETS}, "mult": {"power": Balance.CT_OPENER_POWER}}}}),
				_o("ele_c_cold_lance", "Lança Fria", "Lança de Gelo atravessa inimigos e +15% de dano.", "dano", {"skill_mods": {"ele_ice_lance": {"set": {"projectile_pierce": true}, "mult": {"power": Balance.CT_PIERCE_POWER}}}})]],
			[10, [_o("ele_c_fire", "Coração de Fogo", "+10% de dano de fogo.", "dano", {"stats": {"fire_pct": 10}}),
				_o("ele_c_frost", "Coração de Gelo", "+10% de dano de gelo.", "dano", {"stats": {"frost_pct": 10}}),
				_o("ele_c_storm", "Coração de Raio", "+10% de dano de raio.", "dano", {"stats": {"storm_pct": 10}})]],
			[15, [_o("ele_c_bound", "Elemental Vinculado", "O elemental fica para sempre (invocar outro troca de elemento).", "invocação",
					{"summon_permanent": ["ele_summon_fire", "ele_summon_ice", "ele_summon_storm"]}),
				_o("ele_c_combo", "Fusão", "Combos (Brasas, Choque Térmico, Granizo, Prisma) +25% de dano.", "dano",
					{"skill_mods": {"ele_firestorm": {"mult": {"power": 1.25}}, "ele_frost_flare": {"mult": {"power": 1.25}}, "ele_hailstorm": {"mult": {"power": 1.25}}, "ele_prism": {"mult": {"power": 1.25}}}}),
				_o("ele_c_blink", "Piscar Rápido", "Piscar recarrega 40% mais rápido.", "utilidade", {"skill_mods": {"ele_blink": {"mult": {"cooldown": 0.6}}}})]],
			[20, [_o("ele_c_shatter", "Estilhaço", "Estilhaçar e Lança de Gelo +30% de dano.", "dano", {"skill_mods": {"ele_shatter": {"mult": {"power": 1.3}}, "ele_ice_lance": {"mult": {"power": 1.3}}}}),
				_o("ele_c_burn", "Brasa Viva", "Combustão 30% maior e +20% de dano.", "dano", {"skill_mods": {"ele_combustion": {"mult": {"radius": Balance.CT_AREA_MULT, "power": Balance.CT_SKILL_POWER}}}}),
				_o("ele_c_chain", "Corrente Longa", "Corrente Elétrica acerta 2 alvos a mais.", "dano", {"skill_mods": {"ele_chain": {"set": {"max_targets": 6}}}})]],
			[25, [_o("ele_c_mana", "Fonte de Mana", "Cada abate devolve 5% do MP.", "utilidade", {"on_kill": {"mp_pct": 5}}),
				_o("ele_c_shield", "Escudo de Mana", "20% do dano recebido sai do MP.", "sobrevivência", {"mana_shield": {"pct": 20}}),
				_o("ele_c_mind", "Mente Arcana", "+15% de MP, +80 de INT.", "utilidade", {"stats": {"mp_pct": 15, "attr_INT": 80}})]],
			[30, [_o("ele_c_archmage", "Arquimago", "−20% de recarga em todas as skills.", "utilidade", {"stats": {"cdr": 20}}),
				_o("ele_c_avatar", "Avatar Elemental", "+15% de MATK e +6% de crítico.", "dano", {"stats": {"matk_pct": 15, "crit": 6.0}}),
				_o("ele_c_cataclysm", "Cataclismo", "Meteoro, Inferno e Zero Absoluto recarregam 40% mais rápido.", "dano",
					{"skill_mods": {"ele_meteor": {"mult": {"cooldown": 0.6}}, "ele_inferno": {"mult": {"cooldown": 0.6}}, "ele_absolute_zero": {"mult": {"cooldown": 0.6}}}})]],
			[35, [_b("fogo", "ele_c_scorched", "Terra Queimada", "Muralha de Fogo 30% mais longa e fica acesa e queima 40% mais tempo.", "dano", {"skill_mods": {"ele_fire_wall": {"mult": {"radius": 1.3, "duration": 1.4}}}}),
				_b("gelo", "ele_c_deep_ice", "Gelo Fundo", "Geleira 30% maior e prende por 50% mais tempo.", "utilidade", {"skill_mods": {"ele_glacier": {"mult": {"radius": 1.3, "duration": 1.5}}}}),
				_b("raio", "ele_c_rod", "Para-Raios", "Campo Estático 30% maior e +20% de dano.", "dano", {"skill_mods": {"ele_static": {"mult": {"radius": 1.3, "power": 1.2}}}})]],
			[40, [_b("fogo", "ele_c_furnace", "Fornalha", "Onda de Chamas e Inferno +25% de dano.", "dano", {"skill_mods": {"ele_flame_wave": {"mult": {"power": 1.25}}, "ele_inferno": {"mult": {"power": 1.25}}}}),
				_b("gelo", "ele_c_hoarfrost", "Geada Funda", "Nova de Gelo e Nevasca +25% de dano.", "dano", {"skill_mods": {"ele_frost_nova": {"mult": {"power": 1.25}}, "ele_blizzard": {"mult": {"power": 1.25}}}}),
				_b("raio", "ele_c_voltage", "Alta Tensão", "Relâmpago e Trovão +25% de dano.", "dano", {"skill_mods": {"ele_lightning": {"mult": {"power": 1.25}}, "ele_thunder": {"mult": {"power": 1.25}}}})]],
			[45, [_b("fogo", "ele_c_reborn", "Fênix Renascida", "Fênix +30% de dano e recarrega 20% mais rápido.", "dano", {"skill_mods": {"ele_phoenix": {"mult": {"power": 1.3, "cooldown": 0.8}}}}),
				_b("gelo", "ele_c_ice_age", "Era do Gelo", "Zero Absoluto +30% de dano e 20% maior.", "dano", {"skill_mods": {"ele_absolute_zero": {"mult": {"power": 1.3, "radius": 1.2}}}}),
				_b("raio", "ele_c_hurricane", "Olho do Furacão", "Senhor da Tempestade +30% de dano e recarrega 20% mais rápido.", "dano", {"skill_mods": {"ele_storm_lord": {"mult": {"power": 1.3, "cooldown": 0.8}}}})]],
		],
		"necromancer": [
			[5, [_o("nec_c_army", "Exército Eterno", "Os esqueletos do Erguer Mortos ficam para sempre.", "invocação", {"summon_permanent": ["nec_raise"]}),
				_o("nec_c_slow_dead", "Mortos sem Pressa", "Mortos-vivos com tempo (cães, lich, rei, exército) duram o dobro.", "invocação", {"summon_time": Balance.NEC_TALENT_SUMMON_TIME}),
				_o("nec_c_slow_rot", "Podridão Lenta", "Seus danos no tempo (Podridão, Praga, Enxame, Agonia...) duram 25% a mais e causam 15% a mais por segundo.", "dano",
					{"dot_boost": {"time": Balance.NEC_TALENT_DOT_TIME, "dps": Balance.NEC_TALENT_DOT_DPS}})]],
			[10, [_o("nec_c_more", "Legião", "+1 esqueleto no máximo do Erguer Mortos.", "invocação", {"summon_extra": {"nec_raise": 1}}),
				_o("nec_c_curses", "Maldições Amplas", "Maldições 40% maiores.", "utilidade",
					{"skill_mods": {"nec_curse_weakness": {"mult": {"radius": 1.4}}, "nec_curse_doom": {"mult": {"radius": 1.4}}, "nec_curse_agony": {"mult": {"radius": 1.4}}}}),
				_o("nec_c_death_blade", "Lâmina da Morte", "Ceifar +20% de dano.", "dano", {"skill_mods": {"nec_reap": {"mult": {"power": Balance.CT_SKILL_POWER}}}})]],
			[15, [_o("nec_c_thirsty_scythe", "Foice Sedenta", "Ceifar e Giro da Morte curam o dobro (30% e 20% do dano).", "sobrevivência", {"skill_mods": {"nec_reap": {"effects": {"heal_pct_of_dmg": Balance.CT_SCYTHE_HEAL["nec_reap"]}}, "nec_death_spin": {"effects": {"heal_pct_of_dmg": Balance.CT_SCYTHE_HEAL["nec_death_spin"]}}}}),
				_o("nec_c_lich", "Lich Eterno", "O Lich fica para sempre.", "invocação", {"summon_permanent": ["nec_lich"]}),
				_o("nec_c_drain", "Sede de Almas", "Sugar Alma +30% de dano e cura.", "sobrevivência", {"skill_mods": {"nec_drain_soul": {"mult": {"power": 1.3}}}})]],
			[20, [_o("nec_c_spreading_curse", "Maldição Contagiosa", "Condenação e Maldição da Fraqueza 30% mais fortes e duram 2 s a mais.", "utilidade", {"skill_mods": {"nec_curse_doom": {"effects": {"curse": Balance.CT_CURSES["nec_curse_doom"]}}, "nec_curse_weakness": {"effects": {"curse": Balance.CT_CURSES["nec_curse_weakness"]}}}}),
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
			[35, [_b("invocador", "nec_c_kennel", "Canil dos Mortos", "+1 Cão de Ossos no máximo.", "invocação", {"summon_extra": {"nec_bone_hound": 1}}),
				_b("ceifador", "nec_c_wide_reap", "Ceifa Larga", "Ceifar e Colheita Sombria 25% maiores.", "dano", {"skill_mods": {"nec_reap": {"mult": {"radius": 1.25}}, "nec_harvest": {"mult": {"radius": 1.25}}}}),
				_b("pestilento", "nec_c_deep_rot", "Podridão Funda", "Praga e Decadência +30% de dano.", "dano", {"skill_mods": {"nec_plague": {"mult": {"power": 1.3}}, "nec_decay": {"mult": {"power": 1.3}}}})]],
			[40, [_b("invocador", "nec_c_quick_call", "Chamado Rápido", "Exército dos Mortos recarrega 30% mais rápido.", "invocação", {"skill_mods": {"nec_army": {"mult": {"cooldown": 0.7}}}}),
				_b("ceifador", "nec_c_hungry_scythe", "Foice Faminta", "Rasgar Alma +25% de dano e recarrega 20% mais rápido.", "dano", {"skill_mods": {"nec_soul_rend": {"mult": {"power": 1.25, "cooldown": 0.8}}}}),
				_b("pestilento", "nec_c_wide_shadows", "Sombras Largas", "Enxame de Moscas e Pandemia 30% maiores.", "utilidade", {"skill_mods": {"nec_swarm": {"mult": {"radius": 1.3}}, "nec_pandemic": {"mult": {"radius": 1.3}}}})]],
			[45, [_b("invocador", "nec_c_court", "Corte dos Mortos", "Erguer Lich e Rei Esqueleto recarregam 30% mais rápido.", "invocação", {"skill_mods": {"nec_lich": {"mult": {"cooldown": 0.7}}, "nec_skeleton_king": {"mult": {"cooldown": 0.7}}}}),
				_b("ceifador", "nec_c_supreme", "Ceifeiro Supremo", "Ceifeiro Sinistro +30% de dano e recarrega 20% mais rápido.", "dano", {"skill_mods": {"nec_grim": {"mult": {"power": 1.3, "cooldown": 0.8}}}}),
				_b("pestilento", "nec_c_hungry_void", "Vazio Faminto", "Açoite Mental e Raio do Vazio +30% de dano.", "dano", {"skill_mods": {"nec_mind_flay": {"mult": {"power": 1.3}}, "nec_void_beam": {"mult": {"power": 1.3}}}})]],
		],
	}
