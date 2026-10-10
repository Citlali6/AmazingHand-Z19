# Open the PS UART before powering on the Z19. Never sends serial commands.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidatePattern('^COM[0-9]+$')][string]$Port,
    [Parameter(Mandatory = $true)][string]$Log,
    [ValidateRange(1, 7200)][int]$Seconds = 600
)
$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath $Log) { throw 'Log already exists; choose a new filename.' }
$parent = Split-Path -Parent ([IO.Path]::GetFullPath($Log))
if (-not (Test-Path -LiteralPath $parent -PathType Container)) { throw 'Log directory does not exist.' }
$device = @(Get-CimInstance Win32_SerialPort | Where-Object { $_.DeviceID -eq $Port })
if ($device.Count -ne 1 -or $device[0].Name -match 'Bluetooth' -or $device[0].PNPDeviceID -match '^BTH') {
    throw 'Requested port is missing or a Bluetooth port. Connect and identify the Z19 PS UART first.'
}
$serial = [IO.Ports.SerialPort]::new($Port, 115200, [IO.Ports.Parity]::None, 8, [IO.Ports.StopBits]::One)
$serial.Handshake = [IO.Ports.Handshake]::None
$serial.DtrEnable = $false
$serial.RtsEnable = $false
$serial.ReadTimeout = 250
$serial.Encoding = [Text.Encoding]::ASCII
$writer = $null
try {
    $serial.Open()
    # CreateNew preserves previous logs even if a file appeared after the first check.
    $stream = [IO.File]::Open($Log, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
    $writer = [IO.StreamWriter]::new($stream, [Text.UTF8Encoding]::new($false))
    $writer.AutoFlush = $true
    $writer.WriteLine('# PS UART {0}, 115200 8N1, start UTC {1}' -f $Port, [DateTime]::UtcNow.ToString('o'))
    Write-Output "Recording $Port to $Log. Power on now. Read-only capture; no commands are transmitted."
    $timer = [Diagnostics.Stopwatch]::StartNew()
    while ($timer.Elapsed.TotalSeconds -lt $Seconds) {
        $chunk = $serial.ReadExisting()
        if ($chunk.Length -gt 0) { $writer.Write($chunk); [Console]::Write($chunk) }
        Start-Sleep -Milliseconds 50
    }
} finally {
    if ($null -ne $writer) { $writer.Dispose() }
    if ($serial.IsOpen) { $serial.Close() }
    $serial.Dispose()
}
