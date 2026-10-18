param(
    [Parameter(Mandatory=$true)][string]$VivadoBin,
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path.Replace('\','/')
$destination = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $destination) { throw "Choose a new simulation directory: $destination" }
New-Item -ItemType Directory -Path $destination | Out-Null
$sources = @('fpga/rtl/scs_protocol.sv','fpga/rtl/servo_bus_ctrl.sv','fpga/rtl/grasp_fsm.sv',
 'fpga/sim/scs_slave_model.sv','fpga/sim/tb_scs_protocol.sv','fpga/sim/tb_servo_bus.sv','fpga/sim/tb_grasp_fsm.sv',
 'fpga/hand_control/rtl/hand_hil_axi.sv','fpga/hand_control/sim/tb_hand_hil_axi.sv') | ForEach-Object { "$root/$_" }
Push-Location $destination
try {
    & (Join-Path $VivadoBin 'xvlog.bat') --sv @sources
    if ($LASTEXITCODE -ne 0) { throw 'xvlog failed' }
    foreach ($name in @('tb_scs_protocol','tb_servo_bus','tb_grasp_fsm','tb_hand_hil_axi')) {
        & (Join-Path $VivadoBin 'xelab.bat') $name -s $name --timescale 1ns/1ps
        if ($LASTEXITCODE -ne 0) { throw "xelab failed: $name" }
        $simOutput = & (Join-Path $VivadoBin 'xsim.bat') $name -tclbatch "$root/fpga/hand_control/sim/run.tcl" 2>&1
        $simOutput | Write-Output
        $simOutput | Set-Content -LiteralPath "$name.txt"
        $text = $simOutput -join "`n"
        if ($LASTEXITCODE -ne 0 -or $text -match '(?im)^\s*(Fatal:|Error:|ERROR:)' -or $text -notmatch '(ALL PASS|PASS HIL AXI)') {
            throw "XSim validation failed: $name"
        }
    }
} finally { Pop-Location }
