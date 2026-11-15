# Commit plan - Start flow (title, characters, creation, loading)

> Status: **DRAFT** - built from `git -C .claude/worktrees/sf-int status --porcelain -uall` on 2026-11-14 (base master 39b41b8, nothing staged).
> Rule: the user makes the commits, themed, on master. Never push. No agent runs any of this.
> User rule applied: a file shared by several themes goes entirely in the FIRST theme that needs it (`main.gd`, `hud.gd`, `dev_runner.gd` in commit 2).
> Message refs: `design/ux/start-flow.md` (spec + 'Implementacao' section).
> Not final: the bot-spawn perf and level-45 balance work will be merged into sf-int later and add files (see the placeholder section).

## Open questions for the user

1. **run_tests.gd** is touched by every theme. The first-theme rule would put it in commit 1; this plan follows the Kharzun precedent instead and ships it whole in one `test:` commit (10). Say if you prefer commit 1.
2. **Evidence**: 16 picks (about 10.7 MB) plus a `.gitignore` block; the other 42 PNG stay on disk, untracked and ignored. The block is NOT written yet (this pass may not edit `.gitignore`): append it before commit 12.
3. **Deleted files** (`game/ui/class_select.gd` + `.uid`) ride in commit 2 as `git rm` equivalents: `git add -A -- <path>` stages a deletion. The spec marks the deletion as needing your explicit approval; confirm before commit 2.
4. Intermediate commits do not load on their own (commit 2 references screens from 3-8). Only HEAD must pass the suite.
5. `bash.exe.stackdump` is not in this worktree's porcelain; the modified copy at master root is unrelated to this plan.

## Summary

| # | Commit | Files | MB |
|---|---|---|---|
| 1 | `feat(save): atomic slot writes and damaged-slot detection` | 1 | 0.0 |
| 2 | `feat(menu): start scene as main scene with staged world build and BOOT timings` | 15 | 0.2 |
| 3 | `perf(sim): bot spawn caches - 17 s to ~1 s at game start, identical world` | 4 | 0.2 |
| 4 | `feat(menu): 3D camp set, menu audio and shared settings panel` | 9 | 0.0 |
| 5 | `feat(art): menu camp set, pedestal silhouette and logo` | 7 | 2.5 |
| 6 | `feat(menu): character list, delete dialog and slot portraits` | 6 | 0.0 |
| 7 | `feat(menu): title screen and pedestal preview` | 4 | 0.0 |
| 8 | `feat(menu): character creation with class-in-action step` | 3 | 0.1 |
| 9 | `feat(menu): loading screen with staged progress and zone art` | 2 | 0.0 |
| 10 | `feat(art): per-zone loading art` | 27 | 2.9 |
| 11 | `test: start flow checks - routing, slots, list, set, settings, title, creation, loading` | 1 | 1.1 |
| 12 | `docs: start flow implementation notes, README, DESIGN and project manual` | 8 | 0.3 |
| 13 | `docs(qa): start flow key evidence - title, settings, list, delete, creation, loading, return` | 17 | 10.7 |
| | **Total committed** | **104** | 18.2 |

Porcelain paths today: 145 = 104 committed (incl. .gitignore and this plan, which are not in the porcelain yet: 2) + 42 excluded.

Keep the order 1 -> 12. Per user rule only HEAD must pass the suite.

## Excluded (never `git add`)

| Path / group | Count | Reason |
|---|---|---|
| `production/qa/evidence/start-flow/*` (not in the 16 picks) | 42 | stay on disk; hidden by the `.gitignore` block below |
| `production/session-state/*`, `production/session-logs/*`, `build/`, `.godot/`, `*.import` | 0 | already gitignored, never in the porcelain |
| other worktrees' scratch (`sf-a`, `sf-b`, `sf-b2`, `sf-c`, `sf-p1`, `sf-p5`, `sf-save`) | 0 | not in sf-int; never merge their `production/session-state/agent-sf-*.md` |

Excluded files:

```
production/qa/evidence/start-flow/a_create.png
production/qa/evidence/start-flow/a_loading.png
production/qa/evidence/start-flow/a_title.png
production/qa/evidence/start-flow/b1_create.png
production/qa/evidence/start-flow/b1_list.png
production/qa/evidence/start-flow/b1_settings_title.png
production/qa/evidence/start-flow/b1_title.png
production/qa/evidence/start-flow/b2_list_21x9.png
production/qa/evidence/start-flow/c_list_21x9.png
production/qa/evidence/start-flow/final/e1_exported_title.png
production/qa/evidence/start-flow/final/path_druid/a_create.png
production/qa/evidence/start-flow/final/path_druid/a_loading.png
production/qa/evidence/start-flow/final/path_druid/a_title.png
production/qa/evidence/start-flow/final/path_druid/a_world.png
production/qa/evidence/start-flow/final/path_paladin/a_create.png
production/qa/evidence/start-flow/final/path_paladin/a_loading.png
production/qa/evidence/start-flow/final/path_paladin/a_title.png
production/qa/evidence/start-flow/final/path_paladin/a_world.png
production/qa/evidence/start-flow/final/r1_title.png
production/qa/evidence/start-flow/final/r2_slots.png
production/qa/evidence/start-flow/final/r3_look.png
production/qa/evidence/start-flow/final/r4_loading.png
production/qa/evidence/start-flow/final/r5_wide.png
production/qa/evidence/start-flow/loading_sheet.png
production/qa/evidence/start-flow/menu_set_v5_CAM_create.png
production/qa/evidence/start-flow/menu_set_v5_CAM_create_21x9.png
production/qa/evidence/start-flow/menu_set_v5_CAM_list.png
production/qa/evidence/start-flow/menu_set_v5_CAM_list_21x9.png
production/qa/evidence/start-flow/menu_set_v5_CAM_title.png
production/qa/evidence/start-flow/menu_set_v5_CAM_title_21x9.png
production/qa/evidence/start-flow/menu_set_v5_create_ui.png
production/qa/evidence/start-flow/menu_set_v5_create_ui_21x9.png
production/qa/evidence/start-flow/menu_set_v5_list_ui.png
production/qa/evidence/start-flow/menu_set_v5_list_ui_21x9.png
production/qa/evidence/start-flow/menu_set_v5_title_logo.png
production/qa/evidence/start-flow/menu_set_v5_title_logo_21x9.png
production/qa/evidence/start-flow/menu_set_v5_title_ui.png
production/qa/evidence/start-flow/menu_set_v5_title_ui_21x9.png
production/qa/evidence/start-flow/menu_set_v6_CAM_create.png
production/qa/evidence/start-flow/menu_set_v6_CAM_create_21x9.png
production/qa/evidence/start-flow/p1_start.png
production/qa/evidence/start-flow/p6_create_cam.png
```

## Flagged files

- Largest new binaries: `assets/models/menu_set.glb`, `menu_silhouette.glb`, `assets/ui/loading/*.jpg` (26 files); see the MB column. Nothing above 20 MB.
- `.import` files are gitignored (`.gitignore:2`); the `.uid` files ship next to their `.gd`/`.tscn`.
- Largest diff: `tools/tests/run_tests.gd` (new `_check_*` functions), legitimate.
- `tools/blender/loading_art.py`: `ZONES`/`BOSSES` mirror the catalog by hand; no check covers the 26 `.jpg` (noted in `.claude/docs/ragnaex/conteudo.md`).
- **EOL**: the touched docs and `design/ux/start-flow.md` are CRLF like the rest of the tree; `core.autocrlf=false`, they commit as they are.
- `production/qa/evidence/start-flow/loading_sheet.png` and `logo_preview.png` (written by `loading_art.py --sheet` / `menu_logo.py`) are not on disk in sf-int today; if they appear they stay ignored (not in the picks).

## Commits (in order)

Path lists are exact (verified by `scratchpad/p6/plan.py check`, which maps every porcelain path to one commit or the excluded list).
Append to every commit message: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

### 1. `feat(save): atomic slot writes and damaged-slot detection`

Files: **1** (0.0 MB)

Message body:
```text
Spec: design/ux/start-flow.md section 5 and Q7.
SaveSystem.slot_state (empty|ok|corrupt), save_<n>.json.tmp + rename, _settle_tmp recovery,
first_free_slot only returns empty slots, delete_slot also removes .tmp and the portrait.
Save format unchanged.
```
```bash
git add -- \
  core/save_system.gd
```

### 2. `feat(menu): start scene as main scene with staged world build and BOOT timings`

Files: **15** (0.2 MB)

