# Revisão de skills (bancada `game/dev/showcase.gd`)

Critérios (0–2 cada, passa com ≥ 8): **pose** (o movimento conta o que a skill faz), **tempo** (golpe/efeito no quadro do
dano), **forma** (o efeito desenha a hitbox real), **identidade** (dá pra saber o tema sem ler o nome), **retorno** (acerto lê bem).
Gerar: `.\tools\godot.ps1 --path . -- --showcase=<classe> --out=<pasta>` → folhas por skill + `<classe>_pagina_N.png`.

## Iterações (amostra: elementalista + paladino; depois todas as classes)

| It. | O que mudou | Nota média (amostra) |
|---|---|---|
| 0 | Base: efeitos genéricos por forma de mira (anel/pilar/caixa), 13 clipes por arma | ~4 / 10 — tudo da mesma cor, feixe-caixa, sem tema, Martelo de Luz = tela branca |
| 1 | `SkillDef.vfx` (15 temas por palavra no id) + `SkillFx`: leque no ângulo real, círculo do raio, faixa da largura, partículas do tema, aura de buff, projétil com rastro do tema | ~6 — partículas quadradas, flash estourado, coluna sagrada cobria a tela |
| 2 | Partículas com sprite redondo, luzes mais fracas, coluna baixa/transparente, retículo escondido na bancada, foco entre quem lança e o alvo | ~7 — meteoro caía fora do quadro, fogo sumia em chão claro, raio só caía do céu |
| 3 | Explosão de fogo (bola que cresce, mistura normal), meteoro começa a cair na preparação e bate no quadro do dano, raio em corrente mão→alvo→vizinhos | ~8 |
| 4 | 8 clipes novos no kit (`cast_ground`, `cast_channel`, `cast_target`, `atk_leap`, `atk_charge`, `atk_throw`, `atk_shoot_multi`, `summon`; poses resolvidas no rig) + escolha do clipe pela forma da skill; salto visual em arco; flecha/lâmina girando nos projéteis físicos | ~8,5 |
| 5 | Todas as 8 classes (170 skills): corrigidos Chute (usava clipe de leque do arco) e Recuar (usava investida pra frente) | todas ≥ 8 na revisão das páginas |

| 6 | 14 clipes por família (elemento, buff por intenção, varrida, finalizador, rajada, garras, grito) e tempo em duas fases (preparo e recuperação) | ~5 / 10 — cabeça dobrava e o giro escondia a arma |
| 7 | `_tame` no construtor de clipes: limita tronco e a cabeça compensa, em todos os golpes | ~7 / 10 |
| 8 | Rajada, fogo e foco refeitos; filmados de lado e de frente; 170 skills lançadas sem erro | ~8 / 10 |

| 9 | Auditoria 2026-11 (abaixo): Combustão refeita, 2 skills novas do Guardião, 12 consertos de clipe/tema/números, efeito no alvo de verdade, marca no alvo durante o preparo, rastro do cajado na cor da magia | ~8 / 10 (as consertadas) |

## Auditoria 2026-11 (bancada `--showcase=all` + `tools/tests/skill_audit.tscn` + `combat_probe`)

Números: `skill_audit` compara poder efetivo por recarga (power + dano no tempo/20 + controle; área ×1,5; canalização × pulsos)
com a mediana das irmãs da mesma classe a ±6 níveis; WEAK = abaixo de 60%. Visual: folha de 8 quadros de cada skill.

**Encontradas (pior primeiro)** e o que foi feito:

