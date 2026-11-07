# Revisão de animações (2026-11)

Laço de revisão sobre TODOS os clipes: personagem (47 clipes do kit, cada um com a classe que usa a arma dele, de lado e de
frente; macho = paladino/berserker/assassino/necromante, fêmea = bispo/druida/ranger/elementalista), monstros e formas
(25 modelos, um por tipo de rig: humanoide de kit, quadrúpede, cavalo, aranha, caranguejo, fantasma, elemental, golem, ent,
larva, morcego, formas Lobo/Urso/Demônio; 160 filmes). 258 filmes no total + números de `anim_probe`.

## Ferramentas

- `tools/lineup/film_all.sh <pasta> [char|mob|all] [regex]`: filma tudo (lineup `--strip`/`--mob_strip`, recorte `--crop`).
- `tools/tests/anim_probe.tscn -- [--models=a,b] [--clips=x] [--csv=<arq>]`: por clipe mede costura do loop, maior giro de
  osso por quadro, giro total (quanto mexe), pico de velocidade da mão e em que quadro cai (golpe com estalo no IMPACT),
  quadros parados e altura mínima da cabeça (afundar no chão).
- `tools/tests/run_tests.gd::_check_anim_review`: costura dos loops sem quadro parado, cabeça fora do chão na morte, golpe de
  monstro com pose de impacto no quadro 5, monstro humanoide só com os 7 clipes de bicho.

## Nota (0-2 cada, máx. 10)

S = silhueta/leitura da câmera alta · A = antecipação → impacto → acompanhamento · W = peso · O = movimento secundário
(capa, cabelo, mão livre, rabo) · L = costura do loop (idle/corrida) ou início/fim limpos (golpes).

### Achado global: quadro morto no começo de TODO clipe exportado

O exportador glTF (modo NLA) começava no quadro 0, uma cópia parada do quadro 1: todo clipe ganhava 1/24 s morto no início,
o impacto saía 1 quadro depois de `(IMPACT-1)/24` (a conta da `EntityView`) e os loops davam um tranco na costura
(corrida: 17° no 1º quadro contra 113° no último; idle/queda/guarda idem; monstros também). Correção:
`export_anim_slide_to_zero=True` em `chibi_kit.export_glb` e `lowpoly_lib.export_glb`. Isso sobe o L de todos os clipes.

### Personagem (kit, todas as classes)

| clipe | antes S A W O L = total | depois | o que mudou |
|---|---|---|---|
| idle | 2 1 1 2 1 = 7 | 8 | costura |
| idle_bow / idle_staff | 2 1 1 1 1 = 6 | 7 | costura |
| run | 2 2 1 2 0 = 7 | 9 | costura (tranco a cada passada) |
| block | 1 1 1 0 1 = 4 | 5 | costura |
| block_shield | 2 1 2 1 1 = 7 | 8 | costura |
| jump | 2 2 1 1 1 = 7 | 8 | início |
| fall | 1 1 1 1 0 = 4 | 6 | costura |
| land | 1 2 2 1 1 = 7 | 8 | início |
| **dash** | 1 1 1 1 1 = 5 | 7 | pose parada do 3 ao 7 → as pernas trocam a tesoura, braços batem, corpo quica |
| hit | 2 2 1 1 1 = 7 | 8 | início |
| **die** | 2 2 1 1 0 = 6 | 9 | a cabeça afundava ~0,3 m no chão (raiz -86°, quadril empurrando para baixo, cabeça para trás) → raiz -76°, queixo no peito, quique |
| atk_1h_a | 2 2 1 1 1 = 7 | 8 | início |
| atk_1h_b | 1 2 1 1 1 = 6 | 7 | início |
| atk_2h | 2 2 2 1 1 = 8 | 9 | início |
| **atk_dual_a / atk_dual_b** | 0 1 1 1 1 = 4 | 7 | só cotovelo → lâmina sobe por fora, tronco torce e varre, mão livre em guarda, passo + acompanhamento |
| **atk_dagger** | 0 1 0 1 1 = 3 | 7 | estocada sem corpo → tronco gira para trás com a adaga na cintura, bote com passo longo e ombro à frente (pico da mão 11 → 18 m/s no quadro 5) |
| **atk_thrust** | 0 1 0 1 1 = 3 | 7 | mesma estocada, mais longa (pico 12 → 20 m/s) |
| atk_bow | 1 2 1 1 1 = 6 | 7 | início |
| atk_shoot_multi | 1 2 1 1 1 = 6 | 7 | início |
| **atk_rifle** | 1 1 0 1 1 = 4 | 7 | coice de 8° → cano sobe, ombros e cabeça para trás, pé de trás segura, volta à mira |
| atk_staff | 2 2 2 1 1 = 8 | 9 | início |
| atk_spin | 2 1 1 1 1 = 6 | 7 | início |
| atk_leap | 2 2 2 1 1 = 8 | 9 | início |
| atk_charge | 1 1 1 1 1 = 5 | 6 | início (pose parada na investida: candidato) |
| atk_throw | 2 2 1 1 1 = 7 | 8 | início |
| atk_sweep | 2 2 2 1 1 = 8 | 9 | início |
| atk_finisher | 2 2 2 1 1 = 8 | 9 | início |
| atk_flurry | 1 2 1 1 1 = 6 | 7 | início |
| atk_claw | 2 2 1 1 1 = 7 | 8 | início |
| shout | 2 2 1 1 1 = 7 | 8 | início |
| cast | 2 2 1 1 1 = 7 | 8 | início |
| cast_buff | 2 1 1 1 1 = 6 | 7 | início |
| cast_ground | 2 2 2 1 1 = 8 | 9 | início |
| cast_channel | 1 1 1 1 1 = 5 | 6 | início (tremor pequeno nas mãos: candidato) |
| cast_target | 2 2 1 1 1 = 7 | 8 | início |
| summon | 2 2 1 1 1 = 7 | 8 | início |
| cast_fire / cast_bolt / cast_holy / cast_nature | 2 2 1 1 1 = 7 | 8 | início |
| cast_ice | 2 1 1 1 1 = 6 | 7 | início |
| cast_shadow | 1 1 1 1 1 = 5 | 6 | início (de lado quase não lê: candidato) |
| buff_power | 2 2 1 1 1 = 7 | 8 | início |
| buff_guard | 1 1 2 1 1 = 6 | 7 | início |
| buff_focus | 1 1 1 1 1 = 5 | 6 | início (candidato) |

