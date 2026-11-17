# Varredura de skills: Ranger e Elementalista (2026-11-16)

Pedido do jogador: "varredura em todos os ataques do ranger, e depois do elementalista" (depois do Tiro Múltiplo
com área minúscula). Agente: class-designer. Critério por skill: forma (SELF/DIRECTION/GROUND/CONE/TARGET) x
nome/descrição/arma/fantasia, alcance contra o básico, raio/cone/alvos, projétil, tempo, custo/recarga, efeitos,
desenho do FX (SkillFx/FxManager desenham a forma com os números reais), talentos e uso pelos bots.

## Referências

| Coisa | Número |
|---|---|
| Básico do arco (Ranger) | DIRECTION 13 m, projétil 22 m/s |
| Básico do mosquete | 13 x `RIFLE_RANGE_MULT` 1.2 = 15.6 m, projétil 40 m/s |
| Básico da lança | CONE 3.3 m / 40° / 3 alvos (`SPEAR_*`) |
| Básico do cajado (Elementalista) | DIRECTION 8 m |
| Skills de arco/mosquete do Ranger (não SELF) | `range` x `ARCHER_RANGE_MULT` 1.35 (aplicado em `SkillsCatalog.build`). **O raio de CONE não é multiplicado.** |

Números abaixo: `range` efetivo (já x1.35 quando vale). "fix" = aplicado nesta passada; "prop." = proposta para o usuário.

## Ranger

