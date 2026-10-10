#!/bin/sh
# Explicit installation only, from our RAM recovery. Reject eMMC and other layouts.
set -eu
export PATH=/bin:/sbin
fail() { echo "INSTALL_REFUSED: $*" >&2; exit 1; }
[ "$#" -eq 2 ] || fail 'Usage: sh /install-z19-root.sh --install|--finish ROOT_PARTUUID'
case "$1" in --install|--finish) ;; *) fail 'Expected --install or --finish' ;; esac
operation=$1
[ -f /run/amazinghand-recovery ] || fail 'Not running in the RAM recovery environment'
grep -q 'rdinit=/init' /proc/cmdline || fail 'Missing recovery boot argument'
grep -q ' /boot vfat ' /proc/mounts || fail 'FAT boot partition is not mounted'
[ -r /boot/deployment.env ] || fail 'Missing deployment identity'
# Do not source content from the FAT card as shell code.
ah_boot_partuuid= ah_root_partuuid= ah_disk_sectors= ah_root_start= ah_root_sectors= ah_rootfs_sha256=
while IFS='=' read -r key value; do
    case "$key" in
        ah_boot_partuuid) ah_boot_partuuid=$value ;;
        ah_root_partuuid) ah_root_partuuid=$value ;;
        ah_disk_sectors) ah_disk_sectors=$value ;;
        ah_root_start) ah_root_start=$value ;;
        ah_root_sectors) ah_root_sectors=$value ;;
        ah_rootfs_sha256) ah_rootfs_sha256=$value ;;
        *) fail 'Unexpected deployment key' ;;
    esac
done < /boot/deployment.env
case "$ah_boot_partuuid:$ah_root_partuuid" in ????????-01:????????-02) ;; *) fail 'Invalid PARTUUID pair' ;; esac
case "${ah_boot_partuuid%-01}${ah_root_partuuid%-02}" in *[!0-9a-f]*) fail 'Non-hex disk signature' ;; esac
[ "${ah_boot_partuuid%-01}" = "${ah_root_partuuid%-02}" ] || fail 'Partitions belong to different disks'
[ "$2" = "$ah_root_partuuid" ] || fail 'Explicit confirmation must equal root PARTUUID'
for value in "$ah_disk_sectors" "$ah_root_start" "$ah_root_sectors"; do
    case "$value" in ''|*[!0-9]*) fail 'Invalid geometry' ;; esac
