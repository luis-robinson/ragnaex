<!-- RagnaEx manual (pt-BR) — Visão geral, comandos e arquitetura. Moved VERBATIM from the old CLAUDE.md on 2026-11-08 (CCGS adoption); imported by CLAUDE.md. Edit here. -->

# RagnaEx — guia para o Claude Code

Protótipo de "MMO" 2.5D single-player com bots. **Godot 4.7.2 + GDScript**, sem addons.
Arte: Tree of Savior (chibi, pastel, toon 3 tons + outline) · **layout de mundo estilo Erenshor** (zonas orgânicas:
vale fechado, vila murada como hub, estradas curvas, rio com pontes, POIs com marcos — ver "Layout de zonas") ·
câmera Ragnarok (52°, yaw em 45°, a mesma perspectiva de sempre) · combate Drakantos (encara o cursor, LMB básico,
skills com mira MOBA). Leia `README.md` e `docs/DESIGN.md`.

## Comandos

```powershell
# Windows (use o wrapper; ele acha o Godot em Program Files / Downloads / $env:GODOT)
.\tools\godot.ps1 --headless --path . --import                    # (re)gera cache de classes — rode após criar scripts com class_name
.\tools\godot.ps1 --headless --path . tools/tests/tests.tscn      # testes (14000+ checks) — OBRIGATÓRIO antes de terminar uma tarefa
.\tools\godot.ps1 --headless --path . tools/tests/tests.tscn -- --only=party,shield   # só os _check_* com esses nomes (iterar rápido)
.\tools\godot.ps1 --headless --path . -- --autostart=berserker    # smoke test: joga sozinho e sai; 0 "SCRIPT ERROR" é o critério
.\tools\godot.ps1 --path .                                        # abre o jogo com janela
.\tools\godot.ps1 --headless --path . --export-release "Windows Desktop" build/windows/RagnaEx.exe   # gera o jogo (1 .exe, pck dentro)
build\windows\RagnaEx.exe --headless -- --autostart=berserker  # smoke no exportado (pega JSON/arquivo que ficou fora do pacote)
```
Linux/mac: troque `.\tools\godot.ps1` por `godot` (binário 4.7.2 no PATH).

Scripts novos com `class_name` só são vistos pelos outros scripts depois de `--import`.

## Arquitetura (regra de ouro)

- `core/` = **simulação**. Nunca importe/instancie `Node3D`, `Control`, câmera, shaders ou `Input` aqui.
  Tudo que acontece no jogo passa por `core/sim/world_sim.gd` (autoload `Sim`) via `InputCommand`.
  Jogador e bots são a mesma coisa para a sim (só muda quem gera o comando). Isso é o futuro servidor.
- `game/` = **apresentação**. Lê o estado da sim, nunca muda HP/posição/inventário diretamente;
  chama métodos públicos de `Sim` (`equip`, `use_potion`, `upgrade_mastery`, `try_cast`…) ou os
  sistemas estáticos (`QuestSystem`, `CraftSystem`). Reage aos sinais de `core/events.gd` (autoload `Events`).
- `data/` = conteúdo. Schemas (Resources) em `data/schemas/`, dados em `data/catalog/*_catalog.gd`
  (dicionários → Resources em `GameData._ready`). Constantes de balanceamento SÓ em `data/balance.gd`.
- Autoloads (ordem): `Events`, `Balance`, `GameData`, `Sim`, `SaveSystem`.
- `WorldSim` (`class_name`, autoload `Sim`) guarda o estado e roda o tick, spawn, comandos, pipeline de skill, dano/cura/morte,
  movimento. O resto mora em `core/sim/systems/` como funções estáticas `f(sim: WorldSim, ...)`, sem estado próprio:
  `MapGeometry` (colisão, água/pontes, `water_path`, chão andável), `PartySystem`, `LootSystem` (abate, divisão, elites, baú),
  `LegendEffects`, `ShieldSystem`, `ItemSystem` (equipar, poção, aprimorar, relíquia, depósito), `PortalSystem` (portais, portões,
  troca de mapa, recall), `ProgressionSystem` (XP, árvore, talentos, loadout, `resolve_skill`), `GatherSystem`, `NpcSystem`,
  `TrapSystem`, `MobSystem` (aggro, chefe, spawners). Regra nova vai no sistema dela; dentro da sim chame `Sistema.f(self, ...)`.
  O fim do `world_sim.gd` repassa (`Sim.equip`, `Sim.party_invite`...) o que jogo/testes/brains usam: API nova pública = um repasse lá.
