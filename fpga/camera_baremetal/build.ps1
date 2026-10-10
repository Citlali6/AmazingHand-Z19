# Build the archived standalone CAM0 application with an existing Vitis BSP.
# Inputs are preserved; ELF/map/manifest are written only to a NEW directory.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$BspDirectory,
    [Parameter(Mandatory = $true)][string]$GccPath,
    [Parameter(Mandatory = $true)][string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
$bsp = (Resolve-Path -LiteralPath $BspDirectory).Path
$gcc = (Resolve-Path -LiteralPath $GccPath).Path
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'Output exists; choose a new directory.' }
if (-not (Test-Path -LiteralPath (Join-Path $bsp 'include/xparameters.h')) -or
    -not (Test-Path -LiteralPath (Join-Path $bsp 'lib/libxil.a'))) { throw 'Standalone A53 BSP is incomplete.' }
$main = Join-Path $PSScriptRoot 'src/main.c'
$linker = Join-Path $PSScriptRoot 'camera.ld'
New-Item -ItemType Directory -Path $output | Out-Null
$elf = Join-Path $output 'capture.elf'
$map = Join-Path $output 'capture.map'
$compilerArguments = @(
    '-O2', '-g', '-Wall', '-Wextra', '-march=armv8-a',
    ('-I' + (Join-Path $bsp 'include')), ('-I' + (Join-Path $PSScriptRoot 'src')),
    $main, ('-L' + (Join-Path $bsp 'lib')),
    ('-Wl,-T,' + $linker), ('-Wl,-Map,' + $map),
    '-Wl,--start-group,-lxil,-lgcc,-lc,--end-group', '-o', $elf
)
& $gcc @compilerArguments
if ($LASTEXITCODE -ne 0) { throw ('Standalone compilation failed: ' + $LASTEXITCODE) }
$manifest = [ordered]@{
    schema = 1
    note = 'New standalone build; not the archived JTAG ELF or Linux capture binary. Hardware validation is separate.'
    elf_sha256 = (Get-FileHash -LiteralPath $elf -Algorithm SHA256).Hash.ToLowerInvariant()
    source_sha256 = [ordered]@{
        'src/main.c' = (Get-FileHash -LiteralPath $main -Algorithm SHA256).Hash.ToLowerInvariant()
        'src/sensor_table.h' = (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'src/sensor_table.h') -Algorithm SHA256).Hash.ToLowerInvariant()
        'camera.ld' = (Get-FileHash -LiteralPath $linker -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    bsp_library_sha256 = (Get-FileHash -LiteralPath (Join-Path $bsp 'lib/libxil.a') -Algorithm SHA256).Hash.ToLowerInvariant()
}
$manifestPath = Join-Path $output 'manifest.json'
[IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 4) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
Write-Output ('STANDALONE_BUILD_COMPLETE: ' + $elf)
