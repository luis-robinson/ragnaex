class_name WeaponArcs
extends Node3D
## Arco de golpe por família de arma (auditoria 2026-11-14, opção B; piloto: espada de 1 mão).
## Onda 1 (2026-11-15): maça (como a espada) e espada/maça de duas mãos (básico atk_2h = crescente EM PÉ).
## No tick do dano do golpe em cone: um crescente grosso no estilo toon do tamanho do cone REAL da sim (raio e
## abertura da SkillDef), inclinado para a câmera de 52°, cabeça clara no lado para onde a lâmina foi (A/B espelhados
## pelo clipe), cauda que some em ~0,15 s. No alvo: faíscas jogadas na tangente do golpe, estrela de impacto e um
## empurrãozinho só de desenho. Hit-stop LOCAL: congela só a animação de quem bate e de quem apanha (o resto do mundo
## segue), em vez do Engine.time_scale global.
## Só apresentação: lê a sim, nunca muda tempo nem dano. Números aqui são de aparência (o hit-stop usa os quadros
## que a sim manda, Balance.HIT_STOP_FRAMES_BASIC / SkillDef.hit_stop_frames).

## Família -> aparência. Família nova entra aqui (sem linha = rastro antigo, hit-stop global de sempre).
##  angle_pad: graus a mais que o cone (a lâmina passa um pouco das bordas) · inner: raio de dentro da malha (fração)
##  tilt: graus que o plano do arco deita para a câmera · height: altura do arco (m) · life: s de vida
##  stop_mult: × os quadros de hit-stop da sim · push: m do empurrão de desenho no alvo · glow: força do miolo
##  band: cor da faixa quando o tema da skill é físico (tema mágico usa a cor do tema)
##  Arco em pé (forma S, golpe de cima para baixo; só famílias que têm estas chaves):
##  s_pivot: altura (m) do centro do arco (ombro) · s_up: raio vertical (m) · s_reach: raio à frente = raio do cone × isto
##  s_tail: graus acima da horizontal onde a cauda começa (>90 = atrás da cabeça) · s_roll: teto (graus) do giro do
##  plano no eixo do golpe para a câmera · mark_deg: abertura do risco no chão onde a cabeça bate
##  rim: contorno (opcional; sem a chave = band.darkened(0.82)); família INVERTIDA (faixa escura) traz o contorno claro
##  on: false = só a cor está decidida, a família ainda não tem arco (fica no rastro antigo até a onda dela)
## Cores: production/qa/attack-arc-colours.md (art-director, aprovado pelo usuário 2026-11-15): faixas em "espaço de metal"
## (pouca saturação, valor claro), longe dos matizes de tema/perigo; a família se reconhece pela forma e espessura.
const FAMILIES := {
	"sword": {"angle_pad": 16.0, "inner": 0.30, "tilt": 14.0, "height": 0.62, "life": 0.16, "stop_mult": 1.0,
		"push": 0.13, "glow": 1.25, "band": Color(0.74, 0.83, 0.95)},     # #BDD4F2 aço frio
	# maça de 1 mão: os mesmos clipes e lados da espada (tabela de golpes), aço quente, parada um pouco mais pesada
	"mace": {"angle_pad": 14.0, "inner": 0.26, "tilt": 14.0, "height": 0.60, "life": 0.16, "stop_mult": 1.25,
		"push": 0.17, "glow": 1.25, "band": Color(0.82, 0.80, 0.77),     # #D1CCC4 estanho quente
		"s_pivot": 0.90, "s_up": 1.15, "s_reach": 0.80, "s_tail": 95.0, "s_roll": 40.0, "mark_deg": 40.0},     # atk_claw de maça é de cima
	# duas mãos: básico atk_2h de cima para baixo (forma S), faixa mais grossa, parada dupla
	"sword2h": {"angle_pad": 12.0, "inner": 0.22, "tilt": 14.0, "height": 0.66, "life": 0.18, "stop_mult": 2.0,
		"push": 0.22, "glow": 1.35, "band": Color(0.84, 0.89, 0.96),     # #D6E3F5 aço polido
		"s_pivot": 0.95, "s_up": 1.35, "s_reach": 0.75, "s_tail": 95.0, "s_roll": 40.0, "mark_deg": 44.0},
	"mace2h": {"angle_pad": 12.0, "inner": 0.20, "tilt": 14.0, "height": 0.66, "life": 0.18, "stop_mult": 2.0,
		"push": 0.25, "glow": 1.35, "band": Color(0.85, 0.83, 0.80),     # #D9D4CC estanho claro
		"s_pivot": 0.95, "s_up": 1.35, "s_reach": 0.75, "s_tail": 95.0, "s_roll": 40.0, "mark_deg": 52.0},
	# lança (onda 3): estocada = cunha W ao longo do alcance; inner = onde a cunha começa (fração do raio)
	"spear": {"angle_pad": 0.0, "inner": 0.16, "tilt": 14.0, "height": 0.95, "life": 0.14, "stop_mult": 1.0,
		"push": 0.18, "glow": 1.25, "band": Color(0.90, 0.92, 0.95),     # #E6EBF2 aço de cinza claro
		"w_width": 0.34, "w_lean": 6.0},
	# só a cor (garras na onda das duas armas): ferro rosado
	# machados (onda 2, modelos refeitos): ferro negro INVERTIDO (faixa escura, contorno claro #E0E6F0, miolo forte)
	"axe": {"angle_pad": 14.0, "inner": 0.26, "tilt": 14.0, "height": 0.60, "life": 0.16, "stop_mult": 1.5,
		"push": 0.18, "glow": 1.5, "band": Color(0.27, 0.25, 0.24), "rim": Color(0.88, 0.90, 0.94)},      # #453F3D / #E0E6F0
	# machado de 2 mãos (e o par da Empunhadura de Titã): talho largo (atk_sweep), faixa grossa, parada dupla;
	# atk_claw é de cima (forma S)
	"axe2h": {"angle_pad": 12.0, "inner": 0.20, "tilt": 14.0, "height": 0.70, "life": 0.18, "stop_mult": 2.0,
		"push": 0.26, "glow": 1.5, "band": Color(0.27, 0.25, 0.24), "rim": Color(0.88, 0.90, 0.94),
		"s_pivot": 0.95, "s_up": 1.35, "s_reach": 0.75, "s_tail": 95.0, "s_roll": 40.0, "mark_deg": 52.0},
	# onda 4 (duas armas): garras ferro rosado, adagas brilho; a linha vale para a arma sozinha e dá a cor da lasca dela
	"claw": {"angle_pad": 10.0, "inner": 0.45, "tilt": 16.0, "height": 0.75, "life": 0.13, "stop_mult": 0.75,
		"push": 0.12, "glow": 1.3, "band": Color(0.86, 0.79, 0.81)},                                      # #DBC9CF
	# foice (onda 5; raro: as builds do Necromante batem com magia, aí vale a cor do tema): aço preto-azulado INVERTIDO
	"scythe": {"angle_pad": 12.0, "inner": 0.24, "tilt": 14.0, "height": 0.70, "life": 0.16, "stop_mult": 1.5,
		"push": 0.18, "glow": 1.5, "band": Color(0.23, 0.25, 0.31), "rim": Color(0.88, 0.90, 0.94)},      # #3A4150 / #E0E6F0
	"dagger": {"angle_pad": 10.0, "inner": 0.45, "tilt": 16.0, "height": 0.75, "life": 0.13, "stop_mult": 0.5,
		"push": 0.10, "glow": 1.3, "band": Color(0.93, 0.95, 1.0)},                                       # #EDF2FF
	# onda 6, formas de bicho do Druida: riscos de garra NO CHÃO (forma K), nunca crescente; a cor é sempre a da forma
	# (decisão do usuário 2026-11-15: vermelho no chão = perigo de chefe). Lobo Alfa usa a linha do lobo (mesmo corpo e clipes).
	#  k_len: comprimento do risco (m, antes do FORM_SCALE) · k_gap: espaço entre riscos · k_width: meia-largura na cabeça
	#  k_y: altura sobre o chão · alpha: opacidade (teto MARK_ALPHA) · life: s (teto MARK_LIFE_MAX)
	"form_wolf": {"life": 0.18, "stop_mult": 1.0, "push": 0.12, "glow": 1.0, "alpha": 0.6, "band": Color(0.81, 0.82, 0.84),   # #CFD1D6
		"k_len": 0.75, "k_gap": 0.09, "k_width": 0.035, "k_y": 0.05},
	"form_bear": {"life": 0.18, "stop_mult": 1.5, "push": 0.22, "glow": 1.0, "alpha": 0.6, "band": Color(0.82, 0.80, 0.77),   # #D1CCC4
		"k_len": 0.95, "k_gap": 0.13, "k_width": 0.05, "k_y": 0.05},
	# Ent (ascensão do Guardião Verde, 2,8 m em pé): Golpe de Galho = crescente EM PÉ como as armas (S); pisão das raízes = K.
	# Faixa casca/musgo neutra, pouca saturação (revisão de arte 2026-11-16: mais clara, lê na areia e no basalto)
	"form_ent": {"life": 0.18, "stop_mult": 1.5, "push": 0.22, "glow": 1.0, "alpha": 0.6, "band": Color(0.831, 0.847, 0.800),   # #D4D8CC
		"inner": 0.22, "s_pivot": 1.1, "s_up": 2.0, "s_reach": 0.58, "s_tail": 95.0, "s_roll": 40.0, "mark_deg": 40.0,
		"k_len": 0.95, "k_gap": 0.16, "k_width": 0.06, "k_y": 0.05},
}
## Forma K (garras no chão): medidas obrigatórias da linha
const K_KEYS := ["k_len", "k_gap", "k_width", "k_y", "alpha"]
## Forma (SimEntity.form) -> família de arco. Forma fora daqui (fantasma, demônio, lich, pássaro) fica sem arco.
const FORM_FAMILY := {"wolf": "form_wolf", "bear": "form_bear", "alpha": "form_wolf", "ent": "form_ent"}
## "clipe|forma" que desenha o crescente EM PÉ (S) em vez de marcas: o galhão do Ent cai 2,3 m na frente (quadro 7),
## golpe de arma, não garra (medido: production/qa/attack-arcs-wave6-ancestral.json)
const FORM_STANDING := {"maul|ent": true}
## "clipe do bicho|forma" -> marcas. Marca = [tipo, x, z, quadro(, alfa)]: x/z = contato medido no modelo (m, antes do
## FORM_SCALE; +X do modelo), quadro 0 = no tick do dano, > 0 = gancho da EntityView nesse quadro do clipe (a sim tem um
## golpe só). Tipos: rake (riscos para a frente, cabeça no contato), skid (rake x0,6, pouso do bote), stomp (rake x0,7
## aberto ±20° para fora, pisão), bite (V do focinho, só lobo). Medido nos GLBs refeitos (wt/post-int; spec da onda 6
## seção 2). Lobo Alfa = as linhas do lobo (mesmo corpo/clipes, x1,4; conferir de novo no GLB refeito). Ent: só o pisão
## (os dois punhos no chão à frente, quadro 8); o ataque e a marcha não tocam o chão (sem marca); o galho é FORM_STANDING.
const FORM_ARC := {
	"attack|wolf": [["bite", 0.0, 1.20, 0]],
	"attack|alpha": [["bite", 0.0, 1.20, 0]],
	"attack|bear": [["rake", 0.31, 0.30, 0]],
	"maul|wolf": [["rake", 0.09, 0.23, 0], ["bite", -0.10, 0.98, 0], ["rake", -0.14, 0.34, 10]],
	"maul|alpha": [["rake", 0.09, 0.23, 0], ["bite", -0.10, 0.98, 0], ["rake", -0.14, 0.34, 10]],
	"maul|bear": [["rake", 0.16, 0.33, 0], ["rake", -0.23, 0.26, 11]],
	"maul|ent": [["rake", -1.08, 1.19, 0, 0.8]],            # gancho do braço -X arrastando no chão (refeito, rodada 6); o galho +X é FORM_STANDING
	"pounce|wolf": [["skid", 0.19, 0.65, 0], ["skid", -0.19, 0.65, 0]],
	"pounce|alpha": [["skid", 0.19, 0.65, 0], ["skid", -0.19, 0.65, 0]],
	"pounce|bear": [["skid", 0.28, 0.66, 0], ["skid", -0.28, 0.66, 0]],
	"slam|wolf": [["stomp", 0.15, 0.32, 0], ["stomp", -0.15, 0.32, 0]],
	"slam|alpha": [["stomp", 0.15, 0.32, 0], ["stomp", -0.15, 0.32, 0]],
	"slam|bear": [["stomp", 0.23, 0.29, 0], ["stomp", -0.23, 0.29, 0]],
	"slam|ent": [["stomp", 0.94, 1.31, 0], ["stomp", -0.94, 1.31, 0]],      # os galhos batem à frente
}
## Comprimento e giro por tipo de marca: [× k_len, graus para fora]
const K_KIND := {"rake": [1.0, 0.0], "skid": [0.6, 0.0], "stomp": [0.7, 20.0], "bite": [1.0, 0.0]}
const K_STREAKS := 3                 # riscos por pata (D3: 4 se não ler na areia)
const K_BITE_ARM := 0.35             # m de cada braço do V da mordida, a ±K_BITE_DEG
const K_BITE_DEG := 30.0
const K_POOL := 8                    # nós da forma K (pool próprio: não toma o lugar dos arcos)
const K_SEGS := 6                    # divisões ao longo de cada risco
## Golpe em CONE na forma (decisão do usuário 2026-11-15): as garras saem além do alvo (no pé do bicho ficavam embaixo da
## cabeça e do alvo): a cabeça da marca vai para K_CONE_PAST × raio do cone (o que estiver mais perto sobe até lá)
const K_CONE_PAST := 0.85
## Formas cujo golpe em volta de si fica só nas marcas de pisão, sem o aro/disco do golpe (decisão do usuário 2026-11-16:
## o pisão do Ent lia como aviso de chefe; 2026-11-16 também urso, lobo e Alfa, que usa as linhas do lobo)
const QUIET_FORMS := ["ent", "bear", "wolf", "alpha"]
const COLOUR_KEYS := ["band", "glow"]   # o mínimo de uma linha "on": false
const S_KEYS := ["s_pivot", "s_up", "s_reach", "s_tail", "s_roll", "mark_deg"]
## Medidas padrão do arco em pé / cunha / aro para a família que não traz as dela (onda 5: golpes de skill de todas as famílias)
const S_DEFAULT := {"s_pivot": 0.95, "s_up": 1.25, "s_reach": 0.8, "s_tail": 95.0, "s_roll": 40.0, "mark_deg": 40.0}
const W_DEFAULT := {"w_width": 0.26, "w_lean": 6.0}
## Aro do giro (forma R, atk_spin): raio = SkillDef.radius; r_inner = faixa (fração), r_height (m), r_tilt (graus para a câmera)
const R_DEFAULT := {"r_inner": 0.74, "r_height": 0.55, "r_tilt": 10.0}
## Famílias com arco que não são ItemDef.MELEE_TYPES (a foice é arma de magia no jogo; o tipo não muda por causa do arco)
const EXTRA_FAMILIES := ["scythe", "form_wolf", "form_bear", "form_ent"]
## Corte e Tiro (atk_slash_shot): o IMPACT 9 é o tiro; o corte do sabre passa no quadro 5 (medido: mão de 4 para 5, +X,
## para baixo) -> a EntityView chama slash_hook nesse quadro do clipe
const SLASH_FRAME := 5
const SLASH_REACH := 1.9
## Cunha (forma W, estocada): w_width = meia-largura máxima (m) · w_lean = graus que a cunha deita para o lado do golpe
## (a ponta da lança corre um pouco para a esquerda do boneco na tabela de golpes)
const W_KEYS := ["w_width", "w_lean"]
## "clipe|família" (ou "clipe|*" = qualquer família) -> [lado, forma]. Lado: para onde a lâmina corre no impacto
## (+1 = +X do modelo, a esquerda do boneco; -1 = direita; 0 = de cima para baixo, sem lado). Forma: "F" crescente
## deitado (piloto), "S" crescente em pé, "W" cunha de estocada. Tirado da tabela de golpes medida nos kits
## (production/qa/evidence/attack-arcs/swing_table.json; tipo O = S com lado 0; há check que relê a tabela).
## 3º número opcional: progresso com que o arco nasce (o golpe passou do pico antes do tick do dano).
## Sem linha: crescente deitado com o lado pelo combo. finisher/flurry/leap/spin/thrust ficam para a onda 5.
const CLIP_ARC := {
	"atk_1h_a|*": [1.0, "F"], "atk_1h_b|*": [-1.0, "F"], "atk_sweep|*": [1.0, "F"],
	"atk_2h|*": [0.0, "S"],
	"atk_claw|sword": [1.0, "F"], "atk_claw|sword2h": [1.0, "F"], "atk_claw|mace2h": [1.0, "F"],
	"atk_claw|mace": [0.0, "S"],      # com a maça o atk_claw é de cima (com a espada é de lado)
	"atk_thrust|spear": [1.0, "W"],
	# machados (tabela medida nos kits antigos; a refação mudou a lâmina, não os clipes): o talho do machado de 2 mãos
	# tem o pico no quadro 4 e o impacto no 8 -> o arco já nasce andado (3º número = progresso inicial)
	"atk_sweep|axe2h": [1.0, "F", 0.25],
	"atk_claw|axe": [1.0, "F"], "atk_claw|axe2h": [0.0, "S"],
	# onda 5, golpes de skill de toda família (tabela): giro = aro no sentido horário; salto/execução/rajada = de cima;
	# estocada = cunha (+X). Exceções medidas: o salto com arma de 2 mãos é de lado; a execução da garra é de lado
	"atk_spin|*": [-1.0, "R"],
	"atk_leap|*": [0.0, "S"], "atk_finisher|*": [0.0, "S"], "atk_flurry|*": [0.0, "S"],
	"atk_thrust|*": [1.0, "W"],
	"atk_leap|sword2h": [1.0, "F"], "atk_leap|mace2h": [1.0, "F"], "atk_finisher|claw": [1.0, "F"],
	"atk_slash_shot|*": [1.0, "F"],   # estocada: diagonal com a ponta indo para +X (tabela: dx +1,02 m), cunha
}
## Faixa de tema mágico: a cor do tema puxada para o branco (THEME_WHITE). Sangue mais claro só nos arcos
## (decisão do usuário 2026-11-15, doc de cores 6.6): o vermelho cheio é do aviso de dano (FxManager.DANGER*).
const THEME_WHITE := 0.15
const THEME_WHITE_BY := {"blood": 0.35}
## Duas armas (onda 4): uma lasca curta por mão (ou a estocada da mão de trás), cada uma na cor da família dela.
##  sliver_deg: abertura da lasca · reach: × raio do cone · inner: faixa fina · height/off_height: alturas (não brigam)
##  turn: graus que cada lasca gira para o lado da mão · tilt/life: como nas famílias · off_alpha: mão de trás mais fraca
##  peak_off: o golpe de duas armas tem o pico no quadro 3 e o impacto no 5 -> as lascas nascem andadas
##  stop_mult: × hit-stop (adaga: DUAL_STOP_BY) · jab_width/jab_side: meia-largura (m) e recuo para o lado da estocada
const DUAL := {"sliver_deg": 80.0, "reach": 0.9, "inner": 0.5, "height": 0.80, "off_height": 0.66, "turn": 12.0,
	"tilt": 18.0, "life": 0.13, "off_alpha": 0.8, "peak_off": 0.25, "stop_mult": 0.75, "push": 0.12,
	"jab_width": 0.24, "jab_side": 0.22}
