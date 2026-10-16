# Clear the SD card explicitly authorized on 2026-10-10.
# This removes both old partitions; it does not securely erase every data sector.
# The script does not install Linux or create filesystems.
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param()

$ErrorActionPreference = 'Stop'
$expectedSerial = '121220160204'
$expectedBytes = [uint64]31268536320

function Find-AuthorizedCard {
    $cards = @(Get-Disk | Where-Object {
        $_.BusType -eq 'USB' -and
        ([string]$_.SerialNumber).Trim() -eq $expectedSerial -and
        $_.Size -eq $expectedBytes
    })
    if ($cards.Count -ne 1) {
        throw 'Expected exactly one authorized USB SD card. No disk was changed.'
    }
    $card = $cards[0]
    if ($card.IsBoot -or $card.IsSystem -or $card.IsOffline -or $card.IsReadOnly) {
        throw 'Target is a boot/system/offline/read-only disk. No disk was changed.'
    }
    return $card
}

$card = Find-AuthorizedCard
$description = 'Disk {0}, USB, serial {1}, {2} bytes' -f $card.Number, $expectedSerial, $expectedBytes
Write-Output $description

if (-not $PSCmdlet.ShouldProcess($description, 'Remove all partitions and initialize an empty MBR partition table')) {
    return
}

# Clearing some removable cards leaves an empty MBR instead of reporting RAW.
# Treat this verified end state as complete; rerunning must not clear it again.
if ($card.PartitionStyle -eq 'MBR' -and $card.NumberOfPartitions -eq 0) {
    Write-Output 'SD_CLEAR_COMPLETE: the authorized card already has an empty MBR partition table.'
    Write-Output 'Linux partitioning and image deployment have not been performed.'
    return
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Administrator PowerShell is required. No disk was changed.'
}

# Reidentify by serial/size immediately before clearing; do not rely on disk 2.
$card = Find-AuthorizedCard
if ($card.PartitionStyle -ne 'RAW') {
    Clear-Disk -InputObject $card -RemoveData -RemoveOEM -Confirm:$false
    Update-Disk -InputObject $card
}
$card = Find-AuthorizedCard
if ($card.PartitionStyle -eq 'RAW') {
    Initialize-Disk -InputObject $card -PartitionStyle MBR | Out-Null
    Update-Disk -InputObject $card
} elseif ($card.PartitionStyle -ne 'MBR' -or $card.NumberOfPartitions -ne 0) {
    throw 'Disk is neither RAW nor an empty MBR after clearing. Stop and inspect before continuing.'
}
$card = Find-AuthorizedCard
if ($card.PartitionStyle -ne 'MBR' -or $card.NumberOfPartitions -ne 0) {
    throw 'Empty MBR verification failed. Do not proceed with image writing.'
}
Write-Output 'SD_CLEAR_COMPLETE: the authorized card has an empty MBR partition table.'
Write-Output 'Linux partitioning and image deployment have not been performed.'