| Skill | Problema | Conserto |
|---|---|---|
| `ele_combustion` Combustão | Preparo de 0,15 s (o clipe começava no meio, "sem animação"), efeito = faísca amarela no CURSOR, não no alvo; 1 alvo, só dano + queimadura | Preparo 0,3 s com marca no alvo (aro laranja que fecha, brasas, núcleo crescendo), explosão de 2,6 m no alvo (bola + coluna + tremor), detona as SUAS queimaduras nos atingidos (125% do restante, número ✦ laranja + explosão pequena) e reacende o fogo em todos (efeito `combust`) |
| `dru_moonfire` Fogo Lunar | A palavra "fire" no id dava tema fogo: bola de fogo laranja e a queimadura laranja (contava como fogo) | Tema lunar (regra lunar antes da de fogo): violeta, dano no tempo comum |
| `ber_leap` Salto Selvagem | Preparo 0,12 s escolhia o clipe de investida rasteira (sem salto) e poder 48% das irmãs | Preparo 0,2 s → clipe de salto; poder 1,5 → 1,9 |
| `ber_twin_fang` Presas Gêmeas | "fan" dentro de "fang" mandava para o clipe de arremesso | `clip: atk_flurry` (campo novo `SkillDef.clip`), tema sangue |
| `pal_twin_slash` Arco Radiante | "twin" mandava para rajada de adaga com montante; tema aço | `clip: atk_sweep`, tema sagrado |
| `pal_blade_dance` Giro do Cruzado | "dance" mandava para rajada em vez de giro | `clip: atk_spin`, tema sagrado |
| `ran_mine` Mina Explosiva | Plantar mina com o clipe de tiro de mosquete | `clip: atk_throw` |
| `bis_hammer` Martelo de Luz | "Martelo cai no alvo" era só uma coluna; poder 55% das irmãs | Preparo 0,25 s com marca, martelo de luz caindo do céu no quadro do dano; poder 2,0 → 2,3 |
| `ber_warcry` Grito de Guerra (nv 20) | 0,4 de poder, 18% das irmãs | Poder 1,4, raio 4,5, recarga 20 s, +20% ATK por 8 s em você |
| `nec_harvest` Colheita Sombria (nv 20) | 54% das irmãs | Poder 2,6 → 3,4, recarga 22 → 18 s |
| `ele_frost_nova` Nova de Gelo | 44% das irmãs | Poder 1,1 → 1,5 |
| `ele_static` Campo Estático | 54% das irmãs | Poder 1,4 → 1,8 |
| Todas TARGET | O efeito saía no cursor (quem mira um pouco ao lado via a explosão no chão vazio) | `skill_effect` sai na posição do alvo escolhido |
| Magias TARGET | Nada no alvo durante o preparo | Marca do tema no alvo (`SkillFx.brand`) |
| Magias com cajado/cetro | Rastro branco de "lâmina" no gesto da magia | Rastro na cor do tema (`KitModel.trail_tint`) |

**Fracas de propósito (utilidade; ficaram)**: `ass_shadowstep`, `ass_smoke`, `nec_curse_weakness`, `nec_curse_doom`, `ran_net`, `ran_anchor`,
`ass_paralyze`, `dru_entangle` (controle/mobilidade), `pal_shield_bash`, `ber_blade_rush`, `dru_pounce` (aproximação).

**Novas**: `pal_shield_throw` Escudo Ricochete (escudo voa, ricocheteia em 3, provoca, interrompe, volta; a mão fica vazia enquanto voa) e
`pal_bastion_aura` Aura do Bastião (liga/desliga: anel no pé, onda até 12 m ao ligar; aliados no raio ganham o anel também; pulso de luz
de 1 s em quem está a 3,5 m, faísca dourada no atingido). A bancada agora limpa invocações e buffs entre skills (o lince fica).

**Ainda fracas no visual (próximas)**: a maioria das skills com preparo padrão de 0,15 s mostra o impacto no 2º quadro (pouca antecipação),
físicos de tema "aço" ainda são o leque branco genérico, `dru_moonfire` tem retorno pequeno no acerto.

## Pendências conhecidas
- Flecha física ainda leva o rastro branco de partículas do tema "physical" (fica bonito, mas lê como magia leve).
- Bancada mostra só a câmera do jogo (a vista de lado do plano não foi feita: a do jogo é a que importa).

## Supremas da onda B1 (2026-11-19) — bancada `--showcase=<classe> --skill=<id>` (nível 40, ascensão, carga cheia)
Folhas em `production/qa/evidence/ultimates/<classe>/<id>/`. Nota: pose, tempo, forma, identidade, retorno (0-2 cada; passa com ≥ 8).

