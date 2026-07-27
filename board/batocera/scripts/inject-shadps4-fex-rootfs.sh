#!/bin/bash -e
# SPDX-FileCopyrightText: Added/modified by suckbluefrog

# Usage:
#   inject-shadps4-fex-rootfs.sh <target_name_uppercase> <target_dir> <external_dir>
#
# Example:
#   inject-shadps4-fex-rootfs.sh SM8750 /sm8750/target /build

TARGET_NAME="${1}"
TARGET_DIR="${2}"
EXTERNAL_DIR="${3}"

if [ -z "${TARGET_NAME}" ] || [ -z "${TARGET_DIR}" ] || [ -z "${EXTERNAL_DIR}" ]; then
    echo "inject-shadps4-fex-rootfs.sh: invalid arguments" >&2
    exit 1
fi

TARGET_LOWER="$(echo "${TARGET_NAME}" | tr '[:upper:]' '[:lower:]')"
GUEST_ROOT="${EXTERNAL_DIR}/output/${TARGET_LOWER}_x86_64_v3_shadps4/target"
GUEST_SHADPS4="${GUEST_ROOT}/usr/bin/shadps4/shadps4"
DEST_ROOT="${TARGET_DIR}/usr/share/batocera/apps/shadps4-fex-rootfs"
DEST_SHADPS4="${DEST_ROOT}/usr/bin/shadps4/shadps4"
DEST_QTLAUNCHER="${DEST_ROOT}/usr/bin/shadps4/shadps4-qtlauncher"
DEST_QTLAUNCHER_NATIVE="${DEST_ROOT}/usr/bin/shadps4/shadPS4QtLauncher"
FEX_CONFIG_DIR="${TARGET_DIR}/usr/share/fex-emu/shadps4-fex"
FEX_QTLAUNCHER_CONFIG_DIR="${TARGET_DIR}/usr/share/fex-emu/shadps4-fex-qtlauncher"
LOG_DIR="${EXTERNAL_DIR}/output/build-logs"
MANIFEST_FILE="${LOG_DIR}/${TARGET_LOWER}_shadps4_fex_rootfs_files.txt"

# Check the ELF identification bytes directly instead of relying on file(1).
# Buildroot's host file binary and the build container's magic.mgc can have
# different database versions, while these bytes are stable: ELF64, little
# endian, EM_X86_64 (0x003e).
is_x86_64_elf() {
    local elf_file="${1}"
    local elf_ident
    local elf_machine

    [ -r "${elf_file}" ] || return 1
    elf_ident="$(od -An -tx1 -N6 "${elf_file}" 2>/dev/null | tr -d '[:space:]')" || return 1
    elf_machine="$(od -An -tx1 -j18 -N2 "${elf_file}" 2>/dev/null | tr -d '[:space:]')" || return 1

    [ "${elf_ident}" = "7f454c460201" ] && [ "${elf_machine}" = "3e00" ]
}

if [ ! -x "${TARGET_DIR}/usr/bin/shadps4-fex" ]; then
    echo "shadps4-fex launcher is not installed for ${TARGET_LOWER}, skipping shadPS4 FEX rootfs injection."
    exit 0
fi

if [ ! -x "${GUEST_SHADPS4}" ]; then
    echo "No x86-64-v3 shadPS4 guest rootfs found for ${TARGET_LOWER} at ${GUEST_SHADPS4}, skipping shadPS4 FEX rootfs injection."
    exit 0
fi

echo "Injecting x86-64-v3 shadPS4 FEX rootfs from ${GUEST_ROOT} to ${DEST_ROOT}"
rm -rf "${DEST_ROOT}" || exit 1
rm -rf "${FEX_QTLAUNCHER_CONFIG_DIR}" || exit 1
mkdir -p "${DEST_ROOT}" "${FEX_CONFIG_DIR}" "${FEX_QTLAUNCHER_CONFIG_DIR}" "${LOG_DIR}" || exit 1

