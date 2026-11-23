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
| **block** | 1 1 1 0 1 = 4 | 5 → 7 | costura; 2026-11-23: respira e troca o peso entre os pés (ver "Pacote C9") |
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
| **atk_charge** | 1 1 1 1 1 = 5 | 6 → 8 | início; 2026-11-23: passada de carga no lugar da pose parada (ver "Pacote C9") |
| atk_throw | 2 2 1 1 1 = 7 | 8 | início |
| atk_sweep | 2 2 2 1 1 = 8 | 9 | início |
| atk_finisher | 2 2 2 1 1 = 8 | 9 | início |
| atk_flurry | 1 2 1 1 1 = 6 | 7 | início |
| atk_claw | 2 2 1 1 1 = 7 | 8 | início |
| shout | 2 2 1 1 1 = 7 | 8 | início |
| cast | 2 2 1 1 1 = 7 | 8 | início |
| cast_buff | 2 1 1 1 1 = 6 | 7 | início |
| cast_ground | 2 2 2 1 1 = 8 | 9 | início |
| **cast_channel** | 1 1 1 1 1 = 5 | 6 → 8 | início; 2026-11-23: dois pulsos de corpo inteiro antes do empurrão (ver "Pacote C9") |
| cast_target | 2 2 1 1 1 = 7 | 8 | início |
| summon | 2 2 1 1 1 = 7 | 8 | início |
| cast_fire / cast_bolt / cast_holy / cast_nature | 2 2 1 1 1 = 7 | 8 | início |
| cast_ice | 2 1 1 1 1 = 6 | 7 | início |
| **cast_shadow** | 1 1 1 1 1 = 5 | 6 → 8 | início; 2026-11-23: rasga para a frente e abre em asas (ver "Pacote C9") |
| buff_power | 2 2 1 1 1 = 7 | 8 | início |
| buff_guard | 1 1 2 1 1 = 6 | 7 | início |
| **buff_focus** | 1 1 1 1 1 = 5 | 6 → 8 | início; 2026-11-23: mão livre à frente e arma erguida (ver "Pacote C9") |

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

## Pacote C9 (2026-11-23, plano de combate): os cinco candidatos e o golpe dos chefes humanoides

Números de `anim_probe` (kit_paladin_male; os clipes são os mesmos em todos os kits, na forma demoníaca e nos chefes
humanoides), antes → depois. `giro` = soma do giro dos ossos no clipe (quanto o boneco mexe), `parado` = tempo com tudo a
menos de 0,5° por quadro de 60 Hz, `pico` = maior giro de um osso num quadro de 60 Hz. Duração e IMPACT de todos iguais
(nenhuma das 1800 linhas da sonda mudou de duração). CSVs e filmes em `production/qa/evidence/combat-anim/`
(`probe_before.csv`, `probe_after.csv`, pastas `before/` e `after/`; `film.sh` refaz).

| clipe | giro | parado | pico | o que mudou |
|---|---|---|---|---|
| atk_charge | 973 → 1764° | 0,23 → 0,00 s | 30 → 30° | era a pose `lean` parada do quadro 3 ao 10; agora recolhe com o joelho alto (3), bate de ombro com o braço esticado (5 = impacto), passa do ponto e afunda (7), as pernas trocam e o corpo sobe (10); o tronco torce de um lado ao outro, a cabeça acompanha atrasada, o braço solto vai para trás no impacto |
| cast_channel | 1091 → 3144° | 0,30 → 0,07 s | 29 → 36° | as mãos tremiam 3° no peito (escondidas pela cabeça); agora dois pulsos: encolhe baixo com as mãos no peito e abre os braços para os lados subindo e torcendo, depois empurra (14) e o empurrão ainda cede e volta |
| cast_shadow | 2171 → 2655° | 0,13 → 0,00 s | 31 → 40° | os braços só iam para os lados e para baixo; agora se fecha torcido, as duas mãos rasgam para a frente no impacto (8, com o bote: lê de lado) e abrem alto em asas com o tronco arqueado (lê de frente e de cima) |
| buff_focus | 1791 → 2125° | 0,20 → 0,07 s | 34 → 34° | soltava com os braços colados à cabeça e ao corpo; agora recolhe torcido e baixo e solta destorcendo, mão livre espalmada à frente e arma erguida, na ponta dos pés, e assenta |
| block (sem escudo) | 46 → 256° | laço inteiro → 0,80 s | 0 → 1° | pose parada; agora respira (peito e ombros defasados) e troca o peso entre os pés (quadril vai para o lado e afunda, joelho da frente dobra, tronco torce, cabeça compensa); costura 0,0° |