const DUAL_STOP_BY := {"dagger": 0.5}
## "clipe|família da mão" -> [mão principal, mão de trás]; cada uma [] (parada ou de cima: sem lasca) ou [lado, "F" lasca |
## "W" estocada]. Da tabela de golpes (atk_dual_a/b pelo passo mais rápido, sweep_fast; há check que relê a tabela).
## Clipes de cima (flurry, finisher, leap) ficam sem linha: a skill de duas armas mantém o rastro até a onda 5.
## "atk_sweep|axe2h" = mão de trás da Empunhadura de Titã (medida 2026-11-15: a mão esquerda vai junto com a direita, +X).
const DUAL_ARC := {
	"atk_dual_a|axe": [[1.0, "F"], [-1.0, "F"]], "atk_dual_a|mace": [[1.0, "F"], [-1.0, "F"]],
	"atk_dual_a|sword": [[1.0, "F"], [-1.0, "F"]], "atk_dual_a|dagger": [[1.0, "F"], []],
	"atk_dual_a|claw": [[1.0, "F"], [1.0, "F"]],
	"atk_dual_b|axe": [[], [0.0, "W"]], "atk_dual_b|mace": [[], [0.0, "W"]], "atk_dual_b|sword": [[], [0.0, "W"]],
	"atk_dual_b|dagger": [[-1.0, "F"], [-1.0, "F"]], "atk_dual_b|claw": [[-1.0, "F"], [-1.0, "F"]],
	"atk_claw|axe": [[1.0, "F"], [-1.0, "F"]], "atk_claw|mace": [[], [-1.0, "F"]], "atk_claw|sword": [[1.0, "F"], [-1.0, "F"]],
	"atk_claw|dagger": [[1.0, "F"], [-1.0, "F"]], "atk_claw|claw": [[1.0, "F"], []],
	"atk_sweep|axe": [[1.0, "F"], []], "atk_sweep|mace": [[1.0, "F"], [-1.0, "F"]], "atk_sweep|sword": [[1.0, "F"], [-1.0, "F"]],
	"atk_sweep|dagger": [[1.0, "F"], [1.0, "F"]], "atk_sweep|claw": [[], [1.0, "F"]],
	"atk_sweep|axe2h": [[], [1.0, "F"]],
	# onda 5: de cima em par = um crescente em pé (da principal) + a lasca da mão de trás quando ela corre de lado (tabela);
	# estocada em par = cunha (+ a da mão de trás quando ela também estoca)
	"atk_flurry|axe": [[0.0, "S"], []], "atk_flurry|mace": [[0.0, "S"], []], "atk_flurry|sword": [[0.0, "S"], []],
	"atk_flurry|dagger": [[0.0, "S"], [1.0, "F"]], "atk_flurry|claw": [[0.0, "S"], [1.0, "F"]],
	"atk_finisher|axe": [[0.0, "S"], [-1.0, "F"]], "atk_finisher|mace": [[0.0, "S"], []], "atk_finisher|sword": [[0.0, "S"], []],
	"atk_finisher|dagger": [[0.0, "S"], [-1.0, "F"]], "atk_finisher|claw": [[1.0, "F"], []],
	"atk_leap|axe": [[0.0, "S"], []], "atk_leap|mace": [[0.0, "S"], []], "atk_leap|sword": [[0.0, "S"], []],
	"atk_leap|dagger": [[0.0, "S"], []], "atk_leap|claw": [[0.0, "S"], []],
	"atk_thrust|axe": [[1.0, "W"], []], "atk_thrust|mace": [[1.0, "W"], []], "atk_thrust|sword": [[1.0, "W"], []],
	"atk_thrust|dagger": [[1.0, "W"], [1.0, "W"]], "atk_thrust|claw": [[1.0, "W"], [1.0, "W"]],
}
const STOP_CAP_FRAMES := 8.0         # teto da parada (quadros a 60 Hz) depois do stop_mult: o clipe não fica para trás da sim
const MARK_INNER := 0.78             # risco no chão: faixa fina
const MARK_LIFE_MULT := 1.4          # e dura um pouco mais que o arco
const MARK_LIFE_MAX := 0.2           # marca no chão: vida, opacidade e brilho com teto (o chão saturado é dos avisos de golpe)
const MARK_ALPHA := 0.6
const MARK_GLOW := 1.0
const POOL_SIZE := 8                 # nós por tipo (arco, faíscas, estrela, cunha): golpe a mais reaproveita o mais velho
## Golpes dos outros (bots, guardas; fora do FxManager._mine): só até OTHERS_RANGE m do jogador e nunca nas últimas
## MINE_RESERVE vagas livres de cada pool (o golpe do jogador/grupo sempre acha nó, mesmo na briga grande)
const OTHERS_RANGE := 16.0
const MINE_RESERVE := 3
## A marca no chão ganha contorno mais largo e escuro (lê na areia clara sem subir o teto de alfa MARK_ALPHA)
const MARK_RIM_BOOST := 1.0
const SPARK_LIFE := 0.20
const STAR_LIFE := 0.11
const STAR_SIZE := 0.9
const STAR_TO_CAM := 0.7             # m que a estrela sai na direção da câmera (não some dentro do corpo do alvo)
const SPARK_LEN := 1.25
const ARC_SEGS := 24                 # divisões no ângulo da malha (a forma sai do vertex shader)
const ARC_RINGS := 4                 # divisões no raio

