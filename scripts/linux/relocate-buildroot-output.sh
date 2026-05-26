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

patterns="$(mktemp)"
sed_script="$(mktemp)"
files="$(mktemp)"
trap 'rm -f "${patterns}" "${sed_script}" "${files}"' EXIT

escape_sed_pattern() {
    printf '%s' "$1" | sed -e 's/[.[\*^$\\]/\\&/g' -e 's/|/\\|/g'
}

escape_sed_replacement() {
    printf '%s' "$1" | sed -e 's/[&\\]/\\&/g' -e 's/|/\\|/g'
}

add_rewrite_path() {
    local from="${1%/}"
    local to="${2%/}"

    [ -n "${from}" ] || return 0
    [ -n "${to}" ] || return 0
    [ "${from}" != "${to}" ] || return 0

    printf '%s\n' "${from}" >> "${patterns}"
    printf 's|%s|%s|g\n' \
        "$(escape_sed_pattern "${from}")" \
        "$(escape_sed_replacement "${to}")" >> "${sed_script}"
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
done < <(find "${repo_dir}/configs" -maxdepth 1 -name 'batocera-*.board' -type f | sort)

if [ ! -s "${patterns}" ]; then
    exit 0
fi

scan_dirs=("${output_abs}/host")
if [ -d "${output_abs}/per-package" ]; then
    scan_dirs+=("${output_abs}/per-package")
fi

if grep --binary-files=without-match -IlrZ -f "${patterns}" "${scan_dirs[@]}" > "${files}"; then
    if [ -s "${files}" ]; then
        xargs -0 --no-run-if-empty sed -i -f "${sed_script}" < "${files}"
        count="$(tr -cd '\0' < "${files}" | wc -c)"
        echo "Relocated stale Buildroot output paths in ${count} files to ${builder_root}."
    fi
fi