| id | nome | build | forma atual (antes) | veredito | depois / motivo |
|---|---|---|---|---|---|
| basic (arco) | Ataque | Caçador | DIR 13 m | ok | |
| basic (mosquete) | Ataque | Atirador | DIR 15.6 m, 1.8x recarga, 1.9x poder | ok | |
| basic (lança) | Ataque | Lanceiro | CONE 3.3 m / 40° / 3 | ok | |
| ran_power_shot | Tiro Poderoso | geral | DIR 16.2 m, perfura, 28 m/s | ok | "longo alcance" > básico |
| ran_multishot | Tiro Múltiplo | Caçador | CONE 11 m / 70° / 6 (antes 6 m / 60°) | fix (anterior) | já corrigido antes desta varredura |
| ran_disengage | Recuar | geral | SELF dash -4.5 | ok | |
| ran_trap | Armadilha de Mandíbula | Atirador/Lanceiro | GROUND 9.45 m, r 1.4, armadilha | ok | |
| ran_mark | Marca do Caçador | Atirador/Lanceiro | SELF buff | ok (nome) | prop.: o nome "do Caçador" está em duas builds que não são o Caçador, e a lendária do Caçador também se chama "Marca do Caçador" |
| ran_rain | Chuva de Flechas | Caçador | GROUND 14.85 m, r 3.8, startup 0.4 | ok | |
| ran_anchor | Flecha Âncora | geral (arco/mosquete) | DIR 13.5 m, 24 m/s, 1 alvo, root 1.5 | ok | WEAK no skill_audit já antes (controle) |
| ran_snipe | Tiro Certeiro | Atirador | DIR instantâneo 17.55 m (só 12% além do básico 15.6), startup 0.45 | **fix** | range 13 -> 15 (efetivo 20.25 m, +30% sobre o mosquete): "longuíssimo alcance" de verdade. prop.: startup 0.45 > regra de 0.3 (tiro mirado, deixei) |
| ran_piercing | Flecha Perfurante | Caçador | DIR 14.85 m, perfura | ok | |
| ran_headshot | Tiro na Cabeça | Atirador | TARGET 14.85 m (< mosquete 15.6) | **fix** | range 11 -> 12 (16.2 m): o tiro preciso não fica mais curto que o básico |
| ran_deadeye | Olho de Águia | Atirador | SELF buff | ok | |
| ran_companion | Companheiro | Caçador | SELF invocação | ok | |
| ran_sic | Ataque da Fera | Caçador | TARGET 16.2 m (comando do lince) | ok | |
| ran_pack | Instinto da Matilha | Caçador | SELF buff + lince | ok | |
| ran_scatter | Tiro de Dispersão | Atirador | CONE 5 m / 55° / 5, slow 30% | **fix (texto)** | descrição prometia "empurra o alvo para trás" e não empurra: texto agora "cone curto (5 m), até 5, retarda 30% 1.5s". prop.: empurrão `knockback` (efeito que já existe, usado pelo Canhão de Mão) |
| ran_mine | Mina Explosiva | Atirador | GROUND 9.45 m, r 2.6, armadilha | ok | |
| ran_frost_trap | Armadilha de Gelo | Atirador | GROUND 9.45 m, r 3.0 | ok | |
| ran_explosive | Flecha Explosiva | Caçador | GROUND 13.5 m, r 2.2 | fix (texto) | "Explode no cursor." -> diz que é área de 2,2 m |
| ran_frost_arrow | Flecha Gélida | Caçador | DIR 13.5 m, slow 45% | ok | |
| ran_net | Rede | Caçador | GROUND 12.15 m, r 2.4, root 2.5 | ok | WEAK já antes (controle puro) |
| ran_volley | Saraivada | Caçador (22) | CONE **8 m / 50°**, sem teto de alvos | **fix** | "leque longo e estreito" era MAIS CURTO que o Tiro Múltiplo do nível 3 (11 m). Agora 13 m (alcance do arco) / 40° / até 8 alvos. Área 2,1x; compensado com teto de 8 alvos e cone mais fechado (perto de você pega menos); poder igual |
| ran_barrage | Barragem | Caçador (27) | GROUND r **3.5** (menor que a Chuva de nível 20, r 3.8) | **fix** | r 4.0 (área +31%, sem mexer no poder): a "área grande" do 27 não é menor que a do 20 |
| ran_double_thrust | Estocada Dupla | Lanceiro | CONE 3.6 m / 36° / 3, sangra | ok | 1 golpe só (as "duas estocadas" são do clipe) |
| ran_javelin | Dardo de Caça | Lanceiro | DIR 10 m, 26 m/s, 1 alvo | ok | lança não ganha x1.35 (só arco/mosquete) |
| ran_spear_leap | Salto do Predador | Lanceiro | GROUND 6.5 m, r 2.2, dash fixo 6 m | **prop. (bug)** | o salto anda SEMPRE 6 m, mas o dano sai no cursor: com o cursor a 2 m ele passa do ponto e o dano fica atrás dele. Mesmo problema em `ber_leap`, `bis_faith_leap`, `ass_shadowstep` (todos "até o cursor"). Correção sugerida em `WorldSim._apply_skill`: GROUND + dash anda min(dash, distância do cursor). Não aplicada: muda 3 outras classes |
| ran_spear_sweep | Lança Giratória | Lanceiro | SELF r 3.4 | ok | |
| ran_snare_toss | Armadilha Lançada | Lanceiro | GROUND 8 m, r 1.8, root 2 + sangra | ok | WEAK já antes |
| ran_predator | Marca do Predador | Lanceiro | TARGET 9 m, maldição 10 s, slow 25% 2 s | fix (texto) | o texto não dizia que a lentidão dura 2 s (lia como 10 s) |
| ran_blood_instinct | Instinto do Predador | Lanceiro | SELF buff | ok | |
| ran_impale | Empalar | Lanceiro | DIR investida 5 m (alcance 6), r 1.0 | ok | |
| ran_turret | Torreta de Campo (asc.) | Atirador | GROUND 10.8 m | ok | |
| ran_dragon_jump | Salto Dracônico (asc.) | Lanceiro | GROUND 9 m, r 3.0, pousa no cursor | ok | (este já cai no ponto mirado) |
| ran_shout_* | Brados (asc.) | Lanceiro | SELF buff | ok | |
| ran_falcon | Chamado do Falcão (asc.) | Caçador | SELF | ok | |
| ran_dive | Mergulho (asc.) | Caçador | TARGET `FALCON_RANGE` x1.35 | ok | |
| ran_sky_eyes | Olhos do Céu (asc.) | Caçador | SELF buff de grupo | ok | |

Talentos/evoluções do Ranger:

| id | veredito | nota |
|---|---|---|
| ran_t_multishot (Leque Aberto) | ok | +20% raio (já ajustado antes) |
| ran_t_power_shot, ran_t_trap, ran_t_thrust, ran_t_predator | ok | |
| ran_c_ghost (Tiro Fantasma) | **fix** | prometia "Tiro na Cabeça atravessa", mas a skill é TARGET (sem projétil): `projectile_pierce` não fazia nada. Texto agora "+30% de dano" e o `set` morto saiu. prop.: um efeito real (ex.: o tiro passa e acerta quem está atrás do alvo) |
| ran_c_pierce, ran_c_mines, ran_c_volley, ran_c_wide_sweep, ran_c_long_leap... | ok | |

## Elementalista

| id | nome | build | forma atual (antes) | veredito | depois / motivo |
|---|---|---|---|---|---|
| basic (cajado) | Ataque | todas | DIR 8 m | ok | |
| ele_fireball | Bola de Fogo | geral | DIR 9 m, 16 m/s, r 0.5, alvo único | **fix (texto)** | dizia "explode e queima", mas o projétil não tem explosão. Texto: "queima o alvo por 3s". prop.: explosão de verdade (área no impacto) - é a fantasia clássica da Bola de Fogo |
| ele_spark | Faísca | geral | DIR instantâneo 8 m, 1 alvo | ok | |
| ele_frost_nova | Nova de Gelo | Gelo | SELF r 3.5 | ok | WEAK já antes |
| ele_lightning | Relâmpago | Raio | DIR instantâneo 10 m, 3 alvos | ok | |
| ele_meteor | Meteoro | Fogo | GROUND 10 m, r 3.0, startup 0.55 | ok | |
| ele_blink | Piscar | geral | SELF dash 6 | ok | |
| ele_blizzard | Nevasca | Gelo | GROUND 10 m, r 4.5 | ok | |
| ele_firestorm | Tempestade de Brasas | combo | GROUND 9 m, r 2.8 | ok | |
| ele_frost_flare | Choque Térmico | combo | TARGET 9 m, r 1.8, 5 | ok | |
| ele_hailstorm | Granizo Trovejante | combo | GROUND 9 m, r 3.2 | ok | |
| ele_prism | Prisma Elemental | combo | DIR 12 m, perfura | ok | |
| ele_summon_fire/ice/storm | Elementais | Fogo/Gelo/Raio | SELF invocação | ok | |
| ele_asc_command | Comando Elemental (asc.) | geral | SELF | ok | |
| ele_asc_fusion | Fusão Elemental (asc.) | geral | TARGET 9 m, r 2.5 | ok (sim) | prop. (visual): o tema do FX é sempre `lightning`; com elemental de fogo ou gelo a Fusão desenha raios. O evento `skill_effect` não traz quem lançou, então o FX não sabe a forma: precisa de um tema por forma no evento. WEAK já antes (recarga 40) |
| ele_flame_wave | Onda de Chamas | Fogo | CONE **4 m** / 80° (metade do básico de 8 m) | **fix** | 5 m / 75° / até 6 alvos: área +46%, compensado com o teto de 6 alvos; poder igual |
| ele_combustion | Combustão | Fogo | TARGET 9 m, r 2.6 | ok | |
| ele_fire_wall | Muralha de Fogo | Fogo | GROUND 8 m, círculo r 2.6, dot 5 s | **fix (texto)** | "Fogo no chão queima por 5s" sugeria fogo que fica no chão; é um círculo que aplica a queimadura uma vez. Texto agora diz isso. prop.: muralha de verdade (faixa/linha que fica no chão e queima quem passa) |
| ele_inferno | Inferno | Fogo | SELF r 4.0 | ok | |
| ele_phoenix | Fênix | Fogo | DIR 11 m, perfura | ok | |
| ele_ice_lance | Lança de Gelo | Gelo | DIR 9 m | ok | |
| ele_frost_armor | Armadura de Gelo | Gelo | SELF escudo | ok | |
| ele_glacier | Geleira | Gelo | GROUND 8 m, r 2.4 | ok | |
| ele_shatter | Estilhaçar | Gelo | TARGET 9 m, r 1.5, 4 | ok | |
| ele_absolute_zero | Zero Absoluto | Gelo | SELF r 4.5 | ok | |
| ele_chain | Corrente Elétrica | Raio | TARGET 9 m, r 3.0, 4 alvos | **fix (visual)** | o FX desenhava os saltos até monstros a 5 m do alvo, mas a sim só acerta a 3 m: raio pulando em quem não tomou dano. Agora o FX usa o raio real (`FxManager._on_skill_effect`); vale também para Fusão, Silfo e Corrente da Tempestade |
| ele_static | Campo Estático | Raio | GROUND 8 m, r 3.0 | ok | |
| ele_overload | Sobrecarga | Raio | SELF buff | ok | |
| ele_thunder | Trovão | Raio | GROUND 9 m, r 2.2 | ok | |
| ele_storm_lord | Senhor da Tempestade | Raio (28) | GROUND r **3.5**, poder 3.8 | **fix** | "tempestade gigante" menor que a Nevasca (4.5) e pouco maior que o Campo Estático (3.0): r 4.2 (área +44%), poder 3.8 -> 3.6 (-5%) como compensação |
| elem_* (estágios do elemental) | | asc. | | ok | |

