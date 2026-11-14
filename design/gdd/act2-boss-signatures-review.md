# Ato II — Assinaturas dos Chefes: revisão pós-implementação (proposta)

> **Status**: proposta para o usuário · **Autor**: game-designer · **Data**: 2026-11-13
> **Fonte**: `k-sig/design/gdd/act2-boss-signatures.md` § "Implementação" + notas `agent-k-sig.md`, `agent-k-sig2.md`, `agent-k-sig3.md`
> (worktree `k-sig`, ainda em trabalho: Ulgra/Gorbash/Shazka em andamento; Kragmar/Durgash depois do merge do WP8/balanceamento).
> **Uso**: depois do merge de `k-sig` em `k-int`, aplicar no GDD `act2-boss-signatures.md` os itens aceitos (um por linha) e
> apagar este arquivo, ou mantê-lo como registro. Nenhum item aqui muda número de jogo por si só.

Legenda: **ACEITAR** = o código fica, o GDD muda · **CORRIGIR CÓDIGO** = o GDD fica, o código muda · **USUÁRIO** = decisão de design.

## Revisão pós-implementação (proposta)

| # | Onde no GDD | Texto do GDD | Implementado | Recomendação | Por quê |
|---|---|---|---|---|---|
| 1 | 3.2, §6, R-C, AC-S3 | efeito `channel` | `boss_channel` | **ACEITAR** — trocar a chave em 3.2/R-C | `channel` já é a canalização do Necromante; renomear evita colisão no `EFFECT_KEYS`. Puro nome. |
| 2 | AC-S1 | skill marcada `signature` | `SkillDef.boss_signature` | **ACEITAR** — AC-S1 passa a citar `boss_signature` | `signature` já é a magia-assinatura das builds. |
| 3 | 3.6 × AC-S2 / §7 | AC-S2: todo aviso ≥ `BOSS_SIG_WARN_MIN` (1,5 s); 3.6: Três Botes avisam 0,8 s | check usa `BOSS_SIG_REPEAT_WARN_MIN` 0,8 s para `repeat` | **ACEITAR** — AC-S2 ganha a exceção: "sequência (`repeat`): cada bote ≥ `BOSS_SIG_REPEAT_WARN_MIN` (0,8 s); a sequência inteira é anunciada pelo som `sig_warn`". Novo knob em §7 (feel, faixa 0,6–1,2). | O conflito era interno do GDD (3.6 já pedia 0,8). Esquiva em ritmo exige aviso curto; a leitura vem do ritmo e da faixa no chão. Medido: solo 19/20, trio 20/20 — a faixa campo se manteve. |
| 4 | 3.3, R-E, §5 (cobertura com pet), AC-S4 | Pedregulho = lacaio parado, intocável | lista `m["covers"]` (não é entidade), sem colisão; `MonsterDef.cover` = `{radius, time, max, skills}`; a pedra da Chuva nasce no último círculo (o que cai em volta do chefe) | **ACEITAR** — 3.3/R-E: "cobertura = círculo na lista do mapa, não entidade"; §5 acrescenta: "sem colisão: quem fica dentro do círculo também está coberto (a pedra racha mesmo assim)". | Cumpre OQ-3 (intocável) por construção, é mais barato no tick (fora do laço de entidades) e não confunde ameaça/alvo dos bots. Ponto em aberto pequeno: sem colisão, a pedra não "bloqueia" andar — aceitável, a fantasia é abrigo contra a onda, não parede. |
| 5 | 3.5 (Bots) | tanque segura de frente e bloqueia; não-tanques vão para as costas | quem o Ghar **mira** (tanque ou não) fica parado de guarda, sem golpe, durante a Muralha; os outros vão para as costas | **ACEITAR** — trocar a linha "Bots" de 3.5 | Correr para trás fazia o chefe virar para o grupo: luta de 36 s → 55–60 s e 7/20. Com o alvo parado: 32/40 (80%) sorteados. É regra de IA, não de sim: o jogador continua livre. |
| 6 | 3.5 (Aceite) | fúria média ≤ 3 por muralha (grupo de 4) | medido 4,0 (sorteados) e 5,5 (completo) | **ACEITAR com alvo novo** — "fúria média ≤ 6 (contragolpe ≤ 1,9)"; o alvo que manda é a faixa de vitória (AC-S5) | Com o alvo de guarda, o tanque bloqueia de frente e gera fúria de propósito; o contragolpe cai no cone frontal, onde só ele está. O teto 2,5 continua protegendo. Se o usuário quiser a leitura "fúria = erro do grupo", a alternativa é CORRIGIR CÓDIGO: o bloqueio do tanque não soma fúria. |
| 7 | 3.4, §7 | Marca do Atirador `power` 1,5; tique de fogo 0,2 | `power` 0,9, tique 0,15; `unit_mods.atk` Vorgul 1,1 → 0,9 | **ACEITAR** — atualizar o número em 3.4 (já é knob **(K)**) | Com 1,5 o grupo sorteado caía para 8/20 (3,3 mortes) sem erro de posição (aliado atingido 0,01 por marca): o dano punia quem acertava. Final 72,5% (40 lutas). |
| 8 | 3.1 (Bots) | ir à ilha mais perto | não-tanque prefere ilha a ≥ `BOT_SIG_ISLAND_AVOID` (6 m) do chefe | **ACEITAR** — acrescentar à linha "Bots" de 3.1 e o knob em §7 | A ilha do tanque fica embaixo do chefe e leva o golpe em volta; sem isso, 8/20. |
| 9 | §3 (convenção), §7 | assinatura entra com a fase | 1ª assinatura `BOSS_SIG_OPEN_DELAY` 6 s depois do começo, ou `BOSS_SIG_PHASE_DELAY` 4 s depois da fase que a traz | **ACEITAR** — uma frase na convenção do §3 + 2 knobs (feel, 3–10 s / 2–6 s) | Evita assinatura no primeiro tick (o grupo ainda está se posicionando) e casa com "sawtooth": a fase anuncia, depois cobra. |
| 10 | §2, 3.7, §7 `BOT_SIG_SKILL`, AC (Shazka) | bots erram de propósito (Shazka 70%) | bots sempre perfeitos (k-sig3: bot redireciona da cópia para o verdadeiro) | **ACEITAR (já decidido, OQ-4)** — remover "erram às vezes" do §2, "70%" de 3.7 e o knob `BOT_SIG_SKILL` do §7 | Decisão do usuário 2026-11-13. O texto está velho, não o código. |
| 11 | AC-S6, §9 | `sim_probe` ≤ 5 ms/tick | orçamento do projeto é ≤ 10 ms (AC-36 elevado 2026-11-13) | **ACEITAR** — AC-S6 passa a ≤ 10 ms | Decisão do usuário; o GDD de assinaturas foi escrito antes. |
| 12 | AC-S5 | sorteados 65–85% | k-sig calibrou os 5 de fora de Kharzun para **60–80%** (Maré 62,5, Grukk 75, Troll 67,5, Vorgul 72,5, Ghar 80); Kharzun (KAC-10) segue 65–85 | **USUÁRIO** — (a) **AC-S5 = 60–80% para os 11** (recomendado: a assinatura soma dificuldade e foi a faixa que você pediu para Troll/Maré/Pedreira) · (b) manter 65–85 com exceção para Maré e Troll | Hoje o GDD diz 65–85 e a Maré (62,5%) fica fora. (a) dá um alvo só; (b) exige recalibrar Shazka/Ulgra/Gorbash/Kragmar contra outro número. |
| 13 | §6 Dependencies | `mob_system.gd` dono de R-A..R-D | regras em `core/sim/systems/boss_signatures.gd` (`BossSignatures`); vista `game/fx/boss_sig_view.gd`; som `Sfx.SIG_WARN`/`SIG_EFFECT` (`sig_warn`, `drum_tear`); estado `SimEntity.sig`; pedra `prop_avalanche_stone` | **ACEITAR** — atualizar §6 | Sistema próprio segue a regra de ouro (sistema estático por regra). |
| 14 | 3.7 (Shazka, k-sig3) | cópia = `MonsterDef.decoy`; golpe no verdadeiro some as cópias | monstro `shazka_decoy` (`decoy = true`): vida do chefe mas morre com 1 golpe; só golpe **direto** (não dot) no verdadeiro dissipa; a cópia some no próprio tique (`update_decoy`) | **ACEITAR** — 3.7 diz "golpe direto (não dot)"; §5 já cobre o dot | O dot no verdadeiro dissiparia as cópias sem o jogador escolher o alvo — a mecânica perderia o verbo. |
| 15 | 3.8 (Ulgra, k-sig3) | ela recua à borda e galopa a 1ª faixa | faixas `barrage` em linha (2,0 / 2,6 / 3,2 s, largura 3, vão 3, 30 m); o recuo à borda não aparece nas notas | **VERIFICAR no merge** — se o recuo não existe: ACEITAR como só-visual adiado (as faixas carregam a mecânica) | O recuo é fantasia; a regra (faixas + vãos) está implementada e com aviso ≥ 1,5 s. |
| 16 | 3.9 (Gorbash, k-sig3) | 3 pisadas, anéis a cada 0,5 s | anéis com aviso 1,5 s, `stagger` 0,5, `pulses` 3 com 1,2 s entre pisadas, `pulse_shift` 2 m | **ACEITAR** — acrescentar o intervalo entre pisadas (knob) | O GDD não dizia o intervalo entre pisadas; 1,2 s dá a janela "entra-sai". |
| 17 | 3.11 / F-S1 (Durgash, pendente) | exemplo com ATK 240, `power` 6,0 dividido | Durgash mudou depois do GDD: `BOSS_CROWD_RAID` `[1,1,1,2,4,9,3,25]`, berserk ×20, vida em reajuste (alvo ~100 s) | **CORRIGIR antes de implementar** — refazer o exemplo da F-S1 com os números finais do WP8 e calibrar o `power` do Machado do Trono com a raide de 5 ligada | O soak com 3,25 de reforço (não 5,0) pode ficar fraco; com 4 pessoas fica mais duro — coerente com "4 completo tem de perder". |
| 18 | 3.10 (Kragmar, pendente) | Têmpera multiplica em `_apply_fury` | `_apply_fury` passa a juntar `berserk_mult` (WP8) e o multiplicador da assinatura (conflito resolvido no ensaio de merge) | **ACEITAR** — F-S3: "multiplica junto com enrage, berserk (`berserk_mult` por chefe) e crowd" | Só documenta a ordem dos multiplicadores. |

