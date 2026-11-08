---
paths:
  - "data/catalog/quests_catalog.gd"
  - "data/catalog/bots_catalog.gd"
---

# Narrative Rules

- All new lore must be cross-referenced against existing lore for contradictions
- Every lore entry must specify canon level: Established / Provisional / Under Review
- Character dialogue must match the voice profile defined for that character
- World rules (what is possible/impossible) must be explicitly documented and consistent
- Mysteries must have documented "true answers" even if players never learn them
- Faction motivations, relationships, and power structures must be internally logical
- All narrative text must be localization-ready: no idioms that don't translate, named placeholders for variables
- No line of dialogue should exceed 120 characters for dialogue box constraints

## RagnaEx adaptation

> Added when CCGS was adopted (docs/ccgs-adoption.md). Where a line below
> conflicts with a rule above, **this section wins** for RagnaEx. The project's
> golden rules are in `.claude/rules/ragnaex-architecture.md`.

- In RagnaEx narrative content lives in data: quests and NPC lines in
  `data/catalog/quests_catalog.gd`, bot chat in `data/catalog/bots_catalog.gd`
  (plus NPC/place text in `maps_catalog.gd`). All text is **pt-BR**.
- The "localization-ready" line is relaxed (no localization system yet): avoid
  string-building that breaks pt-BR grammar, use named placeholders.
- Canon references: `docs/DESIGN.md` and the per-band walkthroughs
  `docs/roteiro_*.md`. "Canon level" tags are not used in catalog entries.
- Quest XP is a weight scaled by `QuestsCatalog.scale_xp`; givers/turn-in NPCs
  must exist in a `MapDef.npcs` (checked by tests).
