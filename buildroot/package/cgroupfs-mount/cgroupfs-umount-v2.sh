#!/bin/sh
# cgroupfs-umount-v2.sh - unmount cgroups
set -e

cd /sys/fs/cgroup

# Unmount cgroup v2 first
if mountpoint -q /sys/fs/cgroup && [ -f /sys/fs/cgroup/cgroup.controllers ]; then
    umount /sys/fs/cgroup || true
fi

# Unmount cgroup v1
for sys in $(awk '!/^#/ { if ($4 == 1) print $1 }' /proc/cgroups); do
    if mountpoint -q /sys/fs/cgroup/$sys; then
        umount /sys/fs/cgroup/$sys || true
    fi
done

# Unmount tmpfs
if mountpoint -q /sys/fs/cgroup; then
    umount /sys/fs/cgroup || true
fi