# Copy a complete enough guest rootfs for FEX dynamic linking while dropping
# build/development payload that is not useful at runtime.
rsync -a --delete \
    --exclude '/dev/*' \
    --exclude '/proc/*' \
    --exclude '/sys/*' \
    --exclude '/run/*' \
    --exclude '/tmp/*' \
    --exclude '/boot' \
    --exclude '/root' \
    --exclude '/usr/include' \
    --exclude '/usr/share/doc' \
    --exclude '/usr/share/gtk-doc' \
    --exclude '/usr/share/info' \
    --exclude '/usr/share/man' \
    --exclude '/usr/lib/cmake' \
    --exclude '/usr/lib/pkgconfig' \
    --exclude '/usr/lib64/cmake' \
    --exclude '/usr/lib64/pkgconfig' \
    --exclude '*.a' \
    --exclude '*.la' \
    "${GUEST_ROOT}/" "${DEST_ROOT}/" || exit 1

chmod 0755 "${DEST_SHADPS4}" || exit 1
if [ -e "${DEST_QTLAUNCHER}" ]; then
    chmod 0755 "${DEST_QTLAUNCHER}" || exit 1
fi
if [ -e "${DEST_QTLAUNCHER_NATIVE}" ]; then
    chmod 0755 "${DEST_QTLAUNCHER_NATIVE}" || exit 1
    if [ ! -e "${DEST_QTLAUNCHER}" ]; then
        ln -snf shadPS4QtLauncher "${DEST_QTLAUNCHER}" || exit 1
    fi
fi

if [ ! -e "${DEST_ROOT}/lib64/ld-linux-x86-64.so.2" ] && [ -e "${DEST_ROOT}/lib/ld-linux-x86-64.so.2" ]; then
    mkdir -p "${DEST_ROOT}/lib64" || exit 1
    ln -snf ../lib/ld-linux-x86-64.so.2 "${DEST_ROOT}/lib64/ld-linux-x86-64.so.2" || exit 1
fi

if [ ! -e "${DEST_ROOT}/lib64/ld-linux-x86-64.so.2" ]; then
    echo "ERROR: injected shadPS4 FEX rootfs is missing /lib64/ld-linux-x86-64.so.2" >&2
    exit 1
fi

if ! is_x86_64_elf "${DEST_ROOT}/lib64/ld-linux-x86-64.so.2"; then
    echo "ERROR: injected shadPS4 FEX loader is not x86-64" >&2
    exit 1
fi

if ! is_x86_64_elf "${DEST_SHADPS4}"; then
    echo "ERROR: injected shadPS4 FEX binary is not x86-64" >&2
    exit 1
fi

if [ -e "${DEST_QTLAUNCHER}" ] && ! is_x86_64_elf "${DEST_QTLAUNCHER}"; then
    echo "ERROR: injected shadPS4 FEX Qt launcher is not x86-64" >&2
    exit 1
fi
if [ -e "${DEST_QTLAUNCHER_NATIVE}" ] && ! is_x86_64_elf "${DEST_QTLAUNCHER_NATIVE}"; then
    echo "ERROR: injected shadPS4 FEX Qt launcher is not x86-64" >&2
    exit 1
fi

for thunk in \
    libEGL-guest.so \
    libGL-guest.so \
    libasound-guest.so \
    libdrm-guest.so \
    libvulkan-guest.so \
    libwayland-client-guest.so
do
    if [ ! -e "${TARGET_DIR}/usr/share/fex-emu/GuestThunks/${thunk}" ]; then
        echo "ERROR: FEX guest thunk ${thunk} is missing; shadPS4 FEX config would fail." >&2
        exit 1
    fi
done

rm -rf "${TARGET_DIR}/usr/bin/shadps4-x86_64" || exit 1
ln -snf ../share/batocera/apps/shadps4-fex-rootfs/usr/bin/shadps4 "${TARGET_DIR}/usr/bin/shadps4-x86_64" || exit 1

