# Prêmios de MVP — o que o Chefe de Mundo dá

> Status: **APROVADA PARA IMPLEMENTAR** (2026-11-26, pedido do usuário). Nada implementado. Decisões do usuário em §0 e §9.
> Depende de `momentos-do-mundo.md` (o Chefe de Mundo ainda não existe). Liga com `cartas.md` (Carta de MVP),
> `casa-de-leiloes.md` (vender pergaminhos/cosméticos), `forja-e-refino-ui.md` (usar o pergaminho no ferreiro).

## 0. Decisões do usuário (2026-11-26)

| # | Pergunta | Decisão |
|---|---|---|
| D1 | Quem é "MVP" | **Só os Chefes de Mundo** (um por faixa, `momentos-do-mundo.md` §3.1) |
| D2 | O que dá além da carta rara | **Pergaminho de Refino, Moedas de MVP + loja, Baú "escolha 1 de 3" (pacotes de material de refino, não peças), cosméticos** |
| D3 | Cosméticos | **Cor de montaria, armadura de montaria, tipos novos de montaria** (substitui o cavalo) + **aba Montaria** |
| D4 | Pergaminho de Refino | **Direto para +5**: peça em +0..+4 vira +5 no ferreiro, sem ouro nem minério. Versão rara do fim do jogo: +5/+6 → +7 |

## 1. Overview

Cada Chefe de Mundo (MVP) tem uma **mesa de prêmios** própria. Todo participante que passou do mínimo de dano/cura
(`WORLD_BOSS_SHARE_MIN`, prêmio igual para todos) recebe: XP, **Moedas de MVP**, um **Baú do MVP** (escolhe 1 de 3 pacotes
de material de refino) e sorteios independentes de **Pergaminho de Refino**, **cosmético de montaria** do chefe e da **Carta de MVP**.
As moedas compram na **loja do Intendente das Caçadas** o que a sorte não deu, então nenhuma luta é perdida.

## 2. Player Fantasy

"Hoje eu vou no MVP." A luta a cada ~40 min é o encontro do servidor, e o jogador sai sempre com alguma coisa: uma peça
escolhida, moedas para a meta dele, e às vezes o prêmio raro que todo mundo vê: o lobo de armadura dourada que só o
Rei do Pântano dá.

## 3. Detailed Rules

**3.1 Mesa de prêmios** (por participante, sorteios independentes; `MVP_TABLE[<chefe>]`):

| Prêmio | Chance | Observação |
|---|---|---|
| XP | sempre | `WORLD_BOSS_XP` × XP da faixa (já em `momentos-do-mundo`) |
| Moedas de MVP | sempre | `MVP_COINS[<faixa>]` |
| Baú do MVP | sempre | 1 de 3 pacotes de material de refino (§3.2) |
| Pergaminho de Refino (+5) | `MVP_SCROLL_CHANCE` 25% | §3.3 |
| Pergaminho Superior (+7) | 8%, só faixas 40-45 e 45-50 | §3.3 |
| Cosmético de montaria do chefe | `MVP_COSMETIC_CHANCE` 5% | 1 dos itens do chefe que você ainda não tem (§3.4) |
| Carta de MVP | `MVP_CARD_CHANCE` 2% | carta de núcleo do chefe (`cartas.md`) |

**3.2 Baú do MVP** (mudança do usuário, 2026-11-26: material, não peça). Item na bolsa; abrir mostra **3 pacotes de
material de refino** da faixa do chefe (`MVP_CHEST[<faixa>]`); escolhe 1, os outros somem. Cada pacote é um material do
refino daquela faixa numa quantidade que vale ~1-2 passos de refino. Exemplos (calibrar):

| Faixa | Pacote A | Pacote B | Pacote C |
|---|---|---|---|
| 1-10 | 5 Minério de Ferro | 2 Minério Estelar | 300 ouro + 2 Minério de Ferro |
| 10-20 | 8 Minério de Ferro | 3 Minério Estelar | material élfico ×3 |
| 20-30 | 3 Minério Estelar | Prata Consagrada ×3 | Fragmento da Aurora ×2 |
| 30-40 | 4 Minério Estelar | Prata Consagrada ×4 | Fragmento da Aurora ×3 |
| 40-45 / 45-50 | Aço Anão ×5 | Brasa de Kharzun ×2 | 4 Minério Estelar + ouro |

