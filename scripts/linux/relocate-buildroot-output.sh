#!/usr/bin/env bash
set -euo pipefail

# Rewrite stale absolute Buildroot output roots in an existing output tree.
#
# Docker builds mount each output directory at /<target>. If an output tree is
# reused or symlinked from another target, host metadata such as pkg-config and
# Meson files may still point at /<old-target>, which breaks later package
# configure steps.

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <output-dir> <builder-visible-output-root>" >&2
    exit 1
fi

output_dir="${1%/}"
builder_root="${2%/}"

if [ ! -d "${output_dir}" ]; then
    exit 0
fi

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
output_abs="$(cd "${output_dir}" && pwd -P)"
output_parent="$(cd "$(dirname "${output_abs}")" && pwd -P)"

if [ ! -d "${output_abs}/host" ]; then
    exit 0
fi

is_host_elf_executable() {
    local file="${1}"

    readelf -l "${file}" 2>/dev/null \
        | grep -q "Requesting program interpreter:"
}

elf_needs_host_rpath() {
    local file="${1}"
    local hostdir="${2}"
    local lib

    while IFS= read -r lib; do
        [ -e "${hostdir}/lib/${lib}" ] && return 0
    done < <(
        readelf -d "${file}" 2>/dev/null \
            | sed -r -e '/^.* \(NEEDED\) .*Shared library: \[(.+)\]$/!d' \
                     -e 's//\1/'
    )

    return 1
}

host_rpath_points_to_lib() {
    local hostdir="${1}"
    local rpath="${2}"
    local dir normalized

    [ -n "${rpath}" ] || return 1

    for dir in ${rpath//:/ }; do
        [ -n "${dir}" ] || continue
        normalized="$(sed -r -e 's:/+:/:g; s:/$::;' <<<"${dir}")"
        [ "${normalized}" = "\$ORIGIN/../lib" ] && return 0
        [ -e "${normalized}" ] && [ "${normalized}" -ef "${hostdir}/lib" ] && return 0
    done

    return 1
}

repair_host_tool_rpaths() {
    local hostdir="${1}"
    local patchelf="${hostdir}/bin/patchelf"
    local file rpath changed

    [ -x "${patchelf}" ] || return 0
    [ -d "${hostdir}/lib" ] || return 0

    changed=0
    while IFS= read -r -d '' file; do
        is_host_elf_executable "${file}" || continue
        elf_needs_host_rpath "${file}" "${hostdir}" || continue

        rpath="$("${patchelf}" --print-rpath "${file}" 2>/dev/null || true)"
        host_rpath_points_to_lib "${hostdir}" "${rpath}" && continue

        "${patchelf}" --set-rpath "\$ORIGIN/../lib" "${file}" || continue
        changed=$((changed + 1))
    done < <(find "${hostdir}/bin" "${hostdir}/sbin" -type f -print0 2>/dev/null)

    if [ "${changed}" -gt 0 ]; then
        echo "Repaired host RPATH in ${changed} executable(s) under ${hostdir}."
    fi
}

patterns="$(mktemp)"
rewrites="$(mktemp)"
files="$(mktemp)"
trap 'rm -f "${patterns}" "${rewrites}" "${files}"' EXIT

add_rewrite_path() {
    local from="${1%/}"
    local to="${2%/}"

    [ -n "${from}" ] || return 0
    [ -n "${to}" ] || return 0
    [ "${from}" != "${to}" ] || return 0

    printf '%s\n' "${from}" >> "${patterns}"
    printf '%s\t%s\n' "${from}" "${to}" >> "${rewrites}"
}

add_rewrite_root() {
    local from="${1%/}"
    local subdir

    for subdir in host staging target build images per-package legal-info graphs .br-progress; do
        add_rewrite_path "${from}/${subdir}" "${builder_root}/${subdir}"
    done
}

for suffix in _armhf_libs _armhf_libs_armhf_libs _i386_libs _i386_libs_i386_libs; do
    add_rewrite_root "${builder_root}${suffix}"
done

while IFS= read -r board; do
    target="${board##*/batocera-}"
    target="${target%.board}"

    add_rewrite_root "/${target}"
    add_rewrite_root "${output_parent}/${target}"

    # Older bad relocations can duplicate the output parent repeatedly.
    repeated_output_parent="${output_parent}"
    for _ in {1..12}; do
        repeated_output_parent="${repeated_output_parent}${output_parent}"
        add_rewrite_root "${repeated_output_parent}/${target}"
    done
done < <(find "${repo_dir}/configs" -maxdepth 1 -name 'batocera-*.board' -type f | sort)

if [ ! -s "${patterns}" ]; then
    exit 0
fi

scan_dirs=("${output_abs}/host")
if [ -d "${output_abs}/per-package" ]; then
    scan_dirs+=("${output_abs}/per-package")
fi

if grep --binary-files=without-match -IlrZ -F -f "${patterns}" "${scan_dirs[@]}" > "${files}"; then
    if [ -s "${files}" ]; then
        count="$(
            python3 - "${rewrites}" "${files}" <<'PY'
import os
import sys

rewrites_path, files_path = sys.argv[1], sys.argv[2]

with open(rewrites_path, "rb") as rewrites_file:
    rewrites = [
        line.rstrip(b"\n").split(b"\t", 1)
        for line in rewrites_file
        if line.strip()
    ]

rewrites.sort(key=lambda rewrite: len(rewrite[0]), reverse=True)

with open(files_path, "rb") as files_file:
    files = [path for path in files_file.read().split(b"\0") if path]

path_chars = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_./-"
word_chars = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.-"
flag_prefixes = (b"-I", b"-L", b"-isystem", b"-idirafter", b"-iquote", b"--sysroot=")


def starts_at_path_boundary(data, index):
    if index == 0:
        return True
    if data[index - 1:index] not in path_chars:
        return True
    return any(data[:index].endswith(prefix) for prefix in flag_prefixes)


def ends_at_path_boundary(data, index):
    if index >= len(data):
        return True
    if data[index:index + 1] == b"/":
        return True
    return data[index:index + 1] not in word_chars


def replace_guarded(data, old, new):
    parts = []
    start = 0
    changed = False

    while True:
        index = data.find(old, start)
        if index < 0:
            break

        end = index + len(old)
        if starts_at_path_boundary(data, index) and ends_at_path_boundary(data, end):
            parts.append(data[start:index])
            parts.append(new)
            start = end
            changed = True
        else:
            parts.append(data[start:end])
            start = end

    if not changed:
        return data

    parts.append(data[start:])
    return b"".join(parts)


changed_files = 0
for raw_path in files:
    path = os.fsdecode(raw_path)
    try:
        with open(path, "rb") as input_file:
            original = input_file.read()
    except FileNotFoundError:
        continue

    updated = original
    for old, new in rewrites:
        updated = replace_guarded(updated, old, new)

    if updated != original:
        with open(path, "wb") as output_file:
            output_file.write(updated)
        changed_files += 1

print(changed_files)
PY
        )"
        if [ "${count}" -gt 0 ]; then
            echo "Relocated stale Buildroot output paths in ${count} files to ${builder_root}."
        fi
    fi
fi

repair_host_tool_rpaths "${output_abs}/host"
