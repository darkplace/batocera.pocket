#!/bin/bash -e

# Compare 64-bit target libs with armhf stack for a given board target.
# Usage:
#   scripts/linux/check-armhf-libs.sh rk3568

TARGET="${1}"
if [ -z "${TARGET}" ]; then
    echo "Usage: $0 <target>" >&2
    exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
LIB64_DIR="${ROOT_DIR}/output/${TARGET}/target/usr/lib"
LIB32_DIR="${ROOT_DIR}/output/${TARGET}_armhf_libs/target/usr/lib"

if [ ! -d "${LIB64_DIR}" ]; then
    echo "Missing 64-bit lib dir: ${LIB64_DIR}" >&2
    exit 1
fi

if [ ! -d "${LIB32_DIR}" ]; then
    echo "Missing armhf lib dir: ${LIB32_DIR}" >&2
    exit 1
fi

TMP64="$(mktemp)"
TMP32="$(mktemp)"
trap 'rm -f "${TMP64}" "${TMP32}"' EXIT

find "${LIB64_DIR}" -maxdepth 1 -type f -name 'lib*.so*' -printf '%f\n' \
    | sed -E 's/\.so(\..*)?$/.so/' | sort -u > "${TMP64}"
find "${LIB32_DIR}" -maxdepth 1 -type f -name 'lib*.so*' -printf '%f\n' \
    | sed -E 's/\.so(\..*)?$/.so/' | sort -u > "${TMP32}"

echo "64-bit libs: $(wc -l < "${TMP64}")"
echo "armhf libs:  $(wc -l < "${TMP32}")"
echo
echo "Missing in armhf (top-level SONAME view):"
comm -23 "${TMP64}" "${TMP32}" || true
