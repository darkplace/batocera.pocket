Waydroid per-app evmapy mappings live here in the build tree.

Naming:
- one file per Android package
- format: <package>.keys
- example: com.playdigious.tmnt.keys

Runtime flow:
- /usr/bin/batocera-waydroid-update parses installed Waydroid desktop files
- it creates /userdata/roms/android/waydroid-auto-<package>.waydroid
- if a matching mapping exists here, it copies it to:
  /userdata/roms/android/waydroid-auto-<package>.waydroid.keys
- configgen evmapy then picks up that sidecar automatically for ES launches

User override:
- /userdata/system/configs/evmapy/waydroid/<package>.keys
- user override wins over the packaged mapping

Notes:
- these mappings are keyboard emulation, not native Android gamepad passthrough
- app support still depends on the Android app actually accepting keyboard input
