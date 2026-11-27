# Cartas de Monstro — caça com perseguição

> Status: **APROVADA PARA IMPLEMENTAR** (conceito fechado 2026-11-25). Nada implementado. Decisões do usuário em §0 e §9.
> §4-8 escritos no começo da implementação (2026-11-26); lista do Ato I em `cartas-ato1.md`.
> Referência: sistema de cartas do Ragnarok Online (quase todo monstro tem uma carta; a carta encaixa e muda a build;
> combos de cartas dão bônus extra).

## 0. Decisões do usuário (2026-11-25)

| # | Pergunta | Decisão |
|---|---|---|
| D1 | Força das cartas | **Duas espécies**: a maioria **pequena e específica**; algumas **de núcleo**, fortes (ex.: na arma, −10% de dano recebido). E **combos**: 2 ou 3 cartas do mesmo grupo encaixadas dão bônus a mais. |
| D2 | Onde encaixa | No **slot do personagem** (trocar de equipamento não perde a carta). |
| D3 | Raridade | **~1 carta a cada 20-30 min** de jogo normal (somando todos os monstros caçados). |
| D4 | Bestiário | Só **título** por zona completa (nenhum poder). |
| D5 | Encaixe | **Fixo por carta** (carta de arma, de botas...; um efeito por carta). |
| D6 | Repetidas | Vão para uma **Casa de Leilões** (spec própria: `casa-de-leiloes.md`): o mundo fica mais vivo, bots compram e vendem. |
| D7 | Combos | **Grupos fixos de 3** cartas comuns (núcleo não é coringa). |
| D8 | Núcleos | No máximo **2** cartas de núcleo encaixadas ao mesmo tempo (`CARD_CORE_MAX` = 2). |
| D9 | Tirar carta | **Volta para a bolsa de graça** (sem custo, sem destruir). |

## 1. Overview

Todo monstro comum e elite tem uma **Carta**. Ela cai de vez em quando (~1 a cada 20-30 min de caça normal) e vai num dos
**6 encaixes do personagem**: arma, mão secundária, cabeça, peito, botas e acessório. Há duas espécies:

- **Carta comum** (a maioria): efeito pequeno e específico — "+15% de dano em mortos-vivos", "chance de envenenar ao
  acertar", "+10% de distância no dash". Útil em certos lugares, nunca obrigatória.
- **Carta de núcleo** (poucas por zona; todas as de chefe): efeito forte que define a build — "−10% de dano recebido",
  "abates curam 3% da vida", "o Raio do Vazio salta para mais um alvo".

As cartas formam **grupos** (a matilha do Vale, os mortos da Catacumba, os elfos da Árvore-Mãe...). Encaixar **2 ou 3
cartas do mesmo grupo** liga um **bônus de combo**, como os conjuntos lendários. O jogador passa a caçar *aquele* monstro
para fechar o combo, e cada monstro do mapa vira um prêmio possível — a perseguição que hoje falta (os lendários chegam
em hora marcada, a cada 5 níveis). O **Bestiário** mostra as cartas achadas e as que faltam, e dá um título por zona completa.

## 2. Player Fantasy

"Falta uma para fechar a Matilha." O brilho dourado no chão, o som próprio, os bots comentando no chat. Na caça comum a
carta é a surpresa frequente; no núcleo e no combo é o objetivo que faz o jogador voltar a um mapa de nível baixo de
propósito. Bartle: Conquistador (núcleo, combos) e Explorador/colecionador (Bestiário). A build ganha um toque pessoal:
dois Paladinos Templários com as mesmas peças jogam diferente por causa das cartas.

## 3. Detailed Rules (conceito)

**3.1 Quem tem carta.** Todo monstro com XP > 0 que não seja forma de metamorfose, lacaio de chefe nem boneco de treino
(~200). Elite (Rei de um monstro) dá a carta da base com chance maior. Chefe de campo/masmorra dá uma **carta de núcleo** própria.

