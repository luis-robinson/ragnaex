# Adoption Plan

> **Generated**: 2026-11-09
> **Project phase**: Production (`project.stage` in `project.yaml`)
> **Engine**: Godot 4.7.2 (GDScript, Forward+)
> **Template version**: CCGS v1.2.0 (adapted, see `docs/ccgs-adoption.md`)

Work through these steps in order. Check off each item as you complete it.
Re-run `/adopt` anytime to check remaining gaps.

Audit result: no existing GDD, ADR, story or systems-index to check for format
problems (0 BLOCKING). The project's design lives in the pt-BR `docs/DESIGN.md`,
so every gap below is something that does not exist yet, not something in the
wrong format. Config (`project.yaml`) and the engine reference
(`docs/engine-reference/godot/VERSION.md`) are in place; no v1.0 migration needed.

---

## Step 1: Fix Blocking Gaps

None.

---

## Step 2: Fix High-Priority Gaps

### 2a. No GDDs in `design/gdd/`
Pipeline skills (`/create-epics`, `/create-stories`, `/review-all-gdds`,
`/consistency-check`) read GDDs from `design/gdd/`. The design exists only in
`docs/DESIGN.md`.

Fix: `/reverse-document` (works backwards from the code and `docs/DESIGN.md`).
Do it one system at a time, starting with the systems still changing: bosses,
combat, skills/web, party. The 8-section GDD standard applies only to these new
files; `docs/*.md` keep their format.
**Time**: 1 session per 2-3 systems

- [ ] `design/gdd/systems-index.md` created
- [ ] Bosses GDD
- [ ] Combat / skills GDD
- [ ] Progression (web, talents, levels) GDD
- [ ] Remaining systems (party, loot/economy, world/zones, bots)

### 2b. No ADRs in `docs/architecture/`
Key decisions are only in `CLAUDE.md` and `.claude/rules/ragnaex-architecture.md`:
sim vs presentation split, static stateless systems, data in catalogs,
`InputCommand` as the only way in.

Fix: `/architecture-decision` for each (4-6 ADRs cover it).
**Time**: 30 min each

- [ ] ADR: sim/presentation split and `InputCommand`
- [ ] ADR: stateless static systems under `WorldSim`
- [ ] ADR: content as catalogs + `balance.gd`
- [ ] ADR: save format and migrations

### 2c. No TR registry / control manifest
Needs the GDDs and ADRs above first. See Step 3.

---

## Step 3: Bootstrap Infrastructure

Do these after Step 2 has produced GDDs and ADRs.

### 3a. Register existing requirements (creates tr-registry.yaml)
Run `/architecture-review`.
**Time**: 1 session

- [ ] `docs/architecture/tr-registry.yaml` created

### 3b. Create control manifest
Run `/create-control-manifest`
**Time**: 30 min

- [ ] `docs/architecture/control-manifest.md` created

### 3c. Create sprint tracking file
Run `/sprint-plan update`
**Time**: 5 min

- [ ] `production/sprint-status.yaml` created

### 3d. Authoritative project stage
Already set: `project.stage: Production` in `project.yaml`. `/gate-check production`
would re-confirm it once the artifacts above exist (it may report them missing
until then).

- [x] `project.stage` written

---

## Step 4: Medium-Priority Gaps

- [ ] **Performance budgets** are not in `project.yaml`. The numbers exist in practice
  (sim ~5 ms/tick, 25 FPS floor in `PerfWatch`, `docs/otimizacao.md`). Add a
  `performance:` block with them. **Time**: 5 min
- [ ] **Traceability matrix** `docs/architecture/requirements-traceability.md` is
  produced by `/architecture-review`. **Time**: included in 3a

---

## Step 5: Optional Improvements

- [ ] `.claude/docs/technical-preferences.md` is still the template (all
  `[TO BE CONFIGURED]`). `project.yaml` is authoritative, so this is optional.
  Fill only Forbidden Patterns / Allowed Libraries, the two sections `project.yaml` does not hold.

---

## What to Expect from Existing Stories

There are no stories. When `/create-stories` runs on the new GDDs, they will carry
TR-IDs and manifest versions from the start.

---

## Do not run

`/test-setup`, `/test-helpers` and `/regression-suite` scaffold gdUnit4. RagnaEx
tests are `check()`s in `tools/tests/run_tests.gd`.

## Review mode

Resolves to `lean`, from `modes.rigor: standard`. To change it, edit `modes.rigor`
or pin it with `/settings --local modes.review_mode=<full|lean|solo>`.

---

## Re-run

Run `/adopt` again after Step 3 to verify the high gaps are resolved.