## Resultados medidos (para o GDD § Implementação, já registrados em `docs/DESIGN.md`)

- Sorteados de 4 (40 lutas): Maré 62,5% · Grukk 75% (canais quebrados 92%) · Troll Rei 67,5% (Avalanche 0,10–0,15 atingidos/uso) ·
  Vorgul 72,5% · Ghar 80% · Coração da Pedreira 70% (atk/matk 50 → 66; fora do Ato II, pedido junto). Completo de 4: 20/20 em todos.
- Mãe-Loba (campo): solo 19/20, trio 20/20.
- Depois (k-sig3/4/5): Shazka 70 → **67,5%**, Ulgra 70%, Gorbash 70%, Kragmar 65% (5 sorteados); Vorgul 72,5 → **60%** depois da regra
  "bots saem de toda poça que fica" (na borda). Muralha do Ghar com contragolpe atrasado 0,375 s (`GHAR_COUNTER_DELAY`, clipe
  `wall_counter`). Ver GDD § "Implementação — modelos, clipes e re-sonda".
- Suíte k-sig: 78001 passed / 0 failed; `combat_probe` 0 FLAG; smoke 0 `SCRIPT ERROR`.

## Perguntas para o usuário

1. **AC-S5** (item 12): 60–80% para os 11 chefes **(Recomendado)** ou 65–85% com exceção para Maré e Troll?
2. **Fúria do Ghar** (item 6): aceitar fúria média ≤ 6 **(Recomendado)** ou mudar o código para o bloqueio do tanque não somar fúria?

## Respostas do usuário (2026-11-13)

- AC-S5: faixa **60-80%** (grupo sorteado) para os 11 chefes do Ato II.
- Fúria do Ghar: aceitar média **≤ 6** por muralha (sem mudança de código).
- Plano de commits: arquivo compartilhado entra **inteiro no primeiro tema** que o usa.
- Demais desvios marcados "accept": aceitos como recomendado.
