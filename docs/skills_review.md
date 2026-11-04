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

## Pendências conhecidas
- Flecha física ainda leva o rastro branco de partículas do tema "physical" (fica bonito, mas lê como magia leve).
- Bancada mostra só a câmera do jogo (a vista de lado do plano não foi feita: a do jogo é a que importa).
