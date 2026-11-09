<!-- RagnaEx manual (pt-BR) — Visão geral, comandos e arquitetura. Moved VERBATIM from the old CLAUDE.md on 2026-11-08 (CCGS adoption); imported by CLAUDE.md. Edit here. -->

# RagnaEx — guia para o Claude Code

Protótipo de "MMO" 2.5D single-player com bots. **Godot 4.7.2 + GDScript**, sem addons.
Arte: Tree of Savior (chibi, pastel, toon 3 tons + outline) · **layout de mundo estilo Erenshor** (zonas orgânicas:
vale fechado, vila murada como hub, estradas curvas, rio com pontes, POIs com marcos — ver "Layout de zonas") ·
câmera Ragnarok (52°, yaw em 45°, a mesma perspectiva de sempre) · combate Drakantos (encara o cursor, LMB básico,
skills com mira MOBA). Leia `README.md` e `docs/DESIGN.md`.

## Comandos

```powershell
# Windows (use o wrapper; ele acha o Godot em Program Files / Downloads / $env:GODOT)
.\tools\godot.ps1 --headless --path . --import                    # (re)gera cache de classes — rode após criar scripts com class_name
.\tools\godot.ps1 --headless --path . tools/tests/tests.tscn      # testes (14000+ checks) — OBRIGATÓRIO antes de terminar uma tarefa
.\tools\godot.ps1 --headless --path . tools/tests/tests.tscn -- --only=party,shield   # só os _check_* com esses nomes (iterar rápido)
.\tools\godot.ps1 --headless --path . -- --autostart=berserker    # smoke test: joga sozinho e sai; 0 "SCRIPT ERROR" é o critério
.\tools\godot.ps1 --path .                                        # abre o jogo com janela
```
Linux/mac: troque `.\tools\godot.ps1` por `godot` (binário 4.7.2 no PATH).

Scripts novos com `class_name` só são vistos pelos outros scripts depois de `--import`.

## Arquitetura (regra de ouro)

- `core/` = **simulação**. Nunca importe/instancie `Node3D`, `Control`, câmera, shaders ou `Input` aqui.
  Tudo que acontece no jogo passa por `core/sim/world_sim.gd` (autoload `Sim`) via `InputCommand`.
  Jogador e bots são a mesma coisa para a sim (só muda quem gera o comando). Isso é o futuro servidor.
- `game/` = **apresentação**. Lê o estado da sim, nunca muda HP/posição/inventário diretamente;
  chama métodos públicos de `Sim` (`equip`, `use_potion`, `upgrade_mastery`, `try_cast`…) ou os
  sistemas estáticos (`QuestSystem`, `CraftSystem`). Reage aos sinais de `core/events.gd` (autoload `Events`).
- `data/` = conteúdo. Schemas (Resources) em `data/schemas/`, dados em `data/catalog/*_catalog.gd`
  (dicionários → Resources em `GameData._ready`). Constantes de balanceamento SÓ em `data/balance.gd`.
- Autoloads (ordem): `Events`, `Balance`, `GameData`, `Sim`, `SaveSystem`.
- `WorldSim` (`class_name`, autoload `Sim`) guarda o estado e roda o tick, spawn, comandos, pipeline de skill, dano/cura/morte,
  movimento. O resto mora em `core/sim/systems/` como funções estáticas `f(sim: WorldSim, ...)`, sem estado próprio:
  `MapGeometry` (colisão, água/pontes, `water_path`, chão andável), `PartySystem`, `LootSystem` (abate, divisão, elites, baú),
  `LegendEffects`, `ShieldSystem`, `ItemSystem` (equipar, poção, aprimorar, relíquia, depósito), `PortalSystem` (portais, portões,
  troca de mapa, recall), `ProgressionSystem` (XP, árvore, talentos, loadout, `resolve_skill`), `GatherSystem`, `NpcSystem`,
  `TrapSystem`, `MobSystem` (aggro, chefe, spawners). Regra nova vai no sistema dela; dentro da sim chame `Sistema.f(self, ...)`.
  O fim do `world_sim.gd` repassa (`Sim.equip`, `Sim.party_invite`...) o que jogo/testes/brains usam: API nova pública = um repasse lá.
- Buff/debuff por id: `SimEntity.put_buff/put_debuff/drop_buff/buff_stacks` (renova, não acumula).
  Buff novo precisa de visual no corpo: entrada em `BuffLooks.LOOKS` (`game/fx/buff_looks.gd`; há check); revisar com `-- --autostart=<c> --buff_shot=<pasta> [--only=<id>]`.
