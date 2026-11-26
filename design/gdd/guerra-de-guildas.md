# Guerra de Guildas (GvG) — cerco de castelo

> Status: **APROVADA PARA IMPLEMENTAR** (2026-11-26, pedido do usuário: "guilda contra guilda, dois castelos, um ataca, outro defende,
> inteligência dos bots, chat, táticas, canhões, destruir o portão"). Nada implementado. Decisões em §0 e §9.
> Depende de `bots-com-memoria.md` (a guilda e as guildas de bots). Reaproveita o Cerco Vivo (`SiegeSystem`), as
> sentinelas (`GuardBrain`), o bot líder (`BotLeaderSystem`) e os círculos avisados (`barrage`).

## 0. Decisões do usuário (2026-11-26)

| # | Pergunta | Decisão |
|---|---|---|
| D1 | Quem luta | **Sua guilda contra guildas de bots** (várias guildas de bots existem no mundo). |
| D2 | Quando | **O jogador começa** pela janela da Guilda, quando quiser; prêmio por vitória. |
| D3 | Forma | **Dois castelos**: um lado ataca, o outro defende; canhões; destruir o portão; táticas e chat dos bots. |

## 1. Overview

Na janela da Guilda, aba **"Guerra"**: o jogador escolhe uma guilda de bots e **ataca o castelo dela** ou **defende o
castelo da sua guilda** contra ela. O mapa da guerra (`gvg_field`) tem **dois castelos frente a frente** separados por um
campo com pontes e ruínas. Quem ataca tem de: (1) **derrubar o portão** do castelo inimigo (aríete, canhões, magia),
(2) tomar o pátio e (3) **quebrar o Cristal do Trono** no salão. Quem defende segura até o relógio acabar. Os dois lados
têm **canhões** nas muralhas e no campo. Os bots da guerra têm papéis, recebem **ordens** de um comandante no chat da
guilda e mudam de tática conforme a luta.

## 2. Player Fantasy

"Todos no portão leste!" O jogador é parte de um exército que pensa: o comandante bot grita o plano, o aríete avança
coberto pelos escudos, os canhões abrem buraco na muralha, o portão cai com um estrondo e a guilda inteira corre pelo
pátio. Na defesa: segurar a escada com três amigos enquanto os canhões varrem a ponte.

## 3. Detailed Rules

**3.1 Começar.** Guilda → Guerra → escolher a guilda de bots (cada uma com nome, brasão, força e personalidade:
"Lanternas de Aldara — defensiva", "Lobos de Ferro — agressiva") → **Atacar** ou **Defender** → tela de preparação
(30 s: escolher papel, ver o mapa com o plano do comandante) → mapa da guerra, instância própria.

**3.2 Lados.** Cada lado = `GVG_SIDE_SIZE` (12) combatentes: o jogador + os bots da guilda + **recrutas** (bots com a
etiqueta da guilda, gerados para completar). Níveis **igualados** ao do jogador (bots no nível dele ± 1; atributos de
equipamento do nível, como na sonda). O lado inimigo tem a mesma conta.

**3.3 O mapa** (`gvg_field`, Blender novo, ~200 × 120 m):
- dois castelos (norte e sul) com **muralha**, **portão principal** (destrutível), **portão lateral** menor (destrutível,
  mais fraco, longe), **pátio**, **escada** para o salão e o **Cristal do Trono**;
- campo no meio: rio com 2 pontes, ruínas para se cobrir, um morro com uma **bateria de canhões neutra** (quem toma, usa);
- pontos de renascer: atrás de cada castelo; o atacante ganha um renascer avançado ao derrubar o portão.

**3.4 Objetos de cerco** (entidades novas da sim, com vida, sem IA própria):
- **Portão**: vida alta, só leva dano de aríete, canhão e skill de área/cerco (golpe comum faz 10%). Caiu = vira passagem.
- **Aríete**: o atacante tem 2; anda devagar para o portão quando há ≥ 3 aliados em volta (empurrar); bate a cada 3 s.
  Pode ser destruído pelos defensores.
- **Canhão**: fixo; quem fica do lado e aperta **F** opera (bots também). Atira a cada `GVG_CANNON_CD` s um **círculo
  avisado** (mesma gramática dos `barrage` de chefe: aviso, depois o impacto) no ponto mirado; dano alto em área, ×3 em
  aríete e portão. Muralha: 4 canhões por castelo; morro: 2 neutros.
- **Cristal do Trono**: vida alta; quebrar = vitória do atacante. Regenera devagar se nenhum atacante estiver perto.

**3.5 Vitória.** Atacante: quebrar o Cristal antes do fim do relógio (`GVG_TIME_MIN` 20 min). Defensor: chegar ao fim do
relógio com o Cristal de pé. Renascer: `GVG_RESPAWN_S` (15 s, +5 s a cada morte do mesmo boneco, teto 35 s).

**3.6 Inteligência dos bots** (`GvgBrain`, por cima do `BotBrain`):
- **Papéis** (pela build): Muro (tanques: escoltam o aríete / seguram a escada), Cura (atrás do muro), Artilharia
  (operam canhões; os de longe), Ponta (dano corpo a corpo: matam os canhoneiros e os curas inimigos), Batedores
  (assassinos/rangers: flanqueiam pelo portão lateral).
- **Comandante** (o bot de maior afinidade/nível da guilda, ou o jogador se quiser): escolhe um **plano** no começo e troca
  quando a luta muda. Planos do atacante: *Martelo* (tudo no portão principal), *Pinça* (principal + lateral), *Bateria*
  (primeiro tomar o morro dos canhões), *Cerco Lento* (canhões derrubam o portão, ninguém se expõe). Do defensor:
  *Muralha* (todos em cima), *Surtida* (sair e queimar os aríetes), *Recuo* (abrir mão do portão e segurar a escada).
- **Troca de plano** por gatilhos: aríetes perdidos, portão abaixo de 30%, metade do lado morto, morro perdido, 5 min
  restantes. A personalidade da guilda pesa (agressiva tenta Martelo/Surtida mais).
- **Chat**: o comandante anuncia o plano e as trocas no chat da guilda ("Portão em 30%! Muro no aríete, Ponta nos
  canhões da esquerda!"); os outros respondem em poucas falas. O lado inimigo também fala (no chat geral, como "ouvido do
  campo": "eles estão vindo pela lateral!"), dando pistas ao jogador. Limite de falas para não virar spam.
- **Ordens do jogador**: comandos no chat (`/plano martelo`, `/todos portao`, `/canhoes`, `/recuar`) e uma roda de
  ordens (tecla nova) com 6 ordens; os bots obedecem por `GVG_ORDER_HOLD_S` s e voltam ao plano.

**3.7 Prêmio por vitória** (D2): ouro, **Insígnias de Guerra** (loja de guerra: cosméticos de castelo/estandarte, título,
cores de montaria da guilda) e afinidade com todos os bots da guilda que lutaram. Derrota: metade das insígnias.
Sem perda de XP nas mortes da guerra.

## 4. Formulas (propostas)

- Vida do portão = `GVG_GATE_HP` × nível; um aríete sozinho derruba em ~4 min; aríete + 2 canhões em ~1,5 min.
- Canhão: dano = `GVG_CANNON_POWER` × ATK de um bot do nível, raio 3 m, aviso 1,2 s, recarga 6 s.
- Meta de duração: vitória do atacante em 10-16 min com lados iguais; defensor vence ~45-55% (sonda `gvg_probe`).
- Desempenho: 24 combatentes + objetos ≤ 10 ms/tick; FPS ≥ 40 (o Cerco Vivo com 85 invasores deu 21 fps: aqui são 24).

## 5. Edge Cases

- Jogador morre e o comandante é ele: as ordens dele ficam até alguém dar outra.
- Aríete preso em obstáculo: volta ao último ponto da estrada.
- Canhão sem operador: parado. Dois querem o mesmo canhão: o primeiro fica.
- Jogador sai no meio: derrota.
- Guilda com menos de 12 bots: completa com recrutas.
- Bot do elenco morre na guerra: sem lembrança ruim (é guerra); ajudar um aliado de afinidade dá lembrança `salvou`.

## 6. Dependencies

`bots-com-memoria.md` (guilda, guildas de bots, afinidade, chat da guilda), `SiegeSystem`/`RaidSystem` (marcha por rotas,
levas), `GuardBrain` (defender ponto), `BotLeaderSystem` (plano no chat), `MobSystem.place_barrage`/`hazards` (tiro de
canhão avisado), `MapDef` instância própria, entidades de objeto (portão, aríete, canhão, cristal: tipo novo de entidade
ou monstro parado com flag), `hud` (relógio, vida do portão/cristal, roda de ordens), `KeyBindings` (roda de ordens,
operar canhão = F), `Music` (tema "guerra"), `Sfx` (canhão, portão caindo), **Blender**: `map_gvg_field` (2 castelos),
modelos de aríete, canhão, cristal, estandartes com brasão.

## 7. Tuning Knobs (`data/balance.gd`)

`GVG_SIDE_SIZE` (12), `GVG_TIME_MIN` (20), `GVG_RESPAWN_S` (15/+5/35), `GVG_GATE_HP`, `GVG_SIDE_GATE_MULT` (0,5),
`GVG_CANNON_POWER`, `GVG_CANNON_CD` (6), `GVG_CANNON_SIEGE_MULT` (3), `GVG_RAM_HIT` / `GVG_RAM_PUSHERS` (3),
`GVG_CRYSTAL_HP` / `GVG_CRYSTAL_REGEN`, `GVG_ORDER_HOLD_S` (30), `GVG_PLAN_TRIGGERS`, `GVG_REWARD_*`.

## 8. Acceptance Criteria

1. Portão só cai por aríete/canhão/área em tempo da fórmula (check).
2. Canhão operado por bot acerta aríete inimigo em movimento ≥ 50% dos tiros (sonda).
3. Troca de plano dispara no gatilho certo e aparece no chat (check).
4. `/todos portao` leva ≥ 80% dos bots aliados ao portão em 20 s (check).
5. `gvg_probe` com lados iguais: atacante vence 45-55%, duração média 10-16 min; ≤ 10 ms/tick.
6. Fotos e filme curto (portão caindo, canhões, chat) em `production/qa/evidence/gvg/`.

## 9. Decisões do usuário (2026-11-26)

1. **12 × 12**.
2. **Níveis igualados** ao do jogador (± 1): a guerra vale em qualquer nível.
3. **O castelo só existe na guerra** (o mapa `gvg_field`); nada de sede para visitar.
4. **O bot comandante manda por padrão**; o jogador assume quando quer (roda de ordens / comandos no chat).