static var _shader: Shader = null
static var _arc_mesh: ArrayMesh = null
static var _fan_mesh: ArrayMesh = null
static var _star_mesh: QuadMesh = null

var fx                               # FxManager (camera, main, _mine)
var _mat: ShaderMaterial
var _pools := {0: [], 1: [], 2: [], 3: [], 4: []}  # shape -> [{mi, t, life, hold, on, mine, attacker}] (3 = cunha, mesma malha do arco; 4 = garras K)
var _for_mine := true                # as vagas pedidas agora são do jogador/grupo (marcado na entrada: swing, _slash, form_hook)
var _swings := {}                    # id do atacante -> {frame, dir, sweep, fam, targets, theme}
var last_form := false               # o último swing foi de forma de bicho (golpe no alvo: o FxManager mantém o corte no alvo)
var last_form_id := ""               # forma do último swing de bicho ("" = arma ou sem arco)

## Família de arco da entidade ("" = sem arco: rastro antigo). Duas armas de 1 mão: dual_families (lascas por mão).
static func family_of(e: SimEntity) -> String:
	if e == null or e.stats == null:
		return ""
	if e.form != "":
		return str(FORM_FAMILY.get(e.form, ""))   # bicho: a forma vence a arma (o urso de malho não ganha o crescente do malho)
	if e.stats.offhand_type in ItemDef.ONE_HANDED_MELEE:
		return ""
	var w := e.stats.weapon_type
	return w if FAMILIES.has(w) and (FAMILIES[w] as Dictionary).get("on", true) else ""

