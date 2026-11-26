# Momentos do Mundo — chefes de mundo e cadeias de eventos

> Status: **APROVADA PARA IMPLEMENTAR** (2026-11-25, revisão de diversão). Nada implementado. Decisões do usuário em §9.
> Prêmios do Chefe de Mundo: `mvp-premios.md`.
> Já existe: eventos de estrada (`RoadEventSystem`), investidas (`RaidSystem`), Cerco Vivo (`SiegeSystem`), conquista dos fortes (`WorldState`).

## 1. Overview

Dois tipos de momento que o servidor inteiro sente:
1. **Chefe de Mundo (MVP)**: um chefe grande nasce num lugar fixo de uma zona, o anúncio sai para todos os mapas, e os
   bots da faixa **vão até lá** e lutam junto com você. É a "raide aberta" do Erenshor/Ragnarok.
2. **Cadeias de eventos** (lição do Guild Wars 2): o resultado de um evento decide o próximo e muda a zona por um tempo.
   Ex.: a caravana chega → a feira abre na praça (lojas com desconto, 15 min); a caravana cai → os bandidos montam um
   acampamento na estrada (novo chefe pequeno, 15 min) até alguém desfazer.

## 2. Player Fantasy

"Todo mundo largou o que estava fazendo." O chat explode, a estrada enche de bots correndo para o mesmo lugar, e a luta é
uma bagunça boa de 15 pessoas. E: "o que eu fiz mudou o mapa", mesmo que por pouco tempo.

## 3. Detailed Rules

**3.1 Chefe de Mundo.**
- Um por faixa (1-10, 10-20, 20-30, 30-40, 40-45, 45-50), em lugar fixo da zona (ex.: o Javali Ancestral na Campina).
- Nasce a cada `WORLD_BOSS_EVERY` min de jogo (± sorteio), com aviso 2 min antes ("Os chãos da Campina tremem...")
  no chat de todos os mapas e marca no mapa grande.
- Bots da faixa (no mapa ou a 1 portal) vão até lá; a luta escala com quem está lutando (`BOSS_CROWD_MULT`, já existe).
- Prêmio por participação (como o GW2): todo mundo que bateu ou curou o bastante ganha XP + 1 sorteio de saque;
  o golpe final não importa. A Carta de Chefe dele (ver `cartas.md`) tem chance própria.
- Some em `WORLD_BOSS_LIFE` min se ninguém o matar (fala de despedida).

**3.2 Cadeias.** Uma cadeia é uma lista de **passos**; cada passo é um evento que já existe (escolta, defesa, chefe,
coleta) com dois desfechos. O desfecho liga uma **marca de mundo** por um tempo (`WorldState` com prazo), e a marca muda:
spawners, NPCs, lojas, falas dos bots, música. Começar com **3 cadeias** (uma por zona do Ato I):
- Campina: Caravana do Tobias → chegou: Feira (lojas -15%, NPC de jogo de sorte) / caiu: Acampamento Bandido (mini-chefe).
- Floresta: Fogo na Mata → apagado a tempo: Clareira Florida (colheita dobrada) / não: Mata Queimada (monstros de fogo).
- Ruínas: Ritual dos Cultistas → interrompido: Altar Calado (bênção na zona) / completo: Noite Longa (mortos-vivos ×1,5, chefe de mundo antecipado).

**3.3 Leitura.** Todo momento tem: anúncio no chat, marca no minimapa e no mapa grande (cor dos eventos, já existe),
contagem no HUD enquanto a marca vale, e fala dos NPCs da zona.

## 4. Formulas

- Nascimento: `próximo = WORLD_BOSS_EVERY × (0,8 + 0,4 × rng)` min de jogo, só com o jogador no ato daquela faixa.
- Participação: ganhou prêmio se `dano_ou_cura ≥ WORLD_BOSS_SHARE_MIN × vida_do_chefe / participantes`.
- Cadeia: cada passo dispara com chance `CHAIN_STEP_CHANCE` a cada `CHAIN_TICK` min, só um passo ativo por zona.
- Marca de mundo: dura `CHAIN_MARK_MIN` (15) min de jogo.

## 5. Edge Cases

- Jogador fora da faixa (alto): pode ir; ganha XP reduzida pela regra de nível que já existe.
- Chefe de mundo ao mesmo tempo que investida/cerco no mesmo mapa: o chefe espera o fim do cerco.
- Save no meio de uma marca de mundo: a marca continua com o tempo que faltava.
- Mapa sem o jogador: a cadeia não anda (como o relógio do `RaidSystem`).

## 6. Dependencies

`MobSystem` (spawn/escala do chefe), `BotBrain` (ir ao chefe, comemorar), `RoadEventSystem`/`RaidSystem` (passos de cadeia),
`WorldState` (marcas com prazo), `LootSystem` (prêmio por participação), `Music` (tema de chefe), `hud`/`Minimap`,
`cartas.md` (Carta de Chefe), `bots-com-memoria.md` (saída de guilda).

## 7. Tuning Knobs

`WORLD_BOSS_EVERY` (sugestão 40 min), `WORLD_BOSS_LIFE` (15 min), `WORLD_BOSS_SHARE_MIN`, `CHAIN_STEP_CHANCE`, `CHAIN_TICK`,
`CHAIN_MARK_MIN`, vida/dano de cada chefe de mundo (calibrar com `boss_probe --party=8`).

## 8. Acceptance Criteria

- Anúncio chega no chat de todos os mapas e a marca aparece no mapa grande (check + foto).
- Em 10 lutas simuladas, ≥ 6 bots da faixa chegam antes do chefe cair (sonda).
- Todos os participantes acima do mínimo ganham prêmio; quem não bateu, não (check).
- Cada cadeia muda o que diz que muda (spawners, lojas) e volta ao normal no fim do prazo (check).

## 9. Decisões do usuário (2026-11-25)

1. **Chefe de mundo a cada ~40 min** de jogo (`WORLD_BOSS_EVERY` = 40, ± sorteio de §4).
2. **Uma cadeia piloto primeiro**: Campina (Caravana do Tobias → Feira / Acampamento Bandido); Floresta e Ruínas depois do teste.
3. **Prêmio igual para todos** os que passaram de `WORLD_BOSS_SHARE_MIN` (dano ou cura); sem bônus de top 3.
4. **(2026-11-26) Seis chefes de mundo NOVOS**, um modelo próprio no Blender por faixa (com mecânica própria e a montaria temática de `mvp-premios.md`).
