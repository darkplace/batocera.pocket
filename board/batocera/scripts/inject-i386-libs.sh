#!/bin/bash -e
# SPDX-FileCopyrightText: Added/modified by suckbluefrog

# Usage:
#   inject-i386-libs.sh <target_name_uppercase> <target_dir> <external_dir>
#
# Example:
#   inject-i386-libs.sh ZEN3 /zen3/target /build

TARGET_NAME="${1}"
TARGET_DIR="${2}"
EXTERNAL_DIR="${3}"

if [ -z "${TARGET_NAME}" ] || [ -z "${TARGET_DIR}" ] || [ -z "${EXTERNAL_DIR}" ]; then
    echo "inject-i386-libs.sh: invalid arguments" >&2
    exit 1
fi

TARGET_LOWER="$(echo "${TARGET_NAME}" | tr '[:upper:]' '[:lower:]')"
I386_ROOT="${EXTERNAL_DIR}/output/${TARGET_LOWER}_i386_libs/target"
I386_USR_LIB="${I386_ROOT}/usr/lib"
I386_LIB="${I386_ROOT}/lib"
I386_ICD_DIR="${I386_ROOT}/usr/share/vulkan/icd.d"
I386_IMPLICIT_LAYER_DIR="${I386_ROOT}/usr/share/vulkan/implicit_layer.d"
I386_EXPLICIT_LAYER_DIR="${I386_ROOT}/usr/share/vulkan/explicit_layer.d"
LOG_DIR="${EXTERNAL_DIR}/output/build-logs"
MANIFEST_FILE="${LOG_DIR}/${TARGET_LOWER}_i386_injected_files.txt"
VULKAN_VALIDATION_FILE="${LOG_DIR}/${TARGET_LOWER}_vulkan32_validation.txt"

if [ ! -d "${I386_USR_LIB}" ] && [ ! -d "${I386_LIB}" ]; then
    echo "No i386 lib stack found for ${TARGET_LOWER} under ${I386_ROOT}, skipping /lib32 injection."
    exit 0
fi

mkdir -p "${TARGET_DIR}/lib32" || exit 1
mkdir -p "${TARGET_DIR}/usr" || exit 1
mkdir -p "${TARGET_DIR}/usr/share/vulkan/icd.d" || exit 1
mkdir -p "${TARGET_DIR}/usr/share/vulkan/implicit_layer.d" || exit 1
mkdir -p "${TARGET_DIR}/usr/share/vulkan/explicit_layer.d" || exit 1
mkdir -p "${TARGET_DIR}/usr/share/batocera/steam" || exit 1
mkdir -p "${LOG_DIR}" || exit 1

echo "Injecting i386 libraries from ${I386_ROOT} to ${TARGET_DIR}/lib32"

manifest_tmp="$(mktemp)"
trap 'rm -f "${manifest_tmp}"' EXIT

# Copy runtime userspace from /usr/lib.
if [ -d "${I386_USR_LIB}" ]; then
    rsync -a \
        --exclude 'pkgconfig' \
        --exclude 'cmake' \
        --exclude '*.a' \
        --exclude '*.la' \
        --exclude 'python*' \
        "${I386_USR_LIB}/" "${TARGET_DIR}/lib32/" || exit 1

    (
        cd "${I386_USR_LIB}" || exit 1
        find . -mindepth 1 -not -type d \
            -not -name '*.a' \
            -not -name '*.la' \
            -not -path './pkgconfig/*' \
            -not -path './cmake/*' \
            -not -path './python*/*'
    ) | sed -e 's#^\./#/lib32/#' >> "${manifest_tmp}"
fi

# Copy core runtime loader/libs from /lib (glibc + ld-linux).
if [ -d "${I386_LIB}" ]; then
    rsync -a \
        --exclude '*.a' \
        --exclude '*.la' \
        "${I386_LIB}/" "${TARGET_DIR}/lib32/" || exit 1

    (
        cd "${I386_LIB}" || exit 1
        find . -mindepth 1 -not -type d -not -name '*.a' -not -name '*.la'
    ) | sed -e 's#^\./#/lib32/#' >> "${manifest_tmp}"
fi

# Normalize absolute symlinks that still point to /usr/lib*.
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

# Keep stable compatibility path.
ln -snf ../lib32 "${TARGET_DIR}/usr/lib32" || exit 1

# Ensure loader path used by i386 binaries is available.
if [ -e "${TARGET_DIR}/lib32/ld-linux.so.2" ]; then
    mkdir -p "${TARGET_DIR}/lib" || exit 1
    ln -snf ../lib32/ld-linux.so.2 "${TARGET_DIR}/lib/ld-linux.so.2" || exit 1
fi

# Best-effort legacy SONAME compatibility links for older 32-bit binaries.
# These are only created when the modern provider exists and the legacy
# SONAME is missing.
create_compat_link() {
    local old_soname="$1"
    local new_soname="$2"

    if [ ! -e "${TARGET_DIR}/lib32/${old_soname}" ] && [ -e "${TARGET_DIR}/lib32/${new_soname}" ]; then
        ln -snf "${new_soname}" "${TARGET_DIR}/lib32/${old_soname}" || exit 1
        printf '%s\n' "/lib32/${old_soname}" >> "${manifest_tmp}"
        echo "compat-link: /lib32/${old_soname} -> ${new_soname}"
    fi
}

