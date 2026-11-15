<!-- RagnaEx manual (pt-BR) — Save e Definition of done. Moved VERBATIM from the old CLAUDE.md on 2026-11-08 (CCGS adoption); imported by CLAUDE.md. Edit here. -->

## Save

`SaveSystem` (autoload): espaços `user://save_<n>.json` (`SLOTS`), `SaveSystem.slot` = personagem em jogo. `--autostart` usa `slot = -1` (não grava)
e os testes usam `TEST_SLOT` (90): nunca apague/grave `save_0..4` em teste ou revisão. Esc → `hud.open_game_menu`; voltar ao menu = `main.return_to_menu`
(`Sim.reset_world` + trocar para `start.tscn`, que abre em Personagens com o card do personagem selecionado; `--autostart=<c> --return_check [--menu_shot=<png> --return_shot=<png>]` confere).

## Definition of done

1. `--import` + testes passam (0 failed) + smoke sem `SCRIPT ERROR`.
2. Nenhum `Node`/`Input` dentro de `core/`.
3. Conteúdo novo tem check nos testes e está no README/`docs/DESIGN.md` se mudar regra.


Estado do espaço: `SaveSystem.slot_state(i)` = `"empty"` (sem arquivo) | `"ok"` | `"corrupt"` (arquivo existe, mas o JSON não lê, é `{}`, não é dicionário ou não tem `class`; classe que saiu do jogo continua `ok`).
`has_slot`/`has_save` contam o corrompido (a lista abre para poder excluir); `first_free_slot()` só devolve vazio; `slot_summary`/`load_data` dão `{}` se não for `ok`. Card corrompido = "Save danificado", só Excluir.
Gravação atômica: `save_player` escreve `save_<n>.json.tmp` (flush + erro checado) e renomeia por cima; falha apaga o `.tmp` e mantém o save velho. `.tmp` solto é resolvido por `_settle_tmp` (no boot e em todo `slot_state`):
save principal ok vence e o `.tmp` some; principal faltando/corrompido + `.tmp` válido = o `.tmp` vira o save. `delete_slot` apaga `.json`, `.json.tmp` e `user://portrait_<n>.png`. Formato do save inalterado.
Retrato do card: `Portrait.capture(view, slot)` (game/menu/portrait.gd, corrotina de 2 quadros, 256x256 transparente) em `user://portrait_<n>.png`; não captura em headless nem no espaço -1. Ponto de salvar do jogo: `main.save_game()`
(autosave, Esc → Salvar/Sair, fechar a janela); `return_to_menu` espera `PORTRAIT_FRAMES` antes de trocar de cena. Fotos do menu usam `--menu_saves` (saves falsos em memória, ids 90+) ou `TEST_SLOT`.
