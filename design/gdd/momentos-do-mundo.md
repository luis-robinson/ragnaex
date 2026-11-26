# Momentos do Mundo — chefes de mundo e cadeias de eventos

> Status: **IMPLEMENTADA (onda 5, 2026-11-26)**: Chefes de Mundo com hora marcada (WorldBossSystem) e a cadeia piloto da
> Campina (ChainSystem); Floresta e Ruínas depois do teste (§9.2). Decisões do usuário em §9; números e regras em §10-§11.
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

## 10. Chefes de mundo: números (2026-11-26; onda 5: lugares refeitos e calibragem fechada)

Dados em `MonstersCatalog.WORLD_BOSSES` / `_world_bosses()` e `SkillsCatalog._world_boss_skills()` (`mob_wb_*`). Nascem pelo
`WorldBossSystem` (§11). Teste: `-- --autostart=<classe> --world_boss=<id>` (nasce a 12 m), `--world_boss_shot=<pasta>`,
`--moments_shot=<pasta>` (o evento inteiro). Checks `_check_world_boss_data`, `_check_world_boss_event`.
Todos: chefe de verdade no topo da faixa, escala 3,0 (lobo 2,8), 3 fases (70% lacaios + golpe novo, 40% ward 0,5 com lacaios,
15% fúria ×1,3), fúria por tempo aos 330 s, lacaios 0 XP (`wb_*`), uma assinatura de chão avisada (não esquivável pela AGI).

| Chefe | Nv | Vida | ATK | Assinatura (forma) | Outros golpes |
|---|---|---|---|---|---|
| Javali Ancestral | 10 | 210 000 | 44 | Trilha Ancestral: 3 faixas encadeadas que ele corre (cortejo), atordoa 0,8 s | presa em cone, pisão lento, disparada no longe, vara |
| Alce Ancião | 20 | 600 000 | 76 | Erupção de Cristal: 3 anéis × 2 pulsos (o lugar seguro anda), prende 1,2 s; todo anel que cai em até 3 s já aparece na gramática de perigo (`warn_all`), não só o próximo | galhada, galope, chuva de lascas, bramido (empurra), manada |
| Basilisco das Ruínas | 30 | 1 050 000 | 115 | Olhar que Petrifica: faixa de 10 × 30 m, 2 s de aviso, atordoa 2,5 s | mordida venenosa, cauda (atordoa), bote, cuspe ácido (poça), estátuas |
| Rinoceronte de Guerra | 40 | F2 chefe ×22 (≈3,27 M) | F2 ×0,95 (≈133) | Atropelo da Horda: 3 faixas paralelas em sequência, atordoa 1 s | chifrada, investida, pisão, Tambores (grito +20% ATK/vel. de ataque na Horda), lanças, guerreiros |
| Lobo-Rei de Ferro | 45 | F2 chefe ×10 (≈1,78 M) | F2 ×0,9 (≈144) | Marca da Caçada: 3 marcas que seguem (nunca o tanque) e explodem: espalhar | garra (sangra), salto no longe, queda de ferro (atordoa), uivo da alcateia |
| Gamo de Porcelana | 50 | F2 chefe ×18 (≈3,73 M) | F2 ×0,78 (≈140) | Clarão das Lanternas: ilhas de luz (mín. 4, 3,5 m); fora delas leva o golpe | galhada, deslize, cascos (atordoa), lanternas que caem, convidados |

**Lugares (onda 5).** Os provisórios estavam ruins: o Rinoceronte a 13 m do portal do Forte de Guerra (os bots saíam do mapa
aos ~30 s e o chefe resetava com 100%: era a causa dos 5/20), o Gamo em cima da estrada e a 27 m de portal, o Javali e o
Basilisco em cima da estrada e dentro de spawner, o Alce a 18 m de portal. Refeitos com a sonda
`world_boss_probe.tscn -- --spots --search` (alcançável a pé da chegada; >= 6 m do eixo de estrada; >= 40 m de portal;
>= 4 m além do raio de qualquer spawner; fora do povoado; 50-125 m do hub). Livre em volta: 13 m no Javali, 10 m nos
outros, 8 m no Alce (a Floresta Sombria não tem clareira maior; árvores são obstáculo, não parede).

