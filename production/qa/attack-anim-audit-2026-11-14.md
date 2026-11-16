# Attack animation and hit readability audit (2026-11-14)

Scope: player melee/staff attacks seen from the game camera (52 deg, 24 m). Read-only on code.
Author: technical-artist. Status: **proposal, waiting for the user to choose A / B / C.**

## 0. Evidence gap (read first)

Filming did not happen. The main checkout cannot start the game right now:
`SCRIPT ERROR: Parse Error: Identifier "BossSignatures" not declared` on every launch.
`core/sim/systems/boss_signatures.gd` has `class_name BossSignatures`, but
`.godot/global_script_class_cache.cfg` has 0 entries for it, so it needs `--import`. The brief
forbade `--import`. So the bench (`--showcase`) and `lineup --strip` both fail before the first frame.
Everything below comes from the code. Frame refs are computed timings, not screenshots.
**To close the gap:** run `--import` once, then the commands in section 5. They need about 4 minutes.

Side note: the attempted runs left up to five chained Godot launches in the background. Each one exits at
`timeout 300`. I could not stop them, because `taskkill` was denied.

## 1. Inventory: what exists today

### The "line" = `KitModel` weapon trail (ribbon)
- Node: `game/entities/kit_model.gd:140-153`. It is a `WeaponTrail` `MeshInstance3D` with `top_level` set, world-space
  vertices and an `ImmediateMesh`. Material: `StandardMaterial3D` unshaded, alpha **mix** (not add), vertex colour, no
  texture.
- Setup: `kit_model.gd:597-622`. There is one ribbon per melee weapon (main hand, plus the off hand when it is a 1-hand melee weapon). There is **no
  ribbon for bows**. The tip is the mesh vertex farthest from `hand.R`, times 1.05. The base is `tip * 0.18`, so the ribbon covers the outer ~82%
  of the weapon. Colour is `icon_color.lerp(pale blue, 0.35) * 1.6`.
- Draw: `kit_model.gd:624-656`. Each **render frame** it adds 1 sample (`[base_w, tip_w, t]`) from the bone pose
  and keeps samples for `TRAIL_TIME = 0.2 s` (line 12). It is drawn as a `TRIANGLE_STRIP`, with alpha 0.15 at the base and 0.9 at the tip,
  fading linearly by age.
- On/off: `game/entities/entity_view.gd:1691-1702`. It is on from `startup*0.35` to `startup+active+0.12`. Magic tints it with the
  theme colour (`trail_tint`), and pistol shots turn it off.

### Other hit feedback
| Feedback | Where | What it does |
|---|---|---|
| Hit flash | `world_sim.gd:1703` (`Balance.HIT_FLASH_TIME = 0.12`), `toon.gdshader:90-91`, `entity_view.gd:1092-1106` | The target goes full white for 0.12 s (albedo mix 1.0 + emission 0.6) |
| Flinch | `entity_view.gd:1095`, `:1838` | Monsters play `hit` for 0.22 s |
| Hit-stop | `world_sim.gd:1299-1300` posts `hit_stop`; `fx_manager.gd:263-266` | `Engine.time_scale = 0.05` for `frames/60` s, plus `camera.add_shake(0.03*frames)`. Basic = `Balance.HIT_STOP_FRAMES_BASIC = 2`; skills default 3, some set 6-7 (`ber_overhead`, `ber_decapitate`). It fires only when the player is involved. It is **global** (it freezes the whole world, not only attacker and target) |
| Camera shake | `fx_manager.gd:210, 266, 357, 393, 429` | On big damage taken, hit-stop, explosions and earth impacts |
| Cone fan | `skill_fx.gd:169-204` `sector()` + `decal_sector()` | A flat crescent at y = 0.7 with the real radius and angle (add blend), plus a faint floor fan |
| **Physical basic** | `fx_manager.gd:330-333` | `if th != "physical"` means a **plain physical basic gets no fan, no burst and no impact FX**. Only builds with a signature `look` get the fan |
| X-slash | `skill_fx.gd:400-417` `slash_x()` | A billboard X at the target, used only for physical TARGET skills, shield parry and Corsair |
| Dash streak / wave | `skill_fx.gd:344-397` | Stretched boxes and planes |
| Projectile trail | `fx_manager.gd:1037-1071` | Particles (skills) or a cone stub (basics) |
| Anim anticipation/follow-through | `tools/blender/chibi_kit.py:1497-1520` `_settle_attacks` | Anticipation is a 12% contraction at frame 2 and follow-through is an 8% overshoot. Both are subtle. The impact frames (`chibi_kit.py:875` = `EntityView.IMPACT_FRAME`) are lined up with the damage tick |