# shadPS4's Vulkan WSI path needs FEX's WaylandClient thunk so Vulkan and SDL
# share host-side Wayland objects.
cat > "${FEX_CONFIG_DIR}/shadps4-fex.json" <<'EOF'
{
  "Config": {
    "RootFS": "/usr/share/batocera/apps/shadps4-fex-rootfs",
    "SilentLog": "1",
    "Multiblock": "1",
    "TSOEnabled": "1",
    "ThunkHostLibs": "/usr/lib/fex-emu/HostThunks",
    "ThunkGuestLibs": "/usr/share/fex-emu/GuestThunks"
  },
  "ThunksDB": {
    "EGL": 1,
    "GL": 1,
    "Vulkan": 1,
    "drm": 1,
    "asound": 1,
    "WaylandClient": 1
  }
}
EOF

# The Qt launcher fails under the game config because the local ThunksDB enables
# the WaylandClient thunk. Keep the game path unchanged and run the launcher from
# its own config directory without that thunk.
cat > "${FEX_QTLAUNCHER_CONFIG_DIR}/shadps4-fex.json" <<'EOF'
{
  "Config": {
    "RootFS": "/usr/share/batocera/apps/shadps4-fex-rootfs",
    "SilentLog": "1",
    "Multiblock": "1",
    "TSOEnabled": "1",
    "ThunkHostLibs": "/usr/lib/fex-emu/HostThunks",
    "ThunkGuestLibs": "/usr/share/fex-emu/GuestThunks"
  },
  "ThunksDB": {
    "EGL": 1,
    "GL": 1,
    "Vulkan": 1,
    "drm": 1,
    "asound": 1
  }
}
EOF

cat > "${FEX_CONFIG_DIR}/ThunksDB.json" <<'EOF'
{
  "DB": {
    "EGL": {
      "Library": "libEGL-guest.so",
      "Overlay": [
        "@PREFIX_LIB@/libEGL.so",
        "@PREFIX_LIB@/libEGL.so.1",
        "@PREFIX_LIB@/libEGL.so.1.0.0",
        "@PREFIX_LIB@/libEGL.so.1.1.0"
      ]
    },
    "GL": {
      "Library": "libGL-guest.so",
      "Overlay": [
        "@PREFIX_LIB@/libGL.so",
        "@PREFIX_LIB@/libGL.so.1",
        "@PREFIX_LIB@/libGL.so.1.2.0",
        "@PREFIX_LIB@/libGL.so.1.7.0"
      ]
    },
    "Vulkan": {
      "Library": "libvulkan-guest.so",
      "Overlay": [
        "@PREFIX_LIB@/libvulkan.so",
        "@PREFIX_LIB@/libvulkan.so.1",
        "@HOME@/.local/share/Steam/ubuntu12_32/steam-runtime/pinned_libs_64/libvulkan.so.1"
      ]
    },
    "drm": {
      "Library": "libdrm-guest.so",
      "Overlay": [
        "@PREFIX_LIB@/libdrm.so",
        "@PREFIX_LIB@/libdrm.so.2",
        "@PREFIX_LIB@/libdrm.so.2.4.0"
      ]
    },
    "asound": {
      "Library": "libasound-guest.so",
      "Overlay": [
        "@PREFIX_LIB@/libasound.so",
        "@PREFIX_LIB@/libasound.so.2",
        "@PREFIX_LIB@/libasound.so.2.0.0"
      ]
    },
    "WaylandClient": {
      "Library": "libwayland-client-guest.so",
      "Overlay": [
        "@PREFIX_LIB@/libwayland-client.so",
        "@PREFIX_LIB@/libwayland-client.so.0",
        "@PREFIX_LIB@/libwayland-client.so.0.20.0"
      ]
    }
  }
}
EOF

(
    cd "${DEST_ROOT}" || exit 1
    find . -mindepth 1 -not -type d | sed -e 's#^\./#/usr/share/batocera/apps/shadps4-fex-rootfs/#' | sort
) > "${MANIFEST_FILE}"

mkdir -p "${TARGET_DIR}/usr/share/batocera/shadps4-fex" || exit 1
cp "${MANIFEST_FILE}" "${TARGET_DIR}/usr/share/batocera/shadps4-fex/rootfs-files.txt" || exit 1

echo "shadPS4 FEX rootfs injection completed for ${TARGET_LOWER}."
echo "Manifest: ${MANIFEST_FILE}"
