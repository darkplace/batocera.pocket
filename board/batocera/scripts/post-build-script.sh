#!/bin/bash -e

# PWD = source dir
# BASE_DIR = build dir
# BUILD_DIR = base dir/build
# HOST_DIR = base dir/host
# BINARIES_DIR = images dir
# TARGET_DIR = target dir

BATOCERA_TARGET_CANDIDATES=$(grep -E "^BR2_PACKAGE_BATOCERA_TARGET_[A-Z_0-9]*=y$" "${BR2_CONFIG}" | sed -e s+'^BR2_PACKAGE_BATOCERA_TARGET_\([A-Z_0-9]*\)=y$'+'\1'+)
BATOCERA_TARGET=""
# Primary resolution: derive board key from output dir name (e.g. /rk3568/target -> RK3568).
# Normalize '-' to '_' to handle names like rk3588-sdio -> RK3588_SDIO.
TARGET_DIR_KEY=$(basename "$(dirname "${TARGET_DIR}")" | tr '[:lower:]-' '[:upper:]_')
for CANDIDATE in ${BATOCERA_TARGET_CANDIDATES}; do
    if [ "${CANDIDATE}" = "${TARGET_DIR_KEY}" ]; then
        BATOCERA_TARGET="${CANDIDATE}"
        break
    fi
done

# Secondary resolution: find a concrete board marker for the candidate.
for CANDIDATE in ${BATOCERA_TARGET_CANDIDATES}; do
    if [ -n "${BATOCERA_TARGET}" ]; then
        break
    fi
    CANDIDATE_LOWER=$(echo "${CANDIDATE}" | tr '[:upper:]' '[:lower:]')
    if [ -f "${BR2_EXTERNAL_BATOCERA_PATH}/configs/batocera-${CANDIDATE_LOWER}.board" ]; then
        BATOCERA_TARGET="${CANDIDATE}"
        break
    fi
done

# Fallback to the first enabled target flag if no concrete board marker was found.
if [ -z "${BATOCERA_TARGET}" ]; then
    BATOCERA_TARGET=$(echo "${BATOCERA_TARGET_CANDIDATES}" | head -n1)
fi

# Waydroid is unsupported on SM8750. Remove stale files left by an older
# incremental output before generating the final root filesystem.
if [ "${BATOCERA_TARGET}" = "SM8750" ]; then
    bash "${BR2_EXTERNAL_BATOCERA_PATH}/board/batocera/qualcomm/sm8750/cleanup-waydroid.sh" \
        "${TARGET_DIR}" || exit 1
fi

# Inject optional armhf multilib stack when a matching *_armhf_libs build
# exists in output/. This enables /lib32 runtime for PortMaster/box86 flows.
BATOCERA_INJECT_ARMHF_SCRIPT="${BR2_EXTERNAL_BATOCERA_PATH}/board/batocera/scripts/inject-armhf-libs.sh"
if [ -f "${BATOCERA_INJECT_ARMHF_SCRIPT}" ]; then
    bash "${BATOCERA_INJECT_ARMHF_SCRIPT}" "${BATOCERA_TARGET}" "${TARGET_DIR}" "${BR2_EXTERNAL_BATOCERA_PATH}" || exit 1
fi

# Inject optional i386 multilib stack when a matching *_i386_libs build
# exists in output/. This enables native 32-bit Steam/Wine userspace on x86_64.
BATOCERA_INJECT_I386_SCRIPT="${BR2_EXTERNAL_BATOCERA_PATH}/board/batocera/scripts/inject-i386-libs.sh"
if [ -f "${BATOCERA_INJECT_I386_SCRIPT}" ]; then
    bash "${BATOCERA_INJECT_I386_SCRIPT}" "${BATOCERA_TARGET}" "${TARGET_DIR}" "${BR2_EXTERNAL_BATOCERA_PATH}" || exit 1
fi

# Inject optional x86-64-v3 shadPS4 rootfs for FEX on SM8X50 targets.
BATOCERA_INJECT_SHADPS4_FEX_SCRIPT="${BR2_EXTERNAL_BATOCERA_PATH}/board/batocera/scripts/inject-shadps4-fex-rootfs.sh"
if [ -f "${BATOCERA_INJECT_SHADPS4_FEX_SCRIPT}" ]; then
    bash "${BATOCERA_INJECT_SHADPS4_FEX_SCRIPT}" "${BATOCERA_TARGET}" "${TARGET_DIR}" "${BR2_EXTERNAL_BATOCERA_PATH}" || exit 1