**Today, a plain physical sword/axe/spear basic = ribbon + white flash + flinch + number + 2-frame freeze.**
The ribbon is the only thing that shows *where* and *which way* the swing went, and that is why it "reads as a line".

## 2. Problems (from code; screenshots pending, see section 0)

Timing used below: a basic has startup 0.12 s and active 0.06 s (`game_data.gd` basic). The ribbon is on from **t = 0.04 s to t = 0.30 s**.
The clip is sped up to make impact land at t = 0.12 s, by up to `ANIM_MAX_SPEED = 3.2x` (`entity_view.gd:1545`).

1. **Few, straight samples, so a polygonal sliver.** The fast part of the swing (impact frame -2 to +1) lasts about 0.05-0.08 s.
   At 60 fps that is 3-5 samples. Neighbouring samples are joined by straight chords, so a 150 deg axe sweep becomes
   3-4 flat facets: a bent line, not an arc. At 30-40 fps (crowded hub) it drops to 2-3 samples.
2. **No taper, no texture, so it looks like a line, not a blade sweep.** Alpha only goes base to tip and fades by age. The head
   of the ribbon (the newest sample) has a hard edge and the tail fades linearly. There is no bright leading edge, so the eye
   cannot tell which way the swing went.
3. **Too thin for the 52 deg / 24 m camera.** It is only as wide as the weapon (a 1h sword is about 0.6 m, roughly 15-20 px at 1080p
   from 24 m). The swing plane of most clips is near vertical, and from a high camera a vertical ribbon is seen edge-on, so it shrinks to a stroke.
   Horizontal sweeps read better. Overheads and thrusts are worst: a spear thrust samples almost the same chord every frame, which makes a
   1-pixel streak.
4. **Low contrast.** Alpha **mix** blend, with a pale blue-tinted colour, over pastel ground (Aldara grass/road). There is no outline,
   while the whole art style relies on the toon outline.
5. **World-space samples on a moving body.** Attacking while moving (`legs.drive`, held basic) stretches the ribbon backwards along the path,
   so it reads as a "speed line" and not a swing.
6. **No contact point.** A plain physical basic has nothing at the target (section 1). The white flash is the only confirmation, it covers the
   whole body, and it looks the same for every weapon.
7. **Hit-stop is global and tiny.** 2 frames at `time_scale 0.05` freezes bots, projectiles and particles everywhere. It is short
   enough not to hurt, but it cannot be made heavier per weapon without the whole world stuttering.
8. **Anticipation is too subtle for chibi proportions.** A 12% contraction on a body with a huge head barely shows from above, and
   `_tame` already limits the head and torso (`conteudo.md`).

## 3. Options

All options are presentation only (`game/`, `shaders/`, optionally `tools/blender/`). Nothing goes in `core/`. The project does not
state a per-frame budget for FX draw calls or particles. Numbers below are relative to today, and should be measured with
`-- --perf` (`visible_pass`, `entity_surfaces`) before and after.

### A: Cheap. Fix the ribbon and add a contact spark (S, Godot only, about 1 day)
- **How it looks from 52 deg:** the same ribbon, but as a smooth curved crescent with a bright white leading edge that tapers to
  nothing at the tail. It is drawn additively, and the weapon colour is kept only on the outer rim. On contact there is a small spark star
  (a 1-frame white 4-point billboard plus 6-10 quads thrown *along the swing direction*) on the target.
- **Implementation:**
  - `kit_model.gd` `_process`:
    - Store 3 sub-samples per frame by Catmull-Rom over the last 4 tip/base samples. This needs no extra bone queries.
    - Write UVs (u = age 0..1, v = base..tip) and switch to a `shaders/weapon_trail.gdshader` (unshaded, add,
      `gradient` sampler, `head_width`/`tail_width`, a hard core line `smoothstep` on v).
    - Widen the base toward the hand (`base = tip*0.0`) and push the tip about 15% beyond the blade, so the ribbon reads at 24 m.
  - Store samples in the character's local space while it moves (or subtract root velocity) to remove the stretch.
  - `fx_manager.gd:330`: physical basic gets `SkillFx.hit_spark(at, dir, family)`. It is a new static function in `skill_fx.gd`
    that reuses `burst()` with a narrow `spread`.