**3.2 Espécies.**
- *Comum*: um efeito pequeno do tipo do encaixe (dano/defesa contra uma família, efeito ao acertar, resistência a um estado,
  velocidade, dash, XP, ouro, mana ao abater). Números por faixa, numa tabela, não carta a carta.
- *Núcleo*: um efeito forte (redução de dano, cura no abate, gancho de skill da classe ou geral). ~2-3 por zona + 1 por chefe.
  Uma por personagem por encaixe, e no máximo `CARD_CORE_MAX` núcleos encaixados ao mesmo tempo (proposta: 2), para o núcleo
  continuar uma escolha.

**3.3 Encaixes.** 6, no personagem: arma, mão secundária, cabeça, peito, botas, acessório. Cada carta tem **um encaixe fixo**
e um efeito só (D5; como no Ragnarok: carta de arma, de armadura, de calçado...). Trocar de equipamento não mexe nas cartas.
Duas-mãos (sem mão secundária): o encaixe da mão secundária continua valendo (a carta não depende do item).

**3.4 Grupos e combos.** Cada carta comum pertence a um **grupo fixo de 3** (D7; em geral de uma família/lugar, com
encaixes diferentes para caberem juntas). Encaixar 2 do grupo liga o bônus de 2; as 3 ligam o de 3 (ex.: *Matilha do Vale* —
Lobo (botas), Lobo Cinzento (peito), Lobo Alfa (arma): 2 = +5% de velocidade, 3 = o dash deixa um uivo que assusta por 1 s).
Núcleo não entra em grupo.

**3.5 Queda e aviso.** Ao morrer, o monstro sorteia a carta dele (rng da sim). Ela cai como o baú de saque, com brilho e som
próprios; aviso no chat do mapa ("<nome> achou a Carta do <monstro>!"). No grupo, vale a regra de divisão dos lendários.
Bots também acham e comentam (não encaixam: o poder deles fica calibrado sem cartas).

**3.6 Encaixar.** Pela janela do personagem (C), arrastando da bolsa para o encaixe. Tirar/trocar ali mesmo, **de graça** (D9):
a carta volta para a bolsa.

**3.7 Repetidas.** Com 1 carta a cada 20-30 min, repetidas vão ser comuns: elas vão para a **Casa de Leilões** (D6),
onde o jogador vende e compra cartas, e os bots também (spec própria: `casa-de-leiloes.md`, implementada em 2026-11-27: `AuctionSystem`, NPC Leiloeiro). O mercador continua
comprando por um valor baixo.

**3.8 Bestiário.** Janela nova: monstros vistos, carta de cada um (achada / falta / nunca visto), mapa e faixa onde vivem,
e os grupos de combo. Zona completa = **título** ("Caçador do Vale"), sem bônus.

## 4. Formulas

Números em `data/balance.gd` (`CARD_*`); lista das cartas do Ato I e valores por faixa: `design/gdd/cartas-ato1.md`.

**Chance por abate** (sorteio com o rng da sim, um por personagem que divide o abate, como o lendário):

```
p = base × elite × drop_mult(c)
base  = CARD_CHANCE_COMMON (1/250 = 0,004)    carta comum
      = CARD_CHANCE_CORE   (1/2000 = 0,0005) carta de núcleo de monstro comum
      = CARD_CHANCE_BOSS   (1/12 = 0,083)    carta de núcleo de chefe (Eco de chefe: CARD_CHANCE_ECHO = 1/24)
elite = CARD_ELITE_MULT (10) se o monstro é o Rei (elite_of) da base; senão 1
drop_mult(c) = LootSystem.drop_mult(c) (Poção da Fortuna; 1,0 sem ela)
```
Exemplo: Lobo (comum), sem poção: p = 0,0133. Rei Lobo: 0,133. Ursa-Mãe: 0,083.
Meta D3: `cartas/h = abates/h × p_média ≈ 180 × 0,0133 ≈ 2,4` (alvo 2-3/h). Medida em `tools/tests/card_probe.tscn`.

