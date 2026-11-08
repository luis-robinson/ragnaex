---
paths:
  - "game/ui/**"
---

# UI Code Rules

- UI must NEVER own or directly modify game state — display only, use commands/events to request changes
- All UI text must go through the localization system — no hardcoded user-facing strings
- Support both keyboard/mouse AND gamepad input for all interactive elements
- All animations must be skippable and respect user motion/accessibility preferences
- UI sounds trigger through the audio event system, not directly
- UI must never block the game thread
- Scalable text and colorblind modes are mandatory, not optional
- Test all screens at minimum and maximum supported resolutions

## RagnaEx adaptation

> Added when CCGS was adopted (docs/ccgs-adoption.md). Where a line below
> conflicts with a rule above, **this section wins** for RagnaEx. The project's
> golden rules are in `.claude/rules/ragnaex-architecture.md`.

- Player-facing text is written in **pt-BR directly in code**. There is no
  localization system (the CCGS `localize` skill was not adopted), so the
  "through the localization system" line is suspended; keep strings short and
  free of concatenated grammar so they can be extracted later.
- Input is keyboard + mouse. Gamepad, scalable text and colorblind modes are
  goals, not blockers, until the user schedules them.
- UI is built in code (no large hand-edited `.tscn`). UI reads sim state and
  calls public `Sim.*` methods or static systems (`QuestSystem`, `CraftSystem`);
  it never changes HP/position/inventory directly.
- Review with the documented screenshot flags (`--bag_shot`, `--screenshot`,
  `--wins=...`) listed in `.claude/docs/ragnaex/conteudo.md`.