Golpe (`attack`) dos chefes humanoides de arma larga: o `attack` é o golpe do kit com o preparo encolhido para o impacto cair
no quadro 5 (`chibi_kit._retimed_copy`). Encolhido por igual, o braço da arma varria ~180° em 1,7 quadro. Agora o preparo é
remapeado por trechos (`chibi_kit.MOB_RETIME`, usado por `mob_clips`): o recuo fica mais curto e a descida ganha os quadros.
Impacto no quadro 5 e duração iguais; o pico de velocidade da mão continua no impacto.

| modelo | origem | pico antes | depois |
|---|---|---|---|
| mob_durgash, mob_ghar, mob_orc_warlord, mob_ghoul_giant | atk_sweep, preparo 3,29 → 2,6 e meio do arco 4,43 → 4,0 | 68° | 48° |
| mob_troll_thrower | atk_throw, braço atrás 3 → 2,5 e meio 4,33 → 4,0 (`kharzun_mobs.THROWER_THROW` acompanha) | 72° | 49° |

Ferramenta: `lineup.tscn -- --strip=<classe> --anim=<clipe> --yaw=35 --high` filma o clipe do ângulo da câmera do jogo (52°).

## Pacote C2 (2026-11-23): dez clipes de arquétipo

Gesto próprio por tipo de skill (plano `production/qa/spell-attack-anim-research-2026-11-23.md`, pacote C2). O desenho das
chaves fica em `tools/blender/archetype_clips_solve.py` (tronco e quadril à mão; mãos por alvo de posição + direção da arma
e pés plantados, resolvidos por FK), que grava `archetype_clips_data.py` por sexo; `chibi_kit.animate_archetypes` só lê, fora
do `animate_v3` (monstros e clipes antigos não mudam: as 954 linhas da sonda dos 18 kits saíram iguais, `probe_before.csv` x
`probe_after.csv`). Impactos em `chibi_kit.C2_IMPACT`, kits em `C2_CLASSES`, espelhado em `C2_MIRROR`. Folha de revisão sem
janela (câmera do jogo, lado, frente; impacto em amarelo): `archetype_clips_solve.py -- --dry --shots=<pasta absoluta> [--clips=a,b]`.
Filmes no jogo: `production/qa/evidence/anim-c2/film.sh <tag> [filtro]` (lado, frente e `--yaw=35 --high`).

Números de `anim_probe` (kit masculino da classe): `pico` = maior giro de um osso num quadro de 60 Hz, `parado` = tempo com
tudo abaixo de 0,5°/quadro. Nenhum acima de 36° nem com quadro morto.

