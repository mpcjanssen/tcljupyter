$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$dir = Join-Path $env:TEMP ("tcljupyter-" + [guid]::NewGuid())
$kernel = Join-Path $dir 'kernels\tcljupyter'
New-Item -ItemType Directory -Force $kernel | Out-Null

$spec = @{
    argv           = @('tclsh', (Join-Path $root 'init.tcl'), '{connection_file}')
    display_name   = 'Tcl'
    language       = 'tcl'
    interrupt_mode = 'message'
} | ConvertTo-Json -Compress
[IO.File]::WriteAllText((Join-Path $kernel 'kernel.json'), $spec)

$env:JUPYTER_PATH = $dir
Push-Location $root
try {
    uv run python -m tests.test_tcljupyter
    $rc = $LASTEXITCODE
} finally {
    Pop-Location
    Remove-Item -Recurse -Force $dir
}
exit $rc