| Chefe | Mapa | Lugar antigo | Lugar novo |
|---|---|---|---|
| Javali Ancestral | city_aldara | -84, 24 | -78, 6 |
| Alce Ancião | field_forest | 78, 18 | 53, -10 |
| Basilisco das Ruínas | field_ruins | -72, 42 | -70, 59 |
| Rinoceronte de Guerra | field_steppe | 72, -54 | 38, -46 |
| Lobo-Rei de Ferro | field_kharzun | 84, 42 | 83, 44 |
| Gamo de Porcelana | field_parade | 30, 77 | 62, 68 |

Sonda: `boss_probe.tscn -- --party=8 --boss=<id> --trials=20 [--why]` (8 bots do nível, uma classe de cada; grupo de 5 + 3
soltos; `BOSS_CROWD_MULT` para em 5). Alvo: 70-85% de vitórias, luta de 3-5 min. Resultado nos lugares novos:

| Chefe | Vitórias | Tempo médio (vitórias) | Mortes/luta | Situação |
|---|---|---|---|---|
| Javali Ancestral | 17/20 (85%) | 161 s | 1,6 | no alvo (limite de cima) |
| Alce Ancião | 16/20 (80%) | 209 s | 2,6 | no alvo (era 11/20: só o lugar mudou) |
| Basilisco das Ruínas | 17/20 (85%) | 250 s | 3,9 | no alvo (limite de cima) depois de vida 1,2 M -> 1,05 M e ATK 125 -> 115 (no lugar novo, sem mexer, deu 10/20) |
| Rinoceronte de Guerra | 16/20 (80%) | 193 s | 2,3 | no alvo (era 5/20: o portal) |
| Lobo-Rei de Ferro | 15/20 (75%) | 195 s | 3,0 | no alvo |
| Gamo de Porcelana | 14/20 (70%) | 231 s | 2,6 | no alvo (limite de baixo; era 10/20) |

O que mais bate nos bots (`--why`, lugares novos): o básico do chefe (38-61% do dano), depois o 1º golpe de cone/área; a
assinatura fica em 0-9% (os bots saem dela). Só o Basilisco mudou de número; Alce, Rinoceronte e Gamo entraram no alvo só
com o lugar novo.

Abertos: o Javali está no limite de cima (85%); se o teste de jogo achar fácil, ATK 44 → 48. A sonda não traz de volta o bot
que morreu (no jogo ele renasce no povoado e volta pelo `BotBrain._world_boss`), então a luta aberta real com 10+ bots tende
a ser mais fácil que a sonda.

## 11. Nascimento, anúncio, participação e a cadeia piloto (onda 5, 2026-11-26)

Implementação: `core/sim/systems/world_boss_system.gd`, `core/sim/systems/chain_system.gd`, falas em
`data/catalog/moments_catalog.gd` (provisórias, para o roteirista), números em `Balance.WORLD_BOSS_*` / `CHAIN_*`.

| Knob | Valor | Faixa segura | Efeito |
|---|---|---|---|
| `WORLD_BOSS_EVERY` | 40 min | 25-60 | ritmo dos chefes (× 0,8-1,2, `WORLD_BOSS_ROLL`) |
| `WORLD_BOSS_WARN_S` | 120 s | 60-180 | aviso no chat + marca antes de nascer |
| `WORLD_BOSS_LIFE` | 15 min | 10-20 | quanto tempo ele espera ser derrubado |
| `WORLD_BOSS_SHARE_MIN` | 0,25 | 0,1-0,4 | fração da parte justa (vida / participantes) para ganhar o prêmio |
| `WORLD_BOSS_SHARE_RANGE` | 40 m | 25-50 | cura conta se o curado está a isto do chefe |
| `WORLD_BOSS_BOT_SLACK` | 3 níveis | 0-5 | bots fora da faixa que ainda vão |
| `CHAIN_TICK` / `CHAIN_STEP_CHANCE` | 3 min / 0,35 | 2-6 / 0,2-0,6 | frequência dos passos de cadeia (~1 a cada 8-9 min no mapa) |
| `CHAIN_MARK_MIN` | 15 min | 10-20 | duração da Feira / do Acampamento |
| `CHAIN_COOLDOWN_MIN` | 10 min | 5-20 | pausa depois da marca |
| `CHAIN_FAIR_DISCOUNT` | 0,15 | 0,1-0,25 | desconto da Feira |