## Duas armas de 1 mão com arco: [família da principal, família da de trás]; [] = não é par (ou família desligada).
static func dual_families(e: SimEntity) -> Array:
	if e == null or e.stats == null or e.form != "":
		return []
	var w := e.stats.weapon_type
	var o := e.stats.offhand_type
	if not (o in ItemDef.ONE_HANDED_MELEE and w in ItemDef.ONE_HANDED_MELEE):
		return []
	for f in [w, o]:
		if not FAMILIES.has(f) or not (FAMILIES[f] as Dictionary).get("on", true):
			return []
	return [w, o]

## Lasca de uma mão: [] = nada; senão [lado, "F"/"W"]. hand 0 = principal (linha da família dela), 1 = de trás.
static func dual_entry(clip: String, family: String, hand: int) -> Array:
	var k := clip + "|" + family
	if not DUAL_ARC.has(k):
		return []
	return (DUAL_ARC[k] as Array)[hand]

## Multiplicador do hit-stop do golpe de duas armas (pela principal).
static func dual_stop_mult(main_family: String) -> float:
	return float(DUAL_STOP_BY.get(main_family, DUAL["stop_mult"]))

const ARC_TARGETS := [SkillDef.Target.CONE, SkillDef.Target.SELF, SkillDef.Target.GROUND, SkillDef.Target.TARGET]

## O arco desenha esta skill? Golpe físico em cone (básico e leques) e, com clipe de linha própria, giro/salto/golpe no alvo.
## Forma de bicho do Druida (onda 6): só lobo/urso/Alfa/Ent, golpe físico cujo clipe do bicho tem linha em FORM_ARC
## (o bote e a investida são DIRECTION: só aqui); as outras formas ficam sem arco.
static func draws_arc(e: SimEntity, s: SkillDef) -> bool:
	if s != null and e != null and e.form != "":
		if family_of(e) == "" or not (s.target in ARC_TARGETS or s.target == SkillDef.Target.DIRECTION):
			return false
		if not (s.kind == SkillDef.Kind.PHYSICAL or s.id.begins_with("basic_")):
			return false
		var fk := form_clip(e, s) + "|" + e.form
		return FORM_ARC.has(fk) or FORM_STANDING.has(fk)
	if s == null or e == null or not (s.target in ARC_TARGETS):
		return false
	if not (s.kind == SkillDef.Kind.PHYSICAL or s.id.begins_with("basic_")):
		return false
	var duo := dual_families(e)
	if not duo.is_empty():                     # par: só se o clipe tem lasca em alguma mão (os dois lados do combo do básico)
		for combo in [0, 1]:
			var c := EntityView.clip_for_skill(s, duo[0], duo[1], combo)
			if not dual_entry(c, duo[0], 0).is_empty() or not dual_entry(c, duo[1], 1).is_empty():
				return true
		return false
	var fid := family_of(e)
	if fid == "":
		return false
	var c0 := EntityView.clip_for_skill(s, e.stats.weapon_type, e.stats.offhand_type, 0)
	if c0 == "atk_staff":
		return false                           # básico de magia com cajado/foice: a fita na cor do tema fica
	if s.target != SkillDef.Target.CONE:       # giro, salto, golpe no alvo: só clipe com linha (nunca o lado sorteado)
		return not arc_entry(c0, fid).is_empty()
	return s.kind == SkillDef.Kind.PHYSICAL or s.id.begins_with("basic_")

## O rastro (fita) sai quando o arco substitui: mesma regra do arco; magia/cajado mantém a fita.
static func ribbon_off(e: SimEntity, s: SkillDef) -> bool:
	return draws_arc(e, s)

## Linha de CLIP_ARC do clipe nessa família ("clipe|família", depois "clipe|*"); [] = sem linha.
static func arc_entry(clip: String, family: String) -> Array:
	var k := clip + "|" + family
	if CLIP_ARC.has(k):
		return CLIP_ARC[k]
	k = clip + "|*"
	return CLIP_ARC[k] if CLIP_ARC.has(k) else []

## Clipe do bicho que a skill toca na forma (a mesma regra da EntityView: gesto humano -> FORM_CLIP; sem par = "attack").
static func form_clip(e: SimEntity, s: SkillDef) -> String:
	var c := EntityView.clip_for_skill(s, e.stats.weapon_type if e.stats else "", e.stats.offhand_type if e.stats else "", 0, true, false)
	if c in ["attack", "maul", "pounce", "slam", "roar", "brace"]:
		return c
	return str(EntityView.FORM_CLIP.get(c, "attack" if s.kind == SkillDef.Kind.PHYSICAL else "roar"))

## Marcas do clipe na forma ([] = nenhuma).
static func form_marks(clip: String, form: String) -> Array:
	return FORM_ARC.get(clip + "|" + form, [])

## Quadro do gancho da EntityView para esse clipe na forma (0 = nenhum): a 2ª garra do maul.
static func form_hook_frame(clip: String, form: String) -> int:
	for m in form_marks(clip, form):
		if int(m[3]) > 0:
			return int(m[3])
	return 0

static var _k_meshes := {}

## Malha da forma K: riscos afilados no plano do chão (x de lado, z para a frente; UV.x 0 cabeça .. 1 ponta, UV.y de lado).
## rake = K_STREAKS riscos paralelos (o do meio mais longo, abrindo um pouco na ponta); bite = V de 2 riscos para trás.
static func k_mesh(family: String, kind: String) -> ArrayMesh:
	var key := family + ":" + ("bite" if kind == "bite" else "rake")
	if _k_meshes.has(key):
		return _k_meshes[key]
	var fam: Dictionary = FAMILIES[family]
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var streaks: Array = []              # [início, direção, comprimento, meia-largura]
	if kind == "bite":
		for sd in [-1.0, 1.0]:
			var a: float = deg_to_rad(K_BITE_DEG) * float(sd)
			streaks.append([Vector3.ZERO, Vector3(sin(a), 0, -cos(a)), K_BITE_ARM, float(fam["k_width"]) * 0.9])
	else:
		var gap: float = fam["k_gap"]
		for i in range(K_STREAKS):
			var off := float(i) - float(K_STREAKS - 1) * 0.5
			var length: float = float(fam["k_len"]) * (1.0 if absf(off) < 0.6 else 0.86)
			var d := Vector3(off * gap * 0.25 / maxf(length, 0.01), 0, 1).normalized()     # abre um pouco para a ponta
			streaks.append([Vector3(off * gap, 0, 0), d, length, float(fam["k_width"])])
	for st in streaks:
		var p0: Vector3 = st[0]
		var d: Vector3 = st[1]
		var side := Vector3(d.z, 0, -d.x)
		var base := v.size()
		for i in range(K_SEGS + 1):
			var t := float(i) / K_SEGS
			var hw: float = float(st[3]) * (1.0 - 0.85 * t)       # cheio na cabeça, ponta fina
			var c := p0 + d * float(st[2]) * t
			v.append_array([c - side * hw, c + side * hw])
			uv.append_array([Vector2(t, 0.0), Vector2(t, 1.0)])
		for i in range(K_SEGS):
			var a := base + i * 2
			idx.append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_k_meshes[key] = m
	return m

## Onde a marca fica no mundo: [Transform3D]. origin = entidade no chão, fwd = para onde ela olha; mark = linha de FORM_ARC.
static func k_xf(origin: Vector3, fwd: Vector3, mark: Array, fam: Dictionary, scale: float) -> Transform3D:
	var f := Vector3(fwd.x, 0.0, fwd.z)
	f = f.normalized() if f.length() > 0.001 else Vector3.FORWARD
	var side := Vector3.UP.cross(f)                 # +X do modelo
	var x: float = float(mark[1])
	var kk: Array = K_KIND.get(str(mark[0]), [1.0, 0.0])
	var turn := deg_to_rad(float(kk[1])) * (signf(x) if x != 0.0 else 1.0)
	var d := f.rotated(Vector3.UP, turn)            # pisão: abre para fora (+X gira para +X)
	var dside := Vector3.UP.cross(d)
	var at := origin + side * x * scale + f * float(mark[2]) * scale + Vector3(0, float(fam["k_y"]), 0)
	var lenf: float = 1.0 if str(mark[0]) == "bite" else float(kk[0])
	return Transform3D(Basis(dside * scale, Vector3.UP * scale, d * scale * lenf), at)

