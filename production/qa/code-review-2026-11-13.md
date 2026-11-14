# Code review: Kharzun phase 3 integration (wt/k-int vs master), 2026-11-13

Scope: uncommitted diff `git diff master` (90 files, +6741/-426) plus new files (BossSignatures, MountSystem,
BossSigView, FloatText, NameplateCrowd, 3 zones, Blender scripts). Static review only: Godot was NOT run
(the machine was at its limit), so `--import`, tests and smoke are still open. Other agents were still editing
Durgash unit_mods, asc35 balance, raid scale and the Aldara road, so those areas are reviewed as they stood at this time.

## Verdict: APROVADO (static), on condition that `--import` + `tools/tests/tests.tscn` (0 failed) + smoke pass

No blockers found. Architecture holds: core/ has no Node/Control/Input/shader/camera, all new core events go through
`Events.post(&"...")` (no `Events.x.emit` in the diff), new rules live in their systems (`BossSignatures`,
`MountSystem`, `GatherSystem.node_ready`, `ItemSystem.kharzun_tier`), and new public API has forwarders at the end of
world_sim.gd (`mount_unlocked`, `set_mount_kind`, `gather_ready`, `enhance*(..., smith)`). Save compatibility: OK
(see S1). EOL: all modified .gd/.py/.md/.json files keep the line endings they have on master.

## Major (fix before commit)

M1. data/balance.gd:639 `SHAZKA_DECOY_FADE := 0.35` is dead: nothing reads it. The real value is
    game/entities/entity_view.gd:157 `DECOY_FADE := 0.15`, which means two sources with different values.
    Fix: delete the Balance const, or make EntityView read `Balance.SHAZKA_DECOY_FADE` set to 0.15 (the same way
    `SHAZKA_SMOKE_ALPHA`/`GHAR_SHIELDWALL_SCALE` are read). This is the only unused new Balance const
    (the other three hits are only read inside balance.gd itself).
M2. core/sim/systems/mount_system.gd:23-33 sends two toasts on one hand-in. `on_quest_done` -> `set_kind` posts
    "Montaria: Lobo Atroz (tecla H)" and then `on_quest_done` posts "Nova montaria: ...". Fix: give `set_kind` a
    `notify := true` parameter and call it with false from `on_quest_done`.
M3. core/sim/systems/boss_signatures.gd:514 hardcodes the player-facing text "O tambor rasgou!" and line 515 hardcodes
    the fx radius 2.5 in core. Every other signature line comes from the effect dict (`say`). Fix: read
    `cfg.get("break_say", ...)` from `effects["boss_channel"]` in skills_catalog.

## Minor

m1. Tuning fallbacks as literals in core: boss_signatures.gd:424/430 (guarantee 2, near 5/9), 450 (radius 18),
    522/530/531/533 (on_done radius 20, duration 12, atk_pct 40, heal 0.3), 591 (wall time 6), 614-616 (counter
    base/step/cap), 641-642 (cone 150, range 5.5), 674-675/700 (decoy count/spread/time). The catalog always sets
    them, so these defaults only drift silently. Fix: move them to `Balance.BOSS_SIG_DEFAULTS`, or require the keys
    in `_check_boss_signatures` and drop the defaults.
m2. Tuning literals in bot_brain.gd: 339/1006 (dash when > 5 m), 943 (1.2 / 6.0 m behind the Wall), 1051 (25 m spread
    scan), 1599 (`minf(arc, 100.0)`), 1807 (16 m group centroid), 1861 (2 m soft-aim). Fix: `Balance.BOT_SIG_*`.
m3. Tuning literals in ascension_catalog.gd: node numbers inside `stats`/`desc` (fire_lord fire_pct 9, frost_lord 9,
    cru_wrath atk_pct 5.5, tem_rune INT 10 + desc "+10 INT", tem_dawn matk 3). Line 28 has a desc "+10% de poder"
    that duplicates `Balance.ARENA_FINALE.power` 1.1, and a retune will desync it. twin_fury already does it the right
    way (Balance const + %d in desc). Fix: same pattern for the nodes that were retuned.
m4. boss_signatures.gd:691 `c.stats.max_hp = e.stats.max_hp` is overwritten by the next `recompute_stats()` on the copy
    (any buff or debuff), so the copy HP bar can read above 100%. Low impact (copies die in one hit). Fix: set the
    copy max HP through the def/mods instead of patching `stats`.
