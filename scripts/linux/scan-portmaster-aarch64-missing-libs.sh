#!/bin/bash
set -euo pipefail

# Scan aarch64 ELF files under PortMaster/ports and report unresolved SONAMEs
# against the active system library set.
#
# Usage:
#   scan-portmaster-aarch64-missing-libs.sh [ports_dir] [portmaster_dir]
#
# Defaults:
#   ports_dir      = /userdata/roms/ports
#   portmaster_dir = /userdata/system/.local/share/PortMaster

PORTS_DIR="${1:-/userdata/roms/ports}"
PM_DIR="${2:-/userdata/system/.local/share/PortMaster}"

if ! command -v readelf >/dev/null 2>&1; then
  echo "readelf not found" >&2
  exit 1
fi

if ! command -v file >/dev/null 2>&1; then
  echo "file not found" >&2
  exit 1
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

# Build SONAME index from currently visible system libs.
find /lib /usr/lib /usr/lib64 -type f -name '*.so*' 2>/dev/null \
  | awk -F/ '{print $NF}' | sort -u > "${TMPDIR}/system_sonames.txt"

collect_aarch64_elfs() {
  local root="$1"
  [ -d "${root}" ] || return 0
  find "${root}" -type f 2>/dev/null | while read -r f; do
    if file -b "${f}" | grep -q 'ELF 64-bit.*ARM aarch64'; then
      echo "${f}"
    fi
  done
}

collect_aarch64_elfs "${PORTS_DIR}" > "${TMPDIR}/aarch64_files.txt"
collect_aarch64_elfs "${PM_DIR}" >> "${TMPDIR}/aarch64_files.txt"

if [ ! -s "${TMPDIR}/aarch64_files.txt" ]; then
  echo "No aarch64 ELF files found under:"
  echo "  ${PORTS_DIR}"
  echo "  ${PM_DIR}"
  exit 0
fi

is_present_in_tree() {
  local root="$1"
  local soname="$2"
  find "${root}" -type f -name "${soname}" 2>/dev/null | grep -q .
}

echo -n > "${TMPDIR}/missing_raw.txt"

while read -r elf; do
  # Prefer the nearest top-level port folder for bundle checks.
  port_root="${PORTS_DIR}/$(echo "${elf}" | sed -E "s#^${PORTS_DIR}/([^/]+).*\$#\\1#")"
  [ -d "${port_root}" ] || port_root="${PM_DIR}"

  while read -r need; do
    [ -z "${need}" ] && continue
    case "${need}" in
      linux-vdso.so.*|ld-linux-aarch64.so.1|ld-linux-armhf.so.3|ld-linux.so.3) continue ;;
    esac

    # bundled next to the ELF
    [ -e "$(dirname "${elf}")/${need}" ] && continue

    # bundled somewhere in same port/runtime tree
    is_present_in_tree "${port_root}" "${need}" && continue

    # available in active system libs
    grep -qx "${need}" "${TMPDIR}/system_sonames.txt" && continue

    echo "${need}|${elf}" >> "${TMPDIR}/missing_raw.txt"
  done < <(readelf -d "${elf}" 2>/dev/null | sed -n 's/.*Shared library: \[\(.*\)\].*/\1/p')
done < "${TMPDIR}/aarch64_files.txt"

if [ -s "${TMPDIR}/missing_raw.txt" ]; then
  echo "== Missing SONAMEs (count) =="
  cut -d'|' -f1 "${TMPDIR}/missing_raw.txt" | sort | uniq -c | sort -nr
  echo
  echo "== Missing SONAMEs with files =="
  cat "${TMPDIR}/missing_raw.txt"
else
  echo "No missing aarch64 SONAMEs detected."
fi
