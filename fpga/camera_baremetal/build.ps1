param(
 [Parameter(Mandatory=$true)][string]$BspDir,
 [string]$VitisRoot = 'F:/Xilinx/Vitis/2020.1',
 [string]$OutputDir = (Join-Path $PSScriptRoot ('build/'+(Get-Date -Format 'yyyyMMdd-HHmmss')))
)
$ErrorActionPreference='Stop'
if (Test-Path -LiteralPath $OutputDir) { throw 'Output exists; choose a new build directory' }
$gcc=Join-Path $VitisRoot 'gnu/aarch64/nt/aarch64-none/bin/aarch64-none-elf-gcc.exe'
$nm=Join-Path $VitisRoot 'gnu/aarch64/nt/aarch64-none/bin/aarch64-none-elf-nm.exe'
foreach($path in @($gcc,$nm,(Join-Path $BspDir 'include/xparameters.h'),(Join-Path $BspDir 'lib/libxil.a'))) {
 if (!(Test-Path -LiteralPath $path)) {throw "Required file missing: $path"}
}
New-Item -ItemType Directory -Path $OutputDir | Out-Null
$OutputDir=(Resolve-Path -LiteralPath $OutputDir).Path
$elf=Join-Path $OutputDir 'capture.elf'
& $gcc '-O2' '-g' '-Wall' '-Wextra' '-march=armv8-a' ('-I'+$BspDir+'/include') ('-I'+$PSScriptRoot+'/src') ($PSScriptRoot+'/src/main.c') ('-L'+$BspDir+'/lib') ('-Wl,-T,'+$PSScriptRoot+'/camera.ld') ('-Wl,-Map,'+$OutputDir+'/capture.map') '-Wl,--start-group,-lxil,-lgcc,-lc,--end-group' '-o' $elf
if($LASTEXITCODE -ne 0){throw 'Camera build failed'}
$required=@('preview_request','preview_sequence','preview_status','preview_rgb','board_frames','focus_request','focus_applied','focus_result','debug_info')
$symbols=@{}
& $nm $elf | ForEach-Object {
 if($_ -match '^([0-9a-fA-F]+)\s+\w\s+(\w+)$' -and $required -contains $Matches[2]) {$symbols[$Matches[2]]='0x'+$Matches[1]}
}
if($LASTEXITCODE -ne 0 -or $symbols.Count -ne $required.Count){throw 'Required ELF symbols missing'}
$required | ForEach-Object {'set addr('+$_+') '+$symbols[$_]} | Set-Content -LiteralPath (Join-Path $OutputDir 'symbols.tcl') -Encoding ascii
@{elf_sha256=(Get-FileHash -LiteralPath $elf -Algorithm SHA256).Hash.ToLower();symbols=$symbols;capture_resolution=@(1920,1080);preview_resolution=@(320,180)} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $OutputDir 'manifest.json') -Encoding utf8
Write-Output "CAMERA_BUILD_OK $OutputDir"