| clipe | impacto | fim | kits | pico | giro | parado | gesto |
|---|---|---|---|---|---|---|---|
| cast_heal_nature | 8 | 24 | druid | 25° | 2742° | 0,00 s | ajoelha com o cajado fincado e a mão livre no chão (impacto), aperta, sobe abrindo o braço até o alto na ponta dos pés |
| cast_curse | 8 | 22 | necromancer | 34° | 2483° | 0,00 s | a foice risca o sinal (sobe cruzada, desce), a mão livre em garra dispara com o bote (impacto) e arranca para trás com a foice subindo |
| cast_wind | 9 | 22 | druid, elementalist, ranger | 34° (root) | 2847° | 0,00 s | recolhe baixo torcido, gira o corpo uma volta com os braços abertos subindo, empurra a rajada (impacto) e abre para o alto |
| summon_rise | 11 | 26 | necromancer | 20° | 2462° | 0,03 s | ergue a mão, crava a palma para baixo agachado (foice de pé), puxa devagar do chão; no impacto a mão passa do ombro e o corpo abre para trás |
| summon_call | 9 | 22 | druid, ranger (espelhado), elementalist | 36° | 2591° | 0,00 s | mão em concha na boca tomando ar, lança o braço da arma para o alto e a frente com passo (impacto) e abana chamando; no Ranger a direita assobia e o arco sobe |
| atk_bow_charge | 12 | 24 | ranger | 35° | 1990° | 0,00 s | mira, puxa com a base funda girando de lado, segura tremendo (quadros 8-11), solta (impacto): o arco chuta para cima e o corpo salta para trás |
| atk_pistol_pair | 6 | 20 | assassin | 26° | 2338° | 0,00 s | tiro da pistola (6), troca de ombro e a direita dá a 2ª batida apontando a arma dela (10), a pistola volta e atira de novo (13) |
| atk_pistol_fan | 6 | 22 | assassin | 18° | 1315° | 0,00 s | base baixa, a pistola varre da direita para a esquerda com coices nos quadros 6, 8, 10 e 12, e fecha com o cano para o alto |
| atk_scythe_reap | 8 | 24 | necromancer | 34° | 3261° | 0,00 s | foice atrás à direita com o corpo torcido, passo, varre baixo até a frente (impacto) e segue até atrás do outro lado com o corpo girando; duas mãos no cabo |
| shout_rally | 7 | 22 | todos (inclusive `kit_male`/`kit_female`) | 27-34° | 2123° | 0,00 s | toma fôlego encolhido e ergue a arma como estandarte na ponta dos pés (impacto), acena duas vezes e o braço livre chama o grupo |

Pendências deste pacote:

- `atk_bow_charge` é o mais fraco visto de cima: a cabeça cobre os braços, o que se lê é o corpo afundando/girando e o salto
  para trás ao soltar (o `atk_bow` tem o mesmo limite). O efeito de brilho na corda (pacote V5) é quem deve fechar a leitura.
- `atk_pistol_pair`: o kit tem UMA pistola (`wpn_off_pistol`); a batida da mão direita aponta o sabre. Com uma pistola de mão
  principal no kit o mesmo clipe vira o segundo tiro.
- `atk_pistol_fan` de cima: o tricórnio cobre o braço; lê-se pelo giro do corpo e pelo sabre. Pede clarão de boca por tiro.
- O jogo precisa das linhas em `EntityView.IMPACT_FRAME`/`COIL_FRAME` (ver `chibi_kit.C2_IMPACT`; preparo: quadro 3, e 4 em
  `cast_wind`, `summon_rise` e `shout_rally`): sem elas `_check_clip_routing` falha (15 linhas).

## O que ficou

- `cast_shadow` com arma comprida: a correção de chão da mão dá 50-53° num quadro em `mob_gorbash` e `mob_troll_king`
  (antes 34-39°); abaixo dos 60° da auditoria, mas é o próximo a alisar (a mão vai de "baixo à frente" a "lado alto").
- Picos acima de 60° que não eram deste pacote: `atk_finisher` do kit (64°, braço esquerdo), `mob_flayer atk_sweep` (71°,
  mão), `mob_gorbash atk_leap` (65°, mão).
- `block_shield` (guarda de escudo) continua quase parada de propósito: a montagem dos escudos é medida nela.
- Cavalo, slime e larva têm clipes próprios e não mudaram (só a costura).
- O fade de 0,06 s para preparo a 2,2x ainda dá ~90-100°/quadro em arco contínuo (não é tranco).
