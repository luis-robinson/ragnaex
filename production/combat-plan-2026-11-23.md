# Plano de combate — 2026-11-23

Fontes: `production/qa/combat-best-practices-2026-11-23.md` (boas práticas, 15 critérios) e
`production/qa/combat-audit-2026-11-23.md` (estado atual medido). Status: **APROVADO 2026-11-23** com as decisões abaixo.

## O que já está bom (não mexer)
- Resposta: combat_probe 0 FLAG nas 24 builds, latência 0 tick, buffer 0,25 s, dash cancela, encadear só no impacto.
- Animação: 0 emendas de laço > 15°, 0 clipes congelados; arcos de golpe por família de arma com hit-stop local.
- Avisos de chefe: gramática de cor, assinaturas ≥ 1,5 s, chão avisado não esquivável.

## Pacotes (ordem por impacto no jogador)

| # | Pacote | O quê | Tipo | Decisão do usuário? |
|---|---|---|---|---|
| A | **Acessibilidade** (EM ANDAMENTO) | tremor 0-100% + ruído suave, modo contraste/daltônico nos avisos, densidade de efeitos dos aliados, intensidade de flash | UI | já aprovado |
| C1 | **Bug: canal cortado pelo básico segurado** | `WorldSim._can_chain` deixa o clique segurado encerrar canais (Mente Açoitada, Drenar Alma, Raio do Vazio, Ciclone do Titã: 1 de 4-6 pulsos). Check que falha primeiro, depois correção | bug | não |
| C2 | **Hit-stop sempre local** | golpe de monstro / golpe sem arco ainda congela o mundo (`Engine.time_scale = 0.05`, fx_manager.gd:290). Tudo local; degraus básico 2 / pesado 6 / teto 12 quadros | feel | não |
| C3 | **Retorno no corpo e no som** | jogador reage a golpe forte (flinch leve, sem perder controle); marca visual de atordoado/enraizado/lento (`BuffLooks`); chefes não tremem a cada golpe (postura); som de impacto mágico por alvo e som de golpe por família de arma | feel | não |
| C4 | **Leitura do chefe** | barra de vida + barra de conjuração do chefe no HUD (no alto da tela, com nome e fase); avisos mínimos para lixo/elite (≥ 0,5 s / ≥ 0,8 s em golpe > 20% da vida) com check | UI/regra | **sim (layout da barra)** |
| C5 | **Equilíbrio de dano entre builds** | dano em alvo único no 45: Raio +156%, Fogo +96%, Gelo +66%, Inquisidor +58% … Fera -35%, Invocador -32%, Executor -27%; conjuradores crescem ×3,3 do 30 ao 45, corpo a corpo ×2. Alvo ±25% da mediana (em grupo, regra "group-first") | balanço | **sim (direção)** |
| C6 | **Kits fracos** | Corsário (5 skills 27-48% da mediana, -20% DPS), Predador, Fusão de ascensão, Raízes do Ent, Nova de Gelo | balanço | não (dentro de C5) |
| C7 | **Controle com retorno decrescente** | lentidão/raiz/atordoar repetidos não diminuem hoje | **mecânica nova** | **sim** |
| C8 | **Antecipação** | 66% das skills começam em ≤ 0,15 s (impacto no 2º quadro); 25 skills passam da regra 0,3 s (invocações/áreas grandes) | feel/regra | **sim (política)** |
| C9 | **Animação** | `atk_charge` parado, `cast_channel`/`cast_shadow`/`buff_focus` sem leitura de lado, bloqueio sem escudo parado, `attack` de chefe humanoide gira 68-72°/quadro | arte | não |
| C10 | **Bots** | Cruzado e Templário compram 0 notáveis de papel na teia (`bot_spend`) | IA | não |
| C11 | **Metas de tempo de abate** | escrever e medir TTK de lixo/elite por faixa (hoje só chefes têm alvo) | doc/regra | não |

## Decisões do usuário (2026-11-23)
- C5: **trazer os conjuradores para baixo** (escala 30→45). · C7: **sim, nos monstros** (2ª em 8 s = 50%, 3ª = 25%, depois imune 8 s). · C8: **mínimo 0,2 s nas skills pesadas** + exceção escrita para invocações/áreas. · C4: **barra no topo central do HUD**.

## Decisões (opções apresentadas)
1. **C5 direção do equilíbrio**: (a) trazer conjuradores para baixo (recomendado: o salto ×3,3 é a causa) · (b) subir o corpo a corpo · (c) misto. Medir em grupo (boss_probe) e em alvo único.
2. **C7**: adicionar retorno decrescente de controle (ex.: 2ª aplicação em 8 s = 50%, 3ª = 25%, depois imune 8 s; chefes já têm 40%)? sim / não.
3. **C8 antecipação**: (a) mínimo de 0,2 s nas skills pesadas (dano ≥ 2× básico) + exceção escrita para invocações/áreas · (b) só a exceção escrita, sem mudar tempos.
4. **C4 barra do chefe**: topo da tela centralizada (estilo MMO) ou só a placa sobre a cabeça maior?

## Ordem proposta
Onda 1 (sem decisão): C1, C2, C3, C9, C10 + A (em andamento) · Onda 2 (após decisões): C4, C5+C6, C7, C8 · Onda 3: C11 + revisão independente + exe.
Cada pacote: check que falha antes, combat_probe 0 FLAG, boss_probe sem regressão, smoke, foto/filme quando visual.

## Status (agente combat-core, 2026-11-23)
- **C1 FEITO**: `WorldSim._can_chain` — o básico (segurado ou não) não encadeia no meio de um canal (`channel_done < ticks`); skill/Suprema/dash ainda cortam depois do 1º pulso. Check `_check_channel_hold` falhou antes (4 canais com 1/4-1/6 pulsos) e passa depois.
- **C2 FEITO**: hit-stop sempre local (`FxManager._local_stop` + `WeaponArcs.on_hit_stop`), evento `Events.hit_stop(frames, attacker_id, target_ids)`, degraus `Combat.hit_stop_frames` (básico 2 / pesado e finalizador ≥ 6 / teto 12, `Balance.HIT_STOP_*`). Check `_check_hit_stop_local` (nenhum `Engine.time_scale =` fora do `--speed` de dev).
- **C7 FEITO**: `CcDrSystem` (monstros; `Balance.CC_DR_WINDOW` 8 s, `CC_DR_MULTS` 1/0,5/0,25, depois imune 8 s; ×0,4 do chefe por cima). Check `_check_cc_dr`. boss_probe (4: paladino guardião, bispo sacerdote, elem. gelo, ranger atirador; 40 lutas) com/sem DR: death_knight 40/40 25,4 s vs 24,8 s; lich_king 40/40 34,5 s vs 32,7 s.