Message body:
```text
Spec: design/ux/start-flow.md sections 6-9 (P1 routing + Agent A).
run/main_scene = game/menu/start.tscn; StartRequest hands data to main; main.build_world(staged)
builds the world in steps (dev/autostart stays synchronous); BOOT <step> <ms> prints; main.save_game()
is the save point; F11 moves to WindowKeys; StartDev holds the review flags; DevRunner.autostart_class.
Removes game/ui/class_select.gd and its hud entry points (user-approved deletion).
hud.gd and main.gd are shared by later themes and ship whole here; this commit alone does not load
(needs the menu screens below), only HEAD must pass the suite.
```
```bash
# class_select.gd and its .uid are deleted in the working tree; -A stages the deletion
git add -A -- \
  game/dev/dev_runner.gd \
  game/main.gd \
  game/menu/start.gd \
  game/menu/start.gd.uid \
  game/menu/start.tscn \
  game/menu/start_dev.gd \
  game/menu/start_dev.gd.uid \
  game/menu/start_request.gd \
  game/menu/start_request.gd.uid \
  game/menu/window_keys.gd \
  game/menu/window_keys.gd.uid \
  game/ui/class_select.gd \
  game/ui/class_select.gd.uid \
  game/ui/hud.gd \
  project.godot
```

### 3. `perf(sim): bot spawn caches - 17 s to ~1 s at game start, identical world`

Files: **4** (0.2 MB)

Message body:
```text
Spec: design/ux/start-flow.md section 7 (BOOT showed bots = ~82% of the load). User-approved fixes: bot_spend step-4 ranking cache per (class, build, lean); tree_allocate/bot_spend/bot_pick batch mode (stats recomputed once, spawn_bot only); ClassTalentsCatalog built once (build() returns a copy); _gear_bot scan cache. Bot dump MD5 and sim_probe --suite checksum unchanged; _check_bot_spawn_cache.
```
```bash
git add -- \
  core/sim/systems/class_talent_system.gd \
  core/sim/systems/progression_system.gd \
  core/sim/world_sim.gd \
  data/catalog/class_talents_catalog.gd
```

### 4. `feat(menu): 3D camp set, menu audio and shared settings panel`

Files: **9** (0.0 MB)

Message body:
```text
Spec: design/ux/start-flow.md section 3 (Cenario, Configuracoes), section 9.
MenuSet (camera moves, dusk lighting, fire/sparks), MenuAudio (Aldara theme + UI sounds on the
Music/UI buses), SettingsPanel shared by the Title and the Esc menu, tools/menu_set_view.tscn.
```
```bash
git add -- \
  game/menu/menu_audio.gd \
  game/menu/menu_audio.gd.uid \
  game/menu/menu_set.gd \
  game/menu/menu_set.gd.uid \
  game/ui/settings_panel.gd \
  game/ui/settings_panel.gd.uid \
  tools/menu_set_view.gd \
  tools/menu_set_view.gd.uid \
  tools/menu_set_view.tscn
```

### 5. `feat(art): menu camp set, pedestal silhouette and logo`

Files: **7** (2.5 MB)

Message body:
```text
Spec: design/ux/start-flow.md Q1 (camp at the edge of Aldara).
tools/blender/menu_set.py -> assets/models/menu_set.glb, menu_silhouette.py -> menu_silhouette.glb
(empty-slot mannequin), menu_logo.py -> assets/ui/logo_*.png.
```
```bash
git add -- \
  assets/models/menu_set.glb \
  assets/models/menu_silhouette.glb \
  assets/ui/logo_ragnaex.png \
  assets/ui/logo_subtitle_ato2.png \
  tools/blender/menu_logo.py \
  tools/blender/menu_set.py \
  tools/blender/menu_silhouette.py
```

### 6. `feat(menu): character list, delete dialog and slot portraits`

Files: **6** (0.0 MB)

Message body:
```text
Spec: design/ux/start-flow.md section 3 (Personagens), section 5, Q2, Q5.
CharList (5 cards, keyboard focus, 'Save danificado' card), DeleteDialog, Portrait.capture ->
user://portrait_<n>.png; dev flags --menu_saves and --menu_delete (fake slots in memory only).
```
```bash
git add -- \
  game/menu/char_list.gd \
  game/menu/char_list.gd.uid \
  game/menu/delete_dialog.gd \
  game/menu/delete_dialog.gd.uid \
  game/menu/portrait.gd \
  game/menu/portrait.gd.uid
```