fi

# Compatibility helpers for scripts that only include /bin in PATH.
# Keep tool entrypoints available there.
if [ -x "${TARGET_DIR}/usr/bin/systemctl" ]; then
    ln -snf ../usr/bin/systemctl "${TARGET_DIR}/bin/systemctl" || exit 1
fi
if [ -x "${TARGET_DIR}/usr/bin/glxinfo" ]; then
    ln -snf ../usr/bin/glxinfo "${TARGET_DIR}/bin/glxinfo" || exit 1
fi

# For the root user:
# 1. Use Bash instead of Dash for interactive use.
# 2. Set home directory to /userdata/system instead of /root.
sed -i "s|^root:x:.*$|root:x:0:0:root:/userdata/system:/bin/bash|g" "${TARGET_DIR}/etc/passwd" || exit 1

rm -rf "${TARGET_DIR}/etc/dropbear" || exit 1
ln -sf "/userdata/system/.ssh" "${TARGET_DIR}/etc/dropbear" || exit 1

mkdir -p ${TARGET_DIR}/etc/emulationstation || exit 1
ln -sf "/usr/share/emulationstation/es_systems.cfg" "${TARGET_DIR}/etc/emulationstation/es_systems.cfg" || exit 1
ln -sf "/usr/share/emulationstation/themes"         "${TARGET_DIR}/etc/emulationstation/themes"         || exit 1
mkdir -p "${TARGET_DIR}/usr/share/batocera/datainit/cheats" || exit 1
ln -sf "/userdata/cheats" "${TARGET_DIR}/usr/share/batocera/datainit/cheats/custom" || exit 1

# we don't want the kodi startup script
rm -f "${TARGET_DIR}/etc/init.d/S50kodi" || exit 1

# we have custom urandom scripts
rm -f "${TARGET_DIR}/etc/init.d/S20urandom" || exit 1

# use /userdata/system/iptables.conf for S35iptables
rm -f "${TARGET_DIR}/etc/iptables.conf" || exit 1
ln -sf "/userdata/system/iptables.conf" "${TARGET_DIR}/etc/iptables.conf" || exit 1

# acpid requires /var/run, so, requires S03populate
if test -e "${TARGET_DIR}/etc/init.d/S02acpid"
then
    mv "${TARGET_DIR}/etc/init.d/S02acpid" "${TARGET_DIR}/etc/init.d/S05acpid" || exit 1
fi

# we don't want default xorg files
rm -f "${TARGET_DIR}/etc/X11/xorg.conf"  || exit 1
rm -f "${TARGET_DIR}/etc/init.d/S40xorg" || exit 1

# remove the S10triggerhappy
rm -f "${TARGET_DIR}/etc/init.d/S10triggerhappy" || exit 1

# remove the S40bluetoothd
rm -f "${TARGET_DIR}/etc/init.d/S40bluetoothd" || exit 1

# we want an empty boot directory (grub installation copy some files in the target boot directory)
rm -rf "${TARGET_DIR}/boot/grub" || exit 1

# reorder the boot scripts for the network boot
if test -e "${TARGET_DIR}/etc/init.d/S10udev"
then
    mv "${TARGET_DIR}/etc/init.d/S10udev"    "${TARGET_DIR}/etc/init.d/S05udev"    || exit 1 # move to make number spaces
fi
if test -e "${TARGET_DIR}/etc/init.d/S30dbus"
then
    mv "${TARGET_DIR}/etc/init.d/S30dbus"    "${TARGET_DIR}/etc/init.d/S01dbus"    || exit 1 # move really before for network (connman prerequisite) and pipewire
fi
if test -e "${TARGET_DIR}/etc/init.d/S40network"
then
    mv "${TARGET_DIR}/etc/init.d/S40network" "${TARGET_DIR}/etc/init.d/S07network" || exit 1 # move to make ifaces up sooner, mainly mountable/unmountable before/after share
fi
if test -e "${TARGET_DIR}/etc/init.d/S45connman"
then
    if test -e "${TARGET_DIR}/etc/init.d/S08connman"
    then
	rm -f "${TARGET_DIR}/etc/init.d/S45connman" || exit 1
    else
	mv "${TARGET_DIR}/etc/init.d/S45connman" "${TARGET_DIR}/etc/init.d/S08connman" || exit 1 # move to make before share
    fi
