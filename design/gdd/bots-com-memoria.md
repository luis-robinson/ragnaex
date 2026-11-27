# Bots com Memória — conhecidos, rival e guilda

> Status: **APROVADA PARA IMPLEMENTAR** (2026-11-25, revisão de diversão). Nada implementado. Decisões do usuário em §9 (vencem o texto acima delas).

## 1. Overview

Os bots são o que o jogo tem de mais forte (é o que faz o Erenshor funcionar), mas hoje são todos iguais para o jogador:
nascem, caçam, conversam frases soltas. Esta proposta dá a **poucos bots** uma identidade que dura: eles **lembram do
que você fez** com eles, têm um **rival** que sobe de nível junto com você, formam uma **guilda** que te convida, e
**pedem ajuda** no chat (e você pode ir). A conversa genérica continua; o que muda é que alguns nomes passam a importar.

## 2. Player Fantasy

"Eu conheço essa gente." Entrar em Aldara e ver o Rook, que você salvou na Cripta, te cumprimentar pelo nome. Ver no chat
que a Sable (sua rival) chegou no 22 antes de você. Responder a um pedido de socorro e chegar a tempo. Fantasia social
(Bartle: Socializador), sem a parte ruim de gente de verdade.

## 3. Detailed Rules

**3.1 Elenco fixo.** Cada save ganha um **elenco** de 10 bots com nome, classe/build, personalidade e nível que
**persistem** (hoje os bots nascem de novo a cada carga). Os outros bots seguem descartáveis. Personalidade = um de
`calmo`, `brincalhão`, `competitivo`, `tímido`, `heroico`: escolhe as falas e o quanto fala (no máximo 1 fala a cada
`BOT_CAST_LINE_GAP` s por bot, para não virar barulho).

**3.2 Memória.** Cada bot do elenco guarda uma lista curta de **lembranças** sobre o jogador (no máx. 8, a mais velha sai):
`salvou` (você o curou ou matou o que o matava), `grupo` (fizeram grupo e mataram um chefe), `abandonou` (saiu do grupo no
meio da masmorra), `ajudou_pedido` (veio no pedido de socorro), `perdeu_saque` (você ficou com o lendário dele).
Cada lembrança ajusta a **afinidade** (-100..100). Afinidade alta: cumprimenta, aceita convite sempre, dá desconto em troca,
comenta seus feitos. Baixa: só comentário seco (nunca recusa grupo, §9.4).

**3.3 Rival.** Um bot do elenco, da mesma faixa, é o **rival**: começa 1 nível acima, sobe no ritmo do jogador ±1 nível,
aparece no chat quando passa de nível ou mata um chefe antes de você ("Sable matou o Conde. Sua vez."). Você pode
desafiá-lo para **correr um chefe** (quem mata primeiro); ganhar dá um título e afinidade.

**3.4 Guilda.** No nível 15, os 4-6 bots de maior afinidade formam uma guilda e te convidam (aceitar é opcional).
A guilda tem chat próprio (aba nova), aparece com etiqueta no nome, e uma vez por dia de jogo marca uma **saída de guilda**
(masmorra ou chefe de mundo, ver `momentos-do-mundo.md`) em que os membros vão juntos.

**3.5 Pedido de socorro.** De vez em quando (`BOT_HELP_EVERY` min) um bot do elenco em apuros (vida baixa, cercado,
chefe) pede ajuda no chat com o lugar. Uma marca aparece no minimapa por `BOT_HELP_WINDOW` s. Chegar e ajudar dá
afinidade e um pequeno prêmio (poção, ouro); ignorar não tira nada.

**3.6 Comemorar com você.** Lendário, carta (ver `cartas.md`), nível novo, chefe: os bots próximos e do elenco reagem
no chat. É o retorno social para as conquistas.

## 4. Formulas

- Afinidade: `afinidade = clamp(soma(peso[lembrança]), -100, 100)`; pesos em `Balance.BOT_MEMORY_WEIGHT`
  (salvou +15, grupo +10, ajudou_pedido +20, abandonou -15, perdeu_saque -5).
- Rival: `nível_rival = clamp(nível_jogador + desvio, nível_jogador - 1, nível_jogador + 1)`, desvio sorteado a cada
  `RIVAL_STEP_MIN` min de jogo.
- Pedido de socorro: em média 1 a cada `BOT_HELP_EVERY` (15) min de jogo, só se o bot estiver em mapa a até 1 portal.

## 5. Edge Cases

- Bot do elenco morre: renasce como hoje; a memória fica.
- Save antigo: na 1ª carga sorteia o elenco a partir dos bots de agora (nomes mantidos).
- Rival no seu grupo: pode (ele fala diferente); a corrida de chefe fica suspensa enquanto estão juntos.
- Guilda com bot de afinidade que caiu abaixo de 0: ele sai da guilda com uma fala.
- Elenco nunca mais de `ROSTER_MAX` (12): bots com afinidade 0 e sem lembrança há muito tempo podem ser trocados.

## 6. Dependencies

`BotBrain` (pedido de socorro, ir à saída de guilda), `BotsCatalog` (falas por personalidade e por lembrança),
`BotLeaderSystem` (saída de guilda com líder bot), `PartySystem` (lembranças de grupo), `SaveSystem` (campo novo `roster`),
`hud` (aba Guilda no chat, etiqueta no nome), `Minimap` (marca de pedido), `momentos-do-mundo.md` (chefes de mundo), `casa-de-leiloes.md` (parte da vitrine é assinada pelo elenco, `AUCTION_ROSTER_SHARE`).

## 7. Tuning Knobs

`ROSTER_SIZE` (8-12), `BOT_MEMORY_WEIGHT`, `BOT_HELP_EVERY`, `BOT_HELP_WINDOW`, `RIVAL_STEP_MIN`, `GUILD_LEVEL` (15),
`BOT_CAST_LINE_GAP` (falas por minuto do elenco).

## 8. Acceptance Criteria

- Salvar e carregar mantém nomes, níveis, personalidade e lembranças do elenco (check de save).
- Salvar um bot do elenco (curar abaixo de 25%) cria a lembrança `salvou` (check).
- O rival nunca fica mais de 1 nível longe do jogador em 2 h simuladas (sonda).
- Pedido de socorro: marca no minimapa e prêmio ao chegar (check + foto).
- Em 30 min no Vale, o elenco fala no máximo `N` linhas (sonda de chat; nada de spam).

## 9. Decisões do usuário (2026-11-25)

1. **Elenco de 10** bots por save.
2. **Um rival só**, que acompanha o jogador (±1 nível) o jogo inteiro.
3. **Guilda: convite no 15, opcional**; quem recusa pode fundar depois num NPC de guilda.
4. **Afinidade negativa nunca recusa grupo**: só muda as falas (comentário seco). Tira "recusa grupo" de §3.2.
5. **(2026-11-26) Rival de OUTRA classe, por tabela fixa** (`RIVAL_CLASS`): Paladino↔Berserker, Bispo↔Necromante, Druida↔Elementalista, Ranger↔Assassino.
6. **(2026-11-26) A guilda chega com nome dado pelos bots** (lista em `BotsCatalog`); quem funda a própria no NPC digita o nome.
