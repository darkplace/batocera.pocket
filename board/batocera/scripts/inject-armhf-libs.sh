#!/bin/bash -e
# SPDX-FileCopyrightText: Added/modified by suckbluefrog

# Usage:
#   inject-armhf-libs.sh <target_name_uppercase> <target_dir> <external_dir>
#
# Example:
#   inject-armhf-libs.sh RK3568 /rk3568/target /build

TARGET_NAME="${1}"
TARGET_DIR="${2}"
EXTERNAL_DIR="${3}"

if [ -z "${TARGET_NAME}" ] || [ -z "${TARGET_DIR}" ] || [ -z "${EXTERNAL_DIR}" ]; then
    echo "inject-armhf-libs.sh: invalid arguments" >&2
    exit 1
fi

TARGET_LOWER="$(echo "${TARGET_NAME}" | tr '[:upper:]' '[:lower:]')"
ARMHF_ROOT="${EXTERNAL_DIR}/output/${TARGET_LOWER}_armhf_libs/target"
ARMHF_USR_LIB="${ARMHF_ROOT}/usr/lib"
ARMHF_USR_BIN="${ARMHF_ROOT}/usr/bin"
ARMHF_LIB="${ARMHF_ROOT}/lib"

if [ ! -d "${ARMHF_USR_LIB}" ]; then
    echo "No armhf lib stack found for ${TARGET_LOWER} at ${ARMHF_USR_LIB}, skipping /lib32 injection."
    exit 0
fi

echo "Injecting armhf libraries from ${ARMHF_ROOT} to ${TARGET_DIR}/lib32"
mkdir -p "${TARGET_DIR}/lib32" || exit 1
mkdir -p "${TARGET_DIR}/usr" || exit 1

# Copy userspace libraries/plugins from armhf build.
# Keep runtime files; skip static/dev metadata.
rsync -a \
    --exclude 'pkgconfig' \
    --exclude 'cmake' \
    --exclude '*.a' \
    --exclude '*.la' \
    --exclude 'python*' \
    "${ARMHF_USR_LIB}/" "${TARGET_DIR}/lib32/" || exit 1

# Merge core runtime loader/libs from /lib (glibc, ld-linux, nss, etc.)
# Overwrite any pre-existing files so armhf runtime remains authoritative
# even if other packages dropped non-armhf payloads into /lib32.
if [ -d "${ARMHF_LIB}" ]; then
    rsync -a \
        --exclude '*.a' \
        --exclude '*.la' \
        "${ARMHF_LIB}/" "${TARGET_DIR}/lib32/" || exit 1
fi

# Normalize absolute symlinks that may still point to /usr/lib*.
# In the final aarch64 image, /usr/lib is 64-bit, so any /lib32 symlink to
# /usr/lib would cause ELFCLASS64 runtime failures for armhf/32-bit clients.
while IFS= read -r -d '' link; do
    target="$(readlink "${link}" || true)"
    case "${target}" in
        /usr/lib/*)
            ln -snf "/lib32/${target#/usr/lib/}" "${link}" || exit 1
            ;;
        /usr/lib32/*)
            ln -snf "/lib32/${target#/usr/lib32/}" "${link}" || exit 1
            ;;
    esac
done < <(find "${TARGET_DIR}/lib32" -type l -print0)

# Keep a stable path for software expecting /usr/lib32.
ln -snf ../lib32 "${TARGET_DIR}/usr/lib32" || exit 1

# Ensure dynamic loader paths exist for 32-bit ARM binaries.
# Some armhf stacks install ld-linux.so.3, others ld-linux-armhf.so.3.
if [ -e "${TARGET_DIR}/lib32/ld-linux.so.3" ] && [ ! -e "${TARGET_DIR}/lib32/ld-linux-armhf.so.3" ]; then
    ln -snf ld-linux.so.3 "${TARGET_DIR}/lib32/ld-linux-armhf.so.3" || exit 1
fi
if [ -e "${TARGET_DIR}/lib32/ld-linux-armhf.so.3" ]; then
    mkdir -p "${TARGET_DIR}/lib" || exit 1
    ln -snf ../lib32/ld-linux-armhf.so.3 "${TARGET_DIR}/lib/ld-linux-armhf.so.3" || exit 1
fi
if [ -e "${TARGET_DIR}/lib32/ld-linux.so.3" ]; then
    mkdir -p "${TARGET_DIR}/lib" || exit 1
    ln -snf ../lib32/ld-linux.so.3 "${TARGET_DIR}/lib/ld-linux.so.3" || exit 1
fi

# Validate core /lib32 runtime ABI. This must be armhf for gmloadernext.armhf.
for corelib in \
    ld-linux-armhf.so.3 \
    ld-linux.so.3 \
    libc.so.6 \
    libm.so.6 \
    librt.so.1 \
    libpthread.so.0 \
    libdl.so.2
do
    if [ -e "${TARGET_DIR}/lib32/${corelib}" ] && \
       file -L "${TARGET_DIR}/lib32/${corelib}" | grep -q "Intel 80386"; then
        echo "ERROR: ${TARGET_DIR}/lib32/${corelib} is i386, expected armhf." >&2
        exit 1
    fi
done

# Ensure key OpenGL/X11 entry points in /lib32 do not resolve to 64-bit ELFs.
for soname in libGL.so.1 libX11.so.6 libXext.so.6 libXxf86vm.so.1 libXcomposite.so.1; do
    if [ -e "${TARGET_DIR}/lib32/${soname}" ] && \
       file -L "${TARGET_DIR}/lib32/${soname}" | grep -q "ELF 64-bit"; then
        echo "ERROR: ${TARGET_DIR}/lib32/${soname} resolves to 64-bit ELF." >&2
        exit 1
    fi
done

# Optional box86 runtime from the armhf pipeline.
if [ -x "${ARMHF_USR_BIN}/box86" ]; then
    install -D -m 0755 "${ARMHF_USR_BIN}/box86" "${TARGET_DIR}/usr/bin/box86" || exit 1
fi

if [ -f "${ARMHF_ROOT}/etc/box86.box86rc" ]; then
    install -D -m 0644 "${ARMHF_ROOT}/etc/box86.box86rc" "${TARGET_DIR}/etc/box86.box86rc" || exit 1
fi

if [ -f "${ARMHF_ROOT}/etc/binfmt.d/box86.conf" ]; then
    install -D -m 0644 "${ARMHF_ROOT}/etc/binfmt.d/box86.conf" "${TARGET_DIR}/etc/binfmt.d/box86.conf" || exit 1
fi

# box86 installs bundled i386 libs under /usr/lib/box86-i386-linux-gnu.
# We inject armhf userspace to /lib32, so mirror this expected path.
if [ -d "${TARGET_DIR}/lib32/box86-i386-linux-gnu" ]; then
    mkdir -p "${TARGET_DIR}/usr/lib" || exit 1
    ln -snf /lib32/box86-i386-linux-gnu "${TARGET_DIR}/usr/lib/box86-i386-linux-gnu" || exit 1
fi

echo "armhf /lib32 injection completed for ${TARGET_LOWER}."
