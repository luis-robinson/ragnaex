<!-- RagnaEx manual (pt-BR) — Save e Definition of done. Moved VERBATIM from the old CLAUDE.md on 2026-11-08 (CCGS adoption); imported by CLAUDE.md. Edit here. -->

## Save

`SaveSystem` (autoload): espaços `user://save_<n>.json` (`SLOTS`), `SaveSystem.slot` = personagem em jogo. `--autostart` usa `slot = -1` (não grava)
e os testes usam `TEST_SLOT` (90): nunca apague/grave `save_0..4` em teste ou revisão. Esc → `hud.open_game_menu`; voltar ao menu = `main.return_to_menu`
(`Sim.reset_world` + recarregar a cena; `--autostart=<c> --return_check [--menu_shot=<png> --return_shot=<png>]` confere).

## Definition of done

1. `--import` + testes passam (0 failed) + smoke sem `SCRIPT ERROR`.
2. Nenhum `Node`/`Input` dentro de `core/`.
3. Conteúdo novo tem check nos testes e está no README/`docs/DESIGN.md` se mudar regra.