### Monstros humanoides (bandidos, elfos, esqueletos, lich, guarnição da Aurora, carniçais, cultistas: 35 modelos)

Usavam os clipes v1 de `chibi_kit.animate()` (3 chaves por osso): golpe de cima sem preparo e que começava fora do repouso,
arqueiro dando machadada de mão vazia, morte com a cabeça afundada. Agora `chibi_kit.mob_clips` gera o jogo do kit (v3) e
guarda só os 7 clipes de bicho: `attack` = golpe da família da arma (`MOB_ATTACK`: 1 mão, adaga, par de armas, 2 mãos,
machado/foice em talho, arco, cajado, garras sem arma; lanceiro = estocada) com o impacto movido para o quadro 5
(`_retimed_copy`; `EntityView.IMPACT_FRAME["attack"]`), `idle` da arma (arco baixo / cajado em pé), `block` de escudo.

| clipe | antes | depois |
|---|---|---|
| idle | 1 0 1 0 1 = 3 | 8 |
| run | 1 1 1 0 0 = 3 | 9 |
| attack | 1 0 0 0 0 = 1 | 8 |
| cast | 1 1 0 0 1 = 3 | 8 |
| hit | 1 1 0 0 1 = 3 | 8 |
| die | 2 1 1 0 0 = 4 | 9 |
| block | 1 0 1 0 1 = 3 | 7 |

### Bichos (rig mínimo: lobo, javali, urso, dragão, grifo, lince, cão de ossos, aranha, caranguejo, golem, ent, fantasma, elemental, morcego) e formas do druida

`attack` era genérico para todos: começava com o corpo 10 cm no ar, afundava 25 cm (pernas dentro do chão) e só balançava um
osso de braço que os quadrúpedes nem têm; é também o golpe básico das formas Lobo/Urso. `hit` = 1 osso 15°. `die` = giro de
85° em volta do eixo de pé (o bicho gira no lugar e afunda). Agora:

- `mob_kit.quad_combat` (quadrúpedes e formas): mordida com bote (recolhe de cabeça erguida, crava, sacode), javali com
  presas para cima, urso com patada em gancho; tranco com cabeça, rabo encolhido e patas escorregando; morte que gane, dobra
  as patas da frente, rola de lado com as patas duras e quica (urso/javali mais devagar).
- `build_monsters.combat_actions` (o resto): bote com os dois braços, tranco com braços, morte que cede e tomba de cara
  (de lado para aranha/caranguejo) ou, para quem flutua, estremece, gira e despenca.
- `build_monsters.mob_actions`: idle que respira e olha em volta com os braços vivos; passo com pernas e braços alternados
  (golem e ent deslizavam com as pernas paradas); quem flutua inclina e arrasta os braços; trote em diagonais (aranha).

| clipe | antes | depois |
|---|---|---|
| attack (quadrúpede / forma) | 0 0 0 0 1 = 1 | 8 |
| hit (quadrúpede) | 1 0 0 0 1 = 2 | 7 |
| die (quadrúpede) | 0 0 0 0 1 = 1 | 8 |
| attack / hit / die (outros bichos) | 1 / 1 / 1 | 7 / 7 / 7 |
| idle (outros bichos) | 1 0 0 0 1 = 2 | 6 |
| run (golem, ent, elemental, fantasma, morcego) | 1 1 0 0 1 = 3 | 7 |
| idle / run (quadrúpedes, `quad_motion`) | 6 / 8 | 7 / 10 (costura) |
| maul / pounce / slam / roar / brace (formas) | 8 | 9 (início) |

## O que ficou

- Candidatos do próximo laço: `atk_charge` (pose parada durante a investida), `cast_channel` (tremor pequeno),
  `cast_shadow` e `buff_focus` (de lado quase não leem), `block` sem escudo (estático).
- Cavalo, slime e larva têm clipes próprios e não mudaram (só a costura).
- O fade de 0,06 s para preparo a 2,2x ainda dá ~90-100°/quadro em arco contínuo (não é tranco).
