# Disk identity/geometry refusal tests. Disk commands are mocked; no disk is written.
param([Parameter(Mandatory = $true)][string]$Package)
$ErrorActionPreference = 'Stop'
$script:fakeCards = @()
function Get-Disk { return $fakeCards }
function New-Partition { throw 'UNEXPECTED_MUTATION' }
function Format-Volume { throw 'UNEXPECTED_MUTATION' }
function Set-Partition { throw 'UNEXPECTED_MUTATION' }
$baseline = @{
    Number = 2; BusType = 'USB'; SerialNumber = '121220160204'; Size = [uint64]31268536320
    IsBoot = $false; IsSystem = $false; IsOffline = $false; IsReadOnly = $false
    PartitionStyle = 'MBR'; LogicalSectorSize = 512; NumberOfPartitions = 0; Signature = [uint32]1207762436
}
$cases = @(
    @{ Name = 'valid dry run'; Changes = @{}; Error = $null },
    @{ Name = 'wrong serial'; Changes = @{SerialNumber = 'other'}; Error = 'Expected exactly one' },
    @{ Name = 'wrong capacity'; Changes = @{Size = 1000}; Error = 'Expected exactly one' },
    @{ Name = 'internal disk'; Changes = @{BusType = 'NVMe'}; Error = 'Expected exactly one' },
    @{ Name = 'system disk'; Changes = @{IsSystem = $true}; Error = 'Card is not an' },
    @{ Name = 'boot disk'; Changes = @{IsBoot = $true}; Error = 'Card is not an' },
    @{ Name = 'read only'; Changes = @{IsReadOnly = $true}; Error = 'Card is not an' },
    @{ Name = 'offline'; Changes = @{IsOffline = $true}; Error = 'Card is not an' },
    @{ Name = 'wrong sector size'; Changes = @{LogicalSectorSize = 4096}; Error = 'Card is not an' },
    @{ Name = 'GPT'; Changes = @{PartitionStyle = 'GPT'}; Error = 'Card is not an' },
    @{ Name = 'existing partition'; Changes = @{NumberOfPartitions = 1}; Error = 'Card is not empty' },
    @{ Name = 'duplicate identity'; Changes = @{}; Duplicate = $true; Error = 'Expected exactly one' }
)
foreach ($case in $cases) {
    $properties = $baseline.Clone()
    foreach ($key in $case.Changes.Keys) { $properties[$key] = $case.Changes[$key] }
    $script:fakeCards = @([pscustomobject]$properties)
    if ($case.Duplicate) { $script:fakeCards += [pscustomobject]$properties }
    $caught = $null
    try { & (Join-Path $PSScriptRoot 'prepare_z19_sd.ps1') -Package $Package -WhatIf | Out-Null }
    catch { $caught = $_.Exception.Message }
    if ($case.Error) {
        if (-not $caught -or -not $caught.Contains($case.Error)) { throw "FAIL $($case.Name): $caught" }
    } elseif ($caught) { throw "FAIL $($case.Name): $caught" }
    Write-Output "PASS: $($case.Name)"
}
Write-Output '12 disk guard cases passed; no disk command executed.'