| Suprema | 1ª volta | Final | O que mudou entre as voltas |
|---|---|---|---|
| `pal_ult_dawn_bastion` Bastião da Aurora | 6 (1/2/1/1/1) | 8 (1/2/2/2/1) | estandarte de luz fincado (dura a Proteção), onda até 8 m, coluna, fios até o grupo |
| `pal_ult_dawn_judgement` Juízo da Alvorada | 9 (2/2/2/2/1) | 9 | — (salto + 3 golpes do montante + coluna sagrada + estrelas do atordoar) |
| `pal_ult_hammer_sky` Céu de Martelos | 9 (2/2/2/2/1) | 9 | — (8 martelos girando a 4 m, marca roxa nos atingidos) |
| `ber_ult_blood_feast` Festim de Sangue | 5 (1/2/0/1/1) | 8 (1/2/1/2/2) | explosão de sangue em pé + coluna vermelha (nada vermelho no chão) |
| `ber_ult_headsman_verdict` Veredito do Carrasco | 7 (2/2/1/1/1) | 8 (2/2/2/1/1) | fenda de 3,5 m em volta do alvo (tema terra) + sangue no impacto |
| `ber_ult_seven_winds` Sete Ventos | 8 (1/2/2/2/1) | 8 | — (some e reaparece em cada golpe, rastro de vento) |
| `bis_ult_grace_dome` Cúpula da Graça | 8 (1/2/2/2/1) | 8 | — (a cúpula da Barreira, maior e parada) |
| `bis_ult_judgement_sun` Sol do Julgamento | 9 (1/2/2/2/2) | 9 | — (raio de sol, chão aceso, atordoar) |
| `bis_ult_faith_avatar` Avatar da Fé | 8 (1/2/2/2/1) | 8 | — (martelo de luz em volta, auréola, boneco ×1,25) |
| `dru_ult_primal_colossus` Colosso Primevo | 9 (2/2/2/2/1) | 9 | — (urso ×1,5 com a pele de casca do tema) |
| `dru_ult_blood_moon` Garras da Lua Rubra | 6 (1/2/1/1/1) | 8 (1/2/2/1/2) | tema `lunar` no lugar de `blood`: os círculos dos saltos eram vermelhos no chão (cor de aviso de chefe) |
| `dru_ult_elder_heart` Coração do Bosque Ancião | 6 (1/2/1/1/1) | 8 (1/2/2/2/1) | a árvore ancestral brota no ponto e fica os 12 s; Fogo Lunar sai dela até cada alvo |

Pendências: o Festim não mostra o fechamento (a Sangria sai aos 10 s, fora da folha de 2,4 s); a pose das SELF é o clipe comum
(`buff_power`/`shout`); a Lua Rubra usa o clipe do lobo, sem um salto próprio.

## Supremas da onda B2 (2026-11-19) — bancada `--showcase=<classe> --skill=<id>` (nível 40, ascensão, carga cheia)
Folhas em `production/qa/evidence/ultimates/<classe>/<id>/` (`final.png`; `v1.png` = 1ª volta quando mudou). Nota: pose, tempo,
forma, identidade, retorno (0-2 cada; passa com ≥ 8).

| Suprema | 1ª volta | Final | O que mudou entre as voltas |
|---|---|---|---|
| `ran_ult_wild_bond` Laço Selvagem | 9 (1/2/2/2/2) | 9 | — (o lince volta ×1,4 com o brilho verde; o espiritual em fumaça) |
| `ran_ult_end_shot` Disparo do Fim | 6 (0/2/1/1/2) | 8 (1/2/1/2/2) | a mira segura o quadro do tiro (o clipe se arrastava na mira de 1,2 s e terminava antes do disparo); rastro do tiro até 30 m |
| `ran_ult_endless_lance` Lança Incansável | 6 (1/2/1/1/1) | 8 (2/2/1/2/1) | `atk_thrust` em laço na fase ativa (era `atk_flurry`: talhos largos e depois parado) |
| `ass_ult_royal_toxin` Toxina Real | 6 (1/2/1/0/2) | 8 (1/2/1/2/2) | marca do `dot_amp` sobre o alvo (garras verdes girando ao contrário) |
| `ass_ult_grand_duel` Duelo Supremo | 6 (1/2/1/1/1) | 8 (1/2/2/2/1) | leque prateado da guarda (140°, alcance da resposta) no chão, virando com o duelista |
| `ass_ult_fleet_call` Chamado da Frota | 7 (1/2/1/2/1) | 9 (1/2/2/2/2) | a bala de canhão cai do céu e chega com o golpe (vale também para a Chuva de Meteoros) |
| `ele_ult_eternal_winter` Inverno Eterno | 8 (1/2/2/2/1) | 8 | — (pulsos de gelo, anel de frio e o floco do congelar) |
| `ele_ult_storm_eye` Olho da Tempestade | 6 (1/2/1/1/1) | 9 (1/2/2/2/2) | raio que cai do céu em cada golpe (antes só um anel no chão) |
| `nec_ult_tide_of_dead` Maré dos Mortos | 9 (2/2/2/2/1) | 9 | — |
| `nec_ult_soul_reaping` Ceifa das Almas | 8 (2/2/1/1/2) | 8 | — |
| `nec_ult_void_eclipse` Eclipse do Vazio | 7 (1/2/1/2/1) | 8 (1/2/2/2/1) | disco escuro do vazio no chão pela duração (quase preto: não lê como aviso de chefe) |

Pendências: as folhas de 2,4 s não mostram os fechamentos (Golpe de Mestre do Duelo aos 6 s, implosão do Eclipse aos 8 s,
explosão dos esqueletos aos 20 s); as SELF usam os clipes comuns (`shout`/`buff_power`); a arma do Disparo fica escondida
atrás da cabeça chibi quando ele mira para o norte (câmera do jogo).