**Valor do efeito**: `v = CARD_COMMON[efeito][t]` (comum) ou `CARD_CORE[efeito][t]` (núcleo), `t = 0` se nível ≤ 10,
`1` se ≤ 20, `2` acima (`CARD_TIER_LEVELS = [10, 20]`). Combos: `CARD_GROUP_BONUS[grupo] = [bônus de 2, bônus de 3]`, somam.

**Família**: dano causado × (1 + Σ family_dmg da família do alvo / 100); dano recebido × (1 − min(Σ family_def, CARD_FAMILY_DEF_CAP) / 100).
**Ao acertar** (golpe direto, não dano no tempo): `proc_poison` = dps `CARD_POISON_ATK_PCT`% do maior entre ATK/MATK por `CARD_POISON_S` s;
`proc_slow` = lentidão `CARD_SLOW_PCT`% por `CARD_SLOW_S` s; `proc_stun` = atordoa `CARD_STUN_S` s (× resistência do alvo; chefe resiste como sempre).
**Abate**: `kill_heal` cura `v`% da vida máxima. **XP**: × (1 + xp_pct/100). **Ouro de monstro**: × (1 + gold_pct/100). **Dash**: distância × (1 + dash_pct/100).

## 5. Edge Cases

- **Monstro sem carta**: XP 0 (lacaios, invocações, forma de metamorfose, ovos, boneco), monstro de evento de estrada (o prêmio é do evento) e lacaio de chefe (`boss_id ≥ 0`) não sorteiam.
- **Metamorfose**: conta pela base (`shift_base`), como XP e quest.
- **Rei (elite)**: dá a carta da base (`elite_of`) com chance × `CARD_ELITE_MULT`.
- **Eco de chefe** (`echo_*`): dá a carta do chefe original com `CARD_CHANCE_ECHO`.
- **Grupo**: cada personagem que divide o abate sorteia a sua; a carta cai presa ao dono por 110 s (regra do lendário) e só ele pega antes.
- **Bolsa cheia**: a carta fica no chão (regra do saque comum) até o tempo acabar.
- **Encaixe errado**: carta de botas não entra no encaixe da arma (recusa com aviso). Encaixe ocupado: a carta antiga volta para a bolsa;
  se a bolsa não tem lugar para ela, a troca é recusada ("Bolsa cheia").
- **Terceiro núcleo**: encaixar um núcleo com `CARD_CORE_MAX` já encaixados é recusado, a não ser que troque um núcleo no mesmo encaixe.
- **Tirar**: grátis; com a bolsa cheia (e sem pilha da mesma carta) é recusado.
- **Duas-mãos / sem mão secundária / sem item**: os encaixes valem sempre (são do personagem).
- **Mesma carta duas vezes**: impossível (cada carta tem um encaixe só e cada encaixe uma carta).
- **Bots**: acham, guardam na bolsa e comentam no chat; nunca encaixam (`Sim.card_socket` recusa quem não é o jogador).
- **Save antigo**: sem `cards`/`bestiary` = tudo vazio. Carta que saiu do catálogo some do encaixe ao carregar.
- **Bestiário**: "visto" = abatido por você ou com o seu grupo ao menos uma vez; "achada" = a carta entrou na sua bolsa ao menos uma vez
  (vender depois não apaga). Zona completa = todas as cartas dos monstros que nascem naquele mapa achadas.
- **Chefe com várias fases/lacaios**: só o chefe sorteia.

## 6. Dependencies

`LootSystem` (sorteio no abate, ouro, XP), `WorldSim._deal_damage` (família, ao acertar), `WorldSim.dash_params` (dash),
`SimEntity.recompute_stats` → `Stats.compute` (stats das cartas como bônus), `SaveSystem` (`cards`, `bestiary`), `GameData`
(`cards`, itens `card_<monstro>`), `windows` (janela C: encaixes; janela nova Bestiário), `npc_ui` (o mercador compra),
`FxManager`/`LootChest`/`Sfx` (baú brilhante e som), `BotChat` (comentário dos bots), ícones `tools/icons/card_icons.tscn`
(`assets/icons/card_<monstro>.png`). `casa-de-leiloes.md` (repetidas; `AuctionSystem`). Poção da Fortuna (`LootSystem.drop_mult`).