### 7. `feat(menu): title screen and pedestal preview`

Files: **4** (0.0 MB)

Message body:
```text
Spec: design/ux/start-flow.md section 3 (Titulo), section 4.
TitleScreen (logo, Jogar/Configuracoes/Sair with its own quit confirm, fade-in, keyboard),
PedestalPreview (kit on the pedestal, silhouette for the empty slot, per-instance kit cache).
```
```bash
git add -- \
  game/menu/pedestal_preview.gd \
  game/menu/pedestal_preview.gd.uid \
  game/menu/title_screen.gd \
  game/menu/title_screen.gd.uid
```

### 8. `feat(menu): character creation with class-in-action step`

Files: **3** (0.1 MB)

Message body:
```text
Spec: design/ux/start-flow.md section 3 (Criacao), Q3, Q6, section 12 P5.
CharCreate (class step with the signature skill playing on the pedestal, look step in three tabs,
name, --look, quick-start presets only behind --dev_presets); EntityView.clip_for_skill.
```
```bash
git add -- \
  game/entities/entity_view.gd \
  game/menu/char_create.gd \
  game/menu/char_create.gd.uid
```

### 9. `feat(menu): loading screen with staged progress and zone art`

Files: **2** (0.0 MB)

Message body:
```text
Spec: design/ux/start-flow.md section 3 (Carregamento), section 7.
LoadingScreen overlay (CanvasLayer 100 on the root, not an autoload), step weights measured from
BOOT after the bot-spawn caches (prepare/map_build dominate now), failure banner back to the list.
```
```bash
git add -- \
  game/menu/loading_screen.gd \
  game/menu/loading_screen.gd.uid
```

### 10. `feat(art): per-zone loading art`

Files: **27** (2.9 MB)

Message body:
```text
Spec: design/ux/start-flow.md section 3 (Carregamento).
tools/blender/loading_art.py renders one toon photo per zone from the real map GLB to
assets/ui/loading/<map>.jpg (26 maps). ZONES/BOSSES in the script mirror the catalog by hand.
```
```bash
git add -- \
  assets/ui/loading/city_aldara.jpg \
  assets/ui/loading/city_port.jpg \
  assets/ui/loading/dg_catacumbas.jpg \
  assets/ui/loading/dg_catacumbas_trono.jpg \
  assets/ui/loading/dg_coracao.jpg \
  assets/ui/loading/dg_cripta.jpg \
  assets/ui/loading/dg_goblin.jpg \
  assets/ui/loading/dg_gruta.jpg \
  assets/ui/loading/dg_ninho.jpg \
  assets/ui/loading/dg_pedreira.jpg \
  assets/ui/loading/dg_pedreira_coracao.jpg \
  assets/ui/loading/dg_slayers.jpg \
  assets/ui/loading/elf_city.jpg \
  assets/ui/loading/field_coast.jpg \
  assets/ui/loading/field_forest.jpg \
  assets/ui/loading/field_kharzun.jpg \
  assets/ui/loading/field_ruins.jpg \
  assets/ui/loading/field_steppe.jpg \
  assets/ui/loading/fort_bones.jpg \
  assets/ui/loading/fort_fire.jpg \
  assets/ui/loading/fort_frost.jpg \
  assets/ui/loading/fort_ghoul.jpg \
  assets/ui/loading/fort_trolls.jpg \
  assets/ui/loading/fort_war.jpg \
  assets/ui/loading/kharzun_citadel.jpg \
  assets/ui/loading/lich_citadel.jpg \
  tools/blender/loading_art.py
```

### 11. `test: start flow checks - routing, slots, list, set, settings, title, creation, loading`

Files: **1** (1.1 MB)

Message body:
```text
Spec: design/ux/start-flow.md section 10.
_check_start_flow, _check_char_create, _check_char_list, _check_menu_set, _check_settings_panel,
_check_loading_steps, _check_save_slots, _check_title_screen. run_tests.gd is touched by every
theme, so it ships whole in this one commit (as in the Kharzun plan).
```
```bash
git add -- \
  tools/tests/run_tests.gd
```

### 12. `docs: start flow implementation notes, README, DESIGN and project manual`

Files: **8** (0.3 MB)