## Cor da forma K: sempre a faixa da forma, qualquer que seja o tema da skill (decisão D1, 2026-11-15).
static func k_band_rim(family: String) -> Array:
	return band_rim(FAMILIES[family], "")

## Cor da faixa de um tema mágico no arco.
static func theme_band(theme: String) -> Color:
	return SkillFx.col(theme, 0).lerp(Color.WHITE, float(THEME_WHITE_BY.get(theme, THEME_WHITE)))

## Progresso inicial do arco (3º número da linha de CLIP_ARC; 0 = nasce inteiro).
static func peak_off_of(clip: String, family: String) -> float:
	var a := arc_entry(clip, family)
	return float(a[2]) if a.size() > 2 else 0.0

## Lado do golpe pelo clipe tocado (desconhecido: alterna pelo combo).
static func sweep_of(clip: String, combo: int, family := "") -> float:
	var a := arc_entry(clip, family)
	if not a.is_empty():
		return float(a[0])
	return -1.0 if combo % 2 == 0 else 1.0

## Forma do arco pela linha do clipe ("F" sem linha). Família sem medidas próprias usa S_DEFAULT/W_DEFAULT/R_DEFAULT.
static func shape_of(clip: String, family: String) -> String:
	var a := arc_entry(clip, family)
	if a.is_empty() or not FAMILIES.has(family):
		return "F"
	return str(a[1])

## A linha da família por cima das medidas padrão da forma (a família que traz as dela ganha).
static func shape_params(fam: Dictionary, shape: String) -> Dictionary:
	var d: Dictionary = {"S": S_DEFAULT, "W": W_DEFAULT, "R": R_DEFAULT}.get(shape, {})
	return d.merged(fam, true)

## Quadros de parada do golpe: os da sim × stop_mult da família, com teto.
static func stop_frames(frames: int, family: String) -> float:
	var m: float = (FAMILIES[family] as Dictionary).get("stop_mult", 1.0) if FAMILIES.has(family) else 1.0
	return stop_frames_mult(frames, m)

static func stop_frames_mult(frames: int, mult: float) -> float:
	return minf(float(frames) * mult, STOP_CAP_FRAMES)

## Arco em pé: plano vertical ao longo de `fwd`, girado no eixo do golpe para a câmera (até s_roll; `to_cam` zero =
## sem giro), elipse com `radius` à frente e s_up de altura; a cabeça termina rente ao chão (nunca abaixo).
## Devolve [Transform3D, abertura em graus, distância à frente onde a cabeça bate].
static func standing_xf(origin: Vector3, fwd: Vector3, radius: float, fam: Dictionary, to_cam: Vector3) -> Array:
	var f := Vector3(fwd.x, 0.0, fwd.z)
	f = f.normalized() if f.length() > 0.001 else Vector3.FORWARD
	var side := Vector3.UP.cross(f)
	var tc := to_cam - f * to_cam.dot(f)
	if side.dot(tc) < 0.0:
		side = -side
	var roll := 0.0
	if tc.length() > 0.01:
		roll = minf(atan2(maxf(tc.dot(Vector3.UP), 0.0), maxf(side.dot(tc), 0.001)), deg_to_rad(float(fam["s_roll"])))
	var n := side * cos(roll) + Vector3.UP * sin(roll)
	var w := n.cross(f)
	if w.y < 0.0:
		w = -w                                   # "para cima" dentro do plano
	var pivot: float = fam["s_pivot"]
	radius *= float(fam["s_reach"])
	var rv: float = fam["s_up"]
	var head := -asin(clampf((pivot - 0.03) / maxf(rv * w.y, 0.01), 0.0, 0.98))
	var tail := deg_to_rad(float(fam["s_tail"]))
	var c := (tail + head) * 0.5
	# ponto no ângulo φ do plano = f·radius·cos φ + w·rv·sin φ; o arco do shader vai de c+A/2 (cauda) a c-A/2 (cabeça)
	var z := f * radius * cos(c) + w * rv * sin(c)
	var x := f * radius * sin(c) - w * rv * cos(c)
	var xf := Transform3D(Basis(x, n * radius, z), origin + Vector3(0, pivot, 0))
	return [xf, rad_to_deg(tail - head), radius * cos(head)]

## Malha do arco: grade em UV (a forma do crescente sai do shader), uma para todas as famílias.
static func arc_mesh() -> ArrayMesh:
	if _arc_mesh == null:
		var v := PackedVector3Array()
		var uv := PackedVector2Array()
		var idx := PackedInt32Array()
		for i in range(ARC_SEGS + 1):
			for j in range(ARC_RINGS + 1):
				var u := float(i) / ARC_SEGS
				var r := float(j) / ARC_RINGS
				v.append(Vector3(u - 0.5, 0, r))
				uv.append(Vector2(u, r))
		for i in range(ARC_SEGS):
			for j in range(ARC_RINGS):
				var a := i * (ARC_RINGS + 1) + j
				var b := a + ARC_RINGS + 1
				idx.append_array([a, b, a + 1, a + 1, b, b + 1])
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_INDEX] = idx
		_arc_mesh = ArrayMesh.new()
		_arc_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		_arc_mesh.custom_aabb = AABB(Vector3(-1.1, -0.2, -1.1), Vector3(2.2, 0.4, 2.2))
	return _arc_mesh

## Leque de faíscas: riscos finos saindo da origem para +Z, ±35°, comprimentos e velocidades fixos (COLOR.g).
static func fan_mesh() -> ArrayMesh:
	if _fan_mesh == null:
		var v := PackedVector3Array()
		var uv := PackedVector2Array()
		var col := PackedColorArray()
		var idx := PackedInt32Array()
		var n := 9
		for k in range(n):
			var a := deg_to_rad(lerpf(-35.0, 35.0, float(k) / (n - 1)) + (7.0 if k % 2 == 1 else -4.0))
			var d := Vector3(sin(a), 0, cos(a))
			var side := Vector3(d.z, 0, -d.x)
			var length := 0.55 + 0.45 * fmod(float(k) * 0.618, 1.0)
			var wid := 0.10 if k % 3 == 0 else 0.065
			var sp := fmod(float(k) * 0.381 + 0.2, 1.0)
			var base := v.size()
			for e in [[0.0, -1.0], [0.0, 1.0], [1.0, -1.0], [1.0, 1.0]]:
				v.append(d * length * e[0] + side * wid * e[1] * (1.0 - 0.6 * e[0]))
				uv.append(Vector2(e[0], (e[1] + 1.0) * 0.5))
				col.append(Color(1, sp, 1, 1))
			idx.append_array([base, base + 2, base + 1, base + 1, base + 2, base + 3])
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_COLOR] = col
		arr[Mesh.ARRAY_INDEX] = idx
		_fan_mesh = ArrayMesh.new()
		_fan_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return _fan_mesh

static var _live: WeaponArcs = null      # o do FxManager atual (gancho do Corte e Tiro vindo da EntityView)

## Corte e Tiro: a EntityView chama no quadro SLASH_FRAME do clipe (o tick do dano é o tiro, depois).
static func slash_hook(e: SimEntity, s: SkillDef) -> void:
	if _live != null and is_instance_valid(_live):
		_live._slash(e, s)

func _slash(e: SimEntity, s: SkillDef) -> void:
	var fid := family_of(e)
	if fid == "" or arc_entry("atk_slash_shot", fid).is_empty() or fx == null or fx.main == null:
		return
	if e.map_id != fx.main.current_map_id or not _admit(e):
		return
	var fam: Dictionary = FAMILIES[fid]
	var br := band_rim(fam, FxManager.theme_of(s))
	var dir := e.forward()
	var slot := _take(0)
	var mi: MeshInstance3D = slot["mi"]
	var at := e.position + Vector3(0, fam["height"], 0)
	_start(slot, fam["life"], Transform3D(_plane_basis(at, dir, fam["tilt"], SLASH_REACH), at), br[0], br[1], fam["glow"])
	mi.set_instance_shader_parameter("arc_deg", 110.0 + float(fam["angle_pad"]))
	mi.set_instance_shader_parameter("sweep", float(arc_entry("atk_slash_shot", fid)[0]))
	mi.set_instance_shader_parameter("inner_r", fam["inner"])

func _exit_tree() -> void:
	if _live == self:
		_live = null

func _ready() -> void:
	_live = self
	if _shader == null:
		_shader = load("res://shaders/smear_arc.gdshader")
	if _star_mesh == null:
		_star_mesh = QuadMesh.new()
		_star_mesh.size = Vector2(1, 1)
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	_mat.render_priority = 2

