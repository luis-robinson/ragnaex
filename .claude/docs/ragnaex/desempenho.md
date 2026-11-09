<!-- RagnaEx manual (pt-BR) — Desempenho. Moved VERBATIM from the old CLAUDE.md on 2026-11-08 (CCGS adoption); imported by CLAUDE.md. Edit here. -->

## Desempenho

- `KitModel`: peça que não aparece sai da árvore (`_show`) e só ganha material toon ao aparecer; procure peças com `kit.pieces("<glob>")`,
  não com `find_children` (só acha as ligadas). Mapas sem o jogador simulam a cada `Balance.AWAY_MAP_EVERY` ticks (`Sim.away_every`).
- Draw calls: peças ligadas do kit viram 1 malha (`KitModel._remerge`) e monstros/cavalo de peças rígidas também (`RigidMerge`, malha guardada por modelo);
  bonecos a mais de 58 m somem e param de processar (`main._cull_views`), props têm distância de desenho (`MapBuilder.set_vis_range`).
  Ação de 1 vez no `InputCommand` (montar, voltar) precisa ser zerada no comando repetido entre pensamentos (`WorldSim.tick`).
- Lentidão que só aparece jogando: `PerfWatch` (game/dev/perf_watch.gd) grava em `user://perf_log.txt` (AppData/Roaming/Godot/app_userdata/RagnaEx) cada trecho < 25 FPS com
  mapa, monstros acordados, draws, GPU e as fases da sim; reproduzir com `-- --soak=<s> [--soak_map=<dungeon>]` (joga sozinho e imprime FPS a cada 5 s).
- Qualidade de imagem: `GraphicsSettings` (game/visual/graphics_settings.gd, menu Esc → Gráficos, salvo em `user://settings.cfg`): Nítido (125%, 100% em tela grande)
  ou FSR 2 Qualidade/Equilibrado/Desempenho. Comparar sem mexer no salvo: `-- --perf --gfx=<n>`.
- Medir: `.\tools\godot.ps1 --path . -- --perf [--perf_at=x,z] [--no_merge] [--cull_test=hide|noproc] [--no_prune] [--no_away]` (cidade cheia ~8 s: FPS, draw calls, nós, memória, custo do tick).
  Draws por passada (`canvas_pass` = HUD 2D, `visible_pass`, `shadow_pass`) e `entity_surfaces`; experimentos `--hide_minimap`, `--hide_props=<prefixo,...>`, `--no_prop_shadow`, `--shadow_max=<m>`, `--no_vcol_merge`.
- Fusões com cor no vértice: peças que só mudam de cor dividem a superfície (cor sRGB + `spec_strength` no alfa do `COLOR`; material branco com
  `vcol_srgb`, que é o do grupo e fica em `kit.mats`/`_mats` para o hit flash). Parâmetro novo no toon que varia por peça = entra em `KitModel._shared_key`/`RigidMerge.mat_key`.
  `RigidMerge` guarda a geometria por forma (`_geo_cache`) e a malha por forma + cores.
- 2D: desenho de muitos itens por quadro (`draw_circle` etc.) é 1 draw call cada; o minimapa estático é assado numa `SubViewport` (`Minimap._bake_static`).
- **Sim na thread** (jogo; `SimSync`, game/world/sim_sync.gd): o physics só agenda o tick (com o comando do passo), o tick roda numa WorkerThreadPool
  enquanto o quadro desenha (`Sim.start_async` no `frame_pre_draw`) e quem toca a sim espera antes (`Sim.sync`: input, physics_frame, process_frame).
  A sim emite por `Events.post(&"sinal", ...)` (nunca `Events.x.emit` em `core/`): na thread o evento vai para a fila e sai no sync. Código que toca a sim
  fora desses momentos (thread própria, callback de render) chama `Sim.sync()` antes. `--sim_sync` desliga para comparar; testes chamam `tick()` direto.
- Sim sem tela: `--headless --path . tools/tests/sim_probe.tscn -- [--phases]` (ms/tick + soma de conferência: otimização da sim tem de dar a mesma soma).
  Laço sobre `m["entities"]`: teste a distância antes de chamar métodos (`Combat.nearest_hostile`); nada de alocar por entidade por tick. Notas e números: `docs/otimizacao.md`.