Message body:
```text
Spec: design/ux/start-flow.md (new 'Implementacao' section: what shipped, deviations).
README start flow and save; DESIGN 'Tela inicial'; manual (comandos, conteudo, save, desempenho)
with the new flags, slot_state/atomic write, BOOT timings and the menu/loading art pipeline.
```
Before this commit append to `.gitignore`:
```gitignore
# Start flow QA evidence (design/ux/start-flow.md): only the curated picks are kept; the rest stays on disk, untracked.
production/qa/evidence/start-flow/**
!production/qa/evidence/start-flow/**/
!production/qa/evidence/start-flow/b2_title.png
!production/qa/evidence/start-flow/b2_title_21x9.png
!production/qa/evidence/start-flow/b2_settings.png
!production/qa/evidence/start-flow/b1_settings_hud.png
!production/qa/evidence/start-flow/b2_list_empty.png
!production/qa/evidence/start-flow/b2_list.png
!production/qa/evidence/start-flow/c_list.png
!production/qa/evidence/start-flow/c_delete.png
!production/qa/evidence/start-flow/c_portrait.png
!production/qa/evidence/start-flow/p5_class.png
!production/qa/evidence/start-flow/p5_demo.png
!production/qa/evidence/start-flow/p5_look_hair.png
!production/qa/evidence/start-flow/p5_create_21x9.png
!production/qa/evidence/start-flow/a_loading_60.png
!production/qa/evidence/start-flow/a_fail.png
!production/qa/evidence/start-flow/a_world.png
```
```bash
git add -- \
  .claude/docs/ragnaex/comandos.md \
  .claude/docs/ragnaex/conteudo.md \
  .claude/docs/ragnaex/desempenho.md \
  .claude/docs/ragnaex/save.md \
  README.md \
  design/ux/start-flow.md \
  docs/DESIGN.md \
  production/commit-plan-startflow.md
```

### 13. `docs(qa): start flow key evidence - title, settings, list, delete, creation, loading, return`

Files: **17** (10.7 MB)

Message body:
```text
Spec: design/ux/start-flow.md section 11.
16 hand-picked PNG; the other start-flow captures stay on disk, untracked and ignored (.gitignore block).
.gitignore is not in the porcelain yet: append the block below BEFORE this commit.
```
```bash
git add -- \
  .gitignore \
  production/qa/evidence/start-flow/a_fail.png \
  production/qa/evidence/start-flow/a_loading_60.png \
  production/qa/evidence/start-flow/a_world.png \
  production/qa/evidence/start-flow/b1_settings_hud.png \
  production/qa/evidence/start-flow/b2_list.png \
  production/qa/evidence/start-flow/b2_list_empty.png \
  production/qa/evidence/start-flow/b2_settings.png \
  production/qa/evidence/start-flow/b2_title.png \
  production/qa/evidence/start-flow/b2_title_21x9.png \
  production/qa/evidence/start-flow/c_delete.png \
  production/qa/evidence/start-flow/c_list.png \
  production/qa/evidence/start-flow/c_portrait.png \
  production/qa/evidence/start-flow/p5_class.png \
  production/qa/evidence/start-flow/p5_create_21x9.png \
  production/qa/evidence/start-flow/p5_demo.png \
  production/qa/evidence/start-flow/p5_look_hair.png
```

## Placeholder - work not merged yet (will add files; re-run the coverage script then)

| Source worktree | Expected theme | Expected files | Notes |
|---|---|---|---|
| `botspawn` | `perf(sim): faster bot spawn on world load` | TBD (`core/sim/...`, bot spawn path; `tools/tests/sim_probe`) | goes BEFORE commit 8 if it changes the `bots` weight; after the merge re-measure BOOT and update `LoadingScreen.STEPS` + the `.claude/docs/ragnaex/desempenho.md` line |
| `bal45` | `balance: level 45 ...` | TBD (`data/balance.gd`, catalogs, GDD/DESIGN tables, probes) | independent of the start flow; own commits, own plan section |
| P6 closing | `docs(qa)` additions | TBD | export + `.exe` smoke notes; extra evidence picks (extend `PICKS` in `plan.py` and the `.gitignore` block together) |

When these merge: re-run `git status --porcelain -uall` in sf-int, run `python -I plan.py check` (every path in exactly one commit or excluded), add the new themes here, and refresh the counts.

