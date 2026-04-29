#!/bin/sh

BNAME=$1

FBOARD="${BNAME}.board"

if ! test -e "${FBOARD}"
then
    echo "file ${FBOARD} not found" >&2
    exit 1
fi

TMPL0="${BNAME}_defconfig.tmpl0"
CONFDIR=$(dirname "${FBOARD}")
FDEFCONFIG="${BNAME}_defconfig"

# For untracked local changes
touch -a "${CONFDIR}/batocera-board.local.common"

> "${TMPL0}" || exit 1 # flattened include content

# Flatten include graph depth-first and de-duplicate already expanded files.
awk \
    -v confdir="${CONFDIR}" \
    -v board="${FBOARD}" \
    -v out="${TMPL0}" '
function process_include(rel, abs, line, parts, n, inc) {
    if (seen[rel]) {
        return
    }
    seen[rel] = 1

    abs = confdir "/" rel
    if ((getline line < abs) < 0) {
        printf("include file %s not found from %s\n", rel, board) > "/dev/stderr"
        exit 1
    }
    close(abs)

    while ((getline line < abs) > 0) {
        if (line ~ /^[[:space:]]*include[[:space:]]+/) {
            n = split(line, parts, /[[:space:]]+/)
            if (n >= 2) {
                inc = parts[2]
                process_include(inc)
            }
        }
    }
    close(abs)

    print "# from file " rel >> out
    while ((getline line < abs) > 0) {
        if (line !~ /^[[:space:]]*include[[:space:]]+/) {
            print line >> out
        }
    }
    close(abs)
    print "" >> out
}
BEGIN {
    while ((getline line < board) > 0) {
        if (line ~ /^[[:space:]]*include[[:space:]]+/) {
            n = split(line, parts, /[[:space:]]+/)
            if (n >= 2) {
                process_include(parts[2])
            }
        }
    }
    close(board)
}
' || exit 1

> "${FDEFCONFIG}" || exit 1
cat "${TMPL0}" >> "${FDEFCONFIG}"

rm -f "${TMPL0}" || exit 1

echo "### from board file ###"   >> "${FDEFCONFIG}" || exit 1
grep -vE '^[[:space:]]*include[[:space:]]+' "${FBOARD}" >> "${FDEFCONFIG}" || exit 1

exit 0