static func _cap(shape: int) -> int:
	return K_POOL if shape == 4 else POOL_SIZE

## Vagas livres do tipo (nós apagados + os que ainda podem ser criados).
func _free(shape: int) -> int:
	var n := _cap(shape) - (_pools[shape] as Array).size()
	for slot in _pools[shape]:
		if not slot["on"]:
			n += 1
	return n

## Golpe dos outros cabe agora? Em cada pool que ele pode usar: vaga livre além da reserva do jogador, ou um nó de
## outro golpe dos outros para reaproveitar.
func _others_room() -> bool:
	for shape in [0, 3, 4]:
		if _free(shape) > MINE_RESERVE:
			continue
		var theirs := false
		for slot in _pools[shape]:
			if slot["on"] and not slot.get("mine", true):
				theirs = true
				break
		if not theirs:
			return false
	return true

## Entrada de um golpe: marca de quem são as vagas e barra o dos outros longe do jogador ou sem vaga. false = sem arco.
func _admit(e: SimEntity) -> bool:
	_for_mine = fx == null or not fx.has_method("_mine") or fx._mine(e.id)
	if _for_mine:
		return true
	var p: SimEntity = Sim.player
	if p != null and e.position.distance_squared_to(p.position) > OTHERS_RANGE * OTHERS_RANGE:
		return false
	return _others_room()

## Nó do pool do tipo: um apagado (o dos outros só fora da reserva); senão cria até o teto; senão reaproveita o mais
## andado que não está segurando a parada (o do jogador toma primeiro o dos outros; o dos outros nunca toma o do jogador).
func _take(shape: int) -> Dictionary:
	var pool: Array = _pools[shape]
	var mine := _for_mine
	var slot: Dictionary = {}
	if mine or _free(shape) > MINE_RESERVE:
		for sl in pool:
			if not sl["on"]:
				slot = sl
				break
		if slot.is_empty() and pool.size() < _cap(shape):
			var mi := MeshInstance3D.new()
			mi.mesh = [arc_mesh(), fan_mesh(), _star_mesh, arc_mesh(), k_mesh("form_wolf", "rake")][shape]     # K: a malha troca por marca (k_mesh)
			mi.material_override = _mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.top_level = true
			mi.visible = false
			add_child(mi)
			mi.set_instance_shader_parameter("shape", shape)
			slot = {"mi": mi, "t": 0.0, "life": 1.0, "hold": 0.0, "on": false}
			pool.append(slot)
	if slot.is_empty():
		var best := -INF
		for sl in pool:
			var theirs: bool = not sl.get("mine", true)
			if not mine and not theirs:
				continue
			var score := float(sl["t"]) / maxf(float(sl["life"]), 0.001)
			if float(sl["hold"]) > 0.0:
				score -= 10.0                      # segurando a parada: só se não houver outro
			if mine and theirs:
				score += 5.0                       # o jogador toma primeiro o nó de um golpe dos outros
			if score > best:
				best = score
				slot = sl
		if slot.is_empty():
			slot = pool[0]                         # (o _admit evita isto: sem vaga e sem nó dos outros)
	slot["mine"] = mine
	slot["attacker"] = -1
	return slot

## Quantos nós existem (check de pool).
func pool_count() -> int:
	return _pools[0].size() + _pools[1].size() + _pools[2].size() + _pools[3].size() + _pools[4].size()

## Nós da forma K que estão vivos agora (check do teto).
func k_live() -> int:
	var n := 0
	for slot in _pools[4]:
		if slot["on"]:
			n += 1
	return n

func _start(slot: Dictionary, life: float, xf: Transform3D, band: Color, rim: Color, glow: float) -> void:
	var mi: MeshInstance3D = slot["mi"]
	mi.global_transform = xf
	mi.visible = true
	slot["t"] = 0.0
	slot["life"] = life
	slot["hold"] = 0.0
	slot["on"] = true
	mi.set_instance_shader_parameter("progress", 0.0)
	mi.set_instance_shader_parameter("band_col", band.srgb_to_linear())
	mi.set_instance_shader_parameter("rim_col", rim.srgb_to_linear())
	mi.set_instance_shader_parameter("glow", glow)
	mi.set_instance_shader_parameter("alpha", 1.0)

## Plano deitado para a câmera: normal entre o "para cima" e a direção (no chão) de onde a câmera olha.
func _plane_basis(at: Vector3, fwd: Vector3, tilt_deg: float, scale: float) -> Basis:
	var n := Vector3.UP
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam:
		var to_cam := cam.global_position - at
		to_cam.y = 0.0
		if to_cam.length() > 0.01:
			var t := deg_to_rad(tilt_deg)
			n = (Vector3.UP * cos(t) + to_cam.normalized() * sin(t)).normalized()
	var z := (fwd - n * fwd.dot(n)).normalized()
	var x := n.cross(z)
	return Basis(x, n, z).scaled(Vector3(scale, scale, scale))

## Golpe em cone saiu (FxManager._on_skill_effect). true = desenhou o arco (o FxManager pula o leque antigo).
## `to` = fim da linha do golpe (investida: quem bateu já está lá no tick; o evento traz o ponto de partida).
func swing(skill_id: String, s: SkillDef, theme: String, origin: Vector3, dir: Vector3, reach := -1.0, to := Vector3.INF) -> bool:
	if fx == null or fx.main == null:
		return false
	last_form = false
	last_form_id = ""
	if skill_id.begins_with("mob_") or skill_id.begins_with("basic_mob_"):
		return false                               # golpe de monstro (e o básico de guarda/monstro): nunca arco, sem procurar quem foi
	var e := _attacker(skill_id, origin, to)
	if e == null or not draws_arc(e, s) or not _admit(e):
		return false
	if e.form != "":
		last_form = true
		last_form_id = e.form
		return _swing_form(e, s, dir)
	if not dual_families(e).is_empty():
		return _swing_dual(e, s, theme, origin, dir, reach)
	var fid := family_of(e)
	var rad: float = reach if reach > 0.0 else s.radius
	var fam: Dictionary = FAMILIES[fid]
	var view = fx.main.views.get(e.id)
	var clip: String = view.anim.assigned_animation if view and view.anim else ""
	var sw := sweep_of(clip, view._combo if view else 0, fid)
	var br := band_rim(fam, theme)
	var band: Color = br[0]
	var rim: Color = br[1]
	var shape := shape_of(clip, fid)
	fam = shape_params(fam, shape)
	var slot := _take(3 if shape == "W" else 0)
	var mi: MeshInstance3D = slot["mi"]
	var inner: float = fam["inner"]
	if shape == "R":
		# giro: aro inteiro em volta de quem gira, no raio real da skill; a cabeça corre no sentido do giro
		var rat := origin + Vector3(0, fam["r_height"], 0)
		_start(slot, fam["life"], Transform3D(_plane_basis(rat, dir, fam["r_tilt"], maxf(rad, 1.0)), rat), band, rim, fam["glow"])
		mi.set_instance_shader_parameter("arc_deg", 359.0)
		mi.set_instance_shader_parameter("sweep", sw)
		inner = fam["r_inner"]
		sw = 0.0
	elif shape == "W":
		# cunha ao longo do alcance, deitada um pouco para o lado da ponta; faíscas para a frente (sem lado)
		var ldir := dir.rotated(Vector3.UP, deg_to_rad(float(fam["w_lean"])) * signf(sw))
		var wat := origin + Vector3(0, fam["height"], 0)
		_start(slot, fam["life"], Transform3D(_plane_basis(wat, ldir, fam["tilt"], rad), wat), band, rim, fam["glow"])
		mi.set_instance_shader_parameter("width", float(fam["w_width"]) / maxf(rad, 0.5))
		sw = 0.0
	elif shape == "S":
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		var to_cam := cam.global_position - origin if cam else Vector3.ZERO
		var st := standing_xf(origin, dir, rad, fam, to_cam)
		_start(slot, fam["life"], st[0], band, rim, fam["glow"])
		mi.set_instance_shader_parameter("arc_deg", float(st[1]))
		mi.set_instance_shader_parameter("sweep", 1.0)
		# risco no chão onde a cabeça bate (deitado, atravessado na direção do golpe); cor NEUTRA da família, nunca a do
		# tema (decisão do usuário 2026-11-16: chão colorido de sangue/fogo é dos avisos de golpe)
		var mark := _take(0)
		var mat := origin + Vector3(0, 0.04, 0)
		var mbr := band_rim(fam, "")
		_start(mark, minf(float(fam["life"]) * MARK_LIFE_MULT, MARK_LIFE_MAX), Transform3D(_plane_basis(mat, dir, 0.0, float(st[2])), mat), mbr[0], mbr[1], MARK_GLOW)
		(mark["mi"] as MeshInstance3D).set_instance_shader_parameter("alpha", MARK_ALPHA)
		(mark["mi"] as MeshInstance3D).set_instance_shader_parameter("arc_deg", float(fam["mark_deg"]))
		(mark["mi"] as MeshInstance3D).set_instance_shader_parameter("inner_r", MARK_INNER)
		(mark["mi"] as MeshInstance3D).set_instance_shader_parameter("sweep", 1.0)
		(mark["mi"] as MeshInstance3D).set_instance_shader_parameter("rim_boost", MARK_RIM_BOOST)
		sw = 0.0
	else:
		var at := origin + Vector3(0, fam["height"], 0)
		_start(slot, fam["life"], Transform3D(_plane_basis(at, dir, fam["tilt"], rad), at), band, rim, fam["glow"])
		var deg: float = s.cone_angle_deg if s.target == SkillDef.Target.CONE else 110.0     # fora do cone: o leque do básico
		mi.set_instance_shader_parameter("arc_deg", deg + float(fam["angle_pad"]))
		mi.set_instance_shader_parameter("sweep", sw)
	mi.set_instance_shader_parameter("inner_r", inner)
	var po := peak_off_of(clip, fid)
	if po > 0.0:                               # golpe que passou do pico antes do dano: a cauda já começou a sumir
		slot["t"] = float(slot["life"]) * po
		mi.set_instance_shader_parameter("progress", po)
	slot["attacker"] = e.id
	# Empunhadura de Titã: a 2ª arma de 2 mãos ganha a lasca dela
	var off := e.stats.offhand_type
	if off in EntityView.TWO_HANDED_MELEE and FAMILIES.has(off):
		var oe := dual_entry(clip, off, 1)
		if not oe.is_empty():
			_sliver(oe, FAMILIES[off], 1, theme, origin, dir, rad)
	_remember(e.id, dir, sw, fam, float(fam["stop_mult"]), band, rim, slot)
	return true

