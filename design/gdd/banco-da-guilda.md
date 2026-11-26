# Banco da Guilda — depósitos, patentes e encomendas

> Status: **APROVADA PARA IMPLEMENTAR** (2026-11-26, pedido do usuário). Nada implementado. Decisões do usuário em §0 e §9.
> Depende de `bots-com-memoria.md` (a guilda, afinidade). Liga com `cartas.md`, `mvp-premios.md` (pergaminhos),
> `arena-da-guilda.md` e `guerra-de-guildas.md` (outras coisas da janela da Guilda).

## 0. Pedido do usuário (2026-11-26)

- Banco compartilhado da guilda: os **bots depositam** itens que acham úteis para os outros (cartas, equipamento,
  pergaminhos, materiais, consumíveis) e **ouro**.
- O jogador **tira até 5 itens por hora de jogo**.
- Quanto **mais fortes os bots da guilda e maior o nível do jogador**, melhores as cartas e itens que aparecem.
- O jogador também deposita; conforme o que deposita (ex.: um lendário que não usa mais) **sobe de patente** na guilda,
  e a patente aumenta quanto ele pode tirar.
- Nas patentes altas, o jogador **manda bots em encomendas**: buscar uma carta ou uma quantidade de material num tempo
  dado; o bot põe o resultado no banco, como uma comissão.
- O jogador também pode **pegar pedidos** no quadro da guilda (os pedidos dos bots).

## 1. Overview

Três peças na janela da Guilda:
1. **Banco**: um baú compartilhado (abas: Equipamento, Cartas, Materiais, Consumíveis, Ouro). Os bots enchem ao longo do
   tempo com o que acham na caça; o jogador tira dentro de um limite por hora e deposita o que sobra.
2. **Patente**: os depósitos do jogador viram **Contribuição**; a Contribuição sobe a patente; a patente aumenta o limite
   e libera coisas novas.
3. **Quadro de Encomendas**: duas colunas: **Encomendas suas** (você manda bots buscar algo) e **Pedidos dos bots**
   (eles pedem algo e você entrega/cumpre).

## 2. Player Fantasy

