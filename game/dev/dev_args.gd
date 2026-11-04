class_name DevArgs
extends RefCounted
## Argumentos de linha de comando depois de `--` (modos de revisão/medição), lidos uma vez só.
## `has("--perf")`, `value("--shot", "")` para `--shot=<x>`, `flag("--autostart")` vale para `--autostart` e `--autostart=<x>`.

static var _args: PackedStringArray = []
static var _read := false

static func all() -> PackedStringArray:
	if not _read:
		_args = OS.get_cmdline_user_args()
		_read = true
	return _args

static func any() -> bool:
	return not all().is_empty()

## O argumento exato existe (`--check`).
static func has(arg: String) -> bool:
	return arg in all()

## `--x` ou `--x=<valor>` existe.
static func flag(name: String) -> bool:
	for a in all():
		if a == name or a.begins_with(name + "="):
			return true
	return false

## Valor de `--x=<valor>` (o último, se repetido); `default` se não veio.
static func value(name: String, default: String = "") -> String:
	var out := default
	var pre := name + "="
	for a in all():
		if a.begins_with(pre):
			out = a.substr(pre.length())
	return out
