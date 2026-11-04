# Wrapper: acha o executável do Godot 4.7 no Windows e repassa os argumentos.
# Uso: .\tools\godot.ps1 --headless --path . tools/tests/tests.tscn
# Defina $env:GODOT com o caminho completo do .exe se o auto-detect falhar.
$ErrorActionPreference = "Stop"
$candidates = @()
if ($env:GODOT) { $candidates += $env:GODOT }
$candidates += Get-Command godot -ErrorAction SilentlyContinue | ForEach-Object { $_.Source }
$roots = @("$env:ProgramFiles\Godot", "$env:LOCALAPPDATA\Programs\Godot", "$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop", "C:\Godot", "D:\Godot", "$env:LOCALAPPDATA\Microsoft\WinGet\Packages")
foreach ($r in $roots) {
    if (Test-Path $r) {
        $candidates += Get-ChildItem -Path $r -Recurse -Depth 3 -Filter "Godot_v4*win64.exe" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch "console" } | Sort-Object Name -Descending | ForEach-Object { $_.FullName }
    }
}
$exe = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $exe) {
    Write-Error "Godot 4.7 não encontrado. Baixe em https://godotengine.org/download e defina `$env:GODOT = 'C:\caminho\Godot_v4.7.2-stable_win64.exe'"
    exit 1
}
# o .exe "console" mostra a saída no terminal (necessário para ler erros/testes)
$console = $exe -replace "win64\.exe$", "win64_console.exe"
if (Test-Path $console) { $exe = $console }
& $exe @args
exit $LASTEXITCODE