O pacote mais raro (o "minério de ouro" de cada faixa: Estelar, Fragmento, Brasa) vem em quantidade menor. Pode guardar o
baú fechado; o conteúdo é o da faixa do chefe que deu o baú.

**3.3 Pergaminho de Refino.** Usado no ferreiro (aba do refino, `forja-e-refino-ui.md`):
- **Pergaminho de Refino**: peça em +0..+4 → **+5**, sem ouro nem material. Vale em qualquer peça e qualquer tier
  (inclusive lendário 40+, que hoje só o Ferreiro Anão aprimora: o pergaminho vale em qualquer ferreiro).
- **Pergaminho Superior**: peça em +5..+6 → **+7**.
- Não quebra (como o refino de hoje), não passa de +7. Vendável na Casa de Leilões; o mercador não compra.

**3.4 Cosméticos de montaria** (só aparência, sem poder; §9):
- **Tipos novos de montaria**: cada chefe de mundo tem um tipo temático (ex.: Javali de Guerra na Campina, Alce do Bosque,
  Lagarto das Ruínas, Corcel da Aurora, Lobo de Kharzun Couraçado, Gamo de Porcelana em Lumeria). Ganhar = destrava o tipo.
  Mesma velocidade e regras do cavalo (`MOUNT_SPEED_MULT`, montada do Paladino igual).
- **Cores**: paleta por tipo (`MOUNT_DYES`), 3-4 por chefe.
- **Armaduras de montaria** (barda): 1-2 por chefe, servem em todo tipo que tem o encaixe (sela/peitoral/testeira).
- Tudo fica numa coleção da conta do personagem (`mount_cosmetics`), não na bolsa: não ocupa espaço.

**3.5 Aba Montaria** (janela do personagem C, aba nova; substitui a troca de tipo no Tratador, que passa a só destravar
o Lobo Atroz pela quest como hoje):
```
 Montaria
 [prévia 3D girando da montaria escolhida, com cor e armadura]
 Tipo:     Cavalo · Lobo Atroz · Javali de Guerra (travado: "MVP da Campina") ...
 Cor:      [o][o][o][o]   (travadas em cinza com de onde vem)
 Armadura: Nenhuma · Barda de Bronze · Barda do Javali ...
```
O que escolher vale ao montar (H). O ícone do H segue o tipo (já existe `ActionBar.set_mount_kind`).

**3.6 Moedas de MVP e a loja.** "Insígnia de Caçada" (moeda, não pesa na bolsa, como o ouro). NPC **Intendente das
Caçadas** nas capitais (Aldara, Bastião, Kharzun, Lumeria; papel novo de serviço com ícone, `NpcServices`). Loja:
- Pergaminho de Refino: `MVP_SHOP_SCROLL` 12 insígnias (~4 lutas da faixa média).
- Pergaminho Superior: 40 (só com nível 40+).
- Cores e armaduras de montaria de qualquer chefe que você **já enfrentou** (participou ao menos uma vez): 15-30.
- Tipo de montaria de um chefe: 60, só depois de ter enfrentado aquele chefe 5 vezes.
- **Não** vende carta (fica rara de verdade) nem Baú.

**3.7 Bots.** Bots também ganham (gastam as insígnias em pergaminhos, que entram no aprimoramento deles); às vezes aparecem
com a montaria nova (vitrine para o jogador: "onde você achou esse javali?").

## 4. Formulas (propostas)

| Faixa | Insígnias por luta | Pergaminho na loja | Lutas por pergaminho (só loja) |
|---|---|---|---|
| 1-10 | 2 | 12 | 6 |
| 10-20 | 3 | 12 | 4 |
| 20-30 | 3 | 12 | 4 |
| 30-40 | 4 | 12 | 3 |
| 40-45 / 45-50 | 5 | 12 (Superior 40) | 2-3 (Superior 8) |