func _remember(id: int, dir: Vector3, sw: float, fam: Dictionary, mult: float, band: Color, rim: Color, slot: Dictionary) -> void:
	var frame := Engine.get_process_frames()
	for k in _swings.keys():                  # golpes de quadros passados não recebem mais dano
		if int(_swings[k]["frame"]) != frame:
			_swings.erase(k)
	if slot.has("mi"):
		slot["attacker"] = id                  # a parada só segura este nó se ele ainda for deste golpe
	_swings[id] = {"frame": frame, "dir": dir, "sweep": sw, "fam": fam, "mult": mult, "targets": [], "band": band, "rim": rim, "slot": slot, "stopped": false}

## Forma de bicho (onda 6): as marcas de quadro 0 do clipe tocado, no chão, em volta de onde o bicho está agora
## (investida: já no fim do avanço). A 2ª garra do maul sai depois, pelo gancho da EntityView (form_hook).
func _swing_form(e: SimEntity, s: SkillDef, dir: Vector3) -> bool:
	dir = e.forward()                          # golpe em volta de si (pisão) chega sem direção: a frente do bicho na sim
	var fid := family_of(e)
	var view = fx.main.views.get(e.id)
	var clip: String = view.anim.assigned_animation if view and view.anim else form_clip(e, s)
	if form_marks(clip, e.form).is_empty():
		clip = form_clip(e, s)                 # vista ainda sem o clipe (fila de bonecos): a regra da skill
	var fam: Dictionary = FAMILIES[fid]
	var br := k_band_rim(fid)
	var first: Dictionary
	if FORM_STANDING.has(clip + "|" + e.form):
		first = _form_standing(e, s, dir, fam, br)
		_form_marks(e, clip, dir, false)
	elif s.effects.has("dash") and view and view.has_method("form_land_marks"):
		view.form_land_marks(clip)             # a sim já está no fim do bote; o boneco ainda voa até lá (EntityView)
		first = {"hold": 0.0}
	else:
		first = _form_marks(e, clip, dir, false)
	if first.is_empty():
		return false
	_remember(e.id, dir, 0.0, fam, float(fam["stop_mult"]), br[0], br[1], first)
	return true

## Crescente em pé da forma (galho do Ent): o mesmo arco S das armas, na escala da forma, cor da forma; risco no chão com teto.
func _form_standing(e: SimEntity, s: SkillDef, dir: Vector3, fam: Dictionary, br: Array) -> Dictionary:
	var sc := float(EntityView.FORM_SCALE.get(e.form, 1.0))
	var sf := shape_params(fam, "S").merged({"s_pivot": float(fam["s_pivot"]) * sc, "s_up": float(fam["s_up"]) * sc}, true)
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var st := standing_xf(e.position, dir, maxf(s.radius, 1.0), sf, cam.global_position - e.position if cam else Vector3.ZERO)
	var slot := _take(0)
	var mi: MeshInstance3D = slot["mi"]
	_start(slot, fam["life"], st[0], br[0], br[1], fam["glow"])
	mi.set_instance_shader_parameter("arc_deg", float(st[1]))
	mi.set_instance_shader_parameter("sweep", 1.0)
	mi.set_instance_shader_parameter("inner_r", fam["inner"])
	var mark := _take(0)
	var mat := e.position + Vector3(0, 0.04, 0)
	_start(mark, minf(float(fam["life"]) * MARK_LIFE_MULT, MARK_LIFE_MAX), Transform3D(_plane_basis(mat, dir, 0.0, float(st[2])), mat), br[0], br[1], MARK_GLOW)
	var mm: MeshInstance3D = mark["mi"]
	mm.set_instance_shader_parameter("alpha", minf(float(fam["alpha"]), MARK_ALPHA))
	mm.set_instance_shader_parameter("arc_deg", float(fam["mark_deg"]))
	mm.set_instance_shader_parameter("inner_r", MARK_INNER)
	mm.set_instance_shader_parameter("sweep", 1.0)
	mm.set_instance_shader_parameter("rim_boost", MARK_RIM_BOOST)
	slot["attacker"] = e.id
	return slot

## Solta as marcas do clipe: hooked false = as do tick (quadro 0), true = as de gancho (quadro > 0). Devolve a 1ª.
func _form_marks(e: SimEntity, clip: String, dir: Vector3, hooked: bool) -> Dictionary:
	var fid := family_of(e)
	if fid == "":
		return {}
	var fam: Dictionary = FAMILIES[fid]
	var br := k_band_rim(fid)
	var sc := float(EntityView.FORM_SCALE.get(e.form, 1.0))
	var sk: SkillDef = e.current_skill
	var past: float = sk.radius * K_CONE_PAST / sc if sk != null and sk.target == SkillDef.Target.CONE else 0.0
	var first: Dictionary = {}
	for m0 in form_marks(clip, e.form):
		if (int(m0[3]) > 0) != hooked:
			continue
		var mk: Array = m0
		if past > float(m0[2]):
			mk = m0.duplicate()
			mk[2] = past                       # cone: além do alvo
		var slot := _take(4)
		var mi: MeshInstance3D = slot["mi"]
		var km := k_mesh(fid, str(mk[0]))
		if mi.mesh != km:
			mi.mesh = km
			mi.set_instance_shader_parameter("shape", 4)     # trocar a malha pode zerar os parâmetros da instância
		_start(slot, minf(float(fam["life"]), MARK_LIFE_MAX), k_xf(e.position, dir, mk, fam, sc), br[0], br[1], minf(float(fam["glow"]), MARK_GLOW))
		var a: float = minf(float(fam["alpha"]), MARK_ALPHA) * (float(mk[4]) if mk.size() > 4 else 1.0)
		mi.set_instance_shader_parameter("alpha", a)
		mi.set_instance_shader_parameter("rim_boost", MARK_RIM_BOOST)
		slot["attacker"] = e.id
		if first.is_empty():
			first = slot
	return first

## Gancho da EntityView: `repeat` false = marcas de quadro > 0 do clipe (2ª garra do maul); true = o pisão que repete
## na fase ativa longa (ACTIVE_LOOP) solta de novo as marcas do tick.
static func form_hook(e: SimEntity, clip: String, repeat := false) -> void:
	if _live == null or not is_instance_valid(_live) or _live.fx == null or _live.fx.main == null:
		return
	if e.map_id != _live.fx.main.current_map_id or family_of(e) == "" or not _live._admit(e):
		return
	_live._form_marks(e, clip, e.forward(), not repeat)

## Golpe em volta de si: o FxManager desenha o aro/disco do SkillFx.circle? Não quando a forma de QUIET_FORMS desenhou as
## marcas dela (pisão = impacto; disco + aro claro no chão é a cara do aviso de chefe). drew = swing desenhou.
static func self_ring(drew: bool, form_id: String) -> bool:
	return not (drew and form_id in QUIET_FORMS)