Regras decididas na implementação (além do texto acima; para o designer revisar):
1. **Um Chefe de Mundo por vez** no servidor; o relógio de outra faixa que zera espera ele cair/sumir (HUD e
   `Sim.world_boss_status` mostram um só).
2. **Ato do jogador** = topo da faixa do mapa onde ele está (masmorra/casa = a zona de fora): Ato I até 30, Ato II até 45
   (`WORLD_BOSS_ACT_TOPS`). No Ato I os três relógios do Ato I andam juntos (cada um no seu sorteio).
3. **Save**: relógios das faixas; chefe vivo ou avisado no save volta AVISADO (2 min) no load. Marcas de cadeia voltam com o
   tempo que faltava (o acampamento no mesmo lugar).
4. **Prêmio por participação**: o chefe do evento não usa o abate comum (sem XP para quem mais bateu nem saque de tabela).
   XP igual = `xp` do chefe × `WORLD_BOSS_XP_MULT` com a regra de nível de sempre; o resto é do `MvpSystem.award`
   (contrato wave5 A). Golpe final não importa.
5. **Bots**: da faixa ± 3 níveis, no mapa do chefe ou num mapa com portal direto para ele, fora do grupo do jogador.
   Brigam a `WORLD_BOSS_BOT_ENGAGE` m; lacaio que bate neles vem antes (combate reativo). Alguns gritam no chat.
6. **Caravana do Tobias** = evento de estrada da Campina com a regra da cadeia (salteadores do nível do ponto, carroça
   puxada `cart_draft`, prêmio consumível), nos 4 pontos de evento do Vale. Resolvido = chegou; falhou OU expirou (ninguém
   ajudou) = caiu; investida no mapa = cancelado sem marca.
7. **Feira**: desconto em toda loja do mapa da cadeia e das casas dele (`ChainSystem.shop_mult`; preço na loja =
   `Sim.shop_price`), 3 feirantes na praça (Tobias com carroça, malabarista, temperista) com falas. O "NPC de jogo de sorte"
   do §3.2 ficou de fora (mecânica nova: pedir ao designer).
8. **Acampamento Bandido**: mandachuva nv 10 (`camp_bandit_boss`, 2 400 de vida, XP e saque) + 5 bandidos nv 8
   (`camp_bandit`) a `CHAIN_CAMP_OFFSET` m da estrada onde a caravana caiu; não renascem; todos caídos = a marca acaba antes
   ("desfeito"). Sem tenda/cenário próprio (só monstros): pedir arte se o teste pedir.
9. **Leitura (§3.3)**: chat de sistema (todos os mapas), faixa no topo do HUD com a contagem (`Hud.moment_text`), marca no
   minimapa e no mapa grande (chefe: disco laranja com raios; acampamento: losango vermelho-terra; Feira: anel dourado),
   falas dos NPCs do passo e dos feirantes. Música: o tema de chefe já toca perto do chefe (nada novo para as cadeias).

Sonda §8: `world_boss_probe.tscn -- --boss=<id> --trials=10 [--bots=10] [--limit=480]` (metade dos bots no povoado do mapa,
metade no vizinho a 1 portal). Check `_check_world_boss_event`: 10 bots da faixa saindo da praça de Aldara, >= 6 chegam em 70 s.
Fotos: `production/qa/evidence/momentos/` (`--moments_shot`).
