# BATOCERA ENHANCED ARM64 BUILDS  
**Unofficial Community Builds**

**Download:**  
https://drive.proton.me/urls/RRPFQ38NX8#LmFz5AIaV2aI

---

## Current Builds
- Odin2 / Thor Series  
- Powkiddy X55
- Anbernic RG-DS (test build)
- Dragon Q6A  
- R36s  
- BattleXP G350  

---

## Core Features (All ARM64 Builds)
- Flatpak enabled (with DBus + Wayland fixes)  
- Wine + Box64 + Box86  
- PortMaster fixes with multilib 32-bit support  



- MAME 0.139 (2010)

### Additional CLI Tools Included
- nodejs / npm
- pax-utils  
- file, lddtree, neofetch  
- tree, strace, strings, xmlstarlet, and more

Extra libraries (e.g. `libcups`) included for better AppImage compatibility  




---

## Qualcomm Builds (SM8550, QCS6490)
Includes additional emulators where supported:
- AetherSX2  
- RPCS3  
- Vita3K  
- Cemu  
- SkyEmu  
- NanoBoy Advance
- And more emulators
- Steam aarch64 (aarch64 client) (with gamescope working on sm8550) (h/t tipoex/mia milkyway)
- DXVK (DX11 support)
- Fex-Emu support on Wine runners
- Docker *(enable in Services menu)*
- Hotkey + touchscreen support for on-screen keyboard  

---

## SM8550 (Snapdragon 8 Gen 2 Class)
- Odin 2 includes LED support
- experimental gamescope for wine, cemu
- Strong DX9 / DX10 support  
- Many DX11-era titles may run  
- Vulkan-native titles perform best  
- Not a replacement for x86 gaming PCs  

### General Notes
- Performance varies heavily by engine  
- DXVK improves compatibility but is not magic  
- CPU-heavy or shader-heavy games may still struggle  
- aarch64 Wine translation overhead remains a factor  

---

## Rockchip / Allwinner Devices

### GPU Stack
- Mesa + Panfrost  
- Powkiddy X55 has mali blobs with gpudriver toggle in settings to panfrost
  
### Wine Expectations
> “No! It can't run Crysis”

### Wine Performance Guidelines (Rockchip)
These SoCs are limited by:
- Cortex-A35 / A53 / A55 class CPUs  
- Panfrost driver maturity  
- Memory bandwidth  

#### RK3326 / H700
- Target: early DX8 / DX9 era  
- Pre-2005 recommended  
- 2D engines perform best  

#### RK3566
- Light DX9 titles possible  
- Shader-heavy games will struggle
- Vulkan enabled in libmali mode -- helps especially with PPSSPP (Thanks Sysdarn)
- Azahar enabled - don't expect fullspeed, usually needs 3gb RAM minimum

Do **NOT** expect:
- DX10 / DX11 performance  
- Modern Unity / Unreal engines  
- Heavy physics or CPU-bound games  

---

## Qualcomm GPU Stack
- Mesa + Freedreno + Turnip  
- Supports higher-end emulation where hardware allows  

---

## Support Policy
**DO NOT** ask for support on the official Batocera Discord or Reddit.  
These are unofficial builds and are **NOT supported** by the Batocera team.  

---

## License & Disclaimer
- Released under Batocera’s GPLv2 License  
- Source code is included  
- Use at your own risk  
- No warranty  
- No support provided  