## Cor de faixa e contorno de uma família para o tema do golpe (tema mágico usa a cor do tema).
static func band_rim(fam: Dictionary, theme: String) -> Array:
	var physical := theme in ["", "physical"]
	var band: Color = fam["band"] if physical else theme_band(theme)
	var rim: Color = fam["rim"] if fam.has("rim") and physical else band.darkened(0.82)
	return [band, rim]

## Lasca (F) ou estocada (W) de uma mão. hand 0 = principal (lado direito do boneco, -X), 1 = de trás (+X).
func _sliver(entry: Array, fam: Dictionary, hand: int, theme: String, origin: Vector3, dir: Vector3, radius: float) -> Dictionary:
	var br := band_rim(fam, theme)
	var side := 1.0 if hand == 1 else -1.0
	var side_x := Vector3.UP.cross(dir).normalized() * side
	var h: float = DUAL["off_height"] if hand == 1 else DUAL["height"]
	var slot: Dictionary
	var mi: MeshInstance3D
	if str(entry[1]) == "S":                   # par batendo de cima: um crescente em pé (sem risco no chão)
		slot = _take(0)
		mi = slot["mi"]
		var sf := shape_params(fam, "S")
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		var st := standing_xf(origin, dir, radius, sf, cam.global_position - origin if cam else Vector3.ZERO)
		_start(slot, DUAL["life"], st[0], br[0], br[1], fam["glow"])
		mi.set_instance_shader_parameter("arc_deg", float(st[1]))
		mi.set_instance_shader_parameter("sweep", 1.0)
		mi.set_instance_shader_parameter("inner_r", sf["inner"])
		return slot
	if str(entry[1]) == "W":
		slot = _take(3)
		mi = slot["mi"]
		var wat := origin + Vector3(0, h, 0) + side_x * float(DUAL["jab_side"])
		_start(slot, DUAL["life"], Transform3D(_plane_basis(wat, dir, DUAL["tilt"], radius), wat), br[0], br[1], fam["glow"])
		mi.set_instance_shader_parameter("width", float(DUAL["jab_width"]) / maxf(radius, 0.5))
		mi.set_instance_shader_parameter("inner_r", 0.25)
	else:
		slot = _take(0)
		mi = slot["mi"]
		var sdir := dir.rotated(Vector3.UP, deg_to_rad(float(DUAL["turn"])) * side)
		var at := origin + Vector3(0, h, 0)
		_start(slot, DUAL["life"], Transform3D(_plane_basis(at, sdir, DUAL["tilt"], radius * float(DUAL["reach"])), at), br[0], br[1], fam["glow"])
		mi.set_instance_shader_parameter("arc_deg", DUAL["sliver_deg"])
		mi.set_instance_shader_parameter("inner_r", DUAL["inner"])
		mi.set_instance_shader_parameter("sweep", float(entry[0]))
	if hand == 1:
		mi.set_instance_shader_parameter("alpha", DUAL["off_alpha"])
	var po: float = DUAL["peak_off"]
	slot["t"] = float(slot["life"]) * po
	mi.set_instance_shader_parameter("progress", po)
	return slot

## Golpe de duas armas: uma lasca por mão que tem linha em DUAL_ARC (ou a estocada da mão de trás).
func _swing_dual(e: SimEntity, s: SkillDef, theme: String, origin: Vector3, dir: Vector3, reach := -1.0) -> bool:
	var duo := dual_families(e)
	var view = fx.main.views.get(e.id)
	var clip: String = view.anim.assigned_animation if view and view.anim else ""
	var me := dual_entry(clip, duo[0], 0)
	var oe := dual_entry(clip, duo[1], 1)
	if me.is_empty() and oe.is_empty():
		return false
	var first: Dictionary = {}
	var sw := 0.0
	if not me.is_empty():
		first = _sliver(me, FAMILIES[duo[0]], 0, theme, origin, dir, reach if reach > 0.0 else s.radius)
		sw = float(me[0])
	if not oe.is_empty():
		var o_slot := _sliver(oe, FAMILIES[duo[1]], 1, theme, origin, dir, reach if reach > 0.0 else s.radius)
		if first.is_empty():
			first = o_slot
			sw = float(oe[0])
	var br := band_rim(FAMILIES[duo[0]], theme)
	_remember(e.id, dir, sw, {"push": DUAL["push"]}, dual_stop_mult(duo[0]), br[0], br[1], first)
	return true

## Quem soltou o golpe: a entidade do mapa naquele ponto lançando essa skill (o evento da sim não traz o id).
func _attacker(skill_id: String, origin: Vector3, to := Vector3.INF) -> SimEntity:
	var best: SimEntity = null
	var bd := 0.3 * 0.3
	for o in Sim.map_entities(fx.main.current_map_id):
		var d: float = o.position.distance_squared_to(origin)
		if to != Vector3.INF:                  # investida: em qualquer ponto da linha percorrida
			d = o.position.distance_squared_to(Geometry3D.get_closest_point_to_segment(o.position, origin, to))
		if d <= bd and o.current_skill != null and o.current_skill.id == skill_id:
			best = o
			bd = d
	return best

## Dano saiu (FxManager._on_damage): se veio de um arco deste quadro, faíscas no alvo e empurrão de desenho.
func on_damage(attacker_id: int, target_id: int, mine: bool) -> void:
	if not _swings.has(attacker_id):
		return
	var sw: Dictionary = _swings[attacker_id]
	if int(sw["frame"]) != Engine.get_process_frames():
		return
	var a: SimEntity = Sim.get_entity(attacker_id)
	var t: SimEntity = Sim.get_entity(target_id)
	if a == null or t == null:
		return
	(sw["targets"] as Array).append(target_id)
	var rel := t.position - a.position
	rel.y = 0.0
	rel = rel.normalized() if rel.length() > 0.01 else (sw["dir"] as Vector3)
	var tangent := Vector3.UP.cross(rel) * float(sw["sweep"])     # para onde a lâmina corria nesse ponto
	var fam: Dictionary = sw["fam"]
	var tv = fx.main.views.get(target_id)
	if tv:
		tv.hit_react((tangent * 0.6 + rel * 0.8).normalized() * float(fam["push"]), 0.0)
	if not mine:
		return
	_for_mine = true
	var at := t.position + Vector3(0, 0.85 * t.scale, 0) - rel * t.radius * 0.6
	var fan := _take(1)
	var fdir := (tangent * 0.8 + rel * 0.6).normalized()
	_start(fan, SPARK_LIFE, Transform3D(_plane_basis(at, fdir, 40.0, SPARK_LEN), at), sw["band"], sw["rim"], 1.4)
	var star := _take(2)
	var cam := get_viewport().get_camera_3d()
	var sat := at + ((cam.global_position - at).normalized() * STAR_TO_CAM if cam else Vector3.ZERO)
	_start(star, STAR_LIFE, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * STAR_SIZE * t.scale), sat), sw["band"], sw["rim"], 1.5)

## hit_stop da sim: se é de um arco deste quadro, congela só quem bateu e quem apanhou. true = tratado (sem time_scale).
## A sim manda 1 hit_stop por golpe que acerta: cada golpe com arco consome UM evento ("stopped"); um 2º hit_stop no
## mesmo quadro (projétil, bloqueio, golpe sem arco) cai no global do FxManager em vez de sumir aqui.
func on_hit_stop(frames: int) -> bool:
	var frame := Engine.get_process_frames()
	for id in _swings:
		var sw: Dictionary = _swings[id]
		if int(sw["frame"]) != frame or sw.get("stopped", false):
			continue
		var p: SimEntity = Sim.player
		var ts: Array = sw["targets"]
		if p == null or (id != p.id and not ts.has(p.id)):
			continue
		var stop := stop_frames_mult(frames, float(sw.get("mult", 1.0))) / 60.0
		for vid in [id] + ts:
			var v = fx.main.views.get(vid)
			if v:
				v.hit_react(Vector3.ZERO, stop)
		var slot: Dictionary = sw["slot"]
		if slot.get("on", false) and int(slot.get("attacker", -1)) == int(id):
			slot["hold"] = stop                    # o arco segura cheio durante a parada (se o nó ainda é deste golpe)
		sw["stopped"] = true
		return true
	return false

func _process(delta: float) -> void:
	for shape in _pools:
		for slot in _pools[shape]:
			if not slot["on"]:
				continue
			if float(slot["hold"]) > 0.0:
				slot["hold"] = float(slot["hold"]) - delta
				continue
			slot["t"] = float(slot["t"]) + delta
			var k := float(slot["t"]) / float(slot["life"])
			var mi: MeshInstance3D = slot["mi"]
			if k >= 1.0:
				slot["on"] = false
				mi.visible = false
			else:
				mi.set_instance_shader_parameter("progress", k)