Talentos do Elementalista:

| id | veredito | nota |
|---|---|---|
| ele_t_fireball (Bola de Fogo Maior) | **fix (texto)** | "explode 60% maior": não há explosão, o raio só alarga o projétil. Texto: "60% mais larga (acerta mais fácil) e queima mais forte e por mais tempo" |
| ele_t_meteor (Chuva de Brasas) | **fix (texto)** | "deixa o chão queimando": é só uma queimadura mais forte nos atingidos. Texto ajustado |
| ele_t_frost_nova, ele_t_lightning, ele_c_* | ok | |

## Propostas para o usuário (1ª rodada; o usuário mandou fazer todas: ver "2ª rodada" abaixo)

1. **Saltos que caem no cursor** (bug de mecânica, 4 classes): `ran_spear_leap`, `ber_leap`, `bis_faith_leap`, `ass_shadowstep`
   andam sempre o `dash` inteiro, mas o dano sai no cursor. Sugestão: em `WorldSim._apply_skill`, skill GROUND com
   `dash` anda `min(dash, distância até o cursor)`. Mexe na mobilidade de Berserker, Bispo e Assassino.
2. **Bola de Fogo explode**: área pequena no impacto (ex. 1,5 m, poder cheio no alvo e ~60% em volta). Volta a
   fazer sentido o talento "explode 60% maior". Mexe no DPS em grupo do Fogo.
3. **Muralha de Fogo de verdade**: faixa no chão que fica 5 s e queima quem atravessa (como o Miasma do Necromante).
4. **Tiro de Dispersão empurra**: `knockback` curto (2-3 m), o efeito já existe.
5. **Tiro Fantasma**: dar um efeito real ao talento (atravessar = acerta também quem está atrás do alvo).
6. **Fusão Elemental com a cor da forma**: tema do FX pela forma do elemental (fogo/gelo/raio).
7. **Nome da Marca do Caçador**: a skill `ran_mark` é do Atirador e do Lanceiro; a lendária do Caçador tem o mesmo nome.
8. **Preparo longo**: `ran_snipe` 0.45 s, `ele_hailstorm` 0.45, `ele_meteor` 0.55, `ele_blizzard` 0.5 passam da regra de
   0.3 s fora de ultimate. São tiros/magias "carregados" de propósito; decidir se ficam.

## Lança que atravessa (pedido do usuário, 2026-11-16)

"o ataque do lanceiro tem que atravessar, é uma lança". Antes: básico de lança = CONE 3,3 m / 40° / 3 alvos (já pegava
até 3, mas num leque que abre para os lados e corta quem estiver atrás no 4º; o desenho W é uma cunha fina, mais
estreita que o leque real). Agora:

