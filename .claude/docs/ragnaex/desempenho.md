<!-- RagnaEx manual (pt-BR) — Desempenho. Moved VERBATIM from the old CLAUDE.md on 2026-11-08 (CCGS adoption); imported by CLAUDE.md. Edit here. -->

## Desempenho

- `KitModel`: peça que não aparece sai da árvore (`_show`) e só ganha material toon ao aparecer; procure peças com `kit.pieces("<glob>")`,
  não com `find_children` (só acha as ligadas). Mapas sem o jogador simulam a cada `Balance.AWAY_MAP_EVERY` ticks (`Sim.away_every`).
- Draw calls: peças ligadas do kit viram 1 malha (`KitModel._remerge`) e monstros/cavalo de peças rígidas também (`RigidMerge`, malha guardada por modelo);
  bonecos a mais de 58 m somem e param de processar (`main._cull_views`), props têm distância de desenho (`MapBuilder.set_vis_range`).
  Bonecos nascem pela **fila de views** (`ViewQueue`, `main._drain_views`): cada quadro cria até `main.view_budget_ms` (3,5 ms), grupo/alvo e
  invocações primeiro, depois o mais perto; além de 58 + 8 m esperam chegar perto (o jogador nasce na hora). `main.views` pode não ter a
  entidade: sempre `views.has/get`. Fotos de revisão (`*shot*`, `*film*`, `--tour`...) criam tudo de uma vez; `--view_budget=<ms>` (0 = como antes).
  Ação de 1 vez no `InputCommand` (montar, voltar) precisa ser zerada no comando repetido entre pensamentos (`WorldSim.tick`).
- Lentidão que só aparece jogando: `PerfWatch` (game/dev/perf_watch.gd) grava em `user://perf_log.txt` (AppData/Roaming/Godot/app_userdata/RagnaEx) cada trecho < 25 FPS com
  mapa, monstros acordados, draws, GPU e as fases da sim; reproduzir com `-- --soak=<s> [--soak_map=<dungeon>]` (joga sozinho e imprime FPS a cada 5 s).
- Qualidade de imagem: `GraphicsSettings` (game/visual/graphics_settings.gd, menu Esc → Gráficos, salvo em `user://settings.cfg`): Nítido (125%, 100% em tela grande)
  ou FSR 2 Qualidade/Equilibrado/Desempenho. Comparar sem mexer no salvo: `-- --perf --gfx=<n>`.
- Teclas: `KeyBindings` (game/player/key_bindings.gd, estático; aba Controles das Configurações, seção `keys` do `settings.cfg`, só o que difere do padrão do `project.godot`; lido em `main._ready`/`start.gd` antes de qualquer input). Lista = `KeyBindings.ACTIONS` (H/G/M viraram as ações `mount`/`recall`/`ui_map`); Esc, F11 e Enter (chat) são fixas. Clique na tecla → a próxima tecla/botão do mouse vale (Esc cancela); tecla de outra ação = as duas trocam (aviso). Quem MOSTRA tecla lê `KeyBindings.label/short/fill` (`"{potion_1}"`, `"{move}"` = WASD) e redesenha quando `KeyBindings.revision` muda (barra `ActionBar.refresh_keys`, dica do canto `Hud.HINT`, `Tips.TIPS`, títulos de janela). Ação nova trocável = entrada no `project.godot` + linha em `ACTIONS`. Só nesta partida: `-- --bind=potion_1:Z[,ação:tecla]`; foto da aba: `--select_shot=<png> --title_settings --settings_tab=controls`. Check `_check_key_bindings` (`--only=key_bindings`).
- Acessibilidade: `AccessSettings` (game/visual/access_settings.gd, aba Acessibilidade das Configurações, seção `access` do `settings.cfg`): `shake` (× no
  `CameraRig.add_shake`, ruído suave + tranco no sentido do golpe), `flash` (hit flash, `SkillFx.flash`), `contrast` (padrões `TelePattern` por cima dos avisos
  do `BossSigView`/`FxManager._telegraph`, mesma malha do quadro no BossSigView) e `ally_fx` (`FxManager._ally_fx_skip`/`ally_pass`: efeitos e números dos
  outros personagens; os seus e os de monstro nunca). Só nesta partida: `-- --contrast=0|1|2 --ally_fx=0|1|2 --shake=<0..1> --flash=<0..1>`; foto da aba:
  `--select_shot=<png> --title_settings --settings_tab=access`. Check `_check_accessibility_settings` (`--only=accessibility`).
