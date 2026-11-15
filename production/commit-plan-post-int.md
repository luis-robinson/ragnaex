# Commit plan - post-int (start flow + Kharzun r5, shield, flaky RNG, UI polish)

> Status: **DRAFT**, built from `git -C .claude/worktrees/post-int status --porcelain -uall` on 2026-11-14 (base master 39b41b8, nothing staged). Supersedes `production/commit-plan-startflow.md` (same 12 start-flow themes, paths updated).
> Rule: the user makes the commits, themed, on master. Never push. No agent runs any of this.
> User rule applied: a file shared by several themes ships WHOLE in the FIRST commit that needs it (hud/main/dev_runner -> 2, world_sim -> 3, entity_view -> 8, run_tests -> 14, .gitignore -> 16).
> Message refs: `design/ux/start-flow.md`, `production/qa/art-review-2026-11-13-r2.md`. Only HEAD must pass the suite; intermediate commits may not load (commit 2 needs the menu screens of 4-9, run_tests.gd references code of every commit).
> bal45 merged 2026-11-15 (commit 18; its run_tests.gd/DESIGN.md hunks ride in 14/15). sf-guard, determinism (flaky-sig), ground-clip and boot-splash are merged (2026-11-15).

## Open questions for the user

1. **fix(test) has no files of its own.** `world_sim.gd` (RNG_SEED in `_init`) is shared with the bot-spawn perf commit and `run_tests.gd` is shared with every theme; the whole-file rule puts them in commits 3 and 14, so a standalone `fix(test): deterministic WorldSim RNG` would be empty. It is folded (see 'Folded'). Alternative: commit it FIRST with `world_sim.gd` + `run_tests.gd` whole, which empties the test commit (14) and drops `world_sim.gd` from commit 3; say if you prefer that.
2. **EOL flip in two files.** `game/entities/entity_view.gd` (1856 lines) and `game/world/map_builder.gd` (910 lines) are CRLF in HEAD and LF in the working tree, so their diffs are whole-file (1936+1856 and 946+910 lines; `git diff --ignore-space-at-eol` shows the real change: 108 and 54 lines). Every other modified source file kept its EOL. Recommend converting both back to CRLF before commits 8 and 13 (a tool rewrote them as LF); I did not touch them.
3. **map_builder.gd is not actually shared**: only the UI-polish work touches it (not start flow, not the other extras), so it sits in commit 13 rather than an earlier one.
4. **Evidence for r5 and ui-polish is not in post-int.** Those folders live only in the `art-r5` / `ui-polish` worktrees (ignored by `final-qa/**`). Commit 17 needs the 10 picks copied first (commands in commit 16's section, before the `git add`).
5. **Deleted files** `game/ui/class_select.gd` + `.uid` ride in commit 2 (`git add -A -- ...`). The start-flow spec asks for your explicit approval of the deletion; confirm before commit 2.
6. `bash.exe.stackdump` and `_to_delete/ragnaex.zip` are TRACKED in HEAD (a Git Bash crash dump and a zip). Not part of this plan; master root even shows the dump modified. Consider a separate cleanup.

## Summary

| # | Commit | Files | MB |
|---|---|---|---|
| 1 | `feat(save): atomic slot writes and damaged-slot detection` | 1 | 0.0 |
| 2 | `feat(menu): start scene as main scene with staged world build, BOOT timings and boot splash` | 19 | 0.5 |
| 3 | `perf(sim): bot spawn caches - 17 s to ~1 s at game start, identical world` | 5 | 0.2 |
| 4 | `feat(menu): 3D camp set, menu audio and shared settings panel` | 9 | 0.0 |
| 5 | `feat(art): menu camp set, pedestal silhouette and logo` | 7 | 2.5 |
| 6 | `feat(menu): character list, delete dialog and slot portraits` | 6 | 0.0 |
| 7 | `feat(menu): title screen and pedestal preview` | 4 | 0.0 |
| 8 | `feat(menu): character creation with class-in-action step` | 3 | 0.1 |
| 9 | `feat(menu): loading screen with staged progress and zone art` | 2 | 0.0 |
| 10 | `feat(art): per-zone loading art` | 27 | 2.9 |
| 11 | `fix(art): Kharzun art review r5 - wolf cloth, shrine streaks, goblin forge, basalt pebbles` | 6 | 14.0 |
| 12a | `feat(art): axe remodel - shared axe_kit, 1h/2h/dual axes with set glow, Durgash throne axe, orc/zombie/ghoul axes` | 58 | 5.1 |
| 12b | `feat(art): close shield mounts - per-style SHIELD_MOUNTS, grip and trimmed strap welded into the shield, study/apply tools` | 50 | 0.9 |
| 12c | `chore(art): rebuild all kits and wolf/bear forms - ground clip, axes, close shields, edge glow and dash exit (kits go into history once)` | 21 | 97.7 |
| 13 | `fix(ui): combat text, nameplates and HUD polish` | 6 | 0.2 |
| - | `fix(test): deterministic WorldSim RNG` (folded into 3 and 14) | 0 | 0.0 |
| 14 | `test: start flow, deterministic test RNG, form-leg turn and UI polish checks` | 1 | 1.1 |
| 15 | `docs: start flow implementation notes, README, DESIGN, project manual, commit plans, art notes and playtest checklist` | 15 | 0.4 |
| 16 | `docs(qa): start flow key evidence - boot splash, title, settings, list, delete, creation, loading, return` | 22 | 12.8 |
| 17 | `docs(qa): evidence - Kharzun r5, shield mounts, axes, ground clip, glow/dash, UI polish` | 51 | 46.1 |
| 18 | `feat(balance): level-45 ascension F5 buffs to ~1.30` | 5 | 0.2 |
| | **Total committed** | **318** | 184.7 |

Coverage (re-checked 2026-11-15 after the sf-guard, determinism and ground-clip merges and the playtest checklist; `git status --porcelain -uall` = 247 paths): 247 porcelain + 11 the plan adds (the .gitignore edit and 10 picks of r5/ui-polish to copy in; this plan and the start-flow plan are already in the porcelain) = 258 = 168 committed + 90 excluded (68 + the 14 sf-guard `guard/` evidence shots, covered by the `start-flow/**` ignore block, + 8 ground-clip non-picks). Determinism added no new paths (world_sim.gd and run_tests.gd were already in commits 3 and 14); ground-clip added 34 (14 kits + 2 forms + druid_sets.py into commit 12; 9 evidence picks into commit 17; 8 excluded). The playtest checklist (`production/qa/playtest-checklist-2026-11-15.md`, 1 new path) went into commit 15 with the other production docs. Boot-splash merge (2026-11-15) added 20 porcelain paths (267 total): 4 into commit 2 (boot_splash.png + tools/splash/), 5 evidence picks into commit 16, 11 excluded (`boot-splash/**` ignore block); project.godot and run_tests.gd were already in commits 2 and 14. New totals: 267 porcelain + 11 added by the plan = 278 = 177 committed + 101 excluded. Every porcelain path is in exactly one commit or in Excluded; 0 missing, 0 duplicated.

bal45 merge (2026-11-15) added 5 paths, all into commit 18 (balance.gd, ascension_catalog.gd, druid_ascension.gd, design/balance/ x2); run_tests.gd and DESIGN.md were already in 14/15. 177 + 5 = 182 committed.

Review fixes (2026-11-15, in place, no new commit): launch-once guard + input lock, overlay_parent and has_any routing (start.gd) and drop_loads on early failure (main.gd, start_request.gd) -> commit 2; SaveSystem.PORTRAIT_PATH (save_system.gd) -> commit 1; Portrait.path reads it and delete-last opens Creation (portrait.gd, char_list.gd) -> commit 6; pedestal kit scene evicted with its model (pedestal_preview.gd) -> commit 7; ClassTalentsCatalog.warm (class_talents_catalog.gd) -> commit 3, plus its caller `data/game_data.gd` (the only NEW path from the fixes); `production/patch-notes-2026-11-15.md` (new, from another pass) goes into commit 15 with the other production docs: 182 + 2 = 184 committed; checks (run_tests.gd) -> 14; start-flow.md and the playtest checklist -> 15; the live double-Enter probe in `--path_shot` (start_dev.gd) -> 2. Its 4 evidence shots (`start-flow/review-fixes/`) are excluded (ignore block): 101 + 4 = 105 excluded.

Art merge (2026-11-15; shields-mount, the FINAL art branch incl. ground-clip, axes, close shields, g20 glow, dash exit, merged into post-int): user decision = character kits enter history ONCE, so old commit 12 became 12a/12b/12c (the 18 kits + 2 forms ship only in 12c, 97.7 MB, final versions) and batch 2 no longer needs its own kit commit. +104 art paths (126 copied files + new axe_kit/shield tools; 3-way: conteudo.md 0 conflicts, run_tests.gd 2 keep-both hunks) -> 12a 58, 12b 50, 12c 21; docs (modelos.md, shields_review.md, 2 QA notes) into 15 (+4); 27 evidence picks (~26 MB: 8 shields-mount, 10 art-branch-verify, 9 axes) into 17 with .gitignore blocks in 16; 100 non-picks excluded. `git status --porcelain -uall` = 512 paths: 512 + 11 the plan adds = 523 = 318 committed + 205 excluded; plan.py: missing 0, dup 0. Commit 14 (run_tests.gd, whole) now also carries _check_shield_mounts and _check_axe_kit. attack-arcs (batch 2) still to merge on top: needs these kits.

Order 1 -> 18. The extras (11-13) go after the start-flow code and before the single `test:` commit (14), which already contains the checks of all of them.

## Folded

- `fix(test): deterministic WorldSim RNG` + `fix(test): pass-count determinism` (worktree flaky-sig, merged 2026-11-15): no files of their own. world_sim.gd (RNG_SEED in _init; post-int's RNG hunks are identical to flaky-sig's, the rest of the file differs only by the bot-spawn cache of commit 3) ships whole in commit 3; run_tests.gd ships whole in commit 14 with _check_sim_rng_fresh, the `_seeded_rng()` helper (all 34 unseeded `RandomNumberGenerator.new()` of the test brains/rolls replaced) and the `--count_per_check` diagnostic flag. Both commit bodies carry the fix(test) text. Two full runs after the merge gave the same total. If you want a real fix(test) commit, see open question 1.

## Excluded (never `git add`)

| Path / group | Count | Reason |
|---|---|---|
| `production/qa/evidence/start-flow/*` (not in the 16 picks; includes the 14 `guard/` before/after shots of sf-guard and the 4 `review-fixes/` path shots) | 60 | stay on disk; hidden by the `.gitignore` block |
| `production/qa/evidence/shield-fix/*` (not in the 5 picks) | 26 | stay on disk; hidden by the `.gitignore` block |
| `production/qa/evidence/ground-clip/*` (not in the 9 picks) | 8 | stay on disk; hidden by the `.gitignore` block |
| `production/qa/evidence/shields-mount/*`, `art-branch-verify/*`, `axes/*` (not in the 27 picks: other sheets, block shots, strap tests, v1 glow, rollout frames) | 100 | stay on disk; hidden by the `.gitignore` block |
| `production/qa/evidence/boot-splash/*` (not in the 5 picks: older exe frames, master timelines, logs, in-engine title shot) | 11 | stay on disk; hidden by the `.gitignore` block |
| `final-qa/r5/*`, `final-qa/ui-polish/*` non-picks (60 and 103 files in the source worktrees, not in post-int) | 0 | already ignored by `final-qa/**`; never copied |
| `production/session-state/*`, `session-logs/*`, `build/`, `.godot/`, `*.import`, `.claude/worktrees/` | 0 | already gitignored |

```
production/qa/evidence/boot-splash/boot_splash_source_2560x1440.png
production/qa/evidence/boot-splash/boot_timeline_master_run1.log
production/qa/evidence/boot-splash/boot_timeline_master_run2.log
production/qa/evidence/boot-splash/export_exe_01500ms.png
production/qa/evidence/boot-splash/export_exe_08000ms.png
production/qa/evidence/boot-splash/export_exe_15000ms.png
production/qa/evidence/boot-splash/export_exe_30000ms.png
production/qa/evidence/boot-splash/handover_run.log
production/qa/evidence/boot-splash/handover_title_inengine.png
production/qa/evidence/boot-splash/smoke_postint.log
production/qa/evidence/boot-splash/suite_postint.log
production/qa/evidence/ground-clip/form_bear_maul_round3.png
production/qa/evidence/ground-clip/form_bear_pounce_round3.png
production/qa/evidence/ground-clip/form_bear_slam_round3.png
production/qa/evidence/ground-clip/form_wolf_maul_round3.png
production/qa/evidence/ground-clip/form_wolf_slam_round3.png
production/qa/evidence/ground-clip/spear_atk_finisher_after_recover.png
production/qa/evidence/ground-clip/sword_atk_leap_after.png
production/qa/evidence/ground-clip/sword_atk_leap_before.png
production/qa/evidence/shield-fix/after_juramento_block_shield_front.png
production/qa/evidence/shield-fix/after_juramento_block_shield_game45.png
production/qa/evidence/shield-fix/after_juramento_idle_back.png
production/qa/evidence/shield-fix/after_juramento_idle_front.png
production/qa/evidence/shield-fix/after_juramento_idle_game45.png
production/qa/evidence/shield-fix/after_juramento_run_front.png
production/qa/evidence/shield-fix/after_juramento_run_game45.png
production/qa/evidence/shield-fix/after_tabuas_block_shield_game45.png
production/qa/evidence/shield-fix/after_tabuas_idle_back.png
production/qa/evidence/shield-fix/after_tabuas_idle_front.png
production/qa/evidence/shield-fix/after_tabuas_run_front.png
production/qa/evidence/shield-fix/after_tabuas_run_game45.png
production/qa/evidence/shield-fix/before_tabuas_block_shield_front.png
production/qa/evidence/shield-fix/before_tabuas_block_shield_game45.png
production/qa/evidence/shield-fix/before_tabuas_idle_back.png
production/qa/evidence/shield-fix/before_tabuas_idle_front.png
production/qa/evidence/shield-fix/before_tabuas_run_front.png
production/qa/evidence/shield-fix/before_tabuas_run_game45.png
production/qa/evidence/shield-fix/game/block_wood_aparo.png
production/qa/evidence/shield-fix/game/block_wood_arco.png
production/qa/evidence/shield-fix/game/idle_town.png
production/qa/evidence/shield-fix/game/idle_town_char.png
production/qa/evidence/shield-fix/game/idle_town_craft.png
production/qa/evidence/shield-fix/game/idle_town_party.png
production/qa/evidence/shield-fix/game/idle_town_skills.png
production/qa/evidence/shield-fix/game/idle_town_town.png
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
production/qa/evidence/start-flow/guard/after_berserker_16x9.png
production/qa/evidence/start-flow/guard/after_berserker_21x9.png
production/qa/evidence/start-flow/guard/after_bishop_16x9.png
production/qa/evidence/start-flow/guard/after_bishop_21x9.png
production/qa/evidence/start-flow/guard/after_druid_16x9.png
production/qa/evidence/start-flow/guard/after_druid_21x9.png
production/qa/evidence/start-flow/guard/before_berserker_16x9.png
production/qa/evidence/start-flow/guard/before_berserker_21x9.png
production/qa/evidence/start-flow/guard/before_bishop_16x9.png
production/qa/evidence/start-flow/guard/before_bishop_21x9.png
production/qa/evidence/start-flow/guard/before_druid_16x9.png
production/qa/evidence/start-flow/guard/before_druid_21x9.png
production/qa/evidence/start-flow/guard/it1_bishop_16x9.png
production/qa/evidence/start-flow/guard/it2_bishop_16x9.png
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
production/qa/evidence/start-flow/review-fixes/a_create.png
production/qa/evidence/start-flow/review-fixes/a_loading.png
production/qa/evidence/start-flow/review-fixes/a_title.png
production/qa/evidence/start-flow/review-fixes/a_world.png
production/qa/evidence/art-branch-verify/anim_probe_vs_ground_clip.txt
production/qa/evidence/art-branch-verify/berserker_atk_2h_female.png
production/qa/evidence/art-branch-verify/berserker_atk_2h_male.png
production/qa/evidence/art-branch-verify/berserker_carniceiro_tiers_female.png
production/qa/evidence/art-branch-verify/berserker_carniceiro_tiers_male.png
production/qa/evidence/art-branch-verify/berserker_dash_male.png
production/qa/evidence/art-branch-verify/berserker_executor_tiers_female.png
production/qa/evidence/art-branch-verify/berserker_executor_tiers_male.png
production/qa/evidence/art-branch-verify/dash/berserker_carniceiro30_side_antes.png
production/qa/evidence/art-branch-verify/dash/berserker_carniceiro30_side_depois.png
production/qa/evidence/art-branch-verify/dash/berserker_executor30_front_antes.png
production/qa/evidence/art-branch-verify/dash/berserker_executor30_front_depois.png
production/qa/evidence/art-branch-verify/dash/druid_side_antes.png
production/qa/evidence/art-branch-verify/dash/druid_side_depois.png
production/qa/evidence/art-branch-verify/dash/necromancer_side_antes.png
production/qa/evidence/art-branch-verify/dash/necromancer_side_depois.png
production/qa/evidence/art-branch-verify/dash/paladin_cruzado30_side_antes.png
production/qa/evidence/art-branch-verify/dash/paladin_cruzado30_side_depois.png
production/qa/evidence/art-branch-verify/dash/paladin_front_antes.png
production/qa/evidence/art-branch-verify/dash/paladin_front_depois.png
production/qa/evidence/art-branch-verify/dash/paladin_side_antes.png
production/qa/evidence/art-branch-verify/dash/paladin_side_depois.png
production/qa/evidence/art-branch-verify/dash/ranger_side_antes.png
production/qa/evidence/art-branch-verify/dash/ranger_side_depois.png
production/qa/evidence/art-branch-verify/durgash_attack_strip.png
production/qa/evidence/art-branch-verify/durgash_sig/boss_durgash.png
production/qa/evidence/art-branch-verify/glow/carniceiro_close_antes.png
production/qa/evidence/art-branch-verify/glow/carniceiro_close_depois.png
production/qa/evidence/art-branch-verify/glow/carniceiro_close_v1_claro.png
production/qa/evidence/art-branch-verify/glow/carniceiro_game_antes.png
production/qa/evidence/art-branch-verify/glow/carniceiro_game_depois.png
production/qa/evidence/art-branch-verify/glow/carniceiro_game_v1_claro.png
production/qa/evidence/art-branch-verify/glow/executor_close_antes.png
production/qa/evidence/art-branch-verify/glow/executor_close_depois.png
production/qa/evidence/art-branch-verify/glow/executor_close_v1_claro.png
production/qa/evidence/art-branch-verify/glow/executor_game_antes.png
production/qa/evidence/art-branch-verify/glow/executor_game_depois.png
production/qa/evidence/art-branch-verify/glow/executor_game_v1_claro.png
production/qa/evidence/art-branch-verify/glow/g20_violet_close_antes.png
production/qa/evidence/art-branch-verify/glow/g20_violet_close_depois.png
production/qa/evidence/art-branch-verify/glow/jogo_carniceiro_30_char.png
production/qa/evidence/art-branch-verify/glow/jogo_executor_20_char.png
production/qa/evidence/art-branch-verify/paladin_block_shield_strip_front.png
production/qa/evidence/art-branch-verify/paladin_shields_guard_p0.png
production/qa/evidence/art-branch-verify/paladin_shields_guard_p1.png
production/qa/evidence/art-branch-verify/paladin_shields_idle_p0.png
production/qa/evidence/art-branch-verify/paladin_shields_idle_p1.png
production/qa/evidence/axes/blender_closeup_34.png
production/qa/evidence/axes/blender_closeup_side.png
production/qa/evidence/axes/blender_game_cam_1x.png
production/qa/evidence/axes/blender_game_cam_3x.png
production/qa/evidence/axes/followup/skill_ber_cleave_before.png
production/qa/evidence/axes/followup/skill_icons_berserker_sheet.png
production/qa/evidence/axes/godot_new_tiers_executor.png
production/qa/evidence/axes/godot_old_tiers_executor.png
production/qa/evidence/axes/rollout/durgash_attack.png
production/qa/evidence/axes/rollout/ghar_attack.png
production/qa/evidence/axes/rollout/ghar_guard_wall.png
production/qa/evidence/axes/rollout/ghar_guard_wall_low.png
production/qa/evidence/axes/rollout/ghar_wall_counter.png
production/qa/evidence/axes/rollout/ghar_wall_counter_low.png
production/qa/evidence/axes/rollout/mobs_axes.png
production/qa/evidence/axes/rollout/strip_common_idle.png
production/qa/evidence/axes/rollout/strip_e10_atk_sweep.png
production/qa/evidence/axes/rollout/strip_e20_titan_front.png
production/qa/evidence/axes/rollout/strip_e30_atk_2h.png
production/qa/evidence/axes/rollout/strip_e30_atk_2h_female.png
production/qa/evidence/axes/rollout/strip_g20_atk_dual_a.png
production/qa/evidence/axes/rollout/tiers_carniceiro.png
production/qa/evidence/axes/rollout/tiers_carniceiro_female.png
production/qa/evidence/axes/rollout/tiers_carniceiro_front.png
production/qa/evidence/axes/rollout/tiers_executor_female.png
production/qa/evidence/axes/rollout/tiers_executor_front.png
production/qa/evidence/shields-mount/game_block_shield_defensor_castelo_aparo.png
production/qa/evidence/shields-mount/game_block_shield_defensor_castelo_arco.png
production/qa/evidence/shields-mount/game_block_shield_defensor_castelo_bloqueio.png
production/qa/evidence/shields-mount/game_block_shield_deus_guerra_aparo.png
production/qa/evidence/shields-mount/game_block_shield_deus_guerra_arco.png
production/qa/evidence/shields-mount/game_block_shield_deus_guerra_bloqueio.png
production/qa/evidence/shields-mount/game_block_shield_iron_aparo.png
production/qa/evidence/shields-mount/game_block_shield_iron_arco.png
production/qa/evidence/shields-mount/game_block_shield_muro_suspiros_aparo.png
production/qa/evidence/shields-mount/game_block_shield_muro_suspiros_arco.png
production/qa/evidence/shields-mount/game_block_shield_muro_suspiros_bloqueio.png
production/qa/evidence/shields-mount/lineup_guard_p1.png
production/qa/evidence/shields-mount/lineup_idle_p1.png
production/qa/evidence/shields-mount/shields_02.png
production/qa/evidence/shields-mount/shields_04.png
production/qa/evidence/shields-mount/shields_05.png
production/qa/evidence/shields-mount/shields_06.png
production/qa/evidence/shields-mount/shields_07.png
production/qa/evidence/shields-mount/shields_08.png
production/qa/evidence/shields-mount/straps/alca_frente_corrida_guardajogo_01.png
production/qa/evidence/shields-mount/straps/alca_frente_corrida_guardajogo_02.png
production/qa/evidence/shields-mount/straps/alca_frente_corrida_guardajogo_03.png
production/qa/evidence/shields-mount/straps/alca_icone_jogo_guarda_01.png
production/qa/evidence/shields-mount/straps/alca_icone_jogo_guarda_02.png
production/qa/evidence/shields-mount/straps/alca_icone_jogo_guarda_03.png
production/qa/evidence/shields-mount/straps/strap_vertices_fora.json
production/qa/evidence/shields-mount/study_search.json
```

## Flagged files

- **EOL flip**: entity_view.gd and map_builder.gd (open question 2).
- `tools/blender/druid_sets.py` is CRLF in HEAD and in the working tree (EOL kept; the diff is the real 20 lines).
- Mixed EOL: `.claude/docs/ragnaex/*.md` (4 files, HEAD LF, working tree LF with 5-16 CRLF lines each; `.gitattributes` normalizes `.claude/**/*.md`, git warns 'CRLF will be replaced'), `docs/DESIGN.md` (10 CRLF lines in an LF file), `design/ux/start-flow.md` (39 CRLF / 265 LF), `tools/icons/set_icons.gd` (3 CRLF). `production/commit-plan-startflow.md` is pure CRLF. The earlier start-flow plan claimed 'CRLF like the rest of the tree': not true for these files.
- Largest binaries: `kit_paladin_male.glb` ~8.8 MB (all 18 kits ~5 MB each, rebuilt by ground-clip; commit 12 is ~95 MB), `map_kharzun_citadel.glb` ~5.7 MB, `menu_set.glb` ~1.8 MB, 26 loading `.jpg`. Nothing above 20 MB.
- No stray `.tmp`, `.log` or PNG at the repo root (the only PNGs outside evidence are `assets/ui/logo_*.png`, planned in commit 5). `bash.exe.stackdump` in post-int is tracked and unmodified here.
- Master root (not this plan) also has untracked `design/balance/` (bal45), `production/qa/attack-anim-audit-2026-11-14.md` and a copy of the menu files; those belong to the pending branches or to a separate pass, not to post-int.
- `loading_art.py` `ZONES`/`BOSSES` mirror the catalog by hand; `_check_loading_art` (sf-guard, in commit 14) now covers the jpg existence and the mirror.

## Commits (in order)

Path lists are exact (`scratchpad/postplan/plan.py check` maps every path to one commit or the excluded list). Append to every message: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

### 1. `feat(save): atomic slot writes and damaged-slot detection`

Files: **1** (0.0 MB)

Message body:
```text
Spec: design/ux/start-flow.md section 5 and Q7.
SaveSystem.slot_state (empty|ok|corrupt), save_<n>.json.tmp + rename, _settle_tmp recovery,
first_free_slot only returns empty slots, delete_slot also removes .tmp and the portrait
(SaveSystem.PORTRAIT_PATH, the one path Portrait.path also uses).
Save format unchanged.
```
```bash
git add -- \
  core/save_system.gd
```

### 2. `feat(menu): start scene as main scene with staged world build, BOOT timings and boot splash`

Files: **19** (0.5 MB)

Message body:
```text
Spec: design/ux/start-flow.md sections 6-9 (P1 routing + Agent A).
run/main_scene = game/menu/start.tscn; StartRequest hands data to main; main.build_world(staged)
builds the world in steps (dev/autostart stays synchronous); BOOT <step> <ms> prints; main.save_game()
is the save point; F11 moves to WindowKeys; StartDev holds the review flags; DevRunner.autostart_class.
launch() runs once (a repeated Enter during the 2-frame wait no longer opens a second Loading overlay that never
finishes) and locks the screen input; Title/Creation routing uses CharList.has_any (same source as the list,
so --menu_saves is consistent); main._fail drops the threaded loads it never consumed (StartRequest.drop_loads).
Boot: start.gd and main.gd no longer name DevRunner as a type; it is load()ed only with dev args
(DEV_RUNNER_SCRIPT), so its graph does not compile on the normal path. start.tscn load 2.52-2.77 s ->
1.54-1.63 s, BOOT start_enter ~5.16 s -> ~4.25 s (3 alternating headless pairs, --path).
Removes game/ui/class_select.gd and its hud entry points (user-approved deletion).
Shared files ship whole here (user rule): hud.gd, main.gd, dev_runner.gd also carry the UI-polish parts
(boss shout banner, labels hidden under the HUD, nameplate pixel size, --probe_px dev flag).
Boot splash (worktree boot-splash): application/boot_splash/* in project.godot (bg = default_clear_color,
stretch Keep, filter), assets/ui/boot_splash.png 2560x1440 generated by tools/splash/make_splash.tscn, which
reads TitleScreen.LOGO/SUBTITLE/LOGO_W/LOGO_TOP/SUBTITLE_W/SUBTITLE_OVERLAP so the logo does not jump when
the Title fades in. The splash covers engine + autoloads + start.tscn _ready (~7 s, BOOT start_enter).
This commit alone does not load; only HEAD must pass the suite.
Ref: production/qa/art-review-2026-11-13-r2.md (UI polish part).
```
```bash
# class_select.gd and its .uid are deleted in the working tree; -A stages the deletion
git add -A -- \
  assets/ui/boot_splash.png \
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
  project.godot \
  tools/splash/make_splash.gd \
  tools/splash/make_splash.gd.uid \
  tools/splash/make_splash.tscn
```

### 3. `perf(sim): bot spawn caches - 17 s to ~1 s at game start, identical world`

Files: **5** (0.2 MB)

Message body:
```text
Spec: design/ux/start-flow.md section 7 (BOOT showed bots = ~82% of the load). User-approved fixes: bot_spend step-4 ranking cache per (class, build, lean); tree_allocate/bot_spend/bot_pick batch mode (stats recomputed once, spawn_bot only); ClassTalentsCatalog built once (build() returns a copy) and warmed in GameData._ready (the lazy cache has no lock and the sim ticks on a worker thread); _gear_bot scan cache. Bot dump MD5 and sim_probe --suite checksum unchanged; _check_bot_spawn_cache.
world_sim.gd ships whole here and also carries the deterministic-RNG fix: WorldSim._init seeds RNG_SEED
(see the folded fix(test) entry; its check _check_sim_rng_fresh lives in run_tests.gd, commit 14).
```
```bash
git add -- \
  core/sim/systems/class_talent_system.gd \
  core/sim/systems/progression_system.gd \
  core/sim/world_sim.gd \
  data/catalog/class_talents_catalog.gd \
  data/game_data.gd
```

### 4. `feat(menu): 3D camp set, menu audio and shared settings panel`

Files: **9** (0.0 MB)

Message body:
```text
Spec: design/ux/start-flow.md section 3 (Cenario, Configuracoes), section 9.
MenuSet (camera moves, dusk lighting, fire/sparks), MenuAudio (Aldara theme + UI sounds on the
Music/UI buses), SettingsPanel shared by the Title and the Esc menu, tools/menu_set_view.tscn.
SF-guard: MenuSet.SHOT_NUDGE (create-screen camera nudge so the pedestal is framed at 16:9 and 21:9).
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
Deleting the last character opens Creation in the first free slot (spec section 5: the list is never empty;
user decision 2026-11-15).
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
PedestalPreview (kit on the pedestal, silhouette for the empty slot, per-instance kit cache of MAX_MODELS
models; the kit scene is dropped with its evicted model).
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
entity_view.gd ships whole here and also carries the UI-polish nameplate work (model_top/plate_top:
plate above tall models; pixel size by distance).
Ref: production/qa/art-review-2026-11-13-r2.md (UI polish part).
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

### 11. `fix(art): Kharzun art review r5 - wolf cloth, shrine streaks, goblin forge, basalt pebbles`

Files: **6** (14.0 MB)

Message body:
```text
Fixes from the fifth Kharzun art-review round (field_kharzun, kharzun_citadel, dg_goblin).
Wolf cloth recolored, shrine streaks removed, goblin forge dressed, basalt pebbles added in
act2_dress.py / build_kharzun_citadel.py / places.py; the three map GLBs were rebuilt.
Sim data is unchanged (dress uses its own Random).
Evidence: production/qa/evidence/final-qa/r5/ (commit 17).
Ref: production/qa/art-review-2026-11-13-r2.md
```
```bash
git add -- \
  assets/models/map_dg_goblin.glb \
  assets/models/map_field_kharzun.glb \
  assets/models/map_kharzun_citadel.glb \
  tools/blender/zones/act2_dress.py \
  tools/blender/zones/build_kharzun_citadel.py \
  tools/blender/zones/places.py
```

### 12a. `feat(art): axe remodel - shared axe_kit, 1h/2h/dual axes with set glow, Durgash throne axe, orc/zombie/ghoul axes`

Files: **58** (5.1 MB)

Message body:
```text
Berserker axes redone from one parametric tools/blender/axe_kit.py (HEADS/COMMON/kit_axe): 1h, 2h and dual axes read
as axes (not clubs), per-set edge glow (berserker_sets.AXE_GLOW, axe_kit.EDGE_GLOW_ENERGY 1.0). Bosses and orcs take the
same head via mob_kit.humanoid(axe=...): Durgash throne axe, Ghar, clan guard, orc recruit/warrior/warlord, zombie, giant ghoul.
Item icons (art_axe*, ber_* weapon/offhand, skill_ber_*, class_berserker) re-photographed by item_icons/make_icons.
The player kits that carry these axes are rebuilt once in commit 12c; checks in commit 14 (_check_axe_kit).
Evidence: production/qa/evidence/axes/ and art-branch-verify/ (commit 17). Notes: production/qa/axes-redesign-2026-11-15.md (commit 15).
```
```bash
git add -- \
  assets/icons/art_axe2h_t4.png \
  assets/icons/art_axe2h_t5.png \
  assets/icons/art_axe_bone.png \
  assets/icons/art_axe_golem.png \
  assets/icons/art_axe_iron.png \
  assets/icons/art_axe_old.png \
  assets/icons/art_axe_t0.png \
  assets/icons/art_axe_t1.png \
  assets/icons/art_axe_t2.png \
  assets/icons/art_axe_t3.png \
  assets/icons/art_axe_t4.png \
  assets/icons/art_axe_t5.png \
  assets/icons/ber_e10_weapon.png \
  assets/icons/ber_e15_weapon.png \
  assets/icons/ber_e20_weapon.png \
  assets/icons/ber_e25_weapon.png \
  assets/icons/ber_e30_weapon.png \
  assets/icons/ber_e5_weapon.png \
  assets/icons/ber_g10_offhand.png \
  assets/icons/ber_g10_weapon.png \
  assets/icons/ber_g15_offhand.png \
  assets/icons/ber_g15_weapon.png \
  assets/icons/ber_g20_offhand.png \
  assets/icons/ber_g20_weapon.png \
  assets/icons/ber_g25_offhand.png \
  assets/icons/ber_g25_weapon.png \
  assets/icons/ber_g30_offhand.png \
  assets/icons/ber_g30_weapon.png \
  assets/icons/ber_g5_offhand.png \
  assets/icons/ber_g5_weapon.png \
  assets/icons/class_berserker.png \
  assets/icons/skill_ber_axe_storm.png \
  assets/icons/skill_ber_butcher.png \
  assets/icons/skill_ber_cleave.png \
  assets/icons/skill_ber_crimson_flurry.png \
  assets/icons/skill_ber_execute.png \
  assets/icons/skill_ber_glad_finale.png \
  assets/icons/skill_ber_hack.png \
  assets/icons/skill_ber_leap.png \
  assets/icons/skill_ber_throw_axe.png \
  assets/icons/skill_ber_whirlwind.png \
  assets/models/mob_clan_guard.glb \
  assets/models/mob_durgash.glb \
  assets/models/mob_ghar.glb \
  assets/models/mob_ghoul_giant.glb \
  assets/models/mob_orc_recruit.glb \
  assets/models/mob_orc_warlord.glb \
  assets/models/mob_orc_warrior.glb \
  assets/models/mob_zombie.glb \
  assets/models/prop_durgash_throneaxe.glb \
  tools/blender/act2_bosses.py \
  tools/blender/axe_kit.py \
  tools/blender/berserker_sets.py \
  tools/blender/kharzun_mobs.py \
  tools/blender/mob_kit.py \
  tools/blender/sig_props_b.py \
  tools/icons/item_icons.gd \
  tools/icons/make_icons.gd
```

### 12b. `feat(art): close shield mounts - per-style SHIELD_MOUNTS, grip and trimmed strap welded into the shield, study/apply tools`

Files: **50** (0.9 MB)

Message body:
```text
Named shields sat 0.19 m off the forearm. chibi_kit.py now mounts each of the 40 shield styles close (SHIELD_MOUNTS from a
search against the common body and set helmets), the grip/strap is welded into the shield mesh (the wpn_off_grip meshes are
gone, -2 meshes per kit; mobs keep the old mount via kit_shield close=False) and the strap is clipped to the plate silhouette
(_strap_window/_strap_cut). kit_model.gd drops the grip wiring; shield_mount.py --check 0 touches; study/apply tools
(shield_mount_study.py, shield_mount_apply.py), lineup --tiers --levels/--view, shield and offhand icons re-photographed.
This supersedes the starter-shield (tabuas) mount of the earlier ground-clip text. Kits rebuilt once in commit 12c.
Checks in commit 14: _check_shield_mounts. Evidence: production/qa/evidence/shields-mount/ (commit 17).
Notes: production/qa/shields-mount-2026-11-15.md, docs/shields_review.md (commit 15).
```
```bash
git add -- \
  assets/icons/bis_b10_offhand.png \
  assets/icons/bis_b15_offhand.png \
  assets/icons/bis_b20_offhand.png \
  assets/icons/bis_b25_offhand.png \
  assets/icons/bis_b30_offhand.png \
  assets/icons/bis_b5_offhand.png \
  assets/icons/bis_s10_offhand.png \
  assets/icons/bis_s15_offhand.png \
  assets/icons/bis_s20_offhand.png \
  assets/icons/bis_s25_offhand.png \
  assets/icons/bis_s30_offhand.png \
  assets/icons/bis_s5_offhand.png \
  assets/icons/pal1_offhand.png \
  assets/icons/pal_g10_offhand.png \
  assets/icons/pal_g15_offhand.png \
  assets/icons/pal_g20_offhand.png \
  assets/icons/pal_g25_offhand.png \
  assets/icons/pal_g30_offhand.png \
  assets/icons/pal_t10_offhand.png \
  assets/icons/pal_t15_offhand.png \
  assets/icons/pal_t20_offhand.png \
  assets/icons/pal_t25_offhand.png \
  assets/icons/pal_t30_offhand.png \
  assets/icons/pal_t5_offhand.png \
  assets/icons/shield_abraco_criador.png \
  assets/icons/shield_alado_negro.png \
  assets/icons/shield_asa_angelical.png \
  assets/icons/shield_bone.png \
  assets/icons/shield_defensor_antigo.png \
  assets/icons/shield_defensor_castelo.png \
  assets/icons/shield_deus_guerra.png \
  assets/icons/shield_dragao_pantano.png \
  assets/icons/shield_dragon.png \
  assets/icons/shield_iron.png \
  assets/icons/shield_lamento_gaia.png \
  assets/icons/shield_luz_cristal.png \
  assets/icons/shield_muro_suspiros.png \
  assets/icons/shield_osso_besta.png \
  assets/icons/shield_palavra_deus.png \
  assets/icons/shield_perdao_alice.png \
  assets/icons/shield_senhor_crueldade.png \
  assets/icons/shield_wood.png \
  game/entities/kit_model.gd \
  tools/blender/chibi_kit.py \
  tools/blender/shield_mount.py \
  tools/blender/shield_mount_apply.py \
  tools/blender/shield_mount_study.py \
  tools/icons/set_icons.gd \
  tools/icons/shield_icons.gd \
  tools/lineup/lineup.gd
```

### 12c. `chore(art): rebuild all kits and wolf/bear forms - ground clip, axes, close shields, edge glow and dash exit (kits go into history once)`

Files: **21** (97.7 MB)

Message body:
```text
Single rebuild of the 18 player kits and form_wolf/form_bear (byte-deterministic build from commits 12a/12b plus the ground-clip work):
chibi_kit.clear_ground (per-frame solver, export-faithful FK, turn limited per frame; "Saida da correcao" ease for dash),
clear_weapons per class in build_kit, druid_sets.clear_form_ground for maul/pounce/slam/attack ("pitch" modes: the first
version flipped the front legs 145-173 deg). Weapon tips and form paws no longer go 0.6-1.0 m under the ground; the dash
ends within 43 deg of the authored pose (was 152 for the berserker). The 6 kits of classes without axe/shield change
(assassin, ranger, forms) differ from HEAD only by the ground clip.
Checks in commit 14: _check_hand_twist, _check_form_leg_twist, _check_shield_mounts, _check_axe_kit.
Evidence: production/qa/evidence/ground-clip/ and art-branch-verify/ (commit 17).
Ref: production/qa/art-review-2026-11-13-r2.md
```
```bash
git add -- \
  assets/models/form_bear.glb \
  assets/models/form_wolf.glb \
  assets/models/kit_assassin_female.glb \
  assets/models/kit_assassin_male.glb \
  assets/models/kit_berserker_female.glb \
  assets/models/kit_berserker_male.glb \
  assets/models/kit_bishop_female.glb \
  assets/models/kit_bishop_male.glb \
  assets/models/kit_druid_female.glb \
  assets/models/kit_druid_male.glb \
  assets/models/kit_elementalist_female.glb \
  assets/models/kit_elementalist_male.glb \
  assets/models/kit_female.glb \
  assets/models/kit_male.glb \
  assets/models/kit_necromancer_female.glb \
  assets/models/kit_necromancer_male.glb \
  assets/models/kit_paladin_female.glb \
  assets/models/kit_paladin_male.glb \
  assets/models/kit_ranger_female.glb \
  assets/models/kit_ranger_male.glb \
  tools/blender/druid_sets.py
```

### 13. `fix(ui): combat text, nameplates and HUD polish`

Files: **6** (0.2 MB)

Message body:
```text
UI polish round 2 (art review r2).
Esquiva merge window in float text; hostile aura ring removed (fx_manager); mob line-hit ground slab
(skill_fx); crows/bats (ambient_life); opaque chat/Quests panels; Aldara doormat rug (map_builder);
clean boss crowd line (mob_system).
Parts that live in files shipped earlier in this series (shared files, user rule): boss shout banner, labels
hidden under the HUD, --probe_px (commit 2: hud.gd, main.gd, dev_runner.gd); nameplate pixel size by
distance and plate above tall models (commit 8: entity_view.gd); _check_ui_polish_r2 (commit 14: run_tests.gd).
Evidence: production/qa/evidence/final-qa/ui-polish/ (commit 17).
Ref: production/qa/art-review-2026-11-13-r2.md
```
```bash
git add -- \
  core/sim/systems/mob_system.gd \
  game/fx/float_text.gd \
  game/fx/fx_manager.gd \
  game/fx/skill_fx.gd \
  game/world/ambient_life.gd \
  game/world/map_builder.gd
```

### 14. `test: start flow, deterministic test RNG, form-leg turn and UI polish checks`

Files: **1** (1.1 MB)

Message body:
```text
Spec: design/ux/start-flow.md section 10.
Start flow: _check_start_flow, _check_char_create, _check_char_list, _check_menu_set, _check_settings_panel,
_check_loading_steps, _check_save_slots, _check_title_screen, _check_bot_spawn_cache.
fix(test) part: _check_sim_rng_fresh (WorldSim._init seeds RNG_SEED, so the suite no longer depends on
the order of earlier checks; the seed itself shipped in commit 3 with world_sim.gd). Pass-count determinism:
_seeded_rng() replaces every unseeded RandomNumberGenerator.new() in the test brains and rolls, and
--count_per_check prints passes per check function to diff two runs.
Ground clip: _check_form_leg_twist (form_wolf/form_bear front legs <= 45 deg per 60 Hz step in
slam/pounce/maul/attack; fails on the first ground-clip forms at 69/51 deg; --form_dir=<dir> measures other GLBs).
sf-guard: _check_loading_art (every scenic map has its loading jpg; ZONES/BOSSES in loading_art.py checked against the catalog) and the SHOT_NUDGE framing asserts in _check_menu_set.
Boot splash: _check_boot_splash (image exists at 2560x1440, bg_color = clear color, corners on bg, stretch Keep + filter).
bal45: _check_twin_fury asserts the 45 nodes arena_finale/tem_dawn/frost_lord (stat + gate flag), _check_asc_web_fill
expects TEM_DAWN_FLAG/FROST_LORD_FLAG bought, _check_ancestral_forms uses the per-refine ANC_REFINE_POWER_NODE (code in commit 18).
UI polish: _check_ui_polish_r2. Review fixes: _check_start_routing (launch once + input lock, has_any routing,
delete-last -> Creation, drop_loads), pedestal scene eviction, portrait path constant, ClassTalentsCatalog warm,
and _check_bot_spawn_cache really starts its 2nd round with empty caches.
run_tests.gd is touched by every theme, so it ships whole in this one commit.
Ref: production/qa/art-review-2026-11-13-r2.md
```
```bash
git add -- \
  tools/tests/run_tests.gd
```

### 15. `docs: start flow implementation notes, README, DESIGN, project manual, commit plans and playtest checklist`

Files: **15** (0.4 MB)

Message body:
```text
Spec: design/ux/start-flow.md (new 'Implementacao' section: what shipped, deviations).
README start flow and save; DESIGN 'Tela inicial'; manual (comandos, conteudo, save, desempenho)
with the new flags, slot_state/atomic write, BOOT timings and the menu/loading art pipeline.
Art notes: manual modelos.md/conteudo.md (axe_kit, close shield mounts, edge glow, dash exit), docs/shields_review.md 'Montagem rente', production/qa/shields-mount-2026-11-15.md and axes-redesign-2026-11-15.md.
Also the two commit plans (this one supersedes the start-flow one) and the playtest checklist of the
post-int build (production/qa/playtest-checklist-2026-11-15.md).
DESIGN also gets the bal45 bullet 'F5 no 45 com alvo ~1,30' (knob table, measured bases; code in commit 18).
```
```bash
git add -- \
  .claude/docs/ragnaex/comandos.md \
  .claude/docs/ragnaex/conteudo.md \
  .claude/docs/ragnaex/desempenho.md \
  .claude/docs/ragnaex/modelos.md \
  .claude/docs/ragnaex/save.md \
  README.md \
  design/ux/start-flow.md \
  docs/DESIGN.md \
  docs/shields_review.md \
  production/commit-plan-post-int.md \
  production/commit-plan-startflow.md \
  production/patch-notes-2026-11-15.md \
  production/qa/axes-redesign-2026-11-15.md \
  production/qa/playtest-checklist-2026-11-15.md \
  production/qa/shields-mount-2026-11-15.md
```

### 16. `docs(qa): start flow key evidence - boot splash, title, settings, list, delete, creation, loading, return`

Files: **22** (12.8 MB)

Message body:
```text
Spec: design/ux/start-flow.md section 11.
16 hand-picked PNG; the other start-flow captures stay on disk, untracked and ignored.
Boot splash: splash -> Title handover at 7.0/7.5/8.0 s (dev run, 1920x1080, logo in place), the exported exe
showing the splash at 3 s, and the post-int boot timeline log.
.gitignore ships whole here with the blocks for ALL evidence folders (start-flow, shield-fix, shields-mount, art-branch-verify, axes and the
r5/ui-polish and ground-clip picks of commit 17); apply the edit below BEFORE this commit.
```
Before this commit append to `.gitignore` (tested against the real HEAD `.gitignore` in a temp repo: leaves exactly the 45 picks):
```gitignore
# Post-int QA evidence: only the curated picks are kept; the rest stays on disk, untracked/ignored.
# final-qa/r5 and final-qa/ui-polish are already ignored by 'final-qa/**' (+ '!final-qa/**/'); only their picks are re-included.
# start-flow, shield-fix, ground-clip and boot-splash: untracked folders -> ignore all, re-include sub-directories, re-include picks.
production/qa/evidence/start-flow/**
!production/qa/evidence/start-flow/**/
production/qa/evidence/shield-fix/**
!production/qa/evidence/shield-fix/**/
production/qa/evidence/ground-clip/**
!production/qa/evidence/ground-clip/**/
production/qa/evidence/boot-splash/**
!production/qa/evidence/boot-splash/**/
!production/qa/evidence/boot-splash/boot_timeline_postint.log
!production/qa/evidence/boot-splash/export_exe_03000ms.png
!production/qa/evidence/boot-splash/handover_1_splash_7000ms.png
!production/qa/evidence/boot-splash/handover_2_fade_7500ms.png
!production/qa/evidence/boot-splash/handover_3_title_8000ms.png
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
!production/qa/evidence/shield-fix/sheet_before_after.png
!production/qa/evidence/shield-fix/before_tabuas_idle_game45.png
!production/qa/evidence/shield-fix/after_tabuas_idle_game45.png
!production/qa/evidence/shield-fix/after_tabuas_block_shield_front.png
!production/qa/evidence/shield-fix/game/block_wood_bloqueio.png
!production/qa/evidence/ground-clip/anim_probe_master_vs_worktree_round3.txt
!production/qa/evidence/ground-clip/bear_slam_after.png
!production/qa/evidence/ground-clip/bear_slam_before.png
!production/qa/evidence/ground-clip/form_wolf_pounce_round3.png
!production/qa/evidence/ground-clip/min_height_before_after.txt
!production/qa/evidence/ground-clip/spear_atk_finisher_after.png
!production/qa/evidence/ground-clip/spear_atk_finisher_before.png
!production/qa/evidence/ground-clip/sword2h_atk_2h_after.png
!production/qa/evidence/ground-clip/sword2h_atk_2h_before.png
!production/qa/evidence/final-qa/r5/before_dg_goblin_CAMX_forja.png
!production/qa/evidence/final-qa/r5/after_dg_goblin_CAMX_forja.png
!production/qa/evidence/final-qa/r5/after_kharzun_CAMX_santuario.png
!production/qa/evidence/final-qa/r5/after_kharzun_CAMX_canil.png
!production/qa/evidence/final-qa/r5/after_citadel_CAMX_arena_lobo.png
!production/qa/evidence/final-qa/ui-polish/after3/player_after.png
!production/qa/evidence/final-qa/ui-polish/after/boss34/boss_ulgra.png
!production/qa/evidence/final-qa/ui-polish/after3/before34/boss_troll_king.png
!production/qa/evidence/final-qa/ui-polish/after3/after34/boss_troll_king.png
!production/qa/evidence/final-qa/ui-polish/after/aldara_porta_botica.png
# shields-mount, art-branch-verify, axes (art branch, commit 17): ignore all, re-include sub-directories, re-include picks.
production/qa/evidence/shields-mount/**
!production/qa/evidence/shields-mount/**/
production/qa/evidence/art-branch-verify/**
!production/qa/evidence/art-branch-verify/**/
production/qa/evidence/axes/**
!production/qa/evidence/axes/**/
!production/qa/evidence/shields-mount/shields_01.png
!production/qa/evidence/shields-mount/shields_03.png
!production/qa/evidence/shields-mount/icons_antes_depois.png
!production/qa/evidence/shields-mount/lineup_guard_p0.png
!production/qa/evidence/shields-mount/lineup_idle_p0.png
!production/qa/evidence/shields-mount/game_block_shield_iron_bloqueio.png
!production/qa/evidence/shields-mount/study_final.json
!production/qa/evidence/shields-mount/straps/icones_antes_depois.png
!production/qa/evidence/art-branch-verify/glow/glow_antes_depois.png
!production/qa/evidence/art-branch-verify/glow/icons_antes_depois.png
!production/qa/evidence/art-branch-verify/glow/jogo_executor_20.png
!production/qa/evidence/art-branch-verify/glow/jogo_carniceiro_30.png
!production/qa/evidence/art-branch-verify/glow/g20_violet_game_antes.png
!production/qa/evidence/art-branch-verify/glow/g20_violet_game_depois.png
!production/qa/evidence/art-branch-verify/dash/anim_probe_dash_antes_depois.txt
!production/qa/evidence/art-branch-verify/dash/berserker_executor30_side_antes.png
!production/qa/evidence/art-branch-verify/dash/berserker_executor30_side_depois.png
!production/qa/evidence/art-branch-verify/anim_probe_kits_vs_ground_clip.txt
!production/qa/evidence/axes/godot_old_strip_e10_sweep.png
!production/qa/evidence/axes/godot_new_strip_e10_sweep.png
!production/qa/evidence/axes/godot_old_tiers_carniceiro.png
!production/qa/evidence/axes/godot_new_tiers_carniceiro.png
!production/qa/evidence/axes/rollout/tiers_executor.png
!production/qa/evidence/axes/rollout/mobs_axes_bosses.png
!production/qa/evidence/axes/rollout/icons_axe_sheet.png
!production/qa/evidence/axes/followup/throneaxe_before.png
!production/qa/evidence/axes/followup/throneaxe_after.png
```
Before commit 17, copy the 10 picks that only exist in the source worktrees (plain `cp`, no git):
```bash
W=C:/Users/luisf/Desktop/projects/ragnaex/.claude/worktrees
mkdir -p "$W/post-int/production/qa/evidence/final-qa/r5" && cp "$W/art-r5/production/qa/evidence/final-qa/r5/before_dg_goblin_CAMX_forja.png" "$W/post-int/production/qa/evidence/final-qa/r5/before_dg_goblin_CAMX_forja.png"
mkdir -p "$W/post-int/production/qa/evidence/final-qa/r5" && cp "$W/art-r5/production/qa/evidence/final-qa/r5/after_dg_goblin_CAMX_forja.png" "$W/post-int/production/qa/evidence/final-qa/r5/after_dg_goblin_CAMX_forja.png"
mkdir -p "$W/post-int/production/qa/evidence/final-qa/r5" && cp "$W/art-r5/production/qa/evidence/final-qa/r5/after_kharzun_CAMX_santuario.png" "$W/post-int/production/qa/evidence/final-qa/r5/after_kharzun_CAMX_santuario.png"
mkdir -p "$W/post-int/production/qa/evidence/final-qa/r5" && cp "$W/art-r5/production/qa/evidence/final-qa/r5/after_kharzun_CAMX_canil.png" "$W/post-int/production/qa/evidence/final-qa/r5/after_kharzun_CAMX_canil.png"
mkdir -p "$W/post-int/production/qa/evidence/final-qa/r5" && cp "$W/art-r5/production/qa/evidence/final-qa/r5/after_citadel_CAMX_arena_lobo.png" "$W/post-int/production/qa/evidence/final-qa/r5/after_citadel_CAMX_arena_lobo.png"
mkdir -p "$W/post-int/production/qa/evidence/final-qa/ui-polish/after3" && cp "$W/ui-polish/production/qa/evidence/final-qa/ui-polish/after3/player_after.png" "$W/post-int/production/qa/evidence/final-qa/ui-polish/after3/player_after.png"
mkdir -p "$W/post-int/production/qa/evidence/final-qa/ui-polish/after/boss34" && cp "$W/ui-polish/production/qa/evidence/final-qa/ui-polish/after/boss34/boss_ulgra.png" "$W/post-int/production/qa/evidence/final-qa/ui-polish/after/boss34/boss_ulgra.png"
mkdir -p "$W/post-int/production/qa/evidence/final-qa/ui-polish/after3/before34" && cp "$W/ui-polish/production/qa/evidence/final-qa/ui-polish/after3/before34/boss_troll_king.png" "$W/post-int/production/qa/evidence/final-qa/ui-polish/after3/before34/boss_troll_king.png"
mkdir -p "$W/post-int/production/qa/evidence/final-qa/ui-polish/after3/after34" && cp "$W/ui-polish/production/qa/evidence/final-qa/ui-polish/after3/after34/boss_troll_king.png" "$W/post-int/production/qa/evidence/final-qa/ui-polish/after3/after34/boss_troll_king.png"
mkdir -p "$W/post-int/production/qa/evidence/final-qa/ui-polish/after" && cp "$W/ui-polish/production/qa/evidence/final-qa/ui-polish/after/aldara_porta_botica.png" "$W/post-int/production/qa/evidence/final-qa/ui-polish/after/aldara_porta_botica.png"
```
```bash
git add -- \
  .gitignore \
  production/qa/evidence/boot-splash/boot_timeline_postint.log \
  production/qa/evidence/boot-splash/export_exe_03000ms.png \
  production/qa/evidence/boot-splash/handover_1_splash_7000ms.png \
  production/qa/evidence/boot-splash/handover_2_fade_7500ms.png \
  production/qa/evidence/boot-splash/handover_3_title_8000ms.png \
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

### 17. `docs(qa): evidence - Kharzun r5, shield mounts, axes, ground clip, glow/dash, UI polish`

Files: **51** (46.1 MB)

Message body:
```text
Key before/after captures: 5 for final-qa/r5 (goblin forge, shrine, kennel, wolf arena), 5 for shield-fix
(sheet + tabuas in game45/block), 5 for final-qa/ui-polish (HUD panels, boss banner, nameplates, Aldara rug),
9 for ground-clip, 8 for shields-mount (contact sheets, icons before/after, lineup, iron block, study_final.json, strap icons),
10 for art-branch-verify (glow, g20 violet, dash before/after, anim_probe tables), 9 for axes (old/new strips and tiers, bosses, icons, Durgash throne axe),
9 for ground-clip (min-height and anim_probe tables, spear/2h-sword/bear-slam strips before/after, wolf pounce round 3).
The rest stays on disk, ignored.
Ref: production/qa/art-review-2026-11-13-r2.md
```
```bash
git add -- \
  production/qa/evidence/final-qa/r5/after_citadel_CAMX_arena_lobo.png \
  production/qa/evidence/ground-clip/anim_probe_master_vs_worktree_round3.txt \
  production/qa/evidence/ground-clip/bear_slam_after.png \
  production/qa/evidence/ground-clip/bear_slam_before.png \
  production/qa/evidence/ground-clip/form_wolf_pounce_round3.png \
  production/qa/evidence/ground-clip/min_height_before_after.txt \
  production/qa/evidence/ground-clip/spear_atk_finisher_after.png \
  production/qa/evidence/ground-clip/spear_atk_finisher_before.png \
  production/qa/evidence/ground-clip/sword2h_atk_2h_after.png \
  production/qa/evidence/ground-clip/sword2h_atk_2h_before.png \
  production/qa/evidence/final-qa/r5/after_dg_goblin_CAMX_forja.png \
  production/qa/evidence/final-qa/r5/after_kharzun_CAMX_canil.png \
  production/qa/evidence/final-qa/r5/after_kharzun_CAMX_santuario.png \
  production/qa/evidence/final-qa/r5/before_dg_goblin_CAMX_forja.png \
  production/qa/evidence/final-qa/ui-polish/after/aldara_porta_botica.png \
  production/qa/evidence/final-qa/ui-polish/after/boss34/boss_ulgra.png \
  production/qa/evidence/final-qa/ui-polish/after3/after34/boss_troll_king.png \
  production/qa/evidence/final-qa/ui-polish/after3/before34/boss_troll_king.png \
  production/qa/evidence/final-qa/ui-polish/after3/player_after.png \
  production/qa/evidence/shield-fix/after_tabuas_block_shield_front.png \
  production/qa/evidence/shield-fix/after_tabuas_idle_game45.png \
  production/qa/evidence/shield-fix/before_tabuas_idle_game45.png \
  production/qa/evidence/shield-fix/game/block_wood_bloqueio.png \
  production/qa/evidence/shield-fix/sheet_before_after.png \
  production/qa/evidence/shields-mount/shields_01.png \
  production/qa/evidence/shields-mount/shields_03.png \
  production/qa/evidence/shields-mount/icons_antes_depois.png \
  production/qa/evidence/shields-mount/lineup_guard_p0.png \
  production/qa/evidence/shields-mount/lineup_idle_p0.png \
  production/qa/evidence/shields-mount/game_block_shield_iron_bloqueio.png \
  production/qa/evidence/shields-mount/study_final.json \
  production/qa/evidence/shields-mount/straps/icones_antes_depois.png \
  production/qa/evidence/art-branch-verify/glow/glow_antes_depois.png \
  production/qa/evidence/art-branch-verify/glow/icons_antes_depois.png \
  production/qa/evidence/art-branch-verify/glow/jogo_executor_20.png \
  production/qa/evidence/art-branch-verify/glow/jogo_carniceiro_30.png \
  production/qa/evidence/art-branch-verify/glow/g20_violet_game_antes.png \
  production/qa/evidence/art-branch-verify/glow/g20_violet_game_depois.png \
  production/qa/evidence/art-branch-verify/dash/anim_probe_dash_antes_depois.txt \
  production/qa/evidence/art-branch-verify/dash/berserker_executor30_side_antes.png \
  production/qa/evidence/art-branch-verify/dash/berserker_executor30_side_depois.png \
  production/qa/evidence/art-branch-verify/anim_probe_kits_vs_ground_clip.txt \
  production/qa/evidence/axes/godot_old_strip_e10_sweep.png \
  production/qa/evidence/axes/godot_new_strip_e10_sweep.png \
  production/qa/evidence/axes/godot_old_tiers_carniceiro.png \
  production/qa/evidence/axes/godot_new_tiers_carniceiro.png \
  production/qa/evidence/axes/rollout/tiers_executor.png \
  production/qa/evidence/axes/rollout/mobs_axes_bosses.png \
  production/qa/evidence/axes/rollout/icons_axe_sheet.png \
  production/qa/evidence/axes/followup/throneaxe_before.png \
  production/qa/evidence/axes/followup/throneaxe_after.png
```

### 18. `feat(balance): level-45 ascension F5 buffs to ~1.30`

Files: **5** (0.2 MB)

Message body:
```text
User decision 2026-11-14: every build below F5 1.30 at level 45 rises to ~1.30; nothing is cut
(Fogo, Raio, Cruzado stay above). Kragmar, --lvl=45 --tank_lock, neutral tank + sacerdote + 2x build,
80 fights per arm over 2 seeds. Level 35 unchanged (weight x ASC_POWER_35_MULT products kept).
ASC_BUILD_POWER: lanceiro 3.5, atirador 11.5, cacador 3.0, laminas 1.03, duelista 1.0, corsario 0.85, fera 1.6;
TITAN_CLAW_POWER 1.35; TWIN_FURY_ATK 28; new atk_pct ARENA_FINALE_ATK 16 and ASC_TEM_DAWN_ATK 26, new matk_pct
ASC_FROST_LORD_MATK 15; gate flags TEM_DAWN_FLAG/FROST_LORD_FLAG so bots buy the 5-point 45 nodes;
DruidAscension.refine_power + ANC_REFINE_POWER_NODE (xama 45 refine 0.21, 35/40 stay 0.06).
Tables and measurements: docs/DESIGN.md (commit 15), design/balance/f5-45-split-proposal.md, f5-measure-2026-11-14.md.
Checks in commit 14. Ref GDD: design/gdd/ato2-horda.md.
```
```bash
git add --   core/sim/systems/druid_ascension.gd   data/balance.gd   data/catalog/ascension_catalog.gd   design/balance/f5-45-split-proposal.md   design/balance/f5-measure-2026-11-14.md
```

## Placeholders - work not merged yet

Re-run `plan.py check` after each merge: every new path must land in exactly one commit or the excluded list.

| Branch/worktree | Expected theme | Expected files | Notes |
|---|---|---|---|
| `bal45` | MERGED into post-int (2026-11-15): commit 18 `feat(balance): level-45 ascension F5 buffs to ~1.30` | `data/balance.gd`, `data/catalog/ascension_catalog.gd`, `core/sim/systems/druid_ascension.gd`, `design/balance/f5-45-split-proposal.md`, `design/balance/f5-measure-2026-11-14.md` (commit 18); `tools/tests/run_tests.gd` (commit 14); `docs/DESIGN.md` (commit 15) | 3-way merge on master 39b41b8, 0 conflicts. Nothing left to merge. |
| `sf-guard` | MERGED into post-int (2026-11-15): `_check_loading_art` + `MenuSet.SHOT_NUDGE` + 14 `start-flow/guard/` shots | `tools/tests/run_tests.gd` (commit 14), `game/menu/menu_set.gd` (commit 4), evidence excluded | Nothing left to merge; only re-run `plan.py check` if its worktree changes again. |
| `determinism` (flaky-sig) | MERGED into post-int (2026-11-15): `_seeded_rng()`, `--count_per_check`; world_sim.gd RNG hunks already identical | `tools/tests/run_tests.gd` (commit 14), `core/sim/world_sim.gd` (commit 3) | Folded (see 'Folded'). |
| `boot-splash` | MERGED into post-int (2026-11-15): folded into commit 2 (project.godot ships whole there) | `assets/ui/boot_splash.png`, `tools/splash/make_splash.{gd,gd.uid,tscn}` (commit 2), `_check_boot_splash` (commit 14), 5 evidence picks (commit 16), 11 excluded | make_splash.gd now reads the TitleScreen constants; regenerated PNG byte-identical (md5 fbacab7e...). `.import` is gitignored. Nothing left to merge. |
| `shields-mount` (art) | MERGED into post-int (2026-11-15): commits 12a/12b/12c (supersedes the old commit 12 and the ground-clip row) | axe/shield tools, mobs, icons, 18 kits + forms (12c), kit_model.gd, chibi_kit.py; checks in 14; docs in 15; 27 evidence picks in 17 | Includes `../axes` (axe QA doc + evidence) and ground-clip. If shields-mount changes again, re-copy the art files (they equal its state) and re-run `plan.py check`. |
| `ground-clip` | MERGED into post-int (2026-11-15): folded into commits 12b/12c (shared chibi_kit.py/kit_model.gd/kits; it superseded the shield-fix versions) | 18 kits + form_wolf/form_bear + chibi_kit.py, druid_sets.py, shield_mount.py, kit_model.gd, set_icons.gd, shield_icons.gd (commit 12); `_check_form_leg_twist` (commit 14); 9 evidence picks (commit 17), 8 excluded | Nothing left to merge. |