## 7. Tuning Knobs (`data/balance.gd`)

| Botão | Valor | Faixa segura | Mexe em |
|---|---|---|---|
| `CARD_CHANCE_COMMON` | 1/250 | 1/150-1/350 | cartas/h (D3; ~700 abates/h medidos no `card_probe`, usuário 2026-11-26) |
| `CARD_CHANCE_CORE` | 1/2000 | 1/1000-1/4000 | horas para um núcleo de monstro comum |
| `CARD_CHANCE_BOSS` / `CARD_CHANCE_ECHO` | 1/12 / 1/24 | 1/6-1/30 | abates de chefe por núcleo |
| `CARD_ELITE_MULT` | 10 | 5-20 | o Rei vale a pena |
| `CARD_CORE_MAX` | 2 | 1-3 | quanto o núcleo define a build |
| `CARD_TIER_LEVELS` | [10, 20] | — | faixas dos números |
| `CARD_COMMON` / `CARD_CORE` | tabelas | comum ≤ 1/3 de um núcleo | força por efeito e faixa |
| `CARD_GROUP_BONUS` | por grupo | 2 ≈ uma comum, 3 ≈ duas | combos |
| `CARD_FAMILY_DEF_CAP` | 25 | 15-40 | empilhar defesa de família |
| `CARD_POISON_*`, `CARD_SLOW_*`, `CARD_STUN_S` | 15%/4 s, 25%/2 s, 0,8 s | — | efeitos ao acertar |
| `CARD_PRICE_COMMON` / `CARD_PRICE_CORE` | 30 / 120 (o mercador paga a fração de venda de sempre) | — | ouro das repetidas |

## 8. Acceptance Criteria (check `--only=cards` em `tools/tests/run_tests.gd`)

1. Todo monstro elegível do Ato I (XP > 0, nível ≤ 30, nasce num mapa do Ato I ou numa investida) tem **exatamente uma** carta; nenhuma carta de lacaio/forma/ovo.
2. Todo grupo tem 3 cartas comuns de encaixes diferentes; núcleo não tem grupo; todo efeito existe na tabela da faixa.
3. Encaixar: encaixe certo entra e sai da bolsa; encaixe errado recusa; 3º núcleo recusa; tirar devolve à bolsa sem custo.
4. Combos: 2 do grupo ligam o bônus de 2; 3 ligam os dois; os stats aparecem em `Stats` (ex.: `hp_pct`).
5. Sorteio com rng fixo: com p forçado a 1 a carta cai como baú preso ao dono; com p = 0 não cai; rei usa × `CARD_ELITE_MULT`.
6. Save `TEST_SLOT`: `cards` e `bestiary` voltam iguais; save sem os campos = vazio.
7. Bots: `Sim.card_socket` recusa bot; bot que acha carta fica com ela na bolsa e não encaixa.
8. Ganchos: família muda o dano, `xp_pct`/`gold_pct`/`dash_pct`/`kill_heal` mudam o número certo.
9. Sonda: `card_probe.tscn` imprime cartas/h por mapa; alvo 2-3/h no nível.
10. Telas: janela C com os 6 encaixes, Bestiário, baú de carta no chão (fotos em `production/qa/evidence/cartas/`).

## 9. Perguntas abertas

Nenhuma. Respondidas em 2026-11-25:
1. **Tirar carta**: volta para a bolsa **de graça** (D9). Trocar de build não pune; a escolha pesa pelo slot, não pelo custo.
2. Casa de Leilões: decisões em `casa-de-leiloes.md` §0/§9.
3. **(2026-11-26) 1ª leva = Ato I (níveis 1-30)**, ~90 cartas com grupos e núcleos; Atos II/III depois do teste de jogo.
4. **(2026-11-26) Arte = foto do modelo do monstro numa moldura de carta** (dourada no núcleo), gerada por script como os ícones de conjunto.
