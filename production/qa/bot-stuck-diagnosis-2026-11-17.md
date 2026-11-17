# Bot stuck diagnosis — 2026-11-17

Diagnosis only: no game code was changed. Worktree `wt/post-int2`.

## Probe

`tools/tests/stuck_probe.gd` / `.tscn` (new). It builds the same world as `main._populate_bots`: all maps, 66 bots, and a player
standing in Aldara, so maps without the player tick at `Sim.away_every`. It samples every bot every 0.5 s.

- **PRESO (stuck)**: over a 10 s window the bot is alive and not busy (not casting, stunned, dashing, blocking, gathering,
  recalling or mounting). The brain asks it to move in at least 80% of samples, it attacks or casts in at most 20%, and its
  body never leaves a 1.5 m disc. Back-and-forth movement inside the disc counts as stuck.
- **PARADO (frozen)**: outside town, not in combat, no move or action command, and in the same 1 m spot for 30 s.
- Each episode records map, x/z, brain state, dest_map, target_pos, aim, portal, water_path size, detour_tries, party role and
  leader distance, nearest hostile (distance, aggro, whether the line is blocked and by which collider, whether it crosses
  water), colliders within 3 m (classed as obstacle kind or water), nearest portal, distance to the town wall, and how the
  episode ended.

Re-measure (one Godot process at a time, about 13-16 min real per 30 sim-min):
```
"C:/Users/luisf/Desktop/Godot_v4.7.2-stable_win64.exe" --headless --path . tools/tests/stuck_probe.tscn -- --minutes=30 --seed=4242 --out=production/qa/evidence/bot-stuck/after_s4242.json </dev/null > after_s4242.log 2>&1
# repeat with --seed=777 and --seed=1234, then:
python tools/tests/stuck_cluster.py production/qa/evidence/bot-stuck/after_s*.json
```
Helper: `tools/tests/stuck_path_probe.tscn -- --map=<id> --from=x,z --to=x,z` prints the bridges, `crosses_river`, the
`water_path`, and a step-by-step walk using `resolve_obstacles` up to the first node. It reproduces a wedge without bots.

Baseline evidence: `production/qa/evidence/bot-stuck/stuck_s{4242,777,1234}.{json,log}` and `cluster_baseline.txt`.
All 3 runs had 0 SCRIPT ERROR.
Caveat: another agent had temporary edits in `gear_catalog.gd`/`items_catalog.gd` during the runs. They affect items, not movement.

## Result (3 seeds x 30 sim-min)

| | value |
|---|---|
| Stuck rate (bot-s stuck / bot-s alive) | **9.0%** (32 005 / 355 610). By seed: 9.8%, 9.2%, 8.0% |
| Stuck episodes | 666 (+62 frozen) |
| Duration | p50 19 s, p90 151 s, max 435 s; 138 episodes >= 60 s |
| How they end | 657 walk out on their own (detour, timer, or the target leaves), 2 die, 7 still stuck at the end |
| Brain state | HUNT 82%, HUNT as party follower 5%, HUNT in combat 3%, TRAVEL 9% |

So bots almost never stay stuck forever. They lose minutes at a time: the hunt timer (150-360 s) or the travel leg timer
(60 s) finally moves them on.

### By cause

| Cause | eps | bot-s | share |
|---|---|---|---|
| Town gate ping-pong (Aldara) | 159 | 12 855 | 40% |
| Chasing or roaming into a wall, fence, cliff or rock between bot and target | ~370 | ~14 800 | 46% |
| Aldara river tip / lake slot | ~93 | ~3 200 | 10% |
| Other water (field_ruins bridge bank) | ~30 | ~550 | 2% |
| Frozen followers (secondary: leader is stuck) | 62 | 1 891 | n/a |

### Hotspots (top 12, all seeds)