- Buff/debuff por id: `SimEntity.put_buff/put_debuff/drop_buff/buff_stacks` (renova, não acumula).
  Dano no tempo bate em pulsos de `Balance.DOT_PULSE_S` (mesmo total); o de monstro renova (`WorldSim._renew_dot`) e dura x`Balance.MONSTER_DOT_TIME_MULT`; o do jogador vai até `Balance.PLAYER_DOT_MAX_STACKS` cópias por skill (id `WorldSim.dot_id`, a mais antiga sai: `_put_dot`; `docs/DESIGN.md` "Dano no tempo").
  Buff novo precisa de visual no corpo: entrada em `BuffLooks.LOOKS` (`game/fx/buff_looks.gd`; há check); revisar com `-- --autostart=<c> --buff_shot=<pasta> [--only=<id>]`.

- **Início do jogo**: cena principal `game/menu/start.tscn` (`start.gd`, máquina de telas), fluxo Título (`title_screen.gd`) → Personagens (`char_list.gd`,
  `delete_dialog.gd`) → Criação (`char_create.gd`, pedestal em `pedestal_preview.gd`) → Carregamento (`loading_screen.gd`, overlay `CanvasLayer` 100 na raiz, não é autoload) → `main.tscn`.
  Cenário 3D `menu_set.gd`, som `menu_audio.gd` (tema `aldara`, barramentos Music/UI), `settings_panel.gd` (Título e Esc do HUD), retrato `portrait.gd`, F11 em `window_keys.gd`.
  Dados entre cenas: `StartRequest` (estático; `new_character(...)`, `returning`, `last_slot`, `error`). No menu a `Sim` fica vazia (nada de `load_map` antes do Carregamento).
  `main.build_world(staged)`: `true` = caminho do jogador, em etapas com `await` (`LoadingScreen.STEPS` = pesos da barra; mapas e bots em fatias de `LOAD_MAP_BUDGET_MS`);
  `false` = autostart/dev, síncrono como antes. Quem decide o autostart: `DevRunner.autostart_class(args, returning)` (pura). `class_select.gd` foi removido (o HUD não tem mais `show_class_select`).
  Ponto de salvar do jogo: `main.save_game()` (retrato + `SaveSystem.save_player`); o HUD chama isso, nunca `save_player` direto.
- **Revisar o início** (com janela, flags depois de `--`; saves de teste só em memória/`TEST_SLOT`, nunca `save_0..4`): `--select_shot=<png> [--title_settings]` (foto da tela em que o início abre; `--title_settings` = Configurações sobre o Título);
  `--title_shot=<png> [--title_step=title|slots|class|look|loading] [--title_class=<id>] [--title_tab=body|hair|face] [--title_wait=<s>]` (`slots` pede personagem, real ou `--menu_saves`; `--title_wait=0.3` pega a skill da classe no meio; `--look` abre direto a Criação);
  `--loading_shot=<png> [--loading_map=<id>]` (overlay com a arte da zona, sem montar mundo); `--loading_fail` (força a falha da montagem: volta a Personagens com a faixa vermelha);
  `--path_shot=<pasta> [--path_class=<id>]` (título → Jogar → Criação → Carregamento pelos sinais, espaço -1; grava `a_title/a_create/a_loading.png`; com `--loading_fail` grava `a_fail.png`);
  `--menu_saves=<n|padrão>` (saves falsos, ids 90+: `n` cards ok, ou um char por espaço, `o` ok / `c` danificado / `-` vazio, ex. `oc-o`); `--menu_delete` (abre a confirmação de excluir);
  `--dev_presets` (seletor de começo rápido na Criação, só dev; `--preset=N` continua valendo); `-- --autostart=<c> --return_check [--menu_shot=<png> --return_shot=<png>]` (imprime
  `RETURN_CHECK ok entities=0 maps=0 parties=0 player=false screen=list`); cenário sem a cena de início: `.\tools\godot.ps1 --path . tools/menu_set_view.tscn -- --menu_set_shot=<png> [--shot_cam=title|list|create] [--settings] [--class=<id>]`.
  Checks: `_check_start_flow`, `_check_char_create`, `_check_char_list`, `_check_menu_set`, `_check_settings_panel`, `_check_loading_steps`, `_check_save_slots`, `_check_title_screen`.
