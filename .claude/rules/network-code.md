---
paths:
  - "core/sim/**"
---

# Network Code Rules

- Server is AUTHORITATIVE for all gameplay-critical state — never trust the client
- All network messages must be versioned for forward/backward compatibility
- Client predicts locally, reconciles with server — implement rollback for mispredictions
- Handle disconnection, reconnection, and host migration gracefully
- Rate-limit all network logging to prevent log flooding
- All networked values must specify replication strategy: reliable/unreliable, frequency, interpolation
- Bandwidth budget: define and track per-message-type bandwidth usage
- Security: validate all incoming packet sizes and field ranges

## RagnaEx adaptation

> Added when CCGS was adopted (docs/ccgs-adoption.md). Where a line below
> conflicts with a rule above, **this section wins** for RagnaEx. The project's
> golden rules are in `.claude/rules/ragnaex-architecture.md`.

- There is no netcode yet. `core/sim/` **is the future authoritative server**:
  everything that happens goes through `WorldSim` via `InputCommand`, and the
  player and bots are the same thing to the sim (only the command source
  differs). Keep it that way — that is what "server is authoritative" means
  today.
- Keep the sim deterministic for a given command stream (no presentation
  timing, no `Input`, no randomness outside the sim's own RNG).
- Message versioning, prediction/rollback, bandwidth and replication rules apply
  once a network layer is scheduled; until then they are design constraints,
  not checks.
- Saves are the current "wire format": version changes need a migration
  (`save_version`, `grandfather_gates`, `GameData.resolve_item`).
