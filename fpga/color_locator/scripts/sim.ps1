param(
    [string]$VivadoBin = 'D:\Vivado\Vivado\2020.1\bin',
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [string]$PythonExe = 'python'
)
$ErrorActionPreference = 'Stop'
$sourceRoot = (Split-Path -Parent $PSScriptRoot).Replace('\', '/')
if (Test-Path -LiteralPath $OutputDirectory) { throw 'Choose a new, nonexistent output directory.' }
New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
Push-Location -LiteralPath $OutputDirectory
try {
    & $PythonExe "$sourceRoot/sim/generate_hsv_vectors.py"
    if ($LASTEXITCODE -ne 0) { throw "Vector generation failed: $LASTEXITCODE" }
    & "$VivadoBin\xvlog.bat" --sv "$sourceRoot\vendor\laperex\cv_types.sv" "$sourceRoot\vendor\laperex\cv_rgb_to_hsv.sv" "$sourceRoot\rtl\vg_color_axis.sv" "$sourceRoot\rtl\vg_color_axi.sv" "$sourceRoot\sim\tb_color_axi.sv" "$sourceRoot\sim\tb_color_axis.sv" "$sourceRoot/sim/tb_hsv_reference.sv"
    if ($LASTEXITCODE -ne 0) { throw "xvlog failed: $LASTEXITCODE" }
    & "$VivadoBin\xelab.bat" tb_hsv --timescale 1ns/1ps -s hsv_reference
    if ($LASTEXITCODE -ne 0) { throw "reference xelab failed: $LASTEXITCODE" }
    & "$VivadoBin\xsim.bat" hsv_reference -tclbatch "$sourceRoot/sim/run.tcl" -log hsv_reference.log
    if ($LASTEXITCODE -ne 0) { throw "reference xsim failed: $LASTEXITCODE" }
    $referenceLog = Get-Content -LiteralPath hsv_reference.log -Raw
    if ($referenceLog -notmatch 'HSV_PASS' -or $referenceLog -match '(?m)^(Fatal:|ERROR:)') { throw 'HSV reference did not pass.' }
    & "$VivadoBin\xelab.bat" tb_color_axis --timescale 1ns/1ps -s color_axis
    if ($LASTEXITCODE -ne 0) { throw "xelab failed: $LASTEXITCODE" }
    & "$VivadoBin\xsim.bat" color_axis -tclbatch "$sourceRoot/sim/run.tcl" -log simulation.log
    if ($LASTEXITCODE -ne 0) { throw "xsim failed: $LASTEXITCODE" }
    $log = Get-Content -LiteralPath simulation.log -Raw
    if ($log -notmatch 'COLOR_AXIS_PASS' -or $log -match '(?m)^(Fatal:|ERROR:)') { throw 'Simulation did not pass.' }
    & "$VivadoBin\xelab.bat" tb_color_axi --timescale 1ns/1ps -s color_axi
    if ($LASTEXITCODE -ne 0) { throw "AXI xelab failed: $LASTEXITCODE" }
    & "$VivadoBin\xsim.bat" color_axi -tclbatch "$sourceRoot/sim/run.tcl" -log color_axi.log
    if ($LASTEXITCODE -ne 0) { throw "AXI xsim failed: $LASTEXITCODE" }
    $axiLog = Get-Content -LiteralPath color_axi.log -Raw
    if ($axiLog -notmatch 'COLOR_AXI_PASS' -or $axiLog -match '(?m)^(Fatal:|ERROR:)') { throw 'AXI simulation did not pass.' }
} finally { Pop-Location }