done
[ "$ah_disk_sectors" = '61071360' ] || fail 'Unexpected authorized card capacity'
[ "$ah_root_start" = '2099200' ] || fail 'Unexpected root boundary'
[ "$ah_root_sectors" -gt 50000000 ] || fail 'Root partition unexpectedly small'
case "$ah_rootfs_sha256" in *[!0-9a-f]*) fail 'Invalid rootfs hash' ;; esac
[ "${#ah_rootfs_sha256}" -eq 64 ] || fail 'Invalid rootfs hash length'
boot_device=$(blkid -t "PARTUUID=$ah_boot_partuuid" -o device)
root_device=$(blkid -t "PARTUUID=$ah_root_partuuid" -o device)
case "$boot_device" in /dev/mmcblk[0-9]p1) ;; *) fail 'Boot is not an SD MMC partition 1' ;; esac
[ "$root_device" = "${boot_device%p1}p2" ] || fail 'Root is not partition 2 of the same SD'
disk=${boot_device#/dev/}; disk=${disk%p1}
sys=/sys/class/block/$disk
[ "$(cat "$sys/device/type")" = 'SD' ] || fail 'Device is not SD (eMMC is forbidden)'
[ "$(cat "$sys/size")" = "$ah_disk_sectors" ] || fail 'Card capacity mismatch'
[ "$(cat "$sys/${disk}p1/start")" = '2048' ] || fail 'Boot offset mismatch'
[ "$(cat "$sys/${disk}p1/size")" = '2097152' ] || fail 'Boot size mismatch'
[ "$(cat "$sys/${disk}p2/start")" = "$ah_root_start" ] || fail 'Root offset mismatch'
[ "$(cat "$sys/${disk}p2/size")" = "$ah_root_sectors" ] || fail 'Root size mismatch'
[ ! -e "$sys/${disk}p3" ] || fail 'Unexpected third partition'
mounted_boot=$(awk '$2 == "/boot" {print $1}' /proc/mounts)
[ "$mounted_boot" = "$boot_device" ] || fail 'Mounted boot device mismatch'
awk -v d="$root_device" '$1 == d {found=1} END {exit !found}' /proc/swaps && fail 'Root partition is in use as swap'
awk -v d="$root_device" '$1 == d {found=1} END {exit !found}' /proc/mounts && fail 'Root partition is already mounted'
[ ! -e /boot/installed.env ] || fail 'An installation already exists; recovery will not erase it'
root_type=$(blkid -s TYPE -o value "$root_device" || true)
if [ "$operation" = '--install' ]; then
    [ -z "$root_type" ] || fail 'Root already has a filesystem; refusing to erase it'
else
    [ "$root_type" = 'ext4' ] || fail 'Finish requires the existing ext4 installation'
fi
[ "$ah_rootfs_sha256" = '4f05d24af1b04d3490dde9d3526c4119b9d2e08752b2954c96cfe167f57ddf34' ] || fail 'Root archive is not the reviewed senior baseline'
echo "$ah_rootfs_sha256  /boot/rootfs.tar.gz" | sha256sum -c - || fail 'Root archive checksum mismatch'
echo "INSTALL_TARGET: $root_device, PARTUUID=$ah_root_partuuid, start=$ah_root_start, sectors=$ah_root_sectors"
cleanup() { sync; umount /target 2>/dev/null || true; }
if [ "$operation" = '--finish' ]; then
    # Never re-extract over an interrupted installation. Only an exact archive
    # match may proceed; a partial extraction needs a separate reviewed repair.
    fsck.ext4 -f -n "$root_device" || fail 'Existing ext4 check failed'
    mount -t ext4 -o ro,noload "$root_device" /target
    trap cleanup EXIT
    tar --warning=no-timestamp --numeric-owner -dzf /boot/rootfs.tar.gz -C /target || fail 'Existing root differs from the archive; nothing will be overwritten'
    for path in /target/var/lib/amazinghand/deployment.env /target/var/lib/amazinghand/root-partuuid /target/opt/amazinghand/bin/probe_z19_linux.sh; do
        [ ! -e "$path" ] && [ ! -L "$path" ] || fail 'Project metadata already exists; inspect before finishing'
    done
    umount /target
    trap - EXIT
else
    echo 'Formatting only this verified, blank root partition as ext4.'
    mkfs.ext4 -F -L AH_ROOT "$root_device"
fi
mount -t ext4 "$root_device" /target
trap cleanup EXIT
# The first boot can have an unset RTC. Keep archive timestamps; suppress only
# the corresponding warning so serial output does not throttle every file.
if [ "$operation" = '--install' ]; then
    tar --warning=no-timestamp --numeric-owner --same-owner --same-permissions -xzf /boot/rootfs.tar.gz -C /target
fi
# The senior archive uses absolute symlinks for /sbin/init and /bin/sh.
# Resolve and execute checks inside the new root, not against the RAM root.
chroot /target /bin/sh -c 'export PATH=/usr/sbin:/usr/bin:/sbin:/bin; test -x /sbin/init && test -x /bin/sh && test -r /lib/modules/5.4.0-xilinx-v2020.2/build/.config && test "$(stat -c %u /etc)" = 0' || fail 'Root runtime, kernel baseline or ownership check failed'
# /var/log in the senior root is an absolute symlink into volatile storage.
# Keep project logs under /var/lib, and resolve directory links inside the root.
chroot /target /bin/sh -c 'export PATH=/usr/sbin:/usr/bin:/sbin:/bin; mkdir -p /var/lib/amazinghand/log /opt/amazinghand/bin /opt/amazinghand/models /opt/amazinghand/calibration'
cp /boot/deployment.env /target/var/lib/amazinghand/deployment.env
cp /boot/probe_z19_linux.sh /target/opt/amazinghand/bin/probe_z19_linux.sh
chmod 755 /target/opt/amazinghand/bin/probe_z19_linux.sh
echo "PARTUUID=$ah_root_partuuid" > /target/var/lib/amazinghand/root-partuuid
sync
umount /target
trap - EXIT
fsck.ext4 -f -n "$root_device" || fail 'Read-only ext4 check failed; normal boot not enabled'
mount -t ext4 -o ro "$root_device" /target
chroot /target /bin/sh -c 'export PATH=/usr/sbin:/usr/bin:/sbin:/bin; test -x /sbin/init && test -x /bin/sh && getconf GNU_LIBC_VERSION' || fail 'Post-install runtime/read-back failed'
umount /target
mount -o remount,rw /boot
printf 'ah_installed=1\n' > /boot/installed.env.tmp
sync
mv /boot/installed.env.tmp /boot/installed.env
sync
mount -o remount,ro /boot
echo 'ROOT_INSTALL_COMPLETE: normal boot enabled. No camera or hand validation has been performed.'
echo 'Save this serial log, then run sync and reboot -f.'