| o quê | antes | depois |
|---|---|---|
| forma do básico | cone 40°, 3 alvos, sem ordem | **faixa reta** 3,3 m x 1,0 m (`Balance.SPEAR_LINE_WIDTH`), do mais perto ao mais longe, até 4 (`SPEAR_MAX_TARGETS` 3 -> 4) |
| ran_double_thrust | cone 36° / 3 | mesma faixa (`line_width`), 3 alvos (Estocada Tripla: 5) |
| ran_impale | investida DIR, meia-largura 1,0 | ok (já é linha) |
| poder | 1,15 x | igual: alvo único não muda; matilha em fila ganha o 4º alvo, quem está ao lado da haste sai |
| desenho (`WeaponArcs` "spear" W) | meia-largura 0,34 m | 0,5 m = metade da faixa real |

Mecânica: campo novo opcional `SkillDef.line_width` (CONE com > 0 = faixa reta; `Combat.select_targets`). Bots não mudam
(o básico continua CONE para a IA de corpo a corpo). Check `_check_spear_line` (com prova de montagem: o cone antigo
pegava o monstro ao lado da haste).

## 2ª rodada: as 8 propostas aplicadas (usuário: "veja todos")

| # | o quê | como ficou | equilíbrio |
|---|---|---|---|
| 1 | Saltos pousam no cursor (`ran_spear_leap`, `ber_leap`, `bis_faith_leap`, `ass_shadowstep`) | `WorldSim._apply_skill`: GROUND com `dash` anda `min(dash, distância do cursor)`, mínimo `Balance.LEAP_MIN_HOP` 1 m com o cursor em cima | só mobilidade; bots miram no alvo, então pousam nele; combat_probe 0 FLAG nas 5 classes |
| 2 | Bola de Fogo explode | efeito novo `explode` (`WorldSim._explode`): em volta do atingido (1,5 m) 45% do poder + a queimadura; FX de explosão no raio real. Talento Bola de Fogo Maior = explosão 60% maior (de verdade) | poder 1,8 -> 1,7 (alvo único -5,5%) para pagar a área |
| 3 | Muralha de Fogo de verdade | efeito novo `fire_wall` (`TrapSystem.place_wall`, mora na lista de armadilhas, não conta no limite): faixa de 6 m x 1,4 m atravessada na mira, 5 s acesa; o lançamento bate, cada pulso (0,5 s) renova a queimadura (sem acumular) em quem passa; retículo em faixa, chão em brasa com chamas do tamanho real | queimadura 10/s por 5 s -> 4 s (ficar dentro mantém acesa); skill_audit 104% -> 95% da mediana |
| 4 | Tiro de Dispersão empurra | `knockback` 2,5 m (`Balance.SCATTER_PUSH`) | controle a mais, poder igual |
| 5 | Tiro Fantasma atravessa | TARGET com `projectile_pierce`: o tiro segue a fila atrás do alvo até o alcance (meia-largura `PIERCE_SHOT_HALF` 0,6), até 3 alvos (`GHOST_SHOT_TARGETS`); rastro de tiro até o último | +30% -> +15% de dano (agora pega até 3) |
| 6 | Fusão Elemental na cor da forma | `FxManager._fusion_theme`: acha quem lançou e pinta fogo/gelo/raio pela forma do elemental (`FUSION_THEMES`) | só visual |
| 7 | `ran_mark` renomeada | "Foco Mortal" (id igual, saves seguem); "Marca do Caçador" fica só para a lendária do Caçador. DESIGN.md e buffs_visual.md atualizados | |
| 8 | Preparo longo | nada a mudar: as 3 magias já mostram o "juntar energia" no preparo (`SkillFx.gather`) e o meteoro cai durante ele; o Tiro Certeiro (físico 0,45 s) mostra o aro de aviso. A barra de lançamento do HUD é só de retorno/montaria | |

Checks: `_check_skill_sweep_round2` (salto no cursor nas 4 skills + cursor longe + cursor em cima, explosão pega vizinho e não o de longe e bate menos que o alvo, talento da explosão, muralha fica/bate só na faixa/queima quem entra sem acumular/apaga, empurrão, nome, Tiro Fantasma 1 -> 3 alvos, temas da Fusão).

## Verificação

Ver relatório final do agente (testes, skill_audit antes/depois, showcase, combat_probe, smoke).