| # | map | x, z | eps | bot-s | bots | cause |
|---|---|---|---|---|---|---|
| 1 | city_aldara | -2.7, -29.9 (S gate) | 24 | 2416 | 17 | gate ping-pong (TRAVEL to field_ruins portal, HUNT) |
| 2 | city_aldara | -8.4, 83.4 | 66 | 2301 | 30 | river tip / lake wedge |
| 3 | city_aldara | -2.0, 29.9 (N gate) | 16 | 1632 | 15 | gate ping-pong |
| 4 | city_aldara | 1.0, -29.9 (S gate) | 12 | 1614 | 11 | gate ping-pong |
| 5 | fort_bones | -29.3, -35.5 | 12 | 1368 | 9 | chasing skel_archer through the fort wall ring |
| 6 | city_aldara | 30.0, 0.6 (E gate) | 7 | 998 | 7 | gate ping-pong |
| 7 | city_aldara | -7.8, 81.8 | 33 | 977 | 15 | river tip / lake wedge |
| 8 | fort_trolls | -5.5, -18.2 | 14 | 931 | 9 | chasing troll_whelp through the wall ring |
| 9 | city_aldara | -30.1, -1.8 (W gate) | 9 | 867 | 7 | gate ping-pong |
| 10 | fort_war | -2.3, -26.9 | 9 | 687 | 6 | wall ring (chase plus frozen followers) |
| 11 | fort_ghoul | -29.2, 29.8 / -3.3, -13.0 | 8 | 1045 | 5 | wall ring |
| 12 | elf_city | 52.4, 42.5 / -13.0, -62.6 | 11 | 836 | 9 | chasing elf_archer or elf_lynx through the city wall |

By map (bot-s): city_aldara 12 021, elf_city 3 089, field_steppe 2 878 (orc camp walls, cliffs at 60,74), fort_bones 2 598,
fort_trolls 2 465, fort_ghoul 2 447, lich_citadel 2 370, fort_fire 1 058, fort_war 848, field_ruins 698, field_forest 694,
field_kharzun 616.

## Root causes (ranked) and proposed fixes

### R1. Gate ping-pong in `BotBrain._route` (40%)
`core/sim/ai/bot_brain.gd` `_route` (lines ~1268-1290). The inside/outside test is `in_town()`, a circle at `town_radius` = 30.
That is the wall line, where the gate gaps are. Failure loop:
- The bot is outside and the target is outside, so `_route` returns the target and the bot walks a straight line.
- When the target is beyond the town, that line goes back in through the gate the bot is standing in.
- Once inside, the gate cost `dist(e,g) + dist(g,p)` ties or nearly ties, so it picks the same gate again. Examples:
  - West gate to the east portal: 152.6 vs 156.
  - South gate to a target NNE: 137.5 vs 137.6.
- The bot heads to that gate's `outer` point, crosses r=30 after about 0.1 m, and is outside again.

The result is that it oscillates in the gateway (it hits the pillars, r=2 at ±5 m) until the 60 s leg timer or the hunt timer runs out.

**Fix:**
- When the bot is outside but the segment to `p` crosses the disc `town_radius + 2`, route around the wall: take a waypoint
  on the ring `r + 6`, stepping about 30° per waypoint from the bot's angle toward the target's angle.
- Inside, add hysteresis: once a gate is chosen, keep `outer` as the waypoint until `from_c > r + 3.5`, and store the chosen gate.
- Choose the exit gate by `dist(g, p)` (the gate facing the target) rather than by cost from where the bot stands.

Check to add: a bot at each Aldara gate with a target on the far side gets more than 8 m from the gate within 6 s.

### R2. Chasing or roaming through walls with no reachability (46%)
Three parts that add up:
1. `_pick_monster` (line ~1100) picks any monster within 18 m with no line-of-walk test. `_sticky` (16 m) keeps it. In 276 of
   279 chase episodes the monster had not aggroed the bot: it is an idle archer or whelp on the other side of a fort wall,
   cliff or camp fence, and it never comes out.
2. The approach in `_fight_core` (line ~533, `cmd.move = _steer(e, spot, 0.0)`) and the other combat `_steer` calls pass
   `dt = 0`. That turns off the stuck timer and the detour in `_steer`, so the bot pushes straight into the wall. `stall_t`
   only runs when the bot is already in range.