"A guilda cuida de mim e eu cuido dela." Voltar à cidade e ver o que os amigos deixaram no banco ("a Sable deixou uma
Carta de Lince, é a minha build"); doar o lendário velho e ver o nome subir na lista; mandar o Rook buscar 20 Minérios
Estelares enquanto você faz a masmorra.

## 3. Detailed Rules

**3.1 Onde.** Janela da Guilda (tecla nova ou aba na janela P), aba **Banco**. Mexer no banco: em qualquer cidade com
cristal de retorno (§9.1). O banco é um estado da sim (`GuildSystem`, no `WorldSim`), salvo no save.

**3.2 Bots depositam.** A cada `GBANK_TICK` (10 min de jogo) a guilda faz um **pulso de depósito**: cada bot da guilda
que caçou nesse tempo tem chance de depositar 0-2 coisas, escolhidas por **utilidade para os outros membros**:
- equipamento da classe/build de outro membro (o jogador conta como membro), do tier da faixa do bot;
- cartas que ele achou e não precisa (repetidas, de encaixe que a build dele não quer);
- materiais de refino e de receita da faixa; consumíveis; pergaminhos (`mvp-premios.md`), raramente;
- **ouro**: um pouco por pulso (`GBANK_GOLD_PER_BOT`), que enche o cofre.
Os depósitos aparecem no registro do banco ("Rook depositou: Anel do Caçador de Aço") e às vezes no chat da guilda.
Teto do banco: `GBANK_SLOTS` (60); cheio, o item mais velho e mais barato sai.

**3.3 Qualidade.** Tier e raridade do que entra = função da **força da guilda** (média dos níveis dos bots da guilda) e do
**nível do jogador** (§4). Lendário só entra com patente da guilda alta (§4) e raramente; Ápice e conjuntos do 50 nunca.

**3.4 Tirar.** Cada item tirado gasta 1 **retirada**; o jogador ganha `GBANK_TAKES_PER_H(patente)` retiradas por hora de
jogo (Recruta = **5**), guardando no máximo 2 horas. Ouro tem limite próprio por hora, também pela patente. Pilha de
material/consumível tirada conta como 1 retirada (até `GBANK_STACK_TAKE` unidades).

**3.5 Depositar e Contribuição.** O jogador deposita qualquer coisa que o banco aceita (não: itens de quest). Ganha
**Contribuição** = valor do item (§4; lendário vale muito, carta de núcleo vale muito, lixo vale quase nada). Tirar de
volta um item que você mesmo depositou **devolve** a Contribuição que ele deu (não dá para "girar" o mesmo item).
Depositar algo que um membro usa (classe/build de um bot da guilda) dá +50% e afinidade com esse bot.

**3.6 Patentes** (Contribuição acumulada; nunca cai):

| Patente | Contribuição | Retiradas/h | Ouro/h | Libera |
|---|---|---|---|---|
| Recruta | 0 | 5 | 500 | banco |
| Membro | 300 | 6 | 1.500 | pedidos dos bots |
| Veterano | 1.000 | 8 | 4.000 | **encomendas** (1 por vez) |
| Oficial | 3.000 | 10 | 10.000 | 2 encomendas; lendário no banco |
| Braço-Direito | 8.000 | 12 | 25.000 | 3 encomendas; escolher o bot líder da guerra |

A patente aparece na etiqueta do nome ("Oficial · Lanternas de Aldara") e os bots comentam a subida.

**3.7 Encomendas (você manda).** Veterano+: escolher **o que** (uma carta de monstro que você já viu, ou N de um material
da sua faixa), **quem** (1-3 bots da guilda) e **quanto tempo** (curta 30 min / média 1 h / longa 2 h de jogo). Paga uma
**taxa** em ouro. Os bots escolhidos **saem do mundo** nesse tempo (não estão no grupo nem na cidade; o chat diz
"Rook saiu para a Floresta buscar Presas"). No fim, o resultado fica **reservado para você** (não gasta retirada, os outros bots não pegam).
**Aviso de volta**: aparece um **cartão à esquerda do minimapa** (retrato do bot + ícone do item, pisca de leve). Clicar abre
a **mensagem do bot** contando como foi ("Voltei da Floresta! Achei 12 Presas de Lince, o lince quase me pegou.") e um botão
**"Pôr na bolsa"** (se a bolsa está cheia, o botão diz isso e o item continua reservado no banco). Vários cartões empilham.
A encomenda **nunca falha**: material sempre vem, em quantidade que depende do nível dos bots e do tempo (§4); encomenda de
carta pode não achar a carta, e aí o bot traz **metade da taxa de volta** + alguns materiais do monstro.

**3.8 Pedidos dos bots (você cumpre).** Membro+: o quadro mostra 3-5 pedidos que mudam a cada `GBANK_REQUEST_REFRESH`
(1 h de jogo): "Sable precisa de 10 Presas de Lince", "Rook quer a Carta do Golem", "Mira pede ajuda: mate o Rei Lobo".
Aceitar → cumprir (entregar no banco / matar) → prêmio: Contribuição, afinidade com o bot e um item/ouro do próprio bot.
Pedidos cumpridos alimentam `bots-com-memoria` (lembrança `ajudou_pedido`).

**3.9 Bots tiram também.** Os bots da guilda às vezes tiram do banco o que serve para a build deles (pouco, `GBANK_BOT_TAKE_CHANCE` por pulso; nunca o
reservado de encomenda). O registro mostra ("Rook pegou: Botas do Caçador"): o banco anda.

## 4. Formulas (propostas)

- Força da guilda `F = média(nível dos bots da guilda)`; nível de referência `R = max(F, nível do jogador) − 2`.
  Item depositado: tier do equipamento de nível `R`; raridade sorteada com peso que sobe com `F`
  (`F` 15: 70% comum / 28% raro / 2% lendário-só-Oficial; `F` 40: 45 / 50 / 5).
- Contribuição de um depósito: `preço_ref × GBANK_CONTRIB_RATE` (`preço_ref` = preço do item ou o da carta da
  `casa-de-leiloes`), com mínimos: lendário ≥ 400, carta de núcleo ≥ 250, carta comum ≥ 20.
  Ex.: lendário do 30 que não usa mais = ~500 → de Recruta direto a Membro.
- Encomenda de material: `qtd = base_faixa × horas × (nível_médio_bots / nível_da_faixa)`, teto ×1,5.
  Ex.: 2 bots do 32 buscando Minério Estelar (faixa 30) por 1 h = ~12. Encomenda de carta: chance
  `= min(0,9, horas × 0,35 × fator_nível)` por bot (1 h, 2 bots no nível: ~55%).
- Taxa: `GBANK_MISSION_FEE × horas × bots` (proposta 100 ouro × nível/10 por bot-hora).

## 5. Edge Cases

- Sem guilda: nada disso aparece (a guilda chega no 15).
- Banco cheio com item reservado de encomenda: reservado não conta no teto.
- Bot em encomenda é chamado pela guerra/arena: não pode ir (aparece "fora numa encomenda", com o tempo restante).
- Jogador deposita e o bot tira o mesmo item: a Contribuição do jogador fica (foi doação de verdade).
- Save antigo / guilda nova: banco vazio; o 1º pulso enche com 3-5 itens de boas-vindas.
- Fechar o jogo com encomenda andando: o tempo só anda com o jogo aberto (como o resto do relógio de jogo).

## 6. Dependencies

`bots-com-memoria.md` (guilda, elenco, afinidade, lembranças), `GuildSystem` novo (estado no `WorldSim`, no save),
`LootSystem`/`gear_pool` (o que os bots acham), `cartas.md`, `casa-de-leiloes.md` (preço de referência), `mvp-premios.md`,
`BotBrain` (bot some na encomenda, pega pedidos), `BotsCatalog` (falas), janela da Guilda (`windows`), `SaveSystem`
(`guild_bank`, `guild_contrib`, `guild_missions`, `guild_requests`).

## 7. Tuning Knobs (`data/balance.gd`)

`GBANK_TICK` (10 min), `GBANK_SLOTS` (60), `GBANK_GOLD_PER_BOT`, `GBANK_RANKS` (tabela §3.6), `GBANK_STACK_TAKE` (20),
`GBANK_CONTRIB_RATE`, `GBANK_RARITY_BY_F`, `GBANK_REQUEST_REFRESH` (60 min), `GBANK_MISSION_FEE`, `GBANK_MISSION_TIMES` (30/60/120).

## 8. Acceptance Criteria

1. Em 1 h simulada, a guilda deposita itens do tier certo para `F` e nível do jogador (check com rng fixo).
2. Recruta tira 5 itens e o 6º recusa com o tempo até a próxima (check).
3. Depositar um lendário dá a Contribuição da fórmula; tirar de volta devolve (check).
4. Subir para Veterano libera encomendas; encomenda de 1 h com 2 bots põe o material reservado no banco e os bots somem nesse tempo (check).
5. Pedido de bot cumprido dá Contribuição + afinidade + lembrança (check).
6. Save grava e lê banco, patente, encomendas e pedidos (check).
7. Fotos da janela (banco, patentes, quadro) em `production/qa/evidence/banco-guilda/`.

## 9. Decisões do usuário (2026-11-26)

1. **Em qualquer cidade com cristal**, pela janela da Guilda.
2. **Bots tiram um pouco**, só o que serve à build deles (o banco anda).
3. **Encomenda volta reservada para você**, sem gastar retirada; avisa com um **cartão à esquerda do minimapa** que abre a
   mensagem do bot e o botão "Pôr na bolsa".
4. **Encomenda nunca falha**: bots fracos trazem menos; carta não achada devolve metade da taxa.