- Pergaminho por luta (sorteio + loja), faixa 20-30: 0,25 + 3/12 = **~0,5 por luta** → 1 por ~80 min de jogo (MVP a cada 40).
- Valor de um +0→+5 hoje (tier médio): soma do `enhance_cost` +1..+5 ≈ 5 × 155 ouro + 20 minérios. O pergaminho poupa
  isso; não dá poder novo acima do que o ouro já compra.
- Cosmético: 5% por luta → ~1 a cada 20 lutas (~13 h) pela sorte; pela loja, a cor mais barata sai em 5 lutas.

## 5. Edge Cases

- Participante abaixo do mínimo de dano/cura: nada (regra de `momentos-do-mundo`).
- Bolsa cheia: Baú e pergaminho vão para o **correio do Intendente** (pega depois); insígnias e cosméticos não usam bolsa.
- Cosmético repetido (já tem tudo do chefe): vira `MVP_DUP_COINS` insígnias.
- Pergaminho em peça +5 ou mais (normal) / +7 (Superior): botão desligado com o motivo.
- Personagem de nível muito acima da faixa do chefe: ganha insígnias e cosméticos normalmente; o Baú traz o material da faixa do chefe.
- Save antigo: sem `mount_cosmetics`/insígnias = vazio; tipo de montaria atual (`mount`) continua valendo.

## 6. Dependencies

`momentos-do-mundo.md` (Chefe de Mundo, participação), `LootSystem` (mesa, baú), `ItemSystem`/`WorldSim.enhance` (materiais do refino por faixa, `PLUS_*`)
(pergaminho), `GearCatalog`/`gear_pool`, `cartas.md`, `casa-de-leiloes.md`, `NpcServices` (Intendente), `SaveSystem`
(`mvp_coins`, `mount_cosmetics`, `mount_look`), janela C (aba Montaria), `EntityView` montaria (cor/barda/tipos),
**Blender**: um modelo de montaria por tipo novo (`mob_kit.quadruped`) + bardas como peças do kit da montaria,
ícones (`item_icons`, `make_icons`), `KeyBindings`/`ActionBar.mount_icon`.

## 7. Tuning Knobs (`data/balance.gd`)

`MVP_COINS` (por faixa), `MVP_SCROLL_CHANCE` (15-35%), `MVP_SUPER_SCROLL_CHANCE` (5-12%), `MVP_COSMETIC_CHANCE` (3-10%),
`MVP_CARD_CHANCE` (1-3%), `MVP_CHEST` (pacotes por faixa: ~1-2 passos de refino cada), `MVP_SHOP_*` (preços), `MVP_DUP_COINS`, `MVP_MOUNT_FIGHTS` (5).

## 8. Acceptance Criteria

1. Luta simulada com 3 participantes acima do mínimo e 1 abaixo: os 3 recebem XP, insígnias e Baú; o 4º nada (check).
2. Baú: 3 pacotes de material da faixa do chefe; escolher 1 põe só ele na bolsa (check).
3. Pergaminho +5: peça +2 vira +5 sem gastar ouro/minério; em peça +5 recusa (check).
4. Cosmético repetido vira insígnias (check).
5. Aba Montaria: escolher tipo/cor/armadura muda o boneco montado (foto em `production/qa/evidence/mvp/`).
6. Loja: tipo de montaria só aparece comprável depois de 5 lutas daquele chefe (check).
7. Save grava e lê insígnias, coleção e escolha da montaria; save antigo abre sem nada (check).
Checks `--only=mvp`.

## 9. Decisões do usuário (2026-11-26)

1. **Armadura de montaria = só aparência** (sem stat).
2. **Seis tipos novos** na 1ª leva, um por Chefe de Mundo (6 modelos no Blender).
3. **Baú garantido** para todo participante acima do mínimo; **escolhe 1 de 3 pacotes de material de refino** (não peça).
4. **Pergaminho comprável** na loja do Intendente (12 insígnias), além do sorteio.
Nada em aberto. Ordem sugerida: Chefe de Mundo (`momentos-do-mundo`) → este prêmio → aba Montaria + modelos.