m5. Small allocations per tick: `BossSignatures.update` -> `decoys_of()` builds an Array on every boss tick while copies
    live (<= 10 s); `update_hazards` still duplicates `hz` every tick on maps with hazards (inherited pattern).
    Fix: an allocation-free "any copy alive" check; iterate backwards over `hz`. Measure with
    `sim_probe --map=kharzun_citadel` (AC-36 <= 5 ms/tick).
m6. bot_brain.gd:761 `var first = null` is untyped (Variant). Fix: `var first: Dictionary = {}` and test `is_empty()`.
m7. game/fx/boss_sig_view.gd calls private `MapBuilder._prop_model` (254, 279, 368). Fix: make it public.
    boss_sig_view.gd:279-298: if the holder exists but has 0 children, it is never added to the tree (orphan Node3D leak),
    `_lava_pool` returns true and nothing draws. Fix: treat the empty holder as null (free it, draw the disc).
m8. NameplateCrowd can re-show a nameplate that a dev_runner photo hid (dev_runner.gd:553/585 set
    `nameplate.visible = false` directly, while `set_crowd_hidden(false)` flips it back). Dev-only. Fix: route
    review-shot hiding through a flag the crowd pass respects.
m9. New-file EOL is mixed: zone JSONs are CRLF (same as 17/23 existing), tools/blender/sig_props_c.py is CRLF while
    sig_props_a/b.py are LF. The repo was already mixed. Fix: normalise sig_props_c.py to LF.
m10. Durgash unit_mods, asc35 and raid scale were still being edited during this review. Re-run `_check_kharzun_bosses`,
    `_check_asc_power_35` and `_check_bot_raid` on the final tree.

## Save compatibility (S1)

- "mount" key: `SaveSystem.apply_to` reads it after quests_completed and runs it through `MountSystem.from_save`
  (an unknown kind, or one not unlocked yet, -> `Balance.MOUNT_DEFAULT`). An old save without the key becomes a horse.
  Tested in run_tests (`from_save(p, "dire_wolf") == "horse"`, `"xyz"`).
- QuestDef.reward_title: no new save field; `SimEntity.honor_title()` derives it from quests_completed. The nameplate only
  refreshes when the size of quests_completed changes (cached `_np_q`), so there is no per-frame scan. OK.
- `MapDef.mounts_ok`, `MonsterDef.cover/decoy/berserk_mult/burn_immune`: schema defaults keep old behaviour.

## Rule/content checks (coverage)

Covered by a check(...): boss signatures (rules, bots, Kragmar, Durgash, Kharzun), mount unlock/swap/save, honor title,
Thrain smith gate + Kharzun enhance materials, gather `if` stage gate (`gather_ready`), Lava Salamander burn immunity,
raid crowd table, RAID_MAP_POWER, no_mount, craft_only, FloatText, NameplateCrowd, mob_glow, twin_fury, bot
raid/ward/evade/turn/soft_in_danger/save_stun.
No direct check: `BotBrain._drag_spot`/`_side_escape` (only exercised through the Kragmar/bots signature checks; acceptable),
`ItemSystem.kharzun_tier` (only exercised through the enhance checks), and the npc_ui mount-keeper buttons (UI: needs a
screenshot in production/qa/evidence).
BuffLooks: ghar_wall, boss_channel, boss_temper, mob_frenzy and clan_wolf have entries plus SYSTEM_BUFFS sources; drum_torn
is a `curse` debuff and uses the kind visual (OK). The new effect keys (islands mark boss_channel repeat avalanche wall decoys)
are in `SkillDef.EFFECT_KEYS`.

## Strengths

- BossSignatures is cleanly stateless: state sits in m["hazards"], m["covers"] and SimEntity.sig; reset_boss clears
  everything (AC-S4); copies despawn on their own tick (safe inside the entity loop over a duplicate of `ents`).
- Presentation reads only: BossSigView redraws one ArrayMesh per frame from sim state. FloatText pools Label3D with a
  48 cap. NameplateCrowd is one O(n^2) pass every 0.2 s on trash only, with early break at CROWD_N.
- The lambdas in the diff contain no `if`; the new lerpf in game/ uses clamped weights.

## Results

Tests: NOT RUN (Godot not launched on purpose). Smoke: NOT RUN. ms/tick: not measured.
Required before commit: --import; tests.tscn (0 failed); smoke --autostart=berserker; sim_probe --map=field_kharzun and
--map=kharzun_citadel (<= 5 ms/tick).
