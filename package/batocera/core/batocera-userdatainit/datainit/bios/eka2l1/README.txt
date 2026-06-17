Place EKA2L1 device data packs here.

Supported seed layouts:
- devices.yml plus the matching drives directory directly in this folder.
- an EKA2L1 or Data subfolder containing devices.yml plus the matching drives directory.
- a .zip archive with one of those layouts.

Examples:
/userdata/bios/eka2l1/devices.yml
/userdata/bios/eka2l1/drives/z/NEM-4/System/...
/userdata/bios/eka2l1/roms/NEM-4/SYM.ROM

/userdata/bios/eka2l1/EKA2L1/devices.yml
/userdata/bios/eka2l1/EKA2L1/drives/z/RH-29/System/...
/userdata/bios/eka2l1/EKA2L1/roms/RH-29/SYM.ROM

/userdata/bios/Nokia N-Gage & N-Gage QD (S60v1).zip

The generator copies missing device data into EKA2L1's data-storage directory before launch.
By default, that is /userdata/saves/eka2l1/EKA2L1/data.
Existing EKA2L1 files are not overwritten.
The generator also creates lowercase aliases for firmware paths so Linux can resolve Symbian paths such as system/libs/euser.dll.

Raw Symbian firmware files can also be kept here and imported through the EKA2L1 GUI.
Open the GUI from F1 Applications or Tools/Start_EKA2L1.sh.

Original Nokia N-Gage and N-Gage QD device packs are S60v1/EPOC 6.x devices.
Later .n-gage installer packages are usually Symbian OS 9.x/N-Gage 2.0 packages and require matching S60v3 or newer device data, not an NEM-4/RH-29 profile.

If EKA2L1 says "no non-system app installed on this device", the device pack loaded but the selected game is not installed or mounted as a compatible app for that device.
Use an original N-Gage card dump folder or zip for NEM-4/RH-29, or provide matching S60v3/newer device data for later N-Gage 2.0 packages.
