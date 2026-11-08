<!-- RagnaEx manual (pt-BR) — Estilo GDScript. Moved VERBATIM from the old CLAUDE.md on 2026-11-08 (CCGS adoption); imported by CLAUDE.md. Edit here. -->

## Estilo GDScript

- Tipagem estática; `var x := ...` só quando o tipo é inferível (valores vindos de `Array`/`Dictionary`
  untyped precisam de tipo explícito: `var d: float = e.position.distance_to(...)`).
- Lambdas de uma linha podem ter `a(); b()`, mas não `if`. Use métodos nomeados para sinais com lógica.
- `lerp`/`lerpf` em `_process`: sempre `minf(1.0, delta * k)` como peso.
- Texto do jogo em pt-BR; comentários curtos em pt-BR; nomes de código em inglês.
- Nada de `.tscn` grandes editados à mão: UI e mundo são construídos em código.
