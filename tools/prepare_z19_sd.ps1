# Prepare only the explicitly authorized, already-cleared card. Never clears disks.
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param([Parameter(Mandatory = $true)][string]$Package)

$ErrorActionPreference = 'Stop'
$expectedSerial = '121220160204'
$expectedBytes = [uint64]31268536320
$bootBytes = [uint64]1073741824

function Find-Card {
    $matches = @(Get-Disk | Where-Object {
        $_.BusType -eq 'USB' -and ([string]$_.SerialNumber).Trim() -eq $expectedSerial -and $_.Size -eq $expectedBytes
    })
    if ($matches.Count -ne 1) { throw 'Expected exactly one authorized SD card.' }
    $card = $matches[0]
    if ($card.IsBoot -or $card.IsSystem -or $card.IsOffline -or $card.IsReadOnly -or
        $card.PartitionStyle -ne 'MBR' -or $card.LogicalSectorSize -ne 512) {
        throw 'Card is not an online, writable, nonsystem MBR disk with 512-byte sectors.'
    }
    return $card
}

$packagePath = (Resolve-Path -LiteralPath $Package).Path
$manifestPath = Join-Path $packagePath 'manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.schema -ne 1 -or $manifest.sd_serial -ne $expectedSerial -or $manifest.sd_bytes -ne $expectedBytes) {
    throw 'Package does not describe the authorized SD card.'
}
$fileNames = @('BOOT.BIN', 'rootfs.tar.gz', 'image-normal.ub', 'image-recovery.ub', 'recovery.cpio.gz', 'boot.cmd', 'boot.scr', 'probe_z19_linux.sh')
if (@($manifest.files.PSObject.Properties).Count -ne $fileNames.Count) { throw 'Unexpected package file set.' }
$totalBytes = [uint64]0
foreach ($name in $fileNames) {
    $entry = $manifest.files.$name
    if ($null -eq $entry) { throw "Missing manifest entry: $name" }
    $source = Join-Path $packagePath $name
    $item = Get-Item -LiteralPath $source
    if ($item.PSIsContainer -or $item.Length -ne $entry.bytes -or
        (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.sha256) {
        throw "Package checksum/size verification failed: $name"
    }
    $totalBytes += $item.Length
}
if ($totalBytes -gt 900MB) { throw 'Package exceeds the FAT boot partition budget.' }
$card = Find-Card
if ($card.NumberOfPartitions -ne 0) { throw 'Card is not empty. No partition will be deleted or overwritten.' }
$description = 'Disk {0}, USB serial {1}, {2} bytes, MBR signature {3:x8}' -f $card.Number, $expectedSerial, $expectedBytes, $card.Signature
Write-Output $description
Write-Output "Verified payload: $totalBytes bytes. Plan: 1 GiB FAT32 at 1 MiB; remaining partition type 0x83, unformatted."
if (-not $PSCmdlet.ShouldProcess($description, 'Create two partitions, format FAT32, copy and read-back verified recovery payload')) { return }
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Administrator PowerShell is required. No disk was changed.'
}
$card = Find-Card
if ($card.NumberOfPartitions -ne 0) { throw 'Card state changed before partition creation.' }
$boot = New-Partition -DiskNumber $card.Number -Offset 1MB -Size $bootBytes -MbrType FAT32 -AssignDriveLetter
Format-Volume -Partition $boot -FileSystem FAT32 -NewFileSystemLabel 'AH_BOOT' -Confirm:$false | Out-Null
$card = Find-Card
if ($card.NumberOfPartitions -ne 1) { throw 'Unexpected partition state after FAT formatting. Stop.' }
$root = New-Partition -DiskNumber $card.Number -UseMaximumSize -MbrType IFS
# Set-Partition accepts UInt16 MBR types, including Linux 0x83.
Set-Partition -DiskNumber $card.Number -PartitionNumber $root.PartitionNumber -MbrType 0x83
$card = Find-Card
$partitions = @(Get-Partition -DiskNumber $card.Number | Sort-Object PartitionNumber)
if ($partitions.Count -ne 2 -or $partitions[0].PartitionNumber -ne 1 -or $partitions[1].PartitionNumber -ne 2 -or
    $partitions[0].Offset -ne 1MB -or $partitions[0].Size -ne $bootBytes -or
    $partitions[1].Offset -ne (1MB + $bootBytes) -or $partitions[1].MbrType -ne 0x83 -or
    $partitions[1].Size -lt 25GB) { throw 'Partition geometry differs from the reviewed layout. Stop.' }
$volume = $partitions[0] | Get-Volume
if ($volume.FileSystem -ne 'FAT32' -or $volume.FileSystemLabel -ne 'AH_BOOT' -or -not $volume.DriveLetter) {
    throw 'Boot volume verification failed.'
}
$destination = '{0}:\' -f $volume.DriveLetter
foreach ($name in ($fileNames + @('manifest.json', 'deployment.env'))) {
    if (Test-Path -LiteralPath (Join-Path $destination $name)) { throw "Destination already contains $name; no overwrite allowed." }
}
foreach ($name in $fileNames) {
    Copy-Item -LiteralPath (Join-Path $packagePath $name) -Destination (Join-Path $destination $name)
    if ((Get-FileHash -LiteralPath (Join-Path $destination $name) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $manifest.files.$name.sha256) {
        throw "SD read-back checksum failed: $name"
    }
}
Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $destination 'manifest.json')
$signature = '{0:x8}' -f [uint32]$card.Signature
$lines = @(
    "ah_boot_partuuid=$signature-01", "ah_root_partuuid=$signature-02",
    ('ah_disk_sectors={0}' -f ($card.Size / 512)),
    ('ah_root_start={0}' -f ($partitions[1].Offset / 512)),
    ('ah_root_sectors={0}' -f ($partitions[1].Size / 512)),
    ('ah_rootfs_sha256={0}' -f $manifest.files.'rootfs.tar.gz'.sha256)
)
[IO.File]::WriteAllText((Join-Path $destination 'deployment.env'), (($lines -join "`n") + "`n"), [Text.Encoding]::ASCII)
Get-Content -LiteralPath (Join-Path $destination 'deployment.env')
Write-Output "SD_PAYLOAD_READY: $destination. Root is still unformatted; Linux has NOT been installed or boot-validated."
Write-Output 'Safely eject the SD card before moving it to the powered-off Z19.'
