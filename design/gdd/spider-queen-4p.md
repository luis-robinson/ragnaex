# Rainha Aranha com 4+ pessoas

Status: Implementado (opção B, escolhida pelo usuário como "a recomendada por enquanto", 2026-11-12). Dono: world-builder.
Relaciona: `docs/DESIGN.md` (Chefes: "Reforço extra por chefe", "Sonda com o código final"), `data/catalog/monsters_catalog.gd`
(`spider_queen`, `web_cocoon`), `core/sim/systems/mob_system.gd` (`crowd_mult`, `update_boss`, `cocoon`).

## Problema

Com 4 sorteados a Rainha ficava em 80-82,5% de vitórias e parou de responder a mais dano (`BOSS_CROWD_EXTRA` 1,3 → 1,6 → 1,8).
Alvo 65-85% (mirar ~75%); solo (20-40%) e trio (75-100%) não podem mudar; grupo completo ~100%.

Por que o dano extra satura: o reforço vale por quem está lutando AGORA (`crowd_of` conta só vivos). Com 4 o chefe bate × 3,5 × 1,8
= × 6,3; na 1ª morte o grupo vira trio e o chefe cai para × 2. Mais dano só faz a 1ª morte vir antes e o trio que sobra (90-100% de
vitória no trio) termina a luta. As derrotas que restam são os grupos que se desfazem nos primeiros segundos (sem cura / sem tanque).
Qualquer resposta que dependa de "estar com 4 agora" tem o mesmo teto: a mecânica precisa valer pela luta inteira de quem a abriu com 4.

## Opções

### A. Bolsas de ovos (lacaios por multidão)
A partir de 4, cada fase põe também 2 bolsas de ovos paradas longe do tanque; se não forem quebradas em 8 s chocam 4 filhotes cada.
- Pró: puxa dps para fora do chefe; leitura clara; usa `summon`.
- Contra: precisa de lacaio parado com relógio próprio (sistema novo); os bots já tiram lacaio que bate em quem cura (`_peel_target`),
  mas bolsa parada não bate em ninguém: ou os bots a ignoram sempre (vira dano puro dos filhotes) ou precisam de regra nova. Na luta de
  ~27 s as fases passam rápido: 2-3 levas, quase o mesmo efeito do `summon` atual (que não mudou o resultado).

### B. Casulo de Seda (recomendada)
A partir de 4 (pico da luta, `crowd_peak`), a Rainha ganha "Casulo de Seda": envolve um membro frágil (curandeiro/conjurador/atirador;
senão o mais longe; `mob_pick: "soft"`) num casulo. A vítima fica presa (atordoada) até o casulo ser quebrado; se ninguém quebrar em
7 s o casulo aperta e tira 45% da vida máxima. O casulo é um lacaio da Rainha (conta para o escudo `ward` da fase 2). Bots que não são
tanque nem curandeiro atacam o casulo de um aliado.
- Pró: castiga quem ignora (curandeiro preso = grupo sem cura; 45% de vida), tira dps do chefe mesmo quando respondem, e vale pela luta
  inteira (`crowd_peak`): a 1ª morte não desliga a mecânica. Genérico (`MonsterDef.crowd_skills`): serve a outros chefes (Rei Élfico).
- Contra: efeito novo (`cocoon`) e uma regra de bot; um lacaio novo sem modelo próprio (forma `sphere` branca).

### C. Chuva de teia na retaguarda
A partir de 4, "Chuva de Bile" vira chuva de teia mirando a retaguarda (`mob_pick: "far"`, raiz + dano).
- Pró: só dados (skill nova + `crowd_skills`); pressiona quem fica longe.
- Contra: os bots fogem de círculo avisado (`barrage`) muito bem: é dano evitável, não muda quem perde; mesma família da Chuva de
  Bile que a Rainha já tem.

## Recomendação

B. É a única que muda a luta em vez de somar dano, castiga a composição que ignora (sem dps livre para quebrar, curandeiro preso) e,
gatilhada pelo pico de pessoas da luta, não some na 1ª morte, que é exatamente o motivo de o multiplicador ter parado de responder.
Com a mecânica carregando a dificuldade, o `BOSS_CROWD_EXTRA` da Rainha volta a ser calibrado (descer se a taxa cair abaixo de 65%).

## Números

| Item | Valor | Onde |
|---|---|---|
| Liga a partir de | 4 pessoas no pico da luta (`Balance.BOSS_CROWD_EXTRA_FROM`) | `MobSystem.update_boss` |
| Skill `mob_cocoon` | alvo, alcance 14 m, recarga 13 s, preparação 0,7 s, `mob_pick: "soft"`, poder 0,3 | `skills_catalog.gd` |
| Casulo (`web_cocoon`) | vida 2200, def 8, não anda, não ataca | `monsters_catalog.gd` |
| Prisão | 7 s ou até o casulo cair | efeito `cocoon.duration` |
| Aperto (ninguém quebrou) | 45% da vida máxima da vítima | efeito `cocoon.burst` |
| Reforço de dano 4+ | ver tabela final em `docs/DESIGN.md` | `Balance.BOSS_CROWD_EXTRA` |

## Aceitação

- 4 sorteados (2 sementes × 20 = 40 lutas): 65-85%, mirando ~75%.
- Solo (20 lutas) 20-40% e trio (20 lutas) 75-100%: sem mudança (o casulo nunca aparece com menos de 4).
- Completo (Guardião, Sacerdote, Executor, Fogo; 20 lutas): ~100%, mortes baixas.
- Checks: `crowd_skills` só entram com pico ≥ 4; solo/trio sem casulo; casulo prende, quebrar solta, tempo esgotado aperta;
  reset tira a skill.
