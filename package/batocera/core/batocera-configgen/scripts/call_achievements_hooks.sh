#!/bin/sh

for D in /var/run/emulationstation/scripts/achievements /userdata/system/configs/emulationstation/scripts/achievements
do
    [ -d "${D}" ] || continue
    find -L "${D}" -type f | while read -r X
    do
	"${X}" "${1}" "${2}" "${3}" &
    done
done