- Medir (espera os spawners encherem e a fila de bonecos esvaziar, `PERF settle_s`; `sync_step` = média/pior espera do `Sim.sync` por passo; `physics_max1s_ms` = pior passo de cada segundo, não média): `.\tools\godot.ps1 --path . -- --perf [--perf_at=x,z] [--no_merge] [--cull_test=hide|noproc] [--no_prune] [--no_away]` (cidade cheia ~8 s: FPS, draw calls, nós, memória, custo do tick).
  Draws por passada (`canvas_pass` = HUD 2D, `visible_pass`, `shadow_pass`) e `entity_surfaces`; experimentos `--hide_minimap`, `--hide_props=<prefixo,...>`, `--no_prop_shadow`, `--shadow_max=<m>`, `--no_vcol_merge`.
- Fusões com cor no vértice: peças que só mudam de cor dividem a superfície (cor sRGB + `spec_strength` no alfa do `COLOR`; material branco com
  `vcol_srgb`, que é o do grupo e fica em `kit.mats`/`_mats` para o hit flash). Parâmetro novo no toon que varia por peça = entra em `KitModel._shared_key`/`RigidMerge.mat_key`.
- Monstro com brilho: o toon do monstro mantém a emissão do GLB (`EntityView.mob_glow/glow_color`: energia > 1,05 ou nome `glow_*`; `m_white`
  e pinturas com energia 1,0 não brilham). `emission_amount` vai em degraus de 0,25 (0,25-1,75) para o `RigidMerge` não abrir uma malha por valor; check `_check_mob_glow`.
  `RigidMerge` guarda a geometria por forma (`_geo_cache`) e a malha por forma + cores.
- 2D: desenho de muitos itens por quadro (`draw_circle` etc.) é 1 draw call cada; o minimapa estático é assado numa `SubViewport` (`Minimap._bake_static`).
- Texto de combate só por `FxManager._float_text` → `FloatText` (pool de Label3D, teto 48, fusão "×N", 4 por alvo; briga dos outros só a
  16 m e por amostra); nunca `Label3D.new()` + tween por pop. Nomes em matilha: uma passada `NameplateCrowd.update` a cada 0,2 s em
  `main._cull_views` (não por boneco); `EntityView.set_crowd_hidden` só escreve na troca.
- **Sim na thread** (jogo; `SimSync`, game/world/sim_sync.gd): o physics só agenda o tick (com o comando do passo), o tick roda numa WorkerThreadPool
  enquanto o quadro desenha (`Sim.start_async` no `frame_pre_draw`) e quem toca a sim espera antes (`Sim.sync`: input, physics_frame, process_frame).
  A sim emite por `Events.post(&"sinal", ...)` (nunca `Events.x.emit` em `core/`): na thread o evento vai para a fila e sai no sync. Código que toca a sim
  fora desses momentos (thread própria, callback de render) chama `Sim.sync()` antes. `--sim_sync` desliga para comparar; testes chamam `tick()` direto.
- Sim sem tela: `--headless --path . tools/tests/sim_probe.tscn -- [--phases] [--map=<id>] [--at=x,z] [--suite] [--census]` (ms/tick + soma de conferência: otimização da sim tem de dar a mesma soma;
  `--suite` = o mundo do teste longo do run_tests, `--census` = por mapa: entidades por tipo, monstros dormindo, loot no chão, `--hops` = cada troca de mapa dos bots + resumo `HOPS` com idas e voltas A→B→A em 60 s). Orçamento: ≤ 10 ms/tick com Kharzun carregado (GDD `ato2-horda` AC-36).
  Laço sobre `m["entities"]`: teste a distância antes de chamar métodos (`Combat.nearest_hostile`); nada de alocar por entidade por tick. Notas e números: `docs/otimizacao.md`.

- **Carregamento do início** (`main.build_world(staged=true)`; `BOOT <etapa> <ms> [extra]` no log, de `main._boot`, guardado em `main.boot_ms`; `StartDev.boot` marca `start_enter` = motor + autoloads + `start.tscn`): medido em 2026-11-14,
  depois dos caches do spawn de bots (`ProgressionSystem` ranking/lote, `ClassTalentsCatalog` uma vez, `_gear_bot`; mundo idêntico, check `_check_bot_spawn_cache`): `start_enter` ~5,5-7 s (autoloads + `GameData.load_all`, antes de qualquer cena),
  `sim_maps` ~0,25-0,35 s (33 mapas), `bots` ~1,0-1,4 s (66 bots; antes 17-20 s), `map_build` ~0,6-1,0 s, `world_total` ~1,7-2,8 s; clique → mundo ~7,5 s na janela.
  `LOAD_MAP_BUDGET_MS` (24 ms/quadro) fatia mapas e bots para a barra andar; os pesos de `LoadingScreen.STEPS` saem desses números (refazer se uma etapa mudar muito). Dev/autostart (`staged=false`) continua síncrono, sem `await`.
  A/B com o master (2026-11-14): FPS/draws/tick iguais; `map_build_ms` ~+250 ms (suspeita: `EntityView.model_top` na 1ª vista de cada modelo) — a confirmar.