- **Perf:** draws do not change (1 ribbon per swinging character, plus 1 particle node per hit, which is 0 today). CPU: 3x the vertices per
  ribbon (about 30-60 vertices), which is negligible. The spark only spawns for hits that involve the player or the party (reuse `_mine()`) to protect crowd scenes.
- **Limit:** a ribbon is still a ribbon, so problem 3 (vertical plane seen edge-on) remains for overheads and thrusts.

### B: Recommended. Weapon-family smear arcs + directional impact + per-family weight (M, Godot only, about 3-4 days)
- **How it looks from 52 deg:** at the impact frame a **thick crescent smear** in the toon style appears in front of the character,
  flat-ish (tilted about 25 deg toward the camera so it never goes edge-on). It is shaped by weapon family:
  - sword/mace 1h: a 110 deg crescent, mirrored for combo A/B
  - axe2h/sword2h: a 160-180 deg wide heavy crescent, thicker
  - spear: a long narrow wedge/spike along facing with a speed-line fringe
  - dagger/dual: two short fast slivers
  - staff/scepter: keeps the tinted ribbon

  It has a white core, a family-coloured mid band and a dark toon rim, so it matches the outline art. It erodes from tail to head in
  about 0.12-0.18 s. On contact there are directional sparks (or chips for axes and dust for maces) thrown along the swing tangent, a small
  impact star on the target, and a 0.1 m presentation-only push of the target view along the hit direction. Hit-stop is per family
  (dagger 1, sword 2, axe/2h 4 frames), applied **locally**: the attacker's and target's `AnimationPlayer.speed_scale` drop to 0 for
  N frames instead of changing `Engine.time_scale`.
- **Implementation:**
  - New `game/fx/weapon_arcs.gd`: a `const ARCS := {family: {angle, inner_r, outer_r, tilt, thickness, life, stop_frames, spark}}`,
    which is visual tuning. Hit-stop frames are tuning: keep the frame counts in `Balance` (the project rule) and read them here.
    Each family's arc mesh is built once as an `ArrayMesh` and cached, like `_proj_sphere`.
  - New `shaders/smear_arc.gdshader`: unshaded, add or premultiplied. It takes `progress` (erosion threshold against UV.x),
    a 1-D gradient, rim darkening on UV.y, and a noise texture for a broken edge. Every parameter is a per-instance uniform (`instance uniform`),
    so all arcs share one material.
  - Trigger: `fx_manager._on_skill_effect` CONE branch (`fx_manager.gd:329-336`) for basics and physical cones. Use the real hitbox
    `radius`/`cone_angle_deg` so the arc *is* the hit area: honest readability, which replaces today's `sector()` for physical.
  - Family from `entity.stats.weapon_type` and the clip (`EntityView._action_clip`). A/B mirroring comes from `_combo`.
  - Impact: `_on_damage` (`fx_manager.gd:145`) uses the attacker→target vector for the spark direction. The view push goes in `entity_view.gd`
    next to `_flinch`.
  - Local hit-stop: a new `Events.hit_stop` handler in `EntityView` (attacker + target `anim.speed_scale = 0` for N/60 s), and
    `fx_manager._on_hit_stop` then keeps only the shake. Note: `hit_stop` is only posted for player hits today, which is fine.
  - Ribbon: keep it for staff/scepter/magic only, and shorten it for melee to a faint 0.1 s helper (or turn it off).
- **Blender work:** none required. Optional: hand-painted gradient/noise textures (Godot `GradientTexture1D` +
  `NoiseTexture2D` are enough for the pilot).
- **Perf:** 1 MeshInstance per swing for about 0.15 s, a cached mesh and one shared shader. That is about the same as today (`sector()` +
  `decal_sector()` already build 2 `ImmediateMesh` per cone skill every time, so this is cheaper for skills). Fewer `ImmediateMesh` rebuilds per frame
  once melee ribbons are off. Sparks are limited to player and party, as in A. Local hit-stop removes the world-wide stutter in crowds.
- **Risk:** the arc can disagree with the pose if a clip swings left-to-right but the arc is drawn right-to-left. Mirror the arc by clip, and check
  each family on the bench.

