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
5. **(2026-11-26) Elenco dos 6 chefes de mundo** (modelo novo cada; montaria que dá em `mvp-premios.md`):

| Faixa | Zona | Chefe | Montaria |
|---|---|---|---|
| 1-10 | Vale de Aldara | Javali Ancestral | Javali de Guerra |
| 10-20 | Floresta élfica | Alce Ancião de chifres de cristal | Alce do Bosque |
| 20-30 | Ruínas / Aurora | Basilisco das Ruínas | Lagarto das Ruínas |
| 30-40 | Estepe / Porto | Rinoceronte de Guerra da Horda | Rinoceronte Couraçado |
| 40-45 | Kharzun | Lobo-Rei de Ferro (lobo gigante de armadura) | Lobo de Ferro Couraçado |
| 45-50 | Lumeria | Gamo de Porcelana da Festa | Gamo de Porcelana |

## 10. Chefes de mundo: números (2026-11-26, dados; nascimento/anúncio/prêmios = onda 5)

Dados em `MonstersCatalog.WORLD_BOSSES` / `_world_bosses()` (lugar provisório = clareira com 13 m livres, o da sonda) e
`SkillsCatalog._world_boss_skills()` (`mob_wb_*`). Só para teste até a onda 5: `-- --autostart=<classe> --world_boss=<id>`
(nasce a 12 m) ou `--world_boss_shot=<pasta>` (fotos da luta e da assinatura). Check `_check_world_boss_data`.
Todos: chefe de verdade no topo da faixa, escala 3,0 (lobo 2,8), 3 fases (70% lacaios + golpe novo, 40% ward 0,5 com lacaios,
15% fúria ×1,3), fúria por tempo aos 330 s, lacaios 0 XP (`wb_*`), uma assinatura de chão avisada (não esquivável pela AGI).

| Chefe | Nv | Vida | ATK | Assinatura (forma) | Outros golpes |
|---|---|---|---|---|---|
| Javali Ancestral | 10 | 210 000 | 44 | Trilha Ancestral: 3 faixas encadeadas que ele corre (cortejo), atordoa 0,8 s | presa em cone, pisão lento, disparada no longe, vara |
| Alce Ancião | 20 | 600 000 | 76 | Erupção de Cristal: 3 anéis × 2 pulsos (o lugar seguro anda), prende 1,2 s | galhada, galope, chuva de lascas, bramido (empurra), manada |
| Basilisco das Ruínas | 30 | 1 200 000 | 125 | Olhar que Petrifica: faixa de 10 × 30 m, 2 s de aviso, atordoa 2,5 s | mordida venenosa, cauda (atordoa), bote, cuspe ácido (poça), estátuas |
| Rinoceronte de Guerra | 40 | F2 chefe ×22 (≈3,27 M) | F2 ×0,95 (≈133) | Atropelo da Horda: 3 faixas paralelas em sequência, atordoa 1 s | chifrada, investida, pisão, Tambores (grito +20% ATK/vel. de ataque na Horda), lanças, guerreiros |
| Lobo-Rei de Ferro | 45 | F2 chefe ×10 (≈1,78 M) | F2 ×0,9 (≈144) | Marca da Caçada: 3 marcas que seguem (nunca o tanque) e explodem: espalhar | garra (sangra), salto no longe, queda de ferro (atordoa), uivo da alcateia |
| Gamo de Porcelana | 50 | F2 chefe ×18 (≈3,73 M) | F2 ×0,78 (≈140) | Clarão das Lanternas: ilhas de luz (mín. 4, 3,5 m); fora delas leva o golpe | galhada, deslize, cascos (atordoa), lanternas que caem, convidados |

Sonda: `boss_probe.tscn -- --party=8 --boss=<id> --trials=20` (8 bots do nível, uma classe de cada; grupo de 5 + 3 soltos;
`BOSS_CROWD_MULT` para em 5). Alvo: 70-85% de vitórias, luta de 3-5 min.

| Chefe | Vitórias | Tempo médio (vitórias) | Mortes/luta | Situação |
|---|---|---|---|---|
| Javali Ancestral | 16/20 (80%) | 170 s | 0,7 | no alvo |
| Alce Ancião | 11/20 (55%) | 284 s | 4,5 | abaixo do alvo (aberto) |
| Basilisco das Ruínas | 16/20 (80%) | 251 s | 4,4 | no alvo |
| Rinoceronte de Guerra | 5/20 (25%) | 240 s | 6,2 | muito abaixo (aberto) |
| Lobo-Rei de Ferro | 14/20 (70%) | 173 s | 2,3 | no alvo (limite de baixo) |
| Gamo de Porcelana | 10/20 (50%) | 183 s | 3,8 | abaixo do alvo (aberto) |

Abertos: Alce, Rinoceronte e Gamo ainda difíceis demais para 8 bots (o lugar de nascer mudou na última rodada e mexeu muito
no resultado: o Rinoceronte foi de 6/8 a 6/20 só com a troca de lugar). Próximo passo: medir com `--why` qual golpe mata
(suspeitos: Tambores + Atropelo no Rinoceronte, Ilhas no Gamo para 8 pessoas, Bramido/anéis no Alce) antes de mexer em vida/ATK.
