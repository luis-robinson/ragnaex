# Auto-Poção — beber sozinho abaixo de um % de vida ou mana

> Status: **APROVADA PARA IMPLEMENTAR** (2026-11-26, pedido do usuário: "uma opção pequena para configurar auto pot quando a
> mana ou a vida cair abaixo de um % configurável"). Decisões do usuário em §9. Nada implementado.

## 1. Overview

Uma opção por personagem, nas Configurações (Esc), que bebe sozinha a poção de uma vaga da barra (F1-F3) escolhida pelo
jogador quando a **vida** ou a **mana** cai abaixo de um % escolhido, e que **renova um elixir** quando o efeito dele acaba
durante uma luta. Três linhas independentes (Vida / Mana / Elixir). Não muda o poder: poção, estoque e recarga são os
mesmos de apertar a tecla; a opção só tira o "esqueci de beber" no meio da luta.

## 2. Player Fantasy

"Estou lutando, não olhando a barra." O jogador se concentra em mirar, esquivar e encadear skills; a poção sai no momento
que ele escolheu. Quem gosta de controlar cada gole deixa desligado.

## 3. Detailed Rules

**3.1 Configuração (por personagem).** Guardado no save do personagem (`auto_potion`):

| Linha | Campos | Padrão de personagem novo |
|---|---|---|
| Vida | `hp_on`, `hp_slot` (0-2), `hp_pct` | desligada, F1, 40% |
| Mana | `mp_on`, `mp_slot`, `mp_pct` | desligada, F2, 20% |
| Elixir | `elx_on`, `elx_slot` | desligada, F3 |

% de 10 a 90, em passos de 5.

**3.2 Onde se mexe (UI).** Aba **"Auto-poção"** no painel de Configurações (`settings_panel.gd`), aberto pelo Esc no jogo.
A aba só aparece com personagem em jogo (no Título não há personagem). Layout:
```
 Auto-poção
 [x] Vida    vaga [F1 v]   abaixo de [ 40% ] (- +)
 [ ] Mana    vaga [F2 v]   abaixo de [ 20% ] (- +)
 [ ] Elixir  vaga [F3 v]   renova quando o efeito acaba, só em luta
```
A vaga mostra o nome da tecla atual (`KeyBindings.short("potion_N")`). Na barra, a vaga com uma linha ligada ganha um "A"
pequeno no canto (o jogador vê que está armado sem abrir o menu).

**3.3 Regra na sim (Vida e Mana).** A cada tick, para o **jogador** com alguma linha ligada (bots continuam com a regra
própria do `BotBrain`): se vivo e `hp < max_hp × hp_pct/100`, chama o mesmo `ItemSystem.use_potion(sim, e, hp_slot)` da
tecla, **só se** o item da vaga cura vida (`consume.heal`/`heal_pct`), tem estoque e a recarga da vaga está zerada.
Mana igual (`consume.mana`/`mana_pct`, `mp_slot`). Item da vaga que não é do tipo da linha: não bebe (aviso §3.5).
Vida e mana no mesmo tick: vida primeiro; se as duas linhas apontam para vagas diferentes, as duas podem sair.

**3.4 Regra na sim (Elixir).** Se `elx_on`, o item de `elx_slot` tem `consume.buff`, o jogador **está em luta** e **não
tem** o buff daquele elixir (id do `consume.buff`), bebe (mesmo `use_potion`, mesma recarga). "Em luta" = recebeu ou causou
dano nos últimos `AUTO_POTION_COMBAT_S` s. Fora de luta o elixir não é gasto (ele acaba e espera a próxima briga).

**3.5 Sem poção / vaga errada.** Linha ligada, condição verdadeira e a vaga não serve (vazia, sem estoque, tipo errado):
aviso "Auto-poção: sem poção de vida em F1" (mana / elixir igual) **uma vez**, até a vaga voltar a servir. Recarga só
espera, sem aviso.

**3.6 Onde vale.** Em qualquer mapa, montado ou não, em conjuração ou não (igual à tecla hoje). Morto não bebe.
A Carga Suprema continua sem encher com poção (`ult_quiet`, já existe).

## 4. Formulas

- Vida: dispara quando `hp < max_hp × hp_pct / 100` (mana: `mp < max_mp × mp_pct / 100`).
- Elixir: dispara quando `em_luta and not e.has_buff(buff_id)`; `em_luta = (t_agora − t_ultimo_dano) <= AUTO_POTION_COMBAT_S`.
- Exemplo: 1.200 de vida, 40% → bebe abaixo de 480. Poção (M) cura 35% = 420 → volta a ~900. Recarga 4 s: com dano
  alto ela sai de novo a cada 4 s enquanto ficar abaixo, o mesmo ritmo de quem aperta F1 sem parar.
- Exemplo elixir: Elixir da Força dura 45 s; numa caçada contínua sai 1 a cada ~45 s (80/h); entre lutas não gasta.
- Nenhum ganho de poder além do tempo de reação: `consume_cooldown`, preço e efeito não mudam.

## 5. Edge Cases

- **Duas linhas na mesma vaga** (ex.: Vida e Mana em F1): permitido; cada uma só bebe se o item for do seu tipo.
- **Vida máxima muda** (buff, forma, Vida da Fé): o limite usa o `max_hp` do tick.
- **Escudo absorvente**: conta só a vida.
- **Jogador troca a poção da vaga** (arrastar outra para F1): a linha segue a vaga, não o item.
- **Buff do elixir já ativo por outra fonte** com o mesmo id: não bebe (a regra é "não tem o buff").
- **Save antigo** sem `auto_potion`: padrões de §3.1 (campo opcional, sem `save_version` novo).
- **Autostart/testes** (`slot = -1`, `TEST_SLOT`): começa desligado; os checks ligam à mão.
- **Bots**: não usam esta opção; regra própria intacta (calibragem das sondas não muda).

## 6. Dependencies

- `core/sim/entity.gd` (campo `auto_potion` + hora do último dano, se ainda não houver), `ItemSystem.auto_potion(sim, e)`
  (usa o `use_potion` existente), chamada no `WorldSim.tick` só para o jogador, repasse `Sim.set_auto_potion(...)`.
- `SaveSystem` (grava/lê `auto_potion` com padrão).
- `game/menu/settings_panel.gd` (aba nova, só com personagem em jogo), `game/ui/action_bar.gd` (o "A" na vaga),
  `KeyBindings.short` (nome da tecla da vaga).
- `Events.notification` (aviso de §3.5).

## 7. Tuning Knobs (`data/balance.gd`)

| Constante | Proposta | Faixa segura | O que muda |
|---|---|---|---|
| `AUTO_POTION_HP_DEFAULT` | 40 | 25-60 | % de vida de quem nunca mexeu |
| `AUTO_POTION_MP_DEFAULT` | 20 | 10-40 | % de mana de quem nunca mexeu |
| `AUTO_POTION_PCT_MIN` / `MAX` | 10 / 90 | 5-95 | limites do ajuste |
| `AUTO_POTION_PCT_STEP` | 5 | 5-10 | passo do (- +) |
| `AUTO_POTION_COMBAT_S` | 5 | 3-10 | quanto tempo depois do último dano ainda conta como "em luta" (elixir) |

## 8. Acceptance Criteria

1. Vida abaixo do % com poção de vida na vaga da linha e recarga zerada → bebe no mesmo tick; estoque −1, recarga da vaga = 4 s.
2. Linha desligada → não bebe em nenhum %.
3. Linha de Vida apontando para vaga com poção de mana → não bebe; aviso de §3.5 aparece uma vez.
4. Vida e mana abaixo, linhas em vagas diferentes → as duas saem no mesmo tick.
5. Elixir ligado: em luta e sem o buff → bebe; com o buff ativo → não; fora de luta (> 5 s sem dano) → não.
6. Save com `auto_potion` grava e lê todos os campos; save sem o campo abre com os padrões.
7. Bots não mudam (soma do `sim_probe` igual com o jogador desligado).
8. Aba "Auto-poção" some no Título e aparece no Esc do jogo.
9. Foto da aba e do "A" na vaga em `production/qa/evidence/auto-pocao/`.
Check `_check_auto_potion` (`--only=auto_potion`).

## 9. Decisões do usuário (2026-11-26)

1. **Onde configurar**: nas **Configurações (Esc)**, aba própria (não na barra).
2. **Padrão**: **desligado**, com 40% de vida e 20% de mana já preenchidos.
3. **Vaga**: **o jogador escolhe** a vaga de cada linha (F1/F2/F3).
4. **Elixires**: **3ª linha "renovar elixir"** quando o efeito acaba, só em luta.
Decisões menores minhas: elixir padrão em F3; "em luta" = dano nos últimos 5 s; o "A" na barra fica (só indicador).
