#!/bin/sh
# cgroupfs-mount with cgroup v2 support for Qualcomm kernels
# Qualcomm kernels use cgroup_no_v1=all in cmdline, disabling cgroup v1.
# This script detects that and sets up cgroup v2 (unified hierarchy) instead.
set -e

# if cgroup is mounted by fstab, dont run
if grep -v '^#' /etc/fstab | grep -q cgroup; then
    echo 'cgroups mounted from fstab, not mounting /sys/fs/cgroup'
    exit 0
fi

# kernel provides cgroups?
if [ ! -e /proc/cgroups ]; then
    exit 0
fi

# if we dont even have the directory we need, something else must be wrong
if [ ! -d /sys/fs/cgroup ]; then
    exit 0
fi

# mount /sys/fs/cgroup tmpfs if not already done
if ! mountpoint -q /sys/fs/cgroup; then
    mount -t tmpfs -o uid=0,gid=0,mode=0755 cgroup /sys/fs/cgroup
fi

cd /sys/fs/cgroup

# Detect if cgroup v1 is disabled by checking kernel cmdline
# (Qualcomm kernels set cgroup_no_v1=all)
cgroupv2_only=false
if grep -q 'cgroup_no_v1=all' /proc/cmdline 2>/dev/null; then
    cgroupv2_only=true
fi

# Also check if cgroup2 filesystem is available and no v1 hierarchy is active
if [ "$cgroupv2_only" = "false" ]; then
    # Check if any v1 controller actually has a non-zero hierarchy
    has_v1_hierarchy=false
    while read -r line; do
        case "$line" in
            \#*) continue ;;
        esac
        hierarchy=$(echo "$line" | awk '{print $3}')
        if [ "$hierarchy" != "0" ]; then
            has_v1_hierarchy=true
            break
        fi
    done < /proc/cgroups
    if [ "$has_v1_hierarchy" = "false" ] && grep -qw "cgroup2" /proc/filesystems 2>/dev/null; then
        cgroupv2_only=true
    fi
fi

if [ "$cgroupv2_only" = "true" ]; then
    # cgroup v2 (unified hierarchy) path
    # Mount cgroup2 if not already mounted
    if ! mountpoint -q /sys/fs/cgroup 2>/dev/null || ! [ -f /sys/fs/cgroup/cgroup.controllers ]; then
        mount -t cgroup2 -o nsdelegate,memory_recursiveprot cgroup2 /sys/fs/cgroup || true
    fi

    # Enable all available controllers in the unified hierarchy
    if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
        controllers=$(cat /sys/fs/cgroup/cgroup.controllers)
        if [ -n "$controllers" ]; then
            echo "+${controllers}" > /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null || true
        fi
    fi
else
    # cgroup v1 path (original behavior)
    for sys in $(awk '!/^#/ { if ($4 == 1) print $1 }' /proc/cgroups); do
        mkdir -p $sys
        if ! mountpoint -q $sys; then
            mount -t cgroup -o cpu,cpuacct $sys /sys/fs/cgroup/$sys || true
        fi
        if [ -d /sys/fs/cgroup/$sys/init.scope ]; then
            # cgroup v1 with systemd-style layout
            for controller in $(cat /sys/fs/cgroup/cgroup.controllers); do
                mkdir -p $sys/$controller
                if ! mountpoint -q $sys/$controller; then
                    mount -t cgroup -o $controller $sys /sys/fs/cgroup/$sys/$controller 2>/dev/null || true
                fi
            done
        fi
    done
fi