fi
if test -e "${TARGET_DIR}/etc/init.d/S21rngd"
then
    mv "${TARGET_DIR}/etc/init.d/S21rngd"    "${TARGET_DIR}/etc/init.d/S33rngd"    || exit 1 # move because it takes several seconds (on odroidgoa for example)
    sed -i "s/start-stop-daemon -S -q /start-stop-daemon -S -q -N 10 /g" "${TARGET_DIR}/etc/init.d/S33rngd"  || exit 1 # set rngd niceness to 10 (to decrease slowdown of other processes)
fi

# remove kodi default joystick configuration files
# while as a minimum, the file joystick.Sony.PLAYSTATION(R)3.Controller.xml makes references to PS4 controllers with axes which doesn't exist (making kodi crashing)
# i prefer to put it here than in packages/kodi while there are already a lot a lot of things
rm -rf "${TARGET_DIR}/usr/share/kodi/system/keymaps/joystick."*.xml || exit 1

# tmpfs or sysfs is mounted over theses directories
# clear these directories is required for the upgrade (otherwise, tar xf fails)
rm -rf "${TARGET_DIR}/"{var,run,sys,tmp} || exit 1
mkdir "${TARGET_DIR}/"{var,run,sys,tmp}  || exit 1

# make /etc/shadow a file generated from /boot/batocera-boot.conf for security
rm -f "${TARGET_DIR}/etc/shadow" || exit 1
touch "${TARGET_DIR}/run/batocera.shadow"
(cd "${TARGET_DIR}/etc" && ln -sf "../run/batocera.shadow" "shadow") || exit 1
# ln -sf "/run/batocera.shadow" "${TARGET_DIR}/etc/shadow" || exit 1

# fix pixbuf : Unable to load image-loading module: /lib/gdk-pixbuf-2.0/2.10.0/loaders/libpixbufloader-png.so
# this fix is to be removed once fixed. i've not found the exact source in buildroot. it prevents to display icons in filemanager and some others
if test "${BATOCERA_TARGET}" = "X86" -o "${BATOCERA_TARGET}" = X86_64
then
    ln -sf "/usr/lib/gdk-pixbuf-2.0" "${TARGET_DIR}/lib/gdk-pixbuf-2.0" || exit 1
fi

# timezone
# file generated from the output directory and compared to https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
# because i don't know how to list correctly them
(cd "${TARGET_DIR}/usr/share/zoneinfo" && find -L . -type f | grep -vE '/right/|/posix/|\.tab|Factory' | sed -e s+'^\./'++ | sort) > "${TARGET_DIR}/usr/share/batocera/tz"

# alsa lib
# on x86_64, pcsx2 has no sound because getgrnam_r returns successfully but the result parameter is not filled for an unknown reason (in alsa-lib)
AUDIOGROUP=$(grep -E "^audio:" "${TARGET_DIR}/etc/group" | cut -d : -f 3)
sed -i -e s+'defaults.pcm.ipc_gid .*$'+'defaults.pcm.ipc_gid '"${AUDIOGROUP}"+ "${TARGET_DIR}/usr/share/alsa/alsa.conf" || exit 1

# bios file
mkdir -p "${TARGET_DIR}/usr/share/batocera/datainit/bios" || exit 1
python "${BR2_EXTERNAL_BATOCERA_PATH}/package/batocera/core/batocera-scripts/scripts/batocera-systems" --createReadme > "${TARGET_DIR}/usr/share/batocera/datainit/bios/readme.txt" || exit 1

# enable serial console
SYSTEM_GETTY_PORT=$(grep "BR2_TARGET_GENERIC_GETTY_PORT" "${BR2_CONFIG}" | sed 's/.*\"\(.*\)\"/\1/')
if ! [[ -z "${SYSTEM_GETTY_PORT}" ]]; then
    SYSTEM_GETTY_BAUDRATE=$(grep -E "^BR2_TARGET_GENERIC_GETTY_BAUDRATE_[0-9]*=y$" "${BR2_CONFIG}" | sed -e s+'^BR2_TARGET_GENERIC_GETTY_BAUDRATE_\([0-9]*\)=y$'+'\1'+)
    sed -i -e '/# GENERIC_SERIAL$/s~^.*#~S0::respawn:/sbin/getty -n -L -l /usr/bin/batocera-autologin '${SYSTEM_GETTY_PORT}' '${SYSTEM_GETTY_BAUDRATE}' vt100 #~' \
        ${TARGET_DIR}/etc/inittab