create_compat_link_glob() {
    local old_soname="$1"
    local glob_pattern="$2"
    local candidate

    if [ -e "${TARGET_DIR}/lib32/${old_soname}" ]; then
        return 0
    fi

    candidate="$(find "${TARGET_DIR}/lib32" -maxdepth 1 -type f -name "${glob_pattern}" | sort | head -n1 || true)"
    if [ -n "${candidate}" ]; then
        candidate="$(basename "${candidate}")"
        ln -snf "${candidate}" "${TARGET_DIR}/lib32/${old_soname}" || exit 1
        printf '%s\n' "/lib32/${old_soname}" >> "${manifest_tmp}"
        echo "compat-link: /lib32/${old_soname} -> ${candidate}"
    fi
}

# Optional compatibility mappings are opt-in only.
# Default behavior is a strict "authentic stack" copy with no synthetic
# compatibility SONAME links created at inject time.
if [ "${BATOCERA_I386_COMPAT_LINKS:-0}" = "1" ]; then
    create_compat_link "libudev.so.0" "libudev.so.1"
    create_compat_link "libopenal.so.0" "libopenal.so.1"
    create_compat_link_glob "libSDL-1.2.so.0" "libSDL-1.2.so.0.*"
else
    # Purge stale synthetic compatibility links from prior builds.
    rm -f "${TARGET_DIR}/lib32/libcurl.so.3" \
          "${TARGET_DIR}/lib32/libopenal.so.0" \
          "${TARGET_DIR}/lib32/libudev.so.0"
fi

# Risky ABI mappings remain a separate explicit opt-in.
if [ "${BATOCERA_I386_RISKY_ABI_LINKS:-0}" = "1" ]; then
    create_compat_link "libpng12.so.0" "libpng16.so.16"
    create_compat_link "libpng15.so.15" "libpng16.so.16"
    create_compat_link "libstdc++.so.5" "libstdc++.so.6"
    create_compat_link "libcurl.so.3" "libcurl.so.4"
fi

copy_vulkan_json_dir() {
    local src_dir="$1"
    local dst_dir="$2"

    [ -d "${src_dir}" ] || return 0

    while IFS= read -r json_file; do
        local base
        base="$(basename "${json_file}")"
        install -D -m 0644 "${json_file}" "${dst_dir}/${base}" || exit 1
        sed -i \
            -e 's@/usr/lib32/@/lib32/@g' \
            -e 's@/usr/lib/@/lib32/@g' \
            "${dst_dir}/${base}" || exit 1
        printf '%s\n' "${dst_dir#${TARGET_DIR}}/${base}" >> "${manifest_tmp}"
    done < <(find "${src_dir}" -maxdepth 1 -type f -name '*.json' | grep -E '(i686|32)\.json$' || true)
}

copy_vulkan_json_dir "${I386_ICD_DIR}" "${TARGET_DIR}/usr/share/vulkan/icd.d"
copy_vulkan_json_dir "${I386_IMPLICIT_LAYER_DIR}" "${TARGET_DIR}/usr/share/vulkan/implicit_layer.d"
copy_vulkan_json_dir "${I386_EXPLICIT_LAYER_DIR}" "${TARGET_DIR}/usr/share/vulkan/explicit_layer.d"

sort -u "${manifest_tmp}" > "${MANIFEST_FILE}"
cp "${MANIFEST_FILE}" "${TARGET_DIR}/usr/share/batocera/steam/i386-injected-files.txt" || exit 1

{
    echo "== i386 Vulkan validation for ${TARGET_LOWER} =="
    echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    for soname in \
        /lib32/ld-linux.so.2 \
        /lib32/libvulkan.so.1 \
        /lib32/libGL.so.1 \
        /lib32/libEGL.so.1
    do
        if [ -e "${TARGET_DIR}${soname}" ]; then
            echo "${soname}: $(file -L "${TARGET_DIR}${soname}")"
        else
            echo "${soname}: MISSING"
        fi
    done

    echo "-- i386 ICD files --"
    find "${TARGET_DIR}/usr/share/vulkan/icd.d" -maxdepth 1 -type f -name '*i686*.json' | sort || true

    echo "-- i386 ICD library_path entries --"
    grep -H "\"library_path\"" "${TARGET_DIR}"/usr/share/vulkan/icd.d/*i686*.json 2>/dev/null || true

    if grep -H "\"library_path\"" "${TARGET_DIR}"/usr/share/vulkan/icd.d/*i686*.json 2>/dev/null | grep -q '/lib32/'; then
        echo "result=PASS (i686 ICD json points to /lib32)"
    else
        echo "result=WARN (no i686 ICD json mapped to /lib32)"
    fi
} > "${VULKAN_VALIDATION_FILE}"

cp "${VULKAN_VALIDATION_FILE}" "${TARGET_DIR}/usr/share/batocera/steam/vulkan32-validation.txt" || exit 1

echo "i386 /lib32 injection completed for ${TARGET_LOWER}."
echo "Manifest: ${MANIFEST_FILE}"
echo "Vulkan validation: ${VULKAN_VALIDATION_FILE}"
