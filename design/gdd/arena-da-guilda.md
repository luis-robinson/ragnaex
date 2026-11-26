# Campo de Caça da Guilda — hordas sem fim

> Status: **APROVADA PARA IMPLEMENTAR** (2026-11-26, pedido do usuário). Nada implementado. Decisões do usuário em §0 e §9.
> Depende de `bots-com-memoria.md` (a guilda). Liga com `cartas.md` (cartas caem aqui), `pocoes-de-caca.md` (consumíveis).

## 0. Decisões do usuário (2026-11-26)

| # | Pergunta | Decisão |
|---|---|---|
| D1 | Como a corrida acaba | **Sem fim até cair**: as levas ficam mais duras; acaba quando o grupo morre ou sai. A melhor leva vira o **recorde da guilda**. |
| D2 | Quem entra / quantas vezes | **Você + até 4 bots da guilda**; **1 corrida por hora de jogo**. |
| D3 | O que cai | **Só ouro (×3), cartas e consumíveis** (pedido original). |

## 1. Overview

Na janela da Guilda, botão **"Campo de Caça"**: o grupo (você + até 4 bots da guilda) entra numa **arena pequena** e as
**hordas** de monstros chegam por portões, leva após leva, cada uma mais dura. Monstros dali só deixam **ouro ×3, cartas e
consumíveis**: é o lugar de juntar ouro e caçar cartas, não equipamento. A corrida acaba quando todos caem ou o grupo sai;
a leva mais alta fica no **quadro de recordes** da guilda.

## 2. Player Fantasy

"Mais uma leva." A tensão sobe aos poucos: no começo o grupo varre tudo, na leva 15 o curandeiro grita no chat, na 20
aparece o chefe e todo mundo segura o fôlego. E a pergunta de toda corrida: dá para bater o recorde?

## 3. Detailed Rules

**3.1 Entrada.** Janela da Guilda → "Campo de Caça" → escolher até 4 bots da guilda (sugere tanque + cura + 2 dano pelos
papéis das builds) → entra. Carga: 1 entrada por hora de jogo, guarda no máximo `ARENA_CHARGES_MAX` (3). O mapa é uma
**instância só sua** (`MapDef.instance`; diferente das masmorras compartilhadas): bots de fora não entram.

**3.2 Arena.** Mapa pequeno (~40 m de diâmetro), redondo, com 4 portões por onde as levas entram, pilares baixos para
puxar e um círculo central. Modelo novo no Blender (`map_guild_grounds`), tema de pátio de treino da guilda.

**3.3 Levas.** Leva N = `ARENA_WAVE_SIZE(N)` monstros do **conjunto da faixa do jogador** (monstros comuns das zonas da
faixa; nível = nível do grupo). A cada leva, vida e dano sobem (§4). Marcos:
- a cada 5 levas: **elite** (Rei do monstro) no meio da leva;
- a cada 10 levas: **chefe da arena** (um dos chefes de campo da faixa, sem saque de chefe);
- a partir da leva 15: modificadores sorteados por leva (rápidos, enfurecidos, escudados, curandeiros), anunciados no topo.
Pausa de `ARENA_BREAK_S` (10 s) entre levas; a próxima começa antes se o grupo apertar "Próxima".

**3.4 Saque.** Monstros da arena **não** dão equipamento nem material. Dão:
- **ouro ×3** do ouro normal do monstro (`ARENA_GOLD_MULT`);
- **cartas** com a chance normal da carta daquele monstro (`cartas.md`; elite e chefe com a chance deles);
- **consumíveis**: poções de vida/mana, elixires e, raramente, Poções de Caça (`pocoes-de-caca.md`).
XP: **metade** do XP normal do monstro (`ARENA_XP_MULT` 0,5; §9). O saque cai no chão como hoje (bots pegam a parte deles pela regra de divisão).

**3.5 Fim e recorde.** Todos mortos ou "Sair" → volta ao salão da guilda, com resumo: leva alcançada, ouro, cartas,
tempo. Recorde da guilda = maior leva (com os nomes do grupo); o jogador e cada bot têm o seu recorde pessoal. Bots
comentam no chat da guilda ("leva 23! a Sable caiu primeiro, claro").

**3.6 Morte.** Morrer na arena **não** perde XP nem durabilidade (é treino). Morto fica de espectador até a leva acabar;
se ainda houver alguém vivo, os mortos **voltam na pausa entre levas** com 50% da vida.

## 4. Formulas (propostas)

- Tamanho: `ARENA_WAVE_SIZE(N) = 4 + 2 × N`, teto `ARENA_WAVE_CAP` 30 vivos ao mesmo tempo (o resto espera no portão).
- Força: vida × `(1 + 0,08 × (N − 1))`, dano × `(1 + 0,05 × (N − 1))`. Leva 10 = vida ×1,72, dano ×1,45; leva 20 = ×2,52 / ×1,95.
- Meta: grupo de 5 do nível, build média, chega na leva **12-18**; uma corrida dura **15-25 min**.
- Ouro: corrida média ≈ 2× o ouro de 20 min caçando no campo (×3 por monstro, menos tempo morto).

## 5. Edge Cases

- Jogador sem guilda: o botão não aparece (a guilda chega no 15).
- Menos de 4 bots na guilda: entra com os que houver (mínimo só você).
- Fechar o jogo no meio: a corrida conta como terminada na leva atual (recorde vale, saque não pego se perde).
- Bots da guilda já num grupo com você: são os sugeridos.
- Monstro preso fora da arena / atrás de pilar: volta ao centro depois de `ARENA_STUCK_S`.

## 6. Dependencies

`bots-com-memoria.md` (guilda, janela Guilda, chat da guilda), `MapDef` instância própria (novo), `RaidSystem`/levas
(reaproveitar o spawn por portão), `MobSystem` (escala por leva, elites), `LootSystem` (mesa só da arena), `cartas.md`,
`pocoes-de-caca.md`, `BotBrain` (grupo, posição contra horda), `Music` (tema novo "arena"), **Blender**: `map_guild_grounds`.

## 7. Tuning Knobs (`data/balance.gd`)

`ARENA_CHARGES_MAX` (3), `ARENA_CHARGE_MIN` (60 min de jogo), `ARENA_WAVE_SIZE` (4 + 2N), `ARENA_WAVE_CAP` (30),
`ARENA_HP_STEP` (0,08), `ARENA_DMG_STEP` (0,05), `ARENA_BREAK_S` (10), `ARENA_GOLD_MULT` (3), `ARENA_ELITE_EVERY` (5),
`ARENA_BOSS_EVERY` (10), `ARENA_MOD_FROM` (15).

## 8. Acceptance Criteria

1. Leva N tem o tamanho e a força da fórmula (check).
2. Monstro da arena nunca dá equipamento nem material; dá ouro ×3 (check com sorteio fixo).
3. Sem carga, o botão fica cinza com o tempo até a próxima (check).
4. Grupo morto → volta ao salão, recorde gravado no save (check).
5. Sonda `arena_probe`: grupo de 5 bots do nível chega na leva 12-18 em ≥ 70% das corridas; tick ≤ 10 ms com 30 vivos.
6. Fotos (arena, leva 10 com chefe, resumo) em `production/qa/evidence/arena/`.

## 9. Decisões do usuário (2026-11-26)

1. **XP pela metade** (`ARENA_XP_MULT` = 0,5): a arena não substitui subir de nível no campo.
2. **Monstros comuns da faixa do jogador** (sem modelos novos de monstro; bom para caçar cartas).
3. **Recorde só no quadro** (sem prêmio por marco).
