#!/bin/sh
# PID 1 for the RAM recovery environment. Nothing is formatted at boot.
export PATH=/bin:/sbin
mkdir -p /proc /sys /dev /run /boot /target
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
exec </dev/console >/dev/console 2>&1
touch /run/amazinghand-recovery
echo 'AmazingHand RAM recovery; root installation is NOT automatic.'
boot_uuid=
for argument in $(cat /proc/cmdline); do
    case "$argument" in amazinghand.boot_partuuid=*) boot_uuid=${argument#*=} ;; esac
done
case "$boot_uuid" in
    ????????-01)
        for attempt in 1 2 3 4 5 6 7 8 9 10; do
            boot_device=$(blkid -t "PARTUUID=$boot_uuid" -o device)
            [ -n "$boot_device" ] && break
            sleep 1
        done
        if [ -n "$boot_device" ] && mount -t vfat -o ro "$boot_device" /boot; then
            echo 'Boot partition mounted read-only at /boot.'
            cat /boot/deployment.env
            echo 'When instructed, run: sh /install-z19-root.sh --install ROOT_PARTUUID'
        else
            echo 'Boot partition could not be identified/mounted. DO NOT format any disk.'
        fi
        ;;
    *) echo 'Missing/invalid boot PARTUUID. DO NOT format any disk.' ;;
esac
# Reopening a shell cannot rerun the installer. PID 1 must never exit.
while :; do
    /bin/sh
    echo 'Recovery shell exited; reopening. Use sync then reboot -f to restart.'
    sleep 1
done