### C: Ambitious. Authored smears + baked tip paths + stronger key poses (L, Blender + Godot, about 2 weeks)
- **How it looks:** like B, but the arc follows the exact clip path, plus 1-2 **smear frames** in the animation itself: the weapon mesh
  is stretched or multiplied along the swing on the impact frames (Arc System Works / Guilty Gear style), toon-shaded with outline. Anticipation is
  pushed to chibi-readable poses (a bigger wind-up of the shoulder/weapon, a short squash of the body). There is an optional 1-frame
  "impact frame" on the target (flat silhouette colour).
- **Implementation:**
  - `chibi_kit.py` `animate_v3`/`_settle_attacks`: bake the weapon-tip path per clip at 24 fps into glTF extras or a JSON next to the
    kit, so Godot builds the ribbon/arc from the baked curve and gets the same result at any framerate.
  - Add `smear_*` meshes per weapon family, parented to `hand.R`, shown only on IMPACT-1..IMPACT+1 through a visibility track.
  - Retune the anticipation values per clip, then run `anim_probe` and `combat_probe` (combat latency must stay at 0 FLAG).
  - Godot: B's shader and impact layer, plus the reader for the baked path.
- **Perf / budget risk:** the smear meshes add pieces to every kit, which collides with the `< 200 meshes per kit` check
  (`modelos.md`) and the per-slot `join_slots` merge. It means a kit rebuild for every class (`build_kits`), and new review loops for all 174 skills.
- Most of the visual gain over B is in close-up shots. From 24 m much of it is lost.

## 4. Recommendation and pilot

**Recommend B.** It answers the user's point directly: it replaces "a line" with a shape that says *where*, *which way* and *how heavy*,
sized to the real hitbox and readable from 52 deg. It is Godot-only, cheaper than or equal to today on draws, and gives a reusable table per family.
C can be added later on top of B (the baked paths would feed the same arc).

**Pilot: 1h sword (Paladin Guardião, `atk_1h_a`/`atk_1h_b`).** It is the most common melee setup (players and NPC guards), its
combo alternation exercises arc mirroring, and it currently gets nothing but the ribbon (a physical basic with no `look`).
1. `weapon_arcs.gd` with only the `sword` entry, plus `smear_arc.gdshader`, plus the spark on `_on_damage`, plus local hit-stop.
2. Bench: `--showcase=paladin --skill=pal_aegis_slam` plus a basic-attack film. The bench has no basic mode: add `--skill=basic` to
   `Showcase` (a small dev change, for the user to approve) or use the scratch driver below.
3. Film at the bench distance (9 m) **and** at the game distance (24 m), before and after, and keep the PNGs in
   `production/qa/evidence/attack-arcs/`. Score with the `docs/skills_review.md` grid (pose/time/shape/identity/feedback).
4. `-- --perf` in the full town, before and after: `visible_pass` draws and FPS must not get worse.
5. If it reads well, add the rows for axe2h, then spear, then dagger/dual, in that order.

## 5. Commands to produce the missing evidence (after `--import`)

Scratch driver (not in the repo) that queues the class basic in front of the bench:
`C:/Users/luisf/AppData/Local/Temp/claude/63157312b71971d4/4146cf1e-0704-4584-928c-e0e0ea7c1323/scratchpad/attack_audit/tool/basic_film.gd`

```
G=C:/Users/luisf/Desktop/Godot_v4.7.2-stable_win64.exe; OUT=<scratch>/attack_audit
"$G" --path . --position -4000,-4000 --audio-driver Dummy -s $OUT/tool/basic_film.gd -- --showcase=paladin      --skill=pal_aegis_slam    --out=$OUT/paladin      --basic_build=guardiao
"$G" ... --showcase=berserker    --skill=ber_overhead      --out=$OUT/berserker    --basic_build=executor
"$G" ... --showcase=ranger       --skill=ran_double_thrust --out=$OUT/ranger       --basic_build=lanceiro
"$G" ... --showcase=elementalist --skill=ele_flame_wave    --out=$OUT/elementalist --basic_build=fogo
"$G" ... --showcase=berserker    --skill=ber_earthsplitter --out=$OUT/berserker_24 --basic_build=executor --cam=24
```
Each one writes 8-frame sheets per attack, with the impact frame framed in yellow.
