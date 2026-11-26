# Cartas de Monstro — caça com perseguição

> Status: **APROVADA PARA IMPLEMENTAR** (conceito fechado 2026-11-25). Nada implementado. Decisões do usuário em §0 e §9.
> §5-8 (casos, dependências, botões, critérios) entram por escrito no começo da implementação.
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
onde o jogador vende e compra cartas, e os bots também (spec própria: `casa-de-leiloes.md`). Até lá, vender ao
mercador por um valor baixo.

**3.8 Bestiário.** Janela nova: monstros vistos, carta de cada um (achada / falta / nunca visto), mapa e faixa onde vivem,
e os grupos de combo. Zona completa = **título** ("Caçador do Vale"), sem bônus.

## 4. Formulas (a definir depois do conceito)

Meta da D3: `cartas_por_hora ≈ 2-3` caçando no nível. Com ~3 abates/min (curva de XP) = ~180 abates/h, isso dá chance base
≈ 1/60-1/90 por abate de monstro comum (ex.: 1/75 → 2,4 cartas/h). Uma carta *específica* sai, em média, a cada ~75 abates
daquele monstro (~25 min caçando só ele), então fechar um combo de 3 leva ~1-1,5 h. Carta de núcleo: chance própria, mais baixa
(proposta 1/600 → ~3 h caçando aquele monstro). Elite ×10, chefe com chance própria. Calibrar com uma sonda nova (`card_probe`).

## 5-8. Edge Cases, Dependencies, Tuning Knobs, Acceptance Criteria

Depois do conceito fechado. Rascunho anterior (dependências: `LootSystem`, `Stats.compute`, `SaveSystem`, `windows`,
`npc_ui` Relicária, `BotsCatalog`, ícones) continua válido.

## 9. Perguntas abertas

Nenhuma. Respondidas em 2026-11-25:
1. **Tirar carta**: volta para a bolsa **de graça** (D9). Trocar de build não pune; a escolha pesa pelo slot, não pelo custo.
2. Casa de Leilões: decisões em `casa-de-leiloes.md` §0/§9.
3. **(2026-11-26) 1ª leva = Ato I (níveis 1-30)**, ~90 cartas com grupos e núcleos; Atos II/III depois do teste de jogo.
4. **(2026-11-26) Arte = foto do modelo do monstro numa moldura de carta** (dourada no núcleo), gerada por script como os ícones de conjunto.
