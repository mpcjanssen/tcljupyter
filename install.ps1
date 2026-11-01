param(
    [string]$KernelDir = (Join-Path $env:APPDATA 'jupyter\kernels\tcljupyter'),
    [string]$Tclsh = 'tclsh'
)
$ErrorActionPreference = 'Stop'

if (Test-Path $KernelDir) {
    Write-Error "$KernelDir already exists. Remove it first."
    exit 1
}

New-Item -ItemType Directory -Force $KernelDir | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'logo-svg.svg') $KernelDir -Force

$spec = @{
    argv           = @($Tclsh, (Join-Path $PSScriptRoot 'init.tcl'), '{connection_file}')
    display_name   = 'Tcl'
    language       = 'tcl'
    interrupt_mode = 'message'
} | ConvertTo-Json -Compress
[IO.File]::WriteAllText((Join-Path $KernelDir 'kernel.json'), $spec)
Write-Host "Installed tcljupyter kernel to $KernelDir"
