# Introdução dos Sistemas — um de cada vez

> Status: **APROVADA PARA IMPLEMENTAR** (2026-11-25, revisão de diversão). Nada implementado. Decisões do usuário em §9 (vencem o texto acima delas).

## 1. Overview

O jogo tem sistemas demais para aprender de uma vez: teia de skills, talentos, ranks no Mestre de Skills, evoluções,
cargas, dash, conjuntos e Ápices, híbridos e Fusões, aprimoramento +1..+9, bolsas, ascensão, Suprema. Cada um é bom,
juntos confundem. Esta proposta **libera cada sistema numa hora marcada**, com uma cena curta e uma tarefa pequena,
**esconde o que ainda não abriu**, e põe um botão **"Recomendado"** na teia e nos talentos para quem não quer planejar.

## 2. Player Fantasy

"Toda hora tem uma coisa nova, e eu entendo cada uma." O jogador sente que o personagem cresce em camadas: a cada poucos
níveis um mestre, um ferreiro ou um capitão chama e ensina uma coisa. Nada de janela cheia de botões travados no nível 1.

## 3. Detailed Rules

**3.1 Calendário de liberação** (proposta; os níveis podem mudar no teste de jogo):

| Nível | Sistema | Quem ensina | Tarefa |
|---|---|---|---|
| 1 | Básico, 2 skills, dash, poção | Capitã Mira | matar 3 javalis usando o dash |
| 2 | Teia de skills (só a vizinhança do Início) | Ancião Ravi | gastar 1 ponto |
| 4 | Bolsa, vender, loja | Mercador Tobias | vender 1 item |
| 5 | Talentos de classe (1ª linha) | Mestre de Skills | escolher 1 talento |
| 6 | Grupo com bots | Capitã Mira | convidar 1 bot e matar 5 monstros juntos |
| 8 | Ranks de skill | Mestre de Skills | subir 1 skill ao rank 2 |
| 10 | Conjunto lendário (2 peças) e saque de chefe | Ferreiro Brom | vestir 2 peças do mesmo conjunto |
| 12 | Aprimoramento +1..+9 | Ferreiro Brom | aprimorar 1 peça ao +1 |
| 15 | Bolsas | Alquimista Lyra | vestir 1 bolsa |
| 20 | Evoluções e cargas | Mestre de Skills | comprar 1 evolução |
| 30 | Ápice e híbridos | Relicária | ver as opções |
| 35 | Ascensão | já existe (missão `hx_asc_<classe>`) | — |
| 40 | Suprema | já existe | — |

**3.2 Esconder o que não abriu.** Janela, aba ou botão de sistema não liberado **não aparece** (em vez de cinza): a barra
de atalhos do HUD (I C J K L P M) mostra só os liberados; a aba Talentos aparece no 5; a aba Ascensão no 35 (já é assim).
Save antigo: tudo que o nível dele já passou fica liberado na hora (sem refazer tarefas).

**3.3 Cena curta.** Ao chegar no nível, o NPC dono do sistema ganha "!" e o HUD mostra um aviso de uma linha
("O Mestre de Skills quer falar com você"). A conversa tem no máximo 3 falas e termina numa tarefa de 1-3 min.
As dicas atuais (`Tips`) passam a sair junto da cena em vez de soltas.

**3.4 Botão "Recomendado".** Na teia: gasta os pontos livres no caminho que o bot da mesma build compraria
(`ProgressionSystem.bot_spend` já decide isso). Nos talentos: marca a opção que o bot escolheria (`ClassTalentSystem.bot_score`).
As compras propostas acendem na teia/talentos e o jogador clica Confirmar (§9.3).

**3.5 Pular tudo.** Caixa "Já conheço o jogo" na Criação, por personagem (marcada por padrão quando já existe outro
personagem): libera tudo de uma vez (§9.4).

## 4. Formulas

Sem números novos de jogo. Os níveis do calendário ficam em `Balance.UNLOCK_LEVELS` (tabela sistema → nível).

## 5. Edge Cases

- Começos rápidos de debug (presets 10/16/20/30): liberam tudo até o nível do preset.
- Bots: não passam por isso (já usam todos os sistemas).
- Jogador pula o NPC: o sistema libera mesmo assim depois de `UNLOCK_GRACE_LEVELS` (2) níveis, para não travar ninguém.
- Recomendado com pontos de respec: só gasta pontos livres, nunca desfaz escolhas do jogador.

## 6. Dependencies

`hud` (barra de atalhos), `windows` (abas), `QuestSystem` (tarefas como quests curtas de tutorial), `Tips`,
`ProgressionSystem.bot_spend`, `ClassTalentSystem.bot_score`, `SaveSystem` (lista `unlocked`), `settings_panel`.

## 7. Tuning Knobs

`UNLOCK_LEVELS`, `UNLOCK_GRACE_LEVELS`, texto das cenas (writer).

## 8. Acceptance Criteria

- No nível 1 o HUD mostra só bolsa e personagem; cada sistema aparece no nível da tabela (check por nível).
- Save antigo no nível 25 abre com tudo até o 25 liberado.
- "Recomendado" gasta exatamente o que o `bot_spend` gastaria para a build (check).
- Teste de jogo com alguém novo: sabe dizer o que cada janela faz no fim da primeira hora.

## 9. Decisões do usuário (2026-11-25)

1. **Esconder** o que não abriu (some, não fica cinza) — como §3.2.
2. **Calendário aprovado como está** (§3.1); níveis revistos depois do teste dos primeiros 10 min.
3. **"Recomendado" com prévia + confirmar**: as compras propostas acendem na teia/talentos e o jogador clica Confirmar.
4. **"Já conheço o jogo" na Criação, por personagem**: caixa na Criação, marcada por padrão quando já existe outro personagem;
   cada personagem guarda a sua escolha (a opção nas Configurações de §3.5 sai).