fi

# split target dir in 2 cause of the 4GB image size limit
# in initrd, the 2 targets will be mounted as one
TARGET2_DIR=${TARGET_DIR}2
echo "Generating target2 (${TARGET2_DIR})..."
mkdir -p "${TARGET2_DIR}" || exit 1
# Keep each squashfs below FAT32's per-file limit by moving heavy, static assets
# into the secondary image mounted by initramfs.
for XDIR in \
    lib/firmware \
    lib \
    usr/lib/libretro \
    usr/share/batocera/apps 
do
    echo -n "${XDIR}..."
    if test -e "${TARGET_DIR}/${XDIR}"
    then
	mkdir -p "${TARGET2_DIR}/${XDIR}" || exit 1
	rsync -a "${TARGET_DIR}/${XDIR}/" "${TARGET2_DIR}/${XDIR}/" || exit 1
	rm -rf "${TARGET_DIR}/${XDIR}/" || exit 1
	echo "OK."
    elif test -d "${TARGET2_DIR}/${XDIR}"
    then
    echo "Already in target2. Continuing..."
    else
	echo "${TARGET_DIR}/${XDIR} not found."
	exit 1
    fi
done

# target2 persists across incremental builds, so a kernel bump can otherwise
# leave the previous kernel's modules in rufomaculata.  Resolve the active
# kernel's exact release from the configured source tree and prune only when
# its replacement module directory is already present.
ACTIVE_KERNEL_VERSION="$(sed -n 's/^BR2_LINUX_KERNEL_VERSION="\(.*\)"$/\1/p' "${BR2_CONFIG}")"
ACTIVE_KERNEL_RELEASE=""
if test -n "${ACTIVE_KERNEL_VERSION}" -a \
        -r "${BUILD_DIR}/linux-${ACTIVE_KERNEL_VERSION}/include/config/kernel.release"
then
    ACTIVE_KERNEL_RELEASE="$(sed -n '1p' "${BUILD_DIR}/linux-${ACTIVE_KERNEL_VERSION}/include/config/kernel.release")"
fi

if test -n "${ACTIVE_KERNEL_RELEASE}" -a \
        -d "${TARGET2_DIR}/lib/modules/${ACTIVE_KERNEL_RELEASE}"
then
    for KERNEL_MODULE_DIR in "${TARGET2_DIR}"/lib/modules/*
    do
        test -d "${KERNEL_MODULE_DIR}" || continue
        if test "$(basename "${KERNEL_MODULE_DIR}")" != "${ACTIVE_KERNEL_RELEASE}"
        then
            echo "Removing stale kernel modules: ${KERNEL_MODULE_DIR}"
            rm -rf "${KERNEL_MODULE_DIR}" || exit 1
        fi
    done
fi

# Rebuild module indexes after moving /lib into target2. External module
# packages can leave modules.dep/modules.alias reflecting only their own
# updates/ modules, which breaks modalias autoloading in the final image.
if test -d "${TARGET2_DIR}/lib/modules"
then
    for KERNEL_MODULE_DIR in "${TARGET2_DIR}"/lib/modules/*
    do
        test -d "${KERNEL_MODULE_DIR}" || continue
        "${HOST_DIR}/sbin/depmod" -a -b "${TARGET2_DIR}" "$(basename "${KERNEL_MODULE_DIR}")" || exit 1
    done
fi

# generate the image 2
echo "Generating ${BINARIES_DIR}/rufomaculata..."
"${HOST_DIR}/bin/mksquashfs" "${TARGET2_DIR}" "${BINARIES_DIR}/rufomaculata" -noappend -b 128K -comp zstd || exit 1

# With PARALLEL_BUILD it is difficult to control which of two
# conflicting files from different packages will be the one ending up
# in the final image.  We take any files written to a special
# directory ${BINARIES_DIR}/batocera-target/ and overwrite those
# in the main target tree.

if [ -d "${BINARIES_DIR}/batocera-target" ]; then
    cp -pr "${BINARIES_DIR}/batocera-target/./" "${TARGET_DIR}/./"
fi