3. `_route` never runs outside `is_town` maps, because `MapDef.in_town()` returns false when `is_town` is false. The forts
   (r 28, 1 gate), elf_city (r 66, 6 gates), lich_citadel (r 28) and the hubs (field_forest, field_steppe, field_kharzun,
   field_ruins, 4 gates each) all have `town_radius` and `town_gates` in their JSON, but bots ignore those gates. Roaming
   targets (`random_walkable` near a spawner inside a fort) hit the same wall.

**Fix:**
- (a) In `_pick_monster`, skip a non-aggroed monster when the straight line is blocked. Use a cheap sampled
  `MapGeometry.is_walkable` every 1 m, or a segment-vs-collider test on the grid cells.
- (b) Add an approach-progress timer: if the distance to the target has not dropped by 1 m in 4 s, drop the target and
  blacklist its id for about 20 s. Same for `target_pos` in HUNT: pick a new spawner point.
- (c) Pass the real dt to `_steer` in combat. Keep the think dt in a member so `_fight` callers don't need it.
- (d) Make `_route` use a geometric inside test (`town_radius > 0` and gates present) instead of `in_town()`, so walled forts
  and hubs route through their gate(s). Do it together with R1, because the forts have only one gate.

A general grid A* would also cover the remaining cases: the steppe orc-camp walls (58,-20 and 53,-47), the cliffs at
(60,74), and the citadel ruins. That is an architecture decision for the user.

### R3. Aldara river tip and lake slot (10%)
`data/zones/city_aldara.json`: the river polyline ends at (-8.83, 81.64), 1.57 m short of the lake collider (lake (6.66, 88.82),
collider r 15.5). `MapGeometry.crosses_river` only tests intersection with the river polyline, so a line through that slot
counts as clear and `water_path` is empty. The colliders block it, though: the river boxes extend 0.35 m past the end and are
3 m half-wide. Reproduced with `stuck_path_probe -- --map=city_aldara --from=-3,77 --to=-20,95`: the walk wedges at
(-8.18, 82.98) after 109 steps.

**Fix:** either change the data or change the geometry:
- Data: extend the last river point inside the lake in `tools/blender/zones/build_<aldara>.py` and re-export. The JSON is
  generated, so do not edit it by hand.
- Geometry: in `crosses_river`, treat a river endpoint within `w/2 + shore` of a lake edge as connected (extend the last
  segment into the lake). `build_collider_grid` should then close the slot so physics and planning agree.

Also audit every zone for river ends near a lake or the map edge. A cheap check would assert that `crosses_river` and a
stepped `resolve_obstacles` walk agree on sample lines.

### R4. Followers frozen behind a stuck leader (secondary)
`_follow` (line ~1375): followers keep formation 2-4 m behind a leader who is stuck, so they also show up as frozen (62 eps,
1 891 s). Fixing R1 and R2 fixes this.

### R5. Not measured, found by reading: follower vs. player-only door
In `_follow`, when the leader (the player) goes into an interior, `PortalSystem.portal_towards(def, leader.map_id)` returns
the house door. `check_portals` refuses non-players (`player_only`), so bot followers stand on the door until the player
comes out. The soak does not cover this because the player is never in a party. **Fix:** in `_follow`, when the leader's map
is an interior or the door is `player_only`, wait near the door (hold formation at the door) and skip the portal. Also make
`portal_towards` skip `player_only` portals for bots.

### Minor
- field_ruins (-82, -5), on the east bank 8 m north of the only bridge (-83.9, -13.3): 541 s. In the helper probe a straight
  walk to the bridge end works, so the cause was not isolated. It may be detour sides pushing into the river.
- `_water_step` with dt=0 (combat) never ticks `water_timer`, so the path is only recomputed when the goal moves more than
  3 m. That is harmless today but becomes stale after a detour.

## Suggested order
1. R1 (gate routing with hysteresis and ring-around).
2. R2c and R2b (real dt plus the progress timer). These are small and drop most chase time.
3. R2a and R2d.
4. R3 data fix.
5. R5.

After each step, re-run the 3 seeds. Target: stuck rate below 2% and no hotspot above 300 bot-s.
Also check `sim_probe` ms/tick: (a) adds line tests per pick, which must be cheap (only at pick time, not per tick).
