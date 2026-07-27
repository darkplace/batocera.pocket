#!/bin/bash -e

TARGET_DIR="${1:?missing target directory}"
case "${TARGET_DIR}" in
    /|"")
        echo "Refusing to clean an unsafe target directory: ${TARGET_DIR}" >&2
        exit 1
        ;;
esac

remove_xml_block_containing()
{
    local xml_file="$1"
    local start_pattern="$2"
    local end_pattern="$3"
    local needle="$4"
    local temporary="${xml_file}.sm8750-clean"

    test -f "${xml_file}" || return 0
    awk \
        -v start_pattern="${start_pattern}" \
        -v end_pattern="${end_pattern}" \
        -v needle="${needle}" '
        $0 ~ start_pattern {
            in_block = 1
            block = $0 ORS
            matched = index(tolower($0), needle) != 0
            next
        }
        in_block {
            block = block $0 ORS
            if (index(tolower($0), needle) != 0)
                matched = 1
            if ($0 ~ end_pattern) {
                if (!matched)
                    printf "%s", block
                in_block = 0
                block = ""
                matched = 0
            }
            next
        }
        { print }
        END {
            if (in_block && !matched)
                printf "%s", block
        }
    ' "${xml_file}" > "${temporary}"
    mv "${temporary}" "${xml_file}"
}

remove_yaml_section()
{
    local yaml_file="$1"
    local section="$2"
    local temporary="${yaml_file}.sm8750-clean"

    test -f "${yaml_file}" || return 0
    awk -v section="${section}" '
        $0 == section ":" {
            skipping = 1
            next
        }
        skipping && /^[^[:space:]#][^:]*:/ {
            skipping = 0
        }
        !skipping {
            print
        }
    ' "${yaml_file}" > "${temporary}"
    mv "${temporary}" "${yaml_file}"
}

rm -rf -- \
    "${TARGET_DIR}/usr/lib/waydroid" \
    "${TARGET_DIR}/usr/share/batocera/waydroid" \
    "${TARGET_DIR}/usr/share/batocera/datainit/roms/android"

rm -f -- \
    "${TARGET_DIR}/etc/init.d/S22waydroid-host" \
    "${TARGET_DIR}/etc/xdg/menus/applications-merged/waydroid.menu" \
    "${TARGET_DIR}/usr/bin/Waydroid.sh" \
    "${TARGET_DIR}/usr/bin/batocera-waydroid-app" \
    "${TARGET_DIR}/usr/bin/batocera-waydroid-app-session" \
    "${TARGET_DIR}/usr/bin/batocera-waydroid-init" \
    "${TARGET_DIR}/usr/bin/batocera-waydroid-platform-launch" \
    "${TARGET_DIR}/usr/bin/batocera-waydroid-postboot" \
    "${TARGET_DIR}/usr/bin/batocera-waydroid-session" \
    "${TARGET_DIR}/usr/bin/batocera-waydroid-tools" \
    "${TARGET_DIR}/usr/bin/batocera-waydroid-tools-launcher" \
    "${TARGET_DIR}/usr/bin/batocera-waydroid-update" \
    "${TARGET_DIR}/usr/bin/waydroid" \
    "${TARGET_DIR}/usr/bin/waydroid-get-android-id" \
    "${TARGET_DIR}/usr/share/applications/Waydroid.desktop" \
    "${TARGET_DIR}/usr/share/applications/waydroid.app.install.desktop" \
    "${TARGET_DIR}/usr/share/applications/waydroid.desktop" \
    "${TARGET_DIR}/usr/share/applications/waydroid.market.desktop" \
    "${TARGET_DIR}/usr/share/batocera/datainit/roms/apps/Waydroid.sh" \
    "${TARGET_DIR}/usr/share/batocera/datainit/roms/apps/images/waydroid.png" \
    "${TARGET_DIR}/usr/share/batocera/datainit/roms/emulator/Waydroid_Tools.sh" \
    "${TARGET_DIR}/usr/share/batocera/datainit/roms/emulator/Waydroid_Tools.sh.keys" \
    "${TARGET_DIR}/usr/share/batocera/datainit/roms/emulator/images/waydroid.png" \
    "${TARGET_DIR}/usr/share/batocera/datainit/roms/tools/Start_Waydroid.sh" \
    "${TARGET_DIR}/usr/share/dbus-1/system-services/id.waydro.Container.service" \
    "${TARGET_DIR}/usr/share/dbus-1/system.d/id.waydro.Container.conf" \
    "${TARGET_DIR}/usr/share/desktop-directories/waydroid.directory" \
    "${TARGET_DIR}/usr/share/emulationstation/hooks/preupdate-gamelists-android" \
    "${TARGET_DIR}/usr/share/evmapy/android.keys" \
    "${TARGET_DIR}/usr/share/evmapy/waydroid.keys" \
    "${TARGET_DIR}/usr/share/icons/batocera/waydroid.png" \
    "${TARGET_DIR}/usr/share/icons/hicolor/512x512/apps/waydroid.png" \
    "${TARGET_DIR}/usr/share/metainfo/id.waydro.waydroid.metainfo.xml" \
    "${TARGET_DIR}/usr/share/polkit-1/actions/id.waydro.Container.policy"

for generator in \
    "${TARGET_DIR}"/usr/lib/python*/site-packages/configgen/generators/waydroid
do
    test -e "${generator}" || continue
    rm -rf -- "${generator}"
done

for record in \
    "${TARGET_DIR}"/usr/lib/python*/site-packages/batocera_configgen-*.dist-info/RECORD
do
    test -f "${record}" || continue
    sed -i '\|configgen/generators/waydroid/|d' "${record}"
done

remove_xml_block_containing \
    "${TARGET_DIR}/usr/share/batocera/datainit/roms/apps/gamelist.xml" \
    '^[[:space:]]*<game>' '^[[:space:]]*</game>' 'waydroid'
remove_xml_block_containing \
    "${TARGET_DIR}/usr/share/batocera/datainit/roms/emulator/gamelist.xml" \
    '^[[:space:]]*<game>' '^[[:space:]]*</game>' 'waydroid'
remove_xml_block_containing \
    "${TARGET_DIR}/usr/share/emulationstation/es_systems.cfg" \
    '^[[:space:]]*<system>' '^[[:space:]]*</system>' 'waydroid'
remove_xml_block_containing \
    "${TARGET_DIR}/usr/share/emulationstation/es_features.cfg" \
    '^[[:space:]]*<emulator[ >]' '^[[:space:]]*</emulator>' 'waydroid'
remove_yaml_section \
    "${TARGET_DIR}/usr/share/batocera/configgen/configgen-defaults-arch.yml" \
    'waydroid'
